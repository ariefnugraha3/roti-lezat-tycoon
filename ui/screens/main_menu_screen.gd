class_name MainMenuScreen
extends UIScreen
## Main Menu (GDD 89.2): Continue, New Game, Load Game, Settings, Credits, Exit.
## Muncul tanpa membangun dunia apa pun (GDD 89.1).


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	add_child(ProceduralUIFactory.backdrop())
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Di atas taplak gingham latar, bukan di tengah layar penuh.
	center.offset_bottom = -64.0
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	center.add_child(v)
	var lockup: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 62, 76)
	v.add_child(lockup)
	ProceduralAnimationSystem.idle_wobble(lockup.get_meta("bread"))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 10)
	var col_box := CenterContainer.new()
	col_box.add_child(col)
	v.add_child(col_box)
	var latest: StringName = SaveManager.latest_profile()
	var cont: Button = _menu_button(col, "play", Tx.t("ui_main_continue"), "primary", func() -> void: game.load_profile(latest))
	cont.disabled = latest == &""
	_menu_button(col, "plus", Tx.t("ui_main_new_game"), "success" if latest == &"" else "primary", func() -> void: host.open(&"profiles", {"mode": "new"}))
	_menu_button(col, "box", Tx.t("ui_main_load"), "secondary", func() -> void: host.open(&"profiles", {"mode": "load"}))
	_menu_button(col, "gear", Tx.t("ui_main_settings"), "secondary", func() -> void: host.open(&"settings"))
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 12)
	col.add_child(small)
	var cr: Button = ProceduralUIFactory.icon_text_button("note", Tx.t("ui_main_credits"), "secondary", 20, 16)
	cr.pressed.connect(func() -> void: host.open(&"credits"))
	cr.custom_minimum_size = Vector2(164, 48)
	small.add_child(cr)
	# Web boleh menyembunyikan Quit (GDD 89.2).
	if not OS.has_feature("web"):
		var ex: Button = ProceduralUIFactory.icon_text_button("cross", Tx.t("ui_main_exit"), "secondary", 20, 16)
		ex.pressed.connect(func() -> void: host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit()))
		ex.custom_minimum_size = Vector2(164, 48)
		small.add_child(ex)


## Tombol menu utama: ikon + teks dalam pil lebar (GDD 130.4: tombol utama 56 px+).
func _menu_button(parent: Control, icon_name: String, text: String, kind: String, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button(icon_name, text, kind, 26, 21)
	b.custom_minimum_size = Vector2(340, 58)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func on_back() -> bool:
	host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit())
	return true
