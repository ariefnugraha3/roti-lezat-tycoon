class_name UpgradesScreen
extends UISheet
## Layar Upgrades (GDD idle 12.3): semua upgrade stasiun, meja kasir, resep,
## staf, dan global dalam satu daftar vertikal, diurutkan "Best value first" =
## kenaikan KR/s ÷ biaya satu level (IdleEconomyManager.ranked_offers). Setiap
## baris punya tombol ×1 / ×10 / Max. Urutan dihitung ulang setelah membeli,
## bukan tiap tick, supaya baris tidak meloncat di bawah jari. Promosi
## (GDD idle 11.2, pengganti Marketing v3.1) ada di atas daftar.

const ICON_PX: float = 44.0

var _rows: Array[BuyButtons] = []
## Promosi: id -> {button, state}.
var _promos: Dictionary = {}


func sheet_title() -> String:
	return Tx.t("ui_tab_upgrades")


func build_page(body: VBoxContainer) -> void:
	_rows.clear()
	_promos.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "UpgradeList"
	lbl(list, Tx.t("ui_promotions"), 15, Palette.TEXT_MUTED)
	for id: StringName in BoostManager.promo_ids():
		_promo_row(list, id)
	lbl(list, Tx.t("ui_best_value"), 15, Palette.TEXT_MUTED)
	for item: Dictionary in sim.idle_economy.ranked_offers():
		_row(list, item)
	_tick_promos()


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


## Satu promosi: efek dan lamanya, lalu tombol Start dengan biayanya, atau sisa
## waktu berjalan / jeda.
func _promo_row(parent: Control, id: StringName) -> void:
	var p: Dictionary = BoostManager.promo(id)
	var badge: PanelContainer = ProceduralUIFactory.badge("megaphone", Palette.PASTEL_PERIWINKLE, Palette.UI_WOOD_DEEP, int(ICON_PX))
	var h: HBoxContainer = UISheet.row(parent, Tx.t(String(id)), promo_effect(p), badge)
	h.get_parent().name = "Promo_" + String(id)
	var state: Label = lbl(h, "", 15, Palette.TEXT_MUTED)
	state.name = "State"
	var b: Button = ProceduralUIFactory.button("", "primary")
	b.name = "Start"
	b.custom_minimum_size = Vector2(150, 52)
	b.pressed.connect(func() -> void:
		if sim.boosts.start_promo(id):
			_tick_promos())
	h.add_child(b)
	_promos[id] = {"button": b, "state": state}


## "Customers ×1.5 for 5 min" (+ RotiFood bila ada).
static func promo_effect(p: Dictionary) -> String:
	var key: String = "ui_promo_effect_rf" if float(p.get("rotifood_mult", 1.0)) > 1.0 else "ui_promo_effect"
	return Tx.t(key, {"mult": Tx.mult(float(p.get("arrival_mult", 1.0))), "rf": Tx.mult(float(p.get("rotifood_mult", 1.0))),
		"minutes": int(float(p.get("minutes", 0)))})


func _tick_promos() -> void:
	for k: Variant in _promos.keys():
		var id: StringName = k
		var r: Dictionary = _promos[k]
		var b: Button = r["button"]
		var st: Label = r["state"]
		if not is_instance_valid(b):
			continue
		var block: StringName = sim.boosts.promo_block(id)
		if sim.boosts.promo_id == id and sim.boosts.promo_left > 0.0:
			st.text = Tx.t("ui_promo_running", {"time": Tx.timer(sim.boosts.promo_left)})
		elif block == &"cooldown":
			st.text = Tx.t("ui_promo_cooldown", {"time": Tx.timer(sim.boosts.cooldown_left(id))})
		else:
			st.text = ""
		st.visible = st.text != ""
		b.visible = not st.visible
		b.text = Tx.t("ui_promo_start", {"price": Tx.kr(sim.boosts.promo_cost(id))})
		b.disabled = block != &""


## KR terus berubah: tombol menyala dan jumlah Max ikut naik.
func tick_page() -> void:
	for b: BuyButtons in _rows:
		if is_instance_valid(b):
			b.refresh()
	_tick_promos()


## Baris-baris dalam urutan tampil: [kind, id] (tes).
func order() -> Array:
	var out: Array = []
	for b: BuyButtons in _rows:
		if is_instance_valid(b):
			out.append([b.kind, b.id])
	return out
