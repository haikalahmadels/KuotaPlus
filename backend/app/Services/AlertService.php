<?php

namespace App\Services;

use App\Models\Notification;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use App\Support\Format;
use Illuminate\Support\Carbon;

/**
 * Peringatan FR-13. Dipanggil di akhir GET /home dan POST /usage/sync (tanpa job sendiri).
 * Batas 1 per jenis per hari dijaga unique index (user_id, kind, notified_on) di tabel notifications;
 * delivered_at mencegah alert yang sama dikirim dua kali ke client.
 */
class AlertService
{
    /** FR-13.1(a): sisa kuota utama ≤ 20%. */
    public const QUOTA_LOW_RATIO = 0.2;

    /** FR-13.1(d): masa aktif kartu ≤ 3 hari. */
    public const CARD_EXPIRING_DAYS = 3;

    public function __construct(private ForecastService $forecasts) {}

    /**
     * Evaluasi pemicu, lalu kembalikan alert hari ini yang belum pernah dikirim dan tandai terkirim.
     *
     * @return list<array<string, mixed>> objek Alert (docs/API-KuotaPlus.md)
     */
    public function collect(User $user): array
    {
        $this->evaluate($user);

        $pending = $user->notifications()
            ->whereDate('notified_on', today())
            ->whereNull('delivered_at')
            ->orderBy('id')
            ->get();

        $alerts = [];
        foreach ($pending as $notification) {
            // Klaim per baris: dua request bersamaan tidak mengirim alert yang sama dua kali.
            $claimed = Notification::whereKey($notification->id)->whereNull('delivered_at')->update(['delivered_at' => now()]);
            if ($claimed) {
                $alerts[] = [
                    'id' => $notification->id,
                    'kind' => $notification->kind,
                    ...$notification->payload,
                    'created_at' => $notification->created_at->toIso8601String(),
                ];
            }
        }

        return $alerts;
    }

    public function evaluate(User $user): void
    {
        $subscriber = $user->subscriber;
        $subscriptions = $subscriber->subscriptions()->current()->with('package')->get();

        // (a) Sisa kuota utama semua paket ≤ 20%.
        $mainTotal = $subscriptions->sum('main_total');
        $mainLeft = $subscriptions->sum(fn (Subscription $s) => max(0, $s->main_total - $s->main_used));
        if ($mainTotal > 0 && $mainLeft / $mainTotal <= self::QUOTA_LOW_RATIO) {
            $this->record($user, 'quota_low', [
                'title' => 'Kuota utama tinggal sedikit',
                'body' => 'Sisa kuota utamamu '.Format::bytes($mainLeft).' ('.round($mainLeft / $mainTotal * 100).'%). Lihat paket yang pas sebelum habis.',
                'target' => '/recommendations',
            ]);
        }

        // (b) Prediksi berubah menjadi Berisiko: sekali per episode berisiko, bukan setiap hari selama berisiko.
        if ($subscriptions->isNotEmpty()) {
            $forecast = $this->forecasts->latest($user);
            if ($forecast?->status === 'risk' && ! $this->riskAlreadyNotified($user)) {
                $this->record($user, 'forecast_risk', [
                    'title' => 'Kuota diprediksi habis lebih cepat',
                    // Selisih hari dihitung sama dengan days_early di ForecastResource.
                    'body' => 'Kuotamu diperkirakan habis '.$this->day($forecast->predicted_empty_at).', '
                        .(int) ceil($forecast->predicted_empty_at->diffInSeconds($forecast->main_expires_at) / 86400)
                        .' hari sebelum paket berakhir.',
                    'target' => '/usage',
                ]);
            }
        }

        // (c) Paket berakhir ≤ 1 hari lagi (yang paling cepat).
        $expiring = $subscriptions->first(fn (Subscription $s) => $s->expires_at->lte(now()->addDay()));
        if ($expiring) {
            $name = $expiring->package?->name ?? 'Kuota kiriman';
            $this->record($user, 'package_expiring', [
                'title' => 'Paket segera berakhir',
                'body' => $name.' berakhir '.$this->day($expiring->expires_at).' pukul '.$expiring->expires_at->format('H.i').'. Sisa kuotanya ikut berakhir.',
                'target' => '/packages',
            ]);
        }

        // (d) Masa aktif kartu ≤ 3 hari (nomor yang sudah masa tenggang tampil di beranda, bukan alert ini).
        if ($subscriber->status === 'active' && $subscriber->active_until->lte(today()->addDays(self::CARD_EXPIRING_DAYS))) {
            $this->record($user, 'card_expiring', [
                'title' => 'Masa aktif nomor segera habis',
                'body' => 'Nomormu aktif sampai '.$this->day($subscriber->active_until).'. Isi ulang agar tidak masuk masa tenggang.',
                'target' => '/topup',
            ]);
        }

        // (e) Transaksi berubah status hari ini. Metode pulsa langsung selesai saat dibuat, jadi tidak "berubah".
        $transaction = $user->transactions()
            ->whereIn('status', ['paid', 'failed', 'expired'])
            ->where('payment_method', '!=', 'pulsa')
            ->where('updated_at', '>=', today())
            ->with('package')
            ->latest('updated_at')
            ->first();
        if ($transaction) {
            $this->record($user, 'transaction_status', $this->transactionPayload($transaction));
        }
    }

    /** Sudah ada alert forecast_risk sejak prediksi terakhir yang tidak berisiko? */
    private function riskAlreadyNotified(User $user): bool
    {
        $lastNotRisk = $user->forecasts()
            ->where(fn ($q) => $q->whereNull('status')->orWhere('status', '!=', 'risk'))
            ->max('computed_at');

        return $user->notifications()
            ->where('kind', 'forecast_risk')
            ->when($lastNotRisk, fn ($q) => $q->where('created_at', '>', $lastNotRisk))
            ->exists();
    }

    /** @return array{title: string, body: string, target: string} */
    private function transactionPayload(Transaction $transaction): array
    {
        $item = $transaction->type === 'package'
            ? $transaction->package->name
            : 'Isi ulang '.Format::rupiah($transaction->topup_amount);

        [$title, $body] = match ($transaction->status) {
            'paid' => ['Pembayaran berhasil', $transaction->type === 'package'
                ? $item.' sudah aktif dan bisa langsung dipakai.'
                : $item.' berhasil. Pulsa dan masa aktif sudah bertambah.'],
            'failed' => ['Pembayaran gagal', 'Pembayaran '.$item.' ditolak. Tidak ada saldo yang terpotong.'],
            default => ['Waktu pembayaran habis', 'Pembayaran '.$item.' tidak diselesaikan. Buat transaksi baru jika masih perlu.'],
        };

        return ['title' => $title, 'body' => $body, 'target' => '/history/'.$transaction->id];
    }

    /** Catat alert jika jenis ini belum ada hari ini (unique index menangani request bersamaan). */
    private function record(User $user, string $kind, array $payload): void
    {
        Notification::createOrFirst(
            ['user_id' => $user->id, 'kind' => $kind, 'notified_on' => today()->toDateString()],
            ['payload' => $payload],
        );
    }

    private function day(Carbon $time): string
    {
        return $time->locale('id')->translatedFormat('j M');
    }
}
