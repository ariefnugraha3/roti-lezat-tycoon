extends TestSuite
## Asisten idle (GDD idle 5.3-5.5; v3.1 3.1-3.5, 5.1.4, 21, 57): staf setara
## tanpa gaji, jalur kasir pemilik + kasir dengan antrean yang mengalir ke jalur
## yang buka, koki yang menjalankan batch sendiri, dan kursi koki.


func tests() -> Array:
	return [
		{"id": "ACC_3_STAFF_EQUAL", "name": "idle 5.5 every assistant is equal: no tiers, perks or wages, one walking speed, caps per location tier", "fn": _staff_equal},
		{"id": "ACC_21_LANES_PER_TIER", "name": "21.2, 57 Tiers 1-3 have two checkout lanes and Tiers 4-5 three: lane A is the owner's, one cashier for each other lane", "fn": _lanes_per_tier},
		{"id": "ACC_21_PLAYER_AND_CASHIER", "name": "idle 5.1 the owner leaves the counter to a cashier with room, serves lane A beside them after a tap on the counter, and both lanes sell on their own", "fn": _player_and_cashier},
		{"id": "ACC_21_CASHIER_LANES_SERVE", "name": "21.2 at Tiers 3-5 every hired cashier reaches the post of its own lane and serves customers there without the owner", "fn": _cashier_lanes_serve},
		{"id": "ACC_21_QUEUE_SPLIT", "name": "21.3 the queue only forms at open lanes: it splits when a lane opens and flows back when the owner leaves; a checkout in progress never moves", "fn": _queue_split},
		{"id": "ACC_23_BAKER_WORKS", "name": "idle 5.3 a hired baker runs whole batches for the shelves on their own and sits on the chair when nothing is needed", "fn": _baker_works},
		{"id": "ACC_5_STAFF_CHAIR", "name": "5.1.4 one staff chair per baker slot, a movable fixture; idle bakers sit on it and follow it when moved", "fn": _staff_chair},
	]


# ===========================================================================
# BANTUAN
# ===========================================================================

