class_name WelcomeBackScreen
extends UIScreen
## Popup Selamat Datang (GDD idle 9.5): lama pergi, penghasilan toko, sapaan Pak
## Lurah, dan Collect. KR-nya baru masuk saat Collect (OfflineManager.collect),
## disusul hujan koin. Back sama dengan Collect, jadi penghasilannya tidak
## pernah hilang; bila game ditinggal sebelum Collect, `pending` ikut tersimpan
## dan popup tampil lagi saat profil dimuat.


## Lapisan sistem: tampil di atas lembar atau modal yang sedang terbuka tanpa
## menutupnya (GDD 28.2).
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var p: Dictionary = sim.offline.pending if sim != null else {}
	var amount: float = float(p.get("amount", 0.0))
	var away: float = float(p.get("away", 0.0))
	var body: VBoxContainer = make_popup(Tx.t("ui_welcome_back_title"), Vector2(620, 480.0 + 240.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)), false)
	var row: HBoxContainer = hbox(body, 14)
	var lurah := LurahPortrait.new()
	lurah.name = "Lurah"
	lurah.custom_minimum_size = Vector2(120, 120)
	row.add_child(lurah)
	var greet: Label = lbl(row, Tx.t("ui_welcome_back_lurah"), 18, Palette.TEXT, true)
	greet.name = "Greeting"
	greet.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var text: Label = lbl(body, Tx.t("ui_welcome_back_body", {"time": Tx.duration(away), "amount": Tx.kr(amount)}), 20, Palette.TEXT, true)
	text.name = "AwayText"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var center := CenterContainer.new()
	body.add_child(center)
	var h: HBoxContainer = hbox(center, 10)
	h.add_child(ProceduralUIFactory.icon("coin", 44, Palette.GOLD_STAR))
	var amt: Label = lbl(h, "+" + Tx.kr(amount), 34, Palette.UI_WOOD)
	amt.name = "Amount"
	if sim != null:
		if away > float(p.get("seconds", 0.0)) + 1.0:
			var capped: Label = lbl(body, Tx.t("ui_welcome_back_capped", {"hours": _hours_text(sim.offline.cap_seconds())}), 16, Palette.TEXT_MUTED, true)
			capped.name = "Capped"
			capped.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var info: Label = lbl(body, Tx.t("ui_offline_cap", {"hours": _hours_text(sim.offline.cap_seconds()),
			"percent": int(Money.round_half_up(sim.offline.efficiency() * 100.0))}), 15, Palette.TEXT_MUTED, true)
		info.name = "CapInfo"
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var nav := CenterContainer.new()
	body.add_child(nav)
	var b: Button = btn(nav, Tx.t("ui_collect"), "primary", _collect)
	b.name = "Collect"
	b.custom_minimum_size = Vector2(260, 64)
	EventBus.sfx.emit(&"welcome_back_chime", &"")


static func _hours_text(seconds: float) -> String:
	var hours: float = seconds / 3600.0
	return str(int(hours)) if is_equal_approx(hours, roundf(hours)) else "%.1f" % hours


func _collect() -> void:
	var amount: float = sim.offline.collect() if sim != null else 0.0
	close()
	if amount <= 0.0:
		return
	EventBus.sfx.emit(&"coin_shower", &"")
	if game != null and game.hud != null and not SettingsManager.reduced_motion():
		game.hud.coin_shower()


func on_back() -> bool:
	_collect()
	return true
