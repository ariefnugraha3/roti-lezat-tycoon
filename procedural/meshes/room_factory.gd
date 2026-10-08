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
## Tablet RotiFood di meja dua jalur bergeser sejauh ini ke dalam ubinnya,
## memberi tempat hiasan meja di ujung luar (Tier 1-2).
const TABLET_INSET: float = 0.08
const WALL_HEIGHTS: Array[float] = [1.80, 2.00, 2.05, 2.30, 2.50]
## Lebar bingkai jendela dan tinggi pusatnya (fraksi tinggi dinding). Slot hiasan
## dinding (DecorSlots) memakai angka yang sama supaya tidak menutupi jendela.
const WINDOW_WIDTH: float = 0.78
const WINDOW_HEIGHT_RATIO: float = 0.55


static func wall_height(loc_tier: int) -> float:
	return WALL_HEIGHTS[clampi(loc_tier, 1, 5) - 1]


## Gaya interior per tier lokasi (keputusan maintainer 2026-10-08, GDD 32.3):
## pola dan warna ubin toko dan dapur, dinding, lis bawah (wainscot) dan relnya,
## dinding rendah, kusen, tirai, dan garis batas zona. Tier 1 tetap garasi hangat
## berkayu pinus; tier berikutnya naik kelas mengikuti lingkungannya (GDD 32.5).
static func interior_style(tier: int) -> Dictionary:
	match clampi(tier, 1, 5):
		2:
			# Ruko: keramik putih-abu, dapur ubin mint, dinding kuning mentega.
			return {
				"store": {"pattern": &"checker", "a": Palette.FLOUR_WHITE.darkened(0.03), "b": Palette.HOUSE_SKY.darkened(0.04), "cell": 0.5},
				"kitchen": {"pattern": &"checker", "a": Palette.PASTEL_MINT.darkened(0.08), "b": Palette.FLOUR_WHITE.darkened(0.03), "cell": 0.25},
				"wall": Palette.HOUSE_BUTTER, "wainscot": Palette.FLOUR_WHITE.darkened(0.04), "wainscot_h": 0.5,
				"rail": Palette.PASTEL_MINT.darkened(0.25), "low": Palette.HOUSE_BUTTER.darkened(0.18), "frame": Palette.FLOUR_WHITE.darkened(0.03),
				"curtain": [Palette.PASTEL_MINT, Palette.FLOUR_WHITE], "line": Palette.PASTEL_MINT.darkened(0.25), "pillar": Palette.FLOUR_WHITE,
			}
		3:
			# Bakery mandiri: lantai papan kayu oak, dapur ubin putih, dinding krem
			# berlis kayu cokelat setinggi pinggang.
			return {
				"store": {"pattern": &"planks", "a": Palette.CARAMEL.lightened(0.45), "b": Palette.CARAMEL.lightened(0.36), "c": Palette.CARAMEL.lightened(0.27)},
				"kitchen": {"pattern": &"checker", "a": Palette.FLOUR_WHITE.darkened(0.09), "b": Palette.FLOUR_WHITE.darkened(0.02), "cell": 0.25},
				"wall": Palette.VANILLA_CREAM.lightened(0.3), "wainscot": Palette.DOOR_WOOD, "wainscot_h": 0.75,
				"rail": Palette.CARAMEL, "low": Palette.DOOR_WOOD.darkened(0.1), "frame": Palette.DOOR_WOOD,
				"curtain": [Palette.BUTTER_YELLOW, Palette.FLOUR_WHITE], "line": Palette.DOOR_WOOD, "pillar": Palette.VANILLA_CREAM,
			}
		4:
			# Flagship: lantai marmer berlis kuningan, dapur granit, dinding sage
			# berpanel putih.
			return {
				"store": {"pattern": &"marble", "a": Palette.FLOUR_WHITE.darkened(0.02), "b": Palette.VANILLA_CREAM.lightened(0.18), "cell": 1.0, "inlay": Palette.BRASS},
				"kitchen": {"pattern": &"checker", "a": Palette.GRANITE, "b": Palette.GRANITE.darkened(0.08), "cell": 0.5},
				"wall": Palette.SAGE_WALL, "wainscot": Palette.FLOUR_WHITE.darkened(0.03), "wainscot_h": 0.62,
				"rail": Palette.BRASS, "low": Palette.FLOUR_WHITE.darkened(0.07), "frame": Palette.BRASS,
				"curtain": [Palette.PASTEL_STRAWBERRY.lightened(0.2), Palette.FLOUR_WHITE], "line": Palette.BRASS, "pillar": Palette.FLOUR_WHITE,
			}
		5:
			# Landmark heritage: ubin catur gelap-krem, dapur ubin terakota, dinding
			# kolonial putih dengan wainscot hijau.
			return {
				"store": {"pattern": &"checker", "a": Palette.CHECKER_DARK, "b": Palette.COLONIAL_WHITE, "cell": 0.5},
				"kitchen": {"pattern": &"checker", "a": Palette.TERRACOTTA.lightened(0.18), "b": Palette.TERRACOTTA.lightened(0.3), "cell": 0.5},
				"wall": Palette.COLONIAL_WHITE, "wainscot": Palette.COLONIAL_GREEN, "wainscot_h": 0.9,
				"rail": Palette.FLOUR_WHITE, "low": Palette.COLONIAL_GREEN.darkened(0.12), "frame": Palette.COLONIAL_GREEN,
				"curtain": [Palette.COLONIAL_GREEN.lightened(0.35), Palette.FLOUR_WHITE], "line": Palette.BRASS, "pillar": Palette.COLONIAL_WHITE.darkened(0.04),
			}
		_:
			# Garasi rumah: ubin terakota, dapur krem, dinding kayu pinus.
			return {
				"store": {"pattern": &"checker", "a": Palette.TERRACOTTA, "b": Palette.TERRACOTTA.lightened(0.12), "cell": 0.5},
				"kitchen": {"pattern": &"checker", "a": Palette.VANILLA_CREAM, "b": Palette.FLOUR_WHITE.darkened(0.05), "cell": 0.5},
				"wall": Palette.PINE_WOOD.lightened(0.18), "wainscot": Palette.CARAMEL, "wainscot_h": 0.32,
				"low": Palette.PINE_WOOD.darkened(0.1), "frame": Palette.CARAMEL,
				"curtain": [Palette.GINGHAM_A, Palette.GINGHAM_B], "line": Palette.CARAMEL, "pillar": Palette.VANILLA_CREAM,
			}


