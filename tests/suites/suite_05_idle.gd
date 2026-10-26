extends TestSuite
## Tes penerimaan GDD idle (Seksi 16).


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_NO_INPUT", "name": "idle 2.3: a new game left alone for 30 real minutes keeps selling, never stalls, and the balance never goes negative", "fn": _no_input},
		{"id": "ACC_IDLE_NO_BURN_NO_STALE", "name": "idle 4.6: there is no burnt or stale state; a finished tray waits without a time limit and bread never ages", "fn": _no_burn_no_stale},
	]


func _no_input() -> void:
	var s: SimulationRoot = new_sim(2026)
	var real_minutes: int = 30
	var per_5min: int = int(round(5.0 * 60.0 * DataRegistry.sim_seconds_per_real_second() / s.tick_seconds))
	var sold_before: float = 0.0
	var lowest: float = INF
	for block in real_minutes / 5:
		for i in per_5min:
			s.step(s.tick_seconds)
			if i % 20 == 0:
				lowest = minf(lowest, s.economy.balance)
		var sold: float = s.statistics.get_stat("total_bread_sold")
		check(sold > sold_before, "bread sold during real minutes %d-%d (%d -> %d)" % [block * 5, block * 5 + 5, int(sold_before), int(sold)])
		sold_before = sold
		eq(s.check_invariants(), "", "invariants after %d real minutes" % (block * 5 + 5))
	check(lowest >= 0.0, "balance never negative (lowest %s)" % lowest)
	print("      30 real min: sold %d, earned %s, balance %s, day %d %s" % [int(sold_before),
		Tx.big(s.statistics.get_stat("run_earned_kr")), Tx.big(s.economy.balance), s.time.day, Tx.clock(s.time.time_seconds)])
	free_sim(s)


func _no_burn_no_stale() -> void:
	for gone: String in ["OVERBAKING", "BURNT", "PLACEMENT_UI", "FAILED"]:
		check(not ProductionJob.STAGES.has(StringName(gone)), "no %s stage" % gone)
		check(not ProductionJob.new().get_script().get_script_constant_map().has(gone), "ProductionJob has no %s constant" % gone)
	var st_keys: Dictionary = BreadStack.new().to_dict()
	for field: String in ["freshness_state", "age_ingame_hours", "bake_quality", "base_expiry_hours"]:
		check(not st_keys.has(field), "BreadStack has no %s" % field)
	var s: SimulationRoot = new_sim(5)
	freeze_production(s)
	# Tanpa pembeli: rak dan meja diam selama dua hari in-game.
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	stock(s, &"recipe_plain_loaf", 6, 1)
	var before: Dictionary = s.display.capture()
	# Loyang matang menunggu di oven tanpa batas waktu.
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
	s.production.start_mixing(j.job_id, &"test")
	while j.stage == ProductionJob.MIXING:
		s.production.step(s.tick_seconds)
	s.production.pickup_dough(j.job_id, &"test")
	s.production.insert_oven(j.job_id, oven.iid, &"test")
	while j.stage == ProductionJob.BAKING:
		s.production.step(s.tick_seconds)
	# Diklaim test, supaya pemilik tidak mengangkatnya.
	j.claimed_by = &"test"
	run_hours(s, 48.0)
	eq(j.stage, ProductionJob.BAKE_DONE_WAITING_PICKUP, "the finished tray still waits in the oven after two days")
	eq(s.production.get_job(j.job_id), j, "nothing was thrown away")
	var after: Dictionary = s.display.capture()
	eq(after[str(disp.iid)], before[str(disp.iid)], "shelf bread unchanged after two days and a night")
	eq(s.statistics.get_stat("total_customers_entered"), 0.0, "no buyers came (arrivals frozen)")
	free_sim(s)
