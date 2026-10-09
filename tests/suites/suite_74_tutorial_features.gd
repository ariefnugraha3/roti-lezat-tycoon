extends TestSuite
## Fitur lanjutan diperkenalkan sekali saat pertama dijumpai (keputusan maintainer
## 2026-10-08, GDD 88.4): sorotan yang mem-pause game (kecepatan & Close Early,
## kasir staf, hujan, hari libur, toko bertingkat, Food Vlogger, roti basi,
## badge, Solo Mode) dan tur sekali di dalam layar (Market, harga, Ask a Baker,
## popup RotiFood, buang roti, menaruh alat baru).


func tests() -> Array:
	return [
		{"id": "ACC_88_TUTORIAL_FEATURE_TIPS", "name": "88.4 each feature tip fires once on its first occasion: speed and Close Early on the first opening after Day 1, a working cashier, rain, a coming holiday, a two-floor shop, a Food Vlogger, the first stale shelf, the first badge (held until the next day during a guided step), Solo Mode; the price tip no longer shows while prices are locked; nothing shows once the tutorial is skipped or hints are off", "fn": _feature_tips},
		{"id": "ACC_88_TUTORIAL_FEATURE_SPOTLIGHT_UI", "name": "88.4, 27.5 the feature spotlights pause the game and light up their target: the speed row and Close Early, the hired cashier at their lane, the weather icon, the Food Vlogger, the stale shelf, the Decoration Mode tile and the Solo Mode label", "fn": _feature_ui},
		{"id": "ACC_88_TUTORIAL_SCREEN_TOURS", "name": "88.3, 88.4 when the Market opens the summary spotlights Open Market; the Market tours ingredients, buying, equipment and upgrades, switching tabs itself; the Recipe Book tours the price once prices unlock and Ask a Baker once a Kitchen Assistant works; RotiFood tours Pack and Reject; the shelf detail tours Discard; each tour shows once", "fn": _screen_tours},
		{"id": "ACC_88_TUTORIAL_NEW_SHOP_UI", "name": "88.4 the first day at a two-floor shop spotlights the floor buttons and the stairs door, and new equipment from the Market opens Decoration Mode with a tip that leaves once it is placed", "fn": _new_shop_ui},
	]


func _key(s: SimulationRoot) -> String:
	return str(s.tutorial.prompt.get("key", ""))


func _spot(s: SimulationRoot) -> String:
	return str(s.tutorial.prompt.get("spotlight", ""))


func _spot_keys(kind: StringName) -> Array:
	var out: Array = []
	for st: Variant in TutorialManager.spotlight_steps(kind):
		out.append(str((st as Array)[0]))
	return out


## Tutup semua tip yang menunggu (tanpa langkah terpandu).
func _clear(s: SimulationRoot) -> void:
	for i in 12:
		if s.tutorial.prompt.is_empty() or bool(s.tutorial.prompt.get("guided", false)):
			return
		s.tutorial.dismiss()


func _first_holiday(s: SimulationRoot) -> int:
	for d in range(2, 120):
		if s.weather.is_holiday(d):
			return d
	return -1


func _id_of(role: StringName) -> StringName:
	for st: StaffDefinition in DataRegistry.staff_list():
		if st.role_id == role:
			return st.id
	return &""


