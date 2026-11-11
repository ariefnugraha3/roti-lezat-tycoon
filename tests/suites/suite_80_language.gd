extends TestSuite
## Pilihan bahasa (Seksi 19 no. 25, 20 no. 109): bahasa Inggris dan Indonesia.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_LANGUAGE_STRINGS", "name": "idle 20 no. 109 the Indonesian table has every English key, no extra keys and the same {placeholders}; Tx writes Indonesian text and Indonesian numbers (comma decimals, dot thousands, rb/jt/M/T) and English ones unchanged; a device in Indonesian (id, or in on old Android) starts in Indonesian", "fn": _strings},
		{"id": "ACC_IDLE_LANGUAGE_SWITCH", "name": "idle 20 no. 109 Settings > Gameplay offers English and Bahasa Indonesia; choosing one rebuilds the shop and HUD in that language behind the loading screen and reopens Settings; the start page has EN/ID buttons that rebuild it in that language without starting the game", "fn": _switch},
	]


func _strings() -> void:
	var en: Dictionary = DataRegistry.strings_of("en")
	var idd: Dictionary = DataRegistry.strings_of("id")
	var missing: Array = []
	var bad_ph: Array = []
	var rx := RegEx.create_from_string("\\{[a-z_0-9]+\\}")
	for k: Variant in en.keys():
		if not idd.has(k):
			missing.append(k)
			continue
		var a: Array = []
		var b: Array = []
		for m: RegExMatch in rx.search_all(str(en[k])):
			if not a.has(m.get_string()):
				a.append(m.get_string())
		for m2: RegExMatch in rx.search_all(str(idd[k])):
			if not b.has(m2.get_string()):
				b.append(m2.get_string())
		a.sort()
		b.sort()
		if a != b:
			bad_ph.append(k)
	var extra: Array = idd.keys().filter(func(k: Variant) -> bool: return not en.has(k))
	eq(missing, [], "every English key has an Indonesian text")
	eq(extra, [], "and no Indonesian key is unknown")
	eq(bad_ph, [], "every text keeps the same placeholders")
	DataRegistry.set_language("id")
	eq(Tx.t("ui_tap_to_start"), "Ketuk untuk Mulai", "Tx speaks Indonesian")
	eq(Tx.t("ui_profile_day", {"day": 3}), "Hari 3", "with placeholders")
	eq(Tx.kr(12.5), "12,5 KR", "money under 100 KR uses a decimal comma")
	eq(Tx.big(9850.0), "9.850", "thousands use a dot")
	eq(Tx.big(12400.0), "12,4rb", "rb for thousands")
	eq(Tx.big(3070000.0), "3,07jt", "jt for millions")
	eq(Tx.big(1.5e9), "1,50M", "M for billions (miliar), never read as a million")
	eq(Tx.big(2.0e12), "2,00T", "T for trillions")
	eq(Tx.rate(3.62), "3,62", "rates")
	eq(Tx.mult(1.5), "1,5", "multipliers")
	eq(Tx.dec(2.25, 2), "2,25", "decimals")
	eq(Tx.duration(3900.0), "1 jam 5 mnt", "durations")
	eq(Tx.short_date("2026-11-11"), "11 Nov", "dates put the day first")
	DataRegistry.set_language("en")
	eq(Tx.t("ui_tap_to_start"), "Tap to Start", "and back to English")
	eq([Tx.kr(12.5), Tx.big(9850.0), Tx.big(12400.0), Tx.big(1.5e9), Tx.rate(3.62)], ["12.5 KR", "9,850", "12.4K", "1.50B", "3.62"],
		"English numbers are unchanged")
	eq([SettingsManager.language_for_locale("id"), SettingsManager.language_for_locale("in"), SettingsManager.language_for_locale("ID"),
		SettingsManager.language_for_locale("en"), SettingsManager.language_for_locale("ja")], ["id", "id", "id", "en", "en"],
		"a device in Indonesian starts in Indonesian, any other in English")


func _switch() -> void:
	SaveManager.dir = "user://test_saves_language"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	# Halaman start: tombol EN/ID menyusun ulang halaman itu saja.
	var scene: StartScene = game._splash as StartScene
	check(scene != null and scene.language_buttons() != null, "the start page has language buttons")
	if scene != null and scene.language_buttons() != null:
		(scene.language_buttons().get_node("Lang_id") as Button).pressed.emit()
		await runner.get_tree().process_frame
		var again: StartScene = game._splash as StartScene
		check(again != null and again != scene, "the start page is rebuilt")
		var tap_l: Label = again.tap_pill().find_children("*", "Label", true, false)[0] as Label if again != null else null
		eq(tap_l.text if tap_l != null else "", "Ketuk untuk Mulai", "in Indonesian, still waiting for Tap to Start")
		(again.language_buttons().get_node("Lang_en") as Button).pressed.emit()
		await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Language Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	var old_hud: HUD = game.hud
	var settings: SettingsScreen = game.modals.open(&"settings") as SettingsScreen
	settings._tab = 2
	SettingsScreen._last_tab = 2
	settings._render()
	await runner.get_tree().process_frame
	var row: Node = settings.find_child("LanguageRow", true, false)
	check(row != null and row.find_child("Lang_en", true, false) != null and row.find_child("Lang_id", true, false) != null,
		"Settings > Gameplay offers English and Bahasa Indonesia")
	(row.find_child("Lang_id", true, false) as Button).pressed.emit()
	var guard: int = 0
	while (game.hud == old_hud or game.loading_screen() != null or not game.modals.is_open(&"settings")) and guard < 600:
		await runner.get_tree().process_frame
		guard += 1
	check(game.hud != old_hud and game.hud != null, "the HUD is rebuilt")
	var tab: Button = game.hud.tab_button(&"shop")
	eq((tab.get_meta("caption") as Label).text, "Toko", "in Indonesian")
	check(game.modals.is_open(&"settings"), "and Settings opens again")
	eq(game.sim.bakery_name, "Language Bakery", "the same bakery carries on")
	var row2: Node = game.modals.screen(&"settings").find_child("LanguageRow", true, false)
	check(row2 != null, "on the Gameplay tab")
	if row2 != null:
		(row2.find_child("Lang_en", true, false) as Button).pressed.emit()
		guard = 0
		while (game.loading_screen() != null or not game.modals.is_open(&"settings")) and guard < 600:
			await runner.get_tree().process_frame
			guard += 1
	eq((game.hud.tab_button(&"shop").get_meta("caption") as Label).text, "Shop", "and back in English")
	SettingsScreen._last_tab = 0
	game.modals.close_all()
	game.playing = true
	game.end_session()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false
