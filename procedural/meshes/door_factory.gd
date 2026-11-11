class_name DoorFactory
extends RefCounted
## Pintu masuk toko (GDD 32.3, idle 22.8): kusen, keset, dan hiasan di sekitar
## pintu, satu gaya per tier lokasi (makin tinggi makin mewah) atau satu tema
## skin pintu dari Store. 100% prosedural dari bentuk dasar MeshBuilder (GDD 4,
## 111): satu mesh matte, satu satin, dan satu mesh bercahaya (lampu, bintang)
## dengan material bola lampu yang sama, jadi tidak ada shader baru.
##
## Titik asal: tengah ambang pintu di garis dinding depan, lantai y = 0; muka
## menghadap jalan (-Z), bagian dalam toko di +Z. `w` = jarak pusat kedua tiang.
## Semua bagian di atas tiang setinggi paling banyak MAX_H, di bawah papan nama
## (RoomFactory.make_sign di y 1,05, tepi bawah 0,91), supaya dari kamera
## gameplay papan nama dan isi toko tidak pernah tertutup.

const MAX_H: float = 0.88
const POST: float = 0.08
## Keset di dalam pintu (z lokal) dan ukurannya.
const MAT_Z: float = 0.27
const MAT_D: float = 0.4

## Tema skin pintu (visual_profile_id dekorasi `skin_target` door).
const THEMES: Array[StringName] = [&"door_kitty", &"door_puppy", &"door_garden", &"door_galaxy", &"door_candy", &"door_ocean"]

const NAVY: Color = Color(0.13, 0.15, 0.33)
const NIGHT: Color = Color(0.22, 0.17, 0.42)
const STAR: Color = Color(1.0, 0.92, 0.6)
const GOLD: Color = Color(0.96, 0.76, 0.22)
const MARBLE: Color = Color(0.95, 0.94, 0.9)
const LEAF: Color = Color(0.42, 0.66, 0.40)
const LEAF_DARK: Color = Color(0.28, 0.52, 0.30)
const AQUA: Color = Color(0.45, 0.78, 0.82)
const SAND: Color = Color(0.93, 0.84, 0.64)
## Pangkal lengkung daun Blossom Arch (puncaknya tetap di bawah MAX_H).
const ARCH_Y: float = 0.56


## Pintu gaya `tier` (1-5) atau tema `theme` (&"" = gaya tier) selebar `w` meter.
static func build(tier: int, theme: StringName, w: float, frame: Color = Palette.CARAMEL) -> Node3D:
	# Bukan "Door": nama itu milik pintu oven yang bergerak (MeshBake.KEEP_NAMES).
	var k := DecorFactory.Kit.new("Entrance")
	var g := MeshBuilder.new()
	var ww: float = maxf(w, 0.6)
	match theme:
		&"door_kitty":
			_kitty(k, ww)
		&"door_puppy":
			_puppy(k, ww)
		&"door_garden":
			_garden(k, ww)
		&"door_galaxy":
			_galaxy(k, g, ww)
		&"door_candy":
			_candy(k, ww)
		&"door_ocean":
			_ocean(k, ww)
		_:
			match clampi(tier, 1, 5):
				2:
					_shophouse(k, ww, frame)
				3:
					_bakery(k, g, ww, frame)
				4:
					_flagship(k, g, ww, frame)
				5:
					_heritage(k, g, ww, frame)
				_:
					_garage(k, ww, frame)
	var root: Node3D = k.done()
	if not g.is_empty():
		var mi: MeshInstance3D = g.commit("Glow")
		# Material sendiri: material MeshBuilder dipakai bersama semua model.
		mi.material_override = ProceduralMeshFactory.material(Color.WHITE)
		EquipmentFactory._set_glow(mi, STAR if theme == &"door_galaxy" else Palette.WARMER_LAMP, 0.9)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.set_meta("door_style", String(theme) if theme != &"" else "tier_%d" % clampi(tier, 1, 5))
	return root


# ===========================================================================
# BAGIAN BERSAMA
# ===========================================================================

static func _xf(p: Vector3, r: Vector3 = Vector3.ZERO, s: Vector3 = Vector3.ONE) -> Transform3D:
	return DecorFactory._xf(p, r, s)


## Dua tiang persegi setinggi `h`.
static func _posts(mb: MeshBuilder, w: float, h: float, col: Color, thick: float = POST) -> void:
	for s: float in [-1.0, 1.0]:
		mb.box(_xf(Vector3(s * w * 0.5, h * 0.5, 0.0)), Vector3(thick, h, thick + 0.01), col)


## Balok ambang di atas tiang, tepi atasnya di `top`.
static func _lintel(mb: MeshBuilder, w: float, top: float, col: Color, th: float = 0.07, extra: float = 0.12) -> void:
	mb.box(_xf(Vector3(0.0, top - th * 0.5, 0.0)), Vector3(w + extra, th, POST + 0.03), col)


## Keset di dalam pintu: dasar, lis, dan pola `pattern`.
static func _mat(mb: MeshBuilder, w: float, base: Color, trim: Color, pattern: StringName = &"plain", accent: Color = Color.WHITE) -> void:
	var mw: float = w - 0.08
	mb.box(_xf(Vector3(0.0, 0.004, MAT_Z)), Vector3(mw, 0.008, MAT_D), base)
	_frame_at(mb, Vector3(0.0, 0.0085, MAT_Z), mw, MAT_D, 0.03, trim)
	match pattern:
		&"stripes":
			var n: int = 5
			for i in n:
				var x: float = -mw * 0.5 + (float(i) + 0.5) * mw / float(n)
				if i % 2 == 0:
					mb.box(_xf(Vector3(x, 0.0088, MAT_Z)), Vector3(mw / float(n) * 0.8, 0.001, MAT_D - 0.08), accent)
		&"paws":
			for i in 3:
				var c := Vector3((float(i) - 1.0) * mw * 0.3, 0.009, MAT_Z + (0.06 if i % 2 == 0 else -0.06))
				mb.polygon(DecorFactory._flat(c), DecorFactory._oval_pts(0.035, 0.03, 12), accent, Vector3.BACK)
				for t in 3:
					var a: float = deg_to_rad(-40.0 + 40.0 * float(t))
					mb.polygon(DecorFactory._flat(c + Vector3(sin(a) * 0.05, 0.0, -cos(a) * 0.05)), DecorFactory._oval_pts(0.014, 0.016, 8), accent, Vector3.BACK)
		&"dots":
			for i in 9:
				var x2: float = (float(i % 3) - 1.0) * mw * 0.3 + (0.02 if i % 2 == 0 else -0.02)
				var z2: float = MAT_Z + (float(i / 3) - 1.0) * MAT_D * 0.27
				mb.polygon(DecorFactory._flat(Vector3(x2, 0.009, z2)), DecorFactory._oval_pts(0.014, 0.014, 8), accent, Vector3.BACK)
		&"diamond":
			mb.polygon(DecorFactory._flat(Vector3(0.0, 0.009, MAT_Z)), DecorFactory._diamond_pts(MAT_D * 0.3), accent, Vector3.BACK)


## Bingkai datar selebar `b` di sekeliling persegi `sx` x `sz` berpusat di `c`.
static func _frame_at(mb: MeshBuilder, c: Vector3, sx: float, sz: float, b: float, color: Color) -> void:
	for s: float in [-1.0, 1.0]:
		mb.polygon(DecorFactory._flat(c + Vector3(0.0, 0.0, s * (sz - b) * 0.5)), DecorFactory._rect_pts(sx, b), color, Vector3.BACK)
		mb.polygon(DecorFactory._flat(c + Vector3(s * (sx - b) * 0.5, 0.0, 0.0)), DecorFactory._rect_pts(b, sz - b * 2.0), color, Vector3.BACK)


