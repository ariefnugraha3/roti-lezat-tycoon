class_name DecorFactory
extends RefCounted
## Model dekorasi (GDD 72.1, 72.3): satu model untuk setiap dekorasi yang bisa
## dipasang, dirakit dari bentuk dasar MeshBuilder (satu mesh matte + satu mesh
## satin per model) ditambah bagian khusus: kaca bening toples koin, bola lampu
## yang menyala, dan bandul jam yang berayun. 100% prosedural (GDD 4, 111), tanpa
## teks; angka dan bintang dibentuk dari geometri.
##
## Titik asal dan arah hadap per jenis penempatan:
##   wall          permukaan dinding di pusat slot; model menonjol ke -Z lokal.
##   counter_prop  permukaan meja kasir; muka menghadap pembeli di -Z lokal.
##   floor_prop    lantai di pusat ubin; muka di -Z lokal.
##   floor_overlay lantai di pusat jejak; ukuran = overlay_size_tiles.
## Karena muka menghadap -Z, sisi KANAN penonton adalah -X lokal; tata letak yang
## tidak simetris memakai _v(u, v, z) dengan u ke kanan penonton.
##
## Anggaran GDD 12.2: setiap model di bawah MAX_TRIS.

const MAX_TRIS: int = 2000
## Node anak yang diayun WorldView (bandul jam dinding).
const SWING_NODE: String = "Pendulum"

const WALNUT: Color = Color(0.42, 0.26, 0.15)
const LEAF: Color = Color(0.42, 0.66, 0.40)
const LEAF_DARK: Color = Color(0.28, 0.52, 0.30)
const BRASS: Color = Color(0.88, 0.68, 0.30)
const BRONZE: Color = Color(0.74, 0.47, 0.24)
const SILVER: Color = Color(0.82, 0.84, 0.88)
const GOLD: Color = Color(0.96, 0.76, 0.22)
const WICKER: Color = Color(0.82, 0.64, 0.38)
const SKY: Color = Color(0.74, 0.87, 0.96)
const BRICK: Color = Color(0.64, 0.29, 0.18)
const GLASS: Color = Color(0.88, 0.96, 1.0, 0.30)
const LCD: Color = Color(0.62, 0.72, 0.56)

## Bintang di plakat kenaikan tier (GDD 72.1: ach_tier2..4).
const PLAQUE_STARS: Dictionary = {&"decor_plaque_tier2": 2, &"decor_plaque_tier3": 3, &"decor_plaque_tier4": 4}

static var _proto: Dictionary = {}
static var _glass_mat: StandardMaterial3D = null
static var _marker_mat: StandardMaterial3D = null


## Salinan model siap pasang (mesh & material dipakai bersama prototipe).
static func build_cached(deco_id: StringName) -> Node3D:
	if not _proto.has(deco_id):
		_proto[deco_id] = build(deco_id)
	return (_proto[deco_id] as Node3D).duplicate()


static func clear_caches() -> void:
	for k: Variant in _proto.keys():
		var n: Variant = _proto[k]
		if n is Node and is_instance_valid(n):
			(n as Node).free()
	_proto.clear()
	_glass_mat = null
	_marker_mat = null


## Profil visual yang punya model (GDD 72.1 `visual_profile_id`).
static func has_model(profile: StringName) -> bool:
	return profile in [&"gingham_curtains", &"wall_clock", &"chalk_board", &"flower_box", &"photo_wall",
		&"hanging_lamp", &"plaque_bronze", &"plaque_silver", &"plaque_gold", &"photo_frame", &"plaque_infinity",
		&"cassette_radio", &"coin_jar", &"trophy_small", &"calculator", &"brass_bell",
		&"potted_plant", &"basket_stack", &"trophy_large", &"umbrella_stand", &"terracotta_rug", &"floor_mat"]


## Model utuh satu dekorasi. Dekorasi tak dikenal menghasilkan node kosong.
static func build(deco_id: StringName) -> Node3D:
	var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(deco_id)
	var k := Kit.new("Decor_%s" % deco_id)
	if def == null:
		return k.done()
	match def.visual_profile_id:
		&"gingham_curtains":
			_curtains(k)
		&"wall_clock":
			_pendulum_clock(k)
		&"chalk_board":
			_chalk_board(k)
		&"flower_box":
			_flower_box(k)
		&"photo_wall":
			_photo_wall(k)
		&"hanging_lamp":
			_hanging_lamp(k)
		&"plaque_bronze":
			_plaque_hundred(k)
		&"plaque_silver":
			_plaque_stars(k, int(PLAQUE_STARS.get(deco_id, 2)), false)
		&"plaque_gold":
			_plaque_stars(k, int(PLAQUE_STARS.get(deco_id, 4)), true)
		&"photo_frame":
			_photo_pak_lurah(k)
		&"plaque_infinity":
			_plaque_infinity(k)
		&"cassette_radio":
			_cassette_radio(k)
		&"coin_jar":
			_coin_jar(k)
		&"trophy_small":
			_trophy_small(k)
		&"calculator":
			_calculator(k)
		&"brass_bell":
			_brass_bell(k)
		&"potted_plant":
			_potted_plant(k)
		&"basket_stack":
			_basket_stand(k)
		&"trophy_large":
			_trophy_large(k)
		&"umbrella_stand":
			_umbrella_stand(k)
		&"terracotta_rug":
			_terracotta_rug(k, Vector2(def.overlay_size_tiles) * GridMath.WORLD_METERS_PER_TILE)
		&"floor_mat":
			_floor_mat(k, Vector2(def.overlay_size_tiles) * GridMath.WORLD_METERS_PER_TILE)
	var root: Node3D = k.done()
	root.set_meta("deco_id", deco_id)
	root.set_meta("placement_type", def.placement_type)
	return root


## Material penanda slot Decoration Mode: tanpa bayangan, warna verteks, tembus.
static func marker_material() -> StandardMaterial3D:
	if _marker_mat == null:
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.disable_receive_shadows = true
		_marker_mat = m
	return _marker_mat


## Penanda satu slot (GDD 72.3): bingkai bersudut + tanda tambah di dinding,
## atau cincin + tanda tambah di atas meja. `current` = slot barang terpilih.
static func slot_marker(placement_type: StringName, current: bool) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var col: Color = Color(Palette.GOLD_STAR, 0.95) if current else Color(Palette.FLOUR_WHITE, 0.88)
	var edge: Color = Color(Palette.UI_WOOD, 0.55)
	if placement_type == &"wall":
		var w: float = 0.46
		var h: float = 0.34
		var b: float = 0.026
		for s: float in [-1.0, 1.0]:
			mb.box(_xf(Vector3(0.0, s * (h - b) * 0.5, -0.012)), Vector3(w, b, 0.006), col)
			mb.box(_xf(Vector3(s * (w - b) * 0.5, 0.0, -0.012)), Vector3(b, h - b * 2.0, 0.006), col)
		mb.box(_xf(Vector3(0.0, 0.0, -0.013)), Vector3(0.12, 0.028, 0.006), col)
		mb.box(_xf(Vector3(0.0, 0.0, -0.013)), Vector3(0.028, 0.12, 0.006), col)
		mb.box(_xf(Vector3(0.0, 0.0, -0.006)), Vector3(w - b * 2.0, h - b * 2.0, 0.002), Color(edge, 0.25))
	else:
		mb.torus(_xf(Vector3(0.0, 0.008, 0.0)), 0.085, 0.012, col, 24, 4)
		mb.box(_xf(Vector3(0.0, 0.01, 0.0)), Vector3(0.09, 0.008, 0.022), col)
		mb.box(_xf(Vector3(0.0, 0.01, 0.0)), Vector3(0.022, 0.008, 0.09), col)
		mb.disc(_xf(Vector3(0.0, 0.004, 0.0)), 0.075, Color(edge, 0.25), Color(edge, 0.12), 20)
	var mi: MeshInstance3D = mb.commit("SlotMarker")
	mi.material_override = marker_material()
	return mi


# ===========================================================================
# DINDING
# ===========================================================================

