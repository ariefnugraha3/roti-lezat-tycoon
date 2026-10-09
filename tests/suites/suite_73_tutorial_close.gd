extends TestSuite
## Tutorial Hari 1 setelah toko tutup (keputusan maintainer 2026-10-08, GDD
## 27.2, 88.1): Daily Summary menyorot Manage Staff, Staff Management membuka
## tur pelamar, lalu Marketing dengan tur kampanye, dan akhirnya Continue to
## Next Day.


func tests() -> Array:
	return [
		{"id": "ACC_88_TUTORIAL_CLOSE_STEPS", "name": "88.1 after the Day 1 summary the tutorial leads to Staff Management, then Marketing, then Continue to Next Day; each screen's tour runs only on its step; the step survives a save; the next day ends it and later closings do not repeat it", "fn": _close_steps},
		{"id": "ACC_88_TUTORIAL_CLOSE_UI", "name": "88.1, 27.5 the Day 1 summary spotlights Manage Staff after its tip; Staff Management opens on Applicants with a four-stop tour (list, applicant, wage and room, Hire); the Marketing tile pulses and Marketing tours its first campaign, Launch and the list; then Continue to Next Day pulses, and the after-hours tip never covers the after-hours buttons", "fn": _close_ui},
		{"id": "ACC_88_TUTORIAL_HINT_PHASE", "name": "88.1 the after-hours buttons appear the moment the shop closes, not at the next HUD refresh, so the tutorial tip moves above them at once (this race made ACC_88_TUTORIAL_CLOSE_UI fail now and then)", "fn": _hint_phase},
	]


func _key(s: SimulationRoot) -> String:
	return str(s.tutorial.prompt.get("key", ""))


func _close_steps() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7301)
	s.tutorial.dismiss()
	s.tutorial.on_event(&"summary")
	eq(s.tutorial.guided_step, &"close_staff", "Day 1 closing: Staff Management comes next")
	eq(_key(s), "tut_summary", "behind the Daily Summary tip")
	check(s.tutorial.summary_tour(), "the summary spotlights Manage Staff")
	s.tutorial.dismiss()
	eq(_key(s), "tut_staff_open", "in the HUD: tap Staff Management")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "staff_button", "the Staff Management tile pulses")
	check(not bool(s.tutorial.prompt.get("dismissable", true)), "a guided step")
	s.tutorial.on_event(&"marketing_opened")
	eq(s.tutorial.guided_step, &"close_staff", "Marketing first does not skip the staff lesson")
	s.tutorial.on_event(&"staff_opened")
	eq(s.tutorial.guided_step, &"staff_tour", "Staff Management opens its tour")
	check(s.tutorial.staff_tour() and not s.tutorial.summary_tour(), "only the staff screen tours now")
	eq(_key(s), "", "no HUD tip under the staff screen")
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(u.tutorial.guided_step, &"staff_tour", "a save keeps the step")
	free_sim(u)
	s.tutorial.on_event(&"staff_closed")
	eq(_key(s), "tut_marketing_open", "then: tap Marketing")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "marketing_button", "the Marketing tile pulses")
	s.tutorial.on_event(&"marketing_opened")
	check(s.tutorial.marketing_tour(), "Marketing opens its tour")
	s.tutorial.on_event(&"marketing_closed")
	eq(_key(s), "tut_close_done", "then: Continue to Next Day")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "continue_button", "the Continue button pulses")
	check(bool(s.tutorial.prompt.get("dismissable", false)), "a closing tip with Got it")
	s.tutorial.dismiss()
	eq(s.tutorial.guided_step, &"", "the lesson is over")
	free_sim(s)
	# Hari sungguhan dengan bot: lesson dimulai saat tutup Hari 1, berakhir saat
	# hari berikutnya mulai, dan penutupan Hari 2 tidak mengulanginya.
	var t: SimulationRoot = new_sim(7302)
	var bot := SimBot.new(t)
	run_day(t, bot)
	eq(t.tutorial.guided_step, &"close_staff", "the bot's Day 1 ends at the staff lesson")
	bot.after_hours()
	eq(t.time.day, 2, "Day 2")
	eq(t.tutorial.guided_step, &"", "the new day ends the lesson")
	run_day(t, bot)
	eq(t.tutorial.guided_step, &"", "Day 2 closing does not repeat it")
	eq(t.check_invariants(), "", "invariants")
	free_sim(t)


