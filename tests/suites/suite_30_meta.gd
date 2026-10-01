extends TestSuite
## GDD 107: pasar, staf, save/profil, multi-lantai, upgrade, lifecycle.

const TEST_DIR: String = "user://test_saves"
const FIXTURE_DIR: String = "res://tests/fixtures"
const GOLDEN: String = "res://tests/fixtures/golden_v3_day4.json"
const LEGACY_V1: String = "res://tests/fixtures/legacy_v1_day2.json"


func tests() -> Array:
	return [
		{"id": "TEST_MARKET_001", "name": "+3 in-game hour daytime delivery", "fn": _market_daytime},
		{"id": "TEST_MARKET_002", "name": "after-hours instant storage commit", "fn": _market_after_hours},
		{"id": "TEST_STAFF_001", "name": "duty and wage liability", "fn": _staff_wages},
		{"id": "TEST_SAVE_001", "name": "roundtrip golden fixture", "fn": _save_roundtrip},
		{"id": "TEST_SAVE_002", "name": "crash-safe/idempotent transaction recovery", "fn": _save_crash_safe, "expect_errors": true},
		{"id": "TEST_PROFILE_001", "name": "3-profile isolation", "fn": _profiles},
		{"id": "TEST_MULTIFLOOR_001", "name": "instant floor transition and inactive simulation", "fn": _multifloor},
		{"id": "TEST_UPGRADE_001", "name": "location migration no-loss invariant", "fn": _upgrade},
		{"id": "TEST_LIFECYCLE_001", "name": "app/browser focus-loss pause", "fn": _lifecycle},
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


func _market_daytime() -> void:
	var s: SimulationRoot = new_sim(301)
	check(not s.supply.purchase({&"ingredient_flour": 1})["ok"], "market locked on Day 1 (GDD 24A.1)")
	s.supply.unlock_market()
	run_until(s, 9.0 * 3600.0)
	var flour: int = s.inventory.count(&"ingredient_flour")
	var bal: float = s.economy.balance
	var r: Dictionary = s.supply.purchase({&"ingredient_flour": 2, &"ingredient_sugar": 1})
	check(bool(r["ok"]) and not bool(r["instant"]), "daytime purchase goes to a courier")
	near(s.economy.balance, bal - 2 * 150.0 - 80.0, 0.001, "paid immediately at fixed prices (GDD 5.2)")
	eq(s.inventory.count(&"ingredient_flour"), flour, "not in storage yet")
	eq(s.supply.in_transit_units(), 3, "3 units in transit")
	# Kapasitas termasuk in_transit (GDD 24A.2).
	var room: int = s.supply.max_additional_units()
	eq(room, s.inventory.capacity() - s.inventory.total_units() - 3, "capacity counts in-transit units")
	check(not s.supply.purchase({&"ingredient_flour": room + 1})["ok"], "over-capacity purchase refused")
	run_until(s, 12.0 * 3600.0 - 60.0)
	eq(s.inventory.count(&"ingredient_flour"), flour, "still not delivered before +3 h")
	# Kurir masuk tepat 12:00 lalu commit saat paket diletakkan.
	var t_commit: float = -1.0
	while s.time.time_seconds < 13.0 * 3600.0:
		s.step(s.tick_seconds)
		if t_commit < 0.0 and s.inventory.count(&"ingredient_flour") == flour + 2:
			t_commit = s.time.time_seconds
	check(t_commit >= 12.0 * 3600.0, "committed no earlier than 12:00")
	check(t_commit < 12.0 * 3600.0 + 15.0 * 60.0, "courier commits shortly after arrival (at %s)" % Tx.clock(t_commit))
	eq(s.supply.in_transit_units(), 0, "nothing left in transit")
	# Order yang belum sampai pukul 18:00 di-commit otomatis (GDD 70, 104).
	run_until(s, 16.0 * 3600.0)
	s.supply.purchase({&"ingredient_egg": 1})
	run_day(s, null)
	eq(s.inventory.count(&"ingredient_egg"), 1, "late order committed at close")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _market_after_hours() -> void:
	var s: SimulationRoot = new_sim(302)
	run_day(s, null)
	s.enter_after_hours()
	s.supply.unlock_market()
	var before: int = s.inventory.count(&"ingredient_butter")
	var r: Dictionary = s.supply.purchase({&"ingredient_butter": 4})
	check(bool(r["ok"]) and bool(r["instant"]), "after-hours purchase is instant (GDD 5.2.3.E)")
	eq(s.inventory.count(&"ingredient_butter"), before + 4, "straight into storage")
	eq(s.supply.in_transit_units(), 0, "no courier")
	eq(s.supply.couriers.size(), 0, "no courier actor")
	var bal: float = s.economy.balance
	check(not s.supply.purchase({&"ingredient_butter": 1000})["ok"], "capacity still enforced")
	near(s.economy.balance, bal, 0.001, "refused purchase costs nothing")
	# Save/load setelahnya: stok tidak digandakan.
	var snap: Dictionary = json_copy(s.capture_save())
	var s2: SimulationRoot = load_sim(snap)
	eq(s2.inventory.count(&"ingredient_butter"), before + 4, "reload does not re-commit")
	same_state(logical_state(s2.capture_save()), logical_state(snap), "save after an instant purchase equals the loaded state")
	free_sim(s2)
	free_sim(s)


func _staff_wages() -> void:
	var s: SimulationRoot = new_sim(303)
	eq(s.staff.hire(&"staff_cashier_budi"), &"after_hours", "hiring only after closing (GDD 87)")
	run_day(s, null)
	s.enter_after_hours()
	s.debug_add_kr(10000.0)
	eq(s.staff.hire(&"staff_cashier_budi"), &"", "hire cashier")
	eq(s.staff.hire(&"staff_cashier_sari"), &"full", "Tier 1 cashier cap is 1 (GDD 6)")
	eq(s.staff.hire(&"staff_baker_joko"), &"", "hire baker")
	near(s.staff.wage_liability_today, 0.0, 0.001, "hiring does not charge today's wages")
	s.continue_to_next_day()
	# 05:00: liabilitas terkunci untuk staf on_duty.
	near(s.staff.wage_liability_today, 150.0 + 180.0, 0.001, "05:00 wage liability = on-duty wages")
	check(s.staff.cashier_for_lane(s.queue.main_lane().id) != null, "cashier assigned to the main lane")
	# Libur di tengah hari & pecat: gaji hari ini tetap (GDD 3.4, 87.3).
	run_until(s, 10.0 * 3600.0)
	s.staff.set_on_duty(&"staff_baker_joko", false)
	s.staff.fire(&"staff_cashier_budi")
	near(s.staff.wage_liability_today, 330.0, 0.001, "liability fixed at 05:00")
	check(s.staff.cashier_for_lane(s.queue.main_lane().id) == null, "fired cashier leaves the lane")
	check(s.queue.is_open(s.queue.main_lane()), "main lane falls back to the player")
	# Kembali on_duty di tengah hari tidak bekerja/dibayar sampai 05:00 berikutnya.
	s.staff.set_on_duty(&"staff_baker_joko", true)
	check(s.staff.working_ids().is_empty(), "rescheduled staff does not start mid-day")
	var bal: float = s.economy.balance
	run_day(s, null)
	near(s.economy.today_total(&"STAFF_WAGE"), -330.0, 0.001, "settlement charges the locked liability once")
	check(s.economy.balance <= bal, "wages paid")
	s.enter_after_hours()
	s.continue_to_next_day()
	near(s.staff.wage_liability_today, 180.0, 0.001, "next day only the on-duty baker is liable")
	eq(s.staff.working_ids(), [&"staff_baker_joko"], "baker working again")
	free_sim(s)


## Skenario deterministik yang sama dengan fixture golden.
func _golden_scenario() -> SimulationRoot:
	var s: SimulationRoot = new_sim(2024, &"profile_1")
	var bot := SimBot.new(s)
	for d in 3:
		run_day(s, bot)
		bot.after_hours()
	run_until(s, 10.0 * 3600.0, bot)
	return s


func _save_roundtrip() -> void:
	_use_test_dir()
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--update-fixtures"):
		var g: SimulationRoot = _golden_scenario()
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(FIXTURE_DIR))
		var f: FileAccess = FileAccess.open(GOLDEN, FileAccess.WRITE)
		f.store_string(JSON.stringify(g.capture_save(), "\t", true, true))
		f.close()
		free_sim(g)
		print("      golden fixture rewritten: ", GOLDEN)
		# Save v1: bentuk skema sebelum RNG per stream, analitik, dan flag rollover.
		var l: SimulationRoot = new_sim(55, &"profile_2")
		run_day(l, SimBot.new(l))
		l.enter_after_hours()
		l.continue_to_next_day()
		var v1: Dictionary = json_copy(l.capture_save())
		for k: String in ["rng_states", "recipe_analytics", "statistics", "catalog_versions", "ui_restore", "active_floor_id"]:
			v1.erase(k)
		(v1["flags"] as Dictionary).erase("last_freshness_rollover_day")
		(v1["flags"] as Dictionary).erase("economy_overflowed")
		# v1 juga belum mengenal pengunjung lihat-lihat (GDD 20.12).
		for k2: String in ["next_window_num", "window_shoppers_today"]:
			(v1["customers"] as Dictionary).erase(k2)
		for k3: String in ["scripted_window_shoppers", "next_window_shopper_at"]:
			(v1["demand"] as Dictionary).erase(k3)
		v1["schema_version"] = 1
		v1["master_seed"] = 55
		var f2: FileAccess = FileAccess.open(LEGACY_V1, FileAccess.WRITE)
		f2.store_string(JSON.stringify(v1, "\t", true, true))
		f2.close()
		free_sim(l)
	check(FileAccess.file_exists(GOLDEN), "golden fixture exists (run with --update-fixtures to create it)")
	var golden: Dictionary = {}
	if FileAccess.file_exists(GOLDEN):
		golden = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
		eq(SaveManager.validate_save(golden, &"profile_1"), "", "golden fixture validates")
		# Load -> capture: state logis identik dengan fixture, dan load kedua
		# tidak mengubah apa pun lagi (titik tetap rekonstruksi kanonik).
		var g2: SimulationRoot = load_sim(golden)
		var c1: Dictionary = g2.capture_save()
		same_state(logical_state(c1), logical_state(golden), "fixture roundtrips (logical state)")
		var g3: SimulationRoot = load_sim(json_copy(c1))
		same_state(state_of(g3), normalize_save(c1), "reload of a reloaded save is a fixed point")
		free_sim(g3)
		free_sim(g2)
	# Skenario hidup: sama dengan fixture, tulis ke disk, baca, muat, lanjutkan.
	var s: SimulationRoot = _golden_scenario()
	if not golden.is_empty():
		same_state(state_of(s), normalize_save(golden), "live scenario matches the golden fixture (determinism)")
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "atomic write")
	var r: Dictionary = SaveManager.read_profile(&"profile_1")
	check(bool(r["ok"]) and not bool(r["used_backup"]), "read back main file")
	var s2: SimulationRoot = load_sim(r["data"])
	same_state(logical_state(s2.capture_save()), logical_state(s.capture_save()), "logical state identical after disk roundtrip")
	var bot_b := SimBot.new(s2)
	for i in 2400:
		bot_b.think()
		s2.step(s2.tick_seconds)
	eq(s2.check_invariants(), "", "loaded game keeps playing for 2 in-game hours")
	free_sim(s2)
	free_sim(s)
	# Migrasi v1 -> v3.
	check(FileAccess.file_exists(LEGACY_V1), "legacy v1 fixture exists")
	if FileAccess.file_exists(LEGACY_V1):
		var legacy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEGACY_V1))
		var m: Dictionary = SaveManager.migrate(legacy)
		check(bool(m["ok"]), "v1 save migrates")
		var md: Dictionary = m["data"]
		eq(int(md["schema_version"]), SaveManager.current_schema_version(), "migrated to the current schema")
		eq(SaveManager.validate_save(md, StringName(str(md["profile_id"]))), "", "migrated save validates")
		var s3: SimulationRoot = load_sim(md)
		eq(s3.time.day, int(legacy["day"]), "migrated day kept")
		near(s3.economy.balance, float((legacy["economy"] as Dictionary)["balance_kr"]), 0.001, "migrated balance kept")
		eq(s3.check_invariants(), "", "migrated game invariants")
		s3.run_for(60.0)
		free_sim(s3)
	check(not bool(SaveManager.migrate({"schema_version": 99})["ok"]), "newer-than-game save refused")
	_restore_dir()