## Tirai gingham: jendela lukis bertirai merah muda, diikat di tengah, dengan
## lambrekin bergelombang dan batang tirai berujung emas.
static func _curtains(k: Kit) -> void:
	var wood: Color = Palette.CARAMEL
	k.m.box(_xf(Vector3(0.0, 0.0, -0.004)), Vector3(0.38, 0.34, 0.008), SKY)
	k.m.box(_xf(Vector3(0.0, -0.115, -0.0085)), Vector3(0.38, 0.11, 0.002), SKY.lerp(Palette.PASTEL_MINT, 0.75))
	k.m.cylinder(_xf(_v(-0.10, 0.085, -0.009), Vector3(90.0, 0.0, 0.0)), 0.004, 0.034, 0.034, Palette.BUTTER_YELLOW, 14)
	for c: Vector3 in [_v(0.05, 0.10, -0.010), _v(0.085, 0.108, -0.011), _v(0.12, 0.098, -0.010)]:
		k.m.ellipsoid(_xf(c), Vector3(0.030, 0.018, 0.004), Palette.FLOUR_WHITE, 8, 4)
	_frame(k.m, Vector3(0.0, 0.0, -0.018), Vector2(0.44, 0.40), 0.035, 0.036, wood)
	k.m.box(_xf(Vector3(0.0, 0.0, -0.012)), Vector3(0.016, 0.34, 0.012), Palette.FLOUR_WHITE)
	k.m.box(_xf(Vector3(0.0, 0.02, -0.012)), Vector3(0.38, 0.016, 0.012), Palette.FLOUR_WHITE)
	k.m.box(_xf(Vector3(0.0, -0.215, -0.035)), Vector3(0.50, 0.03, 0.07), wood.darkened(0.1))
	# Batang tirai, penyangga, dan ujung emasnya.
	k.s.cylinder(_xf(Vector3(0.0, 0.235, -0.07), Vector3(0.0, 0.0, 90.0)), 0.62, 0.011, 0.011, Palette.DARK_CHOCOLATE, 8)
	for sx: float in [-1.0, 1.0]:
		k.s.ellipsoid(_xf(Vector3(sx * 0.315, 0.235, -0.07)), Vector3(0.021, 0.021, 0.021), GOLD, 8, 5)
		k.m.box(_xf(Vector3(sx * 0.27, 0.235, -0.035)), Vector3(0.016, 0.016, 0.07), Palette.DARK_CHOCOLATE)
		_curtain_panel(k.m, sx)
	# Lambrekin: kotak-kotak bergantian dengan lengkung di bawahnya.
	for i in 6:
		var x: float = -0.25 + float(i) * 0.1
		var col: Color = Palette.GINGHAM_A if i % 2 == 0 else Palette.GINGHAM_B
		k.m.box(_xf(Vector3(x, 0.21, -0.082)), Vector3(0.1, 0.05, 0.008), col)
		k.m.polygon(_xf(Vector3(x, 0.186, -0.0865)), _arc_pts(0.05, PI, TAU, 6), col, Vector3.FORWARD)


## Satu sisi tirai: empat lipit x delapan baris kotak-kotak, menyempit ke tali
## pengikat lalu melebar lagi ke bawah.
static func _curtain_panel(mb: MeshBuilder, side: float) -> void:
	var top: float = 0.225
	var bottom: float = -0.205
	var tie_y: float = -0.04
	var rows: int = 8
	var strips: int = 4
	var outer: float = 0.30
	for r in rows:
		var y0: float = lerpf(top, bottom, float(r) / float(rows))
		var y1: float = lerpf(top, bottom, float(r + 1) / float(rows))
		var yc: float = (y0 + y1) * 0.5
		var inner: float
		if yc > tie_y:
			inner = lerpf(0.12, 0.235, (top - yc) / (top - tie_y))
		else:
			inner = lerpf(0.235, 0.185, (tie_y - yc) / (tie_y - bottom))
		var ws: float = (outer - inner) / float(strips)
		for j in strips:
			var xc: float = side * (inner + ws * (float(j) + 0.5))
			var z: float = -0.05 - (0.012 if j % 2 == 0 else 0.0)
			var col: Color = Palette.GINGHAM_A if (r + j) % 2 == 0 else Palette.GINGHAM_B
			var yaw: float = side * (16.0 if j % 2 == 0 else -16.0)
			mb.box(_xf(Vector3(xc, yc, z), Vector3(0.0, yaw, 0.0)), Vector3(ws * 1.1, (y0 - y1) * 1.02, 0.008), col)
	mb.box(_xf(Vector3(side * 0.265, tie_y, -0.064)), Vector3(0.09, 0.022, 0.03), Palette.ROSY_CHEEK)


## Jam dinding bandul: kepala bundar kayu walnut, angka dari garis, jarum jam
## 10.10, dan bandul kuningan di balik jendela kaca yang diayun WorldView.
static func _pendulum_clock(k: Kit) -> void:
	var case_col: Color = WALNUT
	k.m.cylinder(_xf(Vector3(0.0, 0.17, -0.035), Vector3(90.0, 0.0, 0.0)), 0.07, 0.11, 0.11, case_col, 20)
	k.m.box(_xf(Vector3(0.0, -0.06, -0.035)), Vector3(0.20, 0.40, 0.07), case_col)
	k.m.box(_xf(Vector3(0.0, 0.29, -0.03)), Vector3(0.07, 0.03, 0.05), case_col.darkened(0.15))
	k.s.ellipsoid(_xf(Vector3(0.0, 0.316, -0.03)), Vector3(0.018, 0.018, 0.018), GOLD, 8, 5)
	k.m.box(_xf(Vector3(0.0, -0.272, -0.04)), Vector3(0.23, 0.03, 0.08), case_col.darkened(0.15))
	k.s.ellipsoid(_xf(Vector3(0.0, -0.30, -0.045)), Vector3(0.02, 0.022, 0.02), GOLD, 8, 5)
	# Muka jam.
	var fc := Vector3(0.0, 0.17, 0.0)
	k.m.cylinder(_xf(fc + Vector3(0.0, 0.0, -0.074), Vector3(90.0, 0.0, 0.0)), 0.008, 0.085, 0.085, Palette.FLOUR_WHITE, 20)
	k.s.torus(_xf(fc + Vector3(0.0, 0.0, -0.077), Vector3(90.0, 0.0, 0.0)), 0.088, 0.008, GOLD, 20, 6)
	for i in 12:
		var a: float = TAU * float(i) / 12.0
		var major: bool = i % 3 == 0
		k.m.box(_xf(fc + Vector3(-sin(a) * 0.066, cos(a) * 0.066, -0.0795), Vector3(0.0, 0.0, rad_to_deg(a))),
			Vector3(0.008 if major else 0.005, 0.018 if major else 0.010, 0.003), Palette.DARK_CHOCOLATE)
	for hand: Vector2 in [Vector2(TAU * (10.0 + 10.0 / 60.0) / 12.0, 0.042), Vector2(TAU * 10.0 / 60.0, 0.062)]:
		var ha: float = hand.x
		var hl: float = hand.y
		k.m.box(_xf(fc + Vector3(-sin(ha) * hl * 0.5, cos(ha) * hl * 0.5, -0.0815), Vector3(0.0, 0.0, rad_to_deg(ha))),
			Vector3(0.009 if hl < 0.05 else 0.006, hl, 0.003), Palette.DARK_CHOCOLATE)
	k.s.ellipsoid(_xf(fc + Vector3(0.0, 0.0, -0.083)), Vector3(0.008, 0.008, 0.004), GOLD, 8, 4)
	# Jendela bandul.
	k.m.box(_xf(Vector3(0.0, -0.08, -0.0715)), Vector3(0.13, 0.26, 0.004), case_col.darkened(0.45))
	_frame(k.s, Vector3(0.0, -0.08, -0.073), Vector2(0.15, 0.28), 0.012, 0.008, GOLD)
	var pend := Node3D.new()
	pend.name = SWING_NODE
	k.root.add_child(pend)
	pend.position = Vector3(0.0, 0.05, -0.083)
	var pb := MeshBuilder.new()
	pb.box(_xf(Vector3(0.0, -0.095, 0.0)), Vector3(0.008, 0.19, 0.004), BRASS)
	pb.cylinder(_xf(Vector3(0.0, -0.20, 0.0), Vector3(90.0, 0.0, 0.0)), 0.008, 0.034, 0.034, GOLD, 16)
	pend.add_child(pb.commit("Bob", MeshBuilder.SATIN))


## Papan menu kapur: papan hijau tua berbingkai pinus tergantung pada tali, dengan
## coretan kapur (roti, hati, garis menu, bintang) dan kapur di ambangnya.
static func _chalk_board(k: Kit) -> void:
	k.m.box(_xf(Vector3(0.0, 0.0, -0.01)), Vector3(0.48, 0.34, 0.02), Palette.CHALKBOARD)
	_frame(k.m, Vector3(0.0, 0.0, -0.016), Vector2(0.54, 0.40), 0.03, 0.032, Palette.PINE_WOOD)
	k.s.cylinder(_xf(Vector3(0.0, 0.30, -0.012), Vector3(90.0, 0.0, 0.0)), 0.024, 0.008, 0.008, Palette.DARK_CHOCOLATE, 8)
	for sx: float in [-1.0, 1.0]:
		_seg(k.m, Vector3(sx * 0.2, 0.2, -0.02), Vector3(0.0, 0.30, -0.02), Vector2(0.006, 0.004), Palette.CARAMEL)
	k.m.box(_xf(Vector3(0.0, -0.215, -0.03)), Vector3(0.46, 0.014, 0.05), Palette.PINE_WOOD.darkened(0.1))
	k.m.box(_xf(_v(-0.12, -0.203, -0.035), Vector3(0.0, 20.0, 0.0)), Vector3(0.04, 0.01, 0.01), Palette.CHALK_WHITE)
	k.m.box(_xf(_v(-0.06, -0.203, -0.03), Vector3(0.0, -10.0, 0.0)), Vector3(0.035, 0.01, 0.01), Palette.PASTEL_STRAWBERRY)
	k.m.box(_xf(_v(0.14, -0.196, -0.03)), Vector3(0.06, 0.022, 0.025), Palette.CARAMEL)
	k.m.box(_xf(_v(0.14, -0.205, -0.03)), Vector3(0.062, 0.008, 0.027), Palette.FLOUR_WHITE.darkened(0.1))
	# Coretan kapur (bidang -Z, tepat di depan papan).
	var z: float = -0.0206
	var chalk: Color = Palette.CHALK_WHITE
	for i in 3:
		k.m.box(_xf(_v(-0.08 + float(i) * 0.08, 0.125, z), Vector3(0.0, 0.0, 6.0 - float(i) * 6.0)), Vector3(0.055, 0.016, 0.002), chalk)
	for i in 6:
		var u0: float = -0.10 + float(i) * 0.04
		_seg(k.m, _v(u0, 0.095, z), _v(u0 + 0.04, 0.095 + (0.008 if i % 2 == 0 else -0.008), z), Vector2(0.005, 0.002), Palette.BUTTER_YELLOW)
	k.m.polygon(_xf(_v(-0.13, -0.01, z - 0.0005)), _oval_pts(0.065, 0.038, 14), Palette.CUSTARD.lightened(0.35), Vector3.FORWARD)
	for i in 3:
		k.m.box(_xf(_v(-0.16 + float(i) * 0.03, 0.0, z - 0.0012), Vector3(0.0, 0.0, -35.0)), Vector3(0.006, 0.028, 0.001), Palette.CHALKBOARD)
	k.m.polygon(_xf(_v(-0.13, -0.105, z - 0.0005)), _heart_pts(0.028), Palette.PASTEL_STRAWBERRY, Vector3.FORWARD)
	for row in 3:
		var v: float = 0.045 - float(row) * 0.06
		var ink: Color = Palette.BUTTER_YELLOW if row == 1 else chalk
		k.m.box(_xf(_v(0.075, v, z)), Vector3(0.09, 0.012, 0.002), ink)
		for d in 3:
			k.m.box(_xf(_v(0.135 + float(d) * 0.014, v - 0.004, z)), Vector3(0.005, 0.005, 0.002), chalk)
		k.m.box(_xf(_v(0.195, v, z)), Vector3(0.03, 0.012, 0.002), ink)
	k.m.polygon(_xf(_v(0.19, 0.13, z - 0.0005)), _star_pts(0.024, 0.01), Palette.BUTTER_YELLOW, Vector3.FORWARD)


