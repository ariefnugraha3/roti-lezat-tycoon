extends TestSuite
## Staf, save/profil, multi-lantai, upgrade lokasi, lifecycle, audio
## (GDD idle 3.4, 5.5, 8.7, 15.3; v3.1 107).

const TEST_DIR: String = "user://test_saves"
const FIXTURE_DIR: String = "res://tests/fixtures"
const GOLDEN: String = "res://tests/fixtures/golden_idle_v1.json"
const CLASSIC: String = "res://tests/fixtures/classic_v3_day4.json"


func tests() -> Array:
	return [
		{"id": "TEST_STAFF_001", "name": "idle 5.5: hiring is paid once from a rising cost list, staff start at once, role caps hold, there are no wages", "fn": _staff_hire},
		{"id": "TEST_SAVE_001", "name": "roundtrip golden idle fixture; classic v3.1 saves are detected and refused", "fn": _save_roundtrip},
		{"id": "TEST_SAVE_002", "name": "crash-safe/idempotent transaction recovery", "fn": _save_crash_safe, "expect_errors": true},
		{"id": "TEST_PROFILE_001", "name": "3-profile isolation", "fn": _profiles},
		{"id": "TEST_MULTIFLOOR_001", "name": "instant floor transition; an upstairs kitchen keeps working while nobody watches", "fn": _multifloor},
		{"id": "TEST_UPGRADE_001", "name": "idle 8.7: moving location while the shop is open loses nothing and keeps every level", "fn": _upgrade},
		{"id": "TEST_LIFECYCLE_001", "name": "idle 3.4: focus loss stops the simulation and saves; focus return resumes at once without a Game Paused screen", "fn": _lifecycle},
		{"id": "ACC_33_AUDIO_BUSES", "name": "33 audio buses follow Master in order and send to it; nothing calls AudioServer.add_bus (silences every sound on Web)", "fn": _audio_buses},
	]


## Bus audio (GDD 33, 35.2). Di Web (playback Sample, Godot 4.7.2) add_bus()
## menyisipkan bus JavaScript di depan Master; set_bus_send lalu membuat lingkaran
## yang dibungkam Web Audio, sehingga game sunyi total di browser. Bug itu tidak
## terlihat di desktop, jadi pemakaiannya dijaga lewat pemindaian sumber.
func _audio_buses() -> void:
	eq(AudioServer.get_bus_index("Master"), 0, "Master is bus 0")
	var first: int = AudioServer.get_bus_index(AudioManager.BUSES[0])
	for i in AudioManager.BUSES.size():
		var b: String = AudioManager.BUSES[i]
		var idx: int = AudioServer.get_bus_index(b)
		check(idx > 0, "%s bus exists after Master" % b)
		eq(idx, first + i, "%s keeps its order" % b)
		eq(String(AudioServer.get_bus_send(idx)), "Master", "%s sends to Master" % b)
	var files: Array[String] = []
	for root: String in ["res://autoload", "res://core", "res://gameplay", "res://ui", "res://scenes", "res://procedural", "res://audio", "res://tools"]:
		StringLint.collect_gd(root, files)
	var hits: Array[String] = []
	for f: String in files:
		if FileAccess.get_file_as_string(f).contains("AudioServer." + "add_bus("):
			hits.append(f.get_file())
	check(hits.is_empty(), "no script calls AudioServer.add_bus (use set_bus_count): %s" % ", ".join(hits))


func _use_test_dir() -> void:
	SaveManager.dir = TEST_DIR
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)


func _restore_dir() -> void:
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	SaveManager.simulation = null
	SaveManager.active_profile = &""


