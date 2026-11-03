class_name HUD
extends CanvasLayer
## HUD idle (GDD idle 12.1). Hanya membaca state; setiap aksi diteruskan sebagai
## perintah ke SimulationRoot atau ModalHost. Semua posisi relatif terhadap
## bingkai potret di dalam safe area (GDD idle 12.0).
##
## Kiri atas: chip KR besar dengan "+{rate}/s" di bawahnya, lalu boost aktif.
## Kanan atas: pause, Goals (bertitik hijau bila ada tujuan atau cap harian yang
## bisa diambil, GDD idle 21.2-21.3), dan Bintang Waralaba. Tengah atas: jam kecil, hari, cuaca
## (suasana) di atas pil krem. Bawah: bar enam tab; tab yang lembarnya terbuka
## bermuka madu (v3.1 130.6: tab aktif selalu terlihat), dan tab diberi titik
## hijau bila ada sesuatu yang terjangkau di dalamnya.

const REFRESH_HZ: float = 5.0
## Tab bar bawah (GDD idle 12.1): [screen id, kunci teks, ikon].
const TABS: Array = [
	[&"upgrades", "ui_tab_upgrades", "bolt"],
	[&"menu", "ui_tab_menu", "bread"],
	[&"staff", "ui_tab_staff", "people"],
	[&"shop", "ui_tab_shop", "shop"],
	[&"decor", "ui_tab_decor", "frame"],
	[&"franchise", "ui_tab_franchise", "star"],
]
## Tinggi bar tab bawah dan ruang bar atas (logis), dipakai kamera untuk
## menaruh lantai di antara keduanya (GDD idle 12.0.4).
const TAB_BAR_H: float = 104.0
const TOP_BAR_H: float = 120.0

var game: GameRoot = null
var sim: SimulationRoot = null
var decoration_active: bool = false

var _root: Control = null
var _cash_chip: PanelContainer = null
var _kr: Label = null
var _rate: Label = null
var _stars_chip: PanelContainer = null
var _goals: Button = null
## Tujuan selesai yang belum diklaim pada refresh terakhir (-1 = belum dihitung);
## bertambah = toast "Goal complete".
var _last_claimable: int = -1
var _stars: Label = null
var _clock: Label = null
## Pil craving harian di bawah jam (GDD idle 21.1); mengetuknya membuka Menu.
var _craving: Button = null
var _craving_art: BreadArt = null
var _craving_label: Label = null
var _craving_lock: IconCanvas = null
## Pil event musiman (GDD idle 21.6); mengetuknya membuka Menu.
var _event: Button = null
var _event_label: Label = null
var _weather_icon: IconCanvas = null
var _boosts: HBoxContainer = null
var _income_boost: PanelContainer = null
var _promo_boost: PanelContainer = null
## Hadiah Roti Emas yang berjalan (GDD idle 21.9): Golden hour dan Rush hour.
var _frenzy_boost: PanelContainer = null
var _rush_boost: PanelContainer = null
var golden: GoldenBread = null
## Kartu "Special order!" pelanggan langganan di atas bar tab (GDD idle 21.10) dan
## hati yang melayang di atas kepalanya.
var _regular: Button = null
var _regular_face: ProceduralUIFactory.ChibiPortrait = null
var _regular_name: Label = null
var _regular_bar: GoalsScreen.GoalBar = null
var _regular_shown: String = ""
var _regular_marker: PanelContainer = null
var _tab_bar: HBoxContainer = null
## screen id -> Button
var _tabs: Dictionary = {}
## Tab yang lembarnya sedang terbuka (&"" = tidak ada).
var _active_tab: StringName = &""
var _hint: PanelContainer = null
var _hint_label: Label = null
var _hint_ok: Button = null
var _toasts: VBoxContainer = null
var _caption: Label = null
var _refresh: float = 0.0
var _recent_notices: Dictionary = {}
## Chip level di atas stasiun (GDD idle 12.1).
var level_chips: LevelChips = null


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
	margin.name = "Frame"
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(inset.x) + 12)
	margin.add_theme_constant_override("margin_top", int(inset.y) + 10)
	margin.add_theme_constant_override("margin_right", int(inset.z) + 12)
	margin.add_theme_constant_override("margin_bottom", int(inset.w) + 8)
	_root.add_child(margin)
	var frame := Control.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_child(frame)
	# Chip level lebih dulu: bar atas dan bar tab tergambar di atasnya.
	level_chips = LevelChips.new()
	level_chips.game = game
	level_chips.sim = sim
	_root.add_child(level_chips)
	_root.move_child(level_chips, 0)
	_build_top_left(frame)
	_build_top_right(frame)
	_build_top_center(frame)
	_build_tab_bar(frame)
	_build_hint(frame)
	_build_regular(frame)
	_build_toasts(frame)
	_caption = ProceduralUIFactory.label("", 16, Palette.TEXT)
	_caption.name = "Caption"
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_caption.offset_bottom = -TAB_BAR_H - 70.0
	_caption.offset_top = _caption.offset_bottom - 40.0
	_caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_caption.modulate.a = 0.0
	frame.add_child(_caption)
	if game != null and game.modals != null:
		game.modals.stack_changed.connect(_sync_active_tab)
	golden = GoldenBread.new()
	golden.game = game
	golden.sim = sim
	add_child(golden)
	EventBus.notify.connect(_on_notify)
	EventBus.feedback.connect(_on_feedback)
	EventBus.coin_popup.connect(_on_coin)
	EventBus.tap_boost.connect(_on_tap_boost)
	AudioManager.caption_requested.connect(_on_caption)
	_refresh_all()


