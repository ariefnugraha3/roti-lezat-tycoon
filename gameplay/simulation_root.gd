class_name SimulationRoot
extends Node
## SimulationRoot — induk seluruh manajer gameplay per-profil (GDD idle 15.1;
## v3.1 35.2, 36, 98).
##
## Simulasi maju dalam tick tetap (clock.sim_tick_seconds) sehingga hasilnya
## tidak bergantung FPS (v3.1 109.1). Toko selalu buka: jam berjalan terus 24
## jam dan hari bertambah pukul 00:00 (GDD idle 3.1). Dalam satu tick manajer
## dipanggil dengan urutan tetap (v3.1 102): jam -> produksi -> pemilik -> staf
## -> jalur kasir -> kedatangan -> pelanggan -> kasir -> RotiFood.
##
## Fungsi harga dan laju kedatangan tinggal di sini: semuanya murni, membaca
## state pemiliknya masing-masing, dan dipakai simulasi hidup maupun UI.

const MAX_TICKS_PER_FRAME: int = 16
const GAME_MODE: String = "idle"
## Skema save idle mulai dari 1 (GDD idle 15.3).
const SCHEMA_VERSION: int = 1
## Kunci save milik satu cabang (GDD idle §20 no. 78): semua yang dimulai ulang
## oleh Waralaba. Ditambah letak dan bonus dekorasi (DecorationManager.
## branch_part), posisi pemilik (`player` tanpa penampilan), penghasilan cabang
## (`run_earned_kr`), dan hari pencapaian tier. Sisanya (jam, cuaca, bintang,
## statistik, pencapaian, mastery, koleksi dekorasi, tutorial, boost, tujuan
## harian, pelanggan langganan, RNG) milik seluruh Crumbtown.
const BRANCH_KEYS: Array[String] = ["location_id", "economy", "upgrades", "display_inventory", "production_jobs",
	"equipment_states", "customers", "queues", "cashier", "demand", "rotifood_orders", "staff", "flags"]

var rng: RNGManager
var time: TimeManager
var economy: EconomyManager
var upgrades: UpgradeManager
var display: DisplayInventoryManager
var equipment: EquipmentManager
var production: ProductionManager
var world: WorldManager
var decoration: DecorationManager
var player: PlayerTaskManager
var queue: QueueManager
var cashier: CashierManager
var customers: CustomerManager
var demand: DemandManager
var rotifood: RotiFoodManager
var staff: StaffManager
var weather: WeatherManager
var prestige: PrestigeManager
var mastery: MasteryManager
var statistics: StatisticsManager
var achievements: AchievementManager
var tutorial: TutorialManager
var idle_economy: IdleEconomyManager
var offline: OfflineManager
var boosts: BoostManager
var cravings: CravingManager
var goals: GoalManager
var calendar: CalendarManager
var events: EventManager
var golden: GoldenManager
var regulars: RegularManager

var profile_id: StringName = &""
var bakery_name: String = "Crumbtown Bakery"
var created_at: String = ""
var tick_seconds: float = 0.05
## Detik jam nyata yang ditunggu karena pause atau belum cukup untuk satu tick.
var _accumulator: float = 0.0
var _in_step: bool = false
var _managers: Array[SimManager] = []
var _auto_cache: StringName = &""
var _auto_cache_key: String = "-"
## Resep Auto tanpa craving (model offline, GDD idle 9.1, 21.1).
var _auto_plain: StringName = &""
var _auto_plain_key: String = "-"


func _init() -> void:
	name = "SimulationRoot"
	rng = _add(RNGManager.new(), "RNGManager")
	time = _add(TimeManager.new(), "TimeManager")
	statistics = _add(StatisticsManager.new(), "StatisticsManager")
	achievements = _add(AchievementManager.new(), "AchievementManager")
	prestige = _add(PrestigeManager.new(), "PrestigeManager")
	mastery = _add(MasteryManager.new(), "MasteryManager")
	economy = _add(EconomyManager.new(), "EconomyManager")
	world = _add(WorldManager.new(), "WorldManager")
	upgrades = _add(UpgradeManager.new(), "UpgradeManager")
	display = _add(DisplayInventoryManager.new(), "DisplayInventoryManager")
	equipment = _add(EquipmentManager.new(), "EquipmentManager")
	production = _add(ProductionManager.new(), "ProductionManager")
	decoration = _add(DecorationManager.new(), "DecorationManager")
	queue = _add(QueueManager.new(), "QueueManager")
	cashier = _add(CashierManager.new(), "CashierManager")
	customers = _add(CustomerManager.new(), "CustomerManager")
	demand = _add(DemandManager.new(), "DemandManager")
	rotifood = _add(RotiFoodManager.new(), "RotiFoodManager")
	staff = _add(StaffManager.new(), "StaffManager")
	player = _add(PlayerTaskManager.new(), "PlayerTaskManager")
	weather = _add(WeatherManager.new(), "WeatherManager")
	tutorial = _add(TutorialManager.new(), "TutorialManager")
	idle_economy = _add(IdleEconomyManager.new(), "IdleEconomyManager")
	offline = _add(OfflineManager.new(), "OfflineManager")
	boosts = _add(BoostManager.new(), "BoostManager")
	cravings = _add(CravingManager.new(), "CravingManager")
	goals = _add(GoalManager.new(), "GoalManager")
	calendar = _add(CalendarManager.new(), "CalendarManager")
	events = _add(EventManager.new(), "EventManager")
	golden = _add(GoldenManager.new(), "GoldenManager")
	regulars = _add(RegularManager.new(), "RegularManager")
	for m: SimManager in _managers:
		m.setup(self)
	tick_seconds = DataRegistry.balf("clock.sim_tick_seconds")
	queue.queue_slot_freed.connect(demand.on_slot_freed)
	# Kursi koki dipindah di Mode Dekorasi: koki yang duduk di sana berdiri dulu.
	world.layout_changed.connect(staff.on_layout_changed)


