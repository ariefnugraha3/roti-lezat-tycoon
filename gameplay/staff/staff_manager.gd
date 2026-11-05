class_name StaffManager
extends SimManager
## StaffManager — pemilik kontrak staf, aktor staf, dan tugas mereka
## (GDD idle 5.3-5.5; v3.1 3.1-3.5, 21.5, 23, 98).
##
## - Tanpa gaji dan tanpa tombol bertugas: staf dibayar sekali saat direkrut
##   (`staff.hire_cost[n]`, naik per orang ke-n) dan langsung bekerja.
## - Asisten Kasir menjaga satu jalur selain jalur A dan melayani otomatis;
##   saat jalurnya sepi ia mengemas pesanan RotiFood di mejanya (GDD idle 6.5).
## - Asisten Dapur mengerjakan rantai produksi seperti pemilik (KitchenBrain,
##   GDD idle 4.3) dan duduk di kursi koki saat menganggur (v3.1 5.1.4).
## - Level staf (UpgradeManager) mempercepat jalan dan aksinya.
## Roster tetap 5 kasir + 5 koki (v3.1 3.5) untuk nama, tampilan, dan bio.

## Jeda evaluasi ulang staf yang menganggur/terblokir (detik simulasi).
const RETHINK_SECONDS: float = 0.5

## staff_id -> {employed, hired_day}
var contracts: Dictionary = {}
## staff_id -> SimActor.
var actors: Dictionary = {}
var _ids_cache: Array = []
## staff_id -> tugas (KitchenBrain, atau {type: "sit", iid}).
var tasks: Dictionary = {}
## staff_id -> lane_id untuk kasir.
var lane_assign: Dictionary = {}
## Transien (tidak disimpan): kapan staf boleh mengevaluasi ulang tugas.
var _rethink_at: Dictionary = {}


func new_game() -> void:
	contracts.clear()
	actors.clear()
	tasks.clear()
	lane_assign.clear()
	_rethink_at.clear()
	_ids_cache = []


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


## Staf yang sedang berada di lantai: setiap staf yang direkrut (GDD idle 5.4).
func is_working(staff_id: StringName) -> bool:
	return actors.has(staff_id)


func working_ids(role: StringName = &"") -> Array[StringName]:
	var out: Array[StringName] = []
	for id: StringName in employed_ids(role):
		if actors.has(id):
			out.append(id)
	return out


func capacity(role: StringName) -> int:
	return sim.world.location.staff_capacity(role)


func hired_count() -> int:
	return employed_ids().size()


# ===========================================================================
# REKRUT (GDD idle 5.5)
# ===========================================================================

## Biaya merekrut orang berikutnya, atau -1 bila daftar biaya habis.
func next_hire_cost() -> float:
	var costs: Array = DataRegistry.idle("staff.hire_cost")
	var n: int = hired_count()
	return float(costs[n]) if n < costs.size() else -1.0


## &"" bila boleh direkrut sekarang; selain itu alasan.
func hire_block(staff_id: StringName) -> StringName:
	var def: StaffDefinition = DataRegistry.staff(staff_id)
	if def == null:
		return &"invalid"
	if is_employed(staff_id):
		return &"employed"
	if employed_ids(def.role_id).size() >= capacity(def.role_id):
		return &"full"
	var cost: float = next_hire_cost()
	if cost < 0.0:
		return &"full"
	if not sim.economy.can_afford(cost):
		return &"kr"
	return &""


## Rekrut dengan bayar sekali (STAFF_HIRE); staf langsung mulai bekerja.
## `free` = perk waralaba Asisten Dapur pertama (GDD idle 10.4).
func hire(staff_id: StringName, free: bool = false) -> StringName:
	var reason: StringName = hire_block(staff_id)
	if free and (reason == &"kr" or reason == &""):
		reason = &""
	if reason != &"":
		return reason
	if not free:
		sim.economy.spend(next_hire_cost(), &"STAFF_HIRE", staff_id, {})
	contracts[staff_id] = {"employed": true, "hired_day": sim.time.day}
	sim.statistics.add(&"staff_hired_count", 1)
	_spawn(staff_id)
	_assign_lanes()
	EventBus.staff_state_changed.emit(staff_id)
	SaveManager.request_autosave("staff_hire")
	return &""


## Batas staf lokasi (v3.1 6): kelebihan diberhentikan, yang terakhir direkrut
## lebih dulu. Hanya untuk data rusak; lokasi hanya pernah naik tier.
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
			_stop_working(ids[i])
			contracts.erase(ids[i])
	return out


## Kasir menjaga jalur selain jalur pemain, urut id (v3.1 21.2).
func _assign_lanes() -> void:
	lane_assign.clear()
	var cashiers: Array = Ids.sort(working_ids(&"cashier"))
	var lanes: Array[QueueLane] = sim.queue.staff_lanes()
	for i in mini(cashiers.size(), lanes.size()):
		var sid: StringName = StringName(str(cashiers[i]))
		lane_assign[sid] = lanes[i].id
		var a: SimActor = actors.get(sid)
		if a != null and a.cell() != lanes[i].cashier_point:
			a.go_to(sim.world, lanes[i].floor_id, lanes[i].cashier_point)


func _make_actor(staff_id: StringName) -> SimActor:
	var a := SimActor.new()
	a.id = staff_id
	a.kind = &"staff"
	a.nav_class = FloorGrid.NAV_STAFF
	a.speed_mps = DataRegistry.staff_speed_mps()
	a.visual_key = staff_id
	return a


## Staf baru muncul di depan Gudang (koki) atau di titik kasir jalurnya.
func _spawn(staff_id: StringName) -> void:
	var def: StaffDefinition = DataRegistry.staff(staff_id)
	var a: SimActor = _make_actor(staff_id)
	actors[staff_id] = a
	tasks.erase(staff_id)
	if def.is_baker():
		var storage: EquipmentInstance = sim.equipment.storage_instance()
		var acc: Dictionary = sim.world.access_of(storage.iid) if storage != null else {}
		if not acc.is_empty():
			a.place_at(acc["floor"], acc["cell"])
			return
	var lane: QueueLane = sim.queue.main_lane()
	a.place_at(lane.floor_id, lane.cashier_point)


func _stop_working(staff_id: StringName) -> void:
	var a: SimActor = actors.get(staff_id)
	if a != null:
		var t: Dictionary = tasks.get(staff_id, {})
		if not t.is_empty() and str(t["type"]) != "sit":
			KitchenBrain.abort(sim, staff_id, t)
		KitchenBrain.drop_carried(sim, a)
	sim.rotifood.release_packer(staff_id)
	sim.world.release_all_for(staff_id)
	actors.erase(staff_id)
	tasks.erase(staff_id)
	lane_assign.erase(staff_id)
	_assign_lanes()


# ===========================================================================
# KASIR (v3.1 21.2, 21.5)
# ===========================================================================

func cashier_for_lane(lane_id: StringName) -> StaffDefinition:
	for sid: Variant in lane_assign.keys():
		if StringName(str(lane_assign[sid])) == lane_id:
			return DataRegistry.staff(StringName(str(sid)))
	return null


func cashier_id_for_lane(lane_id: StringName) -> StringName:
	for sid: Variant in lane_assign.keys():
		if StringName(str(lane_assign[sid])) == lane_id:
			return StringName(str(sid))
	return &""


func any_cashier_working() -> bool:
	return not lane_assign.is_empty()


func cashier_at_post(lane_id: StringName) -> bool:
	var sid: StringName = cashier_id_for_lane(lane_id)
	if sid == &"":
		return false
	var a: SimActor = actors.get(sid)
	var lane: QueueLane = sim.queue.lane(lane_id)
	return a != null and lane != null and not a.has_route() and a.floor_id == lane.floor_id and a.cell() == lane.cashier_point


