class_name SimulationRoot
extends Node
## SimulationRoot — induk seluruh manajer gameplay per-profil (GDD 35.2, 36, 98).
##
## Simulasi maju dalam tick tetap (clock.sim_tick_seconds) sehingga hasilnya
## tidak bergantung FPS (GDD 109.1). Dalam satu tick manajer dipanggil dengan
## urutan prioritas tetap (GDD 102): batas jam -> produksi -> commit inventori ->
## pelanggan -> RotiFood -> ekonomi/reputasi (event langsung) -> presentasi.

signal day_summary_ready(report: Dictionary)

const MAX_TICKS_PER_FRAME: int = 16

var rng: RNGManager
var time: TimeManager
var economy: EconomyManager
var pricing: PricingManager
var inventory: InventoryManager
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
var supply: SupplyOrderManager
var staff: StaffManager
var reputation: ReputationManager
var weather: WeatherManager
var marketing: MarketingManager
var bailout: BailoutManager
var statistics: StatisticsManager
var analytics: AnalyticsManager
var achievements: AchievementManager
var tutorial: TutorialManager
var alerts: AlertManager
var reports: DayReportManager

var ui_requests := UIRequests.new()
var profile_id: StringName = &""
var bakery_name: String = "Roti Lezat"
var created_at: String = ""
var tick_seconds: float = 0.05
## Detik jam nyata yang ditunggu karena pause atau belum cukup untuk satu tick.
var _accumulator: float = 0.0
var _in_step: bool = false
var _managers: Array[SimManager] = []


func _init() -> void:
	name = "SimulationRoot"
	rng = _add(RNGManager.new(), "RNGManager")
	time = _add(TimeManager.new(), "TimeManager")
	economy = _add(EconomyManager.new(), "EconomyManager")
	pricing = _add(PricingManager.new(), "PricingManager")
	world = _add(WorldManager.new(), "WorldManager")
	inventory = _add(InventoryManager.new(), "InventoryManager")
	display = _add(DisplayInventoryManager.new(), "DisplayInventoryManager")
	equipment = _add(EquipmentManager.new(), "EquipmentManager")
	production = _add(ProductionManager.new(), "ProductionManager")
	decoration = _add(DecorationManager.new(), "DecorationManager")
	queue = _add(QueueManager.new(), "QueueManager")
	cashier = _add(CashierManager.new(), "CashierManager")
	customers = _add(CustomerManager.new(), "CustomerManager")
	demand = _add(DemandManager.new(), "DemandManager")
	rotifood = _add(RotiFoodManager.new(), "RotiFoodManager")
	supply = _add(SupplyOrderManager.new(), "SupplyOrderManager")
	staff = _add(StaffManager.new(), "StaffManager")
	player = _add(PlayerTaskManager.new(), "PlayerTaskManager")
	reputation = _add(ReputationManager.new(), "ReputationManager")
	weather = _add(WeatherManager.new(), "WeatherManager")
	marketing = _add(MarketingManager.new(), "MarketingManager")
	bailout = _add(BailoutManager.new(), "BailoutManager")
	statistics = _add(StatisticsManager.new(), "StatisticsManager")
	analytics = _add(AnalyticsManager.new(), "AnalyticsManager")
	achievements = _add(AchievementManager.new(), "AchievementManager")
	tutorial = _add(TutorialManager.new(), "TutorialManager")
	alerts = _add(AlertManager.new(), "AlertManager")
	reports = _add(DayReportManager.new(), "DayReportManager")
	for m: SimManager in _managers:
		m.setup(self)
	tick_seconds = DataRegistry.balf("clock.sim_tick_seconds")
	queue.queue_slot_freed.connect(demand.on_slot_freed)


func _add(m: SimManager, node_name: String) -> Variant:
	m.name = node_name
	add_child(m)
	_managers.append(m)
	return m


# ===========================================================================
# NEW GAME (GDD 89.4)
# ===========================================================================

