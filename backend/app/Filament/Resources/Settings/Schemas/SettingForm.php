<?php

namespace App\Filament\Resources\Settings\Schemas;

use App\Models\Setting;
use App\Support\Format;
use Filament\Forms\Components\Repeater;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Components\Text;
use Filament\Schemas\Schema;

class SettingForm
{
    /** Label dan satuan setiap key (docs/SEED-KuotaPlus.md). */
    public const LABELS = [
        'reward.points_per_day' => ['Poin per hari hemat', 'poin'],
        'reward.streak_length' => ['Panjang streak untuk bonus', 'hari'],
        'reward.streak_bonus' => ['Bonus streak', 'poin'],
        'reward.min_usage_bytes' => ['Pemakaian minimum hari hemat', 'byte'],
        'points.rupiah_per_point' => ['Nilai 1 poin', 'rupiah'],
        'points.redeem_step' => ['Kelipatan tukar poin', 'poin'],
        'points.max_discount_percent' => ['Batas diskon poin', '%'],
        'points.min_net_amount' => ['Total bayar minimum setelah diskon', 'rupiah'],
        'points.validity_days' => ['Masa berlaku poin', 'hari'],
        'card.grace_days' => ['Masa tenggang kartu', 'hari'],
        'share.limit_bytes_30d' => ['Batas berbagi per 30 hari', 'byte'],
        'share.min_remaining_bytes' => ['Sisa kuota minimal setelah berbagi', 'byte'],
        'share.step_bytes' => ['Langkah jumlah berbagi', 'byte'],
        'share.points_per_step' => ['Biaya poin per langkah', 'poin'],
        'share.validity_days' => ['Masa berlaku kuota kiriman', 'hari'],
        'notify.quota_low_percent' => ['Ambang kuota menipis', '%'],
        'notify.package_expiring_days' => ['Peringatan paket berakhir', 'hari'],
        'notify.card_expiring_days' => ['Peringatan masa aktif nomor', 'hari'],
        'topup.options' => ['Tabel nominal isi ulang', null],
    ];

    public static function label(string $key): string
    {
        return self::LABELS[$key][0] ?? $key;
    }

    /** Nilai yang mudah dibaca: byte ditulis MB/GB, rupiah dengan Rp. */
    public static function readable(Setting $setting): string
    {
        $unit = self::LABELS[$setting->key][1] ?? null;
        $value = $setting->value;

        return match (true) {
            is_array($value) => count($value).' baris',
            $unit === 'byte' => Format::bytes((int) $value),
            $unit === 'rupiah' => Format::rupiah((int) $value),
            $unit !== null => $value.' '.$unit,
            default => (string) $value,
        };
    }

    public static function configure(Schema $schema): Schema
    {
        // Satu field `value` per key: Repeater untuk tabel isi ulang, angka untuk sisanya.
        return $schema->components(fn (?Setting $record) => [
            Text::make(self::label($record?->key ?? '').' ('.$record?->key.')'),
            $record?->key === 'topup.options' ? self::topupTable() : self::number(),
        ]);
    }

    private static function number(): TextInput
    {
        return TextInput::make('value')
                ->label('Nilai')
                ->required()
                ->integer()
                ->minValue(fn (?Setting $record) => $record?->min)
                ->maxValue(fn (?Setting $record) => $record?->max)
                ->suffix(fn (?Setting $record) => self::LABELS[$record?->key][1] ?? null)
                ->helperText(fn (?Setting $record) => $record
                    ? "Rentang {$record->min} sampai {$record->max}. Berlaku mulai evaluasi atau transaksi berikutnya."
                    : null)
                ->dehydrateStateUsing(fn ($state) => (int) $state);
    }

    private static function topupTable(): Repeater
    {
        return Repeater::make('value')
                ->label('Nominal isi ulang')
                ->schema([
                    TextInput::make('amount')->label('Nominal')->prefix('Rp')->integer()->minValue(1000)->required(),
                    TextInput::make('extend_days')->label('Tambah masa aktif')->suffix('hari')->integer()->minValue(1)->required(),
                ])
                ->columns(2)
                ->minItems(1)
                ->dehydrateStateUsing(fn ($state) => array_values(array_map(
                    fn ($row) => ['amount' => (int) $row['amount'], 'extend_days' => (int) $row['extend_days']],
                    $state ?? [],
                )));
    }
}
