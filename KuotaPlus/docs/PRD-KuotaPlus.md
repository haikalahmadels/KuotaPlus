# PRD Kuota+

Oct 29, 2026 · @Haikal Ahmad El Salman

## Ringkasan

Kuota+ adalah aplikasi resmi satu operator untuk pelanggan prabayar. Selain cek pulsa, kuota, masa aktif, beli paket, dan isi ulang, aplikasi ini menganalisis pemakaian data per aplikasi, memprediksi kapan kuota habis, merekomendasikan paket termurah yang cukup, dan memberi poin bagi pengguna yang hemat. Poin bisa ditukar diskon paket.

**Konteks proyek:** tugas kuliah individu. Hasilnya prototipe yang bisa didemokan, tanpa deadline. Penilaian mengutamakan kompleksitas dan inovasi fitur.

| Aspek | Keputusan |
| --- | --- |
| Client | Flutter: Android (utama) dan Chrome Web |
| Backend | Laravel (REST API) + MySQL, dijalankan lokal di Laragon |
| Data operator | Disimulasikan oleh Laravel (tidak ada integrasi operator nyata) |
| Pembayaran | Payment gateway dummy yang meniru alur nyata: invoice, status pending, kedaluwarsa, callback |
| Pemakaian per aplikasi | Android: data asli dari `NetworkStatsManager`. Web: hanya menampilkan data yang sudah tersinkron dari Android atau data seed |
| Panel admin | Filament di dalam project Laravel yang sama, diakses lewat browser di /admin |

## Problem statement

Pelanggan prabayar membayar lebih mahal dari yang perlu karena tidak tahu ke mana kuotanya habis dan kapan akan habis. Aplikasi operator saat ini hanya menampilkan **sisa** kuota. Tidak ada penjelasan **kenapa** kuota berkurang atau **paket apa** yang cocok untuk pola pemakaian mereka.

Pihak yang dirugikan:

- **Pelanggan prabayar berbudget ketat** (pelajar, mahasiswa, pekerja informal). Kuota habis sebelum masa aktif selesai, lalu mereka beli paket darurat harian yang harga per GB-nya lebih mahal.
- **Pelanggan yang over-buy.** Mereka membeli paket besar "biar aman" padahal pemakaian sebulan jauh di bawah kuotanya. Sisa kuota hangus saat masa aktif paket berakhir.
- **Pelanggan yang kuotanya tersedot aplikasi tertentu** (video pendek, update otomatis, sinkronisasi foto). Mereka tidak sadar dan tidak tahu harus mengatur apa.
- **Operator.** Pelanggan yang merasa "kuotanya cepat habis tanpa sebab" cenderung churn ke operator lain. Operator juga tidak punya kanal untuk mengarahkan pelanggan ke paket yang tepat.

Akar masalahnya: informasi pemakaian ada di perangkat pengguna (per aplikasi), sedangkan informasi paket dan harga ada di operator. Belum ada aplikasi yang menggabungkan keduanya menjadi keputusan: "beli paket X, cukup sampai tanggal Y, hemat Rp Z".

## Target user dan persona

**Target user:** semua pelanggan prabayar operator di Indonesia yang memakai smartphone Android. Pengguna web (Chrome) adalah pelanggan yang sama yang membuka akun dari laptop. Di web mereka bisa cek, beli, dan melihat analisis, tetapi tidak bisa mengirim data pemakaian.

### Persona 1: Rina, mahasiswa berbudget ketat

| Atribut | Detail |
| --- | --- |
| Usia, pekerjaan | 20 tahun, mahasiswa semester 5 |
| Budget pulsa | Rp50.000–75.000 per bulan dari uang saku |
| Pola pakai | TikTok dan Instagram 3–4 jam/hari, Zoom kuliah 2x seminggu, WhatsApp |
| Masalah | Kuota 15 GB habis di hari ke-20. Ia lalu membeli paket harian Rp5.000/1 GB 3–4 kali |
| Yang ia butuhkan | Peringatan dini, tahu aplikasi mana yang boros, dan paket yang pas sebulan penuh |
| Motivasi reward | Tinggi. Diskon Rp5.000 terasa berarti |

### Persona 2: Pak Budi, pekerja yang over-buy

| Atribut | Detail |
| --- | --- |
| Usia, pekerjaan | 42 tahun, sales lapangan |
| Budget pulsa | Rp150.000 per bulan, dibayar kantor |
| Pola pakai | WhatsApp, Google Maps, email, sesekali YouTube. Di rumah dan kantor memakai Wi-Fi |
| Masalah | Membeli paket 50 GB, terpakai rata-rata 12 GB. Sekitar 38 GB hangus setiap bulan |
| Yang ia butuhkan | Bukti angka bahwa paket lebih kecil cukup, dan pembelian yang cepat tanpa ribet |
| Motivasi reward | Rendah. Ia tertarik karena penghematan langsung, bukan poin |

## Goals dan non-goals

### Goals

1. Pengguna bisa cek pulsa, kuota per paket, dan masa aktif kartu dalam 1 layar (beranda).
2. Pengguna bisa melihat pemakaian data seluler per aplikasi: hari ini, 7 hari, dan 30 hari terakhir.
3. Sistem memprediksi tanggal kuota habis dan menampilkan selisihnya terhadap tanggal berakhirnya paket.
4. Sistem merekomendasikan paket termurah yang menutup kebutuhan 30 hari, lengkap dengan estimasi hemat dalam rupiah.
5. Pengguna bisa membeli paket dan isi ulang pulsa end-to-end lewat payment gateway dummy yang alurnya realistis.
6. Pengguna yang hemat mendapat poin otomatis. Poin bisa ditukar menjadi diskon saat checkout paket.
7. Seluruh alur bisa didemokan di Android dan Chrome Web dengan backend Laravel lokal (Laragon).
8. Pengguna bisa berbagi kuota utama ke nomor lain dari operator yang sama, maksimal 2 GB per 30 hari, dibayar dengan poin.
9. Admin bisa mengelola katalog paket, kategori aplikasi, dan parameter reward, serta memantau transaksi dan metrik dari panel admin.

### Non-goals

- Integrasi API operator nyata, provisioning kuota sungguhan, atau penagihan sungguhan.
- Payment gateway nyata (Midtrans, Xendit, dan sejenisnya).
- Dukungan iOS. iOS tidak menyediakan data pemakaian per aplikasi untuk aplikasi pihak ketiga.
- Multi-operator dan multi-nomor dalam satu akun.
- Memblokir atau membatasi pemakaian data aplikasi lain (firewall atau VPN).
- Model machine learning. Prediksi memakai statistik sederhana yang bisa dijelaskan (lihat FR Prediksi).
- Berbagi kuota aplikasi khusus, berbagi ke nomor operator lain, atau menarik kembali kuota yang sudah dibagikan.
- Panel admin dengan banyak peran (superadmin, CS), serta aksi admin yang mengubah saldo pulsa, kuota, atau poin pelanggan secara manual.
- Pascabayar, roaming, telepon, dan SMS.

## User stories