# ===========================================================================
# BANGUN
# ===========================================================================

func _build_top_left(frame: Control) -> void:
	var v := VBoxContainer.new()
	v.name = "TopLeft"
	v.set_anchors_preset(Control.PRESET_TOP_LEFT)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	frame.add_child(v)
	# KR dan "+{rate}/s" di satu pil krem, supaya angka penghasilan tidak
	# melayang di atas dunia tanpa latar.
	_cash_chip = PanelContainer.new()
	_cash_chip.name = "CashChip"
	var ksb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.UI_CREAM, 0.97), 24, true)
	ksb.content_margin_left = 8.0
	ksb.content_margin_right = 18.0
	ksb.content_margin_top = 4.0
	ksb.content_margin_bottom = 4.0
	_cash_chip.add_theme_stylebox_override("panel", ksb)
	_cash_chip.mouse_filter = Control.MOUSE_FILTER_PASS
	_cash_chip.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	v.add_child(_cash_chip)
	var kh := HBoxContainer.new()
	kh.add_theme_constant_override("separation", 8)
	kh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cash_chip.add_child(kh)
	kh.add_child(ProceduralUIFactory.icon("coin", 42, Palette.GOLD_STAR))
	var kv := VBoxContainer.new()
	kv.add_theme_constant_override("separation", -4)
	kv.alignment = BoxContainer.ALIGNMENT_CENTER
	kv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	kh.add_child(kv)
	_kr = ProceduralUIFactory.label("", 30, Palette.UI_WOOD_DEEP)
	_kr.name = "Value"
	_kr.add_theme_font_override("font", ProceduralUIFactory.display_font())
	kv.add_child(_kr)
	_rate = ProceduralUIFactory.label("", 15, Palette.MATCHA_DEEP)
	_rate.name = "Rate"
	_rate.add_theme_font_override("font", ProceduralUIFactory.display_font())
	kv.add_child(_rate)
	_boosts = HBoxContainer.new()
	_boosts.name = "Boosts"
	_boosts.add_theme_constant_override("separation", 6)
	_boosts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_boosts)
	# Boost aktif dengan sisa waktu (GDD idle 12.1): dibuat sekali, hanya teksnya
	# yang diperbarui.
	_income_boost = _boost_chip("bolt", Palette.HONEY_DEEP, Palette.BUTTER_SOFT)
	_income_boost.name = "IncomeBoost"
	_income_boost.tooltip_text = Tx.t("ui_boost_income")
	_income_boost.visible = false
	_boosts.add_child(_income_boost)
	_promo_boost = _boost_chip("megaphone", Palette.UI_WOOD_DEEP, Palette.PASTEL_PERIWINKLE.lightened(0.35))
	_promo_boost.name = "PromoBoost"
	_promo_boost.visible = false
	_boosts.add_child(_promo_boost)
	# Baris kedua: hadiah Roti Emas, supaya empat pil tidak menabrak jam di tengah.
	var row2 := HBoxContainer.new()
	row2.name = "GoldenBoosts"
	row2.add_theme_constant_override("separation", 6)
	row2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(row2)
	_frenzy_boost = _boost_chip("bread", Palette.HONEY_DEEP, Palette.GOLD_STAR.lightened(0.55))
	_frenzy_boost.name = "FrenzyBoost"
	_frenzy_boost.visible = false
	row2.add_child(_frenzy_boost)
	_rush_boost = _boost_chip("people", Palette.UI_WOOD_DEEP, Palette.MATCHA_SOFT)
	_rush_boost.name = "RushBoost"
	_rush_boost.visible = false
	row2.add_child(_rush_boost)


