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
		{"id": "ACC_33_MUSIC_SONGS", "name": "idle 20 no. 108 every music bed is a 16-bar bossa song (8 chords played as part A then part B, about 50 s at 11025 Hz) with a pentatonic melody that differs between A and B, the mood's percussion, loudness matched to the old beds and no clipping; the busy layer is exactly as long as the day bed so it stays on the beat", "fn": _music_songs},
		{"id": "ACC_33_AUDIO_CACHE", "name": "idle 20 no. 108 built sounds are kept in a disk cache stamped with the generator source hash: written a little per frame through a temp file, read back bit for bit, a damaged or old-stamp file is ignored and pruned, a cached bed starts at once without a build job (a background prewarm reads one cached file per frame), and SOURCE_HASH matches the generator sources", "fn": _audio_cache},
		{"id": "ACC_33_PITCH_JITTER", "name": "idle 20 no. 108 sounds that repeat often (taps, coins, footsteps, the door bell) play at a slightly different pitch each time, within the catalog's pitch_jitter; other sounds keep their pitch", "fn": _pitch_jitter},
		{"id": "ACC_33_AUDIO_TAIL_PAD", "name": "idle 20 no. 66 every sound carries spare samples past its end (a copy of its start when it loops, silence otherwise), so the Android mixer never reads past the buffer", "fn": _audio_tail_pad},
		{"id": "TEST_UI_LOADING_STAGES", "name": "89.5/114 new game and load show staged text and a forward-only bar, keep the clock still, and fade after the world is drawn", "fn": _loading_stages},
		{"id": "ACC_12_ORIENTATION_HINT", "name": "idle 12.0.6 a phone browser held sideways gets a one-time 'Turn your phone upright' hint that blocks and pauses nothing and goes away after 4 s; upright phones and desktops get none", "fn": _orientation_hint},
		{"id": "TEST_UI_SPLASH_TAP", "name": "12.1 Tap to Start reacts when the finger lifts, which browsers need to allow full screen", "fn": _splash_tap},
	]


func _music_build() -> void:
	check(MusicBuild.for_generator("tap_soft") == null, "short sounds are not music jobs")
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


func _audio_tail_pad() -> void:
	var pad: int = AudioGenerator.TAIL_PAD
	check(pad >= 8, "at least 8 spare samples, more than the mixer's interpolation reads ahead")
	var bad: Array[String] = []
	var loops: int = 0
	var ids: Array[StringName] = AudioManager.short_sound_ids()
	for id: StringName in ids:
		var gen: String = String(DataRegistry.audio_event(id).generator)
		var s: AudioStreamWAV = AudioGenerator.build(gen)
		var n: int = s.data.size() / 2 - pad
		if s.loop_mode == AudioStreamWAV.LOOP_FORWARD:
			loops += 1
			if s.loop_end != n:
				bad.append("%s loop_end %d, samples %d" % [gen, s.loop_end, n])
				continue
		for k in pad:
			var want: int = s.data.decode_s16(k * 2) if s.loop_mode == AudioStreamWAV.LOOP_FORWARD else 0
			if s.data.decode_s16((n + k) * 2) != want:
				bad.append("%s spare sample %d" % [gen, k])
				break
	check(ids.size() > 20 and loops >= 3, "checked %d sounds, %d of them loops" % [ids.size(), loops])
	check(bad.is_empty(), "spare samples in place: %s" % ", ".join(bad))
	var bed: AudioStreamWAV = AudioGenerator.build("music_morning")
	eq(bed.data.size(), (bed.loop_end + pad) * 2, "the music bed has the same spare samples")
	var same: bool = true
	for k in pad:
		same = same and bed.data.decode_s16((bed.loop_end + k) * 2) == bed.data.decode_s16(k * 2)
	check(same, "and they repeat its start, so the loop joins without a click")


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
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.open_new_game()
	await runner.get_tree().process_frame
	# Bed pagi belum ada: tahap musik harus merakitnya dengan bar yang bergerak.
	AudioManager._streams.erase(MusicBuild.cache_key("music_morning"))
	AudioManager._drop_job(MusicBuild.cache_key("music_morning"))
	game.start_new_game(&"profile_1", "female", "Loading Bakery")
	var rec: Dictionary = await _record_loading(game)
	eq(rec["stages"], _texts(NEW_GAME_STAGES), "new game walks through the loading stages in order")
	check(bool(rec["forward"]), "the bar never moves backwards")
	check(int(rec["music_frames"]) >= 3, "the radio stage kept the bar moving over several frames (%d)" % int(rec["music_frames"]))
	check(bool(rec["still"]), "the clock stays still and the game is not running while loading")
	near(float(rec["last"]), 1.0, 0.0001, "the bar is full at the end")
	check(game.playing and game.loading_screen() == null, "play starts once the overlay fades")
	check(AudioManager.is_stream_ready(&"shop_music_morning") and AudioManager.is_stream_ready(&"shop_ambience_room"),
		"today's music and ambience were prepared behind the overlay")
	near(game.sim.time.time_seconds, DataRegistry.idlef("clock.start_seconds"), 0.001, "a new game starts at 08:00 sharp (GDD idle 3.1)")
	check(not AudioManager._ambient.is_empty(), "the shop ambience plays in the game")
	# Muat save (Tap to Start dengan save): tahap bacaan save lebih dulu.
	game.end_session()
	await runner.get_tree().process_frame
	check(AudioManager._ambient.is_empty(), "once the session ends the shop ambience stops (GDD 33.1)")
	game.load_profile(&"profile_1")
	var rec2: Dictionary = await _record_loading(game)
	eq(rec2["stages"], _texts(LOAD_STAGES), "loading a save walks through its stages in order")
	check(bool(rec2["forward"]) and game.playing, "the bar moves forward and play resumes")
	# Slot kosong: overlay hilang dan layar galat muncul.
	game.end_session()
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


