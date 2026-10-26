class_name KitchenBrain
extends RefCounted
## KitchenBrain — pemilihan dan pelaksanaan pekerjaan dapur yang sama untuk
## pemilik dan Asisten Dapur (GDD idle 4.3, 5.1, 5.3). Tidak menyimpan state:
## tugas setiap pekerja disimpan manajer pemiliknya (PlayerTaskManager untuk
## pemilik, StaffManager untuk koki).
##
## Prioritas (GDD idle 4.3): barang di tangan diantar dulu; lalu (1) angkat
## loyang dari oven yang selesai, (2) pindahkan adonan dari mixer ke oven bebas,
## (3) ambil barang Meja Tunggu yang tujuannya sudah ada, (4) mulai batch baru
## untuk petak dengan rasio isi terendah.
##
## Tugas = {type, job_id, iid, wait}. Jenis: fetch (ambil bahan di Gudang, lalu
## start_mixing), start_mixing, pickup_dough, insert_oven, pickup_tray,
## place_display, put_table, take_table.

const INTERACT_SECONDS: float = 0.3
## Langkah yang mengklaim job selama pekerja berjalan ke alatnya.
const CLAIM_TASKS: Array[String] = ["fetch", "start_mixing", "pickup_dough", "pickup_tray", "take_table"]


# ===========================================================================
# PILIH
# ===========================================================================

## Tugas dapur berikutnya untuk pekerja `wid`, atau {} bila tidak ada. Dengan
## `focus_iid` >= 0 (ketukan arahan pemilik, GDD idle 5.1), tugas yang
## menyentuh alat itu didahulukan.
static func choose(sim: SimulationRoot, wid: StringName, actor: SimActor, focus_iid: int = -1) -> Dictionary:
	if not actor.carried.is_empty():
		return deliver_task(sim, actor)
	if focus_iid >= 0:
		var f: Dictionary = _choose(sim, wid, focus_iid)
		if not f.is_empty():
			return f
	return _choose(sim, wid, -1)


static func _choose(sim: SimulationRoot, wid: StringName, focus: int) -> Dictionary:
	var jobs: Array[ProductionJob] = sim.production.sorted_jobs()
	for j: ProductionJob in jobs:
		if j.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP and _free_for(j, wid) and (focus < 0 or j.oven_id == focus):
			return {"type": "pickup_tray", "job_id": j.job_id, "iid": j.oven_id}
	for j2: ProductionJob in jobs:
		if j2.stage != ProductionJob.MIX_DONE_WAITING_PICKUP or not _free_for(j2, wid):
			continue
		var oven: EquipmentInstance = sim.production.free_oven_for(j2.recipe(), j2.job_id)
		if oven == null:
			continue
		if focus >= 0 and j2.mixer_id != focus and oven.iid != focus:
			continue
		return {"type": "pickup_dough", "job_id": j2.job_id, "iid": j2.mixer_id, "oven": oven.iid}
	var table: EquipmentInstance = sim.equipment.table_instance()
	if table != null and table.placed and (focus < 0 or focus == table.iid):
		var t: ProductionJob = sim.production.table_pick(wid)
		if t != null:
			return {"type": "take_table", "job_id": t.job_id, "iid": table.iid}
	# Batch yang sudah dibayar tetapi ditinggal pekerjanya (mis. setelah load).
	for j3: ProductionJob in jobs:
		if j3.stage == ProductionJob.ORDERED and _free_for(j3, wid) and (focus < 0 or j3.mixer_id == focus):
			return {"type": "start_mixing", "job_id": j3.job_id, "iid": j3.mixer_id}
	var plan: Dictionary = plan_batch(sim, focus)
	if not plan.is_empty():
		var storage: EquipmentInstance = sim.equipment.storage_instance()
		var first: int = storage.iid if storage != null and storage.placed else int(plan["mixer"])
		plan["type"] = "fetch" if first != int(plan["mixer"]) else "start_mixing"
		plan["iid"] = first
		return plan
	return {}


## Langkah job ini belum dituju pekerja lain dan tidak sedang dibawa siapa pun.
static func _free_for(j: ProductionJob, wid: StringName) -> bool:
	return (j.claimed_by == &"" or j.claimed_by == wid) and j.carrier_id == &""


