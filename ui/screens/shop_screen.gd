class_name ShopScreen
extends UISheet
## Layar Shop (GDD idle 8.4, 8.7, 8.9, 12.3): pindah ke lokasi berikutnya
## (perbandingan Current -> Next seperti Store Upgrade v3.1), buka stasiun baru,
## dan upgrade global. Semua daftar vertikal di lembar bawah.

var _rows: Array[BuyButtons] = []
var _move: Button = null
var _open_buttons: Dictionary = {}


func sheet_title() -> String:
	return Tx.t("ui_tab_shop")


func build_page(body: VBoxContainer) -> void:
	_rows.clear()
	_open_buttons.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "ShopList"
	_location(list)
	lbl(list, Tx.t("ui_shop_open_stations"), 15, Palette.TEXT_MUTED)
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		_open_row(list, cat)
	lbl(list, Tx.t("ui_shop_global"), 15, Palette.TEXT_MUTED)
	for g: Variant in DataRegistry.idle("global_upgrades"):
		_global_row(list, StringName(str((g as Dictionary)["id"])))


## Lokasi sekarang -> berikutnya: slot, jalur, staf, batas level, dan biaya.
func _location(parent: Control) -> void:
	var cur: LocationDefinition = sim.world.location
	var nxt: LocationDefinition = sim.next_location()
	lbl(parent, Tx.t("ui_shop_location"), 15, Palette.TEXT_MUTED)
	var card: PanelContainer = ProceduralUIFactory.card(Tx.t(String(cur.localization_key)) if nxt == null else Tx.t("ui_shop_move_title", {"from": Tx.t(String(cur.localization_key)), "to": Tx.t(String(nxt.localization_key))}))
	card.name = "Location"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(card)
	var body: VBoxContainer = ProceduralUIFactory.content_of(card)
	if nxt == null:
		lbl(body, Tx.t("ui_upgrade_max"), 16, Palette.TEXT_MUTED, true)
		return
	var caps: Array = DataRegistry.idle("station.level_cap_by_location")
	var rows: Array = [
		["ui_shop_row_mixers", cur.slot_count(&"mixer"), nxt.slot_count(&"mixer")],
		["ui_shop_row_ovens", cur.slot_count(&"oven"), nxt.slot_count(&"oven")],
		["ui_shop_row_displays", cur.slot_count(&"display"), nxt.slot_count(&"display")],
		["ui_shop_row_lanes", cur.slot_count(&"cashier"), nxt.slot_count(&"cashier")],
		["ui_shop_row_staff", cur.staff_capacity(&"cashier") + cur.staff_capacity(&"baker"), nxt.staff_capacity(&"cashier") + nxt.staff_capacity(&"baker")],
		["ui_shop_row_level_cap", int(caps[cur.tier - 1]), int(caps[nxt.tier - 1])],
	]
	for r: Array in rows:
		var h: HBoxContainer = hbox(body, 8)
		var l: Label = lbl(h, Tx.t(str(r[0])), 16)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lbl(h, Tx.t("ui_shop_row_change", {"from": int(r[1]), "to": int(r[2])}), 16, Palette.UI_WOOD_DEEP)
	var cost: float = SimulationRoot.location_cost(nxt.tier)
	_move = ProceduralUIFactory.icon_text_button("shop", Tx.t("ui_shop_move", {"price": Tx.kr(cost)}), "primary", 22, 17)
	_move.name = "Move"
	_move.custom_minimum_size = Vector2(0, 58)
	_move.disabled = sim.upgrade_block_reason() != ""
	_move.pressed.connect(_confirm_move)
	body.add_child(_move)


func _confirm_move() -> void:
	var nxt: LocationDefinition = sim.next_location()
	if nxt == null:
		return
	host.confirm(Tx.t("ui_shop_move_confirm", {"to": Tx.t(String(nxt.localization_key)), "price": Tx.kr(SimulationRoot.location_cost(nxt.tier))}), func() -> void:
		var r: String = sim.upgrade_location()
		if r != "":
			EventBus.notify.emit(1, r, {}, &"warning")
		refresh())


## Buka stasiun ke-n kategori `cat` (GDD idle 8.4).
func _open_row(parent: Control, cat: StringName) -> void:
	var have: int = sim.equipment.placed_count(cat)
	var limit: int = sim.equipment.slot_limit(cat)
	var station: String = Tx.t("ui_station_" + String(cat))
	var h: HBoxContainer = UISheet.row(parent, station, Tx.t("ui_shop_open_count", {"have": have, "limit": limit}),
		ProceduralUIFactory.badge(str(UpgradeInfo.ICONS[cat]), Palette.CARAMEL, Palette.FLOUR_WHITE, 44))
	h.get_parent().name = "Open_" + String(cat)
	var cost: float = sim.upgrades.open_station_cost(cat)
	if cost < 0.0:
		lbl(h, Tx.t("ui_shop_open_full"), 15, Palette.TEXT_MUTED)
		return
	var text: String = Tx.t("ui_open_station", {"station": station, "price": Tx.kr(cost)})
	var b: Button = ProceduralUIFactory.button(Tx.t("ui_shop_open_for", {"price": Tx.kr(cost)}), "primary")
	b.name = "Open"
	b.tooltip_text = text
	b.custom_minimum_size = Vector2(maxf(150.0, ProceduralUIFactory._text_width(b.text, 18, true) + 40.0), 52)
	b.disabled = not sim.economy.can_afford(cost)
	b.pressed.connect(func() -> void:
		if sim.upgrades.open_station(cat) >= 0:
			refresh())
	h.add_child(b)
	_open_buttons[cat] = b


func _global_row(parent: Control, gid: StringName) -> void:
	var o: Dictionary = sim.upgrades.offer(&"global", gid)
	var pc := PanelContainer.new()
	pc.name = "Global_" + String(gid)
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM, 18, false)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var top: HBoxContainer = hbox(v, 10)
	top.add_child(UpgradeInfo.icon(sim, o, 44))
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(text)
	var t: Label = lbl(text, UpgradeInfo.title(sim, o), 18, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	lbl(text, UpgradeInfo.effect(sim, o), 14, Palette.TEXT_MUTED, true)
	var buy: BuyButtons = BuyButtons.new().setup(sim, &"global", gid)
	buy.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy.bought.connect(func(_n: int) -> void: refresh())
	v.add_child(buy)
	_rows.append(buy)


func tick_page() -> void:
	for b: BuyButtons in _rows:
		if is_instance_valid(b):
			b.refresh()
	if is_instance_valid(_move):
		_move.disabled = sim.upgrade_block_reason() != ""
	for cat: Variant in _open_buttons.keys():
		var ob: Button = _open_buttons[cat]
		if is_instance_valid(ob):
			var c: float = sim.upgrades.open_station_cost(cat)
			ob.disabled = c < 0.0 or not sim.economy.can_afford(c)
