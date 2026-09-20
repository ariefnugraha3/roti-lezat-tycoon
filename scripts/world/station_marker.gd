class_name StationMarker
extends Node3D
## Penanda yang melayang di atas satu perabot: gelembung tanda seru "!" saat
## perabot itu menunggu diketuk, dan bar progres saat ia sedang bekerja.
##
## Keduanya digambar dari mesh primitif, bukan sprite (GDD 4 & 12.2). Materialnya
## UNSHADED supaya warnanya tidak pernah ikut redup oleh lampu ruangan — sebuah
## tanda seru yang tenggelam dalam bayangan sama saja dengan tidak ada.
##
## MENGHADAP KAMERA DILAKUKAN PADA NODE, BUKAN PADA MATERIAL. Ini bukan selera:
## `billboard_mode` mengganti basis tiap MESH di sekitar posisi dunia mesh itu
## sendiri. Untuk widget berlapis seperti bar progres — yang isinya digeser
## sampai setengah lebar bar pada sumbu X — setiap lapisan berputar mengelilingi
## titik yang berbeda, dan isi bar melenceng diagonal keluar dari alurnya
## alih-alih tumbuh di dalamnya. Yang tersisa di layar cuma alur putihnya.
## Satu basis untuk seluruh penanda menjaga tata letak antar-lapisan tetap
## persis seperti yang dirakit.
##
## Bar progres SENGAJA tidak memakai angka atau hitung mundur: pemain hanya perlu
## tahu "masih jalan" atau "sudah penuh", dan angka detik akan menarik matanya
## dari dapur ke teks.

## Tinggi penanda di atas puncak perabot, meter.
const HOVER: float = 0.22
## Lebar dan tebal bar progres, meter.
const BAR_WIDTH: float = 0.46
const BAR_HEIGHT: float = 0.075
const BAR_DEPTH: float = 0.020
## Jari-jari gelembung tanda seru.
const BUBBLE_RADIUS: float = 0.16
## Denyut gelembung per detik.
const PULSE_HZ: float = 1.6
## Rentang skala denyut.
const PULSE_MIN: float = 0.92
const PULSE_MAX: float = 1.12

## Mode penanda.
const MODE_NONE: String = ""
const MODE_ALERT: String = "alert"
const MODE_PROGRESS: String = "progress"

var mode: String = MODE_NONE

var _bubble: Node3D = null
var _bar: Node3D = null
var _isi: MeshInstance3D = null
var _isi_mat: StandardMaterial3D = null
var _t: float = 0.0
var _nilai: float = 0.0


func _ready() -> void:
	_bubble = _build_bubble()
	add_child(_bubble)
	_bar = _build_bar()
	add_child(_bar)
	_apply_mode()
	_hadap_kamera()


# ===========================================================================
# API
# ===========================================================================

## Menampilkan gelembung tanda seru: "perabot ini menunggu diketuk".
func show_alert() -> void:
	mode = MODE_ALERT
	_apply_mode()


## Menampilkan bar progres terisi `nilai` (0..1).
func show_progress(nilai: float) -> void:
	mode = MODE_PROGRESS
	_nilai = clampf(nilai, 0.0, 1.0)
	_apply_mode()
	_apply_progress()


## Menyembunyikan penanda sepenuhnya.
func hide_marker() -> void:
	mode = MODE_NONE
	_apply_mode()


## Memutar SELURUH penanda sejajar bidang layar.
##
## Hanya BASIS-nya yang disalin dari kamera; posisinya dibiarkan apa adanya,
## karena menyalin global_transform utuh akan menyeret penanda ke tempat kamera.
func _hadap_kamera() -> void:
	if not is_inside_tree():
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not is_instance_valid(cam):
		return
	var t: Transform3D = global_transform
	t.basis = cam.global_transform.basis
	global_transform = t


## Menaruh penanda tepat di atas puncak satu perabot.
func pasang_di(node: Node3D) -> void:
	if node == null or not is_instance_valid(node):
		return
	var b: AABB = _mesh_aabb(node)
	var puncak: float = 0.0
	if b.size != Vector3.ZERO:
		puncak = (b.position.y + b.size.y) * node.scale.y
	position = Vector3(node.position.x, puncak + HOVER, node.position.z)


