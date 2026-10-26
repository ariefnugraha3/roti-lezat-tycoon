# **Roti Lezat Tycoon — GDD Idle Arcade v1.0 (DRAFT)**

> **Status:** rancangan 2026-10-25; ke-13 keputusan Seksi 19 dikonfirmasi maintainer dan implementasi dimulai 2026-10-26 di branch `pivot-to-idle-game` (catatan implementasi di Seksi 20).
> **Peran dokumen:** GDD ini mengubah Roti Lezat Tycoon dari tycoon manajemen harian menjadi **game idle arcade**. Untuk semua hal yang diatur di sini, dokumen ini menggantikan GDD v3.1 (`docs/gdd-roti-lezaat-tycoon-ai-ready-v3.1-final.md`). Hal yang tidak disebut di sini tetap mengikuti v3.1 (Seksi 0.1).
> **Engine lock tetap:** Godot 4.7-stable Standard, GDScript, renderer Compatibility, 100% aset prosedural, teks pemain berbahasa Inggris (v3.1 §4, §43, §96, §111, §127, §128).
> **Nilai bertanda TUNABLE** adalah nilai awal. Semuanya hidup di katalog `data/catalog/idle.json` (Seksi 15.2) dan disetel dengan probe pacing (Seksi 17, fase P7).

---

# **0. Cara Membaca Dokumen Ini**

## **0.1 Hubungan dengan GDD v3.1**

| Status | Bagian v3.1 | Catatan |
|---|---|---|
| **Tetap berlaku** | §4 art direction, §12.2–12.4 rendering & kontrol; §17 grid & navigasi; §28.2 aturan tumpukan modal; §29 input; §30 kamera (kecuali §30.1, lihat Seksi 12.0.4); §31 visual karakter; §32 perabot, interior, lingkungan, kehidupan jalan; §33 kebijakan audio; §34/§77/§106 mekanisme save atomik & 3 profil; §35 arsitektur dasar; §37 & §109 (termasuk §109.3 MeshBake) performa; §43/§127 teks Inggris; §44 aksesibilitas; §57/§60 template layout & dimensi perabot; §68 portal lantai; §72 Decoration Mode; §96–§101 kontrak teknis; §111 asal aset; §115–§117 cache, RNG, logging; §128–§130 toolchain, batas runtime, spesifikasi visual | Dipakai apa adanya kecuali disebut lain di dokumen ini |
| **Diubah** | §1–§3 overview, loop, ekonomi; §5 equipment; §6/§64 lokasi; §7/§28.1 UI; §12.5 orientasi & ponsel, §28.4 breakpoint, §30.1 kamera gameplay, §110 matriks resolusi (semuanya menjadi potret, Seksi 12.0); §8/§48 pemasaran; §9/§25 rating; §15 state & waktu; §16 karakter; §18 produksi; §19 roti & rak; §20 pelanggan; §21 kasir; §22 RotiFood; §23/§87 staf; §24 ekonomi & ledger; §26 cuaca; §27/§88 tutorial; §61/§63 resep & harga; §74/§92/§118 pencapaian; §89 menu utama; §90/§112/§113 lifecycle & offline | Aturan baru ada di seksi terkait dokumen ini |
| **Dihapus** | §18.7 & §62 oven gosong; §19.7–§19.9 kesegaran & roti basi; §20.3 manifest Hari 1–3; §11 & §46 Daily Summary; §15.4 Skip to Open; §15.5 Close Early; §71 kecepatan 2×/3× & Smart Speed; §21.4 kasir manual (popup + OK); §22.5 kemas manual & §22.10 tolak pesanan; §5.2, §24A, §70 pasar bahan & kurir; §5.1.2 beli/ganti/jual alat; §63.2 harga manual; §24.5/§86 utilitas; §24.6/§3.3 gaji; §3.0/§49 bangkrut, talangan, Mode Solo; §104 shutdown 18:00; Ask a Baker | Tidak ada mode lama. Kode dan tesnya ikut dihapus saat implementasi |

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

Genre *idle arcade / hybrid-casual tycoon*. Stasiun di-upgrade per level, manager atau asisten mengotomatiskan stasiun, penghasilan offline, lalu pindah lokasi atau prestige untuk pengali yang lebih besar. Referensi genre (bukan untuk ditiru asetnya): Eatventure, My Perfect Hotel, Idle Miner Tycoon. Game ini tetap **offline penuh**, tanpa iklan, IAP, login, server, atau notifikasi push (v3.1 §112 kecuali larangan progres offline).

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

