extends TestSuite
## Smoke: New Game lalu Hari 1-3 dimainkan bot dari awal sampai Daily Summary.


func tests() -> Array:
	return [
		{"id": "SMOKE_001", "name": "new game starts at 05:00 Day 1 with 1000 KR and starter equipment", "fn": _new_game},
		{"id": "SMOKE_002", "name": "opening days 1-3 play through with the bot", "fn": _opening_days},
	]


func _new_game() -> void:
	var s: SimulationRoot = new_sim()
	eq(s.time.day, 1, "day")
	near(s.time.time_seconds, 18000.0, 0.01, "05:00")
	near(s.economy.balance, 1000.0, 0.01, "starting cash (GDD 55.1)")
	eq(s.equipment.placed_count(&"mixer"), 1, "one mixer placed")
	eq(s.equipment.placed_count(&"oven"), 1, "one oven placed")
	eq(s.equipment.placed_count(&"display"), 1, "one display placed")
	eq(s.equipment.placed_count(&"storage"), 1, "storage placed")
	check(s.world.layout_valid(), "starter layout keeps protected paths")
	for e: EquipmentInstance in s.equipment.placed_list():
		check(not s.world.access_of(e.iid).is_empty(), "%s has an access tile" % e.def_id)
	# Bahan Hari 1: 6 batch roti tawar, pas tanpa cadangan (GDD 2).
	eq(s.inventory.count(&"ingredient_flour"), 6, "day 1 flour")
	eq(s.inventory.count(&"ingredient_butter"), 6, "day 1 butter")
	free_sim(s)


func _opening_days() -> void:
	var s: SimulationRoot = new_sim(777)
	var bot := SimBot.new(s)
	for d in 3:
		run_day(s, bot)
		eq(s.time.phase, TimeManager.SUMMARY, "day %d reaches summary" % (d + 1))
		var r: Dictionary = s.reports.last_report
		check(int(r.get("bread_sold", 0)) > 0, "day %d sold bread (sold %s)" % [d + 1, r.get("bread_sold")])
		print("      day %d: sold %d, walk-ins %d, rotifood %d, balance %s, rating %.2f" % [d + 1, int(r["bread_sold"]),
			int(r["physical_customer_count"]), int(r["delivery_completed"]), s.economy.balance, s.reputation.physical])
		var inv: String = s.check_invariants()
		eq(inv, "", "invariants after day %d" % (d + 1))
		bot.after_hours()
	check(s.supply.market_unlocked, "market unlocked after day 3 settlement (GDD 24A.1)")
	eq(s.time.day, 4, "day 4 reached")
	free_sim(s)