func _process(delta: float) -> void:
	if mode == MODE_NONE:
		return
	_hadap_kamera()
	if mode != MODE_ALERT:
		return
	_t += delta
	# Denyut trigonometris, bukan Tween berulang: penanda muncul dan hilang
	# puluhan kali per hari dan Tween yang lupa di-kill menumpuk diam-diam.
	var gelombang: float = 0.5 + 0.5 * sin(_t * TAU * PULSE_HZ)
	var k: float = lerpf(PULSE_MIN, PULSE_MAX, gelombang)
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.scale = Vector3(k, k, k)


# ===========================================================================
# PERAKITAN
# ===========================================================================

func _apply_mode() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.visible = mode == MODE_ALERT
	if _bar != null and is_instance_valid(_bar):
		_bar.visible = mode == MODE_PROGRESS
	visible = mode != MODE_NONE


func _apply_progress() -> void:
	if _isi == null or not is_instance_valid(_isi):
		return
	var lebar: float = maxf(BAR_WIDTH * _nilai, 0.0001)
	_isi.scale = Vector3(_nilai if _nilai > 0.0 else 0.0001, 1.0, 1.0)
	# Bar tumbuh dari tepi KIRI, jadi titik tengahnya ikut bergeser.
	_isi.position = Vector3(-BAR_WIDTH * 0.5 + lebar * 0.5, 0.0, BAR_DEPTH * 0.6)
	if _isi_mat != null:
		# Hijau saat baru mulai, keemasan saat hampir matang (GDD 5.3.1: progress
		# bar hijau - kuning - merah; di sini merah disisakan untuk roti gosong).
		_isi_mat.albedo_color = Palette.SUCCESS.lerp(Palette.GOLD_STAR, _nilai)
		_isi_mat.emission = _isi_mat.albedo_color


func _build_bubble() -> Node3D:
	var root := Node3D.new()
	root.name = "Bubble"

	var badan: MeshInstance3D = _quad(
		Vector2(BUBBLE_RADIUS * 2.0, BUBBLE_RADIUS * 2.0), Palette.PANEL)
	root.add_child(badan)
	var tepi: MeshInstance3D = _quad(
		Vector2(BUBBLE_RADIUS * 2.24, BUBBLE_RADIUS * 2.24), Palette.WARNING)
	tepi.position = Vector3(0.0, 0.0, -0.004)
	root.add_child(tepi)

	# Tanda seru: satu batang dan satu titik.
	var batang: MeshInstance3D = _quad(Vector2(0.040, 0.135), Palette.WARNING)
	batang.position = Vector3(0.0, 0.032, 0.004)
	root.add_child(batang)
	var titik: MeshInstance3D = _quad(Vector2(0.044, 0.044), Palette.WARNING)
	titik.position = Vector3(0.0, -0.072, 0.004)
	root.add_child(titik)
	return root


func _build_bar() -> Node3D:
	var root := Node3D.new()
	root.name = "Bar"

	var latar: MeshInstance3D = _quad(
		Vector2(BAR_WIDTH + 0.030, BAR_HEIGHT + 0.030), Palette.DARK_CHOCOLATE)
	latar.name = "Latar"
	root.add_child(latar)
	var alur: MeshInstance3D = _quad(Vector2(BAR_WIDTH, BAR_HEIGHT), Palette.PANEL_ALT)
	alur.name = "Alur"
	alur.position = Vector3(0.0, 0.0, BAR_DEPTH * 0.3)
	root.add_child(alur)

	_isi = _quad(Vector2(BAR_WIDTH, BAR_HEIGHT * 0.72), Palette.SUCCESS)
	_isi.name = "Isi"
	_isi_mat = _isi.material_override as StandardMaterial3D
	root.add_child(_isi)
	_apply_progress()
	return root


## Satu bidang datar. Memakai BoxMesh setipis kertas alih-alih QuadMesh supaya
## tetap terlihat dari sisi mana pun tanpa mematikan culling.
##
## Materialnya SENGAJA tidak memakai billboard_mode: yang memutar penanda adalah
## node induknya, satu kali untuk seluruh lapisan (lihat catatan kepala berkas).
func _quad(ukuran: Vector2, warna: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(ukuran.x, ukuran.y, 0.006)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = warna
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.emission_enabled = true
	mat.emission = warna
	mat.emission_energy_multiplier = 0.45
	mat.disable_receive_shadows = true
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


## Kotak pembatas gabungan seluruh mesh keturunan, dalam koordinat lokal `node`.
func _mesh_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var ada: bool = false
	var antrean: Array[Node] = [node]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel: Transform3D = node.global_transform.affine_inverse() * mi.global_transform
		var dunia: AABB = rel * mi.get_aabb()
		if ada:
			box = box.merge(dunia)
		else:
			box = dunia
			ada = true
	return box
