class_name WorldManager
extends SimManager
## WorldManager — pemilik lokasi aktif, grid lantai, layout perabot, navigasi,
## dan reservasi titik eksklusif (GDD 17, 56, 57, 60, 68, 83, 98).

signal layout_changed()

## Alasan penolakan yang berarti "ubin ini harus tetap jadi jalan" (untuk UI).
const WALKWAY_REASONS: Array[StringName] = [&"reserved", &"path", &"blocks_access"]

var location: LocationDefinition = null
var floors: Dictionary = {}
## "floor:x:y" -> actor_id. Titik pakai alat, titik layan, drop-off (GDD 56.1).
var point_reservations: Dictionary = {}
## iid -> {floor, cell} tile akses terpilih untuk perabot terpasang.
var access_cell: Dictionary = {}


func set_location(loc_id: StringName) -> void:
	location = DataRegistry.location(loc_id)
	floors.clear()
	point_reservations.clear()
	access_cell.clear()
	for f: FloorDefinition in location.floors:
		floors[f.id] = FloorGrid.new(f)
	rebuild_occupancy()


func new_game() -> void:
	set_location(DataRegistry.location_by_tier(1).id)


func grid(floor_id: StringName) -> FloorGrid:
	return floors.get(floor_id)


func floor_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for f: FloorDefinition in location.floors:
		out.append(f.id)
	return out


func store_floor() -> StringName:
	return location.store_floor()


func kitchen_floor() -> StringName:
	return location.kitchen_floor()


func entrance_cell() -> Vector2i:
	return location.entrance_cell


# ===========================================================================
# OCCUPANCY
# ===========================================================================

## Menyusun ulang footprint, tile akses, dan dekorasi dari state pemiliknya,
## lalu memperbarui graf navigasi (hanya saat layout berubah, GDD 17.5).
func rebuild_occupancy() -> void:
	sim.equipment.invalidate_lists()
	for g: Variant in floors.values():
		var fg: FloorGrid = g
		fg.furniture_at.clear()
		fg.access_at.clear()
		fg.decor_at.clear()
	access_cell.clear()
	if sim == null or sim.equipment == null:
		return
	for e: EquipmentInstance in sim.equipment.placed_list():
		var fg2: FloorGrid = grid(e.floor_id)
		if fg2 == null:
			continue
		for c: Vector2i in e.footprint_cells():
			fg2.furniture_at[c] = e.iid
	for e2: EquipmentInstance in sim.equipment.placed_list():
		var fg3: FloorGrid = grid(e2.floor_id)
		if fg3 == null:
			continue
		var acc: Vector2i = _pick_access(fg3, e2, e2.anchor, e2.rotation, e2.iid)
		if acc.x >= 0:
			fg3.access_at[acc] = e2.iid
			access_cell[e2.iid] = {"floor": e2.floor_id, "cell": acc}
	if sim.decoration != null:
		for d: Dictionary in sim.decoration.placed_floor_props():
			var fg4: FloorGrid = grid(StringName(str(d["floor_id"])))
			if fg4 != null:
				fg4.decor_at[arr_to_cell(d["cell"])] = int(d["uid"])
	for g2: Variant in floors.values():
		(g2 as FloorGrid).rebuild_nav()
	layout_changed.emit()


## Tile akses di depan interaction face (GDD 60.1). Dipilih yang di tengah
## sisi depan lebih dulu, lalu yang lain.
func _pick_access(fg: FloorGrid, e: EquipmentInstance, anchor: Vector2i, rot: int, self_iid: int) -> Vector2i:
	var fronts: Array[Vector2i] = GridMath.front_cells(anchor, e.def().footprint_tiles, rot, e.def().interaction_face)
	var ordered: Array[Vector2i] = []
	var mid: int = fronts.size() / 2
	if fronts.size() > 0:
		ordered.append(fronts[mid])
	for i in fronts.size():
		if i != mid:
			ordered.append(fronts[i])
	for c: Vector2i in ordered:
		if _access_ok(fg, c, self_iid, e.category()):
			return c
	return Vector2i(-1, -1)


