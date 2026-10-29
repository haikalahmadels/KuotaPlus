# UI Kuota+

Oct 29, 2026 · @Haikal Ahmad El Salman · Draft 1

Design token, daftar layar, dan peta navigasi aplikasi Flutter. Wireframe tiap layar ditambahkan di awal milestone yang membuatnya ([PLAN](PLAN-KuotaPlus.md)). Implementasi token ada di `lib/app/theme.dart`.

## Prinsip

1. **Angka dulu.** Setiap layar menjawab satu pertanyaan pengguna ("berapa sisa kuotaku?", "kapan habis?"). Angka itu tampil paling besar, penjelasannya di bawah.
2. **Warna punya arti.** Hijau hanya untuk hemat/aman, kuning tua untuk berisiko, merah untuk boros/gagal. Warna utama (biru) dipakai untuk aksi, tidak untuk status.
3. **Setiap state punya tampilan.** Setiap layar yang mengambil data punya empat keadaan: memuat, berhasil, kosong, dan error (dengan tombol coba lagi). Empty state yang disebut di PRD ditulis di wireframe layar masing-masing.
4. **Bahasa Indonesia sehari-hari**, kalimat pendek, tanpa istilah teknis ("Kuota habis", bukan "Status: exhausted").

## Design token

Mode terang saja. Mode gelap tidak termasuk MVP.

### Warna

Semua pasangan teks di bawah sudah dicek memenuhi WCAG AA (≥ 4,5:1).

| Token | Hex | Pemakaian | Kontras |
| --- | --- | --- | --- |
| `primary` | `#1E40AF` | Tombol utama, link, tab aktif | 8,1:1 di `background` |
| `onPrimary` | `#FFFFFF` | Teks di atas `primary` | 8,7:1 |
| `background` | `#F6F7F9` | Latar layar | — |
| `surface` | `#FFFFFF` | Kartu, sheet, input | — |
| `text` | `#111827` | Teks utama | 17:1 di `surface` |
| `textMuted` | `#4B5563` | Label, keterangan | 7,0:1 di `background` |
| `border` | `#E5E7EB` | Garis kartu, pemisah | Dekoratif |
| `success` | `#15803D` | Hemat, Aman, transaksi berhasil | 5,0:1 di `surface` |
| `warning` | `#B45309` | Berisiko, perkiraan awal, menunggu bayar | 5,0:1 di `surface` |
| `danger` | `#B91C1C` | Boros, gagal, kuota habis, error | 6,5:1 di `surface` |
| `noData` | `#9CA3AF` | Kalender "tidak ada data" | Dekoratif, selalu disertai legenda teks |

Status tidak pernah disampaikan dengan warna saja: selalu ada label teks atau ikon (misalnya chip "Berisiko" berwarna kuning tua dengan teksnya).

### Tipografi

Font sistem bawaan Material 3 (Roboto di Android, font sistem di web), tanpa font tambahan.

| Token | Ukuran / berat | Pemakaian |
| --- | --- | --- |
| `display` | 32 / 700 | Angka utama: sisa kuota, saldo pulsa |
| `title` | 20 / 600 | Judul layar dan kartu |
| `body` | 16 / 400 | Teks biasa |
| `label` | 14 / 500 | Label field, chip, tombol |
| `caption` | 12 / 400 | Keterangan kecil, waktu diperbarui |

Angka memakai `FontFeature.tabularFigures()` supaya tidak bergeser saat berubah.

### Spacing, radius, ukuran

| Token | Nilai |
| --- | --- |
| Spacing | 4, 8, 12, 16, 24, 32 |
| Padding layar | 16 |
| Jarak antar kartu | 12 |
| Radius kartu | 16 |
| Radius tombol dan input | 12 |
| Tinggi tombol | 48 |
| Target sentuh minimum | 48 × 48 |

## Navigasi

```
/login ──▶ /login/otp ──▶ (Android, izin belum ada) /onboarding/usage-access ──▶ shell
                                                                               │
        ┌──────────────┬──────────────┬──────────────┬──────────────┐          │
        │ Beranda      │ Paket        │ Analisis     │ Reward       │ Riwayat  ◀┘  (NavigationBar, 5 tab)
        │ /home        │ /packages    │ /usage       │ /rewards     │ /history
        └──────┬───────┴──────┬───────┴──────┬───────┴──────┬───────┴──────┬─────
               │              │              │              │              │
   /recommendations   /packages/:id/checkout  /usage/apps/:id  /rewards/ledger  /history/:id
   /topup             /payment/:id           (sheet Mode Demo)
   /share → /share/amount → /share/otp → /share/done
```

