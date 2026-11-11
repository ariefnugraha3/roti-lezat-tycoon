class_name SongBuild
extends MusicBuild
## Bed musik bossa nova lo-fi 16 bar (GDD 33.1, 33.6; Seksi 20 no. 108).
##
## Dulu satu bed hanya empat akor (sekitar 7 detik) yang berulang terus. Kini
## satu bed = progresi delapan akor yang dimainkan dua kali (bagian A lalu B,
## sekitar 50 detik): Rhodes, bass bossa, iringan gitar nilon, melodi (vibrafon,
## suling, atau EP lonceng) yang frasanya berbeda di A dan B, dan perkusi lembut
## yang biasanya baru masuk penuh di B.
##
## Hemat CPU (untuk HP kentang): setiap nada unik (alat, nada, panjang) dirender
## SEKALI, lalu salinannya ditempel di setiap posisinya (salin-tambah jauh lebih
## murah daripada sintesis); iringan delapan bar dirakit sekali lalu digandakan
## secara native untuk bagian B, dan hanya melodi serta perkusi yang ditempel di
## 16 bar. Laju cuplik 11025 Hz: musik lama pun sudah di-lowpass di bawah 4 kHz,
## jadi tidak ada yang hilang, dan biaya serta memorinya separuh.
##
## Tetap dirakit sedikit demi sedikit (`step(budget)`) dengan hasil yang persis
## sama dengan perakitan sekaligus: semua tahap berjalan berurutan, keadaan
## osilator dan RNG derau dibawa antarpotongan. Ekor nada di ujung dibungkus ke
## awal buffer, jadi loop-nya mulus.

## Laju cuplik bed musik.
const RATE: int = 11025
## Satu putaran progresi (bar); satu bed = dua putaran (A lalu B).
const BAR_COUNT: int = 8

enum S { RENDER, ACC, DUP, TOP, MEASURE, ENCODE, FINISHED }

const I_RHODES: int = 0
const I_BASS: int = 1
const I_NYLON: int = 2
const I_VIBES: int = 3
const I_FLUTE: int = 4
const I_EP_BELL: int = 5
const I_KICK: int = 6
const I_RIM: int = 7
const I_SHAKER: int = 8
const I_BRUSH: int = 9

## Akor: [jarak akar dari nada dasar kunci (semitone), interval akor].
const CHORDS: Dictionary = {
	"I": [0, [0, 4, 7, 11]], "ii": [2, [0, 3, 7, 10]], "iii": [4, [0, 3, 7, 10]],
	"IV": [5, [0, 4, 7, 11]], "iv": [5, [0, 3, 7, 9]], "V": [7, [0, 4, 7, 10]],
	"Vsus": [7, [0, 5, 7, 10]], "vi": [9, [0, 3, 7, 10]], "VI7": [9, [0, 4, 7, 10]],
}

## Suasana: kunci (semitone dari F3), tempo, delapan akor, alat melodi, perkusi,
## bentuk frasa A dan B ("-" = jeda, "C" = nada panjang penutup), kekerasan (RMS),
## dan benih komposisi. Tempo dan panjang "cozy" juga dipakai lapisan ramai.
const MOODS: Dictionary = {
	"menu": {"root": 5, "bpm": 80.0, "chords": ["I", "vi", "ii", "V", "iii", "vi", "ii", "V"],
		"lead": I_VIBES, "drums": "light", "form_a": "abacabdC", "form_b": "bacbeacC", "guitar": 1.0, "rms": 0.095, "seed": 811},
	"morning": {"root": 3, "bpm": 72.0, "chords": ["I", "IV", "I", "IV", "vi", "ii", "IV", "Vsus"],
		"lead": I_FLUTE, "drums": "shaker", "form_a": "a-b-a-cC", "form_b": "abacabdC", "guitar": 1.15, "rms": 0.1, "seed": 727},
	"cozy": {"root": 0, "bpm": 78.0, "chords": ["I", "vi", "ii", "V", "iii", "VI7", "ii", "V"],
		"lead": I_VIBES, "drums": "full", "form_a": "abacabdC", "form_b": "bacbeacC", "guitar": 1.0, "rms": 0.092, "seed": 978},
	"rain": {"root": -2, "bpm": 64.0, "chords": ["vi", "IV", "I", "Vsus", "vi", "iii", "IV", "V"],
		"lead": I_EP_BELL, "drums": "none", "form_a": "a-b-c--C", "form_b": "a-b-a-dC", "guitar": 0.55, "rms": 0.083, "seed": 640},
	"summary": {"root": -3, "bpm": 68.0, "chords": ["I", "iii", "IV", "iv", "I", "vi", "ii", "V"],
		"lead": I_VIBES, "drums": "brush", "form_a": "a-bac-dC", "form_b": "abacbadC", "guitar": 0.8, "rms": 0.089, "seed": 686},
}

