class_name IdleEconomyManager
extends SimManager
## Model analitik kondisi tunak (GDD idle 9.1): KR per detik nyata yang
## dihasilkan toko sekarang, untuk HUD, penghasilan offline, dan urutan "Best
## value first" di layar Upgrades. Tidak menyimpan state dan tidak pernah
## menyentuh simulasi; hasilnya di-cache sebentar karena HUD membacanya 5 kali
## per detik.
##
##   D = permintaan unit per jam in-game (kedatangan rata-rata 24 jam × qty rata-
##       rata + RotiFood), dibagi menurut bobot pilihan resep
##   P = produksi unit per jam: min(kapasitas mixer, kapasitas oven) untuk
##       campuran resep itu
##   S = layanan: jalur kasir + pemilik, dan tenaga dapur: koki + pemilik
##       (waktu pemilik dibagi antara kasir jalur A dan dapur)
##   units = min(D, P, S); rate = units × laba bersih per unit / detik nyata per jam

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


## Hitung model sekarang tanpa cache.
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
	# 2. Permintaan per jam in-game, rata-rata 24 jam (malam ikut).
	var arrivals: float = 0.0
	var orders: float = 0.0
	var mods: Dictionary = {}
	for h in 24:
		var t: float = float(h) * 3600.0 + 1800.0
		arrivals += sim.base_arrivals_per_hour() * sim.night_arrival_mult(t)
		orders += sim.base_rotifood_per_hour() * sim.night_rotifood_mult(t)
		var block: StringName = sim.demand.time_block(t)
		mods[block] = int(mods.get(block, 0)) + 1
	arrivals = arrivals / 24.0 * sim.reputation.mult() * sim.decoration.bonus_mult(&"arrival")
	orders = orders / 24.0 * sim.decoration.bonus_mult(&"rotifood")
	if with_boosts:
		arrivals *= sim.boost_arrival_mult()
		orders *= sim.boost_rotifood_mult()
	var demand_w: Dictionary = {}
	var qty_sum: float = 0.0
	var tier: int = sim.world.location.tier
	var weight_sum: float = 0.0
	var arch_w: Dictionary = {}
	for def: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var avg_mod: float = 0.0
		for b: Variant in mods.keys():
			avg_mod += def.time_modifier(StringName(str(b))) * float(mods[b]) / 24.0
		var w: float = def.spawn_weight(tier) * avg_mod
		if w > 0.0:
			arch_w[def] = w
			weight_sum += w
	for def2: Variant in arch_w.keys():
		var a: CustomerArchetypeDefinition = def2
		var p_a: float = float(arch_w[a]) / maxf(weight_sum, 0.0001)
		var q: float = CustomerManager.mean_quantity(a)
		qty_sum += p_a * q
		var rw: Dictionary = CustomerManager.recipe_weights(a, menu)
		var tot: float = 0.0
		for v: Variant in rw.values():
			tot += float(v)
		for rid2: Variant in menu:
			var share: float = float(rw.get(String(rid2), 0.0)) / maxf(tot, 0.0001)
			demand_w[rid2] = float(demand_w.get(rid2, 0.0)) + arrivals * p_a * q * share
	var units_mean: float = _rotifood_units_mean()
	var generic: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_generic")
	var gw: Dictionary = CustomerManager.recipe_weights(generic, menu)
	var gtot: float = 0.0
	for v2: Variant in gw.values():
		gtot += float(v2)
	var demand_rf: Dictionary = {}
	for rid3: Variant in menu:
		demand_rf[rid3] = orders * units_mean * float(gw.get(String(rid3), 0.0)) / maxf(gtot, 0.0001)
	var d_walk: float = 0.0
	var d_rf: float = 0.0
	for rid4: Variant in menu:
		d_walk += float(demand_w[rid4])
		d_rf += float(demand_rf[rid4])
	var d_total: float = d_walk + d_rf
	out["demand"] = d_total
	if d_total <= 0.0:
		return out
	# Bobot campuran resep menurut permintaan.
	var mix: Dictionary = {}
	for rid5: Variant in menu:
		mix[rid5] = (float(demand_w[rid5]) + float(demand_rf[rid5])) / d_total
	# 3. Produksi: waktu mesin dan tenaga per unit untuk campuran itu.
	var h_sim: float = sim.time.sim_seconds_for_hours(1.0)
	var mix_u: float = 0.0
	var bake_u: float = 0.0
	var batches_u: float = 0.0
	for rid6: Variant in menu:
		var r: RecipeDefinition = DataRegistry.recipe(StringName(str(rid6)))
		var b: int = _batch_for(r, int(slot_cap[rid6]))
		var made: float = float(r.batch_yield * b)
		var f: float = DataRegistry.batch_duration_factor(b)
		mix_u += float(mix[rid6]) * (r.mix_duration_seconds + r.prep_duration_seconds) * f / made
		bake_u += float(mix[rid6]) * r.bake_duration_seconds * f / made
		batches_u += float(mix[rid6]) / made
	var mixer_speed: float = 0.0
	for m: EquipmentInstance in sim.equipment.placed_list(&"mixer"):
		mixer_speed += sim.upgrades.station_speed(m.iid)
	var oven_speed: float = 0.0
	for o: EquipmentInstance in sim.equipment.placed_list(&"oven"):
		oven_speed += sim.upgrades.station_speed(o.iid)
	var p_machine: float = minf(mixer_speed * h_sim / maxf(mix_u, 0.000001), oven_speed * h_sim / maxf(bake_u, 0.000001))
	out["production"] = p_machine
	# Tenaga dapur per unit: aksi + satu putaran jalan mixer -> oven -> rak -> mixer.
	var cycle_m: float = _walk_cycle_m()
	var walk: float = sim.upgrades.walk_mult()
	var owner_mps: float = DataRegistry.player_speed_mps() * walk
	var owner_labor_u: float = batches_u * (ACTIONS_PER_BATCH * KitchenBrain.INTERACT_SECONDS + cycle_m / maxf(owner_mps, 0.01))
	var baker_units: float = 0.0
	for sid: StringName in sim.staff.working_ids(&"baker"):
		var sp: float = sim.upgrades.staff_speed(sid)
		var labor: float = batches_u * (ACTIONS_PER_BATCH * KitchenBrain.INTERACT_SECONDS / sp + cycle_m / maxf(DataRegistry.staff_speed_mps() * sp * walk, 0.01))
		baker_units += h_sim / maxf(labor, 0.000001)
	# 4. Layanan per unit: transaksi pembeli dan kemas RotiFood.
	var q_mean: float = maxf(qty_sum, 0.0001)
	var checkout: float = sim.upgrades.checkout_seconds()
	var service_u: float = (d_walk * (checkout + SERVICE_OVERHEAD_SECONDS) / q_mean + d_rf * sim.rotifood.pack_seconds() / maxf(units_mean, 0.0001)) / d_total
	var cashier_units: float = float(sim.staff.working_ids(&"cashier").size()) * h_sim / maxf(service_u, 0.000001)
	var owner_serve_units: float = h_sim / maxf(service_u, 0.000001)
	var owner_kitchen_units: float = h_sim / maxf(owner_labor_u, 0.000001)
	# 5. Unit terjual: terbesar yang muat permintaan, mesin, dan waktu pemilik.
	var hi: float = minf(d_total, p_machine)
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
	out["units_per_hour"] = units
	# 6. Laba bersih per unit (harga rak termasuk bonus rak; RotiFood × price_mult).
	var net: float = 0.0
	var rf_mult: float = DataRegistry.idlef("rotifood.price_mult")
	var boost_div: float = 1.0 if with_boosts else maxf(sim.boost_income_mult(), 0.0001)
	for rid7: Variant in menu:
		var rr: RecipeDefinition = DataRegistry.recipe(StringName(str(rid7)))
		var bonus: float = float(slot_price_bonus[rid7]) / float(slot_count[rid7])
		var price: float = sim.recipe_price(rr.id) * (1.0 + bonus) / boost_div
		var share_w: float = float(demand_w[rid7]) / d_total
		var share_rf: float = float(demand_rf[rid7]) / d_total
		net += share_w * (price - rr.unit_cogs_kr()) + share_rf * (price * rf_mult - rr.unit_cogs_kr())
	out["net_per_unit"] = net
	var real_per_hour: float = h_sim / maxf(DataRegistry.sim_seconds_per_real_second(), 0.0001)
	out["rate"] = maxf(0.0, units * net / real_per_hour)
	return out


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


## Panjang satu putaran kerja dapur (meter): mixer -> oven -> rak -> mixer lewat
## rute sungguhan (termasuk tangga di lokasi dua lantai). Di-cache per tata letak.
func _walk_cycle_m() -> float:
	var mixers: Array[EquipmentInstance] = sim.equipment.placed_list(&"mixer")
	var ovens: Array[EquipmentInstance] = sim.equipment.placed_list(&"oven")
	var shelves: Array[EquipmentInstance] = sim.equipment.placed_list(&"display")
	if mixers.is_empty() or ovens.is_empty() or shelves.is_empty():
		return 0.0
	var key: String = "%d|%d|%d|%s|%s|%s" % [mixers[0].iid, ovens[0].iid, shelves[0].iid, mixers[0].anchor, ovens[0].anchor, shelves[0].anchor]
	if _walk_cache.has(key):
		return _walk_cache[key]
	var stops: Array[EquipmentInstance] = [mixers[0], ovens[0], shelves[0], mixers[0]]
	var total: float = 0.0
	for i in 3:
		total += _route_m(stops[i], stops[i + 1])
	_walk_cache = {key: total}
	return total


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
