# Desain Teknis Kuota+

Oct 29, 2026 · @Haikal Ahmad El Salman · Draft 1

Keputusan teknis untuk membangun Kuota+. Dokumen ini menjelaskan **bagaimana** kebutuhan di [PRD](PRD-KuotaPlus.md) dibangun, mengikuti kontrak di [API](API-KuotaPlus.md) dan data di [SEED](SEED-KuotaPlus.md). Bagian yang sudah jelas dari framework (cara kerja migration, routing, dsb.) tidak diulang.

## Gambaran sistem

```
┌───────────────────────┐        HTTPS/JSON         ┌─────────────────────────────────────┐
│ Flutter                │  ───────────────────────▶ │ Laravel (Laragon, Apache)            │
│  Android (utama)       │  Bearer token Sanctum     │                                     │
│  Chrome Web            │ ◀───────────────────────  │  /api/*      Controller → Service    │
│                        │                            │  /simulator  Blade (bank/e-wallet)  │
│  Android saja:         │                            │  /admin      Filament               │
│  NetworkStatsManager   │                            │  scheduler   schedule:work          │
│  WorkManager (6 jam)   │                            └──────────────┬──────────────────────┘
│  notifikasi lokal      │                                           │
└───────────────────────┘                                           ▼
                                                              MySQL 8.4

Simulator ──(POST /api/payments/callback, X-Signature HMAC)──▶ Laravel
```

## Lingkungan

| Komponen | Versi | Catatan |
| --- | --- | --- |
| PHP | 8.3.33 (Laragon) | |
| MySQL | 8.4.3 (Laragon) | Database `kuotaplus` dan `kuotaplus_test` |
| Composer | 2.10 | |
| Laravel | Versi stabil terbaru yang mendukung PHP 8.3 | Versi persis dikunci oleh `composer.lock` saat `composer create-project` |
| Filament | Versi stabil terbaru yang kompatibel dengan Laravel di atas | |
| Flutter | 3.47.2 stable | |

## Struktur repositori

Satu repo git di folder induk:

```
KuotaPlus/                 ← root git
├── backend/               ← Laravel + Filament
└── KuotaPlus/             ← Flutter (folder yang sekarang)
    ├── docs/              ← PRD, API, SEED, TECH
    └── packages/usage_stats/   ← plugin lokal Android (lihat bagian Android native)
```

Langkah persiapan:

1. `git init` di `KuotaPlus/` dengan `.gitignore` bawaan masing-masing project (`backend/.env`, `vendor/`, `build/`, `.dart_tool/`).
2. Ganti nama package Flutter dari `dayum` ke `kuota_plus` di `pubspec.yaml` dan import yang ada, sebelum ada kode lain yang bergantung padanya.

## Backend (Laravel)

### Dependency

| Paket | Kegunaan |
| --- | --- |
| `laravel/sanctum` | Token API (FR-1.4) |
| `filament/filament` | Panel admin (FR-15) |
| `laravel/telescope` (dev) | Mengukur latensi p95 untuk DoD. Hanya aktif saat `APP_ENV=local` |

Tidak ada paket lain. QR digambar di Flutter, antrean tidak dipakai (`QUEUE_CONNECTION=sync`), dan HMAC memakai `hash_hmac` bawaan PHP.

### Struktur folder

```
backend/app/
├── Http/
│   ├── Controllers/Api/      ← tipis: validasi → panggil service → kembalikan Resource
│   ├── Controllers/SimulatorController.php
│   ├── Requests/             ← FormRequest per endpoint yang menerima body
│   └── Resources/            ← bentuk JSON, satu per "objek bersama" di API (SubscriptionResource, ForecastResource, ...)
├── Services/                 ← semua logika bisnis + transaksi DB
├── Domain/                   ← kalkulator murni, tanpa DB (mudah di-unit-test)
│   ├── ForecastCalculator.php
│   ├── RecommendationCalculator.php
│   ├── RewardEvaluator.php
│   └── UsageProfiles.php     ← profil Rina/Budi/Acak dari SEED
├── Exceptions/ApiException.php
├── Models/
├── Console/Commands/         ← job terjadwal
└── Filament/                 ← resource & widget admin
```

