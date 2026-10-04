extends TestSuite
## Perombakan asisten (keputusan maintainer 2026-10-02, GDD 3.1-3.5, 5.1.4, 21,
## 23, 57): staf setara tanpa tier, gaji per tier lokasi, jalur kasir pemain +
## kasir dengan antrean yang mengalir ke jalur aktif, koki yang hanya membuat
## pesanan "Ask a Baker" dan membantu langkah pemain yang alatnya sudah selesai,
## serta kursi koki.

const LOAF: StringName = &"recipe_plain_loaf"
const SUITE49: GDScript = preload("res://tests/suites/suite_49_staff_handover.gd")


func tests() -> Array:
	return [
		{"id": "ACC_3_STAFF_EQUAL", "name": "3.1-3.3 every assistant is equal: no tiers or perks, one walking speed, and one wage per location tier", "fn": _staff_equal},
		{"id": "ACC_21_LANES_PER_TIER", "name": "21.2, 57 Tiers 1-3 have two checkout lanes and Tiers 4-5 three: lane A is the player's, one cashier for each other lane", "fn": _lanes_per_tier},
		{"id": "ACC_21_PLAYER_AND_CASHIER", "name": "21.2 the player can serve lane A while a cashier serves lane B on their own", "fn": _player_and_cashier},
		{"id": "ACC_21_CASHIER_LANES_SERVE", "name": "21.2 at Tiers 3-5 every hired cashier reaches the post of its own lane and serves customers there without the player", "fn": _cashier_lanes_serve},
		{"id": "ACC_21_QUEUE_SPLIT", "name": "21.3 the queue only forms at open lanes: it splits when a lane opens and flows back when the player leaves", "fn": _queue_split},
		{"id": "ACC_23_ASK_A_BAKER", "name": "23.3 Ask a Baker: a baker makes the order end to end and goes back to the chair", "fn": _ask_a_baker},
		{"id": "ACC_23_BAKER_HELPS", "name": "23.3 an idle baker carries the player's finished dough to an oven and finished bread to a shelf, but never starts the player's mixing", "fn": _baker_helps},
		{"id": "ACC_23_BAKER_YIELDS", "name": "23.3 tapping a finished station sends the baker back to the chair; tapping it again cancels the tap and the baker returns", "fn": _baker_yields},
		{"id": "ACC_5_STAFF_CHAIR", "name": "5.1.4 one staff chair per baker slot, a movable fixture; idle bakers sit on it and follow it when moved", "fn": _staff_chair},
		{"id": "TEST_SAVE_STAFF_V5", "name": "34.5 a v4 save loses tier-era staff settings, dismisses staff over the new limit, gets chairs, and moves furniture off the new lanes", "fn": _save_v5},
	]


# ===========================================================================
# BANTUAN
# ===========================================================================

func _with_staff(seed_value: int, ids: Array[StringName], tier: int = 1) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	if tier > 1:
		jump_to_tier(s, tier)
	s.time.set_phase(TimeManager.AFTER_HOURS)
	for id: StringName in ids:
		eq(s.staff.hire(id), &"", "hire %s" % id)
	check(s.continue_to_next_day(), "the next day starts")
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	return s


func _man(s: SimulationRoot, lane: QueueLane) -> void:
	s.player.cancel_all()
	s.player.actor.place_at(lane.floor_id, lane.cashier_point)
	s.player.manning_lane = lane.id


func _lane(s: SimulationRoot, id: StringName) -> QueueLane:
	return s.queue.lane(id)


func _cust(s: SimulationRoot) -> Customer:
	var before: Dictionary = {}
	for c: Customer in s.customers.sorted():
		before[c.id] = true
	s.customers.try_admit({"archetype": &"customer_generic", "scripted": true, "recipe": LOAF, "quantity": 1, "patience_override": 999.0})
	for c2: Customer in s.customers.sorted():
		if not before.has(c2.id):
			return c2
	return null


# ===========================================================================
# STAF SETARA & GAJI
# ===========================================================================

