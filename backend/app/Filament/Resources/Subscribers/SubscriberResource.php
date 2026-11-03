<?php

namespace App\Filament\Resources\Subscribers;

use App\Filament\Resources\Subscribers\Pages\ListSubscribers;
use App\Filament\Resources\Subscribers\Pages\ViewSubscriber;
use App\Filament\Resources\Subscribers\Schemas\SubscriberInfolist;
use App\Filament\Resources\Subscribers\Tables\SubscribersTable;
use App\Models\Subscriber;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/** FR-15.7–15.8: hanya baca, tanpa pemakaian per aplikasi milik pelanggan. */
class SubscriberResource extends Resource
{
    protected static ?string $model = Subscriber::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedUsers;

    protected static ?string $modelLabel = 'pelanggan';

    protected static ?string $pluralModelLabel = 'Pelanggan';

    protected static ?string $recordTitleAttribute = 'msisdn';

    protected static string|UnitEnum|null $navigationGroup = 'Pelanggan';

    protected static ?int $navigationSort = 1;

    public static function infolist(Schema $schema): Schema
    {
        return SubscriberInfolist::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return SubscribersTable::configure($table);
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
            'index' => ListSubscribers::route('/'),
            'view' => ViewSubscriber::route('/{record}'),
        ];
    }
}
