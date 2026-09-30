extends TestSuite
## GDD 107: antrean, pelanggan, kasir, RotiFood.


func tests() -> Array:
	return [
		{"id": "TEST_QUEUE_001", "name": "no overlap/exclusive queue slots", "fn": _queue_exclusive},
		{"id": "TEST_QUEUE_002", "name": "pending admission maximum delay", "fn": _pending_delay},
		{"id": "TEST_CUSTOMER_001", "name": "target display and substitution", "fn": _target_and_substitution},
		{"id": "TEST_CUSTOMER_002", "name": "purchase quantity distributions", "fn": _quantities},
		{"id": "TEST_CASHIER_001", "name": "estimated-wait lane choice", "fn": _lane_choice},
		{"id": "TEST_ROTIFOOD_001", "name": "no pre-reservation and atomic pack", "fn": _rotifood_atomic},
	]


func _queue_exclusive() -> void:
	var s: SimulationRoot = new_sim(5150)
	var lane: QueueLane = s.queue.main_lane()
	var cap: int = lane.capacity()
	check(cap > 0, "main lane has slots")
	for i in cap:
		check(s.queue.reserve(lane, StringName("fake%d" % i)), "reservation %d within capacity" % i)
	check(not s.queue.reserve(lane, &"one_too_many"), "reservation beyond capacity refused (GDD 57.6)")
	check(not s.queue.reserve(lane, &"fake0"), "an actor cannot hold two reservations")
	for i2 in cap:
		s.queue.release(StringName("fake%d" % i2))
	eq(lane.reservations.size(), 0, "released")
	# Toko dibanjiri pelanggan tanpa kasir yang melayani: antrean penuh, ada
	# yang kabur, ada yang pending. Tidak ada dua aktor diam di sel antrean yang
	# sama dan invarian lane selalu sah.
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	for i3 in 4:
		stock(s, &"recipe_plain_loaf", 6, i3)
	var violations: int = 0
	var peak: int = 0
	var ticks: int = 0
	while s.time.time_seconds < 10.0 * 3600.0:
		if ticks % 60 == 0:
			s.demand._enqueue({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 1, "patience_override": null})
			if s.display.total_sellable() < 6:
				stock(s, &"recipe_plain_loaf", 6, 0)
		s.step(s.tick_seconds)
		ticks += 1
		if ticks % 10 != 0:
			continue
		if s.queue.check_invariants() != "":
			violations += 1
		var cells: Dictionary = {}
		for c: Customer in s.customers.sorted():
			if c.state != Customer.QUEUING or c.actor.has_route():
				continue
			var k: String = "%s:%s" % [c.actor.floor_id, c.actor.cell()]
			if cells.has(k):
				violations += 1
			cells[k] = true
		for l: QueueLane in s.queue.all_lanes():
			peak = maxi(peak, l.line.size())
	eq(violations, 0, "no overlapping or over-capacity queue state during a busy day")
	eq(peak, lane.capacity(), "the queue filled to capacity")
	free_sim(s)