func _orientation_hint() -> void:
	SaveManager.dir = "user://test_saves_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	PauseManager.clear_all()
	# Desktop: tidak ada petunjuk orientasi.
	var desk: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(desk)
	await runner.get_tree().process_frame
	check(desk.find_child("OrientationHint", true, false) == null, "desktop browsers and apps get no orientation hint")
	desk.queue_free()
	await runner.get_tree().process_frame
	# HP tegak: tidak ada petunjuk dan tidak ada pause.
	WebPlatform.force_mobile_web = true
	WebPlatform.forced_portrait = 1
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	var hint: OrientationHint = game.find_child("OrientationHint", true, false) as OrientationHint
	check(hint != null, "phone browsers get the orientation hint layer")
	if hint == null:
		WebPlatform.force_mobile_web = false
		WebPlatform.forced_portrait = -1
		game.queue_free()
		return
	for i in 5:
		await runner.get_tree().process_frame
	check(not hint.is_showing() and not hint.was_shown(), "an upright phone gets no hint")
	check(not PauseManager.is_paused(), "and nothing is paused")
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Phone Bakery")
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.lifecycle_enabled = false
	# Dimiringkan: petunjuk sekali, tanpa pause; game tetap jalan di bingkai potret.
	WebPlatform.forced_portrait = 0
	await runner.get_tree().process_frame
	check(hint.is_showing(), "held sideways: the hint shows")
	check(not PauseManager.is_paused(), "the hint never pauses the game")
	var t0: float = game.sim.time.time_seconds
	for i2 in 10:
		await runner.get_tree().process_frame
	check(game.sim.time.time_seconds > t0, "the day keeps running under the hint")
	hint._process(OrientationHint.SHOW_SECONDS + 0.1)
	check(not hint.is_showing(), "it goes away by itself after 4 s")
	# Tegak lalu miring lagi: tidak muncul untuk kedua kalinya.
	WebPlatform.forced_portrait = 1
	await runner.get_tree().process_frame
	WebPlatform.forced_portrait = 0
	for i3 in 3:
		await runner.get_tree().process_frame
	check(not hint.is_showing(), "only once per session")
	WebPlatform.force_mobile_web = false
	WebPlatform.forced_portrait = -1
	game.end_session()
	await runner.get_tree().process_frame
	game.queue_free()
	await runner.get_tree().process_frame
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"


func _splash_tap() -> void:
	var was_unlocked: bool = AudioManager.unlocked
	# Ketukan memuat save atau membuka popup toko baru: jangan sentuh save pemain.
	SaveManager.dir = "user://test_saves_splash"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	var layer: CanvasLayer = game._splash.get_parent() as CanvasLayer
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	game._on_splash_input(press, layer)
	check(game._splash != null and not game.modals.is_open(&"new_game"), "pressing down alone does not start")
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	game._on_splash_input(release, layer)
	check(game._splash == null and game.modals.is_open(&"new_game"), "lifting the finger starts: without a save, the new bakery popup opens")
	check(AudioManager.unlocked, "the same tap unlocks audio (GDD 33.4)")
	game._on_splash_input(release, layer)
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"new_game") and game.modals.top().screen_id == &"new_game", "a duplicate release does nothing more")
	game.queue_free()
	await runner.get_tree().process_frame
	AudioManager.set_music_state(&"")
	AudioManager.unlocked = was_unlocked
	SaveManager.dir = "user://saves"