func _staff_hire() -> void:
	var s: SimulationRoot = new_sim(303)
	freeze_production(s)
	var costs: Array = DataRegistry.idle("staff.hire_cost")
	s.debug_add_kr(1.0e7)
	var bal: float = s.economy.balance
	near(s.staff.next_hire_cost(), float(costs[0]), 0.001, "first hire costs hire_cost[0]")
	eq(s.staff.hire(&"staff_cashier_budi"), &"", "hire cashier any time (no after-hours rule)")
	near(s.economy.balance, bal - float(costs[0]), 0.001, "paid once")
	eq(str(s.economy.ledger[s.economy.ledger.size() - 1]["category"]), "STAFF_HIRE", "ledger STAFF_HIRE")
	check(s.staff.is_working(&"staff_cashier_budi"), "the cashier starts working at once")
	var lane_b: QueueLane = s.queue.staff_lanes()[0]
	check(s.staff.cashier_for_lane(lane_b.id) != null, "the cashier takes the lane next to the owner's")
	check(s.staff.cashier_for_lane(s.queue.main_lane().id) == null, "lane A stays the owner's")
	eq(s.staff.hire(&"staff_cashier_sari"), &"full", "Tier 1 cashier cap is 1 (v3.1 6)")
	near(s.staff.next_hire_cost(), float(costs[1]), 0.001, "the second person costs hire_cost[1]")
	eq(s.staff.hire(&"staff_baker_joko"), &"", "hire baker")
	check(s.staff.is_working(&"staff_baker_joko"), "the baker starts working at once")
	run_day(s, null)
	run_day(s, null)
	var paid: float = 0.0
	for e: Dictionary in s.economy.ledger:
		if str(e["category"]) == "STAFF_HIRE":
			paid += -float(e["amount"])
	near(paid, float(costs[0]) + float(costs[1]), 0.001, "no wages over two days: only the two hire costs")
	s.economy.spend(s.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	jump_to_tier(s, 4)
	s.economy.spend(s.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	eq(s.staff.hire_block(&"staff_cashier_sari"), &"kr", "a hire needs the KR")
	free_sim(s)


## Skenario deterministik yang sama dengan fixture golden.
func _golden_scenario() -> SimulationRoot:
	var s: SimulationRoot = new_sim(2024, &"profile_1")
	var bot := SimBot.new(s)
	bot.manage = true
	run_hours(s, 4.0, bot)
	return s


func _save_roundtrip() -> void:
	_use_test_dir()
	if OS.get_cmdline_user_args().has("--update-fixtures"):
		var g: SimulationRoot = _golden_scenario()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
		var f: FileAccess = FileAccess.open(GOLDEN, FileAccess.WRITE)
		f.store_string(JSON.stringify(g.capture_save(), "\t", true, true))
		f.close()
		free_sim(g)
		print("      golden fixture rewritten: ", GOLDEN)
	check(FileAccess.file_exists(GOLDEN), "golden fixture exists (run with --update-fixtures to create it)")
	var golden: Dictionary = {}
	if FileAccess.file_exists(GOLDEN):
		golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
		eq(str(golden.get("game_mode", "")), "idle", "fixture is an idle save")
		eq(SaveManager.validate_save(golden, &"profile_1"), "", "golden fixture validates")
		var g2: SimulationRoot = load_sim(golden)
		var c1: Dictionary = g2.capture_save()
		same_state(logical_state(c1), logical_state(golden), "fixture roundtrips (logical state)")
		var g3: SimulationRoot = load_sim(json_copy(c1))
		same_state(state_of(g3), normalize_save(c1), "reload of a reloaded save is a fixed point")
		free_sim(g3)
		free_sim(g2)
	var s: SimulationRoot = _golden_scenario()
	if not golden.is_empty():
		same_state(state_of(s), normalize_save(golden), "live scenario matches the golden fixture (determinism)")
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "atomic write")
	var r: Dictionary = SaveManager.read_profile(&"profile_1")
	check(bool(r["ok"]) and not bool(r["used_backup"]), "read back main file")
	var s2: SimulationRoot = load_sim(r["data"])
	same_state(logical_state(s2.capture_save()), logical_state(s.capture_save()), "logical state identical after disk roundtrip")
	run_hours(s2, 2.0)
	eq(s2.check_invariants(), "", "loaded game keeps playing for 2 in-game hours")
	free_sim(s2)
	free_sim(s)
	# Save tycoon v3.1: dikenali dan ditolak dengan rapi (GDD idle 15.3).
	check(FileAccess.file_exists(CLASSIC), "classic v3.1 fixture exists")
	var classic: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(CLASSIC))
	check(SaveManager.is_classic(classic), "a v3.1 save is classic")
	var cf: FileAccess = FileAccess.open(SaveManager.main_path(&"profile_2"), FileAccess.WRITE)
	cf.store_string(JSON.stringify(classic))
	cf.close()
	var cr: Dictionary = SaveManager.read_profile(&"profile_2")
	check(not bool(cr["ok"]) and bool(cr.get("classic", false)), "reading it reports a classic save, not a corrupt one")
	var ch: Dictionary = SaveManager.read_header(&"profile_2")
	check(bool(ch["exists"]) and bool(ch["classic"]) and not bool(ch["corrupt"]), "the header marks it Classic save (not supported)")
	SaveManager.delete_profile(&"profile_2")
	check(not SaveManager.has_profile(&"profile_2"), "a classic save can be deleted")
	check(not bool(SaveManager.migrate({"schema_version": 99, "game_mode": "idle"})["ok"]), "newer-than-game save refused")
	_restore_dir()


