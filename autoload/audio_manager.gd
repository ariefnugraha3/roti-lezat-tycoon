extends Node
## AudioManager — pemutaran, pooling, prioritas & ducking (GDD 33, 35.2, 93, 129,
## 131.3). Tidak memiliki state gameplay; hanya menerjemahkan event ID menjadi
## bunyi yang dibangkitkan AudioGenerator.
##
## Kebijakan web (GDD 33.4): tidak ada bunyi sebelum `unlock()` dipanggil dari
## gestur pertama pemain di layar "Tap to Start".
##
## Musik tidak pernah dibangun sekaligus di tengah permainan: satu bed musik
## menahan layar hampir satu detik di PC dan beberapa detik di browser HP. Bed
## dirakit SongBuild sedikit demi sedikit di sela frame (GDD 91, 114). Selama bed
## baru belum jadi, bed lama terus berputar, lalu berpindah dengan crossfade.
##
## Setiap bunyi yang selesai dirakit disimpan di AudioCache (Seksi 20 no. 108):
## peluncuran berikutnya membaca berkasnya alih-alih menyintesis ulang.

signal caption_requested(key: String)

const BUSES: Array[String] = ["Music", "SFX", "UI", "Ambient"]
const MUSIC_FOR_STATE: Dictionary = {
	&"MENU": &"menu_music",
	&"MORNING_PREP": &"shop_music_morning",
	&"STORE_OPEN_CALM": &"shop_music_day",
	&"STORE_OPEN_BUSY": &"shop_music_day",
	&"RAIN": &"shop_music_rain",
	&"NIGHT": &"shop_music_after_hours",
}
const CAPTIONS: Dictionary = {
	&"oven_done": "caption_oven_ding",
	&"rotifood_incoming": "caption_order_arrived",
	&"customer_leave_angry": "caption_customer_upset",
	&"door_bell_enter": "caption_door_bell",
}
const DUCK_DB: float = -7.0
const DUCK_SECONDS: float = 0.6
const MUSIC_FADE: float = 1.2
## Anggaran pembangkit musik per frame (mikrodetik): prewarm di latar dan musik
## yang sedang ditunggu pemain.
const JOB_BUDGET_USEC: int = 4000
const JOB_URGENT_BUDGET_USEC: int = 10000
## Anggaran perakitan bunyi pendek di latar menu per frame: bunyi yang sudah
## ada di cache dibaca beberapa sekaligus, yang harus dirakit satu per frame.
const SFX_PREWARM_BUDGET_USEC: int = 6000

## Stream audio_rng milik RNGManager profil aktif (GDD 116). Null di menu.
var rng_source: RandomNumberGenerator = null

var unlocked: bool = false
## Senyap selama iklan berhadiah (Monetization).
var ad_muted: bool = false
var music_state: StringName = &""

var _streams: Dictionary = {}
var _sfx: Array[AudioStreamPlayer] = []
var _sfx_meta: Array[Dictionary] = []
var _music: Array[AudioStreamPlayer] = []
var _music_active: int = 0
var _busy_layer: AudioStreamPlayer = null
var _ambient: Dictionary = {}
var _loops: Dictionary = {}
var _loop_refs: Dictionary = {}
var _last_played: Dictionary = {}
var _duck_left: float = 0.0
var _local_rng := RandomNumberGenerator.new()
var _focus_muted: bool = false
## Prewarm musik di latar; mati di headless (tidak ada suara yang diputar).
var background_prewarm: bool = true
## Kunci cache -> MusicBuild yang belum selesai, dan urutan kerjanya.
var _jobs: Dictionary = {}
var _job_order: Array[String] = []
var _urgent: Dictionary = {}
## Event musik yang sedang terdengar di pemutar aktif.
var _music_playing: StringName = &""
## Musik/lapisan ramai menunggu bed-nya selesai dirakit.
var _pending_music: bool = false
## Bunyi pendek yang dirakit di latar selama layar menu, satu per frame setelah
## musik yang ditunggu siap (GDD 33.6). Kosong selama gameplay.
var _sfx_backlog: Array[StringName] = []
var _pending_busy: bool = false
## Volume dasar bus Music (dB) dan apakah sedang di-duck; bus hanya disetel
## saat salah satunya berubah, bukan setiap frame.
var _music_base_db: float = 0.0
var _music_bus_db: float = 999.0
## Bed dari cache yang dibaca di latar, satu berkas per frame: [kunci, event].
var _cache_loads: Array[Array] = []


