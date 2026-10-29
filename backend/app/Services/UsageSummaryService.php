<?php

namespace App\Services;

use App\Models\App;
use App\Models\UsageRecord;
use App\Models\User;
use App\Support\Format;
use Carbon\CarbonInterface;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Analisis pemakaian (FR-8). Aplikasi dengan label dan kategori sama (misalnya dua build TikTok)
 * digabung menjadi satu baris; app_id baris itu = id terkecil di grupnya.
 */
class UsageSummaryService
{
    public const PERIOD_DAYS = ['today' => 1, '7d' => 7, '30d' => 30];

    private const PERIOD_LABELS = ['today' => 'hari ini', '7d' => 'minggu ini', '30d' => 'dalam 30 hari terakhir'];

    private const TOP = 5;

    private const MB = 1048576;

    public function __construct(private ForecastService $forecasts) {}

    public function summary(User $user, string $period): array
    {
        [$start, $end] = $this->range($period);
        // Data tambahan sebelum periode: median 7 hari untuk lonjakan dan pembanding minggu lalu.
        $from = min($start->copy()->subDays(7), $end->copy()->subDays(13));
        $records = $user->usageRecords()->with('app')->whereBetween('usage_date', [$from, $end])->get();
        $inPeriod = $records->filter(fn ($r) => $r->usage_date->between($start, $end));

        $total = (int) $inPeriod->sum('bytes_mobile');
        $apps = $this->groupByApp($inPeriod)->map(fn ($app) => $app + [
            'percent' => $total > 0 ? round($app['bytes'] * 100 / $total, 1) : 0.0,
        ])->values();

        $dailyTotals = $records->groupBy(fn ($r) => $r->usage_date->toDateString())->map->sum('bytes_mobile');
        // Jatah harian snapshot 00:00 dari evaluasi reward (FR-11); kosong untuk hari yang belum dievaluasi.
        $budgets = $user->dailyEvaluations()->whereBetween('eval_date', [$start, $end])->get()
            ->mapWithKeys(fn ($e) => [$e->eval_date->toDateString() => $e->budget_bytes]);
        $daily = [];
        for ($date = $start->copy(); $date->lte($end); $date->addDay()) {
            $bytes = (int) ($dailyTotals[$date->toDateString()] ?? 0);
            $daily[] = [
                'date' => $date->toDateString(),
                'bytes' => $bytes,
                'budget_bytes' => $budgets[$date->toDateString()] ?? null,
                'is_spike' => $this->isSpike($bytes, $date, $dailyTotals),
            ];
        }

        $latest = $user->usageRecords()->latest('synced_at')->first(['source', 'synced_at']);

        return [
            'period' => $period,
            'source' => $latest?->source,
            'last_synced_at' => $latest?->synced_at->toIso8601String(),
            // Jatah harian saat ini, digambar sebagai garis pembanding di bar harian (FR-8.3).
            'daily_budget_bytes' => $this->forecasts->latest($user)?->daily_budget_bytes,
            'total_bytes' => $total,
            'top_apps' => $this->top($apps, $total),
            'apps' => $apps,
            'daily' => $daily,
            'insights' => $this->insights($period, $apps, $records, $daily, $end),
        ];
    }

    public function app(User $user, int $appId, string $period): array
    {
        $app = App::findOrFail($appId);
        $groupIds = App::where(['label' => $app->label, 'category' => $app->category])->pluck('id');
        [$start, $end] = $this->range($period);

        $byDate = $user->usageRecords()
            ->whereIn('app_id', $groupIds)
            ->whereBetween('usage_date', [$start, $end])
            ->get()
            ->groupBy(fn ($r) => $r->usage_date->toDateString())
            ->map->sum('bytes_mobile');

        $daily = [];
        for ($date = $start->copy(); $date->lte($end); $date->addDay()) {
            $daily[] = ['date' => $date->toDateString(), 'bytes' => (int) ($byDate[$date->toDateString()] ?? 0)];
        }
        $total = (int) $byDate->sum();

        return [
            'app' => ['app_id' => $groupIds->min(), 'package_name' => $app->package_name, 'label' => $app->label, 'category' => $app->category],
            'period' => $period,
            'total_bytes' => $total,
            'avg_daily_bytes' => intdiv($total, self::PERIOD_DAYS[$period]),
            'daily' => $daily,
        ];
    }

