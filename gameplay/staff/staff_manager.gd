class_name StaffManager
extends SimManager
## StaffManager — pemilik kontrak & status tugas staf dan otomasi mereka
## (GDD 3.1-3.5, 23, 24.6, 49, 87, 98).
##
## Roster tetap: kandidat sama selalu tersedia, tanpa XP, tanpa biaya rekrut.
## Gaji hari itu dikunci pukul 05:00 untuk semua staf on_duty (DailyWageLiability).

const INTERACT_SECONDS: float = 0.3
## Jeda evaluasi ulang staf yang menganggur/terblokir (detik simulasi).
const RETHINK_SECONDS: float = 0.5

## staff_id -> {employed, on_duty, working, mode, target_recipe, batch, hired_day, batches_today}
var contracts: Dictionary = {}
## staff_id -> SimActor (hanya staf yang sedang bekerja).
var actors: Dictionary = {}
## staff_id -> task {type, job_id, iid, phase, wait}
var tasks: Dictionary = {}
## staff_id -> lane_id untuk kasir yang bekerja.
var lane_assign: Dictionary = {}
var wage_liability_today: float = 0.0
## Transien (tidak disimpan): kapan staf boleh mengevaluasi ulang tugas.
var _rethink_at: Dictionary = {}
var wage_lines_today: Array = []


func new_game() -> void:
	contracts.clear()
	actors.clear()
	tasks.clear()
	lane_assign.clear()
	wage_liability_today = 0.0
	wage_lines_today.clear()


func contract(staff_id: StringName) -> Dictionary:
	return contracts.get(staff_id, {})


func is_employed(staff_id: StringName) -> bool:
	return bool(contract(staff_id).get("employed", false))


