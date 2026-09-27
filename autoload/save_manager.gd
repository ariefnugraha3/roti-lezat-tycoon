extends Node
## SaveManager — serialisasi tiga profil independen (GDD 34, 77, 89.3, 106, 132).
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
const REQUIRED_KEYS: Array[String] = [
	"schema_version", "profile_id", "bakery_name", "player", "day", "time_seconds", "phase",
	"location_id", "economy", "inventory", "display_inventory", "production_jobs",
	"equipment_states", "flags", "rng_states",
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
	var header: Dictionary = {"profile_id": profile_id, "exists": false, "corrupt": false}
	var r: Dictionary = read_profile(profile_id)
	if bool(r.get("ok", false)):
		var d: Dictionary = r["data"]
		header["exists"] = true
		header["bakery_name"] = str(d.get("bakery_name", ""))
		header["day"] = int(d.get("day", 1))
		header["location_id"] = str(d.get("location_id", ""))
		header["balance_kr"] = _decode_money((d.get("economy", {}) as Dictionary).get("balance_kr", 0.0))
		header["last_played_at"] = str(d.get("last_played_at", ""))
		header["last_played_unix"] = float(d.get("last_played_unix", 0.0))
		header["used_backup"] = bool(r.get("used_backup", false))
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
		if not bool(h.get("exists", false)) or bool(h.get("corrupt", false)):
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

## {ok, data, used_backup, error}. Main dicoba lebih dulu, lalu backup.
func read_profile(profile_id: StringName) -> Dictionary:
	var main_r: Dictionary = _read_and_validate(main_path(profile_id), profile_id)
	if bool(main_r.get("ok", false)):
		main_r["used_backup"] = false
		return main_r
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
	var migrated: Dictionary = migrate(data)
	if not bool(migrated.get("ok", false)):
		return migrated
	var d: Dictionary = migrated["data"]
	var problem: String = validate_save(d, profile_id)
	if problem != "":
		return {"ok": false, "error": problem}
	return {"ok": true, "data": d}


## Validasi skema minimum (GDD 106). Mengembalikan "" bila sah.
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
# MIGRASI (GDD 34.5): vN -> vN+1, field hilang diberi default versioned.
# ===========================================================================

func migrate(data: Dictionary) -> Dictionary:
	var d: Dictionary = data.duplicate(true)
	var v: int = int(d.get("schema_version", 0))
	var target: int = current_schema_version()
	if v <= 0:
		return {"ok": false, "error": "no schema_version"}
	if v > target:
		return {"ok": false, "error": "save is newer than this game"}
	while v < target:
		match v:
			1:
				d = _migrate_v1_to_v2(d)
			2:
				d = _migrate_v2_to_v3(d)
			_:
				return {"ok": false, "error": "no migrator from v%d" % v}
		v = int(d["schema_version"])
	return {"ok": true, "data": d}


## v1 (prototipe awal skema profil): belum ada RNG per stream & analitik resep.
func _migrate_v1_to_v2(d: Dictionary) -> Dictionary:
	if not d.has("rng_states"):
		# Stream diturunkan ulang dari master seed lama (state stream v1 tidak ada).
		var seed_v: int = int(d.get("master_seed", 1))
		d["rng_states"] = {"master_seed": str(seed_v), "day_seed": "0"}
	if not d.has("recipe_analytics"):
		d["recipe_analytics"] = {}
	if not d.has("statistics"):
		d["statistics"] = {}
	d["schema_version"] = 2
	return d


## v2: belum ada catalog_versions, ui_restore, dan flag freshness rollover.
func _migrate_v2_to_v3(d: Dictionary) -> Dictionary:
	if not d.has("catalog_versions"):
		d["catalog_versions"] = DataRegistry.catalog_versions.duplicate()
	if not d.has("ui_restore"):
		d["ui_restore"] = {"game_speed": 1, "camera_zoom": 1.0}
	var flags: Dictionary = d.get("flags", {})
	if not flags.has("last_freshness_rollover_day"):
		flags["last_freshness_rollover_day"] = int(d.get("day", 1)) - 1
	if not flags.has("economy_overflowed"):
		flags["economy_overflowed"] = false
	d["flags"] = flags
	if not d.has("active_floor_id"):
		d["active_floor_id"] = "floor_1"
	d["schema_version"] = 3
	return d


# ===========================================================================
# TULIS
# ===========================================================================

## Menulis dictionary yang sudah lengkap secara atomik (GDD 34.4, 77.5).
func write_profile(profile_id: StringName, data: Dictionary) -> bool:
	_ensure_dir()
	var d: Dictionary = data.duplicate(true)
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
