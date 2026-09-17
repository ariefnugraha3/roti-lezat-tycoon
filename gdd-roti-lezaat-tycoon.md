# **Roti Lezat Tycoon: Game Design Document**

Dokumen ini merinci visi strategis, mekanik mendalam, dan arah artistik untuk Roti Lezat Tycoon, sebuah simulator manajemen bisnis toko roti yang menggabungkan kemudahan bermain dengan strategi ekonomi yang menantang.

# **1\. Game Overview**

Roti Lezat Tycoon adalah game simulasi manajemen di mana pemain membangun kerajaan kuliner dari sebuah gerai kecil di garasi hingga menjadi jaringan bakery kelas dunia yang mendominasi pasar.

* Genre: Tycoon / Business Simulation.  
* Game Engine: Godot Engine 4.x.  
* Target Platform Utama:  
  * **Web Browser**: itch.io (HTML5 / WebGL)  
  * **Mobile**: Android (Google Play Store)  
* **Setting Waktu & Nuansa**: **Dunia Modern Tahun 2026 dengan Jiwa Nostalgia Tahun 2000**. Game berlatar di era masa kini (2026)—di mana ekosistem digital seperti smartphone pesanan daring dan kurir pengantaran online (**Ojek Online / Delivery**) menjadi bagian alami dari keseharian bisnis toko roti—namun visual, musik, dan ritme permainannya dibalut atmosfer retro-comfort, kedamaian, dan kehangatan Minggu sore yang mengingatkan pada era tahun 2000 yang damai.
* **Tema & Suasana Utama**: Kewirausahaan kuliner dengan sentuhan nostalgia yang mendalam:
  * **Warm**: Sehangat aroma roti yang baru matang dari oven.
  * **Cozy**: Sesantai suasana Minggu sore yang damai di era tahun 2000-an.
  * **Cute**: Semanis dan selembut roti manis kesukaan anak-anak.
* **Mata Uang Fiksi In-Game**: **Koin Roti** (disingkat **KR**, simbol: 🪙). Seluruh transaksi ekonomi—mulai dari penjualan roti, pembelian bahan baku di pasar, gaji karyawan, hingga biaya ekspansi toko—menggunakan satuan mata uang fiksi ini.

# **2\. Core Gameplay Loop**

Siklus permainan utama terbagi dalam tiga tahap operasional harian:

1. Tahap Persiapan (04:00 - 08:00): Pemain membuka buku resep, memilih roti/kue dan jumlahnya (bahan seperti telur dan tepung otomatis dikalikan). Pemain mengambil bahan dari gudang, mengklik alat, dan mengikuti instruksi resep hingga selesai. Roti ditaruh di slot etalase (posisi penempatan mempengaruhi penjualan). Tepat jam 08:00 toko otomatis buka meski ada roti belum selesai.  
2. Tahap Jualan (08:00 - 18:00): Toko melayani dua arus pembeli sekaligus: (a) Pelanggan fisik yang masuk, memilih roti dari etalase, dan mengantre di kasir; serta (b) Pesanan digital dari aplikasi online modern di tablet kasir yang dijemput langsung oleh Driver Ojek Online. Pemain klik bubble pesanan, menyiapkan atau mengemas roti, klik OK, lalu uang masuk. UI counter stok roti di kanan layar menunjukkan sisa roti di etalase. Pemain bisa membuat roti lagi di tahap ini, tapi jika ditinggal melayani kasir atau orderan delivery, roti berisiko gosong.  
3. Tahap Tutup (18:00): Muncul Daily Summary. Pemain masuk ke menu Pasar untuk membeli bahan baku, upgrade resep, upgrade peralatan, atau upgrade toko sesuai jumlah uang. Setelah pasar ditutup, siklus kembali ke pagi hari.

# **3\. Key Features & Mechanics**

## **Sistem Ekonomi & Biaya Operasional**

Game menerapkan sistem ekonomi bisnis yang jelas, terukur, dan menenangkan (sesuai tema cozy):

* **Harga Bahan Baku Tetap (Fixed Price)**: Seluruh harga bahan baku bersifat pasti dan tidak mengalami fluktuasi naik-turun. Hal ini memungkinkan pemain merencanakan modal belanja dan menghitung margin laba setiap resep roti dengan pasti tanpa stres memantau grafik bursa.
* **Utility Cost (Biaya Utilitas Real-Time)**: Pemakaian listrik dan gas dihitung real-time berdasarkan durasi aktifnya alat (mixer, oven, showcase). Tidak ada mekanisme pemadaman/jeglek; pemain bebas menyalakan alat kapan pun, namun akumulasi pemakaian akan langsung ditagihkan sebagai biaya operasional harian pada layar *Daily Summary*.
* **Tidak Ada Game Over**: *Roti Lezat Tycoon* tidak mengenal layar *Game Over*. Kegagalan finansial hanyalah titik balik, bukan akhir cerita.

### **3.0 Sistem Kebangkrutan & Bantuan Pemerintah (Government Bailout System)**

Jika saldo Koin Roti pemain menyentuh **0 KR** dan tidak sanggup membeli bahan baku minimum untuk beroperasi keesokan harinya, maka secara otomatis sistem akan memicu **peristiwa khusus: "Kunjungan dari Pak Lurah"**.

#### **A. Cutscene Kunjungan Pak Lurah 🏛️**

