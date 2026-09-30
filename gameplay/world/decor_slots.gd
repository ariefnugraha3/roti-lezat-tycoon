class_name DecorSlots
extends RefCounted
## Slot dekorasi dinding dan meja kasir per lokasi (GDD 72.3; keputusan
## maintainer 2026-09-30). Posisinya diturunkan dari template lokasi, jadi
## simulasi (validasi & save) dan tampilan selalu sepakat tanpa menyimpan
## koordinat apa pun di save.
##
## - Dinding: tempat kosong di dinding setinggi penuh (belakang dan kanan) lantai
##   toko, di sela jendela dan jauh dari sudut serta pintu tangga. Tempat yang
##   menghadap area toko lebih dulu, lalu dinding belakang, lalu dari sisi pintu
##   depan. Hanya `decor_slots.wall` tempat pertama yang boleh dipakai.
## - Meja kasir: satu slot per meja kasir, di ujung yang jauh dari kantong
##   belanja (lihat counter_frame) dan tidak dipakai tablet RotiFood.
##
## Setiap slot: {index, floor, pos: Vector3, yaw: float, wall/counter}.

## Lebar hiasan dinding dan jarak antarhiasan (m).
const WALL_SLOT_WIDTH: float = 0.62
const WALL_SLOT_GAP: float = 0.28
## Jarak bebas di sisi jendela (dari pusatnya) dan di sudut dinding (m).
const WINDOW_CLEAR: float = 0.45
const CORNER_CLEAR: float = 0.06
## Pilar sudut belakang lokasi Tier 4-5 (RoomFactory).
const PILLAR_CLEAR: float = 0.12
## Pusat hiasan sedikit di depan permukaan dinding (m).
const WALL_OFFSET: float = 0.004
## Barang meja: sejauh ini dari ujung meja, sedikit ke sisi pembeli (m).
const COUNTER_END_INSET: float = 0.18
const COUNTER_FRONT_SHIFT: float = 0.05

static var _cache: Dictionary = {}


static func clear_cache() -> void:
	_cache.clear()


## Kunci cache: id lokasi + instance definisinya (katalog yang dimuat ulang
## menghasilkan definisi baru, jadi posisinya dihitung lagi).
static func _key(kind: String, loc: LocationDefinition) -> String:
	return "%s|%s|%d" % [kind, loc.id, loc.get_instance_id()]


## Slot yang boleh dipakai untuk `placement_type` (wall / counter_prop).
static func slots(loc: LocationDefinition, placement_type: StringName) -> Array[Dictionary]:
	if placement_type == &"wall":
		return wall_slots(loc)
	if placement_type == &"counter_prop":
		return counter_slots(loc)
	return []


static func wall_slots(loc: LocationDefinition) -> Array[Dictionary]:
	var spots: Array[Dictionary] = wall_spots(loc)
	return spots.slice(0, mini(loc.decor_slot_count(&"wall"), spots.size()))


static func counter_slots(loc: LocationDefinition) -> Array[Dictionary]:
	var all: Array[Dictionary] = _counter_spots(loc)
	return all.slice(0, mini(loc.decor_slot_count(&"counter_prop"), all.size()))


## Transform (relatif ke node lantai) dekorasi terpasang `item`, atau null bila
## tempatnya tidak ada di lokasi ini (DecorationManager.enforce_rules
## menyimpannya kembali).
static func transform_of(loc: LocationDefinition, def: MiscDefinitions.DecorationDefinition, item: Dictionary) -> Variant:
	match def.placement_type:
		&"wall", &"counter_prop":
			var list: Array[Dictionary] = slots(loc, def.placement_type)
			var i: int = int(item.get("slot", -1))
			if i < 0 or i >= list.size():
				return null
			var sd: Dictionary = list[i]
			return Transform3D(Basis(Vector3.UP, float(sd["yaw"])), sd["pos"])
		&"floor_prop":
			return Transform3D(Basis(), GridMath.cell_center3(SimManager.arr_to_cell(item["cell"])))
		&"floor_overlay":
			var rot: int = int(item.get("rot", 0))
			var fp: Vector2i = overlay_footprint(def, rot)
			var a: Vector2i = SimManager.arr_to_cell(item["cell"])
			var t: float = GridMath.WORLD_METERS_PER_TILE
			var c := Vector3((float(a.x) + float(fp.x) * 0.5) * t, 0.0, (float(a.y) + float(fp.y) * 0.5) * t)
			return Transform3D(Basis(Vector3.UP, PI * 0.5 if rot % 2 == 1 else 0.0), c)
	return null


