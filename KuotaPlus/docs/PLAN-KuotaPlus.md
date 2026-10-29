# Rencana Implementasi Kuota+

Oct 29, 2026 · @Haikal Ahmad El Salman · Draft 1

Urutan pengerjaan Kuota+ dari nol sampai Definition of done (DoD) di [PRD](PRD-KuotaPlus.md) terpenuhi. Rujukan: [API](API-KuotaPlus.md), [SEED](SEED-KuotaPlus.md), [TECH](TECH-KuotaPlus.md).

## Pendekatan

**Per fitur, end-to-end.** Setiap milestone menyelesaikan satu irisan fitur di backend, lalu langsung di Flutter, sampai bisa didemokan di Android dan Chrome. Milestone berikutnya baru dimulai setelah kriteria "Selesai jika" terpenuhi.

Aturan yang berlaku di setiap milestone:

1. **Wireframe dulu.** Sebelum membuat UI Flutter, sketsa kasar layar milestone itu ditambahkan ke `docs/UI-KuotaPlus.md` (dibuat di M0).
2. **Backend dulu, lalu Flutter.** Endpoint selesai beserta feature test-nya, baru layar Flutter yang memakainya.
3. **Kontrak API berubah = dokumen berubah.** Jika saat implementasi ternyata kontrak di API-KuotaPlus.md perlu diubah, dokumennya diperbarui di commit yang sama.
4. **Satu commit per tugas yang selesai**, dan satu tag git per milestone (`m1`, `m2`, …), supaya mudah kembali ke kondisi yang bisa didemokan.

Ukuran (S/M/L) adalah perkiraan relatif, bukan jadwal. PRD tidak menetapkan deadline.

## Peta milestone

| # | Milestone | Ukuran | Butuh | Kriteria DoD yang terpenuhi |
| --- | --- | --- | --- | --- |
| M0 | Fondasi | M | — | — |
| M1 | Login OTP | S | M0 | — |
| M2 | Beranda dan katalog | M | M1 | — |
| M3 | Transaksi dan pembayaran | L | M2 | Ketahanan pembayaran |
| M4 | Pemakaian per aplikasi | L | M2 | Data asli Android |
| M5 | Prediksi dan rekomendasi | M | M4 | Akurasi prediksi, Kebenaran rekomendasi |
| M6 | Reward dan poin | L | M3, M5 | Integritas poin, Skenario demo end-to-end |
| M7 | Peringatan dan notifikasi | S | M5 | — |
| M8 | Berbagi kuota | M | M1, M6 | Aturan berbagi kuota |
| M9 | Panel admin | M | M3–M8 | Panel admin |
| M10 | Verifikasi dan demo | S | semua | Performa lokal, semua kriteria dicek ulang |

M3 dan M4 sama-sama hanya butuh M2, jadi urutannya boleh ditukar.

## M0 Fondasi

**Repo dan dokumen**

- `git init` di folder induk `KuotaPlus/`, `.gitignore` untuk Laravel dan Flutter.
- Ganti nama package Flutter `dayum` → `kuota_plus`.
- Buat `docs/UI-KuotaPlus.md`: design token (warna, tipografi, spacing, radius), daftar semua layar, dan peta navigasi. Wireframe per layar diisi bertahap di milestone masing-masing.

**Backend**

- `composer create-project laravel/laravel backend`, pasang Sanctum.
- `.env`: database `kuotaplus`, `APP_URL` = IP LAN, `APP_TIMEZONE`, `PAYMENT_WEBHOOK_SECRET`, `ADMIN_EMAIL`, `ADMIN_PASSWORD`. Database test `kuotaplus_test` di `phpunit.xml`.
- Laragon: vhost `C:\laragon\etc\apache2\sites-enabled\0-kuotaplus.conf` ke `backend/public`. Nama file diawali `0-` supaya menjadi vhost default untuk `localhost` dan IP LAN; project Laragon lain tetap bisa diakses lewat nama host-nya.
- **Semua migration** sesuai data model PRD (termasuk perubahan dari API, SEED, dan TECH). Data model sudah lengkap, jadi lebih sederhana dibuat sekaligus daripada dicicil per milestone.
- Model Eloquent + relasi.
- `ApiException` + penanganan error di `bootstrap/app.php`.
- Seeder: `SettingSeeder`, `AdminSeeder`, `AppSeeder`, `PackageSeeder`, `SubscriberSeeder` (nomor saja). `DemoAccountSeeder` ditunda ke M6 karena butuh service reward.
- `SettingService`.

**Flutter**

