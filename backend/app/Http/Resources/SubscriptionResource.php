<?php

namespace App\Http\Resources;

use App\Models\Subscriber;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Objek bersama `Subscription` (docs/API-KuotaPlus.md).
 * Butuh relasi package dan incomingTransfer.sender.subscriber sudah dimuat.
 */
class SubscriptionResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $sharedFrom = $this->source === 'shared'
            ? Subscriber::maskMsisdn($this->incomingTransfer->sender->subscriber->msisdn)
            : null;

        return [
            'id' => $this->id,
            'source' => $this->source,
            'name' => $sharedFrom ? "Kuota dari {$sharedFrom}" : $this->package->name,
            'main_total' => $this->main_total,
            'main_used' => $this->main_used,
            'main_remaining' => max(0, $this->main_total - $this->main_used),
            'app_total' => $this->app_total,
            'app_used' => $this->app_used,
            'app_remaining' => max(0, $this->app_total - $this->app_used),
            'app_category' => $this->app_category,
            'started_at' => $this->started_at->toIso8601String(),
            'expires_at' => $this->expires_at->toIso8601String(),
            'status' => $this->status,
            'shared_from' => $sharedFrom,
        ];
    }
}
