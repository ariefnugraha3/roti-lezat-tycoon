class_name AudioGenerator
extends RefCounted

## AudioGenerator — pembangkit audio 100% prosedural untuk Crumbtown.
##
## Proyek ini TIDAK memuat satu pun berkas audio (.ogg/.wav/.mp3). Seluruh bunyi
## dihitung sebagai sampel PCM di dalam GDScript lalu dibungkus menjadi
## AudioStreamWAV 16-bit mono (GDD 33.5, 111.1). Skrip inilah provenance-nya:
## setiap event di data/catalog/audio_events.json menunjuk satu resep di
## `build()`. Hasilnya boleh disimpan di cache disk (AudioCache, v3.1 111.1).
##
## Hemat CPU untuk HP kentang (Seksi 20 no. 108): osilator, amplop, dan derau
## dihitung tanpa pemanggilan fungsi atau `match` per sampel; ambience yang
## isinya rendah (jalan, ruang, oven, mixer, lonceng menara) dirakit di 11025 Hz
## (separuh biaya dan memori); bunyi UI dan lonceng tetap 22050 Hz supaya jernih.
##
## Semua fungsi bersifat static dan tidak bergantung pada autoload mana pun.

## Laju cuplik bunyi UI, lonceng, dan efek. 22050 Hz cukup untuk palet foley
## hangat dan menekan biaya hitung di ponsel maupun browser.
const SAMPLE_RATE: int = 22050
## Laju cuplik ambience yang isinya di bawah ~5 kHz (lihat AMBIENT_RECIPES).
const AMBIENT_RATE: int = 11025
const AMBIENT_RECIPES: Array[String] = [
	"street_t1", "street_t2", "street_t3", "street_t4", "street_t5", "room_tone", "sunny_ambience",
	"oven_loop", "mixer_loop", "clock_chime",
]
## Sampel cadangan setelah ujung setiap stream. Interpolasi mixer Godot membaca
## beberapa sampel melewati titik loop atau akhir bunyi; di Android buffer besar
## berakhir tepat sebelum halaman memori pelindung, jadi tanpa cadangan ini
## thread audio crash (SIGSEGV di AudioTrack) begitu loop ambience berputar
## (GDD idle 20 no. 66). Loop mendapat salinan sampel awalnya (sambungan tetap
## mulus), bunyi sekali-putar mendapat keheningan. loop_end tetap di ujung asli.
const TAIL_PAD: int = 16

## Benih derau tetap agar bunyi selalu identik di setiap sesi (kami tidak
## memakai randf() global sesuai aturan proyek).
const NOISE_SEED: int = 20260418

## Tabel sinus untuk jalur panas. Pencarian tabel jauh lebih murah daripada
## memanggil sin() jutaan kali dari GDScript.
const SINE_TABLE_SIZE: int = 4096
const SINE_TABLE_MASK: int = 4095

## Nada acuan bass musik: F3 (174.614 Hz), nada dasar hangat sesuai GDD 4.1.
const MUSIC_ROOT_HZ: float = 174.614

## Progresi bossa nova ii - V - I - VI (di F mayor: Gm7 - C7 - Fmaj7 - Dm7),
## dipakai lagu trailer. Bed musik game memakai SongBuild.CHORDS/MOODS.
## "deg" = jarak semitone akar akor dari nada dasar; "ivals" = interval akor.
const PROGRESSION: Array = [
	{"deg": 2, "ivals": [0, 3, 7, 10]},
	{"deg": 7, "ivals": [0, 4, 7, 10]},
	{"deg": 0, "ivals": [0, 4, 7, 11]},
	{"deg": 9, "ivals": [0, 3, 7, 10]},
]

const WAVES: Dictionary = {"sine": 0, "triangle": 1, "square": 2, "saw": 3, "noise": 4}

static var _sine_cache: PackedFloat32Array = PackedFloat32Array()
static var _rng: RandomNumberGenerator = null
## Laju cuplik resep yang sedang dirakit (SAMPLE_RATE di luar `build()`).
static var _rate: int = SAMPLE_RATE


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


## Generator acak khusus derau dengan benih tetap: bunyi selalu identik dan
## tidak pernah menyentuh stream RNG gameplay (GDD 116).
static func _noise_rng() -> RandomNumberGenerator:
	if _rng == null:
		_rng = RandomNumberGenerator.new()
		_rng.seed = NOISE_SEED
	return _rng


## Laju cuplik resep `generator_id`.
static func rate_for(generator_id: String) -> int:
	return AMBIENT_RATE if AMBIENT_RECIPES.has(generator_id) else SAMPLE_RATE


# ---------------------------------------------------------------------------
# Utilitas buffer
# ---------------------------------------------------------------------------

## Buffer sampel float kosong sepanjang dur detik.
static func _new_buffer(dur: float) -> PackedFloat32Array:
	var n: int = maxi(1, int(round(dur * float(_rate))))
	var buf: PackedFloat32Array = PackedFloat32Array()
	buf.resize(n)
	buf.fill(0.0)
	return buf


## Mengubah buffer float (-1..1) menjadi AudioStreamWAV 16-bit mono.
static func _to_stream(buf: PackedFloat32Array, looping: bool) -> AudioStreamWAV:
	var n: int = buf.size()
	var data: PackedByteArray = PackedByteArray()
	data.resize((n + TAIL_PAD) * 2)
	for i in n:
		data.encode_s16(i * 2, int(clampf(buf[i], -1.0, 1.0) * 32767.0))
	pad_tail(data, n, looping)
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = _rate
	stream.stereo = false
	stream.data = data
	if looping:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = n
	else:
		stream.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return stream


## Isi TAIL_PAD sampel setelah sampel ke-`n` di `data` (16-bit mono): salinan
## awal untuk loop, nol untuk bunyi sekali-putar.
static func pad_tail(data: PackedByteArray, n: int, looping: bool) -> void:
	for k in TAIL_PAD:
		data.encode_s16((n + k) * 2, data.decode_s16((k % n) * 2) if looping and n > 0 else 0)


## Menjumlahkan src ke dalam dst mulai detik start_sec (dipotong di ujung buffer).
static func _mix_into(dst: PackedFloat32Array, src: PackedFloat32Array,
		start_sec: float) -> PackedFloat32Array:
	var n: int = dst.size()
	var i0: int = int(round(start_sec * float(_rate)))
	for k in src.size():
		var idx: int = i0 + k
		if idx < 0:
			continue
		if idx >= n:
			break
		dst[idx] += src[k]
	return dst


