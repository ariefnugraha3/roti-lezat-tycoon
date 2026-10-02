extends TestSuite
## Boot, loading, dan browser HP (keputusan maintainer 2026-09-30): layar loading
## bertahap (GDD 89.5, 114), musik yang dirakit sedikit demi sedikit (GDD 33, 91),
## layar "putar HP" di browser HP (GDD 12.5, 128.3), dan ketukan "Tap to Start"
## yang dihitung saat dilepas.

const NEW_GAME_STAGES: Array[String] = ["ui_loading", "ui_loading_save", "ui_loading_music", "ui_loading_world", "ui_loading_counter", "ui_loading_ovens"]
const LOAD_STAGES: Array[String] = ["ui_loading_read", "ui_loading", "ui_loading_music", "ui_loading_world", "ui_loading_counter", "ui_loading_ovens"]


func tests() -> Array:
	return [
		{"id": "ACC_33_MUSIC_BUILD", "name": "33 music beds are built in small slices with exactly the same result as building at once", "fn": _music_build},
		{"id": "ACC_33_MUSIC_NO_STALL", "name": "33 a music change never builds a bed on the spot: the old music plays until the new bed is ready", "fn": _music_no_stall},
		{"id": "TEST_UI_LOADING_STAGES", "name": "89.5/114 new game and load show staged text and a forward-only bar, keep the clock still, and fade after the world is drawn", "fn": _loading_stages},
		{"id": "ACC_12_ORIENTATION_GUARD", "name": "12.5 on a phone browser a portrait screen covers the game and pauses it until the phone turns sideways", "fn": _orientation_guard},
		{"id": "TEST_UI_SPLASH_TAP", "name": "12.1 Tap to Start reacts when the finger lifts, which browsers need to allow full screen", "fn": _splash_tap},
	]


func _music_build() -> void:
	check(MusicBuild.for_generator("tap_soft") == null, "short sounds are not music jobs")
	eq(MusicBuild.cache_key("bailout_cue"), MusicBuild.cache_key("music_after_hours"), "identical beds share one stream")
	var sliced: MusicBuild = MusicBuild.for_generator("music_morning")
	var steps: int = 0
	var last: float = -1.0
	var forward: bool = true
	while not sliced.is_done() and steps < 100000:
		sliced.step(0)
		steps += 1
		if sliced.progress() < last:
			forward = false
		last = sliced.progress()
	check(steps > 100, "the bed is built in many small steps (%d)" % steps)
	check(forward, "progress only moves forward")
	near(sliced.progress(), 1.0, 0.0001, "progress ends at 1")
	var whole: AudioStreamWAV = AudioGenerator.build("music_morning")
	check(sliced.result.data == whole.data, "slice by slice gives exactly the same sound as building at once")
	eq(sliced.result.loop_mode, AudioStreamWAV.LOOP_FORWARD, "the bed loops")
	eq(sliced.result.loop_end, whole.loop_end, "same loop length")


func _music_no_stall() -> void:
	var was_unlocked: bool = AudioManager.unlocked
	AudioManager.unlocked = true
	AudioManager.set_music_state(&"")
	AudioManager.stream_for(&"shop_music_morning")
	AudioManager.set_music_state(&"MORNING_PREP")
	eq(AudioManager._music_playing, &"shop_music_morning", "morning music plays")
	# Bed siang belum dirakit: pergantian tidak boleh membangunnya di tempat.
	AudioManager._streams.erase(MusicBuild.cache_key("music_day"))
	var t0: int = Time.get_ticks_usec()
	AudioManager.set_music_state(&"STORE_OPEN_CALM")
	var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	check(ms < 200.0, "switching music returns at once (%.1f ms; a whole bed takes ~800 ms)" % ms)
	check(not AudioManager.is_stream_ready(&"shop_music_day"), "the day bed is still being built")
	eq(AudioManager._music_playing, &"shop_music_morning", "the morning music keeps playing meanwhile")
	var guard: int = 0
	var progressed: bool = false
	while not AudioManager.is_stream_ready(&"shop_music_day") and guard < 100000:
		AudioManager.step_jobs(3000)
		progressed = progressed or AudioManager.stream_progress(&"shop_music_day") > 0.0
		guard += 1
	check(progressed and guard > 3, "the bed was assembled over several slices (%d)" % guard)
	eq(AudioManager._music_playing, &"shop_music_day", "then the day music takes over")
	check(not AudioManager.has_pending_jobs(), "nothing left in the queue")
	AudioManager.set_music_state(&"")
	AudioManager.unlocked = was_unlocked


