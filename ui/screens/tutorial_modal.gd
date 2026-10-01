class_name TutorialModal
extends UIScreen
## Langkah tutorial yang mem-pause game (GDD 88: "game pause ketika tutorial
## modal aktif"). Teksnya dari katalog English (GDD 127.5). Tombol Skip
## melewati tutorial tanpa mengubah demand terjadwal (GDD 27.6).


## Tip tutorial tampil di atas layar yang sedang dijelaskannya, mis. Daily Summary.
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_help"), Vector2(620, 340), false)
	var row: HBoxContainer = hbox(body, 14)
	row.add_child(ProceduralUIFactory.icon("chef", 56, Palette.GOLDEN_CRUST))
	lbl(row, Tx.t(str(params.get("key", ""))), 20, Palette.TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var nav: HBoxContainer = hbox(body, 12)
	nav.alignment = BoxContainer.ALIGNMENT_END
	if sim != null and sim.tutorial.active():
		btn(nav, Tx.t("ui_tutorial_skip"), "ghost", func() -> void:
			host.confirm(Tx.t("ui_tutorial_skip_confirm"), _skip))
	var ok: Button = btn(nav, Tx.t("ui_tutorial_got_it"), "primary", _ok)
	ok.custom_minimum_size = Vector2(200, 56)


func _ok() -> void:
	close()
	if sim != null:
		sim.tutorial.dismiss()


func _skip() -> void:
	close()
	if sim != null:
		sim.tutorial.skip()


func on_back() -> bool:
	_ok()
	return true
