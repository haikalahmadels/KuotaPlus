<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class QuotaTransferSource extends Model
{
    public function quotaTransfer(): BelongsTo
    {
        return $this->belongsTo(QuotaTransfer::class);
    }

    public function subscription(): BelongsTo
    {
        return $this->belongsTo(Subscription::class);
    }
}
