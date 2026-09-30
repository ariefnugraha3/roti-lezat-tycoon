class_name CashierManager
extends SimManager
## CashierManager — pemilik transaksi di jalur kasir (GDD 21, 98, 103.1).
##
## Lane dengan Asisten Kasir bertugas melayani OTOMATIS. Tanpa asisten, lane
## utama hanya bergerak selama karakter pemain berdiri di cashier point; pergi
## berarti progres membeku di tempat, tidak dibatalkan (GDD 2, 21.4).
##
## Setiap transaksi seluruhnya fase membungkus dan berlangsung `packing_seconds`
## (3 dtk) untuk siapa pun yang melayani: roti masuk kantong kertas di meja sejak
## detik pertama, baru kemudian pembeli membayar dan pulang menenteng kantongnya
## (GDD 21.4, keputusan maintainer 2026-09-29).

## lane_id -> {customer, elapsed, duration, manual, confirmed}
var transactions: Dictionary = {}


func new_game() -> void:
	transactions.clear()


## Lama satu transaksi (GDD 21.4): sama untuk pemain, semua tier Asisten Kasir,
## dan semua tipe pembeli.
static func transaction_seconds() -> float:
	return DataRegistry.packing_seconds()


## Kemajuan fase membungkus transaksi pada lane, 0..1 sejak transaksi dimulai;
## -1 bila tidak ada transaksi (dipakai tampilan kantong di meja, GDD 21.4).
func packing_progress(lane_id: StringName) -> float:
	var t: Variant = transactions.get(lane_id)
	if not (t is Dictionary) or not bool((t as Dictionary)["confirmed"]):
		return -1.0
	var td: Dictionary = t
	return clampf(float(td["elapsed"]) / maxf(float(td["duration"]), 0.0001), 0.0, 1.0)


func remaining_time(lane: QueueLane) -> float:
	var t: Variant = transactions.get(lane.id)
	if t is Dictionary:
		var td: Dictionary = t
		return maxf(0.0, float(td["duration"]) - float(td["elapsed"]))
	if lane.service_occupant != &"":
		return transaction_seconds()
	return 0.0


func is_progressing(customer_id: StringName) -> bool:
	for k: Variant in transactions.keys():
		var t: Dictionary = transactions[k]
		if t["customer"] == customer_id and bool(t["confirmed"]):
			var lane: QueueLane = sim.queue.lane(StringName(str(k)))
			return _can_progress(lane, t)
	return false


func transaction_for(lane_id: StringName) -> Dictionary:
	return transactions.get(lane_id, {})


func cancel_for(customer_id: StringName) -> void:
	for k: Variant in transactions.keys():
		if (transactions[k] as Dictionary)["customer"] == customer_id:
			transactions.erase(k)
			return


## Pemain menekan OK di popup pesanan (GDD 21.4).
func confirm_manual(customer_id: StringName) -> bool:
	var c: Customer = sim.customers.customer(customer_id)
	if c == null or c.state != Customer.FRONT_OF_QUEUE:
		return false
	var lane: QueueLane = sim.queue.lane(c.lane_id)
	if lane == null or lane.service_occupant != c.id:
		return false
	transactions[lane.id] = {
		"customer": c.id, "elapsed": 0.0, "duration": transaction_seconds(),
		"manual": true, "confirmed": true,
	}
	c.awaiting_tap = false
	c.state = Customer.BEING_SERVED
	sim.tutorial.on_event(&"manual_service_started")
	return true


func _can_progress(lane: QueueLane, t: Dictionary) -> bool:
	if not bool(t["manual"]):
		return true
	return sim.player.is_manning_lane(lane.id)


func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	for lane: QueueLane in sim.queue.lanes:
		var occupant: StringName = lane.service_occupant
		if occupant == &"":
			transactions.erase(lane.id)
			continue
		var c: Customer = sim.customers.customer(occupant)
		if c == null:
			continue
		if c.actor.has_route():
			continue
		var t: Variant = transactions.get(lane.id)
		if t == null or (t as Dictionary)["customer"] != c.id:
			var staff_def: StaffDefinition = sim.staff.cashier_def_for_lane(lane.id)
			if staff_def != null and sim.staff.cashier_at_post(lane.id):
				# Asisten melayani otomatis tanpa tap pemain (GDD 21.5).
				transactions[lane.id] = {
					"customer": c.id, "elapsed": 0.0, "duration": transaction_seconds(),
					"manual": false, "confirmed": true,
				}
				c.awaiting_tap = false
				c.state = Customer.BEING_SERVED
			else:
				c.awaiting_tap = true
			continue
		var td: Dictionary = t
		if not _can_progress(lane, td):
			continue
		var before: float = float(td["elapsed"])
		td["elapsed"] = before + dt
		# Suara kantong kertas tepat saat membungkus dimulai, yaitu di tick pertama
		# transaksi berjalan (GDD 21.4, 93).
		if before <= 0.0 and float(td["elapsed"]) > 0.0:
			EventBus.sfx.emit(&"cashier_pack", lane.floor_id)
		if float(td["elapsed"]) >= float(td["duration"]):
			transactions.erase(lane.id)
			_complete(c, lane, not bool(td["manual"]))


