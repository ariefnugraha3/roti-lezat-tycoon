extends Node
## Alat ukur beban render dunia per tier lokasi (v3.1 109, 37): draw call, objek,
## dan segitiga per frame dari RenderingServer, plus asal draw call menurut
## kelompok node (ruangan, perabot, roti, dekorasi, aktor, jalan, lalu lintas).
## Setiap tier dibuka semua slot alatnya di batas level (model berevolusi), staf penuh, semua dekorasi,
## rak penuh roti beraneka, dan pembeli di dalam pukul 10:00, seperti toko pemain
## yang sudah mapan.
## Jalankan dengan jendela (bukan --headless, karena perlu renderer):
##   godot --path . --resolution 1280x720 res://tools/render_probe.tscn [-- --tier=3]

const SHOWCASE: Array[StringName] = [&"recipe_classic_croissant", &"recipe_chocolate_bread",
	&"recipe_strawberry_donut", &"recipe_cinnamon_roll", &"recipe_matcha_brioche", &"recipe_classic_baguette",
	&"recipe_sugar_donut", &"recipe_pain_au_chocolat", &"recipe_milk_pullapart", &"recipe_basque_cheese_bun",
	&"recipe_danish_cheese", &"recipe_whole_wheat_sourdough", &"recipe_sweet_cheese_bread",
	&"recipe_luxury_almond_croissant", &"recipe_matcha_mille_crepes", &"recipe_golden_artisan",
	&"recipe_sausage_roll", &"recipe_plain_loaf"]
const BUYERS: Array[StringName] = [&"customer_generic", &"customer_office_worker", &"customer_school_child",
	&"customer_bulk_buyer", &"customer_generic", &"customer_indecisive"]
const GROUPS: Array[String] = ["room", "furniture", "bread", "markers", "decor", "actors", "street", "traffic", "other"]

var sim: SimulationRoot = null
var world: WorldView = null
var bot: SimBot = null
var _next_job: int = -100


func _ready() -> void:
	var only: int = 0
	var frames: int = 90
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			only = int(a.get_slice("=", 1))
		elif a.begins_with("--frames="):
			frames = int(a.get_slice("=", 1))
	PauseManager.clear_all()
	sim = SimulationRoot.new()
	add_child(sim)
	sim.start_new_game(&"profile_render_probe", "Probe Bakery", "female", 5150)
	sim.tutorial.skip()
	bot = SimBot.new(sim)
	world = WorldView.new()
	add_child(world)
	world.setup(sim)
	for tier in range(1, 6):
		if tier > 1:
			_upgrade()
		if only > 0 and tier != only:
			continue
		await _stage_shop()
		await _measure(tier, frames)
	world.queue_free()
	sim.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ProceduralCaches.clear_all()
	get_tree().quit(0)


# ===========================================================================
# PENYIAPAN TOKO
# ===========================================================================

func _upgrade() -> void:
	sim.debug_add_kr(SimulationRoot.location_cost(sim.world.location.tier + 1) + 500000.0)
	var r: String = sim.upgrade_location()
	if r != "":
		push_error("render_probe: upgrade failed: %s" % r)


## Semua slot alat dibuka dan dinaikkan ke batas level lokasi (model berevolusi),
## staf penuh, semua dekorasi, rak penuh, lalu pukul 10:00 dengan pembeli di dalam.
func _stage_shop() -> void:
	sim.debug_add_kr(1.0e12)
	for cat: StringName in [&"display", &"oven", &"mixer"]:
		while sim.upgrades.open_station(cat) >= 0:
			pass
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			sim.upgrades.set_station_level(e.iid, sim.upgrades.level_cap())
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
				break
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id, true)
	for d: Variant in DataRegistry.decorations():
		var dd: MiscDefinitions.DecorationDefinition = d
		if dd.source == &"shop" and not sim.decoration.owns(dd.id):
			sim.decoration.buy(dd.id)
	_place_decor()
	sim.debug_set_time(9.9 * 3600.0)
	_stock_displays()
	for i in 4 + sim.world.location.tier * 2:
		sim.debug_spawn_customer(BUYERS[i % BUYERS.size()])
		_run(6.0)
	_run(20.0)
	var sl: StreetLife = world.street_life
	while not sl._warm.is_empty():
		sl._work_deadline = Time.get_ticks_usec() + 1000000000
		sl._work_units = 0
		sl._warm_step()
	await _frames(10)


