class_name CustomerSim
extends Node

## CustomerSim — simulasi pelanggan FISIK (walk-in) yang datang ke toko roti,
## memilih roti dari rak display, mengantre di meja kasir, lalu membayar.
##
## Driver ojol BUKAN urusan kelas ini (CustomerDB.walk_in = false untuk
## `driver_ojol`); kedatangan kurir diatur DeliverySim mengikuti arus pesanan
## RotiFood, bukan arus pejalan kaki.
##
## Sistem ini mengikuti antarmuka tick deterministik ARCHITECTURE 7.0:
## setup / sim_tick / on_day_start / on_day_end / reset. TIDAK ADA `_process`
## di sini — `Main` yang memanggil loop, sehingga seluruh hari bisa di-step
## secara headless dan hasilnya bisa diulang persis dari satu benih acak.
## Seluruh keacakan memakai GameConfig.rng.
##
## Bentuk Dictionary pelanggan mengikuti ARCHITECTURE 7.1 PERSIS — tidak ada
## kunci tambahan. Data bantu (kualitas isi keranjang) disimpan di dalam sistem.
##
## Sumber angka: GDD "Perilaku Konsumen", GDD 3.0.C (Mode Solo), GDD 3.1 (kasir),
## GDD 3.3 & GDD 6 (kapasitas antrean per tier lokasi), GDD 8 (kampanye),
## GDD 9.1 (rating toko), GDD 10 (cuaca).

# ---------------------------------------------------------------------------
# Status pelanggan — enum string kanonik ARCHITECTURE 7.1
# ---------------------------------------------------------------------------

const STATE_ENTER: String = "masuk"
const STATE_BROWSE: String = "memilih"
const STATE_QUEUE: String = "antre"
const STATE_SERVED: String = "dilayani"
const STATE_DONE: String = "selesai"
const STATE_LEFT: String = "kabur"

# ---------------------------------------------------------------------------
# Alasan pelanggan pergi marah — payload EventBus.customer_left_angry
# ---------------------------------------------------------------------------

## Antrean toko sudah penuh sesuai kapasitas lokasi (GDD 6). Inilah wujud nyata
## peringatan GDD 8.3: iklan tinggi tanpa kasir/dapur memadai = "antrean meledak".
const REASON_QUEUE_FULL: String = "antrean_penuh"

## Kesabaran habis saat mengantre (GDD 9.1 "pelanggan yang kabur karena antrean
## terlalu panjang"). Dipakai juga untuk pelanggan yang belum terlayani sampai tutup.
const REASON_QUEUE_LONG: String = "antrean_lama"

## Rak display kosong saat pelanggan hendak memilih atau saat tiba di kasir
## (GDD 9.1 "stok habis saat pelanggan sudah di kasir").
const REASON_OUT_OF_STOCK: String = "stok_habis"

## Harga jual di atas batas kemampuan arketipe (GDD "Perilaku Konsumen":
## anak sekolah "mengeluh jika harga terlalu mahal").
const REASON_TOO_EXPENSIVE: String = "harga_mahal"

## Toko keburu tutup pukul 18:00 sementara pelanggan masih di dalam.
const REASON_CLOSING: String = "toko_tutup"

# ---------------------------------------------------------------------------
# Kualitas roti — enum string kanonik ARCHITECTURE 2.5
# ---------------------------------------------------------------------------

const QUALITY_PRIMA: String = "prima"

## Kualitas yang dicatat sebagai "roti gosong terjual" untuk sorotan GDD 11.3.
const BURNT_QUALITIES: Array[String] = ["hampir_gosong", "gosong"]

## ID arketipe kritikus VIP (ARCHITECTURE 2.4).
const VIP_ID: String = "food_vlogger"

# ---------------------------------------------------------------------------
# Arus pengunjung
# ---------------------------------------------------------------------------

## Calon pembeli per JAM in-game untuk setiap satu slot "Kapasitas Antrean Toko"
## (GDD 6: 4 / 8 / 14 / 20 / 35 pembeli). GDD tidak pernah menyebut angka
## kedatangan per jam, jadi kapasitas antrean dipakai sebagai ukuran resmi
## seberapa ramai sebuah lokasi. Tier 1 => 4 x 0.4 = 1.6 pembeli/jam pada rating
## awal, kira-kira sepadan dengan 1 rak display Tier 1 (50 roti) per hari.
const VISITORS_PER_QUEUE_SLOT: float = 0.4

## GDD 9.1: "Semakin tinggi rating toko, semakin banyak warga kota yang datang
## berbelanja setiap harinya." GDD tidak memberi tabel angkanya, jadi dipakai
## hubungan lurus: rating awal 3.0 => 1.0x, tiap bintang menambah 20% pengunjung
## (rating 0.0 => 0.4x, rating 5.0 => 1.4x).
const RATING_BASE_MULT: float = 0.40
const RATING_MULT_PER_STAR: float = 0.20

## Toko berhenti menerima pembeli baru setengah jam in-game sebelum tutup agar
## antrean terakhir sempat terurai sebelum pintu ditutup pukul 18:00 (GDD 11).
const LAST_CALL_HOURS: float = 0.5

## Batas jeda antar kedatangan (detik nyata) — penjaga agar loop spawn tidak
## pernah berputar tanpa henti walau arus pengunjung melonjak ekstrem.
const MIN_SPAWN_GAP_SEC: float = 0.05
const MAX_SPAWN_GAP_SEC: float = 600.0

## Batas jumlah kedatangan yang boleh diproses dalam satu tick.
const MAX_SPAWN_PER_TICK: int = 16

# ---------------------------------------------------------------------------
# Waktu gerak pelanggan (detik NYATA)
# ---------------------------------------------------------------------------

## Berjalan dari pintu masuk ke rak display.
const WALK_IN_SEC: float = 2.0

## Memilih roti di rak: waktu dasar + tambahan per buah yang diincar, sehingga
## emak-emak arisan yang memborong 15 roti memang berlama-lama di depan rak.
const BROWSE_BASE_SEC: float = 2.5
const BROWSE_PER_ITEM_SEC: float = 0.15