1. New Game: pilih karakter dan nama toko seperti di v3.1 §89. Toko langsung berjalan, tanpa layar persiapan.
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
  4. Bila tidak ada pekerjaan: animasi idle v3.1 §31.6–§31.7 (gelembung pikiran, tertidur).
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
                           × reputation_mult × decor_arrival_mult × boost_arrival_mult
                           × night_mult × weather_mult × holiday_mult
```

- `base_arrivals` per tier lokasi (TUNABLE): **24 / 32 / 42 / 54 / 70** per jam in-game.
- Kedatangan tetap berupa proses Poisson memakai stream RNG v3.1 §116. Pembeli tetap berjalan dari ujung trotoar (v3.1 §20.1) dan diterima hanya bila ada slot antrean (v3.1 §57.6).
- Arketipe pelanggan v3.1 §20.11 tetap ada untuk variasi tampilan dan jumlah beli. Aturan sensitivitas harga dihapus karena harga tidak lagi disetel pemain.

## **6.2 Pembelian**

- Pembeli memilih resep di antara petak yang berisi, berbobot preferensi arketipe (v3.1 §20.11 tag) × harga relatif. Jumlah beli mengikuti v3.1 §84.1.
- Bila tidak ada roti sama sekali, pembeli pulang. Itu penjualan yang hilang, tanpa denda selain reputasi (Seksi 6.6).

## **6.3 Antrean & Kasir**

Jalur, antrean, dan penyeimbangan mengikuti v3.1 §21.1–§21.3. Transaksi otomatis berlangsung `checkout_seconds` (Seksi 8.2) dengan animasi membungkus v3.1 §21.4. Tidak ada popup pesanan dan tidak ada tombol OK.

## **6.4 Kesabaran**

Kesabaran dan bar kesabaran v3.1 §20.8 dan §58 tetap ada. Pembeli yang kesabarannya habis meninggalkan antrean dan mengembalikan rotinya ke rak. Hilangnya penjualan dan reputasi sudah cukup sebagai akibat.

## **6.5 RotiFood Otomatis**

- Pesanan datang sepanjang hari: `rotifood_orders_per_hour(tier)` (TUNABLE: **3 / 4 / 6 / 8 / 10**) × `night_mult` × weather (hujan ×1,5) × boost.
- Pesanan **diterima otomatis**. Stok dipesan dari rak saat pesanan datang bila tersedia, lalu dikemas otomatis oleh pemilik atau kasir yang menganggur.
- Bila stok belum ada, pesanan menunggu. Driver datang dan menunggu dengan kesabaran v3.1 §22.6. Bila habis, pesanan batal tanpa denda selain reputasi.
- Harga pesanan = harga jual × `rotifood.price_mult` (TUNABLE **1,1**). Tidak ada tolak pesanan dan tidak ada tip.

## **6.6 Reputasi**

- Dua rating v3.1 digabung menjadi satu **Reputasi** ★ 1,0–5,0, ID `reputation`.
- Setiap pembeli atau pesanan yang terlayani: +`reputation.served_delta` (0,01). Setiap yang pergi tanpa terlayani: −`reputation.lost_delta` (0,03). Nilai dibatasi 1–5. Mulai di 3,0.
- `reputation_mult = 0.6 + 0.2 × reputation` (★1 = ×0,8; ★5 = ×1,6).

## **6.7 Tetap Ada (Kosmetik)**

Pengunjung lihat-lihat (v3.1 §20.12), kejutan (§31.9), kehidupan jalan, cuaca visual, dan dekorasi hari libur (§32.6–§32.10), serta celetukan dan gestur staf (§31.6, §31.8) tetap ada tanpa perubahan.

---

# **7. Ekonomi**

## **7.1 Mata Uang**

| Mata uang | Didapat dari | Dipakai untuk | Reset saat Waralaba |
|---|---|---|---|
| **KR** | Penjualan, RotiFood, penghasilan offline, hadiah | Upgrade, staf, lokasi, dekorasi, promosi | Ya, kembali ke `start_kr` |
| **Bintang Waralaba** | Waralaba (Seksi 10) | Pengali pasif & perk (tidak dibelanjakan) | Tidak |

`start_kr` = **50** (TUNABLE). Tidak ada mata uang premium.

## **7.2 Harga Jual per Roti**

```text
unit_price = base_sell_price_kr(recipe)              # recipes.json
             × recipe_price_mult(recipe_level)       # Seksi 8.5
             × (1 + display_price_bonus(shelf_level)) # Seksi 8.2
             × decor_price_mult × franchise_mult × boost_income_mult
