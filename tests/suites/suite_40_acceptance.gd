extends TestSuite
## Acceptance tambahan: modal awal, antrean RotiFood, patience, skala ruang,
## solver penempatan semua tier, jam satu kecepatan, dan batas efek.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_STARTING_CASH", "name": "idle 7.1: a new game opens with start_kr in one ledger entry", "fn": _starting_cash},
		{"id": "ACC_55_OJOL_QUEUE", "name": "55.3 dedicated RotiFood queue at Tier 3+", "fn": _ojol_queue},
		{"id": "ACC_55_PATIENCE", "name": "55.4/58 patience bar and drain", "fn": _patience},
		{"id": "ACC_SPATIAL", "name": "Appendix spatial scale 1-10", "fn": _spatial},
		{"id": "ACC_LAYOUT_SOLVER", "name": "opening stations fills every tier's slots with a valid layout", "fn": _layout_solver},
		{"id": "ACC_81_PLACEMENT", "name": "81.1/81.4 placement keeps paths and access tiles", "fn": _placement},
		{"id": "ACC_IDLE_ONE_SPEED", "name": "idle 0.2: one speed, 1 real second = 1 in-game minute; only the Pause menu stops the clock", "fn": _one_speed},
		{"id": "ACC_81_IN_USE", "name": "81.14 a station holding a batch cannot move", "fn": _in_use},
		{"id": "ACC_72_STOCKED_SHELF_MOVE", "name": "72 a shelf holding bread moves and turns with its bread", "fn": _stocked_shelf},
		{"id": "ACC_DECOR_KEEP_CLEAR", "name": "17.4 decoration tile marks match placement validation", "fn": _keep_clear},
		{"id": "ACC_129_LIMITS", "name": "129 transient effects stop at the cap", "fn": _effect_limit},
		{"id": "ACC_129_FX_TEARDOWN", "name": "129 one-shot effects freed early leave no errors behind", "fn": _effect_teardown},
	]


func _starting_cash() -> void:
	var s: SimulationRoot = new_sim()
	var start: float = DataRegistry.idlef("start_kr")
	near(s.economy.balance, start, 0.001, "balance = start_kr")
	eq(s.economy.ledger.size(), 1, "one opening ledger entry")
	near(float(s.economy.ledger[0]["amount"]), start, 0.001, "opening entry = start_kr")
	eq(Tx.kr(s.economy.balance), Tx.big(start) + " KR", "HUD formatter renders the balance")
	free_sim(s)


func _ojol_queue() -> void:
	var s: SimulationRoot = new_sim(33)
	jump_to_tier(s, 3)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	var rf: QueueLane = s.queue.rotifood_lane
	check(rf != null, "Tier 3 has a dedicated RotiFood lane")
	eq(rf.capacity(), 3, "RotiFood queue has 3 slots (v3.1 57.3)")
	eq(s.queue.driver_lane(), rf, "drivers use the dedicated lane")
	var phys_before: int = s.queue.physical_free_capacity()
	for i in rf.capacity():
		s.queue.reserve(rf, StringName("d_block%d" % i))
	var o: DeliveryOrder = s.rotifood.debug_create_order({&"recipe_plain_loaf": 1}, 0.0)
	s.run_for(1.0)
	eq(o.driver_phase, &"pending", "driver waits outside while the RotiFood queue is full")
	eq(s.queue.physical_free_capacity(), phys_before, "physical lanes untouched by the driver")
	free_sim(s)


