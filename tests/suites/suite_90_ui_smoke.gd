extends TestSuite
## Smoke UI: scene utama sungguhan, New Game lewat GameRoot, lalu setiap layar
## dibuka & ditutup sekali, dan beberapa tap dunia disimulasikan. Menangkap
## error runtime di build() layar yang tidak terjangkau test logika.

const SCREENS: Array[StringName] = [
	&"settings", &"credits", &"help", &"stats", &"pause", &"recipe_book", &"market", &"staff",
	&"marketing", &"decoration", &"rotifood", &"display_detail", &"debug", &"tutorial", &"lifecycle",
]


func tests() -> Array:
	return [
		{"id": "TEST_UI_SMOKE_001", "name": "main scene boots, new game, every screen opens", "fn": _smoke},
		# Setelah smoke: kunci yang diminta saat runtime ikut diperiksa.
		{"id": "TEST_UI_001", "name": "English localization key completeness", "fn": _localization},
		{"id": "TEST_CAMERA_001", "name": "0.20s crossfade + active-floor rule", "fn": _camera},
	]


func _smoke() -> void:
	SaveManager.dir = "user://test_saves_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var scene: PackedScene = load("res://scenes/main.tscn")
	var game: GameRoot = scene.instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.show_main_menu()
	check(game.modals.is_open(&"main_menu"), "main menu opens")
	game.modals.open(&"profiles", {"mode": "new"})
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.modals.open(&"new_game", {"profile_id": &"profile_1"})
	await runner.get_tree().process_frame
	game.modals.close_all()
	await game.start_new_game(&"profile_1", "female", "UI Test Bakery")
	await runner.get_tree().process_frame
	check(game.sim != null and game.world != null and game.hud != null, "gameplay built")
	check(SaveManager.has_profile(&"profile_1"), "day 1 save written (GDD 89.4)")
	for id: StringName in SCREENS:
		var params: Dictionary = {}
		if id == &"display_detail":
			params = {"display": game.sim.equipment.placed_list(&"display")[0].iid}
		if id == &"tutorial":
			params = {"key": "tut_welcome"}
		var s: UIScreen = game.modals.open(id, params)
		check(s != null, "screen %s opens" % id)
		await runner.get_tree().process_frame
		game.modals.close_all()
		await runner.get_tree().process_frame
	# Decoration Mode (GDD 72.2, keputusan maintainer 2026-10-01): seperti The
	# Sims. Ketuk perabot untuk mengangkatnya; ketukan berikutnya hanya memindah
	# posisi calonnya; tata letak baru berubah saat Place.
	PauseManager.clear_all()
	var deco: DecorationScreen = game.modals.open(&"decoration", {})
	await runner.get_tree().process_frame
	var rig: CameraRig = game.world.camera_rig
	check(rig.free_pan, "decoration mode enables free panning")
	# Tanpa panel samping (keputusan maintainer 2026-09-30): tampilan tetap di tengah.
	check(rig.pan_offset.length() < 0.001, "no side panel to dodge: the view starts centred")
	check(deco.toolbar() != null and not deco.toolbar().visible, "no action toolbar before anything is picked up")
	eq(deco._status.text, Tx.t("ui_decor_hint"), "the hint says how to pick furniture up")
	var before_pan: Vector3 = rig.pan_offset
	rig.pan_by_screen(Vector2(-120, 40))
	check(rig.pan_offset.distance_to(before_pan) > 0.05, "dragging pans the view even on a small floor")
	check(game.world._tile_overlay.get_child_count() > 0, "keep-clear tiles are marked in decoration mode")
	var disp: EquipmentInstance = game.sim.equipment.placed_list(&"display")[0]
	var disp_anchor: Vector2i = disp.anchor
	var disp_box: AABB = game.world._aabbs[disp.iid]["aabb"]
	deco._on_world_tap(game.world.screen_of_iid(disp.iid))
	eq(deco._sel_iid, disp.iid, "tapping furniture picks it up")
	check(game.world._ghosts.get_child_count() > 0, "its footprint is marked on the floor")
	check(not deco._warn.visible, "no warning before a rejected placement")
	eq(game.world.lifted_iid(), disp.iid, "the held furniture is lifted")
	eq(deco._status.text, Tx.t("ui_decor_move_hint"), "the hint says to drag it or tap a tile, then Place")
	await runner.get_tree().process_frame
	var tb: DecorationScreen.ActionBar = deco.toolbar()
	check(tb.visible, "the action toolbar appears for the held furniture")
	var anchor: Vector2 = rig.world_to_screen(game.world.top_of_iid(disp.iid))
	var tb_rect := Rect2(tb.position, tb.panel.size)
	check(tb_rect.end.y <= anchor.y + 1.0 and anchor.x >= tb_rect.position.x and anchor.x <= tb_rect.end.x,
		"the toolbar floats right above the held furniture (%s over %s)" % [tb_rect, anchor])
	check(deco._tb_place.visible and deco._tb_rotate.visible and deco._tb_store.visible and deco._tb_cancel.visible,
		"Place, Rotate, Put Away and Cancel sit on the toolbar")
	# Ubin jalur: posisi calon merah beserta alasannya, dan Place menolak dengan banner.
	var fg: FloorGrid = game.sim.world.grid(disp.floor_id)
	var walkway: Vector2i = Vector2i(-1, -1)
	for c: Vector2i in fg.def.protected_cells:
		if fg.is_store(c) and fg.in_bounds(c + Vector2i(1, 0)) and fg.flag(c + Vector2i(1, 0)) == FloorGrid.Flag.WALKABLE_NO_BUILD:
			walkway = c
			break
	check(walkway.x >= 0, "found a store walkway tile")
	deco._on_world_tap(game.world.camera_rig.world_to_screen(GridMath.cell_center3(walkway)))
	await runner.get_tree().process_frame
	check(deco._cand_reason != &"", "a walkway tile is not a valid spot")
	eq(deco._status.text, deco._reason_text(deco._cand_reason), "the hint names the reason")
	eq(disp.anchor, disp_anchor, "nothing moves in the shop before Place")
	deco._place()
	check(deco._warn.visible, "Place on a walkway tile shows the warning banner")
	eq(deco._warn_detail.text, Tx.t("ui_decor_warn_walkway"), "the banner says it would block the walkway")
	eq(disp.anchor, disp_anchor, "the display was not put on the walkway")
	eq(deco._sel_iid, disp.iid, "and it is still held, ready to try somewhere else")
	# Ketuk perabot lain sambil memegang: TIDAK memilihnya (dulu berganti pilihan).
	var storage0: EquipmentInstance = game.sim.equipment.storage_instance()
	var spos: Vector2 = game.world.screen_of_iid(storage0.iid)
	eq(game.world.pick(spos).get("iid", -1), storage0.iid, "that spot shows the storage")
	deco._on_world_tap(spos)
	eq(deco._sel_iid, disp.iid, "tapping other furniture while holding never picks it instead")
	eq(Vector2i(game.world.held()["cell"]), deco._clamp_anchor(deco._anchor_for(game.world.cell_at_screen(spos))),
		"the display moves to the floor tile under the finger, even one hidden behind other furniture")
	# Ketuk perabot yang dipegang itu sendiri: tidak membatalkan (dulu meletakkannya).
	deco._on_world_tap(game.world.screen_of_iid(disp.iid))
	check(deco.has_selection() and deco._sel_iid == disp.iid, "tapping the held furniture itself never drops it")
	# Cancel: semuanya kembali seperti semula.
	deco._cancel()
	check(not deco.has_selection(), "Cancel lets go of it")
	eq(disp.anchor, disp_anchor, "the display stays where it was")
	eq(game.world.lifted_iid(), -1, "nothing is lifted after Cancel")
	check((game.world._aabbs[disp.iid]["aabb"] as AABB).is_equal_approx(disp_box), "its model is back on its own tiles")
	# Gudang tidak bisa disimpan, jadi Put Away disembunyikan.
	deco._on_world_tap(game.world.screen_of_iid(storage0.iid))
	await runner.get_tree().process_frame
	eq(deco._sel_iid, storage0.iid, "with nothing held, tapping furniture picks it up")
	check(not deco._tb_store.visible, "the storage cannot be put away, so the toolbar hides Put Away")
	check(deco.on_back() and not deco.has_selection() and game.modals.is_open(&"decoration"),
		"Back first puts the held furniture back and keeps decoration mode open")
	# Putar di tempat: alat pertama yang masih muat setelah diputar 90 derajat.
	var turned: EquipmentInstance = null
	var want_rot: int = 0
	for e: EquipmentInstance in game.sim.equipment.placed_list():
		if game.sim.equipment.is_in_use(e.iid):
			continue
		var fp: Vector2i = e.def().footprint_tiles
		var cur: Vector2i = GridMath.rotated_footprint(fp, e.rotation)
		var r2: int = (e.rotation + 1) % 4
		var nxt: Vector2i = GridMath.rotated_footprint(fp, r2)
		var keep: Vector2i = e.anchor + Vector2i((cur.x - 1) / 2, (cur.y - 1) / 2) - Vector2i((nxt.x - 1) / 2, (nxt.y - 1) / 2)
		if game.sim.world.validate_placement(e, e.floor_id, keep, r2) == &"":
			turned = e
			want_rot = r2
			break
	check(turned != null, "some furniture can turn in place")
	if turned != null:
		var old_rot: int = turned.rotation
		deco._hold_equipment(turned.iid)
		deco._rotate()
		eq(int(game.world.held()["rot"]), want_rot, "Rotate turns the held furniture right where it stands")
		eq(turned.rotation, old_rot, "the turn is only a preview until Place")
		deco._place()
		eq(turned.rotation, want_rot, "Place keeps the turn")
		check(turned.placed and not deco.has_selection(), "Place puts it down and lets go")
	game.modals.close_all()
	await runner.get_tree().process_frame
	check(not rig.free_pan and rig.pan_offset == Vector3.ZERO, "normal framing restored after decoration mode")
	await runner.get_tree().process_frame
	eq(game.world._tile_overlay.get_child_count(), 0, "tile marks removed after decoration mode")
	# Tap dunia: ketuk Storage lewat picking layar.
	PauseManager.clear_all()
	game.sim.tutorial.skip()
	var storage: EquipmentInstance = game.sim.equipment.storage_instance()
	var pos: Vector2 = game.world.screen_of_iid(storage.iid)
	check(pos.x >= 0.0, "storage projects to screen")
	var pick: Dictionary = game.world.pick(pos)
	eq(pick.get("kind"), &"equipment", "tapping storage picks equipment")
	game._on_world_tap(pos)
	for i in 120:
		game.sim.step(game.sim.tick_seconds)
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"recipe_book"), "walking to storage opens the Recipe Book")
	game.modals.close_all()
	# Hari penuh dengan bot sambil HUD & dunia menyinkron.
	var bot := SimBot.new(game.sim)
	var frames: int = 0
	while game.sim.is_running() and frames < 200000:
		bot.think()
		game.sim.step(game.sim.tick_seconds)
		frames += 1
		if frames % 600 == 0:
			await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"daily_summary"), "daily summary opens at 18:00")
	game.modals.close_all()
	game.return_to_menu()
	await runner.get_tree().process_frame
	check(game.sim == null, "simulation torn down on return to menu (GDD 35.2)")
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"


