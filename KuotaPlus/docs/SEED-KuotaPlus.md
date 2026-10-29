# Spesifikasi Data Seed Kuota+

Oct 29, 2026 · @Haikal Ahmad El Salman · Draft 1

Isi database awal untuk demo dan untuk test. Sumber: [PRD-KuotaPlus.md](PRD-KuotaPlus.md) dan [API-KuotaPlus.md](API-KuotaPlus.md). Dokumen ini menjawab OQ-6 (katalog paket) dan OQ-8 (daftar aplikasi), serta menetapkan dataset profil yang dipakai Definition of done (akurasi prediksi dan kebenaran rekomendasi).

## Prinsip

1. **Tanggal relatif.** Semua tanggal ditulis relatif terhadap **D0** = tanggal WIB saat seeder dijalankan. `D-12` berarti 12 hari sebelum D0. Dengan begitu `php artisan migrate:fresh --seed` sebelum demo selalu menghasilkan data yang segar.
2. **Deterministik.** Profil Rina dan Budi tidak memakai angka acak. Profil Acak memakai `mt_srand(2026)`, sehingga hasilnya selalu sama. Menjalankan seeder dua kali di hari yang sama menghasilkan data yang identik.
3. **Seeder memakai service aplikasi, tidak menyalin logikanya.** Setelah data mentah dimasukkan, seeder memanggil service forecast (FR-9) dan rekomendasi (FR-10) untuk akun demo. Hasil di bagian "Hasil yang diharapkan" sekaligus menjadi cek bahwa service itu benar.
4. **Parameter dari `settings`.** Seeder settings berjalan paling awal. Seeder lain membaca nilai dari tabel itu, bukan dari konstanta di kode.

Urutan seeder: `SettingSeeder` → `AdminSeeder` → `AppSeeder` → `PackageSeeder` → `SubscriberSeeder` → `DemoAccountSeeder`.

## Operator

| Item | Nilai |
| --- | --- |
| Nama | **Nusantel** (fiktif). Menggantikan placeholder "[operator]" di PRD, contoh: "Nomor bukan pelanggan Nusantel" |
| Prefix nomor seed | `0881` (format simpan `62881…`) |

Catatan: semua prefix 08xx di Indonesia sudah dipakai operator nyata (`0881` milik Smartfren). Karena tidak ada integrasi operator sungguhan, tabrakan ini tidak berdampak. Nama fiktif dipakai supaya aplikasi tidak terkesan sebagai aplikasi resmi merek nyata, sejalan dengan OQ-5.

## Settings

Nilai awal tabel `settings` (FR-15.10). Min dan max dipakai validasi form admin.

| Key | Default | Min | Max | Sumber |
| --- | --- | --- | --- | --- |
| `reward.points_per_day` | 10 | 1 | 100 | OQ-3 |
| `reward.streak_length` | 7 | 2 | 30 | OQ-3 |
| `reward.streak_bonus` | 50 | 0 | 500 | OQ-3 |
| `reward.min_usage_bytes` | 52428800 (50 MB) | 0 | 1073741824 (1 GB) | OQ-4 |
| `points.rupiah_per_point` | 10 | 1 | 100 | OQ-3 |
| `points.redeem_step` | 100 | 1 | 1000 | FR-12.2 |
| `points.max_discount_percent` | 20 | 0 | 50 | OQ-3 |
| `points.min_net_amount` | 1000 | 0 | 10000 | FR-12.4 |
| `points.validity_days` | 90 | 7 | 365 | OQ-3 |
| `card.grace_days` | 15 | 0 | 60 | OQ-2 |
| `topup.options` | lihat bawah | — | — | OQ-2 |
| `share.limit_bytes_30d` | 2147483648 (2 GB) | 536870912 (500 MB) | 10737418240 (10 GB) | FR-14.4 |
| `share.min_remaining_bytes` | 2147483648 (2 GB) | 0 | 10737418240 (10 GB) | FR-14.5 |
| `share.step_bytes` | 536870912 (500 MB) | 104857600 (100 MB) | 2147483648 (2 GB) | OQ-15 |
| `share.points_per_step` | 100 | 0 | 1000 | OQ-15 |
| `share.validity_days` | 7 | 1 | 30 | FR-14.8 |
| `notify.quota_low_percent` | 20 | 5 | 50 | FR-13.1 |
| `notify.package_expiring_days` | 1 | 1 | 7 | FR-13.1 |
| `notify.card_expiring_days` | 3 | 1 | 14 | FR-13.1 |

