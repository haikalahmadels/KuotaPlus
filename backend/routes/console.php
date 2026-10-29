<?php

use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\User;
use App\Services\ForecastService;
use App\Services\PaymentService;
use App\Services\PointService;
use App\Services\RewardService;
use App\Services\SettingService;
use Illuminate\Support\Carbon;
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

Artisan::command('forecasts:daily', function (ForecastService $forecasts) {
    $users = User::whereHas('subscriber.subscriptions', fn ($q) => $q->current())->get();
    $users->each(fn (User $user) => $forecasts->recompute($user));

    $this->info("{$users->count()} prediksi dihitung ulang.");
})->purpose('Jatah harian dan prediksi dihitung ulang 00:00 (FR-9.5); juga snapshot jatah untuk evaluasi reward');

Artisan::command('rewards:evaluate {date? : Tanggal yang dievaluasi, default kemarin}', function (RewardService $rewards) {
    $date = $this->argument('date') ? Carbon::parse($this->argument('date')) : today()->subDay();
    // Hanya pengguna yang punya prediksi hari itu = punya paket aktif (RewardService).
    $users = User::whereHas('forecasts', fn ($q) => $q->whereBetween('computed_at', [$date->copy()->startOfDay(), $date->copy()->endOfDay()]))->get();
    $evaluated = $users->filter(fn (User $user) => $rewards->evaluate($user, $date))->count();

    $this->info("{$evaluated} pengguna dievaluasi untuk {$date->toDateString()}.");
})->purpose('Evaluasi hari hemat dan poin untuk hari kemarin (FR-11.1)');

Artisan::command('points:expire', function (PointService $points) {
    $total = 0;
    User::whereHas('pointLedger')->each(function (User $user) use ($points, &$total) {
        $total += DB::transaction(function () use ($user, $points) {
            User::whereKey($user->id)->lockForUpdate()->first();

            return $points->expire($user);
        });
    });

    $this->info("{$total} poin kedaluwarsa.");
})->purpose('Poin lewat masa berlaku dicatat sebagai delta negatif, FIFO, tanpa menyentuh hold (FR-11.6)');

Schedule::command('transactions:expire')->everyMinute();
Schedule::command('subscriptions:expire')->everyMinute();
Schedule::command('forecasts:daily')->dailyAt('00:00');
Schedule::command('subscribers:status')->dailyAt('00:01');
Schedule::command('rewards:evaluate')->dailyAt('00:05');
Schedule::command('points:expire')->dailyAt('00:10');
