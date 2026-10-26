class_name HUD
extends CanvasLayer
## HUD idle (GDD idle 12.1). Hanya membaca state; setiap aksi diteruskan sebagai
## perintah ke SimulationRoot atau ModalHost. Semua posisi relatif terhadap
## bingkai potret di dalam safe area (GDD idle 12.0).
##
## Kiri atas: KR besar dan "+{rate}/s". Kanan atas: Reputasi, Bintang Waralaba,
## pause. Tengah atas: jam kecil, hari, cuaca (suasana). Bawah: bar enam tab;
## tab diberi titik hijau bila ada sesuatu yang terjangkau di dalamnya.

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
var _kr: Label = null
var _rate: Label = null
var _rep: Label = null
var _stars_chip: PanelContainer = null
var _stars: Label = null
var _clock: Label = null
var _weather_icon: IconCanvas = null
var _boosts: HBoxContainer = null
var _tab_bar: HBoxContainer = null
## screen id -> Button
var _tabs: Dictionary = {}
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
	var kr: PanelContainer = ProceduralUIFactory.chip("coin", Palette.GOLD_STAR, "", 30, 38)
	kr.name = "CashChip"
	_kr = kr.get_meta("value")
	v.add_child(kr)
	_rate = ProceduralUIFactory.label("", 18, Palette.UI_WOOD_DEEP)
	_rate.name = "Rate"
	_rate.add_theme_font_override("font", ProceduralUIFactory.display_font())
	v.add_child(_rate)
	_boosts = HBoxContainer.new()
	_boosts.name = "Boosts"
	_boosts.add_theme_constant_override("separation", 6)
	_boosts.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_boosts)


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
	var rep: PanelContainer = ProceduralUIFactory.chip("star", Palette.GOLD_STAR, "", 20, 26)
	rep.name = "Reputation"
	rep.tooltip_text = Tx.t("ui_reputation")
	_rep = rep.get_meta("value")
	row.add_child(rep)
	var pause: Button = ProceduralUIFactory.icon_button("pause", Tx.t("ui_pause_title"), "secondary")
	pause.name = "Pause"
	pause.pressed.connect(func() -> void: game.modals.open(&"pause"))
	row.add_child(pause)
	_stars_chip = ProceduralUIFactory.chip("star", Palette.PASTEL_PERIWINKLE, "", 18, 24)
	_stars_chip.name = "FranchiseStars"
	_stars_chip.tooltip_text = Tx.t("ui_franchise_stars")
	_stars = _stars_chip.get_meta("value")
	v.add_child(_stars_chip)


func _build_top_center(frame: Control) -> void:
	var h := HBoxContainer.new()
	h.name = "Clock"
	h.set_anchors_preset(Control.PRESET_CENTER_TOP)
	h.grow_horizontal = Control.GROW_DIRECTION_BOTH
	h.offset_top = 64.0
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_theme_constant_override("separation", 6)
	frame.add_child(h)
	_weather_icon = ProceduralUIFactory.icon("sun", 22, Palette.GOLD_STAR)
	_weather_icon.name = "Weather"
	h.add_child(_weather_icon)
	_clock = ProceduralUIFactory.label("", 15, Palette.UI_WOOD)
	_clock.add_theme_font_override("font", ProceduralUIFactory.display_font())
	h.add_child(_clock)


func _build_tab_bar(frame: Control) -> void:
	var pc := PanelContainer.new()
	pc.name = "TabBar"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Color(Palette.PANEL, 0.96), 22, true)
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


func _tab_button(icon_name: String, key: String, id: StringName) -> Button:
	var b := Button.new()
	b.name = "Tab_" + String(id)
	b.custom_minimum_size = Vector2(104, TAB_BAR_H - 12.0)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = Tx.t(key)
	ProceduralUIFactory.apply_kind(b, "secondary")
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var ic: IconCanvas = ProceduralUIFactory.icon(icon_name, 34, Palette.UI_WOOD_DEEP)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ic)
	var l: Label = ProceduralUIFactory.label(Tx.t(key), 14, Palette.UI_WOOD_DEEP)
	l.name = "Caption"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	v.add_child(l)
	var dot := Panel.new()
	dot.name = "Dot"
	var dsb := StyleBoxFlat.new()
	dsb.bg_color = Palette.MATCHA
	dsb.set_corner_radius_all(8)
	dot.add_theme_stylebox_override("panel", dsb)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	dot.offset_left = -20.0
	dot.offset_top = 6.0
	dot.offset_right = -6.0
	dot.offset_bottom = 20.0
	dot.visible = false
	b.add_child(dot)
	b.pressed.connect(func() -> void: open_tab(id))
	return b


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
	_kr.text = Tx.big(sim.economy.balance)
	var rate: float = sim.income_rate()
	_rate.text = Tx.t("ui_kr_per_second", {"amount": Tx.rate(rate)}) if rate > 0.0 else ""
	_rep.text = Tx.rating(sim.reputation.reputation)
	_stars_chip.visible = sim.prestige.stars > 0
	_stars.text = Tx.big(float(sim.prestige.stars))
	_clock.text = "%s · %s" % [Tx.t("ui_hud_day", {"day": sim.time.day}), Tx.clock(sim.time.time_seconds)]
	_weather_icon.configure("rain" if sim.weather.is_rain() else ("moon" if sim.time.is_night() else "sun"), 22,
		Palette.PASTEL_PERIWINKLE if sim.weather.is_rain() or sim.time.is_night() else Palette.GOLD_STAR)
	for id: Variant in _tabs.keys():
		var b: Button = _tabs[id]
		(b.get_node("Dot") as Control).visible = b.visible and has_affordable(StringName(str(id)))
	level_chips.refresh()


## Ada sesuatu yang terjangkau di tab `id` (titik hijau, GDD idle 12.1).
func has_affordable(id: StringName) -> bool:
	var up: UpgradeManager = sim.upgrades
	match id:
		&"upgrades":
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
				var c: float = up.open_station_cost(cat2)
				if c >= 0.0 and sim.economy.can_afford(c):
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
	return _kr.get_parent().get_parent() if _kr != null else null


func rate_label() -> Label:
	return _rate


func reputation_chip() -> Control:
	return _root.find_child("Reputation", true, false) as Control


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


func _on_caption(key: String) -> void:
	_caption.text = Tx.t(key)
	var tw := _caption.create_tween()
	_caption.modulate.a = 1.0
	tw.tween_interval(2.0)
	tw.tween_property(_caption, "modulate:a", 0.0, 0.4)


## Petunjuk onboarding non-modal di atas bar tab (GDD idle 13). `target` =
## tab yang dikelilingi cincin berdenyut.
func show_tutorial_hint(key: String, target: StringName) -> void:
	_hint.visible = key != ""
	if key != "":
		_hint_label.text = Tx.t(key)
	for id: Variant in _tabs.keys():
		var b: Button = _tabs[id]
		if key != "" and target == StringName("tab_" + String(id)):
			TutorialPulse.attach(b, ProceduralUIFactory.RADIUS_PILL)
		else:
			TutorialPulse.detach(b)


func tutorial_hint() -> PanelContainer:
	return _hint


func set_decoration_active(on: bool) -> void:
	decoration_active = on
	_root.visible = not on
