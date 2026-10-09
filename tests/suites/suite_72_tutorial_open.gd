extends TestSuite
## Tutorial Hari 1 sesudah dapur (keputusan maintainer 2026-10-08, GDD 27.5,
## 88.1): Skip to Open, tur sorotan HUD tentang rating dan pesanan RotiFood saat
## toko buka, pembeli pertama (sorotan, ke kasir, ketuk pembeli, OK, penjualan
## pertama), dan sorotan sekali untuk pengunjung lihat-lihat yang pulang,
## kejutan, dan pesanan RotiFood pertama.


func tests() -> Array:
	return [
		{"id": "ACC_88_TUTORIAL_SKIP_TO_OPEN", "name": "88.1 after the holding table the tutorial asks for Skip to Open (the button is highlighted and works); when the shop opens a spotlight tour explains the shop rating, RotiFood Stars and the RotiFood orders panel, and closing it waits for the first customer; a shop that is already open skips straight to the tour", "fn": _skip_to_open},
		{"id": "ACC_88_TUTORIAL_FIRST_BUYER", "name": "88.1 the first customer gets a spotlight (customer, then counter), then: tap the counter, wait there, tap the waiting customer, OK, and a closing tip on the first sale; tips it covers never show twice; steps already done are skipped", "fn": _first_buyer},
		{"id": "ACC_88_TUTORIAL_INFO_SPOTLIGHTS", "name": "88.1 the first window shopper who leaves, the first surprise and the first RotiFood order each get one spotlight that pauses the game; a window shopper or surprise during another modal tip waits for the next one, a RotiFood order queues", "fn": _info_spotlights},
		{"id": "ACC_88_TUTORIAL_SPOTLIGHT_UI", "name": "88.1, 27.5 the HUD pulses Skip to Open; the opening tour, first-customer, window shopper, surprise and RotiFood spotlights pause the game and dim everything but their HUD panel or world model; the order popup spotlights OK", "fn": _spotlight_ui},
	]


## Majukan simulasi sampai `cond` benar (paling lama `limit` detik-simulasi).
func _until(s: SimulationRoot, cond: Callable, limit: float = 120.0) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < limit:
		s.step(s.tick_seconds)
		t += s.tick_seconds
	return bool(cond.call())


func _key(s: SimulationRoot) -> String:
	return str(s.tutorial.prompt.get("key", ""))


func _spot_keys(kind: StringName) -> Array:
	var out: Array = []
	for st: Variant in TutorialManager.spotlight_steps(kind):
		out.append(str((st as Array)[0]))
	return out


## Toko Hari 1 yang baru buka, tutorial terpandu sudah sampai tur pembukaan.
func _open_day1(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.dismiss()
	stock(s, &"recipe_plain_loaf", 6)
	run_until(s, s.time.open_time + 1.0)
	s.tutorial._set_step(&"skip_open")
	return s


func _skip_to_open() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7201)
	s.tutorial.dismiss()
	s.tutorial._set_step(&"table")
	s.tutorial.on_event(&"tray_on_table")
	eq(s.tutorial.guided_step, &"skip_open", "after the holding table: Skip to Open")
	eq(_key(s), "tut_skip_open", "with its tip")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "skip_open", "the Skip to Open button is highlighted")
	check(not bool(s.tutorial.prompt.get("dismissable", true)), "the tip waits for the shop to open")
	eq(s.skip_to_open_block(), &"", "Skip to Open can be used")
	check(s.tutorial.allows_tap(&"display") and s.tutorial.allows_tap(&"mixer"), "every station can be tapped again")
	var guard: int = 0
	while s.skip_to_open_step(400) == &"" and guard < 2000:
		guard += 1
	eq(s.time.phase, TimeManager.OPEN, "the skip opens the shop")
	eq(s.tutorial.guided_step, &"open_tour", "the opening tour starts")
	check(bool(s.tutorial.prompt.get("modal", false)) and bool(s.tutorial.prompt.get("guided", false)), "as a guided step that pauses the game")
	eq(str(s.tutorial.prompt.get("spotlight", "")), "open_tour", "a spotlight tour")
	eq(_spot_keys(&"open_tour"), ["tut_tour_rating", "tut_tour_rotifood_rating", "tut_tour_rotifood_orders", "tut_rotifood"],
		"shop rating, RotiFood Stars, the orders panel, and why orders do not hold stock")
	for k: Variant in _spot_keys(&"open_tour"):
		check(s.tutorial.done.has(str(k)), "%s counts as shown" % k)
	# Save di tengah tur: tur yang sama tampil lagi setelah load.
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(u.tutorial.guided_step, &"open_tour", "a save keeps the tour step")
	eq(str(u.tutorial.prompt.get("spotlight", "")), "open_tour", "and its spotlight")
	free_sim(u)
	s.tutorial.dismiss()
	eq(s.tutorial.guided_step, &"buyer_wait", "closing the tour moves on")
	eq(_key(s), "tut_buyer_wait", "the first customer is on the way")
	# Toko sudah buka sebelum loyang sampai di meja: langsung tur pembukaan.
	var t: SimulationRoot = new_sim(7202)
	t.tutorial.dismiss()
	run_until(t, t.time.open_time + 1.0)
	t.tutorial._set_step(&"table")
	t.tutorial.on_event(&"tray_on_table")
	eq(t.tutorial.guided_step, &"open_tour", "an open shop skips straight to the tour")
	# Langkah dari save versi lain yang tidak dikenal lagi mengakhiri urutan.
	var d: Dictionary = json_copy(t.capture_save())
	(d["tutorial"] as Dictionary)["step"] = "table_done"
	var v: SimulationRoot = load_sim(d)
	eq(v.tutorial.guided_step, &"", "an unknown step from another version ends the guided day")
	free_sim(v)
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
	free_sim(t)


