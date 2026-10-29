<?php

namespace App\Services;

use App\Models\Setting;
use Illuminate\Support\Facades\Cache;
use InvalidArgumentException;

/**
 * Parameter bisnis dari tabel settings (FR-15.10). Cache dihapus oleh Setting::booted() setiap kali ada perubahan.
 */
class SettingService
{
    public const CACHE_KEY = 'settings.all';

    public function get(string $key): mixed
    {
        $all = Cache::rememberForever(self::CACHE_KEY, fn () => Setting::pluck('value', 'key')->all());

        if (! array_key_exists($key, $all)) {
            throw new InvalidArgumentException("Setting [$key] tidak ada. Jalankan SettingSeeder.");
        }

        return $all[$key];
    }

    public function int(string $key): int
    {
        return (int) $this->get($key);
    }
}