func _ready() -> void:
	_local_rng.seed = 7331
	background_prewarm = DisplayServer.get_name() != "headless"
	_ensure_buses()
	_music_base_db = linear_to_db(maxf(0.001, float(SettingsManager.get_int("music_volume")) / 100.0))
	var voices: int = int(DataRegistry.bal("limits.sfx_voices")) if DataRegistry.is_valid() else 24
	for i in voices:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx.append(p)
		_sfx_meta.append({"priority": 9, "event": &""})
	for i2 in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		m.volume_db = -80.0
		add_child(m)
		_music.append(m)
	_busy_layer = AudioStreamPlayer.new()
	_busy_layer.bus = "Music"
	_busy_layer.volume_db = -80.0
	add_child(_busy_layer)
	SettingsManager.settings_changed.connect(_on_settings_changed)
	EventBus.sfx.connect(func(event_id: StringName, _floor: StringName) -> void: play(event_id))
	# Getar HP ikut suara umpan balik yang sama (v3.1 75.4, GDD idle 20 no. 55).
	EventBus.sfx.connect(Haptics.on_sfx)
	EventBus.music_state_changed.connect(set_music_state)
	apply_volumes()


## Bus ditambah lewat set_bus_count, bukan add_bus(). Di Web (playback Sample,
## Godot 4.7.2) add_bus() menyisipkan bus JavaScript di depan Master, sehingga
## urutannya tidak lagi cocok dengan AudioServer; set_bus_send lalu menyambung
## keluaran Master ke bus lain, dan lingkaran itu dibungkam Web Audio (tanpa suara).
func _ensure_buses() -> void:
	for b: String in BUSES:
		if AudioServer.get_bus_index(b) == -1:
			var idx: int = AudioServer.bus_count
			AudioServer.set_bus_count(idx + 1)
			AudioServer.set_bus_name(idx, b)
			AudioServer.set_bus_send(idx, "Master")


func apply_volumes() -> void:
	_set_bus("Master", SettingsManager.get_int("master_volume"))
	_set_bus("Music", SettingsManager.get_int("music_volume"))
	_set_bus("SFX", SettingsManager.get_int("sfx_volume"))
	_set_bus("UI", SettingsManager.get_int("ui_volume"))
	_set_bus("Ambient", SettingsManager.get_int("ambient_volume"))
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _focus_muted or ad_muted)


## Iklan berhadiah sedang tayang (GDD idle 22.1): seluruh game senyap.
func set_ad_muted(on: bool) -> void:
	if ad_muted == on:
		return
	ad_muted = on
	apply_volumes()


func _set_bus(bus_name: String, percent: int) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	if percent <= 0:
		AudioServer.set_bus_mute(idx, true)
		return
	AudioServer.set_bus_mute(idx, false)
	AudioServer.set_bus_volume_db(idx, linear_to_db(float(percent) / 100.0))


func _on_settings_changed(_key: String) -> void:
	apply_volumes()
	_music_base_db = linear_to_db(maxf(0.001, float(SettingsManager.get_int("music_volume")) / 100.0))
	_music_bus_db = 999.0


## Dipanggil sekali dari gestur pertama (GDD 12.1, 33.4).
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	if music_state != &"":
		var s: StringName = music_state
		music_state = &""
		set_music_state(s)


