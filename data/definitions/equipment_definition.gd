class_name EquipmentDefinition
extends RefCounted
## Perabot/alat kanonik (GDD 5.1, 60, 62, 85, 86, 101.3).

var id: StringName
var localization_key: StringName
## mixer / oven / display / storage / counter
var category_id: StringName
var tier: int = 1
var footprint_tiles: Vector2i = Vector2i.ONE
var height_m: float = 0.0
var interaction_face: StringName
var rotations_allowed: Array[int] = []
var utility_cost_kr_per_ingame_hour: float = 0.0
## Mixer/oven: waktu referensi Seksi 5.1. 0 untuk kategori lain.
var reference_seconds: float = 0.0
var process_multiplier: float = 1.0
## Display: kapasitas unit roti. Storage: kapasitas unit bahan.
var capacity: int = 0
var slot_count: int = 0
var max_per_slot: int = 0
var aging_rate: float = 1.0
var perfect_window_seconds: float = 0.0
var overbake_window_seconds: float = 0.0
var price_kr: float = 0.0
var for_sale: bool = false
var visual_profile_id: StringName


static func from_dict(d: Dictionary) -> EquipmentDefinition:
	var e := EquipmentDefinition.new()
	e.id = StringName(str(d.get("id", "")))
	e.localization_key = StringName(str(d.get("localization_key", "")))
	e.category_id = StringName(str(d.get("category_id", "")))
	e.tier = int(d.get("tier", 0))
	var fp: Array = d.get("footprint_tiles", [0, 0])
	e.footprint_tiles = Vector2i(int(fp[0]), int(fp[1]))
	e.height_m = float(d.get("height_m", 0.0))
	e.interaction_face = StringName(str(d.get("interaction_face", "front")))
	for r: Variant in d.get("rotations_allowed", [0]):
		e.rotations_allowed.append(int(r))
	e.utility_cost_kr_per_ingame_hour = float(d.get("utility_cost_kr_per_ingame_hour", 0.0))
	e.reference_seconds = float(d.get("reference_seconds", 0.0))
	e.process_multiplier = float(d.get("process_multiplier", 1.0))
	e.capacity = int(d.get("capacity", 0))
	e.slot_count = int(d.get("slot_count", 0))
	e.max_per_slot = int(d.get("max_per_slot", 0))
	e.aging_rate = float(d.get("aging_rate", 1.0))
	e.perfect_window_seconds = float(d.get("perfect_window_seconds", 0.0))
	e.overbake_window_seconds = float(d.get("overbake_window_seconds", 0.0))
	e.price_kr = float(d.get("price_kr", 0.0))
	e.for_sale = bool(d.get("for_sale", false))
	e.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
	return e


func burn_grace_seconds() -> float:
	return perfect_window_seconds + overbake_window_seconds


func is_movable() -> bool:
	return category_id != &"counter"