func _save_crash_safe() -> void:
	_use_test_dir()
	var s: SimulationRoot = new_sim(505, &"profile_1")
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "first save")
	s.run_for(30.0)
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "second save rotates a backup")
	check(FileAccess.file_exists(SaveManager.backup_path(&"profile_1")), "one backup generation exists")
	var tmp: FileAccess = FileAccess.open(SaveManager.tmp_path(&"profile_1"), FileAccess.WRITE)
	tmp.store_string("{\"schema_version\": 1, \"trunc")
	tmp.close()
	var r: Dictionary = SaveManager.read_profile(&"profile_1")
	check(bool(r["ok"]) and not bool(r["used_backup"]), "stale .tmp ignored")
	var main: FileAccess = FileAccess.open(SaveManager.main_path(&"profile_1"), FileAccess.WRITE)
	main.store_string("{ not json")
	main.close()
	r = SaveManager.read_profile(&"profile_1")
	check(bool(r["ok"]) and bool(r["used_backup"]), "corrupt main falls back to the backup (v3.1 34.4)")
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "save after corruption")
	check(bool(SaveManager.read_profile(&"profile_1")["ok"]), "healthy again")
	var bad: Dictionary = s.capture_save()
	(bad["economy"] as Dictionary)["balance_kr"] = NAN
	check(not SaveManager.write_profile(&"profile_1", bad), "NaN save refused")
	check(bool(SaveManager.read_profile(&"profile_1")["ok"]), "previous save intact after refusal")
	free_sim(s)
	# Transaksi idempoten: save di tengah alur tidak menggandakan KR atau roti.
	var t: SimulationRoot = new_sim(506)
	freeze_production(t)
	t.demand.next_physical_at = NEVER
	t.demand.next_rotifood_at = NEVER
	stock(t, &"recipe_plain_loaf", 4)
	var o: DeliveryOrder = t.rotifood.debug_create_order({&"recipe_plain_loaf": 2}, 0.0)
	var guard0: int = 0
	while not o.packed and guard0 < 6000:
		t.step(t.tick_seconds)
		guard0 += 1
	check(o.packed, "order packed before the save")
	var snap: Dictionary = json_copy(t.capture_save())
	var t2: SimulationRoot = load_sim(snap)
	for sim_i: SimulationRoot in [t, t2]:
		var guard: int = 0
		while sim_i.rotifood.order(o.order_id).state != DeliveryOrder.COMPLETED and guard < 6000:
			sim_i.step(sim_i.tick_seconds)
			guard += 1
	near(t2.economy.balance, t.economy.balance, 0.001, "packed order credited exactly once after reload")
	eq(t2.display.total_units(), t.display.total_units(), "no bread duplicated")
	var t3: SimulationRoot = load_sim(snap)
	var t4: SimulationRoot = load_sim(snap)
	same_state(state_of(t3), state_of(t4), "loading is idempotent")
	for x: SimulationRoot in [t, t2, t3, t4]:
		free_sim(x)
	# Save saat memanggang: stage dan sisa timer identik (v3.1 81 no.15).
	var ob: SimulationRoot = new_sim(507)
	var guard2: int = 0
	var j: ProductionJob = null
	while j == null and guard2 < 20000:
		ob.step(ob.tick_seconds)
		guard2 += 1
		for jj: ProductionJob in ob.production.sorted_jobs():
			if jj.stage == ProductionJob.BAKING and jj.progress() > 0.3:
				j = jj
	check(j != null, "a batch is baking")
	if j != null:
		var ob2: SimulationRoot = load_sim(json_copy(ob.capture_save()))
		var j2: ProductionJob = ob2.production.get_job(j.job_id)
		eq(j2.stage, j.stage, "stage identical after load")
		near(j2.stage_elapsed, j.stage_elapsed, 0.000001, "bake timer identical after load")
		ob.run_for(5.0)
		ob2.run_for(5.0)
		eq(j2.stage, j.stage, "both progress the same")
		free_sim(ob2)
	# Pelanggan di antrean kembali ke slot kanonik tanpa duplikasi (v3.1 81 no.16).
	freeze_production(ob)
	ob.demand.next_physical_at = NEVER
	stock(ob, &"recipe_plain_loaf", 13, 1)
	for k in 3:
		ob.customers.try_admit({"archetype": &"customer_generic"})
		ob.run_for(3.0)
	ob.run_for(10.0)
	var units_before: int = ob.display.total_units()
	var held_before: int = 0
	for c: Customer in ob.customers.sorted():
		held_before += c.held_units()
	var ob3: SimulationRoot = load_sim(json_copy(ob.capture_save()))
	var held_after: int = 0
	for c2: Customer in ob3.customers.sorted():
		held_after += c2.held_units()
		var lane: QueueLane = ob3.queue.lane_of(c2.id)
		if lane != null and lane.line.has(c2.id):
			eq(c2.actor.cell(), ob3.queue.slot_cell(lane, lane.line.find(c2.id)), "%s snapped to its canonical slot" % c2.id)
	eq(held_after, held_before, "held bread not duplicated or lost")
	eq(ob3.display.total_units(), units_before, "display stock unchanged by load")
	eq(ob3.check_invariants(), "", "queue invariants after load")
	free_sim(ob3)
	free_sim(ob)
	_restore_dir()


