extends Node
## SaveManager — serialisasi save (GDD idle 15.3; v3.1 34, 77, 106, 132). Game
## hanya memakai satu save, SAVE_ID (GDD idle 19 no. 21); fungsi per profil dan
## dua slot lainnya tersisa dari versi tiga profil, untuk menggabungkan save lama
## (adopt_latest_save) dan untuk tes. Skema save idle mulai dari 1 dan ditandai
## `game_mode: "idle"`. Save tycoon v3.1 (tanpa `game_mode`) tidak didukung dan
## tidak dimigrasi: game memperlakukannya seperti tidak ada save, dan toko baru
## memindahkannya ke slot kosong lebih dulu (make_room_for_new_game).
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
## Satu-satunya save yang dipakai game (GDD idle 19 no. 21).
const SAVE_ID: StringName = &"profile_1"
const GAME_VERSION: String = "1.0.0"
const GAME_MODE: String = "idle"
const REQUIRED_KEYS: Array[String] = [
	"game_mode", "schema_version", "profile_id", "bakery_name", "player", "day", "time_seconds",
	"location_id", "economy", "upgrades", "display_inventory", "production_jobs",
	"equipment_states", "rng_states",
]

## SimulationRoot aktif (diisi GameRoot). Null di luar permainan.
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
		header.merge(header_of(r["data"]), true)
		header["used_backup"] = bool(r.get("used_backup", false))
	elif FileAccess.file_exists(main_path(profile_id)) or FileAccess.file_exists(backup_path(profile_id)):
		header["exists"] = true
		header["corrupt"] = true
	return header


## Rincian kartu profil dari save yang sah (juga pratinjau kode save yang
## ditempel, GDD idle 20 no. 57).
static func header_of(d: Dictionary) -> Dictionary:
	var header: Dictionary = {"exists": true}
	header["bakery_name"] = str(d.get("bakery_name", ""))
	header["day"] = int(d.get("day", 1))
	header["location_id"] = str(d.get("location_id", ""))
	header["balance_kr"] = _decode_money((d.get("economy", {}) as Dictionary).get("balance_kr", 0.0))
	header["run_index"] = int((d.get("franchise", {}) as Dictionary).get("run_index", 1))
	header["stars"] = int((d.get("franchise", {}) as Dictionary).get("stars", 0))
	header["last_played_at"] = str(d.get("last_played_at", ""))
	header["last_played_unix"] = float(d.get("last_played_unix", 0.0))
	# Badge achievement yang sudah didapat, untuk medali di kartu profil (GDD 72.1).
	var badges: Array[String] = []
	for o: Variant in ((d.get("decorations", {}) as Dictionary).get("owned", []) as Array):
		if not (o is Dictionary):
			continue
		var dd: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(StringName(str((o as Dictionary).get("deco_id", ""))))
		if dd != null and dd.is_badge() and not badges.has(String(dd.id)):
			badges.append(String(dd.id))
	header["badges"] = badges
	return header


func has_profile(profile_id: StringName) -> bool:
	return FileAccess.file_exists(main_path(profile_id)) or FileAccess.file_exists(backup_path(profile_id))


## Profil dengan last_played_at terbaru untuk tombol Continue (GDD 89.2).
func latest_profile() -> StringName:
	var h: Dictionary = latest_header()
	return StringName(str(h["profile_id"])) if not h.is_empty() else &""


## Header save yang bisa dimainkan dengan last_played_at terbaru (yang dimuat
## sesudah Tap to Start, lihat adopt_latest_save), atau {} bila tidak ada.
func latest_header() -> Dictionary:
	var best: Dictionary = {}
	var best_time: Array = []
	for h: Dictionary in scan_headers():
		if not bool(h.get("exists", false)) or bool(h.get("corrupt", false)) or bool(h.get("classic", false)):
			continue
		var t: Array = [str(h.get("last_played_at", "")), float(h.get("last_played_unix", 0.0))]
		if best.is_empty() or t[0] > best_time[0] or (t[0] == best_time[0] and t[1] > best_time[1]):
			best = h
			best_time = t
	return best


