extends Node
## Alat ukur biaya simulasi per tick (GDD 102, 109): toko yang ramai pada tier
## tertentu dijalankan satu hari buka penuh (08:00-18:00) dan waktu setiap
## manager di dalam `SimulationRoot.step` dicatat (urutannya disalin dari sana).
## Rating dinaikkan ke 5 supaya pembeli sebanyak mungkin datang.
## Jalankan sebagai scene (bukan --script):
##   godot --headless --path . res://tools/sim_profile.tscn -- --tier=5 [--days=1]

const PARTS: Array[String] = ["time", "production", "equipment", "supply", "display", "player", "staff",
	"rebalance", "demand", "customers", "cashier", "rotifood", "alerts", "bot"]

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
		_after_hours()
		sim.debug_add_kr(sim.next_location().upgrade_cost_kr + 100000.0)
		var r: String = sim.upgrade_location()
		if r != "":
			push_error("sim_profile: upgrade failed: %s" % r)
			break
	for d in days:
		_after_hours()
		_equip()
		sim.weather.tomorrow = &"weather_sunny"
		# Rating tinggi sebelum 05:00, karena permintaan hari itu direncanakan saat hari mulai.
		sim.debug_set_rating(5.0, 5.0)
		# Lewati manifest pembuka Hari 1-3 (GDD 20.3): permintaan normal tier ini.
		sim.time.day = maxi(sim.time.day, 6)
		sim.continue_to_next_day()
		sim.debug_set_rating(5.0, 5.0)
		_run_to(sim.time.open_time - 60.0)
		_stock()
		for p: String in PARTS:
			_us[p] = 0
		_ticks = 0
		var peak_customers: int = 0
		var t0: int = Time.get_ticks_usec()
		while sim.time.phase != TimeManager.AFTER_HOURS and sim.time.phase != TimeManager.SUMMARY and sim.is_running():
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
		if OS.get_cmdline_user_args().has("--detail"):
			_print_detail()
		print("  at 3x and 60 fps: %.2f ms of simulation per frame" % (float(sim_us) / maxf(1.0, float(_ticks)) * 2.0 * 3.0 / 60.0 * 20.0 / 1000.0))
	sim.queue_free()
	await get_tree().process_frame
	ProceduralCaches.clear_all()
	get_tree().quit(0)


## Persiapan pagi berjalan biasa (tanpa stopwatch) sampai jam `t`.
func _run_to(t: float) -> void:
	while sim.time.time_seconds < t and sim.is_running():
		bot.think()
		sim.step(sim.tick_seconds)


func _after_hours() -> void:
	if sim.time.phase == TimeManager.OPEN or sim.time.phase == TimeManager.PREPARATION:
		sim.close_day()
	sim.enter_after_hours()
	sim.player.cancel_all()
	sim.player.actor.carried = {}
	for a: Variant in sim.staff.actors.values():
		(a as SimActor).carried = {}
	sim.staff.tasks.clear()
	for e: EquipmentInstance in sim.equipment.all_sorted():
		e.job_id = -1
	sim.production.jobs.clear()


func _equip() -> void:
	sim.debug_add_kr(3000000.0)
	var tier: int = sim.world.location.tier
	for cat: StringName in [&"display", &"oven", &"mixer"]:
		var def_id := StringName("%s_t%d" % [cat, tier])
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			if e.tier() < tier:
				sim.equipment.buy_replace(def_id, e.iid)
		while sim.equipment.placed_count(cat) + sim.equipment.unplaced_list(cat).size() < sim.equipment.slot_limit(cat):
			if not bool(sim.equipment.buy(def_id).get("ok", false)):
				break
		for e2: EquipmentInstance in sim.equipment.unplaced_list(cat):
			if not bot._place(e2.iid):
				sim.equipment.sell(e2.iid)
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
				break
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id)


