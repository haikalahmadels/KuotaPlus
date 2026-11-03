<?php

namespace App\Filament\Resources\Apps\Schemas;

use Filament\Forms\Components\Select;
use Filament\Forms\Components\TextInput;
use Filament\Schemas\Schema;

class AppForm
{
    public const CATEGORIES = [
        'video' => 'Video',
        'sosmed' => 'Sosmed',
        'game' => 'Game',
        'belajar' => 'Belajar',
        'umum' => 'Umum',
        'sistem' => 'Sistem',
    ];

    public static function configure(Schema $schema): Schema
    {
        return $schema
            ->columns(2)
            ->components([
                TextInput::make('label')->label('Nama')->disabled()->dehydrated(false),
                TextInput::make('package_name')->label('Package')->disabled()->dehydrated(false),
                Select::make('category')
                    ->label('Kategori')
                    ->options(self::CATEGORIES)
                    ->required()
                    ->helperText('Berlaku untuk perhitungan berikutnya; kuota yang sudah terpotong tidak berubah.'),
            ]);
    }
}
