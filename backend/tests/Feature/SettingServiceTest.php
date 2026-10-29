<?php

namespace Tests\Feature;

use App\Models\Setting;
use App\Services\SettingService;
use Database\Seeders\SettingSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\TestCase;

class SettingServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_reads_seeded_values_and_sees_admin_changes(): void
    {
        $this->seed(SettingSeeder::class);
        $settings = app(SettingService::class);

        $this->assertSame(10, $settings->int('reward.points_per_day'));
        $this->assertSame(5000, $settings->get('topup.options')[0]['amount']);

        // Perubahan dari panel admin langsung terbaca karena cache dihapus saat model disimpan.
        Setting::where('key', 'reward.points_per_day')->first()->update(['value' => 15]);
        $this->assertSame(15, $settings->int('reward.points_per_day'));
    }
}
