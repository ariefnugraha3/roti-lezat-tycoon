class_name UpgradeManager
extends SimManager
## UpgradeManager — pemilik semua level (GDD idle 8, 15.1): level tiap stasiun
## (per instance), satu level Meja Kasir untuk semua jalur, level dan status
## buka resep, level staf, dan level upgrade global. Rumus efek setiap level
## juga tinggal di sini supaya produksi, kasir, UI, dan IdleEconomy membaca
## angka yang sama.

## iid -> level (stasiun produksi & rak; default 1).
var station_levels: Dictionary = {}
var counter_level: int = 1
## recipe_id -> level, hanya resep yang sudah dibuka.
var recipe_levels: Dictionary = {}
## staff_id -> level.
var staff_levels: Dictionary = {}
## upgrade global -> jumlah level yang dibeli (0..max_level, GDD idle 8.9).
var global_levels: Dictionary = {}


func new_game() -> void:
	station_levels.clear()
	counter_level = 1
	recipe_levels.clear()
	staff_levels.clear()
	global_levels.clear()
	for r: RecipeDefinition in DataRegistry.recipes():
		if r.unlock_free:
			recipe_levels[r.id] = 1


# ===========================================================================
# MILESTONE & BATAS (GDD idle 8.2, 8.3)
# ===========================================================================

## Jumlah milestone dalam `list` yang sudah dicapai level `level`.
static func milestones_reached(level: int, list: Array) -> int:
	var n: int = 0
	for m: Variant in list:
		if level >= int(m):
			n += 1
	return n


## Milestone berikutnya di atas `level`, atau -1 bila semua sudah dilewati.
static func next_milestone(level: int, list: Array) -> int:
	for m: Variant in list:
		if level < int(m):
			return int(m)
	return -1


## Batas level stasiun dan staf di lokasi sekarang (GDD idle 8.3).
func level_cap() -> int:
	var caps: Array = DataRegistry.idle("station.level_cap_by_location")
	return int(caps[clampi(sim.world.location.tier - 1, 0, caps.size() - 1)])


## Tier model untuk level stasiun (GDD idle 8.2): 1 + ambang yang dilewati.
static func model_tier_for_level(level: int) -> int:
	return 1 + milestones_reached(level, DataRegistry.idle("station.model_tier_thresholds"))


# ===========================================================================
# STASIUN (GDD idle 8.2)
# ===========================================================================

func station_level(iid: int) -> int:
	return int(station_levels.get(iid, 1))


## Tier model logis stasiun `iid` dari levelnya (syarat resep, GDD idle 4.2).
func station_model_tier(iid: int) -> int:
	return model_tier_for_level(station_level(iid))


## Pengali kecepatan mixer/oven: (1 + per_level × (L − 1)) × mult^m(L).
func station_speed(iid: int) -> float:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null:
		return 1.0
	return speed_for(e.category(), station_level(iid))


static func speed_for(category: StringName, level: int) -> float:
	var key: String = "station.%s" % category
	var per: float = DataRegistry.idlef(key + ".speed_per_level")
	var mult: float = DataRegistry.idlef(key + ".milestone_mult")
	var m: int = milestones_reached(level, DataRegistry.idle("station.milestones"))
	return (1.0 + per * float(level - 1)) * pow(mult, m)


## Unit per petak rak `iid` (GDD idle 8.2): base_units × (1 + per_level × (L − 1)),
## base_units = max_per_slot rak T1.
func slot_capacity(iid: int) -> int:
	return slot_capacity_for(station_level(iid))


static func slot_capacity_for(level: int) -> int:
	var base: int = DataRegistry.equipment_for(&"display", 1).max_per_slot
	return int(floor(float(base) * (1.0 + DataRegistry.idlef("station.display.capacity_per_level") * float(level - 1)) + 0.000001))


## Bonus harga rak `iid` (GDD idle 7.2): price_per_level × (L − 1).
func display_price_bonus(iid: int) -> float:
	return DataRegistry.idlef("station.display.price_per_level") * float(station_level(iid) - 1)


## Lama satu transaksi kasir (detik-simulasi, GDD idle 8.2).
func checkout_seconds() -> float:
	return checkout_seconds_for(counter_level)


static func checkout_seconds_for(level: int) -> float:
	var base: float = DataRegistry.idlef("station.counter.checkout_base_seconds")
	var f: float = DataRegistry.idlef("station.counter.checkout_factor")
	return maxf(DataRegistry.idlef("station.counter.checkout_min_seconds"), base * pow(f, float(level - 1)))


