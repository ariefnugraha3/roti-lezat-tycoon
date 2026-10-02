extends TestSuite
## Staff Management (GDD 3.1-3.5, 7; perbaikan 2026-10-02): tidak pernah digulir
## ke samping. Dulu semua kartu berjajar dalam satu baris, sampai 30 kartu
## pelamar. Kini daftar di kiri (hanya ini yang digulir, ke bawah) dan rincian
## karyawan terpilih di kanan, yang muat tanpa gulir.


func tests() -> Array:
	return [
		{"id": "ACC_7_STAFF_NO_SIDE_SCROLL", "name": "7 Staff Management never scrolls sideways: staff sit in a vertical list (the only part that scrolls) and the selected person's card, bio, perks and actions fit without scrolling at 100% and 125% text scale", "fn": _no_side_scroll},
		{"id": "ACC_7_STAFF_HIRE_FROM_DETAIL", "name": "7 after closing, Hire in the detail hires the selected applicant, who moves to Your Team; during the day the button is disabled and says why", "fn": _hire_from_detail},
	]


func _boot() -> GameRoot:
	SaveManager.dir = "user://test_saves_staff_screen"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Staff Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
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


func _employ(sim: SimulationRoot, id: StringName) -> void:
	sim.staff.contracts[id] = {"employed": true, "on_duty": true, "working": false, "mode": "auto",
		"target_recipe": "", "batch": 0, "hired_day": 1, "batches_today": 0}


func _no_side_scroll() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	# Kasir bertier 4 (dua kemampuan khusus) dan baker bertier 5 dengan mode Target
	# Recipe: rincian terpanjang di tab Your Team.
	_employ(sim, &"staff_cashier_hendra")
	_employ(sim, &"staff_baker_alistair")
	sim.staff.contracts[&"staff_baker_alistair"]["mode"] = "target"
	sim.staff.contracts[&"staff_baker_alistair"]["target_recipe"] = "recipe_truffle_bun"
	var was_scale: float = ProceduralUIFactory.text_scale
	for pct: int in [100, 125]:
		ProceduralUIFactory.text_scale = float(pct) / 100.0
		for tab: int in [0, 1]:
			game.modals.close_all()
			var st: StaffScreen = game.modals.open(&"staff", {}) as StaffScreen
			st._tab = tab
			st._render()
			await runner.get_tree().process_frame
			for sc: Node in st.find_children("*", "ScrollContainer", true, false):
				eq((sc as ScrollContainer).horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, "%d%%, tab %d: nothing scrolls sideways" % [pct, tab])
			var worst_y: float = -INF
			var worst_x: float = -INF
			var worst_id: String = ""
			for id: StringName in st._ids:
				st._selected[tab] = id
				st._render_list()
				st._render_detail()
				await runner.get_tree().process_frame
				var area: Control = st._detail.get_parent() as Control
				var need: Vector2 = st._detail.get_combined_minimum_size()
				if need.y - area.size.y > worst_y:
					worst_y = need.y - area.size.y
					worst_id = String(id)
				worst_x = maxf(worst_x, need.x - area.size.x)
			check(worst_y <= 0.5, "%d%%, tab %d: every detail fits without scrolling (worst %s by %.0f px)" % [pct, tab, worst_id, maxf(worst_y, 0.0)])
			check(worst_x <= 0.5, "%d%%, tab %d: no detail is wider than its area (%.0f px)" % [pct, tab, maxf(worst_x, 0.0)])
			if tab == 1:
				var list_area: Control = st._list.get_parent() as Control
				check(st._list.get_combined_minimum_size().y > list_area.size.y, "%d%%: the long applicant list is the part that scrolls, downwards" % pct)
	ProceduralUIFactory.text_scale = was_scale
	await _finish(game)


func _hire_from_detail() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	var st: StaffScreen = game.modals.open(&"staff", {}) as StaffScreen
	st._tab = 1
	st._render()
	var id: StringName = st._selected[1]
	var hire: Button = st._detail.find_child("Hire", true, false) as Button
	check(hire != null and hire.disabled, "during the day Hire is disabled")
	var said: bool = false
	for l: Node in st._detail.find_children("*", "Label", true, false):
		said = said or (l as Label).text == Tx.t("ui_staff_hire_after_hours")
	check(said, "and the detail says hiring happens after closing")
	# Sesudah tutup: rekrut lewat tombol di rincian.
	var phase0: StringName = sim.time.phase
	sim.time.phase = TimeManager.AFTER_HOURS
	st._render()
	hire = st._detail.find_child("Hire", true, false) as Button
	check(hire != null and not hire.disabled, "after closing Hire is enabled")
	if hire != null:
		hire.pressed.emit()
	check(sim.staff.is_employed(id), "the selected applicant is hired")
	check(not st._ids.has(id) and st._selected[1] != id, "they leave the applicant list and the next applicant is selected")
	st._tab = 0
	st._render()
	check(st._ids.has(id) and st._selected[0] == id, "Your Team lists and selects them")
	sim.time.phase = phase0
	await _finish(game)
