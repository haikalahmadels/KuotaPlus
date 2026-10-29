<?php

namespace Database\Seeders;

use App\Models\Setting;
use Illuminate\Database\Seeder;

/**
 * Nilai awal tabel settings. Sumber: docs/SEED-KuotaPlus.md bagian Settings.
 */
class SettingSeeder extends Seeder
{
    private const MB = 1048576;

    private const GB = 1073741824;

    public function run(): void
    {
        $rows = [
            // key => [default, min, max]
            'reward.points_per_day' => [10, 1, 100],
            'reward.streak_length' => [7, 2, 30],
            'reward.streak_bonus' => [50, 0, 500],
            'reward.min_usage_bytes' => [50 * self::MB, 0, self::GB],
            'points.rupiah_per_point' => [10, 1, 100],
            'points.redeem_step' => [100, 1, 1000],
            'points.max_discount_percent' => [20, 0, 50],
            'points.min_net_amount' => [1000, 0, 10000],
            'points.validity_days' => [90, 7, 365],
            'card.grace_days' => [15, 0, 60],
            'share.limit_bytes_30d' => [2 * self::GB, 500 * self::MB, 10 * self::GB],
            'share.min_remaining_bytes' => [2 * self::GB, 0, 10 * self::GB],
            'share.step_bytes' => [500 * self::MB, 100 * self::MB, 2 * self::GB],
            'share.points_per_step' => [100, 0, 1000],
            'share.validity_days' => [7, 1, 30],
            'notify.quota_low_percent' => [20, 5, 50],
            'notify.package_expiring_days' => [1, 1, 7],
            'notify.card_expiring_days' => [3, 1, 14],
            // Tabel nominal; validasi per baris dilakukan di form admin.
            'topup.options' => [[
                ['amount' => 5000, 'extend_days' => 7],
                ['amount' => 10000, 'extend_days' => 15],
                ['amount' => 25000, 'extend_days' => 30],
                ['amount' => 50000, 'extend_days' => 45],
                ['amount' => 100000, 'extend_days' => 60],
            ], null, null],
        ];

        foreach ($rows as $key => [$value, $min, $max]) {
            Setting::updateOrCreate(['key' => $key], ['value' => $value, 'min' => $min, 'max' => $max, 'is_system' => false]);
        }

        Setting::updateOrCreate(['key' => 'catalog.updated_at'], ['value' => now()->toIso8601String(), 'is_system' => true]);
    }
}