## Ukuran jejak karpet dalam ubin setelah diputar `rot` kali 90°.
static func overlay_footprint(def: MiscDefinitions.DecorationDefinition, rot: int) -> Vector2i:
	var sz: Vector2i = def.overlay_size_tiles
	return Vector2i(sz.y, sz.x) if rot % 2 == 1 else sz


## Ubin jejak karpet berjangkar `anchor` (sudut x/z terkecil).
static func overlay_cells(def: MiscDefinitions.DecorationDefinition, anchor: Vector2i, rot: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var fp: Vector2i = overlay_footprint(def, rot)
	for z in fp.y:
		for x in fp.x:
			out.append(anchor + Vector2i(x, z))
	return out


## Semua tempat kosong di dinding tinggi lantai toko, urut prioritas.
static func wall_spots(loc: LocationDefinition) -> Array[Dictionary]:
	var key: String = _key("wall", loc)
	if _cache.has(key):
		return _cache[key]
	var f: FloorDefinition = loc.floor_def(loc.store_floor())
	var out: Array[Dictionary] = []
	if f != null:
		var t: float = GridMath.WORLD_METERS_PER_TILE
		var w: float = float(f.size.x) * t
		var d: float = float(f.size.y) * t
		var y: float = RoomFactory.wall_height(loc.tier) * RoomFactory.WINDOW_HEIGHT_RATIO
		var pillar: float = PILLAR_CLEAR if loc.tier >= 4 else 0.0
		var found: Array[Dictionary] = []
		# Dinding belakang (z = d), sepanjang X.
		var back_blocks: Array[Vector2] = []
		for x: float in RoomFactory.back_window_xs(w):
			back_blocks.append(Vector2(x - WINDOW_CLEAR, x + WINDOW_CLEAR))
		if f.has_portal() and Vector2i(f.portal["cell"]).y == f.size.y - 1:
			var px: float = float(Vector2i(f.portal["cell"]).x) * t
			back_blocks.append(Vector2(px - 0.1, px + t + 0.1))
		for x2: float in _fit(CORNER_CLEAR + pillar, w - CORNER_CLEAR - pillar, back_blocks):
			var cell := Vector2i(clampi(int(x2 / t), 0, f.size.x - 1), f.size.y - 1)
			found.append({"floor": f.id, "pos": Vector3(x2, y, d - WALL_OFFSET), "yaw": 0.0, "wall": &"back",
				"along": x2, "store": f.zone_at(cell) == &"store"})
		# Dinding kanan (x = w), sepanjang Z.
		var right_blocks: Array[Vector2] = []
		for z: float in RoomFactory.side_window_zs(d):
			right_blocks.append(Vector2(z - WINDOW_CLEAR, z + WINDOW_CLEAR))
		if f.has_portal() and Vector2i(f.portal["cell"]).x == f.size.x - 1:
			var pz: float = float(Vector2i(f.portal["cell"]).y) * t
			right_blocks.append(Vector2(pz - 0.1, pz + t + 0.1))
		for z2: float in _fit(CORNER_CLEAR, d - CORNER_CLEAR - pillar, right_blocks):
			var cell2 := Vector2i(f.size.x - 1, clampi(int(z2 / t), 0, f.size.y - 1))
			found.append({"floor": f.id, "pos": Vector3(w - WALL_OFFSET, y, z2), "yaw": PI * 0.5, "wall": &"right",
				"along": z2, "store": f.zone_at(cell2) == &"store"})
		found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if bool(a["store"]) != bool(b["store"]):
				return bool(a["store"])
			if a["wall"] != b["wall"]:
				return a["wall"] == &"back"
			return float(a["along"]) < float(b["along"]))
		for i in found.size():
			var s: Dictionary = found[i]
			out.append({"index": i, "floor": s["floor"], "pos": s["pos"], "yaw": s["yaw"], "wall": s["wall"]})
	_cache[key] = out
	return out


