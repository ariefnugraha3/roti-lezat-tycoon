class_name PhotoModeScreen
extends UIScreen
## Photo mode (GDD idle 21.5): HUD disembunyikan, toko tetap berjalan, kamera
## bebas digeser (seret) dan di-zoom (roda / cubit) tanpa ketukan dunia, filter
## warna polos di atas dunia, bingkai polaroid bernama toko, lalu Capture
## memotret layar tanpa tombol-tombol ini dan menyimpannya / membagikannya
## seperti kartu Share. Dibuka dari menu Pause.

## Filter: [kunci teks, warna lapisan (alfa = kekuatan)]. Lapisan warna polos,
## tanpa shader (v3.1 89.5: tidak ada kombinasi material baru).
const FILTERS: Array = [
	["ui_photo_filter_none", Color(1.0, 1.0, 1.0, 0.0)],
	["ui_photo_filter_warm", Color(1.0, 0.72, 0.38, 0.16)],
	["ui_photo_filter_golden", Color(1.0, 0.58, 0.20, 0.24)],
	["ui_photo_filter_cool", Color(0.55, 0.68, 1.0, 0.16)],
	["ui_photo_filter_vintage", Color(0.62, 0.45, 0.28, 0.26)],
	["ui_photo_filter_night", Color(0.16, 0.18, 0.42, 0.34)],
]

var filter_index: int = 0
var framed: bool = false
var frame_id: StringName = &"polaroid"
var _tint: ColorRect = null
var _frame: Control = null
var _controls: Control = null
var _chips: Array[Button] = []
var _frame_chips: Dictionary = {}
var _frame_btn: Button = null
## Hasil Capture terakhir (toast HUD tersembunyi selama photo mode).
var _status: Label = null


func _init() -> void:
	super._init()
	blocking = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	game.hud.set_decoration_active(true)
	game.commands.tap_override = func(_p: Vector2) -> void: pass
	game.world.camera_rig.set_free_pan(true)
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint = ColorRect.new()
	_tint.name = "Tint"
	_tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tint)
	_frame = PolaroidFrame.new()
	_frame.name = "PolaroidFrame"
	_frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(_frame as PolaroidFrame).caption = sim.bakery_name
	add_child(_frame)
	_build_controls()
	_apply()


func _build_controls() -> void:
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	_controls = MarginContainer.new()
	_controls.name = "Controls"
	_controls.set_anchors_preset(Control.PRESET_FULL_RECT)
	_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_theme_constant_override("margin_left", int(inset.x) + 12)
	_controls.add_theme_constant_override("margin_top", int(inset.y) + 10)
	_controls.add_theme_constant_override("margin_right", int(inset.z) + 12)
	_controls.add_theme_constant_override("margin_bottom", int(inset.w) + 10)
	add_child(_controls)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_controls.add_child(col)
	# Atas: judul kecil dan tombol tutup.
	var top := HBoxContainer.new()
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(top)
	var hint: PanelContainer = ProceduralUIFactory.pill("frame", Tx.t("ui_photo_hint"), Color(Palette.UI_CREAM, 0.95), Palette.UI_WOOD_DEEP, 15)
	hint.name = "Hint"
	hint.size_flags_horizontal = Control.SIZE_EXPAND | Control.SIZE_SHRINK_BEGIN
	hint.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(hint)
	var close_b: Button = ProceduralUIFactory.icon_button("cross", Tx.t("ui_close"), "plain", 24, Palette.UI_WOOD_DEEP)
	close_b.name = "Close"
	close_b.custom_minimum_size = Vector2(56, 56)
	close_b.pressed.connect(close)
	top.add_child(close_b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(spacer)
	# Bawah: panel krem dengan filter, bingkai, dan Capture.
	var panel := PanelContainer.new()
	panel.name = "Bar"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.97), 26, false)
	sb.set_content_margin_all(10.0)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	col.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	panel.add_child(v)
	var flow := HFlowContainer.new()
	flow.name = "Filters"
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	v.add_child(flow)
	for i in FILTERS.size():
		var chip: Button = ProceduralUIFactory.button(Tx.t(str(FILTERS[i][0])), "soft")
		chip.name = "Filter%d" % i
		chip.custom_minimum_size = Vector2(0, 48)
		chip.pressed.connect(_set_filter.bind(i))
		flow.add_child(chip)
		_chips.append(chip)
	var frame_flow := HFlowContainer.new()
	frame_flow.name = "Frames"
	frame_flow.alignment = FlowContainer.ALIGNMENT_CENTER
	frame_flow.add_theme_constant_override("h_separation", 8)
	frame_flow.add_theme_constant_override("v_separation", 8)
	v.add_child(frame_flow)
	_frame_chips.clear()
	for fd: Variant in PremiumManager.photo_frame_defs():
		if not fd is Dictionary:
			continue
		var fid: StringName = StringName(str((fd as Dictionary).get("id", "")))
		var chip2: Button = ProceduralUIFactory.button("", "soft")
		chip2.name = "Frame_" + String(fid)
		chip2.custom_minimum_size = Vector2(0, 44)
		chip2.pressed.connect(_on_frame_chip.bind(fid))
		frame_flow.add_child(chip2)
		_frame_chips[fid] = chip2
	_status = lbl(v, "", 14, Palette.TEXT_MUTED, true)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.visible = false
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	_frame_btn = ProceduralUIFactory.icon_text_button("frame", Tx.t("ui_photo_frame"), "soft", 22, 17)
	_frame_btn.name = "FrameToggle"
	_frame_btn.custom_minimum_size = Vector2(150.0 * SettingsManager.text_scale(), 60)
	_frame_btn.pressed.connect(_toggle_frame)
	row.add_child(_frame_btn)
	var shoot: Button = ProceduralUIFactory.icon_text_button("camera", Tx.t("ui_photo_capture"), "primary", 24, 20)
	shoot.name = "Capture"
	shoot.custom_minimum_size = Vector2(220, 60)
	shoot.pressed.connect(capture)
	row.add_child(shoot)


