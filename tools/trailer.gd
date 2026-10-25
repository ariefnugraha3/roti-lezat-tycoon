extends Node
## Trailer video: satu permainan sungguhan (GameRoot + SimBot) disutradarai adegan
## demi adegan, dari dapur garasi Tier 1 sampai alun-alun Tier 5, dengan kamera
## sinematik dan caption bergaya UI game (GDD 7, 130.6). Hanya tampilan: save
## memakai folder uji sendiri dan pengaturan pemain hanya diubah di memori.
##
## Movie Maker memberi timestep tetap dan merekam suara. Jendelanya dibatasi
## ukuran layar, jadi frame 1920x1080 ditangkap sendiri dari viewport menjadi PNG
## di env TRAILER_OUT. Baris TRAILER_REC memberi frame Movie Maker tempat rekaman
## dimulai, supaya suaranya bisa dipotong pas. Semua langkahnya (render, potong,
## encode MP4) dijalankan tools/render_trailer.sh. Manual, dengan jendela:
##   godot --path . --write-movie <dir>/audio.avi --fixed-fps 30 res://tools/trailer.tscn
## Pratinjau cepat (satu still per adegan, tanpa suara, tanpa Movie Maker):
##   TRAILER_PREVIEW=1 godot --path . --fixed-fps 30 res://tools/trailer.tscn

const OUT_SIZE: Vector2i = Vector2i(1920, 1080)
const SEED: int = 20261014
const PROFILE: StringName = &"profile_1"
const SAVE_DIR: String = "user://test_saves_trailer"
const BAKERY: String = "Roti Lezat"
const TAGLINE: String = "Bake. Sell. Grow."
const PLATFORMS: String = "Play on Web & Android"
## PNG yang boleh menunggu ditulis di thread lain sebelum frame berikutnya ditahan.
const MAX_SAVE_TASKS: int = 8
## Roti etalase tier tinggi, berselang-seling supaya raknya berwarna-warni.
const SHOWCASE: Array[StringName] = [&"recipe_classic_croissant", &"recipe_chocolate_bread",
	&"recipe_strawberry_donut", &"recipe_cinnamon_roll", &"recipe_matcha_brioche", &"recipe_classic_baguette",
	&"recipe_sugar_donut", &"recipe_pain_au_chocolat", &"recipe_milk_pullapart", &"recipe_basque_cheese_bun",
	&"recipe_danish_cheese", &"recipe_whole_wheat_sourdough", &"recipe_sweet_cheese_bread",
	&"recipe_luxury_almond_croissant", &"recipe_matcha_mille_crepes", &"recipe_golden_artisan",
	&"recipe_sausage_roll", &"recipe_plain_loaf"]
const BUYERS: Array[StringName] = [&"customer_generic", &"customer_office_worker", &"customer_school_child",
	&"customer_bulk_buyer", &"customer_generic", &"customer_indecisive"]


## Node pembantu: memanggil `fn` di _process pada urutan process_priority-nya.
class Hook extends Node:
	var fn: Callable

	func _process(delta: float) -> void:
		fn.call(delta)


var game: GameRoot = null
var sim: SimulationRoot = null
var world: WorldView = null
var bot: SimBot = null
var _out: String = ""
var _preview: bool = false
var _recording: bool = false
var _frame: int = 0
var _tasks: Array[int] = []
## Nama still yang diminta mode pratinjau untuk frame berikutnya.
var _still: String = ""
var _shot_no: int = 0
var _cam_on: bool = false
var _cam_focus: Vector3 = Vector3.ZERO
var _cam_size: float = 6.6
var _ui: Control = null
var _caption_node: Control = null
var _chip_node: Control = null
var _next_job: int = -1000
## Langkah seret Decoration Mode yang sudah dijalankan (-1 = sudah ditaruh).
var _decor_step: int = 0
## true = potongan dilewati tanpa frame (TRAILER_FROM).
var _skipping: bool = false


func _ready() -> void:
	_preview = OS.get_environment("TRAILER_PREVIEW") == "1"
	_out = OS.get_environment("TRAILER_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://trailer")
	DirAccess.make_dir_recursive_absolute(_out)
	get_window().size = OUT_SIZE
	get_viewport().msaa_3d = Viewport.MSAA_4X
	_apply_settings()
	PauseManager.lifecycle_enabled = false
	SaveManager.dir = SAVE_DIR
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await _frames(2)
	game.skip_splash_for_tests()
	AudioManager.unlock()
	await _start_game()
	_build_overlay()
	var late := Hook.new()
	late.name = "CameraLate"
	late.process_priority = 1000
	late.fn = _cam_late
	add_child(late)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	await _play()
	await _frames(1)
	_recording = false
	for id: int in _tasks:
		WorkerThreadPool.wait_for_task_completion(id)
	_tasks.clear()
	print("TRAILER_DONE frames=%d process_frame=%d" % [_frame, Engine.get_process_frames()])
	await _cleanup()
	get_tree().quit(0)


