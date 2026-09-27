class_name QueueLane
extends RefCounted
## Satu jalur antrean (GDD 21.1, 57.6). Kapasitas = jumlah slot; aktor yang
## sedang dilayani berdiri di service point dan sudah melepas slotnya.
##
## `reservations` = token kapasitas yang didapat saat admission (aktor sudah
## "masuk toko"). `line` = aktor yang sudah berdiri di slot, indeks = nomor slot.

const KIND_PHYSICAL: StringName = &"physical"
const KIND_ROTIFOOD: StringName = &"rotifood"

var id: StringName
var kind: StringName = KIND_PHYSICAL
var floor_id: StringName
var counter_id: StringName
var main: bool = false
var slots: Array[Vector2i] = []
var service_point: Vector2i
var cashier_point: Vector2i = Vector2i(-1, -1)
var reservations: Array[StringName] = []
var line: Array[StringName] = []
var service_occupant: StringName = &""


func capacity() -> int:
	return slots.size()


func free_capacity() -> int:
	return maxi(0, slots.size() - reservations.size())


func occupancy_ratio() -> float:
	if slots.is_empty():
		return 0.0
	return float(reservations.size()) / float(slots.size())


func slot_index_of(actor_id: StringName) -> int:
	return line.find(actor_id)


func has_actor(actor_id: StringName) -> bool:
	return reservations.has(actor_id) or line.has(actor_id) or service_occupant == actor_id


func to_dict() -> Dictionary:
	var res: Array = []
	for r: StringName in reservations:
		res.append(String(r))
	var ln: Array = []
	for a: StringName in line:
		ln.append(String(a))
	return {"id": String(id), "reservations": res, "line": ln, "service_occupant": String(service_occupant)}
