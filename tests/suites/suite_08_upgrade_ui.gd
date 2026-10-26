extends TestSuite
## UI sistem level (GDD idle 12.1-12.3): chip level di dunia, kartu upgrade
## stasiun, lembar Upgrades ("Best value first"), dan lembar Shop.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_LEVEL_CHIPS", "name": "idle 12.1 every station and the counter on the viewed floor carry a 'Lv n' chip (touch target >= 48 px) whose arrow shows when x1 is affordable; the chips survive HUD refreshes and a tap opens the upgrade card", "fn": _chips},
		{"id": "ACC_IDLE_UPGRADE_CARD", "name": "idle 12.2 the upgrade card floats above its station (or docks above the tab bar), shows 'Oven · Lv n', the effect now -> next and the next milestone, and its x1 / x10 / Max buttons buy exactly what they say", "fn": _card},
		{"id": "ACC_IDLE_UPGRADES_SHEET", "name": "idle 12.3 the Upgrades sheet lists every station, counter, recipe, staff and global upgrade sorted by KR/s gained per KR, and buying from a row re-sorts the list", "fn": _upgrades},
		{"id": "ACC_IDLE_SHOP_SHEET", "name": "idle 8.4, 8.7, 8.9 the Shop sheet compares this location with the next and moves there after a confirm, opens new stations, and sells shop upgrades", "fn": _shop},
	]


