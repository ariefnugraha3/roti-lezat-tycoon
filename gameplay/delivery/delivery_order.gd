class_name DeliveryOrder
extends RefCounted
## Pesanan RotiFood (GDD 22.1, 22.2). `state` melacak siklus pesanan; posisi
## driver dilacak terpisah di `driver_phase`.

const CREATED: StringName = &"CREATED"
const NOTIFIED: StringName = &"NOTIFIED"
const OPENED: StringName = &"OPENED"
const WAITING_FOR_STOCK: StringName = &"WAITING_FOR_STOCK"
const PACKING: StringName = &"PACKING"
const PACKED_WAITING_DRIVER: StringName = &"PACKED_WAITING_DRIVER"
const DRIVER_EN_ROUTE: StringName = &"DRIVER_EN_ROUTE"
const DRIVER_WAITING: StringName = &"DRIVER_WAITING"
const HANDOVER: StringName = &"HANDOVER"
const COMPLETED: StringName = &"COMPLETED"
const EXPIRED: StringName = &"EXPIRED"
const CANCELLED: StringName = &"CANCELLED"

## Fase driver: none -> pending -> entering -> queued -> at_service -> leaving -> gone
var order_id: int = 0
## recipe_id -> jumlah
var items: Dictionary = {}
## recipe_id -> harga per unit yang dikunci saat order dibuat (GDD 63.2)
var unit_prices: Dictionary = {}
var created_at: float = 0.0
var created_ingame: float = 0.0
var prep_window: float = 90.0
var driver_arrival_time: float = 0.0
var preparation_deadline: float = -1.0
var state: StringName = CREATED
var packed: bool = false
var packed_lots: Array = []
var packed_all_prime: bool = false
var packed_at: float = -1.0
var handover_at: float = -1.0
var rating_delta: float = 0.0
var tip_amount: float = 0.0
var economy_committed: bool = false
var scripted: bool = false
var driver_phase: StringName = &"none"
var driver_pending_since: float = -1.0
var driver_entered_at: float = -1.0
var driver_patience: float = 30.0
var driver_patience_max: float = 30.0
var driver_stall: float = 0.0
var driver_last_slot: int = -1
var driver: SimActor = null
var smart_warned: bool = false
var cancel_reason: StringName = &""


func driver_id() -> StringName:
	return StringName("d%d" % order_id)


func subtotal() -> float:
	var s: float = 0.0
	for rid: Variant in items.keys():
		s += Money.round_half_up(float(unit_prices.get(rid, 0.0))) * int(items[rid])
	return s


func total_units() -> int:
	var n: int = 0
	for rid: Variant in items.keys():
		n += int(items[rid])
	return n


func is_active() -> bool:
	return state != COMPLETED and state != EXPIRED and state != CANCELLED


func to_dict() -> Dictionary:
	var lots: Array = []
	for l: Variant in packed_lots:
		var ld: Dictionary = l
		lots.append({"stack": (ld["stack"] as BreadStack).to_dict(), "display_id": ld["display_id"],
			"slot_index": ld["slot_index"], "unit_price": ld["unit_price"], "taken_at": ld.get("taken_at", -1.0)})
	return {
		"order_id": order_id, "items": SimManager.sn_dict_to_json(items),
		"unit_prices": SimManager.sn_dict_to_json(unit_prices), "created_at": created_at,
		"created_ingame": created_ingame, "prep_window": prep_window,
		"driver_arrival_time": driver_arrival_time, "preparation_deadline": preparation_deadline,
		"state": String(state), "packed": packed, "packed_lots": lots, "packed_all_prime": packed_all_prime,
		"packed_at": packed_at, "handover_at": handover_at, "rating_delta": rating_delta,
		"tip_amount": tip_amount, "economy_committed": economy_committed, "scripted": scripted,
		"driver_phase": String(driver_phase), "driver_pending_since": driver_pending_since,
		"driver_entered_at": driver_entered_at, "driver_patience": driver_patience,
		"driver_patience_max": driver_patience_max, "smart_warned": smart_warned,
		"cancel_reason": String(cancel_reason),
		"driver": driver.to_dict() if driver != null else {},
	}


static func from_dict(d: Dictionary) -> DeliveryOrder:
	var o := DeliveryOrder.new()
	o.order_id = int(d.get("order_id", 0))
	var it: Dictionary = d.get("items", {})
	for k: Variant in it.keys():
		o.items[StringName(str(k))] = int(it[k])
	var up: Dictionary = d.get("unit_prices", {})
	for k2: Variant in up.keys():
		o.unit_prices[StringName(str(k2))] = float(up[k2])
	o.created_at = float(d.get("created_at", 0.0))
	o.created_ingame = float(d.get("created_ingame", 0.0))
	o.prep_window = float(d.get("prep_window", 90.0))
	o.driver_arrival_time = float(d.get("driver_arrival_time", 0.0))
	o.preparation_deadline = float(d.get("preparation_deadline", -1.0))
	o.state = StringName(str(d.get("state", CREATED)))
	o.packed = bool(d.get("packed", false))
	o.packed_lots = Customer.held_from(d.get("packed_lots", []))
	o.packed_all_prime = bool(d.get("packed_all_prime", false))
	o.packed_at = float(d.get("packed_at", -1.0))
	o.handover_at = float(d.get("handover_at", -1.0))
	o.rating_delta = float(d.get("rating_delta", 0.0))
	o.tip_amount = float(d.get("tip_amount", 0.0))
	o.economy_committed = bool(d.get("economy_committed", false))
	o.scripted = bool(d.get("scripted", false))
	o.driver_phase = StringName(str(d.get("driver_phase", "none")))
	o.driver_pending_since = float(d.get("driver_pending_since", -1.0))
	o.driver_entered_at = float(d.get("driver_entered_at", -1.0))
	o.driver_patience = float(d.get("driver_patience", 30.0))
	o.driver_patience_max = float(d.get("driver_patience_max", 30.0))
	o.smart_warned = bool(d.get("smart_warned", false))
	o.cancel_reason = StringName(str(d.get("cancel_reason", "")))
	var dd: Dictionary = d.get("driver", {})
	if not dd.is_empty():
		o.driver = SimActor.new()
		o.driver.apply_dict(dd)
	return o
