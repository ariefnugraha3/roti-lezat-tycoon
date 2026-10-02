class_name HUD
extends CanvasLayer
## Gameplay HUD (GDD 7, 28.3, 28.4, 30.4-30.5, 131). Hanya membaca state;
## setiap aksi diteruskan sebagai perintah ke SimulationRoot atau ModalHost.
##
## P0 selalu terlihat: KR, jam, rating fisik, alert kritis. P1 kontekstual:
## stok display, meter utilitas, pesanan RotiFood. P2: kampanye & statistik.

const REFRESH_HZ: float = 5.0

var game: GameRoot = null
var sim: SimulationRoot = null
var decoration_active: bool = false

var _root: Control = null
var _kr: Label = null
var _rating: Label = null
var _stars: Label = null
var _clock: Label = null
var _day: Label = null
var _phase: Label = null
var _phase_pill: PanelContainer = null
var _weather_icon: IconCanvas = null
var _holiday: Label = null
var _utility: Label = null
var _demand: Label = null
var _campaign: Label = null
var _solo: Label = null
var _speed_buttons: Array[Button] = []
var _pause_btn: Button = null
var _skip_btn: Button = null
var _stock_box: VBoxContainer = null
var _stock_panel: Control = null
var _orders_box: VBoxContainer = null
var _orders_sig: String = ""
var _alerts_sig: String = ""
var _rf_panel: Control = null
var _rf_button: RotiFoodButton = null
var _quick: HBoxContainer = null
var _top_right: Control = null
var _clock_panel: Control = null
## Ubin Quick Menu: ukuran terkecil, diameter lencana ikon, ukuran huruf label,
## bantalan muka ubin (kiri, atas, kanan, bawah; bawah = di atas bibir), jarak
## ikon-label, rapat baris label, dan jari-jari sudut (sedikit di bawah pil agar
## baris kedua tidak menyentuh lengkung sudut). Ukuran sebenarnya dihitung dari
## label terpanjang pada skala teks saat ini (`_quick_tile_size`).
const QUICK_BUTTON_SIZE := Vector2(112, 88)
const QUICK_BADGE: int = 36
const QUICK_FONT: int = 13
const QUICK_PAD := Vector4(9, 7, 9, 5)
const QUICK_GAP: int = 3
const QUICK_RADIUS: int = 20
const QUICK_LINE_SPACING: int = -2
const QUICK_LINES: int = 2
const QUICK_KEYS: Array[String] = ["ui_market", "ui_staff", "ui_marketing", "ui_decoration"]
## Lebar panel kanan (stok display & RotiFood), jarak antarpanel, dan jumlah
## baris pesanan RotiFood yang tampil sebelum "+N more".
const RIGHT_PANEL_W: float = 260.0
const PANEL_GAP: float = 8.0
const ORDER_ROWS: int = 3
## Warna lencana ikon Quick Menu (muka, ikon).
const QUICK_BADGES: Dictionary = {
	"cart": [Palette.HONEY, Palette.FLOUR_WHITE], "people": [Palette.MATCHA, Palette.FLOUR_WHITE],
	"megaphone": [Palette.STRAWBERRY, Palette.FLOUR_WHITE], "frame": [Palette.PASTEL_PERIWINKLE, Palette.UI_WOOD_DEEP],
}
var _market_btn: Button = null
var _alerts_box: VBoxContainer = null
var _floor_box: HBoxContainer = null
var _hint: PanelContainer = null
var _hint_label: Label = null
var _toasts: VBoxContainer = null
var _caption: Label = null
var _after_hours: HBoxContainer = null
var _refresh: float = 0.0
var _recent_notices: Dictionary = {}
var _compact: bool = false
var _quick_tile: Vector2 = QUICK_BUTTON_SIZE


func _ready() -> void:
	layer = 10
	name = "HUD"
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)
	ProceduralUIFactory.apply_theme(_root)
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(inset.x) + 12)
	margin.add_theme_constant_override("margin_top", int(inset.y) + 10)
	margin.add_theme_constant_override("margin_right", int(inset.z) + 12)
	margin.add_theme_constant_override("margin_bottom", int(inset.w) + 10)
	_root.add_child(margin)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)
	_build_top_left(frame)
	_build_top_center(frame)
	_build_top_right(frame)
	_build_right_panel(frame)
	_build_quick_menu(frame)
	_build_rotifood_panel(frame)
	_build_alerts(frame)
	_build_hint(frame)
	_build_toasts(frame)
	_build_after_hours(frame)
	_quick.resized.connect(_place_above_quick)
	_clock_panel.resized.connect(_place_above_quick)
	_place_above_quick()
	EventBus.notify.connect(_on_notify)
	EventBus.feedback.connect(_on_feedback)
	EventBus.coin_popup.connect(_on_coin)
	EventBus.speed_changed.connect(func(_s: int) -> void: _refresh_speed())
	PauseManager.pause_changed.connect(func(_p: bool) -> void: _refresh_speed())
	AudioManager.caption_requested.connect(_on_caption)
	get_viewport().size_changed.connect(_on_resize)
	_on_resize()
	_refresh_all()


# ===========================================================================
# BANGUN
# ===========================================================================

