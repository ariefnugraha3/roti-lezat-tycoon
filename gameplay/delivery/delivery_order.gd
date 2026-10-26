class_name DeliveryOrder
extends RefCounted
## Pesanan RotiFood (GDD idle 6.5; v3.1 22.1, 22.2). `state` melacak siklus
## pesanan; posisi driver dilacak terpisah di `driver_phase`.
##
## Pesanan diterima otomatis: roti dipesan dari rak begitu tersedia
## (`reserved_lots`), lalu dikemas pemilik atau kasir yang menganggur, dan
## diserahkan saat driver tiba di titik layan.

const WAITING_FOR_STOCK: StringName = &"WAITING_FOR_STOCK"
const TO_PACK: StringName = &"TO_PACK"
const PACKING: StringName = &"PACKING"
const PACKED: StringName = &"PACKED"
const COMPLETED: StringName = &"COMPLETED"
const CANCELLED: StringName = &"CANCELLED"

## Fase driver: none -> pending -> approaching -> entering -> queued -> at_service -> leaving -> gone
var order_id: int = 0
## recipe_id -> jumlah
var items: Dictionary = {}
var created_at: float = 0.0
var prep_window: float = 90.0
var driver_arrival_time: float = 0.0
var state: StringName = WAITING_FOR_STOCK
## Lot roti yang sudah diambil dari rak untuk pesanan ini (harga terkunci).
var reserved_lots: Array = []
var packed: bool = false
## Pekerja yang sedang mengemas (&"" = belum ada).
var packer_id: StringName = &""
var pack_elapsed: float = 0.0
var handover_at: float = -1.0
var economy_committed: bool = false
var driver_phase: StringName = &"none"
var driver_pending_since: float = -1.0
var driver_entered_at: float = -1.0
var driver_patience: float = 30.0
var driver_patience_max: float = 30.0
var driver_stall: float = 0.0
var driver_last_slot: int = -1
var driver: SimActor = null
var cancel_reason: StringName = &""


func driver_id() -> StringName:
	return StringName("d%d" % order_id)


func is_reserved() -> bool:
	return not reserved_lots.is_empty()


## Pendapatan pesanan: harga per unit yang dikunci saat roti dipesan dari rak.
func subtotal() -> float:
	var s: float = 0.0
	for l: Variant in reserved_lots:
		var ld: Dictionary = l
		s += Money.round_half_up(float(ld["unit_price"])) * (ld["stack"] as BreadStack).quantity
	return s


func total_units() -> int:
	var n: int = 0
	for rid: Variant in items.keys():
		n += int(items[rid])
	return n


func is_active() -> bool:
	return state != COMPLETED and state != CANCELLED


static func lots_to_json(lots: Array) -> Array:
	var out: Array = []
	for l: Variant in lots:
		var ld: Dictionary = l
		out.append({"stack": (ld["stack"] as BreadStack).to_dict(), "display_id": ld["display_id"],
			"slot_index": ld["slot_index"], "unit_price": ld["unit_price"]})
	return out


func to_dict() -> Dictionary:
	return {
		"order_id": order_id, "items": SimManager.sn_dict_to_json(items), "created_at": created_at,
		"prep_window": prep_window, "driver_arrival_time": driver_arrival_time, "state": String(state),
		"reserved_lots": lots_to_json(reserved_lots), "packed": packed, "packer_id": String(packer_id),
		"pack_elapsed": pack_elapsed, "handover_at": handover_at, "economy_committed": economy_committed,
		"driver_phase": String(driver_phase), "driver_pending_since": driver_pending_since,
		"driver_entered_at": driver_entered_at, "driver_patience": driver_patience,
		"driver_patience_max": driver_patience_max, "cancel_reason": String(cancel_reason),
		"driver": driver.to_dict() if driver != null else {},
	}


static func from_dict(d: Dictionary) -> DeliveryOrder:
	var o := DeliveryOrder.new()
	o.order_id = int(d.get("order_id", 0))
	var it: Dictionary = d.get("items", {})
	for k: Variant in it.keys():
		o.items[StringName(str(k))] = int(it[k])
	o.created_at = float(d.get("created_at", 0.0))
	o.prep_window = float(d.get("prep_window", 90.0))
	o.driver_arrival_time = float(d.get("driver_arrival_time", 0.0))
	o.state = StringName(str(d.get("state", WAITING_FOR_STOCK)))
	o.reserved_lots = Customer.held_from(d.get("reserved_lots", []))
	o.packed = bool(d.get("packed", false))
	o.packer_id = StringName(str(d.get("packer_id", "")))
	o.pack_elapsed = float(d.get("pack_elapsed", 0.0))
	o.handover_at = float(d.get("handover_at", -1.0))
	o.economy_committed = bool(d.get("economy_committed", false))
	o.driver_phase = StringName(str(d.get("driver_phase", "none")))
	o.driver_pending_since = float(d.get("driver_pending_since", -1.0))
	o.driver_entered_at = float(d.get("driver_entered_at", -1.0))
	o.driver_patience = float(d.get("driver_patience", 30.0))
	o.driver_patience_max = float(d.get("driver_patience_max", 30.0))
	o.cancel_reason = StringName(str(d.get("cancel_reason", "")))
	var dd: Dictionary = d.get("driver", {})
	if not dd.is_empty():
		o.driver = SimActor.new()
		o.driver.apply_dict(dd)
	return o
