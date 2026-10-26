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
var reputation: ReputationManager
var weather: WeatherManager
var prestige: PrestigeManager
var statistics: StatisticsManager
var achievements: AchievementManager
var tutorial: TutorialManager
var idle_economy: IdleEconomyManager
var offline: OfflineManager
var boosts: BoostManager

var profile_id: StringName = &""
var bakery_name: String = "Roti Lezat"
var created_at: String = ""
var tick_seconds: float = 0.05
## Detik jam nyata yang ditunggu karena pause atau belum cukup untuk satu tick.
var _accumulator: float = 0.0
var _in_step: bool = false
var _managers: Array[SimManager] = []
var _auto_cache: StringName = &""
var _auto_cache_key: String = "-"


func _init() -> void:
	name = "SimulationRoot"
	rng = _add(RNGManager.new(), "RNGManager")
	time = _add(TimeManager.new(), "TimeManager")
	statistics = _add(StatisticsManager.new(), "StatisticsManager")
	achievements = _add(AchievementManager.new(), "AchievementManager")
	prestige = _add(PrestigeManager.new(), "PrestigeManager")
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
	reputation = _add(ReputationManager.new(), "ReputationManager")
	weather = _add(WeatherManager.new(), "WeatherManager")
	tutorial = _add(TutorialManager.new(), "TutorialManager")
	idle_economy = _add(IdleEconomyManager.new(), "IdleEconomyManager")
	offline = _add(OfflineManager.new(), "OfflineManager")
	boosts = _add(BoostManager.new(), "BoostManager")
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
	tutorial.step(dt)
	_in_step = false


## Pukul 00:00: undian cuaca, statistik, dan pesanan lama dibuang (GDD idle 3.1).
func _on_new_day() -> void:
	weather.on_new_day()
	statistics.on_new_day()
	rotifood.prune()
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


## Harga per roti tanpa bonus rak (GDD idle 7.2): harga dasar × level resep ×
## dekorasi × waralaba × boost.
func recipe_price(recipe_id: StringName) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	return r.base_sell_price_kr * upgrades.recipe_price_mult(recipe_id) * price_mult()


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


## Laba bersih per roti resep `recipe_id` tanpa bonus rak dan boost: harga −
## biaya bahan per unit (biaya bahan tidak ikut level, GDD idle 4.4).
func net_per_unit(recipe_id: StringName) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	var price: float = r.base_sell_price_kr * upgrades.recipe_price_mult(recipe_id) * decoration.bonus_mult(&"price") * prestige.income_mult()
	return price - r.unit_cogs_kr()


## Resep "Auto" (GDD idle 4.2): resep terbuka yang bisa dibuat dengan laba
## bersih per roti tertinggi; seri dipecah urutan katalog.
func auto_recipe() -> StringName:
	var key: String = "%s|%s|%s|%s" % [str(upgrades.recipe_levels), production.best_tier(&"mixer"), production.best_tier(&"oven"), prestige.stars]
	if key == _auto_cache_key:
		return _auto_cache
	var best: StringName = &""
	var best_v: float = -INF
	for r: RecipeDefinition in DataRegistry.recipes():
		if not can_make(r.id):
			continue
		var v: float = net_per_unit(r.id)
		if v > best_v + 0.000001:
			best_v = v
			best = r.id
	_auto_cache = best
	_auto_cache_key = key
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
	return base_arrivals_per_hour() * reputation.mult() * decoration.bonus_mult(&"arrival") * boost_arrival_mult() \
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


## Biaya pindah ke lokasi tier `tier` (GDD idle 8.7).
static func location_cost(tier: int) -> float:
	var arr: Array = DataRegistry.idle("location.upgrade_cost")
	return float(arr[clampi(tier - 1, 0, arr.size() - 1)])


## "" bila boleh; selain itu kunci alasan UI.
func upgrade_block_reason() -> String:
	var nxt: LocationDefinition = next_location()
	if nxt == null:
		return "ui_upgrade_max"
	if not economy.can_afford(location_cost(nxt.tier)):
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
	economy.spend(location_cost(nxt.tier), &"LOCATION_UPGRADE", nxt.id, {})
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
# WARALABA (GDD idle 10.5, 10.6)
# ===========================================================================

