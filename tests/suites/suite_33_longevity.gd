extends TestSuite
## Umur permainan panjang (GDD idle 23): cabang Waralaba yang makin mahal, perk
## lanjutan, dan mastery resep yang permanen.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_BRANCH_COSTS", "name": "idle 23.1, 20 no. 89 from branch_cost_start, moving to a bigger location costs x max(1, branch_cost_base x star multiplier ^ branch_cost_power), so it grows with the stars, not with the branch number; levels, opening stations, unlocking recipes, hiring, decorations, sale prices and promotions keep catalog prices; the Franchise sheet names the next branch's multiplier", "fn": _branch_costs},
		{"id": "ACC_IDLE_PERKS_LATE", "name": "idle 23.2 late perks: 750 stars +3 h offline, 1,000 a Tier 3 start, 1,500 coffee x2 longer, 2,500 recipe milestones x4, 5,000 golden bread twice as often", "fn": _late_perks},
		{"id": "ACC_IDLE_ENDLESS_SERIES", "name": "idle 23.4, 20 no. 90 endless milestone series (earn, bread, branches) go on forever: every target passed raises the series level with an achievement boost and a toast, several at once when a stat jumps, the Stats sheet lists them, and the levels survive a save", "fn": _endless_series},
		{"id": "ACC_IDLE_LEGACY", "name": "idle 23.2, 20 no. 90 past the last perk every legacy_every_stars stars multiply all income by 1 + legacy_income, the Franchise sheet names the level and the next one", "fn": _legacy},
		{"id": "ACC_IDLE_TOWN_BONUS", "name": "idle 23.5, 20 no. 91 every branch adds town.bonus_by_tier[its highest tier] to all income up to town.max_bonus, the current branch included; prices carry it; the Franchise sheet and the Crumbtown map show it and each story page names its share", "fn": _town_bonus},
		{"id": "ACC_IDLE_SIGNATURE", "name": "idle 23.6, 20 no. 92 every branch has a signature bread fixed by the save seed and branch number, never the same as the branch before; it sells for branch.signature_mult only in its own branch; the Menu marks it and the map story page names it", "fn": _signature},
		{"id": "ACC_IDLE_STREET_VARIANT", "name": "idle 23.6, 20 no. 92 branch 1 keeps the street colours; other branches turn the neighbours' wall, sign and awning colours with the same shapes and places, and the world builds the street for the branch being played", "fn": _street_variant},
		{"id": "ACC_IDLE_MASTERY", "name": "idle 23.3 recipe mastery: bread sold in the shop and through RotiFood counts per recipe, stars at the catalog thresholds raise that recipe's price for good (also in the KR/s model), a new star shows a toast, and mastery survives a franchise and a save", "fn": _mastery},
	]


