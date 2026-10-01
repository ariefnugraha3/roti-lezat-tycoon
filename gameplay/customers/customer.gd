class_name Customer
extends RefCounted
## State logis satu pelanggan fisik (GDD 20.1). Aktor visualnya diambil dari
## pool oleh lapisan dunia berdasarkan data ini.

const SPAWNING: StringName = &"SPAWNING"
const ENTERING: StringName = &"ENTERING"
const BROWSING: StringName = &"BROWSING"
const SELECTING: StringName = &"SELECTING"
const CARRYING_TO_QUEUE: StringName = &"CARRYING_TO_QUEUE"
const QUEUING: StringName = &"QUEUING"
const FRONT_OF_QUEUE: StringName = &"FRONT_OF_QUEUE"
const BEING_SERVED: StringName = &"BEING_SERVED"
const PAYING: StringName = &"PAYING"
const CELEBRATING: StringName = &"CELEBRATING"
const LEAVING: StringName = &"LEAVING"
const ABANDONING: StringName = &"ABANDONING"
const RETURNING_ITEMS: StringName = &"RETURNING_ITEMS"
const LEAVE_NO_STOCK: StringName = &"LEAVE_NO_STOCK"
const DESPAWNED: StringName = &"DESPAWNED"

var id: StringName
var archetype: StringName
var actor: SimActor
var state: StringName = SPAWNING
var scripted: bool = false
var requested_recipe: StringName = &""
var requested_qty: int = 0
var patience_max: float = 30.0
var patience: float = 30.0
var lane_id: StringName = &""
## Lot yang dipegang (lihat DisplayInventoryManager).
var held: Array = []
var target_recipe: StringName = &""
var target_display: int = -1
var target_qty: int = 0
var substitution_used: bool = false
var browse_left: float = 0.0
var celebrate_left: float = 0.0
## Waktu di antrean sampai dilayani (detik-simulasi), untuk rating & VIP.
var queue_wait: float = 0.0
var stall_time: float = 0.0
var last_slot: int = -1
var awaiting_tap: bool = false
var is_critic: bool = false
var outcome: StringName = &""
var price_label: StringName = &"NEUTRAL"
var spawned_at: float = 0.0
## Pengunjung lihat-lihat (GDD 20.12): ENTERING -> BROWSING di satu atau dua
## tempat dekat rak -> LEAVING, tanpa antrean, patience, stok, maupun rating.
var window_shopper: bool = false
## Sel tempat ia berdiri melihat-lihat; bukan titik eksklusif (GDD 83.3).
var look_cell: Vector2i = Vector2i(-1, -1)
## Rak yang sedang dilihat (-1 = melihat-lihat ruangan).
var look_display: int = -1
var looks_left: int = 0


func def() -> CustomerArchetypeDefinition:
	return DataRegistry.archetype(archetype)


func patience_ratio() -> float:
	if patience_max <= 0.0:
		return 0.0
	return clampf(patience / patience_max, 0.0, 1.0)


func held_units() -> int:
	var n: int = 0
	for l: Variant in held:
		n += ((l as Dictionary)["stack"] as BreadStack).quantity
	return n


## Patience berkurang hanya saat menunggu di antrean/layanan (GDD 20.8, 58).
func drains_patience() -> bool:
	return state == QUEUING or state == FRONT_OF_QUEUE or state == BEING_SERVED


func to_dict() -> Dictionary:
	var lots: Array = []
	for l: Variant in held:
		var ld: Dictionary = l
		lots.append({"stack": (ld["stack"] as BreadStack).to_dict(), "display_id": ld["display_id"],
			"slot_index": ld["slot_index"], "unit_price": ld["unit_price"], "taken_at": ld.get("taken_at", -1.0)})
	return {
		"id": String(id), "archetype": String(archetype), "state": String(state), "scripted": scripted,
		"requested_recipe": String(requested_recipe), "requested_qty": requested_qty,
		"patience_max": patience_max, "patience": patience, "lane_id": String(lane_id),
		"held": lots, "target_recipe": String(target_recipe), "target_display": target_display,
		"target_qty": target_qty, "substitution_used": substitution_used, "browse_left": browse_left,
		"celebrate_left": celebrate_left, "queue_wait": queue_wait, "stall_time": stall_time,
		"awaiting_tap": awaiting_tap, "is_critic": is_critic, "spawned_at": spawned_at,
		"window_shopper": window_shopper, "look_cell": [look_cell.x, look_cell.y], "look_display": look_display,
		"looks_left": looks_left, "actor": actor.to_dict(),
	}


static func held_from(arr: Variant) -> Array:
	var out: Array = []
	if arr is Array:
		for l: Variant in arr:
			var ld: Dictionary = l
			out.append({"stack": BreadStack.from_dict(ld["stack"]), "display_id": int(ld["display_id"]),
				"slot_index": int(ld["slot_index"]), "unit_price": float(ld["unit_price"]),
				"taken_at": float(ld.get("taken_at", -1.0))})
	return out
