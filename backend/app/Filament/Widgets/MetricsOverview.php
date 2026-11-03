<?php

namespace App\Filament\Widgets;

use App\Models\PointLedger;
use App\Models\QuotaTransfer;
use App\Models\Transaction;
use App\Models\UsageRecord;
use App\Models\User;
use App\Services\SettingService;
use App\Support\Format;
use Filament\Widgets\StatsOverviewWidget;
use Filament\Widgets\StatsOverviewWidget\Stat;

/** FR-15.2: metrik dashboard sesuai tabel Success metrics di PRD. */
class MetricsOverview extends StatsOverviewWidget
{
    protected static ?int $sort = 1;

    protected function getStats(): array
    {
        $paid = Transaction::where('status', 'paid');
        $today = (clone $paid)->where('paid_at', '>=', today());
        $month = (clone $paid)->where('paid_at', '>=', now()->subDays(30));

        $packages30 = (clone $month)->where('type', 'package');
        $packageCount = $packages30->count();
        $fromRecommendation = (clone $packages30)->whereNotNull('recommendation_id')->count();

        $android = User::where('platform', 'android');
        $androidCount = $android->count();
        $granted = (clone $android)->where('usage_access_granted', true)->count();

        $outstanding = (int) PointLedger::sum('delta');
        $rupiahPerPoint = app(SettingService::class)->int('points.rupiah_per_point');

        return [
            Stat::make('Transaksi hari ini', $today->count())
                ->description(Format::rupiah((int) $today->sum('net_amount')).' dibayar'),
            Stat::make('Transaksi 30 hari', $month->count())
                ->description('Pendapatan bersih '.Format::rupiah((int) $month->sum('net_amount'))),
            Stat::make('Diskon poin 30 hari', Format::rupiah((int) $month->sum('discount_amount')))
                ->description(number_format((int) $month->sum('points_used'), 0, ',', '.').' poin ditukar'),
            Stat::make('Poin beredar', number_format($outstanding, 0, ',', '.').' poin')
                ->description('Tanggungan '.Format::rupiah($outstanding * $rupiahPerPoint)),
            Stat::make('Kuota dibagikan 30 hari', Format::gb((int) QuotaTransfer::where('status', 'completed')
                ->where('completed_at', '>=', now()->subDays(30))->sum('bytes'))),
            Stat::make('Pembelian dari rekomendasi', self::percent($fromRecommendation, $packageCount))
                ->description("{$fromRecommendation} dari {$packageCount} pembelian paket (30 hari)"),
            Stat::make('Usage Access Android', self::percent($granted, $androidCount))
                ->description("{$granted} dari {$androidCount} pengguna Android"),
            Stat::make('Aplikasi paling boros (agregat)', self::topApp())
                ->description('Dari total trafik semua pelanggan, 30 hari'),
        ];
    }

    private static function percent(int $part, int $whole): string
    {
        return $whole === 0 ? '—' : round($part / $whole * 100).'%';
    }

    /** FR-15.8: hanya agregat seluruh pelanggan, tidak per pelanggan. */
    private static function topApp(): string
    {
        $base = UsageRecord::where('usage_date', '>=', today()->subDays(29));
        $total = (int) (clone $base)->sum('bytes_mobile');
        $top = (clone $base)->join('apps', 'apps.id', '=', 'usage_records.app_id')
            ->selectRaw('apps.label, SUM(usage_records.bytes_mobile) AS bytes')
            ->groupBy('apps.id', 'apps.label')
            ->orderByDesc('bytes')
            ->first();

        return $top && $total > 0 ? $top->label.' '.round($top->bytes / $total * 100).'%' : '—';
    }
}