func _branch_costs() -> void:
	var a: SimulationRoot = new_sim(2301)
	var b: SimulationRoot = new_sim(2301)
	a.tutorial.skip()
	b.tutorial.skip()
	var start: int = DataRegistry.idlei("prestige.branch_cost_start")
	var base: float = DataRegistry.idlef("prestige.branch_cost_base")
	var power: float = DataRegistry.idlef("prestige.branch_cost_power")
	b.prestige.run_index = start + 1
	b.prestige.branch_no = start + 1
	b.prestige.stars = 40
	var m: float = maxf(1.0, base * pow(PrestigeManager.star_mult_for(40), power))
	check(m > 1.0, "40 stars make a dearer branch")
	near(b.prestige.branch_cost_mult(), m, 1e-9, "branch #%d with 40 stars costs x base x star multiplier^power" % (start + 1))
	near(PrestigeManager.branch_cost_mult_for(start + 5, 40), m, 1e-9, "the branch number itself does not matter, only the stars")
	check(PrestigeManager.branch_cost_mult_for(start, 200) > m, "more stars, dearer moves")
	near(PrestigeManager.branch_cost_mult_for(start, 0), 1.0, 1e-9, "never cheaper than the catalog")
	near(PrestigeManager.branch_cost_mult_for(start - 1, 500), 1.0, 1e-9, "branches before #%d keep the catalog price" % start)
	near(a.prestige.branch_cost_mult(), 1.0, 1e-9, "branch #1 costs the catalog price")
	# Bintang yang sama: hanya nomor cabangnya yang berbeda.
	a.prestige.stars = 40
	a.idle_economy.invalidate()
	b.idle_economy.invalidate()
	near(a.prestige.branch_cost_mult(), 1.0, 1e-9, "branch #1 keeps the catalog price even with 40 stars")
	var e: EquipmentInstance = a.equipment.placed_list(&"oven")[0]
	var e2: EquipmentInstance = b.equipment.placed_list(&"oven")[0]
	# Hanya pindah lokasi yang naik; yang lain harga katalog (tanpa tebing penghasilan).
	near(b.location_price(2), SimulationRoot.location_cost(2) * m, 1e-6, "moving to Tier 2 costs the branch multiplier")
	near(b.location_price(5), SimulationRoot.location_cost(5) * m, 1e-6, "and so does every later move")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"station", e2.iid), 1), UpgradeManager.offer_cost(a.upgrades.offer(&"station", e.iid), 1), 1e-6, "an oven level keeps its price")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"counter", &"counter"), 10), UpgradeManager.offer_cost(a.upgrades.offer(&"counter", &"counter"), 10), 1e-6, "ten counter levels too")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"recipe", &"recipe_plain_loaf"), 1), UpgradeManager.offer_cost(a.upgrades.offer(&"recipe", &"recipe_plain_loaf"), 1), 1e-6, "a recipe level too")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"global", &"global_tap_power"), 1), UpgradeManager.offer_cost(a.upgrades.offer(&"global", &"global_tap_power"), 1), 1e-6, "a global upgrade too")
	near(b.staff.next_hire_cost(), a.staff.next_hire_cost(), 1e-6, "hiring too")
	near(b.decoration.price(&"decor_potted_plant"), a.decoration.price(&"decor_potted_plant"), 1e-6, "a bonus decoration too")
	near(b.recipe_price(&"recipe_plain_loaf"), a.recipe_price(&"recipe_plain_loaf"), 1e-9, "sale prices stay the same")
	near(b.boosts.promo_cost(&"promo_flyer"), a.boosts.promo_cost(&"promo_flyer"), 1e-6, "promotions follow KR/s, not the branch")
	# Bayar sungguhan: pindah lokasi menagih harga cabang.
	b.debug_add_kr(b.location_price(2))
	var before: float = b.economy.balance
	eq(b.upgrade_location(), "", "a dearer branch can move once it has the branch price")
	near(before - b.economy.balance, b.location_price(2), 0.01, "and pays exactly that")
	jump_to_tier(a, 2)
	check(b.upgrades.open_station_cost(&"display") > 0.0, "Tier 2 has a shelf to open")
	near(b.upgrades.open_station_cost(&"display"), a.upgrades.open_station_cost(&"display"), 1e-6, "opening a shelf keeps its price")
	# Waralaba: run_index naik, pengali ikut.
	jump_to_tier(a, 3)
	a.debug_add_kr(1.0e9)
	a.statistics.add(&"alltime_earned_kr", 1.0e9)
	check(a.franchise() > 0, "a franchise happens")
	eq(a.prestige.run_index, 2, "branch #2 opens")
	near(a.prestige.branch_cost_mult(), PrestigeManager.branch_cost_mult_for(2, a.prestige.stars), 1e-9, "and costs what its number and stars say")
	free_sim(a)
	free_sim(b)
	# Lembar Waralaba menyebut pengali cabang berikutnya.
	SaveManager.dir = "user://test_saves_branch"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Ladder Bakery")
	await runner.get_tree().process_frame
	game.sim.tutorial.skip()
	game.modals.close_all()
	game.playing = false
	var fr: UIScreen = game.modals.open(&"franchise")
	await runner.get_tree().process_frame
	check(fr.find_child("BranchCosts", true, false) == null, "branch #2 keeps catalog prices, so no cost line yet")
	game.modals.close_all()
	game.sim.prestige.run_index = start - 1
	game.sim.prestige.stars = 40
	fr = game.modals.open(&"franchise")
	await runner.get_tree().process_frame
	var bc: Label = fr.find_child("BranchCosts", true, false) as Label
	var p: PrestigeManager = game.sim.prestige
	eq(bc.text if bc != null else "", Tx.t("ui_franchise_branch_costs", {"number": start, "mult": FranchiseScreen._num(PrestigeManager.branch_cost_mult_for(start, p.stars + p.stars_gain()))}),
		"before branch #%d the Franchise sheet names its cost multiplier" % start)
	game.sim.prestige.stars = 0
	game.sim.prestige.run_index = 1
	game.modals.close_all()
	# Mastery di layar Menu (GDD idle 23.3).
	var th: Array = DataRegistry.idle("mastery.thresholds")
	game.sim.mastery.note_sold(&"recipe_plain_loaf", int(th[0]))
	var mn: UIScreen = game.modals.open(&"menu")
	await runner.get_tree().process_frame
	var row: Node = mn.find_child("Recipe_recipe_plain_loaf", true, false)
	var sub: Label = row.find_child("Sub", true, false) as Label if row != null else null
	check(sub != null and sub.text.contains(Tx.t("ui_mastery_row_next", {"level": 1, "sold": Tx.big(float(th[0])), "next": Tx.big(float(th[1]))})),
		"the Menu shows mastery stars and progress")
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	AudioManager.stop_all_sounds()


