class_name Synth
extends RefCounted

## Synth — pembangkit audio 100% prosedural untuk Roti Lezat Tycoon.
##
## Proyek ini TIDAK memuat satu pun berkas audio (.ogg/.wav/.mp3). Seluruh bunyi
## dihitung sebagai sampel PCM di dalam GDScript lalu dibungkus menjadi
## AudioStreamWAV 16-bit mono 22050 Hz (GDD 4.1, 12.2).
##
## Semua fungsi bersifat static dan tidak bergantung pada autoload mana pun,
## sehingga aman dipanggil dari mode headless (tools/validate.gd).

## Laju cuplik seluruh bunyi. 22050 Hz sudah lebih dari cukup untuk palet foley
## hangat ala lo-fi 2000-an dan menekan biaya hitung di ponsel maupun browser.
const SAMPLE_RATE: int = 22050

## Benih derau tetap agar bunyi selalu identik di setiap sesi (kami tidak
## memakai randf() global sesuai aturan proyek).
const NOISE_SEED: int = 20260418

## Tabel sinus untuk jalur panas (render musik). Pencarian tabel jauh lebih
## murah daripada memanggil sin() jutaan kali dari GDScript.
const SINE_TABLE_SIZE: int = 4096
const SINE_TABLE_MASK: int = 4095

## Nada acuan bass musik: F3 (174.614 Hz), nada dasar hangat sesuai GDD 4.1.
const MUSIC_ROOT_HZ: float = 174.614

## Progresi bossa nova ii - V - I - VI (di F mayor: Gm7 - C7 - Fmaj7 - Dm7).
## "deg" = jarak semitone akar akor dari nada dasar; "ivals" = interval akor.
const PROGRESSION: Array = [
	{"deg": 2, "ivals": [0, 3, 7, 10]},
	{"deg": 7, "ivals": [0, 4, 7, 10]},
	{"deg": 0, "ivals": [0, 4, 7, 11]},
	{"deg": 9, "ivals": [0, 3, 7, 10]},
]

## Varian suasana musik. "pluck" = posisi petikan gitar nilon dalam satuan ketuk
## pada tiap akor (satu akor = 2 ketuk); "tone" = cutoff lowpass lo-fi.
const MUSIC_MOODS: Dictionary = {
	"cozy": {
		"root": 0, "bpm": 72.0, "rhodes": 0.80, "guitar": 0.55, "tone": 3200.0,
		"pluck": [0.0, 0.75, 1.5],
	},
	"busy": {
		"root": 2, "bpm": 92.0, "rhodes": 0.70, "guitar": 0.72, "tone": 4200.0,
		"pluck": [0.0, 0.5, 1.0, 1.5, 1.75],
	},
	"rain": {
		"root": -2, "bpm": 64.0, "rhodes": 0.92, "guitar": 0.28, "tone": 2100.0,
		"pluck": [0.0, 1.5],
	},
	"summary": {
		"root": 0, "bpm": 68.0, "rhodes": 0.86, "guitar": 0.42, "tone": 2700.0,
		"pluck": [0.0, 1.0],
	},
	"menu": {
		"root": 5, "bpm": 76.0, "rhodes": 0.78, "guitar": 0.60, "tone": 3400.0,
		"pluck": [0.0, 0.75, 1.5],
	},
}

static var _sine_cache: PackedFloat32Array = PackedFloat32Array()
static var _rng: RandomNumberGenerator = null


# ---------------------------------------------------------------------------
# Sumber daya bersama
# ---------------------------------------------------------------------------

## Tabel satu putaran gelombang sinus, dibangun sekali seumur proses.
static func _sine_table() -> PackedFloat32Array:
	if _sine_cache.size() == SINE_TABLE_SIZE:
		return _sine_cache
	var tbl: PackedFloat32Array = PackedFloat32Array()
	tbl.resize(SINE_TABLE_SIZE)
	for i in SINE_TABLE_SIZE:
		tbl[i] = sin(TAU * float(i) / float(SINE_TABLE_SIZE))
	_sine_cache = tbl
	return _sine_cache


