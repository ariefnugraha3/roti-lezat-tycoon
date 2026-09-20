class_name StaffDB
extends RefCounted

## Basis data 30 kandidat staf: 15 Asisten Kasir + 15 Asisten Dapur (Baker).
## Sumber angka: GDD 3.1 (tabel tier kasir), 3.2 (tabel tier baker), 3.4 (rekrutmen),
## 3.5.A & 3.5.B (roster nama, profil, ciri visual prosedural).
## Seluruh gaji, kecepatan, dan persentase anti-gosong ditranskripsi PERSIS dari GDD.
## Catatan API: fungsi pencarian bernama `entry()`, BUKAN `get()` (bentrok `Object.get`).

## Peran staf yang sah.
const ROLE_KASIR: String = "kasir"
const ROLE_BAKER: String = "baker"

# --- Warna celemek kanonik per tier (GDD 3.4: warna celemek mencerminkan tingkat keahlian) ---
# Kasir: T1 putih -> T2 hijau mint -> T3 cokelat karamel -> T4 biru navy -> T5 emas.
const APRON_KASIR_T1: Color = Color(1.0, 0.984, 0.961)    # putih gandum lembut #FFFBF5 (GDD 4.1)
const APRON_KASIR_T2: Color = Color(0.710, 0.918, 0.843)  # hijau mint pastel #B5EAD7 (GDD 4.1)
const APRON_KASIR_T3: Color = Color(0.549, 0.290, 0.118)  # cokelat karamel hangat #8C4A1E (GDD 4.1)
const APRON_KASIR_T4: Color = Color(0.133, 0.208, 0.357)  # biru navy elegan #22355B
const APRON_KASIR_T5: Color = Color(0.831, 0.686, 0.216)  # emas koki kepala #D4AF37

# Baker: T1 putih -> T2 oranye pastel -> T3 cokelat kopi -> T4 marun -> T5 emas.
const APRON_BAKER_T1: Color = Color(1.0, 0.984, 0.961)    # putih gandum lembut #FFFBF5
const APRON_BAKER_T2: Color = Color(1.0, 0.753, 0.541)    # oranye pastel #FFC08A
const APRON_BAKER_T3: Color = Color(0.353, 0.180, 0.071)  # cokelat kopi pekat #5A2E12 (GDD 4.1)
const APRON_BAKER_T4: Color = Color(0.431, 0.122, 0.165)  # marun pekat #6E1F2A
const APRON_BAKER_T5: Color = Color(0.831, 0.686, 0.216)  # emas koki agung #D4AF37

# Tabel celemek per tier (indeks 0 = Tier 1), dipakai `apron_color()`.
const APRON_KASIR: Array[Color] = [
	APRON_KASIR_T1, APRON_KASIR_T2, APRON_KASIR_T3, APRON_KASIR_T4, APRON_KASIR_T5,
]
const APRON_BAKER: Array[Color] = [
	APRON_BAKER_T1, APRON_BAKER_T2, APRON_BAKER_T3, APRON_BAKER_T4, APRON_BAKER_T5,
]

# Varian celemek yang disebut khusus oleh teks roster.
const APRON_PUTIH_GADING: Color = Color(1.0, 0.957, 0.886)  # "celemek putih gading" (Dimas) #FFF4E2
const APRON_ORANYE_CERAH: Color = Color(1.0, 0.541, 0.239)  # "celemek oranye cerah" (Doni) #FF8A3D

# --- Warna kulit chibi (palet hangat) ---
const SKIN_TERANG: Color = Color(0.980, 0.851, 0.737)   # #FAD9BC
const SKIN_SEDANG: Color = Color(0.949, 0.788, 0.627)   # #F2C9A0
const SKIN_SAWO: Color = Color(0.878, 0.659, 0.486)     # #E0A87C
const SKIN_GELAP: Color = Color(0.788, 0.541, 0.369)    # #C98A5E