func _feature_tips() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7401)
	s.tutorial.dismiss()
	s.tutorial._set_step(&"")
	_clear(s)
	# Harga masih terkunci di Hari 2: tip lamanya tidak muncul lagi.
	s.time.day = 2
	s.tutorial.on_event(&"pricing_opened")
	eq(_key(s), "", "opening the Recipe Book no longer shows the price tip while prices are locked")
	# Pembukaan pertama setelah Hari 1: kecepatan dan Close Early.
	s.tutorial.on_event(&"store_open")
	eq(_key(s), "tut_speed", "the first opening after Day 1 explains speed")
	eq(_spot(s), "speed_close", "as a spotlight")
	eq(_spot_keys(&"speed_close"), ["tut_speed", "tut_close_early"], "speed, then Close Early")
	check(bool(s.tutorial.prompt.get("modal", false)), "that pauses the game")
	_clear(s)
	s.tutorial.on_event(&"store_open")
	check(_key(s) != "tut_speed", "only once")
	_clear(s)
	# Kasir staf yang bekerja saat toko buka.
	s.staff.lane_assign[_id_of(&"cashier")] = &"lane_b"
	s.tutorial.on_event(&"store_open")
	eq(_key(s), "tut_cashier_staff", "a working cashier is explained when the shop opens")
	eq(_spot(s), "cashier_staff", "with a spotlight on them")
	s.staff.lane_assign.clear()
	_clear(s)
	# Hujan dan hari libur di awal hari.
	s.weather.today = &"weather_rain"
	s.tutorial._day_tips()
	eq(_key(s), "tut_weather_rain", "the first rainy day is explained")
	eq(_spot(s), "weather_rain", "on the weather icon")
	_clear(s)
	s.tutorial._day_tips()
	check(_key(s) != "tut_weather_rain", "only once")
	_clear(s)
	s.weather.today = &"weather_sunny"
	var h: int = _first_holiday(s)
	check(h > 0, "the calendar has a holiday")
	s.time.day = h - 1
	s.tutorial._day_tips()
	eq(_key(s), "tut_holiday", "a coming holiday is explained")
	eq(_spot(s), "holiday", "on the countdown")
	_clear(s)
	s.time.day = 2
	# Food Vlogger yang masuk (tip kesabaran pembeli pertama sudah tampil).
	s.tutorial.done["tut_patience"] = true
	var c := Customer.new()
	c.archetype = &"customer_critic"
	c.is_critic = true
	s.tutorial.on_customer_entered(c)
	eq(_key(s), "tut_critic", "the first Food Vlogger is explained")
	eq(_spot(s), "critic", "with a spotlight on them")
	_clear(s)
	# Roti basi pertama: raknya ikut dicatat.
	var shelf: int = s.equipment.placed_list(&"display")[0].iid
	s.tutorial.on_freshness_changed(&"STALE", shelf)
	eq(_key(s), "tut_stale", "the first stale bread is explained")
	eq(int(s.tutorial.prompt.get("target_iid", -1)), shelf, "on its shelf")
	_clear(s)
	s.tutorial.on_freshness_changed(&"UNSALEABLE", shelf)
	eq(_key(s), "", "only once")
	# Badge: ditunda selama langkah terpandu, lalu tampil di awal hari berikutnya.
	s.tutorial.guided_step = &"serve"
	s.tutorial.on_event(&"achievement")
	eq(_key(s), "", "a badge during a guided step waits")
	check(s.tutorial.done.has("pending_badge"), "for the next day")
	s.tutorial.guided_step = &""
	s.tutorial._day_tips()
	eq(_key(s), "tut_badge", "the next morning the badge is explained")
	eq(_spot(s), "badge", "on the Decoration Mode tile")
	check(not s.tutorial.done.has("pending_badge"), "and no longer waits")
	_clear(s)
	s.tutorial.on_event(&"achievement")
	eq(_key(s), "", "only once")
	# Solo Mode setelah kunjungan Pak Lurah.
	s.bailout.solo_mode = true
	s.tutorial.on_event(&"bailout_seen")
	eq(_key(s), "tut_solo", "Solo Mode is explained after Pak Lurah's visit")
	eq(_spot(s), "solo", "on its label")
	s.bailout.solo_mode = false
	_clear(s)
	# Tur di dalam layar tercatat sekali.
	check(s.tutorial.screen_tour(&"market"), "the Market tour is still to come")
	s.tutorial.mark_tour(&"market")
	check(not s.tutorial.screen_tour(&"market"), "once shown, never again")
	# Bantuan dimatikan (Hari 4+) atau tutorial dilewati: tidak ada apa pun.
	s.time.day = 5
	var was: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", false)
	check(not s.tutorial.screen_tour(&"discard"), "no screen tours with hints off")
	s.tutorial.on_event(&"bailout_seen")
	eq(_key(s), "", "and no spotlights")
	SettingsManager.set_value("tutorial_hints", was)
	var t: SimulationRoot = new_sim(7402)
	t.tutorial.skip()
	t.weather.today = &"weather_rain"
	t.tutorial._day_tips()
	t.tutorial.on_event(&"store_open")
	eq(t.tutorial.prompt, {}, "a skipped tutorial shows nothing")
	check(not t.tutorial.screen_tour(&"market"), "and runs no screen tours")
	free_sim(s)
	free_sim(t)


