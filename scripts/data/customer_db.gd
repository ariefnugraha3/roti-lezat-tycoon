class_name CustomerDB
extends RefCounted

## Basis data arketipe pelanggan (GDD "Perilaku Konsumen" dan GDD 3.6).
##
## GDD menulis perilaku pelanggan secara kualitatif, bukan sebagai tabel angka.
## Karena itu setiap entri di bawah diberi komentar yang menjelaskan dari kalimat
## GDD mana angkanya diturunkan. Angka yang MEMANG tertulis di GDD (5-15 roti,
## jam 08:00-10:00, kasir 2x lebih lama, tip +10%..+25%, driver menunggu >10 detik,
## instant handover <3 detik, preparation timer 60-90 detik) disalin persis.
##
## Arti tiap kunci:
## - `patience`      : detik maksimum pelanggan mau menunggu di antrean sebelum kabur.
## - `budget_factor` : pengali harga satuan default resep yang masih diterima pelanggan.
##                     Harga di atas `budget_factor * RecipeDB.unit_price_default(id)`
##                     membuat pelanggan mengeluh / batal membeli.
## - `bulk_min/max`  : jumlah roti yang dibeli dalam satu transaksi.
## - `prefers`       : ID resep yang paling dicari (ID kanonik ARCHITECTURE 2.2).
## - `peak_hours`    : daftar Vector2i(jam_mulai, jam_selesai) in-game, inklusif di
##                     kedua ujung. Kosong berarti tidak punya jam sibuk khusus.
## - `min_recipe_tier`: tier resep minimum yang bersedia dibeli.
## - `min_store_tier` : tier lokasi toko minimum agar arketipe ini muncul.
## - `rating_impact` : besar perubahan rating toko per interaksi (positif saat
##                     dilayani baik, negatif saat kecewa).
## - `rating_delay_days`: 0 = berlaku hari itu juga, 1 = berlaku keesokan harinya.
## - `cashier_time_mult`: pengali waktu proses di kasir.
## - `spawn_weight`  : bobot dasar kemunculan (sebelum dikalikan faktor jam sibuk).
## - `pickup_window` : detik toleransi penjemputan, hanya relevan untuk driver ojol.
## - `refuse_quality`: kualitas roti yang ditolak mentah-mentah oleh pelanggan ini.
## - `walk_in`       : true untuk pembeli fisik yang memilih roti di rak display.

## Pengali bobot kemunculan saat jam sibuk arketipe tersebut.
## Diturunkan dari GDD: pekerja kantoran "membludak di jam sibuk pagi hari" dan anak
## sekolah "datang beramai-ramai di sore hari" — jam puncak jauh lebih padat dari jam biasa.
const PEAK_MULT := 3.0

## Pengali bobot kemunculan di luar jam sibuk bagi arketipe yang punya jam puncak.
## Mereka tetap bisa datang, hanya jauh lebih jarang.
const OFFPEAK_MULT := 0.45

## Batas waktu "Instant Handover" driver ojol (GDD 3.6.C: waktu tunggu driver < 3 detik).
const INSTANT_HANDOVER_SEC := 3.0

## Ambang keterlambatan yang menurunkan rating RotiFood (GDD 9.2: driver menunggu >10 detik).
const DRIVER_WAIT_PENALTY_SEC := 10.0

## Rentang tip Instant Handover dalam pecahan nilai pesanan (GDD 3.6.C: +10% hingga +25% KR).
const TIP_MIN := 0.10
const TIP_MAX := 0.25

