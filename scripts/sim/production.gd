class_name ProductionSystem
extends Node

## ProductionSystem -- antrean kerja mixer & oven (GDD 2, GDD 3.2, GDD 5.1, GDD 5.3).
##
## Sistem ini TIDAK memakai _process/_physics_process. `Main` yang menjalankan loop
## dan memanggil antarmuka lima metode dari ARCHITECTURE 7.0:
##   setup(main) / sim_tick(delta, hour) / on_day_start(day) / on_day_end(ledger) / reset()
## Semua keacakan memakai GameConfig.rng agar simulasi bisa diulang persis dari benih.
##
## Alur satu batch (GDD 5.3 "Langkah Produksi"):
##   1. Aduk di mixer  -> lama = EquipmentDB.mixer_time(mixer_tier) / pengali kecepatan baker
##   2. Adonan pindah ke oven kosong (bila semua oven penuh, adonan MENUNGGU di mangkuk mixer)
##   3. Panggang        -> lama = EquipmentDB.oven_time(oven_tier)  / pengali kecepatan baker
##   4. Roti matang ("prima") menunggu diangkat; makin lama menganggur makin gosong (GDD 2)
##   5. Pindahkan ke rak display (collect) atau diangkat otomatis oleh baker (GDD 3.2)
##
## Bentuk Dictionary job mengikuti ARCHITECTURE 7.1 persis. Satu kunci TAMBAHAN
## dipakai internal dan selalu ada di setiap job: `remaining` = sisa roti di loyang
## yang belum tertampung rak display (rak penuh -> sebagian roti menunggu di loyang).
## Kunci wajib ARCHITECTURE tidak diubah, tidak diganti nama, dan tidak berubah tipe.

# --- ID kanonik (ARCHITECTURE 2.5) -----------------------------------------

const STAGE_MIXING: String = "mixing"
const STAGE_BAKING: String = "baking"
const STAGE_READY: String = "ready"
const STAGE_BURNED: String = "burned"
const STAGE_COLLECTED: String = "collected"

const QUALITY_RAW: String = "mentah"
const QUALITY_PRIME: String = "prima"
const QUALITY_ALMOST_BURNT: String = "hampir_gosong"
const QUALITY_BURNT: String = "gosong"

const KIND_MIXER: String = "mixer"
const KIND_OVEN: String = "oven"

const ROLE_BAKER: String = "baker"

# --- Tetapan kegosongan (GDD 2 + GameConfig.BURN_GRACE_RATIO) ---------------

## Ambang kedua kegosongan. GDD hanya menetapkan satu angka toleransi
## (BURN_GRACE_RATIO = 35% waktu panggang). Tahap "hampir_gosong" memakai
## toleransi pertama, lalu satu rentang toleransi yang sama lagi sebelum roti
## benar-benar "gosong" (35% -> hampir gosong, 70% -> gosong).
const BURN_RUIN_MULT: float = 2.0

## Batas bawah durasi satu tahap agar pembagian dengan pengali kecepatan baker
## tidak pernah menghasilkan durasi nol/negatif.
const MIN_DURATION: float = 0.05

## Pengali kecepatan baku bila tidak ada baker aktif (GDD 3.2 Tier 1 = 1.0x).
const DEFAULT_BAKER_SPEED: float = 1.0

# --- Keadaan internal ------------------------------------------------------

## Rujukan ke node Main yang menjalankan loop simulasi (ARCHITECTURE 7.0).
var _main: Node = null

## Seluruh job yang sedang berjalan; satu job menempati satu slot alat.
var _jobs: Array = []

## Nomor urut job berikutnya.
var _next_id: int = 1

## Jam in-game terakhir yang diterima dari Main (dipakai sebagai stempel waktu).
var _hour: float = GameConfig.HOUR_START

## Nilai KR bahan yang benar-benar terpakai produksi hari ini.
var _spent_today: float = 0.0

