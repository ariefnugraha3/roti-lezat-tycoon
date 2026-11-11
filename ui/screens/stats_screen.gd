class_name StatsScreen
extends UISheet
## Stats (GDD idle 12.3): pengganti Daily Summary. KR/s, penghasilan putaran dan
## sepanjang masa, roti terjual, waktu bermain dan offline, rekor, serta
## pencapaian. Murni observasional.

const MONEY_STATS: Array[String] = ["run_earned_kr", "alltime_earned_kr", "alltime_spent_kr", "highest_balance", "offline_earned_kr"]
const TIME_STATS: Array[String] = ["total_play_time_real_seconds", "offline_seconds_total"]
const RECORD_KEYS: Dictionary = {
	"largest_transaction": true, "highest_rate_kr_per_s": true, "highest_queue": false,
}

var _tab: int = 0


func sheet_title() -> String:
	return Tx.t("ui_statistics")


func sheet_icon() -> String:
	return "trophy"


func build_page(body: VBoxContainer) -> void:
	body.add_child(ProceduralUIFactory.tab_bar([Tx.t("ui_statistics"), Tx.t("ui_records"), Tx.t("ui_achievements")], _tab, func(idx: int) -> void:
		_tab = idx
		refresh()))
	var list: VBoxContainer = scroll_box(body)
	match _tab:
		0:
			list = _table(list)
			_pair(list, Tx.t("ui_stat_rate"), Tx.t("ui_kr_per_second", {"amount": Tx.rate(sim.income_rate())}))
			for k: String in StatisticsManager.STAT_KEYS:
				var v: float = sim.statistics.get_stat(k)
				var text: String = Tx.big(v)
				if MONEY_STATS.has(k):
					text = Tx.kr(v)
				elif TIME_STATS.has(k):
					text = duration_text(v)
				_pair(list, Tx.t("ui_stat_" + k), text)
		1:
			list = _table(list)
			for k2: String in RECORD_KEYS.keys():
				var v2: float = float(sim.statistics.records.get(k2, 0.0))
				var text2: String = Tx.t("ui_record_none") if v2 <= 0.0 else (Tx.kr(v2) if bool(RECORD_KEYS[k2]) else Tx.big(v2))
				_pair(list, Tx.t("ui_record_" + k2), text2)
			for loc: LocationDefinition in DataRegistry.locations():
				var day: Variant = sim.statistics.tier_reached_day.get(String(loc.id))
				_pair(list, Tx.t("ui_record_fastest_tier", {"location": Tx.t(String(loc.localization_key))}), str(day) if day != null else Tx.t("ui_record_none"))
		2:
			# Seri tanpa ujung lebih dulu (GDD idle §20 no. 90).
			section(list, Tx.t("ui_stats_series"))
			for sx: Variant in DataRegistry.idle("endless.series"):
				var sd: Dictionary = sx
				var lv: int = sim.achievements.series_level(str(sd["id"]))
				var sic: Control = ProceduralUIFactory.badge("trophy" if lv > 0 else "hourglass", Palette.GOLD_STAR if lv > 0 else Palette.UI_CREAM_DEEP,
					Palette.FLOUR_WHITE if lv > 0 else Palette.TEXT_MUTED, 40)
				var srow: HBoxContainer = UISheet.row(list, AchievementManager.series_text(sd, lv),
					Tx.t("ui_stats_series_row", {"level": lv, "mult": DataRegistry.idlei("boosts.achievement.mult"),
						"minutes": DataRegistry.idlei("boosts.achievement.minutes")}), sic)
				srow.get_parent().name = "Series_" + str(sd["id"])
			section(list, Tx.t("ui_tab_achievements_list"))
			for x: Variant in DataRegistry.achievements():
				var a: MiscDefinitions.AchievementDefinition = x
				var done: bool = sim.achievements.is_unlocked(a.id)
				var ic: Control = ProceduralUIFactory.badge("trophy" if done else "hourglass", Palette.GOLD_STAR if done else Palette.UI_CREAM_DEEP, Palette.FLOUR_WHITE if done else Palette.TEXT_MUTED, 40)
				UISheet.row(list, Tx.t(String(a.localization_key)), Tx.t(String(a.id) + "_desc"), ic)


## Lama nyata untuk statistik waktu ("2 h 5 min", Tx.duration).
static func duration_text(seconds: float) -> String:
	return Tx.duration(seconds)


## Satu kartu berisi baris-baris statistik yang dipisah garis tipis.
func _table(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.name = "Table"
	v.add_theme_constant_override("separation", 6)
	card(parent).add_child(v)
	return v


func _pair(parent: Control, left: String, right: String) -> void:
	if parent.get_child_count() > 0:
		var line := ColorRect.new()
		line.color = Color(Palette.UI_WOOD, 0.10)
		line.custom_minimum_size = Vector2(0, 2)
		line.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(line)
	var row: HBoxContainer = hbox(parent, 10)
	var l: Label = lbl(row, left, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var r: Label = lbl(row, right, 17, Palette.UI_WOOD_DEEP)
	r.add_theme_font_override("font", ProceduralUIFactory.display_font())
