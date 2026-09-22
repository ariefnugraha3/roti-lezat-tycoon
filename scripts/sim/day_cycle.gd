class_name DayCycle
extends Node

## DayCycle — pengatur ritme tiga tahap harian (GDD Seksi 2).
##
## Kelas ini adalah SATU-SATUNYA sistem yang memajukan jam in-game. Sistem lain
## hanya membaca jam lewat parameter sim_tick() atau lewat Main.systems["day"].
##
## Sesuai ARCHITECTURE 7.0 kelas ini TIDAK memakai _process/_physics_process.
## Main yang menjalankan loop dan memanggil sim_tick(delta, hour) dengan urutan
## tetap: weather -> mkt -> day -> prod -> staff -> cust -> deliv -> econ -> rep
## -> bailout. Berkat itu simulasi bisa dijalankan headless dan diulang persis.
##
## Tiga tahap harian (GDD Seksi 2):
##   05:00-08:00  "prep"   Tahap Persiapan — pemain membakar stok pagi.
##   08:00-18:00  "sell"   Tahap Jualan — toko buka OTOMATIS pukul 08:00 meski
##                         masih ada roti yang belum selesai dipanggang.
##   18:00        "close"  Tahap Tutup — pintu terkunci, Daily Summary (GDD 11.6).

# Batas aman pengali kecepatan untuk tombol fast-forward. GDD tidak menyebut
# angka percepatan mana pun, jadi nilai di bawah murni kenyamanan kontrol —
# bukan angka balans ekonomi.
const TIME_SCALE_MIN: float = 0.25
const TIME_SCALE_MAX: float = 8.0
const TIME_SCALE_NORMAL: float = 1.0
const TIME_SCALE_FAST: float = 2.0

## Urutan pemanggilan on_day_start() saat fajar (ARCHITECTURE 7.0).
## "day" sengaja tidak ikut: start_day() sudah menyiapkan dirinya sendiri.
const DAY_START_ORDER: Array[String] = [
	"weather", "mkt", "prod", "staff", "cust", "deliv", "econ", "rep", "bailout",
]

## Tutup buku pukul 18:00 dipecah empat tahap agar angkanya benar:
## 1) sistem penghasil angka menutup catatannya (DAY_END_BEFORE),
## 2) EconomySystem.settle_day() memotong utilitas + gaji dari kas,
## 3) reputasi & bailout bereaksi terhadap saldo akhir (DAY_END_AFTER),
## 4) EconomySystem.on_day_end() menyusun dan menyiarkan ledger lengkap.
const DAY_END_BEFORE: Array[String] = ["weather", "mkt", "prod", "staff", "cust", "deliv"]
const DAY_END_AFTER: Array[String] = ["rep", "bailout"]

## Jam in-game berjalan, 5.0 = 05:00. Hanya kelas ini yang boleh mengubahnya.
var hour: float = GameConfig.HOUR_START

## Fase hari kanonik: "prep" | "sell" | "close" (ARCHITECTURE 2.5).
var phase: String = GameConfig.PHASE_PREP

## Pengali kecepatan waktu untuk tombol fast-forward di HUD.
var time_scale: float = TIME_SCALE_NORMAL

var _main: Node = null
var _paused: bool = false
var _day_ended: bool = false


# --- Antarmuka sistem simulasi (ARCHITECTURE 7.0) --------------------------

func setup(main: Node) -> void:
	_main = main


