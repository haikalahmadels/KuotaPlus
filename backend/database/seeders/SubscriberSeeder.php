<?php

namespace Database\Seeders;

use App\Models\Package;
use App\Models\Subscriber;
use App\Models\Subscription;
use Illuminate\Database\Seeder;

/**
 * Nomor pelanggan Nusantel. Sumber: docs/SEED-KuotaPlus.md bagian Pelanggan dan akun demo.
 * Riwayat lengkap Rina/Budi/Dimas/Andi diisi DemoAccountSeeder (M6).
 */
class SubscriberSeeder extends Seeder
{
    public function run(): void
    {
        $today = today();

        $subscribers = [
            // msisdn, pulsa, active_until, grace_until, status
            ['6288100000001', 12500, $today->copy()->addDays(25), null, 'active'],   // Rina
            ['6288100000002', 150000, $today->copy()->addDays(40), null, 'active'],  // Budi
            ['6288100000003', 30000, $today->copy()->addDays(20), null, 'active'],   // Dimas
            ['6288100000004', 100000, $today->copy()->addDays(60), null, 'active'],  // Uji HP
            ['6288100000005', 2000, $today->copy()->subDays(3), $today->copy()->addDays(12), 'grace'], // Sari
            ['6288100000006', 0, $today->copy()->subDays(30), $today->copy()->subDays(15), 'terminated'],
            ['6288100000007', 10000, $today->copy()->addDays(30), null, 'active'],   // Andi
        ];

        foreach ($subscribers as [$msisdn, $pulsa, $activeUntil, $graceUntil, $status]) {
            Subscriber::updateOrCreate(['msisdn' => $msisdn], [
                'pulsa_balance' => $pulsa,
                'active_until' => $activeUntil,
                'grace_until' => $graceUntil,
                'status' => $status,
            ]);
        }

        // Nomor Uji HP: paket BL25 aktif tanpa riwayat, untuk uji data asli Android.
        $ujiHp = Subscriber::where('msisdn', '6288100000004')->first();
        $bl25 = Package::where('code', 'BL25')->first();
        Subscription::updateOrCreate(['subscriber_id' => $ujiHp->id, 'package_id' => $bl25->id], [
            'source' => 'purchase',
            'main_total' => $bl25->main_quota,
            'app_total' => 0,
            'started_at' => $today->copy()->setTime(7, 0),
            'expires_at' => $today->copy()->setTime(7, 0)->addDays($bl25->validity_days),
            'status' => 'active',
        ]);
    }
}
