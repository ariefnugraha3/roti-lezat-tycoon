extends TestSuite
## UI flat (GDD 130.6, keputusan maintainer 2026-10-02): seluruh UI 2D berupa
## bidang warna polos tanpa bayangan, bibir, kilap, garis tepi huruf, maupun
## gradasi. Tes ini menjaga agar kedalaman tidak kembali lewat helper kit.


func tests() -> Array:
	return [
		{"id": "ACC_130_FLAT_UI", "name": "130.6 the UI kit draws flat: no drop shadows, lips, gloss or text outlines on panels, buttons, badges, chips and titles, and button content sits centred on the face", "fn": _flat},
		{"id": "ACC_130_UI_POLISH", "name": "130.6, idle 12.1 flat polish: sheet rows are near-white cards on a deeper cream sheet under small-caps section titles, disabled buttons of every kind turn one readable cream, the open sheet's tab is honey, and the KR/s rate sits inside the KR chip", "fn": _polish},
	]


## Kontras WCAG antara dua warna buram.
static func _contrast(a: Color, b: Color) -> float:
	var la: float = _lum(a)
	var lb: float = _lum(b)
	return (maxf(la, lb) + 0.05) / (minf(la, lb) + 0.05)


static func _lum(c: Color) -> float:
	var l: Color = c.srgb_to_linear()
	return 0.2126 * l.r + 0.7152 * l.g + 0.0722 * l.b


## Pemolesan UI flat 2026-11-03 (GDD idle 20 no. 47).
func _polish() -> void:
	# Kit: nonaktif = satu krem yang sama, tanpa garis tepi; ghost tetap transparan.
	for kind: String in ["primary", "secondary", "success", "danger", "soft", "plain"]:
		var k: Dictionary = ProceduralUIFactory.kind_colors(kind)
		var sb: StyleBoxFlat = ProceduralUIFactory.cushion(k["face"], k["deep"], ProceduralUIFactory.RADIUS_PILL, "disabled")
		check(sb.bg_color.is_equal_approx(Palette.DISABLED_FACE), "a disabled %s button turns the shared disabled cream" % kind)
		eq(sb.border_width_top, 0, "a disabled %s button has no outline" % kind)
	var g: Dictionary = ProceduralUIFactory.kind_colors("ghost")
	var gs: StyleBoxFlat = ProceduralUIFactory.cushion(g["face"], g["deep"], ProceduralUIFactory.RADIUS_PILL, "disabled")
	check(gs.bg_color.a < 0.01 and gs.border_width_top > 0, "a disabled ghost button stays an outline")
	var soft: StyleBoxFlat = ProceduralUIFactory.cushion(Palette.HONEY_SOFT, Color(Palette.HONEY_DEEP, 0.0), ProceduralUIFactory.RADIUS_PILL, "normal")
	eq(soft.border_width_top, 0, "soft buttons are a plain light honey face")
	check(_contrast(Palette.DISABLED_INK, Palette.DISABLED_FACE) >= 3.0, "disabled text stays readable (>= 3:1)")
	var b: Button = ProceduralUIFactory.button("Go", "primary")
	check(b.get_theme_color("font_disabled_color").is_equal_approx(Palette.DISABLED_INK), "disabled button text uses the readable brown")
	b.free()
	# Lembar: kartu nyaris putih di atas krem lembar, judul bagian berhuruf kapital.
	check(_contrast(Palette.CARD, Palette.SHEET) > 1.1, "row cards stand out from the sheet")
	check(_contrast(Palette.CARAMEL, Palette.SHEET) >= 4.5, "section titles are readable on the sheet")
	var sec: Label = ProceduralUIFactory.section_label("Recipes")
	check(sec.uppercase and sec.text == "Recipes", "section titles draw in capitals without changing the text")
	sec.free()
	var game: GameRoot = await _boot()
	var hud: HUD = game.hud
	check(hud.cash_chip() != null and hud.cash_chip().is_ancestor_of(hud.rate_label()), "the KR/s rate sits inside the KR chip")
	eq(hud.active_tab(), &"", "no tab is active while no sheet is open")
	hud.tab_button(&"upgrades").pressed.emit()
	await _frames(2)
	var up: UpgradesScreen = game.modals.screen(&"upgrades") as UpgradesScreen
	check(up != null, "the Upgrades tab opens its sheet")
	eq(hud.active_tab(), &"upgrades", "the Upgrades tab is active")
	var tab_sb: StyleBoxFlat = hud.tab_button(&"upgrades").get_theme_stylebox("normal") as StyleBoxFlat
	check(tab_sb != null and tab_sb.bg_color.is_equal_approx(Palette.HONEY), "the active tab has a honey face")
	var other: StyleBoxFlat = hud.tab_button(&"menu").get_theme_stylebox("normal") as StyleBoxFlat
	check(other != null and other.bg_color.a < 0.01 and other.border_width_top == 0, "other tabs are flat with no outline")
	if up != null:
		var sheet_sb: StyleBoxFlat = up.panel().get_theme_stylebox("panel") as StyleBoxFlat
		check(sheet_sb.bg_color.is_equal_approx(Palette.SHEET), "the sheet is the deeper cream")
		var first: Array = up.order()[0]
		var row: PanelContainer = up.content().find_child("Up_%s_%s" % [first[0], first[1]], true, false) as PanelContainer
		var row_sb: StyleBoxFlat = row.get_theme_stylebox("panel") as StyleBoxFlat if row != null else null
		check(row_sb != null and row_sb.bg_color.is_equal_approx(Palette.CARD), "each upgrade row is a card")
		check(up.content().find_child("Section", true, false) is Label, "sections have small-caps titles")
		var gain: Label = up.content().find_child("Gain", true, false) as Label
		var bottom: Node = gain.get_parent().get_parent().get_parent() if gain != null else null
		check(bottom != null and bottom.find_child("BuyButtons", false, false) is BuyButtons,
			"the KR/s gain pill shares the row with the buy buttons")
	hud.tab_button(&"menu").pressed.emit()
	await _frames(2)
	eq(hud.active_tab(), &"menu", "opening another sheet moves the honey tab")
	hud.tab_button(&"menu").pressed.emit()
	await _frames(2)
	eq(hud.active_tab(), &"", "closing the sheet clears the active tab")
	other = hud.tab_button(&"menu").get_theme_stylebox("normal") as StyleBoxFlat
	check(other.bg_color.a < 0.01, "the closed tab goes flat again")
	await _finish(game)