# ===========================================================================
# RESEP (GDD idle 8.5)
# ===========================================================================

func is_unlocked(recipe_id: StringName) -> bool:
	return recipe_levels.has(recipe_id)


func recipe_level(recipe_id: StringName) -> int:
	return int(recipe_levels.get(recipe_id, 1))


func unlocked_recipes() -> Array[StringName]:
	var out: Array[StringName] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if recipe_levels.has(r.id):
			out.append(r.id)
	return out


## Pengali harga resep (GDD idle 8.5): (1 + per_level × (L − 1)) × mult^m_r(L).
func recipe_price_mult(recipe_id: StringName) -> float:
	return recipe_price_mult_for(recipe_level(recipe_id), recipe_milestone_mult())


static func recipe_price_mult_for(level: int, milestone_mult: float) -> float:
	var per: float = DataRegistry.idlef("recipe.price_per_level")
	var m: int = milestones_reached(level, DataRegistry.idle("recipe.milestones"))
	return (1.0 + per * float(level - 1)) * pow(milestone_mult, m)


## Pengali milestone resep: ×2, atau perk waralaba yang menggantinya (GDD idle 10.4).
func recipe_milestone_mult() -> float:
	return maxf(DataRegistry.idlef("recipe.milestone_mult"), sim.prestige.recipe_milestone_mult())


# ===========================================================================
# STAF (GDD idle 5.5)
# ===========================================================================

func staff_level(staff_id: StringName) -> int:
	return int(staff_levels.get(staff_id, 1))


## Pengali kecepatan jalan dan aksi staf: 1 + per_level × (L − 1).
func staff_speed(staff_id: StringName) -> float:
	return 1.0 + DataRegistry.idlef("staff.speed_per_level") * float(staff_level(staff_id) - 1)


# ===========================================================================
# GLOBAL (GDD idle 8.9)
# ===========================================================================

func global_level(id: StringName) -> int:
	return int(global_levels.get(id, 0))


## Total efek upgrade global `id`: per_level × level yang dibeli.
func global_bonus(id: StringName) -> float:
	var g: Dictionary = DataRegistry.global_upgrade(id)
	return float(g.get("per_level", 0.0)) * float(global_level(id))


## Pengali jalan pemilik dan staf (GDD idle 8.9 `global_walk_speed`).
func walk_mult() -> float:
	return 1.0 + global_bonus(&"global_walk_speed")


## Pengali kesabaran pembeli (GDD idle 8.9 `global_queue_patience`).
func patience_mult() -> float:
	return 1.0 + global_bonus(&"global_queue_patience")


# ===========================================================================
# RUMUS BIAYA (GDD idle 8.1)
# ===========================================================================

## Biaya `n` level berikutnya dari level `level`: base × g^(L−1) × (g^n − 1)/(g − 1).
## `level` di sini = jumlah langkah yang sudah dibayar dari dasar (L − 1 untuk
## level stasiun/resep/staf, jumlah level global yang dibeli).
static func series_cost(base: float, growth: float, steps_done: int, n: int) -> float:
	if n <= 0:
		return 0.0
	var first: float = base * pow(growth, float(steps_done))
	if absf(growth - 1.0) < 0.000001:
		return first * float(n)
	return first * (pow(growth, float(n)) - 1.0) / (growth - 1.0)


## Jumlah level terbanyak yang terjangkau dengan `kr` (GDD idle 8.1), dibatasi
## `room` (sisa batas level).
static func max_affordable(base: float, growth: float, steps_done: int, kr: float, room: int) -> int:
	if room <= 0 or kr <= 0.0:
		return 0
	var first: float = base * pow(growth, float(steps_done))
	if first > kr + 0.0001:
		return 0
	var n: int = int(floor(log(1.0 + kr * (growth - 1.0) / first) / log(growth) + 1e-9))
	n = clampi(n, 0, room)
	# Penjaga pembulatan float: turunkan sampai benar-benar terjangkau.
	while n > 0 and series_cost(base, growth, steps_done, n) > kr + 0.0001:
		n -= 1
	return n


## Jumlah level yang dibeli tombol ×1/×10/Max (GDD idle 8.1): ×1 dan ×10 hanya
## bila seluruhnya terjangkau dan muat dalam batas; Max = sebanyak mungkin
## (paling sedikit 1). 0 = tidak bisa.
static func buy_count(mode: StringName, base: float, growth: float, steps_done: int, kr: float, room: int) -> int:
	match mode:
		&"x1":
			return 1 if room >= 1 and series_cost(base, growth, steps_done, 1) <= kr + 0.0001 else 0
		&"x10":
			return 10 if room >= 10 and series_cost(base, growth, steps_done, 10) <= kr + 0.0001 else 0
	return max_affordable(base, growth, steps_done, kr, room)


