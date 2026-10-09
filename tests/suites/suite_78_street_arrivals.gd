extends TestSuite
## Kedatangan dari ujung trotoar (keputusan maintainer 2026-10-09, GDD 20.1):
## pembeli, pengunjung lihat-lihat, driver RotiFood, kurir, dan pemeran kejutan
## berjalan dari ujung jalan ke pintu, dan yang pulang berjalan kembali ke ujung.


func tests() -> Array:
	return [
		{"id": "ACC_20_STREET_ARRIVAL", "name": "20.1 buyers come from either end of the pavement, walk along it and turn in at the door; only then they ring the bell, count as entered and choose their bread; their queue slot is kept and their patience does not drain on the way", "fn": _arrival},
		{"id": "ACC_20_STREET_PATHS", "name": "20.1 at every tier the walk from both ends of the pavement to the door is clear of everything in the neighbourhood and the holiday decorations, and starts off the shop's sides", "fn": _paths_clear},
		{"id": "ACC_22_DRIVER_ARRIVAL", "name": "22.6 a RotiFood driver sets off from the end of the pavement early by the length of the walk, so he reaches the door at the scheduled time; his patience starts at the door; a rejected order turns him back to the end of the pavement", "fn": _driver},
		{"id": "ACC_24_COURIER_ARRIVAL", "name": "5.2.3 the supply courier sets off from the end of the pavement early by the length of the walk and reaches the door at the Market's ETA", "fn": _courier},
		{"id": "ACC_20_STREET_LEAVERS", "name": "20.1 a buyer who walks out of the door keeps walking along the pavement to its end, as a view only: the simulation has already let them go", "fn": _leavers},
		{"id": "ACC_31_SURPRISE_STREET", "name": "31.9 a surprise performer who walks comes from the end of the pavement, goes into the shop and leaves along the pavement again", "fn": _surprise},
	]


func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	return s


