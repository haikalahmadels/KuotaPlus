<?php

namespace App\Services;

use App\Domain\ForecastCalculator;
use App\Domain\RecommendationCalculator;
use App\Models\Package;
use App\Models\Recommendation;
use App\Models\Transaction;
use App\Models\User;
use App\Support\Format;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;

/**
 * Rekomendasi paket hemat (FR-10). Batch disimpan di tabel recommendations untuk mencatat event
 * ditampilkan/diklik/dibeli (FR-10.8), dan dihitung ulang saat data pemakaian, belanja, atau katalog berubah.
 */
class RecommendationService
{
    public const MIN_DATA_DAYS = 7;

    private const CATEGORY_LABELS = ['video' => 'video', 'sosmed' => 'sosmed', 'game' => 'game', 'belajar' => 'belajar'];

    public function __construct(private ForecastService $forecasts, private SettingService $settings) {}

    /**
     * Isi `GET /recommendations`.
     *
     * @return array{status: string, need: ?array, spent_30d: ?int, items: Collection<int, Recommendation>}
     */
    public function current(User $user, bool $markShown = true): array
    {
        [$daily, $dataDays] = $this->forecasts->history($user);
        if ($dataDays < self::MIN_DATA_DAYS) {
            return ['status' => 'insufficient_data', 'need' => null, 'spent_30d' => null, 'items' => collect()];
        }

        $avg = ForecastCalculator::averageDaily($daily);
        $need = RecommendationCalculator::need($avg, $this->forecasts->categoryBytes($user, 30)->all());
        $spent = $this->spent30d($user);

        $items = $this->freshBatch($user) ?? $this->rebuild($user, $avg, $need, $spent);

        if ($markShown) {
            Recommendation::whereIn('id', $items->pluck('id'))->whereNull('shown_at')->update(['shown_at' => now()]);
        }

        return [
            'status' => $this->status($user, $items, $need, $spent),
            'need' => $need,
            'spent_30d' => $spent,
            'items' => $items,
        ];
    }

    /** Paket peringkat 1 untuk lencana "Paling hemat untukmu" di katalog (FR-3.3). */
    public function recommendedPackageId(User $user): ?int
    {
        $current = $this->current($user, markShown: false);

        return $current['status'] === 'insufficient_data' ? null : $current['items']->first()?->package_id;
    }

    /**
     * FR-10.5: hemat = belanja paket (gross_amount, paid) 30 hari terakhir − biaya 30 hari paket rekomendasi.
     * Null jika tidak ada pembelian paket dalam 30 hari.
     */
    public function spent30d(User $user): ?int
    {
        $query = $this->paidPackages($user);

        return $query->exists() ? (int) $query->sum('gross_amount') : null;
    }

    private function paidPackages(User $user)
    {
        return Transaction::where('user_id', $user->id)
            ->where('type', 'package')
            ->where('status', 'paid')
            ->where('paid_at', '>=', now()->subDays(30));
    }

    /** Batch terakhir masih berlaku jika dibuat setelah perubahan data pemakaian, belanja, dan katalog. */
    private function freshBatch(User $user): ?Collection
    {
        $batchAt = $user->recommendations()->max('computed_at');
        if (! $batchAt) {
            return null;
        }

        $changedAt = collect([
            $user->usageRecords()->max('synced_at'),
            $this->paidPackages($user)->max('paid_at'),
            $this->settings->get('catalog.updated_at'),
        ])->filter()->map(fn ($time) => Carbon::parse($time))->max();

        if ($changedAt && $changedAt->gt(Carbon::parse($batchAt))) {
            return null;
        }

        return $user->recommendations()->with('package')->where('computed_at', $batchAt)->orderBy('rank')->get();
    }

    private function rebuild(User $user, int $avg, array $need, ?int $spent): Collection
    {
        $packages = Package::where('is_active', true)->get();
        $ranked = RecommendationCalculator::rank($need, $packages->map(fn ($p) => $p->only(
            ['id', 'price', 'validity_days', 'main_quota', 'app_quota', 'app_category']
        ))->all());
        $topApps = $this->topApps($user);

        return DB::transaction(function () use ($user, $ranked, $packages, $need, $spent, $avg, $topApps) {
            $now = now();

            return collect($ranked)->values()->map(fn ($item, $i) => $user->recommendations()->create([
                'computed_at' => $now,
                'package_id' => $item['id'],
                'rank' => $i + 1,
                'need_bytes' => $need['total_bytes'],
                'cost_30d' => $item['cost_30d'],
                'saving_30d' => $spent === null ? null : $spent - $item['cost_30d'],
                'leftover_bytes' => $item['leftover_bytes'],
                'reason' => $this->reason($packages->firstWhere('id', $item['id']), $item, $avg, $topApps),
            ])->setRelation('package', $packages->firstWhere('id', $item['id'])));
        });
    }

    /**
     * ok | already_cheapest. "Sudah paling hemat" hanya jika paket terakhir yang dibeli memang cukup;
     * jika tidak, rekomendasi tetap ditampilkan walau lebih mahal dari belanja 30 hari terakhir.
     */
    private function status(User $user, Collection $items, array $need, ?int $spent): string
    {
        $top = $items->first();
        if ($spent === null || $top === null || $top->saving_30d > 0) {
            return 'ok';
        }

        $last = $this->paidPackages($user)->latest('paid_at')->first()?->package;
        $lastIsEnough = $last && RecommendationCalculator::evaluate($last->only(
            ['price', 'validity_days', 'main_quota', 'app_quota', 'app_category']
        ), $need)['enough'];

        return $lastIsEnough ? 'already_cheapest' : 'ok';
    }

    /** Dua aplikasi terbesar 30 hari terakhir dan porsinya, untuk kalimat alasan. */
    private function topApps(User $user): array
    {
        $byLabel = $user->usageRecords()
            ->join('apps', 'apps.id', '=', 'usage_records.app_id')
            ->where('usage_date', '>=', today()->subDays(29))
            ->selectRaw('apps.label, SUM(bytes_mobile) AS total')
            ->groupBy('apps.label')
            ->orderByDesc('total')
            ->pluck('total', 'label');

        $total = $byLabel->sum();
        $top = $byLabel->take(2);

        return ['labels' => $top->keys()->all(), 'percent' => $total > 0 ? (int) round($top->sum() * 100 / $total) : 0];
    }

    /** FR-10.6: alasan dari template. */
    private function reason(Package $package, array $item, int $avg, array $topApps): string
    {
        $sentence = 'Pemakaianmu sekitar '.Format::bytes($avg * 30).'/bulan';
        if ($topApps['labels'] !== []) {
            $sentence .= ', '.$topApps['percent'].'% dari '.implode(' dan ', $topApps['labels']);
        }

        $contents = $package->app_quota > 0
            ? Format::bytes($package->app_quota).' kuota '.(self::CATEGORY_LABELS[$package->app_category] ?? 'aplikasi')
                .' + '.Format::bytes($package->main_quota).' utama'
            : Format::bytes($package->main_quota);
        $offer = $item['purchases'] > 1
            ? "{$package->name} dibeli {$item['purchases']}× dalam 30 hari, total "
                .Format::bytes($package->main_quota * $item['purchases'] + $package->app_quota * $item['purchases'])
            : "{$package->name} berisi {$contents}";

        return "{$sentence}. {$offer}, cukup dengan sisa ".Format::bytes($item['leftover_bytes']).'.';
    }
}
