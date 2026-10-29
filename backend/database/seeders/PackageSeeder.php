<?php

namespace Database\Seeders;

use App\Models\Package;
use Illuminate\Database\Seeder;

/**
 * Katalog paket (OQ-6). Sumber: docs/SEED-KuotaPlus.md bagian Katalog paket.
 */
class PackageSeeder extends Seeder
{
    private const MB = 1048576;

    private const GB = 1073741824;

    /** Dipakai juga oleh unit test rekomendasi supaya data uji sama dengan katalog seed. */
    public const CATALOG = [
        // code, name, type, price, main, app, app_category, validity_days, is_active
        ['HR1', 'Harian 1 GB', 'harian', 5000, 1 * self::GB, 0, null, 1, true],
        ['HR2', 'Harian 2 GB', 'harian', 8000, 2 * self::GB, 0, null, 1, true],
        ['HR3', 'Harian 3 GB 3 Hari', 'harian', 12000, 3 * self::GB, 0, null, 3, true],
        ['MG5', 'Mingguan 5 GB', 'mingguan', 20000, 5 * self::GB, 0, null, 7, true],
        ['MG10', 'Mingguan 10 GB', 'mingguan', 30000, 10 * self::GB, 0, null, 7, true],
        ['BL15', 'Bulanan 15 GB', 'bulanan', 55000, 15 * self::GB, 0, null, 30, true],
        ['BL25', 'Bulanan 25 GB', 'bulanan', 80000, 25 * self::GB, 0, null, 30, true],
        ['BL50', 'Bulanan 50 GB', 'bulanan', 135000, 50 * self::GB, 0, null, 30, true],
        ['VID30', 'Video 30 Hari', 'aplikasi', 65000, 12 * self::GB, 16 * self::GB, 'video', 30, true],
        ['SOS30', 'Sosmed 30 Hari', 'aplikasi', 60000, 4 * self::GB, 12 * self::GB, 'sosmed', 30, true],
        // Sengaja nonaktif: uji PACKAGE_INACTIVE dan aturan "pernah dibeli tidak bisa dihapus".
        ['HR05', 'Harian 500 MB', 'harian', 3000, 500 * self::MB, 0, null, 1, false],
    ];

    public function run(): void
    {
        foreach (self::CATALOG as [$code, $name, $type, $price, $main, $app, $appCategory, $validity, $active]) {
            Package::updateOrCreate(['code' => $code], [
                'name' => $name,
                'type' => $type,
                'price' => $price,
                'main_quota' => $main,
                'app_quota' => $app,
                'app_category' => $appCategory,
                'validity_days' => $validity,
                'is_active' => $active,
            ]);
        }
    }
}
