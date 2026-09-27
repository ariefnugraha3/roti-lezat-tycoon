extends Node
## PauseManager — satu-satunya pemilik alasan pause (GDD 15.2, 71, 90, 98, 113).
##
## Simulasi berjalan hanya bila tidak ada alasan pause aktif. Setiap modal
## keputusan mendorong alasannya sendiri, dan jembatan lifecycle mendorong
## LIFECYCLE_PAUSE saat aplikasi/tab kehilangan fokus. Tidak ada kemajuan
## offline: waktu nyata yang terlewat tidak pernah dikejar.

signal pause_changed(paused: bool)
signal lifecycle_paused()

const LIFECYCLE: StringName = &"lifecycle"
const USER: StringName = &"user"

## Hanya aktif saat gameplay berjalan; di Main Menu fokus hilang tidak berarti apa-apa.
var lifecycle_enabled: bool = false

var _reasons: Dictionary = {}


func push(reason: StringName) -> void:
	var was: bool = is_paused()
	_reasons[reason] = int(_reasons.get(reason, 0)) + 1
	if not was:
		pause_changed.emit(true)


func pop(reason: StringName) -> void:
	if not _reasons.has(reason):
		return
	var n: int = int(_reasons[reason]) - 1
	if n <= 0:
		_reasons.erase(reason)
	else:
		_reasons[reason] = n
	if not is_paused():
		pause_changed.emit(false)


## Menghapus satu alasan sepenuhnya, berapa pun hitungannya.
func clear(reason: StringName) -> void:
	if not _reasons.has(reason):
		return
	_reasons.erase(reason)
	if not is_paused():
		pause_changed.emit(false)


func clear_all() -> void:
	var was: bool = is_paused()
	_reasons.clear()
	if was:
		pause_changed.emit(false)


func is_paused() -> bool:
	return not _reasons.is_empty()


func has(reason: StringName) -> bool:
	return _reasons.has(reason)


func reasons() -> Array:
	return _reasons.keys()


func toggle_user_pause() -> void:
	if has(USER):
		clear(USER)
	else:
		push(USER)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			on_focus_lost()


## Dipanggil lifecycle bridge (dan test TEST_LIFECYCLE_001).
func on_focus_lost() -> void:
	if not lifecycle_enabled or has(LIFECYCLE):
		return
	push(LIFECYCLE)
	lifecycle_paused.emit()


## Pemain menekan Resume pada overlay "Game Paused".
func resume_from_lifecycle() -> void:
	clear(LIFECYCLE)