## Pot bundar dengan bola daun (tanaman di samping pintu).
static func _potted_ball(k: DecorFactory.Kit, c: Vector3, pot: Color, leaf: Color, s: float = 1.0) -> void:
	k.m.cylinder(_xf(c + Vector3(0.0, 0.07 * s, 0.0)), 0.14 * s, 0.075 * s, 0.06 * s, pot, 14)
	k.m.torus(_xf(c + Vector3(0.0, 0.14 * s, 0.0)), 0.075 * s, 0.01 * s, pot.darkened(0.12), 14, 4)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.24 * s, 0.0)), Vector3(0.11, 0.11, 0.11) * s, leaf, 14, 8)
	k.m.ellipsoid(_xf(c + Vector3(-0.04, 0.27 * s, -0.05)), Vector3(0.05, 0.05, 0.05) * s, leaf.lightened(0.15), 10, 6)


## Lampu kecil bercahaya: braket di tiang dan bohlam di `g`.
static func _sconce(k: DecorFactory.Kit, g: MeshBuilder, c: Vector3, metal: Color, side: float) -> void:
	k.s.box(_xf(c + Vector3(-side * 0.04, 0.0, 0.0)), Vector3(0.08, 0.015, 0.015), metal)
	k.s.cylinder(_xf(c + Vector3(0.0, 0.035, 0.0)), 0.012, 0.035, 0.03, metal, 10)
	g.ellipsoid(_xf(c + Vector3(0.0, -0.005, 0.0)), Vector3(0.028, 0.034, 0.028), Palette.WARMER_LAMP.lightened(0.3), 10, 6)


## Titik bintang lima.
static func _star_pts(outer: float, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + float(i) * TAU / 10.0
		var r: float = outer if i % 2 == 0 else inner
		pts.append(Vector2(cos(a), sin(a)) * r)
	return pts


## Poligon di muka depan (bidang XY, menghadap -Z) pada titik `c`.
static func _front(c: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI), c)


# ===========================================================================
# GAYA PER TIER (GDD 32.3)
# ===========================================================================

## Tier 1, garasi: tiang kayu polos, ambang tipis, keset gingham.
static func _garage(k: DecorFactory.Kit, w: float, frame: Color) -> void:
	_posts(k.m, w, 0.84, frame, 0.07)
	_lintel(k.m, w, 0.86, frame.darkened(0.08), 0.05, 0.08)
	_mat(k.m, w, Palette.GINGHAM_A, Palette.GINGHAM_A.darkened(0.15), &"stripes", Palette.FLOUR_WHITE)


## Tier 2, ruko: kusen bercat dengan alas, jendela atas berkisi, dua pot
## tanaman, keset bergaris mint.
static func _shophouse(k: DecorFactory.Kit, w: float, frame: Color) -> void:
	_posts(k.m, w, 0.86, frame)
	for s: float in [-1.0, 1.0]:
		k.m.box(_xf(Vector3(s * w * 0.5, 0.05, 0.0)), Vector3(0.11, 0.1, 0.12), frame.darkened(0.12))
	_lintel(k.m, w, 0.88, frame.darkened(0.06), 0.05)
	k.m.box(_xf(Vector3(0.0, 0.76, 0.0)), Vector3(w - POST, 0.14, 0.02), Palette.HOUSE_SKY.lightened(0.15))
	for i in 3:
		k.m.box(_xf(Vector3((float(i) - 1.0) * (w - POST) / 3.0, 0.76, -0.012)), Vector3(0.016, 0.14, 0.01), frame)
	k.m.box(_xf(Vector3(0.0, 0.69, -0.005)), Vector3(w - POST, 0.02, 0.04), frame)
	for s2: float in [-1.0, 1.0]:
		_potted_ball(k, Vector3(s2 * (w * 0.5 + 0.18), 0.0, -0.17), Palette.TERRACOTTA, LEAF)
	_mat(k.m, w, Palette.PASTEL_MINT.darkened(0.1), Palette.PASTEL_MINT.darkened(0.3), &"stripes", Palette.FLOUR_WHITE)


## Tier 3, bakery mandiri: kusen kayu tua berkepala dan beralas, deretan gigi
## di ambang, gagang kuningan, dua lampu dinding, keset sabut.
static func _bakery(k: DecorFactory.Kit, g: MeshBuilder, w: float, frame: Color) -> void:
	_posts(k.m, w, 0.84, frame, 0.09)
	for s: float in [-1.0, 1.0]:
		var x: float = s * w * 0.5
		k.m.box(_xf(Vector3(x, 0.04, 0.0)), Vector3(0.13, 0.08, 0.13), frame.darkened(0.15))
		k.m.box(_xf(Vector3(x, 0.8, 0.0)), Vector3(0.13, 0.05, 0.13), frame.lightened(0.08))
		k.s.cylinder(_xf(Vector3(x - s * 0.055, 0.45, -0.03), Vector3(0.0, 0.0, 90.0)), 0.03, 0.009, 0.009, Palette.BRASS, 8)
		_sconce(k, g, Vector3(x + s * 0.1, 0.66, -0.04), Palette.BRASS, s)
	_lintel(k.m, w, 0.88, frame, 0.06, 0.18)
	var n: int = int((w + 0.1) / 0.06)
	for i in n:
		k.m.box(_xf(Vector3(-(w + 0.1) * 0.5 + (float(i) + 0.5) * (w + 0.1) / float(n), 0.81, -0.06)), Vector3(0.025, 0.025, 0.02), frame.lightened(0.15))
	for s2: float in [-1.0, 1.0]:
		_barrel_tree(k, Vector3(s2 * (w * 0.5 + 0.22), 0.0, -0.18), frame)
	_mat(k.m, w, Palette.CARAMEL.lightened(0.15), Palette.DARK_CHOCOLATE, &"diamond", Palette.CARAMEL.darkened(0.1))


## Tier 4, flagship: pilar marmer bercincin kuningan, ambang berlis kuningan,
## dua lentera, karpet merah dengan batang kuningan, dua topiari bola.
static func _flagship(k: DecorFactory.Kit, g: MeshBuilder, w: float, _frame: Color) -> void:
	for s: float in [-1.0, 1.0]:
		var x: float = s * w * 0.5
		k.m.box(_xf(Vector3(x, 0.035, 0.0)), Vector3(0.14, 0.07, 0.14), MARBLE.darkened(0.06))
		k.m.cylinder(_xf(Vector3(x, 0.43, 0.0)), 0.72, 0.048, 0.054, MARBLE, 16)
		for y: float in [0.09, 0.78]:
			k.s.torus(_xf(Vector3(x, y, 0.0)), 0.056, 0.01, Palette.BRASS, 16, 4)
		k.m.box(_xf(Vector3(x, 0.81, 0.0)), Vector3(0.14, 0.04, 0.14), MARBLE.darkened(0.03))
		# Lentera kuningan di samping pilar.
		var lx: float = x + s * 0.13
		k.s.box(_xf(Vector3(x + s * 0.07, 0.62, -0.02)), Vector3(0.07, 0.012, 0.012), Palette.BRASS)
		k.s.box(_xf(Vector3(lx, 0.68, -0.02)), Vector3(0.07, 0.012, 0.07), Palette.BRASS)
		k.s.box(_xf(Vector3(lx, 0.56, -0.02)), Vector3(0.06, 0.012, 0.06), Palette.BRASS)
		k.s.cylinder(_xf(Vector3(lx, 0.71, -0.02)), 0.04, 0.0, 0.045, Palette.BRASS, 4)
		g.box(_xf(Vector3(lx, 0.62, -0.02)), Vector3(0.045, 0.1, 0.045), Palette.WARMER_LAMP.lightened(0.3))
		_topiary(k, Vector3(s * (w * 0.5 + 0.3), 0.0, -0.22), Palette.BRASS, false)
	_lintel(k.m, w, 0.88, MARBLE.darkened(0.02), 0.07, 0.2)
	k.s.box(_xf(Vector3(0.0, 0.83, -0.055)), Vector3(w + 0.2, 0.014, 0.01), Palette.BRASS)
	# Karpet merah dari pintu ke trotoar.
	var cw: float = minf(w - 0.2, 0.62)
	k.m.box(_xf(Vector3(0.0, 0.005, -0.32)), Vector3(cw, 0.01, 0.56), Palette.STRAWBERRY_DEEP)
	for z: float in [-0.12, -0.32, -0.52]:
		k.s.cylinder(_xf(Vector3(0.0, 0.014, z), Vector3(0.0, 0.0, 90.0)), cw + 0.04, 0.008, 0.008, Palette.BRASS, 8)
	_mat(k.m, w, Palette.STRAWBERRY_DEEP, Palette.BRASS, &"diamond", Palette.BRASS)


