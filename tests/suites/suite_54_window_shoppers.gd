extends TestSuite
## Hari 1-3 yang lebih ramai dan pengunjung lihat-lihat (keputusan maintainer
## 2026-10-01): stok = permintaan 48/54/60 roti, pembeli tersebar dari buka sampai
## menjelang tutup, dan pengunjung yang masuk, melihat rak, lalu pulang tanpa
## membeli (GDD 2, 20.3, 20.12).


func tests() -> Array:
	return [
		{"id": "ACC_20_OPENING_MANIFEST", "name": "20.3 Days 1-3 stock exactly 48/54/60 breads, with 18+ buyers spread from opening to 17:30 and window shoppers in between", "fn": _manifest},
		{"id": "ACC_20_WINDOW_SHOPPER", "name": "20.12 a window shopper walks in, looks at the display from a free spot, and leaves without buying or touching the rating", "fn": _lifecycle},
		{"id": "ACC_20_WINDOW_SHOPPER_LIMITS", "name": "20.12 window shoppers need no queue slot, keep to the tier cap and their own spots, and vanish at closing without penalty", "fn": _limits},
		{"id": "ACC_20_WINDOW_SHOPPER_GIVE_WAY", "name": "20.12 a window shopper standing where a buyer must wait steps aside, and the buyers fare exactly as without it", "fn": _give_way},
		{"id": "ACC_20_WINDOW_SHOPPER_COSMETIC", "name": "20.12/116 buyers, sales and ratings play out identically with or without window shoppers", "fn": _cosmetic},
		{"id": "ACC_20_WINDOW_SHOPPER_SAVE", "name": "20.12/77.2 a window shopper saved mid-look returns to its spot and the shop plays on identically", "fn": _save},
		{"id": "TEST_VIS_WINDOW_SHOPPER", "name": "20.12 window shoppers show no patience bar, sweep their head across the shelf, say a funny English line as they give up, and leave empty-handed", "fn": _visual},
	]


## Toko buka pukul 08:00:10 tanpa pembeli, pesanan, atau pengunjung terjadwal.
func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	return s


func _window_shoppers(s: SimulationRoot) -> Array[Customer]:
	var out: Array[Customer] = []
	for c: Customer in s.customers.sorted():
		if c.window_shopper:
			out.append(c)
	return out


func _step_until(s: SimulationRoot, done: Callable, max_seconds: float = 120.0) -> bool:
	var t: float = 0.0
	while not bool(done.call()) and t < max_seconds and s.is_running():
		s.step(s.tick_seconds)
		t += s.tick_seconds
	return bool(done.call())


func _manifest() -> void:
	var want: Array[int] = [48, 54, 60]
	for day in range(1, 4):
		var plan: Dictionary = DataRegistry.opening_day(day)
		var r: RecipeDefinition = DataRegistry.recipe(StringName(str(plan["recipe_id"])))
		var walk_units: int = 0
		var times: Array[float] = []
		var walk_times: Array[float] = []
		for w: Variant in plan["walk_ins"]:
			walk_units += int((w as Dictionary)["requested_quantity"])
			walk_times.append(float((w as Dictionary)["spawn_time"]))
			if day == 1:
				check(StringName(str((w as Dictionary)["customer_archetype"])) != &"customer_office_worker",
					"Day 1 keeps to patient buyers (GDD 2)")
		var order_units: int = 0
		for o: Variant in plan["rotifood_orders"]:
			order_units += int((o as Dictionary)["requested_quantity"])
		var lookers: Array = plan.get("window_shoppers", [])
		times.append_array(walk_times)
		for ws: Variant in lookers:
			times.append(float((ws as Dictionary)["spawn_time"]))
		times.sort()
		eq(int(plan["batches"]) * r.batch_yield, want[day - 1], "Day %d storage holds %d breads" % [day, want[day - 1]])
		eq(walk_units + order_units, want[day - 1], "Day %d demand equals the stock exactly" % day)
		check((plan["walk_ins"] as Array).size() >= 18, "Day %d has at least 18 buyers (got %d)" % [day, (plan["walk_ins"] as Array).size()])
		check(lookers.size() >= 8 and lookers.size() <= 10, "Day %d has 8-10 window shoppers, about 1 visitor in 3 (got %d)" % [day, lookers.size()])
		check(walk_times[0] <= 8.25 * 3600.0, "Day %d first buyer by 08:15" % day)
		check(walk_times[walk_times.size() - 1] >= 17.25 * 3600.0 and walk_times[walk_times.size() - 1] < 17.75 * 3600.0,
			"Day %d last buyer between 17:15 and 17:45" % day)
		var gap: float = 0.0
		for i in range(1, times.size()):
			gap = maxf(gap, times[i] - times[i - 1])
		check(gap <= 35.0 * 60.0, "Day %d: someone walks in at least every 35 in-game minutes (longest gap %d min)" % [day, int(gap / 60.0)])
	# New Game: gudang Hari 1 berisi 8 batch roti tawar (GDD 2).
	var s: SimulationRoot = new_sim(2000)
	eq(s.inventory.count(&"ingredient_flour"), 8, "day 1 flour for 8 batches")
	eq(s.demand.demand_total_today, 48, "HUD demand target 48")
	eq(s.demand.scripted_window_shoppers.size(), (DataRegistry.opening_day(1)["window_shoppers"] as Array).size(), "window shoppers planned at 05:00")
	free_sim(s)