# --- Warna rambut ---
const HAIR_HITAM: Color = Color(0.169, 0.129, 0.094)          # #2B2118
const HAIR_COKELAT: Color = Color(0.290, 0.192, 0.129)        # #4A3121
const HAIR_COKELAT_TERANG: Color = Color(0.478, 0.306, 0.176) # #7A4E2D
const HAIR_PIRANG: Color = Color(0.878, 0.753, 0.439)         # #E0C070
const HAIR_OMBRE_PASTEL: Color = Color(0.910, 0.706, 0.847)   # #E8B4D8
const HAIR_ABU: Color = Color(0.788, 0.761, 0.729)            # #C9C2BA

# --- Tabel tier Asisten Kasir (GDD 3.1), indeks 0 = Tier 1 ---
const KASIR_SALARY: Array[int] = [150, 350, 800, 1800, 4000]    # Gaji Harian (KR)
const KASIR_SPEED: Array[float] = [7.0, 5.0, 3.5, 2.2, 1.2]     # detik per pelanggan
const KASIR_PERK: Array[String] = [
	"Pemula, kadang lambat menghitung koin.",
	"Cukup tanggap untuk arus belanja pejalan kaki.",
	"Menurunkan tingkat stres antrean pelanggan sebesar -15%.",
	"Mampu memproses tipe pelanggan \"Si Galau\" 2x lebih cepat.",
	"Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra.",
]

# --- Tabel tier Asisten Dapur / Baker (GDD 3.2), indeks 0 = Tier 1 ---
const BAKER_SALARY: Array[int] = [180, 400, 950, 2200, 5000]       # Gaji Harian (KR)
const BAKER_SPEED: Array[float] = [1.0, 1.25, 1.60, 2.00, 2.80]    # pengali kecepatan kerja
const BAKER_ANTI_BURN: Array[float] = [0.0, 0.25, 0.60, 0.90, 1.00] # peluang Auto-Retrieve
const BAKER_PERK: Array[String] = [
	"0% (Pemain tetap harus mengangkat loyang sendiri)",
	"25% peluang otomatis mengangkat roti matang",
	"60% peluang otomatis mengangkat roti matang",
	"90% peluang otomatis mengangkat roti matang",
	"100% Anti-Gosong (Pasti ditata rapi ke etalase display)",
]

## Urutan kanonik ID kasir (sudah terurut menaik menurut tier).
const ORDER_KASIR: Array[String] = [
	"budi", "sari", "dimas",
	"nadia", "rian", "lili",
	"maya", "reza", "dewi",
	"hendra", "citra", "kenji",
	"grace", "tejo", "luna",
]

## Urutan kanonik ID baker (sudah terurut menaik menurut tier).
const ORDER_BAKER: Array[String] = [
	"joko", "ani", "bagus",
	"fajar", "rina", "doni",
	"aris", "tari", "gilang",
	"sophie", "danu", "aoi",
	"pierre", "mawar", "alistair",
]

