<?php

namespace Tests\Concurrency;

use Dotenv\Dotenv;
use Illuminate\Http\Client\Pool;
use Illuminate\Http\Client\Response;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Str;
use PHPUnit\Framework\Attributes\Group;
use Tests\TestCase;

/**
 * Request bersamaan ke server sungguhan (docs/TECH-KuotaPlus.md, Testing): Laragon harus berjalan dan database
 * server sudah `migrate:fresh --seed`. Jalankan: `php artisan test --group=concurrency`.
 *
 * Tes membuat data seperti saat demo (satu transfer 500 MB dan satu pembelian paket aktif termurah milik Budi),
 * tidak menghapus apa pun. Hasil dicek lewat API dan dengan membaca database server.
 * Alamat server: CONCURRENCY_BASE_URL (default http://localhost).
 */
#[Group('concurrency')]
class ConcurrencyTest extends TestCase
{
    private const BUDI = '6288100000002';

    private const ANDI = '6288100000007';

    private const HALF_GB = 536870912;

    private string $base;

    /** Satu login untuk semua tes: OTP login hanya bisa dikirim ulang setelah 60 detik. */
    private static ?string $token = null;

    /** @var array<string, string> isi .env server (bukan env test) */
    private array $serverEnv;

    protected function setUp(): void
    {
        parent::setUp();
        $this->base = rtrim(env('CONCURRENCY_BASE_URL', 'http://localhost'), '/').'/api';
        $this->serverEnv = Dotenv::parse(file_get_contents(base_path('.env')));

        // Koneksi baca-saja ke database yang dipakai server, untuk memeriksa hasil.
        config(['database.connections.server' => ['database' => $this->serverEnv['DB_DATABASE']] + config('database.connections.mysql')]);

        try {
            Http::acceptJson()->timeout(5)->get($this->base.'/home');
        } catch (\Throwable) {
            $this->markTestSkipped("Server {$this->base} tidak bisa dijangkau. Nyalakan Laragon atau set CONCURRENCY_BASE_URL.");
        }
    }

    private function budiToken(): string
    {
        return self::$token ??= $this->login(self::BUDI);
    }

    private function login(string $msisdn): string
    {
        $code = Http::acceptJson()->post($this->base.'/auth/otp/request', ['msisdn' => $msisdn])->throw()->json('data.demo_otp');
        $this->assertNotNull($code, 'Server harus APP_ENV=local agar demo_otp dikirim.');

        return Http::acceptJson()
            ->post($this->base.'/auth/otp/verify', ['msisdn' => $msisdn, 'code' => $code, 'device_name' => 'concurrency-test'])
            ->throw()
            ->json('data.token');
    }

    public function test_two_simultaneous_transfers_with_one_otp_create_exactly_one(): void
    {
        $token = $this->budiToken();
        $api = Http::acceptJson()->withToken($token)->baseUrl($this->base);

        $quote = $api->get('/quota-transfers/quote', ['recipient_msisdn' => self::ANDI])->throw()->json('data');
        $option = collect($quote['options'])->firstWhere('bytes', self::HALF_GB);
        if ($option === null) {
            $this->markTestSkipped('Pengaturan share.step_bytes server bukan 0,5 GB. Jalankan migrate:fresh --seed.');
        }
        if (! $option['allowed']) {
            $this->markTestSkipped('Budi tidak bisa berbagi 500 MB lagi ('.$option['reason'].'). Jalankan migrate:fresh --seed.');
        }
        $usedBefore = $quote['allowance']['used_30d_bytes'];
        $countBefore = $api->get('/quota-transfers')->throw()->json('meta.total');

        $code = $api->post('/quota-transfers/otp', ['recipient_msisdn' => self::ANDI, 'bytes' => self::HALF_GB])->throw()->json('data.demo_otp');
        $body = ['recipient_msisdn' => self::ANDI, 'bytes' => self::HALF_GB, 'otp_code' => $code];

        /** @var list<Response> $responses */
        $responses = Http::pool(fn (Pool $pool) => [
            $pool->acceptJson()->withToken($token)->withHeaders(['Idempotency-Key' => (string) Str::uuid()])->post($this->base.'/quota-transfers', $body),
            $pool->acceptJson()->withToken($token)->withHeaders(['Idempotency-Key' => (string) Str::uuid()])->post($this->base.'/quota-transfers', $body),
        ]);

        $statuses = collect($responses)->map(fn (Response $r) => $r->status())->sort()->values()->all();
        $this->assertSame([201, 422], $statuses, 'Satu OTP hanya boleh mengonfirmasi satu transfer.');

        $after = $api->get('/quota-transfers/quote', ['recipient_msisdn' => self::ANDI])->throw()->json('data.allowance');
        $this->assertSame($usedBefore + self::HALF_GB, $after['used_30d_bytes']);
        $this->assertLessThanOrEqual($after['limit_bytes'], $after['used_30d_bytes']);
        $this->assertSame($countBefore + 1, $api->get('/quota-transfers')->throw()->json('meta.total'));
    }

    public function test_two_simultaneous_paid_callbacks_provision_once(): void
    {
        $api = Http::acceptJson()->withToken($this->budiToken())->baseUrl($this->base);
        $packageId = collect($api->get('/packages')->throw()->json('data.groups'))
            ->flatMap(fn ($group) => $group['packages'])
            ->sortBy('price')->first()['id']; // paket aktif termurah (HR05 di seed sengaja nonaktif)

        $transaction = $api->withHeaders(['Idempotency-Key' => (string) Str::uuid()])
            ->post('/transactions', ['type' => 'package', 'package_id' => $packageId, 'payment_method' => 'qris'])
            ->throw()
            ->json('data');

        $raw = json_encode(['external_ref' => $transaction['external_ref'], 'status' => 'PAID']);
        $signature = hash_hmac('sha256', $raw, $this->serverEnv['PAYMENT_WEBHOOK_SECRET']);
        $send = fn (Pool $pool) => $pool->withHeaders(['X-Signature' => $signature, 'Accept' => 'application/json'])
            ->withBody($raw, 'application/json')
            ->post($this->base.'/payments/callback');

        $responses = Http::pool(fn (Pool $pool) => [$send($pool), $send($pool)]);

        foreach ($responses as $response) {
            $this->assertSame(200, $response->status(), 'Callback ganda tetap dijawab 200 (idempoten).');
        }
        $this->assertSame('paid', $api->get('/transactions/'.$transaction['id'])->throw()->json('data.status'));
        $this->assertSame(1, DB::connection('server')->table('subscriptions')->where('transaction_id', $transaction['id'])->count(),
            'Paket hanya boleh diprovisioning sekali.');
    }
}
