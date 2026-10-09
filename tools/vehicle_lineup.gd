extends Node3D
## QA visual kendaraan jalan (GDD 32.7): merender semua jenis dan varian
## kendaraan TrafficFactory berjajar ke PNG, dari samping (close-up) dan dari
## sudut kamera gameplay, termasuk bingkai kayuh/langkah dan versi hujan.
## Jalankan dengan jendela (bukan --headless, karena perlu renderer):
##   godot --path . --resolution 1600x900 res://tools/vehicle_lineup.tscn
## Folder keluaran: env LINEUP_OUT, atau user://lineup bila tidak diisi.

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
	var floor_mesh := ProceduralMeshFactory.box(Vector3(80.0, 0.02, 40.0), Palette.BG.darkened(0.08))
	floor_mesh.position = Vector3(0.0, -0.01, 0.0)
	add_child(floor_mesh)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	_cam.current = true
	_stage = Node3D.new()
	add_child(_stage)
	await _run()
	for c: Node in get_children():
		c.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ProceduralCaches.clear_all()
	get_tree().quit(0)


func _clear() -> void:
	for c: Node in _stage.get_children():
		c.free()


## Satu baris kendaraan menghadap -X (seperti lajur ke kiri), mulai dari x = 0.
func _row(items: Array, z: float, gap: float = 0.5) -> float:
	var x: float = 0.0
	for it: Array in items:
		var kind: StringName = it[0]
		var len: float = float(TrafficFactory.info(kind)["length"])
		var t0: int = Time.get_ticks_usec()
		var mi: MeshInstance3D = TrafficFactory.build(kind, int(it[1]), bool(it[2]), 0.0, int(it[3]))
		var ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
		mi.rotation.y = PI * 0.5
		mi.position = Vector3(x + len * 0.5, 0.0, z)
		_stage.add_child(mi)
		var bb: AABB = mi.mesh.get_aabb()
		print("%s v%d rain=%s frame=%d tris=%d build=%.1fms x[%.2f,%.2f] y[%.2f,%.2f] z[%.2f,%.2f]" % [kind, int(it[1]), it[2], int(it[3]),
			int(mi.get_meta("tris", 0)), ms, bb.position.x, bb.end.x, bb.position.y, bb.end.y, bb.position.z, bb.end.z])
		x += len + gap
	return x


func _side_shot(file: String, center: Vector3, size: float) -> void:
	_cam.size = size
	_cam.position = center + Vector3(0.0, 0.35, 20.0)
	_cam.look_at(center + Vector3(0.0, 0.35, 0.0), Vector3.UP)
	await _snap(file)


func _game_shot(file: String, center: Vector3, size: float) -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	_cam.size = size
	var back := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
	_cam.position = center + back * 30.0
	_cam.look_at(center, Vector3.UP)
	await _snap(file)


func _snap(file: String) -> void:
	for i in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img: Image = get_viewport().get_texture().get_image()
	img.save_png(_out.path_join(file))
	print("saved ", file)


