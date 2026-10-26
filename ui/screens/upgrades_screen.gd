class_name UpgradesScreen
extends UISheet
## Layar Upgrades (GDD idle 12.3): semua upgrade stasiun, meja kasir, resep,
## staf, dan global dalam satu daftar vertikal, diurutkan "Best value first" =
## kenaikan KR/s ÷ biaya satu level (IdleEconomyManager.ranked_offers). Setiap
## baris punya tombol ×1 / ×10 / Max. Urutan dihitung ulang setelah membeli,
## bukan tiap tick, supaya baris tidak meloncat di bawah jari.

const ICON_PX: float = 44.0

var _rows: Array[BuyButtons] = []


func sheet_title() -> String:
	return Tx.t("ui_tab_upgrades")


func build_page(body: VBoxContainer) -> void:
	_rows.clear()
	lbl(body, Tx.t("ui_best_value"), 15, Palette.TEXT_MUTED)
	var list: VBoxContainer = scroll_box(body)
	list.name = "UpgradeList"
	for item: Dictionary in sim.idle_economy.ranked_offers():
		_row(list, item)


func _row(parent: Control, item: Dictionary) -> void:
	var o: Dictionary = item["offer"]
	var pc := PanelContainer.new()
	pc.name = "Up_%s_%s" % [o["kind"], o["id"]]
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.UI_CREAM, 18, false)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	pc.add_theme_stylebox_override("panel", sb)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var top: HBoxContainer = hbox(v, 10)
	var ic: Control = UpgradeInfo.icon(sim, o, ICON_PX)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(ic)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	top.add_child(text)
	var t: Label = lbl(text, UpgradeInfo.title(sim, o), 18, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	lbl(text, UpgradeInfo.effect(sim, o), 14, Palette.TEXT_MUTED, true)
	if float(item["delta"]) > 0.0:
		var gain: Label = lbl(text, Tx.t("ui_upgrade_gain", {"amount": Tx.rate(float(item["delta"]))}), 14, Palette.MATCHA, true)
		gain.name = "Gain"
	var buy: BuyButtons = BuyButtons.new().setup(sim, o["kind"], o["id"])
	buy.size_flags_horizontal = Control.SIZE_SHRINK_END
	buy.bought.connect(func(_n: int) -> void: refresh())
	v.add_child(buy)
	_rows.append(buy)


## KR terus berubah: tombol menyala dan jumlah Max ikut naik.
func tick_page() -> void:
	for b: BuyButtons in _rows:
		if is_instance_valid(b):
			b.refresh()


## Baris-baris dalam urutan tampil: [kind, id] (tes).
func order() -> Array:
	var out: Array = []
	for b: BuyButtons in _rows:
		if is_instance_valid(b):
			out.append([b.kind, b.id])
	return out