# ===========================================================================
# UI
# ===========================================================================

func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_tutorial_features"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", profile_name)
	await runner.get_tree().process_frame
	PauseManager.clear_all()
	game.playing = false
	game.modals.close_all()
	game.sim.tutorial.dismiss()
	game.sim.tutorial._set_step(&"")
	game.sim.tutorial.done["storage_opened"] = true
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


func _spotlight(game: GameRoot) -> TutorialSpotlight:
	for c: Node in game.modals.get_children():
		if c is TutorialSpotlight and not c.is_queued_for_deletion():
			return c
	return null


func _screen(game: GameRoot, type: Variant) -> Node:
	for c: Node in game.modals.get_children():
		if is_instance_of(c, type) and not c.is_queued_for_deletion():
			return c
	return null


func _covers(m: CoachMarks, want: Rect2, what: String) -> void:
	var inv: Transform2D = m.get_global_transform().affine_inverse()
	var r: Rect2 = (inv * want).intersection(Rect2(Vector2.ZERO, m.size))
	check(m.hole().has_area() and r.has_area() and m.hole().grow(1.0).encloses(r),
		"%s is spotlighted (hole %s, target %s)" % [what, m.hole(), r])


func _ctl(c: Control) -> Rect2:
	return c.get_global_rect() if c != null else Rect2()


## Sorotan yang sedang terbuka: periksa tiap langkah lalu tutup.
func _check_spotlight(game: GameRoot, keys: Array, targets: Array, what: String) -> void:
	game.hud._refresh_all()
	await _frames(3)
	var spot: TutorialSpotlight = _spotlight(game)
	check(spot != null and spot.marks() != null, "%s: the spotlight opens" % what)
	if spot == null or spot.marks() == null:
		return
	check(PauseManager.is_paused(), "%s: the game pauses" % what)
	var m: CoachMarks = spot.marks()
	var spot_id: int = spot.get_instance_id()
	eq(m.step_count(), keys.size(), "%s: %d stops" % [what, keys.size()])
	for i in keys.size():
		await _frames(1)
		eq(m.text(), Tx.t(str(keys[i])), "%s stop %d text" % [what, i + 1])
		_covers(m, (targets[i] as Callable).call(), "%s stop %d" % [what, i + 1])
		m.next_button().pressed.emit()
	await _frames(2)
	# Sorotan berikutnya yang mengantre boleh langsung terbuka. Objek yang sudah
	# dibebaskan sama dengan null, jadi bandingkan id instance-nya.
	var now: TutorialSpotlight = _spotlight(game)
	check(now == null or now.get_instance_id() != spot_id, "%s: Got it closes it" % what)


