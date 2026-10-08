class_name MarketScreen
extends UIScreen
## Pasar (GDD 5.1.2, 5.2, 7, 24A, 47, 64): tab Ingredients, Equipment, Store
## Upgrade. Membuka Pasar selalu mem-pause simulasi. Equipment & Store Upgrade
## hanya aktif after-hours; di waktu lain tampil read-only. Ketiga tab memakai
## tabel papan kapur yang sama (perbaikan 2026-10-07): kolom berlebar tetap,
## baris berselang-seling, dan judul bagian berkapur kuning.

## Tabel bahan: jarak antar-kolom, jarak tepi baris, dan tinggi baris (px).
const COL_SEP: int = 16
const ROW_PAD: int = 12
const ROW_MIN_H: float = 56.0
## Kapur kuning: judul kategori dan jumlah yang sedang dipilih.
const CHALK_YELLOW: Color = Palette.BUTTER_YELLOW
## Kapur pudar: header kolom, satuan, dan barang yang sedang dikirim.
const CHALK_MUTED: Color = Color(Palette.CHALK_WHITE, 0.68)
## Kapur hijau muda: jumlah alat yang sudah dimiliki.
const CHALK_GREEN: Color = Palette.PASTEL_MINT
## Kapur merah muda: alat yang butuh tier toko lebih tinggi.
const CHALK_PINK: Color = Palette.PASTEL_STRAWBERRY
## Baris alat yang terkunci tier dibuat pudar.
const LOCKED_ALPHA: float = 0.55
## Tinggi baris tabel perbandingan lokasi (px).
const COMPARE_ROW_H: float = 30.0
## Judul kolom angka pertama tabel alat menurut kategori.
const STAT_HEADERS: Dictionary = {&"mixer": "ui_equipment_col_mix", &"oven": "ui_equipment_col_bake", &"display": "ui_equipment_col_holds"}

var _tab: int = 0
var _tabs: ProceduralUIFactory.CozyTabs = null
var _tour: CoachMarks = null
var _body: VBoxContainer = null
var _qty: Dictionary = {}
var _total: Label = null
var _cap: Label = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_market"), Vector2(1180, 660))
	_tab = int(params.get("tab", 0))
	var touring: bool = sim.supply.market_unlocked and sim.tutorial.screen_tour(&"market")
	if touring:
		_tab = 0
	_tabs = ProceduralUIFactory.tab_bar([Tx.t("ui_market_tab_ingredients"), Tx.t("ui_market_tab_equipment"),
		Tx.t("ui_market_tab_upgrade")], _tab, func(idx: int) -> void:
			_tab = idx
			_render())
	body.add_child(_tabs)
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_body)
	_render()
	if touring:
		sim.tutorial.mark_tour(&"market")
		_start_tour.call_deferred()


## Tur Market sekali (GDD 88.4): bahan, membeli, alat, lalu pindah lokasi. Tiap
## langkah membuka tabnya sendiri; sasaran dicari ulang lewat nama tiap frame.
func _start_tour() -> void:
	if is_queued_for_deletion():
		return
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup([
		{"enter": _show_tab.bind(0), "targets": _named.bind(["IngredientRows"]), "key": "tut_market_ingredients", "next": true},
		{"enter": _show_tab.bind(0), "targets": _named.bind(["BuyRow", "DeliveryNote"]), "key": "tut_market_buy", "next": true},
		{"enter": _show_tab.bind(1), "targets": _named.bind(["EquipmentRows"]), "key": "tut_market_equipment", "next": true},
		{"enter": _show_tab.bind(2), "targets": _named.bind(["UpgradeRows", "Upgrade"]), "key": "tut_market_upgrade", "next": true},
	])


func _show_tab(idx: int) -> void:
	if _tab == idx:
		return
	_tab = idx
	_tabs.select(idx)
	_render()


## Node bernama di layar ini (yang terlihat saja); ScrollContainer daftar dipakai
## utuh supaya sorotannya selebar tabel.
func _named(names: Array) -> Array:
	var out: Array = []
	for n: Variant in names:
		var c: Node = find_child(str(n), true, false)
		if c == null:
			continue
		out.append(c.get_parent() if c.get_parent() is ScrollContainer else c)
	return out


func tour() -> CoachMarks:
	return _tour if _tour != null and is_instance_valid(_tour) else null


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

