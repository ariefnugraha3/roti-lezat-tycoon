extends Node
## AudioBus (autoload) — pemutar audio 100% prosedural.
##
## Tidak ada satu pun berkas audio di proyek ini. Seluruh suara dibangkitkan runtime
## oleh `Synth` sebagai PCM (GDD 4.1 soundscape, GDD 7 audio feedback, GDD 3.6.A chime).
##
## Kebijakan autoplay browser (GDD 12.1): musik hanya boleh mulai SETELAH `unlock_audio()`
## dipanggil dari sentuhan pengguna pertama (splash "Tap untuk Mulai").

## Jumlah pemutar SFX agar beberapa suara bisa tumpang tindih tanpa saling memotong.
const SFX_VOICES: int = 8

## Daftar nama SFX yang dikenal (dibangkitkan oleh `_build_sfx`).
const SFX_NAMES: Array[String] = [
	"tap", "pop", "ting", "coin", "paper", "door", "chime", "sad",
]

const MUSIC_MOODS: Array[String] = ["cozy", "busy", "rain", "summary", "menu"]

const MUSIC_VOLUME_DB: float = -13.0
const SFX_VOLUME_DB: float = -6.0

## Preferensi perangkat (bukan isi permainan) disimpan terpisah dari savegame:
## mematikan suara harus tetap berlaku walau pemain menekan "Main Baru".
const SETTINGS_PATH: String = "user://settings.cfg"

## Diset true setelah sentuhan pertama pengguna. Musik tidak akan berbunyi sebelum ini.
var unlocked: bool = false
var muted: bool = false:
	set = _set_muted

var _sfx_cache: Dictionary = {}
var _music_cache: Dictionary = {}
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_next: int = 0
var _music_player: AudioStreamPlayer = null
var _current_mood: String = ""
## Mood yang diminta sebelum audio ter-unlock; diputar begitu unlock terjadi.
var _pending_mood: String = ""
## True selagi preferensi dibaca dari berkas, agar pemuatan tidak menulis balik.
var _loading_settings: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	for i in SFX_VOICES:
		var p := AudioStreamPlayer.new()
		p.volume_db = SFX_VOLUME_DB
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.volume_db = MUSIC_VOLUME_DB
	_music_player.bus = "Master"
	add_child(_music_player)

	# SFX pendek murah dibangkitkan di muka agar tidak ada jeda saat pertama dipakai.
	# Musik SENGAJA tidak dibangkitkan di sini (buffernya jauh lebih panjang) —
	# baru dihitung saat start_music() pertama supaya startup tetap instan.
	for name in SFX_NAMES:
		_sfx_cache[name] = _build_sfx(name)

	_load_settings()


## Membangkitkan satu SFX. Dipisah sebagai match eksplisit karena GDScript tidak
## mengizinkan `call()` pada kelas static secara langsung.
func _build_sfx(name: String) -> AudioStreamWAV:
	match name:
		"tap": return Synth.wooden_tap()
		"pop": return Synth.bubble_pop()
		"ting": return Synth.oven_ting()
		"coin": return Synth.coin_chime()
		"paper": return Synth.paper_rustle()
		"door": return Synth.door_click()
		"chime": return Synth.chime_alert()
		"sad": return Synth.sad_soft()
	return null


## Dipanggil dari sentuhan/klik pertama pengguna (splash "Tap untuk Mulai").
## Memenuhi kebijakan autoplay browser: AudioContext baru boleh hidup setelah gestur pengguna.
func unlock_audio() -> void:
	if unlocked:
		return
	unlocked = true
	# Bunyi sangat pelan untuk "membangunkan" AudioContext browser.
	var p := _pick_player()
	p.stream = _sfx_cache.get("tap", null)
	p.volume_db = -40.0
	p.pitch_scale = 1.0
	if p.stream != null:
		p.play()
	p.volume_db = SFX_VOLUME_DB
	if _pending_mood != "":
		var m := _pending_mood
		_pending_mood = ""
		start_music(m)


func sfx(name: String, pitch: float = 1.0) -> void:
	if muted or not unlocked:
		return
	var stream: AudioStream = _sfx_cache.get(name, null)
	if stream == null:
		push_warning("AudioBus: SFX tidak dikenal '%s'" % name)
		return
	var p := _pick_player()
	p.stream = stream
	p.pitch_scale = clampf(pitch, 0.4, 2.5)
	p.play()


func start_music(mood: String) -> void:
	if not MUSIC_MOODS.has(mood):
		mood = "cozy"
	if not unlocked:
		# Ingat permintaannya; diputar otomatis begitu pengguna menyentuh layar.
		_pending_mood = mood
		return
	if _current_mood == mood and _music_player.playing:
		return
	_current_mood = mood
	if muted:
		return
	if not _music_cache.has(mood):
		_music_cache[mood] = Synth.music_bed(mood)
	_music_player.stream = _music_cache[mood]
	_music_player.play()


func stop_music() -> void:
	_current_mood = ""
	_pending_mood = ""
	_music_player.stop()


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func _pick_player() -> AudioStreamPlayer:
	# Utamakan pemutar yang menganggur; bila semua sibuk, pakai bergilir (round-robin).
	for p in _sfx_players:
		if not p.playing:
			return p
	var chosen := _sfx_players[_sfx_next]
	_sfx_next = (_sfx_next + 1) % _sfx_players.size()
	return chosen


func _set_muted(v: bool) -> void:
	muted = v
	if muted:
		_music_player.stop()
	elif unlocked and _current_mood != "":
		var mood := _current_mood
		_current_mood = ""
		start_music(mood)
	if not _loading_settings:
		_save_settings()


## Membalik keadaan senyap dan mengembalikan keadaan barunya (true = senyap).
## Dipakai tombol suara di Menu dan di menu utama.
func toggle_mute() -> bool:
	muted = not muted
	return muted


func set_muted(v: bool) -> void:
	muted = v


# ---------------------------------------------------------------------------
# Preferensi perangkat
# ---------------------------------------------------------------------------

## Menulis preferensi suara ke `user://settings.cfg`.
##
## Berkasnya sengaja BUKAN savegame: pemain yang mematikan suara di menu utama
## belum tentu punya permainan tersimpan, dan "Main Baru" tidak boleh
## menyalakan kembali suara yang sudah ia matikan.
func _save_settings() -> void:
	var cfg := ConfigFile.new()
	# Berkas yang sudah ada dibaca dulu supaya kunci lain (bila kelak ada)
	# tidak ikut terhapus saat hanya suara yang berubah.
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "muted", muted)
	if cfg.save(SETTINGS_PATH) != OK:
		push_warning("AudioBus: preferensi suara gagal disimpan.")
		return
	# Di Web, `user://` baru mendarat di IndexedDB setelah disinkronkan.
	SaveManager.sync_user_files()


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_loading_settings = true
	muted = bool(cfg.get_value("audio", "muted", false))
	_loading_settings = false