## Pengaturan khusus rekaman, hanya di memori (tidak pernah disimpan).
func _apply_settings() -> void:
	var v: Dictionary = SettingsManager.DEFAULTS.duplicate(true)
	v["quality"] = "quality_high"
	v["mute_when_unfocused"] = false
	v["fps_cap"] = 0
	v["tutorial_hints"] = false
	v["music_volume"] = 100
	v["sfx_volume"] = 70
	v["ui_volume"] = 60
	v["ambient_volume"] = 55
	if _preview:
		v["master_volume"] = 0
	SettingsManager.values = v
	SettingsManager.apply_all()
	SettingsManager.settings_changed.emit("")
	get_window().size = OUT_SIZE


## Profil baru dengan seed tetap (GameRoot.start_new_game memakai jam), lalu masuk
## gameplay lewat jalur loading yang sama. Permintaan modal dari simulasi diputus:
## trailer membuka layarnya sendiri.
func _start_game() -> void:
	game._teardown()
	sim = SimulationRoot.new()
	game.sim = sim
	game.add_child(sim)
	sim.start_new_game(PROFILE, BAKERY, "female", SEED)
	await game._enter_gameplay(PROFILE)
	world = game.world
	game._disconnect_bus()
	PauseManager.lifecycle_enabled = false
	PauseManager.clear_all()
	game.modals.close_all()
	sim.tutorial.skip()
	world.highlight(&"", -1)
	game.hud.show_tutorial_hint("", &"", -1)
	game.hud.visible = false
	# Musik diatur adegan, bukan fase toko.
	if EventBus.music_state_changed.is_connected(AudioManager.set_music_state):
		EventBus.music_state_changed.disconnect(AudioManager.set_music_state)
	for id: StringName in [&"shop_music_day", &"shop_music_busy_layer"]:
		AudioManager.stream_for(id)
	for m: AudioStreamPlayer in AudioManager._music:
		m.stop()
		m.volume_db = -80.0
	AudioManager._music_playing = &""
	AudioManager.music_state = &""
	bot = SimBot.new(sim)


func _cleanup() -> void:
	if not EventBus.music_state_changed.is_connected(AudioManager.set_music_state):
		EventBus.music_state_changed.connect(AudioManager.set_music_state)
	game.modals.close_all()
	game._teardown()
	for m: AudioStreamPlayer in AudioManager._music:
		m.stop()
	for p: AudioStreamPlayer in AudioManager._sfx:
		p.stop()
	AudioManager._busy_layer.stop()
	await _frames(2)
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	SettingsManager.load_settings()
	SettingsManager.apply_all()


# ===========================================================================
# STORYBOARD
# ===========================================================================

func _play() -> void:
	var segs: Array[Callable] = [_seg_title, _seg_bake, _seg_open, _seg_serve, _seg_rotifood, _seg_recipes,
		_seg_staff, _seg_decor, _seg_grow, _seg_life, _seg_end]
	var from: String = OS.get_environment("TRAILER_FROM")
	for seg: Callable in segs:
		# Iterasi cepat: segmen sebelum TRAILER_FROM tetap menyiapkan state-nya,
		# hanya potongannya tidak diputar.
		if from != "" and seg.get_method() == StringName("_seg_" + from):
			from = ""
		_skipping = from != ""
		await seg.call()
	_skipping = false


## Kartu judul di atas fajar Tier 1, lalu memudar ke kampung yang baru bangun.
func _seg_title() -> void:
	_mute()
	_run(3.0)
	_unmute()
	var c: Vector3 = _floor_center()
	var card: Control = _card(false)
	if _skipping:
		card.queue_free()
	_start_recording()
	AudioManager.set_music_state(&"STORE_OPEN_CALM")
	var tw: Tween = card.create_tween()
	tw.tween_interval(2.6)
	tw.tween_property(card, "modulate:a", 0.0, 0.9)
	tw.tween_callback(card.queue_free)
	await _shot("dawn", 6.2, _path(c + Vector3(-0.7, 0.0, -1.3), c + Vector3(-0.2, 0.0, -0.6), 9.4, 7.8))


## Dapur: adonan ke oven, roti matang diangkat, lalu dipajang di rak.
func _seg_bake() -> void:
	_caption("Bake fresh bread from scratch", "bread", 8.0)
	_mute()
	_run_until(func() -> bool: return _carrying(ProductionJob.CARRIED_TO_OVEN))
	_unmute()
	await _shot("dough", 2.6, _follow_player(3.0), 4.0)
	_mute()
	_run_until(func() -> bool: return _job_at(ProductionJob.BAKE_DONE_WAITING_PICKUP) != null)
	_unmute()
	var j: ProductionJob = _job_at(ProductionJob.BAKE_DONE_WAITING_PICKUP)
	var oven: Vector3 = _ground(world.top_of_iid(j.oven_id)) if j != null else _player_ground()
	await _shot("oven", 2.4, _path(oven + Vector3(-0.2, 0.0, -0.1), oven + Vector3(0.0, 0.0, 0.05), 2.9, 2.6))
	_mute()
	_run_until(func() -> bool: return _carrying(ProductionJob.CARRIED_TO_DISPLAY))
	_unmute()
	await _shot("shelf", 3.0, _follow_player(3.3), 4.0)