## Tabel bahan di papan kapur (perbaikan 2026-10-07, GDD 7): header tetap di
## atas, baris bahan digulir di bawahnya. Semua kolom selain nama berlebar tetap,
## dihitung dari teks terpanjang pada skala teks yang dipakai, jadi header dan
## setiap baris selalu lurus apa pun panjang nama atau harganya.
func _render_ingredients() -> void:
	if not sim.supply.market_unlocked:
		lbl(_body, Tx.t("ui_market_locked"), 18, Palette.DANGER, true)
		return
	var board: PanelContainer = ProceduralUIFactory.chalkboard_panel()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(board)
	var inner: VBoxContainer = ProceduralUIFactory.content_of(board)
	var head := MarginContainer.new()
	head.name = "TableHeader"
	inner.add_child(head)
	inner.add_child(ProceduralUIFactory.dashed_separator(Palette.CHALK_WHITE))
	var list: VBoxContainer = scroll_box(inner)
	list.name = "IngredientRows"
	list.add_theme_constant_override("separation", 2)
	# Scrollbar selalu tampil: lebar baris tetap sama, dan header menyisakan
	# tempat yang sama di kanan, sehingga kolomnya lurus dengan baris.
	var sc: ScrollContainer = list.get_parent() as ScrollContainer
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	var widths: Dictionary = _ingredient_widths()
	var shades: Array[StyleBoxFlat] = [_row_style(true), _row_style(false)]
	var last_cat: StringName = &""
	var n: int = 0
	var amount_w: float = 0.0
	for ing: IngredientDefinition in DataRegistry.ingredients():
		if ing.category_id != last_cat:
			last_cat = ing.category_id
			list.add_child(_section_heading(Tx.t("ingredient_category_" + String(ing.category_id)), list.get_child_count() > 0))
			n = 0
		var row: PanelContainer = _ingredient_row(ing, widths, shades[n % 2])
		list.add_child(row)
		amount_w = maxf(amount_w, (row.find_child("Amount", true, false) as Control).get_combined_minimum_size().x)
		n += 1
	head.add_theme_constant_override("margin_left", ROW_PAD)
	head.add_theme_constant_override("margin_right", ROW_PAD + _scrollbar_room(sc))
	head.add_theme_constant_override("margin_bottom", 2)
	head.add_child(_column_labels([["ui_market_col_ingredient", -1.0, HORIZONTAL_ALIGNMENT_LEFT],
		["ui_market_col_price", float(widths["price"]), HORIZONTAL_ALIGNMENT_RIGHT],
		["ui_market_col_stock", float(widths["stock"]), HORIZONTAL_ALIGNMENT_CENTER],
		["ui_market_col_amount", amount_w, HORIZONTAL_ALIGNMENT_CENTER]]))
	var foot: HBoxContainer = hbox(_body, 14)
	foot.name = "BuyRow"
	_cap = lbl(foot, "", 16)
	_total = lbl(foot, "", 20, Palette.GOLDEN_CRUST)
	_total.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var buy: Button = btn(foot, Tx.t("ui_market_buy"), "primary", _buy)
	buy.custom_minimum_size = Vector2(200, 56)
	var note: Label = lbl(_body, Tx.t("ui_market_after_hours_note") if sim.time.is_after_hours() else Tx.t("ui_market_delivery_note"), 14, Palette.TEXT_MUTED, true)
	note.name = "DeliveryNote"
	_update_totals()


## Lebar kolom harga, stok, dan jumlah: teks terpanjang yang mungkin tampil
## (harga termahal, stok/jumlah empat digit untuk gudang Tier 5).
func _ingredient_widths() -> Dictionary:
	var price_w: float = _text_w(Tx.t("ui_market_col_price"), 14)
	for ing: IngredientDefinition in DataRegistry.ingredients():
		price_w = maxf(price_w, _text_w(Tx.kr(ing.fixed_buy_price_kr), 17))
	var stock_w: float = maxf(maxf(_text_w(Tx.t("ui_market_col_stock"), 14), _text_w("9999", 17)),
		_text_w(Tx.t("ui_market_arriving", {"count": 999, "time": Tx.clock(23.0 * 3600.0 + 59.0 * 60.0)}), 13))
	return {"price": ceilf(price_w) + 4.0, "stock": ceilf(stock_w) + 8.0, "qty": ceilf(_text_w("9999", 18)) + 6.0}


## Lebar yang dipakai scrollbar vertikal di kanan isi: batangnya ditambah
## jaraknya dari isi (`scrollbar_v_separation` tema). Judul kolom di luar area
## gulir menyisakan tempat yang sama supaya tetap lurus dengan barisnya.
static func _scrollbar_room(sc: ScrollContainer) -> int:
	return int(ceilf(sc.get_v_scroll_bar().get_combined_minimum_size().x)) + sc.get_theme_constant("scrollbar_v_separation")


static func _text_w(text: String, size: int) -> float:
	return ProceduralUIFactory.cozy_font(1).get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, ProceduralUIFactory.scaled(size)).x


## Latar baris: selang-seling sedikit lebih terang, rata (tanpa bayangan).
static func _row_style(shaded: bool, vpad: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Palette.CHALK_WHITE, 0.07 if shaded else 0.0)
	sb.draw_center = shaded
	sb.set_corner_radius_all(12)
	sb.content_margin_left = ROW_PAD
	sb.content_margin_right = ROW_PAD
	sb.content_margin_top = vpad
	sb.content_margin_bottom = vpad
	return sb


## Samakan lebar sel-sel satu kolom (isi baris dan judulnya) dengan yang
## terlebar, diukur di dalam pohon adegan sesudah semua baris dibangun.
static func _equalize(cells: Array[Control]) -> void:
	var widest: float = 0.0
	for c: Control in cells:
		widest = maxf(widest, c.get_combined_minimum_size().x)
	for c2: Control in cells:
		c2.custom_minimum_size.x = widest


static func _chalk(text: String, size: int, color: Color = Palette.CHALK_WHITE) -> Label:
	var l: Label = ProceduralUIFactory.chalk_label(text, size)
	l.add_theme_color_override("font_color", color)
	return l


