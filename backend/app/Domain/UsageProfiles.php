<?php

namespace App\Domain;

use Carbon\CarbonInterface;
use InvalidArgumentException;

/**
 * Profil pemakaian dari docs/SEED-KuotaPlus.md. Dipakai Mode Demo, seeder akun demo, dan unit test.
 * Satuan MB per aplikasi (package_name) per hari.
 */
final class UsageProfiles
{
    public const PROFILES = ['rina', 'budi', 'random'];

    /** Pola mingguan, indeks 0 = Senin … 6 = Minggu. */
    private const WEEKLY = [
        'rina' => [
            'com.zhiliaoapp.musically' => [380, 380, 380, 380, 380, 480, 480], // TikTok
            'com.instagram.android' => [180, 180, 180, 180, 180, 200, 200],
            'com.google.android.youtube' => [40, 40, 40, 40, 40, 80, 80],
            'com.whatsapp' => [40, 40, 40, 40, 40, 40, 40],
            'us.zoom.videomeetings' => [0, 250, 0, 250, 0, 0, 0],
            'com.android.chrome' => [30, 30, 30, 30, 30, 20, 20],
            'android.system' => [20, 20, 20, 20, 20, 20, 20],
        ],
        'budi' => [
            'com.whatsapp' => [120, 120, 120, 120, 120, 120, 120],
            'com.google.android.apps.maps' => [110, 110, 110, 110, 110, 20, 20],
            'com.google.android.gm' => [40, 40, 40, 40, 40, 10, 10],
            'com.google.android.youtube' => [60, 60, 60, 60, 60, 150, 150],
            'com.android.chrome' => [40, 40, 40, 40, 40, 30, 30],
            'android.system' => [20, 20, 20, 20, 20, 20, 20],
        ],
    ];

    private const RANDOM_SHARES = [
        'com.google.android.youtube' => 0.25,
        'com.mobile.legends' => 0.20,
        'com.instagram.android' => 0.15,
        'com.whatsapp' => 0.10,
        'com.shopee.id' => 0.10,
        'com.android.chrome' => 0.10,
        'android.system' => 0.10,
    ];

    /**
     * @return list<array<string, int>> MB per package_name; indeks 0 = $start, lalu hari-hari berikutnya.
     */
    public static function days(string $profile, CarbonInterface $start, int $count): array
    {
        if ($profile === 'random') {
            return self::random($count);
        }
        if (! isset(self::WEEKLY[$profile])) {
            throw new InvalidArgumentException("Profil [$profile] tidak dikenal.");
        }

        $days = [];
        for ($i = 0; $i < $count; $i++) {
            $weekday = $start->copy()->addDays($i)->dayOfWeekIso - 1;
            $days[] = array_map(fn (array $week) => $week[$weekday], self::WEEKLY[$profile]);
        }

        return $days;
    }

    /** Total per hari = round(600 × U(0,6; 1,4)) MB dengan mt_srand(2026): hasilnya selalu sama. */
    private static function random(int $count): array
    {
        mt_srand(2026);
        $days = [];
        for ($i = 0; $i < $count; $i++) {
            $total = round(600 * (0.6 + 0.8 * mt_rand() / mt_getrandmax()));
            $days[] = array_map(fn (float $share) => (int) round($total * $share), self::RANDOM_SHARES);
        }
        mt_srand(); // jangan tinggalkan seed tetap untuk pemakai mt_rand lain

        return $days;
    }
}