func _staff_equal() -> void:
	var wages: Array[float] = [150.0, 400.0, 900.0, 2000.0, 4500.0]
	var caps: Array[int] = [1, 1, 1, 2, 2]
	for t in range(1, 6):
		var l: LocationDefinition = DataRegistry.location_by_tier(t)
		near(l.staff_daily_wage_kr, wages[t - 1], 0.001, "tier %d wage is %d KR for anyone" % [t, int(wages[t - 1])])
		eq(l.staff_capacity(&"cashier"), caps[t - 1], "tier %d cashier limit" % t)
		eq(l.staff_capacity(&"baker"), caps[t - 1], "tier %d baker limit" % t)
	var cashiers: int = 0
	var bakers: int = 0
	for raw: Variant in DataRegistry._staff_raw.get("items", []):
		var d: Dictionary = raw
		for gone: String in ["tier", "daily_wage_kr", "work_speed_multiplier", "auto_retrieve_probability", "special", "movement_speed_mps"]:
			check(not d.has(gone), "%s has no %s" % [d["id"], gone])
		if str(d["role_id"]) == "cashier":
			cashiers += 1
		else:
			bakers += 1
	check(cashiers >= 2 and bakers >= 2, "enough candidates to fill two slots per role")
	var s: SimulationRoot = _with_staff(301, [&"staff_cashier_budi", &"staff_baker_joko"])
	near(s.staff.wage_liability_today, 2.0 * 150.0, 0.001, "two assistants at the Garage owe 2 x 150 KR at 05:00")
	for sid: Variant in s.staff.actors.keys():
		near((s.staff.actors[sid] as SimActor).speed_mps, DataRegistry.staff_speed_mps(), 0.0001, "%s walks at the shared staff speed" % sid)
	# Kasir tidak lagi mengubah kesabaran antrean (tanpa kemampuan khusus).
	run_until(s, s.time.open_time + 30.0)
	var b: QueueLane = _lane(s, &"lane_b")
	var c: Customer = _cust(s)
	check(c != null, "a customer arrives")
	if c != null:
		c.lane_id = b.id
		c.patience = c.patience_max
		c.stall_time = 0.0
		var before: float = c.patience
		s.customers._drain(c, 1.0)
		near(before - c.patience, DataRegistry.balf("patience.drain_base"), 0.0001, "a cashier's lane drains patience at the base rate")
	free_sim(s)
	var u: SimulationRoot = new_sim(302)
	jump_to_tier(u, 4)
	near(u.staff.daily_wage(), 2000.0, 0.001, "after upgrading to the Flagship every assistant earns 2,000 KR a day")
	free_sim(u)


# ===========================================================================
# JALUR KASIR
# ===========================================================================

func _lanes_per_tier() -> void:
	var want: Array[int] = [2, 2, 2, 3, 3]
	for t in range(1, 6):
		var l: LocationDefinition = DataRegistry.location_by_tier(t)
		var lanes: Array = []
		for f: FloorDefinition in l.floors:
			lanes.append_array(f.lanes)
		eq(lanes.size(), want[t - 1], "tier %d has %d checkout lanes" % [t, want[t - 1]])
		var mains: int = 0
		for ld: Variant in lanes:
			if bool((ld as Dictionary)["main"]):
				mains += 1
		eq(mains, 1, "tier %d has exactly one player lane" % t)
		check(bool((lanes[0] as Dictionary)["main"]), "tier %d: the first lane is the player's" % t)
		eq(l.staff_capacity(&"cashier"), lanes.size() - 1, "tier %d: one cashier per lane besides the player's" % t)
		eq(l.slot_count(&"cashier"), lanes.size(), "tier %d cashier slots match the lanes" % t)
	var s: SimulationRoot = new_sim(2101)
	check(s.world.layout_valid(), "the Garage layout is valid with two lanes")
	for t2 in range(2, 6):
		jump_to_tier(s, t2)
		check(s.world.layout_valid(), "tier %d layout stays valid" % t2)
		for e: EquipmentInstance in s.equipment.all_sorted():
			check(e.placed, "tier %d: %s %d is placed" % [t2, e.def_id, e.iid])
		eq(s.queue.staff_lanes().size(), want[t2 - 1] - 1, "tier %d staff lanes" % t2)
	free_sim(s)


