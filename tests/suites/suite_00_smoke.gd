extends TestSuite
## Smoke: New Game idle lalu satu jam in-game berjalan sendiri tanpa input.


func tests() -> Array:
	return [
		{"id": "SMOKE_001", "name": "new game starts at 08:00 Day 1 with start_kr, the starter stations and Plain Loaf in the first slot", "fn": _new_game},
		{"id": "SMOKE_002", "name": "the shop bakes and sells by itself for three in-game hours", "fn": _first_hours},
	]


func _new_game() -> void:
	var s: SimulationRoot = new_sim()
	eq(s.time.day, 1, "day")
	near(s.time.time_seconds, DataRegistry.idlef("clock.start_seconds"), 0.01, "starts at clock.start_seconds")
	near(s.economy.balance, DataRegistry.idlef("start_kr"), 0.01, "start_kr (GDD idle 7.1)")
	eq(s.equipment.placed_count(&"mixer"), 1, "one mixer placed")
	eq(s.equipment.placed_count(&"oven"), 1, "one oven placed")
	eq(s.equipment.placed_count(&"display"), 1, "one display placed")
	eq(s.equipment.placed_count(&"storage"), 1, "storage placed")
	check(s.equipment.table_instance() != null and s.equipment.table_instance().placed, "holding table placed")
	check(s.world.layout_valid(), "starter layout keeps protected paths")
	for e: EquipmentInstance in s.equipment.placed_list():
		check(not s.world.access_of(e.iid).is_empty(), "%s has an access tile" % e.def_id)
	var d: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	eq(s.display.assignment(d.iid, 0), &"recipe_plain_loaf", "Plain Loaf goes straight into the first slot (GDD idle 8.5)")
	eq(s.upgrades.unlocked_recipes(), [&"recipe_plain_loaf"] as Array[StringName], "only Plain Loaf is unlocked")
	eq(s.upgrades.counter_level, 1, "counter Lv 1")
	eq(s.reputation.reputation, DataRegistry.idlef("reputation.start"), "reputation starts at 3.0")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _first_hours() -> void:
	var s: SimulationRoot = new_sim(777)
	for h in 3:
		run_hours(s, 1.0)
		eq(s.check_invariants(), "", "invariants after hour %d" % (h + 1))
	var sold: int = int(s.statistics.get_stat("total_bread_sold"))
	print("      3 h: sold %d, earned %s, balance %s, reputation %.2f" % [sold, Tx.big(s.statistics.get_stat("run_earned_kr")),
		Tx.big(s.economy.balance), s.reputation.reputation])
	check(sold > 20, "the shop sold bread with no input (sold %d)" % sold)
	check(s.statistics.get_stat("run_earned_kr") > 0.0, "run_earned_kr counts the sales")
	free_sim(s)
