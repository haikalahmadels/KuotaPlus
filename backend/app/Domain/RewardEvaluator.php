<?php

namespace App\Domain;

/**
 * Evaluasi satu hari untuk reward (FR-11.2–11.4). Tanpa database supaya aturannya mudah diuji.
 */
final class RewardEvaluator
{
    /**
     * @param  bool  $hasData  ada sync/data pemakaian untuk hari itu
     * @param  array{points_per_day: int, streak_length: int, streak_bonus: int, min_usage_bytes: int}  $rules
     * @return array{result: string, streak_after: int, daily_points: int, bonus_points: int}
     */
    public static function evaluate(int $usageBytes, int $budgetBytes, bool $hasData, int $previousStreak, array $rules): array
    {
        // Hari tanpa data: tidak ada poin, streak tidak putus (FR-11.4).
        if (! $hasData) {
            return ['result' => 'no_data', 'streak_after' => $previousStreak, 'daily_points' => 0, 'bonus_points' => 0];
        }

        // Batas minimum mencegah orang mematikan data hanya demi poin (FR-11.2, OQ-4).
        $hemat = $usageBytes <= $budgetBytes && $usageBytes >= $rules['min_usage_bytes'];
        if (! $hemat) {
            return ['result' => 'boros', 'streak_after' => 0, 'daily_points' => 0, 'bonus_points' => 0];
        }

        $streak = $previousStreak + 1;

        return [
            'result' => 'hemat',
            'streak_after' => $streak,
            'daily_points' => $rules['points_per_day'],
            'bonus_points' => $streak % $rules['streak_length'] === 0 ? $rules['streak_bonus'] : 0,
        ];
    }
}
