class_name TabIcon
extends Control
## Ikon tab bawah HUD (GDD idle 12.0.5, Seksi 20 no. 104): ilustrasi kecil
## berwarna di atas piring bundar pastel, digambar di `_draw()` (v3.1 4.3,
## 111: tanpa berkas gambar). Gaya flat (v3.1 130.6): tanpa garis tepi,
## bayangan, kilap, atau gradasi; sisi gelap sebuah bentuk adalah bidang warna
## kedua. Tiap tab punya piring berwarna sendiri supaya cepat dikenali. Tab
## aktif (tombol madu) piringnya sedikit membesar dan ikonnya memantul sekali
## (diam bila Reduced Motion).
##
## Semua ukuran dalam satuan sisi ikon (`icon_size`), berpusat di tengah.

const KINDS: Array[StringName] = [&"upgrades", &"menu", &"staff", &"shop", &"decor", &"franchise"]
## Piring pastel per tab.
const PLATES: Dictionary = {
	&"upgrades": Color(0.80, 0.93, 0.84),
	&"menu": Color(0.80, 0.90, 0.98),
	&"staff": Color(1.0, 0.80, 0.70),
	&"shop": Color(1.0, 0.91, 0.66),
	&"decor": Color(1.0, 0.85, 0.85),
	&"franchise": Color(0.87, 0.85, 0.98),
}
const PLATE_R: float = 0.44
const PLATE_R_ACTIVE: float = 0.47
const INK: Color = Palette.DARK_CHOCOLATE
const WHITE: Color = Palette.FLOUR_WHITE
const BLUSH: Color = Color(0.988, 0.596, 0.506)
const SKIN: Color = Color(0.949, 0.788, 0.627)
const HAIR: Color = Color(0.42, 0.25, 0.13)
const GLASS: Color = Color(0.72, 0.87, 0.97)
const BOLT_TOP: Color = Color(1.0, 0.82, 0.25)
const STAR_LIT: Color = Color(1.0, 0.80, 0.22)
const STAR_DARK: Color = Color(0.94, 0.62, 0.06)
const BREAD_BODY: Color = Color(0.976, 0.769, 0.435)
const BREAD_SCORE: Color = Color(1.0, 0.882, 0.627)
const POT_RIM: Color = Color(0.86, 0.50, 0.32)
const TOQUE_BAND: Color = Color(0.95, 0.90, 0.82)

## Tab yang digambar (salah satu [constant KINDS]).
var kind: StringName = &"upgrades":
	set(value):
		kind = value
		queue_redraw()

## Tab sedang aktif (lembarnya terbuka): piring membesar dan ikon memantul.
var active: bool = false:
	set(value):
		if value == active:
			return
		active = value
		queue_redraw()
		if value:
			_pop()

var icon_size: float = 46.0:
	set(value):
		icon_size = maxf(value, 16.0)
		custom_minimum_size = Vector2(icon_size, icon_size)
		queue_redraw()

var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(icon_size, icon_size)


func _draw() -> void:
	var s: float = icon_size
	var c: Vector2 = (size if size != Vector2.ZERO else custom_minimum_size) * 0.5
	_disc(c, s, 0.0, 0.0, PLATE_R_ACTIVE if active else PLATE_R, PLATES.get(kind, PLATES[&"upgrades"]))
	match kind:
		&"menu": _menu(c, s)
		&"staff": _staff(c, s)
		&"shop": _shop(c, s)
		&"decor": _decor(c, s)
		&"franchise": _franchise(c, s)
		_: _upgrades(c, s)


## Pantulan squash & stretch sekali saat tab menjadi aktif.
func _pop() -> void:
	if not is_inside_tree() or SettingsManager.reduced_motion():
		return
	if _tween != null and _tween.is_valid():
		_tween.kill()
	pivot_offset = size * 0.5
	scale = Vector2(1.16, 0.86)
	_tween = create_tween()
	_tween.tween_property(self, "scale", Vector2.ONE, 0.32).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ---------------------------------------------------------------------------
# Ikon
# ---------------------------------------------------------------------------

