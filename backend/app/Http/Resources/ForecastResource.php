<?php

namespace App\Http\Resources;

use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/** Objek bersama `Forecast` (docs/API-KuotaPlus.md). confidence = none → angka prediksi null. */
class ForecastResource extends JsonResource
{
    public function toArray(Request $request): array
    {
        $shown = $this->confidence !== 'none';
        $risk = $this->status === 'risk';

        return [
            'confidence' => $this->confidence,
            'status' => $this->status,
            'avg_daily_bytes' => $shown ? $this->avg_daily_bytes : null,
            'remaining_bytes' => $this->remaining_bytes,
            'predicted_empty_at' => $this->predicted_empty_at?->toIso8601String(),
            'main_expires_at' => $this->main_expires_at->toIso8601String(),
            'days_early' => $risk ? (int) ceil($this->predicted_empty_at->diffInSeconds($this->main_expires_at) / 86400) : null,
            'computed_at' => $this->computed_at->toIso8601String(),
        ];
    }
}
