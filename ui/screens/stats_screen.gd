class_name StatsScreen
extends UIScreen
## Lifetime Statistics, Personal Records, Achievements (GDD 74, 92, 118).
## Murni observasional.

const RECORD_KEYS: Dictionary = {
	"highest_daily_revenue": ["ui_record_highest_daily_revenue", true],
	"highest_daily_profit": ["ui_record_highest_daily_profit", true],
	"most_bread_sold_day": ["ui_record_most_bread_sold_day", false],
	"most_customers_day": ["ui_record_most_customers_day", false],
	"most_rotifood_day": ["ui_record_most_rotifood_day", false],
	"longest_no_burn": ["ui_record_longest_no_burn", false],
	"highest_physical_rating": ["ui_record_highest_physical_rating", false],
	"highest_rotifood_rating": ["ui_record_highest_rotifood_rating", false],
	"largest_transaction": ["ui_record_largest_transaction", true],
	"highest_queue": ["ui_record_highest_queue", false],
}
const MONEY_STATS: Array[String] = ["total_kr_earned", "total_kr_spent", "highest_balance"]

var _tab: int = 0
var _body: VBoxContainer = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_statistics"), Vector2(960, 620))
	body.add_child(ProceduralUIFactory.tab_bar([Tx.t("ui_statistics"), Tx.t("ui_records"), Tx.t("ui_achievements")], _tab, func(idx: int) -> void:
		_tab = idx
		_render()))
	_body = scroll_box(body)
	_render()


func _render() -> void:
	clear(_body)
	match _tab:
		0:
			for k: String in StatisticsManager.STAT_KEYS:
				var v: float = sim.statistics.get_stat(k)
				var text: String = Tx.kr(v) if MONEY_STATS.has(k) else ("%dh %02dm" % [int(v / 3600.0), int(fmod(v, 3600.0) / 60.0)] if k == "total_play_time_real_seconds" else Money.group_int(int(v)))
				_pair(Tx.t("ui_stat_" + k.trim_prefix("")), text)
		1:
			for k2: String in RECORD_KEYS.keys():
				var spec: Array = RECORD_KEYS[k2]
				var v2: float = float(sim.statistics.records.get(k2, 0.0))
				var text2: String = Tx.t("ui_record_none") if v2 <= 0.0 else (Tx.kr(v2) if bool(spec[1]) else ("%.1f" % v2 if k2.contains("rating") else Money.group_int(int(v2))))
				_pair(Tx.t(str(spec[0])), text2)
			for loc: LocationDefinition in DataRegistry.locations():
				var day: Variant = sim.statistics.tier_reached_day.get(String(loc.id))
				_pair(Tx.t("ui_record_fastest_tier", {"location": Tx.t(String(loc.localization_key))}), str(day) if day != null else Tx.t("ui_record_none"))
		2:
			for x: Variant in DataRegistry.achievements():
				var a: MiscDefinitions.AchievementDefinition = x
				var done: bool = sim.achievements.is_unlocked(a.id)
				var row: HBoxContainer = hbox(_body, 10)
				row.add_child(ProceduralUIFactory.icon("trophy" if done else "hourglass", 26, Palette.GOLD_STAR if done else Palette.TEXT_MUTED))
				var v3 := VBoxContainer.new()
				v3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				row.add_child(v3)
				lbl(v3, Tx.t(String(a.localization_key)), 18, Palette.UI_WOOD if done else Palette.TEXT_MUTED)
				lbl(v3, Tx.t(String(a.id) + "_desc"), 14, Palette.TEXT_MUTED, true)
				lbl(v3, Tx.t("ui_achievement_reward", {"reward": Tx.t(String(a.reward_id))}), 14, Palette.GOLDEN_CRUST if done else Palette.TEXT_MUTED)


func _pair(left: String, right: String) -> void:
	var row: HBoxContainer = hbox(_body, 10)
	var l: Label = lbl(row, left, 17)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl(row, right, 17, Palette.UI_WOOD)
