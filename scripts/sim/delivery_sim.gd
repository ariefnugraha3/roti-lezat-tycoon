class_name DeliverySim
extends Node
## DeliverySim -- kanal pesanan daring "RotiFood" (GDD 3.6, GDD 9.2, GDD 10.2).
##
## Sistem ini menjalankan seluruh siklus pesanan online: notifikasi masuk di tablet
## kasir, pengemasan roti dari rak display, kedatangan driver ojol, serah terima,
## hingga pembatalan otomatis saat stok habis atau pemain terlambat.
##
## Sistem TIDAK memakai _process/_physics_process. Main yang memanggil
## setup/sim_tick/on_day_start/on_day_end/reset (ARCHITECTURE 7.0), sehingga
## simulasi dapat dijalankan headless dan hasilnya dapat diulang dari satu benih.
##
## Bentuk Dictionary pesanan mengikuti ARCHITECTURE 7.1 PERSIS; seluruh catatan
## internal (sudah dikemas, driver sudah tiba, kualitas roti, dsb) disimpan
## terpisah di `_meta` agar payload sinyal tidak tercemar kunci tambahan.
##
## Sinyal yang dipancarkan sistem ini:
## - EventBus.delivery_order_received(order)
## - EventBus.delivery_order_packed(order)
## - EventBus.delivery_order_handover(order, tip)
## - EventBus.delivery_order_expired(order)
## - EventBus.toast(text, icon)  (hanya saat pesanan batal)

# ---------------------------------------------------------------------------
# Angka dari GDD
# ---------------------------------------------------------------------------

## Preparation Timer pesanan (GDD 3.6.A: "Preparation Timer (misal: 60 - 90 detik)").
const PREP_WINDOW_MIN: float = 60.0
const PREP_WINDOW_MAX: float = 90.0

## Dampak rating RotiFood -- tabel GDD 9.2. Angkanya dipegang ReputationSystem
## (pemilik tunggal kedua rating), jadi dirujuk dari sana agar hanya ada satu sumber.
const RATING_INSTANT_HANDOVER: float = ReputationSystem.ROTIFOOD_INSTANT_HANDOVER
const RATING_READY_IN_WINDOW: float = ReputationSystem.ROTIFOOD_ON_TIME
const RATING_DRIVER_WAITED: float = ReputationSystem.ROTIFOOD_DRIVER_WAIT
const RATING_CANCELLED: float = ReputationSystem.ROTIFOOD_CANCELLED
const RATING_PRIMA_BONUS: float = ReputationSystem.ROTIFOOD_PRIME_BONUS

## Badge "Toko Terpercaya" (GDD 9.2): rating >= 4.5 bintang menaikkan volume
## order harian hingga +80%.
const BADGE_RATING: float = ReputationSystem.TRUSTED_BADGE_MIN
const BADGE_ORDER_BOOST: float = ReputationSystem.TRUSTED_BADGE_ORDER_BOOST

## Kualitas roti kanonik yang memberi bonus rating (ARCHITECTURE 2.5).
const QUALITY_PRIMA: String = "prima"

# ---------------------------------------------------------------------------
# Angka turunan (tidak disebut eksplisit di GDD; dasar penurunannya dikomentari)
# ---------------------------------------------------------------------------

## Bintang tengah skala RotiFood (1.0-5.0) dianggap "frekuensi standar" GDD 10.1,
## yaitu pengali 1.0. Dari titik ini rating naik lurus sampai +80% di 4.5 bintang
## dan turun lurus di bawahnya.
const RATING_PIVOT: float = 3.0

## Batas bawah pengali order. GDD menegaskan tidak ada kondisi kalah permanen,
## jadi toko berbintang rendah tetap menerima order walau sangat jarang.
const MIN_ORDER_RATE_MULT: float = 0.20

## Frekuensi dasar pesanan per JAM in-game untuk setiap rak display yang dimiliki
## lokasi (LocationDB.rack_slots). Toko makin besar = makin banyak order masuk.
const BASE_ORDERS_PER_HOUR_PER_RACK: float = 1.0

## Sebaran acak jarak antar-order di sekitar rata-ratanya (rata-rata tetap sama).
const ARRIVAL_JITTER_MIN: float = 0.5
const ARRIVAL_JITTER_MAX: float = 1.5

## Driver diberangkatkan bersamaan dengan pesanan masuk, dan tiba sebelum batas
## waktu penyiapan habis; dengan begitu Instant Handover (GDD 3.6.C) selalu bisa
## diraih pemain yang sigap mengemas.
const DRIVER_ETA_MIN_RATIO: float = 0.55
const DRIVER_ETA_MAX_RATIO: float = 0.95

## Bobot tambahan resep yang di GDD 5.3 ditandai favorit delivery / penggemar
## RotiFood (RecipeDB.targets memuat "driver_ojol").
const FAVORITE_WEIGHT: float = 2.0

