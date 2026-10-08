class_name TutorialPulse
extends Control
## Cincin madu berdenyut di sekeliling tombol yang diminta tutorial (GDD 27.5,
## keputusan maintainer 2026-10-07): tombol Decoration Mode di Quick Menu dan
## tombol Done di Decoration Mode. Flat: garis polos tanpa bayangan. Dengan
## Reduced Motion cincinnya diam.

const NODE_NAME: String = "TutorialPulse"
const RING_PX: int = 4
const GROW_PX: float = 9.0
const PERIOD: float = 0.9

var radius: int = 24
var _t: float = 0.0
var _box := StyleBoxFlat.new()


## Pasang cincin pada `target` (sekali saja; pemanggilan berikutnya mengembalikan
## cincin yang sama).
static func attach(target: Control, corner_radius: int = 24) -> TutorialPulse:
	var old: Node = target.get_node_or_null(NODE_NAME)
	if old is TutorialPulse:
		return old as TutorialPulse
	var p := TutorialPulse.new()
	p.name = NODE_NAME
	p.radius = corner_radius
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.set_anchors_preset(Control.PRESET_FULL_RECT)
	target.add_child(p)
	return p


## Lepas cincin dari `target` bila ada.
static func detach(target: Control) -> void:
	if target == null or not is_instance_valid(target):
		return
	var old: Node = target.get_node_or_null(NODE_NAME)
	if old != null:
		target.remove_child(old)
		old.queue_free()


func _ready() -> void:
	_box.draw_center = false
	_box.set_border_width_all(RING_PX)
	_box.anti_aliasing = true


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	var k: float = 0.5 if SettingsManager.reduced_motion() else 0.5 - 0.5 * cos(TAU * _t / PERIOD)
	var grow: float = 3.0 + GROW_PX * k
	_box.border_color = Color(Palette.HONEY, 1.0 - 0.55 * k)
	_box.set_corner_radius_all(radius + int(grow))
	draw_style_box(_box, Rect2(Vector2(-grow, -grow), size + Vector2(grow, grow) * 2.0))