## Tier 5, landmark heritage: pilar beralur berkepala emas, ambang hijau
## kolonial berbatu kunci emas, lentera berhias, tiang tali beludru, guci
## topiari kerucut, karpet merah berlis emas.
static func _heritage(k: DecorFactory.Kit, g: MeshBuilder, w: float, frame: Color) -> void:
	for s: float in [-1.0, 1.0]:
		var x: float = s * w * 0.5
		k.m.box(_xf(Vector3(x, 0.04, 0.0)), Vector3(0.16, 0.08, 0.16), Palette.COLONIAL_WHITE.darkened(0.08))
		k.m.cylinder(_xf(Vector3(x, 0.44, 0.0)), 0.72, 0.052, 0.058, Palette.COLONIAL_WHITE, 18)
		for r in 8:
			var a: float = TAU * float(r) / 8.0
			k.m.box(_xf(Vector3(x + cos(a) * 0.056, 0.44, sin(a) * 0.056), Vector3(0.0, -rad_to_deg(a), 0.0)), Vector3(0.008, 0.66, 0.012), Palette.COLONIAL_WHITE.darkened(0.06))
		k.s.cylinder(_xf(Vector3(x, 0.1, 0.0)), 0.025, 0.07, 0.07, GOLD, 16)
		k.s.cylinder(_xf(Vector3(x, 0.8, 0.0)), 0.03, 0.075, 0.06, GOLD, 16)
		k.s.torus(_xf(Vector3(x, 0.78, 0.0)), 0.062, 0.01, GOLD, 16, 4)
		# Lentera berhias: tudung kerucut emas dan cahaya di dalam kaca.
		var lx: float = x + s * 0.15
		k.s.box(_xf(Vector3(x + s * 0.08, 0.6, -0.02)), Vector3(0.08, 0.014, 0.014), GOLD)
		k.s.cylinder(_xf(Vector3(lx, 0.69, -0.02)), 0.05, 0.0, 0.05, GOLD, 6)
		k.s.cylinder(_xf(Vector3(lx, 0.535, -0.02)), 0.02, 0.04, 0.03, GOLD, 6)
		for c in 3:
			var ca: float = TAU * float(c) / 3.0
			k.s.box(_xf(Vector3(lx + cos(ca) * 0.032, 0.6, -0.02 + sin(ca) * 0.032)), Vector3(0.008, 0.11, 0.008), GOLD)
		g.cylinder(_xf(Vector3(lx, 0.6, -0.02)), 0.1, 0.03, 0.03, Palette.WARMER_LAMP.lightened(0.3), 8)
		# Tiang tali beludru di kedua sisi karpet.
		var cx: float = s * 0.36
		for z: float in [-0.2, -0.62]:
			k.s.cylinder(_xf(Vector3(cx, 0.15, z)), 0.3, 0.012, 0.014, GOLD, 8)
			k.s.ellipsoid(_xf(Vector3(cx, 0.31, z)), Vector3(0.022, 0.022, 0.022), GOLD, 8, 5)
			k.s.disc(_xf(Vector3(cx, 0.004, z)), 0.04, GOLD, GOLD.darkened(0.1), 12)
		_rope(k.m, Vector3(cx, 0.28, -0.2), Vector3(cx, 0.28, -0.62), 0.07, Palette.STRAWBERRY_DEEP)
		_topiary(k, Vector3(s * (w * 0.5 + 0.34), 0.0, -0.22), GOLD, true)
	_lintel(k.m, w, 0.88, frame, 0.08, 0.24)
	k.s.box(_xf(Vector3(0.0, 0.825, -0.06)), Vector3(w + 0.24, 0.012, 0.01), GOLD)
	k.s.box(_xf(Vector3(0.0, 0.89, -0.03)), Vector3(w + 0.26, 0.018, 0.12), GOLD)
	var key := PackedVector2Array([Vector2(-0.05, 0.05), Vector2(0.05, 0.05), Vector2(0.035, -0.04), Vector2(-0.035, -0.04)])
	k.s.polygon(_front(Vector3(0.0, 0.84, -0.07)), key, GOLD, Vector3.BACK)
	# Karpet merah berlis emas.
	var cw: float = 0.6
	k.m.box(_xf(Vector3(0.0, 0.005, -0.4)), Vector3(cw, 0.01, 0.72), Palette.STRAWBERRY_DEEP)
	for s3: float in [-1.0, 1.0]:
		k.s.box(_xf(Vector3(s3 * (cw * 0.5 - 0.025), 0.011, -0.4)), Vector3(0.02, 0.002, 0.72), GOLD)
	_mat(k.m, w, Palette.COLONIAL_GREEN, GOLD, &"diamond", GOLD)


## Topiari di pot: bola (`cone` false) atau kerucut, pot `pot`.
static func _topiary(k: DecorFactory.Kit, c: Vector3, pot: Color, cone: bool) -> void:
	var urn := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.06, 0.0), Vector2(0.05, 0.03), Vector2(0.075, 0.12), Vector2(0.085, 0.16), Vector2(0.0, 0.16)])
	k.s.lathe(_xf(c), urn, pot, 14)
	k.m.cylinder(_xf(c + Vector3(0.0, 0.2, 0.0)), 0.08, 0.012, 0.012, Palette.DARK_CHOCOLATE, 6)
	if cone:
		k.m.cylinder(_xf(c + Vector3(0.0, 0.36, 0.0)), 0.36, 0.0, 0.1, LEAF_DARK, 14)
	else:
		k.m.ellipsoid(_xf(c + Vector3(0.0, 0.32, 0.0)), Vector3(0.11, 0.11, 0.11), LEAF, 14, 8)


# ===========================================================================
# TEMA SKIN PINTU (GDD idle 22.8)
# ===========================================================================

## Kucing: kusen merah muda, kepala kucing di ambang (telinga, mata, hidung,
## kumis), ekor melingkar di satu tiang, keset bercap kaki.
static func _kitty(k: DecorFactory.Kit, w: float) -> void:
	var pink: Color = Color(0.98, 0.76, 0.82)
	_posts(k.m, w, 0.7, pink, 0.09)
	for s: float in [-1.0, 1.0]:
		k.m.ellipsoid(_xf(Vector3(s * w * 0.5, 0.04, -0.01)), Vector3(0.07, 0.04, 0.08), Palette.FLOUR_WHITE, 12, 6)
	# Kepala: papan membulat lebar, dua telinga segitiga dengan bagian dalam.
	DecorFactory._rounded_board(k.m, Vector3(0.0, 0.76, 0.0), Vector2(w + 0.14, 0.17), 0.09, 0.07, pink)
	for s2: float in [-1.0, 1.0]:
		var ex: float = s2 * (w * 0.5 - 0.06)
		k.m.cylinder(_xf(Vector3(ex, 0.86, 0.0)), 0.08, 0.0, 0.07, pink, 4)
		k.m.cylinder(_xf(Vector3(ex, 0.855, -0.02)), 0.05, 0.0, 0.04, Palette.STRAWBERRY, 4)
		k.m.ellipsoid(_xf(Vector3(s2 * 0.12, 0.775, -0.05)), Vector3(0.022, 0.03, 0.01), Palette.DARK_CHOCOLATE, 10, 5)
		k.m.ellipsoid(_xf(Vector3(s2 * 0.115, 0.787, -0.058)), Vector3(0.007, 0.008, 0.004), Palette.FLOUR_WHITE, 6, 3)
		for t in 2:
			k.m.box(_xf(Vector3(s2 * 0.2, 0.745 + 0.016 * float(t), -0.05), Vector3(0.0, 0.0, s2 * (8.0 - 16.0 * float(t)))), Vector3(0.1, 0.005, 0.005), Palette.DARK_CHOCOLATE)
	k.m.polygon(_front(Vector3(0.0, 0.752, -0.048)), PackedVector2Array([Vector2(-0.02, 0.012), Vector2(0.02, 0.012), Vector2(0.0, -0.012)]), Palette.STRAWBERRY_DEEP, Vector3.BACK)
	# Ekor melingkar dari tiang kanan (kanan penonton = -X).
	k.m.torus(_xf(Vector3(-w * 0.5 - 0.09, 0.42, 0.0), Vector3(90.0, 0.0, 0.0)), 0.08, 0.02, pink.darkened(0.08), 16, 6, -PI * 0.2, PI * 1.3)
	_cat(k, Vector3(w * 0.5 + 0.22, 0.0, -0.16))
	_mat(k.m, w, pink.lightened(0.2), pink.darkened(0.2), &"paws", Palette.STRAWBERRY)


