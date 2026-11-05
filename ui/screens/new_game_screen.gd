class_name NewGameScreen
extends UIScreen
## Alur New Game (GDD 7, 31.3, 89.4): Penampilan pemain (pria/wanita, murni
## kosmetik) -> Nama toko (1-24 karakter, Unicode boleh) -> Ringkasan -> Start.
## Di atas setiap langkah ada tiga bulatan langkah (selesai = centang hijau,
## sekarang = madu). Langkah nama menampilkan gambar toko dengan papan nama
## yang ikut berubah saat pemain mengetik; ringkasan menampilkan juru roti dan
## tokonya berdampingan.

const STEPS: int = 3
const POPUP: Vector2 = Vector2(640, 680)

var _step: int = 0
var _gender: String = "male"
var _name: String = ""
var _body: VBoxContainer = null
var _error: Label = null
var _edit: LineEdit = null
var _sign: Label = null


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	_name = Tx.t("ui_bakery_name_default")
	_body = make_popup(Tx.t("ui_new_game_title"), POPUP)
	_render()


func _render() -> void:
	clear(_body)
	_body.add_child(_steps_row())
	match _step:
		0:
			_render_character()
		1:
			_render_name()
		_:
			_render_summary()


## Tiga bulatan langkah bernomor yang disambung garis pendek.
func _steps_row() -> Control:
	var c := CenterContainer.new()
	c.name = "Steps"
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	c.add_child(row)
	for i in STEPS:
		if i > 0:
			var bar := ColorRect.new()
			bar.custom_minimum_size = Vector2(44, 6)
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			bar.color = Palette.MATCHA if i <= _step else Palette.UI_CREAM_DEEP
			row.add_child(bar)
		var face: Color = Palette.MATCHA if i < _step else (Palette.HONEY if i == _step else Palette.UI_CREAM_DEEP)
		var dot := PanelContainer.new()
		dot.custom_minimum_size = Vector2(40, 40)
		var sb: StyleBoxFlat = ProceduralUIFactory.panel(face, 20, false)
		sb.set_content_margin_all(0.0)
		dot.add_theme_stylebox_override("panel", sb)
		row.add_child(dot)
		if i < _step:
			var cc := CenterContainer.new()
			cc.add_child(ProceduralUIFactory.icon("check", 24, Palette.FLOUR_WHITE))
			dot.add_child(cc)
		else:
			var n: Label = ProceduralUIFactory.label(str(i + 1), 20, Palette.FLOUR_WHITE if i == _step else Palette.TEXT_MUTED)
			n.add_theme_font_override("font", ProceduralUIFactory.display_font())
			n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			n.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			dot.add_child(n)
	return c


func _heading(text: String) -> Label:
	var l: Label = lbl(_body, text, 26, Palette.UI_WOOD_DEEP, true)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _render_character() -> void:
	_heading(Tx.t("ui_character_title"))
	var row: HBoxContainer = hbox(_body, 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	for g: String in ["male", "female"]:
		row.add_child(_char_card(g))
	var note: Label = lbl(_body, Tx.t("ui_character_note"), 16, Palette.TEXT_MUTED, true)
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nav(on_back, Tx.t("ui_next"), _go.bind(1))


func _char_card(g: String) -> Control:
	var selected: bool = g == _gender
	var card := PanelContainer.new()
	card.name = "Card_" + g
	card.custom_minimum_size = Vector2(250, 0)
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.HONEY_SOFT if selected else Palette.CARD, 24, true)
	sb.set_content_margin_all(12.0)
	card.add_theme_stylebox_override("panel", sb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	card.add_child(body)
	var portrait := ProceduralUIFactory.ChibiPortrait.new()
	portrait.custom_minimum_size = Vector2(220, 210)
	portrait.configure(portrait_visual(g), "baker", 1)
	body.add_child(portrait)
	var b: Button = btn(body, Tx.t("ui_character_male") if g == "male" else Tx.t("ui_character_female"), "primary" if selected else "secondary", func() -> void:
		_gender = g
		_render())
	b.custom_minimum_size = Vector2(200, 56)
	# Tanda pilihan: lencana centang hijau di sudut kanan atas potret.
	if selected:
		var mark: PanelContainer = ProceduralUIFactory.badge("check", Palette.MATCHA, Palette.FLOUR_WHITE, 44)
		mark.name = "Picked"
		mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		portrait.add_child(mark)
		mark.position = Vector2(portrait.custom_minimum_size.x - 48.0, 4.0)
	return card


## Tampilan potret pemilik (sama dengan model 3D-nya,
## CharacterFactory.spec_for_player), di atas latar pastel masing-masing.
static func portrait_visual(g: String) -> Dictionary:
	if g == "female":
		return {"skin": "#fad9bc", "hair": "#4a3121", "hair_style": "panjang_kepang", "hat": "bandana", "chubby": 0.1,
			"apron": "#ffcba4", "lashes": true, "backdrop": "#ffd9d3"}
	return {"skin": "#f2c9a0", "hair": "#2b2118", "hair_style": "pendek", "hat": "topi_koki", "chubby": 0.18,
		"apron": "#4a3226", "lashes": false, "backdrop": "#cfe9dc"}


func _render_name() -> void:
	_heading(Tx.t("ui_bakery_name_title"))
	# Gambar toko dengan papan nama yang ikut berubah saat mengetik.
	var art_box := CenterContainer.new()
	_body.add_child(art_box)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", -14)
	art_box.add_child(stack)
	var art := ShopFrontArt.new()
	art.name = "NameShop"
	art.tier = 1
	art.custom_minimum_size = Vector2(190, 190)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	stack.add_child(art)
	var plate := PanelContainer.new()
	plate.name = "SignPreview"
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var psb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARAMEL, 16, false)
	psb.content_margin_left = 22.0
	psb.content_margin_right = 22.0
	psb.content_margin_top = 6.0
	psb.content_margin_bottom = 8.0
	plate.add_theme_stylebox_override("panel", psb)
	stack.add_child(plate)
	_sign = ProceduralUIFactory.label(_name, 22, Palette.BUTTER_YELLOW)
	_sign.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_sign.custom_minimum_size = Vector2(minf(ProceduralUIFactory._text_width(_name, 22, true) + 8.0, 480.0), 0.0)
	plate.add_child(_sign)
	_edit = LineEdit.new()
	_edit.text = _name
	_edit.max_length = 64
	_edit.custom_minimum_size = Vector2(0, 60)
	_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	_edit.add_theme_font_size_override("font_size", ProceduralUIFactory.scaled(22))
	_edit.placeholder_text = Tx.t("ui_bakery_name_default")
	_edit.text_changed.connect(_on_typed)
	_edit.text_submitted.connect(func(_t: String) -> void: _accept_name())
	_body.add_child(_edit)
	var hint: Label = lbl(_body, Tx.t("ui_bakery_name_hint"), 16, Palette.TEXT_MUTED)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_error = lbl(_body, "", 16, Palette.DANGER, true)
	_error.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_nav(_go.bind(0), Tx.t("ui_next"), _accept_name)