## Judul bagian berkapur kuning, dengan catatan pudar di kanan (opsional).
func _section_heading(text: String, gap: bool, note: String = "") -> Control:
	var m := MarginContainer.new()
	m.name = "Heading_%s" % text.validate_node_name()
	m.add_theme_constant_override("margin_left", ROW_PAD)
	m.add_theme_constant_override("margin_right", ROW_PAD)
	m.add_theme_constant_override("margin_top", 10 if gap else 2)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", COL_SEP)
	m.add_child(h)
	var t: Label = _chalk(text, 18, CHALK_YELLOW)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if note != "":
		var n: Label = _chalk(note, 14, CHALK_MUTED)
		n.name = "Note"
		h.add_child(n)
	return m


## Baris judul kolom: [kunci string, lebar (-1 = mengisi sisa), perataan].
## Kunci kosong = kolom tanpa judul (mis. tombol aksi).
func _column_labels(cols: Array, node_name: String = "Columns") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = node_name
	h.add_theme_constant_override("separation", COL_SEP)
	for c: Array in cols:
		var key: String = str(c[0])
		var cell: Control
		if key != "":
			var l: Label = _chalk(Tx.t(key), 14, CHALK_MUTED)
			l.name = key
			l.horizontal_alignment = c[2]
			cell = l
		else:
			cell = Control.new()
		if float(c[1]) < 0.0:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		else:
			cell.custom_minimum_size = Vector2(float(c[1]), 0.0)
		h.add_child(cell)
	return h


## Bungkus dengan jarak tepi baris, supaya judul kolom lurus dengan isi baris.
static func _padded(child: Control) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", ROW_PAD)
	m.add_theme_constant_override("margin_right", ROW_PAD)
	m.add_child(child)
	return m


## Panel satu baris tabel berisi satu HBoxContainer (anak pertamanya).
static func _row_panel(node_name: String, style: StyleBoxFlat, min_h: float = ROW_MIN_H) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.name = node_name
	panel.custom_minimum_size = Vector2(0.0, min_h)
	panel.add_theme_stylebox_override("panel", style)
	var row := HBoxContainer.new()
	row.name = "Cells"
	row.add_theme_constant_override("separation", COL_SEP)
	panel.add_child(row)
	return panel


## Satu baris: nama + satuan, harga (rata kanan), stok gudang + yang sedang
## dikirim (rata tengah), dan tombol − jumlah + Max (rata kanan).
func _ingredient_row(ing: IngredientDefinition, w: Dictionary, style: StyleBoxFlat) -> PanelContainer:
	var panel: PanelContainer = _row_panel("Row_%s" % ing.id, style)
	var row: HBoxContainer = panel.get_child(0) as HBoxContainer
	var name_cell := VBoxContainer.new()
	name_cell.name = "NameCell"
	name_cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	name_cell.add_theme_constant_override("separation", 0)
	row.add_child(name_cell)
	for part: Array in [["Name", Tx.item_name(ing.id), 17, Palette.CHALK_WHITE],
			["Unit", Tx.t("ui_market_per_unit", {"unit": Tx.t(String(ing.unit_label_key))}), 13, CHALK_MUTED]]:
		var l: Label = _chalk(str(part[1]), int(part[2]), part[3])
		l.name = str(part[0])
		l.clip_text = true
		l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_cell.add_child(l)
	var price: Label = _chalk(Tx.kr(ing.fixed_buy_price_kr), 17)
	price.name = "Price"
	price.custom_minimum_size = Vector2(float(w["price"]), 0.0)
	price.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(price)
	var stock := VBoxContainer.new()
	stock.name = "StockCell"
	stock.custom_minimum_size = Vector2(float(w["stock"]), 0.0)
	stock.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	stock.add_theme_constant_override("separation", 0)
	row.add_child(stock)
	var have: Label = _chalk(str(sim.inventory.count(ing.id)), 17)
	have.name = "Stock"
	have.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stock.add_child(have)
	var transit: int = sim.supply.in_transit_of(ing.id)
	if transit > 0:
		var eta: Label = _chalk(Tx.t("ui_market_arriving", {"count": transit, "time": Tx.clock(sim.supply.next_eta_of(ing.id))}), 13, CHALK_MUTED)
		eta.name = "Arriving"
		eta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stock.add_child(eta)
	var amount := HBoxContainer.new()
	amount.name = "Amount"
	amount.add_theme_constant_override("separation", 8)
	amount.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(amount)
	var minus: Button = ProceduralUIFactory.icon_button("minus", Tx.t("ui_cancel"), "secondary")
	minus.name = "Minus"
	amount.add_child(minus)
	var q: Label = _chalk(str(_qty.get(ing.id, 0)), 18)
	q.name = "Qty"
	q.custom_minimum_size = Vector2(float(w["qty"]), 0.0)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	amount.add_child(q)
	_paint_qty(q, int(_qty.get(ing.id, 0)))
	var plus: Button = ProceduralUIFactory.icon_button("plus", Tx.t("ui_market_buy"), "secondary")
	plus.name = "Plus"
	amount.add_child(plus)
	var mx: Button = ProceduralUIFactory.button(Tx.t("ui_market_max"), "secondary")
	mx.name = "Max"
	mx.custom_minimum_size = Vector2(76.0, ProceduralUIFactory.TOUCH_MIN)
	amount.add_child(mx)
	var id: StringName = ing.id
	minus.pressed.connect(func() -> void: _change(id, -1, q))
	plus.pressed.connect(func() -> void: _change(id, 1, q))
	mx.pressed.connect(func() -> void: _change(id, 999999, q))
	return panel


