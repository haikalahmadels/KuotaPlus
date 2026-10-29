<?php

namespace App\Services;

use App\Models\Subscription;
use Carbon\CarbonInterface;

/**
 * Pemotongan kuota (FR-7.7). Dipanggil di dalam transaksi DB yang sudah mengunci baris users pemilik.
 */
class QuotaService
{
    /**
     * Memotong $bytes pemakaian aplikasi berkategori $category pada tanggal $date:
     * (a) kuota aplikasi yang kategorinya sama, lalu (b) kuota utama dari paket yang paling cepat berakhir.
     * Hanya paket yang aktif pada tanggal itu yang dipotong, supaya riwayat 7 hari pada sync pertama
     * tidak membebani paket yang baru dibeli.
     *
     * @return int byte yang benar-benar terpotong (bisa < $bytes jika kuota habis; OQ-11: pulsa tidak dipotong)
     */
    public function consume(int $subscriberId, string $category, int $bytes, CarbonInterface $date): int
    {
        if ($bytes <= 0) {
            return 0;
        }

        $subscriptions = Subscription::where('subscriber_id', $subscriberId)
            ->where('status', 'active')
            ->where('started_at', '<', $date->copy()->endOfDay())
            ->where('expires_at', '>', $date->copy()->startOfDay())
            ->orderBy('expires_at')
            ->lockForUpdate()
            ->get();

        $left = $bytes;

        foreach ($subscriptions as $s) {
            if ($s->app_category !== null && $s->app_category === $category) {
                $take = min($left, $s->app_total - $s->app_used);
                $s->app_used += $take;
                $left -= $take;
            }
        }
        foreach ($subscriptions as $s) {
            $take = min($left, $s->main_total - $s->main_used);
            $s->main_used += $take;
            $left -= $take;
        }

        foreach ($subscriptions as $s) {
            if ($s->main_used >= $s->main_total && $s->app_used >= $s->app_total) {
                $s->status = 'exhausted';
            }
            if ($s->isDirty()) {
                $s->save();
            }
        }

        return $bytes - $left;
    }
}
