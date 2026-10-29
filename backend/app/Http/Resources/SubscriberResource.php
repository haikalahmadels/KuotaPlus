<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Objek bersama `Subscriber` (docs/API-KuotaPlus.md). */
class SubscriberResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        return [
            'msisdn' => $this->msisdn,
            'pulsa_balance' => $this->pulsa_balance,
            'status' => $this->status,
            'active_until' => $this->active_until->toDateString(),
            'days_left' => max(0, (int) today()->diffInDays($this->active_until, false)),
            'grace_until' => $this->grace_until?->toDateString(),
        ];
    }
}
