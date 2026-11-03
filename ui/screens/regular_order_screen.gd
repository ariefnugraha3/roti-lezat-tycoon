class_name RegularOrderScreen
extends UIScreen
## Minigame pesanan pelanggan langganan (GDD idle 21.10): "Pack the order".
## Tiket di atas menunjukkan roti yang dipesan; baki di bawah berisi roti itu
## ditambah roti pengecoh, diacak. Ketuk roti yang benar sebelum waktunya habis
## (`regulars.minigame_seconds` + per roti); roti yang salah memotong waktu.
## Sisa waktu menentukan bintang (1-3) dan hadiahnya. Toko di-pause selama
## minigame (popup pemblokir). Menutup popup sebelum selesai tidak menggagalkan
## pesanan: regular tetap menunggu sampai waktu tunggunya habis.

const TILES: int = 8
const COLUMNS: int = 4

## Isi pesanan dan yang sudah masuk kotak.
var order: Array[StringName] = []
var packed: Array[bool] = []
var time_total: float = 0.0
var time_left: float = 0.0
var finished: bool = false
## Hasil setelah selesai: {stars, kr, level_up, level, gift} atau {failed: true}.
var result: Dictionary = {}

var _ticket: HBoxContainer = null
var _bar: GoalsScreen.GoalBar = null
var _time_label: Label = null
var _grid: GridContainer = null
var _body: VBoxContainer = null
var _id: String = ""


func build() -> void:
	var v: Dictionary = sim.regulars.visit
	if v.is_empty():
		close.call_deferred()
		return
	_id = str(v["id"])
	order.clear()
	packed.clear()
	for rid: Variant in v["order"]:
		order.append(StringName(str(rid)))
		packed.append(false)
	time_total = DataRegistry.idlef("regulars.minigame_seconds") + DataRegistry.idlef("regulars.minigame_seconds_per_item") * float(order.size())
	time_left = time_total
	var extra: float = 260.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)
	_body = make_popup(Tx.t(_id), Vector2(640, 800.0 + extra), true)
	_header(_body)
	var tl: Label = lbl(_body, Tx.t("ui_regular_order_title"), 16, Palette.UI_WOOD_DEEP)
	tl.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var tk := PanelContainer.new()
	tk.name = "Ticket"
	var tsb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 18, false)
	tsb.set_content_margin_all(8.0)
	tk.add_theme_stylebox_override("panel", tsb)
	_body.add_child(tk)
	_ticket = HBoxContainer.new()
	_ticket.alignment = BoxContainer.ALIGNMENT_CENTER
	_ticket.add_theme_constant_override("separation", 8)
	tk.add_child(_ticket)
	for i in order.size():
		var slot := PanelContainer.new()
		slot.name = "Want%d" % i
		var ssb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.SHEET, 14, false)
		ssb.set_content_margin_all(4.0)
		slot.add_theme_stylebox_override("panel", ssb)
		_ticket.add_child(slot)
		slot.add_child(BreadArt.for_recipe(order[i], 56.0))
	var th: HBoxContainer = hbox(_body, 10)
	_bar = GoalsScreen.GoalBar.new()
	_bar.name = "TimeBar"
	_bar.custom_minimum_size = Vector2(0, 16)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	th.add_child(_bar)
	_time_label = lbl(th, "", 16, Palette.UI_WOOD_DEEP)
	_time_label.name = "TimeLeft"
	var hint: Label = lbl(_body, Tx.t("ui_regular_hint"), 14, Palette.TEXT_MUTED, true)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var cc := CenterContainer.new()
	_body.add_child(cc)
	_grid = GridContainer.new()
	_grid.name = "Tray"
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	cc.add_child(_grid)
	for rid: StringName in tray(sim, order, sim.regulars.visits):
		_grid.add_child(_tile(rid))
	_tick_time()


