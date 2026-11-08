class_name PrestigeManager
extends SimManager
## PrestigeManager — Bintang Waralaba, perk, dan cabang (GDD idle 10, 21.7, §20
## no. 78). Bintang tidak dibelanjakan: setiap bintang menambah pengali
## penghasilan, dan total bintang membuka perk permanen (GDD idle 10.3, 10.4).
##
## Waralaba tidak menjual toko lagi (§20 no. 78): cabang lama tetap milik pemain
## dan bisa dikunjungi dari Peta Crumbtown. Cabang yang sedang dimainkan hidup di
## simulasi; setiap cabang lain hanya catatan di `branches`, dengan state
## tokonya (`state`, bagian save milik cabang itu, SimulationRoot.BRANCH_KEYS)
## dan acuan tabungannya (`left_unix`, `rate`, `cap`, `eff`): selama ditinggal,
## cabang menabung seperti penghasilan offline (GDD idle 9.2).

## Bintang Waralaba yang dimiliki (ID `franchise_stars`).
var stars: int = 0
## Nomor cabang terbaru (= jumlah cabang yang pernah dibuka); naik setiap
## Waralaba.
var run_index: int = 1
## Nomor cabang yang sedang dimainkan (1..run_index).
var branch_no: int = 1
## Resep yang pernah dibuka di putaran mana pun (perk_recipe_memory).
var recipes_ever: Dictionary = {}
## Catatan setiap cabang selain yang sedang dimainkan, urut nomor (Peta
## Crumbtown, GDD idle 21.7): {number, tier (tertinggi), stars (didapat saat
## cabang sesudahnya dibuka), earned, rate (KR/s model tanpa boost saat
## ditinggal), opened_day, left_unix, cap, eff, state}. Catatan tanpa `state`
## (cabang yang dijual sebelum §20 no. 78, atau `unknown` dari save sebelum
## peta) dibangun ulang sebagai toko awal saat pertama dikunjungi.
var branches: Array[Dictionary] = []
## Hari in-game cabang yang sedang dimainkan dibuka.
var run_started_day: int = 1
## Bintang yang sudah didapat cabang yang sedang dimainkan (catatan `stars`).
var run_stars: int = 0


func new_game() -> void:
	stars = 0
	run_index = 1
	branch_no = 1
	recipes_ever.clear()
	branches.clear()
	run_started_day = 1
	run_stars = 0


## Cabang yang sedang dimainkan, dalam bentuk catatan cabang (Peta Crumbtown):
## `stars` = yang didapat bila Waralaba sekarang, `stars_earned` = yang sudah
## didapatnya.
func current_branch() -> Dictionary:
	return {"number": branch_no, "tier": sim.world.location.tier if sim.world.location != null else 1, "stars": stars_gain(),
		"stars_earned": run_stars, "earned": sim.statistics.get_stat("run_earned_kr"), "rate": sim.idle_economy.rate(false),
		"opened_day": run_started_day, "current": true}


## Catatan cabang `n` yang sedang tidak dimainkan, atau {}.
func record(n: int) -> Dictionary:
	for b: Dictionary in branches:
		if int(b["number"]) == n:
			return b
	return {}


## Tier tertinggi cabang terbaru: syarat Waralaba berikutnya (GDD idle 10.1).
func newest_tier() -> int:
	if branch_no == run_index:
		return sim.world.location.tier if sim.world.location != null else 1
	return int(record(run_index).get("tier", 1))


## Waralaba: bintang `gained` dicatat untuk cabang terbaru, yang membuka cabang
## berikutnya.
func credit_newest(gained: int) -> void:
	if branch_no == run_index:
		run_stars += gained
	else:
		var r: Dictionary = record(run_index)
		if not r.is_empty():
			r["stars"] = int(r.get("stars", 0)) + gained


## Cabang yang sedang dimainkan ditinggal: catatannya disimpan bersama `state`
## dan acuan tabungannya (`left_unix` 0 = tidak diketahui, tanpa tabungan).
func store_current(state: Dictionary, left_unix: float, rate: float, cap: float, eff: float) -> void:
	var b: Dictionary = current_branch()
	b.erase("current")
	b["stars"] = run_stars
	b.erase("stars_earned")
	b["left_unix"] = maxf(left_unix, 0.0)
	b["rate"] = maxf(rate, 0.0)
	b["cap"] = maxf(cap, 0.0)
	b["eff"] = maxf(eff, 0.0)
	b["state"] = state
	_put(b)


## Mulai memainkan cabang `n`: catatannya diambil dari `branches` (state-nya
## dipakai SimulationRoot) dan dikembalikan.
func take(n: int) -> Dictionary:
	var r: Dictionary = {}
	for i in branches.size():
		if int(branches[i]["number"]) == n:
			r = branches[i]
			branches.remove_at(i)
			break
	branch_no = n
	run_started_day = maxi(1, int(r.get("opened_day", sim.time.day)))
	run_stars = maxi(0, int(r.get("stars", 0)))
	return r


