class_name RotiFoodManager
extends SimManager
## RotiFoodManager — pemilik pesanan RotiFood dan driver-nya (GDD idle 6.5;
## v3.1 22, 98, 103.2).
##
## Pesanan diterima otomatis. Roti dipesan dari rak saat pesanan datang bila
## tersedia, selain itu pesanan menunggu stok. Pesanan yang rotinya sudah
## dipesan dikemas otomatis oleh pemilik (PlayerTaskManager) atau Asisten Kasir
## yang jalurnya sepi. Driver datang setelah jendela persiapan dan menunggu di
## titik layan dengan kesabaran v3.1 22.6; bila pesanan sudah dikemas,
## penyerahan terjadi otomatis dan pendapatan di-commit tepat sekali. Bila
## kesabarannya habis, pesanan batal tanpa denda selain reputasi. Tidak ada
## tolak pesanan dan tidak ada tip.

var orders: Dictionary = {}
var next_order_id: int = 1
## Dinaikkan setiap kali isi `orders` berubah; cache di bawah mengikutinya.
var _orders_version: int = 0
var _ids_cache: Array = []
var _ids_version: int = -1
var _active_cache: Array[DeliveryOrder] = []
var _active_version: int = -1
var _leaving_cache: Array[DeliveryOrder] = []
var _leaving_version: int = -1
var _leaving_dirty: bool = true
var _approach_cache: Dictionary = {}
var _approach_loc: StringName = &""


func new_game() -> void:
	orders.clear()
	_orders_version += 1
	next_order_id = 1


func order(order_id: int) -> DeliveryOrder:
	return orders.get(order_id)


## Pesanan aktif terurut ID, read-only. Disusun ulang dari semua pesanan hanya
## bila `orders` berubah, selain itu hanya disaring (v3.1 109).
func active_orders() -> Array[DeliveryOrder]:
	if _active_version != _orders_version:
		var out: Array[DeliveryOrder] = []
		for i: Variant in _order_ids():
			var o: DeliveryOrder = orders[i]
			if o.is_active():
				out.append(o)
		_set_active(out)
		_active_version = _orders_version
	else:
		for o2: DeliveryOrder in _active_cache:
			if not o2.is_active():
				var kept: Array[DeliveryOrder] = []
				for o3: DeliveryOrder in _active_cache:
					if o3.is_active():
						kept.append(o3)
				_set_active(kept)
				break
	return _active_cache


func _set_active(list: Array[DeliveryOrder]) -> void:
	list.make_read_only()
	_active_cache = list


func _order_ids() -> Array:
	if _ids_version != _orders_version:
		_ids_cache = orders.keys()
		_ids_cache.sort()
		_ids_version = _orders_version
	return _ids_cache


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
# PEMBUATAN ORDER (GDD idle 6.5; v3.1 22.9)
# ===========================================================================

## Pesanan baru. Menu = resep yang sedang dijual petak-petak rak; tanpa menu,
## permintaan itu terlewat tanpa penalti.
func create_random_order() -> DeliveryOrder:
	var menu: Array = sim.menu_recipes()
	if menu.is_empty():
		return null
	var r: RandomNumberGenerator = sim.rng.stream(&"rotifood_rng")
	var dist: Dictionary = {}
	for pair: Variant in DataRegistry.bal("rotifood.units_distribution"):
		dist[int((pair as Array)[0])] = float((pair as Array)[1])
	var units: int = int(RNGManager.weighted_pick(r, dist))
	var kinds: int = 1
	if menu.size() > 1 and r.randf() < DataRegistry.balf("rotifood.two_recipe_chance"):
		kinds = 2
	var generic: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_generic")
	var picks: Array = []
	var pool: Array = menu.duplicate()
	for k in kinds:
		var pid: StringName = CustomerManager.pick_recipe(generic, pool, r)
		picks.append(pid)
		pool.erase(pid)
	var items: Dictionary = {}
	for i in picks.size():
		var share: int = units / picks.size() + (1 if i < units % picks.size() else 0)
		if share > 0:
			items[StringName(str(picks[i]))] = share
	var pw: Array = DataRegistry.bal("rotifood.prep_window_seconds")
	return _create(items, r.randf_range(float(pw[0]), float(pw[1])))


