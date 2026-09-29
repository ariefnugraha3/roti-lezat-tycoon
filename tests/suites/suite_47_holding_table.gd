extends TestSuite
## Meja Tunggu (GDD 5.1.3, 19.7.6): tempat parkir sementara adonan dan loyang
## milik pemain. Tanpa batas isi, bukan rak jualan, dan isinya tetap menua.


func tests() -> Array:
	return [
		{"id": "ACC_TABLE_PUT_TAKE", "name": "5.1.3 dough and trays park on the holding table; one tap takes the most urgent item that has somewhere to go", "fn": _put_take},
		{"id": "ACC_TABLE_SPOILAGE", "name": "19.7.6 table bread ages at the base rate, dough twice as fast, spoiled items become waste, and the night counts", "fn": _spoilage},
		{"id": "ACC_TABLE_RULES", "name": "5.1.3 the table has no limit, sells nothing, and survives upgrades, saves and old saves", "fn": _rules},
		{"id": "ACC_87_STAFF_HANDOFF", "name": "87.2/104 at 18:00 a baker's tray that no shelf can take, or dough with no free mixer, is parked on the holding table instead of becoming an orphan job", "fn": _staff_handoff},
	]


## Serah terima staf pukul 18:00 (GDD 87.2, 104, 105 no.11): tanpa job yatim.
func _staff_handoff() -> void:
	var s: SimulationRoot = new_sim(8720)
	s.tutorial.skip()
	var baker: StringName = &"staff_baker_joko"
	var tray: ProductionJob = _tray_in_hand(s, &"recipe_plain_loaf", baker)
	eq(tray.stage, ProductionJob.CARRIED_TO_DISPLAY, "the baker carries a tray")
	var d: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	for i in s.display.slots(d.iid).size():
		stock(s, &"recipe_sugar_donut", 50, i, d.iid)
	eq(s.display.free_units(d.iid), 0, "the only shelf is full")
	var a := SimActor.new()
	a.id = baker
	a.carried = {"type": "tray", "job_id": tray.job_id, "recipe_id": "recipe_plain_loaf"}
	s.staff._drop_carried(baker, a)
	eq(tray.stage, ProductionJob.TRAY_ON_TABLE, "the tray that fits nowhere is parked on the table")
	check(a.carried.is_empty(), "the baker's hands are empty")
	check(not s.production.has_active_jobs(), "no orphan job is left to block a location upgrade")
	var dough: ProductionJob = _dough_in_hand(s, &"recipe_plain_loaf", baker)
	var blocker: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
	check(blocker != null and s.production.free_mixer_for(dough.recipe()) == null, "the only mixer is taken")
	a.carried = {"type": "dough", "job_id": dough.job_id, "recipe_id": "recipe_plain_loaf"}
	s.staff._drop_carried(baker, a)
	eq(dough.stage, ProductionJob.DOUGH_ON_TABLE, "dough with no free mixer is parked on the table")
	eq(s.production.table_jobs().size(), 2, "both items wait on the table")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _step_until(s: SimulationRoot, cond: Callable, max_ticks: int = 6000) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		s.step(s.tick_seconds)
	return cond.call()


## Adonan yang sedang dibawa `owner` (lewat API produksi).
func _dough_in_hand(s: SimulationRoot, recipe_id: StringName, owner: StringName) -> ProductionJob:
	var j: ProductionJob = s.production.create_job(recipe_id, 1, owner)
	s.production.start_mixing(j.job_id, owner, 1.0)
	_step_until(s, func() -> bool: return j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP)
	s.production.pickup_dough(j.job_id, owner)
	return j


## Loyang matang yang sedang dibawa `owner`.
func _tray_in_hand(s: SimulationRoot, recipe_id: StringName, owner: StringName) -> ProductionJob:
	var j: ProductionJob = _dough_in_hand(s, recipe_id, owner)
	s.production.insert_oven(j.job_id, s.production.free_oven_for(j.recipe()).iid, owner, 1.0)
	_step_until(s, func() -> bool: return j.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP)
	s.production.pickup_tray(j.job_id, owner)
	return j


