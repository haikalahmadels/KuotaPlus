<?php

namespace App\Filament\Resources\Settings\Tables;

use App\Filament\Resources\Settings\Schemas\SettingForm;
use App\Models\Setting;
use Filament\Actions\EditAction;
use Filament\Tables\Columns\TextColumn;
use Filament\Tables\Table;

class SettingsTable
{
    public static function configure(Table $table): Table
    {
        return $table
            ->defaultSort('key')
            ->paginated(false)
            ->columns([
                TextColumn::make('key')->label('Parameter')
                    ->formatStateUsing(fn (string $state) => SettingForm::label($state))
                    ->description(fn (Setting $record) => $record->key)
                    ->searchable(),
                TextColumn::make('value')->label('Nilai')
                    ->state(fn (Setting $record) => SettingForm::readable($record)),
                TextColumn::make('updated_at')->label('Diubah')->dateTime('j M Y, H.i')->sortable(),
            ])
            ->recordActions([EditAction::make()]);
    }
}
