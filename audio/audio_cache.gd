class_name AudioCache
extends RefCounted
## Cache disk bunyi hasil generator (Seksi 20 no. 108; v3.1 111.1: "Generated
## output may be cached ... source generation scripts must remain in repository").
##
## Merakit seluruh bunyi dari nol butuh beberapa detik CPU di PC dan jauh lebih
## lama di HP kentang (dulu sebagian besar waktu layar loading di emulator).
## Setiap stream yang selesai dirakit disimpan sebagai PCM 16-bit mentah di
## `user://audio_cache` (IndexedDB di Web); peluncuran berikutnya tinggal membaca
## berkasnya. Nama berkas memuat cap versi: hash sumber generator
## (SOURCE_HASH) dan versi engine, jadi resep yang berubah otomatis memakai
## berkas baru dan berkas lama dibuang saat cache pertama dipakai.
##
## Penulisan tidak pernah menahan frame: berkas besar (bed musik ~1 MB) ditulis
## sedikit demi sedikit (`flush_step`, dipanggil AudioManager tiap frame) ke
## berkas sementara lalu diganti nama, jadi berkas setengah jadi tidak pernah
## terbaca. Berkas yang rusak atau ukurannya tidak cocok diabaikan dan dirakit ulang.
##
## Tes memakai `enabled = false` (runner) supaya hasilnya tidak bergantung pada
## berkas dari sesi lain.

## Hash SHA-256 (12 heksa pertama) dari audio_generator.gd, music_build.gd, dan
## song_build.gd dengan akhir baris LF. WAJIB diperbarui setiap resep berubah
## (tes ACC_33_AUDIO_CACHE menghitungnya ulang dan gagal bila berbeda); cap ini
## membuat cache lama tidak terpakai lagi.
const SOURCE_HASH: String = "8fa9078c14ae"
const SOURCES: Array[String] = ["res://audio/audio_generator.gd", "res://audio/music_build.gd", "res://audio/song_build.gd"]
const DEFAULT_DIR: String = "user://audio_cache"
const MAGIC: int = 0x55415443  # "CTAU"
const HEADER: int = 16
## Byte paling banyak yang ditulis per frame.
const WRITE_BUDGET: int = 131072

static var enabled: bool = true
static var dir: String = DEFAULT_DIR
static var _pruned: bool = false
static var _queue: Array[Dictionary] = []
static var _file: FileAccess = null
static var _written: int = 0


## Cap versi berkas: hash sumber + versi engine (RNG dan matematika engine).
static func stamp() -> String:
	return "%s_%x" % [SOURCE_HASH, Engine.get_version_info().get("hex", 0)]


static func path_for(key: String) -> String:
	return dir.path_join("%s.%s.pcm" % [key.replace(":", "-").replace("/", "-"), stamp()])


## Stream dari cache, atau null bila tidak ada / tidak sah / cache mati.
static func fetch(key: String) -> AudioStreamWAV:
	if not enabled:
		return null
	_prune_once()
	var path: String = path_for(key)
	if not FileAccess.file_exists(path):
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if bytes.size() < HEADER or bytes.decode_u32(0) != MAGIC:
		return null
	var rate: int = bytes.decode_u32(4)
	var n: int = bytes.decode_u32(8)
	var looping: bool = bytes.decode_u32(12) == 1
	if rate < 4000 or rate > 96000 or n <= 0 or bytes.size() != HEADER + (n + AudioGenerator.TAIL_PAD) * 2:
		return null
	var s := AudioStreamWAV.new()
	s.format = AudioStreamWAV.FORMAT_16_BITS
	s.mix_rate = rate
	s.stereo = false
	s.data = bytes.slice(HEADER)
	if looping:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = n
	else:
		s.loop_mode = AudioStreamWAV.LOOP_DISABLED
	return s


## Ada berkas cache untuk `key` (belum tentu sah; `fetch` memeriksanya).
static func has(key: String) -> bool:
	return enabled and FileAccess.file_exists(path_for(key))


## Buang berkas `key` (rusak).
static func drop(key: String) -> void:
	var path: String = path_for(key)
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(path)


## Antrekan `stream` untuk ditulis ke cache (bertahap lewat `flush_step`).
static func store(key: String, stream: AudioStreamWAV) -> void:
	if not enabled or stream == null:
		return
	var data: PackedByteArray = stream.data
	var n: int = data.size() / 2 - AudioGenerator.TAIL_PAD
	if n <= 0:
		return
	var head := PackedByteArray()
	head.resize(HEADER)
	head.encode_u32(0, MAGIC)
	head.encode_u32(4, stream.mix_rate)
	head.encode_u32(8, n)
	head.encode_u32(12, 1 if stream.loop_mode == AudioStreamWAV.LOOP_FORWARD else 0)
	for q: Dictionary in _queue:
		if q["path"] == path_for(key):
			return
	_queue.append({"path": path_for(key), "bytes": head + data})


## Tulis paling banyak `budget` byte dari antrean. true bila masih ada sisa.
static func flush_step(budget: int = WRITE_BUDGET) -> bool:
	if _queue.is_empty():
		return false
	if not enabled:
		_queue.clear()
		return false
	var job: Dictionary = _queue[0]
	var bytes: PackedByteArray = job["bytes"]
	if _file == null:
		DirAccess.make_dir_recursive_absolute(dir)
		_file = FileAccess.open(str(job["path"]) + ".tmp", FileAccess.WRITE)
		_written = 0
		if _file == null:
			_queue.pop_front()
			return not _queue.is_empty()
	var to: int = mini(_written + budget, bytes.size())
	_file.store_buffer(bytes.slice(_written, to))
	_written = to
	if _written >= bytes.size():
		_file.close()
		_file = null
		var final: String = str(job["path"])
		if FileAccess.file_exists(final):
			DirAccess.remove_absolute(final)
		DirAccess.rename_absolute(final + ".tmp", final)
		_queue.pop_front()
	return not _queue.is_empty()


## Selesaikan semua tulisan sekarang (tes, keluar).
static func flush_all() -> void:
	while flush_step(1 << 30):
		pass


static func pending_writes() -> int:
	return _queue.size()


## Buang berkas dengan cap lama dan sisa berkas sementara (sekali per sesi).
static func _prune_once() -> void:
	if _pruned:
		return
	_pruned = true
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	var suffix: String = ".%s.pcm" % stamp()
	for f: String in d.get_files():
		if not f.ends_with(suffix) and (f.ends_with(".pcm") or f.ends_with(".tmp")):
			d.remove(f)


## Kosongkan cache (tes, Reset Game tidak perlu memanggilnya).
static func clear() -> void:
	_queue.clear()
	if _file != null:
		_file.close()
		_file = null
	_pruned = false
	var d: DirAccess = DirAccess.open(dir)
	if d == null:
		return
	for f: String in d.get_files():
		if f.ends_with(".pcm") or f.ends_with(".tmp"):
			d.remove(f)


## Hash sumber generator saat ini (12 heksa pertama SHA-256, akhir baris LF).
static func source_hash() -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	for p: String in SOURCES:
		ctx.update(FileAccess.get_file_as_string(p).replace("\r", "").to_utf8_buffer())
	return ctx.finish().hex_encode().substr(0, 12)
