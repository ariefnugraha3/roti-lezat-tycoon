class_name GameRoot
extends Node
## GameRoot — titik masuk & orkestrasi sesi (GDD 36, 89, 90, 113, 114).
##
## Boot bertahap: katalog divalidasi (DataRegistry), InputMap didaftarkan, lalu
## layar "Tap to Start" membuka kunci audio web (GDD 12.1, 33.4). Main Menu
## muncul tanpa membangun dunia apa pun (GDD 89.1). Simulasi dan dunia baru
## dibuat saat profil dimuat, dan dihancurkan saat kembali ke menu supaya state
## antar-profil tidak bocor (GDD 35.2).

const BUSY_CUSTOMERS: int = 4

var sim: SimulationRoot = null
var world: WorldView = null
var hud: HUD = null
var modals: ModalHost = null
var commands: CommandLayer = null
var playing: bool = false
var _splash: Control = null
var _loading: Control = null
var _music_timer: float = 0.0
var _tutorial_modal_shown: String = ""


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
	PauseManager.lifecycle_paused.connect(_on_lifecycle_paused)
	EventBus.economy_overflowed.connect(func() -> void: modals.open(&"overflow"))
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
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BOTH
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_splash.add_child(box)
	var t: Label = ProceduralUIFactory.title(Tx.t("game_title"), 46)
	box.add_child(t)
	var c := CenterContainer.new()
	c.add_child(ProceduralUIFactory.icon("bread", 96, Palette.GOLDEN_CRUST))
	box.add_child(c)
	var tap: Label = ProceduralUIFactory.label(Tx.t("ui_tap_to_start"), 24, Palette.TEXT_MUTED)
	tap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(tap)
	var pulse := tap.create_tween().set_loops()
	pulse.tween_property(tap, "modulate:a", 0.45, 0.9)
	pulse.tween_property(tap, "modulate:a", 1.0, 0.9)
	_splash.gui_input.connect(_on_splash_input.bind(layer))


func _on_splash_input(event: InputEvent, layer: CanvasLayer) -> void:
	var pressed: bool = (event is InputEventMouseButton and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed) \
		or (event is InputEventKey and (event as InputEventKey).pressed)
	if not pressed:
		return
	AudioManager.unlock()
	layer.queue_free()
	_splash = null
	show_main_menu()


func show_main_menu() -> void:
	modals.close_all()
	EventBus.music_state_changed.emit(&"MENU")
	modals.open(&"main_menu")


## Boot headless (test/validator): lewati splash.
func skip_splash_for_tests() -> void:
	if _splash != null:
		_splash.get_parent().queue_free()
		_splash = null


# ===========================================================================
# PROFIL (GDD 89)
# ===========================================================================

func start_new_game(profile_id: StringName, gender: String, bakery_name: String) -> void:
	_show_loading(Tx.t("ui_loading"))
	await get_tree().process_frame
	_teardown()
	sim = SimulationRoot.new()
	add_child(sim)
	var seed_value: int = absi(hash("%s|%s|%d" % [profile_id, bakery_name, Time.get_ticks_usec()])) + 1
	sim.start_new_game(profile_id, bakery_name, gender, seed_value)
	SaveManager.write_profile(profile_id, sim.capture_save())
	await _enter_gameplay(profile_id)


func load_profile(profile_id: StringName) -> void:
	var r: Dictionary = SaveManager.read_profile(profile_id)
	if not bool(r.get("ok", false)):
		modals.open(&"error", {"text": Tx.t("ui_save_error"), "profile_id": profile_id, "offer_new": true})
		return
	_show_loading(Tx.t("ui_loading_world"))
	await get_tree().process_frame
	_teardown()
	sim = SimulationRoot.new()
	add_child(sim)
	sim.load_from_save(r["data"])
	await _enter_gameplay(profile_id)
	if bool(r.get("used_backup", false)):
		EventBus.notify.emit(0, "ui_profile_backup_loaded", {}, &"warning")
		# Backup sah dimuat: main ditulis ulang pada checkpoint stabil berikutnya (GDD 132).
		SaveManager.request_autosave("backup_recovered", true)


func _enter_gameplay(profile_id: StringName) -> void:
	modals.close_all()
	world = WorldView.new()
	add_child(world)
	world.setup(sim)
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
	playing = true
	_hide_loading()
	EventBus.profile_loaded.emit(profile_id)
	_update_music()
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
	_disconnect_bus()
	PauseManager.lifecycle_enabled = false
	SaveManager.simulation = null
	SaveManager.active_profile = &""
	AudioManager.rng_source = null
	AudioManager.stop_all_loops()
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
	sim.advance(delta)
	if not was_paused:
		sim.statistics.add_play_time(delta)
	_music_timer -= delta
	if _music_timer <= 0.0:
		_music_timer = 1.0
		_update_music()
	if world != null and hud != null:
		var top: UIScreen = modals.top()
		commands.enabled = top == null or top.world_input or not modals.has_blocking()
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
	EventBus.music_state_changed.emit(state)


# ===========================================================================
# INPUT DUNIA -> PERINTAH (GDD 12.4, 29)
# ===========================================================================

func _on_world_tap(pos: Vector2) -> void:
	if sim == null or not sim.is_running():
		return
	var p: Dictionary = world.pick(pos)
	match p.get("kind", &"none"):
		&"equipment":
			sim.player.tap_equipment(int(p["iid"]))
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
		modals.close_all()
	else:
		modals.open(&"pause")


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


func _show_loading(text: String) -> void:
	_hide_loading()
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_loading = Control.new()
	_loading.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var l: Label = ProceduralUIFactory.title(text, 28)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_loading.add_child(l)


func _hide_loading() -> void:
	if _loading != null and is_instance_valid(_loading):
		_loading.get_parent().queue_free()
	_loading = null
