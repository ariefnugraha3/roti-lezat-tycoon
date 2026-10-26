class_name TutorialModal
extends UIScreen
## Langkah onboarding berbentuk popup: sapaan Pak Lurah (GDD idle 13).
## Teksnya dari katalog English (v3.1 127). Tombol Skip melewati onboarding.


## Tip tampil di atas layar yang sedang dijelaskannya.
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_help"), Vector2(620, 340), false)
	var row: HBoxContainer = hbox(body, 14)
	var lurah := LurahPortrait.new()
	lurah.name = "Lurah"
	lurah.custom_minimum_size = Vector2(96, 96)
	row.add_child(lurah)
	lbl(row, Tx.t(str(params.get("key", ""))), 20, Palette.TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var nav: HBoxContainer = hbox(body, 12)
	nav.alignment = BoxContainer.ALIGNMENT_END
	if sim != null and not sim.tutorial.skipped:
		btn(nav, Tx.t("ui_tutorial_skip"), "ghost", func() -> void:
			host.confirm(Tx.t("ui_tutorial_skip_confirm"), _skip))
	var ok: Button = btn(nav, Tx.t("ui_tutorial_got_it"), "primary", _ok)
	ok.custom_minimum_size = Vector2(200, 56)


func _ok() -> void:
	close()
	if sim != null:
		sim.tutorial.dismiss_key(str(params.get("key", "")))


func _skip() -> void:
	close()
	if sim != null:
		sim.tutorial.skip()


func on_back() -> bool:
	_ok()
	return true