func _add(m: SimManager, node_name: String) -> Variant:
	m.name = node_name
	add_child(m)
	_managers.append(m)
	return m


# ===========================================================================
# NEW GAME (GDD idle 2.2; v3.1 89.4)
# ===========================================================================

func start_new_game(pid: StringName, name_text: String, gender: String, master_seed: int) -> void:
	profile_id = pid
	bakery_name = name_text
	created_at = Time.get_datetime_string_from_system(true) + "Z"
	rng.master_seed = master_seed
	for m: SimManager in _managers:
		m.new_game()
	player.appearance = {"gender": gender}
	_setup_run(1)
	cravings.ensure_today()
	goals.ensure_today()
	GameLogger.important("BOOT", "new game in %s seed %d" % [pid, master_seed])


## Toko baru di lokasi tier `tier`: saldo awal, alat awal, Roti Tawar Polos di
## petak pertama (GDD idle 2.2, 8.5).
func _setup_run(tier: int) -> void:
	if world.location == null or world.location.tier != tier:
		world.set_location(DataRegistry.location_by_tier(tier).id)
	economy.open_run(prestige.start_kr())
	_create_starter_equipment()
	queue.build_from_location()
	player.place_at_start()
	var d: EquipmentInstance = equipment.placed_list(&"display")[0] if not equipment.placed_list(&"display").is_empty() else null
	if d != null:
		display.set_assignment(d.iid, 0, first_free_recipe())
	statistics.note_tier_reached(world.location.id, time.day)


## Resep yang terbuka sejak awal (GDD idle 8.5: Roti Tawar Polos).
static func first_free_recipe() -> StringName:
	for r: RecipeDefinition in DataRegistry.recipes():
		if r.unlock_free:
			return r.id
	return &""


## Alat awal: Gudang + 1 Mixer + 1 Oven + 1 Rak (GDD idle 4.1), lalu Meja Tunggu
## dan kursi koki di dapur (v3.1 5.1.3, 5.1.4).
func _create_starter_equipment() -> void:
	var loc: LocationDefinition = world.location
	var order: Array[StringName] = [loc.storage_id, &"oven_t1", &"mixer_t1", &"display_t1", DataRegistry.table_definition().id]
	for def_id: StringName in order:
		var e: EquipmentInstance = equipment.create_instance(def_id)
		if not world.auto_place(e):
			GameLogger.error("WORLD", "starter %s could not be placed" % def_id)
	_ensure_chairs()


## Kursi koki sepaket bangunan: satu per slot koki lokasi (v3.1 5.1.4).
func _ensure_chairs() -> void:
	var want: int = world.location.staff_capacity(&"baker")
	var have: Array[EquipmentInstance] = []
	for e: EquipmentInstance in equipment.all_sorted():
		if e.category() == &"chair":
			have.append(e)
	for i in range(have.size(), want):
		have.append(equipment.create_instance(DataRegistry.chair_definition().id))
	for c: EquipmentInstance in have:
		if not c.placed and not world.auto_place(c):
			GameLogger.error("WORLD", "staff chair %d could not be placed" % c.iid)


func _ensure_table() -> void:
	var t: EquipmentInstance = equipment.table_instance()
	if t == null:
		t = equipment.create_instance(DataRegistry.table_definition().id)
	if not t.placed and not world.auto_place(t):
		GameLogger.error("WORLD", "holding table could not be placed")


# ===========================================================================
# LOOP
# ===========================================================================

## Toko idle selalu berjalan (GDD idle 3.1); yang menghentikannya hanya pause.
func is_running() -> bool:
	return true


## Dipanggil GameRoot setiap frame dengan delta nyata. Satu detik nyata =
## `clock.sim_seconds_per_real_second` detik-simulasi (v3.1 15.2, 99.1).
func advance(real_delta: float) -> void:
	if PauseManager.is_paused():
		_accumulator = 0.0
		return
	var scale: float = DataRegistry.sim_seconds_per_real_second()
	var max_ticks: int = int(ceil(float(MAX_TICKS_PER_FRAME) * scale))
	_accumulator += minf(real_delta, 0.25) * scale
	var ticks: int = 0
	while _accumulator >= tick_seconds and ticks < max_ticks:
		_accumulator -= tick_seconds
		step(tick_seconds)
		ticks += 1
	if ticks >= max_ticks:
		_accumulator = 0.0