func _panel(parent: Control, preset: int) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.93), 18, true)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(preset)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	pc.add_child(v)
	return v


func _build_top_left(frame: Control) -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_TOP_LEFT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 6)
	frame.add_child(v)
	var kr: PanelContainer = ProceduralUIFactory.chip("coin", Palette.GOLD_STAR, "", 24, 34)
	kr.name = "CashChip"
	kr.tooltip_text = Tx.t("ui_summary_balance")
	_kr = kr.get_meta("value")
	v.add_child(kr)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 6)
	r2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(r2)
	var rs: PanelContainer = ProceduralUIFactory.chip("star", Palette.GOLD_STAR, "", 18, 26)
	rs.tooltip_text = Tx.t("ui_summary_store_rating")
	_rating = rs.get_meta("value")
	r2.add_child(rs)
	var rf: PanelContainer = ProceduralUIFactory.chip("scooter", Palette.OJOL_GREEN, "", 18, 26)
	rf.tooltip_text = Tx.t("ui_summary_rotifood_rating")
	_stars = rf.get_meta("value")
	r2.add_child(rf)
	_solo = ProceduralUIFactory.label(Tx.t("ui_hud_solo"), 14, Palette.DANGER)
	_solo.visible = false
	v.add_child(_solo)
	_floor_box = HBoxContainer.new()
	_floor_box.add_theme_constant_override("separation", 6)
	v.add_child(_floor_box)


## Jam, kecepatan & target harian: pojok kiri bawah (keputusan maintainer
## 2026-09-27; GDD 7 semula menaruhnya di atas).
func _build_top_center(frame: Control) -> void:
	var v: VBoxContainer = _panel(frame, Control.PRESET_BOTTOM_LEFT)
	var pc: Control = v.get_parent()
	pc.grow_horizontal = Control.GROW_DIRECTION_END
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_clock_panel = pc
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(row)
	_weather_icon = ProceduralUIFactory.icon("sun", 30, Palette.GOLD_STAR)
	row.add_child(_weather_icon)
	_day = ProceduralUIFactory.label("", 18, Palette.UI_WOOD_DEEP)
	_day.add_theme_font_override("font", ProceduralUIFactory.display_font())
	row.add_child(_day)
	var ck: HBoxContainer = ProceduralUIFactory.icon_value("clock", "", 24, 24, Palette.UI_WOOD)
	_clock = ck.get_meta("value")
	_clock.add_theme_color_override("font_color", Palette.UI_WOOD_DEEP)
	row.add_child(ck)
	# Fase hari dalam lencana berwarna: ikon + teks + warna, bukan warna saja (GDD 130.4).
	_phase_pill = PanelContainer.new()
	_phase_pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_phase_pill)
	_phase = ProceduralUIFactory.label("", 14, Palette.UI_WOOD_DEEP)
	_phase.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_phase_pill.add_child(_phase)
	var speed := HBoxContainer.new()
	speed.alignment = BoxContainer.ALIGNMENT_CENTER
	speed.add_theme_constant_override("separation", 6)
	v.add_child(speed)
	_pause_btn = ProceduralUIFactory.icon_button("pause", Tx.t("ui_pause_title"), "secondary")
	_pause_btn.pressed.connect(func() -> void: game.modals.open(&"pause"))
	speed.add_child(_pause_btn)
	for s in [1, 2, 3]:
		var b: Button = ProceduralUIFactory.button("%d×" % s, "secondary")
		b.custom_minimum_size = Vector2(60, 48)
		b.pressed.connect(func() -> void: sim.time.set_speed(s))
		speed.add_child(b)
		_speed_buttons.append(b)
	_skip_btn = _build_skip_button()
	v.add_child(_skip_btn)
	_demand = ProceduralUIFactory.label("", 16, Palette.UI_WOOD)
	_demand.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_demand)
	_holiday = ProceduralUIFactory.label("", 14, Palette.GOLDEN_CRUST)
	_holiday.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_holiday)


## "Skip to Open" (GDD 15.4): hanya selama persiapan. Ikon + teks di dalam satu
## tombol pil; seluruh tombol tetap bidang sentuhnya.
func _build_skip_button() -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button("skip", Tx.t("ui_skip_open"), "primary", 24, 17)
	b.name = "SkipToOpen"
	b.tooltip_text = Tx.t("ui_skip_open_tip", {"time": Tx.clock(sim.time.open_time)})
	b.custom_minimum_size = Vector2(maxf(210.0, b.custom_minimum_size.x), 52)
	b.pressed.connect(func() -> void: game.request_skip_to_open())
	b.visible = false
	return b


func _build_top_right(frame: Control) -> void:
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 6)
	frame.add_child(v)
	_top_right = v
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row)
	var u: PanelContainer = ProceduralUIFactory.chip("bolt", Palette.WARMER_LAMP, "", 18, 26)
	u.tooltip_text = Tx.t("ui_hud_utility")
	u.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_utility = u.get_meta("value")
	row.add_child(u)
	var menu: Button = ProceduralUIFactory.icon_button("gear", Tx.t("ui_main_settings"), "secondary", 30)
	menu.custom_minimum_size = Vector2(56, 56)
	menu.pressed.connect(func() -> void: game.modals.open(&"pause"))
	row.add_child(menu)
	_campaign = ProceduralUIFactory.label("", 14, Palette.UI_WOOD)
	_campaign.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(_campaign)