## Posisi X pusat jendela di dinding belakang selebar `w` meter.
static func back_window_xs(w: float) -> Array[float]:
	var out: Array[float] = []
	var n: int = maxi(1, int(w / 2.0))
	for i in n:
		out.append(w * (float(i) + 0.5) / float(n))
	return out


## Posisi Z pusat jendela di dinding kanan sepanjang `d` meter.
static func side_window_zs(d: float) -> Array[float]:
	var out: Array[float] = []
	var n: int = maxi(1, int(d / 3.0))
	for j in n:
		out.append(d * (float(j) + 0.5) / float(n))
	return out


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
	var style: Dictionary = interior_style(loc.tier)
	_build_floor_tiles(root, f, style)
	_build_walls(root, f, w, d, h, loc.tier, style)
	for c: Dictionary in f.counters:
		_build_counter(root, loc, f, c, false, skins)
	if not f.rotifood_counter.is_empty():
		_build_counter(root, loc, f, f.rotifood_counter, true, skins)
	for cell: Vector2i in f.walls:
		_partition_block(root, cell, style)
	if f.has_portal():
		_build_portal(root, f, h, style)
	if not f.entrance.is_empty():
		_build_entrance(root, f, bakery_name, h, skins, style)
	_lighting(root, w, d, h)
	return root


