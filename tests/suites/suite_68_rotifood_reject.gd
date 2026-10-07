extends TestSuite
## Tolak pesanan RotiFood (keputusan maintainer 2026-10-06, GDD 22.10, 25.3):
## pesanan yang belum dikemas boleh ditolak, juga saat driver-nya sudah
## menunggu di toko. RotiFood Stars turun 0,05, lebih ringan daripada 0,2 bila
## driver menyerah karena pesanannya tidak dikemas.

const REJECT_STARS: float = 0.05


func tests() -> Array:
	return [
		{"id": "ACC_22_ROTIFOOD_REJECT", "name": "22.10 an unpacked RotiFood order can be rejected: it is cancelled at once with no revenue, RotiFood Stars drop 0.05 while the store rating stays, and it counts as rejected (not cancelled) in the Daily Summary, the lifetime stats and the save", "fn": _reject},
		{"id": "ACC_22_ROTIFOOD_REJECT_DRIVER", "name": "22.10 rejecting while the driver waits in the shop sends the driver away at once for 0.05 stars instead of the 0.2 of a driver giving up; an order waiting for stock can be rejected, a packed one cannot", "fn": _driver},
		{"id": "ACC_22_ROTIFOOD_REJECT_UI", "name": "22.10 the order popup shows Reject Order beside Pack for unpacked orders, asks first with the star cost, and then shows the next order", "fn": _ui},
	]


func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	return s


func _reject() -> void:
	near(-float((DataRegistry.bal("rating.rotifood_events") as Dictionary)["order_rejected"]), REJECT_STARS, 0.0001,
		"rejecting costs 0.05 RotiFood stars")
	var s: SimulationRoot = _open_store(6801)
	var rf0: float = s.reputation.rotifood
	var ph0: float = s.reputation.physical
	var kr0: float = s.economy.balance
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	check(s.rotifood.can_reject(o.order_id), "a new order can be rejected")
	check(s.rotifood.reject(o.order_id), "and is rejected")
	eq(o.state, DeliveryOrder.CANCELLED, "it is cancelled at once")
	eq(o.cancel_reason, &"rejected", "as rejected by the player")
	near(s.reputation.rotifood, rf0 - REJECT_STARS, 0.0001, "RotiFood Stars drop 0.05")
	near(s.reputation.physical, ph0, 0.0001, "the store rating stays")
	near(s.economy.balance, kr0, 0.0001, "no revenue")
	eq(s.rotifood.active_orders().size(), 0, "it leaves the order list")
	eq(s.rotifood.rejected_today, 1, "one order rejected today")
	eq(s.rotifood.cancelled_today, 0, "not counted as cancelled")
	near(float(s.statistics.stats["total_rotifood_orders_rejected"]), 1.0, 0.0001, "the lifetime stats count it")
	near(float(s.statistics.stats["total_rotifood_orders_expired"]), 0.0, 0.0001, "not as expired")
	check(not s.rotifood.reject(o.order_id), "an order is rejected only once")
	near(s.reputation.rotifood, rf0 - REJECT_STARS, 0.0001, "so the stars drop only once")
	# Sesudahnya tidak ada driver yang datang dan tidak ada penalti susulan.
	s.run_for(240.0)
	eq(o.driver, null, "no driver comes for it")
	near(s.reputation.rotifood, rf0 - REJECT_STARS, 0.0001, "and no further penalty")
	# Save & load menyimpan hitungannya.
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(u.rotifood.rejected_today, 1, "a save keeps today's rejected count")
	eq(u.check_invariants(), "", "invariants after load")
	free_sim(u)
	# Daily Summary: baris tersendiri.
	s.time.time_seconds = s.time.close_time - 1.0
	for i in 40:
		s.step(s.tick_seconds)
	eq(s.time.phase, TimeManager.SUMMARY, "the day closes")
	eq(int(s.reports.last_report.get("delivery_rejected", -1)), 1, "the Daily Summary reports one rejected order")
	eq(int(s.reports.last_report.get("delivery_cancelled", -1)), 0, "and no cancelled one")
	check(DataRegistry.has_text("ui_summary_deliveries_rejected") and DataRegistry.has_text("ui_stat_total_rotifood_orders_rejected"),
		"with English labels for the summary and the stats screen")
	free_sim(s)


