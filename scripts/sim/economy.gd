class_name EconomySystem
extends Node

## EconomySystem — kas, biaya operasional, dan penyusun ledger harian.
##
## Sesuai ARCHITECTURE 7.0 kelas ini TIDAK memakai _process/_physics_process;
## Main yang memanggil sim_tick(delta, hour) pada posisi ke-8 urutan tetap.
##
## Tiga sumber biaya operasional (GDD Seksi 3 "Sistem Ekonomi & Biaya Operasional"):
##
## 1. Biaya Utilitas — listrik & gas dihitung REAL-TIME menurut lamanya alat
##    menyala (mixer, oven, showcase). Tidak ada pemadaman; akumulasinya
##    ditagihkan sekali saat tutup toko pada layar Daily Summary.
## 2. Bahan Baku Terpakai — nilai bahan yang benar-benar dipakai produksi hari
##    itu, dihargai memakai harga tetap IngredientDB (GDD 5.2, "Fixed Price").
##    Angka ini dipegang ProductionSystem di GameState.stats.spent_ingredients;
##    EconomySystem hanya membacanya agar tidak terhitung dua kali.
##    CATATAN ARUS KAS: kas nyata sudah keluar saat belanja di Pasar, jadi
##    angka ini MURNI akuntansi laba-rugi dan TIDAK dipotong lagi dari kas.
## 3. Gaji Harian — GDD 3.4: gaji otomatis dipotong dari kas pukul 18:00.
##    Staf yang sedang diliburkan tidak digaji; staf yang dipecat tetap dibayar
##    penuh untuk hari itu (pemecatan baru berlaku setelah laporan ditutup).
##
## GDD juga menegaskan: TIDAK ADA Game Over. Bila kas tidak cukup membayar
## tagihan, yang terbayar hanya sebesar sisa kas dan saldo berhenti di 0 KR.

var _main: Node = null

# Akumulator hari berjalan.
var _utility_accum: float = 0.0        # KR utilitas yang sudah terpakai hari ini
var _ingredient_extra: float = 0.0     # KR bahan terpakai di luar ProductionSystem
var _ingredient_units: Dictionary = {} # ingredient_id -> int unit, hanya catatan econ
var _charged_jobs: Dictionary = {}     # job_id -> true, penjaga potong-ganda
var _salary_detail: Array = []         # [{staff_id, name, role, tier, salary}]
var _bailout_today: bool = false

# Cuaca hari ini dibekukan sejak fajar agar WeatherSim boleh mengundi cuaca
# besok kapan pun tanpa mengubah isi laporan hari ini.
var _weather_today: String = "cerah"
var _forecast_today: String = "cerah"

# Penjaga idempoten: satu hari hanya boleh satu kali potong biaya dan satu ledger.
var _settled_day: int = -1
var _published_day: int = -1

# Rujukan sistem lain, di-cache setelah ditemukan di Main.systems.
var _cache: Dictionary = {}


# --- Antarmuka sistem simulasi (ARCHITECTURE 7.0) --------------------------

func setup(main: Node) -> void:
	_main = main
	if not EventBus.bailout_triggered.is_connected(_on_bailout_triggered):
		EventBus.bailout_triggered.connect(_on_bailout_triggered)
	if not EventBus.weather_changed.is_connected(_on_weather_changed):
		EventBus.weather_changed.connect(_on_weather_changed)
	_weather_today = GameState.weather
	_forecast_today = GameState.forecast


## Menumpuk biaya utilitas real-time (GDD Seksi 3 "Utility Cost").
## Rak display menyala sepanjang toko buka; mixer dan oven hanya dihitung saat
## benar-benar bekerja — jumlah unit sibuk ditanyakan kepada ProductionSystem.
func sim_tick(delta: float, hour: float) -> void:
	if delta <= 0.0:
		return
	if _is_time_paused():
		return

	var mixers: int = _busy_units("mixer")
	var ovens: int = _busy_units("oven")
	var displays: int = _active_displays(hour)
	if mixers <= 0 and ovens <= 0 and displays <= 0:
		return

	var per_sec: float = (
		float(mixers) * GameConfig.UTILITY_MIXER_PER_SEC
		+ float(ovens) * GameConfig.UTILITY_OVEN_PER_SEC
		+ float(displays) * GameConfig.UTILITY_DISPLAY_PER_SEC
	)
	if per_sec <= 0.0:
		return

	_utility_accum += delta * per_sec
	GameState.stats["utility"] = _utility_accum


