class_name PauseScreen
extends UIScreen
## Menu Pause (GDD 28.1): Resume, Share my bakery dan Photo mode (GDD idle 21.4,
## 21.5), Statistics, Help, Settings, Credits, dan, selain di Web, Quit Game.
## Tanpa Main Menu (GDD idle 19 no. 21): Credits dan Quit pindah ke sini.


## Muncul di atas modal yang sedang terbuka (mis. Daily Summary) tanpa menutupnya.
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var items: Array = [
		["play", "ui_resume", "primary", close],
		["share", "ui_share_menu", "secondary", func() -> void: _open(&"share")],
		["camera", "ui_photo_menu", "secondary", func() -> void: _open(&"photo_mode")],
		["trophy", "ui_statistics", "secondary", func() -> void: _open(&"stats")],
		["bubble", "ui_help", "secondary", func() -> void: _open(&"help")],
		["gear", "ui_main_settings", "secondary", func() -> void: _open(&"settings")],
		["note", "ui_main_credits", "secondary", func() -> void: _open(&"credits")],
	]
	# Web tidak punya Quit (v3.1 89.2): tab browser ditutup sendiri.
	if not OS.has_feature("web"):
		items.append(["cross", "ui_quit_game", "ghost", func() -> void: host.confirm(Tx.t("ui_quit_game_confirm"), game.quit_game)])
	# Kartu setinggi isinya: tombol 58 px (+ Debug 48 px di build debug). Tinggi
	# tombol tidak ikut skala teks, jadi kartunya juga tidak.
	var h: float = float(items.size()) * 68.0 + (58.0 if OS.is_debug_build() else 0.0) + 80.0
	var body: VBoxContainer = make_popup(Tx.t("ui_pause_title"), Vector2(460, h))
	for item: Array in items:
		var b: Button = ProceduralUIFactory.icon_text_button(str(item[0]), Tx.t(str(item[1])), str(item[2]), 24, 19)
		b.name = str(item[1])
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
