class_name ModalHost
extends CanvasLayer
## Tumpukan modal (GDD 28.2): maksimal satu modal utama yang memblokir, dialog
## konfirmasi boleh di atasnya, Back/Escape menutup lapisan teratas, dan input
## dunia mati selama modal pemblokir terbuka. Setiap modal pemblokir mendorong
## alasan pause-nya sendiri (GDD 15.2, 71).

signal stack_changed()

var game: GameRoot = null
var _factories: Dictionary = {}
var _stack: Array[UIScreen] = []


func _init() -> void:
	layer = 20
	name = "ModalHost"


func register(id: StringName, factory: Callable) -> void:
	_factories[id] = factory


func has_blocking() -> bool:
	for s: UIScreen in _stack:
		if s.blocking:
			return true
	return false


func top() -> UIScreen:
	return _stack[_stack.size() - 1] if not _stack.is_empty() else null


func is_open(id: StringName) -> bool:
	for s: UIScreen in _stack:
		if s.screen_id == id:
			return true
	return false


## Buka layar. Bila sudah ada modal utama dan yang baru juga modal utama,
## yang lama ditutup lebih dulu (maks satu modal utama).
func open(id: StringName, params: Dictionary = {}) -> UIScreen:
	if not _factories.has(id):
		GameLogger.error("UI", "unknown screen %s" % id)
		return null
	var s: UIScreen = (_factories[id] as Callable).call()
	s.screen_id = id
	s.params = params
	s.host = self
	s.game = game
	s.sim = game.sim if game != null else null
	if id != &"confirm" and s.blocking:
		for old: UIScreen in _stack.duplicate():
			if old.blocking and old.screen_id != &"confirm":
				close_screen(old)
	_stack.append(s)
	add_child(s)
	if s.blocking:
		PauseManager.push(_reason(s))
	EventBus.sfx.emit(&"ui_pause" if s.blocking else &"ui_tap_soft", &"")
	stack_changed.emit()
	return s


func close_screen(s: UIScreen) -> void:
	if not _stack.has(s):
		return
	_stack.erase(s)
	if s.blocking:
		PauseManager.pop(_reason(s))
	s.on_closed()
	s.closed.emit(s)
	s.queue_free()
	stack_changed.emit()


func close_all() -> void:
	for s: UIScreen in _stack.duplicate():
		close_screen(s)


func _reason(s: UIScreen) -> StringName:
	return StringName("modal_%s_%d" % [s.screen_id, s.get_instance_id()])


## Back / Escape / tombol Back Android (GDD 12.1, 28.2).
func back() -> bool:
	var s: UIScreen = top()
	if s == null:
		return false
	return s.on_back()


## Dialog konfirmasi di atas modal apa pun (GDD 28.2, 75.3-75.4).
func confirm(text: String, on_yes: Callable, destructive: bool = false) -> void:
	var d: UIScreen = open(&"confirm", {"text": text, "on_yes": on_yes, "destructive": destructive})
	if d == null:
		on_yes.call()