- Pasang dependency inti (Riverpod, go_router, dio, secure storage, shared_preferences, intl, uuid). Paket lain di TECH dipasang di milestone yang memakainya: `qr_flutter` + `url_launcher` (M3), `fl_chart` + `workmanager` (M4), `flutter_local_notifications` (M7).
- Struktur folder `app/`, `core/`, `features/`.
- `config.dart`, file `env/web.json`, `env/emulator.json`, `env/device.json`.
- `ApiClient` dengan interceptor, `ApiException`, `format.dart` + unit test-nya.
- `theme.dart` dari design token, `router.dart` dengan layar placeholder.
- `AndroidManifest.xml`: `usesCleartextTraffic`.

**Selesai jika**

- `php artisan migrate:fresh --seed` berjalan tanpa error.
- Feature test: route yang tidak ada mengembalikan format error JSON dengan `code = NOT_FOUND`.
- Aplikasi berjalan di Chrome, emulator, dan HP fisik, dan bisa menjangkau backend (cek dengan request ke endpoint mana pun yang mengembalikan 401).

## M1 Login OTP (FR-1)

**Backend:** `OtpService` (hash, kedaluwarsa 5 menit, jeda kirim ulang 60 detik, kunci 15 menit setelah 5 kali salah, kolom `purpose`), `POST /auth/otp/request`, `POST /auth/otp/verify`, `POST /auth/logout`, rate limit 5/menit per IP, `demo_otp` hanya di `local`.

**Flutter:** layar login dan OTP, banner Mode Demo berisi OTP, hitung mundur kirim ulang, simpan token, redirect saat 401 lalu kembali ke layar asal, logout.

**Selesai jika**

- Feature test: nomor tidak terdaftar (404), terminated (403), OTP salah dengan sisa percobaan, kunci setelah 5 kali salah, OTP kedaluwarsa, kirim ulang terlalu cepat (429), logout mencabut token.
- Login dan logout berhasil di Android dan Chrome memakai nomor seed.

## M2 Beranda dan katalog (FR-2, FR-3.1–3.2, FR-4.1)

**Backend:** `GET /home` (subscriber + paket aktif; `forecast`, `daily_budget`, `recommendation_teaser`, `points`, `alerts` masih `null`/kosong), `PUT /device`, `GET /packages` (tanpa `is_recommended`), `GET /topup-options`. API Resource untuk objek bersama `Subscriber`, `Subscription`, `Package`.

**Flutter:** beranda (pulsa, masa aktif, kartu per paket, kuota aplikasi terpisah, empty state tanpa paket), pull-to-refresh, cache offline + banner, katalog per grup, daftar nominal isi ulang.

**Selesai jika**

- Akun `Uji HP` menampilkan paket BL25. Akun tanpa paket menampilkan empty state.
- Saat Laragon dimatikan, beranda menampilkan cache dengan label "Diperbarui [waktu]".

## M3 Transaksi dan pembayaran (FR-3.4–3.6, FR-4, FR-5, FR-6)

Poin belum dipakai di milestone ini (`points_used` selalu 0). Hold dan release poin ditambahkan di M6.

**Backend**

- `TransactionService`: validasi, idempotensi (`request_hash`), metode pulsa dengan row lock, transaksi `pending` + instruksi bayar.
- `PaymentService`: verifikasi HMAC, log `payment_callbacks`, provisioning paket / pulsa + perpanjangan masa aktif dalam satu transaksi DB.
- `SimulatorController` + 2 view Blade.
- `POST /transactions`, `GET /transactions`, `GET /transactions/{id}`, `POST /payments/callback`.
- Command terjadwal: `transactions:expire`, `subscriptions:expire`, `subscribers:status`.

**Flutter:** checkout (metode bayar, total), isi ulang, layar menunggu bayar (VA, QR, tombol e-wallet, polling 3 detik, refresh saat kembali ke foreground), layar sukses/gagal, tab Riwayat "Pembelian" dan detail transaksi dengan "Lanjutkan bayar". Error `INSUFFICIENT_BALANCE` menampilkan kekurangan dan tombol "Isi ulang".

**Selesai jika**

- Feature test (DoD **Ketahanan pembayaran**): callback ganda, callback setelah `expired` (409), signature salah (401), double-submit dengan key yang sama, key sama body beda, error saat provisioning tidak menyisakan `paid` tanpa paket.
- Feature test: pulsa kurang, beli paket saat masa tenggang (403), perpanjangan masa aktif dihitung dari masa aktif saat ini.
- Beli paket lewat QRIS dan isi ulang lewat VA berhasil dari HP, termasuk membuka simulator.

