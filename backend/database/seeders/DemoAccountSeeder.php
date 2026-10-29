<?php

namespace Database\Seeders;

use App\Domain\UsageProfiles;
use App\Models\App;
use App\Models\DailyEvaluation;
use App\Models\Package;
use App\Models\PaymentCallback;
use App\Models\QuotaTransfer;
use App\Models\QuotaTransferSource;
use App\Models\Subscriber;
use App\Models\Subscription;
use App\Models\Transaction;
use App\Models\UsageRecord;
use App\Models\User;
use App\Services\ForecastService;
use App\Services\PointService;
use App\Services\QuotaService;
use App\Services\RewardService;
use Illuminate\Database\Seeder;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Str;

/**
 * Akun demo lengkap (docs/SEED-KuotaPlus.md bagian Pelanggan dan akun demo).
 *
 * Riwayat 30 hari diputar ulang hari demi hari dengan jam yang dimundurkan (Carbon::setTestNow) dan memakai
 * service aplikasi yang sama dengan produksi: prediksi 00:00, evaluasi reward 00:05, pembelian, pemakaian
 * yang memotong kuota, dan berbagi kuota. Hasilnya konsisten dengan aturan bisnis, bukan angka tulisan tangan.
 */
class DemoAccountSeeder extends Seeder
{
    private const MB = 1048576;

    private const GB = 1073741824;

    private const DAYS = 30;

    private Carbon $today;

    /** @var array<string, App> */
    private array $apps;

    /** @var list<array<string, int>> profil Acak untuk Dimas, D-5 s.d. D0 */
    private array $dimasDays;

    public function __construct(
        private ForecastService $forecasts,
        private QuotaService $quota,
        private RewardService $rewards,
        private PointService $points,
    ) {}

    public function run(): void
    {
        $this->today = today();
        $this->apps = App::all()->keyBy('package_name')->all();
        $this->dimasDays = UsageProfiles::days('random', $this->today->copy()->subDays(5), 6);

        $rina = $this->user('6288100000001', 'Rina');
        $budi = $this->user('6288100000002', 'Budi', android: true);
        $dimas = $this->user('6288100000003', 'Dimas');
        $this->user('6288100000005', 'Sari');
        $andi = Subscriber::where('msisdn', '6288100000007')->first();

        // Riwayat sebelum jendela 30 hari.
        $this->rinaHolidayPoints($rina);
        $this->purchase($rina, 'BL15', $this->at(-42, 7), 'va', mainUsed: $this->profileSum('rina', -42, 12));
        $this->purchase($budi, 'HR05', $this->at(-80, 7), 'pulsa', mainUsed: 300 * self::MB);
        $this->purchase($budi, 'BL50', $this->at(-50, 7), 'pulsa', mainUsed: $this->profileSum('budi', -50, 20));

        for ($offset = -self::DAYS; $offset <= 0; $offset++) {
            // 00:00 prediksi + snapshot jatah harian (forecasts:daily).
            $this->travel($offset, 0, 0, 30);
            foreach ([$rina, $budi, $dimas] as $user) {
                $this->forecasts->recompute($user);
            }

            // 00:05 evaluasi reward untuk hari kemarin (rewards:evaluate).
            if ($offset > -self::DAYS) {
                $this->travel($offset, 0, 5);
                foreach ([$rina, $budi, $dimas] as $user) {
                    $this->rewards->evaluate($user, $this->at($offset - 1, 0));
                }
            }

            $this->events($offset, $rina, $budi, $dimas, $andi);

            // Pemakaian hari itu. Hari ini memakai jam sungguhan supaya synced_at tidak di masa depan.
            $offset === 0 ? Carbon::setTestNow() : $this->travel($offset, 21);
            $this->use($rina, $offset, $this->rinaUsage($offset));
            $this->use($budi, $offset, $this->budiUsage($offset));
            $this->use($dimas, $offset, $offset >= -5 ? $this->scale($this->dimasDays[$offset + 5], $offset === 0 ? 0.35 : 1) : []);
        }

        Carbon::setTestNow();
        Artisan::call('subscriptions:expire');
        foreach ([$rina, $budi, $dimas] as $user) {
            $this->forecasts->recompute($user);
        }
    }

