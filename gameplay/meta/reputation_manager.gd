class_name ReputationManager
extends SimManager
## ReputationManager — dua rating terpisah: toko fisik dan RotiFood Stars
## (GDD 9, 25, 98). Tidak pernah digabung menjadi satu skor (GDD 13.3).

var physical: float = 3.0
var rotifood: float = 3.0
var day_start_physical: float = 3.0
var day_start_rotifood: float = 3.0
## Hasil penilaian Food Vlogger, diterapkan 05:00 esok hari (GDD 25.2).
var pending_vip: Array[StringName] = []
var vip_today: bool = false


func new_game() -> void:
	physical = DataRegistry.balf("rating.start_physical")
	rotifood = DataRegistry.balf("rating.start_rotifood")
	day_start_physical = physical
	day_start_rotifood = rotifood
	pending_vip.clear()
	vip_today = false


func _clamp(v: float) -> float:
	return clampf(v, DataRegistry.balf("rating.min"), DataRegistry.balf("rating.max"))


## Event fisik bernama; `scale` = tier_scale untuk event per pelanggan.
func physical_event(event: StringName, scale: float) -> void:
	var ev: Dictionary = DataRegistry.bal("rating.physical_events")
	var delta: float = float(ev.get(String(event), 0.0)) * scale
	add_physical(delta)


func add_physical(delta: float) -> void:
	if is_nan(delta) or delta == 0.0:
		return
	physical = _clamp(physical + delta)
	sim.statistics.note_rating(physical, rotifood)
	EventBus.rating_changed.emit(physical, rotifood)


func rotifood_event(delta: float) -> void:
	if delta == 0.0:
		return
	rotifood = _clamp(rotifood + delta)
	sim.statistics.note_rating(physical, rotifood)
	EventBus.rating_changed.emit(physical, rotifood)
	if rotifood >= DataRegistry.balf("rating.max") - 0.0001:
		sim.achievements.check_condition(&"rotifood_five_stars")


func queue_vip(outcome: StringName) -> void:
	vip_today = true
	pending_vip.append(outcome)


## 05:00: terapkan ulasan VIP kemarin (tidak diskalakan tier).
func begin_day() -> void:
	for outcome: StringName in pending_vip:
		physical_event(outcome, 1.0)
	pending_vip.clear()
	vip_today = false
	day_start_physical = physical
	day_start_rotifood = rotifood


func trusted_badge() -> bool:
	return rotifood >= DataRegistry.balf("rating.trusted_badge_stars")


func capture() -> Dictionary:
	var pv: Array = []
	for p: StringName in pending_vip:
		pv.append(String(p))
	return {"physical": physical, "rotifood": rotifood, "day_start_physical": day_start_physical,
		"day_start_rotifood": day_start_rotifood, "pending_vip": pv, "vip_today": vip_today}


func restore(d: Dictionary) -> void:
	physical = _clamp(float(d.get("physical", 3.0)))
	rotifood = _clamp(float(d.get("rotifood", 3.0)))
	day_start_physical = float(d.get("day_start_physical", physical))
	day_start_rotifood = float(d.get("day_start_rotifood", rotifood))
	pending_vip.clear()
	for p: Variant in d.get("pending_vip", []):
		pending_vip.append(StringName(str(p)))
	vip_today = bool(d.get("vip_today", false))
