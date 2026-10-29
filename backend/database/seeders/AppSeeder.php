<?php

namespace Database\Seeders;

use App\Models\App;
use Illuminate\Database\Seeder;

/**
 * Master aplikasi (OQ-8). Sumber: docs/SEED-KuotaPlus.md bagian Master aplikasi.
 */
class AppSeeder extends Seeder
{
    public function run(): void
    {
        $apps = [
            'video' => [
                'com.zhiliaoapp.musically' => 'TikTok',
                'com.ss.android.ugc.trill' => 'TikTok',
                'com.google.android.youtube' => 'YouTube',
                'com.netflix.mediaclient' => 'Netflix',
                'com.vidio.android' => 'Vidio',
            ],
            'sosmed' => [
                'com.whatsapp' => 'WhatsApp',
                'com.instagram.android' => 'Instagram',
                'com.facebook.katana' => 'Facebook',
                'com.facebook.orca' => 'Messenger',
                'com.twitter.android' => 'X',
                'org.telegram.messenger' => 'Telegram',
                'com.instagram.barcelona' => 'Threads',
            ],
            'game' => [
                'com.mobile.legends' => 'Mobile Legends',
                'com.dts.freefireth' => 'Free Fire',
                'com.tencent.ig' => 'PUBG Mobile',
                'com.roblox.client' => 'Roblox',
                'com.miHoYo.GenshinImpact' => 'Genshin Impact',
            ],
            'belajar' => [
                'us.zoom.videomeetings' => 'Zoom',
                'com.google.android.apps.meetings' => 'Google Meet',
                'com.google.android.apps.classroom' => 'Google Classroom',
                'com.microsoft.teams' => 'Microsoft Teams',
                'com.duolingo' => 'Duolingo',
            ],
            'umum' => [
                'com.android.chrome' => 'Chrome',
                'com.google.android.apps.maps' => 'Google Maps',
                'com.google.android.gm' => 'Gmail',
                'com.shopee.id' => 'Shopee',
                'com.tokopedia.tkpd' => 'Tokopedia',
                'com.gojek.app' => 'Gojek',
                'com.grabtaxi.passenger' => 'Grab',
                'com.spotify.music' => 'Spotify',
            ],
            // Grup UID khusus (FR-7.4).
            'sistem' => [
                'android.system' => 'Sistem Android',
                'android.tethering' => 'Hotspot',
                'android.removed' => 'Aplikasi terhapus',
            ],
        ];

        foreach ($apps as $category => $list) {
            foreach ($list as $packageName => $label) {
                App::updateOrCreate(
                    ['package_name' => $packageName],
                    ['label' => $label, 'category' => $category, 'is_reviewed' => true],
                );
            }
        }
    }
}
