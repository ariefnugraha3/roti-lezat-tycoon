class_name SettingsScreen
extends UIScreen
## Settings & Accessibility (v3.1 44, 75; GDD idle 7.5). Disimpan di user://settings.json,
## terpisah dari profil karier.

## Tab terakhir dibuka (tetap sama setelah ganti bahasa membuka ulang layar ini).
static var _last_tab: int = 0
var _tab: int = 0
var _body: VBoxContainer = null


func build() -> void:
	_tab = _last_tab
	var body: VBoxContainer = make_popup(Tx.t("ui_main_settings"), Vector2(640, 900))
	var labels: Array = []
	for key: String in ["ui_settings_audio", "ui_settings_display", "ui_settings_gameplay", "ui_settings_accessibility"]:
		labels.append(Tx.t(key))
	body.add_child(ProceduralUIFactory.tab_bar(labels, _tab, func(idx: int) -> void:
		_tab = idx
		_last_tab = idx
		_render()))
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
				# Browser HP: layar penuh + potret lagi setelah pemain keluar darinya.
				var fs: Button = btn(_body, Tx.t("ui_settings_fullscreen_enter"), "secondary", func() -> void: WebPlatform.enter_fullscreen_portrait())
				fs.custom_minimum_size = Vector2(280, 56)
			elif not OS.has_feature("mobile"):
				_toggle("fullscreen", "ui_settings_fullscreen")
			_choice("resolution_scale", "ui_settings_resolution_scale", [70, 85, 100], ["70%", "85%", "100%"])
			_slider("brightness", "ui_settings_brightness", 80, 120, 5)
			_choice("fps_cap", "ui_settings_fps_cap", [30, 60, 0], ["30", "60", Tx.t("ui_settings_fps_unlimited")])
			_choice("quality", "ui_settings_quality", ["auto", "quality_low", "quality_medium", "quality_high"],
				[Tx.t("ui_quality_auto"), Tx.t("ui_quality_low"), Tx.t("ui_quality_medium"), Tx.t("ui_quality_high")])
		2:
			_language()
			_choice("number_format", "ui_number_format", ["short", "scientific"],
				[Tx.t("ui_number_format_short"), Tx.t("ui_number_format_scientific")])
			_toggle("tutorial_hints", "ui_settings_tutorial_hints")
			btn(_body, Tx.t("ui_settings_replay_tutorial"), "secondary", func() -> void: host.open(&"help"))
			_save_section()
		3:
			_toggle("reduced_motion", "ui_settings_reduced_motion")
			# Hanya di perangkat yang bisa bergetar (Haptics, v3.1 75.4).
			if Haptics.supported():
				_toggle("haptics", "ui_settings_haptics")
			_toggle("high_contrast_markers", "ui_settings_high_contrast")
			_choice("text_scale", "ui_settings_text_scale", [100, 125, 150], ["100%", "125%", "150%"])
			_toggle("hold_to_confirm", "ui_settings_hold_confirm")
			_toggle("sound_captions", "ui_settings_captions")


## Bahasa (Seksi 19 no. 25): nama tiap bahasa ditulis dalam bahasanya sendiri,
## supaya pemain yang salah pilih tetap bisa menemukan bahasanya. Menggantinya
## menyusun ulang layar (GameRoot.relocalize).
func _language() -> void:
	var row: HBoxContainer = _row("ui_settings_language", true)
	row.name = "LanguageRow"
	var now: String = SettingsManager.language()
	for opt: Array in [["en", "English"], ["id", "Bahasa Indonesia"]]:
		var code: String = opt[0]
		var b: Button = ProceduralUIFactory.button(str(opt[1]), "primary" if now == code else "secondary")
		b.name = "Lang_" + code
		b.custom_minimum_size = Vector2(150, 48)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(func() -> void:
			if SettingsManager.language() != code:
				SettingsManager.set_value("language", code))
		row.add_child(b)


