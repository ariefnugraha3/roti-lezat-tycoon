extends Node
## Validator rilis headless (GDD 133). Jalankan sebagai scene agar autoload aktif:
##   godot --headless --path . res://tools/release_validator.tscn
##   godot --headless --path . res://tools/release_validator.tscn -- --quick
## --quick melewati langkah lambat (test wajib & ekspor); langkah itu dilaporkan
## NOT RUN dan hasil akhirnya tidak pernah dianggap lulus rilis.
## Keluar dengan kode 0 hanya bila setiap aturan REQUIRED lulus.

const FORBIDDEN_EXTENSIONS: Array[String] = [
	"png", "jpg", "jpeg", "webp", "bmp", "tga", "gltf", "glb", "fbx", "obj", "blend", "dae",
	"wav", "ogg", "mp3", "ttf", "otf", "woff", "woff2",
]
const HYGIENE_PATTERNS: Array[String] = ["TODO", "FIXME", "NotImplemented", "placeholder_only", "mock_production"]
const NETWORK_CLASSES: Array[String] = ["HTTPRequest", "HTTPClient", "WebSocketPeer", "StreamPeerTCP", "PacketPeerUDP", "ENetMultiplayerPeer", "WebRTCPeerConnection"]
const SOURCE_ROOTS: Array[String] = ["res://audio", "res://autoload", "res://core", "res://data", "res://gameplay", "res://procedural", "res://scenes", "res://ui"]
const PACKAGE_ID: String = "com.rotilezattycoon.game"

var _results: Array[Dictionary] = []
var _quick: bool = false
var _errors := _ErrorCounter.new()


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
	_quick = OS.get_cmdline_user_args().has("--quick")
	GameLogger.quiet = true
	OS.add_logger(_errors)
	await get_tree().process_frame
	_check_engine()
	_check_catalogs()
	_check_strings()
	_check_source_hygiene()
	_check_assets()
	_check_network()
	_check_export_presets()
	await _check_locations()
	await _check_boot()
	_check_profiles()
	_check_golden()
	_check_required_tests()
	_check_exports()
	ProceduralCaches.clear_all()
	await get_tree().process_frame
	get_tree().quit(_report())


func _add(id: String, ok: bool, detail: String = "", not_run: bool = false) -> void:
	_results.append({"id": id, "ok": ok, "detail": detail, "not_run": not_run})


func _report() -> int:
	var failed: int = 0
	var not_run: int = 0
	print("")
	print("RELEASE VALIDATION (GDD 133)")
	for r: Dictionary in _results:
		var tag: String = "PASS"
		if bool(r["not_run"]):
			tag = "NOT RUN"
			not_run += 1
		elif not bool(r["ok"]):
			tag = "FAIL"
			failed += 1
		print("%-8s %s%s" % [tag, r["id"], "" if str(r["detail"]) == "" else "  — " + str(r["detail"])])
	print("")
	print("%d checks: %d failed, %d not run" % [_results.size(), failed, not_run])
	if failed == 0 and not_run == 0:
		print("RELEASE GATE: OPEN")
		return 0
	print("RELEASE GATE: CLOSED")
	return 1


# ===========================================================================
# 133.1 SPESIFIKASI & DATA
# ===========================================================================

func _check_engine() -> void:
	var v: Dictionary = Engine.get_version_info()
	_add("engine is Godot 4.7-stable", int(v["major"]) == 4 and int(v["minor"]) == 7 and str(v["status"]) == "stable",
		"%s.%s.%s-%s" % [v["major"], v["minor"], v["patch"], v["status"]])
	var r: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method", ""))
	var rm: String = str(ProjectSettings.get_setting("rendering/renderer/rendering_method.mobile", ""))
	_add("Compatibility renderer (GDD 96, 128)", r == "gl_compatibility" and rm == "gl_compatibility", "%s / %s" % [r, rm])
	_add("Android landscape orientation", int(ProjectSettings.get_setting("display/window/handheld/orientation", -1)) == 0)
	_add("no addons folder (GDD 128.1)", not DirAccess.dir_exists_absolute("res://addons"))


func _check_catalogs() -> void:
	var ok: bool = DataRegistry.load_catalogs()
	_add("catalogs validate (IDs, references, yields, costs, times, tiers, patience, achievements)", ok,
		"; ".join(DataRegistry.errors.slice(0, 5)))
	var v: Dictionary = DataRegistry.catalog_versions
	_add("catalog versions present (GDD 134.1)", v.has("catalog_schema_version") and v.has("content_version"))


func _check_strings() -> void:
	var r: Dictionary = StringLint.run(false)
	_add("every UI string key exists", (r["missing"] as Dictionary).is_empty(), str((r["missing"] as Dictionary).keys().slice(0, 8)))
	_add("no empty strings", (r["empty"] as Array).is_empty(), str((r["empty"] as Array).slice(0, 8)))
	_add("player-facing strings are English", (r["bad"] as Dictionary).is_empty(), str(r["bad"]).left(300))


