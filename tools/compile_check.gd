extends Node
## Pemeriksa kompilasi: memuat ulang setiap skrip GDScript di proyek dan
## melaporkan yang gagal. Dijalankan sebagai SCENE agar autoload terdaftar:
##   godot --headless --path . res://tools/compile_check.tscn

const SCAN_DIRS: Array[String] = ["res://autoload", "res://core", "res://data", "res://gameplay",
	"res://procedural", "res://ui", "res://audio", "res://tests", "res://tools", "res://scenes"]

var _fail: Array[String] = []
var _ok: int = 0


func _ready() -> void:
	for d: String in SCAN_DIRS:
		_scan(d)
	print("COMPILE OK: %d  FAIL: %d" % [_ok, _fail.size()])
	for f: String in _fail:
		print("  FAIL ", f)
	get_tree().quit(1 if not _fail.is_empty() else 0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var n: String = dir.get_next()
	while n != "":
		if not n.begins_with("."):
			var full: String = dir_path.path_join(n)
			if dir.current_is_dir():
				_scan(full)
			elif n.ends_with(".gd") and full != get_script().resource_path:
				var s: Resource = ResourceLoader.load(full, "Script", ResourceLoader.CACHE_MODE_IGNORE)
				var g := s as GDScript
				if g == null or g.reload(true) != OK:
					_fail.append(full)
				else:
					_ok += 1
		n = dir.get_next()
	dir.list_dir_end()
