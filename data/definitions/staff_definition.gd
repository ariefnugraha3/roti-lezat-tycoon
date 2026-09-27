class_name StaffDefinition
extends RefCounted
## Kandidat staf dari roster tetap (GDD 3.1-3.5, 87.1, 101.5).

var id: StringName
var display_name: String = ""
## &"cashier" atau &"baker"
var role_id: StringName
var tier: int = 1
var daily_wage_kr: float = 0.0
var work_speed_multiplier: float = 1.0
var cashier_service_seconds: float = 0.0
var auto_retrieve_probability: float = 0.0
var movement_speed_mps: float = 1.2
## Kemampuan khusus kasir (GDD 3.1): queue_patience_drain_multiplier,
## indecisive_service_multiplier, physical_tip_chance.
var special: Dictionary = {}
## Parameter CharacterFactory (warna sebagai "#rrggbb").
var visual: Dictionary = {}
var visual_profile_id: StringName


static func from_dict(d: Dictionary) -> StaffDefinition:
	var s := StaffDefinition.new()
	s.id = StringName(str(d.get("id", "")))
	s.display_name = str(d.get("display_name", ""))
	s.role_id = StringName(str(d.get("role_id", "")))
	s.tier = int(d.get("tier", 0))
	s.daily_wage_kr = float(d.get("daily_wage_kr", 0.0))
	s.work_speed_multiplier = float(d.get("work_speed_multiplier", 1.0))
	s.cashier_service_seconds = float(d.get("cashier_service_seconds", 0.0))
	s.auto_retrieve_probability = float(d.get("auto_retrieve_probability", 0.0))
	s.movement_speed_mps = float(d.get("movement_speed_mps", 1.2))
	s.special = d.get("special", {})
	s.visual = d.get("visual", {})
	s.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
	return s


func is_cashier() -> bool:
	return role_id == &"cashier"


func is_baker() -> bool:
	return role_id == &"baker"


func title_key() -> String:
	return "staff_title_%s_%d" % [role_id, tier]


func special_value(key: String, fallback: float) -> float:
	return float(special.get(key, fallback))
