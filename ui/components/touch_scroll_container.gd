class_name TouchScrollContainer
extends ScrollContainer
## ScrollContainer ramah sentuh Android: geser vertikal mulus di atas kartu
## maupun tombol tanpa memicu klik tombol, serta mematuhi overlay di atasnya.

const _INERTIA_DECAY: float = 7.5
const _MAX_FLING_VEL: float = 3200.0
const _MIN_FLING_VEL: float = 8.0
const _RELEASE_IDLE_USEC: int = 90000

var _touch_id: int = -1
var _start_pos: Vector2 = Vector2.ZERO
var _last_y: float = 0.0
var _scroll_f: float = 0.0
var _last_applied_scroll: int = 0
var _scrolling: bool = false
var _vel_y: float = 0.0
var _last_drag_usec: int = 0
var _drag_ctrl: Control = null
var _consume_mouse_release: bool = false
var _sending_cancel: bool = false


func _ready() -> void:
	set_process(true)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP or mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_vel_y = 0.0


func _input(event: InputEvent) -> void:
	if _sending_cancel:
		return
	if not is_visible_in_tree():
		_reset_gesture()
		return

	if _scrolling and event is InputEventMouseMotion:
		var mm: InputEventMouseMotion = event as InputEventMouseMotion
		if (mm.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			get_viewport().set_input_as_handled()
		return

	if _consume_mouse_release and event is InputEventMouseButton:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed:
			_consume_mouse_release = false
			if mb.device == InputEvent.DEVICE_ID_EMULATION:
				get_viewport().set_input_as_handled()
			return
		_consume_mouse_release = false

	if event is InputEventScreenTouch:
		_handle_screen_touch(event as InputEventScreenTouch)
	elif event is InputEventScreenDrag:
		_handle_screen_drag(event as InputEventScreenDrag)


func _process(delta: float) -> void:
	if _touch_id >= 0 or absf(_vel_y) <= _MIN_FLING_VEL:
		return
	if not is_visible_in_tree() or not _can_scroll():
		_vel_y = 0.0
		return
	if scroll_vertical != _last_applied_scroll:
		_vel_y = 0.0
		return
	_vel_y *= exp(-_INERTIA_DECAY * delta)
	var max_s: float = _max_scroll()
	var next_s: float = _scroll_f + _vel_y * delta
	if next_s <= 0.0:
		_scroll_f = 0.0
		_vel_y = 0.0
	elif next_s >= max_s:
		_scroll_f = max_s
		_vel_y = 0.0
	else:
		_scroll_f = next_s
	_apply_scroll()


func _handle_screen_touch(st: InputEventScreenTouch) -> void:
	if st.pressed:
		_consume_mouse_release = false
		if st.index != 0 or _touch_id >= 0:
			return
		if not _can_scroll():
			return
		if not _point_in_control(self, st.position):
			return
		if _is_blocked_above(st.position):
			return
		_vel_y = 0.0
		var stop_ctrl: Control = _stop_child_at(self, st.position)
		var vsb: VScrollBar = get_v_scroll_bar()
		if stop_ctrl != null and vsb != null and (stop_ctrl == vsb or vsb.is_ancestor_of(stop_ctrl)):
			return
		# Di layar sentuh nyata, anak PASS/IGNORE sudah diteruskan ke
		# ScrollContainer::_gui_input; tangani manual hanya untuk anak STOP
		# (mis. tombol) atau lingkungan non-touchscreen (uji headless).
		if stop_ctrl == null and DisplayServer.is_touchscreen_available():
			return
		_touch_id = st.index
		_start_pos = st.position
		_last_y = st.position.y
		_scroll_f = float(scroll_vertical)
		_last_applied_scroll = scroll_vertical
		_scrolling = false
		_drag_ctrl = stop_ctrl
		_last_drag_usec = Time.get_ticks_usec()
		return

	if st.index != _touch_id:
		return
	_touch_id = -1
	_drag_ctrl = null
	if not _scrolling:
		return
	_scrolling = false
	if Time.get_ticks_usec() - _last_drag_usec > _RELEASE_IDLE_USEC:
		_vel_y = 0.0
	_consume_mouse_release = true
	get_viewport().set_input_as_handled()


func _handle_screen_drag(sd: InputEventScreenDrag) -> void:
	if sd.index != _touch_id:
		return
	if not _scrolling:
		var delta_total: Vector2 = sd.position - _start_pos
		var thresh: float = DataRegistry.balf("input.tap_max_move_px")
		if absf(delta_total.x) <= thresh and absf(delta_total.y) <= thresh:
			return
		if _drag_ctrl is Range and absf(delta_total.x) >= absf(delta_total.y):
			_reset_gesture()
			return
		if absf(delta_total.y) <= thresh or absf(delta_total.y) < absf(delta_total.x):
			_reset_gesture()
			return
		_scrolling = true
		_scroll_f = float(scroll_vertical)
		_cancel_drag_target(_drag_ctrl, _touch_id)
		_vel_y = 0.0
		_last_drag_usec = Time.get_ticks_usec()
		_last_y = _start_pos.y

	var dy: float = sd.position.y - _last_y
	_last_y = sd.position.y
	var now_usec: int = Time.get_ticks_usec()
	var dt: float = maxf(float(now_usec - _last_drag_usec) * 0.000001, 0.001)
	_last_drag_usec = now_usec

	_scroll_f = clampf(_scroll_f - dy, 0.0, _max_scroll())
	_apply_scroll()

	var inst_vel: float = clampf(-dy / dt, -_MAX_FLING_VEL, _MAX_FLING_VEL)
	_vel_y = lerpf(_vel_y, inst_vel, 0.45)
	get_viewport().set_input_as_handled()


func _apply_scroll() -> void:
	var target: int = int(roundf(_scroll_f))
	scroll_vertical = target
	_last_applied_scroll = scroll_vertical


func _reset_gesture() -> void:
	_touch_id = -1
	_scrolling = false
	_drag_ctrl = null


func _can_scroll() -> bool:
	var bar: VScrollBar = get_v_scroll_bar()
	return bar != null and bar.max_value > bar.page + 1.0


func _max_scroll() -> float:
	var bar: VScrollBar = get_v_scroll_bar()
	if bar == null:
		return 0.0
	return maxf(0.0, bar.max_value - bar.page)


func _cancel_drag_target(ctrl: Control, touch_idx: int) -> void:
	if is_instance_valid(ctrl) and ctrl is BaseButton:
		var bb: BaseButton = ctrl as BaseButton
		if not bb.disabled:
			bb.disabled = true
			bb.disabled = false
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	_sending_cancel = true
	var offscreen := Vector2(-100000.0, -100000.0)
	var st := InputEventScreenTouch.new()
	st.index = touch_idx
	st.pressed = false
	st.canceled = true
	st.position = offscreen
	vp.push_input(st, true)
	if DisplayServer.is_touchscreen_available():
		var mb := InputEventMouseButton.new()
		mb.button_index = MOUSE_BUTTON_LEFT
		mb.pressed = false
		mb.canceled = true
		mb.position = offscreen
		mb.global_position = offscreen
		vp.push_input(mb, true)
	_sending_cancel = false


static func _point_in_control(c: Control, canvas_pos: Vector2) -> bool:
	var xform: Transform2D = c.get_global_transform_with_canvas()
	if absf(xform.determinant()) < 0.00001:
		return false
	var local_pos: Vector2 = xform.affine_inverse() * canvas_pos
	if not Rect2(Vector2.ZERO, c.size).has_point(local_pos):
		return false
	if c.has_method("_has_point"):
		return bool(c.call("_has_point", local_pos))
	return true


static func _stop_child_at(root: Control, canvas_pos: Vector2) -> Control:
	for i in range(root.get_child_count() - 1, -1, -1):
		var ch: Node = root.get_child(i)
		if not (ch is Control):
			continue
		var c: Control = ch as Control
		if not c.visible:
			continue
		var hit: bool = _point_in_control(c, canvas_pos)
		if c.clip_contents and not hit:
			continue
		var nested: Control = _stop_child_at(c, canvas_pos)
		if nested != null:
			return nested
		if hit and c.mouse_filter == Control.MOUSE_FILTER_STOP:
			return c
	return null


func _is_blocked_above(canvas_pos: Vector2) -> bool:
	var vp: Viewport = get_viewport()
	if vp == null:
		return false
	var my_cl: CanvasLayer = _enclosing_canvas_layer(self, vp)
	var stop_parent: Node = my_cl if my_cl != null else vp
	var cur: Node = self
	while cur != null and cur != stop_parent:
		var p: Node = cur.get_parent()
		if p == null:
			break
		var start_idx: int = cur.get_index() + 1
		for i in range(start_idx, p.get_child_count()):
			var sib: Node = p.get_child(i)
			if sib is CanvasLayer or sib is Viewport:
				continue
			if _subtree_stops_point(sib, canvas_pos):
				return true
		cur = p
	var my_layer: int = my_cl.layer if my_cl != null else 0
	var state := {"seen_my_cl": my_cl == null}
	return _higher_layer_blocks(vp, my_cl, my_layer, canvas_pos, state)


static func _enclosing_canvas_layer(n: Node, vp: Viewport) -> CanvasLayer:
	var cur: Node = n.get_parent()
	while cur != null and cur != vp:
		if cur is CanvasLayer:
			return cur as CanvasLayer
		cur = cur.get_parent()
	return null


static func _higher_layer_blocks(node: Node, my_cl: CanvasLayer, my_layer: int, pos: Vector2, state: Dictionary) -> bool:
	for i in range(node.get_child_count()):
		var ch: Node = node.get_child(i)
		if ch is Viewport:
			continue
		if ch is CanvasLayer:
			var cl: CanvasLayer = ch as CanvasLayer
			if cl == my_cl:
				state["seen_my_cl"] = true
			elif cl.visible and (cl.layer > my_layer or (cl.layer == my_layer and bool(state["seen_my_cl"]))):
				if _subtree_stops_point(cl, pos):
					return true
		if _higher_layer_blocks(ch, my_cl, my_layer, pos, state):
			return true
	return false


static func _subtree_stops_point(node: Node, canvas_pos: Vector2) -> bool:
	if node is Viewport:
		return false
	if node is Control:
		var c: Control = node as Control
		if not c.visible:
			return false
		var hit: bool = _point_in_control(c, canvas_pos)
		if c.clip_contents and not hit:
			return false
		for i in range(c.get_child_count() - 1, -1, -1):
			if _subtree_stops_point(c.get_child(i), canvas_pos):
				return true
		return hit and c.mouse_filter == Control.MOUSE_FILTER_STOP
	for i in range(node.get_child_count() - 1, -1, -1):
		var ch: Node = node.get_child(i)
		if ch is CanvasLayer:
			continue
		if _subtree_stops_point(ch, canvas_pos):
			return true
	return false
