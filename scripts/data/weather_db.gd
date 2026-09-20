class_name WeatherDB
extends RefCounted

## Basis data cuaca & musim (GDD Seksi 10.1 - 10.3).
##
## Pengali disimpan sebagai Vector2(minimum, maksimum); WeatherSim mengundi satu
## nilai di dalam rentang itu setiap hari lewat `sample_foot()` / `sample_delivery()`.
##
## Penurunan angka dari GDD 10.2:
## - "Foot Traffic Fisik Anjlok -60% hingga -80%" -> pengali 0.20 (turun 80%) sampai
##   0.40 (turun 60%).
## - "Pesanan RotiFood Meledak +150% hingga +200%" -> pengali 2.50 sampai 3.00.
## GDD 10.3 hanya menyebut "lonjakan pengunjung fisik secara masif" tanpa angka;
## rentang 1.8-2.2 (fisik) dan 1.3-1.6 (delivery) diambil dari kontrak ARCHITECTURE
## bagian WeatherDB agar seluruh modul memakai angka yang sama.

## ID cuaca kanonik (ARCHITECTURE 2.5).
const CERAH := "cerah"
const HUJAN := "hujan"
const LIBURAN := "liburan"

## Bobot dasar undian cuaca besok.
## GDD 10.1 menyebut cerah "Kondisi paling umum dan stabil"; hujan adalah kejadian
## reguler yang jadi tulang punggung gameplay delivery (GDD 10.2); musim liburan
## adalah event sesekali (GDD 10.3 "Holiday Season / Event").
const BASE_WEIGHT := {
	"cerah": 0.60,
	"hujan": 0.28,
	"liburan": 0.12
}

## Batas maksimum hari beruntun dengan cuaca yang sama. Nilai 2 berarti cuaca yang
## sama tidak pernah muncul tiga hari berturut-turut.
const MAX_STREAK := 2

const _DATA := {
	"cerah": {
		"id": "cerah",
		"name": "Cerah",
		"icon": "sun",
		"foot_traffic_mult": Vector2(1.0, 1.0),
		"delivery_mult": Vector2(1.0, 1.0),
		"desc": "Kondisi paling umum dan stabil. Arus pengunjung fisik berjalan normal sesuai rating toko. Pesanan RotiFood mengalir pada frekuensi standar. Cocok untuk menjual varian roti standar."
	},
	"hujan": {
		"id": "hujan",
		"name": "Hujan",
		"icon": "rain",
		"foot_traffic_mult": Vector2(0.20, 0.40),
		"delivery_mult": Vector2(2.50, 3.00),
		"desc": "Momen emas delivery. Warga kota malas keluar rumah sehingga pejalan kaki hampir menghilang dari depan toko, tetapi pesanan RotiFood meledak. Driver ojol tetap berdatangan dengan jas hujan kuning menggemaskan. Panggang roti sebanyak mungkin di pagi hari!"
	},
	"liburan": {
		"id": "liburan",
		"name": "Musim Liburan",
		"icon": "party",
		"foot_traffic_mult": Vector2(1.8, 2.2),
		"delivery_mult": Vector2(1.3, 1.6),
		"desc": "Lonjakan pengunjung fisik secara masif di seluruh kota. Momen terbaik untuk mengaktifkan iklan Tier 3-5 dan memaksimalkan profit dari kedua saluran sekaligus. Siapkan diri menghadapi gelombang antrean fisik sekaligus banjir pesanan online."
	}
}

## Pencatat rentetan cuaca agar undian tidak pernah menghasilkan tiga hari sama
## berturut-turut. Disinkronkan ulang dari argumen `prev` setiap kali `roll()` dipanggil,
## sehingga tetap benar meski permainan dimuat ulang dari save.
static var _streak_id: String = ""
static var _streak_len: int = 0


## Kembalikan salinan data cuaca `id`, atau `{}` bila ID tidak dikenal.
static func entry(id: String) -> Dictionary:
	if not _DATA.has(id):
		return {}
	var d: Dictionary = _DATA[id]
	return d.duplicate(true)