func _first_buyer() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_day1(7203)
	eq(s.tutorial.guided_step, &"open_tour", "the shop is open: the tour first")
	s.tutorial.dismiss()
	check(_until(s, func() -> bool: return s.tutorial.guided_step == &"buyer", 400.0), "the first customer walks in")
	var c: Customer = s.customers.first_buyer()
	check(c != null and not c.window_shopper, "a buyer, not a window shopper")
	check(bool(s.tutorial.prompt.get("modal", false)), "the game pauses for a spotlight")
	eq(str(s.tutorial.prompt.get("spotlight", "")), "buyer", "on the customer")
	eq(_spot_keys(&"buyer"), ["tut_buyer_enter", "tut_manual_cashier"], "the customer, then the counter")
	s.tutorial.dismiss()
	eq(_key(s), "tut_serve_counter", "then: tap the counter")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "cashier", "the counter blinks")
	check(not bool(s.tutorial.prompt.get("dismissable", true)), "no Got it: tap the counter")
	check(s.tutorial.order_tour(), "the order popup would spotlight OK")
	var lane: QueueLane = s.queue.main_lane()
	check(s.player.tap_cashier(lane.id, false), "tap the counter")
	check(_until(s, func() -> bool: return s.tutorial.guided_step != &"serve"), "the player reaches the counter")
	check(s.tutorial.guided_step in [&"serve_wait", &"serve_tap"], "and waits there (%s)" % s.tutorial.guided_step)
	check(s.tutorial.done.has("tut_patience"), "the patience tip counts as shown")
	check(_until(s, func() -> bool: return s.tutorial.guided_step == &"serve_tap", 400.0), "the customer reaches the counter")
	eq(_key(s), "tut_serve_tap", "tap them to see the order")
	check(s.player.tap_customer(lane.service_occupant), "tap the customer")
	check(_until(s, func() -> bool: return s.ui_requests.customer_order != &""), "the order pops up")
	check(s.cashier.confirm_manual(s.ui_requests.customer_order), "OK")
	s.ui_requests.customer_order = &""
	eq(_key(s), "tut_serve_pack", "stay while the bread is packed")
	check(_until(s, func() -> bool: return s.tutorial.guided_step == &"sold", 60.0), "the first sale")
	eq(_key(s), "tut_first_sale", "a closing tip")
	check(bool(s.tutorial.prompt.get("dismissable", false)), "with Got it")
	check(s.tutorial.done.has("tut_income"), "the income tip counts as shown")
	s.tutorial.dismiss()
	eq(s.tutorial.guided_step, &"", "the guided Day 1 is over")
	eq(s.tutorial.prompt, {}, "no tip is left")
	# Pemain sudah di kasir sebelum pembeli datang: langkah ke kasir dilewati.
	var t: SimulationRoot = _open_day1(7204)
	t.tutorial.dismiss()
	check(t.player.tap_cashier(t.queue.main_lane().id, false), "walk to the counter early")
	check(_until(t, func() -> bool: return t.player.is_manning_lane(t.queue.main_lane().id)), "standing at the counter")
	check(_until(t, func() -> bool: return t.tutorial.guided_step == &"buyer", 400.0), "the first customer walks in")
	t.tutorial.dismiss()
	eq(t.tutorial.guided_step, &"serve_wait", "already at the counter: straight to waiting")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
	free_sim(t)


