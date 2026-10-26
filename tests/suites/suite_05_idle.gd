extends TestSuite
## Tes penerimaan GDD idle (Seksi 16).


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_NO_INPUT", "name": "idle 2.3: a new game left alone for 30 real minutes keeps selling, never stalls, and the balance never goes negative", "fn": _no_input},
		{"id": "ACC_IDLE_NO_BURN_NO_STALE", "name": "idle 4.6: there is no burnt or stale state; a finished tray waits without a time limit and bread never ages", "fn": _no_burn_no_stale},
		{"id": "ACC_IDLE_AUTOMATION", "name": "idle 4.3, 5.1, 6.5: the owner serves lane A without a cashier, kitchen workers fill the emptiest slot with the biggest batch that fits and is affordable, and RotiFood orders are taken, packed and handed over with no input", "fn": _automation},
		{"id": "ACC_IDLE_TAP_BOOST", "name": "idle 5.2: a Semangat tap adds exactly tap.progress_seconds x tap_power to a working mixer, oven or checkout, ignores taps faster than tap.min_interval_seconds per station, and sets a 10 s focus", "fn": _tap_boost},
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


func _quiet(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	return s


func _automation() -> void:
	# 1. Pemilik melayani jalur A tanpa kasir, tanpa satu ketukan pun.
	var s: SimulationRoot = _quiet(5101)
	freeze_production(s)
	stock(s, &"recipe_plain_loaf", 13)
	var lane: QueueLane = s.queue.main_lane()
	s.customers.try_admit({"archetype": &"customer_generic"})
	var manned: bool = false
	var guard: int = 0
	while s.statistics.get_stat("total_customers_served") < 1.0 and guard < 6000:
		s.step(s.tick_seconds)
		guard += 1
		if not s.cashier.transaction_for(lane.id).is_empty():
			manned = manned or s.player.is_manning_lane(lane.id)
	eq(s.statistics.get_stat("total_customers_served"), 1.0, "the buyer is served with no cashier hired")
	check(manned, "by the owner standing at lane A")
	free_sim(s)
	# 2. Petak dengan rasio isi terendah lebih dulu; batch terbesar yang muat dan terjangkau.
	var k: SimulationRoot = _quiet(5102)
	# Tier 2: dua mixer, supaya rencana kedua bisa dibuat selagi yang pertama jalan.
	jump_to_tier(k, 2)
	freeze_production(k)
	k.debug_add_kr(1.0e6)
	var disp: EquipmentInstance = k.equipment.placed_list(&"display")[0]
	for i0 in k.display.slot_count(disp.iid):
		k.display.set_assignment(disp.iid, i0, &"")
	var fills: Array[int] = [12, 6, 0, 3]
	for i in fills.size():
		if fills[i] > 0:
			stock(k, &"recipe_plain_loaf", fills[i], i, disp.iid)
	var plan: Dictionary = KitchenBrain.plan_batch(k)
	eq(int(plan.get("slot", -1)), 2, "the empty slot is filled first")
	eq(int(plan.get("batch", 0)), 1, "x3 (18 bread) would not fit the 13-bread slot, so x1")
	var mixer: EquipmentInstance = k.equipment.placed_list(&"mixer")[0]
	var j: ProductionJob = k.production.create_job(plan["recipe"], int(plan["batch"]), mixer, int(plan["display"]), int(plan["slot"]), &"test")
	check(j != null, "the planned batch starts")
	check(k.upgrades.open_station(&"mixer") >= 0 or k.equipment.placed_count(&"mixer") >= 2, "a second mixer works")
	var plan2: Dictionary = KitchenBrain.plan_batch(k)
	eq(int(plan2.get("slot", -1)), 3, "with 6 bread on the way to slot 2, slot 3 (3 of 13) is now the emptiest")
	k.upgrades.set_station_level(disp.iid, 50)
	var cap: int = k.display.slot_capacity(disp.iid)
	check(cap >= 30 + 3, "a Lv 50 shelf holds %d per slot" % cap)
	var plan3: Dictionary = KitchenBrain.plan_batch(k)
	eq(int(plan3.get("batch", 0)), 5, "a big slot gets a x5 batch")
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	k.economy.spend(k.economy.balance - ProductionManager.batch_cost(loaf, 3), &"OTHER_ADJUSTMENT", &"test")
	var plan4: Dictionary = KitchenBrain.plan_batch(k)
	eq(int(plan4.get("batch", 0)), 3, "with KR for only x3, the batch is x3")
	k.economy.spend(k.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	check(KitchenBrain.plan_batch(k).is_empty(), "with no KR nothing starts, so the balance never goes negative")
	free_sim(k)
	# Seri rasio: nilai jual per detik tertinggi menang.
	var v: SimulationRoot = _quiet(5103)
	v.debug_add_kr(1.0e6)
	check(v.upgrades.unlock_recipe(&"recipe_sugar_donut"), "Sugar Donut unlocked")
	var d2: EquipmentInstance = v.equipment.placed_list(&"display")[0]
	for i2 in v.display.slot_count(d2.iid):
		v.display.set_assignment(d2.iid, i2, &"recipe_plain_loaf")
	check(v.display.set_assignment(d2.iid, 3, &"recipe_sugar_donut"), "slot 4 sells Sugar Donut")
	var vps_loaf: float = KitchenBrain.value_per_second(v, loaf, d2.iid)
	var vps_donut: float = KitchenBrain.value_per_second(v, DataRegistry.recipe(&"recipe_sugar_donut"), d2.iid)
	var want: int = 3 if vps_donut > vps_loaf else 0
	eq(int(KitchenBrain.plan_batch(v).get("slot", -1)), want, "equal fill ratios: the recipe worth more per second goes first")
	free_sim(v)
	# 3. RotiFood: diterima, dikemas, dan diserahkan sendiri dengan harga x1.1.
	var r: SimulationRoot = _quiet(5104)
	freeze_production(r)
	stock(r, &"recipe_plain_loaf", 13)
	var price: float = r.unit_price(&"recipe_plain_loaf", r.equipment.placed_list(&"display")[0].iid)
	var o: DeliveryOrder = r.rotifood.debug_create_order({&"recipe_plain_loaf": 2}, 30.0)
	eq(o.state, DeliveryOrder.TO_PACK, "the order takes its bread from the shelf at once")
	var packing_seen: bool = false
	var bal: float = r.economy.balance
	var guard2: int = 0
	while o.state != DeliveryOrder.COMPLETED and guard2 < 20000:
		r.step(r.tick_seconds)
		guard2 += 1
		packing_seen = packing_seen or (o.state == DeliveryOrder.PACKING and o.packer_id == PlayerTaskManager.PLAYER_ID)
	check(packing_seen, "the owner packs it without a tap")
	eq(o.state, DeliveryOrder.COMPLETED, "the driver collects it")
	near(r.economy.balance - bal, Money.round_half_up(price * DataRegistry.idlef("rotifood.price_mult")) * 2.0, 1.0, "paid at the shelf price x rotifood.price_mult")
	eq(r.statistics.get_stat("total_rotifood_orders_completed"), 1.0, "counted as completed")
	free_sim(r)


func _tap_boost() -> void:
	var s: SimulationRoot = _quiet(5201)
	jump_to_tier(s, 2)
	freeze_production(s)
	park_owner(s)
	s.debug_add_kr(1.0e6)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var oven: EquipmentInstance = s.equipment.placed_list(&"oven")[0]
	var step_s: float = DataRegistry.idlef("tap.progress_seconds")
	near(step_s, 0.5, 0.0001, "a tap is worth 0.5 simulation-seconds")
	near(DataRegistry.idlef("tap.min_interval_seconds"), 0.12, 0.0001, "taps closer than 0.12 real s are ignored")
	# Alat diam: tidak ada yang dipercepat, tapi tetap jadi prioritas pemilik.
	var idle_tap: Dictionary = s.player.tap_station(mixer.iid, 1000)
	check(bool(idle_tap["focus"]) and not bool(idle_tap["boosted"]), "tapping an idle mixer only sets the focus")
	check(s.player.focus_active() and s.player.focus_iid == mixer.iid, "the tapped station is the owner's priority")
	near(s.player.focus_until - s.time.sim_seconds, DataRegistry.idlef("owner.focus_seconds"), 0.0001, "for owner.focus_seconds")
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
	s.production.start_mixing(j.job_id, &"test")
	var signals: Array = [0]
	var cb := func(_iid: int, _cell: Vector2i, _f: StringName) -> void: signals[0] += 1
	EventBus.tap_boost.connect(cb)
	var e0: float = j.stage_elapsed
	check(bool(s.player.tap_station(mixer.iid, 2000)["boosted"]), "tapping a working mixer boosts it")
	near(j.stage_elapsed - e0, step_s, 0.000001, "by exactly tap.progress_seconds")
	var e1: float = j.stage_elapsed
	check(not bool(s.player.tap_station(mixer.iid, 2100)["boosted"]), "a second tap 0.10 s later is ignored")
	near(j.stage_elapsed, e1, 0.000001, "and adds nothing")
	check(bool(s.player.tap_station(mixer.iid, 2120)["boosted"]), "0.12 s after the last counted tap it works again")
	eq(int(signals[0]), 2, "every counted tap sparkles (tap_boost signal)")
	# Kekuatan ketukan dari upgrade global.
	s.upgrades.global_levels[&"global_tap_power"] = 3
	var power: float = s.player.tap_power()
	check(power > 1.0, "global_tap_power raises tap_power (%.2f)" % power)
	var e2: float = j.stage_elapsed
	s.player.tap_station(mixer.iid, 3000)
	near(j.stage_elapsed - e2, step_s * power, 0.000001, "a tap adds tap.progress_seconds x tap_power")
	s.upgrades.global_levels.erase(&"global_tap_power")
	# Batas per alat: oven punya jedanya sendiri.
	if s.equipment.placed_count(&"mixer") < 2:
		s.upgrades.open_station(&"mixer")
	var m2: EquipmentInstance = s.equipment.placed_list(&"mixer")[1] if s.equipment.placed_count(&"mixer") >= 2 else null
	check(m2 != null, "a second mixer works")
	if m2 != null:
		var j2: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, m2, -1, -1, &"test")
		s.production.start_mixing(j2.job_id, &"test")
		while j2.stage == ProductionJob.MIXING:
			s.production.step(s.tick_seconds)
		s.production.pickup_dough(j2.job_id, &"test")
		s.production.insert_oven(j2.job_id, oven.iid, &"test")
		s.player.tap_station(mixer.iid, 4000)
		var b0: float = j2.stage_elapsed
		check(bool(s.player.tap_station(oven.iid, 4010)["boosted"]), "the oven has its own tap timer")
		near(j2.stage_elapsed - b0, step_s, 0.000001, "and bakes 0.5 s further")
	# Semangat pada kasir: transaksi yang sedang berjalan maju (pemilik bekerja lagi).
	s.player.task = {}
	var lane: QueueLane = s.queue.main_lane()
	stock(s, &"recipe_plain_loaf", 13)
	s.customers.try_admit({"archetype": &"customer_generic"})
	var guard: int = 0
	while s.cashier.transaction_for(lane.id).is_empty() and guard < 6000:
		s.step(s.tick_seconds)
		guard += 1
	var td: Dictionary = s.cashier.transaction_for(lane.id)
	check(not td.is_empty(), "a checkout is running")
	if not td.is_empty():
		var t0: float = float(td["elapsed"])
		check(bool(s.player.tap_cashier(lane.id, 9000)["boosted"]), "tapping the counter boosts the checkout")
		near(float(td["elapsed"]) - t0, step_s, 0.000001, "by tap.progress_seconds")
	EventBus.tap_boost.disconnect(cb)
	free_sim(s)
