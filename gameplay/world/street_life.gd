class_name StreetLife
extends Node3D
## Lalu-lalang kosmetik di luar toko (keputusan maintainer 2026-10-09, GDD 32.7):
## motor, ojol, sepeda, gerobak bakso, angkot, mobil, bus, becak, dan mobil antik
## melintas di jalan sesuai tier lokasinya, dan orang berjalan kaki di depan toko.
##
## Murni tontonan, seperti kejutan (GDD 31.9): kendaraan adalah mesh sementara
## (TrafficFactory) dan pejalan kaki ActorView yang tidak didaftarkan ke
## simulasi, jadwalnya dari RandomNumberGenerator sendiri yang diturunkan dari
## master seed dan hari, dan tidak ada yang disimpan. Simulasi tidak tahu mereka
## ada. Gerak memakai detik nyata (kecepatan 2x/3x tidak mempercepatnya) dan
## berhenti saat game di-pause.
##
## Kendaraan menjadi anak node lingkungan, jadi ikut turun satu lantai saat
## kamera di dapur atas (GDD 32.5). Pejalan kaki hanya tampil di lantai toko.
## Kendaraan di kejauhan memudar ke warna latar seperti jalannya (FADE_LEVELS).

## Tingkat pudar kendaraan. Di layar, bahkan pada zoom terjauh, jalan tidak
## pernah lebih pudar dari ~0,45; sesudahnya kendaraan sudah di luar layar.
const FADE_LEVELS: Array[float] = [0.0, 0.15, 0.3, 0.45]
## Paling banyak satu mesh kendaraan dirakit per frame (menghindari tersendat).
const BUILDS_PER_FRAME: int = 1
const WALKER_POOL: int = 4
const MAX_WALKERS: int = 3
## Kecepatan nyata pejalan kaki (m/s).
const WALK_SPEED: Vector2 = Vector2(1.5, 1.9)
## Lama muncul/menghilang (skala) di ujung lajur yang tampak di layar.
const POP_SECONDS: float = 0.3
## Jarak aman minimal di antara dua kendaraan selajur (m).
const SAFE_GAP: float = 1.6
## Roda dua menyalip kendaraan yang kecepatannya di bawah rasio ini, dengan
## bergeser sejauh PASS_OFFSET ke arah tengah jalan.
const PASS_RATIO: float = 0.6
const PASS_OFFSET: float = 0.75
## Jenis beroda dua yang boleh bergeser ke samping di lajurnya.
const TWO_WHEELS: Array[StringName] = [&"motor", &"motor_pair", &"ojol", &"bicycle", &"onthel"]
## Pejalan kaki saat hujan (GDD 32.8) berjas hujan cerah, dan berpayung bila
## jalurnya cukup jauh dari muka toko sehingga payungnya tidak menutupi lantai
## (syarat: z jalur + 0,18 + `umbrella_lift` < 0).
const RAINCOATS: Array[Color] = [Palette.RAINCOAT_YELLOW, Palette.SIGN_BLUE, Palette.PASTEL_MINT, Palette.STRAWBERRY]
const UMBRELLA_R: float = 0.42
const UMBRELLA_RISE: float = 0.1
## Tinggi kepala pejalan kaki tertinggi yang dipakai menghitung batas payung.
const WALKER_HEAD_MAX: float = 1.3
## Riak tetes hujan di genangan (GDD 32.8): cincin yang melebar lalu memudar.
const RIPPLES_PER_PUDDLE: int = 2
const RIPPLE_SECONDS: float = 0.9
const RIPPLE_RADIUS: float = 0.26
const RIPPLE_ALPHA: Array[float] = [0.5, 0.3, 0.12]

