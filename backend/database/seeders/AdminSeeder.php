<?php

namespace Database\Seeders;

use App\Models\Admin;
use Illuminate\Database\Seeder;
use RuntimeException;

class AdminSeeder extends Seeder
{
    public function run(): void
    {
        $password = config('services.admin.password');

        // Tidak ada password bawaan, supaya tidak ada akun admin dengan password yang terlupa diganti.
        if (blank($password)) {
            throw new RuntimeException('ADMIN_PASSWORD di .env kosong. Isi dulu sebelum menjalankan seeder.');
        }

        Admin::updateOrCreate(
            ['email' => config('services.admin.email')],
            ['name' => 'Admin Kuota+', 'password' => $password],
        );
    }
}
