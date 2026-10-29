<?php

namespace Tests\Feature;

use App\Models\App;
use App\Models\Package;
use App\Models\Subscriber;
use App\Models\Subscription;
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
 * POST /usage/sync (FR-7.5–7.7) dan edge case Data/Kuota.
 */
class UsageSyncTest extends TestCase
{
    use RefreshDatabase;

    private const MB = 1048576;

    private const GB = 1073741824;

    private User $user;

    private int $subscriberId;

    protected function setUp(): void
    {
        parent::setUp();
        $this->seed([SettingSeeder::class, AppSeeder::class, PackageSeeder::class, SubscriberSeeder::class]);
        $this->subscriberId = Subscriber::where('msisdn', '6288100000001')->value('id');
        $this->user = User::create(['subscriber_id' => $this->subscriberId]);
        Sanctum::actingAs($this->user);
    }

    private function subscribe(string $code, array $overrides = []): Subscription
    {
        $package = Package::where('code', $code)->first();

        return Subscription::create($overrides + [
            'subscriber_id' => $this->subscriberId,
            'package_id' => $package->id,
            'main_total' => $package->main_quota,
            'app_total' => $package->app_quota,
            'app_category' => $package->app_category,
            'started_at' => now()->subDays(10),
            'expires_at' => now()->addDays(20),
        ]);
    }

    private function sync(array $buckets)
    {
        return $this->postJson('/api/usage/sync', ['buckets' => $buckets]);
    }

    private function bucket(string $package, int $mb, ?string $date = null, ?string $label = null): array
    {
        return [
            'usage_date' => $date ?? today()->toDateString(),
            'package_name' => $package,
            'label' => $label ?? $package,
            'bytes_mobile' => $mb * self::MB,
        ];
    }

    public function test_repeated_sync_only_charges_the_delta(): void
    {
        $bl15 = $this->subscribe('BL15');

        $this->sync([$this->bucket('com.whatsapp', 100)])->assertOk()->assertJsonPath('data.applied_bytes', 100 * self::MB);
        $this->sync([$this->bucket('com.whatsapp', 100)])->assertOk()->assertJsonPath('data.applied_bytes', 0);
        $this->sync([$this->bucket('com.whatsapp', 150)])->assertOk()->assertJsonPath('data.applied_bytes', 50 * self::MB);

        $this->assertSame(150 * self::MB, $bl15->fresh()->main_used);
        $record = UsageRecord::sole();
        $this->assertSame(150 * self::MB, $record->bytes_mobile);
        $this->assertSame('device', $record->source);
    }

    public function test_shrinking_value_is_ignored(): void
    {
        $bl15 = $this->subscribe('BL15');
        $this->sync([$this->bucket('com.whatsapp', 100)]);

        $this->sync([$this->bucket('com.whatsapp', 60)])->assertOk()->assertJsonPath('data.applied_bytes', 0);

        $this->assertSame(100 * self::MB, $bl15->fresh()->main_used);
        $this->assertSame(100 * self::MB, UsageRecord::sole()->bytes_mobile);
    }

    public function test_future_and_too_old_dates_are_rejected_per_bucket(): void
    {
        $this->sync([
            $this->bucket('com.whatsapp', 10, today()->addDay()->toDateString()),
            $this->bucket('com.whatsapp', 10, today()->subDays(8)->toDateString()),
            $this->bucket('com.whatsapp', 10, today()->subDays(7)->toDateString()),
        ])
            ->assertOk()
            ->assertJsonPath('data.accepted', 1)
            ->assertJsonPath('data.rejected', [['index' => 0, 'reason' => 'FUTURE_DATE'], ['index' => 1, 'reason' => 'TOO_OLD']]);
    }

    public function test_unknown_app_is_created_as_unreviewed_umum(): void
    {
        $this->sync([$this->bucket('com.example.baru', 5, label: 'Aplikasi Baru')])->assertOk();

        $app = App::where('package_name', 'com.example.baru')->sole();
        $this->assertSame(['Aplikasi Baru', 'umum', false], [$app->label, $app->category, $app->is_reviewed]);
    }

    public function test_app_quota_is_used_first_then_main_quota_of_soonest_expiring_package(): void
    {
        $later = $this->subscribe('BL15', ['expires_at' => now()->addDays(20)]);
        $sooner = $this->subscribe('HR1', ['expires_at' => now()->addHours(5)]);
        $video = $this->subscribe('VID30', ['expires_at' => now()->addDays(25)]);

        // 18 GB YouTube: 16 GB kuota video, sisa 2 GB → HR1 (1 GB, paling cepat berakhir) → 1 GB dari VID30? Tidak:
        // urutan kuota utama mengikuti expires_at: HR1, BL15, VID30.
        $this->sync([$this->bucket('com.google.android.youtube', 18 * 1024)]);

        $this->assertSame(16 * self::GB, $video->fresh()->app_used);
        $this->assertSame(self::GB, $sooner->fresh()->main_used);
        $this->assertSame('exhausted', $sooner->fresh()->status);
        $this->assertSame(self::GB, $later->fresh()->main_used);
        $this->assertSame(0, $video->fresh()->main_used);
        $this->assertSame('active', $video->fresh()->status, 'Kuota utama VID30 masih ada');
    }

    public function test_only_packages_active_on_the_usage_date_are_charged(): void
    {
        $newPackage = $this->subscribe('BL15', ['started_at' => now()->startOfDay()->addHours(7)]);

        // Riwayat 3 hari lalu pada sync pertama tidak membebani paket yang baru dibeli hari ini.
        $this->sync([$this->bucket('com.whatsapp', 500, today()->subDays(3)->toDateString())])
            ->assertJsonPath('data.applied_bytes', 0);

        $this->assertSame(0, $newPackage->fresh()->main_used);
        $this->assertSame(1, UsageRecord::count(), 'Pemakaian tetap tercatat untuk analisis');
    }

    public function test_exhausted_quota_does_not_charge_pulsa_and_is_not_billed_later(): void
    {
        $hr1 = $this->subscribe('HR1');

        $this->sync([$this->bucket('com.whatsapp', 1500)])->assertJsonPath('data.applied_bytes', self::GB);
        $this->assertSame('exhausted', $hr1->fresh()->status);
        $this->assertSame(12500, Subscriber::find($this->subscriberId)->pulsa_balance, 'OQ-11: pulsa tidak dipotong');

        // Paket baru dibeli setelahnya tidak menanggung kelebihan pemakaian sebelumnya.
        $bl15 = $this->subscribe('BL15', ['started_at' => now()->subHour()]);
        $this->sync([$this->bucket('com.whatsapp', 1500)])->assertJsonPath('data.applied_bytes', 0);
        $this->assertSame(0, $bl15->fresh()->main_used);
    }

    public function test_device_sync_replaces_demo_data(): void
    {
        $this->postJson('/api/usage/demo', ['profile' => 'rina'])->assertCreated();
        $this->assertTrue(UsageRecord::where('source', 'demo')->exists());

        $this->sync([$this->bucket('com.whatsapp', 10)])->assertOk();

        $this->assertSame(['device'], UsageRecord::distinct()->pluck('source')->all());
    }
}
