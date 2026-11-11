# **Crumbtown: Idle Bakery Tycoon — GDD Idle Arcade v1.0 (DRAFT)**

*Nama sebelum 2026-11-03: Roti Lezat Tycoon (Seksi 19 no. 1, Seksi 20 no. 49).*

> **Status:** rancangan 2026-10-25; ke-13 keputusan Seksi 19 dikonfirmasi maintainer dan implementasi dimulai 2026-10-26 di branch `pivot-to-idle-game` (catatan implementasi di Seksi 20).
> **Peran dokumen:** GDD ini mengubah Roti Lezat Tycoon dari tycoon manajemen harian menjadi **game idle arcade**. Untuk semua hal yang diatur di sini, dokumen ini menggantikan GDD v3.1 (`docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md`). Hal yang tidak disebut di sini tetap mengikuti v3.1 (Seksi 0.1).
> **Engine lock tetap:** Godot 4.7-stable Standard, GDScript, renderer Compatibility, 100% aset prosedural, teks pemain berbahasa Inggris (v3.1 §4, §43, §96, §111, §127, §128).
> **Nilai bertanda TUNABLE** adalah nilai awal. Semuanya hidup di katalog `data/catalog/idle.json` (Seksi 15.2) dan disetel dengan probe pacing (Seksi 17, fase P7).

---

# **0. Cara Membaca Dokumen Ini**

## **0.1 Hubungan dengan GDD v3.1**

| Status | Bagian v3.1 | Catatan |
|---|---|---|
| **Tetap berlaku** | §4 art direction, §12.2–12.4 rendering & kontrol; §17 grid & navigasi; §28.2 aturan tumpukan modal; §29 input; §30 kamera (kecuali §30.1, lihat Seksi 12.0.4); §31 visual karakter; §32 perabot, interior, lingkungan, kehidupan jalan; §33 kebijakan audio; §34/§77/§106 mekanisme save atomik & 3 profil; §35 arsitektur dasar; §37 & §109 (termasuk §109.3 MeshBake) performa; §43/§127 teks Inggris; §44 aksesibilitas; §57/§60 template layout & dimensi perabot; §68 portal lantai; §72 Decoration Mode; §96–§101 kontrak teknis (kecuali pembulatan uang §99.2, lihat Seksi 7.6); §111 asal aset; §115–§117 cache, RNG, logging; §128–§130 toolchain, batas runtime, spesifikasi visual | Dipakai apa adanya kecuali disebut lain di dokumen ini |
| **Diubah** | §1–§3 overview, loop, ekonomi; §5 equipment; §6/§64 lokasi; §7/§28.1 UI; §12.5 orientasi & ponsel, §28.4 breakpoint, §30.1 kamera gameplay, §110 matriks resolusi (semuanya menjadi potret, Seksi 12.0); §8/§48 pemasaran; §99.2 pembulatan uang (Seksi 7.6); §15 state & waktu; §16 karakter; §18 produksi; §19 roti & rak; §20 pelanggan; §21 kasir; §22 RotiFood; §23/§87 staf; §24 ekonomi & ledger; §26 cuaca; §27/§88 tutorial; §61/§63 resep & harga; §74/§92/§118 pencapaian; §89 menu utama; §90/§112/§113 lifecycle & offline | Aturan baru ada di seksi terkait dokumen ini |
| **Dihapus** | §9/§25 rating toko & RotiFood Stars (Seksi 6.6); §18.7 & §62 oven gosong; §19.7–§19.9 kesegaran & roti basi; §20.3 manifest Hari 1–3; §11 & §46 Daily Summary; §15.4 Skip to Open; §15.5 Close Early; §71 kecepatan 2×/3× & Smart Speed; §21.4 kasir manual (popup + OK); §22.5 kemas manual & §22.10 tolak pesanan; §5.2, §24A, §70 pasar bahan & kurir; §5.1.2 beli/ganti/jual alat; §63.2 harga manual; §24.5/§86 utilitas; §24.6/§3.3 gaji; §3.0/§49 bangkrut, talangan, Mode Solo; §104 shutdown 18:00; Ask a Baker | Tidak ada mode lama. Kode dan tesnya ikut dihapus saat implementasi |

## **0.2 Konvensi**

- ID kode, data, dan event berbahasa Inggris. Teks pemain lewat `Tx.t(key)` di `strings_en.json` (Seksi 18).
- Durasi simulasi tetap dalam *simulation-second* (v3.1 §99.1). **1 jam in-game = 60 detik nyata pada kecepatan normal.** Tidak ada lagi tombol kecepatan, jadi "nyata" selalu berarti 1×.
- Mata uang: **Koin Roti (KR)**. Mata uang prestige: **Bintang Waralaba** (ID `franchise_stars`, ikon bintang ungu).
- "Level" selalu bilangan bulat ≥ 1.

## **0.3 Keputusan Maintainer 2026-10-25**

1. Arah: **idle arcade**. Toko 3D, karakter pemain, staf, dan pelanggan yang berjalan tetap ada.
2. **Hanya satu mode, yaitu mode idle.** Mode tycoon lama tidak dipertahankan.
3. **Oven gosong dan roti basi dihapus sepenuhnya.** Tidak ada mode manual.
4. Pengerjaan di branch `pivot-to-idle-game`. Game asli tetap ada di `main`.
5. Batasan GDD v3.1 yang menghalangi rancangan idle (terutama larangan progres offline di §90, §112, §113, dan §119) **dicabut**.
6. **Game dimainkan dalam orientasi potret.** Di layar landscape (laptop, PC, tablet yang dimiringkan) game tetap potret di tengah layar, dan area kosong di sisinya diisi **taplak meja gingham** seperti di layar pembuka dan Main Menu (Seksi 12.0).

---

# **1. Visi**

## **1.1 Pitch**

Toko roti mungil di garasi yang **tidak pernah berhenti bekerja**. Pemiliknya mengaduk, memanggang, dan melayani sendiri sejak detik pertama. Setiap koin yang terkumpul bisa dipakai menaikkan level oven, membuka resep baru, merekrut asisten, lalu pindah ke ruko, toko mandiri, flagship, sampai landmark kota. Saat pemain menutup game, toko tetap buka dan menyambutnya dengan setumpuk koin begitu ia kembali. Begitu toko jadi ikon kota, pemain bisa menjualnya ke investor dan memulai **waralaba** baru yang lebih cepat dan lebih kaya.

## **1.2 Pilar**

1. **Selalu berjalan.** Toko menghasilkan uang tanpa satu ketukan pun. Ketukan mempercepat, tidak pernah diwajibkan.
2. **Setiap ketukan terasa.** Upgrade langsung terlihat: angka naik, model alat berevolusi, ada efek dan bunyi.
3. **Pulang ke toko yang lebih kaya.** Penghasilan offline selalu ada, jelas, dan jujur.
4. **Tumbuh tanpa ujung.** Biaya eksponensial, lonjakan di setiap milestone, dan prestige waralaba.
5. **Tetap hangat, nyaman, dan lucu.** Gaya visual dan audio v3.1 tetap dipakai, tanpa tekanan dan tanpa hukuman.

## **1.3 Genre & Referensi**

Genre *idle arcade / hybrid-casual tycoon*. Stasiun di-upgrade per level, manager atau asisten mengotomatiskan stasiun, penghasilan offline, lalu pindah lokasi atau prestige untuk pengali yang lebih besar. Referensi genre (bukan untuk ditiru asetnya): Eatventure, My Perfect Hotel, Idle Miner Tycoon. Gameplay tetap **offline penuh**: tanpa login, server, atau notifikasi push, dan semua fitur berjalan tanpa internet (v3.1 §112 kecuali larangan progres offline). Sejak 2026-11-05 game **boleh dimonetisasi** (keputusan maintainer, Seksi 19 no. 19): iklan berhadiah yang dipilih sendiri oleh pemain dan satu pembelian Supporter Pack (Seksi 22). Keduanya hanya tampil bila platform dan jaringannya tersedia; tanpa itu game berjalan sama persis.

## **1.4 Target Sesi & Pacing (TUNABLE)**

Sesi singkat 3–10 menit, beberapa kali sehari. Sesi pertama 20–30 menit. Waktu di tabel adalah waktu bermain aktif pemain biasa dari New Game.

| Momen | Target |
|---|---|
| Penjualan pertama | < 30 detik |
| Upgrade pertama | < 60 detik |
| Asisten pertama | 3–5 menit |
| Resep kedua | 5–8 menit |
| Lokasi Tier 2 (Ruko) | 12–18 menit |
| Lokasi Tier 3 (Toko Mandiri), Waralaba terbuka | 30–45 menit |
| Lokasi Tier 4 (Flagship) | 60–80 menit |
| Lokasi Tier 5 (Landmark) | 100–140 menit |
| Waralaba pertama (rata-rata pemain) | 60–120 menit |
| Putaran ke-2 sampai titik yang sama | ≤ 70% waktu putaran ke-1 |

Target jangka panjang (Seksi 23, TUNABLE): permainan tidak pernah "habis". Setiap cabang sesudah yang ke-2 butuh kira-kira 35–75 menit bermain aktif, tidak makin pendek, dan memberi bintang yang makin banyak; tanpa tebing, yaitu pemain biasa tetap sampai Tier 5 di setiap cabang. Sekitar 200 bintang tercapai dalam 18–24 jam bermain aktif, dan perk lanjutan (750–5.000 bintang, Seksi 23.2) menjadi tujuan puluhan jam berikutnya, tersebar di minggu-minggu bermain dengan penghasilan offline. Semua target di atas diukur **tanpa iklan** (Seksi 22.1) dan tanpa penghasilan offline.

---

# **2. Loop Inti**

## **2.1 Empat Skala Waktu**

| Skala | Pemain melakukan | Umpan balik |
|---|---|---|
| **Detik** | Mengetuk stasiun untuk *Semangat* (Seksi 5.2), menonton pelanggan membeli | Koin melompat, angka KR naik, bar progres maju |
| **Menit** | Menaikkan level stasiun dan resep, membuka resep, merekrut asisten | Angka KR/s naik, model alat berevolusi di milestone |
| **Jam** | Membeli lokasi berikutnya, memasang dekorasi berbonus | Interior dan lingkungan baru (v3.1 §32), stasiun dan jalur kasir bertambah |
| **Hari** | Mengumpulkan penghasilan offline, Waralaba, perk permanen | Popup selamat datang, Bintang Waralaba, putaran yang lebih cepat |

## **2.2 Menit Pertama**

1. Permainan pertama (install baru atau Reset Game): setelah Tap to Start muncul popup toko baru, pilih karakter lalu nama toko (Seksi 19 no. 21). Toko langsung berjalan, tanpa layar persiapan. Permainan berikutnya: Tap to Start langsung memuat toko.
2. Pemilik berjalan ke gudang, mengaduk Roti Tawar Polos, memanggang, lalu menata roti di rak. **Semua ini otomatis.**
3. Pembeli pertama datang dan mengambil roti. Pemilik berjalan ke kasir, membungkus (animasi v3.1 §21.4), lalu koin masuk.
4. Chip level di atas oven berkedip: upgrade pertama sudah terjangkau. Pemain mengetuknya, lalu menekan **Upgrade**. Oven naik ke Lv 2.
5. Pemain mengetuk oven beberapa kali. Setiap ketukan menambah progres (Semangat), dan rotinya matang lebih cepat.

## **2.3 Tanpa Input Apa Pun**

Toko tidak pernah macet. Pemilik dan asisten selalu memilih pekerjaan paling mendesak (Seksi 5.1), rak diisi ulang otomatis, pelanggan dilayani, dan pesanan RotiFood diterima serta dikemas sendiri. Kalau KR tidak cukup untuk bahan batch berikutnya, produksi menunggu sampai ada penjualan. Saldo tidak pernah negatif, dan **tidak ada Game Over**.

---

# **3. Waktu & Dunia**

## **3.1 Jam Kontinu**

- Jam in-game berjalan terus 24 jam (00:00–24:00) dengan skala v3.1 §15.2: **1 menit in-game = 1 detik nyata**, jadi satu hari penuh berlangsung 24 menit nyata.
- **Toko selalu buka.** Tidak ada fase persiapan, buka, tutup, atau after-hours. Tidak ada Daily Summary, Skip to Open, atau Close Early.
- Hari bertambah pukul 00:00. Nomor hari dipakai untuk cuaca, kalender libur, statistik, dan teks staf (v3.1 §31.8).
- Pencahayaan siang–malam memakai `Daylight` (v3.1 §32.6) mengikuti jam 24 jam.

## **3.2 Malam (TUNABLE)**

Pukul 22:00–06:00 toko tetap buka dengan lampu menyala, tetapi kedatangan pembeli dikali `night.arrival_mult` = **0,4** dan pesanan RotiFood dikali `night.rotifood_mult` = **0,6**. Produksi berjalan normal sehingga rak penuh menjelang pagi.

## **3.3 Cuaca & Hari Libur**

Undian cuaca harian dan kalender libur v3.1 §26.6 tetap berlaku dan dihitung per hari in-game. Efeknya berupa pengali (Seksi 6.1, 6.5). Tidak ada lagi prakiraan untuk perencanaan.

## **3.4 Pause & Lifecycle**

- Menu Pause menghentikan simulasi. Waktu pause tidak dihitung sebagai waktu offline.
- Aplikasi ke latar, tab browser tersembunyi, atau game ditutup: simulasi berhenti, lalu **waktu offline dihitung** (Seksi 9). Ini mengganti v3.1 §90 dan §113: setelah kembali tidak ada lagi layar "Game Paused" yang menunggu Resume. Game langsung jalan, dan popup Selamat Datang muncul bila waktu offline ≥ `offline.popup_min_seconds`.
- Layar pemblokir "Rotate your phone" v3.1 §12.5 dihapus. Game potret tetap berjalan saat ponsel dimiringkan (Seksi 12.0.6).

---

# **4. Produksi Otomatis**

## **4.1 Stasiun**

| Stasiun | Fungsi | Jumlah |
|---|---|---|
| Gudang | Fixture. Tempat mengambil bahan (visual), tanpa stok | 1 per lokasi |
| Mixer | Mengaduk adonan (tahap mix + prep v3.1 §61.5) | Slot lokasi (v3.1 §6: 1/2/3/4/5) |
| Oven | Memanggang (tahap bake) | Slot lokasi (1/2/3/4/5) |
| Rak Display | Menjual; setiap petak menjual satu resep | Slot lokasi (1/2/3/4/6) |
| Meja Kasir | Jalur layanan; jalur A milik pemilik, sisanya milik Asisten Kasir | Jalur lokasi (2/2/2/3/3) |
| Tablet RotiFood | Sumber pesanan online | 1, sejak awal |
| Meja Tunggu | Penampung otomatis bila semua rak penuh (Seksi 4.7) | 1 per lokasi |
| Kursi Koki | Tempat asisten dapur menganggur (v3.1 §5.1.4) | Sesuai batas staf |

Membuka stasiun tambahan sampai batas slot lokasi dibayar dengan KR (Seksi 8.4). Tidak ada lagi Pasar untuk membeli, mengganti, atau menjual model alat. Model alat **berevolusi otomatis** saat levelnya mencapai milestone (Seksi 8.2).

## **4.2 Menu: Resep per Petak Rak**

- Setiap petak rak menjual **satu resep** yang dipilih pemain di layar **Menu**, atau diisi otomatis dengan resep terbuka yang paling menguntungkan.
- Resep harus **dibuka** dulu (Seksi 8.5). Resep yang ditetapkan di petak harus bisa dibuat oleh paling sedikit satu Mixer dan satu Oven dengan tier model ≥ syarat resep (v3.1 §61.5 kolom `mixer`/`oven`).
- Mengganti resep petak tidak membuang roti yang sudah ada. Petak menjual habis roti lama, lalu diisi resep baru.

## **4.3 Target Stok & Pemilihan Pekerjaan**

- Target setiap petak adalah kapasitas penuh petak itu (Seksi 8.2, Rak).
- Pekerja dapur (pemilik atau Asisten Dapur) yang menganggur memilih petak dengan **rasio isi terendah**. Seri dipecah dengan nilai jual per detik tertinggi, lalu ID petak. Pekerja itu kemudian membuat batch resep petak itu pada mixer bebas yang memenuhi syarat.
- Ukuran batch: terbesar dari x1/x3/x5 yang **tidak melebihi sisa ruang petak** dan terjangkau biaya bahannya (v3.1 §18.9 untuk durasi batch).
- Rantai kerja per batch sama seperti v3.1 §18: mix → ambil adonan → oven → ambil loyang → taruh di petak. Setiap langkah dikerjakan pekerja secara otomatis. Mixer dan oven yang selesai menahan isinya sampai diambil, **tanpa batas waktu dan tanpa penurunan kualitas**.
- Prioritas: (1) mengangkat loyang dari oven yang selesai, (2) memindahkan adonan dari mixer ke oven bebas, (3) memulai batch baru. Aturan ini mencegah alat menganggur.

## **4.4 Biaya Bahan**

Pasar dan stok bahan dihapus. Saat batch dimulai, **biaya bahan batch** (v3.1 §63.1 dari kolom bahan §61.5) dipotong dari KR sebagai `INGREDIENT_COST`. Bila KR kurang, batch belum dimulai. Biaya bahan **tidak ikut naik** dengan level resep, sehingga margin melebar seiring permainan.

## **4.5 Durasi**

```text
mix_seconds  = (mix_seconds_base + optional_prep_seconds) × batch_duration_factor / speed(mixer)
bake_seconds = bake_seconds_base × batch_duration_factor / speed(oven)
```

Nilai dasar dari v3.1 §61.5 (dalam simulation-second, pada tier minimum resep). `speed(...)` dari Seksi 8.2. Rasio waktu referensi antar-tier alat (v3.1 §18.5) **tidak dipakai lagi**, karena kecepatan kini sepenuhnya dari level.

## **4.6 Tidak Ada Gosong, Tidak Ada Basi**

- Stage `OVERBAKING` dan `BURNT`, jendela gosong, asap gosong, dan pengurangan kualitas dihapus. Roti yang matang menunggu di oven sampai diangkat.
- Kesegaran, umur, `STALE`, `UNSALEABLE`, penuaan malam, buang roti, dan pembusukan Meja Tunggu dihapus. Roti tetap sempurna selamanya.
- `bake_quality` dihapus. Semua roti berkualitas sama, dan harga hanya ditentukan Seksi 7.2.

## **4.7 Meja Tunggu sebagai Penampung**

Bila semua petak yang cocok penuh tetapi loyang sudah diangkat (misalnya karena resep petak diganti), pekerja menaruh loyangnya di Meja Tunggu. Pekerja mengambilnya lagi lebih dulu begitu ada petak yang cocok punya ruang. Tidak ada pembusukan dan tidak ada batas isi (v3.1 §5.1.3 tanpa aturan busuk).

---

# **5. Pekerja**

## **5.1 Pemilik (Karakter Pemain)**

- Pemilik adalah **pekerja otomatis serba bisa**. Pemain tidak perlu menyuruhnya.
- Setiap kali menganggur, pemilik memilih tugas menurut urutan ini:
  1. Melayani jalur A bila ada pembeli menunggu di jalur A **dan** tidak ada jalur kasir lain yang buka dengan ruang.
  2. Pekerjaan dapur menurut Seksi 4.3.
  3. Mengemas pesanan RotiFood (Seksi 6.5).
  4. Bila tidak ada pekerjaan (Seksi 20 no. 81): bila ada roti yang sedang dibuat, menunggu di dapur di samping stasiun batch yang paling dulu butuh tangan; bila tidak, berjaga sebagai kasir di jalur A; bila jalur A tidak bisa dijaga, menunggu di sebelah meja kasir. Di mana pun ia menunggu, animasi idle v3.1 §31.6–§31.7 (gelembung pikiran, tertidur) tetap berlaku.
- Setelah ada Asisten Kasir, pemilik tetap boleh melayani jalur A bila jalur kasir penuh.
- **Ketukan arahan:** mengetuk sebuah stasiun juga menjadikan stasiun itu prioritas pertama pemilik untuk 10 detik (TUNABLE `owner.focus_seconds`).

## **5.2 Ketukan Semangat**

- Mengetuk mixer atau oven yang sedang bekerja langsung menambah progres sebanyak `tap.progress_seconds` = **0,5 detik simulasi** × `tap_power`. Efeknya kilau, koin kecil, dan bunyi "pop".
- Mengetuk kasir yang sedang membungkus mempercepat transaksi dengan cara yang sama.
- Batas `tap.min_interval_seconds` = **0,12 detik nyata** per stasiun untuk mencegah autoclicker yang ekstrem. Ketukan lebih cepat diabaikan tanpa efek.
- `tap_power` naik dari upgrade global (Seksi 8.9) dan perk (Seksi 10.4).

## **5.3 Asisten Dapur**

Mengerjakan rantai produksi Seksi 4.3 seperti pemilik. Duduk di kursi koki bila menganggur (v3.1 §5.1.4). Tidak ada lagi Ask a Baker dan tidak ada tombol on/off duty.

## **5.4 Asisten Kasir**

Satu asisten per jalur selain jalur A, dan selalu bertugas. Melayani otomatis dengan durasi transaksi Seksi 8.2 (Meja Kasir). Antrean pindah ke jalur yang buka dan menyeimbang seperti v3.1 §21.3.

## **5.5 Batas, Biaya & Level Staf**

- Batas staf per lokasi mengikuti v3.1 §6. Roster 5 kasir dan 5 koki (v3.1 §3.5) tetap, untuk nama, tampilan, dan bio.
- **Tanpa gaji.** Merekrut dibayar sekali (TUNABLE `staff.hire_cost[n]`, naik per orang ke-n).
- Setiap staf punya level: `staff_speed(L) = 1 + staff.speed_per_level × (L − 1)` (default 0,04), mempercepat jalan dan aksi. Batas level staf sama dengan batas level stasiun lokasi (Seksi 8.3).

---

# **6. Pelanggan & Penjualan**

## **6.1 Kedatangan**

```text
arrivals_per_ingame_hour = base_arrivals(location_tier)
                           × decor_arrival_mult × boost_arrival_mult
                           × night_mult × weather_mult × holiday_mult
```

- `base_arrivals` per tier lokasi (TUNABLE): **23 / 51 / 67 / 86 / 112** per jam in-game (sejak 2026-11-01, Seksi 20 no. 44; awalnya 24 / 32 / 42 / 54 / 70 dengan pengali reputasi).
- Kedatangan tetap berupa proses Poisson memakai stream RNG v3.1 §116. Pembeli tetap berjalan dari ujung trotoar (v3.1 §20.1) dan diterima hanya bila ada slot antrean (v3.1 §57.6).
- Arketipe pelanggan v3.1 §20.11 tetap ada untuk variasi tampilan dan jumlah beli. Aturan sensitivitas harga dihapus karena harga tidak lagi disetel pemain.

## **6.2 Pembelian**

- Pembeli memilih resep di antara petak yang berisi, berbobot preferensi arketipe (v3.1 §20.11 tag) × harga relatif. Jumlah beli mengikuti v3.1 §84.1.
- Bila tidak ada roti sama sekali, pembeli **tidak berbalik di pintu**. Ia berjalan ke depan rak, melihat isinya selama `customers.empty_shelf_look_seconds` (TUNABLE **4** detik-simulasi, 2 detik nyata), lalu memeriksa lagi: bila roti sudah keluar ia membeli seperti biasa, bila belum ia pulang. Itu penjualan yang hilang, tanpa denda lain (Seksi 6.6). Keputusan maintainer 2026-11-01.

## **6.3 Antrean & Kasir**

Jalur, antrean, dan penyeimbangan mengikuti v3.1 §21.1–§21.3. Transaksi otomatis berlangsung `checkout_seconds` (Seksi 8.2) dengan animasi membungkus v3.1 §21.4. Tidak ada popup pesanan dan tidak ada tombol OK.

## **6.4 Kesabaran**

**Pembeli tidak punya kesabaran** (keputusan maintainer 2026-11-04; mengganti v3.1 §20.8 dan §58 untuk pembeli): pembeli yang mengantre menunggu sampai dilayani, tanpa bar di atas kepala. Dalam simulasi dua seed × 120 menit dengan pemain biasa, dari sekitar 11.000 pembeli yang dilayani tidak ada satu pun yang kehabisan kesabaran; yang membatasi penjualan adalah batas antrean (pembeli baru tidak masuk saat antrean penuh, `total_customers_missed`). Upgrade global Queue Patience karena itu diganti **Faster Checkout** (Seksi 8.9), dan statistik `total_customers_lost_patience` dihapus. Hanya driver RotiFood (v3.1 §22.6) yang masih punya kesabaran dasar `driver_rotifood.base_patience_seconds`, tanpa bar; habisnya membatalkan pesanan.

## **6.5 RotiFood Otomatis**

- Pesanan datang sepanjang hari: `rotifood_orders_per_hour(tier)` (TUNABLE: **3 / 4 / 6 / 8 / 10**) × `night_mult` × weather (hujan ×1,5) × boost.
- Pesanan **diterima otomatis**. Stok dipesan dari rak saat pesanan datang bila tersedia, lalu dikemas otomatis oleh pemilik atau kasir yang menganggur.
- Bila stok belum ada, pesanan menunggu. Driver datang dan menunggu dengan kesabaran v3.1 §22.6. Bila habis, pesanan batal tanpa denda lain.
- Harga pesanan = harga jual × `rotifood.price_mult` (TUNABLE **1,1**). Tidak ada tolak pesanan dan tidak ada tip.

## **6.6 Tanpa Rating**

- Game idle ini **tidak punya rating**. Rating toko dan RotiFood Stars v3.1 (§9, §25), juga Reputasi gabungan rancangan awal dokumen ini, dihapus (keputusan maintainer 2026-11-01, Seksi 19 no. 6).
- Toko berjalan sendiri, jadi pembeli yang pulang tanpa roti dan pesanan RotiFood yang batal hanya berarti penjualan yang hilang. Statistiknya tetap dicatat (`total_customers_left_no_purchase`, `total_rotifood_orders_expired`).
- Kedatangan tidak bergantung pada rating. Pemain menambahnya lewat lokasi, dekorasi berbonus, dan promosi (Seksi 6.1).

## **6.7 Tetap Ada (Kosmetik)**

Pengunjung lihat-lihat (v3.1 §20.12), kejutan (§31.9), kehidupan jalan, cuaca visual, dan dekorasi hari libur (§32.6–§32.10), serta celetukan dan gestur staf (§31.6, §31.8) tetap ada tanpa perubahan.

---

# **7. Ekonomi**

## **7.1 Mata Uang**

| Mata uang | Didapat dari | Dipakai untuk | Reset saat Waralaba |
|---|---|---|---|
| **KR** | Penjualan, RotiFood, penghasilan offline, hadiah | Upgrade, staf, lokasi, dekorasi, promosi | Ya, kembali ke `start_kr` |
| **Bintang Waralaba** | Waralaba (Seksi 10) | Pengali pasif & perk (tidak dibelanjakan) | Tidak |

`start_kr` = **65** (TUNABLE, Seksi 20 no. 45). KR adalah satu-satunya mata uang toko; mata uang premium Golden Crumbs (Seksi 22.3) hanya untuk boost, time warp, dan kosmetik.

Toko baru menghasilkan **1 KR/s** tanpa boost (keputusan maintainer 2026-11-02). Semua harga dan biaya KR di katalog diskalakan sama supaya tempo permainan tidak berubah (Seksi 20 no. 45).

## **7.2 Harga Jual per Roti**

```text
unit_price = base_sell_price_kr(recipe)              # recipes.json
             × recipe_price_mult(recipe_level)       # Seksi 8.5
             × (1 + display_price_bonus(shelf_level)) # Seksi 8.2
             × decor_price_mult × franchise_mult × boost_income_mult
             × variety_mult                          # Seksi 20 no. 83
```

`franchise_mult = 1 + prestige.income_per_star × franchise_stars` (Seksi 10.3). `boost_income_mult` dari Seksi 11.

## **7.3 Tanpa Biaya Berjalan**

Gaji, utilitas, sewa, dan talangan dihapus. Satu-satunya pengeluaran otomatis adalah biaya bahan batch (Seksi 4.4). Saldo tidak pernah di bawah 0.

## **7.4 Ledger**

Ledger v3.1 §24.1 tetap ada. Kategorinya kini: `SALE_PHYSICAL`, `SALE_ROTIFOOD`, `OFFLINE_EARNINGS`, `GIFT`, `INGREDIENT_COST`, `UPGRADE_STATION`, `UPGRADE_RECIPE`, `RECIPE_UNLOCK`, `STATION_OPEN`, `STAFF_HIRE`, `STAFF_UPGRADE`, `LOCATION_UPGRADE`, `DECOR_PURCHASE`, `PROMO`, `GLOBAL_UPGRADE`, `FRANCHISE_RESET`, dan `REWARD` (hadiah misi dan cap harian, Seksi 21.2–21.3; bukan pemasukan). Statistik menyimpan `run_earned_kr` dan `alltime_earned_kr`; hanya pemasukan yang dihitung, bukan pengeluaran.

## **7.5 Angka Besar**

- Jumlah uang (`Tx.kr`, `Tx.money`, juga saldo di HUD) di bawah 100 KR ditulis dengan satu desimal bila tidak bulat ("5.8 KR", "65.4 KR"), karena transaksi memakai sen (Seksi 7.6). Selebihnya mengikuti `Tx.big`.
- Format `Tx.big(n)`: < 10.000 ditulis utuh dengan pemisah ribuan ("9,850"). Di atasnya 3 angka penting dengan akhiran: K (10³), M (10⁶), B (10⁹), T (10¹²), lalu aa, ab, …, az, ba, … (10¹⁵, 10¹⁸, …). Contoh: "12.4K", "3.07M", "118aa".
- Pengaturan "Number format: Short / Scientific" (scientific: "1.24e15").
- Semua nilai uang memakai float 64-bit. Penjaga overflow v3.1 §73 tetap berlaku.

## **7.6 Pembulatan**

Setiap transaksi (penjualan, pesanan RotiFood, biaya bahan, upgrade, pembelian, penghasilan offline, promosi) di-commit sampai **sen (0,01 KR), half-up** (`Money.round_cents`). Harga per roti dibulatkan ke sen sebelum dikali jumlahnya. Biaya dianggap terjangkau bila jumlah yang benar-benar ditagih (setelah dibulatkan) muat di saldo. Aturan ini menggantikan "KR utuh" v3.1 §99.2 (keputusan maintainer 2026-11-02): dengan pendapatan awal 1 KR/s harga roti hanya beberapa KR, jadi bonus persen kecil (+1% harga per level rak, +2–4% dekorasi) akan hilang bila dibulatkan ke KR utuh.

---

# **8. Upgrade**

## **8.1 Rumus Biaya Umum**

```text
cost(L → L+1)   = base × growth^(L − 1)
cost(n levels)  = base × growth^(L − 1) × (growth^n − 1) / (growth − 1)
max_affordable  = floor( log(1 + KR × (growth − 1) / (base × growth^(L − 1))) / log(growth) )
```

Hasilnya dibatasi oleh batas level (Seksi 8.3). Tombol pembelian: **×1**, **×10**, dan **Max**. ×10 aktif hanya bila seluruh 10 level terjangkau dan muat dalam batas. Max menampilkan jumlah level ("Max (+37)").

## **8.2 Level Stasiun (per instance)**

Milestone stasiun: **10, 25, 50, 75, 100, 150** (TUNABLE `station.milestones`). `m(L)` adalah jumlah milestone ≤ L.

| Stasiun | Efek per level | Efek milestone | base / growth (TUNABLE) |
|---|---|---|---|
| Mixer | `speed = (1 + 0.05 × (L − 1)) × 2^m(L)` | ×2 kecepatan | 30 / 1,15 |
| Oven | sama dengan Mixer | ×2 kecepatan | 40 / 1,15 |
| Rak Display | kapasitas per petak `units = base_units × (1 + 0.04 × (L − 1))`; `display_price_bonus = 0.01 × (L − 1)` | +petak (evolusi model) | 50 / 1,15 |
| Meja Kasir (satu level untuk semua jalur) | `checkout_seconds = max(1.0, 3.0 × 0.97^(L − 1))` | jalur dapat badge emas (visual) | 60 / 1,15 |