## Satu tick deterministik (v3.1 102).
func step(dt: float) -> void:
	_in_step = true
	if time.advance(dt):
		_on_new_day()
	production.step(dt)
	player.step(dt)
	staff.step(dt)
	# Pembeli di jalur yang tutup atau terlalu panjang pindah lebih dulu, sebelum
	# kedatangan baru mendapat slot (v3.1 21.3).
	customers.rebalance_lanes()
	demand.step(dt)
	customers.step(dt)
	cashier.step(dt)
	rotifood.step(dt)
	boosts.step(dt)
	golden.step(dt)
	regulars.step(dt)
	tutorial.step(dt)
	_in_step = false


## Pukul 00:00: undian cuaca, statistik, dan pesanan lama dibuang (GDD idle 3.1).
func _on_new_day() -> void:
	weather.on_new_day()
	statistics.on_new_day()
	rotifood.prune()
	cravings.on_new_day()
	goals.on_new_day()
	EventBus.day_started.emit(time.day)


## Menjalankan simulasi headless selama `seconds` detik-simulasi (test).
func run_for(seconds: float, dt: float = -1.0) -> void:
	var d: float = dt if dt > 0.0 else tick_seconds
	var t: float = 0.0
	while t < seconds:
		step(d)
		t += d


func is_stable_checkpoint() -> bool:
	return not _in_step


# ===========================================================================
# HARGA & RESEP (GDD idle 4.2, 7.2)
# ===========================================================================

## Resep bisa dibuat sekarang: terbuka dan ada mixer/oven setier syaratnya.
func can_make(recipe_id: StringName) -> bool:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	return r != null and upgrades.is_unlocked(recipe_id) and production.owns_equipment_for(r)


## Harga per roti tanpa bonus rak (GDD idle 7.2, 21.1): harga biasa × boost; resep
## craving yang terbuka dijual ×`craving.best_mult` harga biasa roti termahal yang
## bisa dijual (termasuk dirinya sendiri).
## `live` = false: tanpa boost dan craving (model penghasilan offline, GDD idle 9.1).
func recipe_price(recipe_id: StringName, live: bool = true) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	var p: float = _with_craving(recipe_id, plain_price(recipe_id), live)
	return p * boost_income_mult() if live else p


## Harga biasa per roti: harga dasar × level resep × selera lingkungan × roti
## unggulan event × dekorasi × waralaba × mastery (GDD idle 23.3), tanpa boost
## dan craving.
func plain_price(recipe_id: StringName) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	return r.base_sell_price_kr * upgrades.recipe_price_mult(recipe_id) * cravings.favorite_mult(recipe_id) * events.featured_mult(recipe_id) \
		* decoration.bonus_mult(&"price") * prestige.income_mult() * mastery.price_mult(recipe_id)


## Harga biasa roti termahal yang bisa dijual sekarang (terbuka, alatnya ada).
func best_plain_price() -> float:
	var best: float = 0.0
	for r: RecipeDefinition in DataRegistry.recipes():
		if can_make(r.id):
			best = maxf(best, plain_price(r.id))
	return best


func _with_craving(recipe_id: StringName, plain: float, live: bool) -> float:
	if not live or recipe_id != cravings.active():
		return plain
	return maxf(plain, best_plain_price()) * DataRegistry.idlef("craving.best_mult")


## Harga per roti di rak `display_iid` (GDD idle 7.2); -1 = tanpa bonus rak.
func unit_price(recipe_id: StringName, display_iid: int) -> float:
	var bonus: float = upgrades.display_price_bonus(display_iid) if display_iid >= 0 else 0.0
	return recipe_price(recipe_id) * (1.0 + bonus)


## Pengali harga di luar resep dan rak: dekorasi × waralaba × boost.
func price_mult() -> float:
	return decoration.bonus_mult(&"price") * prestige.income_mult() * boost_income_mult()


## KR per detik nyata (GDD idle 9.1) untuk HUD, dari model IdleEconomyManager.
func income_rate() -> float:
	return idle_economy.rate()


## Pengali penghasilan dari boost aktif (GDD idle 11).
func boost_income_mult() -> float:
	return boosts.income_now()


## Laba bersih per roti resep `recipe_id` tanpa bonus rak dan boost, dengan
## selera dan (bila `live`) craving: harga − biaya bahan per unit (biaya bahan
## tidak ikut level, GDD idle 4.4).
func net_per_unit(recipe_id: StringName, live: bool = true) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	return _with_craving(recipe_id, plain_price(recipe_id), live) - r.unit_cogs_kr()