## Jumlah yang dipilih ditulis dengan kapur kuning supaya mudah dilihat.
static func _paint_qty(q: Label, n: int) -> void:
	q.add_theme_color_override("font_color", CHALK_YELLOW if n > 0 else Palette.CHALK_WHITE)


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
	_paint_qty(q, nv)
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

## Tabel alat di papan kapur (perbaikan 2026-10-07, GDD 5.1.2, 7): satu bagian
## per kategori dengan judul kolomnya sendiri (waktu aduk/panggang atau daya
## tampung, utility, ukuran, harga, aksi). Kolom berlebar sama di semua bagian,
## jadi semua baris lurus. Alat tersimpan tampil paling atas.
func _render_equipment() -> void:
	var open: bool = sim.equipment.market_open_for_equipment()
	if not open:
		lbl(_body, Tx.t("ui_available_after_closing"), 16, Palette.DANGER)
	var board: PanelContainer = ProceduralUIFactory.chalkboard_panel()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(board)
	var list: VBoxContainer = scroll_box(ProceduralUIFactory.content_of(board))
	list.name = "EquipmentRows"
	list.add_theme_constant_override("separation", 2)
	var w: Dictionary = _equipment_widths()
	var shades: Array[StyleBoxFlat] = [_row_style(true), _row_style(false)]
	var stored: Array[EquipmentInstance] = []
	for e: EquipmentInstance in sim.equipment.unplaced_list():
		if not EquipmentManager.is_fixture(e.category()):
			stored.append(e)
	# Kolom aksi tiap tabel diseragamkan dengan isinya yang terlebar (tombol
	# diukur di dalam pohon adegan), termasuk sel kosong di judul kolomnya.
	var stored_cells: Array[Control] = []
	var action_cells: Array[Control] = []
	if not stored.is_empty():
		list.add_child(_section_heading(Tx.t("ui_equipment_stored_list"), false))
		var sh: HBoxContainer = _column_labels([["ui_equipment_col_item", -1.0, HORIZONTAL_ALIGNMENT_LEFT],
			["ui_equipment_col_sell", float(w["price"]), HORIZONTAL_ALIGNMENT_RIGHT],
			["", float(w["stored_actions"]), HORIZONTAL_ALIGNMENT_CENTER]], "Columns_stored")
		list.add_child(_padded(sh))
		stored_cells.append(sh.get_child(sh.get_child_count() - 1) as Control)
		for i in stored.size():
			var sr: PanelContainer = _stored_row(stored[i], w, shades[i % 2], open)
			list.add_child(sr)
			stored_cells.append(sr.find_child("Action", true, false) as Control)
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		var note: String = Tx.t("ui_equipment_section", {"placed": sim.equipment.placed_count(cat),
			"slots": sim.equipment.slot_limit(cat), "stored": sim.equipment.unplaced_list(cat).size()})
		list.add_child(_section_heading(Tx.t("equipment_category_" + String(cat)), list.get_child_count() > 0, note))
		var ch: HBoxContainer = _column_labels([["ui_equipment_col_item", -1.0, HORIZONTAL_ALIGNMENT_LEFT],
			[str(STAT_HEADERS[cat]), float(w["stat"]), HORIZONTAL_ALIGNMENT_CENTER],
			["ui_equipment_col_utility", float(w["utility"]), HORIZONTAL_ALIGNMENT_CENTER],
			["ui_equipment_col_size", float(w["size"]), HORIZONTAL_ALIGNMENT_CENTER],
			["ui_equipment_col_price", float(w["price"]), HORIZONTAL_ALIGNMENT_RIGHT],
			["", float(w["action"]), HORIZONTAL_ALIGNMENT_CENTER]], "Columns_%s" % cat)
		list.add_child(_padded(ch))
		action_cells.append(ch.get_child(ch.get_child_count() - 1) as Control)
		var defs: Array[EquipmentDefinition] = DataRegistry.equipment_in_category(cat)
		for i2 in defs.size():
			var er: PanelContainer = _equipment_row(defs[i2], w, shades[i2 % 2], open)
			list.add_child(er)
			action_cells.append(er.find_child("Action", true, false) as Control)
	_equalize(stored_cells)
	_equalize(action_cells)