## Ubin tiap zona menurut gaya tier: papan catur, papan kayu, atau marmer
## berlis kuningan (interior_style).
static func _build_floor_tiles(root: Node3D, f: FloorDefinition, style: Dictionary) -> void:
	for z: Dictionary in f.zones:
		var r: Rect2i = z["rect"]
		var zs: Dictionary = style["store"] if z["type"] == &"store" else style["kitchen"]
		var zw: float = float(r.size.x) * T
		var zd: float = float(r.size.y) * T
		var plane: MeshInstance3D
		if zs["pattern"] == &"planks":
			var woods: Array[Color] = [zs["a"], zs["b"], zs["c"]]
			plane = EquipmentFactory._plank_plane(zw, zd, 0.25, 1.0, woods)
		else:
			plane = EquipmentFactory._checker_plane(zw, zd, float(zs.get("cell", T)), zs["a"], zs["b"], true)
		plane.name = "Zone_%s" % z["type"]
		root.add_child(plane)
		var cx: float = (float(r.position.x) + float(r.size.x) * 0.5) * T
		var cz: float = (float(r.position.y) + float(r.size.y) * 0.5) * T
		plane.position = Vector3(cx, 0.0, cz)
		if zs["pattern"] == &"marble":
			_inlay(root, Rect2(cx - zw * 0.5, cz - zd * 0.5, zw, zd), float(zs["cell"]), zs["inlay"])
	# Garis batas zona toko/dapur: tipis, tetap terbaca walau garasi terbuka (GDD 6.2).
	if f.zones.size() > 1:
		var k: Rect2i = (f.zones[1] as Dictionary)["rect"]
		var horizontal: bool = k.position.y > 0
		var line := ProceduralMeshFactory.box(Vector3(float(f.size.x) * T if horizontal else 0.03, 0.006, 0.03 if horizontal else float(f.size.y) * T), style["line"])
		line.name = "ZoneLine"
		root.add_child(line)
		if horizontal:
			line.position = Vector3(float(f.size.x) * T * 0.5, 0.004, float(k.position.y) * T)
		else:
			line.position = Vector3(float(k.position.x) * T, 0.004, float(f.size.y) * T * 0.5)


## Garis lis kuningan di sela ubin marmer, mengikuti petak papan caturnya.
static func _inlay(root: Node3D, rect: Rect2, cell: float, color: Color) -> void:
	var nx: int = maxi(2, int(round(rect.size.x / cell)))
	var nz: int = maxi(2, int(round(rect.size.y / cell)))
	for i in range(1, nx):
		var line := ProceduralMeshFactory.box(Vector3(0.02, 0.004, rect.size.y), color)
		line.name = "Inlay"
		root.add_child(line)
		line.position = Vector3(rect.position.x + rect.size.x * float(i) / float(nx), 0.003, rect.position.y + rect.size.y * 0.5)
	for j in range(1, nz):
		var line2 := ProceduralMeshFactory.box(Vector3(rect.size.x, 0.004, 0.02), color)
		line2.name = "Inlay"
		root.add_child(line2)
		line2.position = Vector3(rect.position.x + rect.size.x * 0.5, 0.003, rect.position.y + rect.size.y * float(j) / float(nz))


