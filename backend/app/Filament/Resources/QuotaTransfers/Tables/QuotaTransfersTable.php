<?php

namespace App\Filament\Resources\QuotaTransfers\Tables;

use App\Filament\Support\AdminFormat;
use App\Support\Format;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class QuotaTransfersTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->modifyQueryUsing(fn ($query) => $query->with(['sender.subscriber', 'recipient']))
            ->columns([
                TextColumn::make('sender.subscriber.msisdn')->label('Pengirim')->searchable()
                    ->formatStateUsing(fn (?string $state) => AdminFormat::msisdn($state)),
                TextColumn::make('recipient.msisdn')->label('Penerima')->searchable()
                    ->formatStateUsing(fn (?string $state) => AdminFormat::msisdn($state)),
                TextColumn::make('bytes')->label('Jumlah')->sortable()->formatStateUsing(fn (int $state) => Format::gb($state)),
                TextColumn::make('points_spent')->label('Poin')->suffix(' poin')->sortable(),
                TextColumn::make('status')->label('Status')->badge()
                    ->color(fn (string $state) => $state === 'completed' ? 'success' : 'danger'),
                TextColumn::make('completed_at')->label('Selesai')->dateTime('j M Y, H.i')->sortable(),
                TextColumn::make('expires_at')->label('Berlaku s.d.')->dateTime('j M Y, H.i')->toggleable(),
            ])
            ->filters([AdminFormat::dateRange('created_at', 'Tanggal')])
            ->recordActions([ViewAction::make()]);
    }
}