func _late_perks() -> void:
	var s: SimulationRoot = new_sim(2303)
	s.tutorial.skip()
	var base_hours: float = s.offline.cap_seconds()
	s.prestige.stars = 749
	near(s.prestige.offline_hours_bonus(), 1.0, 1e-9, "below 750 stars only Night Watch adds an hour")
	eq(s.prestige.start_tier(), 2, "Shophouse Start opens at Tier 2")
	s.prestige.stars = 750
	near(s.prestige.offline_hours_bonus(), 4.0, 1e-9, "Night Shift adds 3 more hours")
	check(s.offline.cap_seconds() > base_hours, "the offline cap grows")
	s.prestige.stars = 1000
	eq(s.prestige.start_tier(), 3, "Standalone Start opens at Tier 3")
	near(s.prestige.coffee_mult(), 1.0, 1e-9, "no longer coffee below 1,500 stars")
	s.prestige.stars = 1500
	near(s.prestige.coffee_mult(), 2.0, 1e-9, "Bottomless Cup doubles the coffee")
	s.boosts.new_run()
	s.boosts.pour_coffee()
	near(s.boosts.income_left, DataRegistry.idlef("boosts.daily_gift.minutes") * 60.0 * 2.0, 1e-6, "a cup now lasts twice as long")
	near(s.upgrades.recipe_milestone_mult(), 3.0, 1e-9, "Golden Milestones still x3")
	s.prestige.stars = 2500
	near(s.upgrades.recipe_milestone_mult(), 4.0, 1e-9, "Diamond Milestones makes them x4")
	s.prestige.stars = 5000
	near(s.prestige.golden_interval_mult(), 0.5, 1e-9, "Golden Rain halves the wait")
	var span: Array = DataRegistry.idle("golden.interval_minutes")
	for i in 5:
		s.golden._schedule()
		check(s.golden.next_in <= float(span[1]) * 60.0 * 0.5 + 0.001, "golden bread comes within half the usual wait (%.0f s)" % s.golden.next_in)
	# Waralaba dengan 1.000+ bintang mulai di Tier 3.
	jump_to_tier(s, 3)
	s.statistics.add(&"alltime_earned_kr", 1.0e12)
	s.prestige.stars = 1000
	check(s.franchise() > 0, "franchise")
	eq(s.world.location.tier, 3, "the new branch opens at Tier 3")
	eq(s.check_invariants(), "", "and is consistent")
	free_sim(s)