## Pola ritme melodi satu bar: [ketuk mulai, panjang dalam ketuk].
const RHYTHMS: Array = [
	[[0.0, 1.5], [1.5, 0.5], [2.0, 2.0]],
	[[0.5, 0.5], [1.0, 1.0], [2.5, 0.5], [3.0, 1.0]],
	[[0.0, 2.0], [2.5, 1.5]],
	[[1.0, 0.5], [1.5, 0.5], [2.0, 1.5]],
	[[0.0, 0.5], [0.5, 0.5], [1.0, 0.5], [1.5, 2.0]],
	[[0.0, 1.0], [1.5, 1.0], [3.0, 1.0]],
	[[0.5, 1.0], [2.0, 2.0]],
]
const CADENCE: Array = [[0.0, 3.0]]
## Tangga nada pentatonik mayor (cocok di atas semua akor progresi).
const PENTATONIC: Array[int] = [0, 2, 4, 7, 9]
## Jendela register (semitone dari nada dasar kunci di F3).
const RHODES_LO: int = 5
const NYLON_LO: int = 12
const BASS_LO: int = -12
const MELODY_LO: int = 17
const MELODY_HI: int = 33

var _rate_inv: float = 1.0 / float(RATE)
var _s: int = S.RENDER
var _samples: Array[PackedFloat32Array] = []
var _renders: Array[Dictionary] = []
var _slot_of: Dictionary = {}
var _acc_places: Array[Dictionary] = []
var _top_places: Array[Dictionary] = []
var _acc: PackedFloat32Array = PackedFloat32Array()
var _cur: PackedFloat32Array = PackedFloat32Array()
var _ri: int = 0
var _rk: int = 0
var _rms_target: float = 0.09
var _sum_sq: float = 0.0
var _noise := RandomNumberGenerator.new()
# Keadaan osilator/filter nada yang sedang dirender (dibawa antarpotongan).
var _p1: float = 0.0
var _p2: float = 0.0
var _p3: float = 0.0
var _p4: float = 0.0
var _e1: float = 1.0
var _e2: float = 1.0
var _e3: float = 1.0
var _y1: float = 0.0
var _y2: float = 0.0
var _x1: float = 0.0
var _beat: float = 0.75


# ===========================================================================
# KOMPOSISI
# ===========================================================================

## Bed untuk suasana `mood` (kunci MOODS).
func setup_song(mood: String) -> void:
	var cfg: Dictionary = MOODS.get(mood, MOODS["cozy"])
	key = "bed:" + mood
	_begin(cfg)
	var root: int = int(cfg["root"])
	var chords: Array = cfg["chords"]
	var guitar: float = float(cfg["guitar"])
	# Iringan delapan bar (dirakit sekali, digandakan untuk bagian B).
	for b in BAR_COUNT:
		var ch: Array = CHORDS[str(chords[b])]
		var cr: int = root + int(ch[0])
		var iv: Array = ch[1]
		var next_ch: Array = CHORDS[str(chords[(b + 1) % BAR_COUNT])]
		var t0: float = float(b) * 4.0
		# Rhodes: voicing jazz tanpa akar (3, 7, 9) di satu oktaf tengah (akarnya
		# di bass), sedikit digulir seperti jari manusia.
		var voicing: Array[int] = []
		for tone: int in [int(iv[1]), int(iv[3]), 14]:
			voicing.append(_wrap(cr + tone, root + RHODES_LO))
		voicing.sort()
		for vi in voicing.size():
			_acc_note(I_RHODES, voicing[vi], 4.0, 0.3, t0 + 0.012 * float(vi) / _beat)
		# Bass bossa: akar (ketuk 1), kuint (ketuk 3), nada pendek menuju akor berikutnya.
		var bass_root: int = _wrap(cr, root + BASS_LO)
		_acc_note(I_BASS, bass_root, 1.5, 0.62, t0)
		_acc_note(I_BASS, _wrap(cr + 7, root + BASS_LO), 1.2, 0.5, t0 + 2.0)
		_acc_note(I_BASS, _wrap(root + int(next_ch[0]) - 1 + (2 if b % 2 == 0 else 0), root + BASS_LO), 0.45, 0.36, t0 + 3.5)
		# Gitar nilon: petikan akor (3, 7, 9) berpola bossa dua bar.
		var stabs: Array = [0.0, 1.5, 3.0] if b % 2 == 0 else [0.5, 2.0, 3.5]
		for si in stabs.size():
			for gi in 3:
				var tone2: int = [int(iv[1]), int(iv[3]), 14][gi]
				_acc_note(I_NYLON, _wrap(cr + tone2, root + NYLON_LO), 0.9, 0.14 * guitar * (1.0 if si == 0 else 0.8),
					float(stabs[si]) + t0 + 0.006 * float(gi) / _beat)
	# Melodi dan perkusi di 16 bar (bagian A lalu B).
	_compose_melody(cfg)
	_place_drums(str(cfg["drums"]))
	_end_setup()


