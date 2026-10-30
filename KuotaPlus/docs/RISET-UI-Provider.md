# Aplikasi operator menjual, Kuota+ harus menjelaskan

Riset per 30 Oktober 2026. Semua path screenshot di dokumen ini relatif dari folder `docs/`.

Tujuh aplikasi operator terbesar di Indonesia (MyTelkomsel, by.U, myIM3, bima+, myXL, AXISNET, MySF) memakai pola beranda yang hampir sama. Di atas ada sapaan dan nomor HP. Lalu ada kartu ringkasan pulsa, kuota, dan poin. Di bawahnya ada banner promo, deretan ikon, dan kartu paket "Untukmu". Tampilannya putih dengan satu warna merek yang mencolok, font sans geometris, dan angka yang tebal. Maskot hampir tidak dipakai di dalam aplikasi. Yang ada hanya robot "SMARTY" di materi toko MySF dan tokoh ilustrasi di AXISNET. Persona lainnya berupa chatbot bernama: Veronika, Indira, dan Sarah. Animasi tidak terdokumentasi di sumber mana pun, tetapi gamifikasinya berat: spin wheel, stamp, misi, undian mobil. Secara bisnis, aplikasi ini dioptimalkan untuk menjual paket, bukan untuk membantu pengguna berhemat. Buktinya ada lima: harga paket berbeda per orang, "unlimited" yang tetap kena FUP, kuota hangus (kini dikoreksi Mahkamah Konstitusi), fitur super app yang membuat aplikasi membengkak sampai ratusan MB, dan satu grup yang menjalankan dua sampai tiga aplikasi terpisah. Keluhan teratas pengguna justru soal hal dasar: lambat, gagal login, dan info kuota yang tidak akurat. Celah ini yang paling berguna untuk Kuota+. Aplikasi yang jujur soal harga per GB, memprediksi kapan kuota habis, memberi poin untuk pemakaian hemat, dan memakai maskot lucu hanya di momen emosional akan terasa berbeda dari semua incumbent. Syaratnya, Kuota+ tetap menjaga aturan "warna punya arti" dan kontras WCAG AA.

## Tujuh aplikasi, satu cetakan beranda