## 08:00: pembeli datang dari ujung trotoar (GDD 20.1).
func _seg_open() -> void:
	_mute()
	_run_until(func() -> bool: return sim.time.time_seconds >= 8.0 * 3600.0 + 420.0)
	_spawn(2, 4.0)
	_street(6.0)
	_unmute()
	game.hud.visible = true
	AudioManager.set_music_state(&"STORE_OPEN_BUSY")
	_caption("Open your doors at 8 AM", "shop", 4.9, true)
	var c: Vector3 = _floor_center()
	await _shot("open", 5.0, _path(c + Vector3(-0.8, 0.0, -1.4), c + Vector3(-0.4, 0.0, -0.8), 6.6, 5.8))
	game.hud.visible = false


## Close-up meja kasir saat membungkus (GDD 21.4).
func _seg_serve() -> void:
	var lane: QueueLane = sim.queue.main_lane()
	_mute()
	_run_until(func() -> bool: return sim.cashier.packing_progress(lane.id) >= 0.02)
	_unmute()
	var counter: Node3D = world.counter_of(lane)
	var p: Vector3 = _ground(_center_of(counter) + Vector3(0.0, 0.35, 0.0)) if counter != null else _player_ground()
	_caption("Serve every customer", "bag", 3.5)
	await _shot("serve", 3.6, _path(p + Vector3(-0.15, 0.0, -0.05), p + Vector3(0.05, 0.0, 0.05), 2.4, 2.1))


## Pesanan RotiFood berdering di HUD (GDD 7, 22).
func _seg_rotifood() -> void:
	bot.pack_orders = false
	_mute()
	sim.debug_spawn_order()
	_run(3.0)
	_unmute()
	game.hud.visible = true
	_caption("Take RotiFood delivery orders", "scooter", 4.0, true)
	var c: Vector3 = _floor_center()
	await _shot("rotifood", 4.1, _path(c + Vector3(-0.2, 0.0, -0.4), c + Vector3(0.1, 0.0, -0.2), 6.0, 5.6))
	bot.pack_orders = true
	game.hud.visible = false


## Buku Resep dengan gambar roti (GDD 7).
func _seg_recipes() -> void:
	var pick: StringName = &"recipe_sugar_donut"
	var r: RecipeDefinition = DataRegistry.recipe(pick)
	var items: Dictionary = {}
	for ing: StringName in r.ingredients.keys():
		items[ing] = int(r.ingredients[ing]) * 3
	sim.inventory.add_items(items)
	# Baris harga tampil seperti hari biasa (harga boleh diatur mulai Hari 4).
	var day: int = sim.time.day
	sim.time.day = maxi(day, 4)
	var rb: UIScreen = game.modals.open(&"recipe_book")
	var sc: ScrollContainer = null
	if rb != null:
		rb.set("_selected", pick)
		rb.call("_render_list")
		rb.call("_render_detail")
		var found: Array[Node] = rb.find_children("*", "ScrollContainer", true, false)
		if not found.is_empty():
			sc = found[0] as ScrollContainer
		_shrink_popup(rb, 0.8)
	sim.time.day = day
	_caption("Master %d recipes" % DataRegistry.recipes().size(), "chef", 3.3)
	await _shot("recipes", 3.4, _hold_cam(), 0.0, _scroll_list.bind(sc))
	game.modals.close_all()


## Perkecil popup layar `s` di sekitar tengah atas layar; tirai gelapnya tetap
## menutupi seluruh layar.
func _shrink_popup(s: UIScreen, k: float) -> void:
	s.pivot_offset = Vector2(640.0, 300.0)
	s.scale = Vector2(k, k)
	for n: Node in s.find_children("Scrim", "ColorRect", true, false):
		var scrim: ColorRect = n
		scrim.offset_left = -2000.0
		scrim.offset_top = -2000.0
		scrim.offset_right = 2000.0
		scrim.offset_bottom = 2000.0


func _scroll_list(k: float, sc: ScrollContainer) -> void:
	if sc == null or not is_instance_valid(sc):
		return
	var bar: VScrollBar = sc.get_v_scroll_bar()
	sc.scroll_vertical = int(smoothstep(0.1, 0.9, k) * maxf(0.0, bar.max_value - bar.page) * 0.55)


## Hari 2: kasir dan koki pertama bekerja (GDD 3, 21, 23).
func _seg_staff() -> void:
	_mute()
	_close_now()
	_hire_all()
	_buy_decor()
	_place_decor()
	_continue_day()
	_run_until(func() -> bool: return sim.time.time_seconds >= 9.5 * 3600.0)
	_spawn(2, 6.0)
	_street(6.0)
	_unmute()
	var cashier: Vector3 = _staff_ground(&"cashier")
	var baker: Vector3 = _staff_ground(&"baker")
	_caption("Hire cashiers and bakers", "people", 4.4)
	await _shot("staff", 4.5, _path(cashier, cashier.lerp(baker, 0.7), 3.8, 4.2))


## Decoration Mode: pot tanaman diangkat dan digeser ubin demi ubin (GDD 72.2).
func _seg_decor() -> void:
	var uid: int = _decor_uid(&"decor_potted_plant")
	var ds: UIScreen = game.modals.open(&"decoration")
	var path: Array[Vector2i] = []
	if ds != null and uid >= 0:
		ds.call("_hold_decor", uid)
		path = _decor_walk(uid, 4)
	var c: Vector3 = _floor_center()
	_caption("Decorate your shop your way", "frame", 4.4, true)
	_decor_step = 0
	await _shot("decor", 4.6, _path(c + Vector3(0.2, 0.0, 0.0), c + Vector3(0.0, 0.0, -0.2), 5.4, 5.0), 0.0,
		_drag_decor.bind(ds, path))
	game.modals.close_all()


