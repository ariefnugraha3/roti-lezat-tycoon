class_name IconCanvas
extends Control
## Kanvas ikon 2D yang digambar 100% prosedural di dalam `_draw()`.
##
## GDD 4.3 & 12.3: seluruh ikon in-game (koin emas berkilau, bintang rating
## mentega, jam dinding kayu, balon pesanan berbentuk awan empuk, emoji mood
## Daily Summary) digambar langsung memakai `draw_circle`, `draw_arc`,
## `draw_line`, `draw_colored_polygon`, `draw_rect`, dan `draw_polyline`.
## TIDAK ADA satu pun aset gambar eksternal.
##
## Semua bentuk dirancang di "ruang satuan" [-0.5 .. 0.5] lalu diskalakan ke
## `icon_size` dan digeser ke titik tengah Control, sehingga ikon tetap terbaca
## mulai dari 16 px sampai 128 px. Gaya visual mengikuti GDD 4.1
## "Warm, Cozy & Cute": bentuk gemuk membulat, tanpa sudut tajam.
##
## Contoh pemakaian:
## [codeblock]
## var ic := ProceduralUIFactory.icon("coin", 32, Palette.GOLD_STAR)
## add_child(ic)
## [/codeblock]


## Seluruh nama ikon yang dikenali (38 nama, kontrak ARCHITECTURE.md seksi 8).
const NAMES: Array[String] = [
	"coin", "star", "clock", "bolt", "bread", "bag", "cart", "people", "heart",
	"angry", "sad", "happy", "rain", "sun", "party", "bubble", "check", "cross",
	"plus", "minus", "warning", "fire", "box", "megaphone", "chef", "trophy",
	"note", "moon", "scooter", "hourglass",
	"pause", "play", "kitchen", "shop", "frame",
	"gear", "sound", "mute",
]

## Jumlah ruas per seperempat lingkaran saat membentuk sudut membulat.
const CORNER_STEPS: int = 4

## Ukuran ikon terkecil yang masih masuk akal digambar (piksel).
const MIN_SIZE: float = 4.0


## Nama ikon yang digambar. Lihat [constant NAMES] untuk daftar lengkapnya.
@export_enum(
	"coin", "star", "clock", "bolt", "bread", "bag", "cart", "people", "heart",
	"angry", "sad", "happy", "rain", "sun", "party", "bubble", "check", "cross",
	"plus", "minus", "warning", "fire", "box", "megaphone", "chef", "trophy",
	"note", "moon", "scooter", "hourglass",
	"pause", "play", "kitchen", "shop", "frame",
	"gear", "sound", "mute"
) var icon_name: String = "coin":
	set(value):
		icon_name = value
		queue_redraw()

## Warna utama ikon; detail diturunkan otomatis (lebih gelap / lebih terang).
@export var icon_color: Color = Color.WHITE:
	set(value):
		icon_color = value
		queue_redraw()