## Rak terisi penuh beraneka resep, supaya pembeli selalu menemukan roti.
func _stock() -> void:
	var recipes: Array[RecipeDefinition] = DataRegistry.recipes()
	var k: int = 0
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		var sl: Array = sim.display.slots(e.iid)
		for i in sl.size():
			var r: RecipeDefinition = recipes[k % recipes.size()]
			k += 1
			var room: int = sim.display.slot_room(e.iid, i, r.id)
			if room > 0:
				sim.display.place(e.iid, i, r.id, room, 1.0, sim.time.sim_seconds, -1000 - k)


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
	if not sim.is_running():
		return
	_ticks += 1
	sim._in_step = true
	var was_open: bool = sim.time.is_open()
	var boundary: StringName = sim.time.advance(dt)
	if not was_open and sim.time.is_open():
		sim.tutorial.on_event(&"store_open")
	t = _t("time", t)
	if boundary == &"close":
		sim._in_step = false
		sim.close_day()
		return
	sim.production.step(dt)
	t = _t("production", t)
	sim.equipment.step(dt)
	t = _t("equipment", t)
	sim.supply.step(dt)
	t = _t("supply", t)
	sim.display.step(dt)
	t = _t("display", t)
	sim.player.step(dt)
	t = _t("player", t)
	sim.staff.step(dt)
	t = _t("staff", t)
	sim.customers.rebalance_lanes()
	t = _t("rebalance", t)
	sim.demand.step(dt)
	t = _t("demand", t)
	if OS.get_cmdline_user_args().has("--detail"):
		_customers_step(dt)
	else:
		sim.customers.step(dt)
	t = _t("customers", t)
	sim.cashier.step(dt)
	t = _t("cashier", t)
	if OS.get_cmdline_user_args().has("--detail"):
		_rotifood_step(dt)
	else:
		sim.rotifood.step(dt)
	t = _t("rotifood", t)
	sim.alerts.step(dt)
	t = _t("alerts", t)
	sim._in_step = false


## Salinan CustomerManager.step dengan stopwatch per state (--detail).
var _cs: Dictionary = {}


func _c(part: String, t0: int) -> int:
	var now: int = Time.get_ticks_usec()
	_cs[part] = int(_cs.get(part, 0)) + now - t0
	return now


func _customers_step(dt: float) -> void:
	var cm: CustomerManager = sim.customers
	var lowest: float = 1.0
	var t: int = Time.get_ticks_usec()
	var list: Array[Customer] = cm.sorted()
	t = _c("sorted", t)
	for c: Customer in list:
		var arrived: bool = c.actor.step(dt, sim.world)
		t = _c("actor.step", t)
		if c.state == Customer.APPROACHING:
			if not c.actor.has_route():
				_enter_shop_timed(cm, c)
			t = Time.get_ticks_usec()
			continue
		if c.window_shopper:
			cm._step_window_shopper(c, dt)
			t = _c("window_shopper", t)
			continue
		var st: String = "state_" + String(c.state)
		match c.state:
			Customer.ENTERING:
				cm._step_entering(c, arrived)
			Customer.BROWSING:
				c.browse_left -= dt
				if c.browse_left <= 0.0:
					cm._select(c)
			Customer.CARRYING_TO_QUEUE:
				cm._step_to_queue(c, arrived)
			Customer.QUEUING:
				cm._step_queuing(c, dt)
			Customer.FRONT_OF_QUEUE, Customer.BEING_SERVED:
				if arrived and c.state == Customer.FRONT_OF_QUEUE and c.awaiting_tap:
					cm._at_counter(c)
				cm._drain(c, dt)
			Customer.CELEBRATING:
				c.celebrate_left -= dt
				if c.celebrate_left <= 0.0:
					c.state = Customer.LEAVING
					cm._walk_out(c)
			Customer.LEAVING, Customer.LEAVE_NO_STOCK, Customer.ABANDONING:
				if not c.actor.has_route():
					cm._despawn(c)
		t = _c(st, t)
		if c.drains_patience():
			lowest = minf(lowest, c.patience_ratio())
		t = _c("patience", t)
	if lowest < DataRegistry.balf("smart_speed.patience_ratio"):
		if cm._smart_slow_armed:
			cm._smart_slow_armed = false
			sim.time.smart_slowdown("tut_patience")
	else:
		cm._smart_slow_armed = true
	t = _c("smart", t)