func delete_profile(profile_id: StringName) -> void:
	for p: String in [main_path(profile_id), backup_path(profile_id), tmp_path(profile_id)]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
	GameLogger.important("SAVE", "profile %s deleted" % profile_id)


# ===========================================================================
# SATU SAVE (GDD idle 19 no. 21, 20 no. 68): game hanya memakai SAVE_ID. Dua
# slot lain hanya tersisa dari versi dengan tiga profil.
# ===========================================================================

## Status save tunggal: "none", "playable", "classic" (save tycoon v3.1), atau
## "corrupt" (main dan backup tidak terbaca).
func save_state() -> String:
	var h: Dictionary = read_header(SAVE_ID)
	if not bool(h.get("exists", false)):
		return "none"
	if bool(h.get("classic", false)):
		return "classic"
	return "corrupt" if bool(h.get("corrupt", false)) else "playable"


## Save versi tiga profil: toko yang terakhir dimainkan menjadi save tunggal.
## Toko lama di SAVE_ID bertukar tempat dengannya, jadi tidak ada toko yang
## terhapus; save yang tidak bisa dimainkan di SAVE_ID (tycoon v3.1, rusak)
## pindah ke slot kosong bila ada. Tidak berbuat apa-apa bila SAVE_ID sudah
## yang terbaru. true bila ada yang dipindah.
func adopt_latest_save() -> bool:
	var latest: StringName = latest_profile()
	if latest == &"" or latest == SAVE_ID:
		return false
	var newest: Dictionary = read_profile(latest)
	if not bool(newest.get("ok", false)):
		return false
	var old: Dictionary = read_profile(SAVE_ID)
	if bool(old.get("ok", false)):
		if not write_profile(latest, old["data"]):
			return false
	elif has_profile(SAVE_ID):
		for pid: StringName in PROFILE_IDS:
			if pid != SAVE_ID and pid != latest and not has_profile(pid):
				_park(SAVE_ID, pid)
				break
	if not write_profile(SAVE_ID, newest["data"]):
		write_profile(latest, newest["data"])
		return false
	GameLogger.important("SAVE", "the latest bakery moved from %s into %s" % [latest, SAVE_ID])
	return true


## Sebelum game baru ditulis ke SAVE_ID: save tycoon v3.1 di sana dipindah ke
## slot kosong lain (bila ada), supaya tidak tertimpa diam-diam.
func make_room_for_new_game() -> void:
	if save_state() != "classic":
		return
	for pid: StringName in PROFILE_IDS:
		if pid != SAVE_ID and not has_profile(pid):
			_park(SAVE_ID, pid)
			return


## Pindahkan berkas main dan backup `from` apa adanya ke slot `to` yang kosong.
func _park(from: StringName, to: StringName) -> void:
	if has_profile(to):
		return
	for pair: Array in [[main_path(from), main_path(to)], [backup_path(from), backup_path(to)]]:
		if FileAccess.file_exists(pair[0]):
			DirAccess.rename_absolute(ProjectSettings.globalize_path(pair[0]), ProjectSettings.globalize_path(pair[1]))
	GameLogger.important("SAVE", "the unplayable save in %s moved to %s" % [from, to])


## Reset Game: semua slot dihapus, termasuk sisa dari versi tiga profil.
func delete_all_profiles() -> void:
	for pid: StringName in PROFILE_IDS:
		delete_profile(pid)


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


# ===========================================================================
# KODE SAVE (GDD idle 15.3, 20 no. 57): profil sebagai teks untuk dipindah ke
# perangkat lain atau dicadangkan di luar browser, tetap tanpa server.
# ===========================================================================

## Awalan kode: nama game + versi format kode (bukan versi skema save).
const CODE_PREFIX: String = "CRUMB1-"
## Batas ukuran save setelah dekompresi, supaya kode rusak tidak memakan memori.
const CODE_MAX_BYTES: int = 16 * 1024 * 1024


