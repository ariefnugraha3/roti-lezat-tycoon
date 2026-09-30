class_name DecorationManager
extends SimManager
## DecorationManager — dekorasi kosmetik milik pemain (GDD 72, 72.1, 72.3, 92.1).
## Murni kosmetik: tidak mengubah demand, rating, kecepatan, atau interaksi.
## Decor Shop hanya aktif after-hours; menata ulang boleh kapan saja.
##
## Aturan slot (GDD 72.3, keputusan maintainer 2026-09-30): semua dekorasi
## dipasang di lantai toko, dan jumlah yang terpasang per jenis dibatasi
## `decor_slots` lokasi (dinding, meja kasir, lantai, karpet). Dekorasi dinding
## dan meja menempati slot DecorSlots; dekorasi lantai satu ubin; karpet jejak
## `overlay_size_tiles`, diputar 90° bila "rot" = 1.

## {uid, deco_id, placed, floor_id, cell:[x,z], slot, rot}
var owned: Array[Dictionary] = []
var next_uid: int = 1
## skin_target / "outfit" / "badge" -> deco_id yang sedang dipakai.
var equipped: Dictionary = {}


func new_game() -> void:
	owned.clear()
	next_uid = 1
	equipped.clear()


func def_of(item: Dictionary) -> MiscDefinitions.DecorationDefinition:
	return DataRegistry.decoration(StringName(str(item["deco_id"])))


func owns(deco_id: StringName) -> bool:
	for o: Dictionary in owned:
		if StringName(str(o["deco_id"])) == deco_id:
			return true
	return false


func item(uid: int) -> Dictionary:
	for o: Dictionary in owned:
		if int(o["uid"]) == uid:
			return o
	return {}


func _add(deco_id: StringName) -> Dictionary:
	var o: Dictionary = {"uid": next_uid, "deco_id": String(deco_id), "placed": false, "floor_id": "floor_1", "cell": [-1, -1], "slot": -1, "rot": 0}
	next_uid += 1
	owned.append(o)
	return o


## Hadiah achievement (GDD 72.1): skin/outfit/badge langsung dipakai.
func grant(deco_id: StringName) -> void:
	var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(deco_id)
	if def == null or owns(deco_id):
		return
	_add(deco_id)
	if def.placement_type == &"outfit" or def.placement_type == &"badge" or def.placement_type == &"skin":
		equip(deco_id)


func can_buy(deco_id: StringName) -> StringName:
	var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(deco_id)
	if def == null or def.source != &"shop":
		return &"invalid"
	if not sim.time.is_after_hours():
		return &"after_hours"
	if (def.placement_type == &"skin") and owns(deco_id):
		return &"owned"
	if not sim.economy.can_afford(def.price_kr):
		return &"kr"
	return &""


func buy(deco_id: StringName) -> StringName:
	var reason: StringName = can_buy(deco_id)
	if reason != &"":
		return reason
	var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(deco_id)
	sim.economy.spend(def.price_kr, &"OTHER_ADJUSTMENT", deco_id, {"decor": true})
	_add(deco_id)
	if def.placement_type == &"skin":
		equip(deco_id)
	SaveManager.request_autosave("decor_purchase")
	return &""


func equip(deco_id: StringName) -> void:
	var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(deco_id)
	if def == null or not owns(deco_id):
		return
	var key: String = String(def.skin_target) if def.placement_type == &"skin" else String(def.placement_type)
	equipped[key] = String(deco_id)
	sim.world.layout_changed.emit()


func placed_count(floor_id: StringName) -> int:
	var n: int = 0
	for o: Dictionary in owned:
		if bool(o["placed"]) and StringName(str(o["floor_id"])) == floor_id and def_of(o).is_placeable():
			n += 1
	return n


func placed_floor_props() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for o: Dictionary in owned:
		if bool(o["placed"]) and def_of(o).placement_type == &"floor_prop":
			out.append({"uid": o["uid"], "floor_id": o["floor_id"], "cell": o["cell"]})
	return out


## Lantai tempat semua dekorasi dipasang (GDD 72.3).
func store_floor() -> StringName:
	return sim.world.location.store_floor()


func type_of(o: Dictionary) -> StringName:
	var def: MiscDefinitions.DecorationDefinition = def_of(o)
	return def.placement_type if def != null else &""


## Batas dekorasi terpasang untuk satu jenis di lokasi ini (GDD 72.3). Dinding
## dan meja juga dibatasi jumlah tempat yang benar-benar ada di templatenya.
func cap(placement_type: StringName) -> int:
	var loc: LocationDefinition = sim.world.location
	if placement_type == &"wall" or placement_type == &"counter_prop":
		return DecorSlots.slots(loc, placement_type).size()
	return loc.decor_slot_count(placement_type)