`topup.options` (JSON). Setiap baris divalidasi: `amount` 1.000–1.000.000, `extend_days` 1–365.

```json
[
  { "amount": 5000, "extend_days": 7 },
  { "amount": 10000, "extend_days": 15 },
  { "amount": 25000, "extend_days": 30 },
  { "amount": 50000, "extend_days": 45 },
  { "amount": 100000, "extend_days": 60 }
]
```

## Admin

Satu akun dari `.env`: `ADMIN_EMAIL` (default `admin@kuotaplus.test`) dan `ADMIN_PASSWORD`. Jika `ADMIN_PASSWORD` kosong, seeder berhenti dengan error, supaya tidak ada password bawaan yang terlupa diganti.

## Katalog paket (OQ-6)

Harga mengikuti kisaran pasar prabayar 2026. 1 GB = 1024 MB.

| Kode | Nama | Tipe | Harga | Kuota utama | Kuota aplikasi | Masa berlaku | Aktif |
| --- | --- | --- | --- | --- | --- | --- | --- |
| `HR1` | Harian 1 GB | harian | Rp5.000 | 1 GB | — | 1 hari | Ya |
| `HR2` | Harian 2 GB | harian | Rp8.000 | 2 GB | — | 1 hari | Ya |
| `HR3` | Harian 3 GB 3 Hari | harian | Rp12.000 | 3 GB | — | 3 hari | Ya |
| `MG5` | Mingguan 5 GB | mingguan | Rp20.000 | 5 GB | — | 7 hari | Ya |
| `MG10` | Mingguan 10 GB | mingguan | Rp30.000 | 10 GB | — | 7 hari | Ya |
| `BL15` | Bulanan 15 GB | bulanan | Rp55.000 | 15 GB | — | 30 hari | Ya |
| `BL25` | Bulanan 25 GB | bulanan | Rp80.000 | 25 GB | — | 30 hari | Ya |
| `BL50` | Bulanan 50 GB | bulanan | Rp135.000 | 50 GB | — | 30 hari | Ya |
| `VID30` | Video 30 Hari | aplikasi | Rp65.000 | 12 GB | 16 GB video | 30 hari | Ya |
| `SOS30` | Sosmed 30 Hari | aplikasi | Rp60.000 | 4 GB | 12 GB sosmed | 30 hari | Ya |
| `HR05` | Harian 500 MB | harian | Rp3.000 | 500 MB | — | 1 hari | **Tidak** |

`HR05` sengaja nonaktif. Paket ini dipakai untuk menguji error `PACKAGE_INACTIVE` dan aturan "paket yang pernah dibeli tidak bisa dihapus" (FR-15.3). Satu transaksi lama milik Budi memakai paket ini.

Biaya 30 hari tiap paket (FR-10.3: harga × ceil(30 / masa berlaku)) untuk referensi test:

| Kode | Biaya 30 hari | Total kuota 30 hari |
| --- | --- | --- |
| HR1 | Rp150.000 | 30 GB |
| HR2 | Rp240.000 | 60 GB |
| HR3 | Rp120.000 | 30 GB |
| MG5 | Rp100.000 | 25 GB |
| MG10 | Rp150.000 | 50 GB |
| BL15 | Rp55.000 | 15 GB |
| BL25 | Rp80.000 | 25 GB |
| BL50 | Rp135.000 | 50 GB |
| VID30 | Rp65.000 | 12 GB utama + 16 GB video |
| SOS30 | Rp60.000 | 4 GB utama + 12 GB sosmed |