## Data lengkap 30 staf. Kunci `visual` adalah parameter siap pakai untuk
## `CharacterFactory`, hasil terjemahan kolom "Ciri Visual Prosedural" GDD 3.5.
## Kunci `visual` identik untuk ke-30 entri:
## { apron, hair, hair_style, accessory, chubby, hat, skin, note }.
const DATA: Dictionary = {
	# ===================== A. ROSTER ASISTEN KASIR (GDD 3.5.A) =====================
	"budi": {
		"id": "budi",
		"name": "Budi",
		"role": "kasir",
		"tier": 1,
		"salary": 150,
		"speed": 7.0,
		"perk": "Pemula, kadang lambat menghitung koin.",
		"profile": "Mahasiswa baru yang rajin; sering grogi saat menghitung koin kembalian tapi selalu tersenyum tulus.",
		"visual": {
			"apron": Color(1.0, 0.984, 0.961),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "belah_samping",
			"accessory": ["kacamata_bulat"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Kacamata bulat besar, celemek katun putih polos, rambut belah samping rapi.",
		},
		"extra": {},
	},
	"sari": {
		"id": "sari",
		"name": "Sari",
		"role": "kasir",
		"tier": 1,
		"salary": 150,
		"speed": 7.0,
		"perk": "Pemula, kadang lambat menghitung koin.",
		"profile": "Gadis ramah tetangga toko; suka menyapa pembeli dengan suara riang ceria ala kartun Minggu pagi.",
		"visual": {
			"apron": Color(1.0, 0.984, 0.961),
			"hair": Color(0.290, 0.192, 0.129),
			"hair_style": "kuncir_ganda",
			"accessory": ["pita_kuning"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Kuncir kuda ganda, pita rambut kuning mentega, celemek putih bergaris tipis.",
		},
		"extra": {},
	},
	"dimas": {
		"id": "dimas",
		"name": "Dimas",
		"role": "kasir",
		"tier": 1,
		"salary": 150,
		"speed": 7.0,
		"perk": "Pemula, kadang lambat menghitung koin.",
		"profile": "Terlalu asyik bercerita cuaca dengan pelanggan sampai kadang lupa menekan tombol konfirmasi kasir.",
		"visual": {
			"apron": Color(1.0, 0.957, 0.886),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": [],
			"chubby": 0.0,
			"hat": "topi_pet",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Topi pet kasir miring ke samping, celemek putih gading, ekspresi cengengesan.",
		},
		"extra": {},
	},
	"nadia": {
		"id": "nadia",
		"name": "Nadia",
		"role": "kasir",
		"tier": 2,
		"salary": 350,
		"speed": 5.0,
		"perk": "Cukup tanggap untuk arus belanja pejalan kaki.",
		"profile": "Mantan kasir minimarket; terbiasa menyusun struk transaksi dengan sangat rapi dan teliti.",
		"visual": {
			"apron": Color(0.710, 0.918, 0.843),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "bob",
			"accessory": [],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Rambut bob pendek rapi, celemek hijau mint pastel, senyum profesional ramah.",
		},
		"extra": {},
	},
	"rian": {
		"id": "rian",
		"name": "Rian",
		"role": "kasir",
		"tier": 2,
		"salary": 350,
		"speed": 5.0,
		"perk": "Cukup tanggap untuk arus belanja pejalan kaki.",
		"profile": "Pemuda aktif yang gesit; tanggap melayani arus pejalan kaki jam pulang sekolah.",
		"visual": {
			"apron": Color(0.710, 0.918, 0.843),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "spike",
			"accessory": ["gelang_karet"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Rambut spike pendek, celemek hijau mint, gelang karet oranye sporty.",
		},
		"extra": {},
	},
	"lili": {
		"id": "lili",
		"name": "Lili",
		"role": "kasir",
		"tier": 2,
		"salary": 350,
		"speed": 5.0,
		"perk": "Cukup tanggap untuk arus belanja pejalan kaki.",
		"profile": "Pembawaannya tenang dan sabar; membuat pembeli yang sedang antre merasa adem dan tidak gelisah.",
		"visual": {
			"apron": Color(0.710, 0.918, 0.843),
			"hair": Color(0.290, 0.192, 0.129),
			"hair_style": "pendek",
			"accessory": ["jepit_stroberi"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Jepit rambut stroberi imut, celemek hijau mint lembut, pipi merona merah muda.",
		},
		"extra": {},
	},
	"maya": {
		"id": "maya",
		"name": "Maya",
		"role": "kasir",
		"tier": 3,
		"salary": 800,
		"speed": 3.5,
		"perk": "Menurunkan tingkat stres antrean pelanggan sebesar -15%.",
		"profile": "Memiliki keahlian komunikasi persuasif; mampu meredakan emosi pekerja kantor yang terburu-buru.",
		"visual": {
			"apron": Color(0.549, 0.290, 0.118),
			"hair": Color(0.290, 0.192, 0.129),
			"hair_style": "pendek",
			"accessory": ["bando_gingham", "pin_senyum"],
			"chubby": 0.0,
			"hat": "bando",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Bando motif kotak-kotak (gingham), celemek cokelat karamel, pin senyum.",
		},
		"extra": {"queue_stress": -0.15},
	},
	"reza": {
		"id": "reza",
		"name": "Reza",
		"role": "kasir",
		"tier": 3,
		"salary": 800,
		"speed": 3.5,
		"perk": "Menurunkan tingkat stres antrean pelanggan sebesar -15%.",
		"profile": "Jari-jemarinya lihai menari di atas tuts mesin kasir dengan akurasi hitungan tanpa celah.",
		"visual": {
			"apron": Color(0.549, 0.290, 0.118),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": ["jam_vintage"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Jam tangan vintage era 2000-an, celemek karamel berkantong dobel, tatapan fokus.",
		},
		"extra": {"queue_stress": -0.15},
	},
	"dewi": {
		"id": "dewi",
		"name": "Dewi",
		"role": "kasir",
		"tier": 3,
		"salary": 800,
		"speed": 3.5,
		"perk": "Menurunkan tingkat stres antrean pelanggan sebesar -15%.",
		"profile": "Ingatannya tajam luar biasa; selalu hafal nama dan jenis roti favorit para pelanggan setia toko.",
		"visual": {
			"apron": Color(0.549, 0.290, 0.118),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "panjang_kepang",
			"accessory": ["buku_saku"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Rambut panjang dikepang rapi, celemek cokelat karamel, buku catatan mini di saku.",
		},
		"extra": {"queue_stress": -0.15},
	},
	"hendra": {
		"id": "hendra",
		"name": "Hendra",
		"role": "kasir",
		"tier": 4,
		"salary": 1800,
		"speed": 2.2,
		"perk": "Mampu memproses tipe pelanggan \"Si Galau\" 2x lebih cepat.",
		"profile": "Ahli psikologi konsumen; sanggup memandu pembeli \"Si Galau\" memutuskan pilihan dalam 2 detik.",
		"visual": {
			"apron": Color(0.133, 0.208, 0.357),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "belah_samping",
			"accessory": ["kacamata_emas"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Kemeja berkerah rapi di balik celemek biru navy elegan, kacamata bingkai emas.",
		},
		"extra": {"galau_speedup": 2.0},
	},
	"citra": {
		"id": "citra",
		"name": "Citra",
		"role": "kasir",
		"tier": 4,
		"salary": 1800,
		"speed": 2.2,
		"perk": "Mampu memproses tipe pelanggan \"Si Galau\" 2x lebih cepat.",
		"profile": "Sangat tenang dan berwibawa; sanggup melayani antrean 20 orang tanpa sedikit pun terlihat panik.",
		"visual": {
			"apron": Color(0.133, 0.208, 0.357),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "sanggul",
			"accessory": [],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Sanggul rambut modern elegan, celemek navy bergaris emas tipis, senyuman anggun.",
		},
		"extra": {"galau_speedup": 2.0},
	},
	"kenji": {
		"id": "kenji",
		"name": "Kenji",
		"role": "kasir",
		"tier": 4,
		"salary": 1800,
		"speed": 2.2,
		"perk": "Mampu memproses tipe pelanggan \"Si Galau\" 2x lebih cepat.",
		"profile": "Kasir berdisiplin tinggi; terkenal dengan keramahan membungkuk sopan dan kecepatan kilatnya.",
		"visual": {
			"apron": Color(0.133, 0.208, 0.357),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "cepak",
			"accessory": ["dasi_kupu"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Rambut cepak rapi, celemek biru navy, pita leher dasi kupu-kupu merah marun.",
		},
		"extra": {"galau_speedup": 2.0},
	},
	"grace": {
		"id": "grace",
		"name": "Grace",
		"role": "kasir",
		"tier": 5,
		"salary": 4000,
		"speed": 1.2,
		"perk": "Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra.",
		"profile": "\"Duta Senyum Nasional\"; aura ramahnya membuat pembeli bahagia dan sering memberi tip koin ekstra.",
		"visual": {
			"apron": Color(0.831, 0.686, 0.216),
			"hair": Color(0.878, 0.753, 0.439),
			"hair_style": "ikal",
			"accessory": ["anting_mutiara"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Celemek sutra emas berbordir logo toko, anting mutiara kecil, rambut pirang ikal.",
		},
		"extra": {"tip_chance": 0.05},
	},
	"tejo": {
		"id": "tejo",
		"name": "Tejo",
		"role": "kasir",
		"tier": 5,
		"salary": 4000,
		"speed": 1.2,
		"perk": "Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra.",
		"profile": "Kasir legendaris era toserba 90-an; sanggup menghitung kembalian secepat kilat bahkan sambil merem.",
		"visual": {
			"apron": Color(0.831, 0.686, 0.216),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": ["kumis", "pena_telinga"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.788, 0.541, 0.369),
			"note": "Kumis tipis retro nostalgia, celemek emas koki kepala, pena terselip di telinga.",
		},
		"extra": {"tip_chance": 0.05},
	},
	"luna": {
		"id": "luna",
		"name": "Luna",
		"role": "kasir",
		"tier": 5,
		"salary": 4000,
		"speed": 1.2,
		"perk": "Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra.",
		"profile": "Bintang idola lokal yang magang santai di toko roti; kehadirannya membuat kasir selalu ramai gembira.",
		"visual": {
			"apron": Color(0.831, 0.686, 0.216),
			"hair": Color(0.910, 0.706, 0.847),
			"hair_style": "ombre",
			"accessory": ["pin_bintang"],
			"chubby": 0.0,
			"hat": "bando_kelinci",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Rambut ombre pastel manis, bando telinga kelinci empuk, celemek emas bertabur pin bintang.",
		},
		"extra": {"tip_chance": 0.05},
	},

	# ================ B. ROSTER ASISTEN DAPUR / BAKER (GDD 3.5.B) ================
	"joko": {
		"id": "joko",
		"name": "Joko",
		"role": "baker",
		"tier": 1,
		"salary": 180,
		"speed": 1.0,
		"perk": "0% (Pemain tetap harus mengangkat loyang sendiri)",
		"profile": "Kuat mengaduk adonan tepung berat berjam-jam; tapi sering melamun saat oven berdenting.",
		"visual": {
			"apron": Color(1.0, 0.984, 0.961),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": [],
			"chubby": 0.7,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Tubuh agak gempal berisi, celemek putih tebal bertabur bubuk tepung putih.",
		},
		"extra": {"anti_burn": 0.0},
	},
	"ani": {
		"id": "ani",
		"name": "Ani",
		"role": "baker",
		"tier": 1,
		"salary": 180,
		"speed": 1.0,
		"perk": "0% (Pemain tetap harus mengangkat loyang sendiri)",
		"profile": "Suka mencicipi selai sebelum dioles ke roti; sangat antusias belajar aneka teknik memanggang.",
		"visual": {
			"apron": Color(1.0, 0.984, 0.961),
			"hair": Color(0.290, 0.192, 0.129),
			"hair_style": "pendek",
			"accessory": [],
			"chubby": 0.0,
			"hat": "topi_koki",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Topi koki miring menggemaskan, celemek putih polos, hidung bertotol tepung.",
		},
		"extra": {"anti_burn": 0.0},
	},
	"bagus": {
		"id": "bagus",
		"name": "Bagus",
		"role": "baker",
		"tier": 1,
		"salary": 180,
		"speed": 1.0,
		"perk": "0% (Pemain tetap harus mengangkat loyang sendiri)",
		"profile": "Terbiasa membantu ibunya membuat kue goreng di rumah; langkah kakinya cepat saat mondar-mandir.",
		"visual": {
			"apron": Color(1.0, 0.984, 0.961),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": [],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Celemek putih pendek, lengan baju dilipat tinggi, senyum polos bersemangat.",
		},
		"extra": {"anti_burn": 0.0},
	},
	"fajar": {
		"id": "fajar",
		"name": "Fajar",
		"role": "baker",
		"tier": 2,
		"salary": 400,
		"speed": 1.25,
		"perk": "25% peluang otomatis mengangkat roti matang",
		"profile": "Menguasai teknik menggulung adonan croissant dengan ketebalan yang merata sempurna.",
		"visual": {
			"apron": Color(1.0, 0.753, 0.541),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": ["sarung_tangan"],
			"chubby": 0.0,
			"hat": "bandana",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Celemek oranye pastel, sarung tangan kain tahan panas, bandana koki oranye.",
		},
		"extra": {"anti_burn": 0.25},
	},
	"rina": {
		"id": "rina",
		"name": "Rina",
		"role": "baker",
		"tier": 2,
		"salary": 400,
		"speed": 1.25,
		"perk": "25% peluang otomatis mengangkat roti matang",
		"profile": "Sangat disiplin menimbang gramasi ragi dan mentega; jarang sekali membuat adonan bantat.",
		"visual": {
			"apron": Color(1.0, 0.753, 0.541),
			"hair": Color(0.290, 0.192, 0.129),
			"hair_style": "kuncir_ganda",
			"accessory": ["kacamata_bulat"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Kacamata frame bulat tipis, celemek oranye pastel berenda, rambut dikuncir rapi.",
		},
		"extra": {"anti_burn": 0.25},
	},
	"doni": {
		"id": "doni",
		"name": "Doni",
		"role": "baker",
		"tier": 2,
		"salary": 400,
		"speed": 1.25,
		"perk": "25% peluang otomatis mengangkat roti matang",
		"profile": "Tidak mudah patah arang; sigap membersihkan meja dapur setiap selesai mengocok telur.",
		"visual": {
			"apron": Color(1.0, 0.541, 0.239),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "cepak",
			"accessory": ["handuk_pundak"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Celemek oranye cerah, handuk kecil tersampir di pundak, ekspresi ramah fokus.",
		},
		"extra": {"anti_burn": 0.25},
	},
	"aris": {
		"id": "aris",
		"name": "Aris",
		"role": "baker",
		"tier": 3,
		"salary": 950,
		"speed": 1.60,
		"perk": "60% peluang otomatis mengangkat roti matang",
		"profile": "\"Si Raja Ragi\"; ahli fermentasi roti tawar dan baguette berkulit renyah dengan remah selembut spons.",
		"visual": {
			"apron": Color(0.353, 0.180, 0.071),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": ["kumis"],
			"chubby": 0.0,
			"hat": "topi_koki",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Topi koki silinder sedang, celemek cokelat kopi pekat, kumis melingkar rapi.",
		},
		"extra": {"anti_burn": 0.60},
	},
	"tari": {
		"id": "tari",
		"name": "Tari",
		"role": "baker",
		"tier": 3,
		"salary": 950,
		"speed": 1.60,
		"perk": "60% peluang otomatis mengangkat roti matang",
		"profile": "Gerakannya anggun dan luwes dalam memanggang Cinnamon Roll dan Danish pastry yang wangi semerbak.",
		"visual": {
			"apron": Color(0.353, 0.180, 0.071),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "sanggul",
			"accessory": ["tusuk_konde"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Celemek cokelat kopi bermotif renda bunga, rambut disanggul rapi dengan tusuk konde kayu.",
		},
		"extra": {"anti_burn": 0.60},
	},
	"gilang": {
		"id": "gilang",
		"name": "Gilang",
		"role": "baker",
		"tier": 3,
		"salary": 950,
		"speed": 1.60,
		"perk": "60% peluang otomatis mengangkat roti matang",
		"profile": "Tangan dingin spesialis roti sobek manis; adonannya selalu mengembang cantik dalam cuaca apa pun.",
		"visual": {
			"apron": Color(0.353, 0.180, 0.071),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": ["sarung_tangan"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.788, 0.541, 0.369),
			"note": "Celemek cokelat kopi, sarung tangan oven tebal motif gingham, tatapan tenang berpengalaman.",
		},
		"extra": {"anti_burn": 0.60},
	},
	"sophie": {
		"id": "sophie",
		"name": "Sophie",
		"role": "baker",
		"tier": 4,
		"salary": 2200,
		"speed": 2.00,
		"perk": "90% peluang otomatis mengangkat roti matang",
		"profile": "Baker Prancis lulusan Eropa klasik; ahli melipat pastry mentega ratusan lapis tipis yang renyah berkilau.",
		"visual": {
			"apron": Color(0.431, 0.122, 0.165),
			"hair": Color(0.478, 0.306, 0.176),
			"hair_style": "bob",
			"accessory": ["syal_merah"],
			"chubby": 0.0,
			"hat": "toque",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Topi toque koki tinggi Prancis, celemek marun elegan bergaris emas, syal leher merah.",
		},
		"extra": {"anti_burn": 0.90},
	},
	"danu": {
		"id": "danu",
		"name": "Danu",
		"role": "baker",
		"tier": 4,
		"salary": 2200,
		"speed": 2.00,
		"perk": "90% peluang otomatis mengangkat roti matang",
		"profile": "Maestro roti sehat artisan; menguasai seni fermentasi ragi alami Sourdough dan olahan gandum utuh.",
		"visual": {
			"apron": Color(0.431, 0.122, 0.165),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "jenggot",
			"accessory": ["pisau_kayu"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.878, 0.659, 0.486),
			"note": "Jenggot koki terpangkas rapi, celemek marun pekat berkantong alat pisau roti kayu.",
		},
		"extra": {"anti_burn": 0.90},
	},
	"aoi": {
		"id": "aoi",
		"name": "Aoi",
		"role": "baker",
		"tier": 4,
		"salary": 2200,
		"speed": 2.00,
		"perk": "90% peluang otomatis mengangkat roti matang",
		"profile": "Perfeksionis asal Kyoto; mampu memanggang puluhan lembar krep tipis Matcha Mille Crepes tanpa cela.",
		"visual": {
			"apron": Color(0.431, 0.122, 0.165),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "pendek",
			"accessory": [],
			"chubby": 0.0,
			"hat": "hachimaki",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Bandana hachimaki hitam-putih khas chef Jepang, celemek marun, gerakan tangan presisi.",
		},
		"extra": {"anti_burn": 0.90},
	},
	"pierre": {
		"id": "pierre",
		"name": "Pierre",
		"role": "baker",
		"tier": 5,
		"salary": 5000,
		"speed": 2.80,
		"perk": "100% Anti-Gosong (Pasti ditata rapi ke etalase display)",
		"profile": "Maestro pastry dunia; roti buatannya mengembang selembut awan surga dan selalu ludes diburu pecinta roti.",
		"visual": {
			"apron": Color(0.831, 0.686, 0.216),
			"hair": Color(0.478, 0.306, 0.176),
			"hair_style": "pendek",
			"accessory": ["medali"],
			"chubby": 0.0,
			"hat": "toque",
			"skin": Color(0.980, 0.851, 0.737),
			"note": "Topi koki menjulang tinggi dengan sulaman benang emas, celemek emas koki agung, medali kuliner.",
		},
		"extra": {"anti_burn": 1.00},
	},
	"mawar": {
		"id": "mawar",
		"name": "Mawar",
		"role": "baker",
		"tier": 5,
		"salary": 5000,
		"speed": 2.80,
		"perk": "100% Anti-Gosong (Pasti ditata rapi ke etalase display)",
		"profile": "Nenek sakti pembawa buku resep rahasia keluarga; sentuhan tangannya 100% anti-gosong seumur hidup.",
		"visual": {
			"apron": Color(0.831, 0.686, 0.216),
			"hair": Color(0.788, 0.761, 0.729),
			"hair_style": "sanggul",
			"accessory": ["kacamata_rantai"],
			"chubby": 0.35,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Kacamata rantai emas vintage, celemek emas rajut berhias sulaman mawar merah, aura keibuan hangat.",
		},
		"extra": {"anti_burn": 1.00},
	},
	"alistair": {
		"id": "alistair",
		"name": "Alistair",
		"role": "baker",
		"tier": 5,
		"salary": 5000,
		"speed": 2.80,
		"perk": "100% Anti-Gosong (Pasti ditata rapi ke etalase display)",
		"profile": "Alkemis kuliner modern; spesialis mengolah jamur truffle dan butter artisan menjadi roti termahal di kota.",
		"visual": {
			"apron": Color(0.831, 0.686, 0.216),
			"hair": Color(0.169, 0.129, 0.094),
			"hair_style": "belah_samping",
			"accessory": ["sarung_tangan_satin"],
			"chubby": 0.0,
			"hat": "none",
			"skin": Color(0.949, 0.788, 0.627),
			"note": "Jas koki hitam beraksen emas mewah, sarung tangan satin putih, tatapan tajam visioner.",
		},
		"extra": {"anti_burn": 1.00},
	},
}


## Salinan data staf `id`; kembalikan `{}` bila ID tidak dikenal.
## Salinan dalam (deep copy) agar pemanggil bebas mengubah hasilnya.
static func entry(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var src: Dictionary = DATA[id]
	var out: Dictionary = src.duplicate(true)
	out["id"] = id
	return out


## Seluruh 30 ID staf: kasir dulu, lalu baker; masing-masing terurut menaik menurut tier.
static func ids() -> Array[String]:
	var out: Array[String] = ORDER_KASIR.duplicate()
	out.append_array(ORDER_BAKER)
	return out


## ID staf untuk satu peran (`kasir` / `baker`), terurut menaik menurut tier.
static func by_role(role: String) -> Array[String]:
	if role == ROLE_KASIR:
		return ORDER_KASIR.duplicate()
	if role == ROLE_BAKER:
		return ORDER_BAKER.duplicate()
	var kosong: Array[String] = []
	return kosong


## ID staf satu peran pada satu tier tertentu (1..5); selalu 3 kandidat per tier.
static func by_tier(role: String, tier: int) -> Array[String]:
	var out: Array[String] = []
	for id in by_role(role):
		var d: Dictionary = DATA[id]
		if int(d["tier"]) == tier:
			out.append(id)
	return out


## Warna celemek kanonik untuk kombinasi peran + tier (GDD 3.4).
## Tier di luar rentang diapit ke 1..5 agar tidak pernah keluar dari tabel.
static func apron_color(role: String, tier: int) -> Color:
	var t: int = clampi(tier, 1, 5)
	if role == ROLE_BAKER:
		return APRON_BAKER[t - 1]
	return APRON_KASIR[t - 1]


## Daftar kandidat yang muncul di bursa lowongan Manajemen Karyawan (GDD 3.4).
## Rekrutmen GRATIS dan tidak ada syarat tier lokasi untuk melamar; yang membatasi
## hanyalah jumlah slot staf (GDD 3.3) dan kesanggupan membayar gaji harian.
## Karena itu `unlocked_tier` tidak menyaring apa pun: seluruh kandidat peran
## tersebut dikembalikan, terurut menaik menurut tier.
@warning_ignore("unused_parameter")
static func roster(role: String, unlocked_tier: int) -> Array:
	var out: Array = []
	for id in by_role(role):
		out.append(id)
	return out


## Gaji harian (KR) untuk peran + tier, langsung dari tabel GDD 3.1 / 3.2.
static func salary_for(role: String, tier: int) -> int:
	var t: int = clampi(tier, 1, 5)
	if role == ROLE_BAKER:
		return BAKER_SALARY[t - 1]
	return KASIR_SALARY[t - 1]


## Kecepatan kerja: kasir = detik per pelanggan, baker = pengali kecepatan alat.
static func speed_for(role: String, tier: int) -> float:
	var t: int = clampi(tier, 1, 5)
	if role == ROLE_BAKER:
		return BAKER_SPEED[t - 1]
	return KASIR_SPEED[t - 1]


## Kemampuan khusus per tier: GDD 3.1 (kasir) atau proteksi gosong GDD 3.2 (baker).
static func perk_for(role: String, tier: int) -> String:
	var t: int = clampi(tier, 1, 5)
	if role == ROLE_BAKER:
		return BAKER_PERK[t - 1]
	return KASIR_PERK[t - 1]


## Peluang Proteksi Roti Gosong (Auto-Retrieve) baker, 0.0..1.0 (GDD 3.2).
static func anti_burn(tier: int) -> float:
	return BAKER_ANTI_BURN[clampi(tier, 1, 5) - 1]
