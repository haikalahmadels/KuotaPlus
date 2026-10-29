<?php

use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use App\Services\PaymentService;
use App\Services\SettingService;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schedule;

// Job terjadwal (docs/TECH-KuotaPlus.md). Jalankan `php artisan schedule:work` selama pengembangan dan demo.
// Setiap command aman dijalankan berulang: hanya baris yang masih memenuhi syarat yang diubah.

Artisan::command('transactions:expire', function (PaymentService $payments) {
    $ids = Transaction::where('status', 'pending')->where('expires_at', '<', now())->pluck('id');

    foreach ($ids as $id) {
        DB::transaction(function () use ($id, $payments) {
            $transaction = Transaction::whereKey($id)->lockForUpdate()->first();
            User::whereKey($transaction->user_id)->lockForUpdate()->first();

            // Dicek ulang: callback bisa saja sudah memproses transaksi ini.
            if ($transaction->status === 'pending' && $transaction->expires_at->isPast()) {
                $payments->expire($transaction);
            }
        });
    }

    $this->info("{$ids->count()} transaksi pending diperiksa.");
})->purpose('PENDING yang lewat expires_at menjadi EXPIRED (FR-5.8)');

Artisan::command('subscriptions:expire', function () {
    $count = Subscription::whereIn('status', ['active', 'exhausted'])
        ->where('expires_at', '<=', now())
        ->update(['status' => 'expired']);

    $this->info("{$count} paket berakhir.");
})->purpose('Paket yang lewat expires_at menjadi expired; sisa kuotanya hangus');

Artisan::command('subscribers:status', function (SettingService $settings) {
    $graceDays = $settings->int('card.grace_days');

    Subscriber::where('status', 'active')->where('active_until', '<', today())->each(
        fn (Subscriber $s) => $s->update(['status' => 'grace', 'grace_until' => $s->active_until->copy()->addDays($graceDays)])
    );

    Subscriber::where('status', 'grace')->where('grace_until', '<', today())->with('user')->each(function (Subscriber $s) {
        $s->update(['status' => 'terminated']);
        // Login ditolak setelah masa tenggang habis; sesi yang masih terbuka ikut ditutup.
        $s->user?->tokens()->delete();
    });
})->purpose('Kartu active → grace → terminated sesuai masa aktif dan masa tenggang');

Schedule::command('transactions:expire')->everyMinute();
Schedule::command('subscriptions:expire')->everyMinute();
Schedule::command('subscribers:status')->dailyAt('00:01');
