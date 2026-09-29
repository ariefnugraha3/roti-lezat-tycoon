extends TestSuite
## Test inti GDD 107: boot, jam, RNG, produksi, freshness, inventori, ekonomi.


func tests() -> Array:
	return [
		{"id": "TEST_BOOT_001", "name": "catalog validation and clean boot", "fn": _boot},
		{"id": "TEST_TIME_001", "name": "05:00/08:00/18:00 boundaries", "fn": _time_boundaries},
		{"id": "TEST_TIME_002", "name": "pause and 1x/2x/3x determinism", "fn": _time_determinism},
		{"id": "TEST_RNG_001", "name": "separated deterministic streams", "fn": _rng_streams},
		{"id": "ACC_116_ID_ORDER", "name": "text IDs sort alphabetically in every session", "fn": _id_order},
		{"id": "TEST_PRODUCTION_001", "name": "ingredient -> mixer -> oven -> display happy path", "fn": _production_happy},
		{"id": "TEST_PRODUCTION_002", "name": "burn thresholds per oven tier", "fn": _burn_thresholds},
		{"id": "TEST_PRODUCTION_003", "name": "stage duration formula", "fn": _stage_durations},
		{"id": "TEST_FRESHNESS_001", "name": "cross-day freshness aging", "fn": _freshness},
		{"id": "TEST_INVENTORY_001", "name": "atomic consume/rollback", "fn": _inventory_atomic},
		{"id": "TEST_ECONOMY_001", "name": "price/rounding/ledger reconciliation", "fn": _economy},
	]


func _boot() -> void:
	check(DataRegistry.load_catalogs(), "catalogs reload cleanly")
	eq(DataRegistry.errors, [], "catalog validation errors (GDD 101, 134)")
	check(DataRegistry.is_valid(), "registry valid")
	check(DataRegistry.recipes().size() > 0, "recipes loaded")
	for r: RecipeDefinition in DataRegistry.recipes():
		# batch_cost_kr turunan harus sama dengan jumlah harga bahan (GDD 63.1).
		var cost: float = 0.0
		for ing: StringName in r.ingredients.keys():
			cost += DataRegistry.ingredient(ing).fixed_buy_price_kr * float(r.ingredients[ing])
		near(cost, r.batch_cost_kr, 0.01, "%s batch_cost_kr" % r.id)
		check(DataRegistry.has_text(String(r.localization_key)), "%s has an English name" % r.id)
	for tier in range(1, 6):
		check(DataRegistry.location_by_tier(tier) != null, "location tier %d" % tier)
	for n: String in ["GameLogger", "DataRegistry", "EventBus", "SettingsManager", "PauseManager", "SaveManager", "AudioManager"]:
		check(runner.get_tree().root.has_node(n), "autoload %s (GDD 35.2)" % n)
	var s: SimulationRoot = new_sim()
	eq(s.check_invariants(), "", "invariants right after boot")
	free_sim(s)


func _time_boundaries() -> void:
	var s: SimulationRoot = new_sim()
	near(s.time.time_seconds, 5.0 * 3600.0, 0.001, "day starts 05:00")
	eq(s.time.phase, TimeManager.PREPARATION, "05:00 is preparation")
	# 1 jam in-game = 120 detik nyata pada 1x (GDD 15.2).
	near(s.time.sim_seconds_for_hours(1.0), 120.0, 0.001, "1 in-game hour = 120 s")
	run_until(s, 8.0 * 3600.0 - 30.0)
	eq(s.time.phase, TimeManager.PREPARATION, "still preparation just before 08:00")
	check(not s.time.is_open(), "closed before 08:00")
	run_until(s, 8.0 * 3600.0)
	eq(s.time.phase, TimeManager.OPEN, "store opens automatically at 08:00")
	run_day(s, null)
	near(s.time.time_seconds, 18.0 * 3600.0, 0.001, "clock clamps to 18:00")
	eq(s.time.phase, TimeManager.SUMMARY, "18:00 closes into the summary")
	# Settlement tepat sekali: step setelah tutup tidak mengubah apa pun.
	var bal: float = s.economy.balance
	s.step(s.tick_seconds)
	near(s.economy.balance, bal, 0.001, "no ticks after close")
	s.enter_after_hours()
	eq(s.time.phase, TimeManager.AFTER_HOURS, "after-hours")
	check(s.continue_to_next_day(), "continue to next day")
	eq(s.time.day, 2, "day 2")
	near(s.time.time_seconds, 5.0 * 3600.0, 0.001, "day 2 starts 05:00")
	free_sim(s)


