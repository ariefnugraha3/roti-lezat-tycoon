class_name RotiFoodManager
extends SimManager
## RotiFoodManager — pemilik pesanan RotiFood dan driver-nya (GDD 3.6, 9.2, 22,
## 98, 103.2, 104).
##
## Stok TIDAK di-reserve saat order masuk. Packing memotong stok secara atomik;
## handover terjadi otomatis begitu driver mencapai service point dan order
## sudah dikemas, dan pendapatan di-commit tepat sekali (`economy_committed`).

var orders: Dictionary = {}
var next_order_id: int = 1
var completed_today: int = 0
var cancelled_today: int = 0
var received_today: int = 0
var tips_today: float = 0.0


func new_game() -> void:
	orders.clear()
	next_order_id = 1
	reset_day()


func reset_day() -> void:
	completed_today = 0
	cancelled_today = 0
	received_today = 0
	tips_today = 0.0
	for k: Variant in orders.keys():
		if not (orders[k] as DeliveryOrder).is_active():
			orders.erase(k)


func order(order_id: int) -> DeliveryOrder:
	return orders.get(order_id)


func active_orders() -> Array[DeliveryOrder]:
	var ids: Array = orders.keys()
	ids.sort()
	var out: Array[DeliveryOrder] = []
	for i: Variant in ids:
		var o: DeliveryOrder = orders[i]
		if o.is_active():
			out.append(o)
	return out


func driver_count() -> int:
	var n: int = 0
	for o: DeliveryOrder in active_orders():
		if o.driver != null:
			n += 1
	return n


func driver_order(actor_id: StringName) -> DeliveryOrder:
	for o: DeliveryOrder in active_orders():
		if o.driver_id() == actor_id:
			return o
	return null


# ===========================================================================
# PEMBUATAN ORDER (GDD 20.3, 22.9)
# ===========================================================================

func create_scripted_order(recipe_id: StringName, qty: int) -> DeliveryOrder:
	var items: Dictionary = {recipe_id: qty}
	# Hari 1-3: prep_window tetap dari manifest (GDD 22.9).
	return _create(items, float(DataRegistry.opening_raw().get("manifest_prep_window_seconds", 90)), true)


## Order acak Hari 4+. Menu = resep yang punya stok sellable atau sudah selesai
## diproduksi hari ini; bila kosong, demand terlewat tanpa penalti.
func create_random_order() -> DeliveryOrder:
	var menu: Array = []
	var stock: Dictionary = sim.display.sellable_by_recipe()
	for rid: Variant in stock.keys():
		menu.append(rid)
	for rid2: Variant in sim.production.completed_today.keys():
		if not menu.has(rid2):
			menu.append(rid2)
	if menu.is_empty():
		return null
	menu.sort()
	var r: RandomNumberGenerator = sim.rng.stream(&"rotifood_rng")
	var dist: Dictionary = {}
	for pair: Variant in DataRegistry.bal("rotifood.units_distribution"):
		dist[int((pair as Array)[0])] = float((pair as Array)[1])
	var units: int = int(RNGManager.weighted_pick(r, dist))
	var kinds: int = 1
	if menu.size() > 1 and r.randf() < DataRegistry.balf("rotifood.two_recipe_chance"):
		kinds = 2
	var items: Dictionary = {}
	var picks: Array = []
	var pool: Array = menu.duplicate()
	for k in kinds:
		var idx: int = r.randi_range(0, pool.size() - 1)
		picks.append(pool[idx])
		pool.remove_at(idx)
	for i in picks.size():
		var share: int = units / picks.size() + (1 if i < units % picks.size() else 0)
		if share > 0:
			items[StringName(str(picks[i]))] = share
	var pw: Array = DataRegistry.bal("rotifood.prep_window_seconds")
	return _create(items, r.randf_range(float(pw[0]), float(pw[1])), false)