func start_new_game(pid: StringName, name_text: String, gender: String, master_seed: int) -> void:
	profile_id = pid
	bakery_name = name_text
	created_at = Time.get_datetime_string_from_system(true) + "Z"
	rng.master_seed = master_seed
	for m: SimManager in _managers:
		m.new_game()
	player.appearance = {"gender": gender}
	_create_starter_equipment()
	queue.build_from_location()
	player.place_at_start()
	_begin_day(true)
	GameLogger.important("BOOT", "new game in %s seed %d" % [pid, master_seed])


## Starter: storage + 1 Mixer T1 + 1 Oven T1 + 1 Display T1 terpasang (GDD 5.1.2),
## lalu Meja Tunggu di dapur (GDD 5.1.3).
func _create_starter_equipment() -> void:
	var loc: LocationDefinition = world.location
	var order: Array[StringName] = [loc.storage_id, &"oven_t1", &"mixer_t1", &"display_t1", DataRegistry.table_definition().id]
	for def_id: StringName in order:
		var e: EquipmentInstance = equipment.create_instance(def_id)
		if not world.auto_place(e):
			GameLogger.error("WORLD", "starter %s could not be placed" % def_id)


## Save lama (skema < 4) belum punya Meja Tunggu: dibuat dan ditempatkan saat
## load (GDD 5.1.3, 106).
func _ensure_table() -> void:
	var t: EquipmentInstance = equipment.table_instance()
	if t == null:
		t = equipment.create_instance(DataRegistry.table_definition().id)
	if not t.placed and not world.auto_place(t):
		GameLogger.error("WORLD", "holding table could not be placed")


# ===========================================================================
# LOOP
# ===========================================================================

func is_running() -> bool:
	return time.is_running_phase()


## Dipanggil GameRoot setiap frame dengan delta nyata.
func advance(real_delta: float) -> void:
	if PauseManager.is_paused() or not is_running():
		_accumulator = 0.0
		return
	_accumulator += minf(real_delta, 0.25) * float(time.speed)
	var ticks: int = 0
	while _accumulator >= tick_seconds and ticks < MAX_TICKS_PER_FRAME:
		_accumulator -= tick_seconds
		step(tick_seconds)
		ticks += 1
		if not is_running():
			_accumulator = 0.0
			break
	if ticks >= MAX_TICKS_PER_FRAME:
		_accumulator = 0.0


## Satu tick deterministik (GDD 102).
func step(dt: float) -> void:
	if not is_running():
		return
	_in_step = true
	var was_open: bool = time.is_open()
	var boundary: StringName = time.advance(dt)
	if not was_open and time.is_open():
		tutorial.on_event(&"store_open")
	if boundary == &"close":
		_in_step = false
		close_day()
		return
	production.step(dt)
	equipment.step(dt)
	supply.step(dt)
	display.step(dt)
	player.step(dt)
	staff.step(dt)
	demand.step(dt)
	customers.step(dt)
	cashier.step(dt)
	rotifood.step(dt)
	alerts.step(dt)
	_in_step = false


## "Skip to Open" (GDD 15.4): alasan lompatan ke 08:00 belum boleh dipakai, atau
## &"" bila boleh. &"phase" = bukan fase persiapan; &"tutorial" = Hari 1 masih
## menunggu Gudang dibuka (GDD 88.1); &"oven" = ada loyang yang harus diangkat.
func skip_to_open_block() -> StringName:
	if time.phase != TimeManager.PREPARATION:
		return &"phase"
	if not tutorial.allows_tap(&"skip"):
		return &"tutorial"
	if production.oven_needs_player():
		return &"oven"
	return &""