## Lapisan ramai (GDD 33.2) di atas bed siang: tempo dan panjang sama persis
## dengan "cozy" supaya sejajar ketuk. Shaker 16-an, klave rim, kick lembut,
## dan arpeggio gitar nilon tinggi.
func setup_busy(generator_id: String) -> void:
	var cfg: Dictionary = MOODS["cozy"]
	key = generator_id
	_begin(cfg)
	var root: int = int(cfg["root"])
	var chords: Array = cfg["chords"]
	for b in BAR_COUNT:
		var ch: Array = CHORDS[str(chords[b])]
		var cr: int = root + int(ch[0])
		var iv: Array = ch[1]
		var t0: float = float(b) * 4.0
		for k in 16:
			_acc_note(I_SHAKER, 0, 0.25, 0.11 if k % 2 == 1 else 0.065, t0 + 0.25 * float(k))
		for at: float in ([1.5, 3.0] if b % 2 == 0 else [1.0, 2.5]):
			_acc_note(I_RIM, 0, 0.25, 0.22, t0 + at)
		_acc_note(I_KICK, 0, 0.5, 0.34, t0)
		_acc_note(I_KICK, 0, 0.5, 0.24, t0 + 2.0)
		var arp: Array[int] = [int(iv[1]), int(iv[2]), int(iv[3]), 14]
		for a in 8:
			_acc_note(I_NYLON, _wrap(cr + arp[(a * 3 + b) % arp.size()], root + 19), 0.7, 0.2 if a % 2 == 0 else 0.15, t0 + 0.5 * float(a) + 0.25)
	_rms_target = 0.115
	_end_setup()


## Frasa A (bar 1-8) dan B (bar 9-16): huruf yang sama = pola ritme dan langkah
## nada yang sama (motif yang diulang di akor lain), "C" = nada panjang penutup
## pada nada akor, "-" = jeda. Nada bergerak di tangga pentatonik; ketukan kuat
## dan nada panjang mendarat di nada akor. Bagian B dimulai lebih tinggi.
func _compose_melody(cfg: Dictionary) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(cfg["seed"])
	var root: int = int(cfg["root"])
	var chords: Array = cfg["chords"]
	var lead: int = int(cfg["lead"])
	var allowed: Array[int] = []
	for s in range(root + MELODY_LO, root + MELODY_HI + 1):
		if PENTATONIC.has(posmod(s - root, 12)):
			allowed.append(s)
	# Huruf -> pola ritme (diacak sekali per suasana, tanpa pengulangan).
	var order: Array[int] = []
	for i in RHYTHMS.size():
		order.append(i)
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp
	var motifs: Dictionary = {}
	var at: int = allowed.size() / 3
	for bar in BAR_COUNT * 2:
		var form: String = str(cfg["form_b"] if bar >= BAR_COUNT else cfg["form_a"])
		var letter: String = form[bar % BAR_COUNT]
		if bar == BAR_COUNT:
			at = mini(allowed.size() - 1, at + 2)
		if letter == "-":
			continue
		var ch: Array = CHORDS[str(chords[bar % BAR_COUNT])]
		var cr: int = root + int(ch[0])
		var iv: Array = ch[1]
		var rhythm: Array = CADENCE if letter == "C" else RHYTHMS[order[(letter.unicode_at(0) - 97) % order.size()]]
		var steps: Array = motifs.get(letter, [])
		if steps.is_empty():
			for k in rhythm.size():
				var st: int = [-2, -1, 1, 2, 1, -1][rng.randi_range(0, 5)]
				steps.append(0 if k == 0 and letter == "C" else st)
			motifs[letter] = steps
		for k in rhythm.size():
			var pos: float = float(rhythm[k][0])
			var dur: float = float(rhythm[k][1])
			var step: int = int(steps[k])
			# Pantulkan langkah di tepi register supaya melodi tidak menempel di ujung.
			if at + step < 1 or at + step > allowed.size() - 2:
				step = -step
			at = clampi(at + step, 0, allowed.size() - 1)
			var semi: int = allowed[at]
			if pos == 0.0 or pos == 2.0 or dur >= 1.5 or letter == "C":
				semi = _nearest_chord_tone(semi, cr, iv)
				at = _nearest_index(allowed, semi)
			var g: float = 0.46 * (1.0 if pos == 0.0 else 0.84) * (0.9 + 0.2 * rng.randf())
			_top_note(lead, semi, dur, g, float(bar) * 4.0 + pos)


