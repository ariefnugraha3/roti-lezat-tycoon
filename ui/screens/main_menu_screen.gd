class_name MainMenuScreen
extends UIScreen
## Main Menu (v3.1 89.2): Continue, New Game, Load Game, Settings, Credits, Exit.
## Muncul tanpa membangun dunia apa pun (v3.1 89.1). Potret (GDD idle 12.0.5),
## di bawah tenda toko latar:
##   - logo roti di sepertiga atas;
##   - kartu toko: profil yang terakhir dimainkan (gambar tokonya, nama, hari,
##     lokasi, saldo) dengan tombol Continue besar; tanpa save, sapaan dan
##     tombol New Game besar;
##   - New Game / Load Game berdampingan;
##   - Settings, Credits, dan Exit sebagai tombol ikon bundar berketerangan.
## Exit tidak ada di Web (v3.1 89.2).

## Puncak logo, sebagai bagian tinggi bingkai (splash memakai yang sama).
const LOGO_TOP: float = 0.075
## Lebar kartu toko dan baris tombol di bawahnya.
const COLUMN_W: float = 580.0
## Sisi tombol ikon bundar di baris bawah.
const ROUND_BUTTON: float = 76.0


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	var back: Control = ProceduralUIFactory.backdrop()
	add_child(back)
	var v := VBoxContainer.new()
	v.name = "Column"
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.anchor_top = LOGO_TOP
	# Di atas taplak gingham dan roti di sudutnya.
	v.offset_bottom = -104.0
	v.add_theme_constant_override("separation", 16)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(v)
	var logo_box := CenterContainer.new()
	logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(logo_box)
	var lockup: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 76, 116)
	logo_box.add_child(lockup)
	ProceduralAnimationSystem.idle_wobble(lockup.get_meta("bread"))
	v.add_child(_spacer(1.0))
	var latest: StringName = SaveManager.latest_profile()
	var col := VBoxContainer.new()
	col.name = "Actions"
	col.custom_minimum_size = Vector2(COLUMN_W, 0.0)
	col.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 14)
	v.add_child(col)
	col.add_child(_hero(latest))
	var row: HBoxContainer = hbox(col, 14)
	row.name = "SaveRow"
	if latest != &"":
		_wide(row, "plus", Tx.t("ui_main_new_game"), "secondary", func() -> void: host.open(&"profiles", {"mode": "new"}))
	_wide(row, "box", Tx.t("ui_main_load"), "secondary", func() -> void: host.open(&"profiles", {"mode": "load"}))
	var round_row: HBoxContainer = hbox(col, 40)
	round_row.name = "RoundRow"
	round_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_round(round_row, "gear", Tx.t("ui_main_settings"), func() -> void: host.open(&"settings"))
	_round(round_row, "note", Tx.t("ui_main_credits"), func() -> void: host.open(&"credits"))
	# Web boleh menyembunyikan Quit (v3.1 89.2).
	if not OS.has_feature("web"):
		_round(round_row, "cross", Tx.t("ui_main_exit"), func() -> void: host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit()))
	v.add_child(_spacer(1.0))
	var ver: Label = lbl(v, "v" + str(ProjectSettings.get_setting("application/config/version", "1.0")), 14, Palette.TEXT_MUTED)
	ver.name = "Version"
	ver.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Kartu toko di tengah menu: profil terakhir + Continue, atau sapaan + New Game.
func _hero(latest: StringName) -> Control:
	var card := PanelContainer.new()
	card.name = "HeroCard"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 28, true)
	sb.set_content_margin_all(18.0)
	card.add_theme_stylebox_override("panel", sb)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	card.add_child(body)
	var top: HBoxContainer = hbox(body, 18)
	var art := ShopFrontArt.new()
	art.name = "HeroShop"
	art.custom_minimum_size = Vector2(124, 124)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	top.add_child(info)
	var h: Dictionary = SaveManager.read_header(latest) if latest != &"" else {}
	if not h.is_empty():
		var ldef: LocationDefinition = DataRegistry.location(StringName(str(h.get("location_id", ""))))
		art.tier = ldef.tier if ldef != null else 1
		var tag_box := HBoxContainer.new()
		info.add_child(tag_box)
		tag_box.add_child(ProceduralUIFactory.pill("shop", Tx.t("ui_main_your_bakery"), Palette.HONEY_SOFT, Palette.UI_WOOD_DEEP, 14))
		var name_l: Label = lbl(info, str(h.get("bakery_name", "")), 26, Palette.UI_WOOD_DEEP)
		name_l.name = "BakeryName"
		name_l.add_theme_font_override("font", ProceduralUIFactory.display_font())
		name_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		name_l.clip_text = true
		name_l.custom_minimum_size = Vector2(100.0, 0.0)
		name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var loc: String = str(h.get("location_id", ""))
		var where: String = Tx.t("ui_profile_day", {"day": h.get("day", 1)})
		if loc != "":
			where += " · " + (Tx.t(loc) if DataRegistry.has_text(loc) else loc)
		lbl(info, where, 16, Palette.TEXT_MUTED, true)
		var money: HBoxContainer = ProceduralUIFactory.icon_value("coin", Tx.kr(float(h.get("balance_kr", 0.0))), 24, 20, Palette.GOLDEN_CRUST)
		(money.get_meta("value") as Label).add_theme_color_override("font_color", Palette.GOLDEN_CRUST)
		info.add_child(money)
		var cont: Button = ProceduralUIFactory.icon_text_button("play", Tx.t("ui_main_continue"), "primary", 30, 24)
		cont.name = "Continue"
		cont.custom_minimum_size.y = 72.0
		cont.pressed.connect(func() -> void: game.load_profile(latest))
		body.add_child(cont)
	else:
		art.tier = 1
		var hi: Label = lbl(info, Tx.t("ui_main_welcome_title"), 24, Palette.UI_WOOD_DEEP, true)
		hi.add_theme_font_override("font", ProceduralUIFactory.display_font())
		lbl(info, Tx.t("ui_main_welcome_body"), 17, Palette.TEXT_MUTED, true)
		var start: Button = ProceduralUIFactory.icon_text_button("plus", Tx.t("ui_main_new_game"), "success", 30, 24)
		start.name = "NewGame"
		start.custom_minimum_size.y = 72.0
		start.pressed.connect(func() -> void: host.open(&"profiles", {"mode": "new"}))
		body.add_child(start)
	return card


## Tombol lebar setengah baris (New Game / Load Game).
func _wide(parent: Control, icon_name: String, text: String, kind: String, cb: Callable) -> Button:
	var b: Button = ProceduralUIFactory.icon_text_button(icon_name, text, kind, 24, 20)
	b.custom_minimum_size.y = 62.0
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


## Tombol ikon bundar dengan keterangan di bawahnya (Settings, Credits, Exit).
func _round(parent: Control, icon_name: String, text: String, cb: Callable) -> Button:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	parent.add_child(v)
	var b: Button = ProceduralUIFactory.icon_button(icon_name, text, "secondary", 32, Palette.UI_WOOD_DEEP)
	b.name = text
	b.custom_minimum_size = Vector2(ROUND_BUTTON, ROUND_BUTTON)
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	v.add_child(b)
	var cap: Label = lbl(v, text, 15, Palette.UI_WOOD_DEEP)
	cap.add_theme_font_override("font", ProceduralUIFactory.display_font())
	cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return b


static func _spacer(weight: float) -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_stretch_ratio = weight
	return s


func on_back() -> bool:
	host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit())
	return true