**Aturan pembagian:** controller tidak berisi logika; service mengurus database, lock, dan transaksi; kelas di `Domain/` hanya menerima array/angka dan mengembalikan hasil. Dengan begitu unit test prediksi dan rekomendasi (DoD) cukup memanggil kelas `Domain` tanpa database, dan seeder, Mode Demo, serta test memakai `UsageProfiles` yang sama.

### Service

| Service | Tanggung jawab | FR |
| --- | --- | --- |
| `SettingService` | Membaca `settings` dari cache. Cache dihapus saat admin menyimpan | FR-15.10 |
| `OtpService` | Membuat, mengirim (log), memverifikasi, dan mengunci OTP. Dipakai login dan berbagi kuota (`purpose`) | FR-1, FR-14.10 |
| `QuotaService` | Memotong kuota sesuai urutan FR-7.7, mengubah status `exhausted`/`expired` | FR-7.7 |
| `UsageSyncService` | Upsert `usage_records`, menghitung delta, memanggil `QuotaService`, lalu forecast dan alert | FR-7 |
| `DemoDataService` | Mengisi data demo dari `UsageProfiles` | FR-7.8 |
| `ForecastService` | Mengumpulkan data → `ForecastCalculator` → simpan `forecasts` | FR-9 |
| `RecommendationService` | Mengumpulkan data → `RecommendationCalculator` → simpan batch `recommendations` | FR-10 |
| `PointService` | Ledger: earn, hold, release, spend, expire FIFO. Satu-satunya kelas yang menulis `point_ledger` | FR-11, FR-12 |
| `RewardService` | Evaluasi harian per pengguna memakai `RewardEvaluator` + `PointService`. Menerima parameter tanggal, sehingga bisa dipakai seeder | FR-11 |
| `TransactionService` | Membuat transaksi, idempotensi, potong pulsa, hold poin | FR-3, FR-4, FR-5 |
| `PaymentService` | Memverifikasi signature, memproses callback, provisioning, kedaluwarsa | FR-5 |
| `QuotaTransferService` | Quote, cek aturan, eksekusi berbagi kuota | FR-14 |
| `AlertService` | Mengevaluasi pemicu FR-13 dan menulis `notifications` (unik per jenis per hari) | FR-13 |

### Format error

Satu kelas `ApiException(httpStatus, code, message, meta)`. Di `bootstrap/app.php` (`withExceptions`):

- `ApiException` → JSON sesuai format error di API.
- `ValidationException` → 422 dengan `code = VALIDATION_FAILED` (field `errors` bawaan Laravel tetap ada).
- `AuthenticationException` → 401 `UNAUTHENTICATED`.
- `ModelNotFoundException` → 404 `NOT_FOUND`.
- `ThrottleRequestsException` → 429 `TOO_MANY_REQUESTS`.
- Exception lain → 500 `SERVER_ERROR` tanpa detail (detail hanya di log).

### Waktu

- `config/app.php`: `timezone = Asia/Jakarta`. Koneksi MySQL: `'timezone' => '+07:00'`.
- Semua tanggal "hari" dihitung dari waktu server, tidak pernah dari jam perangkat (edge case manipulasi jam).
- `Carbon::setTestNow()` dipakai di test dan di seeder untuk memutar ulang hari.

### Konkurensi dan transaksi DB

Semua perubahan pulsa, kuota, dan poin terjadi di dalam `DB::transaction()` dengan **baris `users` milik pengguna sebagai kunci per pengguna** (`lockForUpdate`). Poin tidak punya kolom saldo yang bisa dikunci, jadi mengunci baris `users` adalah cara paling sederhana agar dua operasi milik pengguna yang sama tidak berjalan bersamaan.

Urutan kunci selalu sama untuk mencegah deadlock: **`transactions` → `users` → `subscriptions`**.

| Operasi | Yang dikunci | Isi transaksi DB |
| --- | --- | --- |
| Buat transaksi (pulsa) | `users`, `subscribers` | Cek saldo, potong pulsa, hold poin, buat paket |
| Buat transaksi (non-pulsa) | `users` | Hold poin, buat transaksi `pending` |
| Callback `PAID` | `transactions`, `users` | Cek status masih `pending`, provisioning, finalkan hold |
| Callback `FAILED` / kedaluwarsa | `transactions`, `users` | Ubah status, `redeem_release` |
| Sync pemakaian | `users`, `subscriptions` aktif | Upsert usage, potong kuota |
| Berbagi kuota | `users` pengirim, `subscriptions` pengirim | Cek ulang aturan, potong kuota + poin, buat paket penerima |
| Evaluasi harian | `users` | Tulis evaluasi + ledger |

