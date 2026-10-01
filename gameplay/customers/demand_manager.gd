class_name DemandManager
extends SimManager
## DemandManager — pemilik penjadwalan kedatangan (GDD 20.3-20.5, 25.4, 65-67, 98).
##
## Hari 1-3 memakai manifest deterministik tanpa RNG. Mulai Hari 4 kedatangan
## fisik & order RotiFood dijadwalkan dari rumus demand per channel. Kedatangan
## yang tidak mendapat slot antrean menjadi data pending (bukan aktor) dan
## kedaluwarsa diam-diam setelah batas tunggu (GDD 67). Pengunjung lihat-lihat
## (GDD 20.12) punya jadwal sendiri yang murni kosmetik: manifest Hari 1-3,
## lalu proses Poisson dari cosmetic_rng, sehingga siapa pembeli berikutnya dan
## apa yang ia beli tidak pernah berubah karena mereka (GDD 116).

var scripted_walkins: Array[Dictionary] = []
var scripted_orders: Array[Dictionary] = []
## {time, archetype}
var scripted_window_shoppers: Array[Dictionary] = []
var next_physical_at: float = -1.0
var next_rotifood_at: float = -1.0
var next_window_shopper_at: float = -1.0
var critic_at: float = -1.0
## {archetype, scripted, recipe, quantity, patience_override, since}
var pending: Array[Dictionary] = []
var demand_total_today: int = 0
var delivered_today: int = 0
var missed_today: int = 0
var _retry_timer: float = 0.0
var _admission_cooldown: float = 0.0


func new_game() -> void:
	reset_day()


func reset_day() -> void:
	scripted_walkins.clear()
	scripted_orders.clear()
	scripted_window_shoppers.clear()
	pending.clear()
	next_physical_at = -1.0
	next_rotifood_at = -1.0
	next_window_shopper_at = -1.0
	critic_at = -1.0
	demand_total_today = 0
	delivered_today = 0
	missed_today = 0


func is_scripted_day() -> bool:
	return not DataRegistry.opening_day(sim.time.day).is_empty()


## Rencana hari dibuat pukul 05:00.
func plan_day() -> void:
	reset_day()
	var plan: Dictionary = DataRegistry.opening_day(sim.time.day)
	if not plan.is_empty():
		for w: Variant in plan.get("walk_ins", []):
			var wd: Dictionary = w
			scripted_walkins.append({
				"time": float(wd["spawn_time"]), "archetype": StringName(str(wd["customer_archetype"])),
				"recipe": StringName(str(wd["requested_recipe_id"])), "quantity": int(wd["requested_quantity"]),
				"patience_override": wd.get("patience_override"),
			})
			demand_total_today += int(wd["requested_quantity"])
		for o: Variant in plan.get("rotifood_orders", []):
			var od: Dictionary = o
			scripted_orders.append({"time": float(od["order_time"]), "recipe": StringName(str(od["requested_recipe_id"])),
				"quantity": int(od["requested_quantity"])})
			demand_total_today += int(od["requested_quantity"])
		for ws: Variant in plan.get("window_shoppers", []):
			var wsd: Dictionary = ws
			scripted_window_shoppers.append({"time": float(wsd["spawn_time"]), "archetype": StringName(str(wsd["customer_archetype"]))})
		return
	next_physical_at = sim.time.open_time
	next_rotifood_at = sim.time.open_time
	_schedule_next_physical(sim.time.open_time)
	_schedule_next_rotifood(sim.time.open_time)
	_schedule_next_window_shopper(sim.time.open_time)
	_roll_critic()


func _roll_critic() -> void:
	var def: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_critic")
	var chance: float = def.daily_chance(sim.world.location.tier) * sim.marketing.critic_chance_multiplier()
	var r: RandomNumberGenerator = sim.rng.stream(&"customer_arrival_rng")
	if chance > 0.0 and r.randf() < chance:
		critic_at = r.randf_range(def.arrival_window.x, def.arrival_window.y)


func note_units_delivered(units: int) -> void:
	delivered_today += units


# ===========================================================================
# RUMUS DEMAND (GDD 65, 66)
# ===========================================================================