func _feature_ui() -> void:
	var game: GameRoot = await _boot("Tutorial Features")
	var sim: SimulationRoot = game.sim
	var hud: HUD = game.hud
	var world: WorldView = game.world
	sim.demand.scripted_orders.clear()
	sim.demand.scripted_window_shoppers.clear()
	# Rekrut kasir setelah tutup, lalu Hari 2.
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	eq(sim.staff.hire(_id_of(&"cashier")), &"", "hire a Cashier Assistant after closing")
	check(sim.continue_to_next_day(), "on to Day 2")
	game.modals.close_all()
	sim.tutorial.prompt = {}
	sim.demand.scripted_walkins.clear()
	sim.demand.scripted_orders.clear()
	sim.demand.scripted_window_shoppers.clear()
	run_until(sim, sim.time.open_time + 1.0)
	check(sim.staff.any_cashier_working(), "the cashier works today")
	await _check_spotlight(game, ["tut_speed", "tut_close_early"], [
		func() -> Rect2: return _ctl(hud.speed_row()),
		func() -> Rect2: return _ctl(hud.close_early_button()),
	], "speed")
	var sid: StringName = sim.staff.lane_assign.keys()[0]
	var lane: QueueLane = sim.queue.lane(StringName(str(sim.staff.lane_assign[sid])))
	await _check_spotlight(game, ["tut_cashier_staff"], [
		func() -> Rect2: return world.screen_rect_of([world.views.get((sim.staff.actors[sid] as SimActor).id)]),
	], "cashier")
	var lane_rect: Rect2 = world.screen_rect_of([world.counter_of(lane)])
	check(lane_rect.has_area(), "the cashier's counter is on screen (%s)" % lane_rect)
	game.modals.close_all()
	sim.tutorial.prompt = {}
	sim.tutorial._queue.clear()
	await _frames(1)
	# Hujan.
	sim.weather.today = &"weather_rain"
	sim.tutorial._day_tips()
	await _check_spotlight(game, ["tut_weather_rain"], [func() -> Rect2: return _ctl(hud.weather_icon())], "rain")
	sim.weather.today = &"weather_sunny"
	# Food Vlogger masuk toko (tip kesabaran pembeli pertama sudah tampil).
	game.modals.close_all()
	sim.tutorial.prompt = {}
	sim.tutorial._queue.clear()
	sim.tutorial.done["tut_patience"] = true
	stock(sim, &"recipe_plain_fried_bread", 6)
	check(sim.customers.try_admit({"archetype": &"customer_critic"}), "a Food Vlogger walks in")
	var critic: Customer = null
	for c: Customer in sim.customers.sorted():
		if c.is_critic:
			critic = c
	# Ia datang dulu lewat trotoar (GDD 20.1); tipnya muncul begitu ia masuk.
	check(critic != null and walk_in(sim, critic), "the Food Vlogger reaches the door")
	await _frames(2)
	await _check_spotlight(game, ["tut_critic"], [func() -> Rect2: return world.screen_rect_of([world.views.get(critic.id)])], "critic")
	# Roti basi di rak.
	var shelf: int = sim.equipment.placed_list(&"display")[0].iid
	stock(sim, &"recipe_plain_loaf", 6, 1, shelf)
	sim.display.age_all(400.0, false)
	await _check_spotlight(game, ["tut_stale"], [func() -> Rect2: return world.screen_rect_of([world.furniture.get(shelf)])], "stale shelf")
	# Badge pertama.
	sim.tutorial.on_event(&"achievement")
	await _check_spotlight(game, ["tut_badge"], [func() -> Rect2: return _ctl(hud.decoration_button())], "badge")
	# Solo Mode.
	sim.bailout.solo_mode = true
	sim.tutorial.on_event(&"bailout_seen")
	await _check_spotlight(game, ["tut_solo"], [func() -> Rect2: return _ctl(hud.solo_label())], "solo")
	sim.bailout.solo_mode = false
	await _finish(game)