## Pil boost aktif: muka berwarna lembut, ikon dan sisa waktu tebal.
func _boost_chip(icon_name: String, tint: Color, face: Color) -> PanelContainer:
	var c: PanelContainer = ProceduralUIFactory.chip(icon_name, tint, "", 15, 20)
	var sb: StyleBoxFlat = (c.get_theme_stylebox("panel") as StyleBoxFlat).duplicate()
	sb.bg_color = face
	sb.content_margin_left = 8.0
	sb.content_margin_right = 12.0
	c.add_theme_stylebox_override("panel", sb)
	return c


func _build_top_right(frame: Control) -> void:
	var v := VBoxContainer.new()
	v.name = "TopRight"
	v.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	v.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_END
	v.add_theme_constant_override("separation", 6)
	frame.add_child(v)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var pause: Button = _round_button("pause", Tx.t("ui_pause_title"))
	pause.name = "Pause"
	pause.pressed.connect(func() -> void: game.modals.open(&"pause"))
	row.add_child(pause)
	_goals = _round_button("flag", Tx.t("ui_goals_title"))
	_goals.name = "Goals"
	_goals.size_flags_horizontal = Control.SIZE_SHRINK_END
	_goals.pressed.connect(func() -> void: open_tab(&"goals"))
	_goals.add_child(_dot())
	v.add_child(_goals)
	_stars_chip = ProceduralUIFactory.chip("star", Palette.PASTEL_PERIWINKLE, "", 18, 24)
	_stars_chip.name = "FranchiseStars"
	_stars_chip.tooltip_text = Tx.t("ui_franchise_stars")
	_stars = _stars_chip.get_meta("value")
	v.add_child(_stars_chip)


## Tombol bundar krem tanpa garis tepi, senada chip KR di seberangnya.
func _round_button(icon_name: String, tip: String) -> Button:
	var b: Button = ProceduralUIFactory.icon_button(icon_name, tip, "plain", 24, Palette.UI_WOOD_DEEP)
	b.custom_minimum_size = Vector2(56, 56)
	for st: String in ["normal", "hover", "pressed", "hover_pressed"]:
		var psb: StyleBoxFlat = (b.get_theme_stylebox(st) as StyleBoxFlat).duplicate()
		psb.bg_color = Color(Palette.UI_CREAM, 0.97) if st == "normal" else (Palette.FLOUR_WHITE if st == "hover" else Palette.UI_CREAM_DEEP)
		b.add_theme_stylebox_override(st, psb)
	return b


## Titik hijau bercincin krem di pojok kanan atas tombol (tersembunyi).
func _dot() -> Panel:
	var dot := Panel.new()
	dot.name = "Dot"
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Palette.MATCHA
	dsb.border_color = Palette.PANEL
	dsb.set_border_width_all(3)
	dsb.set_corner_radius_all(10)
	dsb.anti_aliasing = true
	dot.add_theme_stylebox_override("panel", dsb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -20.0
	dot.offset_top = 0.0
	dot.offset_right = 0.0
	dot.offset_bottom = 20.0
	dot.visible = false
	return dot


func _build_top_center(frame: Control) -> void:
	# Jam di atas pil krem tipis, supaya terbaca di atas dinding maupun jalan.
	var pill := PanelContainer.new()
	pill.name = "ClockPill"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.UI_CREAM, 0.88), 16, false)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", sb)
	pill.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var col := VBoxContainer.new()
	col.name = "TopCenter"
	col.set_anchors_preset(Control.PRESET_CENTER_TOP)
	col.grow_horizontal = Control.GROW_DIRECTION_BOTH
	col.offset_top = 14.0
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override("separation", 6)
	frame.add_child(col)
	col.add_child(pill)
	var h := HBoxContainer.new()
	h.name = "Clock"
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	pill.add_child(h)
	_weather_icon = ProceduralUIFactory.icon("sun", 22, Palette.GOLD_STAR)
	_weather_icon.name = "Weather"
	h.add_child(_weather_icon)
	_clock = ProceduralUIFactory.label("", 15, Palette.UI_WOOD_DEEP)
	_clock.add_theme_font_override("font", ProceduralUIFactory.display_font())
	h.add_child(_clock)
	_build_craving(col)
	_build_event(col)


