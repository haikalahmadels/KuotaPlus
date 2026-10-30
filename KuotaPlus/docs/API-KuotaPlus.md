# Spesifikasi API Kuota+

Oct 29, 2026 · @Haikal Ahmad El Salman · Draft 1

Kontrak REST antara aplikasi Flutter (Android + Chrome Web) dan backend Laravel. Sumber kebutuhan: [PRD-KuotaPlus.md](PRD-KuotaPlus.md). Setiap endpoint mencantumkan FR yang menjadi dasarnya. Jika dokumen ini bertentangan dengan PRD, PRD yang berlaku dan dokumen ini yang diperbaiki.

## Konvensi umum

| Aspek | Aturan |
| --- | --- |
| Base URL | `{API_BASE_URL}/api`. Diisi lewat `--dart-define=API_BASE_URL=http://192.168.x.x` (HP fisik) atau `http://localhost` (web/emulator: `http://10.0.2.2`) |
| Versi | Tidak ada prefix versi. Prototipe hanya punya satu client |
| Format | JSON, UTF-8. Header `Accept: application/json` wajib dikirim agar Laravel selalu membalas JSON |
| Auth | `Authorization: Bearer {token}` (Laravel Sanctum). Semua endpoint wajib token kecuali yang ditandai **publik** |
| Waktu | Timestamp ISO 8601 dengan offset WIB, contoh `2026-10-29T14:05:00+07:00`. Tanggal tanpa jam memakai `YYYY-MM-DD` (hari WIB) |
| Kuota | Integer byte. Client yang mengubah ke MB/GB (1 GB = 1024 MB) |
| Uang | Integer rupiah, tanpa desimal |
| Nomor HP | Input boleh `08…`, `628…`, atau `+628…`. Server menormalkan ke `628…`. Nomor milik orang lain selalu dikirim dalam bentuk tersamar, contoh `0812••••7890` |
| Bungkus respons | Sukses: `{ "data": … }` (format default Laravel API Resource). Daftar berhalaman menambahkan `links` dan `meta` dari paginator Laravel, 20 item per halaman, parameter `?page=` |
| Rate limit | Default 60 request/menit per token. Batas khusus disebut di endpoint |

### Format error

Mengikuti format bawaan Laravel, ditambah field `code` yang stabil supaya client tidak bergantung pada teks pesan.

```json
{
  "message": "Pulsa tidak cukup. Kurang Rp7.000.",
  "code": "INSUFFICIENT_BALANCE",
  "errors": { "payment_method": ["Pulsa tidak cukup."] },
  "meta": { "shortfall": 7000 }
}
```

- `message`: teks yang siap ditampilkan ke pengguna (bahasa Indonesia).
- `code`: dipakai client untuk memilih aksi (tombol "Isi ulang", redirect login, dll).
- `errors`: hanya ada pada error validasi per field (422).
- `meta`: data tambahan yang dibutuhkan UI, opsional.

| HTTP | Arti | Contoh `code` |
| --- | --- | --- |
| 400 | Request tidak lengkap secara protokol | `IDEMPOTENCY_KEY_REQUIRED` |
| 401 | Token tidak ada, kedaluwarsa, atau dicabut. Client menghapus token dan membuka login, lalu kembali ke layar asal | `UNAUTHENTICATED`, `INVALID_SIGNATURE` (khusus callback) |
| 403 | Diizinkan login, tetapi aksi dilarang oleh status kartu | `SUBSCRIBER_IN_GRACE`, `SUBSCRIBER_TERMINATED` |
| 404 | Data tidak ada atau bukan milik pengguna ini | `NOT_FOUND`, `NOT_SUBSCRIBER` |
| 409 | Bentrok dengan state saat ini | `TRANSACTION_EXPIRED`, `DEVICE_DATA_EXISTS` |
| 422 | Validasi atau aturan bisnis gagal | `VALIDATION_FAILED`, `INSUFFICIENT_BALANCE`, `OTP_INVALID` |
| 423 | Nomor dikunci sementara | `OTP_LOCKED` |
| 429 | Terlalu sering | `OTP_RESEND_TOO_SOON`, `TOO_MANY_REQUESTS` |
| 500 | Error server. Tidak ada perubahan data (transaksi DB di-rollback) | `SERVER_ERROR` |

