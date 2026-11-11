class_name MenuScreen
extends UISheet
## Layar Menu (GDD idle 4.2, 8.5, 12.3): kartu Variety (bonus variasi di rak
## dan roti yang sedang dijual, GDD idle §20 no. 83), lalu satu kartu per rak
## dengan ubin petaknya (gambar resep, Auto, isi), lalu daftar resep dengan
## gambar BreadArt, harga jual, dan tombol buka. Mengetuk ubin membuka pilihan
## resep petak itu sebagai halaman berikutnya di lembar yang sama. Mengganti
## resep petak tidak membuang roti yang sudah ada: petak menjual habis roti
## lama, lalu diisi resep baru.

const ART_LIST: float = 44.0
## Ubin petak rak: ukuran, gambar roti, dan ukuran huruf dasar.
const TILE_W: float = 104.0
const TILE_H: float = 112.0
const TILE_ART: float = 50.0
const TILE_TEXT: int = 13

## Tombol Unlock yang tampil: recipe_id -> Button, diperbarui tiap tick.
var _unlock_buttons: Dictionary = {}
## Tombol level resep yang tampil, diperbarui tiap tick.
var _level_rows: Array[BuyButtons] = []
## Craving yang tampil di kartu; halaman dibangun ulang bila hari berganti.
var _shown_craving: StringName = &""
## Ubin petak yang tampil: [{iid, index, recipe, stock: Label}], isinya
## diperbarui tiap tick; resep yang berganti membangun ulang halaman.
var _tiles: Array[Dictionary] = []


func sheet_title() -> String:
	return Tx.t("ui_tab_menu")


func sheet_icon() -> String:
	return "bread"


func build_page(body: VBoxContainer) -> void:
	_unlock_buttons.clear()
	_level_rows.clear()
	_tiles.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "MenuList"
	_variety_card(list)
	section(list, Tx.t("ui_menu_slots"))
	var shelves: Array[EquipmentInstance] = sim.equipment.placed_list(&"display")
	for n in shelves.size():
		_shelf_card(list, shelves[n], n)
	section(list, Tx.t("ui_menu_recipes"))
	_craving_card(list)
	for r: RecipeDefinition in DataRegistry.recipes():
		_recipe_row(list, r)


## Kartu craving hari ini dan roti favorit lokasi (GDD idle 21.1).
func _craving_card(parent: Control) -> void:
	_shown_craving = sim.cravings.today()
	var pc: PanelContainer = card(parent)
	pc.name = "CravingCard"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	pc.add_child(h)
	var rid: StringName = _shown_craving
	var left: Control = BreadArt.for_recipe(rid, 56.0) if rid != &"" else ProceduralUIFactory.badge("star", Palette.HONEY_SOFT, Palette.HONEY_DEEP, 56)
	left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(left)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 3)
	h.add_child(v)
	if rid != &"":
		var t: Label = lbl(v, Tx.t("ui_craving_card_title", {"recipe": Tx.recipe_name(rid)}), 18, Palette.UI_WOOD_DEEP, true)
		t.add_theme_font_override("font", ProceduralUIFactory.display_font())
		t.name = "CravingTitle"
		lbl(v, Tx.t("ui_craving_card_rule", {"best": int(round((DataRegistry.idlef("craving.best_mult") - 1.0) * 100.0))}), 14, Palette.TEXT_MUTED, true)
		if not sim.upgrades.is_unlocked(rid):
			var lk: Label = lbl(v, Tx.t("ui_craving_card_locked"), 14, Palette.HONEY_DEEP, true)
			lk.add_theme_font_override("font", ProceduralUIFactory.display_font())
	else:
		lbl(v, Tx.t("ui_craving_card_none", {"day": DataRegistry.idlei("craving.first_day")}), 15, Palette.UI_WOOD_DEEP, true)
	var names: PackedStringArray = PackedStringArray()
	for fid: StringName in sim.cravings.favorites():
		names.append(Tx.recipe_name(fid))
	var fav: Label = lbl(v, Tx.t("ui_favorite_card", {"recipes": ", ".join(names),
		"percent": int(round((DataRegistry.idlef("craving.favorite_mult") - 1.0) * 100.0))}), 14, Palette.MATCHA_DEEP, true)
	fav.name = "Favorites"
	# Roti khas cabang ini (GDD idle §20 no. 92; cabang pertama tidak punya).
	if sim.prestige.signature() != &"":
		var sig: Label = lbl(v, Tx.t("ui_signature_line", {"recipe": Tx.recipe_name(sim.prestige.signature()),
			"mult": Tx.dec(DataRegistry.idlef("branch.signature_mult"), 1)}), 14, Palette.UI_WOOD, true)
		sig.name = "SignatureLine"
	# Event musiman (GDD idle 21.6).
	if not sim.events.active().is_empty():
		var feat: PackedStringArray = PackedStringArray()
		for fid: StringName in sim.events.featured():
			feat.append(Tx.recipe_name(fid))
		var ev: Label = lbl(v, Tx.t("ui_event_card", {"name": sim.events.names(), "date": Tx.short_date(sim.events.last_end()),
			"recipes": ", ".join(feat), "percent": int(round((DataRegistry.idlef("events.featured_mult") - 1.0) * 100.0))}), 14, Palette.APRON_NAVY, true)
		ev.name = "EventLine"