func _place_drums(style: String) -> void:
	for bar in BAR_COUNT * 2:
		var b_section: bool = bar >= BAR_COUNT
		var t0: float = float(bar) * 4.0
		var clave: Array = [1.5, 3.0] if bar % 2 == 0 else [1.0, 2.5]
		match style:
			"full":
				for k in 8:
					_top_note(I_SHAKER, 0, 0.25, (0.1 if k % 2 == 1 else 0.06) * (1.0 if b_section else 0.75), t0 + 0.5 * float(k))
				for c: float in clave:
					_top_note(I_RIM, 0, 0.25, 0.2 if b_section else 0.15, t0 + c)
				if b_section:
					_top_note(I_KICK, 0, 0.5, 0.42, t0)
					_top_note(I_KICK, 0, 0.5, 0.3, t0 + 2.0)
			"light":
				for k2 in 8:
					_top_note(I_SHAKER, 0, 0.25, 0.08 if k2 % 2 == 1 else 0.05, t0 + 0.5 * float(k2))
				if b_section:
					for c2: float in clave:
						_top_note(I_RIM, 0, 0.25, 0.16, t0 + c2)
			"shaker":
				if b_section:
					for k3 in 8:
						_top_note(I_SHAKER, 0, 0.25, 0.07 if k3 % 2 == 1 else 0.04, t0 + 0.5 * float(k3))
			"brush":
				_top_note(I_BRUSH, 0, 0.5, 0.14, t0 + 1.0)
				_top_note(I_BRUSH, 0, 0.5, 0.14, t0 + 3.0)
				if b_section:
					for k4 in 4:
						_top_note(I_SHAKER, 0, 0.25, 0.05, t0 + 1.0 * float(k4) + 0.5)


func _begin(cfg: Dictionary) -> void:
	_rate = RATE
	_beat = 60.0 / float(cfg["bpm"])
	var bar_len: int = int(round(4.0 * _beat * float(RATE)))
	_n = bar_len * BAR_COUNT * 2
	_rms_target = float(cfg.get("rms", 0.09))
	_noise.seed = AudioGenerator.NOISE_SEED + int(cfg["seed"])


func _end_setup() -> void:
	_work_total = 2 * _n
	for r: Dictionary in _renders:
		_work_total += int(r["len"])
	for p: Dictionary in _acc_places:
		_work_total += _len_of(int(p["slot"]))
	for p2: Dictionary in _top_places:
		_work_total += _len_of(int(p2["slot"]))
	_samples.resize(_renders.size())
	_s = S.RENDER


## Nada iringan (8 bar) dan nada atas (16 bar). `at` dalam ketuk.
func _acc_note(inst: int, semi: int, beats: float, gain: float, at: float) -> void:
	_acc_places.append({"slot": _slot(inst, semi, beats), "at": _at(at, _n / 2), "gain": gain})


func _top_note(inst: int, semi: int, beats: float, gain: float, at: float) -> void:
	_top_places.append({"slot": _slot(inst, semi, beats), "at": _at(at, _n), "gain": gain})


