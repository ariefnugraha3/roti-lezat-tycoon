class_name QueueManager
extends SimManager
## QueueManager — satu-satunya pemilik occupancy antrean fisik & RotiFood
## (GDD 17.6, 20.5, 21, 57.6, 84.4, 98).
##
## Invarian (TEST_QUEUE_001): satu aktor per slot, tidak ada aktor tanpa slot,
## tidak ada spawn baru ketika kapasitas lane tujuan habis.

signal queue_slot_freed()

var lanes: Array[QueueLane] = []
var rotifood_lane: QueueLane = null
var highest_occupancy_today: int = 0


func build_from_location() -> void:
	lanes.clear()
	rotifood_lane = null
	var loc: LocationDefinition = sim.world.location
	for f: FloorDefinition in loc.floors:
		for ld: Dictionary in f.lanes:
			var l := QueueLane.new()
			l.id = ld["id"]
			l.kind = QueueLane.KIND_PHYSICAL
			l.floor_id = f.id
			l.counter_id = ld["counter_id"]
			l.main = bool(ld["main"])
			l.slots = ld["queue"]
			l.service_point = ld["service_point"]
			l.cashier_point = ld["cashier_point"]
			lanes.append(l)
		if not f.rotifood_counter.is_empty():
			var r := QueueLane.new()
			r.id = &"rotifood"
			r.kind = QueueLane.KIND_ROTIFOOD
			r.floor_id = f.id
			r.counter_id = f.rotifood_counter["id"]
			r.slots = f.rotifood_counter["queue"]
			r.service_point = f.rotifood_counter["service_point"]
			rotifood_lane = r


func new_game() -> void:
	build_from_location()
	highest_occupancy_today = 0


func lane(lane_id: StringName) -> QueueLane:
	if rotifood_lane != null and rotifood_lane.id == lane_id:
		return rotifood_lane
	for l: QueueLane in lanes:
		if l.id == lane_id:
			return l
	return null


func main_lane() -> QueueLane:
	for l: QueueLane in lanes:
		if l.main:
			return l
	return lanes[0] if not lanes.is_empty() else null


## Lane fisik terbuka (GDD 21.2, 57.6): lane dengan Asisten Kasir bertugas,
## atau lane utama bila tidak ada asisten sama sekali (pemain melayani).
func is_open(l: QueueLane) -> bool:
	if l.kind == QueueLane.KIND_ROTIFOOD:
		return true
	if sim.staff.cashier_for_lane(l.id) != null:
		return true
	return l.main and not sim.staff.any_cashier_working()


func open_physical_lanes() -> Array[QueueLane]:
	var out: Array[QueueLane] = []
	for l: QueueLane in lanes:
		if is_open(l):
			out.append(l)
	return out


## Lane tujuan driver: meja RotiFood Tier 3+ (selalu aktif), atau lane utama.
func driver_lane() -> QueueLane:
	if rotifood_lane != null:
		return rotifood_lane
	return main_lane()


func physical_free_capacity() -> int:
	var n: int = 0
	for l: QueueLane in open_physical_lanes():
		n += l.free_capacity()
	return n


func physical_capacity_open() -> int:
	var n: int = 0
	for l: QueueLane in open_physical_lanes():
		n += l.capacity()
	return n


## Estimasi total waktu tunggu (GDD 84.4) untuk satu arketipe.
func estimated_wait(l: QueueLane, archetype: StringName, walk_seconds: float) -> float:
	var t: float = sim.cashier.remaining_time(l)
	for a: StringName in l.reservations:
		t += sim.cashier.expected_service_seconds(l, sim.customers.archetype_of(a))
	t += sim.cashier.expected_service_seconds(l, archetype)
	return t + walk_seconds


## Pilih lane dengan estimasi tunggu terendah di antara lane terbuka yang masih
## punya slot; tie-breaker: antrean lebih pendek, jarak lebih dekat, lane_id kecil.
func choose_physical_lane(archetype: StringName, from_cell: Vector2i, speed_mps: float) -> QueueLane:
	var best: QueueLane = null
	var best_key: Array = []
	for l: QueueLane in open_physical_lanes():
		if l.free_capacity() <= 0:
			continue
		var tail: Vector2i = l.slots[mini(l.reservations.size(), l.slots.size() - 1)]
		var dist_m: float = GridMath.tiles_to_meters(float(GridMath.manhattan(from_cell, tail)))
		var walk: float = dist_m / maxf(speed_mps, 0.1)
		var key: Array = [estimated_wait(l, archetype, walk), l.reservations.size(), dist_m, String(l.id)]
		if best == null or _key_less(key, best_key):
			best = l
			best_key = key
	return best


