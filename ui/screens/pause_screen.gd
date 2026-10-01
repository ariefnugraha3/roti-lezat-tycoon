class_name PauseScreen
extends UIScreen
## Menu Pause (GDD 28.1): Resume, Settings, Statistics, Help, Main Menu.


## Muncul di atas modal yang sedang terbuka (mis. Daily Summary) tanpa menutupnya.
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_pause_title"), Vector2(460, 560))
	for item: Array in [
		["play", "ui_resume", "primary", close],
		["trophy", "ui_statistics", "secondary", func() -> void: _open(&"stats")],
		["bubble", "ui_help", "secondary", func() -> void: _open(&"help")],
		["gear", "ui_main_settings", "secondary", func() -> void: _open(&"settings")],
		["shop", "ui_quit_to_menu", "ghost", func() -> void: host.confirm(Tx.t("ui_quit_confirm"), game.return_to_menu)],
	]:
		var b: Button = ProceduralUIFactory.icon_text_button(str(item[0]), Tx.t(str(item[1])), str(item[2]), 24, 19)
		b.custom_minimum_size = Vector2(360, 58)
		b.pressed.connect(item[3])
		body.add_child(b)
	if OS.is_debug_build():
		var d: Button = ProceduralUIFactory.icon_text_button("bolt", Tx.t("ui_debug_title"), "ghost", 20, 16)
		d.custom_minimum_size = Vector2(360, 48)
		d.pressed.connect(func() -> void: _open(&"debug"))
		body.add_child(d)


## Menu Pause adalah lapisan di atas modal lain; ia menutup diri sebelum membuka
## layar biasa supaya layar itu tidak terselip di bawahnya. Modal di bawahnya
## (mis. Daily Summary) tetap ada.
func _open(id: StringName) -> void:
	var h: ModalHost = host
	close()
	h.open(id)