## Tanpa batas level (resep): ruang besar tetapi tetap terhingga.
const NO_CAP: int = 1 << 30


# ===========================================================================
# PENAWARAN — satu bentuk untuk UI, bot, dan IdleEconomy
# ===========================================================================

## Penawaran upgrade: {kind, id, level, cap, base, growth, steps}. `kind` =
## station, counter, recipe, staff, global. `id` = iid / recipe_id / staff_id /
## upgrade id. `cap` = level tertinggi yang boleh dicapai (NO_CAP bila tanpa batas).
func offer(kind: StringName, id: Variant) -> Dictionary:
	match kind:
		&"station":
			var e: EquipmentInstance = sim.equipment.get_inst(int(id))
			if e == null:
				return {}
			var key: String = "station.%s" % e.category()
			var base: float = DataRegistry.idlef(key + ".cost_base") * pow(DataRegistry.idlef("station.extra_instance_cost_mult"), float(instance_index(e)))
			var lv: int = station_level(e.iid)
			return {"kind": kind, "id": e.iid, "level": lv, "cap": level_cap(), "base": base,
				"growth": DataRegistry.idlef(key + ".cost_growth"), "steps": lv - 1}
		&"counter":
			return {"kind": kind, "id": &"counter", "level": counter_level, "cap": level_cap(),
				"base": DataRegistry.idlef("station.counter.cost_base"), "growth": DataRegistry.idlef("station.counter.cost_growth"),
				"steps": counter_level - 1}
		&"recipe":
			var r: RecipeDefinition = DataRegistry.recipe(StringName(str(id)))
			if r == null or not is_unlocked(r.id):
				return {}
			var lv2: int = recipe_level(r.id)
			return {"kind": kind, "id": r.id, "level": lv2, "cap": NO_CAP,
				"base": r.base_sell_price_kr * DataRegistry.idlef("recipe.level_cost_mult"),
				"growth": DataRegistry.idlef("recipe.level_cost_growth"), "steps": lv2 - 1}
		&"staff":
			var sid: StringName = StringName(str(id))
			if not sim.staff.is_employed(sid):
				return {}
			var lv3: int = staff_level(sid)
			return {"kind": kind, "id": sid, "level": lv3, "cap": level_cap(),
				"base": DataRegistry.idlef("staff.level_cost_base"), "growth": DataRegistry.idlef("staff.level_cost_growth"), "steps": lv3 - 1}
		&"global":
			var g: Dictionary = DataRegistry.global_upgrade(StringName(str(id)))
			if g.is_empty():
				return {}
			var lv4: int = global_level(StringName(str(id)))
			return {"kind": kind, "id": StringName(str(id)), "level": lv4, "cap": int(g["max_level"]),
				"base": float(g["cost_base"]), "growth": float(g["cost_growth"]), "steps": lv4}
	return {}


## Level yang akan dibeli tombol `mode` untuk penawaran `o`.
func offer_count(o: Dictionary, mode: StringName) -> int:
	if o.is_empty():
		return 0
	var room: int = int(o["cap"]) - int(o["level"])
	return buy_count(mode, float(o["base"]), float(o["growth"]), int(o["steps"]), sim.economy.balance, room)


## Biaya `n` level penawaran `o`.
static func offer_cost(o: Dictionary, n: int) -> float:
	if o.is_empty():
		return 0.0
	return series_cost(float(o["base"]), float(o["growth"]), int(o["steps"]), n)


## Beli `n` level penawaran `o`. false bila tidak terjangkau atau melewati batas.
func buy_offer(o: Dictionary, n: int) -> bool:
	if o.is_empty() or n <= 0 or int(o["level"]) + n > int(o["cap"]):
		return false
	var cost: float = offer_cost(o, n)
	var cat: StringName = {&"station": &"UPGRADE_STATION", &"counter": &"UPGRADE_STATION", &"recipe": &"UPGRADE_RECIPE",
		&"staff": &"STAFF_UPGRADE", &"global": &"GLOBAL_UPGRADE"}[o["kind"]]
	if not sim.economy.spend(cost, cat, StringName(str(o["id"])), {"levels": n}):
		return false
	var before: int = int(o["level"])
	var after: int = before + n
	match o["kind"]:
		&"station":
			set_station_level(int(o["id"]), after)
		&"counter":
			counter_level = after
		&"recipe":
			recipe_levels[StringName(str(o["id"]))] = after
		&"staff":
			staff_levels[StringName(str(o["id"]))] = after
		&"global":
			global_levels[StringName(str(o["id"]))] = after
	_note_levels(o, before, after)
	sim.idle_economy.invalidate()
	SaveManager.request_autosave("upgrade")
	return true


## Beli dengan tombol ×1/×10/Max. Mengembalikan jumlah level yang dibeli.
func buy(kind: StringName, id: Variant, mode: StringName) -> int:
	var o: Dictionary = offer(kind, id)
	var n: int = offer_count(o, mode)
	if n <= 0 or not buy_offer(o, n):
		return 0
	return n


## Milestone yang terlewati pembelian ini: sinyal untuk efek dan bunyi.
func _note_levels(o: Dictionary, before: int, after: int) -> void:
	var list: Array = []
	match o["kind"]:
		&"station", &"counter", &"staff":
			list = DataRegistry.idle("station.milestones")
		&"recipe":
			list = DataRegistry.idle("recipe.milestones")
	var crossed: bool = milestones_reached(after, list) > milestones_reached(before, list)
	EventBus.level_up.emit(StringName(o["kind"]), o["id"], after, crossed)
	EventBus.sfx.emit(&"milestone_fanfare" if crossed else &"level_up", &"")


# ===========================================================================
# STASIUN: LEVEL, EVOLUSI, BUKA BARU (GDD idle 8.2, 8.4)
# ===========================================================================

## Urutan instance dalam kategorinya (0 = pertama), untuk pengali biaya
## instance tambahan.
func instance_index(e: EquipmentInstance) -> int:
	var i: int = 0
	for o: EquipmentInstance in sim.equipment.all_sorted():
		if o.iid == e.iid:
			return i
		if o.category() == e.category():
			i += 1
	return i


## Setel level stasiun lalu evolusikan modelnya bila melewati ambang (GDD idle 8.2).
func set_station_level(iid: int, level: int) -> void:
	station_levels[iid] = maxi(1, level)
	evolve(iid)


## Model mengikuti tier dari level: T1–T5 dari EquipmentFactory. Bila jejak
## model baru tidak muat di tempatnya, stasiun pindah ke tempat sah terdekat;
## bila tidak ada tempat sama sekali, evolusi visual menunggu (efek level tetap
## berlaku). true bila model berganti.
func evolve(iid: int) -> bool:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null or not [&"mixer", &"oven", &"display"].has(e.category()):
		return false
	var want: int = station_model_tier(iid)
	if want <= e.tier():
		return false
	var def: EquipmentDefinition = DataRegistry.equipment_for(e.category(), want)
	if def == null:
		return false
	var floor_id: StringName = e.floor_id
	var anchor: Vector2i = e.anchor
	var rot: int = e.rotation
	if e.placed:
		var spot: Dictionary = sim.equipment.replacement_spot(e, def)
		if spot.is_empty():
			return false
		floor_id = spot["floor_id"]
		anchor = spot["anchor"]
		rot = int(spot["rot"])
	var from_tier: int = e.tier()
	e.def_id = def.id
	if e.placed:
		e.floor_id = floor_id
		e.anchor = anchor
		e.rotation = rot
		sim.world.rebuild_occupancy()
	else:
		sim.equipment.invalidate_lists()
	if e.category() == &"display":
		sim.display.ensure_display(iid, want)
	EventBus.station_evolved.emit(iid, from_tier, want)
	EventBus.sfx.emit(&"milestone_fanfare", e.floor_id)
	return true


## Coba lagi evolusi yang tertunda (mis. setelah tata letak berubah).
func retry_evolutions() -> void:
	for e: EquipmentInstance in sim.equipment.all_sorted():
		evolve(e.iid)


## Jumlah stasiun kategori itu yang sudah dibuka dengan KR di lokasi ini
## (stasiun awal gratis tidak dihitung).
func opened_count(category: StringName) -> int:
	return maxi(0, sim.equipment.placed_count(category) + sim.equipment.unplaced_list(category).size() - 1)


## Biaya membuka stasiun berikutnya (GDD idle 8.4): open_cost × open_growth^(n−1),
## n = stasiun ke-n yang dibuka dengan KR. -1 bila slot lokasi penuh.
func open_station_cost(category: StringName) -> float:
	var have: int = sim.equipment.placed_count(category) + sim.equipment.unplaced_list(category).size()
	if have >= sim.equipment.slot_limit(category):
		return -1.0
	return DataRegistry.idlef("station.open_cost.%s" % category) * pow(DataRegistry.idlef("station.open_growth"), float(opened_count(category)))


## Buka stasiun baru: dibayar KR (STATION_OPEN), mulai Lv 1, ditempatkan otomatis.
## Mengembalikan iid baru atau -1.
func open_station(category: StringName) -> int:
	var cost: float = open_station_cost(category)
	if cost < 0.0 or not sim.economy.can_afford(cost):
		return -1
	var e: EquipmentInstance = sim.equipment.create_instance(StringName("%s_t1" % category))
	if not sim.world.auto_place(e):
		sim.equipment.instances.erase(e.iid)
		sim.equipment.invalidate_lists()
		if category == &"display":
			sim.display.remove_display(e.iid)
		GameLogger.warn("WORLD", "no room for a new %s" % category)
		return -1
	sim.economy.spend(cost, &"STATION_OPEN", category, {"iid": e.iid})
	station_levels[e.iid] = 1
	EventBus.station_opened.emit(e.iid)
	EventBus.sfx.emit(&"level_up", e.floor_id)
	SaveManager.request_autosave("station_open")
	return e.iid


# ===========================================================================
# RESEP: BUKA (GDD idle 8.5)
# ===========================================================================

## Biaya membuka resep: harga dasar × `recipe.unlock_mult`; 0 untuk resep gratis.
static func unlock_cost(r: RecipeDefinition) -> float:
	if r == null or r.unlock_free:
		return 0.0
	return r.base_sell_price_kr * DataRegistry.idlef("recipe.unlock_mult")


## &"" bila resep boleh dibuka sekarang; selain itu alasan: owned, tier, kr.
func unlock_block(recipe_id: StringName) -> StringName:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return &"invalid"
	if is_unlocked(recipe_id):
		return &"owned"
	if not sim.production.owns_equipment_for(r):
		return &"tier"
	if not sim.economy.can_afford(unlock_cost(r)):
		return &"kr"
	return &""


func unlock_recipe(recipe_id: StringName) -> bool:
	if unlock_block(recipe_id) != &"":
		return false
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if not sim.economy.spend(unlock_cost(r), &"RECIPE_UNLOCK", recipe_id, {}):
		return false
	recipe_levels[recipe_id] = 1
	sim.prestige.note_recipe_unlocked(recipe_id)
	EventBus.recipe_unlocked.emit(recipe_id)
	EventBus.sfx.emit(&"level_up", &"")
	SaveManager.request_autosave("recipe_unlock")
	return true


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	var st: Dictionary = {}
	for k: Variant in station_levels.keys():
		st[str(k)] = int(station_levels[k])
	return {"stations": st, "counter": counter_level, "recipes": sn_dict_to_json(recipe_levels),
		"staff": sn_dict_to_json(staff_levels), "global": sn_dict_to_json(global_levels)}


func restore(d: Dictionary) -> void:
	station_levels.clear()
	for k: Variant in (d.get("stations", {}) as Dictionary).keys():
		station_levels[int(str(k))] = maxi(1, int(d["stations"][k]))
	counter_level = maxi(1, int(d.get("counter", 1)))
	recipe_levels.clear()
	var rl: Dictionary = json_to_sn_dict(d.get("recipes", {}))
	for k2: Variant in rl.keys():
		if DataRegistry.recipe(k2) != null:
			recipe_levels[k2] = maxi(1, int(rl[k2]))
		else:
			GameLogger.error("SAVE", "dropped the level of unknown recipe %s" % k2)
	for r: RecipeDefinition in DataRegistry.recipes():
		if r.unlock_free and not recipe_levels.has(r.id):
			recipe_levels[r.id] = 1
	staff_levels.clear()
	var sl: Dictionary = json_to_sn_dict(d.get("staff", {}))
	for k3: Variant in sl.keys():
		if DataRegistry.staff(k3) != null:
			staff_levels[k3] = maxi(1, int(sl[k3]))
	global_levels.clear()
	var gl: Dictionary = json_to_sn_dict(d.get("global", {}))
	for k4: Variant in gl.keys():
		var g: Dictionary = DataRegistry.global_upgrade(k4)
		if not g.is_empty():
			global_levels[k4] = clampi(int(gl[k4]), 0, int(g["max_level"]))