## Satu potong lompatan ke 08:00: paling banyak `max_ticks` tick biasa, jadi waktu
## berjalan persis seperti menunggu, hanya lebih cepat (GDD 15.4). Mengembalikan
## &"" bila belum selesai, &"open" saat toko sudah buka, atau &"oven" bila
## berhenti lebih awal karena ada loyang yang harus diangkat pemain.
func skip_to_open_step(max_ticks: int) -> StringName:
	_accumulator = 0.0
	if time.phase != TimeManager.PREPARATION:
		return &"open"
	for i in max_ticks:
		step(tick_seconds)
		if time.phase != TimeManager.PREPARATION:
			return &"open"
		if production.oven_needs_player():
			return &"oven"
	return &""


## Menjalankan simulasi headless selama `seconds` detik-simulasi (test).
func run_for(seconds: float, dt: float = -1.0) -> void:
	var d: float = dt if dt > 0.0 else tick_seconds
	var t: float = 0.0
	while t < seconds and is_running():
		step(d)
		t += d


func is_stable_checkpoint() -> bool:
	return not _in_step


# ===========================================================================
# ALUR HARI
# ===========================================================================

## 05:00 (GDD 15.3, 87.3).
func _begin_day(first: bool) -> void:
	rng.begin_day(time.day)
	economy.reset_day()
	equipment.reset_day()
	production.reset_day()
	customers.reset_day()
	rotifood.reset_day()
	statistics.reset_day()
	queue.highest_occupancy_today = 0
	ui_requests.clear()
	if not first:
		# Penuaan semalam 11 jam, tepat sekali (GDD 19.7.3, 19.7.6, 19.9); HPP
		# yang dibuang tercatat di laporan hari baru. Isi Meja Tunggu ikut menua.
		var fresh_night: bool = display.last_rollover_day < time.day - 1
		display.overnight_rollover(time.day - 1)
		if fresh_night:
			production.age_table(DataRegistry.balf("clock.overnight_aging_hours"))
	weather.begin_day(first)
	reputation.begin_day()
	bailout.apply_if_pending()
	staff.begin_day()
	bailout.begin_day_check()
	_add_opening_stock()
	demand.plan_day()
	tutorial.begin_day()
	EventBus.day_started.emit(time.day)
	EventBus.phase_changed.emit(time.phase)
	EventBus.music_state_changed.emit(&"MORNING_PREP" if not weather.is_rain() else &"RAIN")


## Hari 1-3: gudang diisi pas sebanyak manifest (GDD 2, 20.3).
func _add_opening_stock() -> void:
	var plan: Dictionary = DataRegistry.opening_day(time.day)
	if plan.is_empty():
		return
	var r: RecipeDefinition = DataRegistry.recipe(StringName(str(plan["recipe_id"])))
	var items: Dictionary = {}
	for ing: StringName in r.ingredients.keys():
		items[ing] = int(r.ingredients[ing]) * int(plan["batches"])
	inventory.add_items(items)


## 18:00: shutdown deterministik (GDD 104) lalu settlement tepat sekali (GDD 15.3).
func close_day() -> void:
	time.set_phase(TimeManager.CLOSING)
	EventBus.shop_closed.emit(time.day)
	customers.shutdown()
	rotifood.shutdown()
	supply.shutdown()
	staff.end_day()
	player.cancel_all()
	cashier.transactions.clear()
	for w: String in world.point_reservations.keys():
		if not String(world.point_reservations[w]).begins_with("player"):
			world.point_reservations.erase(w)
	# Settlement: utilitas dibulatkan ke KR terdekat (GDD 86), gaji dari liabilitas 05:00.
	var utility: float = Money.round_half_up(equipment.utility_today)
	var wages: float = staff.wage_liability_today
	economy.charge_settlement(utility, &"UTILITY_COST", &"utility", {})
	economy.charge_settlement(wages, &"STAFF_WAGE", &"payroll", {"lines": staff.wage_lines_today.duplicate(true)})
	var entered: int = maxi(1, customers.entered_today)
	marketing.end_of_day(float(customers.abandoned_today) / float(entered))
	weather.forecast_next()
	bailout.check_after_settlement()
	var report: Dictionary = reports.build({"utility": utility, "wages": wages})
	statistics.end_day(float(report["net_profit"]), production.batches_burnt_today)
	analytics.end_day(time.day)
	achievements.end_day(production.batches_burnt_today, customers.abandoned_today)
	if time.day >= int(DataRegistry.opening_raw().get("market_unlock_day", 3)):
		supply.unlock_market()
	time.set_phase(TimeManager.SUMMARY)
	tutorial.on_event(&"summary")
	EventBus.day_settled.emit(time.day)
	EventBus.music_state_changed.emit(&"DAILY_SUMMARY")
	day_summary_ready.emit(report)
	EventBus.daily_summary_ready.emit(time.day)
	SaveManager.request_autosave("day_settled", true)


