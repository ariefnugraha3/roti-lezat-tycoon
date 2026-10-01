class_name DecorationScreen
extends UIScreen
## Decoration Mode (GDD 7, 17.3-17.4, 56.1, 60.1, 72, 72.1). Membukanya
## mem-pause simulasi; ketukan dan drag di dunia diteruskan ke sini.
##
## Memindah barang meniru The Sims (keputusan maintainer 2026-10-01, GDD 72.2):
## ketuk atau seret perabot untuk MENGANGKATNYA. Barang yang dipegang digambar
## di posisi calonnya; seret untuk menggesernya per ubin, atau ketuk ubin mana
## pun untuk memindahkannya ke sana. Selama memegang, ketukan selalu berarti
## ubin lantai di bawah jari (juga ubin yang tertutup model perabot): ketukan
## tidak pernah memilih perabot lain dan tidak pernah membatalkan. Petak
## jejaknya putih bila sah, merah bersilang beserta alasannya bila tidak. Tata
## letak simulasi baru berubah saat Place diketuk; Cancel, Back, atau klik
## kanan mengembalikan barang ke tempat semula. Perabot IN_USE tidak dapat
## diangkat. Ubin yang harus tetap kosong (jalur, antrean, titik layanan, akses
## perabot, leher botol) diarsir merah selama mode ini (GDD 17.4 "preview merah
## dan tampilkan alasan"). Decor Shop hanya aktif after-hours.
##
## Tata letak (keputusan maintainer 2026-09-30): TANPA panel samping, supaya
## dunia terlihat penuh. Bilah atas tipis (judul, petunjuk, lantai, Done); tab di
## tepi bawah yang membuka baki barang (Equipment / Your Decorations / Decor
## Shop); dan toolbar aksi (Place, Rotate, Put Away, Cancel) yang melayang tepat
## di atas barang yang dipegang dan ikut pindah bersamanya. Barang yang tidak
## digambar di lantai yang sedang dilihat memakai toolbar yang berlabuh di atas
## tab.
##
## Dekorasi (GDD 72.3): semuanya di lantai toko. Dekorasi dinding/meja yang
## dipegang menyalakan penanda slot bebas; ketuk (atau seret ke) penanda untuk
## mencobanya di sana. Karpet dipindah seperti perabot dan bisa diputar. Batas
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
## Barang diseret sampai sejauh ini dari tepi layar: kamera ikut bergeser (px,
## px per detik).
const EDGE_PAN_PX: float = 56.0
const EDGE_PAN_SPEED: float = 520.0
const NO_CELL: Vector2i = Vector2i(-1, -1)

## Barang yang sedang dipegang (-1 = tidak ada).
var _sel_iid: int = -1
var _sel_decor: int = -1
## Posisi calon barang yang dipegang (GDD 72.2): lantai + jangkar jejak untuk
## alat dan dekorasi lantai/karpet, nomor slot untuk dekorasi dinding/meja.
## Tata letak simulasi tidak berubah sampai Place.
var _rot: int = 0
var _cand_floor: StringName = &""
var _cand_cell: Vector2i = NO_CELL
var _cand_slot: int = -1
## "" = posisi calon sah; selain itu kode alasan penolakannya.
var _cand_reason: StringName = &"invalid"
## Posisi saat barang diangkat (untuk petunjuk "sudah digeser").
var _start_floor: StringName = &""
var _start_cell: Vector2i = NO_CELL
var _start_slot: int = -1
var _start_rot: int = 0
## Gestur dunia: titik tekan, perabot di bawahnya (drag dari keadaan diam
## langsung mengangkatnya), dan drag barang yang sedang berjalan.
var _press_pos: Vector2 = Vector2.ZERO
var _press_pick: Dictionary = {}
var _drag_active: bool = false
var _drag_cell0: Vector2i = NO_CELL
var _drag_anchor0: Vector2i = NO_CELL
var _drag_pos: Vector2 = Vector2.ZERO
## Barang dari baki menunggu kamera tiba di lantainya untuk disorot.
var _focus_pending: bool = false
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
var _tb_place: Button = null
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
	game.commands.press_override = _on_world_press
	game.commands.drag_override = _on_world_drag
	game.commands.drop_override = _on_world_drop
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
		_hold_equipment(pre)
		_focus_pending = has_selection()
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
	var done: Button = btn(row, Tx.t("ui_decor_done"), "primary", _done)
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