## Generator acak khusus derau, terpisah dari GameConfig.rng supaya bunyi tetap
## deterministik dan Synth tetap bisa dipakai tanpa autoload apa pun.
static func _noise_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = NOISE_SEED
	return _rng


# ---------------------------------------------------------------------------
# Utilitas buffer
# ---------------------------------------------------------------------------

## Buffer sampel float kosong sepanjang dur detik.
static func _new_buffer(dur: float) -> PackedFloat32Array:
	var n: int = maxi(1, int(round(dur * float(SAMPLE_RATE))))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	return buf


## Mengubah buffer float (-1..1) menjadi AudioStreamWAV 16-bit mono.
static func _to_stream(buf: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var n: int = buf.size()
	var data: PackedByteArray = PackedByteArray()
	data.resize(n * 2)
	for i in n:
		var v: float = clampf(buf[i], -1.0, 1.0)
		data.encode_s16(i * 2, int(round(v * 32767.0)))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = SAMPLE_RATE
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = n
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


## Menjumlahkan src ke dalam dst mulai detik start_sec (dipotong di ujung buffer).
static func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array,
		start_sec: float) -> PackedFloat32Array:
	var n: int = dst.size()
	var i0: int = int(round(start_sec * float(SAMPLE_RATE)))
	for k in src.size():
		var idx: int = i0 + k
		if idx < 0:
			continue
		if idx >= n:
			break
		dst[idx] += src[k]
	return dst


## Seperti _mix_into, tetapi ekor nada dibungkus kembali ke awal buffer. Inilah
## kunci agar bed musik dapat berulang tanpa sambungan yang terdengar.
static func _add_wrapped(dst: PackedFloat32Array, src: PackedFloat32Array,
		start_sec: float) -> PackedFloat32Array:
	var n: int = dst.size()
	if n <= 0:
		return dst
	var i0: int = int(round(start_sec * float(SAMPLE_RATE)))
	for k in src.size():
		var idx: int = posmod(i0 + k, n)
		dst[idx] += src[k]
	return dst


## Menskalakan buffer sehingga puncaknya tepat di peak (mencegah kliping keras).
static func _normalize(buf: PackedFloat32Array, peak: float) -> PackedFloat32Array:
	var m: float = 0.0
	for i in buf.size():
		m = maxf(m, absf(buf[i]))
	if m <= 0.00001:
		return buf
	var gain: float = peak / m
	for i in buf.size():
		buf[i] *= gain
	return buf


## Lowpass satu kutub (RC). Dipakai untuk menghangatkan bunyi agar tidak cempreng.
static func _lowpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	if cutoff <= 0.0:
		return buf
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var rc: float = 1.0 / (TAU * cutoff)
	var a: float = dt / (rc + dt)
	var y: float = 0.0
	for i in buf.size():
		y += a * (buf[i] - y)
		buf[i] = y
	return buf


## Highpass satu kutub (RC). Dipakai bersama lowpass untuk derau pita terbatas.
static func _highpass(buf: PackedFloat32Array, cutoff: float) -> PackedFloat32Array:
	if cutoff <= 0.0:
		return buf
	var dt: float = 1.0 / float(SAMPLE_RATE)
	var rc: float = 1.0 / (TAU * cutoff)
	var a: float = rc / (rc + dt)
	var prev_in: float = 0.0
	var prev_out: float = 0.0
	for i in buf.size():
		var x: float = buf[i]
		var y: float = a * (prev_out + x - prev_in)
		buf[i] = y
		prev_in = x
		prev_out = y
	return buf


# ---------------------------------------------------------------------------
# Amplop ADSR & bentuk gelombang
# ---------------------------------------------------------------------------

