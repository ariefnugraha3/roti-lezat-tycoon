extends TestSuite
## Model yang dipanggang MeshBake (GDD 12.3, 37, 109): sedikit draw call, bagian
## yang bergerak tetap utuh, warna dan ukuran tidak berubah, dan tidak ada
## kombinasi shader baru. Kesamaan gambarnya diperiksa tools/bake_compare.tscn.


func tests() -> Array:
	return [
		{"id": "ACC_109_BAKED_MODELS", "name": "109 every furniture model is baked into a few vertex-coloured meshes: moving parts (whisk, doors, bread slots, table top, seat) stay their own nodes, the size and every part colour are kept, no new shader combination, and copies share one mesh", "fn": _models},
		{"id": "ACC_109_BAKED_BREAD", "name": "109 a bread is one draw call, and a display slot of up to three breads is one draw call too", "fn": _bread},
		{"id": "ACC_109_DRAW_CALL_BUDGET", "name": "109 a fully equipped, stocked Tier 5 shop draws its room, furniture and bread in a few hundred mesh surfaces (more than 2,000 before baking); counters, tablet and stairs door keep their own meshes for taps and tips", "fn": _budget},
	]


## Permukaan mesh yang tergambar di bawah `root` (satu draw call masing-masing).
func _surfaces(root: Node) -> int:
	var n: int = 0
	for x: Node in [root] + root.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		if mi != null and mi.mesh != null and _shown(mi, root):
			n += mi.mesh.get_surface_count()
	return n


func _shown(n: Node, root: Node) -> bool:
	var p: Node = n
	while p != null:
		if p is Node3D and not (p as Node3D).visible:
			return false
		if p == root:
			return true
		p = p.get_parent()
	return true