## job_id -> true untuk loyang yang sedang dijaga baker (Auto-Retrieve GDD 3.2).
## Baker terus mencoba menata ulang bila rak display sempat penuh.
var _guarded: Dictionary = {}


# ===========================================================================
# Antarmuka tick deterministik (ARCHITECTURE 7.0)
# ===========================================================================

func setup(main: Node) -> void:
	_main = main
	_hour = GameConfig.HOUR_START


func sim_tick(delta: float, hour: float) -> void:
	_hour = hour
	if delta <= 0.0:
		return

	# Tahap 1: majukan setiap job pada tahapannya masing-masing.
	# Iterasi memakai salinan array karena job bisa selesai/terbuang di tengah jalan.
	for e: Variant in _jobs.duplicate():
		var job: Dictionary = e
		var stage: String = String(job.get("stage", ""))
		if stage == STAGE_MIXING:
			_advance_mixing(job, delta)
		elif stage == STAGE_BAKING:
			_advance_baking(job, delta)
		elif stage == STAGE_READY:
			_advance_ready(job, delta)

	# Tahap 2: adonan yang selesai diaduk mencari oven kosong, urut kedatangan.
	# Bila oven penuh, adonan tetap menunggu di mangkuk mixer (tidak hilang).
	for e2: Variant in _jobs.duplicate():
		var job2: Dictionary = e2
		if String(job2.get("stage", "")) != STAGE_MIXING:
			continue
		if float(job2.get("elapsed", 0.0)) < float(job2.get("duration", 0.0)):
			continue
		# Adonan milik pemain menunggu DIANGKAT, bukan berpindah sendiri.
		if bool(job2.get("manual", false)):
			continue
		var oven_slot: int = _free_slot(KIND_OVEN)
		if oven_slot < 0:
			break
		_start_baking(job2, oven_slot)


func on_day_start(day: int) -> void:
	_hour = GameConfig.HOUR_START
	_spent_today = 0.0
	# Loyang sisa kemarin tetap menempel di alat; ingatkan pemain agar segera diangkat.
	if not _jobs.is_empty():
		EventBus.toast.emit("Hari %d: %d loyang kemarin masih di alat" % [day, _jobs.size()], "warning")


func on_day_end(ledger: Dictionary) -> void:
	# Toko tutup: seluruh roti yang sudah matang diangkat ke rak agar tidak hangus.
	collect_all()
	# EconomySystem yang menyusun ledger; di sini hanya diisi bila belum ada,
	# supaya angka biaya bahan tidak pernah hilang (ARCHITECTURE 7.1 "ledger harian").
	if not ledger.has("spent_ingredients"):
		ledger["spent_ingredients"] = _spent_today


func reset() -> void:
	_jobs.clear()
	_guarded.clear()
	_next_id = 1
	_spent_today = 0.0
	_hour = GameConfig.HOUR_START


# ===========================================================================
# API publik untuk sistem lain (Main, StaffSim, EconomySystem, HUD)
# ===========================================================================

## Memasukkan `batches` batch resep ke mixer yang kosong.
## Mengembalikan false tanpa efek samping bila resep belum siap, mixer penuh,
## atau bahan di gudang tidak cukup. Penolakan sengaja dibuat senyap
## (tanpa toast) karena StaffSim memanggilnya berulang kali.
##
## `manual` = job ini dikerjakan KARAKTER PEMAIN, bukan asisten dapur.
## Job manual berhenti di setiap ujung tahap dan menunggu perintah pemain:
## adonan tidak melompat sendiri ke oven, dan roti matang tidak menata dirinya
## ke rak. Itulah seluruh perbedaannya — waktu, biaya, dan kegosongan dihitung
## dengan rumus yang sama persis.
func queue_batch(recipe_id: String, batches: int, manual: bool = false) -> bool:
	return _create_job(recipe_id, batches, -1, manual) > 0


