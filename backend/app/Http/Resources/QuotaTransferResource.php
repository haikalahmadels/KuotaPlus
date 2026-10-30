<?php

namespace App\Http\Resources;

use App\Models\Subscriber;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Item berbagi kuota (docs/API-KuotaPlus.md, FR-14). sender_main_remaining_after hanya di respons POST. */
class QuotaTransferResource extends JsonResource
{
    public ?int $senderRemainingAfter = null;

    public function toArray(Request $request): array
    {
        return [
            'id' => $this->id,
            'recipient_msisdn_masked' => Subscriber::maskMsisdn($this->recipient->msisdn),
            'bytes' => $this->bytes,
            'points_spent' => $this->points_spent,
            'recipient_expires_at' => $this->expires_at->toIso8601String(),
            'status' => $this->status,
            'completed_at' => $this->completed_at?->toIso8601String(),
            'sender_main_remaining_after' => $this->when($this->senderRemainingAfter !== null, $this->senderRemainingAfter),
        ];
    }
}