## Maksimum jenis resep berbeda dalam satu pesanan.
const MAX_DISTINCT_ITEMS: int = 3

## Nama metode ReputationSystem yang dipakai untuk menerapkan satu baris tabel
## GDD 9.2. Yang berlaku adalah `apply_rotifood(delta, reason)`; sisanya hanya
## cadangan nama supaya sistem tetap jalan bila API sempat berubah.
const REP_METHODS: Array[String] = [
	"apply_rotifood",
	"apply_rotifood_delta",
	"rotifood_delta",
	"add_rotifood",
]

# ---------------------------------------------------------------------------
# Keadaan runtime
# ---------------------------------------------------------------------------

var _main: Node = null
var _rep_cache: Node = null
var _staff_cache: Node = null

## Pesanan yang masih hidup di tablet (Dictionary sesuai ARCHITECTURE 7.1).
var _orders: Array = []

## Catatan internal per pesanan: order_id -> Dictionary.
var _meta: Dictionary = {}

var _next_id: int = 1
var _next_in: float = 0.0
var _weather_mult: float = 1.0
var _hour: float = GameConfig.HOUR_START

## Perkiraan jumlah pelanggan fisik yang sedang berada di dalam toko. Dipakai untuk
## memperebutkan waktu kasir di toko Tier 1-2 (GDD 3.6.B). Dihitung murni dari
## sinyal EventBus sehingga tidak ada kopling langsung ke CustomerSim.
var _walk_in_inside: int = 0

## Tally roti terjual lewat delivery hari ini: recipe_id -> int.
var _delivery_tally: Dictionary = {}

var _warned_rep: bool = false


# ---------------------------------------------------------------------------
# Antarmuka sistem simulasi (ARCHITECTURE 7.0)
# ---------------------------------------------------------------------------

func setup(main: Node) -> void:
	_main = main
	_rep_cache = null
	_staff_cache = null
	if not EventBus.customer_spawned.is_connected(_on_customer_spawned):
		EventBus.customer_spawned.connect(_on_customer_spawned)
	if not EventBus.customer_served.is_connected(_on_customer_served):
		EventBus.customer_served.connect(_on_customer_served)
	if not EventBus.customer_left_angry.is_connected(_on_customer_left_angry):
		EventBus.customer_left_angry.connect(_on_customer_left_angry)
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	_resample_weather()
	_next_in = _next_interval()


func sim_tick(delta: float, hour: float) -> void:
	if delta <= 0.0:
		return
	_hour = hour
	_tick_orders(delta)
	_tick_arrivals(delta, hour)


func on_day_start(day: int) -> void:
	# Sisa pesanan kemarin dibuang diam-diam; tablet selalu mulai bersih.
	_clear_all(true, false)
	_walk_in_inside = 0
	_delivery_tally.clear()
	_hour = GameConfig.HOUR_START
	_resample_weather()
	_next_in = _next_interval()
	print_verbose("[delivery] hari %d: pengali order cuaca %.2f (%s)" % [
		day, _weather_mult, GameState.weather,
	])


func on_day_end(ledger: Dictionary) -> void:
	# Aplikasi RotiFood menutup toko pukul 18:00. Pesanan yang belum tuntas dibatalkan
	# tanpa penalti rating: GDD 9.2 hanya menghukum pembatalan karena stok habis /
	# lewat batas waktu penyiapan, bukan karena jam operasional berakhir.
	_clear_all(false, false)
	# Kunci tambahan untuk DialogDB.highlights() baris "Delivery surge saat hujan"
	# (GDD 11.3). Bukan kunci wajib ledger ARCHITECTURE 7.1, hanya pelengkap.
	ledger["delivery_surge_pct"] = surge_percent()


func reset() -> void:
	_clear_all(true, false)
	_meta.clear()
	_orders.clear()
	_next_id = 1
	_next_in = 0.0
	_weather_mult = 1.0
	_hour = GameConfig.HOUR_START
	_walk_in_inside = 0
	_delivery_tally.clear()
	_rep_cache = null
	_staff_cache = null
	_warned_rep = false


# ---------------------------------------------------------------------------
# API publik (dipakai UI, StaffSim, dan CustomerSim)
# ---------------------------------------------------------------------------

## Seluruh pesanan yang masih aktif di tablet. Dictionary-nya adalah rujukan hidup
## agar UI bisa menampilkan perkembangan waktu; Array-nya salinan agar isi antrean
## tidak bisa diubah dari luar.
func orders() -> Array:
	return _orders.duplicate()


## Jumlah pesanan yang masih menunggu ditangani (belum selesai / belum batal).
func pending_count() -> int:
	return _orders.size()


