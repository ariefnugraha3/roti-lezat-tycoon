extends TestSuite
## Sistem level (GDD idle 8): rumus biaya, ×1/×10/Max, batas level, milestone,
## dan evolusi model.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_COSTS", "name": "idle 8.1-8.9 cost formulas, x1/x10/Max (also at the level cap), extra-instance, open-station, unlock, hire, location and global costs", "fn": _costs},
		{"id": "ACC_IDLE_MILESTONES", "name": "idle 8.2, 8.5 milestone multipliers and model evolution (more shelf slots, bread kept, nearest legal spot when the new footprint does not fit, waits when there is none)", "fn": _milestones},
	]


func _quiet(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	freeze_production(s)
	park_owner(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	return s


func _costs() -> void:
	# Rumus umum dan bentuk tertutup deret (8.1).
	var base: float = 40.0
	var g: float = 1.15
	for steps: int in [0, 4, 11]:
		var brute: float = 0.0
		for i in 7:
			brute += base * pow(g, float(steps + i))
		near(UpgradeManager.series_cost(base, g, steps, 7), brute, brute * 1e-9, "7 levels from step %d = the sum of single costs" % steps)
	near(UpgradeManager.series_cost(base, g, 3, 1), base * pow(g, 3.0), 1e-9, "one level from Lv 4 costs base x growth^(L-1)")
	var exact: float = UpgradeManager.series_cost(base, g, 2, 9)
	eq(UpgradeManager.max_affordable(base, g, 2, exact, 1000), 9, "KR for exactly 9 levels buys 9")
	eq(UpgradeManager.max_affordable(base, g, 2, exact - 1.0, 1000), 8, "a little less buys 8")
	eq(UpgradeManager.max_affordable(base, g, 2, exact, 5), 5, "Max stops at the level cap")
	eq(UpgradeManager.max_affordable(base, g, 2, 0.0, 10), 0, "nothing with no KR")
	eq(UpgradeManager.buy_count(&"x10", base, g, 0, 1.0e9, 9), 0, "x10 is off when only 9 levels are left under the cap")
	eq(UpgradeManager.buy_count(&"max", base, g, 0, 1.0e9, 9), 9, "Max buys the last 9")
	eq(UpgradeManager.buy_count(&"x10", base, g, 0, UpgradeManager.series_cost(base, g, 0, 10) - 0.5, 100), 0, "x10 is off unless all 10 are affordable")
	eq(UpgradeManager.buy_count(&"x1", base, g, 0, base, 1), 1, "x1 with exactly the cost")
	# Stasiun sungguhan: biaya, ledger, dan batas level lokasi (8.2, 8.3).
	var s: SimulationRoot = _quiet(7001)
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	var o: Dictionary = s.upgrades.offer(&"station", oven.iid)
	near(float(o["base"]), DataRegistry.idlef("station.oven.cost_base"), 1e-9, "the first oven costs station.oven.cost_base")
	eq(int(o["cap"]), 25, "Tier 1 caps station levels at 25")
	s.debug_add_kr(1.0e9)
	var bal: float = s.economy.balance
	eq(s.upgrades.buy(&"station", oven.iid, &"x10"), 10, "x10 buys ten levels")
	eq(s.upgrades.station_level(oven.iid), 11, "the oven is Lv 11")
	near(bal - s.economy.balance, Money.round_half_up(UpgradeManager.series_cost(float(o["base"]), float(o["growth"]), 0, 10)), 1.0, "for the series cost")
	eq(str(s.economy.ledger[s.economy.ledger.size() - 1]["category"]), "UPGRADE_STATION", "booked as UPGRADE_STATION")
	eq(s.upgrades.buy(&"station", oven.iid, &"max"), 14, "Max stops at the Tier 1 cap (Lv 25)")
	eq(s.upgrades.station_level(oven.iid), 25, "Lv 25")
	eq(s.upgrades.buy(&"station", oven.iid, &"x1"), 0, "nothing more at the cap")
	# Kasir: satu level untuk semua jalur.
	var c: Dictionary = s.upgrades.offer(&"counter", &"counter")
	near(float(c["base"]), DataRegistry.idlef("station.counter.cost_base"), 1e-9, "the counter costs station.counter.cost_base")
	# Instance tambahan ×3, buka stasiun ke-n (8.4).
	jump_to_tier(s, 2)
	s.debug_add_kr(1.0e9)
	var open_cost: float = s.upgrades.open_station_cost(&"oven")
	near(open_cost, DataRegistry.idlef("station.open_cost.oven"), 1e-9, "the second oven opens for station.open_cost.oven")
	var second: int = s.upgrades.open_station(&"oven")
	check(second >= 0, "it opens")
	eq(s.upgrades.station_level(second), 1, "at Lv 1")
	near(float(s.upgrades.offer(&"station", second)["base"]), DataRegistry.idlef("station.oven.cost_base") * DataRegistry.idlef("station.extra_instance_cost_mult"), 1e-6,
		"its levels cost x station.extra_instance_cost_mult")
	eq(s.upgrades.open_station_cost(&"oven"), -1.0, "Tier 2 has no third oven slot")
	var mixer_open: float = s.upgrades.open_station_cost(&"mixer")
	near(mixer_open, DataRegistry.idlef("station.open_cost.mixer"), 1e-9, "the first extra mixer costs open_cost")
	# Resep: buka dan level tanpa batas lokasi (8.5).
	var donut: RecipeDefinition = DataRegistry.recipe(&"recipe_sugar_donut")
	near(UpgradeManager.unlock_cost(donut), donut.base_sell_price_kr * DataRegistry.idlef("recipe.unlock_mult"), 1e-9, "unlock = price x recipe.unlock_mult")
	eq(UpgradeManager.unlock_cost(DataRegistry.recipe(&"recipe_plain_loaf")), 0.0, "Plain Loaf is free")
	check(s.upgrades.unlock_recipe(donut.id), "unlock Sugar Donut")
	var ro: Dictionary = s.upgrades.offer(&"recipe", donut.id)
	near(float(ro["base"]), donut.base_sell_price_kr * DataRegistry.idlef("recipe.level_cost_mult"), 1e-9, "recipe levels cost price x level_cost_mult")
	near(float(ro["growth"]), DataRegistry.idlef("recipe.level_cost_growth"), 1e-9, "growing by level_cost_growth")
	eq(int(ro["cap"]), UpgradeManager.NO_CAP, "recipe levels have no location cap")
	# Staf: rekrut dari daftar, level dibatasi lokasi (5.5, 8.6).
	var costs: Array = DataRegistry.idle("staff.hire_cost")
	near(s.staff.next_hire_cost(), float(costs[0]), 1e-9, "the first hire costs hire_cost[0]")
	s.staff.hire(&"staff_baker_joko")
	var so: Dictionary = s.upgrades.offer(&"staff", &"staff_baker_joko")
	near(float(so["base"]), DataRegistry.idlef("staff.level_cost_base"), 1e-9, "staff levels cost staff.level_cost_base")
	eq(int(so["cap"]), s.upgrades.level_cap(), "staff levels share the location cap")
	# Lokasi dan global (8.7, 8.9).
	var loc: Array = DataRegistry.idle("location.upgrade_cost")
	for t in range(2, 6):
		near(SimulationRoot.location_cost(t), float(loc[t - 1]), 1e-6, "moving to Tier %d costs %s" % [t, Tx.big(float(loc[t - 1]))])
	for gv: Variant in DataRegistry.idle("global_upgrades"):
		var gd: Dictionary = gv
		var go: Dictionary = s.upgrades.offer(&"global", StringName(str(gd["id"])))
		near(UpgradeManager.offer_cost(go, 1), float(gd["cost_base"]), 1e-9, "%s starts at cost_base" % gd["id"])
		eq(int(go["cap"]), int(gd["max_level"]), "%s stops at max_level" % gd["id"])
	free_sim(s)


func _milestones() -> void:
	# Kecepatan mixer/oven ×2 di setiap milestone (8.2).
	var per: float = DataRegistry.idlef("station.oven.speed_per_level")
	near(UpgradeManager.speed_for(&"oven", 9), 1.0 + per * 8.0, 1e-9, "Lv 9 oven speed")
	near(UpgradeManager.speed_for(&"oven", 10), (1.0 + per * 9.0) * 2.0, 1e-9, "Lv 10 doubles it")
	near(UpgradeManager.speed_for(&"oven", 25), (1.0 + per * 24.0) * 4.0, 1e-9, "Lv 25 doubles it again")
	near(UpgradeManager.speed_for(&"mixer", 150), (1.0 + per * 149.0) * 64.0, 1e-6, "all six milestones by Lv 150")
	# Harga resep ×2 di milestone resep (8.5).
	var rp: float = DataRegistry.idlef("recipe.price_per_level")
	near(UpgradeManager.recipe_price_mult_for(24, 2.0), 1.0 + rp * 23.0, 1e-9, "Lv 24 recipe")
	near(UpgradeManager.recipe_price_mult_for(25, 2.0), (1.0 + rp * 24.0) * 2.0, 1e-9, "Lv 25 doubles the price")
	# Rak dan kasir.
	eq(UpgradeManager.slot_capacity_for(1), DataRegistry.equipment_for(&"display", 1).max_per_slot, "a Lv 1 shelf holds max_per_slot")
	eq(UpgradeManager.slot_capacity_for(26), int(floor(float(DataRegistry.equipment_for(&"display", 1).max_per_slot) * 2.0 + 1e-6)), "+4% per level")
	near(UpgradeManager.checkout_seconds_for(1), 3.0, 1e-9, "checkout 3 s at Lv 1")
	near(UpgradeManager.checkout_seconds_for(11), 3.0 * pow(0.97, 10.0), 1e-9, "x0.97 per level")
	near(UpgradeManager.checkout_seconds_for(150), 1.0, 1e-9, "never under 1 s")
	# Tier model dari level.
	eq([UpgradeManager.model_tier_for_level(9), UpgradeManager.model_tier_for_level(10), UpgradeManager.model_tier_for_level(25),
		UpgradeManager.model_tier_for_level(50), UpgradeManager.model_tier_for_level(75)], [1, 2, 3, 4, 5], "model tier = 1 + thresholds passed")
	# Evolusi rak di toko: petak bertambah, roti tetap, tempat tetap sah.
	var s: SimulationRoot = _quiet(7002)
	s.debug_add_kr(1.0e9)
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	stock(s, &"recipe_plain_loaf", 6, 0, disp.iid)
	stock(s, &"recipe_plain_loaf", 3, 2, disp.iid)
	var bread: int = s.display.total_units()
	var events: Array = []
	var cb := func(kind: StringName, _id: Variant, level: int, milestone: bool) -> void: events.append([kind, level, milestone])
	EventBus.level_up.connect(cb)
	var evolved: Array = []
	var cb2 := func(iid: int, from_t: int, to_t: int) -> void: evolved.append([iid, from_t, to_t])
	EventBus.station_evolved.connect(cb2)
	eq(s.upgrades.buy(&"station", disp.iid, &"x1"), 1, "Lv 2")
	check(not bool(events[events.size() - 1][2]), "a plain level is not a milestone")
	s.upgrades.buy_offer(s.upgrades.offer(&"station", disp.iid), 8)
	eq(s.upgrades.station_level(disp.iid), 10, "Lv 10")
	check(bool(events[events.size() - 1][2]), "Lv 10 is a milestone")
	eq(disp.def_id, &"display_t2", "the shelf evolved into the Tier 2 model")
	eq(evolved.size(), 1, "station_evolved fired once")
	eq(s.display.slot_count(disp.iid), DataRegistry.equipment(&"display_t2").slot_count, "with the Tier 2 slot count")
	eq(s.display.total_units(), bread, "every bread is still there")
	eq(s.display.slot_units(disp.iid, 0), 6, "in its own slot")
	check(s.world.layout_valid() and not s.world.access_of(disp.iid).is_empty(), "the layout stays valid and reachable")
	# Tier 3 berjejak 2 × 2. Bila tidak ada tempat sama sekali, model menunggu
	# sementara efek levelnya tetap berlaku (8.2): semua ubin lain diblokir dulu.
	var fg: FloorGrid = s.world.grid(disp.floor_id)
	var saved: PackedInt32Array = fg.base_flags.duplicate()
	var own: Array[Vector2i] = disp.footprint_cells()
	for z in fg.size.y:
		for x in fg.size.x:
			var c: Vector2i = Vector2i(x, z)
			if not own.has(c) and fg.flag(c) == FloorGrid.Flag.WALKABLE_BUILDABLE:
				fg._set_flag(c, FloorGrid.Flag.WALKABLE_NO_BUILD)
	var t3: EquipmentDefinition = DataRegistry.equipment(&"display_t3")
	check(s.equipment.replacement_spot(disp, t3).is_empty(), "with every other tile blocked a 2 x 2 shelf has no spot")
	s.upgrades.buy_offer(s.upgrades.offer(&"station", disp.iid), 15)
	eq(s.upgrades.station_level(disp.iid), 25, "Lv 25")
	eq(disp.def_id, &"display_t2", "the model waits for room")
	eq(s.upgrades.slot_capacity(disp.iid), UpgradeManager.slot_capacity_for(25), "but the level's capacity already counts")
	eq(s.display.total_units(), bread, "and no bread moved")
	# Ada tempat lagi: evolusi yang menunggu menyusul ke tempat sah terdekat.
	fg.base_flags = saved
	var spot: Dictionary = s.equipment.replacement_spot(disp, t3)
	check(not spot.is_empty(), "with the tiles free again there is a spot")
	s.upgrades.retry_evolutions()
	eq(disp.def_id, &"display_t3", "the shelf grows into the Tier 3 model")
	eq(disp.anchor, Vector2i(spot["anchor"]), "at the nearest legal spot")
	eq(s.display.total_units(), bread, "with its bread")
	check(s.world.layout_valid() and not s.world.access_of(disp.iid).is_empty(), "the layout stays valid")
	eq(s.check_invariants(), "", "invariants")
	# Batas lokasi menentukan tier model tertinggi (8.3).
	eq(UpgradeManager.model_tier_for_level(25), 3, "Tier 1 (cap 25) tops out at Tier 3 models")
	EventBus.level_up.disconnect(cb)
	EventBus.station_evolved.disconnect(cb2)
	free_sim(s)