func _idle(p: PlayerTaskManager) -> bool:
	return p.current.is_empty() and p.commands.is_empty() and not p.actor.has_route()


func _put_take() -> void:
	var s: SimulationRoot = new_sim(5131)
	s.tutorial.skip()
	var p: PlayerTaskManager = s.player
	var table: EquipmentInstance = s.equipment.table_instance()
	check(table != null and table.placed, "every new game has a placed holding table")
	check(s.world.grid(table.floor_id).is_kitchen(table.anchor), "the table stands in the kitchen")
	var feedback: Array = []
	var cb := func(kind: StringName, _cell: Vector2i, _floor: StringName) -> void: feedback.append(kind)
	EventBus.feedback.connect(cb)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	# Adonan A diambil pemain dari mixer, lalu diparkir di meja.
	var a: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, PlayerTaskManager.PLAYER_ID)
	s.production.start_mixing(a.job_id, PlayerTaskManager.PLAYER_ID, 1.0)
	_step_until(s, func() -> bool: return a.stage == ProductionJob.MIX_DONE_WAITING_PICKUP)
	check(p.tap_equipment(mixer.iid), "tap the finished mixer")
	_step_until(s, func() -> bool: return not p.actor.carried.is_empty())
	check(p.tap_equipment(table.iid), "tap the table with dough in hand")
	_step_until(s, func() -> bool: return p.actor.carried.is_empty())
	eq(a.stage, ProductionJob.DOUGH_ON_TABLE, "the dough rests on the table")
	# Oven sedang memanggang B: adonan A tidak punya tujuan, ketukan hanya memberi ikon.
	var b: ProductionJob = _dough_in_hand(s, &"recipe_plain_loaf", &"test")
	s.production.insert_oven(b.job_id, oven.iid, &"test", 1.0)
	feedback.clear()
	check(p.tap_equipment(table.iid), "tap the table with empty hands while the oven is busy")
	_step_until(s, func() -> bool: return _idle(p))
	check(feedback.has(&"no_free_oven"), "no free oven: the table shows the oven-full icon")
	check(p.actor.carried.is_empty() and a.stage == ProductionJob.DOUGH_ON_TABLE, "the dough stays on the table")
	# Loyang B diangkat, lalu ikut diparkir di meja.
	_step_until(s, func() -> bool: return b.stage == ProductionJob.BAKE_DONE_WAITING_PICKUP)
	check(p.tap_equipment(oven.iid), "tap the finished oven")
	_step_until(s, func() -> bool: return not p.actor.carried.is_empty())
	eq(p.carried_job(), b, "the player carries tray B")
	check(p.tap_equipment(table.iid), "tap the table with the tray in hand")
	_step_until(s, func() -> bool: return p.actor.carried.is_empty())
	eq(b.stage, ProductionJob.TRAY_ON_TABLE, "the tray rests on the table")
	eq(b.carried_units, b.quantity_output, "every unit stays on the tray")
	# Oven kosong lagi: satu ketukan mengambil barang paling dekat basi.
	check(s.production.table_spoil_ratio(a) > s.production.table_spoil_ratio(b), "the older dough is closer to spoiling")
	check(p.tap_equipment(table.iid), "tap the table with empty hands")
	_step_until(s, func() -> bool: return not p.actor.carried.is_empty())
	eq(p.carried_job(), a, "one tap takes the most urgent item that has somewhere to go")
	eq(a.stage, ProductionJob.CARRIED_TO_OVEN, "the dough is back in hand")
	check(p.tap_equipment(oven.iid), "tap the oven")
	_step_until(s, func() -> bool: return p.actor.carried.is_empty())
	eq(a.stage, ProductionJob.BAKING, "dough from the table bakes")
	near(a.table_age_hours, 0.0, 0.0001, "baking starts the bread fresh")
	# Loyang dari meja ke rak; umur yang terkumpul di meja ikut terbawa.
	check(p.tap_equipment(table.iid), "tap the table for the tray")
	_step_until(s, func() -> bool: return not p.actor.carried.is_empty())
	eq(p.carried_job(), b, "the tray is taken next")
	var age: float = b.table_age_hours
	check(age > 0.0, "the tray aged on the table")
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	eq(p.place_into_slot(disp.iid, 0, b.carried_units), b.quantity_output, "the tray goes onto the shelf")
	var st: BreadStack = (s.display.slots(disp.iid)[0]["stacks"] as Array)[0]
	near(st.age_ingame_hours, age, 0.0001, "bread keeps the age it gathered on the table")
	EventBus.feedback.disconnect(cb)
	free_sim(s)


