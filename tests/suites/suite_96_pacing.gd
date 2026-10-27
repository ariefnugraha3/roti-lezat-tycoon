extends TestSuite
## Pacing (GDD idle 1.4, 17 P7): SimBot sebagai pemain biasa dari New Game,
## dengan Waralaba saat kemajuannya mandek, lalu putaran ke-2 sampai titik yang
## sama. "Pemain biasa" = median beberapa seed, karena satu seed bisa jatuh
## tipis di tepi jendela. Waktu dalam menit bermain aktif. Lama (puluhan menit):
## dijalankan tanpa --skip-long.

## Batas waktu per milestone (menit): [paling cepat, paling lambat].
const TARGETS: Dictionary = {
	"first_sale": [0.0, 0.5],
	"first_upgrade": [0.0, 1.0],
	"first_assistant": [3.0, 5.0],
	"second_recipe_affordable": [5.0, 8.0],
	"tier2": [12.0, 18.0],
	"tier3": [30.0, 45.0],
	"tier4": [60.0, 80.0],
	"tier5": [100.0, 140.0],
	"franchise": [60.0, 120.0],
}
const SEEDS: Array[int] = [101, 202, 303]
## Bintang paling sedikit untuk menjual (seperti tools/idle_probe.tscn --franchise=N).
const FRANCHISE_STARS: int = 5
## Putaran ke-2 sampai tier tempat putaran 1 dijual: paling lama 70% (GDD idle 1.4).
const RUN2_RATIO: float = 0.70


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_PACING", "name": "idle 1.4 a typical player (median of three SimBot seeds) reaches every milestone in its target window, franchises when progress stalls, and the second branch reaches the same tier in at most 70% of the time", "fn": _pacing, "long": true},
	]


## Satu sesi: putaran 1 sampai Waralaba, lalu putaran 2 sampai tier yang sama.
## Hasil: {times (menit putaran 1), ratio (putaran 2 ÷ putaran 1), invariant}.
func _session(seed_value: int) -> Dictionary:
	var s: SimulationRoot = new_sim(seed_value)
	var bot := SimBot.new(s)
	bot.manage = true
	var pace := PacingTracker.new(s)
	var ticks_per_minute: int = int(round(60.0 * DataRegistry.sim_seconds_per_real_second() / s.tick_seconds))
	var run1: Dictionary = {}
	var sold_tier: int = 0
	for m in 260:
		for i in ticks_per_minute:
			bot.think()
			s.step(s.tick_seconds)
			pace.note()
		if run1.is_empty() and s.prestige.franchise_block() == &"" and s.prestige.stars_gain() >= FRANCHISE_STARS \
				and pace.franchise_now():
			pace.mark("franchise", pace.now())
			run1 = pace.times.duplicate()
			sold_tier = s.world.location.tier
			s.franchise()
			pace.begin_run()
		if not run1.is_empty() and pace.run_times.has("tier%d" % sold_tier):
			break
	var out: Dictionary = {"times": {}, "ratio": -1.0, "invariant": s.check_invariants()}
	var times: Dictionary = run1 if not run1.is_empty() else pace.times
	for k: Variant in times.keys():
		out["times"][k] = float(times[k]) / 60.0
	if not run1.is_empty() and pace.run_times.has("tier%d" % sold_tier):
		out["ratio"] = float(pace.run_times["tier%d" % sold_tier]) / maxf(float(run1["tier%d" % sold_tier]), 0.001)
	free_sim(s)
	return out


static func _median(values: Array) -> float:
	var v: Array = values.duplicate()
	v.sort()
	return float(v[v.size() / 2]) if not v.is_empty() else -1.0


func _pacing() -> void:
	var sessions: Array[Dictionary] = []
	for sd: int in SEEDS:
		var r: Dictionary = _session(sd)
		sessions.append(r)
		eq(str(r["invariant"]), "", "seed %d keeps its invariants" % sd)
	for k: String in PacingTracker.KEYS:
		if not TARGETS.has(k):
			continue
		var lim: Array = TARGETS[k]
		var vals: Array = []
		for r2: Dictionary in sessions:
			vals.append(float((r2["times"] as Dictionary).get(k, 1.0e9)))
		var med: float = _median(vals)
		print("      %s: median %.1f min %s (target %s-%s)" % [k, med, vals.map(func(x: float) -> String: return "%.1f" % x), lim[0], lim[1]])
		check(med >= float(lim[0]) and med <= float(lim[1]), "%s: median %.1f min is within %s-%s min" % [k, med, lim[0], lim[1]])
	var ratios: Array = []
	for r3: Dictionary in sessions:
		ratios.append(float(r3["ratio"]) if float(r3["ratio"]) >= 0.0 else 9.0)
	var med_ratio: float = _median(ratios)
	print("      run 2 / run 1 to the same tier: median %.0f%% %s" % [med_ratio * 100.0, ratios.map(func(x: float) -> String: return "%.0f%%" % (x * 100.0))])
	check(med_ratio <= RUN2_RATIO, "the second branch reaches the sold tier in at most 70%% of the first run's time (median %.0f%%)" % (med_ratio * 100.0))
