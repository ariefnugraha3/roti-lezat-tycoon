class_name ProductionManager
extends SimManager
## ProductionManager — satu-satunya pemilik ProductionJob (GDD 18, 61, 62, 98).
##
## Alur satu job: ORDERED (bahan sudah dipotong, mixer sudah ditetapkan) ->
## MIXING (mix + prep dalam satu progress) -> MIX_DONE_WAITING_PICKUP ->
## CARRIED_TO_OVEN -> BAKING -> BAKE_DONE_WAITING_PICKUP (READY_PERFECT) ->
## OVERBAKING -> BURNT, atau diangkat -> CARRIED_TO_DISPLAY -> ON_DISPLAY.
## Alat yang selesai menahan isinya sampai diambil (GDD 18.6). Adonan dan loyang
## yang dibawa pemain boleh diparkir di Meja Tunggu (DOUGH_ON_TABLE /
## TRAY_ON_TABLE) lalu diambil lagi (GDD 5.1.3, 19.7.6).

var jobs: Dictionary = {}
var next_job_id: int = 1
var batches_burnt_today: int = 0
var completed_today: Dictionary = {}
var next_table_seq: int = 1

var _min_stage: float = 1.0
var _max_jobs: int = 64


func setup(s: SimulationRoot) -> void:
	super.setup(s)
	_min_stage = DataRegistry.balf("production.min_stage_seconds")
	_max_jobs = DataRegistry.bali("production.max_concurrent_jobs")


func new_game() -> void:
	jobs.clear()
	next_job_id = 1
	next_table_seq = 1
	reset_day()


func reset_day() -> void:
	batches_burnt_today = 0
	completed_today.clear()


func get_job(job_id: int) -> ProductionJob:
	return jobs.get(job_id)


func job_stage(job_id: int) -> StringName:
	var j: ProductionJob = get_job(job_id)
	return j.stage if j != null else &""


func sorted_jobs() -> Array[ProductionJob]:
	var ids: Array = jobs.keys()
	ids.sort()
	var out: Array[ProductionJob] = []
	for i: Variant in ids:
		out.append(jobs[i])
	return out


## Oven dianggap aktif selama baking dan menunggu diambil (GDD 86.2).
func oven_is_hot(job_id: int) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null:
		return false
	return j.stage == ProductionJob.BAKING or j.is_waiting_oven_pickup()


# ===========================================================================
# KETERSEDIAAN RESEP (GDD 61.1)
# ===========================================================================

## Mixer terpasang yang bebas dan cukup tier untuk resep ini.
func free_mixer_for(recipe: RecipeDefinition) -> EquipmentInstance:
	for e: EquipmentInstance in sim.equipment.placed_list(&"mixer"):
		if e.tier() >= recipe.required_mixer_tier and e.job_id < 0:
			return e
	return null


## Oven yang bisa menerima adonan resep ini sekarang: oven kosong lebih dulu,
## lalu oven berisi loyang gosong yang dibuang otomatis saat adonan masuk
## (GDD 16.5, 62).
func free_oven_for(recipe: RecipeDefinition) -> EquipmentInstance:
	var burnt: EquipmentInstance = null
	for e: EquipmentInstance in sim.equipment.placed_list(&"oven"):
		if e.tier() < recipe.required_oven_tier:
			continue
		if e.job_id < 0:
			return e
		if burnt == null and holds_burnt(e):
			burnt = e
	return burnt


## true bila oven masih menahan loyang gosong (GDD 62).
func holds_burnt(oven: EquipmentInstance) -> bool:
	var j: ProductionJob = get_job(oven.job_id) if oven != null and oven.job_id >= 0 else null
	return j != null and j.stage == ProductionJob.BURNT


func owns_equipment_for(recipe: RecipeDefinition) -> bool:
	return sim.equipment.best_tier(&"mixer") >= recipe.required_mixer_tier \
		and sim.equipment.best_tier(&"oven") >= recipe.required_oven_tier


## "" bila bisa dibuat; selain itu kunci string alasan (GDD 16.7).
func make_block_reason(recipe_id: StringName, batch: int) -> String:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return "ui_recipe_cannot_make"
	if not owns_equipment_for(r):
		return "ui_feedback_needs_equipment"
	if not sim.inventory.has_for_recipe(r, batch):
		return "ui_feedback_missing_ingredients"
	if active_job_count() >= _max_jobs:
		return "ui_feedback_job_limit"
	if free_mixer_for(r) == null:
		return "ui_feedback_no_free_mixer"
	return ""