func _set_filter(i: int) -> void:
	filter_index = clampi(i, 0, FILTERS.size() - 1)
	_apply()


func _toggle_frame() -> void:
	if not framed and not sim.premium.owns_photo_frame(frame_id):
		frame_id = &"polaroid"
	framed = not framed
	_apply()


func _on_frame_chip(fid: StringName) -> void:
	if sim.premium.owns_photo_frame(fid):
		frame_id = fid
		framed = true
		_apply()
		return
	var def: Dictionary = PremiumManager.photo_frame_def(fid)
	var cost: int = int(def.get("price_crumbs", 0))
	var fname: String = Tx.t("ui_photo_frame_" + String(fid))
	if not sim.premium.can_spend(cost):
		_status.text = Tx.t("ui_photo_frame_need_crumbs", {"name": fname, "cost": cost})
		_status.visible = true
		EventBus.sfx.emit(&"ui_cancel", &"")
		return
	game.modals.open(&"confirm", {
		"text": Tx.t("ui_photo_frame_buy_confirm", {"name": fname, "cost": cost}),
		"on_yes": func() -> void:
			if sim.premium.buy_photo_frame(fid):
				frame_id = fid
				framed = true
				_status.text = Tx.t("ui_photo_frame_bought", {"name": fname})
				_status.visible = true
				_apply()
	})


func _apply() -> void:
	_tint.color = FILTERS[filter_index][1]
	_tint.visible = filter_index > 0
	var pf: PolaroidFrame = _frame as PolaroidFrame
	if pf.style != frame_id:
		pf.style = frame_id
		pf.queue_redraw()
	_frame.visible = framed
	for i in _chips.size():
		ProceduralUIFactory.apply_kind(_chips[i], "primary" if i == filter_index else "soft")
	for fid: StringName in _frame_chips.keys():
		var b: Button = _frame_chips[fid]
		var owned: bool = sim.premium.owns_photo_frame(fid)
		var label_text: String = Tx.t("ui_photo_frame_" + String(fid))
		if not owned:
			var cost: int = int(PremiumManager.photo_frame_def(fid).get("price_crumbs", 0))
			b.text = Tx.t("ui_photo_frame_locked", {"name": label_text, "cost": cost})
			ProceduralUIFactory.apply_kind(b, "disabled")
		else:
			b.text = label_text
			ProceduralUIFactory.apply_kind(b, "primary" if (framed and frame_id == fid) else "soft")
	ProceduralUIFactory.apply_kind(_frame_btn, "primary" if framed else "soft")