## Fajar hari baru: nolkan seluruh akumulator dan statistik harian.
func on_day_start(_day: int) -> void:
	_reset_accumulators()
	GameState.reset_daily_stats()
	_weather_today = GameState.weather
	_forecast_today = GameState.forecast


## Pukul 18:00: susun ledger lengkap, simpan ke riwayat, siarkan day_ended.
## Dipanggil PALING AKHIR oleh DayCycle agar seluruh sistem lain (termasuk
## ReputationSystem dan BailoutSystem) sudah menyumbang angkanya lebih dulu.
func on_day_end(ledger: Dictionary) -> void:
	# Potongan biaya bersifat idempoten; aman bila Main sudah memanggilnya.
	settle_day()

	if _published_day == GameState.day:
		return
	_published_day = GameState.day

	_fill_ledger(ledger)

	GameState.history.append(_history_entry(ledger))
	var cap: int = maxi(1, GameState.HISTORY_MAX)
	if GameState.history.size() > cap:
		GameState.history = GameState.history.slice(GameState.history.size() - cap, GameState.history.size())

	EventBus.day_ended.emit(ledger)


## Permainan baru / memuat berkas simpanan.
func reset() -> void:
	_reset_accumulators()
	_cache.clear()
	_weather_today = GameState.weather
	_forecast_today = GameState.forecast


# --- Tutup buku ------------------------------------------------------------

## Membekukan angka hari ini lalu memotong utilitas dan gaji dari kas.
## Dipanggil DayCycle SEBELUM ReputationSystem dan BailoutSystem supaya kedua
## sistem itu menilai saldo yang sudah final (GDD 3.0.E). Idempoten per hari.
func settle_day() -> void:
	if _settled_day == GameState.day:
		return
	_settled_day = GameState.day

	# Roti yang tidak laku sampai pintu tertutup (GDD 11.1 "Roti Tidak Laku").
	# Bila sistem lain sudah mencatatnya, catatan itu yang dipakai.
	if int(GameState.stats.get("bread_left", 0)) <= 0:
		GameState.stats["bread_left"] = GameState.display_total()

	GameState.stats["utility"] = _utility_accum

	# GDD 3.4 — gaji harian seluruh staf yang benar-benar bekerja hari ini.
	_salary_detail = _build_salary_detail()
	var salary_total: float = 0.0
	for e: Variant in _salary_detail:
		var row: Dictionary = e
		salary_total += float(row.get("salary", 0.0))
	GameState.stats["salary"] = salary_total

	# Kas keluar: utilitas lebih dulu, lalu gaji (GDD Seksi 3 & 3.4).
	# Bahan baku TIDAK dipotong di sini; kasnya sudah keluar di Pasar.
	_charge(_utility_accum, "biaya utilitas")
	_charge(salary_total, "gaji harian")


## Nilai utilitas yang sudah terkumpul hari ini (KR).
func utility_today() -> float:
	return _utility_accum


## Nilai bahan baku yang sudah terpakai produksi hari ini (KR).
func ingredients_today() -> float:
	return _spent_ingredients()


## Rincian bahan yang dicatat langsung oleh EconomySystem lewat
## record_ingredients(): ingredient_id -> jumlah unit.
func ingredient_usage() -> Dictionary:
	return _ingredient_units.duplicate(true)


## Total gaji harian yang akan/sudah dipotong (KR).
func salary_due() -> float:
	var total: float = 0.0
	for e: Variant in _build_salary_detail():
		var row: Dictionary = e
		total += float(row.get("salary", 0.0))
	return total