# ===========================================================================
# ALUR JOB
# ===========================================================================

## Konfirmasi batch dari Buku Resep: bahan dipotong sekarang (GDD 18.3) dan
## mixer ditetapkan. Mengembalikan job atau null.
func create_job(recipe_id: StringName, batch: int, owner: StringName) -> ProductionJob:
	if make_block_reason(recipe_id, batch) != "":
		return null
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	var mixer: EquipmentInstance = free_mixer_for(r)
	var taken: Dictionary = sim.inventory.consume_for_recipe(r, batch)
	if taken.is_empty():
		return null
	var j := ProductionJob.new()
	j.job_id = next_job_id
	next_job_id += 1
	j.recipe_id = recipe_id
	j.batch_multiplier = batch
	j.quantity_output = r.batch_yield * batch
	j.reserved_ingredients = taken
	j.ingredient_value_kr = sim.inventory.value_of(taken)
	j.mixer_id = mixer.iid
	j.created_at = sim.time.sim_seconds
	j.owner_actor_id = owner
	j.stage = ProductionJob.ORDERED
	mixer.job_id = j.job_id
	jobs[j.job_id] = j
	sim.analytics.note_batch_started(recipe_id)
	EventBus.production_job_created.emit(j.job_id)
	GameLogger.info("PRODUCTION", "job %d %s x%d on mixer %d" % [j.job_id, recipe_id, batch, mixer.iid])
	return j


## Batal sebelum MIXING: seluruh bahan kembali (GDD 18.3, 61.4).
func cancel_job(job_id: int) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.ORDERED:
		return false
	sim.inventory.refund(j.reserved_ingredients)
	_release_mixer(j)
	jobs.erase(job_id)
	return true


## Durasi tahap mixer (GDD 18.5): (mix + prep) × rasio alat × batch ÷ kecepatan.
## Durasi MIXING (GDD 18.5). Batch x3/x5 hanya memperpanjang durasi sesuai
## `batch_duration_factor` (x1 1.0, x3 1.2, x5 1.4), bukan x3/x5 penuh.
func mixer_stage_seconds(recipe: RecipeDefinition, mixer_tier: int, batch: int, staff_speed: float) -> float:
	var active: EquipmentDefinition = DataRegistry.equipment_for(&"mixer", mixer_tier)
	var required: EquipmentDefinition = DataRegistry.equipment_for(&"mixer", recipe.required_mixer_tier)
	var base: float = recipe.mix_duration_seconds + recipe.prep_duration_seconds
	var ratio: float = active.reference_seconds / required.reference_seconds
	return maxf(_min_stage, base * ratio * DataRegistry.batch_duration_factor(batch) / maxf(staff_speed, 0.0001))


func oven_stage_seconds(recipe: RecipeDefinition, oven_tier: int, batch: int, staff_speed: float) -> float:
	var active: EquipmentDefinition = DataRegistry.equipment_for(&"oven", oven_tier)
	var required: EquipmentDefinition = DataRegistry.equipment_for(&"oven", recipe.required_oven_tier)
	var ratio: float = active.reference_seconds / required.reference_seconds
	return maxf(_min_stage, recipe.bake_duration_seconds * ratio * DataRegistry.batch_duration_factor(batch) / maxf(staff_speed, 0.0001))


## Aktor tiba di mixer: MIXING dimulai; kecepatan staf dikunci (GDD 18.5).
func start_mixing(job_id: int, actor_id: StringName, staff_speed: float) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.ORDERED:
		return false
	var mixer: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
	if mixer == null:
		return false
	j.stage = ProductionJob.MIXING
	j.stage_started_by = actor_id
	j.stage_duration = mixer_stage_seconds(j.recipe(), mixer.tier(), j.batch_multiplier, staff_speed)
	j.stage_elapsed = 0.0
	# Setelah MIXING dimulai bahan tidak dapat direfund: dicatat sebagai HPP terpakai.
	if not j.cogs_noted:
		j.cogs_noted = true
		sim.economy.note_cogs(j.ingredient_value_kr)
	EventBus.sfx.emit(&"mixer_start", mixer.floor_id)
	return true


