extends TestSuite
## Slot dekorasi per tier toko, model dekorasi, dan kelebihan kasir Tier 2/4
## (GDD 3.1, 72.1-72.3; keputusan maintainer 2026-09-30).

const T: float = GridMath.WORLD_METERS_PER_TILE


func tests() -> Array:
	return [
		{"id": "ACC_72_DECOR_SLOTS", "name": "72.3 wall spots sit between windows on the full walls, store side first; counter spots sit at the free end of each register counter", "fn": _slot_geometry},
		{"id": "ACC_72_DECOR_CAPS", "name": "72.3 decorations go on the shop floor only, up to the location's cap per type; wall/counter slots cannot be shared", "fn": _caps},
		{"id": "ACC_72_DECOR_RUGS", "name": "72.1 rugs cover their tile footprint in the shop area, may lie on walkways, never block, rotate, and do not overlap", "fn": _rugs},
		{"id": "ACC_72_DECOR_ENFORCE", "name": "72.3 loading or moving shop puts back decorations that break the slot rules; the older one keeps its place", "fn": _enforce},
		{"id": "TEST_VIS_DECOR_MODELS", "name": "72.1 every placeable decoration has its own procedural model inside the triangle budget and its slot", "fn": _models},
		{"id": "TEST_VIS_DECOR_WORLD", "name": "72.3 placed decorations are drawn, pickable in Decoration Mode, and slot markers answer taps; wall windows and clock face the room", "fn": _world},
		{"id": "TEST_UI_DECOR_SLOTS", "name": "72.2-72.3 Decoration Mode lights free slots, a tap tries the decoration there and Place hangs it, full types explain the cap, rugs rotate before Place", "fn": _ui},
		{"id": "ACC_72_BADGES", "name": "72.1 achievement badges hang on a wall spot like wall decorations (sharing the wall cap) and show as medals on the profile card", "fn": _badges},
		{"id": "ACC_3_CASHIER_PERKS", "name": "3.1 Tier 2 cashiers calm the queue by 8%, Tier 4 by 15% and lift the rating 1.5x per sale", "fn": _cashier_perks},
	]


# ===========================================================================
# GEOMETRI SLOT
# ===========================================================================

func _slot_geometry() -> void:
	for x: Variant in DataRegistry.locations():
		var loc: LocationDefinition = x
		var f: FloorDefinition = loc.floor_def(loc.store_floor())
		var w: float = float(f.size.x) * T
		var d: float = float(f.size.y) * T
		var spots: Array[Dictionary] = DecorSlots.wall_spots(loc)
		var cap: int = loc.decor_slot_count(&"wall")
		check(spots.size() >= cap, "%s: %d wall spots for a cap of %d" % [loc.id, spots.size(), cap])
		eq(DecorSlots.wall_slots(loc).size(), cap, "%s: exactly the cap is usable" % loc.id)
		var half: float = DecorSlots.WALL_SLOT_WIDTH * 0.5
		var bad: PackedStringArray = PackedStringArray()
		var saw_kitchen: bool = false
		for i in spots.size():
			var s: Dictionary = spots[i]
			var p: Vector3 = s["pos"]
			eq(int(s["index"]), i, "%s: spots are numbered in order" % loc.id)
			var back: bool = s["wall"] == &"back"
			var along: float = p.x if back else p.z
			if back and (absf(p.z - d) > 0.01 or absf(float(s["yaw"])) > 0.001):
				bad.append("spot %d is not on the back wall" % i)
			if not back and (absf(p.x - w) > 0.01 or absf(float(s["yaw"]) - PI * 0.5) > 0.001):
				bad.append("spot %d is not on the right wall" % i)
			for wx: float in (RoomFactory.back_window_xs(w) if back else RoomFactory.side_window_zs(d)):
				if absf(along - wx) < DecorSlots.WINDOW_CLEAR + half - 0.001:
					bad.append("spot %d covers a window" % i)
			if along - half < -0.001 or along + half > (w if back else d) + 0.001:
				bad.append("spot %d runs past the wall" % i)
			for j in spots.size():
				var s2: Dictionary = spots[j]
				if j != i and s2["wall"] == s["wall"]:
					var a2: float = Vector3(s2["pos"]).x if back else Vector3(s2["pos"]).z
					if absf(a2 - along) < DecorSlots.WALL_SLOT_WIDTH + DecorSlots.WALL_SLOT_GAP - 0.001:
						bad.append("spots %d and %d crowd each other" % [i, j])
			if f.has_portal():
				var pc: Vector2i = f.portal["cell"]
				var on_wall: bool = pc.y == f.size.y - 1 if back else pc.x == f.size.x - 1
				var p0: float = float(pc.x if back else pc.y) * T
				if on_wall and along + half > p0 and along - half < p0 + T:
					bad.append("spot %d hangs over the stairs door" % i)
			var cell: Vector2i = Vector2i(clampi(int(p.x / T), 0, f.size.x - 1), f.size.y - 1) if back else Vector2i(f.size.x - 1, clampi(int(p.z / T), 0, f.size.y - 1))
			var store: bool = f.zone_at(cell) == &"store"
			if store and saw_kitchen:
				bad.append("store-side spot %d comes after a kitchen-side spot" % i)
			saw_kitchen = saw_kitchen or not store
		check(bad.is_empty(), "%s wall spots: %s" % [loc.id, "; ".join(bad)])
		# Meja kasir: satu slot per meja, di ujung yang bebas.
		var ccap: int = loc.decor_slot_count(&"counter_prop")
		var cs: Array[Dictionary] = DecorSlots.counter_slots(loc)
		eq(cs.size(), ccap, "%s: one counter spot per allowed counter decoration" % loc.id)
		for sd: Dictionary in cs:
			var c: Dictionary = f.counter(sd["counter"])
			var fr: Dictionary = DecorSlots.counter_frame(f, c)
			var p2: Vector3 = sd["pos"]
			var mn: Vector2i = fr["cells"][0]
			var mx: Vector2i = fr["cells"][1]
			near(p2.y, EquipmentFactory.COUNTER_HEIGHT, 0.0001, "%s %s: the spot is on the counter top" % [loc.id, sd["counter"]])
			check(p2.x > float(mn.x) * T and p2.x < float(mx.x + 1) * T and p2.z > float(mn.y) * T and p2.z < float(mx.y + 1) * T,
				"%s %s: the spot is on the counter itself" % [loc.id, sd["counter"]])
			var off: Vector2 = Vector2(p2.x, p2.z) - Vector2(fr["center"])
			var axis_off: float = absf(off.x) if bool(fr["axis_x"]) else absf(off.y)
			check(axis_off >= 0.25, "%s %s: clear of the register in the middle (%.2f m)" % [loc.id, sd["counter"], axis_off])
			check(GridMath.world_to_cell(Vector2(p2.x, p2.z)) != Vector2i(c.get("tablet_cell", FloorDefinition.NONE_CELL)),
				"%s %s: not on the RotiFood tablet" % [loc.id, sd["counter"]])
			var bag: Vector2 = Vector2(fr["center"]) + Vector2(fr["bag_side"]) * WorldView.PACK_BAG_SIDE
			check(bag.distance_to(Vector2(p2.x, p2.z)) >= 0.3 or c.get("tablet_cell", FloorDefinition.NONE_CELL) != FloorDefinition.NONE_CELL,
				"%s %s: away from the paper bag" % [loc.id, sd["counter"]])
			var facing := Vector2(-sin(float(sd["yaw"])), -cos(float(sd["yaw"])))
			check(facing.distance_to(Vector2(fr["to_customer"])) < 0.001, "%s %s: the decoration faces the customer" % [loc.id, sd["counter"]])


