class_name DecorController
extends Node
## Mode Dekorasi yang bekerja LANGSUNG di dunia 3D (GDD 7 "Mode Dekorasi").
##
## Pemain tidak lagi menata denah di papan petak terpisah. Ia menyentuh perabot
## yang sesungguhnya, perabot itu terangkat dan berkedip, lalu diseret ke ubin
## lain. Papan petak lama memaksa pemain menerjemahkan sendiri "petak 3,7" ke
## sudut ruangan yang mana — dan terjemahan itulah sumber setiap keluhan bahwa
## perabot "mendarat di tempat yang salah".
##
## Pengendali ini hanya mengurus NIAT pemain (pilih, seret, putar). Seluruh
## aturan tempat — jejak lantai, zona dapur/toko, baris meja kasir, tabrakan —
## dijawab ShopWorld lewat decor_reason(). Satu sumber aturan, satu jawaban.

## Tinggi angkat perabot terpilih, meter. Cukup untuk terbaca sebagai "diangkat"
## tanpa membuatnya melayang seperti bug.
const LIFT: float = 0.16
## Setengah putaran kedip per detik: pelan, tidak gelisah.
const BLINK_HZ: float = 0.9
## Rentang kekuatan kedip (alpha lapisan warna).
const BLINK_MIN: float = 0.10
const BLINK_MAX: float = 0.46
## Jarak geser layar yang sudah dianggap "menyeret", bukan "mengetuk".
const DRAG_SLOP: float = 8.0

## Warna kedip saat tempatnya boleh, dan saat tidak boleh (GDD 4.1 palet hangat).
const WARNA_OK: Color = Color(1.0, 1.0, 1.0)
const WARNA_TOLAK: Color = Color(1.0, 0.33, 0.30)

## Perabot terpilih berubah. `info` kosong berarti tidak ada yang terpilih;
## selain itu berisi kind/index/label/jejak/rot.
signal selection_changed(info: Dictionary)
## Pesan singkat untuk baris keterangan di layar. `ok` = false berarti penolakan.
signal status(text: String, ok: bool)
## Perabot terpilih berpindah/berputar — UI memakai ini untuk menggeser tombol.
signal moved()

var world: ShopWorld = null

var aktif: bool = false
## {"kind": String, "index": int} — kosong bila tidak ada yang terpilih.
var _sel: Dictionary = {}
## Anchor tempat perabot berdiri sebelum diseret; tujuan pulang bila ditolak.
var _anchor_asal: Vector2i = Vector2i.ZERO
## Selisih anchor terhadap petak yang disentuh, supaya perabot tidak melompat
## agar pusatnya menempel ke jari.
var _genggam: Vector2i = Vector2i.ZERO
var _menyeret: bool = false
var _titik_tekan: Vector2 = Vector2.ZERO
var _geser: bool = false
var _boleh: bool = true

var _t: float = 0.0
## Lapisan warna yang ditempelkan ke seluruh mesh perabot terpilih. SATU
## material dipakai bersama, jadi mengubah alpha-nya sekali sudah mengedipkan
## seluruh badan perabot.
var _lapis: StandardMaterial3D = null
var _dilapisi: Array[MeshInstance3D] = []
## Petak tujuan yang disorot di lantai.
var _sorot: MeshInstance3D = null
var _sorot_mat: StandardMaterial3D = null


func setup(w: ShopWorld) -> void:
	world = w
	set_process(false)
	set_process_unhandled_input(false)


# ===========================================================================
# MASUK / KELUAR MODE
# ===========================================================================

func mulai() -> void:
	if world == null:
		return
	aktif = true
	set_process(true)
	set_process_unhandled_input(true)
	_buat_sorot()
	emit_signal("status", "Ketuk perabot untuk memilih, lalu seret ke tempat baru.", true)


func selesai() -> void:
	_lepas_pilihan()
	aktif = false
	set_process(false)
	set_process_unhandled_input(false)
	if _sorot != null and is_instance_valid(_sorot):
		_sorot.visible = false
	if world != null:
		world.decor_save_layout()


## Mengembalikan seluruh perabot ke denah bawaan tier ini.
func kembalikan_awal() -> void:
	if world == null:
		return
	_lepas_pilihan()
	GameState.decor.erase("layout")
	GameState.decor.erase("grid")
	world.rebuild()
	emit_signal("selection_changed", {})
	emit_signal("status", "Denah dikembalikan ke susunan bawaan.", true)


# ===========================================================================
# PILIHAN
# ===========================================================================

