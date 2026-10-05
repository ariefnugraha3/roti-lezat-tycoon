class_name CritterFactory
extends RefCounted
## Model & pose prosedural untuk kejutan kosmetik toko (keputusan maintainer
## 2026-10-04, GDD 31.9): kucing oren, burung pipit, kupu-kupu, maskot roti
## berkostum, ukulele pengamen, hati, dan remah roti. Seperti karakter chibi,
## setiap bagian yang bergerak adalah pivot Node3D berisi satu mesh gabungan
## MeshBuilder berwarna verteks, jadi semuanya memakai material bersama yang
## sudah ada (tanpa kombinasi shader baru). Hadap depan = -Z.

const ORANGE: Color = Color(0.937, 0.596, 0.275)
const ORANGE_DEEP: Color = Color(0.835, 0.471, 0.188)
const CREAM: Color = Color(0.996, 0.945, 0.851)
const PINK: Color = Color(0.976, 0.651, 0.678)
const EYE: Color = Color(0.180, 0.110, 0.070)
const SPARROW_BROWN: Color = Color(0.612, 0.420, 0.259)
const SPARROW_CAP: Color = Color(0.478, 0.302, 0.176)
const BEAK: Color = Color(0.937, 0.643, 0.255)

static var _heart_mesh: ArrayMesh = null
static var _crumb_mesh: ArrayMesh = null


static func clear_caches() -> void:
	_heart_mesh = null
	_crumb_mesh = null


static func _piece(parent: Node3D, node_name: String, pos: Vector3, build: Callable) -> Node3D:
	var pivot := Node3D.new()
	pivot.name = node_name
	pivot.position = pos
	parent.add_child(pivot)
	var mb := MeshBuilder.new()
	build.call(mb)
	if not mb.is_empty():
		pivot.add_child(mb.commit(node_name + "Mesh"))
	return pivot


# ===========================================================================
# KUCING OREN
# ===========================================================================

## Kucing oren chibi bermotif belang, berperut dan berkaus kaki krem, bertelinga
## merah muda. Tinggi sampai ujung telinga sekitar 0,38 m.
static func cat() -> Node3D:
	var root := Node3D.new()
	root.name = "Cat"
	var body: Node3D = _piece(root, "Body", Vector3(0.0, 0.14, 0.03), func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Transform3D(), Vector3(0.080, 0.072, 0.125), ORANGE, 12, 8, func(u: Vector3) -> Color:
			if u.y < -0.35:
				return CREAM
			if u.y > 0.25 and sin(u.z * 13.0) > 0.55:
				return ORANGE_DEEP
			return ORANGE))
	for leg: Array in [["LegFL", -0.045, -0.075], ["LegFR", 0.045, -0.075], ["LegBL", -0.050, 0.085], ["LegBR", 0.050, 0.085]]:
		_piece(body, str(leg[0]), Vector3(float(leg[1]), -0.035, float(leg[2])), func(mb: MeshBuilder) -> void:
			mb.capsule(Vector3.ZERO, Vector3(0.0, -0.085, 0.0), 0.024, 0.022, ORANGE, 8, 2, func(f: float) -> Color:
				return CREAM if f > 0.78 else ORANGE))
	_piece(body, "Tail", Vector3(0.0, 0.03, 0.12), func(mb: MeshBuilder) -> void:
		mb.capsule(Vector3.ZERO, Vector3(0.0, 0.12, 0.07), 0.022, 0.017, ORANGE, 8, 2, func(f: float) -> Color:
			return CREAM if f > 0.86 else (ORANGE_DEEP if fposmod(f * 4.0, 1.0) < 0.3 else ORANGE)))
	_piece(root, "Head", Vector3(0.0, 0.225, -0.105), func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Transform3D(), Vector3(0.088, 0.078, 0.080), ORANGE, 12, 8, func(u: Vector3) -> Color:
			if u.z < -0.55 and u.y < 0.05:
				return CREAM
			if u.y > 0.55 and absf(u.x) < 0.18:
				return ORANGE_DEEP
			return ORANGE)
		for side: float in [-1.0, 1.0]:
			var ear := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), -0.38 * side), Vector3(0.052 * side, 0.066, 0.0))
			mb.ellipsoid(ear, Vector3(0.028, 0.044, 0.014), ORANGE, 8, 4, func(u: Vector3) -> Color:
				return PINK if u.z < -0.2 and u.y < 0.6 else ORANGE)
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.032 * side, 0.010, -0.072)), Vector3(0.012, 0.017, 0.008), EYE, 8, 4)
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.036 * side, 0.016, -0.078)), Vector3(0.0035, 0.004, 0.003), CREAM, 6, 3)
		mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -0.012, -0.082)), Vector3(0.010, 0.007, 0.006), PINK, 8, 4))
	root.scale = Vector3.ONE * 1.2
	return root


