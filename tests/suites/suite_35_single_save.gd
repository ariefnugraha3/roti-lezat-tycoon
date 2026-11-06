extends TestSuite
## Satu save, tanpa Main Menu (keputusan maintainer 2026-11-06, GDD idle 19
## no. 21, 20 no. 68): Tap to Start langsung memuat toko, permainan pertama
## membuka popup karakter dan nama toko, save versi tiga profil digabung menjadi
## satu, Reset Game di Settings memulai dari awal, dan save yang tidak terbaca
## tidak pernah meninggalkan layar kosong.

const DIR: String = "user://test_saves_single"


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_SINGLE_SAVE_START", "name": "idle 19 no. 21 there is no main menu: after Tap to Start a first game opens the new bakery popup, and a game with a save goes straight into the shop with no popup", "fn": _start},
		{"id": "ACC_IDLE_SINGLE_SAVE_ADOPT", "name": "idle 20 no. 68 saves from the three-profile version become one: the latest bakery moves into the save and the old one swaps into its slot; an unplayable save there moves to a free slot, and a new game never overwrites a classic save silently", "fn": _adopt},
		{"id": "ACC_IDLE_RESET_GAME", "name": "idle 20 no. 68 Pause has Credits and, off the web, Quit Game but no Main Menu; Settings > Reset Game asks first, then deletes every save without saving the shop again and opens the new bakery popup like a fresh install", "fn": _reset},
		{"id": "ACC_IDLE_SAVE_UNREADABLE", "name": "idle 20 no. 68, v3.1 132 a save that cannot be read shows Try Again and Start a New Bakery (asking first) on the opening backdrop, and Back cannot leave an empty screen; a classic save alone counts as no save", "fn": _unreadable},
	]


func _clean() -> void:
	SaveManager.dir = DIR
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)


func _done() -> void:
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false
	AudioManager.stop_all_sounds()
	AudioManager.set_music_state(&"")


func _game() -> GameRoot:
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	return game


func _write(pid: StringName, bakery: String, seed_value: int) -> void:
	var s: SimulationRoot = new_sim(seed_value, pid)
	s.bakery_name = bakery
	SaveManager.write_profile(pid, s.capture_save())
	free_sim(s)


## Save tycoon v3.1: tanpa `game_mode`.
func _write_classic(pid: StringName) -> void:
	SaveManager._ensure_dir()
	var f: FileAccess = FileAccess.open(SaveManager.main_path(pid), FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema_version": 6, "profile_id": String(pid), "bakery_name": "Classic Bakery"}))
	f.close()


func _start() -> void:
	_clean()
	var game: GameRoot = await _game()
	check(not game.modals._factories.has(&"main_menu") and not game.modals._factories.has(&"profiles"), "there is no main menu or profile list any more")
	game.begin()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"new_game"), "a first game opens the new bakery popup")
	check(game.sim == null and not game.playing, "and nothing runs behind it")
	game.modals.close_all()
	_write(SaveManager.SAVE_ID, "Saved Bakery", 41)
	await game.begin()
	check(game.playing and game.sim != null, "with a save, Tap to Start goes straight into the shop")
	eq(game.sim.bakery_name if game.sim != null else "", "Saved Bakery", "the saved bakery")
	check(not game.modals.is_open(&"new_game"), "without the new bakery popup")
	game.playing = false
	game.end_session(false)
	game.queue_free()
	await runner.get_tree().process_frame
	_done()


func _adopt() -> void:
	_clean()
	# Profil 1 lebih lama, profil 2 dimainkan terakhir.
	_write(&"profile_1", "Old Bakery", 42)
	_write(&"profile_2", "Newest Bakery", 43)
	eq(SaveManager.latest_profile(), &"profile_2", "profile 2 was played last")
	check(SaveManager.adopt_latest_save(), "the latest bakery is adopted")
	eq(SaveManager.read_header(SaveManager.SAVE_ID).get("bakery_name"), "Newest Bakery", "it is now the save")
	eq(SaveManager.read_header(&"profile_2").get("bakery_name"), "Old Bakery", "the older bakery swapped into its slot, not deleted")
	check(SaveManager.read_profile(&"profile_2").get("ok", false), "under its own profile id")
	eq(SaveManager.latest_profile(), SaveManager.SAVE_ID, "the save is the latest now")
	check(not SaveManager.adopt_latest_save(), "adopting again changes nothing")
	# Save tycoon di SAVE_ID: pindah ke slot kosong, toko terbaru masuk.
	_clean()
	_write_classic(SaveManager.SAVE_ID)
	_write(&"profile_2", "Idle Bakery", 44)
	eq(SaveManager.save_state(), "classic", "a classic save is not playable")
	check(SaveManager.adopt_latest_save(), "the idle bakery is adopted over it")
	eq(SaveManager.read_header(SaveManager.SAVE_ID).get("bakery_name"), "Idle Bakery", "the save is the idle bakery")
	check(bool(SaveManager.read_header(&"profile_3").get("classic", false)), "the classic save moved to the free slot")
	# Toko baru di atas save tycoon: save itu dipindah dulu.
	_clean()
	_write_classic(SaveManager.SAVE_ID)
	SaveManager.make_room_for_new_game()
	eq(SaveManager.save_state(), "none", "a new game finds the save slot free")
	check(bool(SaveManager.read_header(&"profile_2").get("classic", false)), "after the classic save moved to slot 2")
	SaveManager.delete_all_profiles()
	for pid: StringName in SaveManager.PROFILE_IDS:
		check(not SaveManager.has_profile(pid), "%s is deleted" % pid)
	_done()