## Pesanan dengan isi tertentu (panel debug dan test).
func debug_create_order(items: Dictionary, prep_window: float = 90.0) -> DeliveryOrder:
	return _create(items, prep_window)


func _create(items: Dictionary, prep_window: float) -> DeliveryOrder:
	var o := DeliveryOrder.new()
	o.order_id = next_order_id
	next_order_id += 1
	o.items = items
	o.created_at = sim.time.sim_seconds
	o.prep_window = prep_window
	o.driver_arrival_time = o.created_at + o.prep_window
	o.driver_patience_max = float(DataRegistry.driver_def().get("base_patience_seconds", 30.0)) * sim.upgrades.patience_mult()
	o.driver_patience = o.driver_patience_max
	o.state = DeliveryOrder.WAITING_FOR_STOCK
	orders[o.order_id] = o
	_orders_version += 1
	sim.statistics.add(&"total_rotifood_orders_received", 1)
	EventBus.delivery_order_created.emit(o.order_id)
	EventBus.sfx.emit(&"rotifood_incoming", sim.world.store_floor())
	_try_reserve(o)
	return o


## Ambil semua roti pesanan dari rak sekaligus, atau tidak sama sekali.
## Harga per unit = harga jual × `rotifood.price_mult` (GDD idle 6.5).
func _try_reserve(o: DeliveryOrder) -> bool:
	if o.is_reserved() or not o.is_active():
		return o.is_reserved()
	var stock: Dictionary = sim.display.sellable_by_recipe()
	for rid: Variant in o.items.keys():
		if int(stock.get(rid, 0)) < int(o.items[rid]):
			return false
	var all_lots: Array = []
	var mult: float = DataRegistry.idlef("rotifood.price_mult")
	for rid2: Variant in Ids.sort(o.items.keys()):
		var lots: Array[Dictionary] = sim.display.take(rid2, int(o.items[rid2]), -1, 0.0, false)
		if lots.is_empty():
			sim.display.return_lots(all_lots)
			return false
		for l: Dictionary in lots:
			l["unit_price"] = sim.unit_price(StringName(str(rid2)), int(l["display_id"])) * mult
		all_lots.append_array(lots)
	o.reserved_lots = all_lots
	o.state = DeliveryOrder.TO_PACK
	return true


# ===========================================================================
# MENGEMAS (GDD idle 6.5)
# ===========================================================================

## Lama mengemas satu pesanan: sama dengan satu transaksi kasir (GDD idle 8.2).
func pack_seconds() -> float:
	return sim.upgrades.checkout_seconds()


## Pesanan pertama yang rotinya sudah dipesan dan belum dikemas siapa pun.
func next_order_to_pack(worker: StringName) -> int:
	for o: DeliveryOrder in active_orders():
		if o.state == DeliveryOrder.TO_PACK and (o.packer_id == &"" or o.packer_id == worker):
			return o.order_id
	return -1


func claim_pack(order_id: int, worker: StringName) -> bool:
	var o: DeliveryOrder = order(order_id)
	if o == null or o.state != DeliveryOrder.TO_PACK or (o.packer_id != &"" and o.packer_id != worker):
		return false
	o.packer_id = worker
	o.state = DeliveryOrder.PACKING
	o.pack_elapsed = 0.0
	return true


func release_pack(order_id: int, worker: StringName) -> void:
	var o: DeliveryOrder = order(order_id)
	if o != null and o.packer_id == worker and not o.packed:
		o.packer_id = &""
		o.state = DeliveryOrder.TO_PACK if o.is_reserved() else DeliveryOrder.WAITING_FOR_STOCK


