<?php

namespace Tests\Feature;

use App\Models\DailyEvaluation;
use App\Models\Forecast;
use App\Models\Package;
use App\Models\PointLedger;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\UsageRecord;
use App\Models\User;
use App\Services\PaymentService;
use App\Services\PointService;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * FR-11, FR-12 dan DoD "Integritas poin": SUM(point_ledger.delta) selalu = saldo yang ditampilkan,
 * dan poin hold selalu kembali saat transaksi gagal/kedaluwarsa.
 */
class PointsTest extends TestCase
{
    use RefreshDatabase;

    private const MB = 1048576;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.payment.webhook_secret' => 'test-secret']);
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
        $this->user = User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000002')->value('id')]); // Budi, pulsa Rp150.000
        Sanctum::actingAs($this->user);
    }

    /** Poin awal lewat jalur sungguhan: evaluasi hari hemat dan ledger earn. */
    private function givePoints(int $points, int $expiresInDays = 90): void
    {
        $evaluation = DailyEvaluation::create(['user_id' => $this->user->id, 'eval_date' => today()->subDays(rand(100, 900)),
            'usage_bytes' => 0, 'budget_bytes' => 0, 'result' => 'hemat', 'streak_after' => 1]);
        $this->travel($expiresInDays - 90)->days();
        DB::transaction(fn () => app(PointService::class)->earn($this->user, $points, 'earn_daily', $evaluation));
        $this->travelBack();
    }

    private function buy(string $code, string $method, int $points)
    {
        return $this->withHeader('Idempotency-Key', (string) Str::uuid())->postJson('/api/transactions', [
            'type' => 'package', 'package_id' => Package::where('code', $code)->value('id'),
            'payment_method' => $method, 'points_used' => $points,
        ]);
    }

    private function payCallback(array $transaction, string $status): void
    {
        $body = json_encode(['external_ref' => $transaction['external_ref'], 'status' => $status]);
        $this->call('POST', '/api/payments/callback', [], [], [], [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json', 'HTTP_X_SIGNATURE' => PaymentService::sign($body),
        ], $body)->assertOk();
    }

    /** Invarian ledger: saldo API = SUM(delta) = SUM(remaining) kredit yang masih berlaku. */
    private function assertLedgerConsistent(int $expected): void
    {
        $sum = (int) PointLedger::where('user_id', $this->user->id)->sum('delta');
        $this->assertSame($expected, $sum);
        $this->assertSame($sum, $this->getJson('/api/points')->json('data.balance'));
        $this->assertSame($sum, app(PointService::class)->available($this->user));
    }

    public function test_paying_with_points_discounts_and_keeps_ledger_consistent(): void
    {
        $this->givePoints(600);

        $this->buy('VID30', 'pulsa', 500)
            ->assertCreated()
            ->assertJsonPath('data.discount_amount', 5000)
            ->assertJsonPath('data.net_amount', 60000)
            ->assertJsonPath('data.points_used', 500);

        $this->assertSame(90000, Subscriber::find($this->user->subscriber_id)->pulsa_balance);
        $this->assertLedgerConsistent(100);
    }

    public function test_hold_is_returned_exactly_when_payment_fails_or_expires(): void
    {
        $this->givePoints(700);

        $failed = $this->buy('VID30', 'va', 300)->assertCreated()->json('data');
        $this->getJson('/api/points')->assertJsonPath('data.balance', 400)->assertJsonPath('data.held', 300);
        $this->payCallback($failed, 'FAILED');
        $this->assertLedgerConsistent(700);

        $expired = $this->buy('VID30', 'qris', 400)->assertCreated()->json('data');
        $this->travel(16)->minutes();
        $this->artisan('transactions:expire')->assertSuccessful();
        $this->assertSame('expired', Transaction::find($expired['id'])->status);
        $this->assertLedgerConsistent(700);

        // Callback terlambat dan job yang berjalan lagi tidak mengembalikan poin dua kali.
        $this->artisan('transactions:expire')->assertSuccessful();
        $this->assertSame(1, PointLedger::where(['type' => 'redeem_release', 'ref_id' => $expired['id']])->count());
        $this->assertLedgerConsistent(700);
    }

    public function test_hold_becomes_final_when_paid(): void
    {
        $this->givePoints(300);
        $transaction = $this->buy('BL15', 'qris', 200)->json('data');

        $this->payCallback($transaction, 'PAID');

        $this->getJson('/api/points')->assertJsonPath('data.held', 0);
        $this->assertLedgerConsistent(100);
    }

    public function test_point_rules_are_enforced_by_server(): void
    {
        $this->givePoints(5000);

        // Kelipatan 100.
        $this->buy('VID30', 'va', 150)->assertStatus(422)->assertJsonPath('code', 'POINTS_INVALID');
        // Maks 20% × Rp65.000 = Rp13.000 = 1.300 poin.
        $this->buy('VID30', 'va', 1400)->assertStatus(422)->assertJsonPath('meta.max_points', 1300);
        $this->buy('VID30', 'va', 1300)->assertCreated()->assertJsonPath('data.net_amount', 52000);
        // Total bayar minimal Rp1.000: HR1 Rp5.000 → maks 20% = 100 poin.
        $this->buy('HR1', 'va', 200)->assertStatus(422)->assertJsonPath('meta.max_points', 100);
        // BL50 Rp135.000: batas 20% = 2.700 poin walau saldo masih 3.700.
        $this->buy('BL50', 'va', 2800)->assertStatus(422)->assertJsonPath('meta.max_points', 2700);
        // Isi ulang tidak bisa memakai poin (FR-12.1).
        $this->withHeader('Idempotency-Key', (string) Str::uuid())
            ->postJson('/api/transactions', ['type' => 'topup', 'topup_amount' => 25000, 'payment_method' => 'va', 'points_used' => 100])
            ->assertStatus(422);
    }

    public function test_points_cannot_exceed_balance(): void
    {
        $this->givePoints(150);

        $this->buy('VID30', 'va', 200)->assertStatus(422)->assertJsonPath('meta.max_points', 100);
        $this->assertLedgerConsistent(150);
    }

    public function test_expiry_is_fifo_and_never_touches_held_points(): void
    {
        $this->givePoints(100, expiresInDays: 3); // paling cepat kedaluwarsa
        $this->givePoints(300);

        // Hold 200: FIFO mengambil 100 poin lama + 100 poin baru.
        $this->buy('BL15', 'va', 200)->assertCreated();

        $this->travel(4)->days();
        $this->artisan('points:expire')->assertSuccessful();

        $this->assertSame(0, PointLedger::where(['user_id' => $this->user->id, 'type' => 'expire'])->count(), 'Poin lama sedang di-hold, tidak ikut hangus');
        $this->assertLedgerConsistent(200);
    }

    public function test_unused_points_expire_after_validity(): void
    {
        $this->givePoints(100, expiresInDays: 3);
        $this->givePoints(50);
        $this->getJson('/api/points')->assertJsonPath('data.expiring_soon.points', 100);

        $this->travel(4)->days();
        $this->artisan('points:expire')->assertSuccessful();
        $this->artisan('points:expire')->assertSuccessful();

        $this->assertSame(-100, (int) PointLedger::where(['user_id' => $this->user->id, 'type' => 'expire'])->sum('delta'));
        $this->assertLedgerConsistent(50);
    }

    public function test_daily_evaluation_earns_points_streak_bonus_and_is_idempotent(): void
    {
        $package = Package::where('code', 'BL50')->first();
        Subscription::create(['subscriber_id' => $this->user->subscriber_id, 'package_id' => $package->id,
            'main_total' => $package->main_quota, 'started_at' => now()->subDays(10), 'expires_at' => now()->addDays(20)]);
        $wa = \App\Models\App::where('package_name', 'com.whatsapp')->value('id');

        foreach (range(7, 1) as $daysAgo) {
            $date = today()->subDays($daysAgo);
            UsageRecord::create(['user_id' => $this->user->id, 'app_id' => $wa, 'usage_date' => $date,
                'bytes_mobile' => 300 * self::MB, 'source' => 'device', 'synced_at' => now()]);
            Forecast::create(['user_id' => $this->user->id, 'computed_at' => $date->copy()->setTime(0, 0, 30), 'main_expires_at' => now()->addDays(20),
                'daily_budget_bytes' => 1700 * self::MB, 'remaining_bytes' => 0, 'confidence' => 'high', 'status' => 'safe']);
            $this->artisan('rewards:evaluate', ['date' => $date->toDateString()])->assertSuccessful();
            $this->artisan('rewards:evaluate', ['date' => $date->toDateString()])->assertSuccessful(); // dua kali, tetap sekali
        }

        $points = $this->getJson('/api/points')->assertOk();
        $points->assertJsonPath('data.streak', 7)
            ->assertJsonPath('data.calendar.29.result', 'hemat')
            ->assertJsonPath('data.calendar.29.points', 60) // hari ke-7: 10 + bonus 50
            ->assertJsonPath('data.calendar.0.result', 'no_data');
        $this->assertLedgerConsistent(7 * 10 + 50);

        $this->getJson('/api/points/ledger')
            ->assertOk()
            ->assertJsonPath('data.0.type', 'earn_streak')
            ->assertJsonPath('data.0.description', 'Bonus hari hemat berturut-turut')
            ->assertJsonPath('meta.total', 8);
    }
}