## Save tunggal (GDD idle 19 no. 21, 20 no. 57, 68): Export Save (kode teks
## untuk perangkat lain), Import Save (kode yang menggantikan toko ini), dan
## Reset Game (mulai dari awal). Hanya saat sebuah toko sedang dimainkan.
func _save_section() -> void:
	if game == null or game.sim == null:
		return
	_body.add_child(ProceduralUIFactory.section_label(Tx.t("ui_settings_save")))
	var ex: Button = _wide_button("clipboard", "ui_save_code_export", "secondary")
	ex.name = "ExportSave"
	ex.pressed.connect(func() -> void:
		# Kodenya memuat keadaan toko saat ini, bukan autosave terakhir.
		SaveManager.save_now()
		host.open(&"save_code", {"profile_id": SaveManager.SAVE_ID}))
	var im: Button = _wide_button("box", "ui_import_save", "secondary")
	im.name = "ImportSave"
	im.pressed.connect(func() -> void: host.open(&"import_save"))
	var rs: Button = _wide_button("cross", "ui_reset_game", "danger")
	rs.name = "ResetGame"
	rs.pressed.connect(func() -> void: host.confirm(Tx.t("ui_reset_confirm"), game.reset_game, true))
	lbl(_body, Tx.t("ui_reset_hint"), 16, Palette.TEXT_MUTED, true)


func _wide_button(icon_name: String, text_key: String, kind: String) -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button(icon_name, Tx.t(text_key), kind, 22, 18)
	b.custom_minimum_size = Vector2(0, 56)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_child(b)
	return b


## Satu baris pengaturan untuk lebar potret (GDD idle 12.0.5): `stacked` menaruh
## label di atas kontrolnya (slider, pilihan); selain itu label mengisi sisa
## lebar dan kontrol di kanan (toggle).
func _row(label_key: String, stacked: bool = false) -> HBoxContainer:
	if stacked:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", 4)
		_body.add_child(v)
		lbl(v, Tx.t(label_key), 18, Palette.TEXT, true)
		var under: HBoxContainer = hbox(v, 10)
		under.custom_minimum_size = Vector2(0, 52)
		return under
	var row: HBoxContainer = hbox(_body, 12)
	row.custom_minimum_size = Vector2(0, 52)
	lbl(row, Tx.t(label_key), 18, Palette.TEXT, true)
	return row


func _slider(key: String, label_key: String, lo: int, hi: int, step: int) -> void:
	var row: HBoxContainer = _row(label_key, true)
	var sl := HSlider.new()
	sl.focus_mode = Control.FOCUS_NONE
	sl.min_value = lo
	sl.max_value = hi
	sl.step = step
	sl.value = SettingsManager.get_int(key)
	sl.custom_minimum_size = Vector2(240, 48)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sl)
	var v: Label = lbl(row, str(SettingsManager.get_int(key)), 18, Palette.UI_WOOD)
	v.custom_minimum_size = Vector2(64, 0)
	sl.value_changed.connect(func(x: float) -> void:
		SettingsManager.set_value(key, int(x))
		v.text = str(SettingsManager.get_int(key)))


func _toggle(key: String, label_key: String) -> void:
	var row: HBoxContainer = _row(label_key)
	var cb: CheckButton = ProceduralUIFactory.toggle(SettingsManager.get_bool(key))
	cb.toggled.connect(func(on: bool) -> void: SettingsManager.set_value(key, on))
	row.add_child(cb)


func _choice(key: String, label_key: String, values: Array, labels: Array) -> void:
	var row: HBoxContainer = _row(label_key, true)
	for i in values.size():
		var val: Variant = values[i]
		var active: bool = str(SettingsManager.get_value(key)) == str(val)
		var b: Button = ProceduralUIFactory.button(str(labels[i]), "primary" if active else "secondary")
		b.custom_minimum_size = Vector2(90, 48)
		b.pressed.connect(func() -> void:
			SettingsManager.set_value(key, val)
			_render())
		row.add_child(b)
