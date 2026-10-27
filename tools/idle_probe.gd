extends Node
## Probe idle (GDD idle 17 P7): memainkan New Game headless dengan SimBot dan
## mencetak satu baris per jam in-game (KR, penghasilan, roti terjual,
## reputasi, staf, tier) serta waktu bermain aktif setiap milestone Seksi 1.4.
##   godot --headless --path . res://tools/idle_probe.tscn -- --minutes=150 --seed=101 [--manage] [--franchise=N]
##       [--max-tier=N] [--every=M] [--quiet] [--set="recipe.level_cost_mult=35;location.upgrade_cost=[0,5e5]"]
## --set menimpa nilai idle.json hanya untuk probe ini (penyetelan P7).
## --franchise=N: bot menjual toko seperti pemain biasa (di Tier 5, atau bila
## lokasi berikutnya lebih dari 30 menit penghasilan) begitu Waralaba memberi
## >= N bintang, lalu mengukur putaran ke-2 sampai milestone yang sama. Menulis save ke folder
## probe sendiri, tidak pernah ke save pemain.

var _minutes: float = 120.0
var _seed: int = 101
var _manage: bool = false
var _franchise_at: int = 0
var _quiet: bool = false
var _max_tier: int = 5
var _every: int = 10


## Timpa nilai katalog idle: "a.b=JSON;c.d=JSON".
func _override(spec: String) -> void:
	for part: String in spec.split(";", false):
		var eq: int = part.find("=")
		var path: PackedStringArray = part.substr(0, eq).strip_edges().split(".")
		var value: Variant = JSON.parse_string(part.substr(eq + 1))
		var node: Dictionary = DataRegistry._idle
		for i in path.size() - 1:
			node = node[path[i]]
		node[path[path.size() - 1]] = value
		print("SET %s = %s" % [".".join(path), value])
	DataRegistry._idle_cache.clear()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--minutes="):
			_minutes = float(a.substr(10))
		elif a.begins_with("--hours="):
			_minutes = float(a.substr(8))
		elif a.begins_with("--seed="):
			_seed = int(a.substr(7))
		elif a == "--manage":
			_manage = true
		elif a.begins_with("--franchise="):
			_franchise_at = int(a.substr(12))
			_manage = true
		elif a == "--quiet":
			_quiet = true
		elif a.begins_with("--max-tier="):
			_max_tier = int(a.substr(11))
		elif a.begins_with("--every="):
			_every = int(a.substr(8))
		elif a.begins_with("--set="):
			_override(a.substr(6))
	SaveManager.dir = "user://probe_saves"
	GameLogger.quiet = true
	await get_tree().process_frame
	var sim := SimulationRoot.new()
	add_child(sim)
	sim.start_new_game(&"profile_probe", "Probe Bakery", "male", _seed)
	var bot := SimBot.new(sim)
	bot.manage = _manage
	bot.max_tier = _max_tier
	var t0: int = Time.get_ticks_usec()
	var pace := PacingTracker.new(sim)
	var ticks_per_minute: int = int(round(60.0 * DataRegistry.sim_seconds_per_real_second() / sim.tick_seconds))
	var run_start: float = 0.0
	var run1: Dictionary = {}
	for m in int(ceil(_minutes)):
		for i in ticks_per_minute:
			bot.think()
			sim.step(sim.tick_seconds)
			pace.note(run_start)
		if _franchise_at > 0 and run1.is_empty() and sim.prestige.franchise_block() == &"" and sim.prestige.stars_gain() >= _franchise_at \
				and pace.franchise_now():
			var at: float = pace.now()
			pace.mark("franchise", at)
			if run1.is_empty():
				run1 = pace.times.duplicate()
			print("FRANCHISE at %.1f min for %d stars" % [at / 60.0, sim.prestige.stars_gain()])
			sim.franchise()
			run_start = pace.now()
			pace.begin_run()
		if not _quiet and (m + 1) % _every == 0:
			print("PROBE min=%d day=%d %s kr=%s rate=%s/s earned=%s sold=%d rep=%.2f staff=%d tier=%d branch=%d %s" % [
				m + 1, sim.time.day, Tx.clock(sim.time.time_seconds), Tx.big(sim.economy.balance), Tx.rate(sim.idle_economy.rate(false)),
				Tx.big(sim.statistics.get_stat("run_earned_kr")), int(sim.statistics.get_stat("total_bread_sold")), sim.reputation.reputation,
				sim.staff.hired_count(), sim.world.location.tier, sim.prestige.run_index,
				"OK" if sim.check_invariants() == "" else "INVARIANT " + sim.check_invariants()])
	for k: String in PacingTracker.KEYS:
		var v: Variant = (run1 if not run1.is_empty() else pace.times).get(k)
		print("MILESTONE %s %s" % [k, "-" if v == null else "%.2f min" % (float(v) / 60.0)])
	if not run1.is_empty():
		for k2: String in PacingTracker.KEYS:
			if pace.run_times.has(k2) and run1.has(k2):
				print("RUN2 %s %.2f min (%.0f%% of run 1)" % [k2, float(pace.run_times[k2]) / 60.0, 100.0 * float(pace.run_times[k2]) / maxf(float(run1[k2]), 0.001)])
	print("RESULT wall_ms=%d decisions=%d" % [(Time.get_ticks_usec() - t0) / 1000, bot.decisions])
	get_tree().quit(0)