## Anjing: kusen karamel, kepala anak anjing di ambang dengan telinga terkulai,
## moncong putih, hidung hitam, tulang di atasnya, keset biru bercap kaki.
static func _puppy(k: DecorFactory.Kit, w: float) -> void:
	var fur: Color = Color(0.84, 0.62, 0.38)
	var ear: Color = Color(0.55, 0.36, 0.22)
	_posts(k.m, w, 0.7, fur, 0.09)
	DecorFactory._rounded_board(k.m, Vector3(0.0, 0.76, 0.0), Vector2(w + 0.1, 0.17), 0.09, 0.07, fur)
	for s: float in [-1.0, 1.0]:
		k.m.ellipsoid(_xf(Vector3(s * (w * 0.5 + 0.06), 0.7, -0.01), Vector3(0.0, 0.0, s * 18.0)), Vector3(0.05, 0.12, 0.04), ear, 12, 8)
		k.m.ellipsoid(_xf(Vector3(s * 0.12, 0.79, -0.05)), Vector3(0.022, 0.026, 0.01), Palette.DARK_CHOCOLATE, 10, 5)
		k.m.ellipsoid(_xf(Vector3(s * 0.115, 0.8, -0.058)), Vector3(0.007, 0.008, 0.004), Palette.FLOUR_WHITE, 6, 3)
	k.m.ellipsoid(_xf(Vector3(0.0, 0.74, -0.05)), Vector3(0.09, 0.045, 0.03), Palette.FLOUR_WHITE, 14, 6)
	k.s.ellipsoid(_xf(Vector3(0.0, 0.76, -0.075)), Vector3(0.03, 0.022, 0.02), Palette.DARK_CHOCOLATE, 10, 6)
	k.m.ellipsoid(_xf(Vector3(0.0, 0.715, -0.07)), Vector3(0.025, 0.012, 0.01), Palette.STRAWBERRY, 8, 4)
	# Tulang di atas kepala.
	k.m.box(_xf(Vector3(0.0, 0.865, 0.0)), Vector3(0.18, 0.03, 0.03), Palette.FLOUR_WHITE)
	for s2: float in [-1.0, 1.0]:
		for t: float in [-1.0, 1.0]:
			k.m.ellipsoid(_xf(Vector3(s2 * 0.095, 0.865 + t * 0.018, 0.0)), Vector3(0.024, 0.024, 0.024), Palette.FLOUR_WHITE, 10, 5)
	_dog(k, Vector3(-(w * 0.5 + 0.22), 0.0, -0.16), fur, ear)
	_mat(k.m, w, Palette.SIGN_BLUE.lightened(0.3), Palette.SIGN_BLUE, &"paws", Palette.FLOUR_WHITE)


## Taman bunga: tiang bersulur daun, lengkung daun berbunga di atas pintu, dua
## pot bunga, keset rumput berbunga.
static func _garden(k: DecorFactory.Kit, w: float) -> void:
	var trellis: Color = Palette.FLOUR_WHITE.darkened(0.04)
	_posts(k.m, w, ARCH_Y, trellis, 0.06)
	var flowers: Array[Color] = [Palette.STRAWBERRY, Palette.FLOUR_WHITE, Palette.BUTTER_YELLOW, Palette.PASTEL_STRAWBERRY]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for s: float in [-1.0, 1.0]:
		for i in 7:
			var y: float = 0.06 + float(i) * 0.078
			k.m.ellipsoid(_xf(Vector3(s * w * 0.5 + rng.randf_range(-0.04, 0.04), y, -0.03), Vector3(0.0, 0.0, rng.randf_range(-30.0, 30.0))),
				Vector3(0.04, 0.026, 0.02), LEAF if i % 2 == 0 else LEAF_DARK, 8, 5)
	# Lengkung pipih dari puncak tiang (tetap di bawah papan nama).
	var r: float = w * 0.5
	k.m.torus(_xf(Vector3(0.0, ARCH_Y, 0.0), Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.5)), r, 0.022, trellis, 24, 6, 0.0, PI)
	for i2 in 13:
		var a: float = PI * float(i2) / 12.0
		var p := Vector3(cos(a) * r, ARCH_Y + sin(a) * r * 0.5, -0.02)
		k.m.ellipsoid(_xf(p, Vector3(0.0, 0.0, rad_to_deg(a))), Vector3(0.05, 0.03, 0.03), LEAF if i2 % 2 == 0 else LEAF_DARK, 8, 5)
		if i2 % 2 == 1:
			k.m.ellipsoid(_xf(p + Vector3(0.0, 0.02, -0.025)), Vector3(0.022, 0.022, 0.014), flowers[i2 % flowers.size()], 8, 5)
			k.m.ellipsoid(_xf(p + Vector3(0.0, 0.02, -0.035)), Vector3(0.008, 0.008, 0.006), Palette.BUTTER_YELLOW, 6, 3)
	for s2: float in [-1.0, 1.0]:
		var c := Vector3(s2 * (w * 0.5 + 0.2), 0.0, -0.17)
		k.m.cylinder(_xf(c + Vector3(0.0, 0.06, 0.0)), 0.12, 0.08, 0.065, Palette.TERRACOTTA, 14)
		for f in 5:
			var fa: float = TAU * float(f) / 5.0
			k.m.ellipsoid(_xf(c + Vector3(cos(fa) * 0.045, 0.15, sin(fa) * 0.045)), Vector3(0.035, 0.03, 0.035), LEAF, 8, 5)
			k.m.ellipsoid(_xf(c + Vector3(cos(fa) * 0.04, 0.18, sin(fa) * 0.04)), Vector3(0.022, 0.018, 0.022), flowers[f % flowers.size()], 8, 5)
	_mat(k.m, w, LEAF.lightened(0.1), LEAF_DARK, &"dots", Palette.BUTTER_YELLOW)


## Galaksi: kusen biru malam bertabur bintang bercahaya, bulan sabit emas di
## ambang, planet bercincin di samping pintu, keset langit malam berbintang.
static func _galaxy(k: DecorFactory.Kit, g: MeshBuilder, w: float) -> void:
	_posts(k.m, w, 0.82, NAVY, 0.09)
	_lintel(k.m, w, 0.86, NIGHT, 0.09, 0.16)
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for s: float in [-1.0, 1.0]:
		for i in 6:
			g.ellipsoid(_xf(Vector3(s * w * 0.5 + rng.randf_range(-0.03, 0.03), 0.08 + float(i) * 0.12 + rng.randf_range(-0.03, 0.03), -0.052)),
				Vector3(0.01, 0.01, 0.006) * rng.randf_range(0.7, 1.3), STAR, 6, 3)
	for i2 in 7:
		g.ellipsoid(_xf(Vector3(-w * 0.5 + (float(i2) + 0.5) * w / 7.0, 0.815 + rng.randf_range(-0.02, 0.02), -0.065)), Vector3(0.009, 0.009, 0.005), STAR, 6, 3)
	# Bulan sabit di muka ambang.
	g.torus(_xf(Vector3(0.0, 0.815, -0.07), Vector3(90.0, 0.0, 0.0)), 0.035, 0.009, GOLD.lightened(0.2), 16, 5, PI * 0.15, PI * 1.25)
	g.polygon(_front(Vector3(0.12, 0.815, -0.068)), _star_pts(0.02, 0.009), STAR, Vector3.BACK)
	g.polygon(_front(Vector3(-0.12, 0.815, -0.068)), _star_pts(0.02, 0.009), STAR, Vector3.BACK)
	# Planet bercincin di alas berbintang, di samping kanan pintu.
	var pc := Vector3(-(w * 0.5 + 0.22), 0.0, -0.2)
	k.m.cylinder(_xf(pc + Vector3(0.0, 0.1, 0.0)), 0.2, 0.05, 0.07, NAVY, 12)
	k.s.ellipsoid(_xf(pc + Vector3(0.0, 0.3, 0.0)), Vector3(0.1, 0.1, 0.1), Palette.SIGN_PURPLE.lightened(0.15), 16, 10)
	k.s.ellipsoid(_xf(pc + Vector3(0.03, 0.33, -0.06)), Vector3(0.035, 0.02, 0.03), Palette.SIGN_PURPLE.lightened(0.4), 10, 5)
	k.s.torus(_xf(pc + Vector3(0.0, 0.3, 0.0), Vector3(20.0, 0.0, -15.0)), 0.15, 0.012, GOLD, 24, 4)
	_mat(k.m, w, NAVY, NIGHT.lightened(0.15), &"dots", STAR)