func _time_determinism() -> void:
	# Input identik pada tick identik: stok & job disiapkan sebelum jam berjalan,
	# lalu hanya kecepatan yang berbeda. Pelanggan Hari 1, mixer, oven, kasir
	# pemain yang diam, dan penuaan roti semuanya ikut berjalan.
	var target_ticks: int = int(3.4 * 3600.0 / DataRegistry.balf("clock.ingame_seconds_per_sim_second") / 0.05)
	var states: Array[Dictionary] = []
	for speed: int in [1, 2, 3]:
		var s: SimulationRoot = new_sim(4242)
		stock(s, &"recipe_plain_loaf", 6, 0)
		stock(s, &"recipe_plain_loaf", 6, 1)
		var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
		s.production.start_mixing(j.job_id, &"test", 1.0)
		s.time.set_speed(speed)
		eq(s.time.speed, speed, "speed %dx applied" % speed)
		var frames: int = 0
		while _ticks(s) < target_ticks - 40:
			s.advance(1.0 / 30.0)
			frames += 1
			if frames == 50:
				# Pause di tengah: tidak ada yang berubah selama dijeda.
				PauseManager.push(PauseManager.USER)
				var before: Dictionary = state_of(s)
				for i in 30:
					s.advance(1.0 / 30.0)
				same_state(state_of(s), before, "paused simulation does not change (speed %d)" % speed)
				PauseManager.pop(PauseManager.USER)
		while _ticks(s) < target_ticks:
			s.step(s.tick_seconds)
		check(frames * speed < target_ticks * 2, "speed %dx needed %d frames" % [speed, frames])
		states.append(state_of(s))
		free_sim(s)
	same_state(states[1], states[0], "2x reaches the 1x state after the same ticks")
	same_state(states[2], states[0], "3x reaches the 1x state after the same ticks")


## `Array.sort()` mengurutkan StringName menurut alamat internal, bukan huruf,
## jadi urutannya bisa berbeda antar-sesi. Simulasi memakai Ids.sort (GDD 102, 116).
func _id_order() -> void:
	# Dua belas StringName baru dibuat dalam urutan acak; kemungkinan urutan
	# alamatnya kebetulan sama dengan urutan huruf praktis nol.
	var tag: String = str(Time.get_ticks_usec())
	var made: Array = []
	for i: int in [7, 2, 11, 0, 9, 4, 1, 10, 5, 3, 8, 6]:
		made.append(StringName("zz_%s_%02d" % [tag, i]))
	var want: Array = []
	for i2 in 12:
		want.append(StringName("zz_%s_%02d" % [tag, i2]))
	eq(Ids.sort(made.duplicate()), want, "StringName IDs sort alphabetically")
	eq(Ids.sort([3, &"b", 1.5, "a", 2]), [1.5, 2, 3, "a", &"b"], "numbers by value first, then text")
	# weighted_pick menelusuri kunci menurut huruf: dengan bobot sama, roll
	# memilih kunci ke-floor(roll) dari urutan alfabet.
	var weights: Dictionary = {}
	for k: Variant in made:
		weights[k] = 1.0
	for seed_value in range(1, 9):
		var probe := RandomNumberGenerator.new()
		probe.seed = seed_value
		var idx: int = mini(int(probe.randf() * 12.0), 11)
		var r := RandomNumberGenerator.new()
		r.seed = seed_value
		eq(RNGManager.weighted_pick(r, weights), want[idx], "weighted_pick walks keys alphabetically (seed %d)" % seed_value)


func _ticks(s: SimulationRoot) -> int:
	return int(round(s.time.sim_seconds / s.tick_seconds))


