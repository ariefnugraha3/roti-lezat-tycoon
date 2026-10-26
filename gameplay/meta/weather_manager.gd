class_name WeatherManager
extends SimManager
## WeatherManager — cuaca hari ini dan kalender libur (GDD idle 3.3, 11.3;
## v3.1 10, 26, 98). Cuaca diundi sekali per hari in-game, saat hari baru
## dimulai pukul 00:00; efeknya hanya pengali kedatangan dan pesanan RotiFood
## (weather.json). Tidak ada lagi prakiraan untuk perencanaan.

var today: StringName = &"weather_sunny"
## Cuaca hari berikutnya, sudah diundi supaya urutan undian tetap (v3.1 26.6).
var tomorrow: StringName = &"weather_sunny"
var physical_mult: float = 1.0
var delivery_mult: float = 1.0


func new_game() -> void:
	today = &"weather_sunny"
	tomorrow = &"weather_sunny"
	_roll_multipliers()
	_roll_tomorrow()


## Libur deterministik tanpa RNG: day >= start dan (day - start) mod period < length (v3.1 26.6).
static func is_holiday(day: int) -> bool:
	var ev: Dictionary = DataRegistry.holiday_event()
	var start: int = int(ev.get("start_day", 12))
	if day < start:
		return false
	return posmod(day - start, int(ev.get("period_days", 14))) < int(ev.get("length_days", 3))


func holiday_today() -> bool:
	return is_holiday(sim.time.day)


## Hari menuju libur berikutnya (0 = hari ini), atau -1 bila > 30 hari.
func days_until_holiday() -> int:
	for k in range(0, 31):
		if is_holiday(sim.time.day + k):
			return k
	return -1


## Pukul 00:00: cuaca hari ini = undian kemarin; undian hari berikutnya dibuat.
func on_new_day() -> void:
	today = tomorrow
	_roll_multipliers()
	_roll_tomorrow()
	EventBus.weather_changed.emit(today, tomorrow)


func _roll_tomorrow() -> void:
	var next_day: int = sim.time.day + 1
	if next_day <= int(DataRegistry.weather_raw().get("fixed_sunny_through_day", 4)):
		tomorrow = &"weather_sunny"
		return
	var row: Dictionary = (DataRegistry.weather_raw().get("markov", {}) as Dictionary).get(String(today), {})
	var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"weather_rng"), row)
	tomorrow = StringName(str(pick)) if pick != null else &"weather_sunny"


func _roll_multipliers() -> void:
	var w: MiscDefinitions.WeatherDefinition = DataRegistry.weather(today)
	var r: RandomNumberGenerator = sim.rng.stream(&"weather_rng")
	physical_mult = r.randf_range(w.physical_traffic_multiplier_min, w.physical_traffic_multiplier_max) \
		if w.physical_traffic_multiplier_max > w.physical_traffic_multiplier_min else w.physical_traffic_multiplier_min
	delivery_mult = r.randf_range(w.delivery_multiplier_min, w.delivery_multiplier_max) \
		if w.delivery_multiplier_max > w.delivery_multiplier_min else w.delivery_multiplier_min


func physical_multiplier() -> float:
	return physical_mult


func delivery_multiplier() -> float:
	return delivery_mult


func event_physical_multiplier() -> float:
	return float(DataRegistry.holiday_event().get("physical_traffic_multiplier", 1.0)) if holiday_today() else 1.0


func is_rain() -> bool:
	return today == &"weather_rain"


func capture() -> Dictionary:
	return {"today": String(today), "tomorrow": String(tomorrow), "physical_mult": physical_mult, "delivery_mult": delivery_mult}


func restore(d: Dictionary) -> void:
	today = StringName(str(d.get("today", "weather_sunny")))
	tomorrow = StringName(str(d.get("tomorrow", "weather_sunny")))
	if DataRegistry.weather(today) == null:
		today = &"weather_sunny"
	if DataRegistry.weather(tomorrow) == null:
		tomorrow = &"weather_sunny"
	physical_mult = float(d.get("physical_mult", 1.0))
	delivery_mult = float(d.get("delivery_mult", 1.0))
