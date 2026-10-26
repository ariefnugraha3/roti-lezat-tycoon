extends TestSuite
## Test inti: boot, jam 24 jam, determinisme, RNG, produksi, ekonomi
## (GDD idle 3.1, 4, 7; v3.1 107).


func tests() -> Array:
	return [
		{"id": "TEST_BOOT_001", "name": "catalog validation and clean boot", "fn": _boot},
		{"id": "TEST_TIME_001", "name": "the clock runs 24 hours, the day turns at 00:00 and nights run 22:00-06:00", "fn": _time_clock},
		{"id": "TEST_TIME_002", "name": "pause freezes everything and frame-driven play matches fixed ticks", "fn": _time_determinism},
		{"id": "TEST_RNG_001", "name": "separated deterministic streams", "fn": _rng_streams},
		{"id": "ACC_116_ID_ORDER", "name": "text IDs sort alphabetically in every session", "fn": _id_order},
		{"id": "TEST_PRODUCTION_001", "name": "paid batch -> mixer -> oven -> its shelf slot, stations hold their contents without a time limit", "fn": _production_happy},
		{"id": "TEST_PRODUCTION_003", "name": "stage durations follow the recipe, the batch factor and the station level", "fn": _stage_durations},
		{"id": "TEST_ECONOMY_001", "name": "rounding, rejected spending, ledger categories and reconciliation", "fn": _economy, "expect_errors": true},
	]


func _boot() -> void:
	check(DataRegistry.load_catalogs(), "catalogs reload cleanly")
	eq(DataRegistry.errors, [], "catalog validation errors (v3.1 101, 134; GDD idle 15.2)")
	check(DataRegistry.is_valid(), "registry valid")
	check(DataRegistry.recipes().size() > 0, "recipes loaded")
	for r: RecipeDefinition in DataRegistry.recipes():
		var cost: float = 0.0
		for ing: StringName in r.ingredients.keys():
			cost += DataRegistry.ingredient(ing).fixed_buy_price_kr * float(r.ingredients[ing])
		near(cost, r.batch_cost_kr, 0.01, "%s batch_cost_kr" % r.id)
		check(DataRegistry.has_text(String(r.localization_key)), "%s has an English name" % r.id)
	for tier in range(1, 6):
		check(DataRegistry.location_by_tier(tier) != null, "location tier %d" % tier)
	for n: String in ["GameLogger", "DataRegistry", "EventBus", "SettingsManager", "PauseManager", "SaveManager", "AudioManager"]:
		check(runner.get_tree().root.has_node(n), "autoload %s (v3.1 35.2)" % n)
	var s: SimulationRoot = new_sim()
	eq(s.check_invariants(), "", "invariants right after boot")
	free_sim(s)


func _time_clock() -> void:
	var s: SimulationRoot = new_sim()
	# 1 jam in-game = 60 detik nyata = 120 detik-simulasi (GDD idle 0.2).
	near(s.time.sim_seconds_for_hours(1.0), 120.0, 0.001, "1 in-game hour = 120 sim-seconds")
	near(DataRegistry.real_seconds(s.time.sim_seconds_for_hours(1.0)), 60.0, 0.001, "1 in-game hour = 60 real seconds")
	check(s.is_running(), "the shop always runs")
	check(not s.time.is_night(), "08:00 is day")
	run_until(s, 22.0 * 3600.0 - 60.0)
	check(not s.time.is_night(), "21:59 is day")
	run_until(s, 22.0 * 3600.0)
	check(s.time.is_night(), "22:00 is night (GDD idle 3.2)")
	eq(s.time.day, 1, "still day 1 before midnight")
	var days: Array = []
	var cb := func(d: int) -> void: days.append(d)
	EventBus.day_started.connect(cb)
	run_until(s, 60.0)
	EventBus.day_started.disconnect(cb)
	eq(s.time.day, 2, "day 2 after midnight")
	check(s.time.time_seconds < 120.0, "the clock wrapped to 00:00")
	eq(days, [2], "day_started fires once at 00:00")
	check(s.time.is_night(), "00:01 is night")
	run_until(s, 6.0 * 3600.0)
	check(not s.time.is_night(), "06:00 is day again")
	near(s.night_arrival_mult(23.0 * 3600.0), DataRegistry.idlef("night.arrival_mult"), 0.0001, "night arrivals x0.4")
	near(s.night_arrival_mult(12.0 * 3600.0), 1.0, 0.0001, "day arrivals x1")
	eq(s.statistics.get_stat("days_passed"), 1.0, "days_passed counts the rollover")
	free_sim(s)