func _admit(s: SimulationRoot, archetype: StringName) -> Customer:
	var before: Array = s.customers.customers.keys()
	s.customers.try_admit({"archetype": archetype, "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})
	for k: Variant in s.customers.customers.keys():
		if not before.has(k):
			return s.customers.customers[k]
	return null


func _location(tier: int) -> LocationDefinition:
	for loc: LocationDefinition in DataRegistry.locations():
		if loc.tier == tier:
			return loc
	return null


## Ujung trotoar yang terdekat dengan `p` (jarak).
func _end_distance(loc: LocationDefinition, p: Vector2) -> float:
	var d: float = INF
	for side: int in [-1, 1]:
		d = minf(d, p.distance_to(StreetPaths.approach(loc, side)[0]))
	return d


# ===========================================================================
# PEMBELI
# ===========================================================================

func _arrival() -> void:
	var s: SimulationRoot = _open_store(7801)
	stock(s, &"recipe_plain_loaf", 6)
	var loc: LocationDefinition = s.world.location
	var door: Vector2 = GridMath.cell_center(loc.entrance_cell)
	var walk_z: float = StreetPaths.walk_z(loc.tier)
	var sides: Dictionary = {}
	for i in 2:
		var entered: int = s.customers.entered_today
		var c: Customer = _admit(s, &"customer_generic")
		if not check(c != null, "buyer %d is admitted" % (i + 1)):
			break
		eq(c.state, Customer.APPROACHING, "buyer %d comes along the pavement first" % (i + 1))
		check(c.actor.outside and c.actor.pos.y < 0.0, "starts outside the shop")
		check(_end_distance(loc, c.actor.pos) < 0.01, "starts at an end of the pavement, off the shop's sides (%s)" % c.actor.pos)
		var side: int = -1 if c.actor.pos.x < door.x else 1
		sides[side] = true
		check(s.queue.lane_of(c.id) != null, "holds its queue slot from the start")
		eq(s.customers.entered_today, entered, "not counted as entered on the pavement")
		var t0: float = s.time.sim_seconds
		var drained: bool = false
		var off_line: bool = false
		while c.state == Customer.APPROACHING and s.time.sim_seconds - t0 < 120.0:
			s.step(s.tick_seconds)
			if c.state != Customer.APPROACHING:
				break
			if c.patience < c.patience_max - 0.0001:
				drained = true
			var p: Vector2 = c.actor.pos
			if absf(p.y - walk_z) > 0.01 and absf(p.x - door.x) > 0.01:
				off_line = true
		var took: float = s.time.sim_seconds - t0
		check(not drained, "patience does not drain on the pavement")
		check(not off_line, "walks the pavement line, then straight in to the door")
		eq(c.actor.cell(), s.world.entrance_cell(), "steps in through the front door")
		eq(s.customers.entered_today, entered + 1, "counted when stepping in")
		near(took, StreetPaths.approach_seconds(loc, side, c.actor.speed_mps), 0.3, "the walk takes as long as the path is long")
		eq(c.target_recipe, &"recipe_plain_loaf", "chooses its bread once inside")
	check(sides.has(-1) and sides.has(1), "buyers come from both ends of the pavement")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


## Jarak terdekat segmen p-q ke segitiga a-b-c (bidang datar XZ) kurang dari r.
static func _seg_near_tri(p: Vector2, q: Vector2, a: Vector2, b: Vector2, c: Vector2, r: float) -> bool:
	var lo := Vector2(minf(a.x, minf(b.x, c.x)), minf(a.y, minf(b.y, c.y))) - Vector2(r, r)
	var hi := Vector2(maxf(a.x, maxf(b.x, c.x)), maxf(a.y, maxf(b.y, c.y))) + Vector2(r, r)
	if maxf(p.x, q.x) < lo.x or minf(p.x, q.x) > hi.x or maxf(p.y, q.y) < lo.y or minf(p.y, q.y) > hi.y:
		return false
	if Geometry2D.point_is_inside_triangle(p, a, b, c) or Geometry2D.point_is_inside_triangle(q, a, b, c):
		return true
	for e: Array in [[a, b], [b, c], [c, a]]:
		var cp: PackedVector2Array = Geometry2D.get_closest_points_between_segments(p, q, e[0], e[1])
		if cp[0].distance_to(cp[1]) < r:
			return true
	return false


## Segitiga setinggi badan chibi (bukan permukaan tanah, bukan daun atau atap di
## atas kepala, kepala tertinggi ~1,05 m) yang terlalu dekat dengan jalur jalan
## kaki. Mengembalikan beberapa contoh pusat segitiganya.
func _blockers(arrays: Array, paths: Array, r: float) -> Array[String]:
	var out: Array[String] = []
	var count: int = 0
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for t in range(0, idx.size(), 3):
		var a: Vector3 = v[idx[t]]
		var b: Vector3 = v[idx[t + 1]]
		var c: Vector3 = v[idx[t + 2]]
		if maxf(a.y, maxf(b.y, c.y)) < 0.15 or minf(a.y, minf(b.y, c.y)) > 1.2:
			continue
		var a2 := Vector2(a.x, a.z)
		var b2 := Vector2(b.x, b.z)
		var c2 := Vector2(c.x, c.z)
		for path: PackedVector2Array in paths:
			for k in range(1, path.size()):
				if _seg_near_tri(path[k - 1], path[k], a2, b2, c2, r):
					count += 1
					if out.size() < 4:
						out.append("%s" % ((a + b + c) / 3.0))
	if count > out.size():
		out.append("... %d triangles" % count)
	return out


func _paths_clear() -> void:
	for tier in range(1, 6):
		var loc: LocationDefinition = _location(tier)
		var f: FloorDefinition = loc.floor_def(loc.store_floor())
		var w: float = float(f.size.x) * NeighborhoodFactory.T
		var door: Vector2 = GridMath.cell_center(loc.entrance_cell)
		var paths: Array = []
		for side: int in [-1, 1]:
			var path: PackedVector2Array = StreetPaths.approach(loc, side)
			# Tanpa ujung terakhir di dalam pintu: ambang pintu milik ruangan toko.
			var outside := PackedVector2Array([path[0], path[1], Vector2(door.x, -0.05)])
			paths.append(outside)
			check(path[0].x < -1.0 or path[0].x > w + 1.0, "Tier %d: the walk starts off the shop's side (x %.2f)" % [tier, path[0].x])
			check(path[0].y < 0.0, "Tier %d: on the pavement in front of the shop" % tier)
			eq(path[path.size() - 1], door, "Tier %d: and ends in the door" % tier)
		var n: Node3D = NeighborhoodFactory.build(loc, f)
		var street: Array = (n.get_node("Street") as MeshInstance3D).mesh.surface_get_arrays(0)
		var hits: Array[String] = _blockers(street, paths, 0.16)
		eq(hits.size(), 0, "Tier %d: nothing in the neighbourhood stands on the walk to the door %s" % [tier, hits])
		n.free()
		for theme in 3:
			var deco: MeshInstance3D = HolidayFactory.build_outside(f, theme)
			if deco.mesh != null:
				var hits2: Array[String] = _blockers(deco.mesh.surface_get_arrays(0), paths, 0.16)
				eq(hits2.size(), 0, "Tier %d: holiday decorations (theme %d) leave the walk free %s" % [tier, theme, hits2])
			deco.free()


# ===========================================================================
# DRIVER DAN KURIR
# ===========================================================================

func _driver() -> void:
	var s: SimulationRoot = _open_store(7803)
	var loc: LocationDefinition = s.world.location
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 1)
	o.driver_arrival_time = s.time.sim_seconds + 60.0
	var lead: float = s.rotifood.approach_seconds(o)
	check(lead > 3.0, "the driver has a walk from the end of the pavement (%.1f s)" % lead)
	var set_off: float = -1.0
	var at_door: float = -1.0
	var drained: bool = false
	var guard: int = 0
	while at_door < 0.0 and guard < 4000:
		s.step(s.tick_seconds)
		guard += 1
		if set_off < 0.0 and o.driver_phase == &"approaching":
			set_off = s.time.sim_seconds
			check(o.driver.outside and _end_distance(loc, o.driver.pos) < 0.3, "sets off at the end of the pavement")
		if o.driver_phase == &"approaching" and o.driver_patience < o.driver_patience_max - 0.0001:
			drained = true
		if o.driver_phase == &"entering":
			at_door = s.time.sim_seconds
	near(set_off, o.driver_arrival_time - lead, 0.2, "sets off early by the length of the walk")
	near(at_door, o.driver_arrival_time, 0.3, "reaches the door at the scheduled time")
	check(not drained, "patience starts at the door")
	if o.driver != null:
		eq(o.driver.cell(), s.world.entrance_cell(), "comes in through the front door")
	# Order ditolak saat driver masih di trotoar: ia berbalik ke ujung trotoar.
	var o2: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 1)
	o2.driver_arrival_time = s.time.sim_seconds + 40.0
	guard = 0
	while o2.driver_phase != &"approaching" and guard < 2000:
		s.step(s.tick_seconds)
		guard += 1
	s.run_for(2.0)
	if not check(o2.driver_phase == &"approaching" and o2.driver != null, "the second driver is on his way"):
		free_sim(s)
		return
	check(s.rotifood.reject(o2.order_id), "the order is rejected while he walks")
	eq(o2.driver_phase, &"leaving", "the driver turns back")
	check(o2.driver != null and o2.driver.outside, "on the pavement")
	var last: Vector2 = o2.driver.pos
	guard = 0
	while o2.driver != null and guard < 4000:
		last = o2.driver.pos
		s.step(s.tick_seconds)
		guard += 1
	eq(o2.driver_phase, &"gone", "and is gone once at the end")
	check(_end_distance(loc, last) < 0.3, "at the end of the pavement (%s)" % last)
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _courier() -> void:
	var s: SimulationRoot = new_sim(7804)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	s.supply.unlock_market()
	run_until(s, 9.0 * 3600.0)
	var r: Dictionary = s.supply.purchase({&"ingredient_flour": 1})
	check(bool(r["ok"]) and not bool(r["instant"]), "a daytime purchase goes to a courier")
	var o: Dictionary = s.supply.orders[s.supply.orders.size() - 1]
	var oid: int = int(o["order_id"])
	var eta: float = float(o["arrival_game_time"])
	var lead: float = s.supply.approach_game_seconds(oid)
	check(lead > 60.0, "the courier has a walk from the end of the pavement (%.0f in-game s)" % lead)
	run_until(s, eta - lead - 120.0)
	eq(s.supply.couriers.size(), 0, "no courier before he sets off")
	var set_off: float = -1.0
	var at_door: float = -1.0
	while at_door < 0.0 and s.time.time_seconds < eta + 900.0:
		s.step(s.tick_seconds)
		if set_off < 0.0 and s.supply.couriers.has(oid):
			set_off = s.time.time_seconds
			var a: SimActor = s.supply.couriers[oid]
			check(a.outside and _end_distance(s.world.location, a.pos) < 0.3, "sets off at the end of the pavement")
		if str(o["state"]) == String(SupplyOrderManager.COURIER_ENTERING):
			at_door = s.time.time_seconds
	near(set_off, eta - lead, 6.0, "sets off early by the length of the walk")
	near(at_door, eta, 12.0, "reaches the door at the Market's ETA")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