func _player_and_cashier() -> void:
	var s: SimulationRoot = _with_staff(2102, [&"staff_cashier_budi"])
	var a: QueueLane = s.queue.main_lane()
	var b: QueueLane = _lane(s, &"lane_b")
	eq(StringName(str(s.staff.lane_assign.get(&"staff_cashier_budi", ""))), b.id, "the cashier takes lane B, never the player's lane A")
	run_until(s, s.time.open_time + 30.0)
	check(s.staff.cashier_at_post(b.id), "Budi stands at lane B")
	eq(s.queue.open_physical_lanes(), [b] as Array[QueueLane], "with the player away only the cashier's lane is open")
	check(s.player.tap_cashier(b.id, false), "tapping the counter sends the player to the counter")
	check(SUITE49.step_until(s, func() -> bool: return s.player.is_manning_lane(a.id)), "the player mans lane A beside the cashier")
	eq(s.queue.open_physical_lanes().size(), 2, "both lanes are open")
	stock(s, LOAF, 6)
	var c1: Customer = _cust(s)
	var c2: Customer = _cust(s)
	check(c1 != null and c2 != null, "two customers arrive")
	check(SUITE49.step_until(s, func() -> bool:
		return b.service_occupant != &"" and a.service_occupant != &"", 4000), "each lane has a customer at the front")
	var front_a: Customer = s.customers.customer(a.service_occupant)
	check(SUITE49.step_until(s, func() -> bool: return front_a.awaiting_tap, 200), "lane A's customer waits for the player's tap")
	check(SUITE49.step_until(s, func() -> bool: return s.customers.served_today >= 1, 2000), "the cashier serves lane B on their own")
	check(front_a.state == Customer.FRONT_OF_QUEUE, "lane A still waits for the player")
	check(s.cashier.confirm_manual(front_a.id), "the player confirms lane A's order")
	check(SUITE49.step_until(s, func() -> bool: return s.customers.served_today >= 2, 2000), "both lanes sold")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _cashier_lanes_serve() -> void:
	var names: Array[StringName] = [&"staff_cashier_budi", &"staff_cashier_sari"]
	for t in range(3, 6):
		var s: SimulationRoot = new_sim(2100 + t)
		s.tutorial.skip()
		jump_to_tier(s, t)
		s.time.set_phase(TimeManager.AFTER_HOURS)
		var cap: int = s.world.location.staff_capacity(&"cashier")
		for i in cap:
			eq(s.staff.hire(names[i]), &"", "tier %d: hire %s" % [t, names[i]])
		check(s.continue_to_next_day(), "tier %d: the next day starts" % t)
		s.demand.scripted_walkins.clear()
		s.demand.scripted_orders.clear()
		s.demand.scripted_window_shoppers.clear()
		run_until(s, s.time.open_time + 30.0)
		var lanes: Array[QueueLane] = s.queue.staff_lanes()
		eq(lanes.size(), cap, "tier %d: one staff lane per cashier" % t)
		for l: QueueLane in lanes:
			check(s.staff.cashier_at_post(l.id), "tier %d: a cashier stands at %s" % [t, l.id])
		check(not s.queue.is_open(s.queue.main_lane()), "tier %d: the player's lane is closed while the player is away" % t)
		var displays: Array[EquipmentInstance] = s.equipment.placed_list(&"display")
		for i2 in 4:
			stock(s, LOAF, 6, i2, displays[0].iid)
		var served_by: Dictionary = {}
		var want: int = cap * 3
		var spawned: int = 0
		for k in 6000:
			if spawned < want and k % 40 == 0 and _cust(s) != null:
				spawned += 1
			s.step(s.tick_seconds)
			for l2: QueueLane in lanes:
				if not s.cashier.transaction_for(l2.id).is_empty():
					served_by[l2.id] = true
			if spawned >= want and s.customers.served_today >= want:
				break
		eq(s.customers.served_today, want, "tier %d: every customer is served without the player" % t)
		eq(s.customers.abandoned_today, 0, "tier %d: nobody walks out" % t)
		for l3: QueueLane in lanes:
			check(served_by.has(l3.id), "tier %d: %s serves its own queue" % [t, l3.id])
		eq(s.check_invariants(), "", "tier %d invariants" % t)
		free_sim(s)