func _time_determinism() -> void:
	var target_ticks: int = 3000
	var states: Array[Dictionary] = []
	for mode in 2:
		var s: SimulationRoot = new_sim(4242)
		if mode == 0:
			while _ticks(s) < target_ticks:
				s.step(s.tick_seconds)
		else:
			var frames: int = 0
			while _ticks(s) < target_ticks - 40:
				s.advance(1.0 / 30.0)
				frames += 1
				if frames == 50:
					PauseManager.push(PauseManager.USER)
					var before: Dictionary = state_of(s)
					for i in 30:
						s.advance(1.0 / 30.0)
					same_state(state_of(s), before, "paused simulation does not change")
					PauseManager.pop(PauseManager.USER)
			while _ticks(s) < target_ticks:
				s.step(s.tick_seconds)
		states.append(state_of(s))
		free_sim(s)
	same_state(states[1], states[0], "frame-driven play reaches the fixed-tick state after the same ticks")


## `Array.sort()` mengurutkan StringName menurut alamat internal, bukan huruf,
## jadi urutannya bisa berbeda antar-sesi. Simulasi memakai Ids.sort (v3.1 102, 116).
func _id_order() -> void:
	var tag: String = str(Time.get_ticks_usec())
	var made: Array = []
	for i: int in [7, 2, 11, 0, 9, 4, 1, 10, 5, 3, 8, 6]:
		made.append(StringName("zz_%s_%02d" % [tag, i]))
	var want: Array = []
	for i2 in 12:
		want.append(StringName("zz_%s_%02d" % [tag, i2]))
	eq(Ids.sort(made.duplicate()), want, "StringName IDs sort alphabetically")
	eq(Ids.sort([3, &"b", 1.5, "a", 2]), [1.5, 2, 3, "a", &"b"], "numbers by value first, then text")
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
	var saved: Dictionary = a.rng.capture()
	var next_a: int = a.rng.stream(&"weather_rng").randi()
	a.rng.restore(saved)
	eq(a.rng.stream(&"weather_rng").randi(), next_a, "restored stream continues exactly")
	free_sim(a)
	free_sim(b)


## Hanya ProductionManager yang dimajukan, supaya pekerja otomatis tidak ikut campur.
func _run_stage(s: SimulationRoot, j: ProductionJob, until: StringName) -> void:
	var guard: int = 0
	while j.stage != until and guard < 100000:
		s.production.step(s.tick_seconds)
		guard += 1


