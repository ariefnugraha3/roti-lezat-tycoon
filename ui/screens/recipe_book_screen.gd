class_name RecipeBookScreen
extends UIScreen
## Buku Resep (GDD 5.3, 7, 61, 63.2, 92.4). Dibuka dengan mengetuk Storage;
## tombol Make hanya membuat job. Semua angka dibaca dari katalog.
##
## Tutorial Hari 1 (keputusan maintainer 2026-10-07, GDD 88.1): Buku Resep
## pertama dibuka dengan tur sorotan (daftar resep, bahan, peralatan, harga,
## ukuran batch, lalu Make), yang kedua dengan tur singkat (daftar, lalu Make).
##
## Tata letak (perbaikan 2026-10-02): hanya daftar resep di kiri yang digulir.
## Setiap resep bergambar roti flat (BreadArt, keputusan maintainer 2026-10-04):
## kecil di baris daftar, besar di samping judul rincian.
## Rincian di kanan muat tanpa gulir: judul dengan chip alat, kartu Ingredients
## dan Details berdampingan, satu baris harga (label, slider, nilai), satu baris
## reaksi pembeli dan harga referensi, lalu ukuran batch dan tombol Make dalam
## satu baris. Area rinciannya tetap ScrollContainer sebagai cadangan untuk
## skala teks besar.

const REACTION_KEYS: Dictionary = {
	&"VERY_HAPPY": "price_very_happy", &"HAPPY": "price_happy", &"NEUTRAL": "price_neutral",
	&"UNHAPPY": "price_unhappy", &"VERY_UNHAPPY": "price_very_unhappy", &"REFUSE": "price_refuse",
}
const REACTION_ICONS: Dictionary = {
	&"VERY_HAPPY": "heart", &"HAPPY": "happy", &"NEUTRAL": "bubble",
	&"UNHAPPY": "sad", &"VERY_UNHAPPY": "angry", &"REFUSE": "cross",
}
## Sisi gambar roti (BreadArt) di baris daftar dan di samping judul rincian (px).
## Di atas skala teks 100% rincian hampir tidak bersisa ruang, jadi gambar judul
## mengecil setinggi judulnya supaya rincian tetap muat tanpa gulir.
const LIST_ART: float = 46.0
const HERO_ART: float = 96.0
const HERO_ART_LARGE_TEXT: float = 44.0

var _selected: StringName = &""
var _batch: int = 1
var _tab: int = 0
var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _price_label: Label = null
var _reaction: Label = null
var _reaction_icon: IconCanvas = null
var _tour: CoachMarks = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_recipe_book"), Vector2(1180, 660))
	body.add_child(ProceduralUIFactory.tab_bar([Tx.t("ui_recipe_tab_recipes"), Tx.t("ui_recipe_tab_analytics")], _tab, func(idx: int) -> void:
		_tab = idx
		_render_detail()))
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
	var tour: StringName = sim.tutorial.recipe_tour()
	if tour != &"":
		_start_tour.call_deferred(tour)
	else:
		_start_tips.call_deferred()


## Tur sekali (GDD 88.4): slider harga begitu harga boleh diatur, dan Ask a Baker
## begitu ada Kitchen Assistant.
func _start_tips() -> void:
	if is_queued_for_deletion():
		return
	var steps: Array[Dictionary] = []
	if not sim.pricing.prices_locked() and sim.tutorial.screen_tour(&"pricing"):
		sim.tutorial.mark_tour(&"pricing")
		steps.append({"targets": _tour_nodes.bind(["PriceRow", "PriceNote"]), "key": "tut_pricing", "next": true})
	if not sim.staff.employed_ids(&"baker").is_empty() and sim.tutorial.screen_tour(&"ask_baker"):
		sim.tutorial.mark_tour(&"ask_baker")
		steps.append({"targets": _tour_nodes.bind(["AskBaker"]), "key": "tut_ask_baker", "next": true})
	if steps.is_empty():
		return
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup(steps)