## Seperti _mix_into, tetapi ekor nada dibungkus kembali ke awal buffer. Inilah
## kunci agar loop dapat berulang tanpa sambungan yang terdengar.
static func _add_wrapped(dst: PackedFloat32Array, src: PackedFloat32Array,
		start_sec: float) -> PackedFloat32Array:
	var n: int = dst.size()
	if n <= 0:
		return dst
	var idx: int = posmod(int(round(start_sec * float(_rate))), n)
	for k in src.size():
		dst[idx] += src[k]
		idx += 1
		if idx >= n:
			idx = 0
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
	var dt: float = 1.0 / float(_rate)
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
	var dt: float = 1.0 / float(_rate)
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


## Ruang kecil yang hangat: empat pantulan awal (17-61 ms) yang makin pelan,
## supaya bunyi UI dan lonceng terasa terdengar di dalam toko, bukan di ruang
## hampa. Buffer diperpanjang 70 ms untuk pantulan terakhir.
static func _room(buf: PackedFloat32Array, amount: float) -> PackedFloat32Array:
	var sr: float = float(_rate)
	var n: int = buf.size()
	var dry: PackedFloat32Array = buf.duplicate()
	var extra: int = int(0.07 * sr)
	buf.resize(n + extra)
	for i in range(n, n + extra):
		buf[i] = 0.0
	for tap: Array in [[0.017, 0.24], [0.029, 0.16], [0.043, 0.11], [0.061, 0.07]]:
		var d: int = int(float(tap[0]) * sr)
		var g: float = float(tap[1]) * amount
		for k in n:
			buf[k + d] += dry[k] * g
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


## Nilai amplop pada detik t (untuk resep yang menghitung sendiri per sampel).
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


## Kalikan `buf` dengan amplop ADSR sepanjang `dur` detik dan `amp`, dihitung
## langsung di loop (tanpa pemanggilan fungsi per sampel).
static func _apply_env(buf: PackedFloat32Array, dur: float, env: Dictionary, amp: float) -> void:
	var sr: float = float(_rate)
	var e: PackedFloat32Array = _env_norm(dur, env)
	var atk: float = e[0] * sr
	var dec: float = e[1] * sr
	var sus: float = e[2]
	var rel: float = e[3] * sr
	var rel_start: float = e[4] * sr
	for i in buf.size():
		var t: float = float(i)
		var g: float = sus
		if t < atk:
			g = t / atk
		elif t < atk + dec:
			g = 1.0 + (sus - 1.0) * (t - atk) / dec
		elif t >= rel_start:
			g = sus * maxf(0.0, 1.0 - (t - rel_start) / rel) if rel > 0.0 else 0.0
		buf[i] *= g * amp


# ---------------------------------------------------------------------------
# Blok penyusun bunyi
# ---------------------------------------------------------------------------

## Menambahkan satu osilator (boleh menyapu frekuensi f0 menuju f1) ke buffer.
## wave: "sine" | "triangle" | "square" | "saw" | "noise".
static func _add_osc(buf: PackedFloat32Array, start_sec: float, dur: float, f0: float,
		f1: float, wave: String, amp: float, env: Dictionary) -> PackedFloat32Array:
	var sr: float = float(_rate)
	var n: int = buf.size()
	var count: int = int(round(dur * sr))
	if n <= 0 or count <= 0:
		return buf
	var i0: int = int(round(start_sec * sr))
	var e: PackedFloat32Array = _env_norm(dur, env)
	var atk: float = e[0] * sr
	var dec: float = e[1] * sr
	var sus: float = e[2]
	var rel: float = e[3] * sr
	var rel_start: float = e[4] * sr
	var code: int = int(WAVES.get(wave, 0))
	var tbl: PackedFloat32Array = _sine_table()
	var rng: RandomNumberGenerator = _noise_rng()
	var inv: float = 1.0 / sr
	var df: float = (f1 - f0) / float(count)
	var f: float = f0
	var phase: float = 0.0
	for k in count:
		var idx: int = i0 + k
		if idx >= n:
			break
		if idx >= 0:
			var t: float = float(k)
			var g: float = sus
			if t < atk:
				g = t / atk
			elif t < atk + dec:
				g = 1.0 + (sus - 1.0) * (t - atk) / dec
			elif t >= rel_start:
				g = sus * maxf(0.0, 1.0 - (t - rel_start) / rel) if rel > 0.0 else 0.0
			var p: float = phase - floorf(phase)
			var w: float = 0.0
			if code == 0:
				w = tbl[int(p * 4096.0) & SINE_TABLE_MASK]
			elif code == 1:
				var q: float = p + 0.25
				q -= floorf(q)
				w = 1.0 - 4.0 * absf(q - 0.5)
			elif code == 2:
				w = 1.0 if p < 0.5 else -1.0
			elif code == 3:
				var q2: float = p + 0.5
				q2 -= floorf(q2)
				w = 2.0 * q2 - 1.0
			else:
				w = rng.randf_range(-1.0, 1.0)
			buf[idx] += w * g * amp
		phase += f * inv
		f += df
	return buf


## Menambahkan satu partial lonceng: sinus murni berpeluruhan eksponensial.
static func _add_bell(buf: PackedFloat32Array, start_sec: float, dur: float, freq: float,
		amp: float, decay_rate: float) -> PackedFloat32Array:
	var sr: float = float(_rate)
	var n: int = buf.size()
	var count: int = int(round(dur * sr))
	if n <= 0 or count <= 0:
		return buf
	var i0: int = int(round(start_sec * sr))
	var inv: float = 1.0 / sr
	var tbl: PackedFloat32Array = _sine_table()
	var phase: float = 0.0
	var step: float = freq * inv
	var env: float = amp
	var env_mul: float = exp(-decay_rate * inv)
	var attack: int = maxi(1, int(0.0025 * sr))
	var fade_len: int = maxi(1, int(0.05 * sr))
	var fade_start: int = maxi(0, count - fade_len)
	for k in count:
		var idx: int = i0 + k
		if idx >= n:
			break
		var a: float = env
		if k < attack:
			a *= float(k) / float(attack)
		elif k > fade_start:
			a *= maxf(0.0, float(count - k) / float(fade_len))
		if idx >= 0:
			buf[idx] += a * tbl[int(phase * 4096.0) & SINE_TABLE_MASK]
		phase += step
		env *= env_mul
	return buf


## Benda bergetar: beberapa partial [rasio frekuensi, amplitudo, peluruhan/detik]
## dari nada `freq` (lonceng, bilah marimba, kayu).
static func _add_modal(buf: PackedFloat32Array, start_sec: float, dur: float, freq: float,
		amp: float, partials: Array) -> PackedFloat32Array:
	for pt: Array in partials:
		var f: float = freq * float(pt[0])
		if f < float(_rate) * 0.45:
			buf = _add_bell(buf, start_sec, dur, f, amp * float(pt[1]), float(pt[2]))
	return buf