func _build_right_panel(frame: Control) -> void:
	var v: VBoxContainer = _panel(frame, Control.PRESET_CENTER_RIGHT)
	var pc: Control = v.get_parent()
	pc.name = "StockPanel"
	pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pc.grow_vertical = Control.GROW_DIRECTION_BOTH
	pc.custom_minimum_size = Vector2(RIGHT_PANEL_W, 0)
	_stock_panel = pc
	v.add_child(_section_head("bread", Palette.GOLDEN_CRUST, Tx.t("ui_hud_stock"), Palette.UI_WOOD_DEEP))
	_stock_box = VBoxContainer.new()
	_stock_box.add_theme_constant_override("separation", 2)
	v.add_child(_stock_box)


## Pesanan RotiFood (GDD 7, 22; keputusan maintainer 2026-10-02): panel sendiri
## di kanan bawah, tepat di atas Quick Menu, dengan tombol RotiFood yang
## berdering selama ada pesanan yang belum dikemas (RotiFoodButton). Dulu
## bagian ini menempel di bawah stok display dan mudah terlewat.
func _build_rotifood_panel(frame: Control) -> void:
	var v: VBoxContainer = _panel(frame, Control.PRESET_BOTTOM_RIGHT)
	var pc: Control = v.get_parent()
	pc.name = "RotiFoodPanel"
	pc.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.custom_minimum_size = Vector2(RIGHT_PANEL_W, 0)
	_rf_panel = pc
	var head: HBoxContainer = _section_head("scooter", Palette.OJOL_GREEN, Tx.t("ui_rotifood"), Palette.OJOL_GREEN.darkened(0.25))
	v.add_child(head)
	_rf_button = RotiFoodButton.new()
	_rf_button.pressed.connect(func() -> void: game.modals.open(&"rotifood"))
	head.add_child(_rf_button)
	_orders_box = VBoxContainer.new()
	_orders_box.add_theme_constant_override("separation", 4)
	v.add_child(_orders_box)
	pc.item_rect_changed.connect(_fit_right_panels, CONNECT_DEFERRED)
	_stock_panel.resized.connect(_fit_right_panels, CONNECT_DEFERRED)


## Panel RotiFood berdiri tepat di atas baris Quick Menu, mengikuti tingginya
## (ubin membesar pada skala teks 125/150% dan mengecil di layar sempit), dan
## tumbuh ke atas. Petunjuk tutorial dan tombol after-hours di tengah bawah cukup
## lebar untuk melintang di atas panel jam (kiri bawah) maupun Quick Menu (kanan
## bawah), jadi keduanya berdiri di atas yang lebih tinggi. Dulu petunjuk itu
## menutupi lencana fase di panel jam.
func _place_above_quick() -> void:
	var top: float = -(_quick.size.y + PANEL_GAP)
	_rf_panel.offset_bottom = top
	_rf_panel.offset_top = top
	var bottom_h: float = maxf(_quick.size.y, _clock_panel.size.y)
	_hint.offset_bottom = -(bottom_h + PANEL_GAP)
	_after_hours.offset_bottom = -(bottom_h + 12.0)


## Kedua panel kanan selebar yang terlebar, supaya tepinya sejajar. Stok display
## tetap di tengah kanan; ia hanya bergeser naik bila panel RotiFood yang tumbuh
## ke atas akan menabraknya, dan tidak pernah naik melewati pojok kanan atas.
func _fit_right_panels() -> void:
	if _stock_panel == null or _rf_panel == null:
		return
	var w: float = maxf(RIGHT_PANEL_W, maxf(_stock_panel.get_minimum_size().x, _rf_panel.get_minimum_size().x))
	for p: Control in [_stock_panel, _rf_panel]:
		if not is_equal_approx(p.custom_minimum_size.x, w):
			p.custom_minimum_size.x = w
	var h: float = _stock_panel.size.y
	var natural_top: float = (_stock_panel.get_parent_area_size().y - h) * 0.5
	var top: float = minf(natural_top, _rf_panel.position.y - PANEL_GAP - h)
	if _top_right != null:
		top = maxf(top, _top_right.position.y + _top_right.size.y + PANEL_GAP)
	var shift: float = top - natural_top
	if not is_equal_approx(_stock_panel.offset_top, shift):
		_stock_panel.offset_top = shift
		_stock_panel.offset_bottom = shift


## Judul bagian panel kanan: ikon bergaris tepi + judul tebal.
func _section_head(icon_name: String, tint: Color, text: String, ink: Color) -> HBoxContainer:
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	head.add_child(ProceduralUIFactory.icon(icon_name, 24, tint))
	var l: Label = ProceduralUIFactory.label(text, 17, ink)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(l)
	return head


