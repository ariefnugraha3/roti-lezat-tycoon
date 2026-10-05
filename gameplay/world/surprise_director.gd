class_name SurpriseDirector
extends Node3D
## Kejutan kosmetik di toko (keputusan maintainer 2026-10-04, GDD 31.9): adegan
## kecil yang sesekali lewat saat toko buka, murni tontonan. Kucing oren mampir,
## anak kecil kabur dikejar ibunya, Pak Lurah menyapa, maskot roti menari,
## pengamen memetik ukulele, turis berfoto, kupu-kupu nyasar, dan burung pipit
## mencari remah.
##
## Semuanya hidup di lapisan tampilan: pemerannya ActorView/model sementara yang
## tidak didaftarkan ke simulasi, rutenya hanya membaca graf navigasi publik,
## jadwalnya dari RandomNumberGenerator sendiri yang diturunkan dari master seed
## (tanpa menggeser stream RNG simulasi), dan tidak ada yang disimpan. Stok,
## antrean, rating, dan uang tidak pernah tersentuh.
##
## Jadwal (`plan`): tiap hari 2-3 kejutan (`presentation.surprise_per_day`) pada
## jam acak di dalam `presentation.surprise_hours`, dipilih dari yang paling lama
## tidak tampil dan tidak pernah sama dengan kejutan kemarin. Kejutan mulai
## setelah jamnya tiba, saat toko buka, game tidak di-pause, bukan Decoration
## Mode, dan kamera sedang menampilkan lantai toko. Toko tutup = adegan selesai.

const NAV: int = FloorGrid.NAV_PUBLIC
## Kecepatan pemeran (meter per detik nyata).
const SPEED_WALK: float = 1.0
const SPEED_KID: float = 2.0
const SPEED_MOM: float = 1.55
const SPEED_LURAH: float = 0.9
const SPEED_CAT: float = 0.7
const SPEED_MASCOT: float = 0.75
const SPEED_HOP: float = 0.45
const SPEED_FLY: float = 0.9
## Lama muncul/menghilang (skala) pemeran di pintu (detik).
const POP_SECONDS: float = 0.25
## Laju pembauran bobot pose (per detik).
const POSE_RATE: float = 6.0
## Batas waktu satu adegan (detik nyata): pengaman bila rute macet.
const MAX_SECONDS: float = 90.0
## Kejutan yang belum bisa mulai (pemain di lantai lain, Decoration Mode) batal
## bila sudah terlambat lebih dari ini (detik jam in-game, 1,5 jam), supaya
## kejutan yang tertunda tidak tampil beruntun.
const LATE_SECONDS: float = 5400.0

var sim: SimulationRoot = null
var view: WorldView = null
var _plan_day: int = -1
var _todo: Array[Dictionary] = []
var _cast: Array[Dictionary] = []
var _flags: Dictionary = {}
var _kind: StringName = &""
var _rng := RandomNumberGenerator.new()
var _t: float = 0.0
var _fx: Array[Node3D] = []
var _shown: bool = true


func setup(s: SimulationRoot, wv: WorldView) -> void:
	sim = s
	view = wv
	name = "Surprises"


## Kejutan yang sedang dimainkan, atau &"".
func running() -> StringName:
	return _kind


## Sisa rencana hari ini: [{kind, at}] (detik jam in-game).
func todo() -> Array[Dictionary]:
	return _todo


## Model para pemeran yang masih tampil di adegan.
func cast_nodes() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for m: Dictionary in _cast:
		var n: Variant = m.get("node")
		if n != null and is_instance_valid(n):
			out.append(n)
	return out


## Gelembung kalimat para pemeran yang sedang tampil.
func bubbles_showing() -> Array[ThoughtBubble]:
	var out: Array[ThoughtBubble] = []
	for m: Dictionary in _cast:
		var b: Variant = m.get("bubble")
		if b != null and is_instance_valid(b) and (b as ThoughtBubble).is_showing():
			out.append(b)
	return out


# ===========================================================================
# JADWAL
# ===========================================================================

