class_name CashierManager
extends SimManager
## CashierManager — pemilik transaksi di jalur kasir (GDD idle 6.3; v3.1 21, 98, 103.1).
##
## Semua transaksi otomatis: tidak ada popup pesanan dan tidak ada tombol OK.
## Jalur Asisten Kasir berjalan selama kasirnya di pos; jalur A berjalan selama
## pemilik berdiri di titik kasirnya (PlayerTaskManager memutuskan kapan ia
## melayani). Satu transaksi berlangsung `checkout_seconds` dari level Meja
## Kasir (GDD idle 8.2) dengan animasi membungkus v3.1 21.4, dan ketukan
## Semangat pada kasir mempercepatnya (GDD idle 5.2).

## lane_id -> {customer, elapsed, duration}
var transactions: Dictionary = {}


func new_game() -> void:
	transactions.clear()


## Lama satu transaksi sekarang (detik-simulasi).
func transaction_seconds() -> float:
	return sim.upgrades.checkout_seconds()


## Kemajuan fase membungkus transaksi pada lane, 0..1; -1 bila tidak ada
## transaksi (dipakai tampilan kantong di meja, v3.1 21.4).
func packing_progress(lane_id: StringName) -> float:
	var t: Variant = transactions.get(lane_id)
	if not (t is Dictionary):
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
		if t["customer"] == customer_id:
			return _server_present(sim.queue.lane(StringName(str(k))))
	return false


func transaction_for(lane_id: StringName) -> Dictionary:
	return transactions.get(lane_id, {})


func cancel_for(customer_id: StringName) -> void:
	for k: Variant in transactions.keys():
		if (transactions[k] as Dictionary)["customer"] == customer_id:
			transactions.erase(k)
			return


## Semangat pada kasir (GDD idle 5.2): transaksi yang sedang berjalan di jalur
## itu maju `seconds`. false bila tidak ada transaksi.
func boost_lane(lane_id: StringName, seconds: float) -> bool:
	var t: Variant = transactions.get(lane_id)
	if not (t is Dictionary):
		return false
	var td: Dictionary = t
	td["elapsed"] = minf(float(td["duration"]), float(td["elapsed"]) + seconds)
	return true


## Ada yang melayani jalur itu sekarang: kasirnya di pos dan tidak sedang
## mengemas RotiFood, atau (jalur A) pemilik di titik kasir.
func _server_present(lane: QueueLane) -> bool:
	if lane == null:
		return false
	if lane.main:
		return sim.player.is_manning_lane(lane.id) and sim.rotifood.packer_order(PlayerTaskManager.PLAYER_ID) < 0
	var sid: StringName = sim.staff.cashier_id_for_lane(lane.id)
	return sid != &"" and sim.staff.cashier_at_post(lane.id) and sim.rotifood.packer_order(sid) < 0


func step(dt: float) -> void:
	for lane: QueueLane in sim.queue.lanes:
		var occupant: StringName = lane.service_occupant
		if occupant == &"":
			transactions.erase(lane.id)
			continue
		var c: Customer = sim.customers.customer(occupant)
		if c == null or c.actor.has_route():
			continue
		if not _server_present(lane):
			continue
		var t: Variant = transactions.get(lane.id)
		if t == null or (t as Dictionary)["customer"] != c.id:
			transactions[lane.id] = {"customer": c.id, "elapsed": 0.0, "duration": transaction_seconds()}
			c.state = Customer.BEING_SERVED
			t = transactions[lane.id]
		var td: Dictionary = t
		var before: float = float(td["elapsed"])
		td["elapsed"] = before + dt
		# Suara kantong kertas tepat saat membungkus dimulai (v3.1 21.4, 93).
		if before <= 0.0 and float(td["elapsed"]) > 0.0:
			EventBus.sfx.emit(&"cashier_pack", lane.floor_id)
		if float(td["elapsed"]) >= float(td["duration"]):
			transactions.erase(lane.id)
			_complete(c, lane)


## Commit penjualan fisik (v3.1 103.1): harga dikunci saat roti diambil dari rak.
func _complete(c: Customer, lane: QueueLane) -> void:
	var subtotal: float = 0.0
	var units: int = 0
	for lot: Variant in c.held:
		var st: BreadStack = (lot as Dictionary)["stack"]
		subtotal += Money.round_half_up(float((lot as Dictionary)["unit_price"])) * st.quantity
		units += st.quantity
	c.held.clear()
	if units <= 0:
		sim.customers.on_paid(c)
		return
	sim.economy.credit(subtotal, &"SALE_PHYSICAL", c.archetype, {"customer": String(c.id), "units": units})
	sim.statistics.note_physical_sale(units, subtotal)
	sim.reputation.on_served()
	EventBus.sale_completed.emit(subtotal, &"physical")
	EventBus.sfx.emit(&"cashier_coin", lane.floor_id)
	EventBus.sfx.emit(&"sale_success", lane.floor_id)
	EventBus.coin_popup.emit(subtotal, lane.service_point, lane.floor_id)
	sim.customers.on_paid(c)


func capture() -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in transactions.keys():
		var t: Dictionary = transactions[k]
		out[str(k)] = {"customer": String(t["customer"]), "elapsed": t["elapsed"], "duration": t["duration"]}
	return out


func restore(d: Dictionary) -> void:
	transactions.clear()
	for k: Variant in d.keys():
		var t: Dictionary = d[k]
		transactions[StringName(str(k))] = {"customer": StringName(str(t["customer"])), "elapsed": float(t["elapsed"]),
			"duration": float(t["duration"])}