func pilih(kind: String, index: int) -> void:
	if world == null:
		return
	if _sel.get("kind", "") == kind and int(_sel.get("index", -1)) == index:
		return
	_lepas_pilihan()
	var node: Node3D = world.decor_node(kind, index)
	if node == null:
		return
	_sel = {"kind": kind, "index": index}
	_anchor_asal = world.decor_anchor(kind, index)
	_boleh = true
	node.position.y = LIFT
	_pasang_lapisan(node)
	_perbarui_sorot()
	emit_signal("selection_changed", info_pilihan())
	emit_signal("moved")


func batal_pilih() -> void:
	if _sel.is_empty():
		return
	_lepas_pilihan()
	emit_signal("selection_changed", {})


## Keterangan perabot terpilih untuk dipakai UI.
func info_pilihan() -> Dictionary:
	if _sel.is_empty() or world == null:
		return {}
	var kind: String = String(_sel["kind"])
	var index: int = int(_sel["index"])
	var rot: int = world.decor_rot_of(kind, index)
	var j: Vector2i = world.decor_jejak(kind, rot)
	return {
		"kind": kind,
		"index": index,
		"rot": rot,
		"jejak": j,
		"label": "%s %d" % [nama_jenis(kind), index + 1],
		"ukuran": "%d x %d petak" % [j.x, j.y],
	}


static func nama_jenis(kind: String) -> String:
	match kind:
		"mixer": return "Mixer"
		"oven": return "Oven"
		"display": return "Rak Display"
		"storage": return "Gudang Penyimpanan"
	return kind


## Titik layar untuk menempel tombol putar di atas perabot terpilih.
func titik_tombol() -> Vector2:
	if _sel.is_empty() or world == null:
		return Vector2.ZERO
	return world.decor_screen_top(
		world.decor_node(String(_sel["kind"]), int(_sel["index"])))


# ===========================================================================
# PUTAR
# ===========================================================================

func putar() -> void:
	if _sel.is_empty() or world == null:
		return
	var kind: String = String(_sel["kind"])
	var index: int = int(_sel["index"])
	var rot_baru: int = (world.decor_rot_of(kind, index) + 90) % 180
	var anchor: Vector2i = world.decor_anchor(kind, index)
	var alasan: String = world.decor_reason(kind, index, anchor, rot_baru)
	if alasan != "":
		# Diputar di tempat tidak muat. Dicoba digeser mundur setengah jejak —
		# rak 2x1 di ubin terakhir kolomnya selalu gagal diputar tanpa ini.
		var j: Vector2i = world.decor_jejak(kind, rot_baru)
		var mundur := Vector2i(
			clampi(anchor.x, 0, maxi(EquipmentFactory.floor_cols(GameState.location_tier) - j.x, 0)),
			clampi(anchor.y, 0, maxi(EquipmentFactory.floor_rows(GameState.location_tier) - j.y, 0)))
		alasan = world.decor_reason(kind, index, mundur, rot_baru)
		if alasan != "":
			emit_signal("status", "Tidak bisa diputar di sini: %s" % alasan, false)
			AudioBus.sfx("tap")
			return
		anchor = mundur
	world.decor_place(kind, index, anchor, rot_baru)
	_anchor_asal = anchor
	_boleh = true
	_perbarui_sorot()
	AudioBus.sfx("pop")
	emit_signal("selection_changed", info_pilihan())
	emit_signal("moved")
	emit_signal("status", "Diputar. Ukuran sekarang %s."
		% String(info_pilihan().get("ukuran", "")), true)


# ===========================================================================
# INPUT
# ===========================================================================

func _unhandled_input(event: InputEvent) -> void:
	if not aktif or world == null:
		return
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index != MOUSE_BUTTON_LEFT:
			return
		if mb.pressed:
			_tekan(mb.position)
		else:
			lepas()
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			_tekan(st.position)
		else:
			lepas()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and _menyeret:
		_tarik((event as InputEventMouseMotion).position)
	elif event is InputEventScreenDrag and _menyeret:
		_tarik((event as InputEventScreenDrag).position)


func _tekan(titik: Vector2) -> void:
	_titik_tekan = titik
	_geser = false
	# Yang dipilih adalah perabot yang BADANNYA tersentuh, bukan penghuni ubin
	# di bawah kursor. Petak di bawah kursor tetap dipakai, tapi hanya sebagai
	# titik genggam: selama seret, perabot bergerak sejauh petak yang ditempuh
	# kursor — jadi ia tetap terasa menempel di tempat pemain menyentuhnya,
	# di mana pun pada badannya itu berada.
	mulai_seret_perabot(world.decor_pick_at_screen(titik),
		world.decor_tile_at_screen(titik))


