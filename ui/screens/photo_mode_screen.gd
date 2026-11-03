class_name PhotoModeScreen
extends UIScreen
## Photo mode (GDD idle 21.5): HUD disembunyikan, toko tetap berjalan, kamera
## bebas digeser (seret) dan di-zoom (roda / cubit) tanpa ketukan dunia, filter
## warna polos di atas dunia, bingkai polaroid bernama toko, lalu Capture
## memotret layar tanpa tombol-tombol ini dan menyimpannya / membagikannya
## seperti kartu Share. Dibuka dari menu Pause.

## Filter: [kunci teks, warna lapisan (alfa = kekuatan)]. Lapisan warna polos,
## tanpa shader (v3.1 89.5: tidak ada kombinasi material baru).
const FILTERS: Array = [
	["ui_photo_filter_none", Color(1.0, 1.0, 1.0, 0.0)],
	["ui_photo_filter_warm", Color(1.0, 0.72, 0.38, 0.16)],
	["ui_photo_filter_golden", Color(1.0, 0.58, 0.20, 0.24)],
	["ui_photo_filter_cool", Color(0.55, 0.68, 1.0, 0.16)],
	["ui_photo_filter_vintage", Color(0.62, 0.45, 0.28, 0.26)],
	["ui_photo_filter_night", Color(0.16, 0.18, 0.42, 0.34)],
]

var filter_index: int = 0
var framed: bool = false
var _tint: ColorRect = null
var _frame: Control = null
var _controls: Control = null
var _chips: Array[Button] = []
var _frame_btn: Button = null
## Hasil Capture terakhir (toast HUD tersembunyi selama photo mode).
var _status: Label = null


func _init() -> void:
	super._init()
	blocking = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	game.hud.set_decoration_active(true)
	game.commands.tap_override = func(_p: Vector2) -> void: pass
	game.world.camera_rig.set_free_pan(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_frame = PolaroidFrame.new()
	_frame.name = "PolaroidFrame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_frame as PolaroidFrame).caption = sim.bakery_name
	add_child(_frame)
	_build_controls()
	_apply()


func _build_controls() -> void:
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	_controls = MarginContainer.new()
	_controls.name = "Controls"
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_theme_constant_override("margin_left", int(inset.x) + 12)
	_controls.add_theme_constant_override("margin_top", int(inset.y) + 10)
	_controls.add_theme_constant_override("margin_right", int(inset.z) + 12)
	_controls.add_theme_constant_override("margin_bottom", int(inset.w) + 10)
	add_child(_controls)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_child(col)
	# Atas: judul kecil dan tombol tutup.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var hint: PanelContainer = ProceduralUIFactory.pill("frame", Tx.t("ui_photo_hint"), Color(Palette.UI_CREAM, 0.95), Palette.UI_WOOD_DEEP, 15)
	hint.name = "Hint"
	hint.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_BEGIN
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hint)
	var close_b: Button = ProceduralUIFactory.icon_button("cross", Tx.t("ui_close"), "plain", 24, Palette.UI_WOOD_DEEP)
	close_b.name = "Close"
	close_b.custom_minimum_size = Vector2(56, 56)
	close_b.pressed.connect(close)
	top.add_child(close_b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	# Bawah: panel krem dengan filter, bingkai, dan Capture.
	var panel := PanelContainer.new()
	panel.name = "Bar"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.97), 26, false)
	sb.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var flow := HFlowContainer.new()
	flow.name = "Filters"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	for i in FILTERS.size():
		var chip: Button = ProceduralUIFactory.button(Tx.t(str(FILTERS[i][0])), "soft")
		chip.name = "Filter%d" % i
		chip.custom_minimum_size = Vector2(0, 48)
		chip.pressed.connect(_set_filter.bind(i))
		flow.add_child(chip)
		_chips.append(chip)
	_status = lbl(v, "", 14, Palette.TEXT_MUTED, true)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_frame_btn = ProceduralUIFactory.icon_text_button("frame", Tx.t("ui_photo_frame"), "soft", 22, 17)
	_frame_btn.name = "FrameToggle"
	_frame_btn.custom_minimum_size = Vector2(150.0 * SettingsManager.text_scale(), 60)
	_frame_btn.pressed.connect(_toggle_frame)
	row.add_child(_frame_btn)
	var shoot: Button = ProceduralUIFactory.icon_text_button("camera", Tx.t("ui_photo_capture"), "primary", 24, 20)
	shoot.name = "Capture"
	shoot.custom_minimum_size = Vector2(220, 60)
	shoot.pressed.connect(capture)
	row.add_child(shoot)


func _set_filter(i: int) -> void:
	filter_index = clampi(i, 0, FILTERS.size() - 1)
	_apply()


func _toggle_frame() -> void:
	framed = not framed
	_apply()


func _apply() -> void:
	_tint.color = FILTERS[filter_index][1]
	_tint.visible = filter_index > 0
	_frame.visible = framed
	for i in _chips.size():
		ProceduralUIFactory.apply_kind(_chips[i], "primary" if i == filter_index else "soft")
	ProceduralUIFactory.apply_kind(_frame_btn, "primary" if framed else "soft")


## Potret layar dengan filter dan bingkai, tanpa tombol photo mode; lalu simpan
## atau bagikan seperti kartu Share. Mengembalikan gambarnya.
func capture() -> Image:
	_controls.visible = false
	await ShareCard.after_draw(self)
	await ShareCard.after_draw(self)
	var img: Image = ShareCard.grab(get_viewport())
	if not is_instance_valid(_controls):
		return img
	_controls.visible = true
	_flash()
	var r: Dictionary = ShareCard.export_png(img, ShareCard.file_base(sim, "photo"))
	match str(r.get("kind", "")):
		"share":
			_status.text = Tx.t("ui_photo_shared")
		"download":
			_status.text = Tx.t("ui_share_downloaded")
		"saved":
			_status.text = Tx.t("ui_photo_saved", {"path": str(r["path"])})
		_:
			_status.text = Tx.t("ui_share_failed")
	_status.visible = true
	EventBus.sfx.emit(&"ui_confirm", &"")
	return img


## Kilat putih singkat (dilewati dengan Reduced Motion).
func _flash() -> void:
	if SettingsManager.reduced_motion():
		return
	var f := ColorRect.new()
	f.color = Color(1.0, 1.0, 1.0, 0.8)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw: Tween = create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func on_closed() -> void:
	if game == null:
		return
	game.commands.tap_override = Callable()
	if game.world != null:
		game.world.camera_rig.set_free_pan(false)
	if game.hud != null:
		game.hud.set_decoration_active(false)


## Bingkai polaroid krem: tepi tipis di atas dan samping, tepi bawah lebar
## bertuliskan nama toko. Flat, tanpa bayangan.
class PolaroidFrame:
	extends Control
	var caption: String = ""

	func _draw() -> void:
		var side: float = size.x * 0.05
		var bottom: float = size.y * 0.14
		var c: Color = Palette.FLOUR_WHITE
		draw_rect(Rect2(0.0, 0.0, size.x, side), c)
		draw_rect(Rect2(0.0, 0.0, side, size.y), c)
		draw_rect(Rect2(size.x - side, 0.0, side, size.y), c)
		draw_rect(Rect2(0.0, size.y - bottom, size.x, bottom), c)
		var font: Font = ProceduralUIFactory.display_font()
		var fs: int = int(round(size.x * 0.06))
		var w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while fs > 12 and w > size.x - side * 4.0:
			fs -= 2
			w = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2((size.x - w) * 0.5, size.y - bottom * 0.42), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Palette.UI_WOOD_DEEP)
