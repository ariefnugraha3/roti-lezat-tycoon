extends SceneTree
## Validator headless: memuat setiap script GDScript di proyek dan melaporkan yang gagal parse.
## Jalankan: godot --headless --path . --script res://tools/validate.gd

const SCAN_DIRS: Array[String] = ["res://scripts", "res://tools"]

var _ok: int = 0
var _fail: int = 0
var _failed_paths: Array[String] = []


func _initialize() -> void:
	print("=== VALIDATE: memuat semua script ===")
	for dir_path in SCAN_DIRS:
		_scan(dir_path)

	print("")
	print("=== HASIL ===")
	print("OK   : %d" % _ok)
	print("FAIL : %d" % _fail)
	for p in _failed_paths:
		print("  gagal -> %s" % p)

	if _fail > 0:
		quit(1)
	else:
		_check_forbidden_assets()
		quit(0)


func _scan(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_warning("Tidak bisa membuka direktori: %s" % dir_path)
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_scan(full)
		elif name.ends_with(".gd"):
			_load_one(full)
		name = dir.get_next()
	dir.list_dir_end()


func _load_one(path: String) -> void:
	# validate.gd sendiri sedang berjalan; melewatinya menghindari rekursi tak perlu.
	if path == "res://tools/validate.gd":
		return
	var res: Resource = ResourceLoader.load(path, "Script", ResourceLoader.CACHE_MODE_IGNORE)
	if res == null:
		_fail += 1
		_failed_paths.append(path)
		print("FAIL %s" % path)
		return
	var scr := res as GDScript
	if scr == null:
		_fail += 1
		_failed_paths.append(path)
		print("FAIL %s (bukan GDScript)" % path)
		return
	# ResourceLoader tetap mengembalikan objek GDScript meski parse gagal, jadi
	# kompilasi ulang secara eksplisit: hanya reload() yang melaporkan parse error.
	var err := scr.reload(true)
	if err != OK:
		_fail += 1
		_failed_paths.append(path)
		print("FAIL %s (parse error %d)" % [path, err])
		return
	_ok += 1
	print("OK   %s" % path)


## Memastikan tidak ada aset eksternal terlarang yang menyelinap masuk (GDD 4 & 12.2).
func _check_forbidden_assets() -> void:
	const FORBIDDEN: Array[String] = [
		".png", ".jpg", ".jpeg", ".gltf", ".glb", ".fbx", ".obj",
		".ogg", ".wav", ".mp3", ".ttf", ".otf", ".webp", ".bmp",
	]
	var found: Array[String] = []
	_walk_assets("res://", FORBIDDEN, found)
	print("")
	print("=== CEK ASET EKSTERNAL ===")
	if found.is_empty():
		print("Bersih: 100% prosedural, tidak ada aset eksternal.")
	else:
		for f in found:
			print("TERLARANG -> %s" % f)
		quit(1)


func _walk_assets(dir_path: String, forbidden: Array[String], out: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full := dir_path.path_join(name)
		if dir.current_is_dir():
			_walk_assets(full, forbidden, out)
		else:
			var lower := name.to_lower()
			for ext in forbidden:
				if lower.ends_with(ext):
					out.append(full)
					break
		name = dir.get_next()
	dir.list_dir_end()