## Mode Solo GDD 3.0.C: pemain merangkap kasir sambil mengurus dapur. GDD tidak
## memberi angkanya, jadi dipakai kecepatan Kasir Magang (StaffDB Tier 1 = 7.0
## detik) ditambah 50% karena pemain mengerjakan semuanya sendirian.
const MANUAL_SERVICE_PENALTY: float = 1.5

## Food vlogger memberi ulasan melonjak hanya bila dilayani cepat, yaitu
## menunggu tidak lebih dari separuh kesabarannya (GDD "Perilaku Konsumen":
## "Jika pelayanannya cepat dan rotinya berkualitas prima").
const VIP_FAST_RATIO: float = 0.5

# ---------------------------------------------------------------------------
# Keadaan internal
# ---------------------------------------------------------------------------

var _main: Node = null

## Pelanggan yang sedang berada di dalam toko, URUT KEDATANGAN (FIFO antrean).
var _customers: Array = []

## Jalur kasir paralel (GDD 3.1: lebih dari satu meja kasir membagi beban antrean).
var _lanes: Array = []

var _next_id: int = 1

## Detik nyata menuju kedatangan berikutnya (proses Poisson dari GameConfig.rng).
var _spawn_gap: float = 0.0

## Pengali arus pejalan kaki hari ini, diundi sekali sehari dari WeatherDB (GDD 10).
var _foot_mult: float = 1.0

## recipe_id -> jumlah terjual hari ini (untuk stats.best_recipe).
var _recipe_sold: Dictionary = {}

## customer_id -> {"total", "prima", "burnt"} kualitas roti di dalam keranjangnya.
## Disimpan di luar Dictionary pelanggan agar bentuk ARCHITECTURE 7.1 tetap utuh.
var _basket_quality: Dictionary = {}

## Akumulasi dampak rating dari food vlogger hari ini.
var _vip_today: float = 0.0

## Dampak rating food vlogger yang dijadwalkan berlaku HARI BERIKUTNYA
## (CustomerDB.rating_delay_days = 1). Diambil ReputationSystem lewat take_vip_impact().
var _vip_pending: Dictionary = {"day": 0, "impact": 0.0}

## Cache arketipe yang memenuhi syarat tier lokasi saat ini.
var _arch_cache: Array = []
var _arch_cache_tier: int = -1


# ---------------------------------------------------------------------------
# Antarmuka sistem simulasi (ARCHITECTURE 7.0)
# ---------------------------------------------------------------------------

func setup(main: Node) -> void:
	_main = main
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	if not EventBus.staff_hired.is_connected(_on_staff_changed):
		EventBus.staff_hired.connect(_on_staff_changed)
	if not EventBus.staff_fired.is_connected(_on_staff_changed):
		EventBus.staff_fired.connect(_on_staff_changed)
	if not EventBus.staff_leave_toggled.is_connected(_on_staff_leave):
		EventBus.staff_leave_toggled.connect(_on_staff_leave)
	if not EventBus.upgrade_purchased.is_connected(_on_upgrade):
		EventBus.upgrade_purchased.connect(_on_upgrade)
	_foot_mult = WeatherDB.sample_foot(GameState.weather, GameConfig.rng)
	_rebuild_lanes()


## `delta` = detik NYATA, `hour` = jam in-game. Dipanggil Main hanya selama
## fase "prep"/"sell"; kedatangan pembeli sendiri dibatasi jam buka toko.
func sim_tick(delta: float, hour: float) -> void:
	if delta <= 0.0:
		return
	_update_spawn(delta, hour)
	_update_customers(delta)
	_update_lanes(delta)


func on_day_start(_day: int) -> void:
	_customers.clear()
	_basket_quality.clear()
	_recipe_sold.clear()
	_spawn_gap = 0.0
	_vip_today = 0.0
	_arch_cache_tier = -1
	_foot_mult = WeatherDB.sample_foot(GameState.weather, GameConfig.rng)
	_rebuild_lanes()


## Toko tutup pukul 18:00. Transaksi yang rotinya sudah berpindah tangan tetap
## diselesaikan agar stok dan kas konsisten; sisanya pulang dengan kecewa.
func on_day_end(_ledger: Dictionary) -> void:
	_flush_customers()
	if not is_zero_approx(_vip_today):
		var due: int = GameState.day + 1
		var prev_day: int = int(_vip_pending.get("day", 0))
		if prev_day > 0:
			due = mini(due, prev_day)
		_vip_pending = {
			"day": due,
			"impact": float(_vip_pending.get("impact", 0.0)) + _vip_today,
		}
		_vip_today = 0.0


func reset() -> void:
	_customers.clear()
	_basket_quality.clear()
	_recipe_sold.clear()
	_lanes.clear()
	_next_id = 1
	_spawn_gap = 0.0
	_vip_today = 0.0
	_vip_pending = {"day": 0, "impact": 0.0}
	_arch_cache.clear()
	_arch_cache_tier = -1
	_foot_mult = WeatherDB.sample_foot(GameState.weather, GameConfig.rng)
	_rebuild_lanes()


# ---------------------------------------------------------------------------
# API publik untuk UI, dunia 3D, dan sistem lain
# ---------------------------------------------------------------------------

## Jumlah pelanggan yang sedang berada di dalam toko. Inilah angka yang dibatasi
## "Kapasitas Antrean Toko" GDD 6 (LocationDB.queue_cap).
func queue_length() -> int:
	return _customers.size()


## Salinan dangkal daftar pelanggan (Dictionary ARCHITECTURE 7.1, urut kedatangan).
func customers() -> Array:
	return _customers.duplicate()


## Pemain mengetuk pelanggan untuk melayaninya langsung (GDD 12.4: satu ketukan
## per aksi). Pelanggan yang diketuk maju ke meja kasir dan transaksinya selesai
## saat itu juga. Kembalikan false bila pelanggan tidak ada atau belum mengantre.
func serve(customer_id: int) -> bool:
	var c: Dictionary = _find(customer_id)
	if c.is_empty():
		return false
	var st: String = String(c.get("state", ""))
	if st != STATE_QUEUE and st != STATE_SERVED:
		return false
	if not _fill_basket(c):
		_leave_angry(c, REASON_OUT_OF_STOCK)
		return false
	c["state"] = STATE_SERVED
	var lane: Dictionary = _lane_of(c)
	if lane.is_empty():
		lane = {"serving_id": -1, "tip_chance": 0.0}
	_complete(c, lane)
	return true