## Langkah simulasi sambil menahan kasir jauh dari posnya (antrean di jalurnya
## tidak dilayani), supaya antrean sempat terbentuk.
func _step_held(s: SimulationRoot, sid: StringName, cond: Callable, max_ticks: int = 4000) -> bool:
	var storage: EquipmentInstance = s.equipment.storage_instance()
	var acc: Dictionary = s.world.access_of(storage.iid)
	for i in max_ticks:
		if cond.call():
			return true
		var a: SimActor = s.staff.actors.get(sid)
		if a != null:
			a.place_at(acc["floor"], acc["cell"])
		s.step(s.tick_seconds)
	return cond.call()


func _queue_split() -> void:
	var sid: StringName = &"staff_cashier_budi"
	var s: SimulationRoot = _with_staff(2103, [sid])
	var a: QueueLane = s.queue.main_lane()
	var b: QueueLane = _lane(s, &"lane_b")
	run_until(s, s.time.open_time + 30.0)
	stock(s, LOAF, 12)
	var cs: Array[Customer] = []
	for i in 4:
		var c: Customer = _cust(s)
		check(c != null, "customer %d arrives" % i)
		cs.append(c)
	for c2: Customer in cs:
		eq(c2.lane_id, b.id, "%s queues at the cashier's lane while lane A is closed" % c2.id)
	check(_step_held(s, sid, func() -> bool: return b.line.size() >= 3 and b.service_occupant != &""),
		"the queue snakes at lane B")
	var front: StringName = b.service_occupant
	var next: Array[StringName] = b.line.duplicate()
	# Pemain membuka jalur A: pembeli urutan berikutnya pindah sampai seimbang.
	_man(s, a)
	s.customers.rebalance_lanes()
	eq(s.customers.customer(front).lane_id, b.id, "the customer at the counter stays")
	eq(s.customers.customer(next[0]).lane_id, a.id, "the next in line moves to lane A")
	eq(s.customers.customer(next[1]).lane_id, a.id, "and the one after, until both lanes are even")
	eq(s.customers.customer(next[2]).lane_id, b.id, "the last stays at lane B")
	eq(s.queue.load_of(a), s.queue.load_of(b), "the lanes are balanced")
	eq(s.check_invariants(), "", "invariants after the split")
	var mover: Customer = s.customers.customer(next[0])
	check(_step_held(s, sid, func() -> bool: return a.service_occupant == mover.id and not mover.actor.has_route(), 3000),
		"the first mover reaches lane A's counter")
	# Pemain pergi sebelum melayani: pembeli yang belum dilayani mengalir kembali.
	s.player.manning_lane = &""
	s.customers.rebalance_lanes()
	eq(mover.lane_id, b.id, "with the player gone, an unserved customer flows back to the open lane")
	eq(s.check_invariants(), "", "invariants after flowing back")
	# Pembeli yang transaksinya sudah dimulai tidak pernah dipindah.
	_man(s, a)
	var at_a: Array[StringName] = [&""]
	check(_step_held(s, sid, func() -> bool:
		at_a[0] = a.service_occupant
		var fc: Customer = s.customers.customer(at_a[0]) if at_a[0] != &"" else null
		return fc != null and fc.awaiting_tap, 3000), "someone reaches lane A again")
	check(s.cashier.confirm_manual(at_a[0]), "the player starts packing")
	s.player.manning_lane = &""
	s.customers.rebalance_lanes()
	eq(s.customers.customer(at_a[0]).lane_id, a.id, "a customer mid-checkout waits for the player instead of moving")
	free_sim(s)


# ===========================================================================
# KOKI
# ===========================================================================

