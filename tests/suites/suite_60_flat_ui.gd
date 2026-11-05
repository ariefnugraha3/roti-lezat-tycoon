extends TestSuite
## UI flat (GDD 130.6, keputusan maintainer 2026-10-02): seluruh UI 2D berupa
## bidang warna polos tanpa bayangan, bibir, kilap, garis tepi huruf, maupun
## gradasi. Tes ini menjaga agar kedalaman tidak kembali lewat helper kit.


func tests() -> Array:
	return [
		{"id": "ACC_130_FLAT_UI", "name": "130.6 the UI kit draws flat: no drop shadows, lips, gloss or text outlines on panels, buttons, badges, chips and titles, and button content sits centred on the face", "fn": _flat},
		{"id": "ACC_IDLE_BRANDING", "name": "idle 19 no. 1, 20 no. 49 the game is Crumbtown: Idle Bakery Tycoon: title, logo (Crumbtown + IDLE BAKERY TYCOON ribbon and crumbs), project name, user dir Crumbtown, Android name and package, default bakery name, and no player-facing text says Roti Lezat", "fn": _branding},
		{"id": "ACC_130_UI_ART", "name": "12.3.3, 89.3 2D art: Pak Lurah's portrait wears the same safari as his 3D model, the New Game portraits match the owner models (chef hat / bandana, apron colours, lashes) on their own pastel backdrops, and each save card shows a bakery for its location tier (an empty slot shows the '+' silhouette)", "fn": _art},
		{"id": "ACC_IDLE_MENU_LOOK", "name": "idle 20 no. 54 the opening screens: the logo bread is the loaf mascot, the backdrop has an awning and breads on the tablecloth, the main menu's shop card offers New Game without a save and Continue with the last bakery's name and storefront, round Settings/Credits/Exit buttons work, and New Game shows its steps and a sign that follows the typed name", "fn": _menu_look},
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


## Nama dan merek Crumbtown (GDD idle 19 no. 1, 20 no. 49).
func _branding() -> void:
	var title: String = "Crumbtown: Idle Bakery Tycoon"
	eq(Tx.t("game_title"), title, "the game title")
	eq(str(ProjectSettings.get_setting("application/config/name")), title, "the window and browser tab title")
	check(bool(ProjectSettings.get_setting("application/config/use_custom_user_dir", false)), "desktop data uses a custom user dir")
	eq(str(ProjectSettings.get_setting("application/config/custom_user_dir_name", "")), "Crumbtown", "the user dir has no colon in its name")
	var lock: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"))
	var logo: Label = lock.find_child("Logo", true, false) as Label
	eq(logo.text if logo != null else "", "Crumbtown", "the logo reads Crumbtown")
	var ribbon: PanelContainer = lock.find_child("Ribbon", true, false) as PanelContainer
	eq((ribbon.get_meta("label") as Label).text if ribbon != null else "", "IDLE BAKERY TYCOON", "the ribbon carries the subtitle")
	check(lock.find_child("Crumbs", true, false) is ProceduralUIFactory.CrumbScatter, "crumbs are scattered around the logo bread")
	lock.free()
	eq(Tx.t("ui_bakery_name_default"), "Crumbtown Bakery", "the default bakery name")
	var presets := ConfigFile.new()
	eq(presets.load("res://export_presets.cfg"), OK, "export presets load")
	for sec: String in presets.get_sections():
		if sec.ends_with(".options") and str(presets.get_value(sec, "package/unique_name", "")) != "":
			eq(str(presets.get_value(sec, "package/unique_name")), "com.crumbtown.idlebakery", "%s package" % sec)
			eq(str(presets.get_value(sec, "package/name")), "Crumbtown", "%s launcher name" % sec)
	var strings: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog/strings_en.json"))
	var table: Dictionary = (strings as Dictionary).get("strings", {})
	check(table.size() > 100, "the string table loads")
	var old: Array = []
	for k: Variant in table.keys():
		if str(table[k]).to_lower().contains("roti lezat"):
			old.append(k)
	eq(old, [], "no player-facing text still says Roti Lezat")


## Gambar UI 2D (GDD idle 20 no. 48): Pak Lurah, potret New Game, toko profil.
func _art() -> void:
	var lurah: Dictionary = CharacterFactory.spec_for_lurah()
	check(LurahPortrait.SAFARI.is_equal_approx(lurah["cloth"]), "Pak Lurah's portrait wears his 3D safari colour")
	for g: String in ["male", "female"]:
		var v: Dictionary = NewGameScreen.portrait_visual(g)
		var sp: Dictionary = CharacterFactory.spec_for_player("wanita" if g == "female" else "pria")
		eq(str(v["hat"]), str(sp["hat"]), "the %s portrait wears the owner's hat" % g)
		eq(str(v["hair_style"]), str(sp["hair_style"]), "the %s portrait has the owner's hair" % g)
		check(Color.html(str(v["apron"])).is_equal_approx(sp["apron"]), "the %s portrait has the owner's apron" % g)
		eq(bool(v["lashes"]), bool(sp["lashes"]), "the %s portrait has lashes like the model" % g)
		var p := ProceduralUIFactory.ChibiPortrait.new()
		p.configure(v, "baker", 1)
		check(p.backdrop.is_equal_approx(Color.html(str(v["backdrop"]))), "the %s portrait sits on its own pastel" % g)
		p.free()
	check(str(NewGameScreen.portrait_visual("male")["backdrop"]) != str(NewGameScreen.portrait_visual("female")["backdrop"]), "the two portraits have different backdrops")
	var staff := ProceduralUIFactory.ChibiPortrait.new()
	staff.configure({"hair_style": "kuncir_ganda", "apron": "#fffbf5"}, "cashier", 1)
	check(staff.lashes, "soft hair styles get lashes, as on the 3D staff")
	staff.free()
	var ps := ProfileScreen.new()
	ps.params = {"mode": "load"}
	var full: Control = ps._card(1, {"profile_id": &"profile_1", "exists": true, "bakery_name": "Art", "day": 3,
		"location_id": "location_t3_independent_bakery", "balance_kr": 10.0, "badges": [], "last_played_at": ""})
	var art: ShopFrontArt = full.find_child("ShopArt", true, false) as ShopFrontArt
	check(art != null and art.tier == 3, "a Tier 3 save shows the Tier 3 bakery")
	var empty: Control = ps._card(2, {"profile_id": &"profile_2", "exists": false})
	var art2: ShopFrontArt = empty.find_child("ShopArt", true, false) as ShopFrontArt
	check(art2 != null and art2.tier == 0, "an empty slot shows the '+' silhouette")
	full.free()
	empty.free()
	ps.free()


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


## Menu pembuka yang lebih hidup (GDD idle 20 no. 54): roti maskot di logo,
## tenda dan roti di taplak latar, kartu toko Main Menu dengan Continue atau
## New Game, tombol bundar berketerangan, dan New Game dengan bulatan langkah
## serta papan nama yang mengikuti ketikan.
func _menu_look() -> void:
	var lock: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), 76, 116)
	var bread: Variant = lock.get_meta("bread")
	check(bread is LogoBread, "the logo bread is the loaf mascot")
	if bread is LogoBread:
		near((bread as LogoBread).icon_size, 116.0, 0.01, "drawn at the size asked for")
	lock.free()
	var back: ProceduralUIFactory.CozyBackdrop = ProceduralUIFactory.backdrop() as ProceduralUIFactory.CozyBackdrop
	eq(back.get_children().filter(func(n: Node) -> bool: return n is BreadArt).size(), 4, "four breads sit on the tablecloth")
	back.set_anchors_preset(Control.PRESET_TOP_LEFT)
	back.size = Vector2(720, 1280)
	check(back.awning_bottom() > 60.0, "a striped awning hangs at the top")
	back.free()
	SaveManager.dir = "user://test_saves_menu"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.modals.close_all()
	var menu: UIScreen = game.modals.open(&"main_menu")
	await runner.get_tree().process_frame
	check(menu.find_child("NewGame", true, false) is Button, "without a save the shop card offers New Game")
	check(menu.find_child("Continue", true, false) == null, "and no Continue")
	eq((menu.find_child("SaveRow", true, false) as Container).get_child_count(), 1, "Load Game sits alone below it")
	var round_row: Container = menu.find_child("RoundRow", true, false) as Container
	eq(round_row.get_child_count(), 3 if not OS.has_feature("web") else 2, "Settings, Credits and Exit are round buttons")
	var settings: Button = round_row.find_child(Tx.t("ui_main_settings"), true, false) as Button
	check(settings != null and settings.custom_minimum_size.x >= ProceduralUIFactory.TOUCH_MIN, "the round buttons are big enough to tap")
	if settings != null:
		settings.pressed.emit()
		await runner.get_tree().process_frame
		check(game.modals.is_open(&"settings"), "the round Settings button opens Settings")
	game.modals.close_all()
	# Dengan save: kartu toko profil terakhir dan Continue besar.
	var s: SimulationRoot = new_sim(7, &"profile_2")
	s.bakery_name = "Menu Test Bakery"
	jump_to_tier(s, 3)
	SaveManager.write_profile(&"profile_2", s.capture_save())
	free_sim(s)
	menu = game.modals.open(&"main_menu")
	await runner.get_tree().process_frame
	check(menu.find_child("Continue", true, false) is Button, "a save puts Continue on the shop card")
	var name_l: Label = menu.find_child("BakeryName", true, false) as Label
	eq(name_l.text if name_l != null else "", "Menu Test Bakery", "with the bakery's name")
	var shop: ShopFrontArt = menu.find_child("HeroShop", true, false) as ShopFrontArt
	eq(shop.tier if shop != null else -1, 3, "and its Tier 3 storefront")
	eq((menu.find_child("SaveRow", true, false) as Container).get_child_count(), 2, "New Game and Load Game sit side by side")
	game.modals.close_all()
	var ng: NewGameScreen = game.modals.open(&"new_game", {"profile_id": &"profile_1"}) as NewGameScreen
	await runner.get_tree().process_frame
	var steps: Control = ng.find_child("Steps", true, false) as Control
	check(steps != null, "New Game shows its steps")
	ng._go(1)
	await runner.get_tree().process_frame
	var edit: LineEdit = ng.find_children("*", "LineEdit", true, false)[0] as LineEdit
	edit.text = "Tiny Oven"
	edit.text_changed.emit(edit.text)
	eq(ng._sign.text, "Tiny Oven", "the storefront sign follows the typed name")
	edit.text = "  "
	edit.text_changed.emit(edit.text)
	eq(ng._sign.text, Tx.t("ui_bakery_name_default"), "a blank name shows the default name, faded")
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