func _screen_tours() -> void:
	var game: GameRoot = await _boot("Tutorial Screens")
	var sim: SimulationRoot = game.sim
	sim.demand.scripted_walkins.clear()
	sim.demand.scripted_orders.clear()
	sim.demand.scripted_window_shoppers.clear()
	run_until(sim, sim.time.open_time + 1.0)
	sim.supply.unlock_market()
	check(sim.close_early(), "the shop closes")
	await _frames(3)
	# Tanpa pelajaran Staff Hari 1: Open Market yang disorot.
	sim.tutorial._set_step(&"")
	var tip: UIScreen = game.modals.top()
	if tip is TutorialModal:
		(tip as TutorialModal)._ok()
	await runner.get_tree().create_timer(0.6).timeout
	await _frames(2)
	var summary: DailySummaryScreen = _screen(game, DailySummaryScreen) as DailySummaryScreen
	check(summary != null and summary.tour() != null, "the summary spotlights Open Market")
	if summary == null or summary.tour() == null:
		await _finish(game)
		return
	var open_btn: Button = summary.find_child("OpenMarket", true, false) as Button
	_covers(summary.tour(), open_btn.get_global_rect(), "Open Market")
	eq(summary.tour().text(), Tx.t("tut_close_market"), "the Market tip")
	open_btn.pressed.emit()
	await _frames(3)
	# Market: empat langkah, tab berpindah sendiri.
	var market: MarketScreen = _screen(game, MarketScreen) as MarketScreen
	check(market != null and market.tour() != null, "the Market opens with its tour")
	if market != null and market.tour() != null:
		var m: CoachMarks = market.tour()
		var plan: Array = [[0, ["IngredientRows"], "tut_market_ingredients"], [0, ["BuyRow", "DeliveryNote"], "tut_market_buy"],
			[1, ["EquipmentRows"], "tut_market_equipment"], [2, ["UpgradeRows", "Upgrade"], "tut_market_upgrade"]]
		eq(m.step_count(), plan.size(), "four stops")
		for i in plan.size():
			await _frames(2)
			eq(market._tab, int(plan[i][0]), "stop %d shows its tab" % (i + 1))
			eq(m.text(), Tx.t(str(plan[i][2])), "stop %d text" % (i + 1))
			for n: Variant in plan[i][1]:
				var node: Control = market.find_child(str(n), true, false) as Control
				check(node != null, "stop %d: %s exists" % [i + 1, n])
				if node != null:
					var area: Control = node.get_parent() as Control if node.get_parent() is ScrollContainer else node
					_covers(m, area.get_global_rect(), "stop %d %s" % [i + 1, n])
			m.next_button().pressed.emit()
		await _frames(2)
		market.close()
		await _frames(2)
	var again: MarketScreen = game.modals.open(&"market") as MarketScreen
	await _frames(3)
	check(again.tour() == null, "the Market tour shows once")
	again.close()
	# Buku Resep: harga terbuka (malam Hari 3) dan ada Kitchen Assistant.
	sim.time.day = 3
	check(not sim.pricing.prices_locked(), "prices unlock after closing on Day 3")
	eq(sim.staff.hire(_id_of(&"baker")), &"", "hire a Kitchen Assistant")
	var rb: RecipeBookScreen = game.modals.open(&"recipe_book") as RecipeBookScreen
	await _frames(4)
	check(rb.tour() != null, "the Recipe Book opens a tour")
	if rb.tour() != null:
		var t2: CoachMarks = rb.tour()
		eq(t2.step_count(), 2, "price, then Ask a Baker")
		eq(t2.text(), Tx.t("tut_pricing"), "the price stop")
		_covers(t2, (rb._detail.find_child("PriceRow", true, false) as Control).get_global_rect(), "the price row")
		t2.next_button().pressed.emit()
		await _frames(2)
		eq(t2.text(), Tx.t("tut_ask_baker"), "the Ask a Baker stop")
		_covers(t2, (rb._detail.find_child("AskBaker", true, false) as Control).get_global_rect(), "Ask a Baker")
		t2.next_button().pressed.emit()
		await _frames(2)
	rb.close()
	var rb2: RecipeBookScreen = game.modals.open(&"recipe_book") as RecipeBookScreen
	await _frames(4)
	check(rb2.tour() == null, "the Recipe Book tour shows once")
	rb2.close()
	# RotiFood: sorotan pesanan pertama, lalu tur Pack dan Reject di popupnya.
	sim.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	game.hud._refresh_all()
	await _frames(3)
	var first: TutorialSpotlight = _spotlight(game)
	if first != null and first.marks() != null:
		first.marks().next_button().pressed.emit()
	await _frames(2)
	var rf: RotiFoodScreen = game.modals.open(&"rotifood") as RotiFoodScreen
	await _frames(4)
	check(rf.tour() != null, "the RotiFood popup opens a tour")
	if rf.tour() != null:
		var t3: CoachMarks = rf.tour()
		eq(t3.step_count(), 2, "Pack, then Reject")
		_covers(t3, (rf.find_child("Pack", true, false) as Control).get_global_rect(), "Pack Order")
		t3.next_button().pressed.emit()
		await _frames(2)
		_covers(t3, (rf.find_child("Reject", true, false) as Control).get_global_rect(), "Reject Order")
		t3.next_button().pressed.emit()
		await _frames(2)
	rf.close()
	# Rak dengan roti basi: sorotan rak, lalu tur Discard di detailnya.
	var shelf: int = sim.equipment.placed_list(&"display")[0].iid
	stock(sim, &"recipe_plain_loaf", 6, 0, shelf)
	sim.display.age_all(400.0, false)
	await _frames(3)
	var stale: TutorialSpotlight = _spotlight(game)
	if stale != null and stale.marks() != null:
		stale.marks().next_button().pressed.emit()
	await _frames(2)
	var dd: DisplayDetailScreen = game.modals.open(&"display_detail", {"display": shelf}) as DisplayDetailScreen
	await _frames(4)
	check(dd.tour() != null, "the shelf detail opens a tour")
	if dd.tour() != null:
		eq(dd.tour().text(), Tx.t("tut_discard"), "about Discard")
		_covers(dd.tour(), (dd.find_child("Discard", true, false) as Control).get_global_rect(), "Discard")
		dd.tour().next_button().pressed.emit()
		await _frames(2)
	dd.close()
	await _finish(game)