Daftar lengkap `code` ada di [Lampiran A](#lampiran-a-daftar-kode-error).

### Idempotensi

Endpoint yang membuat uang, kuota, atau poin berpindah (`POST /transactions`, `POST /quota-transfers`) wajib membawa header `Idempotency-Key: {UUID v4}`.

- Client membuat key **sekali** saat pengguna menekan tombol konfirmasi, lalu memakai key yang sama untuk semua retry permintaan itu.
- Key berlaku 24 jam per pengguna. Key yang sama dengan body yang sama mengembalikan objek yang sudah dibuat dengan status 200 (bukan 201).
- Key yang sama dengan body berbeda ditolak `422 IDEMPOTENCY_KEY_MISMATCH`.
- Header tidak ada: `400 IDEMPOTENCY_KEY_REQUIRED`.

## Ringkasan endpoint

| Method | Path | Auth | FR | Kegunaan |
| --- | --- | --- | --- | --- |
| POST | `/auth/otp/request` | publik | FR-1 | Minta OTP login |
| POST | `/auth/otp/verify` | publik | FR-1 | Verifikasi OTP, dapat token |
| POST | `/auth/logout` | token | FR-1 | Cabut token |
| GET | `/home` | token | FR-2, FR-9, FR-13 | Data beranda |
| PUT | `/device` | token | FR-7, FR-15.2 | Laporkan platform dan status izin Usage Access |
| GET | `/packages` | token | FR-3, FR-12 | Katalog paket |
| GET | `/topup-options` | token | FR-4 | Nominal isi ulang + tambahan masa aktif |
| POST | `/transactions` | token | FR-3, FR-4, FR-5, FR-12 | Buat transaksi beli paket / isi ulang |
| GET | `/transactions` | token | FR-6 | Riwayat transaksi |
| GET | `/transactions/{id}` | token | FR-5, FR-6 | Detail + polling status |
| POST | `/payments/callback` | publik, HMAC | FR-5 | Callback dari simulator pembayaran |
| POST | `/usage/sync` | token | FR-7 | Kirim pemakaian per aplikasi dari Android |
| POST | `/usage/demo` | token | FR-7.8 | Generate data demo 30 hari |
| GET | `/usage/summary` | token | FR-8 | Analisis per periode |
| GET | `/usage/apps/{app_id}` | token | FR-8.4 | Detail pemakaian satu aplikasi |
| GET | `/recommendations` | token | FR-10 | Rekomendasi paket hemat |
| POST | `/recommendations/{id}/click` | token | FR-10.8 | Catat klik rekomendasi |
| GET | `/points` | token | FR-11 | Saldo, streak, kalender |
| GET | `/points/ledger` | token | FR-11.7 | Riwayat mutasi poin |
| GET | `/quota-transfers/quote` | token | FR-14.2–8 | Cek penerima + pilihan jumlah |
| POST | `/quota-transfers/otp` | token | FR-14.10 | Minta OTP konfirmasi berbagi |
| POST | `/quota-transfers` | token | FR-14.11 | Eksekusi berbagi kuota |
| GET | `/quota-transfers` | token | FR-14.13 | Riwayat berbagi (sebagai pengirim) |

Route web (bukan API, tidak memakai prefix `/api`):

| Method | Path | Kegunaan |
| --- | --- | --- |
| GET | `/simulator/{external_ref}` | Halaman simulator bank/e-wallet (FR-5.4) |
| POST | `/simulator/{external_ref}/pay` | Tombol "Bayar": server mengirim callback `PAID` |
| POST | `/simulator/{external_ref}/reject` | Tombol "Tolak": server mengirim callback `FAILED` |
| — | `/admin/*` | Panel Filament (FR-15). Tidak dibahas di dokumen ini |

## Objek bersama

Objek ini dipakai ulang di beberapa respons. Di bagian endpoint cukup disebut namanya.

### `Subscriber`

```json
{
  "msisdn": "6281234567890",
  "pulsa_balance": 12500,
  "status": "active",
  "active_until": "2026-11-20",
  "days_left": 22,
  "grace_until": null
}
```

`status`: `active` | `grace`. `grace_until` terisi saat `status = grace`. Pengguna `terminated` tidak bisa memanggil API apa pun (tokennya dicabut).

### `Subscription` (paket milik pengguna)

```json
{
  "id": 41,
  "source": "purchase",
  "name": "Bulanan 15 GB",
  "main_total": 16106127360,
  "main_used": 5368709120,
  "main_remaining": 10737418240,
  "app_total": 0,
  "app_used": 0,
  "app_remaining": 0,
  "app_category": null,
  "started_at": "2026-10-10T09:12:00+07:00",
  "expires_at": "2026-11-09T23:59:59+07:00",
  "status": "active",
  "shared_from": null
}
```

- `source`: `purchase` | `shared`. Untuk `shared`, `name` = "Kuota dari 0812••••7890" dan `shared_from` berisi nomor tersamar pengirim.
- `app_category`: `video` | `sosmed` | `game` | `belajar` | `null`.
- `status`: `active` | `exhausted` | `expired`.

### `Package` (item katalog)

```json
{
  "id": 7,
  "code": "VID30",
  "name": "Video 30 Hari",
  "type": "aplikasi",
  "price": 65000,
  "main_quota": 6442450944,
  "app_quota": 10737418240,
  "app_category": "video",
  "app_examples": ["YouTube", "TikTok", "Netflix"],
  "validity_days": 30,
  "is_recommended": true
}
```

`type`: `harian` | `mingguan` | `bulanan` | `aplikasi`. `app_examples` diambil dari tabel `apps` dengan kategori yang sama (maksimal 5). `is_recommended` = paket ini adalah rekomendasi utama terbaru untuk pengguna (FR-3.3).

### `Forecast`

```json
{
  "confidence": "high",
  "status": "risk",
  "avg_daily_bytes": 524288000,
  "remaining_bytes": 3221225472,
  "predicted_empty_at": "2026-11-03T18:00:00+07:00",
  "main_expires_at": "2026-11-09T23:59:59+07:00",
  "days_early": 6,
  "computed_at": "2026-10-29T14:05:00+07:00"
}
```

- `confidence`: `high` (≥ 7 hari data) | `low` (3–6 hari, client menampilkan label "perkiraan awal") | `none` (< 3 hari; field lain bernilai `null`, client menampilkan "Kumpulkan data 3 hari dulu").
- `status`: `safe` | `risk`. `days_early` hanya terisi saat `risk`.
- `avg_daily_bytes = 0`: `predicted_empty_at = null`, `status = safe`, client menampilkan "Kuota aman sampai paket berakhir".

### `Alert`

Peringatan yang sudah lolos aturan 1 per jenis per hari (tabel `notifications`). Android menampilkannya sebagai notifikasi lokal, web sebagai banner.

```json
{
  "id": 310,
  "kind": "forecast_risk",
  "title": "Kuota diprediksi habis lebih cepat",
  "body": "Kuotamu diperkirakan habis 3 Nov, 6 hari sebelum paket berakhir.",
  "target": "/usage",
  "created_at": "2026-10-29T14:05:00+07:00"
}
```

`kind`: `quota_low` | `forecast_risk` | `package_expiring` | `card_expiring` | `transaction_status` | `quota_received`. `target` adalah route Flutter untuk deep link (FR-13.3).

| `kind` | Pemicu (FR-13.1) | `target` |
| --- | --- | --- |
| `quota_low` | Sisa kuota utama semua paket ≤ 20% | `/recommendations` |
| `forecast_risk` | Prediksi berubah menjadi Berisiko. Sekali per episode berisiko: tidak diulang selama prediksi tetap berisiko | `/usage` |
| `package_expiring` | Paket berakhir ≤ 1 hari lagi | `/packages` |
| `card_expiring` | Nomor `active` dengan masa aktif ≤ 3 hari | `/topup` |
| `transaction_status` | Transaksi non-pulsa menjadi `paid`/`failed`/`expired` hari ini (pulsa langsung selesai, jadi tidak berubah status) | `/history/{id}` |
| `quota_received` | Menerima kuota dari pengguna lain (M8) | `/home` |

### `Transaction`

```json
{
  "id": 118,
  "type": "package",
  "item_name": "Video 30 Hari",
  "package_id": 7,
  "topup_amount": null,
  "gross_amount": 65000,
  "discount_amount": 5000,
  "points_used": 500,
  "net_amount": 60000,
  "payment_method": "va",
  "status": "pending",
  "external_ref": "KP-20261029-8F3K2Q",
  "payment": {
    "va_number": "8808123456789012",
    "bank_label": "Bank A",
    "qr_string": null,
    "simulator_url": "http://192.168.1.5/simulator/KP-20261029-8F3K2Q"
  },
  "expires_at": "2026-10-29T14:20:00+07:00",
  "paid_at": null,
  "created_at": "2026-10-29T14:05:00+07:00"
}
```

- `type`: `package` | `topup`.
- `payment_method`: `pulsa` | `ewallet` | `va` | `qris`. Label tampilan generik (OQ-5): "Pulsa", "E-Wallet", "Virtual Account", "QRIS".
- `status`: `pending` | `paid` | `failed` | `expired`.
- `payment`: `null` untuk metode `pulsa`. `va_number` dan `bank_label` hanya terisi untuk `va`. `qr_string` hanya terisi untuk `qris`; client menggambar QR dari string ini (paket `qr_flutter`). `simulator_url` terisi untuk semua metode non-pulsa dan dibuka di in-app browser.

## Endpoint

### Auth (FR-1)

#### `POST /auth/otp/request` (publik)

Rate limit: 5 request/menit per IP.

Request:

```json
{ "msisdn": "081234567890" }
```

Respons `200`:

```json
{
  "data": {
    "msisdn": "6281234567890",
    "expires_at": "2026-10-29T14:10:00+07:00",
    "resend_available_at": "2026-10-29T14:06:00+07:00",
    "demo_otp": "482913"
  }
}
```

`demo_otp` hanya dikirim saat `APP_ENV=local`. Client menampilkannya di banner "Mode Demo" (FR-1.3). Di env lain field ini tidak ada.

Error: `404 NOT_SUBSCRIBER` ("Nomor bukan pelanggan Nusantel"), `403 SUBSCRIBER_TERMINATED`, `429 OTP_RESEND_TOO_SOON` (`meta.retry_after` dalam detik), `423 OTP_LOCKED` (`meta.locked_until`).

#### `POST /auth/otp/verify` (publik)

Request:

```json
{ "msisdn": "081234567890", "code": "482913", "device_name": "android-pixel7" }
```

Respons `200`. Akun `users` dibuat otomatis pada login pertama.

```json
{
  "data": {
    "token": "12|q8Zx…",
    "user": { "id": 3, "name": null, "msisdn": "6281234567890" }
  }
}
```

Error: `422 OTP_INVALID` (`meta.attempts_left`), `422 OTP_EXPIRED`, `423 OTP_LOCKED` (salah ke-5 mengunci 15 menit).

#### `POST /auth/logout`

Mencabut token yang sedang dipakai. Respons `204`.

### Beranda (FR-2, FR-9, FR-13)

#### `GET /home`

Satu panggilan untuk seluruh beranda. Client menyimpan respons terakhir sebagai cache offline dan menampilkan `server_time` sebagai "Diperbarui [waktu]".

```json
{
  "data": {
    "server_time": "2026-10-29T14:05:00+07:00",
    "subscriber": { "…": "Subscriber" },
    "subscriptions": [ { "…": "Subscription, status active atau exhausted yang belum berakhir" } ],
    "forecast": { "…": "Forecast" },
    "daily_budget": {
      "budget_bytes": 412090368,
      "used_today_bytes": 157286400
    },
    "recommendation_teaser": {
      "recommendation_id": 88,
      "package_name": "Bulanan 12 GB",
      "saving_30d": 35000
    },
    "points": { "balance": 340, "streak": 4 },
    "usage": {
      "source": "device",
      "last_synced_at": "2026-10-29T08:00:00+07:00"
    },
    "alerts": [ { "…": "Alert" } ]
  }
}
```

- `subscriptions`: paket yang belum berakhir, termasuk yang kuotanya habis (`exhausted`, ditampilkan "Kuota habis"), terurut dari yang paling cepat berakhir. Kosong: client menampilkan "Kamu tidak punya kuota aktif" (FR-2.6). `forecast` dan `daily_budget` bernilai `null`.
- `recommendation_teaser`: `null` jika tidak ada rekomendasi atau `saving_30d` ≤ 0.
- `usage.source`: `device` | `demo` | `null` (belum ada data). `last_synced_at` dipakai untuk banner "Data pemakaian berhenti diperbarui sejak [tanggal]".
- `alerts`: alert hari ini yang belum pernah dikirim ke client ini. Server menandainya terkirim setelah respons ini.

#### `PUT /device`

Dipanggil saat aplikasi dibuka dan setiap kali status izin berubah. Dipakai untuk metrik admin "% pengguna Android dengan Usage Access aktif" (FR-15.2).

```json
{ "platform": "android", "usage_access_granted": true }
```

`platform`: `android` | `web`. Respons `204`.

### Katalog dan isi ulang (FR-3, FR-4, FR-12)

#### `GET /packages`

```json
{
  "data": {
    "groups": [
      { "type": "harian", "packages": [ { "…": "Package" } ] },
      { "type": "mingguan", "packages": [] },
      { "type": "bulanan", "packages": [] },
      { "type": "aplikasi", "packages": [] }
    ],
    "points": {
      "balance": 340,
      "rupiah_per_point": 10,
      "redeem_step": 100,
      "max_discount_percent": 20,
      "min_net_amount": 1000
    }
  }
}
```

Hanya paket `is_active = true`. Objek `points` diambil dari tabel `settings`, sehingga client bisa menghitung pilihan tukar poin dan total bayar di checkout tanpa memanggil server lagi. Server tetap memvalidasi ulang saat `POST /transactions`.

Rumus di client: poin maksimal = kelipatan `redeem_step` terbesar yang ≤ `balance`, ≤ `price × max_discount_percent / 100 / rupiah_per_point`, dan menyisakan `net_amount` ≥ `min_net_amount`.

#### `GET /topup-options`

```json
{
  "data": [
    { "amount": 5000, "extend_days": 7 },
    { "amount": 10000, "extend_days": 15 },
    { "amount": 25000, "extend_days": 30 },
    { "amount": 50000, "extend_days": 45 },
    { "amount": 100000, "extend_days": 60 }
  ]
}
```

Nilai diambil dari `settings` (OQ-2), jadi bisa berubah dari panel admin.

### Transaksi dan pembayaran (FR-5, FR-6)

#### `POST /transactions`

Header wajib: `Idempotency-Key`.

Beli paket:

```json
{
  "type": "package",
  "package_id": 7,
  "points_used": 500,
  "payment_method": "va",
  "recommendation_id": 88
}
```

Isi ulang:

```json
{ "type": "topup", "topup_amount": 25000, "payment_method": "qris" }
```

Aturan validasi:

| Field | Aturan |
| --- | --- |
| `type` | `package` \| `topup` |
| `package_id` | Wajib jika `package`. Paket harus `is_active` |
| `topup_amount` | Wajib jika `topup`. Harus salah satu nominal di `/topup-options` |
| `points_used` | Opsional, default 0. Hanya untuk `package`. Kelipatan `redeem_step`, ≤ saldo, diskon ≤ batas persen, `net_amount` ≥ `min_net_amount` |
| `payment_method` | `pulsa` hanya untuk `package`. `topup` memakai `ewallet` \| `va` \| `qris` |
| `recommendation_id` | Opsional. Diisi jika pembelian berasal dari layar rekomendasi. Saat `paid`, server mengisi `recommendations.purchased_transaction_id` |

Respons:

- `201`: transaksi baru. Metode `pulsa` langsung `status = paid` dan paket langsung aktif. Metode lain `status = pending` dengan `expires_at` +15 menit dan objek `payment`.
- `200`: replay dengan `Idempotency-Key` yang sama.

Body: `{ "data": Transaction }`.

Error:

| Kode | Kapan |
| --- | --- |
| `422 INSUFFICIENT_BALANCE` | Pulsa kurang. `meta.shortfall` berisi kekurangannya. Client menampilkan tombol "Isi ulang" |
| `422 POINTS_INVALID` | Poin melanggar aturan di atas. `meta.max_points` berisi nilai maksimal yang sah |
| `422 PACKAGE_INACTIVE` | Paket dinonaktifkan admin |
| `403 SUBSCRIBER_IN_GRACE` | Beli paket saat masa tenggang. Isi ulang tetap boleh |
| `422 IDEMPOTENCY_KEY_MISMATCH` | Key sama, body berbeda |

#### `GET /transactions`

Daftar transaksi milik pengguna, terbaru di atas, berhalaman. Filter opsional `?status=pending`. Item berupa `Transaction` tanpa objek `payment` (dihemat). Riwayat berbagi kuota ada di `GET /quota-transfers` dan ditampilkan sebagai tab terpisah di layar riwayat.

#### `GET /transactions/{id}`

`Transaction` lengkap dengan objek `payment`, plus field tambahan:

```json
{ "subscription_id": 52 }
```

`subscription_id` terisi setelah paket terprovisioning. Endpoint ini yang di-polling setiap 3 detik di layar menunggu bayar (FR-5.7). Polling berhenti saat `status` bukan `pending`. Tombol "Lanjutkan bayar" membuka ulang `payment.simulator_url`.

#### `POST /payments/callback` (publik, ditandatangani)

Dipanggil oleh server Laravel sendiri dari halaman simulator. Tidak dipanggil oleh Flutter.

Header: `X-Signature: {hex(HMAC-SHA256(raw_body, PAYMENT_WEBHOOK_SECRET))}`.

```json
{
  "external_ref": "KP-20261029-8F3K2Q",
  "status": "PAID",
  "paid_at": "2026-10-29T14:07:12+07:00"
}
```

`status`: `PAID` | `FAILED`. Semua callback dicatat di `payment_callbacks` sebelum diproses, termasuk yang ditolak.

| Respons | Kapan |
| --- | --- |
| `200` | Diproses, atau callback ganda untuk transaksi yang sudah final (tanpa efek) |
| `401 INVALID_SIGNATURE` | Signature salah. `signature_valid = false` |
| `404 NOT_FOUND` | `external_ref` tidak dikenal |
| `409 TRANSACTION_EXPIRED` | Transaksi sudah `expired`. Tidak ada provisioning |
| `500 SERVER_ERROR` | Provisioning gagal dan seluruh transaksi DB di-rollback. Simulator menampilkan "Coba lagi" |

Callback `PAID` menjalankan dalam satu transaksi DB dengan row lock pada transaksi: ubah status, buat `subscriptions` atau tambah pulsa + perpanjang masa aktif, finalkan hold poin, isi `recommendations.purchased_transaction_id`. Callback `FAILED` mengubah status dan menulis `redeem_release`.

### Pemakaian (FR-7, FR-8)

#### `POST /usage/sync`

Dikirim oleh Android saat aplikasi dibuka dan setiap 6 jam (WorkManager). Berisi bucket 7 hari terakhir. Nilai `bytes_mobile` adalah **total kumulatif** hari itu, bukan selisih. Server yang menghitung delta.

```json
{
  "buckets": [
    {
      "usage_date": "2026-10-28",
      "package_name": "com.zhiliaoapp.musically",
      "label": "TikTok",
      "bytes_mobile": 734003200
    },
    {
      "usage_date": "2026-10-28",
      "package_name": "android.tethering",
      "label": "Hotspot",
      "bytes_mobile": 104857600
    }
  ]
}
```

UID khusus (FR-7.4) dikirim dengan `package_name` tetap: `android.removed` (Aplikasi terhapus), `android.tethering` (Hotspot), `android.system` (Sistem Android).

Aturan server:

- Maksimal 2.100 bucket per request (7 hari × 300 aplikasi). Lebih dari itu ditolak `422 VALIDATION_FAILED`.
- `usage_date` di masa depan (menurut waktu server) atau lebih tua dari 7 hari ditolak per bucket dan masuk `rejected`.
- `package_name` yang belum ada di `apps` dibuat dengan kategori `umum` dan ditandai "Belum ditinjau".
- Delta negatif diabaikan dan dicatat di log.
- Setelah upsert: kuota dipotong (FR-7.7), forecast dihitung ulang (FR-9.6), alert dievaluasi (FR-13).
- Kuota hanya dipotong dari paket yang aktif pada `usage_date` bucket itu, supaya riwayat 7 hari pada sync pertama tidak membebani paket yang baru dibeli.
- Sync pertama dari perangkat menghapus data `source = demo` milik akun itu: data asli menggantikan data demo.

Respons `200`:

```json
{
  "data": {
    "accepted": 41,
    "rejected": [ { "index": 3, "reason": "FUTURE_DATE" } ],
    "applied_bytes": 209715200,
    "forecast": { "…": "Forecast" },
    "alerts": [ { "…": "Alert" } ]
  }
}
```

WorkManager di latar belakang membaca `alerts` lalu menampilkannya sebagai notifikasi lokal.

#### `POST /usage/demo`

Mode Demo (FR-7.8). Membuat pemakaian 30 hari terakhir dari profil. Pemanggilan berikutnya **mengganti** semua data `source = demo` milik pengguna, sehingga bisa dipakai untuk berganti profil saat demo.

```json
{ "profile": "rina" }
```

`profile`: `rina` | `budi` | `random`.

Pemotongan kuota (OQ-1): data demo hari-hari lampau **tidak** memotong kuota, karena 30 hari sekaligus akan langsung menghabiskan paket. Data demo hanya mengisi analisis, prediksi, rekomendasi, dan evaluasi reward.

Respons `201`: `{ "data": { "days": 30, "total_bytes": 15032385536, "forecast": Forecast } }`.

Error: `409 DEVICE_DATA_EXISTS` jika pengguna sudah punya data `source = device`. Data asli tidak boleh tercampur dengan data demo.

#### `GET /usage/summary?period=7d`

`period`: `today` | `7d` | `30d`.

```json
{
  "data": {
    "period": "7d",
    "source": "device",
    "last_synced_at": "2026-10-29T08:00:00+07:00",
    "daily_budget_bytes": 412090368,
    "total_bytes": 3670016000,
    "top_apps": [
      { "app_id": 12, "package_name": "com.zhiliaoapp.musically", "label": "TikTok", "category": "video", "bytes": 1761607680, "percent": 48.0 },
      { "app_id": null, "package_name": null, "label": "Lainnya", "category": null, "bytes": 314572800, "percent": 8.6 }
    ],
    "apps": [ { "app_id": 12, "package_name": "com.zhiliaoapp.musically", "label": "TikTok", "category": "video", "bytes": 1761607680, "percent": 48.0 } ],
    "daily": [
      { "date": "2026-10-23", "bytes": 524288000, "budget_bytes": 450000000, "is_spike": false }
    ],
    "insights": [
      "TikTok memakai 48% kuotamu minggu ini, naik 20% dari minggu lalu."
    ]
  }
}
```

- `top_apps`: 5 aplikasi terbesar + satu item "Lainnya" (`app_id = null`) untuk donut chart. `apps`: daftar lengkap, terurut menurun.
- `daily_budget_bytes`: jatah harian saat ini dari prediksi terbaru, digambar sebagai garis pembanding. `null` jika tidak ada paket aktif.
- `daily.budget_bytes`: jatah harian snapshot hari itu (dari evaluasi reward, M6), `null` jika belum ada. `is_spike`: pemakaian > 3× median 7 hari.
- `insights`: maksimal 3 kalimat (FR-8.5).
- Belum ada data: `source = null`, semua array kosong. Client menampilkan pesan FR-8.6.
- Ikon aplikasi tidak dikirim. Android dan web sama-sama memakai ikon kategori, supaya tampilan konsisten dan tidak butuh kode native tambahan.

#### `GET /usage/apps/{app_id}?period=30d`

```json
{
  "data": {
    "app": { "app_id": 12, "package_name": "com.zhiliaoapp.musically", "label": "TikTok", "category": "video" },
    "period": "30d",
    "total_bytes": 6442450944,
    "avg_daily_bytes": 214748364,
    "daily": [ { "date": "2026-09-30", "bytes": 209715200 } ]
  }
}
```

### Rekomendasi (FR-10)

#### `GET /recommendations`

Mengambil batch terbaru. Batch dihitung ulang jika lebih lama dari forecast terbaru atau dari `catalog_updated_at` (FR-15.5). Setiap pemanggilan mengisi `shown_at` pada item yang belum pernah ditampilkan.

```json
{
  "data": {
    "status": "ok",
    "need": {
      "total_bytes": 15032385536,
      "by_category": { "video": 9126805504, "sosmed": 2147483648, "game": 0, "belajar": 536870912, "umum": 3221225472 }
    },
    "spent_30d": 75000,
    "items": [
      {
        "id": 88,
        "rank": 1,
        "package": { "…": "Package" },
        "cost_30d": 65000,
        "saving_30d": 10000,
        "leftover_bytes": 1503238553,
        "reason": "Pemakaianmu sekitar 14 GB/bulan, 62% dari TikTok dan YouTube. Paket Video 30 Hari berisi 10 GB kuota video + 6 GB utama, cukup dengan sisa 1,4 GB."
      }
    ]
  }
}
```

- `status`: `ok` | `insufficient_data` (< 7 hari data, `items` kosong) | `already_cheapest` (`saving_30d` rank 1 ≤ 0 **dan** paket terakhir yang dibeli cukup). Jika paket terakhir tidak cukup, status tetap `ok` dan `saving_30d` boleh negatif.
- `items`: 1 rekomendasi utama (`rank = 1`) + maksimal 2 alternatif.
- `spent_30d`: total `gross_amount` transaksi paket `paid` dalam 30 hari terakhir. `saving_30d` = `spent_30d` − `cost_30d`. Keduanya `null` jika tidak ada pembelian paket dalam 30 hari terakhir (FR-10.5).

#### `POST /recommendations/{id}/click`

Mengisi `clicked_at`. Respons `204`. Pembelian dicatat lewat `recommendation_id` di `POST /transactions`.

### Reward poin (FR-11)

#### `GET /points`

```json
{
  "data": {
    "balance": 340,
    "held": 0,
    "streak": 4,
    "expiring_soon": { "points": 30, "first_expires_at": "2026-11-02" },
    "calendar": [
      { "date": "2026-09-29", "result": "hemat", "points": 10 },
      { "date": "2026-09-30", "result": "no_data", "points": 0 }
    ],
    "rules": {
      "points_per_day": 10,
      "streak_bonus": 50,
      "streak_length": 7,
      "min_usage_bytes": 52428800
    }
  }
}
```

- `balance` = SUM(`delta`) di `point_ledger`, sudah dikurangi poin yang sedang di-hold. `held` = poin yang ditahan transaksi `pending`.
- `calendar`: 30 hari terakhir, `result`: `hemat` | `boros` | `no_data`.
- `expiring_soon`: poin yang kedaluwarsa dalam 7 hari. `null` jika tidak ada.

#### `GET /points/ledger`

Berhalaman, terbaru di atas.

```json
{
  "data": [
    {
      "id": 901,
      "delta": -500,
      "type": "redeem_hold",
      "description": "Diskon paket Video 30 Hari",
      "ref": { "type": "transaction", "id": 118 },
      "expires_at": null,
      "created_at": "2026-10-29T14:05:00+07:00"
    }
  ]
}
```

`type`: `earn_daily` | `earn_streak` | `redeem_hold` | `redeem_release` | `spend_share` | `expire`. `description` dibuat server supaya client tidak perlu memetakan tiap tipe.

### Berbagi kuota (FR-14)

Alur di client: input nomor → `GET /quota-transfers/quote` → pilih jumlah + layar ringkasan → `POST /quota-transfers/otp` → input OTP → `POST /quota-transfers`.

#### `GET /quota-transfers/quote?recipient_msisdn=081298765432`

Memvalidasi penerima dan menghitung semua pilihan jumlah sekaligus. Hasilnya dipakai untuk layar pilihan jumlah dan layar ringkasan, jadi tidak perlu endpoint terpisah.

```json
{
  "data": {
    "recipient": { "msisdn_masked": "0812••••5432", "has_account": true },
    "allowance": {
      "limit_bytes": 2147483648,
      "used_30d_bytes": 536870912,
      "remaining_bytes": 1610612736,
      "recovers_at": "2026-11-15"
    },
    "sender_main_remaining_bytes": 10737418240,
    "points_balance": 340,
    "options": [
      {
        "bytes": 536870912,
        "points_cost": 100,
        "allowed": true,
        "reason": null,
        "recipient_expires_at": "2026-11-05T14:05:00+07:00",
        "sender_main_remaining_after": 10200547328
      },
      {
        "bytes": 2147483648,
        "points_cost": 400,
        "allowed": false,
        "reason": "Melebihi sisa jatah berbagi 1,5 GB."
      }
    ]
  }
}
```

- `recovers_at`: tanggal transfer tertua dalam jendela 30 hari keluar dari hitungan. `null` jika belum pernah berbagi.
- Opsi yang `allowed = false` tetap dikirim dengan `reason`, supaya client bisa menampilkannya nonaktif (FR-14.3).
- `reason` yang mungkin: melebihi jatah berbagi, sisa kuota setelah berbagi < 2 GB, poin tidak cukup.

Error (penerima ditolak sebelum layar konfirmasi, FR-14.2): `422 RECIPIENT_NOT_SUBSCRIBER`, `422 RECIPIENT_INACTIVE` (masa tenggang atau terminated), `422 RECIPIENT_IS_SELF`.

#### `POST /quota-transfers/otp`

Memeriksa ulang aturan untuk jumlah yang dipilih, lalu mengirim OTP ke nomor **pengirim** memakai mekanisme FR-1 (OQ-14). OTP ini terikat ke kombinasi penerima + jumlah, sehingga tidak bisa dipakai untuk login atau transfer lain.

```json
{ "recipient_msisdn": "081298765432", "bytes": 536870912 }
```

Respons `200`: sama dengan `POST /auth/otp/request` (`expires_at`, `resend_available_at`, `demo_otp`).

Error: semua error `quote` + `422 SHARE_NOT_ALLOWED` (`meta.reason`), `429 OTP_RESEND_TOO_SOON`, `423 OTP_LOCKED`.

#### `POST /quota-transfers`

Header wajib: `Idempotency-Key`.

```json
{ "recipient_msisdn": "081298765432", "bytes": 536870912, "otp_code": "771204" }
```

Server menjalankan FR-14.11 dalam satu transaksi DB: kunci baris paket dan poin pengirim, periksa ulang aturan 2–6, potong kuota (paket paling cepat berakhir dulu), potong poin FIFO, buat `subscriptions` penerima dengan `source = shared`, catat `quota_transfers` + `quota_transfer_sources`, lalu buat alert `quota_received` untuk penerima (atau tulis SMS dummy ke log jika penerima tidak punya akun).

Respons `201` (atau `200` untuk replay):

```json
{
  "data": {
    "id": 15,
    "recipient_msisdn_masked": "0812••••5432",
    "bytes": 536870912,
    "points_spent": 100,
    "recipient_expires_at": "2026-11-05T14:05:00+07:00",
    "status": "completed",
    "completed_at": "2026-10-29T14:06:30+07:00",
    "sender_main_remaining_after": 10200547328
  }
}
```

Error: `422 OTP_INVALID` / `OTP_EXPIRED`, `423 OTP_LOCKED`, `422 SHARE_NOT_ALLOWED` (aturan tidak terpenuhi lagi saat eksekusi, misalnya karena sync atau transfer paralel; poin tidak terpotong), `422 IDEMPOTENCY_KEY_MISMATCH`.

#### `GET /quota-transfers`

Riwayat berbagi sebagai pengirim, berhalaman. Item sama dengan respons `POST /quota-transfers` tanpa `sender_main_remaining_after`. Kuota yang **diterima** tampil di beranda sebagai `Subscription` dengan `source = shared`.

## Perubahan data model dari PRD

Kebutuhan berikut muncul saat menyusun kontrak ini. Semuanya sudah dimasukkan ke bagian "Sketsa data model" PRD (Oct 29, 2026):

| Tabel | Perubahan | Alasan |
| --- | --- | --- |
| `otp_codes` | Tambah `purpose` (`login` / `quota_transfer`) dan `context` (JSON: penerima + jumlah) | OTP berbagi kuota tidak boleh bisa dipakai untuk login, dan sebaliknya |
| `users` | Tambah `platform` (`android`/`web`), `usage_access_granted` (bool), `usage_access_checked_at` | Metrik admin "% pengguna Android dengan Usage Access aktif" (FR-15.2), diisi oleh `PUT /device` |
| `transactions` | Tambah `recommendation_id` (nullable FK) | Menghubungkan pembelian ke rekomendasi saat callback `PAID` (FR-10.8) |
| `transactions` | Tambah `request_hash` | Mendeteksi `IDEMPOTENCY_KEY_MISMATCH` |
| `notifications` | Tambah `delivered_at` | Menandai alert yang sudah dikirim ke client agar tidak muncul dua kali |

## Lampiran A: Daftar kode error

| `code` | HTTP | Endpoint |
| --- | --- | --- |
| `UNAUTHENTICATED` | 401 | Semua endpoint ber-token |
| `TOO_MANY_REQUESTS` | 429 | Semua |
| `VALIDATION_FAILED` | 422 | Semua yang menerima body |
| `NOT_FOUND` | 404 | Endpoint dengan `{id}` |
| `SERVER_ERROR` | 500 | Semua |
| `NOT_SUBSCRIBER` | 404 | `/auth/otp/request` |
| `SUBSCRIBER_TERMINATED` | 403 | `/auth/otp/request` |
| `SUBSCRIBER_IN_GRACE` | 403 | `POST /transactions` (type `package`) |
| `OTP_INVALID` | 422 | `/auth/otp/verify`, `POST /quota-transfers` |
| `OTP_EXPIRED` | 422 | `/auth/otp/verify`, `POST /quota-transfers` |
| `OTP_LOCKED` | 423 | Semua endpoint OTP |
| `OTP_RESEND_TOO_SOON` | 429 | `/auth/otp/request`, `/quota-transfers/otp` |
| `IDEMPOTENCY_KEY_REQUIRED` | 400 | `POST /transactions`, `POST /quota-transfers` |
| `IDEMPOTENCY_KEY_MISMATCH` | 422 | `POST /transactions`, `POST /quota-transfers` |
| `INSUFFICIENT_BALANCE` | 422 | `POST /transactions` |
| `POINTS_INVALID` | 422 | `POST /transactions` |
| `PACKAGE_INACTIVE` | 422 | `POST /transactions` |
| `INVALID_SIGNATURE` | 401 | `/payments/callback` |
| `TRANSACTION_EXPIRED` | 409 | `/payments/callback` |
| `DEVICE_DATA_EXISTS` | 409 | `/usage/demo` |
| `RECIPIENT_NOT_SUBSCRIBER` | 422 | `/quota-transfers/quote`, `/quota-transfers/otp` |
| `RECIPIENT_INACTIVE` | 422 | `/quota-transfers/quote`, `/quota-transfers/otp` |
| `RECIPIENT_IS_SELF` | 422 | `/quota-transfers/quote`, `/quota-transfers/otp` |
| `SHARE_NOT_ALLOWED` | 422 | `/quota-transfers/otp`, `POST /quota-transfers` |

## Pertanyaan terbuka

| ID | Pertanyaan | Usulan default |
| --- | --- | --- |
| AQ-1 | Riwayat berbagi kuota digabung ke daftar transaksi atau tab terpisah? | **Diputuskan:** tab terpisah di layar Riwayat. PRD FR-6.3 dan FR-14.13 sudah diselaraskan |
| AQ-2 | Data demo hari lampau memotong kuota atau tidak (turunan OQ-1)? | **Diputuskan:** tidak. PRD FR-7.8 dan OQ-1 sudah diselaraskan |
| AQ-3 | Apakah `demo_otp` perlu dimatikan untuk demo di depan dosen supaya terlihat seperti nyata? | Tidak. OTP tetap muncul di banner "Mode Demo", sesuai FR-1.3 |