func _access_ok(fg: FloorGrid, c: Vector2i, self_iid: int, category: StringName) -> bool:
	if not fg.in_bounds(c):
		return false
	var f: int = fg.flag(c)
	if f != FloorGrid.Flag.WALKABLE_BUILDABLE and f != FloorGrid.Flag.WALKABLE_NO_BUILD:
		return false
	if fg.is_door(c):
		return false
	if fg.def.has_portal() and c == fg.def.portal["access"]:
		return false
	if fg.furniture_at.has(c) and int(fg.furniture_at[c]) != self_iid:
		return false
	if fg.decor_at.has(c):
		return false
	if fg.access_at.has(c) and int(fg.access_at[c]) != self_iid:
		return false
	# Rak display diakses pelanggan: tile aksesnya harus di zona toko publik.
	if category == &"display" and (not fg.is_store(c) or fg.is_staff_only(c)):
		return false
	return true


func access_of(iid: int) -> Dictionary:
	return access_cell.get(iid, {})


# ===========================================================================
# VALIDASI PENEMPATAN (GDD 17.3, 17.4, 56.1.2, 60.1)
# ===========================================================================

## "" bila sah; selain itu kode alasan untuk UI.
func validate_placement(e: EquipmentInstance, floor_id: StringName, anchor: Vector2i, rot: int) -> StringName:
	var fg: FloorGrid = grid(floor_id)
	if fg == null:
		return &"bounds"
	var def: EquipmentDefinition = e.def()
	if not def.rotations_allowed.has(posmod(rot, 4) * 90):
		return &"invalid"
	var cells: Array[Vector2i] = GridMath.footprint_cells(anchor, def.footprint_tiles, rot)
	var needs_store: bool = def.category_id == &"display"
	for c: Vector2i in cells:
		if not fg.in_bounds(c):
			return &"bounds"
		if needs_store and not fg.is_store(c):
			return &"zone"
		if not needs_store and not fg.is_kitchen(c):
			return &"zone"
		if fg.flag(c) != FloorGrid.Flag.WALKABLE_BUILDABLE:
			return &"reserved"
		if fg.furniture_at.has(c) and int(fg.furniture_at[c]) != e.iid:
			return &"overlap"
		if fg.decor_at.has(c):
			return &"overlap"
		if fg.access_at.has(c) and int(fg.access_at[c]) != e.iid:
			return &"blocks_access"
	# Terapkan sementara, lalu periksa tile akses dan konektivitas.
	var saved_fp: Dictionary = fg.furniture_at.duplicate()
	var saved_acc: Dictionary = fg.access_at.duplicate()
	var old_floor: FloorGrid = grid(e.floor_id) if e.placed else null
	var old_fp: Dictionary = old_floor.furniture_at.duplicate() if old_floor != null and old_floor != fg else {}
	var old_acc: Dictionary = old_floor.access_at.duplicate() if old_floor != null and old_floor != fg else {}
	_strip_iid(fg, e.iid)
	if old_floor != null and old_floor != fg:
		_strip_iid(old_floor, e.iid)
	for c2: Vector2i in cells:
		fg.furniture_at[c2] = e.iid
	var acc: Vector2i = _pick_access(fg, e, anchor, rot, e.iid)
	var reason: StringName = &""
	if acc.x < 0:
		reason = &"access"
	else:
		fg.access_at[acc] = e.iid
		if not _connectivity_ok():
			reason = &"path"
	fg.furniture_at = saved_fp
	fg.access_at = saved_acc
	if old_floor != null and old_floor != fg:
		old_floor.furniture_at = old_fp
		old_floor.access_at = old_acc
	return reason


## Validasi dekorasi floor_prop 1×1 di zona toko (GDD 72.1).
func validate_decor_cell(floor_id: StringName, cell: Vector2i, self_uid: int) -> StringName:
	var fg: FloorGrid = grid(floor_id)
	if fg == null or not fg.in_bounds(cell):
		return &"bounds"
	if not fg.is_store(cell):
		return &"zone"
	if fg.flag(cell) != FloorGrid.Flag.WALKABLE_BUILDABLE:
		return &"reserved"
	if fg.access_at.has(cell):
		return &"blocks_access"
	if fg.furniture_at.has(cell):
		return &"overlap"
	if fg.decor_at.has(cell) and int(fg.decor_at[cell]) != self_uid:
		return &"overlap"
	var saved: Dictionary = fg.decor_at.duplicate()
	for k: Variant in saved.keys():
		if int(saved[k]) == self_uid:
			fg.decor_at.erase(k)
	fg.decor_at[cell] = self_uid
	var ok: bool = _connectivity_ok()
	fg.decor_at = saved
	return &"" if ok else &"path"