var sim: SimulationRoot = null
var view: WorldView = null
## Kendaraan aktif per lajur: [{def, next, cars: [{kind, x, z, speed, want, len, ...}]}].
var lanes: Array[Dictionary] = []
## Pejalan kaki aktif: [{member, x, z, dir, speed, x_end}].
var walkers: Array[Dictionary] = []
var _walk_defs: Array = []
var _walk_next: Array[float] = []
var _looks: Array = []
var _pool: Array[Dictionary] = []
var _root: Node3D = null
var _tier: int = 0
var _center: Vector3 = Vector3.ZERO
var _fade: Vector2 = Vector2(11.0, 28.0)
var _rain: bool = false
var _day: int = -1
var _rng := RandomNumberGenerator.new()
var _cache: Dictionary = {}
var _builds_left: int = 0
var _t: float = 0.0
var _store_view: bool = true
## Riak aktif: [{node, puddle: Vector4, t, level}].
var ripples: Array[Dictionary] = []
var _ripple_meshes: Array[Mesh] = []
## Jam in-game terakhir yang dilihat lonceng menara jam Tier 5 (-1 = belum).
var _hour: int = -1
## Berapa kali lonceng berbunyi (untuk tes).
var chimes: int = 0


func setup(s: SimulationRoot, wv: WorldView) -> void:
	sim = s
	view = wv
	name = "StreetLife"


## Lingkungan baru (lokasi berganti atau dibangun ulang): lajur, kendaraan, dan
## pejalan kaki dimulai lagi dari kosong.
func rebuild(neighborhood: Node3D) -> void:
	clear()
	_cache.clear()
	_tier = sim.world.location.tier if sim != null else 0
	if neighborhood == null or not NeighborhoodFactory.has_street(_tier):
		return
	var store: FloorDefinition = null
	for fd: FloorDefinition in sim.world.location.floors:
		if fd.id == sim.world.location.store_floor():
			store = fd
	if store == null:
		return
	var w: float = float(store.size.x) * NeighborhoodFactory.T
	var d: float = float(store.size.y) * NeighborhoodFactory.T
	_center = Vector3(w * 0.5, 0.0, d * 0.5)
	_fade = NeighborhoodFactory.fade_radii(w, d)
	_root = Node3D.new()
	_root.name = "Traffic"
	neighborhood.add_child(_root)
	_hour = -1
	_rain = sim.weather.is_rain()
	var plan: Dictionary = NeighborhoodFactory.traffic(_tier)
	for ld: Variant in plan["lanes"]:
		lanes.append({"def": ld, "next": 0.0, "cars": []})
	_walk_defs = plan["walks"]
	_walk_next.clear()
	for i in _walk_defs.size():
		_walk_next.append(0.0)
	_looks = plan["looks"]
	_reseed()
	_build_pool()
	if bool(neighborhood.get_meta("wet", false)):
		_build_ripples(neighborhood.get_meta("puddles", []))


## Hapus semua kendaraan dan pejalan kaki (juga dipakai tes).
func clear() -> void:
	for lane: Dictionary in lanes:
		for car: Dictionary in lane["cars"]:
			_free_node(car.get("node"))
	lanes.clear()
	for rp: Dictionary in ripples:
		_free_node(rp.get("node"))
	ripples.clear()
	for wk: Dictionary in walkers:
		_release(wk)
	walkers.clear()
	for m: Dictionary in _pool:
		_free_node(m.get("view"))
	_pool.clear()
	if _root != null and is_instance_valid(_root):
		_root.queue_free()
	_root = null


func _free_node(n: Variant) -> void:
	if n != null and is_instance_valid(n):
		(n as Node).queue_free()


## Pejalan kaki hanya tampil saat kamera di lantai toko.
func set_store_view(on: bool) -> void:
	_store_view = on
	for m: Dictionary in _pool:
		var v: ActorView = m["view"]
		if is_instance_valid(v):
			v.visible = on and bool(m["busy"])


## Jadwal acak baru tiap hari, dari master seed (tanpa menyentuh stream RNG simulasi).
func _reseed() -> void:
	_day = sim.time.day
	_rng.seed = hash("%d|%d|street|%d" % [sim.rng.master_seed, sim.time.day, _tier])
	for lane: Dictionary in lanes:
		var gap: Vector2 = lane["def"]["gap"]
		lane["next"] = _rng.randf_range(0.0, gap.x)
	for i in _walk_next.size():
		_walk_next[i] = _rng.randf_range(0.0, 3.0)