### Idempotensi

Ditangani di `TransactionService` dan `QuotaTransferService`, bukan middleware, karena hanya dua endpoint yang membutuhkannya.

1. Hitung `request_hash` = SHA-256 dari body yang sudah dinormalkan.
2. Cari baris dengan (`user_id`, `idempotency_key`) dalam 24 jam. Jika ada: hash sama → kembalikan baris itu (200), hash beda → `IDEMPOTENCY_KEY_MISMATCH`.
3. Jika tidak ada, buat baris baru. Unique index (`user_id`, `idempotency_key`) menangani dua request yang tiba bersamaan: request yang kalah menangkap error duplicate key lalu mengulang langkah 2.

### Pembayaran dan simulator

- `external_ref` = `KP-{YYYYMMDD}-{6 karakter acak}`.
- Halaman simulator (Blade) memanggil `POST /api/payments/callback` lewat `Http::post(config('app.url') ...)` dengan signature `hash_hmac('sha256', $rawBody, env('PAYMENT_WEBHOOK_SECRET'))`. Callback sengaja lewat HTTP sungguhan supaya verifikasi signature dan idempotensi callback benar-benar diuji.
- Karena simulator memanggil server yang sama, backend **harus** dijalankan lewat Apache Laragon, bukan `php artisan serve`. `artisan serve` hanya melayani satu request sekaligus sehingga panggilan ke dirinya sendiri akan macet.
- Verifikasi memakai `hash_equals`.

### Job terjadwal

Windows tidak punya cron. Selama pengembangan dan demo, jalankan `php artisan schedule:work` di terminal terpisah.

| Jadwal (WIB) | Command | FR |
| --- | --- | --- |
| Setiap menit | `transactions:expire` — `pending` lewat `expires_at` → `expired` + release poin | FR-5.8 |
| Setiap menit | `subscriptions:expire` — paket lewat `expires_at` → `expired`, catat sisa hangus | Edge case |
| 00:00 | `forecasts:daily` — hitung ulang jatah harian dan simpan snapshot untuk evaluasi | FR-9.5 |
| 00:01 | `subscribers:status` — `active` → `grace` → `terminated`, cabut token pengguna yang terminated | Edge case |
| 00:05 | `rewards:evaluate` — evaluasi hari kemarin | FR-11.1 |
| 00:10 | `points:expire` — catat poin kedaluwarsa (FIFO, tidak menyentuh poin yang di-hold) | FR-11.6 |

Setiap command dibuat aman jika dijalankan dua kali (cek baris unik sebelum menulis), karena `schedule:work` yang terlambat dinyalakan bisa melewatkan atau menumpuk jadwal.

Alert FR-13 tidak punya job sendiri. `AlertService` dipanggil di akhir `GET /home` dan `POST /usage/sync`. Batas 1 per jenis per hari dijaga oleh unique index di `notifications`.

### Panel admin (Filament)

- Guard `admin` dengan provider tabel `admins`. Panel Filament memakai guard ini, sehingga token Sanctum pelanggan tidak berlaku di `/admin`.
- Resource: Package, App, Transaction (read-only), Subscriber (read-only), QuotaTransfer (read-only), Setting, AdminAuditLog (read-only).
- **Audit log:** satu observer yang dipasang pada model yang bisa diubah admin (Package, App, Setting). Observer menulis `admin_audit_logs` hanya jika `auth('admin')->check()`, sehingga seeder dan aplikasi tidak ikut tercatat.
- **Privasi (FR-15.8):** resource Subscriber tidak punya relasi ke `usage_records` per aplikasi. Statistik per aplikasi hanya muncul di widget dashboard sebagai agregat.
- `catalog_updated_at` disimpan di `settings` dengan key `catalog.updated_at`. Key ini ditandai `is_system` dan disembunyikan dari form pengaturan.

### Akses dari HP dan web

