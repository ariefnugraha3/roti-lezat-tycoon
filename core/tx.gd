class_name Tx
extends RefCounted
## Pintu tunggal teks yang terlihat pemain (GDD 43, 127). Semua string berasal
## dari data/catalog/strings_en.json lewat DataRegistry; skrip tidak boleh
## menulis kalimat panjang secara langsung.


## Teks untuk `key`, dengan placeholder {nama} diganti dari `params`.
static func t(key: String, params: Dictionary = {}) -> String:
	return DataRegistry.text(key, params)


## Jumlah KR untuk teks: angka besar (Tx.big) + " KR".
static func kr(v: float) -> String:
	if is_nan(v):
		return "? KR"
	return "%s KR" % big(v)


static func kr_signed(v: float) -> String:
	if v > 0.0:
		return "+" + kr(v)
	if v < 0.0:
		return "-" + kr(-v)
	return kr(0.0)


## Angka besar (GDD idle 7.5): di bawah 10.000 ditulis utuh dengan pemisah
## ribuan ("9,850"); di atasnya 3 angka penting dengan akhiran K, M, B, T, lalu
## aa, ab, …, az, ba, … ("12.4K", "3.07M", "118aa"). Pengaturan "Number format:
## Scientific" menulis "1.24e15".
static func big(v: float, scientific: int = -1) -> String:
	if is_nan(v):
		return "?"
	if is_inf(v):
		return "∞" if v > 0.0 else "-∞"
	if v < 0.0:
		return "-" + big(-v, scientific)
	if v < 9999.5:
		return Money.group_int(int(Money.round_half_up(v)))
	var sci: bool = scientific == 1 or (scientific < 0 and str(SettingsManager.get_value("number_format")) == "scientific")
	var e: int = int(floor(log(v) / log(10.0) + 1e-9))
	if sci:
		var m: float = v / pow(10.0, e)
		if snappedf(m, 0.01) >= 10.0:
			m /= 10.0
			e += 1
		return "%.2fe%d" % [m, e]
	var g: int = e / 3
	var mant: float = v / pow(10.0, g * 3)
	# Pembulatan ke 3 angka penting bisa menyentuh 1000: naik satu akhiran.
	if _round3(mant) >= 1000.0:
		g += 1
		mant = v / pow(10.0, g * 3)
	return _fmt3(mant) + _suffix(g)


static func _round3(m: float) -> float:
	if m < 10.0:
		return snappedf(m, 0.01)
	if m < 100.0:
		return snappedf(m, 0.1)
	return snappedf(m, 1.0)


static func _fmt3(m: float) -> String:
	if m < 9.995:
		return "%.2f" % m
	if m < 99.95:
		return "%.1f" % m
	return "%.0f" % m


## Akhiran kelompok ribuan ke-g: 1 K, 2 M, 3 B, 4 T, lalu aa, ab, … (10^15 ke atas).
static func _suffix(g: int) -> String:
	match g:
		0:
			return ""
		1:
			return "K"
		2:
			return "M"
		3:
			return "B"
		4:
			return "T"
	var idx: int = g - 5
	return String.chr(97 + (idx / 26) % 26) + String.chr(97 + idx % 26)


## Jam in-game "HH:MM" dari detik sejak 00:00.
static func clock(time_seconds: float) -> String:
	var total_min: int = int(floor(time_seconds / 60.0))
	var h: int = (total_min / 60) % 24
	var m: int = total_min % 60
	return "%02d:%02d" % [h, m]


static func rating(v: float) -> String:
	return "%.1f" % v


static func percent(v: float) -> String:
	return "%d%%" % int(Money.round_half_up(v * 100.0))


static func recipe_name(recipe_id: StringName) -> String:
	return t(String(recipe_id))


static func item_name(id: StringName) -> String:
	return t(String(id))