## Jumlah jalur kasir yang sedang terbuka (minimal 1, yaitu pemain sendiri).
func lane_count() -> int:
	return _lanes.size()


## Dampak rating Food Vlogger yang sudah jatuh tempo untuk `day`, lalu dikosongkan.
## GDD "Perilaku Konsumen": rating toko melonjak/anjlok KEESOKAN harinya, sehingga
## ReputationSystem memanggil ini pada on_day_start, bukan saat pelanggan dilayani.
func take_vip_impact(day: int) -> float:
	var due: int = int(_vip_pending.get("day", 0))
	var impact: float = float(_vip_pending.get("impact", 0.0))
	if due <= 0 or day < due or is_zero_approx(impact):
		return 0.0
	_vip_pending = {"day": 0, "impact": 0.0}
	return impact


## Dampak VIP yang masih menunggu giliran (tanpa mengosongkannya) — untuk UI/debug.
func pending_vip_impact() -> float:
	return float(_vip_pending.get("impact", 0.0))


# ---------------------------------------------------------------------------
# Kedatangan pelanggan
# ---------------------------------------------------------------------------

func _update_spawn(delta: float, hour: float) -> void:
	if not _is_open(hour):
		return
	var rate: float = _arrival_rate_per_second(hour)
	if rate <= 0.0:
		return
	_spawn_gap -= delta
	var guard: int = 0
	while _spawn_gap <= 0.0 and guard < MAX_SPAWN_PER_TICK:
		guard += 1
		_spawn_one(hour)
		_spawn_gap += _draw_gap(rate)
	if _spawn_gap <= 0.0:
		_spawn_gap = MIN_SPAWN_GAP_SEC


## Toko buka pukul 08:00 dan berhenti menerima pembeli baru menjelang 18:00.
func _is_open(hour: float) -> bool:
	if hour < GameConfig.HOUR_OPEN:
		return false
	return hour < GameConfig.HOUR_CLOSE - LAST_CALL_HOURS


## Jeda antar kedatangan berdistribusi eksponensial (proses Poisson) agar arus
## pengunjung terasa alami namun tetap bisa diulang persis dari benih GameConfig.rng.
func _draw_gap(rate_per_sec: float) -> float:
	if rate_per_sec <= 0.0:
		return MAX_SPAWN_GAP_SEC
	var u: float = clampf(GameConfig.rng.randf(), 0.000001, 0.999999)
	var gap: float = -log(1.0 - u) / rate_per_sec
	return clampf(gap, MIN_SPAWN_GAP_SEC, MAX_SPAWN_GAP_SEC)


func _arrival_rate_per_second(hour: float) -> float:
	if GameConfig.SECONDS_PER_GAME_HOUR <= 0.0:
		return 0.0
	var per_hour: float = _arrival_rate_per_hour(hour)
	if per_hour <= 0.0:
		return 0.0
	return per_hour / GameConfig.SECONDS_PER_GAME_HOUR


## Arus kedatangan per JAM in-game = ukuran lokasi x rating toko x kampanye
## x cuaca x kepadatan jam tersebut.
func _arrival_rate_per_hour(hour: float) -> float:
	var cap: int = maxi(1, LocationDB.queue_cap(GameState.location_tier))
	var base: float = float(cap) * VISITORS_PER_QUEUE_SLOT
	# (a) GDD 9.1 — rating toko.
	var rating_mult: float = maxf(0.0, RATING_BASE_MULT + RATING_MULT_PER_STAR * GameState.store_rating)
	# (b) GDD 8.1 — peningkatan pengunjung kampanye yang sedang aktif.
	var campaign_mult: float = 1.0 + _campaign_boost()
	# (c) GDD 10 — pengali arus pejalan kaki menurut cuaca hari ini.
	var weather_mult: float = maxf(0.0, _foot_mult)
	# (d) GDD "Perilaku Konsumen" — jam sibuk tiap arketipe.
	var hour_mult: float = _hour_volume_mult(hour)
	return base * rating_mult * campaign_mult * weather_mult * hour_mult


## Kepadatan jam `hour` dibanding hari rata-rata, diturunkan dari bobot puncak
## CustomerDB: pekerja kantoran membludak 08:00-10:00, anak sekolah sore hari.
func _hour_volume_mult(hour: float) -> float:
	var flat: float = 0.0
	var now: float = 0.0
	for e: Variant in _archetypes():
		var a: Dictionary = e
		var w: float = float(a.get("weight", 0.0))
		flat += w
		if not bool(a.get("has_peak", false)):
			now += w
		elif CustomerDB.is_peak(String(a.get("id", "")), hour):
			now += w * CustomerDB.PEAK_MULT
		else:
			now += w * CustomerDB.OFFPEAK_MULT
	if flat <= 0.0:
		return 1.0
	return now / flat


## Arketipe pembeli fisik yang boleh muncul di tier lokasi saat ini.
func _archetypes() -> Array:
	if _arch_cache_tier == GameState.location_tier:
		return _arch_cache
	_arch_cache = []
	_arch_cache_tier = GameState.location_tier
	for id: String in CustomerDB.walk_in_ids():
		var d: Dictionary = CustomerDB.entry(id)
		if d.is_empty():
			continue
		if GameState.location_tier < int(d.get("min_store_tier", 1)):
			continue
		var w: float = float(d.get("spawn_weight", 0.0))
		if w <= 0.0:
			continue
		var peaks: Array = d.get("peak_hours", [])
		_arch_cache.append({"id": id, "weight": w, "has_peak": not peaks.is_empty()})
	return _arch_cache


func _campaign_tier() -> int:
	if GameState.campaign.is_empty():
		return 0
	if int(GameState.campaign.get("days_left", 0)) <= 0:
		return 0
	return clampi(int(GameState.campaign.get("tier", 0)), 0, 5)


func _campaign_boost() -> float:
	var tier: int = _campaign_tier()
	if tier <= 0:
		return 0.0
	return maxf(0.0, MarketingDB.visitor_boost(tier))


