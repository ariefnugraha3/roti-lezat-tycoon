extends Node3D
## QA visual karakter (GDD 31, 130.2, 130.5): merender seluruh varian karakter
## berjajar ke PNG, dari depan (close-up) dan dari sudut kamera gameplay.
## Jalankan dengan jendela (bukan --headless, karena perlu renderer):
##   godot --path . --resolution 1920x1080 res://tools/character_lineup.tscn
## Folder keluaran: env LINEUP_OUT, atau user://lineup bila tidak diisi.

const SPACING: float = 0.62
const PER_ROW: int = 6

var _out: String = ""
var _cam: Camera3D = null
var _stage: Node3D = null


func _ready() -> void:
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(_out)
	add_child(EquipmentFactory.build_environment())
	var sun := DirectionalLight3D.new()
	sun.light_color = Palette.GOLDEN_HOUR
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-52.0, -135.0, 0.0)
	add_child(sun)
	var lamp := OmniLight3D.new()
	lamp.light_color = Palette.WARMER_LAMP
	lamp.light_energy = 0.55
	lamp.omni_range = 8.0
	lamp.position = Vector3(1.5, 2.4, -1.0)
	add_child(lamp)
	var floor_mesh := ProceduralMeshFactory.box(Vector3(30.0, 0.02, 30.0), Palette.BG.darkened(0.08))
	floor_mesh.position = Vector3(0.0, -0.01, 0.0)
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	_cam.current = true
	_stage = Node3D.new()
	add_child(_stage)
	await _run()
	# Lepas semua node & cache statis sebelum keluar (tanpa RID bocor, GDD 133.3).
	for c: Node in get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ProceduralCaches.clear_all()
	get_tree().quit(0)


func _entries() -> Array:
	var e: Array = []
	e.append(["Player (male)", CharacterFactory.spec_for_player("pria")])
	e.append(["Player (female)", CharacterFactory.spec_for_player("wanita")])
	for def: StaffDefinition in DataRegistry.staff_list():
		e.append([String(def.id), CharacterFactory.spec_for_staff(String(def.id))])
	for arch: String in CharacterFactory.ARCHETYPE_VISUAL.keys():
		e.append([arch, CharacterFactory.spec_for_customer(arch, 11)])
	for seed_i: int in [3, 27, 58]:
		e.append(["generic %d" % seed_i, CharacterFactory.spec_for_customer("customer_generic", seed_i)])
	e.append(["RotiFood driver", CharacterFactory.spec_for_driver(false)])
	e.append(["RotiFood driver (rain)", CharacterFactory.spec_for_driver(true)])
	e.append(["Supply courier", CharacterFactory.spec_for_courier()])
	e.append(["Pak Lurah", CharacterFactory.spec_for_lurah()])
	return e


