<?php

namespace App\Filament\Resources\Apps\Tables;

use App\Filament\Resources\Apps\Schemas\AppForm;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Filters\TernaryFilter;
use Filament\Tables\Table;

class AppsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('label')
            ->columns([
                TextColumn::make('label')->label('Nama')->searchable()->sortable(),
                TextColumn::make('package_name')->label('Package')->searchable()->color('gray'),
                TextColumn::make('category')->label('Kategori')->badge()
                    ->formatStateUsing(fn (string $state) => AppForm::CATEGORIES[$state] ?? $state),
                IconColumn::make('is_reviewed')->label('Ditinjau')->boolean(),
                TextColumn::make('created_at')->label('Pertama muncul')->dateTime('j M Y')->sortable()
                    ->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                // FR-15.4: aplikasi baru dari sync masuk "umum" dan perlu ditinjau.
                TernaryFilter::make('is_reviewed')
                    ->label('Status tinjauan')
                    ->trueLabel('Sudah ditinjau')
                    ->falseLabel('Belum ditinjau'),
                SelectFilter::make('category')->label('Kategori')->options(AppForm::CATEGORIES),
            ])
            ->recordActions([
                EditAction::make()->label('Ubah kategori'),
            ]);
    }
}
