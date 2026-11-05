class_name LogoBread
extends Control
## Roti maskot logo Crumbtown (splash, menu utama, kartu share, trailer): roti
## tawar berkubah dengan wajah imut, digambar flat (GDD 4, 130.6) tanpa bayangan
## atau kilap. Kubah kerak keemasan dengan tiga guratan sayatan menumpang di
## badan roti yang lebih pucat; uap tipis mengepul di atasnya dan dua kilau
## kecil berkedip di sampingnya. Reduced Motion = diam.
##
## Semua ukuran dalam satuan sisi kontrol (`icon_size`), berpusat di tengah.

const CRUST: Color = Palette.GOLDEN_CRUST
const BODY: Color = Color(0.976, 0.769, 0.435)
const SCORE: Color = Color(1.0, 0.882, 0.627)
const INK: Color = Palette.DARK_CHOCOLATE
const BLUSH: Color = Color(0.988, 0.596, 0.506)
const STEAM: Color = Palette.FLOUR_WHITE
## Turun sedikit dari tengah supaya uap di atas kubah tetap di dalam kotak.
const DROP: float = 0.07

var icon_size: float = 124.0:
	set(value):
		icon_size = maxf(value, 16.0)
		custom_minimum_size = Vector2(icon_size, icon_size)
		queue_redraw()

var _t: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	custom_minimum_size = Vector2(icon_size, icon_size)


func _process(delta: float) -> void:
	if SettingsManager.reduced_motion() or not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()


func _draw() -> void:
	var s: float = icon_size
	var c: Vector2 = (size if size != Vector2.ZERO else custom_minimum_size) * 0.5 + Vector2(0.0, DROP * s)
	_steam(c, s)
	# Badan roti (sisi loyang, lebih pucat) lalu kubah kerak di atasnya.
	ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(
		Rect2(c + Vector2(-0.37, -0.04) * s, Vector2(0.74, 0.37) * s), 0.10 * s, 6), BODY)
	ProceduralUIFactory.fill_aa(self, _offset(cap_points(), c, s), CRUST)
	for sc: Array in [[-0.25, -0.07, -0.15, -0.19], [-0.05, -0.10, 0.05, -0.24], [0.15, -0.07, 0.25, -0.19]]:
		_stroke(c, s, Vector2(sc[0], sc[1]), Vector2(sc[2], sc[3]), 0.058, SCORE)
	_face(c, s)
	_sparkle(c + Vector2(0.45, -0.20) * s, 0.075 * s, 0.0)
	_sparkle(c + Vector2(-0.47, -0.02) * s, 0.055 * s, 1.9)


## Kubah kerak: setengah superelips di atas, bibir bawah membulat yang sedikit
## menggantung di luar badan roti (satuan, berpusat di tengah roti).
static func cap_points() -> PackedVector2Array:
	var pts := PackedVector2Array()
	var rx: float = 0.45
	var ry: float = 0.34
	var cy: float = 0.02
	var n: int = 28
	for i in n + 1:
		var a: float = PI + PI * float(i) / float(n)
		var ca: float = cos(a)
		var sa: float = sin(a)
		# Superelips (eksponen 2.6): kubah yang lebih penuh dari setengah elips.
		var x: float = signf(ca) * pow(absf(ca), 2.0 / 2.6) * rx
		var y: float = signf(sa) * pow(absf(sa), 2.0 / 2.6) * ry
		pts.append(Vector2(x, cy + y))
	var lip: float = 0.065
	for i in 7:
		var a2: float = PI * 0.5 * float(i) / 6.0
		pts.append(Vector2(rx - lip + cos(a2) * lip, cy + sin(a2) * lip))
	for i in 7:
		var a3: float = PI * 0.5 + PI * 0.5 * float(i) / 6.0
		pts.append(Vector2(-rx + lip + cos(a3) * lip, cy + sin(a3) * lip))
	return pts


func _face(c: Vector2, s: float) -> void:
	# Kedip singkat tiap beberapa detik (mata jadi garis lengkung).
	var blink: bool = fmod(_t, 4.2) > 4.05
	for side: float in [-1.0, 1.0]:
		var e: Vector2 = c + Vector2(0.125 * side, 0.135) * s
		if blink:
			draw_arc(e + Vector2(0.0, 0.01 * s), 0.034 * s, PI * 1.1, PI * 1.9, 10, INK, 0.022 * s, true)
		else:
			ProceduralUIFactory.fill_aa(self, _ellipse(e, Vector2(0.036, 0.046) * s, 16), INK)
			draw_circle(e + Vector2(-0.012, -0.016) * s, 0.013 * s, STEAM, true, -1.0, true)
		ProceduralUIFactory.fill_aa(self, _ellipse(c + Vector2(0.245 * side, 0.19) * s, Vector2(0.052, 0.032) * s, 14), BLUSH)
	# Mulut terbuka kecil: setengah lingkaran tinta dengan lidah merah muda.
	var m: Vector2 = c + Vector2(0.0, 0.172) * s
	var mouth := PackedVector2Array()
	for i in 13:
		var a: float = PI * float(i) / 12.0
		mouth.append(m + Vector2(cos(a) * 0.052, sin(a) * 0.05) * s)
	ProceduralUIFactory.fill_aa(self, mouth, INK)
	ProceduralUIFactory.fill_aa(self, _ellipse(m + Vector2(0.0, 0.032) * s, Vector2(0.026, 0.014) * s, 12), BLUSH)


## Tiga garis uap bergelombang yang naik pelan di atas kubah.
func _steam(c: Vector2, s: float) -> void:
	for i in 3:
		var x: float = (float(i) - 1.0) * 0.15
		var phase: float = _t * 2.2 + float(i) * 2.1
		var pts := PackedVector2Array()
		for k in 9:
			var f: float = float(k) / 8.0
			var y: float = -0.36 - f * 0.17 - (0.02 if i == 1 else 0.0)
			pts.append(c + Vector2(x + sin(f * TAU * 0.9 + phase) * 0.022, y) * s)
		draw_polyline(pts, STEAM, 0.04 * s, true)
		draw_circle(pts[0], 0.02 * s, STEAM, true, -1.0, true)
		draw_circle(pts[pts.size() - 1], 0.02 * s, STEAM, true, -1.0, true)


## Kilau bintang empat sudut yang membesar-mengecil pelan.
func _sparkle(p: Vector2, r: float, phase: float) -> void:
	var k: float = 0.75 + 0.25 * sin(_t * 2.4 + phase)
	var rr: float = r * k
	var w: float = rr * 0.32
	var pts := PackedVector2Array([p + Vector2(0.0, -rr), p + Vector2(w, -w), p + Vector2(rr, 0.0), p + Vector2(w, w),
		p + Vector2(0.0, rr), p + Vector2(-w, w), p + Vector2(-rr, 0.0), p + Vector2(-w, -w)])
	ProceduralUIFactory.fill_aa(self, pts, Palette.HONEY)


func _stroke(c: Vector2, s: float, a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(c + a * s, c + b * s, col, w * s, true)
	draw_circle(c + a * s, w * s * 0.5, col, true, -1.0, true)
	draw_circle(c + b * s, w * s * 0.5, col, true, -1.0, true)


static func _offset(pts: PackedVector2Array, c: Vector2, s: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	out.resize(pts.size())
	for i in pts.size():
		out[i] = c + pts[i] * s
	return out


static func _ellipse(p: Vector2, r: Vector2, n: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(p + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out