## Resep "Auto" (GDD idle 4.2): resep terbuka yang bisa dibuat dengan laba
## bersih per roti tertinggi; seri dipecah urutan katalog.
## `live` = false: tanpa craving, seperti model penghasilan offline yang juga
## mengabaikan craving (GDD idle 9.1), supaya KR/s offline tidak menilai petak
## Auto dengan resep craving berharga biasa.
func auto_recipe(live: bool = true) -> StringName:
	var key: String = "%s|%s|%s|%s|%s|%s|%d" % [str(upgrades.recipe_levels), production.best_tier(&"mixer"), production.best_tier(&"oven"), prestige.stars,
		cravings.active() if live else &"", world.location.tier, mastery.version]
	if live and key == _auto_cache_key:
		return _auto_cache
	if not live and key == _auto_plain_key:
		return _auto_plain
	var best: StringName = &""
	var best_v: float = -INF
	for r: RecipeDefinition in DataRegistry.recipes():
		if not can_make(r.id):
			continue
		var v: float = net_per_unit(r.id, live)
		if v > best_v + 0.000001:
			best_v = v
			best = r.id
	if live:
		_auto_cache = best
		_auto_cache_key = key
	else:
		_auto_plain = best
		_auto_plain_key = key
	return best


## Resep yang sedang dijual petak-petak rak (menu RotiFood), urut katalog.
func menu_recipes() -> Array:
	var seen: Dictionary = {}
	for e: EquipmentInstance in equipment.placed_list(&"display"):
		for i in display.slot_count(e.iid):
			var rid: StringName = display.effective_recipe(e.iid, i)
			if rid != &"":
				seen[rid] = true
	var out: Array = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if seen.has(r.id):
			out.append(r.id)
	return out


# ===========================================================================
# KEDATANGAN (GDD idle 3.2, 6.1, 6.5)
# ===========================================================================

func base_arrivals_per_hour() -> float:
	var arr: Array = DataRegistry.idle("location.base_arrivals_per_hour")
	return float(arr[clampi(world.location.tier - 1, 0, arr.size() - 1)])


func base_rotifood_per_hour() -> float:
	var arr: Array = DataRegistry.idle("location.rotifood_orders_per_hour")
	return float(arr[clampi(world.location.tier - 1, 0, arr.size() - 1)])


## Pengali malam untuk pembeli (GDD idle 3.2).
func night_arrival_mult(t: float) -> float:
	return DataRegistry.idlef("night.arrival_mult") if time.is_night(t) else 1.0


func night_rotifood_mult(t: float) -> float:
	return DataRegistry.idlef("night.rotifood_mult") if time.is_night(t) else 1.0


## Pembeli per jam in-game pada jam `t` (GDD idle 6.1).
func arrival_rate_per_hour(t: float) -> float:
	return base_arrivals_per_hour() * decoration.bonus_mult(&"arrival") * boost_arrival_mult() \
		* night_arrival_mult(t) * weather.physical_multiplier() * weather.event_physical_multiplier()


## Pesanan RotiFood per jam in-game pada jam `t` (GDD idle 6.5).
func rotifood_rate_per_hour(t: float) -> float:
	return base_rotifood_per_hour() * decoration.bonus_mult(&"rotifood") * boost_rotifood_mult() \
		* night_rotifood_mult(t) * weather.delivery_multiplier()


func boost_arrival_mult() -> float:
	return boosts.arrival_now()


func boost_rotifood_mult() -> float:
	return boosts.rotifood_now()


# ===========================================================================
# UPGRADE LOKASI (GDD idle 8.7; v3.1 105)
# ===========================================================================

func next_location() -> LocationDefinition:
	return DataRegistry.location_by_tier(world.location.tier + 1)


## Biaya katalog pindah ke lokasi tier `tier` (GDD idle 8.7), tanpa pengali
## cabang; yang ditagih adalah location_price.
static func location_cost(tier: int) -> float:
	var arr: Array = DataRegistry.idle("location.upgrade_cost")
	return float(arr[clampi(tier - 1, 0, arr.size() - 1)])


## Biaya pindah ke lokasi tier `tier` di cabang ini (× pengali biaya cabang,
## GDD idle 23.1). Hanya pindah lokasi yang ikut naik per cabang.
func location_price(tier: int) -> float:
	return location_cost(tier) * prestige.branch_cost_mult()


## "" bila boleh; selain itu kunci alasan UI.
func upgrade_block_reason() -> String:
	var nxt: LocationDefinition = next_location()
	if nxt == null:
		return "ui_upgrade_max"
	if not economy.can_afford(location_price(nxt.tier)):
		return "ui_feedback_not_enough_kr"
	return ""


## Pindah ke lokasi berikutnya selagi toko buka: pelanggan keluar tanpa
## penalti, driver datang lagi nanti, barang di tangan ditaruh di Meja Tunggu,
## lalu migrasi v3.1 105 dengan dekorasi diangkat dulu. Level dan isi alat
## tetap. Bila gagal, snapshot dipulihkan sehingga tidak ada yang hilang.
func upgrade_location() -> String:
	var reason: String = upgrade_block_reason()
	if reason != "":
		return reason
	var nxt: LocationDefinition = next_location()
	var snapshot: Dictionary = capture_save()
	economy.spend(location_price(nxt.tier), &"LOCATION_UPGRADE", nxt.id, {})
	_clear_actors()
	var ok: bool = _migrate_to(nxt)
	if not ok:
		load_from_save(snapshot)
		return "ui_upgrade_blocked_display"
	statistics.add(&"location_upgrades_count", 1)
	statistics.note_tier_reached(nxt.id, time.day)
	achievements.check_tier(nxt.tier)
	EventBus.location_changed.emit(nxt.id)
	EventBus.sfx.emit(&"location_upgrade", &"")
	SaveManager.request_autosave("location_upgrade", true)
	return ""


