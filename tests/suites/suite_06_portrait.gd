extends TestSuite
## Bingkai potret, taplak di sisi, dan kamera potret (GDD idle 12.0).


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_PORTRAIT_FRAME", "name": "idle 12.0.2 the frame box is right for every screen shape (720 logical px wide, ratio clamped 9:16-9:21, centred) and taps outside it never reach the game", "fn": _frame},
		{"id": "ACC_IDLE_TABLECLOTH_SIDES", "name": "idle 12.0.3 outside the frame lies the gingham tablecloth with lace on the side touching the frame and faint floating icons; no game control is there; 9:16-9:21 phones show no tablecloth", "fn": _tablecloth},
		{"id": "ACC_IDLE_PORTRAIT_CAMERA", "name": "idle 12.0.4 the camera keeps the world width (KEEP_WIDTH); Tier 1-3 floors show whole across the screen between the HUD bars on 9:16 and 9:21; bigger floors follow the owner", "fn": _camera},
	]


## Ukuran logis jendela (stretch canvas_items + expand, dasar 720 x 1280) untuk
## layar `w` x `h` piksel.
static func _root_size(w: float, h: float) -> Vector2:
	var k: float = minf(w / 720.0, h / 1280.0)
	return Vector2(w, h) / k


func _frame() -> void:
	# Satu baris per bentuk layar di tabel Seksi 12.0.2 (plus batasnya).
	var rows: Array = [
		["laptop 16:9", Vector2(1920, 1080), Vector2(720, 1280), true],
		["ultrawide", Vector2(2560, 1080), Vector2(720, 1280), true],
		["tablet 4:3", Vector2(2048, 1536), Vector2(720, 1280), true],
		["tablet 3:4", Vector2(1536, 2048), Vector2(720, 1280), true],
		["phone 9:16", Vector2(1080, 1920), Vector2(720, 1280), false],
		["phone 19.5:9", Vector2(1080, 2340), Vector2(720, 1560), false],
		["phone 20:9", Vector2(1080, 2400), Vector2(720, 1600), false],
		["exactly 9:21", Vector2(900, 2100), Vector2(720, 1680), false],
		["slimmer than 9:21", Vector2(1080, 2880), Vector2(720, 1680), true],
	]
	for row: Array in rows:
		var root: Vector2 = _root_size((row[1] as Vector2).x, (row[1] as Vector2).y)
		var r: Rect2 = PortraitShell.frame_rect(root)
		var aspect: float = r.size.x / r.size.y
		check(aspect <= 9.0 / 16.0 + 0.0001 and aspect >= 9.0 / 21.0 - 0.0001, "%s: ratio clamped between 9:16 and 9:21 (%.4f)" % [row[0], aspect])
		near(r.get_center().x, root.x * 0.5, 0.01, "%s: centred across" % row[0])
		near(r.get_center().y, root.y * 0.5, 0.01, "%s: centred down" % row[0])
		eq(PortraitShell.logical_size(r), Vector2i((row[2] as Vector2)), "%s: logical frame %s" % [row[0], row[2]])
		var fills: bool = r.size.is_equal_approx(root)
		eq(not fills, bool(row[3]), "%s: tablecloth %s" % [row[0], "shows" if row[3] else "is not needed"])
	# Shell sungguhan: GameRoot di SubViewport 720 x H, dan ketukan di taplak diabaikan.
	PauseManager.clear_all()
	var was_unlocked: bool = AudioManager.unlocked
	var shell: PortraitShell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(shell)
	await runner.get_tree().process_frame
	check(shell.game != null and shell.game.get_viewport() == shell.viewport, "GameRoot lives inside the frame's SubViewport")
	shell.layout_for(Vector2(1600.0, 1280.0), 1.5)
	eq(shell.frame, Rect2(440.0, 0.0, 720.0, 1280.0), "a wide window gets a 9:16 frame in the middle")
	eq(shell.viewport.size_2d_override, Vector2i(720, 1280), "the game lays out in 720 x 1280 logical px")
	eq(shell.viewport.size, Vector2i(1080, 1920), "but renders at the screen's real pixels")
	near(shell.container.get_global_rect().size.x, 720.0, 0.01, "the frame covers exactly its box")
	shell.layout_for(Vector2(1600.0, 1280.0), 1.0)
	check(shell.game._splash != null, "the game waits on Tap to Start")
	_click(Vector2(200.0, 640.0))
	await runner.get_tree().process_frame
	check(shell.game._splash != null, "a tap on the tablecloth never reaches the game")
	_click(Vector2(800.0, 640.0))
	await runner.get_tree().process_frame
	check(shell.game._splash == null, "a tap inside the frame does")
	shell.queue_free()
	await runner.get_tree().process_frame
	check(PortraitShell.current == null, "the shell lets go of itself")
	AudioManager.set_music_state(&"")
	AudioManager.unlocked = was_unlocked
	PauseManager.clear_all()


