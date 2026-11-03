extends TestSuite
## Fitur retensi dan berbagi (GDD idle 21): craving harian dan selera lingkungan,
## misi ringan harian, kalender cap, Share my bakery, photo mode, event
## musiman, Peta Crumbtown, tip untuk semuanya, dan Roti Emas.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_CRAVING", "name": "idle 21.1 from day 2 the town craves one recipe the kitchen can make (seeded, never yesterday's); while it is unlocked it sells for 1.2x the best bread (itself included), Auto switches to it, offline ignores it, and each location has two favourites at 1.25x", "fn": _craving},
		{"id": "ACC_IDLE_CRAVING_UI", "name": "idle 21.1 the HUD craving chip shows the bread, its name and a lock until unlocked, and opens the Menu, where a card explains the craving and the favourites and rows carry Craving / Local favorite pills", "fn": _craving_ui},
		{"id": "ACC_IDLE_GOALS", "name": "idle 21.2 three seeded goals a day sized from the shop, progress counted from the stat at issue, Claim pays the fixed reward once (not as income), finished goals survive midnight, a franchise issues a new set, save/load and old saves", "fn": _goals},
		{"id": "ACC_IDLE_CALENDAR", "name": "idle 21.3 one stamp per device date from the day after the first visit, missed days never reset, seven rewards (KR, x2 boosts, a calendar decoration on day 7, then KR only), kept across saves", "fn": _calendar},
		{"id": "ACC_IDLE_GOALS_UI", "name": "idle 21.2-21.3 the HUD Goals button lights up and toasts for a finished goal, the Goals sheet claims it, and a new device date opens the Daily Stamps popup that stamps the card", "fn": _goals_ui},
		{"id": "ACC_IDLE_SHARE", "name": "idle 21.4 Share my bakery from the Pause menu photographs the shop without the HUD, bakes a 1080x1350 card with the name, place and four numbers, previews it, and saves a PNG with a safe file name", "fn": _share},
		{"id": "ACC_IDLE_PHOTO_MODE", "name": "idle 21.5 Photo mode from the Pause menu hides the HUD while the shop runs, pans freely without world taps, tints with filters, adds a polaroid frame, captures the screen without its buttons, and restores everything on Close", "fn": _photo},
		{"id": "ACC_IDLE_EVENTS", "name": "idle 21.6 device-date events: fixed windows (also across the new year), Lunar New Year and Lebaran from their date tables, overlapping events, featured breads at 1.25x in the shop and the model, double goal rewards, one announcement per event, off without a date", "fn": _events},
		{"id": "ACC_IDLE_EVENTS_UI", "name": "idle 21.6 an event date toasts the event, shows a HUD chip with the end date that opens the Menu (Event pills and a card line), a Goals banner, and event decorations in the shop; the next date takes them away", "fn": _events_ui},
		{"id": "ACC_IDLE_TOWN_MAP", "name": "idle 21.7 a franchise records the sold branch (tier, stars, KR, income, days); the map lists every branch plus the open one, survives saves, and fills older saves with placeholders", "fn": _town_map},
		{"id": "ACC_IDLE_TOWN_MAP_UI", "name": "idle 21.7 the Franchise sheet opens the Crumbtown map: bakeries along streets in their tier's look, You are here on the open branch, a lot for the next one, and a story page per bakery", "fn": _town_map_ui},
		{"id": "ACC_IDLE_TIPS", "name": "idle 21.8 one-off tips for the craving, daily goals, a seasonal event, Share/Photo mode (Tier 2) and the Crumbtown map (second branch), each once, archived in Help, none with hints off", "fn": _tips},
		{"id": "ACC_IDLE_TIPS_UI", "name": "idle 21.8 a tip for a HUD button opens as a tap guide on that button and finishes when its screen opens; the next tip follows", "fn": _tips_ui},
		{"id": "ACC_IDLE_GOLDEN", "name": "idle 21.9 golden bread flies during play only (real seconds), can be missed, and gives a seeded reward: KR (not income), Golden hour on top of other boosts (live KR/s only) or Rush hour; saved mid-flight, reset by a franchise", "fn": _golden},
		{"id": "ACC_IDLE_GOLDEN_UI", "name": "idle 21.9 the golden bread flies across the frame as a big touch target with a first-time tip, hides under blocking popups and in Decoration Mode, and one tap catches it with a toast and a boost chip", "fn": _golden_ui},
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
	# Model offline: tanpa craving sama sekali, juga untuk pilihan Auto (semua
	# petak di Auto).
	for e: EquipmentInstance in s.equipment.placed_list(&"display"):
		for si in s.display.slot_count(e.iid):
			s.display.set_assignment(e.iid, si, &"")
	s.idle_economy.invalidate()
	var off_rate: float = float(s.idle_economy.compute(false)["rate"])
	CravingManager.enabled = false
	s.idle_economy.invalidate()
	var plain_rate: float = float(s.idle_economy.compute(false)["rate"])
	var plain_auto: StringName = s.auto_recipe()
	CravingManager.enabled = true
	s.idle_economy.invalidate()
	check(plain_auto != c1, "with cravings off another bread is Auto")
	near(off_rate, plain_rate, 1e-9, "the offline KR/s is the same as with cravings off")
	eq(s.auto_recipe(false), plain_auto, "the offline model keeps the usual Auto recipe (%s, live %s)" % [plain_auto, c1])
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


