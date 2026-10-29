<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class QuotaTransfer extends Model
{
    protected function casts(): array
    {
        return [
            'expires_at' => 'datetime',
            'completed_at' => 'datetime',
        ];
    }

    public function sender(): BelongsTo
    {
        return $this->belongsTo(User::class, 'sender_user_id');
    }

    public function recipient(): BelongsTo
    {
        return $this->belongsTo(Subscriber::class, 'recipient_subscriber_id');
    }

    public function recipientSubscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class, 'recipient_subscription_id');
    }

    public function sources(): HasMany
    {
        return $this->hasMany(QuotaTransferSource::class);
    }
}