## Kunci shader semua material di bawah `root`.
func _keys(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for x: Node in [root] + root.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var b := MeshBake._material_of(mi, s) as BaseMaterial3D
			if b != null:
				out[MaterialKeep.key_of(b)] = true
	return out


## Warna albedo bagian buram bercahaya yang boleh dipanggang (di luar bagian bergerak).
func _part_colors(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for x: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		if mi == null or mi.mesh == null or _under_kept(mi, root):
			continue
		var b := MeshBake._material_of(mi, 0) as StandardMaterial3D
		if b != null and b.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
			out[Color(b.albedo_color, 1.0).to_html()] = true
	return out


func _under_kept(n: Node, root: Node) -> bool:
	var p: Node = n
	while p != null and p != root:
		if MeshBake.is_kept(p) or String(p.name).begins_with("Slot"):
			return true
		p = p.get_parent()
	return false


## Warna yang tergambar di model: warna verteks mesh hasil panggang, ditambah
## albedo bagian yang tidak dipanggang.
func _drawn_colors(root: Node) -> Dictionary:
	var out: Dictionary = {}
	for x: Node in root.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		if String(mi.name) == MeshBake.BAKED_NAME:
			for arrays: Variant in mi.mesh.get_meta("surface_arrays", []):
				for c: Color in (arrays as Array)[Mesh.ARRAY_COLOR] as PackedColorArray:
					out[Color(c, 1.0).to_html()] = true
		else:
			var b := MeshBake._material_of(mi, 0) as StandardMaterial3D
			if b != null:
				out[Color(b.albedo_color, 1.0).to_html()] = true
	return out


func _count_named(root: Node, prefix: String) -> int:
	var n: int = 0
	for x: Node in root.find_children(prefix + "*", "Node3D", true, false):
		if String(x.name).begins_with(prefix):
			n += 1
	return n


func _raw(def: EquipmentDefinition, tier: int) -> Node3D:
	match def.category_id:
		&"mixer":
			return EquipmentFactory.build_mixer(def.tier)
		&"oven":
			return EquipmentFactory.build_oven(def.tier)
		&"display":
			return EquipmentFactory.build_display(def.tier)
		&"table":
			return EquipmentFactory.build_holding_table(tier)
		&"chair":
			return EquipmentFactory.build_staff_chair()
	return EquipmentFactory.build_storage(def.tier)


func _models() -> void:
	var glass_key: String = MaterialKeep.key_of(DecorFactory._glass_material())
	var defs: Array = []
	for cat: StringName in [&"mixer", &"oven", &"display", &"storage"]:
		for t in range(1, 6):
			defs.append([DataRegistry.equipment_for(cat, t), t])
	for t2 in range(1, 6):
		defs.append([DataRegistry.table_definition(), t2])
	defs.append([DataRegistry.equipment(&"staff_chair"), 1])
	for row: Array in defs:
		var def: EquipmentDefinition = row[0]
		var tier: int = row[1]
		if def == null:
			check(false, "missing definition")
			continue
		var label: String = "%s (tier %d)" % [def.id, tier]
		var raw: Node3D = _raw(def, tier)
		var baked: Node3D = EquipmentFactory.build_cached(def, tier)
		var before: int = _surfaces(raw)
		var after: int = _surfaces(baked)
		check(after <= 10 and after < before, "%s: %d surfaces, down from %d" % [label, after, before])
		check(ProceduralMeshFactory.tri_count(baked) <= ProceduralMeshFactory.tri_count(raw) + 8,
			"%s keeps its triangle count (%d vs %d)" % [label, ProceduralMeshFactory.tri_count(baked), ProceduralMeshFactory.tri_count(raw)])
		var rb: AABB = EquipmentFactory._mesh_bounds(raw)
		var bb: AABB = baked.get_meta("bounds", AABB())
		check(rb.position.distance_to(bb.position) < 0.01 and rb.size.distance_to(bb.size) < 0.01, "%s keeps its size" % label)
		for kname: String in ["Whisk", "Beater", "Agitator", "Door", "OvenDoor", "Top", "Seat"]:
			eq(baked.find_child(kname, true, false) != null, raw.find_child(kname, true, false) != null, "%s keeps its %s" % [label, kname])
		eq(_count_named(baked, "Pintu"), _count_named(raw, "Pintu"), "%s keeps its doors" % label)
		eq(_count_named(baked, "Slot"), _count_named(raw, "Slot"), "%s keeps its bread slots" % label)
		var missing: PackedStringArray = PackedStringArray()
		var have: Dictionary = _drawn_colors(baked)
		for c: String in _part_colors(raw):
			if not have.has(c):
				missing.append(c)
		eq(missing, PackedStringArray(), "%s keeps every part colour" % label)
		var raw_keys: Dictionary = _keys(raw)
		for k: Variant in _keys(baked):
			check(raw_keys.has(k) or String(k) == glass_key, "%s adds no shader combination" % label)
		var copy: Node3D = EquipmentFactory.build_cached(def, tier)
		var m1: MeshInstance3D = baked.get_node_or_null(MeshBake.BAKED_NAME) as MeshInstance3D
		var m2: MeshInstance3D = copy.get_node_or_null(MeshBake.BAKED_NAME) as MeshInstance3D
		check(m1 != null and m2 != null and m1.mesh == m2.mesh, "%s copies share one baked mesh" % label)
		for n: Node3D in [raw, baked, copy]:
			n.free()


func _bread() -> void:
	for prof: String in ["loaf.plain", "croissant.classic", "roll.cinnamon", "signature", "donut.jam"]:
		var one: Node3D = BreadFactory.build_cached(prof, 1.0, &"FRESH")
		var raw: Node3D = BreadFactory.build(prof, 1.0, &"FRESH")
		eq(_surfaces(one), 1, "%s: one bread is one draw call (was %d)" % [prof, _surfaces(raw)])
		for n in range(1, 4):
			var slot: Node3D = BreadFactory.slot_cached(prof, 1.0, &"FRESH", n)
			eq(_surfaces(slot), 1, "%s: a slot of %d is one draw call" % [prof, n])
			var mi: MeshInstance3D = slot.get_node_or_null(MeshBake.BAKED_NAME) as MeshInstance3D
			var single: MeshInstance3D = one.get_node_or_null(MeshBake.BAKED_NAME) as MeshInstance3D
			if mi != null and single != null:
				var nv: int = 0
				for a: Variant in mi.mesh.get_meta("surface_arrays", []):
					nv += ((a as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				var sv: int = 0
				for a2: Variant in single.mesh.get_meta("surface_arrays", []):
					sv += ((a2 as Array)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
				eq(nv, sv * n, "%s: the slot holds %d whole breads" % [prof, n])
			slot.free()
		one.free()
		raw.free()


func _budget() -> void:
	var s: SimulationRoot = new_sim(8080)
	s.tutorial.skip()
	jump_to_tier(s, 5)
	# Semua slot dibuka dan dinaikkan ke batas level: model berevolusi ke Tier 5.
	equip_shop(s)
	freeze_production(s)
	var k: int = 0
	var recipes: Array[RecipeDefinition] = DataRegistry.recipes()
	for d: EquipmentInstance in s.equipment.placed_list(&"display"):
		for i in s.display.slots(d.iid).size():
			s.display.place(d.iid, i, recipes[k % recipes.size()].id, 20, s.time.sim_seconds, -10 - k)
			k += 1
	check(s.equipment.placed_count(&"display") >= 5, "at least five Tier 5 shelves stand in the shop")
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._update_bread()
	var store: Node3D = world.floors.get(s.world.store_floor())
	var total: int = 0
	for f: Variant in world.floors.values():
		total += _surfaces(f as Node3D)
	check(total <= 700, "the Tier 5 shop draws %d mesh surfaces (budget 700)" % total)
	for e3: EquipmentInstance in s.equipment.placed_list():
		var node: Node3D = world.furniture.get(e3.iid)
		check(node != null and _surfaces(node) <= 40, "%s %d: %d surfaces with its bread" % [e3.def_id, e3.iid, _surfaces(node) if node != null else -1])
	for nm: String in ["Tablet", "Portal"]:
		var n2: Node3D = store.find_child(nm, false, false) as Node3D
		if n2 != null:
			check(EquipmentFactory._mesh_bounds(n2).size.length() > 0.05, "%s keeps its own mesh" % nm)
	var counters: int = 0
	for c: Node in store.get_children():
		if String(c.name).begins_with("Counter_"):
			counters += 1
			check(EquipmentFactory._mesh_bounds(c as Node3D).size.length() > 0.1, "%s keeps its own mesh" % c.name)
	check(counters > 0, "the shop has counters")
	check(world.main_counter() != null, "the main counter is found")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
