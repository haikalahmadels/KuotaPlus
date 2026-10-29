<?php

namespace App\Services;

use App\Models\App;
use App\Models\UsageRecord;
use App\Models\User;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

/**
 * POST /usage/sync (FR-7.5–7.7). Nilai per bucket adalah total kumulatif hari itu; server menghitung delta,
 * jadi sync yang sama boleh terkirim berkali-kali tanpa memotong kuota ganda.
 */
class UsageSyncService
{
    public const MAX_AGE_DAYS = 7;

    public function __construct(private QuotaService $quota) {}

    /**
     * @param  list<array{usage_date: string, package_name: string, label: string, bytes_mobile: int}>  $buckets
     * @return array{accepted: int, rejected: list<array{index: int, reason: string}>, applied_bytes: int}
     */
    public function sync(User $user, array $buckets): array
    {
        $today = today();
        $rejected = [];
        $valid = [];

        foreach ($buckets as $index => $bucket) {
            // Tanggal dinilai dengan jam server, bukan jam perangkat (edge case manipulasi jam).
            $date = Carbon::parse($bucket['usage_date'])->startOfDay();
            $reason = match (true) {
                $date->gt($today) => 'FUTURE_DATE',
                $date->lt($today->copy()->subDays(self::MAX_AGE_DAYS)) => 'TOO_OLD',
                default => null,
            };
            if ($reason) {
                $rejected[] = ['index' => $index, 'reason' => $reason];

                continue;
            }

            // Bucket duplikat untuk aplikasi dan hari yang sama dijumlahkan.
            $key = $date->toDateString().'|'.$bucket['package_name'];
            $valid[$key] ??= ['date' => $date, 'package_name' => $bucket['package_name'], 'label' => $bucket['label'], 'bytes' => 0];
            $valid[$key]['bytes'] += $bucket['bytes_mobile'];
        }

        $applied = DB::transaction(function () use ($user, $valid) {
            User::whereKey($user->id)->lockForUpdate()->first();

            // Data asli menggantikan data demo (tidak boleh tercampur, lihat POST /usage/demo).
            UsageRecord::where('user_id', $user->id)->where('source', 'demo')->delete();

            $applied = 0;
            // Diproses urut tanggal supaya pemotongan kuota mengikuti urutan waktu.
            foreach (collect($valid)->sortBy(fn ($b) => $b['date']->toDateString()) as $bucket) {
                $applied += $this->apply($user, $bucket);
            }

            return $applied;
        });

        return ['accepted' => count($buckets) - count($rejected), 'rejected' => $rejected, 'applied_bytes' => $applied];
    }

    private function apply(User $user, array $bucket): int
    {
        $app = $this->resolveApp($bucket['package_name'], $bucket['label']);

        $record = UsageRecord::firstOrNew([
            'user_id' => $user->id,
            'app_id' => $app->id,
            'usage_date' => $bucket['date']->toDateString(),
        ]);

        $delta = $bucket['bytes'] - $record->bytes_applied;
        if ($delta < 0) {
            Log::warning('Delta pemakaian negatif diabaikan', ['user_id' => $user->id, 'app' => $app->package_name,
                'date' => $bucket['date']->toDateString(), 'stored' => $record->bytes_applied, 'received' => $bucket['bytes']]);

            return 0;
        }

        $applied = $this->quota->consume($user->subscriber_id, $app->category, $delta, $bucket['date']);

        $record->fill([
            'bytes_mobile' => $bucket['bytes'],
            'bytes_applied' => $bucket['bytes'], // sudah diproses; kuota yang habis tidak ditagih belakangan
            'source' => 'device',
            'synced_at' => now(),
        ])->save();

        return $applied;
    }

    /** Aplikasi yang belum dikenal masuk kategori umum dan ditandai "Belum ditinjau" (FR-15.4). */
    private function resolveApp(string $packageName, string $label): App
    {
        return App::firstOrCreate(
            ['package_name' => $packageName],
            ['label' => mb_substr($label, 0, 255), 'category' => 'umum', 'is_reviewed' => false],
        );
    }
}