## Kemas satu pesanan: ambil roti dari rak display lalu mulai membungkus.
## Dipanggil pemain (tap) maupun StaffSim (otomatis oleh kasir/baker).
## Mengembalikan false bila pesanan tidak ada, sudah dikemas, atau stok kurang.
func pack(order_id: int) -> bool:
	var order: Dictionary = order_by_id(order_id)
	if order.is_empty():
		return false
	var meta: Dictionary = _meta.get(order_id, {})
	if meta.is_empty():
		return false
	if bool(meta.get("packed", false)) or bool(meta.get("packing", false)):
		return false
	if _is_closed(String(order.get("state", ""))):
		return false

	var items: Dictionary = order.get("items", {})
	if items.is_empty():
		return false

	# Stok harus mencukupi untuk SELURUH isi pesanan (GDD 3.6.A langkah 2).
	var stock: Dictionary = _display_stock()
	for k: Variant in items:
		if int(stock.get(String(k), 0)) < int(items[k]):
			return false

	# Ambil roti dari rak sambil mencatat kualitas tiap butir (bonus GDD 9.2).
	var taken_map: Dictionary = {}
	var all_prima: bool = true
	var got_any: bool = false
	for k2: Variant in items.keys():
		var rid: String = String(k2)
		var want: int = int(items[k2])
		if want <= 0:
			items.erase(k2)
			continue
		var qualities: Dictionary = _peek_qualities(rid, want)
		var taken: int = GameState.display_take(rid, want)
		if taken <= 0:
			items.erase(k2)
			continue
		if taken < want:
			# Pengaman: stok menyusut di sela pemeriksaan. Pesanan menyusut mengikuti.
			items[k2] = taken
			qualities = _trim_qualities(qualities, taken)
		taken_map[rid] = qualities
		got_any = true
		for q: Variant in qualities:
			if String(q) != QUALITY_PRIMA:
				all_prima = false

	if not got_any:
		# Tidak ada satu pun roti yang berhasil diambil -> pesanan gagal total.
		meta["taken"] = {}
		_cancel(order, meta, "stok_habis", true)
		return false

	# Nilai pesanan mengikuti isi yang benar-benar terkemas.
	order["value"] = _order_value(items)
	meta["taken"] = taken_map
	meta["prima"] = all_prima
	meta["packing"] = true
	meta["pack_left"] = _pack_duration()
	order["state"] = "dikemas"

	if float(meta["pack_left"]) <= 0.0:
		_finish_packing(order, meta)
	return true


## Serahkan paket kepada driver yang sudah tiba. Dipanggil pemain (tap) maupun
## StaffSim. Mengembalikan false bila paket belum dikemas atau driver belum tiba.
func handover(order_id: int) -> bool:
	var order: Dictionary = order_by_id(order_id)
	if order.is_empty():
		return false
	var meta: Dictionary = _meta.get(order_id, {})
	if meta.is_empty():
		return false
	if _is_closed(String(order.get("state", ""))):
		return false
	if not bool(meta.get("packed", false)):
		return false
	if not bool(meta.get("driver_here", false)):
		return false
	_complete(order, meta)
	return true


## Pesanan dengan id tertentu; {} bila sudah tidak ada di tablet.
func order_by_id(order_id: int) -> Dictionary:
	for e: Variant in _orders:
		var o: Dictionary = e
		if int(o.get("id", -1)) == order_id:
			return o
	return {}


## id pesanan terlama yang siap dikemas sekarang (stok mencukupi), -1 bila tidak ada.
## Disediakan untuk StaffSim agar kasir/baker bisa mengemas otomatis.
func next_packable_order() -> int:
	var stock: Dictionary = _display_stock()
	for e: Variant in _orders:
		var o: Dictionary = e
		var meta: Dictionary = _meta.get(int(o.get("id", -1)), {})
		if meta.is_empty():
			continue
		if bool(meta.get("packed", false)) or bool(meta.get("packing", false)):
			continue
		var items: Dictionary = o.get("items", {})
		var enough: bool = not items.is_empty()
		for k: Variant in items:
			if int(stock.get(String(k), 0)) < int(items[k]):
				enough = false
				break
		if enough:
			return int(o.get("id", -1))
	return -1


## id pesanan yang sudah dikemas dan drivernya sudah menunggu, -1 bila tidak ada.
func next_handover_order() -> int:
	for e: Variant in _orders:
		var o: Dictionary = e
		var meta: Dictionary = _meta.get(int(o.get("id", -1)), {})
		if meta.is_empty():
			continue
		if bool(meta.get("packed", false)) and bool(meta.get("driver_here", false)):
			return int(o.get("id", -1))
	return -1


## Jumlah driver ojol yang saat ini menumpuk di KASIR UTAMA (GDD 3.6.B).
## Nol di toko Tier 3 ke atas karena mereka dilayani Meja Khusus Ojol.
## CustomerSim boleh memakai angka ini untuk mengurangi kapasitas antrean fisik.
func till_occupancy() -> int:
	if not uses_main_till():
		return 0
	var n: int = 0
	for e: Variant in _orders:
		var o: Dictionary = e
		var meta: Dictionary = _meta.get(int(o.get("id", -1)), {})
		if bool(meta.get("driver_here", false)):
			n += 1
	return n