## Pil craving (GDD idle 21.1): gambar roti, "Craving: {recipe}", gembok bila
## resepnya belum terbuka. Dibuat sekali; gambar dan teksnya diganti di tempat.
func _build_craving(col: Control) -> void:
	_craving = ProceduralUIFactory.button("", "soft")
	_craving.name = "Craving"
	_craving.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_craving.tooltip_text = Tx.t("ui_craving_pill")
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	_craving.add_child(h)
	_craving_art = BreadArt.for_recipe(&"", 34.0)
	_craving_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_craving_art)
	_craving_label = ProceduralUIFactory.label("", 15, Palette.UI_WOOD_DEEP)
	_craving_label.add_theme_font_override("font", ProceduralUIFactory.display_font())
	h.add_child(_craving_label)
	_craving_lock = ProceduralUIFactory.icon("lock", 18, Palette.HONEY_DEEP)
	h.add_child(_craving_lock)
	_craving.pressed.connect(func() -> void: open_tab(&"menu"))
	_craving.visible = false
	col.add_child(_craving)


func _refresh_craving() -> void:
	var rid: StringName = sim.cravings.today()
	_craving.visible = rid != &""
	if rid == &"":
		return
	var r: RecipeDefinition = DataRegistry.recipe(rid)
	var prof: String = String(r.visual_profile_id) if r != null else ""
	if _craving_art.profile != prof:
		_craving_art.profile = prof
		_craving_art.queue_redraw()
	_craving_label.text = Tx.t("ui_craving_chip", {"recipe": Tx.recipe_name(rid)})
	_craving_lock.visible = not sim.upgrades.is_unlocked(rid)
	_craving.custom_minimum_size = Vector2(_craving_label.get_combined_minimum_size().x + 34.0 + 18.0 + 52.0, 48.0)


## Pil event musiman: ikon pesta dan "{event} · until {date}". Dibuat sekali.
func _build_event(col: Control) -> void:
	_event = ProceduralUIFactory.button("", "soft")
	_event.name = "Event"
	_event.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	_event.add_child(h)
	h.add_child(ProceduralUIFactory.icon("party", 24, Palette.STRAWBERRY))
	_event_label = ProceduralUIFactory.label("", 14, Palette.UI_WOOD_DEEP)
	_event_label.add_theme_font_override("font", ProceduralUIFactory.display_font())
	h.add_child(_event_label)
	_event.pressed.connect(func() -> void: open_tab(&"menu"))
	_event.visible = false
	col.add_child(_event)


func _refresh_event() -> void:
	var on: bool = not sim.events.active().is_empty()
	_event.visible = on
	if not on:
		return
	_event_label.text = Tx.t("ui_event_chip", {"name": sim.events.names(), "date": Tx.short_date(sim.events.last_end())})
	_event.custom_minimum_size = Vector2(_event_label.get_combined_minimum_size().x + 24.0 + 52.0, 48.0)


## Pil event (untuk tes).
func event_chip() -> Button:
	return _event


## Pil craving (untuk tes).
func craving_chip() -> Button:
	return _craving


func _build_tab_bar(frame: Control) -> void:
	var pc := PanelContainer.new()
	pc.name = "TabBar"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.97), 26, true)
	sb.set_content_margin_all(6)
	pc.add_theme_stylebox_override("panel", sb)
	pc.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	frame.add_child(pc)
	_tab_bar = HBoxContainer.new()
	_tab_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_tab_bar.add_theme_constant_override("separation", 4)
	pc.add_child(_tab_bar)
	for t: Array in TABS:
		var id: StringName = t[0]
		var b: Button = _tab_button(str(t[2]), str(t[1]), id)
		_tab_bar.add_child(b)
		_tabs[id] = b
	_sync_tabs()
	_sync_active_tab()


