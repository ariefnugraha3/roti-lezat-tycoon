class_name CharacterSelectScreen
extends Control
## Pemilihan karakter pemain, muncul sekali saat menekan "Main Baru".
##
## Dua pilihan saja, digambar sebagai potret chibi lewat CanvasItem._draw()
## (GDD 4.3: seluruh ikon dan ilustrasi UI prosedural). Potretnya memakai
## proporsi yang sama dengan karakter 3D — kepala bulat besar, pipi merona —
## supaya pemain mengenali sosok yang akan ia mainkan, bukan ikon generik.

var _main: Node = null
var _terpilih: String = GameState.PLAYER_GENDER_DEFAULT
var _kartu: Dictionary = {}   # gender -> PanelContainer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build()


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	_terpilih = GameState.player_gender()
	_sync()


func _build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	margin.add_theme_constant_override("margin_left", int(safe.x) + 28)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 24)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 28)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 24)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 16)
	center.add_child(kolom)

	var judul: Label = ProceduralUIFactory.title("Siapa yang Memanggang?", 34)
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(judul)

	var sub: Label = ProceduralUIFactory.label(
		"Pilih karakter yang akan kamu mainkan. Dia yang akan mengambil bahan, "
		+ "mengaduk adonan, dan menata roti di rak.", 15, Palette.TEXT_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(560, 0)
	kolom.add_child(sub)

	var baris := HBoxContainer.new()
	baris.add_theme_constant_override("separation", 20)
	baris.alignment = BoxContainer.ALIGNMENT_CENTER
	kolom.add_child(baris)
	baris.add_child(_kartu_karakter("pria", "Pria", "Topi koki, celemek kopi."))
	baris.add_child(_kartu_karakter("wanita", "Wanita", "Bandana, kepang, celemek pastel."))

	var mulai: Button = ProceduralUIFactory.button("Mulai Bekerja", "primary")
	mulai.custom_minimum_size = Vector2(0, 52)
	mulai.pressed.connect(_on_mulai)
	kolom.add_child(mulai)

	var batal: Button = ProceduralUIFactory.button("Kembali", "ghost")
	batal.pressed.connect(_on_batal)
	kolom.add_child(batal)


func _kartu_karakter(gender: String, nama: String, catatan: String) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PANEL, 22, true))
	pc.custom_minimum_size = Vector2(230, 0)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var m := MarginContainer.new()
	for sisi in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + sisi, 14)
	pc.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	var potret := ChibiPortrait.new()
	potret.gender = gender
	potret.custom_minimum_size = Vector2(190, 190)
	potret.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(potret)

	var label: Label = ProceduralUIFactory.label(nama, 20)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(label)

	var ket: Label = ProceduralUIFactory.label(catatan, 12, Palette.TEXT_MUTED)
	ket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ket)

	var pilih: Button = ProceduralUIFactory.button("Pilih", "secondary")
	pilih.pressed.connect(_on_pilih.bind(gender))
	v.add_child(pilih)

	_kartu[gender] = pc
	return pc


func _on_pilih(gender: String) -> void:
	_terpilih = gender
	AudioBus.sfx("tap")
	_sync()


## Kartu terpilih diberi bingkai emas dan sedikit membesar. Tanpa penanda visual
## yang jelas, pemain menekan "Mulai" tanpa tahu mana yang sedang dipilih.
func _sync() -> void:
	for g in _kartu.keys():
		var pc: PanelContainer = _kartu[g]
		if pc == null or not is_instance_valid(pc):
			continue
		var aktif: bool = String(g) == _terpilih
		var kotak: StyleBoxFlat = ProceduralUIFactory.panel(
			Palette.PANEL if aktif else Palette.PANEL_ALT, 22, true)
		if aktif:
			kotak.border_width_left = 4
			kotak.border_width_right = 4
			kotak.border_width_top = 4
			kotak.border_width_bottom = 4
			kotak.border_color = Palette.GOLD_STAR
		pc.add_theme_stylebox_override("panel", kotak)
		pc.modulate = Color.WHITE if aktif else Color(1.0, 1.0, 1.0, 0.72)


func _on_mulai() -> void:
	AudioBus.sfx("pop")
	var m: Node = _main if _main != null else _find_main()
	if m != null and m.has_method("new_game"):
		m.call("new_game", _terpilih)


