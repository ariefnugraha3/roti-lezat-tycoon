class_name Signboard
extends Control
## Papan nama toko baru di cutscene Waralaba (GDD idle 10.6): papan kayu di atas
## dua tiang, digambar dengan _draw() dalam warna datar (v3.1 130.6), nama toko
## dan "Branch #n" sebagai label di tengahnya.

var title_text: String = ""
var sub_text: String = ""
var _title: Label = null
var _sub: Label = null


func _ready() -> void:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 6)
	v.anchor_left = 0.12
	v.anchor_right = 0.88
	v.anchor_top = 0.1
	v.anchor_bottom = 0.62
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	_title = ProceduralUIFactory.label(title_text, 30, Palette.FLOUR_WHITE)
	_title.name = "Title"
	_title.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_title)
	_sub = ProceduralUIFactory.label(sub_text, 20, Palette.GOLD_STAR)
	_sub.name = "Sub"
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_sub)


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	# Tiang.
	for x: float in [w * 0.22, w * 0.78]:
		draw_rect(Rect2(x - w * 0.025, h * 0.55, w * 0.05, h * 0.45), Palette.UI_WOOD_DEEP)
	# Papan dan bingkainya.
	var board := Rect2(0.0, 0.0, w, h * 0.7)
	_box(Palette.UI_WOOD_DEEP, 22).draw(get_canvas_item(), board)
	_box(Palette.UI_WOOD, 16).draw(get_canvas_item(), board.grow(-10.0))
	# Dua paku emas.
	for px: float in [w * 0.06, w * 0.94]:
		draw_circle(Vector2(px, h * 0.08), 7.0, Palette.GOLD_STAR)


static func _box(c: Color, radius: int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(radius)
	return sb