| ID | Fitur | User story |
| --- | --- | --- |
| US-01 | Akun | Sebagai pelanggan, saya ingin masuk dengan nomor HP dan OTP, supaya tidak perlu mengingat password. |
| US-02 | Beranda | Sebagai pelanggan, saya ingin melihat pulsa, sisa kuota, dan masa aktif di satu layar, supaya tahu kondisi kartu dalam sekali buka. |
| US-03 | Beranda | Sebagai pelanggan dengan beberapa paket aktif, saya ingin melihat sisa dan tanggal berakhir tiap paket, supaya tahu kuota mana yang dipakai duluan. |
| US-04 | Analisis | Sebagai Rina, saya ingin melihat aplikasi mana yang paling banyak memakai kuota minggu ini, supaya bisa mengurangi pemakaian aplikasi itu. |
| US-05 | Analisis | Sebagai pelanggan, saya ingin melihat tren pemakaian harian 30 hari terakhir, supaya tahu hari apa saya boros. |
| US-06 | Prediksi | Sebagai Rina, saya ingin tahu tanggal perkiraan kuota habis, supaya bisa berhemat sebelum terlambat. |
| US-07 | Prediksi | Sebagai pelanggan, saya ingin diberi peringatan saat kuota diprediksi habis sebelum paket berakhir, supaya tidak terpaksa beli paket darurat. |
| US-08 | Prediksi | Sebagai pelanggan, saya ingin melihat "jatah harian" (sisa kuota dibagi sisa hari), supaya punya batas pemakaian yang konkret. |
| US-09 | Rekomendasi | Sebagai Pak Budi, saya ingin melihat paket yang cukup untuk pemakaian saya dan berapa rupiah yang dihemat, supaya berani pindah ke paket lebih kecil. |
| US-10 | Rekomendasi | Sebagai pelanggan, saya ingin tahu alasan sebuah paket direkomendasikan, supaya saya percaya rekomendasinya. |
| US-11 | Beli paket | Sebagai pelanggan, saya ingin membeli paket dengan pulsa atau metode pembayaran lain, supaya tetap bisa beli saat pulsa kurang. |
| US-12 | Isi ulang | Sebagai pelanggan, saya ingin isi ulang pulsa dengan nominal pilihan, supaya masa aktif kartu bertambah. |
| US-13 | Pembayaran | Sebagai pelanggan, saya ingin melihat status transaksi (menunggu, berhasil, gagal, kedaluwarsa), supaya tahu uang saya ke mana. |
| US-14 | Reward | Sebagai Rina, saya ingin mendapat poin setiap hari pemakaian saya di bawah jatah harian, supaya hemat terasa ada hasilnya. |
| US-15 | Reward | Sebagai pelanggan, saya ingin memakai poin sebagai diskon saat checkout paket, supaya poin punya nilai nyata. |
| US-16 | Reward | Sebagai pelanggan, saya ingin melihat riwayat poin masuk dan keluar, supaya tahu dari mana poin saya berasal. |
| US-17 | Izin | Sebagai pelanggan Android, saya ingin tahu kenapa aplikasi meminta akses data pemakaian, supaya saya yakin memberikannya. |
| US-18 | Berbagi kuota | Sebagai Pak Budi yang kuotanya berlebih, saya ingin membagikan 1 GB ke nomor anak saya, supaya kuota saya tidak hangus dan anak saya tidak perlu beli paket. |
| US-19 | Berbagi kuota | Sebagai Rina, saya ingin memakai poin hemat untuk membagikan kuota ke teman, supaya poin saya punya kegunaan selain diskon. |
| US-20 | Berbagi kuota | Sebagai pengirim, saya ingin melihat sisa jatah berbagi dan sisa kuota saya setelah berbagi sebelum konfirmasi, supaya tidak kehabisan kuota sendiri. |
| US-21 | Berbagi kuota | Sebagai penerima, saya ingin diberi tahu jumlah kuota yang saya terima dan kapan berakhirnya, supaya bisa memakainya sebelum hangus. |
| US-22 | Admin | Sebagai admin, saya ingin menambah, mengubah, dan menonaktifkan paket, supaya katalog bisa diperbarui tanpa mengubah seeder. |
| US-23 | Admin | Sebagai admin, saya ingin mengubah parameter reward dan berbagi kuota dari panel, supaya aturan bisa disetel tanpa deploy ulang. |
| US-24 | Admin | Sebagai admin, saya ingin melihat transaksi, poin beredar, dan adopsi rekomendasi di dashboard, supaya tahu apakah fitur hemat berjalan dan berapa biayanya. |
| US-25 | Admin | Sebagai admin, saya ingin mengoreksi kategori aplikasi baru, supaya rekomendasi paket aplikasi tetap tepat. |

## Daftar fitur: MVP / v2 / later

**Rekomendasi scope:** keempat fitur pembeda (analisis per aplikasi, prediksi, rekomendasi, reward) masuk MVP. Tugas ini dinilai dari inovasi, jadi tanpa fitur-fitur itu Kuota+ hanya klon aplikasi operator. Untuk mengimbanginya, fitur dasar (cek, beli, isi ulang) dibuat sederhana. Kompleksitas yang tidak menambah nilai inovasi ditunda ke v2.

**Siapa yang menanggung biaya diskon dari poin?** Di produk nyata, setiap poin yang ditukar mengurangi pendapatan operator. Karena itu operator harus membatasi nilai poin, menetapkan masa berlaku, dan mencegah kecurangan. Di prototipe ini tidak ada uang sungguhan. Aturan pembatasnya tetap diterapkan (batas diskon, kedaluwarsa, anti-curang) supaya desainnya realistis.

| Fitur | MVP | v2 | Later |
| --- | --- | --- | --- |
| Login nomor HP + OTP dummy | Ya |  |  |
| Beranda: pulsa, kuota per paket, masa aktif | Ya |  |  |
| Katalog paket + beli paket | Ya |  |  |
| Isi ulang pulsa | Ya |  |  |
| Payment gateway dummy (pulsa, e-wallet, VA, QRIS simulasi) | Ya |  |  |
| Riwayat transaksi | Ya |  |  |
| Sinkronisasi pemakaian per aplikasi (Android) | Ya |  |  |
| Dashboard analisis per aplikasi + tren harian | Ya |  |  |
| Prediksi tanggal kuota habis + jatah harian | Ya |  |  |
| Rekomendasi paket hemat + alasan | Ya |  |  |
| Poin hemat harian + streak | Ya |  |  |
| Tukar poin jadi diskon saat checkout | Ya |  |  |
| Peringatan in-app + notifikasi lokal Android | Ya |  |  |
| Mode demo: generator data pemakaian (untuk web/emulator) | Ya |  |  |
| Berbagi kuota utama (maks 2 GB / 30 hari, bayar poin) | Ya |  |  |
| Panel admin: katalog, kategori aplikasi, transaksi, pelanggan, parameter, metrik | Ya |  |  |
| Push notification server (FCM) |  | Ya |  |
| Target hemat buatan pengguna (misal maks 10 GB/bulan) |  | Ya |  |
| Tips hemat per aplikasi (misal matikan autoplay) |  | Ya |  |
| Misi/tantangan mingguan untuk poin bonus |  | Ya |  |
| Promo dan kampanye di panel admin |  | Ya |  |
| Perbandingan pemakaian vs rata-rata pengguna sejenis |  |  | Ya |
| Model prediksi ML (musiman, hari libur) |  |  | Ya |
| Payment gateway nyata |  |  | Ya |
| Multi-nomor / keluarga |  |  | Ya |
| iOS |  |  | Ya |

## Functional requirements (MVP)

Semua waktu memakai zona Asia/Jakarta (WIB). Satu "hari" = 00:00–23:59 WIB. Satuan kuota disimpan dalam byte dan ditampilkan dalam MB/GB (1 GB = 1024 MB). Angka yang ditandai *usulan* belum final dan tercatat di Open questions.