## Pusat-pusat hiasan selebar WALL_SLOT_WIDTH yang muat di [lo, hi] dikurangi
## rentang terhalang, disebar rata dalam tiap celah: jarak antarhiasan paling
## sedikit WALL_SLOT_GAP dan setengahnya di kedua tepi celah.
static func _fit(lo: float, hi: float, blocks: Array[Vector2]) -> Array[float]:
	var sorted: Array[Vector2] = blocks.duplicate()
	sorted.sort_custom(func(a: Vector2, b: Vector2) -> bool: return a.x < b.x)
	var gaps: Array[Vector2] = []
	var cur: float = lo
	for bl: Vector2 in sorted:
		if bl.y <= cur or bl.x >= hi:
			continue
		if bl.x > cur:
			gaps.append(Vector2(cur, minf(bl.x, hi)))
		cur = maxf(cur, bl.y)
	if cur < hi:
		gaps.append(Vector2(cur, hi))
	var out: Array[float] = []
	for g: Vector2 in gaps:
		var length: float = g.y - g.x
		var k: int = int(floor(length / (WALL_SLOT_WIDTH + WALL_SLOT_GAP)))
		for i in k:
			out.append(g.x + length * (float(i) + 0.5) / float(k))
	return out


## Tata letak permukaan satu meja kasir, dipakai bersama slot dekorasi dan
## kantong belanja WorldView: mesin kasir di tengah meja (RoomFactory), kantong
## di sisi `bag_side` mesin kasir, dan hiasan meja di ujung seberangnya.
## {center: Vector2, half: float (m), axis_x: bool, to_customer: Vector2,
##  bag_side: Vector2, cells: [min, max]}; kosong bila meja tanpa lane.
static func counter_frame(f: FloorDefinition, c: Dictionary) -> Dictionary:
	var cells: Array[Vector2i] = c.get("cells", [] as Array[Vector2i])
	if cells.is_empty():
		return {}
	var mn := Vector2i(1 << 20, 1 << 20)
	var mx := Vector2i(-1, -1)
	for cell: Vector2i in cells:
		mn = Vector2i(mini(mn.x, cell.x), mini(mn.y, cell.y))
		mx = Vector2i(maxi(mx.x, cell.x), maxi(mx.y, cell.y))
	var sp: Vector2i = FloorDefinition.NONE_CELL
	var cp: Vector2i = FloorDefinition.NONE_CELL
	for lane: Dictionary in f.lanes:
		if lane["counter_id"] == c["id"]:
			sp = lane["service_point"]
			cp = lane["cashier_point"]
			break
	if sp == FloorDefinition.NONE_CELL or cp == FloorDefinition.NONE_CELL:
		return {}
	var t: float = GridMath.WORLD_METERS_PER_TILE
	var axis_x: bool = (mx.x - mn.x) >= (mx.y - mn.y)
	var to_customer: Vector2 = (GridMath.cell_center(sp) - GridMath.cell_center(cp)).normalized()
	return {
		"center": Vector2((float(mn.x + mx.x) * 0.5 + 0.5) * t, (float(mn.y + mx.y) * 0.5 + 0.5) * t),
		"half": float((mx.x - mn.x) if axis_x else (mx.y - mn.y)) * t * 0.5 + t * 0.5,
		"axis_x": axis_x,
		"to_customer": to_customer,
		"bag_side": Vector2(to_customer.y, -to_customer.x),
		"cells": [mn, mx],
	}


## Satu tempat per meja kasir lantai toko, urut daftar meja di template.
static func _counter_spots(loc: LocationDefinition) -> Array[Dictionary]:
	var key: String = _key("counter", loc)
	if _cache.has(key):
		return _cache[key]
	var out: Array[Dictionary] = []
	var f: FloorDefinition = loc.floor_def(loc.store_floor())
	if f != null:
		for c: Dictionary in f.counters:
			var fr: Dictionary = counter_frame(f, c)
			if fr.is_empty():
				continue
			var mn: Vector2i = fr["cells"][0]
			var mx: Vector2i = fr["cells"][1]
			var bag_side: Vector2 = fr["bag_side"]
			var tablet: Vector2i = c.get("tablet_cell", FloorDefinition.NONE_CELL)
			# Ujung seberang kantong; bila di sana ada tablet, ujung satunya.
			var s: Vector2 = -bag_side
			for _attempt in 2:
				var high: bool = (s.x if bool(fr["axis_x"]) else s.y) > 0.0
				if (mx if high else mn) != tablet:
					break
				s = -s
			var to_customer: Vector2 = fr["to_customer"]
			var p2: Vector2 = Vector2(fr["center"]) + s * (float(fr["half"]) - COUNTER_END_INSET) + to_customer * COUNTER_FRONT_SHIFT
			out.append({"index": out.size(), "floor": f.id, "pos": Vector3(p2.x, EquipmentFactory.COUNTER_HEIGHT, p2.y),
				"yaw": atan2(-to_customer.x, -to_customer.y), "counter": c["id"]})
	_cache[key] = out
	return out