## Sisi bujur sangkar tempat ikon digambar (piksel). Menyetel ini ikut
## memperbarui `custom_minimum_size` agar tata letak container tetap benar.
@export_range(8.0, 256.0, 1.0, "or_greater") var icon_size: float = 32.0:
	set(value):
		icon_size = maxf(value, MIN_SIZE)
		custom_minimum_size = Vector2(icon_size, icon_size)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(icon_size, icon_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


func _draw() -> void:
	var s: float = maxf(icon_size, MIN_SIZE)
	var c: Vector2 = size * 0.5
	if size.x <= 0.0 or size.y <= 0.0:
		c = Vector2(s, s) * 0.5
	_paint(icon_name, c, s, icon_color)


## Setel nama + warna + ukuran sekaligus (satu kali `queue_redraw`).
func configure(new_name: String, new_size: float, new_color: Color) -> void:
	icon_name = new_name
	icon_size = new_size
	icon_color = new_color


## Benar bila [param id] termasuk nama ikon kanonik (lihat [constant NAMES]).
static func has_icon(id: String) -> bool:
	return NAMES.has(id)


# ---------------------------------------------------------------------------
# Penyalur gambar
# ---------------------------------------------------------------------------

func _paint(id: String, c: Vector2, s: float, col: Color) -> void:
	match id:
		"coin": _i_coin(c, s, col)
		"star": _i_star(c, s, col)
		"clock": _i_clock(c, s, col)
		"bolt": _i_bolt(c, s, col)
		"bread": _i_bread(c, s, col)
		"bag": _i_bag(c, s, col)
		"cart": _i_cart(c, s, col)
		"people": _i_people(c, s, col)
		"heart": _i_heart(c, s, col)
		"angry": _i_angry(c, s, col)
		"sad": _i_sad(c, s, col)
		"happy": _i_happy(c, s, col)
		"rain": _i_rain(c, s, col)
		"sun": _i_sun(c, s, col)
		"party": _i_party(c, s, col)
		"bubble": _i_bubble(c, s, col)
		"check": _i_check(c, s, col)
		"cross": _i_cross(c, s, col)
		"plus": _i_plus(c, s, col)
		"minus": _i_minus(c, s, col)
		"warning": _i_warning(c, s, col)
		"fire": _i_fire(c, s, col)
		"box": _i_box(c, s, col)
		"megaphone": _i_megaphone(c, s, col)
		"chef": _i_chef(c, s, col)
		"trophy": _i_trophy(c, s, col)
		"note": _i_note(c, s, col)
		"moon": _i_moon(c, s, col)
		"scooter": _i_scooter(c, s, col)
		"hourglass": _i_hourglass(c, s, col)
		"pause": _i_pause(c, s, col)
		"play": _i_play(c, s, col)
		"kitchen": _i_kitchen(c, s, col)
		"shop": _i_shop(c, s, col)
		"frame": _i_frame(c, s, col)
		"gear": _i_gear(c, s, col)
		"sound": _i_sound(c, s, col)
		"mute": _i_mute(c, s, col)
		_: _i_unknown(c, s, col)


# ---------------------------------------------------------------------------
# Peralatan gambar dasar (semua koordinat dalam satuan [-0.5 .. 0.5])
# ---------------------------------------------------------------------------

## Warna detail yang lebih gelap (garis wajah, guratan, bayangan).
func _ink(col: Color) -> Color:
	return col.darkened(0.42)


## Warna sorot yang lebih terang (kilau koin, nyala api bagian dalam).
func _lit(col: Color) -> Color:
	return col.lightened(0.52)


## Lingkaran penuh berpusat di (x, y).
func _dot(c: Vector2, s: float, x: float, y: float, r: float, col: Color) -> void:
	draw_circle(c + Vector2(x, y) * s, r * s, col)


## Garis tebal berujung bulat (kesan empuk khas GDD 4.1).
func _bar(c: Vector2, s: float, ax: float, ay: float, bx: float, by: float,
		w: float, col: Color) -> void:
	var pa: Vector2 = c + Vector2(ax, ay) * s
	var pb: Vector2 = c + Vector2(bx, by) * s
	draw_line(pa, pb, col, w * s, true)
	var cap: float = w * s * 0.5
	draw_circle(pa, cap, col)
	draw_circle(pb, cap, col)


## Busur dengan jumlah ruas otomatis mengikuti panjang sudutnya.
func _arcline(c: Vector2, s: float, x: float, y: float, r: float,
		a0: float, a1: float, w: float, col: Color) -> void:
	var steps: int = maxi(8, int(absf(a1 - a0) / 0.30))
	draw_arc(c + Vector2(x, y) * s, r * s, a0, a1, steps, col, w * s, true)


## Poligon terisi dari daftar Vector2 satuan.
func _blob(c: Vector2, s: float, pts: Array, col: Color) -> void:
	if pts.size() < 3:
		return
	var out: PackedVector2Array = PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		var v: Vector2 = pts[i]
		out[i] = c + v * s
	draw_colored_polygon(out, col)


## Titik-titik persegi panjang bersudut membulat (satuan), urut searah jarum jam.
func _round_pts(x: float, y: float, w: float, h: float, r: float) -> Array:
	var pts: Array = []
	if w <= 0.0 or h <= 0.0:
		return pts
	var rr: float = clampf(r, 0.0, minf(w, h) * 0.5)
	if rr <= 0.001:
		pts.append(Vector2(x, y))
		pts.append(Vector2(x + w, y))
		pts.append(Vector2(x + w, y + h))
		pts.append(Vector2(x, y + h))
		return pts
	var cx: Array = [x + w - rr, x + w - rr, x + rr, x + rr]
	var cy: Array = [y + rr, y + h - rr, y + h - rr, y + rr]
	var a0: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	for i in 4:
		var px: float = cx[i]
		var py: float = cy[i]
		var base: float = a0[i]
		for k in CORNER_STEPS + 1:
			var a: float = base + PI * 0.5 * (float(k) / float(CORNER_STEPS))
			pts.append(Vector2(px + cos(a) * rr, py + sin(a) * rr))
	return pts


## Persegi panjang bersudut membulat yang langsung terisi warna.
func _round_rect(c: Vector2, s: float, x: float, y: float, w: float, h: float,
		r: float, col: Color) -> void:
	_blob(c, s, _round_pts(x, y, w, h, r), col)


## Bintang berujung [param tips] (dipakai ikon `star` dan pin bintang).
func _star_pts(outer: float, inner: float, tips: int) -> Array:
	var pts: Array = []
	var n: int = maxi(tips, 3) * 2
	for i in n:
		var a: float = -PI * 0.5 + float(i) * TAU / float(n)
		var r: float = outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## Bulan sabit = lingkaran besar dikurangi lingkaran kecil yang digeser.
## Titik potong kedua lingkaran dihitung analitis lalu kedua busurnya disambung.
func _crescent_pts(big_r: float, ox: float, oy: float, small_r: float) -> Array:
	var pts: Array = []
	var o: Vector2 = Vector2(ox, oy)
	var d: float = o.length()
	if d < 0.0001 or d >= big_r + small_r or d + small_r <= big_r:
		return pts
	var a: float = (d * d - small_r * small_r + big_r * big_r) / (2.0 * d)
	var hsq: float = big_r * big_r - a * a
	if hsq <= 0.0:
		return pts
	var hh: float = sqrt(hsq)
	var base: float = o.angle()
	var delta: float = atan2(hh, a)
	var eps: float = atan2(hh, a - d)
	var steps: int = 18
	# Busur luar: bagian lingkaran besar yang tidak tertutup lingkaran kecil.
	for i in steps + 1:
		var t: float = base + delta + (TAU - 2.0 * delta) * (float(i) / float(steps))
		pts.append(Vector2(cos(t), sin(t)) * big_r)
	# Busur dalam: tepi lingkaran kecil, ditelusuri balik (ujung dilewati).
	for i in range(1, steps):
		var t: float = base + TAU - eps - (TAU - 2.0 * eps) * (float(i) / float(steps))
		pts.append(o + Vector2(cos(t), sin(t)) * small_r)
	return pts


# ---------------------------------------------------------------------------
# 30 ikon kanonik
# ---------------------------------------------------------------------------

## Koin Roti (KR) emas berkilau — mata uang game (GDD 4.3).
func _i_coin(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_dot(c, s, 0.0, 0.0, 0.44, col)
	_arcline(c, s, 0.0, 0.0, 0.33, 0.0, TAU, 0.05, ink)
	# Huruf "K" sederhana sebagai lambang Koin Roti.
	_bar(c, s, -0.09, -0.16, -0.09, 0.16, 0.07, ink)
	_bar(c, s, -0.09, 0.00, 0.09, -0.16, 0.06, ink)
	_bar(c, s, -0.09, 0.00, 0.10, 0.16, 0.06, ink)
	_dot(c, s, -0.18, -0.20, 0.07, _lit(col))


## Bintang rating mentega (GDD 9.1 & 9.2).
func _i_star(c: Vector2, s: float, col: Color) -> void:
	_blob(c, s, _star_pts(0.47, 0.22, 5), col)


## Jam dinding kayu berdetik tenang (GDD 4.1).
func _i_clock(c: Vector2, s: float, col: Color) -> void:
	_round_rect(c, s, -0.07, -0.54, 0.14, 0.10, 0.05, col)
	_arcline(c, s, 0.0, 0.0, 0.40, 0.0, TAU, 0.10, col)
	_bar(c, s, 0.0, 0.0, 0.0, -0.22, 0.08, col)
	_bar(c, s, 0.0, 0.0, 0.17, 0.06, 0.08, col)
	_dot(c, s, 0.0, 0.0, 0.06, col)


## Kilat — dipakai untuk kecepatan staf & meteran utilitas listrik.
func _i_bolt(c: Vector2, s: float, col: Color) -> void:
	_blob(c, s, [
		Vector2(0.08, -0.48), Vector2(-0.26, 0.06), Vector2(-0.03, 0.06),
		Vector2(-0.12, 0.48), Vector2(0.27, -0.08), Vector2(0.03, -0.08),
	], col)


## Roti tawar montok mengembang (GDD 4.1 "fluffy loaf").
func _i_bread(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_dot(c, s, -0.22, -0.06, 0.20, col)
	_dot(c, s, 0.00, -0.13, 0.22, col)
	_dot(c, s, 0.22, -0.06, 0.20, col)
	_round_rect(c, s, -0.42, -0.08, 0.84, 0.40, 0.15, col)
	_arcline(c, s, -0.13, -0.12, 0.10, PI * 1.15, PI * 1.85, 0.05, ink)
	_arcline(c, s, 0.13, -0.12, 0.10, PI * 1.15, PI * 1.85, 0.05, ink)


## Kantong kertas roti — tombol belanja / bawa pulang.
func _i_bag(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_arcline(c, s, 0.0, -0.16, 0.17, PI, TAU, 0.07, ink)
	_round_rect(c, s, -0.36, -0.16, 0.72, 0.62, 0.11, col)
	_bar(c, s, -0.30, -0.04, 0.30, -0.04, 0.04, ink)


## Kereta belanja Pasar Bahan Baku (GDD 7).
func _i_cart(c: Vector2, s: float, col: Color) -> void:
	_blob(c, s, [
		Vector2(-0.34, -0.16), Vector2(0.42, -0.16),
		Vector2(0.30, 0.16), Vector2(-0.24, 0.16),
	], col)
	_bar(c, s, -0.48, -0.32, -0.34, -0.16, 0.07, col)
	_bar(c, s, -0.50, -0.32, -0.40, -0.32, 0.07, col)
	_dot(c, s, -0.14, 0.36, 0.10, col)
	_dot(c, s, 0.22, 0.36, 0.10, col)


## Dua pelanggan — jumlah pengunjung harian.
func _i_people(c: Vector2, s: float, col: Color) -> void:
	var back: Color = Color(col, col.a * 0.55)
	_dot(c, s, 0.19, -0.24, 0.14, back)
	_round_rect(c, s, -0.02, -0.08, 0.44, 0.36, 0.16, back)
	_dot(c, s, -0.13, -0.19, 0.18, col)
	_round_rect(c, s, -0.40, 0.02, 0.54, 0.38, 0.19, col)


## Hati — kepuasan pelanggan & favorit.
func _i_heart(c: Vector2, s: float, col: Color) -> void:
	_dot(c, s, -0.19, -0.13, 0.215, col)
	_dot(c, s, 0.19, -0.13, 0.215, col)
	_blob(c, s, [
		Vector2(-0.395, -0.06), Vector2(0.395, -0.06), Vector2(0.0, 0.46),
	], col)


## Wajah marah — pelanggan kabur karena antre terlalu lama (GDD 9.1).
func _i_angry(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_dot(c, s, 0.0, 0.0, 0.45, col)
	_bar(c, s, -0.31, -0.22, -0.09, -0.09, 0.08, ink)
	_bar(c, s, 0.31, -0.22, 0.09, -0.09, 0.08, ink)
	_dot(c, s, -0.17, 0.03, 0.055, ink)
	_dot(c, s, 0.17, 0.03, 0.055, ink)
	_arcline(c, s, 0.0, 0.34, 0.16, PI * 1.15, PI * 1.85, 0.07, ink)


## Wajah sedih — mood Daily Summary "hari yang berat" (GDD 11.2).
func _i_sad(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_dot(c, s, 0.0, 0.0, 0.45, col)
	_bar(c, s, -0.31, -0.14, -0.11, -0.22, 0.07, ink)
	_bar(c, s, 0.31, -0.14, 0.11, -0.22, 0.07, ink)
	_dot(c, s, -0.16, 0.01, 0.06, ink)
	_dot(c, s, 0.16, 0.01, 0.06, ink)
	_arcline(c, s, 0.0, 0.36, 0.15, PI * 1.20, PI * 1.80, 0.07, ink)
	_blob(c, s, [
		Vector2(0.26, 0.05), Vector2(0.33, 0.19), Vector2(0.19, 0.19),
	], _lit(col))
	_dot(c, s, 0.26, 0.20, 0.065, _lit(col))


## Wajah gembira berpipi merona (GDD 4.1 "rosy cheeks").
func _i_happy(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	var blush: Color = Color(Palette.ROSY_CHEEK, 0.70)
	_dot(c, s, 0.0, 0.0, 0.45, col)
	_arcline(c, s, -0.17, 0.03, 0.09, PI * 1.10, PI * 1.90, 0.065, ink)
	_arcline(c, s, 0.17, 0.03, 0.09, PI * 1.10, PI * 1.90, 0.065, ink)
	_dot(c, s, -0.28, 0.17, 0.075, blush)
	_dot(c, s, 0.28, 0.17, 0.075, blush)
	_arcline(c, s, 0.0, 0.10, 0.22, PI * 0.18, PI * 0.82, 0.07, ink)


## Awan hujan — cuaca hujan & lonjakan order RotiFood (GDD 10.2).
func _i_rain(c: Vector2, s: float, col: Color) -> void:
	_dot(c, s, -0.19, -0.14, 0.16, col)
	_dot(c, s, 0.03, -0.22, 0.20, col)
	_dot(c, s, 0.24, -0.12, 0.14, col)
	_round_rect(c, s, -0.35, -0.16, 0.70, 0.22, 0.11, col)
	_bar(c, s, -0.20, 0.16, -0.28, 0.38, 0.065, col)
	_bar(c, s, 0.02, 0.18, -0.06, 0.42, 0.065, col)
	_bar(c, s, 0.24, 0.16, 0.16, 0.38, 0.065, col)


## Matahari cerah golden hour (GDD 10.1).
func _i_sun(c: Vector2, s: float, col: Color) -> void:
	_dot(c, s, 0.0, 0.0, 0.24, col)
	for i in 8:
		var a: float = float(i) * PI * 0.25
		var d: Vector2 = Vector2(cos(a), sin(a))
		_bar(c, s, d.x * 0.34, d.y * 0.34, d.x * 0.48, d.y * 0.48, 0.075, col)


## Terompet konfeti — musim liburan & perayaan (GDD 10.3).
func _i_party(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	var lit: Color = _lit(col)
	_blob(c, s, [
		Vector2(-0.44, 0.44), Vector2(0.00, -0.16), Vector2(0.26, 0.10),
	], col)
	_bar(c, s, 0.00, -0.16, 0.26, 0.10, 0.06, ink)
	_dot(c, s, 0.12, -0.36, 0.06, lit)
	_dot(c, s, 0.34, -0.22, 0.05, ink)
	_dot(c, s, 0.42, 0.04, 0.055, lit)
	_dot(c, s, -0.08, -0.42, 0.05, ink)
	_arcline(c, s, 0.20, -0.20, 0.16, PI * 1.10, PI * 1.70, 0.04, lit)


## Balon pikiran berbentuk awan empuk (GDD 7 "Thought Bubbles").
func _i_bubble(c: Vector2, s: float, col: Color) -> void:
	_dot(c, s, -0.20, -0.16, 0.17, col)
	_dot(c, s, 0.02, -0.24, 0.21, col)
	_dot(c, s, 0.24, -0.14, 0.16, col)
	_round_rect(c, s, -0.36, -0.20, 0.72, 0.28, 0.14, col)
	_dot(c, s, -0.17, 0.19, 0.085, col)
	_dot(c, s, -0.28, 0.36, 0.055, col)


## Centang — konfirmasi, pesanan selesai.
func _i_check(c: Vector2, s: float, col: Color) -> void:
	_bar(c, s, -0.34, 0.02, -0.10, 0.27, 0.13, col)
	_bar(c, s, -0.10, 0.27, 0.35, -0.28, 0.13, col)


## Silang — batal, stok habis, order gagal.
func _i_cross(c: Vector2, s: float, col: Color) -> void:
	_bar(c, s, -0.28, -0.28, 0.28, 0.28, 0.13, col)
	_bar(c, s, 0.28, -0.28, -0.28, 0.28, 0.13, col)


## Tambah — tombol beli porsi "+" di Pasar (GDD 7).
func _i_plus(c: Vector2, s: float, col: Color) -> void:
	_round_rect(c, s, -0.34, -0.09, 0.68, 0.18, 0.09, col)
	_round_rect(c, s, -0.09, -0.34, 0.18, 0.68, 0.09, col)


## Kurang — tombol beli porsi "-" di Pasar (GDD 7).
func _i_minus(c: Vector2, s: float, col: Color) -> void:
	_round_rect(c, s, -0.34, -0.09, 0.68, 0.18, 0.09, col)


## Segitiga peringatan — order batal, stok menipis (GDD 11.3).
func _i_warning(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_blob(c, s, [
		Vector2(0.0, -0.46), Vector2(0.46, 0.36), Vector2(-0.46, 0.36),
	], col)
	_dot(c, s, 0.0, -0.44, 0.07, col)
	_dot(c, s, 0.44, 0.34, 0.07, col)
	_dot(c, s, -0.44, 0.34, 0.07, col)
	_round_rect(c, s, -0.055, -0.17, 0.11, 0.30, 0.055, ink)
	_dot(c, s, 0.0, 0.24, 0.065, ink)


## Api — roti gosong & oven terlalu panas (GDD 4.2).
func _i_fire(c: Vector2, s: float, col: Color) -> void:
	_blob(c, s, [
		Vector2(0.02, -0.48), Vector2(0.20, -0.22), Vector2(0.30, 0.04),
		Vector2(0.22, 0.32), Vector2(0.00, 0.44), Vector2(-0.22, 0.30),
		Vector2(-0.30, 0.02), Vector2(-0.14, -0.20), Vector2(-0.05, -0.31),
	], col)
	_blob(c, s, [
		Vector2(0.02, -0.14), Vector2(0.16, 0.10), Vector2(0.10, 0.32),
		Vector2(-0.06, 0.38), Vector2(-0.17, 0.22), Vector2(-0.12, 0.02),
	], _lit(col))


## Kardus pesanan — paket delivery & stok gudang (GDD 11.3).
func _i_box(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_round_rect(c, s, -0.40, -0.33, 0.80, 0.66, 0.10, col)
	_bar(c, s, -0.38, -0.07, 0.38, -0.07, 0.05, ink)
	_round_rect(c, s, -0.07, -0.33, 0.14, 0.66, 0.03, ink)


## Megafon kampanye pemasaran (GDD 8).
func _i_megaphone(c: Vector2, s: float, col: Color) -> void:
	_blob(c, s, [
		Vector2(-0.44, -0.13), Vector2(0.02, -0.40),
		Vector2(0.02, 0.40), Vector2(-0.44, 0.13),
	], col)
	_round_rect(c, s, -0.50, -0.09, 0.10, 0.18, 0.05, col)
	_arcline(c, s, 0.06, 0.0, 0.16, -PI * 0.34, PI * 0.34, 0.055, col)
	_arcline(c, s, 0.06, 0.0, 0.30, -PI * 0.34, PI * 0.34, 0.055, col)


## Topi koki — staf baker & Mode Solo (GDD 3.5, 11.3).
func _i_chef(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_dot(c, s, -0.22, -0.18, 0.19, col)
	_dot(c, s, 0.00, -0.26, 0.22, col)
	_dot(c, s, 0.22, -0.18, 0.19, col)
	_round_rect(c, s, -0.31, -0.22, 0.62, 0.28, 0.09, col)
	_round_rect(c, s, -0.27, 0.04, 0.54, 0.26, 0.10, col)
	_bar(c, s, -0.22, 0.17, 0.22, 0.17, 0.035, ink)


## Piala — roti terlaris hari ini (GDD 11.3).
func _i_trophy(c: Vector2, s: float, col: Color) -> void:
	_arcline(c, s, -0.26, -0.22, 0.14, PI * 0.5, PI * 1.5, 0.06, col)
	_arcline(c, s, 0.26, -0.22, 0.14, -PI * 0.5, PI * 0.5, 0.06, col)
	_blob(c, s, [
		Vector2(-0.28, -0.40), Vector2(0.28, -0.40), Vector2(0.23, 0.02),
		Vector2(0.00, 0.17), Vector2(-0.23, 0.02),
	], col)
	_round_rect(c, s, -0.07, 0.14, 0.14, 0.16, 0.04, col)
	_round_rect(c, s, -0.25, 0.28, 0.50, 0.14, 0.06, col)


## Sticky note kuning catatan Pak Lurah (GDD 11.4).
func _i_note(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_round_rect(c, s, -0.36, -0.36, 0.72, 0.78, 0.09, col)
	_dot(c, s, 0.0, -0.44, 0.07, ink)
	_bar(c, s, -0.21, -0.14, 0.21, -0.14, 0.055, ink)
	_bar(c, s, -0.21, 0.04, 0.21, 0.04, 0.055, ink)
	_bar(c, s, -0.21, 0.22, 0.05, 0.22, 0.055, ink)


## Bulan sabit — transisi malam menuju hari berikutnya (GDD 11.6).
func _i_moon(c: Vector2, s: float, col: Color) -> void:
	var pts: Array = _crescent_pts(0.44, 0.20, -0.06, 0.38)
	if pts.is_empty():
		_dot(c, s, 0.0, 0.0, 0.44, col)
		return
	_blob(c, s, pts, col)
	_dot(c, s, -0.30, -0.30, 0.045, _lit(col))
	_dot(c, s, -0.38, -0.10, 0.030, _lit(col))


## Skuter kurir ojek online RotiFood (GDD 3.6).
func _i_scooter(c: Vector2, s: float, col: Color) -> void:
	_arcline(c, s, -0.28, 0.26, 0.14, 0.0, TAU, 0.07, col)
	_arcline(c, s, 0.30, 0.26, 0.14, 0.0, TAU, 0.07, col)
	_round_rect(c, s, -0.26, 0.10, 0.42, 0.10, 0.05, col)
	_round_rect(c, s, 0.06, -0.10, 0.28, 0.24, 0.08, col)
	_round_rect(c, s, 0.16, -0.40, 0.28, 0.26, 0.06, col)
	_bar(c, s, -0.22, 0.12, -0.14, -0.30, 0.07, col)
	_bar(c, s, -0.30, -0.34, -0.02, -0.28, 0.06, col)


## Jam pasir — keluhan antrean lama (GDD 7).
func _i_hourglass(c: Vector2, s: float, col: Color) -> void:
	var lit: Color = _lit(col)
	_round_rect(c, s, -0.32, -0.46, 0.64, 0.11, 0.05, col)
	_round_rect(c, s, -0.32, 0.35, 0.64, 0.11, 0.05, col)
	_blob(c, s, [
		Vector2(-0.26, -0.35), Vector2(0.26, -0.35), Vector2(0.0, 0.0),
	], col)
	_blob(c, s, [
		Vector2(-0.26, 0.35), Vector2(0.26, 0.35), Vector2(0.0, 0.0),
	], col)
	_blob(c, s, [
		Vector2(-0.18, -0.29), Vector2(0.18, -0.29), Vector2(0.0, -0.03),
	], lit)
	_blob(c, s, [
		Vector2(-0.20, 0.32), Vector2(0.20, 0.32), Vector2(0.0, 0.14),
	], lit)
	_bar(c, s, 0.0, -0.02, 0.0, 0.14, 0.03, lit)


## Jeda — dua batang tegak membulat (tombol Jeda di HUD).
func _i_pause(c: Vector2, s: float, col: Color) -> void:
	_round_rect(c, s, -0.28, -0.34, 0.20, 0.68, 0.09, col)
	_round_rect(c, s, 0.08, -0.34, 0.20, 0.68, 0.09, col)


## Lanjut — segitiga main (tombol yang sama saat waktu sedang dijeda).
func _i_play(c: Vector2, s: float, col: Color) -> void:
	_blob(c, s, [
		Vector2(-0.24, -0.36), Vector2(0.34, 0.0), Vector2(-0.24, 0.36),
	], col)


## Dapur — badan oven dengan pintu kaca dan satu kenop (sudut pandang dapur).
func _i_kitchen(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	var lit: Color = _lit(col)
	_round_rect(c, s, -0.40, -0.36, 0.80, 0.72, 0.10, col)
	_round_rect(c, s, -0.30, -0.22, 0.60, 0.44, 0.07, ink)
	_round_rect(c, s, -0.24, -0.16, 0.48, 0.32, 0.05, lit)
	_bar(c, s, -0.30, -0.29, 0.14, -0.29, 0.06, ink)
	_dot(c, s, 0.27, -0.29, 0.06, ink)


## Toko — tenda bergaris di atas etalase (sudut pandang area pembeli).
func _i_shop(c: Vector2, s: float, col: Color) -> void:
	var ink: Color = _ink(col)
	_round_rect(c, s, -0.42, -0.02, 0.84, 0.40, 0.08, col)
	_blob(c, s, [
		Vector2(-0.46, -0.06), Vector2(-0.34, -0.36),
		Vector2(0.34, -0.36), Vector2(0.46, -0.06),
	], ink)
	# Tiga guratan tenda supaya terbaca kanopi, bukan sekadar atap.
	_bar(c, s, -0.20, -0.34, -0.26, -0.07, 0.05, col)
	_bar(c, s, 0.0, -0.36, 0.0, -0.07, 0.05, col)
	_bar(c, s, 0.20, -0.34, 0.26, -0.07, 0.05, col)
	_round_rect(c, s, -0.10, 0.12, 0.20, 0.26, 0.04, ink)


## Bingkai — empat siku sudut, artinya "lihat semuanya sekaligus".
func _i_frame(c: Vector2, s: float, col: Color) -> void:
	var a: float = 0.38
	var b: float = 0.14
	var w: float = 0.11
	_bar(c, s, -a, -a, -b, -a, w, col)
	_bar(c, s, -a, -a, -a, -b, w, col)
	_bar(c, s, a, -a, b, -a, w, col)
	_bar(c, s, a, -a, a, -b, w, col)
	_bar(c, s, -a, a, -b, a, w, col)
	_bar(c, s, -a, a, -a, b, w, col)
	_bar(c, s, a, a, b, a, w, col)
	_bar(c, s, a, a, a, b, w, col)


## Roda gigi — tombol Menu di HUD (suara, simpan, keluar).
##
## Gigi dibentuk sebagai satu poligon dengan jari-jari berselang-seling, lalu
## lubang porosnya digambar sebagai lingkaran tinta di tengah — cara yang sama
## dipakai ikon lain untuk memberi kesan "berlubang" tanpa warna latar.
func _i_gear(c: Vector2, s: float, col: Color) -> void:
	var pts: Array = []
	var gigi: int = 8
	var n: int = gigi * 4
	for i in n:
		var a: float = float(i) * TAU / float(n)
		var r: float = 0.44 if (i % 4) < 2 else 0.33
		pts.append(Vector2(cos(a), sin(a)) * r)
	_blob(c, s, pts, col)
	_dot(c, s, 0.0, 0.0, 0.14, _ink(col))


## Badan pengeras suara (kotak + corong), dipakai ikon `sound` dan `mute`.
func _speaker(c: Vector2, s: float, col: Color) -> void:
	_round_rect(c, s, -0.42, -0.13, 0.20, 0.26, 0.06, col)
	_blob(c, s, [
		Vector2(-0.26, -0.12), Vector2(-0.04, -0.34),
		Vector2(-0.04, 0.34), Vector2(-0.26, 0.12),
	], col)


## Suara nyala — pengeras suara dengan dua gelombang.
func _i_sound(c: Vector2, s: float, col: Color) -> void:
	_speaker(c, s, col)
	_arcline(c, s, -0.02, 0.0, 0.24, -PI * 0.36, PI * 0.36, 0.07, col)
	_arcline(c, s, -0.02, 0.0, 0.40, -PI * 0.34, PI * 0.34, 0.07, col)


## Suara mati — pengeras suara yang gelombangnya diganti tanda silang.
func _i_mute(c: Vector2, s: float, col: Color) -> void:
	_speaker(c, s, col)
	_bar(c, s, 0.10, -0.18, 0.42, 0.18, 0.08, col)
	_bar(c, s, 0.42, -0.18, 0.10, 0.18, 0.08, col)


## Cadangan bila nama ikon tidak dikenal: cincin + titik tanya sederhana.
func _i_unknown(c: Vector2, s: float, col: Color) -> void:
	_arcline(c, s, 0.0, 0.0, 0.40, 0.0, TAU, 0.08, col)
	_arcline(c, s, 0.0, -0.10, 0.14, PI * 0.95, TAU * 0.98, 0.08, col)
	_bar(c, s, 0.14, -0.08, 0.02, 0.10, 0.08, col)
	_dot(c, s, 0.0, 0.24, 0.07, col)