### FR-1 Akun dan login

1. Login memakai nomor HP. Nomor harus terdaftar di tabel `subscribers` (hasil seed). Ini mensimulasikan bahwa operator hanya melayani nomornya sendiri. Nomor yang tidak terdaftar ditolak dengan pesan "Nomor bukan pelanggan Nusantel". Nusantel adalah operator fiktif untuk prototipe ini (lihat [SEED-KuotaPlus.md](SEED-KuotaPlus.md)).
2. OTP 6 digit, berlaku 5 menit. Kirim ulang baru bisa setelah 60 detik. Maksimal 5 kali salah, lalu nomor dikunci 15 menit.
3. OTP dummy tidak dikirim via SMS. OTP ditampilkan di log Laravel dan di banner "Mode Demo" pada layar OTP.
4. Login yang berhasil mengembalikan token Laravel Sanctum. Token disimpan di `flutter_secure_storage` (Android) atau storage browser (web).
5. Logout menghapus token di server dan di perangkat.

### FR-2 Beranda

1. Menampilkan: saldo pulsa (Rp), masa aktif kartu (tanggal + sisa hari), dan setiap paket aktif (nama, sisa/total kuota, tanggal berakhir). Kuota aplikasi khusus ditampilkan terpisah dari kuota utama.
2. Kartu prediksi: "Kuota diperkirakan habis \[tanggal\]" dengan status **Aman** (habis setelah paket berakhir) atau **Berisiko** (habis sebelum paket berakhir).
3. Kartu jatah harian: "Jatah hari ini X MB, terpakai Y MB" dengan progress bar.
4. Teaser rekomendasi (jika ada hemat > Rp0) dan saldo poin.
5. Pull-to-refresh memanggil `GET /api/home`. Respons terakhir di-cache lokal dan ditampilkan saat offline dengan label "Diperbarui \[waktu\]".
6. Tidak ada paket aktif: tampilkan "Kamu tidak punya kuota aktif" dan tombol ke katalog.

### FR-3 Katalog dan beli paket

1. Katalog dikelompokkan: Harian, Mingguan, Bulanan, Aplikasi (kuota khusus kategori: Video, Sosmed, Game, Belajar).
2. Setiap paket menampilkan harga, kuota utama, kuota aplikasi (jika ada) beserta daftar aplikasinya, dan masa berlaku.
3. Paket yang sedang direkomendasikan diberi lencana "Paling hemat untukmu".
4. Checkout menampilkan harga, input tukar poin (FR-12), total bayar, dan pilihan metode pembayaran (FR-5).
5. Paket berhasil dibeli: paket baru aktif saat itu juga dan berjalan paralel dengan paket lain. Setiap paket punya `expires_at` sendiri. Membeli paket **tidak** memperpanjang masa aktif kartu.
6. Beli paket tidak bisa dilakukan saat kartu sudah melewati masa tenggang (lihat Edge case).

### FR-4 Isi ulang pulsa

1. Nominal tetap: Rp5.000, 10.000, 25.000, 50.000, 100.000. Tidak ada nominal bebas.
2. Metode: semua metode FR-5 kecuali "Pulsa".
3. Isi ulang yang berhasil menambah saldo pulsa dan memperpanjang masa aktif kartu sesuai tabel nominal (*usulan*, OQ-2): 5rb +7 hari, 10rb +15 hari, 25rb +30 hari, 50rb +45 hari, 100rb +60 hari. Perpanjangan dihitung dari masa aktif saat ini, bukan dari hari ini.

### FR-5 Payment gateway dummy

Tujuannya meniru alur gateway nyata, termasuk status asinkron dan callback.

1. Metode yang tersedia: **Pulsa** (hanya untuk beli paket, langsung terpotong), **E-wallet**, **Virtual Account bank**, **QRIS**. Label merek: OQ-5.
2. `POST /api/transactions` wajib membawa header `Idempotency-Key` (UUID dari client). Key yang sama dalam 24 jam mengembalikan transaksi yang sama, bukan transaksi baru.
3. Untuk metode non-pulsa, transaksi dibuat dengan status `PENDING` dan `expires_at` = +15 menit. Respons berisi instruksi bayar: nomor VA 16 digit acak, gambar QR yang di-generate dari `external_ref`, atau URL halaman e-wallet simulasi.
4. **Simulator pembayaran**: halaman web Laravel `/simulator/{external_ref}` dengan tombol "Bayar" dan "Tolak". Halaman ini dibuka dari aplikasi (in-app browser) dan mewakili aplikasi bank atau e-wallet.
5. Tombol di simulator memicu callback server-ke-server `POST /api/payments/callback` dengan signature HMAC-SHA256 di header `X-Signature`. Callback dengan signature salah ditolak (401).
6. Callback `PAID` menjalankan provisioning (tambah paket atau pulsa, catat ledger poin) dalam **satu transaksi database**. Callback yang sama datang dua kali tidak memprovisioning dua kali.
7. Client mengecek status dengan polling `GET /api/transactions/{id}` setiap 3 detik selama layar menunggu terbuka, dan sekali lagi saat aplikasi kembali ke foreground.
8. Status akhir: `PAID`, `FAILED`, `EXPIRED`. Scheduler Laravel (`schedule:run` tiap menit) mengubah `PENDING` yang lewat `expires_at` menjadi `EXPIRED`.
9. Metode Pulsa: saldo dicek dan dipotong secara atomik (row lock). Saldo kurang ditolak dengan pesan berisi kekurangan rupiahnya dan tombol "Isi ulang".

### FR-6 Riwayat transaksi

1. Daftar transaksi terbaru di atas: jenis, nama item, total, poin dipakai, metode, status, waktu.
2. Detail transaksi menampilkan `external_ref`. Transaksi `PENDING` punya tombol "Lanjutkan bayar".
3. Layar Riwayat punya dua tab: "Pembelian" (transaksi beli paket dan isi ulang) dan "Berbagi" (kuota yang dibagikan, FR-14). Datanya diambil dari dua endpoint terpisah, sehingga tidak perlu menggabungkan dua tabel dalam satu daftar berhalaman.

### FR-7 Sinkronisasi pemakaian per aplikasi (Android)

1. Onboarding menampilkan layar penjelasan izin sebelum membuka Settings "Usage Access" (`PACKAGE_USAGE_STATS`). Isinya: data apa yang dibaca (byte data seluler per aplikasi per hari), data apa yang **tidak** dibaca (isi trafik, riwayat browsing), dan bahwa data hanya dikirim ke server Kuota+.
2. Data dibaca lewat platform channel Kotlin ke `NetworkStatsManager.querySummary(TYPE_MOBILE, ...)`. Hasilnya dikelompokkan per UID per hari, lalu UID dipetakan ke nama paket dan label aplikasi lewat `PackageManager`.
3. Hanya data **seluler** yang dihitung. Wi-Fi diabaikan (OQ-12).
4. UID khusus dipetakan ke grup tetap: `UID_REMOVED` menjadi "Aplikasi terhapus", `UID_TETHERING` menjadi "Hotspot", UID sistem menjadi "Sistem Android".
5. Sinkronisasi berjalan saat aplikasi dibuka dan setiap 6 jam lewat WorkManager. Yang dikirim adalah bucket 7 hari terakhir ke `POST /api/usage/sync`.
6. Server melakukan upsert dengan kunci unik (`user_id`, `app_id`, `usage_date`). Sync berulang untuk hari yang sama hanya memproses **selisih byte** (delta), sehingga aman dikirim berkali-kali.
7. Setiap delta pemakaian mengurangi kuota dengan urutan: (a) kuota aplikasi khusus jika aplikasinya termasuk kategori paket tersebut, lalu (b) kuota utama dari paket yang paling cepat berakhir. Pengurangan kuota memakai data asli ini atau simulasi penuh: OQ-1.
8. **Mode Demo** (web, emulator, atau izin ditolak): tombol "Generate data demo" membuat pemakaian 30 hari dari profil (Rina/Budi/acak) lewat endpoint seeder. Data demo ditandai `source = demo` dan ditampilkan dengan label "Data demo". Data demo untuk hari-hari yang sudah lewat **tidak** memotong kuota, karena 30 hari pemakaian sekaligus akan langsung menghabiskan paket. Data ini hanya mengisi analisis, prediksi, rekomendasi, dan evaluasi reward (OQ-1).

