extends TestSuite
## Tutorial Hari 1 terpandu (keputusan maintainer 2026-10-07, GDD 27.5, 88.1):
## Decoration Mode lebih dulu (pemain wajib mencoba memindahkan perabot), lalu
## Buku Resep dengan tur sorotan, mixer, oven, rak; sekali lagi Buku Resep
## (tur singkat), mixer, oven, dan loyang kedua ke Meja Tunggu.


func tests() -> Array:
	return [
		{"id": "ACC_88_TUTORIAL_DECOR_FIRST", "name": "88.1 Day 1 starts in Decoration Mode: after the welcome every world tap waits until the player has moved a piece of furniture and closed Decoration Mode; closing it early asks again; then only Storage can be tapped", "fn": _decor_first},
		{"id": "ACC_88_TUTORIAL_TWO_BATCHES", "name": "88.1 the guided Day 1 bakes two batches: Storage, mixer, oven, shelf; Storage again, mixer, oven, and the second tray goes on the holding table (shelves wait for it); leaving the Recipe Book without ordering asks for Storage again; the step survives a save", "fn": _two_batches},
		{"id": "ACC_88_TUTORIAL_RECIPE_TOUR", "name": "88.1 the HUD pulses Decoration Mode, Decoration Mode shows the tip and pulses Done, and the first Recipe Book opens a spotlight tour (recipe list, ingredients, equipment, price, batch size, then Make) that blocks everything but its target; the second opens a short tour", "fn": _recipe_tour},
	]


## Majukan simulasi sampai `cond` benar (paling lama `limit` detik-simulasi).
func _until(s: SimulationRoot, cond: Callable, limit: float = 120.0) -> bool:
	var t: float = 0.0
	while not bool(cond.call()) and t < limit:
		s.step(s.tick_seconds)
		t += s.tick_seconds
	return bool(cond.call())


## Pindahkan satu perabot ke ubin sah terdekat (seperti Decoration Mode).
func _move_furniture(s: SimulationRoot) -> bool:
	var e: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var start: Vector2i = e.anchor
	for r in range(1, 6):
		for d: Vector2i in [Vector2i(r, 0), Vector2i(-r, 0), Vector2i(0, r), Vector2i(0, -r)]:
			if s.world.validate_placement(e, e.floor_id, start + d, e.rotation) == &"":
				return s.equipment.place(e.iid, e.floor_id, start + d, e.rotation) == &""
	return false


func _key(s: SimulationRoot) -> String:
	return str(s.tutorial.prompt.get("key", ""))


func _iid(s: SimulationRoot, cat: StringName) -> int:
	return s.equipment.placed_list(cat)[0].iid


