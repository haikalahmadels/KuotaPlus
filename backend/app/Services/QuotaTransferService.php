<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\QuotaTransfer;
use App\Models\QuotaTransferSource;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\User;
use App\Support\Format;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * Berbagi kuota (FR-14). Hanya kuota utama dari paket milik sendiri (bukan kiriman orang lain) yang bisa dibagikan.
 * Eksekusi mengunci baris users pengirim (docs/TECH-KuotaPlus.md, Konkurensi) lalu memeriksa ulang semua aturan,
 * jadi sync atau transfer paralel tidak bisa melanggar batas.
 */
class QuotaTransferService
{
    public function __construct(
        private SettingService $settings,
        private PointService $points,
        private OtpService $otp,
        private ForecastService $forecasts,
        private AlertService $alerts,
    ) {}

    /** FR-14.2: penerima terdaftar, aktif, dan bukan diri sendiri. Ditolak sebelum layar konfirmasi. */
    public function recipient(User $sender, string $input): Subscriber
    {
        $msisdn = Subscriber::normalizeMsisdn($input);
        $recipient = $msisdn ? Subscriber::where('msisdn', $msisdn)->first() : null;

        if ($recipient === null) {
            throw new ApiException(422, 'RECIPIENT_NOT_SUBSCRIBER', 'Nomor ini bukan pelanggan Nusantel.');
        }
        if ($recipient->id === $sender->subscriber_id) {
            throw new ApiException(422, 'RECIPIENT_IS_SELF', 'Kamu tidak bisa berbagi kuota ke nomor sendiri.');
        }
        if ($recipient->status !== 'active') {
            throw new ApiException(422, 'RECIPIENT_INACTIVE', 'Nomor penerima sedang tidak aktif.');
        }

        return $recipient;
    }

    /** GET /quota-transfers/quote: semua pilihan jumlah sekaligus, termasuk yang dinonaktifkan beserta alasannya. */
    public function quote(User $sender, Subscriber $recipient): array
    {
        $sources = $this->sources($sender);
        $remaining = $this->remaining($sources);
        $allowance = $this->allowance($sender);
        $balance = $this->points->available($sender);
        $step = $this->settings->int('share.step_bytes');

        $options = [];
        for ($bytes = $step; $bytes <= $allowance['limit_bytes']; $bytes += $step) {
            $reason = $this->reason($bytes, $allowance, $remaining, $balance);
            $options[] = [
                'bytes' => $bytes,
                'points_cost' => $this->cost($bytes),
                'allowed' => $reason === null,
                'reason' => $reason,
                'recipient_expires_at' => $reason === null ? $this->recipientExpiry($sources, $bytes)->toIso8601String() : null,
                'sender_main_remaining_after' => $reason === null ? $remaining - $bytes : null,
            ];
        }

        return [
            'recipient' => [
                'msisdn_masked' => Subscriber::maskMsisdn($recipient->msisdn),
                'has_account' => $recipient->user()->exists(),
            ],
            'allowance' => $allowance,
            'sender_main_remaining_bytes' => $remaining,
            'points_balance' => $balance,
            'options' => $options,
        ];
    }

    /** POST /quota-transfers/otp: periksa ulang aturan, lalu OTP ke nomor pengirim yang terikat ke penerima + jumlah. */
    public function requestOtp(User $sender, string $recipientInput, int $bytes): array
    {
        $recipient = $this->recipient($sender, $recipientInput);
        $this->ensureAllowed($sender, $bytes);

        return $this->otp->send($sender->subscriber->msisdn, 'quota_transfer', $this->otpContext($recipient, $bytes));
    }

    /**
     * POST /quota-transfers (FR-14.10–14.12).
     *
     * @return array{0: QuotaTransfer, 1: bool} transfer dan apakah baru dibuat (false = replay Idempotency-Key)
     */
    public function execute(User $sender, string $recipientInput, int $bytes, string $otpCode, string $idempotencyKey): array
    {
        $recipient = $this->recipient($sender, $recipientInput);
        $hash = hash('sha256', json_encode(['recipient' => $recipient->msisdn, 'bytes' => $bytes]));

        // Replay dicek sebelum OTP: OTP sudah hangus saat permintaan pertama berhasil.
        if ($existing = $this->replay($sender, $idempotencyKey, $hash)) {
            return [$existing, false];
        }

        $this->otp->verify($sender->subscriber->msisdn, 'quota_transfer', $otpCode, $this->otpContext($recipient, $bytes));

        $transfer = DB::transaction(function () use ($sender, $recipient, $bytes, $idempotencyKey, $hash) {
            User::whereKey($sender->id)->lockForUpdate()->first();

            return $this->replay($sender, $idempotencyKey, $hash)
                ?? $this->transferLocked($sender, $recipient, $bytes, $idempotencyKey, $hash);
        });

        if (! $transfer->wasRecentlyCreated) {
            return [$transfer, false];
        }

        $this->afterTransfer($sender, $recipient, $transfer);

        return [$transfer, true];
    }