### FR-8 Analisis pemakaian

1. Filter periode: Hari ini, 7 hari, 30 hari.
2. Donut chart top 5 aplikasi plus "Lainnya", dalam MB dan persen. Di bawahnya daftar lengkap aplikasi (ikon, nama, MB, persen), terurut dari yang terbesar.
3. Bar chart pemakaian harian, dengan garis jatah harian sebagai pembanding.
4. Detail aplikasi: tren harian aplikasi itu dan rata-rata MB per hari.
5. Insight otomatis maksimal 3 kalimat berbasis aturan, misalnya "TikTok memakai 48% kuotamu minggu ini, naik 20% dari minggu lalu". Insight muncul jika kenaikan pemakaian satu aplikasi ≥ 20% minggu ke minggu, atau jika satu aplikasi mengambil ≥ 40% dari total.
6. Di web, analisis hanya membaca data dari server. Jika belum ada data, tampilkan "Buka Kuota+ di Android untuk mengirim data, atau pakai Mode Demo".

### FR-9 Prediksi kuota habis dan jatah harian

1. Rata-rata harian `avg_daily` = rata-rata tertimbang linear pemakaian 7 hari terakhir (bobot 7 untuk kemarin, 1 untuk 7 hari lalu). Hari ini tidak dihitung karena belum lengkap.
2. `predicted_empty_at` = sekarang + (sisa kuota utama + kuota aplikasi yang relevan) / `avg_daily`.
3. Tingkat keyakinan: ≥ 7 hari data = Tinggi; 3–6 hari = Rendah (ditampilkan dengan label "perkiraan awal"); < 3 hari = prediksi tidak ditampilkan ("Kumpulkan data 3 hari dulu").
4. Status Berisiko jika `predicted_empty_at` < `expires_at` paket utama. Tampilkan juga selisih harinya, misalnya "habis 6 hari lebih cepat".
5. Jatah harian = sisa kuota / sisa hari sampai `expires_at` paket utama terdekat. Dihitung ulang 00:00 WIB dan setiap kali ada pembelian paket.
6. Prediksi dihitung ulang di server setelah setiap sync, lalu disimpan di `forecasts`. Logika prediksi wajib punya unit test (PHPUnit) dengan data uji untuk ketiga level keyakinan.

### FR-10 Rekomendasi paket hemat

1. Butuh minimal 7 hari data. Jika kurang, tampilkan "Rekomendasi tersedia setelah 7 hari pemakaian".
2. Kebutuhan 30 hari = `avg_daily` × 30 × 1,1 (buffer 10%). Kebutuhan dipecah per kategori aplikasi (Video, Sosmed, Game, Belajar, Umum) berdasarkan porsi pemakaian 30 hari terakhir.
3. Untuk setiap paket di katalog: biaya 30 hari = harga × ceil(30 / masa berlaku). Kuota paket juga dikalikan ceil(30 / masa berlaku), sama seperti harganya. Paket "cukup" jika kuota kategori yang tercakup + kuota utama ≥ kebutuhan. Kebutuhan kategori yang tidak tercakup kuota aplikasi diambil dari kuota utama.
4. Pilih paket "cukup" dengan biaya 30 hari terendah. Jika biayanya sama, pilih yang sisa kuotanya paling kecil. Tampilkan 1 rekomendasi utama + maksimal 2 alternatif.
5. Hemat = total `gross_amount` transaksi paket berstatus `PAID` dalam 30 hari terakhir (harga sebelum diskon poin, supaya sebanding dengan harga katalog) − biaya 30 hari rekomendasi. Paket darurat ikut terhitung, sehingga pengguna yang paketnya tidak cukup lalu membeli paket harian tetap melihat penghematan yang benar. Jika hemat ≤ Rp0, tampilkan "Paketmu sekarang sudah paling hemat". Jika belum pernah beli paket dalam 30 hari terakhir, hemat tidak ditampilkan.
6. Setiap rekomendasi punya alasan yang dihasilkan dari template, misalnya: "Pemakaianmu sekitar 14 GB/bulan, 62% dari TikTok dan YouTube. Paket Video 30 hari berisi 10 GB kuota video + 6 GB utama, cukup dengan sisa 1,4 GB."
7. Kombinasi 2 paket tidak direkomendasikan di MVP (OQ-9).
8. Event "ditampilkan", "diklik", dan "dibeli" dicatat di tabel `recommendations` untuk mengukur metrik.

### FR-11 Reward poin hemat

1. Job harian 00:05 WIB mengevaluasi hari kemarin untuk setiap pengguna yang punya paket aktif.
2. **Hari hemat** = pemakaian kemarin ≤ jatah harian kemarin **dan** pemakaian ≥ 50 MB (*usulan*, OQ-4). Batas minimum ini mencegah orang mematikan data hanya demi poin.
3. Hari hemat memberi +10 poin. Setiap kelipatan 7 hari hemat berturut-turut memberi bonus +50 poin. Satu hari bukan-hemat mengembalikan streak ke 0 (*usulan*, OQ-3).
4. Hari dengan data tidak lengkap (tidak ada sync sama sekali hari itu) tidak dievaluasi. Streak tidak putus, tetapi tidak ada poin.
5. Semua mutasi poin dicatat di `point_ledger`. Saldo poin = jumlah `delta`. Tidak ada kolom saldo yang diedit langsung tanpa ledger.
6. Kedaluwarsa: poin berlaku 90 hari sejak didapat dan dipakai FIFO (*usulan*). Job harian mencatat poin yang kedaluwarsa sebagai delta negatif.
7. Layar Reward menampilkan saldo poin, streak saat ini, kalender 30 hari (hijau = hemat, merah = boros, abu-abu = tidak ada data), poin yang akan kedaluwarsa dalam 7 hari, dan riwayat ledger.

### FR-12 Tukar poin jadi diskon

1. Hanya berlaku di checkout **paket**, tidak untuk isi ulang pulsa.
2. Kurs: 1 poin = Rp10. Tukar dalam kelipatan 100 poin. Diskon maksimal 20% dari harga paket (*usulan*, OQ-3).
3. Poin ditahan (ledger `redeem_hold`) saat transaksi dibuat. Jika transaksi `PAID`, hold menjadi final. Jika `FAILED` atau `EXPIRED`, poin dikembalikan lewat ledger `redeem_release`.
4. Total bayar tidak boleh < Rp1.000 setelah diskon.

### FR-13 Peringatan dan notifikasi