func _click(at: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = at
		e.global_position = at
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		runner.get_viewport().push_input(e, true)


func _tablecloth() -> void:
	var cloth := TableclothSides.new()
	runner.add_child(cloth)
	# Layar lebar: taplak kiri dan kanan, rendanya di tepi bingkai.
	cloth.size = Vector2(1600.0, 1280.0)
	cloth.set_frame(Rect2(440.0, 0.0, 720.0, 1280.0))
	var regs: Array[Dictionary] = cloth.regions()
	eq(regs.size(), 2, "a wide screen has cloth on the left and the right")
	if regs.size() == 2:
		eq(regs[0]["rect"], Rect2(0.0, 0.0, 440.0, 1280.0), "left cloth fills up to the frame")
		eq(int(regs[0]["lace"]), SIDE_RIGHT, "with its lace on the frame side")
		eq(regs[1]["rect"], Rect2(1160.0, 0.0, 440.0, 1280.0), "right cloth from the frame to the edge")
		eq(int(regs[1]["lace"]), SIDE_LEFT, "with its lace on the frame side")
		var lace: PackedVector2Array = ProceduralUIFactory.lace_points(regs[0]["rect"], int(regs[0]["lace"]))
		var on_edge: bool = lace.size() > 10
		for p: Vector2 in lace:
			on_edge = on_edge and is_equal_approx(p.x, 440.0)
		check(on_edge, "the lace scallops run down the frame's edge")
	# Gingham: dua warna berselang-seling dalam petak 22 px, sama dengan layar pembuka.
	var cells: Array = ProceduralUIFactory.gingham_cells(Rect2(0.0, 0.0, 88.0, 44.0))
	eq(cells.size(), 8, "4 x 2 cells of 22 px")
	if cells.size() == 8:
		check(cells[0][1] != cells[1][1] and cells[1][1] != cells[5][1] and cells[0][1] == cells[2][1] and cells[1][1] == cells[4][1],
			"neighbouring cells alternate in a check pattern")
		eq(cells[0][1], Palette.GINGHAM_A.darkened(0.06), "the darkest cell is GINGHAM_A")
		eq(cells[5][1], Palette.GINGHAM_B, "the lightest cell is GINGHAM_B")
	check(cloth.floater_count() > 0, "faint icons float over the wide cloth")
	var hits: int = 0
	for n: Node in cloth.find_children("*", "Control", true, false):
		if (n as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
			hits += 1
	eq(hits, 0, "nothing on the cloth takes a tap")
	eq(cloth.mouse_filter, Control.MOUSE_FILTER_IGNORE, "nor the cloth itself")
	# Reduced Motion menghentikan ikonnya.
	var was_rm: Variant = SettingsManager.values.get("reduced_motion", false)
	SettingsManager.values["reduced_motion"] = true
	var ic: Control = cloth._floaters[0]["icon"]
	var p0: Vector2 = ic.position
	cloth._process(0.5)
	eq(ic.position, p0, "Reduced Motion: the icons hold still")
	SettingsManager.values["reduced_motion"] = false
	cloth._process(0.5)
	check(ic.position != p0, "otherwise they bob gently")
	SettingsManager.values["reduced_motion"] = was_rm
	# Layar sangat ramping: pita di atas dan bawah.
	cloth.size = Vector2(720.0, 1920.0)
	cloth.set_frame(Rect2(0.0, 120.0, 720.0, 1680.0))
	var regs2: Array[Dictionary] = cloth.regions()
	eq(regs2.size(), 2, "a very slim screen has bands above and below")
	if regs2.size() == 2:
		eq(int(regs2[0]["lace"]), SIDE_BOTTOM, "the top band's lace touches the frame")
		eq(int(regs2[1]["lace"]), SIDE_TOP, "and so does the bottom band's")
	# HP 9:16 sampai 9:21: bingkai mengisi layar, tanpa taplak.
	for h: float in [1280.0, 1560.0, 1680.0]:
		cloth.size = Vector2(720.0, h)
		cloth.set_frame(PortraitShell.frame_rect(Vector2(720.0, h)))
		eq(cloth.regions().size(), 0, "a 720 x %d phone shows no tablecloth" % int(h))
		eq(cloth.floater_count(), 0, "and no icons")
	cloth.queue_free()
	# Kontrol game hanya ada di dalam bingkai: seluruh GameRoot hidup di SubViewport.
	var shell: PortraitShell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(shell)
	await runner.get_tree().process_frame
	shell.game.skip_splash_for_tests()
	shell.game.show_main_menu()
	await runner.get_tree().process_frame
	var outside: int = 0
	for n2: Node in shell.find_children("*", "Control", true, false):
		if not shell.viewport.is_ancestor_of(n2) and n2 != shell.container and not shell.cloth.is_ancestor_of(n2) and n2 != shell.cloth and n2.name != "Bg":
			outside += 1
	eq(outside, 0, "every game control sits inside the frame")
	check(shell.game.modals.is_open(&"main_menu") and shell.viewport.is_ancestor_of(shell.game.modals), "the menus too")
	shell.game.modals.close_all()
	shell.queue_free()
	await runner.get_tree().process_frame
	AudioManager.set_music_state(&"")


func _camera() -> void:
	PauseManager.clear_all()
	var top: float = DataRegistry.balf("camera.portrait_hud_top_px")
	var bottom: float = DataRegistry.balf("camera.portrait_hud_bottom_px")
	for h: int in [1280, 1680]:
		for tier in range(1, 4):
			var s: SimulationRoot = new_sim(1200 + tier)
			s.tutorial.skip()
			jump_to_tier(s, tier)
			var vp := SubViewport.new()
			vp.size = Vector2i(720, h)
			vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
			runner.add_child(vp)
			var world := WorldView.new()
			vp.add_child(world)
			world.setup(s)
			var rig: CameraRig = world.camera_rig
			eq(rig.camera.keep_aspect, Camera3D.KEEP_WIDTH, "the camera keeps the world width")
			near(rig.camera.size, DataRegistry.balf("camera.portrait_width_m"), 0.0001, "and shows camera.portrait_width_m across")
			for fid: StringName in s.world.floor_ids():
				world.view_floor_override = fid
				world._process(0.016)
				await runner.get_tree().create_timer(0.3).timeout
				# Kamera meluncur halus ke tengah lantai; satu langkah panjang menuntaskannya.
				world._process(1.0)
				world._process(1.0)
				eq(rig.active_floor, fid, "T%d @720x%d: the view is on %s" % [tier, h, fid])
				var sz: Vector2 = Vector2(s.world.grid(fid).size) * GridMath.WORLD_METERS_PER_TILE
				var ok: bool = true
				var worst: String = ""
				for c: Vector3 in [Vector3.ZERO, Vector3(sz.x, 0.0, 0.0), Vector3(0.0, 0.0, sz.y), Vector3(sz.x, 0.0, sz.y)]:
					var p: Vector2 = rig.world_to_screen(c)
					if p.x < 0.0 or p.x > 720.0 or p.y < top or p.y > float(h) - bottom:
						ok = false
						worst = "%s -> %s" % [c, p]
				check(ok, "T%d @720x%d: all of %s shows between the HUD bars %s" % [tier, h, fid, worst])
				check(not rig._floor_exceeds_view(), "T%d %s fits, so the camera frames it whole" % [tier, fid])
			vp.queue_free()
			await runner.get_tree().process_frame
			free_sim(s)
	# Tier 4–5: lantainya lebih lebar dari layar, kamera mengikuti pemilik.
	var big: SimulationRoot = new_sim(1204)
	big.tutorial.skip()
	jump_to_tier(big, 4)
	var vp2 := SubViewport.new()
	vp2.size = Vector2i(720, 1280)
	vp2.render_target_update_mode = SubViewport.UPDATE_DISABLED
	runner.add_child(vp2)
	var w2 := WorldView.new()
	vp2.add_child(w2)
	w2.setup(big)
	w2._process(0.016)
	check(w2.camera_rig._floor_exceeds_view(), "a Tier 4 floor is bigger than the screen, so the camera follows the owner")
	vp2.queue_free()
	await runner.get_tree().process_frame
	free_sim(big)