## Rincian gaji hari ini seperti yang masuk ke ledger.
func salary_detail() -> Array:
	if _salary_detail.is_empty():
		return _build_salary_detail()
	return _salary_detail.duplicate(true)


## Mencatat bahan yang terpakai DI LUAR ProductionSystem (mis. adonan terbuang),
## dinilai memakai harga tetap IngredientDB. Nilainya ditambahkan ke
## GameState.stats.spent_ingredients memakai konvensi aditif yang sama dengan
## ProductionSystem. [param job_id] >= 0 mencegah satu job tercatat dua kali.
##
## ProductionSystem TIDAK boleh memanggil ini: ia sudah membukukan biaya
## bahannya sendiri, dan pemanggilan ganda akan melipatgandakan angka.
func record_ingredients(costs: Dictionary, job_id: int = -1) -> void:
	if costs.is_empty():
		return
	if job_id >= 0:
		if _charged_jobs.has(job_id):
			return
		_charged_jobs[job_id] = true

	var value: float = 0.0
	for k: Variant in costs:
		var ing: String = String(k)
		var qty: int = int(costs[k])
		if qty <= 0:
			continue
		value += float(IngredientDB.price(ing)) * float(qty)
		_ingredient_units[ing] = int(_ingredient_units.get(ing, 0)) + qty

	if value <= 0.0:
		return
	_ingredient_extra += value
	var prev: float = _stat_float(GameState.stats, "spent_ingredients")
	GameState.stats["spent_ingredients"] = prev + value


# --- Penerimaan sinyal -----------------------------------------------------

func _on_bailout_triggered(_times: int) -> void:
	_bailout_today = true


## Cuaca hari ini dibekukan selama toko masih berjalan. Bila WeatherSim mengundi
## cuaca besok pada saat tutup buku (fase "close"), laporan hari ini tidak ikut
## berubah.
func _on_weather_changed(today: String, forecast: String) -> void:
	if _phase() == GameConfig.PHASE_CLOSE:
		return
	_weather_today = today
	_forecast_today = forecast


# --- Penyusunan ledger (ARCHITECTURE 7.1 + GDD 11.1) -----------------------