## Undi arketipe memakai bobot jam CustomerDB.weights_for(), lalu condongkan ke
## "Target Pelanggan Utama" kampanye yang aktif (GDD 8.1 & 8.2).
func _pick_archetype(hour: float) -> String:
	var weights: Dictionary = CustomerDB.weights_for(hour, GameState.location_tier)
	if weights.is_empty():
		return ""
	var tier: int = _campaign_tier()
	var targets: Array = []
	var target_boost: float = 0.0
	var vip_bonus: float = 0.0
	if tier > 0:
		targets = MarketingDB.targets(tier)
		target_boost = maxf(0.0, MarketingDB.visitor_boost(tier))
		vip_bonus = maxf(0.0, MarketingDB.vip_chance_bonus(tier))

	var adjusted: Dictionary = {}
	var total: float = 0.0
	for k: Variant in weights:
		var id: String = String(k)
		var w: float = float(weights[k])
		if w <= 0.0:
			continue
		if targets.has(id):
			w *= 1.0 + target_boost
		# GDD 8.2 butir 4: kampanye Tier 4 menaikkan peluang kedatangan
		# Kritikus Makanan VIP sebesar +40%.
		if id == VIP_ID and vip_bonus > 0.0:
			w *= 1.0 + vip_bonus
		adjusted[id] = w
		total += w
	if total <= 0.0:
		return ""

	var pick: float = GameConfig.rng.randf() * total
	var last: String = ""
	for k2: Variant in adjusted:
		last = String(k2)
		pick -= float(adjusted[k2])
		if pick <= 0.0:
			return last
	return last


func _spawn_one(hour: float) -> void:
	var arch: String = _pick_archetype(hour)
	if arch.is_empty():
		return
	var db: Dictionary = CustomerDB.entry(arch)
	if db.is_empty():
		return
	var c: Dictionary = _new_customer(arch, db, hour)

	# GDD 11.1 "Total Pelanggan Fisik": dihitung sejak pelanggan TIBA, bukan saat
	# transaksinya berhasil. Kalau hanya yang terlayani yang dihitung, angkanya
	# jadi kembaran jumlah transaksi dan tidak sebanding dengan baris
	# "customers_angry" tepat di bawahnya pada nota harian.
	_stat_add_i("customers_total", 1)

	# GDD 6: antrean toko tidak boleh melewati kapasitas lokasi. Calon pembeli
	# yang melihat antrean sudah penuh langsung berbalik pergi — inilah kegagalan
	# "antrean meledak" akibat iklan berlebihan yang diperingatkan GDD 8.3.
	var cap: int = maxi(1, LocationDB.queue_cap(GameState.location_tier))
	if _customers.size() >= cap:
		_leave_angry(c, REASON_QUEUE_FULL)
		return

	if arch == VIP_ID:
		# GDD 11.3: sorotan "Pelanggan VIP hadir" muncul begitu ia datang.
		GameState.stats["vip_visited"] = true
	_customers.append(c)
	EventBus.customer_spawned.emit(c)


## Pelanggan baru dalam bentuk PERSIS ARCHITECTURE 7.1.
func _new_customer(arch: String, db: Dictionary, hour: float) -> Dictionary:
	var c: Dictionary = {
		"id": _next_id,
		"archetype": arch,
		"want": [],
		"count": maxi(1, CustomerDB.bulk_size(arch, GameConfig.rng)),
		"patience": maxf(1.0, float(db.get("patience", 30.0))),
		"waited": 0.0,
		"state": STATE_ENTER,
		"cashier_index": -1,
		"spawn_hour": hour,
		"basket": {},
		"paid": 0.0,
	}
	_next_id += 1
	var scan: Dictionary = _scan_display(arch)
	c["want"] = scan.get("want", [])
	return c


# ---------------------------------------------------------------------------
# Perjalanan pelanggan di dalam toko
# ---------------------------------------------------------------------------

func _update_customers(delta: float) -> void:
	# Bekerja di atas salinan karena pelanggan bisa dikeluarkan di tengah iterasi.
	var snapshot: Array = _customers.duplicate()
	for e: Variant in snapshot:
		var c: Dictionary = e
		var st: String = String(c.get("state", ""))
		if st == STATE_ENTER:
			c["waited"] = float(c.get("waited", 0.0)) + delta
			if float(c["waited"]) >= WALK_IN_SEC:
				c["waited"] = 0.0
				c["state"] = STATE_BROWSE
		elif st == STATE_BROWSE:
			c["waited"] = float(c.get("waited", 0.0)) + delta
			if float(c["waited"]) >= _browse_time(c):
				_finish_browsing(c)
		elif st == STATE_QUEUE:
			# GDD 3.1 Tier 3: "Menurunkan tingkat stres antrean pelanggan sebesar
			# -15%", yakni kesabaran terkuras 15% lebih lambat di jalur kasir itu.
			var lane: Dictionary = _lane_of(c)
			var stress: float = 0.0
			if not lane.is_empty():
				stress = float(lane.get("stress", 0.0))
			c["waited"] = float(c.get("waited", 0.0)) + delta * maxf(0.0, 1.0 + stress)
			if float(c["waited"]) >= float(c.get("patience", 1.0)):
				_leave_angry(c, REASON_QUEUE_LONG)


func _browse_time(c: Dictionary) -> float:
	return BROWSE_BASE_SEC + BROWSE_PER_ITEM_SEC * float(maxi(1, int(c.get("count", 1))))


## Selesai melihat-lihat rak: tetapkan daftar incaran, sesuaikan jumlah beli
## menurut harga, lalu masuk ke jalur kasir terpendek.
func _finish_browsing(c: Dictionary) -> void:
	var arch: String = String(c.get("archetype", ""))
	var scan: Dictionary = _scan_display(arch)
	var want: Array = scan.get("want", [])
	c["want"] = want
	if want.is_empty():
		# Rak kosong melompong (GDD 8.3) atau semua harga di luar jangkauan.
		if bool(scan.get("too_expensive", false)):
			_leave_angry(c, REASON_TOO_EXPENSIVE)
		else:
			_leave_angry(c, REASON_OUT_OF_STOCK)
		return
	_apply_price_mood(c)
	c["waited"] = 0.0
	c["state"] = STATE_QUEUE
	c["cashier_index"] = _shortest_lane()