func _tab_button(icon_name: String, key: String, id: StringName) -> Button:
	var b := Button.new()
	b.name = "Tab_" + String(id)
	b.custom_minimum_size = Vector2(104, TAB_BAR_H - 12.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = Tx.t(key)
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ProceduralUIFactory.apply_kind(b, "tab")
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var ic: IconCanvas = ProceduralUIFactory.icon(icon_name, 34, Palette.UI_WOOD)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l: Label = ProceduralUIFactory.label(Tx.t(key), 14, Palette.UI_WOOD)
	l.name = "Caption"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	v.add_child(l)
	b.set_meta("icon", ic)
	b.set_meta("caption", l)
	# Titik hijau bercincin krem, supaya tetap terpisah dari tab aktif yang madu.
	var dot := Panel.new()
	dot.name = "Dot"
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Palette.MATCHA
	dsb.border_color = Palette.PANEL
	dsb.set_border_width_all(3)
	dsb.set_corner_radius_all(10)
	dsb.anti_aliasing = true
	dot.add_theme_stylebox_override("panel", dsb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -24.0
	dot.offset_top = 4.0
	dot.offset_right = -4.0
	dot.offset_bottom = 24.0
	dot.visible = false
	b.add_child(dot)
	b.pressed.connect(func() -> void: open_tab(id))
	return b


## Tab yang lembarnya terbuka bermuka madu dengan ikon dan teks krem; tab lain
## rata tanpa garis tepi (v3.1 130.6). Hanya digambar ulang saat berubah.
func _sync_active_tab() -> void:
	if game == null or game.modals == null:
		return
	var want: StringName = &""
	for id: Variant in _tabs.keys():
		if game.modals.is_open(screen_for_tab(StringName(str(id)))):
			want = StringName(str(id))
	if want == _active_tab:
		return
	_active_tab = want
	for id2: Variant in _tabs.keys():
		var b: Button = _tabs[id2]
		var on: bool = StringName(str(id2)) == want
		ProceduralUIFactory.apply_kind(b, "primary" if on else "tab")
		var ink: Color = Palette.FLOUR_WHITE if on else Palette.UI_WOOD
		(b.get_meta("icon") as IconCanvas).icon_color = ink
		(b.get_meta("caption") as Label).add_theme_color_override("font_color", ink)


## Tab yang sedang aktif (lembarnya terbuka), atau &"" (tes).
func active_tab() -> StringName:
	return _active_tab


## Buka layar tab `id`; mengetuk tab layar yang sedang terbuka menutupnya.
func open_tab(id: StringName) -> void:
	var screen: StringName = screen_for_tab(id)
	if game.modals.is_open(screen):
		game.modals.close_id(screen)
		return
	game.modals.open(screen)


## Layar milik tab `id`.
static func screen_for_tab(id: StringName) -> StringName:
	return &"decoration" if id == &"decor" else id


## Tab yang layarnya belum ada disembunyikan.
func _sync_tabs() -> void:
	for id: Variant in _tabs.keys():
		(_tabs[id] as Button).visible = game.modals.has_screen(screen_for_tab(StringName(str(id))))


func _build_regular(frame: Control) -> void:
	_regular = Button.new()
	_regular.name = "RegularCard"
	_regular.focus_mode = Control.FOCUS_NONE
	_regular.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	ProceduralUIFactory.apply_kind(_regular, "soft")
	_regular.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_regular.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_regular.offset_bottom = -TAB_BAR_H - 14.0
	_regular.offset_top = _regular.offset_bottom - 84.0
	_regular.offset_right = 300.0
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8.0
	h.offset_right = -12.0
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 8)
	_regular.add_child(h)
	_regular_face = ProceduralUIFactory.ChibiPortrait.new()
	_regular_face.custom_minimum_size = Vector2(64, 64)
	_regular_face.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_regular_face.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(_regular_face)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	_regular_name = ProceduralUIFactory.label("", 15, Palette.UI_WOOD_DEEP)
	_regular_name.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_regular_name.clip_text = true
	v.add_child(_regular_name)
	var sub: Label = ProceduralUIFactory.label(Tx.t("ui_regular_card"), 13, Palette.STRAWBERRY_DEEP)
	v.add_child(sub)
	_regular_bar = GoalsScreen.GoalBar.new()
	_regular_bar.custom_minimum_size = Vector2(0, 8)
	_regular_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_regular_bar)
	_regular.pressed.connect(func() -> void: game.open_regular_order())
	_regular.visible = false
	frame.add_child(_regular)
	_regular_marker = ProceduralUIFactory.badge("heart", Palette.STRAWBERRY, Palette.FLOUR_WHITE, 40)
	_regular_marker.name = "RegularMarker"
	_regular_marker.visible = false
	_root.add_child(_regular_marker)


