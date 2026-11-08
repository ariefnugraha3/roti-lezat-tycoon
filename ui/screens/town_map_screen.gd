class_name TownMapScreen
extends UISheet
## Peta Crumbtown (GDD idle 21.7): setiap cabang yang pernah dibuka berdiri di
## kavlingnya di sepanjang jalan-jalan kota, tiga kavling per jalan, dengan
## etalase sesuai tier lokasi tertinggi yang dicapainya (ShopFrontArt). Cabang
## yang sedang buka diberi pita "You are here", dan satu kavling kosong "Next
## branch" menunggu Waralaba berikutnya. Mengetuk sebuah toko membuka kartu
## ceritanya. Dibuka dari lembar Franchise.
##
## Setiap cabang tetap milik pemain (GDD idle §20 no. 78): kavling cabang lain
## menyebut tabungan yang menunggu ("+1.2K KR"), dan kartu ceritanya punya tombol
## "Visit Branch #n" (GameRoot.visit_branch).

const LOTS_PER_STREET: int = 3


func sheet_title() -> String:
	return Tx.t("ui_map_title")


func sheet_icon() -> String:
	return "shop"


func build_page(body: VBoxContainer) -> void:
	var list: VBoxContainer = scroll_box(body)
	list.name = "MapList"
	list.add_theme_constant_override("separation", 0)
	var head: PanelContainer = card(list)
	head.name = "Summary"
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 2)
	head.add_child(hv)
	var t: Label = lbl(hv, Tx.t("ui_map_summary", {"count": sim.prestige.run_index, "stars": sim.prestige.stars}), 18, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	t.name = "SummaryText"
	lbl(hv, Tx.t("ui_map_hint"), 14, Palette.TEXT_MUTED, true)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 10)
	list.add_child(gap)
	var lots: Array[Dictionary] = branches(sim)
	lots.append({"next": true})
	var street: StreetRow = null
	for i in lots.size():
		if i % LOTS_PER_STREET == 0:
			street = StreetRow.new()
			street.name = "Street%d" % (i / LOTS_PER_STREET + 1)
			street.index = i / LOTS_PER_STREET
			list.add_child(street)
		street.lots.add_child(_lot(lots[i]))


## Semua cabang urut nomor: catatan cabang lain (PrestigeManager.branches,
## termasuk tempat kosong untuk cabang dari save sebelum peta) dan cabang yang
## sedang dimainkan.
static func branches(s: SimulationRoot) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cur: Dictionary = s.prestige.current_branch()
	for b: Dictionary in s.prestige.branches:
		if not cur.is_empty() and int(b.get("number", 0)) > int(cur["number"]):
			out.append(cur)
			cur = {}
		out.append(b)
	if not cur.is_empty():
		out.append(cur)
	return out


## Tabungan yang menunggu di cabang `b` bila dikunjungi sekarang.
func _waiting(b: Dictionary) -> float:
	if bool(b.get("current", false)) or sim == null:
		return 0.0
	return PrestigeManager.waiting_kr(b, sim.offline.now_unix())


func _lot(b: Dictionary) -> Button:
	var btn := Button.new()
	btn.flat = true
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 196)
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		btn.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_FULL_RECT)
	v.alignment = BoxContainer.ALIGNMENT_END
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 2)
	btn.add_child(v)
	var art := ShopFrontArt.new()
	art.custom_minimum_size = Vector2(120, 120)
	art.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(art)
	var cap_text: String
	var face: Color = Palette.CARD
	var ink: Color = Palette.UI_WOOD_DEEP
	if b.has("next"):
		btn.name = "NextLot"
		art.tier = 0
		cap_text = Tx.t("ui_map_next")
		btn.disabled = true
		ink = Palette.TEXT_MUTED
	else:
		var n: int = int(b["number"])
		btn.name = "Branch%d" % n
		art.tier = clampi(int(b.get("tier", 1)), 1, 5)
		cap_text = Tx.t("ui_branch_number", {"number": n})
		if bool(b.get("current", false)):
			face = Palette.HONEY
			ink = Palette.FLOUR_WHITE
			cap_text = Tx.t("ui_map_here", {"number": n})
		btn.pressed.connect(_open_branch.bind(b))
		var wait: float = _waiting(b)
		if wait > 0.0:
			var tag := PanelContainer.new()
			tag.name = "Waiting"
			tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
			tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			var tsb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.BUTTER_SOFT, 12, false)
			tsb.content_margin_left = 6.0
			tsb.content_margin_right = 10.0
			tsb.content_margin_top = 1.0
			tsb.content_margin_bottom = 1.0
			tag.add_theme_stylebox_override("panel", tsb)
			var th := HBoxContainer.new()
			th.mouse_filter = Control.MOUSE_FILTER_IGNORE
			th.add_theme_constant_override("separation", 4)
			tag.add_child(th)
			var coin: Control = ProceduralUIFactory.icon("coin", 18, Palette.GOLD_STAR)
			coin.mouse_filter = Control.MOUSE_FILTER_IGNORE
			th.add_child(coin)
			var tl: Label = ProceduralUIFactory.label("+" + Tx.kr(wait), 13, Palette.UI_WOOD_DEEP)
			tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			th.add_child(tl)
			v.add_child(tag)
	var cap := PanelContainer.new()
	cap.name = "Caption"
	cap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(face, 14, false)
	sb.content_margin_left = 10.0
	sb.content_margin_right = 10.0
	sb.content_margin_top = 2.0
	sb.content_margin_bottom = 2.0
	cap.add_theme_stylebox_override("panel", sb)
	cap.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(cap)
	var l: Label = ProceduralUIFactory.label(cap_text, 14, ink)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cap.add_child(l)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 30)
	pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(pad)
	return btn


