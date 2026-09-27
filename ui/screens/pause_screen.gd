class_name PauseScreen
extends UIScreen
## Menu Pause (GDD 28.1): Resume, Settings, Statistics, Help, Main Menu.


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_pause_title"), Vector2(460, 560))
	for item: Array in [
		["ui_resume", "primary", close],
		["ui_statistics", "secondary", func() -> void: host.open(&"stats")],
		["ui_help", "secondary", func() -> void: host.open(&"help")],
		["ui_main_settings", "secondary", func() -> void: host.open(&"settings")],
		["ui_quit_to_menu", "ghost", func() -> void: host.confirm(Tx.t("ui_quit_confirm"), game.return_to_menu)],
	]:
		var b: Button = btn(body, Tx.t(str(item[0])), str(item[1]), item[2])
		b.custom_minimum_size = Vector2(360, 56)
	if OS.is_debug_build():
		btn(body, Tx.t("ui_debug_title"), "ghost", func() -> void: host.open(&"debug"))