`base_units` mengikuti `max_per_slot` model rak tier 1 di katalog. Biaya setiap instance tambahan dari kategori yang sama dikali `station.extra_instance_cost_mult` = **3** per instance ke-n (TUNABLE).

**Evolusi model:** tier model = 1 + jumlah ambang **10, 25, 50, 75** yang sudah dilewati. Model T1–T5 diambil dari `EquipmentFactory` yang sudah ada. Rak yang berevolusi mendapat jumlah petak model barunya. Bila jejak model baru tidak muat di tempatnya (rak T3+ berjejak 2 × 2), stasiun pindah ke tempat sah terdekat (`EquipmentManager.replacement_spot`). Bila tidak ada tempat sama sekali, evolusi visual menunggu, sedangkan efek level tetap berlaku.

## **8.3 Batas Level per Lokasi**

| Lokasi | Tier 1 Garasi | Tier 2 Ruko | Tier 3 Mandiri | Tier 4 Flagship | Tier 5 Landmark |
|---|---|---|---|---|---|
| Batas level stasiun & staf (TUNABLE) | 25 | 50 | 75 | 100 | 150 |

Dengan ini tier model maksimum tiap lokasi adalah T3, T4, T5, T5, dan T5. Resep T4–T5 terbuka paling cepat di Ruko (L50) dan Mandiri (L75).

## **8.4 Buka Stasiun Baru**

Biaya membuka mixer, oven, atau rak ke-n di lokasi: `station.open_cost[category] × station.open_growth^(n − 1)` (TUNABLE, misalnya rak: 200 × 8^(n−1)). Stasiun baru mulai di Lv 1 dan ditempatkan otomatis (`WorldManager.auto_place`). Posisinya tetap bisa digeser di Decoration Mode.

## **8.5 Resep: Buka & Level**

- **Buka resep:** `unlock_cost = base_sell_price_kr × recipe.unlock_mult` (TUNABLE **150**). Syarat: tier model mixer dan oven terbaik memenuhi kolom resep (v3.1 §61.5). Hanya **Roti Tawar Polos** yang terbuka sejak awal (gratis, `unlock_free`) dan langsung ditaruh di petak pertama. Semua resep lain, termasuk dua resep tier 1 lainnya, dibuka dengan KR.
- **Level resep** adalah mesin pertumbuhan utama:

```text
recipe_price_mult(L) = (1 + 0.10 × (L − 1)) × 2^m_r(L)
milestone resep      = 25, 50, 100, 150, 200, 300, 400, 500   (TUNABLE)
biaya level          = base_sell_price_kr × recipe.level_cost_mult (TUNABLE 10) × 1.12^(L − 1)
```

- Level resep **tidak dibatasi lokasi**, dan pengali waralaba membuatnya terus terjangkau.

## **8.6 Staf**

Rekrut (Seksi 5.5) dan level staf. Layar Staf menampilkan kandidat roster, biaya rekrut, level, dan tombol ×1/×10/Max.

## **8.7 Lokasi**

| | T1 → T2 | T2 → T3 | T3 → T4 | T4 → T5 |
|---|---|---|---|---|
| Biaya (TUNABLE) | 5K | 250K | 25M | 5B |

Upgrade lokasi menjalankan migrasi v3.1 §105, yang pindah ke lokasi baru dengan dekorasi diangkat dulu, di tengah cutscene truk pindahan (Seksi 20 no. 70). Level stasiun yang sudah ada dan level resep dipertahankan, dan batas level naik. Stasiun lama ditempatkan otomatis dan slot baru bisa dibuka (Seksi 8.4).

## **8.8 Dekorasi Berbonus**

Setiap dekorasi v3.1 §72.1 mendapat satu bonus permanen selama putaran (field katalog baru `bonus` = `{type: arrival|price|rotifood, value}`), misalnya pot tanaman +2% kedatangan atau papan menu kapur +3% harga. Bonus sejenis dijumlahkan: `decor_arrival_mult = 1 + Σ arrival`. Harganya diskalakan per tier lokasi (`decor.price_mult_by_tier`, TUNABLE 1 / 20 / 400 / 8.000 / 160.000). Skin storefront tetap kosmetik.

## **8.9 Upgrade Global ("Toko")**

| ID | Efek per level | Batas | base / growth (TUNABLE) |
|---|---|---|---|
| `global_offline_hours` | Batas offline +1 jam | +6 | 2K / 12 |
| `global_offline_efficiency` | Efisiensi offline +5% | +10 | 5K / 6 |
| `global_tap_power` | `tap_power` +25% | 20 | 500 / 3 |
| `global_walk_speed` | Pemilik & staf +5% jalan | 10 | 1K / 4 |
| `global_fast_checkout` | Kasir dan pengemasan RotiFood +5% lebih cepat (mengganti Queue Patience sejak 2026-11-04; save lama memindahkan levelnya) | 10 | 2K / 4 |

---

# **9. Penghasilan Offline**

## **9.1 Model Analitik `IdleEconomy`**

Simulasi agen terlalu mahal untuk menyimulasikan jam-jaman waktu offline: satu hari in-game masih butuh beberapa detik di desktop, dan jauh lebih lama di HP. Karena itu penghasilan offline memakai **model kondisi tunak** yang juga mengisi angka **KR/s** di HUD:

```text
untuk setiap petak berisi resep r (bobot w_r = bagian permintaan resep itu):
  D = permintaan unit per jam (kedatangan rata-rata 24 jam × qty rata-rata + RotiFood)
  P = produksi unit per jam: min(Σ mixer yield/mix_seconds, Σ oven yield/bake_seconds) dibagi menurut w_r,
      dibatasi juga oleh pekerja dapur (perjalanan per jam)
  S = layanan unit per jam: Σ jalur aktif × 3600 / (checkout_seconds + overhead_jalan) × qty rata-rata
  units_per_hour = min(D, P, S)
  net_per_unit   = Σ w_r × (unit_price_r − unit_ingredient_cost_r)
rate_kr_per_real_second = units_per_hour × net_per_unit / 60
```

- Kedatangan dirata-ratakan 24 jam (malam ikut), dengan cuaca netral dan tanpa boost.
- Akurasi model diuji terhadap simulasi hidup: selisih ≤ 20% di toko contoh Tier 1–5 (`ACC_IDLE_MODEL_MATCH`).

## **9.2 Rumus Offline**

```text
away     = clamp(now_unix − last_active_unix, 0, offline_cap_seconds)
earnings = rate_kr_per_real_second(saat pergi) × away × offline_efficiency
```

- `rate` dan `last_active_unix` disimpan saat aplikasi ke latar, tab tersembunyi, game ditutup, dan setiap autosave.
- Batas `offline_cap_seconds`: **2 jam** awal, naik lewat upgrade (Seksi 8.9) dan perk, maksimal **12 jam**.
- Efisiensi `offline_efficiency`: **50%** awal, maksimal **100%**.
- Penghasilan offline masuk ke `run_earned_kr` dan `alltime_earned_kr`.
- Selama offline, stok rak, posisi aktor, dan level tidak berubah. Toko dilanjutkan persis seperti saat ditinggal.

## **9.3 Kapan Dihitung**

Saat game dimuat dari profil, dan saat aplikasi atau tab kembali ke depan. Ketidakhadiran < `offline.min_away_seconds` (60) diabaikan. Bila ≥ `offline.popup_min_seconds` (300), popup Selamat Datang tampil. Di antara keduanya, KR ditambahkan diam-diam dengan toast kecil.

## **9.4 Jam Perangkat**

- Bila jam perangkat mundur (`now < last_active`), `away` = 0 dan acuan direset.
- Lompatan maju dibatasi `offline_cap`. Ini game offline satu pemain, jadi tidak ada deteksi curang lain.

## **9.5 Popup Selamat Datang**

"Welcome back! You were away for {time}. Your bakery earned {amount}." disertai tombol **Collect**, animasi hujan koin, dan sapaan Pak Lurah. Bila iklan berhadiah tersedia (Seksi 22.4, `offline_double`), tombol kedua **Collect ×2** menggandakan jumlahnya setelah iklan selesai ditonton; Collect biasa tetap ada, dan Back tetap sama dengan Collect.

---

# **10. Prestige: Waralaba**

## **10.1 Syarat**

Lokasi Tier 3 sudah dicapai di putaran ini dan Waralaba akan memberi ≥ 1 bintang baru. Sejak Seksi 20 no. 78: Tier 3 dicapai oleh cabang terbaru, dan Waralaba boleh dibuka dari cabang mana pun.

## **10.2 Bintang**

```text
stars_total(E) = floor( (alltime_earned_kr / prestige.stars_divisor_kr) ^ prestige.stars_exponent )
stars_gained   = stars_total − franchise_stars
```

Nilai default `stars_divisor_kr` = 1e6 dan `stars_exponent` = 0,5 (TUNABLE). Layar Waralaba menampilkan jumlah bintang yang akan didapat bila menjual sekarang, dan KR yang dibutuhkan untuk bintang berikutnya. Setiap cabang baru lebih mahal dari sebelumnya (Seksi 23.1).

## **10.3 Efek Pasif**

`franchise_mult = 1 + 0.02 × franchise_stars` (TUNABLE `prestige.income_per_star`), dikalikan ke semua harga jual (Seksi 7.2) dan karena itu juga ke penghasilan offline.

## **10.4 Perk Milestone (berdasarkan total bintang)**

| ID | Bintang | Efek |
|---|---:|---|
| `perk_offline_plus` | 1 | Batas offline +1 jam |
| `perk_head_start` | 5 | Putaran baru mulai dengan 5K KR |
| `perk_free_baker` | 10 | Asisten Dapur pertama gratis dan langsung direkrut |
| `perk_tap_double` | 25 | `tap_power` ×2 |
| `perk_offline_efficiency` | 50 | Efisiensi offline +25% |
| `perk_ruko_start` | 100 | Putaran baru mulai di Tier 2 (Ruko) |
| `perk_recipe_memory` | 250 | Putaran baru mulai dengan semua resep yang pernah dibuka |
| `perk_milestone_triple` | 500 | Milestone resep ×3, bukan ×2 |

Perk lanjutan untuk tangga jangka panjang ada di Seksi 23.2.

## **10.5 Reset**

| Direset | Disimpan |
|---|---|
| KR (ke `start_kr` + perk), lokasi (ke Tier 1 atau 2), stasiun tambahan & semua level stasiun, level dan buka resep (kecuali perk), staf, dekorasi berbonus (kembali ke inventaris, bonusnya tidak aktif sampai dibeli lagi di putaran baru), upgrade global level 1–5, boost aktif | Bintang Waralaba, perk, `alltime_earned_kr`, statistik, pencapaian dan badge, skin storefront dan pakaian, nama toko, karakter, pengaturan, nomor putaran (`run_index`), mastery resep (Seksi 23.3) |

Upgrade global di atas level 5 tetap disimpan, sebagai rasa "lebih kuat" lintas putaran.

Sejak Seksi 20 no. 78 toko lama tidak direset atau dijual: kolom "Direset" adalah awal cabang baru, sedangkan cabang lama tetap seperti ditinggal, menabung seperti penghasilan offline, dan bisa dikunjungi dan dimainkan dari Peta Crumbtown (Seksi 21.7).

## **10.6 Alur**

Layar Waralaba → tombol **Open a New Branch** (dulu Sell & Franchise, Seksi 20 no. 78) → konfirmasi → cutscene Pak Lurah (mekanisme v3.1 §45): investor mendanai cabang baru (dulu: membeli toko), papan nama baru → loading → garasi baru dengan nama toko yang sama dan "Branch #{run_index}". Autosave kritis sebelum dan sesudah reset.

---

# **11. Boost & Hadiah**

## **11.1 Kopi Pak Lurah (Hadiah Harian)**

Sekali per **hari kalender perangkat**: ×2 penghasilan selama 15 menit nyata (TUNABLE). Boost hanya berjalan selama bermain aktif; sisanya disimpan dan tidak berlaku saat offline. Bila iklan berhadiah tersedia, pemain boleh menuang kopi lagi dengan menonton iklan (`coffee_refill`, Seksi 22.4).

## **11.2 Promosi (dulu Kampanye Pemasaran)**

| ID | Efek | Durasi nyata | Biaya | Jeda |
|---|---|---|---|---|
| `promo_flyer` | Kedatangan ×1,5 | 5 menit | 3 menit penghasilan (`rate × 180`) | 10 menit |
| `promo_radio` | Kedatangan ×2 | 10 menit | 8 menit penghasilan | 30 menit |
| `promo_food_vlogger` | Kedatangan ×2, RotiFood ×2 | 10 menit | 15 menit penghasilan | 60 menit |

Biaya diskalakan dengan KR/s saat itu supaya promosi selalu relevan. Food Vlogger dari v3.1 menjadi promosi ini. Semua angka TUNABLE. Jeda promosi bisa diselesaikan dengan menonton iklan (`promo_skip`, Seksi 22.4).

## **11.3 Cuaca & Libur**

Hujan: kedatangan ×0,8 dan RotiFood ×1,5. Libur: kedatangan ×1,3. Nilai akhirnya mengikuti katalog cuaca v3.1 §26.6 yang disetel ulang untuk idle.

## **11.4 Pencapaian**

Pencapaian v3.1 diganti dengan milestone idle (contoh: First Sale, Earn 1K/1M/1B/1T, Station Lv 100, Recipe Lv 100, All Recipes, Tier 5, First Franchise, 10 Franchises). Hadiahnya badge dinding (v3.1 §72.1) dan satu boost ×2 selama 10 menit. Daftar lengkapnya ada di katalog `achievements.json` yang baru.

---

# **12. UI/UX**

## **12.0 Orientasi Potret & Bingkai Layar — CANONICAL**

Keputusan maintainer 2026-10-25 (Seksi 0.3 no. 6). Mengganti orientasi landscape v3.1 (§12.5, §28.4, §30.1, §110).

### **12.0.1 Orientasi**

- **Satu-satunya orientasi adalah potret.** Resolusi logis dasar **720 × 1280** (9:16).
- **Android:** orientasi dikunci potret (`display/window/handheld/orientation = portrait` dan preset ekspor Android).
- **Web:** kanvas tetap mengisi seluruh jendela browser, dan game menggambar bingkai potret di tengahnya (Seksi 12.0.2).
- **Desktop/editor:** ukuran jendela awal **540 × 960** (`window/size/window_width_override`/`window_height_override`) supaya muat di layar laptop. Jendela bebas di-resize; bingkai menyesuaikan.

### **12.0.2 Bingkai Potret**

- Seluruh game (dunia 3D, HUD, modal, splash, Main Menu, loading, cutscene) digambar **di dalam satu bingkai potret** di tengah jendela. Di luar bingkai hanya ada taplak (Seksi 12.0.3).
- **Lebar logis bingkai selalu 720.** Tingginya mengikuti layar dengan rasio lebar : tinggi dijepit antara **9:16 dan 9:21**:

| Bentuk layar | Contoh | Hasil |
|---|---|---|
| Lebih ramping dari 9:21 | Sangat jarang | Bingkai 9:21 setinggi layar; pita taplak tipis di atas dan bawah |
| Antara 9:16 dan 9:21 | Sebagian besar HP potret (9:16, 19.5:9, 20:9) | Bingkai mengisi layar penuh (tinggi logis 1280–1680), **tanpa taplak** |
| Lebih lebar dari 9:16 | Tablet 3:4, laptop, PC, HP yang dimiringkan | Bingkai 9:16 setinggi layar di tengah; **taplak di kiri dan kanan** |

- Ketukan, klik, dan seretan di area taplak diabaikan. Gulir roda mouse di atas taplak juga diabaikan.
- Bingkai tidak punya bayangan, bingkai foto, atau lekukan (gaya datar v3.1 §130.6). Tepinya bertemu renda taplak (Seksi 12.0.3).
- **Teknik yang direkomendasikan:** `scenes/main.tscn` menjadi `PortraitShell` (Control layar penuh) yang berisi `TableclothSides` di belakang dan `SubViewportContainer` (stretch) berisi `SubViewport`, dengan `GameRoot` di dalamnya. Ini diperlukan karena dua hal: Camera3D tidak bisa merender hanya ke sebagian viewport, dan pita hitam bawaan mode aspect `keep` Godot tidak bisa digambari.
  - `SubViewport` memakai `size_2d_override` 720 × H, sehingga koordinat UI logis tetap. Ukuran render mengikuti piksel layar sebenarnya, jadi gambar tetap tajam.
  - `SubViewportContainer` meneruskan input. Tes yang membuat `GameRoot` langsung (tanpa shell) tetap bekerja seperti sekarang.
  - Root project: viewport 720 × 1280, stretch `canvas_items`, aspect `expand`; `PortraitShell` menghitung kotak bingkai dari ukuran root.
- **Web, ketukan Tap to Start:** meminta layar penuh dan mengunci orientasi **potret** bila browser mengizinkan (`WebPlatform.enter_fullscreen_portrait()`, pengganti `enter_fullscreen_landscape`; aturan gestur selesai v3.1 tetap berlaku).

### **12.0.3 Taplak di Sisi Layar**

- Area di luar bingkai diisi **taplak meja gingham** yang sama dengan taplak di tepi bawah layar pembuka (`CozyBackdrop`): warna `Palette.GINGHAM_A` dan `Palette.GINGHAM_B`, petak 22 px logis, pola kotak-kotak bergantian. Taplak memenuhi seluruh tinggi layar di kiri dan kanan, atau seluruh lebar di atas dan bawah untuk layar yang sangat ramping.
- Di sisi yang bersentuhan dengan bingkai ada **renda krem bergelombang** seperti renda taplak layar pembuka, sehingga game terlihat seperti diletakkan di atas meja bertaplak.
- Ikon samar yang melayang dari `CozyBackdrop` (roti, koin, bintang, hati) ikut muncul di atas taplak dengan opasitas rendah. Reduced Motion menghentikan gerakannya.
- Kode gambar gingham dipindahkan dari `CozyBackdrop._draw` ke satu helper bersama (misalnya `ProceduralUIFactory.draw_gingham(canvas, rect, lace_edge)`) yang dipakai `CozyBackdrop` dan `TableclothSides`, sehingga keduanya identik.
- Taplak murni `_draw()` 2D tanpa tekstur atau gambar (v3.1 §111). Bidang taplak hanya digambar ulang saat ukuran jendela berubah; yang beranimasi hanya ikon melayang.
- Taplak tidak menampilkan informasi game apa pun, tanpa HUD, iklan, atau tombol.

### **12.0.4 Kamera Gameplay Potret (mengganti v3.1 §30.1)**

- Sudut kamera tetap (yaw dan pitch `camera.*` v3.1). Kamera ortografis memakai **`keep_aspect = KEEP_WIDTH`**: nilai `size` adalah **lebar** dunia yang terlihat. Lebar terlihat sama di semua HP; layar yang lebih tinggi hanya melihat lebih banyak jalan di atas dan bawah toko.
- `camera.portrait_width_m` (TUNABLE, awal **5,6 m**) memuat lebar lantai Tier 1–3 utuh. Zoom mengikuti rentang `camera.min/max` yang dihitung ulang untuk potret.
- Lantai Tier 4–5 lebih lebar dari layar: kamera mengikuti pemilik dan bisa digeser dengan seret, seperti aturan lantai besar v3.1 §30.
- Bingkai menyisakan ruang untuk HUD (kira-kira 130 px logis di atas dan 170 px di bawah). Fokus kamera digeser supaya lantai berada di antara kedua bar.
- Lingkungan v3.1 §32.5 kini lebih banyak terlihat di atas dan bawah toko. Jangkauan dan jarak pudar `NeighborhoodFactory` diperpanjang seperlunya. Aturan "tidak boleh menutupi lantai" (`ACC_32_NEIGHBORHOOD_CLEAR`) tetap berlaku untuk kamera potret.

### **12.0.5 Tata Letak UI Potret**

- **HUD** (Seksi 12.1): bar atas, bar tab bawah berisi 6 tombol (masing-masing sekitar 110 × 96 px logis, jauh di atas batas 48 px), dan chip level di dunia.
- **Layar besar** (Upgrades, Menu, Staff, Shop, Decor, Franchise, Stats) menjadi **lembar bawah** selebar bingkai yang naik dari atas bar tab, tingginya maksimal 85% bingkai. Isinya daftar yang hanya bergulir vertikal. Detail item (misalnya staf atau resep) terbuka sebagai halaman berikutnya di lembar yang sama, dengan tombol Back. Tidak ada tabel lebar dan tidak ada gulir menyamping.
- **Popup kecil** (konfirmasi, Welcome Back, Waralaba): kartu di tengah, lebar maksimal 640 px logis.
- **Splash dan popup toko baru:** logo di sepertiga atas dan Tap to Start di tengah, `CozyBackdrop` (dengan taplak di tepi bawah) tetap menjadi latar di dalam bingkai. Tidak ada Main Menu (Seksi 19 no. 21).
- **Kartu upgrade stasiun** melayang di atas stasiun. Bila tidak muat di atasnya, kartu menempel tepat di atas bar tab.
- **Decoration Mode:** bar atas dan tab item di bawah mengikuti pola v3.1 §72.2 yang disusun ulang untuk lebar 720.
- Skala teks 100/125/150% wajib muat di lebar 720 tanpa gulir menyamping (pengganti `ACC_7_*_NO_SCROLL` v3.1).
- **Safe area:** notch dan kamera lubang di atas serta bar gestur di bawah menggeser bar HUD ke dalam (v3.1 §12.4 berlaku pada bingkai).

### **12.0.6 Ponsel yang Dimiringkan**

- Layar pemblokir "Rotate your phone" v3.1 §12.5 **dihapus**. Bingkai potret dengan taplak di kedua sisi tetap bisa dimainkan.
- Di browser ponsel yang dipegang landscape, muncul sekali petunjuk yang tidak menghalangi: "Turn your phone upright for a bigger view." Petunjuk hilang sendiri setelah 4 detik.
- Aplikasi Android dikunci potret, jadi situasi ini hanya terjadi di browser ponsel.

### **12.0.7 Matriks Resolusi (mengganti v3.1 §110)**

| Kelompok | Ukuran |
|---|---|
| HP potret | 720 × 1280, 1080 × 1920 (9:16), 1080 × 2340 (19.5:9), 1080 × 2400 (20:9) |
| Tablet | 1536 × 2048 (3:4 potret), 2048 × 1536 (4:3 landscape) |
| Laptop/PC landscape | 1280 × 720, 1366 × 768, 1920 × 1080, 2560 × 1440, 2560 × 1080 (ultrawide) |
| Skala teks | 100%, 125%, 150% di setiap ukuran |

`tools/ui_resolution_sweep.tscn` diperbarui ke matriks ini dan juga memeriksa bahwa tidak ada kontrol game yang muncul di area taplak.

## **12.1 HUD**

Semua posisi relatif terhadap bingkai potret (Seksi 12.0), di dalam safe area.

- **Kiri atas:** KR besar (`Tx.big`), di bawahnya "+{rate}/s" dari `IdleEconomy`, serta ikon boost aktif dengan sisa waktu.
- **Kanan atas:** Bintang Waralaba, tombol pause/pengaturan.
- **Bawah, bar tombol:** Upgrades · Menu · Staff · Shop · Decor · Franchise. Setiap tombol diberi titik hijau bila ada sesuatu yang terjangkau di dalamnya.
- **Dunia:** chip level di atas setiap stasiun ("Lv 12"), dengan panah naik yang berdenyut bila upgrade ×1 terjangkau. Chip adalah kontrol 2D yang diproyeksikan, dengan target sentuh ≥ 48 px (v3.1 §12.4); sejak Seksi 20 no. 77 pilnya besar (teks 20 px, target sentuh sekitar 120 × 63 px) dan ditata supaya tidak saling tumpuk atau tertutup panel HUD.
- Tidak ada lagi jam fase, tombol kecepatan, Skip to Open, Close Early, panel stok, atau panel pesanan RotiFood. Jam kecil tetap ada untuk suasana.

## **12.2 Kartu Upgrade Stasiun**

Dibuka dengan mengetuk chip level. Mengetuk perabotnya sendiri hanya memberi Semangat dan tidak membuka kartu (Seksi 20 no. 77, menggantikan no. 69). Kartu melayang di atas stasiun seperti toolbar Decoration Mode (v3.1 §72.2):

- Judul "Oven · Lv 12", efek sekarang → berikutnya ("Bake speed ×2.30 → ×2.40").
- Bar ke milestone berikutnya ("Lv 25: speed ×2").
- Biaya, tombol ×1 / ×10 / Max.

## **12.3 Layar**

| Layar | Isi |
|---|---|
| **Upgrades** | Semua upgrade (stasiun, resep, staf, global), diurutkan "Best value first" = Δ(KR/s) ÷ biaya. Tombol ×1/×10/Max per baris |
| **Menu** | Daftar resep dengan gambar `BreadArt`: kunci/biaya buka, level, harga jual, tombol upgrade. Juga petak rak, untuk menetapkan resep per petak (atau "Auto") |
| **Staff** | Daftar staf dan kandidat vertikal; detail sebagai halaman berikutnya di lembar bawah (Seksi 12.0.5): rekrut dan level |
| **Shop** | Upgrade lokasi (Current → Next seperti v3.1 Store Upgrade), buka stasiun baru, upgrade global |
| **Decor** | Toko dekorasi (dengan bonus) dan Decoration Mode v3.1 §72 |
| **Franchise** | Bintang sekarang dan yang akan didapat, pengali, perk (tercapai/terkunci), tombol Sell & Franchise |
| **Welcome Back** | Seksi 9.5 |
| **Stats** | Pengganti Daily Summary: KR/s, penghasilan putaran dan sepanjang masa, roti terjual, waktu bermain dan offline, rekor |

Pengaturan, pause, bantuan, dan loading mengikuti v3.1 §89 dengan teks baru. **Tidak ada Main Menu, layar profil, maupun Load Game** (Seksi 19 no. 21): Tap to Start langsung memuat satu-satunya save, atau membuka popup toko baru (karakter, lalu nama toko) bila belum ada save. Yang dulu ada di Main Menu pindah: Settings dan Credits ke menu Pause, Exit menjadi Quit Game di Pause (kecuali Web), Export Save, Import Save, dan Reset Game ke Settings > Gameplay (Seksi 20 no. 68).

## **12.4 Layar yang Dihapus**

Market (semua tab), Recipe Book lama, Customer Order popup, RotiFood popup & reject confirm, Display Detail (buang roti), Daily Summary, Marketing (diganti Promosi di Upgrades), ReplacePicker, layar Skip/Close Early, Solo Mode, cutscene bangkrut, overlay "Rotate your phone".

## **12.5 Umpan Balik**

Koin melompat dari kasir saat transaksi, angka mengambang "+{amount}" (dikelompokkan bila banyak), kilau level-up, ledakan konfeti kecil saat milestone, efek "evolusi" saat model alat berganti tier, dan pulsa hijau pada tombol bar bila sesuatu terjangkau. Reduced Motion mematikan lompatan dan konfeti (v3.1 §44).

---

# **13. Onboarding**

Menggantikan tutorial Hari 1–3 v3.1 (§27, §88). Durasinya sekitar 3 menit dan **tidak pernah menahan ekonomi**. Spotlight memakai `TutorialSpotlight`/`CoachMarks` yang ada, dan setiap langkah bisa ditutup.

**Panduan ketuk** (keputusan maintainer 2026-11-02, Seksi 19 no. 15): langkah yang meminta pemain mengetuk sesuatu meredupkan layar kecuali yang harus diketuk, dan sasaran itu **berkedip** terang. Ketukan di sasaran sampai ke tombolnya, bagian lain tertahan lapisan redup. Setelah pemain membuka tab atau chip yang benar, sorotan pindah ke tombol berikutnya di lembar atau kartu yang terbuka, dengan teks balon yang ikut berganti. Balon punya tombol **Not now**. Toko tetap berjalan selama panduan tampil.

| Langkah | Pemicu | Isi |
|---|---|---|
| `onb_welcome` | Mulai | Pak Lurah: "Your bakery runs itself. Watch your first bread sell!" |
| `onb_first_sale` | Penjualan pertama | Spotlight KR dan KR/s |
| `onb_first_upgrade` | Upgrade oven terjangkau | Panduan: chip level oven, lalu tombol ×1 di kartu upgrade |
| `onb_tap_boost` | Setelah upgrade pertama | Panduan: "Tap a working station to speed it up!" di stasiun yang sedang bekerja; modelnya berkedip |
| `onb_hire` | KR ≥ biaya rekrut pertama | Panduan: tab Staff, lalu tombol Hire seorang Kitchen Assistant |
| `onb_recipe` | KR ≥ biaya buka resep kedua | Panduan: tab Menu, lalu tombol Unlock (petak Auto langsung menjual resep yang paling untung) |
| `onb_offline` | Kunjungan kedua | Popup Selamat Datang dijelaskan sekali |
| `onb_location` | Lokasi Tier 2 terjangkau | Panduan: tab Shop, lalu tombol Move |
| `onb_franchise` | Waralaba pertama kali tersedia | Panduan: tab Franchise, lalu tombol Sell & Franchise dengan penjelasan apa yang tetap dibawa; Not now bila belum mau |

---

# **14. Visual & Audio Tambahan**

- **Evolusi model:** saat tier model berganti, model lama mengecil sambil berkilau dan model baru melompat keluar (squash & stretch, v3.1 §4.2). Model dari `EquipmentFactory.build_cached` (MeshBake).
- **Chip level, angka mengambang, koin:** kontrol dan partikel prosedural memakai kit UI datar v3.1 §130.6 dan material bersama (aturan CLAUDE.md: tanpa material baru per kemunculan, didaftarkan di `ShaderWarmup`).
- **Uang di kasir:** koin kecil melompat dari meja ke HUD, tanpa tumpukan uang yang harus dipungut.
- **Audio baru** (disintesis di `audio_generator.gd`): `level_up`, `milestone_fanfare`, `tap_boost_pop`, `coin_shower`, `franchise_jingle`, `welcome_back_chime`. Bunyi gosong dan "roti basi" dihapus.

---

# **15. Teknis**

## **15.1 Manager & Sistem**

