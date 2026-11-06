extends TestSuite
## Kerapian perangkat (GDD idle 20 no. 55-57): Settings hanya berisi pengaturan
## yang benar-benar mengubah sesuatu dan HP bergetar untuk umpan balik penting,
## build Web bisa dipasang sebagai PWA, dan save bisa dipindah atau dicadangkan
## sebagai kode teks lewat Settings (GDD idle 19 no. 21: satu save, tanpa Main Menu).


func tests() -> Array:
	return [
		{"id": "ACC_75_SETTINGS_USED", "name": "v3.1 75, idle 20 no. 55 every setting in Settings is read by the game (Edge scroll, Screen shake and Confirm expensive purchases are gone), and Vibration shows only on phones and buzzes for taps, level-ups, rewards, achievements, moves and franchises, not for other sounds, with a short gap and never when switched off", "fn": _settings_used},
		{"id": "ACC_IDLE_PWA", "name": "idle 20 no. 56 the Web preset installs as a full-screen portrait PWA on the cream background (no cross-origin isolation for the single-threaded build), Android may vibrate, and the update check does nothing outside a browser", "fn": _pwa},
		{"id": "ACC_IDLE_SAVE_CODE", "name": "idle 15.3, 20 no. 57 a save code holds the whole profile and comes back the same (chat line breaks ignored); wrong, cut, classic and newer codes are refused with their reason; importing writes the chosen profile under its own id and keeps the old save as backup", "fn": _save_code},
		{"id": "ACC_IDLE_SAVE_CODE_UI", "name": "idle 20 no. 57, 68 Settings > Gameplay: Export Save copies the code of the bakery being played (saved first); Import Save pastes a code, previews the bakery, asks before replacing the one being played, then loads it and keeps the old one as the save's backup", "fn": _save_code_ui},
	]


# ===========================================================================
# SETTINGS & GETAR
# ===========================================================================

func _settings_used() -> void:
	for gone: String in ["edge_scroll", "confirm_expensive", "confirm_threshold", "screen_shake"]:
		check(not SettingsManager.DEFAULTS.has(gone), "%s is no longer a setting" % gone)
		check(not DataRegistry.has_text("ui_settings_" + gone), "and has no label left")
	# Setiap pengaturan dibaca kode di luar daftarnya sendiri: sistem lain, atau
	# _apply dan helper SettingsManager (fullscreen, fps_cap, reduced_motion).
	var sources: String = ""
	for path: String in _scripts("res://"):
		if path.ends_with("settings_screen.gd"):
			continue
		var text: String = FileAccess.get_file_as_string(path)
		if path.ends_with("settings_manager.gd"):
			text = text.substr(0, text.find("const DEFAULTS")) + text.substr(text.find("var values"))
		sources += text
	for key: String in SettingsManager.DEFAULTS.keys():
		check(sources.contains("\"%s\"" % key), "the game reads the %s setting" % key)
	# Vibration hanya tampil di perangkat yang bisa bergetar.
	var screen := SettingsScreen.new()
	runner.add_child(screen)
	screen._tab = 3
	screen._render()
	check(screen.find_child(Tx.t("ui_settings_haptics"), true, false) == null and not _has_text(screen, Tx.t("ui_settings_haptics")),
		"a desktop has no Vibration switch")
	Haptics.force_supported = true
	screen._render()
	check(_has_text(screen, Tx.t("ui_settings_haptics")), "a phone has the Vibration switch")
	screen.free()
	# Getar mengikuti suara umpan balik lewat EventBus.sfx.
	var was: bool = SettingsManager.get_bool("haptics")
	SettingsManager.set_value("haptics", true)
	Haptics.reset()
	EventBus.sfx.emit(&"level_up", &"")
	eq(Haptics.pulses, 1, "a level-up buzzes")
	eq(Haptics.last_ms, int(Haptics.PULSE_MS[&"level_up"]), "briefly")
	EventBus.sfx.emit(&"franchise_jingle", &"")
	eq(Haptics.pulses, 1, "a second buzz right after is skipped (short gap)")
	Haptics.reset()
	EventBus.sfx.emit(&"footstep_tile", &"")
	EventBus.sfx.emit(&"ui_tap_soft", &"")
	eq(Haptics.pulses, 0, "footsteps and menu taps do not buzz")
	for ev: StringName in [&"tap_boost_pop", &"coin_shower", &"achievement_unlock", &"location_upgrade", &"franchise_jingle", &"milestone_fanfare"]:
		Haptics.reset()
		EventBus.sfx.emit(ev, &"")
		eq(Haptics.pulses, 1, "%s buzzes" % ev)
	Haptics.reset()
	SettingsManager.set_value("haptics", false)
	EventBus.sfx.emit(&"level_up", &"")
	eq(Haptics.pulses, 0, "Vibration off: no buzz")
	Haptics.force_supported = false
	Haptics.reset()
	SettingsManager.set_value("haptics", true)
	EventBus.sfx.emit(&"level_up", &"")
	eq(Haptics.pulses, 0, "a desktop never buzzes")
	SettingsManager.set_value("haptics", was)
	Haptics.reset()
	AudioManager.stop_all_sounds()