func _create(items: Dictionary, prep_window: float, scripted: bool) -> DeliveryOrder:
	var o := DeliveryOrder.new()
	o.order_id = next_order_id
	next_order_id += 1
	o.items = items
	for rid: Variant in items.keys():
		o.unit_prices[rid] = sim.pricing.price_of(rid)
	o.created_at = sim.time.sim_seconds
	o.created_ingame = sim.time.time_seconds
	o.prep_window = prep_window
	o.driver_arrival_time = o.created_at + prep_window
	o.scripted = scripted
	o.driver_patience_max = float(DataRegistry.driver_def().get("base_patience_seconds", 30.0))
	o.driver_patience = o.driver_patience_max
	o.state = DeliveryOrder.NOTIFIED
	orders[o.order_id] = o
	received_today += 1
	sim.statistics.add(&"total_rotifood_orders_received", 1)
	EventBus.delivery_order_created.emit(o.order_id)
	EventBus.sfx.emit(&"rotifood_incoming", sim.world.store_floor())
	sim.tutorial.on_event(&"rotifood_order")
	return o


# ===========================================================================
# PACKING (GDD 22.3-22.5, 103.2)
# ===========================================================================

func mark_opened(order_id: int) -> void:
	var o: DeliveryOrder = order(order_id)
	if o != null and o.state == DeliveryOrder.NOTIFIED:
		o.state = DeliveryOrder.OPENED


## Kekurangan per resep (untuk tanda merah di popup).
func shortages(o: DeliveryOrder) -> Dictionary:
	var out: Dictionary = {}
	var stock: Dictionary = sim.display.sellable_by_recipe()
	for rid: Variant in o.items.keys():
		var short: int = int(o.items[rid]) - int(stock.get(rid, 0))
		if short > 0:
			out[rid] = short
	return out


## Kemas order: semua item dipotong sekaligus atau tidak sama sekali.
func pack(order_id: int) -> bool:
	var o: DeliveryOrder = order(order_id)
	if o == null or not o.is_active() or o.packed:
		return false
	if not shortages(o).is_empty():
		o.state = DeliveryOrder.WAITING_FOR_STOCK
		return false
	o.state = DeliveryOrder.PACKING
	var all_lots: Array = []
	var ok: bool = true
	var no_filter: Callable = Callable()
	var keys: Array = o.items.keys()
	keys.sort()
	for rid: Variant in keys:
		var lots: Array[Dictionary] = sim.display.take(rid, int(o.items[rid]), no_filter, -1, float(o.unit_prices[rid]), false)
		if lots.is_empty():
			ok = false
			break
		all_lots.append_array(lots)
	if not ok:
		# Rollback transaksional (GDD 38.3).
		sim.display.return_lots(all_lots)
		o.state = DeliveryOrder.WAITING_FOR_STOCK
		return false
	o.packed = true
	o.packed_lots = all_lots
	o.packed_at = sim.time.sim_seconds
	var prime: bool = true
	for l: Variant in all_lots:
		var st: BreadStack = (l as Dictionary)["stack"]
		if st.freshness_state != &"FRESH" or st.bake_quality < DataRegistry.balf("rotifood.fresh_bonus_min_bake_quality"):
			prime = false
	o.packed_all_prime = prime
	o.state = DeliveryOrder.PACKED_WAITING_DRIVER
	EventBus.sfx.emit(&"rotifood_pack_done", sim.world.store_floor())
	sim.tutorial.on_event(&"rotifood_packed")
	return true


# ===========================================================================
# DRIVER (GDD 22.6, 22.9, 58, 67)
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	var now: float = sim.time.sim_seconds
	for o: DeliveryOrder in active_orders():
		match o.driver_phase:
			&"none":
				if now >= o.driver_arrival_time:
					o.driver_phase = &"pending"
					o.driver_pending_since = now
					o.state = DeliveryOrder.DRIVER_EN_ROUTE if not o.packed else o.state
			&"pending":
				if now - o.driver_pending_since > DataRegistry.balf("queue.rotifood_max_pending_seconds"):
					_fail(o, &"pending_expired", false)
				else:
					_try_admit_driver(o)
			&"entering":
				o.driver.step(dt, sim.world)
				_drain(o, dt)
				_driver_to_queue(o)
			&"queued":
				o.driver.step(dt, sim.world)
				_drain(o, dt)
				_driver_queued(o)
			&"at_service":
				o.driver.step(dt, sim.world)
				if o.driver.has_route():
					_drain(o, dt)
					continue
				if o.packed:
					_handover(o)
				else:
					o.state = DeliveryOrder.DRIVER_WAITING
					_drain(o, dt)
		_smart_speed(o, now)
	for o2: DeliveryOrder in _leaving():
		o2.driver.step(dt, sim.world)
		if not o2.driver.has_route():
			sim.world.release_all_for(o2.driver_id())
			o2.driver = null
			o2.driver_phase = &"gone"