func _multifloor() -> void:
	var s: SimulationRoot = new_sim(808)
	jump_to_tier(s, 2)
	check(s.world.location.is_multi_floor(), "Tier 2 has two floors")
	var kitchen: StringName = s.world.kitchen_floor()
	var store: StringName = s.world.store_floor()
	check(kitchen != store, "kitchen on another floor")
	var pub: Array[Dictionary] = s.world.find_route(store, GridMath.cell_center(s.world.entrance_cell()), kitchen, Vector2i(2, 3), FloorGrid.NAV_PUBLIC)
	check(pub.is_empty(), "public actors cannot route to the kitchen floor (v3.1 68)")
	var p: SimActor = s.player.actor
	var lane: QueueLane = s.queue.main_lane()
	p.place_at(store, lane.cashier_point)
	var storage: EquipmentInstance = s.equipment.storage_instance()
	var acc: Dictionary = s.world.access_of(storage.iid)
	eq(StringName(str(acc["floor"])), kitchen, "storage is upstairs")
	var route: Array[Dictionary] = s.world.find_route(store, p.pos, kitchen, acc["cell"], FloorGrid.NAV_STAFF)
	var portals: int = 0
	var length: float = 0.0
	var prev: Vector2 = p.pos
	for wp: Dictionary in route:
		if bool(wp["portal"]):
			portals += 1
			prev = wp["pos"]
			continue
		length += prev.distance_to(wp["pos"])
		prev = wp["pos"]
	eq(portals, 1, "one portal hop")
	check(p.go_to(s.world, kitchen, acc["cell"]), "owner routes upstairs")
	var guard: int = 0
	var switched: bool = false
	while p.has_route() and guard < 10000:
		p.step(s.tick_seconds, s.world)
		guard += 1
		switched = switched or p.floor_id == kitchen
	var travel: float = float(guard) * s.tick_seconds
	eq(p.floor_id, kitchen, "arrived upstairs")
	near(travel, length / p.speed_mps, s.tick_seconds * 2.0, "travel time = walking distance only (no stair penalty)")
	check(switched, "floor changed mid-route")
	# Dapur di atas tetap bekerja dan menahan isinya walau tidak ada yang melihat.
	freeze_production(s)
	s.run_for(30.0)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	eq(oven.floor_id, kitchen, "oven upstairs")
	if mixer.job_id < 0:
		var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
		s.production.start_mixing(j.job_id, &"test")
		j.claimed_by = &"test"
		s.run_for(j.stage_duration + 0.1)
		eq(j.stage, ProductionJob.MIX_DONE_WAITING_PICKUP, "upstairs mixer finished and holds the dough")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _upgrade() -> void:
	var s: SimulationRoot = new_sim(909)
	var bot := SimBot.new(s)
	bot.manage = true
	run_hours(s, 2.0, bot)
	s.debug_add_kr(1.0e12)
	for tier in range(2, 6):
		run_hours(s, 0.5, bot)
		var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
		s.upgrades.set_station_level(disp.iid, s.upgrades.level_cap())
		var units: int = s.display.total_units()
		for c: Customer in s.customers.sorted():
			units += c.held_units()
		for o: DeliveryOrder in s.rotifood.active_orders():
			for l: Variant in o.reserved_lots:
				units += ((l as Dictionary)["stack"] as BreadStack).quantity
		var job_units: int = 0
		for jj: ProductionJob in s.production.sorted_jobs():
			job_units += jj.quantity_output
		var levels: Dictionary = s.upgrades.capture()
		var equip_ids: Array = s.equipment.instances.keys()
		equip_ids.sort()
		var bal: float = s.economy.balance
		var cost: float = SimulationRoot.location_cost(tier)
		var before: Dictionary = logical_state(s.capture_save())
		var snap: Dictionary = s.capture_save()
		s.load_from_save(snap)
		same_state(logical_state(s.capture_save()), before, "T%d rollback snapshot restores exactly" % tier)
		eq(s.upgrade_location(), "", "upgrade to tier %d while the shop is open" % tier)
		eq(s.world.location.tier, tier, "now tier %d" % tier)
		eq(s.customers.active_count(), 0, "T%d customers walked out" % tier)
		var units_after: int = s.display.total_units()
		for o2: DeliveryOrder in s.rotifood.active_orders():
			for l2: Variant in o2.reserved_lots:
				units_after += ((l2 as Dictionary)["stack"] as BreadStack).quantity
		eq(units_after, units, "T%d no bread lost (held bread went back to the shelves)" % tier)
		var job_units2: int = 0
		for jj2: ProductionJob in s.production.sorted_jobs():
			job_units2 += jj2.quantity_output
		eq(job_units2, job_units, "T%d every batch in progress kept" % tier)
		eq(s.upgrades.capture(), levels, "T%d every level kept" % tier)
		var after_ids: Array = s.equipment.instances.keys()
		after_ids.sort()
		for old_id: Variant in equip_ids:
			check(after_ids.has(old_id), "T%d equipment instance %d kept" % [tier, int(old_id)])
		near(s.economy.balance, bal - cost, 0.001, "T%d only the upgrade cost is charged" % tier)
		check(s.world.layout_valid(), "T%d layout valid" % tier)
		check(s.equipment.storage_instance().placed, "T%d storage placed" % tier)
		for e: EquipmentInstance in s.equipment.all_sorted():
			check(e.placed, "T%d %s %d placed" % [tier, e.def_id, e.iid])
		eq(s.check_invariants(), "", "T%d invariants" % tier)
		run_hours(s, 0.5, bot)
		eq(s.check_invariants(), "", "T%d plays after upgrade" % tier)
	eq(s.upgrade_block_reason(), "ui_upgrade_max", "Tier 5 is the last location")
	free_sim(s)