```

`franchise_mult = 1 + prestige.income_per_star × franchise_stars` (Seksi 10.3). `boost_income_mult` dari Seksi 11.

## **7.3 Tanpa Biaya Berjalan**

Gaji, utilitas, sewa, dan talangan dihapus. Satu-satunya pengeluaran otomatis adalah biaya bahan batch (Seksi 4.4). Saldo tidak pernah di bawah 0.

## **7.4 Ledger**

Ledger v3.1 §24.1 tetap ada. Kategorinya kini: `SALE_PHYSICAL`, `SALE_ROTIFOOD`, `OFFLINE_EARNINGS`, `GIFT`, `INGREDIENT_COST`, `UPGRADE_STATION`, `UPGRADE_RECIPE`, `RECIPE_UNLOCK`, `STATION_OPEN`, `STAFF_HIRE`, `STAFF_UPGRADE`, `LOCATION_UPGRADE`, `DECOR_PURCHASE`, `PROMO`, `GLOBAL_UPGRADE`, `FRANCHISE_RESET`. Statistik menyimpan `run_earned_kr` dan `alltime_earned_kr`; hanya pemasukan yang dihitung, bukan pengeluaran.

## **7.5 Angka Besar**

- Format `Tx.big(n)`: < 10.000 ditulis utuh dengan pemisah ribuan ("9,850"). Di atasnya 3 angka penting dengan akhiran: K (10³), M (10⁶), B (10⁹), T (10¹²), lalu aa, ab, …, az, ba, … (10¹⁵, 10¹⁸, …). Contoh: "12.4K", "3.07M", "118aa".
- Pengaturan "Number format: Short / Scientific" (scientific: "1.24e15").
- Semua nilai uang memakai float 64-bit. Penjaga overflow v3.1 §73 tetap berlaku.

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

Upgrade lokasi menjalankan migrasi v3.1 §105, yang pindah ke lokasi baru dengan dekorasi diangkat dulu. Level stasiun yang sudah ada dan level resep dipertahankan, dan batas level naik. Stasiun lama ditempatkan otomatis dan slot baru bisa dibuka (Seksi 8.4).

## **8.8 Dekorasi Berbonus**

Setiap dekorasi v3.1 §72.1 mendapat satu bonus permanen selama putaran (field katalog baru `bonus` = `{type: arrival|price|rotifood, value}`), misalnya pot tanaman +2% kedatangan atau papan menu kapur +3% harga. Bonus sejenis dijumlahkan: `decor_arrival_mult = 1 + Σ arrival`. Harganya diskalakan per tier lokasi (`decor.price_mult_by_tier`, TUNABLE 1 / 20 / 400 / 8.000 / 160.000). Skin storefront tetap kosmetik.

## **8.9 Upgrade Global ("Toko")**

| ID | Efek per level | Batas | base / growth (TUNABLE) |
|---|---|---|---|
| `global_offline_hours` | Batas offline +1 jam | +6 | 2K / 12 |
| `global_offline_efficiency` | Efisiensi offline +5% | +10 | 5K / 6 |
| `global_tap_power` | `tap_power` +25% | 20 | 500 / 3 |
| `global_walk_speed` | Pemilik & staf +5% jalan | 10 | 1K / 4 |
| `global_queue_patience` | Kesabaran pembeli +5% | 10 | 2K / 4 |

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

"Welcome back! You were away for {time}. Your bakery earned {amount}." disertai tombol **Collect**, animasi hujan koin, dan sapaan Pak Lurah. Pengganda penghasilan tidak dijual, karena tidak ada iklan maupun IAP.

---

# **10. Prestige: Waralaba**

## **10.1 Syarat**

Lokasi Tier 3 sudah dicapai di putaran ini dan Waralaba akan memberi ≥ 1 bintang baru.

## **10.2 Bintang**

```text
stars_total(E) = floor( (alltime_earned_kr / prestige.stars_divisor_kr) ^ prestige.stars_exponent )
stars_gained   = stars_total − franchise_stars
```

Nilai default `stars_divisor_kr` = 1e6 dan `stars_exponent` = 0,5 (TUNABLE). Layar Waralaba menampilkan jumlah bintang yang akan didapat bila menjual sekarang, dan KR yang dibutuhkan untuk bintang berikutnya.

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

## **10.5 Reset**

| Direset | Disimpan |
|---|---|
| KR (ke `start_kr` + perk), lokasi (ke Tier 1 atau 2), stasiun tambahan & semua level stasiun, level dan buka resep (kecuali perk), staf, dekorasi berbonus (kembali ke inventaris, bonusnya tidak aktif sampai dibeli lagi di putaran baru), upgrade global level 1–5, boost aktif, reputasi (ke 3,0) | Bintang Waralaba, perk, `alltime_earned_kr`, statistik, pencapaian dan badge, skin storefront dan pakaian, nama toko, karakter, pengaturan, nomor putaran (`run_index`) |

Upgrade global di atas level 5 tetap disimpan, sebagai rasa "lebih kuat" lintas putaran.

## **10.6 Alur**

Layar Waralaba → tombol **Sell & Franchise** → konfirmasi → cutscene Pak Lurah (mekanisme v3.1 §45): investor membeli toko, papan nama baru → loading → garasi baru dengan nama toko yang sama dan "Branch #{run_index}". Autosave kritis sebelum dan sesudah reset.

---

# **11. Boost & Hadiah**

## **11.1 Kopi Pak Lurah (Hadiah Harian)**

Sekali per **hari kalender perangkat**: ×2 penghasilan selama 15 menit nyata (TUNABLE). Boost hanya berjalan selama bermain aktif; sisanya disimpan dan tidak berlaku saat offline.

## **11.2 Promosi (dulu Kampanye Pemasaran)**

| ID | Efek | Durasi nyata | Biaya | Jeda |
|---|---|---|---|---|
| `promo_flyer` | Kedatangan ×1,5 | 5 menit | 3 menit penghasilan (`rate × 180`) | 10 menit |
| `promo_radio` | Kedatangan ×2 | 10 menit | 8 menit penghasilan | 30 menit |
| `promo_food_vlogger` | Kedatangan ×2, RotiFood ×2 | 10 menit | 15 menit penghasilan | 60 menit |

Biaya diskalakan dengan KR/s saat itu supaya promosi selalu relevan. Food Vlogger dari v3.1 menjadi promosi ini. Semua angka TUNABLE.

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
- **Splash dan Main Menu:** logo di sepertiga atas, tombol bertumpuk vertikal, `CozyBackdrop` (dengan taplak di tepi bawah) tetap menjadi latar di dalam bingkai.
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
- **Kanan atas:** Reputasi ★, Bintang Waralaba, tombol pause/pengaturan.
- **Bawah, bar tombol:** Upgrades · Menu · Staff · Shop · Decor · Franchise. Setiap tombol diberi titik hijau bila ada sesuatu yang terjangkau di dalamnya.
- **Dunia:** chip level kecil di atas setiap stasiun ("Lv 12"), dengan panah naik yang berdenyut bila upgrade ×1 terjangkau. Chip adalah kontrol 2D yang diproyeksikan, dengan target sentuh ≥ 48 px (v3.1 §12.4).
- Tidak ada lagi jam fase, tombol kecepatan, Skip to Open, Close Early, panel stok, atau panel pesanan RotiFood. Jam kecil tetap ada untuk suasana.

## **12.2 Kartu Upgrade Stasiun**

Dibuka dengan mengetuk chip level (mengetuk stasiun = Semangat). Kartu melayang di atas stasiun seperti toolbar Decoration Mode (v3.1 §72.2):

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

Menu utama, profil, pengaturan, pause, bantuan, dan loading mengikuti v3.1 §89 dengan teks baru.

## **12.4 Layar yang Dihapus**

Market (semua tab), Recipe Book lama, Customer Order popup, RotiFood popup & reject confirm, Display Detail (buang roti), Daily Summary, Marketing (diganti Promosi di Upgrades), ReplacePicker, layar Skip/Close Early, Solo Mode, cutscene bangkrut, overlay "Rotate your phone".

## **12.5 Umpan Balik**

Koin melompat dari kasir saat transaksi, angka mengambang "+{amount}" (dikelompokkan bila banyak), kilau level-up, ledakan konfeti kecil saat milestone, efek "evolusi" saat model alat berganti tier, dan pulsa hijau pada tombol bar bila sesuatu terjangkau. Reduced Motion mematikan lompatan dan konfeti (v3.1 §44).

---

# **13. Onboarding**

Menggantikan tutorial Hari 1–3 v3.1 (§27, §88). Durasinya sekitar 3 menit dan **tidak pernah menahan ekonomi**. Spotlight memakai `TutorialSpotlight`/`CoachMarks` yang ada, dan setiap langkah bisa ditutup.

| Langkah | Pemicu | Isi |
|---|---|---|
| `onb_welcome` | Mulai | Pak Lurah: "Your bakery runs itself. Watch your first bread sell!" |
| `onb_first_sale` | Penjualan pertama | Spotlight KR dan KR/s |
| `onb_first_upgrade` | Upgrade oven terjangkau | Chip oven berdenyut, lalu kartu upgrade disorot |
| `onb_tap_boost` | Setelah upgrade pertama | "Tap a working station to speed it up!" |
| `onb_hire` | KR ≥ biaya rekrut pertama | Tombol Staff berdenyut, rekrut Asisten Dapur |
| `onb_recipe` | KR ≥ biaya buka resep kedua | Menu: buka resep dan tetapkan ke petak |
| `onb_offline` | Kunjungan kedua | Popup Selamat Datang dijelaskan sekali |
| `onb_location` | Lokasi Tier 2 terjangkau | Tombol Shop berdenyut |
| `onb_franchise` | Waralaba pertama kali tersedia | Layar Waralaba dijelaskan |

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
| **Diubah** | `ReputationManager` | Satu reputasi (Seksi 6.6) |
| **Diubah** | `EconomyManager` | Kategori ledger Seksi 7.4; tanpa gaji, utilitas, talangan |
| **Diubah** | `TutorialManager`, `AchievementManager`, `StatisticsManager` | Seksi 13, 11.4, 12.3 Stats |
| **Dihapus** | `SupplyOrderManager`, `InventoryManager` (stok bahan), `PricingManager` (harga manual), `BailoutManager`, `DayReportManager`, `AnalyticsManager` (diganti Stats) | Beserta UI dan tesnya |

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
  "reputation": {"start": 3.0, "served_delta": 0.01, "lost_delta": 0.03, "mult_base": 0.6, "mult_per_star": 0.2},
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

- Tiga profil dan tulis atomik v3.1 §34/§106 tetap. Root save baru: `"game_mode": "idle"`, `"schema_version": 1` (skema idle mulai dari 1).
- Field baru: `upgrades` (level per instance, resep, staf, global), `recipes_unlocked`, `slot_recipes` (resep per petak), `franchise` (`stars`, `run_index`, `perks`), `offline` (`last_active_unix`, `rate_kr_per_s`), `boosts` (aktif dan sisa detik, hadiah harian terakhir), `stats` (`run_earned_kr`, `alltime_earned_kr`, `offline_seconds_total`, dll.), `reputation`.
- Field dihapus: kesegaran stack, kualitas, `inventory`, `supply_orders`, `pricing`, `bailout`, `reports`, manifest, wage liability.
- **Save v3.1 (tycoon) tidak didukung.** Main Menu menampilkannya sebagai "Classic save (not supported)" dengan tombol Delete. Tidak ada migrasi.

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
| 1 | Nama game tetap **Roti Lezat Tycoon** | Ganti nama, misalnya "Roti Lezat Idle" |
| 2 | Toko **buka 24 jam** dengan kedatangan malam ×0,4 | Toko tutup malam (penghasilan berhenti, offline tetap dihitung) |
| 3 | **Meja Tunggu** dipertahankan sebagai penampung tanpa busuk | Dihapus dari semua layout |
| 4 | Bintang Waralaba **pasif + perk milestone**, tidak dibelanjakan | Pohon perk yang dibeli dengan bintang |
| 5 | **Tombol kecepatan 2×/3× dihapus**; percepatan lewat Semangat dan boost | Tetap ada |
| 6 | Dua rating digabung menjadi **satu Reputasi** | Tetap dua rating |
| 7 | **Save tycoon lama tidak didukung** (hanya bisa dihapus) | Konversi kasar ke idle (misalnya KR → modal awal) |
| 8 | Bahan dibayar otomatis saat batch dimulai; **Pasar dihapus** | Bahan gratis |
| 9 | Kejutan, pengunjung lihat-lihat, dan kehidupan jalan tetap kosmetik | — |
| 10 | Bingkai potret dijepit **9:16 sampai 9:21**: HP modern mengisi layar penuh tanpa taplak; layar yang lebih lebar mendapat taplak di sisi | Selalu tepat 9:16 (HP panjang juga mendapat pita taplak di atas dan bawah) |
| 11 | Taplak sisi = gingham penuh + renda di tepi bingkai + ikon samar melayang dari `CozyBackdrop` | Gingham polos tanpa renda dan ikon, atau seluruh `CozyBackdrop` (latar krem dengan taplak hanya di bawah) |
| 12 | HP yang dimiringkan tetap bisa main (bingkai kecil + petunjuk sekali), tanpa layar pemblokir | Layar pemblokir "Rotate your phone" versi potret |
| 13 | Jendela desktop/editor dibuka 540 × 960 | Ukuran lain |

Pertanyaan terbuka lain: lisensi proyek (masih terbuka sejak v3.1).

---

# **20. Catatan Implementasi**

Keputusan kecil yang diambil saat implementasi karena dokumen ini tidak merincinya. Semuanya bisa diubah maintainer; nilai angkanya hidup di `data/catalog/idle.json`.

| No | Topik | Keputusan |
|---|---|---|
| 1 | P0, model pacing analitik | Model kasar (skrip di luar repo) menunjukkan nilai awal tumbuh jauh lebih cepat dari target Seksi 1.4 dan membuat resep kedua kalah menarik dari level resep. Penyetelan akhir dilakukan di P7 dengan probe simulasi hidup (`tools/idle_probe.tscn`). |
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
| 32 | Boost yang bertemu | Boost penghasilan (kopi, hadiah pencapaian) tidak menumpuk pengali: yang baru menambah sisa waktu, dengan pengali terbesar. Promosi berjalan satu per satu, dan jedanya dihitung sejak promosi dimulai. Semua timer memakai detik nyata permainan aktif, jadi berhenti saat pause, di latar, dan offline. Waralaba mereset boost dan jeda, tetapi kopi hari itu tetap sudah diambil. |
| 33 | Kopi Pak Lurah | Diberikan otomatis saat profil dimuat atau aplikasi kembali ke depan pada hari kalender perangkat yang baru, dengan toast `ui_daily_gift` dan `welcome_back_chime`; tidak ada tombol klaim. |
| 34 | Promosi di Upgrades | Bagian "Promotions" di atas "Best value first": efek, lama, dan tombol "Start · {biaya}", atau sisa waktu berjalan / jeda. Biaya = KR/s model tanpa boost × `cost_income_minutes` × 60, paling sedikit 1 KR. Chip HUD di bawah KR/s menunjukkan boost penghasilan dan promosi beserta sisa waktunya. |
| 35 | Bonus dekorasi | Bonus aktif sejak dibeli (tidak perlu dipasang) dan setiap jenis dekorasi memberinya sekali per putaran; dekorasi berbonus yang sudah aktif tidak dijual lagi di putaran itu. Dekorasi berbonus milik putaran lalu dinyalakan lagi dengan membelinya tanpa menambah salinan. Nilai awal (TUNABLE, `decorations.json`): pot tanaman dan gorden +2% kedatangan, radio dan kotak bunga +3%, karpet +4%; jam dinding +2% harga, papan menu dan keranjang roti +3%, lampu gantung +4%; foto keluarga +5% RotiFood. Harga toko, termasuk skin, dikali `decor.price_mult_by_tier`. |
| 36 | Pencapaian idle | 20 pencapaian: roti terjual 1 / 100 / 10K, total penghasilan 1K / 1M / 1B / 1T, Tier 2–5, rekrut pertama, stasiun Lv 100, resep Lv 100, semua resep dibuka, 100 pesanan RotiFood, 1 jam offline, Waralaba pertama dan ke-10, overflow. Hadiah v3.1 dipakai ulang; pencapaian "punya saldo" v3.1 menjadi "total penghasilan". Boost hadiah ×2 selama 10 menit mengikuti aturan no. 32. |
| 37 | Pemicu onboarding | Diperiksa tiap 0,5 detik-simulasi. Sapaan pembuka berupa popup Pak Lurah, penjualan pertama berupa sorotan KR dan KR/s, sisanya petunjuk di atas bar tab dengan tombol tab (atau chip oven) yang berdenyut. Petunjuk upgrade, rekrut, resep, dan lokasi menutup sendiri setelah dikerjakan. `onb_hire` muncul segera setelah penjualan pertama karena `start_kr` sudah cukup untuk rekrutan pertama. `onb_offline` adalah petunjuk yang muncul bersama Welcome Back pertama. Popup tutorial memakai potret Pak Lurah. |
| 38 | Model tanpa boost | Toko contoh `ACC_IDLE_MODEL_MATCH` menandai semua pencapaian sudah didapat (tanpa hadiah) dan menghentikan boost, karena model offline sengaja tanpa boost (Seksi 9.1). |

