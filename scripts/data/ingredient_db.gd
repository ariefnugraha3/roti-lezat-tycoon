class_name IngredientDB
extends RefCounted

## Basis data bahan baku bertarif tetap (Fixed Price) sesuai GDD 5.2.1 A/B/C.
## Seluruh harga ditranskripsi PERSIS dari tabel GDD dalam satuan Koin Roti (KR).
## Tidak ada fluktuasi harga: pemain dapat menghitung HPP dengan pasti.

## Kategori yang sah untuk kolom `category`.
const CATEGORY_DASAR: String = "dasar"
const CATEGORY_ISIAN: String = "isian"
const CATEGORY_PREMIUM: String = "premium"

## Urutan kategori untuk tampilan katalog Pasar Bahan Baku.
const CATEGORIES: Array[String] = [CATEGORY_DASAR, CATEGORY_ISIAN, CATEGORY_PREMIUM]

## 18 bahan baku kanonik. Urutan kunci = urutan tampil di layar Pasar.
const DATA: Dictionary = {
	# --- A. Bahan Dasar (GDD 5.2.1 A) — pondasi seluruh adonan roti ---
	"tepung_terigu": {
		"name": "Tepung Terigu",
		"unit": "Porsi (kg)",
		"price": 150,
		"role": "Struktur & kerangka utama seluruh jenis adonan roti.",
		"used_in": "Semua varian roti (Roti Tawar, Donat, Roti Goreng, Croissant).",
		"category": "dasar",
	},
	"gula_pasir": {
		"name": "Gula Pasir",
		"unit": "Porsi (ons)",
		"price": 80,
		"role": "Pemanis adonan, pengaktif ragi, dan bahan dasar taburan glaze.",
		"used_in": "Donat Gula, Roti Manis, Glaze Pastry.",
		"category": "dasar",
	},
	"ragi": {
		"name": "Ragi Aktif (Yeast)",
		"unit": "Porsi (sachet)",
		"price": 50,
		"role": "Agen pengembang biologis pembentuk pori roti yang empuk.",
		"used_in": "Wajib untuk semua roti yang mengembang (Roti Tawar, Baguette, Donat).",
		"category": "dasar",
	},
	"telur": {
		"name": "Telur Ayam",
		"unit": "Butir",
		"price": 100,
		"role": "Memberikan kelembutan, warna kuning keemasan, dan aroma gurih.",
		"used_in": "Adonan lembut (Brioche, Roti Manis, Danish Pastry).",
		"category": "dasar",
	},
	"mentega": {
		"name": "Mentega Biasa",
		"unit": "Porsi (gr)",
		"price": 120,
		# GDD menulis "Lemak nabati" untuk mentega (secara kuliner mentega adalah lemak hewani);
		# teks ditranskripsi apa adanya sesuai aturan transkripsi GDD.
		"role": "Lemak nabati pelembut serat roti dan pelapis adonan pastry.",
		"used_in": "Roti Tawar, Croissant dasar, Roti Goreng.",
		"category": "dasar",
	},
	"air_garam": {
		"name": "Air & Garam Dapur",
		"unit": "Takaran",
		"price": 20,
		"role": "Pengikat gluten adonan dan penguat rasa alami roti.",
		"used_in": "Penyeimbang rasa di semua jenis adonan roti.",
		"category": "dasar",
	},

	# --- B. Bahan Isian & Topping (GDD 5.2.1 B) — penambah nilai jual ---
	"cokelat": {
		"name": "Cokelat Batang",
		"unit": "Balok",
		"price": 250,
		"role": "Cokelat leleh legit, favorit pelanggan anak sekolah & pekerja.",
		"used_in": "Roti Cokelat, Donat Cokelat, Pain au Chocolat.",
		"category": "isian",
	},
	"keju": {
		"name": "Keju Cheddar",
		"unit": "Batang",
		"price": 300,
		"role": "Rasa asin gurih meleleh yang sangat disukai berbagai kalangan.",
		"used_in": "Roti Keju Manis, Croissant Keju, Danish Cheese.",
		"category": "isian",
	},
	"selai": {
		"name": "Selai Buah (Stroberi)",
		"unit": "Toples",
		"price": 200,
		"role": "Rasa manis asam segar penyeimbang roti berlemak.",
		"used_in": "Donat Selai, Danish Pastry Buah, Roti Gulung Selai.",
		"category": "isian",
	},
	"susu": {
		"name": "Susu Segar",
		"unit": "Porsi (ml)",
		"price": 150,
		"role": "Menghasilkan remah roti yang lembut serta olesan mengkilap (egg wash).",
		"used_in": "Brioche lembut, roti sobek susu, dan Danish pastry.",
		"category": "isian",
	},
	"sosis": {
		"name": "Sosis Daging Sapi",
		"unit": "Buah",
		"price": 350,
		"role": "Isian daging gurih padat untuk sarapan praktis pekerja kantor.",
		"used_in": "Roti Sosis Gurih (Sausage Roll), Roti Pizza Mini.",
		"category": "isian",
	},
	"kayu_manis": {
		"name": "Bubuk Kayu Manis",
		"unit": "Porsi (gr)",
		"price": 180,
		"role": "Rempah aromatik manis penghangat suasana toko.",
		"used_in": "Cinnamon Roll, Danish Pastry Spiced.",
		"category": "isian",
	},

	# --- C. Bahan Premium & Artisan (GDD 5.2.1 C) — resep kelas atas ---
	"whole_wheat": {
		"name": "Tepung Whole Wheat",
		"unit": "Porsi (kg)",
		"price": 400,
		"role": "Tepung gandum utuh berserat tinggi dengan cita rasa kacang alami.",
		"used_in": "Roti Sehat Sourdough Whole Wheat.",
		"category": "premium",
	},
	"butter_organik": {
		"name": "Butter Organik (Wijsman)",
		"unit": "Kaleng",
		"price": 600,
		"role": "Mentega konsentrat beraroma harum legendaris untuk pastry berlapis.",
		"used_in": "Croissant Artisan Berlapis Mewah, Brioche Gourmet.",
		"category": "premium",
	},
	"almond": {
		"name": "Kacang Almond Iris",
		"unit": "Kantong",
		"price": 500,
		"role": "Taburan renyah gurih memberikan tekstur renyah mewah.",
		"used_in": "Topping Almond Croissant, Roti Cokelat Almond.",
		"category": "premium",
	},
	"cream_cheese": {
		"name": "Cream Cheese Impor",
		"unit": "Kotak",
		"price": 750,
		"role": "Krim keju lembut asam-gurih bertekstur lumer di lidah.",
		"used_in": "Basque Burnt Cheesecake Bun, Premium Cream Pastry.",
		"category": "premium",
	},
	"matcha": {
		"name": "Bubuk Matcha Jepang",
		"unit": "Kaleng",
		"price": 800,
		"role": "Teh hijau asli dengan rasa umami khas dan warna hijau alami.",
		"used_in": "Matcha Mille Crepes, Matcha Sweet Brioche.",
		"category": "premium",
	},
	"truffle": {
		"name": "Minyak / Jamur Truffle",
		"unit": "Botol",
		"price": 1200,
		"role": "Aroma bumi mewah (earthy) yang memberikan status hidangan bintang lima.",
		"used_in": "Truffle Mushroom Bun, Roti Artisan Eksklusif.",
		"category": "premium",
	},
}