## Toko tanpa kedatangan acak, produksi berhenti, staf `ids` direkrut.
func _with_staff(seed_value: int, ids: Array[StringName], tier: int = 1) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	if tier > 1:
		jump_to_tier(s, tier)
	s.debug_add_kr(1.0e7)
	for id: StringName in ids:
		eq(s.staff.hire(id), &"", "hire %s" % id)
	freeze_production(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
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
	s.customers.try_admit({"archetype": &"customer_generic"})
	for c2: Customer in s.customers.sorted():
		if not before.has(c2.id):
			c2.patience_max = 999.0
			c2.patience = 999.0
			return c2
	return null


func _step_until(s: SimulationRoot, cond: Callable, max_ticks: int = 4000) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		s.step(s.tick_seconds)
	return cond.call()


func _served(s: SimulationRoot) -> int:
	return int(s.statistics.get_stat("total_customers_served"))


# ===========================================================================
# STAF SETARA
# ===========================================================================

func _staff_equal() -> void:
	var caps: Array[int] = [1, 1, 1, 2, 2]
	for t in range(1, 6):
		var l: LocationDefinition = DataRegistry.location_by_tier(t)
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
	var bal: float = s.economy.balance
	s.step(s.tick_seconds)
	for sid: Variant in s.staff.actors.keys():
		near((s.staff.actors[sid] as SimActor).speed_mps, DataRegistry.staff_speed_mps(), 0.0001, "%s walks at the shared staff speed at Lv 1" % sid)
	run_day(s)
	run_day(s)
	near(s.economy.balance, bal, 0.001, "two days pass without a single wage")
	# Kasir tidak mengubah kesabaran antrean (tanpa kemampuan khusus).
	var b: QueueLane = _lane(s, &"lane_b")
	stock(s, &"recipe_plain_loaf", 6)
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
		eq(mains, 1, "tier %d has exactly one owner lane" % t)
		check(bool((lanes[0] as Dictionary)["main"]), "tier %d: the first lane is the owner's" % t)
		eq(l.staff_capacity(&"cashier"), lanes.size() - 1, "tier %d: one cashier per lane besides the owner's" % t)
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
	eq(StringName(str(s.staff.lane_assign.get(&"staff_cashier_budi", ""))), b.id, "the cashier takes lane B, never the owner's lane A")
	check(_step_until(s, func() -> bool: return s.staff.cashier_at_post(b.id)), "Budi reaches lane B")
	eq(s.queue.open_physical_lanes(), [b] as Array[QueueLane], "with the owner away only the cashier's lane is open")
	for i0 in 4:
		stock(s, &"recipe_plain_loaf", 13, i0)
	var c0: Customer = _cust(s)
	check(_step_until(s, func() -> bool: return _served(s) >= 1, 4000), "the cashier serves lane B on their own")
	check(not s.player.is_manning_lane(a.id), "the owner leaves the counter to the cashier")
	check(bool(s.player.tap_cashier(a.id)["focus"]), "tapping the counter calls the owner to it")
	check(_step_until(s, func() -> bool: return s.player.is_manning_lane(a.id)), "the owner mans lane A beside the cashier")
	eq(s.queue.open_physical_lanes().size(), 2, "both lanes are open")
	var c1: Customer = _cust(s)
	var c2: Customer = _cust(s)
	check(c0 != null and c1 != null and c2 != null, "customers arrive")
	eq(c1.lane_id != c2.lane_id, true, "the two newcomers split over both lanes")
	check(_step_until(s, func() -> bool: return _served(s) >= 3, 4000), "both lanes sell without any confirm")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _cashier_lanes_serve() -> void:
	var names: Array[StringName] = [&"staff_cashier_budi", &"staff_cashier_sari"]
	for t in range(3, 6):
		var s: SimulationRoot = new_sim(2100 + t)
		s.tutorial.skip()
		jump_to_tier(s, t)
		s.debug_add_kr(1.0e9)
		var cap: int = s.world.location.staff_capacity(&"cashier")
		for i in cap:
			eq(s.staff.hire(names[i]), &"", "tier %d: hire %s" % [t, names[i]])
		freeze_production(s)
		park_owner(s)
		s.demand.next_physical_at = NEVER
		s.demand.next_rotifood_at = NEVER
		s.demand.next_window_shopper_at = NEVER
		var lanes: Array[QueueLane] = s.queue.staff_lanes()
		eq(lanes.size(), cap, "tier %d: one staff lane per cashier" % t)
		check(_step_until(s, func() -> bool:
			for l0: QueueLane in lanes:
				if not s.staff.cashier_at_post(l0.id):
					return false
			return true), "tier %d: every cashier reaches the post" % t)
		check(not s.queue.is_open(s.queue.main_lane()), "tier %d: the owner's lane is closed while the owner is away" % t)
		var displays: Array[EquipmentInstance] = s.equipment.placed_list(&"display")
		for i2 in 4:
			stock(s, &"recipe_plain_loaf", 13, i2, displays[0].iid)
		var served_by: Dictionary = {}
		var want: int = cap * 3
		var spawned: int = 0
		var served0: int = _served(s)
		for k in 8000:
			if spawned < want and k % 40 == 0 and _cust(s) != null:
				spawned += 1
			s.step(s.tick_seconds)
			for l2: QueueLane in lanes:
				if not s.cashier.transaction_for(l2.id).is_empty():
					served_by[l2.id] = true
			if spawned >= want and _served(s) - served0 >= want:
				break
		eq(_served(s) - served0, want, "tier %d: every customer is served without the owner" % t)
		eq(int(s.statistics.get_stat("total_customers_lost_patience")), 0, "tier %d: nobody walks out" % t)
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
	park_owner(s)
	var a: QueueLane = s.queue.main_lane()
	var b: QueueLane = _lane(s, &"lane_b")
	check(_step_until(s, func() -> bool: return s.staff.cashier_at_post(b.id)), "Budi reaches lane B")
	for i0 in 4:
		stock(s, &"recipe_plain_loaf", 13, i0)
	# Satu kurang dari kapasitas jalur B: jalur penuh membuka jalur A untuk
	# pemilik (GDD idle 5.1), dan di sini jalur A harus tetap tutup.
	var n: int = b.capacity() - 1
	check(n >= 3, "lane B holds at least four")
	var cs: Array[Customer] = []
	for i in n:
		var c: Customer = _cust(s)
		check(c != null, "customer %d arrives" % i)
		cs.append(c)
	for c2: Customer in cs:
		eq(c2.lane_id, b.id, "%s queues at the cashier's lane while lane A is closed" % c2.id)
	check(_step_held(s, sid, func() -> bool: return b.line.size() >= n - 1 and b.service_occupant != &""),
		"the queue snakes at lane B")
	var front: StringName = b.service_occupant
	var next: Array[StringName] = b.line.duplicate()
	if next.size() < 2:
		free_sim(s)
		return
	# Pemilik membuka jalur A: pembeli urutan berikutnya pindah sampai seimbang.
	_man(s, a)
	s.customers.rebalance_lanes()
	eq(s.customers.customer(front).lane_id, b.id, "the customer at the counter stays")
	eq(s.customers.customer(next[0]).lane_id, a.id, "the next in line moves to lane A")
	eq(s.customers.customer(next[next.size() - 1]).lane_id, b.id, "the last stays at lane B")
	check(absi(s.queue.load_of(a) - s.queue.load_of(b)) <= 1, "the lanes are balanced")
	eq(s.check_invariants(), "", "invariants after the split")
	var mover: Customer = s.customers.customer(next[0])
	# Pemilik pergi sebelum melayani: pembeli yang belum dilayani mengalir kembali.
	s.player.manning_lane = &""
	s.customers.rebalance_lanes()
	eq(mover.lane_id, b.id, "with the owner gone, an unserved customer flows back to the open lane")
	eq(s.check_invariants(), "", "invariants after flowing back")
	# Pembeli yang transaksinya sudah dimulai tidak pernah dipindah.
	_man(s, a)
	s.customers.rebalance_lanes()
	var at_a: Array[StringName] = [&""]
	check(_step_held(s, sid, func() -> bool:
		if not s.player.is_manning_lane(a.id):
			_man(s, a)
		at_a[0] = a.service_occupant
		return at_a[0] != &"" and not s.cashier.transaction_for(a.id).is_empty(), 3000), "a checkout starts at lane A")
	s.player.manning_lane = &""
	s.customers.rebalance_lanes()
	eq(s.customers.customer(at_a[0]).lane_id, a.id, "a customer mid-checkout waits for the owner instead of moving")
	free_sim(s)


# ===========================================================================
# KOKI
# ===========================================================================

func _baker_works() -> void:
	var sid: StringName = &"staff_baker_joko"
	var s: SimulationRoot = new_sim(2301)
	s.tutorial.skip()
	s.debug_add_kr(1.0e7)
	eq(s.staff.hire(sid), &"", "hire Joko")
	park_owner(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var a: SimActor = s.staff.actors[sid]
	check(_step_until(s, func() -> bool: return s.display.used(disp.iid) > 0, 20000), "Joko's bread reaches the shelf while the owner does nothing")
	check(s.player.actor.carried.is_empty(), "the owner never carried anything")
	check(_step_until(s, func() -> bool: return KitchenBrain.plan_batch(s).is_empty() and s.production.active_job_count() == 0, 60000),
		"Joko keeps baking until no slot has room for another batch (GDD idle 4.3)")
	var yield_: int = DataRegistry.recipe(&"recipe_plain_loaf").batch_yield
	for i in s.display.slot_count(disp.iid):
		check(s.display.slot_capacity(disp.iid) - s.display.slot_units(disp.iid, i) < yield_, "slot %d is as full as a batch allows" % i)
	check(_step_until(s, func() -> bool: return a.seat_iid >= 0 and a.state == &"SITTING", 6000), "with nothing to make he sits on the chair")
	eq(s.production.active_job_count(), 0, "no batch is left half-done")
	eq(s.check_invariants(), "", "invariants")
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
	check(_step_until(u, func() -> bool: return a.seat_iid == chair.iid, 4000), "the idle baker sits on the chair")
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
	check(_step_until(u, func() -> bool: return a.seat_iid == chair.iid, 2000), "and sits down again at its new place")
	eq(a.cell(), u.world.access_of(chair.iid)["cell"], "at the new front tile")
	free_sim(u)