## Permen: tiang bergaris permen tongkat, ambang merah muda bertabur permen
## jeli, dua lolipop di samping pintu, keset merah muda bertabur meses.
static func _candy(k: DecorFactory.Kit, w: float) -> void:
	var gum: Array[Color] = [Palette.STRAWBERRY, Palette.MATCHA, Palette.SIGN_BLUE, Palette.BUTTER_YELLOW, Palette.SIGN_PURPLE]
	for s: float in [-1.0, 1.0]:
		var n: int = 11
		for i in n:
			k.s.cylinder(_xf(Vector3(s * w * 0.5, 0.04 + float(i) * 0.072, 0.0), Vector3(0.0, 0.0, 14.0 * s)), 0.072, 0.042, 0.042,
				Palette.STRAWBERRY if i % 2 == 0 else Palette.FLOUR_WHITE, 12)
	DecorFactory._rounded_board(k.m, Vector3(0.0, 0.83, 0.0), Vector2(w + 0.16, 0.1), 0.08, 0.04, Palette.PASTEL_STRAWBERRY)
	var m: int = int((w + 0.1) / 0.09)
	for j in m:
		var x: float = -(w + 0.1) * 0.5 + (float(j) + 0.5) * (w + 0.1) / float(m)
		k.s.ellipsoid(_xf(Vector3(x, 0.83, -0.045)), Vector3(0.025, 0.028, 0.012), gum[j % gum.size()], 10, 6)
	for s2: float in [-1.0, 1.0]:
		var c := Vector3(s2 * (w * 0.5 + 0.22), 0.0, -0.18)
		k.m.cylinder(_xf(c + Vector3(0.0, 0.25, 0.0)), 0.5, 0.012, 0.012, Palette.FLOUR_WHITE, 8)
		k.m.cylinder(_xf(c + Vector3(0.0, 0.03, 0.0)), 0.06, 0.05, 0.06, Palette.PASTEL_STRAWBERRY, 12)
		for r in 4:
			var col: Color = Palette.STRAWBERRY if r % 2 == 0 else Palette.FLOUR_WHITE
			k.s.cylinder(_xf(c + Vector3(0.0, 0.58, -0.002 * float(r)), Vector3(90.0, 0.0, 0.0)), 0.02, 0.11 - 0.025 * float(r), 0.11 - 0.025 * float(r), col, 20)
	_mat(k.m, w, Palette.PASTEL_STRAWBERRY, Palette.STRAWBERRY, &"dots", Palette.SIGN_BLUE.lightened(0.2))


## Pantai: tiang biru laut bercincin ombak putih, ambang berombak dengan
## kerang di tengah dan bintang laut, keset pasir.
static func _ocean(k: DecorFactory.Kit, w: float) -> void:
	_posts(k.m, w, 0.8, AQUA, 0.09)
	for s: float in [-1.0, 1.0]:
		for i in 4:
			k.m.box(_xf(Vector3(s * w * 0.5, 0.15 + float(i) * 0.18, 0.0)), Vector3(0.1, 0.02, 0.1), Palette.FLOUR_WHITE)
	_lintel(k.m, w, 0.82, AQUA.darkened(0.15), 0.06, 0.14)
	var n: int = int((w + 0.14) / 0.08)
	for j in n:
		var x: float = -(w + 0.14) * 0.5 + (float(j) + 0.5) * (w + 0.14) / float(n)
		k.m.ellipsoid(_xf(Vector3(x, 0.83, -0.01)), Vector3(0.042, 0.04, 0.05), AQUA.lightened(0.15) if j % 2 == 0 else Palette.FLOUR_WHITE, 10, 5)
	# Kerang kipas di tengah ambang.
	var shell := PackedVector2Array([Vector2(0.0, -0.035)])
	for i2 in 9:
		var a: float = PI * (0.15 + 0.7 * float(i2) / 8.0)
		shell.append(Vector2(cos(a), sin(a)) * (0.07 if i2 % 2 == 0 else 0.062))
	k.s.polygon(_front(Vector3(0.0, 0.8, -0.05)), shell, Palette.PASTEL_STRAWBERRY.lightened(0.15), Vector3.BACK)
	for s2: float in [-1.0, 1.0]:
		k.s.polygon(_front(Vector3(s2 * (w * 0.5 - 0.05), 0.45, -0.052)), _star_pts(0.04, 0.017), Palette.SIGN_ORANGE, Vector3.BACK)
	# Pelampung dan tali di samping pintu.
	var bc := Vector3(-(w * 0.5 + 0.17), 0.0, -0.12)
	k.m.cylinder(_xf(bc + Vector3(0.0, 0.25, 0.0)), 0.5, 0.02, 0.022, Palette.CARAMEL, 8)
	k.m.torus(_xf(bc + Vector3(0.0, 0.36, -0.03), Vector3(90.0, 0.0, 0.0)), 0.07, 0.022, Palette.STRAWBERRY, 18, 6)
	_sandcastle(k, Vector3(w * 0.5 + 0.22, 0.0, -0.16))
	_mat(k.m, w, SAND, SAND.darkened(0.2), &"dots", Palette.FLOUR_WHITE)


# ===========================================================================
# HIASAN SAMPING PINTU
# ===========================================================================

## Pohon kecil berbatang dalam tong kayu berikat besi (Tier 3).
static func _barrel_tree(k: DecorFactory.Kit, c: Vector3, wood: Color) -> void:
	k.m.cylinder(_xf(c + Vector3(0.0, 0.08, 0.0)), 0.16, 0.08, 0.07, wood.darkened(0.1), 14)
	for y: float in [0.04, 0.12]:
		k.s.torus(_xf(c + Vector3(0.0, y, 0.0)), 0.077, 0.006, Palette.DARK_CHOCOLATE, 14, 3)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.16, 0.0)), Vector3(0.068, 0.012, 0.068), Palette.DARK_CHOCOLATE.lightened(0.15), 12, 3)
	k.m.cylinder(_xf(c + Vector3(0.0, 0.26, 0.0)), 0.2, 0.01, 0.013, Palette.DARK_CHOCOLATE, 6)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.42, 0.0)), Vector3(0.12, 0.11, 0.12), LEAF, 14, 8)
	k.m.ellipsoid(_xf(c + Vector3(-0.04, 0.46, -0.05)), Vector3(0.05, 0.045, 0.05), LEAF.lightened(0.15), 10, 6)


## Tali beludru yang melengkung turun sedalam `sag` di antara `a` dan `b`.
static func _rope(mb: MeshBuilder, a: Vector3, b: Vector3, sag: float, col: Color) -> void:
	var n: int = 8
	var prev: Vector3 = a
	for i in range(1, n + 1):
		var t: float = float(i) / float(n)
		var p: Vector3 = a.lerp(b, t) + Vector3(0.0, -sag * sin(PI * t), 0.0)
		DecorFactory._seg(mb, prev, p, Vector2(0.016, 0.016), col)
		prev = p