Keesokan paginya, sebelum toko dibuka, muncul animasi cutscene hangat dan menggemaskan: seorang karakter chibi tambun berwajah ramah—**Pak Lurah**—mengetuk pintu garasi/toko dengan senyum tulus, membawa koper kecil dan amplop berstempel resmi pemerintah daerah. Dialog singkat muncul:

> *"Wah, Nak! Bapak dengar kabarnya usaha rotinya sedang agak seret. Jangan menyerah ya! Pemerintah daerah punya program subsidi UMKM untuk pengusaha kecil berbakat seperti kamu. Ini ada bantuan modal awal. Semangat terus, rotimu enak kok!"* 🥺🍞

#### **B. Paket Bantuan Pemerintah (Bailout Package)**

Pemain menerima paket bantuan yang cukup untuk bertahan—namun tidak lebih dari itu:

| Konten Bantuan | Jumlah | Keterangan |
| :--- | :---: | :--- |
| 🪙 **Koin Roti Subsidi** | **650 KR** | Cukup untuk membeli bahan baku Tier 1 (1 batch Roti Tawar + 1 batch Donat Gula) |
| 🍞 **Bahan Baku Darurat** | Set Tier 1 x1 | Tepung (1) + Ragi (1) + Gula (1) + Air & Garam (1) — langsung masuk gudang |
| 📋 **Surat Peringatan Lunak** | — | Munculnya notifikasi tip strategi dari Pak Lurah di Daily Summary |

> **⚠️ Penting**: 650 KR bantuan ini **tidak cukup** untuk membayar gaji karyawan harian (gaji terendah: 150 KR/hari kasir magang + 180 KR/hari baker magang = 330 KR minimum jika punya 2 karyawan). Pemain **harus menonaktifkan semua karyawan** dan **menjalankan seluruh operasi toko seorang diri** sampai kas terkumpul kembali.

#### **C. Mode Solo — "Kerja Sendiri Dulu" 🧑‍🍳**

Saat saldo berada di kisaran 0–500 KR pasca-bailout, toko memasuki **Mode Solo**:

* **Semua karyawan aktif diliburkan sementara** (bukan dipecat; mereka akan kembali saat pemain punya cukup dana untuk menggaji lagi). Karakter karyawan yang sedang diliburkan muncul sebagai ikon tidur kecil di panel Manajemen Karyawan.
* **Pemain melakukan semua pekerjaan sendiri**: mengaduk adonan, membakar roti, melayani kasir, dan mengemas pesanan ojol—semua dilakukan secara manual seperti hari-hari pertama bermain.
* **Tidak ada utilitas yang diputus**: Listrik dan gas tetap menyala agar produksi bisa berjalan.
* **Bonus "Semangat Bangkit" (+Mood)**: Selama Mode Solo aktif, setiap roti yang berhasil dijual memunculkan animasi semangat kecil di atas karakter pemain (bintang kecil berkilauan ✨) sebagai bentuk apresiasi perjuangan bangkit dari nol.

#### **D. Syarat Bailout & Frekuensi**

* **Frekuensi Bebas**: Tidak ada batasan berapa kali pemain bisa mendapatkan bailout. Game ini ingin menjadi teman yang menenangkan, bukan penghukum.
* **Cooldown Ringan**: Setelah menerima bailout, jika pemain kembali bangkrut dalam 3 hari berturut-turut, Pak Lurah akan datang lagi dengan dialog berbeda yang tetap hangat namun kini memberikan **1 buah tip strategi spesifik** (misalnya: *"Coba fokus bikin Donat Gula dulu, Nak, margin-nya paling oke untuk modal kecil!"*).
* **Tidak Ada Stigma / Penalti Reputasi**: Bailout tidak menurunkan rating toko. Pemerintah hadir diam-diam—pelanggan tidak tahu, toko tetap buka seperti biasa.

#### **E. Kondisi Pemicu Bailout**

| Kondisi | Status |
| :--- | :---: |
| Saldo KR = 0 **DAN** tidak bisa beli bahan baku apapun | ✅ Bailout aktif |
| Saldo KR = 0 **TAPI** masih ada stok bahan di gudang | ❌ Belum bailout (masih bisa produksi) |
| Saldo KR cukup bayar gaji karyawan | ❌ Bailout tidak diperlukan |
| Saldo KR < total gaji karyawan, tapi ≥ harga bahan Tier 1 | ⚠️ Sistem memperingatkan pemain untuk melibur karyawan secara manual |



## **Manajemen Karyawan (Staff Management)**

Karyawan bertindak sebagai Asisten berdedikasi yang membantu otomatisasi operasional toko. Semakin tinggi keahlian karyawan, semakin cepat waktu kerjanya (*work speed*) dan semakin besar gaji harian (*daily salary*) yang harus dibayarkan.

### **3.1 Asisten Kasir (Cashier Assistant)**

Asisten Kasir bertugas di meja kasir untuk melayani transaksi pembeli secara otomatis. Keberadaan kasir membebaskan pemain dari keharusan mengklik balon pesanan secara manual dan menjaga agar antrean toko tidak macet.