1. Pemicu: (a) sisa kuota utama ≤ 20%, (b) status prediksi berubah menjadi Berisiko, (c) paket berakhir ≤ 1 hari, (d) masa aktif kartu ≤ 3 hari, (e) transaksi berubah status.
2. Android: notifikasi lokal (`flutter_local_notifications`) yang dipicu setelah sync atau polling. Web: banner in-app di beranda.
3. Maksimal 1 notifikasi per jenis per hari. Setiap notifikasi membuka layar yang relevan (deep link).

### FR-14 Berbagi kuota

1. Menu "Bagi Kuota" ada di beranda. Hanya **kuota utama** yang bisa dibagikan. Kuota aplikasi khusus dan kuota hasil berbagi dari orang lain tidak bisa dibagikan ulang.
2. **Penerima** wajib terdaftar di `subscribers` dengan status `active` dan bukan nomor pengirim sendiri. Penerima tidak perlu punya akun Kuota+. Nomor yang tidak valid ditolak sebelum masuk layar konfirmasi.
3. **Pilihan jumlah:** kelipatan 500 MB, yaitu 500 MB, 1 GB, 1,5 GB, dan 2 GB (*usulan*, OQ-15). Pilihan yang melanggar aturan 4 atau 5 dinonaktifkan dengan alasannya.
4. **Batas pengirim:** total kuota yang dibagikan dalam 30 hari terakhir (rolling, dihitung dari transfer berstatus `completed`) + jumlah baru ≤ 2 GB. Layar menampilkan "Sisa jatah berbagi X GB, pulih \[tanggal\]".
5. **Sisa minimal:** total sisa kuota utama pengirim di semua paket aktif, setelah dikurangi jumlah yang dibagikan, harus ≥ 2 GB. Contoh: untuk membagikan 500 MB, pengirim harus punya sisa kuota utama ≥ 2,5 GB.
6. **Biaya poin:** 100 poin per 500 MB (*usulan*, OQ-15). Poin kurang akan ditolak, dengan tombol ke layar Reward. Poin dipotong FIFO dan dicatat di `point_ledger` dengan tipe `spend_share`.
7. **Sumber kuota:** dipotong dari kuota utama paket yang paling cepat berakhir terlebih dahulu. Satu transfer boleh memotong lebih dari satu paket.
8. **Masa berlaku di penerima:** `expires_at` = yang lebih awal di antara (sekarang + 7 hari) dan `expires_at` paket sumber yang paling akhir dipotong. Tujuannya mencegah berbagi dijadikan cara memperpanjang kuota (OQ-16).
9. Di sisi penerima, kuota tercatat sebagai `subscriptions` dengan `source = shared`, `package_id` kosong, dan `app_total` = 0. Pemotongannya mengikuti urutan biasa (FR-7.7).
10. **Konfirmasi:** layar ringkasan (nomor penerima, jumlah, poin yang dipakai, masa berlaku, sisa kuota pengirim setelah berbagi), lalu verifikasi OTP memakai mekanisme FR-1 (OQ-14). Layar ringkasan menyebutkan bahwa transfer tidak bisa dibatalkan.
11. **Eksekusi atomik:** `POST /api/quota-transfers` membawa `Idempotency-Key`. Server mengunci baris paket dan poin pengirim, memeriksa ulang aturan 2–6, lalu memotong kuota, memotong poin, membuat paket penerima, dan mencatat `quota_transfers` sebagai `completed`. Semua itu dalam satu transaksi database. Jika satu langkah gagal, semuanya di-rollback.
12. **Tidak ada pembatalan.** Kuota yang sudah diterima tidak bisa ditarik kembali oleh pengirim.
13. **Notifikasi:** pengirim melihat transfer di layar Riwayat, pada tab "Berbagi" yang terpisah dari tab "Pembelian" (FR-6.3). Penerima yang punya akun Kuota+ mendapat notifikasi "Kamu menerima 1 GB dari 0812••••7890, berlaku sampai \[tanggal\]". Penerima tanpa akun mendapat SMS dummy (dicatat di log Laravel).
14. **Dampak ke fitur lain:** transfer tidak masuk `usage_records` dan tidak dihitung sebagai pemakaian. Prediksi dan jatah harian pengirim dan penerima langsung dihitung ulang. Evaluasi reward memakai jatah harian snapshot pukul 00:00, sehingga berbagi di siang hari tidak mengubah penilaian hari itu.

### FR-15 Panel admin

**Keputusan teknologi:** Filament di dalam project Laravel yang sama, diakses di `/admin` lewat browser desktop. Filament menyediakan CRUD, tabel dengan filter, form tervalidasi, dan widget grafik siap pakai. Satu dependency ini menggantikan puluhan view Blade yang harus ditulis manual. Waktu pengerjaan bisa dialihkan ke fitur pembeda. Panel admin tidak dibuat di aplikasi Flutter.

1. **Login:** tabel `admins` terpisah dengan guard Laravel `admin` serta email + password (bcrypt). Hanya ada satu peran admin. Akun dibuat lewat seeder atau perintah artisan, tanpa halaman registrasi. Login dibatasi 5 percobaan per menit per IP.
2. **Dashboard:** widget jumlah dan nilai transaksi (hari ini, 30 hari), pendapatan bersih setelah diskon poin, total diskon poin, poin beredar (nilai rupiah yang menjadi tanggungan operator), kuota yang dibagikan dalam 30 hari, % pembelian dari rekomendasi, % pengguna Android dengan Usage Access aktif, dan grafik transaksi harian 30 hari. Isinya mengikuti tabel Success metrics.
3. **Paket:** CRUD katalog. Paket yang pernah dibeli tidak bisa dihapus, hanya dinonaktifkan (`is_active = false`). Perubahan harga hanya berlaku untuk transaksi baru. Transaksi lama tetap memakai harga yang tersimpan di `gross_amount`.
4. **Kategori aplikasi:** mengubah kategori setiap aplikasi. Aplikasi baru yang pertama kali muncul dari sync masuk `umum` dan ditandai "Belum ditinjau". Perubahan kategori berlaku untuk perhitungan berikutnya dan tidak mengubah kuota yang sudah terpotong.
5. **Rekomendasi setelah katalog berubah:** setiap perubahan paket menyimpan `catalog_updated_at`. Jika rekomendasi milik pengguna lebih lama dari waktu itu, rekomendasi dihitung ulang saat pengguna membukanya berikutnya. Tidak perlu queue worker.
6. **Transaksi:** hanya baca. Ada filter status, metode, jenis, dan rentang tanggal. Detail transaksi menampilkan log `payment_callbacks`.
7. **Pelanggan:** hanya baca. Menampilkan nomor, status kartu, pulsa, masa aktif, paket aktif, saldo poin, riwayat transaksi, riwayat berbagi kuota, dan **total** pemakaian harian.
8. **Privasi:** admin **tidak** bisa melihat pemakaian per aplikasi milik pelanggan tertentu. Statistik per aplikasi hanya tersedia sebagai agregat seluruh pelanggan (misal "TikTok = 31% dari total trafik").
9. **Berbagi kuota:** daftar transfer, hanya baca, dengan filter pengirim, penerima, dan tanggal.
10. **Pengaturan:** semua parameter yang berlabel *usulan* disimpan di tabel `settings`, bukan di kode. Daftarnya: poin per hari hemat, bonus streak, kurs poin, batas diskon, masa berlaku poin, batas minimum pemakaian, tabel masa aktif isi ulang, masa tenggang, batas dan biaya berbagi kuota, dan ambang notifikasi. Setiap key punya validasi rentang. Perubahan berlaku mulai evaluasi atau transaksi berikutnya, tidak retroaktif.
11. **Audit log:** setiap create, update, dan delete oleh admin dicatat di `admin_audit_logs` beserta nilai sebelum dan sesudahnya. Admin tidak bisa mengubah atau menghapus log ini.

