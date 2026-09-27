class_name DecorationScreen
extends UIScreen
## Decoration Mode (GDD 7, 17.3-17.4, 56.1, 60.1, 72, 72.1). Membukanya
## mem-pause simulasi; ketukan dunia diteruskan ke sini. Ketuk perabot untuk
## mengangkatnya, lalu ketuk ubin tujuan: petak jejak lantai disorot putih bila
## sah atau merah bersilang beserta alasannya. Perabot IN_USE tidak dapat
## dipindah. Decor Shop hanya aktif after-hours.

const REASON_KEYS: Dictionary = {
	&"zone": "ui_decor_invalid_zone", &"overlap": "ui_decor_invalid_overlap", &"path": "ui_decor_invalid_path",
	&"access": "ui_decor_invalid_access", &"bounds": "ui_decor_invalid_bounds", &"reserved": "ui_decor_invalid_reserved",
	&"in_use": "ui_feedback_in_use", &"slots_full": "ui_equipment_slots_full", &"limit": "ui_decor_limit",
	&"invalid": "ui_decor_invalid_reserved",
}

const PANEL_WIDTH: float = 360.0

var _sel_iid: int = -1
var _sel_decor: int = -1
var _rot: int = 0
var _last_cell: Vector2i = Vector2i(-1, -1)
var _status: Label = null
var _panel_body: VBoxContainer = null
var _tab: int = 0


func _init() -> void:
	super._init()
	world_input = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	game.hud.set_decoration_active(true)
	game.commands.tap_override = _on_world_tap
	# Pan bebas; geseran awal memakai lebar panel sesungguhnya setelah layout.
	game.world.camera_rig.set_free_pan(true, PANEL_WIDTH)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Color(Palette.PANEL, 0.95), 20, true))
	pc.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	pc.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	pc.offset_right = PANEL_WIDTH
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(pc)
	pc.resized.connect(func() -> void:
		if is_instance_valid(game) and game.world != null and game.world.camera_rig.free_pan:
			game.world.camera_rig.set_free_pan(true, pc.size.x), CONNECT_ONE_SHOT)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	v.add_child(ProceduralUIFactory.title(Tx.t("ui_decoration"), 24))
	_status = lbl(v, Tx.t("ui_decor_hint"), 15, Palette.TEXT, true)
	var tabs: HBoxContainer = hbox(v, 6)
	for i in 3:
		var idx: int = i
		var b: Button = btn(tabs, Tx.t(["ui_market_tab_equipment", "ui_decor_owned", "ui_decor_shop"][i]), "secondary", func() -> void:
			_tab = idx
			_render_panel())
		b.custom_minimum_size = Vector2(100, 48)
	_panel_body = scroll_box(v)
	var bar: HBoxContainer = hbox(v, 8)
	btn(bar, Tx.t("ui_decor_rotate"), "secondary", _rotate)
	btn(bar, Tx.t("ui_decor_store"), "secondary", _put_away)
	var done: Button = btn(v, Tx.t("ui_decor_done"), "primary", close)
	done.custom_minimum_size = Vector2(300, 56)
	if sim.world.location.is_multi_floor():
		var fb: HBoxContainer = hbox(v, 8)
		for f: FloorDefinition in sim.world.location.floors:
			var fid: StringName = f.id
			btn(fb, Tx.t("ui_floor_label", {"n": String(f.id).replace("floor_", "")}), "secondary", func() -> void:
				game.world.view_floor_override = fid)
	var pre: int = int(params.get("select_iid", -1))
	if pre >= 0:
		_select_equipment(pre)
	_render_panel()


func _render_panel() -> void:
	clear(_panel_body)
	match _tab:
		0:
			for e: EquipmentInstance in sim.equipment.all_sorted():
				if e.category() == &"storage" and e.placed:
					continue
				var t: String = "%s%s" % [Tx.item_name(e.def_id), "" if e.placed else " · " + Tx.t("ui_decor_unplaced")]
				var b: Button = btn(_panel_body, t, "primary" if e.iid == _sel_iid else "secondary", _select_equipment.bind(e.iid))
				b.custom_minimum_size = Vector2(320, 48)
		1:
			for o: Dictionary in sim.decoration.owned:
				var def: MiscDefinitions.DecorationDefinition = sim.decoration.def_of(o)
				var label: String = "%s · %s" % [Tx.t(String(def.localization_key)), Tx.t("decor_type_" + String(def.placement_type))]
				if def.is_placeable():
					var b2: Button = btn(_panel_body, label, "primary" if int(o["uid"]) == _sel_decor else "secondary", _select_decor.bind(int(o["uid"])))
					b2.custom_minimum_size = Vector2(320, 48)
				else:
					var eq: bool = sim.decoration.equipped.values().has(String(def.id))
					var b3: Button = btn(_panel_body, "%s%s" % [label, " ✓" if eq else ""], "secondary", _equip.bind(def.id))
					b3.custom_minimum_size = Vector2(320, 48)
		_:
			if not sim.time.is_after_hours():
				lbl(_panel_body, Tx.t("ui_available_after_closing"), 15, Palette.DANGER)
			for x: Variant in DataRegistry.decorations():
				var d: MiscDefinitions.DecorationDefinition = x
				if d.source != &"shop":
					continue
				var b4: Button = btn(_panel_body, "%s · %s" % [Tx.t(String(d.localization_key)), Tx.t("ui_decor_buy", {"price": Tx.kr(d.price_kr)})], "secondary", _buy.bind(d.id))
				b4.custom_minimum_size = Vector2(320, 48)
				b4.disabled = sim.decoration.can_buy(d.id) != &""


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
	game.world.view_floor_override = e.floor_id if e.placed else sim.world.floors_for_category(e.category())[0]
	_status.text = Tx.item_name(e.def_id)
	if e.placed:
		_preview(e.anchor)


