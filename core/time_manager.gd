class_name TimeManager
extends SimManager
## TimeManager — pemilik jam, hari, fase, dan kecepatan (GDD 15, 71, 98, 99.1).
##
## 1 detik-simulasi = `clock.ingame_seconds_per_sim_second` detik jam in-game
## (balance.json, GDD 15.2).
## Jam hanya maju pada fase PREPARATION dan OPEN. Pause (PauseManager) dan modal
## keputusan menghentikan seluruh simulasi, termasuk jam.

const PREPARATION: StringName = &"preparation"
const OPEN: StringName = &"open"
const CLOSING: StringName = &"closing"
const SUMMARY: StringName = &"summary"
const AFTER_HOURS: StringName = &"after_hours"
const TRANSITION: StringName = &"transition"

var day: int = 1
var time_seconds: float = 0.0
var phase: StringName = PREPARATION
var speed: int = 1
## Detik-simulasi kumulatif sejak profil dibuat; dasar semua timer relatif.
var sim_seconds: float = 0.0

var day_start: float = 18000.0
var open_time: float = 28800.0
var close_time: float = 64800.0
var ratio: float = 30.0
var _last_emitted_minute: int = -1


func setup(s: SimulationRoot) -> void:
	super.setup(s)
	day_start = DataRegistry.balf("clock.day_start_seconds")
	open_time = DataRegistry.balf("clock.open_seconds")
	close_time = DataRegistry.balf("clock.close_seconds")
	ratio = DataRegistry.balf("clock.ingame_seconds_per_sim_second")


func new_game() -> void:
	day = 1
	time_seconds = day_start
	phase = PREPARATION
	speed = 1
	sim_seconds = 0.0


func is_running_phase() -> bool:
	return phase == PREPARATION or phase == OPEN


func is_open() -> bool:
	return phase == OPEN


func is_after_hours() -> bool:
	return phase == SUMMARY or phase == AFTER_HOURS or phase == CLOSING


## Jam in-game yang setara dengan `sim_dt` detik-simulasi.
func ingame_hours(sim_dt: float) -> float:
	return sim_dt * ratio / 3600.0


## Detik-simulasi untuk durasi jam in-game.
func sim_seconds_for_hours(hours: float) -> float:
	return hours * 3600.0 / ratio


## Hari dalam minggu: 0 = Monday (Hari 1 = Monday, GDD 26.5).
func weekday(for_day: int = -1) -> int:
	var d: int = day if for_day < 0 else for_day
	return posmod(d - 1, 7)


## Satu tick: majukan jam, lalu laporkan batas 08:00 dan 18:00 (P1, GDD 102).
## Mengembalikan &"close" bila tick ini menyentuh 18:00.
func advance(dt: float) -> StringName:
	if not is_running_phase():
		return &""
	sim_seconds += dt
	var before: float = time_seconds
	time_seconds += dt * ratio
	var result: StringName = &""
	if phase == PREPARATION and before < open_time and time_seconds >= open_time:
		phase = OPEN
		EventBus.phase_changed.emit(phase)
		EventBus.shop_opened.emit(day)
	if time_seconds >= close_time:
		time_seconds = close_time
		phase = CLOSING
		EventBus.phase_changed.emit(phase)
		result = &"close"
	var minute: int = int(time_seconds / 60.0)
	if minute != _last_emitted_minute:
		_last_emitted_minute = minute
		EventBus.time_changed.emit(day, time_seconds)
	return result


func set_phase(p: StringName) -> void:
	if phase == p:
		return
	phase = p
	EventBus.phase_changed.emit(phase)


## Mulai hari berikutnya pukul 05:00 (dipanggil transisi malam).
func begin_next_day() -> void:
	day += 1
	time_seconds = day_start
	phase = PREPARATION
	EventBus.phase_changed.emit(phase)
	EventBus.time_changed.emit(day, time_seconds)


func set_speed(s: int) -> void:
	# Angka JSON selalu float; Array.has membandingkan tipe secara ketat.
	var ok: bool = false
	for a: Variant in DataRegistry.bal("clock.speeds"):
		if int(a) == s:
			ok = true
	if not ok:
		return
	if speed == s:
		return
	speed = s
	EventBus.speed_changed.emit(speed)


## Smart Speed Safety (GDD 71.1): turun ke 1× bila setting aktif.
func smart_slowdown(reason_key: String) -> void:
	if speed <= 1 or not SettingsManager.get_bool("smart_speed"):
		return
	set_speed(1)
	EventBus.notify.emit(2, reason_key, {}, &"clock")


func capture() -> Dictionary:
	return {"day": day, "time_seconds": time_seconds, "phase": String(phase), "speed": speed, "sim_seconds": sim_seconds}


func restore(d: Dictionary) -> void:
	day = int(d.get("day", 1))
	time_seconds = float(d.get("time_seconds", day_start))
	phase = StringName(str(d.get("phase", "preparation")))
	speed = clampi(int(d.get("speed", 1)), 1, 3)
	sim_seconds = float(d.get("sim_seconds", 0.0))
