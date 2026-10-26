extends Node
## SaveManager — serialisasi tiga profil independen (GDD idle 15.3; v3.1 34, 77,
## 89.3, 106, 132). Skema save idle mulai dari 1 dan ditandai `game_mode: "idle"`.
## Save tycoon v3.1 (tanpa `game_mode`) tidak didukung: Main Menu menampilkannya
## sebagai "Classic save (not supported)" dengan tombol Delete, tanpa migrasi.
##
## SaveManager TIDAK memiliki state gameplay (GDD 98): saat menyimpan ia meminta
## snapshot dari SimulationRoot, saat memuat ia menyerahkan dictionary yang
## sudah divalidasi & dimigrasi kepada SimulationRoot untuk direkonstruksi.
##
## Penulisan atomik: tulis .tmp -> parse ulang untuk verifikasi -> salin main
## lama ke .backup.json -> ganti main. Save rusak TIDAK PERNAH ditimpa otomatis.

signal profile_saved(profile_id: StringName)
signal save_failed(profile_id: StringName, reason: String)

## Folder profil. Test mengarahkannya ke folder terpisah agar save pemain aman.
var dir: String = "user://saves"
const PROFILE_IDS: Array[StringName] = [&"profile_1", &"profile_2", &"profile_3"]
const GAME_VERSION: String = "1.0.0"
const GAME_MODE: String = "idle"
const REQUIRED_KEYS: Array[String] = [
	"game_mode", "schema_version", "profile_id", "bakery_name", "player", "day", "time_seconds",
	"location_id", "economy", "upgrades", "display_inventory", "production_jobs",
	"equipment_states", "rng_states",
]

## SimulationRoot aktif (diisi GameRoot). Null di Main Menu.
var simulation: Node = null
var active_profile: StringName = &""

var _pending_reason: String = ""
var _pending_critical: bool = false
var _last_autosave_msec: int = -1000000
var _write_count: int = 0


func current_schema_version() -> int:
	return int(DataRegistry.bal("save.schema_version"))


func main_path(profile_id: StringName) -> String:
	return dir.path_join("%s.json" % profile_id)


func backup_path(profile_id: StringName) -> String:
	return dir.path_join("%s.backup.json" % profile_id)


func tmp_path(profile_id: StringName) -> String:
	return dir.path_join("%s.tmp" % profile_id)


func _ensure_dir() -> void:
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)


# ===========================================================================
# HEADER / PROFIL
# ===========================================================================

## Header ringkas untuk kartu profil (GDD 89.3). Tidak membangun dunia.
func scan_headers() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for pid: StringName in PROFILE_IDS:
		out.append(read_header(pid))
	return out


func read_header(profile_id: StringName) -> Dictionary:
	var header: Dictionary = {"profile_id": profile_id, "exists": false, "corrupt": false, "classic": false}
	var r: Dictionary = read_profile(profile_id)
	if bool(r.get("classic", false)):
		header["exists"] = true
		header["classic"] = true
		return header
	if bool(r.get("ok", false)):
		var d: Dictionary = r["data"]
		header["exists"] = true
		header["bakery_name"] = str(d.get("bakery_name", ""))
		header["day"] = int(d.get("day", 1))
		header["location_id"] = str(d.get("location_id", ""))
		header["balance_kr"] = _decode_money((d.get("economy", {}) as Dictionary).get("balance_kr", 0.0))
		header["run_index"] = int((d.get("franchise", {}) as Dictionary).get("run_index", 1))
		header["stars"] = int((d.get("franchise", {}) as Dictionary).get("stars", 0))
		header["last_played_at"] = str(d.get("last_played_at", ""))
		header["last_played_unix"] = float(d.get("last_played_unix", 0.0))
		header["used_backup"] = bool(r.get("used_backup", false))
		# Badge achievement yang sudah didapat, untuk medali di kartu profil (GDD 72.1).
		var badges: Array[String] = []
		for o: Variant in ((d.get("decorations", {}) as Dictionary).get("owned", []) as Array):
			if not (o is Dictionary):
				continue
			var dd: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(StringName(str((o as Dictionary).get("deco_id", ""))))
			if dd != null and dd.is_badge() and not badges.has(String(dd.id)):
				badges.append(String(dd.id))
		header["badges"] = badges
	elif FileAccess.file_exists(main_path(profile_id)) or FileAccess.file_exists(backup_path(profile_id)):
		header["exists"] = true
		header["corrupt"] = true
	return header