## Menormalkan Dictionary ADSR menjadi larik cepat
## [attack, decay, sustain, release, release_start]. Bila attack+decay+release
## melebihi durasi nada, ketiganya dikecilkan proporsional agar amplop utuh.
static func _env_norm(dur: float, env: Dictionary) -> PackedFloat32Array:
	var atk: float = maxf(0.0, float(env.get("attack", 0.005)))
	var dec: float = maxf(0.0, float(env.get("decay", 0.05)))
	var sus: float = clampf(float(env.get("sustain", 0.6)), 0.0, 1.0)
	var rel: float = maxf(0.0, float(env.get("release", 0.05)))
	var total: float = atk + dec + rel
	if total > dur and total > 0.0:
		var k: float = dur / total
		atk *= k
		dec *= k
		rel *= k
	var out: PackedFloat32Array = PackedFloat32Array()
	out.resize(5)
	out[0] = atk
	out[1] = dec
	out[2] = sus
	out[3] = rel
	out[4] = maxf(0.0, dur - rel)
	return out


## Nilai amplop pada detik t.
static func _env_at(e: PackedFloat32Array, t: float) -> float:
	var atk: float = e[0]
	var dec: float = e[1]
	var sus: float = e[2]
	var rel: float = e[3]
	var rel_start: float = e[4]
	if t < atk and atk > 0.0:
		return t / atk
	if t < atk + dec and dec > 0.0:
		return lerpf(1.0, sus, (t - atk) / dec)
	if t < rel_start:
		return sus
	if rel > 0.0:
		return sus * clampf(1.0 - (t - rel_start) / rel, 0.0, 1.0)
	return 0.0


## Nilai gelombang pada fase (dalam satuan putaran penuh). Bentuk di luar daftar
## diperlakukan sebagai "sine". Sinus, segitiga, dan gigi gergaji sama-sama
## dimulai dari nol supaya tidak ada letupan di awal nada.
static func _wave_at(wave: String, phase: float) -> float:
	var p: float = fposmod(phase, 1.0)
	var v: float = 0.0
	match wave:
		"triangle":
			v = 1.0 - 4.0 * absf(fposmod(p + 0.25, 1.0) - 0.5)
		"square":
			v = 1.0 if p < 0.5 else -1.0
		"saw":
			v = 2.0 * fposmod(p + 0.5, 1.0) - 1.0
		"noise":
			v = _noise_rng().randf_range(-1.0, 1.0)
		_:
			v = sin(TAU * p)
	return v


# ---------------------------------------------------------------------------
# Blok penyusun bunyi
# ---------------------------------------------------------------------------

## Menambahkan satu osilator (boleh menyapu frekuensi f0 menuju f1) ke buffer.
static func _add_osc(buf: PackedFloat32Array, start_sec: float, dur: float, f0: float,
		f1: float, wave: String, amp: float, env: Dictionary) -> PackedFloat32Array:
	var n: int = buf.size()
	var count: int = int(round(dur * float(SAMPLE_RATE)))
	if n <= 0 or count <= 0:
		return buf
	var i0: int = int(round(start_sec * float(SAMPLE_RATE)))
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var e: PackedFloat32Array = _env_norm(dur, env)
	var phase: float = 0.0
	for k in count:
		var idx: int = i0 + k
		if idx >= n:
			break
		var t: float = float(k) * inv
		if idx >= 0:
			buf[idx] += _wave_at(wave, phase) * _env_at(e, t) * amp
		phase += lerpf(f0, f1, float(k) / float(count)) * inv
	return buf