## Lepas semua pesanan yang sedang dikemas `worker`.
func release_packer(worker: StringName) -> void:
	for o: DeliveryOrder in active_orders():
		if o.packer_id == worker:
			release_pack(o.order_id, worker)


## Pesanan yang sedang dikemas `worker`, atau -1.
func packer_order(worker: StringName) -> int:
	for o: DeliveryOrder in active_orders():
		if o.packer_id == worker and o.state == DeliveryOrder.PACKING:
			return o.order_id
	return -1


## Pengemasan selesai: tas siap diserahkan ke driver.
func finish_pack(order_id: int, worker: StringName) -> bool:
	var o: DeliveryOrder = order(order_id)
	if o == null or o.packer_id != worker or o.state != DeliveryOrder.PACKING:
		return false
	o.packed = true
	o.packer_id = &""
	o.state = DeliveryOrder.PACKED
	EventBus.sfx.emit(&"rotifood_pack_done", sim.world.store_floor())
	return true


## Asisten Kasir yang jalurnya sepi mengemas di mejanya.
func _cashier_packing(dt: float) -> void:
	for o: DeliveryOrder in active_orders():
		if o.state != DeliveryOrder.PACKING or o.packer_id == PlayerTaskManager.PLAYER_ID:
			continue
		o.pack_elapsed += dt
		if o.pack_elapsed >= pack_seconds():
			finish_pack(o.order_id, o.packer_id)
	for lane: QueueLane in sim.staff.idle_cashier_lanes():
		var sid: StringName = sim.staff.cashier_id_for_lane(lane.id)
		if packer_order(sid) >= 0:
			continue
		var oid: int = next_order_to_pack(sid)
		if oid < 0:
			return
		claim_pack(oid, sid)


# ===========================================================================
# DRIVER (v3.1 22.6, 58, 67)
# ===========================================================================

func step(dt: float) -> void:
	var now: float = sim.time.sim_seconds
	for o0: DeliveryOrder in active_orders():
		if o0.state == DeliveryOrder.WAITING_FOR_STOCK:
			_try_reserve(o0)
	_cashier_packing(dt)
	for o: DeliveryOrder in active_orders():
		match o.driver_phase:
			&"none":
				if now >= o.driver_arrival_time - approach_seconds(o):
					o.driver_phase = &"pending"
					o.driver_pending_since = now
			&"pending":
				if now - o.driver_pending_since > DataRegistry.balf("queue.rotifood_max_pending_seconds"):
					o.driver_pending_since = now
				_try_admit_driver(o)
			&"approaching":
				o.driver.step(dt, sim.world)
				if not o.driver.has_route():
					_driver_enter(o)
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
					_drain(o, dt)
	for o2: DeliveryOrder in _leaving():
		o2.driver.step(dt, sim.world)
		if not o2.driver.has_route():
			sim.world.release_all_for(o2.driver_id())
			o2.driver = null
			o2.driver_phase = &"gone"


func _leaving() -> Array[DeliveryOrder]:
	if _leaving_dirty or _leaving_version != _orders_version:
		var out: Array[DeliveryOrder] = []
		for i: Variant in _order_ids():
			var o: DeliveryOrder = orders[i]
			if o.driver_phase == &"leaving" and o.driver != null:
				out.append(o)
		out.make_read_only()
		_leaving_cache = out
		_leaving_dirty = false
		_leaving_version = _orders_version
		return _leaving_cache
	for o2: DeliveryOrder in _leaving_cache:
		if o2.driver_phase != &"leaving" or o2.driver == null:
			var kept: Array[DeliveryOrder] = []
			for o3: DeliveryOrder in _leaving_cache:
				if o3.driver_phase == &"leaving" and o3.driver != null:
					kept.append(o3)
			kept.make_read_only()
			_leaving_cache = kept
			break
	return _leaving_cache