Kuota yang dibandingkan dengan kebutuhan juga dikalikan ceil(30 / masa berlaku), sama seperti harganya. Tanpa itu, paket harian tidak akan pernah dianggap "cukup".

## Master aplikasi (OQ-8)

30 aplikasi populer di Indonesia + 3 grup UID khusus (FR-7.4). Semua di-seed dengan status sudah ditinjau. Aplikasi lain yang muncul dari sync masuk `umum` dan ditandai "Belum ditinjau".

| Kategori | `package_name` | Label |
| --- | --- | --- |
| video | `com.zhiliaoapp.musically` | TikTok |
| video | `com.ss.android.ugc.trill` | TikTok |
| video | `com.google.android.youtube` | YouTube |
| video | `com.netflix.mediaclient` | Netflix |
| video | `com.vidio.android` | Vidio |
| sosmed | `com.whatsapp` | WhatsApp |
| sosmed | `com.instagram.android` | Instagram |
| sosmed | `com.facebook.katana` | Facebook |
| sosmed | `com.facebook.orca` | Messenger |
| sosmed | `com.twitter.android` | X |
| sosmed | `org.telegram.messenger` | Telegram |
| sosmed | `com.instagram.barcelona` | Threads |
| game | `com.mobile.legends` | Mobile Legends |
| game | `com.dts.freefireth` | Free Fire |
| game | `com.tencent.ig` | PUBG Mobile |
| game | `com.roblox.client` | Roblox |
| game | `com.miHoYo.GenshinImpact` | Genshin Impact |
| belajar | `us.zoom.videomeetings` | Zoom |
| belajar | `com.google.android.apps.meetings` | Google Meet |
| belajar | `com.google.android.apps.classroom` | Google Classroom |
| belajar | `com.microsoft.teams` | Microsoft Teams |
| belajar | `com.duolingo` | Duolingo |
| umum | `com.android.chrome` | Chrome |
| umum | `com.google.android.apps.maps` | Google Maps |
| umum | `com.google.android.gm` | Gmail |
| umum | `com.shopee.id` | Shopee |
| umum | `com.tokopedia.tkpd` | Tokopedia |
| umum | `com.gojek.app` | Gojek |
| umum | `com.grabtaxi.passenger` | Grab |
| umum | `com.spotify.music` | Spotify |
| sistem | `android.system` | Sistem Android |
| sistem | `android.tethering` | Hotspot |
| sistem | `android.removed` | Aplikasi terhapus |

TikTok punya dua `package_name` karena build regional berbeda. Keduanya berlabel sama, dan analisis per aplikasi menggabungkannya berdasarkan label.

Kategori `sistem` dihitung sebagai `umum` saat memecah kebutuhan per kategori di FR-10.2.

## Profil pemakaian

Profil adalah pola pemakaian per hari per aplikasi, dalam MB. Profil yang sama dipakai di tiga tempat:

- `POST /usage/demo` (Mode Demo) untuk membuat 30 hari data.
- Akun demo di bagian berikutnya (pola + kejadian khusus).
- Unit test prediksi dan rekomendasi (Definition of done).

### Rina

Pola mingguan. Rata-rata 804 MB/hari, sehingga Bulanan 15 GB habis di hari ke-19 (persona: "habis di hari ke-20").

| Aplikasi | Sen | Sel | Rab | Kam | Jum | Sab | Min |
| --- | --- | --- | --- | --- | --- | --- | --- |
| TikTok | 380 | 380 | 380 | 380 | 380 | 480 | 480 |
| Instagram | 180 | 180 | 180 | 180 | 180 | 200 | 200 |
| YouTube | 40 | 40 | 40 | 40 | 40 | 80 | 80 |
| WhatsApp | 40 | 40 | 40 | 40 | 40 | 40 | 40 |
| Zoom | 0 | 250 | 0 | 250 | 0 | 0 | 0 |
| Chrome | 30 | 30 | 30 | 30 | 30 | 20 | 20 |
| Sistem Android | 20 | 20 | 20 | 20 | 20 | 20 | 20 |
| **Total** | **690** | **940** | **690** | **940** | **690** | **840** | **840** |