## M4 Pemakaian per aplikasi (FR-7, FR-8)

**Android native:** plugin lokal `packages/usage_stats` (3 method, lihat TECH), permission di manifest.

**Backend**

- `QuotaService` (urutan potong FR-7.7, status `exhausted`).
- `UsageSyncService` + `POST /usage/sync` (validasi tanggal, delta, aplikasi baru `is_reviewed = false`).
- `UsageProfiles` (Rina, Budi, Acak) + `DemoDataService` + `POST /usage/demo`.
- `GET /usage/summary` (top 5 + Lainnya, harian, lonjakan, insight), `GET /usage/apps/{id}`.

**Flutter:** layar penjelasan izin (FR-7.1), cek dan buka pengaturan Usage Access, sync saat aplikasi dibuka, WorkManager 6 jam, Mode Demo (pilih profil), layar analisis (filter periode, donut, daftar aplikasi dengan ikon lokal, bar harian, insight), detail aplikasi, empty state di web dan saat izin ditolak.

**Selesai jika**

- Feature test: sync ganda tidak memotong kuota dua kali, delta negatif diabaikan, tanggal masa depan ditolak, urutan potong kuota aplikasi → paket paling cepat berakhir, Mode Demo ditolak jika sudah ada data `device`.
- DoD **Data asli Android**: pemakaian dari HP fisik tampil di analisis dengan selisih ≤ 5% dibanding Settings > Penggunaan data. Screenshot berdampingan disimpan.
- Sync latar belakang WorkManager terbukti berjalan (cek `synced_at` setelah aplikasi ditutup; untuk uji, interval bisa dipercepat sementara lewat task one-off).

## M5 Prediksi dan rekomendasi (FR-9, FR-10, FR-3.3)

**Backend**

- `ForecastCalculator` + `ForecastService`, dipanggil setelah sync, setelah pembelian, dan oleh `forecasts:daily` (00:00).
- `RecommendationCalculator` + `RecommendationService`, `GET /recommendations`, `POST /recommendations/{id}/click`.
- Lengkapi `GET /home` (`forecast`, `daily_budget`, `recommendation_teaser`), `is_recommended` di `GET /packages`, `recommendation_id` di `POST /transactions` dan pengisian `purchased_transaction_id` saat `paid`.

**Flutter:** kartu prediksi (Aman/Berisiko, label "perkiraan awal", "Kumpulkan data 3 hari dulu"), kartu jatah harian, garis jatah harian di bar chart, layar rekomendasi (kebutuhan, 1 utama + 2 alternatif, alasan, hemat), teaser di beranda, lencana "Paling hemat untukmu" di katalog.

**Selesai jika**

- Unit test (DoD **Akurasi prediksi**): kelima kasus prediksi dan backtest MAPE ≤ 20% untuk Rina, Budi, Acak (SEED).
- Unit test (DoD **Kebenaran rekomendasi**): keenam kasus rekomendasi di SEED, termasuk properti "rank 1 selalu cukup dan termurah".
- Mode Demo profil Rina menampilkan status Berisiko dan rekomendasi Video 30 Hari.

## M6 Reward dan poin (FR-11, FR-12)

**Backend**

- `PointService`: ledger, FIFO `remaining`, hold, release, expire yang tidak menyentuh hold.
- `RewardEvaluator` + `RewardService` (parameter tanggal, snapshot jatah 00:00), command `rewards:evaluate` dan `points:expire`.
- Tukar poin di `TransactionService` (validasi kelipatan, batas 20%, minimal Rp1.000) + hold; finalisasi di callback `PAID`, release di `FAILED`/`EXPIRED`.
- `GET /points`, `GET /points/ledger`, `points` di `GET /home` dan `GET /packages`.
- `DemoAccountSeeder`: akun Rina, Budi, Dimas, Sari, Andi lengkap sesuai SEED, memakai service yang sudah ada.

**Flutter:** layar Reward (saldo, streak, kalender 30 hari, poin akan kedaluwarsa, riwayat ledger), input tukar poin di checkout dengan batas yang dihitung dari objek `points`.

**Selesai jika**

- Feature test (DoD **Integritas poin**): SUM(`delta`) = saldo yang ditampilkan setelah serangkaian earn/hold/release/expire, hold kembali persis saat transaksi gagal atau kedaluwarsa, poin kedaluwarsa tidak memotong hold.
- `migrate:fresh --seed` menghasilkan nilai di tabel "Hasil yang diharapkan" (SEED). Angka ≈ di dokumen SEED diganti dengan angka sebenarnya.
- DoD **Skenario demo end-to-end** berhasil di Android **dan** Chrome: login Rina → beranda → analisis → prediksi → rekomendasi → beli Video 30 Hari dengan 500 poin via QRIS → kuota bertambah. Rekam layar.

