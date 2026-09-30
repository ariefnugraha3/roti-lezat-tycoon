class_name SkipOverlay
extends CanvasLayer
## Lapisan "Skip to Open" (GDD 15.4): dunia tetap tergambar di belakangnya seperti
## time-lapse sementara jam berlari ke 08:00. Menahan semua ketukan selama
## lompatan, tetapi berada di bawah ModalHost supaya modal yang muncul (tutorial,
## lifecycle) tetap bisa ditutup; lompatan menunggu selama modal itu terbuka.

const LAYER: int = 15
const FADE_IN: float = 0.20
const FADE_OUT: float = 0.30

var _root: Control = null
var _title: Label = null
var _clock: Label = null
var _bar: ProgressBar = null
var _from: float = 0.0
var _to: float = 1.0


func _init() -> void:
	layer = LAYER
	name = "SkipOverlay"
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	ProceduralUIFactory.apply_theme(_root)
	var tint := ColorRect.new()
	tint.color = Color(Palette.GOLDEN_HOUR, 0.28)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(tint)
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PARCHMENT, 22, true)
	sb.set_content_margin_all(20.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.set_anchors_preset(Control.PRESET_CENTER)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	_root.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(ProceduralUIFactory.icon("sun", 34, Palette.GOLD_STAR))
	_title = ProceduralUIFactory.title("", 24)
	head.add_child(_title)
	_clock = ProceduralUIFactory.title("", 34)
	v.add_child(_clock)
	_bar = ProgressBar.new()
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(320, 18)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bar)
	_root.modulate.a = 0.0


## Mulai dari jam `from_seconds` menuju `to_seconds` (detik jam in-game).
func begin(from_seconds: float, to_seconds: float) -> void:
	_from = from_seconds
	_to = maxf(to_seconds, from_seconds + 1.0)
	_title.text = Tx.t("ui_skip_open_busy", {"time": Tx.clock(to_seconds)})
	show_time(from_seconds)
	var tw: Tween = _root.create_tween()
	tw.tween_property(_root, "modulate:a", 1.0, FADE_IN)


func show_time(seconds: float) -> void:
	_clock.text = Tx.clock(seconds)
	_bar.value = clampf((seconds - _from) / (_to - _from), 0.0, 1.0)


func clock_text() -> String:
	return _clock.text


## Pudar lalu hilang. Ketukan langsung dilepas supaya pemain bisa segera bermain.
func finish() -> void:
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_inside_tree():
		queue_free()
		return
	var tw: Tween = _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)
