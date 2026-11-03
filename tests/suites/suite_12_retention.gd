extends TestSuite
## Fitur retensi dan berbagi (GDD idle 21): craving harian dan selera lingkungan,
## misi ringan harian, dan kalender cap.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_CRAVING", "name": "idle 21.1 from day 2 the town craves one recipe the kitchen can make (seeded, never yesterday's); while it is unlocked it sells for 1.2x the best bread (itself included), Auto switches to it, offline ignores it, and each location has two favourites at 1.25x", "fn": _craving},
		{"id": "ACC_IDLE_CRAVING_UI", "name": "idle 21.1 the HUD craving chip shows the bread, its name and a lock until unlocked, and opens the Menu, where a card explains the craving and the favourites and rows carry Craving / Local favorite pills", "fn": _craving_ui},
		{"id": "ACC_IDLE_GOALS", "name": "idle 21.2 three seeded goals a day sized from the shop, progress counted from the stat at issue, Claim pays the fixed reward once (not as income), finished goals survive midnight, a franchise issues a new set, save/load and old saves", "fn": _goals},
		{"id": "ACC_IDLE_CALENDAR", "name": "idle 21.3 one stamp per device date from the day after the first visit, missed days never reset, seven rewards (KR, x2 boosts, a calendar decoration on day 7, then KR only), kept across saves", "fn": _calendar},
		{"id": "ACC_IDLE_GOALS_UI", "name": "idle 21.2-21.3 the HUD Goals button lights up and toasts for a finished goal, the Goals sheet claims it, and a new device date opens the Daily Stamps popup that stamps the card", "fn": _goals_ui},
	]


## Lewati pukul 00:00: jam ke 23:59:59, lalu beberapa tick.
static func _cross_midnight(s: SimulationRoot) -> void:
	s.debug_set_time(86400.0 - 1.0)
	for i in int(2.0 / s.tick_seconds):
		s.step(s.tick_seconds)


