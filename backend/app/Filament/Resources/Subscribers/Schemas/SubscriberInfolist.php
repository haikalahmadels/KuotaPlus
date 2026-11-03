<?php

namespace App\Filament\Resources\Subscribers\Schemas;

use App\Filament\Support\AdminFormat;
use App\Models\Subscriber;
use App\Support\Format;
use Filament\Infolists\Components\RepeatableEntry;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

/**
 * FR-15.7: data kartu, paket aktif, poin, transaksi, berbagi, dan TOTAL pemakaian harian.
 * FR-15.8: sengaja tidak ada rincian per aplikasi.
 */
class SubscriberInfolist
{
    public static function configure(Schema $schema): Schema
    {
        $user = fn (Subscriber $record) => $record->user;

        return $schema->components([
            Section::make('Kartu')->columns(4)->columnSpanFull()->schema([
                TextEntry::make('msisdn')->label('Nomor')->formatStateUsing(fn (string $state) => AdminFormat::msisdn($state)),
                TextEntry::make('status')->label('Status')->badge()
                    ->formatStateUsing(fn (string $state) => AdminFormat::CARD[$state] ?? $state),
                TextEntry::make('pulsa_balance')->label('Pulsa')->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                TextEntry::make('active_until')->label('Aktif s.d.')->date('j M Y'),
                TextEntry::make('points')->label('Saldo poin')
                    ->state(fn (Subscriber $record) => $user($record)?->pointBalance() ?? 0)->suffix(' poin'),
                TextEntry::make('account')->label('Akun Kuota+')
                    ->state(fn (Subscriber $record) => $user($record) ? 'Ada (platform '.($user($record)->platform ?? '—').')' : 'Belum'),
            ]),
            Section::make('Paket aktif')->columnSpanFull()->schema([
                RepeatableEntry::make('active')->hiddenLabel()->placeholder('Tidak ada paket aktif.')->columns(4)
                    ->state(fn (Subscriber $record) => $record->subscriptions()->current()->with('package')->get())
                    ->schema([
                        TextEntry::make('package.name')->label('Paket')->placeholder('Kuota kiriman'),
                        TextEntry::make('main')->label('Kuota utama')
                            ->state(fn ($record) => Format::bytes($record->main_total - $record->main_used).' dari '.Format::bytes($record->main_total)),
                        TextEntry::make('status')->label('Status'),
                        TextEntry::make('expires_at')->label('Berakhir')->dateTime('j M Y, H.i'),
                    ]),
            ]),
            Section::make('Total pemakaian harian (14 hari)')->columnSpanFull()->schema([
                RepeatableEntry::make('daily')->hiddenLabel()->placeholder('Belum ada data pemakaian.')->columns(2)
                    ->state(fn (Subscriber $record) => $user($record)?->usageRecords()
                        ->where('usage_date', '>=', today()->subDays(13))
                        ->selectRaw('usage_date, SUM(bytes_mobile) AS total')
                        ->groupBy('usage_date')->orderByDesc('usage_date')->get()
                        ->map(fn ($row) => ['date' => $row->usage_date, 'total' => Format::bytes((int) $row->total)])
                        ->all() ?? [])
                    ->schema([
                        TextEntry::make('date')->label('Tanggal')->date('j M Y'),
                        TextEntry::make('total')->label('Total'),
                    ]),
            ]),
            Section::make('Transaksi terbaru')->columnSpanFull()->collapsible()->schema([
                RepeatableEntry::make('transactions')->hiddenLabel()->placeholder('Belum ada transaksi.')->columns(4)
                    ->state(fn (Subscriber $record) => $user($record)?->transactions()->with('package')->latest('id')->limit(10)->get() ?? [])
                    ->schema([
                        TextEntry::make('item')->label('Item')->state(fn ($record) => AdminFormat::item($record)),
                        TextEntry::make('net_amount')->label('Dibayar')->formatStateUsing(fn (int $state) => Format::rupiah($state)),
                        TextEntry::make('status')->label('Status')->formatStateUsing(fn (string $state) => AdminFormat::STATUSES[$state] ?? $state),
                        TextEntry::make('created_at')->label('Dibuat')->dateTime('j M Y, H.i'),
                    ]),
            ]),
            Section::make('Riwayat berbagi kuota')->columnSpanFull()->collapsible()->schema([
                RepeatableEntry::make('transfers')->hiddenLabel()->placeholder('Belum pernah berbagi.')->columns(4)
                    ->state(fn (Subscriber $record) => $user($record)?->quotaTransfers()->with('recipient')->latest('id')->limit(10)->get() ?? [])
                    ->schema([
                        TextEntry::make('recipient.msisdn')->label('Penerima')->formatStateUsing(fn (string $state) => AdminFormat::msisdn($state)),
                        TextEntry::make('bytes')->label('Jumlah')->formatStateUsing(fn (int $state) => Format::gb($state)),
                        TextEntry::make('points_spent')->label('Poin')->suffix(' poin'),
                        TextEntry::make('completed_at')->label('Selesai')->dateTime('j M Y, H.i'),
                    ]),
            ]),
        ]);
    }
}
