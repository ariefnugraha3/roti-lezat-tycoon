class_name MenuScreen
extends UISheet
## Layar Menu (GDD idle 4.2, 8.5, 12.3): petak rak dengan resep yang dijualnya
## (pilih resep atau "Auto"), lalu daftar resep dengan gambar BreadArt, harga
## jual, dan tombol buka. Detail petak terbuka sebagai halaman berikutnya di
## lembar yang sama. Mengganti resep petak tidak membuang roti yang sudah ada:
## petak menjual habis roti lama, lalu diisi resep baru.

const ART_LIST: float = 44.0

## Tombol Unlock yang tampil: recipe_id -> Button, diperbarui tiap tick.
var _unlock_buttons: Dictionary = {}
## Tombol level resep yang tampil, diperbarui tiap tick.
var _level_rows: Array[BuyButtons] = []


func sheet_title() -> String:
	return Tx.t("ui_tab_menu")


func build_page(body: VBoxContainer) -> void:
	_unlock_buttons.clear()
	_level_rows.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "MenuList"
	lbl(list, Tx.t("ui_menu_slots"), 15, Palette.TEXT_MUTED)
	var shelves: Array[EquipmentInstance] = sim.equipment.placed_list(&"display")
	for n in shelves.size():
		var e: EquipmentInstance = shelves[n]
		lbl(list, Tx.t("ui_menu_shelf", {"n": n + 1, "capacity": sim.display.slot_capacity(e.iid)}), 16, Palette.UI_WOOD, true)
		for i in sim.display.slot_count(e.iid):
			_slot_row(list, e.iid, i)
	lbl(list, Tx.t("ui_menu_recipes"), 15, Palette.TEXT_MUTED)
	for r: RecipeDefinition in DataRegistry.recipes():
		_recipe_row(list, r)


## Satu petak: gambar resep yang sedang dijual, isi petak, dan tombol ganti.
func _slot_row(parent: Control, iid: int, index: int) -> void:
	var rid: StringName = sim.display.effective_recipe(iid, index)
	var auto: bool = sim.display.assignment(iid, index) == &""
	var left: Control = BreadArt.for_recipe(rid, ART_LIST) if rid != &"" else ProceduralUIFactory.icon("box", int(ART_LIST * 0.7), Palette.TEXT_MUTED)
	var title: String = Tx.recipe_name(rid) if rid != &"" else Tx.t("ui_menu_slot_none")
	if auto:
		title = Tx.t("ui_slot_auto_now", {"recipe": title})
	var sub: String = Tx.t("ui_menu_slot_stock", {"n": index + 1, "units": sim.display.slot_units(iid, index), "capacity": sim.display.slot_capacity(iid)})
	var h: HBoxContainer = UISheet.row(parent, title, sub, left)
	h.get_parent().name = "Slot_%d_%d" % [iid, index]
	var b: Button = ProceduralUIFactory.button(Tx.t("ui_menu_change"), "secondary")
	b.name = "Change"
	b.custom_minimum_size = Vector2(maxf(120.0, ProceduralUIFactory._text_width(Tx.t("ui_menu_change"), 18, true) + 40.0), 52)
	b.pressed.connect(func() -> void: push_page(Tx.t("ui_menu_choose_title", {"n": index + 1}), _choose_page.bind(iid, index)))
	h.add_child(b)


## Halaman pilihan resep sebuah petak: Auto lalu setiap resep yang bisa dibuat.
func _choose_page(body: VBoxContainer, iid: int, index: int) -> void:
	_unlock_buttons.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "ChooseList"
	var current: StringName = sim.display.assignment(iid, index)
	var best: StringName = sim.auto_recipe()
	var auto_sub: String = Tx.t("ui_slot_auto_desc", {"recipe": Tx.recipe_name(best) if best != &"" else "-"})
	_choice_row(list, Tx.t("ui_slot_auto"), auto_sub, ProceduralUIFactory.icon("star", int(ART_LIST * 0.7), Palette.GOLD_STAR), current == &"", iid, index, &"")
	for r: RecipeDefinition in DataRegistry.recipes():
		if not sim.can_make(r.id):
			continue
		var sub: String = Tx.t("ui_menu_price", {"price": Tx.kr(sim.unit_price(r.id, iid))})
		_choice_row(list, Tx.recipe_name(r.id), sub, BreadArt.for_recipe(r.id, ART_LIST), current == r.id, iid, index, r.id)


