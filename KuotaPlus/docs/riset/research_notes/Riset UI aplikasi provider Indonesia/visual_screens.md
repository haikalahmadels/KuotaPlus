# Visual design of Indonesian telco self-care apps (from screenshots actually viewed)

Method: store screenshot URLs came from the iTunes Search API (`itunes.apple.com/search?country=id`), which returns the current App Store listing's `screenshotUrls` (mzstatic.com). Google Play listing HTML loaded with curl (play-lh.googleusercontent.com images) and was used for MyTelkomsel and myXL. YouTube result pages and thumbnails (i.ytimg.com) filled gaps. Images are in `_screens/<app>/`, and every file maps to its source URL in `_screens/sources.txt`.

Caveats that apply to everything below:
- **Store screenshots are marketing mockups.** Phones sit inside promo frames, and some show a single screen cropped or tilted. Status-bar times like 9:41 or 09.50 show they are staged.
- **The colors were not pixel-sampled.** No image library was available, so every hex below is an eyeballed estimate ("visual estimate, approximate"), not a measured value.
- **The listing date is not the screen date.** A listing's "version release date" is when the app last updated, and screenshot sets often lag behind. Where the mock data inside a screenshot shows dates, those are noted below.

Sources (listing pages):
- MyTelkomsel: [App Store id651412430](https://apps.apple.com/id/app/id651412430) (v9.4.0, 12 Oct 2026); [Google Play com.telkomsel.telkomselcm](https://play.google.com/store/apps/details?id=com.telkomsel.telkomselcm&hl=id) (updated 16 Okt 2026)
- by.U: [App Store id1483475992](https://apps.apple.com/id/app/id1483475992) (v2.2.5, 1 Oct 2026)
- myIM3: [App Store id888610275](https://apps.apple.com/id/app/id888610275) (v82.18.0, 29 Oct 2026)
- bima+: [App Store id1276444056](https://apps.apple.com/id/app/id1276444056) (v5.17.0, 25 Sep 2026)
- AXISNET: [App Store id497146073](https://apps.apple.com/id/app/id497146073) (v11.0, 25 Sep 2026)
- myXL: [App Store id683141076](https://apps.apple.com/id/app/id683141076) (v9.6.0, 2 Oct 2026); [Google Play com.apps.MyXL](https://play.google.com/store/apps/details?id=com.apps.MyXL&hl=id) (updated 29 Sep 2026)
- MySmartfren: [App Store id1209898190](https://apps.apple.com/id/app/id1209898190) (v7.57.0, 8 Oct 2026). The file names say "Update-mySF-v8".

## What each app's home and dashboard look like (hierarchy, quota and pulsa card, banners)

### Takeaway
The IOH apps (myIM3 and bima+), AXISNET and MySmartfren all open with the same stack: a greeting and phone number, then a summary card with balance, quota and points and quick CTAs, then a banner carousel, an icon grid and a horizontal row of package cards. by.U (in an older screenshot) and MySmartfren are the only ones seen showing quota as a graphic: by.U uses bars and MySmartfren uses rings. Everyone else shows plain numbers. MyTelkomsel's store set no longer shows its home screen. For myXL, store screenshots showed no app UI at all, so its home was seen only in a tiny YouTube thumbnail.

### Cited Findings
- **MyTelkomsel**
  - **Home (seen only in a low-res YouTube thumbnail).** The header is dark with a search bar ("Klaim Hadiah Sp…"), and a full-width promo banner carousel sits at the top ("Hadiah Berlimpah HUT Telkomsel", "5 Juni 2026" in the banner). Below it are brand tabs (SIMPATI / Halo / …), a red chip, "Aktif hingga 10 Mei 2027", "Pulsa Rp0" and "Sisa Kuota 2.9 GB / Dari 3.0 GB" as plain numbers, then "Lihat Semua Kuota". A bottom nav is visible but its labels are unreadable. — [YouTube HkWBdROSZQE thumbnail, ~2026](https://www.youtube.com/watch?v=HkWBdROSZQE)
  - **Store set.** The current set (v9.4, mock dates Feb and Aug 2026) shows only Detail Paket, Kirim Hadiah, Layanan Digital and Riwayat Transaksi, plus search results with a "Paket Untukmu" 2-column grid. It has no home screen. — [App Store](https://apps.apple.com/id/app/id651412430); [Google Play](https://play.google.com/store/apps/details?id=com.telkomsel.telkomselcm&hl=id)
  - **Number-selector pill.** A pill at the top of the screen holds a red "SIMPATI" chip and "0812 0000 0000 ▾". — App Store screenshots 3 and 4
- **by.U (screenshot looks old: the uCoin screen says "Berlaku sampai 31 Des 2022")**
  - **Top of home.** The header shows avatar, name and number, a "BONUS 2 GB" pill and three top tabs: "U-Plan / Updates / U-Tainment".
  - **Pulsa card.** "Pulsa Kamu Rp. 100.000" with three icon actions (Beli Paket, Beli Topping, Beli Pulsa) and a "Langganan Kuota" row.
  - **Usage card.** "Rincian Pemakaian" shows three **horizontal progress bars**, one colour each: blue for data (20 GB), green for topping (10 GB) and orange for voice (60 Menit).
  - **Offers.** "Spesial Buat Kamu" is a horizontal package-card row. — [App Store id1483475992](https://apps.apple.com/id/app/id1483475992), screenshot 4
- **myIM3 (mock date "Valid until 20/09/2025", so a 2025 UI)**
  - **Header.** "Good morning, Immanuel" with number, a red "PREPAID" chip, and search, bell and avatar icons.
  - **Security strip.** A "SATSPAM+ • Activated" strip in a blue gradient.
  - **Summary card.** The active package name ("Freedom Internet 100GB") sits over three numeric columns: **Rp500.000 Balance | 100GB Total Quota | 13.000 pts IMPoin**. Under them are outlined buttons "+ Reload / Buy / Redeem" and a teal info footer.
  - **Below the card.** A banner carousel (SATSPAM), then a circular red icon row (Internet, 5G Coverage, SATSPAM, Emergency Service), then "Hot Promo" with pill tabs (Monthly / Super Hemat). — [App Store id888610275](https://apps.apple.com/id/app/id888610275), screenshot 1
  - **Package detail.** Quota appears as "30.2GB/50GB", "4988/5000 MENIT" and "1000/1000" SMS, each with a **thin teal horizontal bar**. — screenshot 2
- **bima+ ("New look" screenshot)**
  - **Same pattern as myIM3.** Greeting, then a "Platinum A" tier chip, then a summary card **Rp150.000 Balance | 132GB Quota | 12.500 pts Bonstri** with Reload / Buy / Redeem buttons.
  - **Below the card.** A banner ("Happy Ramadan 130GB+5GB, Rp145 ribu"), then a light-pink square icon row (View All, Ekstra TikTok 5GB, Balance, Package, Emergency Service), then "Special for You" with a "Best Offers … disc up to 25%" card and package cards. — [App Store id1276444056](https://apps.apple.com/id/app/id1276444056), screenshot 3
- **AXISNET ("Tampilan Baru", mock dates Oct and Dec 2023, so the screens are probably 2023)**
  - **Header.** A purple header carries a large illustrated character (a young man with a phone and headphones) and "Hi, Angkasa / 0838…".
  - **Two side-by-side white cards.**
    - **"PULSA":** Rp500.000, expiry date and "Menu Pulsa Lainnya".
    - **"PAKET KAMU (10)":** a **circular icon/ring**, "483.00 MB / 120.00 GB", "Bronet 2 GB 1 hari", page dots and "Detail Paket".
  - **Below the cards.** A "Level Temenan – CEK BONUS" mini card, a row of colourful 3D-ish rounded-square icons (Bonus Non Stop, Voucherku with a red badge, Isi Voucher AIGO, Isi Pulsa, Paket suka-suka) and a magenta bottom-sheet section "Hanya Untukmu" with pill filters (Mendadak Diskon / Rekomendasi / Apl…) and package cards. — [App Store id497146073](https://apps.apple.com/id/app/id497146073), screenshot 1
- **myXL**
  - **What the thumbnails show.** YouTube thumbnails (2026) show a light screen with a **mint/teal-to-white gradient header**, white cards, a 4-icon row, a promo banner and a bottom nav. The text is unreadable at thumbnail size. A purchase-confirmation screen shows "Xtra Combo Mini 7 Hari 7GB", a teal "Makin Hemat Pakai Promo!" strip and a "Bayar Menggunakan: Pulsa" card. — [YouTube IFQOu628r-c](https://www.youtube.com/watch?v=IFQOu628r-c) ("Terbaru 2026", ~9 months old); [YouTube 9ORW5ipRjHY](https://www.youtube.com/watch?v=9ORW5ipRjHY) (~2 months old)
  - **Store set.** All 8 App Store screenshots and the Play set are pure brand ads (XL Ultra 5G+, Ookla award 2025, Google Gemini promo, XL Prioritas) with **no app UI**. — [App Store](https://apps.apple.com/id/app/id683141076); [Google Play](https://play.google.com/store/apps/details?id=com.apps.MyXL&hl=id)
- **MySmartfren (v8 screenshot set)**
  - **Header.** "Welcome, Jonathan >" with a scan icon and a bell that has a red dot.
  - **Member row.** "Membership: Red Member", "Prepaid 0888…" and "Valid until 6 Apr 202x".
  - **Balance strip.** A **black "My Balance Rp 288.000 (Bonus Rp 10.000)" strip** with a red "Top Up" button.
  - **Quota rings.** Four **magenta ring gauges** with "New" tags: Internet 19 GB, Midnight 4 GB, Multimedia 6 GB, Bonus 10 GB, then a "Details >" row.
  - **Below the rings.** "Treasure Hunt" and "1.200 SmartPoin" mini cards, then curated package cards (a "VIU 6 GB 30 Days" gradient card). — [App Store id1209898190](https://apps.apple.com/id/app/id1209898190), screenshot 1
  - **Second home view.** It shows a pink "Free Bonus to Claim" voucher carousel and a dark "Entertainment" section with Netflix and Movie cards. — screenshot 3

### Inferences
- **The IOH apps share one design system.** myIM3 and bima+ are near-identical in structure: the same summary card, the same three CTAs, the same icon row and the same 4-tab nav. Only the accent colour and the points name differ.
- **Quota shown as a graphic is the exception.** In current screens, MySmartfren's rings are the strongest graphic. The bars in myIM3 appear on the detail screen, not the home screen.
- **Busiest:** AXISNET (character illustration, many coloured icons, magenta section) and MyTelkomsel's home (banner first). **Calmest:** myIM3 and bima+.

### Gaps
- **MyTelkomsel home in current v9.x:** only a ~480px thumbnail was seen. The bottom nav labels and the exact card anatomy are not seen.
- **myXL home, bottom nav and catalog:** no readable screenshot (store sets are ads only).
- **by.U and AXISNET current (2025–2026) home:** the store screenshots appear to be from 2022 and 2023.
- **Popups:** none seen in any screenshot.

## Bottom navigation (labels, count, center button)

### Takeaway
Where it was visible, the bottom nav has 4–5 tabs. AXISNET is the only one seen with a raised, filled centre "Paket" (buy) button. myIM3 and bima+ use 4 tabs (Home brand tab, Buy, Rewards, Account) with no centre button.

### Cited Findings
- **myIM3:** 4 tabs, **myIM3 · Buy · Rewards · Account**. The Account tab uses the user's avatar photo and the active tab is red. — [App Store id888610275](https://apps.apple.com/id/app/id888610275), screenshots 1 and 3
- **bima+:** 4 tabs, **bima+ · Buy · Rewards · Account**. The active tab is red-pink. — [App Store id1276444056](https://apps.apple.com/id/app/id1276444056), screenshots 2 and 3
- **AXISNET:** 5 tabs, **Home · Playground · Paket · Hiburan · Alifetime**. "Paket" sits in the centre as a **filled magenta rounded-square button with a cart icon**. The other icons are muted lilac. — [App Store id497146073](https://apps.apple.com/id/app/id497146073), screenshots 1 and 2
- **bima+ gaming web view "House of H3RO":** its own nav (Shop, Leaderboard, Home in the centre, Academy, Content) with a raised centre game-controller button. — screenshot 4
- **MyTelkomsel, by.U, myXL and MySmartfren:** the bottom nav was not seen or not legible.

### Inferences
- **Most explicit centre "buy" button:** AXISNET. The IOH apps put "Buy" as the 2nd tab instead.

### Gaps
- **Missing nav labels:** MyTelkomsel, by.U, myXL and MySmartfren, all not seen. No scan button was seen in any nav. MySmartfren has a scan icon in its header.

## Package catalog card anatomy and badges

### Takeaway
Every app seen uses rounded white cards that put **quota (big, bold) + validity + price**, often with a **strikethrough old price**, a coloured **badge/ribbon** at the top and a solid CTA button. Red pill "Beli" buttons (MyTelkomsel) and blue pill "Beli" buttons (by.U) were seen. bima+ cards add a coloured footer ribbon.

### Cited Findings
- **MyTelkomsel, "Paket Untukmu" grid**
  - **Layout:** 2 columns.
  - **Card content:** a small lavender "Promo" or text "HOT PROMO" label, the name ("Super Seru Promo"), quota in bold ("100 GB 28 Days") and a red price "Rp 160.000" with grey strikethrough "Rp 165.000".
  - **CTA:** a full-width red pill **"Beli"**. — [App Store](https://apps.apple.com/id/app/id651412430), screenshot 5
- **MyTelkomsel, Detail Paket**
  - **Top of screen:** the name, "3.5 GB | 30 Hari" and a right-aligned price Rp43.000 over strikethrough Rp50.000. Chips read "3.5 GB Utama" and "+20 Poin".
  - **Details:** a segmented control "Detail / Deskripsi / S&K" (the selected segment is dark navy), then rows for Masa Aktif and Internet.
  - **Add-on section:** "Tambah Add-on" with checkbox add-ons (YouTube Premium).
  - **Bottom sheet:** "Harga Total Rp75.500" with an itemised breakdown and a full-width red **"Beli Paket"** button. — screenshot 1; same in [Google Play gp1](https://play.google.com/store/apps/details?id=com.telkomsel.telkomselcm&hl=id)
- **MyTelkomsel, transaction list.** It uses status chips: **Belum Bayar** (orange), **Diproses** (yellow), **Berhasil** (green) and **Gagal** (red). A red outline button reads "Beli Lagi". — screenshot 4
- **by.U**
  - **Card content:** a red/pink top-left ribbon ("Bonus TikTok", "Bonus Disney+", "Cuman Buat Kamu"), the name ("Yang Bikin Kumat"), a large blue "10 GB | 10 Hari", a grey description and "Rp 25.199".
  - **CTA:** a light-blue pill **"Beli"**.
  - **Layout:** a horizontal carousel with page dots. — [App Store](https://apps.apple.com/id/app/id1483475992), screenshots 3 and 4
- **bima+**
  - **Card body:** a pink-to-white gradient card with "Happy 20GB" (big, bold), two chip boxes "30 Days | One Time" and a magenta footer ribbon "New SIM Card + Zone Qu…".
  - **Price:** Rp80.000.
  - **Above the cards:** filter chips "Search & Filter / Happy / Happy x GoPay / Hot Sale (with a fire icon, orange outline)" and a "6 packages" count with a View toggle. Category pill tabs read Data Package (filled orange) / Entertainment / Roaming. — [App Store](https://apps.apple.com/id/app/id1276444056), screenshot 2
  - **"Happy Flex" custom builder:** sliders for quota (1–150GB) and active period (1/3/7/30 days), a price box and an orange "Continue" button. — screenshot 1
- **AXISNET:** the title is "20GB DISC 20%" (or "OWSEM…"), quota "16GB", red price "Rp 135.900", a red "-20%" chip and strikethrough "Rp169.900". — [App Store](https://apps.apple.com/id/app/id497146073), screenshot 1
- **myIM3 rewards:** a red-and-white points card "1.907 pts" with a progress bar to the next tier, a "Go To Missions" dark-navy banner and pill filters (All / Lifestyle / Donate / Telco). — [App Store](https://apps.apple.com/id/app/id888610275), screenshot 3
- **MySmartfren:** gradient package cards ("VIU 6 GB 30 Days" in a magenta/purple gradient) and entertainment cards (Netflix Plan 1.5 GB) with strikethrough "10.000". — [App Store](https://apps.apple.com/id/app/id1209898190), screenshots 1 and 3
- **myXL:** not seen (a confirmation screen only, in a thumbnail).

### Inferences
- **The common anatomy** is a badge, name, then a big quota number with validity, then a price with strikethrough, then a CTA. A **"discount %" chip next to the price** (AXISNET) and **"+ bonus" chips** (MyTelkomsel "+20 Poin") are recurring patterns.

### Gaps
- **myXL catalog cards:** not seen.
- **MySmartfren and myIM3 full catalog lists:** only partial cards seen.

## Color palette, typography, iconography, illustration, mascots, dark mode

### Takeaway
- **Colours:** each brand keeps a strong single accent on mostly white UI. MyTelkomsel is red with a dark-navy secondary. myIM3 is red. bima+ is pink-magenta plus orange. AXISNET is purple plus magenta. by.U is cyan-blue. myXL is blue plus mint. MySmartfren is magenta-pink with black.
- **Type:** geometric sans throughout, with bold numbers.
- **Mascots and characters:** MySmartfren (robot "SMARTY") and AXISNET (illustrated people) use them. by.U uses a real person (a meme-style face) in its store art.

### Cited Findings (all hex values are visual estimates, approximate; not pixel-sampled)
- **MyTelkomsel**
  - **Colours:** primary red ~#E60023 on CTAs and price, dark navy ~#0A1F44 on the selected segment and "Semua" chip, light grey-lavender ~#EEF0F6 page background, and white cards.
  - **Type:** a geometric sans (Poppins-like). Prices are semibold, with grey strikethrough.
  - **Icons:** line icons in red-tinted circles.
  - **Store art:** dark 3D frame. Dark mode is not seen in the UI. — [App Store](https://apps.apple.com/id/app/id651412430)
- **by.U**
  - **Colours:** sky/cyan blue ~#2DB8F0 dominates, with orange ~#F26B1D as a secondary (the U-Tainment screen header is orange) and white cards.
  - **Type:** a rounded geometric sans, heavy weights in the store art. Quota numbers are large and blue.
  - **Art:** flat illustrated people plus 3D-ish coins ("GB" coins) and gift boxes. The store hero uses a real-person meme face. — [App Store](https://apps.apple.com/id/app/id1483475992)
- **myIM3**
  - **Colours:** red ~#E3242B accents (active tab, chips, icon circles), teal ~#2BB3A6 progress bars and info strip, a soft pastel gradient background in the store frame, and white UI.
  - **Type:** a geometric sans (the store headings look like Gilroy or Poppins). Numbers are bold.
  - **Icons:** mostly line icons. Feature icons are filled red circles with white glyphs.
  - **Accents:** 3D red "GB" tiles and a shield badge appear as decorative 3D elements. — [App Store](https://apps.apple.com/id/app/id888610275)
- **bima+**
  - **Colours:** pink-magenta ~#E5007E, orange ~#FF5A1F (CTA "Continue" and the selected category tab), teal ~#2EC4C4 (Happy Flex sliders) and a pink-peach gradient background.
  - **Type:** a geometric sans, with very bold quota text ("100GB").
  - **Icons:** line icons in a pink tint. The "Bima" mascot hat icon appears on the home tab. — [App Store](https://apps.apple.com/id/app/id1276444056)
- **AXISNET**
  - **Colours:** deep purple ~#4B2A7B header, magenta ~#E5197E sections and centre nav button, lime/yellow-green ~#C6DC2E buttons ("LIHAT BONUS"), and teal ~#1CC6B2 "CEK BONUS".
  - **Icons:** colourful filled 3D-style rounded-square icons.
  - **Art:** a large flat illustrated character in the header, another illustrated girl in the "Hanya Untukmu" section, and 3D illustrations (balloon, chest, mystery box) in Playground.
  - **Type:** a geometric sans, with a hand-drawn display font for "PLAYGROUND". — [App Store](https://apps.apple.com/id/app/id497146073)
- **myXL**
  - **Colours:** brand blue ~#1A3DB8 plus mint/teal ~#2FD3A6 (the "5G+" logo). The in-app header looks mint-to-white in thumbnails.
  - **Store art:** photographic and 3D with bold geometric headlines. No mascot seen. — [App Store](https://apps.apple.com/id/app/id683141076); [YouTube IFQOu628r-c](https://www.youtube.com/watch?v=IFQOu628r-c)
- **MySmartfren**
  - **Colours:** hot magenta-pink ~#F0247A (store background and ring gauges), black ~#111111 for the balance strip and entertainment section, red "Top Up" and white.
  - **Mascot:** a **robot mascot "SMARTY"** (white body, pink screen face) appears on screenshots.
  - **Accents:** 3D bell and "%" accents. — [App Store](https://apps.apple.com/id/app/id1209898190)
- **Dark mode:** no app showed a dark-mode toggle or full dark theme in the screenshots viewed. MyTelkomsel's home header and MySmartfren's entertainment section are dark *sections* inside a light UI.

### Inferences
- **The trend is "white UI + one saturated brand accent + 3D decorative props in marketing."** Inside the apps, icons are mostly line style. AXISNET is the outlier, with filled 3D icons and heavy illustration.
- **Numbers carry the hierarchy everywhere.** Quota and price are the boldest text on every card seen.

### Gaps
- **Exact fonts:** not determinable from screenshots.
- **True hex values:** need pixel sampling (no image library was available).
- **Dark mode:** not seen for any app. Check device settings or in-app settings to confirm.
