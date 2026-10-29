<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\PaymentCallback;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Callback payment gateway dummy dan provisioning (FR-5.5–5.8).
 */
class PaymentService
{
    public function __construct(private SettingService $settings) {}

    public static function sign(string $rawBody): string
    {
        return hash_hmac('sha256', $rawBody, (string) config('services.payment.webhook_secret'));
    }

    public function handleCallback(string $rawBody, ?string $signature): void
    {
        $payload = json_decode($rawBody, true);
        $valid = filled(config('services.payment.webhook_secret'))
            && $signature !== null
            && hash_equals(self::sign($rawBody), $signature);

        // Dicatat di luar transaksi DB supaya tetap ada walau pemrosesan di-rollback.
        $log = PaymentCallback::create([
            'external_ref' => mb_substr((string) ($payload['external_ref'] ?? ''), 0, 64),
            'payload' => is_array($payload) ? $payload : ['raw' => mb_substr($rawBody, 0, 1000)],
            'signature_valid' => $valid,
        ]);

        if (! $valid) {
            throw new ApiException(401, 'INVALID_SIGNATURE', 'Signature callback tidak valid.');
        }
        if (! is_array($payload) || ! in_array($payload['status'] ?? null, ['PAID', 'FAILED'], true) || ! is_string($payload['external_ref'] ?? null)) {
            throw new ApiException(422, 'VALIDATION_FAILED', 'Payload callback tidak lengkap.');
        }

        // Error "sudah kedaluwarsa" dilempar setelah commit supaya perubahan status ke expired tetap tersimpan.
        $error = DB::transaction(function () use ($payload, $log) {
            $transaction = Transaction::where('external_ref', $payload['external_ref'])->lockForUpdate()->first()
                ?? throw new ApiException(404, 'NOT_FOUND', 'Transaksi tidak ditemukan.');
            User::whereKey($transaction->user_id)->lockForUpdate()->first();

            if ($transaction->status === 'pending' && $transaction->expires_at?->isPast()) {
                $this->expire($transaction);
            }

            $log->update(['processed_at' => now()]);

            return match ($transaction->status) {
                'expired' => new ApiException(409, 'TRANSACTION_EXPIRED', 'Transaksi sudah kedaluwarsa.'),
                // Callback ganda atau setelah status final: tanpa efek (FR-5.6).
                'paid', 'failed' => null,
                default => $this->settle($transaction, $payload['status']),
            };
        });

        if ($error) {
            throw $error;
        }
    }

    private function settle(Transaction $transaction, string $status): null
    {
        if ($status === 'PAID') {
            $transaction->update(['status' => 'paid', 'paid_at' => now()]);
            $this->provision($transaction);
        } else {
            $transaction->update(['status' => 'failed']);
            // Pengembalian poin yang di-hold ditambahkan di M6 (FR-12.3).
        }

        return null;
    }

    /** Dipanggil di dalam transaksi DB yang sudah mengunci baris transaksi. */
    public function expire(Transaction $transaction): void
    {
        $transaction->update(['status' => 'expired']);
        // Pengembalian poin yang di-hold ditambahkan di M6 (FR-12.3).
    }

    /**
     * Menambah paket atau pulsa untuk transaksi yang baru PAID. Selalu dipanggil di dalam transaksi DB,
     * jadi kegagalan di sini membatalkan status paid juga (tidak ada PAID tanpa paket).
     */
    public function provision(Transaction $transaction): void
    {
        $subscriber = Subscriber::whereKey($transaction->user->subscriber_id)->lockForUpdate()->first();

        if ($transaction->type === 'package') {
            $package = $transaction->package;

            // Paket berjalan paralel dengan paket lain dan tidak memperpanjang masa aktif kartu (FR-3.5).
            Subscription::create([
                'subscriber_id' => $subscriber->id,
                'source' => 'purchase',
                'package_id' => $package->id,
                'transaction_id' => $transaction->id,
                'main_total' => $package->main_quota,
                'app_total' => $package->app_quota,
                'app_category' => $package->app_category,
                'started_at' => now(),
                'expires_at' => now()->addDays($package->validity_days),
                'status' => 'active',
            ]);

            return;
        }

        // FR-4.3: perpanjangan dihitung dari masa aktif saat ini, bukan dari hari ini.
        $activeUntil = $subscriber->active_until->copy()->addDays($transaction->payment_payload['extend_days']);
        $reactivated = $activeUntil->gte(today());

        $subscriber->update([
            'pulsa_balance' => $subscriber->pulsa_balance + $transaction->topup_amount,
            'active_until' => $activeUntil,
            'status' => $reactivated ? 'active' : $subscriber->status,
            'grace_until' => $reactivated ? null : $subscriber->grace_until,
        ]);
    }
}