- Vhost Kuota+ ada di `C:\laragon\etc\apache2\sites-enabled\0-kuotaplus.conf`. Nama berawalan `0-` membuatnya urut sebelum `00-default.conf` milik Laragon, sehingga menjadi server default untuk `localhost` dan IP LAN.
- Apache Laragon mendengarkan di `0.0.0.0:80` secara bawaan. Izinkan port 80 di Windows Firewall untuk jaringan privat.
- `APP_URL` diisi IP LAN laptop (misalnya `http://192.168.1.5`), karena URL simulator yang dikirim ke HP dibentuk dari `APP_URL`.
- `config/cors.php`: `allowed_origins` = `http://localhost:5000`. Flutter Web selalu dijalankan dengan `--web-port 5000`.
- Jika IP laptop berubah (ganti Wi-Fi), yang perlu diubah hanya `APP_URL` di `.env` dan file define Flutter.

### Test

| Jenis | Lokasi | Database | Cakupan |
| --- | --- | --- | --- |
| Unit | `tests/Unit/Domain` | Tanpa DB | `ForecastCalculator`, `RecommendationCalculator`, `RewardEvaluator`, backtest MAPE. Dataset dari SEED |
| Feature | `tests/Feature` | MySQL `kuotaplus_test` (`RefreshDatabase`) | Semua endpoint, idempotensi, callback (ganda, kedaluwarsa, signature salah), integritas poin, aturan berbagi kuota |
| Konkurensi | `tests/Concurrency` (grup `concurrency`) | MySQL lokal + Laragon berjalan | Dua request berbagi kuota dan dua callback bersamaan lewat `Http::pool` ke server sungguhan |

Feature test memakai MySQL, bukan SQLite, karena SQLite tidak mendukung `lockForUpdate`. Tes konkurensi dipisah ke grup sendiri karena butuh server yang berjalan: `php artisan test --group=concurrency`.

## Flutter

### Dependency

| Paket | Kegunaan |
| --- | --- |
| `flutter_riverpod` | State management (OQ-13) |
| `go_router` | Routing, redirect login, deep link dari notifikasi |
| `dio` | HTTP client + interceptor |
| `flutter_secure_storage` | Token (Android: Keystore; web: storage browser) |
| `shared_preferences` | Cache respons `/home` |
| `fl_chart` | Donut dan bar chart (OQ-13) |
| `qr_flutter` | Menggambar QRIS dari `qr_string` |
| `url_launcher` | Membuka simulator (Custom Tabs di Android, tab baru di web) |
| `workmanager` | Sync 6 jam di Android |
| `flutter_local_notifications` | Notifikasi lokal Android |
| `uuid` | `Idempotency-Key` |
| `intl` | Format rupiah dan tanggal |
| `usage_stats` (path, lokal) | Plugin Android untuk NetworkStatsManager |

Model ditulis manual dengan `factory fromJson`, tanpa code generation.

### Struktur folder

```
lib/
├── main.dart
├── app/
│   ├── router.dart          ← semua route + redirect auth
│   └── theme.dart
├── core/
│   ├── config.dart          ← API_BASE_URL dari --dart-define
│   ├── api_client.dart      ← Dio + interceptor
│   ├── api_exception.dart   ← code, message, meta, status
│   ├── format.dart          ← byte → MB/GB, rupiah, tanggal WIB
│   └── platform.dart        ← isAndroid / kIsWeb di satu tempat
└── features/
    ├── auth/        (login, OTP)
    ├── home/        (beranda, cache offline, alert)
    ├── packages/    (katalog, checkout)
    ├── topup/
    ├── payment/     (layar menunggu bayar, polling)
    ├── history/     (tab Pembelian + Berbagi)
    ├── usage/       (izin, sync, Mode Demo, analisis)
    ├── recommendations/
    ├── rewards/
    └── share/       (berbagi kuota)
```

Setiap fitur berisi `data/` (model + repository yang memanggil `ApiClient`), `ui/` (layar dan widget), dan `providers.dart`. Objek bersama dari API (`Subscription`, `Package`, `Forecast`, `Alert`, `Transaction`) diletakkan di `core/models/` karena dipakai banyak fitur.

### State (Riverpod)

