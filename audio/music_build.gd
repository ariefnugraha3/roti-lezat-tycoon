class_name MusicBuild
extends RefCounted
## Bed musik yang dibangun sedikit demi sedikit (GDD 33, 91, 114 tahap 7).
##
## Satu bed musik berisi puluhan nada Rhodes dan petikan gitar. Membangunnya
## sekaligus menahan layar hampir satu detik di PC dan beberapa detik di browser
## HP. Di sini setiap `step(budget)` hanya mengerjakan potongan kecil (CHUNK
## sampel) sampai anggaran waktunya habis, jadi AudioManager bisa menyiapkan
## musik di sela frame dan layar loading bisa menampilkan kemajuannya.
##
## Nada dirender analitis per rentang sampel (fase = langkah × indeks, peluruhan
## = e^(-laju × t)), jadi hasilnya sama persis berapa pun ukuran potongannya.
## Derau shaker memakai RNG milik pekerjaan ini sendiri, supaya bunyi lain yang
## dibangun di tengah jalan tidak mengubahnya.

## Sampel per potongan kerja; anggaran waktu diperiksa di antara potongan.
const CHUNK: int = 2048

enum Stage { NOTES, LOWPASS, PEAK, SCALE, ENCODE, DONE }

const KIND_BASS: int = 0
const KIND_RHODES: int = 1
const KIND_NYLON: int = 2
const KIND_SHAKER: int = 3

## Kunci cache: bed yang identik berbagi satu stream (bailout_cue = music_after_hours).
var key: String = ""
var result: AudioStreamWAV = null

var _buf: PackedFloat32Array = PackedFloat32Array()
var _n: int = 1
var _notes: Array[Dictionary] = []
var _note: int = 0
var _k: int = 0
var _stage: int = Stage.NOTES
var _i: int = 0
var _tone: float = 0.0
var _peak_target: float = 0.58
var _lp_y: float = 0.0
var _peak: float = 0.0
var _gain: float = 1.0
var _data: PackedByteArray = PackedByteArray()
var _work_total: int = 1
var _work_done: int = 0
var _rng: RandomNumberGenerator = null
var _tbl: PackedFloat32Array = PackedFloat32Array()


## Pekerjaan untuk satu resep musik, atau null bila resep itu bukan musik.
static func for_generator(generator_id: String) -> MusicBuild:
	var mood: String = mood_of(generator_id)
	if mood == "":
		return null
	var b := MusicBuild.new()
	if mood == "busy_layer":
		b._setup_busy_layer(generator_id)
	else:
		b.setup_bed(mood)
	return b


## Suasana bed untuk resep musik ("" = bukan musik).
static func mood_of(generator_id: String) -> String:
	match generator_id:
		"music_menu":
			return "menu"
		"music_morning":
			return "morning"
		"music_day":
			return "cozy"
		"music_rain":
			return "rain"
		"music_after_hours", "bailout_cue":
			return "summary"
		"music_busy_layer":
			return "busy_layer"
	return ""


## Kunci cache stream untuk resep apa pun: bed musik per suasana, sisanya per resep.
static func cache_key(generator_id: String) -> String:
	var mood: String = mood_of(generator_id)
	if mood == "" or mood == "busy_layer":
		return generator_id
	return "bed:" + mood


func progress() -> float:
	return clampf(float(_work_done) / float(maxi(_work_total, 1)), 0.0, 1.0)


func is_done() -> bool:
	return result != null


## Kerjakan potongan demi potongan sampai `budget_usec` habis. true = selesai.
func step(budget_usec: int) -> bool:
	var t0: int = Time.get_ticks_usec()
	while result == null:
		_work_chunk()
		if Time.get_ticks_usec() - t0 >= budget_usec:
			break
	return result != null


## Selesaikan sekarang juga (jalur sinkron AudioGenerator.build).
func finish_now() -> AudioStreamWAV:
	while result == null:
		_work_chunk()
	return result


# ===========================================================================
# SUSUNAN NADA
# ===========================================================================