## Kucing berjalan: kaki diagonal berpasangan, badan dan kepala sedikit memantul.
## `phase` maju terus selama berjalan; `w` 0..1 membaurkan ke diam.
static func cat_walk(cat_node: Node3D, phase: float, w: float, t: float) -> void:
	var body: Node3D = _part(cat_node, "Body")
	var head: Node3D = _part(cat_node, "Head")
	if body == null or head == null:
		return
	var s: float = sin(phase)
	for leg: Array in [["LegFL", 1.0], ["LegBR", 1.0], ["LegFR", -1.0], ["LegBL", -1.0]]:
		var n: Node3D = _part(body, str(leg[0]))
		if n != null:
			n.rotation.x = s * 0.55 * w * float(leg[1])
	body.rotation.x = 0.0
	body.position = ProceduralAnimationSystem._rest_pos(body) + Vector3(0.0, absf(cos(phase)) * 0.008 * w, 0.0)
	head.position = ProceduralAnimationSystem._rest_pos(head) + Vector3(0.0, absf(cos(phase)) * 0.006 * w, 0.0)
	head.rotation = Vector3(sin(phase * 2.0) * 0.05 * w, 0.0, 0.0)
	_tail_sway(body, t, 0.30)


## Duduk (`k` 0..1): badan depan terangkat, kaki belakang terlipat, kaki depan
## tetap tegak, kepala sedikit naik. `lick` 0..1 mengangkat kaki depan kanan ke
## mulut dan menjilatnya; `sniff` 0..1 menunduk mengendus.
static func cat_pose(cat_node: Node3D, k: float, lick: float, sniff: float, t: float) -> void:
	var body: Node3D = _part(cat_node, "Body")
	var head: Node3D = _part(cat_node, "Head")
	if body == null or head == null:
		return
	var tilt: float = 0.48 * k
	body.rotation.x = tilt
	body.position = ProceduralAnimationSystem._rest_pos(body) + Vector3(0.0, -0.012 * k, 0.03 * k)
	for leg_name: String in ["LegFL", "LegFR"]:
		var n: Node3D = _part(body, leg_name)
		if n != null:
			n.rotation.x = -tilt
	for leg_name2: String in ["LegBL", "LegBR"]:
		var n2: Node3D = _part(body, leg_name2)
		if n2 != null:
			n2.rotation.x = 1.25 * k - tilt
	var paw: Node3D = _part(body, "LegFR")
	if paw != null:
		paw.rotation.x = -tilt + 1.25 * lick
	head.position = ProceduralAnimationSystem._rest_pos(head) + Vector3(0.0, 0.035 * k, 0.02 * k)
	head.rotation = Vector3(-0.30 * lick - 0.40 * sniff + sin(t * 11.0) * 0.07 * maxf(lick, sniff), 0.0, 0.18 * lick)
	_tail_sway(body, t, 0.45 - 0.25 * k)


static func _tail_sway(body: Node3D, t: float, amp: float) -> void:
	var tail: Node3D = _part(body, "Tail")
	if tail != null:
		tail.rotation = Vector3(-0.15, 0.0, sin(t * 2.2) * amp)


# ===========================================================================
# BURUNG PIPIT
# ===========================================================================