func _lifecycle() -> void:
	_use_test_dir()
	var s: SimulationRoot = new_sim(111, &"profile_1")
	SaveManager.simulation = s
	SaveManager.active_profile = &"profile_1"
	PauseManager.lifecycle_enabled = true
	s.run_for(10.0)
	var writes: int = SaveManager.write_count()
	var resumed: Array = []
	var cb := func() -> void: resumed.append(true)
	PauseManager.lifecycle_resumed.connect(cb)
	PauseManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(PauseManager.is_paused() and PauseManager.has(PauseManager.LIFECYCLE), "focus loss stops the simulation (GDD idle 3.4)")
	SaveManager.request_autosave("lifecycle", true)
	eq(SaveManager.write_count(), writes + 1, "critical autosave written immediately")
	var fp: String = fingerprint(s)
	for i in 100:
		s.advance(1.0)
	eq(fingerprint(s), fp, "no live progression while away")
	PauseManager._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	eq(PauseManager.reasons().count(PauseManager.LIFECYCLE), 1, "repeated focus loss does not stack")
	PauseManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	check(not PauseManager.is_paused(), "focus return resumes at once, no Game Paused screen")
	eq(resumed.size(), 1, "lifecycle_resumed fires once")
	var t0: float = s.time.sim_seconds
	s.advance(3600.0)
	check(s.time.sim_seconds - t0 <= 0.25 * DataRegistry.sim_seconds_per_real_second() + 0.0001, "one huge frame never fast-forwards the live simulation")
	PauseManager.push(PauseManager.USER)
	PauseManager.on_focus_lost()
	PauseManager.on_focus_gained()
	check(PauseManager.has(PauseManager.USER), "the pause menu survives a focus return")
	PauseManager.lifecycle_resumed.disconnect(cb)
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false
	free_sim(s)
	_restore_dir()