func time_block(t: float) -> StringName:
	var blocks: Dictionary = DataRegistry.time_blocks()
	for k: Variant in blocks.keys():
		var v: Vector2 = blocks[k]
		if t >= v.x and t < v.y:
			return k
	return &"evening"


func physical_rate_per_hour(t: float) -> float:
	var loc: LocationDefinition = sim.world.location
	var rm: Dictionary = DataRegistry.bal("demand.physical_rating_multiplier")
	var rating_mult: float = clampf(float(rm["base"]) + float(rm["per_star"]) * sim.reputation.physical, float(rm["min"]), float(rm["max"]))
	var tod: float = float(DataRegistry.bal("demand.physical_time_of_day")[String(time_block(t))])
	return loc.base_physical_rate * rating_mult * tod * sim.weather.physical_multiplier() \
		* sim.marketing.traffic_multiplier() * price_mix_multiplier() * sim.weather.event_physical_multiplier()


func rotifood_rate_per_hour(t: float) -> float:
	var loc: LocationDefinition = sim.world.location
	var sm: Dictionary = DataRegistry.bal("demand.rotifood_star_multiplier")
	var star: float = clampf(float(sm["base"]) + float(sm["per_star"]) * sim.reputation.rotifood, float(sm["min"]), float(sm["max"]))
	if sim.reputation.rotifood >= DataRegistry.balf("rating.trusted_badge_stars"):
		star *= float(sm["badge_multiplier"])
	star = minf(star, float(sm["total_max"]))
	var tod: float = float(DataRegistry.bal("demand.rotifood_time_of_day")[String(time_block(t))])
	return loc.base_rotifood_rate * star * tod * sim.weather.delivery_multiplier() * price_mix_multiplier() \
		* sim.weather.event_delivery_multiplier()


## Rata-rata berbobot price_demand baseline roti yang tersedia (GDD 65).
func price_mix_multiplier() -> float:
	var stock: Dictionary = sim.display.sellable_by_recipe()
	var total: float = 0.0
	var acc: float = 0.0
	for rid: Variant in stock.keys():
		var n: float = float(stock[rid])
		total += n
		acc += n * sim.pricing.baseline_demand(rid)
	if total <= 0.0:
		return 1.0
	var cl: Array = DataRegistry.bal("demand.price_mix_clamp")
	return clampf(acc / total, float(cl[0]), float(cl[1]))


## Interval berikutnya (proses Poisson, detik jam in-game). Laju per detik-
## simulasi = laju per jam in-game / detik-simulasi per jam in-game.
func _interval(rate_per_hour: float, stream: RandomNumberGenerator, min_sim_seconds: float) -> float:
	if rate_per_hour <= 0.0001:
		return 3600.0
	var per_sim: float = rate_per_hour / sim.time.sim_seconds_for_hours(1.0)
	var u: float = maxf(stream.randf(), 0.000001)
	var dt_sim: float = maxf(-log(u) / per_sim, min_sim_seconds)
	return dt_sim * sim.time.ratio


func _schedule_next_physical(from_t: float) -> void:
	var r: RandomNumberGenerator = sim.rng.stream(&"customer_arrival_rng")
	next_physical_at = from_t + _interval(physical_rate_per_hour(from_t), r, DataRegistry.balf("queue.min_admission_interval_seconds"))


func _schedule_next_rotifood(from_t: float) -> void:
	var r: RandomNumberGenerator = sim.rng.stream(&"rotifood_rng")
	next_rotifood_at = from_t + _interval(rotifood_rate_per_hour(from_t), r, 1.0)


## Laju pengunjung lihat-lihat (GDD 20.12): orang lewat yang menengok ke dalam,
## menurut tier, jam, cuaca, dan hari libur. Rating, harga, dan kampanye tidak
## berpengaruh, jadi jumlah mereka tidak memberi sinyal apa pun kepada pemain.
func window_shopper_rate_per_hour(t: float) -> float:
	var tod: float = float(DataRegistry.bal("demand.physical_time_of_day")[String(time_block(t))])
	return sim.world.location.base_physical_rate * tod * sim.weather.physical_multiplier() \
		* sim.weather.event_physical_multiplier() * DataRegistry.balf("window_shopper.rate_ratio")