## Menambahkan satu partial lonceng: sinus murni berpeluruhan eksponensial.
static func _add_bell(buf: PackedFloat32Array, start_sec: float, dur: float, freq: float,
		amp: float, decay_rate: float) -> PackedFloat32Array:
	var n: int = buf.size()
	var count: int = int(round(dur * float(SAMPLE_RATE)))
	if n <= 0 or count <= 0:
		return buf
	var i0: int = int(round(start_sec * float(SAMPLE_RATE)))
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var tbl: PackedFloat32Array = _sine_table()
	var phase: float = 0.0
	var step: float = freq * inv
	var env: float = 1.0
	var env_mul: float = exp(-decay_rate * inv)
	var attack: float = 0.0025
	var fade_len: float = 0.05
	var fade_start: float = maxf(0.0, dur - fade_len)
	for k in count:
		var idx: int = i0 + k
		if idx >= n:
			break
		var t: float = float(k) * inv
		var a: float = env * amp
		if t < attack:
			a *= t / attack
		if t > fade_start:
			a *= maxf(0.0, 1.0 - (t - fade_start) / fade_len)
		if idx >= 0:
			buf[idx] += a * tbl[int(phase * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		phase += step
		env *= env_mul
	return buf


## Derau putih sepanjang dur yang disaring menjadi pita hp..lp lalu diberi amplop.
static func _noise_buffer(dur: float, amp: float, env: Dictionary, hp: float,
		lp: float) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _new_buffer(dur)
	var rng: RandomNumberGenerator = _noise_rng()
	var n: int = buf.size()
	for i in n:
		buf[i] = rng.randf_range(-1.0, 1.0)
	buf = _highpass(buf, hp)
	buf = _lowpass(buf, lp)
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var e: PackedFloat32Array = _env_norm(dur, env)
	for i in n:
		buf[i] *= _env_at(e, float(i) * inv) * amp
	return buf


# ---------------------------------------------------------------------------
# API publik: nada generik
# ---------------------------------------------------------------------------

## Membangun satu nada tunggal.
## wave: "sine" | "triangle" | "square" | "saw" | "noise".
## env: {attack, decay, sustain, release} dengan attack/decay/release dalam
## detik dan sustain berupa rasio 0..1.
static func tone(freq: float, dur: float, wave: String, env: Dictionary) -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(dur)
	buf = _add_osc(buf, 0.0, dur, freq, freq, wave, 1.0, env)
	buf = _normalize(buf, 0.85)
	return _to_stream(buf, false)


# ---------------------------------------------------------------------------
# API publik: bunyi bernama (GDD 3.6.A, 4.1, 7)
# ---------------------------------------------------------------------------

## "Soft wooden tap" (GDD 7) — bunyi baku setiap tombol UI.
## Semburan derau tersaring (badan kayu) + dentuman segitiga rendah, ~70 ms.
## Sengaja di-lowpass supaya terasa hangat, bukan klik plastik yang cempreng.
static func wooden_tap() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.07)
	var body: PackedFloat32Array = _noise_buffer(0.042, 0.60,
			{"attack": 0.0012, "decay": 0.026, "sustain": 0.0, "release": 0.014},
			320.0, 2300.0)
	buf = _mix_into(buf, body, 0.0)
	buf = _add_osc(buf, 0.0, 0.07, 196.0, 152.0, "triangle", 0.58,
			{"attack": 0.002, "decay": 0.034, "sustain": 0.14, "release": 0.03})
	buf = _lowpass(buf, 3800.0)
	buf = _normalize(buf, 0.82)
	return _to_stream(buf, false)


## "Sweet bubble pop" (GDD 7) — konfirmasi manis.
## Sapuan sinus naik 420 Hz menuju 1180 Hz dengan peluruhan cepat, ~90 ms.
static func bubble_pop() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.09)
	buf = _add_osc(buf, 0.0, 0.09, 420.0, 1180.0, "sine", 0.92,
			{"attack": 0.004, "decay": 0.028, "sustain": 0.42, "release": 0.05})
	buf = _add_osc(buf, 0.028, 0.055, 1580.0, 2360.0, "sine", 0.16,
			{"attack": 0.003, "decay": 0.02, "sustain": 0.2, "release": 0.03})
	buf = _normalize(buf, 0.88)
	return _to_stream(buf, false)


