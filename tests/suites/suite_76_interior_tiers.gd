extends TestSuite
## Interior per tier lokasi (keputusan maintainer 2026-10-08, GDD 32.3): ubin, dinding,
## meja kasir, dan meja tunggu berbeda bentuk dan warnanya di setiap tier, tanpa
## kombinasi shader baru, dan titik pasang perabotnya tetap di tempat yang sama.


func tests() -> Array:
	return [
		{"id": "ACC_32_INTERIOR_TIERS", "name": "32.3 every location tier has its own interior: floor pattern and colours, wall and wainscot colours, cashier counter shape and colours, and holding table shape and colours all differ between tiers; the counter keeps its surface and tablet anchors at counter height, the holding table keeps its Top anchor at one height and fits its 2 x 1 footprint, and the variants add no shader combination", "fn": _interior},
	]


## Ringkasan warna albedo semua mesh di bawah `n` (dibulatkan) beserta jumlah mesh:
## dua perabot berbeda bentuk atau warna menghasilkan ringkasan berbeda.
func _signature(n: Node) -> String:
	var colors: Dictionary = {}
	var meshes: int = 0
	for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
		meshes += 1
		var m: StandardMaterial3D = ProceduralMeshFactory.material_of(mi as MeshInstance3D)
		if m != null:
			var c: Color = m.albedo_color
			colors["%.2f,%.2f,%.2f" % [c.r, c.g, c.b]] = true
	var keys: Array = colors.keys()
	keys.sort()
	return "%d|%s" % [meshes, ";".join(PackedStringArray(keys))]


func _store_floor(loc: LocationDefinition) -> FloorDefinition:
	for f: FloorDefinition in loc.floors:
		if f.id == loc.store_floor():
			return f
	return null


func _interior() -> void:
	# Gaya ruangan: tiap pasangan tier berbeda dinding dan lantai tokonya.
	var walls: Dictionary = {}
	var floors: Dictionary = {}
	for t in range(1, 6):
		var st: Dictionary = RoomFactory.interior_style(t)
		walls[(st["wall"] as Color).to_html()] = t
		var fs: Dictionary = st["store"]
		floors["%s|%s|%s" % [fs["pattern"], (fs["a"] as Color).to_html(), (fs["b"] as Color).to_html()]] = t
		check(st.has("wainscot") and float(st["wainscot_h"]) > 0.0, "Tier %d has a wainscot" % t)
	eq(walls.size(), 5, "every tier paints its walls differently")
	eq(floors.size(), 5, "every tier lays a different shop floor")
	var patterns: Dictionary = {}
	for t2 in range(1, 6):
		patterns[RoomFactory.interior_style(t2)["store"]["pattern"]] = true
	check(patterns.size() >= 3, "shop floors use at least three patterns (checker, planks, marble)")
	# Meja kasir dan meja tunggu: bentuk dan warna berbeda di setiap tier.
	var counters: Dictionary = {}
	var tables: Dictionary = {}
	var holder := Node3D.new()
	runner.add_child(holder)
	var top_y: float = -1.0
	for t3 in range(1, 6):
		var counter: Node3D = EquipmentFactory.build_divider_counter(t3, 1.46, 1)
		holder.add_child(counter)
		counters[_signature(counter)] = t3
		var surface: Node3D = counter.find_child("Surface", false, false) as Node3D
		check(surface != null and is_equal_approx(surface.position.y, EquipmentFactory.DIVIDER_HEIGHT), "Tier %d counter keeps its surface at counter height" % t3)
		check(counter.find_child("Tablet", false, false) != null and counter.find_child("Register0", false, false) != null, "Tier %d counter keeps its tablet spot and register" % t3)
		var table: Node3D = EquipmentFactory.build_holding_table(t3)
		holder.add_child(table)
		tables[_signature(table)] = t3
		var top: Node3D = table.find_child("Top", false, false) as Node3D
		if check(top != null, "Tier %d holding table has its Top anchor" % t3):
			if top_y < 0.0:
				top_y = top.position.y
			near(top.position.y, top_y, 0.001, "Tier %d holding table keeps the same surface height" % t3)
		var b: AABB = EquipmentFactory._mesh_bounds(table)
		check(b.size.x <= 1.0 and b.size.z <= 0.5, "Tier %d holding table fits its 2 x 1 footprint (%s)" % [t3, b.size])
	eq(counters.size(), 5, "every tier has its own cashier counter")
	eq(tables.size(), 5, "every tier has its own holding table")
	# Tidak ada kombinasi shader baru: semua varian memakai kombinasi Tier 1.
	MaterialKeep.clear()
	var base := Node3D.new()
	runner.add_child(base)
	base.add_child(EquipmentFactory.build_divider_counter(1, 1.46, 1))
	base.add_child(EquipmentFactory.build_holding_table(1))
	var loc1: LocationDefinition = null
	for loc: LocationDefinition in DataRegistry.locations():
		if loc.tier == 1:
			loc1 = loc
	base.add_child(RoomFactory.build_floor(loc1, _store_floor(loc1), "Base Bakery", {}))
	MaterialKeep.scan(base)
	var base_count: int = MaterialKeep.count()
	MaterialKeep.scan(holder)
	for loc2: LocationDefinition in DataRegistry.locations():
		for fd: FloorDefinition in loc2.floors:
			var room: Node3D = RoomFactory.build_floor(loc2, fd, "Tier Bakery", {})
			holder.add_child(room)
	MaterialKeep.scan(holder)
	eq(MaterialKeep.count(), base_count, "the tier interiors add no shader combination")
	MaterialKeep.clear()
	base.queue_free()
	holder.queue_free()
	await runner.get_tree().process_frame
