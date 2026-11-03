<?php

namespace App\Filament\Resources\Packages\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Forms\Components\Toggle;
use Filament\Schemas\Schema;

/** FR-15.3: kuota diisi dalam MB (disimpan dalam byte), harga baru hanya berlaku untuk transaksi baru. */
class PackageForm
{
    private const MB = 1048576;

    public const TYPES = ['harian' => 'Harian', 'mingguan' => 'Mingguan', 'bulanan' => 'Bulanan', 'aplikasi' => 'Aplikasi'];

    public const CATEGORIES = ['video' => 'Video', 'sosmed' => 'Sosmed', 'game' => 'Game', 'belajar' => 'Belajar'];

    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->columns(2)
            ->components([
                TextInput::make('code')
                    ->label('Kode')
                    ->required()
                    ->maxLength(16)
                    ->unique(ignoreRecord: true),
                TextInput::make('name')
                    ->label('Nama')
                    ->required()
                    ->maxLength(255),
                Select::make('type')
                    ->label('Jenis')
                    ->options(self::TYPES)
                    ->required(),
                TextInput::make('price')
                    ->label('Harga')
                    ->helperText('Hanya berlaku untuk transaksi baru; transaksi lama tetap memakai harga saat dibeli.')
                    ->required()
                    ->integer()
                    ->minValue(0)
                    ->prefix('Rp'),
                self::megabytes('main_quota', 'Kuota utama')->required()->minValue(1),
                TextInput::make('validity_days')
                    ->label('Masa berlaku')
                    ->required()
                    ->integer()
                    ->minValue(1)
                    ->suffix('hari'),
                self::megabytes('app_quota', 'Kuota aplikasi')->default(0)->minValue(0),
                Select::make('app_category')
                    ->label('Kategori kuota aplikasi')
                    ->options(self::CATEGORIES)
                    ->placeholder('Tidak ada'),
                Toggle::make('is_active')
                    ->label('Aktif dijual')
                    ->helperText('Paket yang pernah dibeli tidak bisa dihapus, hanya dinonaktifkan.')
                    ->default(true),
            ]);
    }

    private static function megabytes(string $name, string $label): TextInput
    {
        return TextInput::make($name)
            ->label($label)
            ->numeric()
            ->suffix('MB')
            ->formatStateUsing(fn ($state) => $state === null ? null : round($state / self::MB, 2))
            ->dehydrateStateUsing(fn ($state) => (int) round(((float) $state) * self::MB));
    }
}