## Pil "Craving" dan "Local favorite" di bawah teks baris resep `rid`.
func _tags(h: HBoxContainer, rid: StringName) -> void:
	var text_col: VBoxContainer = h.get_meta("text") as VBoxContainer
	if text_col == null:
		return
	var tags := HBoxContainer.new()
	tags.name = "Tags"
	tags.add_theme_constant_override("separation", 6)
	if rid == sim.cravings.today():
		var cp: PanelContainer = ProceduralUIFactory.pill("star", Tx.t("ui_craving_pill"), Palette.HONEY_SOFT, Palette.HONEY_DEEP, 13)
		cp.name = "CravingPill"
		tags.add_child(cp)
	if sim.cravings.is_favorite(rid):
		var fp: PanelContainer = ProceduralUIFactory.pill("heart", Tx.t("ui_favorite_pill"), Palette.MATCHA_SOFT, Palette.MATCHA_DEEP, 13)
		fp.name = "FavoritePill"
		tags.add_child(fp)
	if rid != &"" and rid == sim.prestige.signature():
		var sp: PanelContainer = ProceduralUIFactory.pill("star", Tx.t("ui_signature_pill"), Palette.BUTTER_SOFT, Palette.UI_WOOD_DEEP, 13)
		sp.name = "SignaturePill"
		tags.add_child(sp)
	if sim.events.is_featured(rid):
		var ep: PanelContainer = ProceduralUIFactory.pill("party", Tx.t("ui_event_pill"), Palette.PASTEL_PERIWINKLE.lightened(0.45), Palette.APRON_NAVY, 13)
		ep.name = "EventPill"
		tags.add_child(ep)
	if tags.get_child_count() > 0:
		text_col.add_child(tags)
	else:
		tags.free()



## Kartu Variety (GDD idle §20 no. 83): pengali harga dari jumlah resep
## berbeda di rak, aturannya, dan roti yang sedang dijual.
func _variety_card(parent: Control) -> void:
	var pc: PanelContainer = card(parent)
	pc.name = "VarietyCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var t: Label = lbl(v, Tx.t("ui_variety_title", {"mult": Tx.dec(sim.variety_mult(), 2)}), 18, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	t.name = "VarietyTitle"
	var rule: Label = lbl(v, Tx.t("ui_variety_desc_one" if sim.shelf_variety() == 1 else "ui_variety_desc", {"count": sim.shelf_variety(),
		"percent": int(round(DataRegistry.idlef("variety.bonus_per_recipe") * 100.0)), "max": DataRegistry.idlei("variety.max_recipes")}), 14, Palette.TEXT_MUTED, true)
	rule.name = "VarietyRule"
	var flow := HFlowContainer.new()
	flow.name = "SellingNow"
	flow.add_theme_constant_override("h_separation", 12)
	flow.add_theme_constant_override("v_separation", 6)
	v.add_child(flow)
	for rid: Variant in sim.menu_recipes():
		var chip := HBoxContainer.new()
		chip.add_theme_constant_override("separation", 4)
		chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var art: BreadArt = BreadArt.for_recipe(StringName(str(rid)), 30.0)
		art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_child(art)
		chip.add_child(ProceduralUIFactory.label(Tx.recipe_name(StringName(str(rid))), 14, Palette.UI_WOOD_DEEP))
		flow.add_child(chip)


## Satu rak: judulnya lalu ubin setiap petak, mengalir ke baris berikutnya bila
## tidak muat.
func _shelf_card(parent: Control, e: EquipmentInstance, n: int) -> void:
	var pc: PanelContainer = card(parent)
	pc.name = "Shelf_%d" % e.iid
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var head: Label = lbl(v, Tx.t("ui_menu_shelf", {"n": n + 1, "capacity": sim.display.slot_capacity(e.iid)}), 16, Palette.UI_WOOD_DEEP, true)
	head.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var flow := HFlowContainer.new()
	flow.name = "Slots"
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	for i in sim.display.slot_count(e.iid):
		flow.add_child(_slot_tile(e.iid, i))


