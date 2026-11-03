<?php

namespace App\Filament\Resources\AdminAuditLogs;

use App\Filament\Resources\AdminAuditLogs\Pages\ListAdminAuditLogs;
use App\Filament\Resources\AdminAuditLogs\Pages\ViewAdminAuditLog;
use App\Filament\Resources\AdminAuditLogs\Schemas\AdminAuditLogInfolist;
use App\Filament\Resources\AdminAuditLogs\Tables\AdminAuditLogsTable;
use App\Models\AdminAuditLog;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/** FR-15.11: hanya baca. Model juga menolak update dan delete. */
class AdminAuditLogResource extends Resource
{
    protected static ?string $model = AdminAuditLog::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedClipboardDocumentList;

    protected static ?string $modelLabel = 'log';

    protected static ?string $pluralModelLabel = 'Audit log';

    protected static string|UnitEnum|null $navigationGroup = 'Sistem';

    protected static ?int $navigationSort = 2;

    public static function infolist(Schema $schema): Schema
    {
        return AdminAuditLogInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return AdminAuditLogsTable::configure($table);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canEdit(Model $record): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListAdminAuditLogs::route('/'),
            'view' => ViewAdminAuditLog::route('/{record}'),
        ];
    }
}
