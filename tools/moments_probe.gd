extends Node
## Probe momen dunia (GDD idle §20 no. 71): membuka toko di tier `--from`,
## merekrut satu staf (`--role=baker|cashier`) dan memotret sambutannya, lalu
## membuka satu stasiun (`--station=mixer|oven|display`) dan memotret kardusnya.
## Potret penuh plus potongan 2x di sekitar kejadiannya. Save memakai folder uji
## sendiri. Jalankan dengan jendela (perlu renderer):
##   godot --path . --resolution 720x1280 res://tools/moments_probe.tscn -- --from=1 --role=cashier --station=display
## Folder potret: env LINEUP_OUT, atau user://moments bila tidak diisi.

var game: GameRoot = null
var shell: PortraitShell = null
var _out: String = ""
var _from: int = 1
var _role: StringName = &"cashier"
var _station: StringName = &"display"


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			_from = int(a.substr(7))
		elif a.begins_with("--role="):
			_role = StringName(a.substr(7))
		elif a.begins_with("--station="):
			_station = StringName(a.substr(10))
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://moments")
	DirAccess.make_dir_recursive_absolute(_out)
	PauseManager.lifecycle_enabled = false
	SaveManager.dir = "user://test_saves_moments"
	Monetization.use_test_file("moments_probe")
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(shell)
	game = shell.game
	await _frames(2)
	game.skip_splash_for_tests()
	await _frames(2)
	await game.start_new_game(&"profile_1", "female", "Moments Bakery")
	await _frames(10)
	var sim: SimulationRoot = game.sim
	sim.tutorial.skip()
	while sim.world.location.tier < _from:
		sim.debug_add_kr(sim.location_price(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	game.modals.close_all()
	PauseManager.clear_all()
	game.playing = true
	for i in 120:
		await get_tree().process_frame
	# 1. Rekrut.
	sim.debug_add_kr(1.0e9)
	var sid: StringName = &""
	for st: StaffDefinition in DataRegistry.staff_list():
		if st.role_id == _role and sim.staff.hire_block(st.id) == &"":
			sid = st.id
			break
	print("MOMENTS hire %s: %s" % [_role, sim.staff.hire(sid) if sid != &"" else &"none"])
	var t: float = 0.0
	var n: int = 0
	while t < 6.0:
		await _shot("hire_%02d" % n, _door3())
		n += 1
		for k in 18:
			t += get_process_delta_time()
			await get_tree().process_frame
		if game.world.moments.welcomes.is_empty() and t > 1.0:
			break
	print("MOMENTS welcome done in %.1f s" % t)
	# 2. Stasiun baru.
	var iid: int = sim.upgrades.open_station(_station)
	print("MOMENTS open %s: iid %d" % [_station, iid])
	var at: Vector3 = game.world.top_of_iid(iid) if iid >= 0 else _door3()
	t = 0.0
	n = 0
	while t < 2.6:
		await _shot("open_%02d" % n, at)
		n += 1
		for k2 in 6:
			t += get_process_delta_time()
			await get_tree().process_frame
	print("MOMENTS delivery done, deliveries left %d" % game.world.moments.deliveries.size())
	# 3. Resep baru (GDD idle §20 no. 73): Unlock di lembar Menu.
	var menu: MenuScreen = game.modals.open(&"menu", {}) as MenuScreen
	await _frames(3)
	var unlock: Button = menu.unlock_button() if menu != null else null
	print("MOMENTS unlock button: %s" % (unlock != null))
	if unlock != null:
		unlock.pressed.emit()
		t = 0.0
		n = 0
		for at_s: float in [0.05, 0.25, 0.6, 1.4, 2.55, 2.75, 3.2]:
			while t < at_s:
				t += get_process_delta_time()
				await get_tree().process_frame
			await _shot("recipe_%02d" % n, Vector3.INF)
			n += 1
		print("MOMENTS reveal open after: %s" % game.modals.is_open(&"recipe_reveal"))
	game.end_session()
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	get_tree().quit()


func _door3() -> Vector3:
	var d: Vector2 = GridMath.cell_center(game.sim.world.location.entrance_cell)
	return Vector3(d.x, 0.6, d.y)


func _shot(label: String, focus: Vector3) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out.path_join("t%d_%s.png" % [_from, label]))
	if focus == Vector3.INF:
		return
	var gimg: Image = game.get_viewport().get_texture().get_image()
	gimg.convert(Image.FORMAT_RGB8)
	var p: Vector2 = game.world.camera_rig.world_to_screen(focus)
	p *= Vector2(gimg.get_size()) / game.get_viewport().get_visible_rect().size
	var half := Vector2i(150, 150)
	var r := Rect2i(Vector2i(p) - half, half * 2).intersection(Rect2i(Vector2i.ZERO, gimg.get_size()))
	if r.size.x < 20 or r.size.y < 20:
		return
	var crop: Image = gimg.get_region(r)
	crop.resize(r.size.x * 2, r.size.y * 2, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join("t%d_%s_zoom.png" % [_from, label]))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