func _leaving() -> Array[DeliveryOrder]:
	var out: Array[DeliveryOrder] = []
	var ids: Array = orders.keys()
	ids.sort()
	for i: Variant in ids:
		var o: DeliveryOrder = orders[i]
		if o.driver_phase == &"leaving" and o.driver != null:
			out.append(o)
	return out


func _try_admit_driver(o: DeliveryOrder) -> void:
	if not sim.time.is_open():
		return
	if sim.customers.active_count() + driver_count() >= DataRegistry.bali("queue.max_visible_customer_actors"):
		return
	var lane: QueueLane = sim.queue.driver_lane()
	if lane == null or not sim.queue.reserve(lane, o.driver_id()):
		return
	var a := SimActor.new()
	a.id = o.driver_id()
	a.kind = &"driver"
	a.nav_class = FloorGrid.NAV_PUBLIC
	a.speed_mps = float(DataRegistry.driver_def().get("movement_speed_mps", 1.25))
	a.visual_key = &"driver_rotifood"
	a.visual_seed = sim.rng.stream(&"cosmetic_rng").randi()
	a.place_at(sim.world.store_floor(), sim.world.entrance_cell())
	o.driver = a
	o.driver_phase = &"entering"
	o.driver_entered_at = sim.time.sim_seconds
	o.driver_patience = o.driver_patience_max
	o.driver_stall = 0.0
	if not o.packed:
		o.state = DeliveryOrder.DRIVER_EN_ROUTE
	EventBus.sfx.emit(&"rotifood_driver_arrive", a.floor_id)
	_go_tail(o, lane)


func _go_tail(o: DeliveryOrder, lane: QueueLane) -> void:
	o.driver.go_to(sim.world, lane.floor_id, sim.queue.slot_cell(lane, lane.line.size()))


func _driver_to_queue(o: DeliveryOrder) -> void:
	var lane: QueueLane = sim.queue.lane_of(o.driver_id())
	if lane == null:
		return
	var tail: Vector2i = sim.queue.slot_cell(lane, lane.line.size())
	if o.driver.has_route():
		if o.driver.goal_cell != tail:
			o.driver.go_to(sim.world, lane.floor_id, tail)
		return
	if o.driver.cell() != tail:
		o.driver.go_to(sim.world, lane.floor_id, tail)
		return
	o.driver_last_slot = sim.queue.join_line(lane, o.driver_id())
	o.driver_phase = &"queued"


func _driver_queued(o: DeliveryOrder) -> void:
	var lane: QueueLane = sim.queue.lane_of(o.driver_id())
	if lane == null:
		return
	var i: int = lane.slot_index_of(o.driver_id())
	if i < 0:
		return
	if i != o.driver_last_slot:
		o.driver_last_slot = i
		o.driver_stall = 0.0
		o.driver.go_to(sim.world, lane.floor_id, sim.queue.slot_cell(lane, i))
	if i == 0 and lane.service_occupant == &"" and not o.driver.has_route():
		if sim.queue.advance_to_service(lane, o.driver_id()):
			o.driver_phase = &"at_service"
			o.driver.go_to(sim.world, lane.floor_id, lane.service_point)