## "Ting! mekanis oven tua" (GDD 4.1) — penanda roti matang.
## Lonceng dua partial: dasar 932.33 Hz + partial 2.76x, peluruhan eksponensial
## panjang, ditambah klik pegas mekanis agar terasa oven jadul.
static func oven_ting() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(1.10)
	buf = _add_bell(buf, 0.0, 1.10, 932.33, 0.80, 4.0)
	buf = _add_bell(buf, 0.0, 0.70, 932.33 * 2.76, 0.30, 7.0)
	var klik: PackedFloat32Array = _noise_buffer(0.014, 0.30,
			{"attack": 0.0005, "decay": 0.007, "sustain": 0.0, "release": 0.005},
			900.0, 5200.0)
	buf = _mix_into(buf, klik, 0.0)
	buf = _normalize(buf, 0.78)
	return _to_stream(buf, false)


## Gemerincing koin masuk kas — arpeggio segitiga tiga nada menaik (C6-E6-G6).
static func coin_chime() -> AudioStreamWAV:
	const NOTES: Array = [1046.502, 1318.510, 1567.982]
	var gap: float = 0.055
	var note_dur: float = 0.24
	var buf: PackedFloat32Array = _new_buffer(gap * 2.0 + note_dur)
	for i in NOTES.size():
		var f: float = float(NOTES[i])
		buf = _add_osc(buf, gap * float(i), note_dur, f, f, "triangle", 0.45,
				{"attack": 0.003, "decay": 0.09, "sustain": 0.22, "release": 0.14})
	buf = _lowpass(buf, 7000.0)
	buf = _normalize(buf, 0.85)
	return _to_stream(buf, false)


## "Gemerisik bungkus kertas roti" (GDD 4.1) — dipakai saat mengemas paper bag.
## Derau pita terbatas 1300-6200 Hz dengan goyangan amplitudo, ~250 ms.
static func paper_rustle() -> AudioStreamWAV:
	var dur: float = 0.25
	var buf: PackedFloat32Array = _new_buffer(dur)
	var rng: RandomNumberGenerator = _noise_rng()
	var n: int = buf.size()
	for i in n:
		buf[i] = rng.randf_range(-1.0, 1.0)
	buf = _highpass(buf, 1300.0)
	buf = _lowpass(buf, 6200.0)
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var e: PackedFloat32Array = _env_norm(dur,
			{"attack": 0.03, "decay": 0.06, "sustain": 0.70, "release": 0.10})
	for i in n:
		var t: float = float(i) * inv
		# Dua goyangan (17 Hz dan 6 Hz) meniru kertas yang diremas pelan-pelan.
		var wobble: float = 0.55 + 0.30 * sin(TAU * 17.0 * t) + 0.15 * sin(TAU * 6.0 * t + 1.1)
		buf[i] *= _env_at(e, t) * wobble
	buf = _normalize(buf, 0.55)
	return _to_stream(buf, false)


## Klik pintu/laci: sangat pendek dan kering, dengan dentum mid-rendah yang
## terasa memuaskan (bukan klik tipis), ~55 ms.
static func door_click() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.055)
	var tick: PackedFloat32Array = _noise_buffer(0.011, 0.55,
			{"attack": 0.0004, "decay": 0.006, "sustain": 0.0, "release": 0.004},
			1100.0, 5600.0)
	buf = _mix_into(buf, tick, 0.0)
	buf = _add_osc(buf, 0.002, 0.05, 236.0, 168.0, "sine", 0.70,
			{"attack": 0.0015, "decay": 0.022, "sustain": 0.08, "release": 0.026})
	buf = _lowpass(buf, 5200.0)
	buf = _normalize(buf, 0.80)
	return _to_stream(buf, false)


## Notifikasi RotiFood (GDD 3.6.A) — "ting-ting-ting!".
## Tiga lonceng pendek yang identik dan beruntun cepat (jarak 135 ms).
static func chime_alert() -> AudioStreamWAV:
	var gap: float = 0.135
	var one: float = 0.28
	var base: float = 1396.913
	var buf: PackedFloat32Array = _new_buffer(gap * 2.0 + one)
	for i in 3:
		var t0: float = gap * float(i)
		buf = _add_bell(buf, t0, one, base, 0.62, 9.0)
		buf = _add_bell(buf, t0, one * 0.6, base * 2.76, 0.20, 13.0)
	buf = _normalize(buf, 0.82)
	return _to_stream(buf, false)


