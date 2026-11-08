extends TestSuite
## Katalog Decoration Mode (GDD idle §20 no. 72): lembar seperti Staff dengan tab
## per jenis barang, baris berlencana ikon, dan tombol aksi.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_DECOR_ICONS", "name": "idle 20 no. 72 every decoration in the catalog and every kind of equipment has a drawable badge icon", "fn": _icons},
		{"id": "ACC_IDLE_DECOR_CATALOG", "name": "idle 20 no. 72 Decoration Mode lists items in a Staff-like sheet with Equipment / Wall / Counter / Floor / Style tabs: icon badge rows with Move, Place, Buy and Use; slot pills per type; buying a new decoration picks it up to place; holding an item or tapping the open tab folds the sheet to its tabs", "fn": _catalog},
	]


func _icons() -> void:
	var bad: Array[String] = []
	for x: Variant in DataRegistry.decorations():
		var d: MiscDefinitions.DecorationDefinition = x
		var icon: Array = DecorIcons.of_decor(d)
		if not IconCanvas.has_icon(str(icon[0])):
			bad.append("%s:%s" % [d.id, icon[0]])
	eq(bad, [] as Array[String], "every decoration icon is a known IconCanvas name")
	for cat: StringName in [&"mixer", &"oven", &"display", &"storage", &"table", &"chair", &"counter"]:
		check(IconCanvas.has_icon(str(DecorIcons.of_equipment(cat)[0])), "%s has an icon" % cat)
	for n: String in ["plant", "lamp", "rug", "apron", "bell", "book", "calculator"]:
		var ic: IconCanvas = ProceduralUIFactory.icon(n, 48, Palette.FLOUR_WHITE)
		runner.add_child(ic)
		await runner.get_tree().process_frame
		check(ic.icon_name == n, "the %s icon draws" % n)
		ic.queue_free()


func _boot() -> GameRoot:
	SaveManager.dir = "user://test_saves_decor_catalog"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Catalog Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	return game


func _finish(game: GameRoot) -> void:
	game.modals.close_all()
	game.end_session()
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


## Ikon lencana baris katalog bernama `row_name`, atau "".
static func _row_icon(deco: DecorationScreen, row_name: String) -> String:
	var row: Node = deco.find_child(row_name, true, false)
	if row == null:
		return ""
	var icons: Array[Node] = row.find_children("*", "IconCanvas", true, false)
	return (icons[0] as IconCanvas).icon_name if not icons.is_empty() else ""


static func _labels(n: Node) -> PackedStringArray:
	var out := PackedStringArray()
	if n == null:
		return out
	for l: Node in n.find_children("*", "Label", true, false):
		out.append((l as Label).text)
	return out


func _catalog() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	sim.debug_add_kr(1.0e6)
	var deco: DecorationScreen = game.modals.open(&"decoration", {}) as DecorationScreen
	await _frames(3)
	eq(deco._tabs.buttons.size(), 5, "five tabs")
	var names := PackedStringArray()
	for b: Button in deco._tabs.buttons:
		names.append(b.text)
	eq(names, PackedStringArray([Tx.t("ui_market_tab_equipment"), Tx.t("decor_type_wall"), Tx.t("decor_type_counter_prop"),
		Tx.t("decor_type_floor_prop"), Tx.t("decor_type_skin")]), "Equipment, Wall, Counter, Floor, Style")
	check(deco._cat_body.visible, "the catalog opens on its list")
	# Equipment: setiap alat dengan ikon kategorinya dan tombol Move.
	var oven: EquipmentInstance = sim.equipment.placed_list(&"oven")[0]
	eq(_row_icon(deco, "Equip_%d" % oven.iid), "fire", "the oven row has the oven icon")
	var move_b: Button = deco.find_child("Equip_%d" % oven.iid, true, false).find_child("Action", true, false) as Button
	check(move_b != null and move_b.text == Tx.t("ui_decor_move"), "and a Move button")
	# Floor: pil slot dan toko; membeli tanaman langsung mengangkatnya.
	deco._set_tab(DecorationScreen.TAB_FLOOR)
	await _frames(2)
	var usage: PackedStringArray = _labels(deco.find_child("SlotUsage", true, false))
	check(usage.has(Tx.t("ui_decor_slot_count", {"type": Tx.t("decor_type_floor_prop"), "used": 0, "max": sim.decoration.cap(&"floor_prop")}))
		and usage.has(Tx.t("ui_decor_slot_count", {"type": Tx.t("decor_type_floor_overlay"), "used": 0, "max": sim.decoration.cap(&"floor_overlay")})),
		"the Floor tab shows floor and rug spots (%s)" % ", ".join(usage))
	eq(_row_icon(deco, "Shop_decor_potted_plant"), "plant", "the potted plant has its plant icon")
	check(deco.find_child("NoneYet", true, false) != null, "with nothing owned yet, the tab says how to get some")
	var buy: Button = deco.find_child("Shop_decor_potted_plant", true, false).find_child("Action", true, false) as Button
	check(buy != null and not buy.disabled, "Buy is enabled")
	buy.pressed.emit()
	await _frames(3)
	check(sim.decoration.owns(&"decor_potted_plant"), "the plant is bought")
	check(deco.has_selection() and deco._sel_decor >= 0, "and picked up to place right away")
	check(not deco._cat_body.visible, "the catalog folds to its tabs while an item is held")
	deco._cancel()
	await _frames(2)
	deco._set_tab(DecorationScreen.TAB_FLOOR)
	await _frames(2)
	check(deco._cat_body.visible, "a tab opens the list again")
	var uid: int = int(sim.decoration.owned[sim.decoration.owned.size() - 1]["uid"])
	var place_b: Button = deco.find_child("Owned_%d" % uid, true, false).find_child("Action", true, false) as Button
	check(place_b != null and place_b.text == Tx.t("ui_decor_place"), "the plant is listed as yours with Place")
	deco._set_tab(DecorationScreen.TAB_FLOOR)
	await _frames(2)
	check(not deco._cat_body.visible, "tapping the open tab folds the sheet")
	# Style: pakaian dipakai lewat Use.
	var apron: Dictionary = sim.decoration._add(&"outfit_apron_neighborhood")
	deco._set_tab(DecorationScreen.TAB_STYLE)
	await _frames(2)
	eq(_row_icon(deco, "Owned_%d" % int(apron["uid"])), "apron", "the apron has the apron icon")
	var use: Button = deco.find_child("Owned_%d" % int(apron["uid"]), true, false).find_child("Action", true, false) as Button
	check(use != null and use.text == Tx.t("ui_decor_equip"), "with Use")
	use.pressed.emit()
	await _frames(3)
	eq(str(sim.decoration.equipped.get("outfit", "")), "outfit_apron_neighborhood", "Use puts the apron on")
	var used: Button = deco.find_child("Owned_%d" % int(apron["uid"]), true, false).find_child("Action", true, false) as Button
	check(used != null and used.disabled and used.text == Tx.t("ui_decor_equipped"), "and the button says Equipped")
	await _finish(game)
