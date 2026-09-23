extends Node

# SaveManager (autoload) — menyimpan dan memuat progres permainan (GDD 12.6).
#
# Format berkas: {"version": 1, "state": {...}} dalam JSON polos.
# Jalur `user://` dipetakan otomatis oleh Godot:
#   - Web (itch.io): ke IndexedDB peramban.
#   - Android/Desktop: ke direktori privat aplikasi.
# Karena di Web tidak ada sistem berkas nyata, penulisan selalu ditutup rapat lalu
# disinkronkan agar data benar-benar mendarat di IndexedDB sebelum tab ditutup.

const PATH: String = "user://savegame.json"
const VERSION: int = 1

# Nama berkas tanpa awalan "user://", dipakai saat menghapus lewat DirAccess.
const FILE_NAME: String = "savegame.json"

# Pesan galat terakhir (Bahasa Indonesia) untuk ditampilkan di UI bila perlu.
var last_error: String = ""


func _ready() -> void:
	# Simpan otomatis setiap kali satu hari selesai (ARCHITECTURE 11).
	EventBus.day_ended.connect(_on_day_ended)


func _on_day_ended(_ledger: Dictionary) -> void:
	save_game()


# --- API utama -------------------------------------------------------------

# Menulis state saat ini ke berkas. Mengembalikan false bila gagal, tanpa mengubah state.
func save_game() -> bool:
	last_error = ""
	var payload: Dictionary = {
		"version": VERSION,
		"state": GameState.to_dict(),
	}
	var text: String = JSON.stringify(payload, "\t")
	if text.is_empty():
		last_error = "Gagal mengubah data permainan menjadi JSON."
		push_warning(last_error)
		return false

	var f: FileAccess = FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		last_error = "Tidak bisa menulis berkas simpanan (kode %d)." % FileAccess.get_open_error()
		push_warning(last_error)
		return false

	f.store_string(text)
	f.flush()
	f.close()

	# Di ekspor Web, menutup berkas belum tentu langsung menulis ke IndexedDB.
	_sync_web_filesystem()
	return true


# Membaca berkas simpanan dan menerapkannya ke GameState.
# Berkas rusak/tidak terbaca membuat fungsi mengembalikan false tanpa menyentuh state.
func load_game() -> bool:
	last_error = ""
	if not FileAccess.file_exists(PATH):
		last_error = "Belum ada berkas simpanan."
		return false

	var f: FileAccess = FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		last_error = "Berkas simpanan tidak bisa dibuka (kode %d)." % FileAccess.get_open_error()
		push_warning(last_error)
		return false

	var text: String = f.get_as_text()
	f.close()

	if text.strip_edges().is_empty():
		last_error = "Berkas simpanan kosong."
		push_warning(last_error)
		return false

	var json: JSON = JSON.new()
	var err: int = json.parse(text)
	if err != OK:
		last_error = "Berkas simpanan rusak (baris %d: %s)." % [json.get_error_line(), json.get_error_message()]
		push_warning(last_error)
		return false

	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY:
		last_error = "Struktur berkas simpanan tidak dikenali."
		push_warning(last_error)
		return false

	var root: Dictionary = parsed
	var data: Dictionary = _migrate(root)

	var raw_state: Variant = data.get("state", null)
	if typeof(raw_state) != TYPE_DICTIONARY:
		last_error = "Bagian \"state\" tidak ditemukan di berkas simpanan."
		push_warning(last_error)
		return false

	var state: Dictionary = raw_state
	if not _looks_valid(state):
		last_error = "Isi berkas simpanan tidak lengkap."
		push_warning(last_error)
		return false

	GameState.from_dict(state)
	return true


# Memaksa sinkronisasi `user://` ke penyimpanan nyata (IndexedDB di Web).
# Publik karena AudioBus menulis preferensi suaranya sendiri ke user://settings.cfg
# dan butuh jaminan yang sama bahwa datanya mendarat sebelum tab ditutup.
func sync_user_files() -> void:
	_sync_web_filesystem()


func has_save() -> bool:
	return FileAccess.file_exists(PATH)


func delete_save() -> void:
	last_error = ""
	if not FileAccess.file_exists(PATH):
		return
	var dir: DirAccess = DirAccess.open("user://")
	if dir == null:
		last_error = "Tidak bisa membuka direktori simpanan (kode %d)." % DirAccess.get_open_error()
		push_warning(last_error)
		return
	var err: int = dir.remove(FILE_NAME)
	if err != OK:
		last_error = "Berkas simpanan gagal dihapus (kode %d)." % err
		push_warning(last_error)
		return
	_sync_web_filesystem()


# --- Migrasi versi ---------------------------------------------------------

# Menyesuaikan berkas simpanan lama ke bentuk versi terkini.
# Riwayat perubahan format:
#   v0 (tanpa kunci "version", isinya langsung state) -> v1: dibungkus {"version","state"}.
func _migrate(d: Dictionary) -> Dictionary:
	var out: Dictionary = d.duplicate(true)

	# Berkas pra-versi: seluruh isinya adalah state, belum ada pembungkus.
	if not out.has("state") and out.has("coins"):
		out = {"version": 1, "state": d.duplicate(true)}

	var v: int = int(out.get("version", 1))
	if v < 1:
		v = 1
	if v > VERSION:
		push_warning("Berkas simpanan berasal dari versi %d (lebih baru dari %d); dimuat apa adanya." % [v, VERSION])
		v = VERSION
	out["version"] = v
	return out


# --- Pembantu internal -----------------------------------------------------

# Pemeriksaan minimum agar state setengah jadi tidak menimpa permainan yang berjalan.
func _looks_valid(state: Dictionary) -> bool:
	return state.has("coins") and state.has("day") and state.has("location_tier")


# Memaksa sinkronisasi sistem berkas virtual pada ekspor Web (user:// -> IndexedDB).
# Di platform lain fungsi ini tidak melakukan apa pun.
func _sync_web_filesystem() -> void:
	if not OS.has_feature("web"):
		return
	if not Engine.has_singleton("JavaScriptBridge"):
		return
	var bridge: Object = Engine.get_singleton("JavaScriptBridge")
	if bridge == null or not bridge.has_method("eval"):
		return
	var js: String = "if (typeof FS !== 'undefined' && FS.syncfs) { FS.syncfs(false, function (e) {}); }"
	bridge.call("eval", js, true)
