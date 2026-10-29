<?php

namespace App\Services;

use App\Models\PointLedger;
use App\Models\Transaction;
use App\Models\User;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Carbon;
use LogicException;

/**
 * Satu-satunya penulis point_ledger (FR-11.5). Saldo = SUM(delta). Kolom `remaining` di baris yang menambah poin
 * dipakai untuk FIFO: hold dan spend mengambil dari poin paling cepat kedaluwarsa, dan kedaluwarsa hanya memotong
 * `remaining` yang belum dipakai/di-hold (edge case Poin).
 *
 * Semua method dipanggil di dalam transaksi DB yang sudah mengunci baris users pemilik poin.
 */
class PointService
{
    /** Baris yang menambah poin dan ikut FIFO. */
    private const CREDIT_TYPES = ['earn_daily', 'earn_streak', 'redeem_release'];

    public function __construct(private SettingService $settings) {}

    public function balance(User $user): int
    {
        return (int) PointLedger::where('user_id', $user->id)->sum('delta');
    }

    /** Poin yang bisa dipakai sekarang: sama dengan saldo, kecuali ada poin lewat masa berlaku yang belum diproses job. */
    public function available(User $user): int
    {
        return (int) PointLedger::where('user_id', $user->id)
            ->whereIn('type', self::CREDIT_TYPES)
            ->where('expires_at', '>', now())
            ->sum('remaining');
    }

    /** Poin yang sedang ditahan transaksi pending (FR-12.3). */
    public function held(User $user): int
    {
        return (int) -PointLedger::where('user_id', $user->id)
            ->where('type', 'redeem_hold')
            ->whereIn('ref_id', Transaction::where('user_id', $user->id)->where('status', 'pending')->select('id'))
            ->sum('delta');
    }

    public function earn(User $user, int $points, string $type, Model $ref): PointLedger
    {
        return PointLedger::create([
            'user_id' => $user->id,
            'delta' => $points,
            'type' => $type,
            'ref_type' => $ref->getTable(),
            'ref_id' => $ref->getKey(),
            'remaining' => $points,
            'expires_at' => now()->addDays($this->settings->int('points.validity_days')),
        ]);
    }

    /** FR-12.3: poin ditahan saat transaksi dibuat; menjadi final jika PAID tanpa baris tambahan. */
    public function hold(User $user, int $points, Transaction $transaction): void
    {
        $earliestExpiry = $this->consume($user, $points);

        PointLedger::create([
            'user_id' => $user->id,
            'delta' => -$points,
            'type' => 'redeem_hold',
            'ref_type' => 'transactions',
            'ref_id' => $transaction->id,
            // Disimpan supaya poin yang dikembalikan tidak mendapat masa berlaku baru.
            'expires_at' => $earliestExpiry,
        ]);
    }

    /** FAILED/EXPIRED: poin dikembalikan persis sejumlah hold, sekali saja. */
    public function release(Transaction $transaction): void
    {
        $hold = PointLedger::where(['type' => 'redeem_hold', 'ref_type' => 'transactions', 'ref_id' => $transaction->id])->first();
        $released = PointLedger::where(['type' => 'redeem_release', 'ref_type' => 'transactions', 'ref_id' => $transaction->id])->exists();
        if (! $hold || $released) {
            return;
        }

        PointLedger::create([
            'user_id' => $hold->user_id,
            'delta' => -$hold->delta,
            'type' => 'redeem_release',
            'ref_type' => 'transactions',
            'ref_id' => $transaction->id,
            'remaining' => -$hold->delta,
            'expires_at' => $hold->expires_at,
        ]);
    }

    /** Biaya berbagi kuota (FR-14.6), final. */
    public function spend(User $user, int $points, Model $ref): void
    {
        $this->consume($user, $points);

        PointLedger::create([
            'user_id' => $user->id,
            'delta' => -$points,
            'type' => 'spend_share',
            'ref_type' => $ref->getTable(),
            'ref_id' => $ref->getKey(),
        ]);
    }

    /** FR-11.6: poin yang lewat masa berlaku dicatat sebagai delta negatif. Mengembalikan jumlah poin yang hangus. */
    public function expire(User $user): int
    {
        $rows = PointLedger::where('user_id', $user->id)
            ->whereIn('type', self::CREDIT_TYPES)
            ->where('remaining', '>', 0)
            ->where('expires_at', '<=', now())
            ->lockForUpdate()
            ->get();

        $points = (int) $rows->sum('remaining');
        if ($points === 0) {
            return 0;
        }

        $rows->each->update(['remaining' => 0]);
        PointLedger::create(['user_id' => $user->id, 'delta' => -$points, 'type' => 'expire']);

        return $points;
    }

    /**
     * Mengambil $points dari baris kredit yang paling cepat kedaluwarsa.
     *
     * @return Carbon|null masa berlaku paling awal di antara poin yang diambil
     */
    private function consume(User $user, int $points): ?Carbon
    {
        $rows = PointLedger::where('user_id', $user->id)
            ->whereIn('type', self::CREDIT_TYPES)
            ->where('remaining', '>', 0)
            ->where('expires_at', '>', now())
            ->orderBy('expires_at')
            ->orderBy('id')
            ->lockForUpdate()
            ->get();

        if ($rows->sum('remaining') < $points) {
            // Pemanggil wajib memvalidasi saldo lebih dulu; ini penjaga integritas ledger.
            throw new LogicException('Poin tidak cukup untuk dipakai.');
        }

        $left = $points;
        $earliest = null;
        foreach ($rows as $row) {
            if ($left === 0) {
                break;
            }
            $take = min($left, $row->remaining);
            $row->update(['remaining' => $row->remaining - $take]);
            $earliest ??= $row->expires_at;
            $left -= $take;
        }

        return $earliest;
    }
}