static func _build_walls(root: Node3D, f: FloorDefinition, w: float, d: float, h: float, tier: int, style: Dictionary) -> void:
	var wall_color: Color = style["wall"]
	var trim: Color = style["wainscot"]
	var wh: float = float(style["wainscot_h"])
	# Belakang (z = d) dan kanan (x = w): penuh.
	var back := ProceduralMeshFactory.box(Vector3(w + WALL_THICK * 2.0, h, WALL_THICK), wall_color)
	back.name = "WallBack"
	root.add_child(back)
	back.position = Vector3(w * 0.5, h * 0.5, d + WALL_THICK * 0.5)
	var right := ProceduralMeshFactory.box(Vector3(WALL_THICK, h, d), wall_color.darkened(0.06))
	right.name = "WallRight"
	root.add_child(right)
	right.position = Vector3(w + WALL_THICK * 0.5, h * 0.5, d * 0.5)
	# Lis bawah (wainscot) di dasar dinding penuh, dengan rel di atasnya bila ada.
	var wb := ProceduralMeshFactory.box(Vector3(w, wh, 0.012), trim)
	wb.name = "Wainscot"
	root.add_child(wb)
	wb.position = Vector3(w * 0.5, wh * 0.5, d - 0.006)
	var wr := ProceduralMeshFactory.box(Vector3(0.012, wh, d), trim.darkened(0.04))
	wr.name = "Wainscot"
	root.add_child(wr)
	wr.position = Vector3(w - 0.006, wh * 0.5, d * 0.5)
	if style.has("rail"):
		var rail: Color = style["rail"]
		var rb := ProceduralMeshFactory.box(Vector3(w, 0.035, 0.03), rail)
		root.add_child(rb)
		rb.position = Vector3(w * 0.5, wh, d - 0.015)
		var rr := ProceduralMeshFactory.box(Vector3(0.03, 0.035, d), rail)
		root.add_child(rr)
		rr.position = Vector3(w - 0.015, wh, d * 0.5)
	# Depan & kiri: dinding rendah, dengan celah pintu di depan.
	var door_x0: float = INF
	var door_x1: float = -INF
	for c: Vector2i in f.entrance:
		door_x0 = minf(door_x0, float(c.x) * T)
		door_x1 = maxf(door_x1, float(c.x + 1) * T)
	var low: Color = style["low"]
	if door_x0 == INF:
		_low_wall(root, "WallFront", Vector3(w * 0.5, 0.0, -WALL_THICK * 0.5), Vector3(w, LOW_WALL, WALL_THICK), low)
	else:
		if door_x0 > 0.01:
			_low_wall(root, "WallFrontL", Vector3(door_x0 * 0.5, 0.0, -WALL_THICK * 0.5), Vector3(door_x0, LOW_WALL, WALL_THICK), low)
		if door_x1 < w - 0.01:
			_low_wall(root, "WallFrontR", Vector3((door_x1 + w) * 0.5, 0.0, -WALL_THICK * 0.5), Vector3(w - door_x1, LOW_WALL, WALL_THICK), low)
	_low_wall(root, "WallLeft", Vector3(-WALL_THICK * 0.5, 0.0, d * 0.5), Vector3(WALL_THICK, LOW_WALL, d), low)
	# Jendela bertirai dan jam dinding (GDD 4.1 Cozy); kusen dan tirai mengikuti tier.
	for x: float in back_window_xs(w):
		_window(root, Vector3(x, h * WINDOW_HEIGHT_RATIO, d - 0.01), 0.0, style)
	# Muka jendela (-Z lokal) menghadap ke dalam ruangan: yaw +90 di dinding kanan.
	for z: float in side_window_zs(d):
		_window(root, Vector3(w - 0.01, h * WINDOW_HEIGHT_RATIO, z), 90.0, style)
	# Model jam menghadap +Z lokal; diputar 180 supaya mukanya menghadap ruangan.
	var clock := EquipmentFactory._wall_clock(root, Vector3(w * 0.5, h * 0.86, d - 0.02))
	if clock != null:
		clock.name = "WallClock"
		clock.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	if tier >= 4:
		# Flagship & Landmark: pilar penanda di sudut.
		for p: Vector2 in [Vector2(0.0, d), Vector2(w, d)]:
			var pil := ProceduralMeshFactory.cylinder(h, 0.08, 0.09, style["pillar"])
			root.add_child(pil)
			pil.position = Vector3(p.x, h * 0.5, p.y)


static func _low_wall(root: Node3D, node_name: String, center: Vector3, size: Vector3, color: Color) -> void:
	var m := ProceduralMeshFactory.box(size, color)
	m.name = node_name
	root.add_child(m)
	m.position = Vector3(center.x, size.y * 0.5, center.z)


static func _window(root: Node3D, pos: Vector3, yaw: float, style: Dictionary) -> void:
	var win := Node3D.new()
	win.name = "Window"
	root.add_child(win)
	win.position = pos
	win.rotation_degrees = Vector3(0.0, yaw, 0.0)
	var frame := ProceduralMeshFactory.box(Vector3(WINDOW_WIDTH, 0.62, 0.04), style["frame"])
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
		var curtain := EquipmentFactory._checker_plane(0.18, 0.54, 0.06, style["curtain"][0], style["curtain"][1], false)
		win.add_child(curtain)
		curtain.position = Vector3(s * 0.30, 0.0, -0.03)