func _key_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] < b[i]:
			return true
		if a[i] > b[i]:
			return false
	return false


func reserve(l: QueueLane, actor_id: StringName) -> bool:
	if l.free_capacity() <= 0 or l.has_actor(actor_id):
		return false
	l.reservations.append(actor_id)
	_track_occupancy()
	return true


## Aktor tiba di ekor antrean: menempati slot pertama yang kosong.
func join_line(l: QueueLane, actor_id: StringName) -> int:
	if not l.reservations.has(actor_id):
		return -1
	if not l.line.has(actor_id):
		l.line.append(actor_id)
	return l.line.find(actor_id)


func slot_cell(l: QueueLane, index: int) -> Vector2i:
	return l.slots[clampi(index, 0, l.slots.size() - 1)]


## Aktor terdepan pindah ke service point dan melepas slotnya (GDD 57.6).
func advance_to_service(l: QueueLane, actor_id: StringName) -> bool:
	if l.service_occupant != &"" or l.line.is_empty() or l.line[0] != actor_id:
		return false
	l.line.pop_front()
	l.reservations.erase(actor_id)
	l.service_occupant = actor_id
	queue_slot_freed.emit()
	return true


## Keluarkan aktor dari lane mana pun (selesai, kabur, tutup toko).
func release(actor_id: StringName) -> void:
	var freed: bool = false
	for l: QueueLane in all_lanes():
		if l.reservations.has(actor_id):
			l.reservations.erase(actor_id)
			freed = true
		if l.line.has(actor_id):
			l.line.erase(actor_id)
		if l.service_occupant == actor_id:
			l.service_occupant = &""
	if freed:
		queue_slot_freed.emit()


func all_lanes() -> Array[QueueLane]:
	var out: Array[QueueLane] = lanes.duplicate()
	if rotifood_lane != null:
		out.append(rotifood_lane)
	return out


func lane_of(actor_id: StringName) -> QueueLane:
	for l: QueueLane in all_lanes():
		if l.has_actor(actor_id):
			return l
	return null


func _track_occupancy() -> void:
	var n: int = 0
	for l: QueueLane in all_lanes():
		n += l.reservations.size()
	highest_occupancy_today = maxi(highest_occupancy_today, n)
	sim.statistics.note_queue_occupancy(n)


## Pemeriksaan invarian untuk test & debug (GDD 94 no. 6).
func check_invariants() -> String:
	for l: QueueLane in all_lanes():
		var seen: Dictionary = {}
		for a: StringName in l.line:
			if seen.has(a):
				return "duplicate occupant %s in %s" % [a, l.id]
			seen[a] = true
			if not l.reservations.has(a):
				return "occupant %s without reservation in %s" % [a, l.id]
		if l.line.size() > l.slots.size():
			return "lane %s over capacity" % l.id
		if l.reservations.size() > l.slots.size():
			return "lane %s reservations over capacity" % l.id
	return ""


func capture() -> Dictionary:
	var out: Dictionary = {}
	for l: QueueLane in all_lanes():
		out[String(l.id)] = l.to_dict()
	return {"lanes": out, "highest_occupancy_today": highest_occupancy_today}


## Antrean direkonstruksi dari daftar logis; aktor ditempatkan ulang ke slot
## kanonik oleh CustomerManager/RotiFoodManager (GDD 77.2).
func restore(d: Dictionary) -> void:
	build_from_location()
	highest_occupancy_today = int(d.get("highest_occupancy_today", 0))
	var ld: Dictionary = d.get("lanes", {})
	for l: QueueLane in all_lanes():
		var src: Variant = ld.get(String(l.id))
		if not src is Dictionary:
			continue
		for r: Variant in (src as Dictionary).get("reservations", []):
			if l.reservations.size() < l.slots.size():
				l.reservations.append(StringName(str(r)))
		for a: Variant in (src as Dictionary).get("line", []):
			if l.reservations.has(StringName(str(a))):
				l.line.append(StringName(str(a)))
		l.service_occupant = StringName(str((src as Dictionary).get("service_occupant", "")))