## Seluruh ID cuaca kanonik: cerah, hujan, liburan.
static func ids() -> Array[String]:
	var out: Array[String] = []
	for id: String in _DATA.keys():
		out.append(id)
	return out


## Nama cuaca untuk ditampilkan di HUD.
static func name_of(id: String) -> String:
	if not _DATA.has(id):
		return ""
	var d: Dictionary = _DATA[id]
	var value: String = d["name"]
	return value


## Nama ikon IconCanvas untuk cuaca `id` (sun / rain / party).
static func icon_of(id: String) -> String:
	if not _DATA.has(id):
		return "sun"
	var d: Dictionary = _DATA[id]
	var value: String = d["icon"]
	return value


## Rentang pengali arus pejalan kaki, Vector2(minimum, maksimum).
static func foot_range(id: String) -> Vector2:
	if not _DATA.has(id):
		return Vector2.ONE
	var d: Dictionary = _DATA[id]
	var value: Vector2 = d["foot_traffic_mult"]
	return value


## Rentang pengali frekuensi pesanan RotiFood, Vector2(minimum, maksimum).
static func delivery_range(id: String) -> Vector2:
	if not _DATA.has(id):
		return Vector2.ONE
	var d: Dictionary = _DATA[id]
	var value: Vector2 = d["delivery_mult"]
	return value


## Undi satu pengali arus pejalan kaki untuk hari ini.
static func sample_foot(id: String, rng: RandomNumberGenerator) -> float:
	var r: Vector2 = foot_range(id)
	if rng == null or is_equal_approx(r.x, r.y):
		return r.x
	return rng.randf_range(r.x, r.y)


## Undi satu pengali frekuensi pesanan RotiFood untuk hari ini.
static func sample_delivery(id: String, rng: RandomNumberGenerator) -> float:
	var r: Vector2 = delivery_range(id)
	if rng == null or is_equal_approx(r.x, r.y):
		return r.x
	return rng.randf_range(r.x, r.y)


## Benar bila cuaca `id` adalah hujan — dipakai CharacterFactory untuk memakaikan
## jas hujan kuning pada driver ojol (GDD 10.2) dan FX untuk overlay hujan.
static func is_rainy(id: String) -> bool:
	return id == HUJAN


## Undi cuaca untuk hari berikutnya.
##
## `prev` adalah cuaca hari ini (boleh "" pada permainan baru). Bobot dasar memakai
## BASE_WEIGHT: cerah paling sering, hujan reguler, liburan sesekali. Cuaca yang sudah
## muncul MAX_STREAK hari berturut-turut dicoret dari undian, sehingga tidak pernah ada
## tiga hari identik beruntun.
static func roll(rng: RandomNumberGenerator, prev: String) -> String:
	if rng == null:
		return CERAH

	# Sinkronkan pencatat rentetan dengan riwayat yang dibawa pemanggil.
	if prev == "" or not _DATA.has(prev):
		_streak_id = ""
		_streak_len = 0
	elif prev != _streak_id:
		_streak_id = prev
		_streak_len = 1

	var pool: Array[String] = []
	var weights: Array[float] = []
	var total: float = 0.0
	for id: String in _DATA.keys():
		if id == _streak_id and _streak_len >= MAX_STREAK:
			continue
		var w: float = float(BASE_WEIGHT[id])
		if w <= 0.0:
			continue
		pool.append(id)
		weights.append(w)
		total += w

	if pool.is_empty() or total <= 0.0:
		return CERAH

	var pick_value: float = rng.randf() * total
	var chosen: String = pool[pool.size() - 1]
	var acc: float = 0.0
	for i: int in range(pool.size()):
		acc += weights[i]
		if pick_value < acc:
			chosen = pool[i]
			break

	if chosen == _streak_id:
		_streak_len += 1
	else:
		_streak_id = chosen
		_streak_len = 1
	return chosen


## Kosongkan pencatat rentetan — dipanggil saat memulai permainan baru.
static func reset_streak() -> void:
	_streak_id = ""
	_streak_len = 0