## Varian queue_batch() untuk karakter pemain: adonan masuk ke SLOT MIXER yang
## benar-benar ia hampiri, dan id job-nya dikembalikan supaya lapisan tugas bisa
## mengikuti nasib adonan itu sampai ke rak.
##
## Mengembalikan 0 bila pesanan ditolak (bahan kurang / mixer terpakai).
func queue_manual(recipe_id: String, batches: int, mixer_slot: int) -> int:
	return _create_job(recipe_id, batches, mixer_slot, true)


# Membuat satu job baru. `mixer_slot` negatif berarti "cari slot kosong sendiri".
func _create_job(recipe_id: String, batches: int, mixer_slot: int, manual: bool) -> int:
	if batches <= 0:
		return 0
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return 0
	# Syarat resep terbuka + alat minimum + baker minimum (GDD 5.3).
	if not GameState.is_recipe_available(recipe_id):
		return 0

	if mixer_slot >= 0:
		if mixer_slot >= mixer_slot_count() or not _job_at(KIND_MIXER, mixer_slot).is_empty():
			return 0
	else:
		mixer_slot = _free_slot(KIND_MIXER)
	if mixer_slot < 0:
		return 0

	var costs: Dictionary = _scaled_costs(rec, batches)
	if costs.is_empty():
		return 0
	# Pengambilan bahan bersifat atomik: semua ada, atau tidak diambil sama sekali.
	if not GameState.pantry_take(costs):
		return 0

	# Catat nilai KR bahan yang terpakai memakai harga tetap IngredientDB (GDD 5.2.1).
	_book_ingredient_cost(float(IngredientDB.total_price(costs)))

	var speed: float = baker_speed()
	var job: Dictionary = {
		"id": _next_id,
		"recipe_id": recipe_id,
		"batches": batches,
		"stage": STAGE_MIXING,
		"slot_kind": KIND_MIXER,
		"slot_index": mixer_slot,
		"elapsed": 0.0,
		"duration": maxf(EquipmentDB.mixer_time(GameState.mixer_tier) / speed, MIN_DURATION),
		"overtime": 0.0,
		"quality": QUALITY_RAW,
		"started_hour": _hour,
		"remaining": maxi(0, int(rec.get("yield_count", 0))) * batches,
		"manual": manual,
	}
	var jid: int = int(job["id"])
	_next_id += 1
	_jobs.append(job)

	AudioBus.sfx("pop")
	EventBus.production_started.emit(job)
	return jid


## Apakah satu pesanan produksi bisa diterima saat ini (dipakai UI & StaffSim
## untuk menonaktifkan tombol tanpa benar-benar memotong bahan).
func can_queue(recipe_id: String, batches: int) -> bool:
	if batches <= 0:
		return false
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return false
	if not GameState.is_recipe_available(recipe_id):
		return false
	if _free_slot(KIND_MIXER) < 0:
		return false
	var costs: Dictionary = _scaled_costs(rec, batches)
	if costs.is_empty():
		return false
	for k: Variant in costs:
		if int(GameState.pantry.get(String(k), 0)) < int(costs[k]):
			return false
	return true


## Mengangkat loyang dari satu slot OVEN ke rak display.
## `slot_index` adalah indeks slot oven, karena roti yang siap diangkat selalu
## berada di oven (ARCHITECTURE 7.1: slot_kind job yang "ready" = "oven").
func collect(slot_index: int) -> void:
	var job: Dictionary = _job_at(KIND_OVEN, slot_index)
	if job.is_empty():
		return
	_collect(job)


## Varian collect() yang menunjuk job lewat id-nya; aman dari kerancuan indeks slot.
func collect_job(job_id: int) -> bool:
	var job: Dictionary = _job_by_id(job_id)
	if job.is_empty():
		return false
	return _collect(job)


## Mengangkat seluruh loyang yang sudah matang; mengembalikan jumlah roti yang
## benar-benar masuk rak display.
func collect_all() -> int:
	var moved: int = 0
	for e: Variant in _jobs.duplicate():
		var job: Dictionary = e
		var stage: String = String(job.get("stage", ""))
		if stage != STAGE_READY and stage != STAGE_BURNED:
			continue
		var before: int = int(job.get("remaining", 0))
		_collect(job)
		# Roti gosong dibuang, bukan dipindahkan ke rak, jadi tidak ikut dihitung.
		if stage == STAGE_READY:
			moved += maxi(0, before - int(job.get("remaining", 0)))
	return moved


