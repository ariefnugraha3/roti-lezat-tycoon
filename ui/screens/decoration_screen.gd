class_name DecorationScreen
extends UIScreen
## Decoration Mode (GDD 7, 17.3-17.4, 56.1, 60.1, 72, 72.1). Membukanya
## mem-pause simulasi; ketukan dunia diteruskan ke sini. Ketuk perabot untuk
## mengangkatnya, lalu ketuk ubin tujuan: petak jejak lantai disorot putih bila
## sah atau merah bersilang beserta alasannya. Perabot IN_USE tidak dapat
## dipindah. Decor Shop hanya aktif after-hours. Ubin yang harus tetap kosong
## (jalur, antrean, titik layanan, akses perabot, leher botol) diarsir merah
## selama mode ini, dan percobaan menaruh perabot di sana memunculkan banner
## peringatan (GDD 17.4 "preview merah dan tampilkan alasan").
##
## Tata letak (keputusan maintainer 2026-09-30): TANPA panel samping, supaya
## dunia terlihat penuh. Bilah atas tipis (judul, petunjuk, lantai, Done); tab di
## tepi bawah yang membuka baki barang (Equipment / Your Decorations / Decor
## Shop); dan toolbar aksi (Rotate, Put Away, Cancel) yang melayang tepat di atas
## perabot terpilih dan ikut pindah bersamanya. Barang yang belum punya tempat di
## dunia (belum dipasang, dekorasi dinding/meja) memakai toolbar yang berlabuh di
## atas tab.
##
## Dekorasi (GDD 72.3): semuanya di lantai toko. Dekorasi dinding/meja yang
## dipilih menyalakan penanda slot bebas; ketuk penanda untuk memasang atau
## memindahkannya. Karpet mengikuti ubin yang diketuk dan bisa diputar. Batas
## per jenis mengikuti tier toko; baki "Your Decorations" menunjukkan sisa slot.

const REASON_KEYS: Dictionary = {
	&"zone": "ui_decor_invalid_zone", &"overlap": "ui_decor_invalid_overlap", &"path": "ui_decor_invalid_path",
	&"access": "ui_decor_invalid_access", &"bounds": "ui_decor_invalid_bounds", &"reserved": "ui_decor_invalid_reserved",
	&"in_use": "ui_feedback_in_use", &"slots_full": "ui_equipment_slots_full", &"limit": "ui_decor_limit",
	&"invalid": "ui_decor_invalid_reserved", &"blocks_access": "ui_decor_invalid_blocks_access",
}
## Detail banner untuk penolakan karena jalan (WorldManager.WALKWAY_REASONS).
const WARN_KEYS: Dictionary = {
	&"reserved": "ui_decor_warn_walkway", &"path": "ui_decor_warn_walkway", &"blocks_access": "ui_decor_warn_access",
}
const WARN_SECONDS: float = 2.6
## Tab baki bawah: -1 = baki tertutup.
const TAB_EQUIPMENT: int = 0
const TAB_OWNED: int = 1
const TAB_SHOP: int = 2
const TAB_KEYS: Array[String] = ["ui_market_tab_equipment", "ui_decor_owned", "ui_decor_shop"]
const TAB_ICONS: Array[String] = ["kitchen", "frame", "cart"]
const CARD_SIZE: Vector2 = Vector2(184.0, 92.0)
## Jenis dekorasi berpasang dan urutannya di ringkasan slot baki.
const DECOR_TYPES: Array[StringName] = [&"wall", &"counter_prop", &"floor_prop", &"floor_overlay"]
## Jarak ujung ekor toolbar di atas puncak perabot (meter) dan dari tepi layar (px).
const TOOLBAR_LIFT_M: float = 0.18
const EDGE_PX: float = 10.0

var _sel_iid: int = -1
var _sel_decor: int = -1
var _rot: int = 0
var _last_cell: Vector2i = Vector2i(-1, -1)
var _tab: int = -1
var _status: Label = null
var _top: PanelContainer = null
var _bottom: VBoxContainer = null
var _tray: PanelContainer = null
var _tray_row: HBoxContainer = null
var _tabs_box: HBoxContainer = null
var _legend_zone: Control = null
var _legend_clear: Control = null
var _toolbar: ActionBar = null
var _tb_name: Label = null
var _tb_rotate: Button = null
var _tb_store: Button = null
var _tb_cancel: Button = null
var _warn: PanelContainer = null
var _warn_title: Label = null
var _warn_detail: Label = null
var _warn_tween: Tween = null
var _overlay_floor: StringName = &""


func _init() -> void:
	super._init()
	world_input = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	game.hud.set_decoration_active(true)
	game.commands.tap_override = _on_world_tap
	game.world.camera_rig.set_free_pan(true)
	game.world.decoration_mode = true
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(inset.x) + 12)
	margin.add_theme_constant_override("margin_top", int(inset.y) + 10)
	margin.add_theme_constant_override("margin_right", int(inset.z) + 12)
	margin.add_theme_constant_override("margin_bottom", int(inset.w) + 10)
	add_child(margin)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)
	_build_top_bar(frame)
	_build_bottom(frame)
	_build_warning(frame)
	_build_toolbar()
	sim.world.layout_changed.connect(_refresh_overlay)
	var pre: int = int(params.get("select_iid", -1))
	if pre >= 0:
		_select_equipment(pre)
	_refresh_all()
	_refresh_overlay()