## Tur sorotan tutorial (GDD 88.1). Sasarannya dicari ulang tiap frame lewat
## namanya, jadi tetap benar walau rinciannya dibangun ulang (mis. ganti batch).
func _start_tour(kind: StringName) -> void:
	if not is_inside_tree():
		return
	var list_area := func() -> Array: return [_list.get_parent()]
	var steps: Array[Dictionary] = []
	if kind == &"full":
		steps = [
			{"targets": list_area, "key": "tut_tour_list", "next": true},
			{"targets": _tour_nodes.bind(["IngredientsCard"]), "key": "tut_tour_ingredients", "next": true},
			{"targets": _tour_nodes.bind(["EquipmentChip"]), "key": "tut_tour_equipment", "next": true},
			{"targets": _tour_nodes.bind(["PriceRow", "PriceNote"]), "key": "tut_tour_price", "next": true},
			{"targets": _tour_nodes.bind(["BatchLabel", "Batch1", "Batch3", "Batch5"]), "key": "tut_tour_batch", "next": true},
			{"targets": _tour_nodes.bind(["Make"]), "key": "tut_tour_make", "next": false},
		]
	else:
		steps = [
			{"targets": list_area, "key": "tut_tour_again_list", "next": true},
			{"targets": _tour_nodes.bind(["MakeRow"]), "key": "tut_tour_again_make", "next": false},
		]
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup(steps)


func _tour_nodes(names: Array) -> Array:
	var out: Array = []
	for n: Variant in names:
		var c: Node = _detail.find_child(str(n), true, false)
		if c != null:
			out.append(c)
	return out


## Tur yang sedang berjalan (untuk tes), atau null.
func tour() -> CoachMarks:
	return _tour if _tour != null and is_instance_valid(_tour) else null


func _render_list() -> void:
	clear(_list)
	var last_cat: StringName = &""
	for r: RecipeDefinition in DataRegistry.recipes():
		if r.category_id != last_cat:
			last_cat = r.category_id
			lbl(_list, "Tier %d" % r.required_mixer_tier, 14, Palette.TEXT_MUTED)
		_list.add_child(_row(r))


## Satu baris daftar: gambar roti flat (keputusan maintainer 2026-10-04) lalu
## namanya. Lebar daftar tetap; nama yang terlalu panjang (skala teks besar)
## dipotong dengan elipsis alih-alih melebarkan daftar dan menyempitkan rincian.
func _row(r: RecipeDefinition) -> Button:
	var reason: String = sim.production.make_block_reason(r.id, 1)
	var kind: String = "primary" if r.id == _selected else ("secondary" if reason == "" else "ghost")
	var b: Button = ProceduralUIFactory.button("", kind)
	b.name = String(r.id)
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = Tx.recipe_name(r.id)
	var ink: Color = ProceduralUIFactory.kind_colors(kind)["ink"]
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 6.0
	row.offset_right = -14.0
	row.offset_bottom = -ProceduralUIFactory.content_lift()
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	row.add_child(BreadArt.for_recipe(r.id, LIST_ART))
	var n: Label = ProceduralUIFactory.label(Tx.recipe_name(r.id), ProceduralUIFactory.FONT_BODY, ink)
	n.add_theme_font_override("font", ProceduralUIFactory.display_font())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(n)
	var rid: StringName = r.id
	b.pressed.connect(func() -> void:
		_selected = rid
		_render_list()
		_render_detail())
	return b


func _render_detail() -> void:
	clear(_detail)
	var r: RecipeDefinition = DataRegistry.recipe(_selected)
	if r == null:
		return
	var head: HBoxContainer = hbox(_detail, 12)
	head.add_child(BreadArt.for_recipe(r.id, HERO_ART if ProceduralUIFactory.text_scale <= 1.0 else HERO_ART_LARGE_TEXT))
	var title: Label = lbl(head, Tx.recipe_name(r.id), 26, Palette.UI_WOOD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.clip_text = true
	title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	if _tab == 1:
		_render_analytics(r)
		return
	var chip: PanelContainer = _chip(Tx.t("ui_recipe_equipment", {"mixer": r.required_mixer_tier, "oven": r.required_oven_tier}))
	chip.name = "EquipmentChip"
	head.add_child(chip)
	# Rincian lebih lebar dari bahan: barisnya lebih panjang, jadi tidak terlipat
	# (juga pada skala teks 125%).
	var cols: HBoxContainer = hbox(_detail, 14)
	var ing_box: VBoxContainer = _card(cols, 0.8)
	ing_box.get_parent().name = "IngredientsCard"
	_build_ingredients(r, ing_box)
	_build_facts(r, _card(cols, 1.2))
	_detail.add_child(ProceduralUIFactory.dashed_separator())
	_build_price(r)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 2)
	_detail.add_child(gap)
	_build_make(r)