func _decor_first() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7101)
	eq(_key(s), "tut_welcome", "Day 1 opens with the welcome")
	check(bool(s.tutorial.prompt.get("modal", false)), "as a tip that pauses the game")
	eq(s.tutorial.guided_step, &"decor_open", "the guided steps wait behind it")
	s.tutorial.dismiss()
	eq(_key(s), "tut_decor_open", "then: tap Decoration Mode")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "decor_button", "with the Quick Menu button highlighted")
	check(not bool(s.tutorial.prompt.get("dismissable", true)), "a guided step cannot be waved away")
	s.tutorial.dismiss()
	eq(_key(s), "tut_decor_open", "Got it does nothing on a guided step")
	check(not s.player.tap_equipment(_iid(s, &"storage")), "the storage waits")
	check(not s.player.tap_equipment(_iid(s, &"mixer")), "so does the mixer")
	eq(s.skip_to_open_block(), &"tutorial", "and Skip to Open")
	s.tutorial.on_event(&"decor_opened")
	eq(_key(s), "tut_decor_move", "Decoration Mode: move a piece of furniture")
	eq(int(s.tutorial.prompt.get("highlight_iid", -1)), _iid(s, &"display"), "the shelf is suggested")
	s.tutorial.on_event(&"decor_closed")
	eq(_key(s), "tut_decor_open", "closing without moving anything asks again")
	s.tutorial.on_event(&"decor_opened")
	var before: Vector2i = s.equipment.placed_list(&"display")[0].anchor
	check(_move_furniture(s), "the shelf moves to another tile")
	check(s.equipment.placed_list(&"display")[0].anchor != before, "the layout really changed")
	eq(_key(s), "tut_decor_done", "then: tap Done")
	eq(str(s.tutorial.prompt.get("highlight_kind", "")), "decor_done", "with the Done button highlighted")
	check(not s.player.tap_equipment(_iid(s, &"storage")), "the world still waits while Decoration Mode is open")
	s.tutorial.on_event(&"decor_closed")
	eq(_key(s), "tut_tap_storage", "back in the shop: tap Storage")
	eq(int(s.tutorial.prompt.get("highlight_iid", -1)), _iid(s, &"storage"), "the storage blinks")
	check(not s.player.tap_equipment(_iid(s, &"mixer")), "only Storage can be tapped now")
	check(s.player.tap_equipment(_iid(s, &"storage")), "Storage can")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _two_batches() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7102)
	s.tutorial.dismiss()
	s.tutorial.on_event(&"decor_opened")
	check(_move_furniture(s), "furniture moved")
	s.tutorial.on_event(&"decor_closed")
	eq(s.tutorial.guided_step, &"storage", "Storage first")
	# Save di tengah alur: langkahnya ikut tersimpan.
	var u: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(u.tutorial.guided_step, &"storage", "a save keeps the guided step")
	eq(str(u.tutorial.prompt.get("key", "")), "tut_tap_storage", "and its tip")
	free_sim(u)
	var storage: int = _iid(s, &"storage")
	var mixer: int = _iid(s, &"mixer")
	var oven: int = _iid(s, &"oven")
	var shelf: int = _iid(s, &"display")
	var table: int = s.equipment.table_instance().iid
	for round in 2:
		var tag: String = "round %d" % (round + 1)
		check(s.player.tap_equipment(storage), "%s: tap Storage" % tag)
		check(_until(s, func() -> bool: return s.ui_requests.recipe_book_storage >= 0), "%s: the Recipe Book opens" % tag)
		eq(s.tutorial.recipe_tour(), &"full" if round == 0 else &"short", "%s: with the %s tour" % [tag, "full" if round == 0 else "short"])
		if round == 1:
			# Keluar tanpa memesan: Storage diminta lagi.
			s.player.close_storage()
			eq(_key(s), "tut_again_storage", "leaving the book without ordering asks for Storage again")
			check(s.player.tap_equipment(storage), "tap Storage again")
			check(_until(s, func() -> bool: return s.ui_requests.recipe_book_storage >= 0), "the book opens again")
		eq(s.player.order_recipe(&"recipe_plain_loaf", 1), "", "%s: order a loaf" % tag)
		s.player.close_storage()
		eq(_key(s), "tut_tap_mixer" if round == 0 else "tut_mixer_again", "%s: then the mixer" % tag)
		check(s.player.tap_equipment(mixer), "%s: tap the mixer" % tag)
		check(_until(s, func() -> bool: return _key(s) == "tut_equipment_works"), "%s: mixing starts" % tag)
		check(_until(s, func() -> bool: return _key(s) == "tut_mixer_done", 400.0), "%s: the dough is ready" % tag)
		check(s.player.tap_equipment(mixer), "%s: pick up the dough" % tag)
		check(_until(s, func() -> bool: return _key(s) == "tut_to_oven"), "%s: then the oven" % tag)
		check(s.player.tap_equipment(oven), "%s: tap the oven" % tag)
		check(_until(s, func() -> bool: return _key(s) == "tut_baking"), "%s: it bakes" % tag)
		check(_until(s, func() -> bool: return s.tutorial.guided_step == (&"oven_pickup" if round == 0 else &"oven_pickup2"), 600.0), "%s: the bread is ready" % tag)
		if round == 0:
			eq(_key(s), "tut_burn_risk", "the first time, a tip warns about burning")
			s.tutorial.dismiss()
		eq(_key(s), "tut_take_tray", "%s: take the tray out" % tag)
		check(s.player.tap_equipment(oven), "%s: tap the oven again" % tag)
		check(_until(s, func() -> bool: return s.player.carried_job() != null and s.player.carried_job().stage == ProductionJob.CARRIED_TO_DISPLAY), "%s: the tray is carried" % tag)
		if round == 0:
			eq(_key(s), "tut_choose_slot", "the first tray goes on a shelf")
			check(s.player.tap_equipment(shelf), "tap the shelf")
			check(_until(s, func() -> bool: return s.ui_requests.slot_picker_display >= 0), "the slot picker opens")
			var slot: int = 0
			while s.player.carried_job() != null and slot < s.display.slots(shelf).size():
				s.player.place_into_slot(shelf, slot, 99)
				slot += 1
			eq(_key(s), "tut_again_storage", "the first bread is on the shelf: one more batch")
			eq(int(s.tutorial.prompt.get("highlight_iid", -1)), storage, "the storage blinks again")
		else:
			eq(_key(s), "tut_to_table", "the second tray goes on the holding table")
			eq(int(s.tutorial.prompt.get("highlight_iid", -1)), table, "the table blinks")
			check(not s.player.tap_equipment(shelf), "the shelves wait")
			check(s.player.tap_equipment(table), "tap the holding table")
			check(_until(s, func() -> bool: return s.player.carried_job() == null), "the tray is parked")
			eq(s.production.table_jobs().size(), 1, "on the table")
			eq(_key(s), "tut_skip_open", "then: Skip to Open")
			check(not bool(s.tutorial.prompt.get("dismissable", true)), "a guided step, not a closing tip")
			check(s.player.tap_equipment(shelf), "shelves can be tapped again")
			eq(s.skip_to_open_block(), &"", "and Skip to Open can be used")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_tutorial_day1"
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