## Bilah marimba kayu: dasar hangat, parsial 4x dan 10x yang cepat hilang.
const MARIMBA: Array = [[1.0, 1.0, 7.0], [3.93, 0.16, 26.0], [9.2, 0.04, 60.0]]
## Glockenspiel / lonceng kecil: parsial tak harmonis yang berkilau.
const GLOCK: Array = [[1.0, 1.0, 4.5], [2.76, 0.28, 8.0], [5.4, 0.09, 14.0]]
## Bel toko di pintu: tiga parsial lonceng kecil.
const SHOP_BELL: Array = [[1.0, 1.0, 5.5], [2.32, 0.3, 10.0], [4.1, 0.12, 18.0]]


## Derau putih sepanjang dur yang disaring menjadi pita hp..lp lalu diberi amplop.
## `rng` = generator derau milik pemanggil (MusicBuild); bawaannya derau bersama.
static func _noise_buffer(dur: float, amp: float, env: Dictionary, hp: float,
		lp: float, rng: RandomNumberGenerator = null) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _new_buffer(dur)
	if rng == null:
		rng = _noise_rng()
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0)
	buf = _highpass(buf, hp)
	buf = _lowpass(buf, lp)
	_apply_env(buf, dur, env, amp)
	return buf


## Ketukan kayu pendek (badan "tok" + klik), dipakai bunyi UI.
static func _wood(buf: PackedFloat32Array, at: float, freq: float, amp: float) -> PackedFloat32Array:
	buf = _add_bell(buf, at, 0.09, freq, 0.55 * amp, 45.0)
	buf = _add_bell(buf, at, 0.05, freq * 3.9, 0.15 * amp, 120.0)
	buf = _add_bell(buf, at, 0.07, freq * 0.3, 0.3 * amp, 55.0)
	var click: PackedFloat32Array = _noise_buffer(0.006, 0.26 * amp,
			{"attack": 0.0004, "decay": 0.003, "sustain": 0.0, "release": 0.002}, 600.0, 3500.0)
	return _mix_into(buf, click, at)


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

## "Soft wooden tap" (GDD 7) — bunyi baku setiap tombol UI: "tok" bilah kayu
## yang hangat (dasar 640 Hz, parsial 3,9x yang cepat hilang, dentum badan
## rendah, klik halus) di ruang kecil. AudioManager menggeser nadanya sedikit
## tiap kali dibunyikan supaya ketukan beruntun tidak terdengar seperti mesin.
static func wooden_tap() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.09)
	buf = _wood(buf, 0.0, 640.0, 1.0)
	buf = _lowpass(buf, 5200.0)
	buf = _room(buf, 0.5)
	return _to_stream(_normalize(buf, 0.8), false)


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


## "Ting! mekanis oven tua" (GDD 4.1) — penanda roti matang: lonceng pengatur
## waktu dapur dengan parsial tak harmonis (2,76x dan 5,4x), kembaran dasar yang
## sedikit fals sehingga dentingnya berkilau, dan klik pegas mekanis.
static func oven_ting() -> AudioStreamWAV:
	var f: float = 932.33
	var buf: PackedFloat32Array = _new_buffer(1.2)
	buf = _add_bell(buf, 0.0, 1.2, f, 0.7, 3.4)
	buf = _add_bell(buf, 0.0, 1.2, f * 1.0045, 0.25, 3.6)
	buf = _add_bell(buf, 0.0, 0.8, f * 2.76, 0.28, 6.0)
	buf = _add_bell(buf, 0.0, 0.5, f * 5.4, 0.1, 10.0)
	var klik: PackedFloat32Array = _noise_buffer(0.014, 0.30,
			{"attack": 0.0005, "decay": 0.007, "sustain": 0.0, "release": 0.005},
			900.0, 5200.0)
	buf = _mix_into(buf, klik, 0.0)
	buf = _room(buf, 0.35)
	return _to_stream(_normalize(buf, 0.78), false)


## Gemerincing koin masuk kas: dua koin logam beradu ("cling-cling") dengan
## parsial tak harmonis yang pendek dan klik halus. Nadanya digeser sedikit
## tiap kali dibunyikan (AudioManager) supaya kasir yang ramai tidak monoton.
static func coin_chime() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.32)
	for hit: Array in [[0.0, 1.0, 1.0], [0.05, 1.122, 0.7]]:
		var at: float = float(hit[0])
		var f: float = 2320.0 * float(hit[1])
		var a: float = float(hit[2])
		buf = _add_bell(buf, at, 0.27, f, 0.45 * a, 18.0)
		buf = _add_bell(buf, at, 0.2, f * 1.58, 0.25 * a, 24.0)
		buf = _add_bell(buf, at, 0.12, f * 2.51, 0.12 * a, 38.0)
		var tick: PackedFloat32Array = _noise_buffer(0.004, 0.2 * a,
				{"attack": 0.0003, "decay": 0.002, "sustain": 0.0, "release": 0.001}, 3000.0, 9000.0)
		buf = _mix_into(buf, tick, at)
	buf = _lowpass(buf, 9000.0)
	buf = _room(buf, 0.35)
	return _to_stream(_normalize(buf, 0.8), false)


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
	_apply_env(buf, dur, {"attack": 0.03, "decay": 0.06, "sustain": 0.70, "release": 0.10}, 1.0)
	var tbl: PackedFloat32Array = _sine_table()
	var inv: float = 1.0 / float(_rate)
	for i in n:
		var t: float = float(i) * inv
		# Dua goyangan (17 Hz dan 6 Hz) meniru kertas yang diremas pelan-pelan.
		buf[i] *= 0.55 + 0.30 * tbl[int(17.0 * t * 4096.0) & SINE_TABLE_MASK] + 0.15 * tbl[int((6.0 * t + 0.175) * 4096.0) & SINE_TABLE_MASK]
	return _to_stream(_normalize(buf, 0.55), false)


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
	return _to_stream(_normalize(buf, 0.80), false)


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
	buf = _room(buf, 0.3)
	return _to_stream(_normalize(buf, 0.82), false)


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
	return _to_stream(_normalize(buf, 0.62), false)


# ---------------------------------------------------------------------------
# API publik: bed musik bossa nova lo-fi (GDD 4.1)
# ---------------------------------------------------------------------------

## Bed musik yang siap diulang tanpa sambungan. Resep dan renderingnya ada di
## SongBuild, yang juga bisa membangunnya sedikit demi sedikit di sela frame
## (AudioManager, layar loading); jalur ini menyelesaikannya sekaligus.
static func music_bed(mood: String) -> AudioStreamWAV:
	var b := SongBuild.new()
	b.setup_song(mood if SongBuild.MOODS.has(mood) else "cozy")
	return b.finish_now()