func _build_quick_menu(frame: Control) -> void:
	_quick = HBoxContainer.new()
	_quick.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_quick.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quick.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_quick.add_theme_constant_override("separation", 10)
	frame.add_child(_quick)
	_quick_tile = _quick_tile_size()
	# Quick Menu: Pasar, Karyawan, Iklan, Dekorasi (GDD 7). Buku Resep sengaja
	# tidak ada di sini: dibuka lewat Gudang.
	_market_btn = _quick_button("cart", "ui_market", func() -> void:
		if sim.supply.market_unlocked:
			game.modals.open(&"market")
		else:
			_on_notify(2, "ui_hud_market_locked", {}, &"cart"))
	_quick_button("people", "ui_staff", func() -> void: game.modals.open(&"staff"))
	_quick_button("megaphone", "ui_marketing", func() -> void: game.modals.open(&"marketing"))
	_quick_button("frame", "ui_decoration", func() -> void: game.modals.open(&"decoration"))


## Ubin Quick Menu: pil krem berbibir dengan lencana ikon berwarna dan label
## tebal di bawahnya (seperti ikon aplikasi). Semua ubin sama besar, ikonnya
## sebaris, dan labelnya rata atas dalam kotak dua baris yang selalu muat di
## muka ubin, di atas bibirnya. Dulu label dua baris keluar dari ubin, dan pada
## skala teks 125% "Management" bahkan terpotong.
func _quick_button(icon_name: String, key: String, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.button("", "secondary")
	var k: Dictionary = ProceduralUIFactory.kind_colors("secondary")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.add_theme_stylebox_override(st, ProceduralUIFactory.cushion(k["face"], k["deep"], QUICK_RADIUS, "pressed" if st == "hover_pressed" else st))
	b.custom_minimum_size = _quick_tile
	b.tooltip_text = Tx.t(key)
	var v := VBoxContainer.new()
	v.name = "Tile"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.offset_left = QUICK_PAD.x
	v.offset_right = -QUICK_PAD.z
	v.offset_top = QUICK_PAD.y
	v.offset_bottom = -float(ProceduralUIFactory.lip()) - QUICK_PAD.w
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_theme_constant_override("separation", QUICK_GAP)
	var ic := CenterContainer.new()
	ic.name = "Icon"
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var colors: Array = QUICK_BADGES.get(icon_name, [Palette.HONEY, Palette.FLOUR_WHITE])
	ic.add_child(ProceduralUIFactory.badge(icon_name, colors[0], colors[1], QUICK_BADGE))
	v.add_child(ic)
	var font: Font = ProceduralUIFactory.display_font()
	var fs: int = ProceduralUIFactory.scaled(QUICK_FONT)
	var l: Label = ProceduralUIFactory.label(Tx.t(key), QUICK_FONT, Palette.UI_WOOD_DEEP)
	l.name = "Caption"
	l.add_theme_font_override("font", font)
	l.add_theme_constant_override("line_spacing", QUICK_LINE_SPACING)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.max_lines_visible = QUICK_LINES
	l.clip_text = true
	l.custom_minimum_size = Vector2(_quick_tile.x - QUICK_PAD.x - QUICK_PAD.z, _quick_caption_height(font, fs))
	v.add_child(l)
	b.add_child(v)
	b.pressed.connect(cb)
	_quick.add_child(b)
	return b


## Ukuran ubin yang memuat lencana ikon dan label terpanjang dalam paling banyak
## dua baris pada skala teks saat ini (GDD 28.5, 130.4): lebar tumbuh bila satu
## kata tidak muat (misalnya "Management" pada 150%), tinggi mengikuti dua baris.
## Tidak pernah lebih kecil dari QUICK_BUTTON_SIZE.
func _quick_tile_size() -> Vector2:
	var font: Font = ProceduralUIFactory.display_font()
	var fs: int = ProceduralUIFactory.scaled(QUICK_FONT)
	var inner: float = QUICK_BUTTON_SIZE.x - QUICK_PAD.x - QUICK_PAD.z
	for key: String in QUICK_KEYS:
		inner = maxf(inner, wrap_width(Tx.t(key), font, fs, QUICK_LINES))
	var h: float = QUICK_PAD.y + QUICK_BADGE + QUICK_GAP + _quick_caption_height(font, fs) + QUICK_PAD.w + ProceduralUIFactory.lip()
	return Vector2(ceilf(inner + QUICK_PAD.x + QUICK_PAD.z), maxf(QUICK_BUTTON_SIZE.y, ceilf(h)))


func _quick_caption_height(font: Font, fs: int) -> float:
	return ceilf(font.get_height(fs) * QUICK_LINES + QUICK_LINE_SPACING * (QUICK_LINES - 1))


## Lebar terkecil agar `text` muat dalam `max_lines` baris bila dipenggal per kata
## (seperti autowrap Label), ditambah 2 px cadangan pembulatan.
static func wrap_width(text: String, font: Font, fs: int, max_lines: int) -> float:
	var words: PackedStringArray = text.split(" ", false)
	var w: float = 0.0
	for word: String in words:
		w = maxf(w, font.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	while _wrapped_lines(words, font, fs, w) > max_lines:
		w += 2.0
	return w + 2.0


static func _wrapped_lines(words: PackedStringArray, font: Font, fs: int, width: float) -> int:
	var lines: int = 1
	var line: String = ""
	for word: String in words:
		var t: String = word if line == "" else line + " " + word
		if line != "" and font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > width:
			lines += 1
			line = word
		else:
			line = t
	return lines


func quick_tile_size() -> Vector2:
	return _quick_tile


func _build_alerts(frame: Control) -> void:
	_alerts_box = VBoxContainer.new()
	_alerts_box.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_alerts_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_alerts_box.add_theme_constant_override("separation", 6)
	frame.add_child(_alerts_box)


func _build_hint(frame: Control) -> void:
	_hint = PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.BUTTER_YELLOW, 20, true)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	_hint.add_theme_stylebox_override("panel", sb)
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_hint.add_child(row)
	row.add_child(ProceduralUIFactory.badge("chef", Palette.FLOUR_WHITE, Palette.UI_WOOD, 44))
	_hint_label = ProceduralUIFactory.label("", 18, Palette.UI_WOOD_DEEP)
	_hint_label.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(420, 0)
	row.add_child(_hint_label)
	var ok: Button = ProceduralUIFactory.button(Tx.t("ui_tutorial_got_it"), "primary")
	ok.pressed.connect(func() -> void:
		sim.tutorial.dismiss())
	row.add_child(ok)
	_hint.visible = false
	_caption = ProceduralUIFactory.label("", 14, Palette.TEXT_MUTED)
	# Caption suara tepat di atas panel jam (kiri bawah).
	_caption.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	frame.add_child(_caption)
	_clock_panel.resized.connect(func() -> void:
		_caption.offset_bottom = -(_clock_panel.size.y + 8.0))


## After-hours (GDD 11.6): kembali ke nota atau lanjut ke hari berikutnya
## setelah berbelanja/mengelola staf.
func _build_after_hours(frame: Control) -> void:
	_after_hours = HBoxContainer.new()
	_after_hours.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_after_hours.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_after_hours.grow_vertical = Control.GROW_DIRECTION_BEGIN
	# Di atas baris Quick Menu agar tidak menutupi tombol Pasar (_place_above_quick).
	_after_hours.add_theme_constant_override("separation", 12)
	frame.add_child(_after_hours)
	var rep: Button = ProceduralUIFactory.button(Tx.t("ui_daily_summary"), "secondary")
	rep.custom_minimum_size = Vector2(220, 60)
	rep.pressed.connect(func() -> void: game.modals.open(&"daily_summary", {"report": sim.reports.last_report}))
	_after_hours.add_child(rep)
	var cont: Button = ProceduralUIFactory.button(Tx.t("ui_continue_next_day"), "primary")
	cont.name = "Continue"
	cont.custom_minimum_size = Vector2(280, 60)
	cont.pressed.connect(func() -> void:
		if not sim.continue_to_next_day():
			_on_notify(1, "ui_summary_no_stock_note", {}, &"box"))
	_after_hours.add_child(cont)
	_after_hours.visible = false


func _build_toasts(frame: Control) -> void:
	_toasts = VBoxContainer.new()
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = 12
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	frame.add_child(_toasts)


# ===========================================================================
# REFRESH
# ===========================================================================

func _process(delta: float) -> void:
	if sim == null:
		return
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 1.0 / REFRESH_HZ
		_refresh_all()


func _refresh_all() -> void:
	_root.visible = not decoration_active
	_kr.text = Tx.kr(sim.economy.balance)
	_rating.text = Tx.rating(sim.reputation.physical)
	_stars.text = Tx.rating(sim.reputation.rotifood)
	_solo.visible = sim.bailout.solo_mode
	_day.text = "%s · %s" % [Tx.t("ui_hud_day", {"day": sim.time.day}), Tx.t("ui_weekday_%d" % sim.time.weekday())]
	_clock.text = Tx.clock(sim.time.time_seconds)
	var pill: Color = Palette.BUTTER_YELLOW
	match sim.time.phase:
		TimeManager.PREPARATION:
			_phase.text = Tx.t("ui_phase_preparation")
		TimeManager.OPEN:
			_phase.text = Tx.t("ui_phase_open")
			pill = Palette.PASTEL_MINT
		_:
			_phase.text = Tx.t("ui_phase_closed")
			pill = Palette.PASTEL_STRAWBERRY
	if not _phase_pill.has_meta("face") or _phase_pill.get_meta("face") != pill:
		_phase_pill.set_meta("face", pill)
		var sb: StyleBoxFlat = ProceduralUIFactory.panel(pill, 14, false)
		sb.content_margin_left = 10.0
		sb.content_margin_right = 10.0
		sb.content_margin_top = 2.0
		sb.content_margin_bottom = 5.0
		if not ProceduralUIFactory.flat_style:
			sb.border_width_bottom = 3
		_phase_pill.add_theme_stylebox_override("panel", sb)
	_weather_icon.configure("rain" if sim.weather.is_rain() else "sun", 30, Palette.PASTEL_PERIWINKLE if sim.weather.is_rain() else Palette.GOLD_STAR)
	var until: int = sim.weather.days_until_holiday()
	if until == 0:
		_holiday.text = Tx.t("ui_hud_holiday_today")
	elif until > 0 and until <= int(DataRegistry.weather_raw().get("holiday_countdown_days", 3)):
		_holiday.text = Tx.t("ui_hud_holiday_countdown", {"days": until})
	else:
		_holiday.text = ""
	_utility.text = Tx.kr(Money.round_half_up(sim.equipment.utility_today))
	# HUD "Permintaan: x / N roti" selama Hari 1-3 (GDD 2).
	if sim.demand.demand_total_today > 0:
		_demand.text = Tx.t("ui_hud_demand", {"done": sim.demand.delivered_today, "total": sim.demand.demand_total_today})
	else:
		_demand.text = ""
	var camp: Dictionary = sim.marketing.active
	_campaign.text = Tx.t("ui_hud_campaign", {"campaign": Tx.t(str(camp["campaign_id"])), "days": camp["remaining_days"]}) if not camp.is_empty() else ""
	_market_btn.modulate = Color(1, 1, 1, 1.0 if sim.supply.market_unlocked else 0.55)
	_after_hours.visible = sim.time.phase == TimeManager.AFTER_HOURS
	var block: StringName = sim.skip_to_open_block()
	_skip_btn.visible = block != &"phase" and block != &"tutorial" and not game.is_skipping_to_open()
	# Oven menunggu diangkat: tombol tetap bisa diketuk dan menjelaskan alasannya.
	_skip_btn.modulate = Color(1, 1, 1, 0.6 if block == &"oven" else 1.0)
	if _after_hours.visible:
		(_after_hours.get_node("Continue") as Button).disabled = not sim.reports.can_continue()
	_refresh_speed()
	_refresh_stock()
	_refresh_orders()
	_refresh_alerts()


func _refresh_speed() -> void:
	if sim == null:
		return
	for i in _speed_buttons.size():
		var active: bool = sim.time.speed == i + 1 and not PauseManager.has(PauseManager.USER)
		var want: String = "primary" if active else "secondary"
		if str(_speed_buttons[i].get_meta("kind", "")) != want:
			ProceduralUIFactory.apply_kind(_speed_buttons[i], want)


func _refresh_stock() -> void:
	UIScreen.clear(_stock_box)
	var stock: Dictionary = sim.display.sellable_by_recipe()
	if stock.is_empty():
		_stock_box.add_child(ProceduralUIFactory.label(Tx.t("ui_hud_stock_empty"), 14, Palette.TEXT_MUTED))
		return
	var keys: Array = stock.keys()
	keys.sort()
	for rid: Variant in keys:
		var row := HBoxContainer.new()
		_stock_box.add_child(row)
		var n: Label = ProceduralUIFactory.label(Tx.recipe_name(rid), 14)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		n.clip_text = true
		n.custom_minimum_size = Vector2(150, 0)
		row.add_child(n)
		var count := PanelContainer.new()
		var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM_DEEP, 10, false)
		sb.content_margin_left = 8.0
		sb.content_margin_right = 8.0
		sb.content_margin_top = 0.0
		sb.content_margin_bottom = 2.0
		if not ProceduralUIFactory.flat_style:
			sb.border_width_bottom = 2
		count.add_theme_stylebox_override("panel", sb)
		var cl: Label = ProceduralUIFactory.label(str(stock[rid]), 14, Palette.UI_WOOD_DEEP)
		cl.add_theme_font_override("font", ProceduralUIFactory.display_font())
		count.add_child(cl)
		row.add_child(count)


