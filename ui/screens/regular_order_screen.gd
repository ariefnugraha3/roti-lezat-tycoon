class_name RegularOrderScreen
extends UIScreen
## Minigame pesanan pelanggan langganan (GDD idle 21.10, Seksi 20 no. 110). Tiga
## permainan, dipilih acak per kunjungan oleh RegularManager.game_for:
## - "pack" (Kemas Pesanan): tiket di atas menunjukkan roti yang dipesan; baki
##   berisi roti itu ditambah pengecoh, diacak. Ketuk roti yang benar; roti yang
##   salah memotong waktu.
## - "bake" (Panggang Pas): setiap roti pesanan makin matang di oven, dari pucat
##   ke keemasan lalu gosong. Ketuk Angkat saat jarumnya di zona emas; terlalu
##   cepat atau terlalu lama memotong waktu dan roti diulang. Roti berikutnya
##   matang sedikit lebih cepat dan zonanya sedikit lebih sempit.
## - "memory" (Ingat Pesanan): pesanan tampil beberapa detik (waktu belum
##   berjalan), lalu ditutup. Ketuk roti di baki sesuai urutan; salah memotong
##   waktu dan mengintip roti yang seharusnya sebentar.
## Sisa waktu menentukan bintang (1-3) dan hadiahnya, sama untuk ketiganya. Toko
## di-pause selama minigame (popup pemblokir). Menutup popup sebelum selesai
## tidak menggagalkan pesanan: regular tetap menunggu sampai waktu tunggunya habis.

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
## Minigame kunjungan ini: "pack", "bake", atau "memory".
var minigame: String = "pack"
## Panggang Pas: roti yang sedang dipanggang dan kematangannya (0 mentah .. 1 gosong).
var bake_index: int = 0
var doneness: float = 0.0
## Ingat Pesanan: masih masa menghafal, sisa detiknya, dan roti urutan berikutnya.
var memory_showing: bool = false
var memory_left: float = 0.0
var memory_next: int = 0

var _ticket: HBoxContainer = null
var _bar: GoalsScreen.GoalBar = null
var _time_label: Label = null
var _grid: GridContainer = null
var _body: VBoxContainer = null
var _id: String = ""
var _gauge: BakeGauge = null
var _feedback: Label = null
var _take: Button = null
var _count: Label = null
var _peek_left: float = 0.0


func build() -> void:
	var v: Dictionary = sim.regulars.visit
	if v.is_empty():
		close.call_deferred()
		return
	_id = str(v["id"])
	minigame = str(v.get("game", "pack"))
	if not RegularManager.GAMES.has(minigame):
		minigame = "pack"
	order.clear()
	packed.clear()
	for rid: Variant in v["order"]:
		order.append(StringName(str(rid)))
		packed.append(false)
	match minigame:
		"bake":
			time_total = DataRegistry.idlef("regulars.bake_seconds") + DataRegistry.idlef("regulars.bake_seconds_per_item") * float(order.size())
		"memory":
			time_total = DataRegistry.idlef("regulars.memory_seconds") + DataRegistry.idlef("regulars.memory_seconds_per_item") * float(order.size())
		_:
			time_total = DataRegistry.idlef("regulars.minigame_seconds") + DataRegistry.idlef("regulars.minigame_seconds_per_item") * float(order.size())
	time_left = time_total
	var extra: float = 260.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)
	_body = make_popup(Tx.t(_id), Vector2(640, 800.0 + extra), true)
	_header(_body)
	var tl: Label = lbl(_body, "%s · %s" % [Tx.t("ui_regular_game_" + minigame), Tx.t("ui_regular_order_title")], 16, Palette.UI_WOOD_DEEP)
	tl.name = "GameName"
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
	var hint_key: String = "ui_regular_hint" if minigame == "pack" else "ui_regular_hint_" + minigame
	var hint: Label = lbl(_body, Tx.t(hint_key), 14, Palette.TEXT_MUTED, true)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	match minigame:
		"bake":
			_build_bake()
		"memory":
			_build_tray()
			_begin_memory()
		_:
			_build_tray()
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