## Upgrades: kilat dua bidang (segitiga atas kuning, segitiga bawah madu) dan
## dua kilau.
func _upgrades(c: Vector2, s: float) -> void:
	_poly(c, s, [Vector2(0.13, -0.42), Vector2(-0.25, 0.08), Vector2(0.07, 0.08)], BOLT_TOP)
	_poly(c, s, [Vector2(-0.11, 0.44), Vector2(0.27, -0.06), Vector2(-0.05, -0.06)], Palette.HONEY)
	_sparkle(c, s, -0.28, -0.25, 0.10, Palette.HONEY)
	_sparkle(c, s, 0.30, 0.23, 0.07, Palette.HONEY)


## Menu: roti maskot (LogoBread) berwajah imut.
func _menu(c: Vector2, s: float) -> void:
	var o: Vector2 = c + Vector2(0.0, 0.01) * s
	var t: float = s * 0.88
	_rrect(o, t, -0.37, -0.04, 0.74, 0.37, 0.10, BREAD_BODY)
	_poly(o, t, LogoBread.cap_points(), Palette.GOLDEN_CRUST)
	for sc: Array in [[-0.25, -0.07, -0.15, -0.19], [-0.05, -0.10, 0.05, -0.24], [0.15, -0.07, 0.25, -0.19]]:
		_stroke(o, t, Vector2(sc[0], sc[1]), Vector2(sc[2], sc[3]), 0.065, BREAD_SCORE)
	for side: float in [-1.0, 1.0]:
		_poly(o, t, _ellipse(Vector2(0.125 * side, 0.135), Vector2(0.05, 0.062)), INK)
		_disc(o, t, 0.125 * side - 0.016, 0.115, 0.018, WHITE)
		_poly(o, t, _ellipse(Vector2(0.245 * side, 0.20), Vector2(0.06, 0.036)), BLUSH)
	_arc(o, t, Vector2(0.0, 0.165), 0.05, 0.15 * PI, 0.85 * PI, 0.03, INK)


## Staff: koki bertopi tinggi dan berkerah merah, setengah badan di dalam piring.
func _staff(c: Vector2, s: float) -> void:
	# Jas putih dipotong lingkaran piring (kesan foto profil).
	var coat: PackedVector2Array = ProceduralUIFactory.rounded_points(Rect2(c + Vector2(-0.33, 0.22) * s, Vector2(0.66, 0.40) * s), 0.17 * s, 6)
	var pr: float = (PLATE_R_ACTIVE if active else PLATE_R) * s
	for part: PackedVector2Array in Geometry2D.intersect_polygons(coat, _ellipse(c, Vector2(pr, pr), 48)):
		ProceduralUIFactory.fill_aa(self, part, WHITE)
	_disc(c, s, -0.07, 0.35, 0.022, Palette.CARAMEL)
	_disc(c, s, 0.07, 0.35, 0.022, Palette.CARAMEL)
	_rrect(c, s, -0.055, 0.16, 0.11, 0.09, 0.02, SKIN)
	_poly(c, s, [Vector2(-0.11, 0.22), Vector2(0.11, 0.22), Vector2(0.0, 0.33)], Palette.STRAWBERRY)
	# Rambut di sisi kepala, telinga, lalu wajah.
	_disc(c, s, 0.0, 0.0, 0.20, HAIR)
	_disc(c, s, -0.18, 0.07, 0.045, SKIN)
	_disc(c, s, 0.18, 0.07, 0.045, SKIN)
	_disc(c, s, 0.0, 0.055, 0.175, SKIN)
	# Topi koki: tiga gembungan, badan, dan pita.
	_rrect(c, s, -0.15, -0.30, 0.30, 0.16, 0.04, WHITE)
	_disc(c, s, -0.11, -0.25, 0.105, WHITE)
	_disc(c, s, 0.11, -0.25, 0.105, WHITE)
	_disc(c, s, 0.0, -0.30, 0.125, WHITE)
	_rrect(c, s, -0.19, -0.18, 0.38, 0.10, 0.035, TOQUE_BAND)
	for side: float in [-1.0, 1.0]:
		_disc(c, s, 0.065 * side, 0.06, 0.03, INK)
		_disc(c, s, 0.065 * side - 0.01, 0.05, 0.01, WHITE)
		_poly(c, s, _ellipse(Vector2(0.115 * side, 0.115), Vector2(0.036, 0.022)), BLUSH)
	_arc(c, s, Vector2(0.0, 0.095), 0.045, 0.2 * PI, 0.8 * PI, 0.024, INK)