## Kotak bunga jendela: bak kayu pada dua siku besi, penuh bunga pastel.
static func _flower_box(k: Kit) -> void:
	var body: Color = Palette.PINE_WOOD
	k.m.box(_xf(Vector3(0.0, -0.17, -0.07)), Vector3(0.52, 0.11, 0.13), body)
	for i in 2:
		k.m.box(_xf(Vector3(0.0, -0.205 + float(i) * 0.037, -0.1362)), Vector3(0.50, 0.004, 0.002), body.darkened(0.22))
	for s: float in [-1.0, 1.0]:
		k.m.box(_xf(Vector3(0.0, -0.11, -0.07 + s * 0.065)), Vector3(0.55, 0.018, 0.018), Palette.CARAMEL)
		k.m.box(_xf(Vector3(s * 0.266, -0.11, -0.07)), Vector3(0.018, 0.018, 0.12), Palette.CARAMEL)
		k.s.box(_xf(Vector3(s * 0.19, -0.24, -0.006)), Vector3(0.02, 0.10, 0.012), Palette.DARK_CHOCOLATE)
		_seg(k.s, Vector3(s * 0.19, -0.285, -0.008), Vector3(s * 0.19, -0.228, -0.12), Vector2(0.014, 0.014), Palette.DARK_CHOCOLATE)
	k.m.box(_xf(Vector3(0.0, -0.114, -0.07)), Vector3(0.51, 0.006, 0.11), Palette.DARK_CHOCOLATE)
	var petals: Array[Color] = [Palette.PASTEL_STRAWBERRY, Palette.FLOUR_WHITE, Palette.ROSY_CHEEK, Palette.PASTEL_PERIWINKLE,
		Palette.BUTTER_YELLOW, Palette.PASTEL_STRAWBERRY, Palette.FLOUR_WHITE]
	for i in 7:
		var u: float = -0.21 + float(i) * 0.07
		var h: float = 0.08 + float((i * 5) % 4) * 0.017
		var z: float = -0.07 + (0.022 if i % 2 == 0 else -0.018)
		k.m.cylinder(_xf(Vector3(u, -0.11 + h * 0.5, z)), h, 0.005, 0.005, LEAF_DARK, 5, false, false)
		for s: float in [-1.0, 1.0]:
			k.m.ellipsoid(_xf(Vector3(u + s * 0.02, -0.09 + h * 0.2, z), Vector3(0.0, 0.0, s * -40.0)), Vector3(0.028, 0.009, 0.012), LEAF, 5, 3)
		var head := Vector3(u, -0.11 + h, z - 0.004)
		k.m.polygon(_xf(head, Vector3(20.0, 0.0, float(i) * 17.0)), _flower_pts(0.034, 5), petals[i], Vector3.FORWARD)
		var mid: Color = Palette.GOLDEN_CRUST if petals[i] == Palette.BUTTER_YELLOW else Palette.BUTTER_YELLOW
		k.m.ellipsoid(_xf(head + Vector3(0.0, 0.002, -0.004)), Vector3(0.011, 0.011, 0.006), mid, 6, 3)
	for i in 6:
		k.m.ellipsoid(_xf(Vector3(-0.175 + float(i) * 0.07, -0.098, -0.07 + (0.03 if i % 2 == 0 else -0.03))),
			Vector3(0.036, 0.024, 0.03), LEAF if i % 2 == 0 else LEAF_DARK, 6, 4)


## Dinding foto keluarga: lima bingkai beragam (satu lonjong) berisi foto sederhana.
static func _photo_wall(k: Kit) -> void:
	# Foto besar: keluarga di taman.
	var c1: Vector2 = Vector2(-0.16, 0.07)
	_photo(k, c1, Vector2(0.19, 0.23), Palette.CARAMEL, SKY)
	k.m.box(_xf(_v(c1.x, c1.y - 0.07, -0.0085)), Vector3(0.17, 0.065, 0.001), Palette.PASTEL_MINT)
	var people: Array = [[-0.05, Palette.APRON_NAVY, 1.0], [0.0, Palette.PASTEL_STRAWBERRY, 0.95], [0.045, Palette.RAINCOAT_YELLOW, 0.7]]
	for p: Array in people:
		var u: float = c1.x + float(p[0])
		var sc: float = float(p[2])
		k.m.polygon(_xf(_v(u, c1.y - 0.055 * sc, -0.0092)), _round_rect_pts(0.036 * sc, 0.05 * sc, 0.012 * sc, 3), p[1], Vector3.FORWARD)
		k.m.polygon(_xf(_v(u, c1.y - 0.01 * sc + 0.012, -0.0094)), _oval_pts(0.015 * sc, 0.016 * sc, 10), CharacterFactory.SKIN_MID, Vector3.FORWARD)
		k.m.polygon(_xf(_v(u, c1.y + 0.014 * sc + 0.012, -0.0096)), _arc_pts(0.016 * sc, 0.0, PI, 6), CharacterFactory.HAIR_BROWN, Vector3.FORWARD)
	# Toko roti.
	var c2: Vector2 = Vector2(0.04, 0.14)
	_photo(k, c2, Vector2(0.17, 0.13), WALNUT, Palette.BUTTER_YELLOW.lightened(0.35))
	k.m.polygon(_xf(_v(c2.x, c2.y - 0.018, -0.0092)), _rect_pts(0.08, 0.05), Palette.VANILLA_CREAM, Vector3.FORWARD)
	k.m.polygon(_xf(_v(c2.x, c2.y + 0.008, -0.0094)), PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.0, 0.035)]), Palette.TERRACOTTA, Vector3.FORWARD)
	k.m.polygon(_xf(_v(c2.x, c2.y - 0.03, -0.0095)), _rect_pts(0.018, 0.026), Palette.DARK_CHOCOLATE, Vector3.FORWARD)
	for i in 4:
		k.m.polygon(_xf(_v(c2.x - 0.03 + float(i) * 0.02, c2.y - 0.002, -0.0096)), _rect_pts(0.02, 0.012),
			Palette.PASTEL_STRAWBERRY if i % 2 == 0 else Palette.FLOUR_WHITE, Vector3.FORWARD)
	# Potret lonjong berbingkai emas.
	var c3: Vector2 = Vector2(0.20, 0.05)
	k.s.torus(_xf(_v(c3.x, c3.y, -0.01), Vector3(90.0, 0.0, 0.0), Vector3(0.06, 0.1, 0.08)), 1.0, 0.13, GOLD, 18, 5)
	k.m.polygon(_xf(_v(c3.x, c3.y, -0.006)), _oval_pts(0.058, 0.078, 16), Palette.PASTEL_PERIWINKLE, Vector3.FORWARD)
	k.m.polygon(_xf(_v(c3.x, c3.y - 0.045, -0.0065)), _arc_pts(0.04, 0.0, PI, 8), Palette.APRON_MAROON, Vector3.FORWARD)
	k.m.polygon(_xf(_v(c3.x, c3.y + 0.004, -0.0068)), _oval_pts(0.021, 0.024, 10), CharacterFactory.SKIN_LIGHT, Vector3.FORWARD)
	k.m.polygon(_xf(_v(c3.x, c3.y + 0.018, -0.007)), _arc_pts(0.023, 0.0, PI, 6), CharacterFactory.HAIR_BLACK, Vector3.FORWARD)
	# Roti.
	var c4: Vector2 = Vector2(-0.07, -0.14)
	_photo(k, c4, Vector2(0.15, 0.11), Palette.PINE_WOOD, Palette.PASTEL_STRAWBERRY.lightened(0.45))
	k.m.polygon(_xf(_v(c4.x, c4.y - 0.004, -0.0092)), _oval_pts(0.045, 0.024, 12), Palette.GOLDEN_CRUST, Vector3.FORWARD)
	for i in 3:
		k.m.box(_xf(_v(c4.x - 0.02 + float(i) * 0.02, c4.y, -0.0095), Vector3(0.0, 0.0, -30.0)), Vector3(0.004, 0.02, 0.001), Palette.CARAMEL)
	# Hati.
	var c5: Vector2 = Vector2(0.10, -0.12)
	_photo(k, c5, Vector2(0.12, 0.13), Palette.CARAMEL, Palette.FLOUR_WHITE)
	k.m.polygon(_xf(_v(c5.x, c5.y - 0.004, -0.0092)), _heart_pts(0.03), Palette.ROSY_CHEEK, Vector3.FORWARD)