## Ambil mangkuk adonan (GDD 2 langkah 4). Mixer langsung bebas.
func pickup_dough(job_id: int, actor_id: StringName) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.MIX_DONE_WAITING_PICKUP:
		return false
	_release_mixer(j)
	j.stage = ProductionJob.CARRIED_TO_OVEN
	j.carrier_id = actor_id
	j.claimed_by = &""
	return true


## Masukkan adonan ke oven (GDD 2 langkah 5).
func insert_oven(job_id: int, oven_iid: int, actor_id: StringName, staff_speed: float) -> bool:
	var j: ProductionJob = get_job(job_id)
	var oven: EquipmentInstance = sim.equipment.get_inst(oven_iid)
	if j == null or oven == null or j.stage != ProductionJob.CARRIED_TO_OVEN:
		return false
	if oven.tier() < j.recipe().required_oven_tier:
		return false
	if oven.job_id >= 0:
		# Loyang gosong dibuang otomatis agar adonan bisa masuk; loyang yang
		# masih bisa dijual tidak pernah ditukar (GDD 16.5, 62).
		var old: ProductionJob = get_job(oven.job_id)
		if old == null or old.stage != ProductionJob.BURNT:
			return false
		oven.job_id = -1
		old.claimed_by = &""
		_discard_burnt(old, oven)
		sim.alerts.clear_oven(oven_iid)
	oven.job_id = j.job_id
	j.oven_id = oven_iid
	j.stage = ProductionJob.BAKING
	j.stage_started_by = actor_id
	# Adonan dari Meja Tunggu dipanggang normal: roti mulai segar (GDD 19.7.6).
	j.table_age_hours = 0.0
	j.stage_duration = oven_stage_seconds(j.recipe(), oven.tier(), j.batch_multiplier, staff_speed)
	j.stage_elapsed = 0.0
	j.burn_elapsed = 0.0
	j.protected = false
	j.carrier_id = &""
	EventBus.sfx.emit(&"oven_close", oven.floor_id)
	return true


## Angkat loyang (GDD 2 langkah 6, 62). Mengembalikan {ok, burnt}.
func pickup_tray(job_id: int, actor_id: StringName) -> Dictionary:
	var j: ProductionJob = get_job(job_id)
	if j == null or not j.is_waiting_oven_pickup():
		return {"ok": false, "burnt": false}
	var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
	j.bake_quality = current_quality(j)
	if oven != null:
		oven.job_id = -1
		EventBus.sfx.emit(&"oven_open", oven.floor_id)
	j.claimed_by = &""
	if j.stage == ProductionJob.BURNT:
		_discard_burnt(j, oven)
		return {"ok": true, "burnt": true}
	j.stage = ProductionJob.CARRIED_TO_DISPLAY
	j.carrier_id = actor_id
	j.carried_units = j.quantity_output
	j.produced_at = sim.time.sim_seconds
	return {"ok": true, "burnt": false}


## Batch gosong langsung ke disposal, tanpa KR (GDD 19.8, 62).
func _discard_burnt(j: ProductionJob, oven: EquipmentInstance) -> void:
	j.stage = ProductionJob.FAILED
	sim.analytics.note_burnt(j.recipe_id, j.quantity_output, j.ingredient_value_kr)
	sim.statistics.add(&"total_bread_burned", j.quantity_output)
	sim.statistics.add(&"total_bread_wasted", j.quantity_output)
	sim.economy.note_waste(j.ingredient_value_kr)
	batches_burnt_today += 1
	jobs.erase(j.job_id)
	EventBus.sfx.emit(&"bread_burnt", oven.floor_id if oven != null else &"floor_1")


## Taruh sebagian/seluruh isi loyang ke satu petak rak (GDD 85). Mengembalikan
## jumlah yang masuk; job selesai saat loyang kosong.
func place_from_tray(job_id: int, display_iid: int, slot_index: int, qty: int) -> int:
	var j: ProductionJob = get_job(job_id)
	if j == null or (j.stage != ProductionJob.CARRIED_TO_DISPLAY and j.stage != ProductionJob.PLACEMENT_UI):
		return 0
	var n: int = sim.display.place(display_iid, slot_index, j.recipe_id, mini(qty, j.carried_units), j.bake_quality, j.produced_at, j.job_id, j.table_age_hours)
	if n <= 0:
		return 0
	j.carried_units -= n
	EventBus.sfx.emit(&"bread_place_display", sim.equipment.get_inst(display_iid).floor_id)
	if j.carried_units <= 0:
		_complete(j)
	return n