# ===========================================================================
# BATAS & SLOT
# ===========================================================================

func _caps() -> void:
	var s: SimulationRoot = new_sim(7201)
	s.tutorial.skip()
	var dm: DecorationManager = s.decoration
	var sf: StringName = dm.store_floor()
	# Batas lokasi (keputusan maintainer 2026-09-30, "bertahap").
	var want: Dictionary = {1: [2, 1, 1, 1], 2: [3, 1, 2, 1], 3: [4, 2, 3, 1], 4: [6, 2, 4, 2], 5: [8, 3, 6, 2]}
	for x: Variant in DataRegistry.locations():
		var loc: LocationDefinition = x
		var row: Array = want[loc.tier]
		eq([loc.decor_slot_count(&"wall"), loc.decor_slot_count(&"counter_prop"), loc.decor_slot_count(&"floor_prop"), loc.decor_slot_count(&"floor_overlay")],
			row, "tier %d decoration caps" % loc.tier)
	eq(dm.cap(&"wall"), 2, "tier 1: two wall spots")
	var a: Dictionary = dm._add(&"decor_gingham_curtains")
	var b: Dictionary = dm._add(&"decor_wall_clock_pendulum")
	var c: Dictionary = dm._add(&"decor_chalk_menu_board")
	eq(dm.place(int(a["uid"]), sf, Vector2i(-1, -1), 0), &"", "the first wall decoration takes spot 0")
	eq(dm.place(int(b["uid"]), sf, Vector2i(-1, -1), 0), &"overlap", "a spot holds one decoration")
	eq(dm.place(int(b["uid"]), sf, Vector2i(-1, -1), 2), &"invalid", "spots past the cap do not exist here")
	eq(dm.place(int(b["uid"]), sf, Vector2i(-1, -1), 1), &"", "the second takes spot 1")
	check(dm.type_full(int(c["uid"])), "the wall is full for a third one")
	eq(dm.place(int(c["uid"]), sf, Vector2i(-1, -1), 0), &"slots_full", "a third wall decoration is refused: slots full")
	eq(dm.free_slots(&"wall", int(c["uid"])), [] as Array[int], "no free spot is offered")
	eq(dm.free_slots(&"wall", int(a["uid"])), [0] as Array[int], "a placed one may only use its own spot")
	dm.put_away(int(a["uid"]))
	eq(dm.free_slots(&"wall", int(c["uid"])), [0] as Array[int], "putting one away frees its spot")
	eq(dm.place(int(c["uid"]), sf, Vector2i(-1, -1), 0), &"", "the freed spot can be used")
	# Meja kasir: satu slot di Tier 1.
	var r1: Dictionary = dm._add(&"decor_cassette_radio")
	var r2: Dictionary = dm._add(&"decor_brass_bell")
	eq(dm.place(int(r1["uid"]), sf, Vector2i(-1, -1), 0), &"", "the counter decoration takes the counter spot")
	eq(dm.place(int(r2["uid"]), sf, Vector2i(-1, -1), 0), &"slots_full", "tier 1 has one counter spot")
	# Lantai: satu dekorasi berdiri di Tier 1.
	var p1: Dictionary = dm._add(&"decor_potted_plant")
	var p2: Dictionary = dm._add(&"decor_umbrella_stand")
	var cell: Vector2i = _first_ok(s, int(p1["uid"]))
	check(cell.x >= 0, "a free shop tile exists for the plant")
	eq(dm.place(int(p1["uid"]), sf, cell, -1), &"", "the plant stands on a shop tile")
	eq(s.world.grid(sf).decor_at.get(cell, -1), int(p1["uid"]), "the plant occupies its tile")
	var cell2: Vector2i = _first_ok(s, int(p2["uid"]), cell)
	eq(cell2, Vector2i(-1, -1), "no tile accepts a second floor decoration at tier 1")
	eq(dm.check_place(int(p2["uid"]), sf, cell + Vector2i(1, 0), -1, 0), &"slots_full", "the reason is the cap")
	var moved: Vector2i = _first_ok(s, int(p1["uid"]), cell)
	if moved.x >= 0:
		eq(dm.place(int(p1["uid"]), sf, moved, -1), &"", "a placed floor decoration can still move")
	# Tier 2: batas naik, dan lantai dapur (lantai 2) tidak menerima dekorasi.
	jump_to_tier(s, 2)
	eq(dm.cap(&"wall"), 3, "tier 2: three wall spots")
	check(bool(b["placed"]) and bool(c["placed"]) and bool(r1["placed"]), "wall and counter decorations survive the move")
	eq(dm.place(int(a["uid"]), &"floor_2", Vector2i(-1, -1), 2), &"zone", "decorations stay on the shop floor")
	eq(dm.place(int(a["uid"]), s.decoration.store_floor(), Vector2i(-1, -1), 2), &"", "the new third spot is usable")
	free_sim(s)