# ===========================================================================
# WARALABA DAN CABANG (GDD idle 10.5, 10.6, §20 no. 78)
# ===========================================================================

## Buka cabang baru: bintang baru ditambahkan dan cabang ini ditinggal (tetap
## milik pemain, menabung seperti offline, bisa dikunjungi dari Peta Crumbtown).
## Cabang baru mulai dengan KR, lokasi, stasiun dan levelnya, resep, staf, dan
## upgrade global level 1-5 yang baru; bintang, perk, statistik (kecuali
## penghasilan cabang), pencapaian, koleksi dekorasi, nama toko, karakter,
## tutorial, jam, dan cuaca tetap. Perk berlaku untuk cabang baru. Boleh dari
## cabang mana pun begitu cabang terbaru mencapai Tier 3. `now_unix` = jam unix
## saat cabang ini ditinggal (GameRoot; 0 = tidak diketahui, tanpa tabungan,
## seperti di tes simulasi). Mengembalikan bintang yang didapat (0 = ditolak,
## tidak ada yang berubah).
func franchise(now_unix: float = 0.0) -> int:
	if prestige.franchise_block() != &"":
		return 0
	SaveManager.request_autosave("franchise_before", true)
	var gained: int = prestige.stars_gain()
	prestige.credit_newest(gained)
	prestige.stars += gained
	idle_economy.invalidate()
	var kept_globals: Dictionary = _kept_globals()
	_leave_branch(now_unix)
	prestige.run_index += 1
	prestige.open_new(prestige.run_index)
	boosts.new_run()
	_open_branch(prestige.start_tier(), kept_globals)
	statistics.add(&"franchise_count", 1)
	goals.new_run()
	achievements.check_tier(world.location.tier)
	tutorial.on_event(&"franchise")
	if not world.layout_valid():
		GameLogger.warn("WORLD", "new branch layout failed protected-path validation")
	GameLogger.important("FRANCHISE", "branch #%d opened with %d new stars (%d total)" % [prestige.run_index, gained, prestige.stars])
	EventBus.location_changed.emit(world.location.id)
	SaveManager.request_autosave("franchise_after", true)
	return gained


## Pindah ke cabang `n` (Peta Crumbtown, GDD idle §20 no. 78). Cabang ini
## ditinggal seperti saat Waralaba; cabang `n` dimuat dari state-nya lewat jalur
## load biasa, atau dibangun ulang sebagai toko awal di tier tertingginya bila
## state-nya tidak ada (cabang yang dijual sebelum §20 no. 78). Tabungannya
## sejak ditinggal dihitung untuk jam unix `now_unix` (0 = tanpa tabungan).
## Hasil: {} bila ditolak, selain itu {"away": hasil OfflineManager.settle_branch}.
func visit_branch(n: int, now_unix: float = 0.0) -> Dictionary:
	if n == prestige.branch_no or prestige.record(n).is_empty():
		return {}
	SaveManager.request_autosave("branch_before", true)
	var appearance: Dictionary = player.appearance.duplicate()
	var kept_globals: Dictionary = _kept_globals()
	_leave_branch(now_unix)
	var rec: Dictionary = prestige.take(n)
	var state: Dictionary = rec.get("state", {})
	if state.is_empty():
		_open_branch(clampi(int(rec.get("tier", 1)), 1, 5), kept_globals)
		statistics.stats["run_earned_kr"] = maxf(float(rec.get("earned", 0.0)), 0.0)
		if int(rec.get("opened_day", 0)) < 1:
			prestige.run_started_day = time.day
		GameLogger.important("FRANCHISE", "branch #%d rebuilt as a fresh Tier %d shop" % [n, world.location.tier])
	else:
		var full: Dictionary = capture_save()
		for k: String in BRANCH_KEYS:
			if state.has(k):
				full[k] = state[k]
		var pl: Dictionary = (state.get("player", {}) as Dictionary).duplicate(true)
		pl["appearance"] = appearance
		full["player"] = pl
		full["decorations"] = DecorationManager.merge_branch(full["decorations"], state.get("decorations", {}))
		var st: Dictionary = full["stats"]
		(st["stats"] as Dictionary)["run_earned_kr"] = maxf(float(state.get("run_earned_kr", 0.0)), 0.0)
		if state.get("tier_reached_day") is Dictionary:
			st["tier_reached_day"] = (state["tier_reached_day"] as Dictionary).duplicate()
		load_from_save(full)
		GameLogger.important("FRANCHISE", "visiting branch #%d" % n)
	idle_economy.invalidate()
	_auto_cache = &""
	_auto_cache_key = "-"
	_auto_plain_key = "-"
	# KR/s penghasilan offline aplikasi sekarang milik cabang ini (GDD idle 9.2).
	offline.rate_kr_per_s = idle_economy.rate(false)
	var away: Dictionary = offline.settle_branch(now_unix, float(rec.get("left_unix", 0.0)), float(rec.get("rate", 0.0)), n)
	achievements.check_tier(world.location.tier)
	EventBus.location_changed.emit(world.location.id)
	SaveManager.request_autosave("branch_after", true)
	return {"away": away}


