extends Node
## Runner test headless (GDD 107). Jalankan sebagai scene supaya autoload aktif:
##   godot --headless --path . res://tests/test_runner.tscn
##   godot --headless --path . res://tests/test_runner.tscn -- --only=TEST_QUEUE_001
##   godot --headless --path . res://tests/test_runner.tscn -- --id=TEST_LONGRUN_100   (ID persis)
##   godot --headless --path . res://tests/test_runner.tscn -- --skip-long
## Keluar dengan kode 1 bila ada test REQUIRED yang gagal. Laporan JSON ditulis
## ke user://test_report.json.

const SUITE_DIR: String = "res://tests/suites"

var _only: String = ""
## --id=X: hanya test dengan ID persis X (--only mencocokkan prefiks, sehingga
## TEST_LONGRUN_100 juga akan memilih TEST_LONGRUN_1000).
var _exact: String = ""
var _skip_long: bool = false
var _errors := _ErrorCounter.new()


## Menghitung error engine/skrip selama test berjalan: SCRIPT ERROR tidak
## melempar exception di GDScript, jadi tanpa ini test yang crash di tengah
## jalan tetap tampak lulus. Test yang sengaja memicu error memberi
## "expect_errors": true.
class _ErrorCounter extends Logger:
	var count: int = 0
	var first: Array[String] = []
	var _mutex := Mutex.new()

	func _log_error(function: String, file: String, line: int, code: String, rationale: String, _editor_notify: bool,
			error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
		if error_type == ERROR_TYPE_WARNING:
			return
		_mutex.lock()
		count += 1
		if first.size() < 5:
			first.append("%s (%s:%d %s)" % [rationale if rationale != "" else code, file, line, function])
		_mutex.unlock()

	func reset() -> void:
		_mutex.lock()
		count = 0
		first.clear()
		_mutex.unlock()


func _ready() -> void:
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--only="):
			_only = a.substr(7)
		elif a.begins_with("--id="):
			_exact = a.substr(5)
		elif a == "--skip-long":
			_skip_long = true
	GameLogger.quiet = true
	OS.add_logger(_errors)
	# Menunggu satu frame agar semua autoload selesai _ready.
	await get_tree().process_frame
	var code: int = await _run_all()
	ProceduralCaches.clear_all()
	get_tree().quit(code)


func _run_all() -> int:
	var results: Array = []
	var failed: int = 0
	var passed: int = 0
	var skipped: int = 0
	var suites: Array[String] = _list_suites()
	for path: String in suites:
		var script: GDScript = load(path)
		var suite: TestSuite = script.new()
		suite.runner = self
		for t: Variant in suite.tests():
			var td: Dictionary = t
			var id: String = str(td["id"])
			if _only != "" and not id.begins_with(_only):
				continue
			if _exact != "" and id != _exact:
				continue
			if _skip_long and bool(td.get("long", false)):
				skipped += 1
				continue
			suite.failures.clear()
			suite.checks = 0
			var started: int = Time.get_ticks_msec()
			PauseManager.clear_all()
			_errors.reset()
			var fn: Callable = td["fn"]
			await fn.call()
			if _errors.count > 0 and not bool(td.get("expect_errors", false)):
				suite.failures.append("%d engine/script error(s) during the test; first: %s" % [_errors.count, "; ".join(_errors.first)])
			var ms: int = Time.get_ticks_msec() - started
			var ok: bool = suite.failures.is_empty()
			if ok:
				passed += 1
				print("PASS %s  %s (%d checks, %d ms)" % [id, td.get("name", ""), suite.checks, ms])
			else:
				failed += 1
				print("FAIL %s  %s" % [id, td.get("name", "")])
				for f: String in suite.failures.slice(0, 12):
					print("     - ", f)
			results.append({"id": id, "name": td.get("name", ""), "passed": ok, "checks": suite.checks,
				"ms": ms, "failures": suite.failures.slice(0, 20)})
			for c: Node in get_children():
				c.queue_free()
			await get_tree().process_frame
	print("")
	print("TESTS: %d passed, %d failed, %d skipped" % [passed, failed, skipped])
	var f: FileAccess = FileAccess.open("user://test_report.json", FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify({"passed": passed, "failed": failed, "skipped": skipped, "results": results}, "\t"))
		f.close()
	return 1 if failed > 0 else 0


func _list_suites() -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(SUITE_DIR)
	if dir == null:
		return out
	dir.list_dir_begin()
	var n: String = dir.get_next()
	while n != "":
		if n.ends_with(".gd"):
			out.append(SUITE_DIR.path_join(n))
		n = dir.get_next()
	out.sort()
	return out
