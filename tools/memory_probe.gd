extends Node
## Alat ukur memori jangka panjang (GDD idle 20 no. 67): game_root.tscn dijalankan
## seperti pemain (game baru, audio terbuka), lalu toko dibiarkan berjalan dengan
## waktu dipercepat. Setiap `--every` detik dicetak memori statis, jumlah objek,
## resource, node, node yatim, memori video, dan ukuran cache statis; di akhir
## dicetak node yang jumlahnya bertambah sejak pengukuran pertama.
## godot --path . res://tools/memory_probe.tscn -- --minutes=10 --scale=8 [--manage] [--every=20]
## `--manage` membeli upgrade seperti SimBot (toko tumbuh dan dibangun ulang).
## `--ui` membuka dan menutup layar utama bergantian seperti pemain yang sibuk
## (Upgrades, Menu, Staff, Shop, Decor, Goals, Settings, ...), satu per detik.
## Save ditulis ke user://probe_saves, bukan slot pemain.

const PROBE_DIR: String = "user://probe_saves"

var _minutes: float = 10.0
var _scale: float = 8.0
var _every: float = 20.0
var _manage: bool = false
var _ui: bool = false
## Layar yang dibuka bergantian dengan `--ui`.
const UI_SCREENS: Array[StringName] = [
	&"upgrades", &"menu", &"staff", &"shop", &"decoration", &"goals", &"calendar",
	&"stats", &"settings", &"help", &"town_map", &"franchise", &"pause",
]
var _ui_open: UIScreen = null
var _ui_index: int = 0
var _ui_frames: int = 0
var _ui_count: int = 0


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			_minutes = float(a.get_slice("=", 1))
		elif a.begins_with("--scale="):
			_scale = float(a.get_slice("=", 1))
		elif a.begins_with("--every="):
			_every = float(a.get_slice("=", 1))
		elif a == "--manage":
			_manage = true
		elif a == "--ui":
			_ui = true
	SaveManager.dir = PROBE_DIR
	Monetization.use_test_file("memory_probe")
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	AudioManager.unlock()
	game.skip_splash_for_tests()
	game.open_new_game()
	await game.start_new_game(SaveManager.SAVE_ID, "female", "Probe Bakery")
	while not game.playing:
		await get_tree().process_frame
	var bot: SimBot = (load("res://tests/sim_bot.gd") as GDScript).new(game.sim)
	bot.manage = _manage
	bot.think_interval = 1
	print("MEMORY_PROBE playing; %.0f real minutes at x%.0f, sample every %.0f s, manage=%s ui=%s" % [_minutes, _scale, _every, _manage, _ui])
	Engine.time_scale = _scale
	var t0: int = Time.get_ticks_msec()
	var next_sample: int = 0
	var first_hist: Dictionary = {}
	var frames: int = 0
	var worst: float = 0.0
	while Time.get_ticks_msec() - t0 < int(_minutes * 60000.0):
		await get_tree().process_frame
		frames += 1
		worst = maxf(worst, get_process_delta_time() / maxf(Engine.time_scale, 0.001))
		bot.think()
		var top: UIScreen = game.modals.top()
		if top != null and top.overlay and top != _ui_open:
			# Popup sistem (Welcome Back, tip) menutup diri seperti pemain.
			top.close()
		if _ui:
			_step_ui(game)
		var el: int = Time.get_ticks_msec() - t0
		# Ukur hanya saat tidak ada layar latihan yang terbuka, supaya angka
		# dari waktu ke waktu sebanding.
		if el < next_sample or _ui_open != null:
			continue
		next_sample += int(_every * 1000.0)
		_sample(game, el, frames, worst)
		if _ui:
			print("MEMORY_PROBE   screens opened %d" % _ui_count)
		frames = 0
		worst = 0.0
		if first_hist.is_empty() and el >= 30000:
			first_hist = _histogram()
	Engine.time_scale = 1.0
	if _ui_open != null and is_instance_valid(_ui_open):
		_ui_open.close()
	for i in 30:
		await get_tree().process_frame
	_sample(game, Time.get_ticks_msec() - t0, frames, worst)
	_print_growth(first_hist, _histogram())
	game.end_session()
	game.queue_free()
	await get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	print("MEMORY_PROBE done")
	get_tree().quit(0)


