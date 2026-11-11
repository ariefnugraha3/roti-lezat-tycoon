extends TestSuite
## Waralaba (GDD idle 10): bintang, syarat, reset putaran, perk, dan alur layar
## Franchise -> konfirmasi -> cutscene -> cabang baru. Cabang lama tetap milik
## pemain dan bisa dikunjungi (GDD idle §20 no. 78).


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_PRESTIGE", "name": "idle 10.1-10.5 stars = floor((alltime / divisor)^exponent), franchise needs Tier 3 this run and >= 1 new star, the reset clears KR, location, stations, levels, recipes, staff, shop upgrades up to Lv 5 while stars, perks, alltime stats, badges, decorations, name and character stay; perks shape the new branch; the result saves, loads and replays deterministically", "fn": _prestige},
		{"id": "ACC_IDLE_FRANCHISE_FLOW", "name": "idle 10.6, 12.3 the Franchise sheet shows stars, what a new branch earns, the next star and every perk; Open a New Branch asks first, plays the Pak Lurah cutscene with the new signboard, then opens Branch #2 behind the loading screen and saves it", "fn": _flow},
		{"id": "ACC_IDLE_BRANCH_VISIT", "name": "idle 20 no. 78 a franchise keeps the old branch with its own shop and wallet; a branch you are not in saves like offline (KR/s when left x min(away, cap) x efficiency, nothing under a minute, a toast under five minutes, Collect after that); visiting restores it exactly, the next branch can open from any branch once the newest reaches Tier 3, a branch sold before this rule reopens as a fresh shop at its tier, and everything survives save and load", "fn": _branch_visit},
		{"id": "ACC_IDLE_BRANCH_VISIT_FLOW", "name": "idle 20 no. 78 the Crumbtown map shows what each other branch has waiting and a Visit button in its story; visiting rebuilds the world behind the loading screen, greets the branch, and its savings wait for Collect in the Welcome Back popup", "fn": _visit_flow},
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
	eq(s.customers.sorted().size(), 0, "nobody is left in the old shop")
	eq(s.production.jobs.size(), 0, "no batch carries over")
	check(s.world.layout_valid(), "the new branch has a valid layout")
	# Pengali bintang dan perk 1 bintang.
	var base_price: float = DataRegistry.recipe(&"recipe_plain_loaf").base_sell_price_kr
	near(s.recipe_price(&"recipe_plain_loaf") / s.boost_income_mult() / s.prestige.town_mult() / s.prestige.signature_mult(&"recipe_plain_loaf"),
		base_price * (1.0 + DataRegistry.idlef("prestige.income_per_star") * 2.0), 1e-6,
		"every star adds 2% to the price (Lv 1 Plain Loaf, without the achievement boost, town bonus and signature bread)")
	near(s.prestige.town_bonus(), PrestigeManager.town_bonus_for_tier(3) + PrestigeManager.town_bonus_for_tier(1), 1e-9,
		"the old Tier 3 branch and the new garage make the town bonus")
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
	game.end_session()
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


# ===========================================================================
# CABANG YANG BISA DIKUNJUNGI (GDD idle §20 no. 78)
# ===========================================================================