## Potret layar dengan filter dan bingkai, tanpa tombol photo mode; lalu simpan
## atau bagikan seperti kartu Share. Mengembalikan gambarnya.
func capture() -> Image:
	_controls.visible = false
	await ShareCard.after_draw(self)
	await ShareCard.after_draw(self)
	var img: Image = ShareCard.grab(get_viewport())
	if not is_instance_valid(_controls):
		return img
	_controls.visible = true
	_flash()
	var r: Dictionary = ShareCard.export_png(img, ShareCard.file_base(sim, "photo"))
	match str(r.get("kind", "")):
		"share":
			_status.text = Tx.t("ui_photo_shared")
		"download":
			_status.text = Tx.t("ui_share_downloaded")
		"saved":
			_status.text = Tx.t("ui_photo_saved", {"path": str(r["path"])})
		_:
			_status.text = Tx.t("ui_share_failed")
	_status.visible = true
	EventBus.sfx.emit(&"ui_confirm", &"")
	return img


## Kilat putih singkat (dilewati dengan Reduced Motion).
func _flash() -> void:
	if SettingsManager.reduced_motion():
		return
	var f := ColorRect.new()
	f.color = Color(1.0, 1.0, 1.0, 0.8)
	f.set_anchors_preset(Control.PRESET_FULL_RECT)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(f)
	var tw: Tween = create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.35)
	tw.tween_callback(f.queue_free)


func on_closed() -> void:
	if game == null:
		return
	game.commands.tap_override = Callable()
	if game.world != null:
		game.world.camera_rig.set_free_pan(false)
	if game.hud != null:
		game.hud.set_decoration_active(false)


