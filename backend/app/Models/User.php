<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Laravel\Sanctum\HasApiTokens;

class User extends Authenticatable
{
    use HasApiTokens;

    protected function casts(): array
    {
        return [
            'last_login_at' => 'datetime',
            'usage_access_granted' => 'boolean',
            'usage_access_checked_at' => 'datetime',
        ];
    }

    /** Saldo poin = SUM(delta) ledger; hold sudah tercatat negatif (FR-11.5). */
    public function pointBalance(): int
    {
        return (int) $this->pointLedger()->sum('delta');
    }

    public function subscriber(): BelongsTo
    {
        return $this->belongsTo(Subscriber::class);
    }

    public function transactions(): HasMany
    {
        return $this->hasMany(Transaction::class);
    }

    public function usageRecords(): HasMany
    {
        return $this->hasMany(UsageRecord::class);
    }

    public function forecasts(): HasMany
    {
        return $this->hasMany(Forecast::class);
    }

    public function dailyEvaluations(): HasMany
    {
        return $this->hasMany(DailyEvaluation::class);
    }

    public function recommendations(): HasMany
    {
        return $this->hasMany(Recommendation::class);
    }

    public function pointLedger(): HasMany
    {
        return $this->hasMany(PointLedger::class);
    }

    public function notifications(): HasMany
    {
        return $this->hasMany(Notification::class);
    }

    public function quotaTransfers(): HasMany
    {
        return $this->hasMany(QuotaTransfer::class, 'sender_user_id');
    }
}