func _info_spotlights() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7205)
	s.tutorial.dismiss()
	# Tanpa jadwal Hari 1, supaya tidak ada tip pembeli lain di tengah tes.
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	run_until(s, s.time.open_time + 1.0)
	s.tutorial._set_step(&"")
	# Pengunjung lihat-lihat yang pulang saat tip modal lain tampil: menunggu.
	s.tutorial._show("tut_freshness", true)
	s.tutorial.on_window_shopper_left()
	eq(_key(s), "tut_freshness", "a window shopper leaving during another modal tip waits")
	check(not s.tutorial.done.has("tut_window_shopper"), "and is not counted as shown")
	s.tutorial.dismiss()
	check(s.customers.try_admit_window_shopper(&"customer_generic"), "a window shopper walks in")
	var w: Customer = null
	for c: Customer in s.customers.sorted():
		if c.window_shopper:
			w = c
	check(_until(s, func() -> bool: return _key(s) == "tut_window_shopper", 200.0), "it leaves without buying: a spotlight explains")
	eq(str(s.tutorial.prompt.get("spotlight", "")), "window_shopper", "on the window shopper")
	check(bool(s.tutorial.prompt.get("modal", false)), "pausing the game")
	check(w != null and w.state == Customer.LEAVING, "while they walk out")
	s.tutorial.dismiss()
	s.tutorial.on_window_shopper_left()
	eq(_key(s), "", "only once")
	# Kejutan: sekali, dan menunggu bila tip modal lain tampil.
	s.tutorial._show("tut_burn_risk", true)
	s.tutorial.on_surprise()
	eq(_key(s), "tut_burn_risk", "a surprise during another modal tip waits for the next one")
	s.tutorial.dismiss()
	s.tutorial.on_surprise()
	eq(_key(s), "tut_surprise", "the first surprise is explained")
	eq(str(s.tutorial.prompt.get("spotlight", "")), "surprise", "with a spotlight on the cast")
	s.tutorial.dismiss()
	s.tutorial.on_surprise()
	eq(_key(s), "", "only once")
	# Pesanan RotiFood pertama: sorotan pada pesanannya, mengantre di belakang tip modal.
	s.tutorial._show("tut_summary", true)
	s.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	eq(_key(s), "tut_summary", "the RotiFood spotlight waits behind a modal tip")
	s.tutorial.dismiss()
	eq(_key(s), "tut_rotifood_first", "then the first RotiFood order is explained")
	eq(str(s.tutorial.prompt.get("spotlight", "")), "rotifood_order", "with a spotlight on the order")
	s.tutorial.dismiss()
	s.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	eq(_key(s), "", "only once")
	# Tutorial dilewati: tidak ada sorotan sama sekali.
	var t: SimulationRoot = new_sim(7206)
	t.tutorial.skip()
	t.tutorial.on_window_shopper_left()
	t.tutorial.on_surprise()
	eq(t.tutorial.prompt, {}, "a skipped tutorial shows nothing")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
	free_sim(t)


# ===========================================================================
# UI
# ===========================================================================

func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_tutorial_open"
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


## Sorotan tutorial yang sedang terbuka, atau null.
func _spot(game: GameRoot) -> TutorialSpotlight:
	var top: UIScreen = game.modals.top()
	return top as TutorialSpotlight if top is TutorialSpotlight else null


## Lubang sorotan menutupi kotak `want` (koordinat kanvas), dan tur menahan semua
## ketukan lain.
func _covers(m: CoachMarks, want: Rect2, what: String) -> void:
	var inv: Transform2D = m.get_global_transform().affine_inverse()
	var r: Rect2 = inv * want
	check(m.hole().has_area() and m.hole().grow(1.0).encloses(r.intersection(Rect2(Vector2.ZERO, m.size))),
		"%s is spotlighted (hole %s, target %s)" % [what, m.hole(), r])