func _ask_a_baker() -> void:
	var s0: SimulationRoot = new_sim(2300)
	eq(s0.staff.ask_block_reason(LOAF, 1), "ui_recipe_no_baker", "nobody to ask without a baker")
	free_sim(s0)
	var s: SimulationRoot = _with_staff(2301, [&"staff_baker_joko"])
	var sid: StringName = &"staff_baker_joko"
	var a: SimActor = s.staff.actors[sid]
	check(a.seat_iid >= 0 and a.state == &"SITTING", "Joko starts the day sitting in his chair")
	SUITE49.give(s, LOAF, 2)
	var flour_before: int = s.inventory.count(&"ingredient_flour")
	eq(s.staff.order_recipe(LOAF, 1), "", "ask a baker for Plain Loaf x1")
	check(s.inventory.count(&"ingredient_flour") < flour_before, "the ingredients leave storage at once")
	var j: ProductionJob = SUITE49.only_job(s)
	eq(j.owner_actor_id, StaffManager.KITCHEN_ID, "a kitchen order")
	check(not s.player.station_markers().has(j.mixer_id), "no '!' asks the player to start it")
	eq(s.staff.order_recipe(LOAF, 1), "ui_feedback_no_free_mixer", "a second order waits for a free mixer")
	var before: int = s.display.total_units()
	var jid: int = j.job_id
	check(SUITE49.step_until(s, func() -> bool: return s.production.get_job(jid) == null), "the baker makes it end to end")
	eq(s.display.total_units(), before + DataRegistry.recipe(LOAF).batch_yield, "the batch is on a shelf")
	check(s.player.commands.is_empty() and s.player.current.is_empty(), "the player never had to move")
	eq(int(s.staff.contract(sid).get("batches_today", 0)), 1, "Joko is credited with the batch")
	check(SUITE49.step_until(s, func() -> bool: return a.seat_iid >= 0, 2000), "Joko goes back to his chair")
	free_sim(s)


## Pemain memesan sendiri lalu mulai mengaduk; koki tidak pernah memulainya.
func _player_mixing(s: SimulationRoot) -> ProductionJob:
	SUITE49.give(s, LOAF, 2)
	eq(s.player.order_recipe(LOAF, 1), "", "the player orders Plain Loaf")
	var j: ProductionJob = SUITE49.only_job(s)
	for i in 100:
		s.step(s.tick_seconds)
	eq(j.stage, ProductionJob.ORDERED, "the baker never starts the player's mixing")
	check(s.player.tap_equipment(j.mixer_id), "the player taps the mixer")
	check(SUITE49.step_until(s, func() -> bool: return j.stage == ProductionJob.MIXING), "the player starts mixing")
	return j


func _baker_helps() -> void:
	var s: SimulationRoot = _with_staff(2302, [&"staff_baker_joko"])
	var sid: StringName = &"staff_baker_joko"
	var j: ProductionJob = _player_mixing(s)
	var jid: int = j.job_id
	check(SUITE49.step_until(s, func() -> bool: return j.carrier_id == sid), "Joko picks up the finished dough")
	eq(j.owner_actor_id, PlayerTaskManager.PLAYER_ID, "the batch is still the player's")
	check(SUITE49.step_until(s, func() -> bool: return j.stage == ProductionJob.BAKING), "Joko puts it in the oven")
	check(SUITE49.step_until(s, func() -> bool: return j.is_waiting_oven_pickup()), "it bakes")
	var before: int = s.display.total_units()
	check(SUITE49.step_until(s, func() -> bool: return s.production.get_job(jid) == null), "Joko takes it out and shelves it")
	eq(s.display.total_units(), before + DataRegistry.recipe(LOAF).batch_yield, "the bread is on the shelf")
	check(SUITE49.step_until(s, func() -> bool: return s.player.actor.carried.is_empty() and s.player.commands.is_empty()), "the player's hands stayed free")
	free_sim(s)


func _baker_yields() -> void:
	var s: SimulationRoot = _with_staff(2303, [&"staff_baker_joko"])
	var sid: StringName = &"staff_baker_joko"
	var j: ProductionJob = _player_mixing(s)
	# Pemain menunggu di meja kasir, jauh dari mixer.
	var lane: QueueLane = s.queue.main_lane()
	s.player.actor.place_at(lane.floor_id, lane.cashier_point)
	check(SUITE49.step_until(s, func() -> bool:
		return str((s.staff.tasks.get(sid, {}) as Dictionary).get("type", "")) == "pickup_dough"), "Joko heads for the finished mixer")
	var m0: Dictionary = s.player.station_markers().get(j.mixer_id, {})
	eq(m0.get("mode", &""), &"progress", "while Joko is on his way the mixer shows a full bar, not '!'")
	check(s.player.tap_equipment(j.mixer_id), "the player taps the finished mixer")
	s.step(s.tick_seconds)
	check(str((s.staff.tasks.get(sid, {}) as Dictionary).get("type", "")) != "pickup_dough", "Joko gives up the dough")
	eq(j.claimed_by, &"", "and releases it")
	eq((s.player.station_markers().get(j.mixer_id, {}) as Dictionary).get("mode", &""), &"alert", "the '!' is the player's again")
	for i in 8:
		s.step(s.tick_seconds)
	check(j.carrier_id != sid, "Joko keeps away while the player is coming")
	check(s.player.tap_equipment(j.mixer_id), "a second tap cancels the player's walk")
	check(not s.player.has_command_for(j.mixer_id), "the command is gone")
	check(SUITE49.step_until(s, func() -> bool: return j.carrier_id == sid), "Joko takes the dough after all")
	free_sim(s)