func _profile() -> void:
	var spec: Dictionary = TrafficFactory._rider_spec(&"customer_generic", 1, false, "helm")
	var tb: float = 0.0
	var tp: float = 0.0
	var ta: float = 0.0
	var tv: float = 0.0
	for i in 10:
		var t0: int = Time.get_ticks_usec()
		MeshBuilder.capture = true
		var model: Node3D = CharacterFactory.build(spec)
		MeshBuilder.capture = false
		var t1: int = Time.get_ticks_usec()
		TrafficFactory._pose(model, "ride", 0.0, 0.45)
		var t2: int = Time.get_ticks_usec()
		var mb := MeshBuilder.new()
		for n: Node in model.find_children("*", "MeshInstance3D", true, false):
			if n.has_meta("arrays") and StringName(n.get_meta("finish", MeshBuilder.MATTE)) == MeshBuilder.MATTE:
				mb.append_arrays(n.get_meta("arrays"), TrafficFactory._model_xf(n, model))
		var t3: int = Time.get_ticks_usec()
		model.free()
		var mb2 := MeshBuilder.new()
		TrafficFactory.scooter(mb2, Transform3D.IDENTITY, Palette.STRAWBERRY, 1)
		var t4: int = Time.get_ticks_usec()
		tb += float(t1 - t0)
		tp += float(t2 - t1)
		ta += float(t3 - t2)
		tv += float(t4 - t3)
	print("PROFILE per rider: build %.2f ms, pose %.2f ms, append %.2f ms; scooter body %.2f ms" % [tb / 10000.0, tp / 10000.0, ta / 10000.0, tv / 10000.0])
	for kind: StringName in [&"motor", &"motor_pair", &"bicycle", &"gerobak", &"becak", &"car", &"bus"]:
		var t5: int = Time.get_ticks_usec()
		var p: Dictionary = TrafficFactory.plan(kind, 0, false)
		var t5b: int = Time.get_ticks_usec()
		var worst: int = t5b - t5
		while true:
			var ts: int = Time.get_ticks_usec()
			var done: bool = TrafficFactory.plan_step(p)
			worst = maxi(worst, Time.get_ticks_usec() - ts)
			if done:
				break
		print("PROFILE %s: longest plan step %.2f ms" % [kind, worst / 1000.0])
		var t6: int = Time.get_ticks_usec()
		var arr: Array = TrafficFactory.frame_arrays(p, 1)
		var t7: int = Time.get_ticks_usec()
		var m: ArrayMesh = TrafficFactory.mesh_from(arr, 0.3)
		var t8: int = Time.get_ticks_usec()
		print("PROFILE %s: plan %.2f ms, frame %.2f ms, fade+upload %.2f ms, body tris %d, total tris %d" % [kind, (t6 - t5) / 1000.0,
			(t7 - t6) / 1000.0, (t8 - t7) / 1000.0, int(p["body_tris"]), (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3])
		m = null


func _street_tris() -> void:
	for loc: LocationDefinition in DataRegistry.locations():
		for wet: bool in [false, true]:
			var n: Node3D = NeighborhoodFactory.build(loc, loc.floor_def(loc.store_floor()), wet)
			var street: MeshInstance3D = n.get_node("Street") as MeshInstance3D
			print("STREET tier %d wet=%s tris=%d" % [loc.tier, wet, int(street.get_meta("tris", 0))])
			n.free()


func _run() -> void:
	_street_tris()
	_profile()
	var kinds: Array = TrafficFactory.KINDS.keys()
	# 1. Tiap jenis, semua varian, dari samping.
	for kind: StringName in kinds:
		_clear()
		var items: Array = []
		for v in int(TrafficFactory.info(kind)["variants"]):
			items.append([kind, v, false, 0])
		var w: float = _row(items, 0.0)
		await _side_shot("side_%s.png" % kind, Vector3(w * 0.5, 0.0, 0.0), maxf(w * 0.6, 2.4))
	# 2. Bingkai gerak (kayuh/langkah) dan hujan.
	for kind2: StringName in [&"bicycle", &"onthel", &"gerobak", &"becak"]:
		_clear()
		var items2: Array = []
		for f in TrafficFactory.frames(kind2):
			items2.append([kind2, 0, false, f])
		var w2: float = _row(items2, 0.0)
		await _side_shot("frames_%s.png" % kind2, Vector3(w2 * 0.5, 0.0, 0.0), maxf(w2 * 0.6, 2.4))
	_clear()
	var rain_items: Array = []
	for kind3: StringName in [&"motor", &"motor_pair", &"ojol", &"bicycle", &"gerobak", &"becak"]:
		rain_items.append([kind3, 0, true, 0])
	var w3: float = _row(rain_items, 0.0)
	await _side_shot("rain.png", Vector3(w3 * 0.5, 0.0, 0.0), w3 * 0.6)
	# 3. Sudut kamera gameplay: dua baris kendaraan campuran.
	_clear()
	var a: Array = []
	for kind4: StringName in [&"motor", &"ojol", &"motor_pair", &"bicycle", &"gerobak", &"car", &"angkot"]:
		a.append([kind4, 1, false, 1])
	var wa: float = _row(a, 0.0, 1.0)
	var b: Array = []
	for kind5: StringName in [&"luxury", &"van", &"becak", &"onthel", &"vintage", &"bus"]:
		b.append([kind5, 0, false, 2])
	var wb: float = _row(b, -2.4, 1.0)
	await _game_shot("game_angle.png", Vector3(maxf(wa, wb) * 0.5, 0.4, -1.2), 9.0)
	await _game_shot("game_angle_close.png", Vector3(4.5, 0.4, -0.6), 4.0)