## Nada sedih lembut (pelanggan pergi marah / pesanan RotiFood batal).
## Terts minor menurun C5 ke A4 pada sinus empuk, dilapis oktaf bawah dan
## di-lowpass 2400 Hz supaya tidak pernah terdengar menusuk telinga.
static func sad_soft() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.72)
	var soft: Dictionary = {"attack": 0.05, "decay": 0.10, "sustain": 0.55, "release": 0.18}
	buf = _add_osc(buf, 0.0, 0.40, 523.251, 523.251, "sine", 0.62, soft)
	buf = _add_osc(buf, 0.0, 0.40, 261.626, 261.626, "sine", 0.18, soft)
	buf = _add_osc(buf, 0.30, 0.42, 440.0, 440.0, "sine", 0.62, soft)
	buf = _add_osc(buf, 0.30, 0.42, 220.0, 220.0, "sine", 0.18, soft)
	buf = _lowpass(buf, 2400.0)
	buf = _normalize(buf, 0.62)
	return _to_stream(buf, false)


# ---------------------------------------------------------------------------
# API publik: bed musik bossa nova lo-fi (GDD 4.1)
# ---------------------------------------------------------------------------

## Satu nada Rhodes: tumpukan sinus yang sedikit detune dengan serangan empuk.
## bass = true memakai peluruhan lebih lambat dan tanpa partial "tine".
static func _rhodes_note(freq: float, dur: float, amp: float, bass: bool) -> PackedFloat32Array:
	var out: PackedFloat32Array = _new_buffer(dur)
	var n: int = out.size()
	if n <= 0 or amp <= 0.0:
		return out
	var tbl: PackedFloat32Array = _sine_table()
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var attack: float = 0.045 if bass else 0.060
	var decay_rate: float = 1.30 if bass else 1.90
	var tine_amp: float = 0.0 if bass else 0.20
	var phase_a: float = 0.0
	var phase_b: float = 0.0
	var phase_c: float = 0.0
	var step_a: float = freq * inv
	var step_b: float = freq * 1.0032 * inv
	var step_c: float = freq * 2.0 * inv
	var env: float = 1.0
	var env_mul: float = exp(-decay_rate * inv)
	var tine: float = 1.0
	var tine_mul: float = exp(-5.2 * inv)
	var fade_len: float = 0.09
	var fade_start: float = maxf(0.0, dur - fade_len)
	for i in n:
		var t: float = float(i) * inv
		var a: float = env * amp
		if t < attack:
			a *= t / attack
		if t > fade_start:
			a *= maxf(0.0, 1.0 - (t - fade_start) / fade_len)
		var v: float = tbl[int(phase_a * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		v += 0.62 * tbl[int(phase_b * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		if tine_amp > 0.0:
			v += tine_amp * tine * tbl[int(phase_c * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		out[i] = v * a
		phase_a += step_a
		phase_b += step_b
		phase_c += step_c
		env *= env_mul
		tine *= tine_mul
	return out


## Satu petikan gitar nilon: serangan sangat singkat, peluruhan cepat, dan hanya
## beberapa harmonik (1x, 2x, 3x) agar terdengar lembut dan berkarakter kayu.
static func _nylon_note(freq: float, dur: float, amp: float) -> PackedFloat32Array:
	var out: PackedFloat32Array = _new_buffer(dur)
	var n: int = out.size()
	if n <= 0 or amp <= 0.0:
		return out
	var tbl: PackedFloat32Array = _sine_table()
	var inv: float = 1.0 / float(SAMPLE_RATE)
	var attack: float = 0.004
	var phase_a: float = 0.0
	var phase_b: float = 0.0
	var phase_c: float = 0.0
	var step_a: float = freq * inv
	var step_b: float = freq * 2.0 * inv
	var step_c: float = freq * 3.0 * inv
	var env_a: float = 1.0
	var env_b: float = 1.0
	var env_c: float = 1.0
	var mul_a: float = exp(-4.6 * inv)
	var mul_b: float = exp(-7.4 * inv)
	var mul_c: float = exp(-10.5 * inv)
	var fade_len: float = 0.06
	var fade_start: float = maxf(0.0, dur - fade_len)
	for i in n:
		var t: float = float(i) * inv
		var g: float = amp
		if t < attack:
			g *= t / attack
		if t > fade_start:
			g *= maxf(0.0, 1.0 - (t - fade_start) / fade_len)
		var v: float = env_a * tbl[int(phase_a * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		v += 0.40 * env_b * tbl[int(phase_b * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		v += 0.18 * env_c * tbl[int(phase_c * float(SINE_TABLE_SIZE)) & SINE_TABLE_MASK]
		out[i] = v * g
		phase_a += step_a
		phase_b += step_b
		phase_c += step_c
		env_a *= mul_a
		env_b *= mul_b
		env_c *= mul_c
	return out


## Bed musik bossa nova lo-fi yang siap diulang tanpa sambungan.
##
## Progresi ii-V-I-VI (2 ketuk per akor, total 8 ketuk) dimainkan oleh dua suara:
## Rhodes (sinus bertumpuk sedikit detune) dan petikan gitar nilon. Ekor setiap
## nada dibungkus kembali ke awal buffer sehingga loop terdengar mulus.
##
## Bed terpanjang ("rain", 64 BPM) hanya 7.5 detik, jadi bundel web tetap kecil.
## AudioBus membangkitkannya secara lazy pada start_music() pertama, bukan di
## _ready(), supaya waktu mulai game tidak tertahan.
static func music_bed(mood: String) -> AudioStreamWAV:
	var key: String = mood if MUSIC_MOODS.has(mood) else "cozy"
	var cfg: Dictionary = MUSIC_MOODS[key]
	var beat: float = 60.0 / float(cfg["bpm"])
	var chord_beats: float = 2.0
	var total_sec: float = chord_beats * float(PROGRESSION.size()) * beat
	var buf: PackedFloat32Array = _new_buffer(total_sec)
	var root_hz: float = MUSIC_ROOT_HZ * pow(2.0, float(cfg["root"]) / 12.0)
	var rhodes_amp: float = float(cfg["rhodes"])
	var guitar_amp: float = float(cfg["guitar"])
	var pluck: Array = cfg["pluck"]
	var hold: float = chord_beats * beat + beat * 1.1

	for ci in PROGRESSION.size():
		var chord: Dictionary = PROGRESSION[ci]
		var ivals: Array = chord["ivals"]
		var chord_root: float = root_hz * pow(2.0, float(chord["deg"]) / 12.0)
		var t0: float = float(ci) * chord_beats * beat

		# Rhodes: akar di bass ditambah tiga nada akor satu oktaf di atasnya.
		# Onset tiap suara digeser sedikit agar terdengar seperti jari manusia.
		buf = _add_wrapped(buf, _rhodes_note(chord_root, hold, rhodes_amp * 0.85, true), t0)
		for vi in range(1, ivals.size()):
			var f: float = chord_root * 2.0 * pow(2.0, float(ivals[vi]) / 12.0)
			buf = _add_wrapped(buf, _rhodes_note(f, hold, rhodes_amp * 0.42, false),
					t0 + 0.012 * float(vi))

		# Gitar nilon: pola petikan sinkopasi khas bossa nova.
		for pi in pluck.size():
			var ival: int = int(ivals[1 + (pi % 3)])
			var gf: float = chord_root * 2.0 * pow(2.0, float(ival) / 12.0)
			if pi % 2 == 1:
				gf *= 2.0
			buf = _add_wrapped(buf, _nylon_note(gf, beat * 1.15, guitar_amp * 0.50),
					t0 + float(pluck[pi]) * beat)

	# Lowpass lembut memberi karakter lo-fi kaset era 2000-an (GDD 4.1).
	buf = _lowpass(buf, float(cfg["tone"]))
	buf = _normalize(buf, 0.58)
	return _to_stream(buf, true)
