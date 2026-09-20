class_name MarketingDB
extends RefCounted

## Basis data Kampanye Pemasaran (GDD Seksi 8.1 - 8.3).
##
## Seluruh angka disalin PERSIS dari tabel GDD 8.1; teks `desc` dan `effect`
## disalin dari GDD 8.2 ("Deskripsi" dan "Efek Tambahan").
## Aturan kampanye (GDD 8): biaya dibayar di muka, masa aktif 5 hari in-game,
## dan hanya SATU kampanye yang boleh aktif dalam satu waktu.
##
## Peringatan strategis GDD 8.3 (dipakai oleh MarketingScreen sebagai teks bantuan):
## kampanye Tier 3-5 tanpa kapasitas produksi/kasir yang memadai justru membuat
## antrean meluber, pelanggan kabur, dan reputasi toko turun drastis.

## Masa aktif satu kampanye dalam hari in-game (GDD 8: "masa aktif selama 5 hari (in-game)").
const DURATION_DAYS := 5

## Jumlah tingkatan kampanye yang tersedia (GDD 8.1).
const TIER_COUNT := 5

## Peringatan risiko GDD 8.3 — ditampilkan di layar Pemasaran.
const RISK_WARNING := "Kampanye adalah pedang bermata dua. Bila kapasitas dapur atau kasir belum siap, antrean akan meluber melebihi kapasitas toko, pelanggan kabur, dan reputasi turun drastis. Pastikan rak display dan stok gudang mencukupi sebelum iklan dinyalakan."

const _DATA := {
	1: {
		"tier": 1,
		"name": "Selebaran Kertas Roti",
		"cost": 300,
		"per_day": 60,
		"visitor_boost": 0.20,
		"rating_per_day": 0.0,
		"req_location": 1,
		"targets": ["anak_sekolah"],
		"vip_chance_bonus": 0.0,
		"desc": "Karakter membagikan selebaran kertas roti sederhana kepada orang-orang yang melintas di depan rumah.",
		"effect": "Sangat efektif meningkatkan penjualan varian roti dasar (Donat Gula & Roti Tawar)."
	},
	2: {
		"tier": 2,
		"name": "Spanduk & Poster Jalanan",
		"cost": 1200,
		"per_day": 240,
		"visitor_boost": 0.45,
		"rating_per_day": 0.08,
		"req_location": 2,
		"targets": ["pekerja_kantoran", "emak_arisan"],
		"vip_chance_bonus": 0.0,
		"desc": "Memasang spanduk kain motif kotak-kotak pastel dan papan kayu penunjuk arah di persimpangan jalan ramai.",
		"effect": "Meningkatkan frekuensi kedatangan Pekerja Kantoran pada jam sibuk pagi hari (08:00 - 10:00). Boost reputasi +0.08 bintang setiap hari kampanye jika antrean kasir berjalan lancar."
	},
	3: {
		"tier": 3,
		"name": "Siaran Radio & Majalah Kuliner",
		"cost": 3500,
		"per_day": 700,
		"visitor_boost": 0.75,
		"rating_per_day": 0.15,
		"req_location": 3,
		"targets": ["emak_arisan"],
		"vip_chance_bonus": 0.0,
		"desc": "Iklan audio di radio lokal dengan jingle manis serta ulasan satu halaman penuh di majalah kuliner bulanan.",
		"effect": "Memicu kedatangan pelanggan borongan (The Bulk Buyer) yang memborong 5-10 roti sekaligus dalam satu struk. Boost reputasi +0.15 bintang per hari."
	},
	4: {
		"tier": 4,
		"name": "Kolaborasi Influencer & Vlogger",
		"cost": 10000,
		"per_day": 2000,
		"visitor_boost": 1.10,
		"rating_per_day": 0.30,
		"req_location": 4,
		"targets": ["sosialita", "food_vlogger"],
		"vip_chance_bonus": 0.40,
		"desc": "Mengundang food vlogger populer untuk mengulas roti artisan dan merekam video dapur terbuka (open kitchen).",
		"effect": "Mendatangkan pelanggan berkantong tebal (Sosialita) yang hanya membeli roti resep Tier 3 tanpa memedulikan harga mahal. Peluang kedatangan Kritikus Makanan VIP meningkat sebesar +40%. Boost reputasi +0.30 bintang per hari."
	},
	5: {
		"tier": 5,
		"name": "Sponsor Festival Kuliner Akbar",
		"cost": 30000,
		"per_day": 6000,
		"visitor_boost": 1.60,
		"rating_per_day": 0.50,
		"req_location": 5,
		"targets": ["anak_sekolah", "pekerja_kantoran", "emak_arisan", "sosialita", "si_galau", "food_vlogger"],
		"vip_chance_bonus": 0.0,
		"desc": "Menjadi sponsor utama festival kuliner tahunan kota dengan stan raksasa dan promosi masif.",
		"effect": "Menggandakan arus antrean toko menjadi sangat padat (rush hour seharian). Sangat menguntungkan bagi pemain yang sudah memiliki 3 kasir otomatis dan staf dapur master. Boost reputasi +0.50 bintang per hari."
	}
}


