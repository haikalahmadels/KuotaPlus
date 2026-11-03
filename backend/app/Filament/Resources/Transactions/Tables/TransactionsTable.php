<?php

namespace App\Filament\Resources\Transactions\Tables;

use App\Filament\Support\AdminFormat;
use App\Models\Transaction;
use App\Support\Format;
use Filament\Actions\ViewAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Filters\SelectFilter;
use Filament\Tables\Table;

class TransactionsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('created_at', 'desc')
            ->modifyQueryUsing(fn ($query) => $query->with(['package', 'user.subscriber']))
            ->columns([
                TextColumn::make('external_ref')->label('Ref')->searchable()->copyable(),
                TextColumn::make('user.subscriber.msisdn')->label('Nomor')->searchable()
                    ->formatStateUsing(fn (?string $state) => AdminFormat::msisdn($state)),
                TextColumn::make('item')->label('Item')
                    ->state(fn (Transaction $record) => AdminFormat::item($record)),
                TextColumn::make('net_amount')->label('Dibayar')->sortable()
                    ->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                TextColumn::make('discount_amount')->label('Diskon poin')->toggleable()
                    ->formatStateUsing(fn (int $state) => $state > 0 ? Format::rupiah($state) : '—'),
                TextColumn::make('payment_method')->label('Metode')->badge()
                    ->formatStateUsing(fn (string $state) => AdminFormat::METHODS[$state] ?? $state),
                TextColumn::make('status')->label('Status')->badge()
                    ->formatStateUsing(fn (string $state) => AdminFormat::STATUSES[$state] ?? $state)
                    ->color(fn (string $state) => AdminFormat::statusColor($state)),
                TextColumn::make('created_at')->label('Dibuat')->dateTime('j M Y, H.i')->sortable(),
            ])
            ->filters([
                SelectFilter::make('status')->label('Status')->options(AdminFormat::STATUSES),
                SelectFilter::make('payment_method')->label('Metode')->options(AdminFormat::METHODS),
                SelectFilter::make('type')->label('Jenis')->options(['package' => 'Paket', 'topup' => 'Isi ulang']),
                AdminFormat::dateRange('created_at', 'Tanggal dibuat'),
            ])
            ->recordActions([ViewAction::make()]);
    }
}
