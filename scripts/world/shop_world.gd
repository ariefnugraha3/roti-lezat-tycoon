class_name ShopWorld
extends Node3D
## Perakit dunia 3D toko roti.
##
## Seluruh isi toko dibangun ulang dari kode setiap kali tier lokasi berubah
## (GDD 4.2: bentuk bermutasi parametrik saat upgrade). ShopWorld juga menjadi
## panggung: ia mendengarkan EventBus dan memunculkan aktor pelanggan, driver,
## serta karyawan sesuai yang dilaporkan lapisan simulasi.
##
## ShopWorld TIDAK memutuskan apa pun soal ekonomi — ia hanya menggambarkannya.

# --- Meja kasir pembatas -------------------------------------------------
# Satu meja panjang membelah ruangan: dapur di belakangnya, toko di depannya.
## Ukuran meja (span, tebal, tinggi, posisi) dimiliki EquipmentFactory —
## lihat EquipmentFactory.divider_metrics(). ShopWorld tidak menyimpan
## salinannya supaya tidak ada dua sumber angka yang bisa berbeda diam-diam.
## Jarak rak roti di depan garis pembatas.
const RACK_OFFSET: float = 0.85
## Jarak berdiri kasir dari sisi DAPUR meja pembatas, meter. Dipakai bersama
## oleh staf kasir dan karakter pemain supaya keduanya berdiri di garis yang
## sama persis -- dua rumus terpisah untuk satu titik adalah akar setiap bug
## "kasir berdiri di dalam meja" di proyek ini.
const CASHIER_STAND_GAP: float = 0.28
## Nama jenis semu untuk meja kasir. Ia BUKAN anggota DECOR_KINDS: meja pembatas
## bagian dari bangunan dan tidak bisa dipindah pemain, tapi ia tetap boleh
## diketuk supaya karakter bisa disuruh berjaga di sana.
const KIND_CASHIER: String = "cashier"

## Tinggi balon pesanan di atas tablet RotiFood, meter dari alas tablet.
const TABLET_ALERT_Y: float = 0.36

# --- Kamera isometrik ----------------------------------------------------
# Isometrik yang sebenarnya = proyeksi ORTOGRAFIK + yaw 45 derajat. Kamera
# perspektif yang sekadar diputar 45 derajat hanya menghasilkan tampilan 3/4:
# garis-garis sejajar tetap menguncup ke titik hilang dan ubin lantai di tepi
# layar tergambar lebih besar daripada yang di tengah.
#
# Konsekuensi yang disengaja: pada ortografik JARAK kamera tidak lagi mengatur
# besar-kecilnya gambar. Zoom tiap sudut pandang diatur lewat Camera3D.size.
## Yaw kamera terhadap sumbu -Z. 45 derajat = memandang menyusur diagonal ruangan.
const CAM_YAW_DEG: float = 45.0
## Kemiringan isometrik sejati, atan(1/sqrt(2)). Hanya pada sudut inilah sumbu
## X, Y, dan Z terproyeksi sama panjang di layar.
const CAM_PITCH_DEG: float = 35.264389682754654
## Rasio layar acuan GDD 12.5 (1280x720). Camera3D.size mengatur sisi TEGAK,
## jadi rasio ini yang dipakai memastikan sisi mendatar ikut muat.
const VIEW_ASPECT: float = 16.0 / 9.0
## Kelonggaran tepi supaya dinding tidak menempel persis di bibir layar.
const FIT_MARGIN: float = 0.9

## Dinding yang berdiri ANTARA kamera dan isi ruangan. Kamera isometrik
## melayang di kuadran (+X, +Z), jadi dinding kanan dan kedua tunggak depan
## akan menutupi seluruh adegan kalau dibiarkan tampak. Menyembunyikannya
## adalah potongan (cutaway) baku tampilan isometrik — yang tersisa justru dua
## dinding jauh (belakang dan kiri) tempat jendela dan jam bergantung.
const NEAR_WALLS: Array[String] = ["WallRight", "WallFrontLeft", "WallFrontRight"]

## Sudut pandang yang bisa dipilih pemain (GDD 2: tahap persiapan berlangsung di
## dapur, tahap jualan di area kasir — masing-masing butuh framing sendiri).
const VIEW_ALL: String = "semua"
const VIEW_KITCHEN: String = "dapur"
const VIEW_SHOP: String = "toko"
const VIEWS: Array[String] = [VIEW_KITCHEN, VIEW_ALL, VIEW_SHOP]
const VIEW_TWEEN_TIME: float = 0.55

var main: Node = null

var room: Node3D = null
var camera: Camera3D = null
var env: WorldEnvironment = null

## Sudut pandang aktif: VIEW_KITCHEN / VIEW_ALL / VIEW_SHOP.
var view: String = VIEW_ALL
var _cam_focus: Vector3 = Vector3.ZERO
var _cam_tween: Tween = null

## Wadah agar mudah dibersihkan saat rebuild.
var fixtures: Node3D = null
var actors: Node3D = null

## Titik penting di lantai, dihitung ulang tiap rebuild.
var door_pos: Vector3 = Vector3(1.6, 0.0, 2.6)
var cashier_pos: Array[Vector3] = []
var pickup_pos: Vector3 = Vector3.ZERO
var mixer_pos: Array[Vector3] = []
var oven_pos: Array[Vector3] = []
var display_pos: Array[Vector3] = []
## Gudang Penyimpanan (kulkas + lemari). Selalu satu buah, tapi tetap disimpan
## sebagai array supaya seluruh jalur Mode Dekorasi memperlakukannya persis
## sama dengan perabot lain.
var storage_pos: Array[Vector3] = []
## Rotasi tiap perabot dalam derajat (0 atau 90), sejajar array posisi di atas.
## Rotasi 90 menukar sisi jejak lantainya: rak 2x1 menjadi 1x2.
var mixer_rot: Array[int] = []
var oven_rot: Array[int] = []
var display_rot: Array[int] = []
var storage_rot: Array[int] = []
var queue_pos: Array[Vector3] = []
## Titik serah-terima roti di sisi DAPUR meja pembatas. Baker berhenti di sini
## alih-alih menembus meja untuk mencapai rak yang ada di zona toko.
var handover_pos: Array[Vector3] = []

var _mixers: Array[Node3D] = []
var _ovens: Array[Node3D] = []
var _displays: Array[Node3D] = []
var _storages: Array[Node3D] = []
var _tablet: Node3D = null          # tablet RotiFood di ujung meja kasir
var _tablet_marker: StationMarker = null
var _customers: Dictionary = {}     # customer_id -> CustomerActor
var _drivers: Dictionary = {}       # order_id -> DriverActor
var _staff: Dictionary = {}         # staff_id -> StaffActor
var _bread_nodes: Dictionary = {}   # "rack:slot" -> Node3D
var _rain: Node = null
var _t: float = 0.0
var _seed_counter: int = 0
var _built_tier: int = -1


func setup(m: Node) -> void:
	main = m
	_build_static()
	rebuild()
	_connect_events()


# ===========================================================================
# PERAKITAN
# ===========================================================================

func _build_static() -> void:
	env = EquipmentFactory.build_environment()
	if env != null:
		add_child(env)

	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	# size mengatur sisi TEGAK kotak pandang; sisi mendatarnya ikut rasio layar.
	camera.keep_aspect = Camera3D.KEEP_HEIGHT
	camera.near = 0.05
	camera.far = 120.0
	add_child(camera)
	_place_camera()

	fixtures = ProceduralMeshFactory.group("Fixtures")
	add_child(fixtures)
	actors = ProceduralMeshFactory.group("Actors")
	add_child(actors)


## Menempatkan kamera sesuai sudut pandang aktif, tanpa animasi.
func _place_camera() -> void:
	_apply_view(true)


## Mengganti sudut pandang. Dipanggil dari tombol di HUD.
func set_view(v: String, instant: bool = false) -> void:
	if not VIEWS.has(v) or camera == null:
		return
	view = v
	_apply_view(instant)
	AudioBus.sfx("pop")


## Pose kamera isometrik untuk satu sudut pandang:
## [posisi, titik fokus, ukuran kotak ortografik].
##
## Petak lantai w x d yang dipandang dari yaw 45 derajat tergambar di layar
## sebagai BELAH KETUPAT, bukan persegi panjang. Kedua sisinya:
##   mendatar = (w + d) * cos(yaw)
##   tegak    = (w + d) * cos(yaw) * sin(pitch)  + tinggi dinding * cos(pitch)
## Suku terakhir itu yang menjamin puncak dinding belakang tidak terpenggal —
## pada ortografik tidak ada lagi trik "naikkan kamera supaya dinding lewat".
##
## Jarak kamera TIDAK memengaruhi framing di sini; ia hanya dipilih cukup jauh
## untuk melayang di atas dinding dan menjaga seluruh ruangan tetap di antara
## bidang potong dekat dan jauh. Yang mengatur zoom adalah `size`.
func _camera_pose(v: String) -> Array:
	var tier: int = GameState.location_tier
	var w: float = EquipmentFactory.room_width(tier)
	var d: float = EquipmentFactory.room_depth(tier)
	var h: float = EquipmentFactory.room_height(tier)
	var wall: float = EquipmentFactory.room_wall_thickness()
	var z_div: float = EquipmentFactory.partition_z(tier)
	var z_back_wall: float = -d * 0.5 + wall
	var z_front: float = d * 0.5 - wall - 0.30

	# Kedalaman lantai yang wajib terlihat, dan titik yang dipandang kamera.
	var need_d: float = d
	var focus_z: float = z_div
	match v:
		VIEW_KITCHEN:
			need_d = z_div - z_back_wall
			focus_z = (z_back_wall + z_div) * 0.5
		VIEW_SHOP:
			need_d = z_front - z_div
			focus_z = (z_div + z_front) * 0.5

	var pitch: float = deg_to_rad(CAM_PITCH_DEG)
	var yaw: float = deg_to_rad(CAM_YAW_DEG)

	var ketupat_w: float = (w + need_d) * cos(yaw)
	var ketupat_h: float = ketupat_w * sin(pitch) + h * cos(pitch)
	var size: float = maxf(ketupat_h, ketupat_w / VIEW_ASPECT) + FIT_MARGIN

	# Titik fokus diangkat setengah tinggi dinding, BUKAN dibiarkan di lantai.
	# Belah ketupat lantai membentang setangkup di atas dan di bawah fokus, tapi
	# dinding hanya menjulang ke ATAS: memusatkan kamera di lantai membuat puncak
	# dinding kiri terpenggal sementara sepertiga bawah layar melompong.
	var focus_y: float = h * 0.5

	# Jarak dipakai bersama oleh ketiga sudut pandang, jadi arah pandang tetap
	# PERSIS sama selama tween berpindah zona — isometrik yang sudutnya bergoyang
	# sedikit saja sudah kehilangan seluruh kesan isometriknya.
	var l: float = maxf(
		sqrt(w * w + d * d) * 0.5 + 2.0,
		(h + 1.5) / sin(pitch))

	var focus := Vector3(0.0, focus_y, focus_z)
	var offset := Vector3(
		sin(yaw) * cos(pitch),
		sin(pitch),
		cos(yaw) * cos(pitch)) * l
	return [focus + offset, focus, size]