# ---------------------------------------------------------------------------
# API publik: katalog event audio (GDD 93)
# ---------------------------------------------------------------------------

## Daftar resep yang dikenal `build()`; dipakai validator katalog.
const RECIPES: Array[String] = [
	"tap_soft", "confirm", "cancel", "error", "pause", "door_bell", "door_bell_light",
	"footstep", "storage_open", "storage_close", "mixer_start", "mixer_loop", "mixer_done",
	"oven_open", "oven_close", "oven_loop", "oven_ting",
	"place_display", "paper_rustle", "happy_chirp", "impatient_tap", "sad_soft", "coin_chime",
	"register_ding", "tablet_chime", "bag_seal", "handover_ping", "tablet_cancel",
	"sparkle_chime", "whoosh", "achievement_flourish",
	"upgrade_sting", "tap_pop", "truck_horn", "level_up", "milestone_fanfare", "coin_shower", "welcome_back_chime", "franchise_jingle", "rain_loop", "sunny_ambience", "room_tone",
	"street_t1", "street_t2", "street_t3", "street_t4", "street_t5", "clock_chime",
	"music_menu", "music_morning", "music_day", "music_busy_layer", "music_rain",
	"music_after_hours",
]


static func has_recipe(generator_id: String) -> bool:
	return RECIPES.has(generator_id)


## Membangun stream untuk satu resep. Benih derau direset per resep sehingga
## hasilnya identik berapa pun urutan pembangkitannya (reproducible provenance).
static func build(generator_id: String) -> AudioStreamWAV:
	_noise_rng().seed = NOISE_SEED + generator_id.hash()
	# Musik (bed & lapisan busy) dirakit SongBuild; lihat song_build.gd.
	var music: MusicBuild = MusicBuild.for_generator(generator_id)
	if music != null:
		return music.finish_now()
	_rate = rate_for(generator_id)
	var s: AudioStreamWAV = _build_recipe(generator_id)
	_rate = SAMPLE_RATE
	return s


static func _build_recipe(generator_id: String) -> AudioStreamWAV:
	match generator_id:
		"tap_soft":
			return wooden_tap()
		"confirm":
			return _confirm()
		"cancel":
			return _cancel()
		"error":
			return _error()
		"pause":
			return _cloth_muffle()
		"door_bell":
			return _door_bell(1.0, 1.0)
		"door_bell_light":
			return _door_bell(1.26, 0.6)
		"footstep":
			return _footstep()
		"storage_open":
			return _hinge(true)
		"storage_close":
			return _hinge(false)
		"mixer_start":
			return _mixer_start()
		"mixer_loop":
			return _mixer_loop()
		"mixer_done":
			return _mixer_done()
		"oven_open":
			return _oven_door(true)
		"oven_close":
			return _oven_door(false)
		"oven_loop":
			return _oven_loop()
		"oven_ting":
			return oven_ting()
		"place_display":
			return _place_display()
		"paper_rustle":
			return paper_rustle()
		"happy_chirp":
			return _happy_chirp()
		"impatient_tap":
			return _impatient_tap()
		"sad_soft":
			return sad_soft()
		"coin_chime":
			return coin_chime()
		"register_ding":
			return _register_ding()
		"tablet_chime":
			return chime_alert()
		"bag_seal":
			return _bag_seal()
		"handover_ping":
			return _handover_ping()
		"tablet_cancel":
			return _tablet_cancel()
		"sparkle_chime":
			return _sparkle_chime()
		"whoosh":
			return _whoosh()
		"achievement_flourish":
			return _flourish()
		"upgrade_sting":
			return _upgrade_sting()
		"tap_pop":
			return _tap_pop()
		"truck_horn":
			return _truck_horn()
		"level_up":
			return _level_up()
		"milestone_fanfare":
			return _milestone_fanfare()
		"coin_shower":
			return _coin_shower()
		"welcome_back_chime":
			return _welcome_back_chime()
		"franchise_jingle":
			return _franchise_jingle()
		"rain_loop":
			return _rain_loop()
		"sunny_ambience":
			return _sunny_ambience()
		"room_tone":
			return _room_tone()
		"street_t1":
			return _street_kampung()
		"street_t2":
			return _street_shophouse()
		"street_t3":
			return _street_avenue()
		"street_t4":
			return _street_premium()
		"street_t5":
			return _street_square()
		"clock_chime":
			return _clock_chime()
	# Resep tak dikenal: bunyi kosong pendek, tidak pernah null (GDD 132).
	return _to_stream(_new_buffer(0.05), false)


## Konfirmasi: ketukan kayu lalu dua denting lonceng naik (G6 -> C7).
static func _confirm() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.36)
	buf = _wood(buf, 0.0, 600.0, 0.7)
	buf = _add_modal(buf, 0.03, 0.3, 1567.98, 0.34, [[1.0, 1.0, 9.0], [2.0, 0.18, 16.0]])
	buf = _add_modal(buf, 0.09, 0.27, 2093.0, 0.3, [[1.0, 1.0, 10.0], [2.0, 0.15, 18.0]])
	buf = _lowpass(buf, 7000.0)
	buf = _room(buf, 0.6)
	return _to_stream(_normalize(buf, 0.78), false)


## Batal: dua ketukan kayu yang turun, pelan.
static func _cancel() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.16)
	buf = _wood(buf, 0.0, 470.0, 0.8)
	buf = _wood(buf, 0.07, 350.0, 0.65)
	buf = _lowpass(buf, 4200.0)
	buf = _room(buf, 0.4)
	return _to_stream(_normalize(buf, 0.6), false)


static func _error() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.36)
	var soft: Dictionary = {"attack": 0.01, "decay": 0.05, "sustain": 0.4, "release": 0.08}
	buf = _add_osc(buf, 0.0, 0.16, 392.0, 392.0, "triangle", 0.6, soft)
	buf = _add_osc(buf, 0.15, 0.2, 311.13, 311.13, "triangle", 0.6, soft)
	buf = _lowpass(buf, 1800.0)
	buf = _room(buf, 0.4)
	return _to_stream(_normalize(buf, 0.65), false)


static func _cloth_muffle() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _noise_buffer(0.18, 0.5,
			{"attack": 0.03, "decay": 0.06, "sustain": 0.3, "release": 0.08}, 90.0, 700.0)
	return _to_stream(_normalize(buf, 0.5), false)


## Bel pintu toko: lonceng kecil yang berayun, dipukul empat kali dengan jarak
## tak rata dan makin pelan ("kling-kling-ling").
static func _door_bell(pitch: float, amp: float) -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.95)
	var base: float = 1318.51 * pitch
	for hit: Array in [[0.0, 1.0, 1.0], [0.075, 1.19, 0.7], [0.16, 1.0, 0.5], [0.27, 1.19, 0.3]]:
		var at: float = float(hit[0])
		buf = _add_modal(buf, at, 0.9 - at, base * float(hit[1]), 0.5 * amp * float(hit[2]), SHOP_BELL)
	buf = _room(buf, 0.4)
	return _to_stream(_normalize(buf, 0.7 * amp + 0.1), false)