## Rencana kejutan hari `day` untuk master seed `seed_value`: [{kind, at}],
## urut jam. Deterministik: hari 1..day disusun berurutan dengan RNG per hari,
## memilih kejutan yang paling lama tidak tampil, tanpa kejutan kemarin, dan
## tiap kejutan jatuh di bagiannya sendiri dari jendela jam.
static func plan(seed_value: int, day: int) -> Array[Dictionary]:
	var kinds: Array = DataRegistry.bal("presentation.surprise_kinds")
	var per_day: Array = DataRegistry.bal("presentation.surprise_per_day")
	var hours: Array = DataRegistry.bal("presentation.surprise_hours")
	var last_used: Dictionary = {}
	var yesterday: Array[String] = []
	var out: Array[Dictionary] = []
	for d in range(1, day + 1):
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d|%d|surprise" % [seed_value, d])
		var n: int = rng.randi_range(int(per_day[0]), int(per_day[1]))
		var pool: Array[String] = []
		var tie: Dictionary = {}
		for k: Variant in kinds:
			if not yesterday.has(str(k)):
				pool.append(str(k))
				tie[str(k)] = rng.randf()
		pool.sort_custom(func(a: String, b: String) -> bool:
			var la: int = int(last_used.get(a, -9999))
			var lb: int = int(last_used.get(b, -9999))
			if la != lb:
				return la < lb
			return float(tie[a]) < float(tie[b]))
		var picked: Array[String] = pool.slice(0, mini(n, pool.size()))
		# Urutan dalam sehari diacak dengan RNG hari itu (Fisher-Yates).
		for i in range(picked.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var tmp: String = picked[i]
			picked[i] = picked[j]
			picked[j] = tmp
		for k2: String in picked:
			last_used[k2] = d
		yesterday = picked
		if d == day:
			var h0: float = float(hours[0])
			var slot: float = (float(hours[1]) - h0) / float(maxi(picked.size(), 1))
			for i2 in picked.size():
				out.append({"kind": StringName(picked[i2]), "at": (h0 + slot * (float(i2) + rng.randf_range(0.15, 0.85))) * 3600.0})
	return out


func update(delta: float) -> void:
	if sim == null or view == null:
		return
	if _plan_day != sim.time.day:
		_plan_day = sim.time.day
		var now: float = sim.time.time_seconds
		_todo.clear()
		for e: Dictionary in plan(sim.rng.master_seed, sim.time.day):
			# Load di tengah hari: kejutan yang jamnya sudah lama lewat dilewati.
			if float(e["at"]) > now - LATE_SECONDS:
				_todo.append(e)
	if _kind != &"":
		if not sim.time.is_open():
			abort()
			return
		_apply_visibility()
		var paused: bool = PauseManager.is_paused()
		if not paused:
			_step(delta)
		_place_bubbles(0.0 if paused else delta)
		return
	if PauseManager.is_paused() or not sim.time.is_open():
		return
	while not _todo.is_empty() and sim.time.time_seconds > float(_todo[0]["at"]) + LATE_SECONDS:
		_todo.pop_front()
	if _todo.is_empty() or view.decoration_mode or view.camera_rig.active_floor != sim.world.store_floor():
		return
	if sim.time.time_seconds >= float(_todo[0]["at"]):
		start(_todo.pop_front()["kind"])


## Mulai kejutan `kind` sekarang (juga dipakai tes). false bila tidak bisa.
func start(kind: StringName) -> bool:
	abort()
	_kind = kind
	_rng.seed = hash("%d|%d|%s|cast" % [sim.rng.master_seed, sim.time.day, kind])
	_flags.clear()
	_t = 0.0
	match kind:
		&"cat":
			_cat()
		&"kid_chase":
			_kid_chase()
		&"lurah":
			_lurah()
		&"mascot":
			_mascot()
		&"busker":
			_busker()
		&"tourists":
			_tourists()
		&"butterfly":
			_butterfly()
		&"sparrow":
			_sparrow()
	if _cast.is_empty():
		_kind = &""
		return false
	GameLogger.info("WORLD", "surprise %s starts" % kind)
	_apply_visibility()
	return true


## Hentikan adegan dan bersihkan semua pemeran, gelembung, dan efeknya.
func abort() -> void:
	for m: Dictionary in _cast:
		_free_member(m)
	_cast.clear()
	for f: Node3D in _fx:
		if is_instance_valid(f):
			f.queue_free()
	_fx.clear()
	# Partikel yang biasanya membebaskan dirinya sendiri (kilau kilatan kamera)
	# ikut dibuang, supaya tidak ada sisa adegan di bawah node ini.
	for c: Node in get_children():
		c.queue_free()
	_flags.clear()
	_kind = &""


# ===========================================================================
# NASKAH ADEGAN
# ===========================================================================

## Kucing oren mampir: mengendus rak roti, duduk, mengeong, menjilat kaki, pergi.
func _cat() -> void:
	var spot: Dictionary = _display_spot()
	var m: Dictionary = _critter("cat", CritterFactory.cat(), SPEED_CAT)
	m["queue"] = [
		{"do": "enter", "cell": spot["cell"]},
		{"do": "face", "at": spot["center"]},
		{"do": "pose", "name": "sniff", "t": 1.4},
		{"do": "pose", "name": "sit", "t": 0.7},
		{"do": "say", "key": "surprise_cat_meow", "t": 2.4},
		{"do": "fx", "name": "heart"},
		{"do": "pose", "name": "lick", "t": 2.6},
		{"do": "pose", "name": "sit", "t": 0.9},
		{"do": "exit"},
	]


## Anak kecil berlari masuk dan berputar mengelilingi rak; ibunya menyusul,
## lalu keduanya membungkuk minta maaf dan pulang.
func _kid_chase() -> void:
	var spot: Dictionary = _display_spot()
	var ring: Array[Vector2i] = _ring(spot)
	var kid: Dictionary = _person(_spec("customer_school_child", "senang"), SPEED_KID)
	var mom: Dictionary = _person(_spec("customer_bulk_buyer", "kaget"), SPEED_MOM)
	var loop: Array = [{"do": "enter", "cell": ring[0]}, {"do": "say", "key": "surprise_kid_whee", "t": 2.2}]
	for lap in 2:
		for i in range(1, ring.size()):
			loop.append({"do": "walk", "cell": ring[i]})
		loop.append({"do": "walk", "cell": ring[0]})
	kid["queue"] = loop + [
		{"do": "signal", "name": "kid_done"},
		{"do": "until", "name": "mom_here"},
		{"do": "face", "member": mom},
		{"do": "mood", "name": "sedih"},
		{"do": "say", "key": "surprise_kid_sorry", "t": 2.0},
		{"do": "pose", "name": "bow", "t": 1.2},
		{"do": "until", "name": "mom_leaving"},
		{"do": "wait", "t": 0.5},
		{"do": "exit"},
	]
	mom["queue"] = [
		{"do": "wait", "t": 2.2},
		{"do": "enter", "cell": _neighbor(ring[0], ring)},
		{"do": "say", "key": "surprise_mom_call", "t": 2.4},
		{"do": "until", "name": "kid_done"},
		{"do": "signal", "name": "mom_here"},
		{"do": "face", "member": kid},
		{"do": "wait", "t": 2.3},
		{"do": "face", "at": GridMath.cell_center(_counter_cell())},
		{"do": "mood", "name": "senang"},
		{"do": "say", "key": "surprise_mom_sorry", "t": 2.4},
		{"do": "pose", "name": "bow", "t": 1.4},
		{"do": "signal", "name": "mom_leaving"},
		{"do": "exit"},
	]


## Pak Lurah mampir menyapa: melambai, mengacungkan semangat, lalu pamit.
func _lurah() -> void:
	# Kunjungan santai: tanpa koper dan amplop bantuan (GDD 49) di tangannya.
	var spec: Dictionary = CharacterFactory.spec_for_lurah()
	spec["prop"] = PackedStringArray()
	var m: Dictionary = _person(spec, SPEED_LURAH)
	m["queue"] = [
		{"do": "enter", "cell": _center_cell()},
		{"do": "face", "cam": 0.0},
		{"do": "say", "key": "surprise_lurah_hello", "t": 3.0},
		{"do": "pose", "name": "wave", "t": 2.4},
		{"do": "jump"},
		{"do": "wait", "t": 0.9},
		{"do": "exit"},
	]


## Maskot roti masuk, menari sambil menyapa, melambai, lalu keluar.
func _mascot() -> void:
	var m: Dictionary = _critter("mascot", CritterFactory.bread_mascot(), SPEED_MASCOT)
	m["queue"] = [
		{"do": "enter", "cell": _center_cell()},
		{"do": "face", "cam": 0.0},
		{"do": "say", "key": "surprise_mascot_hello", "t": 3.0},
		{"do": "pose", "name": "dance", "t": 4.0},
		{"do": "pose", "name": "wave", "t": 1.8},
		{"do": "exit"},
	]


## Pengamen berdiri dekat pintu memetik ukulele, berterima kasih, lalu pergi.
func _busker() -> void:
	var spec: Dictionary = _spec("customer_generic", "senang")
	spec["hat"] = "topi_pet"
	var m: Dictionary = _person(spec, SPEED_WALK)
	var uke: MeshInstance3D = CritterFactory.ukulele()
	uke.visible = true
	(m["node"] as Node3D).add_child(uke)
	m["prop"] = uke
	m["queue"] = [
		{"do": "enter", "cell": _near_door(2)},
		{"do": "face", "cam": 0.0},
		{"do": "pose", "name": "strum", "t": 5.5},
		{"do": "say", "key": "surprise_busker_thanks", "t": 2.4},
		{"do": "pose", "name": "bow", "t": 1.4},
		{"do": "exit"},
	]


## Dua turis masuk; yang satu memotret rak roti dengan kilatan kamera, yang
## lain kegirangan, lalu keduanya keluar.
func _tourists() -> void:
	var spot: Dictionary = _display_spot()
	var stand: Vector2i = _photo_spot(spot)
	var a_spec: Dictionary = _spec("customer_generic", "senang")
	a_spec["prop"] = PackedStringArray(["kamera"])
	a_spec["hat"] = "topi_pet"
	var b_spec: Dictionary = _spec("customer_generic", "senang")
	var ta: Dictionary = _person(a_spec, SPEED_WALK)
	var tb: Dictionary = _person(b_spec, SPEED_WALK)
	ta["queue"] = [
		{"do": "enter", "cell": stand},
		{"do": "face", "at": spot["center"]},
		{"do": "until", "name": "b_ready"},
		{"do": "say", "key": "surprise_tourist_cheese", "t": 1.3},
		{"do": "pose", "name": "photo", "t": 1.4},
		{"do": "fx", "name": "flash"},
		{"do": "signal", "name": "flash"},
		{"do": "pose", "name": "photo", "t": 1.0},
		{"do": "wait", "t": 0.8},
		{"do": "exit"},
	]
	tb["queue"] = [
		{"do": "wait", "t": 0.8},
		{"do": "enter", "cell": _beside(stand)},
		{"do": "face", "at": spot["center"]},
		{"do": "signal", "name": "b_ready"},
		{"do": "until", "name": "flash"},
		{"do": "say", "key": "surprise_tourist_cute", "t": 2.2},
		{"do": "jump"},
		{"do": "wait", "t": 1.6},
		{"do": "exit"},
	]


## Kupu-kupu masuk lewat pintu, berputar-putar di atas rak, hinggap sebentar,
## lalu terbang keluar.
func _butterfly() -> void:
	var spot: Dictionary = _display_spot()
	var c: Vector2 = spot["center"]
	var top: float = float(spot["height"]) + 0.06
	var m: Dictionary = _critter("butterfly", CritterFactory.butterfly(), SPEED_FLY)
	var outside: Vector2 = _outside_pos()
	var door: Vector2 = GridMath.cell_center(sim.world.entrance_cell())
	var path_in: Array[Vector3] = [Vector3(outside.x, 0.95, outside.y), Vector3(door.x, 1.05, door.y)]
	for i in 17:
		var a: float = TAU * float(i) / 8.0 + 1.2
		path_in.append(Vector3(c.x + cos(a) * 0.55, top + 0.25 + 0.12 * sin(a * 2.0), c.y + sin(a) * 0.55))
	var perch := Vector3(c.x, top, c.y)
	path_in.append(perch)
	m["pos3"] = path_in[0]
	m["queue"] = [
		{"do": "fly", "points": path_in},
		{"do": "pose", "name": "perch", "t": 1.8},
		{"do": "fly", "points": [perch + Vector3(0.0, 0.35, 0.0), Vector3(door.x, 1.05, door.y), Vector3(outside.x, 1.0, outside.y)]},
		{"do": "despawn"},
	]


## Burung pipit terbang masuk, melompat ke dekat rak, mematuk remah, berkicau,
## lalu terbang keluar.
func _sparrow() -> void:
	var spot: Dictionary = _display_spot()
	var ring: Array[Vector2i] = _ring(spot)
	var land: Vector2 = GridMath.cell_center(ring[0])
	var hop1: Vector2 = GridMath.cell_center(ring[1 % ring.size()])
	var outside: Vector2 = _outside_pos()
	var door: Vector2 = GridMath.cell_center(sim.world.entrance_cell())
	var m: Dictionary = _critter("sparrow", CritterFactory.sparrow(), SPEED_HOP)
	m["pos3"] = Vector3(outside.x, 0.6, outside.y)
	m["queue"] = [
		{"do": "fly", "points": [Vector3(outside.x, 0.6, outside.y), Vector3(door.x, 0.45, door.y), Vector3(land.x, 0.0, land.y)]},
		{"do": "fx", "name": "crumbs"},
		{"do": "pose", "name": "peck", "t": 1.6},
		{"do": "hop", "to": hop1},
		{"do": "pose", "name": "look", "t": 1.2},
		{"do": "say", "key": "surprise_sparrow_tweet", "t": 1.8},
		{"do": "pose", "name": "peck", "t": 1.2},
		{"do": "fly", "points": [Vector3(hop1.x, 0.5, hop1.y), Vector3(door.x, 0.7, door.y), Vector3(outside.x, 0.9, outside.y)]},
		{"do": "despawn"},
	]


# ===========================================================================
# PEMERAN
# ===========================================================================

func _spec(customer_id: String, mood: String) -> Dictionary:
	var spec: Dictionary = CharacterFactory.spec_for_customer(customer_id, _rng.randi_range(1, 99999))
	spec["mood"] = mood
	return spec


func _new_member(type: String, node: Node3D, speed: float) -> Dictionary:
	var a := SimActor.new()
	a.id = StringName("surprise_%s_%d" % [_kind, _cast.size()])
	a.kind = &"surprise"
	a.nav_class = NAV
	a.speed_mps = speed
	a.floor_id = sim.world.store_floor()
	a.place_at(a.floor_id, sim.world.entrance_cell())
	add_child(node)
	node.scale = Vector3.ONE * 0.001
	var m: Dictionary = {"type": type, "node": node, "actor": a, "queue": [], "act": {}, "pose": "", "pose_t": 0.0,
		"pose_len": 1.0, "pose_w": 0.0, "pose_last": "", "say_key": "", "say_left": 0.0, "bubble": null, "phase": 0.0,
		"pop": 0.0, "leaving": false, "gone": false, "pos3": Vector3.INF, "base_scale": 1.0, "fx_timer": 0.0}
	_cast.append(m)
	return m


func _person(spec: Dictionary, speed: float) -> Dictionary:
	var v := ActorView.new()
	var m: Dictionary = _new_member("person", v, speed)
	v.bind((m["actor"] as SimActor).id, "surprise|%s|%d" % [_kind, _cast.size()], spec)
	v.set_busy(true)
	return m


## Hewan atau maskot; skala bawaan modelnya dibaca sebelum `_new_member`
## mengecilkannya untuk animasi muncul.
func _critter(type: String, node: Node3D, speed: float) -> Dictionary:
	var base: float = node.scale.x if node.scale.x > 0.01 else 1.0
	var m: Dictionary = _new_member(type, node, speed)
	m["base_scale"] = base
	return m


## Bebaskan model dan gelembung pemeran `m`; referensinya dikosongkan supaya
## tidak ada yang membaca node yang sudah dibebaskan. Antrean aksinya juga
## dikosongkan: aksi "face" menyimpan pemeran lain, dan rujukan melingkar
## antar-Dictionary tidak pernah dilepas.
func _free_member(m: Dictionary) -> void:
	for key: String in ["node", "bubble"]:
		var n: Variant = m.get(key)
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
		m[key] = null
	m["queue"] = []
	m["act"] = {}
	m["say_left"] = 0.0
	m["gone"] = true


# ===========================================================================
# JALANNYA ADEGAN
# ===========================================================================

func _step(delta: float) -> void:
	_t += delta
	var alive: bool = false
	for m: Dictionary in _cast:
		if bool(m["gone"]):
			continue
		alive = true
		_run_actions(m, delta)
		_animate(m, delta)
	_step_fx(delta)
	if not alive or _t > MAX_SECONDS:
		GameLogger.info("WORLD", "surprise %s ends" % _kind)
		abort()


## Jalankan antrean aksi pemeran `m`: aksi seketika (bicara, sinyal, efek)
## diproses dalam frame yang sama, aksi berdurasi berhenti sampai selesai.
## Waktu berjalan sebuah aksi disimpan di "el"; "t" tetap durasi dari naskah.
func _run_actions(m: Dictionary, delta: float) -> void:
	var guard: int = 0
	while guard < 16 and not bool(m["gone"]):
		guard += 1
		var act: Dictionary = m["act"]
		if act.is_empty():
			var q: Array = m["queue"]
			if q.is_empty():
				return
			act = (q.pop_front() as Dictionary).duplicate()
			act["el"] = 0.0
			act["step"] = 0
			m["act"] = act
			_begin(m, act)
			if not _advance(m, act, 0.0):
				return
		elif not _advance(m, act, delta):
			return
		m["act"] = {}


## Persiapan saat sebuah aksi dimulai.
func _begin(m: Dictionary, act: Dictionary) -> void:
	var a: SimActor = m["actor"]
	match str(act["do"]):
		"enter":
			var out: Vector2 = _outside_pos()
			a.pos = out
			a.facing = (GridMath.cell_center(sim.world.entrance_cell()) - out).normalized()
			_straight(a, GridMath.cell_center(sim.world.entrance_cell()))
		"walk":
			a.go_to(sim.world, a.floor_id, act["cell"])
		"exit":
			m["leaving"] = true
			m["pose"] = ""
			if not a.go_to(sim.world, a.floor_id, sim.world.entrance_cell()):
				_straight(a, GridMath.cell_center(sim.world.entrance_cell()))
		"pose":
			m["pose"] = str(act["name"])
			m["pose_t"] = 0.0
			m["pose_len"] = float(act["t"])
			m["pose_last"] = str(act["name"])
			_mood_for_pose(m, str(act["name"]))
		"hop":
			m["hop_from"] = Vector2(a.pos)
		"fly":
			if (m["pos3"] as Vector3) == Vector3.INF:
				m["pos3"] = Vector3(a.pos.x, 0.0, a.pos.y)
			act["i"] = 0


## true bila aksi `act` selesai pada frame ini.
func _advance(m: Dictionary, act: Dictionary, delta: float) -> bool:
	var a: SimActor = m["actor"]
	act["el"] = float(act["el"]) + delta
	match str(act["do"]):
		"enter":
			a.step(delta, sim.world)
			if a.has_route():
				return false
			if int(act["step"]) == 0:
				act["step"] = 1
				if not a.go_to(sim.world, a.floor_id, act["cell"]):
					return true
				return false
			return true
		"walk":
			a.step(delta, sim.world)
			return not a.has_route()
		"exit":
			a.step(delta, sim.world)
			if a.has_route():
				return false
			if int(act["step"]) == 0:
				act["step"] = 1
				_straight(a, _outside_pos())
				return false
			# Di luar pintu: mengecil lalu hilang.
			m["pop"] = maxf(0.0, float(m["pop"]) - delta / POP_SECONDS)
			if float(m["pop"]) <= 0.0:
				_free_member(m)
			return bool(m["gone"])
		"despawn":
			m["leaving"] = true
			m["pop"] = maxf(0.0, float(m["pop"]) - delta / POP_SECONDS)
			if float(m["pop"]) <= 0.0:
				_free_member(m)
			return bool(m["gone"])
		"wait":
			return float(act["el"]) >= float(act["t"])
		"until":
			return _flags.has(str(act["name"]))
		"signal":
			_flags[str(act["name"])] = true
			return true
		"say":
			# Satu pembicara pada satu waktu: tunggu kalimat pemeran lain habis.
			for other: Dictionary in _cast:
				if not is_same(other, m) and not bool(other["gone"]) and float(other["say_left"]) > 0.0:
					return false
			m["say_key"] = str(act["key"])
			m["say_left"] = float(act["t"])
			return true
		"mood":
			if m["type"] == "person":
				CharacterFactory.set_expression((m["node"] as ActorView).model, str(act["name"]))
			return true
		"jump":
			if m["type"] == "person":
				ProceduralAnimationSystem.happy_jump((m["node"] as ActorView).model)
			return true
		"face":
			if act.has("cam"):
				a.facing = _toward_camera(float(act["cam"]))
				return true
			var target: Vector2 = Vector2.INF
			if act.has("member"):
				target = ((act["member"] as Dictionary)["actor"] as SimActor).pos
			elif act.has("at"):
				target = act["at"]
			var d: Vector2 = target - a.pos
			if d.length_squared() > 0.0001:
				a.facing = d.normalized()
			return true
		"pose":
			m["pose_t"] = float(m["pose_t"]) + delta
			if float(m["pose_t"]) < float(m["pose_len"]):
				return false
			m["pose"] = ""
			return true
		"fx":
			_spawn_fx(str(act["name"]), m)
			return true
		"hop":
			var from: Vector2 = m["hop_from"]
			var to: Vector2 = act["to"]
			var dur: float = maxf(from.distance_to(to) / SPEED_HOP, 0.3)
			var k: float = clampf(float(act["el"]) / dur, 0.0, 1.0)
			a.pos = from.lerp(to, k)
			if (to - from).length_squared() > 0.0001:
				a.facing = (to - from).normalized()
			var p3: Vector3 = Vector3(a.pos.x, absf(sin(k * PI * 3.0)) * 0.05, a.pos.y)
			m["pos3"] = p3
			return k >= 1.0
		"fly":
			var pts: Array = act["points"]
			var i: int = int(act["i"])
			var p: Vector3 = m["pos3"]
			var budget: float = SPEED_FLY * delta
			while budget > 0.0 and i < pts.size():
				var target3: Vector3 = pts[i]
				var to3: Vector3 = target3 - p
				var dist: float = to3.length()
				if dist <= budget:
					p = target3
					budget -= dist
					i += 1
				else:
					p += to3 / dist * budget
					budget = 0.0
				if Vector2(to3.x, to3.z).length_squared() > 0.000001:
					a.facing = Vector2(to3.x, to3.z).normalized()
			act["i"] = i
			m["pos3"] = p
			a.pos = Vector2(p.x, p.z)
			return i >= pts.size()
	return true


## Arah hadap ke kamera di bidang lantai, diputar `turn` radian: penampil
## (Pak Lurah, maskot, pengamen) tampil menghadap pemain.
func _toward_camera(turn: float) -> Vector2:
	var z: Vector3 = view.camera_rig.camera.global_basis.z
	var d := Vector2(z.x, z.z)
	if d.length_squared() < 0.0001:
		return Vector2(0.0, 1.0)
	return d.normalized().rotated(turn)


func _straight(a: SimActor, target: Vector2) -> void:
	a.route = [{"floor": a.floor_id, "pos": target, "portal": false}]
	a.moving = true


func _mood_for_pose(m: Dictionary, pose: String) -> void:
	if m["type"] != "person":
		return
	var model: Node3D = (m["node"] as ActorView).model
	match pose:
		"wave", "strum", "photo":
			CharacterFactory.set_expression(model, "senang")
		"bow":
			CharacterFactory.set_expression(model, "lega")


# ===========================================================================
# TAMPILAN
# ===========================================================================

func _animate(m: Dictionary, delta: float) -> void:
	var node: Node3D = m["node"]
	if node == null or not is_instance_valid(node):
		return
	var a: SimActor = m["actor"]
	if not bool(m["leaving"]):
		m["pop"] = minf(1.0, float(m["pop"]) + delta / POP_SECONDS)
	var pop: float = float(m["pop"])
	var target_w: float = 1.0 if str(m["pose"]) != "" else 0.0
	m["pose_w"] = move_toward(float(m["pose_w"]), target_w, delta * POSE_RATE)
	var w: float = float(m["pose_w"])
	var pose: String = str(m["pose"]) if str(m["pose"]) != "" else str(m["pose_last"])
	var k: float = clampf(float(m["pose_t"]) / maxf(float(m["pose_len"]), 0.01), 0.0, 1.0)
	match str(m["type"]):
		"person":
			var v: ActorView = node as ActorView
			v.scale = Vector3.ONE * maxf(_ease_pop(pop), 0.001)
			v.sync(a, delta, true)
			if w > 0.0:
				match pose:
					"wave":
						ProceduralAnimationSystem.wave(v.model, w, _t)
					"bow":
						ProceduralAnimationSystem.bow(v.model, k)
					"strum":
						ProceduralAnimationSystem.strum(v.model, w, _t)
					"photo":
						ProceduralAnimationSystem.photo(v.model, w)
			elif str(m["pose_last"]) != "":
				ProceduralAnimationSystem.end_pose(v.model)
				m["pose_last"] = ""
			if m.has("prop"):
				_place_ukulele(v, m["prop"])
			if pose == "strum" and w > 0.5:
				m["fx_timer"] = float(m["fx_timer"]) - delta
				if float(m["fx_timer"]) <= 0.0:
					m["fx_timer"] = 0.55
					_spawn_fx("note", m)
		"cat", "mascot":
			_ground_pose(node, a, delta)
			node.scale = Vector3.ONE * maxf(_ease_pop(pop) * float(m["base_scale"]), 0.001)
			if a.moving:
				m["phase"] = float(m["phase"]) + delta * TAU * (2.4 if m["type"] == "cat" else 1.6)
				if m["type"] == "cat":
					CritterFactory.cat_walk(node, float(m["phase"]), 1.0, _t)
				else:
					CritterFactory.mascot_walk(node, float(m["phase"]), 1.0)
			elif m["type"] == "cat":
				_cat_weights(m, pose if str(m["pose"]) != "" else "", delta)
				CritterFactory.cat_pose(node, float(m["sit_w"]), float(m["lick_w"]), float(m["sniff_w"]), _t)
			else:
				CritterFactory.mascot_pose(node, w if pose == "dance" else 0.0, w if pose == "wave" else 0.0, _t)
		"sparrow":
			var p3: Vector3 = m["pos3"] if (m["pos3"] as Vector3) != Vector3.INF else Vector3(a.pos.x, 0.0, a.pos.y)
			node.position = p3
			_turn(node, a, delta)
			node.scale = Vector3.ONE * maxf(_ease_pop(pop) * float(m["base_scale"]), 0.001)
			var flying: bool = str((m["act"] as Dictionary).get("do", "")) == "fly" or p3.y > 0.01
			CritterFactory.sparrow_pose(node, w if pose == "peck" and _pulse(_t) else 0.0, 1.0 if flying else 0.0,
				w if pose == "look" else 0.0, _t)
		"butterfly":
			var p4: Vector3 = m["pos3"]
			node.position = p4 + Vector3(0.0, sin(_t * 5.0) * 0.02, 0.0)
			_turn(node, a, delta)
			node.scale = Vector3.ONE * maxf(_ease_pop(pop) * float(m["base_scale"]), 0.001)
			CritterFactory.butterfly_flap(node, _t, 0.25 if pose == "perch" and w > 0.5 else 1.0)


static func _ease_pop(p: float) -> float:
	return 1.0 - pow(1.0 - clampf(p, 0.0, 1.0), 3.0)


## Patukan berulang: true pada setengah pertama tiap siklus 0,4 detik.
static func _pulse(t: float) -> bool:
	return fposmod(t, 0.4) < 0.2


func _ground_pose(node: Node3D, a: SimActor, delta: float) -> void:
	node.position = Vector3(a.pos.x, node.position.y, a.pos.y)
	_turn(node, a, delta)


func _turn(node: Node3D, a: SimActor, delta: float) -> void:
	if a.facing.length_squared() > 0.0001:
		node.rotation.y = lerp_angle(node.rotation.y, atan2(-a.facing.x, -a.facing.y), minf(1.0, 10.0 * delta))


func _cat_weights(m: Dictionary, pose: String, delta: float) -> void:
	for key: String in ["sit_w", "lick_w", "sniff_w"]:
		if not m.has(key):
			m[key] = 0.0
	var sit: float = 1.0 if pose in ["sit", "lick"] else 0.0
	var lick: float = 1.0 if pose == "lick" else 0.0
	var sniff: float = 1.0 if pose == "sniff" else 0.0
	m["sit_w"] = move_toward(float(m["sit_w"]), sit, delta * 3.0)
	m["lick_w"] = move_toward(float(m["lick_w"]), lick, delta * 3.0)
	m["sniff_w"] = move_toward(float(m["sniff_w"]), sniff, delta * 3.0)


## Ukulele dipegang miring di depan dada pengamen.
func _place_ukulele(v: ActorView, uke: Node3D) -> void:
	if v.model == null or not is_instance_valid(uke):
		return
	var s: float = v.model.scale.y
	var fwd: Vector3 = (v.global_basis * Vector3(0.0, 0.0, -1.0)).normalized()
	var chest: Vector3 = v.global_position + Vector3(0.0, v.model.position.y + 0.40 * s, 0.0) + fwd * 0.13 * s
	var b: Basis = Basis(Vector3.UP, v.global_rotation.y) * Basis(Vector3(0.0, 0.0, 1.0), -1.0)
	uke.global_transform = Transform3D(b.scaled(v.model.scale), chest)


func _apply_visibility() -> void:
	_shown = not view.decoration_mode and view.camera_rig.active_floor == sim.world.store_floor()
	for m: Dictionary in _cast:
		var node: Node3D = m.get("node")
		if node != null and is_instance_valid(node):
			node.visible = _shown
	for f: Node3D in _fx:
		if is_instance_valid(f):
			f.visible = _shown


## Gelembung kalimat di atas kepala pemeran yang sedang bicara; `delta` 0 saat
## game di-pause (gelembung tetap tampil).
func _place_bubbles(delta: float) -> void:
	for m: Dictionary in _cast:
		if bool(m["gone"]):
			continue
		var b: ThoughtBubble = m.get("bubble")
		if float(m["say_left"]) > 0.0:
			m["say_left"] = float(m["say_left"]) - delta
		if float(m["say_left"]) <= 0.0 or not _shown:
			if b != null and is_instance_valid(b):
				b.hide_bubble()
			continue
		if b == null or not is_instance_valid(b):
			b = ThoughtBubble.new()
			b.name = "SurpriseLine"
			view._thought_layer.add_child(b)
			m["bubble"] = b
		b.show_key(str(m["say_key"]))
		b.point_at(view.camera_rig.world_to_screen(_anchor(m) + Vector3(0.0, WorldView.THOUGHT_ANCHOR_GAP, 0.0)))


func _anchor(m: Dictionary) -> Vector3:
	var node: Node3D = m["node"]
	if m["type"] == "person":
		return (node as ActorView).head_anchor()
	var top: float = {"cat": 0.42, "mascot": 1.0, "sparrow": 0.22, "butterfly": 0.16}.get(str(m["type"]), 0.3)
	return node.global_position + Vector3(0.0, top, 0.0)


# ===========================================================================
# EFEK KECIL
# ===========================================================================

func _spawn_fx(kind: String, m: Dictionary) -> void:
	var node: Node3D = m["node"]
	var at: Vector3 = node.global_position if node != null and is_instance_valid(node) else Vector3.ZERO
	match kind:
		"heart":
			_add_fx(CritterFactory.heart(), at + Vector3(0.06, 0.36, 0.0), "rise", 1.6, 1.6)
		"note":
			var n: MeshInstance3D = CharacterFactory.music_note(int(_t * 10.0))
			_add_fx(n, (m["node"] as ActorView).head_anchor() + Vector3(0.12 * (1.0 if int(_t * 2.0) % 2 == 0 else -1.0), 0.0, 0.0), "rise", 1.6, 1.5)
		"crumbs":
			for i in 5:
				var off := Vector3(cos(float(i) * 2.5) * (0.05 + 0.02 * float(i % 2)), 0.012, sin(float(i) * 2.5) * (0.05 + 0.02 * float(i % 2)))
				_add_fx(CritterFactory.crumb(), Vector3(at.x + off.x, off.y, at.z + off.z), "stay", 3.4, 1.2)
		"flash":
			var cam_at: Vector3 = (m["node"] as ActorView).head_anchor() + (node.global_basis * Vector3(0.0, -0.08, -0.12))
			_add_fx(CharacterFactory.puff(), cam_at, "flash", 0.35, 6.0)
			FX.sugar_sparkle(self, cam_at)


func _add_fx(node: Node3D, at: Vector3, motion: String, life: float, size: float) -> void:
	add_child(node)
	node.global_position = at
	node.set_meta("origin", at)
	node.set_meta("age", 0.0)
	node.set_meta("life", life)
	node.set_meta("motion", motion)
	node.set_meta("size", size)
	node.scale = Vector3.ONE * 0.001
	node.visible = _shown
	_fx.append(node)


func _step_fx(delta: float) -> void:
	for i in range(_fx.size() - 1, -1, -1):
		var f: Node3D = _fx[i]
		if not is_instance_valid(f):
			_fx.remove_at(i)
			continue
		var age: float = float(f.get_meta("age")) + delta
		f.set_meta("age", age)
		var k: float = age / float(f.get_meta("life"))
		if k >= 1.0:
			f.queue_free()
			_fx.remove_at(i)
			continue
		var origin: Vector3 = f.get_meta("origin")
		var size: float = float(f.get_meta("size"))
		match str(f.get_meta("motion")):
			"rise":
				f.global_position = origin + Vector3(0.025 * sin(k * 9.0), 0.28 * k, 0.0)
				f.scale = Vector3.ONE * maxf(sin(PI * minf(k * 1.3, 1.0)) * size, 0.001)
			"stay":
				f.scale = Vector3.ONE * maxf((1.0 if k < 0.8 else (1.0 - k) / 0.2) * size, 0.001)
			"flash":
				f.scale = Vector3.ONE * maxf(sin(PI * k) * size, 0.001)


# ===========================================================================
# TEMPAT
# ===========================================================================

func _fg() -> FloorGrid:
	return sim.world.grid(sim.world.store_floor())


## Arah keluar dari pintu (ubin di luar lantai toko).
func _outward() -> Vector2i:
	var door: Vector2i = sim.world.entrance_cell()
	var size: Vector2i = _fg().size
	if door.y == 0:
		return Vector2i(0, -1)
	if door.x == 0:
		return Vector2i(-1, 0)
	if door.y == size.y - 1:
		return Vector2i(0, 1)
	return Vector2i(1, 0)


func _outside_pos() -> Vector2:
	return GridMath.cell_center(sim.world.entrance_cell() + _outward())


## Ubin publik sejauh `n` ubin ke dalam dari pintu.
func _near_door(n: int) -> Vector2i:
	return sim.world.nearest_walkable(sim.world.store_floor(), sim.world.entrance_cell() - _outward() * n, NAV)


## Ubin publik terdekat dari tengah area toko.
func _center_cell() -> Vector2i:
	var fg: FloorGrid = _fg()
	var sum := Vector2.ZERO
	var n: int = 0
	for z in fg.size.y:
		for x in fg.size.x:
			var c := Vector2i(x, z)
			if fg.is_store(c) and fg.is_public_walkable(c):
				sum += Vector2(c)
				n += 1
	var mid: Vector2i = Vector2i((sum / float(maxi(n, 1))).round()) if n > 0 else sim.world.entrance_cell()
	return sim.world.nearest_walkable(sim.world.store_floor(), mid, NAV)


## Ubin di depan meja kasir jalur utama (arah pandang menyapa toko).
func _counter_cell() -> Vector2i:
	var lane: QueueLane = sim.queue.main_lane()
	return lane.service_point if lane != null else _center_cell()


## Rak display acak di lantai toko: {iid, cell (ubin aksesnya), center (tengah
## jejaknya, meter), height}. Tanpa rak: tengah toko.
func _display_spot() -> Dictionary:
	var shelves: Array[EquipmentInstance] = []
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		if e.floor_id == sim.world.store_floor() and not sim.world.access_of(e.iid).is_empty():
			shelves.append(e)
	if shelves.is_empty():
		var cc: Vector2i = _center_cell()
		return {"iid": -1, "cell": cc, "center": GridMath.cell_center(cc), "height": 0.8, "cells": [cc]}
	var pick: EquipmentInstance = shelves[_rng.randi_range(0, shelves.size() - 1)]
	var cells: Array[Vector2i] = pick.footprint_cells()
	var center := Vector2.ZERO
	for c: Vector2i in cells:
		center += GridMath.cell_center(c)
	center /= float(cells.size())
	return {"iid": pick.iid, "cell": sim.world.access_of(pick.iid)["cell"], "center": center,
		"height": pick.def().height_m, "cells": cells}


## Ubin publik yang mengelilingi rak, urut melingkar mulai dari ubin aksesnya
## (paling banyak 4), untuk berlari mengitari rak.
func _ring(spot: Dictionary) -> Array[Vector2i]:
	var fg: FloorGrid = _fg()
	var foot: Array = spot["cells"]
	var center: Vector2 = spot["center"]
	var around: Array[Vector2i] = []
	for c: Variant in foot:
		for dz in range(-1, 2):
			for dx in range(-1, 2):
				var n := Vector2i(c) + Vector2i(dx, dz)
				if not foot.has(n) and not around.has(n) and fg.in_bounds(n) and fg.is_public_walkable(n):
					around.append(n)
	var start: Vector2i = spot["cell"]
	if not around.has(start):
		around.append(start)
	var a0: float = (GridMath.cell_center(start) - center).angle()
	around.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		var ap: float = fposmod((GridMath.cell_center(p) - center).angle() - a0, TAU)
		var aq: float = fposmod((GridMath.cell_center(q) - center).angle() - a0, TAU)
		if not is_equal_approx(ap, aq):
			return ap < aq
		return p.x * 1000 + p.y < q.x * 1000 + q.y)
	var out: Array[Vector2i] = []
	var step: int = maxi(1, around.size() / 4)
	for i in range(0, around.size(), step):
		if out.size() < 4:
			out.append(around[i])
	if out.is_empty():
		out.append(start)
	return out