# ===========================================================================
# KURSI KOKI
# ===========================================================================

func _chairs(s: SimulationRoot) -> Array[EquipmentInstance]:
	var out: Array[EquipmentInstance] = []
	for e: EquipmentInstance in s.equipment.all_sorted():
		if e.category() == &"chair":
			out.append(e)
	return out


func _staff_chair() -> void:
	var s: SimulationRoot = new_sim(5141)
	eq(_chairs(s).size(), 1, "the Garage has one staff chair")
	var ch: EquipmentInstance = _chairs(s)[0]
	check(ch.placed and s.world.grid(ch.floor_id).is_kitchen(ch.anchor), "it stands in the kitchen")
	check(EquipmentManager.is_fixture(&"chair"), "a fixture like the Holding Table")
	s.time.set_phase(TimeManager.AFTER_HOURS)
	check(s.equipment.put_away(ch.iid) != &"", "it cannot be put away")
	check(not bool(s.equipment.sell(ch.iid).get("ok", false)), "or sold")
	for t in range(2, 6):
		jump_to_tier(s, t)
		var want: int = s.world.location.staff_capacity(&"baker")
		eq(_chairs(s).size(), want, "tier %d has %d staff chairs" % [t, want])
		for c: EquipmentInstance in _chairs(s):
			check(c.placed, "tier %d chair %d is placed" % [t, c.iid])
	free_sim(s)
	var u: SimulationRoot = _with_staff(5142, [&"staff_baker_joko"])
	var a: SimActor = u.staff.actors[&"staff_baker_joko"]
	var chair: EquipmentInstance = _chairs(u)[0]
	eq(a.seat_iid, chair.iid, "the idle baker sits on the chair")
	eq(a.state, &"SITTING", "in the sitting state")
	eq(a.cell(), u.world.access_of(chair.iid)["cell"], "from the chair's front tile")
	# Kursi dipindah (Mode Dekorasi): koki berdiri lalu duduk di tempat barunya.
	var moved: bool = false
	var fg: FloorGrid = u.world.grid(chair.floor_id)
	for z in fg.size.y:
		for x in fg.size.x:
			var cell := Vector2i(x, z)
			if moved or cell == chair.anchor or cell.distance_to(chair.anchor) < 3.0:
				continue
			if u.world.validate_placement(chair, chair.floor_id, cell, 0) == &"":
				moved = u.equipment.place(chair.iid, chair.floor_id, cell, 0) == &""
	check(moved, "the chair can be moved to another kitchen tile")
	eq(a.seat_iid, -1, "the baker stands up when the chair moves")
	check(SUITE49.step_until(u, func() -> bool: return a.seat_iid == chair.iid, 2000), "and sits down again at its new place")
	eq(a.cell(), u.world.access_of(chair.iid)["cell"], "at the new front tile")
	free_sim(u)


# ===========================================================================
# SAVE v4 -> v5
# ===========================================================================