## Upgrade global di atas `prestige.keep_global_levels_above` dibawa ke toko awal
## baru (GDD idle 10.5).
func _kept_globals() -> Dictionary:
	var keep_above: int = DataRegistry.idlei("prestige.keep_global_levels_above")
	var out: Dictionary = {}
	for k: Variant in upgrades.global_levels.keys():
		if int(upgrades.global_levels[k]) > keep_above:
			out[k] = int(upgrades.global_levels[k])
	return out


## Tinggalkan cabang yang sedang dimainkan: penghasilan yang menunggu Collect
## masuk ke dompetnya dulu, lantai dikosongkan dari aktor, pesanan RotiFood yang
## sudah selesai dibuang seperti tengah malam (sebagian besar save cabang), lalu
## bagian save miliknya disimpan di catatan cabang bersama acuan tabungannya.
func _leave_branch(now_unix: float) -> void:
	if not offline.pending.is_empty():
		offline.collect()
	_clear_actors()
	rotifood.prune()
	prestige.store_current(_branch_state(), now_unix, idle_economy.rate(false), offline.cap_seconds(), offline.efficiency())


## Bagian save cabang yang sedang dimainkan (BRANCH_KEYS dan seterusnya), salinan
## JSON-aman. Ledger-nya diringkas ke total historis.
func _branch_state() -> Dictionary:
	var full: Dictionary = capture_save()
	var out: Dictionary = {}
	for k: String in BRANCH_KEYS:
		out[k] = full[k]
	out["economy"] = economy.capture(0)
	var pl: Dictionary = (full["player"] as Dictionary).duplicate(true)
	pl.erase("appearance")
	out["player"] = pl
	out["decorations"] = decoration.branch_part()
	out["run_earned_kr"] = statistics.get_stat("run_earned_kr")
	out["tier_reached_day"] = statistics.tier_reached_day.duplicate()
	return out.duplicate(true)


## Toko awal baru di lokasi tier `tier` untuk cabang yang sedang dimainkan
## (cabang Waralaba baru, atau cabang lama yang dibangun ulang): manajer milik
## cabang dimulai ulang, upgrade global `kept_globals` dibawa, perk cabang baru
## berlaku, dan dekorasi lain dari cabang sebelumnya dipasang lagi di denah baru
## bila masih sah. Dekorasi berbonus kembali ke inventaris dan bonusnya mati
## sampai dibeli lagi di cabang ini.
func _open_branch(tier: int, kept_globals: Dictionary) -> void:
	var appearance: Dictionary = player.appearance.duplicate()
	var lifted: Array[int] = decoration.begin_run()
	for m: SimManager in [economy, upgrades, display, equipment, production, queue, cashier, customers, demand, rotifood,
			staff, player, idle_economy]:
		m.new_game()
	player.appearance = appearance
	upgrades.global_levels = kept_globals
	# Denah selalu dibangun ulang, juga di tier yang sama: peta ubin lama masih
	# mencatat perabot cabang yang baru ditinggal.
	world.set_location(DataRegistry.location_by_tier(tier).id)
	_setup_run(tier)
	if prestige.has_perk(&"perk_recipe_memory"):
		for rid: StringName in Ids.sort(prestige.recipes_ever.keys().map(func(x: Variant) -> StringName: return StringName(str(x)))):
			if DataRegistry.recipe(rid) != null and not upgrades.recipe_levels.has(rid):
				upgrades.recipe_levels[rid] = 1
	if prestige.has_perk(&"perk_free_baker"):
		for st: StaffDefinition in DataRegistry.staff_list():
			if st.role_id == &"baker":
				staff.hire(st.id, true)
				break
	decoration.replace_lifted(lifted)
	statistics.begin_run(world.location.id)
	_auto_cache = &""
	_auto_cache_key = "-"
	_auto_plain_key = "-"


## Kosongkan lantai dari aktor sebelum dunia dibangun ulang.
func _clear_actors() -> void:
	customers.shutdown()
	rotifood.send_drivers_away()
	player.cancel_all()
	KitchenBrain.drop_carried(self, player.actor)
	for k: Variant in staff.actors.keys():
		var t: Dictionary = staff.tasks.get(k, {})
		if not t.is_empty() and str(t["type"]) != "sit":
			KitchenBrain.abort(self, StringName(str(k)), t)
		KitchenBrain.drop_carried(self, staff.actors[k])
	staff.tasks.clear()
	cashier.transactions.clear()
	world.point_reservations.clear()
	demand.pending.clear()