func _loading_stages() -> void:
	SaveManager.dir = "user://test_saves_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var was_unlocked: bool = AudioManager.unlocked
	AudioManager.unlocked = true
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.show_main_menu()
	await runner.get_tree().process_frame
	# Bed pagi belum ada: tahap musik harus merakitnya dengan bar yang bergerak.
	AudioManager._streams.erase(MusicBuild.cache_key("music_morning"))
	AudioManager._drop_job(MusicBuild.cache_key("music_morning"))
	game.start_new_game(&"profile_1", "female", "Loading Bakery")
	var rec: Dictionary = await _record_loading(game)
	eq(rec["stages"], _texts(NEW_GAME_STAGES), "new game walks through the loading stages in order")
	check(bool(rec["forward"]), "the bar never moves backwards")
	check(int(rec["music_frames"]) >= 3, "the radio stage kept the bar moving over several frames (%d)" % int(rec["music_frames"]))
	check(bool(rec["still"]), "the clock stays at 05:00 and the game is not running while loading")
	near(float(rec["last"]), 1.0, 0.0001, "the bar is full at the end")
	check(game.playing and game.loading_screen() == null, "play starts once the overlay fades")
	check(AudioManager.is_stream_ready(&"shop_music_morning") and AudioManager.is_stream_ready(&"shop_ambience_room"),
		"today's music and ambience were prepared behind the overlay")
	near(game.sim.time.time_seconds, 5.0 * 3600.0, 0.001, "the day starts at 05:00 sharp")
	check(not AudioManager._ambient.is_empty(), "the shop ambience plays in the game")
	# Muat profil (Continue): tahap bacaan save lebih dulu.
	game.return_to_menu()
	await runner.get_tree().process_frame
	check(AudioManager._ambient.is_empty(), "back on the main menu the shop ambience stops; only the menu music plays (GDD 33.1)")
	game.load_profile(&"profile_1")
	var rec2: Dictionary = await _record_loading(game)
	eq(rec2["stages"], _texts(LOAD_STAGES), "loading a save walks through its stages in order")
	check(bool(rec2["forward"]) and game.playing, "the bar moves forward and play resumes")
	# Profil kosong: overlay hilang dan layar galat muncul.
	game.return_to_menu()
	await runner.get_tree().process_frame
	await game.load_profile(&"profile_3")
	check(game.loading_screen() == null, "no loading screen is left behind after a failed load")
	check(game.modals.is_open(&"error"), "a failed load shows the error screen")
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	AudioManager.set_music_state(&"")
	AudioManager.unlocked = was_unlocked
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"


## Rekam setiap frame selama layar loading tampil: teks tahap, bar, dan jam
## (jam simulasi baru tidak boleh bergerak dan permainan belum berjalan).
func _record_loading(game: GameRoot) -> Dictionary:
	var stages: PackedStringArray = PackedStringArray()
	var last: float = 0.0
	var forward: bool = true
	var still: bool = true
	var music_frames: int = 0
	var clock: float = -1.0
	var frames: int = 0
	while frames < 5000:
		var ld: LoadingScreen = game.loading_screen()
		if ld == null:
			break
		stages = ld.stages().duplicate()
		if ld.progress() < last:
			forward = false
		last = ld.progress()
		if ld.stage_text() == Tx.t("ui_loading_music"):
			music_frames += 1
		if game.playing:
			still = false
		if game.sim != null and is_instance_valid(game.sim) and game.world != null:
			if clock < 0.0:
				clock = game.sim.time.time_seconds
			elif not is_equal_approx(game.sim.time.time_seconds, clock):
				still = false
		await runner.get_tree().process_frame
		frames += 1
	var list: Array[String] = []
	for t: String in stages:
		list.append(t)
	return {"stages": list, "last": 1.0 if game.loading_screen() == null else last, "forward": forward,
		"still": still, "music_frames": music_frames}


static func _texts(keys: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for k: String in keys:
		out.append(Tx.t(k))
	return out


func _orientation_guard() -> void:
	SaveManager.dir = "user://test_saves_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	# Desktop: tidak ada penjaga orientasi.
	var desk: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(desk)
	await runner.get_tree().process_frame
	check(desk.find_child("OrientationGuard", true, false) == null, "desktop browsers and apps get no rotate screen")
	desk.queue_free()
	await runner.get_tree().process_frame
	WebPlatform.force_mobile_web = true
	WebPlatform.forced_portrait = 1
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	var guard: OrientationGuard = game.find_child("OrientationGuard", true, false) as OrientationGuard
	check(guard != null, "phone browsers get the rotate screen")
	await runner.get_tree().process_frame
	check(guard.is_blocking() and PauseManager.has(OrientationGuard.REASON), "portrait: the rotate screen covers everything and pauses")
	check(guard.layer > game.modals.layer, "it sits above menus and the loading screen")
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Phone Bakery")
	game.modals.close_all()
	game.sim.tutorial.skip()
	await runner.get_tree().process_frame
	check(PauseManager.is_paused(), "still paused in portrait after the game loads")
	var t0: float = game.sim.time.time_seconds
	for i in 30:
		await runner.get_tree().process_frame
	near(game.sim.time.time_seconds, t0, 0.0001, "the clock does not move while the phone is upright")
	WebPlatform.forced_portrait = 0
	await runner.get_tree().process_frame
	check(not guard.is_blocking() and not PauseManager.has(OrientationGuard.REASON), "landscape: the rotate screen goes away")
	for i2 in 30:
		await runner.get_tree().process_frame
	check(game.sim.time.time_seconds > t0, "and the day runs again")
	WebPlatform.forced_portrait = 1
	await runner.get_tree().process_frame
	check(guard.is_blocking() and PauseManager.is_paused(), "turning back to portrait pauses again")
	WebPlatform.force_mobile_web = false
	WebPlatform.forced_portrait = -1
	game.return_to_menu()
	await runner.get_tree().process_frame
	game.queue_free()
	await runner.get_tree().process_frame
	check(not PauseManager.has(OrientationGuard.REASON), "leaving the game drops its pause reason")
	PauseManager.clear_all()
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"


func _splash_tap() -> void:
	var was_unlocked: bool = AudioManager.unlocked
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	var layer: CanvasLayer = game._splash.get_parent() as CanvasLayer
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	game._on_splash_input(press, layer)
	check(game._splash != null and not game.modals.is_open(&"main_menu"), "pressing down alone does not start")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game._on_splash_input(release, layer)
	check(game._splash == null and game.modals.is_open(&"main_menu"), "lifting the finger opens the main menu")
	check(AudioManager.unlocked, "the same tap unlocks audio (GDD 33.4)")
	game._on_splash_input(release, layer)
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"main_menu"), "a duplicate release does nothing more")
	game.queue_free()
	await runner.get_tree().process_frame
	AudioManager.set_music_state(&"")
	AudioManager.unlocked = was_unlocked
