class_name PlayerTaskManager
extends SimManager
## PlayerTaskManager — karakter pemain sebagai task-driven actor (GDD 2, 12.3.4,
## 16, 21.4). Yang mengantre hanyalah kakinya: mixer & oven terus bekerja.
##
## Setiap ketukan pada perabot selalu dihampiri; aksi ditentukan saat karakter
## tiba. Barang bawaan tidak pernah hilang saat jalan gagal (GDD 16.5).

const INTERACT_SECONDS: float = 0.3
const PLAYER_ID: StringName = &"player"

var actor: SimActor = null
## {gender: "male"/"female"} — murni kosmetik (GDD 31.3).
var appearance: Dictionary = {"gender": "male"}
## Antrean perintah logis: {kind, target, from_customer, id}.
var commands: Array[Dictionary] = []
var current: Dictionary = {}
var manning_lane: StringName = &""
var next_command_id: int = 1


func new_game() -> void:
	commands.clear()
	current = {}
	manning_lane = &""
	next_command_id = 1
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


func is_manning_lane(lane_id: StringName) -> bool:
	return manning_lane == lane_id and not actor.has_route()


# ===========================================================================
# KETUKAN (GDD 16.3, 16.4, 16.7)
# ===========================================================================

func tap_equipment(iid: int) -> bool:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null or not e.placed:
		return false
	if not sim.tutorial.allows_tap(e.category()):
		return false
	var kind: StringName = e.category()
	# Tangan penuh: hanya pengantaran yang cocok yang diterima (GDD 16.5).
	if commands.is_empty() and current.is_empty() and not actor.carried.is_empty():
		var t: String = str(actor.carried.get("type", ""))
		var ok: bool = (t == "dough" and kind == &"oven") or (t == "tray" and kind == &"display")
		if not ok and kind != &"display":
			_feedback(&"hands_full", e.floor_id, sim.world.access_of(iid).get("cell", e.anchor))
			return false
	return _enqueue({"kind": kind, "target": iid, "from_customer": false})


func tap_cashier(lane_id: StringName, from_customer: bool) -> bool:
	if not sim.tutorial.allows_tap(&"cashier"):
		return false
	if sim.staff.cashier_for_lane(lane_id) != null:
		_feedback(&"staff_serving", sim.queue.lane(lane_id).floor_id, sim.queue.lane(lane_id).cashier_point)
		return false
	var lane: QueueLane = sim.queue.lane(lane_id)
	if lane == null or not lane.main:
		return false
	# Sudah berjaga di meja: ketukan balon langsung membuka popup (GDD 2 langkah 5).
	if is_manning_lane(lane_id) and current.is_empty():
		_open_order_popup(lane)
		return true
	return _enqueue({"kind": &"cashier", "target": String(lane_id), "from_customer": from_customer})


## Ketuk pintu tangga (Tier 2-3): karakter berjalan ke portal dan langsung
## berpindah lantai tanpa animasi tangga (GDD 30.4, 68).
func tap_portal() -> bool:
	var fg: FloorGrid = sim.world.grid(actor.floor_id)
	if fg == null or not fg.def.has_portal():
		return false
	return _enqueue({"kind": &"portal", "target": String(fg.def.portal["target_floor"]), "from_customer": false})


func tap_customer(customer_id: StringName) -> bool:
	var c: Customer = sim.customers.customer(customer_id)
	if c == null or not c.awaiting_tap:
		return false
	return tap_cashier(c.lane_id, true)


func _enqueue(cmd: Dictionary) -> bool:
	# Ketukan ganda pada target yang sama diabaikan.
	if not commands.is_empty() and _same_command(commands[commands.size() - 1], cmd):
		return true
	if not current.is_empty() and commands.is_empty() and _same_command(current, cmd):
		return true
	cmd["id"] = next_command_id
	next_command_id += 1
	var limit: int = DataRegistry.bali("player.max_queued_commands")
	if commands.size() >= limit:
		# Ganti tujuan terakhir yang belum terkunci interaksi (GDD 16.4).
		commands[commands.size() - 1] = cmd
		_feedback(&"command_queue_full", actor.floor_id, actor.cell())
	else:
		commands.append(cmd)
	return true


## Target bisa iid perabot (int) atau id lane/lantai (String): jenis dibandingkan
## dulu supaya int tidak pernah dibandingkan dengan String.
static func _same_command(a: Dictionary, b: Dictionary) -> bool:
	if StringName(str(a["kind"])) != StringName(str(b["kind"])):
		return false
	var ta: Variant = a["target"]
	var tb: Variant = b["target"]
	if (ta is int or ta is float) and (tb is int or tb is float):
		return int(ta) == int(tb)
	return str(ta) == str(tb)