func _at(beats: float, n: int) -> int:
	return posmod(int(round(beats * _beat * float(RATE))), n)


## Sampel unik untuk (alat, nada, panjang render): dirender sekali, dipakai
## berulang. Alat berdenting (Rhodes, vibrafon, EP lonceng, gitar) dibiarkan
## berdering dengan panjang tetap, jadi satu nada cukup satu render; suling dan
## bass mengikuti panjang notnya.
func _slot(inst: int, semi: int, beats: float) -> int:
	var sec: float = beats * _beat
	match inst:
		I_RHODES:
			sec = minf(4.0 * _beat + 0.2, 2.6)
		I_EP_BELL:
			sec = 2.6
		I_BASS:
			sec = minf(sec + 0.15, 1.6)
		I_NYLON:
			sec = 0.65
		I_VIBES:
			sec = 1.9
		I_FLUTE:
			sec = sec + 0.12
		I_KICK:
			sec = 0.2
		I_RIM:
			sec = 0.07
		I_SHAKER:
			sec = 0.08
		I_BRUSH:
			sec = 0.22
	var length: int = maxi(16, int(round(sec * float(RATE))))
	var k: String = "%d:%d:%d" % [inst, semi, length]
	if _slot_of.has(k):
		return int(_slot_of[k])
	var slot: int = _renders.size()
	_renders.append({"slot": slot, "inst": inst, "freq": AudioGenerator.MUSIC_ROOT_HZ * pow(2.0, float(semi) / 12.0), "len": length})
	_slot_of[k] = slot
	return slot


func _len_of(slot: int) -> int:
	return int(_renders[slot]["len"])


## `semi` dibawa ke oktaf [lo, lo + 12).
static func _wrap(semi: int, lo: int) -> int:
	return lo + posmod(semi - lo, 12)


## Nada akor terdekat dari `semi` (paling jauh tiga semitone).
static func _nearest_chord_tone(semi: int, chord_root: int, ivals: Array) -> int:
	for d: int in [0, -1, 1, -2, 2, -3, 3]:
		if ivals.has(posmod(semi + d - chord_root, 12)):
			return semi + d
	return semi


static func _nearest_index(allowed: Array[int], semi: int) -> int:
	var best: int = 0
	for i in allowed.size():
		if absi(allowed[i] - semi) < absi(allowed[best] - semi):
			best = i
	return best


# ===========================================================================
# KERJA PER POTONGAN
# ===========================================================================

func _work_chunk() -> void:
	match _s:
		S.RENDER:
			if _ri >= _renders.size():
				_s = S.ACC
				_ri = 0
				_rk = 0
				_acc.resize(_n / 2)
				_acc.fill(0.0)
				return
			var it: Dictionary = _renders[_ri]
			var total: int = int(it["len"])
			if _rk == 0:
				_reset_voice(total)
			var to: int = mini(_rk + CHUNK, total)
			_render(it, _rk, to)
			_work_done += to - _rk
			_rk = to
			if _rk >= total:
				_samples[_ri] = _cur
				_cur = PackedFloat32Array()
				_ri += 1
				_rk = 0
		S.ACC:
			if _ri >= _acc_places.size():
				_s = S.DUP
				return
			_acc = _place_chunk(_acc, _acc_places)
		S.DUP:
			# Bagian B = iringan yang sama: digandakan secara native (nyaris gratis).
			_buf = _acc.duplicate()
			_buf.append_array(_acc)
			_acc = PackedFloat32Array()
			_s = S.TOP
			_ri = 0
			_rk = 0
		S.TOP:
			if _ri >= _top_places.size():
				_samples.clear()
				_s = S.MEASURE
				_i = 0
				_sum_sq = 0.0
				_peak = 0.0
				return
			_buf = _place_chunk(_buf, _top_places)
		S.MEASURE:
			var to2: int = mini(_i + CHUNK, _n)
			var sq: float = _sum_sq
			var pk: float = _peak
			for i in range(_i, to2):
				var v: float = _buf[i]
				sq += v * v
				pk = maxf(pk, absf(v))
			_sum_sq = sq
			_peak = pk
			_work_done += to2 - _i
			_i = to2
			if _i >= _n:
				# Kekerasan sama dengan musik lama (RMS), tanpa pernah melewati 0,95.
				var rms: float = sqrt(_sum_sq / float(_n))
				_gain = 1.0 if rms <= 0.000001 else minf(_rms_target / rms, 0.95 / maxf(_peak, 0.000001))
				_data.resize((_n + AudioGenerator.TAIL_PAD) * 2)
				_s = S.ENCODE
				_i = 0
		S.ENCODE:
			var to3: int = mini(_i + CHUNK, _n)
			var g: float = _gain * 32767.0
			for i2 in range(_i, to3):
				_data.encode_s16(i2 * 2, int(_buf[i2] * g))
			_work_done += to3 - _i
			_i = to3
			if _i >= _n:
				AudioGenerator.pad_tail(_data, _n, true)
				_make_stream()
				_s = S.FINISHED


