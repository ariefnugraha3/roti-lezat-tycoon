class_name LocationDefinition
extends RefCounted
## Lokasi toko per tier (GDD 6, 57, 101.6).

var id: StringName
var localization_key: StringName
var tier: int = 1
var upgrade_cost_kr: float = 0.0
## category -> jumlah slot (mixer, oven, display, cashier).
var slots: Dictionary = {}
## Jenis penempatan dekorasi -> jumlah slot yang boleh dipakai (GDD 72.3):
## wall, counter_prop, floor_prop, floor_overlay.
var decor_slots: Dictionary = {}
var staff_capacity_by_role: Dictionary = {}
var queue_capacity_physical: int = 0
var queue_capacity_rotifood: int = 0
var shared_rotifood_queue: bool = true
var storage_id: StringName
var base_physical_rate: float = 0.0
var base_rotifood_rate: float = 0.0
var active_actor_budget: int = 25
var entrance_floor: StringName
var floors: Array[FloorDefinition] = []
var entrance_cell: Vector2i
var exit_cell: Vector2i


static func from_dict(d: Dictionary) -> LocationDefinition:
	var l := LocationDefinition.new()
	l.id = StringName(str(d.get("id", "")))
	l.localization_key = StringName(str(d.get("localization_key", "")))
	l.tier = int(d.get("tier", 0))
	l.upgrade_cost_kr = float(d.get("upgrade_cost_kr", 0.0))
	var sl: Dictionary = d.get("slots", {})
	for k: Variant in sl.keys():
		l.slots[StringName(str(k))] = int(sl[k])
	var ds: Dictionary = d.get("decor_slots", {})
	for k3: Variant in ds.keys():
		l.decor_slots[StringName(str(k3))] = int(ds[k3])
	var sc: Dictionary = d.get("staff_capacity_by_role", {})
	for k2: Variant in sc.keys():
		l.staff_capacity_by_role[StringName(str(k2))] = int(sc[k2])
	l.queue_capacity_physical = int(d.get("queue_capacity_physical", 0))
	l.queue_capacity_rotifood = int(d.get("queue_capacity_rotifood", 0))
	l.shared_rotifood_queue = bool(d.get("shared_rotifood_queue", true))
	l.storage_id = StringName(str(d.get("storage_id", "")))
	l.base_physical_rate = float(d.get("base_physical_rate", 0.0))
	l.base_rotifood_rate = float(d.get("base_rotifood_rate", 0.0))
	l.active_actor_budget = int(d.get("active_actor_budget", 25))
	l.entrance_floor = StringName(str(d.get("entrance_floor", "floor_1")))
	for f: Variant in d.get("floors", []):
		l.floors.append(FloorDefinition.from_dict(f as Dictionary))
	l.entrance_cell = FloorDefinition.to_cell(d.get("entrance_cell", [0, 0]))
	l.exit_cell = FloorDefinition.to_cell(d.get("exit_cell", [0, 0]))
	return l


func floor_def(floor_id: StringName) -> FloorDefinition:
	for f: FloorDefinition in floors:
		if f.id == floor_id:
			return f
	return null


func slot_count(category: StringName) -> int:
	return int(slots.get(category, 0))


## Slot dekorasi yang boleh dipakai untuk satu jenis penempatan (GDD 72.3).
func decor_slot_count(placement_type: StringName) -> int:
	return int(decor_slots.get(placement_type, 0))


func staff_capacity(role: StringName) -> int:
	return int(staff_capacity_by_role.get(role, 0))


func is_multi_floor() -> bool:
	return floors.size() > 1


## Floor dapur tempat Storage berdiri: floor_2 pada Tier 2-3, floor_1 lainnya.
func kitchen_floor() -> StringName:
	for f: FloorDefinition in floors:
		if f.has_zone(&"kitchen"):
			return f.id
	return floors[0].id


## Floor tempat meja kasir, antrean, dan rak display berada.
func store_floor() -> StringName:
	for f: FloorDefinition in floors:
		if f.has_zone(&"store"):
			return f.id
	return floors[0].id
