<?php

namespace App\Filament\Resources\Subscribers\Tables;

use App\Filament\Support\AdminFormat;
use App\Support\Format;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\IconColumn;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class SubscribersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('msisdn')
            ->modifyQueryUsing(fn ($query) => $query->withExists('user'))
            ->columns([
                TextColumn::make('msisdn')->label('Nomor')->searchable()
                    ->formatStateUsing(fn (string $state) => AdminFormat::msisdn($state)),
                TextColumn::make('status')->label('Status kartu')->badge()
                    ->formatStateUsing(fn (string $state) => AdminFormat::CARD[$state] ?? $state)
                    ->color(fn (string $state) => match ($state) { 'active' => 'success', 'grace' => 'warning', default => 'danger' }),
                TextColumn::make('pulsa_balance')->label('Pulsa')->sortable()
                    ->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                TextColumn::make('active_until')->label('Aktif s.d.')->date('j M Y')->sortable(),
                IconColumn::make('user_exists')->label('Pakai Kuota+')->boolean(),
            ])
            ->filters([
                SelectFilter::make('status')->label('Status kartu')->options(AdminFormat::CARD),
            ])
            ->recordActions([ViewAction::make()]);
    }
}