## Bingkai prosedural flat di atas potret Mode Foto: Polaroid, Kayu, Taplak
## Gingham, Kartu Pos/Prangko, Bingkai Emas, dan Lampu Kafe.
class PolaroidFrame:
	extends Control
	var caption: String = ""
	var style: StringName = &"polaroid"

	func _draw() -> void:
		var side: float = size.x * 0.055
		var bottom: float = size.y * 0.14
		match style:
			&"wood":
				_draw_wood(side, bottom)
			&"gingham":
				_draw_gingham(side, bottom)
			&"stamp":
				_draw_stamp(side, bottom)
			&"golden":
				_draw_golden(side, bottom)
			&"lights":
				_draw_lights(side, bottom)
			_:
				_draw_border(size.x * 0.05, bottom, Palette.FLOUR_WHITE)
				_draw_caption(size.x * 0.05, bottom, Palette.UI_WOOD_DEEP)

	func _draw_border(side: float, bottom: float, color: Color) -> void:
		draw_rect(Rect2(0.0, 0.0, size.x, side), color)
		draw_rect(Rect2(0.0, 0.0, side, size.y), color)
		draw_rect(Rect2(size.x - side, 0.0, side, size.y), color)
		draw_rect(Rect2(0.0, size.y - bottom, size.x, bottom), color)

	func _inner_rect(side: float, bottom: float) -> Rect2:
		return Rect2(side, side, maxf(1.0, size.x - side * 2.0), maxf(1.0, size.y - side - bottom))

	func _draw_caption(side: float, bottom: float, ink: Color, has_plaque: bool = false,
			plaque_fill: Color = Palette.UI_CREAM, plaque_edge: Color = Palette.UI_WOOD_DEEP) -> void:
		var font: Font = ProceduralUIFactory.display_font()
		var fs: int = int(round(size.x * 0.056))
		var w: float = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		while fs > 12 and w > size.x - side * 5.0:
			fs -= 2
			w = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var baseline_y: float = size.y - bottom * 0.40
		if has_plaque:
			var pad_x: float = 22.0
			var box_h: float = float(fs) + 18.0
			var pr := Rect2((size.x - w) * 0.5 - pad_x, size.y - bottom * 0.5 - box_h * 0.5, w + pad_x * 2.0, box_h)
			draw_rect(pr, plaque_fill)
			draw_rect(pr, plaque_edge, false, 3.0)
			baseline_y = pr.position.y + box_h * 0.5 + float(fs) * 0.34
		draw_string(font, Vector2((size.x - w) * 0.5, baseline_y), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, ink)

	func _draw_wood(side: float, bottom: float) -> void:
		_draw_border(side, bottom, Palette.UI_WOOD)
		var inner: Rect2 = _inner_rect(side, bottom)
		draw_rect(inner, Palette.PINE_WOOD, false, 4.0)
		draw_rect(inner.grow(6.0), Palette.UI_WOOD_DEEP, false, 2.0)
		var r: float = maxf(3.0, side * 0.14)
		for p: Vector2 in [
			Vector2(side * 0.5, side * 0.5),
			Vector2(size.x - side * 0.5, side * 0.5),
			Vector2(side * 0.5, size.y - bottom * 0.5),
			Vector2(size.x - side * 0.5, size.y - bottom * 0.5),
		]:
			draw_circle(p, r, Palette.DARK_CHOCOLATE)
		_draw_caption(side, bottom, Palette.UI_WOOD_DEEP, true, Palette.UI_CREAM, Palette.UI_WOOD_DEEP)

	func _draw_gingham(side: float, bottom: float) -> void:
		_draw_border(side, bottom, Palette.UI_CREAM)
		var cell: float = maxf(18.0, size.x * 0.036)
		var stripe: Color = Color(Palette.GINGHAM_A, 0.55)
		var dark_sq: Color = Color(Palette.STRAWBERRY, 0.35)
		var inner: Rect2 = _inner_rect(side, bottom)
		var borders: Array[Rect2] = [
			Rect2(0.0, 0.0, size.x, side),
			Rect2(0.0, side, side, maxf(0.0, size.y - side - bottom)),
			Rect2(size.x - side, side, side, maxf(0.0, size.y - side - bottom)),
			Rect2(0.0, size.y - bottom, size.x, bottom),
		]
		var cols: int = int(ceil(size.x / cell))
		var rows: int = int(ceil(size.y / cell))
		for gy in rows:
			for gx in cols:
				var col: Color
				if (gx % 2 == 1) and (gy % 2 == 1):
					col = dark_sq
				elif (gx % 2 == 1) or (gy % 2 == 1):
					col = stripe
				else:
					continue
				var sq := Rect2(float(gx) * cell, float(gy) * cell, cell, cell)
				for br: Rect2 in borders:
					var clipped: Rect2 = sq.intersection(br)
					if clipped.has_area():
						draw_rect(clipped, col)
		draw_rect(inner, Palette.FLOUR_WHITE, false, 4.0)
		var dot_r: float = maxf(4.0, side * 0.14)
		var step: float = dot_r * 2.2
		var x: float = inner.position.x
		while x <= inner.end.x:
			draw_circle(Vector2(x, inner.position.y), dot_r, Palette.FLOUR_WHITE)
			draw_circle(Vector2(x, inner.end.y), dot_r, Palette.FLOUR_WHITE)
			x += step
		var y: float = inner.position.y
		while y <= inner.end.y:
			draw_circle(Vector2(inner.position.x, y), dot_r, Palette.FLOUR_WHITE)
			draw_circle(Vector2(inner.end.x, y), dot_r, Palette.FLOUR_WHITE)
			y += step
		_draw_caption(side, bottom, Palette.STRAWBERRY_DEEP, true, Palette.FLOUR_WHITE, Palette.STRAWBERRY)

	func _draw_stamp(side: float, bottom: float) -> void:
		_draw_border(side, bottom, Palette.PARCHMENT)
		var inner: Rect2 = _inner_rect(side, bottom)
		draw_rect(inner, Palette.CARAMEL, false, 2.5)
		var notch: float = maxf(6.0, side * 0.20)
		var step: float = notch * 2.5
		var x: float = notch * 1.5
		while x < size.x - notch:
			draw_circle(Vector2(x, 0.0), notch, Palette.UI_CREAM_DEEP)
			draw_circle(Vector2(x, size.y), notch, Palette.UI_CREAM_DEEP)
			x += step
		var y: float = notch * 1.5
		while y < size.y - notch:
			draw_circle(Vector2(0.0, y), notch, Palette.UI_CREAM_DEEP)
			draw_circle(Vector2(size.x, y), notch, Palette.UI_CREAM_DEEP)
			y += step
		var stamp_c := Vector2(size.x - side - bottom * 0.35, size.y - bottom * 0.5)
		draw_arc(stamp_c, bottom * 0.24, 0.0, TAU, 24, Color(Palette.CARAMEL, 0.40), 2.5)
		draw_arc(stamp_c, bottom * 0.16, 0.0, TAU, 20, Color(Palette.CARAMEL, 0.40), 1.5)
		_draw_caption(side, bottom, Palette.TEXT)

	func _draw_golden(side: float, bottom: float) -> void:
		_draw_border(side, bottom, Palette.HONEY)
		var inner: Rect2 = _inner_rect(side, bottom)
		draw_rect(inner, Palette.BUTTER_YELLOW, false, 4.0)
		draw_rect(inner.grow(7.0), Palette.GOLD_STAR, false, 2.5)
		draw_rect(Rect2(3.0, 3.0, size.x - 6.0, size.y - 6.0), Palette.BUTTER_YELLOW, false, 3.0)
		var cr: float = maxf(5.0, side * 0.20)
		for corner: Vector2 in [
			Vector2(side * 0.5, side * 0.5),
			Vector2(size.x - side * 0.5, side * 0.5),
			Vector2(side * 0.5, size.y - bottom * 0.5),
			Vector2(size.x - side * 0.5, size.y - bottom * 0.5),
		]:
			var diamond := PackedVector2Array([
				corner + Vector2(0, -cr), corner + Vector2(cr, 0),
				corner + Vector2(0, cr), corner + Vector2(-cr, 0),
			])
			draw_colored_polygon(diamond, Palette.FLOUR_WHITE)
		_draw_caption(side, bottom, Palette.UI_WOOD_DEEP, true, Palette.FLOUR_WHITE, Palette.GOLD_STAR)

	func _draw_lights(side: float, bottom: float) -> void:
		_draw_border(side, bottom, Palette.CHALKBOARD)
		var inner: Rect2 = _inner_rect(side, bottom)
		draw_rect(inner, Palette.BRASS, false, 2.5)
		var left_x: float = side * 0.5
		var right_x: float = size.x - side * 0.5
		var top_y: float = side * 0.5
		var bot_y: float = size.y - side * 0.5
		var h_span: float = maxf(1.0, right_x - left_x)
		var v_span: float = maxf(1.0, bot_y - top_y)
		var target_gap: float = maxf(36.0, size.x * 0.075)
		var nx: int = maxi(4, int(round(h_span / target_gap)))
		var ny: int = maxi(6, int(round(v_span / target_gap)))
		# Susun searah jarum jam dari 4 sudut agar simetris penuh dan warna selang-seling
		# tidak pernah bentrok di sudut mana pun (total titik 2*(nx+ny) selalu genap).
		var pts: Array[Vector2] = []
		for i in nx:
			pts.append(Vector2(lerpf(left_x, right_x, float(i) / float(nx)), top_y))
		for j in ny:
			pts.append(Vector2(right_x, lerpf(top_y, bot_y, float(j) / float(ny))))
		for i in nx:
			pts.append(Vector2(lerpf(right_x, left_x, float(i) / float(nx)), bot_y))
		for j in ny:
			pts.append(Vector2(left_x, lerpf(bot_y, top_y, float(j) / float(ny))))
		var bulb_r: float = maxf(4.5, side * 0.16)
		for idx in pts.size():
			var pt: Vector2 = pts[idx]
			var bulb_col: Color = Palette.BUTTER_YELLOW if idx % 2 == 0 else Palette.WARMER_LAMP
			draw_circle(pt, bulb_r * 1.9, Color(bulb_col, 0.24))
			draw_circle(pt, bulb_r, bulb_col)
		# Nama toko berada di antara garis dalam bawah dan deretan lampu paling bawah.
		var cap_bottom: float = bottom + side * 0.35
		_draw_caption(side, cap_bottom, Palette.BUTTER_YELLOW)
