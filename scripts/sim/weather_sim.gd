class_name WeatherSim
extends Node

## WeatherSim — penentu cuaca hari ini dan prakiraan besok (GDD Seksi 10).
##
## ATURAN RANTAI PRAKIRAAN. Prakiraan yang diundi hari ini SELALU menjadi cuaca
## besok, tidak pernah diundi ulang. Ini wajib karena GDD 10.2 ("Tips Strategis")
## menyuruh pemain memantau ikon prakiraan setiap pagi lalu memanggang stok ekstra
## bila hujan akan datang — prakiraan yang bisa meleset akan membuat saran itu
## menyesatkan. Jadi: cuaca hari N = prakiraan yang tampil pada pagi hari N-1.
##
## PENGALI HARIAN. GDD 10.2 memberi rentang, bukan satu angka ("Foot Traffic Fisik
## Anjlok -60% hingga -80%", "Pesanan RotiFood Meledak +150% hingga +200%"). Rentang
## itu tersimpan di WeatherDB sebagai Vector2(min, max) dan diundi SEKALI setiap pagi
## memakai GameConfig.rng. Pengali tidak boleh diundi ulang tiap tick: satu hari harus
## terasa konsisten, dan simulasi harus bisa diulang persis dari benih yang sama.
##
## GDD 10.3 (Musim Liburan) menaikkan arus pengunjung fisik secara tajam — rentang
## 1.8x - 2.2x diambil dari WeatherDB agar seluruh modul memakai angka yang sama.

# ---------------------------------------------------------------------------
# Konstanta
# ---------------------------------------------------------------------------

## Cuaca cadangan bila ID cuaca pada save rusak / tidak dikenal.
const FALLBACK_WEATHER: String = "cerah"

## Rating RotiFood minimum yang disarankan GDD 10.2 sebelum berharap panen order
## saat hujan ("pastikan rating RotiFood sudah di angka 4.0 ke atas").
const RAIN_READY_ROTIFOOD: float = 4.0

# ---------------------------------------------------------------------------
# Keadaan internal
# ---------------------------------------------------------------------------

var _main: Node = null

## Pengali yang berlaku sepanjang hari ini, diundi sekali pada on_day_start().
var _foot_mult: float = 1.0
var _delivery_mult: float = 1.0

## Hari yang pengalinya sudah diundi — penjaga agar on_day_start ganda tidak
## menggeser rantai prakiraan dua kali.
var _applied_day: int = -1

## Benar setelah hari pertama sesi ini diproses. Selama masih false, cuaca yang
## sudah ada di GameState (hasil reset_new_game atau berkas simpanan) dipakai apa
## adanya, sehingga memuat save tidak pernah mengubah cuaca yang sedang berjalan.
var _chain_started: bool = false

## Penanda agar pemberitahuan hujan hanya muncul sekali per hari.
var _rain_notice_done: bool = false

# ---------------------------------------------------------------------------
# Antarmuka tick deterministik (ARCHITECTURE 7.0)
# ---------------------------------------------------------------------------

func setup(main: Node) -> void:
	_main = main
	_resample_multipliers()


## Cuaca tidak berubah di tengah hari. Tick hanya dipakai untuk memunculkan
## pengingat hujan tepat saat toko buka (GDD 10.2), sekali per hari.
func sim_tick(_delta: float, hour: float) -> void:
	if _rain_notice_done:
		return
	if hour < GameConfig.HOUR_OPEN:
		return
	_rain_notice_done = true
	if not is_rainy():
		return
	AudioBus.sfx("chime")
	EventBus.toast.emit(
		"Hujan turun. Pejalan kaki sepi, tetapi pesanan RotiFood membanjir!",
		"rain"
	)


func on_day_start(day: int) -> void:
	if day == _applied_day:
		return
	_applied_day = day

	var today: String = _valid(GameState.weather)
	var tomorrow: String = _valid(GameState.forecast)

	if _chain_started:
		# Prakiraan kemarin menjadi cuaca hari ini, lalu diundi prakiraan baru.
		today = tomorrow
		tomorrow = _valid(WeatherDB.roll(GameConfig.rng, today))
	else:
		# Hari pertama sesi: pakai cuaca yang sudah tersimpan di GameState.
		_chain_started = true

	GameState.weather = today
	GameState.forecast = tomorrow
	_resample_multipliers()
	_rain_notice_done = false

	EventBus.weather_changed.emit(today, tomorrow)
	_announce(today, tomorrow)


## Cuaca ikut tercatat di ledger harian (ARCHITECTURE 7.1).
func on_day_end(ledger: Dictionary) -> void:
	ledger["weather"] = GameState.weather
	ledger["forecast"] = GameState.forecast


func reset() -> void:
	_applied_day = -1
	_chain_started = false
	_rain_notice_done = false
	WeatherDB.reset_streak()
	_resample_multipliers()