## Job yang menempati satu slot alat; {} bila slot itu kosong.
## Dipakai lapisan tugas pemain untuk memastikan ia mengirim karakter ke alat
## yang benar-benar masih menganggur.
func job_at_slot(kind: String, slot_index: int) -> Dictionary:
	return _job_at(kind, slot_index)


## Satu job menurut id; {} bila sudah selesai atau tidak pernah ada.
## Dictionary yang dikembalikan adalah RUJUKAN HIDUP, jadi pemanggil bisa
## membaca kemajuan `elapsed` tanpa menanyakannya ulang tiap frame.
func job(job_id: int) -> Dictionary:
	return _job_by_id(job_id)


## Kemajuan satu job pada tahapnya saat ini, 0.0..1.0. 1.0 berarti tahap itu
## sudah rampung dan job sedang menunggu perintah berikutnya.
func progress(job_id: int) -> float:
	var j: Dictionary = _job_by_id(job_id)
	if j.is_empty():
		return 0.0
	var dur: float = float(j.get("duration", 0.0))
	if dur <= 0.0:
		return 1.0
	return clampf(float(j.get("elapsed", 0.0)) / dur, 0.0, 1.0)


## Apakah tahap ADUK satu job sudah rampung dan adonannya siap diangkat.
func mixing_done(job_id: int) -> bool:
	var j: Dictionary = _job_by_id(job_id)
	if j.is_empty():
		return false
	if String(j.get("stage", "")) != STAGE_MIXING:
		return false
	return float(j.get("elapsed", 0.0)) >= float(j.get("duration", 0.0))


## Apakah satu job sudah matang dan menunggu diangkat ke rak.
func baking_done(job_id: int) -> bool:
	var j: Dictionary = _job_by_id(job_id)
	if j.is_empty():
		return false
	var stage: String = String(j.get("stage", ""))
	return stage == STAGE_READY or stage == STAGE_BURNED


## Memindahkan adonan satu job manual dari mixer ke oven kosong.
##
## Mengembalikan indeks slot oven yang dipakai, atau -1 bila adonan belum siap
## atau seluruh oven masih terpakai. Penolakan sengaja senyap: pemain akan
## mencoba lagi, dan toast tiap ketukan hanya akan membanjiri layar.
func move_to_oven(job_id: int, oven_slot: int = -1) -> int:
	if not mixing_done(job_id):
		return -1
	var j: Dictionary = _job_by_id(job_id)
	if j.is_empty():
		return -1
	var slot: int = oven_slot
	if slot >= 0:
		if slot >= oven_slot_count() or not _job_at(KIND_OVEN, slot).is_empty():
			slot = -1
	else:
		slot = _free_slot(KIND_OVEN)
	if slot < 0:
		return -1
	_start_baking(j, slot)
	return slot


## Menata isi satu loyang ke SATU slot rak yang dipilih pemain.
##
## Mengembalikan jumlah roti yang benar-benar masuk. 0 berarti slot itu penuh,
## sudah berisi resep lain, atau rotinya keburu gosong.
func collect_to_slot(job_id: int, global_slot: int) -> int:
	var j: Dictionary = _job_by_id(job_id)
	if j.is_empty():
		return 0
	if String(j.get("stage", "")) != STAGE_READY:
		return 0
	var rid: String = String(j.get("recipe_id", ""))
	var sisa: int = int(j.get("remaining", 0))
	if sisa <= 0:
		_finish(j)
		return 0

	var quality: String = String(j.get("quality", QUALITY_PRIME))
	var masuk: int = GameState.display_add_at(rid, sisa, quality, _hour, global_slot)
	if masuk <= 0:
		return 0

	j["remaining"] = maxi(0, sisa - masuk)
	AudioBus.sfx("pop")
	if int(j.get("remaining", 0)) <= 0:
		_finish(j)
	return masuk


