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
## [EquipmentInstance, tarif utilitas, kategori] untuk alat terpasang bertarif,
## urut seperti placed_list() supaya jumlahnya identik (GDD 86). Ikut cache daftar.
var _utility_rows: Array = []
var _utility_ready: bool = false


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
## tick oleh produksi, staf, dan UI. Isinya hanya bergantung pada instance yang
## ada, status terpasang, dan kategori model, dan setiap perubahan itu memanggil
## invalidate_lists (langsung atau lewat WorldManager.rebuild_occupancy). Dulu
## cache juga dibuang setiap tick, sehingga setiap tick menyortir dan menyusun
## ulang semua daftar (GDD 109).
func invalidate_lists() -> void:
	_list_cache.clear()
	_utility_ready = false


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


## Replace terhalang (GDD 5.1.2)? Alat berisi job atau yang titik pakainya
## dipesan tidak bisa diganti. Rak berisi roti boleh diganti bila rak baru `def`
## memuat setiap petaknya dan punya tempat sah di lantainya; rotinya ikut pindah
## apa adanya (keputusan maintainer 2026-10-25). Sebelumnya rak tertua, yang
## selalu diisi ulang lebih dulu, bisa berhari-hari tidak dapat diganti.
func replace_blocked(old_iid: int, def: EquipmentDefinition) -> bool:
	if _in_use(old_iid, false):
		return true
	var old: EquipmentInstance = get_inst(old_iid)
	if old == null or old.category() != &"display" or sim.display.used(old_iid) <= 0:
		return false
	if def == null or sim.display.carry_plan(old_iid, def).is_empty():
		return true
	return replacement_spot(old, def).is_empty()


## Tempat rak baru `def` yang menggantikan `old` berisi roti, seolah `old` sudah
## diangkat: tempat lama bila muat, selain itu tempat sah terdekat (jejak T3+
## 2x2 tidak selalu muat di tempat rak 2x1). Rak berisi roti tidak boleh
## menunggu di inventaris. {} bila tidak ada. Tidak mengubah state.
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
	if replace_blocked(old_iid, def):
		return {"ok": false, "reason": "in_use"}
	if not sim.economy.can_afford(def.price_kr):
		return {"ok": false, "reason": "kr"}
	sim.economy.spend(def.price_kr, &"EQUIPMENT_PURCHASE", def_id, {"replaces": old_iid})
	var floor_id: StringName = old.floor_id
	var anchor: Vector2i = old.anchor
	var rot: int = old.rotation
	# Roti rak lama pindah ke rak baru, yang pasti punya tempat (replace_blocked).
	var plan: Dictionary = {}
	if old.category() == &"display" and sim.display.used(old_iid) > 0:
		plan = sim.display.carry_plan(old_iid, def)
		var spot: Dictionary = replacement_spot(old, def)
		floor_id = spot["floor_id"]
		anchor = spot["anchor"]
		rot = int(spot["rot"])
	old.placed = false
	invalidate_lists()
	var e: EquipmentInstance = create_instance(def_id)
	if not plan.is_empty():
		sim.display.carry_bread(old_iid, e.iid, def.tier, plan)
	if old.category() == &"display":
		sim.display.remove_display(old_iid)
		sim.display.ensure_display(old_iid, old.tier())
	sim.world.rebuild_occupancy()
	var reason: StringName = sim.world.validate_placement(e, floor_id, anchor, rot)
	if reason == &"":
		_commit_place(e, floor_id, anchor, rot)
	elif not plan.is_empty():
		GameLogger.error("PRODUCTION", "replacement shelf %d holds bread but cannot stand in place: %s" % [e.iid, reason])
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
	sim.tutorial.on_event(&"furniture_placed")
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
	if not _utility_ready:
		_utility_rows.clear()
		for e0: EquipmentInstance in placed_list():
			var d0: EquipmentDefinition = e0.def()
			if d0.utility_cost_kr_per_ingame_hour > 0.0:
				_utility_rows.append([e0, d0.utility_cost_kr_per_ingame_hour, d0.category_id])
		_utility_ready = true
	for row: Array in _utility_rows:
		var e: EquipmentInstance = row[0]
		var rate: float = row[1]
		match row[2]:
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