func has_profile(profile_id: StringName) -> bool:
	return FileAccess.file_exists(main_path(profile_id)) or FileAccess.file_exists(backup_path(profile_id))


## Profil dengan last_played_at terbaru untuk tombol Continue (GDD 89.2).
func latest_profile() -> StringName:
	var best: StringName = &""
	var best_time: Array = []
	for h: Dictionary in scan_headers():
		if not bool(h.get("exists", false)) or bool(h.get("corrupt", false)) or bool(h.get("classic", false)):
			continue
		var t: Array = [str(h.get("last_played_at", "")), float(h.get("last_played_unix", 0.0))]
		if best == &"" or t[0] > best_time[0] or (t[0] == best_time[0] and t[1] > best_time[1]):
			best = h["profile_id"]
			best_time = t
	return best


func delete_profile(profile_id: StringName) -> void:
	for p: String in [main_path(profile_id), backup_path(profile_id), tmp_path(profile_id)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameLogger.important("SAVE", "profile %s deleted" % profile_id)


# ===========================================================================
# BACA
# ===========================================================================

## {ok, data, used_backup, error, classic}. Main dicoba lebih dulu, lalu backup.
## Save klasik v3.1 tidak pernah jatuh ke backup: keduanya sama-sama klasik.
func read_profile(profile_id: StringName) -> Dictionary:
	var main_r: Dictionary = _read_and_validate(main_path(profile_id), profile_id)
	if bool(main_r.get("ok", false)):
		main_r["used_backup"] = false
		return main_r
	if bool(main_r.get("classic", false)):
		return {"ok": false, "error": "classic", "classic": true, "used_backup": false}
	var back_r: Dictionary = _read_and_validate(backup_path(profile_id), profile_id)
	if bool(back_r.get("ok", false)):
		back_r["used_backup"] = true
		back_r["main_error"] = main_r.get("error", "")
		return back_r
	return {"ok": false, "error": str(main_r.get("error", "missing")), "used_backup": false}


func _read_and_validate(path: String, profile_id: StringName) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"ok": false, "error": "missing"}
	var text: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text) != OK or not json.data is Dictionary:
		return {"ok": false, "error": "invalid json"}
	var data: Dictionary = json.data
	if is_classic(data):
		return {"ok": false, "error": "classic", "classic": true}
	var migrated: Dictionary = migrate(data)
	if not bool(migrated.get("ok", false)):
		return migrated
	var d: Dictionary = migrated["data"]
	var problem: String = validate_save(d, profile_id)
	if problem != "":
		return {"ok": false, "error": problem}
	return {"ok": true, "data": d}


## Save tycoon v3.1: tidak punya `game_mode` idle (GDD idle 15.3).
static func is_classic(d: Dictionary) -> bool:
	return str(d.get("game_mode", "")) != GAME_MODE


## Validasi skema minimum (v3.1 106). Mengembalikan "" bila sah.
func validate_save(d: Dictionary, profile_id: StringName) -> String:
	for k: String in REQUIRED_KEYS:
		if not d.has(k):
			return "missing key %s" % k
	if int(d["schema_version"]) != current_schema_version():
		return "schema version %s" % d["schema_version"]
	if profile_id != &"" and StringName(str(d["profile_id"])) != profile_id:
		return "profile id mismatch"
	if DataRegistry.location(StringName(str(d["location_id"]))) == null:
		return "unknown location %s" % d["location_id"]
	var econ: Dictionary = d.get("economy", {})
	var bal: float = _decode_money(econ.get("balance_kr", 0.0))
	if is_nan(bal):
		return "NaN balance"
	return ""


# ===========================================================================
# MIGRASI (v3.1 34.5): vN -> vN+1 di dalam skema idle. Belum ada migrator:
# skema idle masih versi pertama.
# ===========================================================================

func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var v: int = int(d.get("schema_version", 0))
	var target: int = current_schema_version()
	if v <= 0:
		return {"ok": false, "error": "no schema_version"}
	if v > target:
		return {"ok": false, "error": "save is newer than this game"}
	if v < target:
		return {"ok": false, "error": "no migrator from v%d" % v}
	return {"ok": true, "data": d}


# ===========================================================================
# TULIS
# ===========================================================================

