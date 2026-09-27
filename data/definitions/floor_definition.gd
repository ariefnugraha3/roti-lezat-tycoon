class_name FloorDefinition
extends RefCounted
## Satu lantai dari template layout kanonik (GDD 57). Koordinat (x,z) tile,
## asal di sudut kiri-bawah; semua rentang di JSON inklusif.

const NONE_CELL: Vector2i = Vector2i(-1, -1)

var id: StringName
var size: Vector2i
## [{type: StringName, rect: Rect2i}]
var zones: Array[Dictionary] = []
var entrance: Array[Vector2i] = []
var protected_cells: Array[Vector2i] = []
var staff_only: Array[Vector2i] = []
var walls: Array[Vector2i] = []
## [{id, type, cells: Array[Vector2i], tablet_cell: Vector2i}]
var counters: Array[Dictionary] = []
## [{id, counter_id, service_point, cashier_point, queue: Array[Vector2i], main}]
var lanes: Array[Dictionary] = []
## {} atau {id, cells, tablet_cell, service_point, queue}
var rotifood_counter: Dictionary = {}
var supply_dropoff: Vector2i = NONE_CELL
var supply_drop_cell: Vector2i = NONE_CELL
## {} atau {cell, access, target_floor}
var portal: Dictionary = {}
## category -> Rect2i zona penempatan yang dianjurkan.
var preferred_zones: Dictionary = {}


static func to_cell(v: Variant) -> Vector2i:
	if v is Array and (v as Array).size() >= 2:
		return Vector2i(int(v[0]), int(v[1]))
	return NONE_CELL


static func to_cells(v: Variant) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if v is Array:
		for c: Variant in v:
			out.append(to_cell(c))
	return out


static func rect_from(v: Variant) -> Rect2i:
	var a: Array = v
	var x0: int = int(a[0])
	var z0: int = int(a[1])
	return Rect2i(x0, z0, int(a[2]) - x0 + 1, int(a[3]) - z0 + 1)


static func from_dict(d: Dictionary) -> FloorDefinition:
	var f := FloorDefinition.new()
	f.id = StringName(str(d.get("id", "")))
	f.size = to_cell(d.get("size", [0, 0]))
	for z: Variant in d.get("zones", []):
		var zd: Dictionary = z
		f.zones.append({"type": StringName(str(zd["type"])), "rect": rect_from(zd["rect"])})
	f.entrance = to_cells(d.get("entrance", []))
	f.protected_cells = to_cells(d.get("protected", []))
	f.staff_only = to_cells(d.get("staff_only", []))
	f.walls = to_cells(d.get("walls", []))
	for c: Variant in d.get("counters", []):
		var cd: Dictionary = c
		f.counters.append({
			"id": StringName(str(cd["id"])),
			"type": StringName(str(cd["type"])),
			"cells": to_cells(cd["cells"]),
			"tablet_cell": to_cell(cd.get("tablet_cell")),
		})
	for l: Variant in d.get("lanes", []):
		var ld: Dictionary = l
		f.lanes.append({
			"id": StringName(str(ld["id"])),
			"counter_id": StringName(str(ld["counter_id"])),
			"service_point": to_cell(ld["service_point"]),
			"cashier_point": to_cell(ld["cashier_point"]),
			"queue": to_cells(ld["queue"]),
			"main": bool(ld.get("main", false)),
		})
	var rc: Variant = d.get("rotifood_counter")
	if rc is Dictionary:
		var rd: Dictionary = rc
		f.rotifood_counter = {
			"id": StringName(str(rd["id"])),
			"cells": to_cells(rd["cells"]),
			"tablet_cell": to_cell(rd.get("tablet_cell")),
			"service_point": to_cell(rd["service_point"]),
			"queue": to_cells(rd["queue"]),
		}
	f.supply_dropoff = to_cell(d.get("supply_dropoff"))
	f.supply_drop_cell = to_cell(d.get("supply_drop_cell"))
	var pd: Variant = d.get("portal")
	if pd is Dictionary:
		var pdd: Dictionary = pd
		f.portal = {
			"cell": to_cell(pdd["cell"]),
			"access": to_cell(pdd["access"]),
			"target_floor": StringName(str(pdd["target_floor"])),
		}
	var pz: Dictionary = d.get("preferred_zones", {})
	for k: Variant in pz.keys():
		f.preferred_zones[StringName(str(k))] = rect_from(pz[k])
	return f


func has_zone(zone_type: StringName) -> bool:
	for z: Dictionary in zones:
		if z["type"] == zone_type:
			return true
	return false


## Jenis zona sebuah sel: &"store", &"kitchen", atau &"" bila di luar zona.
func zone_at(cell: Vector2i) -> StringName:
	for z: Dictionary in zones:
		var r: Rect2i = z["rect"]
		if r.has_point(cell):
			return z["type"]
	return &""


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < size.x and cell.y < size.y


func has_portal() -> bool:
	return not portal.is_empty()


func lane(lane_id: StringName) -> Dictionary:
	for l: Dictionary in lanes:
		if l["id"] == lane_id:
			return l
	return {}


func counter(counter_id: StringName) -> Dictionary:
	for c: Dictionary in counters:
		if c["id"] == counter_id:
			return c
	return {}
