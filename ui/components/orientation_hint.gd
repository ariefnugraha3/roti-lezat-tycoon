class_name OrientationHint
extends CanvasLayer
## Petunjuk sekali di browser HP yang dipegang landscape (GDD idle 12.0.6):
## "Turn your phone upright for a bigger view." Tidak menghalangi apa pun, tidak
## mem-pause, dan hilang sendiri setelah `SHOW_SECONDS` detik nyata. Bingkai
## potret dengan taplak di kedua sisi tetap bisa dimainkan. Muncul paling banyak
## sekali per sesi.
##
## Hanya dipasang GameRoot di browser HP (WebPlatform.is_mobile_web()).

const LAYER: int = 85
const SHOW_SECONDS: float = 4.0
const FADE_SECONDS: float = 0.35

var _card: PanelContainer = null
var _left: float = -1.0
var _shown_once: bool = false


func _init() -> void:
	layer = LAYER
	name = "OrientationHint"
	var holder := Control.new()
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)
	ProceduralUIFactory.apply_theme(holder)
	_card = PanelContainer.new()
	_card.name = "Card"
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 22, true)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", sb)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.0
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.offset_top = 150.0
	holder.add_child(_card)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 10)
	_card.add_child(row)
	row.add_child(ProceduralUIFactory.icon("rotate", 26, Palette.UI_WOOD))
	var l: Label = ProceduralUIFactory.label(Tx.t("ui_turn_upright"), 18, Palette.TEXT)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(420.0, 0.0)
	row.add_child(l)
	_card.visible = false


func _process(delta: float) -> void:
	if _left < 0.0:
		if not _shown_once and not WebPlatform.is_portrait():
			show_hint()
		return
	_left -= delta
	_card.modulate.a = clampf(_left / FADE_SECONDS, 0.0, 1.0)
	if _left <= 0.0:
		_card.visible = false
		_left = -1.0


## Tampilkan petunjuknya sekarang (sekali per sesi).
func show_hint() -> void:
	if _shown_once:
		return
	_shown_once = true
	_left = SHOW_SECONDS
	_card.visible = true
	_card.modulate.a = 1.0


func is_showing() -> bool:
	return _card.visible


func was_shown() -> bool:
	return _shown_once
