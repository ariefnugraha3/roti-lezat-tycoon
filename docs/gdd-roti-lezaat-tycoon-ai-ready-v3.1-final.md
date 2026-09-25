# **Roti Lezat Tycoon: Game Design Document — AI-Ready Production Specification v3.1 FINAL**

> **FINAL IMPLEMENTATION STATUS — v3.1**
> This document is the sole authoritative specification for *Roti Lezat Tycoon* v1.0. Older GDD versions are obsolete and must not be used as implementation authority. All active requirements are canonical.


> **Document Edition:** AI-Ready Production Specification v3.1 FINAL  
> **Purpose:** Dokumen ini adalah source of truth desain + implementasi untuk membangun *Roti Lezat Tycoon* secara otonom dengan AI coding agent.  
> **Engine Lock:** **Godot Engine 4.7-stable Standard + GDScript only + Compatibility renderer.**  
> **Rule:** Seluruh keputusan v1.0 dianggap final kecuali sebuah nilai secara eksplisit diberi label **TUNABLE**. AI implementor dilarang membuat mekanik baru, menghapus edge case, atau mengganti aturan karena alasan kemudahan implementasi. Seksi **96–135** adalah hard implementation contract. Kontradiksi aktif antar-seksi adalah validation failure (Seksi 13.4); urutan authority saat mencari jawaban mengikuti Seksi 126.2.

Dokumen ini merinci visi strategis, mekanik mendalam, dan arah artistik untuk Roti Lezat Tycoon, sebuah simulator manajemen bisnis toko roti yang menggabungkan kemudahan bermain dengan strategi ekonomi yang menantang.

# **1\. Game Overview**

Roti Lezat Tycoon adalah game simulasi manajemen di mana pemain membangun kerajaan kuliner dari sebuah gerai kecil di garasi hingga menjadi jaringan bakery kelas dunia yang mendominasi pasar.

* Genre: Tycoon / Business Simulation.  
* Game Engine: **Godot Engine 4.7-stable Standard** (GDScript only; Compatibility renderer).  
* Target Platform Utama:  
  * **Web Browser**: itch.io (HTML5 / WebGL)  
  * **Mobile**: Android (Google Play Store)  
* **Setting Waktu & Nuansa**: **Dunia Modern Tahun 2026 dengan Jiwa Nostalgia Tahun 2000**. Game berlatar di era masa kini (2026)—di mana ekosistem digital seperti smartphone pesanan daring dan kurir pengantaran online (**Ojek Online / Delivery**) menjadi bagian alami dari keseharian bisnis toko roti—namun visual, musik, dan ritme permainannya dibalut atmosfer retro-comfort, kedamaian, dan kehangatan Minggu sore yang mengingatkan pada era tahun 2000 yang damai.
* **Tema & Suasana Utama**: Kewirausahaan kuliner dengan sentuhan nostalgia yang mendalam:
  * **Warm**: Sehangat aroma roti yang baru matang dari oven.
  * **Cozy**: Sesantai suasana Minggu sore yang damai di era tahun 2000-an.
  * **Cute**: Semanis dan selembut roti manis kesukaan anak-anak.
* **Karakter Pemain**: Pemain memilih satu karakter—**Pria** atau **Wanita**—saat menekan tombol **New Game**. Karakter inilah yang berjalan sendiri di dalam toko: mengambil bahan dari gudang, mengoperasikan mixer dan oven, menata roti ke rak, dan berjaga di meja kasir. Pilihan ini murni penampilan (gaya rambut, penutup kepala, warna celemek); ia tidak memengaruhi kecepatan kerja maupun ekonomi sedikit pun.
* **Mata Uang Fiksi In-Game**: **Koin Roti** (disingkat **KR**, simbol: 🪙). Seluruh transaksi ekonomi—mulai dari penjualan roti, pembelian bahan baku di pasar, gaji karyawan, hingga biaya ekspansi toko—menggunakan satuan mata uang fiksi ini.
* **Saldo Awal New Game (Canonical):** Pada **Hari 1**, pemain memulai permainan dengan **1.000 KR**. Saldo ini harus sudah terlihat di HUD sejak gameplay pertama dimulai. Bahan tutorial Hari 1–3 tetap mengikuti scripted onboarding dan tidak perlu dibeli dari saldo awal tersebut.

# **2\. Core Gameplay Loop**

Siklus permainan utama terbagi dalam tiga tahap operasional harian:

*Kecepatan jam:* **1 jam in-game = 3 menit nyata**, sehingga satu hari penuh (05:00–18:00) berlangsung **39 menit nyata**—9 menit persiapan dan 30 menit jualan. Seluruh arus yang ditulis "per jam" (kedatangan pembeli, pesanan RotiFood) mengikuti jam in-game, jadi jumlah pembeli **per hari** tidak berubah; yang berubah adalah berapa lama pemain punya waktu untuk melayani mereka.

**1\. Tahap Persiapan (05:00 – 08:00)**

Pemain tidak menekan tombol di menu untuk berproduksi—ia menggerakkan **karakternya** langsung di dalam toko. Seluruh produksi berjalan sebagai rantai ketukan, **satu ketukan per perabot**:

1. **Ketuk Gudang Penyimpanan** → karakter berjalan ke sana, pintu kulkas dan lemarinya berayun terbuka, lalu **Buku Resep** muncul.
2. **Pilih resep dan jumlah batch** (x1 / x3 / x5; bahan seperti telur dan tepung otomatis dikalikan) → daftar dan pintu gudang tertutup, bahan terpotong dari stok, lalu **gelembung tanda seru "!"** muncul mengambang di atas **Mixer** yang harus dihampiri.
3. **Ketuk Mixer** → karakter berjalan ke sana dan mulai mengaduk. Sebuah **bar progres tanpa angka dan tanpa hitung mundur** mengambang di atas alat yang sedang bekerja—pemain hanya perlu tahu "masih jalan" atau "sudah penuh".
4. **Adukan selesai** → tanda "!" **tetap di Mixer**: adonannya masih terkunci di dalam alat. **Ketuk Mixer lagi** → karakter mengambil mangkuk adonan, bawaannya terlihat di tangannya, dan barulah tanda "!" berpindah ke **Oven**.
5. **Ketuk Oven** → karakter mengantarkan adonan yang sedang ia bawa ke oven dan mulai memanggang.
6. **Roti matang** → tanda "!" **tetap di Oven**. **Ketuk Oven lagi** → karakter mengangkat loyang roti, dan tanda "!" berpindah ke **Rak Display**. (Mengetuk oven baru memberi perintah. Selama karakter belum tiba dan mengangkat loyangnya, roti masih di oven panas dan tetap bisa gosong. Begitu loyang terangkat, roti aman dari gosong—Seksi 62.)
7. **Ketuk Rak Display** → karakter mengantar loyang ke rak, lalu layar **Pemilih Petak Rak** terbuka dan pemain menentukan roti ditaruh di petak yang mana (posisi penempatan mempengaruhi penjualan).

*Aturan tetap:* **alat yang selesai bekerja menahan isinya sampai diambil.** Tanda "!" berpindah ke stasiun berikutnya hanya SESUDAH barangnya benar-benar ada di tangan karakter. Jadi tanda yang sama dibaca dua cara: "ambil dari sini" saat tangannya kosong, dan "antar ke sini" saat ia sudah menenteng sesuatu.

*Tangannya cuma sepasang:* selama satu bawaan belum diantar, alat lain yang juga sudah selesai tidak bisa diambil isinya—dan adonan kedua yang menunggu di mixer itulah yang membuat pemain harus memilih urutan kerjanya sendiri.

*Berjalan paralel:* yang mengantre hanyalah **kaki karakter**. Mixer dan oven berdetak sendiri setelah dinyalakan, jadi selagi roti dipanggang pemain tetap bisa memilih resep baru dan mengaduk adonan berikutnya. Beberapa pesanan berjalan sekaligus, masing-masing dengan tandanya sendiri.

Tepat jam 08:00 toko otomatis buka meski ada roti belum selesai.

**Tiga Hari Pembukaan — "jangan sampai gosong"**

Hari 1 sampai 3 **tidak diundi**. Permintaan hari itu sudah ditetapkan—siapa yang datang, jam berapa, membeli berapa, plus pesanan RotiFood-nya—dan gudang diisi **pas sebanyak itu, tanpa sebutir pun cadangan**:

| Hari | Resep | Bahan | Permintaan |
| :---- | :---- | :---- | :---- |
| **1** | Roti Tawar Polos | 6 batch = **36 roti** | 8 pembeli (26 roti) + 2 pesanan ojol (10 roti) |
| **2** | Roti Goreng Polos | 7 batch = **42 roti** | 9 pembeli (30 roti) + 3 pesanan ojol (12 roti) |
| **3** | Donat Gula | 9 batch = **45 roti** | 10 pembeli (34 roti) + 3 pesanan ojol (11 roti) |

Karena bahannya pas, **satu loyang yang dibiarkan gosong di oven berarti ada pembeli atau pesanan yang tidak kebagian hari itu**. Di sinilah pemain belajar bahwa mengangkat loyang tepat waktu bukan formalitas. Pagi hari angka targetnya diumumkan, dan HUD menampilkan "Permintaan: x / N roti" sepanjang hari supaya pemain tahu sisa kewajibannya. Jadwal lengkap per pembeli dan per pesanan RotiFood ditetapkan di Seksi 20.3.

Hari 1 sengaja diisi pembeli sabar (anak sekolah, emak-emak arisan, si galau). Pekerja kantoran yang kesabarannya hanya 18 detik baru muncul di hari 2. Mulai hari 4, permintaan kembali acak mengikuti rating, cuaca, dan kampanye (Seksi 8, 9, 10), dan pemain mulai mengelola pembelian bahan sendiri melalui Pasar. **Mulai setelah Hari 3 selesai, Pasar dapat dibuka kapan saja dari Quick Menu, termasuk saat Tahap Persiapan maupun Tahap Jualan.** Pembelian yang dilakukan sebelum toko tutup memiliki waktu pengiriman **3 jam in-game**; pembelian setelah toko tutup langsung masuk ke Gudang dan tersedia pada Tahap Persiapan keesokan hari.

**2\. Tahap Jualan (08:00 – 18:00)**

Toko melayani dua arus pembeli sekaligus: (a) Pelanggan fisik yang masuk, memilih roti dari etalase, dan mengantre di kasir; serta (b) Pesanan digital dari aplikasi online modern di tablet kasir yang dijemput langsung oleh Driver Ojek Online. Pemain klik bubble pesanan, menyiapkan atau mengemas roti, klik OK, lalu uang masuk. UI counter stok roti di kanan layar menunjukkan sisa roti di etalase.

**Aturan Antrean Universal — Tidak Boleh Menumpuk (Canonical):**

* Semua actor yang datang untuk menerima layanan toko—**pelanggan fisik dan Driver Ojek Online**—harus menempati **slot antrean fisik yang valid**. Satu slot hanya boleh ditempati satu actor. Dua karakter tidak boleh berdiri pada koordinat/slot antrean yang sama dan tidak boleh saling menembus.
* Setiap antrean memiliki jumlah slot maksimum berdasarkan layout/tier toko. Actor bergerak dari slot belakang menuju slot yang lebih depan hanya ketika slot di depannya kosong.
* **Jika seluruh slot antrean yang relevan sedang penuh, tidak ada pelanggan atau Driver Ojol baru yang boleh masuk ke toko.** Sistem spawn menahan kedatangan berikutnya sampai minimal satu slot menjadi kosong. Jangan spawn actor lalu menumpuknya di pintu, di rak, atau di belakang actor lain.
* Untuk Tier 1–2, pelanggan fisik dan Driver Ojol berbagi antrean utama sesuai aturan RotiFood. Untuk Tier 3+, Driver Ojol menggunakan antrean Meja Khusus Ojol bila fasilitas tersebut aktif; kapasitas antrean ojol dihitung terpisah dari antrean kasir reguler.
* Actor yang belum mendapatkan slot dianggap **belum masuk toko**. Mereka tidak memiliki collision/body aktif di interior dan tidak mulai mengurangi patience sampai benar-benar berhasil masuk ke slot/alur layanan yang sah.
* Event demand yang terjadi ketika antrean penuh boleh disimpan sebagai `pending_arrival` secara logis, tetapi tidak boleh divisualisasikan sebagai kerumunan yang menumpuk. Ketika slot tersedia, arrival berikutnya dapat diproses sesuai urutan scheduler.

**Satu pembeli fisik, langkah demi langkah:**

1. **Pembeli masuk** lewat pintu depan dan berjalan ke rak display.
2. **Memilih roti di rak** — dan ia **mengambil rotinya sendiri saat itu juga**. Stok etalase berkurang sejak detik itu, bukan nanti di kasir.
3. **Membawa belanjaannya ke meja kasir** dan berdiri di antrean; roti yang ditentengnya terlihat di tangannya.
4. **Gelembung tanda seru "!" muncul di atas kepalanya** begitu ia menjadi orang terdepan di antrean. Di atas kepala setiap pelanggan juga selalu terdapat **Patience Bar** yang menunjukkan sisa kesabarannya secara visual.
5. **Ketuk balon itu** — hanya berarti bila karakter pemain sedang berjaga di meja kasir. Kalau ia masih di dapur, ketukan itu justru menyuruhnya berjalan ke meja.
6. **Popup pesanan terbuka**: daftar roti yang dibeli beserta totalnya.
7. **Tekan OK** → karakter membungkus belanjaan ke dalam kantong kertas (animasi membungkus, lama sesuai kecepatan layan kasir).
8. **Pembeli membayar**, koin masuk ke kas, lalu ia melompat senang dan pulang.

*Roti yang tidak jadi dibayar kembali ke rak.* Pembeli yang kehabisan kesabaran — atau yang masih berdiri di dalam toko saat pintu ditutup pukul 18:00 — menaruh kembali rotinya ke etalase persis seperti semula, lengkap dengan kualitas dan usianya. Yang hilang adalah penjualannya dan sebagian reputasi, bukan rotinya.

**Siapa yang melayani meja kasir ditentukan satu aturan sederhana:**

* **Ada Asisten Kasir yang bertugas → pembeli dilayani OTOMATIS.** Kasir berdiri sendiri di mejanya sepanjang jam buka; pemain tidak perlu menyentuh meja kasir sama sekali dan bebas berada di dapur. Inilah yang sesungguhnya dibeli pemain saat menggaji kasir (3.1).
* **Tidak ada Asisten Kasir → karakter pemain harus berdiri di meja kasir.** Ketuk meja kasir → karakter berjalan ke posisi melayani di sisi dapur meja dan berbalik menghadap antrean. **Transaksi hanya berjalan selama ia berdiri di sana.** Begitu ia dipanggil pergi ke mixer atau oven, antrean berhenti bergerak dan pembeli mulai kehilangan kesabaran; transaksi yang sedang berjalan **membeku di tempat**—tidak dibatalkan, karena pembelinya masih berdiri menunggu ia kembali.

Aturan ini juga berlaku saat kasir sedang **diliburkan** (Mode Solo, 3.0.C): kasir yang tidak bertugas sama dengan tidak ada kasir, dan meja kembali menuntut kehadiran pemain.

Di sinilah tekanan utama tahap jualan selama toko belum mampu menggaji kasir: **memanggang dan melayani memperebutkan satu pasang kaki yang sama**. Pemain bisa membuat roti lagi di tahap ini, tapi setiap menit yang ia habiskan di dapur adalah antrean kasir yang mengular—dan roti yang ditinggal di oven tetap berisiko gosong. Menyewa Asisten Kasir adalah yang membebaskan kakinya, dan itulah alasan ekonomis utama untuk menggajinya.

**3\. Tahap Tutup (18:00)**

Muncul Daily Summary. Setelah Hari 3, Pasar tidak lagi terbatas pada tahap ini karena pemain sudah dapat membukanya kapan saja dari Quick Menu. Namun **pembelian bahan baku yang dilakukan setelah toko tutup (18:00 atau setelahnya) tidak menggunakan waktu kirim 3 jam**: bahan langsung dimasukkan ke Gudang dan tersedia untuk Tahap Persiapan keesokan harinya. Upgrade resep, peralatan, toko, staf, dan pengaturan lain tetap dapat dikelola pada fase after-hours sesuai menu yang tersedia.

# **3\. Key Features & Mechanics**

## **Sistem Ekonomi & Biaya Operasional**

Game menerapkan sistem ekonomi bisnis yang jelas, terukur, dan menenangkan (sesuai tema cozy):

* **Harga Bahan Baku Tetap (Fixed Price)**: Seluruh harga bahan baku bersifat pasti dan tidak mengalami fluktuasi naik-turun. Hal ini memungkinkan pemain merencanakan modal belanja dan menghitung margin laba setiap resep roti dengan pasti tanpa stres memantau grafik bursa.
* **Utility Cost (Biaya Utilitas Real-Time)**: Pemakaian listrik dan gas dihitung real-time berdasarkan durasi aktifnya alat (mixer, oven, showcase). Tidak ada mekanisme pemadaman/jeglek; pemain bebas menyalakan alat kapan pun, namun akumulasi pemakaian akan langsung ditagihkan sebagai biaya operasional harian pada layar *Daily Summary*.
* **Tidak Ada Game Over**: *Roti Lezat Tycoon* tidak mengenal layar *Game Over*. Kegagalan finansial hanyalah titik balik, bukan akhir cerita.

### **3.0 Sistem Kebangkrutan & Bantuan Pemerintah (Government Bailout System)**

Jika kas pemain tidak lagi sanggup menyelesaikan satu batch resep pun untuk beroperasi keesokan harinya, dan gudang maupun etalase tidak punya stok yang masih bisa dipakai (Seksi 49.1), maka secara otomatis sistem akan memicu **peristiwa khusus: "Kunjungan dari Pak Lurah"**.

#### **A. Cutscene Kunjungan Pak Lurah 🏛️**

Keesokan paginya, sebelum toko dibuka, muncul animasi cutscene hangat dan menggemaskan: seorang karakter chibi tambun berwajah ramah—**Pak Lurah**—mengetuk pintu garasi/toko dengan senyum tulus, membawa koper kecil dan amplop berstempel resmi pemerintah daerah. Dialog singkat muncul:

> *"Hey there! I heard the bakery has been having a rough few days. Don't give up. The local government has a small-business support program for hardworking owners like you. Here is a little emergency capital to get you baking again. Keep going—your bread is worth it!"* 🥺🍞

#### **B. Paket Bantuan Pemerintah (Bailout Package)**

Pemain menerima paket bantuan yang cukup untuk bertahan—namun tidak lebih dari itu:

| Konten Bantuan | Jumlah | Keterangan |
| :--- | :---: | :--- |
| 🪙 **Koin Roti Subsidi** | **650 KR** | Cukup untuk membeli bahan 1 batch `recipe_plain_loaf` + 1 batch `recipe_plain_fried_bread` (biaya batch: Seksi 63.1) |
| 🍞 **Bahan Baku Darurat** | Set Tier 1 x1 | Tepung (1) + Ragi (1) + Gula (1) + Air & Garam (1) — langsung masuk gudang; cukup untuk 1 batch `recipe_plain_fried_bread` |
| 📋 **Surat Peringatan Lunak** | — | Munculnya notifikasi tip strategi dari Pak Lurah di Daily Summary |

> **⚠️ Penting**: 650 KR bantuan ini **tidak cukup** untuk membayar gaji karyawan harian (gaji terendah: 150 KR/hari kasir magang + 180 KR/hari baker magang = 330 KR minimum jika punya 2 karyawan). Pemain **harus menonaktifkan semua karyawan** dan **menjalankan seluruh operasi toko seorang diri** sampai kas terkumpul kembali.

#### **C. Mode Solo — "Kerja Sendiri Dulu" 🧑‍🍳**

Begitu bailout diterapkan, toko memasuki **Mode Solo** (state machine: Seksi 49):

* **Semua karyawan aktif diliburkan sementara** (bukan dipecat; mereka akan kembali saat pemain punya cukup dana untuk menggaji lagi). Karakter karyawan yang sedang diliburkan muncul sebagai ikon tidur kecil di panel Manajemen Karyawan.
* **Pemain melakukan semua pekerjaan sendiri**: mengaduk adonan, membakar roti, melayani kasir, dan mengemas pesanan ojol—semua dilakukan secara manual seperti hari-hari pertama bermain. Ini berlaku **harfiah**: karakter pemain harus benar-benar berjalan ke tiap perabot, dan meja kasir hanya melayani selama ia berdiri di depannya (lihat Tahap Jualan pada Seksi 2).
* **Kecepatan layan manual**: 10,5 detik per pembeli—yaitu kecepatan Asisten Kasir Tier 1 (7,0 detik) dikali penalti manual 1,5x. Pemain memang lebih lambat daripada kasir yang digaji, dan itu disengaja: itulah harga yang dibayar saat kas sedang kosong.
* **Tidak ada utilitas yang diputus**: Listrik dan gas tetap menyala agar produksi bisa berjalan.
* **Bonus "Semangat Bangkit" (+Mood)**: Selama Mode Solo aktif, setiap roti yang berhasil dijual memunculkan animasi semangat kecil di atas karakter pemain (bintang kecil berkilauan ✨) sebagai bentuk apresiasi perjuangan bangkit dari nol.

#### **D. Syarat Bailout & Frekuensi**

* **Frekuensi Bebas**: Tidak ada batasan berapa kali pemain bisa mendapatkan bailout. Game ini ingin menjadi teman yang menenangkan, bukan penghukum.
* **Cooldown Ringan**: Setelah menerima bailout, jika pemain kembali bangkrut dalam 3 hari berturut-turut, Pak Lurah akan datang lagi dengan dialog berbeda yang tetap hangat namun kini memberikan **1 buah tip strategi spesifik** (misalnya: *"Coba fokus bikin Roti Goreng Polos dulu, Nak. Modalnya paling kecil, tapi untungnya paling besar dibanding modalnya!"*).
* **Tidak Ada Stigma / Penalti Reputasi**: Bailout tidak menurunkan rating toko. Pemerintah hadir diam-diam—pelanggan tidak tahu, toko tetap buka seperti biasa.

#### **E. Kondisi Pemicu Bailout**

| Kondisi | Status |
| :--- | :---: |
| Stok gudang + saldo tidak cukup untuk menyelesaikan satu batch resep apa pun yang bisa dibuat dengan equipment yang dimiliki, **DAN** tidak ada roti sellable di etalase | ✅ Bailout aktif (Seksi 49.1) |
| Stok gudang + saldo masih cukup untuk menyelesaikan minimal satu batch | ❌ Belum bailout (masih bisa produksi) |
| Masih ada roti sellable di etalase | ❌ Belum bailout (masih bisa berjualan) |
| Saldo KR cukup bayar gaji karyawan | ❌ Bailout tidak diperlukan |
| Saldo KR < total gaji karyawan, tapi ≥ harga bahan Tier 1 | ⚠️ Sistem memperingatkan pemain untuk melibur karyawan secara manual |



## **Manajemen Karyawan (Staff Management)**

Karyawan bertindak sebagai Asisten berdedikasi yang membantu otomatisasi operasional toko. Semakin tinggi keahlian karyawan, semakin cepat waktu kerjanya (*work speed*) dan semakin besar gaji harian (*daily salary*) yang harus dibayarkan.

### **3.1 Asisten Kasir (Cashier Assistant)**

Asisten Kasir bertugas di meja kasir untuk melayani transaksi pembeli **secara otomatis**. Keberadaan kasir membebaskan pemain dari keharusan mengklik balon pesanan secara manual dan menjaga agar antrean toko tidak macet.

**Arti "otomatis" di sini harfiah:** begitu seorang Asisten Kasir bertugas, jalur kasirnya berjalan sendiri sepanjang jam buka—karakter pemain boleh berada di mana saja di dalam toko, bahkan sibuk di dapur, dan antrean tetap mengalir. Sebaliknya, **tanpa kasir yang bertugas, meja itu hanya melayani selama karakter pemain berdiri di depannya** (lihat Tahap Jualan pada Seksi 2 dan Mode Solo pada 3.0.C). Membandingkan dua keadaan inilah yang membuat gaji kasir terasa sepadan.

| Tingkat / Jabatan | Gaji Harian (Per Hari) | Kecepatan Transaksi (Work Speed) | Kemampuan Khusus & Efek | Cocok untuk Lokasi |
| :--- | :---: | :---: | :--- | :--- |
| **Tier 1: Kasir Magang** | **150 KR** | **7.0 detik** / pelanggan | Pemula, kadang lambat menghitung koin. | Tier 1: Garasi Rumah |
| **Tier 2: Kasir Junior** | **350 KR** | **5.0 detik** / pelanggan | Cukup tanggap untuk arus belanja pejalan kaki. | Tier 2: Ruko 1 Pintu |
| **Tier 3: Kasir Terampil** | **800 KR** | **3.5 detik** / pelanggan | Menurunkan tingkat stres antrean pelanggan sebesar -15%. | Tier 3: Bakery Mandiri |
| **Tier 4: Kasir Profesional** | **1.800 KR** | **2.2 detik** / pelanggan | Mampu memproses tipe pelanggan "Si Galau" 2x lebih cepat. | Tier 4: Flagship Store |
| **Tier 5: Kasir Superstar** | **4.000 KR** | **1.2 detik** / pelanggan | Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra. | Tier 5: Mega Bakery |

*Catatan Kasir:* Jika pemain memiliki lebih dari satu meja kasir (Tier 3 ke atas), penempatan lebih dari satu kasir akan membuka antrean paralel terpisah, secara instan membagi separuh beban antrean toko.

*Batas yang berlaku saat ini:* jumlah jalur kasir yang terbuka = jumlah **kasir yang bertugas**, dibatasi jumlah meja yang dimiliki lokasi. Meja yang tidak ada kasirnya tetap tertutup—karakter pemain tidak bisa membuka jalur kedua di samping kasir yang sedang bekerja. Pemain hanya menggantikan kasir ketika **tidak ada kasir bertugas sama sekali**, dan saat itu ia melayani satu jalur.

---

### **3.2 Asisten Dapur (Kitchen Assistant / Baker)**

Asisten Dapur bertugas mengolah bahan mentah menjadi roti siap santap (mengambil bahan dari gudang, mengoperasikan mixer, memasukkan loyang ke oven, dan memindahkan roti matang ke rak display). 

Selain kecepatan kerja yang tinggi, Asisten Dapur tier tinggi memiliki kemampuan krusial: **Proteksi Roti Gosong (Auto-Retrieve)**, yaitu otomatis mengangkat loyang saat pemanggangan selesai sehingga pemain tidak perlu takut roti hangus saat sibuk.

| Tingkat / Jabatan | Gaji Harian (Per Hari) | Pengali Kecepatan (Work Speed) | Proteksi Roti Gosong (Auto-Retrieve) | Cocok untuk Lokasi |
| :--- | :---: | :---: | :---: | :--- |
| **Tier 1: Pembantu Dapur (Trainee)** | **180 KR** | **1.0x** (Waktu standar alat) | **0%** (Pemain tetap harus mengangkat loyang sendiri) | Tier 1: Garasi Rumah |
| **Tier 2: Asisten Baker (Junior)** | **400 KR** | **1.25x** (25% lebih cepat) | **25% peluang** otomatis mengangkat roti matang | Tier 2: Ruko 1 Pintu |
| **Tier 3: Baker Berpengalaman** | **950 KR** | **1.60x** (60% lebih cepat) | **60% peluang** otomatis mengangkat roti matang | Tier 3: Bakery Mandiri |
| **Tier 4: Chef Pastry Profesional** | **2.200 KR** | **2.00x** (2x lipat lebih cepat) | **90% peluang** otomatis mengangkat roti matang | Tier 4: Flagship Store |
| **Tier 5: Master Artisan Baker** | **5.000 KR** | **2.80x** (Hampir 3x lipat cepat) | **100% Anti-Gosong** (Pasti ditata rapi ke etalase display) | Tier 5: Mega Bakery |

*Catatan Dapur:* Pemain dapat mengatur mode kerja Asisten Dapur:
1. *Mode Auto-Replenish*: Asisten otomatis memproduksi roti yang stoknya paling sedikit di rak display.
2. *Mode Target Resep*: Pemain menetapkan resep spesifik yang harus dibuat secara berkelanjutan hingga bahan habis.

---

### **3.3 Batas Kapasitas Staf (Berdasarkan Tier Lokasi)**

Kapasitas jumlah karyawan yang dapat dipekerjakan dibatasi oleh luas fisik bangunan toko:

| Tier Lokasi | Maks. Asisten Kasir | Maks. Asisten Dapur | Total Maks. Karyawan | Estimasi Beban Gaji Harian |
| :--- | :---: | :---: | :---: | :--- |
| **Tier 1: Garasi Rumah** | 1 Orang | 1 Orang | 2 Orang | 330 – 500 KR / hari |
| **Tier 2: Ruko 1 Pintu** | 1 Orang | 2 Orang | 3 Orang | 750 – 1.500 KR / hari |
| **Tier 3: Toko Bakery Mandiri** | 2 Orang | 2 Orang | 4 Orang | 2.000 – 3.500 KR / hari |
| **Tier 4: Flagship Store** | 2 Orang | 3 Orang | 5 Orang | 5.000 – 10.000 KR / hari |
| **Tier 5: Mega Bakery Landmark** | 3 Orang | 4 Orang | 7 Orang | 15.000 – 32.000 KR / hari |

---

### **3.4 Rekrutmen & Sistem Penggajian**

* **Portal Lowongan Kerja In-Game**: Pemain membuka bursa pelamar melalui menu **Manajemen Karyawan** pada **Tahap Tutup (18:00)**. Daftar pelamar disajikan dalam bentuk foto polaroid imut dengan rincian nama, jabatan, tingkat keahlian, dan gaji harian.
* **Tanpa Biaya Rekrutmen (Gratis Rekrut)**: Tidak ada biaya awal untuk merekrut karyawan baru. Pemain dapat langsung merekrut kandidat yang diinginkan selama slot staf di toko masih tersedia.
* **Beban Murni Gaji Harian**: Biaya karyawan murni berasal dari gaji harian (*daily salary*) yang otomatis dipotong dari kas toko pada layar *Daily Summary* setiap pukul 18:00.
* **Pemecatan & Pergantian Staf**: Pemain dapat memberhentikan staf kapan saja tanpa denda penalti. Gaji hari tersebut tetap dibayarkan secara penuh pada laporan penutupan toko sore itu.
* **Visual Prosedural Karakter Staf**: Karakter staf dirakit secara prosedural dengan seragam celemek dan topi koki yang warnanya mencerminkan tingkatan keahlian mereka (misal: Tier 1 celemek putih sederhana $\rightarrow$ Tier 3 celemek cokelat karamel $\rightarrow$ Tier 5 celemek emas koki kepala).

### **3.5 Daftar Karakter Karyawan yang Dapat Direkrut (Staff Roster)**

Setiap pelamar memiliki identitas unik, cerita latar belakang yang jenaka dan menghangatkan hati (*cozy & wholesome*), serta ciri visual prosedural tersendiri.

#### **A. Roster Kandidat Asisten Kasir**

| Nama Staf | Tier Jabatan | Gaji Harian | Kecepatan Transaksi | Profil Kepribadian & Keunikan | Ciri Visual Prosedural |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Budi** | Tier 1 (Magang) | **150 KR** | 7.0 detik | Mahasiswa baru yang rajin; sering grogi saat menghitung koin kembalian tapi selalu tersenyum tulus. | Kacamata bulat besar, celemek katun putih polos, rambut belah samping rapi. |
| **Sari** | Tier 1 (Magang) | **150 KR** | 7.0 detik | Gadis ramah tetangga toko; suka menyapa pembeli dengan suara riang ceria ala kartun Minggu pagi. | Kuncir kuda ganda, pita rambut kuning mentega, celemek putih bergaris tipis. |
| **Dimas** | Tier 1 (Magang) | **150 KR** | 7.0 detik | Terlalu asyik bercerita cuaca dengan pelanggan sampai kadang lupa menekan tombol konfirmasi kasir. | Topi pet kasir miring ke samping, celemek putih gading, ekspresi cengengesan. |
| **Nadia** | Tier 2 (Junior) | **350 KR** | 5.0 detik | Mantan kasir minimarket; terbiasa menyusun struk transaksi dengan sangat rapi dan teliti. | Rambut bob pendek rapi, celemek hijau mint pastel, senyum profesional ramah. |
| **Rian** | Tier 2 (Junior) | **350 KR** | 5.0 detik | Pemuda aktif yang gesit; tanggap melayani arus pejalan kaki jam pulang sekolah. | Rambut spike pendek, celemek hijau mint, gelang karet oranye sporty. |
| **Lili** | Tier 2 (Junior) | **350 KR** | 5.0 detik | Pembawaannya tenang dan sabar; membuat pembeli yang sedang antre merasa adem dan tidak gelisah. | Jepit rambut stroberi imut, celemek hijau mint lembut, pipi merona merah muda. |
| **Maya** | Tier 3 (Terampil)| **800 KR** | 3.5 detik | Memiliki keahlian komunikasi persuasif; mampu meredakan emosi pekerja kantor yang terburu-buru. | Bando motif kotak-kotak (*gingham*), celemek cokelat karamel, pin senyum. |
| **Reza** | Tier 3 (Terampil)| **800 KR** | 3.5 detik | Jari-jemarinya lihai menari di atas tuts mesin kasir dengan akurasi hitungan tanpa celah. | Jam tangan vintage era 2000-an, celemek karamel berkantong dobel, tatapan fokus. |
| **Dewi** | Tier 3 (Terampil)| **800 KR** | 3.5 detik | Ingatannya tajam luar biasa; selalu hafal nama dan jenis roti favorit para pelanggan setia toko. | Rambut panjang dikepang rapi, celemek cokelat karamel, buku catatan mini di saku. |
| **Hendra** | Tier 4 (Profesional)| **1.800 KR**| 2.2 detik | Ahli psikologi konsumen; sanggup memandu pembeli "Si Galau" memutuskan pilihan dalam 2 detik. | Kemeja berkerah rapi di balik celemek biru navy elegan, kacamata bingkai emas. |
| **Citra** | Tier 4 (Profesional)| **1.800 KR**| 2.2 detik | Sangat tenang dan berwibawa; sanggup melayani antrean 20 orang tanpa sedikit pun terlihat panik. | Sanggul rambut modern elegan, celemek navy bergaris emas tipis, senyuman anggun. |
| **Kenji** | Tier 4 (Profesional)| **1.800 KR**| 2.2 detik | Kasir berdisiplin tinggi; terkenal dengan keramahan membungkuk sopan dan kecepatan kilatnya. | Rambut cepak rapi, celemek biru navy, pita leher dasi kupu-kupu merah marun. |
| **Grace** | Tier 5 (Superstar) | **4.000 KR**| 1.2 detik | "Duta Senyum Nasional"; aura ramahnya membuat pembeli bahagia dan sering memberi tip koin ekstra. | Celemek sutra emas berbordir logo toko, anting mutiara kecil, rambut pirang ikal. |
| **Tejo** | Tier 5 (Superstar) | **4.000 KR**| 1.2 detik | Kasir legendaris era toserba 90-an; sanggup menghitung kembalian secepat kilat bahkan sambil merem. | Kumis tipis retro nostalgia, celemek emas koki kepala, pena terselip di telinga. |
| **Luna** | Tier 5 (Superstar) | **4.000 KR**| 1.2 detik | Bintang idola lokal yang magang santai di toko roti; kehadirannya membuat kasir selalu ramai gembira. | Rambut ombre pastel manis, bando telinga kelinci empuk, celemek emas bertabur pin bintang. |

---

#### **B. Roster Kandidat Asisten Dapur (Baker)**

| Nama Baker | Tier Jabatan | Gaji Harian | Kecepatan & Proteksi Gosong | Profil Kepribadian & Keunikan | Ciri Visual Prosedural |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Joko** | Tier 1 (Trainee) | **180 KR** | 1.0x / 0% Anti-Gosong | Kuat mengaduk adonan tepung berat berjam-jam; tapi sering melamun saat oven berdenting. | Tubuh agak gempal berisi, celemek putih tebal bertabur bubuk tepung putih. |
| **Ani** | Tier 1 (Trainee) | **180 KR** | 1.0x / 0% Anti-Gosong | Suka mencicipi selai sebelum dioles ke roti; sangat antusias belajar aneka teknik memanggang. | Topi koki miring menggemaskan, celemek putih polos, hidung bertotol tepung. |
| **Bagus** | Tier 1 (Trainee) | **180 KR** | 1.0x / 0% Anti-Gosong | Terbiasa membantu ibunya membuat kue goreng di rumah; langkah kakinya cepat saat mondar-mandir. | Celemek putih pendek, lengan baju dilipat tinggi, senyum polos bersemangat. |
| **Fajar** | Tier 2 (Junior) | **400 KR** | 1.25x / 25% Anti-Gosong | Menguasai teknik menggulung adonan croissant dengan ketebalan yang merata sempurna. | Celemek oranye pastel, sarung tangan kain tahan panas, bandana koki oranye. |
| **Rina** | Tier 2 (Junior) | **400 KR** | 1.25x / 25% Anti-Gosong | Sangat disiplin menimbang gramasi ragi dan mentega; jarang sekali membuat adonan bantat. | Kacamata frame bulat tipis, celemek oranye pastel berenda, rambut dikuncir rapi. |
| **Doni** | Tier 2 (Junior) | **400 KR** | 1.25x / 25% Anti-Gosong | Tidak mudah patah arang; sigap membersihkan meja dapur setiap selesai mengocok telur. | Celemek oranye cerah, handuk kecil tersampir di pundak, ekspresi ramah fokus. |
| **Aris** | Tier 3 (Senior) | **950 KR** | 1.60x / 60% Anti-Gosong | "Si Raja Ragi"; ahli fermentasi roti tawar dan baguette berkulit renyah dengan remah selembut spons. | Topi koki silinder sedang, celemek cokelat kopi pekat, kumis melingkar rapi. |
| **Tari** | Tier 3 (Senior) | **950 KR** | 1.60x / 60% Anti-Gosong | Gerakannya anggun dan luwes dalam memanggang Cinnamon Roll dan Danish pastry yang wangi semerbak. | Celemek cokelat kopi bermotif renda bunga, rambut disanggul rapi dengan tusuk konde kayu. |
| **Gilang** | Tier 3 (Senior) | **950 KR** | 1.60x / 60% Anti-Gosong | Tangan dingin spesialis roti sobek manis; adonannya selalu mengembang cantik dalam cuaca apa pun. | Celemek cokelat kopi, sarung tangan oven tebal motif gingham, tatapan tenang berpengalaman. |
| **Sophie** | Tier 4 (Pakar) | **2.200 KR**| 2.00x / 90% Anti-Gosong | Baker Prancis lulusan Eropa klasik; ahli melipat pastry mentega ratusan lapis tipis yang renyah berkilau. | Topi toque koki tinggi Prancis, celemek marun elegan bergaris emas, syal leher merah. |
| **Danu** | Tier 4 (Pakar) | **2.200 KR**| 2.00x / 90% Anti-Gosong | Maestro roti sehat artisan; menguasai seni fermentasi ragi alami Sourdough dan olahan gandum utuh. | Jenggot koki terpangkas rapi, celemek marun pekat berkantong alat pisau roti kayu. |
| **Aoi** | Tier 4 (Pakar) | **2.200 KR**| 2.00x / 90% Anti-Gosong | Perfeksionis asal Kyoto; mampu memanggang puluhan lembar krep tipis Matcha Mille Crepes tanpa cela. | Bandana hachimaki hitam-putih khas chef Jepang, celemek marun, gerakan tangan presisi. |
| **Pierre** | Tier 5 (Master) | **5.000 KR**| 2.80x / 100% Anti-Gosong | Maestro pastry dunia; roti buatannya mengembang selembut awan surga dan selalu ludes diburu pecinta roti. | Topi koki menjulang tinggi dengan sulaman benang emas, celemek emas koki agung, medali kuliner. |
| **Mawar** | Tier 5 (Master) | **5.000 KR**| 2.80x / 100% Anti-Gosong | Nenek sakti pembawa buku resep rahasia keluarga; sentuhan tangannya 100% anti-gosong seumur hidup. | Kacamata rantai emas vintage, celemek emas rajut berhias sulaman mawar merah, aura keibuan hangat. |
| **Alistair** | Tier 5 (Master) | **5.000 KR**| 2.80x / 100% Anti-Gosong | Alkemis kuliner modern; spesialis mengolah jamur truffle dan butter artisan menjadi roti termahal di kota. | Jas koki hitam beraksen emas mewah, sarung tangan satin putih, tatapan tajam visioner. |

## **Perilaku Konsumen**

Sistem penjualan mengusung model gabungan antara **100% Takeaway (Beli lalu Pergi)** untuk pelanggan fisik dan **Digital Delivery Pickup** untuk pesanan online: pelanggan fisik masuk memilih roti dari rak display lalu mengantre di kasir, sedangkan kurir ojek online datang langsung ke counter untuk mengambil paket pesanan daring.

Pelanggan memiliki kepribadian, preferensi, dan pola kedatangan yang berbeda, yang menuntut pemain untuk tanggap dalam mengatur stok, kecepatan kasir, dan kecepatan packing delivery:

* **Kategori Reguler (Harian - Pelanggan Fisik)**:  
  * **Anak Sekolah (The Sweet Tooth)**: Kesabarannya tinggi (mau antre), namun uang saku terbatas sehingga akan mengeluh jika harga terlalu mahal. Mencari roti manis (Donat, Roti Cokelat) dan biasanya datang beramai-ramai di sore hari sepulang sekolah.  
  * **Pekerja Kantoran (The Rush Hour)**: Kesabaran sangat rendah. Jika antrean kasir terlalu panjang, mereka akan menggerutu, berbalik pergi, dan menurunkan rating toko. Mencari roti praktis (Croissant, Roti Sosis) dan membludak di jam sibuk pagi hari (08:00 - 10:00).  
  * **Emak-Emak Arisan (The Bulk Buyer)**: Membeli dalam jumlah sangat banyak sekaligus (5 - 15 roti). Sangat menguntungkan untuk profit cepat, tetapi berisiko menguras habis seluruh stok etalase dalam sekejap, membuat pelanggan di belakangnya terancam tidak kebagian.  
* **Kategori Pengantaran Online (Ekosistem Digital 2026)**:  
  * **Driver Ojek Online (The Delivery Runner)**: Mitra kurir pengantaran makanan bersepeda motor dengan seragam hijau toska pastel (`#4EBA6F`), helm bundar menggemaskan, dan ransel termal kubus di punggung. Driver ojol tidak berkeliling memilih roti di rak etalase; mereka langsung menuju kasir atau **Meja Khusus Ojol** untuk mengambil paket pesanan aplikasi yang sudah dikemas rapi (*paper bag*). Memiliki batas toleransi waktu penjemputan (*Pickup Window*). Jika pesanan sudah siap saat driver tiba (*Instant Handover*), pemain memperoleh rating bintang 5 di aplikasi dan potensi tip koin ekstra.
* **Kategori Premium & Spesial (Muncul di Tier Toko Tertinggi / Event Acak)**:  
  * **Sosialita / Crazy Rich (The Snob)**: Tidak memedulikan harga mahal, tetapi menuntut roti kualitas sempurna (Resep Tier 3 ke atas). Menolak membeli roti berkualitas rendah, mendekati dingin, atau yang hampir gosong.  
  * **Si Galau (The Indecisive)**: Membutuhkan waktu proses di kasir 2x lebih lama dari pelanggan biasa karena kebingungan memilih menu. Menuntut pemain atau Asisten Kasir bekerja ekstra agar pelanggan di belakangnya tidak marah karena antrean macet.  
  * **Food Vlogger / Kritikus (The VIP Critic)**: Pelanggan langka dengan kamera kecil. Jika pelayanannya cepat dan rotinya berkualitas prima, rating toko akan melonjak drastis keesokan harinya. Namun jika ia kecewa, reputasi toko bisa anjlok tajam.

---

### **3.6 Sistem Pesanan Ojek Online (Online Food Delivery System)**

Meskipun bernuansa retro-cozy tahun 2000, dunia *Roti Lezat Tycoon* berlatar di **tahun modern 2026**. Oleh karena itu, toko roti pemain dilengkapi dengan perangkat tablet kasir digital yang terhubung ke platform pesan-antar makanan online fiksi terpopuler di kota: **"RotiFood"**.

#### **A. Alur Siklus Pesanan Online (The Delivery Order Loop)**
1. **Notifikasi Masuk (Chime Alert)**: Tablet digital di samping kasir berdering dengan nada ceria (*ting-ting-ting!*). Balon pesanan digital muncul di atas tablet, menampilkan icon kantong kemasan, daftar roti yang dipesan warga kota, dan *Preparation Timer* (misal: 60 - 90 detik).
2. **Pengemasan Roti (Packing & Bagging)**: Pemain (atau Asisten Kasir/Dapur yang bertugas) mengklik pesanan untuk mengemas roti dari stok etalase display ke dalam kantong kardus cokelat berpita manis (*Procedural Paper Bag*). Roti yang dikemas langsung mengurangi stok display toko.

   *Bentuk ketukannya sama persis dengan pembeli fisik:* ketuk balon → **popup pesanan** memperlihatkan daftar roti beserta sisa stok etalase untuk tiap butirnya → satu tombol menyelesaikan langkah itu. Balonnya bisa diketuk di dua tempat yang sama-sama membuka popup yang sama: panel "Pesanan RotiFood" di HUD, dan tanda "!" yang mengambang di atas tablet di ujung meja kasir. Roti yang kurang ditandai merah di dalam popup, jadi pemain tahu resep mana yang harus dipanggang lebih dulu—tombolnya tidak pernah mati tanpa alasan.

   Berbeda dari pembeli fisik, pesanan aplikasi **tidak menuntut karakter berdiri di meja kasir**: yang bekerja di sini tablet, bukan mesin kasir.
3. **Kedatangan Driver Ojol**: Karakter chibi Driver Ojek Online tiba di toko dengan langkah riang membawa nomor pesanan digital di ponsel pintarnya.
4. **Serah Terima Cepat (Handover)**: Pemain atau kasir menyerahkan kantong roti kepada driver. Driver memasukkan bungkusan ke dalam tas termal punggungnya, melambaikan tangan dengan senyum puas, lalu bergegas mengantarkannya ke pelanggan. Koin Roti (KR) hasil penjualan langsung masuk ke kas kasir.

#### **B. Manajemen Antrean & Meja Khusus Ojol (Dedicated Delivery Counter)**
* **Toko Tier 1 & 2 (Starter / Garasi & Ruko)**: Driver ojol terpaksa mengantre di kasir utama bercampur dengan pelanggan fisik umum. Kondisi ini dapat menyebabkan penumpukan antrean panjang jika pesanan online sedang ramai.
* **Toko Tier 3 ke atas (Bakery Mandiri hingga Mega Bakery)**: Pemain dapat membuka fasilitas **Meja Khusus Ojol (Pickup Counter)** di dekat pintu masuk. Driver ojol akan langsung diarahkan ke meja khusus ini tanpa mengantre di kasir reguler. Ini memisahkan alur pelanggan fisik dan pesanan online 100%, menjaga antrean toko tetap higienis, teratur, dan super efisien.

#### **C. Sistem Reputasi Aplikasi ("RotiFood Stars")**
* **Rating Terpisah**: Kinerja pengantaran online dinilai secara independen melalui skor bintang aplikasi (1.0 hingga 5.0 bintang emas).
* **Instant Handover & Tip Bonus**: Jika pesanan sudah terbungkus rapi di meja sebelum driver tiba (waktu tunggu driver < 3 detik), toko diganjar skor bintang 5 sempurna serta peluang mendapatkan **Tip Koin Tambahan (+10% hingga +25% KR)**.
* **Batal Otomatis (Order Expired / Cancelled)**: Jika batas waktu penyiapan habis karena toko kehabisan stok roti atau pemain terlambat mengemas, pesanan akan dibatalkan otomatis oleh sistem aplikasi. Akibatnya: reputasi RotiFood turun -0.2 bintang dan driver meninggalkan toko dengan animasi kecewa (*sweat drop*).
* **Tingkat Order Masuk**: Semakin tinggi bintang toko di RotiFood, semakin deras order online yang masuk setiap jamnya (hingga lonjakan +80% frekuensi order harian).

#### **D. Sinergi Dinamis Cuaca Hujan (Rainy Weather Delivery Surge)**
Sistem online delivery memiliki sinergi gameplay yang sangat krusial dengan sistem cuaca (Seksi 10). Pada hari hujan, pesanan RotiFood meledak masif (+150% hingga +200%), membalikkan potensi kerugian akibat sepinya pejalan kaki fisik menjadi ladang keuntungan terbesar bagi pemain yang sigap!

## **Dekorasi & Kustomisasi**

Tata letak toko tidak hanya soal visual, tetapi juga soal optimasi alur kerja (workflow):

* Kitchen Layout: Menata posisi oven, mixer, **Gudang Penyimpanan**, dan meja kerja agar staf tidak perlu berjalan jauh.
* Storefront Aesthetics: Meletakkan rak roti di posisi strategis untuk menghindari antrean yang menumpuk di depan pintu.
* **Perabot yang bisa dipindah**: Mixer, Oven, Rak Display, dan Gudang Penyimpanan. **Meja kasir pembatas TIDAK bisa digeser**—ia bagian dari bangunan, bukan perabot lepas.
* **Zona penempatan**: alat masak dan gudang hanya boleh berdiri di area dapur; rak display hanya di area toko. Satu baris ubin tepat di belakang meja kasir selalu disisakan sebagai lorong jalan.
* **Jarak jalan itu nyata**: karakter pemain, pelanggan, karyawan, dan driver ojol **tidak bisa menembus perabot**—mereka mengitarinya. Denah yang berantakan benar-benar memperlambat kaki, jadi menata dapur bukan sekadar soal rapi dipandang.

# **4\. Art Direction & Generasi Objek Prosedural**

Seluruh objek visual yang terlihat di dalam game—baik **objek 3D** maupun **elemen 2D / UI**—dibuat **100% secara pemrograman prosedural (*procedural programming via code*) tanpa aset gambar atau model 3D eksternal (.png, .jpg, .gltf, .fbx, .obj)**. Pendekatan ini menghasilkan gaya visual yang konsisten, hemat memori secara ekstrem, dan memungkinkan variasi dinamis tak terbatas.

## **4.1 Filosofi Visual: "Warm, Cozy, & Cute"**

Identitas visual dan atmosfer game dibangun di atas tiga pilar emosional yang saling melengkapi:

1. **Warm (Sehangat Roti yang Baru Matang)**:
   * **Pencahayaan & Suasana**: Pencahayaan dunia 3D mengadopsi pencahayaan *golden hour* yang hangat. Cahaya matahari sore berwarna kuning keemasan (`#FFE3A8`) menerobos lembut melalui jendela kaca berbingkai kayu, berpadu dengan pendar lampu penghangat etalase (`#FFAA44`) dan bara oven yang ramah.
   * **Palet Warna Kuliner Hangat**:
     * *Golden Crust & Loaf*: Cokelat panggang keemasan (`#D9822B`), karamel hangat (`#8C4A1E`), dan cokelat gelap lembut (`#5A2E12`).
     * *Butter & Custard*: Kuning mentega lembut (`#FCE38A`), krim custard (`#F9D371`).
     * *Flour & Milk Cream*: Putih gandum lembut (`#FFFBF5`), krem vanila hangat (`#F5E6CA`).
     * *Baking Vapor*: Partikel uap hangat mengepul halus dan transparan dari rak dan oven yang baru dibuka.

2. **Cozy (Sesantai Minggu Sore di Tahun 2000)**:
   * **Nuansa Nostalgia Awal 2000-an**: Menghidupkan kembali kedamaian dan rasa santai yang murni ala akhir pekan di awal dekade 2000—terinspirasi dari suasana damai kartun Minggu pagi dan game simulasi klasik yang menenangkan (*Harvest Moon: Back to Nature*, *Boku no Natsuyasumi*). Visual bebas dari distraksi modern yang menyilaukan (tanpa lampu neon dingin atau UI futuristik).
   * **Detail Interior Bernostalgia**: Perabotan toko didominasi kayu pinus berpelitur hangat, lantai ubin terakota, tirai jendela bermotif kotak-kotak pastel (*gingham*), jam dinding bandul kayu berdetik tenang, serta ornamen radio kaset vintage di atas meja kasir.
   * **Soundscape Menenangkan**: Musik bergenre *acoustic bossa nova / lo-fi nostalgic 2000s* (petikan gitar nilon lembut, piano elektrik Rhodes yang empuk), dipadu foley ASMR yang memuaskan: bunyi gemeretak renyah saat roti dipotong, desis lembut mentega yang meleleh, suara *ting!* mekanis oven tua, dan gemerisik bungkus kertas roti.

3. **Cute (Semanis Roti Manis)**:
   * **Karakter Chibi & Empuk (*Squishy & Doughy*)**: Karakter dirancang bertubuh mini menggemaskan dengan proporsi bulat seperti adonan roti (*dough-like shapes*). Wajah dihiasi mata manik bulat berbinar dan pipi bulat merona merah muda (*rosy cheeks* `#FF9AA2`). Kostum koki dan celemek hadir dalam palet pastel manis: merah muda stroberi (`#FFB7B2`), hijau matcha pastel (`#B5EAD7`), dan biru lavender lembut (`#C7CEEA`).
   * **Bentuk Roti Montok & Menggoda**: Roti tawar mengembang tebal (*fluffy loaf*), donat montok empuk dengan taburan *sprinkles* gula warna-warni, serta kue manis bertabur selai berkilau.
   * **Interaksi Sentuh Membal (*Squash & Stretch Bounce*)**: Setiap interaksi (mengetuk roti, menekan tombol UI, atau saat karakter bereaksi senang) memiliki efek elastis yang kenyal seperti memencet roti empuk yang baru keluar dari pemanggang.

## **4.2 Arsitektur Model 3D Prosedural Berbasis Kode**

* **Peralatan Dapur (Mixer, Oven, Display)**: Dirakit secara algoritmik dari mesh primitif Godot (`BoxMesh`, `CylinderMesh`, `TorusMesh`, `SphereMesh`) dengan `StandardMaterial3D` bertekstur warna pastel kayu dan logam tembaga/krom klasik. Bentuk alat bermutasi secara parametrik saat di-upgrade dari perabot tradisional berbahan kayu di Tier 1 hingga teknologi modern di Tier 5.
* **Varian Roti & Pastry**: Mesh geometri dibentuk prosedural. Material memiliki parameter gradasi suhu kematangan: mentah (kuning pucat adonan) $\rightarrow$ matang sempurna (cokelat keemasan menggoda) $\rightarrow$ gosong (hitam gelap berjelaga).
* **Karakter & NPC**: Model chibi dirakit dari komponen badan dan kepala bulat tanpa skeletal armature.
* **Karakter Pemain (Pria / Wanita)**: Dua pilihan dirakit dari **satu perakit karakter yang sama** dengan masukan berbeda—gaya rambut, penutup kepala (topi koki / bandana), warna celemek, dan proporsi badan. Tidak ada model terpisah yang di-impor.
* **Barang Bawaan**: Saat memindahkan hasil kerja, karakter benar-benar **menjunjung barangnya**—mangkuk adonan dari mixer ke oven, loyang roti dari oven ke rak. Bawaan ini bukan hiasan: ia menandai tahap mana yang sedang ditempuh.
* **Penanda Stasiun**: Gelembung tanda seru "!" dan bar progres di atas perabot dirakit dari mesh primitif tipis bermaterial *unshaded*, lalu **seluruh penandanya diputar sekaligus** menghadap kamera. Memutar tiap lapisan sendiri-sendiri (billboard per-material) membuat isi bar progres melenceng keluar dari alurnya.
* **Proporsi Perabot Terikat Karakter**: Setiap meja tempat orang berdiri melayani—meja kasir pembatas, meja kasir, meja ojol—**tingginya dibatasi garis dada karakter chibi** (±0,44 m; permukaan meja 0,42 m). Meja yang melewati garis itu menenggelamkan orang yang berdiri di baliknya.
* **Animasi Prosedural**: Berjalan menggunakan gelombang sinus matematika (`sin(time * speed)` untuk ayunan langkah dan anggukan ceria), sedangkan ekspresi emosional dianimasikan dengan `Tween` squash & stretch.

## **4.3 Estetika Elemen 2D & UI Prosedural**

* **UI Komponen Ramah & Membal**:
  * Seluruh tombol dan panel menggunakan `StyleBoxFlat` dengan sudut membulat tebal (*pill / soft rounded corners* min. 16-24 px) yang memberikan kesan bantalan empuk (*cushiony feel*).
  * Tekstur menu mengadopsi nuansa kertas roti berserat (*parchment paper*) dan papan menu kapur kafe tempo dulu menggunakan noise/gradient generator bawaan Godot.
* **Ikon & Vektor Prosedural**: Ikon in-game (koin emas berkilau, jam dinding kayu, rating bintang mentega, balon pesanan berbentuk awan empuk) digambar langsung dengan fungsi CanvasItem `_draw()`.
* **Efek Visual Partikel (Visual Juice)**: Partikel uap hangat roti, serpihan gula halus berkilauan saat pesanan sukses, koin emas melompat gembira (+KR), serta asap gosong menggunakan `CPUParticles3D` dan `CPUParticles2D` murni dari script.

# **5\. Item & Inventory System**

## **5.1 Peralatan (Equipment)**

Peralatan dibagi menjadi lima tingkatan (tier). Tier 1 adalah peralatan bawaan (Starter) yang didapatkan pemain di awal permainan secara gratis. Semakin tinggi tier, semakin cepat waktu proses atau semakin besar kapasitasnya:

* **Tier 1 (Starter - Bawaan Awal Game):**  
  * **Mixer:** Mangkuk Kayu & Pengocok Manual (Waktu proses: 20 detik | Harga: 0 KR)  
  * **Oven:** Oven Tangkring Tua (Waktu panggang: 30 detik | Harga: 0 KR)  
  * **Display:** Keranjang Bambu Terbuka (Kapasitas: 50 roti | Harga: 0 KR)  
* **Tier 2 (Pemula - Cocok untuk Ruko):**  
  * **Mixer:** Stand Mixer Elektrik Murah (Waktu proses: 15 detik | Harga: 1.500 KR)  
  * **Oven:** Oven Listrik Mini (Waktu panggang: 22 detik | Harga: 2.000 KR)  
  * **Display:** Etalase Kaca Sederhana (Kapasitas: 100 roti | Harga: 1.500 KR)  
* **Tier 3 (Menengah - Cocok untuk Toko Bakery):**  
  * **Mixer:** Heavy Duty Stand Mixer (Waktu proses: 10 detik | Harga: 4.500 KR)  
  * **Oven:** Deck Oven 2 Tray (Waktu panggang: 15 detik | Harga: 6.000 KR)  
  * **Display:** Showcase Kaca dengan Lampu Penghangat (Kapasitas: 200 roti | Harga: 4.500 KR)  
* **Tier 4 (Industrial - Cocok untuk Flagship Store):**  
  * **Mixer:** Industrial Dough Kneader (Waktu proses: 6 detik | Harga: 12.000 KR)  
  * **Oven:** Convection Oven Besar (Waktu panggang: 10 detik | Harga: 15.000 KR)  
  * **Display:** Smart Temperature Showcase (Kapasitas: 350 roti | Harga: 12.000 KR)  
* **Tier 5 (Teknologi Tinggi - Cocok untuk Mega Bakery Landmark):**  
  * **Mixer:** Automated Mixing Robot (Waktu proses: 3 detik | Harga: 35.000 KR)  
  * **Oven:** Conveyor Belt Oven (Waktu panggang: 5 detik | Harga: 50.000 KR)  
  * **Display:** Premium Auto-Dispenser Showcase (Kapasitas: 600 roti | Harga: 30.000 KR)

*Waktu proses Mixer dan Oven di atas adalah **waktu referensi** tiap tier alat.* Durasi tahap sebenarnya dihitung dari waktu dasar resep (Seksi 61.5), dikali rasio waktu referensi alat yang dipakai terhadap alat minimum resep (Seksi 18.5). Contoh non-canonical: Roti Tawar Polos di Mixer T1 + Oven T1 memakai tepat 20 detik aduk dan 30 detik panggang.

### **5.1.1 Gudang Penyimpanan (Storage) — Kulkas & Lemari Bahan**

Berbeda dari mixer, oven, dan rak display, **Gudang Penyimpanan tidak pernah dijual di Pasar**. Ia sepaket dengan bangunan: nama, bentuk, dan kapasitasnya ikut naik sendiri begitu pemain meng-upgrade tier toko. Yang tetap milik pemain hanyalah **tempatnya**—gudang boleh digeser di Mode Dekorasi seperti perabot lepas lainnya.

* **Satu perabot, dua fungsi**: kulkas (bahan dingin) dan lemari bahan kering **menyatu menjadi satu entitas** bernama Gudang Penyimpanan.
* **Susunan**: seluruh unitnya **berjajar dalam satu baris** dan semua pintunya menghadap ke depan, bersebelahan—kulkas, lalu lemari di sampingnya. Karena itu jejak lantainya selalu **N × 1 ubin** dan bertambah besar dengan **melebar ke samping**, bukan menebal ke belakang. Menyusunnya depan-belakang akan membuat separuh pintunya membelakangi kamera isometrik dan mustahil diraih pemain.
* **Pintu masuk Buku Resep**: Buku Resep **tidak punya tombol di Quick Menu**. Ia dibuka dengan mengetuk gudang ini—karakter berjalan ke sana, pintunya berayun terbuka, barulah daftar resep muncul (lihat Seksi 2).

| Tier Toko | Nama Gudang Penyimpanan | Jejak Lantai | Kapasitas Bahan |
| :--- | :--- | :---: | :---: |
| **Tier 1: Garasi Rumah** | Kulkas Bekas & Rak Kayu | 2 × 1 ubin | 150 unit |
| **Tier 2: Ruko 1 Pintu** | Kulkas Dua Pintu & Lemari Bahan | 3 × 1 ubin | 400 unit |
| **Tier 3: Toko Bakery Mandiri** | Chiller Tegak & Lemari Stainless | 4 × 1 ubin | 1.000 unit |
| **Tier 4: Flagship Store** | Chiller Ganda & Lemari Bahan Segar | 4 × 1 ubin | 2.500 unit |
| **Tier 5: Mega Bakery Landmark** | Cold Room & Rak Gudang Industri | 5 × 1 ubin | 6.000 unit |

### **5.1.2 Pembelian, Penempatan & Penjualan Kembali Equipment — CANONICAL**

- **Tempat:** tab **Equipment** di layar Pasar. Pasar punya tiga tab: Ingredients, Equipment, dan Store Upgrade.
- **Waktu:** tab Equipment dan Store Upgrade hanya aktif **after-hours** (setelah Daily Summary). Di waktu lain keduanya tampil read-only dengan label `Available after closing`. Dengan begitu tidak ada alat yang diganti saat masih berisi job, dan keputusan investasi jatuh di momen perencanaan yang sama dengan staf dan iklan.
- **Katalog:** Mixer, Oven, dan Display Tier 1–5 dengan harga Seksi 5.1. Gudang dan meja tidak dijual (Seksi 5.1.1, 32.2). Tidak ada gate tier lokasi: tier apa pun boleh dibeli selama footprint-nya muat (Seksi 60).
- **Kartu alat** menampilkan:
  - nama English (Seksi 127.7) dan tier;
  - waktu referensi atau kapasitas;
  - utility (Seksi 86) dan footprint (Seksi 60);
  - harga;
  - daftar resep yang membutuhkan tier tersebut (Seksi 61.5).
- **Slot:** jumlah alat terpasang per kategori tidak boleh melebihi slot lokasi (Seksi 6). Alat yang baru dibeli masuk `unplaced_owned_furniture`, lalu Decoration Mode terbuka otomatis untuk menempatkannya.
- **Replace:** bila semua slot kategori itu penuh, pembelian menawarkan Replace. Pemain memilih alat terpasang yang diganti, dan alat lama pindah ke `unplaced_owned_furniture` (tidak hilang).
- **Sell:** alat yang tidak terpasang dapat dijual kembali seharga **50%** harga beli (half-up ke KR utuh). Alat Tier 1 bernilai 0. Ledger: `EQUIPMENT_SALE`.
- Alat yang masih berisi job, roti, atau tray (`IN_USE`, Seksi 72) tidak dapat diganti maupun dijual.
- Konfirmasi pembelian mahal mengikuti setting Seksi 75.3.
- **Starter:** New Game memberi 1 Mixer T1, 1 Oven T1, dan 1 Display T1 yang sudah terpasang. Salinan Tier 1 tambahan boleh dibeli seharga 0 KR selama slot tersedia.
- **Save:** alat terpasang maupun `unplaced_owned_furniture` disimpan di `equipment_states` (Seksi 106).

## **5.2 Sistem Bahan Baku (Fixed Price Ingredients)**

Setiap bahan baku memiliki **Harga Tetap (Fixed Price)** yang pasti dan tidak berubah-ubah. Sistem ini dirancang untuk menciptakan pengalaman bermain yang santai, terprediksi, dan menenangkan (*cozy tycoon*), di mana pemain dapat dengan mudah menghitung modal pokok produksi (*HPP - Harga Pokok Penjualan*) dan merencanakan keuntungan tanpa perlu cemas memantau spekulasi harga pasar.

Mulai **setelah Hari 3 selesai**, pembelian bahan baku dapat dilakukan **kapan saja** melalui **Pasar Bahan Baku** di Quick Menu.

* Pembelian pada **05:00–17:59** membuat pesanan suplai dengan waktu pengiriman **3 jam in-game**. Barang belum masuk stok Gudang sebelum pengiriman benar-benar tiba.
* Pembelian pada **18:00 atau setelah toko tutup** langsung masuk ke Gudang tanpa menunggu kurir dan tersedia untuk digunakan pada Tahap Persiapan keesokan hari.
* Pada Hari 1–3, akses Pasar bahan baku masih dikunci oleh tutorial/scripted onboarding, sampai settlement Hari 3 (18:00) membukanya (Seksi 24A.1).

### **5.2.1 Tabel Rincian Bahan Baku (Harga Tetap)**

#### **A. Bahan Dasar (Basic Ingredients - Pondasi Seluruh Adonan Roti)**
Bahan baku esensial yang digunakan sebagai adonan dasar hampir di semua resep roti dan kue.

| Nama Bahan | Satuan Takaran | Harga Tetap (Fixed) | Fungsi Rasa & Tekstur | Penggunaan Resep Utama |
| :--- | :---: | :---: | :--- | :--- |
| **Tepung Terigu** | Porsi (kg) | **150 KR** | Struktur & kerangka utama seluruh jenis adonan roti. | Semua varian roti (Roti Tawar, Donat, Roti Goreng, Croissant). |
| **Gula Pasir** | Porsi (ons) | **80 KR** | Pemanis adonan, pengaktif ragi, dan bahan dasar taburan glaze. | Donat Gula, Roti Manis, Glaze Pastry. |
| **Ragi Aktif (Yeast)** | Porsi (sachet)| **50 KR** | Agen pengembang biologis pembentuk pori roti yang empuk. | Wajib untuk semua roti yang mengembang (Roti Tawar, Baguette, Donat). |
| **Telur Ayam** | Butir | **100 KR** | Memberikan kelembutan, warna kuning keemasan, dan aroma gurih. | Adonan lembut (Brioche, Roti Manis, Danish Pastry). |
| **Mentega Biasa** | Porsi (gr) | **120 KR** | Lemak nabati pelembut serat roti dan pelapis adonan pastry. | Roti Tawar, Croissant dasar, Roti Goreng. |
| **Air & Garam Dapur** | Takaran | **20 KR** | Pengikat gluten adonan dan penguat rasa alami roti. | Penyeimbang rasa di semua jenis adonan roti. |

#### **B. Bahan Isian & Topping (Fillings & Toppings - Penambah Nilai Jual)**
Bahan pelengkap untuk resep roti menengah (Tier 2) yang meningkatkan daya tarik rasa dan margin laba.

| Nama Bahan | Satuan Takaran | Harga Tetap (Fixed) | Fungsi Rasa & Tekstur | Penggunaan Resep Utama |
| :--- | :---: | :---: | :--- | :--- |
| **Cokelat Batang** | Balok | **250 KR** | Cokelat leleh legit, favorit pelanggan anak sekolah & pekerja. | Roti Cokelat, Donat Cokelat, Pain au Chocolat. |
| **Keju Cheddar** | Batang | **300 KR** | Rasa asin gurih meleleh yang sangat disukai berbagai kalangan. | Roti Keju Manis, Croissant Keju, Danish Cheese. |
| **Selai Buah (Stroberi)**| Toples | **200 KR** | Rasa manis asam segar penyeimbang roti berlemak. | Donat Selai, Danish Pastry Buah, Roti Gulung Selai. |
| **Susu Segar** | Porsi (ml) | **150 KR** | Menghasilkan remah roti yang lembut serta olesan mengkilap (*egg wash*). | Brioche lembut, roti sobek susu, dan Danish pastry. |
| **Sosis Daging Sapi** | Buah | **350 KR** | Isian daging gurih padat untuk sarapan praktis pekerja kantor. | Roti Sosis Gurih (Sausage Roll), Roti Pizza Mini. |
| **Bubuk Kayu Manis** | Porsi (gr) | **180 KR** | Rempah aromatik manis penghangat suasana toko. | Cinnamon Roll, Danish Pastry Spiced. |

#### **C. Bahan Premium & Artisan (Luxury Ingredients - Resep Kelas Atas)**
Bahan khusus berkualitas tinggi untuk resep Tier 3 yang menargetkan kalangan elit (Sosialita & Food Vlogger). Memiliki harga modal tertinggi dengan profit penjualan terbesar.

| Nama Bahan | Satuan Takaran | Harga Tetap (Fixed) | Fungsi Rasa & Tekstur | Penggunaan Resep Utama |
| :--- | :---: | :---: | :--- | :--- |
| **Tepung Whole Wheat**| Porsi (kg) | **400 KR** | Tepung gandum utuh berserat tinggi dengan cita rasa kacang alami. | Roti Sehat Sourdough Whole Wheat. |
| **Butter Organik (Wijsman)**| Kaleng | **600 KR** | Mentega konsentrat beraroma harum legendaris untuk pastry berlapis. | Croissant Artisan Berlapis Mewah, Brioche Gourmet. |
| **Kacang Almond Iris** | Kantong | **500 KR** | Taburan renyah gurih memberikan tekstur renyah mewah. | Topping Almond Croissant, Roti Cokelat Almond. |
| **Cream Cheese Impor** | Kotak | **750 KR** | Krim keju lembut asam-gurih bertekstur lumer di lidah. | Basque Burnt Cheesecake Bun, Premium Cream Pastry. |
| **Bubuk Matcha Jepang**| Kaleng | **800 KR** | Teh hijau asli dengan rasa umami khas dan warna hijau alami. | Matcha Mille Crepes, Matcha Sweet Brioche. |
| **Minyak / Jamur Truffle**| Botol | **1.200 KR**| Aroma bumi mewah (*earthy*) yang memberikan status hidangan bintang lima. | Truffle Mushroom Bun, Roti Artisan Eksklusif. |

### **5.2.2 Mekanisme Gudang & Manajemen Inventaris (Pantry Storage)**

Pemain dapat membeli bahan baku sesuai ketersediaan modal uang, namun kapasitas penyimpanan tetap dibatasi oleh kapasitas **Gudang Toko (Pantry)** untuk menjaga elemen manajemen inventaris:

* **Tier 1 (Garasi Rumah)**: Kapasitas **150 Unit Bahan Total** (fokus pada bahan dasar, ruang sangat terbatas).
* **Tier 2 (Ruko 1 Pintu)**: Kapasitas **400 Unit Bahan Total** (mulai leluasa menyimpan aneka isian cokelat, keju, sosis).
* **Tier 3 (Toko Bakery Mandiri)**: Kapasitas **1.000 Unit Bahan Total** (kapasitas nyaman untuk produksi variatif harian).
* **Tier 4 (Flagship Store)**: Kapasitas **2.500 Unit Bahan Total** (dilengkapi chiller penyimpanan bahan segar).
* **Tier 5 (Mega Bakery Landmark)**: Kapasitas **6.000+ Unit Bahan Total** (gudang skala industri untuk suplai masif).

*Aturan Pembelian:* Setelah Pasar terbuka (Hari 4+), pemain dapat membeli bahan baku kapan saja selama saldo mencukupi dan kapasitas Gudang mampu menerima pesanan tersebut. Untuk pembelian saat toko belum tutup, kapasitas harus memperhitungkan **stok saat ini + seluruh jumlah bahan yang masih `in_transit`**, sehingga pemain tidak dapat membuat pesanan yang nantinya melampaui kapasitas Gudang ketika tiba. Saldo KR dipotong saat order dikonfirmasi. Barang baru menjadi `available_inventory` ketika paket benar-benar diterima.

### **5.2.3 Sistem Pengiriman Pesanan Bahan Baku (Ingredient Supply Delivery)**

Setelah tutorial Hari 1–3 selesai, pembelian Pasar pada jam operasional tidak lagi bersifat instan. Sistem ini membuat perencanaan stok menjadi bagian nyata dari ritme tycoon.

#### **A. Lead Time**

* Waktu kirim tetap: **3 jam in-game**. Dengan skala waktu canonical 1 jam in-game = 3 menit nyata, lead time normal setara **9 menit nyata** selama clock berjalan normal.
* `arrival_game_time = purchase_game_time + 3:00`.
* Jika ETA secara matematis melewati 18:00, pesanan tetap dikirim berdasarkan clock/order policy yang ditetapkan scheduler; **pembelian baru yang dibuat setelah toko sudah tutup** adalah kasus khusus dan langsung masuk Gudang untuk esok pagi.
* Pause game menghentikan clock dan otomatis menghentikan progress ETA.

#### **B. Status Purchase Order**

```text
CREATED
PAID
IN_TRANSIT
COURIER_SPAWNING
COURIER_ENTERING
DROPPING_PACKAGE
INVENTORY_COMMITTED
COURIER_EXITING
COMPLETED
```

Data minimum:

```gdscript
class_name IngredientPurchaseOrder
var order_id: int
var created_day: int
var created_game_time: float
var arrival_game_time: float
var items: Dictionary
var total_cost: float   # whole KR (Seksi 99.2)
var state: int
var instant_after_hours: bool
```

#### **C. Animasi Kurir Paket**

Ketika ETA tercapai:

1. Seorang **Kurir Paket Bahan Baku** muncul dari titik masuk luar toko membawa kardus/paket prosedural.
2. Kurir berjalan menuju **staging point di meja kasir**. Kurir paket suplai bukan pelanggan dan bukan Driver RotiFood, sehingga tidak membeli produk dan tidak memakai patience customer.
3. Kurir menaruh paket di permukaan meja kasir dengan animasi singkat (angkat → turunkan → paket menyentuh meja).
4. **Commit point inventaris terjadi tepat ketika paket diletakkan di meja.** Seluruh bahan dalam order ditambahkan ke Gudang secara atomik dan langsung dapat dipakai untuk produksi.
5. Muncul feedback singkat, misalnya ikon paket + teks `Ingredients Delivered!` dan perubahan counter stok.
6. Setelah commit, kurir berbalik, berjalan keluar melalui pintu toko, lalu di-despawn setelah mencapai titik keluar.

#### **D. Anti-Stacking Kurir Suplai**

Jika beberapa purchase order memiliki ETA yang sama/berdekatan, hanya **satu kurir paket** yang melakukan animasi drop-off di meja kasir pada satu waktu. Order berikutnya masuk FIFO delivery queue dan diproses segera setelah staging point bebas. Barang sebuah order tidak boleh ditambahkan sebelum animasi drop-off order tersebut mencapai commit point.

#### **E. Pembelian Setelah Tutup**

Jika Pasar digunakan setelah 18:00:

* Tidak spawn kurir.
* Tidak ada lead time.
* KR tetap dipotong saat konfirmasi.
* Barang langsung masuk Gudang.
* Barang tersebut tersedia ketika Tahap Persiapan hari berikutnya dimulai.

*Wujud Fisiknya:* Kapasitas di atas bukan angka abstrak—ia melekat pada perabot **Gudang Penyimpanan** yang benar-benar berdiri di dapur (lihat 5.1.1). Perabot itulah yang diketuk pemain untuk membuka Buku Resep, dan bentuknya ikut membesar seiring kapasitasnya.

## **5.3 Recipe Book — Canonical Reference Only**

Recipe Book adalah antarmuka pemain untuk memilih resep, batch, harga jual, dan melihat informasi produksi. **Bagian ini tidak menyimpan angka ekonomi canonical.** Seluruh angka resep hanya boleh didefinisikan satu kali pada **Section 61 (Product / Recipe Production Specification), Section 63 (Final Recipe Economy), dan Section 127 (English Content Catalog)**.

### **5.3.1 Canonical Behavior**

- Tidak ada pembelian resep, skill tree, research unlock, atau level resep.
- Sebuah resep dapat dibuat jika seluruh bahan yang dibutuhkan tersedia dan equipment minimum yang disyaratkan tersedia.
- Recipe Book dibuka dengan mengetuk Storage; tidak ada shortcut produksi yang melewati karakter pemain.
- Pemain memilih recipe + batch multiplier (`x1`, `x3`, `x5`), lalu bahan di-reserve/commit sesuai ProductionJob contract.
- Recipe Book menampilkan: English display name, ingredient list, batch yield, equipment requirement, mix time, bake time, burn grace, base expiration duration, default unit price, allowed price range, estimated unit COGS, dan target customer tags.
- Tombol **Make** hanya membuat job/command. Produksi tidak dimulai sebelum karakter mencapai equipment yang benar sesuai Player Task System.
- Seluruh display rack bersifat universal: semua recipe dapat ditempatkan pada semua display tier selama kapasitas tersedia.

### **5.3.2 Single-Source Rule**

Jangan menyalin angka harga, batch yield, recipe cost, expiration, atau waktu proses ke section lain. Section lain harus mereferensikan `recipe_id`. Jika dokumentasi naratif perlu contoh angka, tulis sebagai contoh non-canonical atau referensikan field canonical.

### **5.3.3 Player-Facing Language**

Semua nama recipe dan seluruh teks Recipe Book yang tampil di game wajib memakai English display strings dari Section 127. Nama Indonesia di bagian naratif GDD hanya deskripsi pengembangan dan tidak boleh muncul pada UI rilis.

---

# **6\. Location & Store Upgrade System**

Sistem properti menggunakan mekanisme **Beli Putus (Hak Milik)** sehingga pemain **tidak dibebani biaya sewa harian**. Seluruh penjualan bersifat **100% Takeaway** (tanpa area dine-in).

### **Tabel Ringkasan Spesifikasi Upgrade Toko**

| Spesifikasi | Tier 1: Garasi Rumah | Tier 2: Ruko 1 Pintu | Tier 3: Toko Bakery Mandiri | Tier 4: Flagship Store | Tier 5: Mega Bakery Landmark |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Status Properti** | Milik Sendiri | Beli Putus | Beli Putus | Beli Putus | Beli Putus |
| **Harga Beli / Upgrade** | **0 KR (Starter)** | **15.000 KR** | **55.000 KR** | **180.000 KR** | **600.000 KR** |
| **Biaya Sewa Tempat** | **0 KR** | **0 KR** | **0 KR** | **0 KR** | **0 KR** |
| **Beban Harian Tetap** | Murni Utilitas & Gaji | Murni Utilitas & Gaji | Murni Utilitas & Gaji | Murni Utilitas & Gaji | Murni Utilitas & Gaji |
| **Slot Mixer (Dapur)** | **1 Unit** | **2 Unit** | **3 Unit** | **4 Unit** | **5 Unit** |
| **Slot Oven (Dapur)** | **1 Unit** | **2 Unit** | **3 Unit** | **4 Unit** | **5 Unit** |
| **Slot Rak Display** | **1 Rak** | **2 Rak** | **3 Rak** | **4 Rak** | **6 Rak** |
| **Slot Meja Kasir** | **1 Kasir** | **1 Kasir** | **2 Kasir** | **2 Kasir** | **3 Kasir** |
| **Gudang Penyimpanan** | Kulkas Bekas & Rak Kayu | Kulkas Dua Pintu & Lemari | Chiller Tegak & Lemari Stainless | Chiller Ganda & Lemari Segar | Cold Room & Rak Industri |
| **Jejak Gudang (ubin)** | **2 × 1** | **3 × 1** | **4 × 1** | **4 × 1** | **5 × 1** |
| **Kapasitas Gudang** | **150 Unit** | **400 Unit** | **1.000 Unit** | **2.500 Unit** | **6.000 Unit** |
| **Maks. Asisten Dapur** | 1 Orang | 2 Orang | 2 Orang | 3 Orang | 4 Orang |
| **Maks. Asisten Kasir** | 1 Orang | 1 Orang | 2 Orang | 2 Orang | 3 Orang |
| **Kapasitas Antrean Toko (Seksi 57.6)**| 4 slot (bersama ojol) | 6 slot (bersama ojol) | 8 slot + 3 slot ojol | 10 slot + 4 slot ojol | 18 slot + 6 slot ojol |
| **Ukuran Bangunan Fisik** | **3 m × 6 m** | **L1: 3 m × 6 m; L2: 3 m × 4 m** | **L1: 3 m × 6 m; L2: 3 m × 6 m** | **8 m × 8 m** | **10 m × 10 m** |
| **Ukuran Grid** | **6 × 12 ubin** | **L1: 6 × 12; L2: 6 × 8 ubin** | **L1: 6 × 12; L2: 6 × 12 ubin** | **16 × 16 ubin** | **20 × 20 ubin** |
| **Pembagian Zona** | **3×3 m toko + 3×3 m dapur** | **Lantai bawah seluruhnya toko; lantai atas 3×4 m dapur** | **Lantai bawah seluruhnya toko; lantai atas seluruhnya dapur** | **4×8 m kiri toko + 4×8 m kanan dapur** | **6×10 m kiri toko + 4×10 m kanan dapur** |

### **6.1 Skala Ruang Canonical**

Seluruh ukuran lokasi di atas ditulis dalam **meter**, bukan jumlah tile. Sistem grid menggunakan konversi tetap berikut dan tidak boleh diubah per tier:

- **1 ubin = 0,5 m × 0,5 m = 50 cm × 50 cm.**
- **1 meter = 2 ubin.**
- Luas 1 ubin = **0,25 m²**.
- Semua footprint furniture, lebar lorong, titik antrean, radius interaksi, posisi pintu, tangga, counter, serta anchor karakter harus diturunkan dari skala ini.
- `GridMap`/`AStarGrid2D` menggunakan satu cell logis per **0,5 meter** pada sumbu X/Z.
- Sumbu Y tetap menggunakan meter dunia Godot; satu lantai berbeda secara vertikal dan tidak ditumpuk pada grid 2D yang sama tanpa `floor_id`.

**Aturan koordinat canonical:**

```text
WORLD_METERS_PER_TILE = 0.5
TILES_PER_METER = 2
world_x = grid_x * 0.5
world_z = grid_y * 0.5
grid_x = round(world_x / 0.5)
grid_y = round(world_z / 0.5)
```

Semua AI implementor harus menyimpan dimensi gameplay dalam **tile integer** dan hanya mengonversinya menjadi meter ketika membangun transform dunia 3D. Jangan menggunakan campuran ukuran arbitrer seperti 1 tile = 1 meter pada subsystem lain.

### **6.2 Layout Fisik Tiap Tier**

#### **Tier 1 — Garasi Rumah**
- **1 lantai, 3 m × 6 m = 6 × 12 ubin.**
- Dibagi memanjang menjadi dua zona sama besar:
  - **Toko:** 3 m × 3 m = **6 × 6 ubin**.
  - **Dapur:** 3 m × 3 m = **6 × 6 ubin**.
- Garis batas toko/dapur harus jelas pada data zoning walaupun secara visual boleh terasa seperti satu garasi terbuka.
- Counter kasir berfungsi sebagai batas operasional utama antara jalur pelanggan dan area kerja.

#### **Tier 2 — Ruko 1 Pintu**
- **1,5 lantai.** Istilah “1,5 lantai” berarti lantai bawah penuh dan lantai atas hanya memiliki area aktif 3 m × 4 m.
- **Lantai bawah / toko:** 3 m × 6 m = **6 × 12 ubin**.
- **Lantai atas / dapur:** 3 m × 4 m = **6 × 8 ubin**.
- Dapur tidak berada di belakang toko pada lantai bawah; dapur canonical berada di lantai atas.
- Harus ada **tangga penghubung** yang memiliki entry/exit anchor pada kedua floor. Tangga merupakan jalur wajib player dan staff dapur, tetapi pelanggan fisik serta Driver RotiFood tidak naik ke dapur.
- Pathfinding menggunakan graph per lantai yang dihubungkan oleh `STAIR_LINK`, bukan menganggap dua floor berada pada plane yang sama.

#### **Tier 3 — Toko Bakery Mandiri**
- **2 lantai penuh.**
- **Lantai bawah / toko:** 3 m × 6 m = **6 × 12 ubin**.
- **Lantai atas / dapur:** 3 m × 6 m = **6 × 12 ubin**.
- Semua aturan tangga dan multi-floor Tier 2 tetap berlaku.
- Dua jalur kasir berada di lantai toko; pelanggan tidak masuk ke lantai dapur.

#### **Tier 4 — Flagship Store**
- **1 lantai, 8 m × 8 m = 16 × 16 ubin.**
- Pembagian vertikal pada denah:
  - **Sisi kiri — toko:** 4 m × 8 m = **8 × 16 ubin**.
  - **Sisi kanan — dapur:** 4 m × 8 m = **8 × 16 ubin**.
- Konsep open-kitchen boleh memberi visibilitas ke area dapur, tetapi zoning gameplay tetap terpisah.

#### **Tier 5 — Mega Bakery Landmark**
- **1 lantai, 10 m × 10 m = 20 × 20 ubin.**
- Pembagian vertikal pada denah:
  - **Sisi kiri — toko:** 6 m × 10 m = **12 × 20 ubin**.
  - **Sisi kanan — dapur:** 4 m × 10 m = **8 × 20 ubin**.
- Tiga kasir reguler, area pickup, rak, dan queue harus tetap berada dalam zona toko; seluruh mesin produksi dan gudang berada dalam zona dapur.

### **6.3 Standardisasi Ukuran Perabot dan Object**

Skala 50 cm per tile adalah **source of truth** untuk seluruh proporsi dunia. Sebelum sebuah object dibuat secara prosedural, object harus memiliki `footprint_tiles: Vector2i` dan `size_meters: Vector3`. Footprint selalu dibulatkan ke kelipatan 0,5 m pada X/Z agar placement dan navigation konsisten.

**Footprint canonical:** footprint, ukuran fisik, tinggi, dan interaction face seluruh perabot (Gudang, Mixer, Oven, Rak Display, meja kasir, meja RotiFood, dan portal tangga) hanya didefinisikan di **Seksi 60**. Tabel ini hanya memuat unit ruang non-perabot:

| Object | Footprint Grid | Ukuran Lantai Fisik | Catatan |
| :--- | :---: | :---: | :--- |
| Karakter/NPC standing slot | 1 × 1 ubin | 0,5 × 0,5 m | Satu actor per queue/interaction slot; tidak boleh dua actor memakai slot yang sama. |
| Jalur jalan minimum | 1 ubin | 0,5 m lebar | Minimum absolut. Jalur utama dianjurkan 2 ubin/1 m bila layout memungkinkan. |
| Paket bahan baku | max. 1 × 1 ubin visual | max. 0,5 × 0,5 m | Prop visual di atas counter; tidak membuat occupancy permanen. |

Catatan placement:
- Meja kasir dan meja RotiFood adalah fixture bangunan (tidak movable). Queue anchor berada di sisi pelanggan/driver.
- Rak display menghadap walkway toko dan tidak boleh menghalangi entrance atau queue.
- Semua pintu gudang menghadap interaction side, dan gudang tidak boleh memotong jalur utama dapur.
- Arah conveyor oven T5 menentukan sisi interaksinya.
- Lantai bertingkat dihubungkan portal instan (Seksi 68), bukan tangga fisik.

**Aturan tinggi:** footprint grid hanya mengontrol X/Z. Tinggi object (Y) mengikuti proporsi karakter. Ketentuan meja kasir lama tetap berlaku: permukaan meja sekitar **0,42 m** dan tidak boleh melewati garis dada chibi sekitar **0,44 m**. Object kecil seperti roti, mangkuk, loyang, paper bag, tablet, koin, dan dekorasi tidak mengonsumsi cell grid sendiri bila berada di atas furniture atau dibawa karakter; dimensinya tetap harus masuk akal terhadap tile 0,5 m dan karakter.

**Rule penting:** footprint adalah ruang gameplay, bukan persis bounding box mesh. Mesh boleh sedikit lebih kecil daripada footprint untuk memberi visual breathing room, tetapi tidak boleh keluar jauh dari footprint hingga terlihat bertabrakan dengan object di cell tetangga.

### **Rincian Progresi Lokasi:**

* **Tier 1: Garasi Rumah (The Humble Beginnings)**:  
  * Kondisi: Usaha rintisan di garasi rumah sendiri, **1 lantai berukuran 3 × 6 meter (6 × 12 ubin)**. Area depan **3 × 3 meter** adalah toko dan area belakang **3 × 3 meter** adalah dapur; keduanya boleh terasa terbuka secara visual tetapi tetap memiliki zoning gameplay yang berbeda.  
  * Kapasitas: 1 Mixer, 1 Oven, 1 Rak Display (50 roti), 1 Kasir.  
  * Karyawan: Maksimal 1 Kasir, 1 Dapur.  
  * Target Pelanggan: Tetangga dan anak-anak sekitar.

* **Tier 2: Ruko 1 Pintu (The First Step)**:  
  * Kondisi: Ruko komersial **1,5 lantai**. Lantai bawah **3 × 6 meter (6 × 12 ubin)** seluruhnya menjadi toko; lantai atas **3 × 4 meter (6 × 8 ubin)** menjadi dapur dan dihubungkan tangga internal.  
  * Kapasitas: 2 Mixer, 2 Oven, 2 Rak Display (Total hingga 200 roti), 1 Kasir.  
  * Karyawan: Maksimal 1 Kasir, 2 Dapur.  
  * Target Pelanggan: Pejalan kaki, ibu-ibu belanja, anak sekolah.

* **Tier 3: Toko Bakery Mandiri (The Established Business)**:  
  * Kondisi: Toko bakery **2 lantai penuh**. Lantai bawah **3 × 6 meter (6 × 12 ubin)** menjadi toko dan lantai atas **3 × 6 meter (6 × 12 ubin)** menjadi dapur; dua jalur kasir berada di lantai bawah.  
  * Kapasitas: 3 Mixer, 3 Oven, 3 Rak Display (Total hingga 600 roti), 2 Kasir.  
  * Karyawan: Maksimal 2 Kasir, 2 Dapur.  
  * Target Pelanggan: Pekerja kantoran, mahasiswa, rombongan keluarga.

* **Tier 4: Premium Flagship Store (The Artisan Era)**:  
  * Kondisi: Toko mewah **1 lantai 8 × 8 meter (16 × 16 ubin)**. Sisi kiri **4 × 8 meter** menjadi toko dan sisi kanan **4 × 8 meter** menjadi dapur open-kitchen.  
  * Kapasitas: 4 Mixer, 4 Oven, 4 Rak Display (Total hingga 1.400 roti), 2 Kasir Modern.  
  * Karyawan: Maksimal 2 Kasir, 3 Dapur.  
  * Target Pelanggan: Sosialita, eksekutif, pencinta roti artisan.

* **Tier 5: Mega Bakery Landmark (The Culinary Icon)**:  
  * Kondisi: Mega bakery **1 lantai 10 × 10 meter (20 × 20 ubin)**. Sisi kiri **6 × 10 meter** menjadi toko dan sisi kanan **4 × 10 meter** menjadi dapur industri, dengan 3 kasir otomatis dan kapasitas produksi masif.  
  * Kapasitas: 5 Mixer, 5 Oven, 6 Rak Display (Total hingga 3.600 roti), 3 Kasir Otomatis.  
  * Karyawan: Maksimal 3 Kasir, 4 Dapur.  
  * Target Pelanggan: Seluruh kalangan kota, katering/pesanan event besar, wisatawan kuliner.

# **7\. UI/UX Design**

* **Layar Pemilihan Karakter**: Muncul sekali saat menekan **New Game**. Dua kartu besar berisi potret chibi Pria dan Wanita yang digambar prosedural; kartu terpilih diberi bingkai emas. Pilihan ikut tersimpan di berkas simpanan.
* **Main HUD (Layar Utama)**: Menampilkan informasi esensial. Pojok kiri atas untuk Saldo Koin Roti (KR) dan Rating Toko. Pojok kanan atas untuk Jam In-Game dan Meteran Biaya Utilitas (menampilkan akumulasi biaya listrik & gas harian yang sedang berjalan). Bagian kanan layar terdapat Counter Stok Roti: Menampilkan sisa jumlah roti di etalase secara real-time agar pemain tahu mana yang laku dan tidak. Pojok kanan bawah untuk Quick Menu: **Pasar, Karyawan, Iklan, Dekorasi**. Tombol **Pasar** tampil terkunci/nonaktif selama Hari 1–3 dan terbuka permanen setelah onboarding Hari 3 selesai. **Buku Resep sengaja TIDAK ada di sini**—ia dibuka lewat Gudang Penyimpanan di dapur (lihat Seksi 2).    
* **Desain Menu Utama**:  
  * Pasar Bahan Baku: Tampilan ala papan tulis kapur toko kelontong tempo dulu yang menampilkan katalog bahan dengan harga tetap, stok gudang saat ini, stok `in_transit`, estimasi waktu tiba pesanan aktif, dan tombol beli jumlah porsi (+ / - / Max). Mulai Hari 4 menu ini dapat dibuka kapan saja dari Quick Menu. Pasar memiliki tiga tab: Ingredients, Equipment, dan Store Upgrade (Seksi 5.1.2).  
  * Buku Menu & Harga: Desain seperti buku resep, terdapat slider untuk mengatur harga jual yang memicu munculnya emoji prediksi reaksi pelanggan (misal: marah jika mahal).  
  * Manajemen Karyawan: Menampilkan daftar staf dalam bentuk ID Card atau Polaroid, lengkap dengan indikator skill dan kecepatan proses.  
  * Mode Dekorasi: Perabot sungguhan di dunia 3D disentuh langsung, terangkat dan berkedip, lalu diseret ke ubin lain; petak tujuannya disorot seukuran jejak lantai perabot itu. Kedip putih berarti tempatnya sah, kedip merah berarti ditolak beserta alasannya.
  * Pemilih Petak Rak: Muncul setelah karakter tiba di rak sambil membawa loyang. Kisi tombol besar sebanyak petak rak yang sesungguhnya (jumlahnya menurut tier rak, Seksi 85) menyalin susunan petak itu (kiri ke kanan), lengkap dengan isi tiap petak. Satu loyang boleh disebar ke beberapa petak—layarnya tidak menutup sampai loyangnya habis.    
* **UX Feedback & In-Game Indicators**:  
  * Balon Pikiran Pelanggan (Thought Bubbles) untuk menunjukkan keluhan seperti antrean lama (ikon jam pasir) atau harga mahal (ikon uang terbang).
  * **Patience Bar di Atas Kepala:** Setiap pelanggan fisik memiliki bar horizontal kecil yang selalu mengikuti posisi kepalanya. Bar menunjukkan `current_patience / max_patience`, berkurang secara halus ketika customer berada pada state yang mengonsumsi kesabaran. Driver Ojol yang sedang menunggu handover juga menggunakan indikator kesabaran/waiting yang konsisten bila mekanik patience berlaku padanya. Tidak menampilkan angka detik; pemain membaca kondisi dari panjang bar dan perubahan visual.  
  * Indikator Oven berupa progress bar melingkar yang berubah dari hijau, kuning, hingga merah berkedip sebagai tanda roti matang/gosong.
  * **Gelembung Tanda Seru "!"** mengambang di atas perabot yang menunggu diketuk, berdenyut pelan agar tertangkap sudut mata tanpa menjerit.
  * **Bar Progres Perabot** mengambang di atas alat yang sedang bekerja, tumbuh dari kiri ke kanan dan berubah dari hijau ke keemasan. **Tanpa angka dan tanpa hitung mundur**: pemain hanya perlu tahu "masih jalan" atau "sudah penuh", dan angka detik hanya akan menarik matanya dari dapur ke teks.  
* **UI Art Style (Warm, Cozy Y2K, & Cute)**:
  * Bentuk tombol membulat empuk (*pillow rounded*), menghindari sudut lancip yang kaku.
  * Nuansa palet warna UI: krem mentega lembut (`#FFF8EA`), cokelat kayu hangat (`#8C5835`), serta aksen pastel merah muda stroberi dan hijau matcha.
  * Tipografi: Font rounded ramah dan terbaca jelas (*chunky cozy font*), menghadirkan kesan buku cerita anak atau sampul majalah kuliner santai era 2000-an.
* **Micro-Interactions & Tactile Feedback**:
  * Efek sentuh membal (*squishy bounce*): saat tombol ditekan atau item disentuh, ukuran mengecil lembut ke skala 0.92x lalu membal ke 1.05x sebelum kembali normal, memberikan sensasi memuaskan seperti memencet adonan roti hangat.
  * Audio Feedback: Suara klik tombol berupa *soft wooden tap* (ketukan kayu lembut) atau *sweet bubble pop* yang menenangkan telinga.
* **Adaptasi Kontrol & Layar Sentuh (Mobile & Web)**:  
  * Desain tombol dan elemen interaktif memiliki zona sentuh (hitbox) minimal 48x48 dp agar nyaman disentuh menggunakan jari di layar ponsel tanpa salah klik, sekaligus responsif saat diklik dengan kursor mouse di browser.  
  * Tata letak UI adaptif dengan dukungan *Safe Area Margin* agar indikator HUD tidak terpotong oleh kamera depan (punch-hole/notch) atau rounded corner layar HP modern.

# **8\. Sistem Pemasaran & Iklan (Marketing Campaigns)**

Pemasaran adalah strategi penting untuk meningkatkan volume pengunjung harian (*foot traffic*) ke toko roti. Setiap kampanye pemasaran membutuhkan biaya di muka (*upfront payment*) dalam satuan **Koin Roti (KR)** dan memiliki masa aktif selama **5 hari (in-game)**.

Pemain dapat meluncurkan kampanye melalui menu Pemasaran pada **Tahap Tutup (18:00)**. Hanya satu kampanye iklan yang dapat aktif dalam satu waktu.

### **8.1 Tabel Tingkatan Kampanye Pemasaran (Marketing Tiers)**

Tingkatan kampanye terbuka secara bertahap seiring perkembangan Tier Lokasi Toko:

| Tingkat Kampanye | Biaya Kampanye (Durasi 5 Hari) | Beban Rata-rata / Hari | Peningkatan Pengunjung | Target Pelanggan Utama | Syarat Lokasi Toko |
| :--- | :---: | :---: | :---: | :--- | :--- |
| **Tier 1: Selebaran Kertas Roti** | **300 KR** | 60 KR / hari | **+20%** | Tetangga sekitar & Anak Sekolah | Tier 1: Garasi Rumah |
| **Tier 2: Spanduk & Poster Jalanan**| **1.200 KR** | 240 KR / hari | **+45%** | Pejalan kaki, Pekerja Kantoran, Ibu-Ibu | Tier 2: Ruko 1 Pintu |
| **Tier 3: Siaran Radio & Majalah Kuliner**| **3.500 KR** | 700 KR / hari | **+75%** | Keluarga & Emak-Emak Arisan (*Bulk Buyer*) | Tier 3: Bakery Mandiri |
| **Tier 4: Kolaborasi Influencer & Vlogger**| **10.000 KR** | 2.000 KR / hari | **+110%** | Sosialita (*The Snob*) & Kritikus Makanan VIP | Tier 4: Flagship Store |
| **Tier 5: Sponsor Festival Kuliner Akbar**| **30.000 KR** | 6.000 KR / hari | **+160%** | Seluruh kalangan kota, rombongan event besar | Tier 5: Mega Bakery |

---

### **8.2 Detail Karakteristik & Efek Kampanye**

1. **Tier 1: Selebaran Kertas Roti (Flyers)**:
   * *Deskripsi*: Karakter membagikan selebaran kertas roti sederhana kepada orang-orang yang melintas di depan rumah.
   * *Efek Tambahan*: Sangat efektif meningkatkan penjualan varian roti dasar (Donat Gula & Roti Tawar).
   * *Visual Feedback*: Di pagi hari tampak maskot lucu berdiri di pinggir jalan membagikan kertas selebaran dengan animasi ceria.

2. **Tier 2: Spanduk & Poster Jalanan (Street Banners)**:
   * *Deskripsi*: Memasang spanduk kain motif kotak-kotak pastel dan papan kayu penunjuk arah di persimpangan jalan ramai.
   * *Efek Tambahan*: Meningkatkan frekuensi kedatangan Pekerja Kantoran pada jam sibuk pagi hari (08:00 - 10:00).
   * *Boost Reputasi*: +0.08 bintang rating setiap hari kampanye jika antrean kasir berjalan lancar.

3. **Tier 3: Siaran Radio & Majalah Kuliner (Radio & Food Magazine)**:
   * *Deskripsi*: Iklan audio di radio lokal dengan jingle manis serta ulasan satu halaman penuh di majalah kuliner bulanan.
   * *Efek Tambahan*: Memicu kedatangan pelanggan borongan (*The Bulk Buyer*) yang memborong 5-10 roti sekaligus dalam satu struk.
   * *Boost Reputasi*: +0.15 bintang rating per hari.

4. **Tier 4: Kolaborasi Influencer & Food Vlogger**:
   * *Deskripsi*: Mengundang food vlogger populer untuk mengulas roti artisan dan merekam video dapur terbuka (*open kitchen*).
   * *Efek Tambahan*: Mendatangkan pelanggan berkantong tebal (*Sosialita*) yang hanya membeli roti resep Tier 3 tanpa memedulikan harga mahal. Peluang kedatangan **Kritikus Makanan VIP** meningkat sebesar +40%.
   * *Boost Reputasi*: +0.30 bintang rating per hari.

5. **Tier 5: Sponsor Festival Kuliner Akbar (City Expo Sponsor)**:
   * *Deskripsi*: Menjadi sponsor utama festival kuliner tahunan kota dengan stan raksasa dan promosi masif.
   * *Efek Tambahan*: Menggandakan arus antrean toko menjadi sangat padat (*rush hour seharian*). Sangat menguntungkan bagi pemain yang sudah memiliki 3 kasir otomatis dan staf dapur master.
   * *Boost Reputasi*: +0.50 bintang rating per hari.

---

### **8.3 Peringatan Strategis (Risk & Reward)**

Kampanye pemasaran adalah pedang bermata dua:
* **Risiko Antrean Penuh**: Jika pemain menyalakan kampanye iklan tingkat tinggi (Tier 3-5) namun kapasitas produksi dapur minim atau kasir masih lambat, seluruh **slot antrean** dapat terisi. Antrean tidak boleh meluber atau membuat NPC menumpuk; arrival baru ditahan sampai ada slot kosong. Pelanggan yang sudah berada di antrean tetap kehilangan kesabaran dan dapat kabur, sehingga reputasi toko tetap bisa **turun drastis** bila throughput layanan terlalu rendah.
* **Kesiapan Stok Roti**: Pemain harus memastikan kapasitas rak display dan bahan baku di gudang mencukupi sebelum mengaktifkan iklan, agar pelanggan tidak kecewa mendapati etalase dalam kondisi kosong melompong.

# **9\. Sistem Rating & Reputasi**

Toko *Roti Lezat* memiliki **dua buah sistem reputasi yang berjalan secara paralel**: reputasi fisik toko di kota dan reputasi digital di platform aplikasi pengantaran online.

## **9.1 Rating Reputasi Toko Fisik**

* **Dinamika Rating**: Setiap transaksi atau interaksi pelanggan fisik mempengaruhi reputasi toko secara langsung. Semakin tinggi rating toko, semakin banyak warga kota yang datang berbelanja setiap harinya.  
* **Kenaikan Rating**: Didapatkan dari transaksi pembelian yang berhasil, pelayanan kasir yang cepat dan ramah, serta boost otomatis saat kampanye iklan (Ads) sedang berjalan aktif.  
* **Penurunan Rating**: Terjadi akibat pelanggan yang pulang tanpa membeli karena etalase kosong (`stockout_failure`), pelanggan yang kabur karena antrean terlalu panjang, atau menjual roti dengan kualitas buruk/hampir gosong.

## **9.2 Rating Aplikasi RotiFood (Digital Delivery Rating)**

Reputasi digital toko di platform **RotiFood** diukur secara independen melalui skor bintang (1.0 hingga 5.0 ⭐) yang hanya dipengaruhi oleh performa pesanan online:

| Aksi | Dampak Rating RotiFood |
| :--- | :---: |
| Pesanan siap sebelum driver tiba (*Instant Handover*) | **+0.1 ⭐** |
| Pesanan siap dalam batas waktu normal | **±0** |
| Driver menunggu >10 detik | **−0.1 ⭐** |
| Pesanan dibatalkan karena stok habis / overtime | **−0.2 ⭐** |
| Kualitas roti prima (baru matang sempurna) | **+0.05 ⭐ bonus** |

* **Efek Bintang RotiFood**: Semakin tinggi bintang RotiFood, semakin deras frekuensi order online yang masuk setiap harinya. Toko dengan rating 4.5 ⭐ ke atas mendapatkan **badge "Toko Terpercaya"** yang meningkatkan volume order harian hingga +80%.

# **10\. Sistem Musim & Cuaca**

* **Dinamika Cuaca**: Kondisi cuaca dan musim akan berganti setiap beberapa hari in-game dan mempengaruhi perilaku belanja pelanggan secara berbeda di dua saluran: fisik maupun digital.

## **10.1 Cuaca Cerah / Panas ☀️**

Kondisi paling umum dan stabil. Arus pengunjung fisik berjalan normal sesuai rating toko. Pesanan RotiFood mengalir pada frekuensi standar. Cocok untuk menjual varian roti standar dan minuman dingin (jika fitur minuman sudah terbuka).

## **10.2 Cuaca Hujan 🌧️ — Momen Emas Delivery**

Hari hujan adalah **hari paling dramatis dan menguntungkan** bagi toko yang sudah memiliki reputasi RotiFood tinggi:

* **Foot Traffic Fisik Anjlok −60% hingga −80%**: Warga kota malas keluar rumah, jalanan sepi, dan pejalan kaki hampir menghilang dari depan toko.
* **Pesanan RotiFood Meledak +150% hingga +200%**: Warga yang berdiam di rumah ramai-ramai memesan roti hangat secara online melalui aplikasi. Banjir notifikasi *ting-ting-ting!* di tablet kasir tidak akan berhenti!
* **Driver Ojol Tetap Berdatangan**: Meskipun hujan deras, driver ojol tetap mengantarkan pesanan dengan jas hujan kuning menggemaskan yang otomatis menggantikan seragam hijau standar mereka—membuat animasi karakter menjadi lebih *cozy* dan menyenangkan untuk ditonton.
* **Strategi Pemain**: Pemain yang sigap mengemas dan menyiapkan stok produksi roti ekstra sebelum/saat hujan tiba akan membalikkan hari yang hampir sepi menjadi hari dengan pendapatan tertinggi dalam seminggu.

> **Tips Strategis 🧠**: Pantau ikon prakiraan cuaca di sudut layar setiap pagi sebelum toko buka. Jika ada ikon awan hujan untuk hari ini, prioritaskan memanggang roti sebanyak mungkin di pagi hari dan pastikan rating RotiFood sudah di angka 4.0 ⭐ ke atas!

## **10.3 Musim Liburan 🎉 (Holiday Season / Event)**

Lonjakan pengunjung fisik secara masif di seluruh kota. Ini adalah momen terbaik untuk mengaktifkan Iklan Tier 3–5 dan memaksimalkan profit dari kedua saluran (fisik + online) secara bersamaan. Pemain harus sanggup mengelola gelombang antrean fisik yang brutal **sekaligus** banjir pesanan online yang tak kalah deras.

# **11\. Daily Summary System**

Tepat saat jarum jam in-game menyentuh **18:00**, pintu toko otomatis tertutup dengan bunyi *"klik"* yang memuaskan, dan layar transisi hangat muncul: latar memudar ke suasana sore dalam toko yang senyap, cahaya keemasan dari lampu etalase bersinar lembut, dan karakter pemain berdiri lelah namun tersenyum puas sambil membuka buku catatan besar di meja kasir.

Inilah **Daily Summary** — laporan harian menyeluruh yang merangkum seluruh aktivitas dan kinerja toko dalam satu hari penuh.

---

## **11.1 Tampilan Layar Daily Summary**

Layar Daily Summary ditampilkan sebagai **selembar kertas nota/struk kasir berukuran besar** dengan desain bergaya toko kelontong tempo dulu — dicetak di atas kertas berwarna krem kekuningan (*parchment*), font typewriter bulat, dan ornamen bingkai tanaman sulur daun kecil di sekelilingnya.

```
╔══════════════════════════════════════════════════╗
║       🍞  ROTI LEZAT — LAPORAN HARI KE-{N}  🍞   ║
║           📅 {Nama Hari}, {Tanggal In-Game}       ║
║           ☀️ Cuaca: {Cerah / Hujan / Liburan}     ║
╠══════════════════════════════════════════════════╣
║  PEMASUKAN (INCOME)                              ║
║  ─────────────────────────────────────────────  ║
║  🏪 Penjualan Toko Fisik       :  +X.XXX KR      ║
║     └ Roti Terlaris: {Nama Resep} ({N} buah)     ║
║  📱 Pesanan Online (RotiFood)  :  +X.XXX KR      ║
║     └ Total Order Selesai: {N} pesanan           ║
║     └ Tip Delivery Bonus       :     +XX KR      ║
║  ─────────────────────────────────────────────  ║
║  TOTAL PEMASUKAN               : +XX.XXX KR      ║
╠══════════════════════════════════════════════════╣
║  PENGELUARAN (EXPENSES)                          ║
║  ─────────────────────────────────────────────  ║
║  🧂 Bahan Baku Terpakai        :   -X.XXX KR     ║
║  ⚡ Biaya Utilitas (Listrik+Gas):    -XXX KR     ║
║  👷 Gaji Karyawan              :   -X.XXX KR     ║
║     └ {Nama Kasir} (Kasir T{N}):    -XXX KR     ║
║     └ {Nama Baker} (Baker T{N}):    -XXX KR     ║
║  ─────────────────────────────────────────────  ║
║  TOTAL PENGELUARAN             :  -X.XXX KR      ║
╠══════════════════════════════════════════════════╣
║  LABA / RUGI HARI INI          : ±XX.XXX KR      ║
║  SALDO AKHIR                   :  XX.XXX KR 🪙   ║
╠══════════════════════════════════════════════════╣
║  STATISTIK HARI INI                              ║
║  ─────────────────────────────────────────────  ║
║  👥 Total Pelanggan Fisik      :  {N} orang      ║
║  📦 Order Delivery Selesai     :  {N} pesanan    ║
║  ❌ Order Delivery Batal       :  {N} pesanan    ║
║  🍞 Total Roti Terjual         :  {N} buah       ║
║  🗑️ Roti Tidak Laku (Sisa)     :  {N} buah       ║
║  ⭐ Rating Toko Hari Ini       :  {X.X} / 5.0    ║
║  ⭐ Rating RotiFood Hari Ini   :  {X.X} / 5.0    ║
╚══════════════════════════════════════════════════╝
```

---

## **11.2 Indikator Mood Toko (Daily Performance Emoji)**

Di bagian atas kertas nota, muncul **ikon ekspresi wajah besar** yang merangkum kinerja hari itu secara emosional — sesuai tema cute & cozy:

| Kondisi Hari Itu | Emoji Mood | Warna Latar | Keterangan |
| :--- | :---: | :---: | :--- |
| Laba bersih > 2.000 KR & rating naik | 🤩 | Kuning keemasan | *"Hari yang luar biasa! Rotimu laris manis!"* |
| Laba bersih positif, rating stabil | 😊 | Hijau pastel | *"Hari yang baik. Terus pertahankan ya!"* |
| Impas / laba sangat kecil | 😐 | Krem netral | *"Lumayan. Besok coba bikin lebih banyak!"* |
| Rugi, tapi masih ada saldo | 😟 | Oranye hangat | *"Hari yang berat. Jangan menyerah, ya!"* |
| Saldo 0 KR / bailout terpicu | 🥺 | Merah muda lembut | *"Pak Lurah sedang dalam perjalanan..."* |

---

## **11.3 Panel Sorotan Hari Ini (Daily Highlights)**

Tepat di bawah tabel angka, muncul 1–3 kotak **"Momen Istimewa"** yang merayakan atau mencatat kejadian unik hari itu:

| Jenis Highlight | Ikon | Contoh Teks |
| :--- | :---: | :--- |
| Roti terlaris hari ini | 🏆 | *"Donat Gula jadi bintang hari ini! Terjual 24 buah."* |
| Pelanggan VIP hadir | ⭐ | *"Food Vlogger mampir! Ulasannya keluar besok."* |
| Delivery surge saat hujan | 🌧️ | *"Hujan deras, RotiFood meledak! +180% order online."* |
| Order delivery batal | ⚠️ | *"3 pesanan RotiFood batal karena stok habis. Hati-hati!"* |
| Ada loyang gosong | 🔥 | *"2 loyang gosong hari ini. Jaga oven berikutnya!"* |
| Karyawan sangat produktif | 💪 | *"Aris bekerja luar biasa hari ini! Produksi roti x1.6."* |
| Stok gudang hampir habis | 📦 | *"Bahan baku menipis! Jangan lupa belanja di Pasar."* |
| Hari pertama Mode Solo | 🧑‍🍳 | *"Kamu kerja sendiri hari ini. Keren banget, semangat!"* |
| Kampanye iklan aktif | 📢 | *"Iklan Spanduk Jalanan masih berjalan (hari ke-3/5)."* |
| Hari holiday (`event_holiday`) | 🎉 | *"Libur akhir pekan! Seluruh kota keluar belanja."* |

---

## **11.4 Catatan & Tips dari Pak Lurah 📋**

Di pojok kanan bawah nota, muncul **amplop kecil atau sticky note kuning** dari Pak Lurah. Berisi satu kalimat tip kontekstual yang relevan dengan kondisi hari itu:

| Kondisi Pemicu | Contoh Tip Pak Lurah |
| :--- | :--- |
| Banyak roti sisa tidak laku | *"Coba kurangi produksi besok, Nak. Bikin sesuai perkiraan pembeli saja."* |
| Order RotiFood banyak batal | *"Stok harus selalu siap untuk ojol juga loh. Mereka tidak sabaran!"* |
| Saldo di bawah 500 KR | *"Wah, hampir tipis nih. Fokus bikin Roti Goreng Polos dulu ya, modalnya paling kecil tapi untungnya paling besar dibanding modalnya!"* |
| Rating toko turun | *"Kecepatan kasir sangat pengaruh ke rating. Coba upgrade kasir jika bisa."* |
| Cuaca hujan besok (prakiraan) | *"Besok kelihatannya hujan. Persiapkan stok roti lebih banyak untuk ojol ya!"* |
| Hari pertama, saldo awal | *"Selamat memulai, Nak! Roti Goreng Polos dan Roti Tawar itu modal paling hemat."* |
| Profit sangat tinggi | *"Wah, hebat sekali! Sudah siap upgrade toko ke level berikutnya belum?"* |
| Mode Solo aktif | *"Tidak apa-apa kerja sendiri dulu. Setiap pengusaha besar pernah ada di posisi ini!"* |
| Holiday dimulai besok (Seksi 26.6) | *"Libur akhir pekan sudah dekat. Siapkan stok, dan pertimbangkan kampanye iklan!"* |

---

## **11.5 Tombol Aksi Setelah Daily Summary**

Setelah pemain selesai membaca laporan, tiga tombol besar muncul di bagian bawah layar dengan desain *pill button* cozy:

| Tombol | Ikon | Fungsi |
| :--- | :---: | :--- |
| **🛒 Buka Pasar** | 🧺 | Shortcut after-hours ke Pasar. Pembelian bahan setelah toko tutup langsung masuk Gudang; mulai Hari 4 Pasar juga sudah bisa dibuka kapan saja dari Quick Menu saat hari berjalan. |
| **👷 Kelola Karyawan** | 📋 | Shortcut ke menu manajemen staf untuk hire, libur, atau upgrade karyawan |
| **⏭️ Lanjut ke Besok** | ☀️ | Lewati Pasar dan langsung lanjut ke hari berikutnya (bisa dilakukan jika stok sudah cukup) |

> **Catatan UX**: Tombol **"Continue to Next Day"** akan berwarna abu-abu/nonaktif jika stok bahan baku di gudang **kosong total**, memaksa pemain untuk setidaknya mampir ke Pasar sebelum melanjutkan permainan. Pengecualian: di akhir Hari 1 dan Hari 2 (stok tutorial hari berikutnya diisi otomatis saat hari itu dimulai) dan saat `bailout_pending = true` (bantuan Pak Lurah datang esok pagi), tombol tetap aktif.

---

## **11.6 Alur Transisi Lengkap (End-of-Day Flow)**

```
18:00 — Pintu Toko Tutup Otomatis
    ↓
Animasi Transisi: Karyawan beres-beres, lampu etalase dipadamkan satu per satu
    ↓
📊 Layar Daily Summary muncul (kertas nota bergaya vintage)
    ↓  
[Pemain membaca & menikmati laporan]
    ↓
[ Pilih Aksi ]
    ├──► 🛒 Buka Pasar Bahan Baku
    │        ↓
    │   Belanja bahan, beli/upgrade alat, upgrade toko
    │   (bahan yang dibeli setelah tutup langsung masuk Gudang)
    │        ↓
    │   Keluar Pasar → Lanjut ke Besok
    │
    ├──► 👷 Kelola Karyawan (lalu ke Pasar / Lanjut)
    │
    └──► ⏭️ Langsung Lanjut ke Besok
              ↓
         Animasi malam → Fajar → 05:00 Persiapan Hari Baru
```

---

## **11.7 Desain Visual Daily Summary (Warm, Cozy & Cute)**

Seluruh elemen Daily Summary dirender **100% prosedural** melalui `ProceduralUIFactory`:

* **Kertas Nota**: Panel `StyleBoxFlat` berlapis dengan warna krem `#FFF8EA`, efek *grain/noise* prosedural yang mensimulasikan tekstur kertas berserat vintage.
* **Font Typewriter**: Font rounded (*chunky cozy*) yang dirender dengan `Label` Godot, dengan efek muncul karakter per karakter (*typewriter reveal animation*) menggunakan `Tween` yang lambat dan menenangkan.
* **Garis Pemisah**: Digambar dengan `draw_line()` bergaya putus-putus (*dashed*) berwarna cokelat tinta lembut `#8C5835`.
* **Emoji Mood**: Wajah emoji digambar prosedural menggunakan `draw_circle()` + `draw_arc()` untuk ekspresi mata dan mulut yang berubah sesuai kondisi finansial.
* **Animasi Muncul**: Seluruh layar Daily Summary muncul dengan animasi *unfold* dari atas seperti kertas nota yang terbuka perlahan — digerakkan oleh `Tween` dengan easing `EASE_OUT`.
* **Suara Latar**: Saat Daily Summary terbuka, terdengar suara *"kertas direntangkan"* lembut, diikuti musik lo-fi menenangkan yang lebih pelan dari saat jam jualan.



# **12\. Spesifikasi Teknis & Multiplatform (Godot 4.7)**

Game ini dikembangkan menggunakan **Godot Engine 4.7-stable Standard dengan GDScript dan Compatibility renderer** dengan fokus rilis ganda: **Web Browser (itch.io)** dan **Mobile Android (Google Play Store)** dari satu basis kode (single codebase).

## **12.1 Target & Deployment Platform**

* **Web Browser (itch.io)**:
  * **Format Ekspor**: HTML5 / WebAssembly / WebGL2.
  * **Hosting di itch.io**: Mendukung embed iframe, tombol mode layar penuh (fullscreen toggle), dan responsive scaling.
  * **Optimasi Ukuran Bundle**: Target ukuran file awal (initial download) di bawah 30–40 MB agar waktu pemuatan di browser cepat dan tidak membebani kuota pemain.
  * **Kebijakan Audio Browser (Autoplay Policy)**: Menyediakan splash screen / tombol pembuka *"Klik / Tap untuk Mulai"* agar audio browser terinisialisasi secara legal tanpa diblokir oleh browser.
* **Mobile Android (Google Play Store)**:
  * **Format Ekspor**: Android App Bundle (`.aab`) dengan dukungan arsitektur `arm64-v8a` (64-bit) dan `armeabi-v7a` (32-bit).
  * **Standar Google Play**: Memenuhi target API level terbaru sesuai regulasi Google Play Console (Target SDK terkini).
  * **Siklus Hidup Aplikasi (Android Lifecycle)**: Fitur auto-pause saat aplikasi beralih ke background (misal: saat menerima panggilan telepon atau menekan tombol home).
  * **Penanganan Tombol Back Android**: Tombol navigasi / gestur "Back" pada perangkat Android dapat digunakan untuk menutup dialog / pop-up menu yang aktif, atau menampilkan dialog konfirmasi keluar di menu utama.

## **12.2 Rendering Pipeline & Optimasi Grafis**

* **Mode Renderer Godot: Compatibility (`gl_compatibility` / OpenGL ES 3.0 / WebGL 2.0)**:
  * *Rasional*: Renderer Vulkan (`Mobile` / `Forward+`) di Godot 4 memerlukan WebGPU yang belum stabil dan belum didukung secara luas di browser web (HTML5 itch.io) serta sering mengalami kendala performa pada ponsel Android entry-level. Renderer *Compatibility* memastikan performa stabil 60 FPS di kedua platform tanpa glitch visual.
* **Generasi Aset 100% Prosedural (Zero Asset Overhead)**:
  * Karena seluruh model 3D dan visual 2D dibuat murni melalui kode, tidak ada aset gambar (.png/.jpg) atau model 3D (.gltf/.obj) eksternal yang perlu diunduh atau disimpan dalam package game.
  * Menghasilkan efisiensi memori (VRAM) yang luar biasa di smartphone Android dan loading time hampir instan di browser Web itch.io.
* **Budget Geometri & Shading**:
  * Geometri dibentuk secara matematis dengan jumlah poligon terkontrol (500 – 2.000 tris per perakitan objek).
  * Shading menggunakan `StandardMaterial3D` berbasis parameter warna solid/roughness dan vertex coloring, meminimalkan kompleksitas komputasi GPU.

## **12.3 Arsitektur Pemrograman Prosedural (Procedural Pipeline)**

Untuk menjaga kode tetap modular, bersih, dan mudah di-maintain, seluruh pembentukan visual dipisahkan ke dalam kelas-kelas factory khusus:

1. **`ProceduralMeshFactory` (Pembangkit Objek 3D)**:
   * Menggunakan modulasi primitif (`BoxMesh`, `CylinderMesh`, `SphereMesh`, `TorusMesh`) dan `SurfaceTool` untuk merakit objek 3D secara dinamis.
   * Parameterisasi Tier: Peralatan dapur (Mixer, Oven, Display) dan tata ruang toko memiliki parameter generator yang langsung mengubah bentuk fisik dan warna materialnya saat pemain melakukan upgrade tier (misal: Tier 1 Oven Tangkring manual $\rightarrow$ Tier 5 Conveyor Belt Oven otomatis).
   * Generator Bentuk Roti: Membentuk mesh roti tawar, donat bulat bolong, croissant berlapis, hingga sourdough artisanal secara matematis, termasuk perubahan warna panggang (*baking shade*).
   * Generator Karakter: Merakit karakter *chibi* (kepala, badan, topi koki, celemek) dengan randomisasi warna kulit, rambut, dan pakaian—termasuk **karakter pemain** (Pria/Wanita) dan barang bawaannya (mangkuk adonan, loyang roti).
   * Generator Gudang Penyimpanan: Diparameteri **tier lokasi**, bukan tier alat, karena ia sepaket dengan bangunan. Seluruh unitnya berjajar sebaris dengan pintu menghadap depan.
2. **`ProceduralAnimationSystem` (Animasi Berbasis Kode)**:
   * Menghilangkan kebutuhan rig skeleton 3D eksternal.
   * Animasi berjalan menggunakan modulasi fungsi trigonometri matematika (`sin(time * speed)` untuk ayunan kaki & tangan, serta anggukan kepala).
   * Interaksi dapur (adukan mixer memutar, pintu oven berayun, reaksi emosional pelanggan melompat gembira atau menggeleng kecewa) digerakkan oleh `Tween` bawaan Godot (*squash & stretch interpolation*).
3. **`ProceduralUIFactory` (Pembangkit UI & Grafis 2D)**:
   * Pembuatan seluruh komponen UI (tombol rounded, panel modal, kartu staf, frame resep, kertas nota Daily Summary) memanfaatkan `StyleBoxFlat` dengan *corner radius*, warna tema pastel, dan bayangan (*drop shadow*) dinamis.
   * Rendering Ikon Vektor: Ikon-ikon in-game (koin emas, bintang rating, jam dinding, balon pesanan, ikon hati/marah, emoji mood Daily Summary) digambar secara prosedural menggunakan fungsi CanvasItem `_draw()` (`draw_circle`, `draw_arc`, `draw_line`, `draw_colored_polygon`).
   * Pasar Bahan Baku: Tampilan katalog bahan baku dengan harga tetap, kartu item berpola rounded lembut, ikon bahan prosedural, serta bar visual kapasitas penyimpanan gudang (*pantry bar*).
   * Potret Karakter: Potret chibi pada layar pemilihan karakter digambar dengan `_draw()` (lingkaran dan poligon), bukan hasil render 3D—dua gambar diam tidak sepadan dengan biaya satu `SubViewport`.
4. **Lapisan Tugas Pemain (`PlayerTaskSystem`)**:
   * Menerjemahkan **ketukan** pemain di dunia 3D menjadi perintah produksi, dan sebaliknya menerjemahkan keadaan produksi menjadi penanda yang mengambang di atas perabot.
   * Rantai satu pesanan: gudang → mixer → oven → rak. Alat yang selesai menahan isinya, dan tanda seru **tetap di alat itu** sampai isinya diambil. Tanda baru berpindah ke stasiun berikutnya setelah barangnya benar-benar ada di tangan karakter (Seksi 2, 18.6).
   * Beberapa pesanan berjalan sekaligus; yang antre hanyalah kaki karakter.
   * Perabot yang **tidak** sedang menunggu pekerjaan tetap dihampiri saat diketuk—perabot di dunia 3D adalah tombolnya sendiri, dan tombol yang kadang menjawab kadang tidak membuat pemain mengira ketukannya tidak terbaca.
5. **Navigasi Aktor (`ShopWorld`)**:
   * Aktor berjalan di **kisi ubin yang sama** dengan Mode Dekorasi, bukan di atas collider fisika. Perabot di proyek ini memang tidak punya collider, dan menambahkannya hanya demi tabrakan pejalan kaki berarti dua sumber kebenaran bentuk per perabot yang pasti berbeda diam-diam.
   * Petak terhuni ditandai pada `AStarGrid2D`, lalu rute hasilnya diluruskan kembali dengan uji garis pandang supaya karakter tidak melangkah zig-zag dari pusat ubin ke pusat ubin.

## **12.4 Skema Kontrol Universal (Tap-First & Mouse)**

* **Prinsip Kontrol Sentuh Universal**: Seluruh mekanisme gameplay (klik balon pesanan kasir, mengambil bahan, memilih resep, navigasi menu) dirancang 100% dapat dioperasikan hanya dengan satu jari (layar sentuh Android) atau satu klik kiri mouse (browser PC).
* **Perabot Adalah Tombolnya Sendiri**: Gudang Penyimpanan, Mixer, Oven, Rak Display, dan Meja Kasir semuanya bisa diketuk langsung di dunia 3D. Ketukan dihitung saat jari **dilepas** dan hampir tidak bergeser, sehingga usaha menggeser layar tidak pernah salah terbaca sebagai perintah.
* **Bebas Ketergantungan Keyboard**: Tidak ada kontrol krusial yang mewajibkan tombol keyboard fisik. Shortcut keyboard (seperti tombol Spasi atau Esc) hanya disediakan sebagai fitur tambahan (*Quality-of-Life*) pada versi Web.

## **12.5 Orientasi & Tampilan Layar Responsif**

* **Orientasi**: Landscape (16:9 resolusi referensi 1280x720 / 1920x1080).
* **Mode Stretch Godot**: `canvas_items` dengan konfigurasi aspect `expand` agar tata letak UI menyesuaikan berbagai rasio layar ponsel (18:9, 19.5:9, 20:9) maupun jendela browser tanpa distorsi atau gambar gepeng.

## **12.6 Sistem Penyimpanan Data (Save System)**

* **Abstraksi Path Virtual `user://`**:
  * **Web (itch.io)**: Otomatis dipetakan oleh Godot Web Export ke IndexedDB browser, sehingga progres pemain tersimpan selama cache/data situs tidak dibersihkan.
  * **Android**: Disimpan ke direktori internal privat aplikasi.
  * Ada tepat **tiga profil save** independen. Path dan skema canonical: Seksi 89.3 dan 106.
* **Format Data**: Berbasis JSON serializable yang ringan, portabel, dan tahan terhadap pembaruan versi game (*backward compatible*).

## **12.7 Distribution & Monetization — Final**

- Game v1.0 sepenuhnya offline dan tidak membutuhkan login, backend, telemetry network, remote config, atau koneksi internet untuk gameplay.
- Tidak ada ads, rewarded ads, interstitial ads, IAP, premium currency, loot box, battle pass, energy timer, atau paid gameplay boost.
- itch.io: Web build dapat dirilis gratis, berbayar, atau pay-what-you-want sesuai keputusan publisher di luar gameplay.
- Google Play: distribusi menggunakan Android App Bundle; harga aplikasi/store listing adalah keputusan distribusi dan **tidak mengubah simulation rules**.
- RotiFood, market, weather, dan seluruh sistem online-looking di dalam game hanyalah simulasi lokal.

---

# **13. AI Implementation Contract & Document Governance**

Bagian ini menjadikan GDD sebagai spesifikasi kerja yang dapat diberikan langsung kepada AI implementor tanpa mengandalkan asumsi tersembunyi.

## **13.1 Decision Status — Final**

Semua aturan aktif di dokumen v3.1 FINAL berstatus **CANONICAL**. Tidak ada `PROVISIONAL`, `UNRESOLVED`, atau `DEFERRED` requirement. Catatan historis tidak memiliki authority dan tidak boleh dipakai oleh implementation agent.

## **13.2 Prinsip Source of Truth**

- Tidak boleh ada dua seksi aktif yang saling bertentangan. Kontradiksi yang tersisa adalah validation failure (Seksi 13.4), bukan sesuatu yang diselesaikan dengan urutan prioritas.
- Saat mencari jawaban implementasi, urutan authority mengikuti Seksi 126.2.
- Bagian **AI Implementation Contract** ini lebih tinggi prioritasnya daripada asumsi implementor.
- Jika konflik baru muncul karena perubahan kode, implementor harus berhenti pada aturan canonical dan tidak membuat desain pengganti sendiri.

## **13.3 Larangan Asumsi Diam-Diam**

AI implementor dilarang:

- Mengubah genre, sudut kamera, pacing harian, atau core loop tanpa instruksi baru.
- Mengganti sistem karakter berjalan menjadi menu-only automation.
- Menghapus risiko roti gosong hanya karena dianggap menyulitkan.
- Mengubah fixed-price ingredients menjadi pasar dinamis.
- Menambahkan game over permanen.
- Mengubah properti menjadi sistem sewa harian.
- Menambahkan kebutuhan keyboard sebagai kontrol wajib.
- Mengimpor aset PNG/JPG/GLTF/FBX/OBJ sebagai ketergantungan gameplay utama.
- Mengubah gaya karakter chibi menjadi realistis.
- Membuat pelanggan makan di tempat; game ini 100% takeaway.
- Menggabungkan rating toko fisik dan rating RotiFood menjadi satu skor.

## **13.4 No-Legacy Rule**

Dokumen v3.1 FINAL tidak menggunakan mekanisme "aturan baru mengalahkan aturan lama" untuk implementasi. Aturan obsolete harus dihapus dari badan dokumen. Jika dua bagian aktif masih bertentangan, itu adalah **validation failure** dan project tidak boleh lanjut ke release sampai kontradiksi dibersihkan.

## **13.5 Definition of Done untuk AI Implementor**

Sebuah fitur dianggap selesai hanya jika:

- Gameplay behavior sesuai state machine pada dokumen ini.
- Tidak ada input penting yang hanya bekerja dengan keyboard.
- Berjalan di Web export dan Android target.
- State penting bisa disimpan dan dimuat kembali.
- Tidak ada visual gameplay yang bergantung pada aset eksternal terlarang.
- Edge case utama memiliki test case.
- Angka balance berada di resource/data, bukan tersebar sebagai magic number.
- Error state gagal dengan aman dan tidak merusak save.
- UI memberi feedback ketika aksi tidak bisa dilakukan.

---

# **14. Product Pillars, Scope, dan Non-Goals**

## **14.1 Product Pillars**

Empat pilar berikut harus tetap terasa pada setiap fitur:

1. **Physical Management** — pemain benar-benar melihat karakter berjalan, membawa bahan, dan berpindah stasiun.
2. **Cozy Pressure** — ada tekanan operasional, tetapi kegagalan tidak menghukum secara permanen.
3. **Readable Automation** — staf membuat operasi lebih ringan tanpa menghilangkan keterbacaan sebab-akibat.
4. **Procedural Warmth** — visual sederhana namun hidup, lembut, dan konsisten karena dibangun dari kode.

## **14.2 Target Session**

- Satu hari penuh in-game: ±39 menit nyata sesuai rasio 1 jam in-game = 3 menit nyata.
- Satu sesi pendek yang wajar: 1 hari in-game.
- Sesi menengah: 2–3 hari in-game.
- Game harus aman dipause kapan saja tanpa menghukum pemain.

## **14.3 Non-Goals MVP**

Fitur berikut tidak boleh dianggap wajib pada versi pertama hanya karena tersirat oleh tema:

- Dine-in / meja makan pelanggan.
- Sistem minuman lengkap.
- Multiplayer.
- PvP atau leaderboard kompetitif.
- Trading bahan dengan pemain lain.
- Ekonomi harga bahan dinamis.
- Sistem kredit, bunga, atau utang bank.
- Kustomisasi bangunan bebas voxel.
- Voice acting penuh.
- Cutscene sinematik kompleks berbasis skeletal animation.
- Cloud save lintas perangkat.

---

# **15. Macro Game State & Day State Machine**

## **15.1 Global Game States**

Gunakan state tingkat tinggi berikut:

```text
BOOT
  -> MAIN_MENU
  -> CHARACTER_SELECT (New Game only)
  -> DAY_PREPARATION
  -> DAY_OPEN
  -> DAY_CLOSING
  -> DAILY_SUMMARY
  -> AFTER_HOURS_MANAGEMENT
  -> NEXT_DAY_TRANSITION
  -> DAY_PREPARATION
```

Overlay states yang dapat muncul tanpa mengganti state utama:

```text
PAUSED
MODAL_OPEN
TUTORIAL_BLOCKER
SETTINGS_OPEN
CONFIRM_DIALOG
```

## **15.2 Waktu In-Game**

- Start hari: 05:00.
- Auto-open: 08:00.
- Auto-close: 18:00.
- 1 jam in-game = 180 detik nyata.
- 1 menit in-game = 3 detik nyata.
- Waktu **berhenti** saat pause global atau modal yang bersifat blocking.
- Waktu **berhenti** pada seluruh management menu blocking sesuai Seksi 71 dan pada setiap popup keputusan (lihat CANONICAL di bawah).

**CANONICAL:** Semua menu/popup yang meminta keputusan pemain—termasuk Recipe Book, Display Slot Picker, transaction/order confirmation, Market, Staff, Marketing, Upgrade, Decoration, Settings, dan Daily Summary—mendorong pause reason ke `PauseManager`. Jam, patience, oven/mixer, delivery ETA, dan actor simulation berhenti sampai modal ditutup. Aksi yang dijalankan setelah pemain menekan OK (mis. animasi membungkus atau packing) kembali berjalan di simulation time. HUD tooltip non-interaktif tidak mem-pause.

## **15.3 Transition Rules**

### Preparation -> Open

Pada 08:00:

- Pintu toko membuka otomatis.
- Spawn pelanggan fisik diaktifkan.
- RotiFood order generator diaktifkan.
- Task produksi yang sedang berlangsung tidak dibatalkan.
- Karakter/staf mempertahankan posisi dan pekerjaan.

### Open -> Closing

Pada 18:00:

- Tidak ada pelanggan baru yang boleh spawn.
- Pesanan RotiFood baru berhenti masuk.
- Pelanggan yang belum membayar mengembalikan roti ke rak dengan state kualitas/umur tetap.
- Order online yang belum selesai ditandai sesuai aturan expiry/cancel.
- Task produksi aktif tidak dihapus dan tidak di-fast-resolve. State-nya dibekukan persis (termasuk timer dan burn window) dan berlanjut saat simulation kembali berjalan pukul 05:00 hari berikutnya (Seksi 104).

### Daily Summary -> After Hours

- Semua pemasukan/pengeluaran dibekukan untuk hari itu.
- Gaji dan utility charge diterapkan tepat satu kali.
- Statistik hari di-commit ke history.
- Check bailout dilakukan setelah settlement.

---

# **16. Player Character Controller & Task Queue**

## **16.1 Prinsip**

Karakter pemain bukan avatar bebas analog. Ia adalah **task-driven actor** yang bergerak menuju target hasil ketukan pemain.

## **16.2 Player Actor States**

```text
IDLE
WALKING
WAITING_FOR_PATH
INTERACTING
CARRYING
SERVING_CASHIER
PACKING_ORDER
BLOCKED
```

`CARRYING` adalah flag orthogonal dan bukan selalu state eksklusif; actor dapat `WALKING + carrying_item`.

## **16.3 Command Model**

Setiap tap valid menghasilkan `PlayerCommand`:

```gdscript
class_name PlayerCommand
var command_id: int
var target_id: StringName
var command_type: int
var issued_at_game_time: float
var required_empty_hands: bool
var required_carried_type: StringName
var cancellable: bool
var priority: int
```

## **16.4 Queue Policy**

**CANONICAL behavior intent:** yang mengantre adalah kaki karakter.

**CANONICAL implementation:**

- Maksimal **3 queued commands** per controllable actor.
- Ketukan pada target baru saat actor berjalan mengganti command tujuan terakhir jika command lama belum memasuki interaction lock.
- Task pengambilan yang sudah dimulai tidak boleh kehilangan item.
- Jika actor sedang membawa item, command yang tidak kompatibel ditolak dengan feedback visual kecil.
- Queue command disimpan sebagai logical target/action ID, bukan world transform mentah.

## **16.5 Hand Occupancy Rules**

- `carried_item = null` berarti tangan kosong.
- Satu actor hanya membawa satu container logis sekaligus.
- Container dapat mewakili beberapa unit roti dalam satu batch/loyang.
- Saat membawa mangkuk adonan, hanya Oven yang menerima delivery yang cocok.
- Saat membawa loyang matang, hanya Rak Display yang menerima delivery yang cocok.
- Item tidak boleh hilang jika path gagal; actor kembali ke state BLOCKED dan bubble target tetap aktif.

## **16.6 Interaction Range**

Interaksi terjadi pada `interaction_anchor` milik furniture, bukan pusat mesh. Setiap furniture harus memiliki anchor sisi depan yang dapat dijangkau actor tanpa menembus footprint.

## **16.7 Failure Feedback**

Jika tap gagal:

- Path tidak tersedia -> bubble kecil “jalan terhalang”.
- Tangan penuh -> icon tangan penuh.
- Alat sibuk -> icon jam pasir.
- Bahan tidak cukup -> icon bahan merah dan buka detail resep bila relevan.
- Rak penuh -> icon rak merah.

Tidak boleh ada tap yang terasa “mati” tanpa feedback.

---

# **17. Grid, World Layout, Placement, dan Navigation**

## **17.1 Grid Canonical**

- Satu grid cell adalah unit logis penempatan berukuran **0,5 m × 0,5 m (50 × 50 cm)**.
- Konstanta global: `WORLD_METERS_PER_TILE = 0.5`. Nilai ini tidak boleh dioverride per scene atau per tier.
- Semua furniture memiliki integer footprint `width x depth`; ukuran fisik X/Z = `footprint * 0.5 meter`.
- Grid menentukan occupancy; collider bukan source of truth.
- Ukuran lokasi pada Section 6 diberikan dalam meter dan harus dikonversi menjadi tile integer sebelum scene dibangun.
- Scene multi-floor memiliki grid terpisah per `floor_id`; hubungan antar lantai hanya melalui stair/transition link yang eksplisit.
- Object carried/decorative yang tidak menyentuh lantai secara mandiri tidak perlu menguasai cell, tetapi skalanya tetap mengikuti referensi 0,5 m per tile.

## **17.2 Cell Types**

```text
FLOOR_CUSTOMER
FLOOR_KITCHEN
FLOOR_STAFF_ONLY
FLOOR_WALKWAY_RESERVED
DOOR_CELL
COUNTER_FIXED
WALL
BLOCKED
```

## **17.3 Placement Validation**

Furniture placement valid jika seluruh cell footprint:

- Masuk area map.
- Tidak overlap furniture lain.
- Sesuai zone type.
- Tidak menutup door cell.
- Tidak memutus seluruh jalur antara entrance dan titik wajib pelanggan.
- Tidak memutus seluruh jalur karakter menuju storage, mixer, oven, display, dan cashier manual position.
- Menyisakan baris walkway belakang cashier sebagaimana aturan GDD.

## **17.4 Connectivity Validation**

Setelah drag preview berhenti:

1. Terapkan occupancy secara sementara.
2. Jalankan connectivity check pada graph.
3. Minimal satu path harus tersedia untuk setiap pasangan titik wajib.
4. Jika gagal, preview merah dan tampilkan alasan.
5. Furniture baru benar-benar di-commit saat drop valid.

## **17.5 AStarGrid2D**

- Update region hanya saat layout berubah, bukan setiap frame.
- Gunakan diagonal movement hanya jika corner-cutting dicegah.
- Setelah path ditemukan, lakukan line-of-sight smoothing.
- Repath jika target anchor berubah atau cell menjadi blocked sebelum actor tiba.

## **17.6 NPC Separation**

Karena source of truth adalah grid, crowd separation tidak menggunakan rigid-body collision antar-NPC. Namun aturan queue bersifat lebih ketat:

- **Queue/checkout/pickup:** tepat satu actor per slot 1 × 1 tile. Actor **tidak boleh overlap atau menumpuk**. Actor berikutnya hanya maju setelah slot depan benar-benar dilepas.
- **Saat queue penuh:** spawn/admission pembeli atau Driver RotiFood baru ditahan; actor tidak boleh dibuat lalu dibiarkan bertumpuk di entrance.
- **Free walking di luar queue:** local visual avoidance/offset kecil boleh dipakai agar dua actor yang berpapasan tidak tampak menyatu, tetapi logical occupancy tujuan/interaksi tetap unik.
- Jangan gunakan physics impulse untuk memisahkan crowd karena dapat mendorong actor keluar dari grid/path canonical.

---

# **18. Production Job System**

## **18.1 ProductionJob Data**

Setiap batch yang dipesan dari Buku Resep menjadi satu `ProductionJob`.

```gdscript
class_name ProductionJob
var job_id: int
var recipe_id: StringName
var batch_multiplier: int
var quantity_output: int
var stage: int
var reserved_ingredients: Dictionary
var mixer_id: StringName
var oven_id: StringName
var created_at: float
var quality_state: Dictionary
var owner_actor_id: StringName
```

## **18.2 Job Stages**

```text
ORDERED
WAITING_FOR_MIXER
MIXING
MIX_DONE_WAITING_PICKUP
CARRIED_TO_OVEN
BAKING
BAKE_DONE_WAITING_PICKUP
OVERBAKING
CARRIED_TO_DISPLAY
PLACEMENT_UI
ON_DISPLAY
FAILED
```

`MIXING` mencakup mix dan prep resep (Seksi 18.5). Tidak ada stage prep terpisah.

## **18.3 Ingredient Reservation**

Bahan dipotong **saat pemain mengonfirmasi pembuatan batch**, sesuai aturan asli. Karena itu:

- Stok langsung berkurang.
- Job yang dibatalkan sebelum tahap `MIXING` dimulai mengembalikan seluruh bahan. Setelah `MIXING` dimulai, bahan tidak dapat direfund (Seksi 61.4).
- Jika job gagal karena bug/pathing, sistem harus refund melalui recovery routine agar save tidak rusak.

## **18.4 Station Capacity**

Setiap Mixer/Oven memiliki:

```text
station_id
station_type
station_tier
current_job_id
state
process_speed_multiplier
utility_rate
interaction_anchor
footprint
```

Untuk MVP satu alat memproses satu job pada satu waktu, walaupun narasi alat seperti Deck Oven menyebut dua tray. Kapasitas >1 hanya boleh diaktifkan jika data field `parallel_slots` benar-benar didefinisikan dan UI mampu menunjukkan tiap slot.

## **18.5 Progress Timing**

**CANONICAL:** durasi tiap tahap = waktu dasar resep (Seksi 61.5) × rasio waktu referensi alat (Seksi 5.1) × batch multiplier ÷ kecepatan kerja staf.

```text
mixer_stage_seconds = max(1.0,
    (mix_seconds_base + optional_prep_seconds)
  × mixer_reference_seconds[active_mixer_tier] / mixer_reference_seconds[required_mixer_tier]
  × batch_multiplier / staff_work_speed)

oven_stage_seconds = max(1.0,
    bake_seconds_base
  × oven_reference_seconds[active_oven_tier] / oven_reference_seconds[required_oven_tier]
  × batch_multiplier / staff_work_speed)
```

- `mixer_reference_seconds` / `oven_reference_seconds` = waktu proses per tier pada Seksi 5.1.
- Alat dengan tier di bawah `required_mixer_tier` / `required_oven_tier` tidak dapat menerima job resep tersebut (Seksi 61.1).
- `batch_multiplier` = 1 / 3 / 5 (Seksi 18.9).
- `staff_work_speed` = `work_speed_multiplier` Asisten Dapur yang memulai tahap itu (Seksi 3.2). Tahap yang dimulai karakter pemain memakai `1.0`. Nilainya dikunci saat tahap dimulai.
- Setiap modifier diterapkan tepat satu kali. Durasi akhir tidak pernah kurang dari 1.0 simulation-second.
- `optional_prep_seconds` dijalankan di Mixer sebagai bagian akhir tahap `MIXING` (shaping, filling, laminasi, fermentasi). Mixer tetap occupied, dan satu progress bar mencakup mix + prep. Tidak ada stage atau station prep terpisah.
- `recipe_total_time` = mix + prep + bake pada tier minimum. Nilai ini ringkasan desain untuk balancing/UI, **bukan timer kedua**.

Contoh non-canonical: Roti Goreng Polos di Mixer T1 + Oven T1 = 14 s + 21 s. Di Mixer T3 + Oven T3 menjadi `14 × 10/20 = 7 s` dan `21 × 15/30 = 10.5 s`. Croissant Klasik di Mixer T3 = `22.5 + 18.75 = 41.25 s`; bila dimulai Asisten Dapur 1.60×, menjadi ±25.8 s.

## **18.6 Completion Lock**

Saat mixer selesai:

- Timer berhenti.
- Job masuk `MIX_DONE_WAITING_PICKUP`.
- Mixer tetap occupied.
- Bubble “!” tetap di mixer sampai isi diambil.

Saat oven selesai:

- Job masuk `BAKE_DONE_WAITING_PICKUP`.
- Burn timer mulai.
- Oven tetap occupied sampai loyang diambil.

## **18.7 Burn Logic**

**CANONICAL:** Burn timing mengikuti tabel final per oven tier pada Seksi 62. State minimum adalah `READY_PERFECT`, `OVERBAKE_WARNING`, dan `BURNT`. `BURNT` tidak boleh ditaruh di display; tray dibuang sebagai waste saat diambil. Visual browning harus mengikuti normalized burn progress.

Auto-Retrieve baker melakukan check tepat pada completion event sesuai chance tier.

## **18.8 Auto-Retrieve Resolution**

- Roll chance satu kali per job saat oven selesai (transisi ke `READY_PERFECT`), memakai `staff_rng` (Seksi 116). Roll hanya berlaku untuk job yang tahap ovennya dimulai Asisten Dapur; job yang dimulai karakter pemain tidak di-roll.
- Jika sukses: job **terlindung dari gosong**. Burn timer dibekukan sampai baker mengambil tray, lalu baker mengirimnya ke display sesuai mode kerjanya.
- Jika baker sedang membawa item lain, pengambilan masuk priority queue dan tidak dianggap gagal; perlindungan gosong tetap berlaku sampai tray diambil.
- Jika gagal: baker tidak mengambil tray itu. Tanda "!" dan alert Oven Ready menunggu pemain, dan burn timer berjalan normal (Seksi 3.2, 62).
- Tier 5 100% berarti tidak melakukan RNG; selalu sukses.

## **18.9 Batch Multiplier**

Tombol x1/x3/x5:

- Mengalikan ingredients.
- Mengalikan output.
- Tidak otomatis mengalikan jumlah alat paralel.
- **CANONICAL:** x3/x5 membuat satu production job besar; ingredient, yield, mixing duration, dan baking duration dikalikan linear oleh batch multiplier. Satu equipment memproses satu logical job pada satu waktu kecuali data equipment di revisi masa depan secara eksplisit memiliki `parallel_job_slots > 1`.

---

# **19. Bread Item, Display, Freshness, dan Quality Model**

## **19.1 BreadStack Entity**

Roti di display tidak perlu menjadi node individual per unit. Gunakan stack data per recipe + quality bucket.

Ini satu-satunya skema `BreadStack`:

```gdscript
class_name BreadStack
var recipe_id: StringName
var quantity: int
var slot_id: StringName
var source_job_id: int
var produced_at_game_time: float   # urutan FIFO (Seksi 19.5)
var bake_quality: float            # 0.0..1.0, dari proses oven (Seksi 62)
var age_ingame_hours: float        # usia sejak masuk Display (Seksi 19.7)
var base_expiry_hours: float       # dari recipe (Seksi 61.3)
var freshness_state: StringName    # FRESH / GOOD / STALE / UNSALEABLE
var display_tier: int              # tier rak tempat stack berada saat ini
```

`freshness_score` (Seksi 19.7.1) adalah nilai turunan dan tidak disimpan.

## **19.2 Display Slots**

Setiap rak memiliki sejumlah petak logis. UI penempatan harus membaca slot aktual dari rak, bukan angka hard-coded enam bila tier rak berbeda.

## **19.3 Slot Rules**

- Satu slot boleh menampung satu jenis recipe per stack utama.
- Batch boleh dibagi ke beberapa slot.
- Jika slot berisi recipe sama dan quality bucket kompatibel, quantity dapat digabung.
- Jika slot penuh, sisa tray tetap dibawa actor sampai ditempatkan atau player memilih slot lain.

## **19.4 Capacity**

Kapasitas rak adalah unit roti total per furniture. Jangan menyamakan jumlah petak dengan kapasitas unit.

## **19.5 FIFO Consumption**

**CANONICAL:** customer/packing mengambil unit tertua yang masih sellable untuk recipe yang sama (**FIFO by `produced_at_game_time`**) agar stock rotation konsisten.

## **19.6 Return-to-Shelf**

Jika pelanggan pergi sebelum membayar:

- Unit kembali ke slot asal jika masih tersedia.
- Jika slot asal tidak valid karena layout berubah (layout seharusnya terkunci saat open), cari slot recipe sama.
- Freshness tidak direset.
- Quality tidak direset.

## **19.7 Freshness & Shelf-Life — FINAL CANONICAL**

Freshness hanya berlaku **setelah roti berhasil masuk Display**. Sistem freshness terpisah dari `bake_quality`: roti dapat matang sempurna tetapi sudah tua/stale, atau baru matang namun kualitas bake-nya buruk. Jangan menggabungkan keduanya ke satu variabel.

Field freshness setiap stack (`bake_quality`, `age_ingame_hours`, `base_expiry_hours`, `freshness_state`, `display_tier`) mengikuti skema `BreadStack` di Seksi 19.1.

### **19.7.1 Freshness State**

Gunakan rasio usia terhadap umur simpan efektif:

```text
age_ratio = age_ingame_hours / effective_expiry_hours

0.00 <= ratio <= 0.40  -> FRESH
0.40 <  ratio <= 0.70  -> GOOD
0.70 <  ratio <  1.00  -> STALE
ratio >= 1.00           -> UNSALEABLE
```

`freshness_score` boleh diturunkan linear dari `100 -> 0` untuk UI/internal scoring:

```text
freshness_score = clamp(100 × (1 - age_ratio), 0, 100)
```

Pemain **tidak perlu melihat countdown per unit**. Display/recipe detail cukup menunjukkan label state dan estimasi waktu tersisa hingga expired. Stack yang dibuat pada waktu berbeda tidak boleh digabung jika penggabungan akan menghilangkan umur batch; gunakan bucket umur atau weighted grouping yang mempertahankan FIFO.

### **19.7.2 Display Preservation Multiplier**

Tier Display memperlambat aging, sehingga upgrade display memiliki fungsi selain kapasitas:

| Display Tier | Aging Rate | Effective Shelf-Life |
|---|---:|---:|
| `display_t1` | 1.00× | base × 1.00 |
| `display_t2` | 0.90× | base ÷ 0.90 (~1.11×) |
| `display_t3` | 0.80× | base ÷ 0.80 (1.25×) |
| `display_t4` | 0.70× | base ÷ 0.70 (~1.43×) |
| `display_t5` | 0.60× | base ÷ 0.60 (~1.67×) |

Formula canonical:

```text
effective_age_delta = elapsed_ingame_hours × display_aging_rate
age_ingame_hours += effective_age_delta
```

Jika roti berpindah display, aging rate berikutnya menggunakan display baru; usia yang sudah terakumulasi **tidak pernah di-reset**.

### **19.7.3 Overnight Leftovers**

Leftover **bertahan lintas hari** selama belum expired. Saat toko tutup pukul 18:00 dan hari berikutnya dimulai pukul 05:00, sistem menerapkan aging sebesar **11 jam in-game** dengan aging-rate display tempat roti disimpan.

Urutan rollover hari:
1. Simpan state display pukul 18:00.
2. Terapkan `overnight_elapsed = 11.0 ingame hours`.
3. Hitung freshness baru untuk setiap stack.
4. Stack yang mencapai `UNSALEABLE` otomatis dikeluarkan dari display saat persiapan pagi.
5. HPP unit yang dibuang dicatat sebagai `waste_cost_kr` pada laporan hari berikutnya / rollover summary.
6. Tidak ada denda reputasi tambahan hanya karena membuang roti; kehilangan modal produksi sudah menjadi konsekuensi ekonominya.

### **19.7.4 Customer Reaction**

- `FRESH`: attractiveness/freshness multiplier **1.00**.
- `GOOD`: multiplier **0.92**.
- `STALE`: multiplier **0.55**; pelanggan premium (`The Snob`, Socialita/Crazy Rich, Food Vlogger/Critic) **menolak** stale bread.
- `UNSALEABLE`: tidak pernah muncul sebagai opsi pembelian dan tidak dapat dibayar di kasir/RotiFood.
- Pemain tetap dapat menurunkan harga manual untuk membantu menjual stok STALE; tidak ada auto-discount tersembunyi.
- Jika customer sudah mengambil unit lalu state berubah menjadi UNSALEABLE sebelum pembayaran (edge case speed/pause/save), unit ditolak saat validation dan dikembalikan ke disposal, bukan dijual.

### **19.7.5 Manual Disposal**

Pemain boleh membuka detail Display dan memilih **Discard Stale/Expired**. `UNSALEABLE` selalu dapat dibuang; `STALE` boleh dibuang sukarela. Tidak ada refund bahan.

## **19.8 Burned Bread Sales — FINAL**

Aturan burn mengikuti Seksi 62. `BURNT` memiliki `bake_quality = 0` dan **tidak dapat dijual**. Batch burnt harus diambil dari oven lalu otomatis masuk disposal. Burned bread tidak masuk sistem freshness karena tidak pernah menjadi produk jual valid.

## **19.9 Freshness Persistence Contract**

Save/load wajib mempertahankan `age_ingame_hours`, `base_expiry_hours`, `freshness_state`, lokasi display, dan timestamp simulation yang relevan. Load tidak boleh mereset usia atau memberi shelf-life baru. Save yang dibuat pukul 18:00 sebelum day rollover harus menerapkan overnight aging tepat satu kali saat transisi hari; gunakan `last_freshness_rollover_day` untuk mencegah double-aging.

---

# **20. Customer Simulation Specification**

## **20.1 Customer Lifecycle**

```text
SPAWNING
ENTERING
BROWSING
SELECTING
CARRYING_TO_QUEUE
QUEUING
FRONT_OF_QUEUE
BEING_SERVED
PAYING
CELEBRATING
LEAVING
ABANDONING
RETURNING_ITEMS
DESPAWNED
```

## **20.2 Customer Archetype Data**

```gdscript
class_name CustomerArchetype
var id: StringName
var patience_seconds: float
var budget_profile: StringName
var preferred_recipe_tags: Array[StringName]
var min_quality: int
var min_purchase: int
var max_purchase: int
var arrival_time_weights: Dictionary
var price_sensitivity: float
var queue_stress_multiplier: float
var rating_weight: float
```

## **20.3 Day 1–3 Scripted Spawn**

Hari 1–3 harus menggunakan manifest deterministik yang menyimpan:

```text
day
spawn_time
customer_archetype
requested_recipe_id
requested_quantity
patience_override
```

Random generator umum tidak boleh memengaruhi manifest onboarding.

Manifest canonical berikut adalah satu-satunya jadwal Hari 1–3. Satu baris pembeli = satu pelanggan fisik yang membeli `requested_quantity` unit. Satu baris RotiFood = satu pesanan berisi `requested_quantity` unit resep hari itu. Semua baris memakai `patience_override = null`, sehingga patience mengikuti Seksi 58. Total tiap hari wajib sama dengan tabel pembukaan di Seksi 2 dan dengan stok bahan yang disediakan (`batches × batch_yield`).

### **20.3.1 Hari 1 — `recipe_plain_loaf`, 6 batch = 36 unit**

| # | spawn_time | customer_archetype | requested_recipe_id | requested_quantity |
| :---: | :---: | :--- | :--- | :---: |
| 1 | 08:30 | `customer_school_child` | `recipe_plain_loaf` | 2 |
| 2 | 09:15 | `customer_school_child` | `recipe_plain_loaf` | 2 |
| 3 | 10:00 | `customer_bulk_buyer` | `recipe_plain_loaf` | 6 |
| 4 | 11:00 | `customer_school_child` | `recipe_plain_loaf` | 2 |
| 5 | 12:00 | `customer_indecisive` | `recipe_plain_loaf` | 2 |
| 6 | 13:30 | `customer_bulk_buyer` | `recipe_plain_loaf` | 8 |
| 7 | 15:00 | `customer_school_child` | `recipe_plain_loaf` | 2 |
| 8 | 16:30 | `customer_school_child` | `recipe_plain_loaf` | 2 |

| # | RotiFood order_time | requested_recipe_id | requested_quantity |
| :---: | :---: | :--- | :---: |
| 1 | 09:45 | `recipe_plain_loaf` | 4 |
| 2 | 14:00 | `recipe_plain_loaf` | 6 |

Total Hari 1: 8 pembeli (26 unit) + 2 pesanan RotiFood (10 unit) = 36 unit.

### **20.3.2 Hari 2 — `recipe_plain_fried_bread`, 7 batch = 42 unit**

| # | spawn_time | customer_archetype | requested_recipe_id | requested_quantity |
| :---: | :---: | :--- | :--- | :---: |
| 1 | 08:20 | `customer_office_worker` | `recipe_plain_fried_bread` | 2 |
| 2 | 09:00 | `customer_school_child` | `recipe_plain_fried_bread` | 2 |
| 3 | 09:40 | `customer_bulk_buyer` | `recipe_plain_fried_bread` | 7 |
| 4 | 10:30 | `customer_school_child` | `recipe_plain_fried_bread` | 2 |
| 5 | 11:30 | `customer_indecisive` | `recipe_plain_fried_bread` | 2 |
| 6 | 12:30 | `customer_bulk_buyer` | `recipe_plain_fried_bread` | 9 |
| 7 | 14:00 | `customer_school_child` | `recipe_plain_fried_bread` | 2 |
| 8 | 15:30 | `customer_office_worker` | `recipe_plain_fried_bread` | 2 |
| 9 | 16:40 | `customer_school_child` | `recipe_plain_fried_bread` | 2 |

| # | RotiFood order_time | requested_recipe_id | requested_quantity |
| :---: | :---: | :--- | :---: |
| 1 | 09:20 | `recipe_plain_fried_bread` | 5 |
| 2 | 12:00 | `recipe_plain_fried_bread` | 3 |
| 3 | 15:00 | `recipe_plain_fried_bread` | 4 |

Total Hari 2: 9 pembeli (30 unit) + 3 pesanan RotiFood (12 unit) = 42 unit.

### **20.3.3 Hari 3 — `recipe_sugar_donut`, 9 batch = 45 unit**

| # | spawn_time | customer_archetype | requested_recipe_id | requested_quantity |
| :---: | :---: | :--- | :--- | :---: |
| 1 | 08:15 | `customer_school_child` | `recipe_sugar_donut` | 2 |
| 2 | 08:50 | `customer_office_worker` | `recipe_sugar_donut` | 2 |
| 3 | 09:30 | `customer_bulk_buyer` | `recipe_sugar_donut` | 8 |
| 4 | 10:20 | `customer_school_child` | `recipe_sugar_donut` | 2 |
| 5 | 11:10 | `customer_indecisive` | `recipe_sugar_donut` | 2 |
| 6 | 12:00 | `customer_bulk_buyer` | `recipe_sugar_donut` | 10 |
| 7 | 13:10 | `customer_school_child` | `recipe_sugar_donut` | 2 |
| 8 | 14:20 | `customer_office_worker` | `recipe_sugar_donut` | 2 |
| 9 | 15:30 | `customer_school_child` | `recipe_sugar_donut` | 2 |
| 10 | 16:30 | `customer_indecisive` | `recipe_sugar_donut` | 2 |

| # | RotiFood order_time | requested_recipe_id | requested_quantity |
| :---: | :---: | :--- | :---: |
| 1 | 09:00 | `recipe_sugar_donut` | 4 |
| 2 | 11:40 | `recipe_sugar_donut` | 3 |
| 3 | 14:40 | `recipe_sugar_donut` | 4 |

Total Hari 3: 10 pembeli (34 unit) + 3 pesanan RotiFood (11 unit) = 45 unit.

## **20.4 Spawn Conditions Day 4+**

Base demand dipengaruhi oleh:

- Physical store rating.
- Weather physical multiplier.
- Marketing multiplier.
- Time-of-day archetype weight.
- Tier location capacity.
- Event modifier.

Simpan formula dalam satu service agar tidak tersebar.

## **20.5 Store & Queue Capacity (Canonical)**

Kapasitas masuk ditentukan oleh **jumlah slot antrean fisik yang tersedia**, bukan sekadar jumlah NPC aktif.

```text
queue_slot_count = layout/tier-defined capacity
occupied_slots <= queue_slot_count
1 actor = exactly 1 slot
```

Aturan wajib:

- Pelanggan fisik dan Driver Ojol harus memperoleh slot antrean valid sebelum boleh masuk ke interior/alur layanan.
- Tidak ada dua actor yang menempati slot yang sama.
- Actor tidak boleh overlap, menumpuk, atau membentuk kerumunan di entrance.
- Jika antrean tujuan penuh, spawn actor baru **ditahan**. Jangan membuat character body di pintu.
- Tier 1–2: physical customer dan Driver Ojol menggunakan kapasitas antrean utama yang sama.
- Tier 3+: dedicated ojol queue memiliki slot/capacity sendiri jika counter aktif.
- Scheduler mempertahankan urutan `pending_arrival` dan mencoba masuk kembali ketika `queue_slot_freed` dipancarkan.
- Actor yang masih pending belum mulai mengurangi patience dan tidak memberi rating penalty hanya karena belum dapat masuk.

Acceptance invariant:

```text
for every queue:
    unique(occupant_id per slot)
    no occupant without slot
    no new interior spawn when free_slot_count == 0
```

## **20.6 Product Selection**

Customer selection pipeline:

1. Buat daftar recipe yang tersedia di display.
2. Filter oleh minimum quality.
3. Weight berdasarkan preference tag.
4. Evaluasi harga terhadap budget/sensitivity.
5. Tentukan quantity dalam batas archetype dan stok.
6. Ambil roti saat meninggalkan rak menuju cashier.

## **20.7 Price Reaction**

Harga unit final tersedia di Seksi 63. Efek harga terhadap demand dan pilihan customer memakai multiplier canonical Seksi 63.2 (baseline × sensitivitas archetype). Label reaksi untuk UI diturunkan dari multiplier itu (Seksi 84.5):

```text
VERY_HAPPY
HAPPY
NEUTRAL
UNHAPPY
VERY_UNHAPPY
REFUSE
```

## **20.8 Patience & Overhead Patience Bar**

Patience berkurang terutama saat:

- Menunggu di antrean.
- Menunggu cashier player kembali.
- Menunggu transaksi yang freeze.

Patience tidak berkurang ketika customer sedang berjalan normal ke rak atau pintu, kecuali event khusus.

Setiap customer instance wajib memiliki indikator world-space di atas kepala:

```text
ratio = clamp(current_patience / max_patience, 0.0, 1.0)
```

UI behavior:

- Bar mengikuti anchor `HeadUIAnchor`.
- Tidak menampilkan countdown numerik.
- Update visual boleh di-throttle (mis. 5–10 Hz) untuk efisiensi, tetapi nilai gameplay tetap dihitung dari simulation clock.
- Ketika ratio turun, bar harus memberi perubahan visual yang mudah dibaca tanpa membutuhkan teks.
- Bar disembunyikan ketika customer sudah `PAID/EXITING` dan dilepas saat actor despawn.
- Pending arrival yang belum masuk toko tidak memiliki Patience Bar aktif.

## **20.9 Abandonment**

Saat patience <= 0:

- Customer berhenti menunggu.
- Roti dibawa kembali ke display melalui simplified return action.
- Rating penalty diterapkan.
- Customer keluar.

## **20.10 Special Archetypes**

### Office Worker

- Patience sangat rendah.
- Peak 08:00–10:00.
- Prefer practical bread tags.

### School Child

- Patience tinggi.
- Budget sensitivity tinggi.
- Sweet preference.

### Bulk Buyer

- Quantity 5–15 sesuai sumber.
- Harus dibatasi oleh available stock.

### The Snob

- Harga kurang penting.
- Quality threshold tinggi.
- Premium recipe preference.

### Si Galau

- Service duration multiplier 2x kecuali cashier Tier 4 special handling.

### Food Vlogger

- Rare event customer. Peluang kedatangannya per hari ada di Seksi 20.11.
- Outcome harus didasarkan pada measurable service + quality conditions, bukan scripted selalu positif:
  - **Sukses** (`vip_success`): wait antrean ≤ 50% patience, dan semua unit yang dibeli `FRESH` dengan `bake_quality ≥ 0.95`.
  - **Gagal** (`vip_failure`): ia abandon, mendapati stok habis, wait > 80% patience, atau ada unit `STALE` atau `bake_quality < 0.80`.
  - Di antara keduanya: netral, tanpa efek rating.

## **20.11 Archetype Data Table — CANONICAL**

Berlaku mulai Hari 4; Hari 1–3 memakai manifest Seksi 20.3. Semua roll archetype memakai `customer_arrival_rng`. Nilai-nilai ini TUNABLE lewat catalog.

**Bobot archetype per tier lokasi** (jumlah per kolom = 1.00):

| Archetype | T1 | T2 | T3 | T4 | T5 |
| :--- | ---: | ---: | ---: | ---: | ---: |
| `customer_school_child` | 0.30 | 0.25 | 0.20 | 0.15 | 0.15 |
| `customer_office_worker` | 0.20 | 0.25 | 0.25 | 0.25 | 0.25 |
| `customer_generic` | 0.30 | 0.30 | 0.25 | 0.25 | 0.20 |
| `customer_bulk_buyer` | 0.10 | 0.10 | 0.10 | 0.10 | 0.10 |
| `customer_indecisive` | 0.10 | 0.10 | 0.10 | 0.10 | 0.10 |
| `customer_snob` | 0.00 | 0.00 | 0.10 | 0.15 | 0.20 |

**Modifier jam** (dikalikan ke bobot, lalu dinormalisasi per blok jam Seksi 66):
- `customer_office_worker`: ×2.0 pada 08:00–10:00, ×0.6 di blok lain.
- `customer_school_child`: ×0.4 pada 08:00–10:00, ×2.0 pada 14:00–16:30.

**Efek kampanye pada campuran pelanggan** (Seksi 8.2):
- `campaign_flyer_t1`: bobot preferensi `recipe_plain_loaf` dan `recipe_sugar_donut` ×1.3.
- `campaign_street_banner_t2`: `customer_office_worker` ×1.5 pada 08:00–10:00.
- `campaign_radio_magazine_t3`: `customer_bulk_buyer` ×2.0.
- `campaign_influencer_t4`: `customer_snob` ×1.5, dan peluang Food Vlogger ×1.4.
- `campaign_food_festival_t5`: hanya traffic, tanpa perubahan campuran.

**Food Vlogger** (`customer_critic`) tidak masuk tabel bobot:
- Maksimal satu per hari, sebagai kedatangan tambahan pada jam acak antara 09:00–16:00.
- Peluang per hari: T1 0%, T2 5%, T3 10%, T4 15%, T5 20%.
- Tidak pernah muncul di Hari 1–3.

**Aturan membeli per archetype:**

| Archetype | Preferensi tag (bobot) | Syarat kualitas | Harga unit maks |
| :--- | :--- | :--- | ---: |
| `customer_school_child` | sweet 1.0, family 0.4, practical 0.3 | `bake_quality ≥ 0.60`; boleh `STALE` | 300 KR |
| `customer_office_worker` | practical 1.0, savory 0.8, sweet 0.3 | `bake_quality ≥ 0.60`; boleh `STALE` | 1,000 KR |
| `customer_generic` | family / practical / sweet / savory masing-masing 0.6 | `bake_quality ≥ 0.60`; boleh `STALE` | — |
| `customer_bulk_buyer` | family 1.0, sweet 0.6, practical 0.4 | `bake_quality ≥ 0.60`; boleh `STALE` | — |
| `customer_indecisive` | semua tag 0.5 | `bake_quality ≥ 0.60`; boleh `STALE` | — |
| `customer_snob` | premium 1.0, artisan 0.8; hanya resep dengan tier minimum ≥ 3 | `bake_quality ≥ 0.95`; hanya `FRESH`/`GOOD` | — |
| `customer_critic` | premium 1.0, artisan 1.0 | `bake_quality ≥ 0.80`; hanya `FRESH`/`GOOD` | — |

Cara pakai:
- **Bobot preferensi** sebuah resep = bobot tertinggi archetype itu di antara tag resep (Seksi 61.6). Resep berbobot 0 hanya dipakai sebagai fallback (Seksi 69 langkah 3).
- **Harga unit maks** adalah `budget_profile`. Resep di atas batas ini tidak pernah dipilih, baik sebagai pilihan pertama maupun substitusi.
- **Reaksi harga** mengikuti Seksi 63.2.
- **Field tambahan** `CustomerArchetypeDefinition` (Seksi 101.4): `max_unit_price_kr`, `allowed_freshness_states`, `min_recipe_tier`.

---

# **21. Cashier, Queue, dan Transaction System**

## **21.1 Queue Model**

Setiap cashier lane memiliki:

```text
lane_id
cashier_desk_id
assigned_staff_id
queue_anchor_points[]
customers[]
is_open
```

## **21.2 Lane Opening Rules**

- Tanpa cashier assistant: hanya lane utama yang bisa dilayani player.
- Dengan assistant: lane tersebut otomatis aktif.
- Player tidak membuka lane tambahan di samping assistant.
- Tier 3+ membuka lebih dari satu lane hanya jika terdapat meja dan assistant sesuai aturan.

## **21.3 Queue Assignment**

**CANONICAL:** pelanggan memilih cashier lane dengan **estimated total wait time terendah**, bukan sekadar queue length. Formula final ada di Seksi 84.4.

## **21.4 Manual Cashier Flow**

```text
customer reaches front
 -> ! bubble appears
 -> player taps bubble/desk
 -> player walks to cashier anchor
 -> popup order shown
 -> player confirms OK
 -> packing animation
 -> payment
 -> customer leaves
```

Jika player pergi saat transaction progress:

- Progress freeze.
- Customer tetap di depan.
- Patience tetap menurun.
- Progress dilanjutkan dari nilai terakhir ketika player kembali.

## **21.5 Assistant Cashier Flow**

- Tidak membutuhkan tap player.
- Service dimulai otomatis saat customer berada di depan lane.
- Popup order tidak menghalangi gameplay; detail transaksi dapat tampil sebagai compact bubble.

## **21.6 Payment Commit Point**

Koin masuk hanya setelah packing selesai dan transaksi berhasil.

## **21.7 Closing Time**

Pelanggan yang belum mencapai payment commit pada 18:00 dianggap tidak terjual dan mengembalikan barang, tanpa penalti rating.

## **21.8 Physical Tips**

Tip fisik hanya muncul pada transaksi yang dilayani Asisten Kasir Tier 5 ("+5% peluang tip", Seksi 3.1):
- peluang 5% per transaksi, di-roll dengan `customer_choice_rng`;
- besar tip = `round_half_up(subtotal × 0.10)`;
- dicatat sebagai `TIP_PHYSICAL`.

---

# **22. RotiFood Order State Machine**

## **22.1 Order States**

```text
CREATED
NOTIFIED
OPENED
WAITING_FOR_STOCK
PACKING
PACKED_WAITING_DRIVER
DRIVER_EN_ROUTE
DRIVER_WAITING
HANDOVER
COMPLETED
EXPIRED
CANCELLED
```

## **22.2 Order Data**

```gdscript
class_name DeliveryOrder
var order_id: int
var items: Dictionary
var created_at: float
var preparation_deadline: float
var driver_arrival_time: float
var state: int
var packed_at: float
var handover_at: float
var rating_delta: float
var tip_amount: float   # whole KR (Seksi 99.2)
```

## **22.3 Stock Reservation Policy**

**CANONICAL:** stok **tidak di-reserve** saat RotiFood order masuk. Unit baru dipotong atomik ketika packing dikonfirmasi. Customer fisik dapat membeli stok tersebut lebih dahulu; jika stok berkurang, pemain harus produksi ulang atau order dapat expire.

## **22.4 Partial Stock**

Order tidak boleh dikemas sebagian. Jika ada item kurang:

- Popup menandai kekurangan merah.
- State `WAITING_FOR_STOCK`.
- Player dapat menutup popup dan memanggang item.

## **22.5 Packing**

Saat semua stock cukup:

- Potong seluruh item secara atomik.
- Buat packed bag entity/data.
- Order masuk `PACKED_WAITING_DRIVER`.

## **22.6 Driver Arrival & Queue Admission (Canonical)**

- Driver menjadi eligible untuk datang sesuai schedule order, tetapi **tidak boleh spawn masuk toko jika antrean tujuan penuh**.
- Tier 1–2: Driver Ojol meminta slot pada antrean utama yang sama dengan pelanggan fisik.
- Tier 3+: jika dedicated pickup counter aktif, driver meminta slot pada antrean khusus ojol.
- Hanya setelah `QueueManager.reserve_slot(driver_id, target_queue)` berhasil, driver actor boleh masuk dan berjalan ke slot yang dialokasikan.
- Bila reservasi gagal, arrival tetap `pending` dan dicoba lagi ketika slot kosong; jangan menumpuk beberapa driver di entrance.
- Satu slot = satu driver/customer. Pergerakan maju antar-slot wajib mempertahankan spacing dan collision separation.

## **22.7 Instant Handover**

Jika driver wait time <3 detik sesuai sumber:

- 5-star outcome untuk order tersebut.
- Roll tip 10–25% sesuai aturan sumber.

## **22.8 Expiry**

Saat deadline terlewati sebelum packing complete:

- Order -> EXPIRED/CANCELLED.
- Rating RotiFood -0.2.
- Tidak ada revenue.

Jika stock sudah dipotong dan order dibatalkan karena bug, lakukan transactional rollback.

## **22.9 Order Generation, Timing & Tips — CANONICAL**

Hari 1–3 memakai manifest Seksi 20.3 dengan `prep_window` tetap 90 simulation-seconds. Mulai Hari 4:

**Pembuatan order**
- Laju order mengikuti Seksi 65.
- Tidak ada order baru setelah **17:15**, supaya driver sempat datang sebelum tutup.
- Jumlah unit per order: 2 (10%), 3 (20%), 4 (40%), 5 (20%), 6 (10%).
- Jumlah jenis resep: 1 jenis (70%) atau 2 jenis (30%, unit dibagi serata mungkin). Bila menu hanya punya satu resep, selalu 1 jenis.
- **Menu** = resep yang saat order dibuat punya stok sellable di display, atau sudah selesai diproduksi hari itu. Resep dipilih dengan bobot sama. Bila menu kosong, order tidak dibuat dan demand itu terlewat tanpa penalti.
- Harga per unit dikunci saat order dibuat (Seksi 63.2). Semua roll memakai `rotifood_rng`.

**Timing**
- `prep_window` = roll seragam **60–90 simulation-seconds**. Driver mencoba masuk pada `created_at + prep_window` (admission & pending: Seksi 22.6, 67).
- Patience driver (Seksi 58) mulai saat driver masuk toko. `preparation_deadline` = saat patience itu habis.
- Handover **otomatis**, tanpa pemain atau kasir, begitu driver mencapai service point dan order sudah `PACKED`. Tas yang sudah dikemas menunggu di meja RotiFood (Tier 3+) atau meja kasir (Tier 1–2).
- Bila order belum dikemas, driver menunggu di service point (`DRIVER_WAITING`). Di Tier 1–2 ini ikut menahan antrean utama; itulah alasan meja RotiFood Tier 3+.

**Hasil & rating (nilai Seksi 9.2)**
- Wait driver = waktu dari masuk toko sampai handover.
- Wait < 3 s (Instant Handover): +0.1 ⭐ dan roll tip.
- Wait 3–10 s: ±0.
- Wait > 10 s: −0.1 ⭐.
- Patience habis atau deadline lewat: order `EXPIRED`, −0.2 ⭐. Driver pergi, dan tas yang sudah dikemas kembali ke display secara atomik.
- Bonus kualitas prima +0.05 ⭐ bila semua unit `FRESH` dan `bake_quality ≥ 0.95` saat dikemas.
- Order yang gagal karena pending admission kedaluwarsa (Seksi 67), atau dibatalkan oleh penutupan 18:00 (Seksi 104), tidak mengurangi rating.
- Tip Instant Handover: peluang 50%, besar `round_half_up(subtotal × U(0.10, 0.25))`, dicatat sebagai `TIP_ROTIFOOD`.

---

# **23. Staff AI Architecture**

## **23.1 Staff Common States**

```text
OFF_DUTY
IDLE
CHOOSING_TASK
WALKING
INTERACTING
CARRYING
WAITING
BLOCKED
```

## **23.2 Task Blackboard**

Gunakan shared job board:

```text
AVAILABLE_TASKS
CLAIMED_TASKS
COMPLETED_TASKS
```

Task harus memiliki owner lock agar dua baker tidak mengambil batch yang sama.

## **23.3 Baker Priority — Auto Replenish**

**CANONICAL Baker Priority:**

1. Ambil tray dari oven untuk job yang auto-retrieve-nya berhasil (Seksi 18.8).
2. Deliver carried item.
3. Pindahkan adonan selesai dari mixer ke oven kosong (job milik baker).
4. Refill display untuk resep dengan unit sellable paling sedikit (Seksi 3.2).
5. Mulai job baru jika ingredients cukup dan target mode mengizinkan.
6. Idle animation.

Tray yang auto-retrieve-nya gagal tidak diambil baker. Oven itu tertahan sampai pemain mengambilnya, dan baker memakai alat lain atau menunggu (Seksi 3.2, 30.4).

## **23.4 Baker Target Recipe Mode**

- Hanya recipe target yang dibuat.
- Berhenti jika ingredient tidak cukup, display penuh, atau alat tidak tersedia.
- Tidak boleh masuk infinite retry loop.

## **23.5 Staff Collision / Deadlock**

Jika dua staff saling menghalangi secara visual, mereka tidak boleh deadlock karena grid occupancy actor bukan hard-block. Furniture tetap hard-block.

## **23.6 Off-Duty / Solo Mode**

- Staff off-duty tidak berada dalam worker task system.
- Mereka boleh tidak di-spawn ke floor untuk menghemat processing.
- Data kontrak tetap tersimpan.

## **23.7 Baker Batch Size**

- Setiap Asisten Dapur punya setting batch di Staff Management: `Auto` (default), `x1`, `x3`, atau `x5`.
- `Auto`: baker memakai batch terbesar (x5 → x3 → x1) yang bahannya cukup di Gudang dan output-nya muat di sisa kapasitas display saat job dimulai. Bila x1 pun tidak muat, baker tidak memulai job (Seksi 23.4).
- Setting manual dibatasi aturan yang sama. Bila tidak terpenuhi, baker turun ke batch yang lebih kecil.
- Batch besar tidak lebih cepat per unit, karena durasi dikalikan linear (Seksi 18.9). Keuntungannya hanya jumlah bolak-balik yang lebih sedikit; risikonya lebih banyak unit menua bersamaan (Seksi 19.7).

---

# **24. Economy Model & Accounting**

## **24.1 Ledger-Based Accounting**

Semua perubahan KR wajib melalui ledger service.

```gdscript
class_name EconomyTransaction
var tx_id: int
var day: int
var game_time: float
var category: StringName
var amount: float   # whole KR per transaksi; saldo float64 (Seksi 73, 99.2)
var source_id: StringName
var metadata: Dictionary
```

## **24.2 Transaction Categories**

```text
SALE_PHYSICAL
SALE_ROTIFOOD
TIP_PHYSICAL
TIP_ROTIFOOD
INGREDIENT_PURCHASE
INGREDIENT_DELIVERY_COMMIT
EQUIPMENT_PURCHASE
EQUIPMENT_SALE
STORE_UPGRADE
STAFF_WAGE
UTILITY_COST
MARKETING_COST
BAILOUT_GRANT
OTHER_ADJUSTMENT
```

## **24.3 No Negative Silent Balance**

Saldo tidak boleh negatif akibat pembelian manual. Settlement gaji/utilitas yang melebihi kas harus memicu financial distress flow yang sesuai bailout rules (Seksi 49.1).

## **24.4 Cost of Goods**

Ingredient expense di Daily Summary harus memakai satu definisi konsisten:

- “Bahan Baku Terpakai” sebaiknya berarti value bahan yang **dikonsumsi ke production jobs hari itu**, bukan semua bahan yang dibeli hari itu.
- Purchase transaction tetap ada di ledger cash flow.

Karena UI sumber menampilkan pengeluaran bahan terpakai, implementasi harus membedakan `cash_spent_on_inventory` dan `cogs_consumed`.

## **24.5 Utility Cost**

Setiap station punya rate per real/in-game second yang bersifat TUNABLE.

```text
utility_cost += active_seconds * utility_rate_per_second
```

- Mixer charge hanya ketika MIXING.
- Oven charge ketika BAKING dan OVERBAKING.
- Showcase charge jika tier alat memang menggunakan listrik; rate harus data-driven.

## **24.6 Wage Settlement**

- Dibayar sekali pukul 18:00.
- Staff yang dipecat hari itu tetap mendapat wage penuh sesuai GDD.
- Staff yang diliburkan sebelum hari kerja dimulai tidak dibayar.
- Jika staff berstatus `on_duty=true` pada saat hari kerja dimulai (05:00), **gaji penuh hari itu terutang**. Mengubah menjadi off-duty setelah 05:00 tidak membatalkan gaji. Staff yang sudah off-duty sebelum 05:00 tidak dikenai gaji hari tersebut.

## **24.7 Bailout Transaction**

Bailout harus muncul sebagai transaksi ledger sendiri agar Daily Summary/history dapat diaudit.

## **24.8 Marketing Cost**

Biaya campaign dibayar upfront sekali, bukan charge harian meskipun tabel menampilkan equivalent/day.

---


# **24A. Market Availability & Ingredient Delivery Architecture**

## **24A.1 Unlock Rule**

- Hari 1–3: market ingredient purchasing terkunci oleh onboarding.
- `market_unlocked = true` di-set saat settlement Hari 3 (18:00). Karena itu, pembelian after-hours Hari 3 sudah langsung masuk Gudang untuk persiapan Hari 4.
- Hari 4 dan seterusnya: Pasar dapat dibuka dari Quick Menu selama Preparation, Selling, maupun After Hours. **Membuka Pasar selalu mem-pause simulation** sampai menu ditutup, sesuai policy management screen CANONICAL.

## **24A.2 Purchase Timing Rule**

```text
if store_is_closed and game_time >= 18:00:
    instant_after_hours = true
    commit_inventory_immediately()
else:
    arrival_game_time = current_game_time + 3 in-game hours
    state = IN_TRANSIT
```

Pembelian aktif pada Hari 4+ wajib membedakan `on_hand` dan `in_transit`. Recipe validation hanya boleh memakai `on_hand`.

## **24A.3 Delivery Commit**

Inventory mutation hanya terjadi pada satu titik:

```text
COURIER_DROPPING_PACKAGE -> package_contact_with_cashier_table -> INVENTORY_COMMITTED
```

Commit harus atomic. Jika animasi/courier terinterupsi oleh save/load, state recovery wajib memastikan order tidak double-commit. Simpan `inventory_committed: bool` per purchase order.

## **24A.4 Save/Load**

Save data minimal mencakup:

```text
market_unlocked
pending_purchase_orders[]
  order_id
  items
  total_cost
  created_day
  created_game_time
  arrival_game_time
  state
  inventory_committed
  instant_after_hours
```

Pada load:

- Jika `inventory_committed == true`, jangan tambah stok lagi.
- Jika ETA telah lewat tetapi belum committed, masukkan order ke courier delivery FIFO pada kesempatan aman berikutnya.
- After-hours instant order tidak membuat courier recovery event.

# **25. Rating, Reputation, dan Demand Calculation**

## **25.1 Rating Storage**

Gunakan float internal dengan rentang **1.0–5.0** (Seksi 99.1) dan clamp setiap perubahan. New Game dimulai dengan rating toko fisik **3.0** dan RotiFood Stars **3.0**.

## **25.2 Physical Rating Events**

Nilai berikut adalah default canonical dan berstatus TUNABLE lewat catalog, bukan hard-coded di behavior code.

| Event | Kapan terjadi | Delta dasar |
| :--- | :--- | ---: |
| `successful_sale` | transaksi fisik selesai | +0.02 |
| `fast_service` | tambahan bila wait antrean ≤ 30% patience maksimum customer | +0.01 |
| `customer_abandoned` | patience habis di antrean (Seksi 20.9) | −0.10 |
| `stockout_failure` | customer sudah masuk, tetapi tidak menemukan roti sellable yang boleh ia beli (Seksi 69) | −0.05 |
| `bad_quality_sale` | ada unit terjual dengan `bake_quality < 0.80` atau `STALE`; menggantikan delta `successful_sale` | −0.03 |
| `vip_success` | penilaian Food Vlogger positif (Seksi 20.10); diterapkan pukul 05:00 esok hari | +0.30 |
| `vip_failure` | penilaian Food Vlogger negatif; diterapkan pukul 05:00 esok hari | −0.30 |
| `marketing_daily_bonus` | saat settlement, nilai per tier kampanye di Seksi 8.2; bonus Tier 2 hanya bila abandonment hari itu ≤ 10% | Seksi 8.2 |

Lima event per-customer pertama dikali `tier_scale = 2.0 / base_physical_rate[tier]` (Seksi 65): T1 1.00, T2 0.57, T3 0.40, T4 0.27, T5 0.20. Dengan begitu kecepatan perubahan rating per hari tetap setara walau jumlah pelanggan naik per tier. Event VIP dan marketing tidak diskalakan.

## **25.3 RotiFood Rating**

Gunakan nilai eksplisit sumber untuk event yang sudah ditentukan:

- instant handover +0.1
- normal ready ±0
- driver wait >10s -0.1
- cancel -0.2
- fresh quality bonus +0.05

## **25.4 Demand Multiplier Pipeline**

Gunakan bentuk modular:

```text
final_demand = base_tier_demand
             * rating_multiplier
             * weather_multiplier
             * marketing_multiplier
             * event_multiplier
```

Apply cap untuk menjaga spawn <= physical capacity/performance budget.

## **25.5 Randomness**

Semua random event harus berasal dari seeded RNG service. Simpan seed per day sehingga bug dapat direproduksi.

Hari 1–3 tidak menggunakan random demand.

---

# **26. Weather & Calendar System**

## **26.1 Daily Forecast**

Weather hari berikutnya harus ditentukan sebelum Daily Summary selesai agar tip Pak Lurah dapat menyinggung prakiraan besok.

## **26.2 Weather Data**

```gdscript
class_name WeatherDefinition
var id: StringName
var physical_traffic_multiplier_min: float
var physical_traffic_multiplier_max: float
var delivery_multiplier_min: float
var delivery_multiplier_max: float
var visual_profile: StringName
var audio_profile: StringName
```

## **26.3 Rain**

Gunakan range sumber:

- physical -60% hingga -80%
- online +150% hingga +200%

Roll multiplier sekali per hari, bukan setiap order, agar hari terasa konsisten.

## **26.4 Holiday**

Holiday adalah event modifier terpisah dari weather. Bisa coexist dengan cuaca.

## **26.5 Calendar**

**CANONICAL:** kalender gameplay menggunakan `day_index` dan weekday berulang Monday–Sunday, dengan Hari 1 = Monday. Tidak ada tanggal/bulan/tahun kalender yang memengaruhi simulation; tanggal dunia nyata tidak pernah dipakai untuk event.

## **26.6 Weather Probabilities, Multipliers & Holiday Calendar — CANONICAL**

**Cuaca** (`weather_rng`, di-roll saat settlement untuk hari berikutnya, Seksi 26.1):
- Hari 1–4 selalu `weather_sunny` (onboarding plus hari bebas pertama).
- Mulai Hari 5, cuaca besok mengikuti cuaca hari ini:

| Hari ini | Besok `weather_sunny` | Besok `weather_rain` |
| :--- | ---: | ---: |
| `weather_sunny` | 75% | 25% |
| `weather_rain` | 55% | 45% |

Hasilnya rata-rata ±31% hari hujan. Hujan biasanya 1–2 hari, cerah sekitar 4 hari berturut-turut, sesuai "berganti setiap beberapa hari" (Seksi 10).

**Multiplier harian** (di-roll sekali, lalu berlaku sepanjang hari):

| Kondisi | Traffic fisik | Order RotiFood |
| :--- | ---: | ---: |
| `weather_sunny` | 1.00 | 1.00 |
| `weather_rain` | roll 0.20–0.40 (−60% s/d −80%) | roll 2.50–3.00 (+150% s/d +200%) |
| `event_holiday` | 1.60 | 1.40 |

Holiday bisa bersamaan dengan hujan; multiplier-nya dikalikan.

**Kalender holiday** (deterministik, tanpa RNG, supaya bisa direncanakan):
- `event_holiday` berlangsung 3 hari (Jumat–Minggu) setiap 14 hari mulai Hari 12: Hari 12–14, 26–28, 40–42, dan seterusnya. Rumusnya: `day_index ≥ 12` dan `(day_index − 12) mod 14 < 3`.
- HUD dan Daily Summary menampilkan hitung mundur holiday berikutnya mulai 3 hari sebelumnya.

---

# **27. Tutorial & Onboarding Specification**

## **27.1 Philosophy**

Tutorial harus mengajari melalui aksi dunia, bukan paragraf panjang.

## **27.2 Day 1 Learning Goals**

Pemain harus belajar:

- Membuka gudang/Buku Resep.
- Memilih batch.
- Mengetuk mixer.
- Mengambil hasil mixer.
- Mengantar ke oven.
- Mengambil roti tepat waktu.
- Menaruh ke display.
- Melayani cashier manual.
- Menyelesaikan satu RotiFood order.

## **27.3 Day 2 Learning Goals**

- Pelanggan low-patience.
- Produksi saat toko buka.
- Trade-off dapur vs cashier.
- Pengenalan staff assistant.

## **27.4 Day 3 Learning Goals**

- Batch lebih besar.
- Manajemen stock.
- Daily Summary interpretation.
- Menyelesaikan onboarding yang **membuka Pasar mulai setelah Hari 3**.
- Menjelaskan singkat bahwa mulai Hari 4 pembelian pada jam operasional membutuhkan **3 jam in-game** untuk dikirim, sedangkan pembelian setelah toko tutup langsung tersedia untuk persiapan esok hari.

## **27.5 Tutorial Blocking**

- Hard-block hanya saat perlu mencegah pemain membuat state invalid.
- Highlight target dengan pulse lembut.
- Tutorial bubble tidak menutupi target.

## **27.6 Skip / Replay**

- Tutorial dapat dilewati oleh pemain berpengalaman.
- Setelah skip, scripted day demand tetap berjalan.
- Help menu menyediakan replay tips tanpa reset progres.

---

# **28. UI Screen Inventory & Navigation Map**

## **28.1 Screens**

```text
Splash / Tap to Start
Main Menu
Character Select
Gameplay HUD
Recipe Book
Recipe Batch Selector
Display Slot Selector
Market (tabs: Ingredients, Equipment, Store Upgrade)
Staff Management
Applicant Detail
Marketing
Decoration Mode (termasuk tab Decor Shop, Seksi 72.1)
Pause
Settings
Daily Summary
Store Upgrade (tab Market, after-hours)
Confirmation Dialog
Bailout Cutscene Overlay
Help / Tutorial Archive
Credits
```

## **28.2 Modal Stack Rules**

- Maksimal satu blocking modal utama.
- Confirmation dialog boleh berada di atas satu modal.
- Back/Escape menutup layer paling atas.
- Gameplay input ke world dinonaktifkan selama blocking modal.

## **28.3 HUD Information Priority**

P0 selalu terlihat:

- KR.
- Jam.
- Physical rating.
- Critical alerts.

P1 contextual:

- Display stock summary.
- Utility meter.
- RotiFood pending orders.

P2 expandable:

- Detail statistik.
- Campaign remaining days.

## **28.4 Responsive Breakpoints**

**CANONICAL responsive breakpoints:**

- Compact landscape: width < 1000 logical px.
- Standard: 1000–1599 logical px.
- Wide: >=1600 logical px.

Layout harus rearrange, bukan scale font menjadi terlalu kecil.

## **28.5 Text Scaling**

Settings menyediakan minimal 100% dan 125% UI text scale tanpa memotong tombol penting.

---

# **29. Input Specification**

## **29.1 Primary Actions**

```text
primary_tap
primary_drag
cancel_back
pause
camera_pan (if enabled)
zoom_in / zoom_out (optional)
```

## **29.2 Tap vs Drag Threshold**

**CANONICAL:**

- Tap max movement: 12 logical px at 100% UI scale, multiplied by effective UI scale.
- Tap max duration: 0.35 s real time.
- Drag begins immediately after movement threshold is crossed.

Nilai harus menyesuaikan display scale.

## **29.3 Mouse**

- Left click = tap.
- Left drag = drag.
- Right click = back/cancel optional QoL.
- Wheel = zoom optional QoL.

## **29.4 Keyboard QoL**

- Esc = back/pause.
- Space = pause optional.
- Angka shortcut menu boleh ada, tetapi tidak wajib.

---

# **30. Camera Specification — FINAL CANONICAL**

## **30.1 Gameplay Camera**

Gunakan kamera 3D **isometric / three-quarter orthographic** yang konsisten. Kamera mengikuti **player character**, bukan staff/NPC. `active_floor_id` selalu sama dengan floor tempat player berada. Staff dan simulasi pada floor lain tidak pernah mengambil alih kamera.

Core rules:
- Orthographic projection adalah canonical default.
- Rotasi kamera gameplay dikunci; player tidak dapat memutar sudut isometric.
- Pan hanya diizinkan jika floor lebih besar daripada viewport dan selalu di-clamp ke bounds floor.
- Zoom mempunyai batas per tier agar karakter, interaction marker, dan furniture tetap terbaca.
- Saat modal placement/recipe/management terbuka, kamera tidak melakukan auto-pan/focus.

## **30.2 Multi-Floor Camera — Tier 2 & Tier 3**

Hanya **satu floor aktif divisualisasikan penuh pada satu waktu**. Saat player mencapai stair-door portal dan simulation melakukan instant floor transition (Seksi 68):

1. Player dipindahkan ke paired portal pada floor tujuan.
2. `active_floor_id` langsung berubah.
3. Kamera berpindah ke canonical framing floor tujuan.
4. Jalankan **crossfade 0.20 detik real-time** (`0.15–0.25 s acceptable range`) agar perpindahan tidak terasa kasar.
5. Crossfade bersifat visual saja; **tidak menambah waktu in-game dan tidak memberi stair travel delay**.
6. Floor lama berhenti dirender penuh setelah fade; floor tujuan menjadi visible/interactive.

Tidak ada animasi menaiki tangga, vertical camera fly, split-screen, atau transparansi dua floor bertumpuk.

## **30.3 Inactive Floor Simulation & Rendering**

Floor yang tidak terlihat **tetap disimulasikan penuh secara gameplay**:
- mixer/oven timers berjalan;
- burn timer berjalan;
- staff jobs berjalan;
- inventory, utility, queue, dan orders tetap valid;
- AI path state tidak di-reset.

Untuk performa Web/Android:
- visual mesh/character pada inactive floor boleh `visible = false`;
- procedural animation update boleh dihentikan/reduced;
- logic simulation tidak boleh dihentikan hanya karena floor tidak dirender;
- saat floor kembali aktif, transform visual di-sync ke state simulation terbaru sebelum fade selesai.

## **30.4 Off-Floor Attention System**

Jika player berada di floor berbeda dari event yang membutuhkan perhatian, HUD menunjukkan **off-floor alert** dengan arah floor (`↑` atau `↓`) dan ikon event. Minimum alert types:

| Event | Alert | Priority |
|---|---|---:|
| Oven memasuki `READY_PERFECT` | `↑/↓ Oven Ready` | High |
| Oven memasuki `OVERBAKING` | `↑/↓ Oven Burning!` | Critical |
| Mixer selesai dan menunggu pickup | `↑/↓ Mixer Ready` | Medium |
| Staff blocked/idle karena interaction unavailable | `↑/↓ Staff Needs Access` | Medium |
| Storage/production action memerlukan player | contextual | Medium |

Critical alert tetap terlihat sampai kondisi selesai. Alert tidak memindahkan kamera secara langsung. Mengetuk alert hanya:
1. menampilkan hint singkat nama floor; dan
2. menyalakan highlight/arrow menuju stair-door portal pada floor player saat ini.

Player tetap harus membawa karakternya ke portal untuk berpindah floor. Ini menjaga arti posisi karakter dan layout.

## **30.5 Floor Indicator**

HUD menampilkan indikator ringkas `L1 / L2` hanya pada lokasi multi-floor. Active floor diberi highlight. Jika ada critical event di floor lain, titik/ikon merah kecil muncul pada floor label tersebut.

## **30.6 Camera Framing per Floor**

Setiap floor memiliki data:

```gdscript
FloorCameraProfile {
  floor_id: StringName,
  orthographic_size: float,
  center_anchor: Vector3,
  pan_bounds_min: Vector2,
  pan_bounds_max: Vector2,
  zoom_min: float,
  zoom_max: float
}
```

Tier 2 dan Tier 3 boleh memiliki orthographic size berbeda antara L1/L2 sesuai ukuran floor, tetapi sudut kamera dan perceived character scale harus tetap konsisten.

## **30.7 Focus Events**

Soft camera nudge/temporary focus boleh dipakai untuk bailout cutscene, store-upgrade reveal, dan VIP arrival. Event rutin mixer/oven tidak boleh melakukan hard snap camera, terutama jika event terjadi di floor lain. Gunakan HUD alert.

---

# **31. Procedural Character Visual Specification**

## **31.1 Character Assembly**

Minimum component hierarchy:

```text
CharacterRoot
  Body
  Head
  Hair/Headwear
  EyeL
  EyeR
  Mouth
  ArmL
  ArmR
  LegL
  LegR
  Apron
  CarryAnchor
  ShadowBlob
```

## **31.2 Silhouette Rules**

- Kepala relatif besar.
- Tangan/kaki sederhana dan tebal agar terbaca di layar kecil.
- Carry item harus berada di depan torso dan tidak tertutup counter.

## **31.3 Player Gender Choice**

Pilihan pria/wanita hanya visual. Tidak boleh ada stat bonus.

## **31.4 Staff Identity**

Nama roster canonical harus dipertahankan. Visual boleh dirakit prosedural dari parameter deterministik per `staff_id`, sehingga penampilan tidak berubah setiap load.

## **31.5 Customer Randomization**

Gunakan seed dari customer instance untuk:

- skin tone palette.
- hair shape.
- shirt/pants palette.
- accessory.

Hindari kombinasi warna yang mengurangi keterbacaan role khusus seperti driver ojol.

---

# **32. Procedural Furniture & Environment Specification**

## **32.1 Furniture Interface**

Semua furniture interaktif mengimplementasikan interface konseptual:

```text
get_footprint()
get_interaction_anchor()
get_station_state()
can_accept_job(job)
on_player_interact(actor)
serialize_state()
```

## **32.2 Fixed Building Elements**

- Walls.
- Doors.
- Cashier boundary counter.
- Windows.

Elemen ini tidak boleh dipindah oleh decoration mode.

## **32.3 Tier Visual Mutation**

Upgrade tidak sekadar recolor; minimal ubah 2 dari:

- silhouette.
- component count.
- material palette.
- animation complexity.
- functional attachment.

## **32.4 Procedural Material Palette**

Semua material mengambil warna dari centralized palette resource agar konsisten.

---

# **33. Audio Design & Procedural/Generated Audio Policy**

Sumber asli sudah menetapkan suasana audio, tetapi implementasinya belum dirinci.

## **33.1 Music States**

```text
MENU               menu_music
MORNING_PREP       shop_music_morning
STORE_OPEN_CALM    shop_music_day
STORE_OPEN_BUSY    shop_music_day + shop_music_busy_layer
RAIN               shop_music_rain (+ ambience rain_loop)
DAILY_SUMMARY      shop_music_after_hours
BAILOUT_CUTSCENE   bailout_scene
```

ID audio di kolom kanan berasal dari katalog canonical Seksi 93.

## **33.2 Dynamic Mix**

- Busy layer naik berdasarkan active customers/orders.
- Jangan menaikkan tempo secara agresif; tekanan tetap cozy.
- Oven/mixer SFX tidak boleh menutupi notification penting.

## **33.3 SFX Priority**

P0: error, oven done, RotiFood incoming.
P1: payment coin, door chime.
P2: footsteps, ambient utensils.

## **33.4 Web Audio**

Audio engine hanya aktif setelah user gesture pertama.

## **33.5 Asset Constraint Clarification**

**Canonical:** seluruh audio yang dikirim bersama game harus original dan memiliki provenance proyek. Dilarang mengambil/download third-party audio pack, lagu berhak cipta, atau audio dari internet. Jalur default adalah audio/music procedural atau programmatically generated dengan script/parameter generator yang disimpan di repository. Rincian final terdapat pada Seksi 111.

---

# **34. Save System Schema & Migration**

## **34.1 Save Envelope**

Path file, envelope, dan root shape canonical ada di **Seksi 106**: `schema_version`, metadata profil, dan seluruh state. Settings & accessibility disimpan terpisah dari profil di `user://settings.json`.

## **34.2 Minimum Persisted Data**

- Profile id dan bakery name.
- Player character visual choice.
- Current day/time/state.
- KR balance.
- Store tier.
- Equipment owned and placement.
- Ingredient stock.
- Price settings per recipe.
- Display stock beserta freshness-nya (leftover bertahan lintas hari, Seksi 19.7.3).
- Staff roster/hired/on-duty state.
- Physical rating.
- RotiFood rating.
- Active marketing campaign + remaining days.
- Weather today/tomorrow.
- Tutorial progress.
- RNG seed/day seed.
- Lifetime statistics.

## **34.3 Autosave Points**

Autosave minimal:

- Setelah Daily Summary settlement.
- Setelah pembelian/upgrade besar.
- Setelah staff hire/fire.
- Saat app masuk background Android.

**CANONICAL:** jangan autosave per transaksi/unit terjual. Gunakan event autosave yang tercantum + debounce minimum 5 real-seconds antar autosave non-critical. Background/focus-loss save mengabaikan debounce dan harus diprioritaskan.

## **34.4 Atomic Save**

- Tulis ke temp file.
- Validate JSON.
- Rename/replace save utama.
- Simpan backup satu generasi terakhir.

## **34.5 Migration**

Setiap versi save menyediakan migrator `vN -> vN+1`.

Unknown field diabaikan; missing field diberi default versioned, bukan crash.

---

# **35. Recommended Godot Project Architecture**

## **35.1 Folder Structure**

```text
res://
  autoload/        autoload Seksi 35.2
  core/            infrastruktur simulasi: time, pause, RNG, command layer, pool, procedural cache
  data/
    catalog/       katalog canonical per jenis (Seksi 134)
  gameplay/
    actors/
    production/
    customers/
    delivery/
    economy/
    staff/
    supply/
    world/
  procedural/
    meshes/
    ui/
    animation/
  ui/
    hud/
    screens/
    components/
  audio/           generator audio prosedural (Seksi 111.1)
  tests/
    fixtures/      golden save fixture (Seksi 106)
  tools/           release_validator.gd dan tool headless lain (Seksi 133)
```

## **35.2 Autoloads & Manager Placement — CANONICAL**

Nama manager dan kepemilikan state mengikuti **Seksi 98**.

Autoload (ada sejak boot, termasuk di Main Menu):

```text
DataRegistry      katalog canonical, read-only (Seksi 134)
EventBus          signal global (Seksi 35.4)
SettingsManager
SaveManager
PauseManager      termasuk lifecycle pause (Seksi 90, 113)
AudioManager      playback, pooling, ducking; tidak memiliki state gameplay
Logger            (Seksi 117)
```

Manager gameplay lain di Seksi 98 (TimeManager, EconomyManager, InventoryManager, dan seterusnya, termasuk RNGManager) dibuat sebagai child `SimulationRoot` di `GameRoot` setiap kali sebuah profil dimuat. Semuanya dihancurkan saat kembali ke Main Menu, supaya state antar-profil tidak bocor (TEST_PROFILE_001).

Hindari God Object tunggal yang mengurus semuanya.

## **35.3 Data Resources**

Gunakan custom `Resource` untuk immutable design data dan runtime objects untuk mutable state.

Contoh:

```gdscript
class_name RecipeDefinition
extends Resource

@export var id: StringName
@export var localization_key: StringName
@export var ingredients: Dictionary
@export var batch_yield: int
@export var required_mixer_tier: int
@export var required_oven_tier: int
@export var tags: Array[StringName]
```

Field lengkap: Seksi 101.1.

## **35.4 Signals / Event Bus**

Event minimal:

```text
time_changed
shop_opened
shop_closed
production_job_created
station_completed
bread_added_to_display
customer_spawned
customer_abandoned
sale_completed
delivery_order_created
delivery_order_completed
balance_changed
rating_changed
staff_state_changed
weather_changed
day_settled
```

## **35.5 Dependency Rule**

UI boleh subscribe ke services, tetapi core simulation tidak boleh bergantung pada concrete UI node.

---

# **36. Runtime Scene Tree Recommendation**

```text
GameRoot
  SimulationRoot        manager gameplay per profil (Seksi 35.2, 98)
  WorldRoot
    Environment
    Building
    GridController
    FurnitureRoot
    ActorRoot
      Player
      StaffRoot
      CustomerRoot
      DriverRoot
    FXRoot
  CameraRig
  CanvasLayer_Gameplay
    HUD
    FloatingIndicators
  CanvasLayer_Modal
    ModalHost
  CanvasLayer_Debug
```

Furniture generator harus menciptakan visual dan metadata node, tetapi data state tetap disimpan terpisah agar rebuild scene tidak kehilangan progress.

---

# **37. Performance Budgets**

## **37.1 Frame Rate**

- Target 60 FPS pada device target normal.
- Graceful minimum 30 FPS pada Android entry-level.

## **37.2 Active Actor Budget — CANONICAL PERFORMANCE BUDGET**

- Tier 1–2: <25 actor aktif.
- Tier 3: <40.
- Tier 4: <60.
- Tier 5 event-heavy: <90.

Jika demand logis lebih tinggi, gunakan spawn pacing/virtual queue daripada memaksa semua actor hadir bersamaan.

## **37.3 Node Budget**

Hindari satu node per unit bread inventory. Gunakan aggregate stack.

## **37.4 Draw Calls**

- Reuse materials.
- Gunakan MultiMesh untuk repeated decorative items jika diperlukan.
- Procedural bukan berarti generate ulang setiap frame.

## **37.5 Allocation**

- Pool customer/particle objects.
- Hindari membuat array/dictionary besar di `_process`.
- Update UI hanya saat data berubah.

## **37.6 Web Memory**

Target initial runtime memory konservatif; hindari procedural mesh resolusi tinggi yang tidak terlihat.

---

# **38. Error Recovery & Defensive Simulation**

## **38.1 Stuck Actor Watchdog**

Jika actor tidak bergerak menuju target selama N detik:

1. Repath.
2. Jika gagal, pindah ke nearest valid anchor secara aman hanya sebagai recovery.
3. Catat debug event.
4. Jangan hapus carried item.

## **38.2 Orphan Job Recovery**

Saat load:

- Job yang menunjuk station tidak valid harus dipulihkan ke nearest valid stage.
- Reserved ingredient tidak boleh terduplikasi.

## **38.3 Transactional Inventory**

Packing RotiFood dan customer purchase harus atomic: validate stock -> remove -> commit. Jika commit gagal, rollback.

## **38.4 Save Corruption**

Jika save utama invalid, coba backup. Jika keduanya invalid, tawarkan New Game; jangan overwrite corrupt save sebelum user action.

---

# **39. Debug & Developer Tools**

Build development harus memiliki debug panel yang bisa dimatikan pada release.

## **39.1 Debug Commands**

- Add KR.
- Set day/time.
- Force weather.
- Spawn customer archetype.
- Spawn RotiFood order.
- Complete mixer/oven instantly.
- Set rating.
- Trigger bailout.
- Set location tier / grant equipment.
- Toggle path grid overlay.
- Toggle actor state labels.
- Dump ledger.
- Dump production jobs.

## **39.2 Deterministic Reproduction**

Tampilkan `day_seed` pada debug HUD agar bug demand/RNG dapat direproduksi.

---

# **40. Testing Strategy & Acceptance Criteria**

## **40.1 Automated Unit Tests**

Minimal test untuk:

- Ingredient cost deduction.
- Batch multiplier.
- Ledger balance.
- Wage settlement once only.
- Rating clamp.
- RotiFood expiry.
- Burn state timing.
- Save migration.
- Placement connectivity.

## **40.2 Integration Tests**

### Production Golden Path

Given bahan cukup -> create job -> mixer -> pickup -> oven -> pickup -> display. Expected: output quantity benar, ingredient deducted sekali, station free kembali.

### Manual Cashier Freeze

Customer sedang dilayani -> player pergi -> progress freeze -> player kembali -> progress resume -> revenue masuk sekali.

### Abandonment Return

Customer mengambil bread -> patience habis -> bread kembali -> freshness preserved -> rating penalty once.

### RotiFood Atomic Packing

Order multi-item -> satu item kurang -> tidak ada stock dipotong -> produksi item -> pack -> semua dipotong sekali.

### Bailout

Saldo 0 dan stok tidak cukup -> bailout event -> 650 KR + emergency ingredients -> staff off-duty -> no reputation penalty.

## **40.3 Platform Tests**

Web:

- itch.io iframe.
- fullscreen.
- browser resize.
- audio unlock after tap.
- save in IndexedDB.

Android:

- back gesture.
- background/resume.
- safe areas.
- multiple aspect ratios.
- low-memory resume.

## **40.4 Acceptance Criteria Example**

Satu feature ticket harus memiliki format:

```text
Feature: Manual Mixer Interaction
Given: player has one ordered job and empty hands
When: player taps mixer and reaches interaction anchor
Then: mixer enters MIXING
And: progress indicator appears
And: player becomes free to move after start animation
And: job remains inside mixer until explicitly picked up
```

---

# **41. Balancing Framework**

## **41.1 Balance Goals**

- Hari awal: pemain belajar operasi, bukan menghitung spreadsheet ekstrem.
- Staff harus terasa sebagai pembelian convenience yang ekonomis.
- Store upgrade harus membuka throughput, bukan hanya kosmetik.
- Marketing harus menguntungkan hanya jika kapasitas mampu menyerap demand.
- Rain harus terasa sebagai perubahan strategi, bukan bonus gratis.

## **41.2 Tunable Data Sheet**

Semua nilai berikut harus editable tanpa code change:

- ingredient prices.
- reference sale prices.
- batch yields.
- station durations.
- utility rates.
- salaries.
- customer patience.
- spawn rates.
- rating deltas.
- weather multipliers.
- marketing multipliers.
- store prices.
- staff auto-retrieve chances.

## **41.3 Balance Telemetry (Local)**

Walaupun game offline, development build sebaiknya merekam lokal:

- revenue/day.
- profit/day.
- bread produced/sold/wasted.
- average queue length.
- abandonment count.
- order cancellation count.
- station utilization.
- staff utilization.

Data ini cukup CSV/JSON lokal; tidak perlu analytics cloud untuk MVP.

---

# **42. Content Data Catalog**

Setiap content item harus memiliki stable ID yang tidak berubah walaupun display name berubah.

## **42.1 ID Convention**

```text
ingredient_flour
recipe_plain_loaf
recipe_sugar_donut
mixer_t1
oven_t1
staff_cashier_budi
staff_baker_joko
customer_school_child
location_t1_garage
campaign_flyer_t1
weather_rain
```

Daftar lengkap dan satu-satunya sumber ID: Seksi 78.

## **42.2 Display Name Separation**

Jangan menggunakan display name sebagai key save. Ini memudahkan localization dan rename.

---

# **43. Localization & Text Policy**

Dokumen GDD boleh menggunakan bahasa Indonesia untuk komunikasi desain, tetapi **seluruh konten yang terlihat pemain pada game v1.0 wajib berbahasa Inggris**.

- Main Menu, HUD, tutorial, dialogue, notifications, settings, achievement, Daily Summary, Market, Staff Management, Recipe Book, RotiFood, item names, equipment names, location names, tooltips, error messages, credits, dan cutscene subtitles semuanya English.
- Semua player-facing string tetap melalui localization key; jangan hard-code text panjang di script. Ini menjaga kemungkinan localization masa depan tanpa mengubah kontrak v1.0.
- English (`en`) adalah locale default dan satu-satunya language pack yang wajib dikirim pada v1.0.
- Nama bakery yang diketik pemain boleh Unicode dan tidak diterjemahkan.
- Format angka KR memakai grouping yang konsisten (`1,250 KR`) dan scientific notation untuk nilai ekstrem sesuai Endless Economy.
- Indonesian translation bukan scope v1.0 kecuali ditambahkan oleh revisi selanjutnya.

---

# **44. Accessibility & Comfort**

## **44.1 Required Options**

- Master/Music/SFX volume.
- UI text scale.
- Reduce motion.
- Screen shake toggle (jika ada).
- Tutorial replay.

## **44.2 Color Independence**

Jangan gunakan warna hijau/merah sebagai satu-satunya sinyal. Tambahkan icon/state shape untuk valid/invalid placement dan oven status.

## **44.3 Motion**

`Reduce Motion` mengurangi squash/stretch berlebihan, camera nudge, dan particle density tanpa mengubah gameplay timer.

---

# **45. Cutscene Direction Specification**

## **45.1 Pak Lurah Bailout Cutscene**

Cutscene harus tetap sederhana dan compatible dengan procedural actor.

### Shot 1 — Establishing

- Camera: gameplay camera, soft zoom-in 8–12%.
- Framing: pintu masuk toko di sepertiga kanan.
- Action: tiga ketukan pintu dengan SFX lembut.
- Duration target: 1.5–2.0s.

### Shot 2 — Entrance

- Pak Lurah masuk dari door anchor.
- Walk animation procedural.
- Carry prop: envelope/briefcase.
- Player actor menghadap Pak Lurah.

### Shot 3 — Dialogue

- Two-shot medium framing.
- Dialogue bubble muncul dekat bagian bawah tanpa menutupi wajah.
- Typewriter reveal dapat dipercepat dengan tap.

### Shot 4 — Grant

- Envelope icon bergerak menuju KR HUD.
- `+650 KR` feedback.
- Emergency ingredient icons masuk ke storage counter.

### Shot 5 — Close

- Pak Lurah wave animation.
- Camera kembali ke gameplay framing.
- Solo Mode tip muncul.

## **45.2 Skip Behavior**

Tap-hold/Skip button mempercepat cutscene tetapi tetap mengeksekusi seluruh gameplay transaction tepat satu kali.

---

# **46. Daily Summary Computation Contract**

## **46.1 Snapshot**

Saat 18:00 buat immutable `DayReportSnapshot` sebelum UI animasi dimulai.

## **46.2 Fields**

```text
day_number
weather
physical_sales
rotifood_sales
tips
cogs_consumed
utility_cost
wages
marketing_cost_if_charged_today
net_profit
ending_balance
physical_customer_count
delivery_completed
delivery_cancelled
bread_sold
bread_leftover
rating_start/end
rotifood_rating_start/end
top_recipe
highlights[]
tip_from_pak_lurah
```

## **46.3 Idempotency**

Membuka ulang Daily Summary tidak boleh menghitung ulang wages atau rating events.

---

# **47. Store Upgrade Transaction & Migration**

## **47.1 Upgrade Preconditions**

- KR cukup.
- Hanya after-hours, lewat tab Store Upgrade di Pasar (Seksi 5.1.2).
- Tidak ada modal transaksi lain.

## **47.2 Upgrade Flow**

1. Confirmation.
2. Charge KR.
3. Save checkpoint.
4. Transition visual.
5. Load/generate new location tier.
6. Migrate owned equipment yang masih valid.
7. Place storage baru secara default jika footprint berubah.
8. Validate layout connectivity.
9. Save lagi.

## **47.3 Furniture Overflow**

Jika equipment lama melebihi slot tier baru (secara normal tier naik, jadi tidak terjadi), simpan di owned inventory, jangan delete.

## **47.4 Storage Capacity Migration**

Upgrade selalu menaikkan capacity sehingga stok lama aman.

---

# **48. Marketing Campaign Runtime Rules**

## **48.1 Campaign State**

```text
campaign_id
start_day
remaining_days
upfront_cost_paid
```

## **48.2 Activation**

Hanya pada after-hours.

## **48.3 Duration**

5 hari aktif berarti modifier berlaku pada lima DAY_OPEN berikutnya setelah activation, termasuk hari berikutnya.

## **48.4 Replacement**

Karena satu campaign aktif dalam satu waktu:

**CANONICAL:** hanya satu marketing campaign boleh aktif. Campaign baru tidak dapat dibeli sampai campaign aktif selesai; tidak ada cancel/refund.

---

# **49. Bankruptcy & Solo Mode State Machine**

## **49.1 Financial Distress Check**

Setelah settlement 18:00:

1. Jika gaji + utilitas melebihi saldo, saldo menjadi 0. Sisa tagihan dihapus (tidak ada utang, Seksi 14.3) dan dicatat di metadata settlement.
2. Jalankan cek berikut:

```text
can_operate = ada resep r yang memenuhi tier equipment milik pemain (Seksi 61.5)
              dan missing_cost(r) <= balance
    # missing_cost(r) = Σ fixed_buy_price_kr × kekurangan tiap bahan r terhadap on_hand Gudang

has_sellable_display = ada BreadStack yang masih sellable setelah penuaan malam (Seksi 19.7.3)

if not can_operate and not has_sellable_display:
    bailout_pending = true
```

“Masih ada stok bahan” diuji sebagai **kombinasi bahan yang benar-benar dapat menyelesaikan satu batch resep**, bukan sekadar jumlah unit > 0. Bailout tidak bergantung pada saldo tepat 0, sehingga saldo kecil tanpa bahan tidak pernah membuat permainan macet.

## **49.2 Bailout Apply**

- Add 650 KR.
- Add emergency Tier 1 set.
- Set all staff `on_duty=false`.
- Keep employment records.
- Set solo_mode flag.

## **49.3 Exit Solo Mode**

**CANONICAL:** Solo Mode tidak memiliki threshold saldo keluar terpisah. Staff dapat diaktifkan kembali untuk **hari kerja berikutnya** jika saldo saat scheduling cukup untuk `total_scheduled_wages + cheapest_producible_batch_cost`. UI menampilkan projected remaining cash. Staff yang dijadwalkan kembali tidak mulai bekerja di tengah hari; mereka mulai 05:00 berikutnya.

---

# **50. Release Milestones for AI Implementation**

Milestone berikut hanya checkpoint review untuk merangkum hasil. Urutan implementasi yang berlaku adalah **Seksi 123**; milestone tidak boleh dipakai sebagai urutan kerja tandingan.

## **50.1 Milestone A — Simulation Skeleton**

- Grid world.
- Player actor pathing.
- Storage->Mixer->Oven->Display flow.
- One recipe.
- One customer archetype.
- Manual cashier.
- Time/day cycle.
- Basic save.

## **50.2 Milestone B — Complete Tier 1 Vertical Slice**

- 3 Tier 1 recipes.
- Days 1–3 onboarding.
- RotiFood basic.
- Staff Tier 1.
- Daily Summary.
- Bailout/Solo Mode.
- Web + Android smoke build.

## **50.3 Milestone C — Progression**

- Tier 2–3 stores/equipment/recipes.
- Marketing.
- Weather.
- More archetypes.
- Dedicated pickup counter Tier 3.

## **50.4 Milestone D — Late Game**

- Tier 4–5.
- VIP customers.
- Full staff roster.
- Holiday events.
- Performance scaling.

## **50.5 Milestone E — Polish & Release**

- Accessibility.
- Full save migrations.
- Device testing.
- Balancing pass.
- itch.io packaging.
- Google Play AAB.

---

# **51. AI Task Handoff Template**

Setiap permintaan ke AI coding agent sebaiknya memakai format berikut agar konteks tidak hilang:

```text
PROJECT: Roti Lezat Tycoon
ENGINE: Godot 4.7-stable Standard / GDScript / Compatibility Renderer
TARGET: Web + Android
SOURCE OF TRUTH: GDD current version
FEATURE: <feature name>

CANONICAL RULES:
- <copy relevant rules from GDD>

DEPENDENCIES:
- <systems this feature reads/writes>

INPUTS:
- <player/system events>

OUTPUTS:
- <state changes/signals/UI>

EDGE CASES:
- <list>

SAVE DATA:
- <fields>

ACCEPTANCE TESTS:
- Given/When/Then

DO NOT:
- Import external visual assets
- Bypass physical task chain
- Hard-code balance values
- Add keyboard-only controls
```

---

# **52. Final Implementation Checklist**

Sebelum AI implementor menganggap proyek feature-complete, verifikasi:

- [ ] New Game dimulai dengan saldo tepat **1.000 KR** pada Hari 1.
- [ ] Hari 1–3 deterministik dan demand sesuai tabel pembukaan.
- [ ] 08:00 auto-open dan 18:00 auto-close konsisten.
- [ ] Player benar-benar berjalan ke furniture.
- [ ] Mixer/oven dapat bekerja paralel.
- [ ] Isi alat tetap terkunci sampai diambil.
- [ ] Satu actor tidak membawa dua item.
- [ ] Roti diambil pelanggan dari display sebelum antre cashier.
- [ ] Setiap customer/Driver Ojol memiliki satu slot antrean unik; tidak ada overlap/stacking.
- [ ] Saat antrean penuh, customer/Driver Ojol baru tidak masuk sampai slot tersedia.
- [ ] Patience Bar terlihat di atas kepala pelanggan dan mengikuti nilai patience gameplay.
- [ ] Abandonment mengembalikan roti dengan state semula.
- [ ] Manual cashier berhenti saat player pergi.
- [ ] Assistant cashier otomatis penuh.
- [ ] RotiFood tidak membutuhkan player berdiri di cashier untuk membuka order.
- [ ] Dedicated ojol counter mulai Tier 3.
- [ ] Physical rating dan RotiFood rating terpisah.
- [ ] Rain menekan physical traffic dan menaikkan online order.
- [ ] Fixed ingredient prices tidak berubah acak.
- [ ] Market terkunci Hari 1–3, terbuka sejak settlement Hari 3, dan dapat dibuka kapan saja mulai Hari 4.
- [ ] Pembelian sebelum 18:00 tiba setelah tepat 3 jam in-game dan belum usable sebelum courier drop-off commit.
- [ ] Kurir suplai meletakkan paket di meja kasir, inventory bertambah satu kali, lalu kurir keluar.
- [ ] Beberapa kurir suplai tidak pernah menumpuk di meja; drop-off diproses FIFO satu per satu.
- [ ] Pembelian setelah 18:00 langsung masuk Gudang dan tersedia pada persiapan hari berikutnya.
- [ ] Utility dihitung dari active duration.
- [ ] Gaji dipotong tepat sekali per hari.
- [ ] Tidak ada game over permanen.
- [ ] Bailout tidak memberi reputation penalty.
- [ ] Solo Mode menonaktifkan staff sementara, bukan memecat.
- [ ] Store tidak memiliki biaya sewa harian.
- [ ] Decoration validation mencegah jalur wajib terblokir.
- [ ] Visual utama dibuat prosedural.
- [ ] Input utama 100% tap/click accessible.
- [ ] Web audio unlock bekerja.
- [ ] Android background pause/save aman.
- [ ] Save versioning dan backup tersedia.
- [ ] Balance values berada di data resources.
- [ ] Debug tools tersedia pada development build.
- [ ] Acceptance tests utama lulus di Web dan Android.

---

# **55. Core Revision Acceptance Tests**

## **55.1 Starting Cash**

**Given** pemain membuat New Game, **when** Hari 1 gameplay dimulai, **then** ledger opening balance dan HUD harus menunjukkan tepat `1000 KR`.

## **55.2 Queue Full Blocks Admission**

**Given** seluruh slot antrean utama terisi, **when** scheduler memicu arrival pelanggan baru atau Driver Ojol Tier 1–2, **then** actor baru tidak di-spawn ke interior dan tidak overlap di entrance. Ketika satu slot bebas, arrival paling depan yang pending dapat memperoleh slot.

## **55.3 Dedicated Ojol Queue**

**Given** Tier 3+ dengan dedicated pickup counter aktif dan antrean ojol penuh, **when** driver baru eligible datang, **then** driver tidak menggunakan/menumpuk antrean ojol yang penuh dan tidak mengganggu slot physical queue kecuali desain fasilitas secara eksplisit mengarahkannya ke antrean gabungan.

## **55.4 Patience Bar**

**Given** customer memiliki `max_patience = 30` dan `current_patience = 15`, **then** bar menampilkan ratio 0.5. **When** customer memasuki state non-waiting yang tidak mengurangi patience, **then** nilai gameplay tidak berkurang.

## **55.5 Daytime Market Delivery**

**Given** Hari 4 pukul 10:00 pemain membeli 3 Tepung, **when** transaksi dikonfirmasi, **then** KR langsung berkurang tetapi `on_hand` Tepung belum bertambah dan ETA = 13:00. **When** clock mencapai 13:00 dan kurir menyelesaikan drop-off di meja kasir, **then** 3 Tepung ditambahkan tepat sekali dan langsung dapat dipakai.

## **55.6 Supply Courier Lifecycle**

**Given** purchase order mencapai ETA, **then** courier spawn → walk to cashier staging point → place package → inventory commit → turn around → exit → despawn. Inventory tidak boleh commit saat courier baru spawn atau masih berjalan masuk.

## **55.7 Multiple Deliveries Do Not Stack**

**Given** tiga order mencapai ETA bersamaan, **then** hanya satu courier menggunakan cashier staging point. Dua order lain menunggu dalam FIFO tanpa spawn bertumpuk. Setiap order commit sekali ketika gilirannya drop-off.

## **55.8 After-Hours Purchase**

**Given** Hari 4 pukul 18:05 pemain membeli bahan, **then** tidak ada courier spawn, tidak ada ETA 3 jam, bahan langsung masuk Gudang, dan save untuk hari berikutnya sudah memuat stok tersebut.

## **55.9 Capacity Includes In-Transit**

**Given** kapasitas Gudang tersisa 10 unit dan 8 unit sedang in-transit, **then** Pasar hanya mengizinkan maksimal 2 unit tambahan untuk order baru.


---

# **Appendix — Spatial Scale Acceptance Tests**

1. **Tier 1 dimensions:** Given Tier 1 scene, world floor bounds must equal **3 m × 6 m** and occupancy grid must equal **6 × 12 cells**. Customer zone and kitchen zone must each equal **6 × 6 cells**.
2. **Tier 2 multi-floor:** Ground floor must be **6 × 12 cells**, upper kitchen **6 × 8 cells**; no customer path may resolve to the upper-floor kitchen. Player/staff path may traverse only through the registered stair link.
3. **Tier 3 multi-floor:** Both floors must be **6 × 12 cells** with store below and kitchen above.
4. **Tier 4 dimensions:** Scene must be **16 × 16 cells**, split into **8 × 16 store** and **8 × 16 kitchen**.
5. **Tier 5 dimensions:** Scene must be **20 × 20 cells**, split into **12 × 20 store** and **8 × 20 kitchen**.
6. **Furniture scaling:** A footprint `Vector2i(2,1)` must occupy exactly **1.0 m × 0.5 m** on X/Z regardless of tier.
7. **Queue slot separation:** Two queue actors must never resolve to the same 0.5 m × 0.5 m queue cell. When all slots are reserved/occupied, admission scheduler must not spawn a new actor into the shop.
8. **Placement validation:** A mesh whose logical footprint is 2 × 1 cannot be placed if either of those two cells is blocked, even if its visible mesh appears to fit.
9. **Save/load:** Furniture positions are serialized as `{floor_id, grid_x, grid_y, rotation_quarters}` rather than raw floating world transforms. World transforms are regenerated from the canonical 0.5 m tile scale after loading.
10. **Scale invariant:** Automated validation must fail scene initialization if a generated floor dimension differs from `tile_count × 0.5 meter` by more than floating-point epsilon.

---

# **56. Canonical Gameplay & Technical Decisions**

> **Status:** Seluruh aturan pada seksi ini adalah canonical dan harus konsisten dengan data/schema final. Tidak ada historical override mechanism.

## **56.1 Collision, Passing, Occupancy, dan Anti-Blocking**

Karakter di dunia game menggunakan **soft-pass movement**: player, customer, staff, Driver RotiFood, dan kurir suplai **boleh saling menembus ketika berjalan bebas**. Tidak ada body-to-body collision yang dapat membuat lorong macet.

Namun, actor **tidak boleh overlap** ketika berada dalam state yang membutuhkan kepemilikan posisi unik:
- `QUEUE_SLOT`: satu actor per slot antrean.
- `EQUIPMENT_USE_POINT`: satu actor per interaction point peralatan.
- `CASHIER_SERVICE_POINT`: satu pelanggan/driver per titik layanan.
- `SUPPLY_DROPOFF_POINT`: satu kurir suplai per titik drop-off.
- `STAIR_DOOR_POINT`: boleh dilalui beberapa actor secara bergantian tetapi tidak menjadi waiting slot.

Karakter yang berjalan bebas tidak memakai occupancy locking. Karakter yang masuk state di atas harus melakukan `reserve -> move -> occupy -> release`.

### **56.1.1 Tile Classification**

Setiap tile memiliki salah satu flag utama berikut:
- `WALKABLE_BUILDABLE`: dapat diinjak dan dapat ditempati furniture jika footprint/clearance valid.
- `WALKABLE_NO_BUILD`: dapat diinjak tetapi **tidak pernah** dapat ditempati furniture/dekorasi.
- `QUEUE_RESERVED`: khusus slot antrean; tidak dapat dibangun.
- `INTERACTION_RESERVED`: titik berdiri operator/customer; tidak dapat dibangun.
- `FIXED_STRUCTURE`: dinding, pintu, counter tetap, tangga/door portal.
- `NON_WALKABLE`: tidak dapat dilalui dan tidak dapat dibangun.

Player tidak boleh mengubah flag tersebut. Decoration Mode hanya dapat menggunakan `WALKABLE_BUILDABLE`.

### **56.1.2 Universal Protected Paths**

Setiap floor wajib memiliki `WALKABLE_NO_BUILD` network yang menghubungkan semua critical nodes:
`entrance -> display access -> cashier/customer queue -> exit`, dan untuk actor internal:
`cashier/player side -> storage -> mixer -> oven -> display transfer -> stair portal (jika ada)`.

Validation wajib menolak placement yang menyebabkan salah satu critical node tidak dapat dicapai dari node lain yang relevan. Validasi dilakukan **sebelum** placement dikonfirmasi.

Furniture juga wajib menyisakan **minimal 1 tile (0,5 m × 0,5 m) kosong di depan interaction face**. Tile ini otomatis menjadi temporary `INTERACTION_RESERVED` selama furniture berada di posisi tersebut. Pengecualian: bila tile itu bagian dari protected path, flag-nya tetap `WALKABLE_NO_BUILD` dan tile tetap sah dipakai sebagai interaction tile (Seksi 60.1).

---

# **57. Canonical Layout Templates per Location Tier**

Koordinat menggunakan `(x,z)` dan dimulai dari sudut kiri-bawah floor plan. Satu tile = **0,5 m × 0,5 m**. Rentang koordinat bersifat inklusif.

Istilah yang dipakai di template:
- **Service point**: tempat pelanggan/driver terdepan berdiri di depan meja.
- **Cashier point**: tempat kasir atau karakter pemain berdiri di balik meja.
- **Supply drop-off**: tempat kurir suplai meletakkan paket di meja kasir (Seksi 5.2.3, 70).
- **Baris staf**: tile `WALKABLE_NO_BUILD` yang hanya boleh dilewati pemain dan staf, tidak oleh pelanggan maupun driver.
- Slot antrean yang memotong aisle tetap bisa dilewati actor lain (soft-pass, Seksi 56.1), tetapi tetap `QUEUE_RESERVED` dan tidak dapat dibangun.
- Semua elemen yang tertulis di template adalah fixed. Sel lain di zona yang sama adalah `WALKABLE_BUILDABLE`.

## **57.1 Tier 1 — Garasi Rumah**

- Floor: `6 × 12 tiles` = `3 × 6 m`.
- Store: `x=0..5, z=0..5`.
- Kitchen: `x=0..5, z=6..11`.
- Entrance door: `x=2..3, z=0`.
- Protected entrance spine: `x=2..3, z=0..4` = `WALKABLE_NO_BUILD`.
- Fixed cashier counter: `x=0..2, z=5`. Tablet RotiFood berada di ujung meja ini.
- Customer service point: `(1,4)`.
- Player cashier point: `(1,6)`.
- Main queue slots: `(1,3)`, `(1,2)`, `(1,1)`, `(0,1)` = **4 slots**.
- Supply drop-off: `(0,4)`.
- Passage store ↔ kitchen: `(3,5)` (protected).
- Baris staf di belakang meja: `(0,6)`.
- Kitchen protected spine: `x=2..3, z=6..11`.
- Display placement zone default: `x=4..5, z=1..4`.
- Kitchen buildable strips: `x=0..1` dan `x=4..5`, kecuali reserved interaction tile.

## **57.2 Tier 2 — Ruko 1 Pintu**

**Ground / Store Floor**
- `6 × 12 tiles` = `3 × 6 m`.
- Entrance: `x=2..3, z=0`.
- Protected spine: `x=2..3, z=0..9`, ditambah gap `(3,10)` menuju baris staf.
- Cashier counter: `x=0..2, z=10`. Tablet RotiFood berada di ujung meja ini.
- Customer service point: `(1,9)`.
- Cashier point: `(1,11)`.
- Main queue: `(1,8)`, `(1,7)`, `(1,6)`, `(1,5)`, `(1,4)`, `(0,4)` = **6 slots**.
- Supply drop-off: `(0,9)`.
- Baris staf: `(0,11)`, `(2,11)`, `(3,11)`.
- Stair/door portal to upper floor: `(4,11)` dengan access tile `(4,10)`; keduanya `NO_BUILD`.

**Upper / Kitchen Floor**
- `6 × 8 tiles` = `3 × 4 m`.
- Stair/door portal: `(4,0)` dengan access tile `(4,1)`.
- Protected spine: `x=2..3, z=0..7`.
- Side buildable strips: `x=0..1` dan `x=4..5`, kecuali stair/access tile.

## **57.3 Tier 3 — Toko Bakery Mandiri**

**Ground / Store Floor**
- `6 × 12 tiles`.
- Entrance: `x=2..3, z=0`.
- Protected central spine: `x=2..3, z=0..10`.
- Cashier counter A: `x=0..1, z=10`; counter B: `x=4..5, z=10`.
- Customer service points: `(1,9)` dan `(4,9)`.
- Cashier points: `(1,11)` dan `(4,11)`.
- Queue A: `(1,8)`, `(1,7)`, `(1,6)`, `(0,6)` = 4 slots.
- Queue B: `(4,8)`, `(4,7)`, `(4,6)`, `(5,6)` = 4 slots.
- **Physical queue capacity total = 8**.
- Dedicated RotiFood counter: `x=4..5, z=0`, di sebelah pintu masuk; tablet RotiFood berada di meja ini.
- RotiFood driver service point: `(5,1)`.
- Dedicated RotiFood queue: `(5,2)`, `(5,3)`, `(5,4)` = **3 slots**.
- Supply drop-off: `(0,9)`.
- Baris staf: `(0,11)`, `(2,11)`, `(5,11)`.
- Stair/door portal: `(3,11)` dengan access `(3,10)`.
- Display placement zone default: `x=0..1, z=0..5`.

**Upper / Kitchen Floor**
- `6 × 12 tiles`.
- Portal: `(0,0)` dengan access tile `(1,0)`.
- Protected circulation spine: `x=2..3, z=0..11`.
- Cross aisle wajib pada `z=5..6` agar kedua sisi dapur selalu terhubung.

## **57.4 Tier 4 — Flagship Store**

- Floor: `16 × 16 tiles` = `8 × 8 m`.
- Store zone: `x=0..7, z=0..15`.
- Kitchen zone: `x=8..15, z=0..15`.
- Entrance: `x=3..4, z=0`.
- Store protected main aisle: `x=3..4, z=0..15`.
- Store/kitchen boundary pada `x=7`: dinding rendah (`FIXED_STRUCTURE`), kecuali meja dan passage berikut.
  - Cashier counter A `(7,5),(7,6)`, counter B `(7,10),(7,11)`, RotiFood counter `(7,14),(7,15)`.
  - Passage staf `(7,8)` dan `(8,8)` (protected).
- Cashier service points: `(6,5)` dan `(6,10)`.
- Cashier points: `(8,5)` dan `(8,10)`.
- Queue A: `(5,5),(4,5),(3,5),(2,5),(1,5)` = 5 slots.
- Queue B: `(5,10),(4,10),(3,10),(2,10),(1,10)` = 5 slots.
- **Physical queue capacity total = 10**.
- RotiFood driver service point: `(6,14)`.
- RotiFood queue: `(5,14),(4,14),(3,14),(2,14)` = **4 slots**.
- Supply drop-off: `(6,6)`.
- Kitchen protected spine: `x=9..10, z=0..15`.
- Cross aisles: `z=5` dan `z=10` pada `x=9..15`.

## **57.5 Tier 5 — Mega Bakery Landmark**

- Floor: `20 × 20 tiles` = `10 × 10 m`.
- Store: `x=0..11, z=0..19`.
- Kitchen: `x=12..19, z=0..19`.
- Entrance: `x=5..6, z=0`.
- Store main aisle: `x=5..6, z=0..19`.
- Store/kitchen boundary pada `x=11`: dinding rendah (`FIXED_STRUCTURE`), kecuali meja dan passage berikut.
  - Cashier counters `(11,5),(11,6)`, `(11,10),(11,11)`, `(11,15),(11,16)`; RotiFood counter `(11,18),(11,19)`.
  - Passage staf `(11,8)` dan `(12,8)` (protected).
- Three cashier service points: `(10,5)`, `(10,10)`, `(10,15)`.
- Cashier points: `(12,5)`, `(12,10)`, `(12,15)`.
- Queue lane A: `(9..4,5)` = 6 slots.
- Queue lane B: `(9..4,10)` = 6 slots.
- Queue lane C: `(9..4,15)` = 6 slots.
- **Physical queue capacity total = 18**.
- RotiFood driver service point: `(10,18)`.
- RotiFood queue: `(9,18),(8,18),(7,18),(6,18),(5,18),(4,18)` = **6 slots**.
- Supply drop-off: `(10,6)`.
- Kitchen protected spines: `x=13..14` dan `x=17..18`, dengan cross aisles pada `z=6` dan `z=13`.

### **57.6 Queue Admission Capacity**

| Tier | Physical Customer Capacity | RotiFood Capacity | Queue Topology |
|---|---:|---:|---|
| T1 | 4 shared slots | shared | 1 lane |
| T2 | 6 shared slots | shared | 1 lane |
| T3 | 8 | 3 | 2 cashier lanes + dedicated delivery |
| T4 | 10 | 4 | 2 cashier lanes + dedicated delivery |
| T5 | 18 | 6 | 3 cashier lanes + dedicated delivery |

Untuk Tier 1–2, RotiFood driver memakan slot queue yang sama dengan customer fisik. Untuk Tier 3+, capacity dipisahkan.

Tabel ini adalah satu-satunya definisi kapasitas antrean (ringkasan di Seksi 6 mengikuti tabel ini). Aturan hitungnya:
- Kapasitas = jumlah queue slot. Service point kasir/RotiFood tidak dihitung. Actor yang sedang dilayani berdiri di service point dan melepas slot antreannya.
- Admission (Seksi 20.5) menghitung slot pada lane yang **terbuka**. Lane terbuka = lane dengan Asisten Kasir bertugas, atau lane utama saat pemain melayani manual (Seksi 21.2). Contoh: Tier 3 dengan satu lane terbuka hanya menerima 4 customer fisik.
- Kapasitas RotiFood terpisah berlaku bila meja RotiFood aktif. Bila tidak aktif, driver memakai antrean utama seperti Tier 1–2.

---

# **58. Patience System — Final Numeric Specification**

Patience memakai **simulation seconds**, bukan jam in-game. Nilai ini sengaja berada di rentang puluhan detik agar masuk akal terhadap total hari 39 menit nyata pada 1×.

| Actor Type | `max_patience_seconds` | Catatan |
|---|---:|---|
| School Child | 55 s | Paling sabar di reguler. |
| Office Worker | 18 s | Canonical low-patience rush customer. |
| Arisan / Bulk Buyer | 45 s | Sabar, tetapi transaksi besar. |
| The Snob | 28 s | Cepat kecewa walau kaya. |
| Si Galau | 60 s | Lama memilih tetapi relatif sabar. |
| Food Vlogger / Critic | 25 s | Mengharapkan layanan cepat. |
| Generic Adult | 35 s | Baseline fallback. |
| RotiFood Driver | 30 s | Menunggu handover. |

Patience **tidak** berkurang ketika actor masih `pending_arrival` di luar toko. Customer fisik mulai mengurangi patience ketika sudah membawa roti dan memasuki antrean kasir. Driver mulai mengurangi patience ketika sudah masuk queue pickup.

Drain baseline = `1.0 patience-second per simulation-second`.

Modifiers:
- Cashier Tier 3 stress reduction: `×0.85` drain untuk queue yang dilayani cashier tersebut.
- Queue hampir penuh (`occupancy >= 80%`): `×1.10`.
- Customer telah menunggu tanpa progress queue selama >10 s: tambahan `×1.15`.
- Semua modifier multiplicative, clamp drain akhir `0.5..1.6`.

Patience bar tidak menampilkan angka. State visual:
- `>60%`: tenang.
- `30–60%`: waspada.
- `10–30%`: berkedip pelan.
- `<10%`: berkedip cepat + sweat-drop.
- `0%`: actor keluar, item yang dipegang dikembalikan sesuai aturan customer abandonment.

---

# **59. Character Movement Speed — Final Rules**

Satuan canonical adalah meter per simulation-second. Karena 1 tile = 0,5 m, `tiles/s = m/s ÷ 0.5`.

| Actor | Speed | Tiles/s |
|---|---:|---:|
| Player | 1.50 m/s | 3.0 |
| School Child | 1.10 m/s | 2.2 |
| Office Worker | 1.35 m/s | 2.7 |
| Arisan / Bulk Buyer | 0.95 m/s | 1.9 |
| Snob | 1.05 m/s | 2.1 |
| Si Galau | 0.90 m/s | 1.8 |
| Food Vlogger | 1.10 m/s | 2.2 |
| RotiFood Driver | 1.25 m/s | 2.5 |
| Supply Courier | 1.40 m/s | 2.8 |
| Cashier Staff | 1.20 m/s | 2.4, hanya untuk movement non-counter |
| Baker T1 | 1.25 m/s | 2.5 |
| Baker T2 | 1.35 m/s | 2.7 |
| Baker T3 | 1.45 m/s | 2.9 |
| Baker T4 | 1.55 m/s | 3.1 |
| Baker T5 | 1.70 m/s | 3.4 |

Movement speed dan `work_speed_multiplier` adalah statistik berbeda. Baker cepat bekerja tidak berarti semua timer alat dikalikan dua kali.

---

# **60. Master Furniture Dimension & Interaction Standard**

Semua footprint wajib bilangan bulat tile. Mesh visual boleh sedikit inset dari footprint tetapi tidak boleh keluar lebih dari 0,05 m dari logical footprint.

| Furniture | Tier | Footprint (tiles) | World Size | Height Guideline | Interaction Face |
|---|---:|---:|---:|---:|---|
| Storage | T1 | 2×1 | 1.0×0.5 m | 1.40 m | front long side |
| Storage | T2 | 3×1 | 1.5×0.5 m | 1.55 m | front |
| Storage | T3 | 4×1 | 2.0×0.5 m | 1.70 m | front |
| Storage | T4 | 4×1 | 2.0×0.5 m | 1.80 m | front |
| Storage | T5 | 5×1 | 2.5×0.5 m | 2.00 m | front |
| Mixer | T1 | 1×1 | 0.5×0.5 m | 0.75 m | front |
| Mixer | T2 | 1×1 | 0.5×0.5 m | 0.90 m | front |
| Mixer | T3 | 2×1 | 1.0×0.5 m | 1.00 m | long front |
| Mixer | T4 | 2×1 | 1.0×0.5 m | 1.15 m | long front |
| Mixer | T5 | 2×1 | 1.0×0.5 m | 1.30 m | long front |
| Oven | T1 | 1×1 | 0.5×0.5 m | 0.90 m | door side |
| Oven | T2 | 1×1 | 0.5×0.5 m | 1.00 m | door side |
| Oven | T3 | 2×1 | 1.0×0.5 m | 1.30 m | door side (long side) |
| Oven | T4 | 2×1 | 1.0×0.5 m | 1.60 m | door side (long side) |
| Oven | T5 | 3×1 | 1.5×0.5 m | 1.50 m | loading end (short side, conveyor entry) |
| Display | T1 | 2×1 | 1.0×0.5 m | 0.85 m | customer-facing side |
| Display | T2 | 2×1 | 1.0×0.5 m | 0.95 m | customer-facing side |
| Display | T3 | 2×2 | 1.0×1.0 m | 1.05 m | configured front |
| Display | T4 | 2×2 | 1.0×1.0 m | 1.10 m | configured front |
| Display | T5 | 2×2 | 1.0×1.0 m | 1.15 m | configured front |
| Cashier Counter Segment | all | 2×1 | 1.0×0.5 m | **0.42 m** | customer side/player side |
| RotiFood Counter | T3+ | 2×1 | 1.0×0.5 m | **0.42 m** | driver side |
| Stair Door / Portal | T2–T3 | 2×1 reserved | 1.0×0.5 m | door-height | front |
| Supply Package Visual | all | 1×1 max | ≤0.5×0.5 m | ≤0.45 m | none |

### **60.1 Rotation Rules**

- Rotasi hanya `0° / 90° / 180° / 270°` (`rotation_quarters = 0..3`).
- Footprint ditukar X/Z pada 90° dan 270°.
- Interaction face ikut berputar.
- **Satu tile kosong tepat di depan interaction face wajib tersedia** setelah rotasi.
- Untuk storage multi-door, seluruh front edge harus memiliki minimal satu contiguous access lane 1 tile; AI tidak boleh memutar storage sehingga pintunya menghadap dinding atau `NON_WALKABLE`.
- Oven wajib memiliki access tile pada sisi pintu.
- Display harus memiliki minimal satu customer-access tile pada sisi display dan satu restock-access tile untuk player/staff jika modelnya membutuhkan sisi berbeda.
- Placement invalid jika interaction tile bertabrakan dengan furniture lain, wall, queue slot, fixed structure, door tile, portal tile, service point, atau supply drop-off point.
- Interaction tile **boleh** berada di protected path (`WALKABLE_NO_BUILD`). Actor saling menembus saat berjalan bebas (Seksi 56.1), jadi orang yang berdiri memakai alat atau rak tidak memblokir jalur. Tile protected tetap tidak dapat dibangun dan flag-nya tidak berubah.
- Template layout Seksi 57 wajib mampu menampung jumlah slot Mixer/Oven/Display lokasi tersebut (Seksi 6) dengan equipment setier lokasi, termasuk tile aksesnya.

---

# **61. Product / Recipe Production Specification**

## **61.1 Recipe Availability — Canonical**

**Tidak ada skill unlock, recipe purchase, atau staff-tier requirement.** Sebuah resep dapat dibuat bila seluruh syarat berikut benar:
1. Seluruh bahan resep tersedia di storage.
2. Player memiliki jenis/tier equipment minimum yang dibutuhkan resep.
3. Kapasitas equipment/job slot tersedia.


## **61.2 Canonical Recipe Data Schema**

```gdscript
RecipeData {
  recipe_id: StringName,
  display_name: String,
  ingredients: Dictionary[ingredient_id, int],
  required_mixer_tier: int,
  required_oven_tier: int,
  mix_seconds_base: float,
  optional_prep_seconds: float,
  bake_seconds_base: float,
  yield_units: int,
  batch_cost_kr: float,
  default_unit_price_kr: float,
  min_unit_price_kr: float,
  max_unit_price_kr: float,
  base_expiry_ingame_hours: float,
  freshness_profile_id: StringName,
  customer_tags: Array[StringName]
}
```

`recipe_total_time` pada Seksi 61.5 adalah target total production time pada tier minimum yang disyaratkan. Pembagian default:
- Tier 1 simple bread: 40% mixing, 60% oven.
- Tier 2: 35% mixing, 15% prep/filling, 50% oven.
- Tier 3: 30% mixing, 25% prep/lamination, 45% oven.
- Tier 4: 25% mixing, 30% special prep/fermentation abstraction, 45% oven.
- Tier 5: 20% mixing, 30% finishing/prep, 50% oven/conveyor.

Porsi prep dikerjakan di Mixer sebagai bagian akhir tahap `MIXING`, sehingga beban Mixer (mix + prep) dan Oven per tier menjadi 40/60, 50/50, 55/45, 55/45, dan 50/50.

Equipment yang lebih tinggi daripada minimum menerapkan speed ratio berdasarkan equipment process speed, tetapi recipe tidak pernah menjadi instant (`minimum stage duration = 1.0 simulation-second`). Formula canonical: Seksi 18.5.

## **61.3 Canonical Expired Duration per Recipe**

`Expired Duration` adalah **base shelf-life dalam jam in-game sejak produk masuk Display**, sebelum modifier tier Display. Informasi ini wajib tampil di Recipe Book sebagai `Best Before / Expires in: X in-game hours` dan pada detail batch/display sebagai estimasi waktu tersisa aktual setelah modifier display.

| Recipe ID | Display Name | Base Expired Duration | Notes |
|---|---|---:|---|
| `recipe_plain_loaf` | Roti Tawar Polos | **20 h** | Roti dasar cukup tahan |
| `recipe_sugar_donut` | Donat Gula | **10 h** | Gorengan manis cepat turun kualitas |
| `recipe_plain_fried_bread` | Roti Goreng Polos | **8 h** | Paling baik dimakan hari yang sama |
| `recipe_chocolate_bread` | Roti Cokelat | **12 h** | Filling stabil sedang |
| `recipe_sausage_roll` | Roti Sosis Gulung | **8 h** | Isian daging memperpendek shelf-life |
| `recipe_sweet_cheese_bread` | Roti Keju Manis | **10 h** | Dairy filling |
| `recipe_strawberry_donut` | Donat Selai Stroberi | **8 h** | Filled donut, cepat melemah teksturnya |
| `recipe_classic_baguette` | Baguette Klasik | **12 h** | Cepat kehilangan crispness |
| `recipe_classic_croissant` | Croissant Klasik | **10 h** | Pastry berlemak |
| `recipe_cinnamon_roll` | Cinnamon Roll | **12 h** | Moist sweet roll |
| `recipe_pain_au_chocolat` | Pain au Chocolat | **10 h** | Laminated pastry |
| `recipe_danish_cheese` | Danish Cheese Pastry | **8 h** | Cheese filling |
| `recipe_milk_pullapart` | Roti Sobek Susu | **14 h** | Soft enriched bread |
| `recipe_almond_artisan_croissant` | Croissant Artisan Almond | **10 h** | Premium laminated pastry |
| `recipe_whole_wheat_sourdough` | Sourdough Whole Wheat | **30 h** | Shelf-life terpanjang |
| `recipe_gourmet_brioche` | Brioche Gourmet | **16 h** | Enriched loaf relatif tahan |
| `recipe_matcha_brioche` | Matcha Sweet Brioche | **14 h** | Enriched flavored bread |
| `recipe_basque_cheese_bun` | Basque Burnt Cheese Bun | **8 h** | Cream-cheese rich |
| `recipe_matcha_mille_crepes` | Matcha Mille Crepes | **6 h** | Produk sangat perishable |
| `recipe_truffle_bun` | Truffle Mushroom Artisan Bun | **10 h** | Savory premium filling |
| `recipe_luxury_almond_croissant` | Almond Croissant Mewah | **8 h** | Nut + cream cheese |
| `recipe_premium_cream_cheese_danish` | Premium Cream Cheese Danish | **6 h** | Dairy-heavy pastry |
| `recipe_golden_artisan` | Roti Emas Artisan | **12 h** | Premium but shelf-stable sedang |

**Interpretasi contoh:** Roti Tawar T1 memiliki base 20 h. Jika disimpan di Display T3 (`aging_rate=0.80`), effective shelf-life = `20 / 0.80 = 25 h in-game`.

## **61.4 Batch Object Lifecycle**

`RESERVED_INGREDIENTS -> MIX_WAIT -> MIXING -> CARRY_TO_OVEN -> BAKING -> READY_PERFECT -> OVERBAKING -> BURNT | CARRY_TO_DISPLAY -> DISPLAYED`

Bahan dikurangi saat batch dikonfirmasi. Jika job dibatalkan sebelum mixing dimulai, bahan dikembalikan penuh. Setelah mixing dimulai, bahan tidak dapat direfund.

`MIXING` mencakup `mix_seconds_base` + `optional_prep_seconds` (Seksi 18.5).

## **61.5 Canonical Recipe Production Data**

Tabel ini adalah satu-satunya definisi komposisi bahan, tier equipment minimum, dan durasi tahap per resep untuk field Seksi 61.2.

- Kolom `mixer` / `oven` = `required_mixer_tier` / `required_oven_tier`.
- Kolom `total` = `recipe_total_time`. Kolom `mix` / `prep` / `bake` = `mix_seconds_base` / `optional_prep_seconds` / `bake_seconds_base`.
- Semua durasi dalam simulation-second pada tier equipment minimum. Pembagian `total` ke `mix` / `prep` / `bake` mengikuti persentase Seksi 61.2 menurut tier minimum resep. `prep` dijalankan di Mixer. Durasi aktual per alat, batch, dan staf dihitung dengan Seksi 18.5.
- Biaya batch diturunkan dari kolom bahan (Seksi 63.1).
- Bahan ditulis untuk batch `x1` memakai ingredient ID Seksi 78.4 tanpa prefiks `ingredient_` (mis. `flour` = `ingredient_flour`). Batch `x3` / `x5` mengalikan jumlahnya secara linear (Seksi 18.9).
- Syarat produksi hanya bahan dan tier equipment minimum. Tidak ada syarat tier lokasi, tier staf, atau pembelian resep (Seksi 61.1).

| Recipe ID | Nama (narasi) | Bahan per batch x1 | mixer | oven | total | mix | prep | bake |
|---|---|---|---:|---:|---:|---:|---:|---:|
| `recipe_plain_loaf` | Roti Tawar Polos | flour 1, yeast 1, water_salt 1, butter 1 | 1 | 1 | 50 | 20 | 0 | 30 |
| `recipe_sugar_donut` | Donat Gula | flour 1, sugar 1, yeast 1, egg 1, butter 1 | 1 | 1 | 55 | 22 | 0 | 33 |
| `recipe_plain_fried_bread` | Roti Goreng Polos | flour 1, yeast 1, water_salt 1 | 1 | 1 | 35 | 14 | 0 | 21 |
| `recipe_chocolate_bread` | Roti Cokelat | flour 1, yeast 1, egg 1, chocolate 1, butter 1 | 2 | 2 | 45 | 15.75 | 6.75 | 22.5 |
| `recipe_sausage_roll` | Roti Sosis Gulung | flour 1, yeast 1, butter 1, beef_sausage 1 | 2 | 2 | 40 | 14 | 6 | 20 |
| `recipe_sweet_cheese_bread` | Roti Keju Manis | flour 1, sugar 1, egg 1, milk 1, cheddar 1 | 2 | 2 | 50 | 17.5 | 7.5 | 25 |
| `recipe_strawberry_donut` | Donat Selai Stroberi | flour 1, sugar 1, yeast 1, egg 1, strawberry_jam 1 | 2 | 2 | 55 | 19.25 | 8.25 | 27.5 |
| `recipe_classic_baguette` | Baguette Klasik | flour 1, yeast 1, water_salt 1 | 2 | 2 | 60 | 21 | 9 | 30 |
| `recipe_classic_croissant` | Croissant Klasik | flour 1, butter 2, egg 1, milk 1, yeast 1 | 3 | 3 | 75 | 22.5 | 18.75 | 33.75 |
| `recipe_cinnamon_roll` | Cinnamon Roll | flour 1, sugar 1, egg 1, butter 1, cinnamon 1 | 3 | 3 | 70 | 21 | 17.5 | 31.5 |
| `recipe_pain_au_chocolat` | Pain au Chocolat | flour 1, butter 2, chocolate 1, egg 1 | 3 | 3 | 80 | 24 | 20 | 36 |
| `recipe_danish_cheese` | Danish Cheese Pastry | flour 1, butter 1, egg 1, cheddar 1, milk 1 | 3 | 3 | 80 | 24 | 20 | 36 |
| `recipe_milk_pullapart` | Roti Sobek Susu | flour 1, milk 2, sugar 1, butter 1, egg 1 | 3 | 3 | 65 | 19.5 | 16.25 | 29.25 |
| `recipe_almond_artisan_croissant` | Croissant Artisan Almond | flour 1, organic_butter 1, egg 1, milk 1, almond 1 | 4 | 4 | 90 | 22.5 | 27 | 40.5 |
| `recipe_whole_wheat_sourdough` | Sourdough Whole Wheat | whole_wheat_flour 1, water_salt 1, yeast 1 | 4 | 4 | 120 | 30 | 36 | 54 |
| `recipe_gourmet_brioche` | Brioche Gourmet | flour 1, organic_butter 1, egg 2, sugar 1, milk 1 | 4 | 4 | 100 | 25 | 30 | 45 |
| `recipe_matcha_brioche` | Matcha Sweet Brioche | flour 1, organic_butter 1, egg 1, matcha 1, milk 1 | 4 | 4 | 110 | 27.5 | 33 | 49.5 |
| `recipe_basque_cheese_bun` | Basque Burnt Cheese Bun | flour 1, cream_cheese 1, egg 2, sugar 1 | 4 | 4 | 95 | 23.75 | 28.5 | 42.75 |
| `recipe_matcha_mille_crepes` | Matcha Mille Crepes | flour 1, matcha 1, egg 2, milk 2, organic_butter 1 | 5 | 5 | 150 | 30 | 45 | 75 |
| `recipe_truffle_bun` | Truffle Mushroom Artisan Bun | whole_wheat_flour 1, truffle 1, water_salt 1, yeast 1 | 5 | 5 | 140 | 28 | 42 | 70 |
| `recipe_luxury_almond_croissant` | Almond Croissant Mewah | flour 1, organic_butter 1, almond 1, cream_cheese 1, egg 1 | 5 | 5 | 130 | 26 | 39 | 65 |
| `recipe_premium_cream_cheese_danish` | Premium Cream Cheese Danish | flour 1, organic_butter 1, cream_cheese 1, strawberry_jam 1, egg 1 | 5 | 5 | 120 | 24 | 36 | 60 |
| `recipe_golden_artisan` | Roti Emas Artisan | whole_wheat_flour 1, organic_butter 1, truffle 1, almond 1, cream_cheese 1 | 5 | 5 | 180 | 36 | 54 | 90 |

## **61.6 Recipe Customer Tags**

Nilai field `customer_tags` (Seksi 61.2), dipakai oleh preferensi archetype Seksi 20.11. Kosakata tag: `sweet`, `savory`, `practical`, `family`, `premium`, `artisan`.

| Recipe ID | Tags |
| :--- | :--- |
| `recipe_plain_loaf` | practical, family |
| `recipe_sugar_donut` | sweet |
| `recipe_plain_fried_bread` | practical |
| `recipe_chocolate_bread` | sweet |
| `recipe_sausage_roll` | savory, practical |
| `recipe_sweet_cheese_bread` | sweet, family |
| `recipe_strawberry_donut` | sweet, family |
| `recipe_classic_baguette` | practical, artisan |
| `recipe_classic_croissant` | practical, premium |
| `recipe_cinnamon_roll` | sweet, family |
| `recipe_pain_au_chocolat` | sweet, premium |
| `recipe_danish_cheese` | family, premium |
| `recipe_milk_pullapart` | sweet, family |
| `recipe_almond_artisan_croissant` | premium, artisan |
| `recipe_whole_wheat_sourdough` | artisan, practical |
| `recipe_gourmet_brioche` | premium, family |
| `recipe_matcha_brioche` | premium, sweet |
| `recipe_basque_cheese_bun` | premium, sweet |
| `recipe_matcha_mille_crepes` | premium, sweet |
| `recipe_truffle_bun` | premium, artisan, savory |
| `recipe_luxury_almond_croissant` | premium, artisan |
| `recipe_premium_cream_cheese_danish` | premium, sweet |
| `recipe_golden_artisan` | premium, artisan |

---

# **62. Burn System — Final Numeric Rules**

Bake timer recipe menentukan kapan status `READY_PERFECT` dimulai. Setelah itu oven mempunyai perfect-retrieval window berdasarkan tier.

| Oven Tier | Perfect Window | Overbake Window | Total Grace Before BURNT |
|---|---:|---:|---:|
| T1 | 8 s | 8 s | 16 s |
| T2 | 10 s | 10 s | 20 s |
| T3 | 14 s | 12 s | 26 s |
| T4 | 20 s | 15 s | 35 s |
| T5 | 30 s | 20 s | 50 s |

During `READY_PERFECT`: quality multiplier = `1.00`.

During `OVERBAKING`, quality multiplier turun linear dari `0.95 -> 0.60`. Visual berubah golden-brown ke dark-brown dan smoke meningkat.

Saat timer overbake berakhir: status `BURNT`, quality multiplier `0.0`, item **tidak dapat dijual**. Player/staff harus mengambil batch dari oven; batch lalu otomatis masuk disposal/trash dan tidak menghasilkan KR. Oven tidak bisa menerima batch baru selama batch burnt masih tertahan.

Baker `Auto-Retrieve` melakukan retrieval tepat pada transisi ke `READY_PERFECT` bila proc berhasil; Tier 5 Baker selalu berhasil.

> Freshness setelah roti masuk Display mengikuti **Seksi 19.7 dan 61.3**. Burn quality dan freshness adalah dua sistem terpisah.

---

# **63. Final Recipe Economy — Unit Pricing Model**

## **63.1 Interpretation**

Tabel berikut adalah **satu-satunya canonical unit-pricing reference** untuk ekonomi resep.

- `default_unit_price_kr` adalah harga jual default per unit (nilai desain).
- `batch_cost_kr` adalah **nilai turunan**: Σ(`fixed_buy_price_kr` × jumlah bahan batch `x1` pada Seksi 61.5). Nilainya selalu sama dengan uang yang benar-benar dibayar pemain di Pasar untuk satu batch.
- `unit_cogs_kr = batch_cost_kr / batch_yield`.
- `revenue_per_batch = default_unit_price_kr × batch_yield`.
- `gross_profit_per_batch = revenue_per_batch − batch_cost_kr`.

Kolom Batch Cost, HPP, Revenue, dan Gross Profit di bawah adalah hasil formula tersebut; bila catalog menyimpannya, validator wajib memastikan nilainya sama (Seksi 133.1). Semua UI/analytics membaca field catalog ini dan tidak menghitung ulang dari tabel legacy.

| Recipe | Batch Cost | Yield | HPP / Unit | Default Price / Unit | Revenue / Batch | Gross Profit / Batch | Base Expired Duration |
|---|---:|---:|---:|---:|---:|---:|---:|
| Roti Tawar Polos | 340 | 6 | 56.7 | 90 | 540 | 200 | **20 h** |
| Donat Gula | 500 | 5 | 100 | 150 | 750 | 250 | **10 h** |
| Roti Goreng Polos | 220 | 6 | 36.7 | 65 | 390 | 170 | **8 h** |
| Roti Cokelat | 670 | 5 | 134 | 240 | 1,200 | 530 | **12 h** |
| Roti Sosis Gulung | 670 | 5 | 134 | 220 | 1,100 | 430 | **8 h** |
| Roti Keju Manis | 780 | 5 | 156 | 270 | 1,350 | 570 | **10 h** |
| Donat Selai Stroberi | 580 | 5 | 116 | 210 | 1,050 | 470 | **8 h** |
| Baguette Klasik | 220 | 3 | 73.3 | 215 | 645 | 425 | **12 h** |
| Croissant Klasik | 690 | 4 | 172.5 | 400 | 1,600 | 910 | **10 h** |
| Cinnamon Roll | 630 | 4 | 157.5 | 375 | 1,500 | 870 | **12 h** |
| Pain au Chocolat | 740 | 4 | 185 | 450 | 1,800 | 1,060 | **10 h** |
| Danish Cheese Pastry | 820 | 4 | 205 | 440 | 1,760 | 940 | **8 h** |
| Roti Sobek Susu | 750 | 6 | 125 | 260 | 1,560 | 810 | **14 h** |
| Croissant Artisan Almond | 1,500 | 4 | 375 | 700 | 2,800 | 1,300 | **10 h** |
| Sourdough Whole Wheat | 470 | 2 | 235 | 1,100 | 2,200 | 1,730 | **30 h** |
| Brioche Gourmet | 1,180 | 4 | 295 | 750 | 3,000 | 1,820 | **16 h** |
| Matcha Sweet Brioche | 1,800 | 4 | 450 | 875 | 3,500 | 1,700 | **14 h** |
| Basque Burnt Cheese Bun | 1,180 | 4 | 295 | 625 | 2,500 | 1,320 | **8 h** |
| Matcha Mille Crepes | 2,050 | 2 | 1,025 | 2,750 | 5,500 | 3,450 | **6 h** |
| Truffle Mushroom Artisan Bun | 1,670 | 3 | 556.7 | 2,000 | 6,000 | 4,330 | **10 h** |
| Almond Croissant Mewah | 2,100 | 4 | 525 | 1,250 | 5,000 | 2,900 | **8 h** |
| Premium Cream Cheese Danish | 1,800 | 4 | 450 | 1,125 | 4,500 | 2,700 | **6 h** |
| Roti Emas Artisan | 3,450 | 2 | 1,725 | 4,000 | 8,000 | 4,550 | **12 h** |

### **63.2 Price Slider Limits & Demand Response — CANONICAL**

Seluruh aturan harga ada di seksi ini. Seksi 20.7, 65, 84.2, 84.3, dan 84.5 hanya mereferensikannya.

Per recipe:
- `min_price = max(round_to_5(HPP_unit × 1.05), round_to_5(default_price × 0.60))`.
- `max_price = round_to_5(default_price × 1.80)`.
- Slider step = 5 KR untuk default price < 1,000 KR; 25 KR untuk >=1,000 KR. Nilai slider selalu di-clamp ke `min_price..max_price`.
- Harga per unit **dikunci** saat customer mengambil roti dari rak, atau saat pesanan RotiFood dibuat. Perubahan harga sesudahnya tidak memengaruhi transaksi itu.

Baseline demand multiplier (kontinu, piecewise linear):

```text
price_ratio = player_price / default_price
if ratio <= 0.80: price_demand = 1.25
0.80 < ratio <= 1.00: interpolate 1.25 -> 1.00
1.00 < ratio <= 1.25: interpolate 1.00 -> 0.72
1.25 < ratio <= 1.50: interpolate 0.72 -> 0.40
ratio > 1.50: interpolate 0.40 -> 0.10 at ratio 1.80
```

Sensitivitas archetype `s` menskalakan simpangan dari 1.0, baik untuk bonus harga murah maupun penalti harga mahal:

```text
effective_price_demand = clamp(1.0 + s × (price_demand − 1.0), 0.0, 1.5)
```

| Archetype | `s` |
| :--- | ---: |
| `customer_school_child` | 1.25 |
| `customer_office_worker` | 1.00 |
| `customer_generic` | 1.00 |
| `customer_bulk_buyer` | 1.10 |
| `customer_indecisive` | 1.00 |
| `customer_snob` | 0.35 |
| `customer_critic` | 0.60 (quality sensitivity tetap tinggi, Seksi 20.10) |

Pemakaian:
- `price_mix_multiplier` pada Seksi 65 memakai `price_demand` baseline.
- Bobot pilihan resep dan `price_acceptance` customer (Seksi 20.6, 84.2, 84.3) memakai `effective_price_demand`.
- Label reaksi untuk UI diturunkan dari nilai ini (Seksi 84.5).

Harga murah dapat menaikkan demand tetapi tidak pernah meningkatkan revenue per item secara ajaib. Customer membeli berdasarkan affordability/preference check saat memilih display.

---

# **64. Location Progression — Money Only**

Upgrade lokasi hanya membutuhkan KR. Tidak ada rating gate, day gate, achievement gate, atau skill gate.

Biaya upgrade canonical: baris **Harga Beli / Upgrade** pada tabel Seksi 6 (satu-satunya definisi).

Upgrade hanya dapat dikonfirmasi bila saldo setelah transaksi tidak negatif. Upgrade memigrasikan furniture yang kompatibel ke `unplaced_owned_furniture` bila posisi lama tidak valid di layout baru; player kemudian dapat menata ulang.

---

# **65. Demand Formula — Final**

Demand dihitung per channel (physical dan RotiFood) menggunakan expected arrivals, lalu scheduler mengubahnya menjadi event kedatangan.

```text
expected_arrivals_per_ingame_hour =
    base_rate_by_tier
  × rating_multiplier
  × time_of_day_multiplier
  × weather_multiplier
  × marketing_multiplier
  × price_mix_multiplier
  × event_multiplier
```

Base physical rate (per in-game hour): `T1=2.0, T2=3.5, T3=5.0, T4=7.5, T5=10.0`.

Base RotiFood orders/hour: `T1=0.6, T2=1.0, T3=1.8, T4=3.0, T5=4.5`.

Physical rating multiplier:
`clamp(0.55 + 0.18 × rating_stars, 0.73, 1.45)` untuk rating 1–5.

RotiFood star multiplier:
`clamp(0.40 + 0.16 × stars, 0.56, 1.20)`, lalu dikali `1.50` bila badge **Toko Terpercaya** aktif (stars ≥ 4.5, Seksi 9.2); total clamp `<=1.80`.

Channel multiplier:
- `marketing_multiplier` hanya berlaku untuk channel fisik; untuk RotiFood nilainya `1.0` (Seksi 8).
- `weather_multiplier` dan `event_multiplier` per channel mengikuti Seksi 26.6.

Price mix multiplier = weighted average `price_demand` baseline (Seksi 63.2) dari roti yang sedang tersedia, clamp `0.35..1.25`.

Final arrival rate selalu clamp agar tidak melampaui throughput yang masuk akal: logical pending pool maksimum `3 × relevant queue capacity`.

### **65.1 Penjelasan Sederhana**

Game pertama-tama menentukan **berapa ramai toko seharusnya** berdasarkan tier. Rating bagus membuat lebih ramai, jam sibuk membuat lebih ramai, hujan dapat mengurangi pejalan kaki tetapi meningkatkan delivery, marketing memberi boost, dan harga terlalu mahal mengurangi minat. Hasil formula bukan berarti semua NPC muncul sekaligus; scheduler menyebarkannya sepanjang jam tersebut dan tetap tunduk pada kapasitas antrean.

---

# **66. Daily Arrival Schedule**

Selling period = 08:00–18:00.

Physical `time_of_day_multiplier`:
- 08:00–10:00: **1.35** (office morning rush).
- 10:00–12:00: **0.90**.
- 12:00–14:00: **1.05**.
- 14:00–16:30: **1.30** (school + afternoon traffic).
- 16:30–18:00: **0.85**.

RotiFood multiplier:
- 08:00–10:00: 1.10.
- 10:00–12:00: 0.85.
- 12:00–14:00: 1.25.
- 14:00–16:30: 1.00.
- 16:30–18:00: 1.30.

Scheduler menggunakan randomized interval dengan deterministic RNG seed per day. Interval tidak boleh lebih pendek dari 2 simulation-seconds untuk physical actor admission attempt.

Hari 1–3 tetap memakai scripted schedule yang sudah ditetapkan dan mengabaikan formula random normal.

---

# **67. Pending Arrival & Maximum Delay**

Jika target queue penuh, arrival menjadi `PENDING` dan belum spawn.

- `pending_since_game_time` dicatat.
- Retry saat `queue_slot_freed` atau setiap 2 simulation-seconds.
- **Maximum pending delay = 30 simulation-seconds** untuk customer fisik.
- **Maximum pending delay = 40 simulation-seconds** untuk RotiFood Driver.
- Jika delay habis, arrival dibatalkan secara senyap sebelum actor masuk toko.
- Pending cancellation **tidak** menurunkan rating karena customer belum pernah memasuki toko.
- Namun demand event dianggap terlewat dan tidak di-reschedule ulang; pemain kehilangan potensi revenue. Ini mencegah eksploitasi queue-full tanpa menciptakan penalty ganda.

---

# **68. Multi-Floor Transition — Canonical**

Tier 2 dan Tier 3 menggunakan **instant floor portal**.

Saat actor mencapai interaction tile di depan stair door:
1. Actor snap/transition ke paired portal pada floor tujuan.
2. Tidak ada animasi naik tangga.
3. Tidak ada travel-time penalty.
4. Tidak mengonsumsi in-game time di luar normal frame transition.
5. Pathfinding graph memperlakukan portal sebagai edge dengan traversal cost sangat kecil (`0.1 tile-equivalent`) agar tidak menghasilkan zero-cost loop.

Customer tidak pernah memiliki permission menuju kitchen floor. Player dan kitchen staff boleh.

> **Camera multi-floor behavior FINAL:** ikuti Seksi 30. Kamera mengikuti player, active floor tunggal, instant transition + crossfade 0.20 s, dan off-floor alert untuk event penting.

---

# **69. Customer Product Selection & Substitution**

Customer memiliki ordered preference tags. Selection flow:
1. Cari bread yang cocok dengan first-choice preference dan masih tersedia.
2. Jika habis, cari alternatif berikutnya dari roti available yang cocok minimal satu preference tag.
3. Jika tidak ada match, pilih fallback dari semua roti available berdasarkan weighted attractiveness `preference × price_acceptance × quality`.
4. Jika **seluruh display benar-benar kosong**, customer langsung masuk state `LEAVE_NO_STOCK` dan keluar tanpa antre.
5. Customer yang belum mengambil roti tidak menurunkan stok.

Tidak ada waiting-for-restock behavior untuk customer yang mendapati display benar-benar kosong.

---

# **70. Supply Courier Priority & After-Hours Rule**

Kurir suplai memiliki navigation priority untuk mencapai cash register supply drop-off point. Karena free-walking actor dapat saling menembus, keramaian customer tidak boleh menghalangi jalannya.

- Kurir suplai **tidak memakai customer queue**.
- Player tidak perlu standby di meja kasir.
- Saat courier mencapai drop-off commit point, package visual diletakkan, lalu inventory order **langsung dipindahkan ke Storage secara atomik**.
- Setelah commit, courier berbalik dan keluar toko.
- Supply drop-off point adalah `INTERACTION_RESERVED` dan tidak dapat ditutup furniture.
- Bila ETA order terjadi sebelum 18:00 tetapi courier belum sempat commit sampai clock mencapai 18:00, order **langsung diselesaikan secara otomatis pada 18:00**, inventory masuk Storage, actor courier bila sudah spawn dibatalkan/despawn secara aman.
- Semua order yang ETA-nya >=18:00 juga auto-complete pada transisi closing tanpa visual courier.

---

# **71. Game Speed & Pause Balancing**

Available simulation speeds: **Pause / 1× / 2× / 3×**.

- Time-of-day, movement, equipment, burn, patience, delivery ETA, dan order timer semuanya memakai simulation time dan ikut speed multiplier.
- UI animations boleh tetap real-time agar nyaman dilihat.
- Opening a **blocking management menu** selalu memaksa simulation pause: Market, Recipe Book, Staff Management, Marketing, Settings, Upgrade, Decoration Mode, Daily Summary.
- Menutup menu mengembalikan speed yang aktif sebelum menu dibuka, kecuali player memilih speed baru.
- Popup checkout customer bukan management menu, tetapi tetap mem-pause selama menunggu keputusan pemain (Seksi 15.2). Aksi transaksi setelah OK (membungkus, packing) mengikuti simulation time.

### **71.1 Smart Speed Safety**

Untuk menjaga 3× tetap fair:
- Jika oven manual memasuki `READY_PERFECT`, speed otomatis turun ke 1×.
- Jika customer patience terendah turun di bawah 10%, speed otomatis turun ke 1× satu kali per event cluster.
- Jika RotiFood prep timer tersisa <=10 simulation-seconds, speed otomatis turun ke 1×.
- Player bebas menaikkan speed kembali setelah warning.

Setting `Smart Speed Safety` default ON dan dapat dimatikan di Gameplay Settings.

---

# **72. Decoration Mode — Anytime, Safe, and Paused**

Decoration Mode dapat dibuka kapan saja selama gameplay. Membukanya **pause simulation**.

Furniture dapat dipindah/rotate selama:
- tidak sedang memiliki active production content;
- tidak sedang di-reserve actor;
- placement target valid;
- protected path validation tetap lulus.

Jika furniture sedang digunakan, tampilkan alasan `IN_USE` dan placement tidak dimulai. Tidak ada kebutuhan menunggu toko tutup.

## **72.1 Decoration Catalog — CANONICAL**

Dekorasi murni kosmetik. Ia tidak mengubah demand, rating, kecepatan, footprint alat, atau interaction (Seksi 92.1). Dekorasi dibeli lewat tab **Decor Shop** di Decoration Mode, atau didapat dari achievement. Seperti equipment (Seksi 5.1.2), Decor Shop hanya aktif after-hours; menata ulang dekorasi yang sudah dimiliki boleh kapan saja.

**Jenis penempatan:**
- `wall`: slot dinding; tidak memakai cell grid.
- `floor_prop`: footprint 1×1 di `WALKABLE_BUILDABLE` zona store; ikut validasi placement Seksi 17.3 dan 56.1.2.
- `floor_overlay`: karpet atau tikar; walkable dan tidak memblok apa pun.
- `counter_prop`: di atas meja kasir; tidak memakai cell.
- `skin`: mengganti tampilan alat, meja, papan nama, atau UI; tidak memakai cell.
- `outfit`: kosmetik karakter pemain atau staf.
- `badge`: tanda di kartu profil.

Maksimal **24** dekorasi terpasang per floor (Seksi 129). Nama English: Seksi 127.11.

**Decor Shop:**

| ID | Jenis | Harga |
| :--- | :--- | ---: |
| `decor_potted_plant` | floor_prop | 300 KR |
| `decor_gingham_curtains` | wall | 400 KR |
| `decor_wall_clock_pendulum` | wall | 500 KR |
| `decor_chalk_menu_board` | wall | 600 KR |
| `decor_bread_basket_stack` | floor_prop | 700 KR |
| `decor_cassette_radio` | counter_prop | 800 KR |
| `decor_flower_window_box` | wall | 900 KR |
| `decor_family_photo_wall` | wall | 1,000 KR |
| `decor_hanging_lamp_warm` | wall | 1,200 KR |
| `decor_terracotta_rug` | floor_overlay | 1,500 KR |
| `skin_storefront_striped_awning` | skin | 3,000 KR |
| `skin_storefront_sign_carved_wood` | skin | 5,000 KR |

**Hadiah achievement** (tidak dijual; memetakan kolom Reward Seksi 74):

| Achievement | Reward ID | Jenis |
| :--- | :--- | :--- |
| `ach_first_sale` | `badge_first_crumb` | badge |
| `ach_100_breads` | `decor_plaque_hundred_buns` | wall |
| `ach_1000_breads` | `outfit_apron_neighborhood` | outfit |
| `ach_no_burn_day` | `skin_oven_decal_golden` | skin |
| `ach_week_no_burn` | `outfit_chef_hat_perfect` | outfit |
| `ach_queue_master` | `decor_floor_mat_smooth` | floor_overlay |
| `ach_roti_food_5` | `skin_rotifood_counter_five_star` | skin |
| `ach_cash_10k` | `badge_first_savings` | badge |
| `ach_cash_100k` | `decor_gold_coin_jar` | counter_prop |
| `ach_cash_1m` | `decor_trophy_millionaire` | counter_prop |
| `ach_tier2` | `decor_plaque_tier2` | wall |
| `ach_tier3` | `decor_plaque_tier3` | wall |
| `ach_tier4` | `decor_plaque_tier4` | wall |
| `ach_tier5` | `decor_trophy_landmark` | floor_prop |
| `ach_all_recipes` | `skin_recipe_book_encyclopedia` | skin |
| `ach_price_experiment` | `decor_retro_calculator` | counter_prop |
| `ach_rain_delivery` | `decor_umbrella_stand` | floor_prop |
| `ach_solo_recovery` | `decor_photo_pak_lurah` | wall |
| `ach_big_day` | `decor_brass_bell` | counter_prop |
| `ach_overflow` | `decor_plaque_infinity` | wall |

---

# **73. Endless Economy & Overflow Behavior**

Game tidak memiliki victory screen atau final ending. Setelah Tier 5, permainan tetap berjalan tanpa batas dengan tujuan intrinsik: optimasi, dekorasi, achievements, rating, dan mengumpulkan KR sebanyak mungkin.

`cash_kr` disimpan sebagai **64-bit floating point (`float64`)** untuk memenuhi endless accumulation design. Nilai praktis maksimum finite sekitar `1.7976931348623157e308`.

Karena integer precision tidak exact di angka sangat besar, HUD memakai format compact/scientific mulai `1e12 KR` (Seksi 99.2).

Jika operasi menghasilkan `INF`/overflow:
- jangan corrupt save;
- set `economy_overflowed = true`;
- tampilkan celebratory diagnostic overlay **“You Broke the Bakery Economy!”**;
- gameplay dapat tetap berjalan tetapi transaksi tidak lagi menambah nilai finite;
- ini bukan conventional ending dan tidak memaksa player berhenti.

---

# **74. Achievements**

Achievements disimpan account/save-local dan tidak diperlukan untuk unlock recipe/location.

| ID | Name | Requirement | Reward |
|---|---|---|---|
| `ach_first_sale` | First Crumb | Selesaikan 1 penjualan | badge |
| `ach_100_breads` | Hundred Buns | Jual 100 unit | cosmetic wall plaque |
| `ach_1000_breads` | Neighborhood Bakery | Jual 1,000 unit | apron cosmetic |
| `ach_no_burn_day` | Golden, Not Charcoal | 1 hari tanpa burnt batch | oven decal |
| `ach_week_no_burn` | Perfect Baker | 7 hari berturut-turut tanpa burnt batch | chef hat cosmetic |
| `ach_queue_master` | Smooth Queue | Satu hari tanpa customer abandon | floor mat cosmetic |
| `ach_roti_food_5` | Five-Star Delivery | Capai 5.0 RotiFood Stars | delivery counter skin |
| `ach_cash_10k` | First Savings | Punya 10,000 KR | badge |
| `ach_cash_100k` | Flour Millionaire-ish | Punya 100,000 KR | gold coin decor |
| `ach_cash_1m` | Bakery Millionaire | Punya 1,000,000 KR | trophy |
| `ach_tier2` | Proper Shop | Upgrade T2 | plaque |
| `ach_tier3` | Independent Bakery | Upgrade T3 | plaque |
| `ach_tier4` | Flagship | Upgrade T4 | plaque |
| `ach_tier5` | Landmark | Upgrade T5 | landmark trophy |
| `ach_all_recipes` | Bread Encyclopedia | Produksi semua recipe minimal sekali | recipe-book skin |
| `ach_price_experiment` | Market Research | Jual item di <80% dan >125% default price | calculator decor |
| `ach_rain_delivery` | Rainy Payday | 20 RotiFood orders sukses dalam satu hari hujan | umbrella decor |
| `ach_solo_recovery` | Back on Your Feet | Keluar dari kondisi bailout dengan saldo >5,000 KR | Pak Lurah photo |
| `ach_big_day` | Busy Oven | Revenue harian >50,000 KR | bell cosmetic |
| `ach_overflow` | Beyond Accounting | Trigger economy overflow guard | unique infinity plaque |

Rewards kosmetik tidak memengaruhi throughput/economy. ID reward canonical per achievement: Seksi 72.1.

---

# **75. Settings & Accessibility Specification**

## **75.1 Audio**
- Master Volume 0–100.
- Music 0–100.
- SFX 0–100.
- UI 0–100.
- Ambient 0–100.
- Mute when app unfocused toggle.

## **75.2 Display**
- Fullscreen/windowed (desktop).
- Resolution scale 70/85/100% (desktop/web where supported).
- UI scale 80–150%.
- Brightness 80–120%.
- FPS cap 30/60/Unlimited where platform permits.

## **75.3 Gameplay**
- Smart Speed Safety ON/OFF.
- Edge scroll desktop ON/OFF if camera uses it.
- Confirm expensive purchase ON/OFF; threshold configurable default 5,000 KR.
- Tutorial hints ON/OFF after completion.

## **75.4 Accessibility**
- Reduced Motion: mengurangi bounce, screen shake, rapid tween, particle density.
- Screen Shake: 0–100, default 30.
- Vibration/Haptics: ON/OFF Android.
- High Contrast Interaction Markers.
- Color-independent status icons: burn/patience/rating tidak boleh mengandalkan warna saja.
- Patience Bar Size: Normal/Large.
- UI Text Scale mengikuti UI scale tetapi minimum readability tidak boleh di bawah 14 logical px.
- Dyslexia-friendly font option hanya jika tersedia procedural/system font compatible; jangan bundel asset eksternal tanpa keputusan lisensi.
- Hold-to-confirm alternative untuk destructive actions.
- Audio cue captions: `[Oven Ding]`, `[Order Arrived]`, `[Customer Upset]` bila `Sound Captions` ON.

---

# **76. Audio Event List & Generative Description**

Katalog event audio canonical, berisi ID stabil beserta deskripsi generatifnya, hanya ada di **Seksi 93**. AI audio generator/procedural audio implementation memakai deskripsi di sana sebagai intent, bukan menyalin copyrighted melody.

Audio must support deterministic event IDs and pooled playback. Simultaneous repeated cash/footstep events require cooldown/voice limit to avoid noise buildup.

---

# **77. Save/Load Explicit Contract**

Save format wajib versioned: `schema_version` (Seksi 106).

Persist minimally:
- day number, exact in-game time, active speed before pause;
- cash_kr and economy_overflowed;
- location tier;
- all ingredient `on_hand` and `in_transit` purchase orders with ETA/order state;
- equipment tier, positions, rotations, active jobs;
- batch state including recipe ID, current stage, stage progress, burn timer state;
- display inventory by recipe, bake quality, `age_ingame_hours`, base expiry, freshness state, display tier, and `last_freshness_rollover_day`;
- customer/driver logical state **hanya untuk safe resume snapshot**;
- queue reservations;
- staff roster/employment/on-duty state;
- ratings, marketing state, weather, RNG seed/day seed;
- achievements;
- settings/accessibility separately from career saves, in `user://settings.json` (Section 106).

### **77.1 Mid-Production Save**

Jika save terjadi saat mixing/baking, load harus melanjutkan progress yang sama; timer tidak reset dan tidak maju selama aplikasi tertutup.

### **77.2 Queue Save Policy**

Active customer actors tidak perlu menyimpan raw transform. Simpan logical queue/order snapshot. Saat load, actor direkonstruksi ke canonical slot berdasarkan queue order. Tidak boleh ada double-sale atau duplicate held bread.

### **77.3 Supply Delivery Save Policy**

Order `IN_TRANSIT` mempertahankan ETA. Jika save/load dilakukan pada waktu game yang sama, ETA tidak berubah. Courier visual dapat direkonstruksi atau direspawn; inventory commit hanya berdasarkan persistent `order_committed=false/true` guard.

### **77.4 RNG**

Simpan `day_seed` dan stream state penting agar save/load tidak reroll cuaca, pending scripted event, atau immediate next arrivals secara eksploitatif.

### **77.5 Atomic Save**

Write ke temporary file -> verify -> replace main save. Simpan backup terakhir. Data `INF/NaN` tidak boleh ditulis kecuali economy overflow telah dinormalisasi ke explicit overflow flag.

---

# **78. Canonical ID Table**

Naming rule: lowercase snake_case, stable selamanya setelah shipped. Seksi ini adalah **satu-satunya sumber ID**; seksi lain (termasuk katalog English Seksi 127) wajib memakai ID ini.

## **78.1 Core**
`player`, `currency_kr`, `rating_physical`, `rating_rotifood`, `market_ingredients`.

## **78.2 Locations**
`location_t1_garage`, `location_t2_shophouse`, `location_t3_independent_bakery`, `location_t4_flagship`, `location_t5_landmark`.

Floor: `floor_1` (lantai dasar/toko; satu-satunya floor untuk Tier 1, 4, 5) dan `floor_2` (lantai atas/dapur Tier 2–3).

## **78.3 Equipment**
`storage_t1..storage_t5`, `mixer_t1..mixer_t5`, `oven_t1..oven_t5`, `display_t1..display_t5`, `counter_cashier`, `counter_rotifood`.

## **78.4 Ingredients**
`ingredient_flour`, `ingredient_sugar`, `ingredient_yeast`, `ingredient_egg`, `ingredient_butter`, `ingredient_water_salt`, `ingredient_chocolate`, `ingredient_cheddar`, `ingredient_strawberry_jam`, `ingredient_milk`, `ingredient_beef_sausage`, `ingredient_cinnamon`, `ingredient_whole_wheat_flour`, `ingredient_organic_butter`, `ingredient_almond`, `ingredient_cream_cheese`, `ingredient_matcha`, `ingredient_truffle`.

## **78.5 Recipes**
`recipe_plain_loaf`, `recipe_sugar_donut`, `recipe_plain_fried_bread`, `recipe_chocolate_bread`, `recipe_sausage_roll`, `recipe_sweet_cheese_bread`, `recipe_strawberry_donut`, `recipe_classic_baguette`, `recipe_classic_croissant`, `recipe_cinnamon_roll`, `recipe_pain_au_chocolat`, `recipe_danish_cheese`, `recipe_milk_pullapart`, `recipe_almond_artisan_croissant`, `recipe_whole_wheat_sourdough`, `recipe_gourmet_brioche`, `recipe_matcha_brioche`, `recipe_basque_cheese_bun`, `recipe_matcha_mille_crepes`, `recipe_truffle_bun`, `recipe_luxury_almond_croissant`, `recipe_premium_cream_cheese_danish`, `recipe_golden_artisan`.

## **78.6 Customer Types**
`customer_school_child`, `customer_office_worker`, `customer_bulk_buyer`, `customer_snob`, `customer_indecisive`, `customer_critic`, `customer_generic`, `driver_rotifood`, `courier_supply`.

## **78.7 Staff (roster Seksi 3.5)**
Asisten Kasir: `staff_cashier_budi`, `staff_cashier_sari`, `staff_cashier_dimas`, `staff_cashier_nadia`, `staff_cashier_rian`, `staff_cashier_lili`, `staff_cashier_maya`, `staff_cashier_reza`, `staff_cashier_dewi`, `staff_cashier_hendra`, `staff_cashier_citra`, `staff_cashier_kenji`, `staff_cashier_grace`, `staff_cashier_tejo`, `staff_cashier_luna`.

Asisten Dapur: `staff_baker_joko`, `staff_baker_ani`, `staff_baker_bagus`, `staff_baker_fajar`, `staff_baker_rina`, `staff_baker_doni`, `staff_baker_aris`, `staff_baker_tari`, `staff_baker_gilang`, `staff_baker_sophie`, `staff_baker_danu`, `staff_baker_aoi`, `staff_baker_pierre`, `staff_baker_mawar`, `staff_baker_alistair`.

## **78.8 Marketing Campaigns (Seksi 8.1)**
`campaign_flyer_t1`, `campaign_street_banner_t2`, `campaign_radio_magazine_t3`, `campaign_influencer_t4`, `campaign_food_festival_t5`.

## **78.9 Weather & Events (Seksi 26)**
`weather_sunny`, `weather_rain`, `event_holiday`.

## **78.10 ID yang Didefinisikan di Seksi Lain**
Achievement: Seksi 74 (`ach_*`). Audio event: Seksi 93. UI string: Seksi 127. Dekorasi & kosmetik: Seksi 72.1. Test: Seksi 107. Save profile: `profile_1..profile_3` (Seksi 89.3).

IDs tidak boleh berasal dari translated display string.

---

# **81. Freshness & Multi-Floor Acceptance Tests**

1. Placement furniture yang menutup protected path harus ditolak sebelum commit.
2. Dua free-walking actor boleh melewati koordinat world yang sama tanpa physics blocking.
3. Dua actor tidak pernah memiliki queue slot atau equipment interaction slot yang sama.
4. Setiap furniture valid memiliki minimal satu empty interaction tile pada sisi depan setelah rotasi.
5. Tier 1 antrean tidak menerima actor kelima jika empat slot penuh; actor kelima menjadi pending maksimal 30 s.
6. Office Worker patience habis dalam 18 simulation-seconds baseline jika queue tidak bergerak dan tidak ada modifier.
7. Saat speed 3×, timer simulation bergerak 3× tetapi management menu menghentikan timer sepenuhnya.
8. Oven selesai pada 3× harus trigger Smart Speed Safety dan kembali ke 1× sebelum burn window habis secara tidak terlihat.
9. Recipe tersedia hanya berdasarkan ingredients + required equipment; tidak ada recipe purchase/unlock flag dalam data maupun save.
10. Harga default unit × yield menghasilkan revenue batch yang mendekati canonical target dengan rounding yang terdokumentasi.
11. Customer yang first-choice habis memilih alternatif; jika seluruh display kosong, customer keluar tanpa queue.
12. Supply courier dapat mencapai drop-off walau toko padat karena tidak collision-blocked oleh NPC.
13. Pada tepat 18:00, supply order yang belum visual commit harus auto-commit tepat sekali ke storage dan courier dibersihkan.
14. Decoration Mode dapat dibuka saat selling, langsung pause, dan menolak furniture `IN_USE`.
15. Save saat oven berada di OVERBAKING lalu load menghasilkan stage dan remaining timer identik.
16. Queue actor pada load direkonstruksi ke canonical slot tanpa duplicate item/sale.
17. Tier 2/3 actor berpindah floor segera ketika mencapai stair door interaction tile; tidak ada stair animation/delay.
18. Location upgrade hanya memeriksa saldo KR dan biaya upgrade.
19. `cash_kr` yang mendekati float overflow tidak boleh merusak save; overflow mengaktifkan explicit guard state.
20. Bread dengan `age_ratio < 1.0` bertahan lintas day rollover; rollover 18:00->05:00 menambahkan tepat 11 in-game hours dikalikan display aging rate.
21. Bread yang mencapai `age_ratio >= 1.0` saat rollover menjadi `UNSALEABLE`, dihapus sekali dari display, dan HPP-nya tercatat sebagai waste tanpa rating penalty tambahan.
22. Save/load tidak boleh mereset `age_ingame_hours` atau menerapkan overnight aging dua kali.
23. Recipe Book menampilkan base expired duration sesuai tabel 61.3 dan detail display menampilkan estimasi sisa waktu berdasarkan display tier aktif.
24. Saat player Tier 2/3 berpindah floor, `active_floor_id` berubah dan kamera melakukan crossfade 0.20 s tanpa mengonsumsi in-game time.
25. Staff/oven di inactive floor tetap memproses simulation timer walaupun visual floor disembunyikan.
26. Event `OVERBAKING` pada inactive floor menghasilkan critical off-floor alert, tetapi tidak memindahkan kamera; tap alert hanya menyorot portal.
27. Kamera tidak berpindah floor ketika staff atau NPC berpindah; hanya floor player yang menentukan active camera.


---

# **83. NPC Admission, Door, Visibility, dan Lifetime**

## **83.1 Single Front Door Contract**

Setiap lokasi memiliki **satu logical front-door transit portal** yang dipakai untuk masuk dan keluar.

Tile pintu selalu memiliki flag:

```text
WALKABLE = true
NO_BUILD = true
RESERVED_TRANSIT = true
```

- Player/customer/staff/driver/courier boleh saling menembus ketika berada dalam free-walk transit.
- Door tile tidak memiliki exclusive occupancy lock.
- Queue slot dan equipment interaction tile tetap exclusive dan tidak boleh overlap.
- Furniture tidak pernah boleh ditempatkan pada door tile, protected entrance corridor, queue lane, stair/portal tile, cashier service tile, supply drop-off tile, atau critical access aisle.

## **83.2 Customer/Driver Admission**

NPC customer dan RotiFood Driver **tidak divisualisasikan di luar toko**.

Flow:

```text
Demand Event
 -> PendingArrivalData (data only, no actor/node)
 -> check valid interior queue/admission capacity
 -> if capacity available: instantiate/reuse pooled NPC exactly at interior side of front door
 -> ENTERING
 -> browse/queue/service
 -> EXITING
 -> reach interior side of front door
 -> return actor to pool immediately
```

- Pending arrival yang belum mendapat slot hanya berupa data; tidak ada crowd off-screen.
- Model NPC muncul **sesaat setelah melewati threshold pintu**, sehingga secara visual tampak masuk dari pintu depan.
- Model NPC dibersihkan ketika mencapai threshold pintu saat keluar; tidak perlu actor berjalan di luar bangunan.
- Maximum pending delay mengikuti Seksi 67: physical customer 30 simulation-seconds, RotiFood Driver 40 simulation-seconds.
- Supply courier menggunakan priority transit dan tidak membutuhkan queue capacity customer.

## **83.3 Actor Collision Contract**

Free-walking actor tidak melakukan body blocking satu sama lain. Exclusive reservation hanya berlaku untuk:

- cashier queue slot;
- RotiFood queue slot;
- equipment interaction tile;
- display browsing interaction tile saat sedang mengambil produk;
- supply drop-off point selama commit animation;
- staff/player service point yang secara eksplisit single-user.

Actor yang gagal memperoleh exclusive point menunggu pada logical wait state tanpa menumpuk pada point tersebut.

---

# **84. Customer Purchase Quantity, Browsing, dan Cashier Lane**

## **84.1 Canonical Quantity Ranges**

Quantity ditentukan ketika target recipe terpilih dan selalu dibatasi oleh stock sellable, budget, dan archetype range.

| Archetype | Preferred Quantity | Hard Range | Catatan |
| :--- | :---: | :---: | :--- |
| School Child | 1 | **1–2** | Budget-sensitive; jarang membeli 2 jika harga > reference. |
| Office Worker | 2 | **1–3** | Cepat; memilih produk praktis dan tidak browsing lama. |
| Generic Regular | 2 | **1–4** | Baseline customer. |
| Bulk Buyer / Arisan | 8 | **5–15** | Jika stock kurang, menerima partial quantity minimal 3; jika <3, coba substitusi. |
| Socialite / Snob | 3 | **2–5** | Hanya Good/Fresh premium-quality products. |
| Indecisive | 2 | **1–3** | Quantity normal, service time 2×. |
| Food Vlogger / Critic | 2 | **1–3** | Memprioritaskan quality tertinggi. |

Weighted quantity sampling:

```text
weight(preferred) = 0.50
weight(preferred - 1) = 0.20, if valid
weight(preferred + 1) = 0.20, if valid
remaining valid quantities share 0.10
```

Bulk Buyer menggunakan triangular distribution berpusat pada 8 dengan clamp 5–15.

## **84.2 Product Target Selection**

Customer **mengetahui stock summary toko secara logical**, tetapi tetap harus berjalan ke display slot fisik yang menyimpan recipe pilihannya.

Pipeline final:

1. Query seluruh `SELLABLE` display stacks.
2. Filter minimum bake quality/freshness menurut archetype.
3. Hitung preference weight recipe/tag.
4. Terapkan price acceptance multiplier.
5. Pilih recipe target.
6. Pilih **nearest reachable display slot** yang menyimpan recipe tersebut dan memiliki quantity >0.
7. Reserve hanya **browsing interaction point**, bukan unit stock.
8. Berjalan ke display.
9. Saat tiba, revalidate stock secara atomik.
10. Jika cukup, ambil quantity.
11. Jika berkurang/habis, jalankan substitution pipeline sekali lagi terhadap seluruh stock terbaru.
12. Jika tidak ada alternatif sellable, keluar melalui pintu tanpa masuk cashier queue.

Customer tidak pernah mengambil produk dari “global inventory” tanpa mendatangi rak.

## **84.3 Substitution**

Alternative score:

```text
alternative_score =
    preference_similarity * 0.45
  + price_acceptance       * 0.25
  + freshness_score        * 0.20
  + distance_score         * 0.10
```

Semua komponen dinormalisasi ke `0..1`:
- `preference_similarity` bernilai 0..1.
- `price_acceptance = clamp(effective_price_demand / 1.25, 0, 1)` (Seksi 63.2).
- Komponen freshness memakai `freshness_score / 100` (Seksi 19.7.1).
- `distance_score` bernilai 0..1, dengan 1 = slot terdekat.

Pilih score tertinggi yang memenuhi hard restrictions archetype. Jika semua invalid/stock 0, state -> `LEAVING_NO_PURCHASE`.

## **84.4 Cashier Lane Selection**

Customer memilih lane dengan **estimated total wait time** minimum, di antara lane terbuka yang masih memiliki slot kosong (Seksi 57.6):

```text
estimated_wait(lane) =
    remaining_time_current_transaction
  + sum(expected_service_time(each queued customer, cashier))
  + walking_time_to_lane_tail
```

Tie-breaker berurutan:

1. queue length lebih pendek;
2. jarak lebih dekat;
3. `lane_id` lebih kecil untuk deterministic result.

Customer tidak berpindah lane setelah berhasil reserve slot, untuk mencegah lane-hopping visual.

## **84.5 Price Reaction Label**

Rumus harga, batas slider, dan demand hanya ada di Seksi 63.2. Seksi ini memetakan multiplier menjadi label reaksi untuk UI:
- Emoji pada slider harga memakai `price_demand` baseline.
- Thought bubble tiap customer memakai `effective_price_demand` archetype-nya.

| Multiplier | Label |
| :---: | :--- |
| >= 1.20 | VERY_HAPPY |
| 1.05 – <1.20 | HAPPY |
| 0.95 – <1.05 | NEUTRAL |
| 0.70 – <0.95 | UNHAPPY |
| 0.40 – <0.70 | VERY_UNHAPPY |
| < 0.40 | REFUSE (sebagian besar menolak) |

Label tidak mengubah angka gameplay.

---

# **85. Display Rack Canonical Specification**

Semua Display Rack **universal**: setiap slot dapat menyimpan **recipe apa pun tanpa pengecualian** selama item berstatus sellable.

| Display Tier | Total Capacity | Visual Product Slots | Max per Slot | Preservation Modifier |
| :--- | ---: | ---: | ---: | ---: |
| `display_t1` | 50 | **4** | 13 (global cap tetap 50) | 1.00× aging |
| `display_t2` | 100 | **6** | 17 (global cap 100) | 0.90× aging |
| `display_t3` | 200 | **8** | 25 | 0.80× aging |
| `display_t4` | 350 | **10** | 35 | 0.70× aging |
| `display_t5` | 600 | **12** | 50 | 0.60× aging |

Rules:

- Satu slot menyimpan satu recipe ID pada satu waktu, tetapi dapat berisi beberapa freshness/quality stack internal dari recipe yang sama.
- Recipe yang sama boleh menempati beberapa slot.
- Slot kosong tidak memiliki jenis recipe tetap.
- Player memilih target slot setelah membawa tray ke display.
- Jika recipe yang sama sudah ada, UI menyorot slot existing terlebih dahulu, tetapi player boleh memilih slot kosong lain.
- Jika target slot tidak cukup menampung seluruh tray, UI menawarkan slot valid lain; partial split otomatis diperbolehkan **hanya jika** ada slot kedua yang valid dan total display capacity cukup.
- Pengambilan customer menggunakan FIFO stack tertua yang masih sellable.
- `BURNT` dan `UNSALEABLE` tidak dapat ditempatkan.

Visual compartment harus secara prosedural menunjukkan kelompok produk tanpa membuat satu node per bread unit.

---

# **86. Final Utility Economics**

Utility dihitung hanya berdasarkan **simulation time aktif**. Pause tidak menambah utility.

```text
utility_charge = active_ingame_hours * utility_rate_kr_per_ingame_hour
```

Charge diakumulasi dengan precision float selama hari, kemudian dibulatkan **nearest 1 KR** saat Daily Summary.

## **86.1 Mixer Utility**

| Tier | KR / active in-game hour |
| :--- | ---: |
| `mixer_t1` | **0** |
| `mixer_t2` | **4** |
| `mixer_t3` | **7** |
| `mixer_t4` | **12** |
| `mixer_t5` | **20** |

## **86.2 Oven Utility**

| Tier | KR / active in-game hour |
| :--- | ---: |
| `oven_t1` | **6** |
| `oven_t2` | **10** |
| `oven_t3` | **18** |
| `oven_t4` | **32** |
| `oven_t5` | **55** |

Oven tetap dianggap active selama baking **dan burn waiting state sampai tray diambil**, karena panas masih dipertahankan.

## **86.3 Display Utility**

| Tier | KR / in-game hour while powered |
| :--- | ---: |
| `display_t1` | **0** |
| `display_t2` | **0** |
| `display_t3` | **5** |
| `display_t4` | **8** |
| `display_t5` | **12** |

Powered display T3–T5 aktif dari 05:00–18:00 dan otomatis off setelah closing. Freshness overnight memakai storage/display preservation rule yang sudah ditetapkan, bukan utility real-time malam hari.

Utility rate adalah **TUNABLE balance data**, tetapi formula dan active-state definition canonical.

---

# **87. Staff Canonical Employment Rules**

## **87.1 Candidate Availability**

Roster pada Seksi 3.5 adalah **fixed canonical roster**.

- Kandidat yang sama selalu tersedia pada Staff Management.
- Tidak ada RNG recruitment pool, refresh harian, rarity, reroll, recruitment fee, atau candidate expiration.
- Kandidat yang sedang dipekerjakan ditandai `EMPLOYED` dan tidak dapat direkrut dua kali.
- Kandidat yang dipecat kembali tersedia mulai menu Staff Management berikutnya.
- Tier staff tidak naik melalui XP; untuk kemampuan lebih tinggi player harus merekrut kandidat tier lebih tinggi.

## **87.2 Work Schedule**

- Staff `on_duty=true` spawn/aktif otomatis pada **05:00**.
- Cashier mengambil service position menjelang 08:00 dan melayani otomatis selama Open phase.
- Baker mulai bekerja sejak Preparation 05:00 mengikuti mode automation.
- Pada 18:00 staff menyelesaikan atomic handoff yang sedang committed, lalu berhenti mengambil task baru dan despawn/idle after-hours.
- Tidak ada shift editor atau jam kerja individual.

## **87.3 Wage Liability**

Pada 05:00 sistem membuat `DailyWageLiability` immutable untuk seluruh staff `on_duty=true`.

```text
wage_due_today = sum(daily_salary of staff on duty at 05:00)
```

- Off-duty sebelum 05:00 -> tidak ada wage hari itu.
- Diliburkan/dipecat setelah 05:00 -> wage hari itu tetap penuh.
- Hire after-hours -> mulai duty 05:00 berikutnya; tidak membayar wage pada hari hire.
- Tidak ada partial wage/refund.

Ini mencegah exploit menggunakan staff sebagian hari lalu meliburkan sebelum settlement.

---

# **88. Tutorial Day 1–3 — Canonical Event Timeline**

Semua player-facing tutorial text berikut ditampilkan dalam **English**. Tutorial menggunakan contextual highlight; game pause ketika tutorial modal aktif.

## **88.1 Day 1 — Production + Manual Cashier**

1. 05:00 intro: `"Welcome to your bakery. Let's bake your first loaf."`
2. Highlight Storage; input world lain tetap disabled sampai Storage dipilih.
3. Recipe Book: highlight Plain White Loaf (`recipe_plain_loaf`) x1, jelaskan ingredients dan batch yield.
4. Setelah confirm, highlight Mixer.
5. Saat mixing berjalan, tooltip menjelaskan progress bar dan bahwa equipment bekerja sendiri.
6. Mixer complete: highlight Mixer lagi untuk pickup.
7. Highlight Oven; setelah insert, tutorial menjelaskan burn risk.
8. Oven complete: pause sekali dan jelaskan `"Take it out before it burns."`
9. Highlight Display and Slot Picker.
10. Ulangi guidance ringan sampai scripted Day-1 stock target dapat dipenuhi; jangan memaksa satu command sequence jika player sudah memahami flow.
11. 08:00 open tutorial: customer enters; explain product selection and patience bar.
12. First customer reaches cashier: highlight counter and manual service.
13. First successful payment: explain KR income.
14. First RotiFood order: explain tablet, packing, and driver pickup.
15. 18:00 Daily Summary: explain revenue, cost, utility, waste, rating.
16. Trigger (berlaku Hari 1–3, biasanya terjadi sore Hari 1): saat stack pertama masuk `GOOD`, explain freshness indicator and leftover consequence.

## **88.2 Day 2 — Pressure, Queue, Pricing**

1. Preparation reminder singkat; tidak mengulang tutorial dasar.
2. First Office Worker: explain lower patience.
3. First 2+ customer queue: explain queue capacity and why cashier attention matters.
4. Open pricing control tutorial saat Recipe/Price screen pertama dibuka; explain reference price and demand response.
5. First near-burn event triggers Smart Speed/alert explanation bila belum pernah terjadi.
6. Bila seluruh bahan Hari 2 sudah dipanggang sebelum 08:00, tampilkan hint sekali: `"Fried bread goes stale quickly. Keep some batches for the afternoon."` (umur simpan pendek `recipe_plain_fried_bread`, Seksi 61.3).

## **88.3 Day 3 — Online Orders + Planning**

1. Explain balancing physical stock vs RotiFood because online orders do **not** reserve stock.
2. At Daily Summary, introduce that Market becomes available freely starting Day 4.
3. Show non-blocking teaser: `"From tomorrow, you can order ingredients at any time. Daytime deliveries take 3 in-game hours."`

Tutorial step state disimpan agar save/load tidak mengulang reward/critical commit. Setiap blocking step memiliki recovery condition: bila expected object/state sudah tercapai sebelum prompt, step auto-complete dan lanjut.

---

# **89. Boot, Main Menu, New Game, dan Save Profiles**

## **89.1 Boot / Loading Flow**

```text
APP_START
 -> BootScene
 -> validate ProjectSettings + renderer
 -> load lightweight core config
 -> initialize logging/crash guard
 -> initialize localization (English)
 -> initialize canonical data registry
 -> load shared procedural cache manifest
 -> discover 3 save profile headers only
 -> Main Menu
```

Main Menu harus dapat muncul tanpa men-generate seluruh world/character mesh.

## **89.2 Main Menu**

Player-visible English buttons:

```text
Continue
New Game
Load Game
Settings
Credits
Quit   (desktop/web policy permitting)
```

- `Continue` memuat profile dengan `last_played_at` terbaru; disabled jika semua profile kosong.
- `Load Game` membuka 3 profile cards.
- `New Game` membuka profile selection; occupied profile membutuhkan confirmation sebelum overwrite.
- Web build boleh menyembunyikan `Quit` jika platform tidak mendukung close action.

## **89.3 Three Save Profiles**

Exactly three independent profiles:

```text
profile_1
profile_2
profile_3
```

Card menampilkan:

- Bakery Name
- Day
- Location Tier
- KR balance
- Last Played
- small procedural bakery icon

Setiap profile punya main save + one backup generation.

## **89.4 New Game Flow**

```text
Select Empty/Overwrite Profile
 -> Player Appearance (Male / Female + cosmetic choices)
 -> Bakery Name
 -> Confirmation Summary
 -> initialize deterministic master seed
 -> create Day 1 save (1000 KR)
 -> Intro Cutscene
 -> Day 1 Tutorial
```

### Bakery Name Rules

- Default: **Roti Lezat**.
- User may edit.
- 1–24 visible characters after trim.
- Unicode allowed.
- Reject control characters/newlines.
- Profanity filtering is not required for offline single-player; OS/platform policy may be applied if required by store.
- Name appears on storefront sign, RotiFood shop header, Daily Summary, save card, records, and selected achievement presentation.

## **89.5 Load World Without Blocking**

Setelah memilih profile:

1. Read + schema-validate save asynchronously where platform permits.
2. If main invalid, validate backup.
3. Preload only data/resources required by active location tier.
4. Build/reuse shared procedural meshes/materials from cache.
5. Construct active floor first.
6. Restore logical simulation state (clock, jobs, inventory, actors, queues).
7. Construct inactive floor simulation proxies (if multi-floor) without full render.
8. Reconstruct visible actors from logical state using pools.
9. Run one `post_load_integrity_check`.
10. Fade loading overlay only after first stable frame.

Loading overlay shows English stage text such as `"Preparing the bakery..."`; progress is coarse stage progress, not fake byte percentage.

### Failure Handling

- Missing optional cosmetic cache -> regenerate.
- Corrupt main save -> auto-attempt backup and notify user.
- Both invalid -> do **not** overwrite automatically; show `"Save data could not be loaded."` and offer Back / Start New Game in that profile only after confirmation.
- Missing canonical ID migration -> fail profile load safely and log exact ID.
- Procedural generation exception -> fallback to simplest primitive representation for non-critical cosmetic object; critical gameplay collider/data must still validate.

---

# **90. App / Browser Lifecycle and Pause Contract**

## **90.1 Android**

When app loses focus, enters background, receives pause notification, screen lock, app switch, or OS interruption:

1. push `LIFECYCLE_PAUSE` to pause stack immediately;
2. freeze simulation before processing another gameplay tick;
3. perform priority autosave;
4. mute/pause active audio buses appropriately.

On return:

- Do not apply elapsed real-world time.
- Show `"Game Paused"` overlay.
- Player explicitly presses Resume.

## **90.2 Web Browser**

On tab/window visibility loss or focus loss:

- same `LIFECYCLE_PAUSE` behavior;
- no offline time progression;
- best-effort save according to browser storage capability;
- on focus return remain paused until Resume.

No bread may burn, customer lose patience, order expire, utility accumulate, or delivery ETA advance while app/tab is inactive.

---

# **91. Procedural Cache, Object Pooling, dan RNG Streams**

## **91.1 Shared Procedural Asset Cache**

Procedural generation must be deterministic by parameter key.

```text
MeshCacheKey = object_type + tier + variant_parameters
MaterialCacheKey = palette + material_role + tier
```

Identical furniture/character part parameters reuse shared mesh/material resources. Do not regenerate geometry per instance.

Cache policy:

- lazy-generate on first use;
- retain commonly reused gameplay meshes for session;
- release tier/location-specific large cosmetic caches on location change if memory threshold exceeded;
- cache is reproducible and never authoritative save data.

## **91.2 Object Pools**

Mandatory pools:

- physical customer actors;
- RotiFood driver actors;
- supply courier actors;
- patience/status overhead widgets;
- order bubbles;
- coin/revenue popups;
- common CPUParticles2D/3D emitters;
- transient alert icons.

Pool object reset must clear signals, reservations, carried items, timers, animation state, archetype data, and visibility before reuse.

Pool may expand up to active actor budget but shrinks only during safe transition/loading, not every frame.

## **91.3 Deterministic RNG Streams**

Master seed dibuat saat New Game. Nama, pemakaian, dan kontrak stream ada di **Seksi 116** (satu-satunya daftar); pemiliknya `RNGManager` (Seksi 98).

Setiap stream state disimpan bila dapat memengaruhi future gameplay. Cosmetic/audio stream **tidak boleh** mengubah sequence demand/weather/customer choice.

---

# **92. Achievements, Lifetime Statistics, Records, dan Recipe Analytics**

## **92.1 Achievement Rewards**

Achievement **tidak pernah memberikan KR, ingredients, wage discount, demand multiplier, atau statistical gameplay advantage**.

Allowed rewards:

- badge;
- apron pattern;
- hat/hair accessory;
- storefront sign style;
- display trim skin;
- delivery counter skin;
- decorative prop;
- UI frame/theme cosmetic;
- trophy entry.

Reward cosmetics tidak mengubah collider/footprint/interaction properties.

## **92.2 Lifetime Statistics Panel**

Menu English: **Statistics**.

Track at minimum:

```text
days_played
total_play_time_real_seconds
total_kr_earned
total_kr_spent
highest_balance
total_bread_produced
total_bread_sold
total_bread_wasted
total_bread_burned
total_customers_served
total_customers_left_no_purchase
total_customers_lost_patience
total_rotifood_orders_received
total_rotifood_orders_completed
total_rotifood_orders_expired
total_supply_orders
bailout_count
staff_hired_count
location_upgrades_count
```

## **92.3 Personal Records**

Track:

- Highest Daily Revenue
- Highest Daily Net Profit
- Most Bread Sold in One Day
- Most Customers Served in One Day
- Most RotiFood Orders Completed in One Day
- Longest No-Burn Streak (days)
- Highest Physical Rating Reached
- Highest RotiFood Rating Reached
- Largest Single Customer Transaction
- Highest Concurrent Queue Occupancy
- Fastest Day to Reach each Location Tier (day index)

No global leaderboard/network requirement.

## **92.4 Recipe Analytics**

Setiap canonical recipe memiliki lifetime analytics:

```text
batches_started
batches_completed
units_produced
units_sold_physical
units_sold_rotifood
units_wasted_burnt
units_wasted_expired
gross_revenue_kr
ingredient_cost_attributed_kr
average_selling_price_kr
estimated_gross_margin_kr
```

Recipe Book tab **Analytics** baru terbuka untuk recipe setelah minimal **1 completed batch**.

Display English:

```text
Produced
Sold
Wasted
Revenue
Average Selling Price
Estimated Gross Margin
```

Formula:

```text
sold_units = units_sold_physical + units_sold_rotifood
average_selling_price = gross_revenue / sold_units, if sold_units > 0
estimated_gross_margin = gross_revenue - ingredient_cost_attributed_to_sold_and_wasted_output
```

Analytics bersifat informasional; tidak mengubah simulation.

---

# **93. Updated Audio Event Production List**

Semua audio dibuat/di-generate sesuai kebijakan aset proyek. AI audio implementor menggunakan event ID stabil berikut dan tidak memicu file berdasarkan nama display.

| Event ID | Deskripsi / Karakter Suara |
| :--- | :--- |
| `ui_tap_soft` | soft doughy click, short, warm, no sharp high frequency |
| `ui_confirm` | gentle wooden click + tiny bell accent |
| `ui_cancel` | muted paper tap |
| `ui_error` | soft two-note downward cue / muted wooden tok, non-alarming |
| `ui_pause` | tiny cloth/muffle transition |
| `door_bell_enter` | cozy small shop door bell, short mechanical brass |
| `door_bell_exit` | lighter variant of entrance bell |
| `footstep_tile` | soft indoor shoe step; randomized pitch ±3% |
| `storage_open` | refrigerator/wood cabinet open blend, soft hinge + latch |
| `storage_close` | soft cabinet close |
| `mixer_start` | tier-dependent mechanical start |
| `mixer_loop` | low-volume loop: T1 whisk in bowl with soft rhythmic scrape; T2+ low, non-harsh electric motor hum |
| `mixer_done` | short warm mechanical ding |
| `oven_open` | old-metal/modern-door tier variant |
| `oven_close` | damped metal close + tray slide |
| `oven_loop` | subtle heat/fan loop, tier dependent |
| `oven_done` | clear vintage timer `ting!`, P0 gameplay cue |
| `oven_burn_warning` | subtle faster double-tick + light smoke hiss, urgency without harsh alarm |
| `bread_burnt` | muffled poof/hiss, comedic and not alarming |
| `bread_place_display` | tray/wood/glass contact + soft rustle |
| `customer_pick_bread` | soft paper/crumb pickup rustle |
| `customer_happy` | very short positive non-verbal chirp/chime |
| `customer_impatient` | soft sigh/tap, rate-limited |
| `customer_leave_angry` | disappointed sigh + descending woodblock, not comedic yelling |
| `cashier_pack` | paper bag fold/rustle |
| `cashier_coin` | 2–4 warm coin clinks, randomized |
| `sale_success` | compact register click-ding + tiny sparkle |
| `rotifood_incoming` | distinctive three-note digital-but-warm tablet chime |
| `rotifood_pack_done` | paper bag seal sound |
| `rotifood_driver_arrive` | subtle helmet/bag + door bell, no vehicle engine inside shop |
| `rotifood_handover` | bag handoff rustle + positive confirmation ping |
| `rotifood_expired` | soft tablet cancellation tone |
| `supply_order_placed` | stamp/paper receipt + confirm chime |
| `supply_courier_arrive` | door bell + cardboard handling, subdued |
| `supply_package_drop` | soft cardboard box set down on counter |
| `supply_committed` | inventory sparkle/chime |
| `stairs_floor_switch` | very short whoosh used with crossfade, not literal stair footsteps |
| `achievement_unlock` | short uplifting xylophone/bell flourish, 2–3 s |
| `location_upgrade` | larger cozy success sting, bell arpeggio + sparkle |
| `bailout_scene` | gentle supportive musical cue |
| `rain_loop` | soft rain on awning/window, seamless loop |
| `sunny_ambience` | distant scooters, birds, light wind through the storefront |
| `shop_ambience_room` | interior room tone, subtle clock, distant street |
| `menu_music` | calm warm loop in the same bossa/lo-fi palette |
| `shop_music_morning` | 05:00–08:00: gentle morning guitar + brushed percussion, hopeful |
| `shop_music_day` | warm acoustic bossa/lo-fi, nylon guitar, soft Rhodes, 80–95 BPM, unobtrusive loop |
| `shop_music_busy_layer` | extra layer over `shop_music_day` when the store is busy; no aggressive tempo increase |
| `shop_music_rain` | softer chords, muted percussion, cozy indoor feeling |
| `shop_music_after_hours` | slower, quieter arrangement for Daily Summary and after hours |

Mixing priority: `oven_done`, burn warning, critical UI, and RotiFood incoming duck ambience/music slightly; repeated footsteps/customer vocalizations must use concurrency limits.

---

# **94. Long-Session Stability Acceptance Tests**

Selain acceptance test sebelumnya, build tidak dianggap production-ready sampai lulus:

1. **100-day simulation soak:** tidak ada node count growth setelah population stabil; memory returns near baseline after location transitions.
2. **500-day headless economy soak:** no NaN/INF before legitimate float64 overflow guard; ledger remains reconcilable.
3. **1,000-day save-cycle soak:** repeated save/load every day does not grow save size linearly from stale transient data.
4. Pool stress: 10,000 customer spawn/despawn cycles tidak meninggalkan signal duplicate, reservation, carried item, atau visible orphan.
5. Multi-floor soak: 5,000 floor switches tidak menggandakan actors/equipment nodes.
6. Queue invariant stress: exclusive slot occupancy never exceeds 1 under 3× speed.
7. Production invariant: every ingredient deduction maps to exactly one job or rollback; no duplication after crash/reload checkpoints.
8. RotiFood atomicity: customer physical purchase racing with packing cannot sell same unit twice.
9. Supply commit idempotency: repeated load around courier drop-off never applies ingredients twice.
10. Lifecycle: background/focus loss at every production state freezes simulation and resumes without elapsed-time jump.
11. RNG determinism: same save + same player inputs produces same next weather/arrival sequence regardless of cosmetic/audio RNG calls.
12. Profile isolation: actions/save corruption in profile 1 cannot mutate profile 2/3.
13. Procedural cache: repeated same-key requests return shared resource and do not create unbounded duplicate meshes/materials.
14. English UI overflow: all mandatory screens pass compact landscape breakpoint at 100% and 125% text scale.

Debug builds expose counters for active nodes, pooled/free objects, reservations, signal connections, jobs, and memory estimate.

---

# **96. v3.1 FINAL ENGINE & IMPLEMENTATION LOCK**

Bagian 96–135 adalah **hard implementation contract** untuk build v1.0. Seluruh section aktif harus konsisten satu sama lain. Nilai `TUNABLE` hanya boleh diubah melalui canonical data catalog tanpa mengubah mekanik, invariant, atau ownership sistem.

## **96.1 Exact Engine Lock**

| Item | Canonical Rule |
| :--- | :--- |
| Engine | **Godot Engine 4.7-stable Standard** |
| Programming Language | **GDScript only** |
| Renderer | **Compatibility** |
| Primary Targets | Web Browser / itch.io and Android / Google Play Store |
| C#/.NET | **Forbidden** |
| GDExtension/native plugin | **Forbidden unless a future GDD revision explicitly approves it** |
| Third-party Godot addons | **Forbidden by default** |
| API Reference | Godot **4.7** documentation only |

AI implementor **must not** use APIs introduced after Godot 4.7, even if its own training/runtime knows newer Godot versions. The project must open without migration prompts in Godot 4.7-stable.

GDScript rules:
- Use static typing wherever practical (`var count: int`, typed parameters, typed return values).
- Prefer `StringName` for canonical IDs and frequently compared event/action identifiers.
- Prefer `Resource` definitions for immutable/tunable gameplay data.
- Avoid dynamic property lookup unless required for generic serialization.
- No C# scripts, mixed-language gameplay systems, native DLL/SO, or external runtime dependencies.

---

# **97. Coding Standard & Source Organization**

## **97.1 Naming Convention**

| Element | Convention | Example |
| :--- | :--- | :--- |
| Files | `snake_case` | `customer_manager.gd` |
| Folders | `snake_case` | `gameplay/customers/` |
| Classes / `class_name` | `PascalCase` | `CustomerManager` |
| Functions | `snake_case()` | `request_purchase()` |
| Variables | `snake_case` | `active_customer_count` |
| Constants | `UPPER_SNAKE_CASE` | `MAX_QUEUE_DELAY_SECONDS` |
| Signals | past/event semantic | `order_completed`, `inventory_changed` |
| Canonical IDs | lowercase `snake_case` (Section 78) | `recipe_plain_loaf` |
| Input actions | lowercase `snake_case` | `game_speed_2` |

## **97.2 Mandatory Engineering Rules**

1. One script has one primary responsibility.
2. No circular dependency between gameplay managers.
3. UI is never authoritative gameplay state.
4. No hard-coded absolute node paths for cross-system communication.
5. No gameplay balance value may be duplicated across multiple scripts.
6. No unexplained magic numbers in gameplay code. Use constants or data Resources.
7. Canonical catalog data is loaded through a central registry and validated at boot.
8. Prefer signals/events for outward notification; prefer explicit method calls/commands for state mutation.
9. Avoid per-frame allocation in hot paths.
10. Avoid `get_nodes_in_group()` or tree-wide searches every frame; cache references.
11. Required features may not be left as `pass`, TODO, placeholder, mocked behavior, or commented-out production logic.
12. No code is considered complete until its relevant acceptance tests pass.

Soft maintainability target: scripts should generally stay below ~500 lines. A larger script is allowed only when splitting it would make ownership less clear; data catalogs and generated test fixtures are exempt.

---

# **98. Single Source of Truth — State Ownership Matrix**

**Invariant:** every mutable gameplay state has exactly one authority. Other systems may observe it or request a mutation but must not maintain competing copies.

| State | Sole Authority | Consumers |
| :--- | :--- | :--- |
| Simulation clock/day/phase/game speed | `TimeManager` | all gameplay systems |
| Pause reasons | `PauseManager` | TimeManager, UI, lifecycle bridge |
| KR balance and ledger | `EconomyManager` | HUD, market, payroll, analytics |
| Ingredients/storage contents | `InventoryManager` | production, market, UI |
| Bread/display stock | `DisplayInventoryManager` | customers, RotiFood, UI |
| Production jobs | `ProductionManager` | equipment, staff, HUD |
| Equipment states | `EquipmentManager` | production, visuals, save |
| Customer logical lifecycle | `CustomerManager` | navigation, cashier, UI |
| Physical queue occupancy | `QueueManager` | customer, cashier |
| Cashier lanes/transactions | `CashierManager` | customer, staff, economy |
| RotiFood orders | `RotiFoodManager` | packing, driver, reputation |
| Supply purchase orders | `SupplyOrderManager` | market, courier, inventory |
| Staff employment/duty | `StaffManager` | production/cashier automation |
| Ratings/reputation | `ReputationManager` | demand, UI |
| Weather | `WeatherManager` | demand, visuals/audio |
| Demand scheduling | `DemandManager` | customer/RotiFood managers |
| Active location/floor/layout | `WorldManager` | navigation/camera |
| Camera active floor | `CameraManager` | rendering/UI only |
| Achievements | `AchievementManager` | cosmetics/UI |
| Lifetime statistics/records | `StatisticsManager` | analytics/UI |
| Per-recipe analytics | `AnalyticsManager` | Recipe Book/summary UI |
| Save serialization | `SaveManager` | reads all authorities, owns no gameplay state |
| Settings | `SettingsManager` | audio/video/input/UI |
| RNG stream states | `RNGManager` | demand, weather, customers, RotiFood, staff, marketing, cosmetics, audio |

`SaveManager` must reconstruct authoritative systems during load; it must never become a parallel runtime database.

---

# **99. Canonical Units, Numeric Types & Rounding**

## **99.1 Unit Convention**

| Concept | Canonical Unit |
| :--- | :--- |
| World distance | meters |
| Placement/navigation grid | tile |
| One tile | **0.5 m × 0.5 m** |
| Movement speed | meters / real second at 1× simulation speed |
| Simulation duration (mixing, baking, burn, patience, pending delay, service time) | simulation-seconds: 1 simulation-second = 1 real second at 1× speed (= 20 seconds of in-game clock) |
| Clock time | in-game seconds since 00:00 (e.g. `time_seconds = 28800` = 08:00); 1 in-game hour = 180 simulation-seconds |
| UI animation duration | real seconds, unaffected by game speed unless specified |
| Money | KR, internal `float`/64-bit floating point semantics |
| Probability | normalized `0.0..1.0` |
| Store/RotiFood rating | `1.0..5.0` |
| Angles | degrees |
| Capacity | integer units |

Godot GDScript `float` uses double-precision semantics in this design contract. Integer counts (bread, ingredient units, customers, queue slots) must remain integers.

## **99.2 Money & Rounding**

- Canonical gameplay prices are whole KR unless a formula temporarily produces a fraction.
- Final transaction unit price: round to nearest whole KR using **half-up** semantic (`x.5` rounds away from zero for positive prices).
- Quantity × rounded unit price determines merchandise subtotal.
- Percent tips are calculated from subtotal and then rounded half-up to whole KR.
- Internal balance remains floating point to support endless magnitude, but normal transactions commit whole-KR amounts.
- HUD uses integer formatting below `1e12`, compact suffix/scientific notation at `>= 1e12`.
- NaN is never valid. `+INF` may only be reached through the intentional endless-economy overflow guard and triggers the canonical overflow state already defined.
- Store/RotiFood ratings store at least 2 decimal precision internally and display 1 decimal.

---

# **100. Canonical InputMap & Command Layer**

All platforms feed the same command layer. Gameplay scripts must not implement platform-specific mouse/touch logic independently.

Required Godot InputMap actions:

| Action ID | Desktop Default | Mobile |
| :--- | :--- | :--- |
| `interact_primary` | Left click | single tap |
| `cancel_back` | Esc / right click | back button / UI back |
| `pause_toggle` | Esc / P | pause UI button |
| `camera_pan` | middle drag / edge-independent drag | one-finger drag on empty world |
| `camera_zoom_in` | wheel up / `+` | pinch out |
| `camera_zoom_out` | wheel down / `-` | pinch in |
| `game_speed_1` | `1` | HUD 1× button |
| `game_speed_2` | `2` | HUD 2× button |
| `game_speed_3` | `3` | HUD 3× button |
| `floor_alert_focus` | `F` | tap off-floor alert |
| `ui_accept` | Enter/Space | tap focused control |
| `ui_cancel` | Esc | back |

Touch gestures must never bypass placement validation or task command validation. Input is converted to semantic commands before mutation.

---

# **101. Canonical Data Schema Contract**

Gameplay catalogs should be implemented as typed `Resource` definitions or equivalent typed data objects. Required schema fields below are authoritative minimums; additional derived/cache fields are allowed but may not alter meaning.

## **101.1 `RecipeDefinition`**

```text
id: StringName                    required, unique
localization_key: StringName      required
category_id: StringName           required
ingredients: Dictionary           required; ingredient_id -> integer amount
batch_yield: int                  > 0
required_mixer_tier: int          1..5
required_oven_tier: int           1..5
mix_duration_seconds: float       >= 0; base at required tier (Section 61.5 `mix`)
prep_duration_seconds: float      >= 0; base at required tier, runs inside MIXING (Section 61.5 `prep`)
bake_duration_seconds: float      > 0; base at required tier (Section 61.5 `bake`)
burn_grace_seconds: float         >= 0; may derive from oven tier at runtime
expired_duration_hours: float     > 0
base_sell_price_kr: float         > 0; per unit
required_station_ids: Array       must reference canonical equipment categories
customer_tags: Array[StringName]  Section 61.6
visual_profile_id: StringName     required
```

## **101.2 `IngredientDefinition`**

```text
id: StringName
localization_key: StringName
unit_label_key: StringName
fixed_buy_price_kr: float > 0
storage_units_per_purchase: int >= 1
category_id: StringName
```

## **101.3 `EquipmentDefinition`**

```text
id: StringName
category_id: StringName           mixer/oven/display/storage/counter/etc.
tier: int                         1..5
footprint_tiles: Vector2i
interaction_offsets: Array[Vector2i]
rotations_allowed: Array[int]     subset of 0,90,180,270
utility_cost_kr_per_ingame_hour: float >= 0
process_multiplier: float > 0     mixer/oven: T1 reference seconds / this tier's reference seconds (Section 5.1);
                                  stage ratio in Section 18.5 = process_multiplier[required] / process_multiplier[active];
                                  1.0 for categories without a process
capacity: int >= 0
visual_profile_id: StringName
```

## **101.4 `CustomerArchetypeDefinition`**

```text
id: StringName
base_patience_seconds: float > 0
purchase_quantity_distribution: weighted integer distribution
preferred_categories: weighted Array[StringName]
substitution_allowed: bool
price_sensitivity: float >= 0
quality_requirement: float 0..1
spawn_weight_by_time_block: Dictionary
movement_speed_mps: float > 0
max_unit_price_kr: float >= 0     0 = no cap (Section 20.11)
allowed_freshness_states: Array[StringName]
min_recipe_tier: int 1..5
```

## **101.5 `StaffDefinition`**

```text
id: StringName
role_id: StringName               cashier/baker
tier: int 1..5
daily_wage_kr: float > 0
work_speed_multiplier: float > 0
cashier_service_seconds: float >= 0
auto_retrieve_probability: float 0..1
visual_profile_id: StringName
```

## **101.6 `LocationDefinition`**

```text
id: StringName
tier: int 1..5
upgrade_cost_kr: float
floors: Array[FloorDefinition]
staff_capacity_by_role: Dictionary
queue_capacity_physical: int
queue_capacity_rotifood: int
protected_no_build_cells: Array
entrance_cell: Vector2i
exit_cell: Vector2i               same front-door transit in v1.0
```

## **101.7 Other Required Schemas**

Create typed definitions for `AchievementDefinition`, `AudioEventDefinition`, `DecorationDefinition`, `WeatherDefinition`, `MarketingCampaignDefinition`, and `QualityPresetDefinition`. Boot validation must reject duplicate IDs, missing references, invalid tiers, negative prices/capacities, invalid footprints, and recipe references to missing ingredients.

`DecorationDefinition` minimum fields: `id`, `localization_key`, `placement_type` (Section 72.1), `price_kr` (0 for achievement rewards), `source` (`shop` / `achievement`), `footprint_tiles` (only for `floor_prop`), `visual_profile_id`.

---

# **102. Deterministic Simulation Event Priority**

When multiple simulation events become due on the same simulation tick, process in this deterministic order:

1. **P0 — Lifecycle / save safety:** focus-loss pause request, load reconstruction barrier, stable-checkpoint barrier.
2. **P1 — Clock boundaries:** day rollover, 05:00 preparation start, 08:00 opening, 18:00 closing boundary.
3. **P2 — Production equipment:** mix complete, bake complete, burn threshold, auto-retrieve.
4. **P3 — Inventory commits:** production consume/rollback, display placement, supply delivery commit.
5. **P4 — Customer state:** pickup/revalidation, patience expiry, cashier transaction completion.
6. **P5 — RotiFood:** pack commit, driver handover, order expiry.
7. **P6 — Economy/reputation/statistics/analytics:** ledger, rating, records, achievements.
8. **P7 — UI/audio/cosmetic:** animation, particles, sound, toast, notification.

Within one priority bucket, use stable insertion sequence IDs. Never rely on node-tree iteration order for authoritative resolution.

---

# **103. Transaction Order & Atomicity**

## **103.1 Physical Sale**

1. Revalidate customer-held bread units and transaction eligibility.
2. Calculate subtotal from the per-unit price locked when the bread was taken from the rack (Section 63.2).
3. Commit cashier service completion.
4. Mark held bread as sold; it must never return to display after this point.
5. Calculate/round tip if applicable.
6. Commit Economy ledger transaction.
7. Update recipe analytics and lifetime statistics.
8. Apply reputation event.
9. Emit UI/audio/cosmetic events.

If steps 1–3 fail, no money/statistics mutation occurs. After step 4, all following authoritative bookkeeping must complete in the same simulation transaction or recover idempotently after load.

## **103.2 RotiFood Packing/Sale**

No stock is reserved at order arrival. Packing performs an atomic display-stock revalidation/removal. Handover commits revenue exactly once. An order ID carries an `economy_committed` flag in save reconstruction to prevent double payment.

## **103.3 Market Purchase**

1. Validate capacity including in-transit reservations.
2. Validate KR.
3. Deduct KR and create immutable purchase-order line items atomically.
4. Do not add ingredients to on-hand inventory until canonical delivery commit.
5. On after-hours purchase, commit directly to storage according to the canonical market-delivery rule.

---

# **104. 18:00 Canonical Shutdown Matrix**

At exactly 18:00, stop admitting new physical customers and new RotiFood orders before resolving the table below.

| State at 18:00 | Canonical Result |
| :--- | :--- |
| Customer still browsing | returns any held bread to original compatible display inventory, leaves without sale |
| Customer queued | returns held bread, leaves; no transaction |
| Cashier wrapping not yet committed | cancel service, return bread, no sale |
| Physical sale already committed | customer exits normally; sale remains |
| RotiFood order not packed | cancel without rating penalty (Section 22.9); no stock loss |
| RotiFood packed but not handed over | return packed bread atomically to compatible display stock, then close order without revenue |
| RotiFood handover already committed | revenue remains; driver despawns |
| Mixer currently processing | continues as production state into after-hours management pause only when simulation is resumed; closing UI pauses time |
| Oven currently baking | remains in exact timer state; Daily Summary/management menu pauses simulation so it cannot burn behind modal UI |
| Finished oven contents waiting | remains in oven state; resumes risk only when simulation resumes |
| Supply courier due at/after 18:00 | courier visual is skipped; purchase order auto-commits directly to storage |
| Supply courier already walking inside | complete commit immediately at closing boundary, then despawn; no blocking |
| Staff | duty day ends after required state cleanup; wage liability remains owed |

Daily Summary opens after deterministic shutdown cleanup and pauses simulation.

---

# **105. Location Upgrade Migration Contract**

Location upgrade is allowed only from a stable management state with simulation paused. Before purchase, run `can_migrate_location()`.

Migration order:
1. Freeze commands and create recovery snapshot.
2. Deduct upgrade KR only after validation succeeds.
3. Preserve all ingredient inventory.
4. Preserve all owned equipment and decorations that remain legal in the new location.
5. Preserve bread stacks/freshness exactly; migrate to available display capacity.
6. If new display capacity is insufficient, upgrade must be blocked with a clear UI explanation; no bread may be silently deleted.
7. Preserve hired staff and duty settings subject to larger capacity; upgrade never fires staff.
8. Preserve ratings, analytics, achievements, statistics, market purchase orders, and RNG states.
9. Pending physical arrivals are cleared because the store topology changes while paused; no penalty.
10. Active in-store customers/RotiFood must be zero before upgrade UI enables purchase.
11. Active production jobs must be complete/empty before equipment can migrate; otherwise purchase button remains disabled.
12. Furniture positions do **not** carry blindly across a different floor plan. Each item is placed using deterministic migration anchors; remaining movable items go to an `unplaced_owned_furniture` inventory for player placement.
13. Rebuild navigation/no-build masks and validate protected routes.
14. Save stable checkpoint before resuming.

No item, KR, ingredient, bread, or staff may duplicate during migration.

---

# **106. Save System — Concrete Schema & Golden Fixture**

There are exactly **3 save profiles**. Each has independent autosave and metadata. Save writes use temporary-file + validation + atomic replace semantics where platform allows. This section is the only definition of save paths and the save root shape (Sections 12.6, 34, and 77 refer here).

Canonical paths (`user://` maps to IndexedDB on Web and to app-private storage on Android):

```text
user://saves/profile_1.json          main save, profile 1
user://saves/profile_1.backup.json   previous generation (Section 34.4)
user://saves/profile_1.tmp           exists only during an atomic write
(same pattern for profile_2 and profile_3)
user://settings.json                 settings & accessibility, shared by all profiles
```

Minimum root shape:

```json
{
  "schema_version": 3,
  "game_version": "1.0.0",
  "catalog_versions": { "catalog_schema_version": 1, "content_version": 1 },
  "created_at": "2026-09-25T10:00:00Z",
  "last_played_at": "2026-09-25T11:30:00Z",
  "profile_id": "profile_1",
  "bakery_name": "Roti Lezat",
  "player": {},
  "day": 4,
  "time_seconds": 28800,
  "phase": "open",
  "location_id": "location_t1_garage",
  "active_floor_id": "floor_1",
  "economy": {
    "balance_kr": 2450.0,
    "ledger_sequence": 37
  },
  "inventory": {},
  "display_inventory": {},
  "production_jobs": [],
  "equipment_states": [],
  "customers": [],
  "queues": {},
  "rotifood_orders": [],
  "supply_orders": [],
  "staff": {},
  "ratings": {},
  "weather": {},
  "marketing": {},
  "tutorial": {},
  "flags": {
    "market_unlocked": true,
    "bailout_pending": false,
    "solo_mode": false,
    "economy_overflowed": false,
    "last_freshness_rollover_day": 3
  },
  "achievements": {},
  "statistics": {},
  "recipe_analytics": {},
  "rng_states": {
    "weather_rng": {},
    "customer_arrival_rng": {},
    "customer_choice_rng": {},
    "rotifood_rng": {},
    "staff_rng": {},
    "marketing_rng": {},
    "cosmetic_rng": {},
    "audio_rng": {}
  },
  "ui_restore": {
    "game_speed": 1,
    "camera_zoom": 1.0
  }
}
```

The actual project must include a version-controlled **golden save fixture** under `tests/fixtures/` that loads successfully and is used by migration/regression tests. Transient pooled-node IDs, cached mesh references, signal connections, UI animation progress, and ephemeral pathfinding routes must never be serialized.

Autosave is forbidden mid-transaction. `SaveManager` may write only after all authoritative systems report a **stable checkpoint**.

---

# **107. Test Harness & Required Test IDs**

Use a **custom lightweight headless GDScript test harness** contained in the repository. Do not require a third-party testing plugin. Tests must be runnable from command line/headless Godot 4.7.

Minimum suites:

```text
TEST_BOOT_001          catalog validation and clean boot
TEST_TIME_001          05:00/08:00/18:00 boundaries
TEST_TIME_002          pause and 1×/2×/3× determinism
TEST_PRODUCTION_001    ingredient -> mixer -> oven -> display happy path
TEST_PRODUCTION_002    burn thresholds per oven tier
TEST_PRODUCTION_003    stage duration formula (recipe base × equipment ratio × batch ÷ staff speed, prep inside MIXING)
TEST_FRESHNESS_001     cross-day freshness aging
TEST_INVENTORY_001     atomic consume/rollback
TEST_QUEUE_001         no overlap/exclusive queue slots
TEST_QUEUE_002         pending admission maximum delay
TEST_CUSTOMER_001      target display and substitution
TEST_CUSTOMER_002      purchase quantity distributions
TEST_CASHIER_001       estimated-wait lane choice
TEST_ROTIFOOD_001      no pre-reservation and atomic pack
TEST_MARKET_001        +3 in-game hour daytime delivery
TEST_MARKET_002        after-hours instant storage commit
TEST_STAFF_001         duty and wage liability
TEST_ECONOMY_001       price/rounding/ledger reconciliation
TEST_SAVE_001          roundtrip golden fixture
TEST_SAVE_002          crash-safe/idempotent transaction recovery
TEST_PROFILE_001       3-profile isolation
TEST_MULTIFLOOR_001    instant floor transition and inactive simulation
TEST_CAMERA_001        0.20s crossfade + active-floor rule
TEST_LIFECYCLE_001     app/browser focus-loss pause
TEST_RNG_001           separated deterministic streams
TEST_UPGRADE_001       location migration no-loss invariant
TEST_UI_001            English localization key completeness
TEST_LONGRUN_100       100-day soak
TEST_LONGRUN_500       500-day headless economy soak
TEST_LONGRUN_1000      1,000-day save-cycle soak
```

**Release gate:** all REQUIRED tests pass. AI may not delete, skip, weaken, or comment out a failing test merely to reach green status.

---

# **108. Build & Export Contract**

Required deliverables/presets:

1. **Web export** suitable for itch.io.
2. **Android debug APK** workflow.
3. **Android release AAB-ready** project/preset; signing secret is supplied externally by publisher and must not be hard-coded.

Release validation:
- No missing resource errors.
- No debug-only dependency required at runtime.
- Landscape orientation on Android.
- Touch interactions work without mouse emulation assumptions.
- Save survives application restart.
- Browser save works in supported persistent browser storage environment.
- First user interaction safely unlocks audio where browser policies require it.
- Web boot has no uncaught console errors.
- Compatibility renderer is used.
- Project exports from Godot 4.7-stable.

---

# **109. Target Hardware & Quality Presets**

## **109.1 Minimum Target Class**

**Android minimum design target**:
- Android 10 or newer.
- 4 GB RAM device class.
- OpenGL ES 3 capable GPU compatible with Godot Compatibility renderer.
- 1280×720-equivalent landscape render area or above.

**Web minimum design target**:
- Modern Chromium-family browser with WebGL 2 support.
- 4 GB system RAM class.
- Integrated GPU class capable of standard WebGL 2 workloads.

Performance targets:
- **Preferred:** stable 60 FPS.
- **Minimum acceptable under supported minimum hardware:** stable 30 FPS during normal gameplay.
- Simulation correctness must not depend on render FPS.

## **109.2 Quality Presets**

`Auto`, `Low`, `Medium`, `High`.

Only cosmetic/rendering features may change: shadow quality, particle counts, resolution scale, anti-aliasing, decorative density, off-floor visual update cadence. Gameplay simulation, spawn counts, pathfinding decisions, queue capacity, timers, economy, and AI behavior must remain identical.

`Auto` selects a conservative initial preset and may downgrade cosmetic quality on sustained performance pressure; it may never alter gameplay rules.

---

# **110. Resolution, Safe Area & UI Test Matrix**

Mandatory responsive layouts must pass at minimum:
- 16:9 — 1280×720, 1920×1080.
- 16:10 — 1280×800 / equivalent.
- 18:9.
- 19.5:9.
- 20:9 common Android landscape.
- Device cutout/safe-area inset handling.
- 100%, 125%, and accessibility enlarged text scale.

No mandatory button, timer, price, patience indicator, or modal confirmation may clip outside the safe area. World view may letterbox/adjust zoom; UI remains anchored to safe-area-aware containers.

---

# **111. Audio, Font & Asset-Origin Policy — FINAL**

## **111.1 Audio**

The project uses **no downloaded third-party audio packs, copyrighted songs, ripped sounds, or web-fetched audio assets**.

All shipped music/SFX/ambience must be:
1. generated procedurally/programmatically by project-owned generation scripts, or
2. newly created original audio whose project provenance is recorded.

Preferred autonomous-AI path: deterministic project tools generate required WAV/OGG assets from synthesis/noise/envelopes/sequencing definitions. Generated output may be cached and shipped, but source generation scripts/parameters must remain in repository so origin is reproducible.

Gameplay audio may never require network access.

## **111.2 Font**

Use Godot 4.7 built-in/default font resources for v1.0 unless a future revision explicitly approves a bundled font. Do not download a font automatically. Full player-facing language is English, so no additional script coverage is required beyond normal English UI symbols. Font fallback must fail gracefully to engine defaults.

## **111.3 Asset Manifest**

Repository must include `CREDITS.md` and `LICENSES.md`. Generated assets include a short provenance note identifying their generator/script. No generated artifact may depend on a secret or proprietary source file that is absent from the repository.

---

# **112. Fully Offline / Monetization Contract**

v1.0 is a **fully offline standalone game**.

Forbidden unless future GDD revision adds them:
- login/account system;
- backend/server dependency;
- cloud requirement;
- telemetry upload;
- remote config;
- real payment integration;
- ads;
- IAP;
- premium currency;
- loot boxes;
- energy timers;
- mandatory internet connectivity.

`RotiFood` is a fictional in-game simulation only. Distribution price (free/paid) is outside gameplay design and must not modify the economy.

---

# **113. Application & Browser Lifecycle Contract**

- Android app loses focus, is minimized, screen is locked, or receives pause notification → add lifecycle pause reason immediately.
- Browser tab becomes hidden or loses active gameplay focus → add lifecycle pause reason immediately.
- Simulation clock, production, burn, freshness, customer patience, RotiFood, courier ETA, weather progression, and staff work all freeze.
- No offline progression and no elapsed-real-time catch-up.
- On return, show `Game Paused`; user explicitly resumes.
- If platform termination risk exists, request a stable-checkpoint autosave after pause is established.
- Never save halfway through an atomic transaction.

---

# **114. Loading / Boot Pipeline**

Boot must be staged so a slow device does not freeze indefinitely and a failure produces an actionable English error screen.

Canonical stages:

1. **Engine bootstrap** — create minimal loading scene, SettingsManager, logger.
2. **Settings load** — validate local settings, apply safe defaults on corruption.
3. **Catalog load** — ingredients, recipes, equipment, locations, staff, achievements, audio definitions.
4. **Catalog validation** — IDs, references, ranges, duplicate detection.
5. **Core managers** — initialize ownership authorities and RNG streams.
6. **Procedural generator registry** — register mesh/material/audio generator definitions.
7. **Minimal cache warm-up** — only assets required by menu/current location; do **not** build Tier 5 world at Day 1.
8. **Save profile metadata scan** — headers only, not full worlds.
9. **Main Menu ready**.
10. On profile load: validate save → migrate schema if required → instantiate current location → reconstruct authority state → reconstruct transient actors from logical state → validate invariants → reveal world.

Loading UI shows stage text and progress estimate based on completed stages, not fake time. No synchronous generation of every possible character/furniture variant at boot.

If save validation fails, preserve the original file, show a recoverable English message, and offer available validated backup/new-game choices. Never silently overwrite a corrupt save.

---

# **115. Procedural Cache & Object Pooling Contract**

## **115.1 Shared Procedural Resources**

A key such as `(generator_id, tier, variant parameters, quality preset independent geometry flags)` maps to reusable mesh/material resources. Identical requests must return shared resources where mutability allows it.

Do not mutate a shared material globally when an instance needs a unique parameter; use per-instance shader parameters/material duplication only when necessary.

## **115.2 Required Pools**

Pool at minimum:
- physical customers;
- RotiFood drivers;
- supply couriers;
- customer patience bars;
- order/attention bubbles;
- coin/revenue popup labels;
- common particles;
- transient paper bags/packages where repeated;
- short-lived audio players if implementation benefits from pooling.

Pool reset contract clears signals, timers, references, carried items, queue slot, path, visual expression, archetype data, and transaction IDs before reuse. Pool exhaustion may expand to a capped safe amount; it may not overlap NPCs or silently drop authoritative demand.

---

# **116. RNG Stream Contract**

Persist independent deterministic state for exactly these streams (owner: `RNGManager`, Section 98):

| Stream | Used for |
| :--- | :--- |
| `weather_rng` | daily weather/holiday roll and forecast (Section 26) |
| `customer_arrival_rng` | physical arrival timing and archetype roll (Sections 65–66) |
| `customer_choice_rng` | recipe choice, purchase quantity, physical tips, critic outcome (Sections 84, 20.10) |
| `rotifood_rng` | RotiFood order generation and tips (Section 22) |
| `staff_rng` | baker auto-retrieve rolls (Section 18.8); the roster itself is fixed |
| `marketing_rng` | campaign-specific rolls (Section 48) |
| `cosmetic_rng` | visual variation only |
| `audio_rng` | audio variation only |

Arrival and choice use separate streams, so rearranging the display never changes who arrives next. Gameplay-significant outcomes may not consume `cosmetic_rng` or `audio_rng`. Adding a particle/sound variant must not alter tomorrow's weather or customer schedule.

---

# **117. Logging & Error Handling Convention**

Canonical log categories:

```text
[BOOT] [DATA] [SAVE] [TIME] [WORLD] [NAV] [PRODUCTION]
[INVENTORY] [ECONOMY] [CUSTOMER] [QUEUE] [CASHIER]
[ROTIFOOD] [SUPPLY] [STAFF] [WEATHER] [UI] [AUDIO] [TEST]
```

Debug builds: informative event-level logs and invariant assertions.
Release builds: warnings/errors and major lifecycle/save failures only.

Forbidden:
- per-frame spam logs;
- swallowing exceptions/errors without category/context;
- silently correcting an invalid authoritative transaction;
- continuing after catalog corruption that makes state unsafe.

User-facing errors are concise English. Detailed diagnostics go to log.

---

# **118. Achievement, Statistics, Records & Analytics Reward Rules**

Achievements never award KR, demand boosts, speed boosts, hidden multipliers, or competitive gameplay advantages. Rewards are limited to:
- badge;
- apron/cosmetic variation;
- signboard style;
- decorative prop/theme;
- profile trophy/record marker.

Lifetime Statistics and Records are observational only and may not change simulation outcomes.

Recipe Analytics canonical fields:
- `produced_units`
- `sold_units`
- `wasted_units`
- `burned_units`
- `stale_sold_units`
- `gross_revenue_kr`
- `ingredient_cost_allocated_kr`
- `average_selling_price_kr`
- `estimated_gross_margin_kr`
- `highest_single_day_units_sold`

Analytics update only from committed authoritative events, never from UI prediction.

---

# **119. Explicit Non-Goals v1.0**

AI implementor must **not invent** the following systems:
- cleaning/sweeping/dishwashing;
- hygiene/food-safety meter;
- toilets;
- equipment durability/breakdown/repair/maintenance;
- staff XP/individual leveling;
- staff shift scheduling;
- combat;
- multiplayer/networking;
- cloud backend;
- ads/IAP;
- random ingredient price market;
- recipe skill tree;
- outdoor visible crowds;
- customer collision blocking while freely walking;
- manual stair-climbing animation;
- offline progression.

The intended complexity already comes from time, production, burn, freshness, inventory, pricing, demand, queues, staffing, delivery, layout, and economy.

---

# **120. AI Anti-Shortcut & Recovery Rules**

## **120.1 Anti-Shortcut**

An autonomous implementation agent must not:
- mark a feature complete because a class/UI shell exists;
- leave required method bodies empty or `pass`;
- ship TODO/FIXME for required v1.0 behavior;
- substitute fake/mock gameplay data in production paths;
- silently simplify a mechanic because it is difficult;
- remove edge cases from the GDD;
- disable a failing acceptance test;
- delete a test to obtain a green build;
- comment out failing production behavior;
- hard-code a temporary result where a system is specified;
- skip save/load reconstruction for a feature;
- skip mobile/Web support because desktop works;
- invent a new gameplay rule to resolve a coding inconvenience.

## **120.2 Ambiguity Recovery Hierarchy**

Before asking for clarification or inventing behavior:
1. Search the canonical GDD rule.
2. Search canonical data schema/ID table.
3. Search relevant acceptance test.
4. Search ownership and event-priority contracts.
5. Follow the closest explicit invariant without adding a new mechanic.
6. If implementation is still impossible without a design choice, record a blocker with the exact conflicting passages/fields. Do not guess silently.

Minor implementation detail choices that do not change visible behavior, balance, persistence, platform support, or invariants may be selected autonomously using maintainable Godot 4.7 conventions.

---

# **121. Final Deliverable Contract**

A completed implementation handoff must contain:

1. Playable Godot 4.7-stable project.
2. All GDScript source.
3. All procedural generation source.
4. Generated assets required at runtime with provenance.
5. Web export/preset ready for itch.io.
6. Android debug export workflow and release AAB-ready preset.
7. Three-profile save implementation and schema migration code.
8. Custom headless test harness.
9. Full test report with REQUIRED test IDs and result.
10. `README.md` — opening, running, testing, exporting.
11. `ARCHITECTURE.md` — ownership/managers/data flow.
12. `SAVE_SCHEMA.md` — actual implemented save format/version.
13. `CREDITS.md`.
14. `LICENSES.md`.
15. `KNOWN_LIMITATIONS.md` containing only genuine platform limitations, not unfinished required features.
16. GDD compliance checklist mapping every major system to code paths/tests.
17. No required TODO/blocker left unresolved for the claimed v1.0 build.

---

# **122. Release Completion Definition**

A feature is **DONE** only if all of the following are true:
- canonical gameplay behavior implemented;
- works at Pause/1×/2×/3× as applicable;
- Web and Android input path supported;
- save/load reconstruction works;
- lifecycle pause is safe;
- relevant statistics/analytics update correctly;
- debug invariant validation passes;
- relevant automated tests pass;
- UI strings are English;
- no placeholder production code remains;
- acceptable performance on target class or documented optimization blocker fixed before release.

A project is **v1.0 RELEASE CANDIDATE** only after boot, gameplay, save, 3 profiles, multi-floor, market deliveries, staffing, economy, achievements, analytics, all export checks, and long-run tests pass together in one integration branch.

---

# **123. v3.1 Master Autonomous Implementation Order**

The implementation agent must preserve dependency order. It may work ahead only when doing so cannot create a second source of truth.

### **Phase -1 — Specification/Data Validation**
- Build canonical ID registry.
- Encode typed data schemas.
- Validate all cross-references.
- Implement test harness skeleton first.

### **Phase 0 — Platform Foundation**
- Godot 4.7 project settings, Compatibility renderer.
- GDScript conventions.
- logger, settings, lifecycle pause bridge.
- InputMap.
- RNG streams.
- shared procedural cache and generic pool service.

### **Phase 1 — Core Simulation**
- TimeManager/PauseManager.
- event sequencing/priority.
- stable-checkpoint service.

### **Phase 2 — Grid, World & Navigation**
- 0.5m tile convention.
- no-build/protected transit cells.
- placement validation.
- multi-floor topology and instant floor links.

### **Phase 3 — Economy & Inventories**
- ledger.
- ingredient storage.
- display inventory stack model.
- atomic transaction helpers.

### **Phase 4 — Equipment & Production**
- mixer/oven/display/storage state machines.
- burn system.
- freshness system.
- procedural equipment visuals.

### **Phase 5 — Player Tasking**
- tap/command layer.
- movement/task queue.
- carried item rules.

### **Phase 6 — Display & Customer Product Selection**
- universal compartments.
- recipe stacks.
- physical target slot selection/revalidation/substitution.

### **Phase 7 — Customer Demand, Admission & Queue**
- time-block demand.
- data-only pending arrivals.
- front-door spawn only after admission.
- patience.
- exclusive queue slots.

### **Phase 8 — Cashier & Physical Sale**
- lane estimated-wait selection.
- manual player cashier.
- automated staff cashier.
- atomic sale/economy/statistics.

### **Phase 9 — RotiFood**
- orders, no pre-reservation, packing, driver queue, handover, ratings.

### **Phase 10 — Market & Supply Delivery**
- market UI/transactions.
- +3 in-game-hour daytime ETA.
- supply courier guaranteed route and auto-storage commit.
- after-hours direct commit.

### **Phase 11 — Staff**
- fixed roster.
- no XP.
- daily duty/wage liability.
- baker automation and cashier automation.

### **Phase 12 — Ratings, Weather, Marketing & Demand Multipliers**
- deterministic formulas and separate RNG.

### **Phase 13 — Location Upgrade & Decoration**
- Tier migration.
- furniture placement/rotation.
- protected routes.
- multi-floor migration.

### **Phase 14 — Camera & Rendering**
- active-floor camera.
- crossfade.
- off-floor alerts.
- quality presets.

### **Phase 15 — UI/UX**
- Main Menu/New Game/Bakery Name.
- 3 save profiles.
- HUD/modals/settings/accessibility.
- Statistics/Records/Recipe Analytics.
- English-only player-facing strings.

### **Phase 16 — Procedural Audio/Polish**
- generate audio assets/events.
- particles/squash-stretch/cosmetic feedback.
- achievements/cosmetic rewards.

### **Phase 17 — Save/Load & Recovery Integration**
- full schema v3.
- golden fixture.
- migration.
- corruption handling.
- idempotent recovery.

### **Phase 18 — Tutorial Day 1–3 Integration**
- scripted event timeline on final systems, not mocks.

### **Phase 19 — Performance & Pooling Pass**
- Web/Android profiling.
- eliminate leaks/allocation spikes.
- quality preset tuning.

### **Phase 20 — Automated QA / Long-Run**
- all required test IDs.
- 100/500/1000-day tests.
- resolution matrix.
- lifecycle/background tests.

### **Phase 21 — Export & Release Candidate**
- Web export validation.
- Android APK/AAB-ready validation.
- final documentation/compliance report.

Do not begin release packaging while REQUIRED tests are red.

---

# **124. MASTER PROMPT FOR AUTONOMOUS IMPLEMENTATION — v3.1 FINAL**

The following prompt is intended to be given together with this GDD to an implementation-capable AI agent:

> **Implement Roti Lezat Tycoon completely according to the attached “Roti Lezat Tycoon — AI-Ready Production Specification v3.1 FINAL”. Treat the GDD as the authoritative product and engineering contract. Use Godot Engine 4.7-stable Standard, GDScript only, and the Compatibility renderer. Build the project in the exact dependency order defined by the GDD. Do not invent, omit, simplify, or silently reinterpret gameplay rules. Do not use C#, GDExtension, third-party addons, downloaded visual/audio assets, backend services, ads, IAP, or network dependencies. All player-facing text must be English. Maintain one authoritative owner for every mutable gameplay state, deterministic event priority, atomic economy/inventory transactions, three isolated save profiles, focus-loss pause behavior, procedural/shared visual resources, object pooling, separated RNG streams, and the specified Web + Android constraints.**
>
> **Before implementing gameplay, encode and validate all canonical IDs/data schemas and create the headless GDScript test harness. Implement every required feature through production-ready code, not stubs or placeholders. A class or screen existing is not evidence of completion. Every system must support save/load reconstruction, lifecycle pause, relevant analytics/statistics, and its acceptance tests. Do not disable, remove, weaken, or bypass failing tests. Follow the ambiguity-recovery hierarchy in the GDD; ask for clarification only if a genuine design blocker remains after exhausting the canonical rules, schemas, tests, ownership rules, and invariants.**
>
> **Continuously run tests and integration checks as phases complete. Validate Web and Android behavior, responsive landscape UI, performance, object pools, procedural caches, multi-floor simulation, long-session stability, and save idempotency. The game is considered complete only when all REQUIRED tests pass and the final deliverable contract is satisfied. Deliver the complete Godot project, source, generated-asset provenance, export presets, test harness/results, README, architecture document, save schema document, credits/licenses, known limitations, and a GDD compliance checklist. Do not claim v1.0 completion while required TODOs, blockers, placeholders, failing tests, missing exports, or unresolved GDD requirements remain.**

This master prompt does not override the GDD; it instructs the implementation agent how to consume it.

---

# **125. v3.1 FINAL SOURCE-OF-TRUTH CHECKLIST**

Before development starts, verify:

- [ ] Godot Engine **4.7-stable Standard**.
- [ ] GDScript only.
- [ ] Compatibility renderer.
- [ ] Web + Android targets.
- [ ] Full player-facing English.
- [ ] 1 tile = 0.5m × 0.5m.
- [ ] 3 save profiles.
- [ ] Fully offline; no ads/IAP/network.
- [ ] Visual assets procedural by code.
- [ ] Audio original/generated with provenance.
- [ ] Default Godot font policy.
- [ ] Exact state ownership matrix implemented.
- [ ] Canonical ID/data validation runs at boot/test.
- [ ] InputMap command layer exists.
- [ ] Event priority and atomic transaction rules exist.
- [ ] Protected routes/no-build placement enforced.
- [ ] NPC only visualized after front-door admission.
- [ ] Queue/equipment exclusive occupancy enforced while free walking actors may pass through one another.
- [ ] Freshness/burn systems independent.
- [ ] Camera active-floor rules implemented.
- [ ] App/browser focus loss pauses simulation with no offline catch-up.
- [ ] Shared procedural cache + object pools.
- [ ] Separate deterministic RNG streams.
- [ ] 3-profile save schema/golden fixture.
- [ ] Headless GDScript test harness and required test IDs.
- [ ] 100/500/1000-day stability suites.
- [ ] Web/Android export validation.
- [ ] No active provisional/unresolved/deferred design decision for v1.0.
- [ ] No required TODO/placeholder remains at release candidate.

**End of v3.1 FINAL Consolidated Implementation Contract.**

# **126. FINAL CONSOLIDATION & SINGLE-SOURCE GOVERNANCE**

Section 126–135 adalah hardening layer terakhir untuk membuat dokumen ini layak dipakai sebagai **single-prompt autonomous implementation contract**. Ketentuan berikut mengikat seluruh project.

## **126.1 One Fact, One Definition**

Setiap fakta gameplay numerik hanya boleh memiliki **satu canonical definition**. Section naratif, tutorial, UI, analytics, dan acceptance test wajib mereferensikan canonical ID/field, bukan menyalin angka secara manual.

Contoh benar:

```text
recipe_plain_loaf.default_unit_price_kr
customer_office_worker.base_patience_seconds
oven_t2.burn_grace_seconds
```

Contoh salah:

```text
"Plain White Loaf costs 120 KR" ditulis ulang di lima section berbeda.
```

Jika validator menemukan dua nilai berbeda untuk field canonical yang sama, build dinyatakan **SPEC_INVALID**.

## **126.2 Authority Order**

Urutan authority bila agent mencari jawaban implementasi:

1. Canonical Data Catalog / schema field.
2. State-machine / transaction contract.
3. Acceptance test.
4. Product/UX narrative.
5. Example text.

Examples tidak pernah mengalahkan data canonical.

## **126.3 Forbidden Legacy Artifacts**

Release source dan GDD final tidak boleh mengandung rule aktif berupa:

- recipe purchase cost / recipe unlock fee;
- ads / rewarded ads / IAP;
- staff leveling / XP;
- equipment durability / breakdown;
- cleaning / hygiene meter;
- network/backend dependency;
- player-facing Indonesian text;
- old engine target selain Godot 4.7-stable;
- C# / GDExtension dependency;
- duplicate implementation-order authority.

---

# **127. ENGLISH CONTENT CATALOG — PLAYER-FACING SOURCE OF TRUTH**

Seluruh teks yang terlihat pemain harus berbahasa Inggris. Bahasa Indonesia hanya boleh berada pada komentar internal, developer documentation, atau GDD narrative yang tidak dirender di game.

Kolom ID di tabel-tabel berikut memakai ID canonical Seksi 78; katalog ini hanya menetapkan teks English-nya.

## **127.1 Core UI Strings**

| String ID | Final English Text |
| :--- | :--- |
| `ui_main_new_game` | `New Game` |
| `ui_main_continue` | `Continue` |
| `ui_main_settings` | `Settings` |
| `ui_main_credits` | `Credits` |
| `ui_main_exit` | `Exit` |
| `ui_profile_empty` | `Empty Profile` |
| `ui_profile_overwrite` | `Overwrite this save profile?` |
| `ui_profile_delete` | `Delete Save` |
| `ui_profile_delete_confirm` | `This cannot be undone. Delete this save?` |
| `ui_pause_title` | `Game Paused` |
| `ui_continue_next_day` | `Continue to Next Day` |
| `ui_daily_summary` | `Daily Summary` |
| `ui_recipe_book` | `Recipe Book` |
| `ui_market` | `Ingredient Market` |
| `ui_staff` | `Staff Management` |
| `ui_marketing` | `Marketing` |
| `ui_achievements` | `Achievements` |
| `ui_statistics` | `Lifetime Statistics` |
| `ui_records` | `Personal Records` |
| `ui_recipe_analytics` | `Recipe Analytics` |
| `ui_decoration` | `Decoration Mode` |
| `ui_rotifood` | `RotiFood Orders` |
| `ui_storage` | `Storage` |
| `ui_make` | `Make` |
| `ui_confirm` | `Confirm` |
| `ui_cancel` | `Cancel` |
| `ui_back` | `Back` |
| `ui_apply` | `Apply` |
| `ui_resume` | `Resume` |
| `ui_loading` | `Preparing the bakery...` |
| `ui_save_error` | `Save data could not be loaded.` |

## **127.2 Recipe Display Names**

| Recipe ID | Final English Display Name |
| :--- | :--- |
| `recipe_plain_loaf` | `Plain White Loaf` |
| `recipe_sugar_donut` | `Sugar Donut` |
| `recipe_plain_fried_bread` | `Plain Fried Bread` |
| `recipe_chocolate_bread` | `Chocolate Bread` |
| `recipe_sausage_roll` | `Sausage Roll` |
| `recipe_sweet_cheese_bread` | `Sweet Cheese Bread` |
| `recipe_strawberry_donut` | `Strawberry Jam Donut` |
| `recipe_classic_baguette` | `Classic Baguette` |
| `recipe_classic_croissant` | `Classic Croissant` |
| `recipe_cinnamon_roll` | `Cinnamon Roll` |
| `recipe_pain_au_chocolat` | `Pain au Chocolat` |
| `recipe_danish_cheese` | `Cheese Danish` |
| `recipe_milk_pullapart` | `Milk Pull-Apart Bread` |
| `recipe_almond_artisan_croissant` | `Almond Artisan Croissant` |
| `recipe_whole_wheat_sourdough` | `Whole Wheat Sourdough` |
| `recipe_gourmet_brioche` | `Gourmet Brioche` |
| `recipe_matcha_brioche` | `Matcha Sweet Brioche` |
| `recipe_basque_cheese_bun` | `Basque Burnt Cheese Bun` |
| `recipe_matcha_mille_crepes` | `Matcha Mille Crepes` |
| `recipe_truffle_bun` | `Truffle Mushroom Artisan Bun` |
| `recipe_luxury_almond_croissant` | `Luxury Almond Croissant` |
| `recipe_premium_cream_cheese_danish` | `Premium Cream Cheese Danish` |
| `recipe_golden_artisan` | `Golden Artisan Bread` |

## **127.3 Ingredient Display Names**

| Ingredient ID | Final English Display Name |
| :--- | :--- |
| `ingredient_flour` | `Wheat Flour` |
| `ingredient_sugar` | `Granulated Sugar` |
| `ingredient_yeast` | `Active Yeast` |
| `ingredient_egg` | `Chicken Egg` |
| `ingredient_butter` | `Butter` |
| `ingredient_water_salt` | `Water & Salt` |
| `ingredient_chocolate` | `Chocolate Bar` |
| `ingredient_cheddar` | `Cheddar Cheese` |
| `ingredient_strawberry_jam` | `Strawberry Jam` |
| `ingredient_milk` | `Fresh Milk` |
| `ingredient_beef_sausage` | `Beef Sausage` |
| `ingredient_cinnamon` | `Cinnamon Powder` |
| `ingredient_whole_wheat_flour` | `Whole Wheat Flour` |
| `ingredient_organic_butter` | `Organic Butter` |
| `ingredient_almond` | `Sliced Almonds` |
| `ingredient_cream_cheese` | `Cream Cheese` |
| `ingredient_matcha` | `Japanese Matcha Powder` |
| `ingredient_truffle` | `Truffle Oil` |

## **127.4 Location Display Names**

| Location ID | Final English Display Name |
| :--- | :--- |
| `location_t1_garage` | `Home Garage Bakery` |
| `location_t2_shophouse` | `Single-Front Shophouse` |
| `location_t3_independent_bakery` | `Independent Bakery` |
| `location_t4_flagship` | `Flagship Store` |
| `location_t5_landmark` | `Mega Bakery Landmark` |

## **127.5 Mandatory Tutorial Copy**

Minimum canonical tutorial strings:

- `Welcome to your bakery. Let's bake your first loaf.`
- `Tap Storage to choose a recipe.`
- `Choose a recipe and a batch size.`
- `Tap the Mixer to start mixing.`
- `The equipment keeps working while you move around.`
- `Mixing is done. Tap the Mixer again to pick up the dough.`
- `Take the dough to the Oven.`
- `Take it out before it burns.`
- `Choose a Display slot for the finished bread.`
- `Customers lose patience while they wait.`
- `Stand at the cashier to serve customers until you hire a Cashier Assistant.`
- `RotiFood orders do not reserve stock until you pack them.`
- `Fried bread goes stale quickly. Keep some batches for the afternoon.`
- `From tomorrow, you can order ingredients at any time. Daytime deliveries take 3 in-game hours.`

No tutorial system may invent alternate gameplay facts not present in these rules.

## **127.6 English Lint Rule**

Release validator memindai seluruh player-facing string resource. Jika string non-English yang bukan proper noun ditemukan, release validation gagal. Nama orang Indonesia seperti `Budi`, `Sari`, `Pak Lurah`, serta nama brand fiksi `RotiFood` boleh dipertahankan.

Seksi 127.7–127.11 melengkapi katalog ini. Placeholder `{…}` diisi runtime; angka dan nama di dalamnya selalu berasal dari data canonical.

## **127.7 Equipment & Storage Names**

| ID | Final English Display Name |
| :--- | :--- |
| `mixer_t1` | `Wooden Bowl & Hand Whisk` |
| `mixer_t2` | `Budget Electric Stand Mixer` |
| `mixer_t3` | `Heavy-Duty Stand Mixer` |
| `mixer_t4` | `Industrial Dough Kneader` |
| `mixer_t5` | `Automated Mixing Robot` |
| `oven_t1` | `Old Stovetop Oven` |
| `oven_t2` | `Mini Electric Oven` |
| `oven_t3` | `Two-Tray Deck Oven` |
| `oven_t4` | `Large Convection Oven` |
| `oven_t5` | `Conveyor Belt Oven` |
| `display_t1` | `Open Bamboo Basket` |
| `display_t2` | `Simple Glass Display` |
| `display_t3` | `Warm Glass Showcase` |
| `display_t4` | `Smart Temperature Showcase` |
| `display_t5` | `Premium Auto-Dispenser Showcase` |
| `storage_t1` | `Old Fridge & Wooden Shelf` |
| `storage_t2` | `Two-Door Fridge & Pantry Cabinet` |
| `storage_t3` | `Upright Chiller & Steel Cabinet` |
| `storage_t4` | `Double Chiller & Fresh Pantry` |
| `storage_t5` | `Cold Room & Industrial Racks` |
| `counter_cashier` | `Cashier Counter` |
| `counter_rotifood` | `RotiFood Pickup Counter` |

## **127.8 Staff Titles & Bios**

Role: `Cashier Assistant` dan `Kitchen Assistant`.

| Tier | Cashier title | Baker title |
| :---: | :--- | :--- |
| 1 | `Trainee Cashier` | `Kitchen Trainee` |
| 2 | `Junior Cashier` | `Junior Baker` |
| 3 | `Skilled Cashier` | `Senior Baker` |
| 4 | `Professional Cashier` | `Pastry Expert` |
| 5 | `Superstar Cashier` | `Master Artisan Baker` |

| Staff ID | Final English Bio |
| :--- | :--- |
| `staff_cashier_budi` | `A diligent first-year student. He gets flustered counting change, but his smile is always genuine.` |
| `staff_cashier_sari` | `The friendly girl next door who greets every customer like a Sunday-morning cartoon host.` |
| `staff_cashier_dimas` | `Loves chatting about the weather so much that he sometimes forgets to press Confirm.` |
| `staff_cashier_nadia` | `A former minimarket cashier who keeps every receipt neat and precise.` |
| `staff_cashier_rian` | `Quick on his feet and always ready for the after-school rush.` |
| `staff_cashier_lili` | `Calm and patient; waiting customers feel relaxed around her.` |
| `staff_cashier_maya` | `A persuasive talker who can soothe even the most hurried office worker.` |
| `staff_cashier_reza` | `His fingers dance across the register keys without a single mistake.` |
| `staff_cashier_dewi` | `Remembers every regular's name and favorite bread.` |
| `staff_cashier_hendra` | `A shopper-psychology expert who helps indecisive customers choose in two seconds.` |
| `staff_cashier_citra` | `Calm and composed, she can handle a queue of twenty without breaking a sweat.` |
| `staff_cashier_kenji` | `Disciplined and courteous, famous for his polite bow and lightning speed.` |
| `staff_cashier_grace` | `The "Ambassador of Smiles". Happy customers often leave her an extra tip.` |
| `staff_cashier_tejo` | `A legendary 90s department-store cashier who can count change with his eyes closed.` |
| `staff_cashier_luna` | `A local idol on a relaxed side job; the counter is always buzzing when she's around.` |
| `staff_baker_joko` | `Can knead heavy dough for hours, but tends to daydream when the oven dings.` |
| `staff_baker_ani` | `Always tastes the jam before spreading it, and loves learning new baking tricks.` |
| `staff_baker_bagus` | `Grew up helping his mother fry snacks at home; always quick on his feet.` |
| `staff_baker_fajar` | `Rolls croissant dough to a perfectly even thickness.` |
| `staff_baker_rina` | `Weighs yeast and butter with great discipline; her dough rarely falls flat.` |
| `staff_baker_doni` | `Never gives up, and always wipes the counter after whisking eggs.` |
| `staff_baker_aris` | `The "Yeast King", a fermentation expert for soft loaves and crusty baguettes.` |
| `staff_baker_tari` | `Graceful and nimble, known for fragrant cinnamon rolls and Danish pastries.` |
| `staff_baker_gilang` | `A pull-apart bread specialist whose dough rises beautifully in any weather.` |
| `staff_baker_sophie` | `A classically trained French baker who folds hundreds of buttery layers.` |
| `staff_baker_danu` | `A healthy-artisan maestro of natural sourdough and whole grains.` |
| `staff_baker_aoi` | `A perfectionist from Kyoto who stacks flawless matcha mille crepes.` |
| `staff_baker_pierre` | `A world-class pastry maestro whose bread is as soft as a cloud.` |
| `staff_baker_mawar` | `A grandmother with a secret family recipe book. Nothing ever burns in her hands.` |
| `staff_baker_alistair` | `A modern culinary alchemist who turns truffle and artisan butter into the city's finest bread.` |

## **127.9 Daily Summary, HUD & Market Strings**

| String ID | Final English Text |
| :--- | :--- |
| `ui_summary_title` | `Day {day} Report` |
| `ui_summary_weather` | `Weather: {weather}` |
| `ui_summary_income` | `Income` |
| `ui_summary_store_sales` | `Store Sales` |
| `ui_summary_best_seller` | `Best Seller: {recipe} ({count})` |
| `ui_summary_rotifood_sales` | `RotiFood Orders` |
| `ui_summary_orders_completed` | `Orders Completed: {count}` |
| `ui_summary_tips` | `Tips` |
| `ui_summary_total_income` | `Total Income` |
| `ui_summary_expenses` | `Expenses` |
| `ui_summary_ingredients_used` | `Ingredients Used` |
| `ui_summary_utilities` | `Utilities (Power & Gas)` |
| `ui_summary_wages` | `Staff Wages` |
| `ui_summary_marketing` | `Marketing` |
| `ui_summary_waste` | `Wasted Bread` |
| `ui_summary_total_expenses` | `Total Expenses` |
| `ui_summary_profit` | `Today's Profit / Loss` |
| `ui_summary_balance` | `Ending Balance` |
| `ui_summary_stats` | `Today's Stats` |
| `ui_summary_customers` | `Walk-in Customers` |
| `ui_summary_deliveries_done` | `Deliveries Completed` |
| `ui_summary_deliveries_cancelled` | `Deliveries Cancelled` |
| `ui_summary_bread_sold` | `Bread Sold` |
| `ui_summary_bread_left` | `Bread Left Over` |
| `ui_summary_store_rating` | `Store Rating` |
| `ui_summary_rotifood_rating` | `RotiFood Stars` |
| `ui_summary_open_market` | `Open Market` |
| `ui_summary_manage_staff` | `Manage Staff` |
| `ui_hud_demand` | `Demand: {done} / {total} breads` |
| `ui_hud_holiday_countdown` | `Holiday in {days} days` |
| `ui_weather_sunny` | `Sunny` |
| `ui_weather_rain` | `Rainy` |
| `ui_event_holiday` | `Holiday` |
| `ui_freshness_fresh` | `Fresh` |
| `ui_freshness_good` | `Good` |
| `ui_freshness_stale` | `Stale` |
| `ui_freshness_unsaleable` | `Expired` |
| `ui_market_tab_ingredients` | `Ingredients` |
| `ui_market_tab_equipment` | `Equipment` |
| `ui_market_tab_upgrade` | `Store Upgrade` |
| `ui_decor_shop` | `Decor Shop` |
| `ui_available_after_closing` | `Available after closing` |
| `ui_equipment_replace` | `Replace` |
| `ui_equipment_sell` | `Sell for {price}` |
| `ui_staff_batch_size` | `Batch Size` |
| `ui_batch_auto` | `Auto` |

## **127.10 Pak Lurah, Mood & Highlight Strings**

| String ID | Final English Text |
| :--- | :--- |
| `dlg_bailout_first` | `Hey there! I heard the bakery has been having a rough few days. Don't give up. The local government has a small-business support program for hardworking owners like you. Here is a little emergency capital to get you baking again. Keep going—your bread is worth it!` |
| `dlg_bailout_repeat` | `Back again, kid? There's no shame in that. Here's a little more help, and a tip to go with it.` |
| `mood_great` | `What a day! Your bread sold like hotcakes!` |
| `mood_good` | `A good day. Keep it up!` |
| `mood_even` | `Not bad. Try baking a little more tomorrow!` |
| `mood_rough` | `A tough day. Don't give up!` |
| `mood_bailout` | `Pak Lurah is on his way...` |
| `hl_top_recipe` | `{recipe} was today's star! {count} sold.` |
| `hl_vip_visit` | `A food vlogger stopped by! Their review arrives tomorrow.` |
| `hl_rain_surge` | `Heavy rain, and RotiFood boomed! +{percent}% online orders.` |
| `hl_orders_cancelled` | `{count} RotiFood orders were cancelled. Watch your stock!` |
| `hl_burnt_batches` | `{count} batches burned today. Keep an eye on the oven!` |
| `hl_staff_star` | `{name} did amazing work today! Production x{multiplier}.` |
| `hl_low_ingredients` | `Ingredients are running low! Don't forget the Market.` |
| `hl_solo_day` | `You're running the shop solo today. You've got this!` |
| `hl_campaign_running` | `{campaign} is still running (day {day}/5).` |
| `hl_holiday` | `Holiday weekend! The whole town is out shopping.` |
| `tip_leftover` | `Try baking a little less tomorrow. Bake for the customers you expect.` |
| `tip_cancelled_orders` | `Keep stock ready for RotiFood drivers too. They don't like waiting!` |
| `tip_low_cash` | `Money's getting tight. Focus on Plain Fried Bread for now—it costs the least and earns the most for what you spend!` |
| `tip_rating_drop` | `Fast service matters a lot for your rating. Hire or upgrade a cashier if you can.` |
| `tip_rain_tomorrow` | `Looks like rain tomorrow. Bake extra for the RotiFood rush!` |
| `tip_first_day` | `Welcome, kid! Plain Fried Bread and Plain White Loaf are the cheapest to start with.` |
| `tip_high_profit` | `Wonderful! Are you ready to upgrade your shop?` |
| `tip_solo_mode` | `It's fine to work alone for a while. Every great business owner has been here!` |
| `tip_holiday_soon` | `A holiday weekend is coming. Stock up, and maybe start a marketing campaign!` |

Pemicu tiap tip dan highlight mengikuti Seksi 11.3–11.4. `tip_holiday_soon` muncul pada Daily Summary sehari sebelum `event_holiday` (Seksi 26.6). Kunjungan bailout ulang (Seksi 3.0.D) memakai `dlg_bailout_repeat` lalu satu tip yang relevan.

## **127.11 Campaign, Customer & Decoration Names**

| ID | Final English Display Name |
| :--- | :--- |
| `campaign_flyer_t1` | `Bread Paper Flyers` |
| `campaign_street_banner_t2` | `Street Banners & Posters` |
| `campaign_radio_magazine_t3` | `Radio & Food Magazine Ads` |
| `campaign_influencer_t4` | `Influencer & Food Vlogger Collab` |
| `campaign_food_festival_t5` | `Grand Food Festival Sponsor` |
| `customer_school_child` | `School Kid` |
| `customer_office_worker` | `Office Worker` |
| `customer_generic` | `Neighbor` |
| `customer_bulk_buyer` | `Party Host` |
| `customer_snob` | `Socialite` |
| `customer_indecisive` | `Indecisive Shopper` |
| `customer_critic` | `Food Vlogger` |
| `driver_rotifood` | `RotiFood Driver` |
| `courier_supply` | `Supply Courier` |
| `decor_potted_plant` | `Potted Plant` |
| `decor_gingham_curtains` | `Gingham Curtains` |
| `decor_wall_clock_pendulum` | `Pendulum Wall Clock` |
| `decor_chalk_menu_board` | `Chalk Menu Board` |
| `decor_bread_basket_stack` | `Stacked Bread Baskets` |
| `decor_cassette_radio` | `Vintage Cassette Radio` |
| `decor_flower_window_box` | `Flower Window Box` |
| `decor_family_photo_wall` | `Family Photo Wall` |
| `decor_hanging_lamp_warm` | `Warm Hanging Lamp` |
| `decor_terracotta_rug` | `Terracotta Rug` |
| `skin_storefront_striped_awning` | `Striped Awning` |
| `skin_storefront_sign_carved_wood` | `Carved Wooden Sign` |
| `badge_first_crumb` | `First Crumb Badge` |
| `decor_plaque_hundred_buns` | `Hundred Buns Plaque` |
| `outfit_apron_neighborhood` | `Neighborhood Apron` |
| `skin_oven_decal_golden` | `Golden Oven Decal` |
| `outfit_chef_hat_perfect` | `Perfect Baker Hat` |
| `decor_floor_mat_smooth` | `Smooth Queue Floor Mat` |
| `skin_rotifood_counter_five_star` | `Five-Star Pickup Counter` |
| `badge_first_savings` | `First Savings Badge` |
| `decor_gold_coin_jar` | `Gold Coin Jar` |
| `decor_trophy_millionaire` | `Millionaire Trophy` |
| `decor_plaque_tier2` | `Proper Shop Plaque` |
| `decor_plaque_tier3` | `Independent Bakery Plaque` |
| `decor_plaque_tier4` | `Flagship Plaque` |
| `decor_trophy_landmark` | `Landmark Trophy` |
| `skin_recipe_book_encyclopedia` | `Bread Encyclopedia Cover` |
| `decor_retro_calculator` | `Retro Calculator` |
| `decor_umbrella_stand` | `Umbrella Stand` |
| `decor_photo_pak_lurah` | `Photo with Pak Lurah` |
| `decor_brass_bell` | `Brass Shop Bell` |
| `decor_plaque_infinity` | `Infinity Plaque` |

---

# **128. REPRODUCIBLE TOOLCHAIN MANIFEST**

## **128.1 Engine**

- Godot Engine: **4.7-stable Standard**.
- Language: **GDScript only**.
- Renderer: **Compatibility**.
- Export templates: harus cocok dengan **Godot 4.7-stable** yang dipakai editor/CI.
- Third-party Godot addons: forbidden unless this GDD is explicitly revised.

## **128.2 Android Build Environment**

Canonical local/CI baseline untuk Godot 4.7:

- OpenJDK **17**.
- Android SDK Platform-Tools **35.0.0 or later**.
- Android SDK Build-Tools **35.0.1**.
- Android SDK Platform **35**.
- Android Command-line Tools: latest compatible package.
- NDK **28.1.13356709 (r28b)**.
- CMake **3.10.2.4988404**.
- Development package ID: `com.rotilezattycoon.game`.
- Orientation: landscape only.
- Release artifact: `.aab`.
- Debug artifact: `.apk` allowed for testing only.

Google Play target-policy dapat berubah setelah dokumen ini ditulis. Store submission harus memakai target SDK yang memenuhi policy terbaru tanpa mengubah gameplay or simulation code.

## **128.3 Web Build Baseline**

- Compatibility renderer / WebGL 2 path.
- Single-threaded Web export adalah canonical default untuk kompatibilitas itch.io; jangan mengharuskan cross-origin isolation.
- Fullscreen optional; landscape-responsive canvas mandatory.
- Browser audio baru dimulai setelah user gesture pada initial start screen.
- Gameplay tidak membutuhkan Service Worker, PWA, backend, atau WebSocket.

## **128.4 Reproducibility Rule**

Repository harus menyimpan:

- `project.godot`;
- `export_presets.cfg` tanpa secret signing credentials;
- exact toolchain manifest;
- required generated-data version;
- validator/test entry points.

Secret keystore/password tidak boleh dikomit ke source control.

---

# **129. RUNTIME HARD LIMITS & BACKPRESSURE**

Hard limits melindungi endless simulation dari runaway allocations. Mencapai limit tidak boleh crash; scheduler menggunakan backpressure/virtual pending state.

| Resource | Hard Limit | Behavior at Limit |
| :--- | ---: | :--- |
| Visible customer + driver actors | 96 | New admissions remain logical/pending; never instantiate beyond cap. |
| Supply courier actors | 2 | Additional deliveries stay queued as data. |
| Pending physical arrivals | 128 | Oldest pending request expires by normal maximum-delay rule before accepting more. |
| Pending RotiFood arrivals/orders | 128 | New demand is deferred; never allocate unbounded arrays. |
| Concurrent ProductionJob objects | 64 | New production request rejected with clear UI feedback. |
| Concurrent active equipment jobs | physical station capacity | Cannot exceed actual equipment slots. |
| Toast/notification cards visible | 3 | Lower-priority notices collapse into notification center/icon. |
| Placed decorations per floor | 24 | Decor Shop and Decoration Mode refuse further placement with a clear message (Section 72.1). |
| World-space alerts visible | 24 | Coalesce by station/type. |
| Simultaneous SFX voices | 24 | Drop lowest-priority cosmetic voice first. |
| Simultaneous music voices | 2 | Crossfade only; no stacking beyond two. |
| Pooled customer bodies | 112 | Pool expansion stops at cap. |
| Pooled transient particles | 256 emitters/effect handles | Reuse/drop cosmetic effect. |
| Ledger entries held in hot memory | 2,048 recent | Older entries aggregate into historical totals while preserving Daily Summary/analytics. |
| Analytics daily records | 1,000 detailed days | Older daily details compact into lifetime aggregates; save size stays bounded. |

No hard limit may silently destroy money, inventory, or an already committed sale. Cosmetic events may be dropped; authoritative simulation events may not.

---

# **130. GOLDEN VISUAL SPECIFICATION**

Section ini mengurangi interpretasi visual antar-AI implementor.

## **130.1 Camera Golden Profile**

- Projection: orthographic.
- Canonical yaw around world vertical: **45°**.
- Canonical downward pitch: **35°**.
- Roll: **0°**.
- Player character apparent height at default zoom: target **72–92 px** at 1280×720 reference viewport.
- Camera rotation is locked during normal gameplay.
- Zoom may change only within per-floor bounds; it must never make interaction markers unreadable.

## **130.2 Character Golden Proportions**

Character total world height: approximately **0.90 m** chibi scale.

- Head: ~42% total character height.
- Torso: ~30%.
- Legs/feet: ~28%.
- Eye line: ~65% of head height from chin.
- Hands/feet use rounded primitives; no realistic fingers required.
- Silhouette must remain readable at reference gameplay zoom.
- Character collision/navigation occupancy uses canonical actor cell logic, not full visual mesh volume.

## **130.3 Material & Lighting Golden Rules**

- Use warm matte materials; avoid photoreal PBR complexity.
- Metal objects may use moderate metallic value but retain soft roughness.
- Avoid neon/cold cyberpunk lighting.
- Primary environment light temperature is warm-neutral to golden.
- Shadow softness prioritized over sharp realism.
- No baked external textures; procedural colors/gradients/noise only.
- Core bread doneness must remain distinguishable without relying only on subtle hue differences.

## **130.4 UI Golden Rules**

- Reference viewport: 1280×720.
- Minimum touch target: **48×48 logical px**.
- Important primary buttons target **56 px+** height where space permits.
- Corner radius: 16–24 px family.
- Text must maintain readable contrast and never be embedded as raster art.
- Critical state uses icon + text + color, never color alone.

## **130.5 Golden Scene Validation**

Implementation must capture/render at least these screenshots for visual QA:

1. Tier 1 preparation at 05:30.
2. Tier 1 open store with four-person full queue.
3. Tier 3 L1 shop with off-floor oven alert.
4. Tier 3 L2 kitchen during parallel production.
5. Tier 5 busy store with physical + RotiFood traffic.
6. Rainy day state.
7. Daily Summary.
8. New Game profile/naming screen.

A visual change that breaks readability in any golden scene blocks release.

---

# **131. NOTIFICATION ORCHESTRATION & SUPPRESSION**

## **131.1 Priority Classes**

| Priority | Examples | Presentation |
| :--- | :--- | :--- |
| P0 Critical | Oven burning, save corruption warning, transaction failure | Persistent/high-visibility; may trigger Smart Speed Safety. |
| P1 High | Oven ready, RotiFood near expiry, customer patience critical | Immediate HUD/world alert. |
| P2 Medium | Mixer ready, supply delivery arrived, staff blocked | Normal toast/icon. |
| P3 Low | Achievement unlocked, analytics milestone, flavor hint | Non-blocking toast; may queue. |
| P4 Cosmetic | Coin sparkle, ambient chatter hint | Droppable under load. |

## **131.2 Suppression Rules**

- Maximum 3 toast cards visible simultaneously.
- Same event type from same source within 2 real seconds is coalesced.
- P0/P1 may pre-empt P3/P4 visual space.
- Achievement toast never pauses game.
- Modal menu opening suppresses world-space popups visually but does not discard authoritative events.
- On resume, only still-relevant alerts are restored.
- Notifications never consume input intended for a blocking confirmation dialog.

## **131.3 Audio Ducking**

Critical notification SFX may duck music briefly; overlapping notification sounds are prioritized by the same P0–P4 order.

---

# **132. TECHNICAL FAILURE-RECOVERY MATRIX**

| Failure | Required Recovery | Player Data Policy |
| :--- | :--- | :--- |
| Primary save invalid, backup valid | Load backup and mark primary for rewrite at next stable checkpoint. | Preserve backup state. |
| Primary + backup invalid | Show English error; do not overwrite until player confirms new game for that profile. | Never auto-delete. |
| Missing catalog ID in save | Attempt migration alias; otherwise quarantine affected entity and log error. | Never invent KR/inventory. |
| Invalid furniture cell after migration | Move to nearest valid decoration cell; if impossible, put furniture into `unplaced_owned_furniture`. | Never delete purchased furniture. |
| Actor path impossible | Repath → safe anchor recovery → log. | Preserve carried item/job. |
| Queue occupant references missing actor | Rebuild lane from authoritative queue list and valid reservations. | No duplicate customer/payment. |
| ProductionJob references missing equipment | Pause job as recoverable orphan; return reserved ingredients only if transaction log proves they were not consumed. | No duplication. |
| NaN money | Reject offending transaction and restore last finite ledger checkpoint. | Never save NaN. |
| +INF money from intentional double overflow | Enter documented endless-economy overflow state. | Do not corrupt save. |
| Procedural mesh/material generation failure | Use deterministic primitive fallback with canonical footprint/interaction points. | Gameplay remains functional. |
| Audio generation failure | Continue silently for that event and log once. | No gameplay effect. |
| Pool object state leak | Reset via mandatory `reset_for_pool()` contract before reuse; failing object is discarded/recreated within hard cap. | Simulation authority remains external. |
| Focus loss during modal/transaction | Pause after completing current atomic commit boundary; never half-commit. | Stable save only. |

All recovery paths must be testable without manually editing production code.

---

# **133. RELEASE VALIDATION & SELF-CONSISTENCY VALIDATOR**

Project harus memiliki headless validation entry point, recommended:

```text
res://tools/release_validator.gd
```

Validator returns non-zero exit/error state when any REQUIRED rule fails.

## **133.1 Specification/Data Checks**

Validate at minimum:

- all canonical IDs unique;
- all referenced IDs exist;
- no recipe has unknown ingredient/equipment ID;
- all recipe yields > 0;
- all recipe prices/costs >= 0;
- every recipe `batch_cost_kr` equals Σ(`fixed_buy_price_kr` × ingredient amount) (Section 63.1);
- every recipe `mix + prep + bake` equals `recipe_total_time`, and its required mixer/oven tiers are within 1..5 (Section 61.5);
- all expiration durations > 0;
- all equipment footprints fit canonical tile units;
- interaction cells do not overlap equipment footprint;
- every location has valid protected-path connectivity;
- every customer archetype has finite patience and valid quantity range;
- every achievement points to an existing event/stat;
- all string IDs referenced by UI exist;
- no player-facing non-English string except proper nouns/approved brand names;
- no duplicate signal subscription in static scene validation where detectable;
- no forbidden third-party addon/network config;
- engine feature target is Godot 4.7 Compatibility.

## **133.2 Source Hygiene Checks**

Release fails if source contains required-feature placeholders matching patterns such as:

```text
TODO
FIXME
pass # in required implementation path
NotImplemented
placeholder_only
mock_production
```

Allowlist only explicit test fixtures/document comments that cannot execute in release.

## **133.3 Build Checks**

- headless boot reaches main menu without error;
- three save profiles initialize independently;
- Web export completes;
- Android export project/preset validates;
- all REQUIRED automated tests pass;
- golden save loads and re-saves idempotently;
- no orphan/missing resource errors;
- no console error during canonical Tier 1 vertical slice.

## **133.4 GDD Consistency Rule**

If documentation is converted to machine-readable catalog files, generated documentation tables should be created from those catalogs, not hand-maintained copies. The machine-readable canonical catalog is implementation authority; this GDD describes its required content and validation constraints.

---

# **134. CANONICAL DATA CATALOG FILE GOVERNANCE**

Untuk menghindari angka tersebar di script, implementasi harus memusatkan tuning data dalam deterministic catalog resources/files.

Recommended authoritative catalogs:

```text
res://data/catalog/ingredients.tres|json
res://data/catalog/recipes.tres|json
res://data/catalog/equipment.tres|json
res://data/catalog/customers.tres|json
res://data/catalog/staff.tres|json
res://data/catalog/locations.tres|json
res://data/catalog/achievements.tres|json
res://data/catalog/strings_en.tres|json
res://data/catalog/audio_events.tres|json
```

Exact storage representation (`Resource` vs JSON) boleh dipilih implementor, tetapi **hanya satu representation menjadi runtime authority**. Jangan mempertahankan JSON dan `.tres` writable copies dengan angka yang sama.

## **134.1 Catalog Versioning**

Setiap catalog set memiliki:

```text
catalog_schema_version
content_version
```

Save file menyimpan version yang diperlukan untuk migration diagnostics.

## **134.2 Generated Documentation**

Jika memungkinkan, build tooling menghasilkan read-only markdown/CSV snapshot dari catalog untuk QA. Snapshot tidak boleh diedit manual.

## **134.3 Balance Changes**

Perubahan balancing dilakukan melalui catalog, kemudian validator + automated tests dijalankan. Jangan mengubah angka langsung di UI, actor script, atau test hanya agar test lulus.

---

# **135. FINAL ONE-PROMPT AUTONOMOUS EXECUTION CONTRACT**

## **135.1 Required Execution Behavior**

AI coding agent yang menerima dokumen ini harus:

1. Membaca seluruh GDD sebelum mengubah project.
2. Menjalankan Phase -1 validator/data setup lebih dahulu.
3. Mengimplementasikan berdasarkan dependency order Section 123.
4. Menjalankan test pada akhir setiap phase yang memiliki REQUIRED acceptance test.
5. Memperbaiki implementation failure; jangan menurunkan requirement atau menghapus test.
6. Menjaga project selalu bootable setelah milestone utama.
7. Menggunakan canonical data catalogs untuk seluruh tuning values.
8. Menjaga seluruh player-facing text English.
9. Menyelesaikan Web + Android release validation sebelum mengklaim selesai.
10. Menghasilkan compliance report akhir yang memetakan requirement → implementation file → test ID.

## **135.2 No-Question Default**

Untuk detail minor yang benar-benar tidak dinyatakan:

1. cari canonical schema/catalog;
2. cari state/transaction contract;
3. cari acceptance test;
4. gunakan solusi paling sederhana yang mempertahankan product pillars, deterministic simulation, mobile/web performance, dan existing data model;
5. dokumentasikan keputusan minor pada implementation notes.

Agent hanya boleh menganggap blocker jika requirement material saling kontradiktif atau tidak mungkin dilaksanakan secara teknis. Pada v3.1 FINAL, contradiction validator seharusnya menangkap kondisi ini sebelum implementation.

## **135.3 Final Compliance Report Format**

Minimum output akhir:

```text
Build Status: PASS/FAIL
Godot Version: 4.7-stable
Renderer: Compatibility
Language: GDScript
Web Export: PASS/FAIL
Android Export Validation: PASS/FAIL
Required Tests: X/X PASS
Spec Validator: PASS/FAIL
Forbidden TODO/FIXME: 0
Missing Canonical IDs: 0
Non-English Player Strings: 0
Known Limitations: [list; must not violate required v1.0 contract]
```

## **135.4 Finality Statement**

**This v3.1 FINAL document is the sole authoritative implementation specification for Roti Lezat Tycoon v1.0. There are no active provisional design decisions. Do not consult older GDD versions as authority.**