## Mengisi SELURUH kunci wajib ledger. Kunci yang dimiliki sistem lain
## (cuaca, rating, bailout, biaya bahan) hanya diisi bila sistem itu belum
## menuliskannya, supaya angka mereka tidak pernah tertimpa.
func _fill_ledger(ledger: Dictionary) -> void:
	var stats: Dictionary = GameState.stats

	ledger["day"] = GameState.day
	var weather: String = _adopt_string(ledger, "weather", _weather_today)
	var forecast: String = _adopt_string(ledger, "forecast", _forecast_today)

	# --- Pemasukan (GDD 11.1) ---
	var income_store: float = _stat_float(stats, "income_store")
	var income_delivery: float = _stat_float(stats, "income_delivery")
	var tips: float = _stat_float(stats, "tips")
	var total_income: float = income_store + income_delivery + tips
	ledger["income_store"] = income_store
	ledger["income_delivery"] = income_delivery
	ledger["tips"] = tips
	ledger["total_income"] = total_income

	# --- Pengeluaran (GDD 11.1) ---
	var spent_ingredients: float = _adopt_float(ledger, "spent_ingredients", _spent_ingredients())
	var utility: float = _stat_float(stats, "utility")
	var salary: float = _stat_float(stats, "salary")
	var total_expense: float = spent_ingredients + utility + salary
	ledger["utility"] = utility
	ledger["salary"] = salary
	ledger["salary_detail"] = _salary_detail.duplicate(true)
	ledger["total_expense"] = total_expense

	var profit: float = total_income - total_expense
	var balance: float = GameState.coins
	ledger["profit"] = profit
	ledger["balance"] = balance

	# --- Statistik hari ini (GDD 11.1) ---
	var bread_left: int = int(stats.get("bread_left", 0))
	ledger["customers_total"] = int(stats.get("customers_total", 0))
	ledger["customers_angry"] = int(stats.get("customers_angry", 0))
	ledger["delivery_done"] = int(stats.get("delivery_done", 0))
	ledger["delivery_cancelled"] = int(stats.get("delivery_cancelled", 0))
	ledger["bread_sold"] = int(stats.get("bread_sold", 0))
	ledger["bread_left"] = bread_left
	ledger["burned"] = int(stats.get("burned", 0))
	ledger["best_recipe"] = String(stats.get("best_recipe", ""))
	ledger["best_recipe_count"] = int(stats.get("best_recipe_count", 0))

	# --- Reputasi (dimiliki ReputationSystem) ---
	var rating_start: float = float(stats.get("rating_start", GameState.store_rating))
	var rotifood_start: float = float(stats.get("rotifood_start", GameState.rotifood_rating))
	_adopt_float(ledger, "rating_store", GameState.store_rating)
	_adopt_float(ledger, "rating_rotifood", GameState.rotifood_rating)
	var rating_delta: float = _adopt_float(ledger, "rating_delta", GameState.store_rating - rating_start)
	_adopt_float(ledger, "rotifood_delta", GameState.rotifood_rating - rotifood_start)

	# --- Penanda hari (bailout & Mode Solo dimiliki BailoutSystem) ---
	ledger["vip_visited"] = bool(stats.get("vip_visited", false))
	var solo_mode: bool = _adopt_bool(ledger, "solo_mode", GameState.solo_mode)
	var bailout: bool = _adopt_bool(ledger, "bailout", _bailout_today)

	# GDD 11.2 baris 5: mood "Pak Lurah sedang dalam perjalanan..." muncul saat
	# bailout terpicu ATAU saldo habis sama sekali.
	ledger["mood"] = DialogDB.mood(profit, rating_delta, bailout or balance <= 0.0)
	ledger["highlights"] = DialogDB.highlights(_highlight_context(stats, weather))
	ledger["lurah_tip"] = DialogDB.lurah_tip({
		"day": GameState.day,
		"solo_mode": solo_mode,
		"coins": balance,
		"delivery_cancelled": int(stats.get("delivery_cancelled", 0)),
		"rating_delta": rating_delta,
		"bread_left": bread_left,
		"forecast": forecast,
		"profit": profit,
	})
	ledger["campaign"] = _campaign_snapshot()


## Bahan masukan DialogDB.highlights() (GDD 11.3).
func _highlight_context(stats: Dictionary, weather: String) -> Dictionary:
	var ctx: Dictionary = {
		"best_recipe": String(stats.get("best_recipe", "")),
		"best_recipe_count": int(stats.get("best_recipe_count", 0)),
		"vip_visited": 1 if bool(stats.get("vip_visited", false)) else 0,
		"weather": weather,
		"delivery_done": int(stats.get("delivery_done", 0)),
		"delivery_cancelled": int(stats.get("delivery_cancelled", 0)),
		"burned": int(stats.get("burned", 0)),
		"pantry_total": GameState.pantry_total(),
		"pantry_capacity": GameState.pantry_capacity(),
		"solo_first_day": bool(stats.get("solo_first_day", false)),
	}

	# Jumlah roti gosong yang sempat terjual, bila ada sistem yang mencatatnya.
	if stats.has("burned_sold"):
		ctx["burned_sold"] = int(stats["burned_sold"])
	if stats.has("vip_name"):
		ctx["vip_name"] = String(stats["vip_name"])
	if stats.has("delivery_surge_pct"):
		ctx["delivery_surge_pct"] = int(stats["delivery_surge_pct"])

	# Baker terbaik yang bertugas hari ini (GDD 11.3 baris 6).
	var baker: Dictionary = GameState.best_staff("baker")
	if not baker.is_empty():
		ctx["best_staff"] = String(baker.get("staff_id", ""))

	var camp: Dictionary = _campaign_snapshot()
	if not camp.is_empty():
		ctx["campaign_tier"] = int(camp.get("tier", 0))
		ctx["campaign_days_left"] = int(camp.get("days_left", 0))

	return ctx