func _apply_view(instant: bool) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var pose: Array = _camera_pose(view)
	var target_pos: Vector3 = pose[0]
	var target_focus: Vector3 = pose[1]
	var target_size: float = float(pose[2])

	if _cam_tween != null and _cam_tween.is_valid():
		_cam_tween.kill()
	_cam_tween = null

	if instant or _cam_focus == Vector3.ZERO:
		camera.position = target_pos
		camera.size = target_size
		_cam_focus = target_focus
		_look_safe(target_focus)
		return

	var from_pos: Vector3 = camera.position
	var from_focus: Vector3 = _cam_focus
	# Zoom ikut dianimasikan: pada ortografik INILAH yang terasa sebagai
	# "kamera mendekat", karena menggeser posisi tidak mengubah apa pun.
	var from_size: float = camera.size
	_cam_tween = create_tween()
	_cam_tween.tween_method(
		func(t: float) -> void:
			if camera == null or not is_instance_valid(camera):
				return
			camera.position = from_pos.lerp(target_pos, t)
			camera.size = lerpf(from_size, target_size, t)
			_cam_focus = from_focus.lerp(target_focus, t)
			_look_safe(_cam_focus),
		0.0, 1.0, VIEW_TWEEN_TIME
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## look_at() memicu error bila kamera berimpit dengan titik fokusnya.
func _look_safe(focus: Vector3) -> void:
	if camera.position.distance_squared_to(focus) < 0.0004:
		return
	camera.look_at(focus, Vector3.UP)


## Membangun ulang seluruh isi toko sesuai tier lokasi saat ini.
func rebuild() -> void:
	var tier: int = GameState.location_tier
	_built_tier = tier

	# remove_child() dulu, baru queue_free(): queue_free() bersifat TERTUNDA, jadi
	# tanpa remove_child perabot lama masih terdaftar sebagai anak sampai akhir
	# frame. Dua kali rebuild() dalam satu frame (mis. upgrade lokasi lalu keluar
	# dari Mode Dekorasi) akan menumpuk dua set perabot di tempat yang sama.
	for child in fixtures.get_children():
		fixtures.remove_child(child)
		child.queue_free()
	_mixers.clear()
	_ovens.clear()
	_displays.clear()
	_storages.clear()
	_bread_nodes.clear()
	_clear_markers()
	nav_invalidate()

	var loc: Dictionary = LocationDB.entry(tier)
	if loc.is_empty():
		return

	room = EquipmentFactory.build_room(tier)
	if room != null:
		fixtures.add_child(room)
		_hide_near_walls()

	_layout(loc)
	_place_stations()
	_place_counters(loc)
	_refresh_display_bread()
	_refresh_staff()
	_refresh_player()
	_place_camera()


## Menyembunyikan dinding yang berdiri di antara kamera isometrik dan isi toko.
##
## Dindingnya tetap DIBANGUN, bukan dihapus: lis kaki, jendela, dan jam masih
## menempel padanya, dan sekali sudut kamera diubah cukup menyalakannya lagi.
func _hide_near_walls() -> void:
	if room == null:
		return
	for nama in NEAR_WALLS:
		var dinding := room.get_node_or_null(NodePath(nama)) as Node3D
		if dinding != null:
			dinding.visible = false


## Menghitung titik-titik lantai DARI dimensi ruangan yang sebenarnya.
##
## Dimensi diambil dari EquipmentFactory (pemilik tunggalnya). Dulu fungsi ini
## punya rumus lebar sendiri, akibatnya mixer dan oven mendarat di belakang
## dinding belakang dan area dapur tidak pernah terlihat.
##
## Urutan zona dari dinding belakang ke pintu (GDD 2 dan 6):
##   dinding belakang -> mixer & oven -> MEJA KASIR PEMBATAS -> rak roti
##   -> antrean -> pintu
## Jadi dapur ada di BELAKANG (Z kecil) dan toko di DEPAN (Z besar), keduanya
## dipisahkan satu meja kasir panjang di garis partition_z.
func _layout(loc: Dictionary) -> void:
	var tier: int = int(loc.get("tier", 1))
	var w: float = EquipmentFactory.room_width(tier)
	var d: float = EquipmentFactory.room_depth(tier)
	var wall: float = EquipmentFactory.room_wall_thickness()

	# Permukaan DALAM dinding — dipakai titik-titik yang BUKAN perabot
	# (pintu, antrean, meja ojol); perabot sendiri memakai anchor ubin.
	var x_in: float = w * 0.5 - wall - 0.35
	# Meja kasir berdiri di SATU BARIS UBIN miliknya sendiri (baris pertama zona
	# toko), bukan menunggangi garis zona di antara dua baris seperti dulu.
	var z_meja: float = EquipmentFactory.counter_z(tier)
	var z_rack: float = EquipmentFactory.tile_z(tier, EquipmentFactory.shop_row_min(tier))
	var z_front: float = d * 0.5 - wall - 0.30

	mixer_pos.clear()
	oven_pos.clear()
	display_pos.clear()
	storage_pos.clear()
	mixer_rot.clear()
	oven_rot.clear()
	display_rot.clear()
	storage_rot.clear()
	cashier_pos.clear()
	queue_pos.clear()
	handover_pos.clear()

	# --- Area dapur: oven berbaris di baris paling belakang, mixer dua baris
	# di depannya. Dihitung dalam ANCHOR UBIN dan melangkah selebar jejak
	# masing-masing alat, bukan dengan jarak meter yang bisa saling tindih:
	# satu Oven Conveyor Tier 5 saja sudah memakan empat ubin.
	var n_mix: int = int(loc.get("mixer_slots", 1))
	var n_oven: int = int(loc.get("oven_slots", 1))
	var jejak_oven: Vector2i = EquipmentFactory.footprint("oven", GameState.oven_tier)
	var jejak_mix: Vector2i = EquipmentFactory.footprint("mixer", GameState.mixer_tier)
	var baris_mix: int = mini(jejak_oven.y + 1, EquipmentFactory.kitchen_row_max(tier))

	for i in n_oven:
		oven_pos.append(_pusat_jejak(Vector2i(i * jejak_oven.x, 0), jejak_oven, tier))
		oven_rot.append(0)
	for i in n_mix:
		mixer_pos.append(_pusat_jejak(
			Vector2i(i * jejak_mix.x, baris_mix), jejak_mix, tier))
		mixer_rot.append(0)

	# --- Gudang Penyimpanan: dirapatkan ke dinding KANAN dapur ---
	# Jejaknya ikut tier LOKASI, bukan tier alat (GDD 5.2.2), dan selalu SATU
	# baris ubin dalam karena kulkas dan lemarinya berjajar bersebelahan
	# menghadap depan. Ditaruh di ujung baris paling belakang supaya lorong
	# oven-mixer-meja tetap lapang; pemain boleh memindahkannya sendiri di
	# Mode Dekorasi.
	var jejak_gudang: Vector2i = EquipmentFactory.footprint("storage", tier)
	var kolom_gudang: int = maxi(
		EquipmentFactory.floor_cols(tier) - jejak_gudang.x, 0)
	storage_pos.append(_pusat_jejak(Vector2i(kolom_gudang, 0), jejak_gudang, tier))
	storage_rot.append(0)

	# --- Meja kasir pembatas: satu meja panjang persis di garis pemisah ---
	# Mesin kasir disebar merata di atas bentang meja, tidak pernah masuk ke
	# celah jalan staf di sisi +X.
	var dv: Dictionary = _divider_metrics(tier)
	var span: float = float(dv["span"])
	var cx: float = float(dv["cx"])
	var n_cash: int = int(loc.get("cashier_slots", 1))
	for i in n_cash:
		# Sebaran X memakai fungsi yang SAMA dengan yang dipakai mesh meja untuk
		# menaruh mesin kasirnya, jadi kasir selalu berdiri tepat di belakang
		# mesinnya — bukan bergeser beberapa sentimeter seperti dulu.
		cashier_pos.append(Vector3(
			cx + EquipmentFactory.divider_register_x(i, n_cash, span), 0.0, z_meja))

	# Titik serah roti: ujung meja dekat celah jalan, di sisi dapur.
	handover_pos.append(Vector3(
		cx + span * 0.45, 0.0, z_meja - (EquipmentFactory.DIVIDER_DEPTH * 0.5 + 0.28)))

	# --- Area toko: rak roti berjajar DI DEPAN meja pembatas, menghadap pembeli ---
	# Dijajarkan rapat selebar jejaknya lalu ditengahkan pada baris ubinnya.
	var n_rack: int = int(loc.get("rack_slots", 1))
	var jejak_rak: Vector2i = EquipmentFactory.footprint("display", GameState.display_tier)
	var baris_rak: int = EquipmentFactory.shop_row_min(tier)
	var kolom_rak: int = EquipmentFactory.floor_cols(tier)
	var mulai: int = maxi((kolom_rak - n_rack * jejak_rak.x) / 2, 0)
	for i in n_rack:
		display_pos.append(_pusat_jejak(
			Vector2i(mulai + i * jejak_rak.x, baris_rak), jejak_rak, tier))
		display_rot.append(0)

	# Pintu berada di celah tengah dinding depan.
	door_pos = Vector3(0.0, 0.0, z_front)

	# Antrean membentang dari depan rak roti ke arah pintu; bila kapasitasnya
	# melebihi ruang yang ada, sisanya memang mengekor keluar pintu
	# (GDD 8.3: antrean meluber ke trotoar).
	var queue_cap: int = int(loc.get("queue_cap", 4))
	for i in mini(queue_cap, 12):
		queue_pos.append(Vector3(0.0, 0.0, z_rack + 0.75 + float(i) * 0.48))

	# GDD 3.6.B: Meja Khusus Ojol baru ada di Tier 3 ke atas. Ditaruh mepet
	# dinding kiri dekat pintu — antrean pembeli membentang di X = 0, jadi
	# driver tidak pernah bersenggolan dengannya.
	pickup_pos = Vector3(-x_in + 0.45, 0.0, z_front - 0.85) if tier >= 3 else Vector3.ZERO

	# Denah hasil Mode Dekorasi menimpa tata letak bawaan (GDD "Dekorasi &
	# Kustomisasi": posisi alat memengaruhi alur kerja, bukan cuma tampilan).
	_apply_decor_layout()


## Titik tengah sebuah JEJAK lantai yang dimulai di petak `anchor`.
##
## Anchor selalu petak pojok belakang-kiri jejak, jadi rak 2x1 di anchor (2,7)
## menempati petak (2,7) dan (3,7) dan berpusat di antara keduanya.
func _pusat_jejak(anchor: Vector2i, jejak: Vector2i, tier: int, y: float = 0.0) -> Vector3:
	var t: float = EquipmentFactory.FLOOR_TILE
	return Vector3(
		EquipmentFactory.tile_x(tier, anchor.x) + float(jejak.x - 1) * 0.5 * t,
		y,
		EquipmentFactory.tile_z(tier, anchor.y) + float(jejak.y - 1) * 0.5 * t)


## Kebalikan _pusat_jejak(): petak anchor dari titik tengah sebuah jejak.
func _anchor_jejak(pusat: Vector3, jejak: Vector2i, tier: int) -> Vector2i:
	var t: float = EquipmentFactory.FLOOR_TILE
	return Vector2i(
		EquipmentFactory.tile_col_at(tier, pusat.x - float(jejak.x - 1) * 0.5 * t),
		EquipmentFactory.tile_row_at(tier, pusat.z - float(jejak.y - 1) * 0.5 * t))


## Ukuran meja kasir pembatas untuk satu tier lokasi.
## Ukuran meja kasir pembatas untuk satu tier lokasi.
##
## Meja menutup DIVIDER_SPAN_RATIO bagian lebar ruangan dan dirapatkan ke
## dinding kiri, sehingga sisa lebarnya menjadi satu celah jalan di sisi +X:
## satu-satunya jalan staf keluar-masuk dapur. Dipakai bersama oleh _layout(),
## _place_counters(), dan _driver_wait_spot() supaya meja, kasirnya, dan orang
## yang berdiri di sekitarnya tidak pernah berbeda hitungan.
##
## Dimensi ruangan tetap ditanya ke EquipmentFactory — fungsi ini hanya membagi
## angka yang sudah dimilikinya.
func _divider_metrics(tier: int) -> Dictionary:
	return EquipmentFactory.divider_metrics(tier)


## Membaca GameState.decor["layout"] dan memindahkan titik-titik stasiun sesuai
## petak yang dipilih pemain. Diam-diam dilewati bila belum pernah didekorasi.
func _apply_decor_layout() -> void:
	var raw: Variant = GameState.decor.get("layout", {})
	if not (raw is Dictionary) or (raw as Dictionary).is_empty():
		return
	var layout: Dictionary = raw

	var grid: Dictionary = GameState.decor.get("grid", {})
	var gw: int = int(grid.get("w", 0))
	var gh: int = int(grid.get("h", 0))
	if gw <= 0 or gh <= 0:
		return

	var tier: int = GameState.location_tier
	var cols: int = EquipmentFactory.floor_cols(tier)
	var rows: int = EquipmentFactory.floor_rows(tier)
	# Denah yang ditulis untuk grid berukuran LAIN (toko baru di-upgrade, atau
	# save dari versi sebelum petak = ubin) tidak bisa dipetakan petak-per-petak.
	# Dulu ia dipaksa lewat rumus meter dan hasilnya perabot berjejalan di sudut;
	# sekarang diabaikan saja, dan denah bawaan tier ini yang dipakai.
	if gw != cols or gh != rows:
		return

	# "counter" sengaja TIDAK ada di sini: meja kasir bagian dari bangunan dan
	# tidak bisa dipindah, jadi entri counter pada denah lama diabaikan.
	var baru: Dictionary = {"mixer": [], "oven": [], "display": [], "storage": []}
	for key in layout.keys():
		var entri: Dictionary = _baca_entri_denah(layout[key])
		var kind: String = String(entri.get("kind", ""))
		if not baru.has(kind):
			continue
		var parts: PackedStringArray = String(key).split(",")
		if parts.size() != 2:
			continue
		# Petak (0,0) ada di pojok belakang-kiri; sumbu Z negatif = arah dapur.
		(baru[kind] as Array).append({
			"anchor": Vector2i(int(parts[0]), int(parts[1])),
			"rot": int(entri.get("rot", 0)),
		})

	var baris_dapur_max: int = EquipmentFactory.kitchen_row_max(tier)
	var baris_toko_min: int = EquipmentFactory.shop_row_min(tier)
	var baris_akhir: int = rows - 1

	# Bentrokan jejak TIDAK diurus di sini. _place_stations() yang memutuskannya,
	# karena hanya di sana tier alat yang terpasang — dan karenanya jejaknya —
	# sudah diketahui.
	if not (baru["mixer"] as Array).is_empty():
		_terapkan_denah(baru["mixer"], "mixer", GameState.mixer_tier,
			0, baris_dapur_max, mixer_pos, mixer_rot)
	if not (baru["oven"] as Array).is_empty():
		_terapkan_denah(baru["oven"], "oven", GameState.oven_tier,
			0, baris_dapur_max, oven_pos, oven_rot)
	if not (baru["storage"] as Array).is_empty():
		_terapkan_denah(baru["storage"], "storage", GameState.location_tier,
			0, baris_dapur_max, storage_pos, storage_rot)
	if not (baru["display"] as Array).is_empty():
		_terapkan_denah(baru["display"], "display", GameState.display_tier,
			baris_toko_min, baris_akhir, display_pos, display_rot)


## Satu entri denah bisa berupa String lama ("display") atau Dictionary baru
## ({"kind": "display", "rot": 90}). Keduanya wajib terbaca — save lama harus
## tetap bisa dibuka setelah pembaruan (GDD 12.6).
func _baca_entri_denah(nilai: Variant) -> Dictionary:
	if nilai is Dictionary:
		return nilai as Dictionary
	return {"kind": String(nilai), "rot": 0}


## Mengubah daftar {anchor, rot} menjadi titik pusat dunia + rotasi.
## Baris di luar zona ditarik ke baris terdekat DI DALAM zona; kolom dan
## rotasinya dibiarkan apa adanya.
func _terapkan_denah(src: Array, kind: String, tier_alat: int,
		baris_min: int, baris_max: int,
		keluar_pos: Array[Vector3], keluar_rot: Array[int]) -> void:
	var tier: int = GameState.location_tier
	var lo: int = mini(baris_min, baris_max)
	var hi: int = maxi(baris_min, baris_max)
	keluar_pos.clear()
	keluar_rot.clear()
	for v in src:
		var e: Dictionary = v
		var rot: int = int(e["rot"])
		var jejak: Vector2i = EquipmentFactory.footprint_rotated(kind, tier_alat, rot)
		var anchor: Vector2i = e["anchor"]
		anchor.y = clampi(anchor.y, lo, maxi(hi - jejak.y + 1, lo))
		keluar_pos.append(_pusat_jejak(anchor, jejak, tier))
		keluar_rot.append(rot)


func _to_vec3_array(src: Array) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for v in src:
		out.append(v as Vector3)
	return out


func _place_stations() -> void:
	var tier: int = GameState.location_tier
	# Satu daftar ubin terhuni untuk SELURUH perabot ruangan ini.
	var huni: Dictionary = {}
	var dapur_hi: int = EquipmentFactory.kitchen_row_max(tier)
	var toko_lo: int = EquipmentFactory.shop_row_min(tier)
	var baris_akhir: int = EquipmentFactory.floor_rows(tier) - 1

	for i in mixer_pos.size():
		var m: Node3D = EquipmentFactory.build_mixer(GameState.mixer_tier)
		m.name = "Mixer%d" % i
		m.position = mixer_pos[i]
		fixtures.add_child(m)
		_settle(m, "mixer", GameState.mixer_tier, _rot_at(mixer_rot, i),
			huni, 0, dapur_hi)
		mixer_pos[i] = m.position
		_mixers.append(m)

	for i in oven_pos.size():
		var o: Node3D = EquipmentFactory.build_oven(GameState.oven_tier)
		o.name = "Oven%d" % i
		o.position = oven_pos[i]
		fixtures.add_child(o)
		_settle(o, "oven", GameState.oven_tier, _rot_at(oven_rot, i),
			huni, 0, dapur_hi)
		oven_pos[i] = o.position
		_ovens.append(o)

	# Gudang didudukkan SEBELUM rak display tapi SESUDAH alat masak: ia berbagi
	# zona dapur dengan mixer dan oven, jadi jejaknya harus ikut daftar `huni`
	# yang sama. Tier yang dipakai adalah tier LOKASI.
	for i in storage_pos.size():
		var g: Node3D = EquipmentFactory.build_storage(tier)
		g.name = "Storage%d" % i
		g.position = storage_pos[i]
		fixtures.add_child(g)
		_settle(g, "storage", tier, _rot_at(storage_rot, i), huni, 0, dapur_hi)
		storage_pos[i] = g.position
		_storages.append(g)

	for i in display_pos.size():
		var d: Node3D = EquipmentFactory.build_display(GameState.display_tier)
		d.name = "Display%d" % i
		d.position = display_pos[i]
		fixtures.add_child(d)
		_settle(d, "display", GameState.display_tier, _rot_at(display_rot, i),
			huni, toko_lo, baris_akhir)
		display_pos[i] = d.position
		_displays.append(d)


## Rotasi perabot ke-`i`, 0 bila daftarnya belum terisi (mis. denah lama).
func _rot_at(daftar: Array[int], i: int) -> int:
	return daftar[i] if i < daftar.size() else 0


## Mendudukkan satu perabot pada JEJAK ubin yang seluruhnya bebas.
##
## Perabot tidak lagi "menempati satu ubin": ia menempati jejak resminya
## (EquipmentFactory.FOOTPRINTS) — rak 2x1, Oven Conveyor Tier 5 bahkan 4x1.
## Seluruh petak jejak itu harus bebas, berada dalam zona yang benar, dan masih
## di dalam ruangan. Kalau tidak muat, dicari anchor lain melingkar ke luar.
##
## Karena mesh sudah diskalakan pas ke jejaknya, dua perabot yang jejaknya tidak
## bersinggungan dijamin tidak bersinggungan pula badannya — tidak perlu lagi
## uji tabrakan AABB seperti versi sebelumnya.
func _settle(node: Node3D, kind: String, tier_alat: int, rot: int,
		huni: Dictionary, baris_lo: int, baris_hi: int) -> void:
	var tier: int = GameState.location_tier
	EquipmentFactory.fit_to_footprint(node, kind, tier_alat)
	node.rotation_degrees = Vector3(0.0, float(rot), 0.0)

	var jejak: Vector2i = EquipmentFactory.footprint_rotated(kind, tier_alat, rot)
	var cols: int = EquipmentFactory.floor_cols(tier)
	var asal: Vector2i = _anchor_jejak(node.position, jejak, tier)
	asal.y = clampi(asal.y, baris_lo, maxi(baris_hi - jejak.y + 1, baris_lo))

	for kandidat in _petak_sekitar(asal, cols, baris_lo, baris_hi):
		if not _jejak_bebas(kandidat, jejak, cols, baris_lo, baris_hi, huni):
			continue
		node.position = _pusat_jejak(kandidat, jejak, tier, node.position.y)
		_fit_inside_walls(node)
		_tandai_jejak(kandidat, jejak, huni)
		return

	# Zona penuh: tetap di anchor yang diminta. Lebih baik dua perabot
	# berdempetan daripada satu di antaranya lenyap dari ruangan.
	node.position = _pusat_jejak(asal, jejak, tier, node.position.y)
	_fit_inside_walls(node)
	_tandai_jejak(asal, jejak, huni)


## Apakah seluruh petak jejak mulai `anchor` masih di dalam ruangan, di dalam
## zona [baris_lo, baris_hi], dan belum ditempati perabot lain.
func _jejak_bebas(anchor: Vector2i, jejak: Vector2i, cols: int,
		baris_lo: int, baris_hi: int, huni: Dictionary) -> bool:
	if anchor.x < 0 or anchor.x + jejak.x > cols:
		return false
	if anchor.y < baris_lo or anchor.y + jejak.y - 1 > baris_hi:
		return false
	for dx in jejak.x:
		for dy in jejak.y:
			if huni.has(Vector2i(anchor.x + dx, anchor.y + dy)):
				return false
	return true


## Menandai seluruh petak jejak sebagai terhuni.
func _tandai_jejak(anchor: Vector2i, jejak: Vector2i, huni: Dictionary) -> void:
	for dx in jejak.x:
		for dy in jejak.y:
			huni[Vector2i(anchor.x + dx, anchor.y + dy)] = true


## Daftar ubin mulai dari `asal`, melebar melingkar ke luar, dibatasi zona.
func _petak_sekitar(asal: Vector2i, cols: int, baris_lo: int, baris_hi: int) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if asal.x >= 0 and asal.x < cols and asal.y >= baris_lo and asal.y <= baris_hi:
		out.append(asal)
	var jangkauan: int = maxi(cols, baris_hi - baris_lo + 1)
	for r in range(1, jangkauan + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				# Hanya tepi cincin sejauh r; bagian dalamnya sudah terdaftar.
				if absi(dx) != r and absi(dy) != r:
					continue
				var k := Vector2i(asal.x + dx, asal.y + dy)
				if k.x < 0 or k.x >= cols or k.y < baris_lo or k.y > baris_hi:
					continue
				out.append(k)
	return out


## Menggeser satu perabot agar SELURUH badannya masuk ke dalam dinding, lalu
## menguncinya ke KISI UBIN 50 cm.
##
## Kelonggaran tetap tidak bisa diandalkan: pemain boleh membeli Oven Tier 5
## (Conveyor Belt, lebar 1,7 m) selagi tokonya masih Garasi Tier 1 — Pasar tidak
## menguncinya. Maka ukuran nyata mesh-lah yang dipakai, bukan tebakan.
##
## Fungsi ini HANYA menjepit; ia tidak lagi mengunci apa pun ke kisi.
##
## Penguncian sepenuhnya tugas _settle(), yang menghitung titik tengah dari
## ANCHOR + JEJAK. Dulu fungsi ini ikut mengunci ke pusat ubin terdekat, dan itu
## keliru begitu ada jejak berukuran genap: rak 2x1 berpusat tepat di TEPI ubin,
## sehingga "pusat ubin terdekat" menggesernya setengah ubin ke samping — rak
## yang ditaruh di petak 2 mendarat di petak 3.
##
## Perabot yang badannya menjorok ke dinding cukup digeser beberapa sentimeter
## di dalam jejaknya sendiri, seperti lemari yang dirapatkan ke tembok.
func _fit_inside_walls(node: Node3D) -> void:
	var tier: int = GameState.location_tier
	# Permukaan DALAM dinding yang sesungguhnya — bukan WALL_THICK penuh.
	var wall: float = EquipmentFactory.wall_inset()
	var x_lim: float = EquipmentFactory.room_width(tier) * 0.5 - wall
	var z_lim: float = EquipmentFactory.room_depth(tier) * 0.5 - wall

	# _local_aabb() melaporkan mesh TANPA rotasi node-nya sendiri. Rak yang
	# diputar 90 derajat karena itu akan terlihat masih 2 ubin lebar pada sumbu
	# X, dan dijepit ke tempat yang salah. Basis node diterapkan lebih dulu.
	var box: AABB = Transform3D(node.basis, Vector3.ZERO) * _local_aabb(node)
	if box.size == Vector3.ZERO:
		return

	# Tepi mesh relatif terhadap titik pusat node.
	var kiri: float = box.position.x
	var kanan: float = box.position.x + box.size.x
	var belakang: float = box.position.z
	var depan: float = box.position.z + box.size.z

	var p: Vector3 = node.position
	# Barang yang lebih lebar dari ruangannya dikecilkan, bukan ditanam di dinding.
	var lebar: float = kanan - kiri
	if lebar > x_lim * 2.0 and lebar > 0.001:
		var skala: float = (x_lim * 2.0) / lebar
		node.scale *= skala
		box = Transform3D(node.basis, Vector3.ZERO) * _local_aabb(node)
		kiri = box.position.x
		kanan = box.position.x + box.size.x
		belakang = box.position.z
		depan = box.position.z + box.size.z

	p.x = clampf(p.x, -x_lim - kiri, x_lim - kanan)
	p.z = clampf(p.z, -z_lim - belakang, z_lim - depan)
	node.position = p


## Titik tengah lorong kerja dapur pada sumbu Z: antara tepi depan alat masak
## dan sisi belakang meja pembatas.
##
## Tidak boleh memakai offset tetap dari posisi mixer: tinggi-rendahnya tier
## mengubah kedalaman alat, dan offset tetap pernah membuat baker berdiri
## tertanam di dalam meja kasir.
func _kitchen_aisle_z(mixer_index: int) -> float:
	var z_meja: float = EquipmentFactory.counter_z(GameState.location_tier)
	var meja_belakang: float = z_meja - EquipmentFactory.DIVIDER_DEPTH * 0.5
	var alat_depan: float = -EquipmentFactory.room_depth(GameState.location_tier) * 0.5 \
		+ EquipmentFactory.room_wall_thickness()
	if mixer_index >= 0 and mixer_index < _mixers.size():
		var n: Node3D = _mixers[mixer_index]
		if n != null and is_instance_valid(n):
			var box: AABB = _local_aabb(n)
			if box.size != Vector3.ZERO:
				alat_depan = n.position.z + box.position.z + box.size.z
	return (alat_depan + meja_belakang) * 0.5


## Kotak pembatas gabungan seluruh mesh keturunan, dalam koordinat lokal node.
func _local_aabb(node: Node3D) -> AABB:
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


## Memasang satu meja kasir panjang sebagai pembatas dapur dan toko, lengkap
## dengan tablet RotiFood di atasnya. Meja khusus ojol (Tier 3+) tetap berdiri
## sendiri di dekat pintu.
func _place_counters(loc: Dictionary) -> void:
	var tier: int = int(loc.get("tier", 1))
	var dv: Dictionary = _divider_metrics(tier)

	# Jumlah mesin kasir mengikuti slot lokasi (1..3 menurut LocationDB); dibatasi
	# 4 supaya denah Mode Dekorasi yang aneh tidak pernah memenuhi meja.
	var registers: int = clampi(int(loc.get("cashier_slots", 1)), 1, 4)
	var counter: Node3D = EquipmentFactory.build_divider_counter(
		tier, float(dv["span"]), registers)
	counter.name = "DividerCounter"
	counter.position = Vector3(float(dv["cx"]), 0.0, float(dv["z"]))
	fixtures.add_child(counter)
	# TIDAK dijepit ke dinding, dan itu disengaja.
	#
	# Meja ini bukan perabot lepas melainkan bagian bangunan: bentang, kolom, dan
	# barisnya seluruhnya diturunkan dari ukuran ruangan, jadi ia mustahil keluar
	# gedung. Ujung kirinya memang terbenam ~5 cm di dalam dinding samping —
	# itulah yang membuatnya rata dengan tepi ubin kolom 0. Penjepit umum
	# memakai kelonggaran 4 cm dari permukaan dalam dinding dan akan mendorong
	# meja 18 cm ke kanan, melepaskannya dari kisi lantai.

	var slot: Node3D = counter.get_node_or_null("Tablet") as Node3D
	var tablet: Node3D = EquipmentFactory.build_tablet()
	if slot != null:
		slot.add_child(tablet)
	else:
		tablet.position = counter.position + Vector3(0.0, EquipmentFactory.DIVIDER_HEIGHT, 0.0)
		fixtures.add_child(tablet)
	# Disimpan supaya balon pesanan RotiFood punya tempat bergantung (GDD 3.6.A).
	_tablet = tablet
	_tablet_marker = null

	if LocationDB.has_pickup_counter(tier):
		var p: Node3D = EquipmentFactory.build_pickup_counter()
		p.name = "PickupCounter"
		p.position = pickup_pos
		fixtures.add_child(p)
		# Meja ojol ikut aturan jejak lantai yang sama (2 x 1 ubin).
		EquipmentFactory.fit_to_footprint(p, "pickup", tier)
		_fit_inside_walls(p)
		pickup_pos = p.position


# ===========================================================================
# MODE DEKORASI — API untuk DecorController
# ===========================================================================
# Selama Mode Dekorasi, DUNIA 3D yang menjadi sumber kebenaran denah, bukan
# GameState.decor. Pemain menggeser perabot sungguhan di layar; denahnya baru
# ditulis kembali ke GameState saat ia menekan Selesai (decor_save_layout()).
#
# Itu sebabnya seluruh fungsi di bawah bekerja langsung pada array
# mixer_pos/oven_pos/display_pos dan node-nya: satu rebuild() penuh per frame
# seret akan membongkar-pasang seluruh ruangan enam puluh kali per detik.

## Jenis perabot yang boleh dipindah pemain.
##
## "storage" ikut di sini walaupun ia tidak bisa di-upgrade: yang tidak bisa
## dibeli pemain adalah BENTUKNYA, bukan tempatnya (GDD 5.2.2 + GDD 7 "Mode
## Dekorasi").
const DECOR_KINDS: Array[String] = ["mixer", "oven", "display", "storage"]
## Kelonggaran kotak sentuh perabot saat dipilih, meter.
const PICK_PADDING: float = 0.04

var _decor: DecorController = null


## Pengendali Mode Dekorasi, dibuat saat pertama dibutuhkan.
##
## Dibuat DI SINI, bukan di layar UI, karena ia perlu hidup di pohon yang sama
## dengan kamera dan perabot — dan supaya layar dekor boleh dibuka-tutup
## berkali-kali tanpa melahirkan pengendali baru setiap kali.
func decor_controller() -> DecorController:
	if _decor == null or not is_instance_valid(_decor):
		_decor = DecorController.new()
		_decor.name = "DecorController"
		add_child(_decor)
		_decor.setup(self)
	return _decor


## Tier ALAT yang terpasang untuk satu jenis perabot.
##
## Gudang adalah pengecualiannya: ia tidak punya tier sendiri sama sekali dan
## selalu memakai tier LOKASI, karena ia sepaket dengan bangunan (GDD 5.2.2).
func decor_tier(kind: String) -> int:
	match kind:
		"mixer": return GameState.mixer_tier
		"oven": return GameState.oven_tier
		"display": return GameState.display_tier
		"storage": return GameState.location_tier
	return 1


## Nama perabot yang terpasang, untuk ditampilkan UI.
func decor_nama_alat(kind: String) -> String:
	if kind == "storage":
		return LocationDB.storage_name(GameState.location_tier)
	return EquipmentDB.display_name(kind, decor_tier(kind))


## Jejak lantai satu perabot pada rotasi tertentu.
func decor_jejak(kind: String, rot: int) -> Vector2i:
	return EquipmentFactory.footprint_rotated(kind, decor_tier(kind), rot)


## Node 3D satu perabot, atau null bila indeksnya di luar jangkauan.
func decor_node(kind: String, index: int) -> Node3D:
	var daftar: Array[Node3D] = _decor_nodes(kind)
	if index < 0 or index >= daftar.size():
		return null
	return daftar[index]


func _decor_nodes(kind: String) -> Array[Node3D]:
	match kind:
		"mixer": return _mixers
		"oven": return _ovens
		"display": return _displays
		"storage": return _storages
	return []


func _decor_pos(kind: String) -> Array[Vector3]:
	# Meja kasir SENGAJA tidak ada di sini: ia bagian bangunan, bukan perabot
	# lepas. station_points() yang mengenalnya, karena aktor tetap perlu tahu
	# titiknya untuk berjalan ke sana.
	match kind:
		"mixer": return mixer_pos
		"oven": return oven_pos
		"display": return display_pos
		"storage": return storage_pos
	return []


func _decor_rot(kind: String) -> Array[int]:
	match kind:
		"mixer": return mixer_rot
		"oven": return oven_rot
		"display": return display_rot
		"storage": return storage_rot
	return []


## Berapa banyak perabot satu jenis yang terpasang.
func decor_count(kind: String) -> int:
	return _decor_pos(kind).size()


## Rotasi satu perabot dalam derajat.
func decor_rot_of(kind: String, index: int) -> int:
	var r: Array[int] = _decor_rot(kind)
	return r[index] if index >= 0 and index < r.size() else 0


## Petak anchor satu perabot (pojok belakang-kiri jejaknya).
func decor_anchor(kind: String, index: int) -> Vector2i:
	var p: Array[Vector3] = _decor_pos(kind)
	if index < 0 or index >= p.size():
		return Vector2i.ZERO
	return _anchor_jejak(p[index], decor_jejak(kind, decor_rot_of(kind, index)),
		GameState.location_tier)


## Rentang baris ubin yang sah untuk satu jenis perabot.
func decor_zone(kind: String) -> Vector2i:
	var tier: int = GameState.location_tier
	if kind == "display":
		return Vector2i(EquipmentFactory.shop_row_min(tier),
			EquipmentFactory.floor_rows(tier) - 1)
	return Vector2i(0, EquipmentFactory.kitchen_row_max(tier))


## Peta petak terhuni -> "jenis:indeks". `lewati_*` mengecualikan satu perabot,
## dipakai saat menguji tempat baru untuk perabot yang sedang diseret sendiri.
func decor_occupancy(lewati_kind: String = "", lewati_index: int = -1) -> Dictionary:
	var out: Dictionary = {}
	for kind in DECOR_KINDS:
		for i in _decor_pos(kind).size():
			if kind == lewati_kind and i == lewati_index:
				continue
			var a: Vector2i = decor_anchor(kind, i)
			var j: Vector2i = decor_jejak(kind, decor_rot_of(kind, i))
			for dx in j.x:
				for dy in j.y:
					out[Vector2i(a.x + dx, a.y + dy)] = "%s:%d" % [kind, i]
	return out


## Perabot yang menempati satu petak; Dictionary kosong bila petak itu bebas.
func decor_at(petak: Vector2i) -> Dictionary:
	var id: String = String(decor_occupancy().get(petak, ""))
	if id == "":
		return {}
	var bagian: PackedStringArray = id.split(":")
	return {"kind": bagian[0], "index": int(bagian[1])}


## Alasan kenapa perabot tidak boleh berdiri di `anchor`; "" berarti boleh.
##
## Dikembalikan sebagai kalimat, bukan bool, karena pemain berhak tahu KENAPA
## petak itu berkedip merah.
func decor_reason(kind: String, index: int, anchor: Vector2i, rot: int) -> String:
	var tier: int = GameState.location_tier
	var j: Vector2i = decor_jejak(kind, rot)
	if anchor.x < 0 or anchor.x + j.x > EquipmentFactory.floor_cols(tier):
		return "Tidak muat, keluar dinding samping."
	if anchor.y < 0 or anchor.y + j.y > EquipmentFactory.floor_rows(tier):
		return "Tidak muat, keluar dinding depan/belakang."

	var zona: Vector2i = decor_zone(kind)
	if anchor.y < zona.x or anchor.y + j.y - 1 > zona.y:
		if kind == "display":
			return "Rak display hanya boleh di area toko."
		if kind == "storage":
			return "Gudang penyimpanan hanya boleh di area dapur."
		return "Alat masak hanya boleh di area dapur."

	var baris_meja: int = EquipmentFactory.counter_row(tier)
	if anchor.y <= baris_meja and baris_meja <= anchor.y + j.y - 1:
		return "Baris itu milik meja kasir."

	var huni: Dictionary = decor_occupancy(kind, index)
	for dx in j.x:
		for dy in j.y:
			if huni.has(Vector2i(anchor.x + dx, anchor.y + dy)):
				return "Sudah ada perabot lain di situ."
	return ""


## Memindahkan satu perabot ke `anchor` dengan rotasi `rot`, TANPA memeriksa
## keabsahannya — pemanggil wajib memakai decor_reason() lebih dulu.
## Ketinggian node (y) dipertahankan supaya perabot yang sedang terangkat
## selama diseret tidak tiba-tiba turun ke lantai.
func decor_place(kind: String, index: int, anchor: Vector2i, rot: int) -> void:
	var node: Node3D = decor_node(kind, index)
	if node == null:
		return
	var y: float = node.position.y
	_decor_rot(kind)[index] = rot
	node.rotation_degrees = Vector3(0.0, float(rot), 0.0)
	node.position = _pusat_jejak(anchor, decor_jejak(kind, rot),
		GameState.location_tier, y)
	_fit_inside_walls(node)
	node.position.y = y
	_decor_pos(kind)[index] = Vector3(node.position.x, 0.0, node.position.z)
	nav_invalidate()


## Menulis denah dunia 3D saat ini kembali ke GameState.decor.
func decor_save_layout() -> void:
	var tier: int = GameState.location_tier
	var layout: Dictionary = {}
	for kind in DECOR_KINDS:
		for i in _decor_pos(kind).size():
			var a: Vector2i = decor_anchor(kind, i)
			layout["%d,%d" % [a.x, a.y]] = {
				"kind": kind, "rot": decor_rot_of(kind, i)}
	GameState.decor["layout"] = layout
	GameState.decor["grid"] = {
		"w": EquipmentFactory.floor_cols(tier),
		"h": EquipmentFactory.floor_rows(tier),
		"cell": EquipmentFactory.FLOOR_TILE,
	}


## Petak lantai yang berada tepat di bawah satu titik layar.
##
## Kamera ortografik membuat ini murni geometri: tembakkan sinar dari layar,
## potong dengan bidang lantai y = 0, lalu tanyakan petaknya. Tidak ada
## PhysicsServer yang terlibat, jadi perabot tidak perlu punya collider sama
## sekali — sejalan dengan aturan 100% prosedural (GDD 12.2).
func decor_tile_at_screen(titik: Vector2) -> Vector2i:
	if camera == null or not is_instance_valid(camera):
		return Vector2i(-1, -1)
	var hit: Variant = Plane(Vector3.UP, 0.0).intersects_ray(
		camera.project_ray_origin(titik), camera.project_ray_normal(titik))
	if hit == null:
		return Vector2i(-1, -1)
	var t: Vector3 = hit
	var tier: int = GameState.location_tier
	if absf(t.x) > EquipmentFactory.room_width(tier) * 0.5 \
			or absf(t.z) > EquipmentFactory.room_depth(tier) * 0.5:
		return Vector2i(-1, -1)
	return Vector2i(
		EquipmentFactory.tile_col_at(tier, t.x),
		EquipmentFactory.tile_row_at(tier, t.z))


## Perabot yang BADANNYA tertembus sinar dari satu titik layar.
##
## Ini yang dipakai untuk memilih, BUKAN ubin di bawah kursor. Pada pandangan
## isometrik badan perabot tinggi tergambar jauh di atas ubinnya sendiri: menekan
## puncak oven berarti menembus ubin satu-dua baris di belakangnya, sehingga
## pemain mengetuk oven dan yang terangkat justru rak di belakangnya.
##
## Kotak pembatas tiap perabot digelembungkan sedikit supaya benda tipis
## (rak bambu Tier 1 setebal beberapa sentimeter) tetap gampang kena sentuh.
## Dictionary kosong berarti sinarnya tidak mengenai perabot mana pun.
func decor_pick_at_screen(titik: Vector2) -> Dictionary:
	if camera == null or not is_instance_valid(camera):
		return {}
	var asal: Vector3 = camera.project_ray_origin(titik)
	var arah: Vector3 = camera.project_ray_normal(titik)
	var terbaik: Dictionary = {}
	var terdekat: float = INF
	for kind in DECOR_KINDS:
		for i in _decor_pos(kind).size():
			var n: Node3D = decor_node(kind, i)
			if n == null or not is_instance_valid(n):
				continue
			var kotak: AABB = (n.global_transform * _local_aabb(n)).grow(PICK_PADDING)
			if kotak.size == Vector3.ZERO:
				continue
			var kena: Variant = kotak.intersects_ray(asal, arah)
			if kena == null:
				continue
			# Yang PALING DEKAT ke kamera yang menang: perabot di depan menutupi
			# perabot di belakangnya, persis seperti yang terlihat pemain.
			var jarak: float = (kena as Vector3).distance_to(asal)
			if jarak < terdekat:
				terdekat = jarak
				terbaik = {"kind": kind, "index": i}
	return terbaik


## Titik layar tepat di atas puncak satu perabot, untuk menempel tombol UI.
func decor_screen_top(node: Node3D) -> Vector2:
	if camera == null or not is_instance_valid(camera) or node == null:
		return Vector2.ZERO
	var b: AABB = _local_aabb(node)
	var puncak: float = node.position.y + (b.position.y + b.size.y) * node.scale.y
	return camera.unproject_position(
		Vector3(node.position.x, puncak + 0.20, node.position.z))


# ===========================================================================
# KETUKAN PEMAIN PADA PERABOT (di luar Mode Dekorasi)
# ===========================================================================
# Saat bermain, perabot dunia 3D adalah tombolnya sendiri: pemain mengetuk
# Gudang Penyimpanan untuk membuka Buku Resep, persis seperti GDD 2 menuliskan
# tahap persiapan ("pemain mengambil bahan dari gudang, mengklik alat, dan
# mengikuti instruksi resep").
#
# ShopWorld hanya MELAPORKAN ketukannya. Layar mana yang dibuka adalah urusan
# HUD — dunia 3D tidak memutuskan apa pun soal alur permainan.

## Jarak geser layar yang masih dihitung sebagai ketukan, bukan seretan.
const TAP_SLOP: float = 10.0

## Pemain mengetuk satu perabot. `kind` salah satu DECOR_KINDS.
signal fixture_tapped(kind: String, index: int)

var _tap_titik: Vector2 = Vector2.ZERO
var _tap_hidup: bool = false


func _unhandled_input(event: InputEvent) -> void:
	# Mode Dekorasi punya pengendali input sendiri; selama ia aktif, ketukan
	# berarti "pilih perabot untuk digeser", bukan "buka layar".
	if _decor != null and is_instance_valid(_decor) and _decor.aktif:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		_tap(mb.position, mb.pressed)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		_tap(st.position, st.pressed)


## Ketukan baru dihitung saat jari DILEPAS dan hampir tidak bergeser.
##
## Menanganinya saat ditekan akan membuat setiap usaha menyeret layar ikut
## membuka layar resep — dan di ponsel, jari yang menempel beberapa piksel
## sebelum terangkat adalah hal yang biasa, bukan kesalahan pemain.
func _tap(titik: Vector2, ditekan: bool) -> void:
	if ditekan:
		_tap_titik = titik
		_tap_hidup = true
		return
	if not _tap_hidup:
		return
	_tap_hidup = false
	if titik.distance_to(_tap_titik) > TAP_SLOP:
		return
	var kena: Dictionary = tap_pick_at_screen(titik)
	if kena.is_empty():
		return
	get_viewport().set_input_as_handled()
	fixture_tapped.emit(String(kena["kind"]), int(kena["index"]))


## Perabot yang tersentuh ketukan SAAT BERMAIN.
##
## Berbeda dari decor_pick_at_screen() yang hanya mengenal perabot yang boleh
## DIPINDAH: meja kasir pembatas bagian dari bangunan dan tidak akan pernah
## muncul di Mode Dekorasi, tapi pemain tetap harus bisa mengetuknya untuk
## menyuruh karakternya berjaga di sana. Dua daftar terpisah supaya menambah
## sasaran ketukan tidak diam-diam membuatnya bisa diseret.
func tap_pick_at_screen(titik: Vector2) -> Dictionary:
	# Pembeli yang sedang memanggil didahulukan: ia berdiri TEPAT di depan meja
	# kasir, dan sinar yang menembus badannya pasti juga mengenai meja di
	# belakangnya. Yang bisa ditangkap hanyalah pembeli yang balonnya menyala,
	# jadi ketukan pada pengunjung yang masih melihat-lihat tetap jatuh ke
	# perabot di belakangnya seperti sebelumnya.
	var pembeli: Dictionary = _pick_customer_at_screen(titik)
	if not pembeli.is_empty():
		return pembeli
	# Tablet RotiFood berdiri DI ATAS meja kasir: ia harus diperiksa lebih dulu,
	# kalau tidak setiap ketukan padanya berubah menjadi "berjaga di kasir".
	var tablet: Dictionary = _pick_tablet_at_screen(titik)
	if not tablet.is_empty():
		return tablet
	var kena: Dictionary = decor_pick_at_screen(titik)
	if not kena.is_empty():
		return kena
	return _pick_cashier_at_screen(titik)


## Balon pesanan RotiFood di atas tablet; {} bila tidak ada yang menunggu.
## `index` berisi id PESANAN paling mendesak (DeliverySim yang mengurutkannya).
func _pick_tablet_at_screen(titik: Vector2) -> Dictionary:
	if camera == null or not is_instance_valid(camera):
		return {}
	if _tablet == null or not is_instance_valid(_tablet) or not tablet_alert():
		return {}
	var pusat: Vector3 = _tablet.global_position + Vector3(0.0, TABLET_ALERT_Y, 0.0)
	var kotak := AABB(pusat - Vector3(0.22, 0.22, 0.22), Vector3(0.44, 0.44, 0.44))
	kotak = kotak.merge((_tablet.global_transform * _local_aabb(_tablet)).grow(PICK_PADDING))
	if kotak.intersects_ray(camera.project_ray_origin(titik),
			camera.project_ray_normal(titik)) == null:
		return {}
	var antre: Array[int] = _delivery_orders()
	if antre.is_empty():
		return {}
	return {"kind": PlayerTaskSystem.STATION_TABLET, "index": antre[0]}


func _delivery_orders() -> Array[int]:
	if main == null or not is_instance_valid(main):
		return [] as Array[int]
	var sys: Variant = main.get("systems")
	if not (sys is Dictionary):
		return [] as Array[int]
	var deliv: DeliverySim = (sys as Dictionary).get("deliv") as DeliverySim
	if deliv == null or not is_instance_valid(deliv):
		return [] as Array[int]
	return deliv.waiting_for_player()


## Pembeli berbalon "!" yang tersentuh ketukan; {} bila tidak ada.
##
## `index` berisi ID PELANGGAN, bukan indeks perabot — PlayerTaskSystem yang
## menerjemahkannya lewat CustomerSim.
func _pick_customer_at_screen(titik: Vector2) -> Dictionary:
	if camera == null or not is_instance_valid(camera):
		return {}
	var asal: Vector3 = camera.project_ray_origin(titik)
	var arah: Vector3 = camera.project_ray_normal(titik)
	var terbaik: int = -1
	var terdekat: float = INF
	for cid: Variant in _customers:
		var a: CustomerActor = _customers[cid]
		if a == null or not is_instance_valid(a) or not a.is_inside_tree():
			continue
		if not a.has_alert():
			continue
		var kena: Variant = _kotak_pembeli(a).intersects_ray(asal, arah)
		if kena == null:
			continue
		var d: float = asal.distance_to(kena as Vector3)
		if d < terdekat:
			terdekat = d
			terbaik = int(cid)
	if terbaik < 0:
		return {}
	return {"kind": PlayerTaskSystem.STATION_CUSTOMER, "index": terbaik}


## Kotak ketukan seorang pembeli: badannya DITAMBAH balon di atas kepalanya.
## Balon itulah yang sebenarnya diincar jari pemain, dan ia melayang di luar
## kotak badan.
func _kotak_pembeli(a: CustomerActor) -> AABB:
	var badan: AABB = (a.global_transform * _local_aabb(a)).grow(PICK_PADDING)
	var pusat: Vector3 = a.global_position + Vector3(0.0, CustomerActor.ALERT_Y, 0.0)
	var balon := AABB(pusat - Vector3(0.20, 0.20, 0.20), Vector3(0.40, 0.40, 0.40))
	if badan.size == Vector3.ZERO:
		return balon
	return badan.merge(balon)


## Mesin kasir mana yang tersentuh, bila sinarnya mengenai meja pembatas.
##
## Indeksnya ditentukan mesin kasir TERDEKAT ke titik tumbukan, bukan selalu 0:
## sejak Tier 3 meja ini memikul dua sampai tiga mesin, dan pemain berhak
## memilih yang mana yang ia jaga.
func _pick_cashier_at_screen(titik: Vector2) -> Dictionary:
	if camera == null or not is_instance_valid(camera) or cashier_pos.is_empty():
		return {}
	var meja: Node3D = fixtures.get_node_or_null("DividerCounter") as Node3D
	if meja == null or not is_instance_valid(meja):
		return {}
	var kotak: AABB = (meja.global_transform * _local_aabb(meja)).grow(PICK_PADDING)
	if kotak.size == Vector3.ZERO:
		return {}
	var kena: Variant = kotak.intersects_ray(
		camera.project_ray_origin(titik), camera.project_ray_normal(titik))
	if kena == null:
		return {}

	var hit: Vector3 = kena
	var terbaik: int = 0
	var terdekat: float = INF
	for i in cashier_pos.size():
		var d: float = Vector2(cashier_pos[i].x - hit.x, cashier_pos[i].z - hit.z).length()
		if d < terdekat:
			terdekat = d
			terbaik = i
	return {"kind": KIND_CASHIER, "index": terbaik}


# ===========================================================================
# ROTI DI ETALASE
# ===========================================================================

## Menyusun ulang roti yang terlihat di rak sesuai GameState.display_slots.
func _refresh_display_bread() -> void:
	for key in _bread_nodes.keys():
		var n: Variant = _bread_nodes[key]
		if n != null and is_instance_valid(n):
			(n as Node).queue_free()
	_bread_nodes.clear()

	for entry_v in GameState.display_slots:
		var entry: Dictionary = entry_v
		var rack: int = int(entry.get("rack", 0))
		var slot: int = int(entry.get("slot", 0))
		var count: int = int(entry.get("count", 0))
		if count <= 0 or rack >= _displays.size():
			continue
		var holder: Node3D = _displays[rack].get_node_or_null("Slot%d" % slot) as Node3D
		if holder == null:
			continue
		var bread: Node3D = BreadFactory.build(
			String(entry.get("recipe_id", "")), String(entry.get("quality", "prima")))
		if bread == null:
			continue
		holder.add_child(bread)
		_bread_nodes["%d:%d" % [rack, slot]] = bread
		# Roti yang baru matang masih mengepul (GDD 4.1 baking vapor).
		if String(entry.get("quality", "")) == "prima":
			FX.steam(holder, Vector3(0.0, 0.10, 0.0))


# ===========================================================================
# AKTOR
# ===========================================================================

func _refresh_staff() -> void:
	var wanted: Dictionary = {}
	for s_v in GameState.staff:
		var s: Dictionary = s_v
		wanted[String(s.get("staff_id", ""))] = s

	# Buang yang sudah tidak dipekerjakan. remove_child() dulu, karena
	# queue_free() baru berlaku di akhir frame — tanpa itu karyawan lama masih
	# berdiri di denah lama sepanjang frame tersebut.
	for id in _staff.keys():
		if not wanted.has(id):
			var a: Variant = _staff[id]
			if a != null and is_instance_valid(a):
				var n := a as Node
				if n.get_parent() != null:
					n.get_parent().remove_child(n)
				n.queue_free()
			_staff.erase(id)

	var cashier_i: int = 0
	var baker_i: int = 0
	for id in wanted.keys():
		var rec: Dictionary = wanted[id]
		var actor: StaffActor = _staff.get(id)
		if actor == null or not is_instance_valid(actor):
			actor = StaffActor.new()
			actor.setup_staff(id)
			actor.nav = self
			actors.add_child(actor)
			_staff[id] = actor
		actor.set_on_leave(bool(rec.get("on_leave", false)))
		if actor.role == "kasir":
			var idx: int = mini(cashier_i, maxi(cashier_pos.size() - 1, 0))
			if cashier_pos.size() > 0:
				# Kasir berdiri di SISI DAPUR meja pembatas — pembeli ada di
				# seberangnya, ke arah +Z. Wajah karakter ada di sisi -Z lokal
				# (CharacterFactory.FRONT), jadi menghadap pintu berarti
				# rotation.y = PI, bukan 0.
				actor.home_pos = cashier_stand_spot(idx)
				actor.global_position = actor.home_pos
				actor.rotation.y = PI
			cashier_i += 1
		else:
			# Baker berkeliling stasiun dapur saja. Rak roti kini ada di zona
			# toko di seberang meja pembatas, jadi tujuan "display"-nya diganti
			# titik serah di ujung meja — kalau tidak, baker akan menembus meja.
			actor.stations = {
				"mixer": mixer_pos, "oven": oven_pos, "display": handover_pos,
			}
			if mixer_pos.size() > 0:
				var idx2: int = mini(baker_i, mixer_pos.size() - 1)
				actor.home_pos = Vector3(
					mixer_pos[idx2].x, 0.0, _kitchen_aisle_z(idx2))
				actor.global_position = actor.home_pos
			baker_i += 1


## Menata ulang karakter pemain setelah denah berubah. Ia TIDAK dibuat di sini
## bila belum ada: dunia yang dirakit untuk uji tata letak tidak perlu karakter.
func _refresh_player() -> void:
	if _player == null or not is_instance_valid(_player):
		return
	_player.idle_pos = player_idle_spot()
	if not _player.is_walking:
		_player.global_position = _player.idle_pos


func _spawn_customer(cust: Dictionary) -> void:
	var cid: int = int(cust.get("id", -1))
	if cid < 0 or _customers.has(cid):
		return
	var a := CustomerActor.new()
	a.nav = self
	_seed_counter += 1
	a.setup_customer(cust, _seed_counter)
	# Posisi baru bisa disetel SESUDAH masuk pohon scene; global_position pada
	# node lepas mengembalikan Transform3D kosong dan memuntahkan error.
	actors.add_child(a)
	a.global_position = door_pos
	_customers[cid] = a

	# Masuk lewat pintu -> berhenti di depan rak roti -> antre menghadap meja
	# kasir pembatas. Seluruh rutenya berada di zona toko.
	if not display_pos.is_empty():
		var pick: int = GameConfig.rng.randi_range(0, display_pos.size() - 1)
		a.goto(display_pos[pick] + Vector3(0.0, 0.0, 0.60), "rak", 1.1)
	var slot: int = mini(_customers.size() - 1, maxi(queue_pos.size() - 1, 0))
	if not queue_pos.is_empty():
		a.goto(queue_pos[slot], "antre", 0.0)


func _spawn_driver(order: Dictionary) -> void:
	var oid: int = int(order.get("id", -1))
	if oid < 0 or _drivers.has(oid):
		return
	var d := DriverActor.new()
	d.nav = self
	d.setup_driver(order, GameState.weather == "hujan")
	actors.add_child(d)
	d.global_position = door_pos + Vector3(0.6, 0.0, 0.6)
	_drivers[oid] = d
	d.goto(_driver_wait_spot(), "jemput", 0.0)
	# Sesampainya di tempat jemput ia BERBALIK menghadap pintu, tidak berhenti
	# dengan arah sisa langkah terakhir yang memunggungi kamera.
	d.arrived.connect(func(tag: String) -> void:
		if tag == "jemput" and is_instance_valid(d):
			d.wait_facing_entrance()
	)


## Tempat driver ojol menunggu pesanan.
##
## GDD 3.6.B: mulai Tier 3 ada meja khusus, jadi driver tidak ikut antre kasir.
## Di bawah itu ia menunggu di ujung kanan meja pembatas, dekat celah jalan
## staf — sengaja di luar antrean pembeli yang membentang di sumbu X = 0.
func _driver_wait_spot() -> Vector3:
	if pickup_pos != Vector3.ZERO:
		return pickup_pos + Vector3(0.0, 0.0, 0.70)
	# Berdiri DI DALAM celah jalan sisi +X, SEBARIS dengan meja kasir — bukan di
	# depan meja. Di depan meja adalah tempat rak roti berdiri: rak membentang
	# hampir selebar ruangan, dan titik tunggu lama jatuh persis di dalam badan
	# rak paling kanan.
	#
	# Sumbu X dikunci ke pusat ubin seperti perabot lain, lalu dijepit agar tetap
	# lepas dari ujung meja dan dari dinding.
	var tier: int = GameState.location_tier
	var dv: Dictionary = _divider_metrics(tier)
	var ujung_meja: float = float(dv["cx"]) + float(dv["span"]) * 0.5
	var tepi: float = EquipmentFactory.room_width(tier) * 0.5
	var dinding: float = tepi - EquipmentFactory.room_wall_thickness() - 0.30
	var tengah: float = (ujung_meja + dinding) * 0.5
	return Vector3(
		clampf(EquipmentFactory.snap_x(tier, tengah), ujung_meja + 0.25, dinding),
		0.0,
		float(dv["z"]))


# ===========================================================================
# SINYAL
# ===========================================================================

func _connect_events() -> void:
	EventBus.customer_spawned.connect(_on_customer_spawned)
	EventBus.customer_served.connect(_on_customer_served)
	EventBus.customer_left_angry.connect(_on_customer_left)
	EventBus.delivery_order_received.connect(_on_order_received)
	EventBus.delivery_order_handover.connect(_on_order_handover)
	EventBus.delivery_order_expired.connect(_on_order_expired)
	EventBus.display_changed.connect(_refresh_display_bread)
	EventBus.production_finished.connect(_on_production_finished)
	EventBus.bread_burned.connect(_on_bread_burned)
	EventBus.weather_changed.connect(_on_weather_changed)
	EventBus.staff_hired.connect(_on_staff_changed)
	EventBus.staff_fired.connect(_on_staff_changed)
	EventBus.staff_leave_toggled.connect(_on_staff_leave)
	EventBus.upgrade_purchased.connect(_on_upgrade)


func _on_customer_spawned(c: Dictionary) -> void:
	_spawn_customer(c)


func _on_customer_served(c: Dictionary, _revenue: float) -> void:
	var a: CustomerActor = _customers.get(int(c.get("id", -1)))
	if a == null or not is_instance_valid(a):
		return
	a.serve_happy()
	a.clear_path()
	a.goto(door_pos, "pulang", 0.0)
	a.path_finished.connect(a.leave_and_free.bind(0.35), CONNECT_ONE_SHOT)
	_customers.erase(int(c.get("id", -1)))


func _on_customer_left(c: Dictionary, reason: String) -> void:
	var a: CustomerActor = _customers.get(int(c.get("id", -1)))
	if a == null or not is_instance_valid(a):
		return
	a.leave_angry(reason)
	a.clear_path()
	a.goto(door_pos, "pulang", 0.0)
	a.path_finished.connect(a.leave_and_free.bind(0.35), CONNECT_ONE_SHOT)
	_customers.erase(int(c.get("id", -1)))


func _on_order_received(order: Dictionary) -> void:
	_spawn_driver(order)


func _on_order_handover(order: Dictionary, _tip: float) -> void:
	var oid: int = int(order.get("id", -1))
	var d: DriverActor = _drivers.get(oid)
	if d == null or not is_instance_valid(d):
		return
	d.receive_bag()
	d.clear_path()
	d.goto(door_pos + Vector3(1.4, 0.0, 1.2), "pergi", 0.0)
	d.path_finished.connect(d.leave_and_free.bind(0.35), CONNECT_ONE_SHOT)
	_drivers.erase(oid)


func _on_order_expired(order: Dictionary) -> void:
	var oid: int = int(order.get("id", -1))
	var d: DriverActor = _drivers.get(oid)
	if d == null or not is_instance_valid(d):
		return
	d.reject()
	d.clear_path()
	d.goto(door_pos + Vector3(1.4, 0.0, 1.2), "pergi", 0.0)
	d.path_finished.connect(d.leave_and_free.bind(0.35), CONNECT_ONE_SHOT)
	_drivers.erase(oid)


func _on_production_finished(job: Dictionary) -> void:
	var idx: int = int(job.get("slot_index", 0))
	if idx < _ovens.size():
		var door: Node3D = _ovens[idx].get_node_or_null("Door") as Node3D
		if door != null:
			ProceduralAnimationSystem.oven_door(door, true)
		FX.steam(_ovens[idx], Vector3(0.0, 0.55, 0.35))
	_refresh_display_bread()


func _on_bread_burned(_recipe_id: String, _count: int) -> void:
	if _ovens.is_empty():
		return
	FX.burn_smoke(_ovens[0], Vector3(0.0, 0.62, 0.30))


func _on_weather_changed(today: String, _forecast: String) -> void:
	if _rain != null and is_instance_valid(_rain):
		(_rain as Node).queue_free()
		_rain = null
	if today != "hujan":
		return
	# Hujan digambar sebagai lapisan 2D di atas dunia (GDD 10.2, cozy bukan suram).
	var layer := CanvasLayer.new()
	layer.name = "RainLayer"
	layer.layer = 5
	add_child(layer)
	FX.rain_overlay(layer)
	_rain = layer


func _on_staff_changed(_staff_id: String) -> void:
	_refresh_staff()


func _on_staff_leave(_staff_id: String, _on_leave: bool) -> void:
	_refresh_staff()


func _on_upgrade(kind: String, _tier: int) -> void:
	# Upgrade lokasi mengubah seluruh denah; upgrade alat cukup mengganti alatnya.
	if kind == "location" or GameState.location_tier != _built_tier:
		rebuild()
		return
	for child in fixtures.get_children():
		if child.name.begins_with("Mixer") or child.name.begins_with("Oven") \
				or child.name.begins_with("Display"):
			child.queue_free()
	_mixers.clear()
	_ovens.clear()
	_displays.clear()
	_place_stations()
	_refresh_display_bread()


# ===========================================================================
# NAVIGASI: AKTOR TIDAK MENEMBUS PERABOT
# ===========================================================================
# Aktor berjalan di KISI UBIN yang sama dengan yang dipakai Mode Dekorasi, bukan
# di atas collider fisika. Itu disengaja: perabot di proyek ini tidak punya
# collider sama sekali (lihat decor_pick_at_screen), dan menambahkannya hanya
# demi tabrakan pejalan kaki berarti dua sumber kebenaran bentuk untuk setiap
# perabot — satu mesh, satu collider — yang pasti akan berbeda diam-diam begitu
# jejak lantai berubah.
#
# Petak yang terhuni perabot ditandai SOLID pada AStarGrid2D, lalu rute hasil A*
# diluruskan kembali dengan uji garis pandang supaya karakter tidak berjalan
# zig-zag dari pusat ubin ke pusat ubin.

## Jarak sampel saat menguji apakah satu ruas garis melewati petak terlarang.
## Lebih rapat dari setengah ubin, jadi tidak ada petak yang terlewat.
const NAV_SAMPLE: float = 0.12

var _nav: AStarGrid2D = null
## Kisi dibangun ulang hanya saat denah benar-benar berubah, bukan tiap langkah.
var _nav_dirty: bool = true


## Menandai kisi navigasi perlu dihitung ulang (denah perabot berubah).
func nav_invalidate() -> void:
	_nav_dirty = true


## Petak yang tidak boleh dilalui aktor: seluruh jejak perabot, badan meja kasir
## pembatas, dan meja khusus ojol.
##
## Meja pembatas TIDAK menutup satu baris penuh — ia menyisakan celah jalan di
## sisi +X, dan celah itulah satu-satunya jalan staf keluar-masuk dapur. Karena
## itu yang ditandai hanya kolom yang benar-benar tertutup bentang mejanya.
func blocked_tiles() -> Dictionary:
	var tier: int = GameState.location_tier
	var out: Dictionary = {}
	for kunci in decor_occupancy().keys():
		out[kunci] = true

	var cols: int = EquipmentFactory.floor_cols(tier)
	var baris_meja: int = EquipmentFactory.counter_row(tier)
	var dv: Dictionary = _divider_metrics(tier)
	var span: float = float(dv["span"])
	var cx: float = float(dv["cx"])
	var kol_kiri: int = EquipmentFactory.tile_col_at(tier, cx - span * 0.5 + 0.01)
	var kol_kanan: int = EquipmentFactory.tile_col_at(tier, cx + span * 0.5 - 0.01)
	for k in range(kol_kiri, kol_kanan + 1):
		if k >= 0 and k < cols:
			out[Vector2i(k, baris_meja)] = true

	if pickup_pos != Vector3.ZERO:
		var jejak: Vector2i = EquipmentFactory.footprint("pickup", tier)
		var anchor: Vector2i = _anchor_jejak(pickup_pos, jejak, tier)
		for dx in jejak.x:
			for dy in jejak.y:
				out[Vector2i(anchor.x + dx, anchor.y + dy)] = true
	return out


func is_tile_blocked(petak: Vector2i) -> bool:
	_ensure_nav()
	if _nav == null or not _in_grid(petak):
		return false
	return _nav.is_point_solid(petak)


## Petak bebas terdekat dari `petak`, melebar melingkar ke luar.
## Mengembalikan `petak` apa adanya bila seluruh ruangan tertutup.
func nearest_free_tile(petak: Vector2i) -> Vector2i:
	_ensure_nav()
	if _nav == null:
		return petak
	var tier: int = GameState.location_tier
	var cols: int = EquipmentFactory.floor_cols(tier)
	var rows: int = EquipmentFactory.floor_rows(tier)
	var mulai := Vector2i(clampi(petak.x, 0, cols - 1), clampi(petak.y, 0, rows - 1))
	if not _nav.is_point_solid(mulai):
		return mulai
	for r in range(1, maxi(cols, rows) + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue
				var k := Vector2i(mulai.x + dx, mulai.y + dy)
				if not _in_grid(k):
					continue
				if not _nav.is_point_solid(k):
					return k
	return mulai


## Rute berjalan dari `dari` ke `ke` yang tidak menembus satu pun perabot.
##
## Mengembalikan daftar titik singgah; elemen TERAKHIR selalu tujuan akhir.
## Bila garis lurus sudah bebas, yang dikembalikan hanya satu titik — karakter
## tetap berjalan lurus seperti sebelumnya dan tidak ada gerak yang berubah
## tanpa alasan.
func route(dari: Vector3, ke: Vector3) -> PackedVector3Array:
	var out := PackedVector3Array()
	_ensure_nav()
	if _nav == null or _segmen_bebas(dari, ke):
		out.append(ke)
		return out

	var tier: int = GameState.location_tier
	# Tujuan di LUAR ruangan (mis. driver yang pergi meninggalkan toko) tetap
	# dihormati: A* mengantar sampai petak terdalam yang masih di dalam kisi,
	# lalu titik aslinya ditempelkan sebagai langkah terakhir.
	var luar: bool = not _in_grid(_petak(ke))
	var a: Vector2i = nearest_free_tile(_petak_terjepit(dari))
	var b: Vector2i = nearest_free_tile(_petak_terjepit(ke))

	var ids: Array[Vector2i] = _nav.get_id_path(a, b)
	if ids.is_empty():
		# Tidak ada jalan sama sekali (dapur tertutup rapat perabot): lebih baik
		# menembus daripada karakter membeku selamanya dan pesanan menggantung.
		out.append(ke)
		return out

	var titik := PackedVector3Array()
	titik.append(dari)
	for id in ids:
		titik.append(Vector3(
			EquipmentFactory.tile_x(tier, id.x), 0.0,
			EquipmentFactory.tile_z(tier, id.y)))
	if not luar and _segmen_bebas(titik[titik.size() - 1], ke):
		titik.append(ke)

	var mulus: PackedVector3Array = _luruskan(titik)
	# Titik pertama adalah posisi berdiri sekarang; ia bukan tujuan.
	for i in range(1, mulus.size()):
		out.append(mulus[i])
	if luar:
		out.append(ke)
	if out.is_empty():
		out.append(ke)
	return out


# ---------------------------------------------------------------------------
# Pembantu navigasi
# ---------------------------------------------------------------------------

## Membuang titik singgah yang tidak perlu: dari satu titik, dilompati sejauh
## mungkin selama garis pandangnya masih bebas.
##
## Tanpa ini karakter berjalan dari pusat ubin ke pusat ubin dan terlihat
## melangkah zig-zag seperti bidak catur, padahal lantainya lapang.
func _luruskan(titik: PackedVector3Array) -> PackedVector3Array:
	var out := PackedVector3Array()
	if titik.is_empty():
		return out
	out.append(titik[0])
	var i: int = 0
	while i < titik.size() - 1:
		var j: int = titik.size() - 1
		while j > i + 1 and not _segmen_bebas(titik[i], titik[j]):
			j -= 1
		out.append(titik[j])
		i = j
	return out


## Apakah ruas garis a-b sama sekali tidak menyentuh petak terlarang.
func _segmen_bebas(a: Vector3, b: Vector3) -> bool:
	_ensure_nav()
	if _nav == null:
		return true
	var datar := Vector3(b.x - a.x, 0.0, b.z - a.z)
	var jarak: float = datar.length()
	var langkah: int = maxi(1, int(ceil(jarak / NAV_SAMPLE)))
	for i in range(langkah + 1):
		var p: Vector3 = a + datar * (float(i) / float(langkah))
		var k: Vector2i = _petak(p)
		if not _in_grid(k):
			continue
		if _nav.is_point_solid(k):
			return false
	return true


## Petak yang memuat satu titik dunia, TANPA dijepit ke dalam ruangan.
func _petak(p: Vector3) -> Vector2i:
	var tier: int = GameState.location_tier
	var t: float = EquipmentFactory.FLOOR_TILE
	return Vector2i(
		int(floor((p.x + EquipmentFactory.room_width(tier) * 0.5) / t)),
		int(floor((p.z + EquipmentFactory.room_depth(tier) * 0.5) / t)))


## Petak yang memuat satu titik dunia, dijepit ke dalam ruangan.
func _petak_terjepit(p: Vector3) -> Vector2i:
	var tier: int = GameState.location_tier
	return Vector2i(
		EquipmentFactory.tile_col_at(tier, p.x),
		EquipmentFactory.tile_row_at(tier, p.z))


func _in_grid(petak: Vector2i) -> bool:
	var tier: int = GameState.location_tier
	return petak.x >= 0 and petak.y >= 0 \
		and petak.x < EquipmentFactory.floor_cols(tier) \
		and petak.y < EquipmentFactory.floor_rows(tier)


func _ensure_nav() -> void:
	if not _nav_dirty and _nav != null:
		return
	_nav_dirty = false
	var tier: int = GameState.location_tier
	var cols: int = EquipmentFactory.floor_cols(tier)
	var rows: int = EquipmentFactory.floor_rows(tier)
	if cols <= 0 or rows <= 0:
		_nav = null
		return

	_nav = AStarGrid2D.new()
	_nav.region = Rect2i(0, 0, cols, rows)
	_nav.cell_size = Vector2(EquipmentFactory.FLOOR_TILE, EquipmentFactory.FLOOR_TILE)
	# Menyerong hanya bila KEDUA petak tetangganya bebas: tanpa ini karakter
	# menyelinap lewat celah diagonal antara dua perabot yang bersentuhan sudut,
	# dan terlihat menembus keduanya sekaligus.
	_nav.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_nav.update()
	for kunci in blocked_tiles().keys():
		var k: Vector2i = kunci
		if _in_grid(k):
			_nav.set_point_solid(k, true)


# ===========================================================================
# KARAKTER PEMAIN & PENANDA STASIUN
# ===========================================================================
# Dunia 3D menampung karakter yang dimainkan pemain dan menggambar penanda yang
# mengambang di atas perabot. Ia TIDAK memutuskan apa pun soal alur produksi —
# PlayerTaskSystem yang memberi tahu penanda mana yang harus tampil, dan dunia
# hanya menggambarkannya.

## Jenis perabot yang bisa memikul penanda stasiun.
const MARKER_KINDS: Array[String] = ["mixer", "oven", "display", "storage"]

var _player: PlayerActor = null
## "jenis:indeks" -> StationMarker
var _markers: Dictionary = {}


## Karakter pemain; dibuat saat pertama dibutuhkan supaya dunia tetap bisa
## dirakit di uji headless yang tidak memerlukannya.
func player_actor() -> PlayerActor:
	if _player != null and is_instance_valid(_player):
		return _player
	if actors == null:
		return null
	_player = PlayerActor.new()
	_player.name = "Player"
	_player.nav = self
	_player.setup_player(GameState.player_gender())
	actors.add_child(_player)
	_player.global_position = player_idle_spot()
	_player.idle_pos = _player.global_position
	# Menghadap ke arah toko (+Z) sejak lahir: pada kamera isometrik yang
	# melayang di kuadran (+X, +Z), itulah satu-satunya arah yang memperlihatkan
	# wajahnya. Karakter yang menunggu perintah sambil membelakangi pemain
	# terbaca seperti patung.
	_player.rotation.y = PI
	_player.task_arrived.connect(_on_player_arrived)
	return _player


## Membangun ulang karakter pemain sesuai pilihan yang tersimpan sekarang.
func rebuild_player() -> void:
	if _player != null and is_instance_valid(_player):
		_player.setup_player(GameState.player_gender())
		_player.idle_pos = player_idle_spot()
		_player.global_position = _player.idle_pos
		return
	player_actor()


## Titik mangkal karakter saat menganggur: di lorong dapur, di depan mixer
## pertama — tempat yang sama yang dipakai asisten dapur sebagai pangkalan.
func player_idle_spot() -> Vector3:
	if mixer_pos.is_empty():
		return Vector3(0.0, 0.0, EquipmentFactory.partition_z(GameState.location_tier) - 0.8)
	return Vector3(mixer_pos[0].x, 0.0, _kitchen_aisle_z(0))


## Titik berdiri melayani di belakang mesin kasir ke-`index`, di sisi DAPUR
## meja pembatas. Pembeli berdiri di seberangnya, ke arah +Z.
func cashier_stand_spot(index: int) -> Vector3:
	if cashier_pos.is_empty():
		return Vector3.ZERO
	var i: int = clampi(index, 0, cashier_pos.size() - 1)
	return cashier_pos[i] + Vector3(0.0, 0.0,
		-(EquipmentFactory.DIVIDER_DEPTH * 0.5 + CASHIER_STAND_GAP))


## Titik BERDIRI terbaik di depan satu perabot, dilihat dari `dari`.
##
## Bukan sekadar geser sekian meter dari titik tengahnya: rak display berdiri
## tepat di seberang meja kasir pembatas, dan pergeseran buta ke arah dapur
## mendaratkan karakter DI ATAS meja itu. Yang dicari di sini adalah petak yang
## benar-benar BEBAS, bersebelahan dengan jejak perabot, dan paling dekat ke
## tempat karakter berdiri sekarang.
##
## Petak diagonal di pojok jejak sengaja dilewati: berdiri menyerong di pojok
## tidak terbaca sebagai sedang menghadapi alatnya.
func stand_spot(kind: String, index: int, dari: Vector3) -> Vector3:
	# Meja kasir punya satu titik layan yang sudah ditetapkan bangunan; ia tidak
	# ikut aturan "petak bebas terdekat" karena sisi seberangnya zona pembeli.
	if kind == KIND_CASHIER:
		return cashier_stand_spot(index)
	var daftar: Array[Vector3] = station_points(kind)
	if index < 0 or index >= daftar.size():
		return Vector3.ZERO
	var pusat: Vector3 = daftar[index]
	var tier: int = GameState.location_tier
	var jejak: Vector2i = decor_jejak(kind, decor_rot_of(kind, index))
	var anchor: Vector2i = _anchor_jejak(pusat, jejak, tier)

	var terbaik: Vector3 = Vector3.ZERO
	var terdekat: float = INF
	for dx in range(-1, jejak.x + 1):
		for dy in range(-1, jejak.y + 1):
			var sisi_x: bool = dx < 0 or dx >= jejak.x
			var sisi_y: bool = dy < 0 or dy >= jejak.y
			if not sisi_x and not sisi_y:
				continue   # di dalam jejak perabot itu sendiri
			if sisi_x and sisi_y:
				continue   # pojok diagonal
			var k := Vector2i(anchor.x + dx, anchor.y + dy)
			if not _in_grid(k) or is_tile_blocked(k):
				continue
			var titik := Vector3(
				EquipmentFactory.tile_x(tier, k.x), 0.0,
				EquipmentFactory.tile_z(tier, k.y))
			var d: float = titik.distance_to(dari)
			if d < terdekat:
				terdekat = d
				terbaik = titik
	# Perabot yang seluruh sisinya tertutup: tetap kembalikan titik tengahnya
	# supaya karakter tidak membeku menunggu tempat yang tidak pernah ada.
	return terbaik if terdekat < INF else pusat


## Titik lantai seluruh perabot satu jenis. Dipakai PlayerTaskSystem sebagai
## tujuan berjalan, jadi ia tidak perlu tahu nama array mana pun di sini.
##
## Memuat meja kasir juga, walau ia bukan perabot yang bisa dipindah: aktor
## tetap perlu tahu di mana mesin kasirnya berdiri.
func station_points(kind: String) -> Array[Vector3]:
	match kind:
		"mixer": return mixer_pos
		"oven": return oven_pos
		"display": return display_pos
		"storage": return storage_pos
		KIND_CASHIER: return cashier_pos
	return []


func _on_player_arrived(tag: String) -> void:
	var pt: PlayerTaskSystem = _player_tasks()
	if pt != null:
		pt.on_actor_arrived(tag)


func _player_tasks() -> PlayerTaskSystem:
	if main == null or not is_instance_valid(main):
		return null
	var sys: Variant = main.get("systems")
	if not (sys is Dictionary):
		return null
	return (sys as Dictionary).get("player") as PlayerTaskSystem


## Membuka atau menutup pintu gudang pertama. Dipanggil PlayerTaskSystem lewat
## sinyal storage_door.
func set_storage_open(open: bool) -> void:
	if _storages.is_empty():
		return
	var g: Node3D = _storages[0]
	if g == null or not is_instance_valid(g):
		return
	if open:
		ProceduralAnimationSystem.storage_door_hold(g, true)
	else:
		ProceduralAnimationSystem.storage_door_hold(g, false)


# ---------------------------------------------------------------------------
# Penanda
# ---------------------------------------------------------------------------

## Menyegarkan seluruh penanda dari laporan PlayerTaskSystem.
##
## Penanda dibuat sekali per perabot lalu dipakai ulang: perabot bisa berganti
## antara tanda seru dan bar progres puluhan kali sehari, dan membuat-membuang
## node setiap kali hanya menumpuk sampah.
func refresh_markers() -> void:
	var pt: PlayerTaskSystem = _player_tasks()
	var ingin: Dictionary = pt.markers() if pt != null else {}
	for kunci in _markers.keys():
		var m: StationMarker = _markers[kunci]
		if m == null or not is_instance_valid(m):
			continue
		if not ingin.has(kunci):
			m.hide_marker()
	for kunci in ingin.keys():
		var info: Dictionary = ingin[kunci]
		var m2: StationMarker = _marker_untuk(String(kunci))
		if m2 == null:
			continue
		if String(info.get("mode", "")) == StationMarker.MODE_ALERT:
			m2.show_alert()
		else:
			m2.show_progress(float(info.get("value", 0.0)))


func _marker_untuk(kunci: String) -> StationMarker:
	var ada: Variant = _markers.get(kunci)
	if ada != null and is_instance_valid(ada):
		return ada as StationMarker
	var bagian: PackedStringArray = kunci.split(":")
	if bagian.size() != 2:
		return null
	var node: Node3D = _perabot(String(bagian[0]), int(bagian[1]))
	if node == null:
		return null
	var m := StationMarker.new()
	m.name = "Marker_" + kunci.replace(":", "_")
	fixtures.add_child(m)
	m.pasang_di(node)
	_markers[kunci] = m
	return m


func _perabot(kind: String, index: int) -> Node3D:
	var daftar: Array[Node3D] = _decor_nodes(kind)
	if index < 0 or index >= daftar.size():
		return null
	return daftar[index]


## Membuang seluruh penanda. Dipanggil rebuild() karena perabot yang dipikulnya
## sudah dibongkar.
func _clear_markers() -> void:
	for kunci in _markers.keys():
		var m: Variant = _markers[kunci]
		if m != null and is_instance_valid(m):
			(m as Node).queue_free()
	_markers.clear()


# ===========================================================================
# ANIMASI PER FRAME
# ===========================================================================

func _process(delta: float) -> void:
	tick_world(delta)


## Satu langkah animasi dunia: aktor berjalan, mixer berputar, penanda disegarkan.
##
## Dipisah dari _process() supaya suite tes headless bisa memajukan dunia dengan
## delta tetap. Tanpa ini karakter pemain tidak pernah melangkah di dalam tes —
## _process hanya berjalan pada frame nyata, dan tes tidak menunggu satu pun.
func tick_world(delta: float) -> void:
	if main == null:
		return
	# Dunia ikut berhenti saat simulasi di-pause supaya tidak ada gerak "hantu".
	var d: float = delta
	var sys: Variant = main.get("systems")
	if sys is Dictionary:
		var day: Variant = (sys as Dictionary).get("day")
		if day is DayCycle:
			d = (day as DayCycle).effective_delta(delta)
	if d <= 0.0:
		return

	_t += d
	for a in actors.get_children():
		if a.has_method("tick"):
			a.call("tick", d)

	# Mixer yang sedang bekerja berputar (GDD 4.2).
	var prod: Variant = null
	if sys is Dictionary:
		prod = (sys as Dictionary).get("prod")
	var busy: int = 0
	if prod != null and (prod as Object).has_method("busy_mixers"):
		busy = int((prod as Object).call("busy_mixers"))
	for i in _mixers.size():
		var whisk: Node3D = _mixers[i].get_node_or_null("Whisk") as Node3D
		if whisk != null and i < busy:
			ProceduralAnimationSystem.mixer_spin(whisk, _t)

	refresh_markers()
	refresh_service(sys)


# ---------------------------------------------------------------------------
# Pelayanan di meja kasir
# ---------------------------------------------------------------------------

## Menyegarkan dua hal yang sama-sama bersumber dari CustomerSim: balon "!" di
## atas kepala pembeli yang menunggu, dan gerakan membungkus karakter pemain.
##
## Seperti penanda perabot, dunia TIDAK menghitung sendiri kapan balon muncul —
## ia hanya menggambar apa yang dilaporkan simulasi. Satu sumber kebenaran.
func refresh_service(sys: Variant) -> void:
	if not (sys is Dictionary):
		return
	var cust: CustomerSim = (sys as Dictionary).get("cust") as CustomerSim
	if cust == null or not is_instance_valid(cust):
		return

	var menunggu: Dictionary = {}
	for id: int in cust.waiting_for_player():
		menunggu[id] = true

	# Siapa yang sudah menenteng roti dari rak. Dibaca dari keranjang di
	# simulasi, bukan ditebak dari posisi aktor: yang menentukan roti sudah
	# berpindah tangan adalah CustomerSim.
	var bawa: Dictionary = {}
	for e: Variant in cust.customers():
		var c: Dictionary = e
		if not (c.get("basket", {}) as Dictionary).is_empty():
			bawa[int(c.get("id", -1))] = true

	_refresh_tablet((sys as Dictionary).get("deliv") as DeliverySim)

	for cid: Variant in _customers:
		var a: CustomerActor = _customers[cid]
		if a == null or not is_instance_valid(a):
			continue
		a.set_belanjaan(bool(bawa.get(int(cid), false)))
		# Balon baru muncul setelah kakinya benar-benar sampai di antrean:
		# tanda seru yang ikut berjalan terbaca seperti pembeli yang memanggil
		# dari tengah ruangan, padahal ia belum sampai ke meja.
		if bool(menunggu.get(int(cid), false)) and a.waypoints.is_empty():
			a.show_alert()
		else:
			a.hide_alert()

	_refresh_bungkus(cust)


## Balon "!" di atas tablet RotiFood: ada pesanan aplikasi yang menunggu
## diketuk (GDD 3.6.A langkah 1: "Balon pesanan digital muncul di atas tablet").
##
## Tanda yang sama dengan perabot dapur dan pembeli fisik, di tempat yang
## berbeda — pemain tidak perlu belajar bahasa isyarat ketiga.
func _refresh_tablet(deliv: DeliverySim) -> void:
	if _tablet == null or not is_instance_valid(_tablet):
		return
	var perlu: bool = deliv != null and is_instance_valid(deliv) \
		and not deliv.waiting_for_player().is_empty()
	if not perlu:
		if _tablet_marker != null and is_instance_valid(_tablet_marker):
			_tablet_marker.hide_marker()
		return
	if _tablet_marker == null or not is_instance_valid(_tablet_marker):
		_tablet_marker = StationMarker.new()
		_tablet_marker.name = "MarkerTablet"
		_tablet_marker.position = Vector3(0.0, TABLET_ALERT_Y, 0.0)
		_tablet.add_child(_tablet_marker)
	_tablet_marker.show_alert()


## Apakah balon tablet sedang menyala. Dipakai pemilihan ketukan dan uji.
func tablet_alert() -> bool:
	return _tablet_marker != null and is_instance_valid(_tablet_marker) \
		and _tablet_marker.mode == StationMarker.MODE_ALERT


## Karakter pemain terlihat membungkus pesanan selama transaksi di mejanya
## berjalan. Diturunkan dari keadaan simulasi, bukan disimpan sebagai penanda:
## begitu ia melangkah pergi, manning_lane() berubah dan gerakannya berhenti
## sendiri — persis seperti transaksinya yang ikut membeku (GDD 3.0.C).
func _refresh_bungkus(cust: CustomerSim) -> void:
	if _player == null or not is_instance_valid(_player):
		return
	var pt: PlayerTaskSystem = _player_tasks()
	var lane: int = pt.manning_lane() if pt != null else -1
	var bungkus: bool = lane >= 0 and cust.serving_id(lane) >= 0
	if bungkus == _player.is_wrapping():
		return
	_player.set_wrapping(bungkus)
	# Kantong kertas menggantikan apa pun yang sedang ia pegang. Begitu
	# bungkusannya selesai, adonan atau loyang yang tertunda harus kembali ke
	# tangannya — pesanan dapurnya belum ke mana-mana.
	if not bungkus and pt != null:
		pt.refresh_carry()
