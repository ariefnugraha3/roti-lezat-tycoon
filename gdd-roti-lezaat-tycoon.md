# **Roti Lezat Tycoon: Game Design Document**

Dokumen ini merinci visi strategis, mekanik mendalam, dan arah artistik untuk Roti Lezat Tycoon, sebuah simulator manajemen bisnis toko roti yang menggabungkan kemudahan bermain dengan strategi ekonomi yang menantang.

# **1\. Game Overview**

Roti Lezat Tycoon adalah game simulasi manajemen di mana pemain membangun kerajaan kuliner dari sebuah gerai kecil di garasi hingga menjadi jaringan bakery kelas dunia yang mendominasi pasar.

* Genre: Tycoon / Business Simulation.  
* Target Platform: Mobile (iOS/Android) dan PC (Steam).  
* Tema: Kewirausahaan kuliner dengan fokus pada seni pembuatan roti dan manajemen mikro.

# **2\. Core Gameplay Loop**

Siklus permainan utama terbagi dalam tiga tahap operasional harian:

1. Tahap Persiapan (04:00 \- 08:00): Pemain membuka buku resep, memilih roti/kue dan jumlahnya (bahan seperti telur dan tepung otomatis dikalikan). Pemain mengambil bahan dari gudang, mengklik alat, dan mengikuti instruksi resep hingga selesai. Roti ditaruh di slot etalase (posisi penempatan mempengaruhi penjualan). Tepat jam 08:00 toko otomatis buka meski ada roti belum selesai.  
2. Tahap Jualan (08:00 \- 18:00): Pelanggan masuk, mengambil roti dari etalase, lalu ke kasir (muncul bubble). Pemain klik bubble, muncul list pesanan, klik roti satu per satu, klik OK, lalu uang masuk. UI counter stok roti di kanan layar menunjukkan sisa roti di etalase. Pemain bisa membuat roti lagi di tahap ini, tapi jika ditinggal melayani kasir, roti berisiko gosong.  
3. Tahap Tutup (18:00): Muncul Daily Summary. Pemain masuk ke menu Pasar untuk membeli bahan baku, upgrade resep, upgrade peralatan, atau upgrade toko sesuai jumlah uang. Setelah pasar ditutup, siklus kembali ke pagi hari.

# **3\. Key Features & Mechanics**

## **Ekonomi Fluktuatif**

Dunia game memiliki sistem ekonomi yang dinamis untuk memberikan tantangan strategis bagi pemain:

* Commodity Prices: Harga bahan baku naik turun berdasarkan event musiman atau kelangkaan stok.  
* Utility Cost: Pemakaian listrik dan gas dihitung real-time berdasarkan durasi aktifnya alat (mixer, oven, showcase). Tidak ada mekanisme pemadaman/jeglek; pemain bebas menyalakan alat kapan pun, namun akumulasi pemakaian akan langsung ditagihkan sebagai biaya operasional harian pada layar *Daily Summary*.

## **Manajemen Karyawan**

Karyawan bertugas sebagai Asisten yang bertujuan membantu aktivitas pemain agar lebih efisien. Terdapat dua jenis asisten:

* **Asisten Kasir**: Membantu melayani dan menerima pesanan dari pembeli. Membutuhkan waktu untuk memproses sebuah pesanan. Semakin mahal gaji karyawan (skill tinggi), maka waktu proses pesanan akan semakin cepat sehingga antrean tidak menumpuk.  
* **Asisten Dapur**: Membantu membuat kue atau roti di dapur. Membutuhkan waktu untuk memproses bahan menjadi roti/kue. Semakin mahal gaji karyawan (skill tinggi), maka waktu proses pembuatan akan semakin cepat.

**Batas Kapasitas Karyawan (berdasarkan Tier Lokasi):**

* Tier 1 (Garasi): Maksimal 1 Kasir, 1 Dapur  
* Tier 2 (Ruko 1 Pintu): Maksimal 1 Kasir, 2 Dapur  
* Tier 3 (Toko Bakery Mandiri): Maksimal 2 Kasir, 2 Dapur  
* Tier 4 (Flagship Store): Maksimal 2 Kasir, 3 Dapur  
* Tier 5 (Mega Bakery Landmark): Maksimal 3 Kasir, 4 Dapur

