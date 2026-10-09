class_name TestSuite
extends RefCounted
## Basis suite test headless (GDD 107). Setiap suite mengembalikan daftar
## {id, name, fn, long} dari `tests()`; runner memanggil `fn` dengan suite ini
## sebagai konteks assert.

var failures: Array[String] = []
var checks: int = 0
var runner: Node = null


func tests() -> Array:
	return []


func check(cond: bool, msg: String) -> bool:
	checks += 1
	if not cond:
		failures.append(msg)
	return cond


func eq(a: Variant, b: Variant, msg: String) -> bool:
	return check(a == b, "%s (got %s, expected %s)" % [msg, str(a), str(b)])


func near(a: float, b: float, eps: float, msg: String) -> bool:
	return check(absf(a - b) <= eps, "%s (got %s, expected %s ±%s)" % [msg, a, b, eps])


## SimulationRoot baru dengan New Game deterministik.
func new_sim(seed_value: int = 12345, pid: StringName = &"profile_test") -> SimulationRoot:
	var s := SimulationRoot.new()
	runner.add_child(s)
	s.start_new_game(pid, "Test Bakery", "male", seed_value)
	return s


func free_sim(s: SimulationRoot) -> void:
	if s != null and is_instance_valid(s):
		s.get_parent().remove_child(s)
		s.free()


## Majukan ke jam in-game tertentu (detik sejak 00:00) memakai tick kanonik.
func run_until(s: SimulationRoot, clock_seconds: float, bot: SimBot = null) -> void:
	while s.is_running() and s.time.time_seconds < clock_seconds:
		if bot != null:
			bot.think()
		s.step(s.tick_seconds)


func run_day(s: SimulationRoot, bot: SimBot) -> void:
	while s.is_running():
		if bot != null:
			bot.think()
		s.step(s.tick_seconds)


## Lompat ke lokasi tier `tier` lewat alur upgrade sungguhan (after-hours,
## KR cukup), lalu mulai hari berikutnya pukul 05:00.
func jump_to_tier(s: SimulationRoot, tier: int) -> void:
	while s.world.location.tier < tier:
		s.time.set_phase(TimeManager.AFTER_HOURS)
		s.debug_add_kr(s.next_location().upgrade_cost_kr)
		var r: String = s.upgrade_location()
		if r != "":
			push_error("[TEST] upgrade to tier %d failed: %s" % [s.world.location.tier + 1, r])
			return
	s.time.set_phase(TimeManager.AFTER_HOURS)
	s.continue_to_next_day()


## Pembeli dan pengunjung lihat-lihat datang dulu dari ujung trotoar (GDD 20.1):
## majukan tick kanonik sampai `c` melewati pintu. false bila belum sampai.
func walk_in(s: SimulationRoot, c: Customer, limit: float = 60.0) -> bool:
	var t: float = 0.0
	while c.state == Customer.APPROACHING and t < limit and s.is_running():
		s.step(s.tick_seconds)
		t += s.tick_seconds
	return c.state != Customer.APPROACHING


## Stok rak langsung (tanpa produksi) di petak `index` rak pertama.
func stock(s: SimulationRoot, recipe_id: StringName, qty: int, index: int = 0, iid: int = -1) -> int:
	var d: int = iid if iid >= 0 else s.equipment.placed_list(&"display")[0].iid
	return s.display.place(d, index, recipe_id, qty, 1.0, s.time.sim_seconds, 999)


## Sidik jari state untuk perbandingan determinisme: seluruh save tanpa
## field yang memang bergantung pada waktu dinding atau UI.
static func fingerprint(s: SimulationRoot) -> String:
	var d: Dictionary = s.capture_save()
	d.erase("created_at")
	d.erase("ui_restore")
	(d["clock"] as Dictionary).erase("speed")
	(d["statistics"] as Dictionary).erase("stats")
	return JSON.stringify(d, "", true, true)


## Salinan save lewat JSON (seperti tulis/baca file sungguhan).
static func json_copy(d: Dictionary) -> Dictionary:
	return JSON.parse_string(JSON.stringify(d, "", true, true))


## SimulationRoot baru yang direkonstruksi dari save.
func load_sim(d: Dictionary) -> SimulationRoot:
	var s := SimulationRoot.new()
	runner.add_child(s)
	s.load_from_save(d)
	return s


## Save yang dinormalisasi lewat JSON untuk dibandingkan dengan diff_state.
static func state_of(s: SimulationRoot) -> Dictionary:
	return normalize_save(s.capture_save())


