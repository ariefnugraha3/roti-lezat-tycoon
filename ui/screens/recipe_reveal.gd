class_name RecipeReveal
extends UIScreen
## Sorotan resep baru (GDD idle §20 no. 73): setelah Unlock di lembar Menu, latar
## meredup, sinar berputar di belakang gambar roti resepnya yang melompat masuk
## dengan bintang berkelip, dan kartu berpita "New on the menu!" menyebut nama
## dan harga jualnya, diiringi fanfare. Sesudah HOLD_SECONDS (atau ketukan),
## rotinya terbang mengecil ke tombol tab Menu yang lalu memantul, dan layar ini
## tertutup sendiri.
##
## Lapisan sistem (overlay) yang tidak memblokir: lembar Menu di bawahnya tetap
## terbuka dan toko tidak di-pause. Reduced Motion: tanpa putaran, pantulan, dan
## terbang; hanya muncul dan memudar. Params: {recipe}.

const HOLD_SECONDS: float = 2.4
const EXIT_SECONDS: float = 0.45
## Ketukan baru menutup sorotan setelah ia sempat terlihat sebentar.
const TAP_AFTER: float = 0.35
const BURST_SIZE: float = 560.0
const ART_SIZE: float = 220.0
const STAR_SPOTS: Array[Vector3] = [Vector3(-170.0, -110.0, 40.0), Vector3(175.0, -95.0, 34.0), Vector3(-150.0, 95.0, 30.0),
	Vector3(160.0, 110.0, 42.0), Vector3(-30.0, -175.0, 28.0), Vector3(40.0, 165.0, 26.0)]

var recipe_id: StringName = &""
var _t: float = 0.0
var _leaving: bool = false
var _center: Vector2 = Vector2.ZERO
var _back: ColorRect = null
var _burst: Control = null
var _art: BreadArt = null
var _card: Control = null
var _stars: Array[Control] = []


func _init() -> void:
	super._init()
	overlay = true
	blocking = false
	mouse_filter = Control.MOUSE_FILTER_STOP


func build() -> void:
	recipe_id = StringName(str(params.get("recipe", "recipe_plain_loaf")))
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	var vp: Vector2 = get_viewport_rect().size
	_center = Vector2(vp.x * 0.5, vp.y * 0.4)
	var calm: bool = SettingsManager.reduced_motion()
	_back = ColorRect.new()
	_back.name = "Dim"
	_back.color = Color(Palette.UI_WOOD_DEEP, 0.0)
	_back.set_anchors_preset(Control.PRESET_FULL_RECT)
	_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_back)
	_burst = RevealBurst.new()
	_burst.name = "Burst"
	_burst.size = Vector2(BURST_SIZE, BURST_SIZE)
	_burst.position = _center - _burst.size * 0.5
	_burst.pivot_offset = _burst.size * 0.5
	add_child(_burst)
	for i in STAR_SPOTS.size():
		var spot: Vector3 = STAR_SPOTS[i]
		var st: IconCanvas = ProceduralUIFactory.icon("star", int(spot.z), Palette.BUTTER_YELLOW if i % 2 == 0 else Palette.FLOUR_WHITE)
		st.mouse_filter = Control.MOUSE_FILTER_IGNORE
		st.position = _center + Vector2(spot.x, spot.y) - Vector2(spot.z, spot.z) * 0.5
		st.pivot_offset = Vector2(spot.z, spot.z) * 0.5
		add_child(st)
		_stars.append(st)
	_art = BreadArt.for_recipe(recipe_id, ART_SIZE)
	_art.name = "Bread"
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_art.position = _center - Vector2(ART_SIZE, ART_SIZE) * 0.5
	_art.pivot_offset = Vector2(ART_SIZE, ART_SIZE) * 0.5
	add_child(_art)
	_card = _build_card(r, vp)
	add_child(_card)
	EventBus.sfx.emit(&"milestone_fanfare", &"")
	# Masuk: latar meredup, sinar dan roti melompat, kartu naik, bintang menyusul.
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_back, "color:a", 0.5, 0.22)
	if calm:
		for n: Control in [_burst, _art, _card]:
			n.modulate.a = 0.0
			tw.tween_property(n, "modulate:a", 1.0, 0.25)
		for st2: Control in _stars:
			st2.modulate.a = 0.0
			tw.tween_property(st2, "modulate:a", 1.0, 0.25)
		return
	_burst.scale = Vector2.ONE * 0.3
	tw.tween_property(_burst, "scale", Vector2.ONE, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_art.scale = Vector2.ONE * 0.1
	tw.tween_property(_art, "scale", Vector2.ONE, 0.42).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.08)
	_card.modulate.a = 0.0
	var card_y: float = _card.position.y
	_card.position.y = card_y + 40.0
	tw.tween_property(_card, "modulate:a", 1.0, 0.25).set_delay(0.25)
	tw.tween_property(_card, "position:y", card_y, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.25)
	for i2 in _stars.size():
		var s: Control = _stars[i2]
		s.scale = Vector2.ZERO
		tw.tween_property(s, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT).set_delay(0.3 + 0.08 * float(i2))


