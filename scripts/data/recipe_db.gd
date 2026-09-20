class_name RecipeDB
extends RefCounted

## Basis data 23 resep Roti Lezat Tycoon (GDD 5.3.1 - 5.3.6).
##
## Seluruh angka (modal, harga jual sweet spot, profit bersih, waktu produksi,
## hasil per batch, harga beli resep) disalin PERSIS dari tabel GDD tanpa
## pembulatan atau penyesuaian apa pun.
##
## Invarian yang sudah diverifikasi untuk ke-23 resep: profit == batch_price - modal.
##
## ---------------------------------------------------------------------------
## CATATAN: `modal` GDD vs `modal_computed()` (Sigma harga bahan x qty)
## ---------------------------------------------------------------------------
## Hanya 5 resep yang modalnya sama persis dengan hasil hitung harga bahan
## (roti_tawar_polos 340, donat_gula 500, roti_goreng_polos 220,
## baguette_klasik 220, sourdough_whole_wheat 470).
## 18 resep berikut BERBEDA. Nilai GDD tetap dipakai apa adanya; selisih ini
## sengaja TIDAK dikoreksi (lihat catatan kontrak di ARCHITECTURE.md bagian 3):
##
##   resep                          modal (GDD)   modal_computed
##   roti_cokelat                          820            670
##   roti_sosis_gulung                     710            670
##   roti_keju_manis                       880            780
##   donat_selai_stroberi                  680            580
##   croissant_klasik                      940            690
##   cinnamon_roll                         870            630
##   pain_au_chocolat                     1090            740
##   danish_cheese_pastry                 1070            820
##   roti_sobek_susu                       920            750
##   croissant_artisan_almond             1470           1500   (modal GDD LEBIH KECIL)
##   brioche_gourmet                      1600           1180
##   matcha_sweet_brioche                 1870           1800
##   basque_burnt_cheese_bun              1130           1180   (modal GDD LEBIH KECIL)
##   matcha_mille_crepes                  2450           2050
##   truffle_mushroom_bun                 1870           1670
##   almond_croissant_mewah               2470           2100
##   premium_cream_cheese_danish          2170           1800
##   roti_emas_artisan                    3070           3450   (modal GDD LEBIH KECIL)
##
## `modal` dipakai untuk tampilan perencanaan di Buku Resep agar angka profit
## persis sama dengan GDD. Arus kas nyata memakai harga bahan aktual di Pasar.
##
## Teks langkah produksi disalin dari daftar "Langkah Produksi" tiap tier;
## emoji penanda langkah dilepas karena font bawaan Godot tidak menjaminnya,
## ikon langkah digambar lewat IconCanvas.

## Langkah produksi generik Tier 1 (GDD 5.3.1).
const STEPS_T1: Array = [
	"Aduk bahan di Mixer sampai adonan mentah terbentuk (adonan berwarna putih pucat)",
	"Panggang / Goreng di Oven Tangkring, progress bar berputar (hijau - kuning - merah)",
	"Pindahkan ke rak display, roti berwarna cokelat keemasan siap dijual",
]

## Langkah produksi generik Tier 2 (GDD 5.3.2).
const STEPS_T2: Array = [
	"Aduk di Stand Mixer Elektrik sampai adonan lebih mulus dan cepat terbentuk",
	"Isi / Gulung bahan isian ke dalam adonan, tangan karakter melipat-lipat lembut",
	"Panggang di Oven Listrik Mini",
	"Display ke rak etalase kaca",
]

## Langkah produksi generik Tier 3 tanpa laminasi (GDD 5.3.3).
const STEPS_T3: Array = [
	"Aduk di Heavy Duty Stand Mixer sampai adonan elastis sempurna",
	"Panggang di Deck Oven 2 Tray, dua loyang masuk sekaligus, efisiensi produksi 2x",
	"Finishing: oles glazur atau mentega cair ke permukaan roti untuk efek kilap",
]

## Langkah produksi Tier 3 dengan teknik laminasi adonan mentega berlapis.
## GDD 5.3.3 langkah 2 hanya berlaku untuk Croissant, Pain au Chocolat, dan Danish.
const STEPS_T3_LAMINASI: Array = [
	"Aduk di Heavy Duty Stand Mixer sampai adonan elastis sempurna",
	"Laminasi adonan: lipat, ratakan, lalu lipat lagi adonan mentega berlapis",
	"Panggang di Deck Oven 2 Tray, dua loyang masuk sekaligus, efisiensi produksi 2x",
	"Finishing: oles glazur atau mentega cair ke permukaan roti untuk efek kilap",
]

