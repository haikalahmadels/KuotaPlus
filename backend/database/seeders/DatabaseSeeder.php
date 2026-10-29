<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     * Urutan mengikuti docs/SEED-KuotaPlus.md.
     */
    public function run(): void
    {
        $this->call([
            SettingSeeder::class,
            AdminSeeder::class,
            AppSeeder::class,
            PackageSeeder::class,
            SubscriberSeeder::class,
            DemoAccountSeeder::class,
        ]);
    }
}