## Benar bila driver ojol masih harus mengantre di kasir utama (lokasi Tier 1-2).
func uses_main_till() -> bool:
	return not LocationDB.has_pickup_counter(GameState.location_tier)


## Pengali frekuensi order dari bintang RotiFood (GDD 3.6.C & 9.2).
func rating_multiplier() -> float:
	var r: float = clampf(GameState.rotifood_rating, 1.0, 5.0)
	if r >= BADGE_RATING:
		return 1.0 + BADGE_ORDER_BOOST
	var span: float = BADGE_RATING - RATING_PIVOT
	if span <= 0.0:
		return 1.0
	var m: float = 1.0 + BADGE_ORDER_BOOST * (r - RATING_PIVOT) / span
	return maxf(MIN_ORDER_RATE_MULT, m)


## Benar bila toko memegang badge "Toko Terpercaya" (GDD 9.2).
func has_badge() -> bool:
	return GameState.rotifood_rating >= BADGE_RATING


## Lonjakan order hari ini dalam persen, mis. 180 untuk pengali 2.8 (GDD 10.2).
func surge_percent() -> int:
	return int(roundf((_weather_mult - 1.0) * 100.0))


## Perkiraan jumlah order per jam in-game pada kondisi saat ini (untuk UI/debug).
func orders_per_hour() -> float:
	var racks: int = maxi(1, LocationDB.rack_slots(GameState.location_tier))
	return BASE_ORDERS_PER_HOUR_PER_RACK * float(racks) * rating_multiplier() * _weather_mult


# ---------------------------------------------------------------------------
# Detak pesanan
# ---------------------------------------------------------------------------

func _tick_orders(delta: float) -> void:
	# Iterasi di atas salinan: _complete()/_cancel() mencabut pesanan dari _orders.
	for e: Variant in _orders.duplicate():
		var order: Dictionary = e
		var oid: int = int(order.get("id", -1))
		var meta: Dictionary = _meta.get(oid, {})
		if meta.is_empty():
			continue

		order["elapsed"] = float(order.get("elapsed", 0.0)) + delta

		# Kedatangan driver ojol (GDD 3.6.A langkah 3).
		if not bool(meta.get("driver_here", false)):
			if float(order["elapsed"]) >= float(order.get("driver_eta", 0.0)):
				meta["driver_here"] = true
				meta["ready_on_arrival"] = bool(meta.get("packed", false))
		else:
			order["driver_wait"] = float(order.get("driver_wait", 0.0)) + delta

		# Proses pengemasan berjalan.
		if bool(meta.get("packing", false)):
			meta["pack_left"] = float(meta.get("pack_left", 0.0)) - delta
			if float(meta["pack_left"]) <= 0.0:
				_finish_packing(order, meta)

		# Batas waktu penyiapan habis sebelum pengemasan dimulai (GDD 3.6.C).
		if not bool(meta.get("packed", false)) and not bool(meta.get("packing", false)):
			if float(order["elapsed"]) >= float(order.get("prep_window", 0.0)):
				_cancel(order, meta, "batas_waktu_penyiapan", true)
				continue

		# Driver menyerah setelah melewati pickup window-nya.
		if bool(meta.get("driver_here", false)):
			if float(order.get("driver_wait", 0.0)) >= _pickup_window():
				_cancel(order, meta, "driver_pergi", true)
				continue

		_try_auto_handover(order, meta)
		_refresh_state(order, meta)


func _tick_arrivals(delta: float, hour: float) -> void:
	# Aplikasi hanya menerima order selama toko buka (GDD Seksi 2: 08:00-18:00).
	if hour < GameConfig.HOUR_OPEN or hour >= GameConfig.HOUR_CLOSE:
		return
	_next_in -= delta
	var guard: int = 0
	while _next_in <= 0.0 and guard < 16:
		guard += 1
		if pending_count() < _tablet_capacity():
			_spawn_order(hour)
		_next_in += _next_interval()
	# Pengaman: jangan biarkan utang waktu menumpuk bila batas `guard` tersentuh.
	_next_in = maxf(_next_in, 0.0)


## Jarak waktu nyata ke order berikutnya.
func _next_interval() -> float:
	var per_hour: float = orders_per_hour()
	if per_hour <= 0.0 or GameConfig.SECONDS_PER_GAME_HOUR <= 0.0:
		return 3600.0
	var mean: float = GameConfig.SECONDS_PER_GAME_HOUR / per_hour
	var jitter: float = GameConfig.rng.randf_range(ARRIVAL_JITTER_MIN, ARRIVAL_JITTER_MAX)
	return maxf(0.05, mean * jitter)


## Batas pesanan yang boleh menumpuk di tablet sekaligus; memakai kapasitas antrean
## lokasi (LocationDB.queue_cap) supaya toko kecil tidak dibanjiri order mustahil.
func _tablet_capacity() -> int:
	return maxi(1, LocationDB.queue_cap(GameState.location_tier))