## Memajukan jam in-game. Parameter [param _hour_in] sengaja diabaikan: nilai
## itu berasal dari kelas ini sendiri, sehingga jam tidak pernah maju ganda.
func sim_tick(delta: float, _hour_in: float) -> void:
	if _paused or delta <= 0.0:
		return
	if phase == GameConfig.PHASE_CLOSE:
		return
	if GameConfig.SECONDS_PER_GAME_HOUR <= 0.0:
		return

	hour += delta * time_scale / GameConfig.SECONDS_PER_GAME_HOUR

	# GDD Seksi 2: tepat pukul 08:00 toko otomatis buka, tidak peduli apakah
	# adonan di oven sudah matang atau belum.
	if phase == GameConfig.PHASE_PREP and hour >= GameConfig.HOUR_OPEN:
		_set_phase(GameConfig.PHASE_SELL)
		AudioBus.sfx("door")

	# GDD 11.6: pukul 18:00 pintu toko tertutup otomatis.
	if hour >= GameConfig.HOUR_CLOSE:
		hour = GameConfig.HOUR_CLOSE
		EventBus.clock_tick.emit(hour)
		end_day()
		return

	EventBus.clock_tick.emit(hour)


## Dipanggil Main (atau start_day()) saat hari baru dimulai pukul 05:00.
func on_day_start(_day: int) -> void:
	hour = GameConfig.HOUR_START
	_day_ended = false
	_paused = false
	_set_phase(GameConfig.PHASE_PREP)


## DayCycle tidak menulis angka apa pun ke ledger; ia hanya memastikan jam dan
## fase sudah terkunci di posisi tutup toko.
func on_day_end(_ledger: Dictionary) -> void:
	hour = GameConfig.HOUR_CLOSE
	_day_ended = true
	_set_phase(GameConfig.PHASE_CLOSE)


## Kembali ke kondisi awal (permainan baru / memuat berkas simpanan).
func reset() -> void:
	hour = GameConfig.HOUR_START
	phase = GameConfig.PHASE_PREP
	time_scale = TIME_SCALE_NORMAL
	_paused = false
	_day_ended = false


# --- Kendali hari ----------------------------------------------------------

## Membuka hari baru pada pukul 05:00 (Tahap Persiapan).
func start_day() -> void:
	# DayCycle adalah pemilik tunggal penghitung hari. Hari baru hanya dinaikkan
	# bila hari sebelumnya memang sudah ditutup, sehingga start_day() pertama
	# setelah new_game()/load tetap berada di hari yang sama.
	if _day_ended:
		GameState.day += 1

	hour = GameConfig.HOUR_START
	phase = GameConfig.PHASE_PREP
	_paused = false
	_day_ended = false

	_dispatch_day_start()

	EventBus.day_started.emit(GameState.day)
	EventBus.phase_changed.emit(phase)
	EventBus.clock_tick.emit(hour)


## Menutup toko pukul 18:00 dan memicu penyusunan ledger harian.
## Bersifat idempoten: pemanggilan kedua pada hari yang sama tidak menghasilkan
## ledger kedua (lihat juga penjaga per-hari di EconomySystem).
func end_day() -> void:
	if _day_ended:
		return
	_day_ended = true
	hour = GameConfig.HOUR_CLOSE
	_set_phase(GameConfig.PHASE_CLOSE)
	# GDD Seksi 11: pintu toko tertutup dengan bunyi "klik" yang memuaskan.
	AudioBus.sfx("door")
	_dispatch_day_end()


## Menjeda/melanjutkan waktu. Saat dijeda, jam dan seluruh biaya utilitas ikut
## berhenti (EconomySystem membaca is_paused()).
func set_paused(b: bool) -> void:
	_paused = b


func is_paused() -> bool:
	return _paused


func toggle_paused() -> void:
	_paused = not _paused


## Mengatur pengali kecepatan tombol fast-forward, dijaga pada rentang aman.
func set_time_scale(v: float) -> void:
	time_scale = clampf(v, TIME_SCALE_MIN, TIME_SCALE_MAX)


## Bergantian antara kecepatan normal dan kecepatan cepat.
func toggle_fast_forward() -> void:
	if is_equal_approx(time_scale, TIME_SCALE_NORMAL):
		set_time_scale(TIME_SCALE_FAST)
	else:
		set_time_scale(TIME_SCALE_NORMAL)