func _lifecycle() -> void:
	var s: SimulationRoot = _open_store(2001)
	stock(s, &"recipe_plain_loaf", 6)
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var rating: float = s.reputation.physical
	var lane: QueueLane = s.queue.main_lane()
	var floor_id: StringName = s.world.store_floor()
	var fg: FloorGrid = s.world.grid(floor_id)
	var demand_before: int = s.demand.demand_total_today
	check(s.customers.try_admit_window_shopper(&"customer_generic"), "a window shopper walks in")
	var list: Array[Customer] = _window_shoppers(s)
	eq(list.size(), 1, "one window shopper inside")
	if list.is_empty():
		free_sim(s)
		return
	var w: Customer = list[0]
	eq(w.actor.cell(), s.world.entrance_cell(), "enters through the front door (GDD 83.1)")
	eq(s.customers.window_shoppers_today, 1, "counted as a window shopper")
	eq(s.customers.entered_today, 0, "not counted as a buyer")
	eq(s.demand.demand_total_today, demand_before, "adds no demand")
	var looked: bool = false
	var spot_ok: bool = true
	var in_lane: bool = false
	var guard: int = 0
	while s.customers.customer(w.id) != null and guard < 20000:
		s.step(s.tick_seconds)
		guard += 1
		if s.queue.lane_of(w.id) != null or lane.has_actor(w.id):
			in_lane = true
		if w.state == Customer.BROWSING and not w.actor.has_route():
			looked = true
			var c: Vector2i = w.actor.cell()
			var ring: int = 1 << 30
			for f: Vector2i in disp.footprint_cells():
				ring = mini(ring, maxi(absi(c.x - f.x), absi(c.y - f.y)))
			var flag: int = fg.flag(c)
			if c != w.look_cell or ring > 2 or fg.access_at.has(c) or fg.is_door(c) \
					or flag == FloorGrid.Flag.QUEUE_RESERVED or flag == FloorGrid.Flag.INTERACTION_RESERVED:
				spot_ok = false
			var center: Vector2 = CustomerManager._cells_center(disp.footprint_cells())
			var ahead: Vector2 = (CustomerManager._cells_center(disp.front_cells()) - center).normalized()
			if (GridMath.cell_center(c) - center).dot(ahead) < -0.01:
				spot_ok = false
			if w.actor.facing.dot((center - w.actor.pos).normalized()) < 0.7:
				spot_ok = false
	check(looked, "stopped to look around")
	check(spot_ok, "looked from a free spot in front of or beside the display, facing it, never behind it or on a queue slot, service point, access tile or door")
	check(not in_lane, "never took a queue slot")
	eq(s.customers.customer(w.id), null, "walked out and was cleaned up at the door")
	eq(s.display.total_units(), 6, "took no bread")
	near(s.reputation.physical, rating, 0.000001, "rating untouched")
	eq(s.customers.no_stock_today, 0, "not a 'left without buying' failure")
	eq(s.customers.abandoned_today, 0, "not an abandonment")
	eq(s.demand.missed_today, 0, "not missed demand")
	eq(int(s.statistics.stats.get("total_customers_left_no_purchase", 0)), 0, "no lifetime 'left without buying' count")
	eq(s.world.point_holder(floor_id, w.look_cell), &"", "spot released")
	# Tanpa roti sama sekali ia tetap melihat-lihat dan pulang tanpa penalti.
	s.display.take(&"recipe_plain_loaf", 6, Callable(), -1, 0.0)
	check(s.customers.try_admit_window_shopper(&"customer_school_child"), "window shoppers come even when the shelf is empty")
	var w2: Customer = _window_shoppers(s)[0]
	check(_step_until(s, func() -> bool: return s.customers.customer(w2.id) == null), "and leave again")
	near(s.reputation.physical, rating, 0.000001, "an empty shelf costs no rating for a window shopper")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _limits() -> void:
	var s: SimulationRoot = _open_store(2002)
	stock(s, &"recipe_plain_loaf", 6)
	var lane: QueueLane = s.queue.main_lane()
	for i in lane.capacity():
		s.queue.reserve(lane, StringName("blocker%d" % i))
	eq(lane.free_capacity(), 0, "queue full")
	var cap: int = int((DataRegistry.bal("window_shopper.max_inside_by_tier") as Array)[0])
	eq(cap, 2, "Tier 1 lets two window shoppers in at once")
	for i2 in cap:
		check(s.customers.try_admit_window_shopper(&"customer_generic"), "window shopper %d enters although the queue is full" % (i2 + 1))
	check(not s.customers.try_admit_window_shopper(&"customer_generic"), "one more is turned away at the tier cap")
	eq(s.customers.window_shopper_count(), cap, "cap respected")
	eq(s.demand.pending.size(), 0, "a turned-away window shopper never waits as a pending arrival")
	eq(s.demand.missed_today, 0, "and is not missed demand")
	eq(lane.reservations.size(), lane.capacity(), "queue reservations untouched")
	var spots: Dictionary = {}
	for w: Customer in _window_shoppers(s):
		spots[w.look_cell] = true
	eq(spots.size(), cap, "each window shopper has its own spot")
	# Anggaran aktor lokasi (GDD 37.2) juga membatasi.
	for i3 in cap:
		s.queue.release(StringName("blocker%d" % i3))
	check(s.customers.active_actor_count() < s.world.location.active_actor_budget, "Tier 1 stays inside its actor budget")
	# Pukul 18:00 mereka ikut keluar tanpa penalti (GDD 104).
	var rating: float = s.reputation.physical
	s.debug_set_time(s.time.close_time - 1.0)
	s.run_for(1.0)
	eq(s.time.phase, TimeManager.SUMMARY, "shop closed")
	eq(s.customers.customers.size(), 0, "nobody left inside after closing")
	near(s.reputation.physical, rating, 0.000001, "closing with window shoppers inside costs no rating")
	eq(int(s.reports.last_report.get("customers_entered", -1)), 0, "the Daily Summary counts only buyers")
	free_sim(s)