**Sistem Rekrutmen & Gaji:**  
Untuk mendapatkan karyawan, pemain harus membuka iklan lowongan pekerjaan di sebuah website *in-game*. Pemain hanya bisa melihat daftar pelamar dan melakukan rekrutmen pada saat toko tutup (Tahap Tutup). Gaji karyawan dibayarkan secara harian (*per day*) dan akan otomatis dikurangkan dari pendapatan kotor pada layar *Daily Summary* di penghujung hari.

## **Perilaku Konsumen**

Sistem penjualan mengusung model **100% Takeaway (Beli lalu Pergi)**: pelanggan masuk, memilih roti dari rak display, mengantre di kasir untuk membayar, lalu langsung meninggalkan toko.

Pelanggan memiliki kepribadian, preferensi, dan pola kedatangan yang berbeda, yang menuntut pemain untuk tanggap dalam mengatur stok dan kecepatan kasir:

* Kategori Reguler (Harian):  
  * Anak Sekolah (The Sweet Tooth): Kesabarannya tinggi (mau antre), namun uang saku terbatas sehingga akan mengeluh jika harga terlalu mahal. Mencari roti manis (Donat, Roti Cokelat) dan biasanya datang di sore hari.  
  * Pekerja Kantoran (The Rush Hour): Kesabaran sangat rendah. Jika antrean kasir terlalu panjang, mereka akan marah, pergi, dan menurunkan rating toko. Mencari roti praktis (Croissant, Sosis) dan membludak di jam sibuk pagi hari.  
  * Emak-Emak Arisan (The Bulk Buyer): Membeli dalam jumlah sangat banyak sekaligus. Sangat bagus untuk profit, tapi bisa menguras habis stok etalase dalam sekejap, membuat pelanggan berikutnya berisiko kehabisan.  
* Kategori Premium & Spesial (Muncul di Tier Toko Tertinggi / Event Acak):  
  * Sosialita / Crazy Rich (The Snob): Tidak memedulikan harga mahal, tapi menuntut roti kualitas sempurna (Resep Tier 3). Menolak membeli roti kualitas rendah atau yang hampir gosong.  
  * Si Galau (The Indecisive): Membutuhkan waktu proses di kasir 2x lebih lama dari pelanggan biasa. Menuntut pemain atau Asisten Kasir bekerja ekstra agar pelanggan di belakangnya tidak marah karena antrean macet.  
  * Food Vlogger / Kritikus (The VIP Critic): Pelanggan langka. Jika pelayanannya cepat dan rotinya berkualitas, rating toko akan melonjak drastis keesokan harinya. Namun jika ia kecewa, reputasi toko bisa anjlok tajam.

## **Dekorasi & Kustomisasi**

Tata letak toko tidak hanya soal visual, tetapi juga soal optimasi alur kerja (workflow):

* Kitchen Layout: Menata posisi oven, mixer, dan meja kerja agar staf tidak perlu berjalan jauh.  
* Storefront Aesthetics: Meletakkan rak roti dan mesin kasir di posisi strategis untuk menghindari antrean yang menumpuk di depan pintu.

# **4\. Art Direction**

Roti Lezat Tycoon menggunakan gaya visual 3D Low Poly yang cerah dan menggemaskan. Palet warna yang digunakan adalah warna-warna hangat (cokelat roti, kuning mentega, pastel) untuk memberikan kesan "cozy" dan "inviting". Desain karakter dibuat imut dengan proporsi yang lucu agar menarik bagi berbagai kalangan usia.

# **5\. Item & Inventory System**

## **5.1 Peralatan (Equipment)**

Peralatan dibagi menjadi lima tingkatan (tier). Tier 1 adalah peralatan bawaan (Starter) yang didapatkan pemain di awal permainan secara gratis. Semakin tinggi tier, semakin cepat waktu proses atau semakin besar kapasitasnya:

* **Tier 1 (Starter - Bawaan Awal Game):**  
  * **Mixer:** Mangkuk Kayu & Pengocok Manual (Waktu proses: 20 detik | Harga: 0)  
  * **Oven:** Oven Tangkring Tua (Waktu panggang: 30 detik | Harga: 0)  
  * **Display:** Keranjang Bambu Terbuka (Kapasitas: 50 roti | Harga: 0)  
