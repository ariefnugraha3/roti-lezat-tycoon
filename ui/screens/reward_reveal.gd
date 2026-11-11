class_name RewardReveal
extends UIScreen
## Perayaan barang baru dari Store (GDD idle 22.11). Lapisan overlay di atas
## Store atau Decoration Mode, dibuka sesudah pembelian berhasil:
##   params.deco     dekorasi, pakaian, atau kanopi baru (Style, Pass, paket);
##   params.product  produk toko (No Ads, Golden Oven, Night Manager, Baker's
##                   Club, Bakery Pass Premium, paket). Paket yang berisi barang
##                   menampilkan barangnya di panggung.
##   params.in_decor true = dibuka dari Decoration Mode (barangnya sudah diangkat).
##
## Urutan (game-feel: berlapis, berlebihan sebentar, lalu kembali tenang):
## latar meredup; sinar matahari keemasan membesar lalu berputar pelan; barang
## (model 3D berputar di ItemStage, atau lencana besar untuk produk) meletup
## masuk dengan overshoot dan squash & stretch; fanfare, confetti, dan ledakan
## kilau; pita judul jatuh; nama, keterangan, dan tombol muncul berurutan;
## kelip terus berkedip di sekitar barang. Reduce motion: semua langsung tampil
## tanpa gerak dan tanpa partikel. Ketuk di luar tombol menutupnya sesudah
## TAP_AFTER detik.

const TAP_AFTER: float = 0.7
const STAGE_PX: int = 340
const STAGE_BOX: float = 440.0

var _shade: ColorRect = null
var _col: VBoxContainer = null
var _burst: Sunburst = null
var _stage_box: Control = null
var _hero: Control = null
var _badge: bool = false
var _ribbon: Control = null
var _name: Label = null
var _lines: VBoxContainer = null
var _buttons: HBoxContainer = null
var _motion: bool = true
var _age: float = 0.0
var _closing: bool = false
var _item: MiscDefinitions.DecorationDefinition = null
var _product: Dictionary = {}
var _holding_toasts: bool = false

## Latar peredup: cokelat sangat gelap, supaya barangnya menjadi satu-satunya fokus.
const SHADE: Color = Color(0.12, 0.07, 0.04)
const SHADE_ALPHA: float = 0.88