func _save_v5() -> void:
	var s: SimulationRoot = new_sim(3405)
	s.tutorial.skip()
	jump_to_tier(s, 2)
	var d: Dictionary = json_copy(s.capture_save())
	free_sim(s)
	d["schema_version"] = 4
	# Staf era tier: dua koki (batas lama Ruko) dengan pengaturan kerja lama.
	(d["staff"] as Dictionary)["contracts"] = {
		"staff_baker_joko": {"employed": true, "on_duty": true, "working": false, "mode": "target",
			"target_recipe": "recipe_plain_loaf", "batch": 3, "hired_day": 2, "batches_today": 0},
		"staff_baker_pierre": {"employed": true, "on_duty": true, "working": false, "mode": "auto",
			"target_recipe": "", "batch": 0, "hired_day": 5, "batches_today": 0},
	}
	# Belum ada kursi koki.
	var items: Array = (d["equipment_states"] as Dictionary)["items"]
	for i in range(items.size() - 1, -1, -1):
		if str((items[i] as Dictionary)["def_id"]) == "staff_chair":
			items.remove_at(i)
	# Rak berdiri di ubin yang kini jalur B (kolom 0 lantai toko Ruko).
	var disp: Dictionary = {}
	for it: Variant in items:
		if str((it as Dictionary)["def_id"]).begins_with("display_"):
			disp = it
			break
	disp["floor_id"] = "floor_1"
	disp["grid_x"] = 0
	disp["grid_y"] = 5
	disp["rotation_quarters"] = 1
	# Job koki lama dengan klaim auto-retrieve.
	var jobs: Array = (d["production_jobs"] as Dictionary)["jobs"]
	jobs.append({"job_id": 77, "recipe_id": "recipe_plain_loaf", "batch_multiplier": 1, "quantity_output": 6,
		"stage": "DOUGH_ON_TABLE", "reserved_ingredients": {}, "ingredient_value_kr": 0.0, "mixer_id": -1, "oven_id": -1,
		"created_at": 0.0, "owner_actor_id": "staff_baker_joko", "stage_started_by": "staff_baker_joko",
		"stage_duration": 0.0, "stage_elapsed": 0.0, "burn_elapsed": 0.0, "protected": true, "bake_quality": 1.0,
		"carried_units": 0, "carrier_id": "", "claimed_by": "staff_baker_joko", "cogs_noted": true, "produced_at": 0.0,
		"table_age_hours": 0.0, "table_seq": 1})
	var m: Dictionary = SaveManager.migrate(d)
	check(bool(m.get("ok", false)), "a v4 save migrates")
	if not bool(m.get("ok", false)):
		return
	eq(int((m["data"] as Dictionary)["schema_version"]), SaveManager.current_schema_version(), "to the current schema")
	var mj: Dictionary = {}
	for jd: Variant in ((m["data"] as Dictionary)["production_jobs"] as Dictionary)["jobs"]:
		if int((jd as Dictionary)["job_id"]) == 77:
			mj = jd
	eq(str(mj.get("owner_actor_id", "")), "kitchen", "a baker's old job becomes a kitchen order")
	check(str(mj.get("claimed_by", "x")) == "" and not mj.has("protected"), "without the old claim or auto-retrieve flag")
	var u: SimulationRoot = load_sim(m["data"])
	eq(u.staff.employed_ids(&"baker"), [&"staff_baker_joko"] as Array[StringName], "only the earliest-hired baker stays under the new limit of one")
	check(not u.staff.contract(&"staff_baker_joko").has("mode"), "the old work settings are gone")
	eq(_chairs(u).size(), 1, "the shop gets its staff chair")
	check(_chairs(u)[0].placed, "placed in the kitchen")
	# Tidak ada koki yang sedang bertugas di save ini (pagi, belum ada yang
	# di lantai), jadi pesanan dapur itu langsung berpindah ke pemain.
	var dj: ProductionJob = u.production.get_job(77)
	check(dj != null and dj.owner_actor_id == PlayerTaskManager.PLAYER_ID and dj.claimed_by == &"", "with no baker on the floor the kitchen order passes to the player")
	var dsp: EquipmentInstance = u.equipment.get_inst(int(disp["iid"]))
	check(dsp != null and dsp.placed, "the display is still placed")
	if dsp != null:
		for c: Vector2i in dsp.footprint_cells():
			eq(u.world.grid(dsp.floor_id).flag(c), FloorGrid.Flag.WALKABLE_BUILDABLE, "it moved off lane B (%s)" % c)
	check(u.world.layout_valid(), "the loaded layout is valid")
	eq(u.check_invariants(), "", "invariants")
	free_sim(u)