## Kode teks profil: save yang sah (main, atau backup bila main rusak) sebagai
## JSON, dikompres gzip, lalu base64. "" bila profil tidak bisa dibaca.
func export_code(profile_id: StringName) -> String:
	var r: Dictionary = read_profile(profile_id)
	if not bool(r.get("ok", false)):
		return ""
	var text: String = JSON.stringify(r["data"], "", true, true)
	var packed: PackedByteArray = text.to_utf8_buffer().compress(FileAccess.COMPRESSION_GZIP)
	return CODE_PREFIX + Marshalls.raw_to_base64(packed)


## Baca kode save: {ok, data} dengan data yang sudah dimigrasi dan divalidasi
## seperti file save, atau {ok: false, error} dengan error "format" (bukan kode
## Crumbtown, terpotong, atau rusak), "classic" (save tycoon v3.1), "newer"
## (dari versi game yang lebih baru), atau "invalid" (isi save tidak sah).
## Spasi dan ganti baris dari aplikasi chat diabaikan.
func decode_code(code: String) -> Dictionary:
	var s: String = code
	for ws: String in [" ", "\n", "\r", "\t"]:
		s = s.replace(ws, "")
	if not s.begins_with(CODE_PREFIX):
		return {"ok": false, "error": "format"}
	var b64: String = s.substr(CODE_PREFIX.length())
	if not _is_base64(b64):
		return {"ok": false, "error": "format"}
	var raw: PackedByteArray = Marshalls.base64_to_raw(b64)
	# Kepala gzip (1f 8b): selain itu bukan kode dari export_code.
	if raw.size() < 18 or raw[0] != 0x1f or raw[1] != 0x8b:
		return {"ok": false, "error": "format"}
	var bytes: PackedByteArray = raw.decompress_dynamic(CODE_MAX_BYTES, FileAccess.COMPRESSION_GZIP)
	if bytes.is_empty():
		return {"ok": false, "error": "format"}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {"ok": false, "error": "format"}
	var data: Dictionary = json.data
	if is_classic(data):
		return {"ok": false, "error": "classic"}
	var migrated: Dictionary = migrate(data)
	if not bool(migrated.get("ok", false)):
		return {"ok": false, "error": "newer" if int(data.get("schema_version", 0)) > current_schema_version() else "invalid"}
	var d: Dictionary = migrated["data"]
	if validate_save(d, &"") != "":
		return {"ok": false, "error": "invalid"}
	return {"ok": true, "data": d}


## Tulis save dari kode ke profil `profile_id`, menimpa isinya (save lama
## menjadi backup profil itu). "" bila berhasil, selain itu error decode_code
## atau "write".
func import_code(code: String, profile_id: StringName) -> String:
	var r: Dictionary = decode_code(code)
	if not bool(r.get("ok", false)):
		return str(r.get("error", "format"))
	var d: Dictionary = r["data"]
	d["profile_id"] = String(profile_id)
	if not write_profile(profile_id, d):
		return "write"
	GameLogger.important("SAVE", "save code imported into %s" % profile_id)
	return ""


## Hanya karakter base64 dengan panjang kelipatan 4 dan "=" di ujung saja:
## Marshalls.base64_to_raw mencatat error mesin untuk teks lain.
static func _is_base64(s: String) -> bool:
	if s.is_empty() or s.length() % 4 != 0:
		return false
	var pad: int = 0
	for i in s.length():
		var ch: int = s.unicode_at(i)
		if ch == 61:
			pad += 1
			continue
		if pad > 0:
			return false
		var ok: bool = (ch >= 65 and ch <= 90) or (ch >= 97 and ch <= 122) or (ch >= 48 and ch <= 57) or ch == 43 or ch == 47
		if not ok:
			return false
	return pad <= 2


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
	# Acuan waktu offline ikut setiap save (GDD idle 9.2).
	simulation.call("note_active")
	var data: Dictionary = simulation.call("capture_save")
	var ok: bool = write_profile(active_profile, data)
	_last_autosave_msec = Time.get_ticks_msec()
	_pending_reason = ""
	_pending_critical = false
	return ok


func write_count() -> int:
	return _write_count