func _endless_series() -> void:
	var s: SimulationRoot = new_sim(2305)
	s.tutorial.skip()
	var series: Array = DataRegistry.idle("endless.series")
	check(series.size() >= 3, "three endless series")
	var earn: Dictionary = {}
	for x: Variant in series:
		if str((x as Dictionary)["id"]) == "earn":
			earn = x
	var toasts: Array = []
	var catch := func(_p: int, key: String, _params: Dictionary, _icon: StringName) -> void: toasts.append(key)
	EventBus.notify.connect(catch)
	eq(s.achievements.series_level("earn"), 0, "no level at first")
	s.statistics.add(&"alltime_earned_kr", AchievementManager.series_target(earn, 0) - 1.0)
	s.achievements.check_series()
	eq(s.achievements.series_level("earn"), 0, "one KR short of the first target")
	s.boosts.new_run()
	s.statistics.add(&"alltime_earned_kr", 1.0)
	s.achievements.check_series()
	eq(s.achievements.series_level("earn"), 1, "the first target reached")
	eq(toasts.count("ui_series_unlocked"), 1, "with a toast")
	check(s.boost_income_mult() > 1.0, "and an achievement boost")
	# Lompatan besar: beberapa level sekaligus, tetap tanpa batas.
	s.statistics.add(&"alltime_earned_kr", AchievementManager.series_target(earn, 3))
	s.achievements.check_series()
	eq(s.achievements.series_level("earn"), 4, "a big jump passes several targets at once")
	near(AchievementManager.series_target(earn, 10), float(earn["first"]) * pow(float(earn["factor"]), 10.0), 1.0, "targets keep growing by the factor")
	EventBus.notify.disconnect(catch)
	# Save/load.
	var u: SimulationRoot = SimulationRoot.new()
	runner.add_child(u)
	u.load_from_save(json_copy(s.capture_save()))
	eq(u.achievements.series_level("earn"), 4, "the series level survives a save")
	free_sim(u)
	free_sim(s)
	# Lembar Stats.
	var game: GameRoot = await _game("Series Bakery")
	game.sim.achievements.series["bread"] = 2
	var st: StatsScreen = game.modals.open(&"stats", {}) as StatsScreen
	await runner.get_tree().process_frame
	st._tab = 2
	st.refresh()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	for x2: Variant in series:
		check(st.content().find_child("Series_" + str((x2 as Dictionary)["id"]), true, false) != null, "the Stats sheet lists the %s series" % (x2 as Dictionary)["id"])
	await _end(game)


func _legacy() -> void:
	var after: int = DataRegistry.idlei("prestige.legacy_after_stars")
	var every: int = DataRegistry.idlei("prestige.legacy_every_stars")
	var inc: float = DataRegistry.idlef("prestige.legacy_income")
	eq(PrestigeManager.legacy_level_for(after), 0, "no Legacy at the last perk itself")
	eq(PrestigeManager.legacy_level_for(after + every - 1), 0, "nor one star short of it")
	eq(PrestigeManager.legacy_level_for(after + every), 1, "Legacy 1")
	eq(PrestigeManager.legacy_level_for(after + every * 7 + 3), 7, "Legacy 7")
	var per: float = DataRegistry.idlef("prestige.income_per_star")
	var st: int = after + every * 3
	near(PrestigeManager.star_mult_for(st), (1.0 + per * float(st)) * pow(1.0 + inc, 3.0), 1e-6, "Legacy multiplies the star income")
	var s: SimulationRoot = new_sim(2306)
	s.prestige.stars = st
	near(s.prestige.income_mult(), PrestigeManager.star_mult_for(st), 1e-9, "and it is part of the income multiplier")
	eq(s.prestige.next_legacy_stars(), after + every * 4, "the next level needs another step")
	free_sim(s)
	var game: GameRoot = await _game("Legacy Bakery")
	game.sim.prestige.stars = st
	var fr: UIScreen = game.modals.open(&"franchise")
	await runner.get_tree().process_frame
	var row: Node = fr.find_child("Legacy", true, false)
	check(row != null, "the Franchise sheet has a Legacy row")
	var found: bool = false
	if row != null:
		for l: Node in row.find_children("*", "Label", true, false):
			found = found or (l as Label).text == Tx.t("ui_legacy_title", {"level": 3})
	check(found, "naming Legacy 3")
	game.sim.prestige.stars = 0
	await _end(game)