func employed_ids(role: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for s: StaffDefinition in DataRegistry.staff_list():
		if is_employed(s.id) and (role == &"" or s.role_id == role):
			out.append(s.id)
	return out


func working_ids(role: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in employed_ids(role):
		if bool(contract(id).get("working", false)):
			out.append(id)
	return out


func capacity(role: StringName) -> int:
	return sim.world.location.staff_capacity(role)


# ===========================================================================
# KONTRAK (GDD 3.4, 87)
# ===========================================================================

func can_hire_now() -> bool:
	return sim.time.is_after_hours()


## Rekrut: gratis, mulai bertugas 05:00 berikutnya (GDD 87.3).
func hire(staff_id: StringName) -> StringName:
	var def: StaffDefinition = DataRegistry.staff(staff_id)
	if def == null:
		return &"invalid"
	if is_employed(staff_id):
		return &"employed"
	if not can_hire_now():
		return &"after_hours"
	if employed_ids(def.role_id).size() >= capacity(def.role_id):
		return &"full"
	contracts[staff_id] = {"employed": true, "on_duty": not sim.bailout.solo_mode, "working": false,
		"mode": "auto", "target_recipe": "", "batch": 0, "hired_day": sim.time.day, "batches_today": 0}
	sim.statistics.add(&"staff_hired_count", 1)
	EventBus.staff_state_changed.emit(staff_id)
	SaveManager.request_autosave("staff_hire")
	return &""


## Pecat kapan saja; gaji hari ini tetap dibayar bila sudah on_duty 05:00 (GDD 3.4).
func fire(staff_id: StringName) -> StringName:
	if not is_employed(staff_id):
		return &"invalid"
	_stop_working(staff_id)
	contracts.erase(staff_id)
	EventBus.staff_state_changed.emit(staff_id)
	SaveManager.request_autosave("staff_fire")
	return &""


## Libur/jadwalkan. Libur berlaku seketika (gaji hari ini tetap bila sudah
## terkunci); jadwal kerja berlaku mulai 05:00 berikutnya (GDD 24.6, 49.3).
func set_on_duty(staff_id: StringName, value: bool) -> StringName:
	var c: Dictionary = contract(staff_id)
	if c.is_empty():
		return &"invalid"
	if value == bool(c["on_duty"]):
		return &""
	if value and sim.bailout.solo_mode and not can_afford_schedule_with(staff_id):
		return &"kr"
	c["on_duty"] = value
	if not value:
		_stop_working(staff_id)
	EventBus.staff_state_changed.emit(staff_id)
	return &""


func set_mode(staff_id: StringName, mode: String, target_recipe: StringName) -> void:
	var c: Dictionary = contract(staff_id)
	if c.is_empty():
		return
	c["mode"] = mode
	c["target_recipe"] = String(target_recipe)
	EventBus.staff_state_changed.emit(staff_id)


func set_batch(staff_id: StringName, batch: int) -> void:
	var c: Dictionary = contract(staff_id)
	if c.is_empty() or not [0, 1, 3, 5].has(batch):
		return
	c["batch"] = batch


func scheduled_wages() -> float:
	var t: float = 0.0
	for id: StringName in employed_ids():
		if bool(contract(id)["on_duty"]):
			t += DataRegistry.staff(id).daily_wage_kr
	return t


## Aturan keluar Mode Solo (GDD 49.3): saldo >= gaji terjadwal + batch termurah.
func can_afford_schedule_with(extra_id: StringName) -> bool:
	var wages: float = scheduled_wages()
	if not bool(contract(extra_id).get("on_duty", false)):
		wages += DataRegistry.staff(extra_id).daily_wage_kr
	return sim.economy.balance >= wages + sim.bailout.cheapest_producible_batch_cost()


func projected_cash_after_wages() -> float:
	return sim.economy.balance - scheduled_wages()


# ===========================================================================
# HARI KERJA (GDD 87.2, 87.3)
# ===========================================================================

## 05:00: liabilitas gaji dikunci, staf on_duty mulai bekerja.
func begin_day() -> void:
	wage_liability_today = 0.0
	wage_lines_today.clear()
	lane_assign.clear()
	for id: StringName in employed_ids():
		var c: Dictionary = contract(id)
		c["batches_today"] = 0
		c["working"] = bool(c["on_duty"])
		if bool(c["working"]):
			var def: StaffDefinition = DataRegistry.staff(id)
			wage_liability_today += def.daily_wage_kr
			wage_lines_today.append({"staff_id": String(id), "wage": def.daily_wage_kr})
			_spawn(id)
	_assign_lanes()


func _assign_lanes() -> void:
	lane_assign.clear()
	var cashiers: Array[StringName] = working_ids(&"cashier")
	cashiers.sort_custom(func(a: StringName, b: StringName) -> bool:
		var ta: int = DataRegistry.staff(a).tier
		var tb: int = DataRegistry.staff(b).tier
		if ta != tb:
			return ta > tb
		return String(a) < String(b))
	var lanes: Array[QueueLane] = sim.queue.lanes
	for i in mini(cashiers.size(), lanes.size()):
		lane_assign[cashiers[i]] = lanes[i].id
		var a: SimActor = actors.get(cashiers[i])
		if a != null:
			a.go_to(sim.world, lanes[i].floor_id, lanes[i].cashier_point)


func _spawn(staff_id: StringName) -> void:
	var def: StaffDefinition = DataRegistry.staff(staff_id)
	var a := SimActor.new()
	a.id = staff_id
	a.kind = &"staff"
	a.nav_class = FloorGrid.NAV_STAFF
	a.speed_mps = def.movement_speed_mps
	a.visual_key = staff_id
	var storage: EquipmentInstance = sim.equipment.storage_instance()
	var acc: Dictionary = sim.world.access_of(storage.iid) if storage != null else {}
	if def.is_baker() and not acc.is_empty():
		a.place_at(acc["floor"], acc["cell"])
	else:
		var lane: QueueLane = sim.queue.main_lane()
		a.place_at(lane.floor_id, lane.cashier_point)
	actors[staff_id] = a
	tasks.erase(staff_id)


func _stop_working(staff_id: StringName) -> void:
	var c: Dictionary = contract(staff_id)
	if not c.is_empty():
		c["working"] = false
	var a: SimActor = actors.get(staff_id)
	if a != null:
		_drop_carried(staff_id, a)
	_release_claims(staff_id)
	sim.world.release_all_for(staff_id)
	actors.erase(staff_id)
	tasks.erase(staff_id)
	lane_assign.erase(staff_id)
	_assign_lanes()


func _release_claims(staff_id: StringName) -> void:
	for j: ProductionJob in sim.production.sorted_jobs():
		if j.claimed_by == staff_id:
			j.claimed_by = &""


## Serah terima atomik saat staf berhenti (GDD 87.2): loyang ke rak, adonan
## kembali ke mixer bebas agar tidak ada job yatim.
func _drop_carried(staff_id: StringName, a: SimActor) -> void:
	if a.carried.is_empty():
		return
	var j: ProductionJob = sim.production.get_job(int(a.carried.get("job_id", -1)))
	if j != null:
		if j.stage == ProductionJob.CARRIED_TO_DISPLAY:
			sim.production.auto_place_tray(j.job_id, -1)
			if j.carried_units > 0:
				j.carrier_id = &"player_handoff"
		elif j.stage == ProductionJob.CARRIED_TO_OVEN:
			var mixer: EquipmentInstance = sim.production.free_mixer_for(j.recipe())
			if mixer != null:
				mixer.job_id = j.job_id
				j.mixer_id = mixer.iid
				j.stage = ProductionJob.MIX_DONE_WAITING_PICKUP
				j.carrier_id = &""
	a.carried = {}


## 18:00: staf berhenti mengambil tugas, menyelesaikan serah terima, lalu pulang.
func end_day() -> void:
	for id: StringName in working_ids():
		var a: SimActor = actors.get(id)
		if a != null:
			_drop_carried(id, a)
		_release_claims(id)
		sim.world.release_all_for(id)
		contract(id)["working"] = false
	actors.clear()
	tasks.clear()
	lane_assign.clear()


## Bailout: semua staf diliburkan, kontrak tetap (GDD 49.2).
func put_all_off_duty() -> void:
	for id: StringName in employed_ids():
		contract(id)["on_duty"] = false
		if bool(contract(id).get("working", false)):
			_stop_working(id)
		EventBus.staff_state_changed.emit(id)


func note_batch_completed(owner: StringName) -> void:
	var c: Dictionary = contract(owner)
	if not c.is_empty():
		c["batches_today"] = int(c.get("batches_today", 0)) + 1


# ===========================================================================
# KASIR (GDD 21.5)
# ===========================================================================

func cashier_for_lane(lane_id: StringName) -> StaffDefinition:
	for sid: Variant in lane_assign.keys():
		if StringName(str(lane_assign[sid])) == lane_id:
			return DataRegistry.staff(StringName(str(sid)))
	return null


func cashier_def_for_lane(lane_id: StringName) -> StaffDefinition:
	return cashier_for_lane(lane_id)


func any_cashier_working() -> bool:
	return not lane_assign.is_empty()


func cashier_at_post(lane_id: StringName) -> bool:
	for sid: Variant in lane_assign.keys():
		if StringName(str(lane_assign[sid])) == lane_id:
			var a: SimActor = actors.get(StringName(str(sid)))
			var lane: QueueLane = sim.queue.lane(lane_id)
			return a != null and not a.has_route() and a.floor_id == lane.floor_id and a.cell() == lane.cashier_point
	return false


# ===========================================================================
# TICK: gerak kasir & AI baker (GDD 23)
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	var ids: Array = actors.keys()
	ids.sort()
	for k: Variant in ids:
		var sid: StringName = StringName(str(k))
		var a: SimActor = actors[sid]
		a.step(dt, sim.world)
		var def: StaffDefinition = DataRegistry.staff(sid)
		if def.is_cashier():
			var lane_id: Variant = lane_assign.get(sid)
			if lane_id != null and not a.has_route() and _may_rethink(sid):
				var lane: QueueLane = sim.queue.lane(StringName(str(lane_id)))
				if a.cell() != lane.cashier_point:
					a.go_to(sim.world, lane.floor_id, lane.cashier_point)
					_defer_rethink(sid)
		else:
			_baker_step(sid, a, def, dt)


## Staf yang menganggur/terblokir/salah posisi tidak menghitung ulang rute dan
## rencana setiap tick; cukup tiap RETHINK_SECONDS simulasi (performa, GDD 109).
func _may_rethink(sid: StringName) -> bool:
	return sim.time.sim_seconds >= float(_rethink_at.get(sid, -1.0))


func _defer_rethink(sid: StringName) -> void:
	_rethink_at[sid] = sim.time.sim_seconds + RETHINK_SECONDS


func _baker_step(sid: StringName, a: SimActor, def: StaffDefinition, dt: float) -> void:
	var task: Dictionary = tasks.get(sid, {})
	if task.is_empty():
		if not _may_rethink(sid):
			return
		task = _choose_task(sid, a, def)
		if task.is_empty():
			a.state = &"IDLE"
			_defer_rethink(sid)
			return
		tasks[sid] = task
		if not _route_to_task(sid, a, task):
			sim.alerts.raise_staff_blocked(sid, a.floor_id)
			tasks.erase(sid)
			_release_task_claim(task)
			a.state = &"BLOCKED"
			_defer_rethink(sid)
			return
		a.state = &"WALKING"
	if a.has_route():
		return
	task["wait"] = float(task.get("wait", INTERACT_SECONDS)) - dt
	if float(task["wait"]) > 0.0:
		a.state = &"INTERACTING"
		return
	_finish_task(sid, a, def, task)
	tasks.erase(sid)


## Prioritas baker (GDD 23.3).
func _choose_task(sid: StringName, a: SimActor, def: StaffDefinition) -> Dictionary:
	# 2. Antar barang bawaan.
	if not a.carried.is_empty():
		var j: ProductionJob = sim.production.get_job(int(a.carried["job_id"]))
		if j == null:
			a.carried = {}
		elif j.stage == ProductionJob.CARRIED_TO_OVEN:
			var oven: EquipmentInstance = sim.production.free_oven_for(j.recipe())
			if oven != null:
				return {"type": "insert_oven", "job_id": j.job_id, "iid": oven.iid}
			return {}
		elif j.stage == ProductionJob.CARRIED_TO_DISPLAY:
			var disp: int = _display_with_room()
			if disp >= 0:
				return {"type": "place_display", "job_id": j.job_id, "iid": disp}
			return {}
	# 1. Ambil tray yang auto-retrieve-nya berhasil.
	for j2: ProductionJob in sim.production.sorted_jobs():
		if j2.protected and j2.claimed_by == sid and j2.is_waiting_oven_pickup():
			return {"type": "pickup_tray", "job_id": j2.job_id, "iid": j2.oven_id}
	# 3. Pindahkan adonan selesai milik baker ke oven kosong.
	for j3: ProductionJob in sim.production.sorted_jobs():
		if j3.owner_actor_id == sid and j3.stage == ProductionJob.MIX_DONE_WAITING_PICKUP and (j3.claimed_by == &"" or j3.claimed_by == sid):
			if sim.production.free_oven_for(j3.recipe()) != null:
				j3.claimed_by = sid
				return {"type": "pickup_dough", "job_id": j3.job_id, "iid": j3.mixer_id}
	# Mulai mixing job milik baker yang sudah dipesan.
	for j4: ProductionJob in sim.production.sorted_jobs():
		if j4.owner_actor_id == sid and j4.stage == ProductionJob.ORDERED:
			return {"type": "start_mixing", "job_id": j4.job_id, "iid": j4.mixer_id}
	# 4-5. Isi ulang rak: mulai job baru.
	var plan: Dictionary = _plan_new_job(sid, def)
	if not plan.is_empty():
		var storage: EquipmentInstance = sim.equipment.storage_instance()
		if storage != null:
			return {"type": "order_job", "recipe": plan["recipe"], "batch": plan["batch"], "iid": storage.iid}
	return {}


func _route_to_task(sid: StringName, a: SimActor, task: Dictionary) -> bool:
	var acc: Dictionary = sim.world.access_of(int(task["iid"]))
	if acc.is_empty():
		return false
	task["wait"] = INTERACT_SECONDS
	return a.go_to(sim.world, acc["floor"], acc["cell"])


func _release_task_claim(task: Dictionary) -> void:
	var j: ProductionJob = sim.production.get_job(int(task.get("job_id", -1)))
	if j != null and task.get("type") == "pickup_dough":
		j.claimed_by = &""


func _finish_task(sid: StringName, a: SimActor, def: StaffDefinition, task: Dictionary) -> void:
	var jid: int = int(task.get("job_id", -1))
	a.state = &"IDLE"
	match str(task["type"]):
		"order_job":
			var j: ProductionJob = sim.production.create_job(task["recipe"], int(task["batch"]), sid)
			if j != null:
				tasks[sid] = {"type": "start_mixing", "job_id": j.job_id, "iid": j.mixer_id}
				_route_to_task(sid, a, tasks[sid])
				EventBus.storage_door.emit(int(task["iid"]), true)
		"start_mixing":
			sim.production.start_mixing(jid, sid, def.work_speed_multiplier)
		"pickup_dough":
			if sim.production.pickup_dough(jid, sid):
				var j2: ProductionJob = sim.production.get_job(jid)
				a.carried = {"type": "dough", "job_id": jid, "recipe_id": String(j2.recipe_id)}
		"insert_oven":
			if sim.production.insert_oven(jid, int(task["iid"]), sid, def.work_speed_multiplier):
				a.carried = {}
		"pickup_tray":
			var r: Dictionary = sim.production.pickup_tray(jid, sid)
			if bool(r.get("ok", false)) and not bool(r.get("burnt", false)):
				var j3: ProductionJob = sim.production.get_job(jid)
				a.carried = {"type": "tray", "job_id": jid, "recipe_id": String(j3.recipe_id)}
		"place_display":
			sim.production.auto_place_tray(jid, int(task["iid"]))
			var j4: ProductionJob = sim.production.get_job(jid)
			if j4 == null or j4.carried_units <= 0:
				a.carried = {}


func _display_with_room() -> int:
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		if sim.display.free_units(e.iid) > 0:
			return e.iid
	return -1


## Pilih resep & batch baru (GDD 3.2, 23.3-23.4, 23.7). {} bila tidak ada.
func _plan_new_job(sid: StringName, _def: StaffDefinition) -> Dictionary:
	var c: Dictionary = contract(sid)
	var in_flight: int = 0
	for j: ProductionJob in sim.production.sorted_jobs():
		in_flight += j.quantity_output if j.stage != ProductionJob.CARRIED_TO_DISPLAY else j.carried_units
	var free_display: int = sim.display.total_free_units() - in_flight
	if free_display <= 0:
		return {}
	var candidates: Array[RecipeDefinition] = []
	if str(c.get("mode", "auto")) == "target":
		var tr: RecipeDefinition = DataRegistry.recipe(StringName(str(c.get("target_recipe", ""))))
		if tr != null:
			candidates.append(tr)
	else:
		candidates = DataRegistry.recipes()
	var stock: Dictionary = sim.display.sellable_by_recipe()
	var best: RecipeDefinition = null
	var best_stock: int = 1 << 30
	for r: RecipeDefinition in candidates:
		# Cek bahan (murah) lebih dulu; hasilnya sama karena tanpa bahan resep
		# pasti diblokir make_block_reason.
		if not sim.inventory.has_for_recipe(r, 1):
			continue
		if sim.production.make_block_reason(r.id, 1) != "":
			continue
		if r.batch_yield > free_display:
			continue
		var s: int = int(stock.get(r.id, 0))
		if s < best_stock:
			best_stock = s
			best = r
	if best == null:
		return {}
	# Auto = batch terbesar yang muat; setting manual turun ke batch lebih kecil
	# bila bahan/rak tidak cukup (GDD 23.7).
	var options: Array[int] = [1]
	match int(c.get("batch", 0)):
		0, 5:
			options = [5, 3, 1]
		3:
			options = [3, 1]
	for b: int in options:
		if sim.inventory.has_for_recipe(best, b) and best.batch_yield * b <= free_display:
			return {"recipe": best.id, "batch": b}
	return {}


func capture() -> Dictionary:
	var cs: Dictionary = {}
	for k: Variant in contracts.keys():
		cs[String(k)] = (contracts[k] as Dictionary).duplicate()
	var acts: Dictionary = {}
	for k2: Variant in actors.keys():
		acts[String(k2)] = (actors[k2] as SimActor).to_dict()
	var ts: Dictionary = {}
	for k3: Variant in tasks.keys():
		var t: Dictionary = (tasks[k3] as Dictionary).duplicate()
		if t.has("recipe"):
			t["recipe"] = String(t["recipe"])
		ts[String(k3)] = t
	var la: Dictionary = {}
	for k4: Variant in lane_assign.keys():
		la[String(k4)] = String(lane_assign[k4])
	return {"contracts": cs, "actors": acts, "tasks": ts, "lane_assign": la,
		"wage_liability_today": wage_liability_today, "wage_lines_today": wage_lines_today.duplicate(true)}


func restore(d: Dictionary) -> void:
	new_game()
	var cs: Dictionary = d.get("contracts", {})
	for k: Variant in cs.keys():
		if DataRegistry.staff(StringName(str(k))) == null:
			GameLogger.error("SAVE", "quarantined unknown staff %s" % k)
			continue
		contracts[StringName(str(k))] = (cs[k] as Dictionary).duplicate()
	var acts: Dictionary = d.get("actors", {})
	for k2: Variant in acts.keys():
		var sid: StringName = StringName(str(k2))
		var def: StaffDefinition = DataRegistry.staff(sid)
		if def == null:
			continue
		var a := SimActor.new()
		a.id = sid
		a.kind = &"staff"
		a.nav_class = FloorGrid.NAV_STAFF
		a.speed_mps = def.movement_speed_mps
		a.visual_key = sid
		a.apply_dict(acts[k2])
		actors[sid] = a
	var la: Dictionary = d.get("lane_assign", {})
	for k3: Variant in la.keys():
		lane_assign[StringName(str(k3))] = StringName(str(la[k3]))
	wage_liability_today = float(d.get("wage_liability_today", 0.0))
	wage_lines_today = d.get("wage_lines_today", [])


## Setelah load: tugas dimulai ulang dari state produksi yang otoritatif.
func reconstruct() -> void:
	tasks.clear()
	for k: Variant in actors.keys():
		var a: SimActor = actors[k]
		a.stop()
		var c: Vector2i = sim.world.nearest_walkable(a.floor_id, a.cell(), FloorGrid.NAV_STAFF)
		if c.x >= 0:
			a.place_at(a.floor_id, c)
