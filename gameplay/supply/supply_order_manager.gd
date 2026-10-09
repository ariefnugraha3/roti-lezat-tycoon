class_name SupplyOrderManager
extends SimManager
## SupplyOrderManager — pemilik purchase order bahan & kurir suplai (GDD 5.2.3,
## 24A, 55.5-55.9, 70, 98, 103.3).
##
## Inventory hanya berubah pada satu titik: paket menyentuh meja kasir
## (INVENTORY_COMMITTED). Flag `inventory_committed` per order mencegah
## double-commit lintas save/load (GDD 24A.3, 77.3).

const CREATED: StringName = &"CREATED"
const PAID: StringName = &"PAID"
const IN_TRANSIT: StringName = &"IN_TRANSIT"
const COURIER_SPAWNING: StringName = &"COURIER_SPAWNING"
## Berjalan dari ujung trotoar ke pintu (GDD 20.1, 24A).
const COURIER_APPROACHING: StringName = &"COURIER_APPROACHING"
const COURIER_ENTERING: StringName = &"COURIER_ENTERING"
const DROPPING_PACKAGE: StringName = &"DROPPING_PACKAGE"
const INVENTORY_COMMITTED: StringName = &"INVENTORY_COMMITTED"
const COURIER_EXITING: StringName = &"COURIER_EXITING"
const COMPLETED: StringName = &"COMPLETED"

var market_unlocked: bool = false
var orders: Array[Dictionary] = []
var next_order_id: int = 1
## order_id yang sudah jatuh tempo dan menunggu giliran drop-off (FIFO).
var delivery_fifo: Array[int] = []
## order_id -> SimActor kurir.
var couriers: Dictionary = {}
var _drop_timer: Dictionary = {}


func new_game() -> void:
	market_unlocked = false
	orders.clear()
	next_order_id = 1
	delivery_fifo.clear()
	couriers.clear()
	_drop_timer.clear()


func order_by_id(order_id: int) -> Dictionary:
	for o: Dictionary in orders:
		if int(o["order_id"]) == order_id:
			return o
	return {}


## Unit bahan yang masih di perjalanan (GDD 5.2.2, 55.9).
func in_transit_units() -> int:
	var n: int = 0
	for o: Dictionary in orders:
		if not bool(o["inventory_committed"]):
			for k: Variant in (o["items"] as Dictionary).keys():
				n += int(o["items"][k])
	return n


func in_transit_of(ingredient_id: StringName) -> int:
	var n: int = 0
	for o: Dictionary in orders:
		if not bool(o["inventory_committed"]):
			n += int((o["items"] as Dictionary).get(String(ingredient_id), 0))
	return n


## ETA terdekat (jam in-game) untuk bahan ini, -1 bila tidak ada.
func next_eta_of(ingredient_id: StringName) -> float:
	var best: float = -1.0
	for o: Dictionary in orders:
		if not bool(o["inventory_committed"]) and int((o["items"] as Dictionary).get(String(ingredient_id), 0)) > 0:
			var eta: float = float(o["arrival_game_time"])
			if best < 0.0 or eta < best:
				best = eta
	return best


## Batas beli: stok + in_transit + pesanan baru <= kapasitas Gudang (GDD 55.9).
func max_additional_units() -> int:
	return maxi(0, sim.inventory.capacity() - sim.inventory.total_units() - in_transit_units())


func can_open_market() -> bool:
	return market_unlocked