func _save_crash_safe() -> void:
	_use_test_dir()
	var s: SimulationRoot = new_sim(505, &"profile_1")
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "first save")
	s.run_for(30.0)
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "second save rotates a backup")
	check(FileAccess.file_exists(SaveManager.backup_path(&"profile_1")), "one backup generation exists")
	# Crash di tengah penulisan: .tmp setengah jadi diabaikan, main tetap utuh.
	var tmp: FileAccess = FileAccess.open(SaveManager.tmp_path(&"profile_1"), FileAccess.WRITE)
	tmp.store_string("{\"schema_version\": 3, \"trunc")
	tmp.close()
	var r: Dictionary = SaveManager.read_profile(&"profile_1")
	check(bool(r["ok"]) and not bool(r["used_backup"]), "stale .tmp ignored")
	# Main rusak -> backup dipakai dan main rusak tidak menimpa backup baik.
	var main: FileAccess = FileAccess.open(SaveManager.main_path(&"profile_1"), FileAccess.WRITE)
	main.store_string("{ not json")
	main.close()
	r = SaveManager.read_profile(&"profile_1")
	check(bool(r["ok"]) and bool(r["used_backup"]), "corrupt main falls back to the backup (GDD 34.4)")
	check(SaveManager.write_profile(&"profile_1", s.capture_save()), "save after corruption")
	check(bool(SaveManager.read_profile(&"profile_1")["ok"]), "healthy again")
	# Save NaN ditolak dan file lama tetap.
	var bad: Dictionary = s.capture_save()
	(bad["economy"] as Dictionary)["balance_kr"] = NAN
	check(not SaveManager.write_profile(&"profile_1", bad), "NaN save refused")
	check(bool(SaveManager.read_profile(&"profile_1")["ok"]), "previous save intact after refusal")
	free_sim(s)
	# Transaksi idempoten: save di tengah alur tidak menggandakan KR/roti/bahan.
	var t: SimulationRoot = new_sim(506)
	t.demand.scripted_walkins.clear()
	t.demand.scripted_orders.clear()
	run_until(t, 8.0 * 3600.0 + 10.0)
	stock(t, &"recipe_plain_loaf", 4)
	var o: DeliveryOrder = t.rotifood.create_scripted_order(&"recipe_plain_loaf", 2)
	t.rotifood.pack(o.order_id)
	o.driver_arrival_time = t.time.sim_seconds
	t.supply.unlock_market()
	t.supply.purchase({&"ingredient_flour": 1})
	var snap: Dictionary = json_copy(t.capture_save())
	var t2: SimulationRoot = load_sim(snap)
	for sim_i: SimulationRoot in [t, t2]:
		var guard: int = 0
		while sim_i.rotifood.order(o.order_id).state != DeliveryOrder.COMPLETED and guard < 6000:
			sim_i.step(sim_i.tick_seconds)
			guard += 1
	near(t2.economy.balance, t.economy.balance, 0.001, "packed order credited exactly once after reload")
	eq(t2.display.total_units(), t.display.total_units(), "no bread duplicated")
	eq(t2.supply.in_transit_units(), t.supply.in_transit_units(), "supply order not duplicated")
	# Load dua kali dari save yang sama menghasilkan state yang sama.
	var t3: SimulationRoot = load_sim(snap)
	var t4: SimulationRoot = load_sim(snap)
	same_state(state_of(t3), state_of(t4), "loading is idempotent")
	# Save pukul 18:00 sebelum rollover: penuaan malam tepat sekali.
	run_day(t3, null)
	var eve: Dictionary = json_copy(t3.capture_save())
	var t5: SimulationRoot = load_sim(eve)
	t3.enter_after_hours()
	t3.continue_to_next_day()
	t5.enter_after_hours()
	t5.continue_to_next_day()
	same_state(logical_state(t5.capture_save()), logical_state(t3.capture_save()), "evening save + reload applies overnight aging once")
	for x: SimulationRoot in [t, t2, t3, t4, t5]:
		free_sim(x)
	# GDD 81 no.15: save saat OVERBAKING -> stage & sisa timer identik.
	var ob: SimulationRoot = new_sim(507)
	var oven: EquipmentInstance = ob.equipment.placed_list(&"oven")[0]
	var j: ProductionJob = ob.production.create_job(&"recipe_plain_loaf", 1, &"test")
	ob.production.start_mixing(j.job_id, &"test", 1.0)
	ob.run_for(j.stage_duration + 0.1)
	ob.production.pickup_dough(j.job_id, &"test")
	ob.production.insert_oven(j.job_id, oven.iid, &"test", 1.0)
	ob.run_for(j.stage_duration + oven.def().perfect_window_seconds + 2.0)
	eq(j.stage, ProductionJob.OVERBAKING, "oven overbaking before save")
	var ob2: SimulationRoot = load_sim(json_copy(ob.capture_save()))
	var j2: ProductionJob = ob2.production.get_job(j.job_id)
	eq(j2.stage, j.stage, "stage identical after load")
	near(j2.burn_elapsed, j.burn_elapsed, 0.000001, "burn timer identical after load")
	near(ob2.production.current_quality(j2), ob.production.current_quality(j), 0.000001, "quality identical after load")
	ob.run_for(5.0)
	ob2.run_for(5.0)
	eq(j2.stage, j.stage, "both burn at the same moment")
	# GDD 81 no.16: pelanggan di antrean kembali ke slot kanonik tanpa duplikasi.
	ob.demand.scripted_walkins.clear()
	run_until(ob, 8.0 * 3600.0 + 10.0)
	stock(ob, &"recipe_plain_loaf", 6, 1)
	for k in 3:
		ob.customers.try_admit({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 1, "patience_override": 999.0})
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
	free_sim(ob2)
	free_sim(ob)
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
		near(float(h.get("balance_kr", 0.0)), 1000.0 + 100.0 * (i2 + 1), 0.001, "profile %d balance" % (i2 + 1))
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
	near(float(SaveManager.read_header(&"profile_3")["balance_kr"]), 1305.0, 0.001, "active profile updated")
	near(float(SaveManager.read_header(&"profile_1")["balance_kr"]), 1100.0, 0.001, "inactive profile untouched")
	eq(SaveManager.latest_profile(), &"profile_3", "Continue picks the latest played profile")
	free_sim(s2)
	_restore_dir()


