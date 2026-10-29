<?php

namespace Tests\Unit;

use App\Domain\ForecastCalculator;
use App\Domain\RecommendationCalculator;
use App\Domain\UsageProfiles;
use Carbon\Carbon;
use Database\Seeders\AppSeeder;
use Database\Seeders\PackageSeeder;
use PHPUnit\Framework\TestCase;

/**
 * FR-10 dan DoD "Kebenaran rekomendasi": paket terpilih selalu cukup dan biaya 30 harinya ≤ semua paket lain yang cukup.
 */
class RecommendationCalculatorTest extends TestCase
{
    private const MB = 1048576;

    /** Katalog aktif dari seeder, bentuk yang dipakai RecommendationService. */
    private function catalog(): array
    {
        $packages = [];
        foreach (PackageSeeder::CATALOG as $i => [$code, , , $price, $main, $app, $category, $validity, $active]) {
            if ($active) {
                $packages[] = ['id' => $i + 1, 'code' => $code, 'price' => $price, 'validity_days' => $validity,
                    'main_quota' => $main, 'app_quota' => $app, 'app_category' => $category];
            }
        }

        return $packages;
    }

    /** 30 hari profil yang berakhir kemarin: rata-rata tertimbang 7 hari terakhir + byte per kategori. */
    private function need(string $profile, ?Carbon $yesterday = null): array
    {
        $yesterday ??= Carbon::parse('2026-10-28');
        $days = UsageProfiles::days($profile, $yesterday->copy()->subDays(29), 30);

        $categoryOf = [];
        foreach (AppSeeder::APPS as $category => $apps) {
            foreach ($apps as $package => $label) {
                $categoryOf[$package] = $category;
            }
        }

        $categoryBytes = [];
        foreach ($days as $day) {
            foreach ($day as $package => $mb) {
                $categoryBytes[$categoryOf[$package]] = ($categoryBytes[$categoryOf[$package]] ?? 0) + $mb * self::MB;
            }
        }

        $last7 = array_reverse(array_map(fn ($day) => array_sum($day) * self::MB, array_slice($days, -7)));

        return RecommendationCalculator::need(ForecastCalculator::averageDaily($last7), $categoryBytes);
    }

    private function codes(array $ranked): array
    {
        return array_column($ranked, 'code');
    }

    public function test_rina_gets_video_package_and_bulanan_25_is_not_enough(): void
    {
        $need = $this->need('rina');
        $ranked = RecommendationCalculator::rank($need, $this->catalog());

        $this->assertSame(['VID30', 'HR3', 'BL50'], $this->codes($ranked));
        $this->assertSame(65000, $ranked[0]['cost_30d']);

        $bl25 = collect($this->catalog())->firstWhere('code', 'BL25');
        $this->assertFalse(RecommendationCalculator::evaluate($bl25, $need)['enough'], 'SEED: kebutuhan Rina ≈ 25,2–26,6 GB');
    }

    public function test_budi_gets_smaller_monthly_package(): void
    {
        $ranked = RecommendationCalculator::rank($this->need('budi'), $this->catalog());

        $this->assertSame(['BL15', 'VID30', 'BL25'], $this->codes($ranked));
    }

    public function test_result_does_not_depend_on_weekday(): void
    {
        foreach (range(0, 6) as $shift) {
            $yesterday = Carbon::parse('2026-10-28')->addDays($shift);
            $this->assertSame('VID30', RecommendationCalculator::rank($this->need('rina', $yesterday), $this->catalog())[0]['code']);
            $this->assertSame('BL15', RecommendationCalculator::rank($this->need('budi', $yesterday), $this->catalog())[0]['code']);
        }
    }

    public function test_daily_packages_are_scaled_to_30_days(): void
    {
        $hr1 = collect($this->catalog())->firstWhere('code', 'HR1');
        $result = RecommendationCalculator::evaluate($hr1, ['total_bytes' => 20 * 1073741824, 'by_category' => []]);

        $this->assertSame(30, $result['purchases']);
        $this->assertSame(150000, $result['cost_30d']);
        $this->assertTrue($result['enough'], '30 × 1 GB cukup untuk 20 GB');
    }

    public function test_top_pick_is_always_enough_and_cheapest(): void
    {
        foreach (['rina', 'budi', 'random'] as $profile) {
            $need = $this->need($profile);
            $ranked = RecommendationCalculator::rank($need, $this->catalog());
            $this->assertNotEmpty($ranked, $profile);

            foreach ($this->catalog() as $package) {
                $result = RecommendationCalculator::evaluate($package, $need);
                if ($result['enough']) {
                    $this->assertLessThanOrEqual($result['cost_30d'], $ranked[0]['cost_30d'], "$profile vs {$package['code']}");
                }
            }
            $this->assertTrue(RecommendationCalculator::evaluate($ranked[0], $need)['enough']);
        }
    }
}
