class_name MarketScreen
extends UIScreen
## Pasar (GDD 5.1.2, 5.2, 7, 24A, 47, 64): tab Ingredients, Equipment, Store
## Upgrade. Membuka Pasar selalu mem-pause simulasi. Equipment & Store Upgrade
## hanya aktif after-hours; di waktu lain tampil read-only.

var _tab: int = 0
var _body: VBoxContainer = null
var _qty: Dictionary = {}
var _total: Label = null
var _cap: Label = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_market"), Vector2(1180, 660))
	_tab = int(params.get("tab", 0))
	body.add_child(ProceduralUIFactory.tab_bar([Tx.t("ui_market_tab_ingredients"), Tx.t("ui_market_tab_equipment"),
		Tx.t("ui_market_tab_upgrade")], _tab, func(idx: int) -> void:
			_tab = idx
			_render()))
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_body)
	_render()


func _render() -> void:
	clear(_body)
	match _tab:
		0:
			_render_ingredients()
		1:
			_render_equipment()
		_:
			_render_upgrade()


# ===========================================================================
# INGREDIENTS (GDD 5.2, 55.5-55.9)
# ===========================================================================

func _render_ingredients() -> void:
	if not sim.supply.market_unlocked:
		lbl(_body, Tx.t("ui_market_locked"), 18, Palette.DANGER, true)
		return
	var board: PanelContainer = ProceduralUIFactory.chalkboard_panel()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(board)
	var inner: VBoxContainer = ProceduralUIFactory.content_of(board)
	var list: VBoxContainer = scroll_box(inner)
	var last_cat: StringName = &""
	for ing: IngredientDefinition in DataRegistry.ingredients():
		if ing.category_id != last_cat:
			last_cat = ing.category_id
			list.add_child(ProceduralUIFactory.chalk_label(Tx.t("ingredient_category_" + String(ing.category_id)), 18))
		var row: HBoxContainer = hbox(list, 10)
		var name_l: Label = ProceduralUIFactory.chalk_label("%s (%s)" % [Tx.item_name(ing.id), Tx.t(String(ing.unit_label_key))], 16)
		name_l.custom_minimum_size = Vector2(300, 0)
		row.add_child(name_l)
		row.add_child(ProceduralUIFactory.chalk_label(Tx.kr(ing.fixed_buy_price_kr), 16))
		var stock := VBoxContainer.new()
		stock.custom_minimum_size = Vector2(220, 0)
		row.add_child(stock)
		stock.add_child(ProceduralUIFactory.chalk_label(Tx.t("ui_market_stock", {"count": sim.inventory.count(ing.id)}), 14))
		var transit: int = sim.supply.in_transit_of(ing.id)
		if transit > 0:
			var eta: float = sim.supply.next_eta_of(ing.id)
			stock.add_child(ProceduralUIFactory.chalk_label("%s · %s" % [Tx.t("ui_market_in_transit", {"count": transit}), Tx.t("ui_market_eta", {"time": Tx.clock(eta)})], 14))
		var q: Label = null
		var minus: Button = ProceduralUIFactory.icon_button("minus", Tx.t("ui_cancel"), "secondary")
		row.add_child(minus)
		q = ProceduralUIFactory.chalk_label(str(_qty.get(ing.id, 0)), 18)
		q.custom_minimum_size = Vector2(44, 0)
		q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		row.add_child(q)
		var plus: Button = ProceduralUIFactory.icon_button("plus", Tx.t("ui_market_buy"), "secondary")
		row.add_child(plus)
		var mx: Button = ProceduralUIFactory.button(Tx.t("ui_market_max"), "ghost")
		mx.custom_minimum_size = Vector2(72, 48)
		row.add_child(mx)
		var id: StringName = ing.id
		minus.pressed.connect(func() -> void: _change(id, -1, q))
		plus.pressed.connect(func() -> void: _change(id, 1, q))
		mx.pressed.connect(func() -> void: _change(id, 999999, q))
	var foot: HBoxContainer = hbox(_body, 14)
	_cap = lbl(foot, "", 16)
	_total = lbl(foot, "", 20, Palette.GOLDEN_CRUST)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buy: Button = btn(foot, Tx.t("ui_market_buy"), "primary", _buy)
	buy.custom_minimum_size = Vector2(200, 56)
	lbl(_body, Tx.t("ui_market_after_hours_note") if sim.time.is_after_hours() else Tx.t("ui_market_delivery_note"), 14, Palette.TEXT_MUTED, true)
	_update_totals()