## Toolbar aksi yang melayang di atas barang yang dipegang: Place, Rotate, Put
## Away, Cancel.
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
	_tb_place = _icon_text_button("check", Tx.t("ui_decor_place"), "success", _place)
	row.add_child(_tb_place)
	_tb_rotate = _icon_text_button("rotate", Tx.t("ui_decor_rotate"), "secondary", _rotate)
	row.add_child(_tb_rotate)
	_tb_store = _icon_text_button("box", Tx.t("ui_decor_store"), "secondary", _put_away)
	row.add_child(_tb_store)
	_tb_cancel = ProceduralUIFactory.icon_button("cross", Tx.t("ui_cancel"), "ghost")
	_tb_cancel.pressed.connect(_cancel)
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


## Kartu barang: angkat barangnya, tutup baki supaya dunia terlihat, lalu
## arahkan kamera ke sana bila ia di luar layar.
func _pick_equipment_card(iid: int) -> void:
	_tab = -1
	_hold_equipment(iid)
	_focus_pending = has_selection()


func _pick_decor_card(uid: int) -> void:
	_tab = -1
	_hold_decor(uid)
	_focus_pending = has_selection()


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
# MEMEGANG BARANG (GDD 72.2, seperti The Sims)
# ===========================================================================

## Angkat alat `iid`. Alat yang sedang dipakai tidak bisa diangkat. Alat yang
## belum terpasang muncul di tempat sah terdekat dari tengah layar, seperti
## barang baru di The Sims; bila kategorinya sudah penuh, ia tetap disimpan.
func _hold_equipment(iid: int) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null:
		return
	if e.placed and sim.equipment.is_in_use(iid):
		_refresh_all()
		_set_status(&"in_use", false)
		return
	_drop_hold()
	if not e.placed and not EquipmentManager.is_fixture(e.category()) \
		and sim.equipment.placed_count(e.category()) >= sim.equipment.slot_limit(e.category()):
		_refresh_all()
		_set_status(&"slots_full", false)
		_warn_rejected(&"slots_full")
		return
	_sel_iid = iid
	_rot = e.rotation
	if e.placed:
		_cand_floor = e.floor_id
		_cand_cell = e.anchor
	else:
		var allowed: Array[StringName] = sim.world.floors_for_category(e.category())
		_cand_floor = game.world.camera_rig.active_floor if allowed.has(game.world.camera_rig.active_floor) else allowed[0]
		_spawn()
	_begin_hold()


## Angkat dekorasi `uid` (GDD 72.3). Dinding/meja: slot bebas menyala dan barang
## yang belum terpasang mencoba slot bebas pertama. Lantai/karpet yang belum
## terpasang muncul di ubin sah terdekat dari tengah layar. Jenis yang sudah
## penuh tidak diangkat; banner menyebut batas lokasi ini.
func _hold_decor(uid: int) -> void:
	var o: Dictionary = sim.decoration.item(uid)
	if o.is_empty():
		return
	_drop_hold()
	if sim.decoration.type_full(uid):
		_refresh_all()
		_set_status(&"slots_full", false, uid)
		_warn_rejected(&"slots_full", uid)
		return
	_sel_decor = uid
	_rot = int(o.get("rot", 0))
	_cand_floor = sim.decoration.store_floor()
	var t: StringName = sim.decoration.type_of(o)
	if bool(o["placed"]):
		if _is_slot_type(t):
			_cand_slot = int(o["slot"])
		else:
			_cand_cell = SimManager.arr_to_cell(o["cell"])
	elif _is_slot_type(t):
		var free: Array[int] = sim.decoration.free_slots(t, uid)
		_cand_slot = free[0] if not free.is_empty() else -1
	else:
		_spawn()
	_begin_hold()


## Catat posisi awal pegangan, pindahkan tampilan ke lantainya, lalu gambar.
func _begin_hold() -> void:
	_start_floor = _cand_floor
	_start_cell = _cand_cell
	_start_slot = _cand_slot
	_start_rot = _rot
	game.world.view_floor_override = _cand_floor
	_update_candidate()
	_refresh_overlay()
	_refresh_all()


