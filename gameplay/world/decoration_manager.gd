class_name DecorationManager
extends SimManager
## DecorationManager — dekorasi kosmetik milik pemain (GDD 72, 72.1, 92.1).
## Murni kosmetik: tidak mengubah demand, rating, kecepatan, atau interaksi.
## Decor Shop hanya aktif after-hours; menata ulang boleh kapan saja.

## {uid, deco_id, placed, floor_id, cell:[x,z], slot}
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
	var o: Dictionary = {"uid": next_uid, "deco_id": String(deco_id), "placed": false, "floor_id": "floor_1", "cell": [-1, -1], "slot": -1}
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


## Tempatkan floor_prop / floor_overlay pada sel, atau wall/counter pada slot.
func place(uid: int, floor_id: StringName, cell: Vector2i, slot: int) -> StringName:
	var o: Dictionary = item(uid)
	if o.is_empty():
		return &"invalid"
	var def: MiscDefinitions.DecorationDefinition = def_of(o)
	if not def.is_placeable():
		return &"invalid"
	var was_here: bool = bool(o["placed"]) and StringName(str(o["floor_id"])) == floor_id
	if not was_here and placed_count(floor_id) >= DataRegistry.bali("limits.decorations_per_floor"):
		return &"limit"
	match def.placement_type:
		&"floor_prop":
			var reason: StringName = sim.world.validate_decor_cell(floor_id, cell, uid)
			if reason != &"":
				return reason
		&"floor_overlay":
			var fg: FloorGrid = sim.world.grid(floor_id)
			if fg == null or not fg.in_bounds(cell) or not fg.is_store(cell):
				return &"zone"
		&"wall", &"counter_prop":
			for other: Dictionary in owned:
				if int(other["uid"]) != uid and bool(other["placed"]) and int(other["slot"]) == slot \
					and StringName(str(other["floor_id"])) == floor_id and def_of(other).placement_type == def.placement_type:
					return &"overlap"
	o["placed"] = true
	o["floor_id"] = String(floor_id)
	o["cell"] = [cell.x, cell.y]
	o["slot"] = slot
	sim.world.rebuild_occupancy()
	return &""


func put_away(uid: int) -> void:
	var o: Dictionary = item(uid)
	if o.is_empty():
		return
	o["placed"] = false
	sim.world.rebuild_occupancy()


## Pindah lokasi: dekorasi yang tidak lagi sah kembali ke inventaris (GDD 105.4).
func revalidate_after_migration() -> void:
	for o: Dictionary in owned:
		if not bool(o["placed"]):
			continue
		var fid: StringName = StringName(str(o["floor_id"]))
		if sim.world.grid(fid) == null:
			o["placed"] = false
			continue
		if def_of(o).placement_type == &"floor_prop":
			o["placed"] = false
			var reason: StringName = sim.world.validate_decor_cell(fid, SimManager.arr_to_cell(o["cell"]), int(o["uid"]))
			o["placed"] = reason == &""
	sim.world.rebuild_occupancy()


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