static func _scripts(dir: String) -> Array[String]:
	var out: Array[String] = []
	for d: String in DirAccess.get_directories_at(dir):
		if d.begins_with(".") or d in ["tests", "tools", "build", "docs", "addons"]:
			continue
		out.append_array(_scripts(dir.path_join(d)))
	for f: String in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	return out


static func _has_text(root: Node, text: String) -> bool:
	for n: Node in root.find_children("*", "Label", true, false):
		if (n as Label).text == text:
			return true
	return false


# ===========================================================================
# PWA
# ===========================================================================

func _pwa() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "export presets load")
	var web: String = ""
	var android: Array[String] = []
	for sec: String in cfg.get_sections():
		if sec.ends_with(".options"):
			continue
		match str(cfg.get_value(sec, "platform", "")):
			"Web":
				# Preset portal (GDD idle 22.2) sengaja tanpa PWA.
				if str(cfg.get_value(sec, "name", "")) == "Web":
					web = sec + ".options"
			"Android":
				android.append(sec + ".options")
	check(web != "", "a Web preset exists")
	check(bool(cfg.get_value(web, "progressive_web_app/enabled", false)), "the Web build is a PWA")
	eq(int(cfg.get_value(web, "progressive_web_app/display", -1)), 0, "it opens full screen")
	eq(int(cfg.get_value(web, "progressive_web_app/orientation", -1)), 2, "in portrait")
	check(not bool(cfg.get_value(web, "progressive_web_app/ensure_cross_origin_isolation_headers", true)), "without cross-origin isolation (single-threaded build)")
	var bg: Color = cfg.get_value(web, "progressive_web_app/background_color", Color.BLACK)
	check(bg.is_equal_approx(Palette.UI_CREAM), "its launch screen is the cream of the boot splash")
	eq(android.size(), 2, "two Android presets")
	for a: String in android:
		check(bool(cfg.get_value(a, "permissions/vibrate", false)), "%s may vibrate" % a)
	check(not WebPlatform.pwa_update_waiting(), "no web update outside a browser")
	WebPlatform.apply_pwa_update()


# ===========================================================================
# KODE SAVE
# ===========================================================================