# ---------------------------------------------------------------------------
# Pembuatan pesanan
# ---------------------------------------------------------------------------

func _spawn_order(hour: float) -> void:
	var items: Dictionary = _compose_items(hour)
	if items.is_empty():
		return

	var prep: float = GameConfig.rng.randf_range(PREP_WINDOW_MIN, PREP_WINDOW_MAX)
	var eta_ratio: float = GameConfig.rng.randf_range(DRIVER_ETA_MIN_RATIO, DRIVER_ETA_MAX_RATIO)
	var oid: int = _next_id
	_next_id += 1

	var order: Dictionary = {
		"id": oid,
		"items": items,
		"prep_window": prep,
		"elapsed": 0.0,
		"state": "masuk",
		"driver_eta": prep * eta_ratio,
		"driver_wait": 0.0,
		"value": _order_value(items),
		"tip": 0.0,
		"rainy": WeatherDB.is_rainy(GameState.weather),
	}
	_meta[oid] = {
		"packed": false,
		"packing": false,
		"pack_left": 0.0,
		"driver_here": false,
		"ready_on_arrival": false,
		"prima": false,
		"taken": {},
	}
	_orders.append(order)

	EventBus.delivery_order_received.emit(order)
	# Nada ting-ting-ting tablet RotiFood (GDD 3.6.A langkah 1).
	AudioBus.sfx("chime")


## Menyusun isi pesanan. Warga kota memesan lewat aplikasi, jadi jumlah roti
## diambil dari kebiasaan belanja arketipe warga yang sedang ramai jam itu
## (CustomerDB), sedangkan jenis rotinya mengikuti apa yang tampil di etalase.
func _compose_items(hour: float) -> Dictionary:
	var archetype: String = CustomerDB.pick(GameConfig.rng, hour, GameState.location_tier)
	var want: int = 1
	if not archetype.is_empty():
		want = maxi(1, CustomerDB.bulk_size(archetype, GameConfig.rng))

	var stock: Dictionary = _display_stock()
	if stock.is_empty():
		# Etalase kosong: warga tetap memesan dari daftar menu aplikasi, dan pesanan
		# ini akan batal sendiri bila roti tidak sempat dipanggang (GDD 3.6.C).
		return _menu_items(want)

	var items: Dictionary = {}
	var distinct: int = 0
	while want > 0 and distinct < MAX_DISTINCT_ITEMS and not stock.is_empty():
		var rid: String = _weighted_pick(stock)
		if rid.is_empty():
			break
		var avail: int = int(stock.get(rid, 0))
		stock.erase(rid)
		if avail <= 0:
			continue
		var n: int = mini(want, avail)
		items[rid] = int(items.get(rid, 0)) + n
		want -= n
		distinct += 1

	if items.is_empty():
		return _menu_items(1)
	return items


## Pesanan dari daftar menu aplikasi (resep yang sudah terbuka), dipakai saat rak kosong.
func _menu_items(want: int) -> Dictionary:
	var pool: Dictionary = {}
	for e: Variant in GameState.unlocked_recipes:
		var rid: String = String(e)
		if RecipeDB.entry(rid).is_empty():
			continue
		pool[rid] = 1
	if pool.is_empty():
		for rid2: String in RecipeDB.starter():
			pool[rid2] = 1
	if pool.is_empty():
		return {}
	var pick: String = _weighted_pick(pool)
	if pick.is_empty():
		return {}
	return {pick: maxi(1, want)}


## Undi satu resep dari `pool` (recipe_id -> bobot dasar). Resep yang di GDD 5.3
## ditandai favorit delivery / penggemar RotiFood mendapat bobot ekstra.
func _weighted_pick(pool: Dictionary) -> String:
	var total: float = 0.0
	var keys: Array = pool.keys()
	var weights: Array = []
	for k: Variant in keys:
		var rid: String = String(k)
		var w: float = maxf(0.0, float(pool[k]))
		if _is_delivery_favorite(rid):
			w *= FAVORITE_WEIGHT
		weights.append(w)
		total += w
	if total <= 0.0 or keys.is_empty():
		return ""
	var roll: float = GameConfig.rng.randf() * total
	var acc: float = 0.0
	for i: int in range(keys.size()):
		acc += float(weights[i])
		if roll < acc:
			return String(keys[i])
	return String(keys[keys.size() - 1])


func _is_delivery_favorite(recipe_id: String) -> bool:
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return false
	var targets: Array = rec.get("targets", [])
	return targets.has("driver_ojol")


## Nilai pesanan memakai harga jual per buah yang sedang dipasang pemain.
func _order_value(items: Dictionary) -> float:
	var v: float = 0.0
	for k: Variant in items:
		v += GameState.recipe_price(String(k)) * float(int(items[k]))
	return v


# ---------------------------------------------------------------------------
# Pengemasan & serah terima
# ---------------------------------------------------------------------------