# ===========================================================================
# UI
# ===========================================================================

## Refresh HUD berkala (5 kali per detik) ditahan; hanya sinyal pergantian fase
## yang boleh memunculkan tombol after-hours.
func _hint_phase() -> void:
	var game: GameRoot = await _boot("Phase Bakery")
	var hud: HUD = game.hud
	var sim: SimulationRoot = game.sim
	hud.show_tutorial_hint("tut_close_summary", &"", -1)
	await runner.get_tree().process_frame
	check(not hud.after_hours_row().visible, "during the day the after-hours buttons are hidden")
	hud._refresh = 1000.0
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	check(hud.after_hours_row().visible, "closing shows the after-hours buttons at once")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	hud._refresh = 1000.0
	check(hud.tutorial_hint().visible, "the tip is still shown")
	check(not hud.tutorial_hint().get_global_rect().intersects(hud.after_hours_row().get_global_rect()),
		"two frames later the tip already stands above the after-hours buttons")
	hud._refresh = 0.0
	await _finish(game)


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_tutorial_close"
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


func _covers(m: CoachMarks, ctl: Control, what: String) -> void:
	var inv: Transform2D = m.get_global_transform().affine_inverse()
	var r: Rect2 = inv * ctl.get_global_rect()
	check(m.hole().has_area() and m.hole().grow(1.0).encloses(r.intersection(Rect2(Vector2.ZERO, m.size))),
		"%s is spotlighted (hole %s, target %s)" % [what, m.hole(), r])


## Jalankan tur sampai habis lewat Next/Got it, sambil memeriksa sorotannya.
func _walk(m: CoachMarks, targets: Array, keys: Array, tag: String) -> void:
	eq(m.step_count(), targets.size(), "%s: %d stops" % [tag, targets.size()])
	for i in targets.size():
		await _frames(1)
		eq(m.index(), i, "%s stop %d" % [tag, i + 1])
		eq(m.text(), Tx.t(str(keys[i])), "%s stop %d text" % [tag, i + 1])
		var c: Control = (targets[i] as Callable).call()
		check(c != null, "%s stop %d target exists" % [tag, i + 1])
		if c != null:
			_covers(m, c, "%s stop %d" % [tag, i + 1])
		eq(m.next_button().text, Tx.t("ui_tutorial_got_it") if i == targets.size() - 1 else Tx.t("ui_tour_next"), "%s stop %d button" % [tag, i + 1])
		m.next_button().pressed.emit()
	await _frames(2)


