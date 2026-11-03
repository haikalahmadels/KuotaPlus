<?php

namespace App\Filament\Resources\AdminAuditLogs\Tables;

use App\Filament\Support\AdminFormat;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class AdminAuditLogsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->columns([
                TextColumn::make('created_at')->label('Waktu')->dateTime('j M Y, H.i:s')->sortable(),
                TextColumn::make('admin.name')->label('Admin'),
                TextColumn::make('action')->label('Aksi')->badge()
                    ->formatStateUsing(fn (string $state) => AdminFormat::ACTIONS[$state] ?? $state)
                    ->color(fn (string $state) => match ($state) { 'create' => 'success', 'delete' => 'danger', default => 'info' }),
                TextColumn::make('entity_type')->label('Data')->formatStateUsing(fn (string $state) => AdminFormat::ENTITIES[$state] ?? $state),
                TextColumn::make('entity_id')->label('ID'),
                TextColumn::make('summary')->label('Perubahan')->wrap()
                    ->state(fn ($record) => AdminFormat::changeSummary($record->before, $record->after)),
                TextColumn::make('ip')->label('IP')->toggleable(isToggledHiddenByDefault: true),
            ])
            ->filters([
                SelectFilter::make('action')->label('Aksi')->options(AdminFormat::ACTIONS),
                SelectFilter::make('entity_type')->label('Data')->options(AdminFormat::ENTITIES),
            ])
            ->recordActions([ViewAction::make()]);
    }
}