## Daftar resep yang benar-benar mau dibeli arketipe ini, urut prioritas:
## resep favoritnya lebih dulu (CustomerDB.prefers), lalu apa pun yang tersedia
## di rak. Menolak tier resep di bawah min_recipe_tier, kualitas yang ia tolak,
## dan harga di atas batas kemampuannya.
func _scan_display(arch: String) -> Dictionary:
	var db: Dictionary = CustomerDB.entry(arch)
	var want: Array = []
	var too_expensive: bool = false
	if db.is_empty():
		return {"want": want, "too_expensive": too_expensive}

	var order: Array = []
	var prefers: Array = db.get("prefers", [])
	for v: Variant in prefers:
		var pid: String = String(v)
		if not order.has(pid):
			order.append(pid)
	# Si Galau tidak punya resep favorit (prefers kosong) sehingga langsung
	# mengambil apa saja yang ada di rak.
	for rid_disp: String in _display_recipe_order():
		if not order.has(rid_disp):
			order.append(rid_disp)

	for v2: Variant in order:
		var rid: String = String(v2)
		if _front_stock(rid, arch) <= 0:
			continue
		if not CustomerDB.accepts_recipe_tier(arch, _recipe_tier(rid)):
			continue
		if _too_expensive(arch, rid):
			too_expensive = true
			continue
		want.append(rid)
	return {"want": want, "too_expensive": too_expensive}


## GDD "Perilaku Konsumen": harga di atas sweet spot membuat pembeli berhemat,
## harga di bawah sweet spot membuat mereka senang dan memborong lebih banyak.
func _apply_price_mood(c: Dictionary) -> void:
	var want: Array = c.get("want", [])
	if want.is_empty():
		return
	var db: Dictionary = CustomerDB.entry(String(c.get("archetype", "")))
	if db.is_empty():
		return
	var mood: int = _price_mood(String(want[0]))
	if mood < 0:
		c["count"] = maxi(1, int(db.get("bulk_min", 1)))
	elif mood > 0:
		c["count"] = maxi(int(c.get("count", 1)), maxi(1, int(db.get("bulk_max", 1))))


## -1 = mengeluh (di atas sweet spot), 0 = wajar, 1 = senang (di bawah sweet spot).
func _price_mood(recipe_id: String) -> int:
	var span: Vector2 = RecipeDB.sweet_spot_range(recipe_id)
	var price: float = GameState.recipe_price(recipe_id)
	if span.y > 0.0 and price > span.y:
		return -1
	if span.x > 0.0 and price < span.x:
		return 1
	return 0


## Benar bila harga jual melewati batas kemampuan arketipe ini
## (CustomerDB.budget_factor x harga satuan default resep).
func _too_expensive(arch: String, recipe_id: String) -> bool:
	var ceiling: float = CustomerDB.price_ceiling(arch, RecipeDB.unit_price_default(recipe_id))
	if ceiling <= 0.0:
		return false
	return GameState.recipe_price(recipe_id) > ceiling


func _recipe_tier(recipe_id: String) -> int:
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return 0
	return int(rec.get("tier", 1))


# ---------------------------------------------------------------------------
# Rak display
# ---------------------------------------------------------------------------

func _slot_index(s: Dictionary) -> int:
	return int(s.get("rack", 0)) * GameConfig.SLOTS_PER_RACK + int(s.get("slot", 0))


func _cmp_slot(a: Dictionary, b: Dictionary) -> bool:
	return _slot_index(a) < _slot_index(b)


## Slot berisi resep tertentu, urut dari slot paling depan — urutan yang sama
## dipakai GameState.display_take().
func _slots_for(recipe_id: String) -> Array:
	var out: Array = []
	for e: Variant in GameState.display_slots:
		var s: Dictionary = e
		if String(s.get("recipe_id", "")) != recipe_id:
			continue
		if int(s.get("count", 0)) <= 0:
			continue
		out.append(s)
	out.sort_custom(_cmp_slot)
	return out


## Urutan resep yang terlihat di rak, dari slot paling depan.
func _display_recipe_order() -> Array:
	var slots: Array = GameState.display_slots.duplicate()
	slots.sort_custom(_cmp_slot)
	var out: Array = []
	for e: Variant in slots:
		var s: Dictionary = e
		if int(s.get("count", 0)) <= 0:
			continue
		var rid: String = String(s.get("recipe_id", ""))
		if rid.is_empty() or out.has(rid):
			continue
		out.append(rid)
	return out


## Jumlah roti `recipe_id` di deretan slot terdepan yang kualitasnya masih
## diterima arketipe ini. Berhenti pada slot pertama yang ditolak, karena roti
## itulah yang akan terambil lebih dulu oleh display_take(). Sosialita menolak
## "dingin", "hampir_gosong", dan "gosong" (GDD "Perilaku Konsumen").
func _front_stock(recipe_id: String, arch: String) -> int:
	var total: int = 0
	for e: Variant in _slots_for(recipe_id):
		var s: Dictionary = e
		if not CustomerDB.accepts_quality(arch, String(s.get("quality", "normal"))):
			break
		total += maxi(0, int(s.get("count", 0)))
	return total


## Rincian kualitas `want_n` roti terdepan: {"total", "prima", "burnt"}.
func _front_qualities(recipe_id: String, arch: String, want_n: int) -> Dictionary:
	var out: Dictionary = {"total": 0, "prima": 0, "burnt": 0}
	var left: int = want_n
	for e: Variant in _slots_for(recipe_id):
		if left <= 0:
			break
		var s: Dictionary = e
		var q: String = String(s.get("quality", "normal"))
		if not CustomerDB.accepts_quality(arch, q):
			break
		var n: int = mini(int(s.get("count", 0)), left)
		if n <= 0:
			continue
		left -= n
		out["total"] = int(out["total"]) + n
		if q == QUALITY_PRIMA:
			out["prima"] = int(out["prima"]) + n
		if BURNT_QUALITIES.has(q):
			out["burnt"] = int(out["burnt"]) + n
	return out