func _pending_delay() -> void:
	var s: SimulationRoot = new_sim(6)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	run_until(s, 8.0 * 3600.0 + 60.0)
	stock(s, &"recipe_plain_loaf", 6)
	var lane: QueueLane = s.queue.main_lane()
	for i in lane.capacity():
		s.queue.reserve(lane, StringName("blocker%d" % i))
	var rating: float = s.reputation.physical
	var missed: int = s.demand.missed_today
	s.demand._enqueue({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})
	eq(s.demand.pending.size(), 1, "full queue -> arrival becomes PENDING")
	eq(s.customers.active_count(), 0, "pending arrival has not spawned")
	s.run_for(29.0)
	eq(s.demand.pending.size(), 1, "still pending before 30 s")
	s.run_for(1.5)
	eq(s.demand.pending.size(), 0, "cancelled after 30 simulation-seconds (GDD 67)")
	eq(s.demand.missed_today, missed + 1, "counted as missed demand, not rescheduled")
	near(s.reputation.physical, rating, 0.0001, "silent cancellation does not change the rating")
	# Slot yang bebas diisi segera (retry pada queue_slot_freed).
	s.demand._enqueue({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})
	s.run_for(5.0)
	s.queue.release(&"blocker0")
	s.run_for(0.2)
	eq(s.demand.pending.size(), 0, "admitted as soon as a slot frees")
	eq(s.customers.active_count(), 1, "customer spawned")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
	# Driver RotiFood: batas 40 detik.
	s = new_sim(7)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	run_until(s, 8.0 * 3600.0 + 60.0)
	var dl: QueueLane = s.queue.driver_lane()
	for i2 in dl.capacity():
		s.queue.reserve(dl, StringName("blocker_d%d" % i2))
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 1)
	o.driver_arrival_time = s.time.sim_seconds
	s.run_for(0.2)
	eq(o.driver_phase, &"pending", "driver pending while the lane is full")
	s.run_for(39.0)
	check(o.is_active(), "driver still pending before 40 s")
	s.run_for(1.5)
	eq(o.state, DeliveryOrder.CANCELLED, "driver cancelled after 40 simulation-seconds")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _admit(s: SimulationRoot, archetype: StringName) -> Customer:
	var before: Array = s.customers.customers.keys()
	s.customers.try_admit({"archetype": archetype, "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})
	for k: Variant in s.customers.customers.keys():
		if not before.has(k):
			return s.customers.customers[k]
	return null


func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	return s


func _target_and_substitution() -> void:
	# Tanpa stok: keluar tanpa antre (GDD 84.2 langkah 12).
	var s: SimulationRoot = _open_store(71)
	var c0: Customer = _admit(s, &"customer_generic")
	eq(c0.state, Customer.LEAVE_NO_STOCK, "no sellable stock -> leaves without queuing")
	eq(s.queue.lane_of(c0.id), null, "no queue slot kept")
	free_sim(s)
	# Target: rak & resep yang benar-benar punya stok.
	s = _open_store(72)
	var disp: int = s.equipment.placed_list(&"display")[0].iid
	stock(s, &"recipe_plain_loaf", 6, 1)
	var c1: Customer = _admit(s, &"customer_generic")
	eq(c1.target_recipe, &"recipe_plain_loaf", "targets the only recipe in stock")
	eq(c1.target_display, disp, "targets the display holding it")
	check(c1.target_qty >= 1 and c1.target_qty <= 4, "quantity within 1-4")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 6, "no stock reserved while walking (GDD 84.2 step 7)")
	# Stok target habis sebelum tiba -> substitusi sekali ke resep lain.
	s.display.take(&"recipe_plain_loaf", 6, Callable(), -1, 0.0)
	stock(s, &"recipe_sugar_donut", 5, 2)
	var guard: int = 0
	while c1.held.is_empty() and c1.state != Customer.LEAVE_NO_STOCK and guard < 4000:
		s.step(s.tick_seconds)
		guard += 1
	check(c1.substitution_used, "substitution pipeline ran")
	eq(c1.target_recipe, &"recipe_sugar_donut", "substituted to the remaining recipe")
	check(not c1.held.is_empty(), "picked up the substitute from the display")
	free_sim(s)
	# Snob menolak roti STALE (GDD 19.7.4).
	s = _open_store(73)
	stock(s, &"recipe_plain_loaf", 6, 1)
	for slot: Dictionary in s.display.slots(disp):
		for st: BreadStack in slot["stacks"]:
			st.age_ingame_hours = st.base_expiry_hours * 0.8
			st.refresh_state()
	var snob: Customer = _admit(s, &"customer_snob")
	eq(snob.state, Customer.LEAVE_NO_STOCK, "snob refuses stale bread")
	# Skor substitusi deterministik: resep dengan tag sama menang.
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	near(CustomerManager.tag_similarity(loaf, loaf), 1.0, 0.0001, "identical recipe similarity 1")
	var fried: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_fried_bread")
	var donut: RecipeDefinition = DataRegistry.recipe(&"recipe_sugar_donut")
	check(CustomerManager.tag_similarity(loaf, fried) > CustomerManager.tag_similarity(loaf, donut), "practical bread closer to plain loaf than a donut")
	free_sim(s)


func _quantities() -> void:
	var s: SimulationRoot = new_sim(8080)
	var n: int = 20000
	for arch: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var c := Customer.new()
		c.archetype = arch.id
		var hist: Dictionary = {}
		var total: float = 0.0
		for i in n:
			var q: int = s.customers._pick_quantity(c, arch, &"recipe_plain_loaf")
			hist[q] = int(hist.get(q, 0)) + 1
			total += q
		var lo: int = 1 << 30
		var hi: int = -1
		for q2: Variant in hist.keys():
			lo = mini(lo, int(q2))
			hi = maxi(hi, int(q2))
		check(lo >= arch.quantity_min and hi <= arch.quantity_max, "%s stays in %d-%d (got %d-%d)" % [arch.id, arch.quantity_min, arch.quantity_max, lo, hi])
		if arch.quantity_mode == &"triangular":
			var mean: float = total / float(n)
			var want: float = (arch.quantity_min + arch.quantity_preferred + arch.quantity_max) / 3.0
			near(mean, want, 0.2, "%s triangular mean" % arch.id)
			var mode_q: int = arch.quantity_preferred
			for q3: Variant in hist.keys():
				if int(hist[q3]) > int(hist[mode_q]) and absi(int(q3) - arch.quantity_preferred) > 1:
					mode_q = int(q3)
			eq(mode_q, arch.quantity_preferred, "%s peaks near %d" % [arch.id, arch.quantity_preferred])
			continue
		# Bobot GDD 84.1 dinormalisasi atas kuantitas yang sah.
		var w: Dictionary = {}
		var rest: Array = []
		for q4 in range(arch.quantity_min, arch.quantity_max + 1):
			if q4 == arch.quantity_preferred:
				w[q4] = 0.5
			elif absi(q4 - arch.quantity_preferred) == 1:
				w[q4] = 0.2
			else:
				rest.append(q4)
		for q5: int in rest:
			w[q5] = 0.1 / float(rest.size())
		var sum_w: float = 0.0
		for v: Variant in w.values():
			sum_w += float(v)
		for q6: Variant in w.keys():
			var p: float = float(hist.get(q6, 0)) / float(n)
			near(p, float(w[q6]) / sum_w, 0.015, "%s P(qty=%d)" % [arch.id, int(q6)])
	# GDD 84.1 tabel rentang.
	var ranges: Dictionary = {
		&"customer_school_child": [1, 1, 2], &"customer_office_worker": [2, 1, 3], &"customer_generic": [2, 1, 4],
		&"customer_bulk_buyer": [8, 5, 15], &"customer_snob": [3, 2, 5], &"customer_indecisive": [2, 1, 3],
		&"customer_critic": [2, 1, 3],
	}
	for id: StringName in ranges.keys():
		var a: CustomerArchetypeDefinition = DataRegistry.archetype(id)
		eq([a.quantity_preferred, a.quantity_min, a.quantity_max], ranges[id], "%s quantity table" % id)
	eq(DataRegistry.archetype(&"customer_bulk_buyer").quantity_partial_min, 3, "bulk buyer accepts partial >= 3")
	free_sim(s)


func _lane_choice() -> void:
	var s: SimulationRoot = new_sim(404)
	var tier: int = 0
	for t in range(2, 6):
		var loc: LocationDefinition = DataRegistry.location_by_tier(t)
		var n: int = 0
		for f: FloorDefinition in loc.floors:
			n += f.lanes.size()
		if n >= 2:
			tier = t
			break
	check(tier > 0, "a tier with two cashier lanes exists")
	jump_to_tier(s, tier)
	var lanes: Array[QueueLane] = s.queue.lanes
	var a: QueueLane = lanes[0]
	var b: QueueLane = lanes[1]
	# Kasir T1 di A, T5 di B: semua transaksi sama-sama 3 s (GDD 21.4), jadi
	# yang menentukan hanya jumlah pembeli yang sudah antre dan jarak jalan.
	s.staff.lane_assign = {"staff_cashier_budi": a.id, "staff_cashier_grace": b.id}
	eq(s.queue.open_physical_lanes().size(), 2, "both lanes open with a cashier each")
	var pack: float = DataRegistry.packing_seconds()
	s.queue.reserve(b, &"q1")
	var from: Vector2i = s.world.entrance_cell()
	var wa: float = s.queue.estimated_wait(a, 0.0)
	var wb: float = s.queue.estimated_wait(b, 0.0)
	near(wa, pack, 0.001, "lane A estimate = own 3 s transaction")
	near(wb, 2.0 * pack, 0.001, "lane B estimate = 1 queued + own, 3 s each whatever the cashier tier")
	var pick: QueueLane = s.queue.choose_physical_lane(from, 1.2)
	var walk_a: float = GridMath.tiles_to_meters(float(GridMath.manhattan(from, a.slots[0]))) / 1.2
	var walk_b: float = GridMath.tiles_to_meters(float(GridMath.manhattan(from, b.slots[1]))) / 1.2
	eq(pick.id, a.id if wa + walk_a < wb + walk_b else b.id, "lowest estimated total wait wins, not the shortest line")
	# Seri: kasir sama, antrean kosong -> antrean pendek, jarak, lalu lane_id.
	s.queue.release(&"q1")
	s.staff.lane_assign = {"staff_cashier_budi": a.id, "staff_cashier_sari": b.id}
	var pick2: QueueLane = s.queue.choose_physical_lane(from, 1000000.0)
	var da: int = GridMath.manhattan(from, a.slots[0])
	var db: int = GridMath.manhattan(from, b.slots[0])
	var want: StringName = a.id if (da < db or (da == db and String(a.id) < String(b.id))) else b.id
	eq(pick2.id, want, "tie broken by distance then lane_id")
	# Setelah reserve, pelanggan tidak berpindah lane.
	var c: Customer = null
	s.demand.scripted_walkins.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	stock(s, &"recipe_plain_loaf", 6)
	s.staff.lane_assign = {"staff_cashier_budi": a.id, "staff_cashier_grace": b.id}
	c = _admit(s, &"customer_generic")
	if c != null and c.state != Customer.LEAVE_NO_STOCK:
		var first: StringName = c.lane_id
		s.queue.reserve(s.queue.lane(first), &"late1")
		s.queue.reserve(s.queue.lane(first), &"late2")
		s.run_for(3.0)
		eq(c.lane_id, first, "no lane hopping after reserving")
	free_sim(s)


func _rotifood_atomic() -> void:
	var s: SimulationRoot = _open_store(909)
	stock(s, &"recipe_plain_loaf", 3, 0)
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 3)
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 3, "order creation reserves nothing (GDD 22.3)")
	# Pelanggan boleh mengambil roti yang "diincar" order.
	var taken: Array[Dictionary] = s.display.take(&"recipe_plain_loaf", 2, Callable(), -1, 90.0)
	eq(taken.size() > 0, true, "walk-in can still take the bread")
	check(not s.rotifood.pack(o.order_id), "pack fails when stock is short")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 1, "failed pack removes nothing")
	eq(o.state, DeliveryOrder.WAITING_FOR_STOCK, "order waits for stock")
	s.display.return_lots(taken)
	# Order dua resep: satu kurang -> tidak ada yang dipotong.
	var o2: DeliveryOrder = s.rotifood._create({&"recipe_plain_loaf": 2, &"recipe_sugar_donut": 2}, 90.0, false)
	stock(s, &"recipe_sugar_donut", 1, 1)
	var before: Dictionary = s.display.sellable_by_recipe()
	check(not s.rotifood.pack(o2.order_id), "multi-recipe pack fails if any recipe is short")
	eq(s.display.sellable_by_recipe(), before, "atomic: display unchanged")
	stock(s, &"recipe_sugar_donut", 1, 1)
	check(s.rotifood.pack(o2.order_id), "pack succeeds once everything is in stock")
	eq(s.display.sellable_count(&"recipe_sugar_donut"), 0, "exact donuts removed")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 1, "exact loaves removed")
	check(o2.packed and not o2.economy_committed, "packed, sale not yet committed")
	var bal: float = s.economy.balance
	# Serah terima otomatis saat driver tiba.
	o2.driver_arrival_time = s.time.sim_seconds
	var guard: int = 0
	while o2.state != DeliveryOrder.COMPLETED and guard < 6000:
		s.step(s.tick_seconds)
		guard += 1
	eq(o2.state, DeliveryOrder.COMPLETED, "handover completes automatically")
	check(o2.economy_committed, "economy committed exactly once")
	check(s.economy.balance >= bal + o2.subtotal() - 0.001, "sale credited")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