static func _footstep() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _noise_buffer(0.05, 0.6,
			{"attack": 0.001, "decay": 0.02, "sustain": 0.05, "release": 0.02}, 120.0, 1200.0)
	buf = _add_osc(buf, 0.0, 0.04, 110.0, 80.0, "sine", 0.4,
			{"attack": 0.001, "decay": 0.02, "sustain": 0.0, "release": 0.015})
	return _to_stream(_normalize(buf, 0.5), false)


static func _hinge(opening: bool) -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.35)
	var f0: float = 380.0 if opening else 520.0
	var f1: float = 520.0 if opening else 360.0
	buf = _add_osc(buf, 0.0, 0.22, f0, f1, "triangle", 0.18,
			{"attack": 0.02, "decay": 0.08, "sustain": 0.5, "release": 0.08})
	var latch: PackedFloat32Array = _noise_buffer(0.03, 0.6,
			{"attack": 0.001, "decay": 0.015, "sustain": 0.0, "release": 0.01}, 800.0, 4200.0)
	buf = _mix_into(buf, latch, 0.24 if opening else 0.18)
	buf = _add_osc(buf, 0.22, 0.1, 150.0, 110.0, "sine", 0.35,
			{"attack": 0.002, "decay": 0.04, "sustain": 0.0, "release": 0.04})
	buf = _lowpass(buf, 4000.0)
	return _to_stream(_normalize(buf, 0.6), false)


static func _mixer_start() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.5)
	buf = _add_osc(buf, 0.0, 0.5, 60.0, 140.0, "saw", 0.3,
			{"attack": 0.05, "decay": 0.1, "sustain": 0.7, "release": 0.1})
	buf = _lowpass(buf, 900.0)
	return _to_stream(_normalize(buf, 0.5), false)


static func _mixer_loop() -> AudioStreamWAV:
	var dur: float = 1.0
	var buf: PackedFloat32Array = _new_buffer(dur)
	var n: int = buf.size()
	var inv: float = 1.0 / float(_rate)
	var rng: RandomNumberGenerator = _noise_rng()
	var tbl: PackedFloat32Array = _sine_table()
	for i in n:
		var t: float = float(i) * inv
		# Adukan berirama 4 kali per detik: gesekan whisk di mangkuk.
		var scrape: float = 0.5 + 0.5 * tbl[int(4.0 * t * 4096.0) & SINE_TABLE_MASK]
		buf[i] = rng.randf_range(-1.0, 1.0) * scrape * 0.4 + tbl[int(110.0 * t * 4096.0) & SINE_TABLE_MASK] * 0.15
	buf = _lowpass(buf, 1500.0)
	return _to_stream(_normalize(buf, 0.45), true)


## Adonan jadi: denting lonceng kecil (D6) di ruang kecil.
static func _mixer_done() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.6)
	buf = _add_modal(buf, 0.0, 0.55, 1174.66, 0.6, GLOCK)
	buf = _room(buf, 0.35)
	return _to_stream(_normalize(buf, 0.7), false)


static func _oven_door(opening: bool) -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.45)
	var clunk: PackedFloat32Array = _noise_buffer(0.08, 0.7,
			{"attack": 0.002, "decay": 0.05, "sustain": 0.0, "release": 0.03}, 150.0, 2600.0)
	buf = _mix_into(buf, clunk, 0.0 if opening else 0.25)
	buf = _add_bell(buf, 0.02, 0.3, 520.0, 0.2, 14.0)
	if not opening:
		var slide: PackedFloat32Array = _noise_buffer(0.22, 0.35,
				{"attack": 0.03, "decay": 0.05, "sustain": 0.6, "release": 0.05}, 900.0, 3600.0)
		buf = _mix_into(buf, slide, 0.0)
	buf = _lowpass(buf, 3200.0)
	return _to_stream(_normalize(buf, 0.6), false)


static func _oven_loop() -> AudioStreamWAV:
	var dur: float = 1.5
	var buf: PackedFloat32Array = _new_buffer(dur)
	var rng: RandomNumberGenerator = _noise_rng()
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0)
	buf = _lowpass(buf, 420.0)
	return _to_stream(_normalize(buf, 0.35), true)


static func _place_display() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.3)
	var tap: PackedFloat32Array = _noise_buffer(0.03, 0.6,
			{"attack": 0.001, "decay": 0.015, "sustain": 0.0, "release": 0.01}, 500.0, 3500.0)
	buf = _mix_into(buf, tap, 0.0)
	buf = _add_bell(buf, 0.0, 0.2, 2093.0, 0.12, 20.0)
	var rustle: PackedFloat32Array = _noise_buffer(0.18, 0.2,
			{"attack": 0.02, "decay": 0.05, "sustain": 0.4, "release": 0.06}, 1500.0, 6000.0)
	buf = _mix_into(buf, rustle, 0.05)
	return _to_stream(_normalize(buf, 0.6), false)


## Semangat (GDD idle 5.2, 14): "pop" pendek yang membal, diikuti kilau tipis.
static func _tap_pop() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.16)
	buf = _add_osc(buf, 0.0, 0.06, 520.0, 980.0, "sine", 0.7,
			{"attack": 0.002, "decay": 0.03, "sustain": 0.3, "release": 0.03})
	buf = _add_osc(buf, 0.045, 0.08, 1568.0, 2093.0, "triangle", 0.25,
			{"attack": 0.003, "decay": 0.03, "sustain": 0.2, "release": 0.04})
	buf = _room(buf, 0.3)
	return _to_stream(_normalize(buf, 0.55), false)


## Klakson truk pindahan (GDD idle §20 no. 70): dua "tin" pendek dua nada,
## kotak yang dilunakkan segitiga supaya ramah di telinga.
static func _truck_horn() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.46)
	var env: Dictionary = {"attack": 0.006, "decay": 0.03, "sustain": 0.85, "release": 0.04}
	for i in 2:
		var t0: float = 0.2 * float(i)
		buf = _add_osc(buf, t0, 0.15, 415.3, 411.0, "square", 0.22, env)
		buf = _add_osc(buf, t0, 0.15, 523.25, 518.0, "square", 0.18, env)
		buf = _add_osc(buf, t0, 0.15, 415.3, 411.0, "triangle", 0.35, env)
	buf = _lowpass(buf, 3200.0)
	return _to_stream(_normalize(buf, 0.5), false)