func enter_after_hours() -> void:
	if time.phase == TimeManager.SUMMARY:
		time.set_phase(TimeManager.AFTER_HOURS)


## "Continue to Next Day" (GDD 11.5-11.6).
func continue_to_next_day() -> bool:
	if time.phase != TimeManager.AFTER_HOURS and time.phase != TimeManager.SUMMARY:
		return false
	if not reports.can_continue():
		return false
	time.set_phase(TimeManager.TRANSITION)
	time.begin_next_day()
	_begin_day(false)
	SaveManager.request_autosave("new_day", true)
	return true


# ===========================================================================
# UPGRADE LOKASI (GDD 47, 64, 105)
# ===========================================================================

func next_location() -> LocationDefinition:
	return DataRegistry.location_by_tier(world.location.tier + 1)


## "" bila boleh; selain itu kunci alasan UI.
func upgrade_block_reason() -> String:
	var nxt: LocationDefinition = next_location()
	if nxt == null:
		return "ui_upgrade_max"
	if not time.is_after_hours():
		return "ui_available_after_closing"
	# Isi Meja Tunggu ikut pindah bersama mejanya, jadi tidak menahan upgrade (GDD 5.1.3).
	if production.has_active_jobs() or not player.actor.carried.is_empty():
		return "ui_upgrade_blocked_jobs"
	if not economy.can_afford(nxt.upgrade_cost_kr):
		return "ui_feedback_not_enough_kr"
	return ""


func upgrade_location() -> String:
	var reason: String = upgrade_block_reason()
	if reason != "":
		return reason
	var nxt: LocationDefinition = next_location()
	var snapshot: Dictionary = capture_save()
	economy.spend(nxt.upgrade_cost_kr, &"STORE_UPGRADE", nxt.id, {})
	var ok: bool = _migrate_to(nxt)
	if not ok:
		# Rollback penuh dari snapshot: tidak ada item/KR/roti yang hilang (GDD 105).
		load_from_save(snapshot)
		return "ui_upgrade_blocked_display"
	statistics.add(&"location_upgrades_count", 1)
	statistics.note_tier_reached(nxt.id, time.day)
	achievements.check_tier(nxt.tier)
	EventBus.location_changed.emit(nxt.id)
	EventBus.sfx.emit(&"location_upgrade", &"")
	SaveManager.request_autosave("location_upgrade", true)
	return ""


func _migrate_to(nxt: LocationDefinition) -> bool:
	var prev_placed: Array[EquipmentInstance] = equipment.placed_list()
	for e: EquipmentInstance in equipment.all_sorted():
		e.placed = false
	# Gudang sepaket bangunan: berganti tier bersama lokasi (GDD 5.1.1).
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
		# Rak berisi roti ditempatkan lebih dulu (GDD 105.5-105.6).
		var list: Array[EquipmentInstance] = []
		for e3: EquipmentInstance in prev_placed:
			if e3.category() == cat:
				list.append(e3)
		list.sort_custom(func(a: EquipmentInstance, b: EquipmentInstance) -> bool:
			return display.used(a.iid) > display.used(b.iid) if cat == &"display" else a.iid < b.iid)
		order.append_array(list)
	for e4: EquipmentInstance in order:
		if equipment.placed_count(e4.category()) >= world.location.slot_count(e4.category()):
			continue
		world.auto_place(e4)
	# Meja Tunggu ditempatkan setelah alat produksi, bersama isinya (GDD 5.1.3).
	var table: EquipmentInstance = equipment.table_instance()
	if table != null and not world.auto_place(table):
		return false
	for iid: Variant in display.display_ids():
		var d: EquipmentInstance = equipment.get_inst(int(iid))
		if d != null and display.used(d.iid) > 0 and not d.placed:
			return false
	decoration.revalidate_after_migration()
	player.place_at_start()
	demand.pending.clear()
	return world.layout_valid()