const _DATA := {
	# Anak Sekolah (The Sweet Tooth) — GDD "Perilaku Konsumen", Kategori Reguler.
	# "Kesabarannya tinggi (mau antre)" -> patience 70 detik, tertinggi kedua setelah emak arisan.
	# "uang saku terbatas sehingga akan mengeluh jika harga terlalu mahal" -> budget_factor 1.00,
	#   yaitu hanya menerima sampai harga satuan default resep; di atas itu mengeluh.
	#   (Sweet spot RecipeDB membentang 0.85x..1.25x, jadi anak sekolah mulai protes
	#   di paruh atas sweet spot — arketipe paling sensitif harga.)
	# "Mencari roti manis (Donat, Roti Cokelat)" -> prefers diisi resep manis Tier 1-2.
	# "datang beramai-ramai di sore hari sepulang sekolah" -> puncak 13:00-16:00.
	# Uang saku kecil -> beli 1-2 buah saja (bulk 1..2, sesuai brief tugas).
	"anak_sekolah": {
		"id": "anak_sekolah",
		"name": "Anak Sekolah",
		"patience": 70.0,
		"budget_factor": 1.00,
		"bulk_min": 1,
		"bulk_max": 2,
		"prefers": ["donat_gula", "roti_cokelat", "donat_selai_stroberi", "roti_keju_manis", "roti_goreng_polos"],
		"peak_hours": [Vector2i(13, 16)],
		"min_recipe_tier": 1,
		"min_store_tier": 1,
		"rating_impact": 0.01,
		"rating_delay_days": 0,
		"cashier_time_mult": 1.0,
		"spawn_weight": 0.28,
		"pickup_window": 0.0,
		"refuse_quality": ["mentah", "gosong"],
		"walk_in": true,
		"desc": "Kesabarannya tinggi (mau antre), namun uang saku terbatas sehingga akan mengeluh jika harga terlalu mahal. Mencari roti manis (Donat, Roti Cokelat) dan biasanya datang beramai-ramai di sore hari sepulang sekolah."
	},

	# Pekerja Kantoran (The Rush Hour) — GDD "Perilaku Konsumen", Kategori Reguler.
	# "Kesabaran sangat rendah. Jika antrean kasir terlalu panjang, mereka akan menggerutu,
	#   berbalik pergi, dan menurunkan rating toko" -> patience 18 detik (paling pendek di
	#   antara pembeli fisik) dan rating_impact 0.03 (tiga kali anak sekolah, dua arah).
	# "Mencari roti praktis (Croissant, Roti Sosis)" -> prefers roti sarapan cepat.
	# "membludak di jam sibuk pagi hari (08:00 - 10:00)" -> puncak Vector2i(8, 10) persis GDD.
	# Buru-buru, beli sarapan untuk diri sendiri -> bulk 1..2 (sesuai brief tugas).
	# Tidak sensitif harga tapi juga tidak boros -> budget_factor 1.25, yaitu batas atas
	#   sweet spot RecipeDB; mereka membayar harga premium demi kepraktisan.
	"pekerja_kantoran": {
		"id": "pekerja_kantoran",
		"name": "Pekerja Kantoran",
		"patience": 18.0,
		"budget_factor": 1.25,
		"bulk_min": 1,
		"bulk_max": 2,
		"prefers": ["croissant_klasik", "roti_sosis_gulung", "baguette_klasik", "roti_cokelat", "pain_au_chocolat"],
		"peak_hours": [Vector2i(8, 10)],
		"min_recipe_tier": 1,
		"min_store_tier": 1,
		"rating_impact": 0.03,
		"rating_delay_days": 0,
		"cashier_time_mult": 1.0,
		"spawn_weight": 0.26,
		"pickup_window": 0.0,
		"refuse_quality": ["mentah", "gosong"],
		"walk_in": true,
		"desc": "Kesabaran sangat rendah. Jika antrean kasir terlalu panjang, mereka akan menggerutu, berbalik pergi, dan menurunkan rating toko. Mencari roti praktis (Croissant, Roti Sosis) dan membludak di jam sibuk pagi hari (08:00 - 10:00)."
	},

	# Emak-Emak Arisan (The Bulk Buyer) — GDD "Perilaku Konsumen", Kategori Reguler.
	# "Membeli dalam jumlah sangat banyak sekaligus (5 - 15 roti)" -> bulk_min 5, bulk_max 15
	#   (angka persis dari GDD "Perilaku Konsumen").
	# CATATAN INKONSISTENSI GDD: GDD 8.2 butir 3 menulis pelanggan borongan "memborong
	#   5-10 roti sekaligus", berbeda dari 5-15 di seksi Perilaku Konsumen. Yang dipakai
	#   di sini adalah 5-15 sesuai kontrak ARCHITECTURE bagian CustomerDB.
	# Rela menunggu demi borongan untuk acara arisan -> patience 90 detik, tertinggi.
	# Ibu rumah tangga yang pandai berhitung -> budget_factor 1.10, sedikit di atas harga
	#   default tapi jauh di bawah toleransi pelanggan premium.
	# GDD tidak menyebut jam puncak; arisan lazim digelar sesudah urusan pagi selesai,
	#   jadi puncak ditetapkan 10:00-13:00. Bobot 0.16 karena satu kedatangan sudah
	#   menyedot 5-15 roti ("berisiko menguras habis seluruh stok etalase dalam sekejap").
	"emak_arisan": {
		"id": "emak_arisan",
		"name": "Emak-Emak Arisan",
		"patience": 90.0,
		"budget_factor": 1.10,
		"bulk_min": 5,
		"bulk_max": 15,
		"prefers": ["roti_sobek_susu", "roti_tawar_polos", "roti_keju_manis", "donat_gula", "danish_cheese_pastry"],
		"peak_hours": [Vector2i(10, 13)],
		"min_recipe_tier": 1,
		"min_store_tier": 1,
		"rating_impact": 0.02,
		"rating_delay_days": 0,
		"cashier_time_mult": 1.0,
		"spawn_weight": 0.16,
		"pickup_window": 0.0,
		"refuse_quality": ["mentah", "gosong"],
		"walk_in": true,
		"desc": "Membeli dalam jumlah sangat banyak sekaligus (5 - 15 roti). Sangat menguntungkan untuk profit cepat, tetapi berisiko menguras habis seluruh stok etalase dalam sekejap, membuat pelanggan di belakangnya terancam tidak kebagian."
	},

	# Sosialita / Crazy Rich (The Snob) — GDD "Perilaku Konsumen", Kategori Premium & Spesial.
	# "Tidak memedulikan harga mahal" -> budget_factor 5.00 (praktis tanpa batas atas).
	# "menuntut roti kualitas sempurna (Resep Tier 3 ke atas)" -> min_recipe_tier 3.
	# "Menolak membeli roti berkualitas rendah, mendekati dingin, atau yang hampir gosong"
	#   -> refuse_quality memuat dingin, hampir_gosong, gosong, dan mentah.
	# "Muncul di Tier Toko Tertinggi" -> min_store_tier 3, yakni tier lokasi pertama tempat
	#   resep Tier 3 bisa dibeli; GDD 5.3.3 memang mencantumkan "The Snob" sebagai target
	#   seluruh resep Tier 3, jadi ia harus sudah bisa hadir di toko Tier 3.
	# Terbiasa dilayani cepat, tapi tidak seterburu-buru pekerja kantoran -> patience 30 detik.
	# Belanja butik, bukan borongan -> bulk 1..3. Suaranya didengar orang -> rating_impact 0.05.
	"sosialita": {
		"id": "sosialita",
		"name": "Sosialita",
		"patience": 30.0,
		"budget_factor": 5.00,
		"bulk_min": 1,
		"bulk_max": 3,
		"prefers": ["croissant_klasik", "pain_au_chocolat", "danish_cheese_pastry", "brioche_gourmet", "basque_burnt_cheese_bun", "truffle_mushroom_bun", "almond_croissant_mewah", "premium_cream_cheese_danish"],
		"peak_hours": [Vector2i(14, 17)],
		"min_recipe_tier": 3,
		"min_store_tier": 3,
		"rating_impact": 0.05,
		"rating_delay_days": 0,
		"cashier_time_mult": 1.0,
		"spawn_weight": 0.08,
		"pickup_window": 0.0,
		"refuse_quality": ["mentah", "dingin", "hampir_gosong", "gosong"],
		"walk_in": true,
		"desc": "Tidak memedulikan harga mahal, tetapi menuntut roti kualitas sempurna (Resep Tier 3 ke atas). Menolak membeli roti berkualitas rendah, mendekati dingin, atau yang hampir gosong."
	},

	# Si Galau (The Indecisive) — GDD "Perilaku Konsumen", Kategori Premium & Spesial.
	# "Membutuhkan waktu proses di kasir 2x lebih lama dari pelanggan biasa"
	#   -> cashier_time_mult 2.0 (angka persis dari GDD).
	# Dia sendiri tidak terburu-buru, justru antrean di belakangnya yang marah
	#   -> patience 60 detik, sementara tekanan antrean ditangani CustomerSim.
	# "kebingungan memilih menu" -> prefers dikosongkan: ia mengambil apa saja dari display.
	# Tidak ada jam puncak yang disebut GDD -> peak_hours kosong, muncul merata sepanjang hari.
	# Selera dan dompet rata-rata -> budget_factor 1.15, bulk 1..2, rating_impact 0.01.
	"si_galau": {
		"id": "si_galau",
		"name": "Si Galau",
		"patience": 60.0,
		"budget_factor": 1.15,
		"bulk_min": 1,
		"bulk_max": 2,
		"prefers": [],
		"peak_hours": [],
		"min_recipe_tier": 1,
		"min_store_tier": 1,
		"rating_impact": 0.01,
		"rating_delay_days": 0,
		"cashier_time_mult": 2.0,
		"spawn_weight": 0.10,
		"pickup_window": 0.0,
		"refuse_quality": ["mentah", "gosong"],
		"walk_in": true,
		"desc": "Membutuhkan waktu proses di kasir 2x lebih lama dari pelanggan biasa karena kebingungan memilih menu. Menuntut pemain atau Asisten Kasir bekerja ekstra agar pelanggan di belakangnya tidak marah karena antrean macet."
	},

	# Food Vlogger / Kritikus (The VIP Critic) — GDD "Perilaku Konsumen", Kategori Premium & Spesial.
	# "Pelanggan langka" -> spawn_weight 0.02, terkecil di antara pembeli fisik.
	# "Jika pelayanannya cepat dan rotinya berkualitas prima, rating toko akan melonjak
	#   drastis keesokan harinya. Namun jika ia kecewa, reputasi toko bisa anjlok tajam."
	#   -> rating_impact 0.60 (jauh di atas arketipe lain, berlaku dua arah) dan
	#      rating_delay_days 1 karena efeknya muncul "keesokan harinya".
	# Menilai roti kelas atas -> min_recipe_tier 3 dan prefers diisi resep Tier 3-5 yang
	#   GDD 5.3.3-5.3.5 sebut menargetkan Food Vlogger.
	# Merekam sambil menunggu, tapi menilai kecepatan pelayanan -> patience 45 detik.
	# Mencicipi beberapa varian untuk konten -> bulk 1..3. Tidak sensitif harga -> 3.00.
	# GDD 8.2 Tier 4 menaikkan peluang kedatangannya +40%, artinya ia sudah bisa muncul
	#   sebelum lokasi Tier 4; gerbangnya disamakan dengan sosialita di Tier 3.
	"food_vlogger": {
		"id": "food_vlogger",
		"name": "Food Vlogger",
		"patience": 45.0,
		"budget_factor": 3.00,
		"bulk_min": 1,
		"bulk_max": 3,
		"prefers": ["pain_au_chocolat", "croissant_artisan_almond", "matcha_sweet_brioche", "basque_burnt_cheese_bun", "matcha_mille_crepes", "almond_croissant_mewah", "roti_emas_artisan"],
		"peak_hours": [Vector2i(11, 14)],
		"min_recipe_tier": 3,
		"min_store_tier": 3,
		"rating_impact": 0.60,
		"rating_delay_days": 1,
		"cashier_time_mult": 1.0,
		"spawn_weight": 0.02,
		"pickup_window": 0.0,
		"refuse_quality": ["mentah", "hampir_gosong", "gosong"],
		"walk_in": true,
		"desc": "Pelanggan langka dengan kamera kecil. Jika pelayanannya cepat dan rotinya berkualitas prima, rating toko akan melonjak drastis keesokan harinya. Namun jika ia kecewa, reputasi toko bisa anjlok tajam."
	},

	# Driver Ojek Online (The Delivery Runner) — GDD "Perilaku Konsumen" + GDD 3.6.
	# BUKAN pembeli fisik: "Driver ojol tidak berkeliling memilih roti di rak etalase"
	#   -> walk_in false dan spawn_weight 0.0. Kedatangannya diatur DeliverySim mengikuti
	#      arus pesanan RotiFood, bukan bobot kemunculan pejalan kaki.
	# "Memiliki batas toleransi waktu penjemputan (Pickup Window)" -> pickup_window 90 detik,
	#   yaitu batas atas Preparation Timer GDD 3.6.A ("misal: 60 - 90 detik").
	# GDD 9.2: driver menunggu >10 detik menurunkan rating RotiFood, pesanan batal -0.2
	#   -> patience 30 detik untuk berdiri di antrean serah terima sebelum pergi kecewa;
	#      ambang 3 detik (instant handover) dan 10 detik (penalti) tersedia sebagai
	#      konstanta INSTANT_HANDOVER_SEC dan DRIVER_WAIT_PENALTY_SEC di atas.
	# Harga sudah dikunci aplikasi, driver hanya menjemput -> budget_factor 1.00,
	#   bulk 1..1 (satu paket per pesanan; isi paket ditentukan order DeliverySim),
	#   rating_impact 0.0 karena ia memengaruhi rating RotiFood, bukan rating toko fisik.
	"driver_ojol": {
		"id": "driver_ojol",
		"name": "Driver Ojek Online",
		"patience": 30.0,
		"budget_factor": 1.00,
		"bulk_min": 1,
		"bulk_max": 1,
		"prefers": [],
		"peak_hours": [],
		"min_recipe_tier": 1,
		"min_store_tier": 1,
		"rating_impact": 0.0,
		"rating_delay_days": 0,
		"cashier_time_mult": 1.0,
		"spawn_weight": 0.0,
		"pickup_window": 90.0,
		"refuse_quality": [],
		"walk_in": false,
		"desc": "Mitra kurir pengantaran makanan bersepeda motor dengan seragam hijau toska pastel (#4EBA6F), helm bundar menggemaskan, dan ransel termal kubus di punggung. Driver ojol tidak berkeliling memilih roti di rak etalase; mereka langsung menuju kasir atau Meja Khusus Ojol untuk mengambil paket pesanan aplikasi yang sudah dikemas rapi (paper bag)."
	}
}


