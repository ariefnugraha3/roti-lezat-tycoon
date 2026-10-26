class_name EquipmentManager
extends SimManager
## EquipmentManager — pemilik state perabot: kepemilikan, model, posisi, isi
## (GDD idle 4.1, 8.2, 8.4; v3.1 18.4, 98). Tidak ada Pasar: stasiun tambahan
## dibuka dengan KR (UpgradeManager) dan modelnya berevolusi dari levelnya.
## Meja kasir & meja RotiFood adalah fixture bangunan milik WorldManager.

var instances: Dictionary = {}
var next_iid: int = 1
var _list_cache: Dictionary = {}


func new_game() -> void:
	instances.clear()
	invalidate_lists()
	next_iid = 1


func create_instance(def_id: StringName) -> EquipmentInstance:
	var e := EquipmentInstance.new()
	e.iid = next_iid
	next_iid += 1
	e.def_id = def_id
	e.placed = false
	invalidate_lists()
	instances[e.iid] = e
	if e.category() == &"display":
		sim.display.ensure_display(e.iid, e.tier())
	return e


func get_inst(iid: int) -> EquipmentInstance:
	return instances.get(iid)


## Daftar hasil query di-cache (read-only) karena dipanggil berkali-kali per
## tick oleh produksi, staf, dan UI. Isinya hanya bergantung pada instance yang
## ada, status terpasang, dan kategori model, dan setiap perubahan itu memanggil
## invalidate_lists (langsung atau lewat WorldManager.rebuild_occupancy). Dulu
## cache juga dibuang setiap tick, sehingga setiap tick menyortir dan menyusun
## ulang semua daftar (GDD 109).
func invalidate_lists() -> void:
	_list_cache.clear()


func _cached(key: String) -> Variant:
	return _list_cache.get(key)


func _store(key: String, out: Array[EquipmentInstance]) -> Array[EquipmentInstance]:
	out.make_read_only()
	_list_cache[key] = out
	return out


func all_sorted() -> Array[EquipmentInstance]:
	var hit: Variant = _cached("all")
	if hit != null:
		return hit
	var ids: Array = instances.keys()
	ids.sort()
	var out: Array[EquipmentInstance] = []
	for i: Variant in ids:
		out.append(instances[i])
	return _store("all", out)


func placed_list(category: StringName = &"") -> Array[EquipmentInstance]:
	var key: String = "p:" + String(category)
	var hit: Variant = _cached(key)
	if hit != null:
		return hit
	var out: Array[EquipmentInstance] = []
	for e: EquipmentInstance in all_sorted():
		if e.placed and (category == &"" or e.category() == category):
			out.append(e)
	return _store(key, out)


func unplaced_list(category: StringName = &"") -> Array[EquipmentInstance]:
	var key: String = "u:" + String(category)
	var hit: Variant = _cached(key)
	if hit != null:
		return hit
	var out: Array[EquipmentInstance] = []
	for e: EquipmentInstance in all_sorted():
		if not e.placed and (category == &"" or e.category() == category):
			out.append(e)
	return _store(key, out)


func placed_count(category: StringName) -> int:
	return placed_list(category).size()


func slot_limit(category: StringName) -> int:
	return sim.world.location.slot_count(category)


func storage_instance() -> EquipmentInstance:
	return _fixture(&"storage")


## Meja Tunggu satu-satunya di lokasi ini (v3.1 5.1.3).
func table_instance() -> EquipmentInstance:
	return _fixture(&"table")


func _fixture(category: StringName) -> EquipmentInstance:
	var l: Array[EquipmentInstance] = placed_list(category)
	if not l.is_empty():
		return l[0]
	var u: Array[EquipmentInstance] = unplaced_list(category)
	return u[0] if not u.is_empty() else null


## Gudang, Meja Tunggu, dan kursi koki sepaket dengan bangunan: tidak dijual,
## tidak bisa disimpan, dan tidak memakai slot alat (v3.1 5.1.1, 5.1.3, 5.1.4).
static func is_fixture(category: StringName) -> bool:
	return category == &"storage" or category == &"table" or category == &"chair"


## Alat sedang dipakai: berisi job, roti, atau titik pakainya dipesan.
func is_in_use(iid: int) -> bool:
	return _in_use(iid, true)


## Alat tidak boleh dipindah atau diputar di Decoration Mode (v3.1 72): hanya
## alat yang berisi job atau titik pakainya dipesan. Rak berisi roti boleh
## dipindah dan rotinya ikut pindah, karena toko idle selalu buka.
func move_blocked(iid: int) -> bool:
	return _in_use(iid, false)


## Tempat sah untuk model `def` yang menggantikan model `old` (evolusi, GDD idle
## 8.2), seolah `old` sudah diangkat: tempat lama bila muat, selain itu tempat
## sah terdekat. {} bila tidak ada. Tidak mengubah state.
func replacement_spot(old: EquipmentInstance, def: EquipmentDefinition) -> Dictionary:
	var probe := EquipmentInstance.new()
	probe.iid = old.iid
	probe.def_id = def.id
	probe.floor_id = old.floor_id
	probe.anchor = old.anchor
	probe.rotation = old.rotation
	probe.placed = true
	return sim.world.spot_near(probe, old.floor_id, old.anchor, old.rotation)


func _in_use(iid: int, bread_counts: bool) -> bool:
	var e: EquipmentInstance = get_inst(iid)
	if e == null:
		return false
	if e.job_id >= 0:
		return true
	if bread_counts and e.category() == &"display" and sim.display.used(iid) > 0:
		return true
	if sim.world.is_use_point_reserved_for(iid):
		return true
	return false


# ===========================================================================
# PENEMPATAN
# ===========================================================================

func place(iid: int, floor_id: StringName, anchor: Vector2i, rotation: int) -> StringName:
	var e: EquipmentInstance = get_inst(iid)
	if e == null:
		return &"invalid"
	if e.placed and move_blocked(iid):
		return &"in_use"
	if not e.placed and placed_count(e.category()) >= slot_limit(e.category()) and not is_fixture(e.category()):
		return &"slots_full"
	var reason: StringName = sim.world.validate_placement(e, floor_id, anchor, rotation)
	if reason != &"":
		return reason
	_commit_place(e, floor_id, anchor, rotation)
	return &""


func _commit_place(e: EquipmentInstance, floor_id: StringName, anchor: Vector2i, rotation: int) -> void:
	e.floor_id = floor_id
	e.anchor = anchor
	e.rotation = posmod(rotation, 4)
	e.placed = true
	sim.world.rebuild_occupancy()


func capture() -> Dictionary:
	var list: Array = []
	for e: EquipmentInstance in all_sorted():
		list.append(e.to_dict())
	return {"next_iid": next_iid, "items": list}


func restore(d: Dictionary) -> void:
	instances.clear()
	invalidate_lists()
	next_iid = int(d.get("next_iid", 1))
	for item: Variant in d.get("items", []):
		var e: EquipmentInstance = EquipmentInstance.from_dict(item as Dictionary)
		if e.def() == null:
			GameLogger.error("SAVE", "quarantined unknown equipment %s" % e.def_id)
			continue
		instances[e.iid] = e
		next_iid = maxi(next_iid, e.iid + 1)
	invalidate_lists()