## Gerakan layar baru dihitung sebagai SERETAN setelah melewati DRAG_SLOP.
## Tanpa ambang ini, getaran jari beberapa piksel saat mengetuk sudah dianggap
## memindahkan perabot, dan pemain tidak pernah bisa sekadar memilih.
func _tarik(titik: Vector2) -> void:
	if not _geser and titik.distance_to(_titik_tekan) < DRAG_SLOP:
		return
	_geser = true
	seret(world.decor_tile_at_screen(titik))


# ---------------------------------------------------------------------------
# Niat pemain sebagai fungsi publik.
#
# Sengaja dipisah dari _unhandled_input(): input mentah hanya menerjemahkan
# titik layar menjadi petak, sisanya murni logika petak. Itu yang membuat
# seluruh alur pilih-seret-lepas bisa diuji headless tanpa memalsukan
# InputEvent, dan yang membuat daftar "Perabot Saya" bisa memilih perabot
# lewat jalur yang sama persis dengan sentuhan.
# ---------------------------------------------------------------------------

## Mulai menyeret perabot `pilihan` ({"kind","index"}), dengan `petak` sebagai
## titik genggam. Dictionary kosong berarti tidak ada yang tersentuh; pilihan
## sebelumnya ikut dilepas.
func mulai_seret_perabot(pilihan: Dictionary, petak: Vector2i) -> bool:
	if world == null or pilihan.is_empty():
		batal_pilih()
		return false
	var kind: String = String(pilihan["kind"])
	var index: int = int(pilihan["index"])
	pilih(kind, index)
	# Selisih anchor terhadap petak genggam dipertahankan, supaya perabot tidak
	# melompat agar pusatnya menempel ke jari.
	_genggam = world.decor_anchor(kind, index) - petak
	_menyeret = true
	return true


## Varian berbasis PETAK: memilih penghuni satu ubin. Dipakai daftar "Perabot
## Saya" dan suite tes, yang memang berpikir dalam petak dan bukan dalam sinar.
func mulai_seret(petak: Vector2i) -> bool:
	if world == null:
		return false
	return mulai_seret_perabot(world.decor_at(petak), petak)


## Menyeret pilihan sehingga `petak` kembali berada di titik genggaman semula.
func seret(petak: Vector2i) -> void:
	if _sel.is_empty() or world == null or petak.x < 0:
		return
	# Memanggil seret() SUDAH berarti menyeret. Dulu penanda ini cuma dipasang
	# di jalur input mentah, sehingga seretan yang datang dari mana pun selain
	# gerakan tetikus dianggap ketukan biasa — dan lepas() lupa memulangkan
	# perabot yang berhenti di tempat terlarang.
	_geser = true
	var kind: String = String(_sel["kind"])
	var index: int = int(_sel["index"])
	var rot: int = world.decor_rot_of(kind, index)
	var anchor: Vector2i = petak + _genggam
	if anchor == world.decor_anchor(kind, index):
		return

	var alasan: String = world.decor_reason(kind, index, anchor, rot)
	# Perabot tetap mengikuti jari walau tempatnya terlarang; yang berubah hanya
	# warna kedipnya. Perabot yang berhenti mengikuti jari terasa macet, dan
	# pemain tidak pernah tahu petak mana yang sebenarnya sedang ia tuju.
	world.decor_place(kind, index, anchor, rot)
	_boleh = alasan == ""
	_perbarui_sorot()
	emit_signal("moved")
	if not _boleh:
		emit_signal("status", alasan, false)


## Melepas seretan: menerima tempat baru bila sah, memulangkan bila tidak.
func lepas() -> void:
	if not _menyeret:
		return
	_menyeret = false
	if _sel.is_empty() or world == null:
		return
	var kind: String = String(_sel["kind"])
	var index: int = int(_sel["index"])
	if not _geser:
		emit_signal("status", "%s dipilih. Seret untuk memindahkan."
			% String(info_pilihan().get("label", "")), true)
		return

	var rot: int = world.decor_rot_of(kind, index)
	var anchor: Vector2i = world.decor_anchor(kind, index)
	var alasan: String = world.decor_reason(kind, index, anchor, rot)
	if alasan != "":
		world.decor_place(kind, index, _anchor_asal, rot)
		_boleh = true
		_perbarui_sorot()
		emit_signal("moved")
		emit_signal("status", "%s Dikembalikan ke tempat semula." % alasan, false)
		AudioBus.sfx("tap")
		return
	_anchor_asal = anchor
	_boleh = true
	_perbarui_sorot()
	AudioBus.sfx("pop")
	emit_signal("status", "%s dipindahkan." % String(info_pilihan().get("label", "")), true)