## Burung pipit chibi: badan cokelat berperut krem, topi kepala cokelat tua,
## paruh jingga, sayap dan ekor cokelat tua. Panjang sekitar 0,21 m (skala
## chibi, supaya terbaca dari kamera atas).
static func sparrow() -> Node3D:
	var root := Node3D.new()
	root.name = "Sparrow"
	var body: Node3D = _piece(root, "Body", Vector3(0.0, 0.055, 0.0), func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Transform3D(), Vector3(0.036, 0.033, 0.052), SPARROW_BROWN, 10, 6, func(u: Vector3) -> Color:
			return CREAM if u.y < -0.25 and u.z < 0.4 else SPARROW_BROWN)
		mb.ellipsoid(Transform3D(Basis(Vector3.RIGHT, -0.35), Vector3(0.0, 0.012, 0.058)), Vector3(0.017, 0.005, 0.032), SPARROW_CAP, 8, 4)
		for side: float in [-1.0, 1.0]:
			mb.capsule(Vector3(0.012 * side, -0.025, 0.0), Vector3(0.012 * side, -0.052, -0.004), 0.0035, 0.003, EYE, 5, 1))
	for side2: Array in [["WingL", -1.0], ["WingR", 1.0]]:
		_piece(body, str(side2[0]), Vector3(0.032 * float(side2[1]), 0.010, 0.004), func(mb: MeshBuilder) -> void:
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.004 * float(side2[1]), -0.006, 0.008)), Vector3(0.007, 0.024, 0.040), SPARROW_CAP, 8, 4))
	_piece(root, "Head", Vector3(0.0, 0.085, -0.040), func(mb: MeshBuilder) -> void:
		mb.ellipsoid(Transform3D(), Vector3(0.027, 0.026, 0.027), SPARROW_BROWN, 10, 6, func(u: Vector3) -> Color:
			if u.y > 0.35:
				return SPARROW_CAP
			return CREAM if u.y < -0.35 else SPARROW_BROWN)
		mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -0.004, -0.029)), Vector3(0.006, 0.005, 0.012), BEAK, 6, 3)
		for side3: float in [-1.0, 1.0]:
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.015 * side3, 0.006, -0.018)), Vector3(0.0045, 0.0045, 0.004), EYE, 6, 3))
	root.scale = Vector3.ONE * 1.6
	return root


## Pose pipit: `peck` 0..1 menundukkan kepala mematuk, `flap` 0..1 mengepakkan
## sayap, `look` 0..1 menoleh kiri-kanan.
static func sparrow_pose(bird: Node3D, peck: float, flap: float, look: float, t: float) -> void:
	var body: Node3D = _part(bird, "Body")
	var head: Node3D = _part(bird, "Head")
	if body == null or head == null:
		return
	head.rotation = Vector3(-0.75 * peck, sin(t * 3.0) * 0.6 * look, 0.0)
	head.position = ProceduralAnimationSystem._rest_pos(head) + Vector3(0.0, -0.018 * peck, -0.010 * peck)
	body.rotation.x = -0.25 * peck
	for side: Array in [["WingL", -1.0], ["WingR", 1.0]]:
		var wing: Node3D = _part(body, str(side[0]))
		if wing != null:
			wing.rotation.z = float(side[1]) * flap * (0.5 + 0.9 * sin(t * 34.0))


# ===========================================================================
# KUPU-KUPU
# ===========================================================================

## Kupu-kupu pastel: sayap atas stroberi bertotol mentega, sayap bawah lavender,
## badan cokelat tua dengan dua antena. Bentang sayap sekitar 0,30 m (skala
## chibi, supaya terbaca dari kamera atas).
static func butterfly() -> Node3D:
	var root := Node3D.new()
	root.name = "Butterfly"
	_piece(root, "Body", Vector3.ZERO, func(mb: MeshBuilder) -> void:
		mb.capsule(Vector3(0.0, 0.0, -0.022), Vector3(0.0, 0.0, 0.026), 0.006, 0.005, EYE, 6, 2)
		for side: float in [-1.0, 1.0]:
			mb.capsule(Vector3(0.002 * side, 0.002, -0.024), Vector3(0.012 * side, 0.022, -0.040), 0.0015, 0.0015, EYE, 4, 1))
	for side2: Array in [["WingL", -1.0], ["WingR", 1.0]]:
		var sd: float = float(side2[1])
		_piece(root, str(side2[0]), Vector3(0.004 * sd, 0.0, 0.0), func(mb: MeshBuilder) -> void:
			mb.ellipsoid(Transform3D(Basis(Vector3.UP, 0.35 * sd), Vector3(0.032 * sd, 0.0, -0.010)), Vector3(0.034, 0.003, 0.024),
				Palette.PASTEL_STRAWBERRY, 10, 4, func(u: Vector3) -> Color:
					return Palette.BUTTER_YELLOW if absf(u.x) > 0.55 and absf(u.z) < 0.35 else Palette.PASTEL_STRAWBERRY)
			mb.ellipsoid(Transform3D(Basis(Vector3.UP, -0.30 * sd), Vector3(0.024 * sd, -0.001, 0.018)), Vector3(0.024, 0.003, 0.018),
				Palette.PASTEL_PERIWINKLE, 10, 4))
	root.scale = Vector3.ONE * 2.0
	return root