## Cabang baru `n` dibuka hari ini (Waralaba).
func open_new(n: int) -> void:
	branch_no = n
	run_started_day = sim.time.day
	run_stars = 0


## Tabungan cabang `r` yang menunggu bila dikunjungi pada jam unix `now`:
## KR/s saat ditinggal × min(lama ditinggal, batas) × efisiensi, 0 bila belum
## `offline.min_away_seconds`. Perkiraan Peta; kunjungannya sendiri memakai
## batas dan efisiensi cabang itu saat dimuat (OfflineManager.settle_branch).
static func waiting_kr(r: Dictionary, now: float) -> float:
	var left: float = float(r.get("left_unix", 0.0))
	if left <= 0.0 or now <= left or (r.get("state", {}) as Dictionary).is_empty():
		return 0.0
	var away: float = now - left
	if away < DataRegistry.idlef("offline.min_away_seconds"):
		return 0.0
	return Money.round_cents(float(r.get("rate", 0.0)) * minf(away, float(r.get("cap", 0.0))) * float(r.get("eff", 0.0)))


func _put(b: Dictionary) -> void:
	var at: int = branches.size()
	for i in branches.size():
		if int(branches[i]["number"]) > int(b["number"]):
			at = i
			break
	branches.insert(at, b)


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


## &"" bila Waralaba boleh sekarang (dari cabang mana pun); selain itu alasan:
## tier (cabang terbaru belum mencapai lokasi Tier 3) atau stars (belum ada
## bintang baru).
func franchise_block() -> StringName:
	if newest_tier() < DataRegistry.idlei("prestige.unlock_location_tier"):
		return &"tier"
	if stars_gain() < 1:
		return &"stars"
	return &""


## Pengali biaya pindah lokasi cabang yang sedang dimainkan (GDD idle 23.1): 1 sampai sebelum
## cabang `branch_cost_start`, lalu branch_cost_growth^(n − start + 1). Level,
## buka stasiun dan resep, rekrut, dan dekorasi tetap harga katalog, supaya
## penghasilan tiap putaran tidak turun dan tangganya tanpa tebing.
func branch_cost_mult() -> float:
	return branch_cost_mult_for(branch_no)


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
	return {"stars": stars, "run_index": run_index, "branch_no": branch_no, "perks": Array(perks()).map(func(x: StringName) -> String: return String(x)),
		"recipes_ever": recipes_ever.keys(), "branches": branches.duplicate(true), "run_started_day": run_started_day, "run_stars": run_stars}


func restore(d: Dictionary) -> void:
	new_game()
	stars = maxi(0, int(d.get("stars", 0)))
	run_index = maxi(1, int(d.get("run_index", 1)))
	branch_no = clampi(int(d.get("branch_no", run_index)), 1, run_index)
	for r: Variant in d.get("recipes_ever", []):
		if DataRegistry.recipe(StringName(str(r))) != null:
			recipes_ever[str(r)] = true
	run_started_day = maxi(1, int(d.get("run_started_day", 1)))
	run_stars = maxi(0, int(d.get("run_stars", 0)))
	for b: Variant in d.get("branches", []):
		var n: int = int((b as Dictionary).get("number", 0)) if b is Dictionary else 0
		if n < 1 or n > run_index or n == branch_no or not record(n).is_empty():
			continue
		var e: Dictionary = {}
		for k: String in ["number", "tier", "stars", "opened_day"]:
			e[k] = int((b as Dictionary).get(k, 0))
		e["tier"] = clampi(int(e["tier"]), 1, 5)
		for k2: String in ["earned", "rate", "left_unix", "cap", "eff"]:
			e[k2] = maxf(float((b as Dictionary).get(k2, 0.0)), 0.0)
		if (b as Dictionary).has("sold_day"):
			e["sold_day"] = int((b as Dictionary)["sold_day"])
		if bool((b as Dictionary).get("unknown", false)):
			e["unknown"] = true
		var st: Variant = (b as Dictionary).get("state", {})
		if st is Dictionary and not (st as Dictionary).is_empty():
			e["state"] = (st as Dictionary).duplicate(true)
		_put(e)
	# Cabang dari save sebelum peta hanya tahu nomornya (GDD idle 21.7): tempat
	# kosong bertoko tier `unlock_location_tier`, dibangun ulang saat dikunjungi.
	for n2 in range(1, run_index + 1):
		if n2 != branch_no and record(n2).is_empty():
			_put({"number": n2, "tier": DataRegistry.idlei("prestige.unlock_location_tier"), "stars": 0, "earned": 0.0, "rate": 0.0,
				"opened_day": 0, "left_unix": 0.0, "cap": 0.0, "eff": 0.0, "unknown": true})