# ---------------------------------------------------------------------------
# API publik — dipakai CustomerSim, DeliverySim, HUD, dan FX
# ---------------------------------------------------------------------------

## ID cuaca hari ini: "cerah" | "hujan" | "liburan".
func today_weather() -> String:
	return GameState.weather


## ID prakiraan cuaca besok, sudah terlihat sejak pagi ini (GDD 10.2).
func tomorrow_weather() -> String:
	return GameState.forecast


## Pengali arus pejalan kaki hari ini. Stabil sepanjang hari.
## GDD 10.2 hujan: 0.20 - 0.40. GDD 10.3 liburan: 1.8 - 2.2. GDD 10.1 cerah: 1.0.
func foot_multiplier() -> float:
	return _foot_mult


## Pengali frekuensi pesanan RotiFood hari ini. Stabil sepanjang hari.
## GDD 10.2 hujan: 2.50 - 3.00 (+150% .. +200%).
func delivery_multiplier() -> float:
	return _delivery_mult


## Pengali pejalan kaki untuk sebuah ID cuaca, dipakai layar prakiraan agar bisa
## menampilkan perkiraan dampak besok tanpa mengubah undian hari ini.
func foot_multiplier_of(weather_id: String) -> float:
	var r: Vector2 = WeatherDB.foot_range(_valid(weather_id))
	return (r.x + r.y) * 0.5


## Pengali pesanan online untuk sebuah ID cuaca (rata-rata rentang).
func delivery_multiplier_of(weather_id: String) -> float:
	var r: Vector2 = WeatherDB.delivery_range(_valid(weather_id))
	return (r.x + r.y) * 0.5


func is_rainy() -> bool:
	return WeatherDB.is_rainy(GameState.weather)


func is_holiday() -> bool:
	return GameState.weather == "liburan"


## Benar bila prakiraan besok hujan — pemicu saran "panggang stok ekstra" (GDD 10.2).
func rain_incoming() -> bool:
	return WeatherDB.is_rainy(GameState.forecast)


## Nama cuaca hari ini untuk HUD.
func today_name() -> String:
	return WeatherDB.name_of(GameState.weather)


## Nama ikon prosedural cuaca hari ini (sun / rain / party).
func today_icon() -> String:
	return WeatherDB.icon_of(GameState.weather)

# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

## Mengundi pengali harian sekali saja, memakai satu-satunya sumber acak resmi.
func _resample_multipliers() -> void:
	var id: String = _valid(GameState.weather)
	_foot_mult = WeatherDB.sample_foot(id, GameConfig.rng)
	_delivery_mult = WeatherDB.sample_delivery(id, GameConfig.rng)
	if _foot_mult <= 0.0:
		_foot_mult = WeatherDB.foot_range(id).x
	if _delivery_mult <= 0.0:
		_delivery_mult = WeatherDB.delivery_range(id).x


## Pengumuman pagi: kabar cuaca hari ini sekaligus ancang-ancang untuk besok.
func _announce(today: String, tomorrow: String) -> void:
	var today_label: String = WeatherDB.name_of(today)
	if today == "hujan":
		EventBus.toast.emit(
			"Hari ini %s. Siapkan stok untuk banjir pesanan RotiFood." % today_label,
			WeatherDB.icon_of(today)
		)
	elif today == "liburan":
		EventBus.toast.emit(
			"Hari ini %s. Pengunjung membeludak — pastikan rak display penuh!" % today_label,
			WeatherDB.icon_of(today)
		)
	else:
		EventBus.toast.emit(
			"Hari ini %s. Arus pengunjung berjalan normal." % today_label,
			WeatherDB.icon_of(today)
		)

	# GDD 10.2 "Tips Strategis": prakiraan wajib terlihat pada PAGI SEBELUMNYA agar
	# pemain sempat memanggang stok ekstra.
	if WeatherDB.is_rainy(tomorrow):
		var tip: String = "Prakiraan besok hujan. Perbanyak panggangan pagi ini untuk pesanan RotiFood!"
		if GameState.rotifood_rating < RAIN_READY_ROTIFOOD:
			tip = "Prakiraan besok hujan. Naikkan dulu rating RotiFood ke %.1f bintang agar order mengalir deras." % RAIN_READY_ROTIFOOD
		EventBus.toast.emit(tip, "rain")
	elif tomorrow == "liburan":
		EventBus.toast.emit(
			"Prakiraan besok musim liburan. Waktu terbaik menyalakan kampanye iklan!",
			"party"
		)


## Menjamin ID cuaca selalu sah (berkas simpanan bisa saja membawa ID asing).
func _valid(id: String) -> String:
	if WeatherDB.entry(id).is_empty():
		return FALLBACK_WEATHER
	return id
