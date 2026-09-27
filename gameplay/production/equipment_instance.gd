class_name EquipmentInstance
extends RefCounted
## Satu perabot milik pemain (GDD 18.4, 32.1, 106). Posisi disimpan sebagai
## {floor_id, grid_x, grid_y, rotation_quarters}, bukan transform dunia (GDD 57
## appendix no. 9).

var iid: int = 0
var def_id: StringName
var floor_id: StringName = &"floor_1"
var anchor: Vector2i = Vector2i.ZERO
## 0..3 (kelipatan 90°).
var rotation: int = 0
var placed: bool = false
## Job produksi yang sedang menempati alat ini (-1 = kosong).
var job_id: int = -1


func def() -> EquipmentDefinition:
	return DataRegistry.equipment(def_id)


func category() -> StringName:
	var d: EquipmentDefinition = def()
	return d.category_id if d != null else &""


func tier() -> int:
	var d: EquipmentDefinition = def()
	return d.tier if d != null else 1


func footprint_cells() -> Array[Vector2i]:
	return GridMath.footprint_cells(anchor, def().footprint_tiles, rotation)


func front_cells() -> Array[Vector2i]:
	return GridMath.front_cells(anchor, def().footprint_tiles, rotation, def().interaction_face)


func to_dict() -> Dictionary:
	return {
		"iid": iid, "def_id": String(def_id), "floor_id": String(floor_id),
		"grid_x": anchor.x, "grid_y": anchor.y, "rotation_quarters": rotation,
		"placed": placed, "job_id": job_id,
	}


static func from_dict(d: Dictionary) -> EquipmentInstance:
	var e := EquipmentInstance.new()
	e.iid = int(d.get("iid", 0))
	e.def_id = StringName(str(d.get("def_id", "")))
	e.floor_id = StringName(str(d.get("floor_id", "floor_1")))
	e.anchor = Vector2i(int(d.get("grid_x", 0)), int(d.get("grid_y", 0)))
	e.rotation = posmod(int(d.get("rotation_quarters", 0)), 4)
	e.placed = bool(d.get("placed", false))
	e.job_id = int(d.get("job_id", -1))
	return e
