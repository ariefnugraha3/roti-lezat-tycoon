class_name BuyButtons
extends HBoxContainer
## Tombol pembelian upgrade ×1 / ×10 / Max (GDD idle 8.1, 12.2): setiap tombol
## menampilkan jumlah level dan biayanya. ×10 hanya aktif bila kesepuluh level
## terjangkau dan muat dalam batas; Max menyebut jumlah levelnya ("Max (+37)").
## `refresh()` memperbarui teks dan status tanpa membangun ulang tombol, jadi
## ketukan tidak pernah hilang karena tombol diganti di tengah tekan.
## ×1 madu, ×10 dan Max madu muda; yang belum terjangkau krem pudar.
##
## `make_button` membuat tombol dua baris yang sama (aksi di atas, biaya di
## bawah, WIDTH × HEIGHT, selalu di tengah barisnya) untuk tombol beli lain di
## lembar yang sama, misalnya Start promosi (GDD idle §20 no. 74).

signal bought(levels: int)

const MODES: Array[StringName] = [&"x1", &"x10", &"max"]
## Ukuran tombol beli dua baris (px logis).
const WIDTH: float = 104.0
const HEIGHT: float = 58.0

var sim: SimulationRoot = null
var kind: StringName = &""
var id: Variant = null
var _buttons: Dictionary = {}
var _labels: Dictionary = {}


func setup(s: SimulationRoot, offer_kind: StringName, offer_id: Variant, button_w: float = WIDTH) -> BuyButtons:
	sim = s
	kind = offer_kind
	id = offer_id
	name = "BuyButtons"
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_theme_constant_override("separation", 6)
	for mode: StringName in MODES:
		var b: Button = make_button("primary" if mode == &"x1" else "soft", button_w)
		b.name = "Buy_" + String(mode)
		var m: StringName = mode
		b.pressed.connect(func() -> void: _buy(m))
		add_child(b)
		_buttons[mode] = b
		_labels[mode] = [b.get_meta("top"), b.get_meta("cost")]
	refresh()
	return self


## Tombol beli dua baris: aksi di atas (label "Count"), biaya di bawah ("Cost"),
## berukuran tetap dan di tengah barisnya secara vertikal.
static func make_button(kind: String, width: float = WIDTH) -> Button:
	var b: Button = ProceduralUIFactory.button("", kind)
	b.custom_minimum_size = Vector2(width, HEIGHT)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
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
	b.set_meta("top", top)
	b.set_meta("cost", cost)
	return b


## Isi tombol `make_button`: teks atas dan bawah, tooltip, dan warna tinta yang
## mengikuti `disabled` (setel `disabled` dulu).
static func set_texts(b: Button, top_text: String, cost_text: String, tooltip: String = "") -> void:
	var top: Label = b.get_meta("top")
	var cost: Label = b.get_meta("cost")
	top.text = top_text
	cost.text = cost_text
	b.tooltip_text = tooltip
	var ink: Color = ProceduralUIFactory.disabled_ink() if b.disabled else Palette.UI_WOOD_DEEP
	top.add_theme_color_override("font_color", ink)
	cost.add_theme_color_override("font_color", ink)


## [atas, bawah] tombol `make_button` (tes).
static func texts(b: Button) -> PackedStringArray:
	return PackedStringArray([(b.get_meta("top") as Label).text, (b.get_meta("cost") as Label).text])


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
		b.disabled = n <= 0
		set_texts(b, top.text, Tx.t("ui_level_maxed") if maxed else Tx.kr(UpgradeManager.offer_cost(o, shown_n)))


func _buy(mode: StringName) -> void:
	var n: int = sim.upgrades.buy(kind, id, mode)
	if n > 0:
		bought.emit(n)
	refresh()
