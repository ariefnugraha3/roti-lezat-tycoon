extends TestSuite
## Waralaba (GDD idle 10): bintang, syarat, reset putaran, perk, dan alur layar
## Franchise -> konfirmasi -> cutscene -> cabang baru.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_PRESTIGE", "name": "idle 10.1-10.5 stars = floor((alltime / divisor)^exponent), franchise needs Tier 3 this run and >= 1 new star, the reset clears KR, location, stations, levels, recipes, staff, shop upgrades up to Lv 5 and reputation while stars, perks, alltime stats, badges, decorations, name and character stay; perks shape the new branch; the result saves, loads and replays deterministically", "fn": _prestige},
		{"id": "ACC_IDLE_FRANCHISE_FLOW", "name": "idle 10.6, 12.3 the Franchise sheet shows stars, what selling earns, the next star and every perk; Sell & Franchise asks first, plays the Pak Lurah cutscene with the new signboard, then opens Branch #2 behind the loading screen and saves it", "fn": _flow},
	]


## Pembagi bintang katalog (prestige.stars_divisor_kr): KR sepanjang masa untuk 1 bintang.
static func _d() -> float:
	return DataRegistry.idlef("prestige.stars_divisor_kr")


## Toko Tier 3 yang mapan dengan `alltime` KR sepanjang masa.
func _ready_shop(seed_value: int, alltime: float) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	jump_to_tier(s, 3)
	equip_shop(s, 30)
	s.statistics.stats["alltime_earned_kr"] = alltime
	return s