    /** @return array{0: CarbonInterface, 1: CarbonInterface} termasuk hari ini */
    private function range(string $period): array
    {
        $end = today();

        return [$end->copy()->subDays(self::PERIOD_DAYS[$period] - 1), $end];
    }

    private function groupByApp(Collection $records): Collection
    {
        return $records
            ->groupBy(fn ($r) => $r->app->label.'|'.$r->app->category)
            ->map(function (Collection $group) {
                $first = $group->sortBy('app_id')->first()->app;

                return [
                    'app_id' => $first->id,
                    'package_name' => $first->package_name,
                    'label' => $first->label,
                    'category' => $first->category,
                    'bytes' => (int) $group->sum('bytes_mobile'),
                ];
            })
            ->sortByDesc('bytes');
    }

    private function top(Collection $apps, int $total): array
    {
        $top = $apps->take(self::TOP)->all();
        $others = (int) $apps->slice(self::TOP)->sum('bytes');

        if ($others > 0) {
            $top[] = ['app_id' => null, 'package_name' => null, 'label' => 'Lainnya', 'category' => null,
                'bytes' => $others, 'percent' => round($others * 100 / $total, 1)];
        }

        return $top;
    }

    /** Edge case: lonjakan = pemakaian > 3× median 7 hari sebelumnya. */
    private function isSpike(int $bytes, CarbonInterface $date, Collection $dailyTotals): bool
    {
        $previous = collect(range(1, 7))->map(fn ($i) => (int) ($dailyTotals[$date->copy()->subDays($i)->toDateString()] ?? 0));
        $median = $previous->median();

        return $median > 0 && $bytes > 3 * $median;
    }

    /** FR-8.5: maksimal 3 kalimat berbasis aturan. */
    private function insights(string $period, Collection $apps, Collection $records, array $daily, CarbonInterface $end): array
    {
        $growth = $this->weeklyGrowth($records, $end);
        $insights = [];

        $top = $apps->first();
        if ($top && $top['percent'] >= 40) {
            $sentence = "{$top['label']} memakai ".Format::decimal($top['percent'])."% kuotamu ".self::PERIOD_LABELS[$period];
            if (($growth[$top['label']] ?? 0) >= 20) {
                $sentence .= ', naik '.round($growth[$top['label']]).'% dari minggu lalu';
            }
            $insights[] = $sentence.'.';
        }

        // Aplikasi teratas yang sudah disebut di kalimat pertama tidak diulang.
        $mentioned = $insights ? $top['label'] : null;
        $rising = collect($growth)->filter(fn ($g, $label) => $g >= 20 && $label !== $mentioned)->sortDesc();
        if ($rising->isNotEmpty()) {
            $insights[] = $rising->keys()->first().' naik '.round($rising->first()).'% dari minggu lalu.';
        }

        $spike = collect($daily)->where('is_spike', true)->last();
        if ($spike) {
            $insights[] = 'Lonjakan tidak biasa pada '.Carbon::parse($spike['date'])->locale('id')->translatedFormat('j M')
                .': '.Format::bytes($spike['bytes']).' dalam sehari.';
        }

        return array_slice($insights, 0, 3);
    }

    /**
     * Kenaikan 7 hari terakhir dibanding 7 hari sebelumnya, per label aplikasi.
     * Aplikasi kecil (< 50 MB minggu ini) diabaikan supaya insight tidak berisi angka persen dari pemakaian kecil.
     *
     * @return array<string, float> label => persen
     */
    private function weeklyGrowth(Collection $records, CarbonInterface $end): array
    {
        $thisWeekStart = $end->copy()->subDays(6);
        $lastWeekStart = $end->copy()->subDays(13);
        $growth = [];

        foreach ($records->groupBy(fn ($r) => $r->app->label) as $label => $group) {
            $now = $group->filter(fn ($r) => $r->usage_date->gte($thisWeekStart))->sum('bytes_mobile');
            $before = $group->filter(fn ($r) => $r->usage_date->between($lastWeekStart, $thisWeekStart->copy()->subDay()))->sum('bytes_mobile');

            if ($before > 0 && $now >= 50 * self::MB) {
                $growth[$label] = ($now - $before) * 100 / $before;
            }
        }

        return $growth;
    }
}