## Kasir di posnya tanpa pembeli di depan meja: boleh mengemas RotiFood.
func idle_cashier_lanes() -> Array[QueueLane]:
	var out: Array[QueueLane] = []
	for lane: QueueLane in sim.queue.staff_lanes():
		if cashier_at_post(lane.id) and lane.service_occupant == &"" and sim.cashier.transaction_for(lane.id).is_empty():
			out.append(lane)
	return out


# ===========================================================================
# KOKI
# ===========================================================================

func kitchen_staffed() -> bool:
	return not working_ids(&"baker").is_empty()


## Ringkasan untuk layar Staff: &"sitting", &"working", &"walking",
## &"serving", &"packing", atau &"" bila tidak bertugas.
func activity(staff_id: StringName) -> StringName:
	var a: SimActor = actors.get(staff_id)
	if a == null:
		return &""
	var def: StaffDefinition = DataRegistry.staff(staff_id)
	if def.is_cashier():
		if sim.rotifood.packer_order(staff_id) >= 0:
			return &"packing"
		return &"serving"
	if a.seat_iid >= 0:
		return &"sitting"
	var t: Dictionary = tasks.get(staff_id, {})
	if not t.is_empty() and str(t["type"]) != "sit":
		return &"working"
	return &"walking"


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	var walk: float = sim.upgrades.walk_mult()
	for k: Variant in _actor_ids():
		var sid: StringName = StringName(str(k))
		var a: SimActor = actors[sid]
		a.speed_mps = DataRegistry.staff_speed_mps() * sim.upgrades.staff_speed(sid) * walk
		a.step(dt, sim.world)
		var def: StaffDefinition = DataRegistry.staff(sid)
		if def.is_cashier():
			_cashier_step(sid, a)
		else:
			_baker_step(sid, a, dt)


func _cashier_step(sid: StringName, a: SimActor) -> void:
	var lane_id: Variant = lane_assign.get(sid)
	if lane_id == null or a.has_route() or not _may_rethink(sid):
		return
	var lane: QueueLane = sim.queue.lane(StringName(str(lane_id)))
	if a.cell() != lane.cashier_point:
		a.go_to(sim.world, lane.floor_id, lane.cashier_point)
		_defer_rethink(sid)
	else:
		a.facing = Vector2(lane.service_point - lane.cashier_point).normalized()
		a.state = &"SERVING_CASHIER"


## ID aktor staf terurut, disusun ulang hanya bila himpunannya berubah.
func _actor_ids() -> Array:
	var same: bool = _ids_cache.size() == actors.size()
	if same:
		for k: Variant in _ids_cache:
			if not actors.has(k):
				same = false
				break
	if not same:
		_ids_cache = Ids.sort(actors.keys())
	return _ids_cache


func _may_rethink(sid: StringName) -> bool:
	return sim.time.sim_seconds >= float(_rethink_at.get(sid, -1.0))


func _defer_rethink(sid: StringName) -> void:
	_rethink_at[sid] = sim.time.sim_seconds + RETHINK_SECONDS


func _interact_seconds(sid: StringName) -> float:
	return KitchenBrain.INTERACT_SECONDS / maxf(sim.upgrades.staff_speed(sid), 0.0001)


func _baker_step(sid: StringName, a: SimActor, dt: float) -> void:
	var task: Dictionary = tasks.get(sid, {})
	# Menuju kursi bisa disela pekerjaan yang baru muncul.
	if not task.is_empty() and str(task["type"]) == "sit" and a.has_route() and _may_rethink(sid):
		_defer_rethink(sid)
		var better: Dictionary = KitchenBrain.choose(sim, sid, a)
		if not better.is_empty():
			tasks.erase(sid)
			a.seat_iid = -1
			if _begin(sid, a, better):
				task = tasks[sid]
			else:
				task = {}
	if task.is_empty():
		if not _may_rethink(sid):
			return
		_defer_rethink(sid)
		var next: Dictionary = KitchenBrain.choose(sim, sid, a)
		if next.is_empty():
			if a.seat_iid < 0:
				_go_sit(sid, a)
			return
		a.seat_iid = -1
		if not _begin(sid, a, next):
			return
		task = tasks[sid]
	if a.has_route():
		return
	task["wait"] = float(task.get("wait", 0.0)) - dt
	if float(task["wait"]) > 0.0:
		a.state = &"INTERACTING"
		return
	tasks.erase(sid)
	if str(task["type"]) == "sit":
		var chair: EquipmentInstance = sim.equipment.get_inst(int(task["iid"]))
		if chair != null and chair.placed:
			_sit(sid, a, chair)
		return
	var follow: Dictionary = KitchenBrain.finish(sim, sid, a, task)
	if not follow.is_empty():
		_begin(sid, a, follow)
	else:
		_defer_rethink(sid)


func _begin(sid: StringName, a: SimActor, task: Dictionary) -> bool:
	if not KitchenBrain.begin(sim, sid, a, task, _interact_seconds(sid)):
		a.state = &"BLOCKED"
		_defer_rethink(sid)
		return false
	tasks[sid] = task
	return true


# ===========================================================================
# KURSI KOKI (v3.1 5.1.4)
# ===========================================================================

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
		var seat: Vector2 = GridMath.cell_center(chair.anchor)
		var to: Vector2 = GridMath.cell_center(acc["cell"]) - seat
		if to.length_squared() > 0.0001:
			a.facing = to.normalized()


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


## Upgrade lokasi: jalur kasir dibangun ulang; staf ditempatkan ulang.
func on_location_changed() -> void:
	for k: Variant in Ids.sort(actors.keys()):
		var sid: StringName = StringName(str(k))
		var a: SimActor = actors[sid]
		var t: Dictionary = tasks.get(sid, {})
		if not t.is_empty() and str(t["type"]) != "sit":
			KitchenBrain.abort(sim, sid, t)
		KitchenBrain.drop_carried(sim, a)
		tasks.erase(sid)
		a.seat_iid = -1
		_spawn(sid)
	_assign_lanes()
	for sid2: Variant in lane_assign.keys():
		var lane: QueueLane = sim.queue.lane(StringName(str(lane_assign[sid2])))
		var a2: SimActor = actors.get(StringName(str(sid2)))
		if a2 != null and lane != null:
			a2.place_at(lane.floor_id, lane.cashier_point)


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
	return {"contracts": cs, "actors": acts}


func restore(d: Dictionary) -> void:
	new_game()
	var cs: Dictionary = d.get("contracts", {})
	for k: Variant in cs.keys():
		if DataRegistry.staff(StringName(str(k))) == null:
			GameLogger.error("SAVE", "quarantined unknown staff %s" % k)
			continue
		contracts[StringName(str(k))] = {"employed": true, "hired_day": int((cs[k] as Dictionary).get("hired_day", 1))}
	var acts: Dictionary = d.get("actors", {})
	for sid: StringName in employed_ids():
		var a: SimActor = _make_actor(sid)
		if acts.has(String(sid)):
			a.apply_dict(acts[String(sid)])
		actors[sid] = a


## Setelah load: tugas dimulai ulang dari state produksi yang otoritatif, kasir
## kembali ke jalurnya, dan barang di tangan tetap dibawa bila job-nya masih ada.
func reconstruct() -> void:
	tasks.clear()
	for k: Variant in actors.keys():
		var a: SimActor = actors[k]
		a.stop()
		var c: Vector2i = sim.world.nearest_walkable(a.floor_id, a.cell(), FloorGrid.NAV_STAFF)
		if c.x >= 0:
			a.place_at(a.floor_id, c)
		var j: ProductionJob = sim.production.get_job(int(a.carried.get("job_id", -1))) if not a.carried.is_empty() else null
		if j == null or j.carrier_id != a.id:
			a.carried = {}
	on_layout_changed()
	_assign_lanes()