func _refresh_regular() -> void:
	var v: Dictionary = sim.regulars.visit
	_regular.visible = not v.is_empty() and not decoration_active
	if v.is_empty():
		return
	var id: String = str(v["id"])
	if id != _regular_shown:
		_regular_shown = id
		var vis: Dictionary = (RegularManager.def(id).get("visual", {}) as Dictionary).duplicate()
		vis["no_apron"] = true
		_regular_face.configure(vis, "customer", 1)
		_regular_name.text = Tx.t(id)
	_regular_bar.set_progress(float(v["wait_left"]) / maxf(DataRegistry.idlef("regulars.wait_seconds"), 0.001), true)


## Kartu pesanan khusus (tes).
func regular_card() -> Button:
	return _regular


func _build_hint(frame: Control) -> void:
	_hint = PanelContainer.new()
	_hint.name = "TutorialHint"
	_hint.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.UI_CREAM, 20, true))
	_hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_hint.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_hint.offset_bottom = -TAB_BAR_H - 12.0
	_hint.visible = false
	frame.add_child(_hint)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_hint.add_child(row)
	row.add_child(ProceduralUIFactory.badge("chef", Palette.HONEY, Palette.FLOUR_WHITE, 40))
	_hint_label = ProceduralUIFactory.label("", 17, Palette.UI_WOOD_DEEP)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.custom_minimum_size = Vector2(380, 0)
	row.add_child(_hint_label)
	_hint_ok = ProceduralUIFactory.button(Tx.t("ui_got_it"), "primary")
	_hint_ok.pressed.connect(func() -> void: sim.tutorial.dismiss())
	row.add_child(_hint_ok)


func _build_toasts(frame: Control) -> void:
	_toasts = VBoxContainer.new()
	_toasts.name = "Toasts"
	_toasts.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toasts.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_toasts.offset_top = TOP_BAR_H
	_toasts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toasts.add_theme_constant_override("separation", 6)
	frame.add_child(_toasts)
	# Selalu di bawah kolom KR dan boost, yang ikut meninggi pada skala teks 150%.
	var top_left: Control = frame.get_node("TopLeft")
	top_left.minimum_size_changed.connect(func() -> void:
		_toasts.offset_top = maxf(TOP_BAR_H, top_left.get_combined_minimum_size().y + 12.0))


# ===========================================================================
# REFRESH
# ===========================================================================

func _process(delta: float) -> void:
	if sim == null:
		return
	# Hati di atas kepala regular mengikuti sosoknya setiap frame.
	var head: Vector2 = game.world.regular_head_screen() if game != null and game.world != null and not sim.regulars.visit.is_empty() else Vector2(-1.0, -1.0)
	_regular_marker.visible = head.x >= 0.0 and not decoration_active
	if _regular_marker.visible:
		_regular_marker.position = head - _regular_marker.size * 0.5 + Vector2(0.0, -4.0 * sin(float(Time.get_ticks_msec()) * 0.004))
	_refresh -= delta
	if _refresh <= 0.0:
		_refresh = 1.0 / REFRESH_HZ
		_refresh_all()


