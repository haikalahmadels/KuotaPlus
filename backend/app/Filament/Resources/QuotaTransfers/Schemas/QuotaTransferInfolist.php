<?php

namespace App\Filament\Resources\QuotaTransfers\Schemas;

use App\Filament\Support\AdminFormat;
use App\Support\Format;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class QuotaTransferInfolist
{
    public static function configure(Schema $schema): Schema
    {
        return $schema->components([
            Section::make('Transfer')->columns(3)->columnSpanFull()->schema([
                TextEntry::make('sender.subscriber.msisdn')->label('Pengirim')->formatStateUsing(fn (?string $state) => AdminFormat::msisdn($state)),
                TextEntry::make('recipient.msisdn')->label('Penerima')->formatStateUsing(fn (?string $state) => AdminFormat::msisdn($state)),
                TextEntry::make('bytes')->label('Jumlah')->formatStateUsing(fn (int $state) => Format::gb($state)),
                TextEntry::make('points_spent')->label('Poin')->suffix(' poin'),
                TextEntry::make('status')->label('Status')->badge(),
                TextEntry::make('completed_at')->label('Selesai')->dateTime('j M Y, H.i'),
                TextEntry::make('expires_at')->label('Berlaku di penerima s.d.')->dateTime('j M Y, H.i'),
            ]),
            Section::make('Sumber kuota')->columnSpanFull()->schema([
                RepeatableEntry::make('sources')->hiddenLabel()->columns(2)->schema([
                    TextEntry::make('subscription.package.name')->label('Paket')->placeholder('—'),
                    TextEntry::make('bytes')->label('Dipotong')->formatStateUsing(fn (int $state) => Format::bytes($state)),
                ]),
            ]),
        ]);
    }
}
