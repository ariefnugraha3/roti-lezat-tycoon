extends TestSuite
## Macet di browser (laporan 2026-10-01): mengetuk perabot dan memilih barang di
## Decoration Mode menahan layar 0,2 detik sampai lebih dari 5 detik. Penyebabnya
## shader WebGL yang dikompilasi di tengah permainan (dan dikompilasi ULANG setiap
## kali material sementara dibuat baru) serta bunyi yang disintesis saat pertama
## dibunyikan. Tes ini memeriksa ketiga perbaikannya (GDD 33.6, 89.5).


func tests() -> Array:
	return [
		{"id": "ACC_89_SHADER_WARMUP", "name": "89.5 loading draws one of every late-appearing visual below the floor, keeps one material per shader combination, and leaves nothing behind", "fn": _warmup},
		{"id": "ACC_89_SHARED_HELPER_MATERIALS", "name": "89.5 placement ghosts and tile overlays reuse shared materials, so moving a held piece never needs a new shader", "fn": _shared_materials},
		{"id": "ACC_33_SOUNDS_PREBUILT", "name": "33.6 the menu and the loading screen build every short sound, so tapping furniture never synthesizes audio", "fn": _sounds},
		{"id": "ACC_89_FEW_SHADERS", "name": "89.5 the whole game uses a dozen shader combinations and no lit transparent one; bread shares the furniture shader and thin glass the overlay shader", "fn": _few_shaders},
	]


func _boot(warmup: bool) -> GameRoot:
	SaveManager.dir = "user://test_saves_web_hitches"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.shader_warmup = warmup
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Warmup Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	return game


func _finish(game: GameRoot) -> void:
	game.modals.close_all()
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


## Semua node keturunan `root` dengan nama yang diawali `prefix`.
func _named(root: Node, prefix: String) -> Array[Node]:
	var out: Array[Node] = []
	for n: Node in root.find_children(prefix + "*", "", true, false):
		out.append(n)
	return out


func _warmup() -> void:
	MaterialKeep.clear()
	var game: GameRoot = await _boot(true)
	var world: WorldView = game.world
	await runner.get_tree().process_frame
	eq(_named(world, "ShaderWarmup").size(), 0, "the warm-up samples are gone once loading ends")
	check(MaterialKeep.count() >= 8, "one material is kept per shader combination (%d kept)" % MaterialKeep.count())
	# Kombinasi yang dulu memicu kompilasi di tengah permainan ikut tersimpan.
	var probes: Array[Material] = [
		ProceduralMeshFactory.tint_material(Color(Palette.FLOUR_WHITE, 0.55)),
		ProceduralMeshFactory.overlay_material(),
		DecorFactory.marker_material(),
	]
	var marker := StationMarker.new()
	runner.add_child(marker)
	marker.show_alert(0.5)
	for mi: Node in marker.find_children("*", "MeshInstance3D", true, false):
		probes.append((mi as MeshInstance3D).material_override)
	for m: Material in probes:
		if m is BaseMaterial3D:
			check(MaterialKeep._kept.has(MaterialKeep.key_of(m as BaseMaterial3D)),
				"the shader combination of %s is kept alive" % (m as BaseMaterial3D).resource_name)
	# Contoh dipasang di bawah lantai: tergambar, tetapi tidak pernah terlihat.
	var w: ShaderWarmup = ShaderWarmup.start(world)
	check(w.global_position.y < -0.5, "the samples sit below the floor (y %.2f)" % w.global_position.y)
	var kinds: Dictionary = {}
	for n: Node in w.find_children("*", "", true, false):
		kinds[n.get_class()] = true
	check(kinds.has("CPUParticles3D"), "particle effects are part of the warm-up")
	check(_named(w, "SlotMarker").size() >= 4, "every slot marker look is part of the warm-up")
	check(w.find_children("*", "StationMarker", true, false).size() >= 2 or _count_class(w, StationMarker) >= 2,
		"the progress bar and the alert marker are part of the warm-up")
	var placeable: int = 0
	for x: Variant in DataRegistry.decorations():
		if (x as MiscDefinitions.DecorationDefinition).is_placeable():
			placeable += 1
	var decor_models: int = 0
	for n2: Node in w.get_children():
		if n2.has_meta("deco_id"):
			decor_models += 1
	eq(decor_models, placeable, "every decoration model is part of the warm-up")
	w.finish()
	marker.queue_free()
	await runner.get_tree().process_frame
	check(not is_instance_valid(w), "finish() removes the samples")
	await _finish(game)


func _count_class(root: Node, script: Script) -> int:
	var n: int = 0
	for c: Node in root.find_children("*", "", true, false):
		if c.get_script() == script:
			n += 1
	return n


