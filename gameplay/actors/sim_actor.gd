class_name SimActor
extends RefCounted
## Aktor logis (GDD 16, 56.1, 59). Posisi otoritatif ada di sini dalam meter;
## node visual hanya mengikuti. Aktor berjalan bebas saling menembus (soft-pass);
## eksklusivitas hanya pada titik yang direservasi.

## Aktor berpindah lantai lewat portal (GDD 68).
signal floor_changed(actor: SimActor, floor_id: StringName)

var id: StringName
## player / staff / customer / driver / courier / lurah
var kind: StringName
var floor_id: StringName = &"floor_1"
var pos: Vector2 = Vector2.ZERO
var facing: Vector2 = Vector2(0, -1)
var speed_mps: float = 1.0
var nav_class: int = FloorGrid.NAV_STAFF
## Waypoint tersisa: {floor, pos, portal}.
var route: Array[Dictionary] = []
var goal_floor: StringName = &""
var goal_cell: Vector2i = Vector2i(-1, -1)
var moving: bool = false
## Sedang berjalan di luar grid lantai (trotoar, `walk_path`).
var outside: bool = false
## Barang yang dibawa: {} kosong, atau {type, job_id, recipe_id, units}.
var carried: Dictionary = {}
var state: StringName = &"IDLE"
## Kursi koki tempat aktor ini duduk (iid perabot), -1 = tidak duduk (GDD 5.1.4).
var seat_iid: int = -1
var visual_seed: int = 0
var visual_key: StringName = &""
## Watchdog (GDD 38.1).
var _stuck_time: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO


func cell() -> Vector2i:
	return GridMath.world_to_cell(pos)


func at_goal() -> bool:
	return route.is_empty() and goal_cell.x >= 0 and cell() == goal_cell and floor_id == goal_floor


func has_route() -> bool:
	return not route.is_empty()


## Pasang tujuan; mengembalikan false bila jalan terhalang (GDD 16.7).
func go_to(world: WorldManager, target_floor: StringName, target_cell: Vector2i) -> bool:
	outside = false
	goal_floor = target_floor
	goal_cell = target_cell
	if floor_id == target_floor and cell() == target_cell:
		route.clear()
		pos = GridMath.cell_center(target_cell)
		moving = false
		return true
	var r: Array[Dictionary] = world.find_route(floor_id, pos, target_floor, target_cell, nav_class)
	if r.is_empty():
		route.clear()
		moving = false
		return false
	route = r
	moving = true
	_stuck_time = 0.0
	return true


func stop() -> void:
	route.clear()
	moving = false


## Teleport aman (spawn di pintu, recovery).
func place_at(target_floor: StringName, target_cell: Vector2i) -> void:
	floor_id = target_floor
	pos = GridMath.cell_center(target_cell)
	route.clear()
	moving = false
	outside = false


## Berjalan di luar grid lantai (trotoar, GDD 20.1): mulai di titik pertama `path`
## lalu menempuh titik-titik berikutnya lurus, tanpa pencarian jalan. Selama itu
## `outside` true, jadi repath tata letak tidak menyentuhnya.
func walk_path(target_floor: StringName, path: PackedVector2Array) -> void:
	floor_id = target_floor
	route.clear()
	if path.is_empty():
		moving = false
		outside = false
		return
	pos = path[0]
	for i in range(1, path.size()):
		route.append({"floor": target_floor, "pos": path[i], "portal": false})
	moving = not route.is_empty()
	outside = moving
	if path.size() > 1 and path[0].distance_to(path[1]) > 0.0001:
		facing = (path[1] - path[0]).normalized()


## Satu langkah gerak (detik-simulasi). Mengembalikan true bila tiba di tujuan
## pada tick ini.
func step(dt: float, world: WorldManager) -> bool:
	if route.is_empty():
		moving = false
		return false
	var budget: float = speed_mps * dt
	var arrived: bool = false
	while budget > 0.0 and not route.is_empty():
		var wp: Dictionary = route[0]
		if bool(wp.get("portal", false)):
			# Portal instan: tanpa animasi tangga dan tanpa biaya waktu (GDD 68).
			floor_id = StringName(str(wp["floor"]))
			pos = wp["pos"]
			route.pop_front()
			floor_changed.emit(self, floor_id)
			continue
		var target: Vector2 = wp["pos"]
		var to: Vector2 = target - pos
		var d: float = to.length()
		if d <= budget:
			pos = target
			budget -= d
			route.pop_front()
			if d > 0.0001:
				facing = to / d
		else:
			var dir: Vector2 = to / d
			pos += dir * budget
			facing = dir
			budget = 0.0
	if route.is_empty():
		moving = false
		outside = false
		arrived = true
	if not outside:
		_watchdog(dt, world)
	return arrived


func _watchdog(dt: float, world: WorldManager) -> void:
	if not moving:
		_stuck_time = 0.0
		_last_pos = pos
		return
	if pos.distance_squared_to(_last_pos) > 0.0001:
		_stuck_time = 0.0
		_last_pos = pos
		return
	_stuck_time += dt
	if _stuck_time < DataRegistry.balf("player.stuck_watchdog_seconds"):
		return
	_stuck_time = 0.0
	# 1. Repath. 2. Bila gagal, pindah aman ke sel valid terdekat. Barang bawaan tidak dihapus.
	if not go_to(world, goal_floor, goal_cell):
		var c: Vector2i = world.nearest_walkable(floor_id, cell(), nav_class)
		if c.x >= 0:
			pos = GridMath.cell_center(c)
		GameLogger.warn("NAV", "actor %s recovered from a stuck path" % id)


## Repath setelah layout berubah (GDD 17.5).
func repath(world: WorldManager) -> void:
	if outside:
		return
	if goal_cell.x >= 0 and not route.is_empty():
		go_to(world, goal_floor, goal_cell)


func to_dict() -> Dictionary:
	return {
		"id": String(id), "kind": String(kind), "floor_id": String(floor_id),
		"pos": [pos.x, pos.y], "facing": [facing.x, facing.y], "state": String(state),
		"goal_floor": String(goal_floor), "goal_cell": [goal_cell.x, goal_cell.y],
		"carried": carried, "visual_seed": visual_seed, "visual_key": String(visual_key),
		"seat_iid": seat_iid,
	}


func apply_dict(d: Dictionary) -> void:
	floor_id = StringName(str(d.get("floor_id", "floor_1")))
	pos = SimManager.arr_to_vec(d.get("pos", [0, 0]))
	facing = SimManager.arr_to_vec(d.get("facing", [0, -1]))
	state = StringName(str(d.get("state", "IDLE")))
	goal_floor = StringName(str(d.get("goal_floor", "")))
	goal_cell = SimManager.arr_to_cell(d.get("goal_cell", [-1, -1]))
	carried = d.get("carried", {})
	seat_iid = int(d.get("seat_iid", -1))
	visual_seed = int(d.get("visual_seed", 0))
	visual_key = StringName(str(d.get("visual_key", "")))
