extends TestSuite
## Tutup Lebih Awal (GDD 15.5, keputusan maintainer 2026-10-02): selama toko buka,
## pemain boleh menutup toko kapan saja. Jam maju ke 18:00 dan penutupan berjalan
## persis seperti biasa (GDD 104). Gaji karyawan tetap penuh, tetapi rating toko
## turun 0,05 bintang per jam in-game yang dipotong.


func tests() -> Array:
	return [
		{"id": "ACC_15_CLOSE_EARLY", "name": "15.5 closing early jumps the clock to 18:00 and settles the day like a normal close: customers leave, unpacked RotiFood orders cancel without penalty, staff are paid in full, and the store rating drops 0.05 per hour cut", "fn": _close_early},
		{"id": "ACC_15_CLOSE_EARLY_HUD", "name": "15.5 the Close Early button shows only while the shop is open, asks first with the rating cost, and confirming opens the Daily Summary", "fn": _hud},
	]


func _close_early() -> void:
	var s: SimulationRoot = new_sim(6301)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	# Seorang baker bertugas sejak 05:00: gajinya tetap penuh walau toko tutup awal.
	s.staff.contracts[&"staff_baker_joko"] = {"employed": true, "on_duty": true, "working": false,
		"hired_day": 1, "batches_today": 0}
	s.staff.begin_day()
	var wage: float = s.staff.daily_wage()
	near(s.staff.wage_liability_today, wage, 0.001, "the baker's day wage is owed from 05:00")
	eq(s.close_early_block(), &"phase", "during preparation the shop cannot close early")
	check(not s.close_early(), "and nothing happens if asked")
	run_until(s, 8.0 * 3600.0 + 10.0)
	s.time.time_seconds = 12.0 * 3600.0
	eq(s.close_early_block(), &"tutorial", "while the day-1 storage lesson still locks every other tap, so does Close Early")
	s.tutorial.skip()
	eq(s.close_early_block(), &"", "while open the shop can close early")
	near(s.close_early_penalty(), 0.30, 0.0001, "closing at 12:00 cuts six hours: 0.30 stars")
	# Seorang pembeli di dalam dan satu pesanan RotiFood menunggu dikemas.
	stock(s, &"recipe_plain_loaf", 6)
	var shelf: int = s.display.total_units()
	s.customers.try_admit({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 1, "patience_override": null})
	var o: DeliveryOrder = s.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	for i in 200:
		s.step(s.tick_seconds)
	check(not s.customers.customers.is_empty(), "a buyer is inside")
	var stars: float = s.reputation.physical
	var rf: float = s.reputation.rotifood
	var penalty: float = s.close_early_penalty()
	var at: float = s.time.time_seconds
	check(s.close_early(), "the shop closes early")
	near(s.time.time_seconds, s.time.close_time, 0.001, "the clock jumps to 18:00")
	eq(s.time.phase, TimeManager.SUMMARY, "the day is settled and the Daily Summary is ready")
	near(s.reputation.physical, stars - penalty, 0.0001, "the store rating drops by the penalty (%.3f)" % penalty)
	near(s.reputation.rotifood, rf, 0.0001, "the RotiFood rating is untouched")
	check(s.customers.customers.is_empty(), "customers inside leave")
	eq(s.display.total_units(), shelf, "bread they held goes back to the shelf")
	check(not o.is_active(), "the unpacked RotiFood order is cancelled")
	var r: Dictionary = s.reports.last_report
	near(float(r["wages"]), wage, 0.001, "staff are paid for the full day")
	near(float(r["closed_early_at"]), at, 0.001, "the report records when the shop closed")
	near(float(r["close_early_penalty"]), penalty, 0.0001, "and the stars it cost")
	near(float(r["rating_end"]), s.reputation.physical, 0.0001, "the summary rating includes the drop")
	eq(str(((r["highlights"] as Array)[0] as Dictionary)["key"]), "hl_closed_early", "the Daily Summary leads with the early closing")
	eq(s.close_early_block(), &"phase", "a closed shop cannot close again")
	# Penalti mengikuti sisa jam buka.
	for pair: Array in [[8.0, 0.50], [15.5, 0.125], [17.0, 0.05], [17.99, 0.0005]]:
		s.time.time_seconds = float(pair[0]) * 3600.0
		near(s.close_early_penalty(), float(pair[1]), 0.0001, "closing at %.2fh costs %.4f stars" % [float(pair[0]), float(pair[1])])
	free_sim(s)
	# Tanpa tutup awal, laporan biasa tidak membawa catatan itu.
	var n: SimulationRoot = new_sim(6302)
	n.demand.scripted_walkins.clear()
	n.demand.scripted_orders.clear()
	n.demand.scripted_window_shoppers.clear()
	run_until(n, 8.0 * 3600.0 + 10.0)
	n.time.time_seconds = n.time.close_time - 1.0
	for j in 40:
		n.step(n.tick_seconds)
	eq(n.time.phase, TimeManager.SUMMARY, "a normal close reaches the summary")
	near(float(n.reports.last_report["closed_early_at"]), -1.0, 0.0001, "a normal close is not marked early")
	for h: Variant in n.reports.last_report["highlights"]:
		check(str((h as Dictionary)["key"]) != "hl_closed_early", "no early-closing highlight on a normal close")
	free_sim(n)


func _hud() -> void:
	SaveManager.dir = "user://test_saves_close_early"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Close Test")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
	var btn: Button = game.hud.close_early_button()
	game.hud._refresh_all()
	check(btn != null and not btn.visible, "hidden during preparation")
	var sim: SimulationRoot = game.sim
	sim.demand.scripted_walkins.clear()
	sim.demand.scripted_orders.clear()
	sim.demand.scripted_window_shoppers.clear()
	while not sim.time.is_open():
		sim.step(sim.tick_seconds)
	sim.time.time_seconds = 14.0 * 3600.0
	game.hud._refresh_all()
	check(btn.visible, "shown while the shop is open")
	check(not game.hud.find_child("SkipToOpen", true, false).visible, "in place of Skip to Open")
	btn.pressed.emit()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"confirm"), "closing early asks for confirmation first")
	var dlg: ConfirmDialog = game.modals.top() as ConfirmDialog
	var text: String = str(dlg.params.get("text", ""))
	check(text == Tx.t("ui_close_early_confirm", {"time": Tx.clock(sim.time.close_time), "stars": "%.2f" % 0.20}), "the dialog states the rating cost (%s)" % text)
	eq(sim.time.phase, TimeManager.OPEN, "nothing happens before the player confirms")
	var stars: float = sim.reputation.physical
	dlg._accept()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq(sim.time.phase, TimeManager.SUMMARY, "confirming closes the shop")
	near(sim.reputation.physical, stars - 0.20, 0.0001, "the store rating drops by 0.20 for four hours")
	check(game.modals.is_open(&"daily_summary"), "the Daily Summary opens")
	game.hud._refresh_all()
	check(not btn.visible, "the button hides once the shop is closed")
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