func _select_decor(uid: int) -> void:
	_sel_decor = uid
	_sel_iid = -1
	var o: Dictionary = sim.decoration.item(uid)
	var def: MiscDefinitions.DecorationDefinition = sim.decoration.def_of(o)
	_status.text = Tx.t(String(def.localization_key))
	if def.placement_type == &"wall" or def.placement_type == &"counter_prop":
		# Slot dinding/meja: taruh di slot bebas berikutnya.
		var floor_id: StringName = game.world.camera_rig.active_floor
		for slot in 64:
			if sim.decoration.place(uid, floor_id, Vector2i.ZERO, slot) != &"overlap":
				break
		_set_status(&"", true)
		game.world.rebuild_all()


func _equip(deco_id: StringName) -> void:
	sim.decoration.equip(deco_id)
	game.world.rebuild_all()
	_render_panel()


func _buy(deco_id: StringName) -> void:
	var r: StringName = sim.decoration.buy(deco_id)
	if r != &"":
		EventBus.notify.emit(1, "ui_feedback_not_enough_kr" if r == &"kr" else "ui_available_after_closing", {}, &"coin")
	game.world.rebuild_all()
	_tab = 1
	_render_panel()


func _anchor_for(cell: Vector2i) -> Vector2i:
	if _sel_iid < 0:
		return cell
	var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
	var fp: Vector2i = GridMath.rotated_footprint(e.def().footprint_tiles, _rot)
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
		var reason2: StringName = sim.world.validate_decor_cell(floor_id, anchor, _sel_decor)
		game.world.show_ghost([anchor], floor_id, reason2 == &"")
		_set_status(reason2, reason2 == &"")


func _set_status(reason: StringName, ok: bool) -> void:
	if ok:
		_status.text = Tx.t("ui_decor_valid")
		_status.add_theme_color_override("font_color", Palette.SUCCESS)
	else:
		_status.text = Tx.t(str(REASON_KEYS.get(reason, "ui_decor_invalid_reserved")))
		_status.add_theme_color_override("font_color", Palette.DANGER)


func _on_world_tap(pos: Vector2) -> void:
	var cell: Vector2i = game.world.cell_at_screen(pos)
	var floor_id: StringName = game.world.camera_rig.active_floor
	if _sel_iid < 0 and _sel_decor < 0:
		var p: Dictionary = game.world.pick(pos)
		if p.get("kind", &"") == &"equipment":
			_select_equipment(int(p["iid"]))
			_render_panel()
		return
	if _sel_iid >= 0:
		var anchor: Vector2i = _anchor_for(cell)
		var e: EquipmentInstance = sim.equipment.get_inst(_sel_iid)
		var reason: StringName = sim.equipment.place(_sel_iid, floor_id, anchor, _rot)
		if reason == &"":
			EventBus.sfx.emit(&"bread_place_display", floor_id)
			game.world.clear_ghost()
			_status.text = Tx.t("ui_decor_valid")
			_sel_iid = -1
			_render_panel()
		else:
			game.world.show_ghost(GridMath.footprint_cells(anchor, e.def().footprint_tiles, _rot), floor_id, false)
			_set_status(reason, false)
			EventBus.sfx.emit(&"ui_error", &"")
	elif _sel_decor >= 0:
		var r2: StringName = sim.decoration.place(_sel_decor, floor_id, cell, -1)
		if r2 == &"":
			game.world.clear_ghost()
			_sel_decor = -1
			game.world.rebuild_all()
		else:
			_set_status(r2, false)


func _input(event: InputEvent) -> void:
	# Pratinjau hover (mouse); pada layar sentuh pratinjau muncul saat tap.
	if event is InputEventMouseMotion and (_sel_iid >= 0 or _sel_decor >= 0):
		var cell: Vector2i = game.world.cell_at_screen((event as InputEventMouseMotion).position)
		var anchor: Vector2i = _anchor_for(cell)
		if anchor != _last_cell:
			_preview(anchor)


func _rotate() -> void:
	if _sel_iid < 0:
		return
	_rot = (_rot + 1) % 4
	if _last_cell.x >= 0:
		_preview(_last_cell)


func _put_away() -> void:
	if _sel_iid >= 0:
		var r: StringName = sim.equipment.put_away(_sel_iid)
		if r != &"":
			_set_status(r, false)
			return
		_sel_iid = -1
	elif _sel_decor >= 0:
		sim.decoration.put_away(_sel_decor)
		_sel_decor = -1
		game.world.rebuild_all()
	game.world.clear_ghost()
	_render_panel()


func on_closed() -> void:
	game.world.camera_rig.set_free_pan(false)
	game.world.clear_ghost()
	game.world.view_floor_override = &""
	game.commands.tap_override = Callable()
	game.hud.set_decoration_active(false)
