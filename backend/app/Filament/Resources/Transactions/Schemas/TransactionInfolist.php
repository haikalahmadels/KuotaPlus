<?php

namespace App\Filament\Resources\Transactions\Schemas;

use App\Filament\Support\AdminFormat;
use App\Models\Transaction;
use App\Support\Format;
use Filament\Infolists\Components\IconEntry;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class TransactionInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Transaksi')->columns(3)->columnSpanFull()->schema([
                TextEntry::make('external_ref')->label('Ref')->copyable(),
                TextEntry::make('user.subscriber.msisdn')->label('Nomor')
                    ->formatStateUsing(fn (?string $state) => AdminFormat::msisdn($state)),
                TextEntry::make('item')->label('Item')->state(fn (Transaction $record) => AdminFormat::item($record)),
                TextEntry::make('gross_amount')->label('Harga')->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                TextEntry::make('discount_amount')->label('Diskon poin')
                    ->formatStateUsing(fn (int $state, Transaction $record) => Format::rupiah($state).' ('.$record->points_used.' poin)'),
                TextEntry::make('net_amount')->label('Dibayar')->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                TextEntry::make('payment_method')->label('Metode')
                    ->formatStateUsing(fn (string $state) => AdminFormat::METHODS[$state] ?? $state),
                TextEntry::make('status')->label('Status')->badge()
                    ->formatStateUsing(fn (string $state) => AdminFormat::STATUSES[$state] ?? $state)
                    ->color(fn (string $state) => AdminFormat::statusColor($state)),
                TextEntry::make('recommendation_id')->label('Dari rekomendasi')
                    ->formatStateUsing(fn ($state) => $state ? 'Ya (#'.$state.')' : 'Tidak')->placeholder('Tidak'),
                TextEntry::make('created_at')->label('Dibuat')->dateTime('j M Y, H.i'),
                TextEntry::make('expires_at')->label('Batas bayar')->dateTime('j M Y, H.i')->placeholder('—'),
                TextEntry::make('paid_at')->label('Dibayar pada')->dateTime('j M Y, H.i')->placeholder('—'),
            ]),
            Section::make('Log callback pembayaran')->columnSpanFull()->schema([
                RepeatableEntry::make('callbacks')
                    ->hiddenLabel()
                    ->placeholder('Belum ada callback.')
                    ->columns(3)
                    ->schema([
                        TextEntry::make('created_at')->label('Waktu')->dateTime('j M Y, H.i:s'),
                        IconEntry::make('signature_valid')->label('Signature valid')->boolean(),
                        TextEntry::make('payload')->label('Payload')
                            ->formatStateUsing(fn ($state) => json_encode($state, JSON_UNESCAPED_UNICODE))
                            ->fontFamily('mono'),
                    ]),
            ]),
        ]);
    }
}