# ===========================================================================
# KEMAS PESANAN & INGAT PESANAN: baki roti
# ===========================================================================

func _build_tray() -> void:
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


## Ketuk satu roti di baki (juga dipakai tes): "pack" menerima roti pesanan
## mana pun, "memory" hanya roti urutan berikutnya.
func tap_tile(b: Button) -> void:
	if finished or b.disabled or memory_showing:
		return
	var rid: StringName = b.get_meta("recipe")
	var i: int = -1
	if minigame == "memory":
		if memory_next < order.size() and order[memory_next] == rid:
			i = memory_next
	else:
		for k in order.size():
			if not packed[k] and order[k] == rid:
				i = k
				break
	if i < 0:
		_wrong(b)
		if minigame == "memory":
			_peek(memory_next)
		return
	packed[i] = true
	b.disabled = true
	b.modulate.a = 0.25
	var slot: Control = _ticket.get_child(i) as Control
	if minigame == "memory":
		_uncover(i)
		memory_next += 1
	slot.add_child(_check_mark())
	EventBus.sfx.emit(&"bread_place_display", &"")
	if not packed.has(false):
		_finish(true)


## Salah: waktu dipotong, bunyi galat, dan yang diketuk bergetar.
func _wrong(shake: Control) -> void:
	time_left = maxf(0.0, time_left - DataRegistry.idlef("regulars.wrong_tap_seconds"))
	EventBus.sfx.emit(&"ui_error", &"")
	if shake != null and not SettingsManager.reduced_motion():
		var tw: Tween = shake.create_tween()
		var x0: float = shake.position.x
		for dx: float in [10.0, -10.0, 6.0, 0.0]:
			tw.tween_property(shake, "position:x", x0 + dx, 0.05)
	_tick_time()


static func _check_mark() -> Control:
	var c := CenterContainer.new()
	c.name = "Packed"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.add_child(ProceduralUIFactory.badge("check", Palette.MATCHA, Palette.FLOUR_WHITE, 32))
	return c


# ===========================================================================
# INGAT PESANAN
# ===========================================================================

## Masa menghafal: tiket terbuka, baki redup, waktu belum berjalan.
func _begin_memory() -> void:
	memory_showing = true
	memory_next = 0
	memory_left = DataRegistry.idlef("regulars.memory_show_seconds") + DataRegistry.idlef("regulars.memory_show_seconds_per_item") * float(order.size())
	_grid.modulate.a = 0.35
	_feedback = lbl(_body, "", 18, Palette.STRAWBERRY_DEEP)
	_feedback.name = "MemoryCue"
	_feedback.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.move_child(_feedback, _grid.get_parent().get_index())
	_memory_cue()


func _memory_cue() -> void:
	if _feedback == null:
		return
	_feedback.text = Tx.t("ui_regular_memory_watch", {"seconds": int(ceil(memory_left))}) if memory_showing else Tx.t("ui_regular_memory_go")


## Masa menghafal selesai (juga dipakai tes): tiket ditutup, baki aktif, waktu mulai.
func end_memory_show() -> void:
	if not memory_showing:
		return
	memory_showing = false
	_grid.modulate.a = 1.0
	for i in order.size():
		_cover(i)
	_memory_cue()


func _cover(i: int) -> void:
	var slot: Control = _ticket.get_child(i) as Control
	if slot == null or packed[i] or slot.get_node_or_null("Cover") != null:
		return
	var cover := PanelContainer.new()
	cover.name = "Cover"
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var csb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARAMEL, 12, false)
	cover.add_theme_stylebox_override("panel", csb)
	var q: Label = ProceduralUIFactory.label("?", 30, Palette.FLOUR_WHITE)
	q.add_theme_font_override("font", ProceduralUIFactory.display_font())
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	q.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cover.add_child(q)
	slot.add_child(cover)


func _uncover(i: int) -> void:
	var slot: Control = _ticket.get_child(i) as Control
	var cover: Node = slot.get_node_or_null("Cover") if slot != null else null
	if cover != null:
		slot.remove_child(cover)
		cover.queue_free()