## Sketsa data model

MySQL lewat migration Laravel. Semua tabel punya `id` (BIGINT PK) dan `created_at`/`updated_at` kecuali disebut lain. Satuan kuota dalam byte (BIGINT), uang dalam rupiah (INT, tanpa desimal).

| Entitas | Field kunci | Catatan |
| --- | --- | --- |
| `subscribers` | `msisdn` (unique), `pulsa_balance`, `active_until`, `grace_until`, `status` (active/grace/terminated) | Data "milik operator". Di-seed. Satu nomor = satu subscriber |
| `users` | `subscriber_id` (FK, unique), `name`, `last_login_at`, `platform` (android/web), `usage_access_granted`, `usage_access_checked_at` | Akun aplikasi. Dibuat saat login pertama. Kolom izin diisi lewat `PUT /api/device` untuk metrik admin (FR-15.2) |
| `otp_codes` | `msisdn`, `purpose` (login/quota\_transfer), `context` (JSON, nullable), `code_hash`, `expires_at`, `attempts`, `locked_until` | OTP disimpan dalam bentuk hash. OTP berbagi kuota terikat ke penerima + jumlah di `context` dan tidak bisa dipakai untuk login |
| `apps` | `package_name` (unique), `label`, `category` (video/sosmed/game/belajar/umum/sistem), `is_reviewed` | Master aplikasi. Kategori di-seed untuk aplikasi populer. Aplikasi tak dikenal masuk `umum` dengan `is_reviewed = false` ("Belum ditinjau") |
| `packages` | `code`, `name`, `type` (harian/mingguan/bulanan/aplikasi), `price`, `main_quota`, `app_quota`, `app_category`, `validity_days`, `is_active` | Katalog. Isi seeder: OQ-6 |
| `subscriptions` | `subscriber_id`, `source` (purchase/shared), `package_id`, `transaction_id`, `main_total`, `main_used`, `app_total`, `app_used`, `app_category`, `started_at`, `expires_at`, `status` (active/exhausted/expired) | Paket milik **nomor** (`subscriber_id`), bukan akun, karena penerima berbagi kuota tidak wajib punya akun Kuota+. `app_category` disalin dari paket saat dibeli. Paket milik pengguna. Bisa lebih dari satu aktif. Kolom tambahan source (purchase/shared). Untuk kuota hasil berbagi, package\_id dan transaction\_id kosong |
| `usage_records` | `user_id`, `app_id`, `usage_date`, `bytes_mobile`, `bytes_applied`, `source` (device/demo), `synced_at` | Unique (`user_id`, `app_id`, `usage_date`). `bytes_applied` = byte yang sudah dipotong dari kuota, dipakai untuk menghitung delta |
| `forecasts` | `user_id`, `computed_at`, `avg_daily_bytes`, `remaining_bytes`, `predicted_empty_at`, `daily_budget_bytes`, `confidence` (high/low/none), `status` (safe/risk) | Baris terbaru = prediksi aktif. Riwayatnya dipakai untuk mengukur akurasi |
| `daily_evaluations` | `user_id`, `eval_date`, `usage_bytes`, `budget_bytes`, `result` (hemat/boros/no\_data), `streak_after` | Unique (`user_id`, `eval_date`). Sumber kalender reward |
| `recommendations` | `user_id`, `package_id`, `rank`, `need_bytes`, `cost_30d`, `saving_30d`, `reason`, `shown_at`, `clicked_at`, `purchased_transaction_id` | Satu batch per perhitungan |
| `transactions` | `user_id`, `type` (package/topup), `package_id` (nullable), `topup_amount` (nullable), `gross_amount`, `discount_amount`, `points_used`, `net_amount`, `payment_method`, `status` (pending/paid/failed/expired), `idempotency_key` (unique per user), `request_hash`, `recommendation_id` (nullable FK), `external_ref` (unique), `payment_payload` (JSON: VA/QR/URL), `expires_at`, `paid_at` | Satu-satunya pintu masuk perubahan pulsa dan paket. `request_hash` mendeteksi key sama dengan body berbeda. `recommendation_id` mengisi `recommendations.purchased_transaction_id` saat `PAID` |
| `payment_callbacks` | `external_ref`, `payload` (JSON), `signature_valid`, `processed_at` | Log callback mentah untuk audit dan pengecekan idempotensi |
| `point_ledger` | `user_id`, `delta`, `type` (earn\_daily/earn\_streak/redeem\_hold/redeem\_release/spend\_share/expire), `ref_type`, `ref_id`, `remaining`, `expires_at` | Saldo poin = SUM(`delta`). `remaining` dipakai untuk FIFO kedaluwarsa pada baris earn |
| `notifications` | `user_id`, `kind`, `notified_on` (date), `payload`, `delivered_at` (nullable) | Unique (`user_id`, `kind`, `notified_on`) untuk batas 1 notifikasi per jenis per hari. `delivered_at` mencegah alert yang sama dikirim dua kali ke client |
| `quota_transfers` | sender\_user\_id, recipient\_subscriber\_id, bytes, points\_spent, recipient\_subscription\_id, expires\_at, idempotency\_key, request\_hash, status (completed/failed), completed\_at | Batas 2 GB / 30 hari = SUM(bytes) status completed milik pengirim dengan completed\_at ≥ sekarang − 30 hari. Index (sender\_user\_id, completed\_at) |
| `quota_transfer_sources` | quota\_transfer\_id, subscription\_id, bytes | Mencatat paket pengirim mana saja yang dipotong (FR-14.7) dan berapa byte dari masing-masing |
| `admins` | name, email (unique), password (bcrypt), last\_login\_at | Guard admin, terpisah dari users. Satu peran |
| `settings` | key (unique), value (JSON), min, max, is\_system, updated\_by\_admin\_id | Semua parameter usulan (FR-15.10). Di-cache, dan cache dihapus setiap kali ada perubahan. Nilai awal dari seeder. Key `is_system` (misalnya `catalog.updated_at`) tidak tampil di form admin |
| `admin_audit_logs` | admin\_id, action (create/update/delete), entity\_type, entity\_id, before (JSON), after (JSON), ip, created\_at | Hanya bisa ditambah, tidak bisa diubah atau dihapus |

Relasi utama: `subscribers` 1–1 `users`; `subscribers` 1–N `subscriptions`; `users` 1–N `usage_records`, `transactions`, `point_ledger`; `packages` 1–N `subscriptions`; `apps` 1–N `usage_records`; `transactions` 1–0..1 `subscriptions`.

Relasi tambahan: `transactions` N–0..1 `recommendations`; `users` 1–N `quota_transfers` (sebagai pengirim); `quota_transfers` 1–1 `subscriptions` (paket penerima) dan 1–N `quota_transfer_sources`; `admins` 1–N `admin_audit_logs`.

## Edge case dan failure state

