<?php

namespace App\Services;

use App\Domain\ForecastCalculator;
use App\Models\Forecast;
use App\Models\Subscription;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;

/**
 * Prediksi kuota habis dan jatah harian (FR-9). Dihitung ulang setelah sync, Mode Demo, pembelian paket,
 * dan setiap 00:00 (forecasts:daily). Baris terbaru di tabel forecasts = prediksi aktif.
 */
class ForecastService
{
    /** Null jika pengguna tidak punya paket yang belum berakhir. */
    public function recompute(User $user): ?Forecast
    {
        $subscriptions = Subscription::where('subscriber_id', $user->subscriber_id)->current()->get();
        if ($subscriptions->isEmpty()) {
            return null;
        }

        // "Paket utama" = paket dengan kuota utama terbesar yang kuotanya belum habis; seri → yang berakhir paling akhir.
        // Paket lama yang sudah habis tidak boleh menjadi acuan jatah harian paket darurat yang baru dibeli.
        $candidates = $subscriptions->where('status', 'active');
        $main = ($candidates->isEmpty() ? $subscriptions : $candidates)
            ->sortByDesc(fn ($s) => [$s->main_total, $s->expires_at->timestamp])
            ->first();

        // FR-9.2: kuota aplikasi hanya dihitung untuk kategori yang memang dipakai pengguna.
        $usedCategories = $this->categoryBytes($user, 30)->filter()->keys();
        $remaining = $subscriptions->sum(fn ($s) => $s->main_total - $s->main_used)
            + $subscriptions->filter(fn ($s) => $usedCategories->contains($s->app_category))->sum(fn ($s) => $s->app_total - $s->app_used);

        [$daily, $dataDays] = $this->history($user);
        $result = ForecastCalculator::calculate($daily, $dataDays, $remaining, now(), $main->expires_at);

        return $user->forecasts()->create([
            'computed_at' => now(),
            'avg_daily_bytes' => $result['avg_daily_bytes'],
            'remaining_bytes' => $result['remaining_bytes'],
            'predicted_empty_at' => $result['predicted_empty_at'],
            'main_expires_at' => $main->expires_at,
            'daily_budget_bytes' => $result['daily_budget_bytes'],
            'confidence' => $result['confidence'],
            'status' => $result['status'],
        ]);
    }

    /** Prediksi aktif; dihitung ulang jika belum ada atau dibuat sebelum hari ini (scheduler mati). */
    public function latest(User $user): ?Forecast
    {
        $forecast = $user->forecasts()->latest('computed_at')->latest('id')->first();

        return $forecast && $forecast->computed_at->gte(today()) ? $forecast : $this->recompute($user);
    }

    /**
     * Pemakaian per hari untuk rata-rata tertimbang, hari ini tidak dihitung (FR-9.1).
     * Hari tanpa data di antara data pertama dan kemarin dihitung 0 (misalnya seharian memakai Wi-Fi).
     *
     * @return array{0: list<int>, 1: int} [byte per hari (indeks 0 = kemarin, maks 7), jumlah hari data s.d. kemarin]
     */
    public function history(User $user): array
    {
        $yesterday = today()->subDay();
        $first = $user->usageRecords()->min('usage_date');
        $dataDays = $first ? (int) Carbon::parse($first)->diffInDays($yesterday, false) + 1 : 0;
        if ($dataDays <= 0) {
            return [[], 0];
        }

        $span = min(ForecastCalculator::HISTORY_DAYS, $dataDays);
        $totals = $user->usageRecords()
            ->whereBetween('usage_date', [$yesterday->copy()->subDays($span - 1), $yesterday])
            ->selectRaw('usage_date, SUM(bytes_mobile) AS total')
            ->groupBy('usage_date')
            ->pluck('total', 'usage_date')
            ->mapWithKeys(fn ($total, $date) => [Carbon::parse($date)->toDateString() => (int) $total]);

        $daily = [];
        for ($i = 0; $i < $span; $i++) {
            $daily[] = $totals[$yesterday->copy()->subDays($i)->toDateString()] ?? 0;
        }

        return [$daily, $dataDays];
    }

    /** Pemakaian $days hari terakhir per kategori aplikasi. */
    public function categoryBytes(User $user, int $days): Collection
    {
        return $user->usageRecords()
            ->join('apps', 'apps.id', '=', 'usage_records.app_id')
            ->where('usage_date', '>=', today()->subDays($days - 1))
            ->selectRaw('apps.category, SUM(bytes_mobile) AS total')
            ->groupBy('apps.category')
            ->pluck('total', 'category')
            ->map(fn ($total) => (int) $total);
    }
}
