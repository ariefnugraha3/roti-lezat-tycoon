extends TestSuite
## Kendaraan jalan dan pengendaranya (keputusan maintainer 2026-10-09, GDD 32.7):
## pengendara memakai model karakter pembeli, kendaraan berbentuk mainan
## membulat, dan semuanya dirakit bertahap tanpa tersendat.

const HAND := Vector3(0.0, -CharacterFactory.ARM_LENGTH - 0.024, 0.0)
const FOOT := Vector3(0.0, -0.2, -0.02)


func tests() -> Array:
	return [
		{"id": "ACC_32_STREET_RIDERS", "name": "32.7 riders, passengers, becak drivers and gerobak vendors are whole shopper models (CharacterFactory) posed on their vehicle: hands on the handlebar or the cart handles, feet on the footboard or the pedals; each vehicle with its riders is one mesh with the shared matte material, and riders wear raincoats in the rain", "fn": _riders},
		{"id": "ACC_32_STREET_FRAMES", "name": "32.7 bicycles, onthel, becak and gerobak move legs and pedals through four frames with the same mesh layout, and passing ones switch frames as they roll", "fn": _frames},
		{"id": "ACC_32_VEHICLE_MODELS", "name": "32.7 every vehicle body stays within 2,000 triangles without its riders and a parked one within a few hundred; parked cars, vans, scooters, carts, becak and onthel in the neighbourhood use the same models", "fn": _models},
		{"id": "ACC_32_STREET_BAKE_STEPS", "name": "32.7 a vehicle is assembled in small steps (the body, then one rider per step) and each character is built once in capture mode without touching the GPU; StreetLife prepares its tier's vehicles in the background", "fn": _steps},
	]


func _ready_plan(kind: StringName, v: int, rain: bool) -> Dictionary:
	var p: Dictionary = TrafficFactory.plan(kind, v, rain)
	while not TrafficFactory.plan_step(p):
		pass
	return p


## Titik di bagian bernama `part` pada bingkai `f` (koordinat kendaraan).
func _point(r: Dictionary, part: String, f: int, local: Vector3) -> Vector3:
	var names: PackedStringArray = r["names"]
	var i: int = names.find(part)
	if i < 0:
		return Vector3.INF
	var rows: Array = r["xfs"]
	var xf: Variant = (rows[f % rows.size()] as Array)[i]
	return (xf as Transform3D) * local if xf != null else Vector3.INF