## Penempatan otomatis (baker, GDD 23.3).
func auto_place_tray(job_id: int, preferred_display: int) -> int:
	var j: ProductionJob = get_job(job_id)
	if j == null or j.stage != ProductionJob.CARRIED_TO_DISPLAY:
		return 0
	var n: int = sim.display.auto_place(j.recipe_id, j.carried_units, j.bake_quality, j.produced_at, j.job_id, preferred_display)
	j.carried_units -= n
	if n > 0:
		EventBus.sfx.emit(&"bread_place_display", sim.world.location.store_floor())
	if j.carried_units <= 0:
		_complete(j)
	return n


func _complete(j: ProductionJob) -> void:
	j.stage = ProductionJob.ON_DISPLAY
	j.carrier_id = &""
	completed_today[j.recipe_id] = int(completed_today.get(j.recipe_id, 0)) + 1
	sim.analytics.note_batch_completed(j.recipe_id, j.quantity_output)
	sim.statistics.add(&"total_bread_produced", j.quantity_output)
	sim.staff.note_batch_completed(j.owner_actor_id)
	sim.achievements.note_recipe_produced(j.recipe_id)
	jobs.erase(j.job_id)


func _release_mixer(j: ProductionJob) -> void:
	var mixer: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
	if mixer != null and mixer.job_id == j.job_id:
		mixer.job_id = -1


## Kualitas panggang saat ini (GDD 62): READY 1.0, OVERBAKING linear
## 0.95 -> 0.60, BURNT 0.
func current_quality(j: ProductionJob) -> float:
	match j.stage:
		ProductionJob.BAKE_DONE_WAITING_PICKUP:
			return 1.0
		ProductionJob.OVERBAKING:
			var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
			var def: EquipmentDefinition = oven.def() if oven != null else DataRegistry.equipment_for(&"oven", 1)
			var t: float = clampf((j.burn_elapsed - def.perfect_window_seconds) / def.overbake_window_seconds, 0.0, 1.0)
			return lerpf(DataRegistry.balf("production.overbake_quality_start"), DataRegistry.balf("production.overbake_quality_end"), t)
		ProductionJob.BURNT:
			return 0.0
	return j.bake_quality


## Progres gosong ternormalisasi 0..1 untuk visual browning (GDD 18.7).
func burn_progress(j: ProductionJob) -> float:
	var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
	if oven == null:
		return 0.0
	var def: EquipmentDefinition = oven.def()
	return clampf(j.burn_elapsed / def.burn_grace_seconds(), 0.0, 1.0)


# ===========================================================================
# TICK (P2, GDD 102)
# ===========================================================================

func step(dt: float) -> void:
	if not sim.time.is_running_phase():
		return
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
					sim.tutorial.on_event(&"mixer_done")
			ProductionJob.BAKING:
				j.stage_elapsed += dt
				if j.stage_elapsed >= j.stage_duration:
					j.stage_elapsed = j.stage_duration
					_on_bake_complete(j)
			ProductionJob.BAKE_DONE_WAITING_PICKUP, ProductionJob.OVERBAKING:
				if j.protected:
					continue
				j.burn_elapsed += dt
				_update_burn(j)
	age_table(sim.time.ingame_hours(dt))


func _on_bake_complete(j: ProductionJob) -> void:
	j.stage = ProductionJob.BAKE_DONE_WAITING_PICKUP
	j.burn_elapsed = 0.0
	var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
	var floor_id: StringName = oven.floor_id if oven != null else &"floor_1"
	EventBus.station_completed.emit(j.oven_id, j.stage)
	EventBus.sfx.emit(&"oven_done", floor_id)
	# Auto-retrieve: satu roll per job, hanya bila tahap oven dimulai Asisten Dapur
	# yang masih bertugas (GDD 18.8). Baker yang sudah pergi (dipecat, libur)
	# tidak bisa mengambilnya, jadi hasilnya sama dengan roll gagal.
	var staff_def: StaffDefinition = DataRegistry.staff(j.stage_started_by)
	if staff_def != null and staff_def.is_baker() and sim.staff.is_working(staff_def.id):
		var p: float = staff_def.auto_retrieve_probability
		var ok: bool = p >= 1.0 or (p > 0.0 and sim.rng.stream(&"staff_rng").randf() < p)
		if ok:
			j.protected = true
			j.claimed_by = staff_def.id
	if not j.protected:
		sim.time.smart_slowdown("tut_smart_speed")
		sim.tutorial.on_event(&"oven_ready")
		sim.alerts.raise_oven(j.oven_id, &"ready")