| Status | Sistem | Perubahan |
|---|---|---|
| **Baru** | `UpgradeManager` | Level stasiun, resep, staf, dan global; rumus biaya; ×1/×10/Max; pemilik state level |
| **Baru** | `IdleEconomyManager` | Model analitik Seksi 9.1, KR/s HUD, rekomendasi "best value" |
| **Baru** | `OfflineManager` | `last_active_unix`, rate tersimpan, perhitungan dan popup offline, jam mundur |
| **Baru** | `PrestigeManager` | Bintang, perk, reset waralaba |
| **Baru** | `BoostManager` | Kopi Pak Lurah, promosi, hadiah pencapaian (menggantikan `MarketingManager`) |
| **Baru** | `PortraitShell` (`scenes/main.tscn`), `TableclothSides` | Bingkai potret, SubViewport berisi `GameRoot`, taplak di luar bingkai (Seksi 12.0.2–12.0.3) |
| **Diubah** | `CameraRig` | `KEEP_WIDTH`, lebar terlihat `camera.portrait_width_m`, fokus di antara bar HUD (Seksi 12.0.4) |
| **Diubah** | `WebPlatform`, `OrientationGuard` | Layar penuh + kunci potret; pemblokir "Rotate your phone" diganti petunjuk sekali (Seksi 12.0.6) |
| **Diubah** | `HUD`, semua layar, `CozyBackdrop`, `project.godot`, `export_presets.cfg` | Tata letak potret (Seksi 12.0.5); helper gingham bersama; viewport 720 × 1280, jendela desktop 540 × 960, Android potret |
| **Diubah** | `TimeManager` | Jam 24 jam kontinu, tanpa fase; nomor hari pukul 00:00; tanpa kecepatan 2×/3× |
| **Diubah** | `SimulationRoot` | Tanpa `close_day`, `_begin_day` fase, Skip, Close Early; rollover harian ringan (cuaca, libur, statistik) |
| **Diubah** | `ProductionManager` | Tanpa `OVERBAKING`/`BURNT`, tanpa pembusukan meja; biaya bahan saat batch dimulai |
| **Diubah** | `DisplayInventoryManager` | Petak ber-resep, tanpa kesegaran/umur/buang; kapasitas dari level |
| **Diubah** | `PlayerTaskManager` | Pemilik jadi pekerja otomatis (Seksi 5.1) + ketukan arahan & Semangat |
| **Diubah** | `StaffManager` | Pemilihan kerja Seksi 4.3 untuk koki; kasir selalu bertugas; tanpa gaji dan duty |
| **Diubah** | `CustomerManager`, `DemandManager` | Kedatangan kontinu Seksi 6.1, tanpa manifest; tanpa filter kesegaran/harga manual |
| **Diubah** | `CashierManager` | Transaksi otomatis dengan durasi dari level kasir; jalur A dilayani pemilik otomatis |
| **Diubah** | `RotiFoodManager` | Terima, pesan stok, dan kemas otomatis; tanpa tolak |
| **Diubah** | `EconomyManager` | Kategori ledger Seksi 7.4; tanpa gaji, utilitas, talangan |
| **Diubah** | `TutorialManager`, `AchievementManager`, `StatisticsManager` | Seksi 13, 11.4, 12.3 Stats |
| **Dihapus** | `ReputationManager` (tanpa rating, Seksi 6.6), `SupplyOrderManager`, `InventoryManager` (stok bahan), `PricingManager` (harga manual), `BailoutManager`, `DayReportManager`, `AnalyticsManager` (diganti Stats) | Beserta UI dan tesnya |

Aturan kepemilikan state v3.1 §98 tetap berlaku: setiap field baru punya tepat satu manager pemilik.

## **15.2 Katalog `idle.json`**

Satu-satunya rumah untuk nilai TUNABLE dokumen ini, divalidasi saat boot oleh `DataRegistry` (v3.1 §101, §134). Kerangka:

```json
{
  "catalog_schema_version": 1,
  "start_kr": 50,
  "night": {"from_hour": 22, "to_hour": 6, "arrival_mult": 0.4, "rotifood_mult": 0.6},
  "tap": {"progress_seconds": 0.5, "min_interval_seconds": 0.12},
  "owner": {"focus_seconds": 10},
  "station": {
    "milestones": [10, 25, 50, 75, 100, 150],
    "model_tier_thresholds": [10, 25, 50, 75],
    "level_cap_by_location": [25, 50, 75, 100, 150],
    "extra_instance_cost_mult": 3,
    "mixer":   {"cost_base": 30, "cost_growth": 1.15, "speed_per_level": 0.05, "milestone_mult": 2},
    "oven":    {"cost_base": 40, "cost_growth": 1.15, "speed_per_level": 0.05, "milestone_mult": 2},
    "display": {"cost_base": 50, "cost_growth": 1.15, "capacity_per_level": 0.04, "price_per_level": 0.01},
    "counter": {"cost_base": 60, "cost_growth": 1.15, "checkout_base_seconds": 3.0, "checkout_factor": 0.97, "checkout_min_seconds": 1.0},
    "open_cost": {"mixer": 150, "oven": 200, "display": 200},
    "open_growth": 8
  },
  "recipe": {"unlock_mult": 150, "level_cost_mult": 10, "level_cost_growth": 1.12,
             "price_per_level": 0.10, "milestones": [25, 50, 100, 150, 200, 300, 400, 500], "milestone_mult": 2},
  "staff": {"hire_cost": [300, 3000, 60000, 1500000], "speed_per_level": 0.04, "level_cost_base": 100, "level_cost_growth": 1.15},
  "location": {"upgrade_cost": [0, 5000, 250000, 25000000, 5000000000],
               "base_arrivals_per_hour": [24, 32, 42, 54, 70],
               "rotifood_orders_per_hour": [3, 4, 6, 8, 10]},
  "rotifood": {"price_mult": 1.1},
  "decor": {"price_mult_by_tier": [1, 20, 400, 8000, 160000]},
  "offline": {"base_cap_hours": 2, "max_cap_hours": 12, "base_efficiency": 0.5, "max_efficiency": 1.0,
              "min_away_seconds": 60, "popup_min_seconds": 300},
  "prestige": {"unlock_location_tier": 3, "stars_divisor_kr": 1000000, "stars_exponent": 0.5, "income_per_star": 0.02,
               "keep_global_levels_above": 5},
  "boosts": {"daily_gift": {"mult": 2, "minutes": 15},
             "promo": [{"id": "promo_flyer", "arrival_mult": 1.5, "minutes": 5, "cost_income_minutes": 3, "cooldown_minutes": 10}]},
  "global_upgrades": [{"id": "global_offline_hours", "cost_base": 2000, "cost_growth": 12, "max_level": 6}]
}
```

Perubahan katalog lain:

- `equipment.json`: harga jual-beli dihapus; tambah `level_effect` per kategori bila perlu.
- `recipes.json`: tambah `unlock_free` untuk Roti Tawar Polos.
- `decorations.json`: tambah `bonus`.
- `balance.json`: hapus bagian kesegaran, gosong, gaji, utilitas, pasar, talangan, manifest, Smart Speed.
- `opening.json`: dihapus.
- `achievements.json` dan `strings_en.json`: ditulis ulang untuk konten Seksi 11.4 dan 18.

## **15.3 Save**

- **Satu save** (Seksi 19 no. 21; mengganti tiga profil v3.1 §34/§89.3/§106). Tulis atomik dan satu generasi backup v3.1 §34/§106 tetap. Root save baru: `"game_mode": "idle"`, `"schema_version": 1` (skema idle mulai dari 1).
- Field baru: `upgrades` (level per instance, resep, staf, global), `recipes_unlocked`, `slot_recipes` (resep per petak), `franchise` (`stars`, `run_index`, `perks`), `offline` (`last_active_unix`, `rate_kr_per_s`), `boosts` (aktif dan sisa detik, hadiah harian terakhir), `stats` (`run_earned_kr`, `alltime_earned_kr`, `offline_seconds_total`, dll.).
- Field dihapus: kesegaran stack, kualitas, `inventory`, `supply_orders`, `pricing`, `bailout`, `reports`, manifest, wage liability, rating. Save idle dari sebelum rating dihapus tetap dimuat; `reputation` dan rekor `highest_reputation` di dalamnya dibuang.
- **Save v3.1 (tycoon) tidak didukung** dan tidak dimigrasi: game memperlakukannya seperti belum ada save, dan toko baru memindahkannya ke slot kosong lebih dulu supaya tidak tertimpa diam-diam (Seksi 20 no. 68).
- **Kode save** (Seksi 20 no. 57): save bisa diekspor sebagai teks (Export Save) dan diimpor (Import Save, menggantikan toko yang sedang dimainkan setelah konfirmasi), keduanya di Settings > Gameplay, untuk pindah perangkat atau cadangan di luar browser.

## **15.4 Determinisme**

Simulasi hidup tetap deterministik per seed (v3.1 §102, §116) supaya tes dan probe tetap andal. Waktu offline tidak disimulasikan, melainkan dihitung analitik (Seksi 9). Golden fixture baru dibuat untuk skema idle.

## **15.5 Performa**

Game akan dibiarkan terbuka lama. Anggaran v3.1 §109 dan §109.3 tetap berlaku: draw call dari model dipanggang, simulasi dengan cache identik bit-per-bit. Chip level dan angka mengambang memakai pool (v3.1 §129). Saat tab tersembunyi simulasi berhenti, jadi tidak ada biaya baterai di latar.

## **15.6 Platform**

Web dan Android seperti v3.1, tetapi **potret** (Seksi 12.0): Android dikunci potret, web menampilkan bingkai potret dengan taplak di sisi pada layar lebar. Notifikasi push tidak dibuat (butuh plugin; dilarang engine lock).

---

# **16. Tes Penerimaan (ID Baru)**

| ID | Memeriksa |
|---|---|
| `ACC_IDLE_NO_INPUT` | New Game yang dibiarkan 30 menit nyata (simulasi) terus menjual, tidak pernah macet, dan saldo tidak pernah negatif |
| `ACC_IDLE_NO_BURN_NO_STALE` | Tidak ada state gosong atau basi; loyang matang menunggu tanpa batas, roti tidak menua |
| `ACC_IDLE_AUTOMATION` | Pemilik melayani jalur A tanpa kasir, koki mengisi petak dengan rasio terendah, RotiFood diterima dan dikemas otomatis |
| `ACC_IDLE_TAP_BOOST` | Semangat menambah progres yang tepat dan menghormati jeda minimum |
| `ACC_IDLE_COSTS` | Rumus biaya, ×1/×10/Max, dan batas level tepat (termasuk Max di perbatasan batas) |
| `ACC_IDLE_MILESTONES` | Pengali milestone dan evolusi model, termasuk pindah tempat bila jejak tidak muat |
| `ACC_IDLE_MODEL_MATCH` | KR/s analitik dalam ±20% dari simulasi hidup di toko contoh Tier 1–5 |
| `ACC_IDLE_OFFLINE` | Rumus offline, batas, efisiensi, jam mundur = 0, ambang popup, masuk ke statistik |
| `ACC_IDLE_PRESTIGE` | Rumus bintang, perk, dan daftar reset/simpan Seksi 10.5 persis |
| `ACC_IDLE_BIG_NUMBERS` | Format K…T…aa…zz dan scientific; tidak ada overflow sampai 1e300 |
| `ACC_IDLE_SAVE` | Roundtrip skema idle; save v3.1 terdeteksi dan ditolak dengan rapi |
| `ACC_IDLE_ONBOARDING` | Langkah Seksi 13 terpicu sekali dan tidak menahan ekonomi |
| `ACC_IDLE_PACING` (lama) | Probe idle mencapai milestone Seksi 1.4 dalam rentang target |
| `ACC_IDLE_PORTRAIT_FRAME` | Kotak bingkai benar untuk setiap baris tabel Seksi 12.0.2 (lebar logis 720, rasio dijepit 9:16–9:21, berada di tengah); input di luar bingkai diabaikan |
| `ACC_IDLE_TABLECLOTH_SIDES` | Area di luar bingkai digambar taplak gingham dengan renda di tepi bingkai; tidak ada kontrol game di sana; layar HP 9:16–9:21 tidak menampilkan taplak |
| `ACC_IDLE_PORTRAIT_CAMERA` | `KEEP_WIDTH`; lantai Tier 1–3 terlihat utuh selebar layar di antara bar HUD; lingkungan tidak menutupi lantai dari kamera potret |
| `ACC_IDLE_PORTRAIT_UI` | Matriks Seksi 12.0.7: setiap layar terbuka tanpa kontrol keluar bingkai dan tanpa gulir menyamping di 100/125/150% |
| `ACC_IDLE_ADS` | Seksi 22.1, 22.4: hadiah hanya setelah iklan selesai, toko di-pause dan senyap selama iklan, batas harian, tombol tersembunyi tanpa iklan |
| `ACC_IDLE_SUPPORTER` | Seksi 22.5: No Ads (dulu Supporter Pack) dijual di Store, memberi hadiah tanpa iklan dan badge, tersimpan di perangkat, dipulihkan dari toko |
| `ACC_IDLE_CRUMBS` | Seksi 22.3: crumbs awal, sumber gratis, belanja tidak di bawah nol, save dan save lama |
| `ACC_IDLE_AD_BOOST` | Seksi 22.4: boost ×2 menumpuk sampai batas, berjalan dengan jam nyata, bagian offline yang tertutup boost dikali ×2 |
| `ACC_IDLE_TIME_WARP` | Seksi 22.6: time warp membayar KR/s model, dihitung sebagai penghasilan, memakai crumbs |
| `ACC_IDLE_PERKS` | Seksi 22.5: Golden Oven, Night Manager, Baker's Club; hak beli tidak masuk save |
| `ACC_IDLE_PASS` | Seksi 22.7: tingkat, klaim gratis dan premium, Claim all, pergantian musim, barang musim ganda |
| `ACC_IDLE_STORE_PURCHASES` | Seksi 22.5, 22.9: paket, hak beli, Restore, penawaran berbatas waktu, berkas perangkat lama |
| `ACC_IDLE_STORE_UI` | Seksi 22.2, 22.5, 22.8: tombol Store dan chip crumbs, lima tab, konfirmasi toko uji, iklan tiruan, beli kosmetik |
| `ACC_IDLE_PREMIUM_DECOR` | Seksi 22.8: model kosmetik dalam anggaran, bonus selalu aktif, pakaian dan kanopi di dunia |
| `ACC_IDLE_DOORS` | Seksi 20 no. 100, 101, 22.8: pintu masuk dan papan nama berbeda tiap tier (lampu mulai Tier 3, karpet mulai Tier 4), minimal lima skin pintu dengan papan bertemanya dijual dengan Golden Crumbs, kanopi naik di atas hiasan papan, semua di bawah papan nama dan dalam anggaran segitiga, skin menggantikan pintu tier di toko dan di perayaannya |
| `ACC_IDLE_SIGN_FITS_NAME` | Seksi 20 no. 103: papan nama selebar namanya (diukur dengan hurufnya), di dalam muka toko tiap tier dan gaya papan; nama terlalu lebar mengecil, tidak terpotong atau tertutup hiasan; papan 2D mengecilkan nama panjang |
| `ACC_IDLE_STORE_CELEBRATION` | Seksi 22.11: perayaan barang Style dengan model 3D dan Place it, lencana produk, crumbs terbang dan dihitung naik, chip boost memantul, toast menunggu, Reduce motion |
| `ACC_IDLE_PORTALS` | Seksi 22.2: preset CrazyGames dan Poki memuat SDK-nya, PWA mati, dan build biasa tanpa SDK |
| `ACC_IDLE_BRANCH_COSTS` | Seksi 23.1: mulai `branch_cost_start`, biaya pindah lokasi dikali `max(1, branch_cost_base × pengali_bintang ^ branch_cost_power)`; biaya lain, harga jual, dan promosi tidak |
| `ACC_IDLE_PERKS_LATE` | Seksi 23.2: perk lanjutan memberi efeknya |
| `ACC_IDLE_MASTERY` | Seksi 23.3: roti terjual menaikkan mastery, harga naik, bertahan setelah Waralaba, ikut model KR/s, dan berlanjut tanpa ujung sesudah ambang terakhir |
| `ACC_IDLE_LEGACY` | Seksi 23.2: level Legacy sesudah perk terakhir mengalikan penghasilan dan ikut harga cabang; baris Legacy di layar Waralaba |
| `ACC_IDLE_ENDLESS_SERIES` | Seksi 23.4: seri pencapaian naik level tanpa batas dengan boost dan toast, tersimpan, tampil di lembar Stats |
| `ACC_IDLE_TOWN_BONUS` | Seksi 23.5: bonus kota dari tier tertinggi setiap cabang, nol di putaran 1, dibatasi `town.max_bonus`, bagian dari harga; tampil di peta dan layar Waralaba |
| `ACC_IDLE_SIGNATURE` | Seksi 23.6: roti khas tetap per benih dan cabang, tidak sama dengan cabang sebelumnya, tidak ada di cabang 1, ×`signature_mult` di harga; pil di lembar Menu |
| `ACC_IDLE_STREET_VARIANT` | Seksi 23.6: warna bangunan tetangga berganti per cabang dengan geometri yang sama |

Tes v3.1 yang menyangkut sistem yang dihapus ikut dihapus. Tes visual, performa, dan web (§89, §109, §130) dipertahankan. Tes layout dan UI yang mengandaikan 1280 × 720 landscape diubah ke bingkai potret.

---

# **17. Rencana Implementasi**

| Fase | Isi | Selesai bila |
|---|---|---|
| **P0** | GDD ini; kerangka `idle.json`; probe pacing analitik (spreadsheet atau skrip) untuk kurva awal | Kurva awal memenuhi Seksi 1.4 di model |
| **P1** | Hapus sistem anti-idle: gosong, kesegaran, manifest, fase hari, kasir manual, popup pesanan, RotiFood manual, pasar & kurir, gaji, utilitas, talangan, kecepatan | Game berjalan sendiri tanpa macet pada harga lama (`ACC_IDLE_NO_INPUT`, `ACC_IDLE_NO_BURN_NO_STALE`) |
| **P1b** | Shell potret (Seksi 12.0): `PortraitShell` + SubViewport, taplak gingham di sisi, kamera `KEEP_WIDTH`, HUD dan layar yang ada disusun ulang untuk potret, Android dan web potret. Dikerjakan sebelum UI baru supaya semua UI idle langsung dibangun potret | `ACC_IDLE_PORTRAIT_FRAME`, `ACC_IDLE_TABLECLOTH_SIDES`, `ACC_IDLE_PORTRAIT_CAMERA` |
| **P2** | Otomatisasi: pemilik pekerja otomatis, resep per petak, pemilihan kerja Seksi 4.3, RotiFood otomatis, Semangat | `ACC_IDLE_AUTOMATION`, `ACC_IDLE_TAP_BOOST` |
| **P3** | Sistem level: stasiun, resep, staf, lokasi, global; evolusi model; HUD KR/s; kartu upgrade; layar Upgrades/Menu/Shop | `ACC_IDLE_COSTS`, `ACC_IDLE_MILESTONES` |
| **P4** | `IdleEconomy` + offline + Welcome Back | `ACC_IDLE_MODEL_MATCH`, `ACC_IDLE_OFFLINE` |
| **P5** | Waralaba & perk | `ACC_IDLE_PRESTIGE` |
| **P6** | Boost, dekorasi berbonus, pencapaian baru, onboarding, Stats, angka besar | `ACC_IDLE_ONBOARDING`, `ACC_IDLE_BIG_NUMBERS` |
| **P7** | Balancing dengan `tools/idle_probe.tscn` (bot yang membeli upgrade "best value"), poles UI, sapuan resolusi potret (Seksi 12.0.7), save, dokumen, CLAUDE.md, release validator | `ACC_IDLE_PACING`, `ACC_IDLE_PORTRAIT_UI`, `ACC_IDLE_SAVE`, semua tes hijau |

Setiap fase berakhir dengan game yang bisa dimainkan dan tes yang hijau.

---

# **18. Teks Pemain Awal (Inggris)**

| Key | Text |
|---|---|
| `ui_kr_per_second` | `+{amount}/s` |
| `ui_level_chip` | `Lv {level}` |
| `ui_upgrade` | `Upgrade` |
| `ui_buy_x1` | `×1` |
| `ui_buy_x10` | `×10` |
| `ui_buy_max` | `Max (+{levels})` |
| `ui_next_milestone` | `Lv {level}: {effect}` |
| `ui_effect_speed` | `Speed ×{value}` |
| `ui_effect_price` | `Price ×{value}` |
| `ui_effect_capacity` | `Holds {value} per slot` |
| `ui_effect_checkout` | `Checkout {value} s` |
| `ui_tab_upgrades` | `Upgrades` |
| `ui_tab_menu` | `Menu` |
| `ui_tab_staff` | `Staff` |
| `ui_tab_shop` | `Shop` |
| `ui_tab_decor` | `Decor` |
| `ui_tab_franchise` | `Franchise` |
| `ui_best_value` | `Best value first` |
| `ui_recipe_unlock` | `Unlock for {price}` |
| `ui_slot_auto` | `Auto` |
| `ui_open_station` | `Open a new {station} for {price}` |
| `ui_welcome_back_title` | `Welcome back!` |
| `ui_welcome_back_body` | `You were away for {time}. Your bakery earned {amount}.` |
| `ui_collect` | `Collect` |
| `ui_offline_cap` | `Earns while you are away for up to {hours} h at {percent}%` |
| `ui_franchise_title` | `Franchise` |
| `ui_franchise_gain` | `Sell now for {stars} Franchise Stars` |
| `ui_franchise_next` | `{amount} more for the next star` |
| `ui_franchise_bonus` | `Every star adds {percent}% to all income` |
| `ui_franchise_confirm` | `Sell this bakery and open a new branch? Your stars, perks and badges stay.` |
| `ui_franchise_sell` | `Sell & Franchise` |
| `ui_branch_number` | `Branch #{number}` |
| `ui_daily_gift` | `Pak Lurah's coffee: income ×{mult} for {minutes} min` |
| `ui_boost_left` | `{mult}× · {time}` |
| `onb_welcome` | `Your bakery runs itself. Watch your first bread sell!` |
| `onb_tap_boost` | `Tap a working station to speed it up!` |
| `ui_classic_save` | `Classic save (not supported)` |
| `ui_turn_upright` | `Turn your phone upright for a bigger view.` |
| `ui_number_format` | `Number format` |

Kunci lain ditambahkan selama implementasi, dengan aturan v3.1 §43 dan §127 (lint bahasa Inggris, tanpa teks hardcode).

---

# **19. Keputusan yang Diambil Penulis & Pertanyaan Terbuka**

Keputusan di bawah diambil untuk melengkapi rancangan dan **perlu dikonfirmasi maintainer**. Semuanya bisa diubah tanpa merombak struktur dokumen.

| No | Keputusan | Alternatif |
|---|---|---|
| 1 | Nama game **Crumbtown: Idle Bakery Tycoon** (keputusan maintainer 2026-11-03, menggantikan "Roti Lezat Tycoon" supaya diterima pemain internasional; Seksi 20 no. 49) | Tetap "Roti Lezat Tycoon" |
| 2 | Toko **buka 24 jam** dengan kedatangan malam ×0,4 | Toko tutup malam (penghasilan berhenti, offline tetap dihitung) |
| 3 | **Meja Tunggu** dipertahankan sebagai penampung tanpa busuk | Dihapus dari semua layout |
| 4 | Bintang Waralaba **pasif + perk milestone**, tidak dibelanjakan | Pohon perk yang dibeli dengan bintang |
| 5 | **Tombol kecepatan 2×/3× dihapus**; percepatan lewat Semangat dan boost | Tetap ada |
| 6 | **Tanpa rating** (Seksi 6.6). Rancangan awal menggabungkan dua rating menjadi satu Reputasi; maintainer menghapusnya pada 2026-11-01 karena pembeli yang berbalik di pintu saat rak kosong menurunkannya terus di toko yang berjalan sendiri | Satu Reputasi ★1–5 yang mengubah kedatangan; tetap dua rating |
| 7 | **Save tycoon lama tidak didukung** (hanya bisa dihapus) | Konversi kasar ke idle (misalnya KR → modal awal) |
| 8 | Bahan dibayar otomatis saat batch dimulai; **Pasar dihapus** | Bahan gratis |
| 9 | Kejutan, pengunjung lihat-lihat, dan kehidupan jalan tetap kosmetik | — |
| 10 | Bingkai potret dijepit **9:16 sampai 9:21**: HP modern mengisi layar penuh tanpa taplak; layar yang lebih lebar mendapat taplak di sisi | Selalu tepat 9:16 (HP panjang juga mendapat pita taplak di atas dan bawah) |
| 11 | Taplak sisi = gingham penuh + renda di tepi bingkai + ikon samar melayang dari `CozyBackdrop` | Gingham polos tanpa renda dan ikon, atau seluruh `CozyBackdrop` (latar krem dengan taplak hanya di bawah) |
| 12 | HP yang dimiringkan tetap bisa main (bingkai kecil + petunjuk sekali), tanpa layar pemblokir | Layar pemblokir "Rotate your phone" versi potret |
| 13 | Jendela desktop/editor dibuka 540 × 960 | Ukuran lain |
| 14 | Toko baru menghasilkan **1 KR/s** tanpa boost; semua nilai KR diskalakan sama (Seksi 20 no. 45) dan transaksi dicatat sampai sen (Seksi 7.6). Keputusan maintainer 2026-11-02 | Sekitar 15 KR/s; KR utuh v3.1 §99.2 dengan harga yang dibulatkan |
| 15 | Langkah onboarding yang meminta ketukan meredupkan layar kecuali yang harus diketuk, dan sasaran itu berkedip (Seksi 13, Seksi 20 no. 46). Keputusan maintainer 2026-11-02 | Petunjuk di atas bar tab dengan cincin berdenyut di tab atau chip |
| 16 | UI dipoles supaya lebih rapi dan menarik, **tetap flat** (v3.1 §130.6) dan tetap berpalet krem–madu–cokelat: baris lembar menjadi kartu, tab aktif bermuka madu, dan tombol nonaktif krem yang terbaca (Seksi 20 no. 47). Permintaan maintainer 2026-11-03 | Baris tanpa kartu di lembar krem polos, tab aktif tidak ditandai, KR/s melayang di atas dunia |
| 17 | Gambar 2D yang terlalu sederhana digambar ulang, tetap flat: potret Pak Lurah, gambar di kartu profil save, dan potret karakter New Game (Seksi 20 no. 48). Permintaan maintainer 2026-11-03 | Pak Lurah dari lingkaran dan kotak polos; ikon toko cokelat kecil yang terbaca sebagai roti; potret chibi bermata titik |
| 19 | **Monetisasi diizinkan** (keputusan maintainer 2026-11-05): iklan berhadiah yang dipilih pemain di empat tempat dan satu Supporter Pack (Seksi 22); gameplay tetap offline, tanpa mata uang premium, gacha, energi, atau iklan paksa | Tetap tanpa iklan dan IAP; atau game berbayar sekali beli |
| 20 | **Umur permainan lebih panjang** (permintaan maintainer 2026-11-05): cabang Waralaba yang makin mahal, perk lanjutan sampai 5.000 bintang, dan mastery resep yang permanen (Seksi 23); putaran pertama tidak berubah | Lokasi Tier 6 ke atas (konten 3D baru per tier); putaran pertama diperlambat |
| 21 | **Satu save, tanpa Main Menu** (keputusan maintainer 2026-11-06): setelah splash dan Tap to Start pemain langsung masuk ke toko. Hanya ada satu save; permainan pertama (install baru atau Reset Game) membuka popup pilih karakter dan nama toko lebih dulu. Mengganti Main Menu, layar profil, dan tiga profil v3.1 §89.2–89.4, §34, §106 | Tiga profil dengan Main Menu seperti v3.1 §89 |
| 22 | **Variasi di rak** (keputusan maintainer 2026-11-09): setiap resep berbeda yang dijual rak menaikkan harga semua roti, dan petak Auto menyebar beberapa resep terbaik, sehingga membuka dan menaikkan resep baru menambah KR/s dan roti baru terlihat di rak (Seksi 20 no. 83). Menutup pertanyaan terbuka "resep kedua tidak pernah menguntungkan" | Bonus koleksi (setiap resep yang dibuka menaikkan harga, rak tetap menjual satu resep terbaik); biarkan |
| 23 | **Tanpa ujung yang sungguhan** (keputusan maintainer 2026-11-10, "kerjakan semuanya dari 1 sampai 4"): harga cabang mengikuti pengali bintang sehingga lama satu cabang tetap; Legacy, seri pencapaian, dan mastery tanpa batas; bonus kota dari tier tertinggi setiap cabang; roti khas dan wajah lingkungan per cabang (Seksi 23.1–23.6, Seksi 20 no. 89–92) | Pengali biaya ×1,5 per cabang; perk, pencapaian, dan mastery yang berakhir |
| 24 | **Monetisasi maksimal yang tetap menyenangkan** (keputusan maintainer 2026-11-10: "abaikan batasan dari GDD, lakukan seoptimal dan semaksimal mungkin monetasi di game ini tapi tetap pastikan game akan terasa menyenangkan"; target rilis Google Play lalu App Store; toko belum dihubungkan, pakai tombol dummy; build Android ditunda): Golden Crumbs, boost ×2 dan time warp, Golden Oven, Night Manager, Baker's Club, Bakery Pass, Starter/Branch Pack, kosmetik premium, No Ads, toko uji (Seksi 22) | Hanya iklan berhadiah dan satu Supporter Pack; tanpa mata uang premium dan pengganda permanen (aturan lama 22.1) |
| 18 | Fitur retensi dan berbagi (Seksi 21), dikerjakan berurutan: craving harian dan selera lingkungan, misi dan kalender login, share dan photo mode, event musiman, lalu peta Crumbtown. Semuanya tetap offline penuh (Seksi 1.3). Permintaan maintainer 2026-11-03 | Tanpa fitur retensi tambahan |

Pertanyaan terbuka lain: lisensi proyek (masih terbuka sejak v3.1).

---

# **20. Catatan Implementasi**

Keputusan kecil yang diambil saat implementasi karena dokumen ini tidak merincinya. Semuanya bisa diubah maintainer; nilai angkanya hidup di `data/catalog/idle.json`.

