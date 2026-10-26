extends Node
## Alat ukur loading sungguhan (GDD 89.5, 109, 114): game_root.tscn dijalankan, audio
## dibuka seperti ketukan Tap to Start, lalu game baru dimulai dari Main Menu
## dan lama setiap tahap loading dicetak (log BOOT GameRoot). `--menu=N` menunggu
## N detik di Main Menu dulu (pemain mengisi nama toko sementara musik dan bunyi
## dirakit di latar); bawaannya 0, kasus terburuk.
## Save ditulis ke user://probe_saves, bukan slot pemain.
## Desktop: godot --path . res://tools/loading_probe.tscn [-- --menu=5]
## Browser: arahkan run/main_scene ke scene ini sementara, ekspor Web (lihat CLAUDE.md).

const PROBE_DIR: String = "user://probe_saves"

var _game: GameRoot = null
var _next_report: int = 0
var _frames: int = 0


## Setiap 2 detik: tahap loading yang tampil, progresnya, dan frame per detik.
func _process(_delta: float) -> void:
	_frames += 1
	var now: int = Time.get_ticks_msec()
	if now < _next_report:
		return
	_next_report = now + 2000
	if _game != null and is_instance_valid(_game) and _game.loading_screen() != null:
		var ls: LoadingScreen = _game.loading_screen()
		print("LOADING_PROBE   t=%d ms stage '%s' %.0f%% fps %.1f" % [now, ls.stage_text(), ls.progress() * 100.0, float(_frames) / 2.0])
	_frames = 0


func _ready() -> void:
	var menu_wait: float = 0.0
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--menu="):
			menu_wait = float(a.get_slice("=", 1))
	var t0: int = Time.get_ticks_msec()
	print("LOADING_PROBE start (engine up %d ms)" % Time.get_ticks_msec())
	SaveManager.dir = PROBE_DIR
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	for ab: String in OS.get_cmdline_user_args():
		if ab == "--exp=bare" or ab == "--exp=bare_noaudio":
			if ab == "--exp=bare_noaudio":
				AudioManager.background_prewarm = false
				AudioManager.set_process(false)
			var tb: int = Time.get_ticks_msec()
			var nb: int = 0
			while Time.get_ticks_msec() - tb < 25000:
				await get_tree().process_frame
				if Time.get_ticks_msec() - tb >= nb:
					nb += 1000
					print("LOADING_PROBE exp %s alive %d ms jobs=%s backlog=%d" % [ab, Time.get_ticks_msec() - tb, AudioManager.has_pending_jobs(), AudioManager._sfx_backlog.size()])
			print("LOADING_PROBE done")
			return
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	_game = game
	add_child(game)
	await get_tree().process_frame
	var exp0: String = ""
	for a0: String in OS.get_cmdline_user_args():
		if a0.begins_with("--exp="):
			exp0 = a0.get_slice("=", 1)
	if exp0 == "idle" or exp0 == "menu_noprewarm" or exp0 == "menu_idle" or exp0 == "sfx_only" or exp0 == "music_only":
		await _idle_experiment(game, exp0)
		print("LOADING_PROBE done")
		return
	AudioManager.unlock()
	game.skip_splash_for_tests()
	game.show_main_menu()
	print("LOADING_PROBE main menu after %d ms" % (Time.get_ticks_msec() - t0))
	var waited: float = 0.0
	while waited < menu_wait:
		await get_tree().process_frame
		waited += get_process_delta_time()
	var t1: int = Time.get_ticks_msec()
	var exp: String = ""
	for a2: String in OS.get_cmdline_user_args():
		if a2.begins_with("--exp="):
			exp = a2.get_slice("=", 1)
	if exp != "":
		await _experiment(game, exp)
		print("LOADING_PROBE done")
		return
	if OS.get_cmdline_user_args().has("--steps") or OS.has_feature("web"):
		await _new_game_in_steps(game)
	else:
		await game.start_new_game(&"profile_1", "female", "Probe Bakery")
	while not game.playing:
		await get_tree().process_frame
	print("LOADING_PROBE new game playable after %d ms" % (Time.get_ticks_msec() - t1))
	for line: String in GameLogger.recent():
		if line.contains("loading "):
			print("LOADING_PROBE   ", line)
	# Beberapa detik permainan: frame terlama setelah loading.
	var worst: float = 0.0
	var tt: float = 0.0
	while tt < 4.0:
		await get_tree().process_frame
		var d: float = get_process_delta_time()
		worst = maxf(worst, d)
		tt += d
	print("LOADING_PROBE worst frame in the first 4 s of play: %.0f ms" % (worst * 1000.0))
	game.return_to_menu()
	game.queue_free()
	await get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	print("LOADING_PROBE done")
	get_tree().quit(0)


