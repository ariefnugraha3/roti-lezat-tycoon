class_name GameRoot
extends Node
## GameRoot — titik masuk & orkestrasi sesi (GDD 36, 89, 90, 113, 114).
##
## Boot bertahap: katalog divalidasi (DataRegistry), InputMap didaftarkan, lalu
## layar "Tap to Start" membuka kunci audio web (GDD 12.1, 33.4). Main Menu
## muncul tanpa membangun dunia apa pun (GDD 89.1). Simulasi dan dunia baru
## dibuat saat profil dimuat, dan dihancurkan saat kembali ke menu supaya state
## antar-profil tidak bocor (GDD 35.2).
##
## Masuk gameplay berjalan bertahap di balik LoadingScreen (GDD 89.5, 114): tiap
## tahap berat diberi satu frame supaya teks dan bar kemajuannya tergambar, lalu
## overlay baru memudar setelah frame dunia yang stabil. Di browser HP,
## OrientationGuard menahan permainan selama HP tegak, dan ketukan "Tap to Start"
## memasukkan game ke layar penuh landscape (keputusan maintainer 2026-09-30).

const BUSY_CUSTOMERS: int = 4
## "Skip to Open" (GDD 15.4): waktu nyata per frame untuk tick lompatan, supaya
## dunia tetap tergambar seperti time-lapse dan tab web tidak membeku.
const SKIP_FRAME_BUDGET_USEC: int = 12000
const SKIP_TICKS_PER_CHUNK: int = 20
## Anggaran perakitan musik per frame selama layar loading (mikrodetik).
const LOADING_AUDIO_BUDGET_USEC: int = 30000
## Frame dunia pertama (shader dikompilasi) dianggap stabil di bawah ini (ms).
const STABLE_FRAME_MS: float = 80.0
## Dua ketukan pada perabot yang sama secepat ini = ketukan ganda tak sengaja.
const DOUBLE_TAP_MS: int = 350
const MAX_SETTLE_FRAMES: int = 12

var sim: SimulationRoot = null
var world: WorldView = null
var hud: HUD = null
var modals: ModalHost = null
var commands: CommandLayer = null
var playing: bool = false
var _splash: Control = null
var _loader: LoadingScreen = null
var _orientation: OrientationGuard = null
var _music_timer: float = 0.0
var _tutorial_modal_shown: String = ""
var _skip_overlay: SkipOverlay = null
## Ketukan terakhir pada perabot: {iid, ms}. Ketukan kedua pada perabot yang sama
## dalam DOUBLE_TAP_MS dianggap satu ketukan, bukan pembatalan (GDD 16.4).
var _last_equipment_tap: Dictionary = {}
## Pemanasan shader saat loading dan setelah upgrade lokasi (ShaderWarmup).
## Mati di headless (tanpa GPU tidak ada yang dikompilasi); tes boleh menyalakannya.
var shader_warmup: bool = DisplayServer.get_name() != "headless"


func _ready() -> void:
	name = "GameRoot"
	ProjectSettings.set_setting("application/config/quit_on_go_back", false)
	get_tree().set_quit_on_go_back(false)
	InputActions.register()
	ProceduralUIFactory.text_scale = SettingsManager.text_scale()
	SettingsManager.settings_changed.connect(_on_settings_changed)
	modals = ModalHost.new()
	modals.game = self
	add_child(modals)
	ScreenRegistry.register_all(modals)
	modals.stack_changed.connect(_on_modal_stack_changed)
	PauseManager.lifecycle_paused.connect(_on_lifecycle_paused)
	EventBus.economy_overflowed.connect(func() -> void: modals.open(&"overflow"))
	if WebPlatform.is_mobile_web():
		_orientation = OrientationGuard.new()
		add_child(_orientation)
	if not DataRegistry.is_valid():
		# Katalog rusak: berhenti dengan layar galat berbahasa Inggris (GDD 114, 117).
		GameLogger.error("BOOT", "catalog validation failed: %s" % str(DataRegistry.errors.slice(0, 5)))
		modals.open(&"error", {"text": Tx.t("ui_boot_error") if DataRegistry.has_text("ui_boot_error") else "The game data could not be checked."})
		return
	GameLogger.important("BOOT", "catalogs valid; %d recipes, %d locations" % [DataRegistry.recipes().size(), DataRegistry.locations().size()])
	_show_splash()