func _migrate_to(nxt: LocationDefinition) -> bool:
	var prev_placed: Array[EquipmentInstance] = equipment.placed_list()
	for e: EquipmentInstance in equipment.all_sorted():
		e.placed = false
	# Dekorasi menunggu sampai semua perabot punya tempat (v3.1 105 no. 4, 12).
	var lifted: Array[int] = decoration.lift_all()
	# Gudang sepaket bangunan: berganti tier bersama lokasi (v3.1 5.1.1).
	var storage: EquipmentInstance = null
	for e2: EquipmentInstance in equipment.all_sorted():
		if e2.category() == &"storage":
			storage = e2
	if storage == null:
		storage = equipment.create_instance(nxt.storage_id)
	storage.def_id = nxt.storage_id
	equipment.invalidate_lists()
	world.set_location(nxt.id)
	queue.build_from_location()
	if not world.auto_place(storage):
		return false
	var order: Array[EquipmentInstance] = []
	for cat: StringName in [&"oven", &"mixer", &"display"]:
		var list: Array[EquipmentInstance] = []
		for e3: EquipmentInstance in prev_placed:
			if e3.category() == cat:
				list.append(e3)
		list.sort_custom(func(a: EquipmentInstance, b: EquipmentInstance) -> bool: return a.iid < b.iid)
		order.append_array(list)
	for e4: EquipmentInstance in order:
		if not world.auto_place(e4):
			return false
	var table: EquipmentInstance = equipment.table_instance()
	if table != null and not world.auto_place(table):
		return false
	_ensure_chairs()
	decoration.replace_lifted(lifted)
	player.place_at_start()
	staff.on_location_changed()
	return world.layout_valid()


# ===========================================================================
# SAVE / LOAD (GDD idle 15.3; v3.1 106)
# ===========================================================================

func capture_save() -> Dictionary:
	return {
		"game_mode": GAME_MODE,
		"schema_version": SCHEMA_VERSION,
		"game_version": SaveManager.GAME_VERSION,
		"catalog_versions": DataRegistry.catalog_versions.duplicate(),
		"created_at": created_at,
		"profile_id": String(profile_id),
		"bakery_name": bakery_name,
		"player": player.capture(),
		"day": time.day,
		"time_seconds": time.time_seconds,
		"location_id": String(world.location.id),
		"clock": time.capture(),
		"economy": economy.capture(),
		"upgrades": upgrades.capture(),
		"display_inventory": display.capture(),
		"production_jobs": production.capture(),
		"equipment_states": equipment.capture(),
		"customers": customers.capture(),
		"queues": queue.capture(),
		"cashier": cashier.capture(),
		"demand": demand.capture(),
		"rotifood_orders": rotifood.capture(),
		"staff": staff.capture(),
		"weather": weather.capture(),
		"franchise": prestige.capture(),
		"mastery": mastery.capture(),
		"tutorial": tutorial.capture(),
		"decorations": decoration.capture(),
		"flags": {"economy_overflowed": economy.overflowed},
		"achievements": achievements.capture(),
		"stats": statistics.capture(),
		"offline": offline.capture(),
		"boosts": boosts.capture(),
		"cravings": cravings.capture(),
		"goals": goals.capture(),
		"calendar": calendar.capture(),
		"events": events.capture(),
		"golden": golden.capture(),
		"regulars": regulars.capture(),
		"rng_states": rng.capture(),
	}


## SaveManager memanggil ini tepat sebelum setiap save: acuan waktu offline
## (GDD idle 9.2).
func note_active() -> void:
	offline.mark_active()


