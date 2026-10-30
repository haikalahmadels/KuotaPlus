<?php

namespace Tests\Feature;

use App\Models\Notification;
use App\Models\Package;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use App\Services\AlertService;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Str;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * FR-13: lima pemicu alert, maksimal 1 per jenis per hari, dan alert hanya dikirim sekali ke client.
 */
class AlertTest extends TestCase
{
    use RefreshDatabase;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);

        // Budi: aktif 40 hari lagi, tanpa paket, jadi tidak ada pemicu kecuali yang dibuat tiap tes.
        $this->user = User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000002')->value('id')]);
        Sanctum::actingAs($this->user);
    }

    private function subscribe(array $overrides = []): Subscription
    {
        $package = Package::where('code', 'BL15')->first();

        return Subscription::create($overrides + [
            'subscriber_id' => $this->user->subscriber_id,
            'package_id' => $package->id,
            'main_total' => $package->main_quota,
            'app_total' => 0,
            'started_at' => now()->subDay(),
            'expires_at' => now()->addDays(20),
        ]);
    }

    private function transaction(string $method, string $status): Transaction
    {
        $package = Package::where('code', 'BL15')->first();

        return $this->user->transactions()->create([
            'type' => 'package',
            'package_id' => $package->id,
            'gross_amount' => $package->price,
            'net_amount' => $package->price,
            'payment_method' => $method,
            'status' => $status,
            'idempotency_key' => (string) Str::uuid(),
            'request_hash' => str_repeat('a', 64),
            'external_ref' => 'KP-'.Str::random(10),
        ]);
    }

    private function riskForecast(): void
    {
        $this->user->forecasts()->create([
            'computed_at' => now(),
            'avg_daily_bytes' => 1073741824,
            'remaining_bytes' => 3221225472,
            'predicted_empty_at' => now()->addDays(3),
            'main_expires_at' => now()->addDays(14),
            'daily_budget_bytes' => 230000000,
            'confidence' => 'high',
            'status' => 'risk',
        ]);
    }

    /** @return list<string> */
    private function homeAlertKinds(): array
    {
        return array_column($this->getJson('/api/home')->assertOk()->json('data.alerts'), 'kind');
    }

    public function test_quota_low_when_main_quota_at_most_20_percent(): void
    {
        $sub = $this->subscribe();
        $sub->update(['main_used' => (int) ($sub->main_total * 0.85)]);

        $alerts = $this->getJson('/api/home')->assertOk()->json('data.alerts');

        $this->assertSame(['quota_low'], array_column($alerts, 'kind'));
        $this->assertSame('/recommendations', $alerts[0]['target']);
        $this->assertStringContainsString('15%', $alerts[0]['body']);
    }

    public function test_no_quota_low_above_20_percent(): void
    {
        $sub = $this->subscribe();
        $sub->update(['main_used' => (int) ($sub->main_total * 0.75)]);

        $this->assertNotContains('quota_low', $this->homeAlertKinds());
    }

    public function test_package_expiring_within_one_day(): void
    {
        $this->subscribe(['expires_at' => now()->addHours(20)]);

        $alerts = $this->getJson('/api/home')->assertOk()->json('data.alerts');

        $this->assertContains('package_expiring', array_column($alerts, 'kind'));
        $this->assertSame('/packages', collect($alerts)->firstWhere('kind', 'package_expiring')['target']);
    }

    public function test_card_expiring_within_three_days(): void
    {
        $this->user->subscriber->update(['active_until' => today()->addDays(2)]);

        $alerts = $this->getJson('/api/home')->assertOk()->json('data.alerts');

        $this->assertSame(['card_expiring'], array_column($alerts, 'kind'));
        $this->assertSame('/topup', $alerts[0]['target']);
    }

    public function test_transaction_status_change_links_to_its_detail(): void
    {
        $transaction = $this->transaction('qris', 'paid');

        $alerts = $this->getJson('/api/home')->assertOk()->json('data.alerts');

        $this->assertSame(['transaction_status'], array_column($alerts, 'kind'));
        $this->assertSame('Pembayaran berhasil', $alerts[0]['title']);
        $this->assertSame('/history/'.$transaction->id, $alerts[0]['target']);
    }

    public function test_pulsa_purchase_does_not_alert_because_status_never_changed(): void
    {
        $this->transaction('pulsa', 'paid');

        $this->assertSame([], $this->homeAlertKinds());
    }

    public function test_forecast_risk_alerts_once_per_risk_episode(): void
    {
        $this->subscribe();
        $this->riskForecast();
        $this->assertSame(['forecast_risk'], $this->homeAlertKinds());

        // Besok masih berisiko: bukan perubahan status, jadi tidak ada alert baru.
        $this->travel(1)->days();
        $this->riskForecast();
        $this->assertSame([], $this->homeAlertKinds());

        // Sempat aman, lalu berisiko lagi: alert baru.
        $this->user->forecasts()->create([
            'computed_at' => now()->subMinute(), 'remaining_bytes' => 0, 'main_expires_at' => now()->addDays(13),
            'confidence' => 'high', 'status' => 'safe',
        ]);
        $this->riskForecast();
        $this->assertSame(['forecast_risk'], $this->homeAlertKinds());
    }

    public function test_same_alert_is_not_repeated_on_the_same_day(): void
    {
        $this->user->subscriber->update(['active_until' => today()->addDay()]);

        $this->assertSame(['card_expiring'], $this->homeAlertKinds());
        // Dikirim sekali: request berikutnya (beranda atau sync) tidak membawanya lagi.
        $this->assertSame([], $this->homeAlertKinds());
        $this->postJson('/api/usage/sync', ['buckets' => []])->assertOk()->assertJsonPath('data.alerts', []);

        // Evaluasi berulang tidak membuat baris kedua untuk jenis yang sama di hari yang sama.
        app(AlertService::class)->evaluate($this->user);
        $this->assertSame(1, Notification::where('user_id', $this->user->id)->where('kind', 'card_expiring')->count());

        // Hari berikutnya boleh muncul lagi.
        $this->travel(1)->days();
        $this->assertSame(['card_expiring'], $this->homeAlertKinds());
    }

    public function test_usage_sync_returns_alerts(): void
    {
        $this->user->subscriber->update(['active_until' => today()->addDays(3)]);

        $this->postJson('/api/usage/sync', ['buckets' => []])
            ->assertOk()
            ->assertJsonPath('data.alerts.0.kind', 'card_expiring');
    }
}
