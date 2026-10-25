extends Node
## Pemeriksa visual MeshBake (GDD 109): setiap model perabot, ruangan, dan isi
## petak roti dirender tiga kali di tempat dan cahaya yang sama dengan sudut
## kamera gameplay:
##   A  model rakitan dengan material lama (tanpa warna verteks sebagai albedo),
##   B  model rakitan dengan material sekarang (warna verteks sRGB, primitif putih),
##   C  model yang sudah dipanggang (satu mesh berwarna verteks).
## A-B membuktikan primitif tanpa warna verteks tetap berwarna sama; B-C
## membuktikan pemanggangan tidak mengubah bentuk dan warna. Dicetak selisih
## rata-rata (0..255) dan persen piksel yang berbeda lebih dari 12/255.
## Jalankan dengan jendela (bukan --headless):
##   godot --path . --resolution 1280x720 res://tools/bake_compare.tscn
## Gambar A|B|C disimpan di env BAKE_OUT bila diisi.

const DIFF_THRESHOLD: float = 12.0 / 255.0

var _cam: Camera3D = null
var _stage: Node3D = null
var _out: String = ""
var _worst: float = 0.0


func _ready() -> void:
	_out = OS.get_environment("BAKE_OUT")
	if _out != "":
		DirAccess.make_dir_recursive_absolute(_out)
	add_child(EquipmentFactory.build_environment())
	var sun := DirectionalLight3D.new()
	sun.light_color = Palette.GOLDEN_HOUR
	sun.light_energy = 0.95
	sun.rotation_degrees = Vector3(-52.0, -135.0, 0.0)
	add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	add_child(_cam)
	_stage = Node3D.new()
	add_child(_stage)
	await get_tree().process_frame
	var cases: Array = []
	for t in range(1, 6):
		cases.append(["mixer_t%d" % t, EquipmentFactory.build_mixer.bind(t)])
		cases.append(["oven_t%d" % t, EquipmentFactory.build_oven.bind(t)])
		cases.append(["display_t%d" % t, EquipmentFactory.build_display.bind(t)])
		cases.append(["storage_t%d" % t, EquipmentFactory.build_storage.bind(t)])
		cases.append(["holding_table_%d" % t, EquipmentFactory.build_holding_table.bind(t)])
	cases.append(["staff_chair", EquipmentFactory.build_staff_chair])
	for x: Variant in DataRegistry.locations():
		var loc: LocationDefinition = x
		for fd: FloorDefinition in loc.floors:
			cases.append(["room_%s_%s" % [loc.id, fd.id], _room.bind(loc, fd)])
	for prof: String in ["loaf.plain", "bun.chocolate", "croissant.classic", "donut.sugar", "roll.cinnamon", "crepes", "signature", "baguette"]:
		cases.append(["bread_%s" % prof, _bread.bind(prof)])
	for c: Array in cases:
		await _compare(String(c[0]), c[1] as Callable)
	print("BAKE_COMPARE worst B-C mean diff %.2f/255" % (_worst * 255.0))
	ProceduralCaches.clear_all()
	get_tree().quit(0)


func _room(loc: LocationDefinition, fd: FloorDefinition) -> Node3D:
	var node: Node3D = RoomFactory.build_floor(loc, fd, "Compare Bakery", {})
	# Lampu ruangan bergantung posisi; perbandingan cukup dengan cahaya matahari.
	for l: Node in node.find_children("*", "Light3D", true, false):
		l.queue_free()
	return node


func _bread(prof: String) -> Node3D:
	var root := Node3D.new()
	for k in 3:
		var b: Node3D = BreadFactory.build(prof, 1.0, &"FRESH")
		b.scale = Vector3.ONE * BreadFactory.SLOT_SCALE * 4.0
		b.position = Vector3((float(k) - 1.0) * BreadFactory.SLOT_SPACING * 4.0, 0.0, float(k % 2) * BreadFactory.SLOT_STAGGER * 4.0)
		root.add_child(b)
	return root


