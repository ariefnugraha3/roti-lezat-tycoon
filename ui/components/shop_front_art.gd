class_name ShopFrontArt
extends Control
## Gambar toko di kartu profil save (v3.1 89.3; GDD idle 15.3): etalase toko
## roti kecil dengan papan nama, kanopi bergaris berenda, jendela berisi roti
## di rak, pintu kayu, dan pot tanaman, di atas ubin langit. Warna kanopi,
## dinding, dan hiasan atap mengikuti tier lokasi save (1-5); tier 0 = profil
## kosong: siluet toko krem dengan lencana "+". Flat (v3.1 130.6): bidang warna
## polos tanpa garis tepi, bayangan, atau gradasi.

## Tier lokasi (1-5), atau 0 untuk profil kosong.
var tier: int = 1:
	set(value):
		tier = clampi(value, 0, 5)
		queue_redraw()

## Per tier: [kanopi, dinding, papan nama].
const LOOKS: Array = [
	[Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0), Color(0.0, 0.0, 0.0)],
	[Palette.HONEY, Palette.HOUSE_CREAM, Palette.CARAMEL],
	[Palette.STRAWBERRY, Palette.RUKO_SAND, Palette.CARAMEL],
	[Palette.MATCHA, Palette.HOUSE_PEACH, Palette.DOOR_WOOD],
	[Palette.SIGN_BLUE, Palette.COLONIAL_WHITE, Palette.APRON_NAVY],
	[Palette.APRON_MAROON, Palette.FLOUR_WHITE, Palette.APRON_MAROON],
]

var _o: Vector2 = Vector2.ZERO
var _s: float = 1.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(96.0, 96.0)
	resized.connect(queue_redraw)


func _draw() -> void:
	_s = minf(size.x, size.y)
	if _s < 24.0:
		return
	_o = (size - Vector2(_s, _s)) * 0.5
	if tier == 0:
		_empty()
		return
	var look: Array = LOOKS[tier]
	var awning: Color = look[0]
	var wall: Color = look[1]
	var board: Color = look[2]
	# Ubin langit dan trotoar.
	_rbox(0.0, 0.0, 1.0, 1.0, 0.22, Color(0.882, 0.929, 0.957))
	_rbox(0.0, 0.84, 1.0, 0.16, 0.0, Palette.PAVING, true)
	# Hiasan atap toko besar: segitiga (tier 4) atau kubah berbintang (tier 5).
	if tier == 4:
		_poly([Vector2(0.30, 0.20), Vector2(0.50, 0.08), Vector2(0.70, 0.20)], Palette.BRASS)
	elif tier == 5:
		_oval(0.50, 0.19, 0.17, 0.12, Palette.BRASS)
		_star(0.50, 0.06, 0.05, Palette.GOLD_STAR)
	# Dinding dan lis atap.
	_rbox(0.16, 0.26, 0.68, 0.62, 0.03, wall)
	_rbox(0.12, 0.22, 0.76, 0.08, 0.03, board.darkened(0.15))
	# Papan nama dengan roti kecil.
	_rbox(0.30, 0.13, 0.40, 0.13, 0.04, board)
	_loaf(0.50, 0.195, 0.07, Palette.FLOUR_WHITE, board)
	# Kanopi bergaris dengan renda bulat di bawahnya.
	var n: int = 7
	var w: float = 0.80 / float(n)
	for i in n:
		var col: Color = awning if i % 2 == 0 else Palette.FLOUR_WHITE
		_rbox(0.10 + w * float(i), 0.33, w + 0.002, 0.11, 0.0, col)
		_oval(0.10 + w * (float(i) + 0.5), 0.44, w * 0.5, w * 0.42, col)
	# Jendela pajang: rak kayu dengan tiga roti.
	_rbox(0.21, 0.53, 0.34, 0.26, 0.03, Palette.WINDOW_GLASS.lightened(0.45))
	_rbox(0.21, 0.70, 0.34, 0.03, 0.0, Palette.PINE_WOOD)
	_loaf(0.28, 0.665, 0.055, Palette.GOLDEN_CRUST, Palette.CARAMEL)
	_loaf(0.38, 0.655, 0.065, Palette.CUSTARD.darkened(0.08), Palette.GOLDEN_CRUST)
	_loaf(0.48, 0.665, 0.055, Palette.GOLDEN_CRUST, Palette.CARAMEL)
	_rbox(0.21, 0.755, 0.34, 0.035, 0.0, wall.darkened(0.10))
	# Pintu kayu berjendela bulat dan bergagang emas.
	_rbox(0.60, 0.53, 0.18, 0.31, 0.04, Palette.DOOR_WOOD)
	_oval(0.69, 0.61, 0.05, 0.05, Palette.WINDOW_GLASS.lightened(0.45))
	_oval(0.75, 0.70, 0.016, 0.016, Palette.GOLD_STAR)
	# Pot tanaman di kiri pintu.
	_oval(0.13, 0.76, 0.07, 0.07, Palette.LEAF)
	_oval(0.09, 0.73, 0.04, 0.04, Palette.LEAF_DEEP)
	_poly([Vector2(0.07, 0.79), Vector2(0.19, 0.79), Vector2(0.17, 0.88), Vector2(0.09, 0.88)], Palette.TERRACOTTA)