func _spoilage() -> void:
	var s: SimulationRoot = new_sim(5132)
	s.tutorial.skip()
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var expiry: float = loaf.expired_duration_hours
	var bread_rate: float = DataRegistry.balf("holding_table.bread_aging_rate")
	var dough_rate: float = bread_rate * DataRegistry.balf("holding_table.dough_aging_multiplier")
	near(dough_rate, bread_rate * 2.0, 0.0001, "dough ages twice as fast as bread")
	var notes: Array = []
	var cb := func(_p: int, key: String, _params: Dictionary, _icon: StringName) -> void: notes.append(key)
	EventBus.notify.connect(cb)
	var dough: ProductionJob = _dough_in_hand(s, loaf.id, &"test")
	check(s.production.put_on_table(dough.job_id), "dough parked")
	var tray: ProductionJob = _tray_in_hand(s, loaf.id, &"test")
	check(s.production.put_on_table(tray.job_id), "tray parked")
	var d0: float = dough.table_age_hours
	var t0: float = tray.table_age_hours
	s.production.age_table(2.0)
	near(tray.table_age_hours - t0, 2.0 * bread_rate, 0.0001, "bread ages at the base rate")
	near(dough.table_age_hours - d0, 2.0 * dough_rate, 0.0001, "dough ages at twice that rate")
	# Tick simulasi juga menuakan isi meja.
	var d1: float = dough.table_age_hours
	for i in 200:
		s.step(s.tick_seconds)
	near(dough.table_age_hours - d1, s.time.ingame_hours(200.0 * s.tick_seconds) * dough_rate, 0.001, "every tick ages the table")
	# Diambil lalu ditaruh lagi: umur tidak di-reset.
	var d2: float = dough.table_age_hours
	s.production.take_from_table(dough.job_id, &"test")
	s.production.put_on_table(dough.job_id)
	near(dough.table_age_hours, d2, 0.0001, "picking dough up and parking it again keeps its age")
	# Adonan basi dibuang sebagai waste.
	var waste0: float = s.economy.waste_cost_today
	s.production.age_table((expiry - dough.table_age_hours) / dough_rate + 0.01)
	check(s.production.get_job(dough.job_id) == null, "spoiled dough is thrown away")
	near(s.economy.waste_cost_today - waste0, dough.ingredient_value_kr, 0.001, "spoiled dough counts as waste")
	check(notes.has("ui_table_dough_spoiled"), "the player is told the dough went bad")
	check(s.production.get_job(tray.job_id) != null, "the tray is not spoiled yet")
	# Roti basi di meja juga dibuang.
	var waste1: float = s.economy.waste_cost_today
	var wasted0: int = int(s.statistics.stats.get("total_bread_wasted", 0.0))
	s.production.age_table((expiry - tray.table_age_hours) / bread_rate + 0.01)
	check(s.production.get_job(tray.job_id) == null, "spoiled bread is thrown away")
	near(s.economy.waste_cost_today - waste1, loaf.unit_cogs_kr() * float(tray.quantity_output), 0.001, "spoiled bread counts as waste")
	check(notes.has("ui_table_bread_spoiled"), "the player is told the bread went bad")
	eq(int(s.statistics.stats.get("total_bread_wasted", 0.0)) - wasted0, tray.quantity_output, "wasted units are counted")
	# Semalam (18:00 -> 05:00) isi meja menua 11 jam; adonan menua dua kali lipat.
	run_until(s, 16.5 * 3600.0)
	var late_tray: ProductionJob = _tray_in_hand(s, loaf.id, &"test")
	s.production.put_on_table(late_tray.job_id)
	var late_dough: ProductionJob = _dough_in_hand(s, loaf.id, &"test")
	s.production.put_on_table(late_dough.job_id)
	run_day(s, null)
	var before: float = late_tray.table_age_hours
	s.enter_after_hours()
	check(s.continue_to_next_day(), "continue to the next day")
	near(late_tray.table_age_hours - before, DataRegistry.balf("clock.overnight_aging_hours") * bread_rate, 0.001, "table bread ages 11 h overnight")
	check(s.production.get_job(late_dough.job_id) == null, "dough left out overnight spoils")
	EventBus.notify.disconnect(cb)
	free_sim(s)