## Kepak sayap kupu-kupu (`t` detik, `rate` pengali; 0 = sayap terbuka diam).
static func butterfly_flap(fly: Node3D, t: float, rate: float) -> void:
	var a: float = 0.25 + 0.85 * (0.5 + 0.5 * sin(t * 17.0 * rate)) if rate > 0.0 else 0.15
	var wl: Node3D = _part(fly, "WingL")
	var wr: Node3D = _part(fly, "WingR")
	if wl != null:
		wl.rotation.z = -a
	if wr != null:
		wr.rotation.z = a


# ===========================================================================
# MASKOT ROTI
# ===========================================================================

## Orang berkostum roti tawar raksasa (maskot toko): badan kubah berkulit
## keemasan dengan muka remah krem yang tersenyum, pipi merona, lengan
## bersarung tangan putih, dan kaki bercelana cokelat. Tinggi sekitar 0,95 m.
static func bread_mascot() -> Node3D:
	var root := Node3D.new()
	root.name = "Mascot"
	var crust: Color = Palette.GOLDEN_CRUST
	var crumb: Color = Palette.VANILLA_CREAM.lerp(Palette.FLOUR_WHITE, 0.4)
	var body: Node3D = _piece(root, "Body", Vector3(0.0, 0.30, 0.0), func(mb: MeshBuilder) -> void:
		mb.box(Transform3D(Basis(), Vector3(0.0, 0.20, 0.0)), Vector3(0.44, 0.40, 0.30), crust)
		mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, 0.40, 0.0)), Vector3(0.245, 0.17, 0.150), crust, 14, 6)
		mb.box(Transform3D(Basis(), Vector3(0.0, 0.20, -0.151)), Vector3(0.37, 0.35, 0.012), crumb)
		mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, 0.38, -0.151)), Vector3(0.205, 0.125, 0.008), crumb, 14, 4)
		for side: float in [-1.0, 1.0]:
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.075 * side, 0.30, -0.160)), Vector3(0.024, 0.032, 0.008), EYE, 8, 4)
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.082 * side, 0.312, -0.166)), Vector3(0.007, 0.008, 0.004), CREAM, 6, 3)
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.125 * side, 0.245, -0.160)), Vector3(0.032, 0.018, 0.006), PINK, 8, 4)
		# Senyum "D": separuh elips yang dibalik (sisi lurus di atas).
		mb.ellipsoid(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI), Vector3(0.0, 0.235, -0.160)), Vector3(0.040, 0.024, 0.006),
			Palette.STRAWBERRY_DEEP, 10, 4, Callable(), func(_phi: float) -> float: return PI * 0.5))
	for arm: Array in [["ArmL", -1.0], ["ArmR", 1.0]]:
		_piece(body, str(arm[0]), Vector3(0.235 * float(arm[1]), 0.30, 0.0), func(mb: MeshBuilder) -> void:
			mb.capsule(Vector3.ZERO, Vector3(0.0, -0.17, 0.0), 0.036, 0.032, crust, 8, 2)
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -0.195, 0.0)), Vector3(0.044, 0.042, 0.044), Palette.FLOUR_WHITE, 8, 5))
	for leg: Array in [["LegL", -1.0], ["LegR", 1.0]]:
		_piece(root, str(leg[0]), Vector3(0.10 * float(leg[1]), 0.32, 0.0), func(mb: MeshBuilder) -> void:
			mb.capsule(Vector3.ZERO, Vector3(0.0, -0.27, 0.0), 0.042, 0.040, Palette.CARAMEL, 8, 2)
			mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -0.295, -0.020)), Vector3(0.050, 0.030, 0.065), Palette.DARK_CHOCOLATE, 8, 4))
	return root


## Maskot berjalan berlenggok: kaki berayun, badan bergoyang kiri-kanan.
static func mascot_walk(m: Node3D, phase: float, w: float) -> void:
	var body: Node3D = _part(m, "Body")
	if body == null:
		return
	var s: float = sin(phase)
	for leg: Array in [["LegL", 1.0], ["LegR", -1.0]]:
		var n: Node3D = _part(m, str(leg[0]))
		if n != null:
			n.rotation.x = s * 0.45 * w * float(leg[1])
	body.rotation = Vector3(0.0, 0.0, s * 0.09 * w)
	body.position = ProceduralAnimationSystem._rest_pos(body) + Vector3(0.0, absf(cos(phase)) * 0.015 * w, 0.0)
	for arm: Array in [["ArmL", -1.0], ["ArmR", 1.0]]:
		var a: Node3D = _part(body, str(arm[0]))
		if a != null:
			a.rotation = Vector3(-s * 0.35 * w * float(arm[1]), 0.0, 0.20 * float(arm[1]))
	m.position.y = 0.0