## Profil kosong: siluet toko krem dan lencana "+" madu.
func _empty() -> void:
	var ghost: Color = Palette.UI_CREAM_DEEP
	var deep: Color = Palette.CREAM_LIP
	_rbox(0.0, 0.0, 1.0, 1.0, 0.22, ghost.lightened(0.25))
	_rbox(0.16, 0.26, 0.68, 0.62, 0.03, ghost)
	_rbox(0.12, 0.22, 0.76, 0.08, 0.03, deep)
	_rbox(0.30, 0.13, 0.40, 0.13, 0.04, deep)
	var n: int = 7
	var w: float = 0.80 / float(n)
	for i in n:
		var col: Color = deep if i % 2 == 0 else ghost.lightened(0.15)
		_rbox(0.10 + w * float(i), 0.33, w + 0.002, 0.11, 0.0, col)
		_oval(0.10 + w * (float(i) + 0.5), 0.44, w * 0.5, w * 0.42, col)
	_rbox(0.21, 0.53, 0.34, 0.26, 0.03, ghost.lightened(0.2))
	_rbox(0.60, 0.53, 0.18, 0.31, 0.04, deep)
	_oval(0.80, 0.80, 0.15, 0.15, Palette.HONEY)
	_rbox(0.735, 0.785, 0.13, 0.03, 0.012, Palette.FLOUR_WHITE)
	_rbox(0.785, 0.735, 0.03, 0.13, 0.012, Palette.FLOUR_WHITE)


# --- alat gambar (koordinat satuan 0..1 di dalam kotak persegi) ---------------

func _p(x: float, y: float) -> Vector2:
	return _o + Vector2(x, y) * _s


func _rbox(x: float, y: float, w: float, h: float, r: float, col: Color, bottom_only: bool = false) -> void:
	var rect := Rect2(_p(x, y), Vector2(w, h) * _s)
	if bottom_only:
		# Bidang bawah ubin: sudut bawah ikut membulat seperti ubinnya.
		var pts: PackedVector2Array = ProceduralUIFactory.rounded_points(Rect2(_p(0.0, 0.0), Vector2(_s, _s)), 0.22 * _s, 6)
		var clip := PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])
		for piece: PackedVector2Array in Geometry2D.intersect_polygons(pts, clip):
			ProceduralUIFactory.fill_aa(self, piece, col)
		return
	ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(rect, r * _s, 4), col)


func _oval(x: float, y: float, rx: float, ry: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 24:
		var a: float = TAU * float(i) / 24.0
		pts.append(_p(x + cos(a) * rx, y + sin(a) * ry))
	ProceduralUIFactory.fill_aa(self, pts, col)


func _poly(unit: Array, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for v: Vector2 in unit:
		pts.append(_p(v.x, v.y))
	ProceduralUIFactory.fill_aa(self, pts, col)


func _star(x: float, y: float, r: float, col: Color) -> void:
	var pts: PackedVector2Array = PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + PI * float(i) / 5.0
		var rr: float = r if i % 2 == 0 else r * 0.45
		pts.append(_p(x + cos(a) * rr, y + sin(a) * rr))
	ProceduralUIFactory.fill_aa(self, pts, col)


## Roti tawar kecil: bagian atas membulat di atas alas, dua guratan.
func _loaf(x: float, y: float, r: float, col: Color, ink: Color) -> void:
	_oval(x, y - r * 0.15, r, r * 0.80, col)
	_rbox(x - r, y - r * 0.15, r * 2.0, r * 0.95, r * 0.25, col)
	for k: float in [-0.35, 0.35]:
		draw_line(_p(x + r * k - r * 0.10, y - r * 0.35), _p(x + r * k + r * 0.10, y + r * 0.05), ink,
			maxf(1.0, r * _s * 0.18), true)