- Belum login atau menerima 401 → `/login?from=<route asal>`, lalu kembali ke route asal setelah login.
- Layar di luar 5 tab dibuka di atas shell (tanpa NavigationBar) dan punya tombol kembali.
- `/payment/:id` dibuka setelah checkout atau isi ulang, dan dari tombol "Lanjutkan bayar" di detail transaksi.
- Deep link notifikasi memakai route yang sama (`target` di objek `Alert`).

## Daftar layar

| ID | Layar | Route | Milestone | API utama |
| --- | --- | --- | --- | --- |
| S01 | Login nomor HP | `/login` | M1 | `POST /auth/otp/request` |
| S02 | Verifikasi OTP | `/login/otp` | M1 | `POST /auth/otp/verify` |
| S03 | Penjelasan izin Usage Access | `/onboarding/usage-access` | M4 | `PUT /device` |
| S04 | Beranda | `/home` | M2 (M5–M7 melengkapi) | `GET /home` |
| S05 | Katalog paket | `/packages` | M2 | `GET /packages` |
| S06 | Checkout | `/packages/:id/checkout` | M3 (poin di M6) | `POST /transactions` |
| S07 | Isi ulang | `/topup` | M3 | `GET /topup-options`, `POST /transactions` |
| S08 | Menunggu pembayaran / hasil | `/payment/:id` | M3 | `GET /transactions/{id}` |
| S09 | Riwayat (tab Pembelian, Berbagi) | `/history` | M3 (Berbagi di M8) | `GET /transactions`, `GET /quota-transfers` |
| S10 | Detail transaksi | `/history/:id` | M3 | `GET /transactions/{id}` |
| S11 | Analisis pemakaian | `/usage` | M4 | `GET /usage/summary` |
| S12 | Detail aplikasi | `/usage/apps/:id` | M4 | `GET /usage/apps/{id}` |
| S13 | Mode Demo (bottom sheet) | — | M4 | `POST /usage/demo` |
| S14 | Rekomendasi paket | `/recommendations` | M5 | `GET /recommendations` |
| S15 | Reward | `/rewards` | M6 | `GET /points` |
| S16 | Riwayat poin | `/rewards/ledger` | M6 | `GET /points/ledger` |
| S17 | Bagi kuota: nomor penerima | `/share` | M8 | `GET /quota-transfers/quote` |
| S18 | Bagi kuota: jumlah + ringkasan | `/share/amount` | M8 | (hasil quote) |
| S19 | Bagi kuota: OTP | `/share/otp` | M8 | `POST /quota-transfers/otp`, `POST /quota-transfers` |
| S20 | Bagi kuota: selesai | `/share/done` | M8 | — |

## Wireframe

Diisi per milestone. Format: sketsa ASCII + daftar state (memuat, berhasil, kosong, error) + catatan perilaku.

### S01 Login nomor HP (M1)