## Salinan ledger yang aman diserialisasi ke JSON (GDD 12.6). Satu-satunya nilai
## non-JSON di ledger adalah mood.bg_color bertipe Color; di riwayat nilai itu
## disimpan sebagai teks hex "#rrggbb" yang bisa dibaca balik dengan Color(teks).
## Payload EventBus.day_ended tetap membawa Color asli sesuai ARCHITECTURE 7.1.
func _history_entry(ledger: Dictionary) -> Dictionary:
	var copy: Dictionary = ledger.duplicate(true)
	var raw_mood: Variant = copy.get("mood", {})
	if typeof(raw_mood) == TYPE_DICTIONARY:
		var mood: Dictionary = raw_mood
		if typeof(mood.get("bg_color", null)) == TYPE_COLOR:
			var c: Color = mood["bg_color"]
			mood["bg_color"] = "#" + c.to_html(false)
		copy["mood"] = mood
	return copy


## Salinan kampanye pemasaran yang aman dipakai ulang; {} bila tidak ada.
func _campaign_snapshot() -> Dictionary:
	if GameState.campaign.is_empty():
		return {}
	return {
		"tier": int(GameState.campaign.get("tier", 0)),
		"days_left": int(GameState.campaign.get("days_left", 0)),
	}


# --- Gaji (GDD 3.4) --------------------------------------------------------

## Rincian gaji seluruh staf yang benar-benar bekerja hari ini.
## Staf yang diliburkan (Mode Solo, GDD 3.0.C) tidak dibayar sama sekali.
func _build_salary_detail() -> Array:
	var out: Array = []
	for e: Variant in GameState.staff:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var s: Dictionary = e
		if bool(s.get("on_leave", false)):
			continue
		var staff_id: String = String(s.get("staff_id", ""))
		var db: Dictionary = StaffDB.entry(staff_id)
		if db.is_empty():
			continue
		var role: String = String(s.get("role", db.get("role", "")))
		var tier: int = int(s.get("tier", db.get("tier", 1)))
		var salary: float = float(db.get("salary", StaffDB.salary_for(role, tier)))
		out.append({
			"staff_id": staff_id,
			"name": String(db.get("name", staff_id)),
			"role": role,
			"tier": tier,
			"salary": salary,
		})
	return out


## Memotong kas. Bila kas tidak mencukupi, yang terbayar hanya sisa kas dan
## saldo berhenti di 0 KR — GDD menegaskan tidak ada layar Game Over.
func _charge(amount: float, reason: String) -> void:
	if amount <= 0.0:
		return
	if GameState.spend_coins(amount, reason):
		return
	if GameState.coins > 0.0:
		GameState.add_coins(-GameState.coins, reason + " (kas habis)")


# --- Pembantu internal -----------------------------------------------------

func _reset_accumulators() -> void:
	_utility_accum = 0.0
	_ingredient_extra = 0.0
	_ingredient_units.clear()
	_charged_jobs.clear()
	_salary_detail = []
	_bailout_today = false
	_settled_day = -1
	_published_day = -1


func _stat_float(stats: Dictionary, key: String) -> float:
	var v: Variant = stats.get(key, 0.0)
	var t: int = typeof(v)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return float(v)
	return 0.0


## Biaya bahan terpakai hari ini. ProductionSystem-lah yang membukukannya ke
## GameState.stats; angka di sana yang dipakai agar tidak terhitung dua kali.
func _spent_ingredients() -> float:
	var v: float = _stat_float(GameState.stats, "spent_ingredients")
	if v > 0.0:
		return v
	var prod: Node = _system("prod")
	if prod != null and prod.has_method("ingredients_spent_today"):
		return maxf(0.0, float(prod.call("ingredients_spent_today")))
	return maxf(0.0, _ingredient_extra)


