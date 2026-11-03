# Bukti DoD "Performa lokal"

Target (PRD): p95 latensi API ≤ 500 ms di Laragon; beranda tampil ≤ 2 detik setelah dibuka.
Diukur 3 Nov 2026 di laptop Laragon (Apache 2.4.68, PHP 8.3.33, MySQL) dan HP Infinix X6853, Wi-Fi yang sama.

## Hasil

| Ukuran | Hasil | Target |
| --- | --- | --- |
| p95 API, sisi server (Telescope), 186 request | **124 ms** (maks 341 ms, `POST /auth/otp/request`) | ≤ 500 ms |
| p95 API, sisi klien (termasuk jaringan Wi-Fi), 182 request | **154 ms** (maks 228 ms) | ≤ 500 ms |
| Ketuk ikon → beranda berisi data dari server, 5× buka dingin | **872–1032 ms** | ≤ 2 detik |

## Cara mengukur

**API.** `perf_api.py` login sebagai Budi (akun demo) dan membuka 12 layar aplikasi 15 putaran
(beranda, katalog, analisis 7 dan 30 hari, detail aplikasi, rekomendasi, poin, riwayat poin, riwayat
transaksi, isi ulang, riwayat berbagi, quote berbagi), ditambah satu transaksi QRIS pending. Jeda 1,25 detik
antar-request supaya tidak terkena batas 60 request/menit. Laravel Telescope (dev, hanya `APP_ENV=local`)
mencatat durasi setiap request; `perf_telescope.php` menghitung p95 dari tabel `telescope_entries`.

```
python perf_api.py http://192.168.1.2/api 15        # hasil: perf_api_output.txt
cd ../../../backend && php ../KuotaPlus/docs/bukti/perf_telescope.php "2026-11-03 16:11:28"   # perf_telescope_output.txt
```

**Beranda.** Build profile (`flutter build apk --profile --dart-define-from-file=env/device.json`), sudah login.
Setiap percobaan: `am force-stop`, `am start -W`, lalu selisih waktu logcat antara `ActivityManager: Start proc`
(proses dibuat saat ikon diketuk) dan baris `KuotaPlus: beranda tampil`, yang dicetak setelah frame pertama
berisi data `GET /home` tergambar (`cache: false` = data dari server, bukan cache offline). Hasil:
`perf_beranda_output.txt`. Baris log itu tidak dicetak di build rilis.

## Temuan: OPcache

Pengukuran pertama memberi p95 klien 570 ms: semua endpoint ±500 ms, bahkan `/up` yang kosong. Penyebabnya
OPcache mati di `php.ini` Laragon, sehingga PHP mengompilasi ulang Laravel dan Filament di setiap request.
Setelah `zend_extension=opcache` dan `opcache.enable=1` diaktifkan (memori 256 MB, `max_accelerated_files`
20000, `validate_timestamps` tetap 1 supaya perubahan kode langsung terbaca) dan Apache di-restart,
biaya dasar request turun dari ±480 ms ke ±60 ms. Langkah ini masuk setup di TECH dan README.