func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	_motion = not SettingsManager.reduced_motion()
	var deco: StringName = StringName(str(params.get("deco", "")))
	_product = PremiumManager.product(StringName(str(params.get("product", ""))))
	_item = DataRegistry.decoration(deco) if deco != &"" else null
	# Paket yang berisi barang: barangnya menjadi bintang panggung.
	if _item == null and str(_product.get("decor", "")) != "":
		_item = DataRegistry.decoration(StringName(str(_product["decor"])))
	_shade = ColorRect.new()
	_shade.name = "Shade"
	_shade.color = Color(SHADE, 0.0)
	_shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_shade.mouse_filter = Control.MOUSE_FILTER_STOP
	_shade.gui_input.connect(_on_shade_input)
	add_child(_shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_col = VBoxContainer.new()
	_col.name = "Column"
	_col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_col.add_theme_constant_override("separation", 12)
	_col.custom_minimum_size = Vector2(minf(620.0, get_viewport_rect().size.x - 40.0) if is_inside_tree() else 620.0, 0.0)
	_col.modulate.a = 0.0
	center.add_child(_col)
	_ribbon = ProceduralUIFactory.ribbon_plate(_title(), 30, 600.0)
	_ribbon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(_ribbon)
	_stage_box = Control.new()
	_stage_box.name = "StageBox"
	_stage_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.custom_minimum_size = Vector2(STAGE_BOX, STAGE_BOX)
	_stage_box.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_col.add_child(_stage_box)
	_burst = Sunburst.new()
	_burst.name = "Sunburst"
	_burst.set_anchors_preset(Control.PRESET_FULL_RECT)
	_burst.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_burst.tint = Palette.GOLD_STAR if _item != null else _face()
	_stage_box.add_child(_burst)
	var hero_wrap := CenterContainer.new()
	hero_wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
	hero_wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_stage_box.add_child(hero_wrap)
	var stage: ItemStage = ItemStage.for_item(_item, sim, STAGE_PX) if _item != null else null
	if stage != null:
		stage.name = "ItemStage"
		stage.motion = _motion
		_hero = stage
	else:
		_badge = true
		_hero = ProceduralUIFactory.badge(_icon(), _face(), Palette.FLOUR_WHITE, 230)
		_hero.name = "HeroBadge"
	hero_wrap.add_child(_hero)
	_name = ProceduralUIFactory.label(_name_text(), 30, Palette.FLOUR_WHITE)
	_name.name = "ItemName"
	_name.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(_name)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.add_theme_constant_override("separation", 4)
	_col.add_child(_lines)
	for line: String in _line_texts():
		var l: Label = ProceduralUIFactory.label(line, 18, Palette.UI_CREAM)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_lines.add_child(l)
	_buttons = HBoxContainer.new()
	_buttons.name = "Buttons"
	_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_buttons.add_theme_constant_override("separation", 16)
	_col.add_child(_buttons)
	if _item != null and _item.is_placeable() and not bool(params.get("in_decor", false)):
		var place: Button = ProceduralUIFactory.icon_text_button("frame", Tx.t("ui_reveal_place"), "secondary", 22, 18)
		place.name = "Place"
		place.custom_minimum_size = Vector2(200, 60)
		place.pressed.connect(_place)
		_buttons.add_child(place)
	var ok: Button = ProceduralUIFactory.button(Tx.t("ui_reveal_ok"), "primary")
	ok.name = "Ok"
	ok.custom_minimum_size = Vector2(220, 60)
	ok.pressed.connect(_finish)
	_buttons.add_child(ok)
	if game != null and game.hud != null:
		game.hud.hold_toasts(true)
		_holding_toasts = true
	_play.call_deferred()


# ===========================================================================
# ISI
# ===========================================================================

func _title() -> String:
	if not _product.is_empty():
		return Tx.t("ui_reveal_" + str(_product["kind"]))
	if _item == null:
		return Tx.t("ui_reveal_decor")
	match _item.placement_type:
		&"outfit":
			return Tx.t("ui_reveal_outfit")
		&"skin":
			return Tx.t("ui_reveal_storefront")
	return Tx.t("ui_reveal_decor")


func _name_text() -> String:
	if not _product.is_empty():
		return TestPurchaseScreen.product_title(_product)
	return Tx.t(String(_item.localization_key)) if _item != null else ""


func _line_texts() -> PackedStringArray:
	var out := PackedStringArray()
	if not _product.is_empty():
		match str(_product["kind"]):
			"offer":
				for c: String in StoreScreen.contents(_product):
					out.append("• " + c)
			"income":
				out.append(Tx.t("ui_store_income_desc", {"mult": Tx.mult(float(_product["income_mult"]))}))
			"offline":
				out.append(Tx.t("ui_store_offline_desc", {"hours": Tx.mult(float(_product["offline_hours"]))}))
			"no_ads":
				out.append(Tx.t("ui_store_no_ads_desc"))
			"club":
				out.append(Tx.t("ui_club_income", {"mult": Tx.mult(float(_product["income_mult"]))}))
				out.append(Tx.t("ui_club_ads"))
				out.append(Tx.t("ui_club_daily", {"n": int(_product["daily_crumbs"])}))
			"pass":
				out.append(Tx.t("ui_reveal_pass_line"))
		return out
	if _item == null:
		return out
	match _item.placement_type:
		&"outfit":
			out.append(Tx.t("ui_reveal_outfit_line"))
		&"skin":
			out.append(Tx.t("ui_reveal_storefront_line"))
		_:
			if _item.has_bonus():
				out.append(Tx.t("ui_reveal_bonus_line", {"bonus": DecorationScreen._bonus_text(_item)}))
			out.append(Tx.t("ui_reveal_decor_line_held") if bool(params.get("in_decor", false)) else Tx.t("ui_reveal_decor_line"))
	return out


## Ikon dan warna lencana produk tanpa barang.
func _icon() -> String:
	return {"no_ads": "heart", "income": "fire", "offline": "moon", "club": "crown", "pass": "ticket", "offer": "gift"}.get(str(_product.get("kind", "")), "gift")


func _face() -> Color:
	return {"no_ads": Palette.STRAWBERRY, "income": Palette.HONEY, "offline": Palette.APRON_NAVY, "club": Palette.SIGN_PURPLE,
		"pass": Palette.SIGN_PURPLE, "offer": Palette.STRAWBERRY}.get(str(_product.get("kind", "")), Palette.HONEY)


# ===========================================================================
# ANIMASI
# ===========================================================================

func _play() -> void:
	if not is_inside_tree():
		return
	# Satu frame tata letak dulu supaya titik pusat skala benar.
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_col.modulate.a = 1.0
	for c: Control in [_hero, _burst, _ribbon, _name, _buttons, _lines]:
		c.pivot_offset = c.size * 0.5
	EventBus.sfx.emit(&"milestone_fanfare", &"")
	if not _motion:
		_shade.color.a = SHADE_ALPHA
		return
	_hero.scale = Vector2(0.12, 0.12)
	_hero.rotation = -0.35
	_burst.scale = Vector2(0.35, 0.35)
	_burst.modulate.a = 0.0
	_ribbon.scale = Vector2(0.5, 0.5)
	_ribbon.modulate.a = 0.0
	for c2: Control in [_name, _lines, _buttons]:
		c2.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(_shade, "color:a", SHADE_ALPHA, 0.25)
	tw.parallel().tween_property(_burst, "modulate:a", 1.0, 0.45)
	tw.parallel().tween_property(_burst, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Barang meletup: membesar melewati ukurannya, memipih, memanjang, lalu diam.
	var pop := create_tween()
	pop.tween_interval(0.1)
	pop.tween_property(_hero, "scale", Vector2(1.16, 1.16), 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.parallel().tween_property(_hero, "rotation", 0.06, 0.34).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	pop.tween_callback(_burst_fx)
	pop.tween_property(_hero, "scale", Vector2(1.08, 0.9), 0.09).set_trans(Tween.TRANS_SINE)
	pop.parallel().tween_property(_hero, "rotation", 0.0, 0.2).set_trans(Tween.TRANS_SINE)
	pop.tween_property(_hero, "scale", Vector2(0.95, 1.06), 0.1).set_trans(Tween.TRANS_SINE)
	pop.tween_property(_hero, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	# Pita judul jatuh, lalu nama, keterangan, dan tombol menyusul.
	var rib := create_tween()
	rib.tween_interval(0.32)
	rib.tween_property(_ribbon, "modulate:a", 1.0, 0.18)
	rib.parallel().tween_property(_ribbon, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var txt := create_tween()
	txt.tween_interval(0.5)
	txt.tween_property(_name, "modulate:a", 1.0, 0.25)
	txt.tween_property(_lines, "modulate:a", 1.0, 0.25)
	txt.tween_property(_buttons, "modulate:a", 1.0, 0.2)


## Confetti, kilau, dan kelip sesaat setelah barang muncul.
func _burst_fx() -> void:
	if not is_inside_tree() or _stage_box == null:
		return
	var mid: Vector2 = _stage_box.size * 0.5
	StoreFX.confetti(_stage_box, mid + Vector2(0.0, 40.0), 80, 1.0)
	StoreFX.sparkle_burst(_stage_box, mid, 28, 230.0, _burst.tint)
	StoreFX.twinkles(_stage_box, mid, STAGE_BOX * 0.4)


func _process(delta: float) -> void:
	_age += delta
	if not _motion or _burst == null:
		return
	_burst.angle += delta * 0.35
	_burst.queue_redraw()
	# Lencana produk bergoyang pelan (model 3D sudah berputar sendiri).
	if _badge and _hero != null and _age > 1.2:
		_hero.rotation = 0.05 * sin(_age * 1.8)


# ===========================================================================
# TUTUP
# ===========================================================================

func _on_shade_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and (e as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT \
			and not (e as InputEventMouseButton).pressed and _age >= TAP_AFTER:
		_finish()


func on_back() -> bool:
	_finish()
	return true


func on_closed() -> void:
	if _holding_toasts and game != null and game.hud != null and is_instance_valid(game.hud):
		game.hud.hold_toasts(false)
	_holding_toasts = false
	super.on_closed()


## Tutup dengan memudar singkat (langsung bila Reduce motion).
func _finish() -> void:
	if _closing:
		return
	_closing = true
	if not _motion or not is_inside_tree():
		close()
		return
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.16)
	tw.tween_callback(close)


## Pasang sekarang: buka Decoration Mode dengan barang ini di tangan.
func _place() -> void:
	var g: GameRoot = game
	var id: StringName = _item.id if _item != null else &""
	_closing = true
	close()
	if g != null and id != &"":
		g.place_decoration(id)


## Tes: animasi sedang berjalan atau sudah selesai, dan barangnya.
func hero() -> Control:
	return _hero


# ===========================================================================
# SINAR MATAHARI
# ===========================================================================

## Sinar keemasan di belakang barang: lingkaran cahaya lembut dan sinar
## segitiga yang berputar pelan. Flat, poligon anti-alias (GDD 130.6).
class Sunburst:
	extends Control
	const RAYS: int = 16
	var tint: Color = Palette.GOLD_STAR
	var angle: float = 0.0

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5
		for i in 5:
			draw_circle(c, r * (0.62 - 0.1 * float(i)), Color(tint, 0.07 + 0.05 * float(i)), true, -1.0, true)
		var half: float = TAU / float(RAYS) * 0.26
		for k in RAYS:
			var a: float = angle + TAU * float(k) / float(RAYS)
			var reach: float = r * (1.0 if k % 2 == 0 else 0.82)
			var pts := PackedVector2Array([c + Vector2(cos(a), sin(a)) * r * 0.18,
				c + Vector2(cos(a - half), sin(a - half)) * reach, c + Vector2(cos(a + half), sin(a + half)) * reach])
			ProceduralUIFactory.fill_aa(self, pts, Color(tint, 0.2 if k % 2 == 0 else 0.13))