func _refresh_orders() -> void:
	var orders: Array[DeliveryOrder] = sim.rotifood.active_orders()
	var waiting: int = 0
	var urgent: bool = false
	for o: DeliveryOrder in orders:
		if not o.packed:
			waiting += 1
			urgent = urgent or driver_waiting(o)
	_rf_button.set_orders(waiting, urgent)
	# Baris dibangun ulang hanya bila isinya berubah. Dulu dibangun ulang tiap
	# refresh (5x per detik), sehingga tombol yang sedang ditekan dibuang di
	# tengah ketukan dan ketukannya hilang.
	var shown: Array[DeliveryOrder] = orders.slice(0, ORDER_ROWS)
	var sig: String = str(orders.size())
	for o2: DeliveryOrder in shown:
		sig += "|%d:%d:%s:%s" % [o2.order_id, o2.total_units(), o2.packed, driver_waiting(o2)]
	if sig == _orders_sig:
		return
	_orders_sig = sig
	UIScreen.clear(_orders_box)
	if orders.is_empty():
		_orders_box.add_child(ProceduralUIFactory.label(Tx.t("ui_hud_rotifood_none"), 14, Palette.TEXT_MUTED))
		return
	for o3: DeliveryOrder in shown:
		_orders_box.add_child(_order_row(o3))
	if orders.size() > ORDER_ROWS:
		var more: Button = ProceduralUIFactory.button(Tx.t("ui_rotifood_more", {"count": orders.size() - ORDER_ROWS}), "ghost")
		more.name = "More"
		more.add_theme_font_size_override("font_size", ProceduralUIFactory.scaled(14))
		more.pressed.connect(func() -> void: game.modals.open(&"rotifood"))
		_orders_box.add_child(more)


