class_name DisplayInventoryManager
extends SimManager
## DisplayInventoryManager — pemilik stok roti di rak (GDD 19, 61.3, 85, 98).
##
## Setiap rak universal: satu petak memegang satu resep dalam satu waktu, dengan
## beberapa stack umur/kualitas internal. Pengambilan selalu FIFO (stack tertua
## yang masih sellable). Freshness terpisah dari bake_quality (GDD 19.7).
##
## "Lot" = potongan stack yang sedang dipegang pelanggan/dikemas RotiFood:
## {stack: BreadStack (salinan), display_id, slot_index, unit_price}.

## iid (int) -> {"tier": int, "slots": Array[{"recipe": StringName, "stacks": Array[BreadStack]}]}
var displays: Dictionary = {}
## Penjaga double-aging (GDD 19.9). Disimpan di save sebagai flags.last_freshness_rollover_day.
var last_rollover_day: int = 0


func new_game() -> void:
	displays.clear()
	last_rollover_day = 0


func ensure_display(iid: int, tier: int) -> void:
	var def: EquipmentDefinition = DataRegistry.equipment_for(&"display", tier)
	if displays.has(iid):
		var d: Dictionary = displays[iid]
		d["tier"] = tier
		var slots: Array = d["slots"]
		while slots.size() < def.slot_count:
			slots.append({"recipe": &"", "stacks": []})
		for s: Dictionary in slots:
			for st: BreadStack in s["stacks"]:
				st.display_tier = tier
		return
	var new_slots: Array = []
	for i in def.slot_count:
		new_slots.append({"recipe": &"", "stacks": []})
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


func def_of(iid: int) -> EquipmentDefinition:
	return DataRegistry.equipment_for(&"display", tier_of(iid))


func slots(iid: int) -> Array:
	return (displays.get(iid, {"slots": []}) as Dictionary)["slots"]


func slot_units(iid: int, index: int) -> int:
	var s: Dictionary = slots(iid)[index]
	var n: int = 0
	for st: BreadStack in s["stacks"]:
		n += st.quantity
	return n


func used(iid: int) -> int:
	var n: int = 0
	var sl: Array = slots(iid)
	for i in sl.size():
		n += slot_units(iid, i)
	return n


func capacity(iid: int) -> int:
	var def: EquipmentDefinition = def_of(iid)
	return def.capacity if def != null else 0


func free_units(iid: int) -> int:
	return maxi(0, capacity(iid) - used(iid))


func total_free_units() -> int:
	var n: int = 0
	for iid: Variant in displays.keys():
		n += free_units(int(iid))
	return n


func total_units() -> int:
	var n: int = 0
	for iid: Variant in displays.keys():
		n += used(int(iid))
	return n


## Berapa unit `recipe` yang dapat masuk ke petak `index`.
func slot_room(iid: int, index: int, recipe: StringName) -> int:
	var sl: Array = slots(iid)
	if index < 0 or index >= sl.size():
		return 0
	var s: Dictionary = sl[index]
	if s["recipe"] != &"" and s["recipe"] != recipe and slot_units(iid, index) > 0:
		return 0
	var def: EquipmentDefinition = def_of(iid)
	var per_slot: int = def.max_per_slot - slot_units(iid, index)
	return maxi(0, mini(per_slot, free_units(iid)))


## Menaruh roti matang dari loyang ke satu petak (GDD 19.3, 85). Mengembalikan
## jumlah yang benar-benar masuk. BURNT tidak pernah sampai ke sini. `age_hours`
## = umur yang sudah terkumpul di Meja Tunggu (GDD 19.7.6), 0 untuk loyang lain.
func place(iid: int, index: int, recipe_id: StringName, qty: int, bake_quality: float, produced_at: float, job_id: int, age_hours: float = 0.0) -> int:
	var room: int = slot_room(iid, index, recipe_id)
	var n: int = mini(room, qty)
	if n <= 0:
		return 0
	var s: Dictionary = slots(iid)[index]
	s["recipe"] = recipe_id
	var stacks: Array = s["stacks"]
	# Stack yang sama (satu batch) digabung; batch berbeda tetap terpisah (GDD 19.7.1).
	for st: BreadStack in stacks:
		if st.source_job_id == job_id and absf(st.age_ingame_hours - age_hours) < 0.0001 and absf(st.bake_quality - bake_quality) < 0.0001:
			st.quantity += n
			EventBus.bread_added_to_display.emit(iid, recipe_id, n)
			return n
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	var b := BreadStack.new()
	b.recipe_id = recipe_id
	b.quantity = n
	b.slot_id = StringName("%d:%d" % [iid, index])
	b.source_job_id = job_id
	b.produced_at_game_time = produced_at
	b.bake_quality = bake_quality
	b.age_ingame_hours = age_hours
	b.base_expiry_hours = r.expired_duration_hours
	b.display_tier = tier_of(iid)
	b.refresh_state()
	stacks.append(b)
	EventBus.bread_added_to_display.emit(iid, recipe_id, n)
	return n