## Rekonstruksi otoritas dari save yang sudah divalidasi (v3.1 89.5, 114.10).
func load_from_save(d: Dictionary) -> void:
	profile_id = StringName(str(d.get("profile_id", "")))
	bakery_name = str(d.get("bakery_name", "Crumbtown Bakery"))
	created_at = str(d.get("created_at", ""))
	rng.restore(d.get("rng_states", {}))
	time.restore(d.get("clock", {"day": d.get("day", 1), "time_seconds": d.get("time_seconds", 28800.0)}))
	statistics.restore(d.get("stats", {}))
	achievements.restore(d.get("achievements", {}))
	prestige.restore(d.get("franchise", {}))
	mastery.restore(d.get("mastery", {}))
	world.restore({"location_id": d.get("location_id")})
	economy.restore(d.get("economy", {}))
	upgrades.restore(d.get("upgrades", {}))
	equipment.restore(d.get("equipment_states", {}))
	display.restore(d.get("display_inventory", {}))
	for e: EquipmentInstance in equipment.all_sorted():
		if e.category() == &"display":
			display.ensure_display(e.iid, e.tier())
	decoration.restore(d.get("decorations", {}))
	world.rebuild_occupancy()
	var displaced: Array[EquipmentInstance] = world.release_conflicts()
	decoration.enforce_rules()
	for e2: EquipmentInstance in displaced:
		if not world.auto_place(e2):
			GameLogger.warn("WORLD", "%s %d left unplaced after the layout check" % [e2.def_id, e2.iid])
	_ensure_table()
	_ensure_chairs()
	production.restore(d.get("production_jobs", {}))
	queue.restore(d.get("queues", {}))
	cashier.restore(d.get("cashier", {}))
	staff.restore(d.get("staff", {}))
	var dismissed: Array[String] = staff.enforce_capacity()
	if not dismissed.is_empty():
		GameLogger.important("STAFF", "over the staff limit, dismissed: %s" % ", ".join(dismissed))
	customers.restore(d.get("customers", {}))
	demand.restore(d.get("demand", {}))
	rotifood.restore(d.get("rotifood_orders", {}))
	weather.restore(d.get("weather", {}))
	tutorial.restore(d.get("tutorial", {}))
	offline.restore(d.get("offline", {}))
	boosts.restore(d.get("boosts", {}))
	cravings.restore(d.get("cravings", {}))
	cravings.ensure_today()
	calendar.restore(d.get("calendar", {}))
	events.restore(d.get("events", {}))
	golden.restore(d.get("golden", {}))
	regulars.restore(d.get("regulars", {}))
	goals.restore(d.get("goals", {}))
	player.restore(d.get("player", {}))
	# Integritas pasca-load (v3.1 89.5 langkah 9).
	production.recover_orphans()
	player.reconstruct()
	staff.reconstruct()
	customers.reconstruct()
	rotifood.reconstruct()
	_auto_cache_key = "-"
	_auto_plain_key = "-"
	goals.ensure_today()
	if not world.layout_valid():
		GameLogger.warn("WORLD", "loaded layout failed protected-path validation")
	GameLogger.important("SAVE", "profile %s loaded at day %d" % [profile_id, time.day])


## Alat `iid` yang sudah terpasang baru dipindah atau diputar di Decoration Mode
## (GDD idle §20 no. 75). Isinya (adonan, loyang, roti di rak) terikat pada
## iid-nya, jadi ikut tanpa diubah. Pekerja yang menuju atau sedang memakainya
## dan pembeli yang menuju atau sedang memilih di raknya berjalan ke tile akses
## barunya; aktor yang kini berdiri di jejak barunya bergeser ke sel bebas
## terdekat, dan setiap aktor yang sedang berjalan mencari jalan baru (GDD 17.5).
func on_equipment_moved(iid: int) -> void:
	player.on_equipment_moved(iid)
	staff.on_equipment_moved(iid)
	customers.on_equipment_moved(iid)
	var e: EquipmentInstance = equipment.get_inst(iid)
	var fg: FloorGrid = world.grid(e.floor_id) if e != null else null
	for a: SimActor in _actors():
		if a.outside:
			continue
		if fg != null and a.floor_id == e.floor_id and int(fg.furniture_at.get(a.cell(), -1)) == iid:
			var free: Vector2i = world.nearest_walkable(a.floor_id, a.cell(), a.nav_class)
			if free.x >= 0:
				a.pos = GridMath.cell_center(free)
		a.repath(world)


## Semua aktor simulasi yang berjalan di grid: pemilik, staf, pembeli, dan
## driver RotiFood, dalam urutan tetap.
func _actors() -> Array[SimActor]:
	var out: Array[SimActor] = [player.actor]
	for sid: Variant in Ids.sort(staff.actors.keys()):
		out.append(staff.actors[sid])
	for c: Customer in customers.sorted():
		if c.actor != null:
			out.append(c.actor)
	for o: DeliveryOrder in rotifood.active_orders():
		if o.driver != null:
			out.append(o.driver)
	return out


# ===========================================================================
# DEBUG — dipakai panel debug & test
# ===========================================================================

func debug_add_kr(amount: float) -> void:
	economy.credit(amount, &"OTHER_ADJUSTMENT", &"debug", {})


func debug_set_time(t: float) -> void:
	time.time_seconds = fposmod(t, TimeManager.DAY_SECONDS)


func debug_force_weather(w: StringName) -> void:
	if DataRegistry.weather(w) != null:
		weather.tomorrow = w
		weather.on_new_day()


func debug_spawn_customer(archetype: StringName) -> bool:
	return customers.try_admit({"archetype": archetype})


func debug_spawn_order() -> void:
	rotifood.create_random_order()


func debug_ledger_dump() -> Array:
	return economy.ledger.duplicate(true)


func debug_jobs_dump() -> Array:
	return (production.capture() as Dictionary)["jobs"]


## Pemeriksaan invarian (v3.1 94). "" bila semua sah.
func check_invariants() -> String:
	var q: String = queue.check_invariants()
	if q != "":
		return q
	if not economy.reconcile():
		return "ledger does not reconcile"
	if is_nan(economy.balance):
		return "NaN balance"
	if economy.balance < 0.0:
		return "negative balance"
	for j: ProductionJob in production.sorted_jobs():
		if j.stage == ProductionJob.MIXING or j.stage == ProductionJob.ORDERED:
			var mix: EquipmentInstance = equipment.get_inst(j.mixer_id)
			if mix == null or mix.job_id != j.job_id:
				return "job %d not bound to its mixer" % j.job_id
	return ""
