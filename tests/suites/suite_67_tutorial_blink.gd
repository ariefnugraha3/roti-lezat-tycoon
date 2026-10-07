extends TestSuite
## Kedip sorotan tutorial (keputusan maintainer 2026-10-06, GDD 27.5, 88.1):
## alat atau perabot yang harus diketuk pada langkah tutorial berkedip terang,
## supaya pemain tahu apa yang harus diketuk.


func tests() -> Array:
	return [
		{"id": "ACC_27_TUTORIAL_BLINK", "name": "27.5 the station a tutorial step asks the player to tap blinks bright (storage, mixer, oven, display, the cashier counter, the RotiFood tablet); the blink moves with the steps and stops when the hint ends", "fn": _blink},
		{"id": "ACC_27_TUTORIAL_BLINK_CHEAP", "name": "27.5, 89.5 the blink beats about once a second, holds a steady glow with Reduced Motion, reuses the tile-overlay shader, is warmed at loading and survives a furniture rebuild", "fn": _cheap},
	]


## Seperti GameRoot._show_tutorial_prompt: sorot sasaran prompt tutorial.
func _follow(world: WorldView, s: SimulationRoot) -> void:
	var p: Dictionary = s.tutorial.prompt
	world.highlight(StringName(str(p.get("highlight_kind", ""))), int(p.get("highlight_iid", -1)))
	world._process(0.016)


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
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	var storage: Node3D = world.furniture.get(s.equipment.placed_list(&"storage")[0].iid)
	var mixer: Node3D = world.furniture.get(s.equipment.placed_list(&"mixer")[0].iid)
	# Hari 1: setelah sambutan, tutorial meminta pemain mengetuk Storage.
	eq(str(s.tutorial.prompt.get("key", "")), "tut_welcome", "Day 1 starts with the welcome")
	s.tutorial.dismiss()
	eq(str(s.tutorial.prompt.get("key", "")), "tut_tap_storage", "then asks for the storage")
	_follow(world, s)
	check(world.blink_target() == storage, "the storage blinks")
	check(_lit(storage), "all of it")
	eq(_count_lit(world), _meshes(storage).size(), "and nothing else")
	# Langkah berikutnya: Mixer. Storage berhenti berkedip.
	s.tutorial.on_event(&"storage_opened")
	s.tutorial.on_event(&"recipe_ordered")
	eq(str(s.tutorial.prompt.get("key", "")), "tut_tap_mixer", "after the recipe it asks for the mixer")
	_follow(world, s)
	check(world.blink_target() == mixer and _lit(mixer), "the mixer blinks")
	eq(_count_lit(world), _meshes(mixer).size(), "the storage stops")
	# Petunjuk tanpa sasaran: tidak ada yang berkedip.
	s.tutorial.on_event(&"mixing_started")
	eq(str(s.tutorial.prompt.get("key", "")), "tut_equipment_works", "while mixing it only explains")
	_follow(world, s)
	eq(world.blink_target(), null, "so nothing blinks")
	eq(_count_lit(world), 0, "and no part keeps the glow")
	s.tutorial.on_event(&"mixer_done")
	_follow(world, s)
	check(world.blink_target() == mixer and _lit(mixer), "the finished mixer blinks for pickup")
	s.tutorial.on_event(&"dough_picked")
	eq(str(s.tutorial.prompt.get("key", "")), "tut_to_oven", "then the oven")
	_follow(world, s)
	var oven: Node3D = world.furniture.get(s.equipment.placed_list(&"oven")[0].iid)
	check(world.blink_target() == oven and _lit(oven), "the oven blinks")
	# Sasaran lain yang dipakai tutorial: rak, meja kasir jalur utama, tablet.
	var display_iid: int = s.equipment.placed_list(&"display")[0].iid
	world.highlight(&"display", display_iid)
	world._process(0.016)
	check(world.blink_target() == world.furniture[display_iid] and _lit(world.furniture[display_iid]), "the display blinks for the slot picker")
	world.highlight(&"cashier", -1)
	world._process(0.016)
	var counter: Node3D = world.blink_target()
	var lane: QueueLane = s.queue.main_lane()
	check(counter != null and String(counter.name) == "Counter_%s" % lane.counter_id, "the main lane's counter blinks for manual service")
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