func _check_source_hygiene() -> void:
	var files: Array[String] = []
	for root: String in SOURCE_ROOTS:
		StringLint.collect_gd(root, files)
	var hits: Array[String] = []
	var pass_re := RegEx.create_from_string("^\\s*pass\\s*#")
	for f: String in files:
		var lines: PackedStringArray = FileAccess.get_file_as_string(f).split("\n")
		for i in lines.size():
			var line: String = lines[i]
			for p: String in HYGIENE_PATTERNS:
				if line.contains(p):
					hits.append("%s:%d %s" % [f, i + 1, p])
			if pass_re.search(line) != null:
				hits.append("%s:%d pass #" % [f, i + 1])
	_add("source hygiene: no TODO/FIXME/placeholder (GDD 133.2)", hits.is_empty(), ", ".join(hits.slice(0, 6)))


func _check_assets() -> void:
	var found: Array[String] = []
	_scan_assets("res://", found)
	_add("no external art/audio/font assets (GDD 4, 111)", found.is_empty(), ", ".join(found.slice(0, 8)))
	var icon: String = FileAccess.get_file_as_string("res://icon.svg")
	_add("app icon is the generated icon (tools/generate_icon.gd)", icon == load("res://tools/generate_icon.gd").build())


func _scan_assets(path: String, out: Array[String]) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f: String in d.get_files():
		if FORBIDDEN_EXTENSIONS.has(f.get_extension().to_lower()):
			out.append(path.path_join(f))
	for sub: String in d.get_directories():
		if sub.begins_with(".") or sub == "build":
			continue
		_scan_assets(path.path_join(sub), out)


func _check_network() -> void:
	var files: Array[String] = []
	for root: String in SOURCE_ROOTS:
		StringLint.collect_gd(root, files)
	var hits: Array[String] = []
	for f: String in files:
		var text: String = FileAccess.get_file_as_string(f)
		for c: String in NETWORK_CLASSES:
			if text.contains(c):
				hits.append("%s uses %s" % [f.get_file(), c])
	_add("fully offline: no network classes (GDD 12.7, 112)", hits.is_empty(), ", ".join(hits))


func _check_export_presets() -> void:
	var cfg := ConfigFile.new()
	if cfg.load("res://export_presets.cfg") != OK:
		_add("export_presets.cfg present", false)
		return
	var names: Dictionary = {}
	var secrets: Array[String] = []
	var android_ok: bool = true
	for sec: String in cfg.get_sections():
		if sec.ends_with(".options"):
			for k: String in cfg.get_section_keys(sec):
				if k.begins_with("keystore/") and str(cfg.get_value(sec, k, "")) != "":
					secrets.append("%s %s" % [sec, k])
			continue
		var n: String = str(cfg.get_value(sec, "name", ""))
		var platform: String = str(cfg.get_value(sec, "platform", ""))
		names[n] = platform
		var opt: String = sec + ".options"
		if platform == "Android":
			android_ok = android_ok and str(cfg.get_value(opt, "package/unique_name", "")) == PACKAGE_ID \
				and not bool(cfg.get_value(opt, "permissions/internet", true))
		if platform == "Web":
			_add("Web preset single-threaded for itch.io (GDD 128.3)", not bool(cfg.get_value(opt, "variant/thread_support", true)))
	_add("Web, Android APK and Android AAB presets exist (GDD 108)",
		names.get("Web") == "Web" and names.get("Android Debug APK") == "Android" and names.get("Android Release AAB") == "Android",
		str(names.keys()))
	_add("Android presets use %s without INTERNET permission" % PACKAGE_ID, android_ok)
	_add("no signing secrets in export_presets.cfg (GDD 128.4)", secrets.is_empty(), ", ".join(secrets))
	var aab: bool = false
	for sec2: String in cfg.get_sections():
		if str(cfg.get_value(sec2, "name", "")) == "Android Release AAB":
			aab = int(cfg.get_value(sec2 + ".options", "gradle_build/export_format", 0)) == 1
	_add("release preset exports .aab", aab)


func _check_locations() -> void:
	var bad: Array[String] = []
	var s: SimulationRoot = _new_sim(1)
	for tier in range(1, 6):
		if tier > 1:
			s.time.set_phase(TimeManager.AFTER_HOURS)
			s.debug_add_kr(s.next_location().upgrade_cost_kr)
			var r: String = s.upgrade_location()
			if r != "":
				bad.append("T%d upgrade: %s" % [tier, r])
				break
		if not s.world.layout_valid():
			bad.append("T%d protected paths" % tier)
		for e: EquipmentInstance in s.equipment.placed_list():
			if s.world.access_of(e.iid).is_empty():
				bad.append("T%d %s without access tile" % [tier, e.def_id])
	_free(s)
	await get_tree().process_frame
	_add("every location keeps protected-path connectivity (GDD 56.1.2)", bad.is_empty(), ", ".join(bad))


