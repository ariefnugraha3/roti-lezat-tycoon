extends TestSuite
## Tumpukan modal (GDD 28.2): lapisan sistem (Game Paused, menu Pause, tutorial,
## konfirmasi) muncul di atas Daily Summary tanpa menutupnya, sehingga hari tidak
## pernah macet tanpa tombol lanjut. Bug yang dilaporkan: summary tampil, jendela
## kehilangan fokus, Resume, lalu summary hilang dan permainan tidak bisa lanjut.


func tests() -> Array:
	return [
		{"id": "ACC_28_SUMMARY_SURVIVES_PAUSE", "name": "28.2 Game Paused, Back, the pause key and Pause > Settings sit on top of the Daily Summary and never close it", "fn": _summary_survives},
		{"id": "ACC_28_TUTORIAL_OVER_SUMMARY", "name": "28.2 the Day 1 summary tip shows on top of the Daily Summary and dismissing it leaves the summary open", "fn": _tutorial_over_summary},
	]


func _ids(game: GameRoot) -> Array[StringName]:
	var out: Array[StringName] = []
	for s: UIScreen in game.modals._stack:
		out.append(s.screen_id)
	return out


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_modal_stack"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: GameRoot = scene.instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.show_main_menu()
	await game.start_new_game(&"profile_1", "male", profile_name)
	await runner.get_tree().process_frame
	return game


## Tutup hari tanpa kedatangan terjadwal: jam dilompatkan ke menjelang 18:00.
func _close_day(game: GameRoot) -> void:
	var s: SimulationRoot = game.sim
	# debug_set_time merencanakan ulang hari, jadi jadwal dikosongkan sesudahnya.
	s.debug_set_time(s.time.close_time - 2.0)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	while s.is_running():
		s.step(s.tick_seconds)
	await runner.get_tree().process_frame


func _finish(game: GameRoot) -> void:
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


func _summary_survives() -> void:
	var game: GameRoot = await _boot("Modal Stack Bakery")
	game.sim.tutorial.skip()
	game.modals.close_all()
	PauseManager.clear_all()
	await _close_day(game)
	eq(game.sim.time.phase, TimeManager.SUMMARY, "the day closed")
	eq(_ids(game), [&"daily_summary"] as Array[StringName], "the Daily Summary shows")
	# 1. Jendela kehilangan fokus (bug yang dilaporkan).
	PauseManager.on_focus_lost()
	await runner.get_tree().process_frame
	eq(_ids(game), [&"daily_summary", &"lifecycle"] as Array[StringName], "Game Paused sits on top of the summary")
	eq(game.modals.top().screen_id, &"lifecycle", "Game Paused is the top layer")
	game.modals.back()
	await runner.get_tree().process_frame
	eq(_ids(game), [&"daily_summary"] as Array[StringName], "after Resume the summary is still there")
	check(not PauseManager.has(PauseManager.LIFECYCLE), "the focus pause is cleared")
	# 2. Back/Escape: summary menolak Back, lalu menu Pause muncul di atasnya.
	game._on_back()
	await runner.get_tree().process_frame
	eq(_ids(game), [&"daily_summary", &"pause"] as Array[StringName], "Back opens the pause menu on top of the summary")
	game._on_pause_key()
	await runner.get_tree().process_frame
	eq(_ids(game), [&"daily_summary"] as Array[StringName], "the pause key closes only the pause menu")
	# 3. Pause > Settings: Settings menggantikan menu Pause, summary tetap di bawah.
	var pause: PauseScreen = game.modals.open(&"pause") as PauseScreen
	await runner.get_tree().process_frame
	pause._open(&"settings")
	await runner.get_tree().process_frame
	eq(_ids(game), [&"daily_summary", &"settings"] as Array[StringName], "Settings opens over the summary")
	game.modals.back()
	await runner.get_tree().process_frame
	eq(_ids(game), [&"daily_summary"] as Array[StringName], "closing Settings returns to the summary")
	# 4. Pengaman: bila nota tetap hilang di fase Summary, ia dibuka lagi.
	game.modals.close_id(&"daily_summary")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"daily_summary"), "a summary that disappears during the Summary phase comes back")
	# 5. Tombol Staff membawa ke after-hours; HUD punya tombol lanjut.
	var summary: DailySummaryScreen = game.modals.top() as DailySummaryScreen
	summary._leave_to(&"staff")
	await runner.get_tree().process_frame
	eq(game.sim.time.phase, TimeManager.AFTER_HOURS, "Staff moves on to after-hours")
	eq(_ids(game), [&"staff"] as Array[StringName], "the summary closes itself for Staff")
	game.modals.close_all()
	await runner.get_tree().process_frame
	check(not game.modals.is_open(&"daily_summary"), "after-hours does not bring the summary back")
	check(game.sim.continue_to_next_day(), "the day can continue")
	eq(game.sim.time.day, 2, "Day 2 begins")
	await _finish(game)


func _tutorial_over_summary() -> void:
	var game: GameRoot = await _boot("Tutorial Stack Bakery")
	# Tutup tip modal yang menunggu (sambutan); langkah terpandu Hari 1 tidak
	# bisa di-dismiss dan berakhir sendiri saat hari ditutup (GDD 88.1).
	for i in 8:
		if game.sim.tutorial.prompt.is_empty() or bool(game.sim.tutorial.prompt.get("guided", false)):
			break
		game.sim.tutorial.dismiss()
	game.modals.close_all()
	PauseManager.clear_all()
	await _close_day(game)
	eq(_ids(game), [&"daily_summary", &"tutorial"] as Array[StringName], "the summary tip shows on top of the summary")
	eq(str(game.sim.tutorial.prompt.get("key", "")), "tut_summary", "the tip explains the Daily Summary")
	var tip: TutorialModal = game.modals.top() as TutorialModal
	tip._ok()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"daily_summary"), "the summary stays open after Got it")
	check(str(game.sim.tutorial.prompt.get("key", "")) != "tut_summary", "the tip was dismissed, so later tips can show")
	# Game Paused di atas tip dan summary sekaligus.
	PauseManager.on_focus_lost()
	await runner.get_tree().process_frame
	eq(game.modals.top().screen_id, &"lifecycle", "Game Paused goes on top of everything")
	game.modals.back()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"daily_summary"), "the summary is still there after Resume")
	await _finish(game)