func _rng_streams() -> void:
	var a: SimulationRoot = new_sim(99)
	var b: SimulationRoot = new_sim(99)
	for n: StringName in RNGManager.STREAMS:
		eq(a.rng.stream(n).randi(), b.rng.stream(n).randi(), "stream %s reproducible from the same seed" % n)
	# Mengonsumsi stream kosmetik/audio tidak menggeser stream gameplay (GDD 116).
	var first: Array = []
	for i in 5:
		first.append(a.rng.stream(&"customer_arrival_rng").randi())
	for i in 1000:
		b.rng.stream(&"cosmetic_rng").randi()
		b.rng.stream(&"audio_rng").randi()
		b.rng.stream(&"customer_choice_rng").randi()
	var second: Array = []
	for i in 5:
		second.append(b.rng.stream(&"customer_arrival_rng").randi())
	eq(second, first, "arrival stream independent of choice/cosmetic/audio draws")
	var seeds: Dictionary = {}
	for n2: StringName in RNGManager.STREAMS:
		seeds[a.rng.stream(n2).seed] = true
	eq(seeds.size(), RNGManager.STREAMS.size(), "every stream has a distinct seed")
	# State stream ikut tersimpan: load tidak me-reroll (GDD 77.4).
	var saved: Dictionary = a.rng.capture()
	var next_a: int = a.rng.stream(&"weather_rng").randi()
	a.rng.restore(saved)
	eq(a.rng.stream(&"weather_rng").randi(), next_a, "restored stream continues exactly")
	free_sim(a)
	free_sim(b)


func _production_happy() -> void:
	var s: SimulationRoot = new_sim()
	var r: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var flour_before: int = s.inventory.count(&"ingredient_flour")
	var j: ProductionJob = s.production.create_job(r.id, 1, &"test")
	check(j != null, "job created")
	eq(s.inventory.count(&"ingredient_flour"), flour_before - 1, "ingredients deducted at order (GDD 18.3)")
	eq(j.stage, ProductionJob.ORDERED, "ORDERED")
	check(s.production.start_mixing(j.job_id, &"test", 1.0), "start mixing")
	eq(j.stage, ProductionJob.MIXING, "MIXING")
	_run_stage(s, j, ProductionJob.MIX_DONE_WAITING_PICKUP)
	eq(j.stage, ProductionJob.MIX_DONE_WAITING_PICKUP, "mixer holds the dough until picked up (GDD 2)")
	check(s.production.pickup_dough(j.job_id, &"test"), "pick up dough")
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	check(s.production.insert_oven(j.job_id, oven.iid, &"test", 1.0), "insert into oven")
	_run_stage(s, j, ProductionJob.BAKE_DONE_WAITING_PICKUP)
	eq(j.stage, ProductionJob.BAKE_DONE_WAITING_PICKUP, "READY_PERFECT")
	var res: Dictionary = s.production.pickup_tray(j.job_id, &"test")
	check(bool(res["ok"]) and not bool(res["burnt"]), "tray picked up in the perfect window")
	near(j.bake_quality, 1.0, 0.0001, "perfect quality 1.00 (GDD 62)")
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var placed: int = s.production.place_from_tray(j.job_id, disp.iid, 0, r.batch_yield)
	eq(placed, r.batch_yield, "whole batch placed in one slot")
	eq(s.display.sellable_count(r.id), r.batch_yield, "units sellable on the display")
	check(s.production.get_job(j.job_id) == null, "job completes once the tray is empty")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _run_stage(s: SimulationRoot, j: ProductionJob, until: StringName) -> void:
	var guard: int = 0
	while j.stage != until and guard < 100000:
		s.step(s.tick_seconds)
		guard += 1