## Tempel potongan nada `places[_ri]` ke `dst` (dengan bungkus ke awal buffer).
## `dst` dipegang satu referensi saja supaya tulisannya tidak menyalin buffer.
func _place_chunk(dst: PackedFloat32Array, places: Array[Dictionary]) -> PackedFloat32Array:
	var p: Dictionary = places[_ri]
	var src: PackedFloat32Array = _samples[int(p["slot"])]
	var total: int = src.size()
	var to: int = mini(_rk + CHUNK, total)
	var g: float = float(p["gain"])
	var n: int = dst.size()
	var idx: int = posmod(int(p["at"]) + _rk, n)
	for k in range(_rk, to):
		dst[idx] += src[k] * g
		idx += 1
		if idx == n:
			idx = 0
	_work_done += to - _rk
	_rk = to
	if _rk >= total:
		_ri += 1
		_rk = 0
	return dst


func _reset_voice(total: int) -> void:
	_cur = PackedFloat32Array()
	_cur.resize(total)
	_p1 = 0.0
	_p2 = 0.0
	_p3 = 0.0
	_p4 = 0.0
	_e1 = 1.0
	_e2 = 1.0
	_e3 = 1.0
	_y1 = 0.0
	_y2 = 0.0
	_x1 = 0.0


# ===========================================================================
# ALAT MUSIK (amplitudo 1; volume diberikan saat ditempel)
# ===========================================================================

func _render(it: Dictionary, from: int, to: int) -> void:
	var cur: PackedFloat32Array = _cur
	_cur = PackedFloat32Array()
	var f: float = float(it["freq"])
	var total: int = int(it["len"])
	match int(it["inst"]):
		I_RHODES:
			_rhodes(cur, from, to, total, f, 0.22, 1.7)
		I_EP_BELL:
			_rhodes(cur, from, to, total, f * 2.0, 0.55, 1.9)
		I_BASS:
			_bass(cur, from, to, total, f)
		I_NYLON:
			_nylon(cur, from, to, total, f)
		I_VIBES:
			_vibes(cur, from, to, total, f)
		I_FLUTE:
			_flute(cur, from, to, total, f)
		I_KICK:
			_kick(cur, from, to)
		I_RIM:
			_rim(cur, from, to)
		I_SHAKER:
			_shaker(cur, from, to, 2600.0, 5200.0, 0.006, 55.0)
		I_BRUSH:
			_shaker(cur, from, to, 500.0, 2600.0, 0.014, 15.0)
	_cur = cur


## Panjang fade keluar di ujung setiap nada (sampel, 0,1 detik).
const FADE: int = 1102


## Electric piano: sinus dasar, kembaran sedikit fals (chorus hangat), dan "tine"
## oktaf yang cepat meredup.
func _rhodes(cur: PackedFloat32Array, from: int, to: int, total: int, f: float, tine: float, decay: float) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var sa: float = f * _rate_inv
	var sb: float = f * 1.0035 * _rate_inv
	var sc: float = f * 2.0 * _rate_inv
	var da: float = exp(-decay * _rate_inv)
	var dc: float = exp(-6.5 * _rate_inv)
	var att: int = int(0.01 * float(RATE))
	var fade_from: int = total - FADE
	var p1: float = _p1
	var p2: float = _p2
	var p3: float = _p3
	var e1: float = _e1
	var e2: float = _e2
	for i in range(from, to):

		var g: float = 1.0
		if i < att:
			g = float(i) / float(att)
		elif i > fade_from:
			g = float(total - i) / float(FADE)
		var v: float = tbl[int(p1 * size) & mask] + 0.55 * tbl[int(p2 * size) & mask] + tine * e2 * tbl[int(p3 * size) & mask]
		cur[i] = v * e1 * g
		p1 += sa
		p2 += sb
		p3 += sc
		e1 *= da
		e2 *= dc
	_p1 = p1
	_p2 = p2
	_p3 = p3
	_e1 = e1
	_e2 = e2