## Maskot menari (`dance` 0..1): melompat kecil, bergoyang, kedua tangan naik
## melambai; `wave` 0..1 hanya tangan kanan yang melambai.
static func mascot_pose(m: Node3D, dance: float, wave: float, t: float) -> void:
	var body: Node3D = _part(m, "Body")
	if body == null:
		return
	var hop: float = absf(sin(t * 6.0)) * 0.05 * dance
	m.position.y = hop
	body.rotation = Vector3(0.0, 0.0, sin(t * 3.0) * 0.15 * dance)
	body.position = ProceduralAnimationSystem._rest_pos(body)
	for arm: Array in [["ArmL", -1.0], ["ArmR", 1.0]]:
		var a: Node3D = _part(body, str(arm[0]))
		if a == null:
			continue
		var sd: float = float(arm[1])
		var up: float = dance if sd < 0.0 else maxf(dance, wave)
		a.rotation = Vector3(0.0, 0.0, sd * (0.20 + (2.35 + sin(t * 9.0 + sd) * 0.30) * up))
	for leg: Array in [["LegL", 1.0], ["LegR", -1.0]]:
		var n: Node3D = _part(m, str(leg[0]))
		if n != null:
			n.rotation.x = sin(t * 6.0) * 0.30 * dance * float(leg[1])


# ===========================================================================
# PROPERTI & TANDA KECIL
# ===========================================================================

## Ukulele kayu pinus pengamen: badan angka delapan, lubang suara gelap, leher
## dan kepala lebih tua. Leher searah +Y, muka ke -Z.
static func ukulele() -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var wood: Color = Palette.PINE_WOOD
	mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -0.030, 0.0)), Vector3(0.056, 0.060, 0.018), wood, 12, 6)
	mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, 0.040, 0.0)), Vector3(0.043, 0.046, 0.018), wood, 12, 6)
	mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -0.004, -0.017)), Vector3(0.015, 0.015, 0.003), Palette.DARK_CHOCOLATE, 10, 3)
	mb.box(Transform3D(Basis(), Vector3(0.0, 0.135, -0.004)), Vector3(0.018, 0.130, 0.012), Palette.CARAMEL)
	mb.box(Transform3D(Basis(), Vector3(0.0, 0.215, -0.004)), Vector3(0.028, 0.036, 0.012), Palette.DARK_CHOCOLATE)
	var mi: MeshInstance3D = mb.commit("Ukulele")
	mi.visible = false
	return mi


## Hati kecil yang melayang dari kucing yang senang (tanda menghadap kamera).
static func heart() -> MeshInstance3D:
	if _heart_mesh == null:
		var mb := MeshBuilder.new()
		var pts := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			var hx: float = 16.0 * pow(sin(a), 3.0)
			var hy: float = 13.0 * cos(a) - 5.0 * cos(2.0 * a) - 2.0 * cos(3.0 * a) - cos(4.0 * a)
			pts.append(Vector2(hx, hy) * 0.0022)
		mb.polygon(Transform3D(), pts, Palette.STRAWBERRY)
		var tmp: MeshInstance3D = mb.commit("Heart", MeshBuilder.SIGN)
		_heart_mesh = tmp.mesh as ArrayMesh
		tmp.free()
	return _sign(_heart_mesh, "Heart")


## Remah roti keemasan yang dipatuk burung pipit (tanda menghadap kamera).
static func crumb() -> MeshInstance3D:
	if _crumb_mesh == null:
		var mb := MeshBuilder.new()
		var pts := PackedVector2Array()
		for i in 8:
			var a: float = TAU * float(i) / 8.0
			pts.append(Vector2(cos(a), sin(a)) * (0.017 if i % 2 == 0 else 0.013))
		mb.polygon(Transform3D(), pts, Palette.GOLDEN_CRUST)
		var tmp: MeshInstance3D = mb.commit("Crumb", MeshBuilder.SIGN)
		_crumb_mesh = tmp.mesh as ArrayMesh
		tmp.free()
	return _sign(_crumb_mesh, "Crumb")


static func _sign(mesh: ArrayMesh, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = MeshBuilder.material(MeshBuilder.SIGN)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _part(node: Node3D, part_name: String) -> Node3D:
	if node == null:
		return null
	var direct: Node = node.get_node_or_null(NodePath(part_name))
	if direct is Node3D:
		return direct
	return node.find_child(part_name, true, false) as Node3D
