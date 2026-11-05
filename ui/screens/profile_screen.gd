class_name ProfileScreen
extends UIScreen
## Tiga profil save independen (v3.1 89.3; GDD idle 15.3). Mode "new" memilih profil kosong
## atau menimpa (dengan konfirmasi); mode "load" memuat profil.
##
## Menu utama tetap terlihat di balik kaca popup. Tiap profil satu kartu dengan
## warna penanda sendiri (madu, matcha, stroberi): gambar toko sesuai tier save
## dengan bulatan nomor profil di sudutnya, rincian toko di kanan, lalu satu
## tombol aksi lebar, tombol Export Save (kode save, GDD idle 20 no. 57), dan
## tombol hapus bundar di bawahnya. Import Save di bawah daftar.

## Warna penanda profil 1, 2, 3.
const ACCENTS: Array[Color] = [Palette.HONEY, Palette.MATCHA, Palette.STRAWBERRY]
const ART_SIZE: float = 112.0


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_profile_title"), Vector2(640, 790), true, Palette.SHEET)
	# Kabar dari langkah sebelumnya (mis. save yang baru diimpor).
	var note: String = str(params.get("note", ""))
	if note != "":
		var nl: Label = lbl(body, note, 18, Palette.MATCHA.darkened(0.35), true)
		nl.name = "Note"
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Bingkai potret (GDD idle 12.0.5): tiga kartu bertumpuk, satu per baris.
	var list: VBoxContainer = scroll_box(body)
	list.add_theme_constant_override("separation", 14)
	var headers: Array[Dictionary] = SaveManager.scan_headers()
	for i in headers.size():
		list.add_child(_card(i + 1, headers[i]))
	# Kode save dari perangkat lain (GDD idle 15.3, 20 no. 57).
	var foot := CenterContainer.new()
	body.add_child(foot)
	var imp: Button = ProceduralUIFactory.icon_text_button("clipboard", Tx.t("ui_import_save"), "secondary", 24, 20)
	imp.name = "ImportSave"
	imp.custom_minimum_size = Vector2(300, 60)
	imp.pressed.connect(func() -> void: host.open(&"import_save", {"on_done": refresh}))
	foot.add_child(imp)


