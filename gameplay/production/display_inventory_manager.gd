class_name DisplayInventoryManager
extends SimManager
## DisplayInventoryManager — pemilik stok roti di rak dan resep tiap petak
## (GDD idle 4.2, 4.6, 8.2; v3.1 19, 85, 98).
##
## Setiap petak menjual satu resep: resep yang dipilih pemain di layar Menu,
## atau "Auto" = resep terbuka yang paling menguntungkan
## (`SimulationRoot.auto_recipe`). Mengganti resep petak tidak membuang roti:
## petak menjual habis roti lama, baru kemudian diisi resep baru. Roti tidak
## menua dan tidak basi. Pengambilan selalu FIFO.
##
## "Lot" = potongan stack yang sedang dipegang pelanggan atau pesanan RotiFood:
## {stack: BreadStack (salinan), display_id, slot_index, unit_price}.

## iid (int) -> {"tier": int, "slots": Array[{"recipe": StringName, "stacks": Array[BreadStack], "assign": StringName}]}
## `recipe` = resep roti yang sedang ada di petak; `assign` = resep pilihan
## pemain, atau &"" untuk Auto.
var displays: Dictionary = {}


func new_game() -> void:
	displays.clear()


## Rak `iid` dengan model tier `tier`: jumlah petaknya mengikuti model itu
## (evolusi menambah petak, GDD idle 8.2). Petak lama dan pilihannya tetap.
func ensure_display(iid: int, tier: int) -> void:
	var def: EquipmentDefinition = DataRegistry.equipment_for(&"display", tier)
	if displays.has(iid):
		var d: Dictionary = displays[iid]
		d["tier"] = tier
		var slots_a: Array = d["slots"]
		while slots_a.size() < def.slot_count:
			slots_a.append({"recipe": &"", "stacks": [], "assign": &""})
		return
	var new_slots: Array = []
	for i in def.slot_count:
		new_slots.append({"recipe": &"", "stacks": [], "assign": &""})
	displays[iid] = {"tier": tier, "slots": new_slots}


func remove_display(iid: int) -> void:
	displays.erase(iid)


func has_display(iid: int) -> bool:
	return displays.has(iid)


func display_ids() -> Array:
	var ids: Array = displays.keys()
	ids.sort()
	return ids


func tier_of(iid: int) -> int:
	return int((displays.get(iid, {}) as Dictionary).get("tier", 1))


func slots(iid: int) -> Array:
	return (displays.get(iid, {"slots": []}) as Dictionary)["slots"]


func slot_count(iid: int) -> int:
	return slots(iid).size()


func slot_units(iid: int, index: int) -> int:
	var sl: Array = slots(iid)
	if index < 0 or index >= sl.size():
		return 0
	var n: int = 0
	for st: BreadStack in (sl[index] as Dictionary)["stacks"]:
		n += st.quantity
	return n


## Resep roti yang sedang ada di petak (&"" bila kosong).
func slot_content(iid: int, index: int) -> StringName:
	var sl: Array = slots(iid)
	if index < 0 or index >= sl.size() or slot_units(iid, index) <= 0:
		return &""
	return StringName((sl[index] as Dictionary)["recipe"])


func used(iid: int) -> int:
	var n: int = 0
	for i in slots(iid).size():
		n += slot_units(iid, i)
	return n


## Unit per petak rak `iid` dari level raknya (GDD idle 8.2).
func slot_capacity(iid: int) -> int:
	return sim.upgrades.slot_capacity(iid)


func capacity(iid: int) -> int:
	return slot_capacity(iid) * slot_count(iid)


func free_units(iid: int) -> int:
	return maxi(0, capacity(iid) - used(iid))


func total_units() -> int:
	var n: int = 0
	for iid: Variant in displays.keys():
		n += used(int(iid))
	return n


# ===========================================================================
# RESEP PETAK (GDD idle 4.2)
# ===========================================================================

## Pilihan pemain untuk petak itu: resep, atau &"" untuk Auto.
func assignment(iid: int, index: int) -> StringName:
	var sl: Array = slots(iid)
	if index < 0 or index >= sl.size():
		return &""
	return StringName((sl[index] as Dictionary).get("assign", &""))


## Menu: tetapkan resep petak (&"" = Auto). Resep harus sudah dibuka dan bisa
## dibuat alat yang ada (GDD idle 4.2). Mengembalikan false bila ditolak.
func set_assignment(iid: int, index: int, recipe_id: StringName) -> bool:
	var sl: Array = slots(iid)
	if index < 0 or index >= sl.size():
		return false
	if recipe_id != &"" and not sim.can_make(recipe_id):
		return false
	(sl[index] as Dictionary)["assign"] = recipe_id
	EventBus.slot_recipes_changed.emit(iid)
	return true