* **Tier 2 (Pemula - Cocok untuk Ruko):**  
  * **Mixer:** Stand Mixer Elektrik Murah (Waktu proses: 15 detik | Harga: 1.500)  
  * **Oven:** Oven Listrik Mini (Waktu panggang: 22 detik | Harga: 2.000)  
  * **Display:** Etalase Kaca Sederhana (Kapasitas: 100 roti | Harga: 1.500)  
* **Tier 3 (Menengah - Cocok untuk Toko Bakery):**  
  * **Mixer:** Heavy Duty Stand Mixer (Waktu proses: 10 detik | Harga: 4.500)  
  * **Oven:** Deck Oven 2 Tray (Waktu panggang: 15 detik | Harga: 6.000)  
  * **Display:** Showcase Kaca dengan Lampu Penghangat (Kapasitas: 200 roti | Harga: 4.500)  
* **Tier 4 (Industrial - Cocok untuk Flagship Store):**  
  * **Mixer:** Industrial Dough Kneader (Waktu proses: 6 detik | Harga: 12.000)  
  * **Oven:** Convection Oven Besar (Waktu panggang: 10 detik | Harga: 15.000)  
  * **Display:** Smart Temperature Showcase (Kapasitas: 350 roti | Harga: 12.000)  
* **Tier 5 (Teknologi Tinggi - Cocok untuk Mega Bakery Landmark):**  
  * **Mixer:** Automated Mixing Robot (Waktu proses: 3 detik | Harga: 35.000)  
  * **Oven:** Conveyor Belt Oven (Waktu panggang: 5 detik | Harga: 50.000)  
  * **Display:** Premium Auto-Dispenser Showcase (Kapasitas: 600 roti | Harga: 30.000)

## **5.2 Bahan Baku (Ingredients)**

Ketersediaan dan harga bahan baku bersifat dinamis sesuai bursa in-game:

* **Bahan Dasar**: Tepung terigu, ragi, air, garam, dan gula.  
* **Bahan Isian & Topping**: Cokelat batang, keju cheddar, selai buah, dan susu.  
* **Bahan Premium**: Tepung Whole wheat, Cream cheese impor, kacang Almond, dan mentega organik.

## **5.3 Daftar Roti (Menu)**

Menu dikelompokkan berdasarkan kompleksitas resep. Resep tingkat tinggi membutuhkan alat canggih dan skill karyawan yang mumpuni:

* **Tier 1 (Resep Dasar)**: Roti Tawar, Donat Gula, Roti Goreng.  
* **Tier 2 (Resep Menengah)**: Croissant, Baguette, Cinnamon Roll, Danish Pastry.  
* **Tier 3 (Resep Premium)**: Sourdough, Matcha Mille Crepes, Truffle Mushroom Bun.

# **6\. Location & Store Upgrade System**

Sistem properti menggunakan mekanisme **Beli Putus (Hak Milik)** sehingga pemain **tidak dibebani biaya sewa harian**. Seluruh penjualan bersifat **100% Takeaway** (tanpa area dine-in).

### **Tabel Ringkasan Spesifikasi Upgrade Toko**