func _craving() -> void:
	CravingManager.enabled = true
	var s: SimulationRoot = new_sim(4401)
	s.tutorial.skip()
	eq(s.cravings.today(), &"", "no craving on day 1")
	var toasts: Array = []
	var catch_toast: Callable = func(_p: int, key: String, params: Dictionary, _i: StringName) -> void:
		if key == "ui_craving_today":
			toasts.append(params)
	EventBus.notify.connect(catch_toast)
	_cross_midnight(s)
	EventBus.notify.disconnect(catch_toast)
	var c1: StringName = s.cravings.today()
	check(c1 != &"", "day 2 brings a craving")
	var r1: RecipeDefinition = DataRegistry.recipe(c1)
	check(r1 != null and s.production.owns_equipment_for(r1), "the craving is a recipe the kitchen has the tools for")
	eq(toasts.size(), 1, "a toast announces the craving")
	# Seed yang sama memberi craving yang sama.
	var t: SimulationRoot = new_sim(4401, &"profile_twin")
	_cross_midnight(t)
	eq(t.cravings.today(), c1, "the same seed craves the same recipe")
	free_sim(t)
	# Harga: belum terbuka = tanpa efek; terbuka = max(2x sendiri, 1.25x terbaik).
	var plain: float = s.plain_price(c1)
	if not s.upgrades.is_unlocked(c1):
		near(s.recipe_price(c1), plain * s.boost_income_mult(), 1e-6, "a locked craving changes nothing")
		s.debug_add_kr(UpgradeManager.unlock_cost(r1) + 10.0)
		check(s.upgrades.unlock_recipe(c1), "the craving can be unlocked")
		plain = s.plain_price(c1)
	var best: float = s.best_plain_price()
	check(best >= plain, "the best bread counts the craving itself")
	near(s.recipe_price(c1), best * DataRegistry.idlef("craving.best_mult") * s.boost_income_mult(), 1e-6, "the craving sells for 1.2x the best bread")
	near(s.recipe_price(c1, false), plain, 1e-6, "offline and the model without boosts ignore the craving")
	check(s.recipe_price(c1) > s.recipe_price(&"recipe_plain_loaf") or c1 == &"recipe_plain_loaf", "the craving beats the other breads")
	eq(s.auto_recipe(), c1, "Auto switches to the craving")
	# Roti lain yang levelnya jauh lebih tinggi: craving mengikuti 1.25x roti terbaik.
	var other: StringName = &"recipe_plain_loaf" if c1 != &"recipe_plain_loaf" else &"recipe_sugar_donut"
	if not s.upgrades.is_unlocked(other):
		s.debug_add_kr(UpgradeManager.unlock_cost(DataRegistry.recipe(other)) + 10.0)
		s.upgrades.unlock_recipe(other)
	s.upgrades.recipe_levels[other] = 60
	s.idle_economy.invalidate()
	var best2: float = s.best_plain_price()
	check(best2 > s.plain_price(c1) * 2.0, "another bread is far better levelled")
	near(s.recipe_price(c1), best2 * DataRegistry.idlef("craving.best_mult") * s.boost_income_mult(), 1e-6, "the craving sells for 1.2x a far better levelled bread")
	eq(s.auto_recipe(), c1, "Auto still prefers the craving")
	s.upgrades.recipe_levels[other] = 1
	s.idle_economy.invalidate()
	# Undian berikutnya tidak mengulang kemarin.
	_cross_midnight(s)
	var c2: StringName = s.cravings.today()
	check(c2 != &"" and c2 != c1, "the next craving differs from yesterday's (%s, %s)" % [c1, c2])
	eq(s.cravings.previous, c1, "yesterday's craving is remembered")
	# Satu bulan in-game: craving tidak pernah sama dua hari berturut-turut.
	var w: SimulationRoot = new_sim(9917, &"profile_month")
	var last: StringName = &""
	var repeats: int = 0
	var seen: Dictionary = {}
	for day_i in 30:
		_cross_midnight(w)
		var cw: StringName = w.cravings.today()
		if cw == last:
			repeats += 1
		seen[cw] = true
		last = cw
	eq(repeats, 0, "no craving repeats the day before over 30 days")
	check(seen.size() >= 3, "a month brings several different cravings")
	free_sim(w)
	# Save / load.
	var save: Dictionary = s.capture_save()
	var u: SimulationRoot = SimulationRoot.new()
	runner.add_child(u)
	u.load_from_save(save)
	eq(u.cravings.today(), c2, "the craving survives save and load")
	free_sim(u)
	var old: Dictionary = save.duplicate(true)
	old.erase("cravings")
	var v: SimulationRoot = SimulationRoot.new()
	runner.add_child(v)
	v.load_from_save(old)
	check(v.cravings.today() != &"" and v.cravings.day == v.time.day, "a save from before cravings gets today's craving on load")
	free_sim(v)
	# Selera lingkungan.
	var fav_mult: float = DataRegistry.idlef("craving.favorite_mult")
	var favs: Array[StringName] = s.cravings.favorites()
	eq(favs, [&"recipe_plain_fried_bread", &"recipe_sugar_donut"], "Tier 1 favourites")
	var donut: RecipeDefinition = DataRegistry.recipe(&"recipe_sugar_donut")
	near(s.plain_price(&"recipe_sugar_donut"), donut.base_sell_price_kr * s.upgrades.recipe_price_mult(&"recipe_sugar_donut") * fav_mult
		* s.decoration.bonus_mult(&"price") * s.prestige.income_mult(), 1e-6, "a favourite sells for 1.25x")
	jump_to_tier(s, 2)
	check(not s.cravings.is_favorite(&"recipe_sugar_donut") and s.cravings.is_favorite(&"recipe_chocolate_bread"), "favourites follow the location")
	# Craving mati: harga biasa.
	CravingManager.enabled = false
	near(s.recipe_price(c2), s.plain_price(c2) * s.boost_income_mult(), 1e-6, "with cravings off prices are plain")
	free_sim(s)