## Salah pilih: roti yang seharusnya diintip sebentar.
func _peek(i: int) -> void:
	if i >= order.size():
		return
	_uncover(i)
	_peek_left = DataRegistry.idlef("regulars.memory_peek_seconds")
	set_meta("peek", i)


# ===========================================================================
# PANGGANG PAS
# ===========================================================================

func _build_bake() -> void:
	_count = lbl(_body, "", 16, Palette.UI_WOOD_DEEP)
	_count.name = "BakeCount"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var cc := CenterContainer.new()
	_body.add_child(cc)
	_gauge = BakeGauge.new()
	_gauge.name = "Oven"
	_gauge.custom_minimum_size = Vector2(520, 230)
	cc.add_child(_gauge)
	_feedback = lbl(_body, "", 20, Palette.UI_WOOD_DEEP)
	_feedback.name = "BakeFeedback"
	_feedback.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var nav := CenterContainer.new()
	_body.add_child(nav)
	_take = btn(nav, Tx.t("ui_regular_bake_take"), "primary", take_out)
	_take.name = "TakeOut"
	_take.custom_minimum_size = Vector2(300, 72)
	_next_bread()


## Zona emas roti ke-`i` (0..1): sedikit menyempit tiap roti, tetap berpusat.
func bake_zone(i: int) -> Vector2:
	var z: Array = DataRegistry.idle("regulars.bake_zone")
	var shrink: float = DataRegistry.idlef("regulars.bake_zone_shrink") * float(i)
	var lo: float = float(z[0]) + shrink * 0.5
	var hi: float = float(z[1]) - shrink * 0.5
	if hi - lo < 0.08:
		var mid: float = (float(z[0]) + float(z[1])) * 0.5
		return Vector2(mid - 0.04, mid + 0.04)
	return Vector2(lo, hi)


## Detik dari mentah sampai gosong untuk roti ke-`i` (makin cepat tiap roti).
func brown_seconds(i: int) -> float:
	return DataRegistry.idlef("regulars.bake_brown_seconds") / (1.0 + DataRegistry.idlef("regulars.bake_speedup") * float(i))


func _next_bread() -> void:
	doneness = 0.0
	if _gauge != null:
		_gauge.zone = bake_zone(bake_index)
		_gauge.level = 0.0
		_gauge.queue_redraw()
	if _count != null:
		var i: int = mini(bake_index, order.size() - 1)
		_count.text = Tx.t("ui_regular_bake_count", {"n": i + 1, "total": order.size(), "name": Tx.recipe_name(order[i])})


## Ketuk Angkat (juga dipakai tes): di zona emas = roti jadi; selain itu waktu
## dipotong dan roti itu diulang dari adonan.
func take_out() -> void:
	if finished or minigame != "bake" or bake_index >= order.size():
		return
	var z: Vector2 = bake_zone(bake_index)
	if doneness >= z.x and doneness <= z.y:
		packed[bake_index] = true
		(_ticket.get_child(bake_index) as Control).add_child(_check_mark())
		EventBus.sfx.emit(&"bread_place_display", &"")
		_say("ui_regular_bake_perfect", Palette.MATCHA_DEEP)
		bake_index += 1
		if not packed.has(false):
			_finish(true)
			return
		_next_bread()
		return
	_say("ui_regular_bake_raw" if doneness < z.x else "ui_regular_bake_burnt", Palette.STRAWBERRY_DEEP)
	_wrong(_gauge)
	_next_bread()


func _say(key: String, col: Color) -> void:
	if _feedback == null:
		return
	_feedback.text = Tx.t(key)
	_feedback.add_theme_color_override("font_color", col)


## Roti makin matang; lewat dari ujung = gosong sendiri (dihitung salah).
func _advance_bake(delta: float) -> void:
	if bake_index >= order.size():
		return
	doneness += delta / maxf(brown_seconds(bake_index), 0.05)
	if doneness >= 1.0:
		doneness = 1.0
		_say("ui_regular_bake_burnt", Palette.STRAWBERRY_DEEP)
		_wrong(_gauge)
		_next_bread()
		return
	if _gauge != null:
		_gauge.level = doneness
		_gauge.queue_redraw()


# ===========================================================================
# WAKTU & HASIL
# ===========================================================================