## Menulis dictionary yang sudah lengkap secara atomik (GDD 34.4, 77.5).
func write_profile(profile_id: StringName, data: Dictionary) -> bool:
	_ensure_dir()
	var d: Dictionary = data.duplicate(true)
	d["game_mode"] = GAME_MODE
	d["schema_version"] = current_schema_version()
	d["game_version"] = GAME_VERSION
	d["catalog_versions"] = DataRegistry.catalog_versions.duplicate()
	d["profile_id"] = String(profile_id)
	d["last_played_at"] = Time.get_datetime_string_from_system(true) + "Z"
	# Presisi sub-detik untuk urutan Continue (ISO hanya sampai detik).
	d["last_played_unix"] = Time.get_unix_time_from_system()
	if not d.has("created_at"):
		d["created_at"] = d["last_played_at"]
	# full_precision: posisi & jam simulasi harus kembali persis (determinisme pasca-load).
	var text: String = JSON.stringify(d, "\t", true, true)
	if text == "" or _contains_nan(d):
		save_failed.emit(profile_id, "NaN")
		GameLogger.error("SAVE", "refusing to write NaN into %s" % profile_id)
		return false
	var tmp: String = tmp_path(profile_id)
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		save_failed.emit(profile_id, "open")
		GameLogger.error("SAVE", "cannot open %s" % tmp)
		return false
	f.store_string(text)
	f.close()
	# Verifikasi: file sementara harus bisa dibaca ulang & lolos skema.
	var verify: Dictionary = _read_and_validate(tmp, profile_id)
	if not bool(verify.get("ok", false)):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
		save_failed.emit(profile_id, str(verify.get("error", "")))
		GameLogger.error("SAVE", "verification failed for %s: %s" % [profile_id, verify.get("error", "")])
		return false
	var main: String = main_path(profile_id)
	var backup: String = backup_path(profile_id)
	if FileAccess.file_exists(main):
		# Backup hanya dari main yang masih sah: main rusak tidak menggeser backup baik.
		if bool(_read_and_validate(main, profile_id).get("ok", false)):
			if FileAccess.file_exists(backup):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(backup))
			DirAccess.rename_absolute(ProjectSettings.globalize_path(main), ProjectSettings.globalize_path(backup))
		else:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(main))
	var err: Error = DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(main))
	if err != OK:
		save_failed.emit(profile_id, "rename")
		GameLogger.error("SAVE", "rename failed for %s" % profile_id)
		return false
	_write_count += 1
	profile_saved.emit(profile_id)
	GameLogger.info("SAVE", "saved %s (day %s)" % [profile_id, d.get("day")])
	return true


func _contains_nan(v: Variant) -> bool:
	if v is float:
		return is_nan(v)
	if v is Dictionary:
		for k: Variant in (v as Dictionary).keys():
			if _contains_nan((v as Dictionary)[k]):
				return true
	if v is Array:
		for x: Variant in v:
			if _contains_nan(x):
				return true
	return false


## Uang disimpan sebagai angka biasa, kecuali +INF hasil overflow yang disimpan
## sebagai string "INF" (JSON tidak punya infinity, GDD 73, 77.5).
static func encode_money(v: float) -> Variant:
	if is_inf(v):
		return "INF"
	return v


static func _decode_money(v: Variant) -> float:
	if v is String and str(v) == "INF":
		return INF
	return float(v)


static func decode_money(v: Variant) -> float:
	return _decode_money(v)


# ===========================================================================
# AUTOSAVE (GDD 34.3)
# ===========================================================================

## Minta autosave. Non-critical di-debounce; critical (focus loss) segera begitu
## simulasi mencapai stable checkpoint.
func request_autosave(reason: String, critical: bool = false) -> void:
	if simulation == null or active_profile == &"":
		return
	_pending_reason = reason
	_pending_critical = _pending_critical or critical
	_try_flush()


func _process(_delta: float) -> void:
	if _pending_reason != "":
		_try_flush()


func _try_flush() -> void:
	if simulation == null or active_profile == &"":
		_pending_reason = ""
		_pending_critical = false
		return
	var now: int = Time.get_ticks_msec()
	var debounce_ms: int = int(DataRegistry.balf("save.autosave_debounce_seconds") * 1000.0)
	if not _pending_critical and now - _last_autosave_msec < debounce_ms:
		return
	if not bool(simulation.call("is_stable_checkpoint")):
		return
	save_now()


## Simpan profil aktif sekarang (bila simulasi stabil).
func save_now() -> bool:
	if simulation == null or active_profile == &"":
		return false
	if not bool(simulation.call("is_stable_checkpoint")):
		return false
	var data: Dictionary = simulation.call("capture_save")
	var ok: bool = write_profile(active_profile, data)
	_last_autosave_msec = Time.get_ticks_msec()
	_pending_reason = ""
	_pending_critical = false
	return ok


func write_count() -> int:
	return _write_count