func _burn_thresholds() -> void:
	# Tabel GDD 62: perfect / overbake per tier oven.
	var table: Array = [[8.0, 8.0], [10.0, 10.0], [14.0, 12.0], [20.0, 15.0], [30.0, 20.0]]
	for tier in range(1, 6):
		var def: EquipmentDefinition = DataRegistry.equipment_for(&"oven", tier)
		near(def.perfect_window_seconds, table[tier - 1][0], 0.001, "oven T%d perfect window" % tier)
		near(def.overbake_window_seconds, table[tier - 1][1], 0.001, "oven T%d overbake window" % tier)
		var s: SimulationRoot = new_sim()
		s.debug_add_kr(1000000.0)
		var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
		oven.def_id = def.id
		var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
		s.production.start_mixing(j.job_id, &"test", 1.0)
		_run_stage(s, j, ProductionJob.MIX_DONE_WAITING_PICKUP)
		s.production.pickup_dough(j.job_id, &"test")
		s.production.insert_oven(j.job_id, oven.iid, &"test", 1.0)
		_run_stage(s, j, ProductionJob.BAKE_DONE_WAITING_PICKUP)
		s.run_for(def.perfect_window_seconds - 0.2)
		eq(j.stage, ProductionJob.BAKE_DONE_WAITING_PICKUP, "T%d still perfect before the window ends" % tier)
		s.run_for(0.4)
		eq(j.stage, ProductionJob.OVERBAKING, "T%d overbaking after the perfect window" % tier)
		var q: float = s.production.current_quality(j)
		check(q <= 0.95 + 0.0001 and q >= 0.60 - 0.0001, "T%d overbake quality within 0.95..0.60 (got %.3f)" % [tier, q])
		s.run_for(def.overbake_window_seconds - 0.6)
		eq(j.stage, ProductionJob.OVERBAKING, "T%d still overbaking before grace ends" % tier)
		s.run_for(0.6)
		eq(j.stage, ProductionJob.BURNT, "T%d burnt after %ss total grace" % [tier, def.burn_grace_seconds()])
		# Tukar loyang gosong dengan adonan baru diuji di ACC_62_BURNT_SWAP.
		var bal: float = s.economy.balance
		var res: Dictionary = s.production.pickup_tray(j.job_id, &"test")
		check(bool(res["burnt"]), "T%d burnt batch goes to disposal" % tier)
		near(s.economy.balance, bal, 0.001, "T%d burnt batch earns no KR" % tier)
		eq(s.display.total_units(), 0, "T%d nothing burnt reaches the display" % tier)
		free_sim(s)


func _stage_durations() -> void:
	var s: SimulationRoot = new_sim()
	# Batch hanya memperpanjang durasi: x1 1.0, x3 1.2, x5 1.4 (GDD 18.5, 18.9).
	var factor: Dictionary = {1: 1.0, 3: 1.2, 5: 1.4}
	for b0: int in factor.keys():
		near(DataRegistry.batch_duration_factor(b0), float(factor[b0]), 0.0001, "x%d duration factor" % b0)
	for r: RecipeDefinition in DataRegistry.recipes():
		for mt in range(r.required_mixer_tier, 6):
			var active: EquipmentDefinition = DataRegistry.equipment_for(&"mixer", mt)
			var req: EquipmentDefinition = DataRegistry.equipment_for(&"mixer", r.required_mixer_tier)
			for batch: int in [1, 3, 5]:
				for speed: float in [1.0, 1.25]:
					var want: float = maxf(1.0, (r.mix_duration_seconds + r.prep_duration_seconds) * active.reference_seconds / req.reference_seconds * float(factor[batch]) / speed)
					near(s.production.mixer_stage_seconds(r, mt, batch, speed), want, 0.001, "%s mixer T%d x%d /%.2f" % [r.id, mt, batch, speed])
		for ot in range(r.required_oven_tier, 6):
			var a2: EquipmentDefinition = DataRegistry.equipment_for(&"oven", ot)
			var q2: EquipmentDefinition = DataRegistry.equipment_for(&"oven", r.required_oven_tier)
			for batch2: int in [3, 5]:
				var want2: float = maxf(1.0, r.bake_duration_seconds * a2.reference_seconds / q2.reference_seconds * float(factor[batch2]))
				near(s.production.oven_stage_seconds(r, ot, batch2, 1.0), want2, 0.001, "%s oven T%d x%d" % [r.id, ot, batch2])
	# Prep dihitung di dalam MIXING: job nyata memakai durasi yang sama.
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, &"test")
	s.production.start_mixing(j.job_id, &"test", 1.0)
	var rr: RecipeDefinition = j.recipe()
	near(j.stage_duration, rr.mix_duration_seconds + rr.prep_duration_seconds, 0.001, "job MIXING duration includes prep")
	var t0: float = s.time.sim_seconds
	_run_stage(s, j, ProductionJob.MIX_DONE_WAITING_PICKUP)
	near(s.time.sim_seconds - t0, j.stage_duration, s.tick_seconds + 0.0001, "mixing lasts its computed duration")
	free_sim(s)