## Stream untuk event, dibangun sekarang juga bila belum ada (bunyi pendek, atau
## musik yang memang harus ada saat itu). Bed musik yang identik berbagi stream.
func stream_for(event_id: StringName) -> AudioStream:
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
	if def == null:
		GameLogger.warn_once("audio_" + String(event_id), "AUDIO", "unknown audio event %s" % event_id)
		return null
	var key: String = MusicBuild.cache_key(String(def.generator))
	if not _streams.has(key):
		var cached: AudioStreamWAV = AudioCache.fetch(key)
		if cached != null:
			_drop_job(key)
			_streams[key] = cached
			return cached
		var job: MusicBuild = _jobs.get(key)
		var s: AudioStreamWAV = job.finish_now() if job != null else AudioGenerator.build(String(def.generator))
		_drop_job(key)
		if s == null:
			GameLogger.warn_once("audiogen_" + key, "AUDIO", "generator %s failed" % def.generator)
			return null
		_streams[key] = s
		AudioCache.store(key, s)
	return _streams[key]


## Semua event bunyi yang bukan bed musik, satu per resep generator (bunyi yang
## berbagi resep cukup dirakit sekali). Urut sesuai katalog.
func short_sound_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	var seen: Dictionary = {}
	for x: Variant in DataRegistry.audio_events():
		var def: MiscDefinitions.AudioEventDefinition = x
		var key: String = MusicBuild.cache_key(String(def.generator))
		if MusicBuild.mood_of(String(def.generator)) != "" or seen.has(key):
			continue
		seen[key] = true
		out.append(def.id)
	return out


## Rakit semua bunyi pendek di latar selama layar menu, satu per frame, supaya
## layar loading tidak perlu menunggunya lagi. Dimatikan saat gameplay dimulai.
func prewarm_short_sounds() -> void:
	_sfx_backlog.clear()
	if not background_prewarm:
		return
	for id: StringName in short_sound_ids():
		if not is_stream_ready(id):
			_sfx_backlog.append(id)


func stop_short_sound_prewarm() -> void:
	_sfx_backlog.clear()


func is_stream_ready(event_id: StringName) -> bool:
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
	return def != null and _streams.has(MusicBuild.cache_key(String(def.generator)))


## Kemajuan perakitan stream (0..1; 1 = siap).
func stream_progress(event_id: StringName) -> float:
	if is_stream_ready(event_id):
		return 1.0
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
	if def == null:
		return 0.0
	var job: MusicBuild = _jobs.get(MusicBuild.cache_key(String(def.generator)))
	return job.progress() if job != null else 0.0


## Minta stream disiapkan. Musik masuk antrean perakitan bertahap (`urgent` =
## di depan antrean, anggaran lebih besar); bunyi pendek langsung dibangun.
func request_stream(event_id: StringName, urgent: bool = false) -> void:
	if is_stream_ready(event_id):
		return
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
	if def == null:
		return
	var key: String = MusicBuild.cache_key(String(def.generator))
	if not _jobs.has(key):
		# Sudah dirakit di sesi sebelumnya: dari cache. Yang mendesak dibaca
		# sekarang; prewarm di latar dibaca satu berkas per frame (beberapa bed
		# 1 MB sekaligus bisa menahan frame di HP).
		if AudioCache.has(key):
			if not urgent:
				for q: Array in _cache_loads:
					if q[0] == key:
						return
				_cache_loads.append([key, event_id])
				return
			var cached: AudioStreamWAV = AudioCache.fetch(key)
			if cached != null:
				_streams[key] = cached
				_on_stream_ready()
				return
			AudioCache.drop(key)
		var job: MusicBuild = MusicBuild.for_generator(String(def.generator))
		if job == null:
			stream_for(event_id)
			return
		_jobs[key] = job
		_job_order.append(key)
	if urgent and not _urgent.has(key):
		_urgent[key] = true
		_job_order.erase(key)
		_job_order.push_front(key)