func _run() -> void:
	var entries: Array = _entries()
	var tris_report: PackedStringArray = PackedStringArray()
	# Close-up dari depan, PER_ROW karakter per gambar.
	var page: int = 0
	var i: int = 0
	while i < entries.size():
		_clear()
		var count: int = mini(PER_ROW, entries.size() - i)
		for k in count:
			var spec: Dictionary = entries[i + k][1]
			var ch: Node3D = CharacterFactory.build(spec)
			_stage.add_child(ch)
			ch.position = Vector3((float(k) - float(count - 1) * 0.5) * SPACING, 0.0, 0.0)
			tris_report.append("%-26s tris %5d  meshes %3d  draw %3d" % [entries[i + k][0], _tris(ch), _meshes(ch),
				CharacterFactory.mesh_count(ch)])
		_front_camera(float(PER_ROW) * SPACING)
		await _shot("front_%d" % page)
		page += 1
		i += count
	# Sudut 3/4 dan belakang untuk bentuk yang tak terlihat dari depan (kepang,
	# sanggul, kuncir, pita celemek, ransel).
	var picks: Array = []
	for entry: Array in entries:
		if str(entry[0]) in ["Player (male)", "Player (female)", "staff_cashier_sari", "staff_cashier_dewi",
				"staff_cashier_citra", "RotiFood driver (rain)"]:
			picks.append(entry)
	for view: Array in [["three_quarter", 38.0], ["back", 180.0]]:
		_clear()
		for k3 in picks.size():
			var ch3: Node3D = CharacterFactory.build(picks[k3][1])
			_stage.add_child(ch3)
			ch3.position = Vector3((float(k3) - float(picks.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
			ch3.rotation_degrees.y = float(view[1])
		_front_camera(float(PER_ROW) * SPACING)
		await _shot(str(view[0]))
	# Close-up wajah (sedikit dari atas, seperti kamera gameplay) untuk poni,
	# mata, alis, dan ekspresi.
	_clear()
	var moods: Array[String] = ["senang", "netral", "kesal", "sedih", "kaget"]
	for k4 in 5:
		var spec4: Dictionary = picks[k4 % picks.size()][1].duplicate()
		spec4["mood"] = moods[k4]
		var ch4: Node3D = CharacterFactory.build(spec4)
		_stage.add_child(ch4)
		ch4.position = Vector3((float(k4) - 2.0) * 0.46, 0.0, 0.0)
	var vp4: Vector2 = get_viewport().get_visible_rect().size
	_cam.size = 2.4 * vp4.y / vp4.x
	_cam.position = Vector3(0.0, 0.70 + 6.0 * sin(deg_to_rad(18.0)), -6.0 * cos(deg_to_rad(18.0)))
	_cam.look_at(Vector3(0.0, 0.70, 0.0), Vector3.UP)
	await _shot("faces")
	await _poses()
	# Sudut kamera gameplay (yaw 45°, pitch 35°) pada zoom bawaan: tinggi layar ~72-92 px (GDD 130.1).
	_clear()
	for k2 in entries.size():
		var ch2: Node3D = CharacterFactory.build(entries[k2][1])
		_stage.add_child(ch2)
		ch2.position = Vector3(float(k2 % 10) * 0.5 - 2.25, 0.0, float(k2 / 10) * 0.8 - 1.6)
	_game_camera()
	await _shot("gameplay_zoom")
	var f: FileAccess = FileAccess.open(_out.path_join("tris.txt"), FileAccess.WRITE)
	f.store_string("\n".join(tris_report) + "\n")
	f.close()
	print("\n".join(tris_report))


## Pose & aksi lewat ActorView sungguhan (GDD 20.12, 21.4, 31.6, 31.7): membungkus,
## mengelap wajah, terkantuk-kantuk, pembeli menenteng roti dan kantong, staf
## membawa loyang, gelembung pikiran pemain, dan pengunjung lihat-lihat.
func _poses() -> void:
	_clear()
	PauseManager.clear_all()
	var views: Array[ActorView] = []
	var specs: Array = [
		CharacterFactory.spec_for_player("pria"), CharacterFactory.spec_for_player("wanita"),
		CharacterFactory.spec_for_staff("staff_cashier_budi"), CharacterFactory.spec_for_customer("customer_generic", 3),
		CharacterFactory.spec_for_customer("customer_bulk_buyer", 11), CharacterFactory.spec_for_staff("staff_baker_joko"),
	]
	for k in specs.size():
		var v := ActorView.new()
		_stage.add_child(v)
		v.bind(StringName("pose_%d" % k), "pose|%d" % k, specs[k])
		v.position = Vector3((float(k) - float(specs.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		views.append(v)
	var a := SimActor.new()
	a.pos = Vector2.ZERO
	views[0].set_action(&"pack")
	views[1].set_idle_enabled(true)
	views[1].set_busy(false)
	views[2].set_idle_enabled(true)
	views[2].set_busy(false)
	views[3].set_carry("bread", "loaf.plain", 1.0, 2)
	views[4].set_carry("bag")
	views[5].set_carry("tray", "loaf.plain", 1.0)
	# Waktu nyata disimulasikan: 15,9 s (tengah mengelap) dan 28 s (mengantuk).
	var steps: Dictionary = {1: 15.9, 2: 28.0}
	for k2 in views.size():
		var total: float = float(steps.get(k2, 1.3))
		var t: float = 0.0
		while t < total:
			var sa := SimActor.new()
			sa.pos = Vector2(views[k2].position.x, views[k2].position.z)
			views[k2].sync(sa, 0.1, true)
			t += 0.1
	_front_camera(float(PER_ROW) * SPACING)
	# Gelembung pikiran di atas karakter pertama.
	var layer := CanvasLayer.new()
	add_child(layer)
	var bubble := ThoughtBubble.new()
	layer.add_child(bubble)
	bubble.show_key("thought_quiet_3")
	bubble.point_at(_cam.unproject_position(views[3].global_position + Vector3(0.0, views[3].head_top() + 0.08, 0.0)))
	await _shot("poses")
	for v2: ActorView in views:
		v2.rotation_degrees.y = 38.0
	await _shot("poses_three_quarter")
	layer.queue_free()
	# Pengunjung lihat-lihat (GDD 20.12) di beberapa detik: kepala menyapu rak
	# kiri-kanan, badan sedikit condong, sesekali tangan menopang dagu.
	_clear()
	var lookers: Array[ActorView] = []
	var at: Array[float] = [1.0, 2.2, 3.4, 6.1]
	for k3 in at.size():
		var lv := ActorView.new()
		_stage.add_child(lv)
		lv.bind(StringName("look_%d" % k3), "look|%d" % k3, CharacterFactory.spec_for_customer("customer_school_child", 5 + k3))
		lv.position = Vector3((float(k3) - float(at.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
		lv.set_look_around(true)
		var t3: float = 0.0
		while t3 < at[k3]:
			var sa3 := SimActor.new()
			sa3.pos = Vector2(lv.position.x, lv.position.z)
			lv.sync(sa3, 0.1, true)
			t3 += 0.1
		lookers.append(lv)
	_front_camera(float(PER_ROW) * SPACING)
	await _shot("poses_window_shopper")
	for lv2: ActorView in lookers:
		lv2.rotation_degrees.y = 38.0
	await _shot("poses_window_shopper_three_quarter")


func _clear() -> void:
	for c: Node in _stage.get_children():
		c.queue_free()
	await get_tree().process_frame


func _front_camera(width_m: float) -> void:
	var vp: Vector2 = get_viewport().get_visible_rect().size
	_cam.size = width_m * vp.y / vp.x
	_cam.position = Vector3(0.0, 0.62, -6.0)
	_cam.look_at(Vector3(0.0, 0.48, 0.0), Vector3.UP)


func _game_camera() -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var offset := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * 30.0
	_cam.size = DataRegistry.balf("camera.default_ortho_size")
	var focus := Vector3(0.0, 0.3, 0.0)
	_cam.position = focus + offset
	_cam.look_at(focus, Vector3.UP)


func _shot(name: String) -> void:
	for n in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(name + ".png"))


static func _meshes(n: Node) -> int:
	var c: int = 1 if n is MeshInstance3D else 0
	for ch: Node in n.get_children():
		c += _meshes(ch)
	return c


static func _tris(n: Node) -> int:
	var t: int = 0
	if n is MeshInstance3D and (n as MeshInstance3D).mesh != null:
		var m: Mesh = (n as MeshInstance3D).mesh
		for s in m.get_surface_count():
			var arr: Array = m.surface_get_arrays(s)
			var idx: Variant = arr[Mesh.ARRAY_INDEX]
			if idx != null and (idx as PackedInt32Array).size() > 0:
				t += (idx as PackedInt32Array).size() / 3
			else:
				t += (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
	for ch: Node in n.get_children():
		t += _tris(ch)
	return t
