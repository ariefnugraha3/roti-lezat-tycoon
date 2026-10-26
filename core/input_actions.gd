class_name InputActions
extends RefCounted
## InputMap kanonik (v3.1 100; tanpa tombol kecepatan, GDD idle 0.1). Didaftarkan saat boot bila belum ada, sehingga
## semua platform memakai lapisan perintah yang sama. Keyboard hanya pelengkap
## (GDD 12.4, 29.4): setiap aksi juga dapat dicapai lewat tap.

const ACTIONS: Array[String] = [
	"interact_primary", "cancel_back", "pause_toggle", "camera_pan", "camera_zoom_in", "camera_zoom_out",
]


static func register() -> void:
	_add("interact_primary", [_mouse(MOUSE_BUTTON_LEFT)])
	_add("cancel_back", [_key(KEY_ESCAPE), _mouse(MOUSE_BUTTON_RIGHT)])
	_add("pause_toggle", [_key(KEY_P), _key(KEY_SPACE)])
	_add("camera_pan", [_mouse(MOUSE_BUTTON_MIDDLE)])
	_add("camera_zoom_in", [_mouse(MOUSE_BUTTON_WHEEL_UP), _key(KEY_EQUAL), _key(KEY_KP_ADD)])
	_add("camera_zoom_out", [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _key(KEY_MINUS), _key(KEY_KP_SUBTRACT)])


static func _add(action: String, events: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for e: Variant in events:
		if not InputMap.action_has_event(action, e):
			InputMap.action_add_event(action, e)


static func _key(code: Key) -> InputEventKey:
	var e := InputEventKey.new()
	e.physical_keycode = code
	return e


static func _mouse(button: MouseButton) -> InputEventMouseButton:
	var e := InputEventMouseButton.new()
	e.button_index = button
	return e


static func all_registered() -> bool:
	for a: String in ACTIONS:
		if not InputMap.has_action(a):
			return false
	return true