## Kepadatan hiasan dari preset kualitas (GDD 109.2: hanya tampilan yang boleh
## berubah per preset): Low 0,5, Medium 0,8 (juga Auto), High 1,0.
static func density() -> float:
	var want: String = str(SettingsManager.get_value("quality"))
	if want == "auto" or want == "":
		want = String(DataRegistry.quality_auto_default())
	for q: Variant in DataRegistry.quality_presets():
		var qd: MiscDefinitions.QualityPresetDefinition = q
		if String(qd.id) == want:
			return clampf(qd.decor_density, 0.2, 1.0)
	return 0.8


## Paling banyak pejalan kaki sekaligus menurut kepadatan hiasan: Low 1,
## Medium 2, High 3.
static func max_walkers() -> int:
	return clampi(int(floor(float(MAX_WALKERS) * density() + 0.001)), 1, MAX_WALKERS)


## Ramai-sepinya jalan menurut jam: sepi saat fajar dan after-hours, ramai pada
## jam berangkat dan pulang kerja. Preset kualitas rendah menjarangkannya.
func activity() -> float:
	return _hour_activity() * density()


func _hour_activity() -> float:
	if sim.time.is_after_hours():
		return 0.4
	var h: float = sim.time.time_seconds / 3600.0
	if h < 6.0:
		return 0.35
	if h < 7.0:
		return 0.7
	if h < 9.0:
		return 1.25
	if h < 16.0:
		return 1.0
	return 1.2


func update(delta: float) -> void:
	if sim == null or _root == null or not is_instance_valid(_root):
		return
	if _day != sim.time.day:
		_reseed()
	if sim.weather.is_rain() != _rain:
		_rain = sim.weather.is_rain()
		_restyle()
	if PauseManager.is_paused() or delta <= 0.0:
		return
	_t += delta
	_builds_left = BUILDS_PER_FRAME
	_chime()
	var act: float = activity()
	for lane: Dictionary in lanes:
		_step_lane(lane, delta, act)
	_step_walkers(delta, act)
	_step_ripples(delta)


## Menara jam alun-alun Tier 5 berdentang setiap jam in-game berganti, selama
## persiapan dan jam buka, saat kamera di lantai toko (GDD 32.9).
func _chime() -> void:
	if _tier != 5:
		return
	var h: int = int(sim.time.time_seconds / 3600.0)
	if _hour < 0:
		_hour = h
		return
	if h == _hour:
		return
	_hour = h
	if _store_view and sim.time.is_running_phase():
		chimes += 1
		AudioManager.play(&"clock_tower_chime")


# ===========================================================================
# KENDARAAN
# ===========================================================================

