<?php

namespace App\Filament\Resources\Packages\Tables;

use App\Filament\Resources\Packages\Schemas\PackageForm;
use App\Models\Package;
use App\Support\Format;
use Filament\Actions\DeleteAction;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class PackagesTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('price')
            ->columns([
                TextColumn::make('code')->label('Kode')->searchable(),
                TextColumn::make('name')->label('Nama')->searchable(),
                TextColumn::make('type')->label('Jenis')->badge()
                    ->formatStateUsing(fn (string $state) => PackageForm::TYPES[$state] ?? $state),
                TextColumn::make('price')->label('Harga')->sortable()
                    ->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                TextColumn::make('main_quota')->label('Kuota utama')->sortable()
                    ->formatStateUsing(fn (int $state) => Format::bytes($state)),
                TextColumn::make('app_quota')->label('Kuota aplikasi')
                    ->formatStateUsing(fn (int $state, Package $record) => $state > 0
                        ? Format::bytes($state).' '.(PackageForm::CATEGORIES[$record->app_category] ?? '')
                        : '—'),
                TextColumn::make('validity_days')->label('Masa berlaku')->suffix(' hari')->sortable(),
                IconColumn::make('is_active')->label('Aktif')->boolean(),
                TextColumn::make('updated_at')->label('Diubah')->dateTime('j M Y, H.i')->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('type')->label('Jenis')->options(PackageForm::TYPES),
                TernaryFilter::make('is_active')->label('Aktif dijual'),
            ])
            ->recordActions([
                EditAction::make(),
                // FR-15.3: paket yang pernah dibeli hanya dinonaktifkan (model juga menolak penghapusannya).
                DeleteAction::make()->visible(fn (Package $record) => ! $record->wasPurchased()),
            ]);
    }
}