## Satu bingkai foto persegi di dinding: lis 4 sisi + latar foto.
static func _photo(k: Kit, c: Vector2, size: Vector2, frame_col: Color, back: Color) -> void:
	k.m.box(_xf(_v(c.x, c.y, -0.005)), Vector3(size.x - 0.02, size.y - 0.02, 0.006), back)
	_frame(k.m, _v(c.x, c.y, -0.009), size, 0.016, 0.018, frame_col)


## Lampu gantung hangat: siku besi hitam berulir, rantai pendek, kap tembaga, dan
## bola lampu yang menyala.
static func _hanging_lamp(k: Kit) -> void:
	var iron: Color = Palette.DARK_CHOCOLATE
	k.s.box(_xf(Vector3(0.0, 0.23, -0.008)), Vector3(0.07, 0.12, 0.016), iron)
	k.s.cylinder(_xf(Vector3(0.0, 0.25, -0.14), Vector3(90.0, 0.0, 0.0)), 0.26, 0.01, 0.01, iron, 8)
	k.s.torus(_xf(Vector3(0.0, 0.17, -0.08), Vector3(0.0, 0.0, 90.0)), 0.08, 0.006, iron, 12, 5, PI * 0.5, PI)
	k.s.torus(_xf(Vector3(0.0, 0.198, -0.16), Vector3(0.0, 0.0, 90.0)), 0.022, 0.005, iron, 10, 5, PI * 0.5, PI * 2.0)
	for i in 3:
		# Mata rantai tegak bergantian arah; skala memanjangkannya ke bawah.
		var rot: Vector3 = Vector3(90.0, 0.0, 0.0) if i % 2 == 0 else Vector3(0.0, 0.0, 90.0)
		var stretch: Vector3 = Vector3(1.0, 1.0, 1.4) if i % 2 == 0 else Vector3(1.4, 1.0, 1.0)
		k.s.torus(_xf(Vector3(0.0, 0.232 - float(i) * 0.02, -0.262), rot, stretch), 0.009, 0.0026, iron, 10, 4)
	var sc := Vector3(0.0, 0.17, -0.262)
	k.s.cylinder(_xf(sc + Vector3(0.0, 0.004, 0.0)), 0.02, 0.016, 0.016, GOLD, 10)
	var outer := PackedVector2Array([Vector2(0.012, 0.0), Vector2(0.03, -0.012), Vector2(0.06, -0.045), Vector2(0.085, -0.08),
		Vector2(0.095, -0.1), Vector2(0.097, -0.106)])
	k.s.lathe(_xf(sc), outer, EquipmentFactory.METAL_COPPER, 18)
	var inner := PackedVector2Array([Vector2(0.093, -0.106), Vector2(0.091, -0.1), Vector2(0.081, -0.08), Vector2(0.056, -0.045),
		Vector2(0.026, -0.012), Vector2(0.008, -0.002)])
	k.m.lathe(_xf(sc), inner, Palette.BUTTER_YELLOW, 18)
	k.s.torus(_xf(sc + Vector3(0.0, -0.106, 0.0)), 0.096, 0.004, GOLD, 18, 4)
	var bulb: MeshInstance3D = ProceduralMeshFactory.sphere(0.03, Palette.WARMER_LAMP.lightened(0.25))
	EquipmentFactory._set_glow(bulb, Palette.WARMER_LAMP, 1.8)
	bulb.name = "Bulb"
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	k.root.add_child(bulb)
	bulb.position = sc + Vector3(0.0, -0.1, 0.0)


## Plakat 100 roti: papan walnut, pelat perunggu dengan relief roti dan angka 100.
static func _plaque_hundred(k: Kit) -> void:
	_rounded_board(k.m, Vector3(0.0, 0.0, -0.012), Vector2(0.34, 0.27), 0.024, 0.03, WALNUT)
	_rounded_board(k.m, Vector3(0.0, 0.0, -0.029), Vector2(0.30, 0.23), 0.01, 0.022, WALNUT.lightened(0.12))
	k.s.box(_xf(Vector3(0.0, 0.0, -0.036)), Vector3(0.25, 0.18, 0.006), BRONZE)
	for su: float in [-1.0, 1.0]:
		for sv: float in [-1.0, 1.0]:
			k.s.ellipsoid(_xf(Vector3(su * 0.11, sv * 0.074, -0.04)), Vector3(0.007, 0.007, 0.004), BRONZE.darkened(0.3), 6, 3)
	k.m.ellipsoid(_xf(Vector3(0.0, 0.036, -0.042)), Vector3(0.056, 0.032, 0.012), Palette.GOLDEN_CRUST, 12, 6)
	k.m.ellipsoid(_xf(_v(-0.014, 0.046, -0.0525)), Vector3(0.018, 0.008, 0.003), Palette.BUTTER_YELLOW, 8, 3)
	for i in 5:
		var a: float = -0.8 + float(i) * 0.4
		k.m.box(_xf(Vector3(sin(a) * 0.03, 0.05 + cos(a) * 0.006, -0.054), Vector3(0.0, 0.0, rad_to_deg(a))), Vector3(0.004, 0.008, 0.002), Palette.FLOUR_WHITE)
	var ink: Color = BRONZE.darkened(0.35)
	k.s.box(_xf(_v(-0.052, -0.047, -0.041)), Vector3(0.012, 0.052, 0.006), ink)
	_seg(k.s, _v(-0.052, -0.023, -0.041), _v(-0.066, -0.033, -0.041), Vector2(0.01, 0.006), ink)
	for u: float in [-0.012, 0.036]:
		k.s.torus(_xf(_v(u, -0.047, -0.041), Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 1.4)), 0.016, 0.005, ink, 14, 5)


## Plakat bintang kenaikan tier: papan melengkung, pelat perak (atau emas dengan
## daun salam untuk Flagship), ikon toko, dan `stars` bintang di lengkungnya.
static func _plaque_stars(k: Kit, stars: int, gold: bool) -> void:
	var plate: Color = GOLD if gold else SILVER
	var ink: Color = plate.darkened(0.35)
	var board: Color = WALNUT.darkened(0.08) if gold else WALNUT
	k.m.box(_xf(Vector3(0.0, -0.03, -0.012)), Vector3(0.32, 0.22, 0.024), board)
	k.m.cylinder(_xf(Vector3(0.0, 0.07, -0.012), Vector3(90.0, 0.0, 0.0)), 0.024, 0.16, 0.16, board, 24)
	if gold:
		_frame(k.s, Vector3(0.0, -0.045, -0.026), Vector2(0.28, 0.17), 0.01, 0.006, GOLD)
	k.s.box(_xf(Vector3(0.0, -0.045, -0.027)), Vector3(0.23, 0.13, 0.006), plate)
	# Ikon toko: badan, atap, pintu, kerai bergaris.
	k.s.box(_xf(Vector3(0.0, -0.07, -0.0315)), Vector3(0.07, 0.045, 0.004), ink)
	k.s.polygon(_xf(Vector3(0.0, -0.047, -0.0335)), PackedVector2Array([Vector2(-0.048, 0.0), Vector2(0.048, 0.0), Vector2(0.0, 0.032)]), ink, Vector3.FORWARD)
	k.m.box(_xf(Vector3(0.0, -0.08, -0.034)), Vector3(0.016, 0.025, 0.002), Palette.FLOUR_WHITE)
	if gold:
		k.s.box(_xf(_v(0.03, -0.005, -0.032)), Vector3(0.004, 0.05, 0.003), ink)
		k.m.polygon(_xf(_v(0.03, 0.013, -0.0345)), PackedVector2Array([Vector2(0.0, -0.007), Vector2(0.0, 0.007), Vector2(-0.026, 0.0)]), Palette.DANGER, Vector3.FORWARD)
		for side: float in [-1.0, 1.0]:
			for i in 5:
				var a: float = deg_to_rad(205.0 + float(i) * 15.0)
				var p := Vector3(side * cos(a) * 0.125, -0.045 + sin(a) * 0.075, -0.034)
				k.s.ellipsoid(_xf(p, Vector3(0.0, 0.0, side * (rad_to_deg(a) + 90.0))), Vector3(0.009, 0.022, 0.004), GOLD.darkened(0.12), 6, 3)
	for i in stars:
		var u: float = (float(i) - float(stars - 1) * 0.5) * 0.06
		var v: float = 0.105 - absf(u) * 0.35
		k.m.polygon(_xf(_v(u, v, -0.0255)), _star_pts(0.024, 0.01), Palette.GOLD_STAR, Vector3.FORWARD)
	var ribbon: Color = Palette.PASTEL_PERIWINKLE if stars == 2 else (Palette.PASTEL_STRAWBERRY if stars == 3 else Palette.APRON_MAROON)
	for side: float in [-1.0, 1.0]:
		k.m.polygon(_xf(Vector3(side * 0.045, -0.155, -0.022)), PackedVector2Array([Vector2(-0.018, 0.02), Vector2(0.018, 0.02),
			Vector2(0.018, -0.03), Vector2(0.0, -0.018), Vector2(-0.018, -0.03)]), ribbon, Vector3.FORWARD)