## Patung kucing duduk krem bertotol jahe dengan telinga merah muda (Kitty Door).
static func _cat(k: DecorFactory.Kit, c: Vector3) -> void:
	var fur: Color = Color(0.98, 0.93, 0.84)
	var patch: Color = Color(0.93, 0.62, 0.32)
	k.m.cylinder(_xf(c + Vector3(0.0, 0.02, 0.0)), 0.04, 0.1, 0.11, Palette.STRAWBERRY.lightened(0.3), 16)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.13, 0.0)), Vector3(0.075, 0.09, 0.07), fur, 14, 8)
	k.m.ellipsoid(_xf(c + Vector3(0.03, 0.15, 0.03)), Vector3(0.045, 0.05, 0.04), patch, 10, 6)
	for s: float in [-1.0, 1.0]:
		k.m.ellipsoid(_xf(c + Vector3(s * 0.035, 0.055, -0.05)), Vector3(0.022, 0.02, 0.03), fur, 8, 5)
	var h: Vector3 = c + Vector3(0.0, 0.27, -0.01)
	k.m.ellipsoid(_xf(h), Vector3(0.068, 0.06, 0.06), fur, 14, 8)
	k.m.ellipsoid(_xf(h + Vector3(-0.03, 0.03, 0.01)), Vector3(0.03, 0.025, 0.03), patch, 8, 5)
	for s2: float in [-1.0, 1.0]:
		k.m.cylinder(_xf(h + Vector3(s2 * 0.038, 0.065, 0.0), Vector3(0.0, 0.0, -s2 * 12.0)), 0.05, 0.0, 0.03, fur, 4)
		k.m.cylinder(_xf(h + Vector3(s2 * 0.038, 0.06, -0.012), Vector3(0.0, 0.0, -s2 * 12.0)), 0.032, 0.0, 0.017, Palette.STRAWBERRY.lightened(0.2), 4)
		k.m.ellipsoid(_xf(h + Vector3(s2 * 0.024, 0.008, -0.055)), Vector3(0.011, 0.014, 0.006), Palette.DARK_CHOCOLATE, 8, 4)
		for t in 2:
			k.m.box(_xf(h + Vector3(s2 * 0.06, -0.012 + 0.012 * float(t), -0.05), Vector3(0.0, 0.0, s2 * (10.0 - 20.0 * float(t)))), Vector3(0.05, 0.003, 0.003), Palette.DARK_CHOCOLATE)
	k.m.ellipsoid(_xf(h + Vector3(0.0, -0.012, -0.06)), Vector3(0.009, 0.007, 0.005), Palette.STRAWBERRY_DEEP, 6, 3)
	k.m.torus(_xf(c + Vector3(0.0, 0.07, 0.06), Vector3(0.0, 0.0, 90.0)), 0.07, 0.016, patch, 14, 5, -PI * 0.5, PI * 0.6)


## Patung anak anjing duduk berkalung merah dengan telinga terkulai (Puppy Door).
static func _dog(k: DecorFactory.Kit, c: Vector3, fur: Color, ear: Color) -> void:
	k.m.cylinder(_xf(c + Vector3(0.0, 0.02, 0.0)), 0.04, 0.1, 0.11, Palette.SIGN_BLUE.lightened(0.25), 16)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.13, 0.0)), Vector3(0.078, 0.09, 0.075), fur, 14, 8)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.12, -0.05)), Vector3(0.045, 0.06, 0.03), Palette.FLOUR_WHITE, 10, 6)
	for s: float in [-1.0, 1.0]:
		k.m.ellipsoid(_xf(c + Vector3(s * 0.035, 0.055, -0.055)), Vector3(0.024, 0.02, 0.034), fur, 8, 5)
	k.m.torus(_xf(c + Vector3(0.0, 0.205, -0.005)), 0.055, 0.012, Palette.STRAWBERRY, 16, 4)
	k.s.ellipsoid(_xf(c + Vector3(0.0, 0.19, -0.06)), Vector3(0.014, 0.014, 0.01), DoorFactory.GOLD, 8, 4)
	var h: Vector3 = c + Vector3(0.0, 0.28, -0.015)
	k.m.ellipsoid(_xf(h), Vector3(0.07, 0.062, 0.062), fur, 14, 8)
	for s2: float in [-1.0, 1.0]:
		k.m.ellipsoid(_xf(h + Vector3(s2 * 0.07, -0.02, 0.0), Vector3(0.0, 0.0, s2 * 20.0)), Vector3(0.026, 0.06, 0.03), ear, 10, 6)
		k.m.ellipsoid(_xf(h + Vector3(s2 * 0.026, 0.015, -0.055)), Vector3(0.011, 0.013, 0.006), Palette.DARK_CHOCOLATE, 8, 4)
	k.m.ellipsoid(_xf(h + Vector3(0.0, -0.022, -0.05)), Vector3(0.04, 0.026, 0.028), Palette.FLOUR_WHITE, 10, 6)
	k.s.ellipsoid(_xf(h + Vector3(0.0, -0.01, -0.076)), Vector3(0.014, 0.011, 0.01), Palette.DARK_CHOCOLATE, 8, 4)
	k.m.ellipsoid(_xf(c + Vector3(0.0, 0.12, 0.08), Vector3(-35.0, 0.0, 0.0)), Vector3(0.018, 0.05, 0.018), fur, 8, 5)


## Istana pasir kecil berbendera di samping pintu (Seaside Door).
static func _sandcastle(k: DecorFactory.Kit, c: Vector3) -> void:
	k.m.cylinder(_xf(c + Vector3(0.0, 0.06, 0.0)), 0.12, 0.1, 0.11, SAND.darkened(0.06), 14)
	k.m.cylinder(_xf(c + Vector3(0.0, 0.16, 0.0)), 0.08, 0.065, 0.07, SAND, 14)
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		k.m.box(_xf(c + Vector3(cos(a) * 0.058, 0.215, sin(a) * 0.058), Vector3(0.0, -rad_to_deg(a), 0.0)), Vector3(0.025, 0.03, 0.025), SAND)
	k.m.cylinder(_xf(c + Vector3(0.0, 0.27, 0.0)), 0.1, 0.005, 0.005, Palette.DARK_CHOCOLATE, 6)
	k.m.box(_xf(c + Vector3(-0.02, 0.3, 0.0)), Vector3(0.04, 0.025, 0.004), Palette.STRAWBERRY)
	for s: float in [-1.0, 1.0]:
		k.s.polygon(_front(c + Vector3(s * 0.05, 0.05, -0.108)), _star_pts(0.022, 0.01), Palette.SIGN_ORANGE, Vector3.BACK)


# ===========================================================================
# PAPAN NAMA (sepaket dengan pintunya)
# ===========================================================================

## Tinggi dan tebal papan; muka depan di z = -SIGN_D / 2.
const SIGN_H: float = 0.28
const SIGN_D: float = 0.05

## Warna tulisan [isi, garis tepi] per gaya papan.
const SIGN_TEXT: Dictionary = {
	"tier_1": [Color(1.0, 0.98, 0.94), Color(0.36, 0.22, 0.14)],
	"tier_2": [Color(0.33, 0.21, 0.13), Color(1.0, 0.98, 0.94)],
	"tier_3": [Color(1.0, 0.92, 0.66), Color(0.24, 0.15, 0.1)],
	"tier_4": [Color(0.3, 0.19, 0.1), Color(1.0, 0.96, 0.84)],
	"tier_5": [Color(1.0, 0.86, 0.36), Color(0.1, 0.24, 0.17)],
	"carved": [Color(1.0, 0.92, 0.6), Color(0.36, 0.22, 0.14)],
	"door_kitty": [Color(0.36, 0.22, 0.14), Color(1.0, 0.98, 0.94)],
	"door_puppy": [Color(0.42, 0.26, 0.15), Color(1.0, 0.98, 0.94)],
	"door_garden": [Color(1.0, 0.98, 0.94), Color(0.22, 0.42, 0.24)],
	"door_galaxy": [Color(1.0, 0.92, 0.6), Color(0.1, 0.1, 0.26)],
	"door_candy": [Color(1.0, 0.98, 0.94), Color(0.78, 0.22, 0.3)],
	"door_ocean": [Color(1.0, 0.98, 0.94), Color(0.16, 0.38, 0.55)],
}


