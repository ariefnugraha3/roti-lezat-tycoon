extends TestSuite
## Boost & hadiah, dekorasi berbonus, pencapaian idle, onboarding, dan angka
## besar (GDD idle 7.5, 8.8, 11, 13).


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_BOOSTS", "name": "idle 11.1-11.2 Pak Lurah's coffee once per device day (x2 income for 15 real min, only while playing, saved), promotions cost KR/s x their minutes, raise arrivals or RotiFood for a while, run one at a time with a cooldown; income boosts extend instead of stacking; offline and the franchise ignore them", "fn": _boosts},
		{"id": "ACC_IDLE_DECOR_BONUS", "name": "idle 8.8, 10.5 every shop decoration gives its arrival/price/RotiFood bonus once per run, prices scale with the location tier, skins stay cosmetic; the franchise sends bonus decorations back to the inventory with the bonus off until bought again, while other decorations go back on the wall", "fn": _decor},
		{"id": "ACC_IDLE_ACHIEVEMENTS", "name": "idle 11.4 idle milestones (first sale, earn 1K-1T, tiers, Lv 100 station and recipe, all recipes, franchises, overflow) unlock once, grant their badge or decoration and a x2 income boost for 10 min, and survive the franchise", "fn": _achievements},
		{"id": "ACC_IDLE_ONBOARDING", "name": "idle 13 onboarding steps appear once on their triggers (welcome, first sale, first upgrade, tap boost, hire, recipe, location, franchise), close themselves when done or by Got it, never hold the economy, are saved, and stop after Skip or with hints off", "fn": _onboarding},
		{"id": "ACC_IDLE_BOOST_UI", "name": "idle 11, 12.1, 12.3 loading a profile on a new device day pours Pak Lurah's coffee with a toast; active boosts show their multiplier and time left under KR/s; the Upgrades sheet lists the promotions with their cost and starts them; the Decor shop shows each bonus; onboarding popups are Pak Lurah's and the upgrade hint pulses the oven chip", "fn": _ui},
		{"id": "ACC_IDLE_BIG_NUMBERS", "name": "idle 7.5 big numbers: 9,850 / 12.4K / 3.07M / 1.00aa / 1.00ba and scientific 1.24e15, KR/s with three significant digits, huge balances and costs stay exact or finite through saves, and the overflow guard ends at infinity without NaN", "fn": _big},
	]


