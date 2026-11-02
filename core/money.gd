class_name Money
extends RefCounted
## Aturan uang & pembulatan kanonik (GDD idle 7.6; v3.1 73, 99.2).
##
## Saldo disimpan float64. Di game idle setiap transaksi di-commit sampai sen
## (0,01 KR, half-up), bukan KR utuh seperti v3.1 99.2 (keputusan maintainer
## 2026-11-02): pendapatan awal hanya 1 KR/s dan harga roti beberapa KR, jadi
## bonus persen kecil hilang bila dibulatkan ke KR utuh.


## Half-up: x.5 dibulatkan menjauhi nol untuk nilai positif.
static func round_half_up(v: float) -> float:
	if v >= 0.0:
		return floorf(v + 0.5)
	return -floorf(-v + 0.5)


## Sen terdekat, half-up: satuan setiap transaksi idle (GDD idle 7.6).
static func round_cents(v: float) -> float:
	return round_half_up(v * 100.0) / 100.0


## Bulatkan ke kelipatan `step` terdekat (half-up), dipakai batas harga 63.2.
static func round_to(v: float, step: float) -> float:
	if step <= 0.0:
		return round_half_up(v)
	return round_half_up(v / step) * step


static func is_valid(v: float) -> bool:
	return not is_nan(v)


## Format "1,250 KR" (GDD 43). Mulai ambang `sci_threshold` memakai notasi ilmiah.
static func fmt(v: float, sci_threshold: float = 1.0e12) -> String:
	if is_nan(v):
		return "? KR"
	if is_inf(v):
		return "∞ KR"
	if absf(v) >= sci_threshold:
		return "%s KR" % _scientific(v)
	return "%s KR" % group_int(int(round_half_up(v)))


static func fmt_signed(v: float, sci_threshold: float = 1.0e12) -> String:
	if v > 0.0:
		return "+" + fmt(v, sci_threshold)
	if v < 0.0:
		return "-" + fmt(-v, sci_threshold)
	return fmt(0.0, sci_threshold)


static func group_int(n: int) -> String:
	var neg: bool = n < 0
	var s: String = str(absi(n))
	var out: String = ""
	var count: int = 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if neg else "") + out


static func _scientific(v: float) -> String:
	var e: int = int(floor(log(absf(v)) / log(10.0)))
	var m: float = v / pow(10.0, e)
	return "%.2fe%d" % [m, e]
