class_name HelpScreen
extends UIScreen
## Help / arsip onboarding (GDD idle 13; v3.1 27.6, 28.1): memutar ulang tip
## tanpa mereset progres.


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_help_title"), Vector2(640, 760))
	lbl(body, Tx.t("ui_help_replay_note"), 15, Palette.TEXT_MUTED, true)
	var list: VBoxContainer = scroll_box(body)
	# Dari Main Menu (Settings > Replay tutorial) belum ada game: semua tip tampil.
	var seen: Array[String] = []
	if sim != null:
		seen = sim.tutorial.archive()
	for key: String in TutorialManager.STEPS:
		if sim != null and not seen.has(key):
			continue
		var row: HBoxContainer = hbox(list, 10)
		row.add_child(ProceduralUIFactory.icon("note", 22, Palette.GOLDEN_CRUST))
		lbl(row, Tx.t(key), 17, Palette.TEXT, true)