## Kartu isi lembut berwarna krem tua (tanpa bayangan) yang mengisi separuh lebar.
func _card(parent: Control, ratio: float) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.UI_CREAM_DEEP, 0.5), 16, false)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 8.0
	sb.content_margin_bottom = 8.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.size_flags_stretch_ratio = ratio
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 3)
	pc.add_child(v)
	return v


## Chip kecil di kanan judul (kebutuhan alat).
func _chip(text: String) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM_DEEP, 14, false)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 4.0
	sb.content_margin_bottom = 4.0
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pc.add_child(ProceduralUIFactory.label(text, 14, Palette.UI_WOOD_DEEP))
	return pc


## Bahan sebagai tabel kecil: judul kolom "Have / Need" di kanan, lalu satu
## baris per bahan dengan angka punya / butuh rata kanan (merah bila kurang).
func _build_ingredients(r: RecipeDefinition, box: VBoxContainer) -> void:
	var head: HBoxContainer = hbox(box, 6)
	var t: Label = lbl(head, Tx.t("ui_recipe_ingredients"), 17, Palette.UI_WOOD)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl(head, Tx.t("ui_recipe_have_need"), 14, Palette.TEXT_MUTED)
	for ing: StringName in r.ingredients.keys():
		var need: int = int(r.ingredients[ing]) * _batch
		var have: int = sim.inventory.count(ing)
		var ink: Color = Palette.TEXT if have >= need else Palette.DANGER
		var row: HBoxContainer = hbox(box, 6)
		row.add_child(ProceduralUIFactory.icon("check" if have >= need else "cross", 16, Palette.SUCCESS if have >= need else Palette.DANGER))
		var n: Label = lbl(row, Tx.item_name(ing), 15, ink)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		lbl(row, "%d / %d" % [have, need], 15, ink)


## Rincian: hasil & biaya, waktu, umur simpan, dan penggemarnya, masing-masing
## dengan ikon supaya mudah dipindai.
func _build_facts(r: RecipeDefinition, box: VBoxContainer) -> void:
	lbl(box, Tx.t("ui_recipe_details"), 17, Palette.UI_WOOD)
	var mixer: EquipmentInstance = sim.production.free_mixer_for(r)
	var oven: EquipmentInstance = sim.production.free_oven_for(r)
	var mt: int = mixer.tier() if mixer != null else r.required_mixer_tier
	var ot: int = oven.tier() if oven != null else r.required_oven_tier
	var oven_def: EquipmentDefinition = DataRegistry.equipment_for(&"oven", ot)
	_fact(box, "box", "%s · %s" % [Tx.t("ui_recipe_yield", {"count": r.batch_yield * _batch}), Tx.t("ui_recipe_cogs", {"cost": Tx.kr(r.unit_cogs_kr())})])
	_fact(box, "clock", "%s · %s · %s" % [
		Tx.t("ui_recipe_mix_time", {"seconds": "%.1f" % DataRegistry.real_seconds(sim.production.mixer_stage_seconds(r, mt, _batch, 1.0))}),
		Tx.t("ui_recipe_bake_time", {"seconds": "%.1f" % DataRegistry.real_seconds(sim.production.oven_stage_seconds(r, ot, _batch, 1.0))}),
		Tx.t("ui_recipe_burn_grace", {"seconds": "%d" % roundi(DataRegistry.real_seconds(oven_def.burn_grace_seconds()))})])
	_fact(box, "hourglass", Tx.t("ui_recipe_expires", {"hours": str(snappedf(r.expired_duration_hours, 0.01))}))
	var tags: PackedStringArray = PackedStringArray()
	for t: StringName in r.customer_tags:
		tags.append(Tx.t("tag_" + String(t)))
	_fact(box, "heart", Tx.t("ui_recipe_tags", {"tags": ", ".join(tags)}))


func _fact(box: VBoxContainer, icon_name: String, text: String) -> void:
	var row: HBoxContainer = hbox(box, 6)
	var ic: IconCanvas = ProceduralUIFactory.icon(icon_name, 16, Palette.UI_WOOD)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(ic)
	lbl(row, text, 15, Palette.TEXT, true)


