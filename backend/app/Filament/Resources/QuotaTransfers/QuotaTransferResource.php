<?php

namespace App\Filament\Resources\QuotaTransfers;

use App\Filament\Resources\QuotaTransfers\Pages\ListQuotaTransfers;
use App\Filament\Resources\QuotaTransfers\Pages\ViewQuotaTransfer;
use App\Filament\Resources\QuotaTransfers\Schemas\QuotaTransferInfolist;
use App\Filament\Resources\QuotaTransfers\Tables\QuotaTransfersTable;
use App\Models\QuotaTransfer;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/** FR-15.9: daftar transfer, hanya baca. */
class QuotaTransferResource extends Resource
{
    protected static ?string $model = QuotaTransfer::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedArrowsRightLeft;

    protected static ?string $modelLabel = 'transfer';

    protected static ?string $pluralModelLabel = 'Berbagi kuota';

    protected static string|UnitEnum|null $navigationGroup = 'Pelanggan';

    protected static ?int $navigationSort = 3;

    public static function infolist(Schema $schema): Schema
    {
        return QuotaTransferInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return QuotaTransfersTable::configure($table);
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
            'index' => ListQuotaTransfers::route('/'),
            'view' => ViewQuotaTransfer::route('/{record}'),
        ];
    }
}
