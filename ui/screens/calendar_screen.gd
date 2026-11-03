class_name CalendarScreen
extends UIScreen
## Popup Daily Stamps (GDD idle 21.3): kartu tujuh cap dengan hadiah setiap
## hari, tombol "Stamp it!" bila cap hari ini tersedia, lalu kartu yang sama
## dengan cap barunya. Tampil sendiri saat profil dimuat atau aplikasi kembali
## ke depan pada tanggal baru (GameRoot.check_daily_gift), dan dari lembar Goals.

## Tanggal perangkat yang dipakai popup ini (params "date"; tes boleh mengisinya).
var _date: String = ""
## Jumlah cap yang ditandai di kartu sesudah klaim (-1 = dari state).
var _shown: int = -1


## Lapisan sistem: tampil di atas lembar atau modal yang sedang terbuka tanpa
## menutupnya (GDD 28.2).
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	_date = str(params.get("date", BoostManager.today()))
	var extra: float = 200.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)
	var body: VBoxContainer = make_popup(Tx.t("ui_calendar_title"), Vector2(640, 540.0 + extra), true)
	var avail: bool = sim.calendar.available(_date)
	var shown: int = _shown if _shown >= 0 else sim.calendar.next_index()
	body.add_child(strip(sim, shown, avail and _shown < 0, true))
	var rule: Label = lbl(body, Tx.t("ui_calendar_rule"), 15, Palette.TEXT_MUTED, true)
	rule.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var nav := CenterContainer.new()
	body.add_child(nav)
	if avail:
		var b: Button = ProceduralUIFactory.icon_text_button("calendar", Tx.t("ui_calendar_claim"), "primary", 24, 20)
		b.name = "Claim"
		b.custom_minimum_size = Vector2(280, 64)
		b.pressed.connect(_claim)
		nav.add_child(b)
	else:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 10)
		nav.add_child(v)
		var note: Label = lbl(v, status_text(sim, _date), 16, Palette.UI_WOOD_DEEP, true)
		note.name = "Status"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var c: Button = btn(v, Tx.t("ui_close"), "secondary", close)
		c.name = "Done"
		c.custom_minimum_size = Vector2(220, 56)
		c.size_flags_horizontal = Control.SIZE_SHRINK_CENTER


## "Today's stamp is ready", "first stamp tomorrow" atau "next stamp tomorrow".
static func status_text(s: SimulationRoot, date: String) -> String:
	if s.calendar.available(date):
		return Tx.t("ui_calendar_ready")
	return Tx.t("ui_calendar_first") if s.calendar.stamps == 0 else Tx.t("ui_calendar_tomorrow")


## Kartu tujuh cap: `shown` cap pertama sudah dicap, cap ke-`shown` disorot bila
## `next_ready`. `big` = petak besar berisi hadiahnya dalam dua baris di tengah
## (4 + 3, popup); kecil = satu baris petak ringkas selebar lembar (Goals).
static func strip(s: SimulationRoot, shown: int, next_ready: bool, big: bool) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Stamps"
	v.add_theme_constant_override("separation", 10)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n: int = CalendarManager.rewards().size()
	var per_row: int = 4 if big else n
	var row: HBoxContainer = null
	for i in n:
		if i % per_row == 0:
			row = HBoxContainer.new()
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 10 if big else 6)
			v.add_child(row)
		row.add_child(_tile(s, i, i < shown, i == shown and next_ready, big))
	return v


static func _tile(s: SimulationRoot, i: int, stamped: bool, next: bool, big: bool) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.name = "Day%d" % (i + 1)
	var face: Color = Palette.MATCHA_SOFT if stamped else (Palette.HONEY if next else Palette.CARD)
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(face, 16, false)
	sb.set_content_margin_all(6.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(132, 124) if big else Vector2(0, 76)
	if not big:
		pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.set_meta("stamped", stamped)
	pc.set_meta("next", next)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	var ink: Color = Palette.FLOUR_WHITE if next else (Palette.MATCHA_DEEP if stamped else Palette.UI_WOOD_DEEP)
	var day: Label = ProceduralUIFactory.label(Tx.t("ui_calendar_day", {"n": i + 1}), 15 if big else 13, ink)
	day.add_theme_font_override("font", ProceduralUIFactory.display_font())
	day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(day)
	var what: Array = reward_face(s, i)
	var ic: IconCanvas = ProceduralUIFactory.icon("check" if stamped else str(what[0]), 40 if big else 28,
		ink if stamped or next else Palette.HONEY_DEEP)
	ic.name = "Icon"
	v.add_child(ic)
	if big:
		var amt: Label = ProceduralUIFactory.label(str(what[1]), 15, ink)
		amt.name = "Reward"
		amt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		amt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		v.add_child(amt)
	return pc


## [ikon, teks] hadiah cap ke-`i` bila diambil sekarang.
static func reward_face(s: SimulationRoot, i: int) -> Array:
	var r: Dictionary = s.calendar.reward(i)
	if StringName(r["decor"]) != &"":
		return ["frame", Tx.t(String(DataRegistry.decoration(StringName(r["decor"])).localization_key))]
	if float(r["kr"]) > 0.0:
		return ["coin", "+" + Tx.kr(float(r["kr"]))]
	return ["bolt", Tx.t("ui_calendar_boost", {"mult": Tx.mult(DataRegistry.idlef("calendar.boost_mult")), "minutes": int(r["boost_minutes"])})]


func _claim() -> void:
	var before: int = sim.calendar.next_index()
	var r: Dictionary = sim.calendar.claim(_date)
	if r.is_empty():
		close()
		return
	_shown = before + 1
	if StringName(r["decor"]) != &"":
		var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(StringName(r["decor"]))
		EventBus.notify.emit(1, "ui_calendar_got_decor", {"name": Tx.t(String(def.localization_key))}, &"frame")
	if float(r["kr"]) > 0.0:
		EventBus.notify.emit(2, "ui_calendar_got_kr", {"amount": Tx.kr(float(r["kr"]))}, &"coin")
		if game != null and game.hud != null and not SettingsManager.reduced_motion():
			game.hud.coin_shower()
	if float(r["boost_minutes"]) > 0.0:
		EventBus.notify.emit(2, "ui_calendar_got_boost", {"mult": Tx.mult(DataRegistry.idlef("calendar.boost_mult")),
			"minutes": int(r["boost_minutes"])}, &"bolt")
	for c: Node in get_children():
		c.queue_free()
	build.call_deferred()
