<?php

namespace App\Domain;

use Carbon\CarbonInterface;

/**
 * Prediksi kuota habis dan jatah harian (FR-9). Tanpa database supaya bisa diuji langsung (DoD Akurasi prediksi).
 */
final class ForecastCalculator
{
    public const HISTORY_DAYS = 7;

    /**
     * Rata-rata tertimbang linear: kemarin bobot 7, tujuh hari lalu bobot 1 (FR-9.1).
     * Hanya hari yang tercakup data yang dihitung, jadi pengguna baru dengan 4 hari data tetap punya rata-rata.
     *
     * @param  list<int>  $dailyBytes  indeks 0 = kemarin, 1 = dua hari lalu, … (maks 7)
     */
    public static function averageDaily(array $dailyBytes): int
    {
        $days = array_slice($dailyBytes, 0, self::HISTORY_DAYS);
        if ($days === []) {
            return 0;
        }

        $weighted = 0;
        $weights = 0;
        foreach ($days as $i => $bytes) {
            $weight = self::HISTORY_DAYS - $i;
            $weighted += $bytes * $weight;
            $weights += $weight;
        }

        return intdiv($weighted, $weights);
    }

    /** ≥ 7 hari data = high, 3–6 = low ("perkiraan awal"), < 3 = none (FR-9.3). */
    public static function confidence(int $dataDays): string
    {
        return match (true) {
            $dataDays >= 7 => 'high',
            $dataDays >= 3 => 'low',
            default => 'none',
        };
    }

    /**
     * @param  list<int>  $dailyBytes  lihat averageDaily()
     * @param  int  $dataDays  jumlah hari sejak data pertama s.d. kemarin
     * @param  int  $remainingBytes  sisa kuota utama + kuota aplikasi yang relevan (FR-9.2)
     * @param  CarbonInterface  $mainExpiresAt  berakhirnya paket utama
     * @return array{avg_daily_bytes: int, remaining_bytes: int, predicted_empty_at: ?CarbonInterface, daily_budget_bytes: int,
     *               confidence: string, status: ?string, days_early: ?int}
     */
    public static function calculate(array $dailyBytes, int $dataDays, int $remainingBytes, CarbonInterface $now, CarbonInterface $mainExpiresAt): array
    {
        $avg = self::averageDaily($dailyBytes);
        $confidence = self::confidence($dataDays);

        // FR-9.5: jatah harian = sisa kuota / sisa hari sampai paket utama berakhir; hari ini ikut dihitung.
        $daysLeft = max(1, (int) ceil($now->diffInSeconds($mainExpiresAt, false) / 86400));
        $budget = intdiv($remainingBytes, $daysLeft);

        $predicted = null;
        $status = null;
        $daysEarly = null;

        if ($confidence !== 'none') {
            if ($avg === 0) {
                // Edge case: tidak memakai data seluler (Wi-Fi) → kuota aman sampai paket berakhir.
                $status = 'safe';
            } else {
                $predicted = $now->copy()->addSeconds((int) round($remainingBytes / $avg * 86400));
                $status = $predicted->lt($mainExpiresAt) ? 'risk' : 'safe';
                $daysEarly = $status === 'risk' ? (int) ceil($predicted->diffInSeconds($mainExpiresAt) / 86400) : null;
            }
        }

        return [
            'avg_daily_bytes' => $avg,
            'remaining_bytes' => $remainingBytes,
            'predicted_empty_at' => $predicted,
            'daily_budget_bytes' => $budget,
            'confidence' => $confidence,
            'status' => $status,
            'days_early' => $daysEarly,
        ];
    }
}
