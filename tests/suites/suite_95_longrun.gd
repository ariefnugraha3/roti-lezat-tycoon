extends TestSuite
## Soak panjang GDD 94 & 107. Ditandai "long": lewati dengan --skip-long.
##
## LONGRUN_100 memakai tick kanonik 0,05 s. LONGRUN_500 dan LONGRUN_1000 menguji
## ekonomi dan siklus save, bukan detail gerak, sehingga memakai tick 0,25 s
## agar selesai dalam waktu wajar; semua invarian tetap diperiksa setiap hari.

const COARSE_TICK: float = 0.25


func tests() -> Array:
	return [
		{"id": "TEST_LONGRUN_100", "name": "100-day soak", "fn": _soak_100, "long": true},
		{"id": "TEST_LONGRUN_500", "name": "500-day headless economy soak", "fn": _soak_500, "long": true},
		{"id": "TEST_LONGRUN_1000", "name": "1,000-day save-cycle soak", "fn": _soak_1000, "long": true},
	]


func _node_count(n: Node) -> int:
	var c: int = 1
	for ch: Node in n.get_children():
		c += _node_count(ch)
	return c


## Jumlah semua rujukan state yang seharusnya kosong pukul 05:00.
func _transient(s: SimulationRoot) -> Dictionary:
	var res: int = 0
	for l: QueueLane in s.queue.all_lanes():
		res += l.reservations.size() + l.line.size() + (1 if l.service_occupant != &"" else 0)
	return {
		"customers": s.customers.customers.size(), "reservations": res,
		"points": s.world.point_reservations.size(), "pending": s.demand.pending.size(),
		"transactions": s.cashier.transactions.size(), "couriers": s.supply.couriers.size(),
		"active_orders": s.rotifood.active_orders().size(),
	}


func _progress(label: String, d: int, s: SimulationRoot) -> void:
	if d % 10 == 9:
		print("      %s day %d: tier %d, balance %s, rating %.2f, mem %d MB" % [label, s.time.day, s.world.location.tier,
			Tx.kr(s.economy.balance), s.reputation.physical, int(OS.get_static_memory_usage() / 1048576)])


func _day_checks(s: SimulationRoot, day_label: int) -> bool:
	var inv: String = s.check_invariants()
	var ok: bool = true
	ok = check(inv == "", "day %d invariants: %s" % [day_label, inv]) and ok
	ok = check(not is_nan(s.economy.balance), "day %d balance is not NaN" % day_label) and ok
	ok = check(s.economy.overflowed or not is_inf(s.economy.balance), "day %d no INF without the overflow guard" % day_label) and ok
	ok = check(s.reputation.physical >= 1.0 and s.reputation.physical <= 5.0, "day %d physical rating in range" % day_label) and ok
	var t: Dictionary = _transient(s)
	for k: String in ["customers", "reservations", "transactions", "couriers", "active_orders", "pending"]:
		ok = check(int(t[k]) == 0, "day %d no leftover %s at 05:00 (%s)" % [day_label, k, t[k]]) and ok
	return ok


func _soak_100() -> void:
	var s: SimulationRoot = new_sim(100100)
	var bot := SimBot.new(s)
	bot.manage = true
	var base_nodes: int = -1
	var base_objects: float = -1.0
	var start_tier: int = s.world.location.tier
	for d in 100:
		bot.play_day()
		_progress("soak100", d, s)
		if not _day_checks(s, s.time.day):
			break
		if d == 9:
			base_nodes = _node_count(s)
			base_objects = Performance.get_monitor(Performance.OBJECT_COUNT)
	var end_nodes: int = _node_count(s)
	var end_objects: float = Performance.get_monitor(Performance.OBJECT_COUNT)
	eq(end_nodes, base_nodes, "no node count growth after day 10 (GDD 94 no.1)")
	check(end_objects <= base_objects * 1.15 + 500.0, "object count stable (%d -> %d)" % [int(base_objects), int(end_objects)])
	print("      100 days: tier %d -> %d, balance %s, staff %d, rating %.2f" % [start_tier, s.world.location.tier,
		Tx.kr(s.economy.balance), s.staff.employed_ids().size(), s.reputation.physical])
	check(s.economy.reconcile(), "ledger reconciles after 100 days")
	free_sim(s)


