extends TestSuite
## Kemajuan tutorial tersimpan seketika (laporan maintainer 2026-11-06: tutorial
## yang sudah diselesaikan muncul lagi setelah game ditutup lalu Continue).


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_TUTORIAL_SAVED", "name": "idle 13, 15.3 finishing, closing or skipping a tip is written to the save at once, not at the next 30 s autosave, so a game closed right after never shows it again on Continue; tips still waiting their turn survive a save too", "fn": _saved},
	]


func _saved() -> void:
	SaveManager.dir = "user://test_saves_tutorial"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var hints_before: bool = SettingsManager.get_bool("tutorial_hints")
	SettingsManager.set_value("tutorial_hints", true)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Tutorial Bakery")
	for i in 4:
		await runner.get_tree().process_frame
	var s: SimulationRoot = game.sim
	eq(str(s.tutorial.prompt.get("key", "")), "onb_welcome", "the welcome tip is showing")
	var modal: TutorialModal = game.modals.screen(&"tutorial") as TutorialModal
	check(modal != null, "in the tutorial popup")
	# Got it, lalu game "dimatikan": hanya yang sudah ada di berkas save yang tersisa.
	if modal != null:
		modal._ok()
	for i2 in 3:
		await runner.get_tree().process_frame
	var t: Dictionary = (SaveManager.read_profile(&"profile_1").get("data", {}) as Dictionary).get("tutorial", {})
	check((t.get("done", []) as Array).has("onb_welcome"), "the save knows the welcome tip was seen")
	check(str((t.get("prompt", {}) as Dictionary).get("key", "")) != "onb_welcome", "and that it was closed, right away")
	# Dua tip terpicu bersamaan: yang menunggu giliran ikut tersimpan.
	s.tutorial.prompt = {}
	s.tutorial.show_step("onb_offline")
	s.tutorial.show_step("onb_share", &"hud_pause")
	for i3 in 3:
		await runner.get_tree().process_frame
	var t2: Dictionary = (SaveManager.read_profile(&"profile_1").get("data", {}) as Dictionary).get("tutorial", {})
	eq(str((t2.get("prompt", {}) as Dictionary).get("key", "")), "onb_offline", "the showing tip is saved")
	eq(((t2.get("queue", []) as Array)[0] as Dictionary).get("key", "") if not (t2.get("queue", []) as Array).is_empty() else "", "onb_share",
		"and so is the one waiting its turn")
	var back: SimulationRoot = load_sim(SaveManager.read_profile(&"profile_1")["data"])
	back.tutorial.dismiss()
	eq(str(back.tutorial.prompt.get("key", "")), "onb_share", "after a reload the waiting tip still comes next")
	free_sim(back)
	# Skip seluruh tutorial juga langsung tersimpan.
	s.tutorial.skip()
	for i4 in 3:
		await runner.get_tree().process_frame
	var t3: Dictionary = (SaveManager.read_profile(&"profile_1").get("data", {}) as Dictionary).get("tutorial", {})
	check(bool(t3.get("skipped", false)), "Skip is saved at once")
	var again: SimulationRoot = load_sim(SaveManager.read_profile(&"profile_1")["data"])
	check(again.tutorial.prompt.is_empty() and again.tutorial.skipped, "Continue shows no tutorial after Skip")
	for i5 in int(30.0 / again.tick_seconds):
		again.step(again.tick_seconds)
	check(again.tutorial.prompt.is_empty(), "and none comes back while playing")
	free_sim(again)
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	SettingsManager.set_value("tutorial_hints", hints_before)
	PauseManager.clear_all()
	AudioManager.stop_all_sounds()