| Spesifikasi | Tier 1: Garasi Rumah | Tier 2: Ruko 1 Pintu | Tier 3: Toko Bakery Mandiri | Tier 4: Flagship Store | Tier 5: Mega Bakery Landmark |
| :--- | :---: | :---: | :---: | :---: | :---: |
| **Status Properti** | Milik Sendiri | Beli Putus | Beli Putus | Beli Putus | Beli Putus |
| **Harga Beli / Upgrade** | **Rp 0 (Starter)** | **Rp 15.000** | **Rp 55.000** | **Rp 180.000** | **Rp 600.000** |
| **Biaya Sewa Tempat** | **Rp 0** | **Rp 0** | **Rp 0** | **Rp 0** | **Rp 0** |
| **Beban Harian Tetap** | Murni Utilitas & Gaji | Murni Utilitas & Gaji | Murni Utilitas & Gaji | Murni Utilitas & Gaji | Murni Utilitas & Gaji |
| **Slot Mixer (Dapur)** | **1 Unit** | **2 Unit** | **3 Unit** | **4 Unit** | **5 Unit** |
| **Slot Oven (Dapur)** | **1 Unit** | **2 Unit** | **3 Unit** | **4 Unit** | **5 Unit** |
| **Slot Rak Display** | **1 Rak** | **2 Rak** | **3 Rak** | **4 Rak** | **6 Rak** |
| **Slot Meja Kasir** | **1 Kasir** | **1 Kasir** | **2 Kasir** | **2 Kasir** | **3 Kasir** |
| **Maks. Asisten Dapur** | 1 Orang | 2 Orang | 2 Orang | 3 Orang | 4 Orang |
| **Maks. Asisten Kasir** | 1 Orang | 1 Orang | 2 Orang | 2 Orang | 3 Orang |
| **Kapasitas Antrean Toko**| 4 Pembeli | 8 Pembeli | 14 Pembeli | 20 Pembeli | 35+ Pembeli |

### **Rincian Progresi Lokasi:**

* **Tier 1: Garasi Rumah (The Humble Beginnings)**:  
  * Kondisi: Usaha rintisan di garasi rumah sendiri. Area dapur dan rak display menyatu tanpa sekat.  
  * Kapasitas: 1 Mixer, 1 Oven, 1 Rak Display (50 roti), 1 Kasir.  
  * Karyawan: Maksimal 1 Kasir, 1 Dapur.  
  * Target Pelanggan: Tetangga dan anak-anak sekitar.

* **Tier 2: Ruko 1 Pintu (The First Step)**:  
  * Kondisi: Ruko komersial pinggir jalan dengan sekat pemisah antara dapur dan area display pembeli.  
  * Kapasitas: 2 Mixer, 2 Oven, 2 Rak Display (Total hingga 200 roti), 1 Kasir.  
  * Karyawan: Maksimal 1 Kasir, 2 Dapur.  
  * Target Pelanggan: Pejalan kaki, ibu-ibu belanja, anak sekolah.

* **Tier 3: Toko Bakery Mandiri (The Established Business)**:  
  * Kondisi: Toko bakery tersendiri dengan tata ruang luas yang mampu membuka 2 jalur kasir bersamaan untuk memecah antrean.  
  * Kapasitas: 3 Mixer, 3 Oven, 3 Rak Display (Total hingga 600 roti), 2 Kasir.  
  * Karyawan: Maksimal 2 Kasir, 2 Dapur.  
  * Target Pelanggan: Pekerja kantoran, mahasiswa, rombongan keluarga.

* **Tier 4: Premium Flagship Store (The Artisan Era)**:  
  * Kondisi: Toko mewah di kawasan bisnis/pusat kota dengan dapur open-kitchen dan display berpendingin/penghangat canggih.  
  * Kapasitas: 4 Mixer, 4 Oven, 4 Rak Display (Total hingga 1.400 roti), 2 Kasir Modern.  
  * Karyawan: Maksimal 2 Kasir, 3 Dapur.  
  * Target Pelanggan: Sosialita, eksekutif, pencinta roti artisan.

* **Tier 5: Mega Bakery Landmark (The Culinary Icon)**:  
  * Kondisi: Supermarket roti raksasa berstandar industri dengan 3 kasir otomatis dan kapasitas produksi masif.  
  * Kapasitas: 5 Mixer, 5 Oven, 6 Rak Display (Total hingga 3.600 roti), 3 Kasir Otomatis.  
  * Karyawan: Maksimal 3 Kasir, 4 Dapur.  
  * Target Pelanggan: Seluruh kalangan kota, katering/pesanan event besar, wisatawan kuliner.

# **7\. UI/UX Design**