func _music_songs() -> void:
	var day_len: int = -1
	for mood: String in SongBuild.MOODS.keys():
		var cfg: Dictionary = SongBuild.MOODS[mood]
		var b := SongBuild.new()
		b.setup_song(mood)
		var lead: int = int(cfg["lead"])
		var melody_a: Array = []
		var melody_b: Array = []
		var root: int = int(cfg["root"])
		var off_scale: int = 0
		for pl: Dictionary in b._top_places:
			var r: Dictionary = b._renders[int(pl["slot"])]
			if int(r["inst"]) != lead:
				continue
			var semi: int = int(round(12.0 * log(float(r["freq"]) / AudioGenerator.MUSIC_ROOT_HZ) / log(2.0)))
			var deg: int = posmod(semi - root, 12)
			if not SongBuild.PENTATONIC.has(deg):
				# Nada akor di luar pentatonik hanya boleh di ketukan kuat (pendaratan).
				off_scale += 1
			if int(pl["at"]) < b._n / 2:
				melody_a.append([int(pl["at"]), semi])
			else:
				melody_b.append([int(pl["at"]) - b._n / 2, semi])
		check(melody_a.size() >= 8 and melody_b.size() >= 8, "%s has a melody in both parts (%d + %d notes)" % [mood, melody_a.size(), melody_b.size()])
		check(melody_a != melody_b, "%s: part B's melody is not a copy of part A" % mood)
		check(off_scale * 4 <= melody_a.size() + melody_b.size(), "%s: the melody stays mostly pentatonic (%d off-scale landings)" % [mood, off_scale])
		var s2: AudioStreamWAV = b.finish_now()
		var n: int = s2.loop_end
		var secs: float = float(n) / float(s2.mix_rate)
		eq(s2.mix_rate, SongBuild.RATE, "%s renders at %d Hz" % [mood, SongBuild.RATE])
		check(secs > 40.0 and secs < 70.0, "%s is a long loop (%.1f s; the old beds were ~7 s)" % [mood, secs])
		var d: PackedByteArray = s2.data
		var sq: float = 0.0
		var pk: float = 0.0
		for i in n:
			var v: float = float(d.decode_s16(i * 2)) / 32767.0
			sq += v * v
			pk = maxf(pk, absf(v))
		var rms: float = sqrt(sq / float(n))
		near(rms, float(cfg["rms"]), float(cfg["rms"]) * 0.25, "%s keeps the old loudness (RMS %.3f)" % [mood, rms])
		check(pk <= 0.96, "%s never clips (peak %.3f)" % [mood, pk])
		if mood == "cozy":
			day_len = n
	var busy: AudioStreamWAV = AudioGenerator.build("music_busy_layer")
	eq(busy.loop_end, day_len, "the busy layer is exactly as long as the day bed")
	eq(busy.mix_rate, SongBuild.RATE, "and plays at the same rate")


