class_name NewGameScreen
extends UIScreen
## Alur New Game (GDD 7, 31.3, 89.4): Penampilan pemain (pria/wanita, murni
## kosmetik) -> Nama toko (1-24 karakter, Unicode boleh) -> Ringkasan -> Start.

var _step: int = 0
var _gender: String = "male"
var _name: String = ""
var _body: VBoxContainer = null
var _error: Label = null
var _edit: LineEdit = null


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	_name = Tx.t("ui_bakery_name_default")
	var bg := ColorRect.new()
	bg.color = Color(Palette.BG, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_body = make_popup(Tx.t("ui_new_game_title"), Vector2(900, 580))
	_render()


func _render() -> void:
	clear(_body)
	match _step:
		0:
			_render_character()
		1:
			_render_name()
		_:
			_render_summary()


func _render_character() -> void:
	lbl(_body, Tx.t("ui_character_title"), 24, Palette.UI_WOOD)
	var row: HBoxContainer = hbox(_body, 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for g: String in ["male", "female"]:
		row.add_child(_char_card(g))
	lbl(_body, Tx.t("ui_character_note"), 16, Palette.TEXT_MUTED, true)
	var nav: HBoxContainer = hbox(_body, 16)
	nav.alignment = BoxContainer.ALIGNMENT_END
	btn(nav, Tx.t("ui_back"), "secondary", on_back)
	btn(nav, Tx.t("ui_next"), "primary", func() -> void:
		_step = 1
		_render())


func _char_card(g: String) -> Control:
	var selected: bool = g == _gender
	var card: PanelContainer = ProceduralUIFactory.card("")
	card.custom_minimum_size = Vector2(260, 300)
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL_ALT, 22, true)
	if selected:
		sb.border_color = Palette.GOLD_STAR
		sb.set_border_width_all(5)
	card.add_theme_stylebox_override("panel", sb)
	var body: VBoxContainer = ProceduralUIFactory.content_of(card)
	var portrait := ProceduralUIFactory.ChibiPortrait.new()
	portrait.custom_minimum_size = Vector2(220, 200)
	var visual: Dictionary = {"skin": "#f2c9a0", "hair": "#2b2118", "hair_style": "pendek", "hat": "topi_koki", "chubby": 0.18, "apron": "#4a3226"}
	if g == "female":
		visual = {"skin": "#fad9bc", "hair": "#4a3121", "hair_style": "panjang_kepang", "hat": "bandana", "chubby": 0.1, "apron": "#ffcba4"}
	portrait.configure(visual, "baker", 1)
	body.add_child(portrait)
	var b: Button = btn(body, Tx.t("ui_character_male") if g == "male" else Tx.t("ui_character_female"), "primary" if selected else "secondary", func() -> void:
		_gender = g
		_render())
	b.custom_minimum_size = Vector2(200, 56)
	return card


func _render_name() -> void:
	lbl(_body, Tx.t("ui_bakery_name_title"), 24, Palette.UI_WOOD)
	_edit = LineEdit.new()
	_edit.text = _name
	_edit.max_length = 64
	_edit.custom_minimum_size = Vector2(0, 56)
	_edit.add_theme_font_size_override("font_size", ProceduralUIFactory.scaled(22))
	_edit.placeholder_text = Tx.t("ui_bakery_name_default")
	_body.add_child(_edit)
	lbl(_body, Tx.t("ui_bakery_name_hint"), 16, Palette.TEXT_MUTED)
	_error = lbl(_body, "", 16, Palette.DANGER, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var nav: HBoxContainer = hbox(_body, 16)
	nav.alignment = BoxContainer.ALIGNMENT_END
	btn(nav, Tx.t("ui_back"), "secondary", func() -> void:
		_step = 0
		_render())
	btn(nav, Tx.t("ui_next"), "primary", _accept_name)


## Aturan nama (GDD 89.4): 1-24 karakter terlihat setelah trim, tanpa karakter
## kontrol/baris baru.
static func validate_name(text: String) -> String:
	var t: String = text.strip_edges()
	if t.length() < 1 or t.length() > 24:
		return ""
	for i in t.length():
		var code: int = t.unicode_at(i)
		if code < 32 or code == 127:
			return ""
	return t


func _accept_name() -> void:
	var v: String = validate_name(_edit.text)
	if v == "":
		_error.text = Tx.t("ui_bakery_name_invalid")
		EventBus.sfx.emit(&"ui_error", &"")
		return
	_name = v
	_step = 2
	_render()


func _render_summary() -> void:
	lbl(_body, Tx.t("ui_new_game_summary", {"bakery": _name}), 26, Palette.UI_WOOD, true)
	var pid: StringName = StringName(str(params.get("profile_id", "profile_1")))
	var n: String = String(pid).replace("profile_", "")
	lbl(_body, Tx.t("ui_new_game_summary_detail", {"n": n, "character": Tx.t("ui_character_male") if _gender == "male" else Tx.t("ui_character_female"),
		"cash": Tx.kr(DataRegistry.balf("economy.starting_cash_kr"))}), 18, Palette.TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var nav: HBoxContainer = hbox(_body, 16)
	nav.alignment = BoxContainer.ALIGNMENT_END
	btn(nav, Tx.t("ui_back"), "secondary", func() -> void:
		_step = 1
		_render())
	btn(nav, Tx.t("ui_start"), "primary", func() -> void:
		close()
		game.start_new_game(pid, _gender, _name))


func on_back() -> bool:
	if _step > 0:
		_step -= 1
		_render()
		return true
	close()
	host.open(&"profiles", {"mode": "new"})
	return true