func _craving_ui() -> void:
	CravingManager.enabled = true
	SaveManager.dir = "user://test_saves_retention"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Retention Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
	var sim: SimulationRoot = game.sim
	game.hud._refresh_all()
	check(not game.hud.craving_chip().visible, "no craving chip on day 1")
	_cross_midnight(sim)
	game.hud._refresh_all()
	await _frames(2)
	var rid: StringName = sim.cravings.today()
	var chip: Button = game.hud.craving_chip()
	check(chip.visible, "the craving chip shows from day 2")
	var texts: Array = []
	for n: Node in chip.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	check(texts.has(Tx.t("ui_craving_chip", {"recipe": Tx.recipe_name(rid)})), "the chip names the craving")
	var locked_shown: bool = false
	for n2: Node in chip.find_children("*", "IconCanvas", true, false):
		if (n2 as IconCanvas).icon_name == "lock":
			locked_shown = (n2 as IconCanvas).visible
	eq(locked_shown, not sim.upgrades.is_unlocked(rid), "the lock shows while the craving is locked")
	check(chip.get_global_rect().size.y >= 48.0, "the chip is a 48 px touch target")
	chip.pressed.emit()
	await _frames(2)
	var menu: MenuScreen = game.modals.screen(&"menu") as MenuScreen
	check(menu != null, "the chip opens the Menu")
	if menu != null:
		var card: Node = menu.content().find_child("CravingCard", true, false)
		check(card != null, "the Menu explains today's craving")
		var title: Label = card.find_child("CravingTitle", true, false) as Label if card != null else null
		eq(title.text if title != null else "", Tx.t("ui_craving_card_title", {"recipe": Tx.recipe_name(rid)}), "the card names the craving")
		check(card != null and card.find_child("Favorites", true, false) != null, "the card lists the local favourites")
		var row: Node = menu.content().find_child("Recipe_" + String(rid), true, false)
		check(row != null and _has_pill(row, Tx.t("ui_craving_pill")), "the craving row has a Craving pill")
		var fav_row: Node = menu.content().find_child("Recipe_recipe_sugar_donut", true, false)
		check(fav_row != null and _has_pill(fav_row, Tx.t("ui_favorite_pill")), "a favourite row has a Local favorite pill")
		var plain_row: Node = menu.content().find_child("Recipe_recipe_plain_loaf", true, false)
		check(plain_row != null and (rid == &"recipe_plain_loaf" or not _has_pill(plain_row, Tx.t("ui_craving_pill"))), "other rows have no Craving pill")
	game.modals.close_all()
	game.playing = true
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


