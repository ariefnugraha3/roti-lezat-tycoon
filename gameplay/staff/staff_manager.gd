class_name StaffManager
extends SimManager
## StaffManager — pemilik kontrak & status tugas staf dan otomasi mereka
## (GDD 3.1-3.5, 21.5, 23, 49, 87, 98).
##
## Keputusan maintainer 2026-10-02: staf setara, tanpa tier maupun kemampuan
## khusus. Gaji harian ditetapkan tier lokasi, sama untuk kasir dan koki.
## - Kasir menjaga jalurnya sendiri (jalur selain jalur pemain) dan melayani
##   pembeli otomatis. Pesanan RotiFood tetap dikemas pemain.
## - Koki hanya membuat resep yang dipesan pemain ("Ask a Baker" di Buku Resep).
##   Job pesanan itu milik dapur (KITCHEN_ID), jadi koki mana pun yang bertugas
##   mengerjakan langkah berikutnya. Koki yang menganggur melanjutkan langkah
##   pemain yang alatnya sudah selesai: adonan dari mixer ke oven, loyang dari
##   oven ke rak (Meja Tunggu bila semua rak penuh). Ketukan pemain pada alat itu
##   membuat koki mundur; membatalkan ketukan itu membuatnya kembali.
## - Koki yang tidak punya pekerjaan duduk di kursinya (GDD 5.1.4).
##
## Roster tetap: kandidat sama selalu tersedia, tanpa XP, tanpa biaya rekrut.
## Gaji hari itu dikunci pukul 05:00 untuk semua staf on_duty (DailyWageLiability).

const INTERACT_SECONDS: float = 0.3
## Jeda evaluasi ulang staf yang menganggur/terblokir (detik simulasi).
const RETHINK_SECONDS: float = 0.5
## Pemilik job pesanan "Ask a Baker": dikerjakan koki mana pun yang bertugas.
const KITCHEN_ID: StringName = &"kitchen"
## Langkah job yang diklaim koki saat menuju alatnya.
const CLAIM_TASKS: Array[String] = ["start_mixing", "pickup_dough", "pickup_tray"]

## staff_id -> {employed, on_duty, working, hired_day, batches_today}
var contracts: Dictionary = {}
## staff_id -> SimActor (hanya staf yang sedang bekerja).
var actors: Dictionary = {}
## staff_id -> task {type, job_id, iid, wait}
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
	_rethink_at.clear()
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


## Sedang bertugas saat ini (terjadwal hari ini dan berada di lantai).
func is_working(staff_id: StringName) -> bool:
	return bool(contract(staff_id).get("working", false)) and actors.has(staff_id)


func working_ids(role: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in employed_ids(role):
		if bool(contract(id).get("working", false)):
			out.append(id)
	return out


func capacity(role: StringName) -> int:
	return sim.world.location.staff_capacity(role)


## Gaji harian satu staf di lokasi sekarang, kasir maupun koki (GDD 3.3, 87).
func daily_wage() -> float:
	return sim.world.location.staff_daily_wage_kr


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
		"hired_day": sim.time.day, "batches_today": 0}
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


func scheduled_wages() -> float:
	var n: int = 0
	for id: StringName in employed_ids():
		if bool(contract(id)["on_duty"]):
			n += 1
	return float(n) * daily_wage()


## Aturan keluar Mode Solo (GDD 49.3): saldo >= gaji terjadwal + batch termurah.
func can_afford_schedule_with(extra_id: StringName) -> bool:
	var wages: float = scheduled_wages()
	if not bool(contract(extra_id).get("on_duty", false)):
		wages += daily_wage()
	return sim.economy.balance >= wages + sim.bailout.cheapest_producible_batch_cost()


func projected_cash_after_wages() -> float:
	return sim.economy.balance - scheduled_wages()