## Driver sudah di dalam toko (kesabarannya berkurang) untuk pesanan yang belum
## dikemas: pesanan itu terancam batal.
static func driver_waiting(o: DeliveryOrder) -> bool:
	return not o.packed and o.driver_phase in [&"entering", &"queued", &"at_service"]


## Satu baris pesanan: ikon status + "#id · roti · status". Merah bila driver
## sudah menunggu; teks yang terlalu panjang dipotong agar lebar panel tetap.
func _order_row(o: DeliveryOrder) -> Button:
	var urgent: bool = driver_waiting(o)
	var kind: String = "danger" if urgent else "secondary"
	var status: String = Tx.t("ui_rotifood_driver_here") if urgent else (Tx.t("ui_rotifood_row_packed") if o.packed else Tx.t("ui_rotifood_new"))
	var text: String = "#%d · %d · %s" % [o.order_id, o.total_units(), status]
	var b: Button = ProceduralUIFactory.button("", kind)
	b.name = "Order%d" % o.order_id
	b.custom_minimum_size = Vector2(0, ProceduralUIFactory.TOUCH_MIN)
	b.tooltip_text = text
	var k: Dictionary = ProceduralUIFactory.kind_colors(kind)
	var ink: Color = k["ink"]
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 12.0
	row.offset_right = -12.0
	row.offset_bottom = -ProceduralUIFactory.content_lift()
	row.add_theme_constant_override("separation", 8)
	var ic: IconCanvas = ProceduralUIFactory.icon("warning" if urgent else ("check" if o.packed else "bag"), 20,
		ink if urgent else (Palette.SUCCESS if o.packed else Palette.OJOL_GREEN))
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var l: Label = ProceduralUIFactory.label(text, 14, ink)
	l.name = "Text"
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var outline: Color = k["outline"]
	if outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", 5)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(l)
	b.add_child(row)
	var oid: int = o.order_id
	b.pressed.connect(func() -> void: game.modals.open(&"rotifood", {"order": oid}))
	return b