func _new_sim(seed_value: int) -> SimulationRoot:
	var s := SimulationRoot.new()
	add_child(s)
	s.start_new_game(&"profile_validator", "Validator", "male", seed_value)
	return s


func _free(s: SimulationRoot) -> void:
	remove_child(s)
	s.free()


# ===========================================================================
# 133.3 BUILD
# ===========================================================================

func _check_boot() -> void:
	SaveManager.dir = "user://validator_saves"
	_errors.reset()
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	add_child(game)
	await get_tree().process_frame
	game.skip_splash_for_tests()
	game.show_main_menu()
	await get_tree().process_frame
	_add("headless boot reaches the main menu", game.modals.is_open(&"main_menu"))
	# Irisan vertikal Tier 1: New Game, satu hari penuh, Daily Summary.
	await game.start_new_game(&"profile_1", "female", "Validator Bakery")
	var bot := SimBot.new(game.sim)
	var frames: int = 0
	while game.sim.is_running() and frames < 200000:
		bot.think()
		game.sim.step(game.sim.tick_seconds)
		frames += 1
		if frames % 600 == 0:
			await get_tree().process_frame
	await get_tree().process_frame
	_add("Tier 1 vertical slice reaches the Daily Summary", game.modals.is_open(&"daily_summary"))
	_add("no console error during the Tier 1 vertical slice", _errors.count == 0, "; ".join(_errors.first))
	game.return_to_menu()
	await get_tree().process_frame
	game.queue_free()
	await get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"


func _check_profiles() -> void:
	SaveManager.dir = "user://validator_saves"
	var ok: bool = true
	for i in 3:
		var s: SimulationRoot = _new_sim(10 + i)
		s.bakery_name = "Profile %d" % (i + 1)
		ok = SaveManager.write_profile(SaveManager.PROFILE_IDS[i], s.capture_save()) and ok
		_free(s)
	for i2 in 3:
		ok = str(SaveManager.read_header(SaveManager.PROFILE_IDS[i2]).get("bakery_name", "")) == "Profile %d" % (i2 + 1) and ok
	SaveManager.delete_profile(&"profile_2")
	ok = ok and SaveManager.has_profile(&"profile_1") and SaveManager.has_profile(&"profile_3") and not SaveManager.has_profile(&"profile_2")
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	_add("three save profiles initialize independently", ok)


func _check_golden() -> void:
	const GOLDEN: String = "res://tests/fixtures/golden_v3_day4.json"
	if not FileAccess.file_exists(GOLDEN):
		_add("golden save loads and re-saves idempotently", false, "missing fixture")
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	var s := SimulationRoot.new()
	add_child(s)
	s.load_from_save(data)
	var first: String = JSON.stringify(TestSuite.normalize_save(s.capture_save()), "", true, true)
	var s2 := SimulationRoot.new()
	add_child(s2)
	s2.load_from_save(JSON.parse_string(JSON.stringify(s.capture_save(), "", true, true)))
	var second: String = JSON.stringify(TestSuite.normalize_save(s2.capture_save()), "", true, true)
	_add("golden save loads and re-saves idempotently", first == second and SaveManager.validate_save(data, &"profile_1") == "")
	_free(s)
	_free(s2)


func _check_required_tests() -> void:
	if _quick:
		_add("all REQUIRED automated tests pass (GDD 107)", false, "--quick", true)
		return
	var out: Array = []
	var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
		"res://tests/test_runner.tscn"], out, true)
	var summary: String = ""
	for line: String in str("\n".join(out)).split("\n"):
		if line.begins_with("TESTS:") or line.begins_with("FAIL "):
			summary += line.strip_edges() + " "
	_add("all REQUIRED automated tests pass (GDD 107)", code == 0, summary.strip_edges())


func _check_exports() -> void:
	if _quick:
		_add("Web export completes", false, "--quick", true)
		_add("Android export preset validates", false, "--quick", true)
		return
	var dir: String = ProjectSettings.globalize_path("res://build")
	DirAccess.make_dir_recursive_absolute(dir.path_join("web"))
	DirAccess.make_dir_recursive_absolute(dir.path_join("android"))
	for spec: Array in [["Web", "web/index.html", "Web export completes"],
			["Android Debug APK", "android/roti-lezat-tycoon-debug.apk", "Android export preset validates"]]:
		var out: Array = []
		var code: int = OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"),
			"--export-debug", spec[0], dir.path_join(spec[1])], out, true)
		var why: String = ""
		var text: String = "\n".join(out)
		if text.contains("No export template found"):
			why = "export templates for 4.7.2 are not installed"
		elif text.contains("Android SDK"):
			why = "Android SDK not configured in Editor Settings"
		_add(str(spec[2]), code == 0 and why == "", why)
