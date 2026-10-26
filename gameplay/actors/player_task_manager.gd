class_name PlayerTaskManager
extends SimManager
## PlayerTaskManager — pemilik toko (karakter pemain) sebagai pekerja otomatis
## serba bisa (GDD idle 5.1, 5.2). Pemain tidak perlu menyuruhnya: setiap kali
## menganggur ia memilih (1) melayani jalur A bila ada pembeli menunggu di sana
## dan tidak ada jalur kasir lain yang buka dengan ruang, (2) pekerjaan dapur
## (KitchenBrain, GDD idle 4.3), (3) mengemas pesanan RotiFood, atau (4) diam.
##
## Ketukan pemain pada stasiun (GDD idle 5.1, 5.2) menjadikan stasiun itu
## prioritas pertama pemilik selama `owner.focus_seconds`, dan mengetuk mixer,
## oven, atau kasir yang sedang bekerja menambah progresnya (Semangat).

const PLAYER_ID: StringName = &"player"
## Jeda evaluasi ulang saat tidak ada pekerjaan (detik-simulasi).
const RETHINK_SECONDS: float = 0.25

var actor: SimActor = null
## {gender: "male"/"female"} — murni kosmetik (v3.1 31.3).
var appearance: Dictionary = {"gender": "male"}
## Tugas sekarang: tugas dapur KitchenBrain, {type: "serve"}, atau
## {type: "pack", order_id}.
var task: Dictionary = {}
## Jalur yang sedang dilayani pemilik (&"" = tidak di kasir).
var manning_lane: StringName = &""
## Ketukan arahan (GDD idle 5.1): stasiun prioritas dan batas waktunya.
var focus_iid: int = -1
var focus_cashier: bool = false
var focus_until: float = -1.0
var _rethink_at: float = 0.0
## Transien (tidak disimpan): ketukan Semangat terakhir per stasiun (iid) atau
## jalur ("lane:<id>"), ms nyata.
var _last_boost_ms: Dictionary = {}


func new_game() -> void:
	task = {}
	manning_lane = &""
	focus_iid = -1
	focus_cashier = false
	focus_until = -1.0
	_rethink_at = 0.0
	_last_boost_ms.clear()
	_make_actor()


func _make_actor() -> void:
	actor = SimActor.new()
	actor.id = PLAYER_ID
	actor.kind = &"player"
	actor.nav_class = FloorGrid.NAV_STAFF
	actor.speed_mps = DataRegistry.player_speed_mps()
	actor.visual_key = &"player"


## Posisi awal: di depan Gudang (dapur).
func place_at_start() -> void:
	manning_lane = &""
	task = {}
	var storage: EquipmentInstance = sim.equipment.storage_instance()
	var acc: Dictionary = sim.world.access_of(storage.iid) if storage != null else {}
	if not acc.is_empty():
		actor.place_at(acc["floor"], acc["cell"])
	else:
		var lane: QueueLane = sim.queue.main_lane()
		actor.place_at(lane.floor_id, lane.cashier_point)


func carried_job() -> ProductionJob:
	if actor.carried.is_empty():
		return null
	return sim.production.get_job(int(actor.carried.get("job_id", -1)))


## Pemilik benar-benar berdiri di titik kasir jalur itu dan melayaninya.
func is_manning_lane(lane_id: StringName) -> bool:
	if manning_lane != lane_id or actor.has_route():
		return false
	var lane: QueueLane = sim.queue.lane(lane_id)
	return lane != null and actor.floor_id == lane.floor_id and actor.cell() == lane.cashier_point


func focus_active() -> bool:
	return focus_until > sim.time.sim_seconds


## Ringkasan untuk tampilan: &"serving", &"kitchen", &"packing", &"idle".
func activity() -> StringName:
	if manning_lane != &"":
		return &"serving"
	if task.is_empty():
		return &"idle"
	match str(task["type"]):
		"serve":
			return &"serving"
		"pack":
			return &"packing"
	return &"kitchen"


# ===========================================================================
# KETUKAN (GDD idle 5.1, 5.2)
# ===========================================================================

## Kekuatan ketukan Semangat: upgrade global dan perk (GDD idle 5.2).
func tap_power() -> float:
	var p: float = 1.0 + sim.upgrades.global_bonus(&"global_tap_power")
	if sim.prestige != null:
		p *= sim.prestige.tap_mult()
	return p


## Detik-simulasi yang ditambahkan satu ketukan Semangat.
func tap_seconds() -> float:
	return DataRegistry.idlef("tap.progress_seconds") * tap_power()