## Kembalikan salinan data satu bahan. Dictionary kosong bila id tidak dikenal.
static func entry(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var src: Dictionary = DATA[id]
	var out: Dictionary = src.duplicate(true)
	out["id"] = id
	return out


## Seluruh id bahan sesuai urutan deklarasi (dasar -> isian -> premium).
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in DATA:
		out.append(id)
	return out


## Harga tetap bahan dalam KR. 0 bila id tidak dikenal.
static func price(id: String) -> int:
	if not DATA.has(id):
		return 0
	var src: Dictionary = DATA[id]
	return int(src["price"])


## Nama tampilan bahan. String kosong bila id tidak dikenal.
static func display_name(id: String) -> String:
	if not DATA.has(id):
		return ""
	var src: Dictionary = DATA[id]
	return String(src["name"])


## Daftar id bahan pada satu kategori ("dasar" | "isian" | "premium").
static func by_category(cat: String) -> Array[String]:
	var out: Array[String] = []
	for id: String in DATA:
		var src: Dictionary = DATA[id]
		if String(src["category"]) == cat:
			out.append(id)
	return out


## Apakah id bahan terdaftar.
static func has_id(id: String) -> bool:
	return DATA.has(id)


## Total biaya sebuah resep bahan: {ingredient_id: qty} -> KR.
static func total_price(costs: Dictionary) -> int:
	var total: int = 0
	for id: String in costs:
		total += price(id) * int(costs[id])
	return total