func rotifood_button() -> RotiFoodButton:
	return _rf_button


func rotifood_panel() -> Control:
	return _rf_panel


func stock_panel() -> Control:
	return _stock_panel


func quick_menu() -> Control:
	return _quick


## Alert off-floor & indikator L1/L2 (GDD 30.4, 30.5). Seperti baris pesanan
## RotiFood, tombolnya hanya dibangun ulang bila isinya berubah.
func _refresh_alerts() -> void:
	var pf: StringName = sim.player.actor.floor_id
	var alerts: Array[Dictionary] = sim.alerts.off_floor_alerts(pf)
	var sig: String = "%s|%s|%s" % [sim.world.location.id, pf, sim.world.location.is_multi_floor()]
	for a0: Dictionary in alerts:
		sig += "|%s:%s:%d" % [a0["floor_id"], a0["type"], int(a0["priority"])]
	if sig == _alerts_sig:
		return
	_alerts_sig = sig
	UIScreen.clear(_alerts_box)
	UIScreen.clear(_floor_box)
	if sim.world.location.is_multi_floor():
		for f: FloorDefinition in sim.world.location.floors:
			var n: String = String(f.id).replace("floor_", "")
			var b: Button = ProceduralUIFactory.button(Tx.t("ui_floor_label", {"n": n}), "primary" if f.id == pf else "ghost")
			b.custom_minimum_size = Vector2(56, 40)
			for a: Dictionary in alerts:
				if StringName(str(a["floor_id"])) == f.id and int(a["priority"]) == 0:
					b.text += " •"
					b.add_theme_color_override("font_color", Palette.DANGER)
			b.pressed.connect(focus_floor_alert)
			_floor_box.add_child(b)
	for a2: Dictionary in alerts.slice(0, 4):
		var up: bool = String(a2["floor_id"]) > String(pf)
		var arrow: String = "↑" if up else "↓"
		var key: String = {&"oven_ready": "ui_alert_oven_ready", &"oven_burning": "ui_alert_oven_burning",
			&"mixer_ready": "ui_alert_mixer_ready", &"staff_access": "ui_alert_staff_access"}.get(a2["type"], "ui_alert_oven_ready")
		var b2: Button = ProceduralUIFactory.button(Tx.t(key, {"arrow": arrow}), "danger" if int(a2["priority"]) == 0 else "primary")
		b2.custom_minimum_size = Vector2(200, 48)
		b2.pressed.connect(focus_floor_alert)
		_alerts_box.add_child(b2)


## Mengetuk alert hanya memberi petunjuk & menyorot portal (GDD 30.4).
func focus_floor_alert() -> void:
	var fg: FloorGrid = sim.world.grid(sim.player.actor.floor_id)
	if fg == null or not fg.def.has_portal():
		return
	var target: StringName = fg.def.portal["target_floor"]
	_on_notify(2, "ui_alert_floor_hint", {"floor": Tx.t("ui_floor_1") if target == &"floor_1" else Tx.t("ui_floor_2")}, &"warning")
	game.world.highlight(&"portal", -1)


# ===========================================================================
# NOTIFIKASI (GDD 131)
# ===========================================================================

