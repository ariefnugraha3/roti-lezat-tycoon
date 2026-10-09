extends TestSuite
## Lingkungan di luar toko (keputusan maintainer 2026-10-08, GDD 32.5): Tier 1 di
## pinggir jalan aspal komplek sebuah perumahan kampung kota, Tier 2 di ujung
## deretan ruko yang menghadap jalan dua lajur, Tier 3 berdiri sendiri di tepi
## jalan raya kota, Tier 4 di kawasan premium, Tier 5 menghadap alun-alun kota.
## Satu mesh berwarna verteks, tidak pernah menutupi isi toko (juga dari lantai
## atas).

const T: float = GridMath.WORLD_METERS_PER_TILE
## Batas segitiga mesh jalan satu lokasi (satu draw call) dan lantai dasar ruko
## sendiri.
const TRI_BUDGET: int = 20000
const OWN_TRI_BUDGET: int = 2000


func tests() -> Array:
	return [
		{"id": "ACC_32_NEIGHBORHOOD_STREETS", "name": "32.5 Tier 1 stands on a kampung street, Tier 2 at the end of a row of shophouses, Tier 3 on a city avenue, Tier 4 in a premium district and Tier 5 on the city square: one vertex-coloured street mesh with the shared matte material (one draw call, no new shader, nothing to tap) within the triangle budget, asphalt in front of the shop and the background colour far away (a bigger floor fades further out); a shop with an upper floor also gets its own ground floor as a second mesh; the street is built once per location, not on every decoration change, and changes or goes away with the location", "fn": _streets},
		{"id": "ACC_32_NEIGHBORHOOD_UPPER_FLOOR", "name": "32.5 from the Tier 2 and Tier 3 kitchens upstairs the street shows one storey below with the shop's own ground floor under the kitchen; back on the shop floor it stands at street level again; an unknown floor hides it", "fn": _upper_floor},
		{"id": "ACC_32_NEIGHBORHOOD_CLEAR", "name": "32.5 nothing outside the shop can hide the shop: from the locked camera angle no triangle of the street or its lamp glow (lowered one storey per floor, with the shop's own ground floor on upper floors) covers any part of the floor on screen or what stands on it", "fn": _clear},
	]


func _store_floor(loc: LocationDefinition) -> FloorDefinition:
	for f: FloorDefinition in loc.floors:
		if f.id == loc.store_floor():
			return f
	return null


func _location(tier: int) -> LocationDefinition:
	for loc: LocationDefinition in DataRegistry.locations():
		if loc.tier == tier:
			return loc
	return null


## Warna verteks disimpan 8 bit per kanal, jadi dibandingkan dengan toleransi.
func _close(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.01 and absf(a.g - b.g) < 0.01 and absf(a.b - b.b) < 0.01


func _arrays(street: Node3D, mesh_name: String) -> Array:
	var mi: MeshInstance3D = street.get_node_or_null(mesh_name) as MeshInstance3D
	if mi == null or mi.mesh == null:
		return []
	return mi.mesh.surface_get_arrays(0)


func _streets() -> void:
	PauseManager.clear_all()
	for loc: LocationDefinition in DataRegistry.locations():
		var f: FloorDefinition = _store_floor(loc)
		var n: Node3D = NeighborhoodFactory.build(loc, f)
		if not NeighborhoodFactory.has_street(loc.tier):
			check(n == null, "Tier %d keeps the plain background for now" % loc.tier)
			if n != null:
				n.free()
			continue
		if not check(n != null, "Tier %d has a street around the shop" % loc.tier):
			continue
		var upper: bool = loc.floors.size() > 1
		eq(n.find_children("*", "MeshInstance3D", true, false).size(), (2 if upper else 1) + 1,
			"Tier %d: the street is one mesh (one draw call)%s, plus the street lamp glow shown at dawn and dusk (GDD 32.6)" % [loc.tier, ", plus the shop's own ground floor" if upper else ""])
		var glow: MeshInstance3D = n.get_node_or_null("LampGlow") as MeshInstance3D
		if check(glow != null, "Tier %d has a lamp glow mesh" % loc.tier):
			check(not glow.visible, "Tier %d: the lamp glow starts off" % loc.tier)
			check(glow.material_override == MeshBuilder.material(MeshBuilder.SHADOW), "Tier %d: the lamp glow reuses the shadow material, so no new shader" % loc.tier)
		check(n.find_children("*", "CollisionObject3D", true, false).is_empty(), "Tier %d: nothing in the street can be tapped" % loc.tier)
		for mesh_name: String in ["Street", "OwnBuilding"]:
			var mi: MeshInstance3D = n.get_node_or_null(mesh_name) as MeshInstance3D
			if mi == null:
				check(mesh_name == "OwnBuilding" and not upper, "Tier %d has the %s mesh" % [loc.tier, mesh_name])
				continue
			check(mi.mesh != null, "Tier %d: the %s mesh is built" % [loc.tier, mesh_name])
			check(mi.material_override == MeshBuilder.material(MeshBuilder.MATTE), "Tier %d: %s uses the shared matte material, so no new shader" % [loc.tier, mesh_name])
			eq(mi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "Tier %d: %s casts no shadows" % [loc.tier, mesh_name])
			var tris: int = int(mi.get_meta("tris", 0))
			var budget: int = TRI_BUDGET if mesh_name == "Street" else OWN_TRI_BUDGET
			check(tris > 100 and tris <= budget, "Tier %d: %s stays within %d triangles (%d)" % [loc.tier, mesh_name, budget, tris])
		var own: Node3D = n.get_node_or_null("OwnBuilding") as Node3D
		check(own == null or not own.visible, "Tier %d: the shop's own ground floor starts hidden" % loc.tier)
		# Warna: aspal utuh di depan toko, warna latar di kejauhan.
		var arrays: Array = _arrays(n, "Street")
		if not arrays.is_empty():
			var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var c: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			var w: float = float(f.size.x) * T
			var center := Vector2(w * 0.5, float(f.size.y) * T * 0.5)
			var fade_end: float = NeighborhoodFactory.fade_radii(w, float(f.size.y) * T).y
			var road: Vector2 = NeighborhoodFactory.road_edges(loc.tier)
			var asphalt: int = 0
			var far_wrong: int = 0
			for k in v.size():
				var p: Vector3 = v[k]
				if Vector2(p.x, p.z).distance_to(center) >= fade_end and not _close(c[k], Palette.BG):
					far_wrong += 1
				if absf(p.y - NeighborhoodFactory.Y_ROAD) < 0.001 and p.z <= road.x + 0.001 and p.z >= road.y - 0.001 \
						and absf(p.x - w * 0.5) < 4.0 and _close(c[k], Palette.ASPHALT):
					asphalt += 1
			check(asphalt >= 4, "Tier %d: the road in front of the shop keeps its asphalt colour (%d vertices)" % [loc.tier, asphalt])
			eq(far_wrong, 0, "Tier %d: far away the street melts into the background colour" % loc.tier)
		n.free()
	# Di dunia permainan: dibangun sekali per lokasi, berganti bersama lokasinya.
	var s: SimulationRoot = new_sim(7501)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	await runner.get_tree().process_frame
	var street: Node3D = world.neighborhood()
	if check(street != null, "the Tier 1 world shows the street"):
		check(street.is_inside_tree() and street.visible, "the street is drawn on the shop floor")
		var first: int = street.get_instance_id()
		world.rebuild_all()
		check(world.neighborhood() != null and world.neighborhood().get_instance_id() == first, "redrawing the room after a decoration change keeps the same street")
	jump_to_tier(s, 2)
	await runner.get_tree().process_frame
	eq(s.world.location.tier, 2, "the shop moved to Tier 2")
	var street2: Node3D = world.neighborhood()
	check(street2 != null and street2.get_node_or_null("OwnBuilding") != null, "the Tier 2 shophouse street replaces it")
	check(street == null or not is_instance_valid(street), "the Tier 1 street is gone")
	jump_to_tier(s, 3)
	await runner.get_tree().process_frame
	eq(s.world.location.tier, 3, "the shop moved to Tier 3")
	var street3: Node3D = world.neighborhood()
	check(street3 != null and street3.get_node_or_null("OwnBuilding") != null, "the Tier 3 city avenue replaces it")
	check(street2 == null or not is_instance_valid(street2), "the Tier 2 street is gone")
	jump_to_tier(s, 4)
	await runner.get_tree().process_frame
	eq(s.world.location.tier, 4, "the shop moved to Tier 4")
	var street4: Node3D = world.neighborhood()
	check(street4 != null and street4.get_node_or_null("OwnBuilding") == null, "the Tier 4 premium street replaces it, without an upper floor")
	check(street3 == null or not is_instance_valid(street3), "the Tier 3 street is gone")
	jump_to_tier(s, 5)
	await runner.get_tree().process_frame
	eq(s.world.location.tier, 5, "the shop moved to Tier 5")
	var street5: Node3D = world.neighborhood()
	check(street5 != null and street5.get_node_or_null("OwnBuilding") == null, "the Tier 5 city square replaces it, without an upper floor")
	check(street4 == null or not is_instance_valid(street4), "the Tier 4 street is gone")
	world.queue_free()
	free_sim(s)
	await runner.get_tree().process_frame
	PauseManager.clear_all()


func _upper_floor() -> void:
	PauseManager.clear_all()
	for tier: int in [2, 3]:
		var loc: LocationDefinition = _location(tier)
		eq(NeighborhoodFactory.floor_level(loc, &"floor_1"), 0, "Tier %d: the shop floor stands on the street" % tier)
		eq(NeighborhoodFactory.floor_level(loc, &"floor_2"), 1, "Tier %d: the kitchen is one storey up" % tier)
		eq(NeighborhoodFactory.floor_level(loc, &"somewhere"), -1, "Tier %d: an unknown floor has no level" % tier)
		var s: SimulationRoot = new_sim(7500 + tier)
		jump_to_tier(s, tier)
		var world := WorldView.new()
		runner.add_child(world)
		world.setup(s)
		await runner.get_tree().process_frame
		var street: Node3D = world.neighborhood()
		if check(street != null, "the Tier %d world shows the street" % tier):
			var own: Node3D = street.get_node_or_null("OwnBuilding") as Node3D
			var rig: CameraRig = world.camera_rig
			rig.active_floor = &"floor_2"
			world._apply_floor_visibility()
			check(street.visible, "Tier %d: the street shows from the kitchen" % tier)
			near(street.position.y, -NeighborhoodFactory.STOREY, 0.001, "Tier %d: from the kitchen the street is one storey below" % tier)
			check(own != null and own.visible, "Tier %d: under the kitchen stands the shop's own ground floor" % tier)
			rig.active_floor = s.world.location.store_floor()
			world._apply_floor_visibility()
			check(street.visible, "Tier %d: the street shows on the shop floor" % tier)
			near(street.position.y, 0.0, 0.001, "Tier %d: on the shop floor the street is at street level" % tier)
			check(own != null and not own.visible, "Tier %d: on the shop floor its own ground floor is not drawn (the shop is)" % tier)
			rig.active_floor = &"somewhere"
			world._apply_floor_visibility()
			check(not street.visible, "Tier %d: an unknown floor hides the street" % tier)
			rig.active_floor = s.world.location.store_floor()
			world._apply_floor_visibility()
		world.queue_free()
		free_sim(s)
		await runner.get_tree().process_frame
	PauseManager.clear_all()


## Titik setinggi h menutupi titik tanah yang bergeser h * geser menjauhi kamera.
## Daerah tanah yang bisa ditutupi sebuah segitiga = selubung cembung dari kaki
## dan bayangan ketiga sudutnya; daerah itu tidak boleh menyentuh lantai yang
## sedang tampil. Dari lantai atas, jalan turun STOREY meter per lantai dan lantai
## dasar ruko sendiri ikut diperiksa.
func _clear() -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var shift: Vector2 = Vector2(sin(yaw), cos(yaw)) / tan(pitch)
	var views: int = 0
	for loc: LocationDefinition in DataRegistry.locations():
		if not NeighborhoodFactory.has_street(loc.tier):
			continue
		var n: Node3D = NeighborhoodFactory.build(loc, _store_floor(loc))
		if not check(n != null, "Tier %d street is built" % loc.tier):
			continue
		for fd: FloorDefinition in loc.floors:
			var level: int = NeighborhoodFactory.floor_level(loc, fd.id)
			if level < 0:
				continue
			views += 1
			var drop: float = NeighborhoodFactory.STOREY * float(level)
			var meshes: Array[String] = ["Street", "LampGlow"]
			if level > 0:
				meshes.append("OwnBuilding")
			var bad: Array[String] = []
			var tested: int = 0
			for mesh_name: String in meshes:
				var arrays: Array = _arrays(n, mesh_name)
				if not check(not arrays.is_empty(), "Tier %d %s is built" % [loc.tier, mesh_name]):
					continue
				tested += _hits(arrays, drop, float(fd.size.x) * T, float(fd.size.y) * T, shift, bad)
			check(tested > 1000, "Tier %d %s: the check covers the street (%d triangles above the floor)" % [loc.tier, fd.id, tested])
			eq(bad.size(), 0, "Tier %d %s: no triangle of the street can hide the floor (first: %s)" % [loc.tier, fd.id, ", ".join(PackedStringArray(bad.slice(0, 5)))])
		n.free()
	check(views >= 7, "every floor with a street is checked (%d)" % views)


## Hitung segitiga di atas lantai dan catat yang bisa menutupi lantai w x d.
func _hits(arrays: Array, drop: float, w: float, d: float, shift: Vector2, bad: Array[String]) -> int:
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var floor_rect := Rect2(0.0, 0.0, w, d)
	var floor_poly := PackedVector2Array([Vector2(0.0, 0.0), Vector2(w, 0.0), Vector2(w, d), Vector2(0.0, d)])
	var tested: int = 0
	for t in idx.size() / 3:
		var pts := PackedVector2Array()
		var top: float = -INF
		for k in 3:
			var p: Vector3 = v[idx[t * 3 + k]]
			var y: float = p.y - drop
			top = maxf(top, y)
			pts.append(Vector2(p.x, p.z))
			pts.append(Vector2(p.x, p.z) + shift * maxf(y, 0.0))
		# Di bawah lantai yang tampil: tertutup lantai itu sendiri.
		if top <= 0.001:
			continue
		tested += 1
		var box := Rect2(pts[0], Vector2.ZERO)
		for q: Vector2 in pts:
			box = box.expand(q)
		if not box.intersects(floor_rect):
			continue
		var hull: PackedVector2Array = Geometry2D.convex_hull(pts)
		if hull.size() > 1 and hull[0] == hull[hull.size() - 1]:
			hull.remove_at(hull.size() - 1)
		var hit: bool = false
		if hull.size() >= 3:
			hit = not Geometry2D.intersect_polygons(hull, floor_poly).is_empty()
		else:
			for q2: Vector2 in pts:
				hit = hit or Geometry2D.is_point_in_polygon(q2, floor_poly)
		if hit:
			bad.append(str(v[idx[t * 3]]))
	return tested
