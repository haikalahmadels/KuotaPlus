<?php

namespace Tests\Feature;

use App\Models\Subscriber;
use App\Models\User;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * Tabel "Hasil yang diharapkan" di docs/SEED-KuotaPlus.md: akun demo hasil `migrate:fresh --seed`
 * harus tetap menceritakan persona yang sama walau aturan bisnis diubah.
 */
class DemoAccountSeederTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();
        config(['services.admin.password' => 'test-password']);
        $this->seed(DatabaseSeeder::class);
    }

    private function as(string $msisdn): void
    {
        $this->app['auth']->forgetGuards();
        Sanctum::actingAs(User::where('subscriber_id', Subscriber::where('msisdn', $msisdn)->value('id'))->sole());
    }

    public function test_rina_is_at_risk_gets_video_package_and_has_points_to_redeem(): void
    {
        $this->as('6288100000001');

        $this->getJson('/api/home')
            ->assertJsonPath('data.forecast.confidence', 'high')
            ->assertJsonPath('data.forecast.status', 'risk')
            ->assertJsonPath('data.subscriptions.0.name', 'Bulanan 15 GB');
        $this->getJson('/api/recommendations')
            ->assertJsonPath('data.items.*.package.code', ['VID30', 'HR3', 'BL50'])
            ->assertJsonPath('data.items.0.saving_30d', 10000)
            ->assertJsonPath('data.spent_30d', 75000);
        $points = $this->getJson('/api/points')->assertJsonPath('data.balance', 520)->assertJsonPath('data.streak', 0);
        $this->assertNotNull($points->json('data.expiring_soon'));
    }

    public function test_budi_over_buyer_saves_80000_after_sharing_and_spike(): void
    {
        $this->as('6288100000002');

        $this->getJson('/api/home')
            ->assertJsonPath('data.forecast.status', 'safe')
            ->assertJsonPath('data.recommendation_teaser.saving_30d', 80000);
        $this->getJson('/api/recommendations')->assertJsonPath('data.items.*.package.code', ['BL15', 'VID30', 'BL25']);
        $this->getJson('/api/points')->assertJsonPath('data.balance', 290)->assertJsonPath('data.streak', 8);
        $this->assertStringStartsWith('Lonjakan tidak biasa', $this->getJson('/api/usage/summary?period=30d')->json('data.insights.0'));
    }

    public function test_dimas_is_new_user_and_andi_received_expired_shared_quota(): void
    {
        $this->as('6288100000003');

        $this->getJson('/api/home')->assertJsonPath('data.forecast.confidence', 'low');
        $this->getJson('/api/recommendations')->assertJsonPath('data.status', 'insufficient_data');
        $this->getJson('/api/points')->assertJsonPath('data.balance', 50);

        $andi = Subscriber::where('msisdn', '6288100000007')->first();
        $this->assertSame(['shared' => 'expired'], $andi->subscriptions()->pluck('status', 'source')->all());
    }
}