```
┌──────────────────────────────┐
│                              │
│  Kuota+                      │  ← title
│  Masuk dengan nomor Nusantel │  ← textMuted
│                              │
│  Nomor HP                    │
│  ┌────────────────────────┐  │
│  │ 0881-0000-0001         │  │  ← keyboard angka, autofill nomor
│  └────────────────────────┘  │
│  Nomor bukan pelanggan       │  ← error di bawah field (danger)
│  Nusantel.                   │
│                              │
│  ┌────────────────────────┐  │
│  │     Kirim kode OTP     │  │  ← FilledButton, loading saat request
│  └────────────────────────┘  │
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| Awal | Field kosong, tombol aktif setelah ada isian |
| Memuat | Tombol berisi spinner, field dikunci |
| Error field | `VALIDATION_FAILED`, `NOT_SUBSCRIBER`, `SUBSCRIBER_TERMINATED`: pesan server di bawah field |
| Error lain | `OTP_LOCKED`, `OTP_RESEND_TOO_SOON`, `TOO_MANY_REQUESTS`, jaringan: pesan di bawah field |
| Berhasil | Pindah ke S02 membawa nomor dan waktu kedaluwarsa |

### S02 Verifikasi OTP (M1)

```
┌──────────────────────────────┐
│ ←  Verifikasi                │
│                              │
│  Masukkan 6 digit kode yang  │
│  dikirim ke 0881-0000-0001   │
│                              │
│ ┌──────────────────────────┐ │
│ │ MODE DEMO                │ │  ← banner (warning), hanya jika ada demo_otp
│ │ Kode OTP: 405678  [Isi]  │ │     ketuk "Isi" untuk mengisi otomatis
│ └──────────────────────────┘ │
│                              │
│  ┌────────────────────────┐  │
│  │  4 0 5 6 7 8           │  │  ← satu field, 6 digit, huruf renggang
│  └────────────────────────┘  │
│  Kode salah. Sisa 3 percobaan│  ← error (danger)
│                              │
│  Kirim ulang dalam 0:42      │  ← jadi tombol "Kirim ulang kode" saat 0
│                              │
│  ┌────────────────────────┐  │
│  │         Masuk          │  │
│  └────────────────────────┘  │
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| Mengisi | Verifikasi otomatis saat digit ke-6 diketik |
| Memuat | Tombol berisi spinner |
| `OTP_INVALID` | Pesan dengan sisa percobaan, field dikosongkan |
| `OTP_EXPIRED` | Pesan "kedaluwarsa", tombol kirim ulang langsung aktif |
| `OTP_LOCKED` | Kembali ke S01 dengan pesan jam buka kunci |
| Berhasil | Token disimpan, pindah ke route asal (`from`) atau `/home` |

Catatan: sampai M2, `/home` adalah layar sementara berisi tombol Keluar.

### Shell navigasi (M2)

NavigationBar 5 tab: Beranda, Paket, Analisis, Reward, Riwayat. Tab yang belum dibuat menampilkan empty state "Fitur ini sedang disiapkan" sampai milestone-nya (Analisis M4, Reward M6, Riwayat M3).

### S04 Beranda (M2)

```
┌──────────────────────────────┐
│ Beranda                [⋮]   │  ← menu: Keluar
│ ┌──────────────────────────┐ │
│ │ ⚠ Tidak bisa terhubung   │ │  ← banner (danger), hanya saat menampilkan cache
│ │   ke server              │ │
│ └──────────────────────────┘ │
│ Diperbarui 29 Okt, 14.05     │  ← caption
│ ┌──────────────────────────┐ │
│ │ Pulsa                    │ │
│ │ Rp12.500                 │ │  ← display
│ │ Aktif s.d. 23 Nov 2026   │ │
│ │ 25 hari lagi             │ │
│ │ [Isi ulang]              │ │
│ └──────────────────────────┘ │
│ Kuota aktif                  │
│ ┌──────────────────────────┐ │
│ │ Bulanan 15 GB            │ │
│ │ 5,3 GB      dari 15 GB   │ │  ← sisa besar, total kecil
│ │ ▓▓▓▓▓▓░░░░░░░░░░░░       │ │  ← bar sisa
│ │ Berakhir 16 Nov 2026,    │ │
│ │ 07.00                    │ │  ← tanggal + jam WIB (paket berakhir pada jam tertentu)
│ └──────────────────────────┘ │
│ ┌──────────────────────────┐ │
│ │ Video 30 Hari            │ │
│ │ Utama   8 GB dari 12 GB  │ │
│ │ Video  15 GB dari 16 GB  │ │  ← kuota aplikasi terpisah (FR-2.1)
│ │ Berakhir 3 Nov 2026, 07.00│ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| Memuat pertama kali | Spinner di tengah |
| Berhasil | Seperti sketsa; pull-to-refresh memuat ulang |
| Tanpa paket | Kartu "Kamu tidak punya kuota aktif" + tombol "Lihat paket" (FR-2.6) |
| Paket `exhausted` | Angka sisa diganti chip "Kuota habis" (danger) |
| Kartu masa tenggang | Chip "Masa tenggang s.d. [tanggal]" (warning) + kalimat "Isi ulang agar nomor tetap aktif" |
| Offline dengan cache | Banner + data cache + label "Diperbarui" (FR-2.5) |
| Offline tanpa cache / error | Pesan error + tombol "Coba lagi" |

Kartu prediksi, jatah harian, rekomendasi, dan poin ditambahkan di M5–M6.

### S05 Katalog paket (M2)

```
┌──────────────────────────────┐
│ Paket                        │
│ [Harian][Mingguan][Bulanan][Aplikasi] ← chip filter, satu terpilih
│ ┌──────────────────────────┐ │
│ │ Video 30 Hari    Rp65.000│ │
│ │ 12 GB utama · 30 hari    │ │
│ │ + 16 GB Video            │ │
│ │ YouTube, TikTok, Netflix…│ │  ← app_examples
│ │                   [Beli] │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| Memuat | Spinner |
| Grup kosong | "Belum ada paket di kategori ini" |
| Error | Pesan + "Coba lagi" |
| Tombol Beli | Membuka checkout (M3). Di M2 menampilkan snackbar "Pembelian segera tersedia" |