    /**
     * Inti transfer tanpa OTP, untuk pemanggil tepercaya (DemoAccountSeeder). Pemanggil API selalu lewat execute().
     */
    public function transfer(User $sender, Subscriber $recipient, int $bytes, string $idempotencyKey): QuotaTransfer
    {
        $hash = hash('sha256', json_encode(['recipient' => $recipient->msisdn, 'bytes' => $bytes]));
        $transfer = DB::transaction(function () use ($sender, $recipient, $bytes, $idempotencyKey, $hash) {
            User::whereKey($sender->id)->lockForUpdate()->first();

            return $this->transferLocked($sender, $recipient, $bytes, $idempotencyKey, $hash);
        });
        $this->afterTransfer($sender, $recipient, $transfer);

        return $transfer;
    }

    /** Sisa kuota utama pengirim yang bisa dibagikan saat ini (FR-14.5). */
    public function senderRemaining(User $sender): int
    {
        return $this->remaining($this->sources($sender));
    }

    private function remaining(Collection $sources): int
    {
        return (int) $sources->sum(fn (Subscription $s) => max(0, $s->main_total - $s->main_used));
    }

    /** Dijalankan dengan baris users pengirim terkunci. */
    private function transferLocked(User $sender, Subscriber $recipient, int $bytes, string $key, string $hash): QuotaTransfer
    {
        $sources = $this->sources($sender, lock: true);
        $this->ensureAllowed($sender, $bytes, $sources);

        $expiresAt = $this->recipientExpiry($sources, $bytes);
        $received = Subscription::create([
            'subscriber_id' => $recipient->id,
            'source' => 'shared',
            'main_total' => $bytes,
            'app_total' => 0,
            'started_at' => now(),
            'expires_at' => $expiresAt,
        ]);

        $transfer = QuotaTransfer::create([
            'sender_user_id' => $sender->id,
            'recipient_subscriber_id' => $recipient->id,
            'bytes' => $bytes,
            'points_spent' => $this->cost($bytes),
            'recipient_subscription_id' => $received->id,
            'expires_at' => $expiresAt,
            'idempotency_key' => $key,
            'request_hash' => $hash,
            'status' => 'completed',
            'completed_at' => now(),
        ]);

        // FR-14.7: potong dari paket yang paling cepat berakhir lebih dulu, boleh lebih dari satu paket.
        $left = $bytes;
        foreach ($sources as $s) {
            if ($left === 0) {
                break;
            }
            $take = min($left, $s->main_total - $s->main_used);
            if ($take <= 0) {
                continue;
            }
            $s->main_used += $take;
            if ($s->main_used >= $s->main_total && $s->app_used >= $s->app_total) {
                $s->status = 'exhausted';
            }
            $s->save();
            QuotaTransferSource::create(['quota_transfer_id' => $transfer->id, 'subscription_id' => $s->id, 'bytes' => $take]);
            $left -= $take;
        }

        $this->points->spend($sender, $transfer->points_spent, $transfer);

        return $transfer;
    }

    /** FR-14.13–14: alert/SMS untuk penerima, lalu prediksi kedua pihak dihitung ulang. */
    private function afterTransfer(User $sender, Subscriber $recipient, QuotaTransfer $transfer): void
    {
        $from = Subscriber::maskMsisdn($sender->subscriber->msisdn);
        $until = $transfer->expires_at->locale('id')->translatedFormat('j M Y');
        $message = 'Kamu menerima '.Format::gb($transfer->bytes)." dari {$from}, berlaku sampai {$until}.";

        $recipientUser = $recipient->user;
        if ($recipientUser) {
            $this->alerts->notify($recipientUser, 'quota_received', [
                'title' => 'Kamu menerima kuota',
                'body' => $message,
                'target' => '/home',
            ]);
            $this->forecasts->recompute($recipientUser);
        } else {
            Log::info("SMS dummy ke {$recipient->msisdn}: {$message}");
        }

        $this->forecasts->recompute($sender);
    }

