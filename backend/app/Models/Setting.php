<?php

namespace App\Models;

use App\Services\SettingService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;

class Setting extends Model
{
    protected static function booted(): void
    {
        $forget = fn () => Cache::forget(SettingService::CACHE_KEY);
        static::saved($forget);
        static::deleted($forget);
    }

    protected function casts(): array
    {
        return [
            'value' => 'array',
            'is_system' => 'boolean',
        ];
    }
}