    /** Kejadian per hari (SEED: tabel transaksi dan berbagi kuota). */
    private function events(int $offset, User $rina, User $budi, User $dimas, Subscriber $andi): void
    {
        match ($offset) {
            -21, -19, -16, -14 => $this->purchase($rina, 'HR1', $this->at($offset, 7), 'pulsa'),
            -12 => $this->purchase($rina, 'BL15', $this->at($offset, 7), 'qris'),
            -10 => $this->shareQuota($budi, $andi, self::GB, 200, $this->at($offset, 12)),
            -6 => $this->purchase($dimas, 'MG10', $this->at($offset, 10), 'ewallet'),
            default => null,
        };

        if ($offset === -21) {
            $this->transaction($budi, ['type' => 'topup', 'topup_amount' => 100000], 'va', 'paid', $this->at(-21, 9), ['extend_days' => 60]);
        }
        if ($offset === -20) {
            $this->purchase($budi, 'BL50', $this->at($offset, 7), 'pulsa');
        }
        if ($offset === -5) {
            $this->transaction($rina, ['type' => 'package', 'package_id' => $this->package('VID30')->id], 'qris', 'expired', $this->at(-5, 19));
        }
        if ($offset === -3) {
            $this->transaction($rina, ['type' => 'topup', 'topup_amount' => 25000], 'ewallet', 'failed', $this->at(-3, 20), ['extend_days' => 30]);
        }
    }

    /** Rina: kuota habis D-22 s.d. D-13 (Wi-Fi kampus), kecuali 4 hari paket harian darurat 950 MB. */
    private function rinaUsage(int $offset): array
    {
        $pattern = $this->profile('rina', $offset);

        return match (true) {
            $offset >= -22 && $offset <= -13 => in_array($offset, [-21, -19, -16, -14], true)
                ? $this->scale($pattern, 950 / array_sum($pattern))
                : [],
            $offset === 0 => $this->scale($pattern, 0.35),
            default => $pattern,
        };
    }

    /** Budi: pola Budi + lonjakan update OS D-9 (di luar 7 hari terakhir). */
    private function budiUsage(int $offset): array
    {
        $usage = $this->scale($this->profile('budi', $offset), $offset === 0 ? 0.35 : 1);
        if ($offset === -9) {
            $usage['android.system'] += 3072;
        }

        return $usage;
    }

    /** Pemakaian dicatat sebagai data demo, tapi tetap memotong kuota supaya ceritanya konsisten. */
    private function use(User $user, int $offset, array $usageMb): void
    {
        $date = $this->at($offset, 0);
        foreach ($usageMb as $packageName => $mb) {
            $bytes = (int) round($mb * self::MB);
            if ($bytes <= 0) {
                continue;
            }
            $app = $this->apps[$packageName];
            UsageRecord::create([
                'user_id' => $user->id, 'app_id' => $app->id, 'usage_date' => $date->toDateString(),
                'bytes_mobile' => $bytes, 'bytes_applied' => $bytes, 'source' => 'demo', 'synced_at' => now(),
            ]);
            $this->quota->consume($user->subscriber_id, $app->category, $bytes, $date);
        }
    }

    private function purchase(User $user, string $code, Carbon $at, string $method, ?int $mainUsed = null): void
    {
        Carbon::setTestNow($at);
        $package = $this->package($code);
        $transaction = $this->transaction($user, ['type' => 'package', 'package_id' => $package->id], $method, 'paid', $at);
        $used = min($package->main_quota, $mainUsed ?? 0);

        Subscription::create([
            'subscriber_id' => $user->subscriber_id, 'source' => 'purchase', 'package_id' => $package->id,
            'transaction_id' => $transaction->id, 'main_total' => $package->main_quota, 'main_used' => $used,
            'app_total' => $package->app_quota, 'app_category' => $package->app_category,
            'started_at' => $at, 'expires_at' => $at->copy()->addDays($package->validity_days),
            'status' => $used >= $package->main_quota ? 'exhausted' : 'active',
        ]);

        $this->forecasts->recompute($user);
    }

    private function transaction(User $user, array $item, string $method, string $status, Carbon $at, array $payload = []): Transaction
    {
        Carbon::setTestNow($at);
        $gross = $item['type'] === 'package' ? Package::find($item['package_id'])->price : $item['topup_amount'];
        $externalRef = 'KP-'.$at->format('Ymd').'-'.Str::upper(Str::random(6));

        $transaction = Transaction::create($item + [
            'user_id' => $user->id, 'gross_amount' => $gross, 'net_amount' => $gross, 'payment_method' => $method,
            'status' => $status, 'idempotency_key' => (string) Str::uuid(), 'request_hash' => hash('sha256', $externalRef),
            'external_ref' => $externalRef,
            'payment_payload' => $payload + ($method === 'va' ? ['bank_label' => 'Bank A', 'va_number' => '8808'.random_int(100000000000, 999999999999)] : []),
            'expires_at' => $method === 'pulsa' ? null : $at->copy()->addMinutes(15),
            'paid_at' => $status === 'paid' ? $at : null,
        ]);

        // Detail transaksi di panel admin menampilkan log callback (FR-15.6).
        if ($method !== 'pulsa' && in_array($status, ['paid', 'failed'], true)) {
            PaymentCallback::create([
                'external_ref' => $externalRef, 'signature_valid' => true, 'processed_at' => $at->copy()->addMinutes(2),
                'payload' => ['external_ref' => $externalRef, 'status' => $status === 'paid' ? 'PAID' : 'FAILED'],
            ]);
        }

        return $transaction;
    }

