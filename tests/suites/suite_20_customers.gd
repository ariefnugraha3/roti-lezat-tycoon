extends TestSuite
## Antrean, pelanggan, kasir, RotiFood (GDD idle 6; v3.1 107).


func tests() -> Array:
	return [
		{"id": "TEST_QUEUE_001", "name": "no overlap/exclusive queue slots", "fn": _queue_exclusive},
		{"id": "TEST_QUEUE_002", "name": "pending admission maximum delay; drivers wait for a free slot", "fn": _pending_delay},
		{"id": "TEST_CUSTOMER_001", "name": "target display, substitution, and recipe weights by preference and relative price", "fn": _target_and_substitution},
		{"id": "TEST_CUSTOMER_002", "name": "purchase quantity distributions", "fn": _quantities},
		{"id": "TEST_CASHIER_001", "name": "estimated-wait lane choice with the counter's checkout time", "fn": _lane_choice},
		{"id": "TEST_ROTIFOOD_001", "name": "orders take their bread from the shelves all at once when it is there, otherwise wait; packing and handover are automatic at price x1.1", "fn": _rotifood_auto},
	]


## Toko tanpa kedatangan otomatis dan tanpa produksi: test mengatur semuanya.
func _quiet_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	freeze_production(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	return s


func _queue_exclusive() -> void:
	var s: SimulationRoot = _quiet_store(5150)
	var lane: QueueLane = s.queue.main_lane()
	var cap: int = lane.capacity()
	check(cap > 0, "main lane has slots")
	for i in cap:
		check(s.queue.reserve(lane, StringName("fake%d" % i)), "reservation %d within capacity" % i)
	check(not s.queue.reserve(lane, &"one_too_many"), "reservation beyond capacity refused (v3.1 57.6)")
	check(not s.queue.reserve(lane, &"fake0"), "an actor cannot hold two reservations")
	for i2 in cap:
		s.queue.release(StringName("fake%d" % i2))
	eq(lane.reservations.size(), 0, "released")
	# Banjir pembeli: antrean penuh, ada yang kabur, ada yang pending. Tidak ada dua
	# aktor diam di sel antrean yang sama dan invarian lane selalu sah. Pemilik
	# diparkir, karena checkout 3 detik mengosongkan antrean lebih cepat dari banjir.
	park_owner(s)
	for i3 in 4:
		stock(s, &"recipe_plain_loaf", 13, i3)
	var violations: int = 0
	var peak: int = 0
	var ticks: int = 0
	while ticks < 4800:
		if ticks % 15 == 0:
			s.demand._enqueue({"archetype": &"customer_bulk_buyer"})
			if s.display.total_sellable() < 20:
				for i4 in 4:
					stock(s, &"recipe_plain_loaf", 13, i4)
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
	eq(violations, 0, "no overlapping or over-capacity queue state during a rush")
	eq(peak, lane.capacity(), "the queue filled to capacity")
	free_sim(s)


func _pending_delay() -> void:
	var s: SimulationRoot = _quiet_store(6)
	stock(s, &"recipe_plain_loaf", 6)
	var lane: QueueLane = s.queue.main_lane()
	for i in lane.capacity():
		s.queue.reserve(lane, StringName("blocker%d" % i))
	var rep: float = s.reputation.reputation
	var missed: float = s.statistics.get_stat("total_customers_missed")
	s.demand._enqueue({"archetype": &"customer_generic"})
	eq(s.demand.pending.size(), 1, "full queue -> arrival becomes PENDING")
	eq(s.customers.active_count(), 0, "pending arrival has not spawned")
	s.run_for(29.0)
	eq(s.demand.pending.size(), 1, "still pending before 30 s")
	s.run_for(1.5)
	eq(s.demand.pending.size(), 0, "dropped after 30 simulation-seconds (v3.1 67)")
	eq(s.statistics.get_stat("total_customers_missed"), missed + 1.0, "counted as missed demand")
	near(s.reputation.reputation, rep, 0.0001, "silent cancellation does not change the reputation")
	s.demand._enqueue({"archetype": &"customer_generic"})
	s.run_for(5.0)
	s.queue.release(&"blocker0")
	s.run_for(0.2)
	eq(s.demand.pending.size(), 0, "admitted as soon as a slot frees")
	eq(s.customers.active_count(), 1, "customer spawned")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
	# Driver RotiFood menunggu slot di jalurnya tanpa batal (GDD idle 6.5).
	s = _quiet_store(7)
	var dl: QueueLane = s.queue.driver_lane()
	for i2 in dl.capacity():
		s.queue.reserve(dl, StringName("blocker_d%d" % i2))
	var o: DeliveryOrder = s.rotifood.debug_create_order({&"recipe_plain_loaf": 1}, 0.0)
	s.run_for(0.2)
	eq(o.driver_phase, &"pending", "driver pending while the lane is full")
	s.run_for(60.0)
	check(o.is_active() and o.driver_phase == &"pending", "the driver keeps waiting for a slot")
	s.queue.release(&"blocker_d0")
	s.run_for(1.0)
	check(o.driver != null, "the driver sets off once a slot frees")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _admit(s: SimulationRoot, archetype: StringName) -> Customer:
	var before: Array = s.customers.customers.keys()
	s.customers.try_admit({"archetype": archetype})
	for k: Variant in s.customers.customers.keys():
		if not before.has(k):
			var c: Customer = s.customers.customers[k]
			walk_in(s, c)
			return c
	return null


func _target_and_substitution() -> void:
	# Tanpa roti: pulang tanpa antre, reputasi turun (GDD idle 6.2, 6.6).
	var s: SimulationRoot = _quiet_store(71)
	var rep: float = s.reputation.reputation
	var c0: Customer = _admit(s, &"customer_generic")
	eq(c0.state, Customer.LEAVE_NO_STOCK, "no bread -> leaves without queuing")
	eq(s.queue.lane_of(c0.id), null, "no queue slot kept")
	near(s.reputation.reputation, rep - DataRegistry.idlef("reputation.lost_delta"), 0.0001, "a lost sale costs reputation.lost_delta")
	free_sim(s)
	# Target: rak & resep yang benar-benar punya roti.
	s = _quiet_store(72)
	var disp: int = s.equipment.placed_list(&"display")[0].iid
	stock(s, &"recipe_plain_loaf", 6, 1)
	var c1: Customer = _admit(s, &"customer_generic")
	eq(c1.target_recipe, &"recipe_plain_loaf", "targets the only recipe in stock")
	eq(c1.target_display, disp, "targets the display holding it")
	check(c1.target_qty >= 1 and c1.target_qty <= 4, "quantity within 1-4")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 6, "no stock reserved while walking (v3.1 84.2 step 7)")
	# Roti target habis sebelum tiba -> pindah sekali ke resep lain.
	s.display.take(&"recipe_plain_loaf", 6, -1, 0.0)
	stock(s, &"recipe_sugar_donut", 5, 2)
	var guard: int = 0
	while c1.held.is_empty() and c1.state != Customer.LEAVE_NO_STOCK and guard < 4000:
		s.step(s.tick_seconds)
		guard += 1
	check(c1.substitution_used, "substitution pipeline ran")
	eq(c1.target_recipe, &"recipe_sugar_donut", "substituted to the remaining recipe")
	check(not c1.held.is_empty(), "picked up the substitute from the display")
	near(float((c1.held[0] as Dictionary)["unit_price"]), s.unit_price(&"recipe_sugar_donut", disp), 0.001, "price locked from the shelf (GDD idle 7.2)")
	free_sim(s)
	# Bobot pilihan: preferensi × harga relatif (GDD idle 6.2).
	var office: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_office_worker")
	var w: Dictionary = CustomerManager.recipe_weights(office, [&"recipe_plain_loaf", &"recipe_sugar_donut"])
	var ex: float = DataRegistry.idlef("customers.price_weight_exponent")
	near(float(w["recipe_plain_loaf"]), 1.0, 0.0001, "practical loaf: preference 1.0, cheapest -> price factor 1")
	near(float(w["recipe_sugar_donut"]), 0.3 * pow(90.0 / 150.0, ex), 0.0001, "sweet donut: preference 0.3 x (90/150)^exponent")
	var snob: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_snob")
	var w2: Dictionary = CustomerManager.recipe_weights(snob, [&"recipe_plain_loaf"])
	near(float(w2["recipe_plain_loaf"]), CustomerManager.PREFERENCE_FLOOR, 0.0001, "a recipe nobody prefers keeps the floor weight")
	# Level resep tidak menurunkan permintaannya: bobot memakai harga dasar.
	var s2: SimulationRoot = _quiet_store(73)
	s2.upgrades.recipe_levels[&"recipe_plain_loaf"] = 60
	eq(CustomerManager.recipe_weights(office, [&"recipe_plain_loaf", &"recipe_sugar_donut"]), w, "recipe levels never change the weights")
	free_sim(s2)