## Pembeli kedua yang harus menunggu giliran di rak memakai sel tempat pengunjung
## lihat-lihat berdiri: pengunjung itu minggir, dan kedua pembeli bernasib persis
## sama dengan toko kembar tanpa pengunjung.
func _give_way() -> void:
	var states: Array[Dictionary] = []
	for with_looker: bool in [true, false]:
		var s: SimulationRoot = _open_store(2005)
		stock(s, &"recipe_plain_loaf", 12)
		var floor_id: StringName = s.world.store_floor()
		var wait_cell: Vector2i = s.customers._buyer_wait_cells(floor_id).keys()[0]
		var w: Customer = null
		if with_looker:
			check(s.customers.try_admit_window_shopper(&"customer_generic"), "a window shopper walks in")
			w = _window_shoppers(s)[0]
		# Tick yang sama persis di kedua toko; pengunjung terus melihat begitu tiba.
		for i0 in 160:
			s.step(s.tick_seconds)
			if w != null and w.state == Customer.BROWSING and w.browse_left < 500.0:
				w.browse_left = 999.0
		if with_looker:
			eq(w.state, Customer.BROWSING, "the window shopper is looking")
			eq(w.look_cell, wait_cell, "right in front of the display, where a second buyer would wait")
		for i in 2:
			s.customers.try_admit({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 2, "patience_override": 999.0})
		var contended: bool = false
		var overlap: bool = false
		var t: float = 0.0
		while t < 40.0:
			s.step(s.tick_seconds)
			t += s.tick_seconds
			for b: Customer in s.customers.sorted():
				if b.window_shopper:
					continue
				if b.actor.goal_cell == wait_cell:
					contended = true
				if w != null and s.customers.customer(w.id) != null and not b.actor.moving and not w.actor.moving \
						and b.actor.cell() == w.actor.cell():
					overlap = true
		if with_looker:
			check(contended, "the second buyer had to wait for the display")
			check(s.customers.customer(w.id) == null or w.look_cell != wait_cell, "the window shopper stepped aside")
			check(not overlap, "a buyer and the window shopper never stand on the same tile")
		states.append(_gameplay_state(s))
		free_sim(s)
	same_state(states[1], states[0], "the buyers fare exactly as in the shop without the window shopper")