## Langkah seret Decoration Mode untuk k = 0..1: satu ubin per langkah, lalu Place.
func _drag_decor(k: float, ds: UIScreen, path: Array[Vector2i]) -> void:
	if ds == null or not is_instance_valid(ds) or path.size() < 2:
		return
	var want: int = clampi(int(k * float(path.size() + 1)), 0, path.size() - 1)
	if _decor_step >= 0 and want > _decor_step:
		_decor_step = want
		ds.set("_cand_cell", path[want])
		ds.call("_update_candidate")
	elif _decor_step >= 0 and k > 0.86:
		_decor_step = -1
		ds.call("_place")


## Naik tier: ruko, toko roti mandiri, flagship, landmark (GDD 6, 32.3, 32.5).
func _seg_grow() -> void:
	var lines: Array[String] = ["Grow from a home garage...", "", "...into a city landmark", ""]
	var hours: Array[float] = [9.2, 10.5, 12.5, 15.2]
	var sizes: Array[Vector2] = [Vector2(6.4, 7.0), Vector2(6.6, 7.2), Vector2(8.6, 9.4), Vector2(10.0, 10.9)]
	for i in 4:
		var tier: int = i + 2
		_mute()
		_upgrade()
		if tier == 5:
			# Hari libur (GDD 26.6): umbul-umbul dan bunting di alun-alun.
			sim.time.day = 11
		_continue_day()
		_open_at(hours[i])
		_unmute()
		if lines[i] != "":
			_caption(lines[i], "star", 6.0)
		_tier_chip(tier, 3.1)
		var c: Vector3 = _floor_center()
		var a: Vector3 = c + Vector3(-0.6, 0.0, -1.0)
		await _shot("tier%d" % tier, 3.2, _path(a, a + Vector3(0.3, 0.0, 0.4), sizes[i].x, sizes[i].y))


## Kejutan kecil, hari libur, dan hujan di alun-alun Tier 5 (GDD 31.9, 32.8, 32.10).
func _seg_life() -> void:
	_caption("Rain, holidays and little surprises", "party", 9.2)
	for kind: StringName in [&"mascot", &"cat"]:
		_mute()
		_run(2.0)
		if not world.surprises.start(kind):
			push_warning("trailer: surprise %s did not start" % kind)
		_surprise_show(2.0 if kind == &"mascot" else 0.6)
		_unmute()
		var p: Vector3 = _cast_ground()
		await _shot(String(kind), 3.0, _follow_cast(p, 3.6), 3.0)
	_mute()
	world.surprises.abort()
	sim.debug_force_weather(&"weather_rain")
	_spawn(3, 6.0)
	_street(8.0)
	_unmute()
	var c: Vector3 = _floor_center()
	await _shot("rain", 3.2, _path(c + Vector3(-2.6, 0.0, -4.6), c + Vector3(-2.2, 0.0, -4.0), 6.4, 6.0))


## Senja di alun-alun, lalu kartu penutup.
func _seg_end() -> void:
	_mute()
	sim.debug_force_weather(&"weather_sunny")
	sim.debug_set_time(17.6 * 3600.0)
	_run(4.0)
	_street(8.0)
	_unmute()
	var c: Vector3 = _floor_center()
	var card: Control = _card(true)
	card.modulate.a = 0.0
	var tw: Tween = card.create_tween()
	tw.tween_interval(1.8)
	tw.tween_property(card, "modulate:a", 1.0, 0.8)
	await _shot("dusk", 6.4, _path(c + Vector3(-0.8, 0.0, -1.6), c + Vector3(-1.2, 0.0, -2.2), 9.6, 11.2))


# ===========================================================================
# SIMULASI (sinkron, di antara dua frame: tidak terekam)
# ===========================================================================

## Tick sinkron tidak boleh menumpuk bunyi di satu frame potongan berikutnya, jadi
## suara dikunci selama persiapan potongan.
func _mute() -> void:
	AudioManager.unlocked = false


func _unmute() -> void:
	AudioManager.unlocked = true
	AudioManager.set_ambience(WorldView.ambience_for(sim.weather.is_rain(), sim.world.location.tier))


func _run(sim_seconds: float) -> void:
	var t: float = 0.0
	while t < sim_seconds and sim.is_running():
		bot.think()
		sim.step(sim.tick_seconds)
		t += sim.tick_seconds


func _run_until(cond: Callable, max_sim_seconds: float = 2400.0) -> bool:
	var t: float = 0.0
	while t < max_sim_seconds and sim.is_running():
		bot.think()
		sim.step(sim.tick_seconds)
		t += sim.tick_seconds
		if cond.call():
			return true
	push_warning("trailer: condition not reached")
	return false


## Lalu lintas jalan sudah berjalan saat potongan dimulai (StreetLife).
func _street(seconds: float) -> void:
	var sl: StreetLife = world.street_life
	while not sl._warm.is_empty():
		sl._work_deadline = Time.get_ticks_usec() + 1000000000
		sl._work_units = 0
		sl._warm_step()
	var t: float = 0.0
	while t < seconds:
		sl.update(1.0 / 30.0)
		t += 1.0 / 30.0