func cancel_all() -> void:
	commands.clear()
	current = {}
	actor.stop()


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	actor.step(dt, sim.world)
	if current.is_empty():
		if commands.is_empty():
			if actor.state != &"SERVING_CASHIER":
				actor.state = &"IDLE"
			return
		current = commands.pop_front()
		current["wait"] = INTERACT_SECONDS
		if not _route(current):
			_feedback(&"path_blocked", actor.floor_id, actor.cell())
			actor.state = &"BLOCKED"
			current = {}
			return
		if manning_lane != &"" and not (current["kind"] == &"cashier" and StringName(str(current["target"])) == manning_lane):
			manning_lane = &""
		actor.state = &"WALKING"
		return
	if actor.has_route():
		return
	current["wait"] = float(current["wait"]) - dt
	if float(current["wait"]) > 0.0:
		actor.state = &"INTERACTING"
		return
	var cmd: Dictionary = current
	current = {}
	_execute(cmd)


func _route(cmd: Dictionary) -> bool:
	if cmd["kind"] == &"portal":
		var target: StringName = StringName(str(cmd["target"]))
		var tg: FloorGrid = sim.world.grid(target)
		if tg == null or not tg.def.has_portal():
			return false
		return actor.go_to(sim.world, target, tg.def.portal["access"])
	if cmd["kind"] == &"cashier":
		var lane: QueueLane = sim.queue.lane(StringName(str(cmd["target"])))
		return actor.go_to(sim.world, lane.floor_id, lane.cashier_point)
	var acc: Dictionary = sim.world.access_of(int(cmd["target"]))
	if acc.is_empty():
		return false
	return actor.go_to(sim.world, acc["floor"], acc["cell"])


func _execute(cmd: Dictionary) -> void:
	actor.state = &"IDLE"
	match cmd["kind"]:
		&"storage":
			_at_storage(int(cmd["target"]))
		&"mixer":
			_at_mixer(int(cmd["target"]))
		&"oven":
			_at_oven(int(cmd["target"]))
		&"display":
			_at_display(int(cmd["target"]))
		&"portal":
			pass
		&"cashier":
			var lane: QueueLane = sim.queue.lane(StringName(str(cmd["target"])))
			manning_lane = lane.id
			actor.state = &"SERVING_CASHIER"
			# Berbalik menghadap antrean dari sisi dapur meja (GDD 2).
			actor.facing = Vector2(lane.service_point - lane.cashier_point).normalized()
			sim.tutorial.on_event(&"player_at_cashier")
			_open_order_popup(lane)


func _open_order_popup(lane: QueueLane) -> void:
	if lane.service_occupant == &"":
		return
	var c: Customer = sim.customers.customer(lane.service_occupant)
	if c != null and c.awaiting_tap and c.state == Customer.FRONT_OF_QUEUE and not c.actor.has_route():
		sim.ui_requests.customer_order = c.id
		EventBus.customer_order_requested.emit(0)


func _at_storage(iid: int) -> void:
	if not actor.carried.is_empty():
		_feedback_at(&"hands_full", iid)
		return
	EventBus.storage_door.emit(iid, true)
	EventBus.sfx.emit(&"storage_open", actor.floor_id)
	sim.ui_requests.recipe_book_storage = iid
	EventBus.recipe_book_requested.emit()
	sim.tutorial.on_event(&"storage_opened")


## Buku Resep: pemain memilih resep & batch (GDD 2 langkah 2).
func order_recipe(recipe_id: StringName, batch: int) -> String:
	var reason: String = sim.production.make_block_reason(recipe_id, batch)
	if reason != "":
		return reason
	var j: ProductionJob = sim.production.create_job(recipe_id, batch, PLAYER_ID)
	if j == null:
		return "ui_recipe_cannot_make"
	sim.tutorial.on_event(&"recipe_ordered")
	return ""


func close_storage() -> void:
	var iid: int = sim.ui_requests.recipe_book_storage
	if iid >= 0:
		EventBus.storage_door.emit(iid, false)
		EventBus.sfx.emit(&"storage_close", actor.floor_id)
	sim.ui_requests.recipe_book_storage = -1