func _on_notify(priority: int, key: String, params: Dictionary, icon: StringName) -> void:
	var now: int = Time.get_ticks_msec()
	var coalesce_ms: int = int(DataRegistry.balf("limits.notification_coalesce_seconds") * 1000.0)
	if now - int(_recent_notices.get(key, -100000)) < coalesce_ms:
		return
	_recent_notices[key] = now
	# Kartu identik yang masih tampil diperpanjang, bukan ditumpuk (GDD 131).
	var text: String = Tx.t(key, params)
	for c: Node in _toasts.get_children():
		if str(c.get_meta("text", "")) == text:
			_start_toast_fade(c as Control, priority)
			return
	var limit: int = DataRegistry.bali("limits.toasts_visible")
	while _toasts.get_child_count() >= limit:
		# P0/P1 boleh mendahului kartu berprioritas lebih rendah (GDD 131.2).
		var drop: Node = _toasts.get_child(0)
		if priority > int(drop.get_meta("priority", 4)):
			return
		_toasts.remove_child(drop)
		drop.queue_free()
	var pc: PanelContainer = ProceduralUIFactory.toast_card(text, String(icon), priority)
	pc.set_meta("priority", priority)
	pc.set_meta("text", text)
	_toasts.add_child(pc)
	_start_toast_fade(pc, priority)


func _start_toast_fade(pc: Control, priority: int) -> void:
	if pc.has_meta("fade"):
		var old: Variant = pc.get_meta("fade")
		if old is Tween and (old as Tween).is_valid():
			(old as Tween).kill()
	pc.modulate.a = 1.0
	var tw := pc.create_tween()
	tw.tween_interval(3.0 if priority <= 1 else 2.2)
	tw.tween_property(pc, "modulate:a", 0.0, 0.35)
	tw.tween_callback(pc.queue_free)
	pc.set_meta("fade", tw)


const FEEDBACK_KEYS: Dictionary = {
	&"path_blocked": "ui_feedback_path_blocked", &"hands_full": "ui_feedback_hands_full",
	&"station_busy": "ui_feedback_station_busy", &"missing_ingredients": "ui_feedback_missing_ingredients",
	&"display_full": "ui_feedback_display_full", &"nothing_to_do": "ui_feedback_nothing_to_do",
	&"command_queue_full": "ui_feedback_command_queue_full", &"staff_serving": "ui_feedback_staff_serving",
	&"no_free_oven": "ui_feedback_no_free_oven", &"burnt_discarded": "ui_feedback_burnt_discarded",
}
const FEEDBACK_ICONS: Dictionary = {
	&"path_blocked": "cross", &"hands_full": "bag", &"station_busy": "hourglass",
	&"missing_ingredients": "box", &"display_full": "warning", &"nothing_to_do": "bubble",
	&"burnt_discarded": "fire",
}


## Tap gagal tidak pernah terasa "mati" (GDD 16.7): bubble kecil di tempat.
func _on_feedback(kind: StringName, cell: Vector2i, floor_id: StringName) -> void:
	if game.world == null or floor_id != game.world.camera_rig.active_floor:
		return
	var pos: Vector2 = game.world.camera_rig.world_to_screen(GridMath.cell_center3(cell, 1.1))
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 16, true)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	pc.add_child(row)
	row.add_child(ProceduralUIFactory.icon(str(FEEDBACK_ICONS.get(kind, "warning")), 18, Palette.DANGER))
	row.add_child(ProceduralUIFactory.label(Tx.t(str(FEEDBACK_KEYS.get(kind, "ui_feedback_nothing_to_do"))), 14))
	_root.add_child(pc)
	pc.position = pos - Vector2(80, 30)
	var tw := pc.create_tween()
	tw.tween_property(pc, "position:y", pc.position.y - 30.0, 1.0)
	tw.parallel().tween_property(pc, "modulate:a", 0.0, 1.0).set_delay(0.5)
	tw.tween_callback(pc.queue_free)


func _on_coin(amount: float, cell: Vector2i, floor_id: StringName) -> void:
	if game.world == null or floor_id != game.world.camera_rig.active_floor:
		return
	var pos: Vector2 = game.world.camera_rig.world_to_screen(GridMath.cell_center3(cell, 1.0))
	FX.coin_pop(_root, pos, amount)


func _on_caption(key: String) -> void:
	_caption.text = Tx.t(key)
	var tw := _caption.create_tween()
	_caption.modulate.a = 1.0
	tw.tween_interval(2.0)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)


func show_tutorial_hint(key: String, _kind: StringName, _iid: int) -> void:
	if _hint == null:
		return
	_hint.visible = key != ""
	if key != "":
		_hint_label.text = Tx.t(key)


func set_decoration_active(on: bool) -> void:
	decoration_active = on
	_root.visible = not on


func _on_resize() -> void:
	var w: float = get_viewport().get_visible_rect().size.x / maxf(get_tree().root.content_scale_factor, 0.01)
	_compact = w < 1000.0
	for b: Node in _quick.get_children():
		var cap: Node = b.find_child("Caption", true, false)
		if cap != null:
			(cap as Label).visible = not _compact
		# Layar sempit: ikon saja, tetap target sentuh 64 px (GDD 110).
		(b as Control).custom_minimum_size = Vector2(64, 64) if _compact else _quick_tile