## Shop: toko kayu berkanopi garis stroberi, dua jendela, dan pintu (sedikit
## lebih kecil dari ikon lain supaya piringnya tetap terlihat di sekelilingnya).
func _shop(c0: Vector2, s0: float) -> void:
	var c: Vector2 = c0 + Vector2(0.0, 0.01) * s0
	var s: float = s0 * 0.88
	_rrect(c, s, -0.38, 0.35, 0.76, 0.08, 0.035, Palette.UI_WOOD)
	_rrect(c, s, -0.32, -0.14, 0.64, 0.51, 0.03, Palette.PINE_WOOD)
	for wx: float in [-0.27, 0.12]:
		_rrect(c, s, wx, -0.01, 0.15, 0.15, 0.035, GLASS)
		_stroke(c, s, Vector2(wx + 0.075, 0.0), Vector2(wx + 0.075, 0.13), 0.018, WHITE)
	_rrect(c, s, -0.085, 0.09, 0.17, 0.28, 0.05, Palette.CARAMEL)
	_rrect(c, s, -0.05, 0.13, 0.10, 0.08, 0.02, GLASS)
	_disc(c, s, 0.045, 0.27, 0.018, Palette.BUTTER_YELLOW)
	# Kanopi: enam garis yang melebar ke bawah dengan tepi bergelombang.
	var n: int = 6
	for i in n:
		var t0: float = float(i) / float(n)
		var t1: float = float(i + 1) / float(n)
		var col: Color = Palette.STRAWBERRY if i % 2 == 0 else WHITE
		_poly(c, s, [Vector2(lerpf(-0.33, 0.33, t0), -0.34), Vector2(lerpf(-0.33, 0.33, t1), -0.34),
			Vector2(lerpf(-0.41, 0.41, t1), -0.13), Vector2(lerpf(-0.41, 0.41, t0), -0.13)], col)
		var mx: float = lerpf(-0.41, 0.41, (t0 + t1) * 0.5)
		var r: float = 0.82 / float(n) * 0.5
		var cup: Array = []
		for k in 9:
			var a: float = PI * float(k) / 8.0
			cup.append(Vector2(mx + cos(a) * r, -0.135 + sin(a) * r))
		_poly(c, s, cup, col)
	_rrect(c, s, -0.36, -0.41, 0.72, 0.08, 0.04, Palette.STRAWBERRY_DEEP)


## Decor: tanaman pot terakota berdaun dua warna dengan sekuntum bunga.
func _decor(c: Vector2, s: float) -> void:
	_leaf(c, s, Vector2(-0.03, 0.10), Vector2(-0.39, -0.19), 0.24)
	_leaf(c, s, Vector2(0.03, 0.10), Vector2(0.38, -0.22), 0.24)
	_leaf(c, s, Vector2(0.0, 0.10), Vector2(0.02, -0.42), 0.28)
	_poly(c, s, [Vector2(-0.19, 0.12), Vector2(0.19, 0.12), Vector2(0.14, 0.44), Vector2(-0.14, 0.44)], Palette.TERRACOTTA)
	_poly(c, s, [Vector2(0.05, 0.12), Vector2(0.19, 0.12), Vector2(0.14, 0.44), Vector2(0.04, 0.44)], Palette.ROOF_TILE_DEEP)
	_rrect(c, s, -0.23, 0.05, 0.46, 0.10, 0.035, POT_RIM)
	var f := Vector2(0.24, -0.35)
	for i in 5:
		var a: float = -PI * 0.5 + TAU * float(i) / 5.0
		_disc(c, s, f.x + cos(a) * 0.058, f.y + sin(a) * 0.058, 0.05, Palette.STRAWBERRY)
	_disc(c, s, f.x, f.y, 0.042, Palette.BUTTER_YELLOW)