func _production_happy() -> void:
	var s: SimulationRoot = new_sim()
	var r: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var bal: float = s.economy.balance
	var j: ProductionJob = s.production.create_job(r.id, 1, mixer, disp.iid, 2, &"test")
	check(j != null, "job created")
	near(s.economy.balance, bal - r.batch_cost_kr, 0.001, "ingredient cost paid when the batch starts (GDD idle 4.4)")
	eq(str(s.economy.ledger[s.economy.ledger.size() - 1]["category"]), "INGREDIENT_COST", "ledger category INGREDIENT_COST")
	eq(mixer.job_id, j.job_id, "mixer reserved")
	eq(j.stage, ProductionJob.ORDERED, "ORDERED")
	check(s.production.start_mixing(j.job_id, &"test"), "start mixing")
	_run_stage(s, j, ProductionJob.MIX_DONE_WAITING_PICKUP)
	for i in 4000:
		s.production.step(s.tick_seconds)
	eq(j.stage, ProductionJob.MIX_DONE_WAITING_PICKUP, "the mixer holds the dough with no time limit (GDD idle 4.3)")
	check(s.production.pickup_dough(j.job_id, &"test"), "pick up dough")
	eq(mixer.job_id, -1, "mixer free once the dough is picked up")
	check(s.production.insert_oven(j.job_id, oven.iid, &"test"), "insert into oven")
	_run_stage(s, j, ProductionJob.BAKE_DONE_WAITING_PICKUP)
	for i2 in 6000:
		s.production.step(s.tick_seconds)
	eq(j.stage, ProductionJob.BAKE_DONE_WAITING_PICKUP, "the oven holds the tray with no time limit and nothing burns (GDD idle 4.6)")
	check(s.production.pickup_tray(j.job_id, &"test"), "tray picked up")
	eq(j.carried_units, r.batch_yield, "tray carries the whole batch")
	var placed: int = s.production.deliver_tray(j.job_id, disp.iid)
	eq(placed, r.batch_yield, "whole batch placed")
	eq(s.display.slot_units(disp.iid, 2), r.batch_yield, "the batch went to its target slot")
	check(s.production.get_job(j.job_id) == null, "job completes once the tray is empty")
	eq(s.check_invariants(), "", "invariants")
	# KR kurang: batch tidak dimulai (GDD idle 4.4).
	s.economy.spend(s.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	check(s.production.create_job(r.id, 1, mixer, disp.iid, 0, &"test") == null, "no batch without enough KR")
	near(s.economy.balance, 0.0, 0.001, "balance never negative")
	free_sim(s)


func _stage_durations() -> void:
	var s: SimulationRoot = new_sim()
	var factor: Dictionary = {1: 1.0, 3: 1.2, 5: 1.4}
	for b0: int in factor.keys():
		near(DataRegistry.batch_duration_factor(b0), float(factor[b0]), 0.0001, "x%d duration factor" % b0)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	for level: int in [1, 9, 10, 24, 25]:
		s.upgrades.station_levels[mixer.iid] = level
		s.upgrades.station_levels[oven.iid] = level
		var speed: float = (1.0 + 0.05 * float(level - 1)) * pow(2.0, float(UpgradeManager.milestones_reached(level, [10, 25, 50, 75, 100, 150])))
		near(s.upgrades.station_speed(mixer.iid), speed, 0.0001, "mixer speed at Lv %d (GDD idle 8.2)" % level)
		for r: RecipeDefinition in DataRegistry.recipes():
			for batch: int in [1, 3, 5]:
				var want: float = maxf(1.0, (r.mix_duration_seconds + r.prep_duration_seconds) * float(factor[batch]) / speed)
				near(s.production.mixer_stage_seconds(r, mixer.iid, batch), want, 0.001, "%s mixer Lv %d x%d (GDD idle 4.5)" % [r.id, level, batch])
				var want2: float = maxf(1.0, r.bake_duration_seconds * float(factor[batch]) / speed)
				near(s.production.oven_stage_seconds(r, oven.iid, batch), want2, 0.001, "%s oven Lv %d x%d" % [r.id, level, batch])
	s.upgrades.station_levels[mixer.iid] = 1
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
	s.production.start_mixing(j.job_id, &"test")
	var rr: RecipeDefinition = j.recipe()
	near(j.stage_duration, rr.mix_duration_seconds + rr.prep_duration_seconds, 0.001, "job MIXING duration includes prep")
	var t0: int = 0
	while j.stage == ProductionJob.MIXING:
		s.production.step(s.tick_seconds)
		t0 += 1
	near(float(t0) * s.tick_seconds, j.stage_duration, s.tick_seconds + 0.0001, "mixing lasts its computed duration")
	free_sim(s)


func _economy() -> void:
	eq(Money.round_half_up(2.5), 3.0, "half-up 2.5")
	eq(Money.round_half_up(3.5), 4.0, "half-up 3.5 (not banker's)")
	eq(Money.round_half_up(-2.5), -3.0, "half-up away from zero for -2.5")
	eq(Money.round_half_up(0.49), 0.0, "0.49 -> 0")
	var s: SimulationRoot = new_sim()
	var start: float = s.economy.balance
	check(not s.economy.spend(start + 1.0, &"UPGRADE_STATION", &"t"), "spend beyond balance rejected")
	near(s.economy.balance, start, 0.001, "rejected spend changes nothing")
	check(not s.economy.post(5.0, &"STAFF_WAGE", &"t", {}), "removed v3.1 categories are rejected (GDD idle 7.4)")
	var earned: float = s.statistics.get_stat("run_earned_kr")
	s.economy.credit(10.4, &"SALE_PHYSICAL", &"t")
	s.economy.credit(10.5, &"SALE_PHYSICAL", &"t")
	near(s.economy.balance, start + 21.0, 0.001, "credits commit whole KR, half-up")
	near(s.statistics.get_stat("run_earned_kr") - earned, 21.0, 0.001, "income counts into run_earned_kr")
	s.economy.spend(5.0, &"UPGRADE_STATION", &"t")
	near(s.statistics.get_stat("run_earned_kr") - earned, 21.0, 0.001, "spending is not counted as earnings")
	check(s.economy.reconcile(), "ledger reconciles with the balance")
	var s2: SimulationRoot = new_sim(31)
	run_hours(s2, 3.0)
	check(s2.economy.reconcile(), "ledger reconciles after three played hours")
	var sum: float = 0.0
	for e: Dictionary in s2.economy.ledger:
		sum += float(e["amount"])
		check(float(e["amount"]) == roundf(float(e["amount"])), "ledger amounts are whole KR")
		check(EconomyManager.CATEGORIES.has(StringName(str(e["category"]))), "ledger category %s is an idle category" % e["category"])
	near(sum, s2.economy.balance, 0.5, "ledger (incl. opening balance) sums to the balance")
	check(s2.economy.balance >= 0.0, "balance never negative")
	free_sim(s2)
	free_sim(s)