## Salinan CustomerManager._enter_shop dengan stopwatch per langkah.
func _enter_shop_timed(cm: CustomerManager, c: Customer) -> void:
	var t: int = Time.get_ticks_usec()
	c.actor.place_at(sim.world.store_floor(), sim.world.entrance_cell())
	c.spawned_at = sim.time.sim_seconds
	EventBus.sfx.emit(&"door_bell_enter", c.actor.floor_id)
	t = _c("enter.place", t)
	if c.window_shopper:
		cm.window_shoppers_today += 1
		c.state = Customer.ENTERING
		if not c.actor.go_to(sim.world, sim.world.store_floor(), c.look_cell):
			cm._window_leave(c)
		t = _c("enter.window_go_to", t)
		return
	c.state = Customer.ENTERING
	cm.entered_today += 1
	EventBus.customer_spawned.emit(0)
	t = _c("enter.signal", t)
	cm._choose_target(c)
	t = _c("enter.choose_target", t)
	sim.tutorial.on_customer_entered(c)
	t = _c("enter.tutorial", t)


func _print_detail() -> void:
	var keys: Array = _cs.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(_cs[a]) > int(_cs[b]))
	for k: Variant in keys:
		print("    customers.%-16s %7.2f us/tick" % [k, float(_cs[k]) / maxf(1.0, float(_ticks))])


## Salinan RotiFoodManager.step dengan stopwatch per fase driver (--detail).
func _rotifood_step(dt: float) -> void:
	var rm: RotiFoodManager = sim.rotifood
	if not sim.time.is_running_phase():
		return
	var now: float = sim.time.sim_seconds
	var t: int = Time.get_ticks_usec()
	var list: Array[DeliveryOrder] = rm.active_orders()
	t = _c("rf.active_orders", t)
	for o: DeliveryOrder in list:
		var ph: String = "rf." + String(o.driver_phase)
		match o.driver_phase:
			&"none":
				if now >= o.driver_arrival_time - rm.approach_seconds(o):
					o.driver_phase = &"pending"
					o.driver_pending_since = now
					o.state = DeliveryOrder.DRIVER_EN_ROUTE if not o.packed else o.state
			&"pending":
				if now - o.driver_pending_since > DataRegistry.balf("queue.rotifood_max_pending_seconds"):
					rm._fail(o, &"pending_expired", false)
				else:
					rm._try_admit_driver(o)
			&"approaching":
				o.driver.step(dt, sim.world)
				if not o.driver.has_route():
					rm._driver_enter(o)
			&"entering":
				o.driver.step(dt, sim.world)
				rm._drain(o, dt)
				rm._driver_to_queue(o)
			&"queued":
				o.driver.step(dt, sim.world)
				rm._drain(o, dt)
				rm._driver_queued(o)
			&"at_service":
				o.driver.step(dt, sim.world)
				if o.driver.has_route():
					rm._drain(o, dt)
					t = _c(ph, t)
					continue
				if o.packed:
					rm._handover(o)
				else:
					o.state = DeliveryOrder.DRIVER_WAITING
					rm._drain(o, dt)
		t = _c(ph, t)
		rm._smart_speed(o, now)
		t = _c("rf.smart", t)
	for o2: DeliveryOrder in rm._leaving():
		o2.driver.step(dt, sim.world)
		if not o2.driver.has_route():
			sim.world.release_all_for(o2.driver_id())
			o2.driver = null
			o2.driver_phase = &"gone"
	t = _c("rf.leaving", t)
