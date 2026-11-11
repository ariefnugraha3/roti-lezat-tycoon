class_name NewGameScreen
extends UIScreen
## Toko baru (GDD 7, 31.3, 89.4; idle 19 no. 21): muncul sekali, pada permainan
## pertama (install baru atau Reset Game), di atas latar layar pembuka. Dua
## langkah: penampilan pemain (pria/wanita, murni kosmetik), lalu nama toko
## (1-24 karakter, Unicode boleh) dan Start. Tidak ada Main Menu untuk kembali,
## jadi langkah pertama tidak punya Back dan popup ini tidak bisa ditutup. Di
## atas setiap langkah ada bulatan langkah (selesai = centang hijau, sekarang =
## madu). Langkah nama menampilkan gambar toko dengan papan nama yang ikut
## berubah saat pemain mengetik.

const STEPS: int = 2
const POPUP: Vector2 = Vector2(640, 680)
## Nama toko paling panjang (GDD 89.4) dan lebar papan pratinjaunya.
const NAME_MAX: int = 24
const SIGN_MAX_W: float = 480.0

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
	keep_open = true


func build() -> void:
	# Latar = adegan halaman start tanpa logo dan tombol (Seksi 20 no. 105),
	# jadi "Tap to Start" bersambung mulus ke popup ini.
	var scene := StartScene.new()
	scene.show_front = false
	add_child(scene)
	_name = Tx.t("ui_bakery_name_default")
	_body = make_popup(Tx.t("ui_new_bakery_title"), POPUP, false)
	_render()


func _render() -> void:
	clear(_body)
	_body.add_child(_steps_row())
	if _step == 0:
		_render_character()
	else:
		_render_name()


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
	_nav(Callable(), Tx.t("ui_next"), _go.bind(1))


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
	_sign.name = "SignName"
	_sign.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_fit_sign()
	plate.add_child(_sign)
	_edit = LineEdit.new()
	_edit.text = _name
	# Aturan nama: paling banyak NAME_MAX karakter (validate_name).
	_edit.max_length = NAME_MAX
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
	_nav(_go.bind(0), Tx.t("ui_start"), _accept_name)


## Papan nama pratinjau mengikuti ketikan (nama kosong = nama bawaan pudar).
func _on_typed(text: String) -> void:
	if _sign == null:
		return
	var t: String = text.strip_edges()
	_sign.text = t if t != "" else Tx.t("ui_bakery_name_default")
	_sign.modulate.a = 1.0 if t != "" else 0.5
	_fit_sign()
	_error.text = ""


## Papan pratinjau selebar namanya; nama yang lebih lebar dari SIGN_MAX_W
## hurufnya mengecil supaya tetap terbaca utuh (Seksi 20 no. 103).
func _fit_sign() -> void:
	var f: Font = ProceduralUIFactory.display_font()
	var sz: int = ProceduralUIFactory.fit_font_size(f, _sign.text, ProceduralUIFactory.scaled(22), SIGN_MAX_W - 8.0)
	_sign.add_theme_font_size_override("font_size", sz)
	_sign.custom_minimum_size.x = minf(f.get_string_size(_sign.text, HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x + 8.0, SIGN_MAX_W)


## Aturan nama (GDD 89.4): 1-24 karakter terlihat setelah trim, tanpa karakter
## kontrol/baris baru.
static func validate_name(text: String) -> String:
	var t: String = text.strip_edges()
	if t.length() < 1 or t.length() > NAME_MAX:
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
	var g: GameRoot = game
	close()
	g.start_new_game(SaveManager.SAVE_ID, _gender, _name)


func _go(step: int) -> void:
	_step = step
	_render()


## Baris bawah: Back di kiri (tidak ada di langkah pertama), langkah
## berikutnya (primary, Start = success) di kanan.
func _nav(back_cb: Callable, next_text: String, next_cb: Callable) -> void:
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_body.add_child(spacer)
	var nav: HBoxContainer = hbox(_body, 16)
	if back_cb.is_valid():
		var b: Button = btn(nav, Tx.t("ui_back"), "secondary", back_cb)
		b.custom_minimum_size.y = 60.0
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.size_flags_stretch_ratio = 0.7
	var nx: Button = btn(nav, next_text, "success" if _step == STEPS - 1 else "primary", next_cb)
	nx.name = "Next"
	nx.custom_minimum_size.y = 60.0
	nx.size_flags_horizontal = Control.SIZE_EXPAND_FILL


## Back/Escape: langkah nama kembali ke pemilihan juru roti; di langkah pertama
## Back keluar dari game (dengan konfirmasi), kecuali di Web.
func on_back() -> bool:
	if _step > 0:
		_step -= 1
		_render()
	elif not OS.has_feature("web"):
		host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit())
	return true
