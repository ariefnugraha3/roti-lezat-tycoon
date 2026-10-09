extends Node
## Sapuan resolusi dan skala teks GDD 110: membuka layar-layar utama (menu dan
## dalam game, saat buka dan after-hours) di setiap ukuran jendela 16:9, 16:10,
## 18:9, 19,5:9, 20:9 dan 4:3, pada skala teks 100/125/150%, memotretnya, dan
## mencetak "SWEEP OFF" untuk setiap Control yang tampak tetapi keluar dari layar
## (di luar ScrollContainer). Save memakai folder uji sendiri. Jalankan dengan
## jendela (perlu renderer), lalu baca baris "SWEEP done, N issues":
##   godot --path . --resolution 1280x720 res://tools/ui_resolution_sweep.tscn
## Folder potret: env LINEUP_OUT, atau user://lineup bila tidak diisi.

const RES: Array[Vector2i] = [Vector2i(1280, 720), Vector2i(1920, 1080), Vector2i(1280, 800), Vector2i(1440, 720),
	Vector2i(1560, 720), Vector2i(1600, 720), Vector2i(1024, 768)]
const SCALES: Array[int] = [100, 125, 150]
const MENU_SCREENS: Array[StringName] = [&"main_menu", &"settings", &"credits", &"help", &"profiles", &"new_game"]
const OPEN_SCREENS: Array = [[&"recipe_book", {}], [&"market", {"tab": 0}], [&"market", {"tab": 1}], [&"market", {"tab": 2}],
	[&"staff", {}], [&"marketing", {}], [&"rotifood", {}], [&"pause", {}], [&"stats", {}], [&"settings", {}]]

var game: GameRoot = null
var _out: String = ""
var _issues: int = 0


func _ready() -> void:
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(_out)
	PauseManager.lifecycle_enabled = false
	# Folder save uji sendiri: jangan pernah menyentuh save pemain.
	SaveManager.dir = "user://test_saves_sweep"
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(2)
	game.skip_splash_for_tests()
	await _frames(4)
	var was_scale: int = SettingsManager.get_int("text_scale")
	for r: Vector2i in RES:
		await _resize(r)
		for sc: int in SCALES:
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
		sim.time.set_phase(TimeManager.AFTER_HOURS)
		sim.debug_add_kr(sim.next_location().upgrade_cost_kr)
		if sim.upgrade_location() != "":
			break
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	sim.continue_to_next_day()
	sim.debug_set_time(10.0 * 3600.0)
	game.playing = true
	for pass_i in 2:
		if pass_i == 1:
			# After-hours: Daily Summary, Market yang bisa dibeli, tombol Continue.
			game.modals.close_all()
			sim.close_day()
			sim.enter_after_hours()
			await _frames(4)
			game.modals.close_all()
		for r2: Vector2i in RES:
			await _resize(r2)
			for sc2: int in SCALES:
				SettingsManager.set_value("text_scale", sc2)
				game.modals.close_all()
				await _frames(4)
				_check(game.hud, "hud_%s" % ("open" if pass_i == 0 else "closed"), r2, sc2)
				await _shot("hud_%s" % ("open" if pass_i == 0 else "closed"), r2, sc2)
				for e: Array in OPEN_SCREENS:
					await _visit(e[0], e[1], r2, sc2)
				if pass_i == 1:
					await _visit(&"daily_summary", {"report": sim.reports.last_report}, r2, sc2)
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
	print("SWEEP window %s -> visible %s" % [r, get_viewport().get_visible_rect().size])


func _visit(id: StringName, params: Dictionary, r: Vector2i, sc: int) -> void:
	game.modals.close_all()
	await _frames(1)
	var s: UIScreen = game.modals.open(id, params)
	await _frames(4)
	var label: String = String(id) + (("_tab%d" % int(params["tab"])) if params.has("tab") else "")
	if s != null:
		_check(s, label, r, sc)
	await _shot(label, r, sc)
	game.modals.close_all()
	await _frames(1)


func _inside_clip(c: Control) -> bool:
	var p: Node = c.get_parent()
	while p != null:
		if p is ScrollContainer:
			return true
		if p is Control and (p as Control).clip_contents:
			return true
		p = p.get_parent()
	return false


func _check(root: Node, label: String, r: Vector2i, sc: int) -> void:
	var vis: Rect2 = get_viewport().get_visible_rect()
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
