<?php

namespace App\Models;

use App\Exceptions\ApiException;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;

class Package extends Model
{
    protected static function booted(): void
    {
        // FR-15.3: paket yang pernah dibeli hanya bisa dinonaktifkan, tidak dihapus.
        static::deleting(function (Package $package) {
            if ($package->wasPurchased()) {
                throw new ApiException(422, 'PACKAGE_PURCHASED', 'Paket yang pernah dibeli tidak bisa dihapus. Nonaktifkan saja.');
            }
        });

        // FR-15.5: rekomendasi yang lebih lama dari perubahan katalog dihitung ulang saat dibuka berikutnya.
        $touch = fn () => Setting::where('key', 'catalog.updated_at')->first()?->update(['value' => now()->toIso8601String()]);
        static::saved($touch);
        static::deleted($touch);
    }

    public function wasPurchased(): bool
    {
        return $this->subscriptions()->exists() || $this->transactions()->exists();
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    protected function casts(): array
    {
        return [
            'is_active' => 'boolean',
        ];
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }
}