## Jual toko ini dan buka cabang baru: bintang baru ditambahkan, nomor putaran
## naik, lalu KR, lokasi, stasiun dan levelnya, resep, staf, upgrade global
## level 1-5, dan reputasi direset. Bintang, perk, statistik (kecuali
## penghasilan putaran), pencapaian, dekorasi milik, nama toko, karakter,
## tutorial, jam, dan cuaca tetap. Perk berlaku untuk putaran baru. Mengembalikan
## bintang yang didapat (0 = ditolak, tidak ada yang berubah).
func franchise() -> int:
	if prestige.franchise_block() != &"":
		return 0
	SaveManager.request_autosave("franchise_before", true)
	var gained: int = prestige.stars_gain()
	_clear_actors()
	prestige.stars += gained
	prestige.run_index += 1
	var keep_above: int = DataRegistry.idlei("prestige.keep_global_levels_above")
	var kept_globals: Dictionary = {}
	for k: Variant in upgrades.global_levels.keys():
		if int(upgrades.global_levels[k]) > keep_above:
			kept_globals[k] = int(upgrades.global_levels[k])
	var appearance: Dictionary = player.appearance.duplicate()
	var lifted: Array[int] = decoration.begin_run()
	for m: SimManager in [economy, upgrades, display, equipment, production, queue, cashier, customers, demand, rotifood,
			staff, player, reputation, idle_economy]:
		m.new_game()
	player.appearance = appearance
	upgrades.global_levels = kept_globals
	boosts.new_run()
	_setup_run(prestige.start_tier())
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
	statistics.add(&"franchise_count", 1)
	achievements.check_tier(world.location.tier)
	_auto_cache = &""
	_auto_cache_key = "-"
	if not world.layout_valid():
		GameLogger.warn("WORLD", "new branch layout failed protected-path validation")
	GameLogger.important("FRANCHISE", "branch #%d opened with %d new stars (%d total)" % [prestige.run_index, gained, prestige.stars])
	EventBus.location_changed.emit(world.location.id)
	SaveManager.request_autosave("franchise_after", true)
	return gained


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
		"reputation": reputation.capture(),
		"weather": weather.capture(),
		"franchise": prestige.capture(),
		"tutorial": tutorial.capture(),
		"decorations": decoration.capture(),
		"flags": {"economy_overflowed": economy.overflowed},
		"achievements": achievements.capture(),
		"stats": statistics.capture(),
		"offline": offline.capture(),
		"boosts": boosts.capture(),
		"rng_states": rng.capture(),
	}


## SaveManager memanggil ini tepat sebelum setiap save: acuan waktu offline
## (GDD idle 9.2).
func note_active() -> void:
	offline.mark_active()


## Rekonstruksi otoritas dari save yang sudah divalidasi (v3.1 89.5, 114.10).
func load_from_save(d: Dictionary) -> void:
	profile_id = StringName(str(d.get("profile_id", "")))
	bakery_name = str(d.get("bakery_name", "Roti Lezat"))
	created_at = str(d.get("created_at", ""))
	rng.restore(d.get("rng_states", {}))
	time.restore(d.get("clock", {"day": d.get("day", 1), "time_seconds": d.get("time_seconds", 28800.0)}))
	statistics.restore(d.get("stats", {}))
	achievements.restore(d.get("achievements", {}))
	prestige.restore(d.get("franchise", {}))
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
	reputation.restore(d.get("reputation", {}))
	weather.restore(d.get("weather", {}))
	tutorial.restore(d.get("tutorial", {}))
	offline.restore(d.get("offline", {}))
	boosts.restore(d.get("boosts", {}))
	player.restore(d.get("player", {}))
	# Integritas pasca-load (v3.1 89.5 langkah 9).
	production.recover_orphans()
	player.reconstruct()
	staff.reconstruct()
	customers.reconstruct()
	rotifood.reconstruct()
	_auto_cache_key = "-"
	if not world.layout_valid():
		GameLogger.warn("WORLD", "loaded layout failed protected-path validation")
	GameLogger.important("SAVE", "profile %s loaded at day %d" % [profile_id, time.day])


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


func debug_set_reputation(v: float) -> void:
	reputation.reputation = clampf(v, DataRegistry.idlef("reputation.min"), DataRegistry.idlef("reputation.max"))
	EventBus.reputation_changed.emit(reputation.reputation)


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
