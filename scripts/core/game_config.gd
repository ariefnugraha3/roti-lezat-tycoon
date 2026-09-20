extends Node
## GameConfig -- konstanta global & utilitas format untuk "Roti Lezat Tycoon".
##
## Skrip ini didaftarkan sebagai autoload bernama "GameConfig" di project.godot,
## sehingga TIDAK memakai "class_name": nama kelas global akan bentrok dengan
## nama singleton autoload pada Godot 4.
##
## Sumber angka: docs/gdd-roti-lezaat-tycoon.md + docs/ARCHITECTURE.md Seksi 4.

# ---------------------------------------------------------------------------
# Ritme waktu harian (GDD Seksi 2 -- Core Gameplay Loop)
# ---------------------------------------------------------------------------

## 1 jam in-game = 30 detik nyata -> satu hari 04:00-18:00 = 7 menit nyata.
const SECONDS_PER_GAME_HOUR: float = 30.0

## Tahap Persiapan dimulai pukul 04:00.
const HOUR_START: float = 4.0

## Tahap Jualan dimulai pukul 08:00 (toko buka otomatis meski roti belum siap).
const HOUR_OPEN: float = 8.0

## Tahap Tutup pukul 18:00 -> layar Daily Summary muncul.
const HOUR_CLOSE: float = 18.0

# ---------------------------------------------------------------------------
# Fase hari -- ID kanonik (ARCHITECTURE Seksi 2.5)
# ---------------------------------------------------------------------------

const PHASE_PREP: String = "prep"
const PHASE_SELL: String = "sell"
const PHASE_CLOSE: String = "close"

# ---------------------------------------------------------------------------
# Etalase & ekonomi dasar
# ---------------------------------------------------------------------------

## Jumlah slot penataan roti pada satu rak display.
const SLOTS_PER_RACK: int = 6

## Saldo awal permainan baru.
const STARTING_COINS: float = 2000.0

## GDD 3.0.B -- Koin Roti Subsidi dari Pak Lurah saat bailout.
const BAILOUT_COINS: float = 650.0

## GDD 3.0.C -- Mode Solo aktif selama saldo berada di kisaran 0-500 KR.
const SOLO_MODE_MAX_COINS: float = 500.0

# ---------------------------------------------------------------------------
# Biaya utilitas real-time (KR per detik alat aktif) -- GDD "Utility Cost"
# ---------------------------------------------------------------------------

const UTILITY_MIXER_PER_SEC: float = 0.8
const UTILITY_OVEN_PER_SEC: float = 1.6
const UTILITY_DISPLAY_PER_SEC: float = 0.25

# ---------------------------------------------------------------------------
# Pemanggangan
# ---------------------------------------------------------------------------

## Roti mulai gosong setelah 35% waktu panggang terlewat tanpa diangkat.
const BURN_GRACE_RATIO: float = 0.35

# ---------------------------------------------------------------------------
# Tampilan (GDD 12.5 -- landscape, resolusi referensi 1280x720)
# ---------------------------------------------------------------------------

const REF_RESOLUTION: Vector2i = Vector2i(1280, 720)

# ---------------------------------------------------------------------------
# Kalender in-game
# ---------------------------------------------------------------------------

## Hari ke-1 selalu jatuh pada hari Senin.
const DAY_NAMES := ["Senin", "Selasa", "Rabu", "Kamis", "Jumat", "Sabtu", "Minggu"]

const MONTH_NAMES := [
	"Januari", "Februari", "Maret", "April", "Mei", "Juni",
	"Juli", "Agustus", "September", "Oktober", "November", "Desember",
]

## Senin, 5 Januari 2026 pukul 00:00 UTC -- tanggal in-game untuk hari ke-1.
## (GDD Seksi 1: latar waktu game adalah tahun modern 2026.)
const EPOCH_UNIX: int = 1767571200

const SECONDS_PER_DAY: int = 86400

# ---------------------------------------------------------------------------
# Sumber acak tunggal
# ---------------------------------------------------------------------------

## Satu-satunya sumber angka acak di seluruh game. Jangan memakai randf()/randi() global.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	rng.randomize()


## Mengunci urutan acak pada benih tertentu (dipakai oleh tools/sim_test.gd).
func seed_rng(s: int) -> void:
	rng.seed = s


# ---------------------------------------------------------------------------
# Utilitas format
# ---------------------------------------------------------------------------

## Memformat nilai Koin Roti: 1234.0 -> "1.234 KR", -1234.0 -> "-1.234 KR".
## Pemisah ribuan memakai titik sesuai gaya penulisan angka pada GDD.
func kr(v: float) -> String:
	var rounded: int = int(round(v))
	var negative: bool = rounded < 0
	var digits: String = str(absi(rounded))
	var grouped: String = ""
	var count: int = 0
	for i: int in range(digits.length() - 1, -1, -1):
		grouped = digits[i] + grouped
		count += 1
		if count % 3 == 0 and i > 0:
			grouped = "." + grouped
	if negative:
		grouped = "-" + grouped
	return grouped + " KR"


## Memformat jam in-game menjadi jam dinding 24 jam: 8.5 -> "08:30".
func clock(hour: float) -> String:
	var total_minutes: int = posmod(int(round(hour * 60.0)), 1440)
	var h: int = floori(float(total_minutes) / 60.0)
	var m: int = total_minutes % 60
	return "%02d:%02d" % [h, m]


## Nama hari dalam bahasa Indonesia; hari ke-1 = Senin, lalu berputar Senin..Minggu.
func day_name(day: int) -> String:
	return str(DAY_NAMES[posmod(day - 1, 7)])


## Label tanggal lengkap untuk Daily Summary, mis. "Senin, 5 Januari 2026".
func date_label(day: int) -> String:
	var unix_time: int = EPOCH_UNIX + (day - 1) * SECONDS_PER_DAY
	var d: Dictionary = Time.get_datetime_dict_from_unix_time(unix_time)
	var dd: int = int(d.get("day", 1))
	var mm: int = int(d.get("month", 1))
	var yy: int = int(d.get("year", 2026))
	var month_text: String = str(MONTH_NAMES[clampi(mm - 1, 0, 11)])
	return "%s, %d %s %d" % [day_name(day), dd, month_text, yy]
