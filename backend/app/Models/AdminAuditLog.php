<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;
use LogicException;
use Illuminate\Database\Eloquent\Relations\BelongsTo;

class AdminAuditLog extends Model
{
    const UPDATED_AT = null;

    /** FR-15.11: log tidak bisa diubah atau dihapus. */
    protected static function booted(): void
    {
        $immutable = fn () => throw new LogicException('Audit log tidak bisa diubah atau dihapus.');
        static::updating($immutable);
        static::deleting($immutable);
    }

    protected function casts(): array
    {
        return [
            'before' => 'array',
            'after' => 'array',
        ];
    }

    public function admin(): BelongsTo
    {
        return $this->belongsTo(Admin::class);
    }
}