func _quantities() -> void:
	var s: SimulationRoot = new_sim(8080)
	var n: int = 20000
	for arch: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var hist: Dictionary = {}
		var total: float = 0.0
		for i in n:
			var q: int = s.customers._pick_quantity(arch)
			hist[q] = int(hist.get(q, 0)) + 1
			total += q
		var lo: int = 1 << 30
		var hi: int = -1
		for q2: Variant in hist.keys():
			lo = mini(lo, int(q2))
			hi = maxi(hi, int(q2))
		check(lo >= arch.quantity_min and hi <= arch.quantity_max, "%s stays in %d-%d (got %d-%d)" % [arch.id, arch.quantity_min, arch.quantity_max, lo, hi])
		near(total / float(n), CustomerManager.mean_quantity(arch), 0.2, "%s mean matches mean_quantity" % arch.id)
		if arch.quantity_mode == &"triangular":
			continue
		var w: Dictionary = CustomerManager.quantity_weights(arch)
		var sum_w: float = 0.0
		for v: Variant in w.values():
			sum_w += float(v)
		for q6: Variant in w.keys():
			var p: float = float(hist.get(q6, 0)) / float(n)
			near(p, float(w[q6]) / sum_w, 0.015, "%s P(qty=%d)" % [arch.id, int(q6)])
	eq(DataRegistry.archetype(&"customer_bulk_buyer").quantity_partial_min, 3, "bulk buyer accepts partial >= 3")
	free_sim(s)