## Memakai nilai yang sudah ditulis sistem pemiliknya bila ada; kalau tidak,
## memakai nilai cadangan. Nilainya selalu dikembalikan ke ledger bertipe benar.
func _adopt_float(ledger: Dictionary, key: String, fallback: float) -> float:
	var t: int = typeof(ledger.get(key, null))
	if t == TYPE_FLOAT or t == TYPE_INT:
		var f: float = float(ledger[key])
		ledger[key] = f
		return f
	ledger[key] = fallback
	return fallback


func _adopt_bool(ledger: Dictionary, key: String, fallback: bool) -> bool:
	if typeof(ledger.get(key, null)) == TYPE_BOOL:
		return bool(ledger[key])
	ledger[key] = fallback
	return fallback


func _adopt_string(ledger: Dictionary, key: String, fallback: String) -> String:
	if typeof(ledger.get(key, null)) == TYPE_STRING:
		var s: String = String(ledger[key])
		if not s.is_empty():
			return s
	ledger[key] = fallback
	return fallback


## Jumlah unit mixer/oven yang sedang benar-benar bekerja, ditanyakan kepada
## ProductionSystem lewat Main.systems["prod"]. Hasilnya dibatasi jumlah slot
## lokasi agar tagihan tidak pernah melampaui alat yang benar-benar dimiliki.
func _busy_units(kind: String) -> int:
	var prod: Node = _system("prod")
	if prod == null:
		return 0
	var n: int = 0
	if kind == "mixer" and prod.has_method("busy_mixers"):
		n = int(prod.call("busy_mixers"))
	elif kind == "oven" and prod.has_method("busy_ovens"):
		n = int(prod.call("busy_ovens"))
	elif prod.has_method("busy_units"):
		n = int(prod.call("busy_units", kind))
	else:
		return 0
	return clampi(n, 0, _slot_limit(kind))


## Rak display menyala sepanjang toko buka (GDD Seksi 3 "Utility Cost").
func _active_displays(hour: float) -> int:
	if not _shop_open(hour):
		return 0
	return _slot_limit("display")


func _slot_limit(kind: String) -> int:
	var loc: Dictionary = LocationDB.entry(GameState.location_tier)
	if loc.is_empty():
		return 0
	match kind:
		"mixer":
			return maxi(0, int(loc.get("mixer_slots", 0)))
		"oven":
			return maxi(0, int(loc.get("oven_slots", 0)))
		"display":
			return maxi(0, int(loc.get("rack_slots", 0)))
	return 0


## Fase hari menurut DayCycle; "" bila DayCycle belum terpasang.
func _phase() -> String:
	var day_sys: Node = _system("day")
	if day_sys == null:
		return ""
	var v: Variant = day_sys.get("phase")
	if typeof(v) == TYPE_STRING:
		return String(v)
	return ""


func _shop_open(hour: float) -> bool:
	var p: String = _phase()
	if not p.is_empty():
		return p == GameConfig.PHASE_SELL
	return hour >= GameConfig.HOUR_OPEN and hour < GameConfig.HOUR_CLOSE


## Waktu sedang dijeda pemain. Penjaga ini membuat biaya utilitas tetap berhenti
## walau Main mengirim delta apa adanya saat permainan dijeda.
func _is_time_paused() -> bool:
	var day_sys: Node = _system("day")
	if day_sys == null or not day_sys.has_method("is_paused"):
		return false
	return bool(day_sys.call("is_paused"))


## Ambil sistem lain dari Main.systems, dengan cache ringan.
func _system(key: String) -> Node:
	if _cache.has(key):
		var cached: Variant = _cache[key]
		if cached is Node and is_instance_valid(cached):
			return cached as Node
		_cache.erase(key)

	if _main == null or not is_instance_valid(_main):
		return null
	var raw: Variant = _main.get("systems")
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var systems: Dictionary = raw
	if not systems.has(key):
		return null
	var v: Variant = systems[key]
	if v is Node and is_instance_valid(v):
		_cache[key] = v
		return v as Node
	return null
