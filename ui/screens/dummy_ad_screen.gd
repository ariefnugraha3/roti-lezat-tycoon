class_name DummyAdScreen
extends UIScreen
## Iklan tiruan toko uji (GDD idle 22.2): layar penuh "Test ad" dengan hitung
## mundur `monetization.dummy_ad_seconds`, lalu Claim reward. Menutupnya lebih
## awal sama dengan iklan yang tidak selesai: tanpa hadiah dan jatah harian
## tetap. `params.done(success)` dipanggil tepat sekali. Toko di-pause dan suara
## dibisukan oleh Monetization selama layar ini tampil.

var _left: float = 0.0
var _count: Label = null
var _claim: Button = null
var _resolved: bool = false


func _init() -> void:
	super._init()
	overlay = true
	keep_open = true


func build() -> void:
	_left = maxf(0.0, DataRegistry.idlef("monetization.dummy_ad_seconds"))
	var shade := ColorRect.new()
	shade.color = Color(Palette.DARK_CHOCOLATE, 0.92)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	v.custom_minimum_size = Vector2(560, 0)
	center.add_child(v)
	var tag: PanelContainer = ProceduralUIFactory.pill("play", Tx.t("ui_dummy_ad_tag"), Palette.BUTTER_SOFT, Palette.UI_WOOD_DEEP, 16)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(tag)
	var icon_c := CenterContainer.new()
	v.add_child(icon_c)
	icon_c.add_child(ProceduralUIFactory.icon("bread", 150, Palette.HONEY))
	var t: Label = ProceduralUIFactory.title(Tx.t("ui_dummy_ad_title"), 34)
	t.add_theme_color_override("font_color", Palette.FLOUR_WHITE)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	var body: Label = ProceduralUIFactory.label(Tx.t("ui_dummy_ad_body"), 18, Palette.UI_CREAM)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(body)
	_count = ProceduralUIFactory.label("", 20, Palette.BUTTER_YELLOW)
	_count.name = "Countdown"
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(_count)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	var skip: Button = ProceduralUIFactory.button(Tx.t("ui_dummy_ad_close"), "secondary")
	skip.name = "Skip"
	skip.custom_minimum_size = Vector2(200, 56)
	skip.pressed.connect(func() -> void: _finish(false))
	row.add_child(skip)
	_claim = ProceduralUIFactory.button(Tx.t("ui_dummy_ad_claim"), "success")
	_claim.name = "Claim"
	_claim.custom_minimum_size = Vector2(220, 56)
	_claim.pressed.connect(func() -> void: _finish(true))
	row.add_child(_claim)
	_update()


func _process(delta: float) -> void:
	if _left > 0.0:
		_left = maxf(0.0, _left - delta)
		_update()


func _update() -> void:
	if _count == null:
		return
	_claim.disabled = _left > 0.0
	_count.text = Tx.t("ui_dummy_ad_count", {"s": int(ceil(_left))}) if _left > 0.0 else Tx.t("ui_dummy_ad_done")


## Iklan selesai (true) atau ditutup lebih awal (false).
func _finish(ok: bool) -> void:
	if _resolved:
		return
	_resolved = true
	var done: Callable = params.get("done", Callable())
	close()
	if done.is_valid():
		done.call(ok)


## Tes: lewati hitung mundur.
func skip_countdown() -> void:
	_left = 0.0
	_update()


func on_back() -> bool:
	_finish(false)
	return true


func on_closed() -> void:
	if not _resolved:
		_resolved = true
		var done: Callable = params.get("done", Callable())
		if done.is_valid():
			done.call(false)
	super.on_closed()
