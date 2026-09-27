class_name FloorGrid
extends RefCounted
## Grid logis satu lantai (GDD 17, 56.1.1). Grid adalah source of truth
## occupancy; collider tidak pernah dipakai (GDD 17.1).

enum Flag { WALKABLE_BUILDABLE, WALKABLE_NO_BUILD, QUEUE_RESERVED, INTERACTION_RESERVED, FIXED_STRUCTURE, NON_WALKABLE }

## Kelas navigasi: staf/pemain boleh ke seluruh floor; publik (pelanggan,
## driver, kurir) hanya zona toko di luar baris staf (GDD 57, 68).
const NAV_STAFF: int = 0
const NAV_PUBLIC: int = 1

var id: StringName
var def: FloorDefinition
var size: Vector2i
var base_flags: PackedInt32Array = PackedInt32Array()
var zone_store: PackedByteArray = PackedByteArray()
var staff_only: PackedByteArray = PackedByteArray()
var door: PackedByteArray = PackedByteArray()
## sel -> id meja (fixture).
var counter_at: Dictionary = {}
## sel -> iid perabot (footprint).
var furniture_at: Dictionary = {}
## sel akses (tile di depan interaction face) -> iid.
var access_at: Dictionary = {}
## sel -> uid dekorasi floor_prop.
var decor_at: Dictionary = {}
## Sel pintu tangga: STAIR_DOOR_POINT boleh dilalui staf bergantian tetapi
## bukan waiting slot dan tidak dapat dibangun (GDD 56.1). Di Tier 3 kasir B
## hanya terjangkau lewat sel ini (GDD 57.3).
var portal_cell: Vector2i = Vector2i(-1, -1)
var nav: Array[AStarGrid2D] = []


func _init(floor_def: FloorDefinition) -> void:
	def = floor_def
	id = floor_def.id
	size = floor_def.size
	var n: int = size.x * size.y
	base_flags.resize(n)
	zone_store.resize(n)
	staff_only.resize(n)
	door.resize(n)
	for i in n:
		base_flags[i] = Flag.WALKABLE_BUILDABLE
	for z in size.y:
		for x in size.x:
			var c := Vector2i(x, z)
			var zt: StringName = def.zone_at(c)
			if zt == &"":
				base_flags[idx(c)] = Flag.NON_WALKABLE
			zone_store[idx(c)] = 1 if zt == &"store" else 0
	for c2: Vector2i in def.entrance:
		_set_flag(c2, Flag.WALKABLE_NO_BUILD)
		door[idx(c2)] = 1
	for c3: Vector2i in def.protected_cells:
		_set_flag(c3, Flag.WALKABLE_NO_BUILD)
	for c4: Vector2i in def.staff_only:
		_set_flag(c4, Flag.WALKABLE_NO_BUILD)
		staff_only[idx(c4)] = 1
	for c5: Vector2i in def.walls:
		_set_flag(c5, Flag.FIXED_STRUCTURE)
	for counter: Dictionary in def.counters:
		for c6: Vector2i in counter["cells"]:
			_set_flag(c6, Flag.FIXED_STRUCTURE)
			counter_at[c6] = counter["id"]
	for lane: Dictionary in def.lanes:
		_set_flag(lane["service_point"], Flag.INTERACTION_RESERVED)
		_set_flag(lane["cashier_point"], Flag.INTERACTION_RESERVED)
		staff_only[idx(lane["cashier_point"])] = 1
		for q: Vector2i in lane["queue"]:
			_set_flag(q, Flag.QUEUE_RESERVED)
	if not def.rotifood_counter.is_empty():
		for c7: Vector2i in def.rotifood_counter["cells"]:
			_set_flag(c7, Flag.FIXED_STRUCTURE)
			counter_at[c7] = def.rotifood_counter["id"]
		_set_flag(def.rotifood_counter["service_point"], Flag.INTERACTION_RESERVED)
		for q2: Vector2i in def.rotifood_counter["queue"]:
			_set_flag(q2, Flag.QUEUE_RESERVED)
	if def.supply_dropoff != FloorDefinition.NONE_CELL:
		_set_flag(def.supply_dropoff, Flag.INTERACTION_RESERVED)
	if def.has_portal():
		_set_flag(def.portal["cell"], Flag.FIXED_STRUCTURE)
		portal_cell = def.portal["cell"]
		staff_only[idx(portal_cell)] = 1
		_set_flag(def.portal["access"], Flag.WALKABLE_NO_BUILD)
		staff_only[idx(def.portal["access"])] = 1
	for k in 2:
		var a := AStarGrid2D.new()
		a.region = Rect2i(Vector2i.ZERO, size)
		a.cell_size = Vector2.ONE
		a.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
		a.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		a.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
		a.update()
		nav.append(a)


