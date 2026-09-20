class_name MarketScreen
extends Control
## Pasar Bahan Baku (GDD 7 "Pasar Bahan Baku", 5.2, 5.1, 6).
##
## Tampilan papan tulis kapur toko kelontong tempo dulu. Tiga tab:
##   • Bahan Baku — katalog harga tetap + tombol beli (+ / - / Max)
##   • Peralatan  — upgrade mixer / oven / display
##   • Toko       — upgrade tier lokasi
##
## Harga bahan TIDAK pernah berfluktuasi (GDD 5.2) — itu janji desain, bukan
## kebetulan, jadi layar ini tidak punya konsep "harga hari ini".

var _tab_box: HBoxContainer = null
var _content: VBoxContainer = null
var _pantry_bar_host: Control = null
var _coin_label: Label = null
var _tab: String = "bahan"
## Jumlah yang dipilih pemain per bahan sebelum menekan Beli.
var _pending: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build_shell()
	_render()


func setup(_args: Dictionary) -> void:
	_pending.clear()
	_render()


func _build_shell() -> void:
	var papan: PanelContainer = ProceduralUIFactory.chalkboard_panel()
	papan.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	papan.offset_left = safe.x + 20.0
	papan.offset_top = safe.y + 16.0
	papan.offset_right = -(safe.z + 20.0)
	papan.offset_bottom = -(safe.w + 16.0)
	add_child(papan)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	ProceduralUIFactory.content_of(papan).add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)

	var judul: Label = ProceduralUIFactory.chalk_label("Pasar Bahan Baku", 26)
	judul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(judul)

	head.add_child(ProceduralUIFactory.icon("coin", 24, Palette.GOLD_STAR))
	_coin_label = ProceduralUIFactory.chalk_label(GameConfig.kr(GameState.coins), 20)
	head.add_child(_coin_label)

	var tutup: Button = ProceduralUIFactory.button("Tutup", "ghost")
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	_pantry_bar_host = Control.new()
	_pantry_bar_host.custom_minimum_size = Vector2(0, 28)
	v.add_child(_pantry_bar_host)

	_tab_box = HBoxContainer.new()
	_tab_box.add_theme_constant_override("separation", 8)
	v.add_child(_tab_box)
	for t_v in [["bahan", "Bahan Baku"], ["alat", "Peralatan"], ["toko", "Toko"]]:
		var t: Array = t_v
		var b: Button = ProceduralUIFactory.button(String(t[1]), "secondary")
		b.pressed.connect(_on_tab.bind(String(t[0])))
		_tab_box.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 6)
	scroll.add_child(_content)


func _on_tab(t: String) -> void:
	_tab = t
	AudioBus.sfx("tap")
	_render()


func _on_close() -> void:
	AudioBus.sfx("tap")
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


# ===========================================================================
# RENDER
# ===========================================================================

func _render() -> void:
	if _content == null:
		return
	_coin_label.text = GameConfig.kr(GameState.coins)
	_render_pantry_bar()
	for c in _content.get_children():
		c.queue_free()
	match _tab:
		"bahan": _render_ingredients()
		"alat": _render_equipment()
		"toko": _render_location()

	for i in _tab_box.get_child_count():
		var b: Button = _tab_box.get_child(i) as Button
		if b != null:
			b.modulate = Color.WHITE if _tab_index() == i else Color(1, 1, 1, 0.6)


func _tab_index() -> int:
	match _tab:
		"bahan": return 0
		"alat": return 1
		"toko": return 2
	return 0


func _render_pantry_bar() -> void:
	for c in _pantry_bar_host.get_children():
		c.queue_free()
	var bar: Control = ProceduralUIFactory.pantry_bar(
		GameState.pantry_total(), GameState.pantry_capacity())
	bar.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pantry_bar_host.add_child(bar)


func _render_ingredients() -> void:
	for kategori_v in [["dasar", "Bahan Dasar"], ["isian", "Isian & Topping"],
			["premium", "Premium & Artisan"]]:
		var kategori: Array = kategori_v
		var ids: Array[String] = IngredientDB.by_category(String(kategori[0]))
		if ids.is_empty():
			continue
		_content.add_child(ProceduralUIFactory.chalk_label(String(kategori[1]), 18))
		for id in ids:
			_content.add_child(_ingredient_row(id))
		_content.add_child(ProceduralUIFactory.dashed_separator(Palette.FLOUR_WHITE))


