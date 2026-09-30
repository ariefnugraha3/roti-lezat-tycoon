class_name SettingsScreen
extends UIScreen
## Settings & Accessibility (GDD 44, 75). Disimpan di user://settings.json,
## terpisah dari profil karier.

var _tab: int = 0
var _body: VBoxContainer = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_main_settings"), Vector2(920, 620))
	var tabs: HBoxContainer = hbox(body, 8)
	for i in 4:
		var key: String = ["ui_settings_audio", "ui_settings_display", "ui_settings_gameplay", "ui_settings_accessibility"][i]
		var idx: int = i
		btn(tabs, Tx.t(key), "secondary", func() -> void:
			_tab = idx
			_render())
	_body = scroll_box(body)
	_render()


func _render() -> void:
	clear(_body)
	match _tab:
		0:
			for k: String in ["master_volume", "music_volume", "sfx_volume", "ui_volume", "ambient_volume"]:
				_slider(k, {"master_volume": "ui_settings_master", "music_volume": "ui_settings_music",
					"sfx_volume": "ui_settings_sfx", "ui_volume": "ui_settings_ui", "ambient_volume": "ui_settings_ambient"}[k], 0, 100, 5)
			_toggle("mute_when_unfocused", "ui_settings_mute_unfocused")
		1:
			if WebPlatform.is_mobile_web():
				# Browser HP: layar penuh + landscape lagi setelah pemain keluar darinya.
				var fs: Button = btn(_body, Tx.t("ui_settings_fullscreen_enter"), "secondary", func() -> void: WebPlatform.enter_fullscreen_landscape())
				fs.custom_minimum_size = Vector2(280, 56)
			elif not OS.has_feature("mobile"):
				_toggle("fullscreen", "ui_settings_fullscreen")
			_choice("resolution_scale", "ui_settings_resolution_scale", [70, 85, 100], ["70%", "85%", "100%"])
			_slider("ui_scale", "ui_settings_ui_scale", 80, 150, 5)
			_slider("brightness", "ui_settings_brightness", 80, 120, 5)
			_choice("fps_cap", "ui_settings_fps_cap", [30, 60, 0], ["30", "60", Tx.t("ui_settings_fps_unlimited")])
			_choice("quality", "ui_settings_quality", ["auto", "quality_low", "quality_medium", "quality_high"],
				[Tx.t("ui_quality_auto"), Tx.t("ui_quality_low"), Tx.t("ui_quality_medium"), Tx.t("ui_quality_high")])
		2:
			_toggle("smart_speed", "ui_settings_smart_speed")
			_toggle("edge_scroll", "ui_settings_edge_scroll")
			_toggle("confirm_expensive", "ui_settings_confirm_expensive")
			_slider("confirm_threshold", "ui_settings_confirm_threshold", 0, 100000, 500)
			_toggle("tutorial_hints", "ui_settings_tutorial_hints")
			btn(_body, Tx.t("ui_settings_replay_tutorial"), "secondary", func() -> void: host.open(&"help"))
		3:
			_toggle("reduced_motion", "ui_settings_reduced_motion")
			_slider("screen_shake", "ui_settings_screen_shake", 0, 100, 5)
			if OS.has_feature("mobile"):
				_toggle("haptics", "ui_settings_haptics")
			_toggle("high_contrast_markers", "ui_settings_high_contrast")
			_toggle("patience_bar_large", "ui_settings_patience_large")
			_choice("text_scale", "ui_settings_text_scale", [100, 125, 150], ["100%", "125%", "150%"])
			_toggle("hold_to_confirm", "ui_settings_hold_confirm")
			_toggle("sound_captions", "ui_settings_captions")


func _row(label_key: String) -> HBoxContainer:
	var row: HBoxContainer = hbox(_body, 12)
	row.custom_minimum_size = Vector2(0, 52)
	var l: Label = lbl(row, Tx.t(label_key), 18)
	l.custom_minimum_size = Vector2(320, 0)
	return row


func _slider(key: String, label_key: String, lo: int, hi: int, step: int) -> void:
	var row: HBoxContainer = _row(label_key)
	var sl := HSlider.new()
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = SettingsManager.get_int(key)
	sl.custom_minimum_size = Vector2(300, 48)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	var v: Label = lbl(row, str(SettingsManager.get_int(key)), 18, Palette.UI_WOOD)
	v.custom_minimum_size = Vector2(80, 0)
	sl.value_changed.connect(func(x: float) -> void:
		SettingsManager.set_value(key, int(x))
		v.text = str(SettingsManager.get_int(key)))


func _toggle(key: String, label_key: String) -> void:
	var row: HBoxContainer = _row(label_key)
	var cb := CheckButton.new()
	cb.button_pressed = SettingsManager.get_bool(key)
	cb.custom_minimum_size = Vector2(64, 48)
	cb.toggled.connect(func(on: bool) -> void: SettingsManager.set_value(key, on))
	row.add_child(cb)


func _choice(key: String, label_key: String, values: Array, labels: Array) -> void:
	var row: HBoxContainer = _row(label_key)
	for i in values.size():
		var val: Variant = values[i]
		var active: bool = str(SettingsManager.get_value(key)) == str(val)
		var b: Button = ProceduralUIFactory.button(str(labels[i]), "primary" if active else "secondary")
		b.custom_minimum_size = Vector2(90, 48)
		b.pressed.connect(func() -> void:
			SettingsManager.set_value(key, val)
			_render())
		row.add_child(b)