## Lepaskan barang yang dipegang TANPA menaruhnya: modelnya kembali ke tempat
## yang tersimpan (barang baru kembali ke inventaris).
func _drop_hold() -> void:
	_sel_iid = -1
	_sel_decor = -1
	_cand_floor = &""
	_cand_cell = NO_CELL
	_cand_slot = -1
	_cand_reason = &"invalid"
	_drag_active = false
	_focus_pending = false
	game.world.release_hold()
	game.world.clear_ghost()
	game.world.clear_slot_markers()


## ✕ Cancel / Back / klik kanan: barang kembali ke tempat semula.
func _cancel() -> void:
	if not has_selection():
		return
	_drop_hold()
	_refresh_overlay()
	_refresh_all()


## ✓ Place: taruh barang di posisi calonnya (GDD 17.4 "furniture baru
## benar-benar di-commit saat drop valid"). Tidak sah: banner alasannya, barang
## tetap dipegang supaya bisa digeser ke tempat yang muat.
func _place() -> void:
	if not has_selection():
		return
	if _cand_reason != &"":
		_set_status(_cand_reason, false)
		_warn_rejected(_cand_reason)
		return
	var r: StringName = &""
	if not _unmoved():
		if _sel_iid >= 0:
			r = sim.equipment.place(_sel_iid, _cand_floor, _cand_cell, _rot)
		else:
			r = sim.decoration.place(_sel_decor, _cand_floor, _cand_cell, _cand_slot, _rot)
	if r != &"":
		_set_status(r, false)
		_warn_rejected(r)
		return
	EventBus.sfx.emit(&"bread_place_display", _cand_floor)
	_drop_hold()
	_refresh_overlay()
	_refresh_all()


## Done: barang yang dipegang di tempat yang sah ikut ditaruh, lalu mode ditutup.
func _done() -> void:
	if has_selection() and _cand_reason == &"":
		_place()
	close()


## true bila posisi calon sama dengan posisi tersimpan barang yang sudah terpasang.
func _unmoved() -> bool:
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		return e.placed and e.floor_id == _cand_floor and e.anchor == _cand_cell and e.rotation == _rot
	var o: Dictionary = sim.decoration.item(_sel_decor)
	if not bool(o.get("placed", false)) or StringName(str(o["floor_id"])) != _cand_floor:
		return false
	if _is_slot_type(_sel_decor_type()):
		return int(o["slot"]) == _cand_slot
	return SimManager.arr_to_cell(o["cell"]) == _cand_cell and int(o.get("rot", 0)) == _rot


## true bila barang belum digeser atau diputar sejak diangkat.
func _at_start() -> bool:
	return _cand_floor == _start_floor and _cand_cell == _start_cell and _cand_slot == _start_slot and _rot == _start_rot


func has_selection() -> bool:
	return _sel_iid >= 0 or _sel_decor >= 0


func toolbar() -> ActionBar:
	return _toolbar


static func _is_slot_type(t: StringName) -> bool:
	return t == &"wall" or t == &"counter_prop"


func _sel_decor_type() -> StringName:
	return sim.decoration.type_of(sim.decoration.item(_sel_decor)) if _sel_decor >= 0 else &""


## true bila barang yang dipegang punya posisi calon (ubin atau slot).
func _has_cand() -> bool:
	if _is_slot_type(_sel_decor_type()):
		return _cand_slot >= 0
	return has_selection() and _cand_cell != NO_CELL


## "" bila barang yang dipegang boleh ditaruh di posisi calonnya; selain itu
## kode alasan (GDD 17.3-17.4, 72.3).
func _check_candidate() -> StringName:
	if not _has_cand():
		return &"invalid"
	if _sel_iid >= 0:
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		return sim.world.validate_placement(e, _cand_floor, _cand_cell, _rot)
	return sim.decoration.check_place(_sel_decor, _cand_floor, _cand_cell, _cand_slot, _rot)


## Gambar barang yang dipegang di posisi calonnya: model terangkat di sana,
## petak jejak putih (sah) atau merah bersilang, penanda slot untuk dekorasi
## dinding/meja, lalu toolbar dan petunjuk.
func _update_candidate() -> void:
	if not has_selection():
		return
	_cand_reason = _check_candidate()
	var world: WorldView = game.world
	world.hold({"kind": &"equipment" if _sel_iid >= 0 else &"decor", "id": _sel_iid if _sel_iid >= 0 else _sel_decor,
		"floor": _cand_floor, "cell": _cand_cell, "rot": _rot, "slot": _cand_slot})
	if _is_slot_type(_sel_decor_type()):
		world.clear_ghost()
		_show_slots()
	elif _has_cand():
		world.show_ghost(world.hold_cells(), _cand_floor, _cand_reason == &"")
	else:
		world.clear_ghost()
	_update_toolbar_content()
	_update_status()