# ===========================================================================
# BANGUN
# ===========================================================================

## Bilah atas: judul, petunjuk/status, tombol lantai (Tier 2-3), dan Done.
func _build_top_bar(frame: Control) -> void:
	_top = PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.94), 18, true)
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_top.add_theme_stylebox_override("panel", sb)
	_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_top.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(_top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_top.add_child(row)
	row.add_child(ProceduralUIFactory.icon("frame", 26, Palette.UI_WOOD))
	row.add_child(ProceduralUIFactory.title(Tx.t("ui_decoration"), 22))
	_status = ProceduralUIFactory.label(Tx.t("ui_decor_hint"), 16, Palette.TEXT)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	row.add_child(_status)
	if sim.world.location.is_multi_floor():
		for f: FloorDefinition in sim.world.location.floors:
			var fid: StringName = f.id
			var fb: Button = btn(row, Tx.t("ui_floor_label", {"n": String(f.id).replace("floor_", "")}), "secondary", func() -> void:
				game.world.view_floor_override = fid)
			fb.custom_minimum_size = Vector2(56, 48)
	var done: Button = btn(row, Tx.t("ui_decor_done"), "primary", close)
	done.custom_minimum_size = Vector2(120, 48)


## Tepi bawah: baki barang (tertutup sampai sebuah tab diketuk) di atas baris
## keterangan arsiran + tiga tab.
func _build_bottom(frame: Control) -> void:
	_bottom = VBoxContainer.new()
	_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_theme_constant_override("separation", 8)
	frame.add_child(_bottom)
	_tray = PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.96), 20, true)
	sb.set_content_margin_all(10.0)
	_tray.add_theme_stylebox_override("panel", sb)
	_tray.mouse_filter = Control.MOUSE_FILTER_STOP
	_bottom.add_child(_tray)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size = Vector2(0, CARD_SIZE.y + 14.0)
	_tray.add_child(sc)
	_tray_row = HBoxContainer.new()
	_tray_row.add_theme_constant_override("separation", 10)
	sc.add_child(_tray_row)
	_tray.visible = false
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bottom.add_child(row)
	# Tab di tengah: sisi kiri (keterangan) dan kanan sama lebar.
	var left := HBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(left)
	left.add_child(_build_legend())
	_tabs_box = HBoxContainer.new()
	_tabs_box.add_theme_constant_override("separation", 8)
	row.add_child(_tabs_box)
	var right := Control.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(right)


## Keterangan arsiran ubin (GDD 17.4): contoh warna + teks pendek; kalimat
## lengkapnya ada di tooltip.
func _build_legend() -> Control:
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.90), 14, false)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	pc.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	_legend_clear = _legend_row(Palette.DANGER, "ui_decor_legend_clear_short", "ui_decor_legend_clear")
	v.add_child(_legend_clear)
	_legend_zone = _legend_row(Palette.TEXT_MUTED, "ui_decor_legend_zone_short", "ui_decor_legend_zone")
	_legend_zone.visible = false
	v.add_child(_legend_zone)
	return pc


func _legend_row(color: Color, key: String, tip_key: String) -> Control:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.tooltip_text = Tx.t(tip_key)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	var sw := ColorRect.new()
	sw.color = Color(color, 0.75)
	sw.custom_minimum_size = Vector2(14, 14)
	sw.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(sw)
	h.add_child(ProceduralUIFactory.label(Tx.t(key), 14, Palette.TEXT))
	return h


## Toolbar aksi yang melayang di atas perabot terpilih.
func _build_toolbar() -> void:
	_toolbar = ActionBar.new()
	add_child(_toolbar)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_toolbar.panel.add_child(v)
	_tb_name = ProceduralUIFactory.label("", 15, Palette.UI_WOOD)
	_tb_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_tb_name)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	_tb_rotate = _icon_text_button("rotate", Tx.t("ui_decor_rotate"), "secondary", _rotate)
	row.add_child(_tb_rotate)
	_tb_store = _icon_text_button("box", Tx.t("ui_decor_store"), "secondary", _put_away)
	row.add_child(_tb_store)
	_tb_cancel = ProceduralUIFactory.icon_button("cross", Tx.t("ui_cancel"), "ghost")
	_tb_cancel.pressed.connect(_deselect)
	row.add_child(_tb_cancel)
	_toolbar.visible = false