## Kembalikan salinan data arketipe `id`, atau `{}` bila ID tidak dikenal.
static func entry(id: String) -> Dictionary:
	if not _DATA.has(id):
		return {}
	var d: Dictionary = _DATA[id]
	return d.duplicate(true)


## Seluruh ID pelanggan kanonik, termasuk driver ojol.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _DATA.keys():
		out.append(id)
	return out


## ID pembeli fisik saja (driver ojol dikecualikan).
static func walk_in_ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _DATA.keys():
		var d: Dictionary = _DATA[id]
		var walk_in: bool = d["walk_in"]
		if walk_in:
			out.append(id)
	return out


## Benar bila `hour` (jam in-game, boleh pecahan) berada di dalam salah satu jam puncak
## arketipe `id`. Arketipe tanpa jam puncak selalu mengembalikan false.
static func is_peak(id: String, hour: float) -> bool:
	if not _DATA.has(id):
		return false
	var d: Dictionary = _DATA[id]
	return _in_peak(d["peak_hours"], hour)


## Bobot kemunculan pembeli fisik yang sudah dinormalisasi (total = 1.0) untuk jam
## `hour` dan tier lokasi `location_tier`.
##
## Aturan:
## - Driver ojol tidak pernah ikut: ia dijadwalkan DeliverySim, bukan arus pejalan kaki.
## - Arketipe dengan `min_store_tier` di atas tier lokasi disaring (sosialita & food vlogger
##   hanya muncul di toko tier tinggi, GDD "Kategori Premium & Spesial").
## - Arketipe yang punya jam puncak dikalikan PEAK_MULT di dalam jamnya dan OFFPEAK_MULT
##   di luar jamnya; arketipe tanpa jam puncak memakai bobot dasarnya apa adanya.
##
## Mengembalikan `{}` bila tidak ada arketipe yang memenuhi syarat.
static func weights_for(hour: float, location_tier: int) -> Dictionary:
	var raw: Dictionary = {}
	var total: float = 0.0
	for id: String in _DATA.keys():
		var d: Dictionary = _DATA[id]
		var walk_in: bool = d["walk_in"]
		if not walk_in:
			continue
		if location_tier < int(d["min_store_tier"]):
			continue
		var w: float = float(d["spawn_weight"])
		if w <= 0.0:
			continue
		var peaks: Array = d["peak_hours"]
		if not peaks.is_empty():
			if _in_peak(peaks, hour):
				w *= PEAK_MULT
			else:
				w *= OFFPEAK_MULT
		raw[id] = w
		total += w
	if total <= 0.0:
		return {}
	var out: Dictionary = {}
	for id: String in raw.keys():
		out[id] = float(raw[id]) / total
	return out