func _driver() -> void:
	var s: SimulationRoot = _open_store(6802)
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 1)
	o.driver_arrival_time = s.time.sim_seconds
	var t: float = 0.0
	while t < 120.0 and not (o.driver_phase in [&"queued", &"at_service"]):
		s.step(s.tick_seconds)
		t += s.tick_seconds
	check(o.driver != null and o.driver_phase in [&"queued", &"at_service"], "the driver waits in the shop (%s)" % o.driver_phase)
	check(s.rotifood.can_reject(o.order_id), "an order whose driver waits can still be rejected")
	var rf0: float = s.reputation.rotifood
	check(s.rotifood.reject(o.order_id), "rejected")
	near(s.reputation.rotifood, rf0 - REJECT_STARS, 0.0001, "for 0.05 stars")
	eq(o.driver_phase, &"leaving", "the driver leaves at once")
	eq(s.queue.lane_of(o.driver_id()), null, "freeing the queue spot")
	t = 0.0
	while t < 120.0 and o.driver_phase != &"gone":
		s.step(s.tick_seconds)
		t += s.tick_seconds
	eq(o.driver_phase, &"gone", "and walks out")
	near(s.reputation.rotifood, rf0 - REJECT_STARS, 0.0001, "never the 0.2 of a driver giving up")
	eq(s.check_invariants(), "", "invariants")
	# Menunggu stok: boleh ditolak.
	var o2: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 30)
	check(not s.rotifood.pack(o2.order_id), "an order without stock cannot be packed")
	eq(o2.state, DeliveryOrder.WAITING_FOR_STOCK, "and waits for stock")
	check(s.rotifood.reject(o2.order_id), "it can be rejected")
	# Sudah dikemas: tidak bisa ditolak lagi.
	stock(s, &"recipe_plain_loaf", 6)
	var o3: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	check(s.rotifood.pack(o3.order_id), "an order with stock is packed")
	check(not s.rotifood.can_reject(o3.order_id), "a packed order cannot be rejected")
	var rf1: float = s.reputation.rotifood
	check(not s.rotifood.reject(o3.order_id), "rejecting it does nothing")
	eq(o3.state, DeliveryOrder.PACKED_WAITING_DRIVER, "it stays packed for the driver")
	near(s.reputation.rotifood, rf1, 0.0001, "and costs no stars")
	free_sim(s)


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_rotifood_reject"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", profile_name)
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	# Simulasi dibekukan: status pesanan hanya berubah oleh tes ini.
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


func _ui() -> void:
	var game: GameRoot = await _boot("Reject Test")
	var sim: SimulationRoot = game.sim
	var o1: DeliveryOrder = sim.rotifood.create_scripted_order(&"recipe_plain_loaf", 1)
	var o2: DeliveryOrder = sim.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	game.modals.close_all()
	var scr: RotiFoodScreen = game.modals.open(&"rotifood", {"order": o1.order_id}) as RotiFoodScreen
	await runner.get_tree().process_frame
	var pack: Button = scr.find_child("Pack", true, false) as Button
	var reject: Button = scr.find_child("Reject", true, false) as Button
	check(reject != null and reject.is_visible_in_tree(), "the popup shows Reject Order")
	if reject == null or pack == null:
		await _finish(game)
		return
	eq(reject.text, Tx.t("ui_rotifood_reject"), "labelled in English")
	check(reject.get_parent() == pack.get_parent(), "beside Pack")
	check(reject.size.y >= float(ProceduralUIFactory.TOUCH_MIN), "a full-size touch target (%.0f px)" % reject.size.y)
	var rf0: float = sim.reputation.rotifood
	reject.pressed.emit()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"confirm"), "rejecting asks first")
	var dlg: ConfirmDialog = game.modals.top() as ConfirmDialog
	if dlg == null:
		await _finish(game)
		return
	eq(str(dlg.params.get("text", "")), Tx.t("ui_rotifood_reject_confirm", {"id": o1.order_id, "stars": "0.05"}), "with the star cost")
	check(o1.is_active(), "nothing happens before confirming")
	dlg._cancel()
	await runner.get_tree().process_frame
	check(o1.is_active() and is_equal_approx(sim.reputation.rotifood, rf0), "Cancel keeps the order")
	reject = scr.find_child("Reject", true, false) as Button
	reject.pressed.emit()
	await runner.get_tree().process_frame
	dlg = game.modals.top() as ConfirmDialog
	dlg._accept()
	await runner.get_tree().process_frame
	eq(o1.state, DeliveryOrder.CANCELLED, "confirming rejects the order")
	near(sim.reputation.rotifood, rf0 - REJECT_STARS, 0.0001, "for 0.05 stars")
	check(game.modals.is_open(&"rotifood"), "the order popup stays open")
	eq(scr._selected, o2.order_id, "showing the next order")
	# Pesanan yang sudah dikemas tidak punya tombol Reject.
	stock(sim, &"recipe_plain_loaf", 6)
	scr._render()
	pack = scr.find_child("Pack", true, false) as Button
	pack.pressed.emit()
	await runner.get_tree().process_frame
	check(o2.packed, "the next order is packed")
	reject = scr.find_child("Reject", true, false) as Button
	check(reject == null or not reject.is_visible_in_tree(), "a packed order has no Reject button")
	await _finish(game)
