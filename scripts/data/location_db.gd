class_name LocationDB
extends RefCounted

## Basis data lokasi/toko lima tingkatan, GDD 6 (tabel ringkasan + Rincian Progresi Lokasi),
## GDD 3.3 (batas kapasitas staf), dan GDD 5.2.2 (kapasitas gudang).
##
## `pantry_cap` + `storage_name` adalah Gudang Penyimpanan: satu perabot kulkas
## dan lemari bahan yang menyatu, dan yang ikut tier lokasi alih-alih dibeli
## terpisah di Pasar.
##
## Properti dibeli putus (hak milik): TIDAK ada biaya sewa harian sama sekali.
## Beban harian toko murni utilitas + gaji karyawan.

const MIN_TIER: int = 1
const MAX_TIER: int = 5

## Tier lokasi minimum yang membuka Meja Khusus Ojol (Pickup Counter), GDD 3.6.B.
const PICKUP_COUNTER_MIN_TIER: int = 3

const DATA: Dictionary = {
	1: {
		"name": "Garasi Rumah",
		"price": 0,
		"mixer_slots": 1,
		"oven_slots": 1,
		"rack_slots": 1,
		"cashier_slots": 1,
		"max_kasir": 1,
		"max_baker": 1,
		"queue_cap": 4,
		"pantry_cap": 150,
		"storage_name": "Kulkas Bekas & Rak Kayu",
		"desc": "Usaha rintisan di garasi rumah sendiri. Area dapur dan rak display menyatu tanpa sekat.",
		"targets": ["Tetangga", "Anak-anak sekitar"],
	},
	2: {
		"name": "Ruko 1 Pintu",
		"price": 15000,
		"mixer_slots": 2,
		"oven_slots": 2,
		"rack_slots": 2,
		"cashier_slots": 1,
		"max_kasir": 1,
		"max_baker": 2,
		"queue_cap": 8,
		"pantry_cap": 400,
		"storage_name": "Kulkas Dua Pintu & Lemari Bahan",
		"desc": "Ruko komersial pinggir jalan dengan sekat pemisah antara dapur dan area display pembeli.",
		"targets": ["Pejalan kaki", "Ibu-ibu belanja", "Anak sekolah"],
	},
	3: {
		"name": "Toko Bakery Mandiri",
		"price": 55000,
		"mixer_slots": 3,
		"oven_slots": 3,
		"rack_slots": 3,
		"cashier_slots": 2,
		"max_kasir": 2,
		"max_baker": 2,
		"queue_cap": 14,
		"pantry_cap": 1000,
		"storage_name": "Chiller Tegak & Lemari Stainless",
		"desc": "Toko bakery tersendiri dengan tata ruang luas yang mampu membuka 2 jalur kasir bersamaan untuk memecah antrean.",
		"targets": ["Pekerja kantoran", "Mahasiswa", "Rombongan keluarga"],
	},
	4: {
		# GDD 6 "Rincian Progresi Lokasi" menulis "Premium Flagship Store";
		# tabel ringkasan GDD 6 dan GDD 3.3 menulis "Flagship Store" — dipakai sebagai nama kanonik.
		"name": "Flagship Store",
		"price": 180000,
		"mixer_slots": 4,
		"oven_slots": 4,
		"rack_slots": 4,
		"cashier_slots": 2,
		"max_kasir": 2,
		"max_baker": 3,
		"queue_cap": 20,
		"pantry_cap": 2500,
		"storage_name": "Chiller Ganda & Lemari Bahan Segar",
		"desc": "Toko mewah di kawasan bisnis/pusat kota dengan dapur open-kitchen dan display berpendingin/penghangat canggih.",
		"targets": ["Sosialita", "Eksekutif", "Pencinta roti artisan"],
	},
	5: {
		"name": "Mega Bakery Landmark",
		"price": 600000,
		"mixer_slots": 5,
		"oven_slots": 5,
		"rack_slots": 6,
		"cashier_slots": 3,
		"max_kasir": 3,
		"max_baker": 4,
		# GDD 6 menulis "35+ Pembeli"; angka pasti yang dipakai = 35.
		"queue_cap": 35,
		# GDD 5.2.2 menulis "6.000+ Unit Bahan Total"; angka pasti yang dipakai = 6000.
		"pantry_cap": 6000,
		"storage_name": "Cold Room & Rak Gudang Industri",
		"desc": "Supermarket roti raksasa berstandar industri dengan 3 kasir otomatis dan kapasitas produksi masif.",
		"targets": ["Seluruh kalangan kota", "Katering/pesanan event besar", "Wisatawan kuliner"],
	},
}