## Siapkan musik di latar (menu, pagi, siang...) supaya tidak ada yang ditunggu nanti.
func prewarm_music(event_ids: Array) -> void:
	if not background_prewarm:
		return
	for id: Variant in event_ids:
		request_stream(StringName(str(id)), false)


func has_pending_jobs() -> bool:
	return not _job_order.is_empty() or not _cache_loads.is_empty()


## Kerjakan antrean perakitan sampai `budget_usec` habis (juga dipakai layar loading).
func step_jobs(budget_usec: int) -> void:
	var t0: int = Time.get_ticks_usec()
	while not _job_order.is_empty():
		var left: int = budget_usec - (Time.get_ticks_usec() - t0)
		if left <= 0:
			return
		var key: String = _job_order[0]
		var job: MusicBuild = _jobs[key]
		if not job.step(left):
			return
		_streams[key] = job.result
		AudioCache.store(key, job.result)
		_drop_job(key)
		_on_stream_ready()


func _drop_job(key: String) -> void:
	_jobs.erase(key)
	_job_order.erase(key)
	_urgent.erase(key)


## Bed yang ditunggu sudah jadi: musik atau lapisan ramai yang tertunda dimainkan.
func _on_stream_ready() -> void:
	if _pending_music:
		var want: StringName = MUSIC_FOR_STATE.get(music_state, &"")
		if want == &"" or is_stream_ready(want):
			_pending_music = false
			if want != _music_playing or not _music[_music_active].playing:
				_crossfade_to(want)
	if _pending_busy and is_stream_ready(&"shop_music_busy_layer"):
		_pending_busy = false
		_set_busy_layer(music_state == &"STORE_OPEN_BUSY")


func play(event_id: StringName) -> void:
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
	if def == null:
		return
	if SettingsManager.get_bool("sound_captions") and CAPTIONS.has(event_id):
		caption_requested.emit(str(CAPTIONS[event_id]))
	if not unlocked:
		return
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now - float(_last_played.get(event_id, -100.0)) < def.cooldown:
		return
	_last_played[event_id] = now
	var stream: AudioStream = stream_for(event_id)
	if stream == null:
		return
	var slot: int = _free_voice(def.priority)
	if slot < 0:
		return
	var p: AudioStreamPlayer = _sfx[slot]
	p.stop()
	p.stream = stream
	p.bus = String(def.bus) if def.bus != &"Music" else "SFX"
	p.volume_db = def.volume_db
	# Variasi nada kecil untuk bunyi yang sering berulang (katalog pitch_jitter),
	# supaya kasir dan langkah kaki yang ramai tidak terdengar seperti mesin.
	var pitch: float = 1.0
	if def.pitch_jitter > 0.0:
		var r: RandomNumberGenerator = rng_source if rng_source != null else _local_rng
		pitch = r.randf_range(1.0 - def.pitch_jitter, 1.0 + def.pitch_jitter)
	p.pitch_scale = pitch
	p.play()
	_sfx_meta[slot] = {"priority": def.priority, "event": event_id}
	if def.priority == 0:
		_duck_left = DUCK_SECONDS


## Voice bebas; bila penuh, rebut voice berprioritas paling rendah (GDD 129).
func _free_voice(priority: int) -> int:
	var worst: int = -1
	var worst_pri: int = -1
	for i in _sfx.size():
		if not _sfx[i].playing:
			return i
		var pr: int = int(_sfx_meta[i]["priority"])
		if pr > worst_pri:
			worst_pri = pr
			worst = i
	if worst >= 0 and worst_pri > priority:
		return worst
	return -1