func _lane_choice() -> void:
	var s: SimulationRoot = _quiet_store(404)
	var lanes: Array[QueueLane] = s.queue.lanes
	var a: QueueLane = lanes[0]
	var b: QueueLane = lanes[1]
	check(a.main and not b.main, "lane A is the owner's lane, lane B a cashier's")
	_man(s, a)
	s.staff.lane_assign = {"staff_cashier_budi": b.id}
	eq(s.queue.open_physical_lanes().size(), 2, "both lanes open: the owner at A, a cashier at B")
	var co: float = s.upgrades.checkout_seconds()
	near(co, 3.0, 0.0001, "checkout 3 s at counter Lv 1 (GDD idle 8.2)")
	s.queue.reserve(b, &"q1")
	var from: Vector2i = s.world.entrance_cell()
	var wa: float = s.queue.estimated_wait(a, 0.0)
	var wb: float = s.queue.estimated_wait(b, 0.0)
	near(wa, co, 0.001, "lane A estimate = own transaction")
	near(wb, 2.0 * co, 0.001, "lane B estimate = 1 queued + own")
	var pick: QueueLane = s.queue.choose_physical_lane(from, 1.2)
	var walk_a: float = GridMath.tiles_to_meters(float(GridMath.manhattan(from, a.slots[0]))) / 1.2
	var walk_b: float = GridMath.tiles_to_meters(float(GridMath.manhattan(from, b.slots[1]))) / 1.2
	eq(pick.id, a.id if wa + walk_a < wb + walk_b else b.id, "lowest estimated total wait wins, not the shortest line")
	s.queue.release(&"q1")
	var pick2: QueueLane = s.queue.choose_physical_lane(from, 1000000.0)
	var da: int = GridMath.manhattan(from, a.slots[0])
	var db: int = GridMath.manhattan(from, b.slots[0])
	var want: StringName = a.id if (da < db or (da == db and String(a.id) < String(b.id))) else b.id
	eq(pick2.id, want, "tie broken by distance then lane_id")
	# Level kasir lebih tinggi = transaksi lebih cepat untuk semua jalur.
	s.upgrades.counter_level = 21
	near(s.upgrades.checkout_seconds(), maxf(1.0, 3.0 * pow(0.97, 20.0)), 0.0001, "checkout shrinks 3% per counter level")
	s.upgrades.counter_level = 200
	near(s.upgrades.checkout_seconds(), 1.0, 0.0001, "checkout never below 1 s")
	s.upgrades.counter_level = 1
	# Jalur yang jauh lebih panjang melepas pembeli terdepannya ke jalur terbuka
	# yang lebih pendek (v3.1 21.3).
	stock(s, &"recipe_plain_loaf", 6)
	_man(s, a)
	var c: Customer = _admit(s, &"customer_generic")
	if c != null and c.state != Customer.LEAVE_NO_STOCK:
		_man(s, a)
		var first: StringName = c.lane_id
		var other: StringName = b.id if first == a.id else a.id
		s.queue.reserve(s.queue.lane(first), &"late1")
		s.queue.reserve(s.queue.lane(first), &"late2")
		s.customers.rebalance_lanes()
		eq(c.lane_id, other, "the longer lane hands its customer to the shorter one")
		eq(s.queue.check_invariants(), "", "queue invariants after the move")
	free_sim(s)


