class_name HelpScreen
extends UIScreen
## Help / Tutorial Archive (GDD 27.6, 28.1): memutar ulang tip tanpa mereset
## progres.

const ALL_TIPS: Array[String] = [
	"tut_welcome", "tut_tap_storage", "tut_choose_recipe", "tut_tap_mixer", "tut_equipment_works",
	"tut_mixer_done", "tut_to_oven", "tut_burn_risk", "tut_choose_slot", "tut_patience",
	"tut_manual_cashier", "tut_income", "tut_rotifood", "tut_summary", "tut_freshness",
	"tut_office_worker", "tut_queue_capacity", "tut_pricing", "tut_smart_speed",
	"tut_fried_bread_stale", "tut_day3_balance", "tut_market_unlock", "tut_market_teaser",
]


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_help_title"), Vector2(860, 600))
	lbl(body, Tx.t("ui_help_replay_note"), 15, Palette.TEXT_MUTED, true)
	var list: VBoxContainer = scroll_box(body)
	var seen: Array[String] = sim.tutorial.archive() if sim != null else []
	for key: String in ALL_TIPS:
		if sim != null and not seen.has(key) and sim.tutorial.active():
			continue
		var row: HBoxContainer = hbox(list, 10)
		row.add_child(ProceduralUIFactory.icon("note", 22, Palette.GOLDEN_CRUST))
		lbl(row, Tx.t(key), 17, Palette.TEXT, true)