## Foto bersama Pak Lurah: bingkai emas, Pak Lurah berpeci dan berbaju batik
## bersalaman dengan tukang roti bertopi koki, dan pita penghargaan.
static func _photo_pak_lurah(k: Kit) -> void:
	_frame(k.s, Vector3(0.0, 0.0, -0.014), Vector2(0.30, 0.36), 0.03, 0.028, GOLD.darkened(0.08))
	k.m.box(_xf(Vector3(0.0, 0.0, -0.004)), Vector3(0.25, 0.31, 0.008), Palette.VANILLA_CREAM)
	k.m.box(_xf(Vector3(0.0, 0.03, -0.0085)), Vector3(0.20, 0.20, 0.001), SKY)
	k.m.box(_xf(Vector3(0.0, -0.0975, -0.0085)), Vector3(0.20, 0.055, 0.001), Palette.PASTEL_MINT)
	var z: float = -0.0095
	# Pak Lurah (kiri penonton).
	var ul: float = -0.048
	k.m.polygon(_xf(_v(ul, -0.07, z)), _round_rect_pts(0.075, 0.085, 0.02, 3), Palette.CARAMEL, Vector3.FORWARD)
	for d: Vector2 in [Vector2(-0.018, -0.05), Vector2(0.018, -0.05), Vector2(0.0, -0.075), Vector2(-0.018, -0.095), Vector2(0.018, -0.095)]:
		k.m.polygon(_xf(_v(ul + d.x, d.y, z - 0.0004)), _diamond_pts(0.008), Palette.BUTTER_YELLOW, Vector3.FORWARD)
	k.m.ellipsoid(_xf(_v(ul, 0.0, -0.011)), Vector3(0.029, 0.031, 0.006), CharacterFactory.SKIN_MID, 10, 5)
	k.m.box(_xf(_v(ul, 0.033, -0.012)), Vector3(0.05, 0.02, 0.008), CharacterFactory.PECI_BLACK)
	k.m.box(_xf(_v(ul, -0.009, -0.0175)), Vector3(0.022, 0.005, 0.002), Palette.DARK_CHOCOLATE)
	# Tukang roti (kanan penonton).
	var ur: float = 0.05
	k.m.polygon(_xf(_v(ur, -0.07, z)), _round_rect_pts(0.07, 0.085, 0.02, 3), Palette.APRON_WHITE, Vector3.FORWARD)
	k.m.polygon(_xf(_v(ur, -0.078, z - 0.0004)), _round_rect_pts(0.044, 0.06, 0.012, 3), Palette.PASTEL_STRAWBERRY, Vector3.FORWARD)
	k.m.ellipsoid(_xf(_v(ur, 0.0, -0.011)), Vector3(0.028, 0.03, 0.006), CharacterFactory.SKIN_LIGHT, 10, 5)
	k.m.box(_xf(_v(ur, 0.028, -0.012)), Vector3(0.048, 0.012, 0.008), Palette.FLOUR_WHITE)
	k.m.ellipsoid(_xf(_v(ur, 0.048, -0.012)), Vector3(0.032, 0.022, 0.008), Palette.FLOUR_WHITE, 10, 5)
	for u: float in [ul, ur]:
		for s: float in [-1.0, 1.0]:
			k.m.box(_xf(_v(u + s * 0.01, 0.006, -0.0175)), Vector3(0.004, 0.006, 0.002), Palette.DARK_CHOCOLATE)
	k.m.ellipsoid(_xf(_v(0.001, -0.062, -0.012)), Vector3(0.014, 0.01, 0.006), CharacterFactory.SKIN_MID, 8, 4)
	# Pita penghargaan di sudut kanan atas.
	var rc: Vector3 = _v(0.125, 0.155, -0.032)
	k.m.cylinder(_xf(rc, Vector3(90.0, 0.0, 0.0)), 0.006, 0.03, 0.03, Palette.PASTEL_STRAWBERRY, 14)
	k.s.cylinder(_xf(rc + Vector3(0.0, 0.0, -0.004), Vector3(90.0, 0.0, 0.0)), 0.004, 0.016, 0.016, GOLD, 12)
	for s: float in [-1.0, 1.0]:
		k.m.polygon(_xf(rc + Vector3(s * 0.012, -0.035, 0.002)), PackedVector2Array([Vector2(-0.01, 0.02), Vector2(0.01, 0.02),
			Vector2(0.01, -0.02), Vector2(0.0, -0.012), Vector2(-0.01, -0.02)]), Palette.PASTEL_STRAWBERRY.darkened(0.12), Vector3.FORWARD)


## Plakat tak hingga: papan merah marun berbingkai emas dengan lambang tak
## hingga dari dua cincin dan kilau bintang.
static func _plaque_infinity(k: Kit) -> void:
	_rounded_board(k.m, Vector3(0.0, 0.0, -0.012), Vector2(0.36, 0.24), 0.024, 0.04, Palette.APRON_MAROON)
	_frame(k.s, Vector3(0.0, 0.0, -0.026), Vector2(0.33, 0.21), 0.012, 0.006, GOLD)
	for s: float in [-1.0, 1.0]:
		k.s.torus(_xf(Vector3(s * 0.047, 0.012, -0.036), Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.8)), 0.048, 0.012, GOLD, 22, 8)
	for p: Vector3 in [Vector3(0.125, 0.065, 0.024), Vector3(-0.13, 0.058, 0.018), Vector3(0.12, -0.06, 0.016), Vector3(-0.118, -0.062, 0.022)]:
		k.m.polygon(_xf(Vector3(p.x, p.y, -0.0255)), _star_pts(p.z, p.z * 0.3, 4), Palette.BUTTER_YELLOW, Vector3.FORWARD)
	k.s.box(_xf(Vector3(0.0, -0.075, -0.03)), Vector3(0.14, 0.012, 0.006), GOLD)


# ===========================================================================
# MEJA KASIR
# ===========================================================================

## Radio kaset antik: badan mint, dua pengeras suara berkisi krom, dek kaset,
## skala gelombang, tombol, pegangan, dan antena.
static func _cassette_radio(k: Kit) -> void:
	var chrome: Color = EquipmentFactory.METAL_CHROME
	k.m.box(_xf(Vector3(0.0, 0.064, 0.0)), Vector3(0.24, 0.11, 0.07), Palette.PASTEL_MINT)
	k.m.box(_xf(Vector3(0.0, 0.122, 0.0)), Vector3(0.242, 0.012, 0.072), Palette.FLOUR_WHITE)
	k.m.box(_xf(Vector3(0.0, 0.005, 0.0)), Vector3(0.22, 0.01, 0.06), Palette.DARK_CHOCOLATE)
	for s: float in [-1.0, 1.0]:
		var c := Vector3(s * 0.076, 0.06, -0.035)
		k.m.cylinder(_xf(c, Vector3(90.0, 0.0, 0.0)), 0.006, 0.036, 0.036, EquipmentFactory.DARK_GLASS, 16)
		k.s.torus(_xf(c + Vector3(0.0, 0.0, -0.004), Vector3(90.0, 0.0, 0.0)), 0.034, 0.003, chrome, 16, 4)
		k.s.torus(_xf(c + Vector3(0.0, 0.0, -0.004), Vector3(90.0, 0.0, 0.0)), 0.02, 0.0025, chrome, 12, 4)
		k.s.ellipsoid(_xf(c + Vector3(0.0, 0.0, -0.004)), Vector3(0.008, 0.008, 0.004), chrome, 8, 4)
	k.m.box(_xf(Vector3(0.0, 0.056, -0.0365)), Vector3(0.068, 0.05, 0.003), Palette.DARK_CHOCOLATE)
	k.m.box(_xf(Vector3(0.0, 0.058, -0.0385)), Vector3(0.05, 0.022, 0.002), Palette.VANILLA_CREAM)
	for s2: float in [-1.0, 1.0]:
		k.m.torus(_xf(Vector3(s2 * 0.013, 0.058, -0.04), Vector3(90.0, 0.0, 0.0)), 0.006, 0.0025, Palette.DARK_CHOCOLATE, 10, 4)
	k.m.box(_xf(Vector3(0.0, 0.1, -0.0365)), Vector3(0.1, 0.014, 0.003), Palette.BUTTER_YELLOW)
	k.m.box(_xf(_v(0.012, 0.1, -0.0385)), Vector3(0.003, 0.014, 0.002), Palette.DANGER)
	for i in 5:
		k.s.box(_xf(Vector3(-0.04 + float(i) * 0.02, 0.131, 0.012)), Vector3(0.014, 0.008, 0.018), chrome)
	k.s.torus(_xf(Vector3(0.0, 0.126, 0.0), Vector3(90.0, 0.0, 0.0), Vector3(1.0, 1.0, 0.55)), 0.085, 0.006, chrome, 16, 6, -PI * 0.5, PI * 0.5)
	k.s.cylinder(_xf(_v(0.066 + sin(deg_to_rad(25.0)) * 0.08, 0.128 + cos(deg_to_rad(25.0)) * 0.08, 0.02), Vector3(0.0, 0.0, 25.0)), 0.16, 0.0025, 0.003, chrome, 6)
	k.s.ellipsoid(_xf(_v(0.066 + sin(deg_to_rad(25.0)) * 0.16, 0.128 + cos(deg_to_rad(25.0)) * 0.16, 0.02)), Vector3(0.006, 0.006, 0.006), chrome, 6, 4)


