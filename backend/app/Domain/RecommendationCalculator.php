<?php

namespace App\Domain;

/**
 * Rekomendasi paket hemat (FR-10.2–10.4). Tanpa database supaya bisa diuji langsung (DoD Kebenaran rekomendasi).
 */
final class RecommendationCalculator
{
    public const CATEGORIES = ['video', 'sosmed', 'game', 'belajar', 'umum'];

    public const BUFFER = 1.1;

    public const MAX_ITEMS = 3;

    /**
     * Kebutuhan 30 hari = avg_daily × 30 × 1,1, dipecah per kategori menurut porsi pemakaian 30 hari terakhir.
     * Kategori "sistem" dihitung sebagai "umum" (tidak ada paket kuota sistem).
     *
     * @param  array<string, int>  $categoryBytes  pemakaian 30 hari per kategori
     * @return array{total_bytes: int, by_category: array<string, int>}
     */
    public static function need(int $avgDailyBytes, array $categoryBytes): array
    {
        $categoryBytes['umum'] = ($categoryBytes['umum'] ?? 0) + ($categoryBytes['sistem'] ?? 0);
        $total = (int) round($avgDailyBytes * 30 * self::BUFFER);
        $sum = array_sum(array_map(fn ($c) => $categoryBytes[$c] ?? 0, self::CATEGORIES));

        $byCategory = [];
        foreach (self::CATEGORIES as $category) {
            $share = $sum > 0 ? ($categoryBytes[$category] ?? 0) / $sum : ($category === 'umum' ? 1 : 0);
            $byCategory[$category] = (int) round($total * $share);
        }

        return ['total_bytes' => $total, 'by_category' => $byCategory];
    }

    /**
     * Biaya dan kuota 30 hari: harga dan kuota sama-sama dikali ceil(30 / masa berlaku) (FR-10.3).
     * Kebutuhan kategori yang tidak tercakup kuota aplikasi diambil dari kuota utama.
     *
     * @param  array{price: int, validity_days: int, main_quota: int, app_quota: int, app_category: ?string}  $package
     * @return array{enough: bool, cost_30d: int, leftover_bytes: int, purchases: int}
     */
    public static function evaluate(array $package, array $need): array
    {
        $purchases = (int) ceil(30 / $package['validity_days']);
        $mainCapacity = $package['main_quota'] * $purchases;
        $appCapacity = $package['app_quota'] * $purchases;

        $appNeed = $package['app_category'] ? ($need['by_category'][$package['app_category']] ?? 0) : 0;
        $coveredByApp = min($appNeed, $appCapacity);
        $restForMain = $need['total_bytes'] - $coveredByApp;

        return [
            'enough' => $restForMain <= $mainCapacity,
            'cost_30d' => $package['price'] * $purchases,
            'leftover_bytes' => ($appCapacity - $coveredByApp) + ($mainCapacity - $restForMain),
            'purchases' => $purchases,
        ];
    }

    /**
     * Paket yang cukup, termurah dulu; biaya sama → sisa kuota paling kecil (FR-10.4).
     *
     * @param  list<array{id: int}>  $packages  lihat evaluate()
     * @return list<array> paket + hasil evaluate(), maksimal 3
     */
    public static function rank(array $need, array $packages): array
    {
        $enough = [];
        foreach ($packages as $package) {
            $result = self::evaluate($package, $need);
            if ($result['enough']) {
                $enough[] = $package + $result;
            }
        }

        usort($enough, fn ($a, $b) => [$a['cost_30d'], $a['leftover_bytes']] <=> [$b['cost_30d'], $b['leftover_bytes']]);

        return array_slice($enough, 0, self::MAX_ITEMS);
    }
}