func _choice_row(parent: Control, title: String, sub: String, left: Control, selected: bool, iid: int, index: int, rid: StringName) -> void:
	var h: HBoxContainer = UISheet.row(parent, title, sub, left)
	h.get_parent().name = "Choice_" + (String(rid) if rid != &"" else "auto")
	var b: Button = ProceduralUIFactory.button(Tx.t("ui_menu_selected") if selected else Tx.t("ui_menu_choose"), "primary" if not selected else "secondary")
	b.name = "Pick"
	b.disabled = selected
	b.custom_minimum_size = Vector2(maxf(120.0, ProceduralUIFactory._text_width(b.text, 18, true) + 40.0), 52)
	b.pressed.connect(func() -> void:
		if sim.display.set_assignment(iid, index, rid):
			EventBus.sfx.emit(&"ui_confirm", &"")
			pop_page())
	h.add_child(b)


## Satu resep: gambar, harga jual (atau syarat alat), lalu tombol buka atau
## level resep dengan ×1 / ×10 / Max (GDD idle 8.5).
func _recipe_row(parent: Control, r: RecipeDefinition) -> void:
	var owned: bool = sim.upgrades.is_unlocked(r.id)
	var sub: String = Tx.t("ui_menu_price", {"price": Tx.kr(sim.recipe_price(r.id))})
	if not sim.production.owns_equipment_for(r):
		sub = Tx.t("ui_menu_needs_tier", {"tier": r.recipe_tier()})
	var art: BreadArt = BreadArt.for_recipe(r.id, ART_LIST)
	if not owned:
		art.modulate = Color(1.0, 1.0, 1.0, 0.45)
	var title: String = Tx.recipe_name(r.id)
	if owned:
		var o: Dictionary = sim.upgrades.offer(&"recipe", r.id)
		title = UpgradeInfo.title(sim, o)
		var m: Dictionary = UpgradeInfo.milestone(sim, o)
		if not m.is_empty():
			sub += " · " + str(m["text"])
	var h: HBoxContainer = UISheet.row(parent, title, sub, art)
	h.get_parent().name = "Recipe_" + String(r.id)
	if owned:
		var buy: BuyButtons = BuyButtons.new().setup(sim, &"recipe", r.id, 96.0)
		buy.size_flags_horizontal = Control.SIZE_SHRINK_END
		buy.bought.connect(func(_n: int) -> void: refresh())
		var holder := VBoxContainer.new()
		holder.add_theme_constant_override("separation", 6)
		var pc: Node = h.get_parent()
		pc.remove_child(h)
		holder.add_child(h)
		holder.add_child(buy)
		pc.add_child(holder)
		_level_rows.append(buy)
		return
	# Resep yang belum bisa dibuat alat mana pun hanya menyebut syaratnya.
	if owned or not sim.production.owns_equipment_for(r):
		return
	var text: String = Tx.t("ui_recipe_unlock", {"price": Tx.kr(UpgradeManager.unlock_cost(r))})
	var b: Button = ProceduralUIFactory.icon_text_button("lock", text, "primary", 20, 16)
	b.name = "Unlock"
	b.custom_minimum_size = Vector2(maxf(150.0, ProceduralUIFactory._text_width(text, 16, true) + 20.0 + 8.0 + 36.0), 52)
	b.disabled = sim.upgrades.unlock_block(r.id) != &""
	var rid: StringName = r.id
	b.pressed.connect(func() -> void:
		if sim.upgrades.unlock_recipe(rid):
			refresh())
	h.add_child(b)
	_unlock_buttons[rid] = b


## KR terus berubah: tombol Unlock dan level menyala begitu terjangkau.
func tick_page() -> void:
	for lb: BuyButtons in _level_rows:
		if is_instance_valid(lb):
			lb.refresh()
	for rid: Variant in _unlock_buttons.keys():
		var b: Button = _unlock_buttons[rid]
		if is_instance_valid(b):
			b.disabled = sim.upgrades.unlock_block(rid) != &""