func _quiet(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	ModelSample.no_boosts(s)
	return s


# ===========================================================================
# BOOST
# ===========================================================================

func _boosts() -> void:
	var s: SimulationRoot = _quiet(1101)
	var b: BoostManager = s.boosts
	var price0: float = s.recipe_price(&"recipe_plain_loaf")
	check(b.gift_available("2026-10-26"), "the coffee is ready on a new day")
	check(b.claim_gift("2026-10-26"), "and is given")
	near(b.income_now(), DataRegistry.idlef("boosts.daily_gift.mult"), 1e-9, "income x2")
	near(b.income_left, DataRegistry.idlef("boosts.daily_gift.minutes") * 60.0, 1e-6, "for 15 real minutes")
	near(s.recipe_price(&"recipe_plain_loaf"), price0 * 2.0, 1e-6, "prices double while it runs")
	check(not b.claim_gift("2026-10-26"), "only once per calendar day")
	check(b.gift_available("2026-10-27"), "the next day it is ready again")
	run_for(s, 120.0)
	near(b.income_left, 900.0 - DataRegistry.real_seconds(120.0), 0.05, "it counts down in real seconds of play")
	var left0: float = b.income_left
	b.grant_achievement_boost()
	near(b.income_left, left0 + DataRegistry.idlef("boosts.achievement.minutes") * 60.0, 0.01, "another income boost adds its time")
	near(b.income_now(), 2.0, 1e-9, "instead of stacking the multiplier")
	var saved: Dictionary = json_copy(s.capture_save())
	var s2: SimulationRoot = load_sim(saved)
	near(s2.boosts.income_left, b.income_left, 1e-6, "the rest is saved")
	eq(s2.boosts.last_gift_date, "2026-10-26", "and so is the coffee day")
	free_sim(s2)
	# Offline memakai KR/s tanpa boost.
	s.offline.now_override = 1000.0
	s.offline.mark_active()
	near(s.offline.rate_kr_per_s, s.idle_economy.rate(false), 1e-9, "offline earnings use the unboosted KR/s")
	check(s.idle_economy.rate(true) > s.idle_economy.rate(false) * 1.5, "the HUD KR/s shows the boost")
	b.income_left = 0.5
	run_for(s, 2.0)
	near(b.income_now(), 1.0, 1e-9, "the boost ends")
	near(s.recipe_price(&"recipe_plain_loaf"), price0, 1e-6, "and prices are back")
	# Promosi.
	s.debug_add_kr(1.0e6)
	var t: float = s.time.time_seconds
	var arr0: float = s.arrival_rate_per_hour(t)
	var rf0: float = s.rotifood_rate_per_hour(t)
	var flyer: Dictionary = BoostManager.promo(&"promo_flyer")
	near(b.promo_cost(&"promo_flyer"), Money.round_half_up(s.idle_economy.rate(false) * float(flyer["cost_income_minutes"]) * 60.0), 1.0,
		"Flyers cost 3 minutes of KR/s")
	var bal: float = s.economy.balance
	var cost: float = b.promo_cost(&"promo_flyer")
	check(b.start_promo(&"promo_flyer"), "Flyers start")
	near(bal - s.economy.balance, cost, 1.0, "for their cost")
	near(s.arrival_rate_per_hour(t), arr0 * float(flyer["arrival_mult"]), 1e-6, "customers x1.5")
	near(s.rotifood_rate_per_hour(t), rf0, 1e-6, "RotiFood unchanged")
	eq(b.promo_block(&"promo_radio"), &"running", "one promotion at a time")
	check(s.idle_economy.compute(true)["demand"] > s.idle_economy.compute(false)["demand"], "the boosted model sees the extra customers")
	run_for(s, float(flyer["minutes"]) * 60.0 * DataRegistry.sim_seconds_per_real_second() + 1.0)
	eq(b.promo_id, &"", "Flyers end after 5 real minutes")
	eq(b.promo_block(&"promo_flyer"), &"cooldown", "and cool down")
	near(b.cooldown_left(&"promo_flyer"), (float(flyer["cooldown_minutes"]) - float(flyer["minutes"])) * 60.0, 1.0,
		"the cooldown runs from the start")
	var vlog: Dictionary = BoostManager.promo(&"promo_food_vlogger")
	var t2: float = s.time.time_seconds
	var rf1: float = s.rotifood_rate_per_hour(t2)
	check(b.start_promo(&"promo_food_vlogger"), "the Food Vlogger can start meanwhile")
	near(s.rotifood_rate_per_hour(t2), rf1 * float(vlog["rotifood_mult"]), 1e-6, "RotiFood x2 too")
	# Waralaba mereset boost aktif, bukan tanggal kopi.
	b.claim_gift("2026-10-27")
	b.new_run()
	near(b.income_now(), 1.0, 1e-9, "a new branch has no running boost")
	eq(b.promo_id, &"", "nor a promotion")
	check(b.cooldowns.is_empty(), "nor cooldowns")
	check(not b.gift_available("2026-10-27"), "but today's coffee is still taken")
	free_sim(s)


# ===========================================================================
# DEKORASI
# ===========================================================================

func _decor() -> void:
	var s: SimulationRoot = _quiet(1102)
	var dm: DecorationManager = s.decoration
	var with_bonus: int = 0
	for x: Variant in DataRegistry.decorations():
		var d: MiscDefinitions.DecorationDefinition = x
		if d.source == &"shop" and d.placement_type != &"skin":
			check(d.has_bonus(), "%s carries a bonus" % d.id)
			with_bonus += 1
		elif d.placement_type == &"skin" or d.source == &"achievement":
			check(not d.has_bonus(), "%s is cosmetic" % d.id)
	check(with_bonus >= 8, "the shop sells bonus decorations")
	near(dm.price(&"decor_potted_plant"), DataRegistry.decoration(&"decor_potted_plant").price_kr, 1e-9, "Tier 1 prices are the catalog price")
	near(dm.bonus_mult(&"arrival"), 1.0, 1e-9, "no bonus before buying")
	s.debug_add_kr(1.0e6)
	var arr0: float = s.arrival_rate_per_hour(s.time.time_seconds)
	var demand0: float = s.idle_economy.compute(false)["demand"]
	var plant: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(&"decor_potted_plant")
	eq(dm.buy(&"decor_potted_plant"), &"", "buy a potted plant")
	near(dm.bonus_mult(&"arrival"), 1.0 + float(plant.bonus["value"]), 1e-9, "its arrival bonus is on")
	near(s.arrival_rate_per_hour(s.time.time_seconds), arr0 * (1.0 + float(plant.bonus["value"])), 1e-6, "more customers come")
	check(s.idle_economy.compute(false)["demand"] > demand0, "the KR/s model counts the extra customers")
	eq(dm.can_buy(&"decor_potted_plant"), &"active", "a second plant adds no second bonus")
	var board: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(&"decor_chalk_menu_board")
	var price0: float = s.recipe_price(&"recipe_plain_loaf")
	dm.buy(&"decor_chalk_menu_board")
	near(s.recipe_price(&"recipe_plain_loaf"), price0 * (1.0 + float(board.bonus["value"])) / 1.0, 1e-6, "the menu board raises prices")
	var photo: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(&"decor_family_photo_wall")
	var rf0: float = s.rotifood_rate_per_hour(s.time.time_seconds)
	dm.buy(&"decor_family_photo_wall")
	near(s.rotifood_rate_per_hour(s.time.time_seconds), rf0 * (1.0 + float(photo.bonus["value"])), 1e-6, "the family photo brings RotiFood orders")
	var mult_before: float = dm.bonus_mult(&"arrival")
	dm.buy(&"skin_storefront_striped_awning")
	near(dm.bonus_mult(&"arrival"), mult_before, 1e-9, "a storefront skin stays cosmetic")
	var saved: Dictionary = json_copy(s.capture_save())
	var s2: SimulationRoot = load_sim(saved)
	check(s2.decoration.is_bonus_active(&"decor_potted_plant") and s2.decoration.is_bonus_active(&"decor_chalk_menu_board"), "active bonuses are saved")
	free_sim(s2)
	# Harga ikut tier.
	jump_to_tier(s, 3)
	var mults: Array = DataRegistry.idle("decor.price_mult_by_tier")
	near(dm.price(&"decor_gingham_curtains"), DataRegistry.decoration(&"decor_gingham_curtains").price_kr * float(mults[2]), 1e-6,
		"Tier 3 prices are x%s" % mults[2])
	# Waralaba: dekorasi berbonus kembali ke inventaris, bonus mati sampai dibeli lagi.
	s.debug_add_kr(1.0e9)
	dm.buy(&"decor_gingham_curtains")
	dm.grant(&"badge_first_crumb")
	var sf: StringName = dm.store_floor()
	var curtains: int = _uid(dm, &"decor_gingham_curtains")
	var badge: int = _uid(dm, &"badge_first_crumb")
	eq(dm.place(badge, sf, Vector2i(-1, -1), 0), &"", "the badge hangs on wall spot 0")
	var free: Array[int] = dm.free_slots(&"wall", curtains)
	check(not free.is_empty(), "the curtains have a wall spot at Tier 3")
	if not free.is_empty():
		eq(dm.place(curtains, sf, Vector2i(-1, -1), free[0]), &"", "the curtains hang too")
	var owned_n: int = dm.owned.size()
	s.statistics.stats["alltime_earned_kr"] = 4.0e6
	eq(s.franchise(), 2, "franchise")
	eq(dm.owned.size(), owned_n, "every decoration is still owned")
	check(not bool(dm.item(curtains)["placed"]), "the bonus curtains wait in the inventory")
	near(dm.bonus_mult(&"arrival"), 1.0, 1e-9, "and no bonus is on in the new branch")
	near(dm.bonus_mult(&"price"), 1.0, 1e-9, "no price bonus either")
	if dm.cap(&"wall") > 0:
		check(bool(dm.item(badge)["placed"]), "the badge goes back on its wall spot")
	near(dm.price(&"decor_gingham_curtains"), DataRegistry.decoration(&"decor_gingham_curtains").price_kr, 1e-6, "back at Tier 1 prices")
	s.debug_add_kr(1.0e6)
	eq(dm.buy(&"decor_gingham_curtains"), &"", "buying the curtains again")
	eq(dm.owned.size(), owned_n, "adds no second copy")
	check(dm.is_bonus_active(&"decor_gingham_curtains"), "but turns their bonus back on")
	free_sim(s)


func _uid(dm: DecorationManager, id: StringName) -> int:
	for o: Dictionary in dm.owned:
		if StringName(str(o["deco_id"])) == id:
			return int(o["uid"])
	return -1


# ===========================================================================
# PENCAPAIAN
# ===========================================================================

func _achievements() -> void:
	var ids: Array[StringName] = []
	for x: Variant in DataRegistry.achievements():
		var a: MiscDefinitions.AchievementDefinition = x
		ids.append(a.id)
		check(DataRegistry.decoration(a.reward_id) != null, "%s has a reward" % a.id)
	for want: StringName in [&"ach_first_sale", &"ach_earn_1k", &"ach_earn_1m", &"ach_earn_1b", &"ach_earn_1t", &"ach_station_100",
			&"ach_recipe_100", &"ach_all_recipes", &"ach_tier5", &"ach_first_franchise", &"ach_10_franchises"]:
		check(ids.has(want), "%s exists (GDD idle 11.4)" % want)
	var s: SimulationRoot = new_sim(1103)
	s.tutorial.skip()
	var am: AchievementManager = s.achievements
	var t: float = 0.0
	while s.statistics.get_stat("total_bread_sold") < 1.0 and t < 600.0:
		s.step(s.tick_seconds)
		t += s.tick_seconds
	check(am.is_unlocked(&"ach_first_sale"), "the first sale unlocks First Crumb")
	check(s.decoration.owns(&"badge_first_crumb"), "and grants its badge")
	near(s.boosts.income_now(), DataRegistry.idlef("boosts.achievement.mult"), 1e-9, "and a x2 income boost")
	check(s.boosts.income_left > DataRegistry.idlef("boosts.achievement.minutes") * 60.0 - 1.0, "for 10 minutes")
	var left: float = s.boosts.income_left
	am.check_all()
	near(s.boosts.income_left, left, 1e-6, "an achievement rewards only once")
	s.statistics.note_income(1.0e6)
	check(am.is_unlocked(&"ach_earn_1k") and am.is_unlocked(&"ach_earn_1m"), "earning 1M unlocks the 1K and 1M milestones")
	check(not am.is_unlocked(&"ach_earn_1b"), "but not 1B")
	jump_to_tier(s, 3)
	check(am.is_unlocked(&"ach_tier2") and am.is_unlocked(&"ach_tier3"), "moving up unlocks the tier milestones")
	s.debug_add_kr(1.0e30)
	var rid: StringName = &"recipe_plain_loaf"
	s.upgrades.buy_offer(s.upgrades.offer(&"recipe", rid), 99)
	check(am.is_unlocked(&"ach_recipe_100"), "a Lv 100 recipe unlocks Signature Recipe")
	for r: RecipeDefinition in DataRegistry.recipes():
		if not s.upgrades.is_unlocked(r.id):
			s.upgrades.recipe_levels[r.id] = 1
	s.upgrades.unlock_recipe(&"recipe_plain_loaf")
	am.check_all()
	check(am.is_unlocked(&"ach_all_recipes"), "every recipe unlocked: Bread Encyclopedia")
	jump_to_tier(s, 4)
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	if s.upgrades.level_cap() >= 100:
		s.upgrades.buy(&"station", oven.iid, &"max")
		check(am.is_unlocked(&"ach_station_100"), "a Lv 100 station unlocks Tuned to Perfection")
	s.statistics.stats["alltime_earned_kr"] = 4.0e6
	var unlocked_n: int = am.unlocked.size()
	s.franchise()
	check(am.is_unlocked(&"ach_first_franchise"), "the first franchise unlocks First Franchise")
	check(am.unlocked.size() >= unlocked_n + 1, "earlier achievements survive the franchise")
	near(s.boosts.income_now(), 2.0, 1e-9, "the new branch starts with that achievement's boost")
	s.statistics.add(&"franchise_count", 9)
	check(am.is_unlocked(&"ach_10_franchises"), "the tenth franchise unlocks Franchise Empire")
	s.economy.credit(1.0e308, &"GIFT", &"test")
	s.economy.credit(1.0e308, &"GIFT", &"test")
	check(s.economy.overflowed and am.is_unlocked(&"ach_overflow"), "the overflow guard unlocks Beyond Accounting")
	free_sim(s)


# ===========================================================================
# ONBOARDING
# ===========================================================================

func _key(s: SimulationRoot) -> String:
	return str(s.tutorial.prompt.get("key", ""))


func _onboarding() -> void:
	var hints_before: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", true)
	var s: SimulationRoot = new_sim(1104)
	var tm: TutorialManager = s.tutorial
	run_for(s, 1.0)
	eq(_key(s), "onb_welcome", "the welcome comes first")
	eq(str(tm.prompt.get("style", "")), "popup", "as Pak Lurah's popup")
	# Ekonomi tidak pernah ditahan: prompt dibiarkan terbuka, toko tetap jualan.
	var t: float = 0.0
	while s.statistics.get_stat("total_bread_sold") < 1.0 and t < 600.0:
		s.step(s.tick_seconds)
		t += s.tick_seconds
	check(s.statistics.get_stat("total_bread_sold") >= 1.0, "bread sells while a prompt waits")
	run_for(s, 1.0)
	eq(_key(s), "onb_welcome", "prompts wait their turn")
	tm.dismiss()
	eq(_key(s), "onb_first_sale", "then the first sale")
	eq(str(tm.prompt.get("target", "")), "cash", "spotlights KR and KR/s")
	eq(str(tm.prompt.get("style", "")), "spotlight", "as a spotlight")
	while _key(s) != "" and _key(s) != "onb_first_upgrade":
		tm.dismiss()
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	s.debug_add_kr(1.0e4)
	run_for(s, 1.0)
	while _key(s) != "" and _key(s) != "onb_first_upgrade":
		tm.dismiss()
	eq(_key(s), "onb_first_upgrade", "an affordable oven upgrade is pointed out")
	eq(str(tm.prompt.get("target", "")), "chip_%d" % oven.iid, "on the oven's level chip")
	s.upgrades.buy(&"station", oven.iid, &"x1")
	run_for(s, 1.0)
	check(_key(s) != "onb_first_upgrade", "buying it closes the hint by itself")
	check(tm.has_done("onb_tap_boost"), "and brings the tap tip")
	check(tm.has_done("onb_hire"), "affording the first hire brings the Staff hint")
	s.debug_add_kr(1.0e7)
	run_for(s, 1.0)
	check(tm.has_done("onb_recipe"), "affording a recipe brings the Menu hint")
	check(tm.has_done("onb_location"), "affording Tier 2 brings the Shop hint")
	check(not tm.has_done("onb_franchise"), "no franchise hint before Tier 3")
	var q: Array[String] = []
	while _key(s) != "":
		q.append(_key(s))
		eq(str(tm.prompt.get("style", "")), "hint", "%s is a hint above the tab bar" % _key(s))
		tm.dismiss()
	for k: String in q:
		check(TutorialManager.STEPS.find(k) >= 0, "%s is a GDD idle 13 step" % k)
	var saved: Dictionary = json_copy(s.capture_save())
	var s2: SimulationRoot = load_sim(saved)
	check(s2.tutorial.has_done("onb_recipe") and not s2.tutorial.has_done("onb_franchise"), "the steps shown are saved")
	free_sim(s2)
	jump_to_tier(s, 3)
	s.statistics.stats["alltime_earned_kr"] = 4.0e6
	run_for(s, 1.0)
	eq(_key(s), "onb_franchise", "franchising pays: the Franchise hint")
	eq(str(tm.prompt.get("target", "")), "tab_franchise", "on the Franchise tab")
	tm.dismiss()
	free_sim(s)
	# Skip dan petunjuk mati.
	var k2: SimulationRoot = new_sim(1105)
	k2.tutorial.skip()
	run_for(k2, 60.0)
	eq(k2.tutorial.prompt, {}, "after Skip nothing shows")
	check(not k2.tutorial.has_done("onb_welcome"), "and nothing is triggered")
	free_sim(k2)
	SettingsManager.set_value("tutorial_hints", false)
	var h: SimulationRoot = new_sim(1106)
	run_for(h, 2.0)
	check(h.tutorial.has_done("onb_welcome"), "with hints off the step still counts")
	eq(h.tutorial.prompt, {}, "but nothing is shown")
	free_sim(h)
	SettingsManager.set_value("tutorial_hints", hints_before)


# ===========================================================================
# ANGKA BESAR
# ===========================================================================

func _big() -> void:
	var cases: Array = [[0.0, "0"], [9850.0, "9,850"], [9999.4, "9,999"], [12400.0, "12.4K"], [999500.0, "1.00M"], [3.07e6, "3.07M"],
		[1.0e9, "1.00B"], [1.0e12, "1.00T"], [1.0e15, "1.00aa"], [1.18e17, "118aa"], [1.0e18, "1.00ab"], [1.0e93, "1.00ba"]]
	for c: Array in cases:
		eq(Tx.big(float(c[0]), 0), str(c[1]), "%s reads %s" % [c[0], c[1]])
	eq(Tx.big(1.24e15, 1), "1.24e15", "scientific format")
	eq(Tx.big(INF, 0), "∞", "infinity has its own sign")
	eq(Tx.big(-12400.0, 0), "-12.4K", "negative numbers keep the format")
	for r: Array in [[0.364, "0.36"], [4.25, "4.25"], [28.44, "28.4"], [150.0, "150"], [12400.0, "12.4K"]]:
		eq(Tx.rate(float(r[0])), str(r[1]), "KR/s %s reads %s" % [r[0], r[1]])
	eq(Tx.kr(3.07e6), "3.07M KR", "KR amounts use the same format")
	# Save menyimpan saldo besar persis.
	var s: SimulationRoot = _quiet(1107)
	s.economy.balance = 1.2345678901234e100
	var s2: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(s2.economy.balance, 1.2345678901234e100, "a 1.23e100 balance comes back exactly")
	free_sim(s2)
	# Biaya sangat tinggi tetap terbatas atau ditolak, tidak pernah NaN.
	var c1: float = UpgradeManager.series_cost(50.0, 1.15, 4000, 10)
	check(not is_nan(c1) and c1 > 0.0, "a cost 4,000 levels up is a number")
	var n: int = UpgradeManager.max_affordable(50.0, 1.15, 0, 1.0e300, 100000)
	check(n > 0 and n < 100000, "Max with 1e300 KR buys a finite number of levels (%d)" % n)
	check(PrestigeManager.stars_for(1.0e300) > 0, "stars from 1e300 KR are finite")
	s.offline.rate_kr_per_s = 1.0e290
	var e: Dictionary = s.offline.earnings_for(7200.0)
	check(not is_nan(float(e["amount"])) and not is_inf(float(e["amount"])), "offline earnings at 1e290 KR/s stay finite")
	s.economy.balance = 1.0e308
	s.economy.credit(1.0e308, &"GIFT", &"test")
	check(s.economy.overflowed, "passing the float limit enters the overflow guard")
	check(is_inf(s.economy.balance) and not is_nan(s.economy.balance), "the balance is infinity, never NaN")
	eq(Tx.kr(s.economy.balance), "∞ KR", "and reads as ∞ KR")
	free_sim(s)


# ===========================================================================
# UI
# ===========================================================================

func _boot(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_idle_meta"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", label)
	await runner.get_tree().process_frame
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


func _toast(game: GameRoot, text: String) -> bool:
	for c: Node in game.hud.find_child("Toasts", true, false).get_children():
		if str(c.get_meta("text", "")) == text:
			return true
	return false


func _ui() -> void:
	var hints_before: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", true)
	BoostManager.date_override = "2030-01-01"
	var game: GameRoot = await _boot("Boost Bakery")
	var sim: SimulationRoot = game.sim
	check(sim.boosts.income_left > 0.0, "a new device day pours the coffee")
	check(_toast(game, Tx.t("ui_daily_gift", {"mult": "2", "minutes": 15})), "with a toast")
	game.check_daily_gift()
	near(sim.boosts.income_left, 900.0, 1.0, "only once that day")
	# Onboarding pertama: sapaan Pak Lurah.
	game.playing = true
	var waited: int = 0
	while waited < 120 and not game.modals.is_open(&"tutorial"):
		await runner.get_tree().process_frame
		waited += 1
	check(game.modals.is_open(&"tutorial"), "the welcome popup opens")
	var tip: UIScreen = null
	for n: Node in game.modals.get_children():
		if n is TutorialModal:
			tip = n
	check(tip != null and tip.find_child("Lurah", true, false) is LurahPortrait, "Pak Lurah says it")
	game.playing = false
	sim.tutorial.skip()
	game.modals.close_all()
	PauseManager.clear_all()
	# Chip boost di HUD.
	game.hud._refresh_all()
	var chip: Control = game.hud.find_child("IncomeBoost", true, false) as Control
	check(chip != null and chip.visible, "the income boost chip shows under KR/s")
	var val: Label = chip.get_meta("value") as Label if chip != null else null
	check(val != null and val.text == Tx.t("ui_boost_left", {"mult": "2", "time": Tx.timer(sim.boosts.income_left)}), "with x2 and the time left")
	# Promosi di Upgrades.
	sim.debug_add_kr(1.0e7)
	check(game.hud.has_affordable(&"upgrades"), "an affordable promotion lights the Upgrades dot")
	game.hud.open_tab(&"upgrades")
	await _frames(2)
	var sheet: UpgradesScreen = game.modals.top() as UpgradesScreen
	var row: Node = sheet.content().find_child("Promo_promo_flyer", true, false)
	var start: Button = row.find_child("Start", true, false) as Button if row != null else null
	check(start != null and start.visible and not start.disabled, "Flyers can start from the Upgrades sheet")
	if start != null:
		eq(start.text, Tx.t("ui_promo_start", {"price": Tx.kr(sim.boosts.promo_cost(&"promo_flyer"))}), "the button says the cost")
		start.pressed.emit()
	await _frames(2)
	eq(sim.boosts.promo_id, &"promo_flyer", "the promotion runs")
	var st: Label = row.find_child("State", true, false) as Label
	check(st != null and st.visible and st.text == Tx.t("ui_promo_running", {"time": Tx.timer(sim.boosts.promo_left)}), "its row shows the time left")
	var radio: Button = sheet.content().find_child("Promo_promo_radio", true, false).find_child("Start", true, false) as Button
	check(radio.disabled, "another promotion waits")
	game.hud._refresh_all()
	var pchip: Control = game.hud.find_child("PromoBoost", true, false) as Control
	check(pchip != null and pchip.visible, "the promotion chip shows in the HUD")
	game.modals.close_all()
	# Toko dekorasi.
	var deco: DecorationScreen = game.modals.open(&"decoration") as DecorationScreen
	await _frames(2)
	deco._set_tab(DecorationScreen.TAB_SHOP)
	await _frames(2)
	var card: Button = deco.find_child("Shop_decor_potted_plant", true, false) as Button
	var plant: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(&"decor_potted_plant")
	check(card != null and card.tooltip_text != "", "the shop lists the potted plant")
	var want: String = DecorationScreen.shop_sub(sim, plant)
	var found: bool = false
	if card != null:
		for l: Node in card.find_children("*", "Label", true, false):
			if (l as Label).text == want:
				found = true
	check(found and want.begins_with(Tx.t("ui_decor_bonus_arrival", {"percent": Tx.percent(float(plant.bonus["value"]))})), "its card shows the bonus and price")
	game.modals.close_all()
	await _frames(1)
	# Petunjuk upgrade pertama berdenyut di chip oven.
	var oven: EquipmentInstance = sim.equipment.placed_list(&"oven")[0]
	game.hud.show_tutorial_hint("onb_first_upgrade", StringName("chip_%d" % oven.iid))
	var oc: Button = game.hud.level_chips.chip(&"station", oven.iid)
	check(oc != null and oc.get_node_or_null(TutorialPulse.NODE_NAME) is TutorialPulse, "the oven chip pulses")
	game.hud.show_tutorial_hint("", &"")
	BoostManager.date_override = ""
	SettingsManager.set_value("tutorial_hints", hints_before)
	await _finish(game)