## Membatalkan job pada satu slot. Bahan yang sudah diaduk TIDAK dikembalikan ke
## gudang (adonan terlanjur tercampur), sehingga biaya bahan tetap tercatat.
## `slot_kind` boleh dikosongkan; bila kosong, slot oven diperiksa lebih dulu
## agar sama dengan acuan indeks pada collect(), lalu barulah slot mixer.
func cancel(slot_index: int, slot_kind: String = "") -> void:
	var job: Dictionary = {}
	if slot_kind == KIND_MIXER or slot_kind == KIND_OVEN:
		job = _job_at(slot_kind, slot_index)
	else:
		job = _job_at(KIND_OVEN, slot_index)
		if job.is_empty():
			job = _job_at(KIND_MIXER, slot_index)
	if job.is_empty():
		return
	cancel_job(int(job.get("id", -1)))


## Varian cancel() yang menunjuk job lewat id-nya.
func cancel_job(job_id: int) -> bool:
	var job: Dictionary = _job_by_id(job_id)
	if job.is_empty():
		return false
	_guarded.erase(int(job.get("id", -1)))
	job["remaining"] = 0
	job["stage"] = STAGE_COLLECTED
	_remove(job)
	EventBus.toast.emit("%s dibatalkan" % _recipe_name(String(job.get("recipe_id", ""))), "cross")
	return true


## Jumlah mixer yang benar-benar menyala (dipakai EconomySystem untuk tagihan
## utilitas). Adonan yang sudah selesai diaduk dan menunggu oven TIDAK dihitung:
## motor mixer sudah berhenti, hanya slotnya yang masih terpakai.
func busy_mixers() -> int:
	var n: int = 0
	for e: Variant in _jobs:
		var job: Dictionary = e
		if String(job.get("slot_kind", "")) != KIND_MIXER:
			continue
		if String(job.get("stage", "")) != STAGE_MIXING:
			continue
		if float(job.get("elapsed", 0.0)) >= float(job.get("duration", 0.0)):
			continue
		n += 1
	return n


## Jumlah oven yang menyala. Loyang matang yang belum diangkat tetap dihitung:
## oven masih panas, dan justru panas itulah yang membuat roti gosong (GDD 2).
func busy_ovens() -> int:
	var n: int = 0
	for e: Variant in _jobs:
		var job: Dictionary = e
		if String(job.get("slot_kind", "")) != KIND_OVEN:
			continue
		var stage: String = String(job.get("stage", ""))
		if stage != STAGE_BAKING and stage != STAGE_READY and stage != STAGE_BURNED:
			continue
		n += 1
	return n


## Seluruh job yang sedang berjalan. Array-nya salinan (aman diubah pemanggil),
## sedangkan Dictionary job-nya tetap rujukan hidup agar HUD bisa membaca
## kemajuan `elapsed`/`overtime` secara langsung.
func jobs() -> Array:
	return _jobs.duplicate()


## Jumlah slot mixer yang masih kosong.
func free_mixer_slots() -> int:
	return maxi(0, mixer_slot_count() - _occupied(KIND_MIXER))


## Jumlah slot oven yang masih kosong.
func free_oven_slots() -> int:
	return maxi(0, oven_slot_count() - _occupied(KIND_OVEN))


## Jumlah slot mixer milik lokasi saat ini (LocationDB).
func mixer_slot_count() -> int:
	var loc: Dictionary = LocationDB.entry(GameState.location_tier)
	return maxi(0, int(loc.get("mixer_slots", 0)))


## Jumlah slot oven milik lokasi saat ini (LocationDB).
func oven_slot_count() -> int:
	var loc: Dictionary = LocationDB.entry(GameState.location_tier)
	return maxi(0, int(loc.get("oven_slots", 0)))