## Adegan kejutan maju sampai pemerannya mulai beraksi di dalam toko (bicara atau
## berpose), lalu `extra` detik lagi.
func _surprise_show(extra: float) -> void:
	var dt: float = 1.0 / 30.0
	var t: float = 0.0
	while t < 90.0 and world.surprises.running() != &"" and not _cast_acting():
		world.surprises.update(dt)
		world.street_life.update(dt)
		t += dt
	t = 0.0
	while t < extra:
		world.surprises.update(dt)
		world.street_life.update(dt)
		t += dt


func _cast_acting() -> bool:
	for m: Dictionary in world.surprises._cast:
		var act: Dictionary = m["act"]
		if not bool(m["gone"]) and str(act.get("do", "")) in ["say", "pose"]:
			return true
	return false


## Pembeli tambahan yang datang berselang-seling dari trotoar.
func _spawn(n: int, gap_sim_seconds: float) -> void:
	for i in n:
		sim.debug_spawn_customer(BUYERS[i % BUYERS.size()])
		_run(gap_sim_seconds)


## Hari berikutnya pukul 05:00, cerah.
func _continue_day() -> void:
	sim.weather.tomorrow = &"weather_sunny"
	sim.continue_to_next_day()


func _close_now() -> void:
	if sim.time.phase == TimeManager.OPEN or sim.time.phase == TimeManager.PREPARATION:
		sim.close_day()
	sim.enter_after_hours()


## Dapur dikosongkan paksa supaya upgrade boleh jalan (GDD 105 no. 11).
func _clear_kitchen() -> void:
	sim.player.cancel_all()
	sim.player.actor.carried = {}
	for a: Variant in sim.staff.actors.values():
		(a as SimActor).carried = {}
	sim.staff.tasks.clear()
	for e: EquipmentInstance in sim.equipment.all_sorted():
		e.job_id = -1
	sim.production.jobs.clear()


## Upgrade ke tier berikutnya dengan alat tier itu di setiap slot, staf penuh,
## dekorasi yang muat, dan bahan untuk banyak resep.
func _upgrade() -> void:
	_close_now()
	_clear_kitchen()
	var nxt: LocationDefinition = sim.next_location()
	sim.debug_add_kr(nxt.upgrade_cost_kr + 400000.0)
	var r: String = sim.upgrade_location()
	if r != "":
		# Dekorasi lantai lama bisa jatuh di jalur wajib tata letak baru, sehingga
		# Gudang tidak dapat ditempatkan dan upgrade dibatalkan.
		var moved: Array[String] = []
		for o: Dictionary in sim.decoration.owned:
			var t: StringName = sim.decoration.type_of(o)
			if bool(o["placed"]) and (t == &"floor_prop" or t == &"floor_overlay"):
				moved.append("%s@%s" % [o["deco_id"], str(o["cell"])])
				sim.decoration.put_away(int(o["uid"]))
		r = sim.upgrade_location()
		print("TRAILER_NOTE upgrade to %s failed with floor decor placed (%s); after putting it away: %s" % [nxt.id, ", ".join(moved), "ok" if r == "" else r])
	if r != "":
		push_error("trailer: upgrade failed: %s" % r)
	_equip_best()
	_hire_all()
	_place_decor()
	_buy_ingredients()


## Buka toko pada jam `hour` dengan rak penuh roti beraneka, pembeli di dalam,
## dan jalan yang sudah ramai.
func _open_at(hour: float) -> void:
	sim.debug_set_time(hour * 3600.0)
	_stock_displays(0.8)
	_run(6.0)
	_spawn(4, 3.0)
	_run(10.0)
	_street(8.0)
	var store: StringName = sim.world.store_floor()
	world.view_floor_override = store
	if world.camera_rig.active_floor != store:
		world.camera_rig.active_floor = store
		world._apply_floor_visibility()


func _equip_best() -> void:
	var tier: int = sim.world.location.tier
	for cat: StringName in [&"display", &"oven", &"mixer"]:
		var def_id := StringName("%s_t%d" % [cat, tier])
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			if e.tier() < tier:
				sim.equipment.buy_replace(def_id, e.iid)
		for old: EquipmentInstance in sim.equipment.unplaced_list(cat):
			if old.tier() < tier:
				sim.equipment.sell(old.iid)
		while sim.equipment.placed_count(cat) + sim.equipment.unplaced_list(cat).size() < sim.equipment.slot_limit(cat):
			var b: Dictionary = sim.equipment.buy(def_id)
			if not bool(b.get("ok", false)):
				break
		for e2: EquipmentInstance in sim.equipment.unplaced_list(cat):
			if not bot._place(e2.iid):
				sim.equipment.sell(e2.iid)


func _hire_all() -> void:
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
				break
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id)


func _buy_decor() -> void:
	sim.debug_add_kr(20000.0)
	for d: Variant in DataRegistry.decorations():
		var dd: MiscDefinitions.DecorationDefinition = d
		if dd.source == &"shop" and not sim.decoration.owns(dd.id):
			sim.decoration.buy(dd.id)