func _units_selected() -> int:
	var n: int = 0
	for k: Variant in _qty.keys():
		n += int(_qty[k]) * DataRegistry.ingredient(k).storage_units_per_purchase
	return n


func _cost_selected() -> float:
	var c: float = 0.0
	for k: Variant in _qty.keys():
		c += DataRegistry.ingredient(k).fixed_buy_price_kr * int(_qty[k])
	return c


## +/-/Max dibatasi saldo & kapasitas termasuk in_transit (GDD 55.9).
func _change(id: StringName, delta: int, q: Label) -> void:
	var cur: int = int(_qty.get(id, 0))
	var def: IngredientDefinition = DataRegistry.ingredient(id)
	var free_units: int = sim.supply.max_additional_units() - _units_selected() + cur * def.storage_units_per_purchase
	var afford: int = int((sim.economy.balance - _cost_selected() + cur * def.fixed_buy_price_kr) / def.fixed_buy_price_kr)
	var limit: int = maxi(0, mini(free_units / def.storage_units_per_purchase, afford))
	var nv: int = clampi(cur + delta, 0, limit)
	if nv == 0:
		_qty.erase(id)
	else:
		_qty[id] = nv
	q.text = str(nv)
	_update_totals()


func _update_totals() -> void:
	if _total == null:
		return
	_total.text = Tx.t("ui_market_total", {"total": Tx.kr(_cost_selected())})
	var used: int = sim.inventory.total_units() + sim.supply.in_transit_units() + _units_selected()
	_cap.text = Tx.t("ui_market_capacity", {"used": used, "cap": sim.inventory.capacity()})


func _buy() -> void:
	if _qty.is_empty():
		return
	var cost: float = _cost_selected()
	var go: Callable = func() -> void:
		var r: Dictionary = sim.supply.purchase(_qty.duplicate())
		if bool(r.get("ok", false)):
			_qty.clear()
			EventBus.sfx.emit(&"ui_confirm", &"")
		else:
			_reason_toast(str(r.get("reason", "")))
		_render()
	_confirm_if_expensive(cost, go)


# ===========================================================================
# EQUIPMENT (GDD 5.1.2)
# ===========================================================================

func _render_equipment() -> void:
	var open: bool = sim.equipment.market_open_for_equipment()
	if not open:
		lbl(_body, Tx.t("ui_available_after_closing"), 18, Palette.DANGER)
	var list: VBoxContainer = scroll_box(_body)
	var stored: Array[EquipmentInstance] = sim.equipment.unplaced_list()
	if not stored.is_empty():
		lbl(list, Tx.t("ui_equipment_stored_list"), 20, Palette.UI_WOOD)
		for e: EquipmentInstance in stored:
			if e.category() == &"storage":
				continue
			var row: HBoxContainer = hbox(list, 10)
			var n: Label = lbl(row, "%s (T%d)" % [Tx.item_name(e.def_id), e.tier()], 16)
			n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var place: Button = btn(row, Tx.t("ui_decor_place"), "secondary", func() -> void: host.open(&"decoration", {"select_iid": e.iid}))
			place.disabled = false
			var sell: Button = btn(row, Tx.t("ui_equipment_sell", {"price": Tx.kr(sim.equipment.sell_value(e.iid))}), "danger", _sell.bind(e.iid))
			sell.disabled = not open
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		lbl(list, "%s · %s" % [Tx.t("equipment_category_" + String(cat)),
			Tx.t("ui_equipment_owned", {"placed": sim.equipment.placed_count(cat), "stored": sim.equipment.unplaced_list(cat).size()})], 20, Palette.UI_WOOD)
		for def: EquipmentDefinition in DataRegistry.equipment_in_category(cat):
			list.add_child(_equipment_card(def, open))


