class_name RecipeBookScreen
extends UIScreen
## Buku Resep (GDD 5.3, 7, 61, 63.2, 92.4). Dibuka dengan mengetuk Storage;
## tombol Make hanya membuat job. Semua angka dibaca dari katalog.

const REACTION_KEYS: Dictionary = {
	&"VERY_HAPPY": "price_very_happy", &"HAPPY": "price_happy", &"NEUTRAL": "price_neutral",
	&"UNHAPPY": "price_unhappy", &"VERY_UNHAPPY": "price_very_unhappy", &"REFUSE": "price_refuse",
}
const REACTION_ICONS: Dictionary = {
	&"VERY_HAPPY": "heart", &"HAPPY": "happy", &"NEUTRAL": "bubble",
	&"UNHAPPY": "sad", &"VERY_UNHAPPY": "angry", &"REFUSE": "cross",
}

var _selected: StringName = &""
var _batch: int = 1
var _tab: int = 0
var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _price_label: Label = null
var _reaction: Label = null
var _reaction_icon: IconCanvas = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_recipe_book"), Vector2(1180, 660))
	var tabs: HBoxContainer = hbox(body, 8)
	btn(tabs, Tx.t("ui_recipe_tab_recipes"), "primary", func() -> void:
		_tab = 0
		_render_detail())
	btn(tabs, Tx.t("ui_recipe_tab_analytics"), "secondary", func() -> void:
		_tab = 1
		_render_detail())
	var split: HBoxContainer = hbox(body, 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(380, 0)
	split.add_child(left)
	_list = scroll_box(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_detail = scroll_box(right)
	var plan: Dictionary = DataRegistry.opening_day(sim.time.day)
	_selected = StringName(str(plan.get("recipe_id", ""))) if not plan.is_empty() else &""
	if _selected == &"":
		for r: RecipeDefinition in DataRegistry.recipes():
			if sim.production.make_block_reason(r.id, 1) == "":
				_selected = r.id
				break
	if _selected == &"":
		_selected = DataRegistry.recipes()[0].id
	_render_list()
	_render_detail()
	if sim.tutorial.active():
		sim.tutorial.on_event(&"pricing_opened")


func _render_list() -> void:
	clear(_list)
	var last_cat: StringName = &""
	for r: RecipeDefinition in DataRegistry.recipes():
		if r.category_id != last_cat:
			last_cat = r.category_id
			lbl(_list, "Tier %d" % r.required_mixer_tier, 14, Palette.TEXT_MUTED)
		var reason: String = sim.production.make_block_reason(r.id, 1)
		var b: Button = ProceduralUIFactory.button(Tx.recipe_name(r.id), "primary" if r.id == _selected else ("secondary" if reason == "" else "ghost"))
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(340, 52)
		var rid: StringName = r.id
		b.pressed.connect(func() -> void:
			_selected = rid
			_render_list()
			_render_detail())
		_list.add_child(b)


func _render_detail() -> void:
	clear(_detail)
	var r: RecipeDefinition = DataRegistry.recipe(_selected)
	if r == null:
		return
	var head: HBoxContainer = hbox(_detail, 12)
	var ic := CenterContainer.new()
	ic.add_child(ProceduralUIFactory.icon("bread", 48, Palette.GOLDEN_CRUST))
	head.add_child(ic)
	lbl(head, Tx.recipe_name(r.id), 26, Palette.UI_WOOD, true)
	if _tab == 1:
		_render_analytics(r)
		return
	lbl(_detail, Tx.t("ui_recipe_ingredients"), 18, Palette.UI_WOOD)
	for ing: StringName in r.ingredients.keys():
		var need: int = int(r.ingredients[ing]) * _batch
		var have: int = sim.inventory.count(ing)
		var row: HBoxContainer = hbox(_detail, 8)
		row.add_child(ProceduralUIFactory.icon("check" if have >= need else "cross", 18, Palette.SUCCESS if have >= need else Palette.DANGER))
		lbl(row, "%s — %s" % [Tx.item_name(ing), Tx.t("ui_recipe_have", {"have": have, "need": need})], 16, Palette.TEXT if have >= need else Palette.DANGER)
	var mixer: EquipmentInstance = sim.production.free_mixer_for(r)
	var oven: EquipmentInstance = sim.production.free_oven_for(r)
	var mt: int = mixer.tier() if mixer != null else r.required_mixer_tier
	var ot: int = oven.tier() if oven != null else r.required_oven_tier
	var oven_def: EquipmentDefinition = DataRegistry.equipment_for(&"oven", ot)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 24)
	_detail.add_child(grid)
	lbl(grid, Tx.t("ui_recipe_yield", {"count": r.batch_yield * _batch}), 16)
	lbl(grid, Tx.t("ui_recipe_equipment", {"mixer": r.required_mixer_tier, "oven": r.required_oven_tier}), 16)
	lbl(grid, Tx.t("ui_recipe_mix_time", {"seconds": "%.1f" % sim.production.mixer_stage_seconds(r, mt, _batch, 1.0)}), 16)
	lbl(grid, Tx.t("ui_recipe_bake_time", {"seconds": "%.1f" % sim.production.oven_stage_seconds(r, ot, _batch, 1.0)}), 16)
	lbl(grid, Tx.t("ui_recipe_burn_grace", {"seconds": "%d" % int(oven_def.burn_grace_seconds())}), 16)
	lbl(grid, Tx.t("ui_recipe_cogs", {"cost": Tx.kr(r.unit_cogs_kr())}), 16)
	lbl(_detail, Tx.t("ui_recipe_expires", {"hours": str(snappedf(r.expired_duration_hours, 0.01))}), 16, Palette.TEXT_MUTED, true)
	var tags: PackedStringArray = PackedStringArray()
	for t: StringName in r.customer_tags:
		tags.append(Tx.t("tag_" + String(t)))
	lbl(_detail, Tx.t("ui_recipe_tags", {"tags": ", ".join(tags)}), 16, Palette.TEXT_MUTED, true)
	_detail.add_child(ProceduralUIFactory.dashed_separator())
	_build_price(r)
	_detail.add_child(ProceduralUIFactory.dashed_separator())
	lbl(_detail, Tx.t("ui_recipe_batch"), 18, Palette.UI_WOOD)
	var brow: HBoxContainer = hbox(_detail, 10)
	for b: int in DataRegistry.bal("production.batch_multipliers"):
		var bb: Button = ProceduralUIFactory.button("x%d" % b, "primary" if b == _batch else "secondary")
		bb.custom_minimum_size = Vector2(72, 52)
		bb.pressed.connect(func() -> void:
			_batch = b
			_render_detail())
		brow.add_child(bb)
	var reason: String = sim.production.make_block_reason(r.id, _batch)
	var make: Button = ProceduralUIFactory.button(Tx.t("ui_make"), "primary")
	make.custom_minimum_size = Vector2(220, 60)
	make.disabled = reason != ""
	make.pressed.connect(_make)
	_detail.add_child(make)
	if reason != "":
		lbl(_detail, Tx.t(reason, {"mixer": r.required_mixer_tier, "oven": r.required_oven_tier}), 16, Palette.DANGER, true)


func _build_price(r: RecipeDefinition) -> void:
	lbl(_detail, Tx.t("ui_recipe_price"), 18, Palette.UI_WOOD)
	var row: HBoxContainer = hbox(_detail, 12)
	var sl := HSlider.new()
	sl.min_value = r.min_price_kr
	sl.max_value = r.max_price_kr
	sl.step = r.price_step_kr
	sl.value = sim.pricing.price_of(r.id)
	sl.custom_minimum_size = Vector2(360, 48)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	_price_label = lbl(row, "", 20, Palette.GOLDEN_CRUST)
	var rrow: HBoxContainer = hbox(_detail, 8)
	_reaction_icon = ProceduralUIFactory.icon("happy", 26, Palette.GOLD_STAR)
	rrow.add_child(_reaction_icon)
	_reaction = lbl(rrow, "", 16)
	lbl(_detail, "%s · %s" % [Tx.t("ui_recipe_default_price", {"price": Tx.kr(r.base_sell_price_kr)}),
		Tx.t("ui_recipe_price_range", {"min": Tx.kr(r.min_price_kr), "max": Tx.kr(r.max_price_kr)})], 14, Palette.TEXT_MUTED, true)
	# Hari 1-3 harga terkunci di harga referensi (GDD 63.2).
	if sim.pricing.prices_locked():
		sl.editable = false
		lbl(_detail, Tx.t("ui_recipe_price_locked"), 14, Palette.DANGER, true)
	sl.value_changed.connect(func(v: float) -> void:
		sim.pricing.set_price(r.id, v)
		_update_price(r))
	_update_price(r)


## Emoji slider memakai price_demand baseline (GDD 84.5).
func _update_price(r: RecipeDefinition) -> void:
	_price_label.text = Tx.kr(sim.pricing.price_of(r.id))
	var label: StringName = DataRegistry.price_reaction_label(sim.pricing.baseline_demand(r.id))
	_reaction.text = Tx.t(str(REACTION_KEYS.get(label, "price_neutral")))
	var col: Color = Palette.SUCCESS if label in [&"VERY_HAPPY", &"HAPPY"] else (Palette.TEXT_MUTED if label == &"NEUTRAL" else Palette.DANGER)
	_reaction_icon.configure(str(REACTION_ICONS.get(label, "bubble")), 26, col)


func _render_analytics(r: RecipeDefinition) -> void:
	var v: Dictionary = sim.analytics.view(r.id)
	if not bool(v["unlocked"]):
		lbl(_detail, Tx.t("ui_recipe_analytics_locked"), 18, Palette.TEXT_MUTED, true)
		return
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 40)
	_detail.add_child(grid)
	var rows: Array = [
		["ui_analytics_produced", str(v["produced"])], ["ui_analytics_sold", str(v["sold"])],
		["ui_analytics_wasted", str(v["wasted"])], ["ui_analytics_revenue", Tx.kr(float(v["revenue"]))],
		["ui_analytics_avg_price", Tx.kr(float(v["average_price"]))], ["ui_analytics_margin", Tx.kr(float(v["margin"]))],
	]
	for row: Array in rows:
		lbl(grid, Tx.t(str(row[0])), 18)
		lbl(grid, str(row[1]), 18, Palette.UI_WOOD)


func _make() -> void:
	var reason: String = sim.player.order_recipe(_selected, _batch)
	if reason != "":
		EventBus.sfx.emit(&"ui_error", &"")
		_render_detail()
		return
	EventBus.sfx.emit(&"ui_confirm", &"")
	close()


func on_closed() -> void:
	sim.player.close_storage()
