class_name GoalsScreen
extends UISheet
## Lembar Goals (GDD idle 21.2, 21.3): kartu cap harian di atas, lalu tiga
## tujuan hari ini. Setiap tujuan: ikon, teks, bar kemajuan, hadiah, dan Claim.
## Angka dan tombol diperbarui di tempat (tick_page); halaman dibangun ulang
## hanya bila set tujuan berganti (pukul 00:00) atau sesudah klaim.

const GOAL_ICONS: Dictionary = {"goal_sell": "bread", "goal_serve": "people", "goal_earn": "coin",
	"goal_rotifood": "scooter", "goal_levels": "bolt", "goal_taps": "whisk"}

## Baris tujuan yang tampil: [{index, bar, count, claim, done}].
var _rows: Array[Dictionary] = []
var _shown_key: String = ""
var _stamp_btn: Button = null
var _stamp_note: Label = null
var _stamp_ready: bool = false


func sheet_title() -> String:
	return Tx.t("ui_goals_title")


func sheet_icon() -> String:
	return "flag"


func build_page(body: VBoxContainer) -> void:
	_rows.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "GoalsList"
	section(list, Tx.t("ui_calendar_section"))
	var pc: PanelContainer = card(list)
	pc.name = "StampCard"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	pc.add_child(v)
	var today: String = BoostManager.today()
	_stamp_ready = sim.calendar.available(today)
	v.add_child(CalendarScreen.strip(sim, sim.calendar.next_index(), _stamp_ready, false))
	_stamp_note = lbl(v, CalendarScreen.status_text(sim, today), 15, Palette.UI_WOOD_DEEP, true)
	_stamp_note.name = "StampNote"
	_stamp_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stamp_btn = ProceduralUIFactory.icon_text_button("calendar", Tx.t("ui_calendar_claim"), "primary", 20, 16)
	_stamp_btn.name = "StampIt"
	_stamp_btn.custom_minimum_size = Vector2(220.0 * SettingsManager.text_scale(), 52)
	_stamp_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_stamp_btn.visible = _stamp_ready
	_stamp_btn.pressed.connect(_open_calendar)
	v.add_child(_stamp_btn)
	section(list, Tx.t("ui_goals_today"))
	if not sim.events.active().is_empty():
		var banner: PanelContainer = UISheet.card(list)
		banner.name = "EventBanner"
		banner.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PASTEL_PERIWINKLE.lightened(0.55), 18, false))
		var bh: HBoxContainer = hbox(banner, 10)
		bh.add_child(ProceduralUIFactory.icon("party", 28, Palette.APRON_NAVY))
		var bl: Label = lbl(bh, Tx.t("ui_event_goals", {"name": sim.events.names()}), 15, Palette.APRON_NAVY, true)
		bl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if not sim.goals.started():
		var wait: Label = lbl(UISheet.card(list), Tx.t("ui_goals_first_day", {"day": DataRegistry.idlei("goals.first_day")}), 15, Palette.UI_WOOD_DEEP, true)
		wait.name = "FirstDay"
	for i in sim.goals.goals.size():
		_goal_row(list, i)
	var foot: Label = lbl(list, Tx.t("ui_goals_footer"), 14, Palette.TEXT_MUTED, true)
	foot.name = "Footer"
	_regulars_section(list)
	_shown_key = _key()
	tick_page()


func _goal_row(parent: Control, i: int) -> void:
	var g: Dictionary = sim.goals.goals[i]
	var id: String = str(g["id"])
	var badge: PanelContainer = ProceduralUIFactory.badge(str(GOAL_ICONS.get(id, "flag")), Palette.HONEY_SOFT, Palette.HONEY_DEEP, 48)
	var row: HBoxContainer = UISheet.row(parent, goal_text(sim, g), "", badge)
	row.get_parent().name = "Goal_%d" % i
	var text_col: VBoxContainer = row.get_meta("text") as VBoxContainer
	var bar := GoalBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 12)
	text_col.add_child(bar)
	var count: Label = ProceduralUIFactory.label("", 14, Palette.TEXT_MUTED)
	count.name = "Count"
	text_col.add_child(count)
	var right := VBoxContainer.new()
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	right.add_theme_constant_override("separation", 6)
	row.add_child(right)
	var reward: PanelContainer = ProceduralUIFactory.pill("coin", "+" + Tx.kr(float(g["reward"])), Palette.BUTTER_SOFT, Palette.UI_WOOD_DEEP, 14)
	reward.name = "Reward"
	reward.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(reward)
	var claim: Button = ProceduralUIFactory.button(Tx.t("ui_goals_claim"), "primary")
	claim.name = "Claim"
	claim.custom_minimum_size = Vector2(120, 48)
	claim.pressed.connect(_claim.bind(i))
	right.add_child(claim)
	var done: PanelContainer = ProceduralUIFactory.pill("check", Tx.t("ui_goals_claimed"), Palette.MATCHA_SOFT, Palette.MATCHA_DEEP, 14)
	done.name = "Claimed"
	done.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	right.add_child(done)
	_rows.append({"index": i, "bar": bar, "count": count, "claim": claim, "done": done})


