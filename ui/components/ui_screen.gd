class_name UIScreen
extends Control
## Basis setiap layar/modal (GDD 28). Layar dibangun dari kode dengan
## ProceduralUIFactory; teks selalu lewat Tx.t (GDD 43, 127).
##
## `blocking` = modal keputusan: selama terbuka simulasi di-pause lewat
## PauseManager dan input dunia dimatikan (GDD 15.2, 28.2, 71).

signal closed(screen: UIScreen)

var host: ModalHost = null
var sim: SimulationRoot = null
var game: GameRoot = null
var params: Dictionary = {}
var blocking: bool = true
## Decoration Mode: tap dunia tetap diteruskan walau simulasi di-pause.
var world_input: bool = false
var screen_id: StringName = &""
var _built: bool = false


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _ready() -> void:
	ProceduralUIFactory.apply_theme(self)
	if not _built:
		_built = true
		build()


## Diisi turunan: bangun seluruh isi layar.
func build() -> void:
	pass


## Dipanggil ModalHost saat Back/Escape. Kembalikan false untuk menolak.
func on_back() -> bool:
	close()
	return true


func close() -> void:
	if host != null:
		host.close_screen(self)
	else:
		on_closed()
		queue_free()


## Dipanggil tepat sekali saat layar ditutup dengan cara apa pun (termasuk
## close_all). Turunan membersihkan state sementara di sini.
func on_closed() -> void:
	pass


## Helper: popup standar dengan tombol tutup (X) di baris judul.
func make_popup(title_text: String, size_v: Vector2 = ProceduralUIFactory.POPUP_SIZE, closable: bool = true) -> VBoxContainer:
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var vp: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280, 720)
	var sz := Vector2(minf(size_v.x, vp.x - inset.x - inset.z - 24.0), minf(size_v.y, vp.y - inset.y - inset.w - 24.0))
	var p: Control = ProceduralUIFactory.popup(title_text, sz)
	add_child(p)
	if closable:
		var head: HBoxContainer = p.get_meta("head")
		var x: Button = ProceduralUIFactory.icon_button("cross", Tx.t("ui_close"), "ghost")
		x.pressed.connect(on_back)
		head.add_child(x)
	return p.get_meta("body")


## Helper: area gulir vertikal yang mengisi sisa ruang.
static func scroll_box(parent: Control) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(sc)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 8)
	sc.add_child(v)
	return v


static func hbox(parent: Control, sep: int = 10) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	parent.add_child(h)
	return h


static func lbl(parent: Control, text: String, size: int = 18, color: Color = Palette.TEXT, wrap: bool = false) -> Label:
	var l: Label = ProceduralUIFactory.label(text, size, color)
	if wrap:
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(l)
	return l


static func btn(parent: Control, text: String, kind: String, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.button(text, kind)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func clear(node: Node) -> void:
	for c: Node in node.get_children():
		node.remove_child(c)
		c.queue_free()