func _at_mixer(iid: int) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	var j: ProductionJob = sim.production.get_job(e.job_id) if e.job_id >= 0 else null
	if j == null:
		_feedback_at(&"nothing_to_do", iid)
		return
	match j.stage:
		ProductionJob.ORDERED:
			if not actor.carried.is_empty():
				_feedback_at(&"hands_full", iid)
				return
			sim.production.start_mixing(j.job_id, PLAYER_ID, 1.0)
			sim.tutorial.on_event(&"mixing_started")
		ProductionJob.MIXING:
			_feedback_at(&"station_busy", iid)
		ProductionJob.MIX_DONE_WAITING_PICKUP:
			if not actor.carried.is_empty():
				_feedback_at(&"hands_full", iid)
				return
			if j.claimed_by != &"" and j.claimed_by != PLAYER_ID:
				_feedback_at(&"station_busy", iid)
				return
			if sim.production.pickup_dough(j.job_id, PLAYER_ID):
				actor.carried = {"type": "dough", "job_id": j.job_id, "recipe_id": String(j.recipe_id)}
				sim.tutorial.on_event(&"dough_picked")
		_:
			_feedback_at(&"nothing_to_do", iid)


func _at_oven(iid: int) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	var carried: ProductionJob = carried_job()
	if carried != null and carried.stage == ProductionJob.CARRIED_TO_OVEN:
		if e.job_id >= 0:
			_feedback_at(&"station_busy", iid)
			return
		if e.tier() < carried.recipe().required_oven_tier:
			_feedback_at(&"no_free_oven", iid)
			return
		if sim.production.insert_oven(carried.job_id, iid, PLAYER_ID, 1.0):
			actor.carried = {}
			sim.tutorial.on_event(&"oven_inserted")
		return
	var j: ProductionJob = sim.production.get_job(e.job_id) if e.job_id >= 0 else null
	if j == null:
		_feedback_at(&"nothing_to_do" if actor.carried.is_empty() else &"hands_full", iid)
		return
	if j.stage == ProductionJob.BAKING:
		_feedback_at(&"station_busy", iid)
		return
	if j.is_waiting_oven_pickup():
		if not actor.carried.is_empty():
			_feedback_at(&"hands_full", iid)
			return
		if j.protected and j.claimed_by != &"":
			_feedback_at(&"station_busy", iid)
			return
		var r: Dictionary = sim.production.pickup_tray(j.job_id, PLAYER_ID)
		if bool(r.get("burnt", false)):
			_feedback_at(&"burnt_discarded", iid)
		elif bool(r.get("ok", false)):
			actor.carried = {"type": "tray", "job_id": j.job_id, "recipe_id": String(j.recipe_id)}
			sim.tutorial.on_event(&"tray_picked")
		sim.alerts.clear_oven(iid)


func _at_display(iid: int) -> void:
	var j: ProductionJob = carried_job()
	if j != null and j.stage == ProductionJob.CARRIED_TO_DISPLAY:
		if sim.display.free_units(iid) <= 0:
			_feedback_at(&"display_full", iid)
			return
		j.stage = ProductionJob.PLACEMENT_UI
		sim.ui_requests.slot_picker_display = iid
		EventBus.slot_picker_requested.emit(iid)
		sim.tutorial.on_event(&"slot_picker")
		return
	sim.ui_requests.display_detail = iid
	EventBus.display_detail_requested.emit(iid)


## Pemilih petak: taruh `qty` unit ke satu petak (GDD 7, 85).
func place_into_slot(display_iid: int, slot_index: int, qty: int) -> int:
	var j: ProductionJob = carried_job()
	if j == null:
		return 0
	var n: int = sim.production.place_from_tray(j.job_id, display_iid, slot_index, qty)
	if sim.production.get_job(j.job_id) == null:
		actor.carried = {}
		sim.ui_requests.slot_picker_display = -1
		sim.tutorial.on_event(&"bread_placed")
	return n


## Pemilih petak ditutup sebelum loyang habis: sisa tetap dibawa (GDD 19.3).
func close_slot_picker() -> void:
	var j: ProductionJob = carried_job()
	if j != null and j.stage == ProductionJob.PLACEMENT_UI:
		j.stage = ProductionJob.CARRIED_TO_DISPLAY
	sim.ui_requests.slot_picker_display = -1


func _feedback_at(kind: StringName, iid: int) -> void:
	var acc: Dictionary = sim.world.access_of(iid)
	if acc.is_empty():
		_feedback(kind, actor.floor_id, actor.cell())
	else:
		_feedback(kind, acc["floor"], acc["cell"])