## Ubin yang harus tetap kosong di satu lantai (GDD 17.3-17.4, 56.1): cell ->
## jenis. walkway = jalur terlindung/pintu/baris staf, queue = slot antrean,
## service = titik layanan/kasir/drop-off, access = ubin di depan perabot,
## chokepoint = ubin kosong yang bila ditutup sendirian memutus jalur wajib.
## `ignore_iid`: perabot yang sedang dipindah dianggap belum terpasang.
func keep_clear_cells(floor_id: StringName, ignore_iid: int = -1) -> Dictionary:
	var out: Dictionary = {}
	var fg: FloorGrid = grid(floor_id)
	if fg == null:
		return out
	var saved: Array = []
	if ignore_iid >= 0:
		for g: Variant in floors.values():
			var f: FloorGrid = g
			saved.append([f, f.furniture_at.duplicate(), f.access_at.duplicate()])
			_strip_iid(f, ignore_iid)
	var candidates: Array[Vector2i] = []
	for z in fg.size.y:
		for x in fg.size.x:
			var c := Vector2i(x, z)
			if fg.def.zone_at(c) == &"":
				continue
			match fg.flag(c):
				FloorGrid.Flag.WALKABLE_NO_BUILD:
					out[c] = &"walkway"
				FloorGrid.Flag.QUEUE_RESERVED:
					out[c] = &"queue"
				FloorGrid.Flag.INTERACTION_RESERVED:
					out[c] = &"service"
				FloorGrid.Flag.WALKABLE_BUILDABLE:
					if fg.access_at.has(c):
						out[c] = &"access"
					elif not fg.furniture_at.has(c) and not fg.decor_at.has(c):
						candidates.append(c)
	if not candidates.is_empty():
		var cuts: Dictionary = {}
		if not _connectivity_ok():
			# Tata letak sudah tidak sah: setiap penempatan akan ditolak "path".
			for c2: Vector2i in candidates:
				cuts[c2] = true
		else:
			var targets: Array = _floor_targets(fg)
			var pub_req: Array[Vector2i] = targets[0]
			var staff_req: Array[Vector2i] = targets[1]
			if not fg.def.entrance.is_empty():
				var entrance: Vector2i = fg.def.entrance[0]
				cuts.merge(_cut_cells(fg, entrance, pub_req, fg.is_public_walkable))
				staff_req = staff_req.duplicate()
				staff_req.append(entrance)
			if not staff_req.is_empty():
				cuts.merge(_cut_cells(fg, staff_req[0], staff_req, fg.is_walkable))
		for c3: Vector2i in candidates:
			if cuts.has(c3):
				out[c3] = &"chokepoint"
	for item: Variant in saved:
		var entry: Array = item
		(entry[0] as FloorGrid).furniture_at = entry[1]
		(entry[0] as FloorGrid).access_at = entry[2]
	return out


func _strip_iid(fg: FloorGrid, iid: int) -> void:
	for k: Variant in fg.furniture_at.keys():
		if int(fg.furniture_at[k]) == iid:
			fg.furniture_at.erase(k)
	for k2: Variant in fg.access_at.keys():
		if int(fg.access_at[k2]) == iid:
			fg.access_at.erase(k2)


## Semua node kritis tetap terhubung (GDD 56.1.2): jalur publik pintu -> akses
## rak -> antrean -> layanan, dan jalur internal kasir -> gudang -> mixer ->
## oven -> rak -> portal. Juga tiap perabot harus punya tile akses.
func _connectivity_ok() -> bool:
	for fid: StringName in floor_ids():
		var fg: FloorGrid = grid(fid)
		var targets: Array = _floor_targets(fg)
		var targets_public: Array[Vector2i] = targets[0]
		var targets_staff: Array[Vector2i] = targets[1]
		# Perabot tanpa tile akses di lantai ini = gagal.
		var with_access: Dictionary = {}
		for acc2: Variant in fg.access_at.keys():
			with_access[int(fg.access_at[acc2])] = true
		for c: Variant in fg.furniture_at.keys():
			if not with_access.has(int(fg.furniture_at[c])):
				return false
		if not fg.def.entrance.is_empty():
			var pub: Dictionary = fg.reachable_from(fg.def.entrance[0], fg.is_public_walkable)
			for t: Vector2i in targets_public:
				if not pub.has(t):
					return false
		var start: Vector2i = Vector2i(-1, -1)
		if not targets_staff.is_empty():
			start = targets_staff[0]
		if start.x >= 0:
			var staff: Dictionary = fg.reachable_from(start, fg.is_walkable)
			for t2: Vector2i in targets_staff:
				if not staff.has(t2):
					return false
			if not fg.def.entrance.is_empty() and not staff.has(fg.def.entrance[0]):
				return false
	return true


