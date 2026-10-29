<?php

namespace Tests\Unit;

use App\Domain\ForecastCalculator;
use App\Domain\UsageProfiles;
use Carbon\Carbon;
use PHPUnit\Framework\TestCase;

/**
 * FR-9 dan DoD "Akurasi prediksi": MAPE tanggal habis ≤ 20% pada profil Rina, Budi, Acak (docs/SEED-KuotaPlus.md).
 */
class ForecastCalculatorTest extends TestCase
{
    private const MB = 1048576;

    private const GB = 1073741824;

    /** @return list<int> byte per hari, indeks 0 = hari pertama */
    private function profileBytes(string $profile, int $days): array
    {
        $monday = Carbon::parse('2026-10-26');

        return array_map(fn ($day) => array_sum($day) * self::MB, UsageProfiles::days($profile, $monday, $days));
    }

    public function test_linear_weights_favour_yesterday(): void
    {
        // SEED: hari ke-1 s.d. 6 = 100 MB, kemarin = 800 MB → (100×21 + 800×7) / 28 = 275 MB.
        $this->assertSame(275 * self::MB, ForecastCalculator::averageDaily([800 * self::MB, ...array_fill(0, 6, 100 * self::MB)]));
    }

    public function test_confidence_levels(): void
    {
        $now = Carbon::parse('2026-10-29 12:00');
        $expires = $now->copy()->addDays(20);
        $rina = array_reverse($this->profileBytes('rina', 7));

        $high = ForecastCalculator::calculate($rina, 7, 15 * self::GB, $now, $expires);
        $low = ForecastCalculator::calculate(array_slice($rina, 0, 4), 4, 15 * self::GB, $now, $expires);
        $none = ForecastCalculator::calculate(array_slice($rina, 0, 2), 2, 15 * self::GB, $now, $expires);

        $this->assertSame('high', $high['confidence']);
        $this->assertNotNull($high['predicted_empty_at']);
        $this->assertSame('low', $low['confidence']);
        $this->assertNotNull($low['predicted_empty_at']);
        $this->assertSame('none', $none['confidence']);
        $this->assertNull($none['predicted_empty_at']);
        $this->assertNull($none['status']);
    }

    public function test_zero_usage_is_safe_until_package_ends(): void
    {
        $now = Carbon::parse('2026-10-29 12:00');

        $result = ForecastCalculator::calculate(array_fill(0, 7, 0), 7, 5 * self::GB, $now, $now->copy()->addDays(10));

        $this->assertSame(0, $result['avg_daily_bytes']);
        $this->assertNull($result['predicted_empty_at']);
        $this->assertSame('safe', $result['status']);
    }

    public function test_risk_status_days_early_and_daily_budget(): void
    {
        $now = Carbon::parse('2026-10-29 12:00');
        // 1 GB/hari, sisa 5 GB, paket berakhir 10 hari lagi → habis 5 hari lagi, 5 hari lebih cepat.
        $result = ForecastCalculator::calculate(array_fill(0, 7, self::GB), 7, 5 * self::GB, $now, $now->copy()->addDays(10));

        $this->assertSame('risk', $result['status']);
        $this->assertTrue($now->copy()->addDays(5)->equalTo($result['predicted_empty_at']));
        $this->assertSame(5, $result['days_early']);
        $this->assertSame(intdiv(5 * self::GB, 10), $result['daily_budget_bytes']);
    }

    /**
     * Backtest (SEED): BL15 dibeli di awal hari ke-1, prediksi dibuat di akhir hari ke-7,
     * dibandingkan dengan hari kuota benar-benar habis. APE = |prediksi − aktual| / (aktual − 7).
     */
    public function test_backtest_mape_is_within_20_percent(): void
    {
        $quota = 15 * self::GB;
        $errors = [];

        foreach (['rina', 'budi', 'random'] as $profile) {
            $days = $this->profileBytes($profile, 60);

            $actualDay = null;
            $cumulative = 0;
            foreach ($days as $i => $bytes) {
                $cumulative += $bytes;
                if ($cumulative >= $quota) {
                    $actualDay = $i + 1;
                    break;
                }
            }
            $this->assertNotNull($actualDay, "$profile: kuota harus habis dalam 60 hari");

            $endOfDay7 = Carbon::parse('2026-10-26')->addDays(7);
            $remaining = $quota - array_sum(array_slice($days, 0, 7));
            $result = ForecastCalculator::calculate(array_reverse(array_slice($days, 0, 7)), 7, $remaining, $endOfDay7, $endOfDay7->copy()->addDays(23));

            $predictedDay = 7 + (int) ceil(Carbon::parse('2026-10-26')->addDays(7)->diffInSeconds($result['predicted_empty_at']) / 86400);
            $errors[$profile] = abs($predictedDay - $actualDay) / ($actualDay - 7);
        }

        $mape = array_sum($errors) / count($errors);
        $this->assertLessThanOrEqual(0.20, $mape, 'APE per profil: '.json_encode($errors));
    }
}
