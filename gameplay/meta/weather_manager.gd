class_name WeatherManager
extends SimManager
## WeatherManager — cuaca hari ini/besok, pengali harian, dan kalender holiday
## (GDD 10, 26, 98). Pengali di-roll sekali per hari, bukan per order (GDD 26.3).

var today: StringName = &"weather_sunny"
var tomorrow: StringName = &"weather_sunny"
var physical_mult: float = 1.0
var delivery_mult: float = 1.0


func new_game() -> void:
	today = &"weather_sunny"
	tomorrow = &"weather_sunny"
	physical_mult = 1.0
	delivery_mult = 1.0


## Holiday deterministik tanpa RNG: day >= 12 dan (day-12) mod 14 < 3 (GDD 26.6).
static func is_holiday(day: int) -> bool:
	var ev: Dictionary = DataRegistry.holiday_event()
	var start: int = int(ev.get("start_day", 12))
	if day < start:
		return false
	return posmod(day - start, int(ev.get("period_days", 14))) < int(ev.get("length_days", 3))


func holiday_today() -> bool:
	return is_holiday(sim.time.day)


## Hari menuju holiday berikutnya (0 = hari ini), atau -1 bila > 30 hari.
func days_until_holiday() -> int:
	for k in range(0, 31):
		if is_holiday(sim.time.day + k):
			return k
	return -1


## Prakiraan besok di-roll saat settlement (GDD 26.1, 26.6).
func forecast_next() -> void:
	var next_day: int = sim.time.day + 1
	if next_day <= int(DataRegistry.weather_raw().get("fixed_sunny_through_day", 4)):
		tomorrow = &"weather_sunny"
	else:
		var row: Dictionary = (DataRegistry.weather_raw().get("markov", {}) as Dictionary).get(String(today), {})
		var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"weather_rng"), row)
		tomorrow = StringName(str(pick)) if pick != null else &"weather_sunny"
	EventBus.weather_changed.emit(today, tomorrow)


## 05:00: cuaca hari ini = prakiraan kemarin; pengali di-roll sekali.
func begin_day(first_day: bool) -> void:
	if not first_day:
		today = tomorrow
	var w: MiscDefinitions.WeatherDefinition = DataRegistry.weather(today)
	var r: RandomNumberGenerator = sim.rng.stream(&"weather_rng")
	physical_mult = r.randf_range(w.physical_traffic_multiplier_min, w.physical_traffic_multiplier_max) \
		if w.physical_traffic_multiplier_max > w.physical_traffic_multiplier_min else w.physical_traffic_multiplier_min
	delivery_mult = r.randf_range(w.delivery_multiplier_min, w.delivery_multiplier_max) \
		if w.delivery_multiplier_max > w.delivery_multiplier_min else w.delivery_multiplier_min
	EventBus.weather_changed.emit(today, tomorrow)


func physical_multiplier() -> float:
	return physical_mult


func delivery_multiplier() -> float:
	return delivery_mult


func event_physical_multiplier() -> float:
	return float(DataRegistry.holiday_event().get("physical_traffic_multiplier", 1.0)) if holiday_today() else 1.0


func event_delivery_multiplier() -> float:
	return float(DataRegistry.holiday_event().get("delivery_multiplier", 1.0)) if holiday_today() else 1.0


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
