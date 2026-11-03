<?php

namespace App\Filament\Support;

use App\Models\Subscriber;
use App\Models\Transaction;
use App\Support\Format;
use Filament\Forms\Components\DatePicker;
use Filament\Tables\Filters\Filter;
use Illuminate\Database\Eloquent\Builder;

/** Label dan format yang dipakai beberapa resource panel admin. */
final class AdminFormat
{
    public const STATUSES = ['pending' => 'Menunggu', 'paid' => 'Berhasil', 'failed' => 'Gagal', 'expired' => 'Kedaluwarsa'];

    public const METHODS = ['pulsa' => 'Pulsa', 'ewallet' => 'E-wallet', 'va' => 'Virtual account', 'qris' => 'QRIS'];

    public const CARD = ['active' => 'Aktif', 'grace' => 'Masa tenggang', 'terminated' => 'Hangus'];

    public const ACTIONS = ['create' => 'Buat', 'update' => 'Ubah', 'delete' => 'Hapus'];

    public const ENTITIES = ['packages' => 'Paket', 'apps' => 'Kategori aplikasi', 'settings' => 'Pengaturan'];

    /** Admin melihat nomor lengkap dalam format lokal (berbeda dengan API pelanggan yang menyamarkan nomor orang lain). */
    public static function msisdn(?string $msisdn): string
    {
        if ($msisdn === null) {
            return '—';
        }
        $local = str_starts_with($msisdn, '62') ? '0'.substr($msisdn, 2) : $msisdn;

        return implode('-', str_split($local, 4));
    }

    public static function item(Transaction $transaction): string
    {
        return $transaction->type === 'package'
            ? ($transaction->package?->name ?? 'Paket')
            : 'Isi ulang '.Format::rupiah((int) $transaction->topup_amount);
    }

    public static function statusColor(string $status): string
    {
        return match ($status) {
            'paid' => 'success',
            'pending' => 'warning',
            'failed' => 'danger',
            default => 'gray',
        };
    }

    /** "price: 65000 → 60000" untuk baris audit log. */
    public static function changeSummary(?array $before, ?array $after): string
    {
        $keys = array_keys($after ?? $before ?? []);
        $show = fn ($v) => is_array($v) ? json_encode($v, JSON_UNESCAPED_UNICODE) : (string) $v;

        return collect($keys)
            ->take(4)
            ->map(fn ($key) => $before !== null && $after !== null
                ? "{$key}: ".$show($before[$key] ?? null).' → '.$show($after[$key])
                : $key.': '.$show(($after ?? $before)[$key]))
            ->implode('; ');
    }

    public static function dateRange(string $column, string $label): Filter
    {
        return Filter::make($column)
            ->label($label)
            ->schema([
                DatePicker::make('from')->label($label.' dari'),
                DatePicker::make('until')->label('sampai'),
            ])
            ->query(fn (Builder $query, array $data) => $query
                ->when($data['from'] ?? null, fn ($q, $date) => $q->whereDate($column, '>=', $date))
                ->when($data['until'] ?? null, fn ($q, $date) => $q->whereDate($column, '<=', $date)));
    }
}