func _freshness() -> void:
	eq(BreadStack.state_for_ratio(0.0), &"FRESH", "0.00 FRESH")
	eq(BreadStack.state_for_ratio(0.40), &"FRESH", "0.40 FRESH")
	eq(BreadStack.state_for_ratio(0.41), &"GOOD", "0.41 GOOD")
	eq(BreadStack.state_for_ratio(0.70), &"GOOD", "0.70 GOOD")
	eq(BreadStack.state_for_ratio(0.71), &"STALE", "0.71 STALE")
	eq(BreadStack.state_for_ratio(0.999), &"STALE", "0.999 STALE")
	eq(BreadStack.state_for_ratio(1.0), &"UNSALEABLE", "1.00 UNSALEABLE")
	var rates: Array = [1.0, 0.9, 0.8, 0.7, 0.6]
	for t in range(1, 6):
		near(DataRegistry.equipment_for(&"display", t).aging_rate, rates[t - 1], 0.0001, "display T%d aging rate (GDD 19.7.2)" % t)
	var s: SimulationRoot = new_sim()
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	# Roti Goreng (8 jam) & Roti Tawar (20 jam) diletakkan pukul 05:00.
	s.display.place(disp.iid, 0, &"recipe_plain_fried_bread", 3, 1.0, s.time.sim_seconds, 900)
	s.display.place(disp.iid, 1, &"recipe_plain_loaf", 3, 1.0, s.time.sim_seconds, 901)
	run_day(s, null)
	var loaf_age: float = _age_of(s, disp.iid, &"recipe_plain_loaf")
	near(loaf_age, 13.0, 0.05, "13 in-game hours of daytime aging at T1")
	eq(s.display.sellable_count(&"recipe_plain_fried_bread"), 0, "8 h fried bread expired during the day")
	eq(BreadStack.state_for_ratio(loaf_age / 20.0), &"GOOD", "loaf is GOOD at 18:00")
	# Sisa roti bertahan lintas hari: overnight menambah tepat 11 jam (GDD 19.7.3).
	var loaf_units: int = s.display.sellable_count(&"recipe_plain_loaf")
	_set_age(s, disp.iid, &"recipe_plain_loaf", 5.0)
	s.enter_after_hours()
	s.continue_to_next_day()
	near(_age_of(s, disp.iid, &"recipe_plain_loaf"), 16.0, 0.001, "overnight adds exactly 11 h (GDD 19.7.3)")
	eq(s.display.sellable_count(&"recipe_plain_loaf"), loaf_units, "leftovers survive the night")
	# Stack yang melewati umur simpan dibuang pukul 05:00 dan HPP-nya tercatat.
	_set_age(s, disp.iid, &"recipe_plain_loaf", 12.0)
	run_day(s, null)
	s.enter_after_hours()
	s.continue_to_next_day()
	eq(s.display.total_units(), 0, "stack past 20 h removed at 05:00")
	check(s.economy.waste_cost_today > 0.0, "expired COGS recorded as waste on the new day")
	# Rollover tidak pernah diterapkan dua kali untuk hari yang sama (GDD 19.9).
	s.display.place(disp.iid, 0, &"recipe_plain_loaf", 2, 1.0, s.time.sim_seconds, 902)
	var r1: Dictionary = s.display.overnight_rollover(s.time.day - 1)
	eq(int(r1["units"]), 0, "second rollover for the same day is a no-op")
	near(_age_of(s, disp.iid, &"recipe_plain_loaf"), 0.0, 0.001, "no double aging")
	# Usia bertahan save/load.
	s.run_for(60.0)
	var age_before: float = _age_of(s, disp.iid, &"recipe_plain_loaf")
	var snap: Dictionary = JSON.parse_string(JSON.stringify(s.capture_save()))
	var s2 := SimulationRoot.new()
	runner.add_child(s2)
	s2.load_from_save(snap)
	near(_age_of(s2, disp.iid, &"recipe_plain_loaf"), age_before, 0.0001, "age survives save/load")
	free_sim(s2)
	free_sim(s)


func _set_age(s: SimulationRoot, iid: int, recipe: StringName, hours: float) -> void:
	for slot: Dictionary in s.display.slots(iid):
		for st: BreadStack in slot["stacks"]:
			if st.recipe_id == recipe:
				st.age_ingame_hours = hours
				st.refresh_state()


func _age_of(s: SimulationRoot, iid: int, recipe: StringName) -> float:
	for slot: Dictionary in s.display.slots(iid):
		for st: BreadStack in slot["stacks"]:
			if st.recipe_id == recipe:
				return st.age_ingame_hours
	return -1.0


