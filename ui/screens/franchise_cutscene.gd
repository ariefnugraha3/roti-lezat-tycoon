class_name FranchiseCutscene
extends UIScreen
## Cutscene Waralaba (GDD idle 10.6, mekanisme v3.1 §45): Pak Lurah mengabarkan
## investor membeli toko, lalu papan nama cabang baru. Tombol terakhir menjalankan
## Waralaba lewat GameRoot (reset, simpan, layar loading). Hanya tertutup lewat
## tombolnya sendiri; Back maju satu halaman.

var _page: int = 0
var _box: VBoxContainer = null


func _init() -> void:
	super._init()
	overlay = true
	keep_open = true


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(Palette.UI_CREAM, 0.97)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	m.add_theme_constant_override("margin_left", int(inset.x) + 32)
	m.add_theme_constant_override("margin_right", int(inset.z) + 32)
	m.add_theme_constant_override("margin_top", int(inset.y) + 48)
	m.add_theme_constant_override("margin_bottom", int(inset.w) + 48)
	add_child(m)
	_box = VBoxContainer.new()
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 22)
	m.add_child(_box)
	_show_page()
	EventBus.sfx.emit(&"franchise_jingle", &"")


func page() -> int:
	return _page


func _show_page() -> void:
	clear(_box)
	var stars: int = int(params.get("stars", 0))
	var number: int = int(params.get("number", 2))
	if _page == 0:
		var c := CenterContainer.new()
		_box.add_child(c)
		var lurah := LurahPortrait.new()
		lurah.name = "Lurah"
		lurah.custom_minimum_size = Vector2(220, 220)
		c.add_child(lurah)
		var l: Label = lbl(_box, Tx.t("ui_franchise_cut_1"), 22, Palette.TEXT, true)
		l.name = "Line"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var c2 := CenterContainer.new()
		_box.add_child(c2)
		var h: HBoxContainer = hbox(c2, 10)
		h.add_child(ProceduralUIFactory.icon("star", 48, Palette.SIGN_PURPLE))
		var g: Label = lbl(h, FranchiseScreen.stars_text("ui_franchise_stars_gained", stars), 30, Palette.UI_WOOD_DEEP)
		g.name = "Gained"
		_button(Tx.t("ui_next"), _advance)
	else:
		var sign := Signboard.new()
		sign.name = "Signboard"
		sign.custom_minimum_size = Vector2(520, 300)
		sign.title_text = sim.bakery_name if sim != null else ""
		sign.sub_text = Tx.t("ui_branch_number", {"number": number})
		var c3 := CenterContainer.new()
		_box.add_child(c3)
		c3.add_child(sign)
		var l2: Label = lbl(_box, Tx.t("ui_franchise_cut_2"), 22, Palette.TEXT, true)
		l2.name = "Line"
		l2.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_button(Tx.t("ui_franchise_open", {"number": number}), _finish)


func _button(text: String, cb: Callable) -> void:
	var c := CenterContainer.new()
	_box.add_child(c)
	var b: Button = btn(c, text, "primary", cb)
	b.name = "Continue"
	b.custom_minimum_size = Vector2(300, 64)


func _advance() -> void:
	_page = 1
	_show_page()


func _finish() -> void:
	close()
	if game != null:
		game.do_franchise()


func on_back() -> bool:
	if _page == 0:
		_advance()
	else:
		_finish()
	return true