## Ubin pertama (dari belakang) tempat `uid` boleh berdiri, selain `skip`.
func _first_ok(s: SimulationRoot, uid: int, skip: Vector2i = Vector2i(-1, -1)) -> Vector2i:
	var sf: StringName = s.decoration.store_floor()
	var fg: FloorGrid = s.world.grid(sf)
	for z in range(fg.size.y - 1, -1, -1):
		for x in fg.size.x:
			var c := Vector2i(x, z)
			if c != skip and s.decoration.check_place(uid, sf, c, -1, 0) == &"":
				return c
	return Vector2i(-1, -1)


# ===========================================================================
# KARPET
# ===========================================================================

func _rugs() -> void:
	var s: SimulationRoot = new_sim(7202)
	s.tutorial.skip()
	var dm: DecorationManager = s.decoration
	var sf: StringName = dm.store_floor()
	var fg: FloorGrid = s.world.grid(sf)
	var rug: Dictionary = dm._add(&"decor_terracotta_rug")
	var mat: Dictionary = dm._add(&"decor_floor_mat_smooth")
	var ru: int = int(rug["uid"])
	# Pintu masuk dan dapur ditolak; jalur dan antrean boleh.
	var door: Vector2i = fg.def.entrance[0]
	eq(dm.validate_overlay(ru, sf, door, 0), &"overlap", "no rug over the front door")
	var kitchen := Vector2i(-1, -1)
	for z in fg.size.y:
		for x in fg.size.x:
			if kitchen.x < 0 and fg.is_kitchen(Vector2i(x, z)) and fg.in_bounds(Vector2i(x + 1, z + 1)) and fg.is_kitchen(Vector2i(x + 1, z + 1)):
				kitchen = Vector2i(x, z)
	eq(dm.validate_overlay(ru, sf, kitchen, 0), &"zone", "rugs belong in the shop area")
	var lane: QueueLane = s.queue.main_lane()
	var on_queue := Vector2i(-1, -1)
	for q: Vector2i in lane.slots:
		for off: Vector2i in [Vector2i.ZERO, Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1)]:
			if on_queue.x < 0 and dm.validate_overlay(ru, sf, q + off, 0) == &"":
				on_queue = q + off
	check(on_queue.x >= 0, "a rug may lie over the queue")
	var nav_before: bool = s.world.layout_valid()
	eq(dm.place(ru, sf, on_queue, -1), &"", "the rug is laid")
	eq(dm.overlay_cells(rug).size(), 4, "a 2x2 rug covers four tiles")
	check(s.world.layout_valid() == nav_before and not fg.decor_at.values().has(ru), "a rug never blocks anyone")
	eq(dm.place(int(mat["uid"]), sf, _first_rug_anchor(s, int(mat["uid"])), -1), &"slots_full", "tier 1 has room for one rug")
	# Tier 4: dua karpet, putar, dan tidak saling menindih.
	jump_to_tier(s, 4)
	sf = dm.store_floor()
	fg = s.world.grid(sf)
	var mu: int = int(mat["uid"])
	var anchor: Vector2i = _first_rug_anchor(s, mu)
	check(anchor.x >= 0, "the mat fits somewhere at tier 4")
	eq(dm.place(mu, sf, anchor, -1), &"", "a second rug fits at tier 4")
	eq(DecorSlots.overlay_footprint(dm.def_of(mat), 0), Vector2i(2, 1), "the mat is 2x1")
	var before: Array[Vector2i] = dm.overlay_cells(mat)
	var turned: StringName = dm.rotate_overlay(mu)
	if turned == &"":
		eq(int(mat["rot"]), 1, "Rotate turns the mat")
		var after: Array[Vector2i] = dm.overlay_cells(mat)
		eq(after.size(), 2, "still two tiles")
		check(after[0].x == after[1].x and before[0].y == before[1].y, "2x1 turned into 1x2")
	else:
		check(false, "the placed mat could not turn (%s)" % turned)
	if bool(rug["placed"]):
		var ra: Vector2i = SimManager.arr_to_cell(rug["cell"])
		eq(dm.validate_overlay(mu, sf, ra, int(mat["rot"])), &"overlap", "rugs do not overlap")
	var loose: Dictionary = dm._add(&"decor_terracotta_rug")
	eq(dm.rotate_overlay(int(loose["uid"])), &"", "an unplaced rug remembers its turn")
	eq(int(loose["rot"]), 1, "turn stored for placing")
	free_sim(s)


func _first_rug_anchor(s: SimulationRoot, uid: int) -> Vector2i:
	var sf: StringName = s.decoration.store_floor()
	var fg: FloorGrid = s.world.grid(sf)
	var o: Dictionary = s.decoration.item(uid)
	for z in fg.size.y:
		for x in fg.size.x:
			if s.decoration.validate_overlay(uid, sf, Vector2i(x, z), int(o.get("rot", 0))) == &"":
				return Vector2i(x, z)
	return Vector2i(-1, -1)


# ===========================================================================
# SAVE LAMA & PINDAH LOKASI
# ===========================================================================

func _enforce() -> void:
	var s: SimulationRoot = new_sim(7203)
	s.tutorial.skip()
	var dm: DecorationManager = s.decoration
	var sf: StringName = dm.store_floor()
	var plant: Dictionary = dm._add(&"decor_potted_plant")
	var cell: Vector2i = _first_ok(s, int(plant["uid"]))
	var d: Dictionary = json_copy(s.capture_save())
	var base: int = int(d["decorations"]["next_uid"])
	# Save lama: slot tanpa batas, dekorasi dinding di slot yang sama, dua karpet,
	# dua dekorasi lantai, dan tanpa field "rot".
	var owned: Array = (d["decorations"]["owned"] as Array).duplicate(true)
	var rows: Array = [
		["decor_gingham_curtains", 0, [-1, -1]],        # sah
		["decor_wall_clock_pendulum", 5, [-1, -1]],     # slot di luar batas Tier 1
		["decor_chalk_menu_board", 0, [-1, -1]],        # slot 0 sudah dipakai uid lebih tua
		["decor_family_photo_wall", 1, [-1, -1]],       # sah
		["decor_cassette_radio", 0, [-1, -1]],          # sah
		["decor_brass_bell", 0, [-1, -1]],              # meja penuh
		["decor_potted_plant", -1, [cell.x, cell.y]],   # sah
		["decor_umbrella_stand", -1, [cell.x, cell.y]], # ubin sama & batas lantai
	]
	for i in rows.size():
		var r: Array = rows[i]
		owned.append({"uid": base + i, "deco_id": r[0], "placed": true, "floor_id": String(sf), "cell": r[2], "slot": r[1]})
	d["decorations"]["owned"] = owned
	d["decorations"]["next_uid"] = base + rows.size()
	var t: SimulationRoot = load_sim(json_copy(d))
	var placed: Dictionary = {}
	for o: Dictionary in t.decoration.owned:
		if int(o["uid"]) >= base:
			placed[str(o["deco_id"])] = bool(o["placed"])
	eq(placed, {"decor_gingham_curtains": true, "decor_wall_clock_pendulum": false, "decor_chalk_menu_board": false,
		"decor_family_photo_wall": true, "decor_cassette_radio": true, "decor_brass_bell": false,
		"decor_potted_plant": true, "decor_umbrella_stand": false}, "after loading, only decorations that fit the tier 1 rules stay up")
	eq(t.world.grid(sf).decor_at.get(cell, -1), base + 6, "the older plant keeps its tile")
	# Idempoten: save -> load berikutnya tidak mengubah apa pun lagi.
	var again: SimulationRoot = load_sim(json_copy(t.capture_save()))
	same_state(logical_state(again.capture_save()), logical_state(t.capture_save()), "a cleaned save loads unchanged")
	free_sim(again)
	# Dekorasi di lantai dapur (Tier 2) kembali ke inventaris saat load.
	jump_to_tier(t, 2)
	var d2: Dictionary = json_copy(t.capture_save())
	var owned2: Array = d2["decorations"]["owned"]
	for o2: Variant in owned2:
		if str((o2 as Dictionary)["deco_id"]) == "decor_gingham_curtains":
			(o2 as Dictionary)["floor_id"] = "floor_2"
	var t2: SimulationRoot = load_sim(d2)
	for o3: Dictionary in t2.decoration.owned:
		if str(o3["deco_id"]) == "decor_gingham_curtains" and int(o3["uid"]) >= base:
			check(not bool(o3["placed"]), "a decoration saved on the kitchen floor goes back to the inventory")
		if str(o3["deco_id"]) == "decor_family_photo_wall" and int(o3["uid"]) >= base:
			check(bool(o3["placed"]) and int(o3["slot"]) == 1, "a valid wall decoration keeps its spot after moving shop")
	free_sim(t2)
	free_sim(t)
	free_sim(s)


# ===========================================================================
# MODEL
# ===========================================================================

func _models() -> void:
	var seen: int = 0
	for x: Variant in DataRegistry.decorations():
		var def: MiscDefinitions.DecorationDefinition = x
		if not def.is_placeable():
			continue
		seen += 1
		check(DecorFactory.has_model(def.visual_profile_id), "%s has a model" % def.id)
		var n: Node3D = DecorFactory.build(def.id)
		var tris: int = ProceduralMeshFactory.tri_count(n)
		check(tris >= 40 and tris <= DecorFactory.MAX_TRIS, "%s: %d triangles within the budget" % [def.id, tris])
		var b: AABB = EquipmentFactory._mesh_bounds(n)
		match def.placement_type:
			&"wall":
				check(b.end.z <= 0.01 and b.position.z >= -0.4, "%s stands off the wall into the room" % def.id)
				check(b.size.x <= DecorSlots.WALL_SLOT_WIDTH + 0.06 and b.size.y <= 0.7, "%s fits its wall spot (%s)" % [def.id, b.size])
			&"counter_prop":
				check(b.position.y >= -0.006 and b.size.x <= 0.28 and b.size.z <= 0.18 and b.size.y <= 0.3, "%s fits the counter end (%s)" % [def.id, b.size])
			&"floor_prop":
				check(b.position.y >= -0.001 and b.size.x <= 0.46 and b.size.z <= 0.46 and b.size.y <= 1.0, "%s fits its tile (%s)" % [def.id, b.size])
			&"floor_overlay":
				var fp: Vector2 = Vector2(def.overlay_size_tiles) * T
				check(absf(b.size.x - fp.x) <= 0.07 and absf(b.size.z - fp.y) <= 0.07 and b.size.y <= 0.012, "%s covers its footprint flat (%s)" % [def.id, b.size])
		n.free()
	eq(seen, 25, "all 25 placeable decorations (including the two achievement badges) were checked")
	var clock: Node3D = DecorFactory.build(&"decor_wall_clock_pendulum")
	check(clock.find_child(DecorFactory.SWING_NODE, true, false) != null, "the pendulum clock has a pendulum to swing")
	clock.free()
	var lamp: Node3D = DecorFactory.build(&"decor_hanging_lamp_warm")
	var bulb: MeshInstance3D = lamp.find_child("Bulb", true, false) as MeshInstance3D
	check(bulb != null and ProceduralMeshFactory.material_of(bulb).emission_enabled, "the warm lamp's bulb glows")
	lamp.free()
	var jar: Node3D = DecorFactory.build(&"decor_gold_coin_jar")
	var glass: MeshInstance3D = jar.find_child("Glass", true, false) as MeshInstance3D
	check(glass != null and (glass.material_override as StandardMaterial3D).transparency == BaseMaterial3D.TRANSPARENCY_ALPHA, "the coin jar glass is see-through")
	jar.free()
	var t2: int = ProceduralMeshFactory.tri_count(_tmp(&"decor_plaque_tier2"))
	var t3: int = ProceduralMeshFactory.tri_count(_tmp(&"decor_plaque_tier3"))
	check(t3 > t2, "the tier 3 plaque carries more stars than the tier 2 one")
	# Salinan cache berbagi mesh dengan prototipe.
	var c1: Node3D = DecorFactory.build_cached(&"decor_potted_plant")
	var c2: Node3D = DecorFactory.build_cached(&"decor_potted_plant")
	check((c1.get_child(0) as MeshInstance3D).mesh == (c2.get_child(0) as MeshInstance3D).mesh, "placed copies share one mesh")
	c1.free()
	c2.free()


func _tmp(id: StringName) -> Node3D:
	var n: Node3D = DecorFactory.build(id)
	n.queue_free()
	return n


# ===========================================================================
# DUNIA
# ===========================================================================

func _world() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(7204)
	s.tutorial.skip()
	jump_to_tier(s, 3)
	var dm: DecorationManager = s.decoration
	var sf: StringName = dm.store_floor()
	var wall: Dictionary = dm._add(&"decor_wall_clock_pendulum")
	var counter: Dictionary = dm._add(&"decor_trophy_millionaire")
	var plant: Dictionary = dm._add(&"decor_potted_plant")
	var rug: Dictionary = dm._add(&"decor_terracotta_rug")
	eq(dm.place(int(wall["uid"]), sf, Vector2i(-1, -1), 0), &"", "wall decoration placed")
	eq(dm.place(int(counter["uid"]), sf, Vector2i(-1, -1), 1), &"", "counter decoration placed")
	eq(dm.place(int(plant["uid"]), sf, _first_ok(s, int(plant["uid"])), -1), &"", "floor decoration placed")
	eq(dm.place(int(rug["uid"]), sf, _first_rug_anchor(s, int(rug["uid"])), -1), &"", "rug placed")
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	await runner.get_tree().process_frame
	eq(world._decor.size(), 4, "every placed decoration is drawn")
	var loc: LocationDefinition = s.world.location
	for o: Dictionary in [wall, counter, plant, rug]:
		var node: Node3D = world.decor_node(int(o["uid"]))
		check(node != null and node.get_parent() == world.floors[sf], "%s hangs in the shop floor scene" % o["deco_id"])
		if node != null:
			var xf: Transform3D = DecorSlots.transform_of(loc, dm.def_of(o), o)
			check(node.transform.origin.distance_to(xf.origin) < 0.001, "%s sits where its slot says" % o["deco_id"])
	# Decoration Mode: kamera pindah ke lantai toko (pemain Tier 3 mulai di dapur
	# lantai 2), lalu dekorasi bisa diketuk.
	world.decoration_mode = true
	world.view_floor_override = sf
	for i in 3:
		await runner.get_tree().process_frame
	eq(world.camera_rig.active_floor, sf, "the camera shows the shop floor")
	var rig: CameraRig = world.camera_rig
	rig.set_floor_bounds(Vector2(world.sim.world.grid(sf).size) * T)
	rig.snap_to(Vector3(2.0, 0.0, 3.0))
	var wall_aabb: AABB = world._decor[int(wall["uid"])]["aabb"]
	# Titik atas dekorasi: sinar dari kamera melewati perabot di depannya.
	var wall_top := Vector3(wall_aabb.get_center().x, wall_aabb.end.y - 0.03, wall_aabb.get_center().z)
	var pk: Dictionary = world.pick(rig.world_to_screen(wall_top))
	eq([pk.get("kind"), pk.get("uid")], [&"decor", int(wall["uid"])], "tapping the wall decoration picks it")
	var rc: Vector2i = dm.overlay_cells(rug)[0]
	var pr: Dictionary = world.pick(rig.world_to_screen(GridMath.cell_center3(rc)))
	if pr.get("kind") == &"decor":
		eq(pr.get("uid"), int(rug["uid"]), "tapping a rug tile picks the rug")
		check(pr.has("cell"), "the rug pick keeps the tile for placement taps")
	world.decoration_mode = false
	var pn: Dictionary = world.pick(rig.world_to_screen(wall_top))
	check(pn.get("kind") != &"decor", "outside Decoration Mode decorations are not buttons")
	# Penanda slot.
	world.show_slot_markers(&"wall", [1, 2] as Array[int], -1)
	eq(world.slot_marker_count(), 2, "two free wall spots are marked")
	eq(world.slot_at_screen(world.slot_screen_pos(2)), 2, "a tap on a marker finds its spot")
	eq(world.slot_at_screen(Vector2(-500, -500)), -1, "a tap far away finds nothing")
	world.clear_slot_markers()
	await runner.get_tree().process_frame
	eq(world.slot_marker_count(), 0, "markers clear")
	# Bandul berayun (kecuali Reduced Motion).
	var pend: Node3D = world.decor_node(int(wall["uid"])).find_child(DecorFactory.SWING_NODE, true, false) as Node3D
	world._t = 0.5
	world._animate_swing()
	if not SettingsManager.reduced_motion():
		check(absf(pend.rotation.z) > 0.01, "the pendulum swings")
	# Jendela kanan & jam dinding bawaan menghadap ruangan.
	var room: Node3D = world.floors[sf]
	var clock: Node3D = room.find_child("WallClock", true, false) as Node3D
	check(clock != null and absf(absf(clock.rotation_degrees.y) - 180.0) < 0.01, "the room clock faces into the room")
	var right_ok: bool = true
	var right_seen: int = 0
	var fw: float = float(loc.floor_def(sf).size.x) * T
	for n: Node in room.get_children():
		# Jendela = Node3D polos di muka dalam dinding kanan (nama kembarnya diganti
		# Godot menjadi "@Node3D@..").
		if n.get_class() == "Node3D" and absf((n as Node3D).position.x - (fw - 0.01)) < 0.001:
			right_seen += 1
			right_ok = right_ok and absf((n as Node3D).rotation_degrees.y - 90.0) < 0.01
	check(right_seen > 0 and right_ok, "right-wall windows show their glass and curtains to the room")
	# Kantong belanja di samping mesin kasir, bukan di dalamnya (meja dua ubin).
	var lane: QueueLane = s.queue.main_lane()
	var bag: PackBagRig = world._build_pack_bag(lane)
	var f: FloorDefinition = loc.floor_def(lane.floor_id)
	var fr: Dictionary = DecorSlots.counter_frame(f, f.counter(lane.counter_id))
	near(Vector2(bag.position.x, bag.position.z).distance_to(Vector2(fr["center"])), sqrt(WorldView.PACK_BAG_SIDE * WorldView.PACK_BAG_SIDE + 0.04 * 0.04), 0.001,
		"the paper bag stands beside the register in the middle of the counter")
	bag.free()
	# Simpan: node hilang setelah tata letak dibangun ulang.
	dm.put_away(int(plant["uid"]))
	await runner.get_tree().process_frame
	check(world.decor_node(int(plant["uid"])) == null, "a decoration put away disappears")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


# ===========================================================================
# UI
# ===========================================================================

func _ui() -> void:
	SaveManager.dir = "user://test_saves_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Decor Test")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	var dm: DecorationManager = game.sim.decoration
	var a: Dictionary = dm._add(&"decor_gingham_curtains")
	var b: Dictionary = dm._add(&"decor_wall_clock_pendulum")
	var c: Dictionary = dm._add(&"decor_chalk_menu_board")
	var rug: Dictionary = dm._add(&"decor_terracotta_rug")
	var deco: DecorationScreen = game.modals.open(&"decoration", {})
	await runner.get_tree().process_frame
	var world: WorldView = game.world
	# Ringkasan slot di baki "Your Decorations".
	deco._set_tab(DecorationScreen.TAB_OWNED)
	await runner.get_tree().process_frame
	var usage: Control = deco._tray_row.find_child("SlotUsage", true, false) as Control
	check(usage != null, "the tray shows how many spots this shop has")
	if usage != null:
		var lines: PackedStringArray = PackedStringArray()
		for l: Node in usage.find_children("*", "Label", true, false):
			lines.append((l as Label).text)
		check(lines.has(Tx.t("ui_decor_slot_count", {"type": Tx.t("decor_type_wall"), "used": 0, "max": 2})), "the wall count reads 0/2 (%s)" % ", ".join(lines))
	# Angkat dekorasi dinding: slot bebas menyala dan ia mencoba slot bebas pertama.
	deco._pick_decor_card(int(a["uid"]))
	await runner.get_tree().process_frame
	eq(world.slot_marker_count(), 2, "both free wall spots light up")
	eq(world.lifted_decor(), int(a["uid"]), "the decoration is held")
	eq(int(world.held()["slot"]), 0, "a new decoration first tries the first free spot")
	check(world.hold_node() != null and world.hold_node().visible, "and shows on the wall there")
	eq(deco._status.text, Tx.t("ui_decor_slot_hint_wall"), "the hint says to tap a glowing spot, then Place")
	check(not deco._tb_rotate.visible, "wall decorations do not rotate")
	check(not deco._tb_store.visible, "nothing to put away before it hangs")
	deco._on_world_tap(world.slot_screen_pos(1))
	await runner.get_tree().process_frame
	eq(int(world.held()["slot"]), 1, "tapping spot 1 tries the decoration there")
	check(not bool(a["placed"]), "it is not hung before Place")
	deco._on_world_tap(world.slot_screen_pos(1))
	check(deco.has_selection(), "tapping its own spot again does not drop it")
	deco._place()
	await runner.get_tree().process_frame
	check(bool(a["placed"]) and int(a["slot"]) == 1, "Place hangs the decoration on spot 1")
	check(world.decor_node(int(a["uid"])) != null, "and it appears on the wall")
	check(not deco.has_selection(), "Place lets go of it")
	deco._hold_decor(int(b["uid"]))
	eq(world.slot_marker_count(), 1, "only the remaining spot lights up")
	eq(int(world.held()["slot"]), 0, "the second decoration tries spot 0")
	deco._place()
	check(bool(b["placed"]) and int(b["slot"]) == 0, "the second decoration takes spot 0")
	# Jenis penuh: tidak diangkat; peringatan menyebut batas toko.
	deco._hold_decor(int(c["uid"]))
	await runner.get_tree().process_frame
	check(not deco.has_selection(), "a decoration of a full type is not picked up")
	eq(world.slot_marker_count(), 0, "no spot lights up when the wall is full")
	check(deco._warn.visible, "the warning banner explains why")
	eq(deco._warn_detail.text, Tx.t("ui_decor_slots_full", {"type": Tx.t("decor_type_wall"), "count": 2}), "it names the cap of this shop")
	eq(deco._warn_title.text, Tx.t("ui_decor_full_title"), "with a 'no free spot' title")
	check(not bool(c["placed"]), "nothing was hung")
	# Mengetuk dekorasi di dunia mengangkatnya; Put Away menyimpannya.
	var ab: AABB = world._decor[int(a["uid"])]["aabb"]
	deco._on_world_tap(world.camera_rig.world_to_screen(Vector3(ab.get_center().x, ab.end.y - 0.03, ab.get_center().z)))
	eq(deco._sel_decor, int(a["uid"]), "tapping a hanging decoration picks it up")
	eq(world.lifted_decor(), int(a["uid"]), "the held decoration lifts")
	check(deco._tb_store.visible, "Put Away is offered once it hangs")
	deco._put_away()
	check(not bool(a["placed"]) and not deco.has_selection(), "Put Away takes it down")
	# Karpet: muncul di ubin toko yang sah, Rotate hanya pratinjau sampai Place.
	deco._hold_decor(int(rug["uid"]))
	check(deco._tb_rotate.visible, "rugs can be rotated")
	eq(deco._status.text, Tx.t("ui_decor_rug_hint"), "the rug hint shows")
	eq(deco._cand_reason, &"", "a new rug appears on a free shop tile")
	deco._rotate()
	eq(int(world.held()["rot"]), 1, "Rotate turns the held rug")
	eq(int(rug["rot"]), 0, "the turn is only a preview until Place")
	var anchor: Vector2i = Vector2i(-1, -1)
	var fg: FloorGrid = game.sim.world.grid(dm.store_floor())
	for z in fg.size.y:
		for x in fg.size.x:
			if anchor.x < 0 and dm.check_place(int(rug["uid"]), dm.store_floor(), Vector2i(x, z), -1, 1) == &"":
				anchor = Vector2i(x, z)
	check(anchor.x >= 0, "the turned rug fits somewhere in the shop")
	deco._on_world_tap(world.camera_rig.world_to_screen(GridMath.cell_center3(anchor)))
	await runner.get_tree().process_frame
	eq(Vector2i(world.held()["cell"]), anchor, "tapping a shop tile moves the rug there")
	check(not bool(rug["placed"]), "and does not lay it yet")
	deco._place()
	check(bool(rug["placed"]) and int(rug["rot"]) == 1 and SimManager.arr_to_cell(rug["cell"]) == anchor, "Place lays the rug, turned")
	game.modals.close_all()
	await runner.get_tree().process_frame
	eq(world.slot_marker_count(), 0, "markers are gone after Decoration Mode")
	eq(world.lifted_decor(), -1, "nothing stays lifted")
	game.return_to_menu()
	await runner.get_tree().process_frame
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"


# ===========================================================================
# BADGE ACHIEVEMENT (keputusan maintainer 2026-10-01)
# ===========================================================================

func _badges() -> void:
	# Katalog: setiap badge adalah dekorasi dinding hadiah achievement berikon.
	var badges: Array[StringName] = []
	for x: Variant in DataRegistry.decorations():
		var d: MiscDefinitions.DecorationDefinition = x
		if d.is_badge():
			badges.append(d.id)
			eq(d.placement_type, &"wall", "%s hangs on a wall spot" % d.id)
			eq(d.source, &"achievement", "%s comes from an achievement" % d.id)
			check(IconCanvas.NAMES.has(String(d.badge_icon)), "%s has a profile medal icon" % d.id)
			check(DecorFactory.has_model(d.visual_profile_id), "%s has its own model" % d.id)
	check(badges.has(&"badge_first_crumb") and badges.has(&"badge_first_savings"), "both achievement badges are badges")
	var rewards: int = 0
	for y: Variant in DataRegistry.achievements():
		var ach: MiscDefinitions.AchievementDefinition = y
		if badges.has(ach.reward_id):
			rewards += 1
	eq(rewards, badges.size(), "every badge is an achievement reward")
	# Didapat dari achievement: masuk inventaris, belum terpasang, tidak "dipakai".
	var s: SimulationRoot = new_sim(7202)
	var dm: DecorationManager = s.decoration
	dm.grant(&"badge_first_crumb")
	var o: Dictionary = {}
	for it: Dictionary in dm.owned:
		if StringName(str(it["deco_id"])) == &"badge_first_crumb":
			o = it
	check(not o.is_empty() and not bool(o["placed"]), "the badge waits in the inventory")
	check(not dm.equipped.has("badge"), "badges are not equipped any more, they are placed")
	check(not dm.type_full(int(o["uid"])), "a free wall spot is available at Tier 1")
	var sf: StringName = dm.store_floor()
	eq(dm.place(int(o["uid"]), sf, Vector2i(-1, -1), 0), &"", "the badge hangs on wall spot 0")
	eq(dm.placed_of_type(&"wall"), 1, "it uses one of the shop's wall spots")
	var curtains: Dictionary = dm._add(&"decor_gingham_curtains")
	eq(dm.place(int(curtains["uid"]), sf, Vector2i(-1, -1), 0), &"overlap", "it shares the wall spots with other wall decorations")
	# Save lama yang masih mencatat badge sebagai "dipakai".
	var saved: Dictionary = dm.capture()
	saved["equipped"] = {"badge": "badge_first_crumb"}
	dm.restore(saved)
	check(not dm.equipped.has("badge"), "an old save's equipped badge entry is dropped")
	# Kartu profil: medali untuk setiap badge yang sudah didapat.
	SaveManager.dir = "user://test_saves_badges"
	SaveManager.write_profile(&"profile_1", s.capture_save())
	var h: Dictionary = SaveManager.read_header(&"profile_1")
	eq(h.get("badges", []), ["badge_first_crumb"] as Array[String], "the profile header lists the earned badge")
	var row: Control = ProfileScreen.badge_row(h["badges"])
	check(row != null and row.get_child_count() == 1, "the profile card shows one medal")
	if row != null:
		check(row.get_child(0).tooltip_text == Tx.t("badge_first_crumb"), "the medal is named by its tooltip")
		row.free()
	check(ProfileScreen.badge_row([]) == null, "no medal row without badges")
	SaveManager.delete_profile(&"profile_1")
	SaveManager.dir = "user://saves"
	free_sim(s)


# ===========================================================================
# KASIR TIER 2 & 4
# ===========================================================================

func _cashier_perks() -> void:
	var t1: StaffDefinition = DataRegistry.staff(&"staff_cashier_budi")
	var t2: StaffDefinition = DataRegistry.staff(&"staff_cashier_nadia")
	var t3: StaffDefinition = DataRegistry.staff(&"staff_cashier_maya")
	var t4: StaffDefinition = DataRegistry.staff(&"staff_cashier_hendra")
	var t5: StaffDefinition = DataRegistry.staff(&"staff_cashier_grace")
	near(t2.special_value("queue_patience_drain_multiplier", 1.0), 0.92, 0.0001, "tier 2: the queue is 8% more patient")
	near(t4.special_value("queue_patience_drain_multiplier", 1.0), 0.85, 0.0001, "tier 4: the queue is 15% more patient")
	near(t4.special_value("sale_rating_multiplier", 1.0), 1.5, 0.0001, "tier 4: each sale lifts the rating 1.5x")
	check(t1.special.is_empty(), "tier 1 unchanged: no perk")
	near(t3.special_value("queue_patience_drain_multiplier", 1.0), 0.85, 0.0001, "tier 3 unchanged")
	near(t5.special_value("physical_tip_chance", 0.0), 0.05, 0.0001, "tier 5 unchanged: 5% tips")
	eq(StaffScreen.perk_lines(t1).size(), 0, "a tier 1 card lists no perk")
	eq(StaffScreen.perk_lines(t2), PackedStringArray([Tx.t("staff_special_queue", {"percent": 8})]), "a tier 2 card explains the calmer queue")
	eq(StaffScreen.perk_lines(t4), PackedStringArray([Tx.t("staff_special_queue", {"percent": 15}), Tx.t("staff_special_rating", {"percent": 50})]),
		"a tier 4 card lists both perks")
	# Kesabaran antrean: pengurasan dasar dikali perk kasir di lane itu.
	var s: SimulationRoot = new_sim(301)
	s.tutorial.skip()
	s.debug_set_time(s.time.open_time + 60.0)
	var lane: QueueLane = s.queue.main_lane()
	check(s.debug_spawn_customer(&"customer_generic"), "a customer arrives")
	var c: Customer = s.customers.sorted()[0]
	c.lane_id = lane.id
	var drain := func() -> float:
		c.patience = c.patience_max
		c.stall_time = 0.0
		s.customers._drain(c, 1.0)
		return c.patience_max - c.patience
	var base: float = drain.call()
	check(base > 0.0, "patience drains while waiting")
	s.staff.lane_assign[&"staff_cashier_nadia"] = lane.id
	near(drain.call(), base * 0.92, 0.0001, "a tier 2 cashier's lane drains 8% slower")
	s.staff.lane_assign.clear()
	s.staff.lane_assign[&"staff_cashier_hendra"] = lane.id
	near(drain.call(), base * 0.85, 0.0001, "a tier 4 cashier's lane drains 15% slower")
	s.staff.lane_assign.clear()
	free_sim(s)
	# Rating per penjualan: dua simulasi kembar sampai transaksi pertama.
	var deltas: Array[float] = []
	for staffed: bool in [false, true]:
		var u: SimulationRoot = new_sim(3401)
		PauseManager.clear_all()
		var ln: QueueLane = u.queue.main_lane()
		var bot := SimBot.new(u)
		var guard: int = 0
		while guard < 400000 and u.cashier.transaction_for(ln.id).is_empty() and u.is_running():
			bot.think()
			u.step(u.tick_seconds)
			guard += 1
		var td: Dictionary = u.cashier.transaction_for(ln.id)
		if td.is_empty():
			check(false, "a checkout started")
			free_sim(u)
			return
		var cust: Customer = u.customers.customer(td["customer"])
		for lot: Variant in cust.held:
			var st: BreadStack = (lot as Dictionary)["stack"]
			st.bake_quality = 1.0
			st.freshness_state = &"FRESH"
		if staffed:
			u.staff.lane_assign[&"staff_cashier_hendra"] = ln.id
		u.cashier.transactions.erase(ln.id)
		var r0: float = u.reputation.physical
		u.cashier._complete(cust, ln, staffed)
		deltas.append(u.reputation.physical - r0)
		u.staff.lane_assign.clear()
		free_sim(u)
	check(deltas[0] > 0.0, "a good sale lifts the rating (%.4f)" % deltas[0])
	near(deltas[1], deltas[0] * 1.5, 0.00001, "a tier 4 cashier's sale lifts it 1.5x as much")