## Pemilik berdiri di titik kasir jalur utama dan melayaninya.
func _man(s: SimulationRoot, lane: QueueLane) -> void:
	s.player.task = {}
	s.player.actor.place_at(lane.floor_id, lane.cashier_point)
	s.player.manning_lane = lane.id


func _rotifood_auto() -> void:
	var s: SimulationRoot = _quiet_store(909)
	var disp: int = s.equipment.placed_list(&"display")[0].iid
	stock(s, &"recipe_plain_loaf", 3, 0)
	var o: DeliveryOrder = s.rotifood.debug_create_order({&"recipe_plain_loaf": 3}, 600.0)
	eq(o.state, DeliveryOrder.TO_PACK, "accepted automatically and its bread reserved at once (GDD idle 6.5)")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 0, "the reserved bread left the shelf")
	near(o.subtotal(), Money.round_half_up(s.unit_price(&"recipe_plain_loaf", disp) * DataRegistry.idlef("rotifood.price_mult")) * 3.0, 0.001, "order price = shelf price x rotifood.price_mult")
	# Dua resep, satu kurang: tidak ada yang diambil, pesanan menunggu.
	var o2: DeliveryOrder = s.rotifood.debug_create_order({&"recipe_plain_loaf": 2, &"recipe_sugar_donut": 2}, 0.0)
	stock(s, &"recipe_sugar_donut", 1, 1)
	stock(s, &"recipe_plain_loaf", 2, 0)
	s.run_for(0.2)
	eq(o2.state, DeliveryOrder.WAITING_FOR_STOCK, "waits while any recipe is short")
	eq(s.display.sellable_count(&"recipe_sugar_donut"), 1, "atomic: nothing taken")
	stock(s, &"recipe_sugar_donut", 1, 1)
	var guard: int = 0
	while o2.state == DeliveryOrder.WAITING_FOR_STOCK and guard < 100:
		s.step(s.tick_seconds)
		guard += 1
	check(o2.is_reserved(), "reserved once every recipe is in stock")
	var sub2: float = o2.subtotal()
	var bal: float = s.economy.balance
	guard = 0
	while (o.state != DeliveryOrder.PACKED or o2.state != DeliveryOrder.COMPLETED) and guard < 12000:
		s.step(s.tick_seconds)
		guard += 1
	check(o.packed, "the owner packed the first order with no tap")
	eq(o2.state, DeliveryOrder.COMPLETED, "the second order was packed and handed over automatically")
	check(o2.economy_committed, "economy committed exactly once")
	near(s.economy.balance - bal, sub2, 0.001, "exactly the order price was credited")
	check(s.statistics.get_stat("total_rotifood_orders_completed") >= 1.0, "completed orders counted")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
	# Driver yang kesabarannya habis: pesanan batal, roti kembali ke rak, reputasi turun.
	s = _quiet_store(910)
	stock(s, &"recipe_plain_loaf", 2, 0)
	var o3: DeliveryOrder = s.rotifood.debug_create_order({&"recipe_plain_loaf": 2}, 0.0)
	check(o3.is_reserved(), "bread reserved")
	# Pengemasan diklaim pemilik tetapi tidak pernah selesai.
	o3.packer_id = PlayerTaskManager.PLAYER_ID
	o3.state = DeliveryOrder.PACKING
	var rep: float = s.reputation.reputation
	guard = 0
	while o3.is_active() and guard < 20000:
		s.step(s.tick_seconds)
		guard += 1
	eq(o3.state, DeliveryOrder.CANCELLED, "an impatient driver cancels the order")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), 2, "the reserved bread went back to the shelf")
	near(s.reputation.reputation, rep - DataRegistry.idlef("reputation.lost_delta"), 0.0001, "a lost order costs reputation.lost_delta")
	free_sim(s)
