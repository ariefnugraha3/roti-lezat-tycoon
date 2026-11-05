extends TestSuite
## Umur permainan panjang (GDD idle 23): cabang Waralaba yang makin mahal, perk
## lanjutan, dan mastery resep yang permanen.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_BRANCH_COSTS", "name": "idle 23.1 every KR cost in branch n is the catalog cost x branch_cost_growth^(n-1): station, counter, recipe, staff and global levels, opening stations, unlocking recipes, hiring, moving and bonus decorations; sale prices and promotions are not; the Franchise sheet names the next branch's multiplier", "fn": _branch_costs},
		{"id": "ACC_IDLE_PERKS_LATE", "name": "idle 23.2 late perks: 750 stars +3 h offline, 1,000 a Tier 3 start, 1,500 coffee x2 longer, 2,500 recipe milestones x4, 5,000 golden bread twice as often", "fn": _late_perks},
		{"id": "ACC_IDLE_MASTERY", "name": "idle 23.3 recipe mastery: bread sold in the shop and through RotiFood counts per recipe, stars at the catalog thresholds raise that recipe's price for good (also in the KR/s model), a new star shows a toast, and mastery survives a franchise and a save", "fn": _mastery},
	]


func _branch_costs() -> void:
	var a: SimulationRoot = new_sim(2301)
	var b: SimulationRoot = new_sim(2301)
	a.tutorial.skip()
	b.tutorial.skip()
	b.prestige.run_index = 3
	var start: int = DataRegistry.idlei("prestige.branch_cost_start")
	b.prestige.run_index = start + 1
	var m: float = pow(DataRegistry.idlef("prestige.branch_cost_growth"), 2.0)
	near(b.prestige.branch_cost_mult(), m, 1e-9, "branch #%d costs x growth^2" % (start + 1))
	near(PrestigeManager.branch_cost_mult_for(start - 1), 1.0, 1e-9, "branches before #%d keep the catalog price" % start)
	near(PrestigeManager.branch_cost_mult_for(start), DataRegistry.idlef("prestige.branch_cost_growth"), 1e-9, "branch #%d is the first that costs more" % start)
	near(a.prestige.branch_cost_mult(), 1.0, 1e-9, "branch #1 costs the catalog price")
	var e: EquipmentInstance = a.equipment.placed_list(&"oven")[0]
	var e2: EquipmentInstance = b.equipment.placed_list(&"oven")[0]
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"station", e2.iid), 1), UpgradeManager.offer_cost(a.upgrades.offer(&"station", e.iid), 1) * m, 1e-6, "an oven level")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"counter", &"counter"), 10), UpgradeManager.offer_cost(a.upgrades.offer(&"counter", &"counter"), 10) * m, 1e-6, "ten counter levels")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"recipe", &"recipe_plain_loaf"), 1), UpgradeManager.offer_cost(a.upgrades.offer(&"recipe", &"recipe_plain_loaf"), 1) * m, 1e-6, "a recipe level")
	near(UpgradeManager.offer_cost(b.upgrades.offer(&"global", &"global_tap_power"), 1), UpgradeManager.offer_cost(a.upgrades.offer(&"global", &"global_tap_power"), 1) * m, 1e-6, "a global upgrade")
	var donut: RecipeDefinition = DataRegistry.recipe(&"recipe_sugar_donut")
	near(b.upgrades.unlock_price(donut), UpgradeManager.unlock_cost(donut) * m, 1e-6, "unlocking a recipe")
	near(b.staff.next_hire_cost(), a.staff.next_hire_cost() * m, 1e-6, "hiring")
	near(b.location_price(2), SimulationRoot.location_cost(2) * m, 1e-6, "moving to Tier 2")
	near(b.decoration.price(&"decor_potted_plant"), a.decoration.price(&"decor_potted_plant") * m, 1e-6, "a bonus decoration")
	near(b.recipe_price(&"recipe_plain_loaf"), a.recipe_price(&"recipe_plain_loaf"), 1e-9, "sale prices stay the same")
	near(b.boosts.promo_cost(&"promo_flyer"), a.boosts.promo_cost(&"promo_flyer"), 1e-6, "promotions follow KR/s, not the branch")
	# Bayar sungguhan: pindah lokasi menagih harga cabang.
	b.debug_add_kr(b.location_price(2))
	var before: float = b.economy.balance
	eq(b.upgrade_location(), "", "a dearer branch can move once it has the branch price")
	near(before - b.economy.balance, b.location_price(2), 0.01, "and pays exactly that")
	jump_to_tier(a, 2)
	check(b.upgrades.open_station_cost(&"display") > 0.0, "Tier 2 has a shelf to open")
	near(b.upgrades.open_station_cost(&"display"), a.upgrades.open_station_cost(&"display") * m, 1e-6, "opening a shelf")
	# Waralaba: run_index naik, pengali ikut.
	jump_to_tier(a, 3)
	a.debug_add_kr(1.0e9)
	a.statistics.add(&"alltime_earned_kr", 1.0e9)
	check(a.franchise() > 0, "a franchise happens")
	eq(a.prestige.run_index, 2, "branch #2 opens")
	near(a.prestige.branch_cost_mult(), PrestigeManager.branch_cost_mult_for(2), 1e-9, "and costs what its number says")
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
	fr = game.modals.open(&"franchise")
	await runner.get_tree().process_frame
	var bc: Label = fr.find_child("BranchCosts", true, false) as Label
	eq(bc.text if bc != null else "", Tx.t("ui_franchise_branch_costs", {"number": start, "mult": FranchiseScreen._num(PrestigeManager.branch_cost_mult_for(start))}),
		"before branch #%d the Franchise sheet names its cost multiplier" % start)
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
	eq(s.mastery.level(rid), th.size(), "the last star")
	eq(s.mastery.next_threshold(rid), -1, "nothing left to reach")
	near(s.mastery.price_mult(rid), 1.0 + bonus * float(th.size()), 1e-9, "full price bonus")
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