func _refresh_all() -> void:
	_root.visible = not decoration_active
	_kr.text = Tx.money(sim.economy.balance)
	var rate: float = sim.income_rate()
	_rate.text = Tx.t("ui_kr_per_second", {"amount": Tx.rate(rate)}) if rate > 0.0 else ""
	_stars_chip.visible = sim.prestige.stars > 0
	_stars.text = Tx.big(float(sim.prestige.stars))
	_refresh_boosts()
	_refresh_craving()
	_refresh_event()
	_refresh_regular()
	_refresh_goals()
	_clock.text = "%s · %s" % [Tx.t("ui_hud_day", {"day": sim.time.day}), Tx.clock(sim.time.time_seconds)]
	_weather_icon.configure("rain" if sim.weather.is_rain() else ("moon" if sim.time.is_night() else "sun"), 22,
		Palette.PASTEL_PERIWINKLE if sim.weather.is_rain() or sim.time.is_night() else Palette.GOLD_STAR)
	for id: Variant in _tabs.keys():
		var b: Button = _tabs[id]
		(b.get_node("Dot") as Control).visible = b.visible and has_affordable(StringName(str(id)))
	level_chips.refresh()


func _refresh_boosts() -> void:
	var b: BoostManager = sim.boosts
	_income_boost.visible = b.income_left > 0.0
	if _income_boost.visible:
		(_income_boost.get_meta("value") as Label).text = Tx.t("ui_boost_left", {"mult": Tx.mult(b.income_mult), "time": Tx.timer(b.income_left)})
	_frenzy_boost.visible = b.frenzy_left > 0.0
	if _frenzy_boost.visible:
		(_frenzy_boost.get_meta("value") as Label).text = Tx.t("ui_boost_left", {"mult": Tx.mult(b.frenzy_mult), "time": Tx.timer(b.frenzy_left)})
	_rush_boost.visible = b.rush_left > 0.0
	if _rush_boost.visible:
		(_rush_boost.get_meta("value") as Label).text = Tx.t("ui_boost_left", {"mult": Tx.mult(b.rush_mult), "time": Tx.timer(b.rush_left)})
	_promo_boost.visible = b.promo_left > 0.0
	if _promo_boost.visible:
		var p: Dictionary = BoostManager.promo(b.promo_id)
		(_promo_boost.get_meta("value") as Label).text = Tx.t("ui_boost_left", {"mult": Tx.mult(float(p.get("arrival_mult", 1.0))), "time": Tx.timer(b.promo_left)})
		_promo_boost.tooltip_text = Tx.t(String(b.promo_id))


## Titik di tombol Goals dan toast saat tujuan baru selesai (GDD idle 21.2).
func _refresh_goals() -> void:
	var n: int = sim.goals.claimable()
	if _last_claimable >= 0 and n > _last_claimable:
		EventBus.notify.emit(2, "ui_goals_ready", {}, &"flag")
	_last_claimable = n
	(_goals.get_node("Dot") as Control).visible = n > 0 or sim.calendar.available(BoostManager.today())


## Tombol Goals (tes).
func goals_button() -> Button:
	return _goals


## Sasaran tip onboarding `hud_<name>` (GDD idle 21.8), atau null.
func tutorial_target(target_name: String) -> Control:
	match target_name:
		"craving":
			return _craving
		"goals":
			return _goals
		"event":
			return _event
		"pause":
			return _root.find_child("Pause", true, false) as Control
		"golden":
			return golden.button if golden != null and golden.button.visible else null
		"regular":
			return _regular if _regular.visible else null
	return null


## Ada sesuatu yang terjangkau di tab `id` (titik hijau, GDD idle 12.1).
func has_affordable(id: StringName) -> bool:
	var up: UpgradeManager = sim.upgrades
	match id:
		&"upgrades":
			for pid: StringName in BoostManager.promo_ids():
				if sim.boosts.promo_block(pid) == &"":
					return true
			for cat: StringName in [&"mixer", &"oven", &"display"]:
				for e: EquipmentInstance in sim.equipment.placed_list(cat):
					if up.offer_count(up.offer(&"station", e.iid), &"x1") > 0:
						return true
			if up.offer_count(up.offer(&"counter", &"counter"), &"x1") > 0:
				return true
			for rid: StringName in up.unlocked_recipes():
				if up.offer_count(up.offer(&"recipe", rid), &"x1") > 0:
					return true
			return false
		&"menu":
			for r: RecipeDefinition in DataRegistry.recipes():
				if up.unlock_block(r.id) == &"":
					return true
			return false
		&"shop":
			if sim.upgrade_block_reason() == "":
				return true
			for cat2: StringName in [&"mixer", &"oven", &"display"]:
				if up.open_station_block(cat2) == &"":
					return true
			return false
		&"franchise":
			return sim.prestige.franchise_block() == &""
		&"decor":
			for x: Variant in DataRegistry.decorations():
				var d: MiscDefinitions.DecorationDefinition = x
				if d.has_bonus() and sim.decoration.can_buy(d.id) == &"":
					return true
			return false
		&"staff":
			for sid: StringName in sim.staff.employed_ids():
				if up.offer_count(up.offer(&"staff", sid), &"x1") > 0:
					return true
			var cost: float = sim.staff.next_hire_cost()
			if cost < 0.0 or not sim.economy.can_afford(cost):
				return false
			for role: StringName in [&"cashier", &"baker"]:
				if sim.staff.employed_ids(role).size() < sim.staff.capacity(role):
					return true
			return false
	return false