Porsi kategori: video 57,2%, sosmed 28,1%, belajar 8,9%, umum 5,9%.

### Budi

Rata-rata 379 MB/hari (11,1 GB/bulan; persona: sekitar 12 GB).

| Aplikasi | Sen–Jum | Sab–Min |
| --- | --- | --- |
| WhatsApp | 120 | 120 |
| Google Maps | 110 | 20 |
| Gmail | 40 | 10 |
| YouTube | 60 | 150 |
| Chrome | 40 | 30 |
| Sistem Android | 20 | 20 |
| **Total** | **390** | **350** |

Porsi kategori: umum 45,7%, sosmed 31,7%, video 22,6%.

### Acak

Total per hari = `round(600 × U(0,6; 1,4))` MB, dengan `mt_srand(2026)` dan satu panggilan `mt_rand` per hari secara berurutan dari hari pertama. Total dibagi dengan porsi tetap:

| Aplikasi | Porsi |
| --- | --- |
| YouTube | 25% |
| Mobile Legends | 20% |
| Instagram | 15% |
| WhatsApp | 10% |
| Shopee | 10% |
| Chrome | 10% |
| Sistem Android | 10% |

### Aturan pembentukan data

- Satu baris `usage_records` per aplikasi per hari, `bytes_mobile` = MB × 1.048.576.
- **Hari ini (D0)** diisi 35% dari pola harinya, supaya kartu "terpakai hari ini" tidak kosong.
- Pemakaian sebelum D-30 tidak disimpan di `usage_records`. Jika dibutuhkan (misalnya `main_used` paket lama), angkanya dihitung dari pola yang sama.

## Pelanggan dan akun demo

| Nomor | Nama | Status kartu | Pulsa | Masa aktif | Akun `users` | Kegunaan |
| --- | --- | --- | --- | --- | --- | --- |
| 0881-0000-0001 | Rina | active | Rp12.500 | D+25 | Ya, lengkap | Persona 1: kuota berisiko habis, beli dengan poin, pulsa kurang |
| 0881-0000-0002 | Budi | active | Rp150.000 | D+40 | Ya, lengkap | Persona 2: over-buy, rekomendasi hemat besar, berbagi kuota |
| 0881-0000-0003 | Dimas | active | Rp30.000 | D+20 | Ya, 5 hari data | Pengguna baru: prediksi "perkiraan awal", rekomendasi belum tersedia, paket hampir berakhir |
| 0881-0000-0004 | Uji HP | active | Rp100.000 | D+60 | Tidak | Login dari HP fisik untuk uji data asli Android (DoD). Paket BL25 aktif, tanpa data pemakaian |
| 0881-0000-0005 | Sari | grace | Rp2.000 | D-3 (tenggang sampai D+12) | Ya, tanpa riwayat | Masa tenggang: hanya bisa isi ulang, beli paket ditolak `SUBSCRIBER_IN_GRACE`, tidak bisa jadi penerima berbagi |
| 0881-0000-0006 | — | terminated | Rp0 | D-30 (tenggang berakhir D-15) | Tidak | Login ditolak `SUBSCRIBER_TERMINATED` |
| 0881-0000-0007 | Andi | active | Rp10.000 | D+30 | Tidak | Penerima berbagi kuota tanpa akun Kuota+ (SMS dummy di log) |

Semua `users` dibuat dengan `platform = web` dan `usage_access_granted = false`, kecuali yang disebut lain. `Uji HP` tidak punya baris `users`; akunnya dibuat saat login pertama dari HP.

Jam pembelian semua transaksi seed adalah 07:00 WIB kecuali disebut lain. Setiap transaksi `paid` non-pulsa punya satu baris `payment_callbacks` dengan `signature_valid = true`, supaya detail transaksi di panel admin tidak kosong.

### Rina