## Gaya papan: tema skin pintu, lalu skin papan ukir (`carved`), lalu tier.
static func sign_style(tier: int, theme: StringName, carved: bool) -> String:
	if theme != &"":
		return String(theme)
	if carved:
		return "carved"
	return "tier_%d" % clampi(tier, 1, 5)


## Badan papan nama selebar `w` gaya `style` (tanpa tulisan), berpusat di
## titik asal. Meta "top_extra": tinggi hiasan di atas papan (kanopi dinaikkan
## setinggi itu).
static func build_sign(style: String, w: float) -> Node3D:
	var k := DecorFactory.Kit.new("SignBody")
	var g := MeshBuilder.new()
	var top: float = 0.0
	match style:
		"tier_2":
			_board(k.m, w, Color(0.99, 0.95, 0.85), 0.06)
			_sign_frame(k.m, w, 0.03, Palette.PASTEL_MINT.darkened(0.25))
		"tier_3":
			_board(k.m, w, Color(0.36, 0.22, 0.14))
			_sign_frame(k.m, w, 0.028, Color(0.5, 0.33, 0.2))
			_sign_inner_line(k.m, w, 0.05, Color(0.62, 0.45, 0.28))
		"tier_4":
			_board(k.m, w, MARBLE)
			_sign_frame(k.m, w, 0.034, Palette.BRASS, k.s)
			for sx: float in [-1.0, 1.0]:
				for sy: float in [-1.0, 1.0]:
					k.s.ellipsoid(_xf(Vector3(sx * (w * 0.5 - 0.035), sy * (SIGN_H * 0.5 - 0.035), -0.034)), Vector3(0.01, 0.01, 0.006), Palette.BRASS.darkened(0.1), 6, 3)
			# Dua lampu sorot leher angsa di atas papan.
			for lx: float in [-w * 0.3, w * 0.3]:
				k.s.cylinder(_xf(Vector3(lx, SIGN_H * 0.5 + 0.04, 0.0)), 0.08, 0.006, 0.006, Palette.BRASS, 6)
				k.s.cylinder(_xf(Vector3(lx, SIGN_H * 0.5 + 0.085, -0.04), Vector3(70.0, 0.0, 0.0)), 0.07, 0.006, 0.006, Palette.BRASS, 6)
				k.s.cylinder(_xf(Vector3(lx, SIGN_H * 0.5 + 0.07, -0.085), Vector3(-30.0, 0.0, 0.0)), 0.04, 0.022, 0.012, Palette.BRASS, 10)
				g.ellipsoid(_xf(Vector3(lx, SIGN_H * 0.5 + 0.055, -0.095)), Vector3(0.016, 0.01, 0.016), Palette.WARMER_LAMP.lightened(0.3), 8, 4)
			top = 0.11
		"tier_5":
			_board(k.m, w, Palette.COLONIAL_GREEN)
			_sign_frame(k.m, w, 0.038, GOLD, k.s)
			_sign_inner_line(k.m, w, 0.055, GOLD.darkened(0.1))
			# Lambang mahkota di tengah atas dan bola emas di kedua ujung.
			var cy: float = SIGN_H * 0.5 + 0.035
			k.s.cylinder(_xf(Vector3(0.0, cy - 0.01, -0.005), Vector3(90.0, 0.0, 0.0)), 0.03, 0.07, 0.07, GOLD, 20)
			for i in 3:
				var cx: float = (float(i) - 1.0) * 0.045
				k.s.cylinder(_xf(Vector3(cx, cy + 0.035 + (0.012 if i == 1 else 0.0), -0.005)), 0.05, 0.0, 0.02, GOLD, 4)
				k.s.ellipsoid(_xf(Vector3(cx, cy + 0.065 + (0.012 if i == 1 else 0.0), -0.005)), Vector3(0.012, 0.012, 0.012), GOLD.lightened(0.15), 8, 4)
			k.s.ellipsoid(_xf(Vector3(0.0, cy - 0.005, -0.04)), Vector3(0.02, 0.02, 0.008), Palette.STRAWBERRY_DEEP, 10, 5)
			for sx2: float in [-1.0, 1.0]:
				k.s.ellipsoid(_xf(Vector3(sx2 * (w * 0.5 + 0.045), 0.0, 0.0)), Vector3(0.035, 0.035, 0.035), GOLD, 12, 6)
				k.s.cylinder(_xf(Vector3(sx2 * (w * 0.5 + 0.045), 0.05, 0.0)), 0.04, 0.0, 0.02, GOLD, 8)
			top = 0.12
		"carved":
			_board(k.m, w, Palette.DARK_CHOCOLATE)
			_sign_inner_line(k.m, w, 0.04, Palette.DARK_CHOCOLATE.lightened(0.2))
		"door_kitty":
			var pink: Color = Color(0.98, 0.76, 0.82)
			_board(k.m, w, pink, 0.08)
			_sign_inner_line(k.m, w, 0.035, Palette.FLOUR_WHITE)
			for sx3: float in [-1.0, 1.0]:
				var ex: float = sx3 * (w * 0.5 - 0.12)
				k.m.cylinder(_xf(Vector3(ex, SIGN_H * 0.5 + 0.04, 0.0)), 0.09, 0.0, 0.07, pink, 4)
				k.m.cylinder(_xf(Vector3(ex, SIGN_H * 0.5 + 0.035, -0.022)), 0.06, 0.0, 0.04, Palette.STRAWBERRY, 4)
				_paw(k.m, Vector3(sx3 * (w * 0.5 + 0.06), 0.0, 0.0), 0.8, Palette.STRAWBERRY)
			top = 0.09
		"door_puppy":
			var bone: Color = Color(0.99, 0.95, 0.86)
			_board(k.m, w, bone, 0.08)
			for sx4: float in [-1.0, 1.0]:
				for sy2: float in [-1.0, 1.0]:
					k.m.cylinder(_xf(Vector3(sx4 * (w * 0.5 + 0.02), sy2 * 0.09, 0.0), Vector3(90.0, 0.0, 0.0)), SIGN_D, 0.085, 0.085, bone, 20)
			_sign_inner_line(k.m, w - 0.1, 0.035, Color(0.84, 0.62, 0.38))
		"door_garden":
			_board(k.m, w, Color(0.82, 0.64, 0.42), 0.04)
			_sign_frame(k.m, w, 0.026, Color(0.62, 0.45, 0.28))
			var flowers: Array[Color] = [Palette.STRAWBERRY, Palette.FLOUR_WHITE, Palette.BUTTER_YELLOW, Palette.PASTEL_STRAWBERRY]
			var n: int = int(w / 0.07)
			for i2 in n + 1:
				var x: float = -w * 0.5 + float(i2) * w / float(n)
				k.m.ellipsoid(_xf(Vector3(x, SIGN_H * 0.5 + 0.01, -0.02), Vector3(0.0, 0.0, 30.0 if i2 % 2 == 0 else -30.0)), Vector3(0.04, 0.022, 0.025), LEAF if i2 % 2 == 0 else LEAF_DARK, 8, 4)
				if i2 % 3 == 1:
					k.m.ellipsoid(_xf(Vector3(x, SIGN_H * 0.5 + 0.03, -0.035)), Vector3(0.02, 0.02, 0.012), flowers[i2 % flowers.size()], 8, 4)
			for sx5: float in [-1.0, 1.0]:
				for j in 4:
					k.m.ellipsoid(_xf(Vector3(sx5 * (w * 0.5 + 0.01), SIGN_H * 0.4 - float(j) * 0.07, -0.03)), Vector3(0.022, 0.035, 0.02), LEAF, 8, 4)
			top = 0.05
		"door_galaxy":
			_board(k.m, w, NAVY, 0.05)
			_sign_frame(k.m, w, 0.026, NIGHT.lightened(0.2))
			var rng := RandomNumberGenerator.new()
			rng.seed = 23
			for i3 in 16:
				var sp := Vector3(rng.randf_range(-w * 0.47, w * 0.47), rng.randf_range(-SIGN_H * 0.42, SIGN_H * 0.42), -SIGN_D * 0.5 - 0.004)
				if absf(sp.y) < SIGN_H * 0.3 and absf(sp.x) < w * 0.42:
					sp.y = signf(sp.y if sp.y != 0.0 else 1.0) * SIGN_H * 0.38
				g.ellipsoid(_xf(sp), Vector3(0.008, 0.008, 0.004) * rng.randf_range(0.7, 1.4), STAR, 6, 3)
			g.torus(_xf(Vector3(-(w * 0.5 + 0.07), 0.02, 0.0), Vector3(90.0, 0.0, 0.0)), 0.06, 0.016, GOLD.lightened(0.2), 18, 6, PI * 0.15, PI * 1.25)
			g.polygon(_front(Vector3(w * 0.5 + 0.06, 0.04, 0.0)), _star_pts(0.045, 0.02), STAR, Vector3.BACK)
		"door_candy":
			_board(k.m, w, Palette.PASTEL_STRAWBERRY.lightened(0.1), 0.06)
			var m: int = int((w + SIGN_H) * 2.0 / 0.06)
			for i4 in m:
				var u: float = float(i4) / float(m)
				var pos: Vector3 = _perimeter(w + 0.02, SIGN_H + 0.02, u)
				k.s.box(_xf(pos + Vector3(0.0, 0.0, -0.003)), Vector3(0.032, 0.026, SIGN_D + 0.006), Palette.STRAWBERRY if i4 % 2 == 0 else Palette.FLOUR_WHITE)
			var gum: Array[Color] = [Palette.MATCHA, Palette.SIGN_BLUE, Palette.BUTTER_YELLOW, Palette.SIGN_PURPLE]
			for i5 in 5:
				k.s.ellipsoid(_xf(Vector3((float(i5) - 2.0) * w * 0.2, SIGN_H * 0.5 + 0.035, 0.0)), Vector3(0.025, 0.028, 0.02), gum[i5 % gum.size()], 10, 6)
			top = 0.06
		"door_ocean":
			_board(k.m, w, AQUA, 0.05)
			_sign_inner_line(k.m, w, 0.035, Palette.FLOUR_WHITE)
			var n2: int = int(w / 0.08)
			for i6 in n2 + 1:
				var x2: float = -w * 0.5 + float(i6) * w / float(n2)
				k.m.ellipsoid(_xf(Vector3(x2, SIGN_H * 0.5 + 0.005, -0.004)), Vector3(0.045, 0.035, 0.03), Palette.FLOUR_WHITE if i6 % 2 == 0 else AQUA.lightened(0.25), 10, 5)
			var shell := PackedVector2Array([Vector2(0.0, -0.045)])
			for i7 in 9:
				var a: float = PI * (0.15 + 0.7 * float(i7) / 8.0)
				shell.append(Vector2(cos(a), sin(a)) * (0.085 if i7 % 2 == 0 else 0.075))
			k.s.polygon(_front(Vector3(w * 0.5 + 0.06, -0.02, -0.01)), shell, Palette.PASTEL_STRAWBERRY.lightened(0.15), Vector3.BACK)
			k.s.polygon(_front(Vector3(-(w * 0.5 + 0.055), 0.0, -0.01)), _star_pts(0.05, 0.022), Palette.SIGN_ORANGE, Vector3.BACK)
			top = 0.04
		_:
			# Tier 1: papan kayu berpaku dengan dua alur papan.
			_board(k.m, w, Palette.CARAMEL)
			for y: float in [-SIGN_H * 0.17, SIGN_H * 0.17]:
				k.m.box(_xf(Vector3(0.0, y, -SIGN_D * 0.5 - 0.001)), Vector3(w - 0.02, 0.006, 0.004), Palette.CARAMEL.darkened(0.18))
			for sx6: float in [-1.0, 1.0]:
				for sy3: float in [-1.0, 1.0]:
					k.s.ellipsoid(_xf(Vector3(sx6 * (w * 0.5 - 0.04), sy3 * (SIGN_H * 0.5 - 0.045), -SIGN_D * 0.5 - 0.002)), Vector3(0.008, 0.008, 0.004), Palette.DARK_CHOCOLATE, 6, 3)
	var root: Node3D = k.done()
	if not g.is_empty():
		var mi: MeshInstance3D = g.commit("Glow")
		mi.material_override = ProceduralMeshFactory.material(Color.WHITE)
		EquipmentFactory._set_glow(mi, STAR if style == "door_galaxy" else Palette.WARMER_LAMP, 0.9)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	root.set_meta("sign_style", style)
	root.set_meta("top_extra", top)
	return root