| Area | Kondisi | Perilaku yang diharapkan |
| --- | --- | --- |
| Izin | Pengguna menolak Usage Access | Analisis, prediksi, rekomendasi, dan reward menampilkan empty state + tombol "Beri izin" dan "Pakai Mode Demo". Cek, beli, dan isi ulang tetap jalan |
| Izin | Izin dicabut setelah sebelumnya diberikan | Sync gagal diam-diam. Banner "Data pemakaian berhenti diperbarui sejak \[tanggal\]". Hari tanpa sync dievaluasi `no_data` |
| Data | Data < 3 hari / < 7 hari | Prediksi disembunyikan / rekomendasi disembunyikan (FR-9, FR-10) |
| Data | Lonjakan satu hari (misal update OS 3 GB) | Tetap masuk rata-rata. Insight menandai "Lonjakan tidak biasa pada \[tanggal\]" jika pemakaian > 3× median 7 hari |
| Data | Pemakaian 0 selama berhari-hari (pakai Wi-Fi) | `avg_daily` = 0, prediksi menampilkan "Kuota aman sampai paket berakhir". Tidak ada poin karena di bawah batas minimum |
| Data | Dual SIM | Android 10+ tidak mengizinkan aplikasi biasa memfilter pemakaian per SIM. Semua data seluler dianggap milik nomor ini (OQ-7) |
| Data | Jam perangkat dimanipulasi | Server memakai `usage_date` dari bucket NetworkStats, menolak tanggal di masa depan, dan memakai waktu server untuk evaluasi reward |
| Data | Sync yang sama terkirim dua kali / data hari lalu dikirim ulang | Upsert + delta: kuota tidak terpotong ganda. Delta negatif (angka mengecil) diabaikan dan dicatat di log |
| Kuota | Beberapa paket aktif | Urutan potong: kuota aplikasi yang sesuai kategori, lalu kuota utama dari paket yang paling cepat berakhir (FR-7.7) |
| Kuota | Kuota habis, paket belum berakhir | Status `exhausted`. Beranda menampilkan "Kuota habis" + rekomendasi. Pulsa tidak dipotong (OQ-11) |
| Kuota | Paket berakhir dengan sisa kuota | Status `expired`, sisa kuota hangus. Riwayat mencatat "X GB hangus". Angka ini dipakai insight over-buy |
| Kartu | Masa aktif habis | Masuk masa tenggang 15 hari (*usulan*): hanya bisa isi ulang, tidak bisa beli paket. Setelah masa tenggang lewat: `terminated`, login ditolak |
| Bayar | Pulsa tidak cukup | Ditolak sebelum transaksi dibuat. Tampilkan kekurangan Rp dan tombol "Isi ulang" |
| Bayar | Tombol bayar ditekan dua kali / jaringan putus lalu retry | `Idempotency-Key` yang sama mengembalikan transaksi yang sama |
| Bayar | Pengguna menutup aplikasi saat `PENDING` | Transaksi tetap ada di riwayat dengan tombol "Lanjutkan bayar" sampai `expires_at` |
| Bayar | Callback datang setelah `EXPIRED` | Ditolak (409) dan dicatat di `payment_callbacks`. Tidak ada provisioning |
| Bayar | Callback ganda | Diproses sekali (cek status + row lock). Callback kedua mengembalikan 200 tanpa efek |
| Bayar | Signature callback salah | 401, `signature_valid = false`, tidak ada perubahan |
| Bayar | Provisioning gagal setelah `PAID` (error DB) | Seluruh transaksi DB di-rollback, callback mengembalikan 500, simulator menampilkan "Coba lagi". Tidak boleh ada status `PAID` tanpa paket |
| Poin | Transaksi dengan poin `FAILED`/`EXPIRED` | `redeem_release` mengembalikan poin persis sejumlah hold |
| Poin | Poin diminta > saldo atau > batas 20% | Input dibatasi di client dan divalidasi ulang di server (422) |
| Poin | Poin kedaluwarsa saat sedang di-hold | Hold tetap berlaku. Kedaluwarsa hanya memotong `remaining` yang tidak di-hold |
| Jaringan | Laragon mati / API tidak terjangkau | Tampilkan cache terakhir + banner "Tidak bisa terhubung ke server". Aksi tulis (beli, isi ulang) dinonaktifkan |
| Jaringan | HP fisik tidak bisa mengakses `localhost` | Base URL API dikonfigurasi ke IP LAN laptop (misal `http://192.168.x.x`) lewat `--dart-define`. Laragon di-bind ke `0.0.0.0` |
| Web | CORS dari Flutter Web ke Laravel | `config/cors.php` mengizinkan origin dev Flutter Web |
| Web | Fitur Android-only dibuka di web | Platform check `kIsWeb`: tombol sync disembunyikan, Mode Demo ditawarkan |
| Sesi | Token kedaluwarsa / dicabut | Respons 401 mengarahkan ke login, lalu kembali ke layar asal setelah login |
| Berbagi | Nomor penerima tidak terdaftar, sedang masa tenggang, atau nomor sendiri | Ditolak di langkah input dengan alasan spesifik. OTP tidak dikirim |
| Berbagi | Dua transfer dikirim bersamaan dari dua perangkat | Row lock pada paket dan poin pengirim. Transfer kedua memeriksa ulang batas 2 GB, sisa minimal, dan poin. Jika melanggar, ditolak |
| Berbagi | Kuota pengirim berkurang karena sync di antara layar ringkasan dan OTP | Aturan diperiksa ulang saat eksekusi. Jika sisa minimal 2 GB tidak terpenuhi lagi, transfer ditolak dan poin tidak dipotong |
| Berbagi | Paket sumber berakhir kurang dari 7 hari lagi | Kuota penerima berakhir bersamaan dengan paket sumber terakhir (FR-14.8). Tanggalnya ditampilkan di layar ringkasan |
| Berbagi | Retry jaringan dengan Idempotency-Key yang sama | Mengembalikan transfer yang sama. Kuota dan poin tidak terpotong dua kali |
| Berbagi | Satu nomor menerima kuota dari banyak pengirim | Tidak dibatasi di MVP (OQ-17). Setiap kiriman menjadi paket shared terpisah |
| Admin | Paket dinonaktifkan saat ada transaksi PENDING untuk paket itu | Transaksi PENDING tetap bisa dibayar dengan harga tersimpan. Paket hilang dari katalog dan dari rekomendasi berikutnya |
| Admin | Kurs poin diubah saat ada transaksi dengan poin yang sedang di-hold | Transaksi itu tetap memakai discount\_amount yang tersimpan. Kurs baru berlaku untuk transaksi baru |
| Admin | Nilai setting di luar rentang (misal batas berbagi 0 atau negatif) | Ditolak oleh validasi form min/max. Nilai lama tetap berlaku |
| Admin | Akses /admin tanpa login atau memakai token pelanggan | Redirect ke halaman login admin. Token Sanctum pelanggan tidak berlaku di guard admin |

## Success metrics

Prototipe dianggap **selesai** jika semua kriteria "Definition of done" terpenuhi. Metrik produk dicatat oleh sistem dan ditunjukkan saat demo sebagai bukti bahwa instrumentasinya ada. Angka metrik produk tidak bisa divalidasi tanpa pengguna nyata.

### Definition of done (prototipe)