func _prestige() -> void:
	# Rumus bintang (10.2).
	var d: float = _d()
	eq(PrestigeManager.stars_for(0.0), 0, "no KR, no star")
	eq(PrestigeManager.stars_for(d - 1.0), 0, "just under one divisor is still 0 stars")
	eq(PrestigeManager.stars_for(d), 1, "one divisor earns 1 star")
	eq(PrestigeManager.stars_for(3.99 * d), 1, "under 4 divisors is 1 star")
	eq(PrestigeManager.stars_for(4.0 * d), 2, "4 divisors earn 2 stars (square root)")
	eq(PrestigeManager.stars_for(100.0 * d), 10, "100 divisors earn 10 stars")
	check(PrestigeManager.stars_for(1.0e300) > 0, "a huge number stays a finite star count")
	# Syarat (10.1).
	var fresh: SimulationRoot = new_sim(77)
	fresh.tutorial.skip()
	fresh.statistics.stats["alltime_earned_kr"] = 1.0e9
	eq(fresh.prestige.franchise_block(), &"tier", "Tier 1 cannot franchise")
	eq(fresh.franchise(), 0, "and franchise() refuses")
	free_sim(fresh)
	var s: SimulationRoot = _ready_shop(78, 0.0)
	eq(s.prestige.franchise_block(), &"stars", "Tier 3 without a new star cannot franchise")
	s.statistics.stats["alltime_earned_kr"] = 4.2 * d
	eq(s.prestige.franchise_block(), &"", "Tier 3 with 2 new stars can")
	eq(s.prestige.stars_gain(), 2, "selling now earns 2 stars")
	near(s.prestige.kr_to_next_star(), 9.0 * d - 4.2 * d, 1.0, "the next star needs 9 divisors all-time")
	# State sebelum reset.
	s.upgrades.global_levels[&"global_tap_power"] = 3
	s.upgrades.global_levels[&"global_offline_hours"] = 6
	s.reputation.reputation = 4.6
	run_hours(s, 0.5)
	var sold: float = s.statistics.get_stat("total_bread_sold")
	check(sold > 0.0, "the Tier 3 shop sells before the sale")
	var deco: MiscDefinitions.DecorationDefinition = DataRegistry.decorations()[0]
	s.decoration.grant(deco.id)
	var owned_before: Array = s.decoration.owned.map(func(o: Dictionary) -> int: return int(o["uid"]))
	var day: int = s.time.day
	var clock: float = s.time.time_seconds
	var appearance: Dictionary = s.player.appearance.duplicate()
	var alltime: float = s.statistics.get_stat("alltime_earned_kr")
	eq(s.franchise(), 2, "franchise returns the 2 new stars")
	# Disimpan.
	eq(s.prestige.stars, 2, "the stars are added")
	eq(s.prestige.run_index, 2, "the branch number goes up")
	near(s.statistics.get_stat("alltime_earned_kr"), alltime, 0.5, "alltime earnings stay")
	near(s.statistics.get_stat("total_bread_sold"), sold, 0.001, "lifetime stats stay")
	near(s.statistics.get_stat("run_earned_kr"), 0.0, 0.001, "run earnings start over")
	var owned_after: Array = s.decoration.owned.map(func(o: Dictionary) -> int: return int(o["uid"]))
	check(owned_before.all(func(u: int) -> bool: return owned_after.has(u)), "owned decorations stay")
	check(s.achievements.is_unlocked(&"ach_first_franchise"), "the sale unlocks First Franchise (GDD idle 11.4)")
	eq(s.bakery_name, "Test Bakery", "the bakery name stays")
	eq(s.player.appearance, appearance, "the character stays")
	check(s.tutorial.skipped, "the tutorial state stays")
	eq(s.time.day, day, "the clock keeps running: same day")
	near(s.time.time_seconds, clock, 0.001, "and the same time")
	eq(s.upgrades.global_level(&"global_offline_hours"), 6, "shop upgrades above Lv 5 stay")
	# Direset.
	eq(s.world.location.tier, 1, "the new branch opens at Tier 1")
	near(s.economy.balance, DataRegistry.idlef("start_kr"), 0.5, "with start_kr")
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		eq(s.equipment.placed_count(cat), 1, "one %s again" % cat)
		eq(s.upgrades.station_level(s.equipment.placed_list(cat)[0].iid), 1, "at Lv 1")
	eq(s.upgrades.counter_level, 1, "the counter is Lv 1")
	eq(s.upgrades.unlocked_recipes(), [&"recipe_plain_loaf"] as Array[StringName], "only Plain Loaf is unlocked")
	eq(s.staff.employed_ids().size(), 0, "no staff")
	eq(s.upgrades.global_level(&"global_tap_power"), 0, "shop upgrades up to Lv 5 reset")
	near(s.reputation.reputation, DataRegistry.idlef("reputation.start"), 1e-9, "reputation is back at 3.0")
	eq(s.customers.sorted().size(), 0, "nobody is left in the old shop")
	eq(s.production.jobs.size(), 0, "no batch carries over")
	check(s.world.layout_valid(), "the new branch has a valid layout")
	# Pengali bintang dan perk 1 bintang.
	var base_price: float = DataRegistry.recipe(&"recipe_plain_loaf").base_sell_price_kr
	near(s.recipe_price(&"recipe_plain_loaf") / s.boost_income_mult(), base_price * (1.0 + DataRegistry.idlef("prestige.income_per_star") * 2.0), 1e-6,
		"every star adds 2% to the price (Lv 1 Plain Loaf, without the achievement boost)")
	check(s.prestige.has_perk(&"perk_offline_plus"), "1 star unlocks Night Watch")
	near(s.offline.cap_seconds(), (2.0 + 6.0 + 1.0) * 3600.0, 0.001, "which adds 1 h to the offline cap")
	eq(s.prestige.franchise_block(), &"tier", "the new branch must reach Tier 3 again")
	# Cabang baru berjalan, tersimpan, dan deterministik.
	run_hours(s, 0.5)
	check(s.statistics.get_stat("run_earned_kr") > 0.0, "the new branch sells on its own")
	var saved: Dictionary = json_copy(s.capture_save())
	eq(int((saved["franchise"] as Dictionary)["run_index"]), 2, "the save keeps run_index")
	eq(int((saved["franchise"] as Dictionary)["stars"]), 2, "and the stars")
	var s2: SimulationRoot = load_sim(saved)
	same_state(logical_state(s2.capture_save()), logical_state(saved), "the branch survives a save and load")
	free_sim(s2)
	var twin: SimulationRoot = _ready_shop(78, 0.0)
	twin.statistics.stats["alltime_earned_kr"] = 4.2 * _d()
	twin.upgrades.global_levels[&"global_tap_power"] = 3
	twin.upgrades.global_levels[&"global_offline_hours"] = 6
	twin.reputation.reputation = 4.6
	run_hours(twin, 0.5)
	twin.decoration.grant(deco.id)
	twin.franchise()
	run_hours(twin, 0.5)
	same_state(logical_state(twin.capture_save()), logical_state(s.capture_save()), "the same seed and actions replay the same branch")
	free_sim(twin)
	free_sim(s)
	# Perk besar membentuk cabang baru (10.4).
	var p: SimulationRoot = _ready_shop(79, 0.0)
	p.upgrades.unlock_recipe(&"recipe_sugar_donut")
	p.prestige.stars = 499
	p.statistics.stats["alltime_earned_kr"] = _d() * 500.0 * 500.0
	eq(p.franchise(), 1, "499 -> 500 stars")
	eq(p.world.location.tier, int(DataRegistry.perk(&"perk_ruko_start").get("start_tier", 2)), "Shophouse Start opens the branch at Tier 2")
	near(p.economy.balance, float(DataRegistry.perk(&"perk_head_start").get("start_kr", 5000)), 0.5, "Head Start opens with 5K KR")
	eq(p.staff.employed_ids(&"baker").size(), 1, "Loyal Baker hires the first Kitchen Assistant")
	near(p.economy.balance, float(DataRegistry.perk(&"perk_head_start").get("start_kr", 5000)), 0.5, "for free")
	check(p.upgrades.is_unlocked(&"recipe_sugar_donut"), "Family Recipes keeps Sugar Donut unlocked")
	eq(p.upgrades.recipe_level(&"recipe_sugar_donut"), 1, "at Lv 1")
	near(p.prestige.tap_mult(), 2.0, 1e-9, "Double Cheer doubles taps")
	near(p.offline.efficiency(), 0.75, 1e-9, "Trusted Keys adds 25% offline efficiency")
	near(p.upgrades.recipe_milestone_mult(), 3.0, 1e-9, "Golden Milestones makes recipe milestones x3")
	check(p.world.layout_valid(), "the Tier 2 branch layout is valid")
	run_hours(p, 1.0)
	check(p.statistics.get_stat("run_earned_kr") > 0.0, "the perk branch sells too")
	free_sim(p)