## Papan dasar, sudutnya membulat bila `r` > 0.
static func _board(mb: MeshBuilder, w: float, col: Color, r: float = 0.0) -> void:
	if r > 0.0:
		DecorFactory._rounded_board(mb, Vector3.ZERO, Vector2(w, SIGN_H), SIGN_D, r, col)
	else:
		mb.box(_xf(Vector3.ZERO), Vector3(w, SIGN_H, SIGN_D), col)


## Bingkai menonjol di tepi papan (batang-batang `t` tebal).
static func _sign_frame(mb: MeshBuilder, w: float, t: float, col: Color, shiny: MeshBuilder = null) -> void:
	var b: MeshBuilder = shiny if shiny != null else mb
	for s: float in [-1.0, 1.0]:
		b.box(_xf(Vector3(0.0, s * (SIGN_H + t) * 0.5, -0.004)), Vector3(w + t * 2.0, t, SIGN_D + 0.012), col)
		b.box(_xf(Vector3(s * (w + t) * 0.5, 0.0, -0.004)), Vector3(t, SIGN_H, SIGN_D + 0.012), col)


## Garis tipis di dalam tepi muka papan, `inset` dari tepinya.
static func _sign_inner_line(mb: MeshBuilder, w: float, inset: float, col: Color) -> void:
	var z: float = -SIGN_D * 0.5 - 0.002
	var t: float = 0.008
	for s: float in [-1.0, 1.0]:
		mb.box(_xf(Vector3(0.0, s * (SIGN_H * 0.5 - inset), z)), Vector3(w - inset * 2.0, t, 0.004), col)
		mb.box(_xf(Vector3(s * (w * 0.5 - inset), 0.0, z)), Vector3(t, SIGN_H - inset * 2.0, 0.004), col)


## Cap kaki kucing di muka depan pada `c`.
static func _paw(mb: MeshBuilder, c: Vector3, s: float, col: Color) -> void:
	var z: Vector3 = c + Vector3(0.0, 0.0, -SIGN_D * 0.5 - 0.003)
	mb.polygon(_front(z + Vector3(0.0, -0.015, 0.0) * s), DecorFactory._oval_pts(0.03 * s, 0.026 * s, 12), col, Vector3.BACK)
	for t in 3:
		var a: float = deg_to_rad(-40.0 + 40.0 * float(t))
		mb.polygon(_front(z + Vector3(sin(a) * 0.04, cos(a) * 0.035 + 0.01, 0.0) * s), DecorFactory._oval_pts(0.012 * s, 0.014 * s, 8), col, Vector3.BACK)


## Titik di keliling persegi panjang `w` x `h` (u 0..1 searah jarum jam).
static func _perimeter(w: float, h: float, u: float) -> Vector3:
	var per: float = (w + h) * 2.0
	var d: float = fposmod(u, 1.0) * per
	if d < w:
		return Vector3(-w * 0.5 + d, h * 0.5, 0.0)
	d -= w
	if d < h:
		return Vector3(w * 0.5, h * 0.5 - d, 0.0)
	d -= h
	if d < w:
		return Vector3(w * 0.5 - d, -h * 0.5, 0.0)
	d -= w
	return Vector3(-w * 0.5, -h * 0.5 + d, 0.0)

