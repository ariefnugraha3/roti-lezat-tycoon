class_name DailySummaryScreen
extends UIScreen
## Daily Summary (GDD 11, 46). Menampilkan DayReportSnapshot yang immutable:
## membuka ulang tidak pernah menghitung ulang gaji atau rating (GDD 46.3).

const MOOD_COLORS: Dictionary = {
	"mood_great": Palette.MOOD_BG_AMAZING, "mood_good": Palette.MOOD_BG_GOOD,
	"mood_even": Palette.MOOD_BG_NEUTRAL, "mood_rough": Palette.MOOD_BG_ROUGH,
	"mood_bailout": Palette.MOOD_BG_BAILOUT,
}
const MOOD_ICONS: Dictionary = {
	"mood_great": "happy", "mood_good": "happy", "mood_even": "bubble", "mood_rough": "sad", "mood_bailout": "sad",
}


## Nota harian hanya tertutup lewat tombolnya sendiri, supaya hari tidak pernah macet tanpa tombol lanjut.
func _init() -> void:
	super._init()
	keep_open = true


func build() -> void:
	var r: Dictionary = params.get("report", {})
	var shade := ColorRect.new()
	shade.color = Color(Palette.DARK_CHOCOLATE, 0.5)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var paper: PanelContainer = ProceduralUIFactory.parchment_panel()
	paper.set_anchors_preset(Control.PRESET_CENTER)
	var vp: Vector2 = get_viewport_rect().size
	var w: float = minf(960.0, vp.x - 40.0)
	var h: float = minf(680.0, vp.y - 30.0)
	paper.offset_left = -w * 0.5
	paper.offset_right = w * 0.5
	paper.offset_top = -h * 0.5
	paper.offset_bottom = h * 0.5
	add_child(paper)
	var body: VBoxContainer = ProceduralUIFactory.content_of(paper)
	var sc: VBoxContainer = scroll_box(body)
	# Kepala nota + mood.
	var head: HBoxContainer = hbox(sc, 16)
	var mood: String = str(r.get("mood", "mood_even"))
	var mood_box := PanelContainer.new()
	mood_box.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(MOOD_COLORS.get(mood, Palette.MOOD_BG_NEUTRAL), 40, false))
	mood_box.custom_minimum_size = Vector2(84, 84)
	var mc := CenterContainer.new()
	mc.add_child(ProceduralUIFactory.icon(str(MOOD_ICONS.get(mood, "bubble")), 60, Palette.GOLD_STAR if mood in ["mood_great", "mood_good"] else Palette.CUSTARD))
	mood_box.add_child(mc)
	head.add_child(mood_box)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	lbl(hv, "%s — %s" % [sim.bakery_name, Tx.t("ui_summary_title", {"day": r.get("day_number", 1)})], 26, Palette.UI_WOOD, true)
	var weather_text: String = Tx.t("ui_weather_rain") if str(r.get("weather", "")) == "weather_rain" else Tx.t("ui_weather_sunny")
	if bool(r.get("holiday", false)):
		weather_text += " · " + Tx.t("ui_event_holiday")
	lbl(hv, "%s · %s" % [Tx.t("ui_weekday_%d" % int(r.get("weekday", 0))), Tx.t("ui_summary_weather", {"weather": weather_text})], 16, Palette.TEXT_MUTED)
	lbl(hv, Tx.t(mood), 18, Palette.TEXT, true)
	sc.add_child(ProceduralUIFactory.dashed_separator())
	# Pemasukan.
	lbl(sc, Tx.t("ui_summary_income"), 20, Palette.UI_WOOD)
	_line(sc, Tx.t("ui_summary_store_sales"), Tx.kr_signed(float(r.get("physical_sales", 0.0))))
	if str(r.get("top_recipe", "")) != "":
		_line(sc, "   " + Tx.t("ui_summary_best_seller", {"recipe": Tx.recipe_name(StringName(str(r["top_recipe"]))), "count": r.get("top_recipe_count", 0)}), "")
	_line(sc, Tx.t("ui_summary_rotifood_sales"), Tx.kr_signed(float(r.get("rotifood_sales", 0.0))))
	_line(sc, "   " + Tx.t("ui_summary_orders_completed", {"count": r.get("delivery_completed", 0)}), "")
	_line(sc, Tx.t("ui_summary_tips"), Tx.kr_signed(float(r.get("tips", 0.0))))
	_line(sc, Tx.t("ui_summary_total_income"), Tx.kr_signed(float(r.get("total_income", 0.0))), true)
	sc.add_child(ProceduralUIFactory.dashed_separator())
	# Pengeluaran.
	lbl(sc, Tx.t("ui_summary_expenses"), 20, Palette.UI_WOOD)
	_line(sc, Tx.t("ui_summary_ingredients_used"), Tx.kr_signed(-float(r.get("cogs_consumed", 0.0))))
	_line(sc, Tx.t("ui_summary_utilities"), Tx.kr_signed(-float(r.get("utility_cost", 0.0))))
	_line(sc, Tx.t("ui_summary_wages"), Tx.kr_signed(-float(r.get("wages", 0.0))))
	for wl: Variant in r.get("wage_lines", []):
		var sd: StaffDefinition = DataRegistry.staff(StringName(str((wl as Dictionary)["staff_id"])))
		if sd != null:
			var role: String = Tx.t("ui_staff_role_cashier") if sd.is_cashier() else Tx.t("ui_staff_role_baker")
			_line(sc, "   " + Tx.t("ui_summary_wage_line", {"name": sd.display_name, "role": role}), Tx.kr_signed(-float((wl as Dictionary).get("wage", 0.0))))
	if float(r.get("marketing_cost_if_charged_today", 0.0)) > 0.0:
		_line(sc, Tx.t("ui_summary_marketing"), Tx.kr_signed(-float(r["marketing_cost_if_charged_today"])))
	_line(sc, Tx.t("ui_summary_total_expenses"), Tx.kr_signed(-float(r.get("total_expenses", 0.0))), true)
	if float(r.get("written_off", 0.0)) > 0.0:
		lbl(sc, Tx.t("ui_summary_unpaid", {"amount": Tx.kr(float(r["written_off"]))}), 15, Palette.DANGER, true)
	sc.add_child(ProceduralUIFactory.dashed_separator())
	_line(sc, Tx.t("ui_summary_profit"), Tx.kr_signed(float(r.get("net_profit", 0.0))), true)
	_line(sc, Tx.t("ui_summary_balance"), Tx.kr(SaveManager.decode_money(r.get("ending_balance", 0.0))), true)
	sc.add_child(ProceduralUIFactory.dashed_separator())
	# Statistik.
	lbl(sc, Tx.t("ui_summary_stats"), 20, Palette.UI_WOOD)
	_line(sc, Tx.t("ui_summary_customers"), str(r.get("physical_customer_count", 0)))
	_line(sc, Tx.t("ui_summary_deliveries_done"), str(r.get("delivery_completed", 0)))
	_line(sc, Tx.t("ui_summary_deliveries_cancelled"), str(r.get("delivery_cancelled", 0)))
	if int(r.get("delivery_rejected", 0)) > 0:
		_line(sc, Tx.t("ui_summary_deliveries_rejected"), str(r["delivery_rejected"]))
	_line(sc, Tx.t("ui_summary_bread_sold"), str(r.get("bread_sold", 0)))
	_line(sc, Tx.t("ui_summary_bread_left"), str(r.get("bread_leftover", 0)))
	if float(r.get("waste_cost", 0.0)) > 0.0:
		_line(sc, Tx.t("ui_summary_waste"), Tx.kr(float(r["waste_cost"])))
	_line(sc, Tx.t("ui_summary_store_rating"), "%s → %s / 5.0" % [Tx.rating(float(r.get("rating_start", 3.0))), Tx.rating(float(r.get("rating_end", 3.0)))])
	_line(sc, Tx.t("ui_summary_rotifood_rating"), "%s → %s / 5.0" % [Tx.rating(float(r.get("rotifood_rating_start", 3.0))), Tx.rating(float(r.get("rotifood_rating_end", 3.0)))])
	# Sorotan (1-3) dan tip Pak Lurah.
	for hl: Variant in r.get("highlights", []):
		var hd: Dictionary = hl
		var hrow: HBoxContainer = hbox(sc, 8)
		hrow.add_child(ProceduralUIFactory.icon(str(hd.get("icon", "star")), 22, Palette.GOLDEN_CRUST))
		lbl(hrow, Tx.t(str(hd["key"]), hd.get("params", {})), 16, Palette.TEXT, true)
	var note := PanelContainer.new()
	note.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.BUTTER_YELLOW, 14, true))
	sc.add_child(note)
	var nrow := HBoxContainer.new()
	nrow.add_theme_constant_override("separation", 12)
	note.add_child(nrow)
	nrow.add_child(ProceduralUIFactory.badge("note", Palette.FLOUR_WHITE, Palette.UI_WOOD, 44))
	var nv := VBoxContainer.new()
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nrow.add_child(nv)
	var who: Label = lbl(nv, Tx.t("npc_pak_lurah"), 17, Palette.UI_WOOD_DEEP)
	who.add_theme_font_override("font", ProceduralUIFactory.display_font())
	lbl(nv, Tx.t(str(r.get("tip_from_pak_lurah", "tip_default"))), 16, Palette.TEXT, true)
	if bool(r.get("wage_warning", false)):
		lbl(sc, Tx.t("ui_staff_wage_warning"), 15, Palette.DANGER, true)
	# Tombol aksi (GDD 11.5).
	var row: HBoxContainer = hbox(body, 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	# Market dan Staff membawa pemain ke after-hours: nota ditutup sendiri dulu
	# (keep_open), lalu tombol lanjut ada di HUD (GDD 11.5-11.6).
	btn(row, Tx.t("ui_summary_open_market"), "secondary", func() -> void:
		sim.enter_after_hours()
		if sim.supply.market_unlocked:
			_leave_to(&"market")
		else:
			EventBus.notify.emit(2, "ui_market_locked", {}, &"cart"))
	btn(row, Tx.t("ui_summary_manage_staff"), "secondary", func() -> void:
		sim.enter_after_hours()
		_leave_to(&"staff"))
	var cont: Button = btn(row, Tx.t("ui_continue_next_day"), "primary", _continue)
	cont.custom_minimum_size = Vector2(260, 60)
	cont.disabled = not sim.reports.can_continue()
	if cont.disabled:
		lbl(body, Tx.t("ui_summary_no_stock_note"), 15, Palette.DANGER, true)
	# Animasi "unfold" nota (GDD 11.7).
	if not SettingsManager.reduced_motion():
		paper.scale = Vector2(1.0, 0.05)
		paper.pivot_offset = Vector2(w * 0.5, 0.0)
		create_tween().tween_property(paper, "scale", Vector2.ONE, 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	EventBus.sfx.emit(&"cashier_pack", &"")


## Satu baris nota: keterangan di kiri, jumlah tebal di kanan. Jumlah bertanda
## "+" hijau matcha dan "-" merah stroberi (angka + tanda + warna, GDD 130.4).
func _line(parent: Control, left: String, right: String, bold: bool = false) -> void:
	var row: HBoxContainer = hbox(parent, 8)
	var l: Label = lbl(row, left, 18 if bold else 16, Palette.UI_WOOD_DEEP if bold else Palette.TEXT)
	if bold:
		l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if right != "":
		var ink: Color = Palette.UI_WOOD_DEEP if bold else Palette.TEXT
		if right.begins_with("+"):
			ink = Palette.MATCHA_DEEP
		elif right.begins_with("-") or right.begins_with("−"):
			ink = Palette.STRAWBERRY_DEEP
		var r: Label = lbl(row, right, 18 if bold else 16, ink)
		r.add_theme_font_override("font", ProceduralUIFactory.display_font())


func _continue() -> void:
	if sim.continue_to_next_day():
		close()
	else:
		EventBus.sfx.emit(&"ui_error", &"")


## Market/Staff: pindah ke after-hours, tutup nota, lalu buka layar itu.
func _leave_to(id: StringName) -> void:
	sim.enter_after_hours()
	var h: ModalHost = host
	close()
	h.open(id)


## Back tidak menutup nota: pemain memilih aksi (GDD 11.5).
func on_back() -> bool:
	return false