func _multifloor() -> void:
	var s: SimulationRoot = new_sim(808)
	jump_to_tier(s, 2)
	check(s.world.location.is_multi_floor(), "Tier 2 has two floors")
	var kitchen: StringName = s.world.kitchen_floor()
	var store: StringName = s.world.store_floor()
	check(kitchen != store, "kitchen on another floor")
	# Pelanggan tidak pernah punya rute ke lantai dapur (GDD 68).
	var pub: Array[Dictionary] = s.world.find_route(store, GridMath.cell_center(s.world.entrance_cell()), kitchen, Vector2i(2, 3), FloorGrid.NAV_PUBLIC)
	check(pub.is_empty(), "public actors cannot route to the kitchen floor")
	# Pemain: rute lewat portal, perpindahan instan tanpa biaya waktu.
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
	check(p.go_to(s.world, kitchen, acc["cell"]), "player routes upstairs")
	var t0: float = s.time.sim_seconds
	var switched_at: float = -1.0
	var guard: int = 0
	while p.has_route() and guard < 10000:
		p.step(s.tick_seconds, s.world)
		guard += 1
		if switched_at < 0.0 and p.floor_id == kitchen:
			switched_at = float(guard) * s.tick_seconds
	var travel: float = float(guard) * s.tick_seconds
	eq(p.floor_id, kitchen, "arrived upstairs")
	near(travel, length / p.speed_mps, s.tick_seconds * 2.0, "travel time = walking distance only (no stair penalty)")
	check(switched_at > 0.0, "floor changed mid-route")
	# Lantai yang tidak dilihat tetap disimulasikan: oven dapur memanggang & gosong
	# walau pemain berada di lantai toko.
	p.place_at(store, lane.cashier_point)
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
	s.production.start_mixing(j.job_id, &"test", 1.0)
	s.run_for(j.stage_duration + 0.1)
	eq(j.stage, ProductionJob.MIX_DONE_WAITING_PICKUP, "upstairs mixer finished while player downstairs")
	s.production.pickup_dough(j.job_id, &"test")
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	eq(oven.floor_id, kitchen, "oven upstairs")
	s.production.insert_oven(j.job_id, oven.iid, &"test", 1.0)
	s.run_for(j.stage_duration + oven.def().burn_grace_seconds() + 0.5)
	eq(j.stage, ProductionJob.BURNT, "off-floor oven burns unattended (GDD 30, 62)")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _upgrade() -> void:
	var s: SimulationRoot = new_sim(909)
	s.debug_add_kr(2000000.0)
	# Perabot cadangan belum terpasang + stok gudang.
	var spare: EquipmentInstance = s.equipment.create_instance(&"mixer_t1")
	for tier in range(2, 6):
		s.time.set_phase(TimeManager.AFTER_HOURS)
		var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
		var cap: int = s.display.free_units(disp.iid)
		stock(s, &"recipe_plain_loaf", mini(4, cap), 0, disp.iid)
		var units: int = s.display.total_units()
		var ages: float = _total_age(s)
		var inv: Dictionary = s.inventory.on_hand.duplicate()
		var equip_ids: Array = s.equipment.instances.keys()
		equip_ids.sort()
		var bal: float = s.economy.balance
		var cost: float = s.next_location().upgrade_cost_kr
		# Snapshot/rollback harus memulihkan persis (jalur kegagalan GDD 105).
		var fp_before: Dictionary = state_of(s)
		var snap: Dictionary = s.capture_save()
		s.debug_add_kr(1.0)
		s.load_from_save(snap)
		same_state(state_of(s), fp_before, "T%d rollback snapshot restores exactly" % tier)
		eq(s.upgrade_location(), "", "upgrade to tier %d" % tier)
		eq(s.world.location.tier, tier, "now tier %d" % tier)
		eq(s.display.total_units(), units, "T%d no bread lost" % tier)
		near(_total_age(s), ages, 0.0001, "T%d freshness kept" % tier)
		eq(s.inventory.on_hand, inv, "T%d ingredients kept" % tier)
		var after_ids: Array = s.equipment.instances.keys()
		after_ids.sort()
		eq(after_ids, equip_ids, "T%d every equipment instance kept" % tier)
		near(s.economy.balance, bal - cost, 0.001, "T%d only the upgrade cost is charged" % tier)
		for d: Variant in s.display.display_ids():
			if s.display.used(int(d)) > 0:
				check(s.equipment.get_inst(int(d)).placed, "T%d displays holding bread are placed" % tier)
		check(s.world.layout_valid(), "T%d layout valid" % tier)
		check(s.equipment.storage_instance().placed, "T%d storage placed" % tier)
		eq(s.check_invariants(), "", "T%d invariants" % tier)
		s.continue_to_next_day()
		var bot := SimBot.new(s)
		run_until(s, 9.0 * 3600.0, bot)
		eq(s.check_invariants(), "", "T%d plays after upgrade" % tier)
		# GDD 105 no.11: job produksi harus kosong sebelum upgrade berikutnya.
		check(bot.finish_production(), "T%d kitchen cleared before closing" % tier)
		run_day(s, null)
	check(s.equipment.get_inst(spare.iid) != null, "spare equipment survives all upgrades")
	eq(s.upgrade_block_reason(), "ui_upgrade_max", "Tier 5 is the last location")
	free_sim(s)