# ===========================================================================
# SAVE / LOAD (GDD 106)
# ===========================================================================

func capture_save() -> Dictionary:
	return {
		"schema_version": SaveManager.current_schema_version(),
		"game_version": SaveManager.GAME_VERSION,
		"catalog_versions": DataRegistry.catalog_versions.duplicate(),
		"created_at": created_at,
		"profile_id": String(profile_id),
		"bakery_name": bakery_name,
		"player": player.capture(),
		"day": time.day,
		"time_seconds": time.time_seconds,
		"phase": String(time.phase),
		"location_id": String(world.location.id),
		"active_floor_id": String(player.actor.floor_id),
		"clock": time.capture(),
		"economy": economy.capture(),
		"pricing": pricing.capture(),
		"inventory": inventory.capture(),
		"display_inventory": display.capture(),
		"production_jobs": production.capture(),
		"equipment_states": equipment.capture(),
		"customers": customers.capture(),
		"queues": queue.capture(),
		"cashier": cashier.capture(),
		"demand": demand.capture(),
		"rotifood_orders": rotifood.capture(),
		"supply_orders": supply.capture(),
		"staff": staff.capture(),
		"ratings": reputation.capture(),
		"weather": weather.capture(),
		"marketing": marketing.capture(),
		"tutorial": tutorial.capture(),
		"decorations": decoration.capture(),
		"flags": {
			"market_unlocked": supply.market_unlocked,
			"bailout_pending": bailout.bailout_pending,
			"solo_mode": bailout.solo_mode,
			"economy_overflowed": economy.overflowed,
			"last_freshness_rollover_day": display.last_rollover_day,
		},
		"bailout": bailout.capture(),
		"achievements": achievements.capture(),
		"statistics": statistics.capture(),
		"recipe_analytics": analytics.capture(),
		"reports": reports.capture(),
		"rng_states": rng.capture(),
		"ui_restore": {"game_speed": time.speed, "camera_zoom": 1.0},
	}