func _spotlight_ui() -> void:
	var game: GameRoot = await _boot("Tutorial Open")
	var sim: SimulationRoot = game.sim
	var hud: HUD = game.hud
	var world: WorldView = game.world
	game.modals.close_all()
	sim.tutorial.dismiss()
	stock(sim, &"recipe_plain_loaf", 6)
	# Pesanan dan pengunjung lihat-lihat terjadwal dipicu sendiri di bawah.
	sim.demand.scripted_orders.clear()
	sim.demand.scripted_window_shoppers.clear()
	# Skip to Open berdenyut.
	sim.tutorial._set_step(&"skip_open")
	await _frames(2)
	check(hud.skip_button().get_node_or_null(TutorialPulse.NODE_NAME) != null, "the Skip to Open button pulses")
	check(hud.tutorial_hint().visible, "with the tip")
	check(not (hud.tutorial_hint().find_child("GotIt", true, false) as Button).visible, "and no Got it")
	# Toko buka: tur pembukaan.
	run_until(sim, sim.time.open_time + 1.0)
	await _frames(3)
	check(hud.skip_button().get_node_or_null(TutorialPulse.NODE_NAME) == null, "the button stops pulsing")
	var spot: TutorialSpotlight = _spot(game)
	check(spot != null, "the opening tour opens")
	check(PauseManager.is_paused(), "and pauses the game")
	if spot == null or spot.marks() == null:
		await _finish(game)
		return
	var m: CoachMarks = spot.marks()
	eq(m.step_count(), 4, "four stops")
	var want: Array = [hud.rating_chip(), hud.rotifood_rating_chip(), hud.rotifood_panel(), hud.rotifood_panel()]
	for i in want.size():
		await _frames(1)
		eq(m.index(), i, "stop %d" % (i + 1))
		eq(m.text(), Tx.t(str(_spot_keys(&"open_tour")[i])), "stop %d text" % (i + 1))
		_covers(m, (want[i] as Control).get_global_rect(), "stop %d" % (i + 1))
		check(not m.hole().intersects(hud.quick_menu().get_global_rect()), "stop %d: the Quick Menu stays dimmed" % (i + 1))
		eq(m.next_button().text, Tx.t("ui_tutorial_got_it") if i == want.size() - 1 else Tx.t("ui_tour_next"), "stop %d button" % (i + 1))
		m.next_button().pressed.emit()
	await _frames(2)
	check(_spot(game) == null, "Got it closes the tour")
	check(not PauseManager.is_paused(), "and the game runs again")
	eq(sim.tutorial.guided_step, &"buyer_wait", "the tutorial waits for the first customer")
	check(hud.tutorial_hint().visible, "with a tip in the HUD")
	# Pembeli pertama: sorotan pada pembeli, lalu meja kasir.
	check(_until(sim, func() -> bool: return sim.tutorial.guided_step == &"buyer", 400.0), "the first customer walks in")
	await _frames(3)
	spot = _spot(game)
	check(spot != null and spot.marks() != null, "the customer spotlight opens")
	if spot != null and spot.marks() != null:
		m = spot.marks()
		var c: Customer = sim.customers.first_buyer()
		_covers(m, world.screen_rect_of([world.views.get(c.id)]), "the customer")
		_covers(m, world.screen_rect_of([world.furniture.get(c.target_display)]), "the shelf they head to")
		m.next_button().pressed.emit()
		await _frames(1)
		_covers(m, world.screen_rect_of([world.main_counter()]), "the counter")
		m.next_button().pressed.emit()
		await _frames(2)
	eq(sim.tutorial.guided_step, &"serve", "then: tap the counter")
	check(world.blink_target() == world.main_counter(), "the counter blinks")
	# Popup pesanan menyorot OK.
	check(sim.player.tap_cashier(sim.queue.main_lane().id, false), "tap the counter")
	check(_until(sim, func() -> bool: return sim.tutorial.guided_step == &"serve_tap", 600.0), "the customer waits at the counter")
	await _frames(1)
	check(world.blink_target() == world.main_counter(), "the counter blinks again")
	check(sim.player.tap_customer(sim.queue.main_lane().service_occupant), "tap the customer")
	await _frames(3)
	check(game.modals.is_open(&"customer_order"), "the order pops up")
	var order: CustomerOrderScreen = game.modals.top() as CustomerOrderScreen
	check(order != null and order.tour() != null, "with a spotlight")
	if order != null and order.tour() != null:
		var ok: Button = order.find_child("Wrap", true, false) as Button
		_covers(order.tour(), ok.get_global_rect(), "the OK button")
		_covers(order.tour(), (order.find_child("Total", true, false) as Control).get_global_rect(), "the total")
		check(not order.tour().next_button().visible, "no Next: the player taps OK")
		eq(order.tour().text(), Tx.t("tut_order_ok"), "and the tip says so")
		ok.pressed.emit()
		await _frames(2)
	check(_until(sim, func() -> bool: return sim.tutorial.guided_step == &"sold", 60.0), "the first sale")
	await _frames(1)
	check((hud.tutorial_hint().find_child("GotIt", true, false) as Button).visible, "the closing tip has Got it")
	sim.tutorial.dismiss()
	await _frames(1)
	# Pengunjung lihat-lihat yang pulang.
	check(sim.customers.try_admit_window_shopper(&"customer_generic"), "a window shopper walks in")
	check(_until(sim, func() -> bool: return _spot(game) != null, 300.0), "it leaves without buying and a spotlight opens")
	# Gelembung celetukannya muncul dengan animasi pop: tunggu sampai diam.
	await runner.get_tree().create_timer(0.35).timeout
	await _frames(3)
	spot = _spot(game)
	if spot != null and spot.marks() != null:
		m = spot.marks()
		var w: Customer = null
		for c2: Customer in sim.customers.sorted():
			if c2.window_shopper:
				w = c2
		check(w != null, "the window shopper is still in the shop")
		if w != null:
			_covers(m, world.screen_rect_of([world.views.get(w.id)]), "the window shopper")
			var bubble: ThoughtBubble = world.shopper_bubble(w.id)
			if bubble != null and bubble.is_showing():
				_covers(m, bubble.panel_rect(), "their funny line")
		eq(m.text(), Tx.t("tut_window_shopper"), "the window shopper tip")
		check(not m.skip_button().visible and m.next_button().text == Tx.t("ui_tutorial_got_it"), "one stop: just Got it")
		check(PauseManager.is_paused(), "the game waits")
		m.next_button().pressed.emit()
		await _frames(2)
	check(_spot(game) == null and not PauseManager.is_paused(), "Got it closes it")
	# Kejutan.
	check(world.surprises.start(&"mascot"), "a surprise starts")
	# Maskot datang dulu lewat trotoar (GDD 31.9, 20.1); tipnya baru muncul
	# setelah ia masuk toko.
	var walked: float = 0.0
	while _key(sim) != "tut_surprise" and walked < 90.0:
		world.surprises.update(0.25)
		walked += 0.25
	await _frames(3)
	spot = _spot(game)
	check(spot != null and spot.marks() != null, "the first surprise gets a spotlight")
	if spot != null and spot.marks() != null:
		m = spot.marks()
		_covers(m, world.screen_rect_of(world.surprises.cast_nodes()), "the mascot")
		eq(m.text(), Tx.t("tut_surprise"), "the surprise tip")
		m.next_button().pressed.emit()
		await _frames(2)
	world.surprises.abort()
	# Pesanan RotiFood pertama.
	sim.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	hud._refresh_all()
	await _frames(3)
	spot = _spot(game)
	check(spot != null and spot.marks() != null, "the first RotiFood order gets a spotlight")
	if spot != null and spot.marks() != null:
		hud._refresh_all()
		await _frames(1)
		var row: Control = hud.first_order_row()
		check(row != null, "the order shows in the panel")
		if row != null:
			_covers(spot.marks(), row.get_global_rect(), "the new order")
		_covers(spot.marks(), hud.rotifood_button().get_global_rect(), "the ringing RotiFood button")
		spot.marks().next_button().pressed.emit()
		await _frames(2)
	check(_spot(game) == null, "and Got it closes it")
	await _finish(game)