## Indeks slot oven yang berisi roti siap diangkat (dipakai HUD & StaffSim).
func ready_slots() -> Array:
	var out: Array = []
	for e: Variant in _jobs:
		var job: Dictionary = e
		if String(job.get("stage", "")) != STAGE_READY:
			continue
		out.append(int(job.get("slot_index", -1)))
	return out


## Nilai KR bahan yang sudah terpakai produksi hari ini (dibaca EconomySystem).
## Angka yang sama juga sudah ditambahkan ke GameState.stats.spent_ingredients,
## jadi EconomySystem cukup memakai salah satunya -- jangan dijumlahkan dua kali.
func ingredients_spent_today() -> float:
	return _spent_today


## Pengali kecepatan kerja baker aktif terbaik (GDD 3.2). 1.0 bila tidak ada baker.
func baker_speed() -> float:
	var b: Dictionary = GameState.best_staff(ROLE_BAKER)
	if b.is_empty():
		return DEFAULT_BAKER_SPEED
	var db: Dictionary = StaffDB.entry(String(b.get("staff_id", "")))
	var s: float = DEFAULT_BAKER_SPEED
	if db.has("speed"):
		s = float(db["speed"])
	else:
		s = StaffDB.speed_for(ROLE_BAKER, int(b.get("tier", 1)))
	if s <= 0.0:
		return DEFAULT_BAKER_SPEED
	return s


## Peluang Proteksi Roti Gosong (Auto-Retrieve) baker aktif terbaik, 0.0..1.0 (GDD 3.2).
func baker_anti_burn() -> float:
	var b: Dictionary = GameState.best_staff(ROLE_BAKER)
	if b.is_empty():
		return 0.0
	var db: Dictionary = StaffDB.entry(String(b.get("staff_id", "")))
	if db.has("extra") and typeof(db["extra"]) == TYPE_DICTIONARY:
		var ex: Dictionary = db["extra"]
		if ex.has("anti_burn"):
			return clampf(float(ex["anti_burn"]), 0.0, 1.0)
	return clampf(StaffDB.anti_burn(int(b.get("tier", 1))), 0.0, 1.0)


## Rujukan ke node Main (diisi setup()).
func host() -> Node:
	return _main


# ===========================================================================
# Tahapan produksi
# ===========================================================================

# Mengaduk adonan di mixer. Bila sudah selesai, adonan menunggu oven kosong
# tanpa memajukan apa pun (tahap 2 sim_tick yang memindahkannya).
func _advance_mixing(job: Dictionary, delta: float) -> void:
	var dur: float = float(job.get("duration", 0.0))
	var el: float = float(job.get("elapsed", 0.0))
	if el >= dur:
		return
	job["elapsed"] = minf(el + delta, dur)


# Memanggang di oven. Saat matang, roti menjadi "prima" lalu didengungkan oven.
func _advance_baking(job: Dictionary, delta: float) -> void:
	var dur: float = float(job.get("duration", 0.0))
	var el: float = float(job.get("elapsed", 0.0)) + delta
	if el < dur:
		job["elapsed"] = el
		return

	job["elapsed"] = dur
	job["stage"] = STAGE_READY
	job["quality"] = QUALITY_PRIME
	# Kelebihan waktu pada tick ini langsung dihitung sebagai waktu menganggur.
	job["overtime"] = maxf(0.0, el - dur)

	AudioBus.sfx("ting")

	# GDD 3.2 -- Proteksi Roti Gosong: baker terbaik berpeluang mengangkat sendiri.
	if _roll_anti_burn():
		_guarded[int(job.get("id", -1))] = true
		EventBus.toast.emit(
			"%s menata %s ke rak" % [_baker_name(), _recipe_name(String(job.get("recipe_id", "")))],
			"chef"
		)
		_collect(job)
		return

	EventBus.toast.emit("%s matang, segera angkat!" % _recipe_name(String(job.get("recipe_id", ""))), "bread")