## Nyalakan penanda slot yang boleh dipakai dekorasi yang dipegang; slot
## calonnya emas.
func _show_slots() -> void:
	var t: StringName = _sel_decor_type()
	game.world.show_slot_markers(t, sim.decoration.free_slots(t, _sel_decor), _cand_slot)


## Ukuran jejak barang yang dipegang (ubin) dengan putaran saat ini.
func _footprint() -> Vector2i:
	if _sel_iid >= 0:
		return GridMath.rotated_footprint(sim.equipment.get_inst(_sel_iid).def().footprint_tiles, _rot)
	if _sel_decor_type() == &"floor_overlay":
		return DecorSlots.overlay_footprint(sim.decoration.def_of(sim.decoration.item(_sel_decor)), _rot)
	return Vector2i.ONE


## Jangkar yang menaruh tengah jejak barang di ubin `cell`.
func _anchor_for(cell: Vector2i) -> Vector2i:
	var fp: Vector2i = _footprint()
	return cell - Vector2i((fp.x - 1) / 2, (fp.y - 1) / 2)


## Jangkar yang menjaga seluruh jejak di dalam lantai: barang yang diseret
## keluar ruangan meluncur di sepanjang dindingnya.
func _clamp_anchor(a: Vector2i) -> Vector2i:
	var fg: FloorGrid = sim.world.grid(_cand_floor)
	if fg == null:
		return a
	var fp: Vector2i = _footprint()
	return Vector2i(clampi(a.x, 0, maxi(0, fg.size.x - fp.x)), clampi(a.y, 0, maxi(0, fg.size.y - fp.y)))


## Putaran yang dicoba untuk barang yang dipegang, putaran saat ini lebih dulu.
func _rotations() -> Array[int]:
	var out: Array[int] = [_rot]
	if _sel_iid >= 0:
		var allowed: Array[int] = sim.equipment.get_inst(_sel_iid).def().rotations_allowed
		for i in range(1, 4):
			var r: int = (_rot + i) % 4
			if allowed.has(r * 90):
				out.append(r)
	elif _sel_decor_type() == &"floor_overlay":
		out.append((_rot + 1) % 2)
	return out


## Tempat awal barang baru: jangkar sah terdekat dari tengah layar di lantai
## calon (putaran saat ini lebih dulu, lalu putaran lain). Tanpa tempat sah,
## barang muncul merah di tengah dan bisa digeser.
func _spawn() -> void:
	var fg: FloorGrid = sim.world.grid(_cand_floor)
	if fg == null:
		return
	var origin: Vector2i = fg.size / 2
	if _cand_floor == game.world.camera_rig.active_floor:
		var view: Vector2 = get_viewport_rect().size
		var c: Vector2i = game.world.cell_at_screen(view * 0.5)
		if c != NO_CELL:
			origin = Vector2i(clampi(c.x, 0, fg.size.x - 1), clampi(c.y, 0, fg.size.y - 1))
	var cells: Array[Vector2i] = []
	for z in fg.size.y:
		for x in fg.size.x:
			cells.append(Vector2i(x, z))
	cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		var da: int = (a - origin).length_squared()
		var db: int = (b - origin).length_squared()
		if da != db:
			return da < db
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x)
	var first: int = _rot
	for r: int in _rotations():
		_rot = r
		for c2: Vector2i in cells:
			_cand_cell = _clamp_anchor(_anchor_for(c2))
			if _check_candidate() == &"":
				return
	_rot = first
	_cand_cell = _clamp_anchor(_anchor_for(origin))


## Toolbar mengikuti barang yang dipegang: Rotate untuk alat dan karpet, Put Away
## hanya untuk yang sudah terpasang dan boleh disimpan (Gudang & Meja Tunggu
## tidak).
func _update_toolbar_content() -> void:
	_toolbar.visible = has_selection() and not _drag_active
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
	# Place selalu bisa diketuk: di tempat yang tidak sah ia memudar dan
	# ketukannya menjelaskan alasannya, seperti jejak merah di lantai.
	var ok: bool = _cand_reason == &""
	_tb_place.modulate = Color(1.0, 1.0, 1.0, 1.0 if ok else 0.5)
	_tb_place.tooltip_text = Tx.t("ui_decor_place") if ok else _reason_text(_cand_reason)
	_toolbar.panel.reset_size()


