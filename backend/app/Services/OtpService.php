<?php

namespace App\Services;

use App\Exceptions\ApiException;
use App\Models\OtpCode;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Log;

/**
 * OTP dummy (FR-1.2–1.3): tidak dikirim lewat SMS, hanya ditulis ke log.
 * Dipakai untuk login dan konfirmasi berbagi kuota (purpose).
 */
class OtpService
{
    public const TTL_MINUTES = 5;

    public const RESEND_SECONDS = 60;

    public const MAX_ATTEMPTS = 5;

    public const LOCK_MINUTES = 15;

    /**
     * @return array{code: string, expires_at: Carbon, resend_available_at: Carbon}
     */
    public function send(string $msisdn, string $purpose, ?array $context = null): array
    {
        return DB::transaction(function () use ($msisdn, $purpose, $context) {
            $otp = OtpCode::where(['msisdn' => $msisdn, 'purpose' => $purpose])->lockForUpdate()->first()
                ?? new OtpCode(['msisdn' => $msisdn, 'purpose' => $purpose]);

            $this->ensureNotLocked($otp);

            if ($otp->exists && $otp->sent_at->gt(now()->subSeconds(self::RESEND_SECONDS))) {
                $retryAfter = (int) ceil(now()->diffInSeconds($otp->sent_at->copy()->addSeconds(self::RESEND_SECONDS)));
                throw new ApiException(429, 'OTP_RESEND_TOO_SOON', "Tunggu {$retryAfter} detik sebelum kirim ulang kode.",
                    ['retry_after' => $retryAfter]);
            }

            $code = str_pad((string) random_int(0, 999999), 6, '0', STR_PAD_LEFT);

            if ($otp->locked_until !== null) {
                // Kunci sudah lewat: mulai hitungan baru.
                $otp->attempts = 0;
                $otp->locked_until = null;
            }

            $otp->fill([
                'code_hash' => Hash::make($code),
                'context' => $context,
                'sent_at' => now(),
                'expires_at' => now()->addMinutes(self::TTL_MINUTES),
            ])->save();

            Log::info("OTP {$purpose} untuk {$msisdn}: {$code}");

            return [
                'code' => $code,
                'expires_at' => $otp->expires_at,
                'resend_available_at' => $otp->sent_at->copy()->addSeconds(self::RESEND_SECONDS),
            ];
        });
    }

    /**
     * Berhasil: OTP langsung dihanguskan. Gagal: melempar ApiException.
     * $context harus sama dengan saat dikirim (OTP berbagi kuota terikat ke penerima + jumlah).
     */
    public function verify(string $msisdn, string $purpose, string $code, ?array $context = null): void
    {
        // Hitungan salah harus tersimpan walau verifikasi gagal, jadi exception dilempar setelah transaksi selesai.
        $error = DB::transaction(function () use ($msisdn, $purpose, $code, $context) {
            $otp = OtpCode::where(['msisdn' => $msisdn, 'purpose' => $purpose])->lockForUpdate()->first();

            if ($otp !== null) {
                $this->ensureNotLocked($otp);
            }

            if ($otp === null || $otp->code_hash === null) {
                return new ApiException(422, 'OTP_EXPIRED', 'Kode sudah tidak berlaku. Kirim ulang kode.');
            }

            if ($otp->expires_at->isPast()) {
                return new ApiException(422, 'OTP_EXPIRED', 'Kode sudah kedaluwarsa. Kirim ulang kode.');
            }

            if (! Hash::check($code, $otp->code_hash) || ! $this->sameContext($otp->context, $context)) {
                $otp->attempts++;

                if ($otp->attempts >= self::MAX_ATTEMPTS) {
                    $otp->update(['locked_until' => now()->addMinutes(self::LOCK_MINUTES), 'code_hash' => null]);

                    return $this->lockedError($otp);
                }

                $otp->save();
                $left = self::MAX_ATTEMPTS - $otp->attempts;

                return new ApiException(422, 'OTP_INVALID', "Kode salah. Sisa {$left} percobaan.", ['attempts_left' => $left]);
            }

            $otp->update(['code_hash' => null, 'attempts' => 0]);

            return null;
        });

        if ($error) {
            throw $error;
        }
    }

    /** Kolom JSON MySQL menyusun ulang key, jadi urutan key tidak boleh ikut dibandingkan. */
    private function sameContext(?array $stored, ?array $given): bool
    {
        if ($stored === null || $given === null) {
            return $stored === $given;
        }
        ksort($stored);
        ksort($given);

        return $stored === $given;
    }

    private function ensureNotLocked(OtpCode $otp): void
    {
        if ($otp->locked_until?->isFuture()) {
            throw $this->lockedError($otp);
        }
    }

    private function lockedError(OtpCode $otp): ApiException
    {
        return new ApiException(423, 'OTP_LOCKED',
            'Terlalu banyak kode salah. Coba lagi pukul '.$otp->locked_until->format('H.i').'.',
            ['locked_until' => $otp->locked_until->toIso8601String()]);
    }
}