| No | Topik | Keputusan |
|---|---|---|
| 1 | P0, model pacing analitik | Model kasar (skrip di luar repo) menunjukkan nilai awal tumbuh jauh lebih cepat dari target Seksi 1.4 dan membuat resep kedua kalah menarik dari level resep. Penyetelan akhir dilakukan di P7 dengan probe simulasi hidup (`tools/idle_probe.tscn`); hasilnya di no. 39–42. |
| 2 | `start_kr` | 1.000, bukan 50: batch x1 Roti Tawar Polos berbiaya bahan 340 KR (v3.1 §61.5), jadi 50 KR membuat toko macet sebelum penjualan pertama, dan dengan 400 KR pemilik menganggur menunggu kas karena hanya satu batch yang terbiayai. |
| 3 | Jam awal New Game | 08:00 Hari 1 (`clock.start_seconds`), supaya menit pertama berlangsung siang hari. |
| 4 | Decoration Mode | Tetap mem-pause simulasi seperti v3.1 §72. Lembar bawah (Seksi 12.0.5) tidak mem-pause. |
| 5 | Ketukan arahan pada kasir | Mengirim pemilik ke jalur A walau belum ada yang menunggu di sana. Selama 10 detik fokus itu ia tetap di kasir, jalur A buka, dan antrean jalur lain menyeimbang ke sana (v3.1 §21.3). Pembeli yang sedang berjalan ke ujung antrean jalur A sambil membawa roti dihitung "menunggu" (Seksi 5.1 no. 1). |
| 6 | Kamera di lokasi dua lantai | Kamera tetap di lantai toko walau pemilik bekerja di dapur atas. Mengetuk pintu tangga memindahkan pandangan ke lantai lain dengan crossfade 0,20 s (v3.1 §30.2), dan ketukan berikutnya kembali. |
| 7 | Batch dan sisa ruang petak | Batch hanya dimulai bila hasilnya muat utuh di sisa ruang petak (Seksi 4.3), jadi petak bisa berhenti terisi sampai kurang dari satu hasil batch di bawah kapasitas. |
| 8 | Load di tengah langkah | Pembeli yang sedang berjalan ke rak saat game disimpan mempertahankan pilihan rotinya setelah load, tanpa menarik RNG lagi, supaya load menjadi titik tetap. |
| 9 | Data lama yang dibuang | `locations.json` tidak lagi menyimpan `upgrade_cost_kr`, `staff_daily_wage_kr`, `base_physical_rate`, dan `base_rotifood_rate` (sekarang dari `idle.json`). Arketipe pelanggan kehilangan field kesegaran, kualitas, batas harga, VIP, dan substitusi. Kurir pasokan, bunyi gosong, penanda "!", dan teks fitur yang dihapus ikut dibuang. |
| 10 | Musik malam | Pukul 22:00–06:00 memutar bed "after hours" v3.1 (state musik `NIGHT`). |
| 11 | Lebar kamera potret | `camera.portrait_width_m` = 6,8 m, bukan 5,6 m: dengan yaw 45° lantai 3 × 6 m Tier 1–3 selebar 6,36 m di layar, jadi 5,6 m memotong kedua sudutnya. Zoom `camera.min_width_m`–`max_width_m` = 5,6–11 m. Bar HUD untuk menggeser fokus: `camera.portrait_hud_top_px` 130 dan `portrait_hud_bottom_px` 170. Jalan sekitar (`NeighborhoodFactory`) sudah menutup layar 9:21 di semua tier, jadi jangkauannya tidak diubah. |
| 12 | UI Scale v3.1 §75.2 | Dihapus dari Settings karena lebar logis bingkai selalu 720 (Seksi 12.0.2). Ukuran teks 100/125/150% tetap ada. Resolution Scale kini berlaku pada SubViewport bingkai. |
| 13 | Scene utama | `scenes/main.tscn` adalah `PortraitShell`; GameRoot pindah ke `scenes/game_root.tscn`, yang dipakai tes dan alat yang membuat GameRoot langsung. |
| 14 | Popup dan tab | Popup kecil paling lebar 640 px (`ProceduralUIFactory.POPUP_MAX_WIDTH`). Bar tab turun ke baris berikutnya bila tidak muat. Baris Settings menaruh label di atas slider dan pilihan. Kartu profil bertumpuk satu per baris. Baki item Decoration Mode tetap carousel mendatar seperti v3.1 §72.2. |
| 15 | Umpan balik Semangat | Kilau gula di atas stasiun, pop kenyal pada modelnya, koin kecil tanpa angka, dan bunyi `tap_boost_pop`. Reduced Motion hanya menyisakan kilau dan bunyi. |
| 16 | Layar Menu (P2) | Petak rak di atas, daftar resep di bawah. "Change" membuka halaman pilihan (Auto + resep yang bisa dibuat). Resep yang belum terjangkau tier alatnya hanya menyebut syaratnya, tanpa tombol Unlock. Level resep dan tombol upgrade ditambahkan di P3. |
| 17 | `IdleEconomyManager` lebih awal | Dibangun di P3 karena KR/s HUD dan "Best value first" membutuhkannya; P4 menambah offline dan menguji akurasinya (`ACC_IDLE_MODEL_MATCH`). Rinciannya: siang dan malam dihitung terpisah lalu dirata-ratakan 24 jam; batch tunak = batch terbesar yang muat di petak; tenaga dapur = 5 aksi per batch + satu putaran jalan mixer -> oven -> rak -> mixer lewat rute sungguhan; setiap batch juga memegang alatnya selama jeda serah-terima (oven: pekerja datang mengangkat loyang, adonan diambil dari mixer dan dimasukkan, yaitu 3 interaksi + 3 kali rute mixer-oven + jeda pikir koki; tanpa koki pemilik lebih dulu mengantar loyang, jadi satu putaran penuh; mixer: ambil bahan di Gudang lalu mulai aduk); antrean dibatasi slot jalur ÷ lama seorang pembeli memegang slotnya; waktu pemilik dibagi antara kasir jalur A dan dapur; layanan = transaksi kasir + 1 detik melangkah (`SERVICE_OVERHEAD_SECONDS`) atau kemas RotiFood; syarat tier alat per resep diabaikan. Probe `tools/model_probe.tscn` membandingkan model dengan simulasi hidup (24 jam setelah 2 jam pemanasan): rasio 0,93–1,14 di toko contoh Tier 1–5 dan 1,00 di toko baru. |
| 18 | Isi layar Upgrades | Level stasiun, meja kasir, resep, staf, dan global. Pindah lokasi, buka stasiun, dan upgrade global juga ada di Shop; buka resep di Menu. Upgrade yang tidak menaikkan KR/s (mis. offline, ketukan) berada di akhir daftar. |
| 19 | Chip dan kartu | Meja kasir punya chip di atas meja jalur A. Kartu stasiun yang tidak terlihat (lantai lain) langsung menempel di atas bar tab. Efek kasir ditampilkan dalam detik nyata dengan dua desimal; KR/s di bawah 100 memakai tiga angka penting (`Tx.rate`). |
| 20 | Efek evolusi | Model lama dibuat ulang sesaat di tempat stasiun berdiri sekarang, mengecil, lalu model baru melompat keluar. |
| 21 | Buka stasiun tanpa tempat | Bila tidak ada posisi sah di lantai untuk stasiun baru (model evolusi yang besar bisa memenuhi lantai), Shop menulis "No free spot. Move furniture in Decor to make room." alih-alih tombol Open, dan tidak ada KR yang dipotong. |
| 22 | Antrean masuk | `queue.min_admission_interval_seconds` dan `pending_retry_seconds` 0,5 detik-simulasi (sebelumnya 2): dengan 2 detik, Tier 4–5 tidak bisa menerima pembeli secepat kedatangannya. |
| 23 | Kapan KR offline masuk | Pergi 1–5 menit: KR langsung masuk dengan toast "+{amount} while you were away". Pergi ≥ 5 menit: KR menunggu di `offline.pending` (ikut tersimpan) dan baru masuk saat Collect; Back sama dengan Collect. Bila game ditinggal sebelum Collect, popup tampil lagi saat profil dimuat dan penghasilan berikutnya ditambahkan ke sana. |
| 24 | Waktu di popup | Popup menyebut lama pergi yang sebenarnya ("2 h 15 min", `Tx.duration`), sedangkan penghasilannya dihitung dari waktu yang dibatasi `offline_cap`. Bila lebih lama dari batas, satu baris menjelaskan batasnya. Baris `ui_offline_cap` selalu tampil supaya pemain tahu upgrade offline. |
| 25 | Acuan waktu offline | `last_active_unix` dan `rate_kr_per_s` (KR/s model tanpa boost) dicatat SaveManager sebelum setiap save. Saat aplikasi/tab ke latar acuan dibekukan, jadi save di latar tidak menghapus waktu pergi. Waktu di Main Menu dihitung sebagai waktu pergi, karena tokonya tidak berjalan. Popup adalah lapisan sistem: tampil di atas lembar yang terbuka tanpa menutupnya dan mem-pause sampai Collect. |
| 26 | Jam saat Waralaba | Jam dan nomor hari berjalan terus: cabang baru buka pada jam yang sama, tanpa lompatan ke pagi, supaya cuaca, hari libur, dan statistik hari tidak terganggu. |
| 27 | `perk_head_start` | Saldo awal cabang baru = yang lebih besar dari `start_kr` dan `start_kr` milik perk (5.000), bukan jumlah keduanya. |
| 28 | Upgrade global saat Waralaba | Upgrade global di atas Lv 5 (`prestige.keep_global_levels_above`) disimpan dengan levelnya utuh; yang Lv 1–5 kembali ke Lv 0. |
| 29 | Dekorasi saat Waralaba | Semua dekorasi diangkat lalu dipasang lagi di tempat lamanya bila masih sah di denah baru (seperti pindah lokasi, v3.1 §105); sisanya kembali ke inventaris. Aturan bonus dekorasi Seksi 10.5 ditambahkan bersama bonusnya di P6. |
| 30 | `perk_free_baker` dan `perk_recipe_memory` | Kandidat Asisten Dapur pertama di katalog langsung direkrut tanpa biaya; rekrutan itu tetap dihitung sebagai rekrutan pertama untuk biaya rekrut berikutnya. Resep yang diingat kembali terbuka pada Lv 1. |
| 31 | Alur Waralaba | Lembar Franchise → Sell & Franchise → konfirmasi → cutscene dua halaman (Pak Lurah dengan bintang yang didapat, lalu papan nama "Branch #n"; Back maju satu halaman) → reset di simulasi yang sama → dunia dan HUD dibangun ulang di balik layar loading → toast "Branch #n is open!". Save kritis sebelum reset (`franchise_before`) dan sesudahnya. Bintang dan pengali disebut dengan bentuk tunggal untuk tepat satu bintang. |
| 32 | Boost yang bertemu | Boost penghasilan (kopi, hadiah pencapaian) tidak menumpuk: yang baru menyegarkan sisa waktu ke yang lebih panjang (misalnya sisa 1 menit menjadi 10 menit, sisa 12 menit tetap 12 menit), dengan pengali terbesar. Dengan menambah waktu, pencapaian beruntun di jam pertama membuat ×2 berjalan hampir terus-menerus, sehingga putaran kedua tidak lebih cepat dari yang pertama. Promosi berjalan satu per satu, dan jedanya dihitung sejak promosi dimulai. Semua timer memakai detik nyata permainan aktif, jadi berhenti saat pause, di latar, dan offline. Waralaba mereset boost dan jeda, tetapi kopi hari itu tetap sudah diambil. |
| 33 | Kopi Pak Lurah | Diberikan otomatis saat profil dimuat atau aplikasi kembali ke depan pada hari kalender perangkat yang baru, dengan toast `ui_daily_gift` dan `welcome_back_chime`; tidak ada tombol klaim. |
| 34 | Promosi di Upgrades | Bagian "Promotions" di atas "Best value first": efek, lama, dan tombol "Start · {biaya}", atau sisa waktu berjalan / jeda. Biaya = KR/s model tanpa boost × `cost_income_minutes` × 60, paling sedikit 1 KR. Chip HUD di bawah KR/s menunjukkan boost penghasilan dan promosi beserta sisa waktunya. |
| 35 | Bonus dekorasi | Bonus aktif sejak dibeli (tidak perlu dipasang) dan setiap jenis dekorasi memberinya sekali per putaran; dekorasi berbonus yang sudah aktif tidak dijual lagi di putaran itu. Dekorasi berbonus milik putaran lalu dinyalakan lagi dengan membelinya tanpa menambah salinan. Nilai awal (TUNABLE, `decorations.json`): pot tanaman dan gorden +2% kedatangan, radio dan kotak bunga +3%, karpet +4%; jam dinding +2% harga, papan menu dan keranjang roti +3%, lampu gantung +4%; foto keluarga +5% RotiFood. Harga toko, termasuk skin, dikali `decor.price_mult_by_tier`. |
| 36 | Pencapaian idle | 20 pencapaian: roti terjual 1 / 100 / 10K, total penghasilan 1K / 1M / 1B / 1T, Tier 2–5, rekrut pertama, stasiun Lv 100, resep Lv 100, semua resep dibuka, 100 pesanan RotiFood, 1 jam offline, Waralaba pertama dan ke-10, overflow. Hadiah v3.1 dipakai ulang; pencapaian "punya saldo" v3.1 menjadi "total penghasilan". Boost hadiah ×2 selama 10 menit mengikuti aturan no. 32. |
| 37 | Pemicu onboarding | Diperiksa tiap 0,5 detik-simulasi. Sapaan pembuka berupa popup Pak Lurah, penjualan pertama berupa sorotan KR dan KR/s, sisanya petunjuk di atas bar tab dengan tombol tab (atau chip oven) yang berdenyut. Petunjuk upgrade, rekrut, resep, dan lokasi menutup sendiri setelah dikerjakan. `onb_hire` muncul segera setelah penjualan pertama karena `start_kr` sudah cukup untuk rekrutan pertama. `onb_offline` adalah petunjuk yang muncul bersama Welcome Back pertama. Popup tutorial memakai potret Pak Lurah. |
| 38 | Model tanpa boost | Toko contoh `ACC_IDLE_MODEL_MATCH` menandai semua pencapaian sudah didapat (tanpa hadiah) dan menghentikan boost, karena model offline sengaja tanpa boost (Seksi 9.1). |
| 39 | Pemain biasa untuk pacing (P7) | `SimBot` dengan `manage` (`tests/sim_bot.gd`): pindah lokasi begitu terjangkau, merekrut dan membuka stasiun begitu terjangkau, lalu membeli yang bernilai terbaik (Δ KR/s ÷ biaya) di antara level, membuka resep, dan "mengejar resep" (menaikkan mixer dan oven terbaik ke tier model resep yang lebih untung). Ia menabung untuk lokasi berikutnya bila lokasi itu nilai terbaik dan biayanya ≤ 30 menit penghasilan, dan untuk pembelian terbaik yang ≤ 3 menit lagi. Ia menjual toko (≥ 5 bintang) di Tier 5, atau setelah 20 menit di satu tier bila lokasi berikutnya masih > 30 menit penghasilan (`PacingTracker.franchise_now`). Tidak mengetuk, tidak memakai promosi, dan tanpa kopi harian. `ACC_IDLE_PACING` memakai median seed 101, 202, 303. |
| 40 | Nilai hasil penyetelan P7 | Diubah dari nilai awal GDD (Seksi 8.8, 10.2–10.3, contoh katalog 15.2), karena pendapatan mendatar di setiap putaran (biaya level resep tumbuh 1,12^L, harga hanya linear dan ×2 per milestone), jadi harga lokasi harus mendekati dataran setiap tier (sekitar 6K/s di Tier 2, 11K/s di Tier 3, 17K/s di Tier 4): `location.upgrade_cost` [0, 440K, 5M, 16M, 26M] (awal [0, 5K, 250K, 25M, 5B]); `staff.hire_cost` [4.500, 100K, 2M, 10M] (awal [300, 3K, 60K, 1,5M]); `decor.price_mult_by_tier` [40, 200, 400, 700, 1.000] (awal [1, 20, 400, 8.000, 160.000]; bonus +2% balik modal kira-kira 10 menit); `prestige.stars_divisor_kr` 250K (awal 1M) dan `prestige.income_per_star` 0,07 (awal 0,02), karena putaran pertama ikut terdorong boost pencapaian yang tidak terulang. Terukur (median seed 101/202/303): penjualan pertama 0,4 menit, upgrade pertama 0 menit, asisten pertama 3,8, resep kedua terjangkau 6,3, Tier 2 12,4, Tier 3 33,4, Tier 4 72,0, Tier 5 112,0, Waralaba pertama 112 (17 bintang), putaran ke-2 sampai Tier 5 dalam 45% waktu. |
| 41 | Resep kedua (**diganti no. 83**: variasi di rak) | Dengan rumus Seksi 4.4 dan 8.5, resep pertama yang sudah naik level selalu lebih untung per roti daripada resep baru di Lv 1, sehingga Auto tetap memakainya dan membuka resep kedua tidak pernah bernilai. Target "Resep kedua 5–8 menit" karena itu diukur sebagai saat resep kedua **terjangkau** (petunjuk `onb_recipe` muncul). Membuat tangga resep bermakna butuh perubahan rumus dan menunggu keputusan maintainer (`docs/GDD_COMPLIANCE.md`, keputusan terbuka no. 2). |
| 42 | Reputasi di akhir permainan | Auto memilih laba per roti tertinggi (Seksi 4.2). Di Tier 5 itu bisa resep lambat yang tidak bisa dipasok dapur; KR/s tetap naik tajam, tetapi banyak pembeli kehabisan roti. Dulu reputasi karenanya turun sampai sekitar ★1; sejak rating dihapus (2026-11-01, Seksi 6.6) itu hanya berarti penjualan yang hilang. **Diukur ulang 2026-11-05:** untuk setiap resep yang bisa dibuat, semua petak diisi resep itu lalu toko dijalankan 6–8 jam in-game. Di toko contoh Tier 5 (`ModelSample`, stasiun Lv 90, semua resep Lv 80) dan di dua toko Tier 5 hasil `SimBot` biasa (seed 101 dan 202, menit ke-115), produksi dapur 640–6.500 roti/jam melebihi permintaan sekitar 300/jam untuk setiap resep, tidak ada pembeli yang pulang tanpa roti, dan resep Auto memberi KR/s hidup tertinggi. Toko yang dibatasi permintaan memaksimalkan KR/s dengan laba per roti tertinggi, jadi aturan Auto tidak diubah. |
| 43 | Melihat rak kosong | Pembeli yang mendapati semua rak kosong saat masuk (`checking_shelf`) berjalan ke tempat berdiri di depan atau samping rak terdekat, dengan aturan sel pengunjung lihat-lihat (v3.1 §20.12), bukan ke titik browsing. Dengan begitu beberapa pembeli bisa melihat bersamaan tanpa saling menunggu, dan titik browsing tetap bebas untuk pembeli yang membeli. Sel yang dituju pembeli lain tidak dipilih; tempat pengunjung lihat-lihat diabaikan karena merekalah yang minggir, jadi mereka tetap kosmetik. Ia menghadap rak dan menoleh ke sana kemari seperti pengunjung lihat-lihat. Bila tidak ada tempat di dekat rak mana pun, ia langsung pulang. Selama itu ia tetap memegang slot antreannya dan kesabarannya tidak berkurang. Setelah `customers.empty_shelf_look_seconds` ia memilih roti terhadap stok terbaru; bila masih kosong ia pulang dan dihitung `total_customers_left_no_purchase`. Ia hanya melihat sekali. Pembeli yang sudah di rak lalu kehabisan (direbut pembeli lain) tetap pulang langsung. Pemilik dan koki tidak memesan titik browsing, jadi pembeli yang sedang melihat tidak menghalangi pengisian rak. Tatapan ikut tersimpan dan berlanjut sama setelah load. |
| 44 | Kedatangan setelah rating dihapus | Pemain biasa dulu mencapai ★5 dalam sekitar 10 menit, jadi kedatangannya ×1,6 hampir sepanjang permainan. Tanpa pengali itu bot macet di Tier 3 dan menjual toko di menit ke-60 dengan 9 bintang. `location.base_arrivals_per_hour` karena itu menjadi [23, 51, 67, 86, 112]: Tier 2–5 = nilai awal × 1,6; Tier 1 turun dari 24 ke 23, karena dengan 24 Tier 2 tercapai di 11,97 menit (target 12–18) dan Tier 1 yang lebih sepi juga berarti lebih sedikit pembeli mendapati rak kosong di awal. Tier 1 ≤ 20 jatuh ke "tebing": penghasilan Tier 1 tidak lagi menutup harga Tier 2 dalam 30 menit, sehingga bot tidak menabung dan Tier 2 baru tercapai di menit 27–30. Terukur (median seed 101/202/303, `ACC_IDLE_PACING`): penjualan pertama 0,4 menit, upgrade pertama 0, asisten pertama 4,1, resep kedua terjangkau 6,5, Tier 2 12,5, Tier 3 33,5, Tier 4 72,1, Tier 5 112,6, Waralaba pertama 113 (17 bintang), putaran ke-2 sampai Tier 5 dalam 47% waktu. |
| 45 | Pendapatan awal 1 KR/s | Toko baru dulu menghasilkan 15,47 KR/s. Semua nilai KR katalog dibagi 15,47 (keputusan maintainer 2026-11-02, Seksi 7.1, 19 no. 14): harga jual resep dan harga bahan dibulatkan ke sen, biaya batch dihitung ulang dari harga bahan (laba per roti setiap resep bergeser < 0,13%, jadi urutan Auto tetap); `start_kr` 65; `station.*.cost_base` 1,94 / 2,59 / 3,23 / 3,88 (mixer, oven, rak, meja kasir); `station.open_cost` 9,70 / 12,93 / 12,93; `staff.hire_cost` [291, 6.460, 129K, 646K]; `staff.level_cost_base` 6,46; `location.upgrade_cost` [0, 28,4K, 323K, 1,03M, 1,68M]; `decor.price_mult_by_tier` [2,59, 12,9, 25,9, 45,2, 64,6]; `prestige.stars_divisor_kr` 16,2K; `perk_head_start` 323; `global_upgrades.cost_base` 129 / 323 / 32,32 / 64,64 / 129. Biaya level resep dan buka resep mengikuti harga dasar, jadi ikut terskala. Ambang pencapaian "Earn 1K / 1M / 1B / 1T KR" sengaja tidak diubah supaya namanya tetap benar; boost ×2 dari "1M" kini datang lebih lambat saat penghasilan sudah besar, sehingga Tier 4–5 sedikit lebih cepat. Terukur (median seed 101/202/303, `ACC_IDLE_PACING`): asisten pertama 4,1 menit, resep kedua terjangkau 6,5, Tier 2 12,5, Tier 3 34,1, Tier 4 63,8, Tier 5 105,7, Waralaba pertama 106, putaran ke-2 sampai Tier 5 dalam 54% waktu. |
| 46 | Panduan ketuk | `TutorialGuide` adalah lapisan sistem (overlay) yang **tidak memblokir**: tidak mem-pause toko dan ketukan dunia tetap hidup. Prompt `hint` yang punya sasaran (`chip_<iid>`, `tab_<id>`, `station_<iid>`) tampil sebagai panduan; prompt `hint` tanpa sasaran (`onb_offline`) tetap petunjuk di atas bar tab. Lapisan redupnya `CoachMarks` (empat bidang redup di sekeliling lubang); kilau kedip di atas tombol memakai ritme dan puncak kedip model dunia (`WorldView.blink_alpha`) × 0,75 supaya tulisan tombol tetap terbaca, dan diam dengan Reduced Motion. Untuk stasiun dunia, modelnya sendiri yang berkedip (`WorldView.highlight`) tanpa kilau datar, dan lembar yang menutupi dunia ditutup. Sasaran dicari ulang tiap frame: tombol di lembar atau kartu yang terbuka (Hire Kitchen Assistant lebih dulu, Unlock pertama yang terjangkau, Move, Sell & Franchise, ×1) bila ada dan aktif, selain itu tab atau chip-nya; tombol di daftar bergulir digulir ke dalam pandangan dan lubangnya dipotong tepi daftar. Panduan bersembunyi selama lapisan sistem lain di atasnya (konfirmasi, menu Pause, Welcome Back) atau modal pemblokir di bawahnya (scrim modal itu menelan ketukan, dan toko sedang di-pause). Not now dan Back menutup prompt seperti Got it. Stasiun tip Semangat dipilih dari state simulasi: oven yang sedang memanggang, mixer yang sedang mengaduk, atau oven pertama. Tip itu menutup sendiri begitu pemain mengetuk stasiun (fokus pemilik aktif), dan tip Waralaba begitu waralaba tidak lagi tersedia, termasuk langsung saat menjual toko (`TutorialManager.on_event`), sebelum cabang baru tampil. Cincin `TutorialPulse` dihapus. |
| 47 | Pemolesan UI flat | Semua tetap `StyleBoxFlat` polos tanpa bayangan, bibir, kilap, gradasi, atau garis tepi huruf (v3.1 §130.6). **Lembar** (`UISheet`): latar `Palette.SHEET` (#F7ECD7) dengan setiap baris sebagai kartu `Palette.CARD` (#FFFCF6) bersudut 18 px (`UISheet.card`/`row`, `ProceduralUIFactory.card_box`); judul bagian berhuruf kapital kecil berjarak, karamel (`section_label`, teks aslinya tidak diubah); kepala lembar berisi lencana madu dengan ikon tab (`sheet_icon()`), judul rata kiri, dan tombol tutup bundar krem pekat. Statistik dikelompokkan dalam satu kartu bergaris pemisah tipis. **Tombol**: jenis baru `soft` (madu muda tanpa garis tepi, ×10 dan Max yang terjangkau) dan `plain` (krem pekat tanpa garis tepi, tutup/kembali/detail). Tombol nonaktif semua jenis berwarna satu krem `Palette.DISABLED_FACE` tanpa garis tepi dengan teks `DISABLED_INK` (kontras ±3,4:1), jadi yang terjangkau selalu berwarna dan yang belum selalu krem; ghost tetap transparan bergaris pudar. Baris Upgrades menaruh kenaikan KR/s sebagai pil hijau di baris tombol beli. **HUD**: KR dan "+{rate}/s" (hijau) dalam satu pil krem; jam di atas pil krem tipis; boost di pil mentega/lavender; pause bundar krem tanpa garis tepi; tab bar tanpa garis tepi per tab, dan tab yang lembarnya terbuka bermuka madu dengan ikon dan teks krem (v3.1 §130.6 "tab aktif selalu terlihat", diperbarui lewat `ModalHost.stack_changed`); titik hijau bercincin krem. **Popup**: Pause setinggi isinya; Pak Lurah bicara lewat balon krem berekor (`speech_bubble`) di popup tutorial dan Welcome Back; hadiah Welcome Back di pil mentega; kartu profil di atas popup `SHEET`. **Kartu upgrade** bermuka `CARD` dengan garis tipis krem. **Decoration Mode**: petunjuk/status pindah ke baris kedua bilah atas selebar bilah, dan keterangan arsiran mendapat barisnya sendiri di atas tab, supaya ketiga tab muat di 720 px pada skala teks 150%. **Ikon**: api berujung dua dengan nyala dalam madu (tidak lagi terbaca sebagai tetesan), dan ikon baru `whisk` (pengocok di mangkuk) untuk mixer. `tools/ui_resolution_sweep.tscn` kini juga memotret kartu upgrade dan Decoration Mode, dan `--full` menyimpan potret ukuran penuh. Tes: `ACC_130_UI_POLISH`. |
| 48 | Gambar UI 2D | Semua `_draw()` bidang warna polos (v3.1 §130.6); detail berupa bidang warna kedua, tanpa garis tepi, bayangan, atau gradasi. **Pak Lurah** (`LurahPortrait`): avatar bundar mint dengan badan dipotong lingkarannya; peci beludru hitam dengan bidang atas lebih terang, cambang dan kumis tebal beruban, alis tebal, mata berbinar, pipi merona, senyum terbuka berlidah; baju safari krem (warna sama dengan model 3D-nya, `CharacterFactory.spec_for_lurah`) berkerah lancip, kaos dalam putih, bilah kancing, dua saku bertutup, pena, dan lencana emas; tanpa tangan (maintainer 2026-11-03 meminta tangan yang melambai dihapus). Ukurannya dari sisi terpendek kotaknya, jadi sama rapinya di popup (104–110 px) dan cutscene (220 px). **Kartu profil save** (`ShopFrontArt`, menggantikan ikon toko 48 px): etalase toko roti 96 px di ubin langit — papan nama dengan roti, kanopi bergaris berenda, jendela berisi tiga roti di rak, pintu kayu berjendela bulat, dan pot tanaman. Warna kanopi, dinding, dan papan mengikuti tier lokasi save (madu, stroberi, matcha, biru, marun), tier 4 berhias segitiga kuningan dan tier 5 kubah berbintang; profil kosong siluet krem dengan lencana "+" madu; save klasik atau rusak memakai toko tier 1 yang pudar. **Potret chibi** (`ChibiPortrait`, New Game dan polaroid staf): mata beriris cokelat dengan dua titik cahaya, bulu mata untuk gaya rambut lembut (sama dengan `CharacterFactory.LASH_STYLES`), alis, hidung, senyum terbuka, telinga berbidang dalam, kilau rambut, kerah, lengan baju, saku celemek berhias roti kecil, topi koki bergumpal dengan lipatan, bandana bertotol, dan kilau kecil di latar. Potret New Game (`NewGameScreen.portrait_visual`) sama dengan model pemiliknya (`spec_for_player`) dan duduk di latar pastel masing-masing (mint untuk pria, merah muda untuk wanita). Sapaan Welcome Back di balon tidak lagi diawali "Pak Lurah:". QA: `tools/ui_art_lineup.tscn` (`-- --zoom=2` untuk detail). Tes: `ACC_130_UI_ART`. |
| 49 | Nama dan merek Crumbtown | Judul di game dan logo: **Crumbtown: Idle Bakery Tycoon** (`game_title`). `ProceduralUIFactory.logo_lockup` memotong judul di titik dua: "Crumbtown" huruf tebal, "IDLE BAKERY TYCOON" di pita madu, dan remah-remah roti kecil di sekitar roti yang bergoyang (`CrumbScatter`). Nama aplikasi Android dan ikon peluncur "Crumbtown", package `com.crumbtown.idlebakery` (belum pernah dirilis, jadi aman diganti), hasil ekspor `crumbtown-debug.apk` / `crumbtown.aab`. `application/config/name` memakai judul lengkap (judul jendela dan tab browser); data pengguna desktop memakai folder khusus `Crumbtown` (`config/custom_user_dir_name`), karena Godot mengubah titik dua di nama folder menjadi tanda hubung. Save Web tetap (IndexedDB tidak bergantung pada nama). Nama toko bawaan pemain "Crumbtown Bakery". Ikon (`tools/generate_icon.gd`) mendapat remah roti di kiri dan kanan bawah. Mata uang **Koin Roti**, Pak Lurah, RotiFood, dan latar Indonesia tetap sebagai ciri khas. Nama berkas GDD, nama repositori, dan URL GitHub Pages belum diganti. Tes: `ACC_IDLE_BRANDING`. |
| 50 | Pacing dengan craving dan misi (2026-11-03) | Craving pertama (harga terbesar dari ×2 dirinya atau ×1,25 roti terbaik) membuat roti tawar ber-craving ×2 hampir setiap hari, sehingga T4 tercapai di menit ~51 dan T5 ~75. Aturan disederhanakan menjadi ×`craving.best_mult` (1,2) roti terbaik. `SimBot` kini mengklaim tujuan yang selesai dan membuka resep craving yang terkunci bila biayanya paling banyak `craving_unlock_minutes` (3) menit penghasilan (dengan 8 menit, biaya buka resep tiap hari memperlambat T4 ke menit 84–94). Tujuan yang terbit sejak menit pertama membuat resep kedua terjangkau di menit 4,8, jadi tujuan mulai hari 2 (`goals.first_day`). Setelah perbaikan model offline (Seksi 21.1: Auto tanpa craving) bot tidak lagi mengira tokonya mandek dan maju lebih cepat, jadi `location.upgrade_cost` menjadi [0, 32,5K, 345K, 1,1M, 1,8M] (sebelumnya [0, 28,4K, 323K, 1,03M, 1,68M]). Kurvanya curam karena bot hanya menabung untuk lokasi yang biayanya paling banyak 30 menit penghasilan: T4 960K memberi Tier 4 di menit ~55, 1,2M di menit ~89; T5 1,9M membuat dua dari tiga seed menjual toko di Tier 4 (aturan "mandek 20 menit") dan 1,68M memberi Tier 5 di menit 96. Median tiga seed (`idle_probe --minutes=220 --manage --franchise=5`, seed 101/202/303): asisten pertama 4,1, resep kedua terjangkau 6,5, Tier 2 13,3, Tier 3 32,9, Tier 4 73,0, Tier 5 108,1, Waralaba 109 menit (18 bintang), putaran 2 ke Tier 5 dalam 40% waktu putaran 1. `ACC_IDLE_PACING` kini menyalakan craving. |
| 51 | Bar kesabaran dihapus (2026-11-04) | Permintaan maintainer: bar di atas kepala pembeli yang mengantre tidak relevan di game idle. `ActorView.PatienceBar`, bar driver RotiFood, dan pengaturan `patience_bar_large` dihapus; kesabaran pembeli kemudian dihapus seluruhnya (no. 52), dan bahan shader bar itu tidak lagi dipanaskan `ShaderWarmup`. Tes `ACC_20_NO_PATIENCE_BAR` memastikan tidak ada bar sementara kesabaran tetap berkurang. |
| 52 | Kesabaran pembeli dihapus (2026-11-04) | Permintaan maintainer, sesudah pengukuran (0 dari sekitar 11.000 pembeli kehabisan kesabaran dalam 2 × 120 menit). Pembeli menunggu sampai dilayani; `abandon()` tinggal pengaman pasca-load. `global_queue_patience` diganti `global_fast_checkout`: `UpgradeManager.checkout_seconds()` = waktu meja kasir ÷ (1 + bonus), dipakai transaksi kasir, pengemasan RotiFood, dan model KR/s; driver RotiFood memakai kesabaran dasarnya tanpa pengali. Faster Checkout yang kini berguna membuat Tier 5 tercapai di menit 98,5, jadi biaya Tier 5 naik ke 1,9M: median seed 101/202/303 Tier 2 13,3, Tier 3 31,3, Tier 4 66,2, Tier 5 104,7, Waralaba 105 menit. |
| 53 | Ketajaman grafis (2026-11-05) | Permintaan maintainer: UI tampak buram dan pecah-pecah. Teks sudah tajam karena bingkai dirender sesuai piksel layar; yang bergerigi adalah gambar 2D dari `_draw()` dan tepi 3D. Renderer Compatibility tidak punya MSAA 2D, jadi setiap poligon digambar lewat `ProceduralUIFactory.fill_aa` (isi + garis tepi antialias tipis berwarna sama) dan lingkaran/garis/busur memakai `antialiased`. MSAA 3D kini mengikuti preset kualitas (Low mati, Medium 2x, High 4x; Auto 4x di desktop dan 2x di HP/browser HP), dan jendela desktop menyesuaikan diri ke 90% tinggi layar (9:16), jadi di monitor besar gambarnya dirender lebih tajam (1080 x 1920 di layar 4K). |
| 54 | Layar pembuka yang lebih hidup (2026-11-05) | Permintaan maintainer: splash, Main Menu, pemilih profil, dan New Game terlalu polos, dan roti di logo kurang berbentuk roti. Tetap flat (v3.1 §130.6). **Roti logo** (`LogoBread`): roti tawar berkubah kerak keemasan dengan tiga guratan sayatan di atas badan loyang yang lebih pucat, wajah imut (mata berkilau yang sesekali berkedip, mulut terbuka, pipi merah muda), uap yang mengepul, dan dua kilau madu; dipakai `logo_lockup` (splash, menu, kartu share, trailer) dan layar loading. Ikon `bread` memakai siluet yang sama (badan, kubah, sayatan). **Latar** (`CozyBackdrop`, juga layar loading): tenda toko bergaris merah muda-krem berlengkung di tepi atas, sinar matahari krem yang berputar sangat pelan di belakang logo, ikon samar yang lebih sedikit, dan roti di piring renda (croissant, donat selai, roti kayu manis, roti tawar) di kedua sudut taplak. **Main Menu**: kartu toko berisi profil terakhir (gambar toko sesuai tier, nama, hari, lokasi, saldo) dengan Continue besar, atau sapaan dengan New Game besar bila belum ada save; New Game dan Load Game berdampingan di bawahnya; Settings, Credits, dan Exit (tidak di Web) sebagai tombol bundar berketerangan; nomor versi di bawah. **Splash**: roti logo lebih besar, pil madu "Tap to Start" yang membesar-mengecil pelan (diam bila Reduced Motion); slogan di bawahnya dihapus atas permintaan maintainer 2026-11-06. **Profil**: menu tetap terlihat di balik kaca popup; tiap kartu bernomor dengan warna penanda (madu, matcha, stroberi), satu tombol aksi lebar dan tombol hapus bundar. **New Game**: tiga bulatan langkah, kartu juru roti terpilih bermuka madu muda dengan lencana centang, langkah nama menampilkan toko dengan papan nama yang mengikuti ketikan, dan ringkasan berisi juru roti, toko, dan rincian berikon. `tools/ui_resolution_sweep.tscn -- --menus` memotret semuanya, tanpa dan dengan save. Tes: `ACC_IDLE_MENU_LOOK`. |
| 55 | Settings yang hidup dan getar HP (2026-11-05) | Permintaan maintainer: Settings memuat empat pengaturan yang tidak berpengaruh apa pun. **Dihapus:** Edge scroll (v3.1 §75.3 "if camera uses it": kamera potret tidak digeser dari tepi), Screen Shake (§44.1 "jika ada", §75.4: tidak ada yang mengguncang layar), dan Confirm expensive purchase beserta ambangnya (§75.3: beli ×1/×10/Max adalah inti game idle, dan konfirmasi di setiap beli besar mengganggu); nilai lama di `settings.json` diabaikan saat dimuat. **Vibration** (§75.4) kini bekerja: `Haptics` menggetarkan HP lewat `Input.vibrate_handheld` mengikuti suara umpan balik di `EventBus.sfx` (ketukan Semangat dan roti emas 12 ms, naik level 20 ms, hadiah koin 40 ms, milestone dan pencapaian 45 ms, pindah lokasi 70 ms, Waralaba 80 ms), dengan jeda minimum 90 ms supaya beli Max tidak berdengung. Hanya aplikasi Android dan Chrome Android (`navigator.vibrate`); Safari iPhone tidak punya API getar, jadi pengaturannya hanya tampil di perangkat yang bisa bergetar. Preset Android meminta izin VIBRATE. Tes: `ACC_75_SETTINGS_USED` (juga memeriksa bahwa setiap pengaturan dibaca kode game). |
| 56 | Build Web sebagai PWA (2026-11-05) | Permintaan maintainer. Preset Web mengaktifkan Progressive Web App: "Add to Home Screen" memasang game layar penuh, potret, dengan layar pembuka krem seperti boot splash; service worker menyimpan berkas game di perangkat sehingga kunjungan berikutnya dimuat dari cache dan bisa dibuka tanpa internet. Build single-threaded tidak butuh header cross-origin isolation, jadi opsi itu mati. Ikon PWA dibuat Godot dari `icon.svg` saat ekspor (tidak ada PNG di repositori). Service worker menyajikan versi lama dulu lalu mengunduh yang baru di latar; begitu siap, `GameRoot` memasangnya (halaman dimuat ulang) hanya di layar pembuka atau Main Menu tanpa layar lain di atasnya, tidak pernah di tengah permainan. Tes: `ACC_IDLE_PWA`; `tools/release_validator.tscn` memeriksa presetnya. |
| 57 | Kode save: Export dan Import (2026-11-05) | Permintaan maintainer: save Web hanya ada di penyimpanan browser, jadi hilang bila data situs dihapus dan tidak bisa dipindah ke perangkat lain. Tetap tanpa server (Seksi 1, v3.1 §112). Kode save = `CRUMB1-` + base64 dari JSON save yang dikompres gzip (sekitar 3 KB untuk toko Tier 3); `SaveManager.export_code`/`decode_code`/`import_code`. Kode dibaca dengan aturan yang sama seperti berkas save (migrasi dan validasi skema); spasi dan ganti baris dari aplikasi chat diabaikan. Kode yang salah atau terpotong, save klasik v3.1, dan save dari versi game yang lebih baru ditolak dengan alasannya. **UI** (di Load Game, karena kode milik satu profil): kartu save yang bisa dimainkan punya tombol Export Save (ikon papan klip) yang membuka Save Code: ringkasan toko, potongan kode dan ukurannya, Copy Code, dan di Web juga Download File (`crumbtown-<nama>-day<N>.txt`). Import Save di bawah daftar profil: tempel lewat tombol Paste (di Web membaca `navigator.clipboard`, karena clipboard Godot di Web baru terisi pada tekanan kedua) atau langsung ke kolomnya, atau di Web Open File; kode yang sah menampilkan ringkasan tokonya dan satu tombol per profil. Profil yang berisi minta konfirmasi, dan save lamanya menjadi backup profil itu. Save yang diimpor ditulis dengan id profil tujuan dan menjadi save terbaru (Continue). Daftar profil dan kartu toko Main Menu dibangun ulang sesudah import atau hapus (sebelumnya Continue masih menunjuk profil yang baru dihapus). Tes: `ACC_IDLE_SAVE_CODE`, `ACC_IDLE_SAVE_CODE_UI`; `ACC_IDLE_PORTRAIT_UI` dan `--menus` juga memeriksa kedua popup. |
| 58 | Monetisasi: penyedia per platform (2026-11-05) | Seksi 22. Autoload `Monetization` (layanan tanpa state gameplay) memilih satu `MonetizationProvider`: tanpa monetisasi di desktop dan preset `Web`, `PortalMonetizationProvider` untuk preset `Web CrazyGames`/`Web Poki` (fitur ekspor `crazygames`/`poki`, SDK lewat `html/head_include`, PWA mati), dan `TestMonetizationProvider` di tes dan `tools/ui_resolution_sweep.tscn -- --ads`. Semua JavaScript portal ada di `WebPlatform`. Tombol hadiah hanya lewat `AdButton` (ikon putar + "· Ad", atau hati + "· Free" untuk Supporter) dan hanya tampil bila `Monetization.can_offer`. Selama iklan: `PauseManager` alasan `ad`, `AudioManager.ad_muted`, dan sinyal `gameplay_stop` ke portal. Jatah harian dan hak Supporter di `user://monetization.json`. Workflow GitHub ikut membuat build CrazyGames dan Poki sebagai artifact. Diuji di Edge dengan SDK CrazyGames v3 asli di localhost (`environment` = `local`): `init` siap, iklan berhadiah contoh tayang dan `adFinished` datang sekitar 5 detik kemudian, sinyal loading dan gameplay diterima. Poki belum diuji di browser (perlu Poki Inspector). Android belum punya penyedia (Seksi 22.2). |
| 59 | Tangga cabang (2026-11-05; rumus **diganti no. 89**) | Seksi 23.1. Diukur dengan `tools/idle_probe.tscn -- --runs=12` (seed 101/202/303, bot biasa tanpa iklan dan tanpa offline). (1) `branch_cost_growth` 2 untuk semua biaya sejak cabang 2: hitungan kasar menunjukkan Tier 3 (syarat Waralaba) tak terjangkau sekitar cabang ke-10. (2) 1,5 untuk semua biaya sejak cabang 2: cabang ke-2 butuh 70–97% putaran 1 (target ≤ 70%). (3) 1,5 untuk semua biaya sejak cabang 3: mulus sampai cabang 5, lalu di cabang 6 (×5,06) bot macet di Tier 3 dan menjual toko untuk 2–3 bintang: biaya level yang ikut naik menurunkan batas penghasilan setiap putaran, jadi tangganya bertebing. (4) **Hanya biaya pindah lokasi** ×1,5 sejak cabang 3 (pilihan akhir): cabang 2 selesai dalam 46–54 menit (48% putaran 1), cabang 3–12 dalam 35–72 menit, hampir selalu sampai Tier 5, bintang per cabang naik dari 9 ke 35, dan sekitar 200 bintang tercapai setelah 18–24 jam bermain aktif. Pembanding dengan biaya lokasi saja: ×2 mulus sampai cabang 6, lalu bot macet di Tier 3 setiap cabang mulai cabang 7 (kadang 7–8 jam per cabang); ×2,5 macet mulai cabang 6. |
| 60 | Ambang mastery (2026-11-05) | Seksi 23.3. Dengan bintang pertama di 2.500 roti, resep utama mencapainya di tengah putaran 1 dan median Tier 5 turun ke menit 95,9 (target 100–140). Ambang dinaikkan ke 10K / 50K / 150K / 400K / 1M: bintang pertama kira-kira di akhir putaran 1, dan median kembali ke 104,7. Hanya roti yang terjual selama bermain yang dihitung. |
| 61 | Sorotan tutorial yang lembut (2026-11-05) | Permintaan maintainer: lubang redup di sekitar sasaran tutorial terlalu kotak dan kaku, dan lingkaran ikon kartu tip meninggi mengikuti kartunya. `CoachMarks` kini satu lapisan redup (`CoachMarks.Dim`): lubangnya persegi membulat dengan jari-jari setengah sisi pendeknya (kapsul untuk chip dan tombol, paling besar 32 px), dan gelapnya memudar dari bening ke penuh sepanjang 30 px. Digambar sebagai tiga keliling persegi membulat dengan warna per titik (`RenderingServer.canvas_item_add_triangle_array`), tanpa shader, jadi tidak ada kompilasi shader saat tutorial pertama tampil di browser. Ketukan di dalam lubang tetap diteruskan ke sasarannya (`_has_point`). Cincin madu dan kilau kedip memakai jari-jari yang sama. `ProceduralUIFactory.badge` tidak lagi meregang tinggi di baris yang lebih tinggi darinya, dan tombol Got it kartu tip berada di tengah. `tools/ui_resolution_sweep.tscn -- --tips` memotret kartu tip, sorotan, dan panduan ke tab dan ke stasiun. |
| 62 | Teks lebih besar (2026-11-05) | Permintaan maintainer: huruf terlalu kecil dan agak sulit dibaca, di semua layar termasuk Main Menu. Pilihan Text Size di Settings tetap 100% / 125% / 150%, tetapi ukurannya kini ×1,25 / ×1,375 / ×1,5 ukuran dasar (`SettingsManager.TEXT_BASE` 1,25, `TEXT_MAX` 1,5; mula-mula 1,15, lalu maintainer meminta sedikit lebih besar lagi). Ukuran terbesar tidak berubah, jadi setiap layar yang sudah lolos matriks Seksi 12.0.7 di 150% tetap muat (`ACC_IDLE_PORTRAIT_UI` kini memeriksa ×1,25, ×1,375, dan ×1,5). Ukuran Theme bersama (teks tanpa ukuran sendiri, tooltip) dan teks melayang "+KR" ikut naik. Lebar teks toast dinaikkan ke 590 px supaya toast satu baris yang biasa tidak terbungkus. Kartu Share dan trailer tetap memakai ukuran desainnya sendiri (×1,0). |
| 63 | Kolom KR dan boost sejajar (2026-11-06) | Permintaan maintainer: pil KR dan pil boost di bawahnya berbeda lebar. Kolom kiri atas kini selebar isinya yang paling lebar, dan pil KR serta setiap pil boost mengisi lebar itu (isi pil boost di tengah). Setiap boost di barisnya sendiri (kopi/pencapaian, promosi, Golden hour, Rush hour), karena dua pil berdampingan membuat kolom, dan pil KR, lebih lebar sampai menabrak jam di tengah. Slogan di bawah "Tap to Start" dihapus atas permintaan yang sama. |
| 64 | Celetukan staf sambil bekerja (2026-11-06) | Permintaan maintainer: di game idle staf hampir selalu bekerja, jadi celetukan yang hanya muncul saat menganggur (v3.1 §31.8) jarang terlihat. Mengganti dua aturan v3.1 §31.8: staf kini berceletuk sekali tiap `staff_line_every_seconds` (60 detik nyata) **sibuk atau tidak**, tanpa syarat diam 6 detik (`staff_line_first_seconds` dihapus dari `balance.json`), dan gelembung yang sudah tampil tetap sampai `thought_show_seconds` habis walau staf mendadak sibuk, ikut berjalan di atas kepalanya. Selagi sibuk, tiga kalimat yang hanya cocok saat menganggur dilewati (`DataRegistry.STAFF_LINES_IDLE_ONLY`: "Next customer, please! ...Anyone?", "Stretch... and smile!", dan kalimat khas Dimas "...Oh, nobody's here."). Aturan lain §31.8 tetap: geseran 7 detik antar-staf, kalimat pertama menghitung hari kerja, giliran tanpa berulang, Decoration Mode menyembunyikannya. Tes: `ACC_31_STAFF_LINES`. |
| 65 | Kemajuan tutorial langsung tersimpan (2026-11-06) | Laporan maintainer: tutorial yang sudah diselesaikan atau dilewati muncul lagi setelah game ditutup lalu Continue. Penyebabnya, menutup tip, Skip, dan tip yang baru terpicu hanya mengubah state di memori; save berikutnya baru terjadi pada autosave 30 detik, saat fokus hilang, atau saat jendela ditutup dengan tombol tutup. Game yang dihentikan sebelum itu (tombol Stop editor, proses dimatikan, tab browser yang ditutup sebelum sinkron) menyimpan tutorial sebagai belum selesai. Kini `TutorialManager` meminta save kritis setiap kali state tutorial berubah (`show_step`, `dismiss`, `skip`), dan tip yang menunggu giliran (`queue`) ikut tersimpan supaya tidak hilang. Tes: `ACC_IDLE_TUTORIAL_SAVED` (gagal tanpa perbaikan ini). |
| 66 | Sampel cadangan di ujung setiap bunyi (2026-11-06) | Ditemukan saat build Android pertama diuji di emulator (Android 14, x86_64): game selalu crash beberapa detik setelah masuk toko, dengan SIGSEGV (SEGV_ACCERR, alamat tepat di awal halaman memori) di thread AudioTrack milik `libgodot_android.so`. Bisect di emulator menunjuk ke loop ambience yang mulai berputar. Interpolasi mixer Godot membaca beberapa sampel melewati `loop_end`/ujung data; di desktop dan Web bacaan itu jatuh ke memori yang masih sah, di Android buffer besar berakhir tepat sebelum halaman pelindung. Kini `AudioGenerator._to_stream` dan `MusicBuild` menambah `AudioGenerator.TAIL_PAD` (16) sampel setelah ujung setiap stream: salinan sampel awal untuk loop (sambungan tetap mulus), keheningan untuk bunyi sekali-putar; `loop_end` tetap di ujung asli, jadi yang terdengar tidak berubah. Setelah perbaikan game berjalan di emulator tanpa crash. Tes: `ACC_33_AUDIO_TAIL_PAD`. |
| 67 | Pemeriksaan memori jangka panjang (2026-11-06) | Laporan maintainer: di HP (Poco X6, Android 16, APK debug arm64) game membeku lalu tertutup setelah beberapa lama; dicurigai memory leak. Alat baru `tools/memory_probe.tscn` menjalankan `game_root.tscn` seperti pemain dan mencetak memori statis, jumlah objek, resource, node, node yatim, memori video, dan ukuran cache statis setiap beberapa detik (`--scale` mempercepat waktu, `--manage` membeli upgrade seperti SimBot, `--ui` membuka dan menutup 13 layar utama bergantian). Hasil di desktop: 20 menit ×8 dengan toko tumbuh dari Tier 1 ke Tier 4, memori statis 135 → 155 MB dan hanya naik saat pindah ke lokasi yang lebih besar (datar di dalam satu tier), memori video tetap sekitar 70 MB; 10 menit dengan 1.002 kali buka-tutup layar, memori statis 150 → 145 MB dan node yatim tetap 132. Di emulator Android (`adb shell dumpsys meminfo`): build x86_64 22 menit bermain, native heap naik selama pemanasan lalu hanya sekitar 0,25 MB per menit; build arm64 yang sama dengan di HP (lewat penerjemah ARM) 22 menit sambil mengetuk semua tab dan membeli upgrade, native heap berkisar 241–262 MB tanpa tren naik. Tidak ada crash atau ANR, termasuk saat aplikasi ke latar belakang dan layar dimatikan lalu dinyalakan. Kesimpulan: tidak ditemukan kebocoran memori; penyebab di HP belum diketahui dan perlu catatan crash dari HP itu (`adb shell dumpsys dropbox --print data_app_native_crash`, `data_app_anr`, `data_app_crash`). |
| 68 | Satu save, tanpa Main Menu (2026-11-06) | Seksi 19 no. 21. **Alur:** Tap to Start (`GameRoot.begin`) memuat save tunggal `SaveManager.SAVE_ID` (`profile_1`), atau, tanpa save yang bisa dimainkan, membuka `NewGameScreen` di atas latar layar pembuka: pilih juru roti (hanya Next), lalu nama toko (Back dan Start). Popup itu tanpa tombol tutup; Back di langkah pertama menawarkan keluar dari game (kecuali Web). Langkah ringkasan dihapus. **Save lama tiga profil:** sebelum memuat, toko yang terakhir dimainkan menjadi save tunggal (`adopt_latest_save`); toko lama di `profile_1` bertukar tempat dengannya, jadi tidak ada toko yang terhapus, dan save yang tidak bisa dimainkan di sana pindah ke slot kosong. Dua slot lain tidak pernah ditampilkan lagi. Save tycoon v3.1 dianggap belum ada save; toko baru memindahkannya ke slot kosong dulu (`make_room_for_new_game`). **Yang dulu di Main Menu:** Settings dan Credits di menu Pause; Exit menjadi Quit Game di Pause (simpan lalu tutup; tidak ada di Web); Export Save (menyimpan dulu, supaya kodenya memuat keadaan saat ini), Import Save (menggantikan toko yang sedang dimainkan setelah konfirmasi, toko lama menjadi backup save), dan Reset Game di Settings > Gameplay. **Reset Game:** konfirmasi destruktif, toko tidak disimpan lagi, semua slot save dihapus, lalu popup toko baru seperti install baru; pengaturan dan jatah iklan per perangkat tetap. **Save tidak terbaca** (main dan backup): popup galat di atas latar layar pembuka dengan Try Again dan Start a New Bakery (konfirmasi), tanpa tombol tutup. Pembaruan PWA hanya dipasang di layar pembuka. Tes: `ACC_IDLE_SINGLE_SAVE_START`, `ACC_IDLE_SINGLE_SAVE_ADOPT`, `ACC_IDLE_RESET_GAME`, `ACC_IDLE_SAVE_UNREADABLE`, `ACC_IDLE_SAVE_CODE_UI`, `TEST_UI_NEW_GAME_FLOW`. |
| 69 | Ketuk perabot membuka kartu upgrade (2026-11-08; **diganti no. 77**: kartu kembali hanya dari chip level) | Permintaan maintainer: upgrade mixer, oven, dan perabot lain juga bisa dibuka dengan mengetuk perabotnya, tidak hanya lewat chip level di atasnya. Ketukan pada mixer, oven, atau rak (`LevelChips.STATION_CATEGORIES`) tetap memberi fokus pemilik dan Semangat (Seksi 5.1-5.2), lalu membuka kartu upgrade stasiun itu (`LevelChips.open_card_for_equipment`); ketukan pada meja kasir jalur mana pun membuka kartu Meja Kasir yang melayang di atas meja yang diketuk (param `lane`). Ketukan pada pembeli yang mengantre tidak membuka kartu. Kartu yang sudah terbuka untuk perabot yang sama dibiarkan, jadi ketukan Semangat beruntun tidak membangunnya ulang dan tidak membunyikan suara buka lagi; perabot lain menggantinya. Perabot tanpa level (kulkas, Meja Tunggu) tidak membuka kartu. Ketukan di lantai kosong menutup kartu. Selama lembar bawah lain terbuka (Upgrades, Menu, Staff, dan seterusnya), ketukan perabot hanya memberi Semangat dan tidak menutup lembar itu (`ModalHost.has_sheet`). Panduan `onb_first_upgrade` tetap menunjuk chip level. Tes: `ACC_IDLE_TAP_OPENS_CARD`. |
| 70 | Cutscene truk pindahan (2026-11-08) | Permintaan maintainer: upgrade toko diberi animasi: pemilik dan staf memindahkan perabot ke truk, naik, truk berjalan, berhenti di depan toko baru, Pak Lurah memberi selamat, lalu game dimulai lagi. **Alur:** konfirmasi Move di lembar Shop memanggil `GameRoot.start_move`, yang membuka `MovingCutscene` (modal pemblokir `keep_open`: toko di-pause, HUD disembunyikan, input dunia mati). Adegannya dimainkan `MovingDay` di dunia 3D yang sama: truk bak kayu (`TrafficFactory.moving_truck`, kabin terbuka berjendela tanpa kaca supaya sopir terlihat, satu material MATTE) datang dan parkir di tepi jalan depan toko; pemilik dan semua staf (boneka ActorView dari salinan model aktornya, `ActorView.puppet_model`, tidak didaftarkan ke simulasi) berjalan ke tiap perabot lewat rute grid, mengangkatnya ke atas kepala (`ProceduralAnimationSystem.set_overhead_pose`, salinan prototipe yang sudah dipanggang, sampai 4 terlihat per tumpukan), keluar lewat jalur pembeli, dan menaruhnya di bak; perabot lantai atas dibawa turun lewat pintu tangga. Truk punya **sopir sendiri** (permintaan maintainer 2026-11-08: truk berjalan tanpa sopir terlihat aneh): boneka pembeli bertopi pet dan berkemeja biru di kursi kanan dengan tangan di setir, sejak truk datang sampai pergi, dan melambai saat truk berhenti. Staf naik ke bak, pemilik naik lewat pintu penumpang (sisi trotoar) ke kursi kiri, klakson `truck_horn`, truk berangkat. Di balik layar krem ("On the road to ...") lokasi pindah **tepat sekali** (`SimulationRoot.upgrade_location`, v3.1 §45.2), dunia dibangun ulang, lalu truk tiba di toko baru: kru turun, perabot dari bak melompat masuk lewat pintu dan muncul di tempatnya dengan pop kecil, kru berbaris di depan toko bersama Pak Lurah 3D (`CharacterFactory.spec_for_lurah`) yang melambai, dan kartu Pak Lurah tampil (`ui_moving_lurah`, tombol Let's bake!). Tombolnya membuat kru masuk toko; cutscene ditutup, kamera kembali pelan, truk dan Pak Lurah pergi sendiri. **Skip** (dan Back) melompat ke kartu Pak Lurah di toko baru (pindah lokasi tetap sekali); saat kartu tampil, Back = tombol kartu. Ditutup sebelum truk pergi (mis. sesi berakhir): tidak ada yang pindah atau terbayar, perabot, HUD, dan kamera kembali. Tanpa dunia atau saat `playing` false (tes simulasi) Move langsung pindah seperti dulu. **Lalu lintas** (permintaan maintainer 2026-11-08: tidak ada kendaraan yang menabrak atau ditabrak truk): kendaraan StreetLife tetap melaju selama cutscene (pejalan kaki tidak muncul), dan truk menjadi kendaraan tamu (`StreetLife.set_guest`, diperbarui tiap frame): lajur yang badan kendaraannya bisa bersinggungan dengan truk (lebar kendaraan terlebar lajur itu) tidak memunculkan kendaraan baru, kendaraan di lajur itu yang ada di belakang truk mengerem dan mengantre di belakangnya (memilih yang jarak bempernya terdekat, truk atau kendaraan di depan), roda dua tidak menyalip ke arahnya dan yang sedang menyalip baru kembali ke lajur setelah melewatinya, kendaraan yang menimpa tempat truk muncul dihapus (di luar layar), dan truk sendiri menjaga jarak dengan kendaraan di depannya (`StreetLife.gap_ahead`, aturan pengereman yang sama), termasuk mengikuti gerobak lambat. Truk melaju dan berhenti di satu garis z tanpa pindah lajur. Setelah cutscene truk langsung pergi bersama sopirnya; begitu ia di luar layar lajurnya dibuka lagi. **Tempat parkir** per tier (`MovingDay.PARKING`, disetel terhadap NeighborhoodFactory seperti StreetPaths): truk di tepi jalan sisi toko, ujung belakangnya dekat pintu (T4 berhenti di lajur dekat, karena jalur parkirnya berisi mobil parkir yang akan dilindas bila truk melaju di sana; T3: pemilik berjalan ke pintu penumpang di belakang deret tiang lampu), titik jalan kru menghindari lampu, pohon, dan bangku, dan barisan sambutan bebas dari pot dan tiang tali (T4: kanopi tabebuya menutupi plaza dari sudut kamera, jadi Pak Lurah menyambut di karpet merah). Kru berjalan 3 m/s nyata, lebih cepat di toko yang lebih luas (sampai 1,5x), dengan batas fase angkut 16 detik. Lama sekitar 14–20 detik nyata ditambah kartu. Membangun cutscene sekitar 18 ms di desktop (truk 7 ms; rute dalam toko dihitung saat langkahnya mulai, jadi tersebar antar-frame; log `moving day:` di kategori WORLD). Murni kosmetik: tanpa RNG dan tanpa save; tidak ada material baru. Tes: `ACC_IDLE_MOVE_CUTSCENE`, `ACC_IDLE_MOVE_SKIP`, `ACC_IDLE_MOVE_TRAFFIC` (gerobak lambat di depan truk, mobil dan motor menyusul dari belakang: nol tumpang-tindih badan, antrean, sopir dan kursi penumpang), `ACC_IDLE_MOVE_CLOSED_EARLY`; `tools/move_cutscene_probe.tscn` memotret adegannya per tier, dan `--busy` memadatkan lalu lintas sambil memeriksa tumpang-tindih badan truk tiap frame (T1-T4: nol). |
| 71 | Animasi staf baru dan stasiun baru (2026-11-08) | Permintaan maintainer. Keduanya momen singkat di dunia (`WorldMoments`, anak WorldView) yang tidak mem-pause toko dan tidak mengubah simulasi: staf dan stasiunnya bekerja sejak dibeli, hanya tampilannya yang sebentar digantikan. **Staf baru** (`EventBus.staff_hired`): aktor aslinya disembunyikan (`WorldView.hidden_actors`) dan boneka salinan modelnya berjalan di garis trotoar ke pintu (jalur pembeli), masuk, menghadap kamera, melompat dan melambai dengan kilau, bunyi `door_bell_enter` dan `customer_happy`, serta gelembung sapaan (`ui_staff_welcome_baker`/`ui_staff_welcome_cashier`, menyebut namanya); lalu boneka menyusul aktor asli lewat rute grid (dihitung ulang tiap 0,35 s) dan bertukar tempat dengannya (atau naik lewat pintu tangga bila ia bekerja di dapur atas; paling lama 8 s). Kamera menyorot pintu sebentar (`soft_focus`). **Stasiun baru** (`EventBus.station_opened`): stasiunnya disembunyikan (`WorldView.hidden_furniture`, bertahan walau perabot dibangun ulang), kardus selebar telapaknya jatuh dari 3,2 m, mendarat dengan squash, kepulan debu, dan bunyi `storage_close`, keempat tutupnya terbuka, lalu kardus mengecil dan stasiun melompat keluar (pop seperti evolusi model) dengan kilau dan bunyi `tap_boost_pop`; sekitar 1,5 s. Stasiun di lantai lain (mixer dan oven di dapur atas Tier 2-3) diperlihatkan: kamera pindah ke lantai itu selama kirimannya, lalu kembali bila pemain tidak memilih lantai lain. Lembar Staff dan Shop **ditutup** setelah rekrut atau buka stasiun berhasil, supaya animasinya terlihat (dulu lembar tetap terbuka). Reduced Motion: hanya kilau (dan gelembung sapaan), tanpa boneka dan tanpa kardus. Kardus dan debu memakai material MATTE bersama; tidak ada kombinasi shader baru. Tes: `ACC_IDLE_HIRE_WELCOME`, `ACC_IDLE_STATION_DELIVERY`; `tools/moments_probe.tscn` memotret keduanya per tier. |
| 72 | Katalog Decoration Mode seperti lembar Staff (2026-11-08) | Permintaan maintainer: baki kartu teks mendatar (Equipment / Your Decorations / Decor Shop) diganti katalog berbentuk lembar bawah seperti Staff, dengan tab per jenis barang: **Equipment · Wall · Counter · Floor (dekorasi lantai dan karpet) · Style (skin dan pakaian)**. Setiap baris `UISheet.row`: lencana ikon bulat (`DecorIcons`: ikon per dekorasi, cadangan `badge_icon` lalu ikon jenisnya; perabot memakai ikon kategorinya), nama, keterangan (lantai dan level untuk alat; jenis, bonus, dan Placed/Waiting untuk dekorasi), dan satu tombol: Move/Place (angkat barang), Use/Equipped (skin dan pakaian), atau Buy for {harga} berikon koin (Active bila bonusnya sudah menyala, Owned untuk skin yang sudah dimiliki). Tab dekorasi berisi pil sisa slot jenisnya ("Wall 0/4", "Floor 0/3 · Rug 0/1"), bagian "Your Decorations" (atau ajakan membeli bila kosong), lalu "Decor Shop" jenis itu. Dekorasi baru yang dibeli langsung diangkat untuk ditaruh bila jenisnya masih punya slot. Katalog terbuka di tab Equipment saat mode dibuka (terlipat bila mode dibuka sambil memegang perabot), terlipat menjadi deret tab selama barang dipegang dan saat tab aktif diketuk lagi; daftarnya setinggi sepertiga bingkai supaya toko tetap terlihat di atasnya. Ikon baru IconCanvas: plant, lamp, rug, apron, bell, book, calculator. Deret tab turun ke baris kedua pada teks 150% (CozyTabs), tanpa gulir ke samping. Tes: `ACC_IDLE_DECOR_ICONS`, `ACC_IDLE_DECOR_CATALOG`; `tools/ui_resolution_sweep.tscn -- --screens=decoration` memotret setiap tab. |
| 73 | Sorotan resep baru (2026-11-08) | Permintaan maintainer: animasi saat membuka menu baru. Setelah Unlock di lembar Menu berhasil, `RecipeReveal` (lapisan sistem yang tidak memblokir: lembar Menu tetap terbuka, toko tidak di-pause) meredupkan layar, memunculkan sinar flat yang berputar pelan di belakang gambar `BreadArt` resepnya yang melompat masuk (squash), bintang berkelip di sekelilingnya, dan kartu berpita "New on the menu!" (`ui_recipe_new`) dengan nama resep dan harga jualnya, diiringi `milestone_fanfare`. Sesudah 2,4 s, atau ketukan setelah 0,35 s, atau Back, rotinya terbang mengecil ke tombol tab Menu yang lalu memantul (`tap_boost_pop`) dan sisanya memudar. Unlock berikutnya menggantikan sorotan yang masih terbuka. Hanya dari lembar Menu (bukan dari bot, tes simulasi, atau perk resep waralaba). Reduced Motion: tanpa putaran, pantulan, dan terbang; hanya muncul dan memudar. Tes: `ACC_IDLE_RECIPE_REVEAL`; `tools/moments_probe.tscn` juga memotret sorotan ini. |
| 74 | Baris lembar Upgrades seragam (2026-11-08) | Permintaan maintainer: bentuk UI lembar Upgrades, terutama tombolnya, tidak konsisten (tombol "Start · harga" promosi satu baris dengan lebar mengikuti teks dan ikut memanjang bila keterangannya dua baris, sedangkan ×1/×10/Max dua baris berukuran tetap). Kini semua baris (kopi Pak Lurah, promosi, upgrade) memakai kartu yang sama: ikon, judul, dan keterangan di atas; di bawahnya pil di kiri (kenaikan KR/s, atau status promosi "Running · 4:12" / "Ready in 2:30") dan tombol di kanan. Tombol Start promosi adalah tombol dua baris yang sama dengan ×1 (`BuyButtons.make_button`, 104 × 58, aksi di atas dan biaya di bawah, madu; krem pudar bila tidak bisa): selalu tampil di tempat yang sama, pudar selama promosi berjalan atau jeda (pilnya menjelaskan), dan tidak pernah meregang mengikuti tinggi baris. Tombol iklan Skip dan Another cup setinggi tombol beli. Tes: `ACC_IDLE_BOOST_UI` (disesuaikan), `ACC_IDLE_PORTRAIT_UI`. |
| 75 | Perabot yang sedang dipakai boleh dipindah (2026-11-08) | Keputusan maintainer, mengganti aturan `IN_USE` v3.1 §72 dan §81 no. 14 (perabot berisi job atau dipesan aktor tidak bisa diangkat). Di toko idle dapur tidak pernah menganggur, jadi mixer terkunci 64–84% waktu, oven 40–49%, dan rak 10–14% (bot `--manage`, 2 jam), sementara Decoration Mode mem-pause toko sehingga menunggu di dalamnya tidak membantu. Kini setiap perabot terpasang bisa diangkat, digeser, dan diputar kapan saja; syarat lain tetap (tempat sah, tile akses, jalur terlindung). Isinya ikut karena terikat pada iid-nya: adonan di mixer dan loyang di oven tetap di tahap dan progresnya, roti di rak tetap di petaknya (seperti rak berisi roti sebelumnya). Saat Place (`SimulationRoot.on_equipment_moved`): pemilik dan koki yang menuju atau sedang memakai perabot itu berjalan ke tile akses barunya dan menyelesaikan sisa interaksinya di sana (tugas dibatalkan hanya bila tidak ada jalan; barang di tangan tetap dibawa); pembeli yang menuju rak itu atau sedang memilih di sana melepas titik browsing lamanya dan berjalan ke tile barunya lalu memilih lagi; aktor yang berdiri di jejak barunya bergeser ke sel bebas terdekat; setiap aktor yang sedang berjalan mencari jalan baru (v3.1 §17.5). Pesan "In use right now" dihapus. Tes: `ACC_IDLE_MOVE_BUSY` (mengganti `ACC_81_IN_USE`), `ACC_72_STOCKED_SHELF_MOVE`. |
| 76 | Panah sisi depan di Decoration Mode (2026-11-08) | Permintaan maintainer: saat memindah perabot, tunjukkan arah depannya. Selama alat dipegang, panah oranye madu bertepi putih keluar dari tengah sisi interaction face-nya (`GridMath.face_dir`, termasuk sisi pendek oven conveyor) dan berbaring di ubin tempat pemakainya berdiri, di posisi dan putaran calonnya, jadi ikut setiap Rotate dan setiap geseran; ia maju-mundur pelan kecuali Reduced Motion. Hanya alat (mixer, oven, rak, gudang, meja tunggu, kursi staf); dekorasi tidak punya sisi depan. Bentuknya dihitung di lantai lalu diproyeksikan kamera dan digambar di lapisan UI terbawah Decoration Mode (`DecorationScreen.FrontArrow`, `WorldView.hold_front`), bukan sebagai mesh 3D: dengan pitch 35° model setinggi meja menutupi ubin di belakangnya, jadi panah 3D hilang setiap kali alat menghadap menjauhi kamera, dan mesh tanpa uji kedalaman berarti kombinasi shader baru (`ACC_89_FEW_SHADERS`). Tes: `ACC_IDLE_DECOR_FRONT_ARROW`; tampilan: `tools/ui_resolution_sweep.tscn --screens=decoration` (`decoration_hold_r0`–`r3`). |
| 77 | Kartu upgrade hanya dari chip level; chip diperbesar (2026-11-08) | Permintaan maintainer, menggantikan no. 69: mengetuk perabot (mixer, oven, rak, meja kasir) kembali hanya memberi fokus pemilik dan Semangat (Seksi 5.1-5.2), jadi ketukan beruntun untuk mempercepat tidak pernah membuka, mengganti, atau menutup kartu upgrade; kartu dibuka dari chip level saja, dan ketukan di lantai kosong tetap menutupnya. Supaya chip mudah diketuk, pilnya dibesarkan (teks 20 px, panah 22 px, tinggi sekitar 47 px, sebelumnya teks 14 px dan tinggi 32 px) dengan target sentuh 8 px lebih luas di setiap sisi (sekitar 120 × 63 px). Chip sebesar itu bertabrakan di Tier 4-5, tempat stasiun berjajar rapat (chip lama pun sudah menumpuk), jadi `LevelChips` menatanya setiap frame: dari stasiun yang paling depan, pil yang menabrak pil lain atau panel HUD (isi kolom kiri, kanan, dan tengah atas serta bar tab, `HUD.chip_blockers`) didorong ke atas, atau ke bawah bila ke atas ia keluar layar, dengan jarak 6 px, lalu garis tipis menghubungkannya ke puncak stasiunnya. Chip juga digeser masuk ke layar di tepi. Param `lane` kartu Meja Kasir (no. 69) dihapus: kartunya melayang di atas meja jalur A, tempat chipnya. Tes: `ACC_IDLE_CHIP_OPENS_CARD` (mengganti `ACC_IDLE_TAP_OPENS_CARD`), `ACC_IDLE_CHIPS_DECLUTTER`, `ACC_IDLE_LEVEL_CHIPS`; tampilan: `tools/ui_resolution_sweep.tscn --screens=none --tier=5 --equip`. |
| 78 | Setiap cabang bisa dikunjungi dan dimainkan (2026-11-08) | Permintaan maintainer; tiga pilihan dikonfirmasi maintainer: dompet terpisah per cabang, cabang lain menabung seperti offline, cabang yang sudah dijual dibangun ulang. Waralaba tidak lagi menjual toko: cabang lama tetap milik pemain dan berdiri di Peta Crumbtown. **Yang milik satu cabang** adalah semua yang dimulai ulang oleh Waralaba (Seksi 10.5): saldo KR (setiap cabang punya dompet sendiri, jadi cabang baru tetap mulai kecil dan pacing Seksi 1.4/23 tidak berubah), lokasi, stasiun dan levelnya, kasir, resep, staf, upgrade global, rak, produksi, penghasilan cabang (`run_earned_kr`), hari pencapaian tier, serta letak dan bonus dekorasi (koleksi dekorasi, skin, dan pakaian milik seluruh Crumbtown, jadi setiap cabang menata koleksi yang sama dengan caranya sendiri, dan bonus dekorasi berbonus dibeli per cabang seperti sesudah Waralaba). Jam, cuaca, bintang, perk, statistik sepanjang masa, pencapaian, mastery, tutorial, boost aktif, tujuan harian, cap, pelanggan langganan, dan RNG milik seluruh Crumbtown. Penghasilan cabang mana pun menambah `alltime_earned_kr`, jadi semua cabang ikut memberi bintang. **Hanya cabang yang sedang dimainkan yang disimulasikan.** Cabang lain disimpan di save sebagai bagian save miliknya (`franchise.branches[].state`, ledger diringkas ke total dan pesanan RotiFood yang sudah selesai dibuang seperti tengah malam; cabang Tier 5 sekitar 23 KB) beserta jam unix saat ditinggal, KR/s model tanpa boost, batas offline, dan efisiensinya. Selama ditinggal ia menabung seperti penghasilan offline (Seksi 9.2): KR/s saat ditinggal × min(lama ditinggal, batas) × efisiensi, dengan aturan Seksi 9.4: di bawah 1 menit tidak ada, di bawah 5 menit langsung masuk dengan toast, selebihnya menunggu Collect di popup Selamat Datang cabang itu (judul "Back at Branch #n!", Collect ×2 iklan tetap berlaku). Tabungan masuk ke dompet cabang itu; penghasilan offline aplikasi tetap milik cabang yang sedang dimainkan. Batas dan efisiensi dihitung dari upgrade cabang itu saat dikunjungi. **Kunjungan**: Peta Crumbtown menyebut tabungan yang menunggu di kavling setiap cabang lain (pil "+1.2K KR"), dan kartu ceritanya punya tombol "Visit Branch #n". Pindah cabang memakai jalur Waralaba: cabang ini ditinggal (penghasilan yang menunggu Collect masuk dulu, aktor dikosongkan), cabang tujuan dimuat lewat jalur load biasa di simulasi yang sama, lalu dunia dan HUD dibangun ulang di balik layar loading ("Walking across Crumbtown...") dengan toast "Welcome to Branch #n!". **Waralaba berikutnya** boleh dibuka dari cabang mana pun begitu cabang terbaru mencapai lokasi Tier 3 dan ada bintang baru; bintangnya dicatat untuk cabang terbaru, dan upgrade global di atas level 5 dibawa dari cabang tempat Waralaba ditekan. Pengali biaya lokasi Seksi 23.1 mengikuti nomor cabang yang sedang dimainkan. Teks Waralaba tidak lagi menyebut menjual ("Open a New Branch"; Pak Lurah: investor mendanai cabang baru). **Cabang yang dijual sebelum aturan ini** (hanya catatannya) dan tempat kosong dari save sebelum peta dibuka lagi saat pertama dikunjungi sebagai toko awal di tier tertinggi yang pernah dicapainya (perabot awal level 1, saldo awal termasuk perk, perk cabang baru berlaku); KR dan bintang di ceritanya tetap. Save: `franchise.branch_no`, `franchise.run_stars`, dan field baru di `franchise.branches` (skema tetap 1: save lama dimuat dengan cabang yang sedang dimainkan = `run_index`). Tes: `ACC_IDLE_BRANCH_VISIT`, `ACC_IDLE_BRANCH_VISIT_FLOW`. |
| 79 | Balon dialog di atas chip level (2026-11-08) | Permintaan maintainer: balon dialog pemilik, staf, dan pembeli (ThoughtBubble) tergambar di atas chip level. Chip pindah dari lapisan HUD (10) ke lapisan kanvasnya sendiri `HUD.CHIP_LAYER` (3), dan lapisan balon `WorldView.THOUGHT_LAYER` naik dari 3 ke 4. Urutannya dunia 3D, hujan (2), chip (3), balon (4), transisi lantai (5), HUD (10), lembar dan modal (20). Panel HUD tetap di atas chip, jadi aturan tata letak chip no. 77 tidak berubah. Balon tidak menangkap ketukan, jadi chip di bawah balon tetap bisa diketuk. Lapisan chip ikut tersembunyi bersama HUD (potret ShareCard) dan isinya (Decoration Mode, Photo mode). Tes: `ACC_IDLE_BUBBLES_OVER_CHIPS`. |
| 80 | Pembeli tidak lagi bolak-balik antara jalur A dan jalur kasir (2026-11-08; bagian (1) dan (2) **diganti no. 82**: jalur A tanpa pemilik tidak lagi ditahan, antreannya pindah ke kasir yang aktif; bagian (3) tetap) | Laporan bug maintainer: dengan pemilik dan satu kasir, pembeli tampak bingung dan bolak-balik di antara kasir 1 dan 2. Penyebabnya: jalur B penuh membuka jalur A sebagai luapan, penyeimbangan (v3.1 21.3) memindah pembeli dari B ke A, B jadi punya satu ruang sehingga jalur A tutup, pembeli itu dikembalikan ke B, B penuh lagi, dan seterusnya setiap tick; pemilik tidak pernah datang karena setiap kali ia memeriksa, B tampak punya ruang (Seksi 5.1 no. 1). Perbaikan: (1) jalur A yang dibuka karena semua jalur kasir penuh **ditahan** (`QueueLane.held`, `QueueManager.update_hold`) dan tetap terbuka bagi pembeli yang sudah masuk ke sana; (2) selama ditahan dan ada pembeli menunggu, pemilik datang melayani walau jalur kasir sudah mendapat ruang lagi; (3) jalur A yang belum dijaga pemilik tidak menerima pindahan dari penyeimbangan, hanya pembeli baru, jadi pembeli yang sudah antre tidak pindah sebelum pemilik datang. Tahanan dilepas begitu pemilik datang menjaganya atau jalur A kosong, jadi aturan v3.1 21.3 tetap: bila pemilik pergi sebelum melayani, pembeli yang belum dilayani mengalir kembali ke jalur kasir. `held` ikut tersimpan di save jalur (hanya bila benar). Tes: `ACC_21_NO_LANE_PINGPONG` (Tier 1 dengan satu kasir dan Tier 4 dengan dua: sebelumnya satu pembeli berpindah jalur 10 kali, sekarang paling banyak sekali). |
| 81 | Tempat pemilik menunggu (2026-11-09) | Keputusan maintainer, mengganti langkah 4 Seksi 5.1 (dulu pemilik diam di tempat terakhirnya dan baru ke kasir saat ada pembeli menunggu di jalur A tanpa jalur kasir lain yang berruang): saat tidak ada pekerjaan dapur, kemas, atau pembeli yang harus dilayani, (1) **bila ada roti yang sedang dibuat** (batch mana pun yang belum sampai di rak, dibuat pemilik atau koki) pemilik menunggu di dapur, di tile bebas samping tile akses stasiun batch yang paling dulu selesai (mixer saat diaduk, oven saat dipanggang); (2) **bila tidak ada**, ia menjadi kasir di jalur A, jadi jalur A terbuka dan antrean terbagi dengan jalur kasir (v3.1 21.3), dan pembeli dilayani tanpa menunggu pemilik berjalan; (3) **bila jalur A tidak bisa dijaga** (tidak ada jalan ke titik kasirnya), ia menunggu di tile bebas di sebelah meja kasir. "Kasir yang kosong" dibaca sebagai jalur A: jalur lain milik Asisten Kasir (v3.1 21.2), jadi jalur A selalu kosong bagi pemilik dan langkah (3) hanya cadangan. Pemilik yang berjaga tanpa pembeli memeriksa setiap `RETHINK_SECONDS` dan pergi begitu ada roti yang mulai dibuat atau ada pekerjaan; jalan ke tempat menunggu juga berhenti begitu ada pekerjaan. Selama pemilik di kasir tetapi ingin kembali ke dapur, jalur A tidak menerima pembeli baru bila jalur kasir lain masih punya ruang (`QueueManager.accepts_new`), supaya antreannya habis; tanpa kasir, jalur A tetap menerima semua pembeli seperti sebelumnya. Akibatnya bila ada koki, roti hampir selalu sedang dibuat, jadi pemilik lebih sering menunggu di dapur daripada menjaga kasir. Saat berjaga tanpa transaksi pemilik tidak dihitung sibuk, jadi gerakan idle dan tertidur tetap jalan. Tes: `ACC_IDLE_OWNER_WAITS`, `ACC_21_PLAYER_AND_CASHIER`. |
| 82 | Jalur A tanpa pemilik: antrean dan ojol pindah ke kasir yang aktif (2026-11-09) | Permintaan maintainer, sesudah melihat driver RotiFood menunggu di antrean jalur A padahal pemilik tidak ada di sana. Jalur A dihitung dijaga selama pemilik menjaganya (termasuk berjalan ke sana) atau mengemas pesanan RotiFood di titik kasirnya (`PlayerTaskManager.attends`). Jalur A yang tidak dijaga tertutup selama ada kasir staf dengan ruang, tanpa tahanan luapan (no. 80 bagian 1-2 dicabut), jadi: (1) **pembeli** yang menunggu di sana pindah ke kasir yang aktif (penyeimbangan jalur tutup, v3.1 21.3); aturan no. 80 bagian 3 tetap mencegah bolak-balik, karena pembeli tidak pernah dipindah *ke* jalur A yang tidak dijaga, jadi setiap pembeli pindah paling banyak sekali; bila semua kasir penuh, jalur A tetap terbuka sebagai luapan dan pemilik datang (Seksi 5.1 no. 1). (2) **Driver RotiFood** tanpa meja RotiFood (Tier 1-2) memilih jalur yang aktif saat datang (`QueueManager.driver_lane`): jalur A bila pemilik ada di sana, masih ada ruang, dan pemilik tidak sedang bersiap ke dapur; bila tidak, kasir staf dengan ruang terbanyak; jalur A hanya bila tidak ada kasir berruang. Driver yang menunggu di jalur A (masih di jalan, antre, atau di depan meja) pindah ke kasir yang aktif begitu jalur A tertutup (`RotiFoodManager._leave_empty_lane_a`). (3) Kasir staf boleh mengemas pesanan selagi yang berdiri di depan mejanya driver (bukan pembeli), supaya driver di jalur kasir tidak menunggu kasir yang menganggap dirinya sibuk. Serah terima tetap otomatis begitu pesanan dikemas. Mengemas tidak dihitung alasan pemilik ingin ke dapur (`wants_kitchen`), karena dikerjakan di kasir. Tes: `ACC_IDLE_DRIVER_ACTIVE_LANE`, `ACC_21_NO_LANE_PINGPONG` (pemilik pergi: pembeli luapan di jalur A pindah ke kasir begitu ada ruang, masing-masing paling banyak sekali), `ACC_21_QUEUE_SPLIT`. |

| 83 | Variasi di rak (2026-11-09) | Keputusan maintainer (Seksi 19 no. 22; menutup pertanyaan terbuka resep kedua, no. 41): setiap resep **berbeda** yang dijual petak rak (pilihan pemain yang bisa dibuat ditambah resep Auto yang disebar) menaikkan harga semua roti `variety.bonus_per_recipe` sampai `variety.max_recipes` resep: `variety_mult = 1 + bonus × (min(D, max) − 1)`, bagian dari `SimulationRoot.recipe_price`, jadi ikut model KR/s, offline, RotiFood, dan teks harga. **Rencana Auto** (`SimulationRoot._auto_plan`, fungsi murni state toko, di-cache per kunci yang memuat semua yang dibacanya, termasuk `EquipmentManager.list_version` dan `DisplayInventoryManager.version`): resep yang bisa dibuat diurutkan menurut laba bersih per roti (aturan Auto lama), lalu K resep teratas disebar ke petak Auto, dengan K = 1..min(resep, petak Auto) yang memberi laba rata-rata per roti × variasi terbesar menurut campuran pembeli (`IdleEconomyManager.walk_shares`; K lebih besar hanya bila naik > `PLAN_MARGIN` 0,2%). Petak Auto dibagi ke K resep itu **sebanding bagian permintaannya** (sisa terbesar, paling sedikit satu petak per resep, diselang-seling urut rak dan petak): dibagi rata, roti murah yang paling diminati sering habis dan pembeli pindah ke roti mahal, sehingga toko hidup jauh di atas model (sampel Tier 1 rasio 0,64). **Popularitas resep** (keputusan implementasi, bisa diubah maintainer; mengubah bobot Seksi 6.2): bobot pilihan pembeli dikali `recipe_price_mult(level)^variety.popularity_exponent`. Tanpa itu resep baru di Lv 1 jauh lebih murah daripada resep lama yang sudah naik level, pembeli yang pindah ke roti baru menurunkan harga rata-rata, dan bonus variasi hilang (resep kedua baru dibuka bot di menit 16). Dengan eksponen 1, biaya level per resep yang eksponensial membuat beberapa tangga level paralel jauh lebih murah dari satu tangga panjang dan ekonomi menggelembung (Tier 5 sebelum menit 60); eksponen 2 memusatkan permintaan pada resep utama, sehingga resep lain terutama menyumbang bonus variasi. Nilai: bonus 0,15, maks 5 resep, eksponen 2. Pendapatan tetap naik karena tangga resep kini terpakai, jadi biaya lokasi menjadi [0, 50K, 950K, 1,5M, 2,55M] (dulu [0, 32,5K, 360K, 1,12M, 1,9M]; T2 lebih mahal supaya seluruh rantai mundur, karena T4 dan T5 harus tetap di bawah 30 menit penghasilan tier sebelumnya agar bot tidak menjual toko saat macet) (`location.upgrade_cost`). Diukur dengan `tools/idle_probe.tscn` (seed 101/202/303, bot biasa tanpa iklan): median asisten pertama 4,1 menit, resep kedua terjangkau 5,3 (dibuka 5,3; dulu tidak pernah), Tier 2 13,7, Tier 3 37,5, Tier 4 69,4, Tier 5 100,9 (tipis, seperti 101,9 sebelumnya), Waralaba 101 (21 bintang), putaran ke-2 sampai Tier 5 dalam 46–49% waktu putaran 1; ACC_IDLE_PACING lolos. Tangga cabang (`--runs=8`, seed 101): cabang 1–8 = 101, 50, 56, 37, 66, 75, 79, 95 menit dengan 21, 8, 9, 9, 11, 13, 15, 17 bintang (103 bintang dalam 9,3 jam), semuanya sampai Tier 5 tanpa tebing, tetapi sejak cabang 7 lebih panjang dari "kira-kira 35–75 menit" Seksi 1.4 (sebelum variasi 35–72): ditutup oleh no. 89 (harga cabang mengikuti bintang). Lembar Menu: kartu Variety (pengali, aturan, roti yang dijual) dan satu kartu per rak dengan ubin petak (gambar, Slot n · Auto, isi) menggantikan dua belas baris yang sama. Tes ACC_IDLE_VARIETY, ACC_IDLE_MENU_SLOTS. |
| 84 | Perbaikan UI dari analisis 2026-11-09 | Permintaan maintainer ("eksekusi semuanya"). (1) Tombol beli dua baris berukuran tetap memotong teksnya tanpa terlihat ("Max (+250"): teks yang lebih lebar dari tombol kini mengecil sampai muat (`BuyButtons.fit_label`, paling kecil 60%), dan `ACC_IDLE_PORTRAIT_UI` kini juga memeriksa teks satu baris yang terpotong di dalam tombol (saldo besar, teks 150%). (2) Lembar Upgrades: "Best value first" di atas, promosi dan kopi di bawahnya, supaya aksi utama tampil di layar pertama. (3) Toast di lapisan kanvasnya sendiri (`HUD.TOAST_LAYER` 22, di atas lembar 20): sebelumnya lembar yang terbuka memotongnya; selama lembar bawah terbuka tumpukannya pindah ke bawah, di atas bar tab, supaya tidak menutupi judul dan tombol tutup lembar. (4) Lembar Staff: kandidat satu peran bekerja sama persis, jadi halaman utama menampilkan satu kandidat berikutnya per peran (dengan wajahnya, `ChibiPortrait`) dan baris "Other candidates (n)" ke halaman pilihan; peran yang penuh hanya diberi satu catatan, bukan deretan tombol "Role full". (5) Welcome Back: satu baris batas waktu dan efisiensi, bukan dua. (6) Efek upgrade berbagian hanya memberi panah pada bagian yang berubah ("Holds 13 per slot · Price ×1.00 → Price ×1.01"). (7) Peta Crumbtown selalu paling sedikit empat jalan; kavling yang belum dipakai tampil pudar sebagai "Empty lot" tanpa lencana "+". Tes ACC_7_STAFF_*, ACC_IDLE_WELCOME_BACK, ACC_130_SCROLLBAR_GAP (kini juga lembar Menu, karena Staff tidak bergulir lagi). |
| 85 | Umpan balik naik level (2026-11-09) | Pilar 2 (Seksi 1.2), bertingkat menurut pentingnya (skill game-feel): setiap level stasiun membuat perabotnya berkilau dan memantul (`WorldView.LEVEL_POP`; milestone tidak memantul karena evolusi modelnya mengambil alih); setiap level yang menaikkan KR/s menampilkan KR/s baru seketika dengan "+x/s" yang melayang naik dari KR/s dan pil KR yang memantul, lebih besar untuk lompatan >= 10% atau milestone; lompatan KR besar (hadiah, Collect, Roti Emas; > 5% saldo) dihitung naik selama 0,6 s, penjualan biasa langsung tampil. Reduced Motion: kilau dan angka yang memudar di tempat. `UpgradeManager.buy_offer` kini membuang cache model sebelum memancarkan `level_up`, supaya pendengarnya membaca KR/s yang baru. Tes ACC_IDLE_LEVEL_FEEDBACK. |
| 86 | Polesan art (2026-11-09) | (1) Bar progres di atas mixer dan oven berbentuk pil membulat seperti kit UI flat (mesh persegi membulat bersama per ukuran, `StationMarker.rounded_mesh`), bukan kotak tipis bertepi cokelat tua. (2) Bayangan lembut di lantai di bawah setiap perabot: cakram gradasi selebar jejaknya, anak node perabot (ikut tersembunyi saat dipegang, ikut memantul dan tumbuh saat evolusi), satu mesh dan material SHADOW bersama, tanpa shader baru, tidak ikut kotak batas (`EquipmentFactory.META_NO_BOUNDS`). (3) Pagar tanaman, semak, dan tajuk pohon jalan memakai 10 × 5 segmen (dulu 7–8 × 4, sisi bersegi terlihat dari dekat), tetap di bawah anggaran 20.000 segitiga jalan. (4) Arsiran ubin "Keep clear" di Decoration Mode: isi lembut dan bingkai tipis (`&"frame"`), bukan tiga garis diagonal per ubin yang ramai. |
| 87 | Performa (2026-11-09) | Diukur dengan `tools/render_probe.tscn` dan `tools/sim_profile.tscn`. (1) Wajah karakter: mata, alis, dan mulut tetap node ber-transform ekspresi (kontrak tes dan `TrafficFactory._rig` tidak berubah) tetapi disembunyikan; satu mesh `FaceMerged` menggambar kelimanya, di-cache per ekspresi di node Face, jadi satu karakter 9 draw call, bukan 13. render_probe: Tier 1 171 → 145 dan Tier 5 278 → 251 draw call (isi adegan sedikit berbeda antar-run). (2) Chip level tidak ditata dan digambar ulang setiap frame bila posisi puncak, ukuran pil, penghalang HUD, dan ukuran layar sama dengan frame lalu. (3) `WorldMoments` (staf baru, kardus stasiun baru) berakhir dengan tenang bila dunia dibangun ulang di tengah momennya (pindah lokasi, kunjungan cabang); dulu kardus yang sudah dibebaskan dibaca setiap frame (ratusan script error, ditemukan render_probe). Tes ACC_IDLE_MOMENTS_REBUILD. **Tidak dikerjakan, dengan alasan:** tahap loading yang menunggu musik tetap (kontrak v3.1 §89.5 dan TEST_UI_LOADING_STAGES; angka 45 s dari CPU emulator, bukan HP); pengukuran di HP dan optimasi simulasi (customers dan staff ~60% dari 1,04 ms per tick di Tier 5 (1,20 sebelum perubahan ini; 0,7 ms per frame di desktop)) menunggu pengukuran di perangkat target. |
| 88 | Hambatan terlihat (2026-11-09) | Mulai Tier 3 yang membatasi penjualan biasanya kasir dan antrean, bukan dapur (toko contoh: 19–23% pembeli ditolak antrean penuh sementara dapur memproduksi 6–7× permintaan). Chip meja kasir menambahkan "· Queue full" selama ada pembeli yang ditolak antrean penuh dalam 10 detik nyata terakhir (statistik `total_customers_missed`), dan panah chip stasiun hijau bila satu level menaikkan KR/s, abu-abu bila tidak menambah apa pun sekarang (`IdleEconomyManager.delta_rate`, satu chip per refresh HUD supaya tidak ada lonjakan kerja). Panah tetap tampil selama level terjangkau. Tes ACC_IDLE_BOTTLENECK. Model offline: sejak pemilik menunggu di samping batch (no. 81) serah-terima oven dengan koki dihitung dua jalan mixer-oven, bukan tiga (`OVEN_WALKS_WITH_BAKERS`); toko contoh Tier 1 yang dibatasi oven sebelumnya dihitung 15–20% terlalu rendah. Rasio model/hidup 24 jam: Tier 1 0,87, Tier 2 1,00, Tier 3 0,92, Tier 4 1,03, Tier 5 0,94, toko baru 1,07 (dulu Tier 3 0,81–0,83). |
| 89 | Harga cabang mengikuti bintang (2026-11-10) | Seksi 23.1. `branch_cost_base` 0,6, `branch_cost_power` 1,0, mulai cabang 3. Data tangga lama (biaya ×1,5 per cabang, seed 101): rasio biaya ÷ pengali bintang 0,5 → 56 menit, 0,8 → 66, 1,0 → 75, 1,3 → 79, 1,6 → 95, jadi rasio tetap 0,6 menjaga cabang sekitar 50–60 menit, dan dengan bonus kota penuh (+60%) masih di atas 35. Diukur dengan `tools/idle_probe.tscn -- --runs=12`: seed 101: 101, 47, 59, 34, 49, 45, 47, 47 menit untuk cabang 1–8; seed 202: 104, 45, 56, 58, 51, 47, 45 menit untuk cabang 1–7 (tangga lama seed 101: 101, 50, 56, 37, 66, 75, 79, 95). Bintang bertambah 8–10 per cabang dan pengali biaya naik bersama pengali bintang (1,8 di cabang 3, 3,3 di cabang 7); lamanya sedikit turun karena bonus kota bertambah sampai batasnya. Cabang 1 dan 2 sama seperti sebelumnya (ACC_IDLE_PACING: putaran 2 47%). Mode probe cepat tanpa simulasi pelanggan dicoba lalu dibuang: tanpa boost, Roti Emas, dan misi bot sudah macet di Tier 3 pada cabang 1, jadi tidak mewakili pemain. |
| 90 | Tujuan tanpa ujung (2026-11-10) | Seksi 23.2–23.4. Legacy sesudah 5.000 bintang (×1,1 per 1.000 bintang, bagian dari pengali bintang, jadi ikut harga cabang), mastery berlanjut ×2,5 roti per bintang, dan tiga seri pencapaian (`AchievementManager.series`, disimpan di `achievements.series`; save lama tanpa kunci itu mulai dari level 0). Seri memberi boost pencapaian tetapi tidak dekorasi. Tes ACC_IDLE_LEGACY, ACC_IDLE_MASTERY, ACC_IDLE_ENDLESS_SERIES. |
| 91 | Bonus kota (2026-11-10) | Seksi 23.5. `PrestigeManager.town_bonus` (di-cache per versi catatan cabang, nomor cabang, tier, dan `run_index`), bagian dari `SimulationRoot.plain_price` dan `price_mult`, jadi ikut model, offline, dan teks harga; kunci rencana Auto memuatnya. Tidak ikut harga cabang (23.1), supaya membawa cabang lama ke Tier 5 sungguh mempercepat. Nol di putaran 1. Tes ACC_IDLE_TOWN_BONUS. |
| 92 | Roti khas dan wajah lingkungan (2026-11-10) | Seksi 23.6. `PrestigeManager.signature(n)` dari `hash(benih utama, n)` atas katalog resep, bergeser satu resep bila sama dengan cabang sebelumnya; tidak ada di cabang 1. `NeighborhoodFactory.build(..., variant)` dengan `variant` = nomor cabang − 1 memutar warna dinding (langkah 3 dari 10) dan papan/kanopi (langkah 1 dari 6) lewat `_vary` pada spesifikasi bangunan; geometri sama persis. `ShopFrontArt.variant` memutar warna kanopi di peta. Tes ACC_IDLE_SIGNATURE, ACC_IDLE_STREET_VARIANT. |
| 93 | Toko uji (2026-11-10) | Seksi 22.2. `DummyMonetizationProvider` dipilih `Monetization._platform_provider()` selama `monetization.dummy_store` menyala (semua build kecuali preset portal). Ia memancarkan `Monetization.dummy_ad_requested` / `dummy_purchase_requested`; GameRoot membuka `DummyAdScreen` dan `TestPurchaseScreen` (lapisan overlay). Tanpa pendengar (alat headless) keduanya berhasil pada frame berikutnya. Runner tes memasang `MonetizationProvider` kosong dan berkas `user://test_monetization.json` sebelum setiap tes; alat yang menjalankan GameRoot memanggil `Monetization.use_test_file(nama)` supaya penawaran dan jatah iklan pemain di mesin ini tidak tersentuh. |
| 94 | Golden Crumbs dan PremiumManager (2026-11-10) | Seksi 22.3-22.7. `gameplay/meta/premium_manager.gd` (manajer global, bukan BRANCH_KEYS; save `premium`): crumbs, boost iklan (`ad_boost_left`, jam nyata: `step` saat bermain, `OfflineManager.settle` mengalikan bagian pergi yang tertutup boost lalu memotongnya; `settle_branch` tidak, karena boostnya sudah dipakai di cabang lain), time warp (`economy.credit` kategori baru `TIME_WARP`, termasuk penghasilan), Bakery Pass, hadiah harian Club, dan `deliver`. Hak beli perangkat disalin GameRoot ke `perks` (tidak disimpan; tanpa salinan = tanpa pembelian, jadi tes tetap deterministik). `premium.income_mult()` bagian `plain_price` dan `price_mult`, `ad_boost_mult()` bagian `boost_income_mult()`; kunci rencana Auto memuat pengali pembelian. |
| 95 | Bakery Pass tanpa jam dinding di simulasi (2026-11-10) | Seksi 22.7. XP ditambahkan ke musim yang tersimpan; hanya GameRoot (`check_daily_gift`, saat dimuat dan saat tanggal perangkat berganti) yang memanggil `ensure_season(BoostManager.today())`. Save tanpa musim mengambil musim pertama dengan XP yang sudah terkumpul. Barang musim dipilih dari `pass.season_items` dengan indeks tahun × 12 + bulan. |
| 96 | Penawaran dan Store (2026-11-10) | Seksi 22.9. GameRoot memeriksa penawaran setiap 2 detik bermain (`Monetization.update_offers(tier, franchise_count)`), membuka popup `offer` hanya tanpa layar lain, tanpa petunjuk tutorial, dan di luar Decoration Mode. Store (`ui/screens/store_screen.gd`) membangun ulang halamannya hanya bila keadaannya berubah dan mempertahankan posisi gulir; sisa waktu dan tombol iklan diperbarui di tempat. Kartu Supporter di lembar Shop dipindah ke Store (No Ads). |
| 97 | Kosmetik premium (2026-11-10) | Seksi 22.8. `DecorationDefinition.price_crumbs`, `look`, `colors`, dan `bonus_always()` (sumber selain `shop`: bonus berlaku selama dimiliki, dijumlah di `DecorationManager.bonus_mult` dengan cache per jenis). `WorldView._player_spec` membaca `look`; `RoomFactory` mewarnai kanopi dari `colors`; `DecorFactory` memakai ulang lampu dan karpet dengan warna lain dan menambah patung serta papan neon (material sendiri, kombinasi shader yang sama dengan bola lampu). Ikon baru: crumb, gift, ticket, crown, warp. |
| 98 | Kanopi di atas papan nama (2026-11-10) | Laporan maintainer: kanopi menghalangi nama toko dan hiasan di dinding. Dinding depan dipotong rendah (`RoomFactory.LOW_WALL` 0,16 m) supaya isi toko terlihat, sedangkan kanopi lama selebar seluruh dinding melayang di ketinggian 1,45 m dan miring ke arah kamera, jadi dari sudut kamera ia menutupi papan nama dan apa pun di belakangnya. Kini `RoomFactory._build_awning` memasang kanopi selebar papan (+12 cm tiap sisi) sebagai anak papan nama `Sign`: tepi atas di dinding dengan batang kayu, tepi bawah menjorok 12 cm ke jalan. Tinggi dan sudutnya (`AWNING_RISE`, `AWNING_DROP`, `AWNING_REACH`) dihitung dari kamera gameplay (yaw 45°, pitch 35°) supaya tepi bawahnya jatuh di atas tepi atas papan di layar. Dicek dengan `tools/ui_resolution_sweep.tscn -- --skin=skin_awning_gold` (opsi `--skin` baru). |
| 99 | Perayaan pembelian (2026-11-11) | Seksi 22.11, permintaan maintainer ("animasi untuk setiap item di Store yang berhasil terbeli, terutama Style"). `RewardReveal` (overlay `reward_reveal`) dengan `Sunburst` dan `ItemStage`: SubViewport `own_world_3d` berlatar tembus pandang yang memakai `EquipmentFactory.build_environment`, satu cahaya matahari, dan material MeshBuilder yang sama dengan dunia, jadi tidak ada kombinasi shader baru; kamera diarahkan lewat basisnya sendiri (panggung dibangun sebelum masuk pohon scene). Model: `WorldView.owner_spec(gender, outfit)` (dipakai juga oleh dunia), `RoomFactory.sign_preview` / `make_sign` (papan nama dipecah dari `_build_entrance`), dan `DecorFactory.build`. Partikel di `StoreFX` (confetti, kilau, kelip; tekstur gradien yang dibuat sekali, dibersihkan `ProceduralCaches`). HUD: lapisan efek `FX_LAYER` 23 di atas lembar dan toast, `fly_crumbs` (asal = `purchase_origin`, tombol beli terakhir), `pulse_boost`, `hold_toasts`. Diperiksa dengan `tools/ui_resolution_sweep.tscn -- --screens=reward_reveal` (enam contoh dan satu foto di tengah confetti). Tes ACC_IDLE_STORE_CELEBRATION. |
| 100 | Pintu masuk per tier dan skin pintu (2026-11-11) | Permintaan maintainer: pintu toko berbeda tiap tier, makin tinggi makin mewah, dan pintu bertema yang bisa dibeli. `DoorFactory` (procedural/meshes/door_factory.gd) membangun kusen, keset, dan hiasan pintu: Tier 1 tiang kayu polos dan keset gingham; Tier 2 kusen putih beralas dengan jendela atas berkisi, dua pot tanaman, keset mint bergaris; Tier 3 kusen kayu tua berkepala, deretan gigi di ambang, gagang kuningan, dua lampu dinding, pohon dalam tong kayu, keset sabut; Tier 4 pilar marmer bercincin kuningan, lentera, karpet merah ke trotoar, topiari bola dalam pot kuningan; Tier 5 pilar beralur berkepala emas, batu kunci emas, lentera berhias, tiang tali beludru, topiari kerucut dalam guci, karpet berlis emas. Papan nama berlis mulai Tier 3 (kayu, kuningan, emas). Semua bagian di atas tiang paling tinggi `DoorFactory.MAX_H` (0,88 m), di bawah papan nama, supaya nama toko dan isi toko tidak tertutup dari kamera (pelajaran no. 98); hiasan tema yang paling terbaca diletakkan di samping pintu (patung, planet, lolipop, istana pasir) karena muka ambang tertutup papan nama dari sudut kamera. Node bernama `Entrance`, bukan `Door` (nama pintu oven di `MeshBake.KEEP_NAMES`). Lampu dan bintang memakai material bola lampu, jadi tidak ada shader baru. Tes ACC_IDLE_DOORS. |
| 101 | Papan nama per tier dan per tema pintu (2026-11-11) | Permintaan maintainer ("termasuk dengan papan nama tokonya"). `DoorFactory.build_sign(style, w)` membangun badan papan sepaket dengan pintunya; `RoomFactory.make_sign` memilih gaya lewat `DoorFactory.sign_style`: tema skin pintu dulu, lalu skin papan ukir (`storefront_sign`), lalu tier. Tier 1 papan kayu beralur berpaku; Tier 2 papan cat krem bersudut bulat berbingkai mint; Tier 3 kayu ukir gelap berbingkai dengan lis dalam; Tier 4 muka marmer berbingkai kuningan berpaku keling dengan dua lampu sorot leher angsa; Tier 5 papan hijau kolonial berbingkai emas dengan lis dalam emas, lambang mahkota bersetempel merah, dan bola emas di kedua ujung. Warna tulisan per gaya ada di `DoorFactory.SIGN_TEXT`. Hiasan di atas papan (telinga, mahkota, lampu sorot) mengangkat kanopi setinggi `top_extra`, jadi aturan no. 98 (tepi bawah kanopi di atas papan dari kamera) tetap berlaku. Tes ACC_IDLE_DOORS. |
| 102 | Pintu tangga di sisi yang sama di kedua lantai (2026-11-11) | Laporan maintainer: di Tier 2 pintu tangga lantai 1 ada di dinding belakang (di balik kasir), sedangkan pintu lantai 2 di dinding depan, jadi terlihat aneh. `locations.json`: pintu tangga lantai 2 kini di baris belakang pada kolom yang sama dengan lantai 1 — Tier 2 dari (4, 0) ke (4, 7), akses (4, 6); Tier 3 dari (0, 0) ke (3, 11), akses (3, 10), dan (3, 11) dikeluarkan dari sel terlindung lantai 2 seperti di lantai 1. Tier 4 dan 5 hanya satu lantai. Jendela dinding belakang yang tertimpa kusen pintu tangga digeser ke sisi yang lapang (`RoomFactory.back_window_xs(w, portal_x)`, `portal_back_x`); ini juga memperbaiki lantai 1 Tier 3, tempat kusen pintu tangga sudah menimpa jendela. `DecorSlots` memakai posisi jendela yang sama. Save lama: alat yang berdiri di sel pintu atau sel akses yang baru dilepas dan ditempatkan ulang saat dimuat (`WorldManager.release_conflicts`). Dicek dengan `tools/ui_resolution_sweep.tscn -- --tier=2 --floor=2` (opsi `--floor` baru). |
| 103 | Papan nama selebar nama toko (2026-11-11) | Permintaan maintainer: panjang papan nama mengikuti panjang namanya dan nama tidak boleh terpotong. Dulu lebar papan ditebak dari jumlah huruf (0,1 m per huruf + 0,4 m, paling sempit 1,4 m), padahal tulisan Label3D (64 px x 0,0035 m) rata-rata ~0,12 m per huruf, jadi nama bawaan "Crumbtown Bakery" (tulisan 2,09 m) sudah keluar dari papan 2,0 m dan nama berhuruf lebar tertutup hiasan ujung papan. Kini `RoomFactory.sign_text_width` mengukur tulisan dengan font Label3D itu sendiri (`ThemeDB.fallback_font`, dipasang eksplisit di Label3D) termasuk garis tepinya, dan `sign_width` = tulisan + `SIGN_TEXT_PAD` 0,12 m di tiap ujung (melewati lis, paku, sekrup, dan tulang papan anjing), paling sempit `SIGN_MIN_W` 1,4 m, paling lebar `sign_room(f)`: papan berpusat di pintu masuk, jadi lebarnya 2 x jarak tengah pintu ke sudut muka toko terdekat dikurangi `SIGN_EDGE_ROOM` 0,15 m per sisi untuk hiasan di luar ujung papan dan kanopi (Tier 1-3 2,7 m, Tier 4 3,7 m, Tier 5 5,7 m). Nama yang tetap tidak muat di papan terlebar tulisannya diperkecil (`sign_text_scale`, `pixel_size`), tidak dipotong dan tidak dipecah baris (papan setinggi 0,28 m lebih terbaca dengan satu baris). Pratinjau perayaan Store memakai lebar muka lokasi tier yang sama (`sign_room_for_tier`). Papan 2D ikut: pratinjau papan di popup toko baru dan papan cutscene franchise mengecilkan huruf sampai nama muat satu baris (`ProceduralUIFactory.fit_font_size`) alih-alih elipsis atau pecah kata, nama di kartu Share mengecil (paling kecil 30 px) alih-alih terpotong, kartu simpanan Import Save membungkus nama ke baris kedua alih-alih elipsis, dan kolom nama di popup toko baru dibatasi 24 karakter sesuai aturan nama (GDD v3.1 89.4). `tools/ui_resolution_sweep.tscn -- --name=teks` memotret toko dengan nama apa pun. Tes: `ACC_IDLE_SIGN_FITS_NAME`. |
| 104 | Ikon tab bawah berilustrasi (2026-11-11) | Permintaan maintainer: ikon menu bawah terlihat terlalu basic dan jelek (siluet cokelat satu warna; ikon Decor berupa empat sudut putus-putus mirip ikon potong foto). `TabIcon` (ui/components/tab_icon.gd) menggambar tiap tab sebagai ilustrasi kecil 2-3 warna di atas piring bundar pastel miliknya sendiri, tetap flat (v3.1 130.6: tanpa garis tepi, bayangan, kilap, atau gradasi; sisi gelap berupa bidang warna kedua): Upgrades kilat kuning-madu dengan dua kilau (piring mint), Menu roti maskot `LogoBread` berwajah (piring biru muda), Staff koki bertopi tinggi dan berkerah merah yang jasnya dipotong piring (piring peach), Shop toko kayu berkanopi garis stroberi dengan dua jendela dan pintu (piring mentega), Decor tanaman pot terakota berdaun dua warna dengan sekuntum bunga (piring merah muda), Franchise bintang bersegi berwajah (piring lavender). Ukuran 46 px logis (`HUD.TAB_ICON`, dulu 34). Tab aktif tetap bermuka madu dengan teks krem; piringnya membesar sedikit dan ikonnya memantul sekali (squash & stretch 0,32 s, diam bila Reduced Motion). Ikon satu warna `IconCanvas` (bolt, bread, people, shop, frame, star) tetap dipakai di tempat lain. Tes: `ACC_130_UI_POLISH`. |
---

# **21. Fitur Retensi & Berbagi**

Permintaan maintainer 2026-11-03 (Seksi 19 no. 18): game harus memberi alasan untuk terus main dan untuk mengajak teman. Lima fitur dikerjakan berurutan. Semuanya **tetap offline penuh** (Seksi 1.3): tanpa server, akun, iklan, IAP, atau notifikasi. Hari "perangkat" memakai tanggal perangkat seperti Kopi Pak Lurah (Seksi 11.1); hari "in-game" memakai jam toko (1 hari = 24 menit nyata).

## **21.1 Craving Harian & Selera Lingkungan (TUNABLE: `craving.*`)**

Tujuan: setiap resep punya alasan untuk dibuka dan dijual, bukan hanya satu resep yang terus dinaikkan levelnya (keputusan terbuka "resep kedua tidak pernah balik modal").

- **Selera lingkungan.** Setiap lokasi punya dua **roti favorit** warga (`craving.favorites_by_tier`): Tier 1 Roti Goreng dan Donat Gula, Tier 2 Sosis Gulung dan Roti Cokelat, Tier 3 Cinnamon Roll dan Croissant, Tier 4 Brioche Matcha dan Croissant Almond, Tier 5 Truffle Bun dan Mille Crêpes Matcha. Roti favorit lokasi sekarang dijual ×`craving.favorite_mult` (1,25). Selera ikut model KR/s dan penghasilan offline karena tetap.
- **Craving harian.** Mulai hari in-game ke-`craving.first_day` (2), setiap pukul 00:00 kota mengidam satu resep: diundi rata dari resep yang **alatnya sudah ada** (mixer dan oven setier syaratnya), terbuka maupun belum, dan tidak sama dengan craving kemarin. Undian ditentukan seed master dan nomor hari (deterministik, tidak memakai stream RNG lain).
- **Harga craving.** Selama resep craving **terbuka**, rotinya dijual ×`craving.best_mult` (1,2) harga biasa roti termahal yang bisa dijual toko, termasuk dirinya sendiri ("20% more than your best bread"). Jadi craving selalu menjadi roti paling menguntungkan hari itu, berapa pun levelnya, dan membuka resep baru terbayar di hari craving-nya. Resep craving yang belum terbuka tidak memberi efek sampai dibuka.
- **Auto** memilih resep dengan laba bersih per roti tertinggi termasuk selera dan craving, jadi petak Auto beralih sendiri ke craving yang sudah terbuka. Roti lama di petak tetap dijual habis (Seksi 4.2).
- **Offline.** Craving diperlakukan seperti boost: ikut KR/s di HUD, tetapi **tidak** ikut penghasilan offline (Seksi 9.1). Model tanpa craving juga memilih resep Auto tanpa craving (`auto_recipe(false)`); kalau tidak, petak Auto dinilai dengan resep craving berharga biasa Lv 1 dan KR/s offline anjlok di hari craving (contoh tes: 116,7 menjadi 1,0 KR/s).
- **UI.** Pil craving di bawah jam HUD menampilkan gambar roti dan namanya (gembok bila belum terbuka); mengetuknya membuka Menu. Toast pagi: "Today's craving: {recipe}!". Di Menu, baris resep craving mendapat pil "Craving" madu dan roti favorit pil "Local favorite" mint; kartu di atas daftar resep menjelaskan aturannya.

## **21.2 Misi Ringan Harian (TUNABLE: `goals.*`)**

Tujuan: alasan kecil untuk membuka game beberapa kali sehari dan mencoba hal yang biasanya dilewati (RotiFood, ketukan Semangat, level).

- **Tiga tujuan per hari in-game** (`goals.per_day`), mulai hari ke-`goals.first_day` (2), seperti craving: hari pertama milik tutorial, dan hadiah misi di menit-menit awal terlalu besar dibanding penghasilan 1 KR/s (resep kedua jadi terjangkau sebelum menit ke-5, Seksi 1.4). Sampai saat itu lembar Goals menulis "Your first goals arrive on day 2". Setiap pukul 00:00 tujuan yang **belum selesai** diganti, sedangkan tujuan yang **selesai tetapi belum diklaim** tetap menunggu (tidak ada hadiah yang hilang). Template diundi tanpa pengulangan dalam satu set dari seed master, nomor cabang, dan nomor hari (deterministik, tidak memakai stream RNG lain).
- **Template** (`goals.templates`): jual roti (`total_bread_sold`), layani pembeli (`total_customers_served`), dapatkan KR (`alltime_earned_kr`, termasuk penghasilan offline), selesaikan pesanan RotiFood, beli level upgrade (`levels_bought`), dan ketukan Semangat yang berhasil (`semangat_taps`). Target dihitung dari toko saat tujuan terbit: jenis `units`/`customers`/`rotifood`/`kr` = laju model tanpa boost (Seksi 9.1) × `minutes` menit nyata; jenis `fixed` = angka per tier lokasi (`by_tier`). Target dibulatkan ke dua angka penting dan tidak pernah di bawah `min`.
- **Kemajuan** = statistik sekarang − nilainya saat tujuan terbit. Tujuan tidak punya kait sendiri di sistem lain; tiga statistik baru (`levels_bought`, `semangat_taps`, `goals_completed`) ikut tersimpan dan tampil di Stats.
- **Hadiah** = `goals.reward_income_minutes` (2) menit KR/s model tanpa boost, paling sedikit `goals.reward_min_kr`, ditetapkan saat tujuan terbit dan dibayar saat **Claim**. Hadiah masuk ke ledger sebagai kategori baru `REWARD`, **bukan** pemasukan: tidak menambah `run_earned_kr`, jadi tidak menambah Bintang Waralaba, dan tidak memajukan tujuan "Earn".
- **Waralaba** menerbitkan set baru untuk cabang baru (hadiah lama dihitung dari pendapatan cabang lama).
- **UI.** Tombol bundar "Goals" (ikon bendera) di bawah tombol Pause, bertitik hijau bila ada tujuan atau cap harian yang bisa diambil; toast "Goal complete! Claim your reward in Goals." saat tujuan selesai. Lembar Goals (Seksi 12.0.5): kartu cap harian di atas, lalu tiga kartu tujuan dengan ikon, teks ("Sell 160 bread"), bar kemajuan, "{done} / {target}", pil hadiah, dan tombol Claim (atau pil "Done").

## **21.3 Kalender Cap Harian (TUNABLE: `calendar.*`)**

Tujuan: alasan untuk kembali besok, tanpa menghukum yang absen.

- **Satu cap per tanggal perangkat** (seperti Kopi Pak Lurah, Seksi 11.1), mulai tanggal **sesudah** kunjungan pertama: hari pertama profil (atau hari pertama save lama dimuat dengan fitur ini) hanya memulai kartu, sehingga sesi pertama tidak terganggu dan pemain punya alasan kembali besok.
- **Tujuh cap berputar** (`calendar.rewards`): KR 10 / 15 menit penghasilan, boost ×`calendar.boost_mult` (2) selama 10 menit, KR 20 / 25 menit, boost 20 menit, lalu cap ketujuh: KR 30 menit **plus** dekorasi kalender berikutnya yang belum dimiliki (`calendar.decor_rewards`: Loyalty Stamp Card di dinding, Golden Croissant di meja kasir, Party Bunting di dinding). Setelah ketiganya dimiliki, cap ketujuh hanya memberi KR. KR dihitung dari KR/s model tanpa boost saat cap diambil (paling sedikit `calendar.min_kr`) dan masuk sebagai `REWARD`. Boost mengikuti aturan boost Seksi 11 (tidak menumpuk, berjalan hanya saat bermain aktif).
- **Tidak ada hukuman**: melewatkan hari tidak mereset kartu; cap berikutnya hanya menunggu. Kalender bertahan lintas Waralaba, dan dekorasinya kosmetik (tanpa bonus) seperti hadiah pencapaian.
- **UI.** Popup "Daily Stamps" (lapisan sistem) terbuka sendiri saat profil dimuat atau aplikasi kembali ke depan pada tanggal baru, sesudah popup Selamat Datang bila keduanya ada. Kartu tujuh petak (4 + 3, di tengah): petak yang sudah dicap hijau mint bercentang, cap hari ini madu, sisanya krem dengan ikon dan hadiahnya. Tombol "Stamp it!" mengambil cap, lalu kartu tampil lagi dengan cap barunya dan tombol Close. Lembar Goals menampilkan kartu yang sama dalam satu baris dengan tombol "Stamp it!" bila cap tersedia.
- Simulasi tidak membaca jam perangkat: GameRoot memberikan tanggalnya (`BoostManager.today()`, dipalsukan tes lewat `date_override`), jadi save tes tetap tanpa nilai jam dinding.

## **21.4 Share My Bakery**

Tujuan: pemain bisa memamerkan tokonya dan mengajak teman, tanpa server, akun, atau tautan undangan.

- **Dari menu Pause**: "Share my bakery" membuka popup yang memotret toko saat itu **tanpa HUD dan popup** (dua frame tanpa keduanya), lalu merakit **kartu 1080 × 1350** (4:5, ukuran unggahan media sosial) dari kit UI flat: pita gingham di atas dan bawah, logo Crumbtown, potret toko dalam bingkai kartu (potongan 2:1 di sekitar lantai toko), nama toko, nama lokasi (ditambah "Branch #n" setelah Waralaba), empat angka (KR/s, roti terjual, Bintang Waralaba atau pembeli yang dilayani bila belum punya bintang, dan hari buka), dan pita "Can you beat my bakery?". Ukuran hurufnya tetap, tidak ikut pengaturan ukuran teks.
- **Pratinjau** kartu tampil di popup. Tombolnya **Share** di Web: lembar bagi browser dengan berkas PNG (Web Share API, umumnya di HP), atau unduhan bila browser tidak mendukungnya. Di platform lain tombolnya **Save image**: PNG disimpan ke `Pictures/Crumbtown` (folder data game bila tidak ada folder Pictures), dan popup menyebut lokasinya.
- Nama berkas `crumbtown-bakery-<nama toko>-<YYYYmmdd-HHMMSS>.png`, hanya huruf kecil, angka, dan tanda hubung.
- `core/web_platform.gd` tetap satu-satunya kode yang memanggil JavaScript (`share_or_download_png`).

## **21.5 Photo Mode**

- **Dari menu Pause**: "Photo mode" menyembunyikan HUD, sementara toko **tetap berjalan** (bukan lapisan yang mem-pause). Kamera bebas digeser (seret) dan di-zoom (roda / cubit) seperti Decoration Mode; ketukan dunia tidak berbuat apa-apa.
- **Filter**: Natural, Warm, Golden hour, Cool, Vintage, Night, berupa lapisan warna polos di atas dunia (tanpa shader, jadi tidak menambah kombinasi material, v3.1 §89.5). **Frame** menambahkan bingkai polaroid krem dengan nama toko di tepi bawah.
- **Capture** memotret layar dengan filter dan bingkainya tetapi tanpa tombol photo mode, disertai kilat putih singkat (tanpa kilat bila Reduced Motion), lalu menyimpan atau membagikan PNG seperti kartu Share (`crumbtown-photo-…`). Karena HUD tersembunyi, hasilnya ditulis di bar photo mode, bukan toast. Tombol X keluar dan mengembalikan HUD, kamera, dan ketukan dunia.

## **21.6 Event Musiman (TUNABLE: `events.*`)**

Tujuan: alasan kembali di musim-musim tertentu, dengan tampilan toko yang ikut berubah, tanpa server (semua dari tanggal perangkat).

- **Kalender** (`events.list`), mengikuti tanggal perangkat seperti Kopi Pak Lurah (Seksi 11.1). Event bertanggal tetap memakai jendela `from`–`to` ("MM-DD", boleh melewati tahun baru): Sweetheart Week 7–14 Feb, Spring Blossom Fair 21 Mar–4 Apr, Summer Picnic 1–14 Jul, Merdeka Week 10–20 Agu, Harvest Festival 18–31 Okt, Winter Holidays 18 Des–2 Jan. Event bulan memakai tabel tanggal per tahun (`dates`) dengan `before`/`after` hari: **Lunar New Year** 2027–2031 (6 Feb 2027, 26 Jan 2028, 13 Feb 2029, 3 Feb 2030, 23 Jan 2031; −2 sampai +5 hari) dan **Lebaran** 2027–2030 (perkiraan 10 Mar 2027, 26 Feb 2028, 14 Feb 2029, 5 Feb 2030; −4 sampai +4 hari, jadi selisih sidang isbat satu-dua hari tetap tercakup). Tabel ini perlu diperpanjang maintainer setiap beberapa tahun.
- **Beberapa event boleh bersamaan** (mis. Imlek dan Sweetheart Week 2027); efeknya digabung dan namanya ditulis "A & B".
- **Efek**: tiga **roti unggulan** per event (satu murah, satu menengah, satu mahal) dijual ×`events.featured_mult` (1,25), seperti roti favorit (ikut model KR/s dan penghasilan offline). **Tujuan yang terbit** selama event berhadiah ×`events.goal_reward_mult` (2). Toko berhias untaian bendera warna event (HolidayFactory tema 3–8: Imlek merah-emas berlampion, musim dingin merah-putih-hijau berbola hias, Sweetheart merah muda, musim semi bunga, piknik langit-mentega, panen jingga; Merdeka memakai merah-putih tema 0 dan Lebaran hijau-kuning berketupat tema 2), mendahului hiasan libur in-game.
- **UI**: toast sekali per kemunculan event ("{name} has begun! …", tercatat di save supaya tidak berulang), pil HUD di bawah pil craving ("{name} · until {date}") yang membuka Menu, pil "Event" di baris roti unggulan dan satu baris penjelasan di kartu Menu, serta spanduk di lembar Goals. Toast panjang kini dibungkus (lebar teks paling besar 540 px).
- Simulasi tidak membaca jam perangkat: GameRoot memberi tanggalnya saat profil dimuat, saat aplikasi kembali ke depan, dan setiap 5 detik bermain (tanggal yang berganti di tengah permainan juga memberi kopi dan cap harian hari baru). Tanpa tanggal (probe, tes simulasi) tidak ada event, dan test runner mematikan event (`EventManager.enabled`) kecuali di tes event, supaya hasil tes tidak bergantung pada hari tes dijalankan.

## **21.7 Peta Crumbtown**

Tujuan: Waralaba terasa seperti membangun kota, bukan hanya mengulang dari nol.

- **Catatan cabang.** Saat Waralaba, cabang yang ditinggal dicatat di save (`PrestigeManager.branches`): nomor cabang, tier lokasi tertinggi, Bintang Waralaba yang didapat, KR yang didapat cabang itu, KR/s model saat ditinggal, dan hari dibuka; sejak Seksi 20 no. 78 juga tokonya sendiri dan acuan tabungannya, dan catatan yang sama ditulis setiap kali sebuah cabang ditinggal untuk dikunjungi cabang lain (save lama masih menyimpan hari dijual). Hari buka cabang baru (`run_started_day`) ikut tersimpan. Save dari sebelum peta hanya tahu nomor cabangnya: cabang lama tampil sebagai kavling bertoko tier 3 tanpa cerita ("its story is lost to time").
- **Peta** (lembar bawah, dari tombol "Crumbtown map" di lembar Franchise): jalan-jalan kota bertumpuk ke bawah, tiga kavling per jalan, dengan rumput, pohon bulat di antara kavling, dan jalan beraspal bergaris. Setiap cabang berdiri di kavlingnya dengan gambar etalase tier yang dicapainya (`ShopFrontArt`, sama dengan kartu save) dan label "Branch #n"; cabang yang sedang buka berlabel madu "You are here", dan kavling terakhir berisi siluet "Next branch" untuk Waralaba berikutnya.
- **Cerita cabang**: mengetuk sebuah toko membuka halaman berisi etalase besar, nama toko dan lokasinya, bintang yang didapat (cabang yang buka: "Stars if you franchise now"), KR yang didapat, penghasilan per detik, dan hari dibuka ("Day x").
- **Kunjungan** (Seksi 20 no. 78): kavling setiap cabang lain menyebut tabungan yang menunggu ("+1.2K KR"), dan cerita cabangnya punya baris "Waiting to collect" dan tombol "Visit Branch #n" yang memindahkan pemain ke cabang itu.

## **21.8 Tip untuk Fitur Baru**

Permintaan maintainer 2026-11-03: fitur Seksi 21 harus ditemukan pemain. Lima tip onboarding baru (Seksi 13) tampil sekali, bisa ditutup, ikut arsip Help, dan tidak tampil bila tip dimatikan:

| Kunci | Pemicu | Sasaran |
|---|---|---|
| `onb_craving` | craving pertama (hari 2) | pil craving di HUD; selesai saat Menu terbuka |
| `onb_goals` | tujuan harian pertama (hari 2) | tombol Goals; selesai saat lembar Goals terbuka |
| `onb_event` | event musiman pertama | pil event di HUD; selesai saat Menu terbuka |
| `onb_share` | pindah ke Tier 2 | tombol Pause; selesai saat menu Pause terbuka |
| `onb_map` | cabang kedua (setelah Waralaba) | tab Franchise, lalu tombol "Crumbtown map"; selesai saat peta terbuka |

Tip bersasaran tombol HUD memakai panduan ketuk yang sama (`TutorialGuide`, sasaran `hud_<name>`). Kalender cap tidak diberi tip karena popupnya sudah menjelaskan diri sendiri.

## **21.9 Roti Emas (TUNABLE: `golden.*`)**

Permintaan maintainer 2026-11-03: momen seru selama bermain aktif, seperti "golden cookie".

- **Hanya saat bermain aktif.** Roti emas pertama muncul setelah `golden.first_after_minutes` (8) menit nyata bermain (sesudah tutorial pertama; dengan 3 menit, hadiahnya mempercepat Tier 2 ke menit 11,6), berikutnya setiap `golden.interval_minutes` (5–8) menit. Semua timer dalam detik nyata permainan aktif (berhenti saat pause, di latar, dan offline), jadi roti emas tidak pernah muncul atau memberi apa pun saat pemain pergi.
- **Terbang** melintasi bingkai selama `golden.visible_seconds` (9) detik, bergantian dari kiri dan kanan dengan gelombang naik-turun, di atas lembar bawah (bisa ditangkap selagi lembar terbuka), tetapi tersembunyi selama modal pemblokir, Decoration Mode, dan Photo mode. Gambarnya roti emas bergaris dengan lingkar cahaya berdenyut dan dua kilau; sasaran ketuknya 112 px. Kalau tidak diketuk, ia terbang pergi tanpa hukuman.
- **Hadiah acak berbobot** (`golden.rewards`), diundi dari seed master dan nomor penerbangan (tanpa stream RNG lain):
  - *Golden bread* (bobot 50): KR sebesar 0,75 menit KR/s model tanpa boost (paling sedikit `golden.min_kr`), masuk sebagai `REWARD`.
  - *Golden hour* (30): penghasilan ×3 selama 30 detik, **di atas** boost lain (kopi ×2 + Golden hour = ×6), hanya di KR/s hidup.
  - *Rush hour* (20): kedatangan pembeli ×2 selama 60 detik, di atas promosi.
  Golden hour dan Rush hour tampil sebagai pil boost di baris kedua di bawah KR, ikut tersimpan, dan direset oleh Waralaba seperti boost lain. Toast menyebut hadiahnya; KR disertai hujan koin.
- **Tip** `onb_golden` menunjuk roti emas pertama (panduan ketuk yang mengikuti posisinya) dan selesai sendiri saat roti itu tertangkap atau pergi.
- **Pacing.** Pemain biasa (`SimBot.catch_golden`) menangkap setiap penerbangan bernomor genap (separuhnya); probe dan `ACC_IDLE_PACING` memakainya.

## **21.10 Pelanggan Langganan & Minigame Pesanan (TUNABLE: `regulars.*`)**

Permintaan maintainer 2026-11-03: karakter yang membuat pemain terikat, **hanya aktif saat pemain membuka game**, dengan **minigame untuk menyelesaikan pesanannya**.

- **Delapan warga Crumbtown** (`regulars.list`): Mila the Florist, Raka the Courier, Grandma Rosa, Coach Ben, Dr. Ana, Leo the Student, Nina the Painter, dan Mr. Wong the Grocer. Masing-masing punya sosok tetap (warna kulit, rambut, gaya rambut, topi, aksesori, baju, barang bawaan; dipakai sosok 3D `CharacterFactory.spec_for_regular` dan potret 2D tanpa celemek), roti favorit, sapaan, dan lima kenangan.
- **Hanya saat bermain aktif.** Kunjungan pertama setelah `regulars.first_after_minutes` (10) menit nyata bermain, berikutnya setiap `regulars.interval_minutes` (7–11) menit; semua timer dalam detik nyata permainan aktif, jadi tidak ada kunjungan saat pergi. Regular berikutnya tidak pernah orang yang sama dua kali berturut-turut. Undian (siapa, pesanan, jeda) memakai seed master dan nomor kunjungan.
- **Kunjungan.** Toast "{name} is here with a special order!", sosoknya berjalan masuk dari trotoar dan menunggu di dekat rak dengan hati melayang di atas kepalanya, dan kartu "Special order!" (potret, nama, bar waktu tunggu) di atas bar tab. Ketuk kartunya atau sosoknya untuk membuka minigame. Ia menunggu `regulars.wait_seconds` (120) detik; kalau dibiarkan, ia pulang tanpa hukuman dan tanpa pertemanan.
- **Pesanan**: `regulars.order_items_base` (3) roti ditambah satu per dua hati (paling banyak `order_items_max`, 5), roti favoritnya bila toko bisa membuatnya, sisanya acak dari resep yang bisa dibuat (boleh berulang).
- **Minigame "Pack the order"** (popup yang mem-pause toko): potret dan sapaan di atas, tiket pesanan, bar waktu `minigame_seconds` (14) + 2 detik per roti, dan baki 8 roti (yang dipesan ditambah pengecoh dari resep lain, diacak). Ketuk roti yang dipesan; roti yang benar masuk tiket bercentang, yang salah bergetar dan memotong `wrong_tap_seconds` (2) detik. Semua masuk = selesai: sisa waktu ≥ 50% tiga bintang, ≥ 25% dua, selain itu satu. Waktu habis = gagal ("Out of time!"), regular pulang tanpa hadiah. Menutup popup sebelum selesai tidak menggagalkan: regular tetap menunggu.
- **Hadiah**: `reward_income_minutes` (1) menit KR/s model tanpa boost (paling sedikit `min_kr`), ditetapkan saat ia datang, × `star_bonus` (1 / 1,25 / 1,5 untuk 1–3 bintang), masuk sebagai `REWARD`.
- **Pertemanan**: lima hati; pesanan selesai ke-`levels` (1, 3, 6, 10, 15) mengisi hati berikutnya, membuka satu kenangan (teks cerita pendek) dan hadiah pertemanan `level_gift_income_minutes` (1,5) menit penghasilan (dengan 5 menit, hati pertama setiap warga, yang terisi di pesanan pertamanya, membuat Tier 5 tercapai di menit 82). Layar hasil menampilkan bintang, KR, hati, dan kenangan baru.
- **Album**: bagian "Regulars" di lembar Goals: potret (pudar dan "Not met yet" sebelum bertemu), jumlah pesanan, hati, dan tombol kenangan yang membuka halaman kenangan (yang belum terbuka bergembok).
- **Tip** `onb_regular` menunjuk kartu pada kunjungan pertama dan selesai saat minigame terbuka.
- **Pacing.** Pemain biasa (`SimBot.serve_regulars`) mengerjakan kunjungan bernomor genap dengan dua bintang sekitar 20 detik setelah regular datang.

## **21.11 Pacing dengan Roti Emas dan Pelanggan Langganan**

Hadiah KR sekaligus mempercepat tabungan tetapi tidak menaikkan KR/s model, sedangkan pemain biasa menjual toko bila 20 menit di satu tier lokasi berikutnya masih lebih dari 30 menit penghasilan (`PacingTracker.franchise_now`). Karena itu biaya lokasi tidak bisa dinaikkan jauh: T4 1,2M membuat bot mandek di Tier 3 (Waralaba di menit ~50) dan T5 1,95M di Tier 4. Dengan hadiah awal (Roti Emas 1,5 menit, pesanan 2 menit, hadiah hati 5 menit) Tier 5 tercapai di menit 82. Nilai akhir: Roti Emas 0,75 menit, pesanan 1 menit, hadiah hati 1,5 menit, `location.upgrade_cost` [0, 32,5K, 360K, 1,12M, 1,85M] (sejak no. 52: Tier 5 1,9M). Median seed 101/202/303 (`idle_probe --minutes=220 --manage --franchise=5`, bot menangkap separuh roti emas dan mengerjakan separuh pesanan dengan dua bintang): Tier 2 13,3, Tier 3 31,6, Tier 4 67,3, Tier 5 101,9, Waralaba 102 menit, putaran 2 ke Tier 5 dalam 38% waktu putaran 1.

---

# **22. Monetisasi**

Keputusan maintainer 2026-11-05 (Seksi 19 no. 19): game boleh menghasilkan uang. Keputusan maintainer 2026-11-10 (Seksi 19 no. 24): monetisasi dibuat **semaksimal mungkin selama permainan tetap menyenangkan**, dengan target rilis pertama Google Play (Android), lalu App Store. Aturan lama 22.1 (hanya iklan berhadiah dan satu Supporter Pack; tanpa mata uang premium dan tanpa pengganda permanen) diganti bab ini. Gameplay tetap offline penuh: iklan dan toko hanya tambahan.

## **22.1 Prinsip: Menghasilkan Uang Tanpa Merusak Permainan**

Yang dijual adalah kenyamanan, kecepatan, dan gaya, bukan pintu yang terkunci.

- **Tanpa iklan paksa.** Tidak ada interstitial dan banner. Setiap iklan dipilih pemain lewat tombol yang jelas bertanda iklan ("· Ad"), dan hadiahnya hanya diberikan bila iklan selesai ditonton. Iklan yang gagal atau ditutup lebih awal tidak memberi hadiah dan tidak memakai jatah harian.
- **Seluruh permainan bisa dicapai gratis.** Semua tier, resep, staf, cabang, perk, dan pencapaian terbuka tanpa uang. Pembelian hanya mempercepat (boost, time warp, pengganda), memperpanjang penghasilan offline, atau kosmetik.
- **Golden Crumbs gratis setiap hari** dari misi harian, cap kalender, pencapaian, seri tanpa ujung, cabang baru, Bakery Pass jalur gratis, dan iklan (22.3), sehingga pemain yang tidak membayar tetap bisa membeli kosmetik dan time warp.
- **Penawaran tidak mengganggu.** Popup penawaran tampil paling banyak sekali per penawaran, hanya saat tidak ada layar lain dan tidak ada petunjuk tutorial, dan selalu punya "Maybe later". Sesudahnya penawaran menunggu di Store sampai waktunya habis.
- **Harga jelas.** Tombol uang sungguhan selalu menyebut harganya; tombol Golden Crumbs selalu menyebut jumlah crumbs. Tidak ada gacha, loot box, energi, atau timer yang memblokir permainan.
- **Pacing Seksi 1.4 dan 23 diukur tanpa iklan dan tanpa pembelian**; semuanya hanya mempercepat. SimBot tidak pernah membeli.
- **Selama iklan** toko di-pause dan semua suara dibisukan; sesudahnya kembali seperti semula.

## **22.2 Platform dan Toko Uji (TUNABLE: `monetization.dummy_store`)**

| Build | Iklan berhadiah | Toko (IAP) |
|---|---|---|
| Selama `dummy_store` = true: desktop, Web biasa, Android | **Toko uji**: iklan tiruan dan pembelian tiruan | Toko uji |
| CrazyGames (preset `Web CrazyGames`) | SDK HTML5 v3 `SDK.ad.requestAd("rewarded", ...)` | Tidak ada |
| Poki (preset `Web Poki`) | Poki SDK v2 `PokiSDK.rewardedBreak()` | Tidak ada |
| Android rilis (nanti) | AdMob rewarded lewat plugin Android | Google Play Billing lewat plugin Android |
| iOS (nanti) | AdMob rewarded | App Store (StoreKit) |

- **Toko uji** (`DummyMonetizationProvider`, keputusan maintainer 2026-11-10: "jangan dulu dihubungkan ke Google Play atau App Store, buat tombol dummy"). Iklan tiruan: layar penuh "Test ad" dengan hitung mundur `dummy_ad_seconds` lalu Claim reward; Close lebih awal = tanpa hadiah. Pembelian tiruan: popup "Test store" dengan nama produk, harga `price_usd`, isinya, dan catatan bahwa tidak ada uang yang ditarik; Buy (test) atau Cancel. Store menulis "Test store: ads and purchases are simulated and no money is charged." Tidak ada jaringan dan tidak ada SDK. Begitu plugin Play Billing dan AdMob dipasang, `dummy_store` dimatikan dan penyedia Android menggantikannya tanpa mengubah layar.
- **Portal web.** Seperti sebelumnya: SDK portal dari `html/head_include`, hanya lewat `WebPlatform`, PWA mati, sinyal siklus hidup. Portal tidak mengizinkan IAP, jadi Store di sana hanya berisi hal yang dibayar dengan iklan atau Golden Crumbs.
- **Android rilis** butuh akun Play Console dan AdMob, ID unit iklan, izin INTERNET, persetujuan pengguna (UMP/GDPR), kebijakan privasi, formulir Data Safety, rating konten, dan target API terbaru Google Play. Plugin AdMob dan Google Play Billing tetap **satu-satunya pengecualian** larangan addon pihak ketiga (v3.1 §96).
- Hak beli perangkat (produk tetap, Baker's Club, jam penawaran, jatah iklan) disimpan di `user://monetization.json`, bukan di save; isi yang masuk save (Golden Crumbs, isi paket, Pass premium) masuk lewat `PremiumManager.deliver`.

## **22.3 Golden Crumbs (TUNABLE: `premium.*`)**

Mata uang premium, disimpan di save (kunci `premium`) dan milik seluruh Crumbtown: Waralaba dan kunjungan cabang tidak mengubahnya. KR tetap mata uang toko.

| Sumber gratis | Golden Crumbs | XP Pass |
|---|---|---|
| Toko baru (atau save dari sebelum toko) | `start_crumbs` (50) | – |
| Klaim misi harian | 5 | 40 |
| Cap kalender (cap ketujuh +20) | 5 | 30 |
| Pencapaian katalog | 10 | 40 |
| Setiap level seri tanpa ujung | 15 | 40 |
| Cabang baru (Waralaba) | 2 per bintang | 150 |
| Iklan `ad_crumbs` | 5 (5× sehari) | 10 |
| Bakery Pass, Baker's Club | lihat 22.7, 22.5 | – |

Belanja Golden Crumbs: boost ×2 4 jam (40), time warp (22.6), dan kosmetik premium (22.8). Saldo tidak pernah di bawah nol.

## **22.4 Iklan Berhadiah (TUNABLE: `monetization.placements`)**

| ID | Di mana | Hadiah | Batas per hari |
|---|---|---|---|
| `offline_double` | Popup Welcome Back: **Collect ×2** | Penghasilan offline ×2 | 10 |
| `coffee_refill` | Lembar Upgrades, Boosts: **Another coffee** | Kopi Pak Lurah sekali lagi | 2 |
| `promo_skip` | Promosi yang sedang jeda: **Skip wait** | Jeda promosi selesai | 5 |
| `golden_double` | Tombol **×2** sesudah Roti Emas berhadiah KR | KR roti emas sekali lagi | 10 |
| `ad_boost` | Store, tab Boosts | **Income ×2 selama 4 jam**, menumpuk sampai 12 jam | 8 |
| `ad_warp` | Store, tab Boosts | Penghasilan 30 menit langsung | 3 |
| `ad_crumbs` | Store, tab Crumbs | +5 Golden Crumbs | 5 |

**Boost ×2 (TUNABLE: `premium.ad_boost`).** Berbeda dari boost lain (Seksi 11), boost ini berjalan dengan **jam nyata**: berkurang saat bermain dan saat pergi. Ia mengalikan penghasilan di atas kopi, pencapaian, dan Golden hour. Saat kembali, bagian waktu pergi yang masih tertutup boost ikut dikali ×2 di penghasilan offline (popup Welcome Back), lalu sisa boost dipotong waktu pergi. Model offline yang tersimpan tetap tanpa boost. Chip "×2 · 3:59:12" di HUD membuka tab Boosts.

Jatah harian dihitung per perangkat (`user://monetization.json`). Pemilik No Ads atau anggota Baker's Club mendapat semua hadiah iklan tanpa menonton (tombol "· Free"); jatah harian tetap berlaku.

## **22.5 Produk Toko (TUNABLE: `monetization.products`)**

Harga di bawah adalah harga toko uji (`price_usd`); toko sungguhan memakai harga Play Console/App Store.

| Produk | Jenis | Harga | Isi |
|---|---|---|---|
| 80 / 500 / 1.200 / 2.600 / 7.000 Golden Crumbs | habis pakai | $0,99 / 4,99 / 9,99 / 19,99 / 49,99 | Golden Crumbs; paket besar memberi bonus (+24% sampai +73%), "Most popular" dan "Best value" |
| **No Ads** (dulu Supporter Pack) | tetap | $4,99 | Semua hadiah iklan tanpa menonton, badge Supporter Heart |
| **Golden Oven** | tetap | $9,99 | Semua penghasilan ×2 selamanya, di semua cabang, juga offline |
| **Night Manager** | tetap | $4,99 | Batas offline +8 jam dan penghasilan offline penuh (100%) |
| **Baker's Club** | langganan 30 hari | $6,99 | Penghasilan ×1,5, hadiah iklan tanpa iklan, +50 Golden Crumbs setiap hari kalender, batas offline +4 jam |
| **Bakery Pass Premium** | per musim | $4,99 | Jalur premium Bakery Pass musim ini (22.7) |
| **Starter Pack** | penawaran sekali | $1,99 | 300 Golden Crumbs, pakaian Golden Apron, boost ×2 4 jam ("×5 value") |
| **New Branch Pack** | penawaran sekali | $4,99 | 800 Golden Crumbs, time warp 4 jam, Golden Loaf Statue ("×4 value") |

- Pengganda Golden Oven dan Baker's Club bagian dari harga biasa (Seksi 7.2), jadi ikut model KR/s, penghasilan offline, dan rencana Auto. Batas offline dengan pembelian paling lama `premium.max_offline_hours` (24 jam).
- Hak beli tetap dan langganan milik perangkat dan kembali lewat **Restore purchases**. Membeli Club lagi memperpanjangnya 30 hari. Isi paket masuk ke save sekali (`premium.delivered`).
- Kode lama `supporter_pack` dibaca sebagai No Ads (`monetization.legacy_products`); berkas perangkat versi 1 dengan Supporter menjadi pemilik No Ads.

## **22.6 Time Warp (TUNABLE: `premium.warps`)**

Penghasilan sekian jam langsung masuk: KR/s model **tanpa boost** × detiknya, tanpa batas offline dan tanpa efisiensi (pemain membayarnya). Dihitung sebagai penghasilan (bintang Waralaba). Lewat iklan (30 menit, 3× sehari) atau Golden Crumbs: 1 jam (30), 4 jam (100), 24 jam (480). Store menyebut KR per jam saat ini dan jumlah setiap warp.

## **22.7 Bakery Pass (TUNABLE: `pass.*`)**

- **Musim = bulan kalender perangkat** ("November Pass"). 30 tingkat, 100 XP per tingkat. XP dari misi harian, cap kalender, pencapaian, seri tanpa ujung, cabang baru, dan iklan yang ditonton (tabel 22.3).
- **Jalur gratis:** Golden Crumbs kecil, time warp 30 menit setiap 5 tingkat, boost ×2 1 jam di tingkat 10 dan 20, 100 Golden Crumbs di tingkat 30.
- **Jalur premium** (dibeli per musim): 30 Golden Crumbs di kebanyakan tingkat (660 total), time warp 1 jam setiap 5 tingkat, boost ×2 4 jam di tingkat 8 dan 22, **pakaian musim** di tingkat 15 dan **dekorasi musim** di tingkat 30 (`pass.season_items`, berganti setiap bulan; barang musim yang sudah dimiliki diganti `duplicate_crumbs` Golden Crumbs).
- Hadiah diambil per tingkat atau sekaligus (**Claim all**). Saat bulan berganti, hadiah musim lama yang sudah tercapai tetapi belum diambil langsung diberikan (toast), lalu XP dan premium mulai dari nol. Membuka premium di tengah musim membuat semua hadiah premium tingkat yang sudah tercapai bisa diambil.
- Simulasi tidak membaca tanggal: GameRoot menentukan musim saat game dimuat dan saat tanggal perangkat berganti, sehingga save tes tetap tanpa jam dinding.

## **22.8 Kosmetik Premium (TUNABLE: `decorations.json`)**

Lewat jalur dekorasi yang sama (Seksi 8.8, v3.1 §72): sumber `premium` (dibeli dengan `price_crumbs`), `offer` (isi paket), dan `pass` (barang musim).

- **Pakaian pemilik** (`look`: warna celemek dan topi): Strawberry Baker, Night Owl, Matcha Chef (premium), Golden Apron (Starter Pack), Royal/Sunny/Mint Baker (Pass). Langsung dipakai saat didapat; bisa diganti di Decoration Mode tab Style atau di Store.
- **Kanopi toko** (`colors`): Mint, Lavender, Golden Awning. Kanopi (juga Striped Awning dari toko KR) adalah atap kecil selebar papan nama yang duduk di atas papan, tidak lagi selebar dinding (Seksi 20 no. 98).
- **Pintu toko** (skin `door`, `DoorFactory.THEMES`, 300-450 Golden Crumbs): Kitty Door (kusen merah muda berwajah kucing, patung kucing duduk, keset cap kaki), Puppy Door (wajah anak anjing bertelinga terkulai, tulang, patung anak anjing berkalung), Blossom Arch (sulur dan lengkung daun berbunga, pot bunga), Galaxy Gate (kusen biru malam bertabur bintang bercahaya, bulan sabit, planet bercincin), Candy Door (tiang permen tongkat, permen jeli, lolipop), Seaside Door (ombak, kerang, bintang laut, pelampung, istana pasir). Setiap skin pintu datang sepaket dengan **papan nama bertemanya** (Seksi 20 no. 101): papan merah muda bertelinga kucing dan bercap kaki, papan berbentuk tulang, papan kayu berhias untaian daun dan bunga, papan biru malam bertabur bintang bercahaya dengan bulan sabit, papan permen bergaris bertabur permen jeli, papan biru laut berombak dengan kerang dan bintang laut. Skin pintu menggantikan pintu dan papan gaya tier (Seksi 20 no. 100) dan dirayakan dengan pintu masuk lengkap di panggung 3D.
- **Dekorasi berbonus**: Golden Chandelier, Marble Rug, Neon Bread Sign (premium), Golden Loaf Statue (paket cabang), Starry Rug, Crystal Lamp, Croissant Statue (Pass). Bonusnya (+3% sampai +5% harga atau kedatangan) **berlaku selama dimiliki** di semua cabang, tanpa dibeli lagi setiap Waralaba seperti dekorasi KR.
- Semua model prosedural (Seksi 4 v3.1): lampu dan karpet memakai model yang ada dengan warna lain, patung dan papan neon adalah model baru. Papan neon memakai bahan cahaya yang sama dengan bola lampu, jadi tidak ada shader baru.
- Decoration Mode menampilkan bagian "Golden Crumbs shop" di setiap tab untuk barang premium yang belum dimiliki.

## **22.9 Store dan Penawaran**

- **Store** (lembar bawah, tombol kado di kanan atas HUD; chip Golden Crumbs di bawah bintang membuka tab Crumbs): lima tab.
  - **Offers:** penawaran berbatas waktu dengan sisa waktu, Baker's Club, Golden Oven, Night Manager, No Ads, Restore purchases.
  - **Pass:** musim, sisa hari, tingkat dan bar XP, Unlock Premium, Claim all, dan 30 baris tingkat (hadiah gratis dan premium).
  - **Crumbs:** Golden Crumbs gratis lewat iklan dan paket Golden Crumbs.
  - **Boosts:** boost ×2 (iklan atau Golden Crumbs) dengan sisa waktunya, dan time warp.
  - **Style:** kosmetik premium dengan Golden Crumbs.
  Tombol kado bertitik bila ada penawaran berjalan atau hadiah Pass yang bisa diambil.
- **Penawaran berbatas waktu** (`monetization.offers`): Starter Pack mulai saat toko pertama kali pindah ke Tier 2, New Branch Pack sesudah Waralaba pertama; masing-masing berjalan 48 jam nyata, popupnya tampil sekali (22.1), paling cepat `monetization.offer_delay_seconds` (60) detik setelah game dibuka, lalu menunggu di tab Offers. Penawaran yang sudah dibeli atau habis hilang.
- **Baker's Club:** Golden Crumbs harian diberikan otomatis saat game dibuka di hari kalender baru (toast).

## **22.11 Perayaan Pembelian**

Setiap pembelian dan hadiah toko yang berhasil dirayakan, makin besar barangnya makin meriah (skill game-feel: berlapis, berlebihan sebentar, lalu kembali tenang):

- **Barang Style** (pakaian, kanopi, dekorasi; dari Style, Decoration Mode, Bakery Pass, atau paket): layar perayaan penuh. Latar meredup gelap, sinar matahari keemasan membesar lalu berputar pelan, dan **model 3D barang aslinya** berputar di panggung kecil (pemilik yang memakai pakaian baru, pintu masuk dengan kanopi baru, atau dekorasinya; karpet dilihat dari atas, barang dinding dan papan nama mengayun). Barangnya meletup masuk dengan overshoot dan squash & stretch, disusul fanfare, confetti, ledakan kilau, dan kelip yang terus berkedip; pita judul ("New outfit!", "New storefront look!", "New decoration!") jatuh, lalu nama, bonusnya, dan tombol muncul berurutan. Dekorasi yang bisa dipasang punya tombol **Place it** yang langsung membuka Decoration Mode dengan barang itu di tangan.
- **Produk** (No Ads, Golden Oven, Night Manager, Baker's Club, Bakery Pass Premium): perayaan yang sama dengan lencana besar produknya; paket menampilkan barang di dalamnya di panggung.
- **Golden Crumbs** (paket, iklan, hadiah Pass): crumbs terbang dari tombolnya ke saldo di HUD dalam lengkung, lalu chip saldo memantul dan angkanya dihitung naik.
- **Boost ×2:** chip boost di HUD muncul dengan pantulan dan kilau. **Time warp:** hujan koin di atas saldo KR.
- Toast menunggu selama layar perayaan terbuka. **Reduce motion:** semuanya langsung tampil tanpa gerak, partikel, atau crumbs terbang.

## **22.10 Privasi**

Game tetap tanpa telemetri sendiri. Iklan dan pembelian ditangani SDK platform, yang mengumpulkan datanya sendiri; build Android dan portal memerlukan kebijakan privasi (bisa di GitHub Pages) dan persetujuan pengguna sesuai aturan platform. Toko uji tidak memakai jaringan sama sekali.

---

# **23. Umur Permainan Panjang**

Permintaan maintainer 2026-11-05 (Seksi 19 no. 20): pemain harus punya alasan kembali selama berminggu-minggu. Putaran pertama dan target Seksi 1.4 tidak berubah; yang ditambah adalah tangga jangka panjang sesudah Waralaba pertama.

## **23.1 Harga Cabang Mengikuti Bintang (TUNABLE: `prestige.branch_cost_base`, `prestige.branch_cost_power`, `prestige.branch_cost_start`)**

Cabang ke-2 masih memakai harga katalog, supaya Waralaba pertama terasa sebagai lompatan (Seksi 1.4: putaran ke-2 ≤ 70%). Mulai cabang ke-`branch_cost_start` (3), **biaya pindah lokasi** dikalikan `max(1, branch_cost_base × pengali_bintang ^ branch_cost_power)`, dengan pengali_bintang = (1 + `income_per_star` × bintang) × Legacy (Seksi 23.2). Level stasiun, kasir, resep, staf, dan upgrade global, buka stasiun, buka resep, rekrut, dekorasi, harga jual, dan promosi tetap memakai harga katalog. Layar Waralaba menyebut pengali biaya lokasi cabang berikutnya.

Keputusan maintainer 2026-11-10 (Seksi 19 no. 23, Seksi 20 no. 89): dulu pengalinya `branch_cost_growth^(n − start + 1)` (×1,5 per cabang). Biaya itu tumbuh eksponensial sementara bintang hanya menambah penghasilan secara linear, jadi setiap cabang makin lama (diukur 56, 37, 66, 75, 79, 95 menit untuk cabang 3–8) dan permainan tanpa ujung lama-lama mentok. Kini harga mengikuti pengali bintang, sehingga lama satu cabang tetap sama selamanya; bonus kota (23.5), mastery (23.3), dan roti khas (23.6) tetap mempercepat karena tidak ikut menaikkan harga.

## **23.2 Perk Lanjutan**

| ID | Bintang | Efek |
|---|---:|---|
| `perk_offline_long` | 750 | Batas offline +3 jam |
| `perk_mandiri_start` | 1.000 | Putaran baru mulai di Tier 3 (Toko Mandiri) |
| `perk_coffee_long` | 1.500 | Kopi Pak Lurah (juga isi ulangnya) berlangsung 2× lebih lama |
| `perk_milestone_quad` | 2.500 | Milestone resep ×4 |
| `perk_golden_rain` | 5.000 | Roti emas muncul 2× lebih sering |

**Legacy (tanpa ujung, TUNABLE: `prestige.legacy_*`, Seksi 20 no. 90).** Sesudah perk terakhir, setiap `legacy_every_stars` (1.000) bintang di atas `legacy_after_stars` (5.000) menaikkan level Legacy satu, dan setiap level mengalikan semua penghasilan dengan 1 + `legacy_income` (×1,1). Layar Waralaba menampilkan level Legacy dan bintang untuk level berikutnya.

## **23.3 Mastery Resep (TUNABLE: `mastery.*`)**

- Setiap resep mengumpulkan **roti terjual sepanjang masa** (semua cabang, toko dan RotiFood). Hanya roti yang benar-benar terjual selama bermain yang dihitung; penghasilan offline berupa KR saja dan tidak menambah mastery, jadi mastery adalah hadiah untuk bermain aktif.
- **Bintang mastery 1–5** pada `mastery.thresholds` (10K, 50K, 150K, 400K, 1M roti: bintang pertama resep utama kira-kira di akhir putaran pertama, sehingga pacing Seksi 1.4 tidak berubah); setiap bintang menambah harga jual resep itu sebesar `mastery.price_bonus_per_level`, permanen (tidak direset Waralaba).
- Harga mastery bagian dari harga biasa (Seksi 7.2), jadi ikut model KR/s, penghasilan offline, dan pilihan Auto.
- **Tanpa ujung** (Seksi 20 no. 90): sesudah ambang terakhir, setiap bintang berikutnya butuh `mastery.endless_factor` (2,5) kali roti ambang sebelumnya (2,5 juta, 6,25 juta, dan seterusnya), dan setiap bintang tetap menambah bonus harganya.
- Tampil di layar Menu (bintang dan progres ke bintang berikutnya); naik bintang memberi toast.
- Memberi alasan jangka panjang untuk menjual resep lain (craving, roti favorit lokasi).
- Save: field `mastery` (`sold` per resep), dimiliki `MasteryManager`.

## **23.4 Seri Pencapaian Tanpa Ujung (TUNABLE: `endless.series`)**

Pencapaian katalog (Seksi 11.4) berhenti di 1T KR, 10K roti, dan 10 Waralaba. Tiga seri melanjutkannya tanpa batas (Seksi 20 no. 90): hasilkan 10^15 KR lalu ×1.000, jual 100K roti lalu ×10, buka 25 cabang lalu ×2. Setiap target yang terlewati menaikkan level seri, memberi boost pencapaian ×2 seperti pencapaian biasa, dan diumumkan dengan toast; lompatan besar melewati beberapa level sekaligus. Lembar Stats (tab Achievements) menampilkan level dan target berikutnya setiap seri.

## **23.5 Bonus Kota (TUNABLE: `town.*`)**

Peta Crumbtown menjadi lapisan meta (Seksi 20 no. 91): setiap cabang, termasuk yang sedang dimainkan, menyumbang `town.bonus_by_tier[tier tertingginya]` (Tier 3 +1%, Tier 4 +2%, Tier 5 +4%) ke penghasilan semua cabang, paling banyak `town.max_bonus` (+60%). Kota baru ada sesudah Waralaba pertama, jadi putaran 1 tidak berubah. Cabang yang dijual saat macet di Tier 3 atau 4 karena itu layak dikunjungi lagi untuk dibawa ke Tier 5. Peta menampilkan bonus kota dan aturannya, halaman cerita setiap cabang menyebut sumbangannya, dan layar Waralaba menyebut bonusnya.

## **23.6 Roti Khas dan Wajah Lingkungan per Cabang (TUNABLE: `branch.signature_mult`)**

Supaya setiap cabang terasa berbeda (Seksi 20 no. 92):
- **Roti khas (Signature):** setiap cabang sejak cabang ke-2 mendapat satu resep khas, tetap per save (benih utama) dan nomor cabang, tidak pernah sama dengan cabang sebelumnya, yang dijual `branch.signature_mult` (×1,3) di cabang itu. Lembar Menu memberinya pil "Signature" dan menyebutnya di kartu craving; halaman cerita cabang di peta juga.
- **Wajah lingkungan:** cabang 1 memakai warna jalan aslinya; cabang lain memutar warna dinding, papan nama, dan kanopi bangunan tetangga (bentuk dan letaknya sama, jadi jalan tetap tidak menutupi toko). Gambar toko di peta juga memutar warna kanopinya per cabang.
