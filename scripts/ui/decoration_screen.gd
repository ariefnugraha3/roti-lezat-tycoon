class_name DecorationScreen
extends Control
## Lapisan kendali Mode Dekorasi (GDD 7 "Mode Dekorasi" dan "Dekorasi &
## Kustomisasi").
##
## Layar ini sengaja TEMBUS PANDANG: penataan terjadi di dunia 3D yang sama
## dengan yang dilihat pemain saat bermain, bukan di papan petak terpisah.
## Papan petak lama memaksa pemain menerjemahkan sendiri "petak 3,7" menjadi
## sudut ruangan yang mana, dan terjemahan itulah sumber setiap keluhan bahwa
## perabot mendarat di tempat yang salah.
##
## Semua niat pemain diteruskan ke DecorController; layar ini hanya menyediakan
## tombol dan keterangan. Tata letak bukan sekadar hiasan — GDD menegaskan
## posisi alat memengaruhi jarak jalan staf dan posisi rak memengaruhi antrean.

## Sisi tombol putar yang melayang di atas perabot terpilih. Minimal 48 dp
## (GDD 7 / 12.4), dilebihkan sedikit karena ia melayang di atas dunia 3D.
const TOMBOL_PUTAR_PX: int = 56

var _main: Node = null
var _world: ShopWorld = null
var _dekor: DecorController = null

var _info: Label = null
var _tombol_putar: Button = null
var _panel_daftar: PanelContainer = null
var _isi_daftar: VBoxContainer = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Seluruh lapisan meneruskan sentuhan ke dunia 3D; hanya tombol yang
	# benar-benar memakannya. Tanpa ini tidak ada satu pun ketukan yang sampai
	# ke perabot, karena Control sebesar layar menadah semuanya lebih dulu.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ProceduralUIFactory.apply_theme(self)
	_build_shell()


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	if _main != null:
		_world = _main.get("world") as ShopWorld
	if _world == null:
		return
	_dekor = _world.decor_controller()
	if not _dekor.selection_changed.is_connected(_on_selection):
		_dekor.selection_changed.connect(_on_selection)
	if not _dekor.status.is_connected(_on_status):
		_dekor.status.connect(_on_status)
	if not _dekor.moved.is_connected(_on_moved):
		_dekor.moved.connect(_on_moved)
	_dekor.mulai()
	_on_selection({})
	_isi_panel_daftar()


func _exit_tree() -> void:
	if _dekor != null and is_instance_valid(_dekor):
		_dekor.selesai()


# ===========================================================================
# RANGKA
# ===========================================================================

func _build_shell() -> void:
	# Tidak ada ColorRect latar: dunia 3D di belakangnya justru yang ditata.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	margin.add_theme_constant_override("margin_left", int(safe.x) + 20)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 16)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 20)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 16)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(head)

	var judul: Label = ProceduralUIFactory.title("Mode Dekorasi", 26)
	judul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	judul.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_child(judul)

	var daftar: Button = ProceduralUIFactory.button("Perabot Saya", "secondary")
	daftar.pressed.connect(_on_toggle_daftar)
	head.add_child(daftar)
	var reset: Button = ProceduralUIFactory.button("Kembalikan Awal", "secondary")
	reset.pressed.connect(_on_reset)
	head.add_child(reset)
	var tutup: Button = ProceduralUIFactory.button("Selesai", "primary")
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	_info = ProceduralUIFactory.label(
		"Ketuk perabot untuk memilih, lalu seret ke tempat baru.",
		15, Palette.TEXT_MUTED)
	_info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_info)

	_build_tombol_putar()
	_build_panel_daftar()