# ===========================================================================
# SPLASH & MENU
# ===========================================================================

func _show_splash() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	_splash = Control.new()
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_splash)
	ProceduralUIFactory.apply_theme(_splash)
	_splash.add_child(ProceduralUIFactory.backdrop())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_splash.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 30)
	center.add_child(box)
	var lockup: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 84, 124)
	box.add_child(lockup)
	ProceduralAnimationSystem.idle_wobble(lockup.get_meta("bread"))
	# "Tap to Start" dalam pil krem berbibir yang berdenyut pelan.
	var tap_row := CenterContainer.new()
	tap_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(tap_row)
	var tap: PanelContainer = ProceduralUIFactory.chip("play", Palette.HONEY, Tx.t("ui_tap_to_start"), 24, 30)
	tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tap_row.add_child(tap)
	var pulse := tap.create_tween().set_loops()
	pulse.tween_property(tap, "modulate:a", 0.55, 0.9)
	pulse.tween_property(tap, "modulate:a", 1.0, 0.9)
	_splash.gui_input.connect(_on_splash_input.bind(layer))
	# Musik menu dirakit di latar selagi pemain membaca layar ini, lalu bunyi
	# pendek (GDD 33.6), supaya tidak ada yang perlu dirakit saat bermain.
	AudioManager.prewarm_music([&"menu_music"])
	AudioManager.prewarm_short_sounds()


## Ketukan dihitung saat jari/klik DILEPAS: browser baru mengizinkan layar penuh
## dari gestur yang selesai (touchend/mouseup), bukan saat jari baru menempel.
func _on_splash_input(event: InputEvent, layer: CanvasLayer) -> void:
	if _splash == null:
		return
	var tapped: bool = (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed \
			and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT) \
		or (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed) \
		or (event is InputEventKey and (event as InputEventKey).pressed)
	if not tapped:
		return
	if WebPlatform.is_mobile_web():
		WebPlatform.enter_fullscreen_landscape()
	AudioManager.unlock()
	layer.queue_free()
	_splash = null
	show_main_menu()


func show_main_menu() -> void:
	modals.close_all()
	EventBus.music_state_changed.emit(&"MENU")
	modals.open(&"main_menu")
	# Bed pagi ikut dirakit di latar: saat pemain selesai mengisi nama toko,
	# layar loading tidak perlu menunggunya lagi. Begitu juga bunyi pendek.
	AudioManager.prewarm_music([&"menu_music", &"shop_music_morning"])
	AudioManager.prewarm_short_sounds()


## Boot headless (test/validator): lewati splash.
func skip_splash_for_tests() -> void:
	if _splash != null:
		_splash.get_parent().queue_free()
		_splash = null


# ===========================================================================
# PROFIL (GDD 89)
# ===========================================================================

func start_new_game(profile_id: StringName, gender: String, bakery_name: String) -> void:
	await _begin_loading("ui_loading", 0.05)
	_teardown()
	sim = SimulationRoot.new()
	add_child(sim)
	var seed_value: int = absi(hash("%s|%s|%d" % [profile_id, bakery_name, Time.get_ticks_usec()])) + 1
	sim.start_new_game(profile_id, bakery_name, gender, seed_value)
	await _loading_stage("ui_loading_save", 0.20)
	SaveManager.write_profile(profile_id, sim.capture_save())
	await _enter_gameplay(profile_id)


func load_profile(profile_id: StringName) -> void:
	await _begin_loading("ui_loading_read", 0.05)
	var r: Dictionary = SaveManager.read_profile(profile_id)
	if not bool(r.get("ok", false)):
		_end_loading(true)
		modals.open(&"error", {"text": Tx.t("ui_save_error"), "profile_id": profile_id, "offer_new": true})
		return
	await _loading_stage("ui_loading", 0.20)
	_teardown()
	sim = SimulationRoot.new()
	add_child(sim)
	sim.load_from_save(r["data"])
	await _enter_gameplay(profile_id)
	if bool(r.get("used_backup", false)):
		EventBus.notify.emit(0, "ui_profile_backup_loaded", {}, &"warning")
		# Backup sah dimuat: main ditulis ulang pada checkpoint stabil berikutnya (GDD 132).
		SaveManager.request_autosave("backup_recovered", true)