func _profiles() -> void:
	_use_test_dir()
	var names: Array[String] = ["Alpha Bakery", "Beta Bakery", "Gamma Bakery"]
	for i in 3:
		var s: SimulationRoot = new_sim(700 + i, SaveManager.PROFILE_IDS[i])
		s.bakery_name = names[i]
		s.debug_add_kr(100.0 * (i + 1))
		check(SaveManager.write_profile(SaveManager.PROFILE_IDS[i], s.capture_save()), "write profile %d" % (i + 1))
		free_sim(s)
	for i2 in 3:
		var h: Dictionary = SaveManager.read_header(SaveManager.PROFILE_IDS[i2])
		eq(h.get("bakery_name"), names[i2], "profile %d header" % (i2 + 1))
		near(float(h.get("balance_kr", 0.0)), DataRegistry.idlef("start_kr") + 100.0 * (i2 + 1), 0.001, "profile %d balance" % (i2 + 1))
	# Merusak & menghapus profil 2 tidak menyentuh profil 1 dan 3.
	var f: FileAccess = FileAccess.open(SaveManager.main_path(&"profile_2"), FileAccess.WRITE)
	f.store_string("garbage")
	f.close()
	check(bool(SaveManager.read_profile(&"profile_1")["ok"]), "profile 1 unaffected by corrupt profile 2")
	check(bool(SaveManager.read_profile(&"profile_3")["ok"]), "profile 3 unaffected")
	SaveManager.delete_profile(&"profile_2")
	check(not SaveManager.has_profile(&"profile_2"), "profile 2 deleted")
	check(SaveManager.has_profile(&"profile_1") and SaveManager.has_profile(&"profile_3"), "others kept")
	# Save milik profil lain ditolak (id tidak cocok).
	var d1: Dictionary = SaveManager.read_profile(&"profile_1")["data"]
	check(SaveManager.validate_save(d1, &"profile_3") != "", "a profile cannot load another profile's data")
	# Autosave hanya menulis profil aktif.
	var s2: SimulationRoot = load_sim(SaveManager.read_profile(&"profile_3")["data"])
	SaveManager.simulation = s2
	SaveManager.active_profile = &"profile_3"
	s2.debug_add_kr(5.0)
	check(SaveManager.save_now(), "save active profile")
	near(float(SaveManager.read_header(&"profile_3")["balance_kr"]), DataRegistry.idlef("start_kr") + 305.0, 0.001, "active profile updated")
	near(float(SaveManager.read_header(&"profile_1")["balance_kr"]), DataRegistry.idlef("start_kr") + 100.0, 0.001, "inactive profile untouched")
	eq(SaveManager.latest_profile(), &"profile_3", "Continue picks the latest played profile")
	free_sim(s2)
	_restore_dir()
