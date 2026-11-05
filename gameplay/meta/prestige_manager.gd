class_name PrestigeManager
extends SimManager
## PrestigeManager — Bintang Waralaba, perk, dan nomor putaran (GDD idle 10).
## Bintang tidak dibelanjakan: setiap bintang menambah pengali penghasilan, dan
## total bintang membuka perk permanen (GDD idle 10.3, 10.4).

## Bintang Waralaba yang dimiliki (ID `franchise_stars`).
var stars: int = 0
## Nomor putaran: 1 untuk toko pertama, naik setiap Waralaba.
var run_index: int = 1
## Resep yang pernah dibuka di putaran mana pun (perk_recipe_memory).
var recipes_ever: Dictionary = {}
## Cabang yang sudah dijual, untuk Peta Crumbtown (GDD idle 21.7): {number,
## tier, stars, earned, rate, opened_day, sold_day}.
var branches: Array[Dictionary] = []
## Hari in-game cabang sekarang dibuka.
var run_started_day: int = 1


func new_game() -> void:
	stars = 0
	run_index = 1
	recipes_ever.clear()
	branches.clear()
	run_started_day = 1


## Cabang yang sedang buka, dalam bentuk catatan cabang (Peta Crumbtown):
## bintang = yang didapat bila dijual sekarang.
func current_branch() -> Dictionary:
	return {"number": run_index, "tier": sim.world.location.tier if sim.world.location != null else 1, "stars": stars_gain(),
		"earned": sim.statistics.get_stat("run_earned_kr"), "rate": sim.idle_economy.rate(false),
		"opened_day": run_started_day, "current": true}


## Waralaba (SimulationRoot.franchise): catat cabang yang dijual dengan
## `gained` bintang, sebelum putarannya direset.
func record_branch(gained: int) -> void:
	var b: Dictionary = current_branch()
	b.erase("current")
	b["stars"] = gained
	b["sold_day"] = sim.time.day
	branches.append(b)


## Perk `id` sudah terbuka oleh total bintang (GDD idle 10.4).
func has_perk(id: StringName) -> bool:
	var p: Dictionary = DataRegistry.perk(id)
	return not p.is_empty() and stars >= int(p.get("stars", 0))


## Daftar perk yang terbuka, urut katalog.
func perks() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Variant in DataRegistry.idle("perks"):
		var id: StringName = StringName(str((p as Dictionary)["id"]))
		if has_perk(id):
			out.append(id)
	return out


# ===========================================================================
# BINTANG (GDD idle 10.1, 10.2)
# ===========================================================================

## Total bintang untuk penghasilan sepanjang masa `alltime`:
## floor((alltime / stars_divisor_kr) ^ stars_exponent).
static func stars_for(alltime: float) -> int:
	var x: float = maxf(alltime, 0.0) / DataRegistry.idlef("prestige.stars_divisor_kr")
	return int(minf(floor(pow(x, DataRegistry.idlef("prestige.stars_exponent")) + 1e-9), 1.0e15))


func _alltime() -> float:
	return sim.statistics.get_stat("alltime_earned_kr")


## Bintang baru bila menjual sekarang.
func stars_gain() -> int:
	return maxi(0, stars_for(_alltime()) - stars)


## KR sepanjang masa yang masih dibutuhkan untuk satu bintang lagi.
func kr_to_next_star() -> float:
	var target: float = float(maxi(stars, stars_for(_alltime())) + 1)
	var need: float = DataRegistry.idlef("prestige.stars_divisor_kr") * pow(target, 1.0 / DataRegistry.idlef("prestige.stars_exponent"))
	return maxf(0.0, need - _alltime())


## &"" bila Waralaba boleh sekarang; selain itu alasan: tier (lokasi Tier 3
## belum dicapai di putaran ini) atau stars (belum ada bintang baru).
func franchise_block() -> StringName:
	if sim.world.location.tier < DataRegistry.idlei("prestige.unlock_location_tier"):
		return &"tier"
	if stars_gain() < 1:
		return &"stars"
	return &""


## Pengali biaya pindah lokasi cabang ini (GDD idle 23.1): 1 sampai sebelum
## cabang `branch_cost_start`, lalu branch_cost_growth^(n − start + 1). Level,
## buka stasiun dan resep, rekrut, dan dekorasi tetap harga katalog, supaya
## penghasilan tiap putaran tidak turun dan tangganya tanpa tebing.
func branch_cost_mult() -> float:
	return branch_cost_mult_for(run_index)


