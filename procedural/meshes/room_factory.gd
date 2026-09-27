class_name RoomFactory
extends RefCounted
## Pabrik bangunan satu lantai dari template layout kanonik (GDD 6.2, 32.2, 57).
##
## Koordinat dunia: 1 tile = 0,5 m; tile (x,z) menempati [x*0.5, (x+1)*0.5] di
## sumbu X dan [z*0.5, (z+1)*0.5] di sumbu Z. Pintu depan ada di z = 0. Kamera
## isometrik memandang dari sisi depan-kiri, jadi dinding depan (z = 0) dan kiri
## (x = 0) dibangun rendah supaya interior terbaca, dinding belakang & kanan
## setinggi penuh dengan jendela bertirai gingham (GDD 4.1).
##
## Elemen bangunan tetap (dinding, pintu, meja kasir, meja RotiFood, portal)
## tidak pernah dapat dipindah Decoration Mode (GDD 32.2).

const T: float = GridMath.WORLD_METERS_PER_TILE
const WALL_THICK: float = 0.10
const LOW_WALL: float = 0.16
const PARTITION_H: float = 0.62
const WALL_HEIGHTS: Array[float] = [1.80, 2.00, 2.05, 2.30, 2.50]


static func wall_height(loc_tier: int) -> float:
	return WALL_HEIGHTS[clampi(loc_tier, 1, 5) - 1]


