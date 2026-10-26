extends Node
## Sapuan resolusi dan skala teks (GDD idle 12.0.7, menggantikan v3.1 110):
## membuka layar-layar utama (menu dan dalam game) di setiap ukuran matriks
## potret, tablet, dan laptop/PC, pada skala teks 100/125/150%, memotretnya, dan
## mencetak "SWEEP OFF" untuk setiap Control yang tampak tetapi keluar dari layar
## (di luar ScrollContainer). Save memakai folder uji sendiri. Jalankan dengan
## jendela (perlu renderer), lalu baca baris "SWEEP done, N issues":
##   godot --path . --resolution 540x960 res://tools/ui_resolution_sweep.tscn
## Folder potret: env LINEUP_OUT, atau user://lineup bila tidak diisi.
## Filter opsional: -- --res=720x1280,1920x1080 --scales=100,150
## --screens=welcome_back,franchise (menu utama dilewati bila --screens diisi).

const RES: Array[Vector2i] = [Vector2i(720, 1280), Vector2i(1080, 1920), Vector2i(1080, 2340), Vector2i(1080, 2400),
	Vector2i(1536, 2048), Vector2i(2048, 1536), Vector2i(1280, 720), Vector2i(1366, 768), Vector2i(1920, 1080),
	Vector2i(2560, 1440), Vector2i(2560, 1080)]
const SCALES: Array[int] = [100, 125, 150]
const MENU_SCREENS: Array[StringName] = [&"main_menu", &"settings", &"credits", &"help", &"profiles", &"new_game"]
const OPEN_SCREENS: Array[StringName] = [&"upgrades", &"menu", &"staff", &"shop", &"franchise", &"stats", &"pause", &"settings",
	&"welcome_back", &"franchise_cutscene", &"tutorial"]

var game: GameRoot = null
var shell: PortraitShell = null
var _out: String = ""
var _issues: int = 0
var _res: Array[Vector2i] = RES.duplicate()
var _scales: Array[int] = SCALES.duplicate()
var _screens: Array[StringName] = []


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--res="):
			_res.clear()
			for t: String in a.substr(6).split(","):
				var wh: PackedStringArray = t.split("x")
				_res.append(Vector2i(int(wh[0]), int(wh[1])))
		elif a.begins_with("--scales="):
			_scales.clear()
			for t2: String in a.substr(9).split(","):
				_scales.append(int(t2))
		elif a.begins_with("--screens="):
			for t3: String in a.substr(10).split(","):
				_screens.append(StringName(t3))
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(_out)
	PauseManager.lifecycle_enabled = false
	# Folder save uji sendiri: jangan pernah menyentuh save pemain.
	SaveManager.dir = "user://test_saves_sweep"
	# Scene utama sungguhan: bingkai potret dengan taplak di sisinya (GDD idle 12.0).
	shell = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(shell)
	game = shell.game
	await _frames(2)
	game.skip_splash_for_tests()
	await _frames(4)
	var was_scale: int = SettingsManager.get_int("text_scale")
	for r: Vector2i in _res:
		if not _screens.is_empty():
			break
		await _resize(r)
		for sc: int in _scales:
			SettingsManager.set_value("text_scale", sc)
			await _frames(3)
			for id: StringName in MENU_SCREENS:
				await _visit(id, {}, r, sc)
	await game.start_new_game(&"profile_3", "female", "Sweep Bakery")
	await _frames(20)
	PauseManager.lifecycle_enabled = false
	PauseManager.clear_all()
	var sim: SimulationRoot = game.sim
	sim.tutorial.skip()
	while sim.world.location.tier < 3:
		sim.debug_add_kr(SimulationRoot.location_cost(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	sim.debug_set_time(10.0 * 3600.0)
	game.playing = true
	for r2: Vector2i in _res:
		await _resize(r2)
		for sc2: int in _scales:
			SettingsManager.set_value("text_scale", sc2)
			game.modals.close_all()
			await _frames(4)
			_check(game.hud, "hud", r2, sc2)
			await _shot("hud", r2, sc2)
			for id2: StringName in OPEN_SCREENS:
				if game.modals.has_screen(id2) and (_screens.is_empty() or _screens.has(id2)):
					await _visit(id2, _params_for(id2), r2, sc2)
	SettingsManager.set_value("text_scale", was_scale)
	print("SWEEP done, %d issues" % _issues)
	game.modals.close_all()
	game.playing = true
	game.return_to_menu()
	await _frames(2)
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	get_tree().quit(0)


func _resize(r: Vector2i) -> void:
	get_window().size = r
	await _frames(6)
	print("SWEEP window %s -> frame %s, logical %s" % [r, shell.frame, shell.viewport.size_2d_override])


func _visit(id: StringName, params: Dictionary, r: Vector2i, sc: int) -> void:
	game.modals.close_all()
	await _frames(1)
	var s: UIScreen = game.modals.open(id, params)
	await _frames(4)
	var label: String = String(id) + (("_tab%d" % int(params["tab"])) if params.has("tab") else "")
	if s != null:
		_check(s, label, r, sc)
	await _shot(label, r, sc)
	# Halaman kedua cutscene: papan nama cabang baru.
	if s is FranchiseCutscene:
		(s as FranchiseCutscene)._advance()
		await _frames(3)
		_check(s, label + "_p2", r, sc)
		await _shot(label + "_p2", r, sc)
	game.modals.close_all()
	game.sim.offline.pending = {}
	await _frames(1)


## Isi contoh untuk layar yang butuh data: penghasilan offline yang menunggu
## Collect, dan bintang cutscene Waralaba.
func _params_for(id: StringName) -> Dictionary:
	match id:
		&"welcome_back":
			game.sim.offline.pending = {"amount": 123456.0, "seconds": 7200.0, "away": 3.0 * 3600.0 + 25.0 * 60.0}
		&"franchise_cutscene":
			return {"stars": 12, "number": 3}
		&"tutorial":
			return {"key": "onb_welcome"}
	return {}


func _inside_clip(c: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		if p is Control and (p as Control).clip_contents:
			return true
		p = p.get_parent()
	return false


## Setiap kontrol yang tampak harus berada di dalam bingkai potret (isi
## SubViewport); tidak ada yang boleh keluar ke area taplak (GDD idle 12.0.7).
func _check(root: Node, label: String, r: Vector2i, sc: int) -> void:
	var vis: Rect2 = game.get_viewport().get_visible_rect()
	var found: int = 0
	for n: Node in root.find_children("*", "Control", true, false):
		var c: Control = n
		if not c.is_visible_in_tree() or _inside_clip(c):
			continue
		var g: Rect2 = c.get_global_rect()
		if g.size.x < 1.0 or g.size.y < 1.0:
			continue
		if g.position.x < vis.position.x - 1.0 or g.position.y < vis.position.y - 1.0 or g.end.x > vis.end.x + 1.0 or g.end.y > vis.end.y + 1.0:
			found += 1
			_issues += 1
			if found <= 4:
				print("SWEEP OFF %dx%d @%d%% %s: %s %s %s" % [r.x, r.y, sc, label, c.get_class(), root.get_path_to(c), g])
	if found > 4:
		print("SWEEP OFF %dx%d @%d%% %s: ... %d more" % [r.x, r.y, sc, label, found - 4])


func _shot(label: String, r: Vector2i, sc: int) -> void:
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.convert(Image.FORMAT_RGB8)
	img.resize(img.get_width() / 2, img.get_height() / 2, Image.INTERPOLATE_BILINEAR)
	img.save_png(_out.path_join("%dx%d_%d_%s.png" % [r.x, r.y, sc, label]))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
