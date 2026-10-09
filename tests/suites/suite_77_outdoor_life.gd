extends TestSuite
## Suasana luar toko (keputusan maintainer 2026-10-09, GDD 32.6-32.10): cahaya
## mengikuti jam, lalu-lalang kendaraan dan pejalan kaki, jalan basah dan genangan
## saat hujan, suara jalan per tier dengan lonceng menara jam, dan hiasan hari
## libur. Semuanya murni tampilan: simulasi tidak berubah sedikit pun.

const T: float = GridMath.WORLD_METERS_PER_TILE


func tests() -> Array:
	return [
		{"id": "ACC_32_DAYLIGHT", "name": "32.6 the light follows the clock: a soft dawn, a bright warm-neutral day, the old golden hour at 15:00, a deeper gold and a dusk with the shop lamps up and the street lamps glowing, always warm; rain dims the sun and brightens the lamps; only lights and the background change", "fn": _daylight},
		{"id": "ACC_32_STREET_LIFE", "name": "32.7 vehicles drive along their lanes in their own direction without running into each other (two-wheelers swing out to pass slow carts) and people walk by in front of the shop at every tier; they move in real seconds, stop while paused, hide from the kitchen upstairs (walkers) or drop with the street, and never touch the simulation", "fn": _street_life},
		{"id": "ACC_32_STREET_LIFE_CLEAR", "name": "32.7 nothing that drives or walks past, no lamp glow and no holiday banner can hide the shop floor from the locked camera; every vehicle uses the shared matte material", "fn": _street_clear},
		{"id": "ACC_32_RAIN_STREET", "name": "32.8 on rainy days the street is darker with puddles where raindrops ripple, riders wear raincoats, and the street is rebuilt dry when the rain stops; the wet street stays within the triangle budget", "fn": _rain_street},
		{"id": "ACC_32_HOLIDAY_DECOR", "name": "32.10 on holidays bunting hangs along the top of the shop's back walls (clear of the wall clock) and two umbul-umbul stand beside the shop front; the theme changes with each holiday (red and white, pastel with lanterns, green and yellow with ketupat) and everything goes away after the holiday", "fn": _holiday},
		{"id": "ACC_33_STREET_AMBIENCE", "name": "32.9 each location tier adds its own looping street sound to the ambience, and the Tier 5 clock tower chimes once when an in-game hour turns, never at other tiers", "fn": _ambience},
	]


func _store_floor(loc: LocationDefinition) -> FloorDefinition:
	return loc.floor_def(loc.store_floor())


func _location(tier: int) -> LocationDefinition:
	for loc: LocationDefinition in DataRegistry.locations():
		if loc.tier == tier:
			return loc
	return null


func _world(s: SimulationRoot) -> WorldView:
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	return world


func _warm(c: Color) -> bool:
	return c.r >= c.g - 0.001 and c.g >= c.b - 0.001


## Warna verteks yang dibaca kembali tersimpan 8 bit per kanal.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


# ===========================================================================
# CAHAYA
# ===========================================================================