func _open_branch(b: Dictionary) -> void:
	push_page(Tx.t("ui_branch_number", {"number": int(b["number"])}), _branch_page.bind(b))


func _branch_page(body: VBoxContainer, b: Dictionary) -> void:
	var list: VBoxContainer = scroll_box(body)
	list.name = "BranchStory"
	var c := CenterContainer.new()
	list.add_child(c)
	var art := ShopFrontArt.new()
	art.custom_minimum_size = Vector2(200, 200)
	art.tier = clampi(int(b.get("tier", 1)), 1, 5)
	c.add_child(art)
	var loc: LocationDefinition = DataRegistry.location_by_tier(art.tier)
	var title: Label = ProceduralUIFactory.title("%s · %s" % [sim.bakery_name, Tx.t(String(loc.localization_key))], 22)
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	list.add_child(title)
	var current: bool = bool(b.get("current", false))
	if not current:
		var visit: Button = ProceduralUIFactory.icon_text_button("shop", Tx.t("ui_map_visit", {"number": int(b["number"])}), "primary", 22, 18)
		visit.name = "Visit"
		visit.custom_minimum_size = Vector2(0, 60)
		visit.pressed.connect(_visit.bind(int(b["number"])))
		list.add_child(visit)
	if bool(b.get("unknown", false)) or (not current and (b.get("state", {}) as Dictionary).is_empty()):
		var lost: Label = lbl(list, Tx.t("ui_map_unknown" if bool(b.get("unknown", false)) else "ui_map_rebuild"), 15, Palette.TEXT_MUTED, true)
		lost.name = "Rebuild"
		lost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if bool(b.get("unknown", false)):
			return
	var rows: Array = []
	if current:
		rows.append(["star", Tx.t("ui_map_stars_now"), Tx.big(float(b.get("stars", 0)))])
		if int(b.get("stars_earned", 0)) > 0:
			rows.append(["star", Tx.t("ui_map_stars"), Tx.big(float(b.get("stars_earned", 0)))])
	else:
		rows.append(["star", Tx.t("ui_map_stars"), Tx.big(float(b.get("stars", 0)))])
		rows.append(["coin", Tx.t("ui_map_waiting"), Tx.kr(_waiting(b))])
	rows.append(["coin", Tx.t("ui_map_earned"), Tx.kr(float(b.get("earned", 0.0)))])
	rows.append(["bolt", Tx.t("ui_map_rate"), Tx.t("ui_kr_per_second", {"amount": Tx.rate(float(b.get("rate", 0.0)))})])
	rows.append(["sun", Tx.t("ui_map_days"), Tx.t("ui_map_days_value", {"from": maxi(1, int(b.get("opened_day", 1)))})])
	for r: Array in rows:
		var row: HBoxContainer = UISheet.row(list, str(r[1]), "", ProceduralUIFactory.badge(str(r[0]), Palette.HONEY_SOFT, Palette.HONEY_DEEP, 44))
		var val: Label = lbl(row, str(r[2]), 18, Palette.UI_WOOD_DEEP)
		val.add_theme_font_override("font", ProceduralUIFactory.display_font())


## Tombol Visit: pindah ke cabang `n` di balik layar loading.
func _visit(n: int) -> void:
	if game != null:
		game.visit_branch(n)


## Satu jalan kota: rumput, pohon kecil, dan jalan beraspal bergaris di bawah
## kavling-kavlingnya. Flat: bidang warna polos.
class StreetRow:
	extends PanelContainer
	var lots: HBoxContainer = null
	var index: int = 0

	func _init() -> void:
		add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		lots = HBoxContainer.new()
		lots.name = "Lots"
		lots.add_theme_constant_override("separation", 8)
		add_child(lots)

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		var road_h: float = 34.0
		draw_rect(Rect2(0.0, 0.0, w, h - road_h), Palette.GRASS.lightened(0.15))
		# Pohon bulat di antara kavling.
		for k in range(1, 3):
			var x: float = w * float(k) / 3.0
			draw_circle(Vector2(x, h - road_h - 26.0), 13.0, Palette.LEAF_DEEP if (k + index) % 2 == 0 else Palette.LEAF, true, -1.0, true)
			draw_rect(Rect2(x - 2.0, h - road_h - 14.0, 4.0, 12.0), Palette.TRUNK)
		draw_rect(Rect2(0.0, h - road_h, w, road_h), Palette.ASPHALT)
		var dash: float = 26.0
		var x2: float = 8.0 + float(index % 2) * dash
		while x2 < w:
			draw_rect(Rect2(x2, h - road_h * 0.5 - 2.0, dash * 0.6, 4.0), Palette.ROAD_PAINT)
			x2 += dash * 1.6