func _card(n: int, h: Dictionary) -> Control:
	var pid: StringName = h["profile_id"]
	var accent: Color = ACCENTS[(n - 1) % ACCENTS.size()]
	var mode: String = str(params.get("mode", "load"))
	var exists: bool = bool(h.get("exists", false))
	var corrupt: bool = bool(h.get("corrupt", false))
	var classic: bool = bool(h.get("classic", false))
	var playable: bool = exists and not corrupt and not classic
	var card := PanelContainer.new()
	card.name = "Profile%d" % n
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 24, true)
	sb.set_content_margin_all(16.0)
	card.add_theme_stylebox_override("panel", sb)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 14)
	card.add_child(content)
	var row: HBoxContainer = hbox(content, 16)
	# Gambar toko roti sesuai tier lokasi save; profil kosong = siluet dengan "+".
	var art := ShopFrontArt.new()
	art.name = "ShopArt"
	art.custom_minimum_size = Vector2(ART_SIZE, ART_SIZE)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	art.tier = 0
	if playable:
		var ldef: LocationDefinition = DataRegistry.location(StringName(str(h.get("location_id", ""))))
		art.tier = ldef.tier if ldef != null else 1
	elif exists:
		art.tier = 1
		art.modulate = Color(1.0, 1.0, 1.0, 0.45)
	row.add_child(art)
	# Bulatan nomor profil di sudut kiri atas gambar toko.
	var num: PanelContainer = _number_badge(n, accent)
	art.add_child(num)
	num.position = Vector2(-6.0, -6.0)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_theme_constant_override("separation", 4)
	row.add_child(body)
	var slot: Label = lbl(body, Tx.t("ui_profile_slot", {"n": n}).to_upper(), 14, accent.darkened(0.25))
	slot.add_theme_font_override("font", ProceduralUIFactory.section_font())
	if not exists:
		var e: Label = lbl(body, Tx.t("ui_profile_empty"), 22, Palette.UI_WOOD_DEEP)
		e.add_theme_font_override("font", ProceduralUIFactory.display_font())
		lbl(body, Tx.t("ui_profile_empty_hint"), 16, Palette.TEXT_MUTED, true)
	elif classic:
		# Save tycoon v3.1 tidak didukung (GDD idle 15.3): hanya bisa dihapus.
		var cl: Label = lbl(body, Tx.t("ui_classic_save"), 18, Palette.TEXT_MUTED, true)
		cl.name = "ClassicSave"
	elif corrupt:
		lbl(body, Tx.t("ui_save_error"), 18, Palette.DANGER, true)
	else:
		var nm: Label = lbl(body, str(h.get("bakery_name", "")), 22, Palette.UI_WOOD_DEEP)
		nm.add_theme_font_override("font", ProceduralUIFactory.display_font())
		nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm.clip_text = true
		nm.custom_minimum_size = Vector2(100.0, 0.0)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var loc: String = str(h.get("location_id", ""))
		var where: String = Tx.t("ui_profile_day", {"day": h.get("day", 1)})
		if loc != "":
			where += " · " + (Tx.t(loc) if DataRegistry.has_text(loc) else loc)
		lbl(body, where, 16, Palette.TEXT_MUTED, true)
		var money: HBoxContainer = ProceduralUIFactory.icon_value("coin", Tx.kr(float(h.get("balance_kr", 0.0))), 22, 18, Palette.GOLDEN_CRUST)
		(money.get_meta("value") as Label).add_theme_color_override("font_color", Palette.GOLDEN_CRUST)
		body.add_child(money)
		var medals: Control = badge_row(h.get("badges", []))
		if medals != null:
			(medals as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
			body.add_child(medals)
		var when: String = str(h.get("last_played_at", "")).replace("T", " ").replace("Z", "")
		if when != "":
			lbl(body, Tx.t("ui_profile_last_played", {"when": when}), 14, Palette.TEXT_MUTED, true)
	# Aksi: satu tombol lebar (New Game / Continue) dan hapus bundar di kanan.
	var actions: HBoxContainer = hbox(content, 12)
	actions.name = "Actions"
	if mode == "new":
		var nb: Button = btn(actions, Tx.t("ui_main_new_game"), "success" if not exists else "primary", _on_new.bind(pid, exists))
		nb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	elif playable:
		var cb: Button = btn(actions, Tx.t("ui_main_continue"), "primary", _on_load.bind(pid))
		cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if exists:
		if actions.get_child_count() == 0:
			var gap := Control.new()
			gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			actions.add_child(gap)
		if playable:
			var ex: Button = ProceduralUIFactory.icon_button("clipboard", Tx.t("ui_save_code_export"), "secondary", 24, Palette.UI_WOOD_DEEP)
			ex.name = "Export"
			ex.custom_minimum_size = Vector2(56, 56)
			ex.pressed.connect(func() -> void: host.open(&"save_code", {"profile_id": pid}))
			actions.add_child(ex)
		var del: Button = ProceduralUIFactory.icon_button("cross", Tx.t("ui_profile_delete"), "danger", 24, Palette.FLOUR_WHITE)
		del.name = "Delete"
		del.custom_minimum_size = Vector2(56, 56)
		del.pressed.connect(_on_delete.bind(pid))
		actions.add_child(del)
	for b: Node in actions.get_children():
		if b is Button:
			(b as Control).custom_minimum_size.y = 56.0
	if actions.get_child_count() == 0:
		content.remove_child(actions)
		actions.free()
	return card


## Bulatan nomor profil berwarna penanda.
static func _number_badge(n: int, accent: Color) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.name = "SlotNumber"
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.custom_minimum_size = Vector2(38, 38)
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(accent, 19, false)
	sb.set_content_margin_all(0.0)
	pc.add_theme_stylebox_override("panel", sb)
	var l: Label = ProceduralUIFactory.label(str(n), 20, Palette.FLOUR_WHITE)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pc.add_child(l)
	return pc


func _on_new(pid: StringName, exists: bool) -> void:
	if exists:
		host.confirm(Tx.t("ui_profile_overwrite"), _start_new.bind(pid), true)
	else:
		_start_new(pid)


func _on_load(pid: StringName) -> void:
	close()
	game.load_profile(pid)


func _on_delete(pid: StringName) -> void:
	host.confirm(Tx.t("ui_profile_delete_confirm"), _do_delete.bind(pid), true)


func _do_delete(pid: StringName) -> void:
	SaveManager.delete_profile(pid)
	refresh()


## Bangun ulang daftar profil setelah isinya berubah (hapus, import), beserta
## kartu toko Main Menu di bawahnya supaya Continue tidak menunjuk save lama.
func refresh(note: String = "") -> void:
	var p: Dictionary = params.duplicate()
	p["note"] = note
	var h: ModalHost = host
	close()
	h.open(&"profiles", p)
	var menu: MainMenuScreen = h.screen(&"main_menu") as MainMenuScreen
	if menu != null:
		menu.refresh()


func _start_new(pid: StringName) -> void:
	close()
	host.open(&"new_game", {"profile_id": pid})


## Ringkasan toko satu save (pratinjau kode save, GDD idle 20 no. 57): gambar
## toko sesuai tier, nama, hari dan lokasi, saldo. `h` dari SaveManager.header_of.
static func summary_row(h: Dictionary, art_size: float) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "Summary"
	row.add_theme_constant_override("separation", 16)
	var art := ShopFrontArt.new()
	art.name = "ShopArt"
	art.custom_minimum_size = Vector2(art_size, art_size)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ldef: LocationDefinition = DataRegistry.location(StringName(str(h.get("location_id", ""))))
	art.tier = ldef.tier if ldef != null else 1
	row.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	row.add_child(info)
	var nm: Label = lbl(info, str(h.get("bakery_name", "")), 22, Palette.UI_WOOD_DEEP)
	nm.name = "BakeryName"
	nm.add_theme_font_override("font", ProceduralUIFactory.display_font())
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(100.0, 0.0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loc: String = str(h.get("location_id", ""))
	var where: String = Tx.t("ui_profile_day", {"day": h.get("day", 1)})
	if loc != "":
		where += " · " + (Tx.t(loc) if DataRegistry.has_text(loc) else loc)
	lbl(info, where, 16, Palette.TEXT_MUTED, true)
	var money: HBoxContainer = ProceduralUIFactory.icon_value("coin", Tx.kr(float(h.get("balance_kr", 0.0))), 22, 18, Palette.GOLDEN_CRUST)
	(money.get_meta("value") as Label).add_theme_color_override("font_color", Palette.GOLDEN_CRUST)
	info.add_child(money)
	return row


## Medali badge achievement di kartu profil (GDD 72.1): satu lingkaran berwarna
## pita badge itu dengan ikonnya; namanya muncul sebagai tooltip.
static func badge_row(ids: Array) -> Control:
	if ids.is_empty():
		return null
	var row := HBoxContainer.new()
	row.name = "Badges"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for id: Variant in ids:
		var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(StringName(str(id)))
		if def == null or not def.is_badge():
			continue
		var medal: PanelContainer = ProceduralUIFactory.badge(String(def.badge_icon), DecorFactory.badge_ribbon(def.visual_profile_id), Palette.FLOUR_WHITE, 40)
		medal.tooltip_text = Tx.t(String(def.localization_key))
		medal.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(medal)
	return row if row.get_child_count() > 0 else null