| Tingkat / Jabatan | Gaji Harian (Per Hari) | Kecepatan Transaksi (Work Speed) | Kemampuan Khusus & Efek | Cocok untuk Lokasi |
| :--- | :---: | :---: | :--- | :--- |
| **Tier 1: Kasir Magang** | **150 KR** | **7.0 detik** / pelanggan | Pemula, kadang lambat menghitung koin. | Tier 1: Garasi Rumah |
| **Tier 2: Kasir Junior** | **350 KR** | **5.0 detik** / pelanggan | Cukup tanggap untuk arus belanja pejalan kaki. | Tier 2: Ruko 1 Pintu |
| **Tier 3: Kasir Terampil** | **800 KR** | **3.5 detik** / pelanggan | Menurunkan tingkat stres antrean pelanggan sebesar -15%. | Tier 3: Bakery Mandiri |
| **Tier 4: Kasir Profesional** | **1.800 KR** | **2.2 detik** / pelanggan | Mampu memproses tipe pelanggan "Si Galau" 2x lebih cepat. | Tier 4: Flagship Store |
| **Tier 5: Kasir Superstar** | **4.000 KR** | **1.2 detik** / pelanggan | Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra. | Tier 5: Mega Bakery |

*Catatan Kasir:* Jika pemain memiliki lebih dari satu meja kasir (Tier 3 ke atas), penempatan lebih dari satu kasir akan membuka antrean paralel terpisah, secara instan membagi separuh beban antrean toko.

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

* Kitchen Layout: Menata posisi oven, mixer, dan meja kerja agar staf tidak perlu berjalan jauh.  
* Storefront Aesthetics: Meletakkan rak roti dan mesin kasir di posisi strategis untuk menghindari antrean yang menumpuk di depan pintu.

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
   * **Karakter Chibi & Empuk (*Squishy & Doughy*)**: Karakter dirancang bertubuh mini menggemaskan dengan proporsi bulat seperti adonan roti (*dough-like shapes*). Wajah dihiasi mata manik bulat berbinar dan pipi bulat merona merah muda (*rosy cheeks* `#FF9AA2`). Kostum koki dan celemek hadir dalam palet pastel manis: merah muda stroberi (`#FFB7B2`), hijau matcha pastel (`#C7CEEA`), dan biru langit lembut (`#B5EAD7`).
   * **Bentuk Roti Montok & Menggoda**: Roti tawar mengembang tebal (*fluffy loaf*), donat montok empuk dengan taburan *sprinkles* gula warna-warni, serta kue manis bertabur selai berkilau.
   * **Interaksi Sentuh Membal (*Squash & Stretch Bounce*)**: Setiap interaksi (mengetuk roti, menekan tombol UI, atau saat karakter bereaksi senang) memiliki efek elastis yang kenyal seperti memencet roti empuk yang baru keluar dari pemanggang.

## **4.2 Arsitektur Model 3D Prosedural Berbasis Kode**

* **Peralatan Dapur (Mixer, Oven, Display)**: Dirakit secara algoritmik dari mesh primitif Godot (`BoxMesh`, `CylinderMesh`, `TorusMesh`, `SphereMesh`) dengan `StandardMaterial3D` bertekstur warna pastel kayu dan logam tembaga/krom klasik. Bentuk alat bermutasi secara parametrik saat di-upgrade dari perabot tradisional berbahan kayu di Tier 1 hingga teknologi modern di Tier 5.
* **Varian Roti & Pastry**: Mesh geometri dibentuk prosedural. Material memiliki parameter gradasi suhu kematangan: mentah (kuning pucat adonan) $\rightarrow$ matang sempurna (cokelat keemasan menggoda) $\rightarrow$ gosong (hitam gelap berjelaga).
* **Karakter & NPC**: Model chibi dirakit dari komponen badan dan kepala bulat tanpa skeletal armature.
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

## **5.2 Sistem Bahan Baku (Fixed Price Ingredients)**

Setiap bahan baku memiliki **Harga Tetap (Fixed Price)** yang pasti dan tidak berubah-ubah. Sistem ini dirancang untuk menciptakan pengalaman bermain yang santai, terprediksi, dan menenangkan (*cozy tycoon*), di mana pemain dapat dengan mudah menghitung modal pokok produksi (*HPP - Harga Pokok Penjualan*) dan merencanakan keuntungan tanpa perlu cemas memantau spekulasi harga pasar.

Pembelian bahan baku dilakukan setiap saat pada **Tahap Tutup (18:00)** melalui menu **Pasar Bahan Baku**.

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

*Aturan Pembelian:* Pemain dapat membeli bahan baku kapan saja di Tahap Tutup selama saldo mencukupi dan total stok di gudang belum melampaui batas kapasitas Tier Toko yang aktif.

## **5.3 Buku Resep (Recipe Book)**

Resep adalah jantung bisnis *Roti Lezat Tycoon*. Setiap resep memiliki **modal bahan baku**, **harga jual yang bisa diatur pemain**, **rentang profit**, **waktu produksi**, **peralatan minimum**, dan **pelanggan target** masing-masing.

### **Cara Kerja Resep:**
* **Harga Jual Fleksibel**: Pemain bebas mengatur harga jual sendiri di menu Buku Resep, dengan slider harga yang menampilkan emoji reaksi pelanggan (terlalu mahal → wajah cemberut 😤; pas → senyum puas 😊; murah → wajah bahagia bersemangat 🤩).
* **Rentang Harga Wajar**: Tiap resep memiliki *Sweet Spot* harga—kisaran di mana pembeli tetap senang dan margin tetap menguntungkan.
* **Penguncian Resep**: Resep Tier 2, 3, 4, dan 5 perlu **dibeli/dibuka** terlebih dahulu menggunakan KR di menu Buku Resep sebelum bisa diproduksi.

---