func _save_code() -> void:
	SaveManager.dir = "user://test_saves_code"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	eq(SaveManager.export_code(&"profile_1"), "", "an empty profile has no code")
	var s: SimulationRoot = new_sim(31, &"profile_1")
	s.bakery_name = "Code Bakery"
	jump_to_tier(s, 3)
	run_hours(s, 1.0)
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "profile 1 saved")
	free_sim(s)
	var code: String = SaveManager.export_code(&"profile_1")
	check(code.begins_with(SaveManager.CODE_PREFIX), "the code starts with %s" % SaveManager.CODE_PREFIX)
	var file_text: String = FileAccess.get_file_as_string(SaveManager.main_path(&"profile_1"))
	check(code.length() < file_text.length() / 2, "the code is much shorter than the save file (%d vs %d chars)" % [code.length(), file_text.length()])
	var r: Dictionary = SaveManager.decode_code(code)
	check(bool(r.get("ok", false)), "the code decodes")
	var orig: Dictionary = SaveManager.read_profile(&"profile_1")["data"]
	same_state(logical_state(normalize_save(r.get("data", {}))), logical_state(normalize_save(orig)), "the decoded save equals the profile")
	# Aplikasi chat memecah teks panjang.
	var wrapped: String = ""
	for i in range(0, code.length(), 60):
		wrapped += code.substr(i, 60) + ("\r\n" if i % 120 == 0 else " \n")
	check(bool(SaveManager.decode_code("  " + wrapped + "  ").get("ok", false)), "line breaks and spaces from a chat app are ignored")
	eq(SaveManager.decode_code("hello").get("error"), "format", "random text is not a code")
	eq(SaveManager.decode_code(code.substr(0, code.length() - 3)).get("error"), "format", "a cut code is refused")
	eq(SaveManager.decode_code(SaveManager.CODE_PREFIX + "!!!!").get("error"), "format", "a code with stray characters is refused")
	eq(SaveManager.decode_code(SaveManager.CODE_PREFIX + Marshalls.raw_to_base64("not gzip at all, just text".to_utf8_buffer())).get("error"), "format",
		"a code that is not a packed save is refused")
	var classic: Dictionary = orig.duplicate(true)
	classic.erase("game_mode")
	eq(SaveManager.decode_code(_pack(classic)).get("error"), "classic", "a classic save is refused")
	var newer: Dictionary = orig.duplicate(true)
	newer["schema_version"] = SaveManager.current_schema_version() + 1
	eq(SaveManager.decode_code(_pack(newer)).get("error"), "newer", "a save from a newer game is refused")
	var broken: Dictionary = orig.duplicate(true)
	broken["location_id"] = "location_nowhere"
	eq(SaveManager.decode_code(_pack(broken)).get("error"), "invalid", "a save with a broken field is refused")
	eq(SaveManager.import_code("hello", &"profile_2"), "format", "a bad code is not imported")
	check(not SaveManager.has_profile(&"profile_2"), "and writes nothing")
	# Import ke profil kosong dan ke profil yang berisi.
	eq(SaveManager.import_code(code, &"profile_2"), "", "the code imports into profile 2")
	var p2: Dictionary = SaveManager.read_profile(&"profile_2")
	check(bool(p2.get("ok", false)), "profile 2 reads back")
	eq(str((p2.get("data", {}) as Dictionary).get("profile_id", "")), "profile_2", "under its own profile id")
	eq(str((p2.get("data", {}) as Dictionary).get("bakery_name", "")), "Code Bakery", "with the bakery inside the code")
	eq(SaveManager.latest_profile(), &"profile_2", "the imported bakery is the latest one")
	var other: SimulationRoot = new_sim(32, &"profile_3")
	other.bakery_name = "Old Bakery"
	SaveManager.write_profile(&"profile_3", other.capture_save())
	free_sim(other)
	eq(SaveManager.import_code(code, &"profile_3"), "", "the code replaces profile 3")
	eq(SaveManager.read_header(&"profile_3").get("bakery_name"), "Code Bakery", "profile 3 now holds the imported bakery")
	var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.backup_path(&"profile_3")))
	eq(str(back.get("bakery_name", "")), "Old Bakery", "the replaced save stays as profile 3's backup")
	var loaded: SimulationRoot = load_sim(SaveManager.read_profile(&"profile_2")["data"])
	eq(loaded.bakery_name, "Code Bakery", "the imported save loads into a running shop")
	eq(loaded.world.location.tier, 3, "at its location tier")
	free_sim(loaded)
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"


static func _pack(d: Dictionary) -> String:
	var bytes: PackedByteArray = JSON.stringify(d, "", true, true).to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return SaveManager.CODE_PREFIX + Marshalls.raw_to_base64(bytes)