func _branch_visit() -> void:
	var s: SimulationRoot = _ready_shop(81, 4.2 * _d())
	run_hours(s, 0.3)
	var t0: float = 1.0e6
	var mixers1: int = s.equipment.placed_count(&"mixer")
	var oven1: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	var oven_lv: int = s.upgrades.station_level(oven1.iid)
	var recipes1: Array[StringName] = s.upgrades.unlocked_recipes()
	var staff1: int = s.staff.employed_ids().size()
	eq(s.franchise(t0), 2, "the franchise earns 2 stars")
	eq(s.prestige.run_index, 2, "Branch #2 opens")
	eq(s.prestige.branch_no, 2, "and you play it")
	var r1: Dictionary = s.prestige.record(1)
	check(not (r1.get("state", {}) as Dictionary).is_empty(), "Branch #1 keeps its shop")
	near(float(r1["left_unix"]), t0, 0.001, "and when it was left")
	check(float(r1["rate"]) > 0.0 and float(r1["cap"]) > 0.0 and float(r1["eff"]) > 0.0, "and its KR/s, cap and efficiency")
	eq(int(r1["stars"]), 2, "the stars go to the branch that opened the next one")
	var bal1: float = SaveManager.decode_money(((r1["state"] as Dictionary)["economy"] as Dictionary)["balance_kr"])
	check(bal1 > 0.0, "Branch #1 keeps its own wallet")
	near(s.economy.balance, DataRegistry.idlef("start_kr"), 0.5, "the new branch has its own fresh wallet")
	# Tabungan menunggu, seperti offline (GDD idle 9.2).
	var cap: float = float(r1["cap"])
	var expect: float = Money.round_cents(float(r1["rate"]) * minf(7200.0, cap) * float(r1["eff"]))
	near(PrestigeManager.waiting_kr(r1, t0 + 7200.0), expect, 0.01, "two hours away: KR/s x min(away, cap) x efficiency")
	eq(PrestigeManager.waiting_kr(r1, t0 + 30.0), 0.0, "nothing waits under a minute")
	near(PrestigeManager.waiting_kr(r1, t0 + 99999.0), Money.round_cents(float(r1["rate"]) * cap * float(r1["eff"])), 0.01, "and the cap holds")
	run_hours(s, 0.3)
	var bal2: float = s.economy.balance
	# Kunjungi Cabang #1 dua jam kemudian.
	var out: Dictionary = s.visit_branch(1, t0 + 7200.0)
	check(not out.is_empty(), "Branch #1 can be visited")
	eq(s.prestige.branch_no, 1, "you are in Branch #1")
	eq(s.world.location.tier, 3, "at its Tier 3 location")
	eq(s.equipment.placed_count(&"mixer"), mixers1, "with its mixers")
	eq(s.upgrades.station_level(oven1.iid), oven_lv, "its oven levels")
	eq(s.upgrades.unlocked_recipes(), recipes1, "its recipes")
	eq(s.staff.employed_ids().size(), staff1, "and its staff")
	near(s.economy.balance, bal1, 0.01, "and its own wallet")
	check(s.world.layout_valid(), "its layout is valid")
	var away: Dictionary = out.get("away", {})
	check(bool(away.get("popup", false)), "two hours of savings wait for Collect")
	near(float(away.get("amount", 0.0)), expect, 0.01, "the same amount the map promised")
	eq(int(s.offline.pending.get("branch", 0)), 1, "the Welcome Back popup is Branch #1's")
	var got: float = s.offline.collect()
	near(got, expect, 0.01, "Collect brings it in")
	near(s.economy.balance, bal1 + got, 1.0, "into Branch #1's wallet")
	eq(s.check_invariants(), "", "the ledger reconciles")
	var sold: float = s.statistics.get_stat("total_bread_sold")
	run_hours(s, 0.3)
	check(s.statistics.get_stat("total_bread_sold") > sold, "Branch #1 sells again")
	# Kembali ke Cabang #2 tiga menit kemudian: tabungan kecil langsung masuk.
	var out2: Dictionary = s.visit_branch(2, t0 + 7200.0 + 180.0)
	var away2: Dictionary = out2.get("away", {})
	eq(s.world.location.tier, 1, "Branch #2 is the Tier 1 garage again")
	check(not bool(away2.get("popup", true)) and float(away2.get("amount", 0.0)) > 0.0, "three minutes of savings come in without a popup")
	check(s.offline.pending.is_empty(), "nothing waits for Collect")
	near(s.economy.balance, bal2 + float(away2.get("amount", 0.0)), 0.01, "they go into Branch #2's wallet")
	eq(str((s.economy.ledger.back() as Dictionary).get("category", "")), "OFFLINE_EARNINGS", "as offline earnings")
	# Pergi dan kembali tanpa jeda: cabangnya persis seperti ditinggal.
	check(not s.visit_branch(1).is_empty(), "back to Branch #1")
	var stored2: Dictionary = json_copy(s.prestige.record(2)["state"])
	check(not s.visit_branch(2).is_empty(), "and to Branch #2 again")
	same_state(logical_state(json_copy(s._branch_state())), logical_state(stored2), "a branch comes back exactly as it was left")
	eq(s.visit_branch(2), {}, "visiting the branch you are in does nothing")
	eq(s.visit_branch(9), {}, "nor does a branch that does not exist")
	# Cabang berikutnya: syaratnya cabang terbaru (Tier 3), dari cabang mana pun.
	s.statistics.stats["alltime_earned_kr"] = 9.5 * _d()
	check(not s.visit_branch(1).is_empty(), "to Branch #1")
	eq(s.prestige.franchise_block(), &"tier", "the next branch waits for the newest one (Branch #2) to reach Tier 3")
	check(not s.visit_branch(2).is_empty(), "to Branch #2")
	jump_to_tier(s, 3)
	check(not s.visit_branch(1).is_empty(), "back to Branch #1")
	eq(s.prestige.franchise_block(), &"", "now it can open from Branch #1")
	eq(s.franchise(), 1, "for 1 new star")
	eq(s.prestige.run_index, 3, "Branch #3 opens")
	eq(int(s.prestige.record(2)["stars"]), 1, "the star goes to Branch #2, the newest one")
	eq(int(s.prestige.record(1)["stars"]), 2, "Branch #1 keeps its own")
	eq(int(s.prestige.record(2)["tier"]), 3, "Branch #2 is remembered at Tier 3")
	near(PrestigeManager.branch_cost_mult_for(3, s.prestige.stars), s.prestige.branch_cost_mult(), 1e-9, "location moves cost what Branch #3 costs")
	check(not s.visit_branch(2).is_empty(), "to Branch #2")
	near(s.prestige.branch_cost_mult(), PrestigeManager.branch_cost_mult_for(2, s.prestige.stars), 1e-9, "and what Branch #2 costs there")
	# Save dan load menyimpan setiap cabang.
	var saved: Dictionary = json_copy(s.capture_save())
	var s2: SimulationRoot = load_sim(saved)
	same_state(logical_state(s2.capture_save()), logical_state(saved), "every branch survives a save and load")
	check(not s2.visit_branch(1).is_empty(), "a loaded save can visit Branch #1")
	eq(s2.world.location.tier, 3, "which is still at Tier 3")
	free_sim(s2)
	# Cabang yang dijual sebelum aturan ini dibuka lagi sebagai toko awal.
	var old: Dictionary = json_copy(saved)
	var fr: Dictionary = old["franchise"]
	fr["branches"] = [{"number": 1, "tier": 4, "stars": 6, "earned": 610115.23, "rate": 161.07, "opened_day": 1, "sold_day": 2}]
	fr["run_index"] = 3
	fr["branch_no"] = 3
	var s3: SimulationRoot = load_sim(old)
	eq(s3.prestige.branches.size(), 2, "the old record and a placeholder for Branch #2")
	check(bool(s3.prestige.record(2).get("unknown", false)), "Branch #2 without a story is a placeholder")
	eq(PrestigeManager.waiting_kr(s3.prestige.record(1), t0 + 7200.0), 0.0, "a sold branch has nothing waiting")
	var start_kr: float = s3.prestige.start_kr()
	check(not s3.visit_branch(1, t0).is_empty(), "the sold Branch #1 can be visited")
	eq(s3.world.location.tier, 4, "it reopens at the tier it reached")
	eq(s3.equipment.placed_count(&"mixer"), 1, "as a fresh shop")
	near(s3.economy.balance, start_kr, 0.5, "with the starting balance")
	near(s3.statistics.get_stat("run_earned_kr"), 610115.23, 0.01, "its earnings stay in its story")
	eq(s3.prestige.run_stars, 6, "and so do its stars")
	check(s3.world.layout_valid(), "the rebuilt shop has a valid layout")
	run_hours(s3, 0.5)
	check(s3.statistics.get_stat("run_earned_kr") > 610115.23, "and it sells (%s)" % s3.statistics.get_stat("run_earned_kr"))
	check(not (s3.prestige.record(3).get("state", {}) as Dictionary).is_empty(), "the branch you came from is kept")
	check(not s3.visit_branch(2).is_empty(), "the placeholder Branch #2 reopens too")
	eq(s3.world.location.tier, DataRegistry.idlei("prestige.unlock_location_tier"), "at Tier 3")
	free_sim(s3)
	free_sim(s)