func _process(delta: float) -> void:
	if finished or _bar == null:
		return
	if minigame == "memory":
		if memory_showing:
			memory_left -= delta
			if memory_left <= 0.0:
				end_memory_show()
			else:
				_memory_cue()
			return
		if _peek_left > 0.0:
			_peek_left -= delta
			if _peek_left <= 0.0:
				_cover(int(get_meta("peek", 0)))
	elif minigame == "bake":
		_advance_bake(delta)
		if finished:
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
	_gauge = null
	_feedback = null
	_take = null
	_count = null
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


## Oven Panggang Pas: roti yang warnanya mengikuti kematangan (adonan pucat,
## keemasan, gosong) di atas pengukur dengan zona emas dan jarum. Flat (v3.1
## 130.6): bidang warna polos tanpa garis tepi atau gradasi.
class BakeGauge extends Control:
	const RAW: Color = Color(0.94, 0.88, 0.69)
	const GOLD: Color = Color(0.87, 0.55, 0.2)
	const BURNT: Color = Color(0.3, 0.18, 0.1)
	const WINDOW: Color = Color(0.36, 0.22, 0.14)
	const GLOW: Color = Color(1.0, 0.72, 0.36)
	var level: float = 0.0
	var zone: Vector2 = Vector2(0.58, 0.8)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	## Warna kulit roti untuk kematangan `t`: pucat -> keemasan (tengah zona) -> gosong.
	func crust(t: float) -> Color:
		var mid: float = (zone.x + zone.y) * 0.5
		if t <= mid:
			return RAW.lerp(GOLD, clampf(t / maxf(mid, 0.01), 0.0, 1.0))
		return GOLD.lerp(BURNT, clampf((t - mid) / maxf(1.0 - mid, 0.01), 0.0, 1.0))

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		# Jendela oven dengan cahaya hangat dan roti di dalamnya.
		var win := Rect2(w * 0.5 - 130.0, 0.0, 260.0, h - 70.0)
		ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(win, 22.0, 6), WINDOW)
		ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(win.grow(-12.0), 16.0, 6), GLOW)
		var c := Vector2(w * 0.5, win.end.y - 46.0)
		var s: float = 150.0
		var col: Color = crust(level)
		ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(Rect2(c + Vector2(-0.37, -0.04) * s, Vector2(0.74, 0.3) * s), 0.08 * s, 5),
			col.lerp(Color.WHITE, 0.25))
		var cap := PackedVector2Array()
		for p: Vector2 in LogoBread.cap_points():
			cap.append(c + p * s)
		ProceduralUIFactory.fill_aa(self, cap, col)
		for k in 3:
			var x: float = (float(k) - 1.0) * 0.2
			draw_line(c + Vector2(x - 0.05, -0.08) * s, c + Vector2(x + 0.05, -0.2) * s, col.lerp(Color.WHITE, 0.35), 0.05 * s, true)
		# Pengukur: pucat | zona emas | gosong, dan jarumnya.
		var bar := Rect2(24.0, h - 44.0, w - 48.0, 24.0)
		ProceduralUIFactory.fill_aa(self, ProceduralUIFactory.rounded_points(bar, 12.0, 5), RAW)
		draw_rect(Rect2(bar.position.x + bar.size.x * zone.y, bar.position.y, bar.size.x * (1.0 - zone.y) - 12.0, bar.size.y), BURNT.lerp(GOLD, 0.25))
		draw_rect(Rect2(bar.position.x + bar.size.x * zone.x, bar.position.y, bar.size.x * (zone.y - zone.x), bar.size.y), Palette.GOLD_STAR)
		var nx: float = bar.position.x + bar.size.x * clampf(level, 0.0, 1.0)
		ProceduralUIFactory.fill_aa(self, PackedVector2Array([Vector2(nx - 11.0, bar.position.y - 14.0), Vector2(nx + 11.0, bar.position.y - 14.0),
			Vector2(nx, bar.position.y + 2.0)]), Palette.UI_WOOD_DEEP)
		draw_line(Vector2(nx, bar.position.y), Vector2(nx, bar.end.y), Palette.UI_WOOD_DEEP, 4.0, true)