## Bass kontra lembut: dasar kuat, harmonik 2 dan 3 yang cepat meredup.
func _bass(cur: PackedFloat32Array, from: int, to: int, total: int, f: float) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var s1: float = f * _rate_inv
	var d1: float = exp(-2.3 * _rate_inv)
	var d2: float = exp(-6.0 * _rate_inv)
	var att: int = int(0.006 * float(RATE))
	var fade_from: int = total - FADE
	var p1: float = _p1
	var e1: float = _e1
	var e2: float = _e2
	for i in range(from, to):

		var g: float = 1.0
		if i < att:
			g = float(i) / float(att)
		elif i > fade_from:
			g = float(total - i) / float(FADE)
		var ph: int = int(p1 * size)
		var v: float = tbl[ph & mask] + e2 * (0.35 * tbl[(ph * 2) & mask] + 0.12 * tbl[(ph * 3) & mask])
		cur[i] = v * e1 * g
		p1 += s1
		e1 *= d1
		e2 *= d2
	_p1 = p1
	_e1 = e1
	_e2 = e2


## Petikan gitar nilon: serangan singkat, harmonik 1x-3x dengan peluruhan berbeda.
func _nylon(cur: PackedFloat32Array, from: int, to: int, total: int, f: float) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var s1: float = f * _rate_inv
	var d1: float = exp(-4.2 * _rate_inv)
	var d2: float = exp(-7.4 * _rate_inv)
	var d3: float = exp(-11.0 * _rate_inv)
	var att: int = int(0.003 * float(RATE))
	var fade_from: int = total - FADE
	var p1: float = _p1
	var e1: float = _e1
	var e2: float = _e2
	var e3: float = _e3
	for i in range(from, to):

		var g: float = 1.0
		if i < att:
			g = float(i) / float(att)
		elif i > fade_from:
			g = float(total - i) / float(FADE)
		var ph: int = int(p1 * size)
		var v: float = e1 * tbl[ph & mask] + 0.4 * e2 * tbl[(ph * 2) & mask] + 0.18 * e3 * tbl[(ph * 3) & mask]
		cur[i] = v * g
		p1 += s1
		e1 *= d1
		e2 *= d2
		e3 *= d3
	_p1 = p1
	_e1 = e1
	_e2 = e2
	_e3 = e3


## Vibrafon: bilah sinus dengan parsial 4x yang cepat meredup dan tremolo motor
## 5,2 Hz yang lembut.
func _vibes(cur: PackedFloat32Array, from: int, to: int, total: int, f: float) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var s1: float = f * _rate_inv
	var s4: float = 5.2 * _rate_inv
	var d1: float = exp(-1.5 * _rate_inv)
	var d2: float = exp(-9.0 * _rate_inv)
	var att: int = int(0.003 * float(RATE))
	var fade_from: int = total - FADE
	var p1: float = _p1
	var p4: float = _p4
	var e1: float = _e1
	var e2: float = _e2
	for i in range(from, to):

		var g: float = 1.0
		if i < att:
			g = float(i) / float(att)
		elif i > fade_from:
			g = float(total - i) / float(FADE)
		var ph: int = int(p1 * size)
		var trem: float = 0.86 + 0.14 * tbl[int(p4 * size) & mask]
		var v: float = tbl[ph & mask] + 0.22 * e2 * tbl[(ph * 4) & mask]
		cur[i] = v * e1 * trem * g
		p1 += s1
		p4 += s4
		e1 *= d1
		e2 *= d2
	_p1 = p1
	_p4 = p4
	_e1 = e1
	_e2 = e2


