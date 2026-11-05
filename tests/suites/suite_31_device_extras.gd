extends TestSuite
## Kerapian perangkat (GDD idle 20 no. 55-57): Settings hanya berisi pengaturan
## yang benar-benar mengubah sesuatu dan HP bergetar untuk umpan balik penting,
## build Web bisa dipasang sebagai PWA, dan save bisa dipindah atau dicadangkan
## sebagai kode teks lewat Load Game.


func tests() -> Array:
	return [
		{"id": "ACC_75_SETTINGS_USED", "name": "v3.1 75, idle 20 no. 55 every setting in Settings is read by the game (Edge scroll, Screen shake and Confirm expensive purchases are gone), and Vibration shows only on phones and buzzes for taps, level-ups, rewards, achievements, moves and franchises, not for other sounds, with a short gap and never when switched off", "fn": _settings_used},
		{"id": "ACC_IDLE_PWA", "name": "idle 20 no. 56 the Web preset installs as a full-screen portrait PWA on the cream background (no cross-origin isolation for the single-threaded build), Android may vibrate, and the update check does nothing outside a browser", "fn": _pwa},
		{"id": "ACC_IDLE_SAVE_CODE", "name": "idle 15.3, 20 no. 57 a save code holds the whole profile and comes back the same (chat line breaks ignored); wrong, cut, classic and newer codes are refused with their reason; importing writes the chosen profile under its own id and keeps the old save as backup", "fn": _save_code},
		{"id": "ACC_IDLE_SAVE_CODE_UI", "name": "idle 20 no. 57 Load Game: each playable save card has Export Save, which copies the code; Import Save pastes a code, previews the bakery and imports it into a picked profile (asking before replacing one); the profile list and the main menu card refresh, also after a delete", "fn": _save_code_ui},
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
	eq(SaveManager.latest_profile(), &"profile_2", "the imported bakery is the one Continue opens")
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
	var s: SimulationRoot = new_sim(33, &"profile_1")
	s.bakery_name = "Move Me Bakery"
	jump_to_tier(s, 2)
	SaveManager.write_profile(&"profile_1", s.capture_save())
	free_sim(s)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.modals.close_all()
	var menu: MainMenuScreen = game.modals.open(&"main_menu") as MainMenuScreen
	var prof: UIScreen = game.modals.open(&"profiles", {"mode": "load"})
	await runner.get_tree().process_frame
	var card1: Control = prof.find_child("Profile1", true, false) as Control
	check(card1 != null and card1.find_child("Export", true, false) is Button, "a playable save card has Export Save")
	var card2: Control = prof.find_child("Profile2", true, false) as Control
	check(card2 != null and card2.find_child("Export", true, false) == null, "an empty card has none")
	var imp_btn: Button = prof.find_child("ImportSave", true, false) as Button
	check(imp_btn != null, "Load Game has Import Save")
	# Export: Copy menyalin kode profil itu.
	(card1.find_child("Export", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	var ex: SaveCodeScreen = game.modals.screen(&"save_code") as SaveCodeScreen
	check(ex != null, "Export Save opens the save code")
	check(game.modals.is_open(&"profiles"), "over the profile list, which stays open")
	if ex != null:
		WebPlatform.last_copied = ""
		(ex.find_child("Copy", true, false) as Button).pressed.emit()
		eq(WebPlatform.last_copied, SaveManager.export_code(&"profile_1"), "Copy Code copies the whole code")
		check((ex.find_child("Status", true, false) as Label).text != "", "and says what happened")
		check(ex.find_child("Download", true, false) == null, "Download File is only in a browser")
		ex.close()
	await runner.get_tree().process_frame
	# Import: Paste membaca clipboard, pratinjau, lalu pilih profil kosong.
	var code: String = SaveManager.export_code(&"profile_1")
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
	check(im.find_child("ImportTo1", true, false) == null, "and offers no profile")
	WebPlatform.fake_clipboard = code
	(im.find_child("Paste", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var nm: Label = im.find_child("BakeryName", true, false) as Label
	eq(nm.text if nm != null else "", "Move Me Bakery", "Paste previews the bakery in the code")
	var to1: Button = im.find_child("ImportTo1", true, false) as Button
	var to3: Button = im.find_child("ImportTo3", true, false) as Button
	check(to1 != null and to1.text.contains("Move Me Bakery"), "a full profile button names the bakery it would replace")
	check(to3 != null and to3.text.contains(Tx.t("ui_profile_empty")), "an empty one says so")
	# Profil berisi: konfirmasi dulu.
	to1.pressed.emit()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"confirm"), "replacing a full profile asks first")
	game.modals.close_id(&"confirm")
	await runner.get_tree().process_frame
	to3.pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(not game.modals.is_open(&"import_save"), "importing into an empty profile closes Import Save")
	eq(SaveManager.read_header(&"profile_3").get("bakery_name"), "Move Me Bakery", "profile 3 holds the bakery")
	var prof2: UIScreen = game.modals.screen(&"profiles")
	check(prof2 != null and prof2.find_child("Profile3", true, false).find_child("Export", true, false) is Button, "the profile list shows it")
	var note: Label = prof2.find_child("Note", true, false) as Label if prof2 != null else null
	eq(note.text if note != null else "", Tx.t("ui_import_done", {"name": "Move Me Bakery", "n": 3}), "with a note about the move")
	# Main Menu di bawahnya ikut dibangun ulang: Continue = save terbaru.
	menu = game.modals.screen(&"main_menu") as MainMenuScreen
	check(menu != null and menu.find_child("Continue", true, false) is Button, "the main menu card still offers Continue")
	eq(SaveManager.latest_profile(), &"profile_3", "the imported profile is the latest")
	# Hapus profil terbaru: kartu Main Menu menunjuk profil yang tersisa.
	(prof2.find_child("Profile3", true, false).find_child("Delete", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	var conf: UIScreen = game.modals.screen(&"confirm")
	if conf != null:
		var yes: Callable = conf.params.get("on_yes")
		game.modals.close_screen(conf)
		yes.call()
	await runner.get_tree().process_frame
	check(not SaveManager.has_profile(&"profile_3"), "profile 3 is deleted")
	menu = game.modals.screen(&"main_menu") as MainMenuScreen
	var cont: Button = menu.find_child("Continue", true, false) as Button if menu != null else null
	check(cont != null, "the main menu card refreshed after the delete")
	var bn: Label = menu.find_child("BakeryName", true, false) as Label if menu != null else null
	eq(bn.text if bn != null else "", "Move Me Bakery", "and shows the remaining profile 1")
	game.modals.close_all()
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
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans, "no orphan UI nodes left")
