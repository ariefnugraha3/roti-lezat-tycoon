extends TestSuite
## Lembar Menu (GDD idle 4.2, 8.5, 12.3): petak rak dengan resepnya (pilih
## resep atau Auto) dan daftar resep dengan gambar, harga, dan tombol buka.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_MENU_SLOTS", "name": "idle 4.2 the Menu sheet lists every shelf slot; Change opens a page with Auto and every recipe that can be made; picking one sells it there, and bread already in the slot stays until sold", "fn": _slots},
		{"id": "ACC_IDLE_MENU_RECIPES", "name": "idle 8.5, 12.3 every recipe shows its BreadArt picture and price; Unlock is offered for recipes the stations can make, charges unlock_cost once, and tier-locked recipes only name their need", "fn": _recipes},
		{"id": "ACC_IDLE_VARIETY", "name": "idle 8.5, 20 no. 83 every different bread on the shelves raises every price by variety.bonus_per_recipe (up to variety.max_recipes); Auto slots spread the top recipes when that earns more, take turns slot by slot, count manual picks, levelled recipes are more popular, and the plan survives save/load", "fn": _variety},
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
	game.end_session()
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


func _variety() -> void:
	var s: SimulationRoot = new_sim(8301, &"profile_variety")
	freeze_production(s)
	var bonus: float = DataRegistry.idlef("variety.bonus_per_recipe")
	var cap: int = DataRegistry.idlei("variety.max_recipes")
	# Rumus dan batasnya.
	near(SimulationRoot.variety_mult_for(1), 1.0, 1e-9, "one bread: no bonus")
	near(SimulationRoot.variety_mult_for(3), 1.0 + 2.0 * bonus, 1e-9, "three breads: two bonuses")
	near(SimulationRoot.variety_mult_for(cap + 4), 1.0 + float(cap - 1) * bonus, 1e-9, "the bonus stops at max_recipes")
	# Toko baru: satu resep, tanpa bonus, harga biasa.
	eq(s.shelf_variety(), 1, "a new shop sells one bread")
	near(s.recipe_price(&"recipe_plain_loaf"), s.plain_price(&"recipe_plain_loaf") * s.boost_income_mult(), 1e-6, "a new shop has plain prices")
	# Popularitas: resep berlevel lebih tinggi dipilih lebih sering.
	var generic: CustomerArchetypeDefinition = DataRegistry.archetype(&"customer_generic")
	s.debug_add_kr(1.0e7)
	check(s.upgrades.unlock_recipe(&"recipe_sugar_donut"), "Sugar Donut unlocked")
	var opts: Array = [&"recipe_plain_loaf", &"recipe_sugar_donut"]
	var w0: Dictionary = CustomerManager.recipe_weights(generic, opts, s.recipe_popularity(opts))
	s.upgrades.recipe_levels[&"recipe_plain_loaf"] = 30
	var w1: Dictionary = CustomerManager.recipe_weights(generic, opts, s.recipe_popularity(opts))
	check(float(w1["recipe_plain_loaf"]) / float(w1["recipe_sugar_donut"]) > float(w0["recipe_plain_loaf"]) / float(w0["recipe_sugar_donut"]) * 2.0,
		"a levelled recipe draws more buyers than at Lv 1")
	near(float(w1["recipe_plain_loaf"]) / float(w0["recipe_plain_loaf"]),
		pow(s.upgrades.recipe_price_mult(&"recipe_plain_loaf"), DataRegistry.idlef("variety.popularity_exponent")), 1e-6,
		"popularity = level price multiplier ^ popularity_exponent")
	# Petak Auto menyebar resep teratas bila itu lebih untung, bergiliran.
	var disp: EquipmentInstance = s.equipment.placed_list(&"display")[0]
	var n_slots: int = s.display.slot_count(disp.iid)
	check(n_slots >= 2, "the first shelf has at least two slots")
	for i in n_slots:
		s.display.set_assignment(disp.iid, i, &"")
	var order: Array = s.auto_order()
	check(order.size() >= 1 and order[0] == s.auto_recipe(), "the best recipe leads the Auto plan")
	var per: Dictionary = {}
	var auto_slots: int = 0
	for e5: EquipmentInstance in s.equipment.placed_list(&"display"):
		for i2 in s.display.slot_count(e5.iid):
			if s.display.assignment(e5.iid, i2) == &"":
				auto_slots += 1
				var r2: StringName = s.display.effective_recipe(e5.iid, i2)
				check(order.has(r2), "Auto slot %d:%d sells a recipe of the plan" % [e5.iid, i2])
				per[r2] = int(per.get(r2, 0)) + 1
	var shares: Dictionary = s.idle_economy.walk_shares(Ids.sort(order.duplicate()))
	var weights: Array[float] = []
	for r3: Variant in order:
		weights.append(float(shares.get(r3, 0.0)))
	var counts: Array[int] = SimulationRoot.slot_counts(weights, auto_slots)
	for j3 in order.size():
		eq(int(per.get(order[j3], 0)), counts[j3], "%s gets slots in proportion to its share of demand" % order[j3])
		check(int(per.get(order[j3], 0)) >= 1, "every planned bread gets a slot")
	eq(s.shelf_variety(), order.size(), "the variety counts the breads Auto spreads")
	# Pembagian petak: sebanding bobot, paling sedikit satu, selang-seling.
	eq(SimulationRoot.slot_counts([0.6, 0.3, 0.1] as Array[float], 10), [6, 3, 1] as Array[int], "10 slots split 6/3/1")
	eq(SimulationRoot.slot_counts([0.9, 0.05, 0.05] as Array[float], 4), [2, 1, 1] as Array[int], "every bread keeps at least one slot")
	eq(SimulationRoot.slot_sequence([2, 1, 1] as Array[int]), [0, 1, 2, 0] as Array[int], "slots take turns instead of clumping")
	near(s.recipe_price(&"recipe_plain_loaf"), s.plain_price(&"recipe_plain_loaf") * s.variety_mult() * s.boost_income_mult(), 1e-6, "every price carries the variety bonus")
	# Auto memilih jumlah resep dengan laba rata-rata × variasi terbesar.
	var best_v: float = -INF
	var best_k: int = 0
	var ranked: Array = s._auto_plan(true)["ranked"]
	for k in range(1, mini(ranked.size(), n_slots) + 1):
		var v: float = s._menu_value({}, ranked, k, true)
		if best_k == 0 or v > best_v + absf(best_v) * SimulationRoot.PLAN_MARGIN + 0.000001:
			best_v = v
			best_k = k
	eq(order.size(), best_k, "Auto spreads the number of breads that earns the most")
	# Pilihan pemain ikut dihitung.
	s.upgrades.recipe_levels[&"recipe_plain_loaf"] = 1
	s.display.set_assignment(disp.iid, 0, &"recipe_sugar_donut")
	for i3 in range(1, n_slots):
		s.display.set_assignment(disp.iid, i3, &"recipe_plain_loaf")
	eq(s.shelf_variety(), 2, "two breads picked by hand count as variety")
	near(s.variety_mult(), 1.0 + bonus, 1e-9, "and earn one bonus")
	# Model offline memakai pengali yang sama (tanpa boost).
	near(s.recipe_price(&"recipe_plain_loaf", false), s.plain_price(&"recipe_plain_loaf") * s.variety_mult(false), 1e-6, "the offline model prices with the variety bonus")
	# Save/load: rencana Auto adalah fungsi state toko, jadi hasilnya sama.
	for i4 in n_slots:
		s.display.set_assignment(disp.iid, i4, &"")
	s.upgrades.recipe_levels[&"recipe_plain_loaf"] = 12
	var before_order: Array = s.auto_order()
	var before_slots: Array = []
	for i5 in n_slots:
		before_slots.append(s.display.effective_recipe(disp.iid, i5))
	var u: SimulationRoot = SimulationRoot.new()
	runner.add_child(u)
	u.load_from_save(s.capture_save())
	eq(u.auto_order(), before_order, "the Auto plan is the same after a load")
	var after_slots: Array = []
	for i6 in n_slots:
		after_slots.append(u.display.effective_recipe(disp.iid, i6))
	eq(after_slots, before_slots, "every Auto slot sells the same bread after a load")
	near(u.variety_mult(), s.variety_mult(), 1e-9, "and the variety bonus is the same")
	free_sim(u)
	free_sim(s)


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