func _goals() -> void:
	var s: SimulationRoot = new_sim(5501)
	s.tutorial.skip()
	var g: GoalManager = s.goals
	check(g.goals.is_empty() and not g.started(), "no goals on day 1")
	_cross_midnight(s)
	eq(g.goals.size(), DataRegistry.idlei("goals.per_day"), "day 2 brings the first goals")
	var ids: Dictionary = {}
	for x: Dictionary in g.goals:
		ids[x["id"]] = true
		check(float(x["target"]) > 0.0 and float(x["reward"]) > 0.0, "%s has a target and a reward" % x["id"])
		eq(g.progress(x), 0.0, "%s starts at zero" % x["id"])
	eq(ids.size(), g.goals.size(), "the goals are all different")
	eq(g.day, s.time.day, "the set belongs to today")
	var t: SimulationRoot = new_sim(5501, &"profile_twin")
	t.tutorial.skip()
	_cross_midnight(t)
	same_state({"g": t.goals.capture()}, {"g": g.capture()}, "the same seed issues the same goals")
	free_sim(t)
	# Angka enak dibaca.
	eq(GoalManager.nice(1234.0), 1200.0, "nice rounds to two digits")
	eq(GoalManager.nice(7.2), 8.0, "small targets round up")
	eq(GoalManager.nice(57.3), 57.0, "two-digit targets stay whole")
	# Kemajuan dan klaim.
	var first: Dictionary = g.goals[0]
	var stat: StringName = StringName(str(first["stat"]))
	var target: float = float(first["target"])
	s.statistics.add(stat, target - 1.0)
	check(not g.is_done(first) and not g.claim(0), "an unfinished goal cannot be claimed")
	s.statistics.add(stat, 5.0)
	eq(g.progress(first), target, "progress stops at the target")
	eq(g.claimable(), 1, "one goal waits for Claim")
	var before: float = s.economy.balance
	var earned: float = s.statistics.get_stat("run_earned_kr")
	check(g.claim(0), "Claim works")
	near(s.economy.balance - before, float(first["reward"]), 0.001, "Claim pays the fixed reward")
	eq(s.statistics.get_stat("run_earned_kr"), earned, "rewards are not income (no extra stars)")
	check(not g.claim(0), "a goal pays once")
	eq(s.statistics.get_stat("goals_completed"), 1.0, "goals completed are counted")
	# Level yang dibeli dihitung.
	var lv: float = s.statistics.get_stat("levels_bought")
	s.debug_add_kr(1.0e6)
	var e: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	check(s.upgrades.buy_offer(s.upgrades.offer(&"station", e.iid), 3), "three oven levels")
	eq(s.statistics.get_stat("levels_bought"), lv + 3.0, "levels bought are counted")
	# Tengah malam: selesai-belum-diklaim tetap, sisanya diganti.
	var second: Dictionary = g.goals[1]
	s.statistics.add(StringName(str(second["stat"])), float(second["target"]))
	var kept_id: String = str(second["id"])
	var old_third: Dictionary = g.goals[2].duplicate()
	s.statistics.add(StringName(str(old_third["stat"])), maxf(1.0, float(old_third["target"]) - 1.0))
	check(not g.is_done(g.goals[2]) and g.progress(g.goals[2]) > 0.0, "the third goal is half way")
	_cross_midnight(s)
	eq(g.day, s.time.day, "midnight issues a new set")
	eq(g.goals.size(), DataRegistry.idlei("goals.per_day"), "still three goals")
	var kept: Array = g.goals.filter(func(x: Dictionary) -> bool: return str(x["id"]) == kept_id)
	check(kept.size() == 1 and g.is_done(kept[0]) and not bool(kept[0]["claimed"]), "a finished goal waits past midnight")
	var claimed_left: bool = false
	for x2: Dictionary in g.goals:
		if bool(x2["claimed"]):
			claimed_left = true
	check(not claimed_left, "claimed goals make room for new ones")
	var stale: bool = false
	for x3: Dictionary in g.goals:
		if str(x3["id"]) == str(old_third["id"]) and g.progress(x3) > 0.0:
			stale = true
	check(not stale, "unfinished goals are replaced (a redrawn template starts again)")
	# Save / load.
	var save: Dictionary = s.capture_save()
	var u: SimulationRoot = load_sim(json_copy(save))
	same_state({"g": u.goals.capture()}, {"g": g.capture()}, "goals survive save and load")
	free_sim(u)
	var old: Dictionary = json_copy(save)
	old.erase("goals")
	var v: SimulationRoot = load_sim(old)
	eq(v.goals.goals.size(), DataRegistry.idlei("goals.per_day"), "a save from before goals gets today's set")
	free_sim(v)
	# Waralaba: set baru dari statistik sekarang.
	g.new_run()
	eq(g.goals.size(), DataRegistry.idlei("goals.per_day"), "a new branch gets a new set")
	for x4: Dictionary in g.goals:
		eq(g.progress(x4), 0.0, "%s starts at zero for the new branch" % x4["id"])
	free_sim(s)


## Tanggal perangkat palsu ke-`n` (hari 1 = 2030-01-01).
static func _date(n: int) -> String:
	return Time.get_date_string_from_unix_time(Time.get_unix_time_from_datetime_string("2030-01-01T00:00:00") + (n - 1) * 86400)