func _shared_materials() -> void:
	var game: GameRoot = await _boot(false)
	var world: WorldView = game.world
	var disp: EquipmentInstance = game.sim.equipment.placed_list(&"display")[0]
	var cells: Array[Vector2i] = GridMath.footprint_cells(disp.anchor, disp.def().footprint_tiles, disp.rotation)
	var used: Dictionary = {}
	for valid: bool in [true, false, true]:
		world.show_ghost(cells, disp.floor_id, valid)
		for mi: Node in world._ghosts.find_children("*", "MeshInstance3D", true, false):
			if not (mi as Node).is_queued_for_deletion():
				used[(mi as MeshInstance3D).material_override] = true
	eq(used.size(), 3, "valid tiles, invalid tiles and their cross share three materials in total")
	var keys: Dictionary = {}
	for m: Variant in used.keys():
		keys[MaterialKeep.key_of(m as BaseMaterial3D)] = true
	keys[MaterialKeep.key_of(ProceduralMeshFactory.overlay_material())] = true
	eq(keys.size(), 1, "ghosts and tile overlays use one and the same unshaded shader")
	world.show_tile_overlay(cells, cells)
	world.show_tile_overlay(cells, [] as Array[Vector2i])
	for ov: Node in world._tile_overlay.get_children():
		var mesh: Mesh = (ov as MeshInstance3D).mesh
		if mesh != null and mesh.get_surface_count() > 0:
			check(mesh.surface_get_material(0) == ProceduralMeshFactory.overlay_material(), "tile overlays reuse the shared material")
	world.clear_ghost()
	world.clear_tile_overlay()
	await _finish(game)


func _sounds() -> void:
	var ids: Array[StringName] = AudioManager.short_sound_ids()
	check(not ids.is_empty(), "there are short sounds to prepare")
	var covered: Dictionary = {}
	for id: StringName in ids:
		var def: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(id)
		check(MusicBuild.mood_of(String(def.generator)) == "", "%s is not a music bed" % id)
		covered[MusicBuild.cache_key(String(def.generator))] = true
	for x: Variant in DataRegistry.audio_events():
		var d2: MiscDefinitions.AudioEventDefinition = x
		if MusicBuild.mood_of(String(d2.generator)) == "":
			check(covered.has(MusicBuild.cache_key(String(d2.generator))), "the sound of %s is built during loading" % d2.id)
	for ui_id: StringName in [&"ui_tap_soft", &"footstep_tile", &"storage_open", &"mixer_start", &"oven_open", &"bread_place_display", &"ui_pause", &"ui_error"]:
		var dd: MiscDefinitions.AudioEventDefinition = DataRegistry.audio_event(ui_id)
		check(dd != null and covered.has(MusicBuild.cache_key(String(dd.generator))), "%s is ready before the first tap" % ui_id)

	# Menu: bunyi pendek dirakit di latar; gameplay menghentikannya.
	var was: bool = AudioManager.background_prewarm
	AudioManager.background_prewarm = true
	AudioManager.prewarm_short_sounds()
	AudioManager.background_prewarm = was
	check(not AudioManager._sfx_backlog.is_empty() or ids.all(func(i: StringName) -> bool: return AudioManager.is_stream_ready(i)),
		"the menu queues the short sounds that are not built yet")
	var game: GameRoot = await _boot(false)
	check(AudioManager._sfx_backlog.is_empty(), "entering gameplay stops building sounds in the background")
	await _finish(game)


func _few_shaders() -> void:
	# Kaca tipis: tanpa cahaya, shader yang sama dengan arsiran ubin.
	var glass: StandardMaterial3D = ProceduralMeshFactory.material(Color(0.9, 0.95, 0.95, 0.24))
	eq(glass.shading_mode, BaseMaterial3D.SHADING_MODE_UNSHADED, "thin glass is unshaded")
	eq(MaterialKeep.key_of(glass), MaterialKeep.key_of(ProceduralMeshFactory.overlay_material()), "thin glass shares the tile overlay shader")
	# Roti: shader yang sama dengan perabot.
	var bread: Node3D = BreadFactory.build("loaf.plain", 0.7, &"FRESH")
	var furniture_key: String = MaterialKeep.key_of(ProceduralMeshFactory.material(Palette.PINE_WOOD))
	var bread_keys: Dictionary = {}
	for mi: Node in bread.find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m != null and m.get_surface_count() > 0 and m.surface_get_material(0) is BaseMaterial3D:
			bread_keys[MaterialKeep.key_of(m.surface_get_material(0) as BaseMaterial3D)] = true
		if m is PrimitiveMesh and (m as PrimitiveMesh).material is BaseMaterial3D:
			bread_keys[MaterialKeep.key_of((m as PrimitiveMesh).material as BaseMaterial3D)] = true
	bread.free()
	check(not bread_keys.is_empty(), "the bread model has materials")
	check(bread_keys.size() == 1 and bread_keys.has(furniture_key), "bread shares the furniture shader (%d combinations)" % bread_keys.size())
	# Seluruh game: alat semua tier, semua ruangan, dan sampel pemanasan.
	var game: GameRoot = await _boot(false)
	var root := Node3D.new()
	game.world.add_child(root)
	for t in range(1, 6):
		root.add_child(EquipmentFactory.build_mixer(t))
		root.add_child(EquipmentFactory.build_oven(t))
		root.add_child(EquipmentFactory.build_display(t))
		root.add_child(EquipmentFactory.build_storage(t))
	for loc: Variant in DataRegistry.locations():
		for fd: FloorDefinition in (loc as LocationDefinition).floors:
			root.add_child(RoomFactory.build_floor(loc as LocationDefinition, fd, "Shader Bakery", {}))
	var w: ShaderWarmup = ShaderWarmup.start(game.world)
	MaterialKeep.clear()
	MaterialKeep.scan(game.world)
	check(MaterialKeep.count() <= 12, "a dozen shader combinations cover the whole game (%d)" % MaterialKeep.count())
	for k: Variant in MaterialKeep._kept.keys():
		var m2: BaseMaterial3D = MaterialKeep._kept[k]
		check(m2.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED or m2.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED,
			"no lit transparent shader (the slowest to compile in a browser)")
	w.finish()
	root.queue_free()
	await _finish(game)