static func branch_cost_mult_for(branch: int) -> float:
	var steps: int = maxi(0, branch - DataRegistry.idlei("prestige.branch_cost_start") + 1)
	return pow(DataRegistry.idlef("prestige.branch_cost_growth"), float(steps))


## Nilai perk terbesar (`largest`) atau jumlahnya untuk kunci efek `key` dari
## semua perk yang terbuka (GDD idle 10.4, 23.2); `fallback` bila tidak ada.
func _perk_value(key: String, fallback: float, largest: bool = true) -> float:
	var out: float = fallback
	var found: bool = false
	for p: Variant in DataRegistry.idle("perks"):
		var d: Dictionary = p
		if not d.has(key) or not has_perk(StringName(str(d["id"]))):
			continue
		var v: float = float(d[key])
		if not found:
			out = v
			found = true
		else:
			out = maxf(out, v) if largest else out + v
	return out


## Saldo awal putaran baru: start_kr, atau perk_head_start bila lebih besar.
func start_kr() -> float:
	var base: float = DataRegistry.idlef("start_kr")
	if has_perk(&"perk_head_start"):
		return maxf(base, float(DataRegistry.perk(&"perk_head_start").get("start_kr", base)))
	return base


## Tier lokasi awal putaran baru (perk_ruko_start: Tier 2, perk_mandiri_start:
## Tier 3).
func start_tier() -> int:
	return clampi(int(_perk_value("start_tier", 1.0)), 1, 5)


## Pengali penghasilan dari bintang (GDD idle 10.3).
func income_mult() -> float:
	return 1.0 + DataRegistry.idlef("prestige.income_per_star") * float(stars)


func tap_mult() -> float:
	return float(DataRegistry.perk(&"perk_tap_double").get("tap_mult", 2)) if has_perk(&"perk_tap_double") else 1.0


## Pengali milestone resep dari perk (×3, lalu ×4), 0 bila belum ada.
func recipe_milestone_mult() -> float:
	return _perk_value("recipe_milestone_mult", 0.0)


## Jam offline tambahan dari semua perk (dijumlahkan).
func offline_hours_bonus() -> float:
	return _perk_value("offline_hours", 0.0, false)


## Pengali lama kopi Pak Lurah (perk_coffee_long, GDD idle 23.2).
func coffee_mult() -> float:
	return _perk_value("coffee_mult", 1.0)


## Pengali jeda roti emas (perk_golden_rain: 0,5 = dua kali lebih sering).
func golden_interval_mult() -> float:
	return _perk_value("golden_interval_mult", 1.0)


func offline_efficiency_bonus() -> float:
	return float(DataRegistry.perk(&"perk_offline_efficiency").get("offline_efficiency", 0.25)) if has_perk(&"perk_offline_efficiency") else 0.0


func note_recipe_unlocked(recipe_id: StringName) -> void:
	recipes_ever[String(recipe_id)] = true


func capture() -> Dictionary:
	return {"stars": stars, "run_index": run_index, "perks": Array(perks()).map(func(x: StringName) -> String: return String(x)),
		"recipes_ever": recipes_ever.keys(), "branches": branches.duplicate(true), "run_started_day": run_started_day}


func restore(d: Dictionary) -> void:
	new_game()
	stars = maxi(0, int(d.get("stars", 0)))
	run_index = maxi(1, int(d.get("run_index", 1)))
	for r: Variant in d.get("recipes_ever", []):
		if DataRegistry.recipe(StringName(str(r))) != null:
			recipes_ever[str(r)] = true
	run_started_day = maxi(1, int(d.get("run_started_day", 1)))
	for b: Variant in d.get("branches", []):
		if b is Dictionary and int((b as Dictionary).get("number", 0)) >= 1:
			var e: Dictionary = {}
			for k: String in ["number", "tier", "stars", "opened_day", "sold_day"]:
				e[k] = int((b as Dictionary).get(k, 0))
			for k2: String in ["earned", "rate"]:
				e[k2] = float((b as Dictionary).get(k2, 0.0))
			branches.append(e)
