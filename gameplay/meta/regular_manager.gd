class_name RegularManager
extends SimManager
## Pelanggan langganan (GDD idle 21.10): warga Crumbtown bernama dari
## `regulars.list` yang sesekali datang dengan pesanan khusus. Hanya saat
## bermain aktif: semua timer dalam detik nyata permainan aktif, jadi tidak ada
## kunjungan saat pemain pergi. Pesanan diselesaikan lewat minigame "pack the
## order" di UI (RegularOrderScreen); hasilnya `complete(stars)` atau `fail()`.
##
## Setiap pesanan yang selesai menambah pertemanan; ambang `regulars.levels`
## membuka hati berikutnya, satu kenangan (teks cerita) dan hadiah KR.
## Undian (siapa yang datang, isi pesanan, jeda) memakai seed master dan nomor
## kunjungan, tidak memakai stream RNG lain. Sosoknya di toko adalah pengunjung
## kosmetik (CustomerManager.admit_regular).

static var enabled: bool = true

## Minigame pesanan (Seksi 20 no. 110): kemas pesanan, panggang pas, ingat pesanan.
const GAMES: Array[String] = ["pack", "bake", "memory"]

## Detik nyata sampai kunjungan berikutnya.
var next_in: float = 0.0
## Kunjungan berjalan: {id, order: [recipe ids], reward, wait_left, customer,
## game} atau {}.
var visit: Dictionary = {}
## Nomor kunjungan (naik setiap kunjungan).
var visits: int = 0
## Pertemanan: id -> {orders, level}.
var friends: Dictionary = {}
## Regular kunjungan terakhir (tidak datang dua kali berturut-turut).
var last_id: String = ""


func new_game() -> void:
	next_in = DataRegistry.idlef("regulars.first_after_minutes") * 60.0
	visit = {}
	visits = 0
	friends.clear()
	last_id = ""


static func list() -> Array:
	return DataRegistry.idle("regulars.list")


static func def(id: String) -> Dictionary:
	for x: Variant in list():
		if str((x as Dictionary)["id"]) == id:
			return x
	return {}


func friend(id: String) -> Dictionary:
	return friends.get(id, {"orders": 0, "level": 0})


func level_of(id: String) -> int:
	return int(friend(id).get("level", 0))


## Pesanan selesai yang dibutuhkan untuk hati berikutnya (-1 bila sudah penuh).
func next_level_orders(id: String) -> int:
	var lv: Array = DataRegistry.idle("regulars.levels")
	var l: int = level_of(id)
	return int(lv[l]) if l < lv.size() else -1


func step(dt: float) -> void:
	if not enabled:
		return
	var r: float = DataRegistry.real_seconds(dt)
	if not visit.is_empty():
		visit["wait_left"] = float(visit["wait_left"]) - r
		_keep_customer()
		if float(visit["wait_left"]) <= 0.0:
			_end_visit(false)
		return
	next_in -= r
	if next_in <= 0.0:
		_start_visit()