func _patience() -> void:
	var c := Customer.new()
	c.patience_max = 30.0
	c.patience = 15.0
	near(c.patience_ratio(), 0.5, 0.0001, "bar ratio 0.5 (v3.1 55.4)")
	for st: StringName in [Customer.APPROACHING, Customer.ENTERING, Customer.BROWSING, Customer.SELECTING, Customer.CARRYING_TO_QUEUE]:
		c.state = st
		check(not c.drains_patience(), "%s does not drain patience" % st)
	var table: Dictionary = {&"customer_school_child": 55.0, &"customer_office_worker": 18.0, &"customer_bulk_buyer": 45.0,
		&"customer_snob": 28.0, &"customer_indecisive": 60.0, &"customer_critic": 25.0, &"customer_generic": 35.0}
	for id: StringName in table.keys():
		near(DataRegistry.archetype(id).base_patience_seconds, float(table[id]), 0.001, "%s patience (v3.1 58)" % id)
	near(float(DataRegistry.driver_def()["base_patience_seconds"]), 30.0, 0.001, "driver patience 30 s")
	# Office Worker sendirian di antrean yang tidak dilayani (pemilik diparkir):
	# 1,0/s selama 10 s, lalu ×1,15 karena tanpa progres (v3.1 58).
	var s: SimulationRoot = new_sim(44)
	freeze_production(s)
	park_owner(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	stock(s, &"recipe_plain_loaf", 6)
	s.customers.try_admit({"archetype": &"customer_office_worker"})
	var cu: Customer = s.customers.sorted()[0]
	var guard: int = 0
	while not cu.drains_patience() and guard < 4000:
		s.step(s.tick_seconds)
		guard += 1
	var t0: float = s.time.sim_seconds
	s.run_for(5.0)
	near(cu.patience, 18.0 - 5.0, 0.06, "baseline drain 1.0 per simulation-second")
	while cu.state != Customer.ABANDONING and cu.state != Customer.LEAVING and guard < 20000:
		s.step(s.tick_seconds)
		guard += 1
	var took: float = s.time.sim_seconds - t0
	near(took, 10.0 + 8.0 / 1.15, 0.15, "office worker gives up after 10 s + 8 s at x1.15")
	eq(s.display.total_units(), 6, "abandoning customer returned the bread")
	free_sim(s)


func _cells_in_zone(f: FloorDefinition, zone: StringName) -> int:
	var n: int = 0
	for z in f.size.y:
		for x in f.size.x:
			if f.zone_at(Vector2i(x, z)) == zone:
				n += 1
	return n


func _spatial() -> void:
	var t1: LocationDefinition = DataRegistry.location_by_tier(1)
	eq(t1.floors.size(), 1, "Tier 1 single floor")
	eq(t1.floors[0].size, Vector2i(6, 12), "Tier 1 grid 6 x 12")
	near(t1.floors[0].size.x * GridMath.WORLD_METERS_PER_TILE, 3.0, 0.000001, "Tier 1 width 3 m")
	near(t1.floors[0].size.y * GridMath.WORLD_METERS_PER_TILE, 6.0, 0.000001, "Tier 1 depth 6 m")
	eq(_cells_in_zone(t1.floors[0], &"store"), 36, "Tier 1 store 6 x 6")
	eq(_cells_in_zone(t1.floors[0], &"kitchen"), 36, "Tier 1 kitchen 6 x 6")
	var t2: LocationDefinition = DataRegistry.location_by_tier(2)
	eq(t2.floor_def(&"floor_1").size, Vector2i(6, 12), "Tier 2 ground 6 x 12")
	eq(t2.floor_def(&"floor_2").size, Vector2i(6, 8), "Tier 2 kitchen 6 x 8")
	var t3: LocationDefinition = DataRegistry.location_by_tier(3)
	for f: FloorDefinition in t3.floors:
		eq(f.size, Vector2i(6, 12), "Tier 3 %s 6 x 12" % f.id)
	check(t3.floor_def(&"floor_1").has_zone(&"store") and t3.floor_def(&"floor_2").has_zone(&"kitchen"), "Tier 3 store below, kitchen above")
	var t4: FloorDefinition = DataRegistry.location_by_tier(4).floors[0]
	eq(t4.size, Vector2i(16, 16), "Tier 4 16 x 16")
	eq(_cells_in_zone(t4, &"store"), 8 * 16, "Tier 4 store 8 x 16")
	eq(_cells_in_zone(t4, &"kitchen"), 8 * 16, "Tier 4 kitchen 8 x 16")
	var t5: FloorDefinition = DataRegistry.location_by_tier(5).floors[0]
	eq(t5.size, Vector2i(20, 20), "Tier 5 20 x 20")
	eq(_cells_in_zone(t5, &"store"), 12 * 20, "Tier 5 store 12 x 20")
	eq(_cells_in_zone(t5, &"kitchen"), 8 * 20, "Tier 5 kitchen 8 x 20")
	# Footprint 2x1 = 1,0 m x 0,5 m di semua tier.
	var cells: Array[Vector2i] = GridMath.footprint_cells(Vector2i(1, 1), Vector2i(2, 1), 0)
	eq(cells.size(), 2, "2x1 footprint covers 2 cells")
	near(2.0 * GridMath.WORLD_METERS_PER_TILE, 1.0, 0.000001, "2 tiles = 1.0 m")
	# Save menyimpan posisi grid, bukan transform dunia.
	var s: SimulationRoot = new_sim()
	var item: Dictionary = (s.equipment.capture()["items"] as Array)[0]
	for k: String in ["floor_id", "grid_x", "grid_y", "rotation_quarters"]:
		check(item.has(k), "equipment saved with %s" % k)
	check(not item.has("position") and not item.has("transform"), "no raw world transform in the save")
	# Blok 2x1: salah satu sel terhalang -> ditolak.
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var spare: EquipmentInstance = s.equipment.create_instance(&"display_t1")
	var fp: Vector2i = spare.def().footprint_tiles
	var blocked: Vector2i = disp.anchor
	var reason: StringName = s.world.validate_placement(spare, disp.floor_id, blocked - Vector2i(fp.x - 1, 0), 0)
	check(reason != &"", "placement overlapping one blocked cell refused (%s)" % reason)
	free_sim(s)


## Solver penempatan: setiap tier menampung jumlah slot penuh tiap kategori
## lewat Buka Stasiun (penempatan otomatis deterministik), dan layout tetap sah.
func _layout_solver() -> void:
	for tier in range(1, 6):
		var s: SimulationRoot = new_sim(600 + tier)
		if tier > 1:
			jump_to_tier(s, tier)
		s.debug_add_kr(1.0e15)
		for cat: StringName in [&"oven", &"mixer", &"display"]:
			var limit: int = s.world.location.slot_count(cat)
			var guard: int = 0
			while s.equipment.placed_count(cat) < limit and guard < 10:
				guard += 1
				check(s.upgrades.open_station(cat) >= 0, "T%d opens %s #%d" % [tier, cat, s.equipment.placed_count(cat) + 1])
			eq(s.equipment.placed_count(cat), limit, "T%d %s slots filled (%d)" % [tier, cat, limit])
			eq(s.upgrades.open_station_cost(cat), -1.0, "T%d no more %s to open" % [tier, cat])
		check(s.world.layout_valid(), "T%d layout valid with every slot filled" % tier)
		var table: EquipmentInstance = s.equipment.table_instance()
		check(table != null and table.placed, "T%d holding table placed alongside full slots (v3.1 5.1.3)" % tier)
		for e2: EquipmentInstance in s.equipment.placed_list():
			check(not s.world.access_of(e2.iid).is_empty(), "T%d %s#%d has an access tile" % [tier, e2.def_id, e2.iid])
		eq(s.check_invariants(), "", "T%d invariants" % tier)
		free_sim(s)


func _placement() -> void:
	var s: SimulationRoot = new_sim(71)
	var fg: FloorGrid = s.world.grid(&"floor_1")
	var spare: EquipmentInstance = s.equipment.create_instance(&"display_t1")
	# Sel jalur terlindungi: tidak boleh dibangun.
	var prot: Vector2i = fg.def.protected_cells[0]
	var bad: int = 0
	for rot in 4:
		if s.world.validate_placement(spare, &"floor_1", prot, rot) == &"":
			bad += 1
	eq(bad, 0, "protected path cell never accepts furniture (GDD 81.1)")
	# Semua posisi sah: tile akses kosong di depan sisi interaksi, setelah rotasi.
	var valid: int = 0
	for z in fg.size.y:
		for x in fg.size.x:
			for rot2 in 4:
				var a := Vector2i(x, z)
				if s.world.validate_placement(spare, &"floor_1", a, rot2) != &"":
					continue
				valid += 1
				var front: Array[Vector2i] = GridMath.front_cells(a, spare.def().footprint_tiles, rot2, spare.def().interaction_face)
				var ok: bool = false
				for c: Vector2i in front:
					if fg.is_walkable(c):
						ok = true
				check(ok, "valid placement at %s rot %d keeps a free front tile (GDD 81.4)" % [a, rot2])
	check(valid > 0, "some valid display positions exist")
	free_sim(s)


func _one_speed() -> void:
	var s: SimulationRoot = new_sim(81)
	check(not s.time.has_method("set_speed") and not ("speed" in s.time), "the clock has no speed setting")
	var c0: float = s.time.time_seconds
	for i0 in 30:
		s.advance(1.0 / 30.0)
	near(s.time.time_seconds - c0, 60.0, s.time.ratio * s.tick_seconds + 0.001, "1 real second = 1 in-game minute")
	PauseManager.push(PauseManager.USER)
	var t1: float = s.time.sim_seconds
	for i2 in 30:
		s.advance(1.0 / 30.0)
	near(s.time.sim_seconds, t1, 0.000001, "the Pause menu freezes the clock")
	PauseManager.clear_all()
	var t2: float = s.time.sim_seconds
	for i3 in 30:
		s.advance(1.0 / 30.0)
	check(s.time.sim_seconds > t2, "the clock runs again after Resume")
	free_sim(s)


func _in_use() -> void:
	var s: SimulationRoot = new_sim(101)
	freeze_production(s)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
	s.production.start_mixing(j.job_id, &"test")
	check(s.equipment.is_in_use(mixer.iid), "mixing mixer is IN_USE")
	check(s.equipment.move_blocked(mixer.iid), "a mixing mixer may not move")
	var fg: FloorGrid = s.world.grid(mixer.floor_id)
	var moved: int = 0
	for z in fg.size.y:
		for x in fg.size.x:
			if s.equipment.place(mixer.iid, mixer.floor_id, Vector2i(x, z), mixer.rotation) == &"":
				moved += 1
	eq(moved, 0, "in-use furniture cannot move anywhere (v3.1 81.14)")
	free_sim(s)


## Rak berisi roti boleh dipindah dan diputar kapan saja (toko idle selalu
## buka), dan rotinya ikut pindah (GDD idle 4.6, v3.1 72).
func _stocked_shelf() -> void:
	var s: SimulationRoot = new_sim(102)
	freeze_production(s)
	park_owner(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	stock(s, &"recipe_plain_loaf", 6, 0, disp.iid)
	check(s.display.used(disp.iid) > 0, "the shelf holds bread")
	var bread: String = JSON.stringify(s.display.capture())
	check(s.equipment.is_in_use(disp.iid), "a shelf holding bread still counts as in use")
	check(not s.equipment.move_blocked(disp.iid), "but it may move")
	var spot: Dictionary = _shelf_spot(s, disp, false)
	check(not spot.is_empty(), "the shelf has another free spot")
	if spot.is_empty():
		free_sim(s)
		return
	eq(s.equipment.place(disp.iid, disp.floor_id, spot["anchor"], spot["rot"]), &"", "Place moves the shelf holding bread")
	eq(disp.anchor, spot["anchor"], "the shelf stands at its new spot")
	eq(JSON.stringify(s.display.capture()), bread, "its bread moved with it: same slots and units")
	check(not s.world.access_of(disp.iid).is_empty() and s.world.layout_valid(), "the new layout keeps its access tile and paths")
	var turn: Dictionary = _shelf_spot(s, disp, true)
	check(not turn.is_empty(), "the shelf has a free spot facing another way")
	if not turn.is_empty():
		eq(s.equipment.place(disp.iid, disp.floor_id, turn["anchor"], turn["rot"]), &"", "it may turn too")
		eq(disp.rotation, int(turn["rot"]), "the shelf faces its new way")
		eq(JSON.stringify(s.display.capture()), bread, "with its bread untouched")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


## Tempat sah lain untuk rak `e` di lantainya: {anchor, rot}; `turn` meminta
## putaran yang berbeda, selain itu jangkar yang berbeda dengan putaran sama.
func _shelf_spot(s: SimulationRoot, e: EquipmentInstance, turn: bool) -> Dictionary:
	var fg: FloorGrid = s.world.grid(e.floor_id)
	for r in 4:
		var rot: int = (e.rotation + r) % 4
		if (rot != e.rotation) != turn:
			continue
		for z in fg.size.y:
			for x in fg.size.x:
				var a := Vector2i(x, z)
				if (a != e.anchor or turn) and s.world.validate_placement(e, e.floor_id, a, rot) == &"":
					return {"anchor": a, "rot": rot}
	return {}


func _effect_limit() -> void:
	var root := Node3D.new()
	runner.add_child(root)
	var cap: int = DataRegistry.bali("limits.pooled_particles")
	eq(cap, 256, "cap from GDD 129")
	var base: int = FX.live_effects()
	var made: int = 0
	for i in cap + 20:
		if FX.steam(root, Vector3.ZERO) != null:
			made += 1
	eq(base + made, cap, "effects created up to the cap only")
	check(FX.at_capacity(), "at capacity")
	check(FX.steam(root, Vector3.ZERO) == null, "further cosmetic effects are dropped, not queued")
	root.free()
	eq(FX.live_effects(), base, "freeing effects releases their slots")
	# Batas lain dibaca dari katalog yang sama.
	for k: String in ["world_alerts_visible", "pooled_customer_bodies", "music_voices", "sfx_voices", "toasts_visible", "decorations_per_floor"]:
		check(DataRegistry.bali("limits." + k) > 0, "limit %s defined" % k)


## Dunia bisa dibongkar (kembali ke menu) saat partikel sekali-jalan masih hidup.
## Timer auto-free yang tertinggal tidak boleh memicu error ketika berbunyi;
## runner menggagalkan tes ini bila ada error engine.
func _effect_teardown() -> void:
	var root := Node3D.new()
	runner.add_child(root)
	var base: int = FX.live_effects()
	check(FX.sugar_sparkle(root, Vector3.ZERO) != null, "one-shot sparkle created")
	root.free()
	eq(FX.live_effects(), base, "freeing the world releases the effect slot")
	await runner.get_tree().create_timer(FX.SPARKLE_LIFETIME * 1.4 + FX.AUTO_FREE_MARGIN + 0.3).timeout
	eq(FX.live_effects(), base, "the late auto-free timer changes nothing")


## Tanda ubin Decoration Mode jujur (GDD 17.3-17.4, 56.1): ubin yang diarsir
## selalu ditolak karena jalan, ubin kosong yang tidak diarsir selalu sah untuk
## perabot 1x1, dan analisis leher botol setara dengan uji konektivitas penuh.
func _keep_clear() -> void:
	var s: SimulationRoot = new_sim(1703)
	for tier in range(1, 6):
		if tier > 1:
			jump_to_tier(s, tier)
		for fid: StringName in s.world.floor_ids():
			var fg: FloorGrid = s.world.grid(fid)
			var t0: int = Time.get_ticks_usec()
			var kc: Dictionary = s.world.keep_clear_cells(fid)
			var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
			check(ms < 100.0, "T%d %s keep-clear analysis is fast (%.1f ms)" % [tier, fid, ms])
			for c: Vector2i in fg.def.protected_cells:
				if fg.def.zone_at(c) != &"":
					check(kc.has(c), "T%d %s protected cell %s marked" % [tier, fid, c])
			for lane: Dictionary in fg.def.lanes:
				for q: Vector2i in lane["queue"]:
					eq(kc.get(q), &"queue", "T%d %s queue slot %s marked" % [tier, fid, q])
				eq(kc.get(lane["service_point"]), &"service", "T%d %s service point marked" % [tier, fid])
				eq(kc.get(lane["cashier_point"]), &"service", "T%d %s cashier point marked" % [tier, fid])
			# Ubin akses di jalur terlindung tetap berlabel walkway (GDD 56.1.2).
			for acc: Variant in fg.access_at.keys():
				check(kc.get(acc, &"") in [&"access", &"walkway"], "T%d %s access tile %s marked (%s)" % [tier, fid, acc, kc.get(acc, &"")])
			var mismatches: Array[String] = []
			for z in fg.size.y:
				for x in fg.size.x:
					var c2 := Vector2i(x, z)
					if fg.def.zone_at(c2) == &"" or fg.flag(c2) != FloorGrid.Flag.WALKABLE_BUILDABLE:
						continue
					if fg.furniture_at.has(c2) or fg.decor_at.has(c2) or fg.access_at.has(c2):
						continue
					# Brute force: tutup ubin ini lalu uji konektivitas penuh.
					fg.decor_at[c2] = -1
					var breaks: bool = not s.world._connectivity_ok()
					fg.decor_at.erase(c2)
					if breaks != (kc.get(c2, &"") == &"chokepoint"):
						mismatches.append(str(c2))
					if fg.is_store(c2):
						var r: StringName = s.world.validate_decor_cell(fid, c2, -99)
						if kc.has(c2):
							check(WorldManager.WALKWAY_REASONS.has(r), "T%d %s marked store cell %s rejected for the walkway (%s)" % [tier, fid, c2, r])
						else:
							eq(r, &"", "T%d %s unmarked free store cell %s accepts a 1x1 item" % [tier, fid, c2])
			eq(mismatches, [], "T%d %s chokepoints match a full connectivity test" % [tier, fid])
	# Perabot yang sedang dipindah tidak menandai ubin aksesnya sendiri.
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var own_acc: Vector2i = s.world.access_of(disp.iid)["cell"]
	if s.world.grid(disp.floor_id).flag(own_acc) == FloorGrid.Flag.WALKABLE_BUILDABLE:
		eq(s.world.keep_clear_cells(disp.floor_id).get(own_acc), &"access", "access tile marked while the display stays")
		check(s.world.keep_clear_cells(disp.floor_id, disp.iid).get(own_acc, &"") != &"access", "moving display frees its own access tile")
	eq(s.check_invariants(), "", "analysis leaves the layout untouched")
	check(s.world.layout_valid(), "layout still valid")
	free_sim(s)
