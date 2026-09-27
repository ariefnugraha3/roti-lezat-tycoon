class_name CustomerOrderScreen
extends UIScreen
## Popup pesanan pembeli fisik (GDD 2 langkah 6-7, 21.4): daftar roti yang
## dibeli beserta total; OK memulai animasi membungkus di simulation time.


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
	lbl(body, Tx.t("ui_order_total", {"total": Tx.kr(total)}), 22, Palette.GOLDEN_CRUST)
	var row2: HBoxContainer = hbox(body, 12)
	row2.alignment = BoxContainer.ALIGNMENT_END
	var ok: Button = btn(row2, Tx.t("ui_order_wrap"), "primary", func() -> void:
		sim.cashier.confirm_manual(cid)
		close())
	ok.custom_minimum_size = Vector2(200, 60)


func on_closed() -> void:
	sim.ui_requests.customer_order = &""