## Loop berbasis refcount (mixer_loop/oven_loop): menyala selama ada pemakai.
func set_loop(event_id: StringName, owner_key: String, active: bool) -> void:
	var refs: Dictionary = _loop_refs.get(event_id, {})
	if active:
		refs[owner_key] = true
	else:
		refs.erase(owner_key)
	_loop_refs[event_id] = refs
	var should: bool = not refs.is_empty() and unlocked
	var p: AudioStreamPlayer = _loops.get(event_id)
	if should and p == null:
		var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
		var stream: AudioStream = stream_for(event_id)
		if def == null or stream == null:
			return
		p = AudioStreamPlayer.new()
		p.bus = String(def.bus)
		p.stream = stream
		p.volume_db = def.volume_db
		add_child(p)
		p.play()
		_loops[event_id] = p
	elif not should and p != null:
		p.stop()
		p.queue_free()
		_loops.erase(event_id)


## Hentikan bunyi pendek yang masih diputar (runner tes sebelum keluar: playback
## yang masih jalan saat shutdown dilaporkan sebagai objek bocor).
func stop_all_sounds() -> void:
	for p: AudioStreamPlayer in _sfx:
		p.stop()
	stop_all_loops()


func stop_all_loops() -> void:
	for k: Variant in _loops.keys():
		var p: AudioStreamPlayer = _loops[k]
		p.stop()
		p.queue_free()
	_loops.clear()
	_loop_refs.clear()


## Status musik (GDD 33.1). Maksimal dua voice musik + lapisan busy (GDD 129).
func set_music_state(state: StringName) -> void:
	if state == music_state:
		return
	music_state = state
	var new_music: StringName = MUSIC_FOR_STATE.get(state, &"")
	_set_busy_layer(state == &"STORE_OPEN_BUSY")
	if not unlocked:
		return
	if new_music == _music_playing and _music[_music_active].playing:
		_pending_music = false
		return
	# Bed baru belum jadi: bed lama terus berputar sampai SongBuild selesai
	# (bed dari cache langsung siap).
	if new_music != &"" and not is_stream_ready(new_music):
		request_stream(new_music, true)
		if not is_stream_ready(new_music):
			_pending_music = true
			return
	_pending_music = false
	_crossfade_to(new_music)


## Crossfade memakai kedua pemutar; layer ramai dihentikan agar tidak ada suara
## musik ketiga (GDD 129).
func _crossfade_to(new_music: StringName) -> void:
	if _busy_layer.playing:
		_busy_layer.stop()
	var from: AudioStreamPlayer = _music[_music_active]
	_music_active = 1 - _music_active
	var to: AudioStreamPlayer = _music[_music_active]
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(new_music)
	var stream: AudioStream = stream_for(new_music) if new_music != &"" else null
	_music_playing = new_music if stream != null else &""
	var tw := create_tween().set_parallel(true)
	tw.tween_property(from, "volume_db", -60.0, MUSIC_FADE)
	tw.chain().tween_callback(from.stop)
	if stream != null and def != null:
		to.stream = stream
		to.volume_db = -60.0
		to.play()
		var tw2 := create_tween()
		tw2.tween_property(to, "volume_db", def.volume_db, MUSIC_FADE)


func _set_busy_layer(on: bool) -> void:
	if not unlocked:
		return
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(&"shop_music_busy_layer")
	# Maks. suara musik (GDD 129): layer ramai hanya ditambahkan bila tidak ada
	# crossfade yang sedang memakai pemutar kedua.
	if on and _music_voices_playing() >= DataRegistry.bali("limits.music_voices"):
		return
	if not on:
		_pending_busy = false
	if on and not _busy_layer.playing:
		if not is_stream_ready(&"shop_music_busy_layer"):
			request_stream(&"shop_music_busy_layer", true)
			if not is_stream_ready(&"shop_music_busy_layer"):
				_pending_busy = true
				return
		_busy_layer.stream = stream_for(&"shop_music_busy_layer")
		_busy_layer.volume_db = -60.0
		# Sejajarkan ketuk dengan bed musik day yang sedang berputar.
		var pos: float = _music[_music_active].get_playback_position() if _music[_music_active].playing else 0.0
		_busy_layer.play(pos)
		create_tween().tween_property(_busy_layer, "volume_db", def.volume_db if def != null else -16.0, MUSIC_FADE)
	elif not on and _busy_layer.playing:
		var tw := create_tween()
		tw.tween_property(_busy_layer, "volume_db", -60.0, MUSIC_FADE)
		tw.tween_callback(_busy_layer.stop)


