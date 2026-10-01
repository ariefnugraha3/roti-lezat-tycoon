class_name ShaderWarmup
extends Node3D
## Pemanasan shader di balik layar loading (GDD 89.5, 109, 114).
##
## WebGL mengompilasi shader saat sebuah kombinasi material PERTAMA KALI
## digambar. Di browser satu kompilasi makan sekitar 0,2 detik bila cache GPU
## browser sudah hangat dan beberapa detik bila belum (kunjungan pertama). Tanpa
## pemanasan, kompilasi itu jatuh di tengah permainan: saat penanda "!" pertama
## muncul, saat mixer mulai, saat pelanggan pertama datang, atau saat perabot
## pertama diangkat di Decoration Mode.
##
## Node ini memasang satu contoh setiap visual yang baru muncul belakangan
## (alat sampai tier lokasi, semua dekorasi, penanda stasiun, karakter, barang
## bawaan, partikel, jejak penempatan, arsiran ubin, penanda slot) rapat di titik
## fokus kamera, SEDIKIT DI BAWAH LANTAI: semuanya tetap digambar (jadi shadernya
## terkompilasi) tetapi tertutup lantai, sehingga tidak pernah terlihat, baik di
## balik layar loading maupun saat upgrade lokasi. Setelah beberapa frame,
## `finish()` menyimpan satu material per kombinasi lewat MaterialKeep, supaya
## shadernya tetap hidup seumur proses, lalu membuang semuanya.

## Jarak antar-contoh (meter) dan skala model; cukup rapat agar semua di layar.
const STEP: float = 0.32
const MODEL_SCALE: float = 0.22
## Kedalaman di bawah lantai (meter): tertutup lantai, tetap di dalam frustum.
const BELOW_FLOOR_M: float = 0.9

var _slot: int = 0
var _cols: int = 8


## Pasang contoh-contoh di lantai yang sedang dilihat, di titik fokus kamera.
static func start(world: WorldView) -> ShaderWarmup:
	var w := ShaderWarmup.new()
	w.name = "ShaderWarmup"
	var parent: Node3D = world.floors.get(world.camera_rig.active_floor)
	if parent == null:
		parent = world
	parent.add_child(w)
	var focus: Vector3 = world.camera_rig.screen_to_ground(world.get_viewport().get_visible_rect().size * 0.5)
	if is_inf(focus.x):
		focus = Vector3.ZERO
	w.global_position = Vector3(focus.x, -BELOW_FLOOR_M, focus.z)
	w._fill(world)
	return w


## Simpan material setiap kombinasi (MaterialKeep), lalu buang contohnya.
func finish() -> int:
	var added: int = MaterialKeep.scan(self)
	queue_free()
	return added


func _place(n: Node3D, scale_k: float = MODEL_SCALE) -> void:
	add_child(n, true)
	var col: int = _slot % _cols
	var row: int = _slot / _cols
	n.position = Vector3((float(col) - float(_cols) * 0.5) * STEP, 0.0, (float(row) - 2.0) * STEP)
	n.scale = Vector3.ONE * scale_k
	_slot += 1