## Save lama dari sebelum batas baru (keputusan maintainer 2026-10-02) bisa
## mempekerjakan lebih banyak staf dari batas lokasi. Yang paling baru direkrut
## diberhentikan, tanpa biaya; mengembalikan nama yang diberhentikan.
func enforce_capacity() -> Array[String]:
	var out: Array[String] = []
	for role: StringName in [&"cashier", &"baker"]:
		var ids: Array[StringName] = employed_ids(role)
		if ids.size() <= capacity(role):
			continue
		ids.sort_custom(func(a: StringName, b: StringName) -> bool:
			var da: int = int(contract(a).get("hired_day", 0))
			var db: int = int(contract(b).get("hired_day", 0))
			if da != db:
				return da < db
			return String(a) < String(b))
		for i in range(capacity(role), ids.size()):
			out.append(DataRegistry.staff(ids[i]).display_name)
			# Tanpa autosave: dipanggil di tengah load (SimulationRoot.load_from_save).
			_stop_working(ids[i])
			contracts.erase(ids[i])
	return out


# ===========================================================================
# HARI KERJA (GDD 87.2, 87.3)
# ===========================================================================

## 05:00: liabilitas gaji dikunci, staf on_duty mulai bekerja.
func begin_day() -> void:
	wage_liability_today = 0.0
	wage_lines_today.clear()
	lane_assign.clear()
	var wage: float = daily_wage()
	for id: StringName in employed_ids():
		var c: Dictionary = contract(id)
		c["batches_today"] = 0
		c["working"] = bool(c["on_duty"])
		if bool(c["working"]):
			wage_liability_today += wage
			wage_lines_today.append({"staff_id": String(id), "wage": wage})
			_spawn(id)
	_assign_lanes(true)
	if working_ids(&"baker").is_empty():
		_hand_kitchen_to_player()


## Kasir menjaga jalur selain jalur pemain, urut id (GDD 21.2). `snap`: pukul
## 05:00 kasir langsung muncul di posnya; sesudahnya ia berjalan ke sana.
func _assign_lanes(snap: bool = false) -> void:
	lane_assign.clear()
	var cashiers: Array = Ids.sort(working_ids(&"cashier"))
	var lanes: Array[QueueLane] = sim.queue.staff_lanes()
	for i in mini(cashiers.size(), lanes.size()):
		var sid: StringName = StringName(str(cashiers[i]))
		lane_assign[sid] = lanes[i].id
		var a: SimActor = actors.get(sid)
		if a == null:
			continue
		if snap:
			a.place_at(lanes[i].floor_id, lanes[i].cashier_point)
			a.facing = Vector2(lanes[i].service_point - lanes[i].cashier_point).normalized()
		else:
			a.go_to(sim.world, lanes[i].floor_id, lanes[i].cashier_point)


func _spawn(staff_id: StringName) -> void:
	var def: StaffDefinition = DataRegistry.staff(staff_id)
	var a := SimActor.new()
	a.id = staff_id
	a.kind = &"staff"
	a.nav_class = FloorGrid.NAV_STAFF
	a.speed_mps = DataRegistry.staff_speed_mps()
	a.visual_key = staff_id
	actors[staff_id] = a
	tasks.erase(staff_id)
	if def.is_baker():
		# Koki memulai hari duduk di kursinya (GDD 5.1.4).
		var chair: EquipmentInstance = _free_chair(staff_id)
		var acc: Dictionary = sim.world.access_of(chair.iid) if chair != null else {}
		if not acc.is_empty():
			a.place_at(acc["floor"], acc["cell"])
			_sit(staff_id, a, chair)
			return
		var storage: EquipmentInstance = sim.equipment.storage_instance()
		var acc2: Dictionary = sim.world.access_of(storage.iid) if storage != null else {}
		if not acc2.is_empty():
			a.place_at(acc2["floor"], acc2["cell"])
			return
	var lane: QueueLane = sim.queue.main_lane()
	a.place_at(lane.floor_id, lane.cashier_point)


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
	if working_ids(&"baker").is_empty():
		_hand_kitchen_to_player()


func _release_claims(staff_id: StringName) -> void:
	for j: ProductionJob in sim.production.sorted_jobs():
		if j.claimed_by == staff_id:
			j.claimed_by = &""


## Tidak ada lagi koki yang bertugas (dipecat, libur, Mode Solo, atau tidak ada
## yang terjadwal pagi ini): job pesanan dapur berpindah ke pemain dan tanda "!"
## muncul di alatnya, supaya tidak ada job yatim (GDD 87.2, 105 no.11).
func _hand_kitchen_to_player() -> void:
	for j: ProductionJob in sim.production.sorted_jobs():
		if j.owner_actor_id == KITCHEN_ID:
			j.owner_actor_id = PlayerTaskManager.PLAYER_ID
			j.claimed_by = &""
			if j.is_waiting_oven_pickup():
				sim.alerts.raise_oven(j.oven_id, &"ready")


## Serah terima atomik saat staf berhenti (GDD 87.2, 104): loyang ke rak, adonan
## kembali ke mixer bebas. Yang tidak muat (rak penuh, tidak ada mixer bebas)
## diparkir di Meja Tunggu (GDD 5.1.3), supaya tidak ada job yatim yang menahan
## upgrade lokasi (GDD 105 no.11).
func _drop_carried(_staff_id: StringName, a: SimActor) -> void:
	if a.carried.is_empty():
		return
	var j: ProductionJob = sim.production.get_job(int(a.carried.get("job_id", -1)))
	if j != null:
		if j.stage == ProductionJob.CARRIED_TO_DISPLAY:
			sim.production.auto_place_tray(j.job_id, -1)
			var rest: ProductionJob = sim.production.get_job(j.job_id)
			if rest != null and rest.carried_units > 0:
				sim.production.put_on_table(rest.job_id)
		elif j.stage == ProductionJob.CARRIED_TO_OVEN:
			var mixer: EquipmentInstance = sim.production.free_mixer_for(j.recipe())
			if mixer != null:
				mixer.job_id = j.job_id
				j.mixer_id = mixer.iid
				j.stage = ProductionJob.MIX_DONE_WAITING_PICKUP
				j.carrier_id = &""
			else:
				sim.production.put_on_table(j.job_id)
	a.carried = {}


## 18:00: staf berhenti mengambil tugas, menyelesaikan serah terima, lalu pulang.
## Job pesanan dapur yang belum selesai menunggu koki keesokan paginya.
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


# ===========================================================================
# KASIR (GDD 21.2, 21.5)
# ===========================================================================

func cashier_for_lane(lane_id: StringName) -> StaffDefinition:
	for sid: Variant in lane_assign.keys():
		if StringName(str(lane_assign[sid])) == lane_id:
			return DataRegistry.staff(StringName(str(sid)))
	return null


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
# KOKI: PESANAN "ASK A BAKER" (GDD 3.2, 23.3)
# ===========================================================================

func kitchen_staffed() -> bool:
	return not working_ids(&"baker").is_empty()


## "" bila koki boleh disuruh membuat resep ini sekarang; selain itu kunci alasan.
func ask_block_reason(recipe_id: StringName, batch: int) -> String:
	if not kitchen_staffed():
		return "ui_recipe_no_baker"
	return sim.production.make_block_reason(recipe_id, batch)


## Buku Resep, tombol "Ask a Baker": bahan dipotong sekarang dan mixer
## ditetapkan seperti pesanan pemain, tetapi job-nya milik dapur sehingga koki
## yang mengerjakan semua langkahnya.
func order_recipe(recipe_id: StringName, batch: int) -> String:
	var reason: String = ask_block_reason(recipe_id, batch)
	if reason != "":
		return reason
	var j: ProductionJob = sim.production.create_job(recipe_id, batch, KITCHEN_ID)
	if j == null:
		return "ui_recipe_cannot_make"
	EventBus.staff_state_changed.emit(&"")
	return ""


## Job ini dijamin diurus koki: pesanan dapur selama ada koki bertugas, atau
## langkah yang sedang dituju seorang koki.
func handles(j: ProductionJob) -> bool:
	if j == null:
		return false
	if j.claimed_by != &"" and actors.has(j.claimed_by):
		return true
	return j.owner_actor_id == KITCHEN_ID and kitchen_staffed()


## Koki yang sedang menuju atau mengerjakan alat `iid` (kosong bila tidak ada).
func baker_heading_to(iid: int) -> StringName:
	for k: Variant in tasks.keys():
		var t: Dictionary = tasks[k]
		if int(t.get("iid", -1)) == iid and CLAIM_TASKS.has(str(t["type"])):
			return StringName(str(k))
	return &""


## Ringkasan pekerjaan koki untuk layar Staff: &"sitting", &"working",
## &"walking" (menuju kursi), atau &"" bila tidak bertugas.
func activity(staff_id: StringName) -> StringName:
	var a: SimActor = actors.get(staff_id)
	if a == null:
		return &""
	if a.seat_iid >= 0:
		return &"sitting"
	var t: Dictionary = tasks.get(staff_id, {})
	if not t.is_empty() and str(t["type"]) != "sit":
		return &"working"
	return &"walking"


# ===========================================================================
# TICK: gerak kasir & koki (GDD 23)
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
	var ids: Array = Ids.sort(actors.keys())
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
					a.facing = Vector2(lane.service_point - lane.cashier_point).normalized()
		else:
			_baker_step(sid, a, dt)


## Staf yang menganggur/terblokir/salah posisi tidak menghitung ulang rute dan
## rencana setiap tick; cukup tiap RETHINK_SECONDS simulasi (performa, GDD 109).
func _may_rethink(sid: StringName) -> bool:
	return sim.time.sim_seconds >= float(_rethink_at.get(sid, -1.0))


func _defer_rethink(sid: StringName) -> void:
	_rethink_at[sid] = sim.time.sim_seconds + RETHINK_SECONDS


func _baker_step(sid: StringName, a: SimActor, dt: float) -> void:
	var task: Dictionary = tasks.get(sid, {})
	# Ketukan pemain pada alat yang dituju menang: koki mundur ke kursinya
	# (GDD 23.3, keputusan maintainer 2026-10-02).
	if not task.is_empty() and CLAIM_TASKS.has(str(task["type"])) and sim.player.has_command_for(int(task["iid"])):
		_abort(sid, a, task)
		task = {}
	# Menuju kursi bisa disela pekerjaan yang baru muncul.
	if not task.is_empty() and str(task["type"]) == "sit" and a.has_route() and _may_rethink(sid):
		var better: Dictionary = _choose_task(sid, a)
		_defer_rethink(sid)
		if not better.is_empty():
			_release_seat(sid, a)
			task = _begin(sid, a, better)
	if task.is_empty():
		if not _may_rethink(sid):
			return
		_defer_rethink(sid)
		var next: Dictionary = _choose_task(sid, a)
		if next.is_empty():
			if a.seat_iid < 0:
				_go_sit(sid, a)
			return
		_release_seat(sid, a)
		task = _begin(sid, a, next)
		if task.is_empty():
			return
	if a.has_route():
		return
	task["wait"] = float(task.get("wait", INTERACT_SECONDS)) - dt
	if float(task["wait"]) > 0.0:
		a.state = &"INTERACTING"
		return
	tasks.erase(sid)
	_finish_task(sid, a, task)


## Mulai tugas: klaim langkah job-nya, lalu berjalan ke tile akses alat.
func _begin(sid: StringName, a: SimActor, task: Dictionary) -> Dictionary:
	var j: ProductionJob = sim.production.get_job(int(task.get("job_id", -1)))
	if j != null and CLAIM_TASKS.has(str(task["type"])):
		j.claimed_by = sid
	var acc: Dictionary = sim.world.access_of(int(task["iid"]))
	task["wait"] = INTERACT_SECONDS
	if acc.is_empty() or not a.go_to(sim.world, acc["floor"], acc["cell"]):
		sim.alerts.raise_staff_blocked(sid, a.floor_id)
		_release_task_claim(sid, task)
		a.state = &"BLOCKED"
		return {}
	tasks[sid] = task
	a.state = &"WALKING"
	return task