## Lebar kolom tabel alat: teks dan tombol terlebar yang mungkin tampil pada
## skala teks saat ini, untuk semua kategori sekaligus.
func _equipment_widths() -> Dictionary:
	var stat_w: float = 0.0
	var util_w: float = _text_w(Tx.t("ui_equipment_col_utility"), 14)
	var size_w: float = _text_w(Tx.t("ui_equipment_col_size"), 14)
	var price_w: float = maxf(_text_w(Tx.t("ui_equipment_col_price"), 14), _text_w(Tx.t("ui_equipment_col_sell"), 14))
	for cat: Variant in STAT_HEADERS.keys():
		stat_w = maxf(stat_w, _text_w(Tx.t(str(STAT_HEADERS[cat])), 14))
		for d: EquipmentDefinition in DataRegistry.equipment_in_category(StringName(str(cat))):
			stat_w = maxf(stat_w, maxf(_text_w(_stat_text(d), 17), _text_w(_stat_note(d), 13)))
			util_w = maxf(util_w, _text_w(_utility_text(d), 17))
			size_w = maxf(size_w, _text_w(_size_text(d), 17))
			price_w = maxf(price_w, _text_w(Tx.kr(d.price_kr), 17))
	var action_w: float = maxf(_button_w(Tx.t("ui_equipment_buy_short"), "primary"), _button_w(Tx.t("ui_equipment_replace"), "secondary"))
	action_w = maxf(action_w, maxf(_text_w(Tx.t("ui_equipment_owned_count", {"count": 9}), 14), _text_w(Tx.t("ui_equipment_no_slot"), 14)))
	# Tulisan kunci tier satu baris pada skala teks 100%; pada skala yang lebih
	# besar ia boleh dua baris supaya kolom nama tetap lega.
	if ProceduralUIFactory.text_scale <= 1.01:
		action_w = maxf(action_w, _text_w(Tx.t("ui_equipment_tier_locked", {"tier": 5}), 14))
	var stored_w: float = _button_w(Tx.t("ui_decor_place"), "secondary") + _button_w(Tx.t("ui_equipment_sell_short"), "danger") + 8.0
	return {"stat": ceilf(stat_w) + 8.0, "utility": ceilf(util_w) + 8.0, "size": ceilf(size_w) + 8.0,
		"price": ceilf(price_w) + 4.0, "action": ceilf(action_w) + 4.0, "stored_actions": ceilf(stored_w)}


static func _button_w(text: String, kind: String) -> float:
	var b: Button = ProceduralUIFactory.button(text, kind)
	var wv: float = b.get_combined_minimum_size().x
	b.free()
	return wv


## Waktu referensi (mixer, oven) dalam detik nyata, atau daya tampung rak.
static func _stat_text(d: EquipmentDefinition) -> String:
	if d.category_id == &"display":
		return Tx.t("ui_equipment_holds", {"count": d.capacity})
	return Tx.t("ui_equipment_seconds", {"seconds": "%.1f" % DataRegistry.real_seconds(d.reference_seconds)})


static func _stat_note(d: EquipmentDefinition) -> String:
	return Tx.t("ui_equipment_slots", {"slots": d.slot_count}) if d.category_id == &"display" else ""


static func _utility_text(d: EquipmentDefinition) -> String:
	return Tx.t("ui_equipment_power", {"cost": Tx.kr(d.utility_cost_kr_per_ingame_hour)})


static func _size_text(d: EquipmentDefinition) -> String:
	return Tx.t("ui_equipment_size", {"w": d.footprint_tiles.x, "h": d.footprint_tiles.y})


## Sel nama: label tier, nama, lalu keterangan pudar selebar sel di bawahnya
## (resep yang dibuka alat itu, atau kategorinya).
func _item_cell(tier: int, title: String, note: String) -> HBoxContainer:
	var item := HBoxContainer.new()
	item.name = "ItemCell"
	item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	item.add_theme_constant_override("separation", 10)
	var tag: PanelContainer = _tier_tag(tier)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item.add_child(tag)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text.add_theme_constant_override("separation", 0)
	item.add_child(text)
	var nm: Label = _chalk(title, 17)
	nm.name = "Name"
	nm.clip_text = true
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	text.add_child(nm)
	if note != "":
		var n: Label = _chalk(note, 13, CHALK_MUTED)
		n.name = "Note"
		n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text.add_child(n)
	return item


