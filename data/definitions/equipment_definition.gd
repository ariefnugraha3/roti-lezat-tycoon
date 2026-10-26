class_name EquipmentDefinition
extends RefCounted
## Model perabot/alat kanonik (GDD idle 4.1, 8.2; v3.1 5.1, 60, 101.3). Tidak ada
## harga: stasiun dibuka dengan KR dan modelnya berevolusi dari levelnya.

var id: StringName
var localization_key: StringName
## mixer / oven / display / storage / table / chair / counter
var category_id: StringName
var tier: int = 1
var footprint_tiles: Vector2i = Vector2i.ONE
var height_m: float = 0.0
var interaction_face: StringName
var rotations_allowed: Array[int] = []
## Display: jumlah petak model ini; max_per_slot rak T1 = base_units (GDD idle 8.2).
var slot_count: int = 0
var max_per_slot: int = 0
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
	e.slot_count = int(d.get("slot_count", 0))
	e.max_per_slot = int(d.get("max_per_slot", 0))
	e.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
	return e


func is_movable() -> bool:
	return category_id != &"counter"
