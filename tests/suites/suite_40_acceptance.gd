extends TestSuite
## Acceptance tambahan: GDD 55, Appendix skala ruang, dan GDD 81 yang belum
## tercakup suite wajib, termasuk solver penempatan otomatis semua tier.


func tests() -> Array:
	return [
		{"id": "ACC_55_STARTING_CASH", "name": "55.1 opening balance 1000 KR in the ledger", "fn": _starting_cash},
		{"id": "ACC_55_OJOL_QUEUE", "name": "55.3 dedicated RotiFood queue at Tier 3+", "fn": _ojol_queue},
		{"id": "ACC_55_PATIENCE", "name": "55.4/58 patience bar and drain", "fn": _patience},
		{"id": "ACC_55_COURIERS", "name": "55.5-55.7 courier ETA, lifecycle and FIFO", "fn": _couriers},
		{"id": "ACC_55_CAPACITY", "name": "55.9 capacity includes in-transit", "fn": _capacity},
		{"id": "ACC_SPATIAL", "name": "Appendix spatial scale 1-10", "fn": _spatial},
		{"id": "ACC_LAYOUT_SOLVER", "name": "auto-placement fills every tier's slots", "fn": _layout_solver},
		{"id": "ACC_81_PLACEMENT", "name": "81.1/81.4 placement keeps paths and access tiles", "fn": _placement},
		{"id": "ACC_81_SPEED", "name": "81.7/81.8 speed, menu pause, smart speed safety", "fn": _speed},
		{"id": "ACC_81_RECIPES", "name": "81.9/81.10 no unlock flags, batch revenue", "fn": _recipes},
		{"id": "ACC_81_IN_USE", "name": "81.14 in-use furniture cannot move", "fn": _in_use},
		{"id": "ACC_16_COMMANDS", "name": "16.4 retargeting mixes equipment, cashier and portal taps", "fn": _mixed_taps},
		{"id": "ACC_DECOR_KEEP_CLEAR", "name": "17.4 decoration tile marks match placement validation", "fn": _keep_clear},
		{"id": "ACC_129_LIMITS", "name": "129 transient effects stop at the cap", "fn": _effect_limit},
		{"id": "ACC_129_FX_TEARDOWN", "name": "129 one-shot effects freed early leave no errors behind", "fn": _effect_teardown},
		{"id": "ACC_62_BURNT_SWAP", "name": "62 dough in hand replaces a burnt tray, never a sellable one", "fn": _burnt_swap},
	]


func _starting_cash() -> void:
	var s: SimulationRoot = new_sim()
	near(s.economy.balance, 1000.0, 0.001, "balance 1000 KR")
	eq(s.economy.ledger.size(), 1, "one opening ledger entry")
	near(float(s.economy.ledger[0]["amount"]), 1000.0, 0.001, "opening entry 1000 KR")
	eq(Tx.kr(s.economy.balance).contains("1"), true, "HUD formatter renders the balance")
	free_sim(s)


func _ojol_queue() -> void:
	var s: SimulationRoot = new_sim(33)
	jump_to_tier(s, 3)
	var rf: QueueLane = s.queue.rotifood_lane
	check(rf != null, "Tier 3 has a dedicated RotiFood lane")
	eq(rf.capacity(), 3, "RotiFood queue has 3 slots (GDD 57.3)")
	eq(s.queue.driver_lane(), rf, "drivers use the dedicated lane")
	var phys_before: int = s.queue.physical_free_capacity()
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	for i in rf.capacity():
		s.queue.reserve(rf, StringName("d_block%d" % i))
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 1)
	o.driver_arrival_time = s.time.sim_seconds
	s.run_for(1.0)
	eq(o.driver_phase, &"pending", "driver waits outside while the RotiFood queue is full")
	eq(s.queue.physical_free_capacity(), phys_before, "physical lanes untouched by the driver")
	free_sim(s)