func _update_burn(j: ProductionJob) -> void:
	var oven: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
	var def: EquipmentDefinition = oven.def() if oven != null else DataRegistry.equipment_for(&"oven", 1)
	if j.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP and j.burn_elapsed >= def.perfect_window_seconds:
		j.stage = ProductionJob.OVERBAKING
		EventBus.sfx.emit(&"oven_burn_warning", oven.floor_id if oven != null else &"floor_1")
		sim.alerts.raise_oven(j.oven_id, &"burning")
		sim.tutorial.on_event(&"near_burn")
	if j.stage == ProductionJob.OVERBAKING and j.burn_elapsed >= def.burn_grace_seconds():
		j.stage = ProductionJob.BURNT
		j.burn_elapsed = def.burn_grace_seconds()
		EventBus.station_completed.emit(j.oven_id, j.stage)


# ===========================================================================
# MEJA TUNGGU (GDD 5.1.3, 19.7.6) — hanya pemain yang memakainya
# ===========================================================================

## Isi Meja Tunggu, urut waktu ditaruh.
func table_jobs() -> Array[ProductionJob]:
	var out: Array[ProductionJob] = []
	for j: ProductionJob in sorted_jobs():
		if j.is_on_table():
			out.append(j)
	out.sort_custom(func(a: ProductionJob, b: ProductionJob) -> bool: return a.table_seq < b.table_seq)
	return out


## Job yang memakai alat atau sedang dibawa. Isi meja tidak dihitung dalam batas
## job serentak (GDD 129) dan tidak menahan upgrade lokasi (GDD 105).
func active_job_count() -> int:
	var n: int = 0
	for j: ProductionJob in jobs.values():
		if not j.is_on_table():
			n += 1
	return n


func has_active_jobs() -> bool:
	return active_job_count() > 0


## Ada loyang matang di oven yang menunggu diangkat pemain dan bisa gosong
## (GDD 62): tidak dilindungi auto-retrieve baker (GDD 18.8). Loyang yang sudah
## gosong tidak dihitung, karena tidak ada lagi yang bisa diselamatkan.
func oven_needs_player() -> bool:
	for j: ProductionJob in sorted_jobs():
		if j.oven_id >= 0 and not j.protected and (j.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP or j.stage == ProductionJob.OVERBAKING):
			return true
	return false


## Taruh mangkuk adonan atau loyang yang sedang dibawa ke meja.
func put_on_table(job_id: int) -> bool:
	var j: ProductionJob = get_job(job_id)
	if j == null:
		return false
	match j.stage:
		ProductionJob.CARRIED_TO_OVEN:
			j.stage = ProductionJob.DOUGH_ON_TABLE
		ProductionJob.CARRIED_TO_DISPLAY, ProductionJob.PLACEMENT_UI:
			j.stage = ProductionJob.TRAY_ON_TABLE
		_:
			return false
	j.carrier_id = &""
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
	EventBus.sfx.emit(&"bread_place_display", _table_floor())
	return true


## Barang paling dekat basi yang tujuannya kosong: adonan bila ada oven yang
## bisa menerimanya, loyang bila rak masih punya ruang. null bila tidak ada.
func table_pick() -> ProductionJob:
	var best: ProductionJob = null
	for j: ProductionJob in table_jobs():
		if not table_has_destination(j):
			continue
		if best == null or table_spoil_ratio(j) > table_spoil_ratio(best) + 0.000001:
			best = j
	return best


func table_has_destination(j: ProductionJob) -> bool:
	if j.stage == ProductionJob.DOUGH_ON_TABLE:
		return free_oven_for(j.recipe()) != null
	return sim.display.total_free_units() > 0


## 0..1: umur di meja terhadap batas basi resep.
func table_spoil_ratio(j: ProductionJob) -> float:
	return j.table_age_hours / maxf(j.recipe().expired_duration_hours, 0.0001)


## Laju penuaan per jam in-game di meja: roti matang memakai laju dasar, adonan
## dikali `holding_table.dough_aging_multiplier` (GDD 19.7.6).
func table_aging_rate(j: ProductionJob) -> float:
	var rate: float = DataRegistry.balf("holding_table.bread_aging_rate")
	if j.stage == ProductionJob.DOUGH_ON_TABLE:
		rate *= DataRegistry.balf("holding_table.dough_aging_multiplier")
	return rate