## Pasang dekorasi yang belum terpasang di slot/ubin sah pertama, dengan urutan
## ubin acak tetap supaya tidak menumpuk di satu sudut.
func _place_decor() -> void:
	var store: StringName = sim.decoration.store_floor()
	var fg: FloorGrid = sim.world.grid(store)
	var cells: Array[Vector2i] = []
	for z in fg.size.y:
		for x in fg.size.x:
			cells.append(Vector2i(x, z))
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED + sim.world.location.tier
	for i in range(cells.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = cells[i]
		cells[i] = cells[j]
		cells[j] = tmp
	for o: Dictionary in sim.decoration.owned:
		if bool(o["placed"]):
			continue
		var uid: int = int(o["uid"])
		var t: StringName = sim.decoration.type_of(o)
		if t == &"wall" or t == &"counter_prop":
			var free: Array[int] = sim.decoration.free_slots(t, uid)
			if not free.is_empty():
				sim.decoration.place(uid, store, Vector2i.ZERO, free[0])
		elif t == &"floor_prop" or t == &"floor_overlay":
			for c: Vector2i in cells:
				if sim.decoration.place(uid, store, c, -1, 0) == &"":
					break


func _buy_ingredients() -> void:
	var items: Dictionary = {}
	for rid: StringName in SHOWCASE:
		var r: RecipeDefinition = DataRegistry.recipe(rid)
		if r == null or not sim.production.owns_equipment_for(r):
			continue
		for ing: StringName in r.ingredients.keys():
			items[ing] = int(items.get(ing, 0)) + int(r.ingredients[ing]) * 4
	var cap: int = sim.supply.max_additional_units()
	var total: int = 0
	for k: Variant in items.keys():
		total += int(items[k])
	if total > cap and total > 0:
		for k2: Variant in items.keys():
			items[k2] = int(floor(float(items[k2]) * float(cap) / float(total)))
	sim.supply.purchase(items)


## Isi rak langsung dengan roti beraneka (tampilan etalase), `fill` dari kapasitas
## tiap petak, supaya koki masih punya ruang memanggang.
func _stock_displays(fill: float) -> void:
	var n: int = mini(SHOWCASE.size(), 6 + sim.world.location.tier * 2)
	var k: int = sim.world.location.tier * 3
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		var def: EquipmentDefinition = e.def()
		var sl: Array = sim.display.slots(e.iid)
		for i in sl.size():
			var rid: StringName = SHOWCASE[k % n]
			k += 1
			var qty: int = maxi(1, int(round(float(def.max_per_slot) * fill)))
			_next_job -= 1
			sim.display.place(e.iid, i, rid, qty, 1.0, sim.time.time_seconds, _next_job)


# ===========================================================================
# KAMERA
# ===========================================================================

## Satu potongan: kamera mengikuti `cam(k)` -> [fokus tanah, ukuran ortho] untuk
## k = 0..1, sementara permainan berjalan biasa. `smooth` > 0 = kamera mengejar
## sasarannya (mengikuti aktor), 0 = jalur pas. `each(k)` dipanggil tiap frame.
func _shot(label: String, seconds: float, cam: Callable, smooth: float = 0.0, each: Callable = Callable()) -> void:
	_shot_no += 1
	if _skipping:
		return
	var t: float = 0.0
	var first: bool = true
	var still_done: bool = false
	print("TRAILER_SHOT %02d %s frame=%d day=%d time=%s" % [_shot_no, label, _frame, sim.time.day, Tx.clock(sim.time.time_seconds)])
	while t < seconds:
		var k: float = clampf(t / seconds, 0.0, 1.0)
		var c: Array = cam.call(k)
		if first or smooth <= 0.0:
			_cam_focus = c[0]
			_cam_size = float(c[1])
		else:
			var a: float = 1.0 - exp(-smooth / 30.0)
			_cam_focus = _cam_focus.lerp(c[0], a)
			_cam_size = lerpf(_cam_size, float(c[1]), a)
		first = false
		_cam_on = true
		_cam_pre()
		if each.is_valid():
			each.call(k)
		if not PauseManager.is_paused() and sim.is_running():
			bot.think()
		if _preview and not still_done and k >= 0.5:
			still_done = true
			_still = "%02d_%s" % [_shot_no, label]
		await get_tree().process_frame
		t += get_process_delta_time()


## Jalur lurus fokus a->b dan ukuran s0->s1 dengan ease lembut.
func _path(a: Vector3, b: Vector3, s0: float, s1: float) -> Callable:
	return func(k: float) -> Array:
		var e: float = smoothstep(0.0, 1.0, k)
		return [a.lerp(b, e), lerpf(s0, s1, e)]


func _hold_cam() -> Callable:
	var f: Vector3 = _cam_focus
	var s: float = _cam_size
	return func(_k: float) -> Array: return [f, s]


func _follow_player(size: float) -> Callable:
	return func(_k: float) -> Array: return [_player_ground(), size]


## Mengikuti pemeran kejutan; bila adegannya sudah selesai, tetap di `fallback`.
func _follow_cast(fallback: Vector3, size: float) -> Callable:
	return func(_k: float) -> Array:
		var nodes: Array[Node3D] = world.surprises.cast_nodes()
		if nodes.is_empty():
			return [fallback, size]
		return [_cast_ground(), size]


## Fokus diletakkan sebelum WorldView menggerakkan kamera: dengan pan bebas yang
## sama dengan sasaran, follow() tidak menggeser apa-apa, jadi gelembung kalimat
## dihitung dengan kamera yang benar.
func _cam_pre() -> void:
	var rig: CameraRig = world.camera_rig
	var fs: Vector2 = Vector2(sim.world.grid(rig.active_floor).size) * GridMath.WORLD_METERS_PER_TILE
	rig.free_pan = true
	rig.pan_offset = Vector3(_cam_focus.x - fs.x * 0.5, 0.0, _cam_focus.z - fs.y * 0.5)
	rig._focus = _cam_focus
	rig._pan_idle = 0.0
	rig._nudge_left = 0.0
	rig.ortho_size = _cam_size


## Setelah semua _process: fokus pas walau di luar batas pan bebas.
func _cam_late(_delta: float) -> void:
	if not _cam_on or world == null or not is_instance_valid(world):
		return
	var rig: CameraRig = world.camera_rig
	rig._focus = _cam_focus
	rig.ortho_size = _cam_size
	rig._apply()


## Titik tanah yang tampil di tempat yang sama dengan titik `p` (kamera ortho).
func _ground(p: Vector3) -> Vector3:
	if not p.is_finite():
		return _floor_center()
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var d: float = p.y / tan(pitch)
	return Vector3(p.x + sin(yaw) * d, 0.0, p.z + cos(yaw) * d)


func _floor_center() -> Vector3:
	var fs: Vector2 = Vector2(sim.world.grid(world.camera_rig.active_floor).size) * GridMath.WORLD_METERS_PER_TILE
	return Vector3(fs.x * 0.5, 0.0, fs.y * 0.5)


func _player_ground() -> Vector3:
	var v: Node3D = world.views.get(sim.player.actor.id) as Node3D
	var p: Vector3 = v.global_position if v != null else Vector3(sim.player.actor.pos.x, 0.0, sim.player.actor.pos.y)
	return _ground(p + Vector3(0.0, 0.55, 0.0))


func _staff_ground(role: StringName) -> Vector3:
	for sid: StringName in sim.staff.employed_ids(role):
		var a: SimActor = sim.staff.actors.get(sid)
		if a != null:
			return _ground(Vector3(a.pos.x, 0.55, a.pos.y))
	return _floor_center()


func _cast_ground() -> Vector3:
	var nodes: Array[Node3D] = world.surprises.cast_nodes()
	if nodes.is_empty():
		return _floor_center()
	var p: Vector3 = Vector3.ZERO
	for n: Node3D in nodes:
		p += n.global_position
	p /= float(nodes.size())
	return _ground(p + Vector3(0.0, 0.4, 0.0))


func _center_of(n: Node3D) -> Vector3:
	return world._world_aabb(n).get_center()


func _job_at(stage: StringName) -> ProductionJob:
	for j: ProductionJob in sim.production.sorted_jobs():
		if j.stage == stage and j.owner_actor_id == PlayerTaskManager.PLAYER_ID:
			return j
	return null


func _carrying(stage: StringName) -> bool:
	var j: ProductionJob = sim.player.carried_job()
	return j != null and j.stage == stage


func _decor_uid(deco_id: StringName) -> int:
	for o: Dictionary in sim.decoration.owned:
		if StringName(str(o["deco_id"])) == deco_id:
			return int(o["uid"])
	return -1


## Jalur ubin sah terpanjang (paling banyak `steps` langkah) dari tempat dekorasi
## `uid` sekarang; dari yang sama panjang, yang paling sedikit berbelok.
func _decor_walk(uid: int, steps: int) -> Array[Vector2i]:
	var o: Dictionary = sim.decoration.item(uid)
	var at: Vector2i = SimManager.arr_to_cell(o["cell"])
	var start: Array[Vector2i] = [at]
	var best: Dictionary = _walk_from(uid, start, Vector2i.ZERO, 0, steps, int(o.get("rot", 0)))
	return best["path"]


func _walk_from(uid: int, path: Array[Vector2i], dir: Vector2i, turns: int, left: int, rot: int) -> Dictionary:
	var best: Dictionary = {"path": path, "turns": turns}
	if left == 0:
		return best
	var store: StringName = sim.decoration.store_floor()
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var c: Vector2i = path[path.size() - 1] + d
		if path.has(c) or sim.decoration.check_place(uid, store, c, -1, rot) != &"":
			continue
		var next: Array[Vector2i] = path.duplicate()
		next.append(c)
		var turn: int = 1 if dir != Vector2i.ZERO and d != dir else 0
		var r: Dictionary = _walk_from(uid, next, d, turns + turn, left - 1, rot)
		var rp: Array = r["path"]
		var bp: Array = best["path"]
		if rp.size() > bp.size() or (rp.size() == bp.size() and int(r["turns"]) < int(best["turns"])):
			best = r
	return best


# ===========================================================================
# OVERLAY: caption, chip tier, kartu judul & penutup (UI kit flat, GDD 130.6)
# ===========================================================================

func _build_overlay() -> void:
	var layer := CanvasLayer.new()
	layer.name = "TrailerOverlay"
	layer.layer = 100
	add_child(layer)
	_ui = Control.new()
	_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(_ui)
	ProceduralUIFactory.apply_theme(_ui)


func _caption(text: String, icon_name: String, seconds: float, top: bool = false) -> void:
	if _caption_node != null and is_instance_valid(_caption_node):
		_caption_node.queue_free()
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM, 30, false)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 30.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	h.add_child(ProceduralUIFactory.badge(icon_name, Palette.HONEY, Palette.FLOUR_WHITE, 46))
	var l: Label = ProceduralUIFactory.label(text, 30, Palette.UI_WOOD_DEEP)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	h.add_child(l)
	if top:
		_anchor(pc, Vector2(0.5, 0.0), 86.0)
	else:
		_anchor(pc, Vector2(0.5, 1.0), -44.0)
	_ui.add_child(pc)
	_caption_node = pc
	_animate_in_out(pc, seconds, -14.0 if top else 18.0)