## Naik level (GDD idle 14): arpeggio marimba naik C6-E6-G6-C7 yang ceria,
## nada terakhir berkilau glockenspiel.
static func _level_up() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.75)
	var notes: Array[float] = [1046.5, 1318.51, 1567.98, 2093.0]
	for i in notes.size():
		var last: bool = i == notes.size() - 1
		buf = _add_modal(buf, 0.055 * float(i), 0.6 if last else 0.4, notes[i], 0.42 if last else 0.34, MARIMBA)
	buf = _add_modal(buf, 0.165, 0.5, 2093.0, 0.1, GLOCK)
	buf = _room(buf, 0.5)
	return _to_stream(_normalize(buf, 0.6), false)


## Pad hangat di bawah fanfare: dua sinus lembut yang masuk pelan.
static func _warm_pad(buf: PackedFloat32Array, at: float, dur: float, freqs: Array, amp: float) -> PackedFloat32Array:
	for f: float in freqs:
		buf = _add_osc(buf, at, dur, f, f, "sine", amp,
				{"attack": 0.15, "decay": 0.2, "sustain": 0.7, "release": minf(0.6, dur * 0.4)})
	return buf


## Milestone (GDD idle 14): arpeggio marimba lima nada, akor lonceng di puncak,
## dan pad hangat di bawahnya.
static func _milestone_fanfare() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(1.6)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.51]
	for i in notes.size():
		buf = _add_modal(buf, 0.085 * float(i), 0.5, notes[i], 0.32, MARIMBA)
	for f: float in [1046.5, 1318.51, 1567.98]:
		buf = _add_modal(buf, 0.42, 1.15, f, 0.2, [[1.0, 1.0, 3.2], [2.0, 0.08, 6.0]])
	buf = _warm_pad(buf, 0.0, 1.5, [261.63, 392.0], 0.12)
	buf = _room(buf, 0.4)
	return _to_stream(_normalize(buf, 0.66), false)


## Hujan koin (GDD idle 9.5, Collect): denting koin logam yang makin rapat lalu
## mereda, nadanya berganti dalam tangga nada pentatonik supaya tetap manis.
static func _coin_shower() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(1.5)
	var notes: Array = [1567.98, 1760.0, 2093.0, 2349.32, 2637.02]
	var t: float = 0.0
	for i in 22:
		var f: float = float(notes[(i * 3 + i / 4) % notes.size()])
		var a: float = 0.35 - 0.008 * float(i)
		buf = _add_bell(buf, t, 0.16, f, a, 20.0)
		buf = _add_bell(buf, t, 0.1, f * 1.58, a * 0.45, 30.0)
		t += 0.035 + 0.025 * absf(sin(float(i) * 1.7))
	buf = _lowpass(buf, 9000.0)
	return _to_stream(_normalize(buf, 0.6), false)


## Selamat datang kembali (GDD idle 9.5): bel pintu toko lalu tiga nada marimba
## naik yang hangat di atas pad lembut.
static func _welcome_back_chime() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(1.3)
	buf = _add_modal(buf, 0.0, 0.6, 1318.51, 0.18, SHOP_BELL)
	var notes: Array[float] = [783.99, 987.77, 1174.66]
	for i in notes.size():
		buf = _add_modal(buf, 0.12 + 0.15 * float(i), 0.7, notes[i], 0.36, MARIMBA)
	buf = _warm_pad(buf, 0.1, 1.1, [392.0, 587.33], 0.1)
	buf = _room(buf, 0.4)
	return _to_stream(_normalize(buf, 0.6), false)


## Waralaba (GDD idle 10.6): jingle riang enam nada marimba dengan bas hangat
## dan kilau glockenspiel penutup, seperti pembukaan toko baru.
static func _franchise_jingle() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(2.4)
	var notes: Array = [[0.0, 523.25], [0.16, 659.25], [0.32, 783.99], [0.56, 659.25], [0.72, 783.99], [0.9, 1046.5]]
	for n: Array in notes:
		buf = _add_modal(buf, float(n[0]), 0.7 if float(n[0]) < 0.9 else 1.3, float(n[1]), 0.38, MARIMBA)
	for b: Array in [[0.0, 130.81], [0.56, 196.0], [0.9, 261.63]]:
		buf = _add_osc(buf, float(b[0]), 0.5 if float(b[0]) < 0.9 else 1.2, float(b[1]), float(b[1]), "triangle", 0.3,
				{"attack": 0.01, "decay": 0.15, "sustain": 0.4, "release": 0.3})
	for i in 5:
		var f: float = 2093.0 * pow(1.12246, float(i))
		buf = _add_modal(buf, 1.05 + 0.05 * float(i), 0.3, f, 0.1, GLOCK)
	buf = _warm_pad(buf, 0.9, 1.4, [261.63, 329.63, 392.0], 0.08)
	return _to_stream(_normalize(buf, 0.65), false)


static func _happy_chirp() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.22)
	buf = _add_osc(buf, 0.0, 0.1, 880.0, 1320.0, "sine", 0.6,
			{"attack": 0.005, "decay": 0.04, "sustain": 0.4, "release": 0.04})
	buf = _add_osc(buf, 0.09, 0.12, 1175.0, 1760.0, "sine", 0.5,
			{"attack": 0.005, "decay": 0.04, "sustain": 0.4, "release": 0.05})
	buf = _room(buf, 0.25)
	return _to_stream(_normalize(buf, 0.6), false)


static func _impatient_tap() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.4)
	for k in 3:
		var tap: PackedFloat32Array = _noise_buffer(0.025, 0.5,
				{"attack": 0.001, "decay": 0.012, "sustain": 0.0, "release": 0.008}, 400.0, 2500.0)
		buf = _mix_into(buf, tap, 0.12 * float(k))
	return _to_stream(_normalize(buf, 0.45), false)


## Penjualan: lonceng meja kasir kecil ("ding") didahului klak laci kas. Lebih
## lembut dari dulu karena berbunyi di setiap penjualan.
static func _register_ding() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.8)
	var clk: PackedFloat32Array = _noise_buffer(0.025, 0.35,
			{"attack": 0.001, "decay": 0.012, "sustain": 0.0, "release": 0.01}, 900.0, 3500.0)
	buf = _mix_into(buf, clk, 0.0)
	var f: float = 1975.53
	buf = _add_modal(buf, 0.03, 0.75, f, 0.5, [[1.0, 1.0, 4.5], [2.0, 0.28, 8.0], [2.76, 0.24, 9.0], [5.4, 0.1, 15.0]])
	buf = _add_bell(buf, 0.03, 0.75, f * 1.003, 0.09, 4.5)
	buf = _room(buf, 0.5)
	return _to_stream(_normalize(buf, 0.7), false)