func _localization() -> void:
	var r: Dictionary = StringLint.run(true)
	check(int(r["files"]) > 50, "scanned %d scripts" % int(r["files"]))
	eq(r["missing"], {}, "every referenced string key exists in strings_en.json")
	eq(r["empty"], [], "no empty strings")
	eq(r["bad"], {}, "player-facing strings are English with valid placeholders")


func _camera() -> void:
	SaveManager.dir = "user://test_saves_ui"
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Camera Test")
	await runner.get_tree().process_frame
	var sim: SimulationRoot = game.sim
	near(DataRegistry.balf("camera.crossfade_seconds"), 0.20, 0.0001, "crossfade duration is 0.20 s (GDD 30.2)")
	jump_to_tier(sim, 2)
	game.modals.close_all()
	PauseManager.clear_all()
	sim.tutorial.skip()
	await runner.get_tree().process_frame
	var rig: CameraRig = game.world.camera_rig
	var store: StringName = sim.world.store_floor()
	var kitchen: StringName = sim.world.kitchen_floor()
	var p: SimActor = sim.player.actor
	p.place_at(store, sim.queue.main_lane().cashier_point)
	for i in 3:
		await runner.get_tree().process_frame
	eq(rig.active_floor, store, "camera shows the player's floor")
	# NPC/staf di lantai lain tidak memindahkan kamera (GDD 81 no.27).
	var fake := SimActor.new()
	fake.place_at(kitchen, Vector2i(2, 2))
	sim.staff.actors[&"staff_baker_joko"] = fake
	for i2 in 5:
		await runner.get_tree().process_frame
	eq(rig.active_floor, store, "staff on another floor does not move the camera")
	sim.staff.actors.erase(&"staff_baker_joko")
	# Alert OVERBAKING di lantai lain: alert kritis, kamera tetap (GDD 81 no.26).
	var oven: EquipmentInstance = sim.equipment.placed_list(&"oven")[0]
	var j: ProductionJob = sim.production.create_job(&"recipe_plain_loaf", 1, &"test")
	sim.production.start_mixing(j.job_id, &"test", 1.0)
	sim.run_for(j.stage_duration + 0.1)
	sim.production.pickup_dough(j.job_id, &"test")
	sim.production.insert_oven(j.job_id, oven.iid, &"test", 1.0)
	sim.run_for(j.stage_duration + oven.def().perfect_window_seconds + 1.0)
	eq(j.stage, ProductionJob.OVERBAKING, "upstairs oven overbaking")
	var off: Array[Dictionary] = sim.alerts.off_floor_alerts(store)
	check(not off.is_empty() and int(off[0]["priority"]) == 0, "critical off-floor alert raised")
	game.hud._refresh_all()
	var alert_btn: Node = game.hud._alerts_box.get_child(0) if game.hud._alerts_box.get_child_count() > 0 else null
	check(alert_btn is Button, "the HUD shows the off-floor alert as a button")
	game.hud._refresh_all()
	game.hud._refresh_all()
	check(is_instance_valid(alert_btn) and alert_btn.get_parent() == game.hud._alerts_box, "the alert button survives HUD refreshes, so a tap on it is not lost")
	for i3 in 5:
		await runner.get_tree().process_frame
	eq(rig.active_floor, store, "off-floor alert does not move the camera")
	# Pemain pindah lantai: kamera berganti dengan crossfade ~0,20 s nyata,
	# simulasi tidak dijeda dan tidak menunggu.
	var sim_t0: float = sim.time.sim_seconds
	p.place_at(kitchen, sim.world.grid(kitchen).def.portal["access"])
	var started: int = Time.get_ticks_usec()
	var seen_fade: bool = false
	var ended: int = -1
	var guard: int = 0
	while guard < 2000:
		await runner.get_tree().process_frame
		guard += 1
		var a: float = rig._fade.color.a
		if a > 0.01:
			seen_fade = true
		elif seen_fade:
			ended = Time.get_ticks_usec()
			break
	eq(rig.active_floor, kitchen, "camera follows the player upstairs")
	check(seen_fade, "a crossfade played")
	var dur: float = float(ended - started) / 1000000.0
	check(ended > 0 and dur >= 0.15 and dur <= 0.45, "crossfade lasts about 0.20 s (%.3f s)" % dur)
	check(not PauseManager.is_paused(), "floor change does not pause the simulation")
	check(sim.time.sim_seconds > sim_t0, "simulation kept running during the crossfade")
	game.return_to_menu()
	await runner.get_tree().process_frame
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