func _recipe_tour() -> void:
	var game: GameRoot = await _boot("Tutorial Tour")
	var sim: SimulationRoot = game.sim
	check(game.modals.is_open(&"tutorial"), "the welcome tip opens")
	game.modals.close_all()
	sim.tutorial.dismiss()
	await _frames(2)
	var hud: HUD = game.hud
	check(hud.decoration_button().get_node_or_null(TutorialPulse.NODE_NAME) != null, "the Decoration Mode button pulses")
	check(hud.tutorial_hint().visible, "the hint shows")
	check(not (hud.tutorial_hint().find_child("GotIt", true, false) as Button).visible, "without Got it")
	var deco: DecorationScreen = game.modals.open(&"decoration") as DecorationScreen
	await _frames(2)
	eq(sim.tutorial.guided_step, &"decor_move", "opening Decoration Mode moves the lesson on")
	var tip: PanelContainer = deco.tutorial_tip()
	check(tip != null, "Decoration Mode shows the tip")
	var done_btn: Button = deco.find_child("Done", true, false) as Button
	check(done_btn.get_node_or_null(TutorialPulse.NODE_NAME) == null, "Done does not pulse yet")
	check(_move_furniture(sim), "a piece of furniture moves")
	await _frames(1)
	check(done_btn.get_node_or_null(TutorialPulse.NODE_NAME) != null, "now Done pulses")
	var says_done: bool = false
	if deco.tutorial_tip() != null:
		for l: Node in deco.tutorial_tip().find_children("*", "Label", true, false):
			says_done = says_done or (l as Label).text == Tx.t("tut_decor_done")
	check(says_done, "the tip says to tap Done")
	done_btn.pressed.emit()
	await _frames(2)
	check(not game.modals.is_open(&"decoration"), "Done closes Decoration Mode")
	eq(sim.tutorial.guided_step, &"storage", "the lesson moves to Storage")
	check(hud.decoration_button().get_node_or_null(TutorialPulse.NODE_NAME) == null, "the button stops pulsing")
	# Buku Resep pertama: tur lengkap.
	sim.tutorial.on_event(&"storage_opened")
	var rb: RecipeBookScreen = game.modals.open(&"recipe_book") as RecipeBookScreen
	await _frames(3)
	var tour: CoachMarks = rb.tour()
	check(tour != null, "the Recipe Book opens with a spotlight tour")
	if tour == null:
		await _finish(game)
		return
	eq(tour.step_count(), 6, "six stops")
	var make: Button = rb.find_child("Make", true, false) as Button
	var targets: Array = [[rb._list.get_parent()], ["IngredientsCard"], ["EquipmentChip"], ["PriceRow", "PriceNote"],
		["BatchLabel", "Batch1", "Batch3", "Batch5"], ["Make"]]
	var inv: Transform2D = tour.get_global_transform().affine_inverse()
	for i in targets.size():
		await _frames(1)
		eq(tour.index(), i, "stop %d" % (i + 1))
		var want := Rect2()
		var first: bool = true
		for t: Variant in targets[i]:
			var ctl: Control = (t as Control) if t is Control else rb._detail.find_child(str(t), true, false) as Control
			var r: Rect2 = inv * ctl.get_global_rect()
			want = r if first else want.merge(r)
			first = false
		check(tour.hole().encloses(want), "stop %d spotlights its part of the book" % (i + 1))
		var make_r: Rect2 = inv * make.get_global_rect()
		if i < targets.size() - 1:
			check(not tour.hole().intersects(make_r), "stop %d: Make is still covered" % (i + 1))
			check(tour.next_button().visible, "stop %d has Next" % (i + 1))
			tour.next_button().pressed.emit()
		else:
			check(not tour.next_button().visible, "the last stop has no Next: tap Make itself")
	make.pressed.emit()
	await _frames(2)
	eq(sim.tutorial.guided_step, &"mixer", "Make orders the bread and the lesson moves to the mixer")
	check(not game.modals.is_open(&"recipe_book"), "and the book closes")
	# Buku Resep kedua: tur singkat.
	sim.tutorial._set_step(&"storage2")
	sim.tutorial.on_event(&"storage_opened")
	var rb2: RecipeBookScreen = game.modals.open(&"recipe_book") as RecipeBookScreen
	await _frames(3)
	var short: CoachMarks = rb2.tour()
	check(short != null and short.step_count() == 2, "the second book opens a short tour")
	if short != null:
		short.next_button().pressed.emit()
		await _frames(1)
		var row: Control = rb2._detail.find_child("MakeRow", true, false) as Control
		check(short.hole().encloses(short.get_global_transform().affine_inverse() * row.get_global_rect()), "its last stop is the batch size and Make")
	game.modals.close_all()
	await _finish(game)