### **5.3.1 Resep Tier 1 — Dapur Garasi (Starter Recipes)**

> Resep bawaan, terbuka sejak hari pertama. Modal rendah, rasa simpel, cocok untuk membangun kas awal.
> **Peralatan Minimum**: Mixer Tier 1 (Mangkuk Kayu) + Oven Tier 1 (Oven Tangkring)

| 🍞 Nama Resep | Bahan Baku | Modal Bahan (KR) | Harga Jual Sweet Spot (KR) | Profit Bersih (KR) | Waktu Produksi | Hasil per Batch | Target Pelanggan |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :--- |
| **Roti Tawar Polos** | Tepung (1) + Ragi (1) + Air & Garam (1) + Mentega (1) | **340 KR** | **550 KR** | **+210 KR** | 50 detik | 6 potong | Semua kalangan, favorit keluarga |
| **Donat Gula** | Tepung (1) + Gula (1) + Ragi (1) + Telur (1) + Mentega (1) | **500 KR** | **750 KR** | **+250 KR** | 55 detik | 5 buah | Anak Sekolah, Pekerja pagi |
| **Roti Goreng Polos** | Tepung (1) + Ragi (1) + Air & Garam (1) | **220 KR** | **400 KR** | **+180 KR** | 35 detik | 6 buah | Tetangga, Anak Sekolah |

**Langkah Produksi Tier 1 (Generik):**
1. 🥣 **Aduk** bahan di Mixer → Adonan mentah terbentuk (indikator adonan berwarna putih pucat)
2. 🔥 **Panggang / Goreng** di Oven Tangkring → Progress bar berputar (hijau → kuning → merah)
3. 🍽️ **Pindahkan** ke rak display → Roti berwarna cokelat keemasan siap dijual

---

### **5.3.2 Resep Tier 2 — Ruko Pertama (Intermediate Recipes)**

> Dibuka di Tier Toko 2 (Ruko). Membutuhkan **pembelian resep** (biaya buku resep). Rasa lebih kompleks, margin lebih besar.
> **Peralatan Minimum**: Mixer Tier 2 (Stand Mixer Elektrik) + Oven Tier 2 (Oven Listrik Mini)

| 🥐 Nama Resep | Bahan Baku | Modal Bahan (KR) | Harga Jual Sweet Spot (KR) | Profit Bersih (KR) | Waktu Produksi | Hasil per Batch | Harga Beli Resep | Target Pelanggan |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Roti Cokelat** | Tepung (1) + Ragi (1) + Telur (1) + Cokelat Batang (1) + Mentega (1) | **820 KR** | **1.200 KR** | **+380 KR** | 45 detik | 5 buah | **500 KR** | Anak Sekolah, Pekerja Kantoran |
| **Roti Sosis Gulung** | Tepung (1) + Ragi (1) + Mentega (1) + Sosis Daging Sapi (1) | **710 KR** | **1.100 KR** | **+390 KR** | 40 detik | 5 buah | **500 KR** | Pekerja Kantoran, Sarapan cepat |
| **Roti Keju Manis** | Tepung (1) + Gula (1) + Telur (1) + Susu Segar (1) + Keju Cheddar (1) | **880 KR** | **1.350 KR** | **+470 KR** | 50 detik | 5 buah | **600 KR** | Semua kalangan, favorit delivery |
| **Donat Selai Stroberi** | Tepung (1) + Gula (1) + Ragi (1) + Telur (1) + Selai Buah (1) | **680 KR** | **1.050 KR** | **+370 KR** | 55 detik | 5 buah | **500 KR** | Anak Sekolah, Keluarga |
| **Baguette Klasik** | Tepung (1) + Ragi (1) + Air & Garam (1) | **220 KR** | **650 KR** | **+430 KR** | 60 detik | 3 buah | **400 KR** | Pekerja Kantoran, pelanggan premium awal |

**Langkah Produksi Tier 2 (Tambahan):**
1. 🥣 **Aduk** di Stand Mixer Elektrik → Adonan lebih mulus dan cepat terbentuk
2. ➕ **Isi / Gulung** bahan isian (cokelat, keju, sosis) ke dalam adonan → Animasi tangan karakter melipat-lipat lembut
3. 🔥 **Panggang** di Oven Listrik Mini
4. 🍽️ **Display** ke rak etalase kaca

---

### **5.3.3 Resep Tier 3 — Bakery Mandiri (Advanced Recipes)**

> Dibuka di Tier Toko 3 (Bakery Mandiri). Membutuhkan **pembelian resep** dan karyawan dapur Tier 3 (Senior) atau lebih. Margin profit terbesar di kelas menengah.
> **Peralatan Minimum**: Mixer Tier 3 (Heavy Duty) + Oven Tier 3 (Deck Oven 2 Tray)