## Franchise: bintang bersegi (sisi terang dan gelap bergantian) berwajah imut.
func _franchise(c: Vector2, s: float) -> void:
	var o := Vector2(0.0, 0.03)
	var pts: Array = []
	for i in 10:
		var a: float = -PI * 0.5 + float(i) * PI / 5.0
		var r: float = 0.46 if i % 2 == 0 else 0.215
		pts.append(o + Vector2(cos(a), sin(a)) * r)
	for i in 10:
		_poly(c, s, [o, pts[i], pts[(i + 1) % 10]], STAR_LIT if i % 2 == 1 else STAR_DARK)
	for side: float in [-1.0, 1.0]:
		_disc(c, s, o.x + 0.065 * side, o.y + 0.0, 0.03, INK)
		_poly(c, s, _ellipse(o + Vector2(0.12 * side, 0.06), Vector2(0.035, 0.02)), BLUSH)
	_arc(c, s, o + Vector2(0.0, 0.035), 0.04, 0.2 * PI, 0.8 * PI, 0.022, INK)
	_sparkle(c, s, 0.34, -0.33, 0.08, WHITE)
	_sparkle(c, s, -0.35, 0.27, 0.055, WHITE)


# ---------------------------------------------------------------------------
# Alat gambar (koordinat satuan, dikali `s` dan digeser ke `c`)
# ---------------------------------------------------------------------------

## Poligon terisi; `pts` berupa Array atau PackedVector2Array satuan.
func _poly(c: Vector2, s: float, pts: Variant, col: Color) -> void:
	var out := PackedVector2Array()
	for p: Vector2 in pts:
		out.append(c + p * s)
	ProceduralUIFactory.fill_aa(self, out, col)


func _disc(c: Vector2, s: float, x: float, y: float, r: float, col: Color) -> void:
	draw_circle(c + Vector2(x, y) * s, r * s, col, true, -1.0, true)


func _rrect(c: Vector2, s: float, x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
	ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(Rect2(c + Vector2(x, y) * s, Vector2(w, h) * s), r * s, 5), col)


## Garis tebal berujung bulat.
func _stroke(c: Vector2, s: float, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(c + a * s, c + b * s, col, w * s, true)
	draw_circle(c + a * s, w * s * 0.5, col, true, -1.0, true)
	draw_circle(c + b * s, w * s * 0.5, col, true, -1.0, true)


## Busur tebal berujung bulat (senyum).
func _arc(c: Vector2, s: float, ctr: Vector2, r: float, a0: float, a1: float, w: float, col: Color) -> void:
	var p: Vector2 = c + ctr * s
	draw_arc(p, r * s, a0, a1, 12, col, w * s, true)
	draw_circle(p + Vector2(cos(a0), sin(a0)) * r * s, w * s * 0.5, col, true, -1.0, true)
	draw_circle(p + Vector2(cos(a1), sin(a1)) * r * s, w * s * 0.5, col, true, -1.0, true)


## Kilau bintang empat sudut.
func _sparkle(c: Vector2, s: float, x: float, y: float, r: float, col: Color) -> void:
	var p := Vector2(x, y)
	var w: float = r * 0.32
	_poly(c, s, [p + Vector2(0.0, -r), p + Vector2(w, -w), p + Vector2(r, 0.0), p + Vector2(w, w),
		p + Vector2(0.0, r), p + Vector2(-w, w), p + Vector2(-r, 0.0), p + Vector2(-w, -w)], col)


## Daun lonjong dari `base` ke `tip`: belahan kiri hijau terang, kanan gelap.
func _leaf(c: Vector2, s: float, base: Vector2, tip: Vector2, width: float) -> void:
	var d: Vector2 = tip - base
	var n: Vector2 = Vector2(-d.y, d.x).normalized()
	for side: float in [1.0, -1.0]:
		var half: Array = [base]
		for i in range(1, 10):
			var t: float = float(i) / 10.0
			half.append(base + d * t + n * side * sin(PI * pow(t, 0.8)) * width * 0.5)
		half.append(tip)
		_poly(c, s, half, Palette.MATCHA if side < 0.0 else Palette.LEAF_DEEP)


static func _ellipse(ctr: Vector2, r: Vector2, n: int = 18) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(ctr + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out