func _drain(o: DeliveryOrder, dt: float) -> void:
	o.driver_stall += dt
	var lane: QueueLane = sim.queue.lane_of(o.driver_id())
	var m: float = DataRegistry.balf("patience.drain_base")
	if lane != null and lane.occupancy_ratio() >= DataRegistry.balf("patience.near_full_occupancy_ratio"):
		m *= DataRegistry.balf("patience.near_full_multiplier")
	if o.driver_stall > DataRegistry.balf("patience.stall_seconds"):
		m *= DataRegistry.balf("patience.stall_multiplier")
	m = clampf(m, DataRegistry.balf("patience.drain_clamp_min"), DataRegistry.balf("patience.drain_clamp_max"))
	o.driver_patience = maxf(0.0, o.driver_patience - m * dt)
	o.preparation_deadline = sim.time.sim_seconds + o.driver_patience / m
	if o.driver_patience <= 0.0:
		_fail(o, &"expired", true)


## Handover otomatis (GDD 22.9): rating dari lama tunggu driver, tip bila
## instant, pendapatan di-commit sekali.
func _handover(o: DeliveryOrder) -> void:
	if o.economy_committed:
		return
	o.state = DeliveryOrder.HANDOVER
	var wait: float = sim.time.sim_seconds - o.driver_entered_at
	var ev: Dictionary = DataRegistry.bal("rating.rotifood_events")
	var delta: float = 0.0
	var tip: float = 0.0
	var subtotal: float = o.subtotal()
	if wait < DataRegistry.balf("rotifood.instant_handover_seconds"):
		delta += float(ev["instant_handover"])
		var r: RandomNumberGenerator = sim.rng.stream(&"rotifood_rng")
		if r.randf() < DataRegistry.balf("rotifood.tip_chance"):
			var tr: Array = DataRegistry.bal("rotifood.tip_fraction_range")
			tip = Money.round_half_up(subtotal * r.randf_range(float(tr[0]), float(tr[1])))
	elif wait > DataRegistry.balf("rotifood.long_wait_seconds"):
		delta += float(ev["driver_wait_long"])
	if o.packed_all_prime:
		delta += float(ev["fresh_quality_bonus"])
	o.rating_delta = delta
	sim.reputation.rotifood_event(delta)
	o.economy_committed = true
	sim.economy.credit(subtotal, &"SALE_ROTIFOOD", &"rotifood", {"order": o.order_id})
	if tip > 0.0:
		o.tip_amount = tip
		tips_today += tip
		sim.economy.credit(tip, &"TIP_ROTIFOOD", &"rotifood", {"order": o.order_id})
	var units: int = 0
	for l: Variant in o.packed_lots:
		var st: BreadStack = (l as Dictionary)["stack"]
		var price: float = float((l as Dictionary)["unit_price"])
		units += st.quantity
		sim.analytics.note_sold(st.recipe_id, st.quantity, price * st.quantity, &"rotifood", st.freshness_state == &"STALE")
		sim.pricing.note_sold_at(st.recipe_id, price)
	o.packed_lots.clear()
	sim.statistics.note_rotifood_sale(units, subtotal + tip)
	sim.demand.note_units_delivered(units)
	o.handover_at = sim.time.sim_seconds
	o.state = DeliveryOrder.COMPLETED
	completed_today += 1
	EventBus.sale_completed.emit(subtotal + tip, &"rotifood")
	EventBus.delivery_order_completed.emit(o.order_id)
	EventBus.sfx.emit(&"rotifood_handover", o.driver.floor_id)
	var lane: QueueLane = sim.queue.lane_of(o.driver_id())
	if lane != null:
		EventBus.coin_popup.emit(subtotal + tip, lane.service_point, lane.floor_id)
	_driver_leave(o)
	sim.tutorial.on_event(&"rotifood_handover")
	sim.achievements.on_rotifood_completed()


## Gagal: patience habis (-0.2, GDD 22.8) atau pending admission kedaluwarsa
## (tanpa penalti, GDD 67). Tas yang sudah dikemas kembali ke rak secara atomik.
func _fail(o: DeliveryOrder, reason: StringName, penalize: bool) -> void:
	if o.packed and not o.economy_committed:
		sim.display.return_lots(o.packed_lots)
		o.packed_lots.clear()
		o.packed = false
	o.cancel_reason = reason
	o.state = DeliveryOrder.EXPIRED if penalize else DeliveryOrder.CANCELLED
	cancelled_today += 1
	sim.statistics.add(&"total_rotifood_orders_expired", 1)
	if penalize:
		var ev: Dictionary = DataRegistry.bal("rating.rotifood_events")
		o.rating_delta = float(ev["order_cancelled"])
		sim.reputation.rotifood_event(o.rating_delta)
		EventBus.sfx.emit(&"rotifood_expired", sim.world.store_floor())
	if o.driver != null:
		_driver_leave(o)
	else:
		o.driver_phase = &"gone"