## Toples koin emas: tumpukan koin di balik kaca bening, tutup karamel berpita,
## dan dua koin tercecer di meja.
static func _coin_jar(k: Kit) -> void:
	k.s.cylinder(_xf(Vector3(0.0, 0.036, 0.0)), 0.064, 0.044, 0.044, GOLD, 14)
	k.s.ellipsoid(_xf(Vector3(0.0, 0.068, 0.0)), Vector3(0.044, 0.018, 0.044), GOLD, 14, 5)
	for c: Array in [[Vector3(0.012, 0.086, -0.01), Vector3(25.0, 0.0, 10.0)], [Vector3(-0.016, 0.083, 0.008), Vector3(-15.0, 30.0, -20.0)],
			[Vector3(0.0, 0.088, 0.018), Vector3(35.0, 60.0, 0.0)], [Vector3(-0.012, 0.084, -0.016), Vector3(-30.0, 0.0, 15.0)]]:
		k.s.cylinder(_xf(c[0], c[1]), 0.004, 0.015, 0.015, GOLD.lightened(0.12), 10)
	var g := MeshBuilder.new()
	g.lathe(_xf(Vector3.ZERO), PackedVector2Array([Vector2(0.0, 0.002), Vector2(0.05, 0.002), Vector2(0.053, 0.012), Vector2(0.053, 0.10),
		Vector2(0.046, 0.114), Vector2(0.037, 0.12), Vector2(0.037, 0.13)]), GLASS, 16)
	var glass: MeshInstance3D = g.commit("Glass")
	glass.material_override = _glass_material()
	k.root.add_child(glass)
	k.m.cylinder(_xf(Vector3(0.0, 0.139, 0.0)), 0.018, 0.042, 0.042, Palette.CARAMEL, 16)
	k.s.ellipsoid(_xf(Vector3(0.0, 0.153, 0.0)), Vector3(0.012, 0.01, 0.012), GOLD, 8, 4)
	k.m.torus(_xf(Vector3(0.0, 0.122, 0.0)), 0.04, 0.004, Palette.PASTEL_STRAWBERRY, 16, 4)
	k.s.cylinder(_xf(_v(0.075, 0.002, -0.02)), 0.004, 0.016, 0.016, GOLD, 10)
	k.s.cylinder(_xf(_v(0.07, 0.01, 0.006), Vector3(20.0, 0.0, 12.0)), 0.004, 0.016, 0.016, GOLD, 10)


## Piala jutawan kecil: alas walnut berpelat emas, cawan emas bergagang dua, dan
## bintang merah di mukanya.
static func _trophy_small(k: Kit) -> void:
	k.m.box(_xf(Vector3(0.0, 0.015, 0.0)), Vector3(0.10, 0.03, 0.08), WALNUT)
	k.m.box(_xf(Vector3(0.0, 0.036, 0.0)), Vector3(0.075, 0.012, 0.06), WALNUT.lightened(0.1))
	k.s.box(_xf(Vector3(0.0, 0.016, -0.041)), Vector3(0.06, 0.016, 0.003), GOLD)
	_cup(k.s, Vector3(0.0, 0.042, 0.0), 1.0)
	k.m.polygon(_xf(Vector3(0.0, 0.126, -0.046), Vector3(-6.0, 0.0, 0.0)), _star_pts(0.017, 0.007), Palette.DANGER, Vector3.FORWARD)


## Kalkulator retro: badan krem miring, layar LCD, panel surya, dan tombol
## warna-warni menghadap pembeli.
static func _calculator(k: Kit) -> void:
	var tilt := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-8.0)), Vector3(0.0, 0.017, 0.0))
	k.m.box(tilt * _xf(Vector3.ZERO), Vector3(0.12, 0.02, 0.16), Palette.VANILLA_CREAM.darkened(0.06))
	k.m.box(tilt * _xf(Vector3(0.0, -0.004, 0.0)), Vector3(0.124, 0.012, 0.164), Palette.UI_WOOD)
	k.m.box(tilt * _xf(Vector3(0.0, 0.0105, 0.047)), Vector3(0.1, 0.002, 0.05), Palette.DARK_CHOCOLATE)
	k.m.box(tilt * _xf(Vector3(0.0, 0.0115, 0.043)), Vector3(0.084, 0.002, 0.028), LCD)
	for i in 3:
		k.m.box(tilt * _xf(Vector3(0.024 - float(i) * 0.016, 0.0125, 0.043)), Vector3(0.009, 0.001, 0.016), LCD.darkened(0.45))
	k.m.box(tilt * _xf(_v(0.022, 0.0115, 0.066)), Vector3(0.04, 0.002, 0.01), Palette.DARK_CHOCOLATE.lightened(0.1))
	for r in 5:
		for c in 4:
			var col: Color = Palette.FLOUR_WHITE
			if c == 3:
				col = Palette.APRON_ORANGE_PASTEL
			if r == 0 and c == 3:
				col = Palette.BUTTER_YELLOW
			if r == 4 and c == 0:
				col = Palette.PASTEL_STRAWBERRY
			var p: Vector3 = _v(-0.039 + float(c) * 0.026, 0.013, -0.066 + float(r) * 0.019)
			k.m.box(tilt * _xf(p), Vector3(0.018, 0.006, 0.013), col)


## Bel toko kuningan: alas kayu bulat, kubah kuningan, dan tombol pemukul.
static func _brass_bell(k: Kit) -> void:
	k.m.cylinder(_xf(Vector3(0.0, 0.008, 0.0)), 0.016, 0.046, 0.05, WALNUT, 16)
	k.s.torus(_xf(Vector3(0.0, 0.016, 0.0)), 0.041, 0.003, BRASS, 16, 4)
	k.s.lathe(_xf(Vector3(0.0, 0.016, 0.0)), PackedVector2Array([Vector2(0.04, 0.0), Vector2(0.04, 0.006), Vector2(0.036, 0.022),
		Vector2(0.028, 0.034), Vector2(0.016, 0.042), Vector2(0.0, 0.045)]), BRASS, 16)
	k.s.cylinder(_xf(Vector3(0.0, 0.066, 0.0)), 0.012, 0.004, 0.004, BRASS.darkened(0.2), 8)
	k.s.ellipsoid(_xf(Vector3(0.0, 0.074, 0.0)), Vector3(0.009, 0.006, 0.009), BRASS.darkened(0.1), 8, 4)


# ===========================================================================
# LANTAI
# ===========================================================================

## Tanaman pot: pot terakota berbibir, daun lebat melengkung, dan tiga bunga
## lili putih.
static func _potted_plant(k: Kit) -> void:
	var pot := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.09, 0.0), Vector2(0.1, 0.012), Vector2(0.125, 0.2),
		Vector2(0.14, 0.205), Vector2(0.14, 0.24), Vector2(0.125, 0.245)])
	var rim: Color = Palette.TERRACOTTA.lightened(0.12)
	k.m.lathe(_xf(Vector3.ZERO), pot, Palette.TERRACOTTA, 16, func(y: float, _phi: float) -> Color:
		return rim if y > 0.202 else Palette.TERRACOTTA)
	k.m.cylinder(_xf(Vector3(0.0, 0.236, 0.0)), 0.01, 0.124, 0.124, Palette.DARK_CHOCOLATE, 16)
	var base := Vector3(0.0, 0.24, 0.0)
	for i in 11:
		var a: float = TAU * float(i) / 11.0 + (0.25 if i % 2 == 1 else 0.0)
		var e: float = deg_to_rad(34.0 + float(i % 3) * 14.0)
		var dir := Vector3(sin(a) * cos(e), sin(e), -cos(a) * cos(e))
		var length: float = 0.17 + float(i % 4) * 0.018
		_leaf(k.m, base + dir * (length * 0.55), dir, Vector3(0.05, length * 0.5, 0.012), LEAF if i % 2 == 0 else LEAF_DARK)
	for j in 3:
		var a2: float = TAU * float(j) / 3.0 + 0.5
		var dir2 := Vector3(sin(a2) * 0.25, 1.0, -cos(a2) * 0.25).normalized()
		_leaf(k.m, base + dir2 * 0.12, dir2, Vector3(0.04, 0.12, 0.01), LEAF)
	for j2 in 3:
		var a3: float = TAU * float(j2) / 3.0 + 1.6
		var top := base + Vector3(sin(a3) * 0.07, 0.26 + float(j2) * 0.03, -cos(a3) * 0.07)
		k.m.capsule(base + Vector3(sin(a3) * 0.02, 0.0, -cos(a3) * 0.02), top, 0.005, 0.004, LEAF_DARK, 5, 1)
		_leaf(k.m, top + Vector3(0.0, 0.035, 0.0), Vector3(sin(a3) * 0.3, 1.0, -cos(a3) * 0.3).normalized(), Vector3(0.028, 0.05, 0.01), Palette.FLOUR_WHITE)
		k.m.capsule(top + Vector3(0.0, 0.01, 0.0), top + Vector3(0.0, 0.05, 0.0), 0.007, 0.005, Palette.BUTTER_YELLOW, 5, 1)