func _soak_500() -> void:
	var s: SimulationRoot = new_sim(500500)
	s.tick_seconds = COARSE_TICK
	var bot := SimBot.new(s)
	bot.manage = true
	bot.think_interval = 1
	for d in 500:
		bot.play_day()
		_progress("soak500", d, s)
		if not _day_checks(s, s.time.day):
			break
		if d % 50 == 49:
			check(s.economy.reconcile(), "ledger reconciles at day %d" % s.time.day)
	print("      500 days: tier %d, balance %s, bailouts %d" % [s.world.location.tier, Tx.kr(s.economy.balance), s.bailout.bailout_count])
	# Penjaga overflow: saldo mendekati batas float tetap aman & tersimpan.
	s.economy.credit(1.0e308, &"OTHER_ADJUSTMENT", &"soak")
	s.economy.credit(1.0e308, &"OTHER_ADJUSTMENT", &"soak")
	check(s.economy.overflowed, "overflow guard engaged (GDD 73)")
	var d2: Dictionary = json_copy(s.capture_save())
	eq(SaveManager.validate_save(d2, s.profile_id), "", "overflowed save still validates")
	var s2: SimulationRoot = load_sim(d2)
	check(s2.economy.overflowed and is_inf(s2.economy.balance), "overflow state survives save/load")
	free_sim(s2)
	free_sim(s)


func _soak_1000() -> void:
	var s: SimulationRoot = new_sim(1000)
	s.tick_seconds = COARSE_TICK
	var bot := SimBot.new(s)
	bot.manage = true
	bot.think_interval = 1
	var sizes: Array[int] = []
	for d in 1000:
		bot.play_day()
		_progress("soak1000", d, s)
		# Siklus save/load setiap hari lewat JSON, seperti tulis-baca file.
		var text: String = JSON.stringify(s.capture_save(), "", true, true)
		var data: Dictionary = JSON.parse_string(text)
		sizes.append(_transient_size(data))
		var next: SimulationRoot = load_sim(data)
		next.tick_seconds = COARSE_TICK
		same_state(logical_state(next.capture_save()), logical_state(data), "day %d reload preserves state" % next.time.day)
		free_sim(s)
		s = next
		bot = SimBot.new(s)
		bot.manage = true
		bot.think_interval = 1
		if not _day_checks(s, s.time.day):
			break
	# Ukuran save tidak tumbuh linear dari data transien basi (GDD 94 no.3).
	# Riwayat analitik & laporan boleh tumbuh sampai batas detail GDD 129
	# (limits.analytics_detailed_days), jadi diukur terpisah.
	if sizes.size() >= 1000:
		var at_200: int = sizes[199]
		var at_1000: int = sizes[999]
		print("      save size without bounded histories, day 200: %d bytes, day 1000: %d bytes" % [at_200, at_1000])
		check(at_1000 < at_200 * 2, "non-history save size bounded (%d -> %d bytes)" % [at_200, at_1000])
	var limit: int = DataRegistry.bali("limits.analytics_detailed_days")
	check(s.analytics.daily.size() <= limit, "analytics history within %d days" % limit)
	check(s.reports.history.size() <= limit, "report history within %d days" % limit)
	free_sim(s)


## Ukuran save tanpa riwayat yang dibatasi GDD 129.
func _transient_size(d: Dictionary) -> int:
	var c: Dictionary = d.duplicate(true)
	if c.has("recipe_analytics"):
		(c["recipe_analytics"] as Dictionary).erase("daily")
	if c.has("reports"):
		(c["reports"] as Dictionary).erase("history")
	return JSON.stringify(c, "", true, true).length()
