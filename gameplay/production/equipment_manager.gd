class_name EquipmentManager
extends SimManager
## EquipmentManager — pemilik state perabot: kepemilikan, posisi, isi (GDD 5.1.2,
## 18.4, 86, 98). Meja kasir & meja RotiFood adalah fixture bangunan milik
## WorldManager, bukan instance di sini.

var instances: Dictionary = {}
var next_iid: int = 1
## Biaya utilitas berjalan hari ini (float; dibulatkan saat settlement, GDD 86).
var utility_today: float = 0.0
var _list_cache: Dictionary = {}
var _cache_stamp: float = -1.0


func new_game() -> void:
	instances.clear()
	invalidate_lists()
	next_iid = 1
	utility_today = 0.0


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
## tick oleh produksi, staf, dan UI. Cache dikosongkan pada setiap perubahan
## perabot (invalidate_lists) dan setiap kali jam simulasi bergerak.
func invalidate_lists() -> void:
	_list_cache.clear()


func _cached(key: String) -> Variant:
	if sim.time.sim_seconds != _cache_stamp:
		_list_cache.clear()
		_cache_stamp = sim.time.sim_seconds
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


## Meja Tunggu satu-satunya di lokasi ini (GDD 5.1.3).
func table_instance() -> EquipmentInstance:
	return _fixture(&"table")


func _fixture(category: StringName) -> EquipmentInstance:
	var l: Array[EquipmentInstance] = placed_list(category)
	if not l.is_empty():
		return l[0]
	var u: Array[EquipmentInstance] = unplaced_list(category)
	return u[0] if not u.is_empty() else null


## Gudang, Meja Tunggu, dan kursi koki sepaket dengan bangunan: tidak dijual,
## tidak bisa disimpan, dan tidak memakai slot alat (GDD 5.1.1, 5.1.3, 5.1.4).
static func is_fixture(category: StringName) -> bool:
	return category == &"storage" or category == &"table" or category == &"chair"


## Tier tertinggi alat terpasang per kategori (syarat resep, GDD 61.1).
func best_tier(category: StringName) -> int:
	var best: int = 0
	for e: EquipmentInstance in placed_list(category):
		best = maxi(best, e.tier())
	return best


## Alat sedang dipakai: berisi job, roti, atau tray (GDD 5.1.2, 72).
func is_in_use(iid: int) -> bool:
	return _in_use(iid, true)


## Alat tidak boleh dipindah atau diputar di Decoration Mode (GDD 72). Sama
## dengan is_in_use, kecuali roti di rak display: selama toko tidak buka, rak
## yang berisi roti boleh dipindah dan rotinya ikut pindah (keputusan
## maintainer 2026-10-04). Simpan, ganti, dan jual tetap memakai is_in_use.
func move_blocked(iid: int) -> bool:
	return _in_use(iid, sim.time.is_open())


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
# PASAR: BELI / GANTI / JUAL (GDD 5.1.2)
# ===========================================================================

func market_open_for_equipment() -> bool:
	return sim.time.is_after_hours()


## Pasar hanya menjual alat setinggi tier lokasi (GDD 5.1.2). Alat yang sudah
## dimiliki tidak terpengaruh.
func tier_allowed(def: EquipmentDefinition) -> bool:
	return def != null and def.tier <= sim.world.location.tier


## {ok, reason, iid}. Alat baru masuk unplaced lalu Decoration Mode dibuka.
func buy(def_id: StringName) -> Dictionary:
	var def: EquipmentDefinition = DataRegistry.equipment(def_id)
	if def == null or not def.for_sale:
		return {"ok": false, "reason": "invalid"}
	if not market_open_for_equipment():
		return {"ok": false, "reason": "after_hours"}
	if not tier_allowed(def):
		return {"ok": false, "reason": "tier_locked"}
	if placed_count(def.category_id) + unplaced_list(def.category_id).size() >= slot_limit(def.category_id):
		return {"ok": false, "reason": "slots_full"}
	if not sim.economy.spend(def.price_kr, &"EQUIPMENT_PURCHASE", def_id, {}):
		return {"ok": false, "reason": "kr"}
	var e: EquipmentInstance = create_instance(def_id)
	sim.statistics.note_purchase()
	GameLogger.info("PRODUCTION", "bought %s (iid %d)" % [def_id, e.iid])
	SaveManager.request_autosave("equipment_purchase")
	return {"ok": true, "reason": "", "iid": e.iid}