## Bed bossa nova lo-fi: progresi ii-V-I-VI (2 ketuk per akor) oleh Rhodes dan
## gitar nilon; ekor setiap nada dibungkus ke awal buffer agar loop mulus.
func setup_bed(mood: String) -> void:
	key = "bed:" + mood
	var cfg: Dictionary = AudioGenerator.MUSIC_MOODS[mood]
	var beat: float = 60.0 / float(cfg["bpm"])
	var chord_beats: float = 2.0
	_alloc(chord_beats * float(AudioGenerator.PROGRESSION.size()) * beat)
	var root_hz: float = AudioGenerator.MUSIC_ROOT_HZ * pow(2.0, float(cfg["root"]) / 12.0)
	var rhodes_amp: float = float(cfg["rhodes"])
	var guitar_amp: float = float(cfg["guitar"])
	var pluck: Array = cfg["pluck"]
	var hold: float = chord_beats * beat + beat * 1.1
	for ci in AudioGenerator.PROGRESSION.size():
		var chord: Dictionary = AudioGenerator.PROGRESSION[ci]
		var ivals: Array = chord["ivals"]
		var chord_root: float = root_hz * pow(2.0, float(chord["deg"]) / 12.0)
		var t0: float = float(ci) * chord_beats * beat
		# Rhodes: akar di bass ditambah tiga nada akor satu oktaf di atasnya,
		# onsetnya digeser sedikit seperti jari manusia.
		_add_note(KIND_BASS, chord_root, hold, rhodes_amp * 0.85, t0)
		for vi in range(1, ivals.size()):
			var f: float = chord_root * 2.0 * pow(2.0, float(ivals[vi]) / 12.0)
			_add_note(KIND_RHODES, f, hold, rhodes_amp * 0.42, t0 + 0.012 * float(vi))
		# Gitar nilon: pola petikan sinkopasi khas bossa nova.
		for pi in pluck.size():
			var ival: int = int(ivals[1 + (pi % 3)])
			var gf: float = chord_root * 2.0 * pow(2.0, float(ival) / 12.0)
			if pi % 2 == 1:
				gf *= 2.0
			_add_note(KIND_NYLON, gf, beat * 1.15, guitar_amp * 0.50, t0 + float(pluck[pi]) * beat)
	# Lowpass lembut memberi karakter lo-fi kaset era 2000-an (GDD 4.1).
	_tone = float(cfg["tone"])
	_peak_target = 0.58
	_finish_setup()


## Lapisan "busy" di atas music_day: tempo dan panjang loop SAMA dengan mood
## "cozy" supaya keduanya sejajar ketuk (GDD 33.2).
func _setup_busy_layer(generator_id: String) -> void:
	key = generator_id
	_rng = RandomNumberGenerator.new()
	_rng.seed = AudioGenerator.NOISE_SEED + generator_id.hash()
	var cfg: Dictionary = AudioGenerator.MUSIC_MOODS["cozy"]
	var beat: float = 60.0 / float(cfg["bpm"])
	_alloc(2.0 * float(AudioGenerator.PROGRESSION.size()) * beat)
	var root_hz: float = AudioGenerator.MUSIC_ROOT_HZ * pow(2.0, float(cfg["root"]) / 12.0)
	for ci in AudioGenerator.PROGRESSION.size():
		var chord: Dictionary = AudioGenerator.PROGRESSION[ci]
		var ivals: Array = chord["ivals"]
		var chord_root: float = root_hz * pow(2.0, float(chord["deg"]) / 12.0)
		var t0: float = float(ci) * 2.0 * beat
		for step_i in 4:
			var ival: int = int(ivals[(step_i + 1) % ivals.size()])
			var gf: float = chord_root * 4.0 * pow(2.0, float(ival) / 12.0)
			_add_note(KIND_NYLON, gf, beat * 0.6, 0.35, t0 + float(step_i) * beat * 0.5 + beat * 0.25)
		for h in 4:
			_add_note(KIND_SHAKER, 0.0, 0.05, 0.25, t0 + float(h) * beat * 0.5)
	_tone = float(cfg["tone"])
	_peak_target = 0.45
	_finish_setup()


func _alloc(total_sec: float) -> void:
	_n = maxi(1, int(round(total_sec * float(AudioGenerator.SAMPLE_RATE))))
	_buf.resize(_n)
	_buf.fill(0.0)


