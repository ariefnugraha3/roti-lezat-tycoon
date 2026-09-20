class_name DailySummaryScreen
extends Control
## Laporan Harian (GDD 11) — kertas nota vintage yang muncul tepat pukul 18:00.
##
## Tata letaknya mengikuti GDD 11.1 baris demi baris, ditambah emoji mood
## (11.2), panel sorotan (11.3), catatan Pak Lurah (11.4), dan tiga tombol aksi
## (11.5) yang mengarahkan alur ke Pasar / Karyawan / hari berikutnya (11.6).

var _ledger: Dictionary = {}
var _main: Node = null


func setup(args: Dictionary) -> void:
	_ledger = args.get("ledger", {})
	_main = _find_main()
	_rebuild()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()

	var bg := ColorRect.new()
	bg.color = Color(0.0, 0.0, 0.0, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)

	var nota: PanelContainer = ProceduralUIFactory.parchment_panel()
	nota.custom_minimum_size = Vector2(560, 0)
	center.add_child(nota)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	var isi: Node = ProceduralUIFactory.content_of(nota)
	isi.add_child(v)

	_header(v)
	_mood_banner(v)
	v.add_child(ProceduralUIFactory.dashed_separator())
	_income(v)
	v.add_child(ProceduralUIFactory.dashed_separator())
	_expenses(v)
	v.add_child(ProceduralUIFactory.dashed_separator())
	_bottom_line(v)
	v.add_child(ProceduralUIFactory.dashed_separator())
	_statistics(v)
	_highlights(v)
	_lurah_note(v)
	_actions(v)

	# Nota "dicetak": muncul dengan pantulan lembut (GDD 11.7).
	nota.scale = Vector2(0.92, 0.92)
	nota.pivot_offset = nota.size * 0.5
	var tw := create_tween()
	tw.tween_property(nota, "scale", Vector2.ONE, 0.32) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioBus.sfx("paper")
	AudioBus.start_music("summary")


func _g(key: String, fallback: Variant = 0) -> Variant:
	return _ledger.get(key, fallback)


func _line(parent: Node, kiri: String, kanan: String, size: int = 15,
		warna: Color = Palette.TEXT) -> void:
	var h := HBoxContainer.new()
	var a: Label = ProceduralUIFactory.typewriter_label(kiri, size, warna)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(a)
	var b: Label = ProceduralUIFactory.typewriter_label(kanan, size, warna)
	b.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(b)
	parent.add_child(h)


func _sub(parent: Node, teks: String) -> void:
	var l: Label = ProceduralUIFactory.typewriter_label(
		"   └ " + teks, 13, Palette.TEXT_MUTED)
	parent.add_child(l)


func _header(v: VBoxContainer) -> void:
	var hari: int = int(_g("day", GameState.day))
	var judul: Label = ProceduralUIFactory.title("ROTI LEZAT — LAPORAN HARI KE-%d" % hari, 22)
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(judul)

	var cuaca_id: String = String(_g("weather", GameState.weather))
	var cuaca: String = String(WeatherDB.entry(cuaca_id).get("name", cuaca_id))
	var tgl: Label = ProceduralUIFactory.typewriter_label(
		"%s  •  Cuaca: %s" % [GameConfig.date_label(hari), cuaca], 14, Palette.TEXT_MUTED)
	tgl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(tgl)


## GDD 11.2 — wajah besar yang merangkum hari itu.
func _mood_banner(v: VBoxContainer) -> void:
	var mood: Dictionary = _g("mood", {})
	if mood.is_empty():
		return
	var pc := PanelContainer.new()
	var warna: Color = _mood_color(mood)
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(warna, 18, false))
	v.add_child(pc)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	m.add_child(h)
	pc.add_child(m)

	h.add_child(ProceduralUIFactory.icon(
		String(mood.get("icon", "happy")), 44, Palette.TEXT))
	var l: Label = ProceduralUIFactory.label(String(mood.get("text", "")), 16)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)


## `bg_color` datang sebagai Color dari sinyal langsung, tapi sebagai String hex
## bila dibaca dari GameState.history (JSON tidak bisa menyimpan Color).
func _mood_color(mood: Dictionary) -> Color:
	var raw: Variant = mood.get("bg_color", Palette.PANEL)
	if raw is Color:
		return raw
	if raw is String:
		var s: String = raw
		if s.begins_with("#") or s.length() >= 6:
			return Color.html(s)
	return Palette.PANEL


func _income(v: VBoxContainer) -> void:
	v.add_child(ProceduralUIFactory.typewriter_label("PEMASUKAN", 15, Palette.SUCCESS))
	_line(v, "Penjualan Toko Fisik", "+" + GameConfig.kr(float(_g("income_store", 0.0))))
	var best: String = String(_g("best_recipe", ""))
	if best != "":
		_sub(v, "Roti Terlaris: %s (%d buah)" % [
			String(RecipeDB.entry(best).get("name", best)), int(_g("best_recipe_count", 0))])
	_line(v, "Pesanan Online (RotiFood)", "+" + GameConfig.kr(float(_g("income_delivery", 0.0))))
	_sub(v, "Total Order Selesai: %d pesanan" % int(_g("delivery_done", 0)))
	_sub(v, "Tip Delivery Bonus: +%s" % GameConfig.kr(float(_g("tips", 0.0))))
	_line(v, "TOTAL PEMASUKAN", "+" + GameConfig.kr(float(_g("total_income", 0.0))),
		16, Palette.SUCCESS)