### S07 Isi ulang (M2 tampilan, M3 pembayaran)

```
┌──────────────────────────────┐
│ ←  Isi ulang                 │
│ Pilih nominal                │
│ ┌────────────┐┌────────────┐ │
│ │ Rp5.000    ││ Rp10.000   │ │
│ │ +7 hari    ││ +15 hari   │ │  ← tambahan masa aktif (FR-4.3)
│ └────────────┘└────────────┘ │
│ ...                          │
│ ┌────────────────────────┐   │
│ │       Lanjut bayar     │   │  ← aktif setelah memilih (M3)
│ └────────────────────────┘   │
└──────────────────────────────┘
```

### S06 Checkout paket (M3, tukar poin di M6)

```
┌──────────────────────────────┐
│ ←  Checkout                  │
│ ┌──────────────────────────┐ │
│ │ Video 30 Hari            │ │
│ │ 12 GB utama · 30 hari    │ │
│ │ + 16 GB Video            │ │
│ │ Paket aktif setelah      │ │
│ │ dibayar ...              │ │
│ └──────────────────────────┘ │
│ Metode pembayaran            │
│ (•) Pulsa                    │  ← isi ulang (S07) tidak menampilkan Pulsa
│ ( ) E-Wallet                 │
│ ( ) Virtual Account          │
│ ( ) QRIS                     │
│ ──────────────────────────── │
│ Total bayar        Rp65.000  │
│ Pulsa tidak cukup. Kurang    │  ← error (danger)
│ Rp52.500.  [Isi ulang pulsa] │     tombol hanya untuk INSUFFICIENT_BALANCE
│ ┌────────────────────────┐   │
│ │          Bayar         │   │
│ └────────────────────────┘   │
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| Memuat | Tombol berisi spinner, pilihan metode dikunci |
| Berhasil | Layar diganti S08 |
| Error bisnis | Pesan server di atas tombol (`INSUFFICIENT_BALANCE`, `SUBSCRIBER_IN_GRACE`, `PACKAGE_INACTIVE`) |
| Error jaringan | Tombol menjadi "Coba lagi" dengan Idempotency-Key yang sama, jadi tidak ada transaksi ganda |
| Offline sebelum bayar | Tombol nonaktif + keterangan (TECH: `serverReachableProvider`) |

### S08 Pembayaran (M3)

```
┌──────────────────────────────┐
│ ←  Pembayaran                │
│ ┌──────────────────────────┐ │
│ │ Bulanan 15 GB  (Menunggu)│ │  ← chip status
│ │ Rp55.000                 │ │
│ │ QRIS · KP-20261029-KRS4V2│ │
│ └──────────────────────────┘ │
│ Bayar dalam 14:32            │  ← warning, hitung mundur ke expires_at
│ Batas 29 Okt 2026, 17.05     │
│        ┌────────┐            │
│        │ ▓▓ ▓▓▓ │            │  ← QR (QRIS) / nomor VA + tombol salin (VA)
│        └────────┘            │
│ ┌────────────────────────┐   │
│ │ Buka simulator pembayaran  │  ← Custom Tabs (Android) / tab baru (web)
│ └────────────────────────┘   │
│ Status diperbarui otomatis.  │
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| `pending` | Instruksi bayar; polling `GET /transactions/{id}` tiap 3 detik + saat aplikasi kembali ke foreground |
| `paid` | Ikon centang (success), "Paket sudah aktif" / "Pulsa dan masa aktif sudah bertambah", tombol Ke Beranda dan Lihat riwayat |
| `failed` | Ikon silang (danger), "Pembayaran ditolak" |
| `expired` | Ikon jam (muted), "Waktu pembayaran habis" |
| Error jaringan saat polling | Data terakhir tetap tampil, polling berlanjut |