## GameRoot.start_new_game langkah demi langkah, dengan cetakan di antaranya:
## bila loading berhenti, langkah terakhir yang tercetak menunjukkan tempatnya.
func _new_game_in_steps(game: GameRoot) -> void:
	print("LOADING_PROBE step begin_loading")
	await game._begin_loading("ui_loading", 0.05)
	print("LOADING_PROBE step teardown")
	game._teardown()
	print("LOADING_PROBE step sim")
	game.sim = SimulationRoot.new()
	game.add_child(game.sim)
	game.sim.start_new_game(&"profile_1", "Probe Bakery", "female", 12345)
	print("LOADING_PROBE step stage save")
	await game._loading_stage("ui_loading_save", 0.20)
	print("LOADING_PROBE step write_profile")
	SaveManager.write_profile(&"profile_1", game.sim.capture_save())
	print("LOADING_PROBE step enter_gameplay")
	await game._enter_gameplay(&"profile_1")
	print("LOADING_PROBE step done")


## Bisect masalah loading di browser: cetak setiap frame sesudah satu langkah.
func _experiment(game: GameRoot, exp: String) -> void:
	print("LOADING_PROBE exp ", exp)
	if exp == "sim_only" or exp == "sim_steps":
		var s := SimulationRoot.new()
		print("LOADING_PROBE exp sim new")
		add_child(s)
		print("LOADING_PROBE exp sim in tree")
		await _frames_print(3, "after add_child")
		if exp == "sim_steps":
			s.rng.master_seed = 12345
			for m: SimManager in s._managers:
				m.new_game()
				print("LOADING_PROBE exp new_game ", m.name)
				await _frames_print(1, String(m.name))
			s._create_starter_equipment()
			print("LOADING_PROBE exp starter equipment")
			await _frames_print(2, "starter")
			s.queue.build_from_location()
			s.player.place_at_start()
			await _frames_print(2, "queue+player")
			s._begin_day(true)
			print("LOADING_PROBE exp begin_day")
			await _frames_print(3, "begin_day")
		else:
			s.start_new_game(&"profile_1", "Probe Bakery", "female", 12345)
			print("LOADING_PROBE exp started")
			await _frames_print(5, "after start")
	elif exp == "loader_only":
		await game._begin_loading("ui_loading", 0.05)
		await game._loading_stage("ui_loading_save", 0.20)
		await _frames_print(5, "loader")


func _frames_print(n: int, label: String) -> void:
	for i in n:
		await get_tree().process_frame
		print("LOADING_PROBE exp frame %d %s" % [i, label])


## Tanpa loading: apakah frame terus berjalan bila Main Menu / perakitan audio
## di latar aktif? Mencetak tiap detik selama 25 detik.
func _idle_experiment(game: GameRoot, exp: String) -> void:
	print("LOADING_PROBE exp ", exp)
	game.skip_splash_for_tests()
	if exp == "menu_noprewarm":
		AudioManager.background_prewarm = false
		game.show_main_menu()
	elif exp == "menu_idle":
		game.show_main_menu()
	elif exp == "sfx_only":
		AudioManager.prewarm_short_sounds()
	elif exp == "music_only":
		AudioManager.prewarm_music([&"menu_music", &"shop_music_morning"])
	var t0: int = Time.get_ticks_msec()
	var next: int = 0
	while Time.get_ticks_msec() - t0 < 25000:
		await get_tree().process_frame
		var el: int = Time.get_ticks_msec() - t0
		if el >= next:
			next += 1000
			print("LOADING_PROBE exp %s alive %d ms jobs=%s sfx_backlog=%d" % [exp, el, AudioManager.has_pending_jobs(), AudioManager._sfx_backlog.size()])