## Membangun seluruh cangkang satu lantai. Anak penting:
##   "Counter_<id>"  meja kasir/RotiFood (dengan anak "Tablet" bila ada)
##   "Portal"        pintu tangga (Tier 2-3)
##   "Sign"          papan nama toko (lantai toko)
static func build_floor(loc: LocationDefinition, f: FloorDefinition, bakery_name: String, skins: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Floor_%s" % f.id
	var w: float = float(f.size.x) * T
	var d: float = float(f.size.y) * T
	var h: float = wall_height(loc.tier)
	_build_floor_tiles(root, f)
	_build_walls(root, f, w, d, h, loc.tier)
	for c: Dictionary in f.counters:
		_build_counter(root, loc, f, c, false, skins)
	if not f.rotifood_counter.is_empty():
		_build_counter(root, loc, f, f.rotifood_counter, true, skins)
	for cell: Vector2i in f.walls:
		_partition_block(root, cell, loc.tier)
	if f.has_portal():
		_build_portal(root, f, h)
	if not f.entrance.is_empty():
		_build_entrance(root, f, bakery_name, h, skins)
	_lighting(root, w, d, h)
	return root


static func _build_floor_tiles(root: Node3D, f: FloorDefinition) -> void:
	for z: Dictionary in f.zones:
		var r: Rect2i = z["rect"]
		var store: bool = z["type"] == &"store"
		var a: Color = Palette.TERRACOTTA if store else Palette.VANILLA_CREAM
		var b: Color = Palette.TERRACOTTA.lightened(0.12) if store else Palette.FLOUR_WHITE.darkened(0.05)
		var plane: MeshInstance3D = EquipmentFactory._checker_plane(float(r.size.x) * T, float(r.size.y) * T, T, a, b, true)
		plane.name = "Zone_%s" % z["type"]
		root.add_child(plane)
		plane.position = Vector3((float(r.position.x) + float(r.size.x) * 0.5) * T, 0.0, (float(r.position.y) + float(r.size.y) * 0.5) * T)
	# Garis batas zona toko/dapur: tipis, tetap terbaca walau garasi terbuka (GDD 6.2).
	if f.zones.size() > 1:
		var k: Rect2i = (f.zones[1] as Dictionary)["rect"]
		var horizontal: bool = k.position.y > 0
		var line := ProceduralMeshFactory.box(Vector3(float(f.size.x) * T if horizontal else 0.03, 0.006, 0.03 if horizontal else float(f.size.y) * T), Palette.CARAMEL)
		line.name = "ZoneLine"
		root.add_child(line)
		if horizontal:
			line.position = Vector3(float(f.size.x) * T * 0.5, 0.004, float(k.position.y) * T)
		else:
			line.position = Vector3(float(k.position.x) * T, 0.004, float(f.size.y) * T * 0.5)


static func _build_walls(root: Node3D, f: FloorDefinition, w: float, d: float, h: float, tier: int) -> void:
	var wall_color: Color = Palette.PINE_WOOD.lightened(0.18)
	var trim: Color = Palette.CARAMEL
	# Belakang (z = d) dan kanan (x = w): penuh.
	var back := ProceduralMeshFactory.box(Vector3(w + WALL_THICK * 2.0, h, WALL_THICK), wall_color)
	back.name = "WallBack"
	root.add_child(back)
	back.position = Vector3(w * 0.5, h * 0.5, d + WALL_THICK * 0.5)
	var right := ProceduralMeshFactory.box(Vector3(WALL_THICK, h, d), wall_color.darkened(0.06))
	right.name = "WallRight"
	root.add_child(right)
	right.position = Vector3(w + WALL_THICK * 0.5, h * 0.5, d * 0.5)
	# Wainscot kayu di dasar dinding penuh.
	var wb := ProceduralMeshFactory.box(Vector3(w, 0.32, 0.012), trim)
	root.add_child(wb)
	wb.position = Vector3(w * 0.5, 0.16, d - 0.006)
	var wr := ProceduralMeshFactory.box(Vector3(0.012, 0.32, d), trim)
	root.add_child(wr)
	wr.position = Vector3(w - 0.006, 0.16, d * 0.5)
	# Depan & kiri: dinding rendah, dengan celah pintu di depan.
	var door_x0: float = INF
	var door_x1: float = -INF
	for c: Vector2i in f.entrance:
		door_x0 = minf(door_x0, float(c.x) * T)
		door_x1 = maxf(door_x1, float(c.x + 1) * T)
	if door_x0 == INF:
		_low_wall(root, "WallFront", Vector3(w * 0.5, 0.0, -WALL_THICK * 0.5), Vector3(w, LOW_WALL, WALL_THICK))
	else:
		if door_x0 > 0.01:
			_low_wall(root, "WallFrontL", Vector3(door_x0 * 0.5, 0.0, -WALL_THICK * 0.5), Vector3(door_x0, LOW_WALL, WALL_THICK))
		if door_x1 < w - 0.01:
			_low_wall(root, "WallFrontR", Vector3((door_x1 + w) * 0.5, 0.0, -WALL_THICK * 0.5), Vector3(w - door_x1, LOW_WALL, WALL_THICK))
	_low_wall(root, "WallLeft", Vector3(-WALL_THICK * 0.5, 0.0, d * 0.5), Vector3(WALL_THICK, LOW_WALL, d))
	# Jendela bertirai gingham dan jam dinding (GDD 4.1 Cozy).
	var windows: int = maxi(1, int(w / 2.0))
	for i in windows:
		var x: float = w * (float(i) + 0.5) / float(windows)
		_window(root, Vector3(x, h * 0.55, d - 0.01), 0.0)
	var side_windows: int = maxi(1, int(d / 3.0))
	for j in side_windows:
		var z: float = d * (float(j) + 0.5) / float(side_windows)
		_window(root, Vector3(w - 0.01, h * 0.55, z), -90.0)
	var clock := EquipmentFactory._wall_clock(root, Vector3(w * 0.5, h * 0.86, d - 0.02))
	if clock != null:
		clock.name = "WallClock"
	if tier >= 4:
		# Flagship & Landmark: pilar penanda di sudut.
		for p: Vector2 in [Vector2(0.0, d), Vector2(w, d)]:
			var pil := ProceduralMeshFactory.cylinder(h, 0.08, 0.09, Palette.VANILLA_CREAM)
			root.add_child(pil)
			pil.position = Vector3(p.x, h * 0.5, p.y)


static func _low_wall(root: Node3D, node_name: String, center: Vector3, size: Vector3) -> void:
	var m := ProceduralMeshFactory.box(size, Palette.PINE_WOOD.darkened(0.1))
	m.name = node_name
	root.add_child(m)
	m.position = Vector3(center.x, size.y * 0.5, center.z)


static func _window(root: Node3D, pos: Vector3, yaw: float) -> void:
	var win := Node3D.new()
	win.name = "Window"
	root.add_child(win)
	win.position = pos
	win.rotation_degrees = Vector3(0.0, yaw, 0.0)
	var frame := ProceduralMeshFactory.box(Vector3(0.78, 0.62, 0.04), Palette.CARAMEL)
	win.add_child(frame)
	var glass := ProceduralMeshFactory.box(Vector3(0.66, 0.50, 0.02), Palette.GOLDEN_HOUR)
	var gm: StandardMaterial3D = ProceduralMeshFactory.material_of(glass)
	if gm != null:
		gm = gm.duplicate()
		gm.emission_enabled = true
		gm.emission = Palette.GOLDEN_HOUR
		gm.emission_energy_multiplier = 0.55
		glass.material_override = gm
	win.add_child(glass)
	glass.position = Vector3(0.0, 0.0, -0.012)
	for s: float in [-1.0, 1.0]:
		var curtain := EquipmentFactory._checker_plane(0.18, 0.54, 0.06, Palette.GINGHAM_A, Palette.GINGHAM_B, false)
		win.add_child(curtain)
		curtain.position = Vector3(s * 0.30, 0.0, -0.03)


static func _partition_block(root: Node3D, cell: Vector2i, tier: int) -> void:
	var m := ProceduralMeshFactory.box(Vector3(T, PARTITION_H, T * 0.5), Palette.PINE_WOOD if tier < 5 else Palette.VANILLA_CREAM)
	m.name = "Partition"
	root.add_child(m)
	m.position = GridMath.cell_center3(cell, PARTITION_H * 0.5)
	var top := ProceduralMeshFactory.box(Vector3(T, 0.04, T * 0.6), Palette.CARAMEL)
	root.add_child(top)
	top.position = GridMath.cell_center3(cell, PARTITION_H + 0.02)


## Meja kasir / meja RotiFood: fixture sepanjang sel-selnya, sisi pembeli
## menghadap service point (GDD 57, 60).
static func _build_counter(root: Node3D, loc: LocationDefinition, f: FloorDefinition, c: Dictionary, rotifood: bool, skins: Dictionary) -> void:
	var cells: Array[Vector2i] = c["cells"]
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-1, -1)
	for cell: Vector2i in cells:
		mn = Vector2i(mini(mn.x, cell.x), mini(mn.y, cell.y))
		mx = Vector2i(maxi(mx.x, cell.x), maxi(mx.y, cell.y))
	var along_x: bool = (mx.x - mn.x) >= (mx.y - mn.y)
	var span: float = float((mx.x - mn.x) if along_x else (mx.y - mn.y)) * T + T
	var center := Vector3((float(mn.x + mx.x) * 0.5 + 0.5) * T, 0.0, (float(mn.y + mx.y) * 0.5 + 0.5) * T)
	# Arah sisi pembeli: ke service point terdekat.
	var sp: Vector2i = FloorDefinition.NONE_CELL
	if rotifood:
		sp = c["service_point"]
	else:
		for lane: Dictionary in f.lanes:
			if lane["counter_id"] == c["id"]:
				sp = lane["service_point"]
	var dir := Vector2(0, -1)
	if sp != FloorDefinition.NONE_CELL:
		var to := Vector2(GridMath.cell_center(sp)) - Vector2(center.x, center.z)
		if absf(to.x) > absf(to.y):
			dir = Vector2(signf(to.x), 0.0)
		else:
			dir = Vector2(0.0, signf(to.y))
	var node: Node3D
	if rotifood:
		node = EquipmentFactory.build_pickup_counter()
		if skins.has("rotifood_counter"):
			_star_trim(node)
	else:
		node = EquipmentFactory.build_divider_counter(loc.tier, span - 0.04, 1)
	node.name = "Counter_%s" % c["id"]
	node.set_meta("counter_id", c["id"])
	root.add_child(node)
	node.position = center
	node.rotation.y = atan2(dir.x, dir.y)
	var tablet_cell: Vector2i = c.get("tablet_cell", FloorDefinition.NONE_CELL)
	if tablet_cell != FloorDefinition.NONE_CELL:
		var tab: Node3D = EquipmentFactory.build_tablet()
		tab.name = "Tablet"
		root.add_child(tab)
		tab.position = GridMath.cell_center3(tablet_cell, EquipmentFactory.COUNTER_HEIGHT)
		tab.rotation.y = atan2(-dir.x, -dir.y)


