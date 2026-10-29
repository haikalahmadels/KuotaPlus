<?php

namespace App\Http\Resources;

use App\Services\TransactionService;
use Illuminate\Http\Request;
use Illuminate\Http\Resources\Json\JsonResource;

/**
 * Objek bersama `Transaction` (docs/API-KuotaPlus.md). Butuh relasi package dan subscription sudah dimuat.
 * Daftar riwayat memakai TransactionSummaryResource supaya instruksi bayar tidak ikut dikirim.
 */
class TransactionResource extends JsonResource
{
    protected bool $withPayment = true;

    public function toArray(Request $request): array
    {
        $data = [
            'id' => $this->id,
            'type' => $this->type,
            'item_name' => $this->type === 'package'
                ? $this->package->name
                : 'Isi ulang '.TransactionService::rupiah($this->topup_amount),
            'package_id' => $this->package_id,
            'topup_amount' => $this->topup_amount,
            'gross_amount' => $this->gross_amount,
            'discount_amount' => $this->discount_amount,
            'points_used' => $this->points_used,
            'net_amount' => $this->net_amount,
            'payment_method' => $this->payment_method,
            'status' => $this->status,
            'external_ref' => $this->external_ref,
            'expires_at' => $this->expires_at?->toIso8601String(),
            'paid_at' => $this->paid_at?->toIso8601String(),
            'created_at' => $this->created_at->toIso8601String(),
        ];

        if ($this->withPayment) {
            $data['payment'] = $this->payment();
            $data['subscription_id'] = $this->subscription?->id;
        }

        return $data;
    }

    private function payment(): ?array
    {
        if ($this->payment_method === 'pulsa') {
            return null;
        }

        $payload = $this->payment_payload ?? [];

        return [
            'va_number' => $payload['va_number'] ?? null,
            'bank_label' => $payload['bank_label'] ?? null,
            // QR digambar di Flutter dari string ini (docs/TECH-KuotaPlus.md).
            'qr_string' => $this->payment_method === 'qris' ? "NUSANTEL-QRIS|{$this->external_ref}|{$this->net_amount}" : null,
            'simulator_url' => rtrim(config('app.url'), '/').'/simulator/'.$this->external_ref,
        ];
    }
}