## Tombol tab (untuk tes dan sorotan onboarding).
func tab_button(id: StringName) -> Button:
	return _tabs.get(id)


func cash_chip() -> Control:
	return _cash_chip


func rate_label() -> Label:
	return _rate


# ===========================================================================
# NOTIFIKASI (v3.1 131)
# ===========================================================================

func _on_notify(priority: int, key: String, params: Dictionary, icon: StringName) -> void:
	var now: int = Time.get_ticks_msec()
	var coalesce_ms: int = int(DataRegistry.balf("limits.notification_coalesce_seconds") * 1000.0)
	if now - int(_recent_notices.get(key, -100000)) < coalesce_ms:
		return
	_recent_notices[key] = now
	var text: String = Tx.t(key, params)
	for c: Node in _toasts.get_children():
		if str(c.get_meta("text", "")) == text:
			_start_toast_fade(c as Control, priority)
			return
	var limit: int = DataRegistry.bali("limits.toasts_visible")
	while _toasts.get_child_count() >= limit:
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
	&"path_blocked": "ui_feedback_path_blocked", &"nothing_to_do": "ui_feedback_nothing_to_do",
}
const FEEDBACK_ICONS: Dictionary = {&"path_blocked": "cross", &"nothing_to_do": "bubble"}


## Umpan balik kecil di tempat (v3.1 16.7).
func _on_feedback(kind: StringName, cell: Vector2i, floor_id: StringName) -> void:
	if game.world == null or floor_id != game.world.camera_rig.active_floor or not FEEDBACK_KEYS.has(kind):
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
	row.add_child(ProceduralUIFactory.label(Tx.t(str(FEEDBACK_KEYS[kind])), 14))
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


## Semangat (GDD idle 5.2): koin kecil melompat dari stasiun yang diketuk.
func _on_tap_boost(iid: int, cell: Vector2i, floor_id: StringName) -> void:
	if game.world == null or floor_id != game.world.camera_rig.active_floor or SettingsManager.reduced_motion():
		return
	var at: Vector3 = game.world.top_of_iid(iid) if iid >= 0 else GridMath.cell_center3(cell, 1.0)
	if at == Vector3.INF:
		return
	FX.coin_pop(_root, game.world.camera_rig.world_to_screen(at), 0.0)


## Hujan koin setelah Collect di popup Selamat Datang (GDD idle 9.5).
func coin_shower() -> void:
	FX.coin_shower(_root, _root.size)
	var chip: Control = cash_chip()
	if chip != null:
		chip.pivot_offset = chip.size * 0.5
		var tw := chip.create_tween()
		tw.tween_property(chip, "scale", Vector2(1.15, 1.15), 0.12).set_delay(0.6)
		tw.tween_property(chip, "scale", Vector2.ONE, 0.2)


func _on_caption(key: String) -> void:
	_caption.text = Tx.t(key)
	var tw := _caption.create_tween()
	_caption.modulate.a = 1.0
	tw.tween_interval(2.0)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)


## Petunjuk onboarding non-modal di atas bar tab untuk langkah tanpa sasaran
## (GDD idle 13). Langkah yang meminta ketukan memakai `TutorialGuide`.
func show_tutorial_hint(key: String) -> void:
	_hint.visible = key != ""
	if key != "":
		_hint_label.text = Tx.t(key)


func tutorial_hint() -> PanelContainer:
	return _hint


func set_decoration_active(on: bool) -> void:
	decoration_active = on
	_root.visible = not on