## Album pelanggan langganan (GDD idle 21.10): potret, hati, dan jumlah pesanan;
## mengetuknya membuka kenangan yang sudah terbuka.
func _regulars_section(list: VBoxContainer) -> void:
	section(list, Tx.t("ui_regulars_section"))
	for x: Variant in RegularManager.list():
		var id: String = str((x as Dictionary)["id"])
		var f: Dictionary = sim.regulars.friend(id)
		var met: bool = int(f.get("orders", 0)) > 0
		var face: Control = RegularOrderScreen.portrait(id, 64.0)
		if not met:
			face.modulate = Color(1.0, 1.0, 1.0, 0.45)
		var row: HBoxContainer = UISheet.row(list, Tx.t(id) if met else Tx.t("ui_regulars_unknown"),
			Tx.t("ui_regulars_orders", {"count": int(f.get("orders", 0))}) if met else "", face)
		var card: Control = row.get_parent() as Control
		card.name = "Regular_" + id
		row.add_child(RegularOrderScreen.hearts(sim.regulars.level_of(id), 18))
		if met:
			var open_b: Button = ProceduralUIFactory.icon_button("note", Tx.t("ui_regulars_story_title"), "soft", 20, Palette.UI_WOOD_DEEP)
			open_b.name = "Story"
			open_b.custom_minimum_size = Vector2(48, 48)
			open_b.pressed.connect(func() -> void: push_page(Tx.t(id), _story_page.bind(id)))
			row.add_child(open_b)


func _story_page(body: VBoxContainer, id: String) -> void:
	var list: VBoxContainer = scroll_box(body)
	list.name = "Stories"
	var c := CenterContainer.new()
	list.add_child(c)
	c.add_child(RegularOrderScreen.portrait(id, 150.0))
	var hc := CenterContainer.new()
	list.add_child(hc)
	hc.add_child(RegularOrderScreen.hearts(sim.regulars.level_of(id), 26))
	section(list, Tx.t("ui_regulars_story_title"))
	var lv: int = sim.regulars.level_of(id)
	for k in (DataRegistry.idle("regulars.levels") as Array).size():
		var open: bool = k < lv
		var row: HBoxContainer = UISheet.row(list, Tx.t("%s_story_%d" % [id, k + 1]) if open else Tx.t("ui_regulars_locked_memory"), "",
			ProceduralUIFactory.badge("heart" if open else "lock", Palette.STRAWBERRY if open else Palette.UI_CREAM_DEEP,
			Palette.FLOUR_WHITE if open else Palette.TEXT_MUTED, 40))
		row.get_parent().name = "Memory%d" % (k + 1)


## Teks tujuan dengan targetnya ("Sell 120 bread", "Earn 2,400 KR").
static func goal_text(s: SimulationRoot, g: Dictionary) -> String:
	return Tx.t(str(g["id"]), {"target": amount_text(g, float(g["target"]))})


static func amount_text(g: Dictionary, v: float) -> String:
	return Tx.kr(v) if str(g["stat"]) == "alltime_earned_kr" else Tx.big(v)


## Set tujuan dan status klaimnya; berubah = halaman dibangun ulang.
func _key() -> String:
	var parts: PackedStringArray = PackedStringArray([str(sim.goals.day), str(sim.goals.started()), str(sim.calendar.stamps)])
	for g: Dictionary in sim.goals.goals:
		parts.append("%s:%s" % [g["id"], g["claimed"]])
	return "|".join(parts)


func tick_page() -> void:
	if sim == null or page_depth() > 0 or _stamp_btn == null or not is_instance_valid(_stamp_btn):
		return
	if _key() != _shown_key or sim.calendar.available(BoostManager.today()) != _stamp_ready:
		refresh()
		return
	for r: Dictionary in _rows:
		var g: Dictionary = sim.goals.goals[int(r["index"])]
		var p: float = sim.goals.progress(g)
		var t: float = float(g["target"])
		var bar: GoalBar = r["bar"]
		bar.set_progress(p / maxf(t, 0.0001), p >= t)
		(r["count"] as Label).text = Tx.t("ui_goals_progress", {"done": amount_text(g, floorf(p)), "target": amount_text(g, t)})
		var claimed: bool = bool(g["claimed"])
		var claim: Button = r["claim"]
		claim.visible = not claimed
		claim.disabled = p < t
		(r["done"] as Control).visible = claimed


func _claim(i: int) -> void:
	if not sim.goals.claim(i):
		return
	EventBus.sfx.emit(&"coin_shower", &"")
	if game != null and game.hud != null and not SettingsManager.reduced_motion():
		game.hud.coin_shower()
	refresh()


func _open_calendar() -> void:
	if game != null and not game.modals.is_open(&"calendar"):
		game.modals.open(&"calendar", {"date": BoostManager.today()})


## Bar kemajuan tujuan: alur krem, isi madu (hijau setelah selesai). Flat.
class GoalBar:
	extends Control
	var value: float = 0.0
	var done: bool = false

	func set_progress(v: float, is_done: bool) -> void:
		var nv: float = clampf(v, 0.0, 1.0)
		if is_equal_approx(nv, value) and is_done == done:
			return
		value = nv
		done = is_done
		queue_redraw()

	func _draw() -> void:
		var h: float = size.y
		var bg: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM_DEEP, int(h * 0.5), false)
		bg.set_content_margin_all(0.0)
		draw_style_box(bg, Rect2(Vector2.ZERO, size))
		if value <= 0.0:
			return
		var fill: StyleBoxFlat = ProceduralUIFactory.panel(Palette.MATCHA if done else Palette.HONEY, int(h * 0.5), false)
		fill.set_content_margin_all(0.0)
		draw_style_box(fill, Rect2(Vector2.ZERO, Vector2(maxf(h, size.x * value), h)))