## Satu layar terbuka kira-kira setengah detik, lalu ditutup; satu frame
## kemudian layar berikutnya dibuka.
func _step_ui(game: GameRoot) -> void:
	_ui_frames += 1
	if _ui_open != null:
		if _ui_frames < 30:
			return
		if is_instance_valid(_ui_open):
			_ui_open.close()
		_ui_open = null
		_ui_frames = 0
		return
	if _ui_frames < 2:
		return
	_ui_open = game.modals.open(UI_SCREENS[_ui_index % UI_SCREENS.size()])
	_ui_index += 1
	_ui_count += 1
	_ui_frames = 0


func _sample(game: GameRoot, el: int, frames: int, worst: float) -> void:
	var mb: float = 1024.0 * 1024.0
	var gt: String = "day %d %s" % [game.sim.time.day, Tx.clock(game.sim.time.time_seconds)] if game.sim != null else "-"
	print("MEMORY_PROBE t=%4ds %s tier %d | static %.1f MB (max %.1f) | objects %d res %d nodes %d orphan %d | video %.1f MB tex %.1f buf %.1f | draws %d | frames %d worst %.0f ms" % [
		el / 1000, gt, game.sim.world.location.tier if game.sim != null else 0,
		Performance.get_monitor(Performance.MEMORY_STATIC) / mb,
		Performance.get_monitor(Performance.MEMORY_STATIC_MAX) / mb,
		Performance.get_monitor(Performance.OBJECT_COUNT),
		Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT),
		Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),
		Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / mb,
		Performance.get_monitor(Performance.RENDER_TEXTURE_MEM_USED) / mb,
		Performance.get_monitor(Performance.RENDER_BUFFER_MEM_USED) / mb,
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		frames, worst * 1000.0])
	print("MEMORY_PROBE   caches: %s" % _caches(game))


## Ukuran cache statis yang bisa tumbuh selama permainan.
func _caches(game: GameRoot) -> String:
	var out: Array[String] = []
	var list: Dictionary = {
		"MaterialKeep": MaterialKeep._kept, "UIFactory.font": ProceduralUIFactory._font_cache,
		"UIFactory.switch": ProceduralUIFactory._switch_cache, "BreadArt": BreadArt._cache,
		"DecorSlots": DecorSlots._cache, "MeshFactory.tint": ProceduralMeshFactory._tint_mats,
		"MeshFactory.boxes": ProceduralMeshFactory._shared_boxes, "MeshBuilder.mat": MeshBuilder._materials,
		"DecorFactory": DecorFactory._proto, "MeshBake.mat": MeshBake._materials,
		"EquipmentFactory": EquipmentFactory._proto_cache, "BreadFactory.mat": BreadFactory._material_cache,
		"BreadFactory.proto": BreadFactory._proto_cache, "BreadFactory.slot": BreadFactory._slot_cache,
		"AudioManager.streams": AudioManager._streams,
	}
	for k: String in list:
		out.append("%s %d" % [k, (list[k] as Dictionary).size()])
	if game.world != null and game.world.street_life != null:
		out.append("StreetLife %d" % game.world.street_life._cache.size())
	return ", ".join(out)


func _histogram() -> Dictionary:
	var h: Dictionary = {}
	_count(get_tree().root, h)
	return h


func _count(n: Node, h: Dictionary) -> void:
	var key: String = n.get_class()
	var s: Script = n.get_script()
	if s != null and s.get_global_name() != &"":
		key = String(s.get_global_name())
	h[key] = int(h.get(key, 0)) + 1
	for c: Node in n.get_children(true):
		_count(c, h)


func _print_growth(a: Dictionary, b: Dictionary) -> void:
	var rows: Array = []
	for k: String in b:
		var d: int = int(b[k]) - int(a.get(k, 0))
		if d != 0:
			rows.append([d, k, int(a.get(k, 0)), int(b[k])])
	for k2: String in a:
		if not b.has(k2):
			rows.append([-int(a[k2]), k2, int(a[k2]), 0])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0])
	print("MEMORY_PROBE node growth since 30 s (class: before -> after):")
	for r: Array in rows.slice(0, 25):
		print("MEMORY_PROBE   %+d %s: %d -> %d" % [r[0], r[1], r[2], r[3]])
