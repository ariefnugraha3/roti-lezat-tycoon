class_name PacingTracker
extends RefCounted
## Waktu bermain aktif (detik nyata) setiap milestone GDD idle 1.4, untuk
## tools/idle_probe.tscn dan ACC_IDLE_PACING. `times` dihitung dari New Game;
## `run_times` dari awal putaran sekarang (setelah Waralaba).

## second_recipe_affordable: resep kedua pertama kali bisa dibuka (petunjuk
## onb_recipe muncul, GDD idle 13); second_recipe: benar-benar dibuka.
const KEYS: Array[String] = ["first_sale", "first_upgrade", "first_assistant", "second_recipe_affordable", "second_recipe",
	"tier2", "tier3", "tier4", "tier5", "franchise"]

var sim: SimulationRoot
var times: Dictionary = {}
var run_times: Dictionary = {}
var _run_start: float = 0.0


func _init(s: SimulationRoot) -> void:
	sim = s


## Detik nyata bermain aktif sejak New Game.
func now() -> float:
	return DataRegistry.real_seconds(sim.time.sim_seconds)


func mark(key: String, at: float) -> void:
	if not times.has(key):
		times[key] = at
	if not run_times.has(key):
		run_times[key] = at - _run_start


func begin_run() -> void:
	_run_start = now()
	run_times.clear()


## Catat milestone yang baru tercapai (panggil setelah setiap tick).
func note(_run_start_unused: float = 0.0) -> void:
	var t: float = now()
	if not run_times.has("first_sale") and sim.statistics.get_stat("run_earned_kr") > 0.0:
		mark("first_sale", t)
	if not run_times.has("first_upgrade") and _any_upgrade():
		mark("first_upgrade", t)
	if not run_times.has("first_assistant") and sim.staff.hired_count() > 0:
		mark("first_assistant", t)
	if not run_times.has("second_recipe") and sim.upgrades.unlocked_recipes().size() >= 2:
		mark("second_recipe", t)
	if not run_times.has("second_recipe_affordable") and sim.upgrades.unlocked_recipes().size() < 2:
		for r: RecipeDefinition in DataRegistry.recipes():
			if sim.upgrades.unlock_block(r.id) == &"":
				mark("second_recipe_affordable", t)
				break
	var tier: int = sim.world.location.tier
	for n in range(2, 6):
		var k: String = "tier%d" % n
		if tier >= n and not run_times.has(k):
			mark(k, t)


## Menit bermain paling sedikit di tier sekarang sebelum pemain biasa menyerah
## menunggu lokasi berikutnya.
const STALL_MINUTES: float = 20.0


## Pemain biasa menjual toko saat kemajuannya mandek: di Tier 5, atau setelah
## STALL_MINUTES di tier yang sama bila lokasi berikutnya masih lebih dari 30
## menit penghasilan (KR/s tanpa boost).
func franchise_now() -> bool:
	var nxt: LocationDefinition = sim.next_location()
	if nxt == null:
		return true
	var tier: int = sim.world.location.tier
	var since: float = float(run_times.get("tier%d" % tier, 0.0)) if tier > 1 else 0.0
	if now() - _run_start - since < STALL_MINUTES * 60.0:
		return false
	return SimulationRoot.location_cost(nxt.tier) > sim.idle_economy.rate(false) * 60.0 * 30.0


func _any_upgrade() -> bool:
	if sim.upgrades.counter_level > 1:
		return true
	for v: Variant in sim.upgrades.station_levels.values():
		if int(v) > 1:
			return true
	for v2: Variant in sim.upgrades.recipe_levels.values():
		if int(v2) > 1:
			return true
	for v3: Variant in sim.upgrades.staff_levels.values():
		if int(v3) > 1:
			return true
	for v4: Variant in sim.upgrades.global_levels.values():
		if int(v4) > 0:
			return true
	return false