# Roti matang menganggur di oven panas: makin lama makin gosong (GDD 2).
func _advance_ready(job: Dictionary, delta: float) -> void:
	var dur: float = maxf(float(job.get("duration", 0.0)), MIN_DURATION)
	var ot: float = float(job.get("overtime", 0.0)) + delta
	job["overtime"] = ot

	var ratio: float = ot / dur
	if ratio > GameConfig.BURN_GRACE_RATIO * BURN_RUIN_MULT:
		_burn(job)
		return
	if ratio > GameConfig.BURN_GRACE_RATIO and String(job.get("quality", "")) != QUALITY_ALMOST_BURNT:
		job["quality"] = QUALITY_ALMOST_BURNT
		EventBus.toast.emit("%s mulai hangus!" % _recipe_name(String(job.get("recipe_id", ""))), "fire")

	# Baker yang menjaga loyang mencoba lagi bila tadi rak display sempat penuh.
	if _guarded.has(int(job.get("id", -1))):
		_collect(job)


# Memindahkan adonan matang-aduk ke oven kosong dan mulai memanggang.
func _start_baking(job: Dictionary, oven_slot: int) -> void:
	var speed: float = baker_speed()
	job["stage"] = STAGE_BAKING
	job["slot_kind"] = KIND_OVEN
	job["slot_index"] = oven_slot
	job["elapsed"] = 0.0
	job["duration"] = maxf(EquipmentDB.oven_time(GameState.oven_tier) / speed, MIN_DURATION)
	job["overtime"] = 0.0
	job["quality"] = QUALITY_RAW
	# ARCHITECTURE 5: production_started = "satu batch masuk ke mixer / oven",
	# jadi sinyal ini dikirim lagi saat loyang masuk oven (id job tetap sama).
	EventBus.production_started.emit(job)


# Menangani satu loyang yang diangkat: gosong dibuang, matang masuk rak.
func _collect(job: Dictionary) -> bool:
	var stage: String = String(job.get("stage", ""))
	if stage == STAGE_BURNED:
		_burn(job)
		return true
	if stage != STAGE_READY:
		return false
	return _place(job)


# Menaruh isi loyang ke rak display. Bila rak penuh, yang muat saja yang masuk
# dan sisanya tetap menunggu di loyang (dan tetap bisa gosong).
func _place(job: Dictionary) -> bool:
	var rid: String = String(job.get("recipe_id", ""))
	var count: int = int(job.get("remaining", 0))
	if count <= 0:
		_finish(job)
		return true

	var quality: String = String(job.get("quality", QUALITY_PRIME))
	var placed: int = GameState.display_add(rid, count, quality, _hour)
	var left: int = maxi(0, count - placed)
	job["remaining"] = left

	if placed > 0:
		AudioBus.sfx("pop")
	if left > 0:
		# Hanya dikabarkan saat ada roti yang benar-benar berpindah, supaya
		# percobaan ulang baker tiap tick tidak membanjiri layar dengan toast.
		if placed > 0:
			EventBus.toast.emit("Rak penuh, %d %s menunggu di loyang" % [left, _recipe_name(rid)], "warning")
		return false

	_finish(job)
	return true


# Job selesai: slot dibebaskan dan UI dikabari lewat production_finished.
func _finish(job: Dictionary) -> void:
	job["stage"] = STAGE_COLLECTED
	_guarded.erase(int(job.get("id", -1)))
	EventBus.production_finished.emit(job)
	_remove(job)


# Roti gosong: dibuang, dicatat ke statistik harian, dan slot oven dibebaskan
# agar dapur tidak macet (GDD: tidak ada kondisi kalah, permainan harus jalan terus).
func _burn(job: Dictionary) -> void:
	job["stage"] = STAGE_BURNED
	job["quality"] = QUALITY_BURNT
	var count: int = int(job.get("remaining", 0))
	var rid: String = String(job.get("recipe_id", ""))
	if count > 0:
		GameState.stats["burned"] = int(GameState.stats.get("burned", 0)) + count
		EventBus.bread_burned.emit(rid, count)
		EventBus.toast.emit("%d %s gosong terbuang" % [count, _recipe_name(rid)], "fire")
	job["remaining"] = 0
	_guarded.erase(int(job.get("id", -1)))
	_remove(job)