## Titik wajib satu lantai: [publik, staf]. Satu-satunya definisi, dipakai
## _connectivity_ok dan analisis ubin leher botol.
func _floor_targets(fg: FloorGrid) -> Array:
	var targets_public: Array[Vector2i] = []
	var targets_staff: Array[Vector2i] = []
	for lane: Dictionary in fg.def.lanes:
		targets_public.append(lane["service_point"])
		for q: Vector2i in lane["queue"]:
			targets_public.append(q)
		targets_staff.append(lane["cashier_point"])
	if not fg.def.rotifood_counter.is_empty():
		targets_public.append(fg.def.rotifood_counter["service_point"])
		for q2: Vector2i in fg.def.rotifood_counter["queue"]:
			targets_public.append(q2)
	if fg.def.supply_dropoff != FloorDefinition.NONE_CELL:
		targets_public.append(fg.def.supply_dropoff)
	if fg.def.has_portal():
		targets_staff.append(fg.def.portal["access"])
	for acc: Variant in fg.access_at.keys():
		var iid: int = int(fg.access_at[acc])
		var e: EquipmentInstance = sim.equipment.get_inst(iid)
		if e != null and e.category() == &"display":
			targets_public.append(acc)
		targets_staff.append(acc)
	return [targets_public, targets_staff]


## Ubin yang bila ditutup sendirian memisahkan titik wajib dari akarnya
## (titik artikulasi, Tarjan, satu DFS iteratif per graf). Setara dengan
## menguji _connectivity_ok untuk setiap ubin, tetapi linear, bukan kuadratik.
func _cut_cells(fg: FloorGrid, root: Vector2i, required: Array[Vector2i], walk: Callable) -> Dictionary:
	var cut: Dictionary = {}
	if not fg.in_bounds(root) or not bool(walk.call(root)):
		return cut
	var need: Dictionary = {}
	for r: Vector2i in required:
		need[r] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var disc: Dictionary = {root: 0}
	var low: Dictionary = {root: 0}
	var parent: Dictionary = {}
	var sub: Dictionary = {root: 1}
	var clock: int = 0
	var stack: Array = [[root, 0]]
	while not stack.is_empty():
		var top: Array = stack[stack.size() - 1]
		var u: Vector2i = top[0]
		var i: int = top[1]
		if i < 4:
			top[1] = i + 1
			var n: Vector2i = u + dirs[i]
			if not fg.in_bounds(n) or not bool(walk.call(n)):
				continue
			if not disc.has(n):
				clock += 1
				disc[n] = clock
				low[n] = clock
				parent[n] = u
				sub[n] = 1 if need.has(n) else 0
				stack.append([n, 0])
			elif not parent.has(u) or parent[u] != n:
				low[u] = mini(int(low[u]), int(disc[n]))
			continue
		stack.pop_back()
		if u == root:
			continue
		var pu: Vector2i = parent[u]
		low[pu] = mini(int(low[pu]), int(low[u]))
		sub[pu] = int(sub[pu]) + int(sub[u])
		if pu != root and int(low[u]) >= int(disc[pu]) and int(sub[u]) > 0:
			cut[pu] = true
	return cut


func layout_valid() -> bool:
	return _connectivity_ok()


## Save dari template lama (jalur kasir baru Tier 1, 2, dan 4, keputusan
## maintainer 2026-10-02): perabot yang footprint-nya kini menimpa sel yang tidak
## boleh dibangun (slot antrean, titik layan/kasir, drop-off, meja), atau yang
## tidak lagi punya tile akses, dilepas dari lantai. Pemanggil menempatkannya
## kembali dengan auto_place; isinya tidak berubah karena instance-nya sama.
func release_conflicts() -> Array[EquipmentInstance]:
	var out: Array[EquipmentInstance] = []
	for e: EquipmentInstance in sim.equipment.placed_list():
		var fg: FloorGrid = grid(e.floor_id)
		var bad: bool = fg == null
		if not bad:
			for c: Vector2i in e.footprint_cells():
				if not fg.in_bounds(c) or fg.flag(c) != FloorGrid.Flag.WALKABLE_BUILDABLE:
					bad = true
					break
		if not bad and access_of(e.iid).is_empty():
			bad = true
		if bad:
			out.append(e)
	for e2: EquipmentInstance in out:
		e2.placed = false
	if not out.is_empty():
		rebuild_occupancy()
	return out


