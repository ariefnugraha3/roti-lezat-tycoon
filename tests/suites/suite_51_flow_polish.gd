extends TestSuite
## Perbaikan alur 2026-09-30: penanda perabot setelah tata letak dibangun ulang
## (GDD 7, 18.6) dan "Skip to Open" di fase persiapan (GDD 15.4).


func tests() -> Array:
	return [
		{"id": "ACC_7_MARKER_REBUILD", "name": "7 a rebuilt layout leaves no frozen progress bar behind; markers hide in Decoration Mode", "fn": _marker_rebuild},
		{"id": "ACC_15_SKIP_TO_OPEN", "name": "15.4 Skip to Open runs the same ticks as waiting, stops when an oven needs the player, and only works during preparation", "fn": _skip_to_open},
		{"id": "TEST_UI_SKIP_OPEN", "name": "15.4 the HUD button asks first, time-lapses to 08:00 behind an overlay, then hands control back", "fn": _skip_ui},
	]


## Sebelum perbaikan, penanda menempel di node lantai dan tidak ikut dibebaskan
## saat perabot dibangun ulang: bar progres lama membeku di atas alat selamanya.
func _marker_rebuild() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(707)
	s.tutorial.skip()
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, PlayerTaskManager.PLAYER_ID)
	check(j != null and j.mixer_id == mixer.iid, "a player job waits at the mixer")
	if j == null:
		world.queue_free()
		free_sim(s)
		return
	s.production.start_mixing(j.job_id, PlayerTaskManager.PLAYER_ID, 1.0)
	world._update_markers()
	var old: StationMarker = world.markers[mixer.iid]
	eq(old.mode, StationMarker.MODE_PROGRESS, "the mixing mixer shows a progress bar")
	# Tata letak berubah di tengah jalan (skin dari achievement, Decoration Mode, beli alat).
	s.world.layout_changed.emit()
	await runner.get_tree().process_frame
	check(not is_instance_valid(old), "the old marker is freed together with the old furniture")
	eq(_markers_in(world).size(), world.markers.size(), "only the current markers exist in the world")
	s.run_for(j.stage_duration + 0.5)
	eq(j.stage, ProductionJob.MIX_DONE_WAITING_PICKUP, "mixing finished")
	world._update_markers()
	var bars: int = 0
	for m: StationMarker in _markers_in(world):
		if m.visible and m.mode == StationMarker.MODE_PROGRESS:
			bars += 1
	eq(bars, 0, "no progress bar is left once the work is done")
	eq((world.markers[mixer.iid] as StationMarker).mode, StationMarker.MODE_ALERT, "the mixer now shows its '!' marker")
	world.decoration_mode = true
	world._update_markers()
	var shown: int = 0
	for m2: StationMarker in _markers_in(world):
		if m2.visible:
			shown += 1
	eq(shown, 0, "markers hide while the layout is being arranged")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