func _fill(world: WorldView) -> void:
	var sim: SimulationRoot = world.sim
	# Alat: semua kategori sampai tier tertinggi yang bisa dibeli di lokasi ini
	# (GDD 5.1.2), plus isi yang muncul saat bekerja.
	var max_tier: int = clampi(sim.world.location.tier, 1, 5)
	for t in range(1, max_tier + 1):
		_place(EquipmentFactory.build_mixer(t))
		_place(EquipmentFactory.build_oven(t))
		_place(EquipmentFactory.build_display(t))
		_place(EquipmentFactory.build_storage(t))
	_place(EquipmentFactory.build_holding_table())
	var profile: String = _any_profile()
	_place(EquipmentFactory.dough_bowl(), 1.0)
	_place(EquipmentFactory.bread_tray(profile, 1.0, &"FRESH"), 1.0)
	for f: StringName in [&"FRESH", &"STALE"]:
		_place(BreadFactory.build_cached(profile, 0.5, f), 1.0)
	_place(BreadFactory.build_paper_bag(), 1.0)
	# Semua dekorasi (Decor Shop dan hadiah achievement) dan penanda slotnya.
	for x: Variant in DataRegistry.decorations():
		var d: MiscDefinitions.DecorationDefinition = x
		if d.is_placeable():
			_place(DecorFactory.build_cached(d.id), 0.5)
	for t2: StringName in [&"wall", &"counter_prop"]:
		_place(DecorFactory.slot_marker(t2, false), 0.5)
		_place(DecorFactory.slot_marker(t2, true), 0.5)
	# Penanda stasiun: bar progres, tanda seru, dan tanda gosong berapi.
	var progress := StationMarker.new()
	_place(progress, 0.5)
	progress.show_progress(0.5)
	var alert := StationMarker.new()
	_place(alert, 0.5)
	alert.show_alert(0.6)
	# Karakter: setiap tipe pelanggan, pengemudi RotiFood saat hujan, kurir,
	# karyawan, dan pemain; lengkap dengan bar kesabaran, balon, dan bawaan.
	var specs: Array[Dictionary] = []
	for arch: Variant in CharacterFactory.ARCHETYPE_VISUAL.keys():
		specs.append(CharacterFactory.spec_for_customer(str(arch), 7, false))
	specs.append(CharacterFactory.spec_for_customer("driver_rotifood", 7, true))
	specs.append(CharacterFactory.spec_for_customer("courier_supply", 7, false))
	var roles: Dictionary = {}
	for sd: StaffDefinition in DataRegistry.staff_list():
		if not roles.has(sd.role_id):
			roles[sd.role_id] = true
			specs.append(CharacterFactory.spec_for_staff(String(sd.id)))
	specs.append(CharacterFactory.spec_for_player("wanita"))
	var carries: Array[String] = ["bag", "tray", "dough", "bread", "package", ""]
	for i in specs.size():
		var v := ActorView.new()
		_place(v, 0.5)
		v.bind(StringName("warm_%d" % i), "warm_%d" % i, specs[i])
		v.set_carry(carries[i % carries.size()], profile, 1.0, 2)
		if i == 0:
			v.set_patience(0.2, true, false)
			v.set_alert(true)
			v.set_thought("?")
		if i == 1:
			v._show_cloth(true)
			var z: MeshInstance3D = CharacterFactory.sleep_z()
			v.add_child(z)
			z.position = Vector3(0.1, 1.3, 0.0)
	# Partikel (GDD 4.1): uap, kilau gula, asap gosong, keringat.
	var fx_root := Node3D.new()
	_place(fx_root, 1.0)
	FX.steam(fx_root, Vector3.ZERO)
	FX.sugar_sparkle(fx_root, Vector3(0.1, 0.0, 0.0))
	FX.burn_smoke(fx_root, Vector3(-0.1, 0.0, 0.0))
	# Decoration Mode: jejak penempatan sah/tidak sah dan arsiran ubin.
	_place(WorldView.ghost_tile(true), 1.0)
	_place(WorldView.ghost_tile(false), 1.0)
	var cell := Vector2i.ZERO
	for pattern: StringName in [&"stripes", &"dot"]:
		var ov: MeshInstance3D = ProceduralMeshFactory.tile_overlay([cell], Color(Palette.DANGER, 0.2), Color(Palette.DANGER, 0.7), pattern)
		_place(ov, 1.0)
	# Kantong kertas di meja kasir saat membungkus (GDD 21.4).
	var lane: QueueLane = sim.queue.main_lane()
	if lane != null:
		var rig: PackBagRig = world._build_pack_bag(lane)
		_place(rig, 1.0)


static func _any_profile() -> String:
	for r: RecipeDefinition in DataRegistry.recipes():
		if String(r.visual_profile_id) != "":
			return String(r.visual_profile_id)
	return ""
