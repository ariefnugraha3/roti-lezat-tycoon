class_name UpgradesScreen
extends UISheet
## Layar Upgrades (GDD idle 12.3): semua upgrade stasiun, meja kasir, resep,
## staf, dan global dalam satu daftar vertikal, diurutkan "Best value first" =
## kenaikan KR/s ÷ biaya satu level (IdleEconomyManager.ranked_offers). Setiap
## baris punya tombol ×1 / ×10 / Max. Urutan dihitung ulang setelah membeli,
## bukan tiap tick, supaya baris tidak meloncat di bawah jari. Promosi
## (GDD idle 11.2, pengganti Marketing v3.1) ada di bawah daftar (GDD idle
## §20 no. 84).
##
## Semua baris berbentuk sama (GDD idle §20 no. 74): kartu dengan ikon, judul,
## dan keterangan di atas; di bawahnya pil di kiri (kenaikan KR/s, atau status
## promosi) dan tombol di kanan. Tombol Start promosi adalah tombol dua baris
## yang sama dengan ×1/×10/Max (BuyButtons.make_button): selalu di tempat yang
## sama, ukuran yang sama, dan tidak ikut memanjang bersama keterangannya.

const ICON_PX: float = 44.0

var _rows: Array[BuyButtons] = []
## Promosi: id -> {button, state, pill, skip}.
var _promos: Dictionary = {}
## Kopi Pak Lurah lewat iklan (GDD idle 22.4): baris dan tombolnya.
var _coffee: Control = null
var _coffee_button: Button = null


func sheet_title() -> String:
	return Tx.t("ui_tab_upgrades")


func sheet_icon() -> String:
	return "bolt"


func build_page(body: VBoxContainer) -> void:
	_rows.clear()
	_promos.clear()
	var list: VBoxContainer = scroll_box(body)
	list.name = "UpgradeList"
	# Upgrade dulu, promosi di bawahnya (GDD idle §20 no. 84): aksi utama
	# lembar ini tampil di layar pertama, juga pada teks 150%.
	section(list, Tx.t("ui_best_value"))
	for item: Dictionary in sim.idle_economy.ranked_offers():
		_row(list, item)
	section(list, Tx.t("ui_promotions"))
	_coffee_row(list)
	for id: StringName in BoostManager.promo_ids():
		_promo_row(list, id)
	_tick_promos()


