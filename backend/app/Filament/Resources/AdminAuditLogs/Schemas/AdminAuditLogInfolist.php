<?php

namespace App\Filament\Resources\AdminAuditLogs\Schemas;

use App\Filament\Support\AdminFormat;
use Filament\Infolists\Components\TextEntry;
use Filament\Schemas\Components\Section;
use Filament\Schemas\Schema;

class AdminAuditLogInfolist
{
    public static function configure(Schema $schema): Schema
    {
        $json = fn (?array $value) => $value === null ? '—' : json_encode($value, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);

        return $schema->components([
            Section::make('Log')->columns(3)->columnSpanFull()->schema([
                TextEntry::make('created_at')->label('Waktu')->dateTime('j M Y, H.i:s'),
                TextEntry::make('admin.name')->label('Admin'),
                TextEntry::make('ip')->label('IP'),
                TextEntry::make('action')->label('Aksi')->formatStateUsing(fn (string $state) => AdminFormat::ACTIONS[$state] ?? $state),
                TextEntry::make('entity_type')->label('Data')->formatStateUsing(fn (string $state) => AdminFormat::ENTITIES[$state] ?? $state),
                TextEntry::make('entity_id')->label('ID'),
            ]),
            Section::make('Sebelum')->schema([
                TextEntry::make('before_json')->hiddenLabel()->fontFamily('mono')
                    ->state(fn ($record) => $json($record->before))->extraAttributes(['style' => 'white-space: pre-wrap']),
            ]),
            Section::make('Sesudah')->schema([
                TextEntry::make('after_json')->hiddenLabel()->fontFamily('mono')
                    ->state(fn ($record) => $json($record->after))->extraAttributes(['style' => 'white-space: pre-wrap']),
            ]),
        ]);
    }
}
