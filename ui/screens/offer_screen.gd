class_name OfferScreen
extends UIScreen
## Popup penawaran berbatas waktu (GDD idle 22.9): tampil sekali per penawaran,
## hanya saat tidak ada modal lain dan tutorial tidak berjalan. Isi paket, nilai
## ("×5 value"), sisa waktu, Buy dengan harga toko, dan Maybe later. Sesudahnya
## penawaran menunggu di tab Offers lembar Store sampai waktunya habis.

var _id: StringName = &""
var _timer: Label = null


func build() -> void:
	_id = StringName(str(params.get("id", "")))
	var p: Dictionary = PremiumManager.product(_id)
	var body: VBoxContainer = make_popup(Tx.t(String(_id)), Vector2(620, 560.0 + 200.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)))
	var c := CenterContainer.new()
	body.add_child(c)
	var art := HBoxContainer.new()
	art.add_theme_constant_override("separation", 12)
	c.add_child(art)
	art.add_child(ProceduralUIFactory.icon("gift", 96, Palette.STRAWBERRY))
	art.add_child(ProceduralUIFactory.icon("crumb", 72, Palette.GOLD_STAR))
	var tag: PanelContainer = ProceduralUIFactory.pill("star", Tx.t("ui_store_value", {"mult": int(p.get("value_mult", 1))}), Palette.STRAWBERRY, Palette.FLOUR_WHITE, 16)
	tag.name = "Value"
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	body.add_child(tag)
	for line: String in StoreScreen.contents(p):
		var l: Label = lbl(body, "• " + line, 18, Palette.TEXT, true)
		l.name = "Line"
	_timer = lbl(body, "", 16, Palette.STRAWBERRY_DEEP, true)
	_timer.name = "Timer"
	_timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var row: HBoxContainer = hbox(body, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var later: Button = btn(row, Tx.t("ui_offer_later"), "secondary", close)
	later.name = "Later"
	var price: String = Monetization.price(_id)
	var buy: Button = btn(row, Tx.t("ui_store_buy_price", {"price": price}) if price != "" else Tx.t("ui_store_buy"), "primary", _buy)
	buy.name = "Buy"
	_tick()


func _process(_delta: float) -> void:
	_tick()


func _tick() -> void:
	if _timer == null:
		return
	var left: float = Monetization.offer_left(_id)
	_timer.text = Tx.t("ui_store_ends_in", {"time": Tx.timer(left)})
	if left <= 0.0 and is_inside_tree():
		close()


func _buy() -> void:
	Monetization.buy(_id, func(ok: bool) -> void:
		if not ok:
			EventBus.notify.emit(1, "ui_store_failed", {}, &"warning")
			return
		if is_inside_tree():
			close())