func _music_voices_playing() -> int:
	var n: int = 0
	for m: AudioStreamPlayer in _music:
		if m.playing:
			n += 1
	return n + (1 if _busy_layer.playing else 0)


## Ambience berlapis: daftar event loop yang harus aktif.
func set_ambience(event_ids: Array) -> void:
	for k: Variant in _ambient.keys():
		if not event_ids.has(k):
			var p: AudioStreamPlayer = _ambient[k]
			p.stop()
			p.queue_free()
			_ambient.erase(k)
	if not unlocked:
		return
	for id: Variant in event_ids:
		var eid: StringName = StringName(str(id))
		if _ambient.has(eid):
			continue
		var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(eid)
		var stream: AudioStream = stream_for(eid)
		if def == null or stream == null:
			continue
		var p2 := AudioStreamPlayer.new()
		p2.bus = "Ambient"
		p2.stream = stream
		p2.volume_db = def.volume_db
		add_child(p2)
		p2.play()
		_ambient[eid] = p2


func _process(delta: float) -> void:
	if not _cache_loads.is_empty():
		_cache_load_step()
	elif not _job_order.is_empty() and (background_prewarm or not _urgent.is_empty()):
		step_jobs(JOB_URGENT_BUDGET_USEC if not _urgent.is_empty() else JOB_BUDGET_USEC)
	elif not _sfx_backlog.is_empty():
		_prewarm_step()
	# Cache disk ditulis sedikit demi sedikit (tidak pernah menahan frame).
	AudioCache.flush_step()
	# Ducking (GDD 131.3): bus Music hanya disetel saat nilainya berubah.
	if _duck_left > 0.0:
		_duck_left = maxf(0.0, _duck_left - delta)
	var want: float = _music_base_db + (DUCK_DB if _duck_left > 0.0 else 0.0)
	if want != _music_bus_db and SettingsManager.get_int("music_volume") > 0:
		var idx: int = AudioServer.get_bus_index("Music")
		if idx >= 0:
			AudioServer.set_bus_volume_db(idx, want)
			_music_bus_db = want


## Satu bed dari cache per frame; berkas yang ternyata rusak dibuang lalu bed
## itu dirakit seperti biasa.
func _cache_load_step() -> void:
	var q: Array = _cache_loads.pop_front()
	var key: String = str(q[0])
	if _streams.has(key):
		return
	var cached: AudioStreamWAV = AudioCache.fetch(key)
	if cached != null:
		_streams[key] = cached
		_on_stream_ready()
		return
	AudioCache.drop(key)
	request_stream(StringName(q[1]), false)


## Bunyi pendek berikutnya dari antrean menu: yang ada di cache dibaca beberapa
## sekaligus sampai anggaran habis; yang harus dirakit satu saja per frame.
func _prewarm_step() -> void:
	var t0: int = Time.get_ticks_usec()
	while not _sfx_backlog.is_empty() and Time.get_ticks_usec() - t0 < SFX_PREWARM_BUDGET_USEC:
		var id: StringName = _sfx_backlog.pop_front()
		var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(id)
		var key: String = MusicBuild.cache_key(String(def.generator)) if def != null else ""
		var built: bool = def != null and not _streams.has(key) and not AudioCache.has(key)
		stream_for(id)
		if built:
			return


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED:
			if SettingsManager.get_bool("mute_when_unfocused"):
				_focus_muted = true
				apply_volumes()
		NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED:
			if _focus_muted:
				_focus_muted = false
				apply_volumes()
