extends Node
## AudioManager — pemutaran, pooling, prioritas & ducking (GDD 33, 35.2, 93, 129,
## 131.3). Tidak memiliki state gameplay; hanya menerjemahkan event ID menjadi
## bunyi yang dibangkitkan AudioGenerator.
##
## Kebijakan web (GDD 33.4): tidak ada bunyi sebelum `unlock()` dipanggil dari
## gestur pertama pemain di layar "Tap to Start".

signal caption_requested(key: String)

const BUSES: Array[String] = ["Music", "SFX", "UI", "Ambient"]
const MUSIC_FOR_STATE: Dictionary = {
	&"MENU": &"menu_music",
	&"MORNING_PREP": &"shop_music_morning",
	&"STORE_OPEN_CALM": &"shop_music_day",
	&"STORE_OPEN_BUSY": &"shop_music_day",
	&"RAIN": &"shop_music_rain",
	&"DAILY_SUMMARY": &"shop_music_after_hours",
	&"BAILOUT_CUTSCENE": &"bailout_scene",
}
const CAPTIONS: Dictionary = {
	&"oven_done": "caption_oven_ding",
	&"rotifood_incoming": "caption_order_arrived",
	&"customer_leave_angry": "caption_customer_upset",
	&"oven_burn_warning": "caption_burn_warning",
	&"door_bell_enter": "caption_door_bell",
}
const DUCK_DB: float = -7.0
const DUCK_SECONDS: float = 0.6
const MUSIC_FADE: float = 1.2

## Stream audio_rng milik RNGManager profil aktif (GDD 116). Null di menu.
var rng_source: RandomNumberGenerator = null

var unlocked: bool = false
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


func _ready() -> void:
	_local_rng.seed = 7331
	_ensure_buses()
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
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), _focus_muted)


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


## Dipanggil sekali dari gestur pertama (GDD 12.1, 33.4).
func unlock() -> void:
	if unlocked:
		return
	unlocked = true
	if music_state != &"":
		var s: StringName = music_state
		music_state = &""
		set_music_state(s)


func stream_for(event_id: StringName) -> AudioStream:
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(event_id)
	if def == null:
		GameLogger.warn_once("audio_" + String(event_id), "AUDIO", "unknown audio event %s" % event_id)
		return null
	var key: String = String(def.generator)
	if not _streams.has(key):
		var s: AudioStreamWAV = AudioGenerator.build(key)
		if s == null:
			GameLogger.warn_once("audiogen_" + key, "AUDIO", "generator %s failed" % key)
			return null
		_streams[key] = s
	return _streams[key]


## Pra-bangkitkan stream (tahap warm-up loading, GDD 114 tahap 7).
func prewarm(event_ids: Array) -> void:
	for id: Variant in event_ids:
		stream_for(StringName(str(id)))


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
	var pitch: float = 1.0
	if event_id == &"footstep_tile" or event_id == &"cashier_coin":
		var r: RandomNumberGenerator = rng_source if rng_source != null else _local_rng
		pitch = r.randf_range(0.97, 1.03)
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
	var old_music: StringName = MUSIC_FOR_STATE.get(music_state, &"")
	music_state = state
	var new_music: StringName = MUSIC_FOR_STATE.get(state, &"")
	_set_busy_layer(state == &"STORE_OPEN_BUSY")
	if not unlocked:
		return
	if new_music == old_music and _music[_music_active].playing:
		return
	# Crossfade memakai kedua pemutar; layer ramai dihentikan agar tidak ada suara
	# musik ketiga (GDD 129).
	if _busy_layer.playing:
		_busy_layer.stop()
	var from: AudioStreamPlayer = _music[_music_active]
	_music_active = 1 - _music_active
	var to: AudioStreamPlayer = _music[_music_active]
	var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(new_music)
	var stream: AudioStream = stream_for(new_music) if new_music != &"" else null
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
	if on and not _busy_layer.playing:
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
	var idx: int = AudioServer.get_bus_index("Music")
	if idx < 0:
		return
	var base: float = linear_to_db(maxf(0.001, float(SettingsManager.get_int("music_volume")) / 100.0))
	if _duck_left > 0.0:
		_duck_left = maxf(0.0, _duck_left - delta)
		AudioServer.set_bus_volume_db(idx, base + DUCK_DB)
	elif SettingsManager.get_int("music_volume") > 0:
		AudioServer.set_bus_volume_db(idx, base)


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
