class_name TutorialModal
extends UIScreen
## Langkah onboarding berbentuk popup: sapaan Pak Lurah (GDD idle 13).
## Teksnya dari katalog English (v3.1 127). Tombol Skip melewati onboarding.


## Tip tampil di atas layar yang sedang dijelaskannya.
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_help"), Vector2(620, 300 + 120.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)), false)
	var row: HBoxContainer = hbox(body, 22)
	var lurah := LurahPortrait.new()
	lurah.name = "Lurah"
	lurah.custom_minimum_size = Vector2(104, 104)
	lurah.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(lurah)
	var said: Label = ProceduralUIFactory.label(Tx.t(str(params.get("key", ""))), 19, Palette.TEXT)
	said.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bubble: PanelContainer = ProceduralUIFactory.speech_bubble(said)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(bubble)
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
