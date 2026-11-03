class_name GoldenManager
extends SimManager
## Roti Emas (GDD idle 21.9): selama bermain aktif, sesekali roti emas terbang
## melintasi layar selama `golden.visible_seconds` detik nyata. Mengetuknya
## memberi satu hadiah acak berbobot (`golden.rewards`): KR, Golden hour
## (penghasilan ×mult sebentar), atau Rush hour (pembeli ×mult sebentar).
##
## Semua timer dalam detik nyata permainan aktif (detik-simulasi dikonversi),
## jadi berhenti saat pause, di latar, dan selama offline: roti emas tidak
## pernah muncul atau memberi apa pun saat pemain pergi. Undian jeda dan hadiah
## memakai seed master dan nomor penerbangan, tidak memakai stream RNG lain.

## Tes yang mengukur ekonomi tidak terganggu: roti emas tidak muncul bila mati.
static var enabled: bool = true

## Detik nyata sampai roti emas berikutnya muncul.
var next_in: float = 0.0
## Detik nyata sisa terbangnya (0 = tidak ada roti emas di layar).
var visible_left: float = 0.0
## Nomor penerbangan (naik setiap kali muncul); juga menentukan arah terbangnya.
var flight: int = 0
var catches: int = 0


func new_game() -> void:
	next_in = DataRegistry.idlef("golden.first_after_minutes") * 60.0
	visible_left = 0.0
	flight = 0
	catches = 0


func step(dt: float) -> void:
	if not enabled:
		return
	var r: float = DataRegistry.real_seconds(dt)
	if visible_left > 0.0:
		visible_left = maxf(0.0, visible_left - r)
		if visible_left <= 0.0:
			_schedule()
		return
	next_in -= r
	if next_in <= 0.0:
		flight += 1
		visible_left = DataRegistry.idlef("golden.visible_seconds")
		EventBus.sfx.emit(&"tap_boost_pop", &"")


func is_flying() -> bool:
	return visible_left > 0.0


## Bagian terbang yang sudah dilalui, 0..1 (posisi gambarnya di layar).
func progress() -> float:
	var total: float = DataRegistry.idlef("golden.visible_seconds")
	return clampf(1.0 - visible_left / maxf(total, 0.001), 0.0, 1.0)


func _rng(salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNGManager._derive(sim.rng.master_seed, "golden_%s_%d" % [salt, flight])
	return rng


func _schedule() -> void:
	visible_left = 0.0
	var span: Array = DataRegistry.idle("golden.interval_minutes")
	next_in = _rng("next").randf_range(float(span[0]), float(span[1])) * 60.0


## Hadiah penerbangan ini bila ditangkap: {id, kr, mult, seconds}.
func reward_now() -> Dictionary:
	var weights: Dictionary = {}
	var defs: Dictionary = {}
	for x: Variant in DataRegistry.idle("golden.rewards"):
		var d: Dictionary = x
		weights[str(d["id"])] = float(d.get("weight", 1.0))
		defs[str(d["id"])] = d
	var id: String = str(RNGManager.weighted_pick(_rng("reward"), weights))
	var d2: Dictionary = defs.get(id, {})
	var out: Dictionary = {"id": id, "kr": 0.0, "mult": float(d2.get("mult", 1.0)), "seconds": float(d2.get("seconds", 0.0))}
	if id == "golden_kr":
		out["kr"] = GoalManager.nice(maxf(DataRegistry.idlef("golden.min_kr"), sim.idle_economy.rate(false) * 60.0 * float(d2.get("income_minutes", 1.0))))
	return out


## Ketuk roti emas yang sedang terbang. Mengembalikan hadiahnya ({} bila tidak ada).
func catch() -> Dictionary:
	if not is_flying():
		return {}
	var r: Dictionary = reward_now()
	match str(r["id"]):
		"golden_kr":
			sim.economy.credit(float(r["kr"]), &"REWARD", &"golden", {})
		"golden_frenzy":
			sim.boosts.add_frenzy(float(r["mult"]), float(r["seconds"]))
		"golden_rush":
			sim.boosts.add_rush(float(r["mult"]), float(r["seconds"]))
	catches += 1
	sim.statistics.add(&"golden_caught", 1)
	EventBus.sfx.emit(&"coin_shower", &"")
	_schedule()
	return r


func capture() -> Dictionary:
	return {"next_in": next_in, "visible_left": visible_left, "flight": flight, "catches": catches}


func restore(d: Dictionary) -> void:
	new_game()
	next_in = maxf(0.0, float(d.get("next_in", next_in)))
	visible_left = clampf(float(d.get("visible_left", 0.0)), 0.0, DataRegistry.idlef("golden.visible_seconds"))
	flight = maxi(0, int(d.get("flight", 0)))
	catches = maxi(0, int(d.get("catches", 0)))
