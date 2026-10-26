class_name BreadStack
extends RefCounted
## Satu-satunya skema tumpukan roti (v3.1 19.1). Roti tidak pernah menjadi node
## per unit (v3.1 37.3); satu stack = satu batch.
##
## Roti idle tidak menua, tidak basi, dan tidak punya kualitas panggang
## (GDD idle 4.6): stack hanya mencatat resep, jumlah, petak, dan batch asalnya.
## `produced_at_game_time` memakai detik-simulasi kumulatif TimeManager supaya
## urutan FIFO tetap benar lintas hari.

var recipe_id: StringName
var quantity: int = 0
var slot_id: StringName
var source_job_id: int = -1
var produced_at_game_time: float = 0.0


func duplicate_stack() -> BreadStack:
	var b := BreadStack.new()
	b.recipe_id = recipe_id
	b.quantity = quantity
	b.slot_id = slot_id
	b.source_job_id = source_job_id
	b.produced_at_game_time = produced_at_game_time
	return b


func to_dict() -> Dictionary:
	return {
		"recipe_id": String(recipe_id), "quantity": quantity, "slot_id": String(slot_id),
		"source_job_id": source_job_id, "produced_at_game_time": produced_at_game_time,
	}


static func from_dict(d: Dictionary) -> BreadStack:
	var b := BreadStack.new()
	b.recipe_id = StringName(str(d.get("recipe_id", "")))
	b.quantity = int(d.get("quantity", 0))
	b.slot_id = StringName(str(d.get("slot_id", "")))
	b.source_job_id = int(d.get("source_job_id", -1))
	b.produced_at_game_time = float(d.get("produced_at_game_time", 0.0))
	return b