func _town_bonus() -> void:
	var arr: Array = DataRegistry.idle("town.bonus_by_tier")
	var s0: SimulationRoot = new_sim(2317)
	jump_to_tier(s0, 5)
	near(s0.prestige.town_bonus(), 0.0, 1e-9, "the first branch alone has no town yet (run 1 pacing unchanged)")
	free_sim(s0)
	var s: SimulationRoot = new_sim(2307)
	s.prestige.run_index = 2
	s.prestige.branch_no = 2
	near(s.prestige.town_bonus(), float(arr[0]), 1e-9, "after the first franchise a garage adds its Tier 1 share")
	var p0: float = s.plain_price(&"recipe_plain_loaf")
	jump_to_tier(s, 3)
	near(s.prestige.town_bonus(), float(arr[2]), 1e-9, "the branch being played adds its highest tier")
	s.prestige._put({"number": 2, "tier": 5, "stars": 0, "earned": 0.0, "rate": 0.0, "opened_day": 1, "left_unix": 0.0, "cap": 0.0, "eff": 0.0})
	s.prestige._put({"number": 3, "tier": 4, "stars": 0, "earned": 0.0, "rate": 0.0, "opened_day": 1, "left_unix": 0.0, "cap": 0.0, "eff": 0.0})
	near(s.prestige.town_bonus(), float(arr[2]) + float(arr[4]) + float(arr[3]), 1e-9, "every other branch adds its share")
	near(s.prestige.town_mult(), 1.0 + s.prestige.town_bonus(), 1e-9, "town multiplier")
	for i in 60:
		s.prestige._put({"number": 10 + i, "tier": 5, "stars": 0, "earned": 0.0, "rate": 0.0, "opened_day": 1, "left_unix": 0.0, "cap": 0.0, "eff": 0.0})
	near(s.prestige.town_bonus(), DataRegistry.idlef("town.max_bonus"), 1e-9, "the bonus stops at town.max_bonus")
	var r: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	near(s.plain_price(r.id), r.base_sell_price_kr * s.upgrades.recipe_price_mult(r.id) * s.cravings.favorite_mult(r.id) * s.events.featured_mult(r.id)
		* s.decoration.bonus_mult(&"price") * s.prestige.income_mult() * s.prestige.town_mult() * s.prestige.signature_mult(r.id) * s.mastery.price_mult(r.id), 1e-6,
		"prices carry the town bonus")
	check(p0 > 0.0, "a price before")
	free_sim(s)
	var game: GameRoot = await _game("Town Bakery")
	var map: UIScreen = game.modals.open(&"town_map")
	await runner.get_tree().process_frame
	var tb: Label = map.find_child("TownBonus", true, false) as Label
	eq(tb.text if tb != null else "", Tx.t("ui_town_bonus", {"percent": FranchiseScreen._pct(game.sim.prestige.town_bonus())}), "the map shows the town bonus")
	var lot: Button = map.find_child("Branch1", true, false) as Button
	if lot != null:
		lot.pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(map.find_child("BranchExtras", true, false) != null, "the story page names its share and signature bread")
	game.modals.close_all()
	var fr: UIScreen = game.modals.open(&"franchise")
	await runner.get_tree().process_frame
	check(fr.find_child("TownBonus", true, false) != null, "the Franchise sheet shows the town bonus")
	await _end(game)