static func _partition_block(root: Node3D, cell: Vector2i, style: Dictionary) -> void:
	var m := ProceduralMeshFactory.box(Vector3(T, PARTITION_H, T * 0.5), style["low"])
	m.name = "Partition"
	root.add_child(m)
	m.position = GridMath.cell_center3(cell, PARTITION_H * 0.5)
	var top := ProceduralMeshFactory.box(Vector3(T, 0.04, T * 0.6), style["line"])
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
	var shared: Array[Dictionary] = []
	if not rotifood:
		shared = DecorSlots.lanes_on(f, c["id"])
	var yaw: float = atan2(dir.x, dir.y)
	if rotifood:
		node = EquipmentFactory.build_pickup_counter()
		if skins.has("rotifood_counter"):
			_star_trim(node)
	elif shared.size() > 1:
		# Meja dua jalur (Tier 1-2): satu mesin kasir di ubin meja tiap jalur.
		node = EquipmentFactory.build_divider_counter(loc.tier, span - 0.04, 0)
		var inv := Basis(Vector3.UP, yaw).inverse()
		for i in shared.size():
			var lf: Dictionary = DecorSlots.lane_frame(f, shared[i])
			var reg: Vector2 = lf["register"]
			var local: Vector3 = inv * (Vector3(reg.x, 0.0, reg.y) - center)
			EquipmentFactory.add_divider_register(node, i, local.x, loc.tier)
	else:
		node = EquipmentFactory.build_divider_counter(loc.tier, span - 0.04, 1)
	node.name = "Counter_%s" % c["id"]
	node.set_meta("counter_id", c["id"])
	root.add_child(node)
	node.position = center
	node.rotation.y = yaw
	var tablet_cell: Vector2i = c.get("tablet_cell", FloorDefinition.NONE_CELL)
	if tablet_cell != FloorDefinition.NONE_CELL:
		var tab: Node3D = EquipmentFactory.build_tablet()
		tab.name = "Tablet"
		root.add_child(tab)
		tab.position = GridMath.cell_center3(tablet_cell, EquipmentFactory.COUNTER_HEIGHT)
		if shared.size() > 1:
			# Ujung luar ubin tablet dipakai hiasan meja (DecorSlots): tablet ke dalam.
			var toward: Vector2 = -((DecorSlots.lane_frame(f, shared[0]) as Dictionary).get("bag_side", Vector2.ZERO) as Vector2)
			tab.position += Vector3(toward.x, 0.0, toward.y) * TABLET_INSET
		tab.rotation.y = atan2(-dir.x, -dir.y)


static func _star_trim(node: Node3D) -> void:
	var trim := ProceduralMeshFactory.box(Vector3(0.8, 0.03, 0.03), Palette.GOLD_STAR)
	node.add_child(trim)
	trim.position = Vector3(0.0, EquipmentFactory.COUNTER_HEIGHT + 0.02, 0.23)


## Pintu tangga (GDD 60, 68): bingkai pintu dengan anak tangga mungil di baliknya.
static func _build_portal(root: Node3D, f: FloorDefinition, h: float, style: Dictionary) -> void:
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
		var post := ProceduralMeshFactory.box(Vector3(0.06, door_h, 0.08), style["frame"])
		portal.add_child(post)
		post.position = Vector3(s * 0.21, door_h * 0.5, 0.0)
	var lintel := ProceduralMeshFactory.box(Vector3(0.48, 0.07, 0.09), style["frame"])
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


static func _build_entrance(root: Node3D, f: FloorDefinition, bakery_name: String, h: float, skins: Dictionary, style: Dictionary) -> void:
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
		var post := ProceduralMeshFactory.box(Vector3(0.07, 0.9, 0.08), style["frame"])
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
