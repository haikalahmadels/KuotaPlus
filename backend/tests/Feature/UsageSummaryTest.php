<?php

namespace Tests\Feature;

use App\Models\App;
use App\Models\Subscriber;
use App\Models\UsageRecord;
use App\Models\User;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use Database\Seeders\SettingSeeder;
use Database\Seeders\SubscriberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Laravel\Sanctum\Sanctum;
use Tests\TestCase;

/**
 * POST /usage/demo (FR-7.8) dan GET /usage/summary, /usage/apps/{id} (FR-8).
 */
class UsageSummaryTest extends TestCase
{
    use RefreshDatabase;

    private const MB = 1048576;

    private User $user;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
        $this->user = User::create(['subscriber_id' => Subscriber::where('msisdn', '6288100000001')->value('id')]);
        Sanctum::actingAs($this->user);
    }

    private function record(string $package, int $mb, int $daysAgo): void
    {
        UsageRecord::create([
            'user_id' => $this->user->id,
            'app_id' => App::where('package_name', $package)->value('id'),
            'usage_date' => today()->subDays($daysAgo)->toDateString(),
            'bytes_mobile' => $mb * self::MB,
            'source' => 'device',
            'synced_at' => now(),
        ]);
    }

    public function test_demo_generates_30_days_plus_partial_today_and_can_switch_profile(): void
    {
        $this->postJson('/api/usage/demo', ['profile' => 'rina'])->assertCreated()->assertJsonPath('data.days', 30);

        $dates = UsageRecord::distinct()->orderBy('usage_date')->pluck('usage_date');
        $this->assertCount(31, $dates);
        $this->assertSame(today()->subDays(30)->toDateString(), $dates->first()->toDateString());

        $today = (int) UsageRecord::whereDate('usage_date', today())->sum('bytes_mobile');
        $pattern = [1 => 690, 940, 690, 940, 690, 840, 840][today()->dayOfWeekIso];
        $this->assertEqualsWithDelta($pattern * 0.35 * self::MB, $today, 7 * self::MB);

        $this->postJson('/api/usage/demo', ['profile' => 'budi'])->assertCreated();
        $this->assertFalse(UsageRecord::whereHas('app', fn ($q) => $q->where('package_name', 'com.zhiliaoapp.musically'))->exists());
        $this->getJson('/api/usage/summary?period=7d')->assertJsonPath('data.source', 'demo');
    }

    public function test_demo_is_refused_when_device_data_exists(): void
    {
        $this->record('com.whatsapp', 10, 0);

        $this->postJson('/api/usage/demo', ['profile' => 'rina'])->assertStatus(409)->assertJsonPath('code', 'DEVICE_DATA_EXISTS');
        $this->postJson('/api/usage/demo', ['profile' => 'lain'])->assertStatus(422);
    }

    public function test_summary_without_data_is_empty(): void
    {
        $this->getJson('/api/usage/summary')
            ->assertOk()
            ->assertJsonPath('data.period', '7d')
            ->assertJsonPath('data.source', null)
            ->assertJsonPath('data.total_bytes', 0)
            ->assertJsonPath('data.apps', [])
            ->assertJsonCount(7, 'data.daily');
    }

    public function test_summary_groups_top_five_plus_others_and_merges_same_label(): void
    {
        $this->record('com.zhiliaoapp.musically', 300, 1);
        $this->record('com.ss.android.ugc.trill', 100, 2); // TikTok build lain → satu baris
        $this->record('com.instagram.android', 200, 1);
        $this->record('com.whatsapp', 150, 1);
        $this->record('com.google.android.youtube', 100, 1);
        $this->record('com.android.chrome', 90, 1);
        $this->record('com.shopee.id', 40, 1);
        $this->record('com.google.android.gm', 20, 1);

        $response = $this->getJson('/api/usage/summary?period=7d')->assertOk();

        $response->assertJsonPath('data.total_bytes', 1000 * self::MB)
            ->assertJsonPath('data.apps.0.label', 'TikTok')
            ->assertJsonPath('data.apps.0.bytes', 400 * self::MB)
            ->assertJsonPath('data.apps.0.percent', 40)
            ->assertJsonCount(7, 'data.apps')
            ->assertJsonCount(6, 'data.top_apps')
            ->assertJsonPath('data.top_apps.5.label', 'Lainnya')
            ->assertJsonPath('data.top_apps.5.bytes', 60 * self::MB);
        $this->assertSame('TikTok memakai 40% kuotamu minggu ini.', $response->json('data.insights.0'));
    }

    public function test_spike_and_weekly_growth_insights(): void
    {
        // 7 hari terakhir vs 7 hari sebelumnya: WhatsApp tetap, TikTok naik dari 100 ke 130 MB/hari (30%).
        foreach (range(0, 13) as $daysAgo) {
            $this->record('com.whatsapp', 100, $daysAgo);
            $this->record('com.zhiliaoapp.musically', $daysAgo <= 6 ? 130 : 100, $daysAgo);
        }
        $this->record('android.system', 3072, 0); // update OS hari ini

        $response = $this->getJson('/api/usage/summary?period=7d')->assertOk();

        $this->assertTrue($response->json('data.daily.6.is_spike'));
        $this->assertFalse($response->json('data.daily.5.is_spike'));
        // Sistem Android: 3072 / (700 + 910 + 3072) MB = 65,6%.
        $this->assertSame([
            'Sistem Android memakai 65,6% kuotamu minggu ini.',
            'TikTok naik 30% dari minggu lalu.',
            'Lonjakan tidak biasa pada '.today()->locale('id')->translatedFormat('j M').': 3,2 GB dalam sehari.',
        ], $response->json('data.insights'));
    }

    public function test_app_detail_merges_same_label_and_averages_per_day(): void
    {
        $this->record('com.zhiliaoapp.musically', 300, 1);
        $this->record('com.ss.android.ugc.trill', 100, 2);

        $trill = App::where('package_name', 'com.ss.android.ugc.trill')->value('id');

        $this->getJson("/api/usage/apps/{$trill}?period=7d")
            ->assertOk()
            ->assertJsonPath('data.app.label', 'TikTok')
            ->assertJsonPath('data.total_bytes', 400 * self::MB)
            ->assertJsonPath('data.avg_daily_bytes', intdiv(400 * self::MB, 7))
            ->assertJsonCount(7, 'data.daily');
    }
}
