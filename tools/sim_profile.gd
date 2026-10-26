extends Node
## Alat ukur biaya simulasi per tick (v3.1 102, 109): toko yang ramai pada tier
## tertentu dijalankan satu hari in-game penuh (24 jam, GDD idle 3.1) dan waktu
## setiap manager di dalam `SimulationRoot.step` dicatat (urutannya disalin dari
## sana). Semua slot alat dibuka di batas level, staf penuh, reputasi 5, dan rak
## diisi ulang supaya pembeli sebanyak mungkin datang dan membeli.
## Jalankan sebagai scene (bukan --script):
##   godot --headless --path . res://tools/sim_profile.tscn -- --tier=5 [--days=1]

const PARTS: Array[String] = ["time", "production", "player", "staff", "rebalance", "demand", "customers",
	"cashier", "rotifood", "bot"]

var sim: SimulationRoot = null
var bot: SimBot = null
var _us: Dictionary = {}
var _ticks: int = 0
var _sales: int = 0


func _ready() -> void:
	var tier: int = 5
	var days: int = 1
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			tier = int(a.get_slice("=", 1))
		elif a.begins_with("--days="):
			days = int(a.get_slice("=", 1))
	PauseManager.clear_all()
	EventBus.sale_completed.connect(func(_a: float, _c: StringName) -> void: _sales += 1)
	sim = SimulationRoot.new()
	add_child(sim)
	sim.start_new_game(&"profile_sim_profile", "Profile Bakery", "male", 7070)
	sim.tutorial.skip()
	bot = SimBot.new(sim)
	while sim.world.location.tier < tier:
		sim.debug_add_kr(SimulationRoot.location_cost(sim.world.location.tier + 1))
		var r: String = sim.upgrade_location()
		if r != "":
			push_error("sim_profile: upgrade failed: %s" % r)
			break
	_equip()
	for d in days:
		sim.debug_set_reputation(5.0)
		for p: String in PARTS:
			_us[p] = 0
		_ticks = 0
		var peak_customers: int = 0
		var t0: int = Time.get_ticks_usec()
		var per_day: int = int(round(sim.time.sim_seconds_for_hours(24.0) / sim.tick_seconds))
		for i in per_day:
			_step()
			peak_customers = maxi(peak_customers, sim.customers.active_count())
			if _ticks % 2400 == 0:
				_stock()
		var wall: float = float(Time.get_ticks_usec() - t0) / 1000000.0
		var sim_us: int = 0
		for p2: String in PARTS:
			if p2 != "bot":
				sim_us += int(_us[p2])
		print("TIER %d day %d: %d ticks in %.1f s wall; simulation %.1f us/tick, bot %.1f us/tick; peak customers %d; sales %d" % [tier,
			sim.time.day, _ticks, wall, float(sim_us) / maxf(1.0, float(_ticks)), float(_us["bot"]) / maxf(1.0, float(_ticks)),
			peak_customers, _sales])
		var rows: Array = []
		for p3: String in PARTS:
			rows.append([p3, float(_us[p3]) / maxf(1.0, float(_ticks))])
		rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[1]) > float(b[1]))
		for row: Array in rows:
			print("  %-11s %7.2f us/tick" % [row[0], float(row[1])])
		print("  at 60 fps: %.2f ms of simulation per frame" % (float(sim_us) / maxf(1.0, float(_ticks)) * DataRegistry.sim_seconds_per_real_second() / 60.0 / sim.tick_seconds / 1000.0))
	sim.queue_free()
	await get_tree().process_frame
	ProceduralCaches.clear_all()
	get_tree().quit(0)


func _equip() -> void:
	sim.debug_add_kr(1.0e12)
	for cat: StringName in [&"display", &"oven", &"mixer"]:
		while sim.upgrades.open_station(cat) >= 0:
			pass
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			sim.upgrades.set_station_level(e.iid, sim.upgrades.level_cap())
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
				break
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id, true)
	for r: RecipeDefinition in DataRegistry.recipes():
		if not sim.upgrades.is_unlocked(r.id) and sim.upgrades.unlock_block(r.id) == &"":
			sim.upgrades.unlock_recipe(r.id)


## Rak terisi penuh resep petaknya, supaya pembeli selalu menemukan roti.
func _stock() -> void:
	var k: int = 0
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		for i in sim.display.slot_count(e.iid):
			k += 1
			var rid: StringName = sim.display.effective_recipe(e.iid, i)
			if rid == &"":
				continue
			var room: int = sim.display.slot_room(e.iid, i, rid)
			if room > 0:
				sim.display.place(e.iid, i, rid, room, sim.time.sim_seconds, -1000 - k)


func _t(part: String, t0: int) -> int:
	var now: int = Time.get_ticks_usec()
	_us[part] = int(_us[part]) + now - t0
	return now


## Salinan urutan SimulationRoot.step dengan stopwatch per manager.
func _step() -> void:
	var dt: float = sim.tick_seconds
	var t: int = Time.get_ticks_usec()
	bot.think()
	t = _t("bot", t)
	_ticks += 1
	sim._in_step = true
	if sim.time.advance(dt):
		sim._on_new_day()
	t = _t("time", t)
	sim.production.step(dt)
	t = _t("production", t)
	sim.player.step(dt)
	t = _t("player", t)
	sim.staff.step(dt)
	t = _t("staff", t)
	sim.customers.rebalance_lanes()
	t = _t("rebalance", t)
	sim.demand.step(dt)
	t = _t("demand", t)
	sim.customers.step(dt)
	t = _t("customers", t)
	sim.cashier.step(dt)
	t = _t("cashier", t)
	sim.rotifood.step(dt)
	t = _t("rotifood", t)
	sim._in_step = false
