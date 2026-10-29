<?php

namespace App\Services;

use App\Domain\UsageProfiles;
use App\Exceptions\ApiException;
use App\Models\App;
use App\Models\UsageRecord;
use App\Models\User;
use Illuminate\Support\Facades\DB;

/**
 * Mode Demo (FR-7.8): 30 hari pemakaian dari profil + hari ini 35%. Data demo hari lampau
 * tidak memotong kuota (OQ-1, keputusan AQ-2).
 */
class DemoDataService
{
    public const DAYS = 30;

    public const TODAY_FRACTION = 0.35;

    private const MB = 1048576;

    /** @return int total byte yang dibuat */
    public function generate(User $user, string $profile): int
    {
        $start = today()->subDays(self::DAYS);
        $days = UsageProfiles::days($profile, $start, self::DAYS + 1);
        $appIds = App::whereIn('package_name', array_keys($days[0]))->pluck('id', 'package_name');

        $rows = [];
        foreach ($days as $i => $usage) {
            $fraction = $i === self::DAYS ? self::TODAY_FRACTION : 1;
            foreach ($usage as $packageName => $mb) {
                $bytes = (int) round($mb * $fraction * self::MB);
                if ($bytes > 0) {
                    $rows[] = [
                        'user_id' => $user->id,
                        'app_id' => $appIds[$packageName],
                        'usage_date' => $start->copy()->addDays($i)->toDateString(),
                        'bytes_mobile' => $bytes,
                        'bytes_applied' => $bytes,
                        'source' => 'demo',
                        'synced_at' => now(),
                        'created_at' => now(),
                        'updated_at' => now(),
                    ];
                }
            }
        }

        DB::transaction(function () use ($user, $rows) {
            User::whereKey($user->id)->lockForUpdate()->first();

            if (UsageRecord::where('user_id', $user->id)->where('source', 'device')->exists()) {
                throw new ApiException(409, 'DEVICE_DATA_EXISTS', 'Akun ini sudah punya data pemakaian asli dari HP, jadi Mode Demo tidak tersedia.');
            }

            // Memanggil lagi = ganti profil.
            UsageRecord::where('user_id', $user->id)->delete();
            UsageRecord::insert($rows);
        });

        return array_sum(array_column($rows, 'bytes_mobile'));
    }
}