## Ketuk stasiun: jadi prioritas pemilik sebentar, dan mixer/oven yang sedang
## bekerja mendapat Semangat. `now_ms` = jam nyata (ms) untuk batas ketukan
## (test boleh mengisinya). {focus: bool, boosted: bool}.
func tap_station(iid: int, now_ms: int = -1) -> Dictionary:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null or not e.placed:
		return {"focus": false, "boosted": false}
	focus_iid = iid
	focus_cashier = false
	focus_until = sim.time.sim_seconds + DataRegistry.idlef("owner.focus_seconds")
	_rethink_at = 0.0
	var boosted: bool = false
	if (e.category() == &"mixer" or e.category() == &"oven") and _boost_allowed(iid, now_ms):
		boosted = sim.production.boost_station(iid, tap_seconds())
		if boosted:
			EventBus.tap_boost.emit(iid, sim.world.access_of(iid).get("cell", e.anchor), e.floor_id)
			EventBus.sfx.emit(&"tap_boost_pop", e.floor_id)
	return {"focus": true, "boosted": boosted}


## Ketuk meja kasir atau pembeli di jalur A: pemilik mendahulukan jalur A, dan
## transaksi yang sedang berjalan di jalur yang diketuk mendapat Semangat.
func tap_cashier(lane_id: StringName, now_ms: int = -1) -> Dictionary:
	var lane: QueueLane = sim.queue.lane(lane_id)
	if lane == null:
		return {"focus": false, "boosted": false}
	focus_cashier = true
	focus_iid = -1
	focus_until = sim.time.sim_seconds + DataRegistry.idlef("owner.focus_seconds")
	_rethink_at = 0.0
	var boosted: bool = false
	if _boost_allowed("lane:" + String(lane_id), now_ms):
		boosted = sim.cashier.boost_lane(lane_id, tap_seconds())
		if boosted:
			EventBus.tap_boost.emit(-1, lane.service_point, lane.floor_id)
			EventBus.sfx.emit(&"tap_boost_pop", lane.floor_id)
	return {"focus": true, "boosted": boosted}


func tap_customer(customer_id: StringName, now_ms: int = -1) -> Dictionary:
	var c: Customer = sim.customers.customer(customer_id)
	if c == null or c.lane_id == &"":
		return {"focus": false, "boosted": false}
	return tap_cashier(c.lane_id, now_ms)


## Batas `tap.min_interval_seconds` nyata per stasiun (GDD idle 5.2): ketukan
## yang lebih cepat diabaikan tanpa efek.
func _boost_allowed(key: Variant, now_ms: int) -> bool:
	var now: int = now_ms if now_ms >= 0 else Time.get_ticks_msec()
	var gap: int = int(DataRegistry.idlef("tap.min_interval_seconds") * 1000.0)
	if _last_boost_ms.has(key) and now - int(_last_boost_ms[key]) < gap:
		return false
	_last_boost_ms[key] = now
	return true


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	actor.speed_mps = DataRegistry.player_speed_mps() * sim.upgrades.walk_mult()
	actor.step(dt, sim.world)
	if not focus_active():
		focus_iid = -1
		focus_cashier = false
	if manning_lane != &"":
		if actor.has_route():
			return
		if _keep_serving():
			var lane: QueueLane = sim.queue.lane(manning_lane)
			actor.state = &"SERVING_CASHIER"
			actor.facing = Vector2(lane.service_point - lane.cashier_point).normalized()
			return
		manning_lane = &""
		actor.state = &"IDLE"
	if not task.is_empty():
		if actor.has_route():
			return
		task["wait"] = float(task.get("wait", 0.0)) - dt
		if float(task["wait"]) > 0.0:
			actor.state = &"INTERACTING"
			return
		var done: Dictionary = task
		task = {}
		var next: Dictionary = _finish(done)
		if not next.is_empty():
			_begin(next)
		return
	if sim.time.sim_seconds < _rethink_at:
		return
	if not _choose_and_begin():
		actor.state = &"IDLE"
		_rethink_at = sim.time.sim_seconds + RETHINK_SECONDS


func _choose_and_begin() -> bool:
	if actor.carried.is_empty() and _should_serve():
		return _begin({"type": "serve"})
	var focus: int = focus_iid if focus_active() else -1
	var k: Dictionary = KitchenBrain.choose(sim, PLAYER_ID, actor, focus)
	if not k.is_empty() and _begin(k):
		return true
	if actor.carried.is_empty():
		var oid: int = sim.rotifood.next_order_to_pack(PLAYER_ID)
		if oid >= 0:
			return _begin({"type": "pack", "order_id": oid})
	return false


func _interact_seconds() -> float:
	return KitchenBrain.INTERACT_SECONDS


func _begin(t: Dictionary) -> bool:
	match str(t["type"]):
		"serve":
			var lane: QueueLane = sim.queue.main_lane()
			if lane == null or not actor.go_to(sim.world, lane.floor_id, lane.cashier_point):
				return false
			manning_lane = lane.id
			actor.state = &"WALKING"
			return true
		"pack":
			var lane2: QueueLane = sim.queue.main_lane()
			if lane2 == null or not sim.rotifood.claim_pack(int(t["order_id"]), PLAYER_ID):
				return false
			if not actor.go_to(sim.world, lane2.floor_id, lane2.cashier_point):
				sim.rotifood.release_pack(int(t["order_id"]), PLAYER_ID)
				return false
			t["wait"] = sim.rotifood.pack_seconds()
			task = t
			actor.state = &"WALKING"
			return true
	if not KitchenBrain.begin(sim, PLAYER_ID, actor, t, _interact_seconds()):
		return false
	task = t
	return true