## Dua toko kembar, satu tanpa pengunjung lihat-lihat: selain stream kosmetik,
## penampilan aktor, dan pembukuan pengunjung itu sendiri, hasilnya identik.
func _cosmetic() -> void:
	# Hari 1: jadwal manifest.
	var a: SimulationRoot = new_sim(4747)
	var b: SimulationRoot = new_sim(4747)
	b.demand.scripted_window_shoppers.clear()
	run_day(a, SimBot.new(a))
	run_day(b, SimBot.new(b))
	check(a.customers.window_shoppers_today >= 8, "Day 1 had its window shoppers (%d)" % a.customers.window_shoppers_today)
	eq(b.customers.window_shoppers_today, 0, "the twin had none")
	same_state(_gameplay_state(b), _gameplay_state(a), "Day 1 plays out the same with or without window shoppers")
	print("      day 1: sold %d of %d, walk-ins served %d, window shoppers %d" % [int(a.reports.last_report["bread_sold"]),
		a.demand.demand_total_today, a.customers.served_today, a.customers.window_shoppers_today])
	free_sim(a)
	free_sim(b)
	# Hari 4+: aliran acak dari cosmetic_rng.
	var a2: SimulationRoot = new_sim(4848)
	var b2: SimulationRoot = new_sim(4848)
	for s: SimulationRoot in [a2, b2]:
		s.tutorial.skip()
		s.time.day = 4
		s.demand.plan_day()
	b2.demand.next_window_shopper_at = -1.0
	run_day(a2, SimBot.new(a2))
	run_day(b2, SimBot.new(b2))
	check(a2.customers.window_shoppers_today > 0, "Day 4 brought window shoppers (%d)" % a2.customers.window_shoppers_today)
	eq(b2.customers.window_shoppers_today, 0, "the twin had none")
	check(a2.customers.entered_today > 0, "Day 4 brought buyers (%d)" % a2.customers.entered_today)
	same_state(_gameplay_state(b2), _gameplay_state(a2), "Day 4 plays out the same with or without window shoppers")
	free_sim(a2)
	free_sim(b2)


static func _gameplay_state(s: SimulationRoot) -> Dictionary:
	var d: Dictionary = logical_state(s.capture_save())
	(((d["rng_states"] as Dictionary)["streams"]) as Dictionary).erase("cosmetic_rng")
	var cu: Dictionary = d["customers"]
	cu.erase("next_window_num")
	cu.erase("window_shoppers_today")
	var buyers: Array = []
	for c: Variant in cu["customers"]:
		if not bool((c as Dictionary).get("window_shopper", false)):
			buyers.append(c)
	cu["customers"] = buyers
	var dm: Dictionary = d["demand"]
	dm.erase("scripted_window_shoppers")
	dm.erase("next_window_shopper_at")
	d.erase("tutorial")
	return d