func placed_of_type(placement_type: StringName, except_uid: int = -1) -> int:
	var n: int = 0
	for o: Dictionary in owned:
		if bool(o["placed"]) and int(o["uid"]) != except_uid and type_of(o) == placement_type:
			n += 1
	return n


## Slot dinding/meja yang boleh dipakai `uid`: slot yang kosong ditambah slot
## yang sedang ia tempati.
func free_slots(placement_type: StringName, uid: int) -> Array[int]:
	var taken: Dictionary = {}
	for o: Dictionary in owned:
		if bool(o["placed"]) and int(o["uid"]) != uid and type_of(o) == placement_type:
			taken[int(o["slot"])] = true
	var out: Array[int] = []
	for i in cap(placement_type):
		if not taken.has(i):
			out.append(i)
	return out


## Barang belum terpasang yang jenisnya sudah penuh di lokasi ini.
func type_full(uid: int) -> bool:
	var o: Dictionary = item(uid)
	if o.is_empty() or bool(o["placed"]):
		return false
	var t: StringName = type_of(o)
	return placed_of_type(t, uid) >= cap(t)


## Tempatkan floor_prop / floor_overlay pada sel (jangkar jejak), atau
## wall/counter_prop pada slot. "" bila berhasil; selain itu kode alasan UI.
func place(uid: int, floor_id: StringName, cell: Vector2i, slot: int) -> StringName:
	var o: Dictionary = item(uid)
	if o.is_empty():
		return &"invalid"
	var reason: StringName = check_place(uid, floor_id, cell, slot, int(o.get("rot", 0)))
	if reason != &"":
		return reason
	o["placed"] = true
	o["floor_id"] = String(floor_id)
	o["cell"] = [cell.x, cell.y]
	o["slot"] = slot
	sim.world.rebuild_occupancy()
	return &""


## "" bila `uid` boleh dipasang di tempat itu dengan putaran `rot` (GDD 72.1,
## 72.3). Barang yang belum terpasang juga harus muat di batas jenisnya.
func check_place(uid: int, floor_id: StringName, cell: Vector2i, slot: int, rot: int) -> StringName:
	var o: Dictionary = item(uid)
	var def: MiscDefinitions.DecorationDefinition = def_of(o) if not o.is_empty() else null
	if def == null or not def.is_placeable():
		return &"invalid"
	if floor_id != store_floor():
		return &"zone"
	var t: StringName = def.placement_type
	if not bool(o["placed"]):
		if placed_count(floor_id) >= DataRegistry.bali("limits.decorations_per_floor"):
			return &"limit"
		if placed_of_type(t, uid) >= cap(t):
			return &"slots_full"
	match t:
		&"floor_prop":
			return sim.world.validate_decor_cell(floor_id, cell, uid)
		&"floor_overlay":
			return validate_overlay(uid, floor_id, cell, rot)
		_:
			if slot < 0 or slot >= cap(t):
				return &"invalid"
			for other: Dictionary in owned:
				if int(other["uid"]) != uid and bool(other["placed"]) and int(other["slot"]) == slot and type_of(other) == t:
					return &"overlap"
	return &""


## Karpet (GDD 72.1 floor_overlay): seluruh jejaknya di zona toko pada lantai
## yang bisa diinjak, tidak di pintu masuk atau pintu tangga, dan tidak menindih
## karpet lain. Karpet tidak memblok apa pun, jadi boleh di jalur dan antrean.
func validate_overlay(uid: int, floor_id: StringName, anchor: Vector2i, rot: int) -> StringName:
	var fg: FloorGrid = sim.world.grid(floor_id)
	var def: MiscDefinitions.DecorationDefinition = def_of(item(uid))
	if fg == null or def == null:
		return &"bounds"
	var others: Dictionary = {}
	for o: Dictionary in owned:
		if bool(o["placed"]) and int(o["uid"]) != uid and type_of(o) == &"floor_overlay":
			for c0: Vector2i in overlay_cells(o):
				others[c0] = true
	for c: Vector2i in DecorSlots.overlay_cells(def, anchor, rot):
		if not fg.in_bounds(c):
			return &"bounds"
		if not fg.is_store(c):
			return &"zone"
		var f: int = fg.flag(c)
		if f == FloorGrid.Flag.FIXED_STRUCTURE or f == FloorGrid.Flag.NON_WALKABLE or fg.is_door(c) \
			or (fg.def.has_portal() and c == Vector2i(fg.def.portal["cell"])) or others.has(c):
			return &"overlap"
	return &""


