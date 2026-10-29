<?php

namespace Tests\Feature;

use App\Models\Package;
use App\Models\Recommendation;
use App\Models\Setting;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\UsageRecord;
use App\Models\User;
use App\Services\PaymentService;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * FR-9 dan FR-10 lewat API: /home, /recommendations, /packages, pembelian dari rekomendasi, forecasts:daily.
 */
class ForecastAndRecommendationTest extends TestCase
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

    /** Paket yang dibeli (paid) $daysAgo hari lalu, supaya ikut dihitung sebagai belanja 30 hari. */
    private function bought(User $user, string $code, int $daysAgo = 2): Subscription
    {
        $package = Package::where('code', $code)->first();
        $transaction = Transaction::create([
            'user_id' => $user->id, 'type' => 'package', 'package_id' => $package->id,
            'gross_amount' => $package->price, 'net_amount' => $package->price, 'payment_method' => 'pulsa',
            'status' => 'paid', 'idempotency_key' => (string) Str::uuid(), 'request_hash' => str_repeat('a', 64),
            'external_ref' => 'KP-T-'.Str::random(6), 'paid_at' => now()->subDays($daysAgo),
        ]);

        return Subscription::create([
            'subscriber_id' => $user->subscriber_id, 'package_id' => $package->id, 'transaction_id' => $transaction->id,
            'main_total' => $package->main_quota, 'app_total' => $package->app_quota, 'app_category' => $package->app_category,
            'started_at' => now()->subDays($daysAgo), 'expires_at' => now()->subDays($daysAgo)->addDays($package->validity_days),
        ]);
    }

    public function test_rina_is_at_risk_and_gets_video_package_even_if_more_expensive(): void
    {
        $rina = $this->actingAsNumber('6288100000001');
        $this->bought($rina, 'BL15');
        $this->postJson('/api/usage/demo', ['profile' => 'rina'])
            ->assertCreated()
            ->assertJsonPath('data.forecast.confidence', 'high');

        $home = $this->getJson('/api/home')->assertOk();
        $home->assertJsonPath('data.forecast.status', 'risk')
            ->assertJsonPath('data.recommendation_teaser', null); // Rp55.000 → Rp65.000: tidak ada penghematan
        $this->assertGreaterThan(0, $home->json('data.forecast.days_early'));
        $this->assertSame(intdiv(15 * self::GB, 28), $home->json('data.daily_budget.budget_bytes'));

        $recommendations = $this->getJson('/api/recommendations')->assertOk();
        $recommendations->assertJsonPath('data.status', 'ok') // BL15 tidak cukup, jadi bukan "sudah paling hemat"
            ->assertJsonPath('data.items.0.package.code', 'VID30')
            ->assertJsonPath('data.items.0.package.app_examples.0', 'TikTok')
            ->assertJsonPath('data.items.0.saving_30d', -10000)
            ->assertJsonPath('data.spent_30d', 55000)
            ->assertJsonCount(3, 'data.items');
        $this->assertStringContainsString('TikTok dan Instagram', $recommendations->json('data.items.0.reason'));
        $this->assertStringContainsString('Video 30 Hari berisi 16 GB kuota video + 12 GB utama, cukup dengan sisa', $recommendations->json('data.items.0.reason'));
        $this->assertNotNull(Recommendation::where('rank', 1)->value('shown_at'));
    }

    public function test_budi_over_buyer_sees_saving_teaser_and_badge(): void
    {
        $budi = $this->actingAsNumber('6288100000002');
        $this->bought($budi, 'BL50');
        $this->postJson('/api/usage/demo', ['profile' => 'budi']);

        $this->getJson('/api/home')
            ->assertJsonPath('data.forecast.status', 'safe')
            ->assertJsonPath('data.recommendation_teaser.package_name', 'Bulanan 15 GB')
            ->assertJsonPath('data.recommendation_teaser.saving_30d', 80000);

        $this->getJson('/api/recommendations')
            ->assertJsonPath('data.items.*.package.code', ['BL15', 'VID30', 'BL25']);

        $bulanan = collect($this->getJson('/api/packages')->json('data.groups'))->firstWhere('type', 'bulanan')['packages'];
        $this->assertSame(['BL15' => true, 'BL25' => false, 'BL50' => false], collect($bulanan)->pluck('is_recommended', 'code')->all());
    }

    public function test_already_cheapest_when_current_package_is_enough(): void
    {
        $budi = $this->actingAsNumber('6288100000002');
        $this->bought($budi, 'BL15');
        $this->postJson('/api/usage/demo', ['profile' => 'budi']);

        $this->getJson('/api/recommendations')
            ->assertJsonPath('data.status', 'already_cheapest')
            ->assertJsonPath('data.items.0.saving_30d', 0);
    }

    public function test_needs_seven_days_of_data(): void
    {
        $user = $this->actingAsNumber('6288100000001');
        $this->postJson('/api/usage/demo', ['profile' => 'rina']);
        UsageRecord::where('usage_date', '<', today()->subDays(5))->delete();

        $this->getJson('/api/recommendations')
            ->assertJsonPath('data.status', 'insufficient_data')
            ->assertJsonPath('data.items', []);
    }

    public function test_click_and_purchase_from_recommendation_are_recorded(): void
    {
        config(['services.payment.webhook_secret' => 'test-secret']);
        $budi = $this->actingAsNumber('6288100000002');
        $this->bought($budi, 'BL50');
        $this->postJson('/api/usage/demo', ['profile' => 'budi']);
        $top = $this->getJson('/api/recommendations')->json('data.items.0');

        $this->postJson("/api/recommendations/{$top['id']}/click")->assertNoContent();
        $this->assertNotNull(Recommendation::find($top['id'])->clicked_at);

        $transaction = $this->withHeader('Idempotency-Key', (string) Str::uuid())->postJson('/api/transactions', [
            'type' => 'package', 'package_id' => $top['package']['id'], 'payment_method' => 'va', 'recommendation_id' => $top['id'],
        ])->assertCreated()->json('data');
        $body = json_encode(['external_ref' => $transaction['external_ref'], 'status' => 'PAID']);
        $this->call('POST', '/api/payments/callback', [], [], [], [
            'CONTENT_TYPE' => 'application/json', 'HTTP_ACCEPT' => 'application/json', 'HTTP_X_SIGNATURE' => PaymentService::sign($body),
        ], $body)->assertOk();

        $this->assertSame($transaction['id'], Recommendation::find($top['id'])->purchased_transaction_id);
        $this->assertGreaterThan(1, $budi->forecasts()->count(), 'Prediksi dihitung ulang setelah pembelian');
    }

    public function test_catalog_change_rebuilds_recommendations(): void
    {
        $budi = $this->actingAsNumber('6288100000002');
        $this->bought($budi, 'BL50');
        $this->postJson('/api/usage/demo', ['profile' => 'budi']);
        $first = $this->getJson('/api/recommendations')->json('data.items.0.id');
        $this->assertSame($first, $this->getJson('/api/recommendations')->json('data.items.0.id'), 'Batch dipakai ulang');

        $this->travel(1)->minutes();
        Package::where('code', 'BL15')->update(['is_active' => false]);
        Setting::where('key', 'catalog.updated_at')->first()->update(['value' => now()->toIso8601String()]);

        $this->getJson('/api/recommendations')
            ->assertJsonPath('data.items.0.package.code', 'VID30');
    }

    public function test_daily_command_recomputes_forecasts_for_users_with_packages(): void
    {
        $rina = User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000001')->value('id')]);
        $this->bought($rina, 'BL15');
        User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000007')->value('id')]); // tanpa paket

        $this->artisan('forecasts:daily')->assertSuccessful();

        $this->assertSame(1, $rina->forecasts()->count());
        $this->assertSame(1, \App\Models\Forecast::count());
    }

    public function test_usage_summary_includes_current_daily_budget(): void
    {
        $rina = $this->actingAsNumber('6288100000001');
        $this->bought($rina, 'BL15');
        $this->postJson('/api/usage/demo', ['profile' => 'rina']);

        $this->getJson('/api/usage/summary?period=7d')
            ->assertJsonPath('data.daily_budget_bytes', intdiv(15 * self::GB, 28));
    }
}