## Ambil roti dari rak saat pelanggan tiba di meja kasir. Kembalikan false bila
## tidak ada satu pun roti yang bisa diambil (GDD 9.1: "stok habis saat pelanggan
## sudah di kasir"). Emak-emak arisan memang bisa menguras rak sampai kosong —
## itu fitur, bukan cacat (GDD "Perilaku Konsumen").
func _fill_basket(c: Dictionary) -> bool:
	var basket: Dictionary = c.get("basket", {})
	if not basket.is_empty():
		# Roti sudah terambil sebelumnya (mis. jalur kasir berubah di tengah jalan).
		return true

	var arch: String = String(c.get("archetype", ""))
	var need: int = maxi(1, int(c.get("count", 1)))
	var want: Array = c.get("want", [])
	var q_total: int = 0
	var q_prima: int = 0
	var q_burnt: int = 0

	for v: Variant in want:
		if need <= 0:
			break
		var rid: String = String(v)
		var avail: int = _front_stock(rid, arch)
		if avail <= 0:
			continue
		if _too_expensive(arch, rid):
			continue
		var n: int = mini(avail, need)
		if n <= 0:
			continue
		var q: Dictionary = _front_qualities(rid, arch, n)
		var got: int = GameState.display_take(rid, n)
		if got <= 0:
			continue
		basket[rid] = int(basket.get(rid, 0)) + got
		need -= got
		q_total += got
		q_prima += mini(int(q.get("prima", 0)), got)
		q_burnt += mini(int(q.get("burnt", 0)), got)

	c["basket"] = basket
	if q_total <= 0:
		return false
	_basket_quality[int(c.get("id", -1))] = {
		"total": q_total,
		"prima": q_prima,
		"burnt": q_burnt,
	}
	return true


# ---------------------------------------------------------------------------
# Jalur kasir (GDD 3.1)
# ---------------------------------------------------------------------------

## Susun ulang jalur kasir. Lokasi Tier 3 ke atas punya lebih dari satu meja
## kasir; setiap kasir aktif membuka antrean paralel yang benar-benar membagi
## beban toko (GDD 3.1 "Catatan Kasir", GDD 6 "Slot Meja Kasir").
func _rebuild_lanes() -> void:
	var desks: int = maxi(1, LocationDB.cashier_slots(GameState.location_tier))
	var crew: Array = _sorted_cashiers()
	var count: int = mini(crew.size(), desks)

	var lanes: Array = []
	if count <= 0:
		# GDD 3.0.C Mode Solo: tanpa kasir, pemain melayani sendiri di satu meja.
		lanes.append(_make_lane(0, {}))
	else:
		for i: int in range(count):
			lanes.append(_make_lane(i, crew[i]))

	# Pertahankan transaksi yang sedang berjalan bila jalurnya masih ada.
	for i2: int in range(lanes.size()):
		if i2 >= _lanes.size():
			break
		var old: Dictionary = _lanes[i2]
		var fresh: Dictionary = lanes[i2]
		fresh["serving_id"] = int(old.get("serving_id", -1))
		fresh["elapsed"] = float(old.get("elapsed", 0.0))
		fresh["duration"] = float(old.get("duration", 0.0))

	_lanes = lanes
	_reassign_customers()


func _make_lane(index: int, staff: Dictionary) -> Dictionary:
	var lane: Dictionary = {
		"index": index,
		"staff_id": "",
		"tier": 0,
		"manual": true,
		"base_time": _manual_service_time(),
		"stress": 0.0,
		"galau_speedup": 0.0,
		"tip_chance": 0.0,
		"serving_id": -1,
		"elapsed": 0.0,
		"duration": 0.0,
	}
	if staff.is_empty():
		return lane

	var sid: String = String(staff.get("staff_id", ""))
	var db: Dictionary = StaffDB.entry(sid)
	var tier: int = clampi(int(staff.get("tier", db.get("tier", 1))), 1, 5)
	lane["staff_id"] = sid
	lane["tier"] = tier
	lane["manual"] = false
	# GDD 3.1: kecepatan transaksi 7.0 / 5.0 / 3.5 / 2.2 / 1.2 detik per pelanggan.
	lane["base_time"] = maxf(0.0, StaffDB.speed_for(StaffDB.ROLE_KASIR, tier))
	var extra: Dictionary = db.get("extra", {})
	lane["stress"] = float(extra.get("queue_stress", 0.0))
	lane["galau_speedup"] = float(extra.get("galau_speedup", 0.0))
	lane["tip_chance"] = float(extra.get("tip_chance", 0.0))
	return lane


## Waktu layan saat pemain merangkap kasir (GDD 3.0.C Mode Solo).
func _manual_service_time() -> float:
	return maxf(0.0, StaffDB.speed_for(StaffDB.ROLE_KASIR, 1) * MANUAL_SERVICE_PENALTY)


## Kasir aktif, tier tertinggi lebih dulu; urutan ID menjaga hasil tetap deterministik.
func _sorted_cashiers() -> Array:
	var out: Array = GameState.active_staff(StaffDB.ROLE_KASIR).duplicate()
	out.sort_custom(_cmp_staff)
	return out


func _cmp_staff(a: Dictionary, b: Dictionary) -> bool:
	var ta: int = int(a.get("tier", 0))
	var tb: int = int(b.get("tier", 0))
	if ta != tb:
		return ta > tb
	return String(a.get("staff_id", "")) < String(b.get("staff_id", ""))


## Pindahkan pelanggan yang jalurnya hilang (kasir dipecat/diliburkan) ke jalur
## terpendek yang masih ada, lalu bersihkan jalur yang menunjuk pelanggan basi.
func _reassign_customers() -> void:
	var n: int = _lanes.size()
	if n <= 0:
		return
	for e: Variant in _customers:
		var c: Dictionary = e
		var st: String = String(c.get("state", ""))
		if st != STATE_QUEUE and st != STATE_SERVED:
			continue
		var idx: int = int(c.get("cashier_index", -1))
		if idx >= 0 and idx < n:
			continue
		if st == STATE_SERVED:
			c["state"] = STATE_QUEUE
		c["cashier_index"] = _shortest_lane()

	for i: int in range(n):
		var lane: Dictionary = _lanes[i]
		var sid: int = int(lane.get("serving_id", -1))
		if sid < 0:
			continue
		var cur: Dictionary = _find(sid)
		if cur.is_empty():
			_clear_lane(lane)
			continue
		if String(cur.get("state", "")) != STATE_SERVED or int(cur.get("cashier_index", -1)) != i:
			_clear_lane(lane)