Cerita: paket bulanannya habis di tengah bulan lalu, ia membeli paket harian darurat 4 kali, lalu membeli Bulanan 15 GB lagi yang akan habis lebih cepat lagi.

**Transaksi**

| Waktu | Item | Metode | Status | Catatan |
| --- | --- | --- | --- | --- |
| D-42 | BL15 Rp55.000 | va | paid | Paket lama, di luar jendela 30 hari |
| D-21, D-19, D-16, D-14 | HR1 Rp5.000 (×4) | pulsa | paid | Pembelian darurat |
| D-12 | BL15 Rp55.000 | qris | paid | Paket aktif sekarang |
| D-5 | VID30 Rp65.000 | qris | expired | Tidak dibayar dalam 15 menit |
| D-3 | Isi ulang Rp25.000 | ewallet | failed | Ditolak di simulator |

Total belanja paket `paid` 30 hari terakhir: 4 × Rp5.000 + Rp55.000 = **Rp75.000**.

**Paket (`subscriptions`)**

| Paket | Mulai | Berakhir | Status di D0 | `main_used` |
| --- | --- | --- | --- | --- |
| BL15 lama | D-42 | D-12 | expired | 15 GB (habis di D-23) |
| HR1 ×4 | hari beli | +1 hari | expired | Sama dengan pemakaian hari itu |
| BL15 aktif | D-12 | D+18 | active | Total pemakaian D-12 s.d. D0 |

**Pemakaian (D-30 s.d. D0)**

| Rentang | Isi |
| --- | --- |
| D-30 s.d. D-23 | Pola Rina |
| D-22 s.d. D-13 | Kuota habis, memakai Wi-Fi kampus: 0 MB, kecuali di 4 hari HR1 masing-masing 950 MB dengan porsi pola Rina |
| D-12 s.d. D0 | Pola Rina (D0 35%) |

**Poin**

| Sumber | Baris | Poin |
| --- | --- | --- |
| Libur semester, D-88 s.d. D-61 | 28 hari `earn_daily` berturut-turut + 4 `earn_streak` (hari ke-7, 14, 21, 28) | 480 |
| Evaluasi 30 hari terakhir | Dihitung seeder dengan aturan FR-11 (lihat Aturan evaluasi) | ±40 |

Poin dari D-88 s.d. D-83 kedaluwarsa D+2 s.d. D+7, sehingga kartu "poin akan kedaluwarsa" punya isi. Hari-hari libur semester juga diberi baris `daily_evaluations` (`usage_bytes` 400 MB, `budget_bytes` 500 MB, `hemat`) supaya setiap baris ledger punya referensi.

### Budi

Cerita: membeli Bulanan 50 GB tiap bulan, sisa sekitar 38 GB hangus. Pernah berbagi 1 GB ke Andi. Ada lonjakan update sistem.

**Transaksi**

| Waktu | Item | Metode | Status |
| --- | --- | --- | --- |
| D-80 | HR05 Rp3.000 | pulsa | paid |
| D-50 | BL50 Rp135.000 | pulsa | paid |
| D-21 | Isi ulang Rp100.000 | va | paid |
| D-20 | BL50 Rp135.000 | pulsa | paid |

Total belanja paket `paid` 30 hari terakhir: **Rp135.000**.

**Paket**

| Paket | Mulai | Berakhir | Status di D0 | `main_used` |
| --- | --- | --- | --- | --- |
| HR05 | D-80 | D-79 | expired | 300 MB |
| BL50 lama | D-50 | D-20 | expired | 30 hari pola Budi (≈ 11,1 GB). Sisa ≈ 38,9 GB tercatat hangus |
| BL50 aktif | D-20 | D+10 | active | Pemakaian D-20 s.d. D0 + 1 GB yang dibagikan ke Andi |

**Pemakaian:** pola Budi untuk D-30 s.d. D0, ditambah lonjakan **Sistem Android +3.072 MB pada D-9** (update OS). Lonjakan ini sengaja di luar 7 hari terakhir, supaya muncul di insight "Lonjakan tidak biasa" tetapi tidak menggeser prediksi.