func _schedule_next_window_shopper(from_t: float) -> void:
	var r: RandomNumberGenerator = sim.rng.stream(&"cosmetic_rng")
	next_window_shopper_at = from_t + _interval(window_shopper_rate_per_hour(from_t), r, DataRegistry.balf("queue.min_admission_interval_seconds"))


## Penampilan pengunjung lihat-lihat: bobot arketipe tier × jam (GDD 20.11),
## diundi dari cosmetic_rng karena tidak memengaruhi gameplay (GDD 116).
func roll_window_shopper_look(t: float) -> StringName:
	var block: StringName = time_block(t)
	var weights: Dictionary = {}
	for def: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var w: float = def.spawn_weight(sim.world.location.tier) * def.time_modifier(block)
		if w > 0.0:
			weights[String(def.id)] = w
	var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"cosmetic_rng"), weights)
	return StringName(str(pick)) if pick != null else &"customer_generic"


## Arketipe dari bobot tier × modifier jam × kampanye, dinormalisasi (GDD 20.11).
func roll_archetype(t: float) -> StringName:
	var block: StringName = time_block(t)
	var weights: Dictionary = {}
	for def: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var w: float = def.spawn_weight(sim.world.location.tier)
		if w <= 0.0:
			continue
		w *= def.time_modifier(block) * sim.marketing.archetype_multiplier(def.id, block)
		weights[String(def.id)] = w
	var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"customer_arrival_rng"), weights)
	return StringName(str(pick)) if pick != null else &"customer_generic"


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_open():
		return
	var now: float = sim.time.time_seconds
	# Manifest Hari 1-3.
	while not scripted_walkins.is_empty() and float(scripted_walkins[0]["time"]) <= now:
		var w: Dictionary = scripted_walkins.pop_front()
		_enqueue({"archetype": w["archetype"], "scripted": true, "recipe": w["recipe"],
			"quantity": w["quantity"], "patience_override": w["patience_override"]})
	while not scripted_orders.is_empty() and float(scripted_orders[0]["time"]) <= now:
		var o: Dictionary = scripted_orders.pop_front()
		sim.rotifood.create_scripted_order(o["recipe"], int(o["quantity"]))
	# Hari 4+.
	if next_physical_at >= 0.0:
		while now >= next_physical_at:
			var at: float = next_physical_at
			_enqueue({"archetype": roll_archetype(at), "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})
			_schedule_next_physical(at)
	if critic_at >= 0.0 and now >= critic_at:
		critic_at = -1.0
		_enqueue({"archetype": &"customer_critic", "scripted": false, "recipe": &"", "quantity": 0, "patience_override": null})
	if next_rotifood_at >= 0.0:
		while now >= next_rotifood_at:
			var at2: float = next_rotifood_at
			if at2 < DataRegistry.balf("rotifood.last_order_time_seconds"):
				sim.rotifood.create_random_order()
			_schedule_next_rotifood(at2)
	_process_pending(dt)
	# Pengunjung lihat-lihat, sesudah pembeli pending mendapat giliran (GDD 20.12).
	while not scripted_window_shoppers.is_empty() and float(scripted_window_shoppers[0]["time"]) <= now:
		var ws: Dictionary = scripted_window_shoppers.pop_front()
		sim.customers.try_admit_window_shopper(ws["archetype"])
	if next_window_shopper_at >= 0.0:
		while now >= next_window_shopper_at:
			var at3: float = next_window_shopper_at
			sim.customers.try_admit_window_shopper(roll_window_shopper_look(at3))
			_schedule_next_window_shopper(at3)


func _enqueue(arrival: Dictionary) -> void:
	var cap: int = mini(DataRegistry.bali("queue.max_pending_physical"),
		DataRegistry.bali("queue.pending_pool_capacity_multiplier") * maxi(1, sim.queue.physical_capacity_open()))
	if pending.size() >= cap:
		missed_today += 1
		return
	arrival["since"] = sim.time.sim_seconds
	pending.append(arrival)
	# Coba segera; interval minimum admission tetap dihormati.
	_retry_timer = 0.0


func _process_pending(dt: float) -> void:
	_admission_cooldown = maxf(0.0, _admission_cooldown - dt)
	_retry_timer -= dt
	var max_wait: float = DataRegistry.balf("queue.physical_max_pending_seconds")
	# Kedaluwarsa diam-diam: belum pernah masuk toko, tanpa penalti (GDD 67).
	for i in range(pending.size() - 1, -1, -1):
		if sim.time.sim_seconds - float(pending[i]["since"]) > max_wait:
			pending.remove_at(i)
			missed_today += 1
	if pending.is_empty() or _retry_timer > 0.0 or _admission_cooldown > 0.0:
		return
	_retry_timer = DataRegistry.balf("queue.pending_retry_seconds")
	if sim.customers.try_admit(pending[0]):
		pending.pop_front()
		_admission_cooldown = DataRegistry.balf("queue.min_admission_interval_seconds")


## Slot antrean baru bebas: coba lagi pada tick berikutnya (GDD 20.5).
func on_slot_freed() -> void:
	_retry_timer = 0.0


func capture() -> Dictionary:
	var walk: Array = []
	for w: Dictionary in scripted_walkins:
		walk.append({"time": w["time"], "archetype": String(w["archetype"]), "recipe": String(w["recipe"]),
			"quantity": w["quantity"], "patience_override": w["patience_override"]})
	var orders: Array = []
	for o: Dictionary in scripted_orders:
		orders.append({"time": o["time"], "recipe": String(o["recipe"]), "quantity": o["quantity"]})
	var pend: Array = []
	for p: Dictionary in pending:
		pend.append({"archetype": String(p["archetype"]), "scripted": p["scripted"], "recipe": String(p["recipe"]),
			"quantity": p["quantity"], "patience_override": p["patience_override"], "since": p["since"]})
	var lookers: Array = []
	for ws: Dictionary in scripted_window_shoppers:
		lookers.append({"time": ws["time"], "archetype": String(ws["archetype"])})
	return {"scripted_walkins": walk, "scripted_orders": orders, "scripted_window_shoppers": lookers,
		"next_physical_at": next_physical_at, "next_rotifood_at": next_rotifood_at,
		"next_window_shopper_at": next_window_shopper_at, "critic_at": critic_at, "pending": pend,
		"demand_total_today": demand_total_today, "delivered_today": delivered_today, "missed_today": missed_today}


func restore(d: Dictionary) -> void:
	reset_day()
	for w: Variant in d.get("scripted_walkins", []):
		var wd: Dictionary = w
		scripted_walkins.append({"time": float(wd["time"]), "archetype": StringName(str(wd["archetype"])),
			"recipe": StringName(str(wd["recipe"])), "quantity": int(wd["quantity"]), "patience_override": wd.get("patience_override")})
	for o: Variant in d.get("scripted_orders", []):
		var od: Dictionary = o
		scripted_orders.append({"time": float(od["time"]), "recipe": StringName(str(od["recipe"])), "quantity": int(od["quantity"])})
	# Save lama belum punya pengunjung lihat-lihat: hari itu berjalan tanpa mereka.
	for ws: Variant in d.get("scripted_window_shoppers", []):
		var wsd: Dictionary = ws
		scripted_window_shoppers.append({"time": float(wsd["time"]), "archetype": StringName(str(wsd["archetype"]))})
	for p: Variant in d.get("pending", []):
		var pd: Dictionary = p
		pending.append({"archetype": StringName(str(pd["archetype"])), "scripted": bool(pd["scripted"]),
			"recipe": StringName(str(pd["recipe"])), "quantity": int(pd["quantity"]),
			"patience_override": pd.get("patience_override"), "since": float(pd["since"])})
	next_physical_at = float(d.get("next_physical_at", -1.0))
	next_rotifood_at = float(d.get("next_rotifood_at", -1.0))
	next_window_shopper_at = float(d.get("next_window_shopper_at", -1.0))
	critic_at = float(d.get("critic_at", -1.0))
	demand_total_today = int(d.get("demand_total_today", 0))
	delivered_today = int(d.get("delivered_today", 0))
	missed_today = int(d.get("missed_today", 0))