func _boot() -> GameRoot:
	SaveManager.dir = "user://test_saves_ui_polish"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Polish Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
	await _frames(1)
	return game


func _finish(game: GameRoot) -> void:
	game.modals.close_all()
	game.playing = true
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame


func _flat() -> void:
	check(ProceduralUIFactory.flat_style, "the release UI is flat")
	eq(ProceduralUIFactory.lip(), 0, "no button lip")
	eq(ProceduralUIFactory.press_shift(), 0, "the face does not sink when pressed")
	near(ProceduralUIFactory.content_lift(), 0.0, 0.0001, "button content is centred on the face")
	var p: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 20, true)
	eq(p.shadow_size, 0, "panels cast no shadow")
	eq(p.border_width_bottom, 0, "panels have no lip")
	eq(p.content_margin_top, p.content_margin_bottom, "panel content is centred")
	for kind: String in ["primary", "secondary", "success", "danger", "ghost", "tab"]:
		var k: Dictionary = ProceduralUIFactory.kind_colors(kind)
		check(not bool(k["gloss"]), "%s has no gloss" % kind)
		check((k["outline"] as Color).a == 0.0, "%s text has no outline" % kind)
		for st: String in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBoxFlat = ProceduralUIFactory.cushion(k["face"], k["deep"], ProceduralUIFactory.RADIUS_PILL, st)
			eq(sb.shadow_size, 0, "%s %s casts no shadow" % [kind, st])
			eq(sb.border_width_bottom, sb.border_width_top, "%s %s has no lip" % [kind, st])
			near(sb.expand_margin_top, 0.0, 0.0001, "%s %s does not sink" % [kind, st])
	var b: Button = ProceduralUIFactory.button("Go", "primary")
	eq(b.get_theme_constant("outline_size"), 0, "button text has no outline")
	b.free()
	var badge: PanelContainer = ProceduralUIFactory.badge("cart", Palette.HONEY, Palette.FLOUR_WHITE, 36)
	var bs: StyleBoxFlat = badge.get_theme_stylebox("panel") as StyleBoxFlat
	check(bs.border_width_bottom == 0 and bs.shadow_size == 0, "badges are flat circles")
	badge.free()
	var chip: PanelContainer = ProceduralUIFactory.chip("coin", Palette.GOLD_STAR, "1", 20, 28)
	var cs: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
	check(cs.border_width_bottom == 0 and cs.shadow_size == 0, "HUD chips are flat pills")
	chip.free()
	var title: Label = ProceduralUIFactory.hero_label("Title", 26, Palette.FLOUR_WHITE, Palette.HONEY_DEEP)
	eq(title.get_theme_constant("outline_size"), 0, "titles have no outline")
	near(title.get_theme_color("font_shadow_color").a, 0.0, 0.0001, "titles have no extruded shadow")
	title.free()
	var pop: Control = ProceduralUIFactory.popup("Title")
	var card: PanelContainer = pop.get_meta("kartu")
	check(card.find_child("PaperGrain", false, false) == null, "popups have no paper grain")
	var face: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	check(face.shadow_size == 0 and face.border_width_bottom == 0, "popup cards are flat")
	pop.free()