# ===========================================================================
# PENEMPATAN OTOMATIS DETERMINISTIK (New Game & migrasi, GDD 47, 105.12)
# ===========================================================================

func floors_for_category(category: StringName) -> Array[StringName]:
	var out: Array[StringName] = []
	for f: FloorDefinition in location.floors:
		if category == &"display" and f.has_zone(&"store"):
			out.append(f.id)
		elif category != &"display" and f.has_zone(&"kitchen"):
			out.append(f.id)
	return out


## Menempatkan satu instance pada posisi sah pertama menurut urutan tetap.
func auto_place(e: EquipmentInstance) -> bool:
	for fid: StringName in floors_for_category(e.category()):
		var fg: FloorGrid = grid(fid)
		for cand: Dictionary in _candidates(fg, e):
			if validate_placement(e, fid, cand["anchor"], int(cand["rot"])) == &"":
				e.floor_id = fid
				e.anchor = cand["anchor"]
				e.rotation = int(cand["rot"])
				e.placed = true
				rebuild_occupancy()
				return true
	return false


## Kandidat: zona anjuran lebih dulu, lalu sel yang menempel tepi ruangan.
func _candidates(fg: FloorGrid, e: EquipmentInstance) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var pref: Variant = fg.def.preferred_zones.get(e.category())
	for z in fg.size.y:
		for x in fg.size.x:
			for rot in 4:
				var a := Vector2i(x, z)
				var fp: Vector2i = GridMath.rotated_footprint(e.def().footprint_tiles, rot)
				var inside_pref: bool = false
				if pref is Rect2i:
					inside_pref = (pref as Rect2i).encloses(Rect2i(a, fp))
				var edge: int = mini(mini(a.x, fg.size.x - (a.x + fp.x)), mini(a.y, fg.size.y - (a.y + fp.y)))
				# Hadap menjauhi tepi terdekat supaya pintu/ruang akses mengarah ke lorong.
				var score: int = (0 if inside_pref else 1000) + edge * 10 + rot
				out.append({"anchor": a, "rot": rot, "score": score, "order": out.size()})
	out.sort_custom(func(p: Dictionary, q: Dictionary) -> bool:
		if int(p["score"]) != int(q["score"]):
			return int(p["score"]) < int(q["score"])
		return int(p["order"]) < int(q["order"]))
	return out


# ===========================================================================
# RESERVASI TITIK EKSKLUSIF (GDD 56.1, 83.3)
# ===========================================================================

static func point_key(floor_id: StringName, cell: Vector2i) -> String:
	return "%s:%d:%d" % [floor_id, cell.x, cell.y]


func reserve_point(floor_id: StringName, cell: Vector2i, actor_id: StringName) -> bool:
	var k: String = point_key(floor_id, cell)
	var cur: Variant = point_reservations.get(k)
	if cur != null and StringName(str(cur)) != actor_id:
		return false
	point_reservations[k] = String(actor_id)
	return true


func release_point(floor_id: StringName, cell: Vector2i, actor_id: StringName) -> void:
	var k: String = point_key(floor_id, cell)
	if StringName(str(point_reservations.get(k, ""))) == actor_id:
		point_reservations.erase(k)


func release_all_for(actor_id: StringName) -> void:
	for k: Variant in point_reservations.keys():
		if StringName(str(point_reservations[k])) == actor_id:
			point_reservations.erase(k)


func point_holder(floor_id: StringName, cell: Vector2i) -> StringName:
	return StringName(str(point_reservations.get(point_key(floor_id, cell), "")))


func is_use_point_reserved_for(iid: int) -> bool:
	var a: Dictionary = access_of(iid)
	if a.is_empty():
		return false
	return point_holder(a["floor"], a["cell"]) != &""


# ===========================================================================
# RUTE (GDD 17.5, 68)
# ===========================================================================