## Lama membungkus roti ke paper bag. Bila ada kasir aktif, dialah yang mengemas
## sehingga lamanya = waktu layan kasir tersebut (StaffDB.speed lewat StaffSim).
## Tanpa kasir, pemain sendiri yang mengemas: tap-nya langsung selesai (0 detik).
func _pack_duration() -> float:
	var st: Node = _staff_system()
	if st != null and st.has_method("service_time"):
		return maxf(0.0, float(st.call("service_time", "driver_ojol", -1)))
	var best: Dictionary = GameState.best_staff("kasir")
	if best.is_empty():
		return 0.0
	var db: Dictionary = StaffDB.entry(String(best.get("staff_id", "")))
	if db.is_empty():
		return 0.0
	return maxf(0.0, float(db.get("speed", 0.0)))


func _finish_packing(order: Dictionary, meta: Dictionary) -> void:
	meta["packing"] = false
	meta["packed"] = true
	meta["pack_left"] = 0.0
	_refresh_state(order, meta)
	EventBus.delivery_order_packed.emit(order)
	# Gemerisik kantong kertas cokelat (GDD 3.6.A langkah 2).
	AudioBus.sfx("paper")


## Serah terima otomatis oleh kasir. Di toko Tier 1-2 driver ikut mengantre di
## kasir utama, jadi serah terima baru bisa jalan saat ada meja kasir yang bebas
## (GDD 3.6.B). Tanpa kasir aktif, pemain harus menyerahkan sendiri lewat handover().
func _try_auto_handover(order: Dictionary, meta: Dictionary) -> void:
	if not bool(meta.get("packed", false)):
		return
	if not bool(meta.get("driver_here", false)):
		return
	if GameState.active_staff("kasir").is_empty():
		return
	if not _till_available():
		return
	_complete(order, meta)


## Benar bila ada tempat melayani driver saat ini.
func _till_available() -> bool:
	if not uses_main_till():
		# Meja Khusus Ojol memisahkan alur online 100% dari antrean kasir (GDD 3.6.B).
		return true
	var slots: int = maxi(1, LocationDB.cashier_slots(GameState.location_tier))
	var busy: int = mini(maxi(0, _walk_in_inside), slots)
	return busy < slots


func _complete(order: Dictionary, meta: Dictionary) -> void:
	var wait: float = float(order.get("driver_wait", 0.0))
	var ready_first: bool = bool(meta.get("ready_on_arrival", false))
	# Instant Handover: paket sudah siap saat driver tiba DAN ia menunggu < 3 detik.
	var instant: bool = ready_first and wait < CustomerDB.INSTANT_HANDOVER_SEC
	var late: bool = wait > CustomerDB.DRIVER_WAIT_PENALTY_SEC

	# Tip hanya mengalir pada Instant Handover (GDD 3.6.C: +10% hingga +25% KR).
	var tip: float = 0.0
	if instant:
		var pct: float = GameConfig.rng.randf_range(CustomerDB.TIP_MIN, CustomerDB.TIP_MAX)
		tip = roundf(float(order.get("value", 0.0)) * pct)

	var value: float = float(order.get("value", 0.0))
	order["tip"] = tip
	order["state"] = "selesai"

	var items: Dictionary = order.get("items", {})
	var sold: int = 0
	for k: Variant in items:
		var rid: String = String(k)
		var n: int = int(items[k])
		sold += n
		_delivery_tally[rid] = int(_delivery_tally.get(rid, 0)) + n

	GameState.add_coins(value + tip, "RotiFood #%d" % int(order.get("id", 0)))

	var s: Dictionary = GameState.stats
	s["income_delivery"] = float(s.get("income_delivery", 0.0)) + value
	s["tips"] = float(s.get("tips", 0.0)) + tip
	s["delivery_done"] = int(s.get("delivery_done", 0)) + 1
	s["bread_sold"] = int(s.get("bread_sold", 0)) + sold
	_update_best_recipe()

	_remove(order)
	AudioBus.sfx("coin")
	EventBus.delivery_order_handover.emit(order, tip)

	# Dampak rating RotiFood -- tabel GDD 9.2 (satu baris per pesanan).
	if instant:
		_apply_rating(RATING_INSTANT_HANDOVER, "instant_handover")
	elif late:
		_apply_rating(RATING_DRIVER_WAITED, "driver_menunggu_lama")
	else:
		_apply_rating(RATING_READY_IN_WINDOW, "siap_dalam_batas_waktu")
	if bool(meta.get("prima", false)):
		_apply_rating(RATING_PRIMA_BONUS, "roti_prima")


