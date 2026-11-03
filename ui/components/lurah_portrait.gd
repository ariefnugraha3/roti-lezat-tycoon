class_name LurahPortrait
extends Control
## Potret Pak Lurah (v3.1 3.0.A, 12.3.3 potret 2D) digambar dengan _draw():
## chibi tambun ramah berpeci beludru hitam, rambut dan kumis tebal beruban,
## baju safari krem berkerah dengan saku dada, pena, dan lencana emas. Avatar
## bundar mint di belakangnya; badan dipotong lingkaran itu. Tanpa tangan
## (keputusan maintainer 2026-11-03). Flat (v3.1 130.6): bidang warna polos
## tanpa garis tepi, bayangan, atau gradasi. Dipakai popup tutorial, Selamat
## Datang, dan cutscene Waralaba (GDD idle 9.5, 10.6, 13).

## Warna safari krem (sama dengan model 3D-nya, CharacterFactory.spec_for_lurah).
const SAFARI: Color = Color(0.827, 0.780, 0.596)  # #D3C798
const PECI: Color = Color(0.165, 0.157, 0.200)  # #2A2833
const BACKDROP: Color = Color(0.835, 0.929, 0.886)  # #D5EDE2

## Lingkaran avatar dalam satuan u (setengah sisi terpendek).
var _circle: PackedVector2Array = PackedVector2Array()


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	var s: float = minf(size.x, size.y)
	if s < 24.0:
		return
	var u: float = s * 0.5
	var o: Vector2 = size * 0.5
	_circle = _ell(o, u * 0.96, u * 0.96, 0.0, TAU, 48)
	draw_colored_polygon(_circle, BACKDROP)
	# Kilau lingkaran latar: dua titik krem kecil (flat), suasana ramah.
	draw_circle(o + Vector2(-0.62, -0.58) * u, u * 0.05, Color(Palette.FLOUR_WHITE, 0.8), true, -1.0, true)
	draw_circle(o + Vector2(-0.74, -0.42) * u, u * 0.03, Color(Palette.FLOUR_WHITE, 0.8), true, -1.0, true)
	_body(o, u)
	_head(o, u)


# --- alat gambar -------------------------------------------------------------

## Titik-titik elips (busur a0..a1).
static func _ell(p: Vector2, rx: float, ry: float, a0: float = 0.0, a1: float = TAU, n: int = 28) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var full: bool = absf(a1 - a0 - TAU) < 0.001
	var count: int = n if full else n + 1
	for i in count:
		var a: float = a0 + (a1 - a0) * float(i) / float(n)
		pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Poligon terisi yang dipotong lingkaran avatar.
func _clip(poly: PackedVector2Array, col: Color) -> void:
	for piece: PackedVector2Array in Geometry2D.intersect_polygons(poly, _circle):
		if piece.size() >= 3:
			draw_colored_polygon(piece, col)


func _oval(p: Vector2, rx: float, ry: float, col: Color) -> void:
	draw_colored_polygon(_ell(p, rx, ry), col)


func _box(r: Rect2, radius: float) -> PackedVector2Array:
	return ProceduralUIFactory.rounded_points(r, radius, 5)


func _pts(o: Vector2, u: float, unit: Array) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in unit:
		out.append(o + v * u)
	return out


# --- badan -------------------------------------------------------------------

func _body(o: Vector2, u: float) -> void:
	var dark: Color = SAFARI.darkened(0.12)
	var light: Color = SAFARI.lightened(0.22)
	var skin: Color = CharacterFactory.SKIN_TAN
	# Leher, lalu badan safari tambun.
	_clip(_box(Rect2(o + Vector2(-0.14, 0.16) * u, Vector2(0.28, 0.22) * u), u * 0.06), skin.darkened(0.08))
	_clip(_box(Rect2(o + Vector2(-0.82, 0.30) * u, Vector2(1.64, 1.10) * u), u * 0.46), SAFARI)
	# Kaos dalam putih di leher V, lalu kerah lancip.
	_clip(_pts(o, u, [Vector2(-0.17, 0.30), Vector2(0.17, 0.30), Vector2(0.0, 0.54)]), Palette.FLOUR_WHITE)
	_clip(_pts(o, u, [Vector2(0.0, 0.50), Vector2(-0.20, 0.27), Vector2(-0.40, 0.31), Vector2(-0.24, 0.56)]), light)
	_clip(_pts(o, u, [Vector2(0.0, 0.50), Vector2(0.20, 0.27), Vector2(0.40, 0.31), Vector2(0.24, 0.56)]), light)
	# Bilah kancing.
	_clip(_box(Rect2(o + Vector2(-0.035, 0.50) * u, Vector2(0.07, 0.50) * u), u * 0.02), dark)
	for y: float in [0.64, 0.82]:
		draw_circle(o + Vector2(0.0, y) * u, u * 0.035, Palette.CARAMEL.lightened(0.15), true, -1.0, true)
	# Saku dada bertutup; pena di saku kanan penonton, lencana emas di kiri.
	for sx: float in [-1.0, 1.0]:
		var px: float = 0.26 if sx > 0.0 else -0.56
		if sx > 0.0:
			_clip(_box(Rect2(o + Vector2(px + 0.08, 0.50) * u, Vector2(0.06, 0.20) * u), u * 0.02), Palette.APRON_NAVY)
			draw_circle(o + Vector2(px + 0.11, 0.50) * u, u * 0.03, Palette.BRASS, true, -1.0, true)
		_clip(_box(Rect2(o + Vector2(px, 0.62) * u, Vector2(0.30, 0.28) * u), u * 0.05), dark)
		_clip(_box(Rect2(o + Vector2(px - 0.01, 0.60) * u, Vector2(0.32, 0.09) * u), u * 0.04), dark.darkened(0.08))
	_clip(_ell(o + Vector2(-0.41, 0.48) * u, u * 0.07, u * 0.07), Palette.GOLD_STAR)
	_clip(_ell(o + Vector2(-0.41, 0.48) * u, u * 0.035, u * 0.035), Palette.BRASS.darkened(0.1))