func _patience() -> void:
	var c := Customer.new()
	c.patience_max = 30.0
	c.patience = 15.0
	near(c.patience_ratio(), 0.5, 0.0001, "bar ratio 0.5 (GDD 55.4)")
	for st: StringName in [Customer.ENTERING, Customer.BROWSING, Customer.SELECTING, Customer.CARRYING_TO_QUEUE]:
		c.state = st
		check(not c.drains_patience(), "%s does not drain patience" % st)
	var table: Dictionary = {&"customer_school_child": 55.0, &"customer_office_worker": 18.0, &"customer_bulk_buyer": 45.0,
		&"customer_snob": 28.0, &"customer_indecisive": 60.0, &"customer_critic": 25.0, &"customer_generic": 35.0}
	for id: StringName in table.keys():
		near(DataRegistry.archetype(id).base_patience_seconds, float(table[id]), 0.001, "%s patience (GDD 58)" % id)
	near(float(DataRegistry.driver_def()["base_patience_seconds"]), 30.0, 0.001, "driver patience 30 s")
	# Office Worker sendirian di antrean yang tidak dilayani: 1,0/s selama 10 s,
	# lalu ×1,15 karena tanpa progres (GDD 58).
	var s: SimulationRoot = new_sim(44)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	stock(s, &"recipe_plain_loaf", 6)
	s.customers.try_admit({"archetype": &"customer_office_worker", "scripted": false, "recipe": &"", "quantity": 1, "patience_override": null})
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
	near(took, 10.0 + 8.0 / 1.15, 0.15, "office worker gives up after 10 s + 8 s at ×1.15")
	eq(s.display.total_units(), 6, "abandoning customer returned the bread")
	free_sim(s)


func _couriers() -> void:
	var s: SimulationRoot = new_sim(55)
	s.supply.unlock_market()
	run_until(s, 10.0 * 3600.0)
	var flour: int = s.inventory.count(&"ingredient_flour")
	var bal: float = s.economy.balance
	s.supply.purchase({&"ingredient_flour": 3})
	near(s.economy.balance, bal - 450.0, 0.001, "KR deducted at once (GDD 55.5)")
	eq(s.inventory.count(&"ingredient_flour"), flour, "on_hand unchanged")
	near(s.supply.next_eta_of(&"ingredient_flour"), 13.0 * 3600.0, 0.5, "ETA 13:00")
	# Dua order lagi, jatuh tempo bersamaan (GDD 55.7).
	s.supply.purchase({&"ingredient_sugar": 1})
	s.supply.purchase({&"ingredient_egg": 1})
	var seen_states: Array[String] = []
	var max_couriers: int = 0
	var commit_state: String = ""
	var committed: Array[int] = []
	while s.time.time_seconds < 14.0 * 3600.0:
		s.step(s.tick_seconds)
		# Hanya kurir yang masuk/menaruh paket memakai staging point.
		var using: int = 0
		for o3: Dictionary in s.supply.orders:
			if str(o3["state"]) in ["COURIER_ENTERING", "DROPPING_PACKAGE"]:
				using += 1
		max_couriers = maxi(max_couriers, using)
		for o: Dictionary in s.supply.orders:
			var st: String = str(o["state"])
			if not seen_states.has(st):
				seen_states.append(st)
			if bool(o["inventory_committed"]) and not committed.has(int(o["order_id"])):
				committed.append(int(o["order_id"]))
		if commit_state == "" and s.inventory.count(&"ingredient_flour") > flour:
			for o2: Dictionary in s.supply.orders:
				if (o2["items"] as Dictionary).has("ingredient_flour"):
					commit_state = str(o2["state"])
	eq(s.inventory.count(&"ingredient_flour"), flour + 3, "3 flour added exactly once")
	eq(committed.size(), 3, "every order committed")
	eq(max_couriers, 1, "only one courier uses the staging point at a time (GDD 55.7)")
	for st2: String in ["COURIER_SPAWNING", "COURIER_ENTERING", "DROPPING_PACKAGE"]:
		check(seen_states.has(st2), "courier lifecycle passes %s (GDD 55.6)" % st2)
	check(commit_state in ["INVENTORY_COMMITTED", "COURIER_EXITING", "COMPLETED"], "commit happens at drop-off, not on spawn (%s)" % commit_state)
	eq(s.supply.couriers.size(), 0, "couriers despawned")
	free_sim(s)