## Kembalikan salinan data kampanye untuk `tier` (1..5), atau `{}` bila tidak ada.
## Salinan dalam (deep copy) dipakai agar data konstanta tidak bisa diubah pemanggil.
static func entry(tier: int) -> Dictionary:
	if not _DATA.has(tier):
		return {}
	var d: Dictionary = _DATA[tier]
	return d.duplicate(true)


## Kontrak data layer: daftar ID sebagai String. Kunci MarketingDB adalah tier angka,
## sehingga ID-nya adalah tier dalam bentuk teks ("1".."5"). Untuk iterasi numerik
## gunakan `tiers()`.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for tier: int in _DATA.keys():
		out.append(str(tier))
	return out


## Daftar seluruh tier kampanye, urut dari yang termurah.
static func tiers() -> Array[int]:
	var out: Array[int] = []
	for tier: int in _DATA.keys():
		out.append(tier)
	return out


## Kampanye yang boleh dibeli pada tier lokasi tertentu.
## GDD 8.1: "Tingkatan kampanye terbuka secara bertahap seiring perkembangan Tier Lokasi Toko"
## — sebuah kampanye butuh `req_location` <= tier lokasi pemain.
static func available(location_tier: int) -> Array[int]:
	var out: Array[int] = []
	for tier: int in _DATA.keys():
		var d: Dictionary = _DATA[tier]
		if int(d["req_location"]) <= location_tier:
			out.append(tier)
	return out


## Benar bila kampanye `tier` sudah terbuka di lokasi `location_tier`.
static func is_available(tier: int, location_tier: int) -> bool:
	if not _DATA.has(tier):
		return false
	var d: Dictionary = _DATA[tier]
	return int(d["req_location"]) <= location_tier


## Biaya di muka satu kampanye penuh (5 hari), dalam KR.
static func cost(tier: int) -> int:
	if not _DATA.has(tier):
		return 0
	var d: Dictionary = _DATA[tier]
	return int(d["cost"])


## Beban rata-rata per hari dalam KR (kolom "Beban Rata-rata / Hari" GDD 8.1).
## Angka ini hanya untuk tampilan; kas dipotong sekali di muka sebesar `cost()`.
static func per_day(tier: int) -> int:
	if not _DATA.has(tier):
		return 0
	var d: Dictionary = _DATA[tier]
	return int(d["per_day"])


## Peningkatan pengunjung sebagai pecahan (+20% -> 0.20).
static func visitor_boost(tier: int) -> float:
	if not _DATA.has(tier):
		return 0.0
	var d: Dictionary = _DATA[tier]
	return float(d["visitor_boost"])


## Tambahan rating toko per hari selama kampanye aktif (GDD 8.2 "Boost Reputasi").
static func rating_per_day(tier: int) -> float:
	if not _DATA.has(tier):
		return 0.0
	var d: Dictionary = _DATA[tier]
	return float(d["rating_per_day"])


## Tambahan peluang kedatangan Kritikus Makanan VIP (Food Vlogger).
## Hanya Tier 4 yang memberi bonus, yaitu +40% (GDD 8.2 butir 4).
static func vip_chance_bonus(tier: int) -> float:
	if not _DATA.has(tier):
		return 0.0
	var d: Dictionary = _DATA[tier]
	return float(d["vip_chance_bonus"])


## Daftar ID pelanggan yang paling terdorong oleh kampanye ini (kolom
## "Target Pelanggan Utama" GDD 8.1 dipadukan dengan "Efek Tambahan" GDD 8.2).
static func targets(tier: int) -> Array:
	if not _DATA.has(tier):
		return []
	var d: Dictionary = _DATA[tier]
	var src: Array = d["targets"]
	return src.duplicate()


## Kampanye tertinggi yang terbuka di sebuah tier lokasi, atau 0 bila belum ada.
static func highest_available(location_tier: int) -> int:
	var best: int = 0
	for tier: int in _DATA.keys():
		var d: Dictionary = _DATA[tier]
		if int(d["req_location"]) <= location_tier and tier > best:
			best = tier
	return best