## Tahap akhir loading (GDD 89.5, 114): musik & ambience hari ini, dunia, HUD,
## lalu beberapa frame dunia di balik overlay sampai stabil. Simulasi baru jalan
## (`playing`) setelah overlay mulai memudar, jadi jam tidak maju selama loading.
func _enter_gameplay(profile_id: StringName) -> void:
	modals.close_all()
	# Sisa bunyi pendek dirakit di layar loading; selama gameplay tidak ada
	# perakitan bunyi di latar yang bisa menahan frame.
	AudioManager.stop_short_sound_prewarm()
	await _loading_stage("ui_loading_music", 0.30)
	await _warm_audio(0.30, 0.55)
	await _loading_stage("ui_loading_world", 0.55)
	world = WorldView.new()
	world.shader_warmup = shader_warmup
	add_child(world)
	world.setup(sim)
	await _loading_stage("ui_loading_counter", 0.72)
	commands = CommandLayer.new()
	commands.world = world
	add_child(commands)
	commands.world_tapped.connect(_on_world_tap)
	commands.back_requested.connect(_on_back)
	commands.pause_requested.connect(_on_pause_key)
	commands.speed_requested.connect(func(s: int) -> void: sim.time.set_speed(s))
	commands.floor_alert_requested.connect(func() -> void: hud.focus_floor_alert())
	hud = HUD.new()
	hud.game = self
	hud.sim = sim
	add_child(hud)
	SaveManager.simulation = sim
	SaveManager.active_profile = profile_id
	AudioManager.rng_source = sim.rng.stream(&"audio_rng")
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = true
	_connect_sim_requests()
	await _loading_stage("ui_loading_ovens", 0.85)
	# Shader setiap visual yang muncul belakangan dikompilasi sekarang, di balik
	# layar loading, bukan di tengah permainan (GDD 89.5, 109; ShaderWarmup).
	var warm: ShaderWarmup = ShaderWarmup.start(world) if shader_warmup else null
	await _settle_frames(0.85, 1.0)
	if warm != null:
		warm.finish()
	MaterialKeep.scan(world)
	playing = true
	_end_loading(false)
	EventBus.profile_loaded.emit(profile_id)
	_update_music()
	_prewarm_day_music()
	# Modal yang harus muncul lagi setelah load.
	if sim.time.phase == TimeManager.SUMMARY or sim.time.phase == TimeManager.CLOSING:
		modals.open(&"daily_summary", {"report": sim.reports.last_report})
	elif sim.bailout.cutscene_pending:
		modals.open(&"bailout", {"repeat": sim.bailout.repeat_visit})
	_show_tutorial_prompt()
	await get_tree().process_frame


func _connect_sim_requests() -> void:
	_connect_bus(EventBus.recipe_book_requested, func() -> void: modals.open(&"recipe_book"))
	_connect_bus(EventBus.slot_picker_requested, func(iid: int) -> void: modals.open(&"slot_picker", {"display": iid}))
	_connect_bus(EventBus.display_detail_requested, func(iid: int) -> void: modals.open(&"display_detail", {"display": iid}))
	_connect_bus(EventBus.customer_order_requested, func(_id: int) -> void: modals.open(&"customer_order", {"customer": sim.ui_requests.customer_order}))
	_connect_bus(EventBus.daily_summary_ready, func(_day: int) -> void: modals.open(&"daily_summary", {"report": sim.reports.last_report}))
	_connect_bus(EventBus.bailout_cutscene_requested, func(repeat: bool) -> void: modals.open(&"bailout", {"repeat": repeat}))
	_connect_bus(EventBus.tutorial_step_changed, func(_s: StringName) -> void: _show_tutorial_prompt())


## Sambungan EventBus disimpan agar dapat diputus saat teardown.
var _bus_links: Array[Dictionary] = []


func _connect_bus(sig: Signal, cb: Callable) -> void:
	sig.connect(cb)
	_bus_links.append({"signal": sig, "cb": cb})


func _disconnect_bus() -> void:
	for l: Dictionary in _bus_links:
		var sig: Signal = l["signal"]
		if sig.is_connected(l["cb"]):
			sig.disconnect(l["cb"])
	_bus_links.clear()


