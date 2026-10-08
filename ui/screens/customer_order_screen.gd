class_name CustomerOrderScreen
extends UIScreen
## Popup pesanan pembeli fisik (GDD 2 langkah 6-7, 21.4): daftar roti yang
## dibeli beserta total; OK memulai animasi membungkus di simulation time.
## Selama tutorial Hari 1 mengajarkan pembeli pertama (GDD 88.1), total dan
## tombol OK disorot (`CoachMarks`), dan pemain mengetuk OK sendiri.

var _tour: CoachMarks = null


func build() -> void:
	var cid: StringName = StringName(str(params.get("customer", "")))
	var c: Customer = sim.customers.customer(cid)
	var body: VBoxContainer = make_popup(Tx.t("ui_order_title"), Vector2(560, 440))
	if c == null:
		lbl(body, Tx.t("ui_feedback_nothing_to_do"), 18)
		return
	lbl(body, Tx.t(String(c.archetype)), 20, Palette.UI_WOOD)
	var total: float = 0.0
	var list: VBoxContainer = scroll_box(body)
	for l: Variant in c.held:
		var lot: Dictionary = l
		var st: BreadStack = lot["stack"]
		var price: float = Money.round_half_up(float(lot["unit_price"]))
		total += price * st.quantity
		var row: HBoxContainer = hbox(list, 8)
		row.add_child(ProceduralUIFactory.icon("bread", 22, Palette.GOLDEN_CRUST))
		var n: Label = lbl(row, Tx.t("ui_order_line", {"count": st.quantity, "recipe": Tx.recipe_name(st.recipe_id)}), 17)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl(row, Tx.kr(price * st.quantity), 17, Palette.UI_WOOD)
	var total_l: Label = lbl(body, Tx.t("ui_order_total", {"total": Tx.kr(total)}), 22, Palette.GOLDEN_CRUST)
	total_l.name = "Total"
	var row2: HBoxContainer = hbox(body, 12)
	row2.alignment = BoxContainer.ALIGNMENT_END
	var ok: Button = btn(row2, Tx.t("ui_order_wrap"), "primary", func() -> void:
		sim.cashier.confirm_manual(cid)
		close())
	ok.name = "Wrap"
	ok.custom_minimum_size = Vector2(200, 60)
	if sim.tutorial.order_tour():
		_start_tour.call_deferred([list.get_parent(), total_l, ok])


## Satu sorotan: roti yang dibeli, total, dan OK. Tanpa Next, karena pemain
## mengetuk OK sendiri.
func _start_tour(targets: Array) -> void:
	if is_queued_for_deletion():
		return
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup([{"targets": func() -> Array: return targets, "key": "tut_order_ok", "next": false}])


func tour() -> CoachMarks:
	return _tour if _tour != null and is_instance_valid(_tour) else null


func on_closed() -> void:
	sim.ui_requests.customer_order = &""