func _audio_cache() -> void:
	eq(AudioCache.SOURCE_HASH, AudioCache.source_hash(),
		"AudioCache.SOURCE_HASH matches the generator sources (update it whenever a recipe changes, so old caches are dropped)")
	var was_enabled: bool = AudioCache.enabled
	var was_dir: String = AudioCache.dir
	AudioCache.dir = "user://test_audio_cache"
	AudioCache.enabled = true
	AudioCache.clear()
	# Satu bunyi UI (22050 Hz), satu ambience (11025 Hz, loop), satu bed musik.
	for gen: String in ["tap_soft", "room_tone", "music_busy_layer"]:
		var built: AudioStreamWAV = AudioGenerator.build(gen)
		var key: String = MusicBuild.cache_key(gen)
		AudioCache.store(key, built)
		var steps: int = 0
		while AudioCache.flush_step(4096):
			steps += 1
			if steps == 1:
				check(not FileAccess.file_exists(AudioCache.path_for(key)), "%s: nothing final before the last write" % gen)
		check(gen != "music_busy_layer" or steps > 10, "%s is written over many frames (%d)" % [gen, steps])
		var back: AudioStreamWAV = AudioCache.fetch(key)
		check(back != null and back.data == built.data, "%s reads back bit for bit" % gen)
		if back != null:
			eq([back.mix_rate, back.loop_mode, back.loop_end], [built.mix_rate, built.loop_mode, built.loop_end], "%s keeps rate and loop" % gen)
	# Berkas rusak diabaikan.
	var bad: String = AudioCache.path_for("tap_soft")
	var f: FileAccess = FileAccess.open(bad, FileAccess.WRITE)
	f.store_buffer(PackedByteArray([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17]))
	f.close()
	check(AudioCache.fetch("tap_soft") == null, "a damaged file is ignored")
	# Berkas cap lama dibuang saat cache pertama dipakai.
	var old: String = AudioCache.dir.path_join("room_tone.oldstamp_1.pcm")
	var f2: FileAccess = FileAccess.open(old, FileAccess.WRITE)
	f2.store_buffer(PackedByteArray([0]))
	f2.close()
	AudioCache._pruned = false
	AudioCache.fetch("room_tone")
	check(not FileAccess.file_exists(old), "files with an old stamp are pruned")
	check(AudioCache.fetch("room_tone") != null, "current files stay")
	# AudioManager: bed dari cache langsung siap, tanpa pekerjaan perakitan.
	var was_unlocked: bool = AudioManager.unlocked
	AudioManager.unlocked = true
	AudioManager.set_music_state(&"")
	AudioManager._streams.erase(MusicBuild.cache_key("music_busy_layer"))
	AudioManager.request_stream(&"shop_music_busy_layer", true)
	check(AudioManager.is_stream_ready(&"shop_music_busy_layer") and not AudioManager.has_pending_jobs(), "a cached bed is ready at once, with no build job")
	AudioManager._streams.erase(MusicBuild.cache_key("music_busy_layer"))
	# Prewarm di latar: dibaca dari cache satu berkas per frame, bukan semua sekaligus.
	AudioManager.request_stream(&"shop_music_busy_layer", false)
	check(not AudioManager.is_stream_ready(&"shop_music_busy_layer") and AudioManager._cache_loads.size() == 1, "a background prewarm queues the cached bed")
	AudioManager._cache_load_step()
	check(AudioManager.is_stream_ready(&"shop_music_busy_layer") and not AudioManager.has_pending_jobs(), "and reads it on a later frame, still without building")
	AudioManager._streams.erase(MusicBuild.cache_key("music_busy_layer"))
	AudioManager.set_music_state(&"")
	AudioManager.unlocked = was_unlocked
	AudioCache.clear()
	AudioCache.enabled = was_enabled
	AudioCache.dir = was_dir


func _pitch_jitter() -> void:
	var was_unlocked: bool = AudioManager.unlocked
	AudioManager.unlocked = true
	var jit: Array[StringName] = []
	for x: Variant in DataRegistry.audio_events():
		var d: MiscDefinitions.AudioEventDefinition = x
		if d.pitch_jitter > 0.0:
			jit.append(d.id)
	for must: StringName in [&"ui_tap_soft", &"cashier_coin", &"footstep_tile", &"door_bell_enter"]:
		check(jit.has(must), "%s varies its pitch" % must)
	var pitches: Dictionary = {}
	var inside: bool = true
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(&"cashier_coin")
	for i in 12:
		AudioManager._last_played.erase(&"cashier_coin")
		AudioManager.play(&"cashier_coin")
		for k in AudioManager._sfx.size():
			if AudioManager._sfx_meta[k]["event"] == &"cashier_coin" and AudioManager._sfx[k].playing:
				var ps: float = AudioManager._sfx[k].pitch_scale
				pitches[snappedf(ps, 0.0001)] = true
				inside = inside and absf(ps - 1.0) <= def.pitch_jitter + 0.0001
		AudioManager.stop_all_sounds()
	check(pitches.size() >= 3, "the coin sound comes at different pitches (%d)" % pitches.size())
	check(inside, "always within +/-%.0f%%" % (def.pitch_jitter * 100.0))
	AudioManager._last_played.erase(&"ui_error")
	AudioManager.play(&"ui_error")
	var steady: bool = true
	for k2 in AudioManager._sfx.size():
		if AudioManager._sfx_meta[k2]["event"] == &"ui_error":
			steady = steady and AudioManager._sfx[k2].pitch_scale == 1.0
	check(steady, "a sound without pitch_jitter keeps its pitch")
	AudioManager.stop_all_sounds()
	AudioManager.unlocked = was_unlocked
