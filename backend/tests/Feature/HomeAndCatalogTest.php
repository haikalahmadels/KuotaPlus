<?php

namespace Tests\Feature;

use App\Models\Package;
use App\Models\QuotaTransfer;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\User;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * FR-2, FR-3.1–3.2, FR-4.1: GET /home, PUT /device, GET /packages, GET /topup-options.
 */
class HomeAndCatalogTest extends TestCase
{
    use RefreshDatabase;

    private const GB = 1073741824;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
    }

    private function actingAsNumber(string $msisdn): User
    {
        $user = User::create(['subscriber_id' => Subscriber::where('msisdn', $msisdn)->value('id')]);
        Sanctum::actingAs($user);

        return $user;
    }

    private function subscribe(string $msisdn, string $code, array $overrides = []): Subscription
    {
        $package = Package::where('code', $code)->first();

        return Subscription::create($overrides + [
            'subscriber_id' => Subscriber::where('msisdn', $msisdn)->value('id'),
            'package_id' => $package->id,
            'main_total' => $package->main_quota,
            'app_total' => $package->app_quota,
            'app_category' => $package->app_category,
            'started_at' => now()->subDay(),
            'expires_at' => now()->addDays(10),
        ]);
    }

    public function test_home_requires_login(): void
    {
        $this->getJson('/api/home')->assertStatus(401)->assertJsonPath('code', 'UNAUTHENTICATED');
    }

    public function test_home_shows_subscriber_and_seeded_package_for_uji_hp(): void
    {
        $this->actingAsNumber('6288100000004');

        $this->getJson('/api/home')
            ->assertOk()
            ->assertJsonPath('data.subscriber.pulsa_balance', 100000)
            ->assertJsonPath('data.subscriber.days_left', 60)
            ->assertJsonPath('data.subscriber.status', 'active')
            ->assertJsonCount(1, 'data.subscriptions')
            ->assertJsonPath('data.subscriptions.0.name', 'Bulanan 25 GB')
            ->assertJsonPath('data.subscriptions.0.main_remaining', 25 * self::GB)
            ->assertJsonPath('data.points', ['balance' => 0, 'streak' => 0])
            ->assertJsonPath('data.usage', ['source' => null, 'last_synced_at' => null])
            ->assertJsonPath('data.forecast', null);
    }

    public function test_home_lists_current_packages_soonest_first_and_hides_expired(): void
    {
        $this->actingAsNumber('6288100000001');
        $this->subscribe('6288100000001', 'BL15', ['expires_at' => now()->addDays(20)]);
        $this->subscribe('6288100000001', 'VID30', ['expires_at' => now()->addDays(5), 'app_used' => self::GB]);
        $this->subscribe('6288100000001', 'HR1', ['main_used' => self::GB, 'status' => 'exhausted', 'expires_at' => now()->addHours(3)]);
        $this->subscribe('6288100000001', 'MG5', ['status' => 'expired', 'expires_at' => now()->subDay()]);
        $this->subscribe('6288100000001', 'MG10', ['expires_at' => now()->subMinute()]); // belum diproses job

        $this->getJson('/api/home')
            ->assertOk()
            ->assertJsonPath('data.subscriptions.*.name', ['Harian 1 GB', 'Video 30 Hari', 'Bulanan 15 GB'])
            ->assertJsonPath('data.subscriptions.0.status', 'exhausted')
            ->assertJsonPath('data.subscriptions.0.main_remaining', 0)
            ->assertJsonPath('data.subscriptions.1.app_category', 'video')
            ->assertJsonPath('data.subscriptions.1.app_remaining', 15 * self::GB);
    }

    public function test_shared_quota_shows_masked_sender(): void
    {
        $budi = User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000002')->value('id')]);
        $this->actingAsNumber('6288100000007');

        $shared = Subscription::create([
            'subscriber_id' => Subscriber::where('msisdn', '6288100000007')->value('id'),
            'source' => 'shared',
            'main_total' => self::GB,
            'started_at' => now(),
            'expires_at' => now()->addDays(7),
        ]);
        QuotaTransfer::create([
            'sender_user_id' => $budi->id,
            'recipient_subscriber_id' => $shared->subscriber_id,
            'bytes' => self::GB,
            'points_spent' => 200,
            'recipient_subscription_id' => $shared->id,
            'expires_at' => $shared->expires_at,
            'idempotency_key' => fake()->uuid(),
            'request_hash' => str_repeat('a', 64),
            'status' => 'completed',
            'completed_at' => now(),
        ]);

        $this->getJson('/api/home')
            ->assertJsonPath('data.subscriptions.0.name', 'Kuota dari 0881••••0002')
            ->assertJsonPath('data.subscriptions.0.shared_from', '0881••••0002');
    }

    public function test_grace_subscriber_sees_grace_date(): void
    {
        $this->actingAsNumber('6288100000005');

        $this->getJson('/api/home')
            ->assertJsonPath('data.subscriber.status', 'grace')
            ->assertJsonPath('data.subscriber.days_left', 0)
            ->assertJsonPath('data.subscriber.grace_until', today()->addDays(12)->toDateString())
            ->assertJsonPath('data.subscriptions', []);
    }

    public function test_device_report_is_stored(): void
    {
        $user = $this->actingAsNumber('6288100000004');

        $this->putJson('/api/device', ['platform' => 'android', 'usage_access_granted' => true])->assertNoContent();
        $this->putJson('/api/device', ['platform' => 'ios', 'usage_access_granted' => true])
            ->assertStatus(422)->assertJsonPath('code', 'VALIDATION_FAILED');

        $user->refresh();
        $this->assertSame('android', $user->platform);
        $this->assertTrue($user->usage_access_granted);
        $this->assertNotNull($user->usage_access_checked_at);
    }

    public function test_packages_grouped_active_only_with_app_examples_and_point_rules(): void
    {
        $this->actingAsNumber('6288100000001');

        $response = $this->getJson('/api/packages')->assertOk();

        $this->assertSame(['harian', 'mingguan', 'bulanan', 'aplikasi'], $response->json('data.groups.*.type'));
        $this->assertSame(['HR1', 'HR2', 'HR3'], $response->json('data.groups.0.packages.*.code')); // HR05 nonaktif
        $this->assertSame(['SOS30', 'VID30'], $response->json('data.groups.3.packages.*.code'));
        $this->assertSame(['TikTok', 'YouTube', 'Netflix', 'Vidio'], $response->json('data.groups.3.packages.1.app_examples'));
        $response->assertJsonPath('data.points', [
            'balance' => 0,
            'rupiah_per_point' => 10,
            'redeem_step' => 100,
            'max_discount_percent' => 20,
            'min_net_amount' => 1000,
        ]);
    }

    public function test_topup_options_come_from_settings(): void
    {
        $this->actingAsNumber('6288100000001');

        $this->getJson('/api/topup-options')
            ->assertOk()
            ->assertJsonCount(5, 'data')
            ->assertJsonPath('data.0', ['amount' => 5000, 'extend_days' => 7]);
    }
}