## Commit penjualan fisik (GDD 103.1). Langkah 1-3 divalidasi dulu; setelah roti
## ditandai terjual semua pembukuan diselesaikan dalam tick yang sama.
func _complete(c: Customer, lane: QueueLane, by_staff: bool) -> void:
	# 1. Validasi ulang: unit yang sudah UNSALEABLE ditolak ke disposal (GDD 19.7.4).
	var sold_lots: Array = []
	for l: Variant in c.held:
		var lot: Dictionary = l
		var st: BreadStack = lot["stack"]
		sim.display.age_held(lot)
		if st.freshness_state == &"UNSALEABLE":
			var r: RecipeDefinition = DataRegistry.recipe(st.recipe_id)
			sim.analytics.note_wasted(st.recipe_id, st.quantity, r.unit_cogs_kr() * st.quantity, &"expired")
			sim.economy.note_waste(r.unit_cogs_kr() * st.quantity)
			continue
		sold_lots.append(lot)
	if sold_lots.is_empty():
		c.held.clear()
		sim.customers.on_paid(c)
		return
	# 2. Subtotal dari harga yang dikunci saat roti diambil dari rak.
	var subtotal: float = 0.0
	var units: int = 0
	var bad_quality: bool = false
	var all_fresh_prime: bool = true
	var any_stale: bool = false
	var min_bake: float = 1.0
	for lot2: Variant in sold_lots:
		var st2: BreadStack = (lot2 as Dictionary)["stack"]
		var price: float = float((lot2 as Dictionary)["unit_price"])
		subtotal += Money.round_half_up(price) * st2.quantity
		units += st2.quantity
		min_bake = minf(min_bake, st2.bake_quality)
		if st2.bake_quality < DataRegistry.balf("rating.bad_quality_bake_threshold") or st2.freshness_state == &"STALE":
			bad_quality = true
		if st2.freshness_state == &"STALE":
			any_stale = true
		if st2.freshness_state != &"FRESH" or st2.bake_quality < DataRegistry.balf("rotifood.fresh_bonus_min_bake_quality"):
			all_fresh_prime = false
	# 3-4. Layanan selesai; roti resmi terjual dan tidak pernah kembali ke rak.
	c.held.clear()
	# 5. Tip fisik hanya dari Asisten Kasir Tier 5 (GDD 21.8).
	var tip: float = 0.0
	var staff_def: StaffDefinition = sim.staff.cashier_def_for_lane(lane.id) if by_staff else null
	if staff_def != null:
		var chance: float = staff_def.special_value("physical_tip_chance", 0.0)
		if chance > 0.0 and sim.rng.stream(&"customer_choice_rng").randf() < chance:
			tip = Money.round_half_up(subtotal * DataRegistry.balf("physical_tip.fraction"))
	# 6. Ledger.
	sim.economy.credit(subtotal, &"SALE_PHYSICAL", c.archetype, {"customer": String(c.id), "units": units})
	if tip > 0.0:
		sim.economy.credit(tip, &"TIP_PHYSICAL", c.archetype, {"customer": String(c.id)})
	# 7. Analitik & statistik.
	for lot3: Variant in sold_lots:
		var st3: BreadStack = (lot3 as Dictionary)["stack"]
		var p3: float = float((lot3 as Dictionary)["unit_price"])
		sim.analytics.note_sold(st3.recipe_id, st3.quantity, p3 * st3.quantity, &"physical", st3.freshness_state == &"STALE")
		sim.pricing.note_sold_at(st3.recipe_id, p3)
	sim.statistics.note_physical_sale(units, subtotal + tip)
	sim.demand.note_units_delivered(units)
	# 8. Reputasi (GDD 25.2).
	var ts: float = sim.customers.tier_scale()
	if bad_quality:
		sim.reputation.physical_event(&"bad_quality_sale", ts)
	else:
		sim.reputation.physical_event(&"successful_sale", ts)
	if c.queue_wait <= c.patience_max * DataRegistry.balf("rating.fast_service_max_wait_ratio"):
		sim.reputation.physical_event(&"fast_service", ts)
	if c.is_critic:
		var vr: Dictionary = DataRegistry.vip_rules()
		if c.queue_wait > c.patience_max * float(vr["failure_wait_ratio"]) or any_stale or min_bake < float(vr["failure_bake_quality"]):
			c.outcome = &"vip_failure"
		elif c.queue_wait <= c.patience_max * float(vr["success_max_wait_ratio"]) and all_fresh_prime and min_bake >= float(vr["success_min_bake_quality"]):
			c.outcome = &"vip_success"
		else:
			c.outcome = &"neutral"
		if c.outcome != &"neutral":
			sim.reputation.queue_vip(c.outcome)
	# 9. Presentasi.
	EventBus.sale_completed.emit(subtotal + tip, &"physical")
	EventBus.sfx.emit(&"cashier_coin", lane.floor_id)
	EventBus.sfx.emit(&"sale_success", lane.floor_id)
	EventBus.coin_popup.emit(subtotal + tip, lane.service_point, lane.floor_id)
	sim.customers.on_paid(c)
	sim.tutorial.on_event(&"first_payment")


func capture() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in transactions.keys():
		var t: Dictionary = transactions[k]
		out[str(k)] = {"customer": String(t["customer"]), "elapsed": t["elapsed"], "duration": t["duration"],
			"manual": t["manual"], "confirmed": t["confirmed"]}
	return out


func restore(d: Dictionary) -> void:
	transactions.clear()
	for k: Variant in d.keys():
		var t: Dictionary = d[k]
		transactions[StringName(str(k))] = {"customer": StringName(str(t["customer"])), "elapsed": float(t["elapsed"]),
			"duration": float(t["duration"]), "manual": bool(t["manual"]), "confirmed": bool(t["confirmed"])}