**Berbagi kuota:** D-10, 1 GB ke Andi, 200 poin, `completed`. Sumbernya BL50 aktif. Kuota Andi berakhir min(D-10 + 7 hari, D+10) = D-3, jadi berstatus `expired` di D0. Jatah berbagi Budi tersisa 1 GB dan pulih di D+20.

**Poin:** dari evaluasi 30 hari terakhir dikurangi 200 poin `spend_share`. `usage_access_granted = true`, `platform = android`, untuk mengisi metrik admin.

### Dimas

**Transaksi:** D-6 pukul 10:00, MG10 Rp30.000 lewat ewallet, `paid`.

**Paket:** MG10 aktif, mulai D-6 10:00, berakhir **D+1 10:00**. Ini memicu alert `package_expiring`.

**Pemakaian:** profil Acak untuk D-5 s.d. D-1 (5 hari) + D0 35%.

**Poin:** dari evaluasi D-5 s.d. D-1. Jatah hariannya besar (10 GB / 7 hari), jadi kelima hari itu hemat: ≈ 50 poin, streak 5, belum ada bonus streak. D-6 tidak dievaluasi karena belum ada sync hari itu (FR-11.4).

### Andi

Subscriber tanpa akun. Punya satu `subscriptions` dengan `source = shared` dari Budi (1 GB, D-10 s.d. D-3, `expired`).

## Aturan evaluasi reward di seeder

Supaya kalender reward konsisten dengan data, seeder memutar ulang hari demi hari dari D-30 s.d. D-1 untuk Rina, Budi, dan Dimas:

1. Pada awal hari d, ambil paket utama aktif. Jika tidak ada paket aktif, hari itu tidak dievaluasi (tidak ada baris, kalender abu-abu).
2. `budget_bytes` = sisa kuota utama pada 00:00 / sisa hari sampai `expires_at` paket utama terdekat. Untuk paket yang dibeli di hari itu, pakai kuota awal paket.
3. Kurangi kuota dengan pemakaian hari d.
4. Tentukan `result` dan poin dengan aturan FR-11.2 dan FR-11.3, lalu tulis `daily_evaluations` dan `point_ledger`.

Logika ini sama dengan job harian FR-11. Seeder sebaiknya memanggil service yang sama dengan parameter tanggal, bukan menulis ulang aturannya.

## Hasil yang diharapkan

Cek ini dijalankan setelah `migrate:fresh --seed`. Angka bertanda ≈ bergantung pada hari dalam seminggu saat seeder dijalankan.

| Akun | Endpoint | Hasil |
| --- | --- | --- |
| Rina | `GET /home` | Forecast `high`, `risk`, habis ≈ D+7, `days_early` ≈ 11. Satu paket aktif BL15 dengan sisa ≈ 5,3 GB |
| Rina | `GET /recommendations` | `ok`. Rank 1 **VID30** (Rp65.000, sisa ≈ 2 GB). Alternatif: HR3 (Rp120.000), BL50 (Rp135.000). `saving_30d` = Rp75.000 − Rp65.000 = **Rp10.000**. BL25 **tidak** cukup karena kebutuhan ≈ 25,2–26,6 GB |
| Rina | `GET /points` | Saldo ≈ 520, streak 0, `expiring_soon` 60 poin. Saat checkout VID30, poin maksimal 500 (Rp5.000) |
| Rina | `POST /transactions` VID30 metode pulsa | `422 INSUFFICIENT_BALANCE`, `shortfall` Rp52.500 (atau Rp47.500 jika memakai 500 poin) |
| Budi | `GET /home` | Forecast `high`, `safe`. Sisa BL50 ≈ 38,5 GB |
| Budi | `GET /recommendations` | `ok`. Rank 1 **BL15** (Rp55.000, sisa ≈ 2,8 GB). Alternatif: VID30 (Rp65.000), BL25 (Rp80.000). `saving_30d` = Rp135.000 − Rp55.000 = **Rp80.000** |
| Budi | `GET /usage/summary?period=30d` | Insight lonjakan pada D-9. Hari D-9 `is_spike = true` |
| Budi | `GET /points` | Streak ≈ 8 (lonjakan D-9 membuat hari itu boros) |
| Budi | `GET /quota-transfers/quote` | `remaining_bytes` 1 GB, `recovers_at` D+20 |
| Dimas | `GET /home` | Forecast `low` (5 hari data), alert `package_expiring` |
| Dimas | `GET /recommendations` | `insufficient_data` |
| Sari | `POST /transactions` paket | `403 SUBSCRIBER_IN_GRACE` |
| 0006 | `POST /auth/otp/request` | `403 SUBSCRIBER_TERMINATED` |
| 0881-9999-9999 | `POST /auth/otp/request` | `404 NOT_SUBSCRIBER` |