func _capacity() -> void:
	var s: SimulationRoot = new_sim(66)
	s.supply.unlock_market()
	s.debug_add_kr(100000.0)
	run_until(s, 9.0 * 3600.0)
	var free: int = s.inventory.capacity() - s.inventory.total_units()
	# Sisakan 10 unit, 8 di antaranya in-transit.
	var fill: int = free - 10
	if fill > 0:
		s.inventory.add_items({&"ingredient_water_salt": fill})
	check(s.supply.purchase({&"ingredient_flour": 8})["ok"], "8 units in transit")
	eq(s.supply.max_additional_units(), 2, "only 2 more units allowed (GDD 55.9)")
	check(not s.supply.purchase({&"ingredient_flour": 3})["ok"], "3 units refused")
	check(s.supply.purchase({&"ingredient_flour": 2})["ok"], "2 units accepted")
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
## lewat penempatan otomatis deterministik, dan layout tetap sah.
func _layout_solver() -> void:
	for tier in range(1, 6):
		var s: SimulationRoot = new_sim(600 + tier)
		if tier > 1:
			jump_to_tier(s, tier)
		s.time.set_phase(TimeManager.AFTER_HOURS)
		for cat: StringName in [&"oven", &"mixer", &"display"]:
			var limit: int = s.world.location.slot_count(cat)
			var guard: int = 0
			while s.equipment.placed_count(cat) < limit and guard < 10:
				guard += 1
				var e: EquipmentInstance = s.equipment.create_instance(DataRegistry.equipment_for(cat, 1).id)
				check(s.world.auto_place(e), "T%d auto-places %s #%d" % [tier, cat, s.equipment.placed_count(cat) + 1])
			eq(s.equipment.placed_count(cat), limit, "T%d %s slots filled (%d)" % [tier, cat, limit])
		check(s.world.layout_valid(), "T%d layout valid with every slot filled" % tier)
		var table: EquipmentInstance = s.equipment.table_instance()
		check(table != null and table.placed, "T%d holding table placed alongside full slots (GDD 5.1.3)" % tier)
		for e2: EquipmentInstance in s.equipment.placed_list():
			check(not s.world.access_of(e2.iid).is_empty(), "T%d %s#%d has an access tile" % [tier, e2.def_id, e2.iid])
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


func _speed() -> void:
	var s: SimulationRoot = new_sim(81)
	s.time.set_speed(3)
	var t0: float = s.time.sim_seconds
	for i in 30:
		s.advance(1.0 / 30.0)
	near(s.time.sim_seconds - t0, 3.0, 0.051, "3x speed: 1 real second = 3 simulation seconds")
	# Menu manajemen menghentikan timer sepenuhnya.
	PauseManager.push(&"modal_market")
	var t1: float = s.time.sim_seconds
	for i2 in 30:
		s.advance(1.0 / 30.0)
	near(s.time.sim_seconds, t1, 0.000001, "management menu freezes the timer")
	PauseManager.clear_all()
	# Smart Speed Safety: oven selesai pada 3x kembali ke 1x (GDD 71.1).
	SettingsManager.set_value("smart_speed", true)
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
	s.production.start_mixing(j.job_id, &"test", 1.0)
	s.run_for(j.stage_duration + 0.1)
	s.production.pickup_dough(j.job_id, &"test")
	s.production.insert_oven(j.job_id, s.equipment.placed_list(&"oven")[0].iid, &"test", 1.0)
	s.time.set_speed(3)
	s.run_for(j.stage_duration + 0.1)
	eq(j.stage, ProductionJob.BAKE_DONE_WAITING_PICKUP, "bake done")
	eq(s.time.speed, 1, "speed dropped to 1x before the burn window runs (GDD 81.8)")
	free_sim(s)