func _teardown() -> void:
	playing = false
	if _skip_overlay != null and is_instance_valid(_skip_overlay):
		_skip_overlay.queue_free()
	_skip_overlay = null
	_disconnect_bus()
	PauseManager.lifecycle_enabled = false
	SaveManager.simulation = null
	SaveManager.active_profile = &""
	AudioManager.rng_source = null
	AudioManager.stop_all_loops()
	# Ambience toko dan cuaca milik dunia; Main Menu hanya memutar menu_music
	# (GDD 33.1). Dulu ambience terus berputar di bawah musik menu.
	AudioManager.set_ambience([])
	for n: Node in [hud, commands, world, sim]:
		if n != null and is_instance_valid(n):
			n.queue_free()
	hud = null
	commands = null
	world = null
	sim = null
	PauseManager.clear_all()
	EventBus.profile_unloaded.emit()


## Kembali ke Main Menu: simpan dulu (GDD 89.2).
func return_to_menu() -> void:
	if sim != null:
		SaveManager.save_now()
	modals.close_all()
	_teardown()
	show_main_menu()


# ===========================================================================
# LOOP
# ===========================================================================

func _process(delta: float) -> void:
	if not playing or sim == null:
		return
	var was_paused: bool = PauseManager.is_paused()
	if _skip_overlay != null:
		_run_skip_to_open()
	else:
		sim.advance(delta)
	if not was_paused:
		sim.statistics.add_play_time(delta)
	_music_timer -= delta
	if _music_timer <= 0.0:
		_music_timer = 1.0
		_update_music()
	if world != null and hud != null:
		var top: UIScreen = modals.top()
		commands.enabled = _skip_overlay == null and (top == null or top.world_input or not modals.has_blocking())
		# Loop mixer/oven mengikuti state (GDD 93).
		var mixing: bool = false
		var baking: bool = false
		for e: EquipmentInstance in sim.equipment.placed_list():
			if e.job_id >= 0:
				var st: StringName = sim.production.job_stage(e.job_id)
				mixing = mixing or st == ProductionJob.MIXING
				baking = baking or st == ProductionJob.BAKING
		var run: bool = not PauseManager.is_paused()
		AudioManager.set_loop(&"mixer_loop", "stations", mixing and run)
		AudioManager.set_loop(&"oven_loop", "stations", baking and run)


func _update_music() -> void:
	if sim == null:
		return
	EventBus.music_state_changed.emit(_music_state())


## Suasana musik untuk keadaan toko saat ini (GDD 33.1).
func _music_state() -> StringName:
	var state: StringName = &"STORE_OPEN_CALM"
	match sim.time.phase:
		TimeManager.PREPARATION:
			state = &"MORNING_PREP"
		TimeManager.OPEN:
			if sim.weather.is_rain():
				state = &"RAIN"
			elif sim.customers.active_count() >= BUSY_CUSTOMERS or sim.rotifood.active_orders().size() >= 2:
				state = &"STORE_OPEN_BUSY"
		_:
			state = &"DAILY_SUMMARY"
	if modals.is_open(&"bailout"):
		state = &"BAILOUT_CUTSCENE"
	return state


## Bed yang akan dibutuhkan hari ini dirakit di latar, jauh sebelum 08:00/18:00.
func _prewarm_day_music() -> void:
	var ids: Array = [&"shop_music_after_hours"]
	if sim.weather.is_rain():
		ids.push_front(&"shop_music_rain")
	else:
		ids.push_front(&"shop_music_busy_layer")
		ids.push_front(&"shop_music_day")
	AudioManager.prewarm_music(ids)


# ===========================================================================
# SKIP TO OPEN (GDD 15.4)
# ===========================================================================

func is_skipping_to_open() -> bool:
	return _skip_overlay != null


## Tombol HUD "Skip to Open": minta konfirmasi, atau jelaskan kenapa belum bisa.
func request_skip_to_open() -> void:
	if sim == null or _skip_overlay != null:
		return
	match sim.skip_to_open_block():
		&"":
			modals.confirm(Tx.t("ui_skip_open_confirm", {"time": Tx.clock(sim.time.open_time)}), begin_skip_to_open)
		&"oven":
			EventBus.notify.emit(1, "ui_skip_open_oven", {}, &"fire")
		_:
			pass


## "Close Early" (GDD 15.5): konfirmasi dulu (dialog menjeda simulasi, jadi
## penalti yang tertulis tepat), lalu toko tutup, jam maju ke 18:00, dan Daily
## Summary terbuka lewat alur penutupan biasa.
func request_close_early() -> void:
	if sim == null or sim.close_early_block() != &"":
		return
	var stars: String = "%.2f" % sim.close_early_penalty()
	modals.confirm(Tx.t("ui_close_early_confirm", {"time": Tx.clock(sim.time.close_time), "stars": stars}), func() -> void:
		if sim != null and sim.close_early():
			EventBus.sfx.emit(&"ui_confirm", &""))