func _markers_in(root: Node) -> Array[StationMarker]:
	var out: Array[StationMarker] = []
	var todo: Array[Node] = [root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		for c: Node in n.get_children():
			todo.append(c)
		if n is StationMarker and not n.is_queued_for_deletion():
			out.append(n as StationMarker)
	return out


func _skip_to_open() -> void:
	PauseManager.clear_all()
	# 1. Hari 1: lompatan terkunci sampai pelajaran Decoration Mode dan Gudang
	# selesai (GDD 88.1 hard-block).
	var t: SimulationRoot = new_sim(1504)
	eq(t.skip_to_open_block(), &"tutorial", "day 1 waits for the first lessons")
	for ev: StringName in [&"decor_opened", &"furniture_placed", &"decor_closed"]:
		t.tutorial.on_event(ev)
	eq(t.skip_to_open_block(), &"tutorial", "after Decoration Mode it still waits for Storage")
	t.tutorial.on_event(&"storage_opened")
	eq(t.skip_to_open_block(), &"", "after the first lessons the skip is allowed")
	free_sim(t)
	# 2. Melompat = menunggu, hanya lebih cepat: tick yang sama, state yang sama.
	var a: SimulationRoot = _prep_with_baker(1505)
	var b: SimulationRoot = _prep_with_baker(1505)
	eq(b.skip_to_open_block(), &"", "day 2 at 05:00 with a baker at work: skip allowed")
	var result: StringName = &""
	var chunks: int = 0
	while result == &"" and chunks < 100000:
		result = b.skip_to_open_step(40)
		chunks += 1
	run_until(a, b.time.time_seconds)
	eq(fingerprint(b), fingerprint(a), "skipping ends in exactly the state that waiting would reach")
	if result == &"open":
		eq(b.time.phase, TimeManager.OPEN, "the shop opened")
		check(b.time.time_seconds >= b.time.open_time and b.time.time_seconds < b.time.open_time + 60.0, "the clock shows 08:00")
	else:
		eq(result, &"oven", "the only early stop is an oven that needs the player")
		check(b.production.oven_needs_player(), "a baker tray missed its auto-retrieve")
	free_sim(a)
	free_sim(b)
	# 3. Roti pemain di oven: lompatan berhenti begitu matang, sebelum gosong.
	var s: SimulationRoot = new_sim(1506)
	s.tutorial.skip()
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, PlayerTaskManager.PLAYER_ID)
	s.production.start_mixing(j.job_id, PlayerTaskManager.PLAYER_ID, 1.0)
	s.run_for(j.stage_duration + 0.1)
	s.production.pickup_dough(j.job_id, PlayerTaskManager.PLAYER_ID)
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	check(s.production.insert_oven(j.job_id, oven.iid, PlayerTaskManager.PLAYER_ID, 1.0), "the player's bread is baking")
	eq(s.skip_to_open_block(), &"", "baking bread does not block the skip")
	var r2: StringName = &""
	var guard: int = 0
	while r2 == &"" and guard < 100000:
		r2 = s.skip_to_open_step(40)
		guard += 1
	eq(r2, &"oven", "the skip stops when the bread is done")
	eq(j.stage, ProductionJob.BAKE_DONE_WAITING_PICKUP, "stopped right away, not burnt")
	eq(s.time.phase, TimeManager.PREPARATION, "still before opening")
	eq(s.skip_to_open_block(), &"oven", "while the tray waits, the skip explains why it cannot run")
	s.production.pickup_tray(j.job_id, PlayerTaskManager.PLAYER_ID)
	eq(s.skip_to_open_block(), &"", "once the tray is out the skip works again")
	# 4. Setelah buka tidak ada lompatan.
	run_until(s, s.time.open_time + 1.0)
	eq(s.skip_to_open_block(), &"phase", "no skip once the shop is open")
	eq(s.skip_to_open_step(10), &"open", "a stray skip step does nothing after opening")
	free_sim(s)


## Hari 2 pukul 05:00 dengan satu Asisten Dapur yang langsung bekerja.
func _prep_with_baker(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	s.time.set_phase(TimeManager.AFTER_HOURS)
	var r: StringName = s.staff.hire(&"staff_baker_joko")
	eq(r, &"", "baker hired after hours")
	s.continue_to_next_day()
	return s


func _skip_ui() -> void:
	SaveManager.dir = "user://test_saves_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Skip Test")
	await runner.get_tree().process_frame
	game.modals.close_all()
	PauseManager.clear_all()
	var btn: Button = game.hud.find_child("SkipToOpen", true, false) as Button
	check(btn != null, "the HUD has a Skip to Open button")
	game.hud._refresh_all()
	check(not btn.visible, "hidden while day 1 waits for the storage lesson")
	game.sim.tutorial.skip()
	game.hud._refresh_all()
	check(btn.visible, "shown during preparation")
	game.request_skip_to_open()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"confirm"), "the skip asks for confirmation first")
	check(not game.is_skipping_to_open(), "nothing happens before the player confirms")
	(game.modals.top() as ConfirmDialog)._accept()
	check(game.is_skipping_to_open(), "confirming starts the skip")
	var frames: int = 0
	var saw_progress: bool = false
	var start: float = game.sim.time.time_seconds
	while game.is_skipping_to_open() and frames < 5000:
		await runner.get_tree().process_frame
		frames += 1
		if game.is_skipping_to_open() and game.sim.time.time_seconds > start + 600.0:
			saw_progress = true
			check(not game.commands.enabled, "world taps are off during the skip")
	check(saw_progress, "the clock runs ahead while the overlay shows")
	check(not game.is_skipping_to_open(), "the skip finishes (%d frames)" % frames)
	eq(game.sim.time.phase, TimeManager.OPEN, "the shop is open")
	check(game.sim.time.time_seconds < game.sim.time.open_time + 60.0, "at 08:00 exactly (%s)" % Tx.clock(game.sim.time.time_seconds))
	check(not PauseManager.is_paused(), "no pause left behind")
	game.hud._refresh_all()
	check(not btn.visible, "the button hides once the shop is open")
	await runner.get_tree().process_frame
	check(game.commands.enabled, "control returns to the player")
	game.return_to_menu()
	await runner.get_tree().process_frame
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