- Tanpa code generation, konsisten dengan model manual.
- Data layar: `FutureProvider` / `AsyncNotifierProvider` per layar. Pull-to-refresh = `ref.invalidate`.
- Aksi tulis (beli, isi ulang, berbagi): `AsyncNotifier` yang menyimpan `Idempotency-Key` di state-nya. Key dibuat saat tombol konfirmasi pertama kali ditekan dan dipakai ulang untuk setiap retry, lalu dibuang saat hasilnya final.
- Setelah aksi tulis berhasil, invalidate provider yang terdampak (`home`, `points`, `transactions`).

### API client

Interceptor `dio` berurutan:

1. Tambah `Accept: application/json` dan `Authorization: Bearer` jika ada token.
2. Respons error → ubah menjadi `ApiException` dari field `code`, `message`, `meta`. Error jaringan → `ApiException(code: 'NETWORK')`.
3. 401 `UNAUTHENTICATED` → hapus token, lalu router mengarah ke `/login?from=<route asal>`.

Satu provider `serverReachableProvider` diperbarui oleh interceptor (true saat ada respons, false saat error jaringan). Tombol beli dan isi ulang membaca provider ini untuk menonaktifkan diri saat offline.

### Cache offline

Hanya respons `GET /home` yang di-cache (FR-2.5): JSON mentah + waktu diterima, disimpan di `shared_preferences`. Saat gagal terhubung, beranda menampilkan cache dengan banner "Tidak bisa terhubung ke server" dan label "Diperbarui [waktu]". Layar lain menampilkan state error dengan tombol coba lagi.

### Waktu dan format

- API mengirim waktu dengan offset `+07:00`. `DateTime.parse` mengubahnya ke UTC. Untuk tampilan, `format.dart` menambahkan 7 jam ke nilai UTC lalu memformatnya, sehingga tampilan selalu WIB walau zona waktu perangkat berbeda.
- Byte ditampilkan dalam MB jika < 1 GB, selain itu GB dengan 1 desimal. 1 GB = 1024 MB.
- Rupiah: `NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0)`.

### Konfigurasi lingkungan

Memakai `--dart-define-from-file` dengan tiga file di `env/` (masuk git, tidak berisi rahasia):

| File | `API_BASE_URL` | Perintah |
| --- | --- | --- |
| `env/web.json` | `http://localhost` | `flutter run -d chrome --web-port 5000 --dart-define-from-file=env/web.json` |
| `env/emulator.json` | `http://10.0.2.2` | `flutter run --dart-define-from-file=env/emulator.json` |
| `env/device.json` | `http://192.168.x.x` (IP laptop) | `flutter run --dart-define-from-file=env/device.json` |

Android butuh `android:usesCleartextTraffic="true"` karena backend lokal memakai HTTP.

`android/gradle.properties` berisi `kotlin.incremental=false`: project di drive D: dan pub cache di drive C: membuat cache inkremental Kotlin gagal ditutup di Windows. Build Flutter dengan plugin juga butuh Developer Mode Windows aktif (symlink).

### Pembayaran di client

1. Checkout → `POST /transactions`.
2. Metode pulsa: langsung ke layar sukses.
3. Non-pulsa: buka layar menunggu, tampilkan instruksi (nomor VA, QR, atau tombol buka e-wallet), dan buka `simulator_url` lewat `url_launcher`.
4. Layar menunggu melakukan polling `GET /transactions/{id}` tiap 3 detik dengan `Timer.periodic`, dan sekali lagi saat aplikasi kembali ke foreground (`AppLifecycleListener`). Timer dihentikan saat status final atau layar ditutup.

### Notifikasi dan deep link

- Android: setiap `Alert` dari `/home` atau `/usage/sync` ditampilkan lewat `flutter_local_notifications` dengan payload `target`. Saat diketuk, `go_router` membuka `target`.
- Web: alert ditampilkan sebagai banner di beranda.

## Android native

### Plugin lokal `usage_stats`

Pembacaan NetworkStatsManager dibuat sebagai **plugin Flutter lokal** (`packages/usage_stats`, dipasang lewat `path:` di `pubspec.yaml`), bukan `MethodChannel` di `MainActivity`.

Alasannya: WorkManager menjalankan sync latar belakang di Flutter engine terpisah tanpa `MainActivity`. Channel yang didaftarkan di `MainActivity` tidak tersedia di engine itu, sehingga sync 6 jam akan selalu gagal. Plugin didaftarkan otomatis di setiap engine, termasuk engine latar belakang.