## Ukuran batch, tombol "Ask a Baker" (bila ada koki yang direkrut), dan tombol
## Make dalam satu baris; alasan bila belum bisa dibuat. Koki hanya membuat
## resep yang dipesan pemain di sini (GDD 3.2, 23.3; keputusan maintainer
## 2026-10-02).
func _build_make(r: RecipeDefinition) -> void:
	var row: HBoxContainer = hbox(_detail, 8)
	row.name = "MakeRow"
	lbl(row, Tx.t("ui_recipe_batch"), 17, Palette.UI_WOOD).name = "BatchLabel"
	for b: int in DataRegistry.bal("production.batch_multipliers"):
		var bb: Button = ProceduralUIFactory.button("x%d" % b, "primary" if b == _batch else "secondary")
		bb.name = "Batch%d" % b
		bb.custom_minimum_size = Vector2(64, ProceduralUIFactory.TOUCH_MIN)
		bb.pressed.connect(func() -> void:
			_batch = b
			_render_detail())
		row.add_child(bb)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var reason: String = sim.production.make_block_reason(r.id, _batch)
	var ask_reason: String = ""
	if not sim.staff.employed_ids(&"baker").is_empty():
		ask_reason = sim.staff.ask_block_reason(r.id, _batch)
		var ask: Button = ProceduralUIFactory.icon_text_button("chef", Tx.t("ui_recipe_ask_baker"), "secondary", 22, 17)
		ask.name = "AskBaker"
		ask.custom_minimum_size = Vector2(maxf(190.0, ask.custom_minimum_size.x), 52)
		ask.disabled = ask_reason != ""
		ask.pressed.connect(_ask)
		row.add_child(ask)
	var make: Button = ProceduralUIFactory.button(Tx.t("ui_make"), "primary")
	make.name = "Make"
	make.custom_minimum_size = Vector2(170, 52)
	make.disabled = reason != ""
	make.pressed.connect(_make)
	row.add_child(make)
	if reason != "":
		lbl(_detail, Tx.t(reason, {"mixer": r.required_mixer_tier, "oven": r.required_oven_tier}), 15, Palette.DANGER, true)
	elif ask_reason != "":
		lbl(_detail, Tx.t(ask_reason), 15, Palette.TEXT_MUTED, true)


## Harga: label, slider, dan nilai dalam satu baris; reaksi pembeli dan harga
## referensi di baris berikutnya.
func _build_price(r: RecipeDefinition) -> void:
	var row: HBoxContainer = hbox(_detail, 12)
	row.name = "PriceRow"
	lbl(row, Tx.t("ui_recipe_price"), 17, Palette.UI_WOOD)
	var sl := HSlider.new()
	sl.min_value = r.min_price_kr
	sl.max_value = r.max_price_kr
	sl.step = r.price_step_kr
	sl.value = sim.pricing.price_of(r.id)
	sl.custom_minimum_size = Vector2(200, 48)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	_price_label = lbl(row, "", 20, Palette.GOLDEN_CRUST)
	_price_label.custom_minimum_size = Vector2(84, 0)
	_price_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rrow: HBoxContainer = hbox(_detail, 8)
	rrow.name = "PriceNote"
	_reaction_icon = ProceduralUIFactory.icon("happy", 24, Palette.GOLD_STAR)
	rrow.add_child(_reaction_icon)
	_reaction = lbl(rrow, "", 16)
	_reaction.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Hari 1-3 harga terkunci di harga referensi (GDD 63.2): catatannya mengganti
	# harga referensi & rentang di baris yang sama, karena keduanya belum berlaku.
	var locked: bool = sim.pricing.prices_locked()
	var note: String = Tx.t("ui_recipe_price_locked") if locked else "%s · %s" % [
		Tx.t("ui_recipe_default_price", {"price": Tx.kr(r.base_sell_price_kr)}),
		Tx.t("ui_recipe_price_range", {"min": Tx.kr(r.min_price_kr), "max": Tx.kr(r.max_price_kr)})]
	var ref: Label = lbl(rrow, note, 14, Palette.DANGER if locked else Palette.TEXT_MUTED)
	ref.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	if locked:
		sl.editable = false
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
	_reaction_icon.configure(str(REACTION_ICONS.get(label, "bubble")), 24, col)


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


## "Ask a Baker": koki yang bertugas mengerjakan seluruh langkahnya.
func _ask() -> void:
	var reason: String = sim.staff.order_recipe(_selected, _batch)
	if reason != "":
		EventBus.sfx.emit(&"ui_error", &"")
		_render_detail()
		return
	EventBus.sfx.emit(&"ui_confirm", &"")
	EventBus.notify.emit(2, "ui_baker_order_placed", {"recipe": Tx.recipe_name(_selected), "batch": _batch}, &"chef")
	close()


func on_closed() -> void:
	sim.player.close_storage()