## Beli bahan (GDD 103.3). items: ingredient_id(String/StringName) -> jumlah.
## {ok, reason, order_id, instant}.
func purchase(items: Dictionary) -> Dictionary:
	if not market_unlocked:
		return {"ok": false, "reason": "locked"}
	var clean: Dictionary = {}
	var units: int = 0
	var cost: float = 0.0
	for k: Variant in items.keys():
		var q: int = int(items[k])
		if q <= 0:
			continue
		var def: IngredientDefinition = DataRegistry.ingredient(StringName(str(k)))
		if def == null:
			return {"ok": false, "reason": "invalid"}
		clean[String(def.id)] = q
		units += q * def.storage_units_per_purchase
		cost += def.fixed_buy_price_kr * q
	if clean.is_empty():
		return {"ok": false, "reason": "empty"}
	# 1. Kapasitas termasuk in_transit. 2. KR.
	if units > max_additional_units():
		return {"ok": false, "reason": "capacity"}
	if not sim.economy.can_afford(cost):
		return {"ok": false, "reason": "kr"}
	# 3. Potong KR dan buat line item immutable secara atomik.
	var instant: bool = not sim.time.is_running_phase()
	sim.economy.spend(cost, &"INGREDIENT_PURCHASE", &"market", {"items": clean, "instant": instant})
	var o: Dictionary = {
		"order_id": next_order_id, "items": clean, "total_cost": cost, "created_day": sim.time.day,
		"created_game_time": sim.time.time_seconds,
		"arrival_game_time": sim.time.time_seconds + DataRegistry.balf("supply.lead_time_ingame_hours") * 3600.0,
		"state": String(PAID), "inventory_committed": false, "instant_after_hours": instant,
	}
	next_order_id += 1
	orders.append(o)
	sim.statistics.add(&"total_supply_orders", 1)
	EventBus.sfx.emit(&"supply_order_placed", sim.world.store_floor())
	if instant:
		# Setelah tutup: langsung masuk Gudang, tanpa kurir (GDD 5.2.3.E).
		_commit(o)
		o["state"] = String(COMPLETED)
		# Order yang sudah selesai dibersihkan segera, supaya save sama persis
		# dengan state setelah load (GDD 77).
		_prune()
	else:
		o["state"] = String(IN_TRANSIT)
	SaveManager.request_autosave("market_purchase")
	return {"ok": true, "reason": "", "order_id": o["order_id"], "instant": instant}


func _commit(o: Dictionary) -> void:
	if bool(o["inventory_committed"]):
		return
	o["inventory_committed"] = true
	sim.inventory.add_items(o["items"])
	o["state"] = String(INVENTORY_COMMITTED)
	EventBus.supply_delivered.emit(int(o["order_id"]))
	EventBus.sfx.emit(&"supply_committed", sim.world.store_floor())
	EventBus.notify.emit(2, "ui_ingredients_delivered", {}, &"box")


# ===========================================================================
# KURIR (GDD 5.2.3.C-D, 70)
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	var now: float = sim.time.time_seconds
	for o: Dictionary in orders:
		# Kurir berangkat dari ujung trotoar selama perjalanannya sebelum ETA, jadi
		# tiba di pintu tepat pada jam yang tertulis di Pasar.
		if str(o["state"]) == String(IN_TRANSIT) and now >= float(o["arrival_game_time"]) - approach_game_seconds(int(o["order_id"])):
			o["state"] = String(COURIER_SPAWNING)
			delivery_fifo.append(int(o["order_id"]))
	_spawn_next()
	var keys: Array = couriers.keys()
	keys.sort()
	for k: Variant in keys:
		var oid: int = int(k)
		var a: SimActor = couriers[oid]
		var o2: Dictionary = order_by_id(oid)
		a.step(dt, sim.world)
		match StringName(str(o2["state"])):
			COURIER_APPROACHING:
				if not a.has_route():
					_courier_enter(oid, a)
			COURIER_ENTERING:
				if not a.has_route():
					o2["state"] = String(DROPPING_PACKAGE)
					_drop_timer[oid] = DataRegistry.balf("supply.dropoff_seconds")
			DROPPING_PACKAGE:
				_drop_timer[oid] = float(_drop_timer.get(oid, 0.0)) - dt
				if float(_drop_timer[oid]) <= 0.0:
					# Commit tepat saat paket menyentuh meja.
					EventBus.sfx.emit(&"supply_package_drop", a.floor_id)
					_commit(o2)
					o2["state"] = String(COURIER_EXITING)
					var f: FloorDefinition = sim.world.location.floor_def(sim.world.store_floor())
					sim.world.release_point(sim.world.store_floor(), f.supply_dropoff, a.id)
					a.go_to(sim.world, sim.world.store_floor(), sim.world.entrance_cell())
			COURIER_EXITING:
				if not a.has_route():
					o2["state"] = String(COMPLETED)
					couriers.erase(oid)
					_drop_timer.erase(oid)
	_prune()


## Hanya satu kurir memakai staging point; order lain menunggu FIFO (GDD 55.7).
func _spawn_next() -> void:
	if delivery_fifo.is_empty():
		return
	if couriers.size() >= DataRegistry.bali("supply.max_courier_actors"):
		return
	var f: FloorDefinition = sim.world.location.floor_def(sim.world.store_floor())
	var oid: int = delivery_fifo[0]
	var cid: StringName = StringName("k%d" % oid)
	if not sim.world.reserve_point(sim.world.store_floor(), f.supply_dropoff, cid):
		return
	delivery_fifo.pop_front()
	var a := SimActor.new()
	a.id = cid
	a.kind = &"courier"
	a.nav_class = FloorGrid.NAV_PUBLIC
	a.speed_mps = float(DataRegistry.courier_def().get("movement_speed_mps", 1.4))
	a.visual_key = &"courier_supply"
	a.visual_seed = sim.rng.stream(&"cosmetic_rng").randi()
	a.walk_path(sim.world.store_floor(), StreetPaths.approach(sim.world.location, _side(oid)))
	couriers[oid] = a
	var o: Dictionary = order_by_id(oid)
	o["state"] = String(COURIER_APPROACHING)


