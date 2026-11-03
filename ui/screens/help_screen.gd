class_name HelpScreen
extends UIScreen
## Help / arsip onboarding (GDD idle 13; v3.1 27.6, 28.1): memutar ulang tip
## tanpa mereset progres.


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_help_title"), Vector2(640, 760), true, Palette.SHEET)
	lbl(body, Tx.t("ui_help_replay_note"), 15, Palette.TEXT_MUTED, true)
	var list: VBoxContainer = scroll_box(body)
	# Dari Main Menu (Settings > Replay tutorial) belum ada game: semua tip tampil.
	var seen: Array[String] = []
	if sim != null:
		seen = sim.tutorial.archive()
	for key: String in TutorialManager.STEPS:
		if sim != null and not seen.has(key):
			continue
		# Satu kartu per tip (pemolesan UI 2026-11-03, GDD idle 20 no. 47).
		var row: HBoxContainer = hbox(UISheet.card(list), 12)
		var ic: PanelContainer = ProceduralUIFactory.badge("note", Palette.HONEY_SOFT, Palette.GOLDEN_CRUST, 36)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		lbl(row, Tx.t(key), 17, Palette.TEXT, true)
