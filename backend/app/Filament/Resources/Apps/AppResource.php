<?php

namespace App\Filament\Resources\Apps;

use App\Filament\Resources\Apps\Pages\EditApp;
use App\Filament\Resources\Apps\Pages\ListApps;
use App\Filament\Resources\Apps\Schemas\AppForm;
use App\Filament\Resources\Apps\Tables\AppsTable;
use App\Models\App;
use BackedEnum;
use Filament\Resources\Resource;
use Filament\Schemas\Schema;
use Filament\Support\Icons\Heroicon;
use Filament\Tables\Table;
use Illuminate\Database\Eloquent\Model;
use UnitEnum;

/** FR-15.4: aplikasi muncul sendiri dari sync; admin hanya mengatur kategori. */
class AppResource extends Resource
{
    protected static ?string $model = App::class;

    protected static string|BackedEnum|null $navigationIcon = Heroicon::OutlinedSquares2x2;

    protected static ?string $modelLabel = 'aplikasi';

    protected static ?string $pluralModelLabel = 'Kategori aplikasi';

    protected static ?string $recordTitleAttribute = 'label';

    protected static string|UnitEnum|null $navigationGroup = 'Katalog';

    protected static ?int $navigationSort = 2;

    public static function form(Schema $schema): Schema
    {
        return AppForm::configure($schema);
    }

    public static function table(Table $table): Table
    {
        return AppsTable::configure($table);
    }

    public static function canCreate(): bool
    {
        return false;
    }

    public static function canDelete(Model $record): bool
    {
        return false;
    }

    /** Badge jumlah aplikasi yang belum ditinjau di navigasi. */
    public static function getNavigationBadge(): ?string
    {
        $count = App::where('is_reviewed', false)->count();

        return $count > 0 ? (string) $count : null;
    }

    public static function getPages(): array
    {
        return [
            'index' => ListApps::route('/'),
            'edit' => EditApp::route('/{record}/edit'),
        ];
    }
}
