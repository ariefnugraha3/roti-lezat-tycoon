class_name WelcomeBackScreen
extends UIScreen
## Popup Selamat Datang (GDD idle 9.5): lama pergi, penghasilan toko, sapaan Pak
## Lurah, dan Collect. KR-nya baru masuk saat Collect (OfflineManager.collect),
## disusul hujan koin. Back sama dengan Collect, jadi penghasilannya tidak
## pernah hilang; bila game ditinggal sebelum Collect, `pending` ikut tersimpan
## dan popup tampil lagi saat profil dimuat. Bila iklan berhadiah tersedia,
## Collect ×2 menggandakannya setelah iklan selesai (GDD idle 22.4).

var _double: Button = null
var _note: Label = null


## Lapisan sistem: tampil di atas lembar atau modal yang sedang terbuka tanpa
## menutupnya (GDD 28.2).
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var p: Dictionary = sim.offline.pending if sim != null else {}
	var amount: float = float(p.get("amount", 0.0))
	var away: float = float(p.get("away", 0.0))
	# Tabungan cabang yang baru dikunjungi (GDD idle §20 no. 78).
	var branch: int = int(p.get("branch", 0))
	var title: String = Tx.t("ui_welcome_back_branch_title", {"number": branch}) if branch > 0 else Tx.t("ui_welcome_back_title")
	var body: VBoxContainer = make_popup(title, Vector2(620, 480.0 + 240.0 * maxf(0.0, SettingsManager.text_scale() - 1.0)), false)
	var row: HBoxContainer = hbox(body, 22)
	var lurah := LurahPortrait.new()
	lurah.name = "Lurah"
	lurah.custom_minimum_size = Vector2(110, 110)
	row.add_child(lurah)
	var greet: Label = ProceduralUIFactory.label(Tx.t("ui_welcome_back_branch_lurah") if branch > 0 else Tx.t("ui_welcome_back_lurah"), 18, Palette.TEXT)
	greet.name = "Greeting"
	greet.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var bubble: PanelContainer = ProceduralUIFactory.speech_bubble(greet)
	bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bubble)
	var text: Label = lbl(body, Tx.t("ui_welcome_back_body", {"time": Tx.duration(away), "amount": Tx.kr(amount)}), 20, Palette.TEXT, true)
	text.name = "AwayText"
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Hadiahnya di pil mentega, supaya angka yang dikumpulkan paling menonjol.
	var center := CenterContainer.new()
	body.add_child(center)
	var prize := PanelContainer.new()
	prize.name = "Prize"
	var psb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.BUTTER_SOFT, 26, false)
	psb.content_margin_left = 16.0
	psb.content_margin_right = 26.0
	psb.content_margin_top = 6.0
	psb.content_margin_bottom = 6.0
	prize.add_theme_stylebox_override("panel", psb)
	center.add_child(prize)
	var h: HBoxContainer = hbox(prize, 10)
	h.add_child(ProceduralUIFactory.icon("coin", 44, Palette.GOLD_STAR))
	var amt: Label = lbl(h, "+" + Tx.kr(amount), 34, Palette.UI_WOOD_DEEP)
	amt.name = "Amount"
	if sim != null:
		var hours: String = _hours_text(sim.offline.cap_seconds())
		var percent: int = int(Money.round_half_up(sim.offline.efficiency() * 100.0))
		# Satu baris saja (GDD idle §20 no. 84): batas waktu yang terlampaui,
		# atau aturan batas dan efisiensinya.
		if away > float(p.get("seconds", 0.0)) + 1.0:
			var capped: Label = lbl(body, Tx.t("ui_welcome_back_capped", {"hours": hours, "percent": percent}), 16, Palette.TEXT_MUTED, true)
			capped.name = "Capped"
			capped.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		else:
			var info: Label = lbl(body, Tx.t("ui_offline_cap", {"hours": hours, "percent": percent}), 15, Palette.TEXT_MUTED, true)
			info.name = "CapInfo"
			info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	_note = lbl(body, "", 15, Palette.TEXT_MUTED, true)
	_note.name = "AdNote"
	_note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_note.visible = false
	var nav := HBoxContainer.new()
	nav.alignment = BoxContainer.ALIGNMENT_CENTER
	nav.add_theme_constant_override("separation", 12)
	body.add_child(nav)
	var b: Button = btn(nav, Tx.t("ui_collect"), "primary", _collect)
	b.name = "Collect"
	b.custom_minimum_size = Vector2(220, 64)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_double = AdButton.make(&"offline_double", Tx.t("ui_collect_double", {"mult": Tx.mult(_mult())}), "success", 22, 18)
	_double.custom_minimum_size.y = 64
	_double.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_double.pressed.connect(_collect_double)
	nav.add_child(_double)
	EventBus.sfx.emit(&"welcome_back_chime", &"")


func _process(_delta: float) -> void:
	AdButton.refresh(_double)


static func _mult() -> float:
	return float(Monetization.placement(&"offline_double").get("mult", 2.0))


## Tonton iklan, lalu Collect dengan pengali; iklan yang tidak selesai tidak
## memberi apa pun dan popup tetap terbuka (GDD idle 22.1).
func _collect_double() -> void:
	_double.disabled = true
	Monetization.show_rewarded(&"offline_double", func(ok: bool) -> void:
		if not is_inside_tree():
			return
		_double.disabled = false
		if ok:
			_collect(_mult())
		else:
			_note.text = Tx.t("ui_ad_failed")
			_note.visible = true)


static func _hours_text(seconds: float) -> String:
	var hours: float = seconds / 3600.0
	return str(int(hours)) if is_equal_approx(hours, roundf(hours)) else Tx.dec(hours, 1)


func _collect(mult: float = 1.0) -> void:
	var amount: float = sim.offline.collect(mult) if sim != null else 0.0
	close()
	if amount <= 0.0:
		return
	EventBus.sfx.emit(&"coin_shower", &"")
	if game != null and game.hud != null and not SettingsManager.reduced_motion():
		game.hud.coin_shower()


func on_back() -> bool:
	if Monetization.busy:
		return true
	_collect()
	return true