## Kartu di bawah roti: pita "New on the menu!", nama resep, dan harga jualnya.
func _build_card(r: RecipeDefinition, vp: Vector2) -> Control:
	var col := VBoxContainer.new()
	col.name = "Card"
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", -14)
	var rib_row := CenterContainer.new()
	rib_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rib_row.z_index = 1
	col.add_child(rib_row)
	rib_row.add_child(ProceduralUIFactory.ribbon_plate(Tx.t("ui_recipe_new"), 24, vp.x - 120.0))
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 22, true)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 24
	sb.content_margin_bottom = 14
	pc.add_theme_stylebox_override("panel", sb)
	col.add_child(pc)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	pc.add_child(v)
	var name_l: Label = ProceduralUIFactory.label(Tx.recipe_name(recipe_id), 28, Palette.UI_WOOD_DEEP)
	name_l.name = "Name"
	name_l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.custom_minimum_size = Vector2(minf(480.0, vp.x - 120.0), 0)
	v.add_child(name_l)
	if r != null and sim != null:
		var price: Label = ProceduralUIFactory.label(Tx.t("ui_menu_price", {"price": Tx.kr(sim.recipe_price(r.id))}), 18, Palette.TEXT_MUTED)
		price.name = "Price"
		price.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(price)
	var w: float = minf(560.0, vp.x - 80.0)
	col.custom_minimum_size = Vector2(w, 0)
	col.size = col.get_combined_minimum_size()
	col.position = Vector2((vp.x - w) * 0.5, _center.y + ART_SIZE * 0.5 + 28.0)
	return col


func _process(delta: float) -> void:
	_t += delta
	if _burst != null and not SettingsManager.reduced_motion():
		_burst.rotation += delta * 0.45
		for i in _stars.size():
			if not _leaving and _t > 0.8:
				_stars[i].rotation = sin(_t * 3.0 + float(i)) * 0.25
	if _t >= HOLD_SECONDS and not _leaving:
		leave()


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.button_index == MOUSE_BUTTON_LEFT and not mb.pressed and _t >= TAP_AFTER:
		accept_event()
		leave()


func on_back() -> bool:
	leave()
	return true


## Keluar: roti terbang ke tab Menu (bila terlihat) sambil mengecil, sisanya
## memudar, lalu tab Menu memantul dan layar tertutup.
func leave() -> void:
	if _leaving:
		return
	_leaving = true
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(_back, "color:a", 0.0, EXIT_SECONDS)
	for n: Control in [_burst, _card]:
		tw.tween_property(n, "modulate:a", 0.0, EXIT_SECONDS * 0.7)
	for s: Control in _stars:
		tw.tween_property(s, "modulate:a", 0.0, EXIT_SECONDS * 0.6)
	var tab: Button = game.hud.tab_button(&"menu") if game != null and game.hud != null and game.hud.visible else null
	if tab != null and tab.is_visible_in_tree() and not SettingsManager.reduced_motion():
		var target: Vector2 = tab.get_global_rect().get_center() - get_global_rect().position
		tw.tween_property(_art, "position", target - _art.size * 0.5, EXIT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(_art, "scale", Vector2.ONE * 0.2, EXIT_SECONDS).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(func() -> void:
			if is_instance_valid(tab):
				ProceduralAnimationSystem.squash_pop(tab, 1.15, 0.22)
				EventBus.sfx.emit(&"tap_boost_pop", &"")
			close())
	else:
		tw.tween_property(_art, "modulate:a", 0.0, EXIT_SECONDS)
		tw.chain().tween_callback(close)


func is_leaving() -> bool:
	return _leaving


## Sinar pipih bergantian di belakang roti, dengan lingkaran krem di tengahnya
## (gaya flat, GDD 130.6).
class RevealBurst extends Control:
	const RAYS: int = 14

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = size.x * 0.5
		for i in RAYS:
			var a0: float = TAU * float(i) / float(RAYS)
			var a1: float = a0 + TAU / float(RAYS) * 0.5
			var pts := PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * r, c + Vector2(cos((a0 + a1) * 0.5), sin((a0 + a1) * 0.5)) * r * 1.02,
				c + Vector2(cos(a1), sin(a1)) * r])
			ProceduralUIFactory.fill_aa(self, pts, Color(Palette.BUTTER_YELLOW, 0.55))
		draw_circle(c, r * 0.45, Color(Palette.UI_CREAM, 0.96), true, -1.0, true)