## Keranjang roti bertingkat: rak pinus dua susun, masing-masing dengan keranjang
## rotan berisi roti bundar, baguette, dan roti gulung.
static func _basket_stand(k: Kit) -> void:
	var wood: Color = Palette.PINE_WOOD
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			k.m.box(_xf(Vector3(sx * 0.18, 0.29, sz * 0.15)), Vector3(0.026, 0.58, 0.026), wood)
		k.m.box(_xf(Vector3(0.0, 0.57, sx * 0.15)), Vector3(0.39, 0.02, 0.022), Palette.CARAMEL)
	for y: float in [0.1, 0.34]:
		k.m.box(_xf(Vector3(0.0, y, 0.0)), Vector3(0.40, 0.018, 0.34), Palette.CARAMEL)
	_basket(k.m, Vector3(0.0, 0.109, 0.0), 0.13)
	for b: Vector3 in [Vector3(-0.05, 0.19, -0.03), Vector3(0.05, 0.19, -0.03), Vector3(0.0, 0.19, 0.04), Vector3(-0.07, 0.185, 0.045), Vector3(0.075, 0.185, 0.04)]:
		k.m.ellipsoid(_xf(b), Vector3(0.045, 0.03, 0.04), Palette.GOLDEN_CRUST, 8, 5)
	_basket(k.m, Vector3(0.0, 0.349, 0.0), 0.13)
	for s: float in [-1.0, 1.0]:
		k.m.capsule(Vector3(s * -0.12, 0.40, 0.05), Vector3(s * 0.13, 0.45, -0.07), 0.022, 0.02, Palette.GOLDEN_CRUST, 8, 2)
	for r: Vector3 in [Vector3(-0.06, 0.425, 0.06), Vector3(0.07, 0.42, 0.055)]:
		k.m.ellipsoid(_xf(r), Vector3(0.035, 0.024, 0.03), Palette.GOLDEN_CRUST.darkened(0.08), 8, 4)


## Keranjang rotan lonjong di `pos` (alas), jari-jari bibir `r`: anyaman kotak-
## kotak dari warna verteks, bibir tebal, dan kain gingham di dalamnya.
static func _basket(mb: MeshBuilder, pos: Vector3, r: float) -> void:
	var prof := PackedVector2Array()
	for i in 6:
		var t: float = float(i) / 5.0
		prof.append(Vector2(lerpf(r * 0.76, r, t), t * 0.075))
	var xf: Transform3D = _xf(pos, Vector3.ZERO, Vector3(1.25, 1.0, 1.0))
	var dark: Color = WICKER.darkened(0.16)
	mb.lathe(xf, prof, WICKER, 14, func(y: float, phi: float) -> Color:
		var row: int = int(round(y / 0.015))
		var col: int = int(round(phi / (TAU / 14.0)))
		return WICKER if (row + col) % 2 == 0 else dark)
	mb.torus(_xf(pos + Vector3(0.0, 0.076, 0.0), Vector3.ZERO, Vector3(1.25, 1.0, 1.0)), r, 0.011, WICKER.lightened(0.05), 16, 5)
	mb.cylinder(_xf(pos + Vector3(0.0, 0.03, 0.0), Vector3.ZERO, Vector3(1.25, 1.0, 1.0)), 0.004, r * 0.86, r * 0.86, Palette.GINGHAM_A, 14)


## Piala Landmark: alas marmer krem berlis emas dengan pelat bintang, dan piala
## emas besar bergagang dengan bintang di puncaknya.
static func _trophy_large(k: Kit) -> void:
	k.m.box(_xf(Vector3(0.0, 0.2, 0.0)), Vector3(0.30, 0.37, 0.30), Palette.VANILLA_CREAM)
	for y: float in [0.015, 0.385]:
		k.s.box(_xf(Vector3(0.0, y, 0.0)), Vector3(0.32, 0.03, 0.32), GOLD)
	k.s.box(_xf(Vector3(0.0, 0.22, -0.152)), Vector3(0.15, 0.08, 0.006), GOLD)
	k.m.polygon(_xf(Vector3(0.0, 0.22, -0.1555)), _star_pts(0.03, 0.013), Palette.DANGER, Vector3.FORWARD)
	k.m.box(_xf(Vector3(0.0, 0.42, 0.0)), Vector3(0.17, 0.04, 0.17), WALNUT)
	var cup_base := Vector3(0.0, 0.44, 0.0)
	_cup(k.s, cup_base, 2.3)
	var top_y: float = 0.44 + 0.1 * 2.3
	k.s.cylinder(_xf(Vector3(0.0, top_y + 0.03, 0.0)), 0.06, 0.006, 0.006, GOLD, 8)
	for s: float in [1.0, -1.0]:
		k.m.polygon(_xf(Vector3(0.0, top_y + 0.085, s * 0.004)), _star_pts(0.05, 0.022), Palette.GOLD_STAR, Vector3(0.0, 0.0, s))


## Tempat payung: tabung keramik periwinkle bergaris dengan tiga payung tertutup
## bergagang kayu.
static func _umbrella_stand(k: Kit) -> void:
	var stand := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.1, 0.0), Vector2(0.105, 0.015), Vector2(0.1, 0.1),
		Vector2(0.1, 0.13), Vector2(0.1, 0.16), Vector2(0.1, 0.25), Vector2(0.1, 0.28), Vector2(0.108, 0.34)])
	k.m.lathe(_xf(Vector3.ZERO), stand, Palette.PASTEL_PERIWINKLE, 16, func(y: float, _phi: float) -> Color:
		return Palette.FLOUR_WHITE if (y > 0.12 and y < 0.17) or (y > 0.24 and y < 0.29) else Palette.PASTEL_PERIWINKLE)
	k.m.torus(_xf(Vector3(0.0, 0.342, 0.0)), 0.104, 0.008, Palette.FLOUR_WHITE, 16, 5)
	k.m.cylinder(_xf(Vector3(0.0, 0.3, 0.0)), 0.004, 0.098, 0.098, Palette.DARK_CHOCOLATE.darkened(0.2), 14)
	var umbrellas: Array = [
		[Palette.RAINCOAT_YELLOW, Palette.RAINCOAT_YELLOW.darkened(0.08), Vector3(-7.0, 0.0, 6.0), Vector3(0.03, 0.03, 0.02), 0.78],
		[Palette.PASTEL_STRAWBERRY, Palette.FLOUR_WHITE, Vector3(6.0, 0.0, -9.0), Vector3(-0.035, 0.03, 0.0), 0.74],
		[Palette.APRON_NAVY, Palette.APRON_NAVY.lightened(0.12), Vector3(-3.0, 40.0, -2.0), Vector3(0.0, 0.03, -0.04), 0.82],
	]
	for u: Array in umbrellas:
		var rot: Vector3 = u[2]
		var xf := Transform3D(Basis.from_euler(Vector3(deg_to_rad(rot.x), deg_to_rad(rot.y), deg_to_rad(rot.z))), u[3])
		var length: float = u[4]
		var ca: Color = u[0]
		var cb: Color = u[1]
		k.m.cylinder(xf * _xf(Vector3(0.0, length * 0.5, 0.0)), length, 0.006, 0.006, Palette.DARK_CHOCOLATE, 6, false, false)
		var prof := PackedVector2Array([Vector2(0.004, 0.08), Vector2(0.03, 0.2), Vector2(0.036, 0.3), Vector2(0.03, 0.48),
			Vector2(0.014, 0.58), Vector2(0.007, 0.62)])
		k.m.lathe(xf, prof, ca, 8, func(_y: float, phi: float) -> Color:
			return ca if int(round(phi / (TAU / 8.0))) % 2 == 0 else cb)
		k.m.torus(xf * _xf(Vector3(0.0, 0.42, 0.0)), 0.029, 0.004, ca.darkened(0.25), 12, 4)
		k.m.torus(xf * _xf(Vector3(0.03, length, 0.0), Vector3(90.0, 0.0, 0.0)), 0.03, 0.008, Palette.CARAMEL, 12, 6, -PI * 0.5, PI)


# ===========================================================================
# KARPET
# ===========================================================================

## Karpet terakota: dasar merah bata, pinggiran krem, garis cokelat, medali
## wajik di tengah, segitiga sudut, dan rumbai di kedua ujung pendek.
static func _terracotta_rug(k: Kit, size: Vector2) -> void:
	var sx: float = size.x - 0.06
	var sz: float = size.y - 0.06
	k.m.box(_xf(Vector3(0.0, 0.003, 0.0)), Vector3(sx, 0.006, sz), BRICK)
	var band: float = 0.055
	_floor_frame(k.m, sx, sz, band, 0.0068, Palette.VANILLA_CREAM)
	_floor_frame(k.m, sx - band * 2.0 - 0.03, sz - band * 2.0 - 0.03, 0.012, 0.0076, Palette.DARK_CHOCOLATE)
	var m: float = minf(sx, sz)
	k.m.polygon(_flat(Vector3(0.0, 0.0076, 0.0)), _diamond_pts(m * 0.2), Palette.CUSTARD, Vector3.BACK)
	k.m.polygon(_flat(Vector3(0.0, 0.0084, 0.0)), _diamond_pts(m * 0.12), BRICK.lightened(0.08), Vector3.BACK)
	k.m.polygon(_flat(Vector3(0.0, 0.0092, 0.0)), _diamond_pts(m * 0.045), Palette.FLOUR_WHITE, Vector3.BACK)
	var ix: float = sx * 0.5 - band - 0.05
	var iz: float = sz * 0.5 - band - 0.05
	for cx: float in [-1.0, 1.0]:
		for cz: float in [-1.0, 1.0]:
			var tri := PackedVector2Array([Vector2(0.0, 0.0), Vector2(-cx * 0.09, 0.0), Vector2(0.0, cz * 0.09)])
			k.m.polygon(_flat(Vector3(cx * ix, 0.0076, cz * iz)), tri, Palette.CUSTARD, Vector3.BACK)
	var n: int = int(sz / 0.05)
	for side: float in [-1.0, 1.0]:
		for i in n:
			var z: float = -sz * 0.5 + (float(i) + 0.5) * sz / float(n)
			k.m.box(_xf(Vector3(side * (sx * 0.5 + 0.016), 0.0015, z)), Vector3(0.032, 0.003, 0.01), Palette.FLOUR_WHITE)


