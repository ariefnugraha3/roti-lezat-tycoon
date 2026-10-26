class_name DemandManager
extends SimManager
## DemandManager — pemilik penjadwalan kedatangan (GDD idle 6.1, 6.5; v3.1 20.4,
## 20.5, 67, 98).
##
## Kedatangan pembeli dan pesanan RotiFood berjalan terus 24 jam sebagai proses
## Poisson dengan laju dari `SimulationRoot.arrival_rate_per_hour` dan
## `rotifood_rate_per_hour`. Kedatangan yang tidak mendapat slot antrean
## menjadi data pending (bukan aktor) dan kedaluwarsa diam-diam setelah batas
## tunggu (v3.1 67). Pengunjung lihat-lihat (v3.1 20.12) punya jadwal sendiri
## yang murni kosmetik dari cosmetic_rng, sehingga siapa pembeli berikutnya dan
## apa yang ia beli tidak pernah berubah karena mereka (v3.1 116).
##
## Waktu jadwal = detik jam absolut sejak Hari 1 00:00 (`abs_time`), supaya
## jadwal tetap benar melewati tengah malam.

var next_physical_at: float = -1.0
var next_rotifood_at: float = -1.0
var next_window_shopper_at: float = -1.0
## {archetype, since}
var pending: Array[Dictionary] = []
var _retry_timer: float = 0.0
var _admission_cooldown: float = 0.0


## Jadwal pertama dibuat pada tick pertama (semua manajer sudah siap).
func new_game() -> void:
	pending.clear()
	next_physical_at = -1.0
	next_rotifood_at = -1.0
	next_window_shopper_at = -1.0


## Detik jam in-game sejak Hari 1 00:00.
func abs_time() -> float:
	return float(sim.time.day - 1) * TimeManager.DAY_SECONDS + sim.time.time_seconds


## Jam in-game (0..86400) dari waktu absolut.
static func clock_of(t_abs: float) -> float:
	return fposmod(t_abs, TimeManager.DAY_SECONDS)


func time_block(t: float) -> StringName:
	var blocks: Dictionary = DataRegistry.time_blocks()
	for k: Variant in blocks.keys():
		var v: Vector2 = blocks[k]
		if t >= v.x and t < v.y:
			return k
	return &"evening"


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
	next_physical_at = from_t + _interval(sim.arrival_rate_per_hour(clock_of(from_t)), r, DataRegistry.balf("queue.min_admission_interval_seconds"))


func _schedule_next_rotifood(from_t: float) -> void:
	var r: RandomNumberGenerator = sim.rng.stream(&"rotifood_rng")
	next_rotifood_at = from_t + _interval(sim.rotifood_rate_per_hour(clock_of(from_t)), r, 1.0)


## Laju pengunjung lihat-lihat (v3.1 20.12): orang lewat yang menengok ke dalam,
## menurut tier, malam, cuaca, dan hari libur. Reputasi dan promosi tidak
## berpengaruh, jadi jumlah mereka tidak memberi sinyal apa pun kepada pemain.
func window_shopper_rate_per_hour(t: float) -> float:
	return sim.base_arrivals_per_hour() * sim.night_arrival_mult(t) * sim.weather.physical_multiplier() \
		* sim.weather.event_physical_multiplier() * DataRegistry.balf("window_shopper.rate_ratio")


func _schedule_next_window_shopper(from_t: float) -> void:
	var r: RandomNumberGenerator = sim.rng.stream(&"cosmetic_rng")
	next_window_shopper_at = from_t + _interval(window_shopper_rate_per_hour(clock_of(from_t)), r, DataRegistry.balf("queue.min_admission_interval_seconds"))


## Penampilan pengunjung lihat-lihat: bobot arketipe tier × jam (v3.1 20.11),
## diundi dari cosmetic_rng karena tidak memengaruhi gameplay (v3.1 116).
func roll_window_shopper_look(t: float) -> StringName:
	var block: StringName = time_block(t)
	var weights: Dictionary = {}
	for def: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var w: float = def.spawn_weight(sim.world.location.tier) * def.time_modifier(block)
		if w > 0.0:
			weights[String(def.id)] = w
	var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"cosmetic_rng"), weights)
	return StringName(str(pick)) if pick != null else &"customer_generic"