func _calendar() -> void:
	var s: SimulationRoot = new_sim(5502)
	s.tutorial.skip()
	var c: CalendarManager = s.calendar
	check(not c.available(_date(1)), "no stamp before the first visit")
	c.note_date(_date(1))
	eq(c.first_date, "2030-01-01", "the first visit starts the card")
	check(not c.available(_date(1)) and c.claim(_date(1)).is_empty(), "no stamp on the first day")
	c.note_date(_date(2))
	eq(c.first_date, "2030-01-01", "the start date stays")
	check(c.available(_date(2)), "the next date has a stamp")
	var want: Dictionary = c.reward(0)
	var before: float = s.economy.balance
	var earned: float = s.statistics.get_stat("run_earned_kr")
	var got: Dictionary = c.claim(_date(2))
	near(float(got.get("kr", 0.0)), float(want["kr"]), 0.001, "stamp 1 gives its KR")
	near(s.economy.balance - before, float(want["kr"]), 0.001, "the KR arrives")
	eq(s.statistics.get_stat("run_earned_kr"), earned, "stamps are not income")
	check(not c.available(_date(2)) and c.claim(_date(2)).is_empty(), "one stamp per date")
	# Melewatkan hari tidak mereset.
	check(not c.claim(_date(9)).is_empty(), "a week later the card continues")
	eq(c.stamps, 2, "two stamps")
	eq(c.next_index(), 2, "no reset after a missed week")
	var r3: Dictionary = c.claim(_date(10))
	check(float(r3.get("boost_minutes", 0.0)) > 0.0 and s.boosts.income_left > 0.0, "stamp 3 starts an income boost")
	near(s.boosts.income_mult, DataRegistry.idlef("calendar.boost_mult"), 0.001, "a x2 boost")
	var day: int = 11
	var decors: Array[StringName] = []
	for cycle in 4:
		while c.next_index() != 6:
			check(not c.claim(_date(day)).is_empty(), "stamp %d" % (c.stamps + 1))
			day += 1
		var r7: Dictionary = c.claim(_date(day))
		day += 1
		decors.append(StringName(r7.get("decor", &"")))
		check(float(r7.get("kr", 0.0)) > 0.0, "stamp 7 also gives KR")
	eq(decors, [&"decor_stamp_card", &"decor_golden_croissant", &"decor_bunting_garland", &""], "each week gives the next calendar decoration, then KR only")
	for did: StringName in [&"decor_stamp_card", &"decor_golden_croissant", &"decor_bunting_garland"]:
		check(s.decoration.owns(did), "%s is owned" % did)
		var m: Node3D = DecorFactory.build(did)
		var tris: int = 0
		for mi: Node in m.find_children("*", "MeshInstance3D", true, false):
			var mesh: Mesh = (mi as MeshInstance3D).mesh
			for si in mesh.get_surface_count():
				var idx: int = mesh.surface_get_array_index_len(si)
				tris += (idx if idx > 0 else mesh.surface_get_array_len(si)) / 3
		check(tris > 50 and tris <= DecorFactory.MAX_TRIS, "%s has a model within budget (%d tris)" % [did, tris])
		m.free()
	# Save / load.
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(u.calendar.capture(), c.capture(), "the card survives save and load")
	free_sim(u)
	free_sim(s)


