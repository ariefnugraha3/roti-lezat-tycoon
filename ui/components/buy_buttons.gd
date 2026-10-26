class_name BuyButtons
extends HBoxContainer
## Tombol pembelian upgrade ×1 / ×10 / Max (GDD idle 8.1, 12.2): setiap tombol
## menampilkan jumlah level dan biayanya. ×10 hanya aktif bila kesepuluh level
## terjangkau dan muat dalam batas; Max menyebut jumlah levelnya ("Max (+37)").
## `refresh()` memperbarui teks dan status tanpa membangun ulang tombol, jadi
## ketukan tidak pernah hilang karena tombol diganti di tengah tekan.

signal bought(levels: int)

const MODES: Array[StringName] = [&"x1", &"x10", &"max"]

var sim: SimulationRoot = null
var kind: StringName = &""
var id: Variant = null
var _buttons: Dictionary = {}
var _labels: Dictionary = {}


func setup(s: SimulationRoot, offer_kind: StringName, offer_id: Variant, button_w: float = 104.0) -> BuyButtons:
	sim = s
	kind = offer_kind
	id = offer_id
	name = "BuyButtons"
	add_theme_constant_override("separation", 6)
	for mode: StringName in MODES:
		var b: Button = ProceduralUIFactory.button("", "primary" if mode == &"x1" else "secondary")
		b.name = "Buy_" + String(mode)
		b.custom_minimum_size = Vector2(button_w, 58)
		b.clip_contents = true
		var v := VBoxContainer.new()
		v.set_anchors_preset(Control.PRESET_FULL_RECT)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_theme_constant_override("separation", 0)
		b.add_child(v)
		var top: Label = ProceduralUIFactory.label("", 15, Palette.UI_WOOD_DEEP)
		top.name = "Count"
		top.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		top.add_theme_font_override("font", ProceduralUIFactory.display_font())
		v.add_child(top)
		var cost: Label = ProceduralUIFactory.label("", 12, Palette.UI_WOOD)
		cost.name = "Cost"
		cost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(cost)
		var m: StringName = mode
		b.pressed.connect(func() -> void: _buy(m))
		add_child(b)
		_buttons[mode] = b
		_labels[mode] = [top, cost]
	refresh()
	return self


func offer() -> Dictionary:
	return sim.upgrades.offer(kind, id) if sim != null else {}


## Teks tombol mode `mode`: "×1", "×10", atau "Max (+n)" (tes).
func label_of(mode: StringName) -> String:
	return (_labels[mode][0] as Label).text


func cost_of(mode: StringName) -> String:
	return (_labels[mode][1] as Label).text


func button(mode: StringName) -> Button:
	return _buttons.get(mode)


func refresh() -> void:
	var o: Dictionary = offer()
	var maxed: bool = o.is_empty() or int(o["level"]) >= int(o["cap"])
	for mode: StringName in MODES:
		var b: Button = _buttons[mode]
		var top: Label = _labels[mode][0]
		var cost: Label = _labels[mode][1]
		var n: int = 0 if maxed else sim.upgrades.offer_count(o, mode)
		match mode:
			&"x1":
				top.text = Tx.t("ui_buy_x1")
			&"x10":
				top.text = Tx.t("ui_buy_x10")
			_:
				top.text = Tx.t("ui_buy_max", {"levels": n}) if n > 0 else Tx.t("ui_buy_max_none")
		var shown_n: int = n
		if shown_n <= 0 and not maxed:
			shown_n = 1 if mode != &"x10" else mini(10, int(o["cap"]) - int(o["level"]))
		cost.text = Tx.t("ui_level_maxed") if maxed else Tx.kr(UpgradeManager.offer_cost(o, shown_n))
		b.disabled = n <= 0
		var ink: Color = Palette.TEXT_MUTED if b.disabled else Palette.UI_WOOD_DEEP
		top.add_theme_color_override("font_color", ink)
		cost.add_theme_color_override("font_color", ink)


func _buy(mode: StringName) -> void:
	var n: int = sim.upgrades.buy(kind, id, mode)
	if n > 0:
		bought.emit(n)
	refresh()
