class_name GoalManager
extends SimManager
## Misi ringan harian (GDD idle 21.2): mulai hari `goals.first_day`, tiga tujuan
## kecil per hari in-game, masing-masing dari satu template `goals.templates`
## dengan target yang diukur dari toko saat tujuan itu terbit dan hadiah KR yang
## tetap sejak terbit.
##
## Kemajuan = statistik sekarang − nilainya saat tujuan terbit, jadi tujuan tidak
## perlu kait sendiri di setiap sistem. Pukul 00:00 tujuan yang belum selesai
## diganti; tujuan yang selesai tetapi belum diklaim tetap menunggu (tidak ada
## yang hilang). Undian template memakai seed master dan nomor hari, tidak memakai
## stream RNG lain. Waralaba menerbitkan set baru untuk cabang baru.

## Tujuan aktif: [{id, stat, base, target, reward, claimed}].
var goals: Array[Dictionary] = []
## Hari in-game set terakhir terbit.
var day: int = 0


func new_game() -> void:
	goals.clear()
	day = 0


## Pastikan ada set untuk hari ini (awal permainan, setelah load).
func ensure_today() -> void:
	if day != sim.time.day or (goals.is_empty() and started()):
		_issue(sim.time.day)


## Tujuan sudah dimulai (hari `goals.first_day` atau sesudahnya).
func started() -> bool:
	return sim.time.day >= DataRegistry.idlei("goals.first_day")


## Pukul 00:00 (SimulationRoot._on_new_day).
func on_new_day() -> void:
	_issue(sim.time.day)


## Cabang baru (Waralaba): target dan hadiah cabang lama tidak berlaku lagi.
func new_run() -> void:
	goals.clear()
	_issue(sim.time.day)


func _issue(d: int) -> void:
	day = d
	var kept: Array[Dictionary] = []
	for g: Dictionary in goals:
		if is_done(g) and not bool(g["claimed"]):
			kept.append(g)
	goals = kept
	if d < DataRegistry.idlei("goals.first_day"):
		return
	var taken: Dictionary = {}
	for g2: Dictionary in goals:
		taken[str(g2["id"])] = true
	var pool: Array[Dictionary] = []
	for t: Variant in DataRegistry.idle("goals.templates"):
		var td: Dictionary = t
		if not taken.has(str(td["id"])) and _target_for(td) > 0.0:
			pool.append(td)
	var rng := RandomNumberGenerator.new()
	rng.seed = RNGManager._derive(sim.rng.master_seed, "goals_%d_%d" % [sim.prestige.run_index, d])
	var want: int = DataRegistry.idlei("goals.per_day")
	while goals.size() < want and not pool.is_empty():
		var td2: Dictionary = pool.pop_at(rng.randi_range(0, pool.size() - 1))
		var stat: String = str(td2["stat"])
		goals.append({"id": str(td2["id"]), "stat": stat, "base": sim.statistics.get_stat(stat),
			"target": _target_for(td2), "reward": reward_now(), "claimed": false})


## Target template `t` untuk toko sekarang, dibulatkan ke angka enak dibaca.
func _target_for(t: Dictionary) -> float:
	var minutes: float = float(t.get("minutes", 0.0))
	var m: Dictionary = sim.idle_economy.model(false)
	var per_min: float = 60.0 / maxf(float(m.get("real_seconds_per_hour", 60.0)), 0.0001)
	var raw: float = 0.0
	match str(t.get("kind", "")):
		"units":
			raw = float(m.get("units_per_hour", 0.0)) * per_min * minutes
		"customers":
			raw = float(m.get("customers_per_hour", 0.0)) * per_min * minutes
		"rotifood":
			raw = float(m.get("rotifood_per_hour", 0.0)) * per_min * minutes
		"kr":
			raw = sim.idle_economy.rate(false) * 60.0 * minutes
		"fixed":
			var by_tier: Array = t.get("by_tier", [])
			raw = float(by_tier[clampi(sim.world.location.tier - 1, 0, by_tier.size() - 1)]) if not by_tier.is_empty() else 0.0
	if raw <= 0.0:
		return 0.0
	return nice(maxf(raw, float(t.get("min", 1.0))))


## Hadiah satu tujuan bila terbit sekarang: `goals.reward_income_minutes` menit
## KR/s model tanpa boost, paling sedikit `goals.reward_min_kr`, dikali hadiah
## event musiman (GDD idle 21.6).
func reward_now() -> float:
	var kr: float = sim.idle_economy.rate(false) * 60.0 * DataRegistry.idlef("goals.reward_income_minutes") * sim.events.goal_reward_mult()
	return nice(maxf(kr, DataRegistry.idlef("goals.reward_min_kr") * sim.events.goal_reward_mult()))


## Angka bulat yang enak dibaca: dua angka penting (minimal bilangan bulat).
static func nice(x: float) -> float:
	if x <= 0.0:
		return 0.0
	if x < 10.0:
		return ceilf(x)
	var mag: float = pow(10.0, floorf(log(x) / log(10.0)) - 1.0)
	return roundf(x / mag) * mag


func progress(g: Dictionary) -> float:
	return clampf(sim.statistics.get_stat(str(g["stat"])) - float(g["base"]), 0.0, float(g["target"]))


func is_done(g: Dictionary) -> bool:
	return progress(g) >= float(g["target"])


## Jumlah tujuan yang selesai dan menunggu diklaim (titik di HUD).
func claimable() -> int:
	var n: int = 0
	for g: Dictionary in goals:
		if is_done(g) and not bool(g["claimed"]):
			n += 1
	return n


## Klaim tujuan ke-`i`: hadiahnya masuk sebagai REWARD (bukan penghasilan, jadi
## tidak menambah Bintang Waralaba). true bila berhasil.
func claim(i: int) -> bool:
	if i < 0 or i >= goals.size():
		return false
	var g: Dictionary = goals[i]
	if bool(g["claimed"]) or not is_done(g):
		return false
	g["claimed"] = true
	sim.economy.credit(float(g["reward"]), &"REWARD", StringName(str(g["id"])), {})
	sim.statistics.add(&"goals_completed", 1)
	# Golden Crumbs dan XP Bakery Pass (GDD idle 22.3, 22.7).
	sim.premium.on_goal()
	EventBus.sfx.emit(&"level_up", &"")
	SaveManager.request_autosave("goal")
	return true


func capture() -> Dictionary:
	return {"day": day, "goals": goals.duplicate(true)}


func restore(d: Dictionary) -> void:
	new_game()
	day = int(d.get("day", 0))
	var ids: Dictionary = {}
	for t: Variant in DataRegistry.idle("goals.templates"):
		ids[str((t as Dictionary)["id"])] = str((t as Dictionary)["stat"])
	for x: Variant in d.get("goals", []):
		if not (x is Dictionary):
			continue
		var g: Dictionary = x
		var id: String = str(g.get("id", ""))
		if not ids.has(id):
			continue
		goals.append({"id": id, "stat": ids[id], "base": float(g.get("base", 0.0)), "target": maxf(1.0, float(g.get("target", 1.0))),
			"reward": maxf(0.0, float(g.get("reward", 0.0))), "claimed": bool(g.get("claimed", false))})