func _try_admit_driver(o: DeliveryOrder) -> void:
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
	# Datang dari ujung trotoar (v3.1 20.1, 22.6); kesabarannya baru berkurang di toko.
	a.walk_path(sim.world.store_floor(), StreetPaths.approach(sim.world.location, _side(o)))
	o.driver = a
	o.driver_phase = &"approaching"
	o.driver_patience = o.driver_patience_max
	o.driver_stall = 0.0


func _driver_enter(o: DeliveryOrder) -> void:
	o.driver.place_at(sim.world.store_floor(), sim.world.entrance_cell())
	o.driver_phase = &"entering"
	o.driver_entered_at = sim.time.sim_seconds
	EventBus.sfx.emit(&"rotifood_driver_arrive", o.driver.floor_id)
	var lane: QueueLane = sim.queue.lane_of(o.driver_id())
	if lane != null:
		_go_tail(o, lane)


func _side(o: DeliveryOrder) -> int:
	return 1 if o.order_id % 2 == 0 else -1


## Lama driver berjalan dari ujung trotoar ke pintu (detik-simulasi). Ia berangkat
## selama itu sebelum `driver_arrival_time`, jadi tiba di pintu tepat waktu.
func approach_seconds(o: DeliveryOrder) -> float:
	if _approach_loc != sim.world.location.id:
		_approach_cache.clear()
		_approach_loc = sim.world.location.id
	var side: int = _side(o)
	if not _approach_cache.has(side):
		_approach_cache[side] = StreetPaths.approach_seconds(sim.world.location, side,
			float(DataRegistry.driver_def().get("movement_speed_mps", 1.25)))
	return _approach_cache[side]


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
	var pt: PackedFloat64Array = DataRegistry.patience_tuning()
	var m: float = pt[0]
	if lane != null and lane.occupancy_ratio() >= pt[1]:
		m *= pt[2]
	if o.driver_stall > pt[3]:
		m *= pt[4]
	m = clampf(m, pt[5], pt[6])
	o.driver_patience = maxf(0.0, o.driver_patience - m * dt)
	if o.driver_patience <= 0.0:
		_fail(o, &"expired")


## Penyerahan otomatis: pendapatan di-commit sekali, reputasi naik.
func _handover(o: DeliveryOrder) -> void:
	if o.economy_committed:
		return
	var subtotal: float = o.subtotal()
	var units: int = 0
	for l: Variant in o.reserved_lots:
		units += ((l as Dictionary)["stack"] as BreadStack).quantity
	o.economy_committed = true
	sim.economy.credit(subtotal, &"SALE_ROTIFOOD", &"rotifood", {"order": o.order_id})
	sim.reputation.on_served()
	sim.statistics.note_rotifood_sale(units, subtotal)
	o.reserved_lots.clear()
	o.handover_at = sim.time.sim_seconds
	o.state = DeliveryOrder.COMPLETED
	EventBus.sale_completed.emit(subtotal, &"rotifood")
	EventBus.delivery_order_completed.emit(o.order_id)
	EventBus.sfx.emit(&"rotifood_handover", o.driver.floor_id)
	var lane: QueueLane = sim.queue.lane_of(o.driver_id())
	if lane != null:
		EventBus.coin_popup.emit(subtotal, lane.service_point, lane.floor_id)
	_driver_leave(o)


## Kesabaran driver habis: pesanan batal, roti yang dipesan kembali ke rak, dan
## reputasi turun (GDD idle 6.5, 6.6).
func _fail(o: DeliveryOrder, reason: StringName) -> void:
	if not o.economy_committed:
		sim.display.return_lots(o.reserved_lots)
		o.reserved_lots.clear()
		o.packed = false
	o.packer_id = &""
	o.cancel_reason = reason
	o.state = DeliveryOrder.CANCELLED
	sim.statistics.add(&"total_rotifood_orders_expired", 1)
	sim.reputation.on_lost()
	EventBus.sfx.emit(&"rotifood_expired", sim.world.store_floor())
	if o.driver != null:
		_driver_leave(o)
	else:
		o.driver_phase = &"gone"


