extends Node
## Probe cutscene pindah lokasi (GDD idle §20 no. 70): membuka toko di tier
## `--from`, mengisi stasiun dan staf (`--bare` = toko awal apa adanya), lalu
## menekan Move dan memotret adegannya tiap `--every` detik nyata sampai kru masuk
## toko baru. Kartu Pak Lurah dipotret lalu ditekan. Save memakai folder uji
## sendiri. Jalankan dengan jendela (perlu renderer):
##   godot --path . --resolution 540x960 res://tools/move_cutscene_probe.tscn -- --from=1 --every=0.5
## `--skip=S` menekan Skip S detik setelah mulai; `--busy` membuat lalu lintas
## sepadat mungkin, dan setiap frame badan truk diperiksa terhadap badan setiap
## kendaraan (baris "MOVING HIT" bila bertumpuk, ringkasan "MOVING traffic"). Folder potret: env LINEUP_OUT,
## atau user://moving bila tidak diisi. Baris "MOVING <detik> <fase>" mencatat
## pergantian fase, dan "MOVING done" mengakhiri probe.

var game: GameRoot = null
var shell: PortraitShell = null
var _out: String = ""
var _from: int = 1
var _every: float = 0.5
var _bare: bool = false
var _skip_at: float = -1.0
## Close-up: --cab memotret kabin sopir 4x, selain itu seluruh truk 2x.
var _cab: bool = false
var _zoom_at: Vector3 = Vector3(0.0, 0.8, 0.0)
## --busy: lalu lintas sepadat mungkin; pemeriksa tabrakan truk tiap frame.
var _busy: bool = false
var _checked: int = 0
var _hits: int = 0
var _seen: Dictionary = {}


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--from="):
			_from = int(a.substr(7))
		elif a.begins_with("--every="):
			_every = float(a.substr(8))
		elif a == "--bare":
			_bare = true
		elif a.begins_with("--skip="):
			_skip_at = float(a.substr(7))
		elif a == "--busy":
			_busy = true
		elif a == "--cab":
			_cab = true
			_zoom_at = Vector3(TrafficFactory.TRUCK_DRIVER.x, 1.0, TrafficFactory.TRUCK_DRIVER.z)
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://moving")
	DirAccess.make_dir_recursive_absolute(_out)
	PauseManager.lifecycle_enabled = false
	SaveManager.dir = "user://test_saves_moving"
	Monetization.use_test_file("move_cutscene_probe")
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(shell)
	game = shell.game
	await _frames(2)
	game.skip_splash_for_tests()
	await _frames(2)
	await game.start_new_game(&"profile_1", "female", "Probe Bakery")
	await _frames(10)
	var sim: SimulationRoot = game.sim
	sim.tutorial.skip()
	while sim.world.location.tier < _from:
		sim.debug_add_kr(sim.location_price(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	if not _bare:
		sim.debug_add_kr(1.0e15)
		for cat: StringName in [&"display", &"oven", &"mixer"]:
			while sim.upgrades.open_station(cat) >= 0:
				pass
		for role: StringName in [&"cashier", &"baker"]:
			for st: StaffDefinition in DataRegistry.staff_list():
				if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
					break
				if st.role_id == role and not sim.staff.is_employed(st.id):
					sim.staff.hire(st.id, true)
	game.modals.close_all()
	PauseManager.clear_all()
	game.playing = true
	# Biarkan toko berjalan sebentar supaya staf menyebar ke tempat kerjanya.
	for i in 240:
		if _busy:
			_crowd()
		await get_tree().process_frame
	sim.debug_add_kr(sim.location_price(sim.world.location.tier + 1))
	await _shot("00_before")
	var r: String = game.start_move()
	print("MOVING start from tier %d: %s" % [_from, r if r != "" else "ok"])
	var scr: MovingCutscene = game.modals.screen(&"moving_cutscene") as MovingCutscene
	if scr == null:
		print("MOVING no cutscene")
		get_tree().quit(1)
		return
	var t: float = 0.0
	var next_shot: float = 0.0
	var last_phase: int = -1
	var n: int = 1
	var skipped: bool = false
	var greeted: float = -1.0
	while is_instance_valid(scr) and scr.is_inside_tree() and t < 60.0:
		var dt: float = get_process_delta_time()
		await get_tree().process_frame
		t += dt
		if not is_instance_valid(scr) or not scr.is_inside_tree():
			break
		var d: MovingDay = scr.director
		if _busy:
			_crowd()
		_check_hits(d, t)
		var ph: int = d.phase if d != null and is_instance_valid(d) else -1
		if ph != last_phase:
			last_phase = ph
			print("MOVING %.2f %s" % [t, MovingDay.Phase.find_key(ph) if ph >= 0 else "none"])
		if _skip_at >= 0.0 and t >= _skip_at and not skipped:
			skipped = true
			print("MOVING %.2f skip" % t)
			scr.skip()
		if t >= next_shot:
			next_shot += _every
			await _shot("%02d_%s" % [n, MovingDay.Phase.find_key(ph) if ph >= 0 else "none"])
			n += 1
		if not is_instance_valid(scr) or not scr.is_inside_tree():
			break
		if scr.continue_button() != null:
			if greeted < 0.0:
				greeted = t
				await _shot("%02d_card" % n)
				n += 1
			elif t - greeted > 1.0:
				scr.continue_button().pressed.emit()
	# Truk masih pergi sendiri sesudah cutscene ditutup: tetap diawasi.
	var left: MovingDay = game.world.find_child("MovingDay", false, false) as MovingDay
	var t2: float = 0.0
	while left != null and is_instance_valid(left) and t2 < 15.0:
		t2 += get_process_delta_time()
		if _busy:
			_crowd()
		_check_hits(left, t + t2)
		await get_tree().process_frame
	for i in 30:
		await get_tree().process_frame
	await _shot("99_after")
	print("MOVING traffic checks: %d frames, %d vehicles near the truck, %d overlaps" % [_checked, _seen.size(), _hits])
	print("MOVING done in %.1f s, tier now %d, cutscene open %s" % [t, game.sim.world.location.tier, game.modals.is_open(&"moving_cutscene")])
	game.end_session()
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	get_tree().quit()


## Lalu lintas sepadat mungkin (--busy): setiap lajur mencoba memunculkan
## kendaraan tiap frame (aturan jarak muncul StreetLife tetap berlaku).
func _crowd() -> void:
	var street: StreetLife = game.world.street_life if game.world != null else null
	if street == null:
		return
	for lane: Dictionary in street.lanes:
		lane["next"] = minf(float(lane["next"]), 0.0)


## Badan truk dan badan setiap kendaraan StreetLife tidak boleh bertumpuk.
func _check_hits(d: MovingDay, t: float) -> void:
	var street: StreetLife = game.world.street_life if game.world != null else null
	if street == null or d == null or not is_instance_valid(d) or d.truck == null or street.guest.is_empty():
		return
	_checked += 1
	var g: Dictionary = street.guest
	var gx: float = float(g["x"])
	var gz: float = float(g["z"])
	for lane: Dictionary in street.lanes:
		for car: Dictionary in lane["cars"]:
			var inf: Dictionary = TrafficFactory.info(car["kind"])
			var cz: float = float(car["z"]) + float(car.get("offset", 0.0))
			var dx: float = absf(float(car["x"]) - gx) - (float(g["len"]) + float(car["len"])) * 0.5
			var dz: float = absf(cz - gz) - (float(g["width"]) + float(inf["width"])) * 0.5
			if dx < 3.0 and dz < 0.3:
				_seen[car.get("node")] = true
			if dx < -0.02 and dz < -0.02:
				_hits += 1
				if _hits <= 10:
					print("MOVING HIT %.2f %s at x %.2f z %.2f (truck x %.2f z %.2f, phase %s)" % [t, car["kind"], float(car["x"]), cz,
						gx, gz, MovingDay.Phase.find_key(d.phase)])


func _shot(label: String) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.save_png(_out.path_join("t%d_%s.png" % [_from, label]))
	# Close-up 2x di sekitar truk (dari gambar SubViewport game).
	var scr: MovingCutscene = game.modals.screen(&"moving_cutscene") as MovingCutscene if game != null and game.modals != null else null
	var d: MovingDay = scr.director if scr != null else null
	if d == null or not is_instance_valid(d) or d.truck == null:
		return
	var gimg: Image = game.get_viewport().get_texture().get_image()
	gimg.convert(Image.FORMAT_RGB8)
	var at: Vector2 = game.world.camera_rig.world_to_screen(d.truck.global_transform * _zoom_at)
	at *= Vector2(gimg.get_size()) / game.get_viewport().get_visible_rect().size
	var half := Vector2i(170, 170) / (2 if _cab else 1)
	var r := Rect2i(Vector2i(at) - half, half * 2).intersection(Rect2i(Vector2i.ZERO, gimg.get_size()))
	if r.size.x < 20 or r.size.y < 20:
		return
	var crop: Image = gimg.get_region(r)
	var z: int = 4 if _cab else 2
	crop.resize(r.size.x * z, r.size.y * z, Image.INTERPOLATE_NEAREST)
	crop.save_png(_out.path_join("t%d_%s_zoom.png" % [_from, label]))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
