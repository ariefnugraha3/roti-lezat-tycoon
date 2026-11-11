class_name TestPurchaseScreen
extends UIScreen
## Konfirmasi pembelian toko uji (GDD idle 22.2): nama produk, harga, isinya, dan
## catatan bahwa tidak ada uang yang ditarik. Buy = pembelian berhasil, Cancel
## (atau Back) = dibatalkan. `params.done(success)` dipanggil tepat sekali.

var _resolved: bool = false


func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var id: StringName = StringName(str(params.get("product", "")))
	var p: Dictionary = PremiumManager.product(id)
	var body: VBoxContainer = make_popup(Tx.t("ui_test_store_title"), Vector2(600, 420.0 + 160.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)), false)
	var head: HBoxContainer = hbox(body, 12)
	var badge: PanelContainer = ProceduralUIFactory.badge("gift", Palette.HONEY, Palette.FLOUR_WHITE, 56)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var t: Label = lbl(tv, product_title(p), 22, Palette.UI_WOOD_DEEP, true)
	t.name = "Product"
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var price: Label = lbl(tv, Monetization.price(id), 20, Palette.MATCHA_DEEP)
	price.name = "Price"
	for line: String in StoreScreen.contents(p):
		lbl(body, "• " + line, 16, Palette.TEXT, true)
	var note: Label = lbl(body, Tx.t("ui_test_store_note"), 15, Palette.TEXT_MUTED, true)
	note.name = "Note"
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var row: HBoxContainer = hbox(body, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cancel: Button = btn(row, Tx.t("ui_cancel"), "secondary", func() -> void: _finish(false))
	cancel.name = "Cancel"
	var buy: Button = btn(row, Tx.t("ui_test_store_buy"), "primary", func() -> void: _finish(true))
	buy.name = "Confirm"


## Nama produk untuk pembeli ("500 Golden Crumbs", "Baker's Club", ...).
static func product_title(p: Dictionary) -> String:
	if p.is_empty():
		return ""
	if str(p["kind"]) == "crumbs":
		return Tx.t("ui_reward_crumbs", {"n": Tx.big(float(p["crumbs"]))})
	return Tx.t(str(p["id"]))


func _finish(ok: bool) -> void:
	if _resolved:
		return
	_resolved = true
	var done: Callable = params.get("done", Callable())
	close()
	EventBus.sfx.emit(&"ui_confirm" if ok else &"ui_cancel", &"")
	if done.is_valid():
		done.call(ok)


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
