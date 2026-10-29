<?php

namespace Tests\Unit;

use App\Domain\UsageProfiles;
use Carbon\Carbon;
use PHPUnit\Framework\TestCase;

/** Angka profil harus sama dengan docs/SEED-KuotaPlus.md, karena hasil prediksi dan rekomendasi bergantung padanya. */
class UsageProfilesTest extends TestCase
{
    private function weeklyTotals(string $profile): array
    {
        $monday = Carbon::parse('2026-10-26'); // Senin

        return array_map('array_sum', UsageProfiles::days($profile, $monday, 7));
    }

    public function test_rina_weekly_pattern_matches_seed_document(): void
    {
        $this->assertSame([690, 940, 690, 940, 690, 840, 840], $this->weeklyTotals('rina'));
        $this->assertEqualsWithDelta(804.3, array_sum($this->weeklyTotals('rina')) / 7, 0.05);
    }

    public function test_budi_weekly_pattern_matches_seed_document(): void
    {
        $this->assertSame([390, 390, 390, 390, 390, 350, 350], $this->weeklyTotals('budi'));
    }

    public function test_weekday_follows_the_start_date(): void
    {
        $sunday = Carbon::parse('2026-11-01');
        $this->assertSame(840, array_sum(UsageProfiles::days('rina', $sunday, 1)[0]));
    }

    public function test_random_profile_is_deterministic_and_within_range(): void
    {
        $first = UsageProfiles::days('random', Carbon::parse('2026-10-26'), 30);
        $second = UsageProfiles::days('random', Carbon::parse('2026-01-01'), 30);

        $this->assertSame($first, $second);
        foreach ($first as $day) {
            $this->assertGreaterThanOrEqual(355, array_sum($day)); // 600 × 0,6 dengan pembulatan per aplikasi
            $this->assertLessThanOrEqual(845, array_sum($day));
        }
    }
}