func _daylight() -> void:
	for h: float in [5.0, 5.5, 6.0, 7.0, 8.0, 10.0, 12.0, 14.0, 15.0, 16.0, 17.0, 17.5, 18.0]:
		for rain: bool in [false, true]:
			var s: Dictionary = Daylight.sample(h * 3600.0, rain)
			check(_warm(s["sun"]) and _warm(s["amb"]), "%05.2f%s: the sun and ambient light stay warm (GDD 130.3)" % [h, " rain" if rain else ""])
			check(float(s["sun_e"]) >= 0.15 and float(s["sun_e"]) <= 1.05, "%05.2f: sun energy in range (%.2f)" % [h, s["sun_e"]])
			check(float(s["amb_e"]) >= 0.4 and float(s["amb_e"]) <= 0.7, "%05.2f: ambient energy in range (%.2f)" % [h, s["amb_e"]])
	var golden: Dictionary = Daylight.sample(15.0 * 3600.0)
	check((golden["sun"] as Color).is_equal_approx(Palette.GOLDEN_HOUR) and is_equal_approx(float(golden["sun_e"]), 0.95)
		and (golden["amb"] as Color).is_equal_approx(Palette.GOLDEN_HOUR) and is_equal_approx(float(golden["amb_e"]), 0.55),
		"at 15:00 the light is the old golden hour")
	check(bool(Daylight.sample(5.25 * 3600.0)["street"]) and bool(Daylight.sample(18.0 * 3600.0)["street"]), "street lamps glow at dawn and dusk")
	check(not bool(Daylight.sample(8.0 * 3600.0)["street"]) and not bool(Daylight.sample(12.0 * 3600.0)["street"]), "street lamps are off by day")
	var noon: Dictionary = Daylight.sample(12.0 * 3600.0)
	var dusk: Dictionary = Daylight.sample(18.0 * 3600.0)
	check(float(noon["sun_e"]) > float(dusk["sun_e"]) and float(noon["lamp_e"]) < float(dusk["lamp_e"]), "the sun is strongest at noon; the shop lamps are brightest at dusk")
	var wet: Dictionary = Daylight.sample(12.0 * 3600.0, true)
	check(float(wet["sun_e"]) < float(noon["sun_e"]) and float(wet["lamp_e"]) > float(noon["lamp_e"]), "rain dims the sun and brightens the lamps")
	# Di dunia: matahari, lampu, ambient, dan pendar lampu jalan mengikuti jam.
	PauseManager.clear_all()
	var sim: SimulationRoot = new_sim(7701)
	var world: WorldView = _world(sim)
	await runner.get_tree().process_frame
	check(not world._suns.is_empty() and not world._lamps.is_empty(), "the world knows its sun and shop lamps")
	sim.debug_set_time(7.0 * 3600.0)
	var before: Dictionary = state_of(sim)
	world.apply_daylight()
	same_state(state_of(sim), before, "changing the light leaves the simulation untouched")
	var sun: DirectionalLight3D = world._suns[0]
	var morning: Color = sun.light_color
	var morning_e: float = sun.light_energy
	var glow: Node3D = world.neighborhood().get_node_or_null("LampGlow") as Node3D
	check(glow != null and glow is MeshInstance3D and (glow as MeshInstance3D).mesh != null, "the street has a lamp glow mesh")
	check(glow != null and not glow.visible, "no lamp glow in the morning")
	check(glow != null and (glow as MeshInstance3D).material_override == MeshBuilder.material(MeshBuilder.SHADOW), "the glow reuses the character shadow material, so no new shader")
	sim.debug_set_time(17.9 * 3600.0)
	world.apply_daylight()
	check(not sun.light_color.is_equal_approx(morning) and sun.light_energy < morning_e, "the evening sun is deeper and lower than the morning sun")
	check(glow != null and glow.visible, "the street lamps glow at dusk")
	check(world._lamps[0].light_energy > 0.7, "the shop lamps are up at dusk (%.2f)" % world._lamps[0].light_energy)
	eq(world._env.environment.ambient_light_color, world.daylight["amb"], "the ambient light follows the clock")
	world.queue_free()
	free_sim(sim)
	await runner.get_tree().process_frame


# ===========================================================================
# LALU-LALANG
# ===========================================================================