func _driver_leave(o: DeliveryOrder) -> void:
	sim.queue.release(o.driver_id())
	sim.world.release_all_for(o.driver_id())
	o.driver_phase = &"leaving"
	if o.driver != null and not o.driver.go_to(sim.world, sim.world.store_floor(), sim.world.entrance_cell()):
		o.driver = null
		o.driver_phase = &"gone"


func _smart_speed(o: DeliveryOrder, now: float) -> void:
	if o.packed or o.smart_warned or not o.is_active():
		return
	var left: float = INF
	if o.driver_phase == &"none":
		left = o.driver_arrival_time - now
	elif o.driver != null:
		left = o.driver_patience
	if left <= DataRegistry.balf("smart_speed.rotifood_prep_seconds"):
		o.smart_warned = true
		sim.time.smart_slowdown("ui_rotifood_driver_here")


## Pukul 18:00 (GDD 104).
func shutdown() -> void:
	for o: DeliveryOrder in active_orders():
		_fail(o, &"closing", false)
	for k: Variant in orders.keys():
		var o2: DeliveryOrder = orders[k]
		if o2.driver != null:
			sim.queue.release(o2.driver_id())
			sim.world.release_all_for(o2.driver_id())
			o2.driver = null
			o2.driver_phase = &"gone"


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	var list: Array = []
	var ids: Array = orders.keys()
	ids.sort()
	for i: Variant in ids:
		list.append((orders[i] as DeliveryOrder).to_dict())
	return {"next_order_id": next_order_id, "orders": list, "completed_today": completed_today,
		"cancelled_today": cancelled_today, "received_today": received_today, "tips_today": tips_today}


func restore(d: Dictionary) -> void:
	orders.clear()
	next_order_id = int(d.get("next_order_id", 1))
	completed_today = int(d.get("completed_today", 0))
	cancelled_today = int(d.get("cancelled_today", 0))
	received_today = int(d.get("received_today", 0))
	tips_today = float(d.get("tips_today", 0.0))
	for item: Variant in d.get("orders", []):
		var o: DeliveryOrder = DeliveryOrder.from_dict(item as Dictionary)
		if o.driver != null:
			o.driver.id = o.driver_id()
			o.driver.kind = &"driver"
			o.driver.nav_class = FloorGrid.NAV_PUBLIC
			o.driver.speed_mps = float(DataRegistry.driver_def().get("movement_speed_mps", 1.25))
		orders[o.order_id] = o
		next_order_id = maxi(next_order_id, o.order_id + 1)


## Rekonstruksi driver ke slot kanonik setelah load (GDD 77.2).
func reconstruct() -> void:
	for o: DeliveryOrder in active_orders():
		if o.driver == null:
			if o.driver_phase in [&"entering", &"queued", &"at_service"]:
				o.driver_phase = &"pending"
				o.driver_pending_since = sim.time.sim_seconds
			continue
		var lane: QueueLane = sim.queue.lane_of(o.driver_id())
		match o.driver_phase:
			&"queued":
				var i: int = lane.slot_index_of(o.driver_id()) if lane != null else -1
				if i >= 0:
					o.driver_last_slot = i
					o.driver.place_at(lane.floor_id, sim.queue.slot_cell(lane, i))
				else:
					o.driver_phase = &"entering"
					if lane != null:
						_go_tail(o, lane)
			&"at_service":
				if lane != null and lane.service_occupant == o.driver_id():
					o.driver.place_at(lane.floor_id, lane.service_point)
				else:
					_fail(o, &"recovery", false)
			&"entering":
				if lane != null:
					_go_tail(o, lane)
			&"leaving":
				_driver_leave(o)