## Penempatan otomatis staf: petak dengan resep sama lebih dulu, lalu petak kosong.
func auto_place(recipe_id: StringName, qty: int, bake_quality: float, produced_at: float, job_id: int, preferred_iid: int = -1) -> int:
	var left: int = qty
	var order: Array = display_ids()
	if preferred_iid >= 0 and order.has(preferred_iid):
		order.erase(preferred_iid)
		order.push_front(preferred_iid)
	for pass_i in 2:
		for iid: Variant in order:
			var sl: Array = slots(int(iid))
			for i in sl.size():
				if left <= 0:
					return qty
				var s: Dictionary = sl[i]
				var same: bool = s["recipe"] == recipe_id and slot_units(int(iid), i) > 0
				var empty: bool = slot_units(int(iid), i) == 0
				if (pass_i == 0 and same) or (pass_i == 1 and empty):
					left -= place(int(iid), i, recipe_id, left, bake_quality, produced_at, job_id)
	return qty - left


# ===========================================================================
# STOK & PENGAMBILAN
# ===========================================================================

## Stok sellable per resep di semua rak (untuk ringkasan HUD & demand).
func sellable_by_recipe() -> Dictionary:
	var out: Dictionary = {}
	for iid: Variant in displays.keys():
		for s: Dictionary in slots(int(iid)):
			for st: BreadStack in s["stacks"]:
				if st.is_sellable():
					out[st.recipe_id] = int(out.get(st.recipe_id, 0)) + st.quantity
	return out


func sellable_count(recipe_id: StringName) -> int:
	return int(sellable_by_recipe().get(recipe_id, 0))


func total_sellable() -> int:
	var n: int = 0
	var m: Dictionary = sellable_by_recipe()
	for k: Variant in m.keys():
		n += int(m[k])
	return n


func has_any_sellable() -> bool:
	return total_sellable() > 0


## Semua stack sellable yang lolos `filter` (Callable(BreadStack) -> bool).
func matching_stacks(filter: Callable, only_iid: int = -1) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for iid: Variant in display_ids():
		if only_iid >= 0 and int(iid) != only_iid:
			continue
		var sl: Array = slots(int(iid))
		for i in sl.size():
			for st: BreadStack in (sl[i] as Dictionary)["stacks"]:
				if st.is_sellable() and (not filter.is_valid() or bool(filter.call(st))):
					out.append({"display_id": int(iid), "slot_index": i, "stack": st})
	return out


func count_matching(recipe_id: StringName, filter: Callable, only_iid: int = -1) -> int:
	var n: int = 0
	for m: Dictionary in matching_stacks(filter, only_iid):
		var st: BreadStack = m["stack"]
		if st.recipe_id == recipe_id:
			n += st.quantity
	return n


## Ambil `qty` unit FIFO (produced_at tertua). Atomik: hanya mengambil bila
## seluruh `qty` tersedia, kecuali `allow_partial`. Mengembalikan daftar lot.
func take(recipe_id: StringName, qty: int, filter: Callable, only_iid: int, unit_price: float, allow_partial: bool = false) -> Array[Dictionary]:
	var cands: Array[Dictionary] = []
	for m: Dictionary in matching_stacks(filter, only_iid):
		if (m["stack"] as BreadStack).recipe_id == recipe_id:
			cands.append(m)
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
		lots.append({"stack": piece, "display_id": c2["display_id"], "slot_index": c2["slot_index"], "unit_price": unit_price,
			"taken_at": sim.time.sim_seconds})
	_cleanup()
	return lots


## Pengembalian ke rak (GDD 19.6): petak asal bila masih cocok, lalu petak resep
## sama, lalu petak kosong. Freshness & kualitas TIDAK direset. Roti tidak pernah
## hilang: bila semua penuh, dikembalikan ke petak asal melebihi batas petak.
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
		age_held(lot)
		var target: Vector2i = Vector2i(-1, -1)
		if iid >= 0 and idx >= 0 and idx < slots(iid).size():
			var s: Dictionary = slots(iid)[idx]
			if s["recipe"] == st.recipe_id or slot_units(iid, idx) == 0:
				target = Vector2i(iid, idx)
		if target.x < 0:
			target = _find_slot_for(st.recipe_id, st.quantity)
		if target.x < 0 and iid >= 0 and idx >= 0 and idx < slots(iid).size():
			target = Vector2i(iid, idx)
		if target.x < 0:
			target = _any_slot()
		if target.x < 0:
			GameLogger.error("INVENTORY", "no display to return bread to; kept as waste-free overflow")
			continue
		var slot: Dictionary = slots(target.x)[target.y]
		slot["recipe"] = st.recipe_id
		var back: BreadStack = st.duplicate_stack()
		back.slot_id = StringName("%d:%d" % [target.x, target.y])
		back.display_tier = tier_of(target.x)
		(slot["stacks"] as Array).append(back)