static func _bag_seal() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.3)
	var fold: PackedFloat32Array = _noise_buffer(0.12, 0.5,
			{"attack": 0.01, "decay": 0.04, "sustain": 0.5, "release": 0.04}, 1200.0, 5000.0)
	buf = _mix_into(buf, fold, 0.0)
	var press: PackedFloat32Array = _noise_buffer(0.04, 0.6,
			{"attack": 0.001, "decay": 0.02, "sustain": 0.0, "release": 0.015}, 200.0, 1600.0)
	buf = _mix_into(buf, press, 0.18)
	return _to_stream(_normalize(buf, 0.55), false)


static func _handover_ping() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.5)
	var rustle: PackedFloat32Array = _noise_buffer(0.12, 0.35,
			{"attack": 0.01, "decay": 0.04, "sustain": 0.4, "release": 0.04}, 1200.0, 5000.0)
	buf = _mix_into(buf, rustle, 0.0)
	buf = _add_modal(buf, 0.12, 0.35, 1567.98, 0.5, [[1.0, 1.0, 8.0], [2.0, 0.15, 14.0]])
	buf = _add_modal(buf, 0.2, 0.3, 2093.0, 0.4, [[1.0, 1.0, 9.0], [2.0, 0.12, 16.0]])
	buf = _room(buf, 0.35)
	return _to_stream(_normalize(buf, 0.65), false)


static func _tablet_cancel() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.5)
	buf = _add_osc(buf, 0.0, 0.18, 987.77, 987.77, "sine", 0.5,
			{"attack": 0.005, "decay": 0.05, "sustain": 0.5, "release": 0.06})
	buf = _add_osc(buf, 0.17, 0.3, 739.99, 739.99, "sine", 0.5,
			{"attack": 0.005, "decay": 0.05, "sustain": 0.5, "release": 0.12})
	buf = _lowpass(buf, 3000.0)
	buf = _room(buf, 0.3)
	return _to_stream(_normalize(buf, 0.6), false)


static func _sparkle_chime() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(0.8)
	var notes: Array = [2093.0, 2637.02, 3135.96, 4186.01]
	for i in notes.size():
		buf = _add_modal(buf, 0.06 * float(i), 0.5, float(notes[i]), 0.3, [[1.0, 1.0, 9.0], [2.76, 0.12, 16.0]])
	buf = _room(buf, 0.3)
	return _to_stream(_normalize(buf, 0.55), false)


static func _whoosh() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _noise_buffer(0.25, 0.6,
			{"attack": 0.08, "decay": 0.06, "sustain": 0.4, "release": 0.1}, 300.0, 2600.0)
	return _to_stream(_normalize(buf, 0.45), false)


## Achievement: arpeggio glockenspiel naik, denting panjang di puncak, pad lembut.
static func _flourish() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(2.0)
	var notes: Array[float] = [1046.5, 1318.51, 1567.98, 2093.0, 2637.02]
	for i in notes.size():
		buf = _add_modal(buf, 0.07 * float(i), 0.9, notes[i], 0.3, GLOCK)
	buf = _add_modal(buf, 0.42, 1.5, 2093.0, 0.24, [[1.0, 1.0, 2.8], [2.76, 0.18, 6.0]])
	buf = _warm_pad(buf, 0.0, 1.8, [523.25, 659.25], 0.08)
	buf = _room(buf, 0.35)
	return _to_stream(_normalize(buf, 0.65), false)


## Pindah lokasi: arpeggio marimba dua oktaf, akor lonceng yang bergema, dan pad
## hangat (C mayor) — perayaan terbesar.
static func _upgrade_sting() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(2.6)
	var notes: Array[float] = [523.25, 659.25, 783.99, 1046.5, 1318.51, 1567.98, 2093.0]
	for i in notes.size():
		buf = _add_modal(buf, 0.09 * float(i), 0.55, notes[i], 0.32, MARIMBA)
	for f: float in [1046.5, 1318.51, 1567.98]:
		buf = _add_modal(buf, 0.6, 1.9, f, 0.2, [[1.0, 1.0, 2.6], [2.0, 0.1, 5.0]])
	buf = _warm_pad(buf, 0.0, 2.4, [261.63, 392.0], 0.16)
	return _to_stream(_normalize(buf, 0.7), false)


static func _rain_loop() -> AudioStreamWAV:
	var dur: float = 4.0
	var buf: PackedFloat32Array = _new_buffer(dur)
	var rng: RandomNumberGenerator = _noise_rng()
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0)
	buf = _highpass(buf, 700.0)
	buf = _lowpass(buf, 5200.0)
	# Tetes di jendela: klik lembut acak yang dibungkus agar loop tetap mulus.
	for k in 60:
		var drop: PackedFloat32Array = _noise_buffer(0.012, 0.9,
				{"attack": 0.001, "decay": 0.006, "sustain": 0.0, "release": 0.004}, 1500.0, 6000.0)
		buf = _add_wrapped(buf, drop, rng.randf_range(0.0, dur))
	return _to_stream(_normalize(buf, 0.4), true)


static func _sunny_ambience() -> AudioStreamWAV:
	var dur: float = 6.0
	var buf: PackedFloat32Array = _new_buffer(dur)
	var rng: RandomNumberGenerator = _noise_rng()
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0) * 0.3
	buf = _lowpass(buf, 600.0)
	# Kicau burung sesekali.
	for k in 5:
		var t0: float = rng.randf_range(0.0, dur - 0.5)
		var f: float = rng.randf_range(2600.0, 3600.0)
		buf = _chirps(buf, t0, f, 0.25)
	return _to_stream(_normalize(buf, 0.35), true)


static func _room_tone() -> AudioStreamWAV:
	var dur: float = 4.0
	var buf: PackedFloat32Array = _new_buffer(dur)
	var rng: RandomNumberGenerator = _noise_rng()
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0)
	buf = _lowpass(buf, 300.0)
	# Detak jam dinding, satu per detik.
	for k in 4:
		var tick: PackedFloat32Array = _noise_buffer(0.01, 0.8,
				{"attack": 0.0005, "decay": 0.005, "sustain": 0.0, "release": 0.003}, 1800.0, 5000.0)
		buf = _add_wrapped(buf, tick, float(k))
	return _to_stream(_normalize(buf, 0.3), true)


# ---------------------------------------------------------------------------
# Suara jalan per tier lokasi (GDD 32.9): lapisan ambience dari luar toko.
# Loop pendek (STREET_SECONDS) supaya murah dirakit di layar loading; peristiwa
# dibungkus (_add_wrapped) dan modulasi pas satu putaran agar sambungannya mulus.
# Dirakit di AMBIENT_RATE (isinya di bawah 5 kHz).
# ---------------------------------------------------------------------------