## Papan nama pratinjau mengikuti ketikan (nama kosong = nama bawaan pudar).
func _on_typed(text: String) -> void:
	if _sign == null:
		return
	var t: String = text.strip_edges()
	_sign.text = t if t != "" else Tx.t("ui_bakery_name_default")
	_sign.modulate.a = 1.0 if t != "" else 0.5
	_sign.custom_minimum_size.x = minf(ProceduralUIFactory._text_width(_sign.text, 22, true) + 8.0, 480.0)
	_error.text = ""


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
	_heading(Tx.t("ui_new_game_summary", {"bakery": _name}))
	var pid: StringName = StringName(str(params.get("profile_id", "profile_1")))
	var n: String = String(pid).replace("profile_", "")
	# Juru roti dan tokonya berdampingan.
	var pics: HBoxContainer = hbox(_body, 18)
	pics.alignment = BoxContainer.ALIGNMENT_CENTER
	var portrait := ProceduralUIFactory.ChibiPortrait.new()
	portrait.custom_minimum_size = Vector2(170, 170)
	portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	portrait.configure(portrait_visual(_gender), "baker", 1)
	pics.add_child(portrait)
	var art := ShopFrontArt.new()
	art.tier = 1
	art.custom_minimum_size = Vector2(170, 170)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	pics.add_child(art)
	# Rincian dalam kartu: profil, juru roti, dan modal awal.
	var card := PanelContainer.new()
	card.name = "Details"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 22, true)
	sb.set_content_margin_all(16.0)
	card.add_theme_stylebox_override("panel", sb)
	_body.add_child(card)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 10)
	card.add_child(rows)
	var character: String = Tx.t("ui_character_male") if _gender == "male" else Tx.t("ui_character_female")
	_detail(rows, "box", Tx.t("ui_new_game_profile", {"n": n}), Palette.UI_WOOD)
	_detail(rows, "chef", Tx.t("ui_new_game_baker", {"character": character}), Palette.UI_WOOD)
	_detail(rows, "coin", Tx.t("ui_new_game_cash", {"cash": Tx.kr(DataRegistry.idlef("start_kr"))}), Palette.GOLDEN_CRUST)
	_nav(_go.bind(1), Tx.t("ui_start"), func() -> void:
		close()
		game.start_new_game(pid, _gender, _name))


func _detail(parent: Control, icon_name: String, text: String, tint: Color) -> void:
	var h: HBoxContainer = hbox(parent, 12)
	h.add_child(ProceduralUIFactory.icon(icon_name, 28, tint))
	var l: Label = lbl(h, text, 19, Palette.TEXT, true)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())


func _go(step: int) -> void:
	_step = step
	_render()


## Baris bawah: Back di kiri, langkah berikutnya (primary) di kanan.
func _nav(back_cb: Callable, next_text: String, next_cb: Callable) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var nav: HBoxContainer = hbox(_body, 16)
	var b: Button = btn(nav, Tx.t("ui_back"), "secondary", back_cb)
	b.custom_minimum_size.y = 60.0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.size_flags_stretch_ratio = 0.7
	var nx: Button = btn(nav, next_text, "success" if _step == STEPS - 1 else "primary", next_cb)
	nx.custom_minimum_size.y = 60.0
	nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func on_back() -> bool:
	if _step > 0:
		_step -= 1
		_render()
		return true
	close()
	host.open(&"profiles", {"mode": "new"})
	return true
