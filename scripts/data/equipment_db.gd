class_name EquipmentDB
extends RefCounted

## Basis data peralatan dapur (mixer / oven / display) lima tingkatan, GDD 5.1.
## Nama kanonik diambil dari GDD 5.1. Bila GDD 5.3.4 / 5.3.5 menyebut nama lain
## untuk alat yang sama, nama itu disimpan pada `alt_name`.
##
## Arti kolom `value` berbeda per jenis alat:
##   mixer   -> lama proses aduk (detik)
##   oven    -> lama panggang (detik)
##   display -> kapasitas roti PER RAK (buah)

const KIND_MIXER: String = "mixer"
const KIND_OVEN: String = "oven"
const KIND_DISPLAY: String = "display"

## Urutan jenis alat untuk tampilan menu Pasar.
const KINDS: Array[String] = [KIND_MIXER, KIND_OVEN, KIND_DISPLAY]

const MIN_TIER: int = 1
const MAX_TIER: int = 5

const DATA: Dictionary = {
	# --- Mixer: value = detik proses aduk ---
	"mixer": {
		1: {
			"name": "Mangkuk Kayu & Pengocok Manual",
			"alt_name": "",
			"price": 0,
			"value": 20,
			"desc": "Peralatan bawaan garasi: diaduk manual dengan tenaga tangan.",
		},
		2: {
			"name": "Stand Mixer Elektrik Murah",
			"alt_name": "",
			"price": 1500,
			"value": 15,
			"desc": "Mixer listrik sederhana, adonan lebih mulus dan cepat terbentuk.",
		},
		3: {
			"name": "Heavy Duty Stand Mixer",
			"alt_name": "",
			"price": 4500,
			"value": 10,
			"desc": "Motor kuat untuk adonan berat, menghasilkan adonan elastis sempurna.",
		},
		4: {
			"name": "Industrial Dough Kneader",
			"alt_name": "",
			"price": 12000,
			"value": 6,
			"desc": "Pengulen skala industri, tekstur adonan sangat elastis mengkilap.",
		},
		5: {
			"name": "Automated Mixing Robot",
			# GDD 5.3.5 menyebut mixer Tier 5 sebagai "Planetary Industrial";
			# GDD 5.1 tetap kanonik untuk `name`.
			"alt_name": "Planetary Industrial",
			"price": 35000,
			"value": 3,
			"desc": "Robot pengaduk kapasitas jumbo, menguleni banyak adonan sekaligus.",
		},
	},

	# --- Oven: value = detik panggang ---
	"oven": {
		1: {
			"name": "Oven Tangkring Tua",
			"alt_name": "",
			"price": 0,
			"value": 30,
			"desc": "Oven tangkring jadul di atas kompor, panasnya lambat merata.",
		},
		2: {
			"name": "Oven Listrik Mini",
			"alt_name": "",
			"price": 2000,
			"value": 22,
			"desc": "Oven listrik mungil untuk ruko, panas lebih stabil.",
		},
		3: {
			"name": "Deck Oven 2 Tray",
			"alt_name": "",
			"price": 6000,
			"value": 15,
			"desc": "Dua loyang masuk sekaligus, efisiensi produksi 2x.",
		},
		4: {
			"name": "Convection Oven Besar",
			# GDD 5.3.4 menyebut oven Tier 4 sebagai "Rotary Rack Oven";
			# GDD 5.1 tetap kanonik untuk `name`.
			"alt_name": "Rotary Rack Oven",
			"price": 15000,
			"value": 10,
			"desc": "Oven konveksi besar, loyang berputar perlahan agar matang merata.",
		},
		5: {
			"name": "Conveyor Belt Oven",
			"alt_name": "",
			"price": 50000,
			"value": 5,
			"desc": "Loyang berjalan otomatis masuk-keluar oven tanpa henti.",
		},
	},

	# --- Display: value = kapasitas roti PER RAK ---
	"display": {
		1: {
			"name": "Keranjang Bambu Terbuka",
			"alt_name": "",
			"price": 0,
			"value": 50,
			"desc": "Keranjang bambu terbuka beralas kain gingham.",
		},
		2: {
			"name": "Etalase Kaca Sederhana",
			"alt_name": "",
			"price": 1500,
			"value": 100,
			"desc": "Etalase kaca berbingkai kayu pinus, roti terlindung debu.",
		},
		3: {
			"name": "Showcase Kaca dengan Lampu Penghangat",
			"alt_name": "",
			"price": 4500,
			"value": 200,
			"desc": "Lampu penghangat menjaga roti tetap hangat lebih lama.",
		},
		4: {
			"name": "Smart Temperature Showcase",
			"alt_name": "",
			"price": 12000,
			"value": 350,
			"desc": "Showcase berpendingin/penghangat cerdas dengan kontrol suhu.",
		},
		5: {
			"name": "Premium Auto-Dispenser Showcase",
			"alt_name": "",
			"price": 30000,
			"value": 600,
			"desc": "Showcase raksasa dengan dispenser otomatis skala supermarket.",
		},
	},
}


## Kembalikan salinan data satu alat. Dictionary kosong bila jenis/tier tidak sah.
static func entry(kind: String, tier: int) -> Dictionary:
	if not DATA.has(kind):
		return {}
	var per_tier: Dictionary = DATA[kind]
	if not per_tier.has(tier):
		return {}
	var src: Dictionary = per_tier[tier]
	var out: Dictionary = src.duplicate(true)
	out["kind"] = kind
	out["tier"] = tier
	return out


## Seluruh jenis alat yang dikenal.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for kind: String in DATA:
		out.append(kind)
	return out


## Daftar tier yang tersedia (1..5).
static func tiers() -> Array[int]:
	var out: Array[int] = []
	for t: int in range(MIN_TIER, MAX_TIER + 1):
		out.append(t)
	return out


## Harga beli alat dalam KR. 0 bila jenis/tier tidak sah (Tier 1 memang gratis).
static func price(kind: String, tier: int) -> int:
	var e: Dictionary = entry(kind, tier)
	if e.is_empty():
		return 0
	return int(e["price"])


## Nama kanonik alat (GDD 5.1). String kosong bila tidak sah.
static func display_name(kind: String, tier: int) -> String:
	var e: Dictionary = entry(kind, tier)
	if e.is_empty():
		return ""
	return String(e["name"])


## Nilai mentah kolom `value` sesuai jenis alat. 0 bila tidak sah.
static func value(kind: String, tier: int) -> int:
	var e: Dictionary = entry(kind, tier)
	if e.is_empty():
		return 0
	return int(e["value"])


## Lama proses aduk mixer dalam detik.
static func mixer_time(tier: int) -> float:
	return float(value(KIND_MIXER, tier))


## Lama panggang oven dalam detik.
static func oven_time(tier: int) -> float:
	return float(value(KIND_OVEN, tier))


## Kapasitas roti PER RAK display.
static func rack_capacity(tier: int) -> int:
	return value(KIND_DISPLAY, tier)


## Apakah jenis alat terdaftar.
static func has_kind(kind: String) -> bool:
	return DATA.has(kind)