## Titik layar yang ditunjuk ekor toolbar, atau (-1, -1) bila barang yang
## dipegang tidak digambar di lantai yang sedang dilihat (toolbar berlabuh di
## bawah).
func _toolbar_anchor() -> Vector2:
	var top: Vector3 = game.world.hold_top()
	if top == Vector3.INF:
		return Vector2(-1, -1)
	return game.world.camera_rig.world_to_screen(top + Vector3(0.0, TOOLBAR_LIFT_M, 0.0))


## Letakkan toolbar tepat di atas barang yang dipegang, tetap di dalam layar di
## antara bilah atas dan tab bawah. Selama barang diseret toolbar disembunyikan.
func _place_toolbar() -> void:
	_toolbar.visible = has_selection() and not _drag_active
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


## Petunjuk di bilah atas: cara mengangkat, cara memindah barang yang dipegang,
## "sah, ketuk Place" setelah digeser, atau alasan penolakan (merah).
func _update_status() -> void:
	if _status.has_theme_color_override("font_color"):
		_status.remove_theme_color_override("font_color")
	if not has_selection():
		_status.text = Tx.t("ui_decor_hint")
		return
	if _cand_reason != &"" and _has_cand():
		_set_status(_cand_reason, false)
		return
	var t: StringName = _sel_decor_type()
	if not _at_start() and _has_cand():
		_set_status(&"", true)
	elif _is_slot_type(t):
		_status.text = Tx.t("ui_decor_slot_hint_wall" if t == &"wall" else "ui_decor_slot_hint_counter")
	elif t == &"floor_overlay":
		_status.text = Tx.t("ui_decor_rug_hint")
	else:
		var placed: bool = sim.equipment.get_inst(_sel_iid).placed if _sel_iid >= 0 else bool(sim.decoration.item(_sel_decor).get("placed", false))
		_status.text = Tx.t("ui_decor_move_hint") if placed else Tx.t("ui_decor_place_hint")


# ===========================================================================
# ARSIRAN & PERINGATAN
# ===========================================================================

## Tampilkan peringatan untuk penempatan yang ditolak. Penolakan karena jalan
## memakai kalimat "menghalangi jalan"; alasan lain memakai teks alasannya.
func _warn_rejected(reason: StringName, uid: int = -1) -> void:
	if _warn == null:
		return
	var decor: bool = (uid if uid >= 0 else _sel_decor) >= 0
	_warn_title.text = Tx.t("ui_decor_full_title" if reason == &"slots_full" and decor else "ui_decor_warn_title")
	_warn_detail.text = _reason_text(reason, uid) if not WARN_KEYS.has(reason) else Tx.t(str(WARN_KEYS[reason]))
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
## lokasi ini (GDD 72.3); `uid` = dekorasi yang dimaksud (bawaan: yang dipegang).
func _reason_text(reason: StringName, uid: int = -1) -> String:
	var u: int = uid if uid >= 0 else _sel_decor
	if reason == &"slots_full" and u >= 0:
		var t: StringName = sim.decoration.type_of(sim.decoration.item(u))
		return Tx.t("ui_decor_slots_full", {"type": Tx.t("decor_type_" + String(t)), "count": sim.decoration.cap(t)})
	return Tx.t(str(REASON_KEYS.get(reason, "ui_decor_invalid_reserved")))


## Arsir ubin yang harus tetap kosong di lantai yang sedang dilihat; bila ada
## barang yang dipegang, tandai juga ubin di luar area barang itu.
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
		if dt0 == &"floor_prop" or dt0 == &"floor_overlay":
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


func _process(delta: float) -> void:
	# Pindah lantai (tombol L1/L2 atau barang di lantai lain): perbarui arsiran.
	if is_instance_valid(game) and game.world != null and game.world.camera_rig.active_floor != _overlay_floor:
		_refresh_overlay()
	if _drag_active:
		_edge_pan(delta)
	if _focus_pending:
		_focus_hold()
	_place_toolbar()