static func _star_trim(node: Node3D) -> void:
	var trim := ProceduralMeshFactory.box(Vector3(0.8, 0.03, 0.03), Palette.GOLD_STAR)
	node.add_child(trim)
	trim.position = Vector3(0.0, EquipmentFactory.COUNTER_HEIGHT + 0.02, 0.23)


## Pintu tangga (GDD 60, 68): bingkai pintu dengan anak tangga mungil di baliknya.
static func _build_portal(root: Node3D, f: FloorDefinition, h: float) -> void:
	var cell: Vector2i = f.portal["cell"]
	var access: Vector2i = f.portal["access"]
	var portal := Node3D.new()
	portal.name = "Portal"
	root.add_child(portal)
	portal.position = GridMath.cell_center3(cell)
	var to := Vector2(access - cell)
	portal.rotation.y = atan2(to.x, to.y)
	var door_h: float = minf(1.35, h * 0.72)
	for s: float in [-1.0, 1.0]:
		var post := ProceduralMeshFactory.box(Vector3(0.06, door_h, 0.08), Palette.CARAMEL)
		portal.add_child(post)
		post.position = Vector3(s * 0.21, door_h * 0.5, 0.0)
	var lintel := ProceduralMeshFactory.box(Vector3(0.48, 0.07, 0.09), Palette.CARAMEL)
	portal.add_child(lintel)
	lintel.position = Vector3(0.0, door_h, 0.0)
	var dark := ProceduralMeshFactory.box(Vector3(0.38, door_h - 0.04, 0.02), Palette.DARK_CHOCOLATE)
	portal.add_child(dark)
	dark.position = Vector3(0.0, door_h * 0.5, -0.04)
	for i in 4:
		var step := ProceduralMeshFactory.box(Vector3(0.36, 0.05, 0.1), Palette.PINE_WOOD)
		portal.add_child(step)
		step.position = Vector3(0.0, 0.03 + 0.1 * float(i), -0.06 - 0.02 * float(i))
	var arrow := Label3D.new()
	arrow.text = "▲" if f.id == &"floor_1" else "▼"
	arrow.font_size = 48
	arrow.modulate = Palette.GOLD_STAR
	arrow.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	arrow.no_depth_test = true
	portal.add_child(arrow)
	arrow.position = Vector3(0.0, door_h + 0.2, 0.0)