## Suling kayu lembut: dasar dan dua harmonik, desah napas di awal, vibrato
## yang masuk pelan.
func _flute(cur: PackedFloat32Array, from: int, to: int, total: int, f: float) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var s1: float = f * _rate_inv
	var s4: float = 4.8 * _rate_inv
	var att: int = int(0.05 * float(RATE))
	var fade_from: int = total - FADE
	var vib_in: float = 0.18 * float(RATE)
	var d3: float = exp(-28.0 * _rate_inv)
	var p1: float = _p1
	var p4: float = _p4
	var e3: float = _e3
	var y: float = _y1
	for i in range(from, to):
		var depth: float = 0.0035 * minf(1.0, float(i) / vib_in)
		var ph: int = int(p1 * size)
		var v: float = tbl[ph & mask] + 0.2 * tbl[(ph * 2) & mask] + 0.06 * tbl[(ph * 3) & mask]
		# Napas: derau yang di-lowpass dan meredup cepat.
		y += 0.25 * (_noise.randf_range(-1.0, 1.0) - y)

		var g: float = 1.0
		if i < att:
			g = float(i) / float(att)
		elif i > fade_from:
			g = float(total - i) / float(FADE)
		cur[i] = (v * 0.85 + y * 0.5 * e3) * g
		p1 += s1 * (1.0 + depth * tbl[int(p4 * size) & mask])
		p4 += s4
		e3 *= d3
	_p1 = p1
	_p4 = p4
	_e3 = e3
	_y1 = y


## Kick lembut: sinus yang turun dari ~125 Hz ke 50 Hz dengan klik kecil.
func _kick(cur: PackedFloat32Array, from: int, to: int) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var sweep: float = exp(-30.0 * _rate_inv)
	var amp_d: float = exp(-16.0 * _rate_inv)
	var click: int = int(0.002 * float(RATE))
	var p1: float = _p1
	var e1: float = _e1
	var e2: float = _e2
	for i in range(from, to):
		var v: float = tbl[int(p1 * size) & mask] * e2
		if i < click:
			v += _noise.randf_range(-1.0, 1.0) * 0.3
		cur[i] = v
		p1 += (50.0 + 75.0 * e1) * _rate_inv
		e1 *= sweep
		e2 *= amp_d
	_p1 = p1
	_e1 = e1
	_e2 = e2


## Klik rim kayu: dua parsial bernada yang sangat cepat meredup dan klik derau.
func _rim(cur: PackedFloat32Array, from: int, to: int) -> void:
	var tbl: PackedFloat32Array = AudioGenerator._sine_table()
	var size: float = float(AudioGenerator.SINE_TABLE_SIZE)
	var mask: int = AudioGenerator.SINE_TABLE_MASK
	var s1: float = 1750.0 * _rate_inv
	var s2: float = 2650.0 * _rate_inv
	var d1: float = exp(-70.0 * _rate_inv)
	var d2: float = exp(-95.0 * _rate_inv)
	var click: int = int(0.003 * float(RATE))
	var p1: float = _p1
	var p2: float = _p2
	var e1: float = _e1
	var e2: float = _e2
	for i in range(from, to):
		var v: float = 0.6 * e1 * tbl[int(p1 * size) & mask] + 0.4 * e2 * tbl[int(p2 * size) & mask]
		if i < click:
			v += _noise.randf_range(-1.0, 1.0) * 0.35 * (1.0 - float(i) / float(click))
		cur[i] = v
		p1 += s1
		p2 += s2
		e1 *= d1
		e2 *= d2
	_p1 = p1
	_p2 = p2
	_e1 = e1
	_e2 = e2


## Shaker / sapuan brush: derau pita `hp`..`lp` dengan serangan `att` detik dan
## peluruhan `decay` per detik.
func _shaker(cur: PackedFloat32Array, from: int, to: int, hp: float, lp: float, att_sec: float, decay: float) -> void:
	var a_lp: float = _rate_inv / (1.0 / (TAU * lp) + _rate_inv)
	var rc_hp: float = 1.0 / (TAU * hp)
	var a_hp: float = rc_hp / (rc_hp + _rate_inv)
	var d1: float = exp(-decay * _rate_inv)
	var att: int = maxi(1, int(att_sec * float(RATE)))
	var e1: float = _e1
	var x1: float = _x1
	var y1: float = _y1
	var y2: float = _y2
	for i in range(from, to):
		var x: float = _noise.randf_range(-1.0, 1.0)
		y1 = a_hp * (y1 + x - x1)
		x1 = x
		y2 += a_lp * (y1 - y2)
		var g: float = e1
		if i < att:
			g *= float(i) / float(att)
		else:
			e1 *= d1
		cur[i] = y2 * g * 2.2
	_e1 = e1
	_x1 = x1
	_y1 = y1
	_y2 = y2