## Roti yang dipegang pelanggan/kurir tetap menua dengan rate rak asalnya
## (GDD 19.7.2): umur tidak pernah berhenti atau di-reset. Dipanggil sekali per
## lot, sebelum lot kembali ke rak atau divalidasi di kasir/pack.
func age_held(lot: Dictionary) -> void:
	var st: BreadStack = lot["stack"]
	var since: float = float(lot.get("taken_at", -1.0))
	if since < 0.0:
		since = sim.time.sim_seconds
	var elapsed: float = maxf(0.0, sim.time.sim_seconds - since)
	lot["taken_at"] = sim.time.sim_seconds
	if elapsed <= 0.0:
		return
	var iid: int = int(lot.get("display_id", -1))
	var rate: float = def_of(iid).aging_rate if displays.has(iid) else 1.0
	st.age_ingame_hours += sim.time.ingame_hours(elapsed) * rate
	st.refresh_state()


func _find_slot_for(recipe_id: StringName, qty: int) -> Vector2i:
	for pass_i in 2:
		for iid: Variant in display_ids():
			var sl: Array = slots(int(iid))
			for i in sl.size():
				var s: Dictionary = sl[i]
				var ok: bool = (pass_i == 0 and s["recipe"] == recipe_id and slot_units(int(iid), i) > 0) \
					or (pass_i == 1 and slot_units(int(iid), i) == 0)
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
# FRESHNESS
# ===========================================================================

## Penuaan selama hari berjalan (GDD 19.7.2): umur += jam × aging rate rak.
func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	age_all(sim.time.ingame_hours(dt), false)


func age_all(hours: float, _overnight: bool) -> void:
	for iid: Variant in displays.keys():
		var d: Dictionary = displays[iid]
		var rate: float = def_of(int(iid)).aging_rate
		for s: Dictionary in d["slots"]:
			for st: BreadStack in s["stacks"]:
				st.age_ingame_hours += hours * rate
				var before: StringName = st.freshness_state
				st.refresh_state()
				if before != st.freshness_state:
					sim.tutorial.on_freshness_changed(st.freshness_state)


## Rollover 18:00 -> 05:00 (GDD 19.7.3). Tepat sekali per hari, dijaga
## `last_freshness_rollover_day` (GDD 19.9).
func overnight_rollover(for_day: int) -> Dictionary:
	if last_rollover_day >= for_day:
		return {"units": 0, "cost": 0.0}
	last_rollover_day = for_day
	age_all(DataRegistry.balf("clock.overnight_aging_hours"), true)
	return _remove_where(func(st: BreadStack) -> bool: return st.freshness_state == &"UNSALEABLE", &"expired")


## Buang manual (GDD 19.7.5): UNSALEABLE selalu, STALE bila diminta.
func discard(iid: int, include_stale: bool) -> Dictionary:
	return _remove_where(func(st: BreadStack) -> bool:
		return st.freshness_state == &"UNSALEABLE" or (include_stale and st.freshness_state == &"STALE"), &"expired", iid)


func _remove_where(pred: Callable, reason: StringName, only_iid: int = -1) -> Dictionary:
	var units: int = 0
	var cost: float = 0.0
	for iid: Variant in displays.keys():
		if only_iid >= 0 and int(iid) != only_iid:
			continue
		for s: Dictionary in slots(int(iid)):
			var stacks: Array = s["stacks"]
			for i in range(stacks.size() - 1, -1, -1):
				var st: BreadStack = stacks[i]
				if bool(pred.call(st)):
					var r: RecipeDefinition = DataRegistry.recipe(st.recipe_id)
					var c: float = r.unit_cogs_kr() * float(st.quantity)
					units += st.quantity
					cost += c
					sim.analytics.note_wasted(st.recipe_id, st.quantity, c, reason)
					stacks.remove_at(i)
	_cleanup()
	if units > 0:
		sim.economy.note_waste(cost)
		sim.statistics.add(&"total_bread_wasted", units)
	return {"units": units, "cost": cost}


func has_discardable(iid: int) -> bool:
	for s: Dictionary in slots(iid):
		for st: BreadStack in s["stacks"]:
			if st.freshness_state == &"UNSALEABLE" or st.freshness_state == &"STALE":
				return true
	return false


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
			sl.append({"recipe": String(s["recipe"]), "stacks": stacks})
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
			sl.append({"recipe": StringName(str(sd.get("recipe", ""))), "stacks": stacks})
		displays[int(str(k))] = {"tier": int(dd.get("tier", 1)), "slots": sl}