| Kriteria | Target | Cara membuktikan |
| --- | --- | --- |
| Skenario demo end-to-end | Login, cek beranda, lihat analisis, lihat prediksi, terima rekomendasi, beli paket rekomendasi dengan poin via QRIS dummy, cek kuota bertambah: tanpa error di Android **dan** Chrome | Rekaman demo |
| Data asli Android | Sync pemakaian per aplikasi dari HP fisik tampil di dashboard dan sesuai dengan Settings > Penggunaan data (selisih ≤ 5%) | Screenshot berdampingan |
| Akurasi prediksi | MAPE tanggal habis ≤ 20% pada 3 dataset profil (Rina, Budi, acak) dengan backtest: prediksi di hari ke-7, bandingkan dengan hari habis sebenarnya | Unit test PHPUnit |
| Kebenaran rekomendasi | Pada dataset uji, paket terpilih selalu "cukup" dan biaya 30 harinya ≤ semua paket lain yang cukup | Unit test PHPUnit |
| Ketahanan pembayaran | Callback ganda, callback setelah kedaluwarsa, signature salah, dan double-submit tidak menghasilkan provisioning ganda | Feature test Laravel |
| Integritas poin | SUM(`point_ledger.delta`) selalu = saldo yang ditampilkan. Poin hold selalu kembali saat transaksi gagal | Feature test Laravel |
| Performa lokal | p95 latensi API ≤ 500 ms di Laragon. Beranda tampil ≤ 2 detik setelah dibuka | Log Laravel / Telescope |
| Aturan berbagi kuota | Batas 2 GB / 30 hari, sisa minimal 2 GB, dan biaya poin tidak bisa dilanggar, termasuk lewat request paralel dan retry. Kuota pengirim berkurang tepat sebesar kuota yang diterima penerima | Feature test Laravel (termasuk uji 2 request bersamaan) |
| Panel admin | Admin mengubah harga paket dan parameter reward di panel, lalu perubahannya terlihat di aplikasi Flutter tanpa mengubah kode. Setiap perubahan tercatat di audit log | Rekaman demo |

### Metrik produk (jika dirilis ke pengguna nyata)

| Metrik | Definisi | Target awal (usulan) |
| --- | --- | --- |
| Opt-in Usage Access | % pengguna Android yang memberi izin dalam 7 hari pertama | ≥ 60% |
| Adopsi rekomendasi | % pembelian paket yang berasal dari rekomendasi | ≥ 25% |
| Penghematan riil | Rata-rata `saving_30d` dari pembelian lewat rekomendasi | ≥ Rp10.000/pengguna/bulan |
| Pembelian darurat | Jumlah pembelian paket harian dalam 7 hari sebelum paket utama berakhir, dibanding sebelum memakai Kuota+ | Turun ≥ 30% |
| Kuota hangus | Rata-rata GB hangus per pengguna per bulan | Turun ≥ 20% |
| Engagement reward | % pengguna aktif dengan ≥ 1 hari hemat per minggu | ≥ 40% |
| Guardrail: ARPU | Pendapatan per pengguna tidak turun > 10%. Rekomendasi hemat tidak boleh merusak bisnis operator | Dipantau |
| Pemakaian berbagi kuota | % pengguna aktif yang berbagi kuota ≥ 1 kali per bulan, dan % poin yang dipakai untuk berbagi dibanding untuk diskon | ≥ 10% pengguna. Rasio poin dipantau |

## Open questions

Setiap pertanyaan punya usulan default supaya pengembangan tidak terhambat. Usulan itu bukan keputusan.

Parameter angka di OQ-2, OQ-3, OQ-4, dan OQ-15 disimpan di tabel `settings` dan bisa diubah dari panel admin (FR-15.10). Usulan default menjadi nilai awal seeder, jadi angka-angka ini tidak perlu final sebelum mulai coding.

| ID | Pertanyaan | Usulan default |
| --- | --- | --- |
| OQ-1 | Apakah sisa kuota di backend dikurangi oleh pemakaian **asli** dari HP (hasil sync), atau sepenuhnya simulasi? | Dikurangi data asli untuk akun Android, data demo untuk akun web/emulator. Konsekuensinya: kuota demo bisa habis sungguhan saat dipakai harian. **Diputuskan:** data demo hari-hari lampau yang dibuat Mode Demo tidak memotong kuota (FR-7.8) |
| OQ-2 | Berapa tambahan masa aktif per nominal isi ulang, dan berapa lama masa tenggang? | Tabel di FR-4.3, masa tenggang 15 hari |
| OQ-3 | Nilai poin: poin per hari hemat, bonus streak, kurs, batas diskon, masa berlaku | 10 poin/hari, +50 per 7 hari beruntun, 1 poin = Rp10, maks 20% harga paket, berlaku 90 hari. Dengan angka ini Rina mendapat sekitar Rp3.000–4.500 per bulan |
| OQ-4 | Berapa pemakaian minimum harian agar sebuah hari layak dapat poin? | 50 MB |
| OQ-5 | Metode pembayaran dummy memakai nama dan logo merek asli (GoPay, OVO, BCA) atau label generik ("E-Wallet", "Bank A")? | Label generik, untuk menghindari kesan bahwa aplikasi ini terhubung ke layanan merek itu |
| OQ-6 | Apa isi katalog paket (nama, harga, kuota, kategori, masa berlaku)? | Sekitar 10 paket di seeder: 3 harian, 2 mingguan, 3 bulanan, 2 paket aplikasi (Video, Sosmed). Harga mengikuti kisaran pasar prabayar 2026. **Diputuskan:** 10 paket aktif + 1 paket nonaktif untuk uji, lihat SEED-KuotaPlus.md |
| OQ-7 | Untuk pengguna dual SIM, apakah semua data seluler diterima sebagai pemakaian nomor ini? | Ya, dan ditulis sebagai keterbatasan di dokumentasi |
| OQ-8 | Daftar aplikasi apa saja yang di-seed beserta kategorinya? | 30 aplikasi terpopuler di Indonesia. Sisanya otomatis masuk `umum`. **Diputuskan:** daftar di SEED-KuotaPlus.md |
| OQ-9 | Apakah rekomendasi boleh berupa kombinasi 2 paket (utama + aplikasi)? | Tidak di MVP. Masuk v2 jika dibutuhkan |
| OQ-10 | Saat membeli paket yang sama dengan paket aktif, apakah kuotanya digabung atau berjalan sebagai paket terpisah? | Terpisah, masing-masing dengan `expires_at` sendiri |
| OQ-11 | Saat kuota habis, apakah pemakaian memotong pulsa dengan tarif dasar per MB? | Tidak. Internet dianggap berhenti, pulsa tidak dipotong |
| OQ-12 | Apakah pemakaian Wi-Fi ditampilkan di analisis sebagai informasi? | Tidak di MVP. Hanya data seluler |
| OQ-13 | Apakah state management Flutter dan library chart ditentukan dosen atau bebas? | Bebas. Usulan: Riverpod + `fl_chart`. **Diputuskan:** bebas, memakai Riverpod + `fl_chart` (lihat TECH-KuotaPlus.md) |
| OQ-14 | Konfirmasi berbagi kuota memakai OTP, PIN transaksi baru, atau cukup layar konfirmasi? | OTP, memakai ulang mekanisme FR-1. PIN berarti harus membuat fitur baru: pembuatan, reset, dan penguncian PIN |
| OQ-15 | Berapa biaya poin untuk berbagi kuota, dan apa satuan jumlahnya? | Kelipatan 500 MB, 100 poin per 500 MB (setara Rp1.000 dengan kurs OQ-3). Berbagi 2 GB = 400 poin, sekitar 40 hari hemat |
| OQ-16 | "Masa berlaku maksimal 7 hari": apakah benar dipotong mengikuti paket sumber jika paket itu berakhir lebih cepat? | Ya, yang lebih awal di antara 7 hari dan berakhirnya paket sumber (FR-14.8) |
| OQ-17 | Perlukah batas jumlah kuota yang bisa diterima satu nomor dari banyak pengirim? | Tidak di MVP. Jika perlu, tambahkan setting batas terima per 30 hari |