static func normalize_save(d: Dictionary) -> Dictionary:
	var c: Dictionary = json_copy(d)
	for k: String in ["created_at", "last_played_at", "last_played_unix", "game_version", "ui_restore"]:
		c.erase(k)
	if c.has("clock"):
		(c["clock"] as Dictionary).erase("speed")
	if c.has("statistics"):
		(c["statistics"] as Dictionary).erase("stats")
	return c


## Daftar path yang berbeda (maks `limit`). Angka dibandingkan sebagai float.
static func diff_state(a: Variant, b: Variant, path: String = "", out: Array[String] = [], limit: int = 8) -> Array[String]:
	if out.size() >= limit:
		return out
	var num_a: bool = a is int or a is float
	var num_b: bool = b is int or b is float
	if num_a and num_b:
		if absf(float(a) - float(b)) > 0.000001 * maxf(1.0, absf(float(a))):
			out.append("%s: %s != %s" % [path, a, b])
		return out
	if typeof(a) != typeof(b):
		out.append("%s: type %s != %s" % [path, type_string(typeof(a)), type_string(typeof(b))])
		return out
	if a is Dictionary:
		var keys: Dictionary = {}
		for k: Variant in (a as Dictionary).keys():
			keys[k] = true
		for k2: Variant in (b as Dictionary).keys():
			keys[k2] = true
		var sorted_keys: Array = keys.keys()
		sorted_keys.sort()
		for k3: Variant in sorted_keys:
			if not (a as Dictionary).has(k3) or not (b as Dictionary).has(k3):
				out.append("%s/%s: only in %s" % [path, k3, "A" if (a as Dictionary).has(k3) else "B"])
			else:
				diff_state((a as Dictionary)[k3], (b as Dictionary)[k3], "%s/%s" % [path, k3], out, limit)
			if out.size() >= limit:
				break
		return out
	if a is Array:
		if (a as Array).size() != (b as Array).size():
			out.append("%s: size %d != %d" % [path, (a as Array).size(), (b as Array).size()])
			return out
		for i in (a as Array).size():
			diff_state(a[i], b[i], "%s[%d]" % [path, i], out, limit)
			if out.size() >= limit:
				break
		return out
	if a != b:
		out.append("%s: %s != %s" % [path, str(a).left(80), str(b).left(80)])
	return out


func same_state(a: Dictionary, b: Dictionary, msg: String) -> bool:
	var d: Array[String] = diff_state(a, b)
	return check(d.is_empty(), "%s: %s" % [msg, "; ".join(d)])


## State logis untuk perbandingan save/load. Transform aktor (posisi, arah,
## rute, tugas staf yang sedang berjalan) dikanonisasi saat load (GDD 77.2,
## 81 no.16) sehingga dikeluarkan; semua timer, stage, uang, stok, antrean,
## pesanan, dan RNG tetap dibandingkan persis.
static func logical_state(d: Dictionary) -> Dictionary:
	var c: Dictionary = normalize_save(d)
	_strip_keys(c, ["actor", "driver", "facing", "stall_time"])
	if c.has("player"):
		var p: Dictionary = c["player"]
		var cmds: Array = []
		var cur: Dictionary = p.get("current", {})
		if not cur.is_empty():
			cmds.append([cur["kind"], cur["target"]])
		for x: Variant in p.get("commands", []):
			cmds.append([(x as Dictionary)["kind"], (x as Dictionary)["target"]])
		p["commands"] = cmds
		p.erase("current")
		p.erase("next_command_id")
	if c.has("staff"):
		(c["staff"] as Dictionary).erase("actors")
		(c["staff"] as Dictionary).erase("tasks")
	# Pemilih petak yang terbuka saat disimpan kembali ke loyang yang dibawa saat
	# load (PlayerTaskManager.reconstruct), seperti transform aktor.
	if c.has("production_jobs"):
		for j: Variant in (c["production_jobs"] as Dictionary).get("jobs", []):
			if str((j as Dictionary).get("stage", "")) == "PLACEMENT_UI":
				(j as Dictionary)["stage"] = "CARRIED_TO_DISPLAY"
	if c.has("supply_orders"):
		(c["supply_orders"] as Dictionary).erase("couriers")
	c.erase("active_floor_id")
	return c


static func _strip_keys(v: Variant, keys: Array) -> void:
	if v is Dictionary:
		for k: String in keys:
			(v as Dictionary).erase(k)
		for x: Variant in (v as Dictionary).values():
			_strip_keys(x, keys)
	elif v is Array:
		for y: Variant in v:
			_strip_keys(y, keys)