## Sisi trotoar kurir: bergantian menurut nomor order, tanpa RNG.
func _side(oid: int) -> int:
	return -1 if oid % 2 == 0 else 1


## Lama kurir berjalan dari ujung trotoar ke pintu, dalam detik jam in-game.
func approach_game_seconds(oid: int) -> float:
	var speed: float = float(DataRegistry.courier_def().get("movement_speed_mps", 1.4))
	return StreetPaths.approach_seconds(sim.world.location, _side(oid), speed) * sim.time.ratio


## Kurir tiba di pintu lalu masuk menuju titik antar barang.
func _courier_enter(oid: int, a: SimActor) -> void:
	var f: FloorDefinition = sim.world.location.floor_def(sim.world.store_floor())
	var o: Dictionary = order_by_id(oid)
	a.place_at(sim.world.store_floor(), sim.world.entrance_cell())
	o["state"] = String(COURIER_ENTERING)
	EventBus.sfx.emit(&"supply_courier_arrive", a.floor_id)
	if not a.go_to(sim.world, sim.world.store_floor(), f.supply_dropoff):
		# Jalan terhalang: commit tetap dijamin, kurir dibatalkan aman (GDD 70).
		_commit(o)
		o["state"] = String(COMPLETED)
		couriers.erase(oid)
		sim.world.release_point(sim.world.store_floor(), f.supply_dropoff, a.id)


func _prune() -> void:
	for i in range(orders.size() - 1, -1, -1):
		var o: Dictionary = orders[i]
		if str(o["state"]) == String(COMPLETED) and bool(o["inventory_committed"]):
			orders.remove_at(i)


## 18:00: semua order yang belum commit diselesaikan otomatis, kurir di-despawn
## (GDD 70, 104).
func shutdown() -> void:
	for o: Dictionary in orders:
		if not bool(o["inventory_committed"]):
			_commit(o)
		o["state"] = String(COMPLETED)
	for k: Variant in couriers.keys():
		sim.world.release_all_for((couriers[k] as SimActor).id)
	couriers.clear()
	delivery_fifo.clear()
	_drop_timer.clear()
	_prune()


## Settlement Hari 3 membuka Pasar (GDD 24A.1).
func unlock_market() -> void:
	market_unlocked = true


func capture() -> Dictionary:
	var list: Array = []
	for o: Dictionary in orders:
		list.append(o.duplicate(true))
	var cour: Dictionary = {}
	for k: Variant in couriers.keys():
		cour[str(k)] = (couriers[k] as SimActor).to_dict()
	return {"market_unlocked": market_unlocked, "next_order_id": next_order_id, "orders": list,
		"delivery_fifo": delivery_fifo.duplicate(), "couriers": cour}


func restore(d: Dictionary) -> void:
	new_game()
	market_unlocked = bool(d.get("market_unlocked", false))
	next_order_id = int(d.get("next_order_id", 1))
	for o: Variant in d.get("orders", []):
		orders.append((o as Dictionary).duplicate(true))
	for f: Variant in d.get("delivery_fifo", []):
		delivery_fifo.append(int(f))


## Pada load: order yang ETA-nya sudah lewat tetapi belum commit dimasukkan ke
## FIFO; order yang sudah commit tidak pernah menambah stok lagi (GDD 24A.4).
## Kurir visual direspawn dari awal antrean.
func reconstruct() -> void:
	couriers.clear()
	var fifo: Array[int] = []
	for o: Dictionary in orders:
		if bool(o["inventory_committed"]):
			o["state"] = String(COMPLETED)
			continue
		var st: StringName = StringName(str(o["state"]))
		if st in [COURIER_SPAWNING, COURIER_APPROACHING, COURIER_ENTERING, DROPPING_PACKAGE, COURIER_EXITING]:
			o["state"] = String(COURIER_SPAWNING)
			fifo.append(int(o["order_id"]))
	for oid: int in delivery_fifo:
		if not fifo.has(oid) and not bool(order_by_id(oid).get("inventory_committed", true)):
			fifo.append(oid)
	delivery_fifo = fifo
	_prune()