# ===========================================================================
# ALUR LAYAR
# ===========================================================================

func _boot(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_franchise"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", label)
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
	return game


func _finish(game: GameRoot) -> void:
	game.modals.close_all()
	game.playing = true
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame


func _flow() -> void:
	var game: GameRoot = await _boot("Branch Bakery")
	var sim: SimulationRoot = game.sim
	check(game.hud.tab_button(&"franchise") != null and game.hud.tab_button(&"franchise").visible, "the Franchise tab is shown")
	check(not game.hud.has_affordable(&"franchise"), "no green dot at Tier 1")
	game.hud.open_tab(&"franchise")
	await _frames(2)
	var sheet: FranchiseScreen = game.modals.top() as FranchiseScreen
	check(sheet != null, "the tab opens the Franchise sheet")
	var sell: Button = sheet.content().find_child("Sell", true, false) as Button
	check(sell != null and sell.disabled, "Sell & Franchise is off at Tier 1")
	var gain: Label = sheet.content().find_child("Gain", true, false) as Label
	check(gain != null and gain.text == Tx.t("ui_franchise_need_tier", {"location": Tx.t(String(DataRegistry.location_by_tier(3).localization_key))}),
		"it says which location opens franchising")
	eq(sheet.content().find_children("Perk_*", "", true, false).size(), DataRegistry.idle("perks").size(), "every perk is listed")
	var perk_row: Node = sheet.content().find_child("Perk_perk_head_start", true, false)
	var perk_state: Label = perk_row.find_child("State", true, false) as Label if perk_row != null else null
	check(perk_state != null and perk_state.text == Tx.t("ui_franchise_perk_need", {"stars": "5"}), "a locked perk shows the stars it needs")
	game.modals.close_all()
	jump_to_tier(sim, 3)
	sim.statistics.stats["alltime_earned_kr"] = 4.2 * _d()
	check(game.hud.has_affordable(&"franchise"), "the tab gets its green dot once franchising pays")
	game.hud.open_tab(&"franchise")
	await _frames(2)
	sheet = game.modals.top() as FranchiseScreen
	sell = sheet.content().find_child("Sell", true, false) as Button
	gain = sheet.content().find_child("Gain", true, false) as Label
	check(not sell.disabled, "Sell & Franchise is on at Tier 3 with new stars")
	eq(gain.text, Tx.t("ui_franchise_gain", {"stars": "2"}), "it says selling earns 2 stars")
	var nxt: Label = sheet.content().find_child("Next", true, false) as Label
	eq(nxt.text, Tx.t("ui_franchise_next", {"amount": Tx.kr(sim.prestige.kr_to_next_star())}), "and how much the next star needs")
	sell.pressed.emit()
	await _frames(2)
	check(game.modals.is_open(&"confirm"), "selling asks first")
	for n: Node in game.modals.get_children():
		if n is ConfirmDialog:
			(n as ConfirmDialog)._accept()
	await _frames(2)
	var cut: FranchiseCutscene = game.modals.top() as FranchiseCutscene
	check(cut != null, "the Pak Lurah cutscene plays")
	eq(sim.prestige.run_index, 1, "nothing is reset yet")
	if cut != null:
		check(cut.find_child("Lurah", true, false) is LurahPortrait, "Pak Lurah is there")
		var gained: Label = cut.find_child("Gained", true, false) as Label
		check(gained != null and gained.text == Tx.t("ui_franchise_stars_gained", {"stars": "2"}), "it shows the 2 new stars")
		(cut.find_child("Continue", true, false) as Button).pressed.emit()
		await _frames(2)
		var sign: Signboard = cut.find_child("Signboard", true, false) as Signboard
		check(sign != null and sign.title_text == "Branch Bakery" and sign.sub_text == Tx.t("ui_branch_number", {"number": 2}),
			"the new signboard keeps the name and says Branch #2")
		(cut.find_child("Continue", true, false) as Button).pressed.emit()
	var waited: int = 0
	while waited < 600 and not (game.playing and game.hud != null and game.sim.prestige.run_index == 2 and game.loading_screen() == null):
		await runner.get_tree().process_frame
		waited += 1
	check(game.playing and game.hud != null, "the new branch opens behind the loading screen")
	await _frames(3)
	eq(game.sim, sim, "the same simulation carries on")
	eq(sim.prestige.run_index, 2, "Branch #2")
	eq(sim.world.location.tier, 1, "in a fresh Tier 1 garage")
	eq(sim.prestige.stars, 2, "with the 2 stars")
	check(game.world != null and is_instance_valid(game.world), "the world is rebuilt")
	var header: Dictionary = SaveManager.read_header(&"profile_1")
	eq(int(header.get("run_index", 0)), 2, "the new branch is saved")
	var toast_text: String = Tx.t("ui_branch_open", {"number": 2})
	var found: bool = false
	for c: Node in game.hud.find_child("Toasts", true, false).get_children():
		if str(c.get_meta("text", "")) == toast_text:
			found = true
	check(found, "a toast welcomes Branch #2")
	await _finish(game)