func _recipes() -> void:
	var raw: String = FileAccess.get_file_as_string("res://data/catalog/recipes.json")
	for w: String in ["unlock", "unlocked", "purchase_price"]:
		check(not raw.contains("\"%s" % w), "recipes.json has no %s field (GDD 61.1)" % w)
	var s: SimulationRoot = new_sim(91)
	var save_text: String = JSON.stringify(s.capture_save())
	check(not save_text.contains("unlocked_recipes") and not save_text.contains("recipe_unlock"), "no recipe unlock flags in the save")
	# Resep bisa dibuat semata dari bahan + alat minimum.
	for r: RecipeDefinition in DataRegistry.recipes():
		var reason: String = s.production.make_block_reason(r.id, 1)
		if s.production.owns_equipment_for(r) and s.inventory.has_for_recipe(r, 1):
			eq(reason, "", "%s makeable with ingredients + equipment" % r.id)
	# Pendapatan batch = harga default x yield (GDD 63.1, 81.10).
	for r2: RecipeDefinition in DataRegistry.recipes():
		near(Money.round_half_up(r2.base_sell_price_kr) * r2.batch_yield, r2.base_sell_price_kr * r2.batch_yield, 0.001, "%s batch revenue" % r2.id)
		check(r2.base_sell_price_kr * r2.batch_yield > r2.batch_cost_kr, "%s batch is profitable at default price" % r2.id)
	free_sim(s)


func _in_use() -> void:
	var s: SimulationRoot = new_sim(101)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
	s.production.start_mixing(j.job_id, &"test", 1.0)
	check(s.equipment.is_in_use(mixer.iid), "mixing mixer is IN_USE")
	eq(s.equipment.place(mixer.iid, mixer.floor_id, mixer.anchor + Vector2i(0, 1), mixer.rotation), &"in_use", "in-use furniture cannot move (GDD 81.14)")
	eq(s.equipment.put_away(mixer.iid), &"in_use", "in-use furniture cannot be stored")
	free_sim(s)


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