## Langkah produksi generik Tier 4 tanpa fermentasi (GDD 5.3.4).
const STEPS_T4: Array = [
	"Uleni di Industrial Kneader sampai tekstur adonan sangat elastis mengkilap",
	"Panggang di Rotary Rack Oven, loyang berputar perlahan di dalam oven industri",
	"Dekorasi artisan: tabur almond iris, oles cream cheese, atau cetak pola scoring",
]

## Langkah produksi Tier 4 dengan fermentasi awal.
## GDD 5.3.4 langkah 1 hanya berlaku untuk Sourdough Whole Wheat.
const STEPS_T4_FERMENTASI: Array = [
	"Fermentasi adonan di mangkuk tertutup, pemain bisa mengerjakan tugas lain sambil menunggu",
	"Uleni di Industrial Kneader sampai tekstur adonan sangat elastis mengkilap",
	"Panggang di Rotary Rack Oven, loyang berputar perlahan di dalam oven industri",
	"Dekorasi artisan: tabur almond iris, oles cream cheese, atau cetak pola scoring",
]

## Langkah produksi generik Tier 5 (GDD 5.3.5).
const STEPS_T5: Array = [
	"Seleksi bahan premium: menatap seksama minyak truffle, butter organik, dan cream cheese",
	"Uleni di Planetary Industrial Mixer berkapasitas jumbo",
	"Panggang di Conveyor Belt Oven, loyang berjalan otomatis masuk dan keluar tanpa henti",
	"Finishing artisan: tabur almond berlapis ganda, suntik cream cheese, drizzle minyak truffle",
	"Kemasan premium: roti dikemas dalam gift box cokelat elegan sebelum dipajang",
]

## Urutan kanonik 23 resep, dikelompokkan per tier.
const ORDER: Array = [
	"roti_tawar_polos",
	"donat_gula",
	"roti_goreng_polos",
	"roti_cokelat",
	"roti_sosis_gulung",
	"roti_keju_manis",
	"donat_selai_stroberi",
	"baguette_klasik",
	"croissant_klasik",
	"cinnamon_roll",
	"pain_au_chocolat",
	"danish_cheese_pastry",
	"roti_sobek_susu",
	"croissant_artisan_almond",
	"sourdough_whole_wheat",
	"brioche_gourmet",
	"matcha_sweet_brioche",
	"basque_burnt_cheese_bun",
	"matcha_mille_crepes",
	"truffle_mushroom_bun",
	"almond_croissant_mewah",
	"premium_cream_cheese_danish",
	"roti_emas_artisan",
]

