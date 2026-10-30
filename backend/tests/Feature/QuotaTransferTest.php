<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Package;
use App\Models\PointLedger;
use App\Models\QuotaTransfer;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\User;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * DoD "Aturan berbagi kuota" (FR-14): batas 30 hari, sisa minimal, poin, penerima, OTP khusus transfer,
 * idempotensi, dan pemotongan kuota yang tepat.
 */
class QuotaTransferTest extends TestCase
{
    use RefreshDatabase;

    private const GB = 1073741824;

    private const HALF = self::GB / 2;

    private const ANDI = '6288100000007';

    private User $budi;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
        config(['services.otp.expose_code' => true]);

        $this->budi = User::create(['subscriber_id' => $this->subscriberId('6288100000002')]);
        Sanctum::actingAs($this->budi);
    }

    private function subscriberId(string $msisdn): int
    {
        return Subscriber::where('msisdn', $msisdn)->value('id');
    }

    private function package(int $mainBytes, array $overrides = []): Subscription
    {
        return Subscription::create($overrides + [
            'subscriber_id' => $this->budi->subscriber_id,
            'package_id' => Package::where('code', 'BL15')->value('id'),
            'main_total' => $mainBytes,
            'app_total' => 0,
            'started_at' => now()->subDay(),
            'expires_at' => now()->addDays(20),
        ]);
    }

    private function givePoints(int $points): void
    {
        PointLedger::create([
            'user_id' => $this->budi->id, 'delta' => $points, 'type' => 'earn_daily',
            'ref_type' => 'daily_evaluations', 'ref_id' => 0, 'remaining' => $points, 'expires_at' => now()->addDays(60),
        ]);
    }

    /** Minta OTP lalu eksekusi; mengembalikan respons POST /quota-transfers. */
    private function share(int $bytes, string $recipient = self::ANDI, ?string $key = null)
    {
        $code = $this->postJson('/api/quota-transfers/otp', ['recipient_msisdn' => $recipient, 'bytes' => $bytes])
            ->assertOk()
            ->json('data.demo_otp');

        return $this->postJson('/api/quota-transfers',
            ['recipient_msisdn' => $recipient, 'bytes' => $bytes, 'otp_code' => $code],
            ['Idempotency-Key' => $key ?? (string) Str::uuid()]);
    }

    private function option(array $quote, int $bytes): array
    {
        return collect($quote['options'])->firstWhere('bytes', $bytes);
    }

    public function test_quote_lists_four_options_with_cost_and_expiry(): void
    {
        $this->package(10 * self::GB);
        $this->givePoints(1000);

        $quote = $this->getJson('/api/quota-transfers/quote?recipient_msisdn=0881-0000-0007')->assertOk()->json('data');

        $this->assertSame('0881••••0007', $quote['recipient']['msisdn_masked']);
        $this->assertSame([self::HALF, self::GB, self::GB + self::HALF, 2 * self::GB], array_column($quote['options'], 'bytes'));
        $this->assertSame([100, 200, 300, 400], array_column($quote['options'], 'points_cost'));
        $this->assertTrue($this->option($quote, 2 * self::GB)['allowed']);
        $this->assertSame(8 * self::GB, $this->option($quote, 2 * self::GB)['sender_main_remaining_after']);
    }

    public function test_recipient_must_be_active_subscriber_and_not_self(): void
    {
        $quote = fn (string $msisdn) => $this->getJson('/api/quota-transfers/quote?recipient_msisdn='.$msisdn);

        $quote('089999999999')->assertStatus(422)->assertJsonPath('code', 'RECIPIENT_NOT_SUBSCRIBER');
        $quote('0881-0000-0005')->assertStatus(422)->assertJsonPath('code', 'RECIPIENT_INACTIVE'); // Sari, masa tenggang
        $quote('0881-0000-0006')->assertStatus(422)->assertJsonPath('code', 'RECIPIENT_INACTIVE'); // terminated
        $quote('0881-0000-0002')->assertStatus(422)->assertJsonPath('code', 'RECIPIENT_IS_SELF');
    }

    public function test_successful_share_moves_exact_bytes_cuts_points_and_alerts_recipient(): void
    {
        $sub = $this->package(10 * self::GB);
        $this->givePoints(500);
        $andi = User::create(['subscriber_id' => $this->subscriberId(self::ANDI)]);

        $response = $this->share(self::GB)->assertStatus(201)
            ->assertJsonPath('data.bytes', self::GB)
            ->assertJsonPath('data.points_spent', 200)
            ->assertJsonPath('data.status', 'completed')
            ->assertJsonPath('data.sender_main_remaining_after', 9 * self::GB);

        $transfer = QuotaTransfer::findOrFail($response->json('data.id'));
        $received = $transfer->recipientSubscription;
        $this->assertSame(self::GB, $sub->fresh()->main_used);
        $this->assertSame(self::GB, (int) $transfer->sources()->sum('bytes'));
        $this->assertSame('shared', $received->source);
        $this->assertSame(self::GB, $received->main_total);
        $this->assertNull($received->package_id);
        $this->assertSame(300, $this->budi->pointBalance());
        $this->assertSame(-200, (int) PointLedger::where(['user_id' => $this->budi->id, 'type' => 'spend_share'])->sum('delta'));
        $this->assertTrue(Notification::where(['user_id' => $andi->id, 'kind' => 'quota_received'])->exists());

        $this->getJson('/api/quota-transfers')->assertOk()
            ->assertJsonPath('data.0.id', $transfer->id)
            ->assertJsonMissingPath('data.0.sender_main_remaining_after');
    }

    public function test_cuts_earliest_expiring_package_first_and_recipient_expiry_follows_last_source(): void
    {
        $soon = $this->package(3 * self::GB, ['expires_at' => now()->addDays(3), 'main_used' => 3 * self::GB - self::HALF]);
        $later = $this->package(10 * self::GB, ['expires_at' => now()->addDays(5)]);
        $this->givePoints(500);

        $transfer = QuotaTransfer::findOrFail($this->share(self::GB)->assertStatus(201)->json('data.id'));

        $this->assertSame([$soon->id => self::HALF, $later->id => self::HALF],
            $transfer->sources()->pluck('bytes', 'subscription_id')->map(fn ($b) => (int) $b)->all());
        $this->assertSame('exhausted', $soon->fresh()->status);
        // Paket sumber terakhir berakhir 5 hari lagi, lebih awal dari batas 7 hari (FR-14.8).
        $this->assertTrue($transfer->expires_at->eq($later->expires_at));
    }

    public function test_recipient_expiry_capped_at_seven_days(): void
    {
        $this->package(10 * self::GB, ['expires_at' => now()->addDays(25)]);
        $this->givePoints(500);

        $transfer = QuotaTransfer::findOrFail($this->share(self::HALF)->assertStatus(201)->json('data.id'));

        $this->assertEqualsWithDelta(now()->addDays(7)->timestamp, $transfer->expires_at->timestamp, 5);
    }

    public function test_thirty_day_allowance_of_two_gb(): void
    {
        $this->package(20 * self::GB);
        $this->givePoints(2000);
        $this->share(self::GB + self::HALF)->assertStatus(201);

        $quote = $this->getJson('/api/quota-transfers/quote?recipient_msisdn='.self::ANDI)->json('data');
        $this->assertSame(self::HALF, $quote['allowance']['remaining_bytes']);
        $this->assertSame(now()->addDays(30)->toDateString(), $quote['allowance']['recovers_at']);
        $this->assertTrue($this->option($quote, self::HALF)['allowed']);
        $this->assertFalse($this->option($quote, self::GB)['allowed']);
        $this->assertStringContainsString('jatah berbagi', $this->option($quote, self::GB)['reason']);

        $this->postJson('/api/quota-transfers/otp', ['recipient_msisdn' => self::ANDI, 'bytes' => self::GB])
            ->assertStatus(422)->assertJsonPath('code', 'SHARE_NOT_ALLOWED');

        // Setelah 30 hari, jatah pulih.
        $this->travel(31)->days();
        $this->package(20 * self::GB);
        $this->assertTrue($this->option($this->getJson('/api/quota-transfers/quote?recipient_msisdn='.self::ANDI)->json('data'), 2 * self::GB)['allowed']);
    }

    public function test_must_keep_two_gb_main_quota(): void
    {
        $this->package(3 * self::GB);
        $this->givePoints(1000);

        $quote = $this->getJson('/api/quota-transfers/quote?recipient_msisdn='.self::ANDI)->json('data');

        $this->assertTrue($this->option($quote, self::GB)['allowed']);
        $this->assertFalse($this->option($quote, self::GB + self::HALF)['allowed']);
        $this->assertStringContainsString('minimal 2 GB', $this->option($quote, self::GB + self::HALF)['reason']);
    }

    public function test_not_enough_points_is_rejected_without_cutting_anything(): void
    {
        $sub = $this->package(10 * self::GB);
        $this->givePoints(150);

        $quote = $this->getJson('/api/quota-transfers/quote?recipient_msisdn='.self::ANDI)->json('data');
        $this->assertTrue($this->option($quote, self::HALF)['allowed']);
        $this->assertFalse($this->option($quote, self::GB)['allowed']);
        $this->assertStringContainsString('Poin tidak cukup', $this->option($quote, self::GB)['reason']);

        $this->postJson('/api/quota-transfers/otp', ['recipient_msisdn' => self::ANDI, 'bytes' => self::GB])
            ->assertStatus(422)->assertJsonPath('code', 'SHARE_NOT_ALLOWED');
        $this->assertSame(0, $sub->fresh()->main_used);
        $this->assertSame(150, $this->budi->pointBalance());
    }

    public function test_shared_quota_received_from_others_cannot_be_reshared(): void
    {
        $this->package(10 * self::GB, ['source' => 'shared', 'package_id' => null]);
        $this->givePoints(1000);

        $quote = $this->getJson('/api/quota-transfers/quote?recipient_msisdn='.self::ANDI)->json('data');

        $this->assertSame(0, $quote['sender_main_remaining_bytes']);
        $this->assertFalse($this->option($quote, self::HALF)['allowed']);
    }

    public function test_login_otp_cannot_confirm_a_transfer_and_otp_is_bound_to_recipient_and_amount(): void
    {
        $this->package(10 * self::GB);
        $this->givePoints(1000);

        $login = $this->postJson('/api/auth/otp/request', ['msisdn' => '0881-0000-0002'])->json('data.demo_otp');
        $this->postJson('/api/quota-transfers',
            ['recipient_msisdn' => self::ANDI, 'bytes' => self::GB, 'otp_code' => $login],
            ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(422)->assertJsonPath('code', 'OTP_EXPIRED');

        // OTP untuk 500 MB tidak berlaku untuk 1 GB.
        $code = $this->postJson('/api/quota-transfers/otp', ['recipient_msisdn' => self::ANDI, 'bytes' => self::HALF])->json('data.demo_otp');
        $this->postJson('/api/quota-transfers',
            ['recipient_msisdn' => self::ANDI, 'bytes' => self::GB, 'otp_code' => $code],
            ['Idempotency-Key' => (string) Str::uuid()])
            ->assertStatus(422)->assertJsonPath('code', 'OTP_INVALID');

        $this->assertSame(0, QuotaTransfer::count());
    }

    public function test_retry_with_same_key_returns_the_same_transfer_and_mismatch_is_rejected(): void
    {
        $this->package(10 * self::GB);
        $this->givePoints(1000);
        $key = (string) Str::uuid();

        $first = $this->share(self::GB, key: $key)->assertStatus(201)->json('data.id');
        // Retry setelah jaringan putus: OTP sudah hangus, tetapi replay tetap dikenali.
        $this->postJson('/api/quota-transfers', ['recipient_msisdn' => self::ANDI, 'bytes' => self::GB, 'otp_code' => '000000'],
            ['Idempotency-Key' => $key])
            ->assertStatus(200)->assertJsonPath('data.id', $first);
        $this->postJson('/api/quota-transfers', ['recipient_msisdn' => self::ANDI, 'bytes' => self::HALF, 'otp_code' => '000000'],
            ['Idempotency-Key' => $key])
            ->assertStatus(422)->assertJsonPath('code', 'IDEMPOTENCY_KEY_MISMATCH');

        $this->assertSame(1, QuotaTransfer::count());
        $this->assertSame(800, $this->budi->pointBalance());
    }

    public function test_idempotency_key_is_required(): void
    {
        $this->postJson('/api/quota-transfers', ['recipient_msisdn' => self::ANDI, 'bytes' => self::GB, 'otp_code' => '123456'])
            ->assertStatus(400)->assertJsonPath('code', 'IDEMPOTENCY_KEY_REQUIRED');
    }
}