## Ubin jejak karpet terpasang `o`.
func overlay_cells(o: Dictionary) -> Array[Vector2i]:
	return DecorSlots.overlay_cells(def_of(o), SimManager.arr_to_cell(o["cell"]), int(o.get("rot", 0)))


## Putar karpet 90°. Karpet terpasang berputar di tempat (jejak barunya dicoba
## dari ubin yang sama, lalu geser satu ubin); gagal = alasan, putaran tetap.
func rotate_overlay(uid: int) -> StringName:
	var o: Dictionary = item(uid)
	if o.is_empty() or type_of(o) != &"floor_overlay":
		return &"invalid"
	var old_rot: int = int(o.get("rot", 0))
	var new_rot: int = (old_rot + 1) % 2
	if not bool(o["placed"]):
		o["rot"] = new_rot
		return &""
	var fid: StringName = StringName(str(o["floor_id"]))
	var anchor: Vector2i = SimManager.arr_to_cell(o["cell"])
	var d: Vector2i = DecorSlots.overlay_footprint(def_of(o), old_rot) - DecorSlots.overlay_footprint(def_of(o), new_rot)
	var reason: StringName = &""
	for cand: Vector2i in [anchor, anchor + Vector2i(d.x, 0), anchor + Vector2i(0, d.y), anchor + d]:
		reason = validate_overlay(uid, fid, cand, new_rot)
		if reason == &"":
			o["rot"] = new_rot
			o["cell"] = [cand.x, cand.y]
			sim.world.layout_changed.emit()
			return &""
	return reason


func put_away(uid: int) -> void:
	var o: Dictionary = item(uid)
	if o.is_empty():
		return
	o["placed"] = false
	sim.world.rebuild_occupancy()


## Kembalikan ke inventaris setiap dekorasi yang tidak lagi sah (GDD 72.3,
## 105.4): bukan di lantai toko, melebihi batas jenisnya, slotnya di luar slot
## lokasi atau dipakai dua kali, atau ubin/jejaknya tidak sah lagi. Dijalankan
## sesudah load dan pindah lokasi. Diperiksa berurutan menurut uid, jadi
## dekorasi yang lebih dulu dimiliki yang bertahan. Mengembalikan jumlah yang
## disimpan.
func enforce_rules() -> int:
	var pending: Array[Dictionary] = []
	for o: Dictionary in owned:
		if bool(o["placed"]):
			pending.append(o)
			o["placed"] = false
	if pending.is_empty():
		return 0
	pending.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["uid"]) < int(b["uid"]))
	# Dekorasi lantai dilepas dari peta ubin dulu, lalu dipasang lagi satu per satu.
	for o2: Dictionary in pending:
		var fg0: FloorGrid = sim.world.grid(StringName(str(o2["floor_id"])))
		var c2: Vector2i = SimManager.arr_to_cell(o2["cell"])
		if fg0 != null and int(fg0.decor_at.get(c2, -1)) == int(o2["uid"]):
			fg0.decor_at.erase(c2)
	var removed: int = 0
	var props_removed: bool = false
	for o3: Dictionary in pending:
		var fid: StringName = StringName(str(o3["floor_id"]))
		var cell: Vector2i = SimManager.arr_to_cell(o3["cell"])
		var reason: StringName = check_place(int(o3["uid"]), fid, cell, int(o3["slot"]), int(o3.get("rot", 0)))
		if reason == &"":
			o3["placed"] = true
			if type_of(o3) == &"floor_prop":
				sim.world.grid(fid).decor_at[cell] = int(o3["uid"])
		else:
			removed += 1
			props_removed = props_removed or type_of(o3) == &"floor_prop"
			GameLogger.info("DECOR", "%s put away: %s" % [o3["deco_id"], reason])
	if props_removed:
		sim.world.rebuild_occupancy()
	elif removed > 0:
		sim.world.layout_changed.emit()
	return removed


func capture() -> Dictionary:
	return {"owned": owned.duplicate(true), "next_uid": next_uid, "equipped": equipped.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	for o: Variant in d.get("owned", []):
		var od: Dictionary = (o as Dictionary).duplicate()
		if DataRegistry.decoration(StringName(str(od.get("deco_id", "")))) == null:
			continue
		owned.append(od)
	next_uid = int(d.get("next_uid", 1))
	equipped = (d.get("equipped", {}) as Dictionary).duplicate()