func _tier_chip(tier: int, seconds: float) -> void:
	if _chip_node != null and is_instance_valid(_chip_node):
		_chip_node.queue_free()
	var loc: LocationDefinition = DataRegistry.location_by_tier(tier)
	var text: String = "Tier %d  ·  %s" % [tier, Tx.t(String(loc.localization_key))]
	var chip: PanelContainer = ProceduralUIFactory.chip("shop", Palette.HONEY_DEEP, text, 24, 34)
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anchor(chip, Vector2(0.0, 0.0), 28.0)
	_ui.add_child(chip)
	_chip_node = chip
	_animate_in_out(chip, seconds, -14.0)


## Tempel `c` pada titik jangkar layar `at` (0..1), `gap` px dari tepinya.
func _anchor(c: Control, at: Vector2, gap: float) -> void:
	c.anchor_left = at.x
	c.anchor_right = at.x
	c.anchor_top = at.y
	c.anchor_bottom = at.y
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH if at.x == 0.5 else (Control.GROW_DIRECTION_END if at.x == 0.0 else Control.GROW_DIRECTION_BEGIN)
	c.grow_vertical = Control.GROW_DIRECTION_BEGIN if at.y == 1.0 else Control.GROW_DIRECTION_END
	var x: float = 0.0 if at.x == 0.5 else (absf(gap) if at.x == 0.0 else -absf(gap))
	c.offset_left = x
	c.offset_right = x
	c.offset_top = gap
	c.offset_bottom = gap


