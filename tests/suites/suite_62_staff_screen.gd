extends TestSuite
## Layar Staff idle (GDD idle 5.5, 12.0.5): lembar bawah dengan satu daftar
## vertikal (satu-satunya yang digulir), detail sebagai halaman berikutnya, dan
## tidak pernah digulir ke samping. Merekrut kapan saja, dibayar sekali.


func tests() -> Array:
	return [
		{"id": "ACC_7_STAFF_NO_SIDE_SCROLL", "name": "idle 12.0.5 the Staff sheet never scrolls sideways: one vertical list with Your Team, the next candidate per role (a note when the role is full) and Other candidates on its own page; every page fits the sheet's width at 100% and 125% text scale", "fn": _no_side_scroll},
		{"id": "ACC_7_STAFF_HIRE_FROM_DETAIL", "name": "idle 5.5 Hire on a candidate's detail page hires them at once for hire_cost[n]; they move to Your Team and a full role says so", "fn": _hire_from_detail},
	]


func _boot() -> GameRoot:
	SaveManager.dir = "user://test_saves_staff_screen"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
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
	game.end_session()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


## Teks tombol ikon+teks ada di Label anaknya (ProceduralUIFactory.icon_text_button).
func _text(b: Button) -> String:
	if b == null:
		return ""
	for n: Node in b.find_children("*", "Label", true, false):
		return (n as Label).text
	return b.text


func _sideways(root: Node) -> int:
	var n: int = 0
	for sc: Node in root.find_children("*", "ScrollContainer", true, false):
		if (sc as ScrollContainer).horizontal_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			n += 1
	return n


func _no_side_scroll() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	sim.debug_add_kr(1.0e6)
	sim.staff.hire(&"staff_cashier_budi")
	var was_scale: float = ProceduralUIFactory.text_scale
	for pct: int in [100, 125]:
		ProceduralUIFactory.text_scale = float(pct) / 100.0
		game.modals.close_all()
		var st: StaffScreen = game.modals.open(&"staff", {}) as StaffScreen
		await runner.get_tree().process_frame
		var frame: Rect2 = st.get_viewport_rect()
		var panel: Rect2 = st.panel().get_global_rect()
		check(panel.size.y <= frame.size.y * UISheet.MAX_HEIGHT_RATIO + 0.5, "%d%%: the sheet is at most 85%% of the frame high" % pct)
		check(panel.position.x >= -0.5 and panel.end.x <= frame.size.x + 0.5, "%d%%: the sheet stays inside the frame" % pct)
		eq(_sideways(st), 0, "%d%%: nothing scrolls sideways" % pct)
		var lists: int = st.find_children("*", "ScrollContainer", true, false).size()
		eq(lists, 1, "%d%%: the staff list is the only part that scrolls" % pct)
		for hid: StringName in sim.staff.employed_ids():
			check(st.content().find_child(String(hid), true, false) != null, "%d%%: %s has a row in Your Team" % [pct, hid])
		# Satu kandidat berikutnya per peran, sisanya di halaman pilihan; peran
		# penuh hanya diberi satu catatan (GDD idle §20 no. 84).
		check(st.content().find_child("Full_cashier", true, false) != null, "%d%%: the full cashier role shows one note" % pct)
		check(st.content().find_child("staff_cashier_sari", true, false) == null, "%d%%: no Hire rows for a full role" % pct)
		var bakers: Array[StaffDefinition] = st.candidates(&"baker")
		check(st.content().find_child(String(bakers[0].id), true, false) != null, "%d%%: the next kitchen candidate has a row" % pct)
		check(st.content().find_child(String(bakers[1].id), true, false) == null, "%d%%: the other kitchen candidates wait on their own page" % pct)
		var more: Node = st.content().find_child("More_baker", true, false)
		var choose: Button = more.find_child("Choose", true, false) as Button if more != null else null
		check(choose != null, "%d%%: Other candidates opens the choice page" % pct)
		if choose != null:
			choose.pressed.emit()
			await runner.get_tree().process_frame
			await runner.get_tree().process_frame
			eq(st.page_depth(), 1, "%d%%: the choice page is a page of the same sheet" % pct)
			var on_page: int = 0
			for d: StaffDefinition in bakers:
				if st.content().find_child(String(d.id), true, false) != null:
					on_page += 1
			eq(on_page, bakers.size(), "%d%%: every kitchen candidate is on the choice page" % pct)
			eq(_sideways(st), 0, "%d%%: the choice page does not scroll sideways" % pct)
			st.pop_page()
			await runner.get_tree().process_frame
		var worst_x: float = -INF
		for def2: StaffDefinition in DataRegistry.staff_list():
			st.push_page(def2.display_name, st._detail.bind(def2.id))
			await runner.get_tree().process_frame
			await runner.get_tree().process_frame
			eq(st.page_depth(), 1, "%d%%: %s opens as a page of the same sheet" % [pct, def2.id])
			var need: Vector2 = st.content().get_combined_minimum_size()
			worst_x = maxf(worst_x, need.x - st.content().size.x)
			eq(_sideways(st), 0, "%d%%: %s detail does not scroll sideways" % [pct, def2.id])
			st.pop_page()
			await runner.get_tree().process_frame
		check(worst_x <= 0.5, "%d%%: no detail is wider than the sheet (%.0f px)" % [pct, maxf(worst_x, 0.0)])
	ProceduralUIFactory.text_scale = was_scale
	await _finish(game)


func _hire_from_detail() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	var costs: Array = DataRegistry.idle("staff.hire_cost")
	sim.debug_add_kr(float(costs[0]) + float(costs[1]))
	var st: StaffScreen = game.modals.open(&"staff", {}) as StaffScreen
	await runner.get_tree().process_frame
	var id: StringName = &"staff_cashier_sari"
	st.push_page(DataRegistry.staff(id).display_name, st._detail.bind(id))
	await runner.get_tree().process_frame
	var hire: Button = st.content().find_child("Hire", true, false) as Button
	check(hire != null and not hire.disabled, "Hire works at any time of day (no after-hours rule)")
	check(_text(hire).contains(Tx.big(float(costs[0]))), "the button shows the first hire cost (%s)" % _text(hire))
	var bal: float = sim.economy.balance
	if hire != null:
		hire.pressed.emit()
	await runner.get_tree().process_frame
	check(sim.staff.is_employed(id), "the candidate is hired")
	near(sim.economy.balance, bal - float(costs[0]), 0.001, "paid once, hire_cost[0]")
	# Lembar ditutup supaya sambutan staf baru terlihat (GDD idle §20 no. 71).
	check(not game.modals.is_open(&"staff"), "the sheet closes so the new hire's welcome shows")
	st = game.modals.open(&"staff", {}) as StaffScreen
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var team_row: Node = st.content().find_child(String(id), true, false)
	check(team_row != null and team_row.find_child("Hire", true, false) == null, "Your Team lists them without a Hire button")
	var full_note: Label = st.content().find_child("Full_cashier", true, false) as Label
	check(full_note != null and full_note.text == Tx.t("ui_staff_full_cashier", {"max": 1}), "the full cashier role says so once at Tier 1")
	check(st.content().find_child("staff_cashier_budi", true, false) == null, "no Hire row for another cashier while the role is full")
	var baker: Node = st.content().find_child("staff_baker_joko", true, false)
	var bh: Button = baker.find_child("Hire", true, false) as Button if baker != null else null
	check(_text(bh).contains(Tx.big(float(costs[1]))), "the next person costs hire_cost[1] (%s)" % _text(bh))
	await _finish(game)