## Barang dari baki: arahkan kamera ke sana bila ia di luar area dunia yang
## terlihat. Menunggu sampai kamera sudah berada di lantainya.
func _focus_hold() -> void:
	if not has_selection():
		_focus_pending = false
		return
	var top: Vector3 = game.world.hold_top()
	if top == Vector3.INF:
		return
	_focus_pending = false
	var p: Vector2 = game.world.camera_rig.world_to_screen(top)
	var view: Vector2 = get_viewport_rect().size
	var y0: float = _top.get_global_rect().end.y + 40.0
	var y1: float = _bottom.get_global_rect().position.y - 20.0
	if p.x < 60.0 or p.x > view.x - 60.0 or p.y < y0 or p.y > y1:
		game.world.camera_rig.focus_free_pan(top)


func _set_status(reason: StringName, ok: bool, uid: int = -1) -> void:
	if ok:
		_status.text = Tx.t("ui_decor_valid")
		_status.add_theme_color_override("font_color", Palette.SUCCESS)
	else:
		_status.text = _reason_text(reason, uid)
		_status.add_theme_color_override("font_color", Palette.DANGER)


# ===========================================================================
# KETUKAN & DRAG DUNIA
# ===========================================================================

## Ketukan dunia. Tanpa pegangan: ketuk perabot atau dekorasi untuk
## mengangkatnya. Saat memegang, ketukan TIDAK PERNAH memilih perabot lain dan
## tidak pernah membatalkan: barang pindah sehingga tengahnya berada di ubin
## lantai di bawah jari, walau ubin itu tertutup model perabot (sinar layar
## menembus sampai lantai). Dekorasi dinding/meja pindah ke penanda slot yang
## diketuk.
func _on_world_tap(pos: Vector2) -> void:
	if not has_selection():
		var p: Dictionary = game.world.pick(pos)
		match p.get("kind", &""):
			&"equipment":
				_hold_equipment(int(p["iid"]))
			&"decor":
				_hold_decor(int(p["uid"]))
		return
	if _is_slot_type(_sel_decor_type()):
		var slot: int = game.world.slot_at_screen(pos)
		if slot >= 0:
			_cand_slot = slot
			_update_candidate()
		elif not game.world.hold_hit(pos):
			_status.text = Tx.t("ui_decor_pick_slot")
			_status.add_theme_color_override("font_color", Palette.WARNING)
		return
	var cell: Vector2i = game.world.cell_at_screen(pos)
	if cell == NO_CELL:
		return
	_cand_floor = game.world.camera_rig.active_floor
	_cand_cell = _clamp_anchor(_anchor_for(cell))
	_update_candidate()


## Tekan di dunia (CommandLayer.press_override): true bila drag gestur ini
## menyeret barang, bukan kamera. Saat memegang: hanya barang itu sendiri
## (badan modelnya atau ubin jejaknya). Tanpa pegangan: badan perabot atau
## dekorasi berdiri yang boleh dipindah; drag-nya langsung mengangkat lalu
## menyeretnya. Karpet hanya diangkat dengan ketukan, supaya drag di lantai
## tetap menggeser kamera.
func _on_world_press(pos: Vector2) -> bool:
	_press_pos = pos
	_press_pick = {}
	if has_selection():
		return game.world.hold_hit(pos)
	var p: Dictionary = game.world.pick(pos)
	match p.get("kind", &""):
		&"equipment":
			if p.has("cell") or sim.equipment.is_in_use(int(p["iid"])):
				return false
			_press_pick = p
			return true
		&"decor":
			if p.has("cell"):
				return false
			_press_pick = p
			return true
	return false


## Drag barang: ia ikut jari per ubin, relatif terhadap titik yang dipegang,
## jadi menggeser satu ubin cukup dengan menyeret sejauh satu ubin.
func _on_world_drag(pos: Vector2) -> void:
	if not _drag_active:
		if not _press_pick.is_empty():
			var p: Dictionary = _press_pick
			_press_pick = {}
			if p["kind"] == &"equipment":
				_hold_equipment(int(p["iid"]))
			else:
				_hold_decor(int(p["uid"]))
		if not has_selection():
			return
		_drag_active = true
		_drag_cell0 = game.world.cell_at_screen(_press_pos)
		_drag_anchor0 = _cand_cell
	_drag_pos = pos
	_drag_to(pos)


