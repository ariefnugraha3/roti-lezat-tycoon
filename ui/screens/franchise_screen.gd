class_name FranchiseScreen
extends UISheet
## Layar Waralaba (GDD idle 10, 12.3): bintang sekarang dan yang akan didapat,
## pengali penghasilan, perk (tercapai/terkunci), dan tombol Sell & Franchise.
## Konfirmasi membuka cutscene Pak Lurah; resetnya sendiri dijalankan GameRoot
## setelah cutscene (GDD idle 10.6).

var _sell: Button = null
var _gain: Label = null
var _next: Label = null


func sheet_title() -> String:
	return Tx.t("ui_franchise_title")


func build_page(body: VBoxContainer) -> void:
	var list: VBoxContainer = scroll_box(body)
	list.name = "FranchiseList"
	var p: PrestigeManager = sim.prestige
	var card: PanelContainer = ProceduralUIFactory.card(Tx.t("ui_branch_number", {"number": p.run_index}))
	card.name = "Summary"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(card)
	var cb: VBoxContainer = ProceduralUIFactory.content_of(card)
	var h: HBoxContainer = hbox(cb, 10)
	h.add_child(ProceduralUIFactory.icon("star", 40, Palette.SIGN_PURPLE))
	var have: Label = lbl(h, stars_text("ui_franchise_have", p.stars), 22, Palette.UI_WOOD_DEEP, true)
	have.name = "Have"
	var mult: Label = lbl(cb, Tx.t("ui_franchise_mult", {"mult": "%.2f" % p.income_mult()}), 17, Palette.TEXT, true)
	mult.name = "Mult"
	lbl(cb, Tx.t("ui_franchise_bonus", {"percent": _num(DataRegistry.idlef("prestige.income_per_star") * 100.0)}), 15, Palette.TEXT_MUTED, true)
	_gain = lbl(cb, "", 20, Palette.UI_WOOD_DEEP, true)
	_gain.name = "Gain"
	_next = lbl(cb, "", 15, Palette.TEXT_MUTED, true)
	_next.name = "Next"
	_sell = ProceduralUIFactory.icon_text_button("star", Tx.t("ui_franchise_sell"), "primary", 22, 18)
	_sell.name = "Sell"
	_sell.custom_minimum_size = Vector2(0, 60)
	_sell.pressed.connect(_confirm)
	cb.add_child(_sell)
	var rs: Label = lbl(cb, Tx.t("ui_franchise_resets"), 14, Palette.TEXT_MUTED, true)
	rs.name = "Resets"
	lbl(cb, Tx.t("ui_franchise_keeps"), 14, Palette.TEXT_MUTED, true)
	lbl(list, Tx.t("ui_franchise_perks"), 15, Palette.TEXT_MUTED)
	for x: Variant in DataRegistry.idle("perks"):
		var perk: Dictionary = x
		var id: StringName = StringName(str(perk["id"]))
		var on: bool = p.has_perk(id)
		var badge: PanelContainer = ProceduralUIFactory.badge("star" if on else "lock", Palette.SIGN_PURPLE if on else Palette.UI_CREAM_DEEP,
			Palette.FLOUR_WHITE if on else Palette.TEXT_MUTED, 44)
		var row: HBoxContainer = UISheet.row(list, Tx.t(String(id)), Tx.t(String(id) + "_desc", perk_params(perk)), badge)
		row.get_parent().name = "Perk_" + String(id)
		var state: Label = lbl(row, Tx.t("ui_franchise_perk_on") if on else stars_text("ui_franchise_perk_need", int(perk.get("stars", 0))),
			15, Palette.MATCHA if on else Palette.TEXT_MUTED)
		state.name = "State"
	tick_page()


## Angka yang ikut berubah selama lembar terbuka: bintang yang didapat, KR untuk
## bintang berikutnya, dan alasan tombol mati.
func tick_page() -> void:
	if sim == null or _sell == null or not is_instance_valid(_sell):
		return
	var p: PrestigeManager = sim.prestige
	var block: StringName = p.franchise_block()
	match block:
		&"tier":
			var loc: LocationDefinition = DataRegistry.location_by_tier(DataRegistry.idlei("prestige.unlock_location_tier"))
			_gain.text = Tx.t("ui_franchise_need_tier", {"location": Tx.t(String(loc.localization_key))})
		&"stars":
			_gain.text = Tx.t("ui_franchise_need_stars")
		_:
			_gain.text = stars_text("ui_franchise_gain", p.stars_gain())
	_next.text = Tx.t("ui_franchise_next", {"amount": Tx.kr(p.kr_to_next_star())})
	_sell.disabled = block != &""


## Teks berisi {stars}: kunci `_one` untuk tepat satu bintang.
static func stars_text(key: String, n: int) -> String:
	return Tx.t(key + "_one") if n == 1 else Tx.t(key, {"stars": Tx.big(float(n))})


## Parameter teks deskripsi perk dari katalognya.
static func perk_params(perk: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k: Variant in perk.keys():
		var key: String = str(k)
		if key == "id" or key == "stars":
			continue
		var v: float = float(perk[k])
		match key:
			"start_kr":
				out[key] = Tx.kr(v)
			"offline_efficiency":
				out[key] = Tx.percent(v)
			_:
				out[key] = _num(v)
	return out


static func _num(v: float) -> String:
	return str(int(v)) if is_equal_approx(v, roundf(v)) else "%.1f" % v


func _confirm() -> void:
	if sim.prestige.franchise_block() != &"":
		return
	host.confirm(Tx.t("ui_franchise_confirm"), func() -> void:
		host.open(&"franchise_cutscene", {"stars": sim.prestige.stars_gain(), "number": sim.prestige.run_index + 1}))
