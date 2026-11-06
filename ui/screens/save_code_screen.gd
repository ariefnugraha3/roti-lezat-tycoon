class_name SaveCodeScreen
extends UIScreen
## Kode save (GDD idle 15.3, 20 no. 57), dari Export Save di Settings: ringkasan
## toko, potongan kodenya, lalu Copy Code (semua platform) dan, di Web, Download
## File (berkas .txt sebagai cadangan di luar penyimpanan browser). Di perangkat
## lain kode dibuka lewat Import Save.

## Kode lengkap save ini ("" bila save tidak terbaca).
var code: String = ""
var _status: Label = null


func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var pid: StringName = StringName(str(params.get("profile_id", "")))
	code = SaveManager.export_code(pid)
	# Setinggi isinya; teks yang lebih besar mendapat ruang tambahan.
	var extra: float = 300.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)
	var body: VBoxContainer = make_popup(Tx.t("ui_save_code_title"), Vector2(620, 600.0 + extra), true, Palette.SHEET)
	body.add_theme_constant_override("separation", 16)
	var list: VBoxContainer = scroll_box(body)
	list.add_theme_constant_override("separation", 16)
	if code == "":
		lbl(list, Tx.t("ui_save_error"), 18, Palette.DANGER, true)
		return
	var card := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 24, true)
	sb.set_content_margin_all(16.0)
	card.add_theme_stylebox_override("panel", sb)
	card.add_child(SaveSummary.row(SaveManager.read_header(pid), 96.0))
	list.add_child(card)
	lbl(list, Tx.t("ui_save_code_body"), 17, Palette.TEXT, true)
	# Potongan kode dan ukurannya, supaya terlihat apa yang disalin.
	var chip := PanelContainer.new()
	chip.name = "CodePreview"
	var cs: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM_DEEP, 16, false)
	cs.set_content_margin_all(12.0)
	chip.add_theme_stylebox_override("panel", cs)
	list.add_child(chip)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	chip.add_child(row)
	var snip: Label = lbl(row, code.substr(0, 40) + "...", 16, Palette.UI_WOOD_DEEP)
	snip.clip_text = true
	snip.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	snip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	snip.custom_minimum_size = Vector2(80.0, 0.0)
	lbl(row, Tx.t("ui_save_code_size", {"size": "%.1f" % (float(code.length()) / 1024.0)}), 16, Palette.TEXT_MUTED)
	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.add_theme_constant_override("separation", 12)
	body.add_child(buttons)
	var copy: Button = ProceduralUIFactory.icon_text_button("clipboard", Tx.t("ui_save_code_copy"), "primary", 24, 20)
	copy.name = "Copy"
	copy.custom_minimum_size = Vector2(0, 64)
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.pressed.connect(_copy)
	buttons.add_child(copy)
	if WebPlatform.is_web():
		var dl: Button = ProceduralUIFactory.icon_text_button("box", Tx.t("ui_save_code_download"), "secondary", 24, 20)
		dl.name = "Download"
		dl.custom_minimum_size = Vector2(0, 64)
		dl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		dl.pressed.connect(_download.bind(SaveManager.read_header(pid)))
		buttons.add_child(dl)
	_status = lbl(body, "", 16, Palette.MATCHA.darkened(0.35), true)
	_status.name = "Status"
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _copy() -> void:
	if WebPlatform.copy_text(code):
		_status.text = Tx.t("ui_save_code_copied")
		EventBus.sfx.emit(&"ui_confirm", &"")
	else:
		_status.text = Tx.t("ui_save_code_no_clipboard")
		EventBus.sfx.emit(&"ui_error", &"")


func _download(h: Dictionary) -> void:
	var file_name: String = file_name_for(h)
	if WebPlatform.download_text(code, file_name):
		_status.text = Tx.t("ui_save_code_downloaded", {"file": file_name})
		EventBus.sfx.emit(&"ui_confirm", &"")


## Nama berkas cadangan: crumbtown-<nama toko>-day<N>.txt (huruf kecil, angka,
## dan tanda hubung saja).
static func file_name_for(h: Dictionary) -> String:
	var slug: String = ""
	for ch: String in str(h.get("bakery_name", "")).to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			slug += ch
		elif not slug.ends_with("-") and slug != "":
			slug += "-"
	slug = slug.trim_suffix("-")
	if slug == "":
		slug = "bakery"
	return "crumbtown-%s-day%d.txt" % [slug, int(h.get("day", 1))]