func _new_shop_ui() -> void:
	var game: GameRoot = await _boot("Tutorial New Shop")
	var sim: SimulationRoot = game.sim
	var hud: HUD = game.hud
	var world: WorldView = game.world
	jump_to_tier(sim, 2)
	await _frames(4)
	check(sim.world.location.is_multi_floor(), "a two-floor shop")
	# Tip lain yang mungkin mengantre di depannya ditutup dulu.
	for i in 6:
		if str(sim.tutorial.prompt.get("key", "")) == "tut_floors" or sim.tutorial.prompt.is_empty():
			break
		game.modals.close_all()
		sim.tutorial.dismiss()
		await _frames(2)
	eq(str(sim.tutorial.prompt.get("key", "")), "tut_floors", "the first day there explains the floors")
	await _check_spotlight(game, ["tut_floors", "tut_floor_stairs"], [
		func() -> Rect2: return _ctl(hud.floor_buttons()),
		func() -> Rect2: return world.screen_rect_of([world.portal_node()]),
	], "floors")
	# Alat baru dari Market: Decoration Mode dengan tip menaruhnya.
	game.modals.close_all()
	sim.tutorial.prompt = {}
	sim.tutorial._queue.clear()
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	sim.debug_add_kr(50000.0)
	# Alat dari kategori yang masih punya slot kosong di toko baru.
	var def_id: StringName = &""
	for cat: StringName in [&"display", &"mixer", &"oven"]:
		if sim.equipment.placed_count(cat) + sim.equipment.unplaced_list(cat).size() >= sim.equipment.slot_limit(cat):
			continue
		for d: EquipmentDefinition in DataRegistry.equipment_in_category(cat):
			if d.for_sale and sim.equipment.tier_allowed(d):
				def_id = d.id
				break
		if def_id != &"":
			break
	check(def_id != &"", "the new shop has a free equipment slot")
	var r: Dictionary = sim.equipment.buy(def_id)
	check(bool(r.get("ok", false)), "buy a shelf (%s)" % r)
	var deco: DecorationScreen = game.modals.open(&"decoration", {"select_iid": int(r.get("iid", -1))}) as DecorationScreen
	await _frames(4)
	var tip: PanelContainer = deco.tutorial_tip()
	check(tip != null, "Decoration Mode shows a tip")
	var says: bool = false
	if tip != null:
		for l: Node in tip.find_children("*", "Label", true, false):
			says = says or (l as Label).text == Tx.t("tut_place_equipment")
	check(says, "how to place new equipment")
	if deco._cand_reason == &"":
		deco._place()
		await _frames(2)
		check(deco.tutorial_tip() == null, "the tip leaves once it is placed")
	deco.close()
	await _frames(2)
	var r2: Dictionary = sim.equipment.buy(def_id)
	if bool(r2.get("ok", false)):
		var deco2: DecorationScreen = game.modals.open(&"decoration", {"select_iid": int(r2["iid"])}) as DecorationScreen
		await _frames(4)
		check(deco2.tutorial_tip() == null, "the tip shows once")
		deco2.close()
	await _finish(game)