## Rute dari posisi dunia (meter) ke sel tujuan, lintas lantai lewat portal.
## Mengembalikan daftar waypoint {floor, pos: Vector2, portal: bool}; kosong bila
## tidak ada jalan.
func find_route(from_floor: StringName, from_pos: Vector2, to_floor: StringName, to_cell: Vector2i, nav_class: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var fg: FloorGrid = grid(from_floor)
	var tg: FloorGrid = grid(to_floor)
	if fg == null or tg == null:
		return out
	var start: Vector2i = nearest_walkable(from_floor, GridMath.world_to_cell(from_pos), nav_class)
	if start.x < 0:
		return out
	if from_floor == to_floor:
		return _floor_route(fg, from_floor, start, to_cell, nav_class)
	if nav_class == FloorGrid.NAV_PUBLIC or not fg.def.has_portal() or not tg.def.has_portal():
		return out
	var first: Array[Dictionary] = _floor_route(fg, from_floor, start, fg.def.portal["access"], nav_class)
	if first.is_empty() and start != fg.def.portal["access"]:
		return out
	out.append_array(first)
	var dest_access: Vector2i = tg.def.portal["access"]
	out.append({"floor": to_floor, "pos": GridMath.cell_center(dest_access), "portal": true})
	var second: Array[Dictionary] = _floor_route(tg, to_floor, dest_access, to_cell, nav_class)
	if second.is_empty() and dest_access != to_cell:
		return []
	out.append_array(second)
	return out


func _floor_route(fg: FloorGrid, floor_id: StringName, start: Vector2i, goal: Vector2i, nav_class: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if start == goal:
		out.append({"floor": floor_id, "pos": GridMath.cell_center(goal), "portal": false})
		return out
	var cells: Array[Vector2i] = fg.cell_path(start, goal, nav_class)
	if cells.is_empty():
		return out
	var smooth: Array[Vector2i] = _smooth(fg, cells, nav_class)
	for i in range(1, smooth.size()):
		out.append({"floor": floor_id, "pos": GridMath.cell_center(smooth[i]), "portal": false})
	return out


## Line-of-sight smoothing (GDD 12.3.5, 17.5): lompati titik antara selama garis
## lurus hanya melewati sel yang bisa dilalui.
func _smooth(fg: FloorGrid, cells: Array[Vector2i], nav_class: int) -> Array[Vector2i]:
	if cells.size() <= 2:
		return cells
	var out: Array[Vector2i] = [cells[0]]
	var i: int = 0
	while i < cells.size() - 1:
		var j: int = cells.size() - 1
		while j > i + 1 and not _line_clear(fg, cells[i], cells[j], nav_class):
			j -= 1
		out.append(cells[j])
		i = j
	return out


func _line_clear(fg: FloorGrid, a: Vector2i, b: Vector2i, nav_class: int) -> bool:
	var pa: Vector2 = Vector2(a) + Vector2(0.5, 0.5)
	var pb: Vector2 = Vector2(b) + Vector2(0.5, 0.5)
	var dist: float = pa.distance_to(pb)
	var steps: int = maxi(1, int(ceil(dist / 0.12)))
	for s in steps + 1:
		var p: Vector2 = pa.lerp(pb, float(s) / float(steps))
		# Uji sel yang dilalui titik ini dan keempat sudut kecil di sekitarnya,
		# supaya aktor tidak memotong sudut perabot.
		for off: Vector2 in [Vector2.ZERO, Vector2(0.3, 0.3), Vector2(-0.3, 0.3), Vector2(0.3, -0.3), Vector2(-0.3, -0.3)]:
			var c := Vector2i(int(floor(p.x + off.x)), int(floor(p.y + off.y)))
			var ok: bool = fg.is_walkable(c) if nav_class == FloorGrid.NAV_STAFF else fg.is_public_walkable(c)
			if not ok:
				return false
	return true


## Sel dapat-dilalui terdekat (recovery watchdog, GDD 38.1).
func nearest_walkable(floor_id: StringName, cell: Vector2i, nav_class: int) -> Vector2i:
	var fg: FloorGrid = grid(floor_id)
	if fg == null:
		return Vector2i(-1, -1)
	var ok_fn: Callable = fg.is_walkable if nav_class == FloorGrid.NAV_STAFF else fg.is_public_walkable
	if bool(ok_fn.call(cell)):
		return cell
	for r in range(1, maxi(fg.size.x, fg.size.y)):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dz) != r:
					continue
				var c := cell + Vector2i(dx, dz)
				if bool(ok_fn.call(c)):
					return c
	return Vector2i(-1, -1)


func capture() -> Dictionary:
	return {"location_id": String(location.id)}


func restore(d: Dictionary) -> void:
	set_location(StringName(str(d.get("location_id", DataRegistry.location_by_tier(1).id))))