## Dataset unit test

Unit test tidak memakai database hasil seeder. Test membuat datanya sendiri dari **profil** di atas, supaya hasilnya tidak bergantung pada tanggal.

### Prediksi (FR-9.6)

| Kasus | Data | Harapan |
| --- | --- | --- |
| Keyakinan tinggi | 7 hari pola Rina | `confidence = high` |
| Keyakinan rendah | 4 hari pola Rina | `confidence = low` |
| Tanpa prediksi | 2 hari pola Rina | `confidence = none`, `predicted_empty_at = null` |
| Pemakaian nol | 7 hari 0 MB | `avg_daily_bytes = 0`, `status = safe` |
| Bobot | 7 hari: hari ke-1 s.d. 6 = 100 MB, kemarin = 800 MB | `avg_daily` = (100×21 + 800×7) / 28 = 275 MB |

### Backtest akurasi (DoD: MAPE ≤ 20%)

Untuk setiap profil (Rina, Budi, Acak):

1. Bangun 60 hari data, dimulai hari Senin.
2. Paket BL15 dibeli di awal hari ke-1.
3. Prediksi dibuat di akhir hari ke-7.
4. Hari habis sebenarnya = hari pertama ketika pemakaian kumulatif ≥ 15 GB.
5. APE = |hari prediksi − hari sebenarnya| / (hari sebenarnya − 7).

MAPE = rata-rata APE ketiga profil, harus ≤ 20%. Hari habis sebenarnya: Rina ≈ hari ke-20, Budi ≈ hari ke-41, Acak bergantung pada hasil RNG.

### Rekomendasi (FR-10)

| Kasus | Data | Harapan |
| --- | --- | --- |
| Rina | 30 hari pola Rina, belanja 30 hari Rp75.000 | Rank 1 VID30, `saving_30d` Rp10.000 |
| Budi | 30 hari pola Budi, belanja 30 hari Rp135.000 | Rank 1 BL15, `saving_30d` Rp80.000 |
| Data kurang | 6 hari pola Rina | `insufficient_data` |
| Sudah paling hemat | Pola Budi, belanja 30 hari Rp55.000 | `already_cheapest` |
| Belum pernah beli | Pola Budi, tanpa transaksi | `saving_30d = null` |
| Properti umum | Setiap profil | Paket rank 1 selalu "cukup" dan `cost_30d`-nya ≤ semua paket lain yang cukup (DoD) |

## Pertanyaan terbuka

| ID | Pertanyaan | Usulan default |
| --- | --- | --- |
| SQ-1 | Aturan "hari hemat" (pemakaian ≤ jatah harian) membuat pengguna over-buy seperti Budi hampir selalu hemat, karena jatah hariannya besar. Over-buy justru diberi poin. Perlu diubah? | Tidak di MVP. Dicatat sebagai keterbatasan. Opsi v2: jatah harian dihitung dari kebutuhan rekomendasi, bukan dari sisa kuota |
| SQ-2 | Daftar `package_name` belum diverifikasi di perangkat nyata. | Verifikasi saat uji HP fisik. Nama yang salah tidak merusak apa pun: aplikasinya masuk `umum` dan bisa dikoreksi dari panel admin |
