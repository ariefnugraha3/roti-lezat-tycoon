class_name MainMenuScreen
extends UIScreen
## Main Menu (v3.1 89.2): Continue, New Game, Load Game, Settings, Credits, Exit.
## Muncul tanpa membangun dunia apa pun (v3.1 89.1). Potret (GDD idle 12.0.5):
## logo di sepertiga atas, tombol bertumpuk vertikal di bawahnya.

## Puncak logo, sebagai bagian tinggi bingkai.
const LOGO_TOP: float = 0.13


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	add_child(ProceduralUIFactory.backdrop())
	var v := VBoxContainer.new()
	v.anchor_right = 1.0
	v.anchor_top = LOGO_TOP
	v.anchor_bottom = 1.0
	# Di atas taplak gingham latar.
	v.offset_bottom = -110.0
	v.alignment = BoxContainer.ALIGNMENT_BEGIN
	v.add_theme_constant_override("separation", 44)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var logo_box := CenterContainer.new()
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(logo_box)
	var lockup: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 76, 104)
	logo_box.add_child(lockup)
	ProceduralAnimationSystem.idle_wobble(lockup.get_meta("bread"))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 12)
	var col_box := CenterContainer.new()
	col_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col_box.add_child(col)
	v.add_child(col_box)
	var latest: StringName = SaveManager.latest_profile()
	var cont: Button = _menu_button(col, "play", Tx.t("ui_main_continue"), "primary", func() -> void: game.load_profile(latest))
	cont.disabled = latest == &""
	_menu_button(col, "plus", Tx.t("ui_main_new_game"), "success" if latest == &"" else "primary", func() -> void: host.open(&"profiles", {"mode": "new"}))
	_menu_button(col, "box", Tx.t("ui_main_load"), "secondary", func() -> void: host.open(&"profiles", {"mode": "load"}))
	_menu_button(col, "gear", Tx.t("ui_main_settings"), "secondary", func() -> void: host.open(&"settings"))
	_menu_button(col, "note", Tx.t("ui_main_credits"), "secondary", func() -> void: host.open(&"credits"))
	# Web boleh menyembunyikan Quit (v3.1 89.2).
	if not OS.has_feature("web"):
		_menu_button(col, "cross", Tx.t("ui_main_exit"), "secondary", func() -> void: host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit()))


## Tombol menu utama: ikon + teks dalam pil lebar (GDD 130.4: tombol utama 56 px+).
func _menu_button(parent: Control, icon_name: String, text: String, kind: String, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button(icon_name, text, kind, 26, 21)
	b.custom_minimum_size = Vector2(400, 64)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func on_back() -> bool:
	host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit())
	return true