## Label tier kecil bergaris kapur ("T1".."T5"), selebar "T5" supaya nama lurus.
func _tier_tag(tier: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.name = "Tier"
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.set_border_width_all(2)
	sb.border_color = Color(Palette.CHALK_WHITE, 0.55)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 1
	sb.content_margin_bottom = 1
	pc.add_theme_stylebox_override("panel", sb)
	var l: Label = _chalk("T%d" % tier, 14)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.custom_minimum_size = Vector2(ceilf(_text_w("T5", 14)), 0.0)
	pc.add_child(l)
	return pc


## Sel angka berlebar tetap, dengan keterangan pudar di bawahnya (opsional).
func _value_cell(node_name: String, text: String, width: float, align: HorizontalAlignment, note: String = "") -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = node_name
	v.custom_minimum_size = Vector2(width, 0.0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.add_theme_constant_override("separation", 0)
	var l: Label = _chalk(text, 17)
	l.horizontal_alignment = align
	v.add_child(l)
	if note != "":
		var n: Label = _chalk(note, 13, CHALK_MUTED)
		n.horizontal_alignment = align
		v.add_child(n)
	return v


## Satu baris katalog alat. Kolom aksi berisi tepat satu aksi: tulisan kunci
## tier, Buy (slot masih ada), Replace (slot penuh), atau keterangan bila tidak
## ada yang bisa dilakukan. Jumlah yang sudah dimiliki tertulis hijau di
## bawahnya.
func _equipment_row(def: EquipmentDefinition, w: Dictionary, style: StyleBoxFlat, open: bool) -> PanelContainer:
	var panel: PanelContainer = _row_panel("Row_%s" % def.id, style)
	var row: HBoxContainer = panel.get_child(0) as HBoxContainer
	var recipes: PackedStringArray = PackedStringArray()
	for r: RecipeDefinition in DataRegistry.recipes():
		if (def.category_id == &"mixer" and r.required_mixer_tier == def.tier) or (def.category_id == &"oven" and r.required_oven_tier == def.tier):
			recipes.append(Tx.recipe_name(r.id))
	var owned: int = _owned_count(def.id)
	var item: HBoxContainer = _item_cell(def.tier, Tx.item_name(def.id),
		Tx.t("ui_equipment_recipes", {"recipes": ", ".join(recipes)}) if not recipes.is_empty() else "")
	row.add_child(item)
	var cells: Array[Control] = [item,
		_value_cell("Stat", _stat_text(def), float(w["stat"]), HORIZONTAL_ALIGNMENT_CENTER, _stat_note(def)),
		_value_cell("Utility", _utility_text(def), float(w["utility"]), HORIZONTAL_ALIGNMENT_CENTER),
		_value_cell("Size", _size_text(def), float(w["size"]), HORIZONTAL_ALIGNMENT_CENTER),
		_value_cell("Price", Tx.kr(def.price_kr), float(w["price"]), HORIZONTAL_ALIGNMENT_RIGHT)]
	for c: Control in cells.slice(1):
		row.add_child(c)
	var act := VBoxContainer.new()
	act.name = "Action"
	act.custom_minimum_size = Vector2(float(w["action"]), 0.0)
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.add_theme_constant_override("separation", 2)
	row.add_child(act)
	var count_line: String = Tx.t("ui_equipment_owned_count", {"count": owned}) if owned > 0 else ""
	# Gerbang tier lokasi (GDD 5.1.2): baris pudar dengan tulisan kunci.
	if not sim.equipment.tier_allowed(def):
		for c2: Control in cells:
			c2.modulate = Color(1.0, 1.0, 1.0, LOCKED_ALPHA)
		var lock: Label = _chalk(Tx.t("ui_equipment_tier_locked", {"tier": def.tier}), 14, CHALK_PINK)
		lock.name = "Locked"
		lock.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lock.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		act.add_child(lock)
		_owned_line(act, count_line)
		return panel
	var cat: StringName = def.category_id
	var full: bool = sim.equipment.placed_count(cat) + sim.equipment.unplaced_list(cat).size() >= sim.equipment.slot_limit(cat)
	var afford: bool = sim.economy.can_afford(def.price_kr)
	if not full:
		var buy: Button = ProceduralUIFactory.button(Tx.t("ui_equipment_buy_short"), "primary")
		buy.name = "Buy"
		buy.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		buy.disabled = not open or not afford
		buy.pressed.connect(_buy_equipment.bind(def.id))
		act.add_child(buy)
		_owned_line(act, count_line)
		return panel
	var candidates: Array[int] = _replace_candidates(def)
	if candidates.is_empty():
		# Semua alat terpasang sudah alat ini: tidak ada yang perlu diganti.
		var status: Label = _chalk(count_line if count_line != "" else Tx.t("ui_equipment_no_slot"), 14, CHALK_GREEN if count_line != "" else CHALK_MUTED)
		status.name = "Owned" if count_line != "" else "NoSlot"
		status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		act.add_child(status)
		return panel
	var all_busy: bool = true
	for iid: int in candidates:
		all_busy = all_busy and sim.equipment.is_in_use(iid)
	var rep: Button = ProceduralUIFactory.button(Tx.t("ui_equipment_replace"), "secondary")
	rep.name = "Replace"
	rep.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	rep.disabled = not open or not afford or all_busy
	rep.pressed.connect(_ask_replace.bind(def.id, candidates))
	act.add_child(rep)
	_owned_line(act, count_line)
	return panel


## "Owned ×N" hijau kecil di bawah aksi baris (bila alat ini sudah dimiliki).
func _owned_line(act: VBoxContainer, text: String) -> void:
	if text == "":
		return
	var l: Label = _chalk(text, 13, CHALK_GREEN)
	l.name = "OwnedCount"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	act.add_child(l)


## Alat tersimpan: nama, nilai jual, lalu Place dan Sell.
func _stored_row(e: EquipmentInstance, w: Dictionary, style: StyleBoxFlat, open: bool) -> PanelContainer:
	var panel: PanelContainer = _row_panel("Stored_%d" % e.iid, style)
	var row: HBoxContainer = panel.get_child(0) as HBoxContainer
	row.add_child(_item_cell(e.tier(), Tx.item_name(e.def_id), Tx.t("equipment_category_" + String(e.category()))))
	row.add_child(_value_cell("Price", Tx.kr(sim.equipment.sell_value(e.iid)), float(w["price"]), HORIZONTAL_ALIGNMENT_RIGHT))
	var act := HBoxContainer.new()
	act.name = "Action"
	act.custom_minimum_size = Vector2(float(w["stored_actions"]), 0.0)
	act.alignment = BoxContainer.ALIGNMENT_END
	act.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	act.add_theme_constant_override("separation", 8)
	row.add_child(act)
	var iid: int = e.iid
	var place: Button = btn(act, Tx.t("ui_decor_place"), "secondary", func() -> void: host.open(&"decoration", {"select_iid": iid}))
	place.name = "Place"
	var sell: Button = btn(act, Tx.t("ui_equipment_sell_short"), "danger", _sell.bind(iid))
	sell.name = "Sell"
	sell.disabled = not open
	return panel


## Jumlah alat `def_id` yang dimiliki (terpasang maupun tersimpan).
func _owned_count(def_id: StringName) -> int:
	var n: int = 0
	for e: EquipmentInstance in sim.equipment.placed_list():
		if e.def_id == def_id:
			n += 1
	for e2: EquipmentInstance in sim.equipment.unplaced_list():
		if e2.def_id == def_id:
			n += 1
	return n


## Alat terpasang sekategori yang bisa diganti dengan `def`. Alat yang sama
## persis tidak ditawarkan, karena menggantinya hanya membuang uang.
func _replace_candidates(def: EquipmentDefinition) -> Array[int]:
	var out: Array[int] = []
	for e: EquipmentInstance in sim.equipment.placed_list(def.category_id):
		if e.def_id != def.id:
			out.append(e.iid)
	return out


## Replace (GDD 5.1.2): pemain memilih alat terpasang yang diganti. Bila hanya
## ada satu calon, langsung dipakai; selain itu ReplacePicker menanyakannya.
func _ask_replace(def_id: StringName, candidates: Array[int]) -> void:
	if candidates.size() == 1:
		_replace(def_id, candidates[0])
		return
	host.open(&"replace_picker", {"def_id": def_id, "candidates": candidates,
		"on_pick": func(iid: int) -> void: _replace(def_id, iid)})


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

## Perbandingan lokasi (perbaikan 2026-10-07, GDD 6, 7): satu tabel papan kapur
## "lokasi sekarang → lokasi berikutnya" yang muat di popup. Yang bertambah
## ditulis kapur kuning beserta selisihnya. Di tier tertinggi hanya kolom
## lokasi sekarang yang tampil.
func _render_upgrade() -> void:
	var cur: LocationDefinition = sim.world.location
	var nxt: LocationDefinition = sim.next_location()
	var board: PanelContainer = ProceduralUIFactory.chalkboard_panel()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(board)
	var inner: VBoxContainer = ProceduralUIFactory.content_of(board)
	var rows: Array[Dictionary] = _upgrade_rows(cur, nxt)
	var val_w: float = maxf(_text_w(Tx.t(String(cur.localization_key)), 16), _text_w(Tx.t("ui_upgrade_current"), 12))
	if nxt != null:
		val_w = maxf(val_w, maxf(_text_w(Tx.t(String(nxt.localization_key)), 16), _text_w(Tx.t("ui_upgrade_next"), 12)))
	for r: Dictionary in rows:
		val_w = maxf(val_w, maxf(_text_w(str(r["now"]), 16), _text_w(str(r["next"]) + "  " + str(r["delta"]), 16)))
	val_w = ceilf(val_w) + 12.0
	var arrow_w: float = ceilf(_text_w("→", 16)) + 4.0
	# Judul kolom: nama lokasi sekarang dan berikutnya.
	var head := HBoxContainer.new()
	head.name = "UpgradeColumns"
	head.add_theme_constant_override("separation", COL_SEP)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(spacer)
	head.add_child(_location_head("Now", Tx.t("ui_upgrade_current"), Tx.t(String(cur.localization_key)), val_w, Palette.CHALK_WHITE))
	if nxt != null:
		var gap := Control.new()
		gap.custom_minimum_size = Vector2(arrow_w, 0.0)
		head.add_child(gap)
		head.add_child(_location_head("Next", Tx.t("ui_upgrade_next"), Tx.t(String(nxt.localization_key)), val_w, CHALK_YELLOW))
	var head_box: MarginContainer = _padded(head)
	inner.add_child(head_box)
	inner.add_child(ProceduralUIFactory.dashed_separator(Palette.CHALK_WHITE))
	# Pada 100% semua baris muat; pada skala teks besar barisnya digulir supaya
	# popup tidak memanjang. Scrollbar selalu tampil (seperti tabel bahan), jadi
	# judul kolom menyisakan tempat yang sama di kanan dan tetap lurus.
	var list: VBoxContainer = scroll_box(inner)
	list.name = "UpgradeRows"
	list.add_theme_constant_override("separation", 2)
	var sc: ScrollContainer = list.get_parent() as ScrollContainer
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_ALWAYS
	head_box.add_theme_constant_override("margin_right", ROW_PAD + _scrollbar_room(sc))
	var shades: Array[StyleBoxFlat] = [_row_style(true, 2), _row_style(false, 2)]
	for i in rows.size():
		list.add_child(_compare_row(rows[i], val_w, arrow_w, shades[i % 2], nxt != null))
	if nxt == null:
		var top: Label = _chalk(Tx.t("ui_upgrade_max"), 18, CHALK_YELLOW)
		top.name = "TopTier"
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(_padded(top))
		return
	var foot: HBoxContainer = hbox(_body, 16)
	var reason: String = sim.upgrade_block_reason()
	var b: Button = btn(foot, Tx.t("ui_upgrade_buy", {"price": Tx.kr(nxt.upgrade_cost_kr)}), "primary", func() -> void:
		host.confirm(Tx.t("ui_upgrade_confirm", {"location": Tx.t(String(nxt.localization_key)), "price": Tx.kr(nxt.upgrade_cost_kr)}), _do_upgrade))
	b.name = "Upgrade"
	b.custom_minimum_size = Vector2(320, 56)
	b.disabled = reason != ""
	if reason != "":
		var why: Label = lbl(foot, Tx.t(reason), 16, Palette.DANGER, true)
		why.name = "Reason"
		why.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Judul satu kolom lokasi: "Current/Next location" pudar di atas namanya.
func _location_head(node_name: String, caption: String, title: String, width: float, color: Color) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = node_name
	v.custom_minimum_size = Vector2(width, 0.0)
	v.add_theme_constant_override("separation", 0)
	var c: Label = _chalk(caption, 12, CHALK_MUTED)
	c.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(c)
	var t: Label = _chalk(title, 16, color)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	return v


## Baris perbandingan: {key, now, next, up, delta}. `up` = nilai berikutnya
## lebih besar (ditandai kuning); `delta` = selisih yang ditulis di sampingnya.
func _upgrade_rows(cur: LocationDefinition, nxt: LocationDefinition) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for r: Array in [["ui_upgrade_row_mixers", &"mixer"], ["ui_upgrade_row_ovens", &"oven"],
			["ui_upgrade_row_displays", &"display"], ["ui_upgrade_row_lanes", &"cashier"]]:
		out.append(_count_row(str(r[0]), cur.slot_count(r[1]), nxt.slot_count(r[1]) if nxt != null else 0, nxt != null))
	for r2: Array in [["ui_upgrade_row_cashiers", &"cashier"], ["ui_upgrade_row_bakers", &"baker"]]:
		out.append(_count_row(str(r2[0]), cur.staff_capacity(r2[1]), nxt.staff_capacity(r2[1]) if nxt != null else 0, nxt != null))
	var cap_now: int = DataRegistry.equipment(cur.storage_id).capacity
	var cap_next: int = DataRegistry.equipment(nxt.storage_id).capacity if nxt != null else 0
	out.append({"key": "ui_upgrade_row_storage", "now": Tx.t("ui_upgrade_storage_value", {"capacity": cap_now}),
		"next": Tx.t("ui_upgrade_storage_value", {"capacity": cap_next}) if nxt != null else "",
		"up": nxt != null and cap_next > cap_now, "delta": "(+%d)" % (cap_next - cap_now) if nxt != null and cap_next > cap_now else ""})
	out.append({"key": "ui_upgrade_row_equipment", "now": Tx.t("ui_upgrade_equipment_value", {"tier": cur.tier}),
		"next": Tx.t("ui_upgrade_equipment_value", {"tier": nxt.tier}) if nxt != null else "",
		"up": nxt != null and nxt.tier > cur.tier, "delta": ""})
	out.append({"key": "ui_upgrade_row_wage", "now": Tx.t("ui_upgrade_wage_value", {"wage": Tx.kr(cur.staff_daily_wage_kr)}),
		"next": Tx.t("ui_upgrade_wage_value", {"wage": Tx.kr(nxt.staff_daily_wage_kr)}) if nxt != null else "",
		"up": false, "delta": ""})
	return out


static func _count_row(key: String, now: int, next: int, has_next: bool) -> Dictionary:
	return {"key": key, "now": str(now), "next": str(next) if has_next else "", "up": has_next and next > now,
		"delta": "(+%d)" % (next - now) if has_next and next > now else ""}


func _compare_row(r: Dictionary, val_w: float, arrow_w: float, style: StyleBoxFlat, has_next: bool) -> PanelContainer:
	var panel: PanelContainer = _row_panel("Compare_%s" % r["key"], style, COMPARE_ROW_H)
	var row: HBoxContainer = panel.get_child(0) as HBoxContainer
	var label: Label = _chalk(Tx.t(str(r["key"])), 14, CHALK_MUTED)
	label.name = "Label"
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var now: Label = _chalk(str(r["now"]), 16)
	now.name = "Now"
	now.custom_minimum_size = Vector2(val_w, 0.0)
	now.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(now)
	if not has_next:
		return panel
	var arrow: Label = _chalk("→", 16, CHALK_MUTED)
	arrow.custom_minimum_size = Vector2(arrow_w, 0.0)
	arrow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(arrow)
	var up: bool = bool(r["up"])
	var nx: Label = _chalk(str(r["next"]) + ("  " + str(r["delta"]) if str(r["delta"]) != "" else ""), 16, CHALK_YELLOW if up else Palette.CHALK_WHITE)
	nx.name = "Next"
	nx.custom_minimum_size = Vector2(val_w, 0.0)
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(nx)
	return panel


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