const RECIPES: Dictionary = {
	# ---------------------------------------------------------------- Tier 1
	# GDD 5.3.1 - Dapur Garasi. Resep bawaan, terbuka sejak hari pertama.
	"roti_tawar_polos": {
		"id": "roti_tawar_polos",
		"name": "Roti Tawar Polos",
		"tier": 1,
		"ingredients": {"tepung_terigu": 1, "ragi": 1, "air_garam": 1, "mentega": 1},
		"modal": 340,
		"batch_price": 550,
		"profit": 210,
		"time_sec": 50.0,
		"yield_count": 6,
		"unlock_price": 0,
		"targets": ["anak_sekolah", "pekerja_kantoran", "emak_arisan", "si_galau"],
		"steps": STEPS_T1,
		"min_mixer": 1,
		"min_oven": 1,
		"min_baker_tier": 0,
	},
	"donat_gula": {
		"id": "donat_gula",
		"name": "Donat Gula",
		"tier": 1,
		"ingredients": {"tepung_terigu": 1, "gula_pasir": 1, "ragi": 1, "telur": 1, "mentega": 1},
		"modal": 500,
		"batch_price": 750,
		"profit": 250,
		"time_sec": 55.0,
		"yield_count": 5,
		"unlock_price": 0,
		"targets": ["anak_sekolah", "pekerja_kantoran"],
		"steps": STEPS_T1,
		"min_mixer": 1,
		"min_oven": 1,
		"min_baker_tier": 0,
	},
	"roti_goreng_polos": {
		"id": "roti_goreng_polos",
		"name": "Roti Goreng Polos",
		"tier": 1,
		"ingredients": {"tepung_terigu": 1, "ragi": 1, "air_garam": 1},
		"modal": 220,
		"batch_price": 400,
		"profit": 180,
		"time_sec": 35.0,
		"yield_count": 6,
		"unlock_price": 0,
		"targets": ["anak_sekolah", "emak_arisan"],
		"steps": STEPS_T1,
		"min_mixer": 1,
		"min_oven": 1,
		"min_baker_tier": 0,
	},

	# ---------------------------------------------------------------- Tier 2
	# GDD 5.3.2 - Ruko Pertama. Perlu pembelian resep.
	"roti_cokelat": {
		"id": "roti_cokelat",
		"name": "Roti Cokelat",
		"tier": 2,
		"ingredients": {"tepung_terigu": 1, "ragi": 1, "telur": 1, "cokelat": 1, "mentega": 1},
		"modal": 820,  # GDD 820, hasil hitung bahan 670 - angka GDD dipertahankan
		"batch_price": 1200,
		"profit": 380,
		"time_sec": 45.0,
		"yield_count": 5,
		"unlock_price": 500,
		"targets": ["anak_sekolah", "pekerja_kantoran"],
		"steps": STEPS_T2,
		"min_mixer": 2,
		"min_oven": 2,
		"min_baker_tier": 0,
	},
	"roti_sosis_gulung": {
		"id": "roti_sosis_gulung",
		"name": "Roti Sosis Gulung",
		"tier": 2,
		"ingredients": {"tepung_terigu": 1, "ragi": 1, "mentega": 1, "sosis": 1},
		"modal": 710,  # GDD 710, hasil hitung bahan 670 - angka GDD dipertahankan
		"batch_price": 1100,
		"profit": 390,
		"time_sec": 40.0,
		"yield_count": 5,
		"unlock_price": 500,
		"targets": ["pekerja_kantoran"],
		"steps": STEPS_T2,
		"min_mixer": 2,
		"min_oven": 2,
		"min_baker_tier": 0,
	},
	"roti_keju_manis": {
		"id": "roti_keju_manis",
		"name": "Roti Keju Manis",
		"tier": 2,
		"ingredients": {"tepung_terigu": 1, "gula_pasir": 1, "telur": 1, "susu": 1, "keju": 1},
		"modal": 880,  # GDD 880, hasil hitung bahan 780 - angka GDD dipertahankan
		"batch_price": 1350,
		"profit": 470,
		"time_sec": 50.0,
		"yield_count": 5,
		"unlock_price": 600,
		"targets": ["anak_sekolah", "pekerja_kantoran", "emak_arisan", "si_galau", "driver_ojol"],
		"steps": STEPS_T2,
		"min_mixer": 2,
		"min_oven": 2,
		"min_baker_tier": 0,
	},
	"donat_selai_stroberi": {
		"id": "donat_selai_stroberi",
		"name": "Donat Selai Stroberi",
		"tier": 2,
		"ingredients": {"tepung_terigu": 1, "gula_pasir": 1, "ragi": 1, "telur": 1, "selai": 1},
		"modal": 680,  # GDD 680, hasil hitung bahan 580 - angka GDD dipertahankan
		"batch_price": 1050,
		"profit": 370,
		"time_sec": 55.0,
		"yield_count": 5,
		"unlock_price": 500,
		"targets": ["anak_sekolah", "emak_arisan"],
		"steps": STEPS_T2,
		"min_mixer": 2,
		"min_oven": 2,
		"min_baker_tier": 0,
	},
	"baguette_klasik": {
		"id": "baguette_klasik",
		"name": "Baguette Klasik",
		"tier": 2,
		"ingredients": {"tepung_terigu": 1, "ragi": 1, "air_garam": 1},
		"modal": 220,
		"batch_price": 650,
		"profit": 430,
		"time_sec": 60.0,
		"yield_count": 3,
		"unlock_price": 400,
		"targets": ["pekerja_kantoran", "sosialita"],
		"steps": STEPS_T2,
		"min_mixer": 2,
		"min_oven": 2,
		"min_baker_tier": 0,
	},

	# ---------------------------------------------------------------- Tier 3
	# GDD 5.3.3 - Bakery Mandiri. Perlu baker Tier 3 (Senior) atau lebih.
	"croissant_klasik": {
		"id": "croissant_klasik",
		"name": "Croissant Klasik",
		"tier": 3,
		"ingredients": {"tepung_terigu": 1, "mentega": 2, "telur": 1, "susu": 1, "ragi": 1},
		"modal": 940,  # GDD 940, hasil hitung bahan 690 - angka GDD dipertahankan
		"batch_price": 1600,
		"profit": 660,
		"time_sec": 75.0,
		"yield_count": 4,
		"unlock_price": 1200,
		"targets": ["pekerja_kantoran", "sosialita"],
		"steps": STEPS_T3_LAMINASI,
		"min_mixer": 3,
		"min_oven": 3,
		"min_baker_tier": 3,
	},
	"cinnamon_roll": {
		"id": "cinnamon_roll",
		"name": "Cinnamon Roll",
		"tier": 3,
		"ingredients": {"tepung_terigu": 1, "gula_pasir": 1, "telur": 1, "mentega": 1, "kayu_manis": 1},
		"modal": 870,  # GDD 870, hasil hitung bahan 630 - angka GDD dipertahankan
		"batch_price": 1500,
		"profit": 630,
		"time_sec": 70.0,
		"yield_count": 4,
		"unlock_price": 1200,
		"targets": ["emak_arisan", "driver_ojol"],
		"steps": STEPS_T3,
		"min_mixer": 3,
		"min_oven": 3,
		"min_baker_tier": 3,
	},
	"pain_au_chocolat": {
		"id": "pain_au_chocolat",
		"name": "Pain au Chocolat",
		"tier": 3,
		"ingredients": {"tepung_terigu": 1, "mentega": 2, "cokelat": 1, "telur": 1},
		"modal": 1090,  # GDD 1.090, hasil hitung bahan 740 - angka GDD dipertahankan
		"batch_price": 1800,
		"profit": 710,
		"time_sec": 80.0,
		"yield_count": 4,
		"unlock_price": 1500,
		"targets": ["sosialita", "food_vlogger"],
		"steps": STEPS_T3_LAMINASI,
		"min_mixer": 3,
		"min_oven": 3,
		"min_baker_tier": 3,
	},
	"danish_cheese_pastry": {
		"id": "danish_cheese_pastry",
		"name": "Danish Cheese Pastry",
		"tier": 3,
		"ingredients": {"tepung_terigu": 1, "mentega": 1, "telur": 1, "keju": 1, "susu": 1},
		"modal": 1070,  # GDD 1.070, hasil hitung bahan 820 - angka GDD dipertahankan
		"batch_price": 1750,
		"profit": 680,
		"time_sec": 80.0,
		"yield_count": 4,
		"unlock_price": 1500,
		"targets": ["sosialita", "emak_arisan"],
		"steps": STEPS_T3_LAMINASI,
		"min_mixer": 3,
		"min_oven": 3,
		"min_baker_tier": 3,
	},
	"roti_sobek_susu": {
		"id": "roti_sobek_susu",
		"name": "Roti Sobek Susu",
		"tier": 3,
		"ingredients": {"tepung_terigu": 1, "susu": 2, "gula_pasir": 1, "mentega": 1, "telur": 1},
		"modal": 920,  # GDD 920, hasil hitung bahan 750 - angka GDD dipertahankan
		"batch_price": 1550,
		"profit": 630,
		"time_sec": 65.0,
		"yield_count": 6,
		"unlock_price": 1000,
		"targets": ["emak_arisan", "driver_ojol"],
		"steps": STEPS_T3,
		"min_mixer": 3,
		"min_oven": 3,
		"min_baker_tier": 3,
	},

	# ---------------------------------------------------------------- Tier 4
	# GDD 5.3.4 - Flagship Store. Perlu baker Tier 4 (Pakar).
	"croissant_artisan_almond": {
		"id": "croissant_artisan_almond",
		"name": "Croissant Artisan Almond",
		"tier": 4,
		"ingredients": {"tepung_terigu": 1, "butter_organik": 1, "telur": 1, "susu": 1, "almond": 1},
		"modal": 1470,  # GDD 1.470, hasil hitung bahan 1500 - angka GDD dipertahankan
		"batch_price": 2800,
		"profit": 1330,
		"time_sec": 90.0,
		"yield_count": 4,
		"unlock_price": 3000,
		"targets": ["sosialita", "food_vlogger"],
		"steps": STEPS_T4,
		"min_mixer": 4,
		"min_oven": 4,
		"min_baker_tier": 4,
	},
	"sourdough_whole_wheat": {
		"id": "sourdough_whole_wheat",
		"name": "Sourdough Whole Wheat",
		"tier": 4,
		"ingredients": {"whole_wheat": 1, "air_garam": 1, "ragi": 1},
		"modal": 470,
		"batch_price": 2200,
		"profit": 1730,
		"time_sec": 120.0,
		"yield_count": 2,
		"unlock_price": 3500,
		"targets": ["sosialita", "pekerja_kantoran"],
		"steps": STEPS_T4_FERMENTASI,
		"min_mixer": 4,
		"min_oven": 4,
		"min_baker_tier": 4,
	},
	"brioche_gourmet": {
		"id": "brioche_gourmet",
		"name": "Brioche Gourmet",
		"tier": 4,
		"ingredients": {"tepung_terigu": 1, "butter_organik": 1, "telur": 2, "gula_pasir": 1, "susu": 1},
		"modal": 1600,  # GDD 1.600, hasil hitung bahan 1180 - angka GDD dipertahankan
		"batch_price": 3000,
		"profit": 1400,
		"time_sec": 100.0,
		"yield_count": 4,
		"unlock_price": 3000,
		"targets": ["sosialita", "driver_ojol"],
		"steps": STEPS_T4,
		"min_mixer": 4,
		"min_oven": 4,
		"min_baker_tier": 4,
	},
	"matcha_sweet_brioche": {
		"id": "matcha_sweet_brioche",
		"name": "Matcha Sweet Brioche",
		"tier": 4,
		"ingredients": {"tepung_terigu": 1, "butter_organik": 1, "telur": 1, "matcha": 1, "susu": 1},
		"modal": 1870,  # GDD 1.870, hasil hitung bahan 1800 - angka GDD dipertahankan
		"batch_price": 3500,
		"profit": 1630,
		"time_sec": 110.0,
		"yield_count": 4,
		"unlock_price": 4000,
		"targets": ["sosialita", "food_vlogger", "driver_ojol"],
		"steps": STEPS_T4,
		"min_mixer": 4,
		"min_oven": 4,
		"min_baker_tier": 4,
	},
	"basque_burnt_cheese_bun": {
		"id": "basque_burnt_cheese_bun",
		"name": "Basque Burnt Cheese Bun",
		"tier": 4,
		"ingredients": {"tepung_terigu": 1, "cream_cheese": 1, "telur": 2, "gula_pasir": 1},
		"modal": 1130,  # GDD 1.130, hasil hitung bahan 1180 - angka GDD dipertahankan
		"batch_price": 2500,
		"profit": 1370,
		"time_sec": 95.0,
		"yield_count": 4,
		"unlock_price": 3500,
		"targets": ["sosialita"],
		"steps": STEPS_T4,
		"min_mixer": 4,
		"min_oven": 4,
		"min_baker_tier": 4,
	},

	# ---------------------------------------------------------------- Tier 5
	# GDD 5.3.5 - Mega Bakery. Perlu baker Tier 5 (Master).
	"matcha_mille_crepes": {
		"id": "matcha_mille_crepes",
		"name": "Matcha Mille Crepes",
		"tier": 5,
		"ingredients": {"tepung_terigu": 1, "matcha": 1, "telur": 2, "susu": 2, "butter_organik": 1},
		"modal": 2450,  # GDD 2.450, hasil hitung bahan 2050 - angka GDD dipertahankan
		"batch_price": 5500,
		"profit": 3050,
		"time_sec": 150.0,
		"yield_count": 2,
		"unlock_price": 8000,
		"targets": ["food_vlogger", "sosialita"],
		"steps": STEPS_T5,
		"min_mixer": 5,
		"min_oven": 5,
		"min_baker_tier": 5,
	},
	"truffle_mushroom_bun": {
		"id": "truffle_mushroom_bun",
		"name": "Truffle Mushroom Artisan Bun",
		"tier": 5,
		"ingredients": {"whole_wheat": 1, "truffle": 1, "air_garam": 1, "ragi": 1},
		"modal": 1870,  # GDD 1.870, hasil hitung bahan 1670 - angka GDD dipertahankan
		"batch_price": 6000,
		"profit": 4130,
		"time_sec": 140.0,
		"yield_count": 3,
		"unlock_price": 10000,
		"targets": ["sosialita"],
		"steps": STEPS_T5,
		"min_mixer": 5,
		"min_oven": 5,
		"min_baker_tier": 5,
	},
	"almond_croissant_mewah": {
		"id": "almond_croissant_mewah",
		"name": "Almond Croissant Mewah",
		"tier": 5,
		"ingredients": {"tepung_terigu": 1, "butter_organik": 1, "almond": 1, "cream_cheese": 1, "telur": 1},
		"modal": 2470,  # GDD 2.470, hasil hitung bahan 2100 - angka GDD dipertahankan
		"batch_price": 5000,
		"profit": 2530,
		"time_sec": 130.0,
		"yield_count": 4,
		"unlock_price": 7000,
		"targets": ["sosialita", "food_vlogger"],
		"steps": STEPS_T5,
		"min_mixer": 5,
		"min_oven": 5,
		"min_baker_tier": 5,
	},
	"premium_cream_cheese_danish": {
		"id": "premium_cream_cheese_danish",
		"name": "Premium Cream Cheese Danish",
		"tier": 5,
		"ingredients": {"tepung_terigu": 1, "butter_organik": 1, "cream_cheese": 1, "selai": 1, "telur": 1},
		"modal": 2170,  # GDD 2.170, hasil hitung bahan 1800 - angka GDD dipertahankan
		"batch_price": 4500,
		"profit": 2330,
		"time_sec": 120.0,
		"yield_count": 4,
		"unlock_price": 6000,
		"targets": ["sosialita", "driver_ojol"],
		"steps": STEPS_T5,
		"min_mixer": 5,
		"min_oven": 5,
		"min_baker_tier": 5,
	},
	"roti_emas_artisan": {
		"id": "roti_emas_artisan",
		"name": "Roti Emas Artisan (Signature)",
		"tier": 5,
		"ingredients": {"whole_wheat": 1, "butter_organik": 1, "truffle": 1, "almond": 1, "cream_cheese": 1},
		"modal": 3070,  # GDD 3.070, hasil hitung bahan 3450 - angka GDD dipertahankan
		"batch_price": 8000,
		"profit": 4930,
		"time_sec": 180.0,
		"yield_count": 2,
		"unlock_price": 15000,
		"targets": ["sosialita", "food_vlogger"],
		"steps": STEPS_T5,
		"min_mixer": 5,
		"min_oven": 5,
		"min_baker_tier": 5,
	},
}