## Muncul (memudar sambil naik/turun `rise` px), bertahan, lalu hilang.
func _animate_in_out(c: Control, seconds: float, rise: float) -> void:
	c.modulate.a = 0.0
	var top0: float = c.offset_top
	var bottom0: float = c.offset_bottom
	c.offset_top = top0 + rise
	c.offset_bottom = bottom0 + rise
	var tw: Tween = c.create_tween()
	tw.set_parallel(true)
	tw.tween_property(c, "modulate:a", 1.0, 0.35)
	tw.tween_property(c, "offset_top", top0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "offset_bottom", bottom0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.chain().tween_interval(maxf(0.1, seconds - 0.75))
	tw.chain().tween_property(c, "modulate:a", 0.0, 0.3)
	tw.chain().tween_callback(c.queue_free)


## Kartu judul (seperti layar pembuka game) atau kartu penutup dengan tagline dan
## platform.
func _card(ending: bool) -> Control:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(ProceduralUIFactory.backdrop())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 22)
	center.add_child(box)
	var lockup: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 96, 132)
	box.add_child(lockup)
	ProceduralAnimationSystem.idle_wobble(lockup.get_meta("bread"))
	if ending:
		var tag: Label = ProceduralUIFactory.title(TAGLINE, 34)
		box.add_child(tag)
		var row := CenterContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		box.add_child(row)
		var chip: PanelContainer = ProceduralUIFactory.chip("play", Palette.MATCHA_DEEP, PLATFORMS, 26, 34)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(chip)
	_ui.add_child(root)
	return root


# ===========================================================================
# PENANGKAP FRAME
# ===========================================================================

func _start_recording() -> void:
	_recording = true
	# Frame Movie Maker yang sedang berjalan: rekaman suara dipotong dari sini.
	print("TRAILER_REC start_process_frame=%d" % Engine.get_process_frames())


func _on_post_draw() -> void:
	if _preview:
		if _still != "":
			_save(_grab(), _out.path_join(_still + ".png"))
			_still = ""
		return
	if not _recording:
		return
	_save(_grab(), _out.path_join("f%05d.png" % _frame))
	_frame += 1


func _grab() -> Image:
	var img: Image = get_viewport().get_texture().get_image()
	if img.get_size() != OUT_SIZE:
		img.resize(OUT_SIZE.x, OUT_SIZE.y, Image.INTERPOLATE_LANCZOS)
	img.convert(Image.FORMAT_RGB8)
	return img


## PNG ditulis di thread pekerja; paling banyak MAX_SAVE_TASKS menunggu.
func _save(img: Image, path: String) -> void:
	_tasks.append(WorkerThreadPool.add_task(func() -> void: img.save_png(path)))
	while _tasks.size() > MAX_SAVE_TASKS:
		WorkerThreadPool.wait_for_task_completion(_tasks.pop_front())


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame
