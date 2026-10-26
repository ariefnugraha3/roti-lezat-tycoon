extends TestSuite
## Kedip sorotan tutorial (keputusan maintainer 2026-10-06, GDD 27.5, 88.1):
## alat atau perabot yang harus diketuk pada langkah tutorial berkedip terang,
## supaya pemain tahu apa yang harus diketuk.


func tests() -> Array:
	return [
		{"id": "ACC_27_TUTORIAL_BLINK", "name": "27.5 the station an onboarding hint points at blinks bright (storage, mixer, oven, display, the cashier counter, the RotiFood tablet); the blink moves with the hint and stops when it ends", "fn": _blink},
		{"id": "ACC_27_TUTORIAL_BLINK_CHEAP", "name": "27.5, 89.5 the blink beats about once a second, holds a steady glow with Reduced Motion, reuses the tile-overlay shader, is warmed at loading and survives a furniture rebuild", "fn": _cheap},
	]


func _meshes(root: Node) -> Array[MeshInstance3D]:
	var out: Array[MeshInstance3D] = []
	if root is MeshInstance3D:
		out.append(root)
	for n: Node in root.find_children("*", "MeshInstance3D", true, false):
		out.append(n as MeshInstance3D)
	return out


## Semua mesh di bawah `root` memakai kilau kedip.
func _lit(root: Node) -> bool:
	var list: Array[MeshInstance3D] = _meshes(root)
	if list.is_empty():
		return false
	for mi: MeshInstance3D in list:
		if mi.material_overlay != ProceduralMeshFactory.flash_material():
			return false
	return true


## Jumlah mesh di dunia yang memakai kilau kedip.
func _count_lit(world: WorldView) -> int:
	var n: int = 0
	for mi: MeshInstance3D in _meshes(world):
		if mi.material_overlay == ProceduralMeshFactory.flash_material():
			n += 1
	return n


func _blink() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(6701)
	s.tutorial.skip()
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	eq(_count_lit(world), 0, "nothing blinks without a hint")
	# Setiap jenis sasaran yang bisa disorot langkah onboarding: hanya sasaran itu
	# yang berkedip, dan kedipnya pindah bersama langkah.
	var lit_before: Node3D = null
	for cat: StringName in [&"storage", &"mixer", &"oven", &"display"]:
		var iid: int = s.equipment.placed_list(cat)[0].iid
		var node: Node3D = world.furniture.get(iid)
		world.highlight(cat, iid)
		world._process(0.016)
		check(world.blink_target() == node and _lit(node), "the %s blinks" % cat)
		eq(_count_lit(world), _meshes(node).size(), "and nothing else while the %s blinks" % cat)
		if lit_before != null:
			check(not _lit(lit_before), "the previous target stops when the %s takes over" % cat)
		lit_before = node
	world.highlight(&"cashier", -1)
	world._process(0.016)
	var counter: Node3D = world.blink_target()
	var lane: QueueLane = s.queue.main_lane()
	check(counter != null and String(counter.name) == "Counter_%s" % lane.counter_id, "the owner's counter blinks")
	check(counter != null and _lit(counter), "all of the counter")
	world.highlight(&"tablet", -1)
	world._process(0.016)
	var tablet: Node3D = world.blink_target()
	check(tablet != null and String(tablet.name) == "Tablet" and _lit(tablet), "the RotiFood tablet blinks")
	check(counter == null or not _lit(counter), "the counter stops")
	# Petunjuk selesai.
	world.highlight(&"", -1)
	world._process(0.016)
	eq(_count_lit(world), 0, "when the hint ends nothing blinks")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


func _cheap() -> void:
	PauseManager.clear_all()
	var was_rm: Variant = SettingsManager.values.get("reduced_motion", false)
	SettingsManager.values["reduced_motion"] = false
	# Satu ketukan: gelap, paling terang di tengah, gelap lagi.
	var period: float = WorldView.BLINK_PERIOD
	check(period >= 0.6 and period <= 1.5, "about one blink a second (%.2f s), never a fast flicker" % period)
	near(WorldView.blink_alpha(0.0, false), 0.0, 0.0001, "a beat starts dark")
	near(WorldView.blink_alpha(period * 0.5, false), WorldView.BLINK_PEAK, 0.0001, "and is brightest half-way")
	near(WorldView.blink_alpha(period, false), 0.0, 0.0001, "dark again a beat later")
	check(WorldView.BLINK_PEAK >= 0.5, "bright at its peak (%.2f)" % WorldView.BLINK_PEAK)
	# Material: shader arsiran ubin, instans sendiri.
	var flash: StandardMaterial3D = ProceduralMeshFactory.flash_material()
	eq(MaterialKeep.key_of(flash), MaterialKeep.key_of(ProceduralMeshFactory.overlay_material()),
		"the blink uses the tile-overlay shader, so no new shader compiles")
	check(flash != ProceduralMeshFactory.overlay_material(), "but a material of its own, so tile overlays never blink")
	check(flash.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED, "unshaded, never a lit transparent material")
	var s: SimulationRoot = new_sim(6702)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	# Pemanasan loading menggambar contoh yang berkedip.
	var w: ShaderWarmup = ShaderWarmup.start(world)
	var warm: int = 0
	for mi: MeshInstance3D in _meshes(w):
		if mi.material_overlay == flash:
			warm += 1
	check(warm > 0, "the loading warm-up draws a blinking sample (%d parts)" % warm)
	w.finish()
	await runner.get_tree().process_frame
	# Di dunia, alfa kilau mengikuti ketukan; Reduced Motion menyala tetap.
	var iid: int = s.equipment.placed_list(&"mixer")[0].iid
	world.highlight(&"mixer", iid)
	near(flash.albedo_color.a, 0.0, 0.0001, "the blink starts dark")
	world._process(period * 0.5)
	near(flash.albedo_color.a, WorldView.BLINK_PEAK, 0.01, "half a beat later it is at its brightest")
	world._process(period * 0.5)
	near(flash.albedo_color.a, 0.0, 0.01, "and dark again a beat later")
	SettingsManager.values["reduced_motion"] = true
	world._process(0.2)
	var a1: float = flash.albedo_color.a
	world._process(0.3)
	near(a1, WorldView.BLINK_STEADY, 0.0001, "Reduced Motion: a steady glow")
	near(flash.albedo_color.a, a1, 0.0001, "that does not blink")
	SettingsManager.values["reduced_motion"] = false
	# Perabot dibangun ulang (mis. sesudah Decoration Mode): kilau ikut pindah.
	var old: Node3D = world.furniture[iid]
	world.rebuild_furniture()
	world._process(0.016)
	var fresh: Node3D = world.furniture[iid]
	check(fresh != old and _lit(fresh), "a rebuilt mixer keeps blinking")
	world.highlight(&"", -1)
	world._process(0.016)
	eq(_count_lit(world), 0, "and stops when the hint ends")
	SettingsManager.values["reduced_motion"] = was_rm
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