func _expenses(v: VBoxContainer) -> void:
	v.add_child(ProceduralUIFactory.typewriter_label("PENGELUARAN", 15, Palette.DANGER))
	_line(v, "Bahan Baku Terpakai", "-" + GameConfig.kr(float(_g("spent_ingredients", 0.0))))
	_line(v, "Biaya Utilitas (Listrik+Gas)", "-" + GameConfig.kr(float(_g("utility", 0.0))))
	_line(v, "Gaji Karyawan", "-" + GameConfig.kr(float(_g("salary", 0.0))))
	for d_v in _g("salary_detail", []):
		var d: Dictionary = d_v
		_sub(v, "%s (%s T%d): -%s" % [
			String(d.get("name", "")), String(d.get("role", "")).capitalize(),
			int(d.get("tier", 1)), GameConfig.kr(float(d.get("salary", 0.0)))])
	_line(v, "TOTAL PENGELUARAN", "-" + GameConfig.kr(float(_g("total_expense", 0.0))),
		16, Palette.DANGER)


func _bottom_line(v: VBoxContainer) -> void:
	var laba: float = float(_g("profit", 0.0))
	var warna: Color = Palette.SUCCESS if laba >= 0.0 else Palette.DANGER
	var tanda: String = "+" if laba >= 0.0 else ""
	_line(v, "LABA / RUGI HARI INI", tanda + GameConfig.kr(laba), 18, warna)
	_line(v, "SALDO AKHIR", GameConfig.kr(float(_g("balance", GameState.coins))), 18)


func _statistics(v: VBoxContainer) -> void:
	v.add_child(ProceduralUIFactory.typewriter_label("STATISTIK HARI INI", 15, Palette.TEXT_MUTED))
	_line(v, "Total Pelanggan Fisik", "%d orang" % int(_g("customers_total", 0)), 14)
	_line(v, "Order Delivery Selesai", "%d pesanan" % int(_g("delivery_done", 0)), 14)
	_line(v, "Order Delivery Batal", "%d pesanan" % int(_g("delivery_cancelled", 0)), 14)
	_line(v, "Total Roti Terjual", "%d buah" % int(_g("bread_sold", 0)), 14)
	_line(v, "Roti Tidak Laku (Sisa)", "%d buah" % int(_g("bread_left", 0)), 14)
	_line(v, "Roti Gosong", "%d buah" % int(_g("burned", 0)), 14)
	_line(v, "Rating Toko Hari Ini",
		"%.1f / 5.0  (%+.2f)" % [float(_g("rating_store", 0.0)), float(_g("rating_delta", 0.0))], 14)
	_line(v, "Rating RotiFood Hari Ini",
		"%.1f / 5.0  (%+.2f)" % [float(_g("rating_rotifood", 0.0)), float(_g("rotifood_delta", 0.0))], 14)


## GDD 11.3 — maksimal 3 kotak "Momen Istimewa".
func _highlights(v: VBoxContainer) -> void:
	var list: Array = _g("highlights", [])
	if list.is_empty():
		return
	v.add_child(ProceduralUIFactory.dashed_separator())
	v.add_child(ProceduralUIFactory.typewriter_label("SOROTAN HARI INI", 15, Palette.TEXT_MUTED))
	for item_v in list:
		var item: Dictionary = item_v
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		h.add_child(ProceduralUIFactory.icon(String(item.get("icon", "star")), 22, Palette.GOLD_STAR))
		var l: Label = ProceduralUIFactory.label(String(item.get("text", "")), 14)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(l)
		v.add_child(h)


## GDD 11.4 — sticky note kuning dari Pak Lurah.
func _lurah_note(v: VBoxContainer) -> void:
	var tip: String = String(_g("lurah_tip", ""))
	if tip == "":
		return
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.BUTTER_YELLOW, 14, true))
	v.add_child(pc)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 12)
	m.add_theme_constant_override("margin_top", 9)
	m.add_theme_constant_override("margin_bottom", 9)
	pc.add_child(m)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	m.add_child(h)
	h.add_child(ProceduralUIFactory.icon("note", 24, Palette.CARAMEL))
	var l: Label = ProceduralUIFactory.label("Pak Lurah: " + tip, 14, Palette.CARAMEL)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)


## GDD 11.5 — tiga tombol besar.
func _actions(v: VBoxContainer) -> void:
	v.add_child(ProceduralUIFactory.dashed_separator())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_child(h)

	var pasar: Button = ProceduralUIFactory.button("Buka Pasar", "primary")
	pasar.pressed.connect(func() -> void: ScreenRouter.go("market"))
	h.add_child(pasar)

	var staf: Button = ProceduralUIFactory.button("Kelola Karyawan", "secondary")
	staf.pressed.connect(func() -> void: ScreenRouter.go("staff"))
	h.add_child(staf)

	var lanjut: Button = ProceduralUIFactory.button("Lanjut ke Besok", "secondary")
	# GDD 11.5 catatan UX: tombol ini nonaktif bila gudang benar-benar kosong,
	# supaya pemain tidak terjebak memulai hari tanpa bahan sama sekali.
	var gudang_kosong: bool = GameState.pantry_total() <= 0
	lanjut.disabled = gudang_kosong
	if gudang_kosong:
		lanjut.tooltip_text = "Gudang kosong — belanja dulu di Pasar."
	lanjut.pressed.connect(_on_next_day)
	h.add_child(lanjut)

	if gudang_kosong:
		var w: Label = ProceduralUIFactory.label(
			"Gudang kosong. Mampir ke Pasar dulu sebelum lanjut.", 13, Palette.DANGER)
		w.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(w)


func _on_next_day() -> void:
	AudioBus.sfx("door")
	var sys: Dictionary = {}
	if _main != null and is_instance_valid(_main):
		var raw: Variant = _main.get("systems")
		if raw is Dictionary:
			sys = raw
	var day: Variant = sys.get("day")
	if day is DayCycle:
		(day as DayCycle).start_day()
	AudioBus.start_music("cozy")
	ScreenRouter.go("hud")


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