## Ubin tempat turis memotret rak: 2,5-4 ubin dari tengah rak, yang paling
## membuat mereka menghadap kamera saat memandang rak (wajah dan kameranya
## terlihat pemain). Tanpa ubin cocok: tengah toko.
func _photo_spot(spot: Dictionary) -> Vector2i:
	var fg: FloorGrid = _fg()
	var center: Vector2 = spot["center"]
	var to_cam: Vector2 = _toward_camera(0.0)
	var best: Vector2i = _center_cell()
	var best_score: float = -INF
	for z in fg.size.y:
		for x in fg.size.x:
			var c := Vector2i(x, z)
			if not (fg.is_store(c) and fg.is_public_walkable(c)):
				continue
			var d: Vector2 = center - GridMath.cell_center(c)
			var tiles: float = d.length() * GridMath.TILES_PER_METER
			if tiles < 2.5 or tiles > 4.0:
				continue
			var score: float = d.normalized().dot(to_cam) - 0.04 * tiles
			if score > best_score:
				best_score = score
				best = c
	return best


## Ubin publik di samping `cell` (tegak lurus arah pandang kamera), supaya dua
## pemeran berdiri berdampingan tanpa saling menutupi.
func _beside(cell: Vector2i) -> Vector2i:
	var fg: FloorGrid = _fg()
	var to_cam: Vector2 = _toward_camera(0.0)
	var dirs: Array[Vector2i] = []
	for dz in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dz != 0:
				dirs.append(Vector2i(dx, dz))
	dirs.sort_custom(func(p: Vector2i, q: Vector2i) -> bool:
		var sp: float = absf(Vector2(p).normalized().dot(to_cam))
		var sq: float = absf(Vector2(q).normalized().dot(to_cam))
		if not is_equal_approx(sp, sq):
			return sp < sq
		return p.x * 10 + p.y < q.x * 10 + q.y)
	for d: Vector2i in dirs:
		var n: Vector2i = cell + d
		if fg.in_bounds(n) and fg.is_store(n) and fg.is_public_walkable(n):
			return n
	return cell


## Ubin publik tetangga `cell` yang belum dipakai pemeran lain (`avoid`).
func _neighbor(cell: Vector2i, avoid: Array) -> Vector2i:
	var fg: FloorGrid = _fg()
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(-1, 1)]:
		var n: Vector2i = cell + d
		if fg.in_bounds(n) and fg.is_public_walkable(n) and not avoid.has(n):
			return n
	return cell