func _on_world_drop(pos: Vector2) -> void:
	if _drag_active and has_selection():
		_drag_to(pos)
		EventBus.sfx.emit(&"ui_tap_soft", &"")
	_drag_active = false
	_press_pick = {}


func _drag_to(pos: Vector2) -> void:
	if _is_slot_type(_sel_decor_type()):
		var slot: int = game.world.slot_at_screen(pos)
		if slot >= 0 and slot != _cand_slot:
			_cand_slot = slot
			_update_candidate()
		return
	var cell: Vector2i = game.world.cell_at_screen(pos)
	if cell == NO_CELL or _drag_cell0 == NO_CELL:
		return
	var a: Vector2i = _clamp_anchor(_drag_anchor0 + cell - _drag_cell0)
	if a != _cand_cell:
		_cand_cell = a
		_update_candidate()


## Barang diseret ke tepi layar (atau ke atas bilah UI): kamera ikut bergeser
## dan barang tetap di bawah jari.
func _edge_pan(delta: float) -> void:
	var view: Vector2 = get_viewport_rect().size
	var p: Vector2 = _drag_pos
	var push := Vector2.ZERO
	if p.x < EDGE_PAN_PX:
		push.x = 1.0
	elif p.x > view.x - EDGE_PAN_PX:
		push.x = -1.0
	if p.y < _top.get_global_rect().end.y:
		push.y = 1.0
	elif p.y > _bottom.get_global_rect().position.y:
		push.y = -1.0
	if push == Vector2.ZERO:
		return
	game.world.camera_rig.pan_by_screen(push * EDGE_PAN_SPEED * delta)
	_drag_to(p)


## Putar 90° di tempat (titik tengahnya tetap), seperti The Sims. Bila tidak
## muat, jangkar lama dan geseran kecil dicoba; tetap tidak muat = merah beserta
## alasannya, dan barang bisa digeser ke tempat yang muat. Belum ditaruh sampai
## Place.
func _rotate() -> void:
	if not _has_cand() or (_sel_decor >= 0 and _sel_decor_type() != &"floor_overlay"):
		return
	var rots: Array[int] = _rotations()
	if rots.size() < 2:
		return
	var before: Vector2i = _footprint()
	var old_anchor: Vector2i = _cand_cell
	var center: Vector2i = old_anchor + Vector2i((before.x - 1) / 2, (before.y - 1) / 2)
	_rot = rots[1]
	var after: Vector2i = _footprint()
	var keep: Vector2i = _clamp_anchor(center - Vector2i((after.x - 1) / 2, (after.y - 1) / 2))
	var d: Vector2i = before - after
	_cand_cell = keep
	if _check_candidate() != &"":
		for alt: Vector2i in [old_anchor, old_anchor + Vector2i(d.x, 0), old_anchor + Vector2i(0, d.y), old_anchor + d]:
			_cand_cell = _clamp_anchor(alt)
			if _check_candidate() == &"":
				break
			_cand_cell = keep
	EventBus.sfx.emit(&"ui_tap_soft", &"")
	_update_candidate()


## Put Away: barang yang sudah terpasang kembali ke inventaris.
func _put_away() -> void:
	var iid: int = _sel_iid
	var uid: int = _sel_decor
	_drop_hold()
	if iid >= 0:
		var r: StringName = sim.equipment.put_away(iid)
		if r != &"":
			_set_status(r, false)
			_warn_rejected(r)
	elif uid >= 0:
		sim.decoration.put_away(uid)
	_refresh_overlay()
	_refresh_all()


## Back/Escape/klik kanan: kembalikan barang yang dipegang dulu, baru keluar
## dari mode ini.
func on_back() -> bool:
	if has_selection():
		_cancel()
		return true
	close()
	return true


func on_closed() -> void:
	if sim.world.layout_changed.is_connected(_refresh_overlay):
		sim.world.layout_changed.disconnect(_refresh_overlay)
	game.world.release_hold()
	game.world.clear_tile_overlay()
	game.world.camera_rig.set_free_pan(false)
	game.world.clear_ghost()
	game.world.clear_slot_markers()
	game.world.decoration_mode = false
	game.world.view_floor_override = &""
	game.commands.tap_override = Callable()
	game.commands.press_override = Callable()
	game.commands.drag_override = Callable()
	game.commands.drop_override = Callable()
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