func _boot(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_upgrade_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", label)
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


func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame


func _chips() -> void:
	var game: GameRoot = await _boot("Chip Bakery")
	var sim: SimulationRoot = game.sim
	var chips: LevelChips = game.hud.level_chips
	game.hud._refresh_all()
	await _frames(2)
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		var e: EquipmentInstance = sim.equipment.placed_list(cat)[0]
		var b: Button = chips.chip(&"station", e.iid)
		check(b != null and b.visible, "the %s has a level chip" % cat)
		if b != null:
			check(b.size.y >= 48.0 and b.size.x >= 48.0, "its touch target is at least 48 px")
	var counter: Button = chips.chip(&"counter", &"counter")
	check(counter != null and counter.visible, "the counter has a level chip")
	var oven: EquipmentInstance = sim.equipment.placed_list(&"oven")[0]
	var oven_chip: Button = chips.chip(&"station", oven.iid)
	var arrow: Control = oven_chip.find_child("Arrow", true, false) as Control
	sim.economy.spend(sim.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	game.hud._refresh_all()
	check(not arrow.visible, "no arrow while Lv 2 is out of reach")
	sim.debug_add_kr(UpgradeManager.offer_cost(sim.upgrades.offer(&"station", oven.iid), 1))
	game.hud._refresh_all()
	check(arrow.visible, "the arrow shows once x1 is affordable")
	for i in 6:
		game.hud._refresh_all()
	check(is_instance_valid(oven_chip) and chips.chip(&"station", oven.iid) == oven_chip, "refreshing never rebuilds a chip")
	oven_chip.pressed.emit()
	await _frames(2)
	check(game.modals.is_open(&"upgrade_card"), "tapping the chip opens the upgrade card")
	check(game.modals.top() is UpgradeCard, "the card is on top")
	game.modals.close_all()
	sim.upgrades.buy(&"station", oven.iid, &"x1")
	game.hud._refresh_all()
	eq((oven_chip.find_children("*", "Label", true, false)[0] as Label).text, Tx.t("ui_level_chip", {"level": 2}), "the chip reads Lv 2 after the upgrade")
	await _finish(game)


func _card() -> void:
	var game: GameRoot = await _boot("Card Bakery")
	var sim: SimulationRoot = game.sim
	var oven: EquipmentInstance = sim.equipment.placed_list(&"oven")[0]
	game.hud.level_chips.open_card(&"station", oven.iid)
	await _frames(3)
	var card: UpgradeCard = null
	for n: Node in game.modals.get_children():
		if n is UpgradeCard:
			card = n
	check(card != null, "the card opens")
	if card == null:
		await _finish(game)
		return
	var title: Label = card.find_child("Title", true, false) as Label
	eq(title.text, Tx.t("ui_title_level", {"name": Tx.t("ui_station_oven"), "level": 1}), "titled 'Oven · Lv 1'")
	var effect: Label = card.find_child("Effect", true, false) as Label
	check(effect.text.contains("→"), "the effect reads now -> next (%s)" % effect.text)
	var mile: Label = card.find_child("Milestone", true, false) as Label
	check(mile.visible and mile.text.begins_with(Tx.t("ui_next_milestone", {"level": 10, "effect": ""}).strip_edges().left(5)), "the next milestone is Lv 10 (%s)" % mile.text)
	check(not card.is_docked(), "the card floats above the oven it belongs to")
	var top: Vector3 = game.world.top_of_iid(oven.iid)
	var anchor: Vector2 = game.world.camera_rig.world_to_screen(top)
	check(card.panel().position.y + card.panel().size.y <= anchor.y, "above the oven's top")
	# Tombol: ×1, ×10 hanya bila 10 level terjangkau, Max menyebut jumlahnya.
	var buy: BuyButtons = card.buttons()
	var o: Dictionary = sim.upgrades.offer(&"station", oven.iid)
	sim.economy.spend(sim.economy.balance, &"OTHER_ADJUSTMENT", &"test")
	sim.debug_add_kr(UpgradeManager.offer_cost(o, 3))
	buy.refresh()
	check(not buy.button(&"x1").disabled, "x1 is affordable")
	check(buy.button(&"x10").disabled, "x10 is off with KR for only 3 levels")
	eq(buy.label_of(&"max"), Tx.t("ui_buy_max", {"levels": 3}), "Max (+3)")
	eq(buy.cost_of(&"max"), Tx.kr(UpgradeManager.offer_cost(o, 3)), "with the cost of three levels")
	buy.button(&"max").pressed.emit()
	await _frames(1)
	eq(sim.upgrades.station_level(oven.iid), 4, "Max bought exactly 3 levels")
	near(sim.economy.balance, 0.0, 1.0, "for exactly their cost")
	card._render()
	eq(title.text, Tx.t("ui_title_level", {"name": Tx.t("ui_station_oven"), "level": 4}), "the title follows")
	check(card.milestone_ratio() > 0.0, "the milestone bar has filled a bit")
	game.modals.close_all()
	# Stasiun di lantai lain: kartu menempel di atas bar tab.
	jump_to_tier(sim, 2)
	await _frames(2)
	var mixer: EquipmentInstance = sim.equipment.placed_list(&"mixer")[0]
	check(mixer.floor_id != game.world.camera_rig.active_floor, "the Tier 2 mixer is upstairs, out of view")
	game.hud.level_chips.open_card(&"station", mixer.iid)
	await _frames(3)
	var card2: UpgradeCard = null
	for n2: Node in game.modals.get_children():
		if n2 is UpgradeCard:
			card2 = n2
	check(card2 != null and card2.is_docked(), "a card for a station out of view docks above the tab bar")
	await _finish(game)


func _upgrades() -> void:
	var game: GameRoot = await _boot("Upgrade Bakery")
	var sim: SimulationRoot = game.sim
	sim.debug_add_kr(1.0e6)
	sim.staff.hire(&"staff_baker_joko")
	sim.upgrades.unlock_recipe(&"recipe_sugar_donut")
	var sheet: UpgradesScreen = game.modals.open(&"upgrades", {}) as UpgradesScreen
	await _frames(2)
	var order: Array = sheet.order()
	var kinds: Dictionary = {}
	for row: Array in order:
		kinds[row[0]] = true
	for k: StringName in [&"station", &"counter", &"recipe", &"staff", &"global"]:
		check(kinds.has(k), "the list has %s upgrades" % k)
	var ranked: Array[Dictionary] = sim.idle_economy.ranked_offers()
	eq(order.size(), ranked.size(), "one row per upgrade that can still go up")
	var sorted_ok: bool = true
	for i in range(1, ranked.size()):
		if float(ranked[i]["value"]) > float(ranked[i - 1]["value"]) + 1e-12:
			sorted_ok = false
	check(sorted_ok, "sorted by KR/s gained per KR, best first")
	check(float(ranked[0]["delta"]) > 0.0, "the first row raises KR/s")
	var first: Array = order[0]
	var o: Dictionary = sim.upgrades.offer(first[0], first[1])
	var lv: int = int(o["level"])
	var row_node: Node = sheet.content().find_child("Up_%s_%s" % [first[0], first[1]], true, false)
	var buy: BuyButtons = row_node.find_child("BuyButtons", true, false) as BuyButtons
	buy.button(&"x1").pressed.emit()
	await _frames(3)
	eq(int(sim.upgrades.offer(first[0], first[1])["level"]), lv + 1, "x1 on the first row buys one level")
	eq(sheet.order().size(), sim.idle_economy.ranked_offers().size(), "the list is rebuilt after buying")
	await _finish(game)


func _shop() -> void:
	var game: GameRoot = await _boot("Shop Bakery")
	var sim: SimulationRoot = game.sim
	var sheet: ShopScreen = game.modals.open(&"shop", {}) as ShopScreen
	await _frames(2)
	var move: Button = sheet.content().find_child("Move", true, false) as Button
	check(move != null and move.disabled, "Move is off until the next location is affordable")
	sim.debug_add_kr(SimulationRoot.location_cost(2))
	sheet.tick_page()
	check(not move.disabled, "and lights up once it is")
	move.pressed.emit()
	await _frames(2)
	check(game.modals.is_open(&"confirm"), "moving asks first")
	for n: Node in game.modals.get_children():
		if n is ConfirmDialog:
			(n as ConfirmDialog)._accept()
	await _frames(3)
	eq(sim.world.location.tier, 2, "the bakery moved to Tier 2")
	near(sim.economy.balance, DataRegistry.idlef("start_kr"), 1.0, "for exactly the location cost")
	# Buka stasiun baru.
	sheet = game.modals.open(&"shop", {}) as ShopScreen
	await _frames(2)
	sim.upgrades._room_cache[&"mixer"] = false
	sheet = game.modals.open(&"shop", {}) as ShopScreen
	await _frames(2)
	var nr_row: Node = sheet.content().find_child("Open_mixer", true, false)
	check(nr_row != null and nr_row.find_child("NoRoom", true, false) != null and nr_row.find_child("Open", true, false) == null,
		"with no free spot the Shop says so instead of offering Open")
	sim.world.rebuild_occupancy()
	sheet = game.modals.open(&"shop", {}) as ShopScreen
	await _frames(2)
	var open_row: Node = sheet.content().find_child("Open_mixer", true, false)
	var open_b: Button = open_row.find_child("Open", true, false) as Button if open_row != null else null
	check(open_b != null, "Tier 2 offers a second mixer")
	var cost: float = sim.upgrades.open_station_cost(&"mixer")
	sim.debug_add_kr(cost)
	var bal: float = sim.economy.balance
	sheet.tick_page()
	open_b.pressed.emit()
	await _frames(3)
	eq(sim.equipment.placed_count(&"mixer"), 2, "the second mixer opens")
	near(bal - sim.economy.balance, cost, 1.0, "for its open cost")
	# Upgrade global.
	sim.debug_add_kr(1.0e6)
	sheet = game.modals.open(&"shop", {}) as ShopScreen
	await _frames(2)
	var g_row: Node = sheet.content().find_child("Global_global_tap_power", true, false)
	var gb: BuyButtons = g_row.find_child("BuyButtons", true, false) as BuyButtons if g_row != null else null
	check(gb != null, "shop upgrades are listed")
	if gb != null:
		gb.refresh()
		gb.button(&"x1").pressed.emit()
		eq(sim.upgrades.global_level(&"global_tap_power"), 1, "x1 buys Strong Hands Lv 1")
	await _finish(game)
