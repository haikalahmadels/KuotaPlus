<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\Package;
use App\Models\Subscriber;
use App\Models\Transaction;
use App\Models\User;
use App\Support\Format;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

/**
 * Membuat transaksi beli paket / isi ulang (FR-3, FR-4, FR-5). Satu-satunya pintu masuk perubahan pulsa dan paket,
 * bersama PaymentService yang memprovisioning hasil pembayaran.
 */
class TransactionService
{
    public const PENDING_MINUTES = 15;

    public function __construct(
        private PaymentService $payments,
        private SettingService $settings,
        private PointService $points,
    ) {}

    /**
     * @param  array{type: string, package_id?: int, topup_amount?: int, points_used?: int, payment_method: string, recommendation_id?: int}  $input  sudah divalidasi
     * @return array{0: Transaction, 1: bool} transaksi dan apakah baru dibuat (false = replay Idempotency-Key)
     */
    public function create(User $user, array $input, string $idempotencyKey): array
    {
        $input = [
            'type' => $input['type'],
            'package_id' => $input['package_id'] ?? null,
            'topup_amount' => $input['topup_amount'] ?? null,
            'points_used' => (int) ($input['points_used'] ?? 0),
            'payment_method' => $input['payment_method'],
            'recommendation_id' => $input['recommendation_id'] ?? null,
        ];
        $hash = hash('sha256', json_encode($input));

        // Kunci baris users = antrean per pengguna (docs/TECH-KuotaPlus.md, Konkurensi), termasuk dua request dengan key yang sama.
        return DB::transaction(function () use ($user, $input, $idempotencyKey, $hash) {
            User::whereKey($user->id)->lockForUpdate()->first();

            $existing = Transaction::where(['user_id' => $user->id, 'idempotency_key' => $idempotencyKey])->first();
            if ($existing) {
                if ($existing->request_hash !== $hash) {
                    throw new ApiException(422, 'IDEMPOTENCY_KEY_MISMATCH', 'Permintaan berbeda memakai Idempotency-Key yang sama.');
                }

                return [$existing, false];
            }

            $subscriber = Subscriber::whereKey($user->subscriber_id)->lockForUpdate()->first();

            return [$this->createLocked($user, $subscriber, $input, $idempotencyKey, $hash), true];
        });
    }

    private function createLocked(User $user, Subscriber $subscriber, array $input, string $key, string $hash): Transaction
    {
        $isPackage = $input['type'] === 'package';

        if ($subscriber->status === 'terminated') {
            throw new ApiException(403, 'SUBSCRIBER_TERMINATED', 'Nomor ini sudah tidak aktif.');
        }
        if ($isPackage && $subscriber->status === 'grace') {
            throw new ApiException(403, 'SUBSCRIBER_IN_GRACE',
                'Nomor sedang dalam masa tenggang. Isi ulang pulsa dulu untuk bisa membeli paket.');
        }

        $payload = [];
        if ($isPackage) {
            $package = Package::find($input['package_id']);
            if (! $package?->is_active) {
                throw new ApiException(422, 'PACKAGE_INACTIVE', 'Paket ini sudah tidak dijual.');
            }
            $gross = $package->price;
        } else {
            $gross = $input['topup_amount'];
            // Tambahan masa aktif dibekukan saat transaksi dibuat; perubahan setting berlaku untuk transaksi berikutnya.
            $payload['extend_days'] = collect($this->settings->get('topup.options'))->firstWhere('amount', $gross)['extend_days'];
        }

        $points = $input['points_used'];
        $discount = $points * $this->settings->int('points.rupiah_per_point');
        if ($points > 0) {
            $this->validatePoints($user, $gross, $points);
        }
        $net = $gross - $discount;
        $isPulsa = $input['payment_method'] === 'pulsa';

        if ($isPulsa && $subscriber->pulsa_balance < $net) {
            $shortfall = $net - $subscriber->pulsa_balance;
            throw new ApiException(422, 'INSUFFICIENT_BALANCE',
                'Pulsa tidak cukup. Kurang '.self::rupiah($shortfall).'.', ['shortfall' => $shortfall]);
        }

        $transaction = Transaction::create([
            'user_id' => $user->id,
            'type' => $input['type'],
            'package_id' => $input['package_id'],
            'topup_amount' => $input['topup_amount'],
            'gross_amount' => $gross,
            'discount_amount' => $discount,
            'points_used' => $points,
            'net_amount' => $net,
            'payment_method' => $input['payment_method'],
            'status' => 'pending',
            'idempotency_key' => $key,
            'request_hash' => $hash,
            'recommendation_id' => $input['recommendation_id'],
            'external_ref' => 'KP-'.now()->format('Ymd').'-'.Str::upper(Str::random(6)),
            'payment_payload' => $payload + $this->paymentInstructions($input['payment_method']),
            'expires_at' => $isPulsa ? null : now()->addMinutes(self::PENDING_MINUTES),
        ]);

        if ($points > 0) {
            $this->points->hold($user, $points, $transaction);
        }

        if ($isPulsa) {
            // FR-5.9: saldo dicek dan dipotong dalam transaksi DB yang sama dengan baris subscriber terkunci.
            $subscriber->decrement('pulsa_balance', $net);
            $transaction->update(['status' => 'paid', 'paid_at' => now()]);
            $this->payments->provision($transaction);
        }

        return $transaction;
    }

    /**
     * FR-12.2, FR-12.4: kelipatan redeem_step, ≤ poin yang bisa dipakai, diskon ≤ batas persen harga paket,
     * dan total bayar ≥ minimal. meta.max_points = nilai terbesar yang sah, untuk dikoreksi client.
     */
    private function validatePoints(User $user, int $price, int $points): void
    {
        $rate = $this->settings->int('points.rupiah_per_point');
        $step = $this->settings->int('points.redeem_step');
        $limit = min(
            $this->points->available($user),
            intdiv(intdiv($price * $this->settings->int('points.max_discount_percent'), 100), $rate),
            intdiv(max(0, $price - $this->settings->int('points.min_net_amount')), $rate),
        );
        $max = intdiv($limit, $step) * $step;

        if ($points % $step !== 0 || $points > $max) {
            throw new ApiException(422, 'POINTS_INVALID',
                $max === 0 ? 'Poin belum bisa dipakai untuk paket ini.' : "Poin yang bisa dipakai maksimal {$max}, kelipatan {$step}.",
                ['max_points' => $max]);
        }
    }

    /** Instruksi bayar dummy (FR-5.3). String QRIS dan URL simulator dibentuk TransactionResource. */
    private function paymentInstructions(string $method): array
    {
        return $method === 'va'
            ? ['bank_label' => 'Bank A', 'va_number' => '8808'.str_pad((string) random_int(0, 999_999_999_999), 12, '0', STR_PAD_LEFT)]
            : [];
    }

    public static function rupiah(int $amount): string
    {
        return Format::rupiah($amount);
    }
}