## Kartu baris yang sama untuk upgrade, promosi, dan kopi: [ikon, judul,
## keterangan] di atas, lalu baris bawah (pil kiri, tombol kanan) yang
## dikembalikan. `card_name` = nama node kartunya.
func _card_row(parent: Control, card_name: String, icon: Control, title_text: String, sub_text: String) -> HBoxContainer:
	var pc: PanelContainer = card(parent)
	pc.name = card_name
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var top: HBoxContainer = hbox(v, 10)
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(icon)
	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", 2)
	top.add_child(text)
	var t: Label = lbl(text, title_text, 18, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	lbl(text, sub_text, 14, Palette.TEXT_MUTED, true)
	var bottom: HBoxContainer = hbox(v, 8)
	bottom.name = "Bottom"
	return bottom


## Pemisah yang mendorong tombol ke kanan baris bawah.
static func _push_right(row: HBoxContainer) -> void:
	var gap := Control.new()
	gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(gap)


func _row(parent: Control, item: Dictionary) -> void:
	var o: Dictionary = item["offer"]
	var bottom: HBoxContainer = _card_row(parent, "Up_%s_%s" % [o["kind"], o["id"]], UpgradeInfo.icon(sim, o, ICON_PX),
		UpgradeInfo.title(sim, o), UpgradeInfo.effect(sim, o))
	# Baris beli: kenaikan KR/s sebagai pil hijau di kiri, tombol di kanan.
	if float(item["delta"]) > 0.0:
		var gain: PanelContainer = ProceduralUIFactory.pill("up", Tx.t("ui_upgrade_gain", {"amount": Tx.rate(float(item["delta"]))}),
			Palette.MATCHA_SOFT, Palette.MATCHA_DEEP)
		gain.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		(gain.get_meta("label") as Label).name = "Gain"
		bottom.add_child(gain)
	_push_right(bottom)
	var buy: BuyButtons = BuyButtons.new().setup(sim, o["kind"], o["id"])
	buy.bought.connect(func(_n: int) -> void: refresh())
	bottom.add_child(buy)
	_rows.append(buy)


## Satu promosi: efek dan lamanya di atas; di bawah pil status (berjalan /
## jeda) di kiri, lalu (saat jeda) Skip lewat iklan dan tombol Start dua baris
## berbiaya di kanan.
func _promo_row(parent: Control, id: StringName) -> void:
	var p: Dictionary = BoostManager.promo(id)
	var badge: PanelContainer = ProceduralUIFactory.badge("megaphone", Palette.PASTEL_PERIWINKLE, Palette.UI_WOOD_DEEP, int(ICON_PX))
	var bottom: HBoxContainer = _card_row(parent, "Promo_" + String(id), badge, Tx.t(String(id)), promo_effect(p))
	var pill: PanelContainer = ProceduralUIFactory.pill("clock", "", Palette.UI_CREAM_DEEP, Palette.UI_WOOD_DEEP)
	pill.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var state: Label = pill.get_meta("label")
	state.name = "State"
	bottom.add_child(pill)
	_push_right(bottom)
	# Jeda promosi bisa diselesaikan dengan iklan (GDD idle 22.4).
	var skip: Button = AdButton.make(&"promo_skip", Tx.t("ui_promo_skip"), "soft", 18, 15)
	skip.name = "Skip"
	skip.custom_minimum_size.y = BuyButtons.HEIGHT
	skip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	skip.pressed.connect(func() -> void:
		skip.disabled = true
		Monetization.show_rewarded(&"promo_skip", func(ok: bool) -> void:
			if not is_instance_valid(skip):
				return
			skip.disabled = false
			if ok:
				sim.boosts.skip_cooldown(id)
			_tick_promos()))
	bottom.add_child(skip)
	var b: Button = BuyButtons.make_button("primary")
	b.name = "Start"
	b.pressed.connect(func() -> void:
		if sim.boosts.start_promo(id):
			_tick_promos())
	bottom.add_child(b)
	_promos[id] = {"button": b, "state": state, "pill": pill, "skip": skip}


## Secangkir kopi Pak Lurah lagi lewat iklan berhadiah (GDD idle 11.1, 22.3).
## Barisnya hanya tampil selagi hadiah itu bisa ditawarkan.
func _coffee_row(parent: Control) -> void:
	var badge: PanelContainer = ProceduralUIFactory.badge("heart", Palette.BUTTER_SOFT, Palette.UI_WOOD_DEEP, int(ICON_PX))
	var bottom: HBoxContainer = _card_row(parent, "Coffee", badge, Tx.t("ui_coffee_title"),
		Tx.t("ui_coffee_effect", {"mult": Tx.mult(DataRegistry.idlef("boosts.daily_gift.mult")),
		"minutes": int(DataRegistry.idlef("boosts.daily_gift.minutes") * sim.prestige.coffee_mult())}))
	_coffee = bottom.get_parent().get_parent() as Control
	_push_right(bottom)
	_coffee_button = AdButton.make(&"coffee_refill", Tx.t("ui_coffee_refill"), "primary", 18, 15)
	_coffee_button.custom_minimum_size.y = BuyButtons.HEIGHT
	_coffee_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_coffee_button.pressed.connect(func() -> void:
		_coffee_button.disabled = true
		Monetization.show_rewarded(&"coffee_refill", func(ok: bool) -> void:
			if not is_instance_valid(_coffee_button):
				return
			_coffee_button.disabled = false
			if ok:
				sim.boosts.pour_coffee()
				EventBus.sfx.emit(&"welcome_back_chime", &"")
			_tick_promos()))
	bottom.add_child(_coffee_button)


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
		(r["pill"] as Control).visible = st.visible
		# Tombol Start selalu di tempatnya; saat berjalan atau jeda ia pudar dan
		# pil statusnya menjelaskan alasannya.
		var price: String = Tx.kr(sim.boosts.promo_cost(id))
		b.disabled = block != &""
		BuyButtons.set_texts(b, Tx.t("ui_promo_start_short"), price, Tx.t("ui_promo_start", {"price": price}))
		var skip: Button = r["skip"]
		AdButton.refresh(skip)
		skip.visible = skip.visible and block == &"cooldown"
	if is_instance_valid(_coffee_button):
		AdButton.refresh(_coffee_button)
		_coffee.visible = _coffee_button.visible


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
