<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Subscriber extends Model
{
    /**
     * "0881-0000-0001", "+62 881 0000 0001", atau "6288100000001" → "6288100000001".
     * Null jika bukan nomor seluler Indonesia.
     */
    public static function normalizeMsisdn(string $input): ?string
    {
        $digits = preg_replace('/[\s\-().]/', '', $input);
        $digits = preg_replace('/^(\+62|62|0)/', '62', $digits, 1);

        return preg_match('/^628\d{7,11}$/', $digits) ? $digits : null;
    }

    /** Nomor orang lain selalu tersamar: "6281298765432" → "0812••••5432". */
    public static function maskMsisdn(string $msisdn): string
    {
        $local = '0'.substr($msisdn, 2);

        return substr($local, 0, 4).'••••'.substr($local, -4);
    }

    protected function casts(): array
    {
        return [
            'active_until' => 'date',
            'grace_until' => 'date',
        ];
    }

    public function user(): HasOne
    {
        return $this->hasOne(User::class);
    }

    public function subscriptions(): HasMany
    {
        return $this->hasMany(Subscription::class);
    }
}