func _feedback(kind: StringName, floor_id: StringName, cell: Vector2i) -> void:
	EventBus.feedback.emit(kind, cell, floor_id)
	if kind != &"nothing_to_do":
		EventBus.sfx.emit(&"ui_error", floor_id)


# ===========================================================================
# PENANDA "!" & BAR PROGRES (GDD 2, 7, 18.6)
# ===========================================================================

## iid -> {mode: &"alert"|&"progress", value: float, burn: float, state: StringName}
func station_markers() -> Dictionary:
	var out: Dictionary = {}
	var carried: ProductionJob = carried_job()
	for e: EquipmentInstance in sim.equipment.placed_list():
		var j: ProductionJob = sim.production.get_job(e.job_id) if e.job_id >= 0 else null
		match e.category():
			&"mixer":
				if j != null:
					if j.stage == ProductionJob.MIXING:
						out[e.iid] = {"mode": &"progress", "value": j.progress(), "burn": 0.0, "state": j.stage}
					elif j.stage == ProductionJob.ORDERED and j.owner_actor_id == PLAYER_ID:
						out[e.iid] = {"mode": &"alert", "value": 0.0, "burn": 0.0, "state": j.stage}
					elif j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP and (j.owner_actor_id == PLAYER_ID or j.claimed_by == &""):
						out[e.iid] = {"mode": &"alert", "value": 1.0, "burn": 0.0, "state": j.stage}
			&"oven":
				if j != null:
					if j.stage == ProductionJob.BAKING:
						out[e.iid] = {"mode": &"progress", "value": j.progress(), "burn": 0.0, "state": j.stage}
					elif j.is_waiting_oven_pickup() and not j.protected:
						out[e.iid] = {"mode": &"alert", "value": 1.0, "burn": sim.production.burn_progress(j), "state": j.stage}
				elif carried != null and carried.stage == ProductionJob.CARRIED_TO_OVEN and e.tier() >= carried.recipe().required_oven_tier:
					out[e.iid] = {"mode": &"alert", "value": 0.0, "burn": 0.0, "state": &"deliver"}
			&"display":
				if carried != null and (carried.stage == ProductionJob.CARRIED_TO_DISPLAY or carried.stage == ProductionJob.PLACEMENT_UI) and sim.display.free_units(e.iid) > 0:
					out[e.iid] = {"mode": &"alert", "value": 0.0, "burn": 0.0, "state": &"deliver"}
	return out


func capture() -> Dictionary:
	var cmds: Array = []
	for c: Dictionary in commands:
		cmds.append({"kind": String(c["kind"]), "target": c["target"], "from_customer": c["from_customer"], "id": c["id"]})
	var cur: Dictionary = {}
	if not current.is_empty():
		cur = {"kind": String(current["kind"]), "target": current["target"], "from_customer": current["from_customer"], "id": current["id"]}
	return {"appearance": appearance.duplicate(), "actor": actor.to_dict(), "commands": cmds,
		"current": cur, "manning_lane": String(manning_lane), "next_command_id": next_command_id}


func restore(d: Dictionary) -> void:
	_make_actor()
	appearance = d.get("appearance", {"gender": "male"})
	actor.apply_dict(d.get("actor", {}))
	commands.clear()
	for c: Variant in d.get("commands", []):
		var cd: Dictionary = c
		commands.append({"kind": StringName(str(cd["kind"])), "target": cd["target"], "from_customer": cd.get("from_customer", false), "id": int(cd.get("id", 0))})
	var cur: Dictionary = d.get("current", {})
	if not cur.is_empty():
		# Perintah yang sedang berjalan diulang dari awal rute (bukan transform mentah, GDD 16.4).
		commands.push_front({"kind": StringName(str(cur["kind"])), "target": cur["target"], "from_customer": cur.get("from_customer", false), "id": int(cur.get("id", 0))})
	current = {}
	manning_lane = StringName(str(d.get("manning_lane", "")))
	next_command_id = int(d.get("next_command_id", 1))


func reconstruct() -> void:
	actor.stop()
	var c: Vector2i = sim.world.nearest_walkable(actor.floor_id, actor.cell(), FloorGrid.NAV_STAFF)
	if c.x >= 0 and c != actor.cell():
		actor.place_at(actor.floor_id, c)
	# Loyang yang sedang dipilih petaknya saat disimpan kembali ke status dibawa.
	var j: ProductionJob = carried_job()
	if j != null and j.stage == ProductionJob.PLACEMENT_UI:
		j.stage = ProductionJob.CARRIED_TO_DISPLAY
	if j == null and not actor.carried.is_empty():
		actor.carried = {}