func _add_note(kind: int, freq: float, dur: float, amp: float, start_sec: float) -> void:
	var count: int = maxi(1, int(round(dur * float(AudioGenerator.SAMPLE_RATE))))
	_notes.append({"kind": kind, "freq": freq, "dur": dur, "amp": amp, "count": count,
		"i0": int(round(start_sec * float(AudioGenerator.SAMPLE_RATE)))})


func _finish_setup() -> void:
	_tbl = AudioGenerator._sine_table()
	var total: int = 0
	for nd: Dictionary in _notes:
		total += int(nd["count"])
	# Lowpass, cari puncak, skala, dan encode masing-masing satu lintasan buffer.
	_work_total = total + 4 * _n


# ===========================================================================
# KERJA PER POTONGAN
# ===========================================================================

func _work_chunk() -> void:
	match _stage:
		Stage.NOTES:
			if _note >= _notes.size():
				_stage = Stage.LOWPASS
				_i = 0
				_lp_y = 0.0
				return
			var nd: Dictionary = _notes[_note]
			var count: int = int(nd["count"])
			if int(nd["kind"]) == KIND_SHAKER:
				_mix_shaker(nd)
				_work_done += count
				_note += 1
				_k = 0
				return
			var to: int = mini(_k + CHUNK, count)
			if float(nd["amp"]) <= 0.0:
				to = count
			elif int(nd["kind"]) == KIND_NYLON:
				_render_nylon(nd, _k, to)
			else:
				_render_rhodes(nd, _k, to, int(nd["kind"]) == KIND_BASS)
			_work_done += to - _k
			_k = to
			if _k >= count:
				_note += 1
				_k = 0
		Stage.LOWPASS:
			_lowpass_range(_i, mini(_i + CHUNK, _n))
		Stage.PEAK:
			var to2: int = mini(_i + CHUNK, _n)
			for i in range(_i, to2):
				_peak = maxf(_peak, absf(_buf[i]))
			_advance(to2, Stage.SCALE)
			if _stage == Stage.SCALE:
				_gain = _peak_target / _peak if _peak > 0.00001 else 1.0
		Stage.SCALE:
			var to3: int = mini(_i + CHUNK, _n)
			if _gain != 1.0:
				for i in range(_i, to3):
					_buf[i] *= _gain
			_advance(to3, Stage.ENCODE)
			if _stage == Stage.ENCODE:
				_data.resize(_n * 2)
		Stage.ENCODE:
			var to4: int = mini(_i + CHUNK, _n)
			for i in range(_i, to4):
				_data.encode_s16(i * 2, int(round(clampf(_buf[i], -1.0, 1.0) * 32767.0)))
			_advance(to4, Stage.DONE)
			if _stage == Stage.DONE:
				_make_stream()


func _advance(to: int, next_stage: int) -> void:
	_work_done += to - _i
	_i = to
	if _i >= _n:
		_stage = next_stage
		_i = 0


## Satu nada Rhodes: tumpukan sinus yang sedikit detune dengan serangan empuk.
## Bass memakai peluruhan lebih lambat dan tanpa partial "tine".
func _render_rhodes(nd: Dictionary, from: int, to: int, bass: bool) -> void:
	var inv: float = 1.0 / float(AudioGenerator.SAMPLE_RATE)
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var freq: float = float(nd["freq"])
	var dur: float = float(nd["dur"])
	var amp: float = float(nd["amp"])
	var attack: float = 0.045 if bass else 0.060
	var decay_rate: float = 1.30 if bass else 1.90
	var tine_amp: float = 0.0 if bass else 0.20
	var step_a: float = freq * inv
	var step_b: float = freq * 1.0032 * inv
	var step_c: float = freq * 2.0 * inv
	var phase_a: float = step_a * float(from)
	var phase_b: float = step_b * float(from)
	var phase_c: float = step_c * float(from)
	var env: float = exp(-decay_rate * inv * float(from))
	var env_mul: float = exp(-decay_rate * inv)
	var tine: float = exp(-5.2 * inv * float(from))
	var tine_mul: float = exp(-5.2 * inv)
	var fade_len: float = 0.09
	var fade_start: float = maxf(0.0, dur - fade_len)
	var idx: int = posmod(int(nd["i0"]) + from, _n)
	for i in range(from, to):
		var t: float = float(i) * inv
		var a: float = env * amp
		if t < attack:
			a *= t / attack
		if t > fade_start:
			a *= maxf(0.0, 1.0 - (t - fade_start) / fade_len)
		var v: float = _tbl[int(phase_a * size) & mask] + 0.62 * _tbl[int(phase_b * size) & mask]
		if tine_amp > 0.0:
			v += tine_amp * tine * _tbl[int(phase_c * size) & mask]
		_buf[idx] += v * a
		phase_a += step_a
		phase_b += step_b
		phase_c += step_c
		env *= env_mul
		tine *= tine_mul
		idx += 1
		if idx >= _n:
			idx = 0


