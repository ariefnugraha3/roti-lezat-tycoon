extends Node
## GameLogger — konvensi log berkategori (GDD 117).
##
## Nama autoload di GDD 35.2 adalah "Logger", tetapi Godot 4.7 sudah memiliki
## kelas bawaan `Logger`; singleton dengan nama yang sama tidak dapat didaftarkan.
## Karena itu autoload ini bernama GameLogger (catatan implementasi, bukan
## perubahan perilaku).
##
## Debug build: log level info ke atas. Release build: hanya warning/error dan
## peristiwa lifecycle/save penting (`important()`).

const CATEGORIES: Array[String] = [
	"BOOT", "DATA", "SAVE", "TIME", "WORLD", "NAV", "PRODUCTION", "INVENTORY",
	"ECONOMY", "CUSTOMER", "QUEUE", "CASHIER", "ROTIFOOD", "SUPPLY", "STAFF",
	"WEATHER", "UI", "AUDIO", "TEST",
]
const RING_SIZE: int = 400

## Tes dapat membisukan log info agar keluaran tetap ringkas.
var quiet: bool = false
var _ring: Array[String] = []
var _debug: bool = true
var _once: Dictionary = {}


func _ready() -> void:
	_debug = OS.is_debug_build()


func info(category: String, message: String) -> void:
	if not _debug or quiet:
		_remember(category, "INFO", message)
		return
	_emit(category, "INFO", message)


func important(category: String, message: String) -> void:
	_emit(category, "INFO", message)


func warn(category: String, message: String) -> void:
	_emit(category, "WARN", message)
	push_warning("[%s] %s" % [category, message])


func error(category: String, message: String) -> void:
	_emit(category, "ERROR", message)
	push_error("[%s] %s" % [category, message])


## Log satu kali per kunci (mis. kegagalan audio, GDD 132).
func warn_once(key: String, category: String, message: String) -> void:
	if _once.has(key):
		return
	_once[key] = true
	warn(category, message)


func recent() -> Array[String]:
	return _ring


func _emit(category: String, level: String, message: String) -> void:
	var cat: String = category if CATEGORIES.has(category) else "BOOT"
	var line: String = "[%s] %s %s" % [cat, level, message]
	if not quiet or level != "INFO":
		print(line)
	_push(line)


func _remember(category: String, level: String, message: String) -> void:
	_push("[%s] %s %s" % [category, level, message])


func _push(line: String) -> void:
	_ring.append(line)
	if _ring.size() > RING_SIZE:
		_ring.pop_front()