## Membatalkan pesanan. `penalize` false dipakai saat toko tutup / permainan di-reset,
## yaitu keadaan yang bukan kesalahan pemain.
func _cancel(order: Dictionary, meta: Dictionary, reason: String, penalize: bool) -> void:
	order["state"] = "batal"
	order["tip"] = 0.0
	_return_packed_bread(meta)
	_remove(order)

	if penalize:
		var s: Dictionary = GameState.stats
		s["delivery_cancelled"] = int(s.get("delivery_cancelled", 0)) + 1
		AudioBus.sfx("sad")

	# Sinyal tetap dipancarkan agar lapisan dunia membersihkan driver dan
	# memainkan animasi kecewa (sweat drop, GDD 3.6.C).
	EventBus.delivery_order_expired.emit(order)

	if penalize:
		_apply_rating(RATING_CANCELLED, reason)
		EventBus.toast.emit("Pesanan RotiFood batal!", "warning")


## Roti yang terlanjur dikemas dikembalikan ke rak saat pesanan batal, supaya tidak
## ada roti yang hilang begitu saja dari pembukuan toko.
func _return_packed_bread(meta: Dictionary) -> void:
	var taken: Dictionary = meta.get("taken", {})
	if taken.is_empty():
		return
	for k: Variant in taken:
		var rid: String = String(k)
		var by_quality: Dictionary = taken[k]
		for q: Variant in by_quality:
			var n: int = int(by_quality[q])
			if n > 0:
				GameState.display_add(rid, n, String(q), _hour)
	meta["taken"] = {}


func _refresh_state(order: Dictionary, meta: Dictionary) -> void:
	var st: String = String(order.get("state", ""))
	if _is_closed(st):
		return
	if bool(meta.get("packing", false)):
		order["state"] = "dikemas"
	elif bool(meta.get("driver_here", false)):
		order["state"] = "driver_menunggu"
	elif bool(meta.get("packed", false)):
		order["state"] = "siap"
	else:
		order["state"] = "masuk"


func _is_closed(state: String) -> bool:
	return state == "selesai" or state == "batal"


func _remove(order: Dictionary) -> void:
	var oid: int = int(order.get("id", -1))
	_meta.erase(oid)
	for i: int in range(_orders.size()):
		var o: Dictionary = _orders[i]
		if int(o.get("id", -1)) == oid:
			_orders.remove_at(i)
			return


## Mengosongkan tablet. `silent` = tanpa sinyal apa pun (reset/hari baru).
func _clear_all(silent: bool, penalize: bool) -> void:
	for e: Variant in _orders.duplicate():
		var order: Dictionary = e
		var meta: Dictionary = _meta.get(int(order.get("id", -1)), {})
		if silent:
			_return_packed_bread(meta)
			order["state"] = "batal"
			_remove(order)
		else:
			_cancel(order, meta, "toko_tutup", penalize)
	_orders.clear()
	_meta.clear()


# ---------------------------------------------------------------------------
# Rak display
# ---------------------------------------------------------------------------

## Isi etalase saat ini: recipe_id -> jumlah.
func _display_stock() -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in GameState.display_slots:
		var s: Dictionary = e
		var rid: String = String(s.get("recipe_id", ""))
		if rid.is_empty():
			continue
		out[rid] = int(out.get(rid, 0)) + int(s.get("count", 0))
	return out


## Kualitas roti yang akan terambil bila display_take() dipanggil sekarang.
## Urutannya meniru GameState.display_take(): slot paling depan lebih dulu.
func _peek_qualities(recipe_id: String, count: int) -> Dictionary:
	var out: Dictionary = {}
	var slots: Array = GameState.display_slots.duplicate()
	slots.sort_custom(_cmp_slot)
	var left: int = count
	for e: Variant in slots:
		if left <= 0:
			break
		var s: Dictionary = e
		if String(s.get("recipe_id", "")) != recipe_id:
			continue
		var n: int = mini(int(s.get("count", 0)), left)
		if n <= 0:
			continue
		var q: String = String(s.get("quality", "normal"))
		out[q] = int(out.get(q, 0)) + n
		left -= n
	return out


## Memotong catatan kualitas agar totalnya pas `total` butir.
func _trim_qualities(qualities: Dictionary, total: int) -> Dictionary:
	var out: Dictionary = {}
	var left: int = total
	for k: Variant in qualities:
		if left <= 0:
			break
		var n: int = mini(int(qualities[k]), left)
		if n <= 0:
			continue
		out[String(k)] = n
		left -= n
	return out


func _cmp_slot(a: Dictionary, b: Dictionary) -> bool:
	var ia: int = int(a.get("rack", 0)) * GameConfig.SLOTS_PER_RACK + int(a.get("slot", 0))
	var ib: int = int(b.get("rack", 0)) * GameConfig.SLOTS_PER_RACK + int(b.get("slot", 0))
	return ia < ib


# ---------------------------------------------------------------------------
# Reputasi, cuaca, dan statistik
# ---------------------------------------------------------------------------

## Menerapkan delta rating RotiFood LEWAT ReputationSystem (ARCHITECTURE 7.0).
## DeliverySim tidak pernah menulis GameState.rotifood_rating selama sistem reputasi
## menyediakan salah satu metode pada REP_METHODS.
func _apply_rating(delta: float, reason: String) -> void:
	if is_zero_approx(delta):
		return
	var rep: Node = _rep_system()
	if rep != null:
		for m: String in REP_METHODS:
			if not rep.has_method(m):
				continue
			if _method_arg_count(rep, m) >= 2:
				rep.call(m, delta, reason)
			else:
				rep.call(m, delta)
			return
	_fallback_rating(delta)