func _shortest_lane() -> int:
	if _lanes.is_empty():
		_rebuild_lanes()
	if _lanes.is_empty():
		return 0
	var best: int = 0
	var best_load: int = -1
	for i: int in range(_lanes.size()):
		var lane_load: int = _lane_load(i)
		if best_load < 0 or lane_load < best_load:
			best_load = lane_load
			best = i
	return best


func _lane_load(index: int) -> int:
	var n: int = 0
	for e: Variant in _customers:
		var c: Dictionary = e
		if int(c.get("cashier_index", -1)) != index:
			continue
		var st: String = String(c.get("state", ""))
		if st == STATE_QUEUE or st == STATE_SERVED:
			n += 1
	return n


func _lane_of(c: Dictionary) -> Dictionary:
	var idx: int = int(c.get("cashier_index", -1))
	if idx < 0 or idx >= _lanes.size():
		return {}
	var lane: Dictionary = _lanes[idx]
	return lane


## Pelanggan paling depan yang masih mengantre di jalur `index` (FIFO kedatangan).
func _head_of(index: int) -> Dictionary:
	for e: Variant in _customers:
		var c: Dictionary = e
		if String(c.get("state", "")) != STATE_QUEUE:
			continue
		if int(c.get("cashier_index", -1)) != index:
			continue
		return c
	return {}


func _clear_lane(lane: Dictionary) -> void:
	lane["serving_id"] = -1
	lane["elapsed"] = 0.0
	lane["duration"] = 0.0


func _release_lane_for(c: Dictionary) -> void:
	var id: int = int(c.get("id", -1))
	for e: Variant in _lanes:
		var lane: Dictionary = e
		if int(lane.get("serving_id", -1)) == id:
			_clear_lane(lane)


# ---------------------------------------------------------------------------
# Transaksi di meja kasir
# ---------------------------------------------------------------------------

func _update_lanes(delta: float) -> void:
	for i: int in range(_lanes.size()):
		var lane: Dictionary = _lanes[i]

		# 0) Jalur MANUAL hanya hidup selama karakter pemain berdiri di mejanya
		#    (GDD 3.0.C: tanpa kasir, pemain melayani sendiri). Transaksi yang
		#    sedang berjalan ikut membeku saat ia pergi -- tidak dibatalkan,
		#    karena pembelinya masih berdiri di depan meja menunggu ia kembali.
		if bool(lane.get("manual", false)) and not _pemain_berjaga(i):
			continue

		# 1) Lanjutkan transaksi yang sedang berjalan.
		var sid: int = int(lane.get("serving_id", -1))
		if sid >= 0:
			var cur: Dictionary = _find(sid)
			if cur.is_empty() or String(cur.get("state", "")) != STATE_SERVED:
				_clear_lane(lane)
			else:
				lane["elapsed"] = float(lane.get("elapsed", 0.0)) + delta
				if float(lane["elapsed"]) >= float(lane.get("duration", 0.0)):
					_complete(cur, lane)

		# 2) Kasir menganggur -> panggil kepala antrean.
		if int(lane.get("serving_id", -1)) < 0:
			var head: Dictionary = _head_of(i)
			if not head.is_empty():
				_start_service(head, lane)


## Apakah karakter pemain sedang berjaga di mesin kasir ke-`lane_index`.
##
## Mengembalikan true bila lapisan tugas pemain tidak ada sama sekali (uji unit
## yang merakit CustomerSim sendirian): sistem pelanggan tidak boleh berhenti
## bekerja hanya karena tetangganya tidak dirakit.
func _pemain_berjaga(lane_index: int) -> bool:
	if _main == null or not is_instance_valid(_main):
		return true
	var sys: Variant = _main.get("systems")
	if not (sys is Dictionary):
		return true
	var pt: PlayerTaskSystem = (sys as Dictionary).get("player") as PlayerTaskSystem
	if pt == null:
		return true
	return pt.manning_lane() == lane_index


func _start_service(c: Dictionary, lane: Dictionary) -> void:
	if not _fill_basket(c):
		_leave_angry(c, REASON_OUT_OF_STOCK)
		return
	c["state"] = STATE_SERVED
	c["cashier_index"] = int(lane.get("index", 0))
	lane["serving_id"] = int(c.get("id", -1))
	lane["elapsed"] = 0.0
	lane["duration"] = _service_time(c, lane)


## Lama proses di kasir: kecepatan kasir terbaik di jalur ini (GDD 3.1) atau
## waktu manual pemain (GDD 3.0.C). Si Galau butuh 2x lebih lama, KECUALI bila
## dilayani Kasir Profesional Tier 4 yang memprosesnya 2x lebih cepat sehingga
## pengali itu tepat ternetralkan (GDD 3.1).
func _service_time(c: Dictionary, lane: Dictionary) -> float:
	var base: float = maxf(0.0, float(lane.get("base_time", 0.0)))
	var mult: float = 1.0
	var db: Dictionary = CustomerDB.entry(String(c.get("archetype", "")))
	if not db.is_empty():
		mult = maxf(0.05, float(db.get("cashier_time_mult", 1.0)))
	var speedup: float = float(lane.get("galau_speedup", 0.0))
	if mult > 1.0 and speedup > 0.0:
		mult = maxf(1.0, mult / speedup)
	return maxf(0.0, base * mult)