## Tombol putar melayang MENEMPEL pada perabot terpilih, bukan berdiam di tepi
## layar: pemain sedang menatap perabotnya, dan tombol yang jauh dari sana
## memaksa matanya bolak-balik.
func _build_tombol_putar() -> void:
	_tombol_putar = ProceduralUIFactory.button("Putar", "primary")
	_tombol_putar.custom_minimum_size = Vector2(TOMBOL_PUTAR_PX + 24, TOMBOL_PUTAR_PX)
	_tombol_putar.visible = false
	_tombol_putar.pressed.connect(_on_putar)
	add_child(_tombol_putar)


func _build_panel_daftar() -> void:
	_panel_daftar = PanelContainer.new()
	_panel_daftar.name = "PanelDaftar"
	_panel_daftar.visible = false
	_panel_daftar.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL, 18, true))
	_panel_daftar.clip_contents = true
	# Ditambatkan ke tepi kanan dengan offset eksplisit, bukan lewat preset:
	# preset tanpa ukuran membuat PanelContainer menyusut jadi nol dan panelnya
	# "terbuka" tanpa ada yang terlihat.
	_panel_daftar.anchor_left = 1.0
	_panel_daftar.anchor_right = 1.0
	_panel_daftar.anchor_top = 0.0
	_panel_daftar.anchor_bottom = 1.0
	_panel_daftar.offset_left = -332.0
	_panel_daftar.offset_right = -20.0
	_panel_daftar.offset_top = 104.0
	_panel_daftar.offset_bottom = -20.0
	add_child(_panel_daftar)

	var marg := MarginContainer.new()
	for sisi in ["left", "top", "right", "bottom"]:
		marg.add_theme_constant_override("margin_" + sisi, 14)
	_panel_daftar.add_child(marg)

	# Daftar bisa panjang di Mega Bakery (5 mixer + 5 oven + 6 rak), jadi
	# isinya digulir alih-alih dipaksa muat.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	marg.add_child(scroll)

	_isi_daftar = VBoxContainer.new()
	_isi_daftar.add_theme_constant_override("separation", 6)
	_isi_daftar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_isi_daftar)


# ===========================================================================
# DAFTAR PERABOT
# ===========================================================================

## Daftar perabot yang DIMILIKI pemain, dikelompokkan per jenis.
##
## Dibaca dari dunia 3D, bukan dari denah tersimpan: selama Mode Dekorasi
## duniala yang menjadi sumber kebenaran, dan daftar yang menunjukkan hal
## berbeda dari yang terlihat hanya akan membingungkan.
func _isi_panel_daftar() -> void:
	if _isi_daftar == null or _world == null:
		return
	for c in _isi_daftar.get_children():
		c.queue_free()

	_isi_daftar.add_child(ProceduralUIFactory.title("Perabot Saya", 20))
	var loc: Dictionary = LocationDB.entry(GameState.location_tier)
	# Gudang sengaja TIDAK punya kunci slot: jumlahnya tidak diatur tabel lokasi,
	# ia selalu satu buah yang ikut bangunan (GDD 5.2.2). Kunci yang tidak ada
	# jatuh ke jumlah terpasang, jadi barisnya terbaca "terpasang 1 dari 1".
	var slot_key: Dictionary = {
		"mixer": "mixer_slots", "oven": "oven_slots", "display": "rack_slots"}

	for kind in ShopWorld.DECOR_KINDS:
		var jumlah: int = _world.decor_count(kind)
		var slot: int = int(loc.get(String(slot_key.get(kind, "")), jumlah))
		_isi_daftar.add_child(_baris_teks(
			"%s — %s" % [DecorController.nama_jenis(kind),
				_world.decor_nama_alat(kind)],
			15, Palette.TEXT))
		var j: Vector2i = _world.decor_jejak(kind, 0)
		_isi_daftar.add_child(_baris_teks(
			"%d x %d petak (%d x %d cm) · terpasang %d dari %d slot"
			% [j.x, j.y,
				int(round(float(j.x) * EquipmentFactory.FLOOR_TILE * 100.0)),
				int(round(float(j.y) * EquipmentFactory.FLOOR_TILE * 100.0)),
				jumlah, slot],
			12, Palette.TEXT_MUTED))

		var baris := HBoxContainer.new()
		baris.add_theme_constant_override("separation", 6)
		_isi_daftar.add_child(baris)
		for i in jumlah:
			var b: Button = ProceduralUIFactory.button("#%d" % (i + 1), "secondary")
			b.custom_minimum_size = Vector2(48, 48)
			b.pressed.connect(_on_pilih_dari_daftar.bind(kind, i))
			baris.add_child(b)


