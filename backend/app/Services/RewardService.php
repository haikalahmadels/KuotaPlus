<?php

namespace App\Services;

use App\Domain\RewardEvaluator;
use App\Models\DailyEvaluation;
use App\Models\Forecast;
use App\Models\User;
use Carbon\CarbonInterface;
use Illuminate\Support\Facades\DB;

/**
 * Evaluasi harian reward poin (FR-11). Dijalankan 00:05 untuk hari kemarin (rewards:evaluate),
 * dan oleh DemoAccountSeeder untuk memutar ulang riwayat. Aman dipanggil dua kali untuk hari yang sama.
 */
class RewardService
{
    public function __construct(private PointService $points, private SettingService $settings) {}

    /** @return DailyEvaluation|null null jika hari itu tidak punya paket aktif atau sudah dievaluasi */
    public function evaluate(User $user, CarbonInterface $date): ?DailyEvaluation
    {
        $date = $date->copy()->startOfDay();

        // Jatah hari itu = jatah tertinggi yang dihitung pada hari itu: snapshot 00:00, atau setelah membeli paket
        // (FR-9.5). Berbagi kuota dan pemakaian hanya menurunkan jatah, jadi tidak mengubah penilaian (FR-14.14).
        // Tidak ada prediksi sama sekali = tidak punya paket aktif = tidak dievaluasi (FR-11.1).
        $budget = Forecast::where('user_id', $user->id)
            ->whereBetween('computed_at', [$date, $date->copy()->endOfDay()])
            ->max('daily_budget_bytes');
        if ($budget === null) {
            return null;
        }

        return DB::transaction(function () use ($user, $date, $budget) {
            User::whereKey($user->id)->lockForUpdate()->first();

            if (DailyEvaluation::where(['user_id' => $user->id, 'eval_date' => $date->toDateString()])->exists()) {
                return null;
            }

            $records = $user->usageRecords()->whereDate('usage_date', $date);
            $previousStreak = (int) ($user->dailyEvaluations()->where('eval_date', '<', $date->toDateString())
                ->latest('eval_date')->value('streak_after') ?? 0);

            $result = RewardEvaluator::evaluate((int) $records->sum('bytes_mobile'), (int) $budget, $records->exists(), $previousStreak, [
                'points_per_day' => $this->settings->int('reward.points_per_day'),
                'streak_length' => $this->settings->int('reward.streak_length'),
                'streak_bonus' => $this->settings->int('reward.streak_bonus'),
                'min_usage_bytes' => $this->settings->int('reward.min_usage_bytes'),
            ]);

            $evaluation = $user->dailyEvaluations()->create([
                'eval_date' => $date->toDateString(),
                'usage_bytes' => (int) $records->sum('bytes_mobile'),
                'budget_bytes' => (int) $budget,
                'result' => $result['result'],
                'streak_after' => $result['streak_after'],
            ]);

            if ($result['daily_points'] > 0) {
                $this->points->earn($user, $result['daily_points'], 'earn_daily', $evaluation);
            }
            if ($result['bonus_points'] > 0) {
                $this->points->earn($user, $result['bonus_points'], 'earn_streak', $evaluation);
            }

            return $evaluation;
        });
    }
}
