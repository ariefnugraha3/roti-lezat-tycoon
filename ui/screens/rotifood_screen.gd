class_name RotiFoodScreen
extends UIScreen
## Pesanan RotiFood (GDD 3.6.A, 22). Popup yang sama dibuka dari panel HUD dan
## dari tablet di meja. Item yang stoknya kurang ditandai merah dengan ikon
## silang; tombol Pack tidak pernah mati tanpa alasan. Pesanan yang belum
## dikemas bisa ditolak (Reject, GDD 22.10) setelah konfirmasi yang menyebut
## penalti bintangnya. Tidak menuntut karakter berdiri di meja kasir.

var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _selected: int = -1
var _tour: CoachMarks = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_rotifood"), Vector2(1000, 560))
	var split: HBoxContainer = hbox(body, 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	split.add_child(left)
	_list = scroll_box(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_detail = scroll_box(right)
	_selected = int(params.get("order", -1))
	var orders: Array[DeliveryOrder] = sim.rotifood.active_orders()
	if _selected < 0 and not orders.is_empty():
		_selected = orders[0].order_id
	_render()
	var o: DeliveryOrder = sim.rotifood.orders.get(_selected)
	if o != null and not o.packed and sim.tutorial.screen_tour(&"rotifood_popup"):
		sim.tutorial.mark_tour(&"rotifood_popup")
		_start_tour.call_deferred()


## Tur sekali (GDD 88.4, 22.10): Pack Order, lalu Reject Order.
func _start_tour() -> void:
	if is_queued_for_deletion():
		return
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup([
		{"targets": _named.bind("Pack"), "key": "tut_rotifood_pack", "next": true},
		{"targets": _named.bind("Reject"), "key": "tut_rotifood_reject", "next": true},
	])


func _named(node_name: String) -> Array:
	var n: Node = find_child(node_name, true, false)
	return [n] if n != null else []


func tour() -> CoachMarks:
	return _tour if _tour != null and is_instance_valid(_tour) else null


func _render() -> void:
	clear(_list)
	clear(_detail)
	var orders: Array[DeliveryOrder] = sim.rotifood.active_orders()
	if orders.is_empty():
		_list.add_child(ProceduralUIFactory.empty_state("scooter", Tx.t("ui_hud_rotifood_none")))
		return
	for o: DeliveryOrder in orders:
		var b: Button = ProceduralUIFactory.button("#%d · %d" % [o.order_id, o.total_units()], "primary" if o.order_id == _selected else "secondary")
		b.custom_minimum_size = Vector2(280, 52)
		var oid: int = o.order_id
		b.pressed.connect(func() -> void:
			_selected = oid
			_render())
		_list.add_child(b)
	var o2: DeliveryOrder = sim.rotifood.order(_selected)
	if o2 == null or not o2.is_active():
		return
	sim.rotifood.mark_opened(o2.order_id)
	lbl(_detail, Tx.t("ui_rotifood_order_title", {"id": o2.order_id}), 22, Palette.OJOL_GREEN)
	var stock: Dictionary = sim.display.sellable_by_recipe()
	var short: Dictionary = sim.rotifood.shortages(o2)
	var keys: Array = o2.items.keys()
	keys.sort()
	for rid: Variant in keys:
		var missing: bool = short.has(rid)
		var row: HBoxContainer = hbox(_detail, 8)
		row.add_child(ProceduralUIFactory.icon("cross" if missing and not o2.packed else "check", 20, Palette.DANGER if missing and not o2.packed else Palette.SUCCESS))
		var n: Label = lbl(row, Tx.t("ui_order_line", {"count": o2.items[rid], "recipe": Tx.recipe_name(rid)}), 17, Palette.DANGER if missing and not o2.packed else Palette.TEXT)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl(row, Tx.t("ui_rotifood_stock", {"stock": stock.get(rid, 0)}), 15, Palette.TEXT_MUTED)
	lbl(_detail, Tx.t("ui_order_total", {"total": Tx.kr(o2.subtotal())}), 20, Palette.GOLDEN_CRUST)
	if o2.packed:
		lbl(_detail, Tx.t("ui_rotifood_packed"), 18, Palette.SUCCESS)
		return
	if not short.is_empty():
		lbl(_detail, Tx.t("ui_rotifood_missing"), 16, Palette.DANGER, true)
	var actions: HBoxContainer = hbox(_detail, 12)
	var pack: Button = btn(actions, Tx.t("ui_rotifood_pack"), "primary", func() -> void:
		if sim.rotifood.pack(_selected):
			EventBus.sfx.emit(&"ui_confirm", &"")
		else:
			EventBus.sfx.emit(&"ui_error", &"")
		_render())
	pack.name = "Pack"
	pack.custom_minimum_size = Vector2(220, 60)
	pack.disabled = not short.is_empty()
	var reject: Button = btn(actions, Tx.t("ui_rotifood_reject"), "secondary", _ask_reject)
	reject.name = "Reject"
	reject.custom_minimum_size = Vector2(180, 60)
	reject.visible = sim.rotifood.can_reject(o2.order_id)
	lbl(_detail, Tx.t("tut_rotifood"), 14, Palette.TEXT_MUTED, true)


## Menolak menurunkan RotiFood Stars, jadi tanya dulu. Setelah ditolak, pesanan
## aktif berikutnya yang terpilih.
func _ask_reject() -> void:
	var oid: int = _selected
	var stars: String = "%.2f" % absf(float((DataRegistry.bal("rating.rotifood_events") as Dictionary)["order_rejected"]))
	host.confirm(Tx.t("ui_rotifood_reject_confirm", {"id": oid, "stars": stars}), func() -> void:
		if sim.rotifood.reject(oid):
			var left: Array[DeliveryOrder] = sim.rotifood.active_orders()
			_selected = left[0].order_id if not left.is_empty() else -1
		_render())
