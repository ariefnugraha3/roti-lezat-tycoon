class_name MarketingScreen
extends Control
## Kampanye Pemasaran (GDD 8).
##
## Hanya satu kampanye boleh aktif, biaya dibayar di muka, masa aktif 5 hari.
## Layar ini juga menampilkan peringatan risiko GDD 8.3 secara eksplisit: iklan
## tinggi tanpa kapasitas produksi justru menurunkan reputasi.

var _content: VBoxContainer = null
var _main: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build_shell()
	_render()


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	_render()


func _build_shell() -> void:
	var popup: Control = ProceduralUIFactory.popup("Pemasaran & Iklan")
	add_child(popup)
	var head: HBoxContainer = popup.get_meta("head")
	var v: VBoxContainer = popup.get_meta("body")
	(popup.get_meta("scrim") as Control).gui_input.connect(_on_scrim_input)

	var tutup: Button = ProceduralUIFactory.icon_button("cross", "Tutup", "ghost", 22)
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


func _on_close() -> void:
	AudioBus.sfx("tap")
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


## Ketukan pada kaca gelap di luar kartu = tutup (GDD 12.4: satu ketukan).
func _on_scrim_input(event: InputEvent) -> void:
	var tekan: bool = (event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tekan:
		_on_close()


func _render() -> void:
	if _content == null:
		return
	for c in _content.get_children():
		c.queue_free()

	var mkt: Object = _systems().get("mkt")
	var aktif: bool = mkt != null and mkt.has_method("is_active") and bool(mkt.call("is_active"))

	if aktif:
		var tier: int = int(mkt.call("active_tier"))
		var sisa: int = int(mkt.call("days_left"))
		var e: Dictionary = MarketingDB.entry(tier)
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel",
			ProceduralUIFactory.panel(Palette.PASTEL_MINT, 18, true))
		var m := MarginContainer.new()
		m.add_theme_constant_override("margin_left", 14)
		m.add_theme_constant_override("margin_right", 14)
		m.add_theme_constant_override("margin_top", 10)
		m.add_theme_constant_override("margin_bottom", 10)
		pc.add_child(m)
		var iv := VBoxContainer.new()
		m.add_child(iv)
		iv.add_child(ProceduralUIFactory.label(
			"Kampanye aktif: %s" % String(e.get("name", "")), 18))
		iv.add_child(ProceduralUIFactory.label(
			"Sisa %d dari %d hari  •  Pengunjung +%d%%"
			% [sisa, MarketingDB.DURATION_DAYS,
				int(float(e.get("visitor_boost", 0.0)) * 100.0)], 14, Palette.TEXT_MUTED))
		_content.add_child(pc)
		_content.add_child(ProceduralUIFactory.label(
			"Hanya satu kampanye boleh berjalan. Tunggu sampai selesai.",
			13, Palette.TEXT_MUTED))
		_content.add_child(ProceduralUIFactory.dashed_separator())

	# GDD 8.3 — peringatan risiko, ditulis terus terang.
	var warn := PanelContainer.new()
	warn.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.BUTTER_YELLOW, 14, false))
	var wm := MarginContainer.new()
	wm.add_theme_constant_override("margin_left", 12)
	wm.add_theme_constant_override("margin_right", 12)
	wm.add_theme_constant_override("margin_top", 8)
	wm.add_theme_constant_override("margin_bottom", 8)
	warn.add_child(wm)
	var wl: Label = ProceduralUIFactory.label(
		"Pedang bermata dua: iklan tier tinggi tanpa kapasitas dapur dan kasir yang memadai "
		+ "akan membuat antrean meluber, pelanggan kabur, dan reputasi justru anjlok. "
		+ "Pastikan stok roti dan bahan baku siap sebelum menyalakan iklan.",
		13, Palette.CARAMEL)
	wl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	wm.add_child(wl)
	_content.add_child(warn)

	for tier in range(1, 6):
		_content.add_child(_campaign_card(tier, aktif, mkt))


func _campaign_card(tier: int, ada_aktif: bool, mkt: Object) -> Control:
	var e: Dictionary = MarketingDB.entry(tier)
	var syarat: int = int(e.get("req_location", tier))
	var boleh_lokasi: bool = GameState.location_tier >= syarat
	var harga: int = int(e.get("cost", 0))
	var mampu: bool = GameState.coins >= float(harga)

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL if boleh_lokasi else Palette.PANEL_ALT, 18, true))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	pc.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	m.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(ProceduralUIFactory.icon("megaphone", 26, Palette.CARAMEL))
	var nama: Label = ProceduralUIFactory.label(
		"Tier %d: %s" % [tier, String(e.get("name", ""))], 17)
	nama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nama)
	v.add_child(head)

	v.add_child(ProceduralUIFactory.label(
		"%s untuk 5 hari  (≈ %s / hari)  •  Pengunjung +%d%%  •  Rating +%.2f / hari"
		% [GameConfig.kr(float(harga)), GameConfig.kr(float(e.get("per_day", 0))),
			int(float(e.get("visitor_boost", 0.0)) * 100.0),
			float(e.get("rating_per_day", 0.0))], 13, Palette.TEXT_MUTED))

	var efek: Label = ProceduralUIFactory.label(String(e.get("effect", "")), 13)
	efek.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(efek)

	if not boleh_lokasi:
		v.add_child(ProceduralUIFactory.label(
			"Butuh toko Tier %d." % syarat, 13, Palette.DANGER))
		return pc

	var b: Button = ProceduralUIFactory.button(
		"Luncurkan " + GameConfig.kr(float(harga)), "primary")
	b.disabled = ada_aktif or not mampu
	if ada_aktif:
		b.tooltip_text = "Sudah ada kampanye yang berjalan."
	elif not mampu:
		b.tooltip_text = "Koin tidak cukup."
	b.pressed.connect(_on_launch.bind(tier, mkt))
	v.add_child(b)
	return pc


func _on_launch(tier: int, mkt: Object) -> void:
	if mkt == null or not mkt.has_method("start_campaign"):
		return
	if bool(mkt.call("start_campaign", tier)):
		AudioBus.sfx("coin")
		EventBus.toast.emit("Kampanye diluncurkan!", "megaphone")
	else:
		EventBus.toast.emit("Kampanye tidak bisa dijalankan.", "warning")
	_render()


func _systems() -> Dictionary:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return {}
	var raw: Variant = _main.get("systems")
	return raw if raw is Dictionary else {}


func _find_main() -> Node:
	var t := get_tree()
	if t == null:
		return null
	var node: Node = t.current_scene
	if node is Main:
		return node
	if node != null:
		for c in node.get_children():
			if c is Main:
				return c
	return null