## Menuakan isi meja `hours` jam in-game; yang mencapai batas basi langsung
## dibuang sebagai waste. Dipakai tiap tick dan sekali saat rollover malam.
func age_table(hours: float) -> void:
	if hours <= 0.0:
		return
	for j: ProductionJob in table_jobs():
		j.table_age_hours += hours * table_aging_rate(j)
		if table_spoil_ratio(j) >= DataRegistry.balf("freshness.unsaleable_ratio"):
			_discard_table_item(j)


func _discard_table_item(j: ProductionJob) -> void:
	var dough: bool = j.stage == ProductionJob.DOUGH_ON_TABLE
	var units: int = 0 if dough else j.carried_units
	var cost: float = j.ingredient_value_kr if dough else j.recipe().unit_cogs_kr() * float(j.carried_units)
	sim.economy.note_waste(cost)
	sim.analytics.note_wasted(j.recipe_id, units, cost, &"table_spoiled")
	if units > 0:
		sim.statistics.add(&"total_bread_wasted", units)
	j.stage = ProductionJob.FAILED
	jobs.erase(j.job_id)
	EventBus.notify.emit(1, "ui_table_dough_spoiled" if dough else "ui_table_bread_spoiled", {"recipe": Tx.recipe_name(j.recipe_id)}, &"box")
	GameLogger.info("PRODUCTION", "job %d spoiled on the holding table" % j.job_id)


func _table_floor() -> StringName:
	var t: EquipmentInstance = sim.equipment.table_instance()
	return t.floor_id if t != null else sim.world.kitchen_floor()


# ===========================================================================
# DEBUG (GDD 39.1)
# ===========================================================================

func debug_complete_all() -> void:
	for j: ProductionJob in sorted_jobs():
		if j.stage == ProductionJob.MIXING or j.stage == ProductionJob.BAKING:
			j.stage_elapsed = j.stage_duration


# ===========================================================================
# SAVE & RECOVERY (GDD 38.2, 77.1)
# ===========================================================================

func capture() -> Dictionary:
	var list: Array = []
	for j: ProductionJob in sorted_jobs():
		list.append(j.to_dict())
	return {"next_job_id": next_job_id, "jobs": list, "batches_burnt_today": batches_burnt_today,
		"completed_today": sn_dict_to_json(completed_today), "next_table_seq": next_table_seq}


func restore(d: Dictionary) -> void:
	jobs.clear()
	next_job_id = int(d.get("next_job_id", 1))
	next_table_seq = int(d.get("next_table_seq", 1))
	batches_burnt_today = int(d.get("batches_burnt_today", 0))
	completed_today = json_to_sn_dict(d.get("completed_today", {}))
	for item: Variant in d.get("jobs", []):
		var j: ProductionJob = ProductionJob.from_dict(item as Dictionary)
		if j.recipe() == null:
			GameLogger.error("SAVE", "quarantined job with unknown recipe %s" % j.recipe_id)
			continue
		jobs[j.job_id] = j
		next_job_id = maxi(next_job_id, j.job_id + 1)


## Dipanggil setelah semua manajer dipulihkan (GDD 38.2, 132).
func recover_orphans() -> void:
	for j: ProductionJob in sorted_jobs():
		var needs_mixer: bool = j.stage in [ProductionJob.ORDERED, ProductionJob.MIXING, ProductionJob.MIX_DONE_WAITING_PICKUP]
		var needs_oven: bool = j.stage == ProductionJob.BAKING or j.is_waiting_oven_pickup()
		if needs_mixer:
			var m: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
			if m == null or not m.placed:
				if j.stage == ProductionJob.ORDERED:
					sim.inventory.refund(j.reserved_ingredients)
					jobs.erase(j.job_id)
				else:
					GameLogger.error("PRODUCTION", "job %d lost its mixer; paused as orphan" % j.job_id)
					j.stage = ProductionJob.MIX_DONE_WAITING_PICKUP
				continue
			m.job_id = j.job_id
		if needs_oven:
			var o: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
			if o == null or not o.placed:
				GameLogger.error("PRODUCTION", "job %d lost its oven; tray kept as carried" % j.job_id)
				j.stage = ProductionJob.CARRIED_TO_OVEN
				continue
			o.job_id = j.job_id
