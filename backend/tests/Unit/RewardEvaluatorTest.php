<?php

namespace Tests\Unit;

use App\Domain\RewardEvaluator;
use PHPUnit\Framework\TestCase;

/** FR-11.2–11.4 dengan nilai default settings (OQ-3, OQ-4). */
class RewardEvaluatorTest extends TestCase
{
    private const MB = 1048576;

    private const RULES = ['points_per_day' => 10, 'streak_length' => 7, 'streak_bonus' => 50, 'min_usage_bytes' => 50 * self::MB];

    public function test_within_budget_and_above_minimum_is_hemat(): void
    {
        $this->assertSame(
            ['result' => 'hemat', 'streak_after' => 3, 'daily_points' => 10, 'bonus_points' => 0],
            RewardEvaluator::evaluate(400 * self::MB, 500 * self::MB, true, 2, self::RULES),
        );
    }

    public function test_every_seventh_day_in_a_row_gets_bonus(): void
    {
        $this->assertSame(50, RewardEvaluator::evaluate(400 * self::MB, 500 * self::MB, true, 6, self::RULES)['bonus_points']);
        $this->assertSame(50, RewardEvaluator::evaluate(400 * self::MB, 500 * self::MB, true, 13, self::RULES)['bonus_points']);
        $this->assertSame(0, RewardEvaluator::evaluate(400 * self::MB, 500 * self::MB, true, 7, self::RULES)['bonus_points']);
    }

    public function test_over_budget_resets_streak(): void
    {
        $this->assertSame(
            ['result' => 'boros', 'streak_after' => 0, 'daily_points' => 0, 'bonus_points' => 0],
            RewardEvaluator::evaluate(600 * self::MB, 500 * self::MB, true, 5, self::RULES),
        );
    }

    public function test_switching_data_off_for_points_does_not_count(): void
    {
        $this->assertSame('boros', RewardEvaluator::evaluate(10 * self::MB, 500 * self::MB, true, 5, self::RULES)['result']);
    }

    public function test_day_without_data_keeps_streak_without_points(): void
    {
        $this->assertSame(
            ['result' => 'no_data', 'streak_after' => 5, 'daily_points' => 0, 'bonus_points' => 0],
            RewardEvaluator::evaluate(0, 500 * self::MB, false, 5, self::RULES),
        );
    }
}