func _place_decor() -> void:
	var store: StringName = sim.decoration.store_floor()
	var fg: FloorGrid = sim.world.grid(store)
	for o: Dictionary in sim.decoration.owned:
		if bool(o["placed"]):
			continue
		var uid: int = int(o["uid"])
		var t: StringName = sim.decoration.type_of(o)
		if t == &"wall" or t == &"counter_prop":
			var free: Array[int] = sim.decoration.free_slots(t, uid)
			if not free.is_empty():
				sim.decoration.place(uid, store, Vector2i.ZERO, free[0])
		elif t == &"floor_prop" or t == &"floor_overlay":
			var done: bool = false
			for z in range(fg.size.y - 1, -1, -1):
				for x in fg.size.x:
					if not done and sim.decoration.place(uid, store, Vector2i(x, z), -1, 0) == &"":
						done = true


func _stock_displays() -> void:
	var k: int = sim.world.location.tier * 3
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		var cap: int = sim.display.slot_capacity(e.iid)
		var sl: Array = sim.display.slots(e.iid)
		for i in sl.size():
			var rid: StringName = SHOWCASE[k % SHOWCASE.size()]
			k += 1
			_next_job -= 1
			sim.display.place(e.iid, i, rid, maxi(1, int(cap * 0.8)), sim.time.sim_seconds, _next_job)


func _run(sim_seconds: float) -> void:
	var t: float = 0.0
	while t < sim_seconds:
		bot.think()
		sim.step(sim.tick_seconds)
		t += sim.tick_seconds


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ===========================================================================
# PENGUKURAN
# ===========================================================================

func _measure(tier: int, frames: int) -> void:
	var calls: Array[float] = []
	var objects: Array[float] = []
	var prims: Array[float] = []
	var proc_ms: Array[float] = []
	for i in frames:
		# Simulasi tetap berjalan seperti di 1x supaya aktor bergerak.
		_run(1.0 / 30.0)
		await RenderingServer.frame_post_draw
		calls.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		objects.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))
		prims.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
		proc_ms.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	var groups: Dictionary = {}
	for g: String in GROUPS:
		groups[g] = 0
	var nodes: Dictionary = groups.duplicate()
	var cam: Camera3D = world.camera_rig.camera
	var planes: Array[Plane] = cam.get_frustum()
	for n: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = n
		if mi.mesh == null or not mi.is_visible_in_tree() or not _in_view(mi, planes):
			continue
		var g2: String = _group_of(mi)
		groups[g2] = int(groups[g2]) + mi.mesh.get_surface_count()
		nodes[g2] = int(nodes[g2]) + 1
	var mm: int = 0
	for n2: Node in world.find_children("*", "MultiMeshInstance3D", true, false):
		if (n2 as MultiMeshInstance3D).is_visible_in_tree():
			mm += 1
	# Rincian per anak node lantai (nama tanpa angka): perabot dan bagian ruangan.
	var parts_by: Dictionary = {}
	for n3: Node in world.find_children("*", "MeshInstance3D", true, false):
		var mi3: MeshInstance3D = n3
		if mi3.mesh == null or not mi3.is_visible_in_tree() or not _in_view(mi3, planes):
			continue
		var top: Node = mi3
		while top.get_parent() != null and not world.floors.values().has(top.get_parent()):
			top = top.get_parent()
		if top.get_parent() == null:
			continue
		var key: String = String(top.name).rstrip("0123456789").rstrip("_")
		if top.has_meta("iid"):
			var e: EquipmentInstance = sim.equipment.get_inst(int(top.get_meta("iid")))
			key = String(e.def_id) if e != null else key
		parts_by[key] = int(parts_by.get(key, 0)) + mi3.mesh.get_surface_count()
	var keys: Array = parts_by.keys()
	keys.sort_custom(func(a: Variant, b: Variant) -> bool: return int(parts_by[a]) > int(parts_by[b]))
	var top_parts: PackedStringArray = PackedStringArray()
	for k2: Variant in keys.slice(0, 14):
		top_parts.append("%s %d" % [k2, int(parts_by[k2])])
	print("  floor children: ", ", ".join(top_parts))
	if OS.get_cmdline_user_args().has("--why"):
		_print_unbaked()
	if OS.get_cmdline_user_args().has("--surfaces"):
		_print_surfaces()

	print("TIER %d  draw_calls %.0f (max %.0f)  objects %.0f  triangles %.0f  process %.2f ms" % [tier,
		_avg(calls), _max(calls), _avg(objects), _avg(prims), _avg(proc_ms)])
	var parts: PackedStringArray = PackedStringArray()
	for g3: String in GROUPS:
		parts.append("%s %d/%d" % [g3, int(groups[g3]), int(nodes[g3])])
	print("  visible surfaces/nodes: ", ", ".join(parts), "  multimesh ", mm)


func _in_view(mi: MeshInstance3D, planes: Array[Plane]) -> bool:
	var box: AABB = mi.global_transform * mi.get_aabb()
	for p: Plane in planes:
		var outside: bool = true
		for i in 8:
			if not p.is_point_over(box.get_endpoint(i)):
				outside = false
				break
		if outside:
			return false
	return true


func _group_of(mi: Node) -> String:
	var n: Node = mi
	var in_equip: bool = false
	while n != null and n != world:
		var nm: String = String(n.name)
		if nm.begins_with("Bread_") or nm == "PaperBag" or nm == "GiftBox":
			return "bread"
		if nm.begins_with("Equip_"):
			in_equip = true
		if nm.begins_with("Decor_"):
			return "decor"
		if n is StationMarker:
			return "markers"
		if n is ActorView:
			return "actors"
		if nm == "Neighborhood":
			return "street"
		if nm == "Traffic":
			return "traffic"
		if n.get_parent() == world and world.floors.values().has(n):
			return "furniture" if in_equip else "room"
		n = n.get_parent()
	return "furniture" if in_equip else "other"


func _avg(a: Array[float]) -> float:
	var s: float = 0.0
	for v: float in a:
		s += v
	return s / maxf(1.0, float(a.size()))


func _max(a: Array[float]) -> float:
	var m: float = 0.0
	for v: float in a:
		m = maxf(m, v)
	return m


## Bagian yang masih punya draw call sendiri di perabot dan ruangan, dengan sebabnya.
func _print_unbaked() -> void:
	var why: Dictionary = {}
	for f: Variant in world.floors.values():
		for n: Node in (f as Node3D).find_children("*", "MeshInstance3D", true, false):
			var mi: MeshInstance3D = n
			if mi.mesh == null or String(mi.name) == MeshBake.BAKED_NAME or not mi.is_visible_in_tree():
				continue
			var m: Material = MeshBake._material_of(mi, 0)
			var b := m as BaseMaterial3D
			var reason: String = "no material"
			if b != null:
				reason = "%s vc=%s emis=%s alpha=%d shade=%d bill=%d" % [b.get_class(), b.vertex_color_use_as_albedo, b.emission_enabled,
					b.transparency, b.shading_mode, b.billboard_mode]
			var p: Node = mi.get_parent()
			var chain: String = String(mi.name)
			while p != null and p != f:
				if MeshBake.is_kept(p):
					chain = "%s<%s>" % [chain, p.name]
				p = p.get_parent()
			var key: String = "%s %s | %s" % [mi.mesh.get_class(), chain.rstrip("0123456789"), reason]
			why[key] = int(why.get(key, 0)) + 1
	var keys: Array = why.keys()
	keys.sort_custom(func(a: Variant, b2: Variant) -> bool: return int(why[a]) > int(why[b2]))
	for k: Variant in keys.slice(0, 30):
		print("    %4d  %s" % [int(why[k]), k])


## Permukaan model hasil panggang: kelompok material yang tersisa per model.
func _print_surfaces() -> void:
	for k: Variant in EquipmentFactory._proto_cache.keys():
		var proto: Node3D = EquipmentFactory._proto_cache[k]
		var parts: PackedStringArray = PackedStringArray()
		var total: int = 0
		for n: Node in [proto] + proto.find_children("*", "MeshInstance3D", true, false):
			var mi := n as MeshInstance3D
			if mi == null or mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				total += 1
				var b := MeshBake._material_of(mi, s) as BaseMaterial3D
				if b != null:
					parts.append("%s r%.2f m%.2f%s%s" % [mi.name, b.roughness, b.metallic, " E" if b.emission_enabled else "", " A" if b.transparency != 0 else ""])
		print("  %s: %d surfaces: %s" % [k, total, ", ".join(parts)])