| 🥖 Nama Resep | Bahan Baku | Modal Bahan (KR) | Harga Jual Sweet Spot (KR) | Profit Bersih (KR) | Waktu Produksi | Hasil per Batch | Harga Beli Resep | Target Pelanggan |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Croissant Klasik** | Tepung (1) + Mentega Biasa (2) + Telur (1) + Susu Segar (1) + Ragi (1) | **940 KR** | **1.600 KR** | **+660 KR** | 75 detik | 4 buah | **1.200 KR** | Pekerja Kantoran, The Snob |
| **Cinnamon Roll** | Tepung (1) + Gula (1) + Telur (1) + Mentega (1) + Bubuk Kayu Manis (1) | **870 KR** | **1.500 KR** | **+630 KR** | 70 detik | 4 buah | **1.200 KR** | Keluarga, delivery saat hujan |
| **Pain au Chocolat** | Tepung (1) + Mentega Biasa (2) + Cokelat Batang (1) + Telur (1) | **1.090 KR** | **1.800 KR** | **+710 KR** | 80 detik | 4 buah | **1.500 KR** | The Snob, Food Vlogger |
| **Danish Cheese Pastry** | Tepung (1) + Mentega (1) + Telur (1) + Keju Cheddar (1) + Susu Segar (1) | **1.070 KR** | **1.750 KR** | **+680 KR** | 80 detik | 4 buah | **1.500 KR** | The Snob, Bulk Buyer premium |
| **Roti Sobek Susu** | Tepung (1) + Susu Segar (2) + Gula (1) + Mentega (1) + Telur (1) | **920 KR** | **1.550 KR** | **+630 KR** | 65 detik | 6 potong | **1.000 KR** | Emak-Emak Arisan, penggemar RotiFood |

**Langkah Produksi Tier 3 (Tambahan — Teknik Lipatan):**
1. 🥣 **Aduk** di Heavy Duty Stand Mixer → Adonan elastis sempurna
2. 🧈 **Laminasi Adonan**: Animasi karakter melipat, meratakan, dan melipat lagi adonan mentega berlapis (khusus Croissant, Pain au Chocolat, Danish)
3. 🔥 **Panggang** di Deck Oven 2 Tray → Dua loyang masuk sekaligus, efisiensi produksi 2x
4. ✨ **Finishing**: Oles glazur/mentega cair ke permukaan roti → Efek kilap menggiurkan

---

### **5.3.4 Resep Tier 4 — Flagship Store (Expert Recipes)**

> Dibuka di Tier Toko 4 (Flagship). Membutuhkan karyawan dapur Tier 4 (Pakar). Bahan premium dan waktu produksi lebih panjang, namun harga jual jauh lebih tinggi.
> **Peralatan Minimum**: Mixer Tier 4 (Industrial Dough Kneader) + Oven Tier 4 (Rotary Rack Oven)

| 🥨 Nama Resep | Bahan Baku | Modal Bahan (KR) | Harga Jual Sweet Spot (KR) | Profit Bersih (KR) | Waktu Produksi | Hasil per Batch | Harga Beli Resep | Target Pelanggan |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Croissant Artisan Almond** | Tepung (1) + Butter Organik (1) + Telur (1) + Susu Segar (1) + Kacang Almond (1) | **1.470 KR** | **2.800 KR** | **+1.330 KR** | 90 detik | 4 buah | **3.000 KR** | The Snob, Food Vlogger |
| **Sourdough Whole Wheat** | Tepung Whole Wheat (1) + Air & Garam (1) + Ragi (1) | **470 KR** | **2.200 KR** | **+1.730 KR** | 120 detik | 2 buah | **3.500 KR** | The Snob, pelanggan sehat |
| **Brioche Gourmet** | Tepung (1) + Butter Organik (1) + Telur (2) + Gula (1) + Susu Segar (1) | **1.600 KR** | **3.000 KR** | **+1.400 KR** | 100 detik | 4 buah | **3.000 KR** | Sosialita, premium delivery |
| **Matcha Sweet Brioche** | Tepung (1) + Butter Organik (1) + Telur (1) + Bubuk Matcha Jepang (1) + Susu Segar (1) | **1.870 KR** | **3.500 KR** | **+1.630 KR** | 110 detik | 4 buah | **4.000 KR** | The Snob, Food Vlogger, RotiFood premium |
| **Basque Burnt Cheese Bun** | Tepung (1) + Cream Cheese Impor (1) + Telur (2) + Gula (1) | **1.130 KR** | **2.500 KR** | **+1.370 KR** | 95 detik | 4 buah | **3.500 KR** | The Snob, Sosialita |

**Langkah Produksi Tier 4 (Tambahan — Presisi & Fermentasi):**
1. 🕐 **Fermentasi Adonan** (khusus Sourdough): Adonan didiamkan dalam mangkuk tertutup selama durasi fermentasi—pemain bisa mengerjakan tugas lain sambil menunggu
2. 🥣 **Uleni** di Industrial Kneader → Tekstur adonan terlihat sangat elastis mengkilap
3. 🔥 **Panggang** di Rotary Rack Oven → Animasi loyang berputar perlahan di dalam oven bergaya industri
4. 🎨 **Dekorasi Artisan**: Tabur almond iris, oles cream cheese, atau cetak pola scoring di atas roti dengan pisau khusus

---

### **5.3.5 Resep Tier 5 — Mega Bakery (Master Recipes)**

> Resep puncak. Hanya bisa diproduksi di Tier Toko 5 (Mega Bakery) dengan karyawan dapur Tier 5 (Master). Modal tertinggi, profit tertinggi, dan menjadi daya tarik food vlogger serta wisatawan kuliner.
> **Peralatan Minimum**: Mixer Tier 5 (Planetary Industrial) + Oven Tier 5 (Conveyor Belt Oven)