## Resep yang sedang dijual petak itu: pilihan pemain, atau resep Auto. &"" bila
## tidak ada resep yang bisa dibuat.
func effective_recipe(iid: int, index: int) -> StringName:
	var a: StringName = assignment(iid, index)
	if a != &"" and sim.can_make(a):
		return a
	if a != &"":
		return &""
	return sim.auto_recipe()


## Berapa unit `recipe` yang masih bisa masuk ke petak itu. Petak yang masih
## berisi resep lain tidak menerima apa pun sampai kosong.
func slot_room(iid: int, index: int, recipe: StringName) -> int:
	var sl: Array = slots(iid)
	if index < 0 or index >= sl.size():
		return 0
	var units: int = slot_units(iid, index)
	if units > 0 and StringName((sl[index] as Dictionary)["recipe"]) != recipe:
		return 0
	return maxi(0, slot_capacity(iid) - units)


## Menaruh roti ke satu petak. Mengembalikan jumlah yang benar-benar masuk.
func place(iid: int, index: int, recipe_id: StringName, qty: int, produced_at: float, job_id: int) -> int:
	var n: int = mini(slot_room(iid, index, recipe_id), qty)
	if n <= 0:
		return 0
	var s: Dictionary = slots(iid)[index]
	s["recipe"] = recipe_id
	var stacks: Array = s["stacks"]
	for st: BreadStack in stacks:
		if st.source_job_id == job_id:
			st.quantity += n
			EventBus.bread_added_to_display.emit(iid, recipe_id, n)
			return n
	var b := BreadStack.new()
	b.recipe_id = recipe_id
	b.quantity = n
	b.slot_id = StringName("%d:%d" % [iid, index])
	b.source_job_id = job_id
	b.produced_at_game_time = produced_at
	stacks.append(b)
	EventBus.bread_added_to_display.emit(iid, recipe_id, n)
	return n


# ===========================================================================
# STOK & PENGAMBILAN
# ===========================================================================

## Stok per resep di semua rak.
func sellable_by_recipe() -> Dictionary:
	var out: Dictionary = {}
	for iid: Variant in displays.keys():
		for s: Dictionary in slots(int(iid)):
			for st: BreadStack in s["stacks"]:
				if st.quantity > 0:
					out[st.recipe_id] = int(out.get(st.recipe_id, 0)) + st.quantity
	return out


func sellable_count(recipe_id: StringName) -> int:
	return int(sellable_by_recipe().get(recipe_id, 0))


func total_sellable() -> int:
	return total_units()


func has_any_sellable() -> bool:
	return total_units() > 0


## Unit `recipe_id` di semua rak (atau satu rak saja).
func count_recipe(recipe_id: StringName, only_iid: int = -1) -> int:
	var n: int = 0
	for iid: Variant in display_ids():
		if only_iid >= 0 and int(iid) != only_iid:
			continue
		for s: Dictionary in slots(int(iid)):
			for st: BreadStack in s["stacks"]:
				if st.recipe_id == recipe_id:
					n += st.quantity
	return n


## Ambil `qty` unit FIFO (produced_at tertua). Atomik: hanya mengambil bila
## seluruh `qty` tersedia, kecuali `allow_partial`. Mengembalikan daftar lot.
func take(recipe_id: StringName, qty: int, only_iid: int, unit_price: float, allow_partial: bool = false) -> Array[Dictionary]:
	var cands: Array[Dictionary] = []
	for iid: Variant in display_ids():
		if only_iid >= 0 and int(iid) != only_iid:
			continue
		var sl: Array = slots(int(iid))
		for i in sl.size():
			for st: BreadStack in (sl[i] as Dictionary)["stacks"]:
				if st.recipe_id == recipe_id and st.quantity > 0:
					cands.append({"display_id": int(iid), "slot_index": i, "stack": st})
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var sa: BreadStack = a["stack"]
		var sb: BreadStack = b["stack"]
		if sa.produced_at_game_time != sb.produced_at_game_time:
			return sa.produced_at_game_time < sb.produced_at_game_time
		if int(a["display_id"]) != int(b["display_id"]):
			return int(a["display_id"]) < int(b["display_id"])
		return int(a["slot_index"]) < int(b["slot_index"]))
	var avail: int = 0
	for c: Dictionary in cands:
		avail += (c["stack"] as BreadStack).quantity
	var want: int = qty
	if avail < qty:
		if not allow_partial:
			return []
		want = avail
	var lots: Array[Dictionary] = []
	var left: int = want
	for c2: Dictionary in cands:
		if left <= 0:
			break
		var st: BreadStack = c2["stack"]
		var n: int = mini(left, st.quantity)
		var piece: BreadStack = st.duplicate_stack()
		piece.quantity = n
		st.quantity -= n
		left -= n
		lots.append({"stack": piece, "display_id": c2["display_id"], "slot_index": c2["slot_index"], "unit_price": unit_price})
	_cleanup()
	return lots