func _step_lane(lane: Dictionary, delta: float, act: float) -> void:
	var def: Dictionary = lane["def"]
	var dir: float = float(def["dir"])
	var cars: Array = lane["cars"]
	lane["next"] = float(lane["next"]) - delta * act
	if float(lane["next"]) <= 0.0 and _spawn_car(lane):
		var gap: Vector2 = def["gap"]
		lane["next"] = _rng.randf_range(gap.x, gap.y)
	var end_x: float = float(def["x0"]) if dir < 0.0 else float(def["x1"])
	# Urut dari yang paling depan, supaya yang baru menyalip dihitung di depan.
	cars.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["x"]) * dir > float(b["x"]) * dir)
	var i: int = 0
	while i < cars.size():
		var car: Dictionary = cars[i]
		var want: float = float(car["want"])
		var passing: bool = false
		if i > 0:
			var ahead: Dictionary = cars[i - 1]
			var gap_m: float = absf(float(ahead["x"]) - float(car["x"])) - (float(ahead["len"]) + float(car["len"])) * 0.5
			if gap_m < SAFE_GAP * 2.0:
				# Roda dua menyalip yang jauh lebih lambat (gerobak, sepeda, becak)
				# dengan bergeser ke tengah jalan; selain itu melambat di belakangnya.
				if TWO_WHEELS.has(car["kind"]) and float(ahead["want"]) < want * PASS_RATIO:
					passing = true
				else:
					want = minf(want, float(ahead["speed"]) * (0.8 if gap_m < SAFE_GAP else 1.0))
		if passing:
			car["pass_until"] = float(cars[i - 1]["x"]) + dir * (float(cars[i - 1]["len"]) + float(car["len"]) + 1.0)
		var offset_want: float = 0.0
		if car.has("pass_until") and float(car["x"]) * dir < float(car["pass_until"]) * dir:
			# Lalu lintas lajur kiri: tengah jalan ada di -z untuk arah -x, di +z untuk +x.
			offset_want = dir * PASS_OFFSET
		else:
			car.erase("pass_until")
		car["offset"] = move_toward(float(car.get("offset", 0.0)), offset_want, delta * 1.6)
		car["speed"] = move_toward(float(car["speed"]), want, delta * 3.0)
		car["x"] = float(car["x"]) + dir * float(car["speed"]) * delta
		car["age"] = float(car["age"]) + delta
		var done: bool = float(car["x"]) * dir >= end_x * dir
		_place_car(car, done, delta)
		if done and float(car["pop_out"]) >= POP_SECONDS:
			_free_node(car["node"])
			cars.remove_at(i)
			continue
		i += 1


## Muncul di ujung lajur. false bila ujungnya masih terhalang kendaraan lain atau
## meshnya belum bisa dirakit di frame ini.
func _spawn_car(lane: Dictionary) -> bool:
	var def: Dictionary = lane["def"]
	var dir: float = float(def["dir"])
	var start_x: float = float(def["x1"]) if dir < 0.0 else float(def["x0"])
	var cars: Array = lane["cars"]
	var kind: StringName = _pick(def["kinds"])
	var inf: Dictionary = TrafficFactory.info(kind)
	if not cars.is_empty():
		var last: Dictionary = cars[cars.size() - 1]
		if absf(float(last["x"]) - start_x) < (float(last["len"]) + float(inf["length"])) * 0.5 + SAFE_GAP * 2.0:
			return false
	var variant: int = _rng.randi_range(0, int(inf["variants"]) - 1)
	var z: float = float(def["z"])
	if TWO_WHEELS.has(kind):
		z += _rng.randf_range(-float(def["jitter"]), float(def["jitter"]))
	var level: int = _level_at(start_x, z)
	var mesh: Mesh = _mesh(kind, variant, level, true)
	if mesh == null:
		return false
	var mi := MeshInstance3D.new()
	mi.name = String(kind)
	mi.mesh = mesh
	mi.material_override = MeshBuilder.material(MeshBuilder.MATTE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation.y = -PI * 0.5 if dir > 0.0 else PI * 0.5
	_root.add_child(mi)
	var speed: Vector2 = inf["speed"]
	var v: float = _rng.randf_range(speed.x, speed.y)
	var car: Dictionary = {"kind": kind, "variant": variant, "node": mi, "x": start_x, "z": z, "speed": v, "want": v,
		"len": float(inf["length"]), "bob": float(inf["bob"]), "phase": _rng.randf_range(0.0, TAU), "level": level,
		"age": 0.0, "pop": bool(def.get("pop", false)), "pop_out": 0.0}
	cars.append(car)
	_place_car(car, false, 0.0)
	return true


func _place_car(car: Dictionary, leaving: bool, delta: float) -> void:
	var mi: MeshInstance3D = car["node"]
	if not is_instance_valid(mi):
		return
	var x: float = car["x"]
	var z: float = float(car["z"]) + float(car.get("offset", 0.0))
	var bob: float = float(car["bob"]) * (0.5 + 0.5 * sin(_t * 13.0 + float(car["phase"])))
	mi.position = Vector3(x, NeighborhoodFactory.Y_ROAD + bob, z)
	var s: float = 1.0
	if bool(car["pop"]):
		if leaving:
			car["pop_out"] = float(car["pop_out"]) + delta
			s = clampf(1.0 - float(car["pop_out"]) / POP_SECONDS, 0.001, 1.0)
		else:
			s = clampf(float(car["age"]) / POP_SECONDS, 0.001, 1.0)
	elif leaving:
		car["pop_out"] = POP_SECONDS
	mi.scale = Vector3.ONE * s
	var level: int = _level_at(x, z)
	if level != int(car["level"]):
		var mesh: Mesh = _mesh(car["kind"], int(car["variant"]), level, false)
		if mesh != null:
			mi.mesh = mesh
			car["level"] = level


## Tingkat pudar di titik (x, z): sama dengan pudar jalan di bawahnya.
func _level_at(x: float, z: float) -> int:
	var dist: float = Vector2(x - _center.x, z - _center.z).length()
	var t: float = clampf((dist - _fade.x) / maxf(_fade.y - _fade.x, 0.001), 0.0, 1.0)
	var best: int = 0
	for i in FADE_LEVELS.size():
		if absf(FADE_LEVELS[i] - t) < absf(FADE_LEVELS[best] - t):
			best = i
	return best


## Mesh dari cache; dirakit bila belum ada dan anggaran frame ini masih ada.
## `fallback`: pakai tingkat pudar lain yang sudah jadi bila anggaran habis.
func _mesh(kind: StringName, variant: int, level: int, fallback: bool) -> Mesh:
	var key: String = "%s|%d|%d|%d" % [kind, variant, 1 if _rain else 0, level]
	if _cache.has(key):
		return _cache[key]
	if _builds_left > 0:
		_builds_left -= 1
		var mi: MeshInstance3D = TrafficFactory.build(kind, variant, _rain, FADE_LEVELS[level])
		_cache[key] = mi.mesh
		mi.free()
		return _cache[key]
	if fallback:
		for l in FADE_LEVELS.size():
			var k2: String = "%s|%d|%d|%d" % [kind, variant, 1 if _rain else 0, l]
			if _cache.has(k2):
				return _cache[k2]
	return null


func _pick(weights: Dictionary) -> StringName:
	var total: float = 0.0
	for k: Variant in weights.keys():
		total += float(weights[k])
	var r: float = _rng.randf() * total
	var keys: Array = weights.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return String(a) < String(b))
	for k2: Variant in keys:
		r -= float(weights[k2])
		if r <= 0.0:
			return StringName(str(k2))
	return StringName(str(keys[keys.size() - 1]))


## Cuaca berganti: kendaraan baru memakai jas hujan; yang sedang lewat tetap.
func _restyle() -> void:
	_cache.clear()
	_build_pool()


# ===========================================================================
# RIAK HUJAN
# ===========================================================================

## Cincin riak berbagi tiga mesh (makin pudar saat melebar) dengan material
## SHADOW yang sudah dipakai bayangan karakter.
func _build_ripples(puddles: Array) -> void:
	if _ripple_meshes.is_empty():
		for a: float in RIPPLE_ALPHA:
			var mb := MeshBuilder.new()
			mb.disc(Transform3D.IDENTITY, 1.0, Color(1.0, 1.0, 1.0, 0.0), Color(0.96, 0.98, 1.0, a), 18)
			var mi: MeshInstance3D = mb.commit("Ripple", MeshBuilder.SHADOW)
			_ripple_meshes.append(mi.mesh)
			mi.free()
	for pd: Variant in puddles:
		for k in RIPPLES_PER_PUDDLE:
			var node := MeshInstance3D.new()
			node.name = "Ripple"
			node.mesh = _ripple_meshes[0]
			node.material_override = MeshBuilder.material(MeshBuilder.SHADOW)
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_root.add_child(node)
			var rp: Dictionary = {"node": node, "puddle": pd, "t": _rng.randf_range(0.0, RIPPLE_SECONDS), "level": 0}
			_respot(rp)
			ripples.append(rp)


func _respot(rp: Dictionary) -> void:
	var pd: Vector4 = rp["puddle"]
	var a: float = _rng.randf_range(0.0, TAU)
	var r: float = sqrt(_rng.randf()) * pd.w * 0.6
	(rp["node"] as Node3D).position = Vector3(pd.x + cos(a) * r, pd.y + 0.006, pd.z + sin(a) * r)


func _step_ripples(delta: float) -> void:
	for rp: Dictionary in ripples:
		var node: MeshInstance3D = rp["node"]
		if not is_instance_valid(node):
			continue
		rp["t"] = float(rp["t"]) + delta
		if float(rp["t"]) >= RIPPLE_SECONDS:
			rp["t"] = fposmod(float(rp["t"]), RIPPLE_SECONDS)
			_respot(rp)
		var f: float = float(rp["t"]) / RIPPLE_SECONDS
		node.scale = Vector3.ONE * lerpf(0.04, RIPPLE_RADIUS, f)
		var level: int = mini(RIPPLE_ALPHA.size() - 1, int(f * float(RIPPLE_ALPHA.size())))
		if level != int(rp["level"]):
			rp["level"] = level
			node.mesh = _ripple_meshes[level]


# ===========================================================================
# PEJALAN KAKI
# ===========================================================================

## Kumpulan ActorView yang dipakai bergantian (dirakit sekali per lokasi dan
## cuaca, supaya tidak ada model yang dirakit di tengah permainan).
func _build_pool() -> void:
	for wk: Dictionary in walkers:
		_release(wk)
	walkers.clear()
	for m: Dictionary in _pool:
		_free_node(m.get("view"))
	_pool.clear()
	if _looks.is_empty():
		return
	var umbrellas: bool = _rain and _umbrellas_fit()
	for i in WALKER_POOL:
		var arche: String = String(_looks[i % _looks.size()])
		var a := SimActor.new()
		a.id = StringName("street_walker_%d" % i)
		a.kind = &"street"
		a.floor_id = sim.world.store_floor()
		var v := ActorView.new()
		add_child(v)
		var seed_i: int = 7919 * (i + 1) + _tier * 131
		var spec: Dictionary = CharacterFactory.spec_for_customer(arche, seed_i, false)
		if _rain:
			spec["cloth"] = RAINCOATS[i % RAINCOATS.size()]
			spec["sleeve"] = "long"
		v.bind(a.id, "street|%d|%d|%s" % [_tier, i, "rain" if _rain else "dry"], spec)
		v.set_busy(true)
		v.visible = false
		if umbrellas:
			var u := MeshInstance3D.new()
			u.name = "Umbrella"
			u.mesh = umbrella_mesh(i)
			u.material_override = MeshBuilder.material(MeshBuilder.MATTE)
			u.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			v.add_child(u)
			u.position = Vector3(0.0, minf(v.head_top(), WALKER_HEAD_MAX) + UMBRELLA_RISE, 0.0)
		_pool.append({"view": v, "actor": a, "busy": false})


## Payung muat bila semua jalur pejalan kaki tier ini cukup jauh dari toko.
func _umbrellas_fit() -> bool:
	var k: float = cos(deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))) / tan(deg_to_rad(DataRegistry.balf("camera.pitch_degrees")))
	for wd: Variant in _walk_defs:
		if float((wd as Dictionary)["z"]) + 0.18 + umbrella_lift(k) >= 0.0:
			return false
	return true


## Batas atas (geser layar ke +z) payung yang dipegang pejalan kaki tertinggi:
## titik kubah di sudut theta memberi r sin(theta) + k (puncak + r/2 cos(theta)),
## yang paling besar r sqrt(1 + k^2/4) di atas k x tinggi tepi kubah.
static func umbrella_lift(k: float) -> float:
	var top: float = WALKER_HEAD_MAX + UMBRELLA_RISE
	return k * top + UMBRELLA_R * sqrt(1.0 + 0.25 * k * k) + 0.01


## Payung bergaris dua warna di atas kepala, dengan gagang di bawahnya.
static func umbrella_mesh(variant: int) -> Mesh:
	var pairs: Array = [[Palette.SIGN_RED, Palette.FLOUR_WHITE], [Palette.SIGN_BLUE, Palette.BUTTER_YELLOW],
		[Palette.PASTEL_MINT.darkened(0.15), Palette.FLOUR_WHITE], [Palette.PASTEL_STRAWBERRY, Palette.PASTEL_PERIWINKLE]]
	var pair: Array = pairs[posmod(variant, pairs.size())]
	var a: Color = pair[0]
	var b: Color = pair[1]
	var mb := MeshBuilder.new()
	mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3.ZERO), Vector3(UMBRELLA_R, UMBRELLA_R * 0.5, UMBRELLA_R), a, 16, 4,
		func(u: Vector3) -> Color: return a if int(floor((atan2(u.x, u.z) + PI) / (TAU / 8.0))) % 2 == 0 else b,
		func(_phi: float) -> float: return PI * 0.5)
	mb.cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, -0.22, 0.0)), 0.5, 0.012, 0.012, Palette.CABLE, 6)
	mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, UMBRELLA_R * 0.5, 0.0)), Vector3.ONE * 0.025, Palette.CABLE, 6, 3)
	var mi: MeshInstance3D = mb.commit("Umbrella")
	var mesh: Mesh = mi.mesh
	mi.free()
	return mesh


func _step_walkers(delta: float, act: float) -> void:
	for i in _walk_defs.size():
		_walk_next[i] -= delta * act
		if _walk_next[i] <= 0.0:
			var wd: Dictionary = _walk_defs[i]
			var gap: Vector2 = wd["gap"]
			_walk_next[i] = _rng.randf_range(gap.x, gap.y)
			if walkers.size() < max_walkers():
				_spawn_walker(wd)
	var k: int = 0
	while k < walkers.size():
		var wk: Dictionary = walkers[k]
		var m: Dictionary = wk["member"]
		var a: SimActor = m["actor"]
		wk["x"] = float(wk["x"]) + float(wk["dir"]) * float(wk["speed"]) * delta
		a.pos = Vector2(float(wk["x"]), float(wk["z"]))
		var v: ActorView = m["view"]
		v.sync(a, delta, true)
		if float(wk["x"]) * float(wk["dir"]) >= float(wk["x_end"]) * float(wk["dir"]):
			_release(wk)
			walkers.remove_at(k)
			continue
		k += 1


func _spawn_walker(wd: Dictionary) -> void:
	var free: Array[Dictionary] = []
	for m: Dictionary in _pool:
		if not bool(m["busy"]):
			free.append(m)
	if free.is_empty():
		return
	var m2: Dictionary = free[_rng.randi_range(0, free.size() - 1)]
	var dir: float = 1.0 if _rng.randf() < 0.5 else -1.0
	var x0: float = float(wd["x0"])
	var x1: float = float(wd["x1"])
	var start: float = x0 if dir > 0.0 else x1
	# Jangan muncul menumpuk dengan pejalan kaki lain di ujung yang sama.
	for other: Dictionary in walkers:
		if absf(float(other["x"]) - start) < 1.2 and absf(float(other["z"]) - float(wd["z"])) < 0.5:
			return
	var z: float = float(wd["z"]) + (0.18 if dir > 0.0 else -0.18)
	var a: SimActor = m2["actor"]
	a.pos = Vector2(start, z)
	a.facing = Vector2(dir, 0.0)
	a.moving = true
	m2["busy"] = true
	var v: ActorView = m2["view"]
	v.visible = _store_view
	v.global_position = Vector3(start, 0.0, z)
	v.rotation.y = atan2(-a.facing.x, -a.facing.y)
	walkers.append({"member": m2, "x": start, "z": z, "dir": dir, "speed": _rng.randf_range(WALK_SPEED.x, WALK_SPEED.y),
		"x_end": x1 if dir > 0.0 else x0})


func _release(wk: Dictionary) -> void:
	var m: Dictionary = wk["member"]
	m["busy"] = false
	(m["actor"] as SimActor).moving = false
	var v: Variant = m.get("view")
	if v != null and is_instance_valid(v):
		(v as ActorView).visible = false