func _complete(c: Dictionary, lane: Dictionary) -> void:
	var basket: Dictionary = c.get("basket", {})
	var revenue: float = 0.0
	var sold: int = 0
	for k: Variant in basket:
		var rid: String = String(k)
		var n: int = int(basket[k])
		if n <= 0:
			continue
		revenue += GameState.recipe_price(rid) * float(n)
		sold += n
		_recipe_sold[rid] = int(_recipe_sold.get(rid, 0)) + n
		# Roti terlaris hari ini (GDD 11.1 & 11.3). Nilainya hanya naik, sehingga
		# tetap aman ketika DeliverySim ikut mencatat penjualan online.
		var running: int = int(_recipe_sold[rid])
		if running > int(GameState.stats.get("best_recipe_count", 0)):
			GameState.stats["best_recipe"] = rid
			GameState.stats["best_recipe_count"] = running

	var tip: float = _roll_tip(lane, revenue)
	c["paid"] = revenue + tip
	c["state"] = STATE_DONE

	if revenue + tip > 0.0:
		GameState.add_coins(revenue + tip, "penjualan toko")
	_stat_add_f("income_store", revenue)
	if tip > 0.0:
		_stat_add_f("tips", tip)
	_stat_add_i("bread_sold", sold)

	# GDD 11.3 baris 5: sorotan "Pelanggan komplain roti gosong" butuh jumlah
	# roti gosong yang benar-benar terjual (kunci opsional yang dibaca DialogDB).
	var quality: Dictionary = _basket_quality.get(int(c.get("id", -1)), {})
	var burnt: int = int(quality.get("burnt", 0))
	if burnt > 0:
		_stat_add_i("burned_sold", burnt)

	_track_vip(c, true)

	if int(lane.get("serving_id", -1)) == int(c.get("id", -1)):
		_clear_lane(lane)
	_remove(c)

	AudioBus.sfx("coin")
	EventBus.customer_served.emit(c, revenue + tip)


## GDD 3.1 Tier 5: "Senyuman manis: +5% peluang pelanggan memberi tip koin ekstra."
## GDD tidak menyebut besar tipnya, jadi dipakai rentang tip yang memang tercatat
## di GDD 3.6.C (+10% hingga +25%) lewat konstanta CustomerDB.TIP_MIN/TIP_MAX.
func _roll_tip(lane: Dictionary, revenue: float) -> float:
	if revenue <= 0.0:
		return 0.0
	var chance: float = float(lane.get("tip_chance", 0.0))
	if chance <= 0.0:
		return 0.0
	if GameConfig.rng.randf() >= chance:
		return 0.0
	return revenue * GameConfig.rng.randf_range(CustomerDB.TIP_MIN, CustomerDB.TIP_MAX)


## Pelanggan pergi dengan kecewa. Dipakai juga untuk calon pembeli yang berbalik
## di depan pintu karena antrean penuh — mereka tidak pernah masuk daftar toko,
## sehingga hanya sinyal kemarahannya yang dikirim.
func _leave_angry(c: Dictionary, reason: String) -> void:
	c["state"] = STATE_LEFT
	_stat_add_i("customers_angry", 1)
	_track_vip(c, false)
	_remove(c)
	AudioBus.sfx("sad")
	EventBus.customer_left_angry.emit(c, reason)


## GDD "Perilaku Konsumen": food vlogger membuat rating melonjak bila dilayani
## cepat DAN rotinya prima, tetapi anjlok tajam bila ia kecewa. Dampaknya baru
## terasa keesokan harinya, jadi di sini hanya dicatat untuk ReputationSystem.
func _track_vip(c: Dictionary, served: bool) -> void:
	if String(c.get("archetype", "")) != VIP_ID:
		return
	var db: Dictionary = CustomerDB.entry(VIP_ID)
	var impact: float = absf(float(db.get("rating_impact", 0.0)))
	if impact <= 0.0:
		return
	if not served:
		_vip_today -= impact
		return
	var quality: Dictionary = _basket_quality.get(int(c.get("id", -1)), {})
	var total: int = int(quality.get("total", 0))
	var prima: int = int(quality.get("prima", 0))
	var fast: bool = float(c.get("waited", 0.0)) <= float(c.get("patience", 1.0)) * VIP_FAST_RATIO
	if fast and total > 0 and prima == total:
		_vip_today += impact
	# Selain itu ulasannya netral: tidak menaikkan, tidak menurunkan.


# ---------------------------------------------------------------------------
# Tutup toko
# ---------------------------------------------------------------------------

## Pukul 18:00 pintu tertutup. Pelanggan yang rotinya sudah berpindah tangan
## tetap diselesaikan transaksinya agar stok dan kas tidak pernah bocor.
func _flush_customers() -> void:
	var snapshot: Array = _customers.duplicate()
	for e: Variant in snapshot:
		var c: Dictionary = e
		if String(c.get("state", "")) == STATE_SERVED:
			var lane: Dictionary = _lane_of(c)
			if lane.is_empty():
				lane = {"serving_id": -1, "tip_chance": 0.0}
			_complete(c, lane)
		else:
			_leave_angry(c, REASON_CLOSING)
	_customers.clear()
	_basket_quality.clear()
	for e2: Variant in _lanes:
		var lane2: Dictionary = e2
		_clear_lane(lane2)


# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

func _find(customer_id: int) -> Dictionary:
	for e: Variant in _customers:
		var c: Dictionary = e
		if int(c.get("id", -1)) == customer_id:
			return c
	return {}


func _remove(c: Dictionary) -> void:
	var id: int = int(c.get("id", -1))
	for i: int in range(_customers.size()):
		var other: Dictionary = _customers[i]
		if int(other.get("id", -1)) == id:
			_customers.remove_at(i)
			break
	_basket_quality.erase(id)
	_release_lane_for(c)


func _stat_add_i(key: String, n: int) -> void:
	GameState.stats[key] = int(GameState.stats.get(key, 0)) + n


func _stat_add_f(key: String, v: float) -> void:
	GameState.stats[key] = float(GameState.stats.get(key, 0.0)) + v


# ---------------------------------------------------------------------------
# Reaksi terhadap EventBus
# ---------------------------------------------------------------------------

func _on_weather_changed(today: String, _forecast: String) -> void:
	# GDD 10.2: hujan membuat arus pejalan kaki anjlok 60-80%; GDD 10.3: musim
	# liburan melonjakkan pengunjung fisik. Rentangnya diundi sekali per hari.
	_foot_mult = WeatherDB.sample_foot(today, GameConfig.rng)


func _on_staff_changed(_staff_id: String) -> void:
	_rebuild_lanes()


func _on_staff_leave(_staff_id: String, _on_leave: bool) -> void:
	_rebuild_lanes()


func _on_upgrade(kind: String, _tier: int) -> void:
	if kind == "location":
		_arch_cache_tier = -1
		_rebuild_lanes()