# ===========================================================================
# Pembantu internal
# ===========================================================================

# Kebutuhan bahan satu pesanan = takaran resep x jumlah batch (GDD 2: bahan
# otomatis dikalikan saat pemain memilih jumlah roti).
func _scaled_costs(rec: Dictionary, batches: int) -> Dictionary:
	var out: Dictionary = {}
	var raw: Variant = rec.get("ingredients", {})
	if typeof(raw) != TYPE_DICTIONARY:
		return out
	var need: Dictionary = raw
	for k: Variant in need:
		var qty: int = int(need[k]) * batches
		if qty > 0:
			out[String(k)] = qty
	return out


# Mencatat biaya bahan terpakai ke akumulator harian dan ke GameState.stats.
# Bahan sudah dibayar saat belanja di Pasar, jadi TIDAK ada pemotongan koin di sini.
func _book_ingredient_cost(value: float) -> void:
	if value <= 0.0:
		return
	_spent_today += value
	var prev: float = float(GameState.stats.get("spent_ingredients", 0.0))
	GameState.stats["spent_ingredients"] = prev + value


# Undian Proteksi Roti Gosong. Undian selalu dilakukan agar urutan angka acak
# tidak bergantung pada tier baker; Tier 5 (1.00) dijamin selalu berhasil.
func _roll_anti_burn() -> bool:
	var chance: float = baker_anti_burn()
	var roll: float = GameConfig.rng.randf()
	if chance >= 1.0:
		return true
	return roll < chance


# Indeks slot kosong pertama untuk satu jenis alat; -1 bila penuh.
func _free_slot(kind: String) -> int:
	var total: int = mixer_slot_count() if kind == KIND_MIXER else oven_slot_count()
	if total <= 0:
		return -1
	var used: Dictionary = {}
	for e: Variant in _jobs:
		var job: Dictionary = e
		if String(job.get("slot_kind", "")) == kind:
			used[int(job.get("slot_index", -1))] = true
	for i: int in range(total):
		if not used.has(i):
			return i
	return -1


# Jumlah slot satu jenis alat yang sedang terpakai job mana pun.
func _occupied(kind: String) -> int:
	var n: int = 0
	for e: Variant in _jobs:
		var job: Dictionary = e
		if String(job.get("slot_kind", "")) == kind:
			n += 1
	return n


# Job yang menempati satu slot; {} bila slot kosong.
func _job_at(kind: String, slot_index: int) -> Dictionary:
	for e: Variant in _jobs:
		var job: Dictionary = e
		if String(job.get("slot_kind", "")) != kind:
			continue
		if int(job.get("slot_index", -1)) == slot_index:
			return job
	return {}


# Job menurut id; {} bila tidak ada.
func _job_by_id(job_id: int) -> Dictionary:
	for e: Variant in _jobs:
		var job: Dictionary = e
		if int(job.get("id", -1)) == job_id:
			return job
	return {}


# Membuang job dari daftar aktif berdasarkan id (bukan perbandingan Dictionary).
func _remove(job: Dictionary) -> void:
	var jid: int = int(job.get("id", -1))
	for i: int in range(_jobs.size() - 1, -1, -1):
		var cur: Dictionary = _jobs[i]
		if int(cur.get("id", -2)) == jid:
			_jobs.remove_at(i)


# Nama resep untuk teks pemberitahuan; id mentah bila resep tidak dikenal.
func _recipe_name(recipe_id: String) -> String:
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return recipe_id
	return String(rec.get("name", recipe_id))


# Nama baker aktif terbaik untuk teks pemberitahuan.
func _baker_name() -> String:
	var b: Dictionary = GameState.best_staff(ROLE_BAKER)
	if b.is_empty():
		return "Baker"
	var db: Dictionary = StaffDB.entry(String(b.get("staff_id", "")))
	if db.is_empty():
		return "Baker"
	return String(db.get("name", "Baker"))