## Banner peringatan di bawah bilah atas. HUD disembunyikan selama Decoration
## Mode, jadi toast biasa tidak akan terlihat.
func _build_warning(frame: Control) -> void:
	var area := CenterContainer.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.set_anchors_preset(Control.PRESET_TOP_WIDE)
	area.offset_top = 74
	area.offset_bottom = 170
	frame.add_child(area)
	_warn = PanelContainer.new()
	_warn.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 18, true)
	sb.border_color = Palette.DANGER
	sb.set_border_width_all(3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_warn.add_theme_stylebox_override("panel", sb)
	area.add_child(_warn)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_warn.add_child(row)
	row.add_child(ProceduralUIFactory.icon("warning", 30, Palette.DANGER))
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(col)
	_warn_title = ProceduralUIFactory.label(Tx.t("ui_decor_warn_title"), 17, Palette.DANGER)
	col.add_child(_warn_title)
	_warn_detail = ProceduralUIFactory.label("", 15, Palette.TEXT)
	col.add_child(_warn_detail)
	_warn.visible = false


## Tombol pil berisi ikon + teks; seluruh tombol tetap bidang sentuhnya.
static func _icon_text_button(icon_name: String, text: String, kind: String, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button(icon_name, text, kind, 22, 16)
	b.pressed.connect(cb)
	return b


# ===========================================================================
# BAKI BARANG (tab bawah)
# ===========================================================================

## Ketuk tab: buka baki di tab itu; ketuk tab yang sedang terbuka: tutup baki.
## Dibangun ulang sesudah sinyal tombolnya selesai.
func _set_tab(idx: int) -> void:
	_tab = -1 if _tab == idx else idx
	_refresh_all.call_deferred()


func _refresh_all() -> void:
	_render_tabs()
	_render_tray()
	_update_toolbar_content()
	_update_status()


## Tab aktif memakai gaya utama. Tab alat menghitung alat yang belum dipasang.
func _render_tabs() -> void:
	clear(_tabs_box)
	var unplaced: int = 0
	for e: EquipmentInstance in sim.equipment.all_sorted():
		if not e.placed:
			unplaced += 1
	for i in TAB_KEYS.size():
		var idx: int = i
		var text: String = Tx.t(TAB_KEYS[i])
		if i == TAB_EQUIPMENT and unplaced > 0:
			text += " (%d)" % unplaced
		var b: Button = _icon_text_button(TAB_ICONS[i], text, "primary" if i == _tab else "secondary", func() -> void: _set_tab(idx))
		b.name = "Tab%d" % i
		_tabs_box.add_child(b)


func _render_tray() -> void:
	clear(_tray_row)
	_tray.visible = _tab >= 0
	match _tab:
		TAB_EQUIPMENT:
			for e: EquipmentInstance in sim.equipment.all_sorted():
				# Fixture bangunan (Gudang, Meja Tunggu) dipilih lewat ketukan di dunia.
				if EquipmentManager.is_fixture(e.category()) and e.placed:
					continue
				var sub: String = Tx.t("ui_decor_placed") if e.placed else Tx.t("ui_decor_unplaced")
				_tray_row.add_child(_card(Tx.item_name(e.def_id), sub, e.iid == _sel_iid, false, _pick_equipment_card.bind(e.iid)))
		TAB_OWNED:
			_tray_row.add_child(_slot_usage_card())
			for o: Dictionary in sim.decoration.owned:
				var def: MiscDefinitions.DecorationDefinition = sim.decoration.def_of(o)
				var name_text: String = Tx.t(String(def.localization_key))
				var type_text: String = Tx.t("decor_type_" + String(def.placement_type))
				if def.is_placeable():
					var sub2: String = "%s · %s" % [type_text, Tx.t("ui_decor_placed") if bool(o["placed"]) else Tx.t("ui_decor_unplaced")]
					_tray_row.add_child(_card(name_text, sub2, int(o["uid"]) == _sel_decor, false, _pick_decor_card.bind(int(o["uid"]))))
				else:
					var eq: bool = sim.decoration.equipped.values().has(String(def.id))
					var sub3: String = "%s · %s" % [type_text, Tx.t("ui_decor_equipped") if eq else Tx.t("ui_decor_equip")]
					_tray_row.add_child(_card(name_text, sub3, eq, false, _equip.bind(def.id)))
		TAB_SHOP:
			if not sim.time.is_after_hours():
				var note: Label = ProceduralUIFactory.label(Tx.t("ui_available_after_closing"), 15, Palette.DANGER)
				note.custom_minimum_size = Vector2(150, 0)
				note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				_tray_row.add_child(note)
			for x: Variant in DataRegistry.decorations():
				var d: MiscDefinitions.DecorationDefinition = x
				if d.source != &"shop":
					continue
				var price: String = Tx.t("ui_decor_buy", {"price": Tx.kr(d.price_kr)})
				_tray_row.add_child(_card(Tx.t(String(d.localization_key)), price, false, sim.decoration.can_buy(d.id) != &"", _buy.bind(d.id)))


## Ringkasan slot dekorasi lokasi ini (GDD 72.3): "Wall 1/2" dan seterusnya;
## jenis yang penuh ditulis dengan warna kayu.
func _slot_usage_card() -> Control:
	var pc := PanelContainer.new()
	pc.name = "SlotUsage"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.VANILLA_CREAM, 0.9), 16, false)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(0, CARD_SIZE.y)
	pc.tooltip_text = Tx.t("ui_decor_slot_usage_tip")
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(v)
	for t: StringName in DECOR_TYPES:
		var used: int = sim.decoration.placed_of_type(t)
		var cap: int = sim.decoration.cap(t)
		var l: Label = ProceduralUIFactory.label(Tx.t("ui_decor_slot_count", {"type": Tx.t("decor_type_" + String(t)), "used": used, "max": cap}),
			14, Palette.UI_WOOD if used >= cap else Palette.TEXT)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(l)
	return pc