## Pengembalian ke rak (v3.1 19.6): petak asal bila masih cocok, lalu petak
## berisi resep sama, lalu petak kosong. Roti tidak pernah hilang: bila semua
## penuh, roti kembali ke petak asal melebihi batas petak.
func return_lots(lots: Array) -> void:
	for l: Variant in lots:
		var lot: Dictionary = l
		var st: BreadStack = lot["stack"]
		if st.quantity <= 0:
			continue
		var iid: int = int(lot.get("display_id", -1))
		var idx: int = int(lot.get("slot_index", -1))
		if not displays.has(iid):
			iid = -1
		var target: Vector2i = Vector2i(-1, -1)
		if iid >= 0 and idx >= 0 and idx < slots(iid).size():
			if slot_content(iid, idx) == st.recipe_id or slot_units(iid, idx) == 0:
				target = Vector2i(iid, idx)
		if target.x < 0:
			target = _find_slot_for(st.recipe_id, st.quantity)
		if target.x < 0 and iid >= 0 and idx >= 0 and idx < slots(iid).size():
			target = Vector2i(iid, idx)
		if target.x < 0:
			target = _any_slot()
		if target.x < 0:
			GameLogger.error("INVENTORY", "no display to return bread to")
			continue
		var slot: Dictionary = slots(target.x)[target.y]
		slot["recipe"] = st.recipe_id
		var back: BreadStack = st.duplicate_stack()
		back.slot_id = StringName("%d:%d" % [target.x, target.y])
		(slot["stacks"] as Array).append(back)
		EventBus.bread_added_to_display.emit(target.x, st.recipe_id, st.quantity)


func _find_slot_for(recipe_id: StringName, qty: int) -> Vector2i:
	for pass_i in 2:
		for iid: Variant in display_ids():
			var sl: Array = slots(int(iid))
			for i in sl.size():
				var units: int = slot_units(int(iid), i)
				var ok: bool = (pass_i == 0 and units > 0 and slot_content(int(iid), i) == recipe_id) or (pass_i == 1 and units == 0)
				if ok and slot_room(int(iid), i, recipe_id) >= qty:
					return Vector2i(int(iid), i)
	return Vector2i(-1, -1)


func _any_slot() -> Vector2i:
	for iid: Variant in display_ids():
		if slots(int(iid)).size() > 0:
			return Vector2i(int(iid), 0)
	return Vector2i(-1, -1)


func _cleanup() -> void:
	for iid: Variant in displays.keys():
		for s: Dictionary in slots(int(iid)):
			var stacks: Array = s["stacks"]
			for i in range(stacks.size() - 1, -1, -1):
				if (stacks[i] as BreadStack).quantity <= 0:
					stacks.remove_at(i)
			if stacks.is_empty():
				s["recipe"] = &""


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	var out: Dictionary = {}
	for iid: Variant in displays.keys():
		var d: Dictionary = displays[iid]
		var sl: Array = []
		for s: Dictionary in d["slots"]:
			var stacks: Array = []
			for st: BreadStack in s["stacks"]:
				stacks.append(st.to_dict())
			sl.append({"recipe": String(s["recipe"]), "stacks": stacks, "assign": String(s.get("assign", &""))})
		out[str(iid)] = {"tier": d["tier"], "slots": sl}
	return out


func restore(d: Dictionary) -> void:
	displays.clear()
	for k: Variant in d.keys():
		var dd: Dictionary = d[k]
		var sl: Array = []
		for s: Variant in dd.get("slots", []):
			var sd: Dictionary = s
			var stacks: Array = []
			for st: Variant in sd.get("stacks", []):
				var b: BreadStack = BreadStack.from_dict(st as Dictionary)
				if DataRegistry.recipe(b.recipe_id) == null:
					GameLogger.error("SAVE", "quarantined bread of unknown recipe %s" % b.recipe_id)
					continue
				stacks.append(b)
			var assign: StringName = StringName(str(sd.get("assign", "")))
			if assign != &"" and DataRegistry.recipe(assign) == null:
				assign = &""
			sl.append({"recipe": StringName(str(sd.get("recipe", ""))), "stacks": stacks, "assign": assign})
		displays[int(str(k))] = {"tier": int(dd.get("tier", 1)), "slots": sl}
	_cleanup()
