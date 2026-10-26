extends Node
## Probe idle (GDD idle 17 P7): memainkan New Game headless dan mencetak satu
## baris per jam in-game: KR, penghasilan, roti terjual, reputasi, staf, tier.
##   godot --headless --path . res://tools/idle_probe.tscn -- --hours=4 --seed=101 [--manage]
## Menulis save ke folder probe sendiri, tidak pernah ke save pemain.

var _hours: float = 2.0
var _seed: int = 101
var _manage: bool = false


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--hours="):
			_hours = float(a.substr(8))
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
		elif a == "--manage":
			_manage = true
	SaveManager.dir = "user://probe_saves"
	GameLogger.quiet = true
	await get_tree().process_frame
	var sim := SimulationRoot.new()
	add_child(sim)
	sim.start_new_game(&"profile_probe", "Probe Bakery", "male", _seed)
	var bot := SimBot.new(sim)
	bot.manage = _manage
	var per_hour: int = int(round(sim.time.sim_seconds_for_hours(1.0) / sim.tick_seconds))
	var t0: int = Time.get_ticks_usec()
	var first_sale: float = -1.0
	for h in int(ceil(_hours)):
		for i in per_hour:
			bot.think()
			sim.step(sim.tick_seconds)
			if first_sale < 0.0 and sim.statistics.get_stat("total_bread_sold") > 0.0:
				first_sale = DataRegistry.real_seconds(sim.time.sim_seconds)
		var inv: String = sim.check_invariants()
		print("PROBE h=%d day=%d %s kr=%s earned=%s sold=%d served=%d lost=%d missed=%d rep=%.2f staff=%d tier=%d jobs=%d table=%d %s" % [
			h + 1, sim.time.day, Tx.clock(sim.time.time_seconds), Tx.big(sim.economy.balance),
			Tx.big(sim.statistics.get_stat("run_earned_kr")), int(sim.statistics.get_stat("total_bread_sold")),
			int(sim.statistics.get_stat("total_customers_served")), int(sim.statistics.get_stat("total_customers_left_no_purchase") + sim.statistics.get_stat("total_customers_lost_patience")),
			int(sim.statistics.get_stat("total_customers_missed")), sim.reputation.reputation, sim.staff.hired_count(),
			sim.world.location.tier, sim.production.jobs.size(), sim.production.table_jobs().size(),
			"OK" if inv == "" else "INVARIANT " + inv])
	print("RESULT first_sale_real_s=%.1f wall_ms=%d" % [first_sale, (Time.get_ticks_usec() - t0) / 1000])
	get_tree().quit(0)