| 👑 Nama Resep | Bahan Baku | Modal Bahan (KR) | Harga Jual Sweet Spot (KR) | Profit Bersih (KR) | Waktu Produksi | Hasil per Batch | Harga Beli Resep | Target Pelanggan |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| **Matcha Mille Crepes** | Tepung (1) + Bubuk Matcha Jepang (1) + Telur (2) + Susu Segar (2) + Butter Organik (1) | **2.450 KR** | **5.500 KR** | **+3.050 KR** | 150 detik | 2 buah | **8.000 KR** | Food Vlogger, wisatawan kuliner |
| **Truffle Mushroom Artisan Bun** | Tepung Whole Wheat (1) + Minyak Truffle (1) + Air & Garam (1) + Ragi (1) | **1.870 KR** | **6.000 KR** | **+4.130 KR** | 140 detik | 3 buah | **10.000 KR** | The Snob, Sosialita, Crazy Rich |
| **Almond Croissant Mewah** | Tepung (1) + Butter Organik (1) + Kacang Almond Iris (1) + Cream Cheese Impor (1) + Telur (1) | **2.470 KR** | **5.000 KR** | **+2.530 KR** | 130 detik | 4 buah | **7.000 KR** | Sosialita, Food Vlogger |
| **Premium Cream Cheese Danish** | Tepung (1) + Butter Organik (1) + Cream Cheese Impor (1) + Selai Buah (1) + Telur (1) | **2.170 KR** | **4.500 KR** | **+2.330 KR** | 120 detik | 4 buah | **6.000 KR** | The Snob, Sosialita, premium delivery |
| **Roti Emas Artisan (Signature)** | Tepung Whole Wheat (1) + Butter Organik (1) + Minyak Truffle (1) + Kacang Almond (1) + Cream Cheese Impor (1) | **3.070 KR** | **8.000 KR** | **+4.930 KR** | 180 detik | 2 buah | **15.000 KR** | Crazy Rich, wisatawan, event besar |

> 🏆 **"Roti Emas Artisan"** adalah resep terprestisius di seluruh game. Setiap unit yang berhasil terjual menghasilkan **+4.930 KR profit bersih per 2 buah**. Cocok dijadikan bahan kampanye iklan Tier 5 (Sponsor Festival) untuk menghasilkan pendapatan harian yang legendaris.

**Langkah Produksi Tier 5 (Master Pipeline):**
1. 🌾 **Seleksi Bahan Premium**: Animasi karakter menatap seksama setiap bahan — minyak truffle, butter organik, cream cheese — dengan ekspresi serius berpengalaman
2. 🥣 **Uleni di Planetary Industrial Mixer** → Kapasitas jumbo, bisa diuleni sekaligus dalam jumlah besar
3. 🔥 **Panggang di Conveyor Belt Oven** → Loyang berjalan otomatis masuk–keluar oven secara berkelanjutan (produksi massal tanpa henti)
4. 🎂 **Finishing Artisan**: Tabur almond berlapis ganda, suntik cream cheese, drizzle minyak truffle, dan dekorasi bunga edible prosedural yang menawan
5. 📦 **Kemasan Premium**: Roti dikemas dalam kotak gift box cokelat elegan sebelum dipajang di showcase pendingin khusus

---

### **5.3.6 Rangkuman Ekonomi Resep**

| Tier | Resep Terbaik (Profit/Batch) | Profit Tertinggi per Batch | Modal Awal |
| :---: | :--- | :---: | :---: |
| 1 | Donat Gula | +250 KR / 5 buah | 0 KR |
| 2 | Roti Keju Manis | +470 KR / 5 buah | 600 KR |
| 3 | Pain au Chocolat | +710 KR / 4 buah | 1.500 KR |
| 4 | Sourdough Whole Wheat | +1.730 KR / 2 buah | 3.500 KR |
| 5 | Roti Emas Artisan | +4.930 KR / 2 buah | 15.000 KR |



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

* **Main HUD (Layar Utama)**: Menampilkan informasi esensial. Pojok kiri atas untuk Saldo Koin Roti (KR) dan Rating Toko. Pojok kanan atas untuk Jam In-Game dan Meteran Biaya Utilitas (menampilkan akumulasi biaya listrik & gas harian yang sedang berjalan). Bagian kanan layar terdapat Counter Stok Roti: Menampilkan sisa jumlah roti di etalase secara real-time agar pemain tahu mana yang laku dan tidak. Pojok kanan bawah untuk Quick Menu (Pasar, Buku Resep, Karyawan, Dekorasi).  
* **Desain Menu Utama**:  
  * Pasar Bahan Baku: Tampilan ala papan tulis kapur toko kelontong tempo dulu yang menampilkan katalog bahan dengan harga tetap, stok gudang saat ini, dan tombol beli jumlah porsi (+ / - / Max).  
  * Buku Menu & Harga: Desain seperti buku resep, terdapat slider untuk mengatur harga jual yang memicu munculnya emoji prediksi reaksi pelanggan (misal: marah jika mahal).  
  * Manajemen Karyawan: Menampilkan daftar staf dalam bentuk ID Card atau Polaroid, lengkap dengan indikator skill dan kecepatan proses.  
  * Mode Dekorasi: Kamera berubah menjadi top-down isometric, lantai memunculkan grid penempatan barang ala The Sims.  