func _reset() -> void:
	_clean()
	var game: GameRoot = await _game()
	await game.start_new_game(SaveManager.SAVE_ID, "male", "Reset Bakery")
	game.sim.tutorial.skip()
	game.modals.close_all()
	_write(&"profile_3", "Leftover Bakery", 45)
	var pause: UIScreen = game.modals.open(&"pause")
	await runner.get_tree().process_frame
	check(pause.find_child("ui_main_credits", true, false) is Button, "Pause has Credits")
	check(pause.find_child("ui_quit_game", true, false) is Button, "and Quit Game off the web")
	var texts: Array = pause.find_children("*", "Button", true, false).map(func(b: Node) -> String: return (b as Button).text)
	check(not texts.has("Main Menu"), "but no Main Menu")
	game.modals.close_all()
	var settings: SettingsScreen = game.modals.open(&"settings") as SettingsScreen
	settings._tab = 2
	settings._render()
	await runner.get_tree().process_frame
	var rs: Button = settings.find_child("ResetGame", true, false) as Button
	check(rs != null, "Settings > Gameplay has Reset Game")
	if rs == null:
		game.queue_free()
		_done()
		return
	rs.pressed.emit()
	await runner.get_tree().process_frame
	var conf: UIScreen = game.modals.screen(&"confirm")
	check(conf != null and bool(conf.params.get("destructive", false)), "it asks first, as a destructive choice")
	check(game.sim != null and SaveManager.has_profile(SaveManager.SAVE_ID), "nothing is deleted before the answer")
	var writes: int = SaveManager.write_count()
	if conf != null:
		var yes: Callable = conf.params.get("on_yes")
		game.modals.close_screen(conf)
		yes.call()
	await runner.get_tree().process_frame
	eq(SaveManager.write_count(), writes, "the shop is not saved again on the way out")
	for pid: StringName in SaveManager.PROFILE_IDS:
		check(not SaveManager.has_profile(pid), "%s is deleted" % pid)
	check(game.sim == null and not game.playing, "the shop is gone")
	check(game.modals.is_open(&"new_game") and game.modals.top().screen_id == &"new_game", "the new bakery popup opens, like a fresh install")
	await game.start_new_game(SaveManager.SAVE_ID, "female", "Fresh Bakery")
	eq(game.sim.bakery_name, "Fresh Bakery", "a brand-new bakery starts")
	eq(game.sim.prestige.run_index, 1, "from the first run")
	game.playing = false
	game.end_session(false)
	game.queue_free()
	await runner.get_tree().process_frame
	_done()


func _unreadable() -> void:
	_clean()
	SaveManager._ensure_dir()
	for path: String in [SaveManager.main_path(SaveManager.SAVE_ID), SaveManager.backup_path(SaveManager.SAVE_ID)]:
		var f: FileAccess = FileAccess.open(path, FileAccess.WRITE)
		f.store_string("{ this is not a save")
		f.close()
	eq(SaveManager.save_state(), "corrupt", "main and backup are unreadable")
	var game: GameRoot = await _game()
	await game.begin()
	check(game.loading_screen() == null, "no loading screen is left behind")
	var err: UIScreen = game.modals.screen(&"error")
	check(err != null, "an unreadable save shows the error popup")
	if err == null:
		game.queue_free()
		_done()
		return
	check(err.get_child(0) is ProceduralUIFactory.CozyBackdrop, "on the opening backdrop")
	check(err.find_child("TryAgain", true, false) is Button and err.find_child("StartNew", true, false) is Button, "with Try Again and Start a New Bakery")
	check(err.find_child("Close", true, false) == null, "and no close button")
	game.modals.back()
	check(game.modals.is_open(&"error"), "Back does not leave an empty screen")
	(err.find_child("TryAgain", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var err2: UIScreen = game.modals.screen(&"error")
	check(err2 != null and err2 != err, "Try Again reads the save again and explains again")
	if err2 != null:
		(err2.find_child("StartNew", true, false) as Button).pressed.emit()
		await runner.get_tree().process_frame
		var conf: UIScreen = game.modals.screen(&"confirm")
		check(conf != null, "starting over asks first")
		if conf != null:
			var yes: Callable = conf.params.get("on_yes")
			game.modals.close_screen(conf)
			yes.call()
		await runner.get_tree().process_frame
		check(game.modals.is_open(&"new_game"), "then the new bakery popup opens")
	# Hanya save tycoon: dianggap belum ada save.
	game.modals.close_all()
	_clean()
	_write_classic(SaveManager.SAVE_ID)
	await game.begin()
	check(game.modals.is_open(&"new_game") and not game.modals.is_open(&"error"), "a classic save alone opens the new bakery popup")
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	_done()