func _inventory_atomic() -> void:
	var s: SimulationRoot = new_sim()
	var r: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var before: Dictionary = s.inventory.on_hand.duplicate()
	# Butter hanya 6: batch x5 butuh 5, tapi hilangkan yeast agar satu bahan kurang.
	s.inventory.on_hand.erase(&"ingredient_yeast")
	var snapshot: Dictionary = s.inventory.on_hand.duplicate()
	var taken: Dictionary = s.inventory.consume_for_recipe(r, 1)
	eq(taken, {}, "consume fails when one ingredient is missing")
	eq(s.inventory.on_hand, snapshot, "nothing deducted on failure")
	check(s.production.create_job(r.id, 1, &"test") == null, "job not created without ingredients")
	eq(s.inventory.on_hand, snapshot, "failed job leaves inventory untouched")
	s.inventory.on_hand = before.duplicate()
	var j: ProductionJob = s.production.create_job(r.id, 3, &"test")
	check(j != null, "x3 job")
	eq(s.inventory.count(&"ingredient_flour"), int(before[&"ingredient_flour"]) - 3, "x3 deducts 3 flour")
	check(s.production.cancel_job(j.job_id), "cancel before mixing")
	eq(s.inventory.on_hand, before, "cancel before MIXING refunds everything (GDD 18.3)")
	var j2: ProductionJob = s.production.create_job(r.id, 1, &"test")
	s.production.start_mixing(j2.job_id, &"test", 1.0)
	check(not s.production.cancel_job(j2.job_id), "no refund once MIXING started")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _economy() -> void:
	eq(Money.round_half_up(2.5), 3.0, "half-up 2.5")
	eq(Money.round_half_up(3.5), 4.0, "half-up 3.5 (not banker's)")
	eq(Money.round_half_up(-2.5), -3.0, "half-up away from zero for -2.5")
	eq(Money.round_half_up(0.49), 0.0, "0.49 -> 0")
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	# GDD 63.2: min = maks(HPP×1.05, default×0.6), maks = default×1.8, kelipatan 5.
	near(loaf.min_price_kr, 60.0, 0.001, "plain loaf min price")
	near(loaf.max_price_kr, 160.0, 0.001, "plain loaf max price")
	near(loaf.price_step_kr, 5.0, 0.001, "plain loaf slider step")
	var s: SimulationRoot = new_sim()
	# Harga terkunci selama Hari 1-3 (GDD 63.2); slider diuji di Hari 4.
	s.time.day = 4
	near(s.pricing.set_price(loaf.id, 10.0), 60.0, 0.001, "price clamps to min")
	near(s.pricing.set_price(loaf.id, 999.0), 160.0, 0.001, "price clamps to max")
	near(s.pricing.set_price(loaf.id, 103.0), 105.0, 0.001, "price snaps to step")
	s.pricing.set_price(loaf.id, 90.0)
	check(not s.pricing.prices.has(loaf.id), "default price stores no override")
	var start: float = s.economy.balance
	check(not s.economy.spend(start + 1.0, &"INGREDIENT_PURCHASE", &"t"), "spend beyond balance rejected")
	near(s.economy.balance, start, 0.001, "rejected spend changes nothing")
	s.economy.credit(10.4, &"SALE_PHYSICAL", &"t")
	s.economy.credit(10.5, &"SALE_PHYSICAL", &"t")
	near(s.economy.balance, start + 21.0, 0.001, "credits commit whole KR, half-up")
	var owed: float = s.economy.charge_settlement(s.economy.balance + 250.0, &"STAFF_WAGE", &"payroll")
	near(s.economy.balance, 0.0, 0.001, "settlement larger than cash floors at 0 (GDD 49.1)")
	near(owed, 250.0, 0.001, "excess is written off")
	check(s.economy.reconcile(), "ledger reconciles with the balance")
	# Hari penuh dengan bot: rekonsiliasi tetap terjaga.
	var s2: SimulationRoot = new_sim(31)
	run_day(s2, SimBot.new(s2))
	check(s2.economy.reconcile(), "ledger reconciles after a played day")
	var sum: float = 0.0
	for e: Dictionary in s2.economy.ledger:
		sum += float(e["amount"])
		check(float(e["amount"]) == roundf(float(e["amount"])), "ledger amounts are whole KR")
	near(sum, s2.economy.balance, 0.5, "ledger (incl. opening balance) sums to the balance")
	free_sim(s2)
	free_sim(s)