func _on_batal() -> void:
	AudioBus.sfx("tap")
	if not ScreenRouter.back():
		ScreenRouter.go("main_menu")


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


## Potret chibi 2D yang digambar langsung, bukan hasil render 3D.
##
## Merender karakter 3D ke SubViewport hanya untuk dua gambar diam jauh lebih
## mahal daripada menggambar ulang siluetnya dengan beberapa lingkaran — dan
## siluet itulah yang sebenarnya membedakan kedua pilihan.
class ChibiPortrait:
	extends Control

	var gender: String = "pria":
		set(value):
			gender = value
			queue_redraw()

	func _draw() -> void:
		var s: float = minf(size.x, size.y)
		if s < 8.0:
			return
		var c := Vector2(size.x * 0.5, size.y * 0.5)
		var wanita: bool = gender == "wanita"

		var kulit: Color = Color(0.980, 0.851, 0.737) if wanita else Color(0.949, 0.788, 0.627)
		var rambut: Color = Color(0.290, 0.192, 0.129) if wanita else Color(0.169, 0.129, 0.094)
		var celemek: Color = Palette.APRON_ORANGE_PASTEL if wanita else Palette.APRON_COFFEE_BROWN

		# Latar bulat hangat supaya potret terbaca sebagai satu benda.
		draw_circle(c, s * 0.46, Palette.VANILLA_CREAM)

		# Badan + celemek.
		var badan_y: float = c.y + s * 0.20
		draw_circle(Vector2(c.x, badan_y), s * 0.20, Palette.FLOUR_WHITE)
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - s * 0.13, badan_y - s * 0.05),
			Vector2(c.x + s * 0.13, badan_y - s * 0.05),
			Vector2(c.x + s * 0.16, badan_y + s * 0.20),
			Vector2(c.x - s * 0.16, badan_y + s * 0.20),
		]), celemek)

		# Rambut belakang: kepang panjang hanya pada karakter wanita.
		var kepala := Vector2(c.x, c.y - s * 0.08)
		if wanita:
			draw_circle(Vector2(kepala.x - s * 0.20, kepala.y + s * 0.16), s * 0.075, rambut)
			draw_circle(Vector2(kepala.x + s * 0.20, kepala.y + s * 0.16), s * 0.075, rambut)

		# Kepala bulat besar (GDD 4.1).
		draw_circle(kepala, s * 0.23, kulit)
		# Tempurung rambut: setengah lingkaran atas.
		draw_arc(kepala, s * 0.225, PI, TAU, 24, rambut, s * 0.075)
		draw_circle(Vector2(kepala.x, kepala.y - s * 0.115), s * 0.135, rambut)

		# Penutup kepala: bandana untuk wanita, topi koki untuk pria.
		if wanita:
			draw_colored_polygon(PackedVector2Array([
				Vector2(kepala.x - s * 0.23, kepala.y - s * 0.10),
				Vector2(kepala.x + s * 0.23, kepala.y - s * 0.10),
				Vector2(kepala.x + s * 0.21, kepala.y - s * 0.19),
				Vector2(kepala.x - s * 0.21, kepala.y - s * 0.19),
			]), Palette.GINGHAM_A)
		else:
			draw_circle(Vector2(kepala.x, kepala.y - s * 0.28), s * 0.115, Palette.FLOUR_WHITE)
			draw_rect(Rect2(kepala.x - s * 0.19, kepala.y - s * 0.26,
				s * 0.38, s * 0.085), Palette.FLOUR_WHITE)

		# Wajah: mata, rona pipi, mulut tersenyum.
		var mata_dx: float = s * 0.085
		for sisi in [-1.0, 1.0]:
			draw_circle(Vector2(kepala.x + sisi * mata_dx, kepala.y + s * 0.01),
				s * 0.030, Color(0.129, 0.090, 0.075))
			draw_circle(Vector2(kepala.x + sisi * mata_dx + s * 0.010,
				kepala.y - s * 0.004), s * 0.011, Color.WHITE)
			draw_circle(Vector2(kepala.x + sisi * s * 0.155, kepala.y + s * 0.055),
				s * 0.032, Palette.ROSY_CHEEK)
		draw_arc(Vector2(kepala.x, kepala.y + s * 0.045), s * 0.055,
			0.15 * PI, 0.85 * PI, 14, Color(0.451, 0.204, 0.180), s * 0.020)