## Boot GameRoot untuk tes Share / Photo mode; berkas gambar ke folder tes.
func _boot_share(name_text: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_retention"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	ShareCard.out_dir_override = ProjectSettings.globalize_path("user://test_share")
	_clear_share_dir()
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", name_text)
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	return game


func _end_share(game: GameRoot) -> void:
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
	_clear_share_dir()
	ShareCard.out_dir_override = ""


func _clear_share_dir() -> void:
	var d: DirAccess = DirAccess.open(ShareCard.out_dir_override) if ShareCard.out_dir_override != "" else null
	if d == null:
		return
	for f: String in d.get_files():
		d.remove(f)


func _share_files(prefix: String) -> PackedStringArray:
	var out := PackedStringArray()
	var d: DirAccess = DirAccess.open(ShareCard.out_dir_override)
	if d == null:
		return out
	for f: String in d.get_files():
		if f.begins_with(prefix) and f.ends_with(".png"):
			out.append(f)
	return out


func _pause_has(game: GameRoot, key: String) -> bool:
	var p: UIScreen = game.modals.open(&"pause")
	var found: bool = false
	for b: Node in p.find_children("*", "Button", true, false):
		for l: Node in b.find_children("*", "Label", true, false):
			if (l as Label).text == Tx.t(key):
				found = true
	game.modals.close_id(&"pause")
	return found


func _share() -> void:
	var game: GameRoot = await _boot_share("Shiny Buns!")
	var sim: SimulationRoot = game.sim
	check(_pause_has(game, "ui_share_menu"), "the Pause menu has Share my bakery")
	var base: String = ShareCard.file_base(sim, "bakery")
	check(base.begins_with("crumbtown-bakery-shiny-buns-"), "file names are safe (%s)" % base)
	var st: Array = ShareCard.stats(sim)
	eq(st.size(), 4, "the card shows four numbers")
	eq(str(st[0][1]), Tx.t("ui_kr_per_second", {"amount": Tx.rate(sim.income_rate())}), "the first is KR/s")
	var s: ShareScreen = game.modals.open(&"share") as ShareScreen
	check(s != null and game.modals.has_blocking(), "Share opens as a popup that pauses the shop")
	var go: Button = s.find_child("Share", true, false) as Button
	check(go != null and go.disabled, "Save waits until the card is ready")
	var waited: int = 0
	while s.card == null and waited < 240:
		await runner.get_tree().process_frame
		waited += 1
	check(s.card != null, "the card is baked")
	if s.card != null:
		eq(Vector2i(s.card.get_width(), s.card.get_height()), ShareCard.SIZE, "the card is 1080x1350")
	check(game.hud.visible and game.modals.visible, "the HUD and popups come back after the photo")
	check(not go.disabled, "Save is ready")
	check((s.find_child("Preview", true, false) as TextureRect).texture != null, "the popup previews the card")
	go.pressed.emit()
	await runner.get_tree().process_frame
	var files: PackedStringArray = _share_files("crumbtown-bakery-shiny-buns-")
	eq(files.size(), 1, "Save image writes one PNG")
	if files.size() == 1:
		var img: Image = Image.load_from_file(ShareCard.out_dir_override.path_join(files[0]))
		check(img != null and img.get_width() == ShareCard.SIZE.x and img.get_height() == ShareCard.SIZE.y, "the saved PNG is the card")
	var status: Label = s.find_child("Status", true, false) as Label
	check(status.text.begins_with(Tx.t("ui_share_saved", {"path": ""})), "the popup says where it went")
	# Kartu tanpa bintang menyebut pembeli; dengan bintang menyebut bintang.
	sim.prestige.stars = 7
	eq(str(ShareCard.stats(sim)[2][2]), Tx.t("ui_share_stat_stars"), "franchise stars show once earned")
	sim.prestige.stars = 0
	await _end_share(game)


func _photo() -> void:
	var game: GameRoot = await _boot_share("Photo Bakery")
	var sim: SimulationRoot = game.sim
	check(_pause_has(game, "ui_photo_menu"), "the Pause menu has Photo mode")
	var p: PhotoModeScreen = game.modals.open(&"photo_mode") as PhotoModeScreen
	await _frames(2)
	check(p != null, "Photo mode opens")
	check(game.hud.decoration_active, "the HUD hides")
	check(not game.modals.has_blocking(), "the shop keeps running")
	check(game.world.camera_rig.free_pan, "the camera pans freely")
	check(game.commands.tap_override.is_valid(), "world taps do nothing")
	var tint: ColorRect = p.find_child("Tint", true, false) as ColorRect
	check(tint != null and not tint.visible, "no filter at first")
	(p.find_child("Filter2", true, false) as Button).pressed.emit()
	check(tint.visible and tint.color == PhotoModeScreen.FILTERS[2][1], "a filter chip tints the picture")
	var frame: Control = p.find_child("PolaroidFrame", true, false) as Control
	check(not frame.visible, "no frame at first")
	(p.find_child("FrameToggle", true, false) as Button).pressed.emit()
	check(frame.visible, "Frame adds the polaroid border")
	var img: Image = await p.capture()
	var vs: Vector2 = game.get_viewport().get_visible_rect().size
	check(img != null and img.get_width() == int(vs.x) and img.get_height() == int(vs.y), "Capture takes the whole screen")
	check((p.find_child("Controls", true, false) as Control).visible, "the buttons come back after the shot")
	eq(_share_files("crumbtown-photo-photo-bakery-").size(), 1, "the photo is saved")
	var status: Label = p.find_child("Status", true, false) as Label
	check(status.visible and status.text.begins_with(Tx.t("ui_photo_saved", {"path": ""})), "and the bar says where")
	(p.find_child("Close", true, false) as Button).pressed.emit()
	await _frames(1)
	check(not game.modals.is_open(&"photo_mode"), "Close leaves Photo mode")
	check(not game.hud.decoration_active, "the HUD is back")
	check(not game.world.camera_rig.free_pan, "the camera follows the shop again")
	check(not game.commands.tap_override.is_valid(), "world taps work again")
	await _end_share(game)


static func _event_ids(d: String) -> Array:
	var out: Array = []
	for ev: Dictionary in EventManager.events_on(d):
		out.append(str(ev["id"]))
	return out


func _events() -> void:
	EventManager.enabled = true
	# Kalender: jendela tetap, melewati tahun baru, dan tanggal Imlek/Lebaran.
	eq(_event_ids("2030-12-17"), [], "the day before the winter window has no event")
	eq(_event_ids("2030-12-18"), ["event_winter"], "the winter window opens on Dec 18")
	eq(_event_ids("2031-01-02"), ["event_winter"], "and runs past the new year to Jan 2")
	eq(_event_ids("2031-01-03"), [], "then ends")
	eq(str(EventManager.events_on("2031-01-01")[0]["start"]), "2030-12-18", "a wrapping window starts in the old year")
	eq(str(EventManager.events_on("2031-01-01")[0]["end"]), "2031-01-02", "and ends in the new one")
	eq(_event_ids("2027-02-04"), ["event_lunar_new_year"], "Lunar New Year starts two days before Feb 6, 2027")
	eq(_event_ids("2027-02-08"), ["event_lunar_new_year", "event_sweetheart"], "two events can run together")
	eq(_event_ids("2027-02-12"), ["event_sweetheart"], "Lunar New Year ends five days after")
	eq(_event_ids("2027-03-06"), ["event_lebaran"], "Lebaran 2027 starts four days before Mar 10")
	eq(_event_ids("2027-03-15"), [], "and ends four days after")
	eq(_event_ids("2026-08-17"), ["event_merdeka"], "Merdeka Week covers Aug 17")
	eq(_event_ids(""), [], "no device date, no event")
	eq(Tx.short_date("2031-01-02"), "Jan 2", "short dates read like Jan 2")
	# Efek di toko.
	var s: SimulationRoot = new_sim(5601)
	s.tutorial.skip()
	var choc: StringName = &"recipe_chocolate_bread"
	var before_price: float = s.plain_price(choc)
	var before_rate: float = s.idle_economy.rate(false)
	check(s.events.set_date("2030-12-20"), "a winter date starts the event")
	check(not s.events.set_date("2030-12-20"), "the same date changes nothing")
	check(s.events.is_featured(choc) and not s.events.is_featured(&"recipe_plain_loaf"), "featured breads come from the event")
	near(s.plain_price(choc), before_price * DataRegistry.idlef("events.featured_mult"), 1e-6, "featured breads sell for 1.25x")
	eq(s.events.featured(), [choc, &"recipe_almond_artisan_croissant", &"recipe_gourmet_brioche"], "featured list in catalog order")
	near(s.events.goal_reward_mult(), DataRegistry.idlef("events.goal_reward_mult"), 1e-9, "goal rewards are doubled")
	var reward_on: float = s.goals.reward_now()
	s.events.set_date("2031-01-10")
	check(s.events.active().is_empty(), "after the window the event is over")
	near(s.plain_price(choc), before_price, 1e-6, "prices go back")
	check(reward_on > s.goals.reward_now(), "goals issued during the event pay more")
	near(s.idle_economy.rate(false), before_rate, 1e-6, "the model forgets the event")
	# Pengumuman sekali per kemunculan event, ikut tersimpan.
	s.events.set_date("2030-12-20")
	eq(s.events.take_announcements().size(), 1, "a new event is announced once")
	eq(s.events.take_announcements().size(), 0, "not twice")
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	u.events.set_date("2030-12-21")
	eq(u.events.take_announcements().size(), 0, "a reload does not announce it again")
	u.events.set_date("2031-12-20")
	eq(u.events.take_announcements().size(), 1, "next year's winter is announced again")
	free_sim(u)
	# Mati di tes lain.
	EventManager.enabled = false
	s.events.set_date("2030-12-25")
	check(s.events.active().is_empty(), "with events off no date starts one")
	free_sim(s)


func _events_ui() -> void:
	EventManager.enabled = true
	BoostManager.date_override = "2030-12-20"
	var toasts: Array = []
	var catch_toast: Callable = func(_p: int, key: String, params: Dictionary, _i: StringName) -> void:
		if key == "ui_event_started":
			toasts.append(params)
	EventBus.notify.connect(catch_toast)
	var game: GameRoot = await _boot_share("Event Bakery")
	EventBus.notify.disconnect(catch_toast)
	var sim: SimulationRoot = game.sim
	eq(toasts.size(), 1, "the event is announced with a toast")
	game.playing = false
	game.hud._refresh_all()
	var chip: Button = game.hud.event_chip()
	check(chip != null and chip.visible, "the HUD shows the event")
	var texts: Array = []
	for n: Node in chip.find_children("*", "Label", true, false):
		texts.append((n as Label).text)
	check(texts.has(Tx.t("ui_event_chip", {"name": Tx.t("event_winter"), "date": "Jan 2"})), "with its name and end date (%s)" % [texts])
	check(chip.get_global_rect().size.y >= 48.0, "the event chip is a 48 px touch target")
	check(not game.world.holiday_nodes().is_empty(), "the shop is decorated")
	chip.pressed.emit()
	await _frames(2)
	var menu: MenuScreen = game.modals.screen(&"menu") as MenuScreen
	check(menu != null, "the chip opens the Menu")
	if menu != null:
		var row: Node = menu.content().find_child("Recipe_recipe_chocolate_bread", true, false)
		check(row != null and _has_pill(row, Tx.t("ui_event_pill")), "featured breads carry an Event pill")
		check(menu.content().find_child("EventLine", true, false) != null, "the Menu card explains the event")
	game.modals.close_all()
	game.hud.open_tab(&"goals")
	await _frames(2)
	var goals: GoalsScreen = game.modals.screen(&"goals") as GoalsScreen
	check(goals != null and goals.content().find_child("EventBanner", true, false) != null, "the Goals sheet says goals pay double")
	game.modals.close_all()
	# Tanggal berganti saat bermain: event selesai, hiasan dicopot.
	BoostManager.date_override = "2031-01-10"
	game.check_daily_gift()
	game.hud._refresh_all()
	check(not chip.visible, "the chip goes away after the event")
	check(game.world.holiday_nodes().is_empty() or sim.weather.holiday_today(), "the decorations come down")
	BoostManager.date_override = ""
	await _end_share(game)


func _town_map() -> void:
	var s: SimulationRoot = new_sim(5701)
	s.tutorial.skip()
	eq(s.prestige.branches.size(), 0, "a new bakery has no sold branches")
	var cur: Dictionary = s.prestige.current_branch()
	check(bool(cur["current"]) and int(cur["number"]) == 1 and int(cur["opened_day"]) == 1, "the open shop is branch 1 since day 1")
	eq(TownMapScreen.branches(s).size(), 1, "the map starts with one bakery")
	# Waralaba mencatat cabang yang dijual.
	jump_to_tier(s, 3)
	equip_shop(s, 30)
	var d: float = DataRegistry.idlef("prestige.stars_divisor_kr")
	s.statistics.stats["alltime_earned_kr"] = 3.5 * d
	s.statistics.stats["run_earned_kr"] = 12345.0
	run_hours(s, 0.2)
	var earned: float = s.statistics.get_stat("run_earned_kr")
	var sold_day: int = s.time.day
	var gained: int = s.prestige.stars_gain()
	check(gained > 0 and s.franchise() == gained, "franchise")
	eq(s.prestige.branches.size(), 1, "the sold branch is recorded")
	var b: Dictionary = s.prestige.branches[0]
	eq(int(b["number"]), 1, "as branch 1")
	eq(int(b["tier"]), 3, "with the tier it reached")
	eq(int(b["stars"]), gained, "the stars it earned")
	near(float(b["earned"]), earned, 0.01, "the KR it earned")
	eq(int(b["sold_day"]), sold_day, "and the day it was sold")
	check(not b.has("current"), "a sold branch is not current")
	eq(s.prestige.run_started_day, s.time.day, "the new branch opens today")
	var lots: Array[Dictionary] = TownMapScreen.branches(s)
	eq(lots.size(), 2, "the map now shows two bakeries")
	check(bool(lots[1]["current"]) and int(lots[1]["number"]) == 2, "the second is the open branch")
	# Save / load dan save lama.
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	same_state({"b": u.prestige.branches}, {"b": s.prestige.branches}, "branches survive save and load")
	eq(u.prestige.run_started_day, s.prestige.run_started_day, "and the opening day")
	free_sim(u)
	var old: Dictionary = json_copy(s.capture_save())
	(old["franchise"] as Dictionary).erase("branches")
	old["franchise"]["run_index"] = 3
	var v: SimulationRoot = load_sim(old)
	var lots2: Array[Dictionary] = TownMapScreen.branches(v)
	eq(lots2.size(), 3, "an older save shows every branch number")
	check(bool(lots2[0].get("unknown", false)) and bool(lots2[1].get("unknown", false)), "earlier branches without a story are placeholders")
	free_sim(v)
	free_sim(s)


func _town_map_ui() -> void:
	var game: GameRoot = await _boot_share("Map Bakery")
	var sim: SimulationRoot = game.sim
	game.playing = false
	sim.prestige.branches.append({"number": 1, "tier": 4, "stars": 9, "earned": 1.5e6, "rate": 812.0, "opened_day": 1, "sold_day": 6})
	sim.prestige.run_index = 2
	game.hud.open_tab(&"franchise")
	await _frames(2)
	var fr: UIScreen = game.modals.screen(&"franchise")
	var open_b: Button = fr.find_child("TownMap", true, false) as Button if fr != null else null
	check(open_b != null and open_b.get_global_rect().size.y >= 48.0, "the Franchise sheet has a Crumbtown map button")
	open_b.pressed.emit()
	await _frames(2)
	var map: TownMapScreen = game.modals.screen(&"town_map") as TownMapScreen
	check(map != null, "it opens the map")
	if map == null:
		await _end_share(game)
		return
	var b1: Button = map.content().find_child("Branch1", true, false) as Button
	var b2: Button = map.content().find_child("Branch2", true, false) as Button
	check(b1 != null and b2 != null and map.content().find_child("NextLot", true, false) != null, "two bakeries and a lot for the next one")
	var art1: ShopFrontArt = b1.find_child("*", true, false) as ShopFrontArt
	for n: Node in b1.find_children("*", "ShopFrontArt", true, false):
		art1 = n as ShopFrontArt
	eq(art1.tier if art1 != null else -1, 4, "a branch looks like the tier it reached")
	var here: bool = false
	for l: Node in b2.find_children("*", "Label", true, false):
		if (l as Label).text == Tx.t("ui_map_here"):
			here = true
	check(here, "the open branch says You are here")
	check(map.content().find_child("Street1", true, false) != null, "bakeries stand along a street")
	b1.pressed.emit()
	await _frames(3)
	check(map.page_depth() == 1, "tapping a bakery opens its story")
	var story: Node = map.content().find_child("BranchStory", true, false)
	var found: bool = false
	if story != null:
		for l2: Node in story.find_children("*", "Label", true, false):
			if (l2 as Label).text == Tx.big(9.0):
				found = true
	check(found, "the story shows the stars it earned")
	game.modals.close_all()
	await _end_share(game)


## Langkah onboarding dasar (sebelum tip fitur retensi) dianggap sudah tampil.
static func _base_steps_done(s: SimulationRoot) -> void:
	for k: String in TutorialManager.STEPS:
		if k in ["onb_craving", "onb_goals", "onb_event", "onb_share", "onb_map", "onb_golden"]:
			continue
		s.tutorial.done[k] = true
	s.tutorial.prompt = {}


static func _tip_step(s: SimulationRoot) -> void:
	for i in int(1.0 / s.tick_seconds):
		s.step(s.tick_seconds)


func _tips() -> void:
	var hints_before: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", true)
	CravingManager.enabled = true
	var s: SimulationRoot = new_sim(5801)
	_base_steps_done(s)
	_tip_step(s)
	eq(s.tutorial.prompt, {}, "no new tip on day 1")
	_cross_midnight(s)
	_tip_step(s)
	eq(str(s.tutorial.prompt.get("key", "")), "onb_craving", "day 2 points at the craving chip")
	eq(str(s.tutorial.prompt.get("target", "")), "hud_craving", "with the HUD target")
	s.tutorial.dismiss()
	eq(str(s.tutorial.prompt.get("key", "")), "onb_goals", "then at the Goals button")
	eq(str(s.tutorial.prompt.get("target", "")), "hud_goals", "with its HUD target")
	s.tutorial.dismiss()
	jump_to_tier(s, 2)
	_tip_step(s)
	eq(str(s.tutorial.prompt.get("key", "")), "onb_share", "a bigger shop suggests Share and Photo mode")
	eq(str(s.tutorial.prompt.get("target", "")), "hud_pause", "through the Pause button")
	s.tutorial.dismiss()
	EventManager.enabled = true
	s.events.set_date("2030-12-20")
	_tip_step(s)
	eq(str(s.tutorial.prompt.get("key", "")), "onb_event", "a seasonal event points at its chip")
	s.tutorial.dismiss()
	s.prestige.run_index = 2
	_tip_step(s)
	eq(str(s.tutorial.prompt.get("key", "")), "onb_map", "a second branch points at the Crumbtown map")
	eq(str(s.tutorial.prompt.get("target", "")), "tab_franchise", "through the Franchise tab")
	s.tutorial.dismiss()
	_cross_midnight(s)
	_tip_step(s)
	eq(s.tutorial.prompt, {}, "every tip shows only once")
	for k: String in ["onb_craving", "onb_goals", "onb_event", "onb_share", "onb_map"]:
		check(s.tutorial.archive().has(k), "%s is in the Help archive" % k)
		check(Tx.t(k) != k, "%s has English text" % k)
	free_sim(s)
	# Tip mati: tidak ada yang tampil.
	SettingsManager.set_value("tutorial_hints", false)
	var t: SimulationRoot = new_sim(5802)
	_base_steps_done(t)
	_cross_midnight(t)
	_tip_step(t)
	eq(t.tutorial.prompt, {}, "with hints off no tip appears")
	free_sim(t)
	SettingsManager.set_value("tutorial_hints", hints_before)


func _tips_ui() -> void:
	var hints_before: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", true)
	CravingManager.enabled = true
	var game: GameRoot = await _boot_share("Tip Bakery")
	var sim: SimulationRoot = game.sim
	game.modals.close_all()
	sim.tutorial.skipped = false
	_base_steps_done(sim)
	game.playing = false
	_cross_midnight(sim)
	_tip_step(sim)
	game.hud._refresh_all()
	await _frames(3)
	var guide: TutorialGuide = game.modals.screen(&"tutorial_guide") as TutorialGuide
	check(guide != null and guide.key == "onb_craving", "the craving tip opens as a tap guide")
	if guide != null:
		await _frames(2)
		eq(guide.target_control(), game.hud.craving_chip(), "the hole sits on the craving chip")
	game.hud.craving_chip().pressed.emit()
	await _frames(3)
	check(game.modals.is_open(&"menu"), "tapping the chip opens the Menu")
	check(str(sim.tutorial.prompt.get("key", "")) != "onb_craving", "and finishes the craving tip")
	game.modals.close_id(&"menu")
	await _frames(3)
	var guide2: TutorialGuide = game.modals.screen(&"tutorial_guide") as TutorialGuide
	check(guide2 != null and guide2.key == "onb_goals", "the Goals tip follows")
	if guide2 != null:
		await _frames(2)
		eq(guide2.target_control(), game.hud.goals_button(), "pointing at the Goals button")
	game.hud.goals_button().pressed.emit()
	await _frames(3)
	check(game.modals.is_open(&"goals") and not game.modals.is_open(&"tutorial_guide"), "opening Goals closes the tip")
	eq(sim.tutorial.prompt, {}, "no tip is left")
	game.modals.close_all()
	SettingsManager.set_value("tutorial_hints", hints_before)
	await _end_share(game)


## Langsung terbangkan roti emas berikutnya.
static func _launch_golden(s: SimulationRoot) -> void:
	s.golden.next_in = 0.0
	s.step(s.tick_seconds)


func _golden() -> void:
	var s: SimulationRoot = new_sim(5901)
	s.tutorial.skip()
	var g: GoldenManager = s.golden
	near(g.next_in, DataRegistry.idlef("golden.first_after_minutes") * 60.0, 0.001, "the first golden bread waits a few minutes of play")
	check(not g.is_flying(), "nothing flies at the start")
	g.next_in = 1.0
	s.run_for(1.5 * DataRegistry.sim_seconds_per_real_second())
	check(g.is_flying() and g.flight == 1, "after the wait it flies (counted in real seconds of play)")
	var vis: float = DataRegistry.idlef("golden.visible_seconds")
	s.run_for(vis * 0.5 * DataRegistry.sim_seconds_per_real_second())
	near(g.progress(), (vis * 0.5 + 0.5) / vis, 0.03, "it crosses the screen in golden.visible_seconds")
	s.run_for(vis * 0.6 * DataRegistry.sim_seconds_per_real_second())
	check(not g.is_flying(), "a missed golden bread flies away")
	var span: Array = DataRegistry.idle("golden.interval_minutes")
	check(g.next_in >= float(span[0]) * 60.0 - 1.0 and g.next_in <= float(span[1]) * 60.0, "the next one comes within the interval (%.0f s)" % g.next_in)
	eq(g.catch(), {}, "nothing to catch when nothing flies")
	# Hadiah: sama dengan undiannya, dan semua jenis muncul.
	var seen: Dictionary = {}
	var coffee: bool = false
	for i in 40:
		_launch_golden(s)
		var want: Dictionary = g.reward_now()
		var before: float = s.economy.balance
		var earned: float = s.statistics.get_stat("run_earned_kr")
		var got: Dictionary = g.catch()
		eq(got, want, "flight %d gives the drawn reward" % g.flight)
		check(not g.is_flying(), "a caught golden bread is gone")
		match str(got["id"]):
			"golden_kr":
				near(s.economy.balance - before, float(got["kr"]), 0.001, "golden KR arrive")
				eq(s.statistics.get_stat("run_earned_kr"), earned, "and are not income")
			"golden_frenzy":
				if not coffee:
					s.boosts.add_income(2.0, 900.0)
					coffee = true
				near(s.boosts.income_now(), 2.0 * float(got["mult"]), 1e-9, "Golden hour multiplies on top of the coffee")
				near(s.boosts.frenzy_left, float(got["seconds"]), 0.001, "for its seconds")
				s.idle_economy.invalidate()
				check(s.idle_economy.rate(true) > s.idle_economy.rate(false) * 2.5, "the live KR/s counts it")
			"golden_rush":
				near(s.boosts.arrival_now(), float(got["mult"]), 1e-9, "Rush hour brings more customers")
		seen[str(got["id"])] = true
		s.boosts.frenzy_left = 0.0
		s.boosts.frenzy_mult = 1.0
		s.boosts.rush_left = 0.0
		s.boosts.rush_mult = 1.0
	eq(seen.size(), 3, "all three rewards turn up (%s)" % [seen.keys()])
	eq(s.statistics.get_stat("golden_caught"), 40.0, "catches are counted")
	# Boost berakhir dalam detik nyata.
	s.boosts.add_frenzy(3.0, 2.0)
	s.run_for(2.5 * DataRegistry.sim_seconds_per_real_second())
	near(s.boosts.frenzy_mult, 1.0, 1e-9, "Golden hour ends on time")
	# Seed sama, penerbangan sama.
	var t: SimulationRoot = new_sim(5901, &"profile_twin")
	t.golden.flight = g.flight
	eq(t.golden.reward_now(), g.reward_now(), "the same seed and flight draw the same reward")
	free_sim(t)
	# Save / load di tengah terbang.
	_launch_golden(s)
	s.boosts.add_rush(2.0, 30.0)
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	check(u.golden.is_flying() and is_equal_approx(u.golden.visible_left, g.visible_left), "a flying golden bread survives save and load")
	near(u.boosts.rush_left, s.boosts.rush_left, 0.001, "and so does Rush hour")
	free_sim(u)
	# Waralaba menghentikan hadiahnya.
	s.boosts.new_run()
	check(s.boosts.rush_left == 0.0 and s.boosts.frenzy_left == 0.0, "a new branch starts without golden boosts")
	# Mati: tidak terbang.
	GoldenManager.enabled = false
	var w: SimulationRoot = new_sim(5903)
	w.golden.next_in = 0.0
	w.step(w.tick_seconds)
	check(not w.golden.is_flying(), "switched off, nothing flies")
	GoldenManager.enabled = true
	free_sim(w)
	free_sim(s)


func _golden_ui() -> void:
	var hints_before: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", true)
	var game: GameRoot = await _boot_share("Golden Bakery")
	var sim: SimulationRoot = game.sim
	game.modals.close_all()
	sim.tutorial.skipped = false
	_base_steps_done(sim)
	for k: String in ["onb_craving", "onb_goals", "onb_event", "onb_share", "onb_map"]:
		sim.tutorial.done[k] = true
	game.playing = false
	_launch_golden(sim)
	_tip_step(sim)
	await _frames(3)
	var btn: Button = game.hud.golden.button
	check(btn.visible, "a flying golden bread shows on screen")
	check(btn.size.x >= 48.0 and btn.size.y >= 48.0, "as a big touch target")
	var vp: Rect2 = btn.get_viewport_rect()
	check(vp.grow(btn.size.x).encloses(Rect2(btn.position, btn.size)), "inside the frame")
	var guide: TutorialGuide = game.modals.screen(&"tutorial_guide") as TutorialGuide
	check(guide != null and guide.key == "onb_golden", "the first one comes with a tip")
	if guide != null:
		eq(guide.target_control(), btn, "pointing at the golden bread")
	game.modals.open(&"pause")
	await _frames(2)
	check(not btn.visible, "it hides under the Pause menu")
	game.modals.close_id(&"pause")
	await _frames(2)
	check(btn.visible, "and comes back")
	var toasts: Array = []
	var catch_toast: Callable = func(_p: int, key: String, _params: Dictionary, _i: StringName) -> void:
		if key.begins_with("golden_"):
			toasts.append(key)
	EventBus.notify.connect(catch_toast)
	var want: String = str(sim.golden.reward_now()["id"])
	btn.pressed.emit()
	EventBus.notify.disconnect(catch_toast)
	await _frames(2)
	eq(toasts, [want], "catching it toasts the reward")
	check(not btn.visible and not sim.golden.is_flying(), "and it is gone")
	_tip_step(sim)
	await _frames(2)
	check(not game.modals.is_open(&"tutorial_guide"), "the tip closes")
	sim.boosts.add_frenzy(3.0, 30.0)
	game.hud._refresh_all()
	var chip: Control = game.hud.find_child("FrenzyBoost", true, false) as Control
	check(chip != null and chip.visible, "Golden hour shows a chip with its time")
	game.hud.set_decoration_active(true)
	_launch_golden(sim)
	await _frames(2)
	check(not btn.visible, "no golden bread in Decoration Mode")
	game.hud.set_decoration_active(false)
	SettingsManager.set_value("tutorial_hints", hints_before)
	await _end_share(game)


static func _has_pill(row: Node, text: String) -> bool:
	for n: Node in row.find_children("*", "Label", true, false):
		if (n as Label).text == text and n.get_parent().get_parent() is PanelContainer and String(n.get_parent().get_parent().name).ends_with("Pill"):
			return true
	return false


func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame
