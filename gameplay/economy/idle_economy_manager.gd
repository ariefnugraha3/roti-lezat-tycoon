class_name IdleEconomyManager
extends SimManager
## Model analitik kondisi tunak (GDD idle 9.1): KR per detik nyata yang
## dihasilkan toko sekarang, untuk HUD, penghasilan offline, dan urutan "Best
## value first" di layar Upgrades. Tidak menyimpan state dan tidak pernah
## menyentuh simulasi; hasilnya di-cache sebentar karena HUD membacanya 5 kali
## per detik.
##
##   D = permintaan unit per jam in-game (pembeli × qty rata-rata + RotiFood),
##       dibagi menurut bobot pilihan resep; siang dan malam terpisah
##   Q = pembeli yang muat di antrean: slot jalur ÷ lama memegang slot
##   P = produksi unit per jam: min(kapasitas mixer, kapasitas oven) untuk
##       campuran resep itu; tiap batch juga memegang alatnya selama jeda
##       serah-terima (pekerja datang, ambil, antar)
##   S = layanan: jalur kasir + pemilik, dan tenaga dapur: koki + pemilik
##       (waktu pemilik dibagi antara kasir jalur A dan dapur)
##   units = min(D, Q, P, S) per periode; rate = rata-rata 24 jam unit × laba
##   bersih per unit / detik nyata per jam

## Detik-simulasi tambahan per transaksi kasir: pembeli melangkah dari antrean ke
## depan meja (perkiraan, disetel terhadap simulasi hidup).
const SERVICE_OVERHEAD_SECONDS: float = 1.0
## Interaksi pekerja per batch: mulai aduk, ambil adonan, masukkan oven, ambil
## loyang, taruh di rak (GDD idle 4.3).
const ACTIONS_PER_BATCH: float = 5.0
## Umur cache hasil model (detik-simulasi).
const CACHE_SECONDS: float = 1.0

var _cache: Dictionary = {}
var _cache_at: float = -INF
var _walk_cache: Dictionary = {}


func new_game() -> void:
	invalidate()


func invalidate() -> void:
	_cache = {}
	_cache_at = -INF
	_walk_cache = {}


## KR per detik nyata sekarang. `with_boosts` = false untuk penghasilan offline
## (GDD idle 9.1: cuaca netral, tanpa boost).
func rate(with_boosts: bool = true) -> float:
	var m: Dictionary = model(with_boosts)
	return float(m.get("rate", 0.0))


## Rincian model (di-cache `CACHE_SECONDS` detik-simulasi per varian boost).
func model(with_boosts: bool = true) -> Dictionary:
	var key: String = "b" if with_boosts else "n"
	if sim.time.sim_seconds - _cache_at >= CACHE_SECONDS or sim.time.sim_seconds < _cache_at:
		_cache = {}
		_cache_at = sim.time.sim_seconds
	if not _cache.has(key):
		_cache[key] = compute(with_boosts)
	return _cache[key]


## Hitung model sekarang tanpa cache. Siang dan malam dihitung terpisah (laju
## kedatangan berbeda, batas antrean dan dapur sama), lalu dirata-ratakan 24 jam.
func compute(with_boosts: bool = true) -> Dictionary:
	var out: Dictionary = {"rate": 0.0, "units_per_hour": 0.0, "demand": 0.0, "production": 0.0, "net_per_unit": 0.0}
	# 1. Menu: resep setiap petak dan kapasitas petaknya.
	var slot_cap: Dictionary = {}
	var slot_price_bonus: Dictionary = {}
	var slot_count: Dictionary = {}
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		for i in sim.display.slot_count(e.iid):
			var rid: StringName = sim.display.effective_recipe(e.iid, i)
			if rid == &"":
				continue
			slot_cap[rid] = maxi(int(slot_cap.get(rid, 0)), sim.display.slot_capacity(e.iid))
			slot_price_bonus[rid] = float(slot_price_bonus.get(rid, 0.0)) + sim.upgrades.display_price_bonus(e.iid)
			slot_count[rid] = int(slot_count.get(rid, 0)) + 1
	if slot_cap.is_empty():
		return out
	var menu: Array = Ids.sort(slot_cap.keys())
	# 2. Campuran pembeli (24 jam) dan pilihan resepnya.
	var mods: Dictionary = {}
	var night_hours: int = 0
	for h in 24:
		var t: float = float(h) * 3600.0 + 1800.0
		var block: StringName = sim.demand.time_block(t)
		mods[block] = int(mods.get(block, 0)) + 1
		if sim.time.is_night(t):
			night_hours += 1
	var day_hours: int = 24 - night_hours
	var tier: int = sim.world.location.tier
	var weight_sum: float = 0.0
	var arch_w: Dictionary = {}
	for def: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var avg_mod: float = 0.0
		for blk: Variant in mods.keys():
			avg_mod += def.time_modifier(StringName(str(blk))) * float(mods[blk]) / 24.0
		var w: float = def.spawn_weight(tier) * avg_mod
		if w > 0.0:
			arch_w[def] = w
			weight_sum += w
	var share_walk: Dictionary = {}
	var q_mean: float = 0.0
	var speed_mean: float = 0.0
	for def2: Variant in arch_w.keys():
		var a: CustomerArchetypeDefinition = def2
		var p_a: float = float(arch_w[a]) / maxf(weight_sum, 0.0001)
		var q: float = CustomerManager.mean_quantity(a)
		q_mean += p_a * q
		speed_mean += p_a * a.movement_speed_mps
		var rw: Dictionary = CustomerManager.recipe_weights(a, menu)
		var tot: float = 0.0
		for v: Variant in rw.values():
			tot += float(v)
		for rid2: Variant in menu:
			share_walk[rid2] = float(share_walk.get(rid2, 0.0)) + p_a * q * float(rw.get(String(rid2), 0.0)) / maxf(tot, 0.0001)
	q_mean = maxf(q_mean, 0.0001)
	# share_walk[r]: bagian resep r dari unit yang dibeli pembeli.
	for rid3: Variant in menu:
		share_walk[rid3] = float(share_walk[rid3]) / q_mean
	var units_mean: float = _rotifood_units_mean()
	var generic: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_generic")
	var gw: Dictionary = CustomerManager.recipe_weights(generic, menu)
	var gtot: float = 0.0
	for v2: Variant in gw.values():
		gtot += float(v2)
	var share_rf: Dictionary = {}
	for rid4: Variant in menu:
		share_rf[rid4] = float(gw.get(String(rid4), 0.0)) / maxf(gtot, 0.0001)
	# 3. Laju siang per jam in-game; malam dikali faktor malam.
	var arr_day: float = sim.base_arrivals_per_hour() * sim.reputation.mult() * sim.decoration.bonus_mult(&"arrival")
	var rf_day: float = sim.base_rotifood_per_hour() * sim.decoration.bonus_mult(&"rotifood")
	if with_boosts:
		arr_day *= sim.boost_arrival_mult()
		rf_day *= sim.boost_rotifood_mult()
	# 4. Kapasitas: mesin, tenaga dapur, kasir, dan antrean.
	var h_sim: float = sim.time.sim_seconds_for_hours(1.0)
	var mix: Dictionary = {}
	var d_mix_w: float = arr_day * q_mean
	var d_mix_rf: float = rf_day * units_mean
	for rid5: Variant in menu:
		mix[rid5] = (d_mix_w * float(share_walk[rid5]) + d_mix_rf * float(share_rf[rid5])) / maxf(d_mix_w + d_mix_rf, 0.0001)
	var mix_u: float = 0.0
	var bake_u: float = 0.0
	var batches_u: float = 0.0
	for rid6: Variant in menu:
		var r: RecipeDefinition = DataRegistry.recipe(StringName(str(rid6)))
		var bsz: int = _batch_for(r, int(slot_cap[rid6]))
		var made: float = float(r.batch_yield * bsz)
		var f: float = DataRegistry.batch_duration_factor(bsz)
		mix_u += float(mix[rid6]) * (r.mix_duration_seconds + r.prep_duration_seconds) * f / made
		bake_u += float(mix[rid6]) * r.bake_duration_seconds * f / made
		batches_u += float(mix[rid6]) / made
	var routes: Dictionary = _kitchen_routes()
	var cycle_m: float = routes["cycle"]
	var walk: float = sim.upgrades.walk_mult()
	var owner_mps: float = DataRegistry.player_speed_mps() * walk
	# Jeda serah-terima per batch (GDD idle 4.3). Oven: pekerja datang mengangkat
	# loyang, baru setelah oven kosong adonan diambil dari mixer dan dimasukkan;
	# tanpa koki, pemilik lebih dulu mengantar loyangnya ke rak. Mixer: pekerja
	# mengambil bahan di Gudang lalu mulai mengaduk.
	var bakers: Array[StringName] = sim.staff.working_ids(&"baker")
	var v_sum: float = owner_mps
	for sid0: StringName in bakers:
		v_sum += DataRegistry.staff_speed_mps() * sim.upgrades.staff_speed(sid0) * walk
	var v_k: float = maxf(v_sum / float(bakers.size() + 1), 0.01)
	var act: float = KitchenBrain.INTERACT_SECONDS
	var r_mo: float = routes["mixer_oven"]
	var gap_oven: float
	if bakers.is_empty():
		gap_oven = PlayerTaskManager.RETHINK_SECONDS + 4.0 * act + (cycle_m + r_mo) / v_k
	else:
		gap_oven = StaffManager.RETHINK_SECONDS + 3.0 * act + 3.0 * r_mo / v_k
	var gap_mixer: float = (StaffManager.RETHINK_SECONDS if not bakers.is_empty() else PlayerTaskManager.RETHINK_SECONDS) \
		+ float(routes["mixer_acts"]) * act + 2.0 * float(routes["storage_mixer"]) / v_k
	var mixer_cap: float = 0.0
	for m: EquipmentInstance in sim.equipment.placed_list(&"mixer"):
		mixer_cap += h_sim / maxf(mix_u / sim.upgrades.station_speed(m.iid) + batches_u * gap_mixer, 0.000001)
	var oven_cap: float = 0.0
	for o: EquipmentInstance in sim.equipment.placed_list(&"oven"):
		oven_cap += h_sim / maxf(bake_u / sim.upgrades.station_speed(o.iid) + batches_u * gap_oven, 0.000001)
	var p_machine: float = minf(mixer_cap, oven_cap)
	var owner_labor_u: float = batches_u * (ACTIONS_PER_BATCH * KitchenBrain.INTERACT_SECONDS + cycle_m / maxf(owner_mps, 0.01))
	var baker_units: float = 0.0
	for sid: StringName in bakers:
		var sp: float = sim.upgrades.staff_speed(sid)
		var labor: float = batches_u * (ACTIONS_PER_BATCH * KitchenBrain.INTERACT_SECONDS / sp + cycle_m / maxf(DataRegistry.staff_speed_mps() * sp * walk, 0.01))
		baker_units += h_sim / maxf(labor, 0.000001)
	var txn_seconds: float = sim.upgrades.checkout_seconds() + SERVICE_OVERHEAD_SECONDS
	var cashiers: float = float(sim.staff.working_ids(&"cashier").size())
	# Antrean: setiap pembeli memegang satu slot sejak diterima sampai membayar.
	var walkers: float = _queue_customers_per_hour(h_sim, speed_mean, txn_seconds)
	# 5. Laba bersih per unit pembeli dan per unit RotiFood.
	var net_w: float = 0.0
	var net_rf: float = 0.0
	var rf_mult: float = DataRegistry.idlef("rotifood.price_mult")
	var boost_div: float = 1.0 if with_boosts else maxf(sim.boost_income_mult(), 0.0001)
	for rid7: Variant in menu:
		var rr: RecipeDefinition = DataRegistry.recipe(StringName(str(rid7)))
		var bonus: float = float(slot_price_bonus[rid7]) / float(slot_count[rid7])
		var price: float = sim.recipe_price(rr.id) * (1.0 + bonus) / boost_div
		net_w += float(share_walk[rid7]) * (price - rr.unit_cogs_kr())
		net_rf += float(share_rf[rid7]) * (price * rf_mult - rr.unit_cogs_kr())
	# 6. Siang dan malam: unit terjual = terbesar yang muat permintaan, antrean,
	# mesin, dan waktu pemilik.
	var units_total: float = 0.0
	var demand_total: float = 0.0
	var kr_total: float = 0.0
	for period: int in 2:
		var hours: float = float(day_hours if period == 0 else night_hours)
		if hours <= 0.0:
			continue
		var arr: float = arr_day * (1.0 if period == 0 else DataRegistry.idlef("night.arrival_mult"))
		var rf: float = rf_day * (1.0 if period == 0 else DataRegistry.idlef("night.rotifood_mult"))
		var d_walk: float = minf(arr, walkers) * q_mean
		var d_rf: float = rf * units_mean
		demand_total += (arr * q_mean + d_rf) * hours
		var d: float = d_walk + d_rf
		if d <= 0.0:
			continue
		var service_u: float = (d_walk * txn_seconds / q_mean + d_rf * sim.rotifood.pack_seconds() / maxf(units_mean, 0.0001)) / d
		var cashier_units: float = cashiers * h_sim / maxf(service_u, 0.000001)
		var owner_serve_units: float = h_sim / maxf(service_u, 0.000001)
		var owner_kitchen_units: float = h_sim / maxf(owner_labor_u, 0.000001)
		var hi: float = minf(d, p_machine)
		var units: float = hi
		if _owner_need(hi, cashier_units, owner_serve_units, baker_units, owner_kitchen_units) > 1.0:
			var lo: float = 0.0
			for _i in 50:
				var mid: float = (lo + hi) * 0.5
				if _owner_need(mid, cashier_units, owner_serve_units, baker_units, owner_kitchen_units) <= 1.0:
					lo = mid
				else:
					hi = mid
			units = lo
		units_total += units * hours
		kr_total += units * (d_walk * net_w + d_rf * net_rf) / d * hours
	out["units_per_hour"] = units_total / 24.0
	out["demand"] = demand_total / 24.0
	out["production"] = p_machine
	out["net_per_unit"] = kr_total / maxf(units_total, 0.0001)
	var real_per_hour: float = h_sim / maxf(DataRegistry.sim_seconds_per_real_second(), 0.0001)
	out["rate"] = maxf(0.0, kr_total / 24.0 / real_per_hour)
	return out


## Pembeli per jam in-game paling banyak yang bisa dilayani antrean fisik:
## kapasitas semua slot jalur ÷ lama satu pembeli memegang slotnya (jalan dari
## ujung trotoar ke pintu, ke rak, memilih, ke meja, dilayani).
func _queue_customers_per_hour(h_sim: float, speed_mps: float, txn_seconds: float) -> float:
	var cap: float = 0.0
	for l: QueueLane in sim.queue.lanes:
		cap += float(l.capacity())
	if cap <= 0.0:
		return 0.0
	var loc: LocationDefinition = sim.world.location
	var v: float = maxf(speed_mps, 0.1)
	var approach: float = (StreetPaths.approach_seconds(loc, -1, v) + StreetPaths.approach_seconds(loc, 1, v)) * 0.5
	var walk_in: float = _shop_walk_m() / v
	var hold: float = approach + walk_in + CustomerManager.BROWSE_SECONDS + txn_seconds
	return cap * h_sim / maxf(hold, 0.001)


## Jalan pembeli di dalam toko (meter): pintu -> rak pertama -> titik layanan
## jalur A. Di-cache per tata letak.
func _shop_walk_m() -> float:
	var shelves: Array[EquipmentInstance] = sim.equipment.placed_list(&"display")
	var lane: QueueLane = sim.queue.main_lane()
	if shelves.is_empty() or lane == null:
		return 0.0
	var key: String = "shop|%d|%s" % [shelves[0].iid, shelves[0].anchor]
	if _walk_cache.has(key):
		return _walk_cache[key]
	var acc: Dictionary = sim.world.access_of(shelves[0].iid)
	if acc.is_empty():
		return 0.0
	var store: StringName = sim.world.store_floor()
	var door: Vector2 = GridMath.cell_center(sim.world.entrance_cell())
	var total: float = _path_m(store, door, StringName(str(acc["floor"])), acc["cell"])
	total += _path_m(StringName(str(acc["floor"])), GridMath.cell_center(acc["cell"]), lane.floor_id, lane.service_point)
	_walk_cache[key] = total
	return total


func _path_m(from_floor: StringName, from: Vector2, to_floor: StringName, to_cell: Vector2i) -> float:
	var route: Array[Dictionary] = sim.world.find_route(from_floor, from, to_floor, to_cell, FloorGrid.NAV_PUBLIC)
	var length: float = 0.0
	var prev: Vector2 = from
	for wp: Dictionary in route:
		if bool(wp["portal"]):
			prev = wp["pos"]
			continue
		length += prev.distance_to(wp["pos"])
		prev = wp["pos"]
	return length


## Bagian satu jam pemilik yang dibutuhkan untuk menjual `x` unit per jam: kasir
## jalur A untuk yang tidak tertangani kasir, dapur untuk yang tidak tertangani koki.
static func _owner_need(x: float, cashier_units: float, owner_serve_units: float, baker_units: float, owner_kitchen_units: float) -> float:
	return maxf(0.0, x - cashier_units) / maxf(owner_serve_units, 0.000001) + maxf(0.0, x - baker_units) / maxf(owner_kitchen_units, 0.000001)


## Ukuran batch tunak resep `r` di petak berkapasitas `cap`: terbesar yang muat.
static func _batch_for(r: RecipeDefinition, cap: int) -> int:
	var mults: Array = DataRegistry.bal("production.batch_multipliers").duplicate()
	mults.sort()
	mults.reverse()
	for m: Variant in mults:
		if r.batch_yield * int(m) <= cap:
			return int(m)
	return 1


static func _rotifood_units_mean() -> float:
	var acc: float = 0.0
	var tot: float = 0.0
	for pair: Variant in DataRegistry.bal("rotifood.units_distribution"):
		acc += float((pair as Array)[0]) * float((pair as Array)[1])
		tot += float((pair as Array)[1])
	return acc / maxf(tot, 0.0001)


## Rute dapur sungguhan (meter, termasuk tangga di lokasi dua lantai), di-cache
## per tata letak: cycle = mixer -> oven -> rak -> mixer, mixer_oven, dan
## storage_mixer (0 tanpa Gudang) dengan mixer_acts = interaksi sebelum mengaduk.
func _kitchen_routes() -> Dictionary:
	var mixers: Array[EquipmentInstance] = sim.equipment.placed_list(&"mixer")
	var ovens: Array[EquipmentInstance] = sim.equipment.placed_list(&"oven")
	var shelves: Array[EquipmentInstance] = sim.equipment.placed_list(&"display")
	if mixers.is_empty() or ovens.is_empty() or shelves.is_empty():
		return {"cycle": 0.0, "mixer_oven": 0.0, "storage_mixer": 0.0, "mixer_acts": 1}
	var storage: EquipmentInstance = sim.equipment.storage_instance()
	if storage != null and not storage.placed:
		storage = null
	var key: String = "%d|%d|%d|%s|%s|%s|%s" % [mixers[0].iid, ovens[0].iid, shelves[0].iid, mixers[0].anchor, ovens[0].anchor,
		shelves[0].anchor, str(storage.anchor) if storage != null else "-"]
	if _walk_cache.has(key):
		return _walk_cache[key]
	var stops: Array[EquipmentInstance] = [mixers[0], ovens[0], shelves[0], mixers[0]]
	var total: float = 0.0
	for i in 3:
		total += _route_m(stops[i], stops[i + 1])
	var out: Dictionary = {"cycle": total, "mixer_oven": _route_m(mixers[0], ovens[0]),
		"storage_mixer": _route_m(storage, mixers[0]) if storage != null else 0.0, "mixer_acts": 2 if storage != null else 1}
	_walk_cache[key] = out
	return out


func _route_m(a: EquipmentInstance, b: EquipmentInstance) -> float:
	var aa: Dictionary = sim.world.access_of(a.iid)
	var bb: Dictionary = sim.world.access_of(b.iid)
	if aa.is_empty() or bb.is_empty():
		return 0.0
	var from: Vector2 = GridMath.cell_center(aa["cell"])
	var route: Array[Dictionary] = sim.world.find_route(StringName(str(aa["floor"])), from, StringName(str(bb["floor"])), bb["cell"], FloorGrid.NAV_STAFF)
	var length: float = 0.0
	var prev: Vector2 = from
	for wp: Dictionary in route:
		if bool(wp["portal"]):
			prev = wp["pos"]
			continue
		length += prev.distance_to(wp["pos"])
		prev = wp["pos"]
	return length


# ===========================================================================
# REKOMENDASI "BEST VALUE" (GDD idle 12.3)
# ===========================================================================

## Kenaikan KR/s bila penawaran `o` (UpgradeManager.offer) naik `n` level. Level
## diubah sementara lalu dikembalikan; simulasi tidak tersentuh.
func delta_rate(o: Dictionary, n: int = 1) -> float:
	if o.is_empty() or n <= 0:
		return 0.0
	var before: float = compute(false)["rate"]
	var up: UpgradeManager = sim.upgrades
	var after: float = before
	match o["kind"]:
		&"station":
			var iid: int = int(o["id"])
			var had: bool = up.station_levels.has(iid)
			var old: int = up.station_level(iid)
			up.station_levels[iid] = old + n
			after = compute(false)["rate"]
			if had:
				up.station_levels[iid] = old
			else:
				up.station_levels.erase(iid)
		&"counter":
			var c0: int = up.counter_level
			up.counter_level = c0 + n
			after = compute(false)["rate"]
			up.counter_level = c0
		&"recipe":
			var rid: StringName = StringName(str(o["id"]))
			var r0: int = up.recipe_level(rid)
			up.recipe_levels[rid] = r0 + n
			after = compute(false)["rate"]
			up.recipe_levels[rid] = r0
		&"staff":
			var sid: StringName = StringName(str(o["id"]))
			var had2: bool = up.staff_levels.has(sid)
			var s0: int = up.staff_level(sid)
			up.staff_levels[sid] = s0 + n
			after = compute(false)["rate"]
			if had2:
				up.staff_levels[sid] = s0
			else:
				up.staff_levels.erase(sid)
		&"global":
			var gid: StringName = StringName(str(o["id"]))
			var had3: bool = up.global_levels.has(gid)
			var g0: int = up.global_level(gid)
			up.global_levels[gid] = g0 + n
			after = compute(false)["rate"]
			if had3:
				up.global_levels[gid] = g0
			else:
				up.global_levels.erase(gid)
	return maxf(0.0, after - before)


## Kenaikan KR/s bila resep `rid` dibuka pada Lv 1 dan petak Auto memakainya
## bila lebih untung. Resep dibuka sementara lalu dikembalikan.
func delta_unlock(rid: StringName) -> float:
	var up: UpgradeManager = sim.upgrades
	if up.is_unlocked(rid):
		return 0.0
	var before: float = compute(false)["rate"]
	up.recipe_levels[rid] = 1
	var after: float = compute(false)["rate"]
	up.recipe_levels.erase(rid)
	return maxf(0.0, after - before)


## Semua penawaran upgrade yang masih bisa naik, diurutkan "Best value first":
## Δ(KR/s) ÷ biaya satu level, terbesar dulu; seri dipecah biaya termurah, lalu
## urutan jenis dan ID. [{offer, cost, delta, value}].
func ranked_offers() -> Array[Dictionary]:
	var up: UpgradeManager = sim.upgrades
	var list: Array[Dictionary] = []
	var offers: Array[Dictionary] = []
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			offers.append(up.offer(&"station", e.iid))
	offers.append(up.offer(&"counter", &"counter"))
	for rid: StringName in up.unlocked_recipes():
		offers.append(up.offer(&"recipe", rid))
	for sid: StringName in sim.staff.employed_ids():
		offers.append(up.offer(&"staff", sid))
	for g: Variant in DataRegistry.idle("global_upgrades"):
		offers.append(up.offer(&"global", StringName(str((g as Dictionary)["id"]))))
	var kinds: Array = [&"station", &"counter", &"recipe", &"staff", &"global"]
	for i in offers.size():
		var o: Dictionary = offers[i]
		if o.is_empty() or int(o["level"]) >= int(o["cap"]):
			continue
		var cost: float = UpgradeManager.offer_cost(o, 1)
		var d: float = delta_rate(o, 1)
		list.append({"offer": o, "cost": cost, "delta": d, "value": d / maxf(cost, 0.000001), "order": kinds.find(o["kind"]) * 1000 + i})
	list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["value"]), float(b["value"])):
			return float(a["value"]) > float(b["value"])
		if not is_equal_approx(float(a["cost"]), float(b["cost"])):
			return float(a["cost"]) < float(b["cost"])
		return int(a["order"]) < int(b["order"]))
	return list