func _close_ui() -> void:
	var game: GameRoot = await _boot("Tutorial Close")
	var sim: SimulationRoot = game.sim
	var hud: HUD = game.hud
	game.modals.close_all()
	sim.tutorial.dismiss()
	# Lewati siang hari: urutan pembukaan selesai, lalu tutup lebih awal.
	sim.tutorial._set_step(&"")
	sim.tutorial.done["storage_opened"] = true
	sim.demand.scripted_walkins.clear()
	sim.demand.scripted_orders.clear()
	sim.demand.scripted_window_shoppers.clear()
	run_until(sim, sim.time.open_time + 1.0)
	check(sim.close_early(), "the shop closes")
	await _frames(3)
	check(game.modals.is_open(&"daily_summary"), "the Daily Summary opens")
	check(game.modals.is_open(&"tutorial"), "with its tip on top")
	var summary: DailySummaryScreen = null
	for c: Node in game.modals.get_children():
		if c is DailySummaryScreen:
			summary = c
	check(summary != null and summary.tour() == null, "no spotlight while the tip shows")
	(game.modals.top() as TutorialModal)._ok()
	# Nota "membuka" dengan animasi 0,45 detik nyata: tunggu sampai diam.
	await runner.get_tree().create_timer(0.6).timeout
	await _frames(3)
	check(summary != null and summary.tour() != null, "after the tip, the summary spotlights Manage Staff")
	if summary == null or summary.tour() == null:
		await _finish(game)
		return
	var staff_btn: Button = summary.find_child("ManageStaff", true, false) as Button
	_covers(summary.tour(), staff_btn, "Manage Staff")
	eq(summary.tour().text(), Tx.t("tut_close_summary"), "the closing tip")
	check(not summary.tour().next_button().visible, "no Next: tap Manage Staff")
	staff_btn.pressed.emit()
	await _frames(3)
	var staff: StaffScreen = game.modals.top() as StaffScreen
	check(staff != null, "Staff Management opens")
	check(not game.modals.is_open(&"daily_summary"), "the summary steps aside")
	eq(sim.time.phase, TimeManager.AFTER_HOURS, "after hours")
	if staff == null or staff.tour() == null:
		check(false, "the staff tour starts")
		await _finish(game)
		return
	check(staff.find_child("Hire", true, false) != null, "on the Applicants tab")
	await _walk(staff.tour(), [
		func() -> Control: return staff.find_child("StaffList", true, false) as Control,
		func() -> Control: return staff.find_child("Detail", true, false) as Control,
		func() -> Control: return staff.find_child("StaffSummary", true, false) as Control,
		func() -> Control: return staff.find_child("Hire", true, false) as Control,
	], ["tut_tour_staff_list", "tut_tour_staff_role", "tut_tour_staff_wage", "tut_tour_staff_hire"], "staff")
	check(staff.tour() == null, "Got it ends the staff tour")
	staff.close()
	await _frames(3)
	eq(sim.tutorial.guided_step, &"marketing", "closing it moves on to Marketing")
	check(hud.marketing_button().get_node_or_null(TutorialPulse.NODE_NAME) != null, "the Marketing tile pulses")
	check(hud.staff_button().get_node_or_null(TutorialPulse.NODE_NAME) == null, "the Staff tile does not")
	check(hud.tutorial_hint().visible, "with a tip")
	check(not hud.tutorial_hint().get_global_rect().intersects(hud.after_hours_row().get_global_rect()), "the tip stays clear of the after-hours buttons")
	hud.marketing_button().pressed.emit()
	await _frames(3)
	var ads: MarketingScreen = game.modals.top() as MarketingScreen
	check(ads != null and ads.tour() != null, "Marketing opens with a tour")
	if ads != null and ads.tour() != null:
		var list: Control = ads.find_child("CampaignList", true, false) as Control
		# Kartu kampanye pertama di dalam daftar gulir.
		var card: Control = list.get_child(0).get_child(0) as Control
		await _walk(ads.tour(), [
			func() -> Control: return card,
			func() -> Control: return card.find_child("Launch", true, false) as Control,
			func() -> Control: return list,
		], ["tut_tour_marketing_card", "tut_tour_marketing_launch", "tut_tour_marketing_later"], "marketing")
		ads.close()
		await _frames(3)
	eq(sim.tutorial.guided_step, &"close_done", "then the closing tip")
	check(hud.continue_button().get_node_or_null(TutorialPulse.NODE_NAME) != null, "Continue to Next Day pulses")
	check((hud.tutorial_hint().find_child("GotIt", true, false) as Button).visible, "the tip has Got it")
	check(not hud.tutorial_hint().get_global_rect().intersects(hud.after_hours_row().get_global_rect()), "and stays clear of the after-hours buttons")
	(hud.tutorial_hint().find_child("GotIt", true, false) as Button).pressed.emit()
	await _frames(2)
	eq(sim.tutorial.guided_step, &"", "the lesson is over")
	check(hud.continue_button().get_node_or_null(TutorialPulse.NODE_NAME) == null, "the pulse stops")
	await _finish(game)
