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
## Naik setiap kali daftar catatan cabang berubah (cache bonus kota).
var version: int = 0
var _town_key: String = ""
var _town_cache: float = 0.0


func new_game() -> void:
	stars = 0
	run_index = 1
	branch_no = 1
	recipes_ever.clear()
	branches.clear()
	run_started_day = 1
	run_stars = 0
	version += 1


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
			version += 1
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
	version += 1
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


## Pengali biaya pindah lokasi cabang yang sedang dimainkan (GDD idle 23.1,
## §20 no. 89): 1 sebelum cabang `branch_cost_start`; sesudahnya mengikuti
## pengali penghasilan bintang, max(1, branch_cost_base × star_mult ^
## branch_cost_power). Dulu ×branch_cost_growth per cabang: harga tumbuh
## eksponensial sementara bintang hanya menambah penghasilan secara linear,
## sehingga setiap cabang makin lama dan permainan tanpa ujung lama-lama mentok.
## Kini lama satu cabang tetap sama selamanya. Level, buka stasiun dan resep,
## rekrut, dan dekorasi tetap harga katalog, jadi bonus kota dan mastery tetap
## mempercepat.
func branch_cost_mult() -> float:
	return branch_cost_mult_for(branch_no, stars)


## Pengali biaya pindah lokasi cabang `branch` dengan `star_count` bintang.
static func branch_cost_mult_for(branch: int, star_count: int) -> float:
	if branch < DataRegistry.idlei("prestige.branch_cost_start"):
		return 1.0
	return maxf(1.0, DataRegistry.idlef("prestige.branch_cost_base") * pow(star_mult_for(star_count), DataRegistry.idlef("prestige.branch_cost_power")))


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


## Pengali penghasilan dari bintang (GDD idle 10.3) dan Legacy (§20 no. 90).
func income_mult() -> float:
	return star_mult_for(stars)


## (1 + income_per_star × bintang) × (1 + legacy_income)^level Legacy.
static func star_mult_for(star_count: int) -> float:
	return (1.0 + DataRegistry.idlef("prestige.income_per_star") * float(maxi(star_count, 0))) \
		* pow(1.0 + DataRegistry.idlef("prestige.legacy_income"), float(legacy_level_for(star_count)))


## Level Legacy (GDD idle 23.2, §20 no. 90): tujuan tanpa ujung sesudah perk
## terakhir, satu level setiap `legacy_every_stars` bintang di atas
## `legacy_after_stars`.
static func legacy_level_for(star_count: int) -> int:
	var after: int = DataRegistry.idlei("prestige.legacy_after_stars")
	return maxi(0, (star_count - after) / maxi(1, DataRegistry.idlei("prestige.legacy_every_stars")))


func legacy_level() -> int:
	return legacy_level_for(stars)


## Bintang total untuk level Legacy berikutnya.
func next_legacy_stars() -> int:
	return DataRegistry.idlei("prestige.legacy_after_stars") + (legacy_level() + 1) * DataRegistry.idlei("prestige.legacy_every_stars")


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


# ===========================================================================
# BONUS KOTA DAN ROTI KHAS CABANG (GDD idle 21.7, §20 no. 91, 92)
# ===========================================================================

## Sumbangan satu cabang bertier tertinggi `tier` ke bonus kota.
static func town_bonus_for_tier(tier: int) -> float:
	var arr: Array = DataRegistry.idle("town.bonus_by_tier")
	return float(arr[clampi(tier - 1, 0, arr.size() - 1)])


## Bonus kota (§20 no. 91): setiap cabang, termasuk yang sedang dimainkan,
## menyumbang menurut tier tertinggi yang dicapainya, paling banyak
## `town.max_bonus`. Bagian dari harga biasa semua cabang, jadi membawa cabang
## lama ke Tier 5 membuat seluruh kota lebih kaya. Kota baru ada sesudah
## Waralaba pertama: cabang pertama sendirian tidak mendapat bonus, jadi
## pacing putaran 1 (GDD idle 1.4) tidak berubah.
func town_bonus() -> float:
	var tier: int = sim.world.location.tier if sim.world.location != null else 1
	var key: String = "%d|%d|%d|%d" % [version, branch_no, tier, run_index]
	if key == _town_key:
		return _town_cache
	_town_key = key
	if run_index < 2:
		_town_cache = 0.0
		return 0.0
	var sum: float = town_bonus_for_tier(tier)
	for b: Dictionary in branches:
		sum += town_bonus_for_tier(int(b.get("tier", 1)))
	_town_cache = minf(sum, DataRegistry.idlef("town.max_bonus"))
	return _town_cache


func town_mult() -> float:
	return 1.0 + town_bonus()


## Roti khas cabang `n` (§20 no. 92): satu resep dari katalog, tetap per save
## (benih utama) dan nomor cabang, tidak sama dengan cabang sebelumnya; dijual
## `branch.signature_mult` kali di cabang itu. Cabang pertama tidak punya (&""):
## roti khas adalah ciri cabang Waralaba, dan pacing putaran 1 tidak berubah.
func signature(n: int = -1) -> StringName:
	var b: int = branch_no if n < 0 else n
	if b < 2:
		return &""
	var pick: StringName = _signature_raw(b)
	if b > 2 and pick == _signature_raw(b - 1):
		var all: Array = DataRegistry.recipes()
		var i: int = 0
		for k in all.size():
			if (all[k] as RecipeDefinition).id == pick:
				i = k
		pick = (all[(i + 1) % all.size()] as RecipeDefinition).id
	return pick


func _signature_raw(n: int) -> StringName:
	var all: Array = DataRegistry.recipes()
	if all.is_empty():
		return &""
	var h: int = absi(hash("signature|%d|%d" % [sim.rng.master_seed, n]))
	return (all[h % all.size()] as RecipeDefinition).id


## Pengali harga roti khas cabang yang sedang dimainkan.
func signature_mult(recipe_id: StringName) -> float:
	return DataRegistry.idlef("branch.signature_mult") if recipe_id != &"" and recipe_id == signature() else 1.0


func note_recipe_unlocked(recipe_id: StringName) -> void:
	recipes_ever[String(recipe_id)] = true


func capture() -> Dictionary:
	return {"stars": stars, "run_index": run_index, "branch_no": branch_no, "perks": Array(perks()).map(func(x: StringName) -> String: return String(x)),
		"recipes_ever": recipes_ever.keys(), "branches": branches.duplicate(true), "run_started_day": run_started_day, "run_stars": run_stars}


func restore(d: Dictionary) -> void:
	new_game()
	_town_key = ""
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