## Satu baris teks di panel daftar: WAJIB membungkus kata.
## Nama alat tier tinggi panjang-panjang ("Oven Konveksi Industri Enam Rak"),
## dan Label yang tidak membungkus tidak terpotong melainkan MELIMPAH keluar
## panel sampai ke tepi layar.
func _baris_teks(teks: String, ukuran: int, warna: Color) -> Label:
	var l: Label = ProceduralUIFactory.label(teks, ukuran, warna)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(240, 0)
	return l


func _on_pilih_dari_daftar(kind: String, index: int) -> void:
	if _dekor == null:
		return
	_dekor.pilih(kind, index)
	AudioBus.sfx("tap")


func _on_toggle_daftar() -> void:
	if _panel_daftar == null:
		return
	_panel_daftar.visible = not _panel_daftar.visible
	if _panel_daftar.visible:
		_isi_panel_daftar()
	AudioBus.sfx("tap")


# ===========================================================================
# SINYAL DARI PENGENDALI
# ===========================================================================

func _on_selection(info: Dictionary) -> void:
	if _tombol_putar == null:
		return
	_tombol_putar.visible = not info.is_empty()
	_letakkan_tombol()


func _on_moved() -> void:
	_letakkan_tombol()


func _on_status(text: String, ok: bool) -> void:
	if _info == null:
		return
	_info.text = text
	_info.add_theme_color_override("font_color",
		Palette.TEXT_MUTED if ok else Palette.DANGER)


func _process(_delta: float) -> void:
	# Tombol ikut bergerak selama perabot diseret. Sinyal `moved` sudah menutupi
	# sebagian besar kasus, tapi kamera juga masih boleh beranimasi masuk.
	if _tombol_putar != null and _tombol_putar.visible:
		_letakkan_tombol()


func _letakkan_tombol() -> void:
	if _tombol_putar == null or not _tombol_putar.visible or _dekor == null:
		return
	var titik: Vector2 = _dekor.titik_tombol()
	var ukuran: Vector2 = _tombol_putar.size
	if ukuran == Vector2.ZERO:
		ukuran = _tombol_putar.custom_minimum_size
	# Dijepit ke dalam layar: perabot di tepi ruangan bisa memproyeksikan
	# tombolnya ke luar viewport, dan tombol yang tidak terlihat sama saja
	# dengan tidak ada.
	var batas: Vector2 = get_viewport_rect().size
	_tombol_putar.position = Vector2(
		clampf(titik.x - ukuran.x * 0.5, 8.0, maxf(batas.x - ukuran.x - 8.0, 8.0)),
		clampf(titik.y - ukuran.y, 8.0, maxf(batas.y - ukuran.y - 8.0, 8.0)))


# ===========================================================================
# TOMBOL
# ===========================================================================

func _on_putar() -> void:
	if _dekor != null:
		_dekor.putar()


func _on_reset() -> void:
	if _dekor == null:
		return
	_dekor.kembalikan_awal()
	_isi_panel_daftar()
	AudioBus.sfx("paper")


func _on_close() -> void:
	AudioBus.sfx("tap")
	if _dekor != null:
		_dekor.selesai()
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


func _find_main() -> Node:
	var t := get_tree()
	if t == null:
		return null
	var node: Node = t.current_scene
	if node is Main:
		return node
	if node != null:
		for c in node.get_children():
			if c is Main:
				return c
	return null