func _equipment_card(def: EquipmentDefinition, open: bool) -> Control:
	var card: PanelContainer = ProceduralUIFactory.card("%s · T%d" % [Tx.item_name(def.id), def.tier])
	var body: VBoxContainer = ProceduralUIFactory.content_of(card)
	var info := GridContainer.new()
	info.columns = 2
	info.add_theme_constant_override("h_separation", 24)
	body.add_child(info)
	if def.category_id == &"display":
		lbl(info, Tx.t("ui_equipment_capacity", {"count": def.capacity, "slots": def.slot_count}), 15)
	else:
		lbl(info, Tx.t("ui_equipment_reference", {"seconds": str(snappedf(DataRegistry.real_seconds(def.reference_seconds), 0.01))}), 15)
	lbl(info, Tx.t("ui_equipment_utility", {"cost": Tx.kr(def.utility_cost_kr_per_ingame_hour)}), 15)
	lbl(info, Tx.t("ui_equipment_footprint", {"w": def.footprint_tiles.x, "h": def.footprint_tiles.y}), 15)
	var recipes: PackedStringArray = PackedStringArray()
	for r: RecipeDefinition in DataRegistry.recipes():
		if (def.category_id == &"mixer" and r.required_mixer_tier == def.tier) or (def.category_id == &"oven" and r.required_oven_tier == def.tier):
			recipes.append(Tx.recipe_name(r.id))
	if not recipes.is_empty():
		lbl(body, Tx.t("ui_equipment_recipes", {"recipes": ", ".join(recipes)}), 14, Palette.TEXT_MUTED, true)
	# Alat di atas tier lokasi belum dijual (GDD 5.1.2).
	var locked: bool = not sim.equipment.tier_allowed(def)
	if locked:
		lbl(body, Tx.t("ui_equipment_tier_locked", {"tier": def.tier}), 15, Palette.DANGER, true)
	var row: HBoxContainer = hbox(body, 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var full: bool = sim.equipment.placed_count(def.category_id) + sim.equipment.unplaced_list(def.category_id).size() >= sim.equipment.slot_limit(def.category_id)
	var buy: Button = btn(row, Tx.t("ui_equipment_buy", {"price": Tx.kr(def.price_kr)}), "primary", _buy_equipment.bind(def.id))
	buy.disabled = not open or locked or full or not sim.economy.can_afford(def.price_kr)
	if full and not locked:
		for e: EquipmentInstance in sim.equipment.placed_list(def.category_id):
			var rb: Button = btn(row, "%s: %s" % [Tx.t("ui_equipment_replace"), Tx.item_name(e.def_id)], "secondary", _replace.bind(def.id, e.iid))
			rb.disabled = not open or sim.equipment.is_in_use(e.iid) or not sim.economy.can_afford(def.price_kr)
	return card


func _buy_equipment(def_id: StringName) -> void:
	var def: EquipmentDefinition = DataRegistry.equipment(def_id)
	_confirm_if_expensive(def.price_kr, func() -> void:
		var r: Dictionary = sim.equipment.buy(def_id)
		if bool(r.get("ok", false)):
			close()
			# Alat baru masuk inventaris lalu Decoration Mode terbuka (GDD 5.1.2).
			host.open(&"decoration", {"select_iid": int(r["iid"])})
		else:
			_reason_toast(str(r.get("reason", "")))
			_render())


func _replace(def_id: StringName, old_iid: int) -> void:
	var def: EquipmentDefinition = DataRegistry.equipment(def_id)
	_confirm_if_expensive(def.price_kr, func() -> void:
		var r: Dictionary = sim.equipment.buy_replace(def_id, old_iid)
		if not bool(r.get("ok", false)):
			_reason_toast(str(r.get("reason", "")))
		elif not bool(r.get("placed", false)):
			close()
			host.open(&"decoration", {"select_iid": int(r["iid"])})
			return
		_render())


func _sell(iid: int) -> void:
	host.confirm(Tx.t("ui_equipment_sell", {"price": Tx.kr(sim.equipment.sell_value(iid))}), _do_sell.bind(iid), true)


func _do_sell(iid: int) -> void:
	sim.equipment.sell(iid)
	_render()


# ===========================================================================
# STORE UPGRADE (GDD 6, 47, 64, 105)
# ===========================================================================

func _render_upgrade() -> void:
	var cur: LocationDefinition = sim.world.location
	lbl(_body, Tx.t("ui_upgrade_current"), 18, Palette.TEXT_MUTED)
	_body.add_child(_location_card(cur))
	var nxt: LocationDefinition = sim.next_location()
	if nxt == null:
		lbl(_body, Tx.t("ui_upgrade_max"), 20, Palette.GOLDEN_CRUST)
		return
	lbl(_body, Tx.t("ui_upgrade_next"), 18, Palette.TEXT_MUTED)
	_body.add_child(_location_card(nxt))
	var reason: String = sim.upgrade_block_reason()
	var b: Button = btn(_body, Tx.t("ui_upgrade_buy", {"price": Tx.kr(nxt.upgrade_cost_kr)}), "primary", func() -> void:
		host.confirm(Tx.t("ui_upgrade_confirm", {"location": Tx.t(String(nxt.localization_key)), "price": Tx.kr(nxt.upgrade_cost_kr)}), _do_upgrade))
	b.custom_minimum_size = Vector2(300, 60)
	b.disabled = reason != ""
	if reason != "":
		lbl(_body, Tx.t(reason), 16, Palette.DANGER, true)


func _location_card(l: LocationDefinition) -> Control:
	var card: PanelContainer = ProceduralUIFactory.card(Tx.t(String(l.localization_key)))
	var body: VBoxContainer = ProceduralUIFactory.content_of(card)
	lbl(body, Tx.t("ui_upgrade_detail", {"mixers": l.slot_count(&"mixer"), "ovens": l.slot_count(&"oven"),
		"displays": l.slot_count(&"display"), "cashiers": l.slot_count(&"cashier")}), 16, Palette.TEXT, true)
	lbl(body, Tx.t("ui_upgrade_staff", {"cashiers": l.staff_capacity(&"cashier"), "bakers": l.staff_capacity(&"baker")}), 16)
	lbl(body, Tx.t("ui_upgrade_storage", {"capacity": DataRegistry.equipment(l.storage_id).capacity}), 16)
	return card


func _do_upgrade() -> void:
	var r: String = sim.upgrade_location()
	if r != "":
		EventBus.notify.emit(1, r, {}, &"warning")
		_render()
		return
	close()


# ===========================================================================

func _confirm_if_expensive(cost: float, go: Callable) -> void:
	if SettingsManager.get_bool("confirm_expensive") and cost >= float(SettingsManager.get_int("confirm_threshold")):
		host.confirm(Tx.t("ui_confirm_purchase", {"price": Tx.kr(cost)}), go)
	else:
		go.call()


func _reason_toast(reason: String) -> void:
	var key: String = {"kr": "ui_feedback_not_enough_kr", "capacity": "ui_feedback_storage_full",
		"after_hours": "ui_available_after_closing", "slots_full": "ui_equipment_slots_full",
		"in_use": "ui_feedback_in_use", "locked": "ui_market_locked",
		"tier_locked": "ui_equipment_tier_locked"}.get(reason, "ui_feedback_nothing_to_do")
	EventBus.notify.emit(1, key, {"tier": sim.world.location.tier + 1}, &"warning")
	EventBus.sfx.emit(&"ui_error", &"")