## Mulai lompatan. Simulasi berjalan tick demi tick seperti biasa, hanya jauh
## lebih cepat, sampai 08:00 atau sampai ada oven yang butuh pemain.
func begin_skip_to_open() -> void:
	if sim == null or _skip_overlay != null or sim.skip_to_open_block() != &"":
		return
	_skip_overlay = SkipOverlay.new()
	add_child(_skip_overlay)
	_skip_overlay.begin(sim.time.time_seconds, sim.time.open_time)
	EventBus.sfx.emit(&"ui_confirm", &"")


func _run_skip_to_open() -> void:
	# Modal yang muncul di tengah lompatan (tutorial, lifecycle) menahannya dulu.
	if PauseManager.is_paused():
		return
	var t0: int = Time.get_ticks_usec()
	var result: StringName = &""
	while result == &"" and Time.get_ticks_usec() - t0 < SKIP_FRAME_BUDGET_USEC:
		result = sim.skip_to_open_step(SKIP_TICKS_PER_CHUNK)
	_skip_overlay.show_time(sim.time.time_seconds)
	if result != &"":
		_end_skip_to_open(result)


func _end_skip_to_open(result: StringName) -> void:
	_skip_overlay.finish()
	_skip_overlay = null
	if result == &"oven":
		EventBus.notify.emit(1, "ui_skip_open_stopped", {}, &"fire")


# ===========================================================================
# INPUT DUNIA -> PERINTAH (GDD 12.4, 29)
# ===========================================================================

func _on_world_tap(pos: Vector2) -> void:
	if sim == null or not sim.is_running():
		return
	var p: Dictionary = world.pick(pos)
	match p.get("kind", &"none"):
		&"equipment":
			var iid: int = int(p["iid"])
			var now: int = Time.get_ticks_msec()
			if int(_last_equipment_tap.get("iid", -1)) == iid and now - int(_last_equipment_tap.get("ms", 0)) < DOUBLE_TAP_MS:
				return
			_last_equipment_tap = {"iid": iid, "ms": now}
			sim.player.tap_equipment(iid)
		&"cashier":
			sim.player.tap_cashier(StringName(str(p["lane"])), false)
		&"customer":
			sim.player.tap_customer(StringName(str(p["customer"])))
		&"tablet":
			modals.open(&"rotifood", {})
		&"portal":
			sim.player.tap_portal()
		_:
			pass


func _on_back() -> void:
	if _loader != null:
		return
	if modals.back():
		return
	if hud != null and hud.decoration_active:
		return
	if playing:
		modals.open(&"pause")
	else:
		modals.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit())


func _on_pause_key() -> void:
	if not playing:
		return
	if modals.is_open(&"pause"):
		# Hanya menu Pause; modal di bawahnya (mis. Daily Summary) tetap terbuka.
		modals.close_id(&"pause")
	else:
		modals.open(&"pause")


## Pengaman (GDD 11.5-11.6): selama fase Summary nota harian selalu ada di
## layar. Bila tumpukan modal kosong padahal hari belum dilanjutkan, nota dibuka
## lagi supaya permainan tidak pernah macet tanpa tombol lanjut.
func _on_modal_stack_changed() -> void:
	if _summary_missing():
		_reopen_summary.call_deferred()


func _summary_missing() -> bool:
	return playing and sim != null and sim.time.phase == TimeManager.SUMMARY \
		and not modals.is_open(&"daily_summary") and not modals.has_blocking()


func _reopen_summary() -> void:
	if _summary_missing():
		modals.open(&"daily_summary", {"report": sim.reports.last_report})


func _exit_tree() -> void:
	ProceduralCaches.clear_all()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_on_back()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		if sim != null:
			SaveManager.save_now()


## Fokus hilang: pause sudah didorong PauseManager; simpan prioritas setelah
## pause stabil, lalu tampilkan "Game Paused" (GDD 90, 113).
func _on_lifecycle_paused() -> void:
	if not playing:
		return
	SaveManager.request_autosave("lifecycle", true)
	if not modals.is_open(&"lifecycle"):
		modals.open(&"lifecycle")