## Arketipe dari bobot tier × modifier jam (v3.1 20.11), dinormalisasi.
func roll_archetype(t: float) -> StringName:
	var block: StringName = time_block(t)
	var weights: Dictionary = {}
	for def: CustomerArchetypeDefinition in DataRegistry.archetypes():
		var w: float = def.spawn_weight(sim.world.location.tier) * def.time_modifier(block)
		if w > 0.0:
			weights[String(def.id)] = w
	var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"customer_arrival_rng"), weights)
	return StringName(str(pick)) if pick != null else &"customer_generic"


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	var now: float = abs_time()
	if next_physical_at < 0.0:
		_schedule_next_physical(now)
	if next_rotifood_at < 0.0:
		_schedule_next_rotifood(now)
	if next_window_shopper_at < 0.0:
		_schedule_next_window_shopper(now)
	while now >= next_physical_at:
		var at: float = next_physical_at
		_enqueue({"archetype": roll_archetype(clock_of(at))})
		_schedule_next_physical(at)
	while now >= next_rotifood_at:
		var at2: float = next_rotifood_at
		sim.rotifood.create_random_order()
		_schedule_next_rotifood(at2)
	_process_pending(dt)
	# Pengunjung lihat-lihat, sesudah pembeli pending mendapat giliran (v3.1 20.12).
	while now >= next_window_shopper_at:
		var at3: float = next_window_shopper_at
		sim.customers.try_admit_window_shopper(roll_window_shopper_look(clock_of(at3)))
		_schedule_next_window_shopper(at3)


func _enqueue(arrival: Dictionary) -> void:
	var cap: int = mini(DataRegistry.bali("queue.max_pending_physical"),
		DataRegistry.bali("queue.pending_pool_capacity_multiplier") * maxi(1, sim.queue.physical_capacity_open()))
	if pending.size() >= cap:
		sim.statistics.add(&"total_customers_missed", 1)
		return
	arrival["since"] = sim.time.sim_seconds
	pending.append(arrival)
	_retry_timer = 0.0


func _process_pending(dt: float) -> void:
	_admission_cooldown = maxf(0.0, _admission_cooldown - dt)
	_retry_timer -= dt
	var max_wait: float = DataRegistry.balf("queue.physical_max_pending_seconds")
	# Kedaluwarsa diam-diam: belum pernah masuk toko, tanpa penalti (v3.1 67).
	for i in range(pending.size() - 1, -1, -1):
		if sim.time.sim_seconds - float(pending[i]["since"]) > max_wait:
			pending.remove_at(i)
			sim.statistics.add(&"total_customers_missed", 1)
	if pending.is_empty() or _retry_timer > 0.0 or _admission_cooldown > 0.0:
		return
	_retry_timer = DataRegistry.balf("queue.pending_retry_seconds")
	if sim.customers.try_admit(pending[0]):
		pending.pop_front()
		_admission_cooldown = DataRegistry.balf("queue.min_admission_interval_seconds")


## Slot antrean baru bebas: coba lagi pada tick berikutnya (v3.1 20.5).
func on_slot_freed() -> void:
	_retry_timer = 0.0


func capture() -> Dictionary:
	var pend: Array = []
	for p: Dictionary in pending:
		pend.append({"archetype": String(p["archetype"]), "since": p["since"]})
	return {"next_physical_at": next_physical_at, "next_rotifood_at": next_rotifood_at,
		"next_window_shopper_at": next_window_shopper_at, "pending": pend}


func restore(d: Dictionary) -> void:
	pending.clear()
	for p: Variant in d.get("pending", []):
		var pd: Dictionary = p
		pending.append({"archetype": StringName(str(pd["archetype"])), "since": float(pd["since"])})
	next_physical_at = float(d.get("next_physical_at", -1.0))
	next_rotifood_at = float(d.get("next_rotifood_at", -1.0))
	next_window_shopper_at = float(d.get("next_window_shopper_at", -1.0))