## Rekonstruksi otoritas dari save yang sudah divalidasi (GDD 89.5, 114.10).
func load_from_save(d: Dictionary) -> void:
	profile_id = StringName(str(d.get("profile_id", "")))
	bakery_name = str(d.get("bakery_name", "Roti Lezat"))
	created_at = str(d.get("created_at", ""))
	rng.restore(d.get("rng_states", {}))
	var clock: Dictionary = d.get("clock", {})
	if clock.is_empty():
		clock = {"day": d.get("day", 1), "time_seconds": d.get("time_seconds", 18000.0), "phase": d.get("phase", "preparation")}
	time.restore(clock)
	world.restore({"location_id": d.get("location_id")})
	economy.restore(d.get("economy", {}))
	pricing.restore(d.get("pricing", {}))
	inventory.restore(d.get("inventory", {}))
	equipment.restore(d.get("equipment_states", {}))
	display.restore(d.get("display_inventory", {}))
	var flags: Dictionary = d.get("flags", {})
	display.last_rollover_day = int(flags.get("last_freshness_rollover_day", time.day - 1))
	for e: EquipmentInstance in equipment.all_sorted():
		if e.category() == &"display":
			display.ensure_display(e.iid, e.tier())
	decoration.restore(d.get("decorations", {}))
	world.rebuild_occupancy()
	_ensure_table()
	production.restore(d.get("production_jobs", {}))
	queue.restore(d.get("queues", {}))
	cashier.restore(d.get("cashier", {}))
	staff.restore(d.get("staff", {}))
	customers.restore(d.get("customers", {}))
	demand.restore(d.get("demand", {}))
	rotifood.restore(d.get("rotifood_orders", {}))
	supply.restore(d.get("supply_orders", {}))
	supply.market_unlocked = bool(flags.get("market_unlocked", supply.market_unlocked))
	reputation.restore(d.get("ratings", {}))
	weather.restore(d.get("weather", {}))
	marketing.restore(d.get("marketing", {}))
	tutorial.restore(d.get("tutorial", {}))
	bailout.restore(d.get("bailout", {}))
	bailout.bailout_pending = bool(flags.get("bailout_pending", bailout.bailout_pending))
	bailout.solo_mode = bool(flags.get("solo_mode", bailout.solo_mode))
	achievements.restore(d.get("achievements", {}))
	statistics.restore(d.get("statistics", {}))
	analytics.restore(d.get("recipe_analytics", {}))
	reports.restore(d.get("reports", {}))
	player.restore(d.get("player", {}))
	ui_requests.clear()
	# Integritas pasca-load (GDD 89.5 langkah 9).
	production.recover_orphans()
	player.reconstruct()
	staff.reconstruct()
	customers.reconstruct()
	rotifood.reconstruct()
	supply.reconstruct()
	var speed_v: int = int((d.get("ui_restore", {}) as Dictionary).get("game_speed", 1))
	time.speed = clampi(speed_v, 1, 3)
	if not world.layout_valid():
		GameLogger.warn("WORLD", "loaded layout failed protected-path validation")
	GameLogger.important("SAVE", "profile %s loaded at day %d" % [profile_id, time.day])


# ===========================================================================
# DEBUG (GDD 39.1) — dipakai panel debug & test
# ===========================================================================

func debug_add_kr(amount: float) -> void:
	economy.credit(amount, &"OTHER_ADJUSTMENT", &"debug", {})


func debug_set_time(t: float) -> void:
	time.time_seconds = clampf(t, time.day_start, time.close_time - 1.0)
	if time.time_seconds >= time.open_time and time.phase == TimeManager.PREPARATION:
		time.set_phase(TimeManager.OPEN)
		demand.plan_day()


func debug_force_weather(w: StringName) -> void:
	if DataRegistry.weather(w) != null:
		weather.today = w
		weather.begin_day(true)


func debug_spawn_customer(archetype: StringName) -> bool:
	return customers.try_admit({"archetype": archetype, "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})


func debug_spawn_order() -> void:
	rotifood.create_random_order()


func debug_set_rating(physical_v: float, rotifood_v: float) -> void:
	reputation.physical = clampf(physical_v, 1.0, 5.0)
	reputation.rotifood = clampf(rotifood_v, 1.0, 5.0)
	EventBus.rating_changed.emit(reputation.physical, reputation.rotifood)


func debug_trigger_bailout() -> void:
	bailout.bailout_pending = true


func debug_ledger_dump() -> Array:
	return economy.ledger.duplicate(true)


func debug_jobs_dump() -> Array:
	return (production.capture() as Dictionary)["jobs"]


## Pemeriksaan invarian (GDD 94). "" bila semua sah.
func check_invariants() -> String:
	var q: String = queue.check_invariants()
	if q != "":
		return q
	if not economy.reconcile():
		return "ledger does not reconcile"
	if is_nan(economy.balance):
		return "NaN balance"
	for j: ProductionJob in production.sorted_jobs():
		if j.stage == ProductionJob.MIXING or j.stage == ProductionJob.ORDERED:
			var mix: EquipmentInstance = equipment.get_inst(j.mixer_id)
			if mix == null or mix.job_id != j.job_id:
				return "job %d not bound to its mixer" % j.job_id
	return ""