func _signature() -> void:
	var a: SimulationRoot = new_sim(2308)
	var b: SimulationRoot = new_sim(2308)
	var c: SimulationRoot = new_sim(9999)
	var same: int = 0
	var differ: int = 0
	eq(a.prestige.signature(1), &"", "the first branch has no signature bread (run 1 pacing unchanged)")
	near(a.prestige.signature_mult(&"recipe_plain_loaf"), 1.0, 1e-9, "so nothing sells for more there")
	a.prestige.run_index = 2
	a.prestige.branch_no = 2
	for n in range(2, 30):
		eq(a.prestige.signature(n), b.prestige.signature(n), "branch %d: the same seed picks the same signature bread" % n)
		if n > 2:
			check(a.prestige.signature(n) != a.prestige.signature(n - 1), "branch %d differs from the branch before" % n)
		if a.prestige.signature(n) == c.prestige.signature(n):
			same += 1
		else:
			differ += 1
		check(DataRegistry.recipe(a.prestige.signature(n)) != null, "branch %d picks a real recipe" % n)
	check(differ > same, "another save picks other signature breads (%d differ, %d same)" % [differ, same])
	var sig: StringName = a.prestige.signature()
	var other: StringName = &"recipe_plain_loaf" if sig != &"recipe_plain_loaf" else &"recipe_sugar_donut"
	near(a.prestige.signature_mult(sig), DataRegistry.idlef("branch.signature_mult"), 1e-9, "the signature bread sells for signature_mult")
	near(a.prestige.signature_mult(other), 1.0, 1e-9, "other breads do not")
	a.prestige.branch_no = 3
	a.prestige.run_index = 3
	if a.prestige.signature() != sig:
		near(a.prestige.signature_mult(sig), 1.0, 1e-9, "in another branch the old signature bread is ordinary")
	free_sim(a)
	free_sim(b)
	free_sim(c)
	var game: GameRoot = await _game("Signature Bakery")
	game.sim.prestige.run_index = 2
	game.sim.prestige.branch_no = 2
	var gs: StringName = game.sim.prestige.signature()
	var mn: UIScreen = game.modals.open(&"menu")
	await runner.get_tree().process_frame
	var row: Node = mn.find_child("Recipe_" + String(gs), true, false)
	check(row != null and row.find_child("SignaturePill", true, false) != null, "the Menu marks the signature bread")
	check(mn.find_child("SignatureLine", true, false) != null, "and the craving card names it")
	await _end(game)