## Potret, sapaan, dan hati pertemanan.
func _header(parent: Control) -> void:
	var h: HBoxContainer = hbox(parent, 14)
	var face: Control = portrait(_id, 104.0)
	h.add_child(face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	h.add_child(v)
	var hello: Label = ProceduralUIFactory.label(Tx.t(_id + "_hello"), 16, Palette.TEXT)
	hello.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bubble: PanelContainer = ProceduralUIFactory.speech_bubble(hello)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(bubble)
	v.add_child(hearts(sim.regulars.level_of(_id), 22))


## Baki: setiap roti pesanan sekali (ulangan ikut berulang), ditambah pengecoh
## dari resep lain, diacak dengan seed kunjungan.
static func tray(s: SimulationRoot, want: Array[StringName], visit_no: int) -> Array[StringName]:
	var out: Array[StringName] = want.duplicate()
	var rng := RandomNumberGenerator.new()
	rng.seed = RNGManager._derive(s.rng.master_seed, "regular_tray_%d" % visit_no)
	var others: Array[StringName] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if not want.has(r.id):
			others.append(r.id)
	while out.size() < TILES and not others.is_empty():
		out.append(others.pop_at(rng.randi_range(0, others.size() - 1)))
	for i in range(out.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: StringName = out[i]
		out[i] = out[j]
		out[j] = tmp
	return out


func _tile(rid: StringName) -> Button:
	var b := Button.new()
	b.name = "Tile_" + String(rid)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(134, 118.0 + 60.0 * maxf(0.0, SettingsManager.text_scale() - 1.0))
	ProceduralUIFactory.apply_kind(b, "plain")
	b.set_meta("recipe", rid)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	b.add_child(v)
	var art: BreadArt = BreadArt.for_recipe(rid, 64.0)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var l: Label = ProceduralUIFactory.label(Tx.recipe_name(rid), 12, Palette.UI_WOOD_DEEP)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = 120.0
	v.add_child(l)
	b.pressed.connect(tap_tile.bind(b))
	return b


## Ketuk satu roti di baki (juga dipakai tes).
func tap_tile(b: Button) -> void:
	if finished or b.disabled:
		return
	var rid: StringName = b.get_meta("recipe")
	var i: int = -1
	for k in order.size():
		if not packed[k] and order[k] == rid:
			i = k
			break
	if i < 0:
		time_left = maxf(0.0, time_left - DataRegistry.idlef("regulars.wrong_tap_seconds"))
		EventBus.sfx.emit(&"ui_error", &"")
		if not SettingsManager.reduced_motion():
			var tw: Tween = b.create_tween()
			var x0: float = b.position.x
			for dx: float in [10.0, -10.0, 6.0, 0.0]:
				tw.tween_property(b, "position:x", x0 + dx, 0.05)
		_tick_time()
		return
	packed[i] = true
	b.disabled = true
	b.modulate.a = 0.25
	var slot: Control = _ticket.get_child(i) as Control
	slot.add_child(_check_mark())
	EventBus.sfx.emit(&"bread_place_display", &"")
	if not packed.has(false):
		_finish(true)


static func _check_mark() -> Control:
	var c := CenterContainer.new()
	c.name = "Packed"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ProceduralUIFactory.badge("check", Palette.MATCHA, Palette.FLOUR_WHITE, 32))
	return c


func _process(delta: float) -> void:
	if finished or _bar == null:
		return
	time_left = maxf(0.0, time_left - delta)
	_tick_time()
	if time_left <= 0.0:
		_finish(false)


func _tick_time() -> void:
	if _bar == null:
		return
	_bar.set_progress(time_left / maxf(time_total, 0.001), time_left / maxf(time_total, 0.001) > 0.5)
	_time_label.text = Tx.t("ui_regular_seconds", {"seconds": int(ceil(time_left))})


## Bintang dari sisa waktu: separuh atau lebih = 3, seperempat = 2, selain itu 1.
static func stars_for(left_ratio: float) -> int:
	if left_ratio >= 0.5:
		return 3
	if left_ratio >= 0.25:
		return 2
	return 1


func _finish(ok: bool) -> void:
	finished = true
	if ok:
		var stars: int = stars_for(time_left / maxf(time_total, 0.001))
		result = sim.regulars.complete(stars)
		result["stars"] = stars
		EventBus.sfx.emit(&"coin_shower", &"")
	else:
		sim.regulars.fail()
		result = {"failed": true}
		EventBus.sfx.emit(&"customer_impatient", &"")
	_show_result()


func _show_result() -> void:
	for c: Node in _body.get_children():
		c.queue_free()
	var col := VBoxContainer.new()
	col.name = "Result"
	col.add_theme_constant_override("separation", 12)
	col.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(col)
	var cc := CenterContainer.new()
	col.add_child(cc)
	cc.add_child(portrait(_id, 140.0))
	if bool(result.get("failed", false)):
		var t: Label = lbl(col, Tx.t("ui_regular_failed", {"name": Tx.t(_id)}), 20, Palette.UI_WOOD_DEEP, true)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		var sh := HBoxContainer.new()
		sh.name = "Stars"
		sh.alignment = BoxContainer.ALIGNMENT_CENTER
		col.add_child(sh)
		for k in 3:
			sh.add_child(ProceduralUIFactory.icon("star", 48, Palette.GOLD_STAR if k < int(result["stars"]) else Palette.UI_CREAM_DEEP))
		var thanks: Label = lbl(col, Tx.t("ui_regular_thanks", {"name": Tx.t(_id)}), 20, Palette.UI_WOOD_DEEP, true)
		thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var pay: Label = lbl(col, "+" + Tx.kr(float(result["kr"])), 30, Palette.UI_WOOD_DEEP)
		pay.name = "Pay"
		pay.add_theme_font_override("font", ProceduralUIFactory.display_font())
		pay.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var hc := CenterContainer.new()
		col.add_child(hc)
		hc.add_child(hearts(int(result["level"]), 28))
		if bool(result.get("level_up", false)):
			var card: PanelContainer = UISheet.card(col)
			card.name = "Memory"
			var mv := VBoxContainer.new()
			mv.add_theme_constant_override("separation", 4)
			card.add_child(mv)
			var mt: Label = lbl(mv, Tx.t("ui_regular_memory", {"gift": Tx.kr(float(result["gift"]))}), 17, Palette.STRAWBERRY_DEEP, true)
			mt.add_theme_font_override("font", ProceduralUIFactory.display_font())
			lbl(mv, Tx.t("%s_story_%d" % [_id, int(result["level"])]), 15, Palette.TEXT, true)
		else:
			var need: int = sim.regulars.next_level_orders(_id)
			if need > 0:
				lbl(col, Tx.t("ui_regular_progress", {"done": int(sim.regulars.friend(_id).get("orders", 0)), "need": need}), 15, Palette.TEXT_MUTED, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if game != null and game.hud != null and not SettingsManager.reduced_motion():
			game.hud.coin_shower()
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(spacer)
	var nav := CenterContainer.new()
	col.add_child(nav)
	var b: Button = btn(nav, Tx.t("ui_close"), "primary", close)
	b.name = "Done"
	b.custom_minimum_size = Vector2(240, 60)


## Potret 2D regular `id` (sama dengan sosok 3D-nya, tanpa celemek).
static func portrait(id: String, size_px: float) -> Control:
	var p := ProceduralUIFactory.ChibiPortrait.new()
	p.name = "Portrait"
	p.custom_minimum_size = Vector2(size_px, size_px)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var vis: Dictionary = (RegularManager.def(id).get("visual", {}) as Dictionary).duplicate()
	vis["no_apron"] = true
	p.configure(vis, "customer", 1)
	return p


## Lima hati: yang terisi = level pertemanan.
static func hearts(level: int, size_px: int) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.name = "Hearts"
	h.add_theme_constant_override("separation", 2)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var n: int = (DataRegistry.idle("regulars.levels") as Array).size()
	for k in n:
		var ic: IconCanvas = ProceduralUIFactory.icon("heart", size_px, Palette.STRAWBERRY if k < level else Palette.UI_CREAM_DEEP)
		h.add_child(ic)
	h.set_meta("filled", level)
	return h


func on_back() -> bool:
	close()
	return true