## Delta detik nyata yang sudah dikali pengali kecepatan; 0.0 saat dijeda.
## Main memakai ini untuk memberi makan sistem selain DayCycle agar seluruh
## simulasi ikut dipercepat oleh tombol fast-forward.
func effective_delta(raw_delta: float) -> float:
	if _paused or raw_delta <= 0.0:
		return 0.0
	return raw_delta * time_scale


# --- Pembacaan status ------------------------------------------------------

## Toko sedang melayani pembeli (Tahap Jualan).
func is_open() -> bool:
	return phase == GameConfig.PHASE_SELL


## Toko sudah tutup untuk hari ini.
func is_closed() -> bool:
	return phase == GameConfig.PHASE_CLOSE


## Sisa jam in-game sampai pukul 18:00; 0.0 bila sudah tutup.
func hours_left() -> float:
	return maxf(0.0, GameConfig.HOUR_CLOSE - hour)


## Kemajuan hari 0.0 (05:00) sampai 1.0 (18:00) untuk bilah jam di HUD.
func day_progress() -> float:
	var span: float = GameConfig.HOUR_CLOSE - GameConfig.HOUR_START
	if span <= 0.0:
		return 1.0
	return clampf((hour - GameConfig.HOUR_START) / span, 0.0, 1.0)


## Jam dinding siap tampil, mis. "08:30".
func clock_text() -> String:
	return GameConfig.clock(hour)


# --- Pembantu internal -----------------------------------------------------

func _set_phase(p: String) -> void:
	if phase == p:
		return
	phase = p
	EventBus.phase_changed.emit(phase)


## Kumpulan sistem simulasi milik Main; {} bila Main belum memilikinya.
func _systems() -> Dictionary:
	if _main == null or not is_instance_valid(_main):
		return {}
	var v: Variant = _main.get("systems")
	if typeof(v) == TYPE_DICTIONARY:
		return v
	return {}


func _system_from(systems: Dictionary, key: String) -> Node:
	if not systems.has(key):
		return null
	var v: Variant = systems[key]
	if v is Node and is_instance_valid(v):
		return v as Node
	return null


## Membagikan on_day_start() ke seluruh sistem. Bila Main menyediakan
## run_day_start(), urusan itu diserahkan sepenuhnya kepada Main agar tidak ada
## sistem yang disiapkan dua kali.
func _dispatch_day_start() -> void:
	if _main != null and is_instance_valid(_main) and _main.has_method("run_day_start"):
		_main.call("run_day_start", GameState.day)
		return
	var systems: Dictionary = _systems()
	for key: String in DAY_START_ORDER:
		var n: Node = _system_from(systems, key)
		if n != null and n.has_method("on_day_start"):
			n.call("on_day_start", GameState.day)


## Membagikan on_day_end() sesuai urutan tutup buku. Bila Main menyediakan
## run_day_end(), urusan itu diserahkan sepenuhnya kepada Main.
func _dispatch_day_end() -> void:
	if _main != null and is_instance_valid(_main) and _main.has_method("run_day_end"):
		_main.call("run_day_end")
		return

	var systems: Dictionary = _systems()
	var ledger: Dictionary = {}

	for key: String in DAY_END_BEFORE:
		_call_day_end(systems, key, ledger)

	# EconomySystem memotong utilitas dan gaji lebih dulu supaya BailoutSystem
	# menilai saldo yang sudah final (GDD 3.0.E).
	var econ: Node = _system_from(systems, "econ")
	if econ != null and econ.has_method("settle_day"):
		econ.call("settle_day")

	for key2: String in DAY_END_AFTER:
		_call_day_end(systems, key2, ledger)

	if econ == null:
		push_warning("DayCycle: EconomySystem tidak terpasang, ledger harian tidak dapat disusun.")
		return
	_call_day_end(systems, "econ", ledger)


func _call_day_end(systems: Dictionary, key: String, ledger: Dictionary) -> void:
	var n: Node = _system_from(systems, key)
	if n == null or not n.has_method("on_day_end"):
		return
	n.call("on_day_end", ledger)