Pasar seluler Indonesia praktis dikuasai tiga grup. Pada Q1 2026, Telkomsel punya **153,67 juta pelanggan**, Indosat (IM3 + Tri) **94,0 juta**, dan XLSMART (XL + AXIS + Smartfren) **67,40 juta** ([Bisnis.com](https://teknologi.bisnis.com/read/20260707/101/1986220/jumlah-pelanggan-telkomsel-indosat-dan-xlsmart-jelang-tambahan-frekuensi-26-ghz)). by.U, merek digital Telkomsel, sudah menembus **10 juta pengguna aktif** pada Q3 2025 ([Selular.id](https://selular.id/2025/10/by-u-tembus-10-juta-pengguna-kuasai-pasar-digital-operator/)). Karena itu riset ini memakai level merek dan aplikasi, bukan level grup. Pembagian pelanggan di dalam grup (IM3 vs Tri, XL vs AXIS vs Smartfren) tidak dipublikasikan. Jadi urutan bima+, AXISNET, dan MySF tidak bisa dipastikan.

Dari screenshot yang benar-benar dilihat, myIM3 dan bima+ nyaris kembar. Keduanya punya sapaan, chip tipe kartu, kartu ringkasan tiga kolom (**Saldo | Kuota | Poin**), tombol Reload / Buy / Redeem, banner, deretan ikon bulat, lalu "Hot Promo" atau "Special for You" (`riset/research_notes/Riset UI aplikasi provider Indonesia/_screens/myim3/1.jpg`, `.../_screens/bimaplus/3.jpg`; [App Store myIM3](https://apps.apple.com/id/app/id888610275), [App Store bima+](https://apps.apple.com/id/app/id1276444056)). Changelog keduanya juga sering memakai kalimat yang sama. Ini tanda satu design system yang hanya diganti warna mereknya. AXISNET (screenshot bertanggal mock 2023) paling ramai. Header ungunya memuat tokoh ilustrasi besar, dua kartu berdampingan (PULSA dan PAKET KAMU dengan cincin), ikon 3D warna-warni, dan section magenta "Hanya Untukmu" (`.../_screens/axisnet/1.jpg`). MySF menampilkan saldo di strip hitam dengan tombol merah "Top Up", lalu **empat cincin magenta** untuk Internet, Midnight, Multimedia, dan Bonus (`.../_screens/mysf/1.jpg`). by.U, di screenshot yang tampaknya dari 2022, menampilkan "Rincian Pemakaian" sebagai **tiga bar horizontal** berwarna biru, hijau, dan oranye (`.../_screens/byu/4.jpg`). Hanya by.U dan MySF yang menggambar kuota sebagai grafik di beranda. Aplikasi lain cukup menulis angka.

Beranda MyTelkomsel versi 9.x hanya terlihat di thumbnail YouTube resolusi rendah. Isinya: header gelap dengan pencarian, banner promo lebar di paling atas, tab merek, lalu "Sisa Kuota 2.9 GB / Dari 3.0 GB" sebagai angka biasa (`.../_screens/mytelkomsel/yt_HkWBdROSZQE.jpg`; [YouTube](https://www.youtube.com/watch?v=HkWBdROSZQE)). Jadi Telkomsel menaruh promo di atas angka kuota. Store set MyTelkomsel sekarang tidak menampilkan beranda sama sekali, hanya Detail Paket, grid "Paket Untukmu", Kirim Hadiah, dan Riwayat ([App Store](https://apps.apple.com/id/app/id651412430)). Semua screenshot myXL di App Store dan Play Store berisi iklan merek tanpa UI aplikasi. Yang terlihat hanya header gradasi mint-ke-putih di thumbnail YouTube (`.../_screens/myxl/yt_IFQOu628r-c.jpg`).

| Aplikasi | Navigasi bawah (yang terlihat) | Cara menampilkan kuota | Screenshot |
| --- | --- | --- | --- |
| MyTelkomsel | Label tidak terbaca. Dulu 5 tab: Home, Rewards, Shop, Explore, Profile ([FAQ v4.2](https://www.telkomsel.com/en/support/faq/about-mytelkomsel-42)) | Angka "2.9 GB / 3.0 GB" | `.../_screens/mytelkomsel/` |
| by.U | Tidak terlihat. Tab atas: U-Plan / Updates / U-Tainment | 3 bar berwarna | `.../_screens/byu/4.jpg` |
| myIM3 | 4 tab: myIM3 · Buy · Rewards · Account | Angka di beranda, bar teal di detail | `.../_screens/myim3/1.jpg`, `2.jpg` |
| bima+ | 4 tab: bima+ · Buy · Rewards · Account | Angka | `.../_screens/bimaplus/3.jpg` |
| AXISNET | 5 tab: Home · Playground · **Paket (tombol tengah menonjol)** · Hiburan · Alifetime | Cincin + angka | `.../_screens/axisnet/1.jpg` |
| myXL | Tidak terlihat | Tidak terlihat | `.../_screens/myxl/` (iklan saja) |
| MySF | Tidak terlihat. Ada tab "More" ([Indotelko](https://www.indotelko.com/read/1752015439/sarah-smartfren-siap-layani-pelanggan-24-jam)) | 4 cincin magenta | `.../_screens/mysf/1.jpg` |

Kartu paket di semua aplikasi punya anatomi yang sama. Ada badge di atas, nama paket, **kuota besar dan tebal**, masa aktif, harga dengan **harga coret**, lalu tombol pil "Beli" (`.../_screens/mytelkomsel/5.jpg`, `.../_screens/byu/3.jpg`, `.../_screens/axisnet/1.jpg`). Ada dua pola menarik. Pertama, pembuat paket sendiri: slider kuota 1–150 GB dan masa aktif 1/3/7/30 hari di "Happy Flex" bima+ (`.../_screens/bimaplus/1.jpg`), "Paket Suka-Suka" AXIS, dan "Atur Kuota Sendiri" by.U. Kedua, chip status transaksi MyTelkomsel: Belum Bayar (oranye), Diproses (kuning), Berhasil (hijau), Gagal (merah) (`.../_screens/mytelkomsel/4.jpg`). Arah redesign 2025–2026 juga seragam, yaitu merapikan beranda. myXL 9.5.0 menulis "more compact dashboard" ([App Store myXL](https://apps.apple.com/id/app/id683141076)) dan AXISNET 11.0 menulis "Tampilan Home makin bersih & rapi" ([App Store AXISNET](https://apps.apple.com/us/app/app/id497146073)).

## Putih, satu warna merek, dan angka paling tebal

Tidak ada sumber resmi untuk kode hex atau font di dalam aplikasi mana pun. Semua warna di bawah adalah **perkiraan mata** dari screenshot, bukan hasil sampling piksel. Polanya jelas: UI putih, satu aksen merek yang jenuh, dan properti 3D dekoratif di materi pemasaran. MyTelkomsel memakai merah sekitar #E60023 dengan navy sekitar #0A1F44. myIM3 merah sekitar #E3242B dengan bar teal. bima+ pink-magenta sekitar #E5007E dengan oranye untuk CTA. AXISNET ungu tua sekitar #4B2A7B, magenta, dan hijau limau. by.U biru langit sekitar #2DB8F0 dengan oranye. myXL biru sekitar #1A3DB8 dengan mint. MySF magenta sekitar #F0247A dengan hitam. Tidak ada aplikasi yang terlihat punya mode gelap.

Masalahnya untuk Kuota+: hampir semua incumbent memakai **merah atau magenta sebagai warna merek dan tombol "Beli"**. Di aplikasi mereka, merah berarti "beli" sekaligus "gagal" (chip Gagal di riwayat MyTelkomsel). Kuota+ sudah memutuskan merah hanya untuk boros, gagal, dan habis. Jadi biru #1E40AF sebagai satu-satunya warna aksi adalah pembeda yang sah, bukan kekurangan.

Untuk tipografi, satu-satunya fakta kuat adalah Telkomsel. Rebrand Juni 2021 memperkenalkan font khusus **Telkomsel Batik Sans** buatan Deni Anggara, yang terinspirasi lengkung batik ([Gizmologi](https://gizmologi.id/news/telco/logo-baru-telkomsel/); [Campaign Asia](https://campaignasia.com/article/telkomsel-unifies-50-identities-in-brand-relaunch/470443)). Apakah font itu dipakai di dalam aplikasi belum terkonfirmasi. Aplikasi lain tampak memakai sans geometris mirip Poppins atau Gilroy. Angka kuota dan harga selalu jadi teks paling tebal di setiap kartu. Suara brand paling khas ada di AXIS: deskripsinya dibuka dengan "Dear Warganet Tercinta", pakai istilah "wahana", dan sudut pandang "Aku" ([App Store AXISNET](https://apps.apple.com/us/app/app/id497146073)). Ini lebih layak ditiru daripada aset visualnya.

## Maskot hampir absen, gamifikasi justru berlimpah

Riset teks tidak menemukan maskot resmi di MyTelkomsel, by.U, myIM3, bima+, myXL, atau AXISNET. Persona yang ada berupa chatbot: **Veronika** di MyTelkomsel ([App Store](https://apps.apple.com/id/app/mytelkomsel/id651412430)), **Indira** di myIM3 ([Kontan](https://investasi.kontan.co.id/news/indosat-ooredoo-isat-meluncurkan-chat-bot-indira)), dan **Sarah** di MySF ([Indotelko](https://www.indotelko.com/read/1752015439/sarah-smartfren-siap-layani-pelanggan-24-jam)). by.U sengaja tidak memakai maskot atau brand ambassador. Mereka mengandalkan budaya meme, komunitas, dan kreator ([Selular.id](https://selular.id/2025/10/by-u-tembus-10-juta-pengguna-kuasai-pasar-digital-operator/)). IM3 memakai selebritas seperti Iqbaal Ramadhan, Chicco Kurniawan, dan Kunto Aji ([Gizmologi](https://gizmologi.id/news/kampanye-simpelnya-im3/); [SWA](https://swa.co.id/read/469428/foto-bisnis-swa--gaya-ngepop-im3-untuk-menangkal-spam-dan-scam)). Screenshot memberi koreksi kecil. Materi toko MySF v8 menampilkan **robot berlayar pink** (catatan visual menyebutnya "SMARTY") di luar bingkai ponsel (`.../_screens/mysf/1.jpg`). AXISNET memakai tokoh manusia ilustrasi di header. Keduanya lebih mirip ilustrasi pemasaran daripada maskot yang bereaksi terhadap keadaan aplikasi. Artinya, **maskot lucu yang punya ekspresi sesuai state adalah ruang kosong** di kategori ini.

Animasi tidak terdokumentasi di sumber tertulis mana pun. Splash, skeleton, transisi, dan animasi sukses semuanya butuh pengamatan langsung di perangkat. Yang terdokumentasi rapi adalah gamifikasi. MyTelkomsel punya Daily Login, **Wheel of POIN**, Game Hub dengan check-in harian, dan "Stamp Berhadiah" ([FAQ Telkomsel](https://www.telkomsel.com/en/support/faq/about-mytelkomsel-42); [rilis Telkomsel 2024](https://www.telkomsel.com/about-us/news/mytelkomsel-hadir-sebagai-super-app-yang-memberikan-kemudahan-transaksi-dan)). AXISNET punya Playground, AXIS Stamp dari misi, AXIS Coin, dan level "Alifetime". by.U punya uCoin, Ustamp, Mini Games, serta hadiah kuota di bulan ke-3/6/9/12 dan saat ulang tahun ([App Store by.U](https://apps.apple.com/us/app/by-u-id/id1483475992)). IM3 menjalankan undian **Pesta Hadiah IMPoin 2026**. Mulai tahun ini pengguna bisa memilih hadiah incarannya dan melihat jumlah tiket ([Selular.id](https://selular.id/2026/10/im3-gelar-pesta-hadiah-impoin-2026-siapkan-2-026-hadiah/)). Pola "pilih target, lihat progres" ini cocok dipinjam Kuota+ untuk "poin hemat menuju diskon".

Pelajaran dari luar telco memperjelas batas pemakaian maskot. Duolingo mendesain ulang Duo dengan prinsip siluet dulu, dengan warna dan spesies yang tidak boleh berubah ([Duolingo blog](https://blog.duolingo.com/reshaping-duo/)). Tapi notifikasi Duo yang membuat pengguna merasa bersalah banyak dikritik, sampai disamakan dengan "chat mantan toxic" ([The Sun Malaysia](https://thesun.my/going-viral/netizens-say-duolingo-notifications-feel-like-toxic-ex-texts); [Cursor TU/e](https://cursor.tue.nl/en/opinion/alain-starke/guilt-tripped-by-an-owl)). Tokopedia membangun "semesta" Toped. Karakter pendukungnya sengaja dibuat tidak menutupi maskot utama ([Tokopedia Design](https://medium.com/tokopedia-design/making-a-universe-for-toped-and-tokopedia-ae799d46275d)).

## Enam praktik yang menguntungkan operator tapi merugikan pengguna

**Harga dipersonalisasi.** MyTelkomsel menampilkan paket berbeda per pengguna. Pemakai data berat melihat bundel besar, pengguna baru kadang dapat harga perkenalan, dan flash sale sering tidak muncul di beranda ([GNFI, Jun 2026](https://www.goodnewsfromindonesia.id/2026/06/29/mengapa-harga-paket-internet-berbeda-beda-setiap-penggunanya)). Studi ulasan juga mencatat keluhan "harga beda untuk pelanggan berbeda" ([Telkom University](https://repository.telkomuniversity.ac.id/pustaka/files/239491/bab1/analisis-sentimen-opini-publik-terkait-layanan-kuota-internet-aplikasi-mytelkomsel-melalui-ulasan-di-playstore-dan-appstore-dalam-bentuk-buku-karya-ilmiah.pdf)). Bagi operator, ini menaikkan konversi. Bagi pengguna, dua orang serumah bisa melihat harga beda untuk paket "sama", dan tidak ada cara mengecek apakah "rekomendasi" memang termurah. Kepercayaan rusak justru di titik keputusan beli.

**Istilah yang tidak jujur.** Paket "unlimited" tetap kena FUP dan banyak diprotes ([Bisnis.com](https://teknologi.bisnis.com/read/20240311/101/1748307/fup-di-layanan-internet-unlimited-banyak-diprotes-apa-itu)). Smartfren bahkan menjual "Booster" untuk menambah kuota FUP pada paket unlimited ([Detikinet](https://inet.detik.com/telecommunication/d-5110138/mengenal-booster-unlimited-untuk-paket-internet-smartfren)). Contoh lain: Rollover ISTIMEWA IM3 memberi **kuota lebih sedikit dengan harga hampir sama** dibanding paket reguler ([Bisnis.com, Sep 2026](https://teknologi.bisnis.com/read/20260928/101/2007945/im3-indosat-punya-rollover-istimewa-harga-hampir-mirip-paket-freedom)). Kuota yang dipecah menjadi utama, aplikasi, dan malam membuat angka GB di etalase tampak besar, tetapi nilai pakainya lebih kecil.

**Kuota hangus.** Putusan MK No. 273/PUU-XXIII/2025 (23 Juli 2026) mewajibkan operator menyediakan opsi agar sisa kuota tetap bisa dipakai tanpa biaya tambahan, misalnya lewat rollover, perpanjangan, konversi, atau refund. Sebelum putusan itu, rollover hanya berlaku untuk paket tertentu dan bersyarat beli ulang ([Katadata](https://katadata.co.id/digital/teknologi/6a6975012ae22/ylki-minta-kppu-awasi-potensi-kartel-usai-putusan-mk-soal-kuota-internet-hangus)). Poin Telkomsel juga hangus otomatis tiap 31 Desember ([Telkomsel](https://www.telkomsel.com/jelajah/jelajah-lifestyle/bisa-dapat-hadiah-dari-poin-telkomsel-ini-cara-menukarnya)). Ini mekanisme "sunk cost" yang mendorong pembelian dan penukaran impulsif.

**Super app yang membengkak.** MyTelkomsel berukuran **382,8 MB** di iOS dan memuat tiket perjalanan, lari, BPJS, voucher 100+ merek, dan game ([App Store](https://apps.apple.com/id/app/mytelkomsel/id651412430)). Telkomsel bahkan ingin aplikasinya dipakai untuk bayar parkir sampai cicil rumah ([Bisnis.com](https://teknologi.bisnis.com/read/20240808/101/1789365/telkomsel-ingin-mytelkomsel-bisa-dipakai-bayar-parkir-hingga-cicil-rumah)). myXL berukuran **475,1 MB** ([App Store myXL](https://apps.apple.com/id/app/id683141076)). Pendapatan dari fitur non-inti ini tidak pernah diungkap. Sementara itu keluhan teratas tetap soal crash, loading lambat, navigasi membingungkan, gagal login, dan info kuota tidak akurat ([Telkom University](https://repository.telkomuniversity.ac.id/pustaka/files/239491/jurnal_eproc/analisis-sentimen-opini-publik-terkait-layanan-kuota-internet-aplikasi-mytelkomsel-melalui-ulasan-di-playstore-dan-appstore-dalam-bentuk-buku-karya-ilmiah.pdf)). Telkomsel sampai membuat aplikasi terpisah "MyTelkomsel Basic", yang ratingnya hanya **3,02** ([AppGoblin](https://appgoblin.info/apps/com.tsel.telkomselku)). Keberadaan aplikasi versi ringan itu sendiri adalah pengakuan bahwa aplikasi utamanya terlalu berat.

**Satu grup, banyak aplikasi.** Setelah merger, XLSMART tetap menjalankan myXL, AXISNET, dan mySF dengan tiga sistem poin terpisah. Penukaran XL Poin di Hari Pelanggan 2025 hanya bisa lewat myXL ([Selular.id](https://selular.id/2025/09/xlsmart-apresiasi-pelanggan-dengan-program-poin-dan-kejutan-spesial-di-hari-pelanggan-nasional-2025/)). Indosat juga menjalankan myIM3 dan bima+ yang strukturnya kembar. Bagi pengguna multi-SIM, yang umum di Indonesia, artinya memasang dua sampai tiga aplikasi besar untuk satu perusahaan.

**Gangguan dan aturan yang aneh.** Pop-up penawaran paket yang terlalu sering adalah keluhan berulang di myIM3 ([IT Telkom Purwokerto](https://repository.ittelkom-pwt.ac.id/8241/5/BAB%20I.pdf)). AXISNET mengirim **500 juta+ notifikasi per bulan** ([MoEngage case study](https://www.casestudies.com/company/moengage/case-study/how-axisnet-drives-higher-engagement-growing-maus-by-895)). Paket keluarga Akrab memakai aturan "siapa cepat dia dapat", sehingga anggota yang sudah diberi batas tetap bisa tidak kebagian kuota ([Liputan6](https://www.liputan6.com/tekno/read/4714978/ini-cara-kontrol-pemakaian-kuota-data-internet-dalam-satu-paket)). Ada juga kasus pengguna sudah bayar lewat VA, tetapi kuota tidak masuk dan tidak ada jalur pemulihan di aplikasi ([App Store bima+](https://apps.apple.com/id/app/bima/id1276444056?l=en)).

Supaya adil, ada praktik baik yang patut diakui. MyTelkomsel menyediakan **Jaga Pulsa** agar pulsa tidak tersedot saat kuota habis ([Telkomsel](https://www.telkomsel.com/jelajah/jelajah-lifestyle/cara-pulsa-telkomsel-tidak-tersedot-saat-kuota-habis)). AXISNET punya tombol "Lock" dengan tujuan serupa. myXL menambah "Cek Tiket Aduan" dengan status real-time ([Selular.id](https://selular.id/2025/11/pelanggan-xlsmart-kini-bisa-cek-tiket-aduan-di-aplikasi-myxl/)). by.U menjual transparansi lewat slogan "no hidden fees" dan kartu tanpa masa aktif. Fitur yang melindungi pengguna, walaupun mengurangi pendapatan jangka pendek, ternyata bisa dijual sebagai nilai.

## Rekomendasi konkret untuk redesign Kuota+

### Arah desain

Kuota+ sebaiknya tidak meniru incumbent mana pun secara visual. Arah yang disarankan: **"utilitas tenang, karakter hangat"**. Layar kerja (beranda, katalog, analisis, checkout) tetap bersih, angka di depan, satu warna aksi. Kehangatan datang dari copywriting, bentuk sudut yang membulat, dan maskot yang muncul hanya di momen emosional. Polanya: myIM3/bima+ untuk ketenangan struktur, by.U untuk transparansi dan bar pemakaian, AXIS untuk suara brand yang akrab. Jangan tiru kepadatan AXISNET atau banner-di-atas-angka ala MyTelkomsel.

### Tipografi

Ganti font sistem dengan **Plus Jakarta Sans** sebagai satu-satunya keluarga font. Font ini dibuat Tokotype untuk identitas kota Jakarta, berlisensi OFL, punya sumbu berat variabel, dan sejak v2.600 menyediakan tabular figures ([GitHub tokotype](https://github.com/tokotype/PlusJakartaSans)). Bundel file font sebagai asset, jangan lewat `google_fonts`, supaya tidak ada dependensi baru, tetap jalan offline, dan tidak ada lompatan layout di web. Inter adalah cadangan yang aman. Satu hal wajib diuji: render "111" dan "888" dengan `FontFeature.tabularFigures()` dan pastikan lebarnya sama. Kalau gagal, pakai Inter.

| Peran | Ukuran / tinggi baris / berat | Catatan |
| --- | --- | --- |
| Angka utama beranda (sisa kuota) | 36 / 40 / 700 | Tabular, unit "GB" 16/500 abu-abu |
| Angka sekunder (pulsa, masa aktif, harga) | 24 / 32 / 600 | Tabular |
| Judul layar | 22 / 28 / 600 | `titleLarge` |
| Judul kartu | 16 / 24 / 600 | `titleMedium` |
| Teks biasa | 14 / 20 / 400 | 16/24 untuk teks panjang |
| Label, chip, keterangan | 12 / 16 / 500 | Tidak ada teks di bawah 11 px |

Tidak ada angka 48 px ke atas, dan hanya satu angka terbesar per layar. Format angka Indonesia: "Rp25.000", "12,5 GB".

### Palet: aturan "warna punya arti" tetap, ditambah tiga tint

Token yang ada sudah benar dan lolos AA. Jangan ganti biru ke oranye "ceria". Oranye akan bertabrakan dengan kuning tua yang berarti berisiko. Tambahkan hanya tint latar untuk chip dan kartu status. Semua pasangan di tabel ini sudah dihitung dengan rumus WCAG.

| Token | Hex | Pemakaian | Kontras teks |
| --- | --- | --- | --- |
| `primary` (tetap) | #1E40AF | Satu-satunya warna aksi, tab aktif, link | 8,1:1 di `background` |
| `primaryContainer` (baru) | #EAF0FF | Latar kartu rekomendasi, chip terpilih | `primary` 7,65:1; `textMuted` 6,62:1 |
| `successContainer` | #DCFCE7 | Latar chip "Aman" / "Hemat" | `success` 4,57:1 (jangan dimudakan) |
| `warningContainer` | #FEF3C7 | Latar chip "Berisiko" | `warning` 4,51:1 (pas-pasan, jangan dimudakan) |
| `dangerContainer` | #FEE2E2 | Latar chip "Habis" / "Gagal" | `danger` 5,3:1 |
| `textMuted` (tetap) | #4B5563 | Label, keterangan | 7,0:1. Jangan ganti ke #64748B, yang hanya 4,44:1 di `background` |

Maskot memakai biru `primary`, putih, dan satu biru muda dekoratif. Maskot tidak pernah memakai hijau, kuning tua, atau merah, supaya tidak dibaca sebagai status. Simpan semua warna sebagai token `ColorScheme`/`ThemeExtension` supaya mode gelap nanti tinggal menambah satu tema.

### Layout dan navigasi

Pertahankan `NavigationBar` 5 tab (Beranda, Paket, Analisis, Reward, Riwayat). Jumlah ini sesuai praktik 4–5 tab incumbent, dan "Paket" di posisi kedua sama seperti "Buy" di myIM3/bima+. Tombol tengah yang menonjol ala AXISNET tidak perlu, karena membeli bukan tujuan utama Kuota+. Untuk beranda, ada tiga perubahan.

1. Pindahkan **kartu kuota ke posisi pertama** sebagai angka utama, dengan bar atau cincin bertanda di kedua ujung ("5,3 GB dari 15 GB"). Pulsa dan masa aktif turun jadi angka sekunder. Pertanyaan pertama pengguna adalah "berapa sisa kuotaku?", bukan saldo.
2. Taruh kartu prediksi tepat di bawahnya.
3. Jangan ada banner carousel. Rekomendasi muncul sebagai satu kartu teaser, dan hanya kalau memang ada penghematan.

Ganti "Spinner di tengah" saat memuat dengan **skeleton abu-abu seukuran nilai asli**, tanpa gradasi shimmer dan tanpa layout bergeser. Ganti juga emoji 🐷 dan 💡 di wireframe dengan ikon garis biasa atau pose kecil maskot. Untuk kartu paket, pakai anatomi yang sudah dikenal pengguna Indonesia (nama, kuota besar, masa aktif, harga, tombol Beli), lalu tambahkan **harga per GB**. Pakai harga coret hanya kalau memang ada diskon nyata dari poin.

### Aturan maskot

Satu karakter dengan siluet sederhana. Contohnya karakter "tetes kuota" atau "bar sinyal" yang dibangun dari lingkaran dan persegi membulat. Siapkan sekitar enam pose. Maskot selalu dekoratif bagi pembaca layar (`ExcludeSemantics`). Makna selalu ada di teks dan warna di sebelahnya.

| Keadaan aplikasi | Maskot | Tempat |
| --- | --- | --- |
| Onboarding / pertama kali | Melambai | Layar penuh, bisa di-skip |
| Kuota aman | Tidak muncul | Angka yang memimpin |
| Kuota berisiko | Agak khawatir, opsional, plus teks dan tombol "Lihat paket hemat" | Kartu prediksi |
| Kuota habis | Mengantuk/"baterai kosong", tenang, tidak memarahi | Beranda, dengan tombol "Isi ulang" |
| Pembayaran berhasil | Merayakan sekitar 1,5 detik, sekali saja | Layar S08 `paid` |
| Pembayaran gagal | **Tidak muncul** | Alur uang harus serius |
| Riwayat/notifikasi kosong | Pose istirahat kecil + satu kalimat + satu tombol | Hanya empty state layar penuh |
| Poin didapat / hari hemat beruntun | Bersorak + confetti sekali | Layar Reward |
| Rentetan hemat putus | Menyemangati ("Mulai lagi hari ini") | Layar Reward |

Maskot dilarang muncul di form checkout, daftar metode bayar, OTP, dan di dalam grafik. Maskot juga tidak boleh dipakai untuk membuat pengguna merasa bersalah di notifikasi. Produksi pertama cukup berupa 5–6 PNG/SVG statis lewat `Image.asset`, dianimasikan dengan `AnimatedScale`/`AnimatedSlide` bawaan. Rive menjadi upgrade opsional: satu file `.riv` dengan state machine `mood` dan trigger `celebrate`. Rive lebih cocok daripada Lottie untuk karakter yang punya banyak state ([pub.dev rive](https://pub.dev/packages/rive)).

### Aturan motion dan pilihan Flutter

Motion adalah umpan balik, bukan pertunjukan. Animasikan paling banyak 1–2 elemen per layar. Bungkus durasi dan easing bawaan Flutter dalam satu kelas `Motion` di folder theme. Jangan tulis angka milidetik langsung di widget ([Durations](https://api.flutter.dev/flutter/material/Durations-class.html); [Easing](https://api.flutter.dev/flutter/material/Easing-class.html)).

| Interaksi | Durasi | Easing / API |
| --- | --- | --- |
| Tekan kartu/tombol | 100–150 ms, skala 0,97 + ripple | `Easing.standard`, `InkWell` |
| Pilih chip (filter, nominal, metode bayar) | 150 ms | `HapticFeedback.selectionClick()` |
| Hitung naik sisa kuota + isi bar/cincin | 500–700 ms, dari nilai lama, hanya saat muat/refresh | `TweenAnimationBuilder`, `Easing.emphasizedDecelerate`, angka tabular |
| Ganti state (memuat → berhasil/kosong/error) | 200 ms fade | `AnimatedSwitcher` |
| Bottom sheet, halaman masuk | 400 ms | `Easing.emphasizedDecelerate` |
| Keluar | 200 ms | `Easing.emphasizedAccelerate` |
| Langkah checkout | Geser horizontal | `SharedAxisTransition` (paket `animations`) |
| Kartu paket → detail | Pilih salah satu, jangan dua-duanya | `Hero` atau `OpenContainer` |
| Bayar berhasil | Centang digambar sekitar 400 ms, struk langsung tampil | `HapticFeedback.mediumImpact()` |
| Bayar gagal | Instan, tanpa goyangan | Pesan di blok yang gagal + "Coba lagi" |
| Confetti poin | ≤1,2 detik, ≤40 partikel, hanya saat poin benar-benar didapat | `CustomPainter` sendiri |

Dependensi baru cukup satu, yaitu `animations` dari flutter.dev ([pub.dev](https://pub.dev/packages/animations)), ditambah `rive` kalau maskot animasi disetujui. Lewati `flutter_animate`, `lottie`, dan `confetti`. Bungkus cincin kuota dan maskot dengan `RepaintBoundary`. Animasikan transform dan opacity, jangan ukuran layout. Hormati pengaturan kurangi animasi lewat `MediaQuery.of(context).disableAnimations || accessibleNavigation`. Kalau aktif, durasi jadi nol, confetti dan loop maskot dimatikan, tetapi perubahan warna dan teks tetap jalan. Flag ini **tidak** terpasang oleh "Reduce Motion" di iOS ([api.flutter.dev](https://api.flutter.dev/flutter/widgets/MediaQueryData/disableAnimations.html)). Perilakunya di Chrome web juga perlu dites manual.

### Fitur yang membedakan Kuota+

Ada lima diferensiasi yang langsung lahir dari kelemahan incumbent. Kelimanya sudah ada di rencana Kuota+, jadi tinggal ditonjolkan di UI.

| Fitur | Kelemahan incumbent yang dijawab |
| --- | --- |
| **Rekomendasi "paling hemat untukmu" dengan harga per GB dan alasan terbuka** | Harga personal yang tidak bisa dicek |
| **Prediksi tanggal kuota habis vs tanggal paket berakhir** | Tidak ditemukan incumbent yang memprediksi. Info kuota sering dikeluhkan tidak akurat |
| **Poin untuk hari hemat, bukan untuk belanja** | Poin incumbent hanya dari transaksi dan login harian, lalu hangus |
| **Pemakaian per aplikasi + insight** | Incumbent hanya menampilkan sisa per jenis kuota |
| **Satu aplikasi ringan, tanpa pop-up dan banner** | Aplikasi 270–475 MB, pop-up dan notifikasi massal |

Ada dua tambahan murah yang selaras dengan putusan MK dan praktik baik. Pertama, tampilkan "kuota yang akan hangus" beserta tanggal dan jamnya, dan sarankan cara memakainya. Kedua, tampilkan poin yang akan kedaluwarsa dengan nada informatif, bukan "tukar sekarang sebelum hangus!".

### Anti-pattern yang harus dihindari

| Jangan | Lakukan |
| --- | --- |
| Banner carousel di atas angka kuota | Angka kuota paling atas, rekomendasi satu kartu |
| Pop-up penawaran saat membuka aplikasi | Teaser hanya kalau `saving_30d > 0` |
| Harga beda per pengguna tanpa penjelasan | Harga katalog sama untuk semua, rekomendasi menyebut alasannya |
| Kata "unlimited" atau GB headline yang menyembunyikan kuota aplikasi | Pisahkan "Utama" dan "Video" seperti wireframe S04 |
| Merah sebagai warna merek atau tombol Beli | Merah hanya untuk habis/gagal/boros |
| Gradasi di kartu dan tombol, ikon dalam lingkaran berwarna di setiap kartu | Kartu putih, satu border **atau** satu bayangan |
| Maskot di checkout/OTP/grafik, maskot yang memarahi | Maskot hanya di momen emosional |
| Shimmer satu layar penuh, spinner untuk area konten | Skeleton abu-abu seukuran nilai |
| Confetti setiap buka aplikasi, spin wheel, misi login harian | Hadiah hanya untuk perilaku hemat yang nyata |
| Uang terpotong tanpa jalur pemulihan | Status transaksi jelas, "Lanjutkan bayar", poin dikembalikan saat gagal |
| Fitur gaya hidup di luar tugas inti | Cek kuota, beli, analisis, hemat. Cukup itu |

## Apa yang belum terverifikasi

Beberapa batas riset ini perlu dicatat terang-terangan.

**Screenshot.** Banyak screenshot sudah tua. Beranda by.U tampak dari 2022 (layar uCoin bertuliskan "Berlaku sampai 31 Des 2022"), dan AXISNET dari 2023 (tanggal mock Okt/Des 2023). Jadi keduanya belum tentu mencerminkan UI versi 2026. Store screenshot juga mockup pemasaran yang dibingkai dan dipotong.

**Visual yang hilang.** **Beranda myXL tidak terlihat sama sekali**. Semua screenshot toko berisi iklan, dan thumbnail YouTube terlalu kecil untuk dibaca. **Beranda MyTelkomsel versi 9.x** hanya terlihat di thumbnail resolusi rendah, dan label navigasi bawahnya tidak terbaca. Navigasi bawah by.U, myXL, dan MySF juga tidak terlihat.

**Warna dan font.** **Semua hex warna incumbent adalah perkiraan mata**, bukan hasil sampling piksel. Jangan dikutip sebagai fakta. Font di dalam aplikasi tidak bisa dipastikan dari screenshot, termasuk apakah MyTelkomsel memakai Telkomsel Batik Sans.

**Data pasar dan ulasan.** **Pembagian pelanggan di dalam grup** (IM3 vs Tri, XL vs AXIS vs Smartfren) tidak dipublikasikan, jadi urutan "5 besar" di bawah tiga grup tidak pasti. Ulasan Google Play terbaru tidak bisa diambil, sehingga sentimen pengguna bersandar pada studi akademik dan ulasan App Store yang sebagian sudah tua. Kaskus dan Reddit tidak ditelusuri.

**Hal yang belum ditemukan.** Animasi, splash, dan state sukses di aplikasi incumbent, keberadaan fitur prediksi kuota di incumbent, dan perbandingan harga aplikasi vs outlet tidak ditemukan. Ketiadaan bukti di sini tidak sama dengan bukti ketiadaan.

**Rekomendasi Flutter.** Dukungan tabular figures Plus Jakarta Sans di mesin teks Flutter, perilaku `disableAnimations` di Chrome web, dan perubahan besar paket `animations` 3.0.0 belum diuji di proyek.

## Kesimpulan

Pelajaran terbesarnya bukan soal visual. Desain incumbent sudah matang dan saling mirip. Kuota+ tidak akan menang lewat warna atau ilustrasi yang lebih ramai. Bedanya ada di **untuk siapa layar itu bekerja**. Aplikasi operator dibangun untuk menaikkan pendapatan per pelanggan. Hasilnya: banner di atas angka, harga yang berbeda per orang, poin yang hangus, dan ratusan MB fitur sampingan, sementara keluhan soal hal dasar tidak juga selesai. Kuota+ bisa membalik urutannya. Angka dan prediksi di depan, harga per GB terbuka, dan hadiah untuk perilaku hemat.

Maskot adalah satu-satunya ruang visual yang benar-benar kosong di kategori ini. Tapi nilainya bergantung pada disiplin. Maskot yang muncul di checkout atau memarahi pengguna akan mengulang kesalahan Duolingo. Maskot yang hanya muncul saat pengguna berhasil berhemat atau baru selesai membayar akan menjadi wajah dari posisi Kuota+ sebagai aplikasi yang memihak pengguna. Putusan MK soal kuota hangus juga menggeser arah industri ke transparansi. Fitur yang di proyek kuliah terasa seperti "nilai tambah" kemungkinan besar sebentar lagi menjadi standar.
