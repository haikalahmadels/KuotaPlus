<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Builder;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasOne;

class Subscription extends Model
{
    protected function casts(): array
    {
        return [
            'started_at' => 'datetime',
            'expires_at' => 'datetime',
        ];
    }

    /** Paket yang belum berakhir, termasuk yang kuotanya sudah habis. Paling cepat berakhir lebih dulu. */
    public function scopeCurrent(Builder $query): void
    {
        $query->whereIn('status', ['active', 'exhausted'])
            ->where('expires_at', '>', now())
            ->orderBy('expires_at');
    }

    public function subscriber(): BelongsTo
    {
        return $this->belongsTo(Subscriber::class);
    }

    public function package(): BelongsTo
    {
        return $this->belongsTo(Package::class);
    }

    public function transaction(): BelongsTo
    {
        return $this->belongsTo(Transaction::class);
    }

    /** Untuk paket source = shared: transfer yang membuatnya. */
    public function incomingTransfer(): HasOne
    {
        return $this->hasOne(QuotaTransfer::class, 'recipient_subscription_id');
    }
}