func _rep_system() -> Node:
	if _rep_cache != null and is_instance_valid(_rep_cache):
		return _rep_cache
	_rep_cache = _system("rep")
	return _rep_cache


## StaffSim dipakai untuk menanyakan lama kerja kasir saat mengemas pesanan ojol.
func _staff_system() -> Node:
	if _staff_cache != null and is_instance_valid(_staff_cache):
		return _staff_cache
	_staff_cache = _system("staff")
	return _staff_cache


## Mengambil sistem saudara dari Main.systems (ARCHITECTURE 7). null bila belum ada.
func _system(key: String) -> Node:
	if _main == null or not is_instance_valid(_main):
		return null
	var raw: Variant = _main.get("systems")
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var sys: Dictionary = raw
	var node: Variant = sys.get(key)
	if node is Node:
		return node as Node
	return null


func _method_arg_count(obj: Object, method: String) -> int:
	for e: Variant in obj.get_method_list():
		var m: Dictionary = e
		if String(m.get("name", "")) != method:
			continue
		var args: Array = m.get("args", [])
		return args.size()
	return 0


## Jaring pengaman bila ReputationSystem belum terpasang (mis. uji headless sebagian).
## Rating tetap dijaga di rentang sah 1.0-5.0 agar permainan tidak pernah rusak.
func _fallback_rating(delta: float) -> void:
	if not _warned_rep:
		_warned_rep = true
		push_warning("DeliverySim: ReputationSystem tidak ditemukan; rating RotiFood ditulis langsung.")
	GameState.rotifood_rating = clampf(GameState.rotifood_rating + delta, 1.0, 5.0)
	EventBus.rating_changed.emit(GameState.store_rating, GameState.rotifood_rating)


## Pengali frekuensi order dari cuaca (GDD 10.2: hujan +150% .. +200%).
## WeatherSim adalah pengundi tunggal pengali harian; DeliverySim hanya membacanya
## agar seluruh sistem sepakat pada angka lonjakan yang sama. Bila WeatherSim belum
## terpasang (uji headless sebagian), undi sendiri dari WeatherDB.
func _resample_weather() -> void:
	var weather_sys: Node = _system("weather")
	if weather_sys != null and weather_sys.has_method("delivery_multiplier"):
		_weather_mult = float(weather_sys.call("delivery_multiplier"))
	else:
		_weather_mult = WeatherDB.sample_delivery(GameState.weather, GameConfig.rng)
	if _weather_mult <= 0.0:
		_weather_mult = 1.0
	# Dipakai DialogDB.highlights() untuk kalimat lonjakan hujan (GDD 11.3).
	GameState.stats["delivery_surge_pct"] = surge_percent()


## Batas toleransi penjemputan driver ojol (CustomerDB.pickup_window, GDD 3.6.B).
func _pickup_window() -> float:
	var d: Dictionary = CustomerDB.entry("driver_ojol")
	var w: float = float(d.get("pickup_window", 0.0))
	if w <= 0.0:
		return PREP_WINDOW_MAX
	return w


## Memperbarui resep terlaris hari ini bila penjualan delivery melampaui catatan
## yang ada. Penjualan kasir fisik dicatat CustomerSim dengan cara yang sama.
func _update_best_recipe() -> void:
	var s: Dictionary = GameState.stats
	var best_id: String = String(s.get("best_recipe", ""))
	var best_n: int = int(s.get("best_recipe_count", 0))
	for k: Variant in _delivery_tally:
		var n: int = int(_delivery_tally[k])
		if n > best_n:
			best_n = n
			best_id = String(k)
	s["best_recipe"] = best_id
	s["best_recipe_count"] = best_n


# ---------------------------------------------------------------------------
# Pantauan antrean kasir lewat EventBus (GDD 3.6.B)
# ---------------------------------------------------------------------------

func _on_customer_spawned(_c: Dictionary) -> void:
	# Batas atas memakai kapasitas antrean lokasi agar hitungan tidak melenceng
	# bila ada pelanggan yang tidak sempat mengirim sinyal penutup.
	var cap: int = maxi(1, LocationDB.queue_cap(GameState.location_tier))
	_walk_in_inside = mini(_walk_in_inside + 1, cap)


func _on_customer_served(_c: Dictionary, _revenue: float) -> void:
	_walk_in_inside = maxi(0, _walk_in_inside - 1)


func _on_customer_left_angry(_c: Dictionary, _reason: String) -> void:
	_walk_in_inside = maxi(0, _walk_in_inside - 1)


func _on_weather_changed(today: String, _forecast: String) -> void:
	if today.is_empty():
		return
	_resample_weather()