func _abort(sid: StringName, a: SimActor, task: Dictionary) -> void:
	_release_task_claim(sid, task)
	tasks.erase(sid)
	a.stop()
	a.state = &"IDLE"
	_defer_rethink(sid)


func _release_task_claim(sid: StringName, task: Dictionary) -> void:
	var j: ProductionJob = sim.production.get_job(int(task.get("job_id", -1)))
	if j != null and j.claimed_by == sid:
		j.claimed_by = &""


## Prioritas koki (GDD 23.3): barang bawaan, lalu langkah pesanan dapur (loyang,
## adonan, mulai aduk), lalu inisiatif pada langkah pemain yang alatnya sudah
## selesai (loyang, adonan). Alat yang sedang dituju perintah pemain dilewati.
func _choose_task(sid: StringName, a: SimActor) -> Dictionary:
	if not a.carried.is_empty():
		return _deliver_task(a)
	var jobs: Array[ProductionJob] = sim.production.sorted_jobs()
	for kitchen: bool in [true, false]:
		for j: ProductionJob in jobs:
			if (j.owner_actor_id == KITCHEN_ID) != kitchen or not _free_for(j, sid):
				continue
			if j.is_waiting_oven_pickup() and (kitchen or j.stage != ProductionJob.BURNT) \
					and not sim.player.has_command_for(j.oven_id):
				return {"type": "pickup_tray", "job_id": j.job_id, "iid": j.oven_id}
		for j2: ProductionJob in jobs:
			if (j2.owner_actor_id == KITCHEN_ID) != kitchen or not _free_for(j2, sid):
				continue
			if j2.stage == ProductionJob.MIX_DONE_WAITING_PICKUP and sim.production.free_oven_for(j2.recipe()) != null \
					and not sim.player.has_command_for(j2.mixer_id):
				return {"type": "pickup_dough", "job_id": j2.job_id, "iid": j2.mixer_id}
		if kitchen:
			for j3: ProductionJob in jobs:
				if j3.owner_actor_id == KITCHEN_ID and j3.stage == ProductionJob.ORDERED and _free_for(j3, sid) \
						and not sim.player.has_command_for(j3.mixer_id):
					return {"type": "start_mixing", "job_id": j3.job_id, "iid": j3.mixer_id}
	return {}


## Langkah job ini belum dituju koki lain dan tidak sedang dibawa siapa pun.
func _free_for(j: ProductionJob, sid: StringName) -> bool:
	return (j.claimed_by == &"" or j.claimed_by == sid) and j.carrier_id == &""


## Antar barang bawaan: adonan ke oven yang bisa menerimanya, loyang ke rak yang
## masih muat. Tanpa tujuan, barang diparkir di Meja Tunggu (GDD 5.1.3).
func _deliver_task(a: SimActor) -> Dictionary:
	var j: ProductionJob = sim.production.get_job(int(a.carried.get("job_id", -1)))
	if j == null:
		a.carried = {}
		return {}
	var table: EquipmentInstance = sim.equipment.table_instance()
	var table_iid: int = table.iid if table != null and table.placed else -1
	if j.stage == ProductionJob.CARRIED_TO_OVEN:
		var oven: EquipmentInstance = sim.production.free_oven_for(j.recipe())
		if oven != null:
			return {"type": "insert_oven", "job_id": j.job_id, "iid": oven.iid}
	elif j.stage == ProductionJob.CARRIED_TO_DISPLAY:
		var disp: int = _display_with_room(j.recipe_id)
		if disp >= 0:
			return {"type": "place_display", "job_id": j.job_id, "iid": disp}
	else:
		a.carried = {}
		return {}
	if table_iid >= 0:
		return {"type": "put_table", "job_id": j.job_id, "iid": table_iid}
	return {}


func _finish_task(sid: StringName, a: SimActor, task: Dictionary) -> void:
	var jid: int = int(task.get("job_id", -1))
	a.state = &"IDLE"
	match str(task["type"]):
		"start_mixing":
			sim.production.start_mixing(jid, sid, 1.0)
			_release_task_claim(sid, task)
		"pickup_dough":
			if sim.production.pickup_dough(jid, sid):
				var j: ProductionJob = sim.production.get_job(jid)
				a.carried = {"type": "dough", "job_id": jid, "recipe_id": String(j.recipe_id)}
			_release_task_claim(sid, task)
		"insert_oven":
			if sim.production.insert_oven(jid, int(task["iid"]), sid, 1.0):
				a.carried = {}
		"pickup_tray":
			var r: Dictionary = sim.production.pickup_tray(jid, sid)
			if bool(r.get("ok", false)):
				sim.alerts.clear_oven(int(task["iid"]))
				if not bool(r.get("burnt", false)):
					var j2: ProductionJob = sim.production.get_job(jid)
					a.carried = {"type": "tray", "job_id": jid, "recipe_id": String(j2.recipe_id)}
			_release_task_claim(sid, task)
		"place_display":
			_place_on(jid, int(task["iid"]))
			if sim.production.get_job(jid) == null:
				a.carried = {}
				_note_batch(sid)
		"put_table":
			if sim.production.put_on_table(jid):
				a.carried = {}
		"sit":
			var chair: EquipmentInstance = sim.equipment.get_inst(int(task["iid"]))
			if chair != null and chair.placed:
				_sit(sid, a, chair)
	_defer_rethink(sid)


func _note_batch(sid: StringName) -> void:
	var c: Dictionary = contract(sid)
	if not c.is_empty():
		c["batches_today"] = int(c.get("batches_today", 0)) + 1


## Rak terpasang pertama yang masih bisa menerima resep ini (GDD 19.3).
func _display_with_room(recipe_id: StringName) -> int:
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		if _room_on(e.iid, recipe_id) > 0:
			return e.iid
	return -1


func _room_on(iid: int, recipe_id: StringName) -> int:
	var n: int = 0
	for i in sim.display.slots(iid).size():
		n += sim.display.slot_room(iid, i, recipe_id)
	return n


## Koki menata loyang di rak yang ia datangi: petak berisi resep yang sama
## lebih dulu, lalu petak kosong (GDD 23.3). Sisa yang tidak muat tetap dibawa.
func _place_on(job_id: int, iid: int) -> void:
	var j: ProductionJob = sim.production.get_job(job_id)
	if j == null or j.stage != ProductionJob.CARRIED_TO_DISPLAY:
		return
	var recipe: StringName = j.recipe_id
	for pass_i in 2:
		for i in sim.display.slots(iid).size():
			j = sim.production.get_job(job_id)
			if j == null:
				return
			var units: int = sim.display.slot_units(iid, i)
			var same: bool = units > 0 and (sim.display.slots(iid)[i] as Dictionary)["recipe"] == recipe
			if (pass_i == 0 and same) or (pass_i == 1 and units == 0):
				sim.production.place_from_tray(job_id, iid, i, j.carried_units)


# ===========================================================================
# KURSI KOKI (GDD 5.1.4)
# ===========================================================================

## Kursi yang belum ditempati koki lain; kursi yang sedang ia duduki atau tuju
## lebih dulu.
func _free_chair(sid: StringName) -> EquipmentInstance:
	var taken: Dictionary = {}
	for k: Variant in actors.keys():
		if StringName(str(k)) == sid:
			continue
		var other: SimActor = actors[k]
		if other.seat_iid >= 0:
			taken[other.seat_iid] = true
		var t: Dictionary = tasks.get(StringName(str(k)), {})
		if not t.is_empty() and str(t["type"]) == "sit":
			taken[int(t["iid"])] = true
	for e: EquipmentInstance in sim.equipment.placed_list(&"chair"):
		if not taken.has(e.iid) and not sim.world.access_of(e.iid).is_empty():
			return e
	return null


func _go_sit(sid: StringName, a: SimActor) -> void:
	var chair: EquipmentInstance = _free_chair(sid)
	if chair == null:
		a.state = &"IDLE"
		return
	var acc: Dictionary = sim.world.access_of(chair.iid)
	if a.floor_id == acc["floor"] and a.cell() == acc["cell"] and not a.has_route():
		_sit(sid, a, chair)
		return
	if a.go_to(sim.world, acc["floor"], acc["cell"]):
		tasks[sid] = {"type": "sit", "iid": chair.iid, "wait": 0.0}
		a.state = &"WALKING"
	else:
		a.state = &"IDLE"


func _sit(_sid: StringName, a: SimActor, chair: EquipmentInstance) -> void:
	var acc: Dictionary = sim.world.access_of(chair.iid)
	a.seat_iid = chair.iid
	a.state = &"SITTING"
	if not acc.is_empty():
		# Duduk membelakangi sandaran, menghadap tile akses kursi.
		var seat: Vector2 = GridMath.cell_center(chair.anchor)
		var to: Vector2 = GridMath.cell_center(acc["cell"]) - seat
		if to.length_squared() > 0.0001:
			a.facing = to.normalized()


func _release_seat(_sid: StringName, a: SimActor) -> void:
	a.seat_iid = -1


## Kursi dipindah di Mode Dekorasi atau dihapus: koki yang duduk di sana berdiri.
func on_layout_changed() -> void:
	for k: Variant in actors.keys():
		var a: SimActor = actors[k]
		if a.seat_iid < 0:
			continue
		var chair: EquipmentInstance = sim.equipment.get_inst(a.seat_iid)
		var acc: Dictionary = sim.world.access_of(a.seat_iid) if chair != null and chair.placed else {}
		if acc.is_empty() or a.floor_id != acc["floor"] or a.cell() != acc["cell"]:
			a.seat_iid = -1
			a.state = &"IDLE"


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	var cs: Dictionary = {}
	for k: Variant in contracts.keys():
		cs[String(k)] = (contracts[k] as Dictionary).duplicate()
	var acts: Dictionary = {}
	for k2: Variant in actors.keys():
		acts[String(k2)] = (actors[k2] as SimActor).to_dict()
	var ts: Dictionary = {}
	for k3: Variant in tasks.keys():
		ts[String(k3)] = (tasks[k3] as Dictionary).duplicate()
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
		var c: Dictionary = (cs[k] as Dictionary).duplicate()
		# Pengaturan kerja koki lama (mode, resep target, batch) sudah tidak ada.
		for old: String in ["mode", "target_recipe", "batch"]:
			c.erase(old)
		contracts[StringName(str(k))] = c
	var acts: Dictionary = d.get("actors", {})
	for k2: Variant in acts.keys():
		var sid: StringName = StringName(str(k2))
		if DataRegistry.staff(sid) == null or not contracts.has(sid):
			continue
		var a := SimActor.new()
		a.id = sid
		a.kind = &"staff"
		a.nav_class = FloorGrid.NAV_STAFF
		a.speed_mps = DataRegistry.staff_speed_mps()
		a.visual_key = sid
		a.apply_dict(acts[k2])
		actors[sid] = a
	var la: Dictionary = d.get("lane_assign", {})
	for k3: Variant in la.keys():
		lane_assign[StringName(str(k3))] = StringName(str(la[k3]))
	wage_liability_today = float(d.get("wage_liability_today", 0.0))
	wage_lines_today = d.get("wage_lines_today", [])


## Setelah load: tugas dimulai ulang dari state produksi yang otoritatif, kasir
## kembali ke jalur staf menurut template sekarang, dan klaim lama dilepas.
func reconstruct() -> void:
	tasks.clear()
	for j: ProductionJob in sim.production.sorted_jobs():
		if j.claimed_by != &"" and j.claimed_by != PlayerTaskManager.PLAYER_ID:
			j.claimed_by = &""
	for k: Variant in actors.keys():
		var a: SimActor = actors[k]
		a.stop()
		var c: Vector2i = sim.world.nearest_walkable(a.floor_id, a.cell(), FloorGrid.NAV_STAFF)
		if c.x >= 0:
			a.place_at(a.floor_id, c)
	on_layout_changed()
	if sim.time.is_running_phase():
		_assign_lanes()
		if working_ids(&"baker").is_empty():
			_hand_kitchen_to_player()