func _driver_leave(o: DeliveryOrder) -> void:
	sim.queue.release(o.driver_id())
	sim.world.release_all_for(o.driver_id())
	o.driver_phase = &"leaving"
	_leaving_dirty = true
	if o.driver != null and o.driver.outside:
		o.driver.walk_path(sim.world.store_floor(), StreetPaths.retreat(sim.world.location, _side(o), o.driver.pos))
	elif o.driver != null and not o.driver.go_to(sim.world, sim.world.store_floor(), sim.world.entrance_cell()):
		o.driver = null
		o.driver_phase = &"gone"


## Driver keluar dari dunia (upgrade lokasi): pesanan tetap ada dan driver
## datang lagi dari ujung trotoar.
func send_drivers_away() -> void:
	for o: DeliveryOrder in active_orders():
		if o.driver != null:
			sim.queue.release(o.driver_id())
			sim.world.release_all_for(o.driver_id())
			o.driver = null
			o.driver_phase = &"pending"
			o.driver_pending_since = sim.time.sim_seconds
		if o.packer_id != &"" and not o.packed:
			release_pack(o.order_id, o.packer_id)
	for k: Variant in orders.keys():
		var o2: DeliveryOrder = orders[k]
		if not o2.is_active() and o2.driver != null:
			sim.world.release_all_for(o2.driver_id())
			o2.driver = null
			o2.driver_phase = &"gone"


## Pesanan yang selesai atau batal dibuang supaya daftar tidak tumbuh tanpa batas.
func prune() -> void:
	var removed: bool = false
	for k: Variant in orders.keys():
		var o: DeliveryOrder = orders[k]
		if not o.is_active() and o.driver == null:
			orders.erase(k)
			removed = true
	if removed:
		_orders_version += 1


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	var list: Array = []
	var ids: Array = orders.keys()
	ids.sort()
	for i: Variant in ids:
		list.append((orders[i] as DeliveryOrder).to_dict())
	return {"next_order_id": next_order_id, "orders": list}


func restore(d: Dictionary) -> void:
	orders.clear()
	_orders_version += 1
	next_order_id = int(d.get("next_order_id", 1))
	for item: Variant in d.get("orders", []):
		var o: DeliveryOrder = DeliveryOrder.from_dict(item as Dictionary)
		if o.driver != null:
			o.driver.id = o.driver_id()
			o.driver.kind = &"driver"
			o.driver.nav_class = FloorGrid.NAV_PUBLIC
			o.driver.speed_mps = float(DataRegistry.driver_def().get("movement_speed_mps", 1.25))
		orders[o.order_id] = o
		_orders_version += 1
		next_order_id = maxi(next_order_id, o.order_id + 1)


## Rekonstruksi driver ke slot kanonik setelah load (v3.1 77.2). Pengemasan yang
## terputus dimulai ulang.
func reconstruct() -> void:
	for o: DeliveryOrder in active_orders():
		if o.state == DeliveryOrder.PACKING:
			o.packer_id = &""
			o.pack_elapsed = 0.0
			o.state = DeliveryOrder.TO_PACK if o.is_reserved() else DeliveryOrder.WAITING_FOR_STOCK
		if o.driver == null:
			if o.driver_phase in [&"approaching", &"entering", &"queued", &"at_service"]:
				o.driver_phase = &"pending"
				o.driver_pending_since = sim.time.sim_seconds
			continue
		var lane: QueueLane = sim.queue.lane_of(o.driver_id())
		match o.driver_phase:
			&"approaching":
				o.driver.walk_path(sim.world.store_floor(), StreetPaths.approach(sim.world.location, _side(o)))
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
					o.driver = null
					o.driver_phase = &"pending"
					o.driver_pending_since = sim.time.sim_seconds
			&"entering":
				if lane != null:
					_go_tail(o, lane)
			&"leaving":
				_driver_leave(o)
