class_name TimeManager
extends SimManager
## TimeManager — pemilik jam dan nomor hari (GDD idle 3.1, v3.1 15.2, 99.1).
##
## Jam berjalan terus 24 jam: tidak ada fase hari, Skip to Open, Close Early,
## atau tombol kecepatan. 1 detik-simulasi = `clock.ingame_seconds_per_sim_second`
## detik jam in-game (balance.json), dan satu detik nyata memajukan
## `clock.sim_seconds_per_real_second` detik-simulasi (SimulationRoot.advance),
## jadi 1 menit in-game = 1 detik nyata. Hari bertambah tepat pukul 00:00.
## Pause (PauseManager) menghentikan seluruh simulasi, termasuk jam.

const DAY_SECONDS: float = 86400.0

var day: int = 1
## Detik jam sejak 00:00 hari ini (0 <= t < 86400).
var time_seconds: float = 0.0
## Detik-simulasi kumulatif sejak profil dibuat; dasar semua timer relatif.
var sim_seconds: float = 0.0

var ratio: float = 30.0
var _night_from: float = 79200.0
var _night_to: float = 21600.0
var _last_emitted_minute: int = -1


func setup(s: SimulationRoot) -> void:
	super.setup(s)
	ratio = DataRegistry.balf("clock.ingame_seconds_per_sim_second")
	_night_from = DataRegistry.idlef("night.from_hour") * 3600.0
	_night_to = DataRegistry.idlef("night.to_hour") * 3600.0


func new_game() -> void:
	day = 1
	time_seconds = DataRegistry.idlef("clock.start_seconds")
	sim_seconds = 0.0


## Jam in-game yang setara dengan `sim_dt` detik-simulasi.
func ingame_hours(sim_dt: float) -> float:
	return sim_dt * ratio / 3600.0


## Detik-simulasi untuk durasi jam in-game.
func sim_seconds_for_hours(hours: float) -> float:
	return hours * 3600.0 / ratio


## Hari dalam minggu: 0 = Monday (Hari 1 = Monday, v3.1 26.5).
func weekday(for_day: int = -1) -> int:
	var d: int = day if for_day < 0 else for_day
	return posmod(d - 1, 7)


## Malam (GDD idle 3.2): `night.from_hour` sampai `night.to_hour`, melewati 00:00.
func is_night(t: float = -1.0) -> bool:
	var x: float = time_seconds if t < 0.0 else fposmod(t, DAY_SECONDS)
	if _night_from > _night_to:
		return x >= _night_from or x < _night_to
	return x >= _night_from and x < _night_to


## Satu tick: majukan jam. Mengembalikan true bila tick ini melewati 00:00
## (hari baru dimulai).
func advance(dt: float) -> bool:
	sim_seconds += dt
	time_seconds += dt * ratio
	var rolled: bool = false
	while time_seconds >= DAY_SECONDS:
		time_seconds -= DAY_SECONDS
		day += 1
		rolled = true
	var minute: int = int(time_seconds / 60.0)
	if minute != _last_emitted_minute or rolled:
		_last_emitted_minute = minute
		EventBus.time_changed.emit(day, time_seconds)
	return rolled


func capture() -> Dictionary:
	return {"day": day, "time_seconds": time_seconds, "sim_seconds": sim_seconds}


func restore(d: Dictionary) -> void:
	day = maxi(1, int(d.get("day", 1)))
	time_seconds = fposmod(float(d.get("time_seconds", DataRegistry.idlef("clock.start_seconds"))), DAY_SECONDS)
	sim_seconds = float(d.get("sim_seconds", 0.0))
