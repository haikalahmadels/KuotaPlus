<?php

namespace App\Filament\Widgets;

use App\Models\Transaction;
use Filament\Widgets\ChartWidget;

/** FR-15.2: grafik transaksi berhasil per hari, 30 hari terakhir. */
class DailyTransactionsChart extends ChartWidget
{
    protected static ?int $sort = 2;

    protected int|string|array $columnSpan = 'full';

    protected ?string $heading = 'Transaksi berhasil per hari (30 hari)';

    protected ?string $maxHeight = '280px';

    protected function getData(): array
    {
        $counts = Transaction::where('status', 'paid')
            ->where('paid_at', '>=', today()->subDays(29))
            ->selectRaw('DATE(paid_at) AS day, COUNT(*) AS total')
            ->groupBy('day')
            ->pluck('total', 'day');

        $labels = [];
        $data = [];
        for ($i = 29; $i >= 0; $i--) {
            $day = today()->subDays($i);
            $labels[] = $day->locale('id')->translatedFormat('j M');
            $data[] = (int) ($counts[$day->toDateString()] ?? 0);
        }

        return [
            'datasets' => [['label' => 'Transaksi', 'data' => $data, 'borderColor' => '#1E40AF', 'backgroundColor' => '#EAF0FF', 'fill' => true]],
            'labels' => $labels,
        ];
    }

    protected function getType(): string
    {
        return 'line';
    }
}