const STREET_SECONDS: float = 4.0


## Derau dasar: putih -> lowpass (dengung lalu lintas, angin, air).
static func _street_bed(amp: float, lp: float, hp: float = 0.0) -> PackedFloat32Array:
	var buf: PackedFloat32Array = _new_buffer(STREET_SECONDS)
	var rng: RandomNumberGenerator = _noise_rng()
	for i in buf.size():
		buf[i] = rng.randf_range(-1.0, 1.0) * amp
	buf = _lowpass(buf, lp)
	if hp > 0.0:
		buf = _highpass(buf, hp)
	return buf


## Motor lewat di kejauhan: gigi gergaji rendah yang naik lalu menghilang.
static func _moto_pass(buf: PackedFloat32Array, at: float, f0: float, amp: float) -> PackedFloat32Array:
	var m: PackedFloat32Array = _new_buffer(2.2)
	m = _add_osc(m, 0.0, 2.2, f0, f0 * 1.18, "saw", amp, {"attack": 0.9, "decay": 0.25, "sustain": 0.55, "release": 1.0})
	m = _lowpass(m, 650.0)
	return _add_wrapped(buf, m, at)


## Kicau burung: tiga nada naik yang pendek.
static func _chirps(buf: PackedFloat32Array, at: float, f: float, amp: float) -> PackedFloat32Array:
	for c in 3:
		var ch: PackedFloat32Array = _new_buffer(0.08)
		ch = _add_osc(ch, 0.0, 0.08, f, f * 1.25, "sine", amp, {"attack": 0.005, "decay": 0.03, "sustain": 0.3, "release": 0.03})
		buf = _add_wrapped(buf, ch, at + 0.11 * float(c))
	return buf


## Tier 1, kampung kota: angin lembut, motor lewat jauh, burung, dan "ting ting"
## sendok penjual bakso di kejauhan.
static func _street_kampung() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _street_bed(0.22, 420.0)
	buf = _moto_pass(buf, 0.4, 70.0, 0.2)
	buf = _chirps(buf, 2.3, 3100.0, 0.18)
	for c in 3:
		var ting: PackedFloat32Array = _new_buffer(0.32)
		ting = _add_bell(ting, 0.0, 0.32, 2637.0, 0.16, 14.0)
		ting = _add_bell(ting, 0.0, 0.25, 3951.0, 0.05, 22.0)
		buf = _add_wrapped(buf, ting, 3.0 + 0.22 * float(c))
	return _to_stream(_normalize(buf, 0.35), true)


## Tier 2, jalan ruko: dengung lalu lintas, dua motor, dan klakson angkot.
static func _street_shophouse() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _street_bed(0.45, 280.0)
	buf = _moto_pass(buf, 0.2, 64.0, 0.22)
	buf = _moto_pass(buf, 2.2, 78.0, 0.18)
	var horn: PackedFloat32Array = _new_buffer(0.42)
	for k in 2:
		horn = _add_osc(horn, 0.18 * float(k), 0.12, 440.0, 440.0, "square", 0.12, {"attack": 0.005, "decay": 0.02, "sustain": 0.8, "release": 0.03})
	horn = _lowpass(horn, 1600.0)
	buf = _add_wrapped(buf, horn, 3.1)
	return _to_stream(_normalize(buf, 0.38), true)


## Tier 3, jalan raya kota: dengung lebih tebal, mobil berdesir lewat, desis rem bus.
static func _street_avenue() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _street_bed(0.6, 360.0)
	for at: float in [0.2, 1.9]:
		var swell: PackedFloat32Array = _noise_buffer(1.6, 0.35, {"attack": 0.7, "decay": 0.2, "sustain": 0.6, "release": 0.7}, 180.0, 1400.0)
		buf = _add_wrapped(buf, swell, at)
	var hiss: PackedFloat32Array = _noise_buffer(0.35, 0.18, {"attack": 0.01, "decay": 0.1, "sustain": 0.5, "release": 0.2}, 2500.0, 5000.0)
	buf = _add_wrapped(buf, hiss, 3.2)
	return _to_stream(_normalize(buf, 0.4), true)


## Tier 4, kawasan premium: gemericik air mancur, lalu lintas yang jauh dan pelan,
## dan burung.
static func _street_premium() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _street_bed(0.5, 3600.0, 700.0)
	var n: int = buf.size()
	var inv: float = 1.0 / float(_rate)
	var tbl: PackedFloat32Array = _sine_table()
	for i in n:
		buf[i] *= 0.82 + 0.18 * tbl[int(0.5 * float(i) * inv * 4096.0) & SINE_TABLE_MASK]
	var hum: PackedFloat32Array = _street_bed(0.15, 260.0)
	for j in n:
		buf[j] += hum[j]
	buf = _chirps(buf, 1.2, 3400.0, 0.12)
	return _to_stream(_normalize(buf, 0.36), true)


## Tier 5, alun-alun: riuh orang ramai yang naik-turun dan bel becak "kring kring".
static func _street_square() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _street_bed(0.55, 900.0, 250.0)
	var n: int = buf.size()
	var inv: float = 1.0 / float(_rate)
	var tbl: PackedFloat32Array = _sine_table()
	for i in n:
		var t: float = float(i) * inv
		buf[i] *= 0.7 + 0.2 * tbl[int(1.5 * t * 4096.0) & SINE_TABLE_MASK] + 0.1 * tbl[int(0.75 * t * 4096.0) & SINE_TABLE_MASK]
	for k in 2:
		var ring: PackedFloat32Array = _new_buffer(0.45)
		ring = _add_bell(ring, 0.0, 0.45, 2093.0, 0.14, 9.0)
		ring = _add_bell(ring, 0.0, 0.3, 4400.0, 0.05, 16.0)
		buf = _add_wrapped(buf, ring, 1.4 + 0.18 * float(k))
	return _to_stream(_normalize(buf, 0.38), true)


## Lonceng menara jam Tier 5 setiap jam (GDD 32.9): empat nada lalu satu dentang.
static func _clock_chime() -> AudioStreamWAV:
	var buf: PackedFloat32Array = _new_buffer(4.2)
	var notes: Array[float] = [659.25, 523.25, 587.33, 392.0]
	for i in notes.size():
		buf = _add_bell(buf, 0.55 * float(i), 2.0, notes[i], 0.5, 2.2)
		buf = _add_bell(buf, 0.55 * float(i), 1.2, notes[i] * 2.76, 0.12, 4.0)
	buf = _add_bell(buf, 2.6, 1.6, 196.0, 0.55, 1.2)
	buf = _add_bell(buf, 2.6, 1.2, 392.0, 0.2, 2.0)
	buf = _lowpass(buf, 4500.0)
	return _to_stream(_normalize(buf, 0.6), false)