func _save_code_ui() -> void:
	SaveManager.dir = "user://test_saves_code_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var orphans: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	# Kode dari "perangkat lain": toko lain yang ditulis sementara di slot 2.
	var s: SimulationRoot = new_sim(33, &"profile_2")
	s.bakery_name = "Move Me Bakery"
	jump_to_tier(s, 2)
	SaveManager.write_profile(&"profile_2", s.capture_save())
	free_sim(s)
	var code: String = SaveManager.export_code(&"profile_2")
	SaveManager.delete_profile(&"profile_2")
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(SaveManager.SAVE_ID, "female", "Playing Bakery")
	game.sim.tutorial.skip()
	game.modals.close_all()
	var settings: SettingsScreen = game.modals.open(&"settings") as SettingsScreen
	settings._tab = 2
	settings._render()
	await runner.get_tree().process_frame
	var ex_btn: Button = settings.find_child("ExportSave", true, false) as Button
	var imp_btn: Button = settings.find_child("ImportSave", true, false) as Button
	check(ex_btn != null and imp_btn != null and settings.find_child("ResetGame", true, false) is Button,
		"Settings > Gameplay has Export Save, Import Save and Reset Game")
	if ex_btn == null or imp_btn == null:
		game.queue_free()
		return
	# Export: kodenya memuat toko yang sedang dimainkan.
	game.sim.economy.balance = 4321.0
	ex_btn.pressed.emit()
	await runner.get_tree().process_frame
	var ex: SaveCodeScreen = game.modals.screen(&"save_code") as SaveCodeScreen
	check(ex != null and game.modals.is_open(&"settings"), "Export Save opens the save code over Settings")
	if ex != null:
		var exported: Dictionary = SaveManager.decode_code(ex.code).get("data", {})
		eq(SaveManager.header_of(exported).get("balance_kr"), 4321.0, "the code holds the shop as it is now, not the last autosave")
		WebPlatform.last_copied = ""
		(ex.find_child("Copy", true, false) as Button).pressed.emit()
		eq(WebPlatform.last_copied, ex.code, "Copy Code copies the whole code")
		check((ex.find_child("Status", true, false) as Label).text != "", "and says what happened")
		check(ex.find_child("Download", true, false) == null, "Download File is only in a browser")
		ex.close()
	await runner.get_tree().process_frame
	# Import: Paste membaca clipboard, pratinjau, lalu Load This Bakery.
	imp_btn.pressed.emit()
	await runner.get_tree().process_frame
	var im: ImportSaveScreen = game.modals.screen(&"import_save") as ImportSaveScreen
	check(im != null, "Import Save opens")
	if im == null:
		game.queue_free()
		return
	WebPlatform.fake_clipboard = "not a code"
	(im.find_child("Paste", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq((im.find_child("Status", true, false) as Label).text, Tx.t("ui_import_err_format"), "a wrong clipboard is explained")
	check(im.find_child("LoadBakery", true, false) == null, "and offers nothing to load")
	WebPlatform.fake_clipboard = code
	(im.find_child("Paste", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var nm: Label = im.find_child("BakeryName", true, false) as Label
	eq(nm.text if nm != null else "", "Move Me Bakery", "Paste previews the bakery in the code")
	var load_btn: Button = im.find_child("LoadBakery", true, false) as Button
	check(load_btn != null, "with Load This Bakery")
	load_btn.pressed.emit()
	await runner.get_tree().process_frame
	var conf: UIScreen = game.modals.screen(&"confirm")
	check(conf != null and str(conf.params.get("text", "")).contains("Playing Bakery"), "it asks first, naming the bakery that gets replaced")
	if conf != null:
		var yes: Callable = conf.params.get("on_yes")
		game.modals.close_screen(conf)
		yes.call()
	var guard: int = 0
	while (game.sim == null or not game.playing or game.sim.bakery_name != "Move Me Bakery") and guard < 600:
		await runner.get_tree().process_frame
		guard += 1
	check(game.playing and game.sim != null and game.sim.bakery_name == "Move Me Bakery", "the imported bakery is loaded and running")
	eq(game.sim.world.location.tier if game.sim != null else 0, 2, "at its location")
	eq(SaveManager.read_header(SaveManager.SAVE_ID).get("bakery_name"), "Move Me Bakery", "it is now the save")
	var back: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SaveManager.backup_path(SaveManager.SAVE_ID)))
	eq(str(back.get("bakery_name", "")), "Playing Bakery", "the replaced bakery stays as the save's backup")
	check(not game.modals.is_open(&"import_save") and not game.modals.is_open(&"settings"), "Import Save and Settings are closed")
	game.playing = false
	game.end_session(false)
	game.queue_free()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	WebPlatform.fake_clipboard = ""
	WebPlatform.last_copied = ""
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	AudioManager.stop_all_sounds()
	AudioManager.set_music_state(&"")
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans, "no orphan UI nodes left")