## Apakah perabot terpilih sedang berdiri di tempat yang sah. Dipakai UI dan
## suite tes untuk membaca warna kedip tanpa menebak dari materialnya.
func tempat_sah() -> bool:
	return _boleh


# ===========================================================================
# KEDIP & SOROTAN
# ===========================================================================

## Kedip dijalankan trigonometris di _process, bukan lewat Tween berulang:
## satu perabot bisa dipilih dan dilepas puluhan kali dalam satu sesi, dan
## Tween yang lupa di-kill akan menumpuk diam-diam (GDD 12.3: animasi
## prosedural, bukan rig).
func _process(delta: float) -> void:
	if not aktif or _lapis == null:
		return
	_t += delta
	var gelombang: float = 0.5 + 0.5 * sin(_t * TAU * BLINK_HZ)
	var a: float = lerpf(BLINK_MIN, BLINK_MAX, gelombang)
	var warna: Color = WARNA_OK if _boleh else WARNA_TOLAK
	_lapis.albedo_color = Color(warna.r, warna.g, warna.b, a)
	_lapis.emission = warna
	_lapis.emission_energy_multiplier = 0.25 + gelombang * 0.55
	if _sorot_mat != null:
		_sorot_mat.albedo_color = Color(warna.r, warna.g, warna.b, 0.18 + gelombang * 0.30)


func _pasang_lapisan(node: Node3D) -> void:
	_lapis = StandardMaterial3D.new()
	_lapis.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lapis.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lapis.albedo_color = Color(1.0, 1.0, 1.0, BLINK_MIN)
	_lapis.emission_enabled = true
	_lapis.emission = WARNA_OK
	# Tanpa ini lapisan hanya tampak di sisi yang menghadap kamera dan perabot
	# terlihat berkedip sebagian.
	_lapis.cull_mode = BaseMaterial3D.CULL_DISABLED
	_dilapisi.clear()
	var antrean: Array[Node] = [node]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		mi.material_overlay = _lapis
		_dilapisi.append(mi)


func _lepas_pilihan() -> void:
	if world != null and not _sel.is_empty():
		var node: Node3D = world.decor_node(String(_sel["kind"]), int(_sel["index"]))
		if node != null and is_instance_valid(node):
			node.position.y = 0.0
	for mi in _dilapisi:
		if is_instance_valid(mi):
			mi.material_overlay = null
	_dilapisi.clear()
	_lapis = null
	_sel = {}
	_menyeret = false
	_geser = false
	if _sorot != null and is_instance_valid(_sorot):
		_sorot.visible = false


## Petak tujuan disorot sebagai pelat tipis di lantai, seukuran JEJAK perabot.
## Tanpa ini pemain tidak pernah tahu rak 2x1 sebenarnya memakan petak yang mana.
func _buat_sorot() -> void:
	if _sorot != null and is_instance_valid(_sorot):
		return
	if world == null or world.fixtures == null:
		return
	_sorot_mat = StandardMaterial3D.new()
	_sorot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_sorot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_sorot_mat.albedo_color = Color(1.0, 1.0, 1.0, 0.25)
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1.0, 0.02, 1.0)
	_sorot = MeshInstance3D.new()
	_sorot.name = "DecorSorot"
	_sorot.mesh = mesh
	_sorot.material_override = _sorot_mat
	_sorot.visible = false
	world.add_child(_sorot)


func _perbarui_sorot() -> void:
	if _sorot == null or not is_instance_valid(_sorot) or _sel.is_empty() or world == null:
		return
	var kind: String = String(_sel["kind"])
	var index: int = int(_sel["index"])
	var rot: int = world.decor_rot_of(kind, index)
	var j: Vector2i = world.decor_jejak(kind, rot)
	var tile: float = EquipmentFactory.FLOOR_TILE
	var a: Vector2i = world.decor_anchor(kind, index)
	var tier: int = GameState.location_tier
	_sorot.scale = Vector3(float(j.x) * tile, 1.0, float(j.y) * tile)
	_sorot.position = Vector3(
		EquipmentFactory.tile_x(tier, a.x) + float(j.x - 1) * 0.5 * tile,
		0.012,
		EquipmentFactory.tile_z(tier, a.y) + float(j.y - 1) * 0.5 * tile)
	_sorot.visible = true