func _rules() -> void:
	var s: SimulationRoot = new_sim(5133)
	s.tutorial.skip()
	var table: EquipmentInstance = s.equipment.table_instance()
	# Fixture bangunan: tidak dijual di pasar dan tidak bisa disimpan.
	check(not DataRegistry.table_definition().for_sale, "the table is not sold in the market")
	eq(s.equipment.put_away(table.iid), &"invalid", "the table cannot be put away")
	var tray: ProductionJob = _tray_in_hand(s, &"recipe_plain_loaf", &"test")
	s.production.put_on_table(tray.job_id)
	var dough: ProductionJob = _dough_in_hand(s, &"recipe_plain_loaf", &"test")
	s.production.put_on_table(dough.job_id)
	# Tanpa batas: isi meja tidak dihitung dalam batas job serentak (GDD 129).
	eq(s.production.active_job_count(), 0, "items on the table are not active jobs")
	s.production._max_jobs = 1
	eq(s.production.make_block_reason(&"recipe_plain_loaf", 1), "", "the job limit ignores the table")
	s.production._max_jobs = DataRegistry.bali("production.max_concurrent_jobs")
	# Bukan rak jualan.
	eq(s.display.total_sellable(), 0, "bread on the table is not for sale")
	# Upgrade lokasi boleh dengan isi meja; isinya ikut pindah.
	var age: float = tray.table_age_hours
	s.time.set_phase(TimeManager.AFTER_HOURS)
	s.debug_add_kr(s.next_location().upgrade_cost_kr)
	eq(s.upgrade_block_reason(), "", "items on the table do not block an upgrade")
	eq(s.upgrade_location(), "", "upgrade with items on the table")
	var t2: EquipmentInstance = s.equipment.table_instance()
	check(t2 != null and t2.placed, "the table is placed in the new location")
	check(t2 != null and s.world.grid(t2.floor_id).is_kitchen(t2.anchor), "the table is in the new kitchen")
	eq(s.production.table_jobs().size(), 2, "both items moved with the table")
	near(tray.table_age_hours, age, 0.0001, "the tray keeps its age")
	# Save/load menyimpan isi meja apa adanya.
	var s2: SimulationRoot = load_sim(json_copy(s.capture_save()))
	eq(s2.production.table_jobs().size(), 2, "table contents survive save/load")
	near(s2.production.get_job(tray.job_id).table_age_hours, age, 0.0001, "ages survive save/load")
	eq(s2.production.get_job(dough.job_id).stage, ProductionJob.DOUGH_ON_TABLE, "stages survive save/load")
	# Save lama (skema 3) belum punya meja: meja dibuat dan ditempatkan saat load.
	var old: Dictionary = json_copy(s.capture_save())
	var items: Array = (old["equipment_states"] as Dictionary)["items"]
	for i in range(items.size() - 1, -1, -1):
		if str((items[i] as Dictionary)["def_id"]) == String(DataRegistry.table_definition().id):
			items.remove_at(i)
	var jobs: Array = (old["production_jobs"] as Dictionary)["jobs"]
	for k in range(jobs.size() - 1, -1, -1):
		if str((jobs[k] as Dictionary)["stage"]).ends_with("_ON_TABLE"):
			jobs.remove_at(k)
	old["schema_version"] = 3
	var m: Dictionary = SaveManager.migrate(old)
	check(bool(m.get("ok", false)), "a v3 save migrates")
	var s3: SimulationRoot = load_sim(m["data"])
	var t3: EquipmentInstance = s3.equipment.table_instance()
	check(t3 != null and t3.placed, "an old save gets a placed holding table")
	free_sim(s3)
	free_sim(s2)
	free_sim(s)