func idx(c: Vector2i) -> int:
	return c.y * size.x + c.x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < size.x and c.y < size.y


func _set_flag(c: Vector2i, f: int) -> void:
	if in_bounds(c):
		base_flags[idx(c)] = f


func flag(c: Vector2i) -> int:
	if not in_bounds(c):
		return Flag.NON_WALKABLE
	return base_flags[idx(c)]


func is_store(c: Vector2i) -> bool:
	return in_bounds(c) and zone_store[idx(c)] == 1


func is_kitchen(c: Vector2i) -> bool:
	return in_bounds(c) and zone_store[idx(c)] == 0 and base_flags[idx(c)] != Flag.NON_WALKABLE


func is_staff_only(c: Vector2i) -> bool:
	return in_bounds(c) and staff_only[idx(c)] == 1


func is_door(c: Vector2i) -> bool:
	return in_bounds(c) and door[idx(c)] == 1


## Dapat diinjak aktor (tanpa memperhitungkan aktor lain, GDD 56.1 soft-pass).
func is_walkable(c: Vector2i) -> bool:
	if not in_bounds(c):
		return false
	if c == portal_cell:
		return true
	var f: int = base_flags[idx(c)]
	if f == Flag.FIXED_STRUCTURE or f == Flag.NON_WALKABLE:
		return false
	if furniture_at.has(c) or decor_at.has(c):
		return false
	return true


func is_public_walkable(c: Vector2i) -> bool:
	return is_walkable(c) and is_store(c) and not is_staff_only(c)


## Sel boleh dibangun (Decoration Mode hanya WALKABLE_BUILDABLE, GDD 56.1.1).
func is_buildable(c: Vector2i) -> bool:
	return in_bounds(c) and base_flags[idx(c)] == Flag.WALKABLE_BUILDABLE and not access_at.has(c) \
		and not furniture_at.has(c) and not decor_at.has(c)


func rebuild_nav() -> void:
	for k in 2:
		var a: AStarGrid2D = nav[k]
		for z in size.y:
			for x in size.x:
				var c := Vector2i(x, z)
				var ok: bool = is_walkable(c) if k == NAV_STAFF else is_public_walkable(c)
				a.set_point_solid(c, not ok)


func cell_path(from: Vector2i, to: Vector2i, nav_class: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	var a: AStarGrid2D = nav[nav_class]
	if not a.is_in_boundsv(from) or not a.is_in_boundsv(to):
		return out
	if a.is_point_solid(from) or a.is_point_solid(to):
		return out
	var p: Array[Vector2i] = a.get_id_path(from, to)
	for c: Vector2i in p:
		out.append(c)
	return out


## BFS keterjangkauan (validasi konektivitas, GDD 17.4) dengan predikat sel.
func reachable_from(start: Vector2i, walk: Callable) -> Dictionary:
	var seen: Dictionary = {}
	if not in_bounds(start) or not bool(walk.call(start)):
		return seen
	var frontier: Array[Vector2i] = [start]
	seen[start] = true
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not frontier.is_empty():
		var c: Vector2i = frontier.pop_back()
		for d: Vector2i in dirs:
			var n: Vector2i = c + d
			if seen.has(n) or not in_bounds(n):
				continue
			if bool(walk.call(n)):
				seen[n] = true
				frontier.append(n)
	return seen