# --- kepala ------------------------------------------------------------------

func _head(o: Vector2, u: float) -> void:
	var skin: Color = CharacterFactory.SKIN_TAN
	var hc: Vector2 = o + Vector2(0.0, -0.13) * u
	var grey: Color = CharacterFactory.HAIR_GREY
	var grey_deep: Color = grey.darkened(0.18)
	# Rambut belakang, telinga, lalu wajah bulat tembam.
	_oval(hc + Vector2(0.0, -0.10) * u, u * 0.50, u * 0.40, grey_deep)
	for sx: float in [-1.0, 1.0]:
		_oval(hc + Vector2(sx * 0.47, 0.04) * u, u * 0.10, u * 0.12, skin)
		_oval(hc + Vector2(sx * 0.48, 0.05) * u, u * 0.05, u * 0.07, skin.darkened(0.12))
	_oval(hc + Vector2(0.0, 0.02) * u, u * 0.47, u * 0.43, skin)
	# Cambang uban: rambut yang menyembul dari bawah peci, menipis ke telinga.
	for sx2: float in [-1.0, 1.0]:
		draw_colored_polygon(_pts(hc, u, [Vector2(sx2 * 0.30, -0.30), Vector2(sx2 * 0.46, -0.27),
			Vector2(sx2 * 0.45, -0.06), Vector2(sx2 * 0.39, 0.00), Vector2(sx2 * 0.36, -0.16), Vector2(sx2 * 0.28, -0.24)]), grey)
	# Pipi merona, mata berbinar, alis tebal.
	for sx3: float in [-1.0, 1.0]:
		_oval(hc + Vector2(sx3 * 0.27, 0.15) * u, u * 0.09, u * 0.055, Color(Palette.ROSY_CHEEK, 0.55))
		var e: Vector2 = hc + Vector2(sx3 * 0.17, -0.02) * u
		_oval(e, u * 0.055, u * 0.07, CharacterFactory.EYE_COLOR)
		draw_circle(e + Vector2(-0.018, -0.025) * u, u * 0.022, Palette.FLOUR_WHITE, true, -1.0, true)
		draw_colored_polygon(_pts(hc, u, [Vector2(sx3 * 0.08, -0.14), Vector2(sx3 * 0.27, -0.17),
			Vector2(sx3 * 0.28, -0.12), Vector2(sx3 * 0.09, -0.10)]), grey_deep)
	# Hidung bulat kecil.
	_oval(hc + Vector2(0.0, 0.08) * u, u * 0.065, u * 0.05, skin.darkened(0.14))
	# Senyum lebar terbuka dengan lidah, lalu kumis tebal di atasnya.
	var mouth: PackedVector2Array = _ell(hc + Vector2(0.0, 0.19) * u, u * 0.13, u * 0.11, 0.0, PI, 16)
	draw_colored_polygon(mouth, CharacterFactory.MOUTH_COLOR)
	_oval(hc + Vector2(0.0, 0.26) * u, u * 0.065, u * 0.035, Palette.STRAWBERRY.lightened(0.15))
	for sx4: float in [-1.0, 1.0]:
		draw_colored_polygon(_pts(hc, u, [Vector2(0.0, 0.12), Vector2(sx4 * 0.05, 0.10), Vector2(sx4 * 0.17, 0.11),
			Vector2(sx4 * 0.24, 0.17), Vector2(sx4 * 0.20, 0.20), Vector2(sx4 * 0.08, 0.18), Vector2(0.0, 0.19)]), grey)
	_peci(hc, u)


## Peci beludru hitam: badan tegak sedikit melebar ke bawah, bagian atas lebih
## terang sebagai bidang kedua (flat), dan tepi bawah melengkung di dahi.
func _peci(hc: Vector2, u: float) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	var top: float = -0.60
	var bottom: float = -0.27
	pts.append(hc + Vector2(-0.40, top + 0.04) * u)
	pts.append(hc + Vector2(-0.36, top) * u)
	pts.append(hc + Vector2(0.36, top) * u)
	pts.append(hc + Vector2(0.40, top + 0.04) * u)
	pts.append(hc + Vector2(0.45, bottom) * u)
	for i in 13:
		var t: float = float(i) / 12.0
		var x: float = lerpf(0.45, -0.45, t)
		pts.append(hc + Vector2(x, bottom + 0.05 * (1.0 - pow(x / 0.45, 2.0))) * u)
	draw_colored_polygon(pts, PECI)
	draw_colored_polygon(_box(Rect2(hc + Vector2(-0.36, top) * u, Vector2(0.72, 0.07) * u), u * 0.03), PECI.lightened(0.14))