func _save() -> void:
	var s: SimulationRoot = _open_store(2003)
	stock(s, &"recipe_plain_loaf", 6)
	check(s.customers.try_admit_window_shopper(&"customer_indecisive"), "a window shopper walks in")
	var w: Customer = _window_shoppers(s)[0]
	check(_step_until(s, func() -> bool: return w.state == Customer.BROWSING), "reaches its spot")
	s.run_for(1.0)
	var snap: Dictionary = json_copy(s.capture_save())
	var s2: SimulationRoot = load_sim(snap)
	var w2: Customer = s2.customers.customer(w.id)
	check(w2 != null and w2.window_shopper, "restored as a window shopper")
	if w2 == null:
		free_sim(s)
		free_sim(s2)
		return
	eq(w2.state, Customer.BROWSING, "still looking after load")
	eq(w2.actor.cell(), w.look_cell, "back on its spot")
	near(w2.browse_left, w.browse_left, 0.000001, "the same look time remains")
	eq(s2.world.point_holder(s2.world.store_floor(), w2.look_cell), w2.id, "its spot is reserved again")
	s.run_for(30.0)
	s2.run_for(30.0)
	same_state(logical_state(s2.capture_save()), logical_state(s.capture_save()), "the reloaded shop plays on identically")
	eq(s2.customers.customer(w.id), null, "left after looking")
	# Save dari sebelum fitur ini (tanpa satu pun field pengunjung lihat-lihat)
	# tetap dimuat; hari itu berjalan tanpa pengunjung lihat-lihat.
	var old: Dictionary = json_copy(snap)
	var cu: Dictionary = old["customers"]
	cu["customers"] = []
	cu.erase("next_window_num")
	cu.erase("window_shoppers_today")
	(old["demand"] as Dictionary).erase("scripted_window_shoppers")
	(old["demand"] as Dictionary).erase("next_window_shopper_at")
	var s3: SimulationRoot = load_sim(old)
	eq(s3.demand.scripted_window_shoppers.size(), 0, "an old save has no window shoppers left that day")
	eq(s3.customers.next_window_num, 1, "window shopper ids start fresh")
	s3.run_for(10.0)
	eq(s3.check_invariants(), "", "old save loads and plays cleanly")
	for x: SimulationRoot in [s, s2, s3]:
		free_sim(x)


func _visual() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(2004)
	stock(s, &"recipe_plain_loaf", 6)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	check(s.customers.try_admit_window_shopper(&"customer_school_child"), "a window shopper walks in")
	var w: Customer = _window_shoppers(s)[0]
	var v: ActorView = null
	var t: float = 0.0
	while t < 60.0 and not (w.state == Customer.BROWSING and not w.actor.moving):
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
		t += s.tick_seconds
	world._process(0.05)
	v = world.views.get(w.id)
	check(v != null, "drawn in the shop")
	if v == null:
		world.queue_free()
		await runner.get_tree().process_frame
		free_sim(s)
		return
	check(v.is_looking_around(), "looks around while browsing")
	check(v._patience == null or not v._patience.visible, "no patience bar: a window shopper never waits")
	var head: Node3D = CharacterFactory.part(v.model, "Head")
	var lo: float = INF
	var hi: float = -INF
	for i in 50:
		world._process(0.1)
		lo = minf(lo, head.rotation.y)
		hi = maxf(hi, head.rotation.y)
	check(hi - lo > 0.4, "the head sweeps across the shelf (range %.2f rad)" % (hi - lo))
	eq(world.shopper_bubble(w.id) != null, WorldView.shopper_speaking(w), "a line bubble only on the last look")
	check(_step_until(s, func() -> bool: return w.state == Customer.LEAVING and w.actor.moving), "turns to leave")
	world._process(0.05)
	check(not v.is_looking_around(), "stops looking once walking out")
	near(head.rotation.y, 0.0, 0.0001, "head faces forward again")
	check(v._carry == null, "leaves empty-handed, without a paper bag")
	# Celetukan lucu berbahasa Inggris saat ia batal membeli (GDD 127.19).
	var bubble: ThoughtBubble = world.shopper_bubble(w.id)
	check(bubble != null and bubble.is_showing(), "a funny line pops up as they give up")
	if bubble != null:
		var key: String = bubble.current_key()
		check(DataRegistry.WINDOW_SHOPPER_LINES.has(key), "the line comes from the window shopper catalog (%s)" % key)
		eq(bubble.text().replace("\n", " "), Tx.t(key), "English text from the string catalog")
		eq(key, WorldView.shopper_line_key(w), "the same line every time for this visitor")
	check(_step_until(s, func() -> bool: return s.customers.customer(w.id) == null), "walks out")
	world._process(0.05)
	eq(world.shopper_bubble(w.id), null, "the bubble is gone with them")
	var keys: Dictionary = {}
	for seed_i in 40:
		var probe := Customer.new()
		probe.window_shopper = true
		probe.actor = SimActor.new()
		probe.actor.visual_seed = seed_i * 7919
		keys[WorldView.shopper_line_key(probe)] = true
	check(keys.size() >= 6, "visitors say different lines (%d of %d)" % [keys.size(), DataRegistry.WINDOW_SHOPPER_LINES.size()])
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
	PauseManager.clear_all()