func _rng(salt: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = RNGManager._derive(sim.rng.master_seed, "regular_%s_%d" % [salt, visits])
	return rng


func _schedule() -> void:
	var span: Array = DataRegistry.idle("regulars.interval_minutes")
	next_in = _rng("next").randf_range(float(span[0]), float(span[1])) * 60.0


func _start_visit() -> void:
	var makeable: Array[StringName] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.can_make(r.id):
			makeable.append(r.id)
	if makeable.is_empty():
		_schedule()
		return
	visits += 1
	var rng: RandomNumberGenerator = _rng("pick")
	var options: Array = []
	for x: Variant in list():
		if str((x as Dictionary)["id"]) != last_id:
			options.append(x)
	var d: Dictionary = options[rng.randi_range(0, options.size() - 1)]
	var id: String = str(d["id"])
	last_id = id
	# Pesanan: roti favoritnya bila bisa dibuat, sisanya acak dari yang bisa dibuat.
	var n: int = mini(int(DataRegistry.idlef("regulars.order_items_base")) + level_of(id) / 2, int(DataRegistry.idlef("regulars.order_items_max")))
	var order: Array = []
	var fav: StringName = StringName(str(d.get("favorite", "")))
	if makeable.has(fav):
		order.append(String(fav))
	while order.size() < n:
		order.append(String(makeable[rng.randi_range(0, makeable.size() - 1)]))
	var reward: float = GoalManager.nice(maxf(DataRegistry.idlef("regulars.min_kr"),
		sim.idle_economy.rate(false) * 60.0 * DataRegistry.idlef("regulars.reward_income_minutes")))
	visit = {"id": id, "order": order, "reward": reward, "wait_left": DataRegistry.idlef("regulars.wait_seconds"), "customer": "",
		"game": game_for_order(visits, order)}
	_keep_customer()
	EventBus.notify.emit(1, "ui_regular_arrived", {"name": Tx.t(id)}, &"heart")
	EventBus.sfx.emit(&"door_bell_enter", &"")


## Minigame kunjungan ke-`n` (Seksi 20 no. 110): kunjungan pertama selalu
## "pack" (yang dijelaskan tip onb_regular), selanjutnya diacak dari seed master
## dan nomor kunjungan dan tidak pernah sama dengan kunjungan sebelumnya. Undian
## memakai salt sendiri, jadi siapa yang datang dan isi pesanannya tidak berubah.
func game_for(n: int) -> String:
	var games: Array = DataRegistry.idle("regulars.games")
	if games.is_empty():
		return "pack"
	var g: int = 0
	for k in range(2, n + 1):
		if games.size() < 2:
			break
		var rng := RandomNumberGenerator.new()
		rng.seed = RNGManager._derive(sim.rng.master_seed, "regular_game_%d" % k)
		g = (g + 1 + rng.randi_range(0, games.size() - 2)) % games.size()
	return str(games[g])


## Minigame yang dimainkan untuk pesanan `order`: Ingat Pesanan butuh minimal
## dua jenis roti (pesanan satu jenis cukup dilihat sekilas), jadi pesanan
## seperti itu memainkan minigame lain yang bukan undian kunjungan sebelumnya.
func game_for_order(n: int, order: Array) -> String:
	var g: String = game_for(n)
	var kinds: Dictionary = {}
	for rid: Variant in order:
		kinds[str(rid)] = true
	if g != "memory" or kinds.size() >= 2:
		return g
	var prev: String = game_for(n - 1) if n > 1 else ""
	for alt: Variant in DataRegistry.idle("regulars.games"):
		if str(alt) != "memory" and str(alt) != prev:
			return str(alt)
	return "pack"


## Sosok regular di toko: masuk sekali ada tempat, menunggu selama kunjungan.
func _keep_customer() -> void:
	if visit.is_empty():
		return
	var cid: StringName = StringName(str(visit.get("customer", "")))
	if cid == &"" or sim.customers.customer(cid) == null:
		visit["customer"] = String(sim.customers.admit_regular(StringName(str(visit["id"]))))
	else:
		sim.customers.hold_regular(cid)


## Hadiah KR pesanan ini untuk `stars` bintang (1-3).
func reward_for(stars: int) -> float:
	if visit.is_empty():
		return 0.0
	var bonus: Array = DataRegistry.idle("regulars.star_bonus")
	return Money.round_cents(float(visit["reward"]) * float(bonus[clampi(stars, 1, 3) - 1]))


## Minigame selesai dengan `stars` bintang (1-3). Hasil: {kr, level_up, level,
## gift}; {} bila tidak ada kunjungan.
func complete(stars: int) -> Dictionary:
	if visit.is_empty():
		return {}
	var id: String = str(visit["id"])
	var kr: float = reward_for(stars)
	sim.economy.credit(kr, &"REWARD", StringName(id), {"stars": stars})
	var f: Dictionary = friend(id).duplicate()
	f["orders"] = int(f.get("orders", 0)) + 1
	var out: Dictionary = {"kr": kr, "level_up": false, "level": int(f.get("level", 0)), "gift": 0.0}
	var need: int = next_level_orders(id)
	if need > 0 and int(f["orders"]) >= need:
		f["level"] = int(f.get("level", 0)) + 1
		var gift: float = GoalManager.nice(maxf(DataRegistry.idlef("regulars.min_kr"),
			sim.idle_economy.rate(false) * 60.0 * DataRegistry.idlef("regulars.level_gift_income_minutes")))
		sim.economy.credit(gift, &"REWARD", StringName(id), {"level": f["level"]})
		out["level_up"] = true
		out["level"] = int(f["level"])
		out["gift"] = gift
	friends[id] = f
	sim.statistics.add(&"regular_orders", 1)
	_end_visit(true)
	return out


## Minigame gagal (waktu habis): regular pulang tanpa hadiah, pertemanan tetap.
func fail() -> void:
	if not visit.is_empty():
		_end_visit(false)


func _end_visit(happy: bool) -> void:
	var cid: StringName = StringName(str(visit.get("customer", "")))
	if cid != &"":
		sim.customers.release_regular(cid, happy)
	visit = {}
	_schedule()


func capture() -> Dictionary:
	return {"next_in": next_in, "visit": visit.duplicate(true), "visits": visits, "friends": friends.duplicate(true), "last_id": last_id}


func restore(d: Dictionary) -> void:
	new_game()
	next_in = float(d.get("next_in", next_in))
	visits = maxi(0, int(d.get("visits", 0)))
	last_id = str(d.get("last_id", ""))
	for k: Variant in (d.get("friends", {}) as Dictionary).keys():
		if not def(str(k)).is_empty():
			var f: Dictionary = d["friends"][k]
			friends[str(k)] = {"orders": maxi(0, int(f.get("orders", 0))), "level": clampi(int(f.get("level", 0)), 0, (DataRegistry.idle("regulars.levels") as Array).size())}
	var v: Variant = d.get("visit", {})
	if v is Dictionary and not (v as Dictionary).is_empty() and not def(str((v as Dictionary).get("id", ""))).is_empty():
		var order: Array = []
		for rid: Variant in (v as Dictionary).get("order", []):
			if DataRegistry.recipe(StringName(str(rid))) != null:
				order.append(str(rid))
		if not order.is_empty():
			# Sosoknya ikut tersimpan sebagai pengunjung; bila tidak ada, ia masuk lagi.
			var g: String = str(v.get("game", "pack"))
			visit = {"id": str(v["id"]), "order": order, "reward": maxf(0.0, float(v.get("reward", 0.0))),
				"wait_left": float(v.get("wait_left", 1.0)), "customer": str(v.get("customer", "")),
				"game": g if GAMES.has(g) else "pack"}