    private function ensureAllowed(User $sender, int $bytes, ?Collection $sources = null): void
    {
        $step = $this->settings->int('share.step_bytes');
        $allowance = $this->allowance($sender);
        if ($bytes <= 0 || $bytes % $step !== 0 || $bytes > $allowance['limit_bytes']) {
            throw new ApiException(422, 'SHARE_NOT_ALLOWED', 'Jumlah tidak tersedia.', ['reason' => 'Jumlah tidak tersedia.']);
        }

        $reason = $this->reason($bytes, $allowance, $this->remaining($sources ?? $this->sources($sender)), $this->points->available($sender));
        if ($reason !== null) {
            throw new ApiException(422, 'SHARE_NOT_ALLOWED', $reason, ['reason' => $reason]);
        }
    }

    /** Alasan opsi ditolak (FR-14.4–14.6), null jika boleh. */
    private function reason(int $bytes, array $allowance, int $remaining, int $balance): ?string
    {
        $min = $this->settings->int('share.min_remaining_bytes');

        return match (true) {
            $bytes > $allowance['remaining_bytes'] => 'Melebihi sisa jatah berbagi '.Format::gb($allowance['remaining_bytes']).'.',
            $remaining - $bytes < $min => 'Sisa kuota utamamu setelah berbagi harus minimal '.Format::gb($min).'.',
            $balance < $this->cost($bytes) => 'Poin tidak cukup, butuh '.$this->cost($bytes).' poin.',
            default => null,
        };
    }

    /** FR-14.4: jatah 30 hari bergulir dari transfer completed. */
    private function allowance(User $sender): array
    {
        $limit = $this->settings->int('share.limit_bytes_30d');
        $window = QuotaTransfer::where('sender_user_id', $sender->id)
            ->where('status', 'completed')
            ->where('completed_at', '>', now()->subDays(30));
        $used = (int) $window->clone()->sum('bytes');
        $oldest = $window->clone()->min('completed_at');

        return [
            'limit_bytes' => $limit,
            'used_30d_bytes' => $used,
            'remaining_bytes' => max(0, $limit - $used),
            'recovers_at' => $oldest ? Carbon::parse($oldest)->addDays(30)->toDateString() : null,
        ];
    }

    /** FR-14.6: poin per langkah (100 poin per 500 MB). */
    private function cost(int $bytes): int
    {
        return intdiv($bytes, $this->settings->int('share.step_bytes')) * $this->settings->int('share.points_per_step');
    }

    /** Paket milik sendiri yang aktif, paling cepat berakhir lebih dulu (FR-14.1, 14.7). */
    private function sources(User $sender, bool $lock = false): Collection
    {
        return Subscription::where('subscriber_id', $sender->subscriber_id)
            ->current()
            ->where('status', 'active')
            ->where('source', '!=', 'shared')
            ->when($lock, fn ($q) => $q->lockForUpdate())
            ->get();
    }

    /** FR-14.8: yang lebih awal antara sekarang + 7 hari dan berakhirnya paket sumber terakhir yang dipotong. */
    private function recipientExpiry(Collection $sources, int $bytes): Carbon
    {
        $limit = now()->addDays($this->settings->int('share.validity_days'));
        $left = $bytes;
        $last = null;
        foreach ($sources as $s) {
            if ($left <= 0) {
                break;
            }
            $take = min($left, max(0, $s->main_total - $s->main_used));
            if ($take > 0) {
                $last = $s->expires_at;
                $left -= $take;
            }
        }

        return $last && $last->lt($limit) ? $last->copy() : $limit;
    }

    private function replay(User $sender, string $key, string $hash): ?QuotaTransfer
    {
        $existing = QuotaTransfer::where(['sender_user_id' => $sender->id, 'idempotency_key' => $key])->first();
        if ($existing && $existing->request_hash !== $hash) {
            throw new ApiException(422, 'IDEMPOTENCY_KEY_MISMATCH', 'Permintaan berbeda memakai Idempotency-Key yang sama.');
        }

        return $existing;
    }

    private function otpContext(Subscriber $recipient, int $bytes): array
    {
        return ['recipient' => $recipient->msisdn, 'bytes' => $bytes];
    }
}
