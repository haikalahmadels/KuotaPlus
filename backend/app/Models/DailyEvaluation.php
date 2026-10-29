<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use Illuminate\Database\Eloquent\Relations\BelongsTo;
use Illuminate\Database\Eloquent\Relations\HasMany;

class DailyEvaluation extends Model
{
    protected function casts(): array
    {
        return [
            'eval_date' => 'date',
        ];
    }

    /** Poin hasil evaluasi ini (earn_daily + earn_streak). */
    public function pointLedger(): HasMany
    {
        return $this->hasMany(PointLedger::class, 'ref_id')->where('ref_type', 'daily_evaluations');
    }

    public function user(): BelongsTo
    {
        return $this->belongsTo(User::class);
    }
}