func _goals_ui() -> void:
	SaveManager.dir = "user://test_saves_retention"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	BoostManager.date_override = "2030-03-01"
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Goal Bakery")
	await runner.get_tree().process_frame
	var sim: SimulationRoot = game.sim
	eq(sim.calendar.first_date, "2030-03-01", "the first visit starts the stamp card")
	check(not game.modals.is_open(&"calendar"), "no stamp popup on the first day")
	game.modals.close_all()
	sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
	game.hud._refresh_all()
	game.hud.open_tab(&"goals")
	await _frames(2)
	var early: GoalsScreen = game.modals.screen(&"goals") as GoalsScreen
	check(early != null and early.content().find_child("FirstDay", true, false) != null and early.content().find_child("Goal_0", true, false) == null,
		"on day 1 the sheet says when the first goals arrive")
	game.modals.close_all()
	_cross_midnight(sim)
	game.hud._refresh_all()
	var btn: Button = game.hud.goals_button()
	check(btn != null and btn.visible and btn.get_global_rect().size.x >= 48.0, "the HUD has a 48 px Goals button")
	var dot: Control = btn.get_node("Dot") as Control
	check(not dot.visible, "no dot while nothing is ready")
	var toasts: Array = []
	var catch_toast: Callable = func(_p: int, key: String, _params: Dictionary, _i: StringName) -> void:
		if key == "ui_goals_ready":
			toasts.append(key)
	EventBus.notify.connect(catch_toast)
	var g0: Dictionary = sim.goals.goals[0]
	sim.statistics.add(StringName(str(g0["stat"])), float(g0["target"]))
	game.hud._refresh_all()
	EventBus.notify.disconnect(catch_toast)
	check(dot.visible, "a finished goal lights the dot")
	eq(toasts.size(), 1, "and toasts once")
	btn.pressed.emit()
	await _frames(2)
	var sheet: GoalsScreen = game.modals.screen(&"goals") as GoalsScreen
	check(sheet != null, "the button opens the Goals sheet")
	if sheet != null:
		var row: Node = sheet.content().find_child("Goal_0", true, false)
		var claim: Button = row.find_child("Claim", true, false) as Button if row != null else null
		check(claim != null and claim.visible and not claim.disabled, "the finished goal has Claim")
		var other: Button = sheet.content().find_child("Goal_1", true, false).find_child("Claim", true, false) as Button
		check(other.disabled, "an unfinished goal's Claim is off")
		var count: Label = row.find_child("Count", true, false) as Label
		var full: String = GoalsScreen.amount_text(g0, float(g0["target"]))
		eq(count.text, Tx.t("ui_goals_progress", {"done": full, "target": full}), "the row shows the progress")
		check(sheet.content().find_child("StampCard", true, false) != null, "the sheet shows the stamp card")
		var stamp_it: Button = sheet.content().find_child("StampIt", true, false) as Button
		check(stamp_it != null and not stamp_it.visible, "no Stamp button on the first day")
		var before: float = sim.economy.balance
		claim.pressed.emit()
		await _frames(3)
		near(sim.economy.balance - before, float(g0["reward"]), 0.001, "Claim pays the reward")
		var row2: Node = sheet.content().find_child("Goal_0", true, false)
		var done: Control = row2.find_child("Claimed", true, false) as Control if row2 != null else null
		check(done != null and done.visible, "the claimed goal shows Done")
	game.hud._refresh_all()
	check(not dot.visible, "the dot goes out")
	game.modals.close_all()
	# Tanggal perangkat baru: popup Daily Stamps.
	BoostManager.date_override = "2030-03-02"
	game.check_daily_gift()
	await _frames(2)
	var cal: CalendarScreen = game.modals.screen(&"calendar") as CalendarScreen
	check(cal != null, "a new device date opens Daily Stamps")
	if cal != null:
		var tile: Node = cal.find_child("Day1", true, false)
		check(tile != null and bool(tile.get_meta("next", false)), "day 1 is highlighted")
		var b: Button = cal.find_child("Claim", true, false) as Button
		check(b != null, "with a Stamp it! button")
		var before2: float = sim.economy.balance
		var want: float = float(sim.calendar.reward(0)["kr"])
		if b != null:
			b.pressed.emit()
		await _frames(3)
		near(sim.economy.balance - before2, want, 0.001, "stamping pays day 1")
		eq(sim.calendar.stamps, 1, "one stamp")
		var tile2: Node = cal.find_child("Day1", true, false)
		check(tile2 != null and bool(tile2.get_meta("stamped", false)), "day 1 shows its stamp")
		check(cal.find_child("Claim", true, false) == null and cal.find_child("Done", true, false) != null, "then only Close is left")
	game.modals.close_all()
	game.check_daily_gift()
	await _frames(1)
	check(not game.modals.is_open(&"calendar"), "no second popup that day")
	BoostManager.date_override = ""
	game.playing = true
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


static func _has_pill(row: Node, text: String) -> bool:
	for n: Node in row.find_children("*", "Label", true, false):
		if (n as Label).text == text and n.get_parent().get_parent() is PanelContainer and String(n.get_parent().get_parent().name).begins_with("Pill"):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame
