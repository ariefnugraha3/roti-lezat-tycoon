class_name ProductionManager
extends SimManager
## ProductionManager — satu-satunya pemilik ProductionJob (GDD idle 4; v3.1 18, 61, 98).
##
## Alur satu job: pekerja memilih petak rak, membayar bahan, dan memesan mixer
## (ORDERED) -> MIXING -> MIX_DONE_WAITING_PICKUP -> CARRIED_TO_OVEN -> BAKING ->
## BAKE_DONE_WAITING_PICKUP -> CARRIED_TO_DISPLAY -> roti di rak. Mixer dan oven
## yang selesai menahan isinya tanpa batas waktu; tidak ada gosong dan tidak
## ada roti basi (GDD idle 4.6). Loyang yang tidak muat diparkir di Meja Tunggu
## (GDD idle 4.7). Kecepatan alat datang dari levelnya (UpgradeManager).

var jobs: Dictionary = {}
var next_job_id: int = 1
var next_table_seq: int = 1

var _min_stage: float = 1.0
var _max_jobs: int = 64
var _sorted_cache: Array[ProductionJob] = []
var _sorted_dirty: bool = true


func setup(s: SimulationRoot) -> void:
	super.setup(s)
	_min_stage = DataRegistry.balf("production.min_stage_seconds")
	_max_jobs = DataRegistry.bali("production.max_concurrent_jobs")


func new_game() -> void:
	jobs.clear()
	_sorted_dirty = true
	next_job_id = 1
	next_table_seq = 1


func get_job(job_id: int) -> ProductionJob:
	return jobs.get(job_id)


func job_stage(job_id: int) -> StringName:
	var j: ProductionJob = get_job(job_id)
	return j.stage if j != null else &""


## Job terurut ID (read-only), disusun ulang hanya bila himpunannya berubah.
func sorted_jobs() -> Array[ProductionJob]:
	if _sorted_dirty or _sorted_cache.size() != jobs.size():
		var ids: Array = jobs.keys()
		ids.sort()
		var out: Array[ProductionJob] = []
		for i: Variant in ids:
			out.append(jobs[i])
		out.make_read_only()
		_sorted_cache = out
		_sorted_dirty = false
	return _sorted_cache


func _add(j: ProductionJob) -> void:
	jobs[j.job_id] = j
	_sorted_dirty = true


func _erase(j: ProductionJob) -> void:
	jobs.erase(j.job_id)
	_sorted_dirty = true


# ===========================================================================
# ALAT & RESEP (GDD idle 4.1, 4.2)
# ===========================================================================

## Tier model logis alat (dari levelnya, GDD idle 8.2).
func tier_of(e: EquipmentInstance) -> int:
	return sim.upgrades.station_model_tier(e.iid)


## Tier tertinggi mixer/oven terpasang (syarat resep, GDD idle 4.2).
func best_tier(category: StringName) -> int:
	var best: int = 0
	for e: EquipmentInstance in sim.equipment.placed_list(category):
		best = maxi(best, tier_of(e))
	return best


## Resep bisa dibuat: paling sedikit satu mixer dan satu oven setier syaratnya.
func owns_equipment_for(recipe: RecipeDefinition) -> bool:
	return best_tier(&"mixer") >= recipe.required_mixer_tier and best_tier(&"oven") >= recipe.required_oven_tier


## Mixer bebas tercepat yang memenuhi syarat resep (seri: iid terkecil).
func free_mixer_for(recipe: RecipeDefinition) -> EquipmentInstance:
	var best: EquipmentInstance = null
	var best_speed: float = -1.0
	for e: EquipmentInstance in sim.equipment.placed_list(&"mixer"):
		if e.job_id >= 0 or tier_of(e) < recipe.required_mixer_tier:
			continue
		var sp: float = sim.upgrades.station_speed(e.iid)
		if sp > best_speed + 0.000001:
			best = e
			best_speed = sp
	return best


## Oven kosong tercepat yang memenuhi syarat dan belum dipesan pekerja lain.
func free_oven_for(recipe: RecipeDefinition, for_job: int = -1) -> EquipmentInstance:
	var best: EquipmentInstance = null
	var best_speed: float = -1.0
	for e: EquipmentInstance in sim.equipment.placed_list(&"oven"):
		if e.job_id >= 0 or tier_of(e) < recipe.required_oven_tier or oven_reserved(e.iid, for_job):
			continue
		var sp: float = sim.upgrades.station_speed(e.iid)
		if sp > best_speed + 0.000001:
			best = e
			best_speed = sp
	return best


## Oven `iid` sedang dituju adonan job lain (pekerja membawa atau akan
## mengambil adonan untuknya).
func oven_reserved(iid: int, except_job: int = -1) -> bool:
	for j: ProductionJob in sorted_jobs():
		if j.job_id != except_job and j.oven_id == iid and (j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP or j.stage == ProductionJob.CARRIED_TO_OVEN):
			return true
	return false


## Durasi MIXING (GDD idle 4.5): (mix + prep) × faktor batch ÷ speed(mixer).
func mixer_stage_seconds(recipe: RecipeDefinition, mixer_iid: int, batch: int) -> float:
	var base: float = recipe.mix_duration_seconds + recipe.prep_duration_seconds
	return maxf(_min_stage, base * DataRegistry.batch_duration_factor(batch) / maxf(sim.upgrades.station_speed(mixer_iid), 0.0001))


## Durasi BAKING (GDD idle 4.5): bake × faktor batch ÷ speed(oven).
func oven_stage_seconds(recipe: RecipeDefinition, oven_iid: int, batch: int) -> float:
	return maxf(_min_stage, recipe.bake_duration_seconds * DataRegistry.batch_duration_factor(batch) / maxf(sim.upgrades.station_speed(oven_iid), 0.0001))


## Biaya bahan satu batch (GDD idle 4.4): biaya bahan x1 (v3.1 63.1) × kelipatan
## batch, tidak ikut naik dengan level resep.
static func batch_cost(recipe: RecipeDefinition, batch: int) -> float:
	return recipe.batch_cost_kr * float(batch)


# ===========================================================================
# PETAK TUJUAN (GDD idle 4.3)
# ===========================================================================

## Unit yang sedang dibuat untuk petak itu (belum sampai di rak dan tidak
## sedang diparkir di Meja Tunggu).
func in_flight_units(display_iid: int, slot_index: int) -> int:
	var n: int = 0
	for j: ProductionJob in sorted_jobs():
		if j.target_display == display_iid and j.target_slot == slot_index and not j.is_on_table():
			n += j.carried_units if j.stage == ProductionJob.CARRIED_TO_DISPLAY else j.quantity_output
	return n


func active_job_count() -> int:
	var n: int = 0
	for j: ProductionJob in jobs.values():
		if not j.is_on_table():
			n += 1
	return n


func has_active_jobs() -> bool:
	return active_job_count() > 0


func can_create_job() -> bool:
	return active_job_count() < _max_jobs


# ===========================================================================
# ALUR JOB
# ===========================================================================

## Pekerja memulai batch untuk petak tujuan: bahan dibayar sekarang
## (INGREDIENT_COST) dan mixer dipesan. null bila KR kurang atau mixer terpakai.
func create_job(recipe_id: StringName, batch: int, mixer: EquipmentInstance, target_display: int, target_slot: int, worker: StringName) -> ProductionJob:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null or mixer == null or mixer.job_id >= 0 or not can_create_job():
		return null
	var cost: float = batch_cost(r, batch)
	if not sim.economy.spend(cost, &"INGREDIENT_COST", recipe_id, {"batch": batch}):
		return null
	var j := ProductionJob.new()
	j.job_id = next_job_id
	next_job_id += 1
	j.recipe_id = recipe_id
	j.batch_multiplier = batch
	j.quantity_output = r.batch_yield * batch
	j.ingredient_cost_kr = Money.round_half_up(cost)
	j.mixer_id = mixer.iid
	j.target_display = target_display
	j.target_slot = target_slot
	j.created_at = sim.time.sim_seconds
	j.claimed_by = worker
	j.stage = ProductionJob.ORDERED
	mixer.job_id = j.job_id
	_add(j)
	EventBus.production_job_created.emit(j.job_id)
	GameLogger.info("PRODUCTION", "job %d %s x%d on mixer %d for %d:%d" % [j.job_id, recipe_id, batch, mixer.iid, target_display, target_slot])
	return j


## Pekerja tiba di mixer: MIXING dimulai.
func start_mixing(job_id: int, actor_id: StringName) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.ORDERED:
		return false
	var mixer: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
	if mixer == null:
		return false
	j.stage = ProductionJob.MIXING
	j.stage_started_by = actor_id
	j.stage_duration = mixer_stage_seconds(j.recipe(), mixer.iid, j.batch_multiplier)
	j.stage_elapsed = 0.0
	j.claimed_by = &""
	EventBus.sfx.emit(&"mixer_start", mixer.floor_id)
	return true


## Ambil mangkuk adonan. Mixer langsung bebas; oven tujuannya sudah dipesan.
func pickup_dough(job_id: int, actor_id: StringName) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.MIX_DONE_WAITING_PICKUP:
		return false
	_release_mixer(j)
	j.stage = ProductionJob.CARRIED_TO_OVEN
	j.carrier_id = actor_id
	j.claimed_by = &""
	return true


## Pesan oven `oven_iid` untuk adonan job ini (sebelum diambil dari mixer).
func reserve_oven(job_id: int, oven_iid: int) -> void:
	var j: ProductionJob = get_job(job_id)
	if j != null and j.stage != ProductionJob.BAKING and j.stage != ProductionJob.BAKE_DONE_WAITING_PICKUP:
		j.oven_id = oven_iid


func release_oven_reservation(job_id: int) -> void:
	var j: ProductionJob = get_job(job_id)
	if j != null and (j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP or j.stage == ProductionJob.CARRIED_TO_OVEN or j.stage == ProductionJob.DOUGH_ON_TABLE):
		j.oven_id = -1


## Masukkan adonan ke oven.
func insert_oven(job_id: int, oven_iid: int, actor_id: StringName) -> bool:
	var j: ProductionJob = get_job(job_id)
	var oven: EquipmentInstance = sim.equipment.get_inst(oven_iid)
	if j == null or oven == null or j.stage != ProductionJob.CARRIED_TO_OVEN:
		return false
	if oven.job_id >= 0 or tier_of(oven) < j.recipe().required_oven_tier or oven_reserved(oven_iid, j.job_id):
		return false
	oven.job_id = j.job_id
	j.oven_id = oven_iid
	j.stage = ProductionJob.BAKING
	j.stage_started_by = actor_id
	j.stage_duration = oven_stage_seconds(j.recipe(), oven_iid, j.batch_multiplier)
	j.stage_elapsed = 0.0
	j.carrier_id = &""
	EventBus.sfx.emit(&"oven_close", oven.floor_id)
	return true


## Angkat loyang matang.
func pickup_tray(job_id: int, actor_id: StringName) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.BAKE_DONE_WAITING_PICKUP:
		return false
	var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
	if oven != null and oven.job_id == j.job_id:
		oven.job_id = -1
		EventBus.sfx.emit(&"oven_open", oven.floor_id)
	j.claimed_by = &""
	j.stage = ProductionJob.CARRIED_TO_DISPLAY
	j.carrier_id = actor_id
	j.carried_units = j.quantity_output
	j.produced_at = sim.time.sim_seconds
	return true


## Petak yang bisa menerima loyang resep ini di rak `iid`, urut: petak tujuan,
## lalu petak yang menjual resep itu dengan rasio isi terendah. [[iid, slot], ...]
func delivery_slots(j: ProductionJob, only_iid: int = -1) -> Array:
	var out: Array = []
	if (only_iid < 0 or only_iid == j.target_display) and sim.display.has_display(j.target_display) \
			and sim.display.slot_room(j.target_display, j.target_slot, j.recipe_id) > 0:
		out.append([j.target_display, j.target_slot])
	var rest: Array = []
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		if only_iid >= 0 and e.iid != only_iid:
			continue
		for i in sim.display.slot_count(e.iid):
			if e.iid == j.target_display and i == j.target_slot:
				continue
			if sim.display.effective_recipe(e.iid, i) != j.recipe_id or sim.display.slot_room(e.iid, i, j.recipe_id) <= 0:
				continue
			var cap: float = float(maxi(1, sim.display.slot_capacity(e.iid)))
			rest.append([float(sim.display.slot_units(e.iid, i)) / cap, e.iid, i])
	rest.sort_custom(func(a: Array, b: Array) -> bool:
		if absf(float(a[0]) - float(b[0])) > 0.000001:
			return float(a[0]) < float(b[0])
		if int(a[1]) != int(b[1]):
			return int(a[1]) < int(b[1])
		return int(a[2]) < int(b[2]))
	for r: Array in rest:
		out.append([r[1], r[2]])
	return out


## Rak pertama tempat loyang ini bisa ditaruh (tujuan pekerja), atau -1.
func delivery_display(j: ProductionJob) -> int:
	var slots_l: Array = delivery_slots(j)
	return int(slots_l[0][0]) if not slots_l.is_empty() else -1


## Pekerja tiba di rak `iid` membawa loyang: isi ditaruh ke petak tujuan lalu
## petak lain di rak itu yang menjual resep yang sama. Mengembalikan jumlah
## unit yang masuk; job selesai saat loyang kosong.
func deliver_tray(job_id: int, iid: int) -> int:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.CARRIED_TO_DISPLAY:
		return 0
	var placed: int = 0
	for pair: Array in delivery_slots(j, iid):
		if j.carried_units <= 0:
			break
		var n: int = sim.display.place(int(pair[0]), int(pair[1]), j.recipe_id, j.carried_units, j.produced_at, j.job_id)
		j.carried_units -= n
		placed += n
	if placed > 0:
		EventBus.sfx.emit(&"bread_place_display", sim.equipment.get_inst(iid).floor_id)
	if j.carried_units <= 0:
		_complete(j)
	return placed


func _complete(j: ProductionJob) -> void:
	j.carrier_id = &""
	sim.statistics.add(&"total_bread_produced", j.quantity_output)
	sim.achievements.note_recipe_produced(j.recipe_id)
	_erase(j)


func _release_mixer(j: ProductionJob) -> void:
	var mixer: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
	if mixer != null and mixer.job_id == j.job_id:
		mixer.job_id = -1


## Semangat (GDD idle 5.2): progres tahap yang berjalan di alat `iid` maju
## `seconds` detik-simulasi. false bila alat itu tidak sedang bekerja.
func boost_station(iid: int, seconds: float) -> bool:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null or e.job_id < 0:
		return false
	var j: ProductionJob = get_job(e.job_id)
	if j == null or (j.stage != ProductionJob.MIXING and j.stage != ProductionJob.BAKING):
		return false
	j.stage_elapsed = minf(j.stage_duration, j.stage_elapsed + seconds)
	return true


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	for j: ProductionJob in sorted_jobs():
		match j.stage:
			ProductionJob.MIXING:
				j.stage_elapsed += dt
				if j.stage_elapsed >= j.stage_duration:
					j.stage_elapsed = j.stage_duration
					j.stage = ProductionJob.MIX_DONE_WAITING_PICKUP
					var mixer: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
					EventBus.station_completed.emit(j.mixer_id, j.stage)
					EventBus.sfx.emit(&"mixer_done", mixer.floor_id if mixer != null else &"floor_1")
			ProductionJob.BAKING:
				j.stage_elapsed += dt
				if j.stage_elapsed >= j.stage_duration:
					j.stage_elapsed = j.stage_duration
					j.stage = ProductionJob.BAKE_DONE_WAITING_PICKUP
					var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
					EventBus.station_completed.emit(j.oven_id, j.stage)
					EventBus.sfx.emit(&"oven_done", oven.floor_id if oven != null else &"floor_1")


# ===========================================================================
# MEJA TUNGGU (GDD idle 4.7) — penampung tanpa busuk dan tanpa batas isi
# ===========================================================================

func table_jobs() -> Array[ProductionJob]:
	var out: Array[ProductionJob] = []
	for j: ProductionJob in sorted_jobs():
		if j.is_on_table():
			out.append(j)
	out.sort_custom(func(a: ProductionJob, b: ProductionJob) -> bool: return a.table_seq < b.table_seq)
	return out


## Taruh mangkuk adonan atau loyang yang sedang dibawa ke meja.
func put_on_table(job_id: int) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null:
		return false
	match j.stage:
		ProductionJob.CARRIED_TO_OVEN:
			j.stage = ProductionJob.DOUGH_ON_TABLE
			j.oven_id = -1
		ProductionJob.CARRIED_TO_DISPLAY:
			j.stage = ProductionJob.TRAY_ON_TABLE
		_:
			return false
	j.carrier_id = &""
	j.claimed_by = &""
	j.table_seq = next_table_seq
	next_table_seq += 1
	EventBus.sfx.emit(&"bread_place_display", _table_floor())
	return true


## Ambil satu barang dari meja ke tangan `actor_id`.
func take_from_table(job_id: int, actor_id: StringName) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or not j.is_on_table():
		return false
	j.stage = ProductionJob.CARRIED_TO_OVEN if j.stage == ProductionJob.DOUGH_ON_TABLE else ProductionJob.CARRIED_TO_DISPLAY
	j.carrier_id = actor_id
	j.claimed_by = &""
	EventBus.sfx.emit(&"bread_place_display", _table_floor())
	return true


## Barang meja pertama (urut ditaruh) yang tujuannya sudah ada: loyang bila ada
## petak yang menjual resepnya dengan ruang, adonan bila ada oven bebas. Yang
## sudah dituju pekerja lain dilewati. null bila tidak ada.
func table_pick(worker: StringName = &"") -> ProductionJob:
	for j: ProductionJob in table_jobs():
		if j.claimed_by != &"" and j.claimed_by != worker:
			continue
		if table_has_destination(j):
			return j
	return null


func table_has_destination(j: ProductionJob) -> bool:
	if j.stage == ProductionJob.DOUGH_ON_TABLE:
		return free_oven_for(j.recipe(), j.job_id) != null
	return not delivery_slots(j).is_empty()


func _table_floor() -> StringName:
	var t: EquipmentInstance = sim.equipment.table_instance()
	return t.floor_id if t != null else sim.world.kitchen_floor()


# ===========================================================================
# DEBUG
# ===========================================================================

func debug_complete_all() -> void:
	for j: ProductionJob in sorted_jobs():
		if j.stage == ProductionJob.MIXING or j.stage == ProductionJob.BAKING:
			j.stage_elapsed = j.stage_duration


# ===========================================================================
# SAVE & RECOVERY (v3.1 38.2, 77.1)
# ===========================================================================

func capture() -> Dictionary:
	var list: Array = []
	for j: ProductionJob in sorted_jobs():
		list.append(j.to_dict())
	return {"next_job_id": next_job_id, "jobs": list, "next_table_seq": next_table_seq}


func restore(d: Dictionary) -> void:
	jobs.clear()
	_sorted_dirty = true
	next_job_id = int(d.get("next_job_id", 1))
	next_table_seq = int(d.get("next_table_seq", 1))
	for item: Variant in d.get("jobs", []):
		var j: ProductionJob = ProductionJob.from_dict(item as Dictionary)
		if j.recipe() == null or not ProductionJob.STAGES.has(j.stage):
			GameLogger.error("SAVE", "quarantined job %d (%s, %s)" % [j.job_id, j.recipe_id, j.stage])
			continue
		_add(j)
		next_job_id = maxi(next_job_id, j.job_id + 1)


## Dipanggil setelah semua manajer dipulihkan (v3.1 38.2, 132). Klaim pekerja
## dilepas (tugas dimulai ulang dari state otoritatif), barang yang sedang
## dibawa tetap di tangan pembawanya, dan job yang kehilangan alatnya ditaruh
## di Meja Tunggu supaya tidak ada yang hilang.
func recover_orphans() -> void:
	for j: ProductionJob in sorted_jobs():
		j.claimed_by = &""
		var needs_mixer: bool = j.stage in [ProductionJob.ORDERED, ProductionJob.MIXING, ProductionJob.MIX_DONE_WAITING_PICKUP]
		var needs_oven: bool = j.stage == ProductionJob.BAKING or j.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP
		if j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP:
			j.oven_id = -1
		if needs_mixer:
			var m: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
			if m == null or not m.placed:
				GameLogger.error("PRODUCTION", "job %d lost its mixer; dough parked on the holding table" % j.job_id)
				j.stage = ProductionJob.CARRIED_TO_OVEN
				put_on_table(j.job_id)
				continue
			m.job_id = j.job_id
		if needs_oven:
			var o: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
			if o == null or not o.placed:
				GameLogger.error("PRODUCTION", "job %d lost its oven; tray parked on the holding table" % j.job_id)
				j.stage = ProductionJob.CARRIED_TO_DISPLAY
				j.carried_units = j.quantity_output
				put_on_table(j.job_id)
				continue
			o.job_id = j.job_id