## Satu petikan gitar nilon: serangan sangat singkat, peluruhan cepat, dan hanya
## harmonik 1x, 2x, 3x agar lembut dan berkarakter kayu.
func _render_nylon(nd: Dictionary, from: int, to: int) -> void:
	var inv: float = 1.0 / float(AudioGenerator.SAMPLE_RATE)
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var freq: float = float(nd["freq"])
	var dur: float = float(nd["dur"])
	var amp: float = float(nd["amp"])
	var attack: float = 0.004
	var step_a: float = freq * inv
	var step_b: float = freq * 2.0 * inv
	var step_c: float = freq * 3.0 * inv
	var phase_a: float = step_a * float(from)
	var phase_b: float = step_b * float(from)
	var phase_c: float = step_c * float(from)
	var env_a: float = exp(-4.6 * inv * float(from))
	var env_b: float = exp(-7.4 * inv * float(from))
	var env_c: float = exp(-10.5 * inv * float(from))
	var mul_a: float = exp(-4.6 * inv)
	var mul_b: float = exp(-7.4 * inv)
	var mul_c: float = exp(-10.5 * inv)
	var fade_len: float = 0.06
	var fade_start: float = maxf(0.0, dur - fade_len)
	var idx: int = posmod(int(nd["i0"]) + from, _n)
	for i in range(from, to):
		var t: float = float(i) * inv
		var g: float = amp
		if t < attack:
			g *= t / attack
		if t > fade_start:
			g *= maxf(0.0, 1.0 - (t - fade_start) / fade_len)
		var v: float = env_a * _tbl[int(phase_a * size) & mask]
		v += 0.40 * env_b * _tbl[int(phase_b * size) & mask]
		v += 0.18 * env_c * _tbl[int(phase_c * size) & mask]
		_buf[idx] += v * g
		phase_a += step_a
		phase_b += step_b
		phase_c += step_c
		env_a *= mul_a
		env_b *= mul_b
		env_c *= mul_c
		idx += 1
		if idx >= _n:
			idx = 0


## Shaker pendek (derau pita 4-9 kHz) dari RNG pekerjaan ini, dibungkus ke buffer.
func _mix_shaker(nd: Dictionary) -> void:
	var s: PackedFloat32Array = AudioGenerator._noise_buffer(float(nd["dur"]), float(nd["amp"]),
			{"attack": 0.005, "decay": 0.02, "sustain": 0.2, "release": 0.02}, 4000.0, 9000.0, _rng)
	var idx: int = posmod(int(nd["i0"]), _n)
	for k in s.size():
		_buf[idx] += s[k]
		idx += 1
		if idx >= _n:
			idx = 0


## Lowpass satu kutub (RC), keadaannya dibawa antarpotongan.
func _lowpass_range(from: int, to: int) -> void:
	if _tone > 0.0:
		var dt: float = 1.0 / float(AudioGenerator.SAMPLE_RATE)
		var rc: float = 1.0 / (TAU * _tone)
		var a: float = dt / (rc + dt)
		var y: float = _lp_y
		for i in range(from, to):
			y += a * (_buf[i] - y)
			_buf[i] = y
		_lp_y = y
	_advance(to, Stage.PEAK)
	if _stage == Stage.PEAK:
		_peak = 0.0


func _make_stream() -> void:
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = AudioGenerator.SAMPLE_RATE
	stream.stereo = false
	stream.data = _data
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = _n
	result = stream
	_buf = PackedFloat32Array()
	_notes.clear()
