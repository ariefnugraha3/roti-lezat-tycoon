class_name CommandLayer
extends Node
## Lapisan perintah input (GDD 29, 100): mengubah mouse/sentuh/keyboard menjadi
## perintah semantik. Skrip gameplay tidak pernah membaca input mentah.
##
## Tap = dilepas dalam 12 px logis (× skala UI) dan 0,35 detik nyata; lebih dari
## itu adalah drag (pan kamera). Klik kanan = back, roda = zoom.

signal world_tapped(screen_pos: Vector2)
signal back_requested()
signal pause_requested()
signal speed_requested(speed: int)
signal floor_alert_requested()

var world: WorldView = null
var enabled: bool = true
## Handler alternatif (mis. Decoration Mode) menerima tap dunia bila diset.
var tap_override: Callable = Callable()
var drag_override: Callable = Callable()

var _press_pos: Vector2 = Vector2.ZERO
var _press_time: int = 0
var _pressed: bool = false
var _dragging: bool = false
var _last_pos: Vector2 = Vector2.ZERO
var _touches: Dictionary = {}
var _pinch_dist: float = 0.0


func _threshold() -> float:
	return DataRegistry.balf("input.tap_max_move_px") * float(SettingsManager.get_int("ui_scale")) / 100.0


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("cancel_back") and not (event is InputEventMouseButton):
		back_requested.emit()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_RIGHT and event.is_pressed():
		back_requested.emit()
		return
	if event.is_action_pressed("pause_toggle"):
		pause_requested.emit()
		return
	for s in 3:
		if event.is_action_pressed("game_speed_%d" % (s + 1)):
			speed_requested.emit(s + 1)
			return
	if event.is_action_pressed("floor_alert_focus"):
		floor_alert_requested.emit()
		return
	if not enabled or world == null:
		return
	if event.is_action_pressed("camera_zoom_in"):
		world.camera_rig.zoom(-DataRegistry.balf("camera.zoom_step"))
		return
	if event.is_action_pressed("camera_zoom_out"):
		world.camera_rig.zoom(DataRegistry.balf("camera.zoom_step"))
		return
	if event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		world.camera_rig.zoom((1.0 - mg.factor) * 4.0)
		return
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_touches[st.index] = st.position
		else:
			_touches.erase(st.index)
		_pinch_dist = 0.0
		return
	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var ps: Array = _touches.values()
			var d: float = (ps[0] as Vector2).distance_to(ps[1] as Vector2)
			if _pinch_dist > 0.0:
				world.camera_rig.zoom((_pinch_dist - d) * 0.01)
			_pinch_dist = d
			_dragging = true
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index != MOUSE_BUTTON_LEFT and mb.button_index != MOUSE_BUTTON_MIDDLE:
			return
		if mb.pressed:
			_pressed = true
			_dragging = false
			_press_pos = mb.position
			_last_pos = mb.position
			_press_time = Time.get_ticks_msec()
		else:
			var was_drag: bool = _dragging
			_pressed = false
			_dragging = false
			var elapsed: float = float(Time.get_ticks_msec() - _press_time) / 1000.0
			if not was_drag and mb.button_index == MOUSE_BUTTON_LEFT and elapsed <= DataRegistry.balf("input.tap_max_duration_seconds") \
				and mb.position.distance_to(_press_pos) <= _threshold():
				if tap_override.is_valid():
					tap_override.call(mb.position)
				else:
					world_tapped.emit(mb.position)
		return
	if event is InputEventMouseMotion and _pressed:
		var mm: InputEventMouseMotion = event
		if not _dragging and mm.position.distance_to(_press_pos) > _threshold():
			_dragging = true
		if _dragging:
			if drag_override.is_valid():
				drag_override.call(mm.position)
			elif _touches.size() < 2:
				world.camera_rig.pan_by_screen(mm.position - _last_pos)
		_last_pos = mm.position