func _total_age(s: SimulationRoot) -> float:
	var t: float = 0.0
	for d: Variant in s.display.display_ids():
		for slot: Dictionary in s.display.slots(int(d)):
			for st: BreadStack in slot["stacks"]:
				t += st.age_ingame_hours * st.quantity
	return t


func _lifecycle() -> void:
	_use_test_dir()
	var s: SimulationRoot = new_sim(111, &"profile_1")
	SaveManager.simulation = s
	SaveManager.active_profile = &"profile_1"
	PauseManager.lifecycle_enabled = true
	s.run_for(10.0)
	var writes: int = SaveManager.write_count()
	PauseManager._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	check(PauseManager.is_paused() and PauseManager.has(PauseManager.LIFECYCLE), "focus loss pauses (GDD 90)")
	# Autosave kritis diminta oleh GameRoot; di sini dipicu langsung.
	SaveManager.request_autosave("lifecycle", true)
	eq(SaveManager.write_count(), writes + 1, "critical autosave written immediately")
	var fp: String = fingerprint(s)
	for i in 100:
		s.advance(1.0)
	eq(fingerprint(s), fp, "no progression while paused")
	PauseManager._notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	eq(PauseManager.reasons().count(PauseManager.LIFECYCLE), 1, "repeated focus loss does not stack")
	PauseManager.resume_from_lifecycle()
	check(not PauseManager.is_paused(), "resume clears the lifecycle pause")
	# Tidak ada progres offline: satu frame raksasa dibatasi 0,25 s nyata.
	var t0: float = s.time.sim_seconds
	s.advance(3600.0)
	check(s.time.sim_seconds - t0 <= 0.25 * DataRegistry.sim_seconds_per_real_second() + 0.0001, "no offline catch-up after returning (GDD 113)")
	# Pause lain (modal) tidak dicabut oleh resume lifecycle.
	PauseManager.push(PauseManager.USER)
	PauseManager.on_focus_lost()
	PauseManager.resume_from_lifecycle()
	check(PauseManager.has(PauseManager.USER), "user pause survives lifecycle resume")
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false
	free_sim(s)
	_restore_dir()