Method channel `kuotaplus/usage_stats`:

| Method | Hasil |
| --- | --- |
| `hasUsageAccess()` | `bool`, dari `AppOpsManager.unsafeCheckOpNoThrow(OPSTR_GET_USAGE_STATS, …)` |
| `openUsageAccessSettings()` | Membuka `Settings.ACTION_USAGE_ACCESS_SETTINGS` |
| `queryDailyMobileUsage(days: 7)` | Daftar bucket `{usage_date, package_name, label, bytes_mobile}`, sama dengan body `POST /usage/sync` |

Implementasi `queryDailyMobileUsage`:

1. Untuk setiap hari, ambil rentang 00:00–24:00 **zona Asia/Jakarta** (bukan zona perangkat), supaya batas hari sama dengan server.
2. `NetworkStatsManager.querySummary(ConnectivityManager.TYPE_MOBILE, null, start, end)`. `subscriberId = null` wajib di Android 10+.
3. Jumlahkan `rxBytes + txBytes` per UID.
4. Petakan UID:
   - `NetworkStats.Bucket.UID_REMOVED` → `android.removed`
   - `NetworkStats.Bucket.UID_TETHERING` → `android.tethering`
   - UID < `Process.FIRST_APPLICATION_UID` → `android.system`
   - selainnya → `packageManager.getPackagesForUid(uid)[0]`, label dari `getApplicationLabel`. Jika tidak ditemukan → `android.removed`.
5. Hari ini ikut dikirim (nilainya kumulatif sampai saat ini). Server yang menghitung delta.

Manifest: `<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS" tools:ignore="ProtectedPermissions" />`.

Manifest plugin juga meminta `QUERY_ALL_PACKAGES`. Tanpa izin ini, Android 11+ menyembunyikan aplikasi lain dari `getPackagesForUid()` sehingga semua pemakaian terbaca sebagai "Aplikasi terhapus". Izin ini butuh justifikasi khusus jika aplikasi dirilis ke Play Store; untuk prototipe tidak masalah.

### Alur sinkronisasi

1. Aplikasi dibuka (Android) → `PUT /device` dengan status izin.
2. Izin ada → `queryDailyMobileUsage(7)` → `POST /usage/sync` → tampilkan alert.
3. WorkManager periodic task 6 jam menjalankan langkah 2 di latar belakang. Task ini membaca token dari `flutter_secure_storage` dan membuat `ApiClient` sendiri (provider Riverpod tidak tersedia di engine latar belakang).
4. Izin tidak ada → tidak ada sync. Layar analisis menampilkan empty state dengan tombol "Beri izin" dan "Pakai Mode Demo".

## Alur kerja harian

```
1. Start Laragon (Apache + MySQL)
2. cd backend && php artisan schedule:work        ← terminal terpisah, biarkan berjalan
3. php artisan migrate:fresh --seed               ← reset data demo bila perlu
4. cd KuotaPlus && flutter run --dart-define-from-file=env/<target>.json
```

## Perubahan data model dari PRD

| Tabel | Perubahan | Alasan |
| --- | --- | --- |
| `quota_transfers` | Tambah `request_hash` | Mendeteksi `IDEMPOTENCY_KEY_MISMATCH`, sama seperti `transactions` |
| `apps` | Tambah `is_reviewed` (bool) | Penanda "Belum ditinjau" untuk aplikasi baru dari sync (FR-15.4) |
| `settings` | Tambah `is_system` (bool) | Key internal seperti `catalog.updated_at` tidak tampil di form admin |

## Pertanyaan terbuka

| ID | Pertanyaan | Usulan default |
| --- | --- | --- |
| TQ-1 | Apakah perlu HTTPS untuk demo? | Tidak. HTTP lokal + `usesCleartextTraffic`. Token Sanctum tetap aman di jaringan rumah/kampus untuk keperluan prototipe, dan ini dicatat sebagai keterbatasan |
| TQ-2 | Apakah test Flutter wajib? | Hanya unit test kecil untuk `format.dart` dan `fromJson` objek bersama. DoD tidak mensyaratkan test Flutter |