## Satu petak sebagai ubin yang bisa diketuk ("Change"): gambar resep yang
## sedang dijual, nomor petak dan Auto, lalu isinya.
func _slot_tile(iid: int, index: int) -> Control:
	var rid: StringName = sim.display.effective_recipe(iid, index)
	var auto: bool = sim.display.assignment(iid, index) == &""
	var holder := MarginContainer.new()
	holder.name = "Slot_%d_%d" % [iid, index]
	var b: Button = ProceduralUIFactory.button("", "secondary")
	b.name = "Change"
	b.custom_minimum_size = Vector2(TILE_W, TILE_H)
	b.clip_contents = true
	b.tooltip_text = "%s · %s" % [Tx.recipe_name(rid) if rid != &"" else Tx.t("ui_menu_slot_none"), Tx.t("ui_menu_change")]
	b.pressed.connect(func() -> void: push_page(Tx.t("ui_menu_choose_title", {"n": index + 1}), _choose_page.bind(iid, index)))
	holder.add_child(b)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var art: Control = BreadArt.for_recipe(rid, TILE_ART) if rid != &"" else ProceduralUIFactory.icon("box", int(TILE_ART * 0.7), Palette.TEXT_MUTED)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	var name_l: Label = ProceduralUIFactory.label(Tx.t("ui_slot_tile_auto" if auto else "ui_slot_tile", {"n": index + 1}), TILE_TEXT, Palette.UI_WOOD_DEEP)
	name_l.name = "SlotName"
	name_l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.set_meta("base_size", TILE_TEXT)
	v.add_child(name_l)
	BuyButtons.fit_label(name_l, TILE_W - 2.0 * BuyButtons.FIT_PAD)
	var stock: Label = ProceduralUIFactory.label("", TILE_TEXT, Palette.TEXT_MUTED)
	stock.name = "Stock"
	stock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock.set_meta("base_size", TILE_TEXT)
	v.add_child(stock)
	var t: Dictionary = {"iid": iid, "index": index, "recipe": rid, "stock": stock}
	_tiles.append(t)
	_tile_stock(t)
	return holder


## Isi petak sebuah ubin ("7/13").
func _tile_stock(t: Dictionary) -> void:
	var l: Label = t["stock"]
	if not is_instance_valid(l):
		return
	l.text = Tx.t("ui_slot_tile_stock", {"units": sim.display.slot_units(int(t["iid"]), int(t["index"])), "capacity": sim.display.slot_capacity(int(t["iid"]))})
	BuyButtons.fit_label(l, TILE_W - 2.0 * BuyButtons.FIT_PAD)


## Halaman pilihan resep sebuah petak: Auto lalu setiap resep yang bisa dibuat.
func _choose_page(body: VBoxContainer, iid: int, index: int) -> void:
	_unlock_buttons.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "ChooseList"
	var current: StringName = sim.display.assignment(iid, index)
	var best: StringName = sim.auto_slot_recipe(iid, index)
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
	if rid != &"":
		_tags(h, rid)
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
		# Mastery resep (GDD idle 23.3): bintang dan roti terjual menuju bintang berikutnya.
		var nxt: int = sim.mastery.next_threshold(r.id)
		var mp: Dictionary = {"level": sim.mastery.level(r.id), "sold": Tx.big(float(sim.mastery.units(r.id))), "next": Tx.big(float(nxt))}
		sub += "\n" + Tx.t("ui_mastery_row_next" if nxt > 0 else "ui_mastery_row", mp)
	var h: HBoxContainer = UISheet.row(parent, title, sub, art)
	h.get_parent().name = "Recipe_" + String(r.id)
	_tags(h, r.id)
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
			refresh()
			# Sorotan resep baru di atas lembar ini (GDD idle §20 no. 73).
			if host != null:
				host.close_id(&"recipe_reveal")
				host.open(&"recipe_reveal", {"recipe": rid}))
	h.add_child(b)
	_unlock_buttons[rid] = b


## Tombol Unlock pertama yang bisa diketuk sekarang (panduan onboarding, GDD
## idle 13), atau null.
func unlock_button() -> Button:
	for r: RecipeDefinition in DataRegistry.recipes():
		var b: Button = _unlock_buttons.get(r.id)
		if b != null and is_instance_valid(b) and not b.disabled and b.is_visible_in_tree():
			return b
	return null


## KR terus berubah: tombol Unlock dan level menyala begitu terjangkau. Craving
## baru (pukul 00:00) membangun ulang halaman utama.
func tick_page() -> void:
	if page_depth() == 0 and sim.cravings.today() != _shown_craving:
		refresh()
		return
	if page_depth() == 0:
		for t: Dictionary in _tiles:
			if sim.display.effective_recipe(int(t["iid"]), int(t["index"])) != StringName(t["recipe"]):
				# Rencana Auto berganti (resep baru, level, variasi): ubin dan
				# kartu Variety dibangun ulang.
				refresh()
				return
		for t2: Dictionary in _tiles:
			_tile_stock(t2)
	for lb: BuyButtons in _level_rows:
		if is_instance_valid(lb):
			lb.refresh()
	for rid: Variant in _unlock_buttons.keys():
		var b: Button = _unlock_buttons[rid]
		if is_instance_valid(b):
			b.disabled = sim.upgrades.unlock_block(rid) != &""