    /** Budi berbagi 1 GB ke Andi (FR-14.7–14.9). Logika lengkapnya dibangun di M8; di sini hanya hasil akhirnya. */
    private function shareQuota(User $sender, Subscriber $recipient, int $bytes, int $pointsCost, Carbon $at): void
    {
        Carbon::setTestNow($at);
        $source = Subscription::where('subscriber_id', $sender->subscriber_id)->current()->where('status', 'active')->first();
        $source->increment('main_used', $bytes);

        $received = Subscription::create([
            'subscriber_id' => $recipient->id, 'source' => 'shared', 'main_total' => $bytes,
            'started_at' => $at, 'expires_at' => min($at->copy()->addDays(7), $source->expires_at),
        ]);
        $transfer = QuotaTransfer::create([
            'sender_user_id' => $sender->id, 'recipient_subscriber_id' => $recipient->id, 'bytes' => $bytes,
            'points_spent' => $pointsCost, 'recipient_subscription_id' => $received->id, 'expires_at' => $received->expires_at,
            'idempotency_key' => (string) Str::uuid(), 'request_hash' => hash('sha256', 'seed-share'),
            'status' => 'completed', 'completed_at' => $at,
        ]);
        QuotaTransferSource::create(['quota_transfer_id' => $transfer->id, 'subscription_id' => $source->id, 'bytes' => $bytes]);

        $this->points->spend($sender, $pointsCost, $transfer);
        $this->forecasts->recompute($sender);
    }

    /** Rina hemat selama libur semester D-88 s.d. D-61: 28 hari berturut-turut + 4 bonus streak. */
    private function rinaHolidayPoints(User $rina): void
    {
        for ($day = 1; $day <= 28; $day++) {
            $offset = -89 + $day;
            Carbon::setTestNow($this->at($offset + 1, 0, 5));
            $evaluation = DailyEvaluation::create([
                'user_id' => $rina->id, 'eval_date' => $this->at($offset, 0)->toDateString(),
                'usage_bytes' => 400 * self::MB, 'budget_bytes' => 500 * self::MB, 'result' => 'hemat', 'streak_after' => $day,
            ]);
            $this->points->earn($rina, 10, 'earn_daily', $evaluation);
            if ($day % 7 === 0) {
                $this->points->earn($rina, 50, 'earn_streak', $evaluation);
            }
        }
    }

    private function user(string $msisdn, string $name, bool $android = false): User
    {
        return User::create([
            'subscriber_id' => Subscriber::where('msisdn', $msisdn)->value('id'),
            'name' => $name,
            'platform' => $android ? 'android' : 'web',
            'usage_access_granted' => $android,
            'usage_access_checked_at' => $android ? now() : null,
        ]);
    }

    /** MB per aplikasi untuk hari $offset dari profil (mengikuti hari dalam seminggu). */
    private function profile(string $profile, int $offset): array
    {
        return UsageProfiles::days($profile, $this->at($offset, 0), 1)[0];
    }

    /** Total pemakaian profil selama $days hari mulai $offset, dalam byte (untuk main_used paket lama). */
    private function profileSum(string $profile, int $offset, int $days): int
    {
        return array_sum(array_map('array_sum', UsageProfiles::days($profile, $this->at($offset, 0), $days))) * self::MB;
    }

    private function scale(array $usage, float $factor): array
    {
        return array_map(fn ($mb) => $mb * $factor, $usage);
    }

    private function package(string $code): Package
    {
        return Package::where('code', $code)->first();
    }

    private function at(int $offset, int $hour, int $minute = 0, int $second = 0): Carbon
    {
        return $this->today->copy()->addDays($offset)->setTime($hour, $minute, $second);
    }

    private function travel(int $offset, int $hour, int $minute = 0, int $second = 0): void
    {
        Carbon::setTestNow($this->at($offset, $hour, $minute, $second));
    }
}