func _street_variant() -> void:
	var loc: LocationDefinition = DataRegistry.location_by_tier(2)
	var f: FloorDefinition = null
	for fd: FloorDefinition in loc.floors:
		if fd.id == loc.store_floor():
			f = fd
	var n0: Node3D = NeighborhoodFactory.build(loc, f, false, 0)
	var n1: Node3D = NeighborhoodFactory.build(loc, f, false, 1)
	var m0: ArrayMesh = (n0.get_node("Street") as MeshInstance3D).mesh as ArrayMesh
	var m1: ArrayMesh = (n1.get_node("Street") as MeshInstance3D).mesh as ArrayMesh
	var a0: Array = m0.surface_get_arrays(0)
	var a1: Array = m1.surface_get_arrays(0)
	eq((a0[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (a1[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), "the same number of vertices")
	var moved: int = 0
	var recolored: int = 0
	var v0: PackedVector3Array = a0[Mesh.ARRAY_VERTEX]
	var v1: PackedVector3Array = a1[Mesh.ARRAY_VERTEX]
	var c0: PackedColorArray = a0[Mesh.ARRAY_COLOR]
	var c1: PackedColorArray = a1[Mesh.ARRAY_COLOR]
	for i in v0.size():
		if not v0[i].is_equal_approx(v1[i]):
			moved += 1
		var dc: Color = c0[i] - c1[i]
		if absf(dc.r) + absf(dc.g) + absf(dc.b) > 0.03:
			recolored += 1
	eq(moved, 0, "the same shapes in the same places")
	check(recolored > 100, "the neighbours' colours change (%d vertices)" % recolored)
	eq(int(n1.get_meta("variant", -1)), 1, "the street knows its variant")
	n0.free()
	n1.free()
	var game: GameRoot = await _game("Street Bakery")
	var hood: Node = game.world.find_child("Neighborhood", true, false)
	eq(int(hood.get_meta("variant", -1)) if hood != null else -1, game.sim.prestige.branch_no - 1, "the world builds the street for the branch being played")
	await _end(game)


## GameRoot dengan game baru untuk tes UI lembar.
func _game(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_endless"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", label)
	await runner.get_tree().process_frame
	game.sim.tutorial.skip()
	game.modals.close_all()
	PauseManager.clear_all()
	game.playing = false
	return game


func _end(game: GameRoot) -> void:
	game.modals.close_all()
	game.playing = true
	game.end_session()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


func _mastery() -> void:
	var s: SimulationRoot = new_sim(2304)
	s.tutorial.skip()
	var th: Array = DataRegistry.idle("mastery.thresholds")
	var bonus: float = DataRegistry.idlef("mastery.price_bonus_per_level")
	var rid: StringName = &"recipe_plain_loaf"
	eq(s.mastery.level(rid), 0, "no mastery at first")
	var p0: float = s.plain_price(rid)
	var toasts: Array = []
	var catch_toast := func(_p: int, key: String, _params: Dictionary, _icon: StringName) -> void: toasts.append(key)
	EventBus.notify.connect(catch_toast)
	s.mastery.note_sold(rid, int(th[0]) - 1)
	eq(s.mastery.level(rid), 0, "one short of the first threshold")
	eq(toasts.count("ui_mastery_up"), 0, "no toast yet")
	var rate0: float = s.idle_economy.rate(false)
	s.mastery.note_sold(rid, 1)
	eq(s.mastery.level(rid), 1, "the first star")
	eq(toasts.count("ui_mastery_up"), 1, "with a toast")
	near(s.plain_price(rid), p0 * (1.0 + bonus), 1e-6, "the price rises by the bonus")
	check(s.idle_economy.rate(false) > rate0, "and so does the KR/s model")
	s.mastery.note_sold(rid, int(th[th.size() - 1]))
	eq(s.mastery.level(rid), th.size(), "the last catalog star")
	near(s.mastery.price_mult(rid), 1.0 + bonus * float(th.size()), 1e-9, "its price bonus")
	# Tanpa ujung (GDD idle §20 no. 90): setiap bintang berikutnya butuh faktor x roti.
	var f: float = DataRegistry.idlef("mastery.endless_factor")
	var next: int = int(float(th[th.size() - 1]) * f)
	eq(s.mastery.next_threshold(rid), next, "mastery goes on: the next star needs endless_factor times the last threshold")
	s.mastery.note_sold(rid, next - s.mastery.units(rid))
	eq(s.mastery.level(rid), th.size() + 1, "a star past the catalog")
	eq(s.mastery.next_threshold(rid), int(float(th[th.size() - 1]) * f * f), "and the one after needs the factor again")
	near(s.mastery.price_mult(rid), 1.0 + bonus * float(th.size() + 1), 1e-9, "every star keeps adding the bonus")
	eq(MasteryManager.level_for(int(float(th[th.size() - 1]) * pow(f, 4.0)) + 1), th.size() + 4, "four stars past the catalog")
	EventBus.notify.disconnect(catch_toast)
	# Penjualan sungguhan dihitung per resep.
	var sold0: float = s.statistics.get_stat("total_bread_sold")
	var m0: int = 0
	for r: RecipeDefinition in DataRegistry.recipes():
		m0 += s.mastery.units(r.id)
	run_hours(s, 3.0)
	var m1: int = 0
	for r2: RecipeDefinition in DataRegistry.recipes():
		m1 += s.mastery.units(r2.id)
	check(s.statistics.get_stat("total_bread_sold") > sold0, "bread sold in three hours")
	eq(m1 - m0, int(s.statistics.get_stat("total_bread_sold") - sold0), "every sold bread counts toward mastery")
	# Bertahan setelah Waralaba dan save.
	var units: int = s.mastery.units(rid)
	jump_to_tier(s, 3)
	s.statistics.add(&"alltime_earned_kr", 1.0e9)
	check(s.franchise() > 0, "franchise")
	eq(s.mastery.units(rid), units, "mastery survives the franchise")
	var d: Dictionary = json_copy(s.capture_save())
	check(d.has("mastery"), "the save holds mastery")
	var t: SimulationRoot = load_sim(d)
	eq(t.mastery.units(rid), units, "and loads it back")
	near(t.plain_price(rid), s.plain_price(rid), 1e-6, "with the same price")
	free_sim(t)
	free_sim(s)