## Keset antrean: karet mint berlis hijau dengan tiga panah chevron putih
## sepanjang sisi panjang.
static func _floor_mat(k: Kit, size: Vector2) -> void:
	var sx: float = size.x - 0.06
	var sz: float = size.y - 0.06
	k.m.box(_xf(Vector3(0.0, 0.003, 0.0)), Vector3(sx, 0.006, sz), Palette.PASTEL_MINT.darkened(0.06))
	_floor_frame(k.m, sx, sz, 0.03, 0.0068, Palette.OJOL_GREEN)
	var long_x: bool = sx >= sz
	var span: float = maxf(sx, sz)
	var arm: float = minf(sx, sz) * 0.28
	for i in 3:
		var t: float = (float(i) - 1.0) * span * 0.26
		for s: float in [-1.0, 1.0]:
			var ang: float = deg_to_rad(40.0) * s
			var off := Vector2(-arm * 0.35, s * arm * 0.42)
			var p := Vector3(t + off.x, 0.0078, off.y) if long_x else Vector3(off.y, 0.0078, t + off.x)
			var yaw: float = ang if long_x else ang - PI * 0.5
			var xf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5), p)
			k.m.polygon(xf, _rect_pts(arm * 1.1, 0.026), Palette.FLOUR_WHITE, Vector3.BACK)


# ===========================================================================
# BAGIAN BERSAMA
# ===========================================================================

## Cawan piala emas bergagang dua di `base` (alas cawan), skala `s` (1 = piala meja).
static func _cup(mb: MeshBuilder, base: Vector3, s: float) -> void:
	var prof := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.024, 0.0), Vector2(0.024, 0.006), Vector2(0.01, 0.014),
		Vector2(0.007, 0.03), Vector2(0.01, 0.04), Vector2(0.016, 0.046), Vector2(0.034, 0.058), Vector2(0.042, 0.08),
		Vector2(0.044, 0.1), Vector2(0.04, 0.1)])
	for i in prof.size():
		prof[i] = prof[i] * s
	mb.lathe(_xf(base), prof, GOLD, 16)
	mb.cylinder(_xf(base + Vector3(0.0, 0.097 * s, 0.0)), 0.002 * s, 0.04 * s, 0.04 * s, GOLD.darkened(0.3), 14)
	for side: float in [-1.0, 1.0]:
		var a0: float = 0.0 if side > 0.0 else PI
		mb.torus(_xf(base + Vector3(side * 0.044 * s, 0.076 * s, 0.0), Vector3(90.0, 0.0, 0.0)), 0.018 * s, 0.005 * s, GOLD, 10, 5, a0, a0 + PI)


## Papan bersudut bulat di bidang dinding: tiga kotak + empat silinder sudut.
static func _rounded_board(mb: MeshBuilder, c: Vector3, size: Vector2, depth: float, r: float, color: Color) -> void:
	mb.box(_xf(c), Vector3(size.x - r * 2.0, size.y, depth), color)
	for s: float in [-1.0, 1.0]:
		mb.box(_xf(c + Vector3(s * (size.x * 0.5 - r * 0.5), 0.0, 0.0)), Vector3(r, size.y - r * 2.0, depth), color)
		for t: float in [-1.0, 1.0]:
			mb.cylinder(_xf(c + Vector3(s * (size.x * 0.5 - r), t * (size.y * 0.5 - r), 0.0), Vector3(90.0, 0.0, 0.0)), depth, r, r, color, 8)


## Bingkai persegi empat lis di bidang dinding (pusat c, ukuran luar size).
static func _frame(mb: MeshBuilder, c: Vector3, size: Vector2, b: float, d: float, color: Color) -> void:
	for s: float in [-1.0, 1.0]:
		mb.box(_xf(c + Vector3(0.0, s * (size.y - b) * 0.5, 0.0)), Vector3(size.x, b, d), color)
		mb.box(_xf(c + Vector3(s * (size.x - b) * 0.5, 0.0, 0.0)), Vector3(b, size.y - b * 2.0, d), color)


## Bingkai datar di lantai (bidang XZ menghadap +Y), pusat di titik asal.
static func _floor_frame(mb: MeshBuilder, sx: float, sz: float, b: float, y: float, color: Color) -> void:
	for s: float in [-1.0, 1.0]:
		mb.polygon(_flat(Vector3(0.0, y, s * (sz - b) * 0.5)), _rect_pts(sx, b), color, Vector3.BACK)
		mb.polygon(_flat(Vector3(s * (sx - b) * 0.5, y, 0.0)), _rect_pts(b, sz - b * 2.0), color, Vector3.BACK)


## Batang kotak dari a ke b (tebal thick.x di bidangnya, thick.y ke samping).
static func _seg(mb: MeshBuilder, a: Vector3, b: Vector3, thick: Vector2, color: Color) -> void:
	var d: Vector3 = b - a
	if d.length() < 0.0001:
		return
	mb.box(Transform3D(MeshBuilder.frame_y(d / d.length()), (a + b) * 0.5), Vector3(thick.x, d.length(), thick.y), color)


## Daun elipsoid sepanjang `dir` dengan sisi pipihnya menghadap ke atas.
static func _leaf(mb: MeshBuilder, center: Vector3, dir: Vector3, radii: Vector3, color: Color) -> void:
	var y: Vector3 = dir.normalized()
	var x: Vector3 = Vector3.UP.cross(y)
	if x.length() < 0.01:
		x = Vector3.RIGHT
	x = x.normalized()
	var z: Vector3 = x.cross(y).normalized()
	mb.ellipsoid(Transform3D(Basis(x, y, z), center), radii, color, 6, 5)


## Transform posisi + rotasi (derajat) + skala lokal (diterapkan sebelum rotasi).
static func _xf(p: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> Transform3D:
	var b := Basis.from_euler(Vector3(deg_to_rad(rot_deg.x), deg_to_rad(rot_deg.y), deg_to_rad(rot_deg.z)))
	return Transform3D(Basis(b.x * scl.x, b.y * scl.y, b.z * scl.z), p)


## Transform poligon datar di lantai: bidang XY lokal dipetakan ke XZ dunia.
static func _flat(p: Vector3) -> Transform3D:
	return Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), p)


## Titik di bidang dinding dengan u ke KANAN penonton (= -X lokal).
static func _v(u: float, v: float, z: float) -> Vector3:
	return Vector3(-u, v, z)


static func _rect_pts(w: float, h: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)])


static func _oval_pts(rx: float, ry: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## Busur cembung dari sudut a0 ke a1 (radian, 0 = kanan, berlawanan jarum jam).
static func _arc_pts(r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	return pts


static func _round_rect_pts(w: float, h: float, r: float, seg: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var cs: Array[Vector2] = [Vector2(w * 0.5 - r, h * 0.5 - r), Vector2(-w * 0.5 + r, h * 0.5 - r),
		Vector2(-w * 0.5 + r, -h * 0.5 + r), Vector2(w * 0.5 - r, -h * 0.5 + r)]
	for q in 4:
		for i in seg + 1:
			var a: float = PI * 0.5 * (float(q) + float(i) / float(seg))
			pts.append(cs[q] + Vector2(cos(a), sin(a)) * r)
	return pts


static func _star_pts(r_out: float, r_in: float, points: int = 5) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in points * 2:
		var a: float = PI * float(i) / float(points)
		var r: float = r_out if i % 2 == 0 else r_in
		pts.append(Vector2(sin(a) * r, cos(a) * r))
	return pts


static func _diamond_pts(r: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(0.0, r), Vector2(r * 0.8, 0.0), Vector2(0.0, -r), Vector2(-r * 0.8, 0.0)])


## Bunga berkelopak `petals` (poligon berbentuk bintang terhadap pusatnya).
static func _flower_pts(r: float, petals: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var n: int = petals * 4
	for i in n:
		var a: float = TAU * float(i) / float(n)
		pts.append(Vector2(sin(a), cos(a)) * r * (0.45 + 0.55 * absf(cos(a * float(petals) * 0.5))))
	return pts


## Hati: dua lengkung atas dan ujung bawah, bintang terhadap pusatnya.
static func _heart_pts(s: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var t: float = TAU * float(i) / 20.0
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		pts.append(Vector2(x, y + 2.0) * (s / 16.0))
	return pts


static func _glass_material() -> StandardMaterial3D:
	if _glass_mat == null:
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.vertex_color_is_srgb = true
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.12
		m.metallic_specular = 0.9
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_glass_mat = m
	return _glass_mat


## Dua MeshBuilder (matte & satin) untuk satu model; `done()` memasang keduanya.
class Kit:
	var root: Node3D
	var m := MeshBuilder.new()
	var s := MeshBuilder.new()

	func _init(node_name: String) -> void:
		root = Node3D.new()
		root.name = node_name

	func done() -> Node3D:
		if not m.is_empty():
			root.add_child(m.commit("Matte", MeshBuilder.MATTE))
		if not s.is_empty():
			root.add_child(s.commit("Satin", MeshBuilder.SATIN))
		return root