## Ganti alat terpasang: yang lama pindah ke unplaced (tidak hilang). Alat baru
## langsung menempati posisi lama bila footprint-nya sah di sana.
func buy_replace(def_id: StringName, old_iid: int) -> Dictionary:
	var def: EquipmentDefinition = DataRegistry.equipment(def_id)
	var old: EquipmentInstance = get_inst(old_iid)
	if def == null or old == null or old.category() != def.category_id or not old.placed:
		return {"ok": false, "reason": "invalid"}
	if not market_open_for_equipment():
		return {"ok": false, "reason": "after_hours"}
	if not tier_allowed(def):
		return {"ok": false, "reason": "tier_locked"}
	if is_in_use(old_iid):
		return {"ok": false, "reason": "in_use"}
	if not sim.economy.can_afford(def.price_kr):
		return {"ok": false, "reason": "kr"}
	sim.economy.spend(def.price_kr, &"EQUIPMENT_PURCHASE", def_id, {"replaces": old_iid})
	var floor_id: StringName = old.floor_id
	var anchor: Vector2i = old.anchor
	var rot: int = old.rotation
	old.placed = false
	invalidate_lists()
	if old.category() == &"display":
		sim.display.remove_display(old_iid)
		sim.display.ensure_display(old_iid, old.tier())
	var e: EquipmentInstance = create_instance(def_id)
	sim.world.rebuild_occupancy()
	var reason: StringName = sim.world.validate_placement(e, floor_id, anchor, rot)
	if reason == &"":
		_commit_place(e, floor_id, anchor, rot)
	sim.statistics.note_purchase()
	SaveManager.request_autosave("equipment_replace")
	return {"ok": true, "reason": "", "iid": e.iid, "placed": e.placed}


func sell_value(iid: int) -> float:
	var e: EquipmentInstance = get_inst(iid)
	if e == null:
		return 0.0
	return Money.round_half_up(e.def().price_kr * DataRegistry.equipment_sell_ratio())


## Jual alat yang tidak terpasang seharga 50% (GDD 5.1.2). Tier 1 bernilai 0.
func sell(iid: int) -> Dictionary:
	var e: EquipmentInstance = get_inst(iid)
	if e == null or e.placed or is_fixture(e.category()):
		return {"ok": false, "reason": "invalid"}
	if not market_open_for_equipment():
		return {"ok": false, "reason": "after_hours"}
	if is_in_use(iid):
		return {"ok": false, "reason": "in_use"}
	var value: float = sell_value(iid)
	if value > 0.0:
		sim.economy.credit(value, &"EQUIPMENT_SALE", e.def_id, {"iid": iid})
	instances.erase(iid)
	invalidate_lists()
	if e.category() == &"display":
		sim.display.remove_display(iid)
	SaveManager.request_autosave("equipment_sale")
	return {"ok": true, "reason": "", "value": value}


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


## Simpan (Put Away) di Decoration Mode.
func put_away(iid: int) -> StringName:
	var e: EquipmentInstance = get_inst(iid)
	if e == null or not e.placed:
		return &"invalid"
	if is_fixture(e.category()):
		return &"invalid"
	if is_in_use(iid):
		return &"in_use"
	e.placed = false
	sim.world.rebuild_occupancy()
	return &""


# ===========================================================================
# UTILITAS (GDD 86)
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	var hours: float = sim.time.ingame_hours(dt)
	for e: EquipmentInstance in placed_list():
		var def: EquipmentDefinition = e.def()
		var rate: float = def.utility_cost_kr_per_ingame_hour
		if rate <= 0.0:
			continue
		match def.category_id:
			&"mixer":
				if e.job_id >= 0 and sim.production.job_stage(e.job_id) == ProductionJob.MIXING:
					utility_today += rate * hours
			&"oven":
				if e.job_id >= 0 and sim.production.oven_is_hot(e.job_id):
					utility_today += rate * hours
			&"display":
				# Display bertenaga T3-T5 menyala 05:00-18:00 (GDD 86.3).
				utility_today += rate * hours


func reset_day() -> void:
	utility_today = 0.0


func capture() -> Dictionary:
	var list: Array = []
	for e: EquipmentInstance in all_sorted():
		list.append(e.to_dict())
	return {"next_iid": next_iid, "utility_today": utility_today, "items": list}


func restore(d: Dictionary) -> void:
	instances.clear()
	invalidate_lists()
	next_iid = int(d.get("next_iid", 1))
	utility_today = float(d.get("utility_today", 0.0))
	for item: Variant in d.get("items", []):
		var e: EquipmentInstance = EquipmentInstance.from_dict(item as Dictionary)
		if e.def() == null:
			GameLogger.error("SAVE", "quarantined unknown equipment %s" % e.def_id)
			continue
		instances[e.iid] = e
		next_iid = maxi(next_iid, e.iid + 1)
	invalidate_lists()