func _tris(arrays: Array) -> int:
	return (arrays[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func _world(s: SimulationRoot) -> WorldView:
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	return world


# ===========================================================================
# PENGENDARA
# ===========================================================================

func _riders() -> void:
	var expect: Dictionary = {&"motor": 1, &"motor_pair": 2, &"ojol": 1, &"bicycle": 1, &"onthel": 1, &"gerobak": 1, &"becak": 2}
	for kind: StringName in expect.keys():
		var p: Dictionary = _ready_plan(kind, 0, false)
		var riders: Array = p["riders"]
		eq(riders.size(), int(expect[kind]), "%s carries %d people" % [kind, expect[kind]])
		for r: Dictionary in riders:
			# Model pembeli yang utuh: bagian-bagiannya persis mesh karakter itu.
			MeshBuilder.capture = true
			var model: Node3D = CharacterFactory.build(r["spec"])
			MeshBuilder.capture = false
			var want: int = 0
			for n: Node in model.find_children("*", "MeshInstance3D", true, false):
				if n.has_meta("arrays") and StringName(n.get_meta("finish", MeshBuilder.MATTE)) == MeshBuilder.MATTE:
					want += _tris(n.get_meta("arrays"))
			model.free()
			var got: int = 0
			for part: Array in r["parts"]:
				got += _tris(part)
			eq(got, want, "%s: the %s is a whole shopper model" % [kind, r["pose"]])
		var arr: Array = TrafficFactory.frame_arrays(p, 0)
		check(_tris(arr) > int(p["body_tris"]) + 800 * riders.size(), "%s: the riders are part of the one vehicle mesh" % kind)
		var mi: MeshInstance3D = TrafficFactory.build(kind, 0, false, 0.0)
		eq(mi.material_override, MeshBuilder.material(MeshBuilder.MATTE), "%s uses the shared matte material" % kind)
		eq(mi.mesh.get_surface_count(), 1, "%s is one surface (one draw call)" % kind)
		mi.free()
	for kind2: StringName in [&"car", &"luxury", &"angkot", &"van", &"bus", &"vintage"]:
		eq((TrafficFactory.plan(kind2, 0, false)["jobs"] as Array).size(), 0, "%s needs no rider" % kind2)
	# Tangan di setang skuter, kaki di pijakannya.
	var sc: Dictionary = _ready_plan(&"motor", 1, false)
	var rider: Dictionary = sc["riders"][0]
	for side: String in ["L", "R"]:
		var hand: Vector3 = _point(rider, "Arm%sMesh" % side, 0, HAND)
		var grip := Vector3(0.165 * (-1.0 if side == "L" else 1.0), 0.62, -0.16)
		check(hand.distance_to(grip) < 0.1, "the rider's %s hand holds the handlebar (%s)" % [side, hand])
		var foot: Vector3 = _point(rider, "Leg%sMesh" % side, 0, FOOT)
		check(absf(foot.y - 0.045 - TrafficFactory.SCOOTER_FLOOR) < 0.03 and foot.z > -0.32 and foot.z < -0.06,
			"the rider's %s foot rests on the footboard (%s)" % [side, foot])
	# Pedagang gerobak memegang gagang dorong.
	var cart: Dictionary = _ready_plan(&"gerobak", 0, false)
	var vendor: Dictionary = cart["riders"][0]
	for f in 4:
		for side2: String in ["L", "R"]:
			var hand2: Vector3 = _point(vendor, "Arm%sMesh" % side2, f, HAND)
			var handle := Vector3(0.15 * (-1.0 if side2 == "L" else 1.0), 0.45, 0.72 - 0.17)
			check(hand2.distance_to(handle) < 0.1, "frame %d: the vendor's %s hand holds the cart (%s)" % [f, side2, hand2])
	# Kaki pengayuh di pedal pada setiap bingkai.
	for kind3: StringName in [&"bicycle", &"onthel", &"becak"]:
		var bp: Dictionary = _ready_plan(kind3, 0, false)
		var r3: Dictionary = bp["riders"][0]
		var pd: Dictionary = bp["pedals"][0]
		var bb: Vector3 = (pd["xf"] as Transform3D) * (pd["bb"] as Vector3)
		var worst: float = 0.0
		for f2 in TrafficFactory.frames(kind3):
			var phase: float = TAU * float(f2) / float(TrafficFactory.frames(kind3))
			for i in 2:
				var a: float = phase + PI * float(i)
				var pedal: Vector3 = bb + Vector3(-0.06 if i == 0 else 0.06, TrafficFactory.CRANK * cos(a), -TrafficFactory.CRANK * sin(a))
				var foot2: Vector3 = _point(r3, "LegLMesh" if i == 0 else "LegRMesh", f2, FOOT)
				worst = maxf(worst, foot2.distance_to(pedal))
		check(worst < 0.1, "%s: the rider's feet stay on the pedals (%.3f m at worst)" % [kind3, worst])
	# Hujan: jas hujan untuk pengendara, seragam hujan untuk driver ojol.
	var wet: Dictionary = _ready_plan(&"motor", 0, true)
	check(PackedStringArray(wet["riders"][0]["spec"]["accessory"]).has("jas_hujan"), "a rider wears a raincoat in the rain")
	var ojol: Dictionary = _ready_plan(&"ojol", 0, true)
	check(bool(ojol["riders"][0]["spec"]["rainy"]), "the ojol driver wears the rain uniform")


func _frames() -> void:
	for kind: StringName in [&"bicycle", &"onthel", &"gerobak", &"becak"]:
		eq(TrafficFactory.frames(kind), 4, "%s has four frames" % kind)
		var p: Dictionary = _ready_plan(kind, 0, false)
		var a0: Array = TrafficFactory.frame_arrays(p, 0)
		var a1: Array = TrafficFactory.frame_arrays(p, 1)
		var v0: PackedVector3Array = a0[Mesh.ARRAY_VERTEX]
		var v1: PackedVector3Array = a1[Mesh.ARRAY_VERTEX]
		eq(v1.size(), v0.size(), "%s: every frame has the same mesh layout" % kind)
		var moved: int = 0
		for i in mini(v0.size(), v1.size()):
			if v0[i].distance_to(v1[i]) > 0.005:
				moved += 1
		check(moved > 100, "%s: legs move between frames (%d vertices)" % [kind, moved])
	for kind2: StringName in [&"motor", &"car", &"bus"]:
		eq(TrafficFactory.frames(kind2), 1, "%s needs a single frame" % kind2)
	# Di jalan: bingkai berganti selagi melaju.
	PauseManager.clear_all()
	for tier: int in [1, 5]:
		var sim: SimulationRoot = new_sim(7790 + tier)
		jump_to_tier(sim, tier)
		var world: WorldView = _world(sim)
		await runner.get_tree().process_frame
		var sl: StreetLife = world.street_life
		sim.debug_set_time(10.0 * 3600.0)
		var seen: bool = false
		var changed: bool = false
		var last: Dictionary = {}
		for step in 1500:
			sl.update(0.1)
			for lane: Dictionary in sl.lanes:
				for car: Dictionary in lane["cars"]:
					if int(car["frames"]) <= 1:
						continue
					seen = true
					var id: int = (car["node"] as Node).get_instance_id()
					if last.has(id) and int(last[id]) != int(car["frame"]):
						changed = true
					last[id] = int(car["frame"])
			if changed:
				break
		check(seen, "Tier %d: pedalled or pushed vehicles come by" % tier)
		check(changed, "Tier %d: their legs move as they roll" % tier)
		world.queue_free()
		free_sim(sim)
		await runner.get_tree().process_frame


# ===========================================================================
# MODEL
# ===========================================================================

func _models() -> void:
	for kind: StringName in TrafficFactory.KINDS.keys():
		for v in int(TrafficFactory.info(kind)["variants"]):
			var p: Dictionary = TrafficFactory.plan(kind, v, false)
			check(int(p["body_tris"]) <= 2000, "%s %d: the body stays within 2,000 triangles (%d)" % [kind, v, int(p["body_tris"])])
	var parked: Dictionary = {
		"scooter": [func(mb: MeshBuilder) -> void: TrafficFactory.scooter(mb, Transform3D.IDENTITY, Palette.STRAWBERRY, 0), 350],
		"compact": [func(mb: MeshBuilder) -> void: TrafficFactory.car(mb, Transform3D.IDENTITY, Palette.SIGN_RED, 0, 0), 800],
		"sedan": [func(mb: MeshBuilder) -> void: TrafficFactory.car(mb, Transform3D.IDENTITY, Palette.SIGN_RED, 1, 0), 800],
		"luxury": [func(mb: MeshBuilder) -> void: TrafficFactory.car(mb, Transform3D.IDENTITY, Palette.SIGN_RED, 2, 0), 800],
		"van": [func(mb: MeshBuilder) -> void: TrafficFactory.boxy(mb, Transform3D.IDENTITY, Palette.FLOUR_WHITE, false, 0), 800],
		"cart": [func(mb: MeshBuilder) -> void: TrafficFactory.gerobak(mb, Transform3D.IDENTITY, Palette.SIGN_BLUE, 0), 700],
		"becak": [func(mb: MeshBuilder) -> void: TrafficFactory.becak(mb, Transform3D.IDENTITY, Palette.SIGN_BLUE, 0.0, 0), 900],
		"onthel": [func(mb: MeshBuilder) -> void: TrafficFactory.bicycle(mb, Transform3D.IDENTITY, Palette.ROSY_CHEEK, true, 0.0, 0), 700],
	}
	for key: String in parked.keys():
		var mb := MeshBuilder.new()
		(parked[key][0] as Callable).call(mb)
		check(mb.tri_count() <= int(parked[key][1]), "a parked %s stays within %d triangles (%d)" % [key, parked[key][1], mb.tri_count()])
	# Lingkungan memakai model yang sama untuk kendaraan parkirnya.
	var pairs: Array = [
		[func(mb: MeshBuilder) -> void: NeighborhoodFactory._car(mb, Vector3.ZERO, 0.0, Palette.SIGN_RED, 1), parked["sedan"][0]],
		[func(mb: MeshBuilder) -> void: NeighborhoodFactory._van(mb, Vector3.ZERO, 0.0, Palette.FLOUR_WHITE), parked["van"][0]],
		[func(mb: MeshBuilder) -> void: NeighborhoodFactory._motorbike(mb, Vector3.ZERO, 0.0, Palette.STRAWBERRY), parked["scooter"][0]],
		[func(mb: MeshBuilder) -> void: NeighborhoodFactory._becak(mb, Vector3.ZERO, 0.0, Palette.SIGN_BLUE), parked["becak"][0]],
		[func(mb: MeshBuilder) -> void: NeighborhoodFactory._bicycle(mb, Vector3.ZERO, 0.0, Palette.ROSY_CHEEK), parked["onthel"][0]],
		[func(mb: MeshBuilder) -> void: NeighborhoodFactory._cart(mb, Vector3.ZERO, -PI * 0.5, Palette.SIGN_BLUE), parked["cart"][0]],
	]
	for i in pairs.size():
		var a := MeshBuilder.new()
		var b := MeshBuilder.new()
		(pairs[i][0] as Callable).call(a)
		(pairs[i][1] as Callable).call(b)
		eq(a.vertices(), b.vertices(), "parked vehicle %d in the neighbourhood is the passing model" % i)


func _steps() -> void:
	var p: Dictionary = TrafficFactory.plan(&"motor_pair", 1, false)
	check(not TrafficFactory.plan_ready(p), "the body comes first, the riders later")
	eq((p["jobs"] as Array).size(), 2, "one step per rider")
	check(not TrafficFactory.plan_step(p), "one rider per step")
	eq((p["riders"] as Array).size(), 1, "the first rider is built")
	check(TrafficFactory.plan_step(p), "then the plan is complete")
	check(not MeshBuilder.capture, "capture mode is switched off again")
	MeshBuilder.capture = true
	var model: Node3D = CharacterFactory.build(CharacterFactory.spec_for_customer("customer_generic", 7, false))
	MeshBuilder.capture = false
	var gpu: int = 0
	var parts: int = 0
	for n: Node in model.find_children("*", "MeshInstance3D", true, false):
		if (n as MeshInstance3D).mesh != null:
			gpu += 1
		if n.has_meta("arrays"):
			parts += 1
	model.free()
	eq(gpu, 0, "a captured character makes no GPU mesh")
	check(parts >= 7, "but keeps every part's arrays (%d)" % parts)
	# StreetLife menyiapkan semua kendaraan lajurnya di latar.
	PauseManager.clear_all()
	var sim: SimulationRoot = new_sim(7799)
	var world: WorldView = _world(sim)
	await runner.get_tree().process_frame
	var sl: StreetLife = world.street_life
	check(not sl._warm.is_empty(), "StreetLife queues its tier's vehicles to prepare")
	var updates: int = 0
	while not sl._warm.is_empty() and updates < 600:
		sl.update(0.1)
		updates += 1
	check(sl._warm.is_empty(), "and prepares them all in the background (%d updates)" % updates)
	world.queue_free()
	free_sim(sim)
	await runner.get_tree().process_frame