## Kembalikan data resep. Dictionary kosong bila id tidak dikenal.
static func entry(id: String) -> Dictionary:
	if RECIPES.has(id):
		return RECIPES[id]
	return {}


## Seluruh id resep dalam urutan tier.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in ORDER:
		out.append(id)
	return out


## Harga jual default per BUAH = harga satu batch dibagi hasil per batch.
static func unit_price_default(id: String) -> float:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return 0.0
	var y: int = int(e["yield_count"])
	if y <= 0:
		return 0.0
	return float(int(e["batch_price"])) / float(y)


## Rentang harga wajar (sweet spot) per BUAH: 85% sampai 125% harga default.
static func sweet_spot_range(id: String) -> Vector2:
	var u: float = unit_price_default(id)
	return Vector2(u * 0.85, u * 1.25)


## Semua id resep pada tier tertentu.
static func by_tier(t: int) -> Array[String]:
	var out: Array[String] = []
	for id: String in ORDER:
		var e: Dictionary = RECIPES[id]
		if int(e["tier"]) == t:
			out.append(id)
	return out


## Resep bawaan yang sudah terbuka sejak hari pertama (Tier 1).
static func starter() -> Array[String]:
	return by_tier(1)


## Modal hasil hitung dari harga bahan aktual: Sigma harga bahan x jumlah.
## Sengaja bisa berbeda dari `modal` GDD, lihat tabel di komentar kepala file.
static func modal_computed(id: String) -> int:
	var e: Dictionary = entry(id)
	if e.is_empty():
		return 0
	var total: int = 0
	var ing: Dictionary = e["ingredients"]
	for ing_id: String in ing.keys():
		total += IngredientDB.price(ing_id) * int(ing[ing_id])
	return total