## Pilih satu ID pembeli fisik secara acak memakai bobot `weights_for()`.
## Mengembalikan "" bila tidak ada kandidat.
static func pick(rng: RandomNumberGenerator, hour: float, location_tier: int) -> String:
	if rng == null:
		return ""
	var weights: Dictionary = weights_for(hour, location_tier)
	if weights.is_empty():
		return ""
	var roll_value: float = rng.randf()
	var acc: float = 0.0
	var last: String = ""
	for id: String in weights.keys():
		last = id
		acc += float(weights[id])
		if roll_value < acc:
			return id
	return last


## Jumlah roti yang dibeli arketipe `id` dalam satu transaksi.
static func bulk_size(id: String, rng: RandomNumberGenerator) -> int:
	if not _DATA.has(id):
		return 0
	var d: Dictionary = _DATA[id]
	var lo: int = int(d["bulk_min"])
	var hi: int = int(d["bulk_max"])
	if rng == null or hi <= lo:
		return lo
	return rng.randi_range(lo, hi)


## Benar bila pelanggan `id` bersedia membeli roti berkualitas `quality`.
## Kualitas memakai enum string ARCHITECTURE 2.5.
static func accepts_quality(id: String, quality: String) -> bool:
	if not _DATA.has(id):
		return false
	var d: Dictionary = _DATA[id]
	var refused: Array = d["refuse_quality"]
	return not refused.has(quality)


## Benar bila pelanggan `id` bersedia membeli resep bertier `recipe_tier`.
static func accepts_recipe_tier(id: String, recipe_tier: int) -> bool:
	if not _DATA.has(id):
		return false
	var d: Dictionary = _DATA[id]
	return recipe_tier >= int(d["min_recipe_tier"])


## Harga satuan tertinggi yang masih diterima pelanggan `id`, dihitung dari harga
## satuan default resep (`RecipeDB.unit_price_default`). Di atas angka ini pelanggan
## mengeluh dan batal membeli.
static func price_ceiling(id: String, base_unit_price: float) -> float:
	if not _DATA.has(id):
		return base_unit_price
	var d: Dictionary = _DATA[id]
	return base_unit_price * float(d["budget_factor"])


## Detik toleransi penjemputan driver ojol (0.0 untuk pembeli fisik).
static func pickup_window(id: String) -> float:
	if not _DATA.has(id):
		return 0.0
	var d: Dictionary = _DATA[id]
	return float(d["pickup_window"])


static func _in_peak(peaks: Array, hour: float) -> bool:
	for p: Vector2i in peaks:
		if hour >= float(p.x) and hour <= float(p.y):
			return true
	return false