func _street_life() -> void:
	PauseManager.clear_all()
	for tier in range(1, 6):
		var sim: SimulationRoot = new_sim(7710 + tier)
		jump_to_tier(sim, tier)
		var world: WorldView = _world(sim)
		await runner.get_tree().process_frame
		var sl: StreetLife = world.street_life
		check(sl.lanes.size() >= 2, "Tier %d has traffic lanes" % tier)
		var plan: Dictionary = NeighborhoodFactory.traffic(tier)
		check(not (plan["walks"] as Array).is_empty() and not (plan["looks"] as Array).is_empty(), "Tier %d has people walking by" % tier)
		var seen_cars: Dictionary = {}
		var seen_walkers: int = 0
		var last_x: Dictionary = {}
		var backwards: int = 0
		var overlaps: int = 0
		var max_walkers: int = 0
		sim.debug_set_time(10.0 * 3600.0)
		var before: Dictionary = state_of(sim)
		for step in 1500:
			sl.update(0.1)
			for lane: Dictionary in sl.lanes:
				var dir: float = float(lane["def"]["dir"])
				var cars: Array = lane["cars"]
				for i in cars.size():
					var car: Dictionary = cars[i]
					var id: int = (car["node"] as Node).get_instance_id()
					seen_cars[id] = true
					if last_x.has(id) and (float(car["x"]) - float(last_x[id])) * dir < -0.0001:
						backwards += 1
					last_x[id] = float(car["x"])
					if i > 0 and absf(float(car.get("offset", 0.0))) < 0.05 and absf(float(cars[i - 1].get("offset", 0.0))) < 0.05:
						var ahead: Dictionary = cars[i - 1]
						var gap: float = absf(float(ahead["x"]) - float(car["x"])) - (float(ahead["len"]) + float(car["len"])) * 0.5
						if gap < -0.05:
							overlaps += 1
			max_walkers = maxi(max_walkers, sl.walkers.size())
			seen_walkers = maxi(seen_walkers, sl.walkers.size())
		check(seen_cars.size() >= 4, "Tier %d: vehicles come by (%d in 150 s)" % [tier, seen_cars.size()])
		check(seen_walkers >= 1, "Tier %d: people walk by" % tier)
		eq(backwards, 0, "Tier %d: vehicles only move in their lane's direction" % tier)
		eq(overlaps, 0, "Tier %d: vehicles in a lane never run into each other" % tier)
		check(max_walkers <= StreetLife.max_walkers(), "Tier %d: at most %d people walk by at once" % [tier, StreetLife.max_walkers()])
		for lane2: Dictionary in sl.lanes:
			for car2: Dictionary in lane2["cars"]:
				check((car2["node"] as MeshInstance3D).material_override == MeshBuilder.material(MeshBuilder.MATTE), "Tier %d: vehicles use the shared matte material" % tier)
				break
		# Pause: tidak ada yang bergerak.
		var xs: Array[float] = []
		for lane3: Dictionary in sl.lanes:
			for car3: Dictionary in lane3["cars"]:
				xs.append(float(car3["x"]))
		PauseManager.push(&"test_street")
		for k in 20:
			sl.update(0.1)
		var xs2: Array[float] = []
		for lane4: Dictionary in sl.lanes:
			for car4: Dictionary in lane4["cars"]:
				xs2.append(float(car4["x"]))
		PauseManager.pop(&"test_street")
		eq(xs2, xs, "Tier %d: traffic stops while the game is paused" % tier)
		same_state(state_of(sim), before, "Tier %d: traffic and walkers never touch the simulation" % tier)
		# Dari dapur di lantai atas: pejalan kaki disembunyikan, jalan turun.
		if sim.world.location.floors.size() > 1:
			for fd: FloorDefinition in sim.world.location.floors:
				if fd.id != sim.world.location.store_floor():
					world.camera_rig.active_floor = fd.id
			world._apply_floor_visibility()
			var shown: int = 0
			for m: Dictionary in sl._pool:
				if (m["view"] as ActorView).visible:
					shown += 1
			eq(shown, 0, "Tier %d: nobody walks by in the kitchen upstairs" % tier)
			near(world.neighborhood().position.y, -NeighborhoodFactory.STOREY, 0.001, "Tier %d: traffic drops one storey with the street" % tier)
		world.queue_free()
		free_sim(sim)
		await runner.get_tree().process_frame
	PauseManager.clear_all()
	# Preset kualitas (GDD 109.2): hanya kepadatan hiasan yang berubah.
	var was: Variant = SettingsManager.get_value("quality")
	var expect: Dictionary = {"quality_low": 1, "quality_medium": 2, "quality_high": 3, "auto": 2}
	for q: String in expect.keys():
		SettingsManager.set_value("quality", q)
		eq(StreetLife.max_walkers(), int(expect[q]), "%s: at most %d people walk by at once" % [q, expect[q]])
	SettingsManager.set_value("quality", "quality_low")
	var low: float = StreetLife.density()
	SettingsManager.set_value("quality", "quality_high")
	check(low < StreetLife.density(), "the low preset thins the traffic out")
	SettingsManager.set_value("quality", was)


## Titik tertinggi (z + geser layar x tinggi) dari semua verteks mesh `m` yang
## diputar `yaw` mengitari Y: bila < 0 di posisi lajur, benda itu tidak pernah
## menutupi lantai toko (lantai berada di z >= 0, geser layar selalu ke +z).
func _lift(arrays: Array, yaw: float, k: float) -> float:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var b := Basis(Vector3.UP, yaw)
	var top: float = -INF
	for p: Vector3 in v:
		var q: Vector3 = b * p
		top = maxf(top, q.z + k * maxf(q.y, 0.0))
	return top


func _street_clear() -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var k: float = cos(yaw) / tan(pitch)
	var cache: Dictionary = {}
	for tier in range(1, 6):
		var loc: LocationDefinition = _location(tier)
		var f: FloorDefinition = _store_floor(loc)
		var w: float = float(f.size.x) * T
		var plan: Dictionary = NeighborhoodFactory.traffic(tier)
		for lane: Variant in plan["lanes"]:
			var ld: Dictionary = lane
			var dir: float = float(ld["dir"])
			var ry: float = -PI * 0.5 if dir > 0.0 else PI * 0.5
			for kind: Variant in (ld["kinds"] as Dictionary).keys():
				var kn := StringName(str(kind))
				var two: bool = StreetLife.TWO_WHEELS.has(kn)
				var worst: float = -INF
				for v in int(TrafficFactory.info(kn)["variants"]):
					for rain: bool in [false, true]:
						var key: String = "%s|%d|%s|%f" % [kn, v, rain, ry]
						if not cache.has(key):
							var mi: MeshInstance3D = TrafficFactory.build(kn, v, rain, 0.0)
							check(mi.material_override == MeshBuilder.material(MeshBuilder.MATTE), "%s uses the shared matte material" % kn)
							cache[key] = _lift(mi.mesh.surface_get_arrays(0), ry, k)
							mi.free()
						worst = maxf(worst, float(cache[key]))
				var z: float = float(ld["z"])
				if two:
					z += float(ld["jitter"]) + maxf(0.0, dir * StreetLife.PASS_OFFSET)
				check(z + worst < 0.0, "Tier %d: a %s at z %.2f never hides the shop floor (reaches %.2f)" % [tier, kn, float(ld["z"]), z + worst])
		# Pejalan kaki: model karakter sungguhan, kering dan berjas hujan.
		for walk: Variant in plan["walks"]:
			var wd: Dictionary = walk
			for look: Variant in plan["looks"]:
				for rain2: bool in [false, true]:
					var model: Node3D = CharacterFactory.build(CharacterFactory.spec_for_customer(String(look), 7919, rain2))
					runner.add_child(model)
					var top: float = -INF
					for mi2: Node in model.find_children("*", "MeshInstance3D", true, false):
						var m3: MeshInstance3D = mi2
						if m3.mesh == null or not m3.is_visible_in_tree():
							continue
						for si in m3.mesh.get_surface_count():
							var v2: PackedVector3Array = m3.mesh.surface_get_arrays(si)[Mesh.ARRAY_VERTEX]
							for p: Vector3 in v2:
								# Pejalan kaki bisa menghadap ke mana saja: ambil jari-jari datar.
								var g: Vector3 = m3.global_transform * p
								top = maxf(top, Vector2(g.x, g.z).length() + k * maxf(g.y, 0.0))
					model.free()
					var z2: float = float(wd["z"]) + 0.18
					check(z2 + top < 0.0, "Tier %d: a %s walking by never hides the shop floor (reaches %.2f)" % [tier, look, z2 + top])
		# Payung pejalan kaki saat hujan: bentuknya tidak melebihi batas yang
		# dipakai StreetLife memutuskan tier mana yang boleh berpayung.
		var umbrella: Mesh = StreetLife.umbrella_mesh(tier)
		var u_top: float = -INF
		for p3: Vector3 in umbrella.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			var y3: float = p3.y + StreetLife.WALKER_HEAD_MAX + StreetLife.UMBRELLA_RISE
			u_top = maxf(u_top, Vector2(p3.x, p3.z).length() + k * maxf(y3, 0.0))
		check(u_top <= StreetLife.umbrella_lift(k) + 0.01, "the umbrella fits the reach StreetLife assumes (%.2f <= %.2f)" % [u_top, StreetLife.umbrella_lift(k)])
		# Pendar lampu jalan dan umbul-umbul hari libur.
		var n: Node3D = NeighborhoodFactory.build(loc, f)
		var glow: MeshInstance3D = n.get_node("LampGlow") as MeshInstance3D
		check(glow.mesh != null and glow.mesh.get_surface_count() > 0, "Tier %d has street lamps to glow" % tier)
		n.free()
		var outside: MeshInstance3D = HolidayFactory.build_outside(f, 0)
		var min_x: float = INF
		for p2: Vector3 in outside.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			min_x = minf(min_x, p2.x)
		check(min_x > w, "Tier %d: the holiday banners stand beside the shop on the side that never covers it (x %.2f > %.2f)" % [tier, min_x, w])
		outside.free()


# ===========================================================================
# HUJAN
# ===========================================================================

func _rain_street() -> void:
	for tier in range(1, 6):
		var loc: LocationDefinition = _location(tier)
		var f: FloorDefinition = _store_floor(loc)
		var dry: Node3D = NeighborhoodFactory.build(loc, f, false)
		var wet: Node3D = NeighborhoodFactory.build(loc, f, true)
		check(not bool(dry.get_meta("wet")) and bool(wet.get_meta("wet")), "Tier %d: the street knows whether it is wet" % tier)
		eq((wet.get_meta("puddles") as Array).size(), NeighborhoodFactory.puddle_spots(tier).size(), "Tier %d: every puddle is laid" % tier)
		eq((dry.get_meta("puddles") as Array).size(), 0, "Tier %d: no puddles on a dry day" % tier)
		var a_dry: Array = (dry.get_node("Street") as MeshInstance3D).mesh.surface_get_arrays(0)
		var a_wet: Array = (wet.get_node("Street") as MeshInstance3D).mesh.surface_get_arrays(0)
		var v: PackedVector3Array = a_dry[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = a_dry[Mesh.ARRAY_NORMAL]
		var c0: PackedColorArray = a_dry[Mesh.ARRAY_COLOR]
		var c1: PackedColorArray = a_wet[Mesh.ARRAY_COLOR]
		var darker: int = 0
		var lighter: int = 0
		for i in v.size():
			if v[i].y < NeighborhoodFactory.WET_MAX_Y and n[i].y > 0.95 and Vector2(v[i].x, v[i].z).length() < 10.0:
				if c1[i].get_luminance() < c0[i].get_luminance() - 0.02:
					darker += 1
				elif c1[i].get_luminance() > c0[i].get_luminance() + 0.01:
					lighter += 1
		check(darker > 200 and lighter == 0, "Tier %d: the ground near the shop is darker when wet (%d vertices)" % [tier, darker])
		var tris: int = int((wet.get_node("Street") as MeshInstance3D).get_meta("tris", 0))
		check(tris <= 20000, "Tier %d: the wet street stays within 20,000 triangles (%d)" % [tier, tris])
		for pd: Vector4 in NeighborhoodFactory.puddle_spots(tier):
			check(pd.y <= 0.0, "Tier %d: puddles lie on the ground" % tier)
		dry.free()
		wet.free()
	# Pengendara berjas hujan.
	var coat: MeshInstance3D = TrafficFactory.build(&"motor", 0, true, 0.0)
	var dry_coat: MeshInstance3D = TrafficFactory.build(&"motor", 0, false, 0.0)
	check(int(coat.get_meta("tris")) > int(dry_coat.get_meta("tris")), "riders put on a poncho in the rain")
	coat.free()
	dry_coat.free()
	# Di dunia: riak di genangan saat hujan; jalan kering lagi saat hujan reda.
	PauseManager.clear_all()
	var sim: SimulationRoot = new_sim(7720)
	sim.debug_force_weather(&"weather_rain")
	var world: WorldView = _world(sim)
	await runner.get_tree().process_frame
	var sl: StreetLife = world.street_life
	check(bool(world.neighborhood().get_meta("wet")), "on a rainy day the world street is wet")
	eq(sl.ripples.size(), NeighborhoodFactory.puddle_spots(1).size() * StreetLife.RIPPLES_PER_PUDDLE, "raindrops ripple in every puddle")
	if not sl.ripples.is_empty():
		var rn: MeshInstance3D = sl.ripples[0]["node"]
		check(rn.material_override == MeshBuilder.material(MeshBuilder.SHADOW), "ripples reuse the shadow material")
		var s0: float = rn.scale.x
		sl.update(0.3)
		check(not is_equal_approx(rn.scale.x, s0), "ripples spread out")
	var walker_rain: bool = false
	var umbrellas_t1: int = 0
	for m: Dictionary in sl._pool:
		walker_rain = walker_rain or String((m["view"] as ActorView).spec_key).contains("rain")
		if (m["view"] as Node).get_node_or_null("Umbrella") != null:
			umbrellas_t1 += 1
	check(walker_rain, "people walking by put on raincoats")
	eq(umbrellas_t1, 0, "on the narrow kampung road nobody opens an umbrella (it would cover the shop front)")
	sim.debug_force_weather(&"weather_sunny")
	await runner.get_tree().process_frame
	check(not bool(world.neighborhood().get_meta("wet")), "when the rain stops the street is rebuilt dry")
	eq(sl.ripples.size(), 0, "and the ripples are gone")
	world.queue_free()
	free_sim(sim)
	await runner.get_tree().process_frame
	# Tier 2: trotoar cukup jauh dari muka toko, jadi pejalan kaki berpayung.
	var sim2: SimulationRoot = new_sim(7721)
	jump_to_tier(sim2, 2)
	sim2.debug_force_weather(&"weather_rain")
	var world2: WorldView = _world(sim2)
	await runner.get_tree().process_frame
	var umbrellas_t2: int = 0
	for m2: Dictionary in world2.street_life._pool:
		if (m2["view"] as Node).get_node_or_null("Umbrella") != null:
			umbrellas_t2 += 1
	eq(umbrellas_t2, StreetLife.WALKER_POOL, "on the Tier 2 shophouse street people walk under umbrellas")
	world2.queue_free()
	free_sim(sim2)
	await runner.get_tree().process_frame


# ===========================================================================
# HARI LIBUR
# ===========================================================================

func _holiday() -> void:
	eq(HolidayFactory.theme_for(12), 0, "the first holiday is red and white")
	eq(HolidayFactory.theme_for(14), 0, "a holiday keeps its theme for all its days")
	eq(HolidayFactory.theme_for(26), 1, "the next holiday is pastel with lanterns")
	eq(HolidayFactory.theme_for(40), 2, "then green and yellow with ketupat")
	eq(HolidayFactory.theme_for(54), 0, "then the themes start again")
	PauseManager.clear_all()
	var sim: SimulationRoot = new_sim(7730)
	var world: WorldView = _world(sim)
	await runner.get_tree().process_frame
	eq(world.holiday_nodes().size(), 0, "no holiday decorations on an ordinary day")
	var themes: Dictionary = {12: Palette.SIGN_RED, 26: Palette.PASTEL_MINT, 40: Palette.MATCHA}
	for day: Variant in themes.keys():
		sim.time.day = int(day)
		check(sim.weather.holiday_today(), "day %d is a holiday" % day)
		world.rebuild_all()
		var nodes: Array[Node3D] = world.holiday_nodes()
		eq(nodes.size(), 2, "day %d: bunting inside and banners outside" % day)
		if nodes.size() < 2:
			continue
		var inside: MeshInstance3D = nodes[0] as MeshInstance3D
		var room: Node3D = world.floors.get(sim.world.location.store_floor())
		check(inside.get_parent() == room, "the bunting hangs in the shop")
		check(nodes[1].get_parent() == world.neighborhood(), "the banners stand in the street")
		check(inside.material_override == MeshBuilder.material(MeshBuilder.MATTE), "the bunting uses the shared matte material")
		var f: FloorDefinition = _store_floor(sim.world.location)
		var w: float = float(f.size.x) * T
		var d: float = float(f.size.y) * T
		var h: float = RoomFactory.wall_height(sim.world.location.tier)
		var arrays: Array = inside.mesh.surface_get_arrays(0)
		var on_walls: bool = true
		var near_clock: int = 0
		var has_color: bool = false
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		for i in verts.size():
			var p: Vector3 = verts[i]
			on_walls = on_walls and p.x <= w + 0.001 and p.z <= d + 0.001 and p.y >= h * 0.6
			if p.z > d - 0.1 and absf(p.x - w * 0.5) < HolidayFactory.CLOCK_CLEAR - 0.1:
				near_clock += 1
			has_color = has_color or _close(colors[i], themes[day])
		check(on_walls, "day %d: the bunting stays high on the back walls" % day)
		eq(near_clock, 0, "day %d: the bunting leaves the wall clock clear" % day)
		check(has_color, "day %d: the bunting has the holiday theme's colours" % day)
	sim.time.day = 15
	world.rebuild_all()
	eq(world.holiday_nodes().size(), 0, "after the holiday the decorations come down")
	world.queue_free()
	free_sim(sim)
	await runner.get_tree().process_frame


# ===========================================================================
# SUARA JALAN
# ===========================================================================

func _ambience() -> void:
	check(WorldView.ambience_for(false, 3).has(&"street_ambience_t3"), "Tier 3 hears its own street")
	check(WorldView.ambience_for(true, 5).has(&"rain_loop") and WorldView.ambience_for(true, 5).has(&"street_ambience_t5"), "rain and the street play together")
	for tier in range(1, 6):
		var id := StringName("street_ambience_t%d" % tier)
		var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(id)
		if not check(def != null, "%s is in the audio catalog" % id):
			continue
		eq(String(def.bus), "Ambient", "%s plays on the ambient bus" % id)
		check(def.loop, "%s loops" % id)
		var stream: AudioStreamWAV = AudioGenerator.build(String(def.generator))
		eq(stream.loop_mode, AudioStreamWAV.LOOP_FORWARD, "%s is built as a seamless loop" % id)
		near(float(stream.data.size()) / 2.0 / float(stream.mix_rate), AudioGenerator.STREET_SECONDS, 0.01, "%s is a short loop" % id)
	var chime: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(&"clock_tower_chime")
	if check(chime != null and not chime.loop, "the clock tower chime is a one-shot sound"):
		var cs: AudioStreamWAV = AudioGenerator.build(String(chime.generator))
		check(cs.loop_mode == AudioStreamWAV.LOOP_DISABLED and cs.data.size() > 0, "the chime is built")
	# Lonceng hanya di Tier 5, sekali tiap jam berganti.
	PauseManager.clear_all()
	for tier2: int in [1, 5]:
		var sim: SimulationRoot = new_sim(7740 + tier2)
		jump_to_tier(sim, tier2)
		var world: WorldView = _world(sim)
		await runner.get_tree().process_frame
		var sl: StreetLife = world.street_life
		sim.debug_set_time(9.0 * 3600.0 + 3590.0)
		sl.update(0.1)
		var start: int = sl.chimes
		sim.debug_set_time(10.0 * 3600.0 + 10.0)
		sl.update(0.1)
		sim.debug_set_time(10.0 * 3600.0 + 300.0)
		sl.update(0.1)
		eq(sl.chimes - start, 1 if tier2 == 5 else 0, "Tier %d: the clock tower chimes %s" % [tier2, "once on the hour" if tier2 == 5 else "only at the city square"])
		world.queue_free()
		free_sim(sim)
		await runner.get_tree().process_frame