## Kartu barang di baki: nama (dua baris) dan keterangan kecil.
func _card(title_text: String, sub: String, selected: bool, disabled: bool, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.button("", "primary" if selected else "secondary")
	b.custom_minimum_size = CARD_SIZE
	b.disabled = disabled
	b.tooltip_text = title_text
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 10
	v.offset_right = -10
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var ink: Color = Palette.FLOUR_WHITE if selected else Palette.TEXT
	var t: Label = ProceduralUIFactory.label(title_text, 15, ink)
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.custom_minimum_size = Vector2(CARD_SIZE.x - 20.0, 0)
	t.max_lines_visible = 2
	v.add_child(t)
	var s: Label = ProceduralUIFactory.label(sub, 14, Color(ink, 0.8) if selected else Palette.TEXT_MUTED)
	s.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	s.clip_text = true
	s.custom_minimum_size = Vector2(CARD_SIZE.x - 20.0, 0)
	v.add_child(s)
	b.pressed.connect(cb)
	return b


## Kartu alat: pilih, arahkan kamera ke alat yang sudah terpasang, lalu tutup
## baki supaya dunia terlihat untuk memindahkannya.
func _pick_equipment_card(iid: int) -> void:
	_tab = -1
	_select_equipment(iid)
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if _sel_iid == iid and e != null and e.placed:
		var top: Vector3 = game.world.top_of_iid(iid)
		if top != Vector3.INF:
			game.world.camera_rig.focus_free_pan(top)


func _pick_decor_card(uid: int) -> void:
	_tab = -1
	_select_decor(uid)


func _equip(deco_id: StringName) -> void:
	sim.decoration.equip(deco_id)
	game.world.rebuild_all()
	_refresh_all.call_deferred()


func _buy(deco_id: StringName) -> void:
	var r: StringName = sim.decoration.buy(deco_id)
	if r != &"":
		EventBus.notify.emit(1, "ui_feedback_not_enough_kr" if r == &"kr" else "ui_available_after_closing", {}, &"coin")
		return
	game.world.rebuild_all()
	_tab = TAB_OWNED
	_refresh_all.call_deferred()


# ===========================================================================
# PILIHAN & TOOLBAR
# ===========================================================================

func _select_equipment(iid: int) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null:
		return
	if e.placed and sim.equipment.is_in_use(iid):
		_set_status(&"in_use", false)
		return
	_sel_iid = iid
	_sel_decor = -1
	_rot = e.rotation
	_last_cell = Vector2i(-1, -1)
	game.world.clear_ghost()
	game.world.clear_slot_markers()
	game.world.set_decor_lift(-1)
	game.world.view_floor_override = e.floor_id if e.placed else sim.world.floors_for_category(e.category())[0]
	game.world.set_lift(iid if e.placed else -1)
	if e.placed:
		_preview(e.anchor)
	_refresh_overlay()
	_refresh_all()


## Pilih dekorasi (GDD 72.3). Kamera pindah ke lantai toko. Dinding/meja:
## penanda slot bebas menyala. Lantai/karpet terpasang: jejaknya disorot. Jenis
## yang sudah penuh langsung memberi tahu pemain.
func _select_decor(uid: int) -> void:
	var o: Dictionary = sim.decoration.item(uid)
	if o.is_empty():
		return
	_sel_decor = uid
	_sel_iid = -1
	_last_cell = Vector2i(-1, -1)
	game.world.set_lift(-1)
	game.world.clear_ghost()
	game.world.clear_slot_markers()
	var placed: bool = bool(o["placed"])
	game.world.view_floor_override = sim.decoration.store_floor()
	game.world.set_decor_lift(uid if placed else -1)
	_refresh_overlay()
	var t: StringName = sim.decoration.type_of(o)
	if sim.decoration.type_full(uid):
		_warn_rejected(&"slots_full")
	elif _is_slot_type(t):
		_show_slots()
	elif placed and t == &"floor_prop":
		game.world.show_ghost([SimManager.arr_to_cell(o["cell"])], StringName(str(o["floor_id"])), true)
	elif placed and t == &"floor_overlay":
		game.world.show_ghost(sim.decoration.overlay_cells(o), StringName(str(o["floor_id"])), true)
	_refresh_all()


static func _is_slot_type(t: StringName) -> bool:
	return t == &"wall" or t == &"counter_prop"


func _sel_decor_type() -> StringName:
	return sim.decoration.type_of(sim.decoration.item(_sel_decor)) if _sel_decor >= 0 else &""


## Nyalakan penanda slot yang boleh dipakai dekorasi terpilih; slotnya sendiri emas.
func _show_slots() -> void:
	var o: Dictionary = sim.decoration.item(_sel_decor)
	var t: StringName = sim.decoration.type_of(o)
	var current: int = int(o["slot"]) if bool(o["placed"]) else -1
	game.world.show_slot_markers(t, sim.decoration.free_slots(t, _sel_decor), current)


## Pasang/pindahkan dekorasi dinding/meja terpilih ke `slot`. Mengetuk slotnya
## sendiri = selesai, seperti mengetuk perabot terpilih.
func _place_decor_slot(slot: int) -> void:
	var o: Dictionary = sim.decoration.item(_sel_decor)
	if bool(o["placed"]) and int(o["slot"]) == slot:
		_deselect()
		return
	var r: StringName = sim.decoration.place(_sel_decor, sim.decoration.store_floor(), Vector2i(-1, -1), slot)
	if r != &"":
		_set_status(r, false)
		_warn_rejected(r)
		return
	EventBus.sfx.emit(&"bread_place_display", sim.decoration.store_floor())
	game.world.set_decor_lift(_sel_decor)
	_show_slots()
	_refresh_all()
	_set_status(&"", true)


func _deselect() -> void:
	_sel_iid = -1
	_sel_decor = -1
	_last_cell = Vector2i(-1, -1)
	game.world.set_lift(-1)
	game.world.set_decor_lift(-1)
	game.world.clear_ghost()
	game.world.clear_slot_markers()
	_refresh_overlay()
	_refresh_all()


func has_selection() -> bool:
	return _sel_iid >= 0 or _sel_decor >= 0


func toolbar() -> ActionBar:
	return _toolbar


## Isi toolbar mengikuti barang terpilih: Rotate hanya untuk alat, Put Away hanya
## untuk yang sudah terpasang dan boleh disimpan (Gudang & Meja Tunggu tidak).
func _update_toolbar_content() -> void:
	_toolbar.visible = has_selection()
	if not has_selection():
		return
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		_tb_name.text = Tx.item_name(e.def_id)
		_tb_rotate.visible = true
		_tb_store.visible = e.placed and not EquipmentManager.is_fixture(e.category())
	else:
		var o: Dictionary = sim.decoration.item(_sel_decor)
		_tb_name.text = Tx.t(String(sim.decoration.def_of(o).localization_key))
		_tb_rotate.visible = sim.decoration.type_of(o) == &"floor_overlay"
		_tb_store.visible = bool(o.get("placed", false))
	_toolbar.panel.reset_size()


## Titik layar yang ditunjuk ekor toolbar, atau (-1, -1) bila barang terpilih
## tidak punya tempat di lantai yang sedang dilihat (toolbar berlabuh di bawah).
func _toolbar_anchor() -> Vector2:
	var world: WorldView = game.world
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		if e == null or not e.placed or e.floor_id != world.camera_rig.active_floor:
			return Vector2(-1, -1)
		var top: Vector3 = world.top_of_iid(_sel_iid)
		if top == Vector3.INF:
			return Vector2(-1, -1)
		return world.camera_rig.world_to_screen(top + Vector3(0.0, TOOLBAR_LIFT_M, 0.0))
	if _sel_decor >= 0:
		var o: Dictionary = sim.decoration.item(_sel_decor)
		if not bool(o["placed"]) or StringName(str(o["floor_id"])) != world.camera_rig.active_floor:
			return Vector2(-1, -1)
		var top2: Vector3 = world.top_of_decor(_sel_decor)
		if top2 == Vector3.INF:
			return Vector2(-1, -1)
		return world.camera_rig.world_to_screen(top2 + Vector3(0.0, TOOLBAR_LIFT_M, 0.0))
	return Vector2(-1, -1)


## Letakkan toolbar tepat di atas barang terpilih, tetap di dalam layar di antara
## bilah atas dan tab bawah.
func _place_toolbar() -> void:
	if not _toolbar.visible:
		return
	var view: Vector2 = get_viewport_rect().size
	var sz: Vector2 = _toolbar.panel.get_combined_minimum_size()
	_toolbar.panel.size = sz
	var top_limit: float = _top.get_global_rect().end.y + EDGE_PX
	var bottom_limit: float = _bottom.get_global_rect().position.y - EDGE_PX
	var anchor: Vector2 = _toolbar_anchor()
	var pos: Vector2
	if anchor.x < 0.0:
		pos = Vector2((view.x - sz.x) * 0.5, bottom_limit - sz.y)
		_toolbar.tail_x = -1.0
	else:
		pos = Vector2(anchor.x - sz.x * 0.5, anchor.y - ActionBar.TAIL_H - sz.y)
		pos.x = clampf(pos.x, EDGE_PX, maxf(EDGE_PX, view.x - sz.x - EDGE_PX))
		pos.y = clampf(pos.y, top_limit, maxf(top_limit, bottom_limit - sz.y - ActionBar.TAIL_H))
		# Ekor hanya bila toolbar benar-benar berada tepat di atas titiknya.
		var tip_y: float = pos.y + sz.y + ActionBar.TAIL_H
		_toolbar.tail_x = clampf(anchor.x - pos.x, 20.0, sz.x - 20.0) if absf(tip_y - anchor.y) < 2.0 else -1.0
	_toolbar.position = pos
	_toolbar.size = sz + Vector2(0.0, ActionBar.TAIL_H)
	_toolbar.refresh_tail()


func _update_status() -> void:
	if _status.has_theme_color_override("font_color"):
		_status.remove_theme_color_override("font_color")
	if not has_selection():
		_status.text = Tx.t("ui_decor_hint")
		return
	var placed: bool = false
	if _sel_iid >= 0:
		placed = sim.equipment.get_inst(_sel_iid).placed
	else:
		placed = bool(sim.decoration.item(_sel_decor).get("placed", false))
		var t: StringName = _sel_decor_type()
		if sim.decoration.type_full(_sel_decor):
			_status.text = _reason_text(&"slots_full")
			_status.add_theme_color_override("font_color", Palette.DANGER)
			return
		if _is_slot_type(t):
			_status.text = Tx.t("ui_decor_slot_move") if placed else Tx.t("ui_decor_slot_hint_wall" if t == &"wall" else "ui_decor_slot_hint_counter")
			return
		if t == &"floor_overlay":
			_status.text = Tx.t("ui_decor_rug_hint")
			return
	_status.text = Tx.t("ui_decor_move_hint") if placed else Tx.t("ui_decor_place_hint")


# ===========================================================================
# ARSIRAN, PRATINJAU & PERINGATAN
# ===========================================================================

## Tampilkan peringatan untuk penempatan yang ditolak. Penolakan karena jalan
## memakai kalimat "menghalangi jalan"; alasan lain memakai teks alasannya.
func _warn_rejected(reason: StringName) -> void:
	if _warn == null:
		return
	_warn_title.text = Tx.t("ui_decor_full_title" if reason == &"slots_full" and _sel_decor >= 0 else "ui_decor_warn_title")
	_warn_detail.text = _reason_text(reason) if not WARN_KEYS.has(reason) else Tx.t(str(WARN_KEYS[reason]))
	_warn.visible = true
	_warn.modulate.a = 1.0
	if _warn_tween != null and _warn_tween.is_valid():
		_warn_tween.kill()
	_warn_tween = _warn.create_tween()
	_warn_tween.tween_interval(WARN_SECONDS)
	_warn_tween.tween_property(_warn, "modulate:a", 0.0, 0.3)
	_warn_tween.tween_callback(func() -> void: _warn.visible = false)
	EventBus.sfx.emit(&"ui_error", &"")


## Teks alasan penolakan. "Slot penuh" untuk dekorasi menyebut jenis dan batas
## lokasi ini (GDD 72.3).
func _reason_text(reason: StringName) -> String:
	if reason == &"slots_full" and _sel_decor >= 0:
		var t: StringName = _sel_decor_type()
		return Tx.t("ui_decor_slots_full", {"type": Tx.t("decor_type_" + String(t)), "count": sim.decoration.cap(t)})
	return Tx.t(str(REASON_KEYS.get(reason, "ui_decor_invalid_reserved")))


## Arsir ubin yang harus tetap kosong di lantai yang sedang dilihat; bila ada
## perabot terpilih, tandai juga ubin di luar area perabot itu.
func _refresh_overlay() -> void:
	if not is_instance_valid(game) or game.world == null:
		return
	var floor_id: StringName = game.world.camera_rig.active_floor
	_overlay_floor = floor_id
	var fg: FloorGrid = sim.world.grid(floor_id)
	if fg == null:
		return
	var keep: Dictionary = sim.world.keep_clear_cells(floor_id, _sel_iid)
	# Karpet tidak memblok apa pun (GDD 72.1) dan dekorasi dinding/meja tidak
	# memakai ubin: arsiran ubin wajib kosong hanya mengganggu penanda slotnya.
	var dt0: StringName = _sel_decor_type()
	if dt0 == &"floor_overlay" or _is_slot_type(dt0):
		keep = {}
	var clear_cells: Array[Vector2i] = []
	for c: Variant in keep.keys():
		clear_cells.append(c)
	var target_zone: StringName = &""
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		if e != null:
			target_zone = &"store" if e.category() == &"display" else &"kitchen"
	elif _sel_decor >= 0:
		var dt: StringName = _sel_decor_type()
		if dt == &"floor_prop" or dt == &"floor_overlay":
			target_zone = &"store"
	var wrong: Array[Vector2i] = []
	if target_zone != &"":
		for z in fg.size.y:
			for x in fg.size.x:
				var c2 := Vector2i(x, z)
				var zt: StringName = fg.def.zone_at(c2)
				if zt == &"" or zt == target_zone or keep.has(c2):
					continue
				if fg.flag(c2) == FloorGrid.Flag.WALKABLE_BUILDABLE and not fg.furniture_at.has(c2):
					wrong.append(c2)
	game.world.show_tile_overlay(clear_cells, wrong)
	_legend_clear.visible = not clear_cells.is_empty()
	_legend_zone.visible = not wrong.is_empty()
	_legend_clear.get_parent().get_parent().visible = _legend_clear.visible or _legend_zone.visible


func _process(_delta: float) -> void:
	# Pindah lantai (tombol L1/L2 atau pemilihan perabot): perbarui arsiran.
	if is_instance_valid(game) and game.world != null and game.world.camera_rig.active_floor != _overlay_floor:
		_refresh_overlay()
	_place_toolbar()


func _anchor_for(cell: Vector2i) -> Vector2i:
	var fp := Vector2i.ONE
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		fp = GridMath.rotated_footprint(e.def().footprint_tiles, _rot)
	elif _sel_decor_type() == &"floor_overlay":
		var o: Dictionary = sim.decoration.item(_sel_decor)
		fp = DecorSlots.overlay_footprint(sim.decoration.def_of(o), int(o.get("rot", 0)))
	return cell - Vector2i((fp.x - 1) / 2, (fp.y - 1) / 2)


func _preview(anchor: Vector2i) -> void:
	_last_cell = anchor
	var floor_id: StringName = game.world.camera_rig.active_floor
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		var reason: StringName = sim.world.validate_placement(e, floor_id, anchor, _rot)
		game.world.show_ghost(GridMath.footprint_cells(anchor, e.def().footprint_tiles, _rot), floor_id, reason == &"")
		_set_status(reason, reason == &"")
	elif _sel_decor >= 0:
		var t: StringName = _sel_decor_type()
		if _is_slot_type(t):
			return
		var o: Dictionary = sim.decoration.item(_sel_decor)
		var reason2: StringName = sim.decoration.check_place(_sel_decor, floor_id, anchor, -1, int(o.get("rot", 0)))
		game.world.show_ghost(_decor_cells(anchor), floor_id, reason2 == &"")
		_set_status(reason2, reason2 == &"")


## Ubin yang akan ditempati dekorasi lantai/karpet terpilih berjangkar `anchor`.
func _decor_cells(anchor: Vector2i) -> Array[Vector2i]:
	var o: Dictionary = sim.decoration.item(_sel_decor)
	if sim.decoration.type_of(o) == &"floor_overlay":
		return DecorSlots.overlay_cells(sim.decoration.def_of(o), anchor, int(o.get("rot", 0)))
	return [anchor]


func _set_status(reason: StringName, ok: bool) -> void:
	if ok:
		_status.text = Tx.t("ui_decor_valid")
		_status.add_theme_color_override("font_color", Palette.SUCCESS)
	else:
		_status.text = _reason_text(reason)
		_status.add_theme_color_override("font_color", Palette.DANGER)


# ===========================================================================
# KETUKAN DUNIA
# ===========================================================================

## Tanpa pilihan: ketuk perabot untuk memilihnya. Dengan pilihan: ketuk ubin
## kosong untuk memindahkannya ke sana, ketuk perabot lain untuk berganti
## pilihan, atau ketuk perabot terpilih itu sendiri untuk selesai.
func _on_world_tap(pos: Vector2) -> void:
	var cell: Vector2i = game.world.cell_at_screen(pos)
	var floor_id: StringName = game.world.camera_rig.active_floor
	# Dekorasi dinding/meja terpilih: penanda slot yang menyala didahulukan.
	if _sel_decor >= 0 and _is_slot_type(_sel_decor_type()):
		var slot: int = game.world.slot_at_screen(pos)
		if slot >= 0:
			_place_decor_slot(slot)
			return
	var p: Dictionary = game.world.pick(pos)
	var kind: StringName = p.get("kind", &"")
	if not has_selection():
		if kind == &"equipment":
			_select_equipment(int(p["iid"]))
		elif kind == &"decor":
			_select_decor(int(p["uid"]))
		return
	# Badan perabot yang terlihat (kotak 3D-nya, bukan ubin akses di depannya):
	# perabot terpilih itu sendiri -> selesai, perabot lain -> ganti pilihan.
	if kind == &"equipment" and not p.has("cell"):
		if int(p["iid"]) == _sel_iid:
			_deselect()
		else:
			_select_equipment(int(p["iid"]))
		return
	if kind == &"decor":
		var duid: int = int(p["uid"])
		if duid == _sel_decor:
			_deselect()
			return
		# Karpet di bawah jari tetap sasaran bagi alat dan dekorasi lantai.
		if not p.has("cell") or (_sel_iid < 0 and _sel_decor_type() != &"floor_prop"):
			_select_decor(duid)
			return
	if _sel_decor >= 0 and _is_slot_type(_sel_decor_type()):
		if sim.decoration.free_slots(_sel_decor_type(), _sel_decor).is_empty():
			_set_status(&"slots_full", false)
			_warn_rejected(&"slots_full")
		else:
			_status.text = Tx.t("ui_decor_pick_slot")
			_status.add_theme_color_override("font_color", Palette.WARNING)
		return
	if _sel_iid >= 0:
		var anchor: Vector2i = _anchor_for(cell)
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		var reason: StringName = sim.equipment.place(_sel_iid, floor_id, anchor, _rot)
		if reason == &"":
			EventBus.sfx.emit(&"bread_place_display", floor_id)
			game.world.clear_ghost()
			game.world.set_lift(_sel_iid)
			_last_cell = Vector2i(-1, -1)
			_refresh_overlay()
			_refresh_all()
			_set_status(&"", true)
		else:
			game.world.show_ghost(GridMath.footprint_cells(anchor, e.def().footprint_tiles, _rot), floor_id, false)
			_set_status(reason, false)
			_warn_rejected(reason)
	elif _sel_decor >= 0:
		var anchor2: Vector2i = _anchor_for(cell)
		var r2: StringName = sim.decoration.place(_sel_decor, floor_id, anchor2, -1)
		if r2 == &"":
			EventBus.sfx.emit(&"bread_place_display", floor_id)
			game.world.set_decor_lift(_sel_decor)
			game.world.show_ghost(_decor_cells(anchor2), floor_id, true)
			_refresh_overlay()
			_refresh_all()
			_set_status(&"", true)
		else:
			game.world.show_ghost(_decor_cells(anchor2), floor_id, false)
			_set_status(r2, false)
			_warn_rejected(r2)


func _input(event: InputEvent) -> void:
	# Pratinjau hover (mouse); pada layar sentuh pratinjau muncul saat tap.
	if event is InputEventMouseMotion and has_selection():
		var mm: InputEventMouseMotion = event
		# Di atas toolbar atau bilah UI: jangan memindahkan pratinjau.
		if _over_ui(mm.position):
			return
		var cell: Vector2i = game.world.cell_at_screen(mm.position)
		var anchor: Vector2i = _anchor_for(cell)
		if anchor != _last_cell:
			_preview(anchor)


func _over_ui(p: Vector2) -> bool:
	for c: Control in [_top, _bottom, _toolbar.panel]:
		if c.is_visible_in_tree() and c.get_global_rect().has_point(p):
			return true
	return false


## Putar 90°. Alat yang sudah terpasang langsung diputar di tempat (titik
## tengahnya tetap) bila posisinya sah; bila tidak, pratinjau merah beserta
## alasannya tampil dan putaran itu dipakai saat ubin tujuan diketuk.
func _rotate() -> void:
	if _sel_decor >= 0:
		_rotate_rug()
		return
	if _sel_iid < 0:
		return
	var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
	var new_rot: int = (_rot + 1) % 4
	if not e.placed:
		_rot = new_rot
		if _last_cell.x >= 0:
			_preview(_last_cell)
		return
	var fp: Vector2i = e.def().footprint_tiles
	var cur: Vector2i = GridMath.rotated_footprint(fp, e.rotation)
	var center: Vector2i = e.anchor + Vector2i((cur.x - 1) / 2, (cur.y - 1) / 2)
	var nxt: Vector2i = GridMath.rotated_footprint(fp, new_rot)
	var keep_center: Vector2i = center - Vector2i((nxt.x - 1) / 2, (nxt.y - 1) / 2)
	_rot = new_rot
	for cand: Vector2i in [keep_center, e.anchor]:
		if sim.world.validate_placement(e, e.floor_id, cand, new_rot) == &"":
			sim.equipment.place(_sel_iid, e.floor_id, cand, new_rot)
			EventBus.sfx.emit(&"bread_place_display", e.floor_id)
			game.world.clear_ghost()
			game.world.set_lift(_sel_iid)
			_refresh_overlay()
			_refresh_all()
			_set_status(&"", true)
			return
	var reason: StringName = sim.world.validate_placement(e, e.floor_id, keep_center, new_rot)
	game.world.show_ghost(GridMath.footprint_cells(keep_center, fp, new_rot), e.floor_id, false)
	_last_cell = keep_center
	_set_status(reason, false)
	_warn_rejected(reason)


## Karpet (GDD 72.1): terpasang = berputar di tempat bila muat; belum
## terpasang = putaran dipakai saat ubin tujuan diketuk.
func _rotate_rug() -> void:
	var o: Dictionary = sim.decoration.item(_sel_decor)
	if sim.decoration.type_of(o) != &"floor_overlay":
		return
	var r: StringName = sim.decoration.rotate_overlay(_sel_decor)
	if r != &"":
		_set_status(r, false)
		_warn_rejected(r)
		return
	if bool(o["placed"]):
		EventBus.sfx.emit(&"bread_place_display", StringName(str(o["floor_id"])))
		game.world.show_ghost(sim.decoration.overlay_cells(o), StringName(str(o["floor_id"])), true)
		_set_status(&"", true)
	elif _last_cell.x >= 0:
		_preview(_last_cell)


func _put_away() -> void:
	if _sel_iid >= 0:
		var r: StringName = sim.equipment.put_away(_sel_iid)
		if r != &"":
			_set_status(r, false)
			return
	elif _sel_decor >= 0:
		sim.decoration.put_away(_sel_decor)
	_deselect()


## Back/Escape/klik kanan: lepaskan pilihan dulu, baru keluar dari mode ini.
func on_back() -> bool:
	if has_selection():
		_deselect()
		return true
	close()
	return true


func on_closed() -> void:
	if sim.world.layout_changed.is_connected(_refresh_overlay):
		sim.world.layout_changed.disconnect(_refresh_overlay)
	game.world.clear_tile_overlay()
	game.world.camera_rig.set_free_pan(false)
	game.world.clear_ghost()
	game.world.clear_slot_markers()
	game.world.set_lift(-1)
	game.world.set_decor_lift(-1)
	game.world.decoration_mode = false
	game.world.view_floor_override = &""
	game.commands.tap_override = Callable()
	game.hud.set_decoration_active(false)


## Toolbar melayang: panel krem dengan ekor segitiga yang menunjuk ke barang.
## Ekornya digambar di anak terakhir supaya berada di atas bayangan panel.
class ActionBar extends Control:
	const TAIL_H: float = 14.0
	const TAIL_W: float = 26.0

	var panel: PanelContainer = null
	## Posisi x ujung ekor dalam koordinat lokal; < 0 = tanpa ekor.
	var tail_x: float = -1.0
	var _tail: Control = null

	func _init() -> void:
		name = "DecorToolbar"
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel = PanelContainer.new()
		panel.name = "Panel"
		var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PARCHMENT, 18, true)
		sb.border_color = Color(Palette.UI_WOOD, 0.45)
		sb.set_border_width_all(2)
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.content_margin_top = 6
		sb.content_margin_bottom = 8
		panel.add_theme_stylebox_override("panel", sb)
		panel.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(panel)
		_tail = Control.new()
		_tail.name = "Tail"
		_tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_tail.draw.connect(_draw_tail)
		add_child(_tail)

	func refresh_tail() -> void:
		_tail.queue_redraw()

	func _draw_tail() -> void:
		if tail_x < 0.0:
			return
		var y: float = panel.size.y - 3.0
		var pts := PackedVector2Array([Vector2(tail_x - TAIL_W * 0.5, y), Vector2(tail_x + TAIL_W * 0.5, y), Vector2(tail_x, y + TAIL_H)])
		_tail.draw_colored_polygon(pts, Palette.PARCHMENT)
		_tail.draw_polyline(PackedVector2Array([pts[0] + Vector2(0.0, 1.0), pts[2], pts[1] + Vector2(0.0, 1.0)]), Color(Palette.UI_WOOD, 0.45), 2.0, true)