func _visit_flow() -> void:
	var game: GameRoot = await _boot("Visit Bakery")
	var sim: SimulationRoot = game.sim
	jump_to_tier(sim, 3)
	equip_shop(sim, 30)
	sim.statistics.stats["alltime_earned_kr"] = 4.2 * _d()
	var t0: float = 2.0e6
	sim.offline.now_override = t0
	game.do_franchise()
	await _wait(game, func() -> bool: return sim.prestige.branch_no == 2)
	check(game.playing and game.hud != null, "Branch #2 opens")
	near(float(sim.prestige.record(1).get("left_unix", 0.0)), t0, 0.001, "Branch #1 starts saving when it is left")
	game.modals.close_all()
	await _frames(2)
	# Dua jam kemudian: peta menyebut tabungan Cabang #1.
	sim.offline.now_override = t0 + 7200.0
	var waiting: float = PrestigeManager.waiting_kr(sim.prestige.record(1), t0 + 7200.0)
	check(waiting > 0.0, "two hours of savings wait in Branch #1")
	game.modals.open(&"town_map")
	await _frames(2)
	var map: TownMapScreen = game.modals.screen(&"town_map") as TownMapScreen
	check(map != null, "the map opens")
	if map == null:
		await _finish(game)
		return
	var b1: Button = map.content().find_child("Branch1", true, false) as Button
	var tag: Node = b1.find_child("Waiting", true, false) if b1 != null else null
	var tag_ok: bool = false
	if tag != null:
		for l: Node in tag.find_children("*", "Label", true, false):
			tag_ok = tag_ok or (l as Label).text == "+" + Tx.kr(waiting)
	check(tag_ok, "Branch #1's lot shows what is waiting")
	var b2: Button = map.content().find_child("Branch2", true, false) as Button
	check(b2 != null and b2.find_child("Waiting", true, false) == null, "the branch you are in has no tag")
	b1.pressed.emit()
	await _frames(3)
	var visit: Button = map.content().find_child("Visit", true, false) as Button
	check(visit != null and visit.get_global_rect().size.y >= 48.0, "Branch #1's story has a Visit button")
	if visit == null:
		await _finish(game)
		return
	visit.pressed.emit()
	await _wait(game, func() -> bool: return sim.prestige.branch_no == 1)
	game.playing = false
	eq(game.sim, sim, "the same simulation carries on")
	eq(sim.prestige.branch_no, 1, "you are in Branch #1")
	eq(sim.world.location.tier, 3, "at its Tier 3 location")
	check(game.world != null and is_instance_valid(game.world), "the world is rebuilt")
	var wb: UIScreen = game.modals.screen(&"welcome_back")
	check(wb != null, "the Welcome Back popup waits")
	if wb != null:
		var titled: bool = false
		for l2: Node in wb.find_children("*", "Label", true, false):
			titled = titled or (l2 as Label).text == Tx.t("ui_welcome_back_branch_title", {"number": 1})
		check(titled, "it is Branch #1's")
		var before: float = sim.economy.balance
		var collect: Button = wb.find_child("Collect", true, false) as Button
		collect.pressed.emit()
		await _frames(2)
		var last: Dictionary = sim.economy.ledger.back() if not sim.economy.ledger.is_empty() else {}
		check(str(last.get("category", "")) == "OFFLINE_EARNINGS" and absf(float(last.get("amount", 0.0)) - waiting) < 0.005,
			"Collect brings in what the map promised")
		check(sim.economy.balance > before, "into Branch #1's wallet")
	var toast_text: String = Tx.t("ui_branch_welcome", {"number": 1})
	var found: bool = false
	for c: Node in game.hud.find_child("Toasts", true, false).get_children():
		found = found or str(c.get_meta("text", "")) == toast_text
	check(found, "a toast greets Branch #1")
	var r: Dictionary = SaveManager.read_profile(&"profile_1")
	eq(int(((r.get("data", {}) as Dictionary).get("franchise", {}) as Dictionary).get("branch_no", 0)), 1, "the visit is saved")
	sim.offline.now_override = -1.0
	await _finish(game)


## Tunggu sampai `done` benar dan dunia cabangnya selesai dibangun.
func _wait(game: GameRoot, done: Callable) -> void:
	var waited: int = 0
	while waited < 600 and not (done.call() and game.playing and game.hud != null and game.loading_screen() == null):
		await runner.get_tree().process_frame
		waited += 1
	await _frames(3)