### S09 Riwayat (M3, tab Berbagi di M8)

```
┌──────────────────────────────┐
│ Riwayat                      │
│ [ Pembelian ][  Berbagi  ]   │
│ Video 30 Hari       Rp65.000 │
│ 29 Okt, 16.50 · QRIS (Menunggu)
│ ──────────────────────────── │
│ Isi ulang Rp25.000  Rp25.000 │
│ 29 Okt, 16.40 · VA  (Berhasil)
│ ...                          │
│ [        Muat lagi        ]  │  ← jika masih ada halaman berikutnya
└──────────────────────────────┘
```

### S10 Detail transaksi (M3)

Daftar label–nilai: Item, Harga, Diskon poin (jika ada), Total bayar, Metode, Dibuat, Dibayar, Bayar sebelum (pending), Referensi (`external_ref`, bisa dipilih untuk disalin). Transaksi `pending` punya tombol "Lanjutkan bayar" ke S08 (FR-6.2).

### S03 Izin data pemakaian (M4)

Ditawarkan otomatis sekali setelah login di Android jika izin belum ada; setelah itu lewat tombol "Beri izin" di S11.

```
┌──────────────────────────────┐
│ ←  Izin data pemakaian       │
│ Lihat aplikasi mana yang     │
│ menghabiskan kuotamu         │
│ ✓ Yang dibaca: byte data     │  ← FR-7.1: apa yang dibaca,
│   seluler per aplikasi/hari  │     apa yang tidak, ke mana datanya
│ ⊘ Yang tidak dibaca: isi     │
│   trafik, pesan, browsing    │
│ 🔒 Ke mana: hanya server     │
│   Kuota+                     │
│ [  Buka pengaturan izin   ]  │  ← Settings "Akses penggunaan"
│ [     Pakai Mode Demo     ]  │
│        Nanti saja            │
└──────────────────────────────┘
```

Kembali dari Settings dengan izin aktif: langsung sync lalu layar ditutup.

### S11 Analisis (M4, garis jatah harian di M5)

```
┌──────────────────────────────┐
│ Analisis                     │
│ [Hari ini][ 7 hari ][30 hari]│  ← SegmentedButton
│ (Data demo) Disinkronkan ... │  ← chip hanya untuk data demo
│ 💡 TikTok memakai 52,1%      │  ← insight (maks 3)
│    kuotamu minggu ini.       │
│ ┌──────────────────────────┐ │
│ │      ◯ donut 4,9 GB      │ │  ← gradasi biru menurut peringkat,
│ │ ● TikTok    2,5 GB · 52% │ │     Lainnya abu-abu; legenda membawa
│ │ ● Instagram 1,1 GB · 24% │ │     identitas (nama + MB + %)
│ │ ● Lainnya   0,3 GB ·  6% │ │
│ └──────────────────────────┘ │
│ Pemakaian harian             │
│ ▂ ▅ ▂ ▅ ▂ ▃ ▃                │  ← bar biru; hari lonjakan kuning tua
│ Semua aplikasi               │
│ ▶ TikTok         2,5 GB      │  ← ketuk → S12
└──────────────────────────────┘
```

| State | Tampilan |
| --- | --- |
| Belum ada data, web | "Buka Kuota+ di Android untuk mengirim data, atau pakai Mode Demo" (FR-8.6) |
| Belum ada data, Android tanpa izin | "Beri izin" + "Pakai Mode Demo" (edge case Izin) |
| Belum ada data, Android dengan izin | Ajakan tarik layar untuk sinkronisasi |
| Data demo | Chip "Data demo" + tombol "Ganti profil demo" |
| Tarik ke bawah | Android: sync dari HP dulu, lalu muat ulang |

Warna donut tidak memakai palet kategorikal: semua kombinasi 5 warna yang lolos uji buta warna memakai hijau atau merah, yang di aplikasi ini sudah berarti hemat dan boros.

### S12 Detail aplikasi (M4)

Ikon kategori, dua kartu angka (Total, Rata-rata per hari), dan bar tren harian untuk periode yang sama dengan S11.

### S13 Mode Demo (M4, bottom sheet)

Daftar profil Rina, Budi, Acak dengan deskripsi singkat. Memilih profil membuat data 30 hari dan menutup sheet. `DEVICE_DATA_EXISTS` ditampilkan sebagai pesan di sheet.