func _finish(t: Dictionary) -> Dictionary:
	if str(t["type"]) == "pack":
		sim.rotifood.finish_pack(int(t["order_id"]), PLAYER_ID)
		actor.state = &"IDLE"
		return {}
	return KitchenBrain.finish(sim, PLAYER_ID, actor, t)


## Pembeli yang memegang roti sedang menunggu di jalur A (di antrean, di depan
## meja, atau sedang berjalan ke ujung antreannya), bukan driver RotiFood.
func _buyers_waiting(lane: QueueLane) -> bool:
	for id: StringName in lane.line:
		if sim.customers.customer(id) != null:
			return true
	if lane.service_occupant != &"":
		var c: Customer = sim.customers.customer(lane.service_occupant)
		if c != null:
			return true
	for id2: StringName in lane.reservations:
		var c2: Customer = sim.customers.customer(id2)
		if c2 != null and c2.state == Customer.CARRYING_TO_QUEUE:
			return true
	return false


## GDD idle 5.1 no. 1: ada pembeli menunggu di jalur A dan tidak ada jalur
## kasir lain yang buka dengan ruang. Ketukan arahan pada kasir mengirim pemilik
## ke jalur A walau belum ada yang menunggu di sana: jalur A buka dan antrean
## jalur lain menyeimbang ke sana (v3.1 21.3).
func _should_serve() -> bool:
	var lane: QueueLane = sim.queue.main_lane()
	if lane == null:
		return false
	if focus_cashier and focus_active():
		return true
	if not _buyers_waiting(lane):
		return false
	for o: QueueLane in sim.queue.staff_lanes():
		if sim.queue.is_open(o) and o.free_capacity() > 0:
			return false
	return true


## Sudah di kasir: tetap melayani selama masih ada pembeli menunggu di jalur A,
## atau selama ketukan arahan pada kasir masih berlaku.
func _keep_serving() -> bool:
	var lane: QueueLane = sim.queue.lane(manning_lane)
	if lane == null:
		return false
	if focus_cashier and focus_active():
		return true
	return _buyers_waiting(lane) or sim.cashier.transaction_for(lane.id).size() > 0


func cancel_all() -> void:
	if not task.is_empty():
		if str(task["type"]) == "pack":
			sim.rotifood.release_pack(int(task["order_id"]), PLAYER_ID)
		else:
			KitchenBrain.abort(sim, PLAYER_ID, task)
	task = {}
	manning_lane = &""
	actor.stop()


# ===========================================================================
# PENANDA BAR PROGRES (v3.1 7, 18.6)
# ===========================================================================

## iid -> {mode: &"progress", value: float, state: StringName} untuk mixer dan
## oven yang bekerja atau menahan isinya.
func station_markers() -> Dictionary:
	var out: Dictionary = {}
	for e: EquipmentInstance in sim.equipment.placed_list():
		if e.job_id < 0:
			continue
		var j: ProductionJob = sim.production.get_job(e.job_id)
		if j == null:
			continue
		match e.category():
			&"mixer":
				if j.stage == ProductionJob.MIXING:
					out[e.iid] = {"mode": &"progress", "value": j.progress(), "state": j.stage}
				elif j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP:
					out[e.iid] = {"mode": &"progress", "value": 1.0, "state": j.stage}
			&"oven":
				if j.stage == ProductionJob.BAKING:
					out[e.iid] = {"mode": &"progress", "value": j.progress(), "state": j.stage}
				elif j.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP:
					out[e.iid] = {"mode": &"progress", "value": 1.0, "state": j.stage}
	return out


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	return {"appearance": appearance.duplicate(), "actor": actor.to_dict(), "focus_iid": focus_iid,
		"focus_cashier": focus_cashier, "focus_until": focus_until}


func restore(d: Dictionary) -> void:
	_make_actor()
	appearance = d.get("appearance", {"gender": "male"})
	actor.apply_dict(d.get("actor", {}))
	task = {}
	manning_lane = &""
	focus_iid = int(d.get("focus_iid", -1))
	focus_cashier = bool(d.get("focus_cashier", false))
	focus_until = float(d.get("focus_until", -1.0))


## Setelah load: tugas dimulai ulang dari state otoritatif. Barang di tangan
## tetap dibawa bila job-nya masih ada; selain itu tangan dikosongkan.
func reconstruct() -> void:
	actor.stop()
	task = {}
	manning_lane = &""
	var c: Vector2i = sim.world.nearest_walkable(actor.floor_id, actor.cell(), FloorGrid.NAV_STAFF)
	if c.x >= 0 and c != actor.cell():
		actor.place_at(actor.floor_id, c)
	var j: ProductionJob = carried_job()
	if j == null or j.carrier_id != PLAYER_ID:
		actor.carried = {}