# ===========================================================================
# YANG PULANG DAN KEJUTAN
# ===========================================================================

func _leavers() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(7805)
	var loc: LocationDefinition = s.world.location
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	await runner.get_tree().process_frame
	# Tanpa roti di rak: ia masuk, tidak menemukan apa-apa, lalu keluar.
	var c: Customer = _admit(s, &"customer_generic")
	var id: StringName = c.id
	var guard: int = 0
	while s.customers.customer(id) != null and guard < 600:
		for k in 10:
			s.step(s.tick_seconds)
		await runner.get_tree().process_frame
		guard += 1
	eq(s.customers.customer(id), null, "the buyer left the simulation at the door")
	await runner.get_tree().process_frame
	var mine: Dictionary = {}
	for lv: Dictionary in world.leavers():
		if (lv["view"] as ActorView).actor_id == id:
			mine = lv
	check(not mine.is_empty(), "their body keeps walking out of the door")
	if not mine.is_empty():
		var a: SimActor = mine["actor"]
		var last: Vector2 = a.pos
		guard = 0
		while world.leavers().has(mine) and guard < 600:
			last = a.pos
			for k2 in 10:
				s.step(s.tick_seconds)
			await runner.get_tree().process_frame
			guard += 1
		check(not world.leavers().has(mine), "until they are gone")
		check(_end_distance(loc, last) < 0.6, "at the end of the pavement (%s)" % last)
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


func _surprise() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(7806)
	s.tutorial.skip()
	var loc: LocationDefinition = s.world.location
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	await runner.get_tree().process_frame
	var sd: SurpriseDirector = world.surprises
	check(sd.start(&"mascot"), "a surprise starts")
	sd.update(0.1)
	var a: SimActor = sd._cast[0]["actor"]
	check(a.pos.y < 0.0 and _end_distance(loc, a.pos) < 0.5, "the mascot comes from the end of the pavement (%s)" % a.pos)
	var inside: bool = false
	var last: Vector2 = a.pos
	var t: float = 0.0
	while sd._kind != &"" and t < SurpriseDirector.MAX_SECONDS:
		sd.update(0.1)
		t += 0.1
		if a.pos.y >= 0.0:
			inside = true
		last = a.pos
	check(inside, "goes into the shop")
	check(_end_distance(loc, last) < 0.6, "and leaves along the pavement to its end (%s)" % last)
	sd.abort()
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