## Rencana batch baru (GDD idle 4.3): petak dengan rasio isi terendah (unit di
## rak + unit yang sedang dibuat untuknya), seri dipecah nilai jual per detik
## tertinggi lalu ID petak. Batch = kelipatan terbesar yang muat di sisa ruang
## petak dan bahannya terjangkau. {} bila tidak ada.
## Hasil: {recipe, batch, mixer, display, slot}.
static func plan_batch(sim: SimulationRoot, focus: int = -1) -> Dictionary:
	if not sim.production.can_create_job():
		return {}
	var mults: Array = DataRegistry.bal("production.batch_multipliers").duplicate()
	mults.sort()
	mults.reverse()
	var best: Dictionary = {}
	var best_key: Array = []
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		var cap: int = sim.display.slot_capacity(e.iid)
		if cap <= 0:
			continue
		for i in sim.display.slot_count(e.iid):
			var rid: StringName = sim.display.effective_recipe(e.iid, i)
			if rid == &"":
				continue
			var units: int = sim.display.slot_units(e.iid, i)
			if units > 0 and sim.display.slot_content(e.iid, i) != rid:
				continue
			var r: RecipeDefinition = DataRegistry.recipe(rid)
			var mixer: EquipmentInstance = sim.production.free_mixer_for(r)
			if mixer == null or (focus >= 0 and mixer.iid != focus and e.iid != focus):
				continue
			var inflight: int = sim.production.in_flight_units(e.iid, i)
			var room: int = cap - units - inflight
			var batch: int = 0
			for m: Variant in mults:
				if r.batch_yield * int(m) <= room and sim.economy.can_afford(ProductionManager.batch_cost(r, int(m))):
					batch = int(m)
					break
			if batch <= 0:
				continue
			var ratio: float = float(units + inflight) / float(cap)
			var key: Array = [ratio, -value_per_second(sim, r, e.iid), e.iid, i]
			if best.is_empty() or _key_less(key, best_key):
				best_key = key
				best = {"recipe": rid, "batch": batch, "mixer": mixer.iid, "display": e.iid, "slot": i}
	return best


## Nilai jual roti resep `r` per detik produksi (pemecah seri GDD idle 4.3).
static func value_per_second(sim: SimulationRoot, r: RecipeDefinition, display_iid: int) -> float:
	var secs: float = maxf(r.mix_duration_seconds + r.prep_duration_seconds + r.bake_duration_seconds, 0.001)
	return sim.unit_price(r.id, display_iid) * float(r.batch_yield) / secs


static func _key_less(a: Array, b: Array) -> bool:
	for i in a.size():
		if a[i] < b[i]:
			return true
		if a[i] > b[i]:
			return false
	return false


## Antar barang di tangan: adonan ke oven bebas, loyang ke rak yang punya petak
## untuknya, selain itu ke Meja Tunggu (GDD idle 4.7).
static func deliver_task(sim: SimulationRoot, actor: SimActor) -> Dictionary:
	var j: ProductionJob = sim.production.get_job(int(actor.carried.get("job_id", -1)))
	if j == null or j.carrier_id != actor.id:
		actor.carried = {}
		return {}
	if j.stage == ProductionJob.CARRIED_TO_OVEN:
		var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id) if j.oven_id >= 0 else null
		if oven == null or oven.job_id >= 0:
			oven = sim.production.free_oven_for(j.recipe(), j.job_id)
		if oven != null:
			sim.production.reserve_oven(j.job_id, oven.iid)
			return {"type": "insert_oven", "job_id": j.job_id, "iid": oven.iid}
	elif j.stage == ProductionJob.CARRIED_TO_DISPLAY:
		var disp: int = sim.production.delivery_display(j)
		if disp >= 0:
			return {"type": "place_display", "job_id": j.job_id, "iid": disp}
	else:
		actor.carried = {}
		return {}
	var table: EquipmentInstance = sim.equipment.table_instance()
	if table != null and table.placed:
		return {"type": "put_table", "job_id": j.job_id, "iid": table.iid}
	return {}


# ===========================================================================
# JALANKAN
# ===========================================================================

## Mulai tugas: batch baru dibuat (bahan dibayar, mixer dipesan) atau langkah
## job diklaim, lalu pekerja berjalan ke tile akses alat. false bila gagal.
static func begin(sim: SimulationRoot, wid: StringName, actor: SimActor, task: Dictionary, interact_seconds: float) -> bool:
	if task.has("recipe") and int(task.get("job_id", -1)) < 0:
		var mixer: EquipmentInstance = sim.equipment.get_inst(int(task["mixer"]))
		var j: ProductionJob = sim.production.create_job(StringName(str(task["recipe"])), int(task["batch"]), mixer,
			int(task["display"]), int(task["slot"]), wid)
		if j == null:
			return false
		task["job_id"] = j.job_id
	var job: ProductionJob = sim.production.get_job(int(task.get("job_id", -1)))
	if job != null and CLAIM_TASKS.has(str(task["type"])):
		job.claimed_by = wid
	if str(task["type"]) == "pickup_dough" and job != null:
		sim.production.reserve_oven(job.job_id, int(task["oven"]))
	task["wait"] = interact_seconds
	if not _route(sim, actor, int(task["iid"])):
		abort(sim, wid, task)
		return false
	actor.state = &"WALKING"
	return true


static func _route(sim: SimulationRoot, actor: SimActor, iid: int) -> bool:
	var acc: Dictionary = sim.world.access_of(iid)
	if acc.is_empty():
		return false
	return actor.go_to(sim.world, acc["floor"], acc["cell"])


## Lepas klaim tugas yang batal di tengah jalan. Batch yang sudah dibayar tetap
## ada (ORDERED) dan diambil pekerja berikutnya.
static func abort(sim: SimulationRoot, wid: StringName, task: Dictionary) -> void:
	var j: ProductionJob = sim.production.get_job(int(task.get("job_id", -1)))
	if j == null:
		return
	if j.claimed_by == wid:
		j.claimed_by = &""
	if str(task["type"]) == "pickup_dough" and j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP:
		sim.production.release_oven_reservation(j.job_id)


## Pekerja tiba dan selesai berinteraksi: lakukan aksinya. Mengembalikan tugas
## lanjutan (mis. antar adonan ke oven), atau {}.
static func finish(sim: SimulationRoot, wid: StringName, actor: SimActor, task: Dictionary) -> Dictionary:
	var jid: int = int(task.get("job_id", -1))
	var j: ProductionJob = sim.production.get_job(jid)
	actor.state = &"IDLE"
	match str(task["type"]):
		"fetch":
			if j != null and j.stage == ProductionJob.ORDERED:
				EventBus.sfx.emit(&"storage_open", actor.floor_id)
				return {"type": "start_mixing", "job_id": jid, "iid": j.mixer_id}
		"start_mixing":
			if j != null and j.stage == ProductionJob.ORDERED:
				sim.production.start_mixing(jid, wid)
		"pickup_dough":
			var oven_iid: int = j.oven_id if j != null else -1
			if j != null and sim.production.pickup_dough(jid, wid):
				actor.carried = {"type": "dough", "job_id": jid, "recipe_id": String(j.recipe_id)}
				var oven: EquipmentInstance = sim.equipment.get_inst(oven_iid)
				if oven != null and oven.job_id < 0:
					return {"type": "insert_oven", "job_id": jid, "iid": oven_iid}
				return deliver_task(sim, actor)
			abort(sim, wid, task)
		"insert_oven":
			if j != null and sim.production.insert_oven(jid, int(task["iid"]), wid):
				actor.carried = {}
			elif j != null and j.carrier_id == wid:
				return deliver_task(sim, actor)
		"pickup_tray":
			if j != null and sim.production.pickup_tray(jid, wid):
				actor.carried = {"type": "tray", "job_id": jid, "recipe_id": String(j.recipe_id)}
				return deliver_task(sim, actor)
			abort(sim, wid, task)
		"place_display":
			if j != null:
				sim.production.deliver_tray(jid, int(task["iid"]))
			if sim.production.get_job(jid) == null:
				actor.carried = {}
			else:
				return deliver_task(sim, actor)
		"put_table":
			if j != null and sim.production.put_on_table(jid):
				actor.carried = {}
		"take_table":
			if j != null and sim.production.table_has_destination(j) and sim.production.take_from_table(jid, wid):
				actor.carried = {"type": "dough" if j.stage == ProductionJob.CARRIED_TO_OVEN else "tray", "job_id": jid, "recipe_id": String(j.recipe_id)}
				return deliver_task(sim, actor)
			abort(sim, wid, task)
	return {}


## Serah terima saat pekerja berhenti atau dunia dibangun ulang: barang di
## tangan ditaruh di Meja Tunggu supaya tidak ada job yatim.
static func drop_carried(sim: SimulationRoot, actor: SimActor) -> void:
	if actor.carried.is_empty():
		return
	var j: ProductionJob = sim.production.get_job(int(actor.carried.get("job_id", -1)))
	if j != null and j.carrier_id == actor.id:
		sim.production.put_on_table(j.job_id)
	actor.carried = {}