func _compare(label: String, build: Callable) -> void:
	var a: Node3D = build.call()
	_old_materials(a)
	var b: Node3D = build.call()
	var c: Node3D = build.call()
	var parts_before: int = _surfaces(c)
	var t0: int = Time.get_ticks_usec()
	MeshBake.bake(c, [], label.begins_with("bread_"))
	var bake_ms: float = float(Time.get_ticks_usec() - t0) / 1000.0
	var parts_after: int = _surfaces(c)
	var box: AABB = EquipmentFactory._mesh_bounds(b)
	_frame(box)
	var imgs: Array[Image] = []
	for n: Node3D in [a, b, c]:
		_stage.add_child(n)
		await get_tree().process_frame
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		imgs.append(get_viewport().get_texture().get_image())
		_stage.remove_child(n)
	var ab: Vector2 = _diff(imgs[0], imgs[1])
	var bc: Vector2 = _diff(imgs[1], imgs[2])
	_worst = maxf(_worst, bc.x)
	print("%-34s surfaces %4d -> %3d  bake %6.1f ms  A-B mean %.2f (%.2f%% px)  B-C mean %.2f (%.2f%% px)" % [label,
		parts_before, parts_after, bake_ms, ab.x * 255.0, ab.y * 100.0, bc.x * 255.0, bc.y * 100.0])
	if _out != "":
		var w: int = imgs[0].get_width()
		var h: int = imgs[0].get_height()
		var strip: Image = Image.create(w * 3, h, false, imgs[0].get_format())
		for i in 3:
			strip.blit_rect(imgs[i], Rect2i(0, 0, w, h), Vector2i(w * i, 0))
		strip.save_png(_out.path_join("%s.png" % label))
	for n2: Node3D in [a, b, c]:
		n2.free()


## Kamera gameplay (yaw 45, pitch 35, ortografis) yang membingkai kotak model.
func _frame(box: AABB) -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var focus: Vector3 = box.get_center()
	var offset := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * 30.0
	_cam.global_position = focus + offset
	_cam.look_at(focus, Vector3.UP)
	_cam.size = maxf(box.size.length() * 1.05, 0.2)


func _old_materials(root: Node) -> void:
	for n: Node in [root] + root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var m := MeshBake._material_of(mi, s) as StandardMaterial3D
			# Hanya material perabot/roti (Lambert); mesh MeshBuilder memang berwarna verteks.
			if m == null or not m.vertex_color_is_srgb or m.diffuse_mode != BaseMaterial3D.DIFFUSE_LAMBERT:
				continue
			var old: StandardMaterial3D = m.duplicate()
			old.vertex_color_use_as_albedo = false
			old.vertex_color_is_srgb = false
			mi.set_surface_override_material(s, old)


func _surfaces(root: Node) -> int:
	var n: int = 0
	for x: Node in [root] + root.find_children("*", "MeshInstance3D", true, false):
		var mi := x as MeshInstance3D
		if mi != null and mi.mesh != null and mi.visible:
			n += mi.mesh.get_surface_count()
	return n


## (selisih rata-rata 0..1, bagian piksel yang selisihnya di atas ambang).
func _diff(p: Image, q: Image) -> Vector2:
	var w: int = p.get_width()
	var h: int = p.get_height()
	var total: float = 0.0
	var over: int = 0
	var count: int = 0
	for y in range(0, h, 2):
		for x in range(0, w, 2):
			var a: Color = p.get_pixel(x, y)
			var b: Color = q.get_pixel(x, y)
			var d: float = maxf(maxf(absf(a.r - b.r), absf(a.g - b.g)), absf(a.b - b.b))
			total += d
			count += 1
			if d > DIFF_THRESHOLD:
				over += 1
	return Vector2(total / float(count), float(over) / float(count))