* **UX Feedback & In-Game Indicators**:  
  * Balon Pikiran Pelanggan (Thought Bubbles) untuk menunjukkan keluhan seperti antrean lama (ikon jam pasir) atau harga mahal (ikon uang terbang).  
  * Indikator Oven berupa progress bar melingkar yang berubah dari hijau, kuning, hingga merah berkedip sebagai tanda roti matang/gosong.  
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
* **Risiko Antrean Meledak**: Jika pemain menyalakan kampanye iklan tingkat tinggi (Tier 3-5) namun kapasitas produksi dapur minim atau kasir masih lambat, antrean akan meluber melebihi kapasitas antrean toko. Pelanggan yang menunggu terlalu lama akan marah, kabur, dan justru **menurunkan reputasi toko secara drastis**.
* **Kesiapan Stok Roti**: Pemain harus memastikan kapasitas rak display dan bahan baku di gudang mencukupi sebelum mengaktifkan iklan, agar pelanggan tidak kecewa mendapati etalase dalam kondisi kosong melompong.

# **9\. Sistem Rating & Reputasi**

Toko *Roti Lezat* memiliki **dua buah sistem reputasi yang berjalan secara paralel**: reputasi fisik toko di kota dan reputasi digital di platform aplikasi pengantaran online.

## **9.1 Rating Reputasi Toko Fisik**

* **Dinamika Rating**: Setiap transaksi atau interaksi pelanggan fisik mempengaruhi reputasi toko secara langsung. Semakin tinggi rating toko, semakin banyak warga kota yang datang berbelanja setiap harinya.  
* **Kenaikan Rating**: Didapatkan dari transaksi pembelian yang berhasil, pelayanan kasir yang cepat dan ramah, serta boost otomatis saat kampanye iklan (Ads) sedang berjalan aktif.  
* **Penurunan Rating**: Terjadi akibat pembelian yang gagal (stok habis saat pelanggan sudah di kasir), pelanggan yang kabur karena antrean terlalu panjang, atau menjual roti dengan kualitas buruk/hampir gosong.

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

# **11\. Sistem Laporan Harian (Daily Summary)**

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
| Pelanggan VIP hadir | ⭐ | *"Food Vlogger mampir! Rating toko melonjak besok."* |
| Delivery surge saat hujan | 🌧️ | *"Hujan deras, RotiFood meledak! +180% order online."* |
| Order delivery batal | ⚠️ | *"3 pesanan RotiFood batal karena stok habis. Hati-hati!"* |
| Roti gosong terjual | 🔥 | *"Pelanggan komplain roti gosong. Jaga oven berikutnya!"* |
| Karyawan sangat produktif | 💪 | *"Aris bekerja luar biasa hari ini! Produksi roti x1.6."* |
| Stok gudang hampir habis | 📦 | *"Bahan baku menipis! Jangan lupa belanja di Pasar."* |
| Hari pertama Mode Solo | 🧑‍🍳 | *"Kamu kerja sendiri hari ini. Keren banget, semangat!"* |
| Kampanye iklan aktif | 📢 | *"Iklan Spanduk Jalanan masih berjalan (hari ke-3/5)."* |

---

## **11.4 Catatan & Tips dari Pak Lurah 📋**

Di pojok kanan bawah nota, muncul **amplop kecil atau sticky note kuning** dari Pak Lurah. Berisi satu kalimat tip kontekstual yang relevan dengan kondisi hari itu:

| Kondisi Pemicu | Contoh Tip Pak Lurah |
| :--- | :--- |
| Banyak roti sisa tidak laku | *"Coba kurangi produksi besok, Nak. Bikin sesuai perkiraan pembeli saja."* |
| Order RotiFood banyak batal | *"Stok harus selalu siap untuk ojol juga loh. Mereka tidak sabaran!"* |
| Saldo di bawah 500 KR | *"Wah, hampir tipis nih. Fokus bikin Donat Gula dulu ya, margin-nya paling oke!"* |
| Rating toko turun | *"Kecepatan kasir sangat pengaruh ke rating. Coba upgrade kasir jika bisa."* |
| Cuaca hujan besok (prakiraan) | *"Besok kelihatannya hujan. Persiapkan stok roti lebih banyak untuk ojol ya!"* |
| Hari pertama, saldo awal | *"Selamat memulai, Nak! Roti Tawar dan Donat Gula itu modal paling hemat."* |
| Profit sangat tinggi | *"Wah, hebat sekali! Sudah siap upgrade toko ke level berikutnya belum?"* |
| Mode Solo aktif | *"Tidak apa-apa kerja sendiri dulu. Setiap pengusaha besar pernah ada di posisi ini!"* |

---

## **11.5 Tombol Aksi Setelah Daily Summary**

Setelah pemain selesai membaca laporan, tiga tombol besar muncul di bagian bawah layar dengan desain *pill button* cozy:

| Tombol | Ikon | Fungsi |
| :--- | :---: | :--- |
| **🛒 Buka Pasar** | 🧺 | Masuk ke menu Pasar Bahan Baku untuk belanja bahan, upgrade resep, dan beli peralatan |
| **👷 Kelola Karyawan** | 📋 | Shortcut ke menu manajemen staf untuk hire, libur, atau upgrade karyawan |
| **⏭️ Lanjut ke Besok** | ☀️ | Lewati Pasar dan langsung lanjut ke hari berikutnya (bisa dilakukan jika stok sudah cukup) |

> **Catatan UX**: Tombol "Lanjut ke Besok" akan berwarna abu-abu/nonaktif jika stok bahan baku di gudang **kosong total**, memaksa pemain untuk setidaknya mampir ke Pasar sebelum melanjutkan permainan.

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
    │   Belanja bahan, upgrade alat, beli resep baru
    │        ↓
    │   Pasar Tutup → Lanjut ke Besok
    │
    ├──► 👷 Kelola Karyawan (lalu ke Pasar / Lanjut)
    │
    └──► ⏭️ Langsung Lanjut ke Besok
              ↓
         Animasi malam → Fajar → 04:00 Persiapan Hari Baru
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