static func _build_entrance(root: Node3D, f: FloorDefinition, bakery_name: String, h: float, skins: Dictionary) -> void:
	var x0: float = INF
	var x1: float = -INF
	for c: Vector2i in f.entrance:
		x0 = minf(x0, float(c.x) * T)
		x1 = maxf(x1, float(c.x + 1) * T)
	var mid: float = (x0 + x1) * 0.5
	var mat_node := ProceduralMeshFactory.box(Vector3(x1 - x0 - 0.06, 0.01, 0.4), Palette.GINGHAM_A)
	mat_node.name = "DoorMat"
	root.add_child(mat_node)
	mat_node.position = Vector3(mid, 0.006, 0.22)
	for s: float in [x0, x1]:
		var post := ProceduralMeshFactory.box(Vector3(0.07, 0.9, 0.08), Palette.CARAMEL)
		root.add_child(post)
		post.position = Vector3(s, 0.45, -WALL_THICK * 0.5)
	var sign := Node3D.new()
	sign.name = "Sign"
	root.add_child(sign)
	sign.position = Vector3(mid, 1.05, -0.06)
	var carved: bool = skins.has("storefront_sign")
	var board := ProceduralMeshFactory.box(Vector3(maxf(1.4, float(bakery_name.length()) * 0.1 + 0.4), 0.28, 0.05), Palette.DARK_CHOCOLATE if carved else Palette.CARAMEL)
	sign.add_child(board)
	var label := Label3D.new()
	label.name = "SignText"
	label.text = bakery_name
	label.font_size = 64
	label.pixel_size = 0.0035
	label.modulate = Palette.BUTTER_YELLOW if carved else Palette.FLOUR_WHITE
	label.outline_size = 8
	label.outline_modulate = Palette.DARK_CHOCOLATE
	sign.add_child(label)
	label.position = Vector3(0.0, 0.0, -0.035)
	label.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	if skins.has("storefront"):
		var awning := EquipmentFactory._checker_plane(float(f.size.x) * T, 0.5, 0.25, Palette.PASTEL_STRAWBERRY, Palette.FLOUR_WHITE, false)
		awning.name = "Awning"
		root.add_child(awning)
		awning.position = Vector3(float(f.size.x) * T * 0.5, 1.45, -0.2)
		awning.rotation_degrees = Vector3(-35.0, 180.0, 0.0)


## Cahaya golden hour (GDD 4.1, 130.3): matahari hangat + pengisi lembut.
static func _lighting(root: Node3D, w: float, d: float, h: float) -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Palette.GOLDEN_HOUR
	sun.light_energy = 0.95
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-52.0, -135.0, 0.0)
	root.add_child(sun)
	var lamp_count: int = maxi(1, int((w * d) / 9.0))
	for i in lamp_count:
		var omni := OmniLight3D.new()
		omni.name = "Lamp%d" % i
		omni.light_color = Palette.WARMER_LAMP
		omni.light_energy = 0.55
		omni.omni_range = maxf(3.0, maxf(w, d) * 0.6)
		omni.shadow_enabled = false
		root.add_child(omni)
		var fx: float = (float(i % 3) + 0.5) / 3.0
		var fz: float = (float(i / 3) + 0.5) / float(maxi(1, lamp_count / 3 + 1))
		omni.position = Vector3(w * fx, h * 0.9, d * fz)