func _ingredient_row(id: String) -> Control:
	var e: Dictionary = IngredientDB.entry(id)
	var harga: int = int(e.get("price", 0))
	var punya: int = int(GameState.pantry.get(id, 0))
	var mau: int = int(_pending.get(id, 0))

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL_ALT, 14, false))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 6)
	m.add_theme_constant_override("margin_bottom", 6)
	pc.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	m.add_child(h)

	var kiri := VBoxContainer.new()
	kiri.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kiri.add_child(ProceduralUIFactory.label(String(e.get("name", id)), 16))
	kiri.add_child(ProceduralUIFactory.label(
		"%s / %s   •   punya: %d" % [GameConfig.kr(float(harga)),
			String(e.get("unit", "porsi")), punya], 12, Palette.TEXT_MUTED))
	h.add_child(kiri)

	var minus: Button = ProceduralUIFactory.button("−", "ghost")
	minus.pressed.connect(_on_adjust.bind(id, -1))
	h.add_child(minus)

	var jml: Label = ProceduralUIFactory.label(str(mau), 18)
	jml.custom_minimum_size = Vector2(46, 0)
	jml.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(jml)

	var plus: Button = ProceduralUIFactory.button("+", "ghost")
	plus.pressed.connect(_on_adjust.bind(id, 1))
	h.add_child(plus)

	var maxb: Button = ProceduralUIFactory.button("Max", "ghost")
	maxb.pressed.connect(_on_max.bind(id))
	h.add_child(maxb)

	var beli: Button = ProceduralUIFactory.button(
		"Beli " + GameConfig.kr(float(harga * mau)), "primary")
	beli.disabled = mau <= 0 or GameState.coins < float(harga * mau)
	beli.pressed.connect(_on_buy.bind(id))
	h.add_child(beli)

	return pc


func _max_affordable(id: String) -> int:
	var harga: int = IngredientDB.price(id)
	if harga <= 0:
		return 0
	var muat: int = GameState.pantry_capacity() - GameState.pantry_total()
	var mampu: int = int(GameState.coins / float(harga))
	return maxi(0, mini(muat, mampu))


func _on_adjust(id: String, delta: int) -> void:
	var mau: int = int(_pending.get(id, 0)) + delta
	_pending[id] = clampi(mau, 0, _max_affordable(id))
	AudioBus.sfx("tap")
	_render()


func _on_max(id: String) -> void:
	_pending[id] = _max_affordable(id)
	AudioBus.sfx("tap")
	_render()


func _on_buy(id: String) -> void:
	var mau: int = int(_pending.get(id, 0))
	if mau <= 0:
		return
	var harga: int = IngredientDB.price(id)
	var total: float = float(harga * mau)
	if not GameState.spend_coins(total, "beli_bahan"):
		EventBus.toast.emit("Koin tidak cukup.", "warning")
		return
	var masuk: int = GameState.pantry_add(id, mau)
	if masuk < mau:
		# Gudang penuh: kembalikan uang untuk yang tidak muat (GDD 5.2.2).
		GameState.add_coins(float((mau - masuk) * harga), "refund_gudang_penuh")
		EventBus.toast.emit("Gudang penuh, sebagian dikembalikan.", "box")
	else:
		AudioBus.sfx("coin")
	_pending[id] = 0
	_render()


func _render_equipment() -> void:
	for kind_v in [["mixer", "Mixer", GameState.mixer_tier],
			["oven", "Oven", GameState.oven_tier],
			["display", "Rak Display", GameState.display_tier]]:
		var kind: Array = kind_v
		var id: String = String(kind[0])
		var tier: int = int(kind[2])
		_content.add_child(ProceduralUIFactory.chalk_label(String(kind[1]), 18))

		var sekarang: Dictionary = EquipmentDB.entry(id, tier)
		_content.add_child(ProceduralUIFactory.label(
			"Sekarang: %s (Tier %d) — %s" % [String(sekarang.get("name", "")), tier,
				_equip_value_text(id, tier)], 13, Palette.TEXT_MUTED))

		if tier >= 5:
			_content.add_child(ProceduralUIFactory.label(
				"Sudah tier tertinggi.", 13, Palette.SUCCESS))
		else:
			_content.add_child(_upgrade_row(id, tier + 1))
		_content.add_child(ProceduralUIFactory.dashed_separator(Palette.FLOUR_WHITE))


func _equip_value_text(kind: String, tier: int) -> String:
	match kind:
		"mixer": return "%.0f detik proses" % EquipmentDB.mixer_time(tier)
		"oven": return "%.0f detik panggang" % EquipmentDB.oven_time(tier)
		"display": return "%d roti per rak" % EquipmentDB.rack_capacity(tier)
	return ""