# **12\. Spesifikasi Teknis & Multiplatform (Godot 4)**

Game ini dikembangkan menggunakan **Godot Engine 4.x** dengan fokus rilis ganda: **Web Browser (itch.io)** dan **Mobile Android (Google Play Store)** dari satu basis kode (single codebase).

## **12.1 Target & Deployment Platform**

* **Web Browser (itch.io)**:
  * **Format Ekspor**: HTML5 / WebAssembly / WebGL2.
  * **Hosting di itch.io**: Mendukung embed iframe, tombol mode layar penuh (fullscreen toggle), dan responsive scaling.
  * **Optimasi Ukuran Bundle**: Target ukuran file awal (initial download) di bawah 30–40 MB agar waktu pemuatan di browser cepat dan tidak membebani kuota pemain.
  * **Kebijakan Audio Browser (Autoplay Policy)**: Menyediakan splash screen / tombol pembuka *"Klik / Tap untuk Mulai"* agar audio browser terinisialisasi secara legal tanpa diblokir oleh browser.
* **Mobile Android (Google Play Store)**:
  * **Format Ekspor**: Android App Bundle (`.aab`) dengan dukungan arsitektur 64-bit (`arm64-v8a` dan `armeabi-v7a`).
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
   * Generator Karakter: Merakit karakter *chibi* (kepala, badan, topi koki, celemek) dengan randomisasi warna kulit, rambut, dan pakaian.
2. **`ProceduralAnimationSystem` (Animasi Berbasis Kode)**:
   * Menghilangkan kebutuhan rig skeleton 3D eksternal.
   * Animasi berjalan menggunakan modulasi fungsi trigonometri matematika (`sin(time * speed)` untuk ayunan kaki & tangan, serta anggukan kepala).
   * Interaksi dapur (adukan mixer memutar, pintu oven berayun, reaksi emosional pelanggan melompat gembira atau menggeleng kecewa) digerakkan oleh `Tween` bawaan Godot (*squash & stretch interpolation*).
3. **`ProceduralUIFactory` (Pembangkit UI & Grafis 2D)**:
   * Pembuatan seluruh komponen UI (tombol rounded, panel modal, kartu staf, frame resep, kertas nota Daily Summary) memanfaatkan `StyleBoxFlat` dengan *corner radius*, warna tema pastel, dan bayangan (*drop shadow*) dinamis.
   * Rendering Ikon Vektor: Ikon-ikon in-game (koin emas, bintang rating, jam dinding, balon pesanan, ikon hati/marah, emoji mood Daily Summary) digambar secara prosedural menggunakan fungsi CanvasItem `_draw()` (`draw_circle`, `draw_arc`, `draw_line`, `draw_colored_polygon`).
   * Pasar Bahan Baku: Tampilan katalog bahan baku dengan harga tetap, kartu item berpola rounded lembut, ikon bahan prosedural, serta bar visual kapasitas penyimpanan gudang (*pantry bar*).

## **12.4 Skema Kontrol Universal (Tap-First & Mouse)**

* **Prinsip Kontrol Sentuh Universal**: Seluruh mekanisme gameplay (klik balon pesanan kasir, mengambil bahan, memilih resep, navigasi menu) dirancang 100% dapat dioperasikan hanya dengan satu jari (layar sentuh Android) atau satu klik kiri mouse (browser PC).
* **Bebas Ketergantungan Keyboard**: Tidak ada kontrol krusial yang mewajibkan tombol keyboard fisik. Shortcut keyboard (seperti tombol Spasi atau Esc) hanya disediakan sebagai fitur tambahan (*Quality-of-Life*) pada versi Web.

## **12.5 Orientasi & Tampilan Layar Responsif**

* **Orientasi**: Landscape (16:9 resolusi referensi 1280x720 / 1920x1080).
* **Mode Stretch Godot**: `canvas_items` dengan konfigurasi aspect `expand` agar tata letak UI menyesuaikan berbagai rasio layar ponsel (18:9, 19.5:9, 20:9) maupun jendela browser tanpa distorsi atau gambar gepeng.

## **12.6 Sistem Penyimpanan Data (Save System)**

* **Abstraksi Path Virtual `user://`**:
  * **Web (itch.io)**: Otomatis dipetakan oleh Godot Web Export ke IndexedDB browser, sehingga progres pemain tersimpan selama cache/data situs tidak dibersihkan.
  * **Android**: Disimpan ke direktori internal privat aplikasi (`user://savegame.json`).
* **Format Data**: Berbasis JSON serializable yang ringan, portabel, dan tahan terhadap pembaruan versi game (*backward compatible*).

## **12.7 Kesiapan Monetisasi & Distribusi**

* **itch.io**: Menyediakan rilis game gratis / web demo dengan opsi donasi atau link komunitas.
* **Google Play Store**: Arsitektur modular disiapkan untuk monetisasi ramah pemain:
  * **Rewarded Ads (Iklan Berhadiah)**: Pemain menonton iklan sukarela untuk mendapatkan bonus pasokan bahan baku gratis atau percepatan timer oven.
  * **IAP (In-App Purchase)**: Opsi pembelian untuk menghapus iklan atau paket kustomisasi kosmetik toko.