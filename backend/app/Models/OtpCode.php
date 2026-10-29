<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Model;

class OtpCode extends Model
{
    protected function casts(): array
    {
        return [
            'context' => 'array',
            'expires_at' => 'datetime',
            'locked_until' => 'datetime',
        ];
    }
}