func _upgrade_row(kind: String, tier: int) -> Control:
	var e: Dictionary = EquipmentDB.entry(kind, tier)
	var harga: int = int(e.get("price", 0))

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var kiri := VBoxContainer.new()
	kiri.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kiri.add_child(ProceduralUIFactory.label(
		"Tier %d: %s" % [tier, String(e.get("name", ""))], 15))
	kiri.add_child(ProceduralUIFactory.label(
		_equip_value_text(kind, tier), 12, Palette.TEXT_MUTED))
	h.add_child(kiri)

	var b: Button = ProceduralUIFactory.button(
		"Upgrade " + GameConfig.kr(float(harga)), "primary")
	b.disabled = GameState.coins < float(harga)
	b.pressed.connect(_on_upgrade_equipment.bind(kind, tier, harga))
	h.add_child(b)
	return h


func _on_upgrade_equipment(kind: String, tier: int, harga: int) -> void:
	if not GameState.spend_coins(float(harga), "upgrade_" + kind):
		EventBus.toast.emit("Koin tidak cukup.", "warning")
		return
	match kind:
		"mixer": GameState.mixer_tier = tier
		"oven": GameState.oven_tier = tier
		"display": GameState.display_tier = tier
	AudioBus.sfx("coin")
	EventBus.upgrade_purchased.emit(kind, tier)
	EventBus.toast.emit("Peralatan naik ke Tier %d!" % tier, "trophy")
	_render()


func _render_location() -> void:
	var tier: int = GameState.location_tier
	var now: Dictionary = LocationDB.entry(tier)
	_content.add_child(ProceduralUIFactory.chalk_label(
		"Tier %d: %s" % [tier, String(now.get("name", ""))], 20))
	_content.add_child(ProceduralUIFactory.label(String(now.get("desc", "")), 13,
		Palette.TEXT_MUTED))
	_content.add_child(_location_stats(now))
	_content.add_child(ProceduralUIFactory.dashed_separator(Palette.FLOUR_WHITE))

	if tier >= 5:
		_content.add_child(ProceduralUIFactory.chalk_label(
			"Kamu sudah mencapai Mega Bakery Landmark. Luar biasa!", 16))
		return

	var next: Dictionary = LocationDB.entry(tier + 1)
	var harga: int = int(next.get("price", 0))
	_content.add_child(ProceduralUIFactory.chalk_label(
		"Berikutnya — Tier %d: %s" % [tier + 1, String(next.get("name", ""))], 18))
	_content.add_child(ProceduralUIFactory.label(String(next.get("desc", "")), 13,
		Palette.TEXT_MUTED))
	_content.add_child(_location_stats(next))

	var b: Button = ProceduralUIFactory.button(
		"Beli Putus " + GameConfig.kr(float(harga)), "primary")
	b.disabled = GameState.coins < float(harga)
	b.pressed.connect(_on_upgrade_location.bind(tier + 1, harga))
	_content.add_child(b)
	# GDD 6: beli putus, jadi tidak ada sewa harian sama sekali.
	_content.add_child(ProceduralUIFactory.label(
		"Status hak milik — tanpa biaya sewa harian.", 12, Palette.SUCCESS))


func _location_stats(loc: Dictionary) -> Control:
	var v := VBoxContainer.new()
	var baris: Array = [
		["Mixer / Oven", "%d / %d unit" % [int(loc.get("mixer_slots", 1)),
			int(loc.get("oven_slots", 1))]],
		["Rak Display", "%d rak" % int(loc.get("rack_slots", 1))],
		["Meja Kasir", "%d kasir" % int(loc.get("cashier_slots", 1))],
		["Maks. Karyawan", "%d kasir, %d baker" % [int(loc.get("max_kasir", 1)),
			int(loc.get("max_baker", 1))]],
		["Kapasitas Antrean", "%d pembeli" % int(loc.get("queue_cap", 4))],
		["Kapasitas Gudang", "%d unit" % int(loc.get("pantry_cap", 150))],
	]
	for b_v in baris:
		var b: Array = b_v
		var h := HBoxContainer.new()
		var a: Label = ProceduralUIFactory.label(String(b[0]), 13, Palette.TEXT_MUTED)
		a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(a)
		h.add_child(ProceduralUIFactory.label(String(b[1]), 13))
		v.add_child(h)
	return v


func _on_upgrade_location(tier: int, harga: int) -> void:
	if not GameState.spend_coins(float(harga), "upgrade_lokasi"):
		EventBus.toast.emit("Koin tidak cukup.", "warning")
		return
	GameState.location_tier = tier
	AudioBus.sfx("coin")
	EventBus.upgrade_purchased.emit("location", tier)
	EventBus.toast.emit("Selamat! Toko pindah ke %s." % String(
		LocationDB.entry(tier).get("name", "")), "trophy")
	_render()