* **Main HUD (Layar Utama)**: Menampilkan informasi esensial. Pojok kiri atas untuk Saldo Uang dan Rating Toko. Pojok kanan atas untuk Jam In-Game dan Meteran Biaya Utilitas (menampilkan akumulasi biaya listrik & gas harian yang sedang berjalan). Bagian kanan layar terdapat Counter Stok Roti: Menampilkan sisa jumlah roti di etalase secara real-time agar pemain tahu mana yang laku dan tidak. Pojok kanan bawah untuk Quick Menu (Bursa, Buku Resep, Karyawan, Dekorasi).  
* **Desain Menu Utama**:  
  * Bursa Bahan Baku: Tampilan ala papan tulis kapur dengan grafik garis imut untuk melihat tren harga.  
  * Buku Menu & Harga: Desain seperti buku resep, terdapat slider untuk mengatur harga jual yang memicu munculnya emoji prediksi reaksi pelanggan (misal: marah jika mahal).  
  * Manajemen Karyawan: Menampilkan daftar staf dalam bentuk ID Card atau Polaroid, lengkap dengan indikator skill dan kecepatan proses.  
  * Mode Dekorasi: Kamera berubah menjadi top-down isometric, lantai memunculkan grid penempatan barang ala The Sims.  
* **UX Feedback & In-Game Indicators**:  
  * Balon Pikiran Pelanggan (Thought Bubbles) untuk menunjukkan keluhan seperti antrean lama (ikon jam pasir) atau harga mahal (ikon uang terbang).  
  * Indikator Oven berupa progress bar melingkar yang berubah dari hijau, kuning, hingga merah berkedip sebagai tanda roti matang/gosong.  
* **UI Art Style**: Bentuk tombol membulat (rounded), menghindari sudut kaku. Menggunakan tekstur visual seperti kayu ringan, celemek kain, atau kertas roti dengan palet warna pastel dan krem agar mata tidak cepat lelah.

# **8\. Sistem Pemasaran & Iklan**

Untuk meningkatkan jumlah pengunjung yang datang ke toko, pemain dapat menggunakan fitur periklanan. Setiap kampanye iklan membutuhkan biaya tertentu di awal dan efeknya akan aktif selama 5 hari (in-game).

* **Iklan Tier 1 (Selebaran)**: Membagikan selebaran kepada orang yang lewat di sekitar toko. Peluang kedatangan pembeli bertambah sebesar 20%.  
* **Iklan Tier 2 (Sosial Media Sendiri)**: Mempromosikan toko melalui akun sosial media milik toko. Peluang kedatangan pembeli bertambah sebesar 50%.  
* **Iklan Tier 3 (Influencer)**: Membayar influencer sosial media untuk melakukan promosi. Peluang kedatangan pembeli bertambah sebesar 70%.

# **9\. Sistem Rating & Reputasi**

* **Dinamika Rating**: Setiap transaksi atau interaksi pelanggan akan mempengaruhi reputasi toko secara langsung. Semakin tinggi rating toko, semakin banyak basis jumlah pengunjung yang akan datang setiap harinya.  
* **Kenaikan Rating**: Didapatkan dari transaksi pembelian yang berhasil, pelayanan kasir yang cepat, dan juga mendapatkan boost otomatis saat kampanye iklan (Ads) sedang berjalan.  
* **Penurunan Rating**: Terjadi akibat pembelian yang gagal (misal: stok habis saat pelanggan sudah di kasir), pelanggan yang kabur karena antrean terlalu panjang, atau menjual roti dengan kualitas buruk/hampir gosong.

# **10\. Sistem Musim & Cuaca**

* **Dinamika Cuaca**: Kondisi cuaca dan musim akan berganti dan mempengaruhi perilaku belanja pelanggan.  
* **Cuaca Cerah/Panas**: Arus pengunjung normal. Cocok untuk menjual varian roti standar dan minuman dingin (jika fitur minuman sudah terbuka).  
* **Cuaca Hujan**: Jumlah pengunjung harian (foot traffic) akan menurun drastis karena orang malas keluar rumah. Namun, pelanggan yang datang akan mencari roti yang hangat (baru matang dari oven), dan omzet bisa diselamatkan jika pemain sigap memanggang secara dadakan.  
* **Musim Liburan (Holiday Season/Event)**: Lonjakan pengunjung secara masif. Ini adalah momen terbaik untuk menggunakan Iklan Tier 3 dan memaksimalkan profit, asalkan pemain sanggup mengelola gelombang antrean yang brutal.