func _on_settings_changed(key: String) -> void:
	if key == "text_scale" or key == "":
		ProceduralUIFactory.text_scale = SettingsManager.text_scale()


# ===========================================================================
# TUTORIAL & LOADING
# ===========================================================================

func _show_tutorial_prompt() -> void:
	if sim == null or hud == null:
		return
	var p: Dictionary = sim.tutorial.prompt
	if p.is_empty():
		hud.show_tutorial_hint("", &"", -1)
		world.highlight(&"", -1)
		return
	if bool(p.get("modal", false)):
		if _tutorial_modal_shown != str(p["key"]):
			_tutorial_modal_shown = str(p["key"])
			hud.show_tutorial_hint("", &"", -1)
			modals.open(&"tutorial", {"key": p["key"]})
	else:
		hud.show_tutorial_hint(str(p["key"]), StringName(str(p.get("highlight_kind", ""))), int(p.get("highlight_iid", -1)))
	world.highlight(StringName(str(p.get("highlight_kind", ""))), int(p.get("highlight_iid", -1)))


func _begin_loading(stage_key: String, progress_value: float) -> void:
	_end_loading(true)
	_loader = LoadingScreen.new()
	add_child(_loader)
	await _loading_stage(stage_key, progress_value)


## Tampilkan tahap berikutnya dan beri satu frame agar teks & bar tergambar
## sebelum pekerjaan berat tahap itu berjalan (GDD 114).
func _loading_stage(stage_key: String, progress_value: float) -> void:
	if _loader != null:
		_loader.set_stage(Tx.t(stage_key), progress_value)
	await get_tree().process_frame


func _end_loading(immediate: bool) -> void:
	if _loader != null and is_instance_valid(_loader):
		if immediate:
			_loader.queue_free()
		else:
			_loader.finish()
	_loader = null


func loading_screen() -> LoadingScreen:
	return _loader


## GDD 114 tahap 7: musik suasana sekarang dirakit bertahap dengan bar yang terus
## bergerak (biasanya sudah jadi di Main Menu), lalu ambience cuaca hari ini dan
## loop mixer/oven. Dilewati sebelum audio dibuka (headless), karena belum ada
## yang diputar.
func _warm_audio(p_from: float, p_to: float) -> void:
	if not AudioManager.unlocked:
		return
	var p_mid: float = lerpf(p_from, p_to, 0.8)
	var music: StringName = AudioManager.MUSIC_FOR_STATE.get(_music_state(), &"")
	if music != &"":
		AudioManager.request_stream(music, true)
		while not AudioManager.is_stream_ready(music):
			AudioManager.step_jobs(LOADING_AUDIO_BUDGET_USEC)
			if _loader != null:
				_loader.set_progress(lerpf(p_from, p_mid, AudioManager.stream_progress(music)))
			await get_tree().process_frame
	var others: Array[StringName] = WorldView.ambience_for(sim.weather.is_rain())
	others.append_array([&"mixer_loop", &"oven_loop"])
	# Bunyi pendek lain juga dirakit sekarang. Dulu bunyi disintesis saat pertama
	# dibunyikan, dan di browser itu menahan frame 20-170 ms per bunyi tepat saat
	# pemain mengetuk perabot (GDD 33.6).
	for id: StringName in AudioManager.short_sound_ids():
		if not others.has(id) and not AudioManager.is_stream_ready(id):
			others.append(id)
	for i in others.size():
		AudioManager.stream_for(others[i])
		if _loader != null:
			_loader.set_progress(lerpf(p_mid, p_to, float(i + 1) / float(others.size())))
		await get_tree().process_frame


## GDD 89.5 no. 10: overlay baru memudar setelah frame dunia yang stabil. Frame
## pertama biasanya lama karena shader dikompilasi saat dunia pertama digambar.
func _settle_frames(p_from: float, p_to: float) -> void:
	var stable: int = 0
	var last: int = Time.get_ticks_usec()
	for i in MAX_SETTLE_FRAMES:
		await get_tree().process_frame
		var now: int = Time.get_ticks_usec()
		stable = stable + 1 if float(now - last) / 1000.0 < STABLE_FRAME_MS else 0
		last = now
		if _loader != null:
			_loader.set_progress(lerpf(p_from, p_to, float(i + 1) / float(MAX_SETTLE_FRAMES)))
		if stable >= 2:
			break
	if _loader != null:
		_loader.set_progress(p_to)