## Soft-lock oven gosong (GDD 16.5, 62): siapa pun yang membawa adonan boleh
## memakai oven berisi loyang gosong. Loyang itu dibuang sebagai waste, lalu
## adonan masuk. Loyang yang masih bisa dijual tetap menahan oven.
func _burnt_swap() -> void:
	var s: SimulationRoot = new_sim(6262)
	s.tutorial.skip()
	var p: PlayerTaskManager = s.player
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	# Loyang A dibiarkan sampai gosong.
	var a: ProductionJob = s.production.create_job(loaf.id, 1, &"test")
	s.production.start_mixing(a.job_id, &"test", 1.0)
	_step_until(s, func() -> bool: return a.stage == ProductionJob.MIX_DONE_WAITING_PICKUP)
	s.production.pickup_dough(a.job_id, &"test")
	s.production.insert_oven(a.job_id, oven.iid, &"test", 1.0)
	_step_until(s, func() -> bool: return a.stage == ProductionJob.BURNT)
	check(s.production.holds_burnt(oven), "oven holds the burnt tray")
	eq(s.production.free_oven_for(loaf), oven, "a burnt oven still takes dough")
	# Adonan B diambil pemain dari mixer, lalu dibawa ke oven gosong.
	var b: ProductionJob = s.production.create_job(loaf.id, 1, PlayerTaskManager.PLAYER_ID)
	s.production.start_mixing(b.job_id, PlayerTaskManager.PLAYER_ID, 1.0)
	_step_until(s, func() -> bool: return b.stage == ProductionJob.MIX_DONE_WAITING_PICKUP)
	check(p.tap_equipment(mixer.iid), "tap the finished mixer")
	_step_until(s, func() -> bool: return not p.actor.carried.is_empty())
	eq(p.carried_job(), b, "player carries the dough")
	var waste0: float = s.economy.waste_cost_today
	var burnt0: int = s.production.batches_burnt_today
	var bal0: float = s.economy.balance
	check(p.tap_equipment(oven.iid), "tap the burnt oven with dough in hand")
	_step_until(s, func() -> bool: return p.actor.carried.is_empty())
	check(s.production.get_job(a.job_id) == null, "burnt tray discarded")
	near(s.economy.waste_cost_today - waste0, a.ingredient_value_kr, 0.001, "discarded tray counted as waste")
	eq(s.production.batches_burnt_today, burnt0 + 1, "counted as a burnt batch")
	near(s.economy.balance, bal0, 0.001, "no KR from the burnt tray")
	eq(b.stage, ProductionJob.BAKING, "the new dough bakes")
	eq(oven.job_id, b.job_id, "oven holds the new dough")
	# Loyang yang sedang dipanggang atau siap jual tidak pernah ditukar.
	var c: ProductionJob = s.production.create_job(loaf.id, 1, &"test")
	s.production.start_mixing(c.job_id, &"test", 1.0)
	_step_until(s, func() -> bool: return c.stage == ProductionJob.MIX_DONE_WAITING_PICKUP)
	s.production.pickup_dough(c.job_id, &"test")
	check(s.production.free_oven_for(loaf) == null, "a baking oven is not offered for dough")
	check(not s.production.insert_oven(c.job_id, oven.iid, &"test", 1.0), "dough cannot replace a baking tray")
	_step_until(s, func() -> bool: return b.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP)
	check(not s.production.insert_oven(c.job_id, oven.iid, &"test", 1.0), "dough cannot replace a ready tray")
	eq(oven.job_id, b.job_id, "the ready tray stays in the oven")
	free_sim(s)


func _step_until(s: SimulationRoot, cond: Callable, max_ticks: int = 4000) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		s.step(s.tick_seconds)
	return cond.call()


func _mixed_taps() -> void:
	var s: SimulationRoot = new_sim(1604)
	s.tutorial.skip()
	run_until(s, 8.0 * 3600.0 + 10.0)
	var p: PlayerTaskManager = s.player
	var storage: EquipmentInstance = s.equipment.storage_instance()
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var lane: StringName = s.queue.main_lane().id
	# Karakter sedang berjalan ke satu perabot lalu pemain mengetuk target lain
	# (perabot/kasir) berulang kali: int dan String tidak pernah dibandingkan.
	check(p.tap_equipment(storage.iid), "tap storage")
	s.step(s.tick_seconds)
	check(p.tap_cashier(lane, false), "tap cashier while walking")
	check(p.tap_equipment(mixer.iid), "tap mixer after cashier")
	check(p.tap_cashier(lane, false), "tap cashier again")
	check(p.tap_cashier(lane, false), "double tap on the same target is ignored")
	check(p.tap_equipment(mixer.iid), "tap mixer again")
	check(p.commands.size() <= DataRegistry.bali("player.max_queued_commands"), "queue stays within its limit")
	# Setelah load, iid menjadi float; ketukan ganda tetap dikenali.
	var s2: SimulationRoot = load_sim(json_copy(s.capture_save()))
	var before: int = s2.player.commands.size()
	var last: Dictionary = s2.player.commands[before - 1] if before > 0 else {}
	if not last.is_empty() and StringName(str(last["kind"])) != &"cashier":
		s2.player.tap_equipment(int(last["target"]))
		eq(s2.player.commands.size(), before, "double tap after load is still ignored")
	s.run_for(5.0)
	eq(s.check_invariants(), "", "invariants")
	free_sim(s2)
	free_sim(s)


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
