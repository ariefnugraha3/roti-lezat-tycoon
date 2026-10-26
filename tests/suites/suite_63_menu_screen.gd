extends TestSuite
## Lembar Menu (GDD idle 4.2, 8.5, 12.3): petak rak dengan resepnya (pilih
## resep atau Auto) dan daftar resep dengan gambar, harga, dan tombol buka.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_MENU_SLOTS", "name": "idle 4.2 the Menu sheet lists every shelf slot; Change opens a page with Auto and every recipe that can be made; picking one sells it there, and bread already in the slot stays until sold", "fn": _slots},
		{"id": "ACC_IDLE_MENU_RECIPES", "name": "idle 8.5, 12.3 every recipe shows its BreadArt picture and price; Unlock is offered for recipes the stations can make, charges unlock_cost once, and tier-locked recipes only name their need", "fn": _recipes},
	]


func _boot() -> GameRoot:
	SaveManager.dir = "user://test_saves_menu_screen"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Menu Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
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


func _text(b: Button) -> String:
	if b == null:
		return ""
	for n: Node in b.find_children("*", "Label", true, false):
		return (n as Label).text
	return b.text


func _slots() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	sim.debug_add_kr(1.0e6)
	check(sim.upgrades.unlock_recipe(&"recipe_sugar_donut"), "Sugar Donut unlocked for the test")
	var disp: EquipmentInstance = sim.equipment.placed_list(&"display")[0]
	freeze_production(sim)
	for i0 in sim.display.slot_count(disp.iid):
		sim.display.set_assignment(disp.iid, i0, &"")
	stock(sim, &"recipe_plain_loaf", 6, 0, disp.iid)
	var menu: MenuScreen = game.modals.open(&"menu", {}) as MenuScreen
	await runner.get_tree().process_frame
	check(menu != null and game.hud._tabs[&"menu"].visible, "the Menu tab opens its sheet")
	var rows: int = 0
	for i in sim.display.slot_count(disp.iid):
		if menu.content().find_child("Slot_%d_%d" % [disp.iid, i], true, false) != null:
			rows += 1
	eq(rows, sim.display.slot_count(disp.iid), "one row per shelf slot")
	var slot0: Node = menu.content().find_child("Slot_%d_0" % disp.iid, true, false)
	var change: Button = slot0.find_child("Change", true, false) as Button if slot0 != null else null
	check(change != null, "each slot has a Change button")
	if change == null:
		await _finish(game)
		return
	change.pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq(menu.page_depth(), 1, "the choice opens as a page of the same sheet")
	check(menu.content().find_child("Choice_auto", true, false) != null, "Auto is offered")
	for r: RecipeDefinition in DataRegistry.recipes():
		var shown: bool = menu.content().find_child("Choice_" + String(r.id), true, false) != null
		eq(shown, sim.can_make(r.id), "%s is offered only when it can be made" % r.id)
	var auto_pick: Button = menu.content().find_child("Choice_auto", true, false).find_child("Pick", true, false) as Button
	check(auto_pick.disabled, "the current choice (Auto) is marked selected")
	var pick: Button = menu.content().find_child("Choice_recipe_sugar_donut", true, false).find_child("Pick", true, false) as Button
	pick.pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq(sim.display.assignment(disp.iid, 0), &"recipe_sugar_donut", "slot 1 now sells Sugar Donut")
	eq(menu.page_depth(), 0, "and the sheet goes back to the list")
	eq(sim.display.slot_units(disp.iid, 0), 6, "the Plain Loaf already there stays on the shelf")
	eq(sim.display.slot_content(disp.iid, 0), &"recipe_plain_loaf", "and keeps selling")
	# Dapur tidak mengisi petak itu dengan Donat selama roti lama masih ada.
	eq(sim.display.effective_recipe(disp.iid, 0), &"recipe_sugar_donut", "the slot now asks for Sugar Donut")
	eq(sim.display.slot_room(disp.iid, 0, &"recipe_sugar_donut"), 0, "but has no room for it while old bread fills it")
	sim.display.take(&"recipe_plain_loaf", 6, disp.iid, 0.0)
	eq(sim.display.slot_room(disp.iid, 0, &"recipe_sugar_donut"), sim.display.slot_capacity(disp.iid), "once it is sold out the slot takes the new recipe")
	await _finish(game)


func _recipes() -> void:
	var game: GameRoot = await _boot()
	var sim: SimulationRoot = game.sim
	var menu: MenuScreen = game.modals.open(&"menu", {}) as MenuScreen
	await runner.get_tree().process_frame
	var art_ok: int = 0
	for r: RecipeDefinition in DataRegistry.recipes():
		var row: Node = menu.content().find_child("Recipe_" + String(r.id), true, false)
		var art: BreadArt = row.find_child("BreadArt", true, false) as BreadArt if row != null else null
		if art != null and art.profile == String(r.visual_profile_id):
			art_ok += 1
	eq(art_ok, DataRegistry.recipes().size(), "every recipe row shows its own BreadArt picture")
	var donut: Node = menu.content().find_child("Recipe_recipe_sugar_donut", true, false)
	var unlock: Button = donut.find_child("Unlock", true, false) as Button if donut != null else null
	var cost: float = UpgradeManager.unlock_cost(DataRegistry.recipe(&"recipe_sugar_donut"))
	check(unlock != null and _text(unlock).contains(Tx.kr(cost)), "a recipe the stations can make offers Unlock for its cost")
	var croissant: Node = menu.content().find_child("Recipe_recipe_classic_croissant", true, false)
	check(croissant != null and croissant.find_child("Unlock", true, false) == null, "a tier-locked recipe offers no Unlock")
	var needs: bool = false
	if croissant != null:
		for l: Node in croissant.find_children("*", "Label", true, false):
			needs = needs or (l as Label).text == Tx.t("ui_menu_needs_tier", {"tier": 3})
	check(needs, "it names the station tier it needs")
	var plain: Node = menu.content().find_child("Recipe_recipe_plain_loaf", true, false)
	check(plain != null and plain.find_child("Unlock", true, false) == null, "Plain Loaf is free and already unlocked")
	sim.economy.spend(sim.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	menu.tick_page()
	check(unlock != null and unlock.disabled, "Unlock is disabled while the KR is short")
	sim.debug_add_kr(cost)
	menu.tick_page()
	check(unlock != null and not unlock.disabled, "and lights up once it is affordable")
	if unlock != null:
		unlock.pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(sim.upgrades.is_unlocked(&"recipe_sugar_donut"), "pressing it unlocks the recipe")
	near(sim.economy.balance, 0.0, 0.001, "for exactly unlock_cost")
	var donut2: Node = menu.content().find_child("Recipe_recipe_sugar_donut", true, false)
	check(donut2 != null and donut2.find_child("Unlock", true, false) == null, "the row no longer offers Unlock")
	await _finish(game)