## M7 Peringatan dan notifikasi (FR-13)

**Backend:** `AlertService` (5 pemicu, unik per jenis per hari, `delivered_at`), dipanggil di `GET /home` dan `POST /usage/sync`.

**Flutter:** notifikasi lokal Android (termasuk dari WorkManager), deep link lewat `target`, banner alert di web.

**Selesai jika**

- Feature test: alert yang sama tidak muncul dua kali di hari yang sama, setiap pemicu menghasilkan `kind` yang benar.
- Akun Dimas memunculkan notifikasi `package_expiring` di HP, dan mengetuknya membuka layar yang benar.

## M8 Berbagi kuota (FR-14)

**Backend:** `QuotaTransferService`, `GET /quota-transfers/quote`, `POST /quota-transfers/otp` (OTP `purpose = quota_transfer` dengan `context`), `POST /quota-transfers`, `GET /quota-transfers`, alert `quota_received` dan SMS dummy di log.

**Flutter:** menu Bagi Kuota di beranda, input nomor, pilihan jumlah (opsi nonaktif dengan alasan), ringkasan, OTP, hasil, tab Riwayat "Berbagi".

**Selesai jika**

- Feature test (DoD **Aturan berbagi kuota**): batas 2 GB/30 hari, sisa minimal 2 GB, poin kurang, penerima tidak valid/masa tenggang/diri sendiri, OTP login tidak bisa dipakai untuk transfer, retry dengan key yang sama, kuota pengirim berkurang tepat sebesar yang diterima, masa berlaku penerima mengikuti paket sumber.
- Test konkurensi (`--group=concurrency`): dua transfer bersamaan tidak melanggar batas; dua callback bersamaan tidak memprovisioning dua kali.
- Budi berhasil berbagi 500 MB ke Andi dari HP.

## M9 Panel admin (FR-15)

**Backend:** guard `admin` + panel Filament, rate limit login, resource Package (nonaktif, bukan hapus, jika pernah dibeli), App (kategori, filter "Belum ditinjau"), Transaction + log callback, Subscriber (tanpa pemakaian per aplikasi), QuotaTransfer, Setting (validasi min/max, sembunyikan `is_system`), AdminAuditLog. Observer audit log. Pengisian `catalog.updated_at`. Widget dashboard sesuai Success metrics.

**Selesai jika**

- Feature test: token pelanggan ditolak di `/admin`, setting di luar rentang ditolak, paket yang pernah dibeli tidak bisa dihapus, perubahan admin tercatat di audit log dan log tidak bisa diubah.
- DoD **Panel admin**: ubah harga paket dan poin per hari hemat di panel, lalu perubahannya terlihat di aplikasi Flutter tanpa mengubah kode. Rekam layar.

## M10 Verifikasi dan demo

- DoD **Performa lokal**: ukur p95 latensi API dengan Telescope saat menjalankan skenario demo (≤ 500 ms), dan waktu tampil beranda (≤ 2 detik).
- Jalankan ulang seluruh test backend (`php artisan test` dan `--group=concurrency`) dan test Flutter.
- Centang ulang setiap baris Definition of done dan kumpulkan buktinya (rekaman, screenshot, output test) di `docs/bukti/`.
- `README.md` di root: cara setup dari nol, cara menjalankan, akun demo, dan keterbatasan (dual SIM, HTTP lokal, SQ-1).
- Gladi resik demo dari `migrate:fresh --seed`.

## Risiko

| Risiko | Dampak | Penanganan |
| --- | --- | --- |
| Angka `NetworkStatsManager` berbeda > 5% dari Settings | DoD Data asli Android gagal | Dikerjakan di M4, jauh sebelum akhir. Cek dulu batas hari (zona WIB vs zona HP) dan apakah Settings menghitung siklus tagihan, bukan hari kalender |
| WorkManager tidak berjalan di HP tertentu (optimasi baterai pabrikan) | Sync 6 jam tidak terjadi | Sync saat aplikasi dibuka tetap jalan. Catat sebagai keterbatasan |
| IP laptop berubah saat demo di kampus | HP tidak terhubung ke backend | Ubah `APP_URL` dan `env/device.json`, atau pakai hotspot dari HP sendiri |
| `schedule:work` lupa dinyalakan | Transaksi tidak kedaluwarsa, reward tidak dievaluasi | Masuk checklist alur kerja harian (TECH) dan gladi resik |
