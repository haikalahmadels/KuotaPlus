<?php

namespace App\Models;

use App\Services\SettingService;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\ValidationException;

class Setting extends Model
{
    protected static function booted(): void
    {
        // FR-15.10: setiap key punya rentang; nilai di luar rentang ditolak apa pun jalurnya.
        static::saving(function (Setting $setting) {
            $value = $setting->value;
            if (is_numeric($value) && (($setting->min !== null && $value < $setting->min) || ($setting->max !== null && $value > $setting->max))) {
                throw ValidationException::withMessages([
                    'value' => "Nilai {$setting->key} harus antara {$setting->min} dan {$setting->max}.",
                ]);
            }
        });

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