## Kembalikan salinan data satu lokasi. Dictionary kosong bila tier tidak sah.
static func entry(tier: int) -> Dictionary:
	if not DATA.has(tier):
		return {}
	var src: Dictionary = DATA[tier]
	var out: Dictionary = src.duplicate(true)
	out["tier"] = tier
	return out


## Seluruh tier lokasi sebagai String, memenuhi kontrak data layer.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for tier: int in DATA:
		out.append(str(tier))
	return out


## Daftar tier lokasi sebagai int (1..5).
static func tiers() -> Array[int]:
	var out: Array[int] = []
	for tier: int in DATA:
		out.append(tier)
	return out


## Ambil satu kolom int dari data lokasi. `fallback` bila tier tidak sah.
static func _field_int(tier: int, key: String, fallback: int) -> int:
	if not DATA.has(tier):
		return fallback
	var src: Dictionary = DATA[tier]
	return int(src[key])


## Nama lokasi. String kosong bila tier tidak sah.
static func display_name(tier: int) -> String:
	if not DATA.has(tier):
		return ""
	var src: Dictionary = DATA[tier]
	return String(src["name"])


## Harga beli putus lokasi dalam KR (Tier 1 gratis, bawaan awal game).
static func price(tier: int) -> int:
	return _field_int(tier, "price", 0)


## Jumlah slot mixer di dapur.
static func mixer_slots(tier: int) -> int:
	return _field_int(tier, "mixer_slots", 0)


## Jumlah slot oven di dapur.
static func oven_slots(tier: int) -> int:
	return _field_int(tier, "oven_slots", 0)


## Jumlah rak display yang tersedia.
static func rack_slots(tier: int) -> int:
	return _field_int(tier, "rack_slots", 0)


## Jumlah meja kasir fisik.
static func cashier_slots(tier: int) -> int:
	return _field_int(tier, "cashier_slots", 0)


## Batas maksimum staf untuk satu peran ("kasir" | "baker"), GDD 3.3.
static func max_staff(tier: int, role: String) -> int:
	if role == "kasir":
		return _field_int(tier, "max_kasir", 0)
	if role == "baker":
		return _field_int(tier, "max_baker", 0)
	return 0


## Kapasitas antrean pelanggan fisik di toko.
static func queue_cap(tier: int) -> int:
	return _field_int(tier, "queue_cap", 0)


## Kapasitas gudang bahan baku (total unit), GDD 5.2.2.
static func pantry_cap(tier: int) -> int:
	return _field_int(tier, "pantry_cap", 0)


## Nama perabot Gudang Penyimpanan (kulkas + lemari bahan yang menyatu).
##
## Gudang TIDAK dibeli di Pasar seperti mixer/oven/rak — ia sepaket dengan
## bangunan, jadi namanya, bentuknya, dan kapasitasnya semua ikut tier LOKASI
## (GDD 5.2.2). Karena itu namanya tinggal di sini, bukan di EquipmentDB yang
## isinya alat-alat yang bisa di-upgrade sendiri.
static func storage_name(tier: int) -> String:
	if not DATA.has(tier):
		return ""
	var src: Dictionary = DATA[tier]
	return String(src["storage_name"])


## Apakah lokasi punya Meja Khusus Ojol terpisah dari kasir reguler (GDD 3.6.B).
## Tier 1-2: driver ojol ikut mengantre di kasir utama.
static func has_pickup_counter(tier: int) -> bool:
	return tier >= PICKUP_COUNTER_MIN_TIER


## Total kapasitas roti di seluruh rak display: jumlah rak x kapasitas per rak.
## Sesuai GDD 6 bila tier display = tier lokasi: 50 / 200 / 600 / 1.400 / 3.600 roti.
static func display_capacity(loc_tier: int, display_tier: int) -> int:
	return rack_slots(loc_tier) * EquipmentDB.rack_capacity(display_tier)


## Tier lokasi berikutnya yang bisa dibeli, atau 0 bila sudah maksimum.
static func next_tier(tier: int) -> int:
	if tier >= MAX_TIER:
		return 0
	return tier + 1
