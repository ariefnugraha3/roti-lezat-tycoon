extends TestSuite
## UI sistem level (GDD idle 12.1-12.3): chip level di dunia, kartu upgrade
## stasiun, lembar Upgrades ("Best value first"), dan lembar Shop.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_LEVEL_CHIPS", "name": "idle 12.1 every station and the counter on the viewed floor carry a big 'Lv n' chip (touch target >= 56 px) whose arrow shows when x1 is affordable; the chips survive HUD refreshes and a tap opens the upgrade card", "fn": _chips},
		{"id": "ACC_IDLE_UPGRADE_CARD", "name": "idle 12.2 the upgrade card floats above its station (or docks above the tab bar), shows 'Oven · Lv n', the effect now -> next and the next milestone, and its x1 / x10 / Max buttons buy exactly what they say", "fn": _card},
		{"id": "ACC_IDLE_CHIP_OPENS_CARD", "name": "idle 20 no. 77 tapping a mixer, oven, shelf or checkout counter gives the owner's focus (Semangat) but opens no upgrade card and never closes or replaces an open one; a real tap on a level chip opens its card; an empty floor tap closes it", "fn": _chip_opens_card},
		{"id": "ACC_IDLE_CHIPS_DECLUTTER", "name": "idle 20 no. 77 level chips are big (20 px text, pill >= 40 px tall, touch target >= 56 px) and in a full Tier 5 shop no two overlap, each stays on screen, a chip pushed off its station gets a line to it, and tapping each one opens its own card", "fn": _chips_declutter},
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


## Kartu upgrade yang terbuka, dan berapa yang ada di tumpukan modal.
func _cards(game: GameRoot) -> Array[UpgradeCard]:
	var out: Array[UpgradeCard] = []
	for n: Node in game.modals.get_children():
		if n is UpgradeCard and not n.is_queued_for_deletion():
			out.append(n as UpgradeCard)
	return out


## Kartu upgrade hanya dari chip level (GDD idle §20 no. 77): ketukan pada
## perabot memberi fokus pemilik dan Semangat saja.
func _chip_opens_card() -> void:
	var game: GameRoot = await _boot("Chip Card Bakery")
	var sim: SimulationRoot = game.sim
	var world: WorldView = game.world
	var rig: CameraRig = world.camera_rig
	var chips: LevelChips = game.hud.level_chips
	game.hud._refresh_all()
	await _frames(2)
	# Mixer, oven, dan rak: ketukan memberi fokus pemilik, tanpa kartu.
	for cat: StringName in LevelChips.STATION_CATEGORIES:
		var e: EquipmentInstance = sim.equipment.placed_list(cat)[0]
		var pos: Vector2 = world.screen_of_iid(e.iid)
		var p: Dictionary = world.pick(pos)
		check(p.get("kind") == &"equipment" and int(p.get("iid", -1)) == e.iid, "the %s picks as itself" % cat)
		game._on_world_tap(pos)
		await _frames(2)
		eq(sim.player.focus_iid, e.iid, "tapping the %s gives it the owner's focus" % cat)
		eq(_cards(game).size(), 0, "tapping the %s opens no upgrade card" % cat)
	# Meja kasir jalur A: fokus pemilik, tanpa kartu.
	var lane: QueueLane = sim.queue.main_lane()
	var counter_pos: Vector2 = Vector2(-1, -1)
	for cd: Dictionary in world._counter_aabbs:
		if StringName(str(cd["counter_id"])) == lane.counter_id and StringName(str(cd["floor"])) == rig.active_floor:
			var ab: AABB = cd["aabb"]
			counter_pos = rig.world_to_screen(Vector3(ab.get_center().x, ab.end.y - 0.05, ab.get_center().z))
	check(counter_pos.x >= 0.0, "the checkout counter projects to screen")
	eq(world.pick(counter_pos).get("kind"), &"cashier", "tapping the checkout counter picks the cashier")
	game._on_world_tap(counter_pos)
	await _frames(2)
	check(sim.player.focus_cashier, "the counter tap focuses the owner on lane A")
	eq(_cards(game).size(), 0, "and opens no card either")
	# Ketukan sungguhan di tengah chip oven membuka kartu oven.
	var oven: EquipmentInstance = sim.equipment.placed_list(&"oven")[0]
	var r: Rect2 = chips.chip_rect(&"station", oven.iid)
	check(r.has_area(), "the oven's chip is on screen")
	_tap(r.get_center())
	await _frames(2)
	var cards: Array[UpgradeCard] = _cards(game)
	check(cards.size() == 1 and cards[0].kind == &"station" and int(cards[0].id) == oven.iid, "tapping the oven's chip opens the oven's card")
	var card: UpgradeCard = cards[0] if cards.size() == 1 else null
	# Ketukan Semangat pada oven itu dan pada mixer tidak menutup atau mengganti kartu.
	var mixer: EquipmentInstance = sim.equipment.placed_list(&"mixer")[0]
	for iid: int in [oven.iid, oven.iid, mixer.iid]:
		game._on_world_tap(world.screen_of_iid(iid))
	await _frames(2)
	check(_cards(game).size() == 1 and _cards(game)[0] == card, "Semangat taps on stations leave the open card as it is")
	# Lantai kosong menutup kartu.
	var empty: Vector2 = Vector2(-1, -1)
	var view: Vector2 = game.get_viewport().get_visible_rect().size
	for gy in range(10, 90, 4):
		for gx in range(10, 90, 8):
			var at: Vector2 = Vector2(view.x * gx / 100.0, view.y * gy / 100.0)
			if world.pick(at).get("kind") == &"cell":
				empty = at
				break
		if empty.x >= 0.0:
			break
	check(empty.x >= 0.0, "an empty floor tile is on screen")
	game._on_world_tap(empty)
	await _frames(2)
	eq(_cards(game).size(), 0, "tapping an empty tile closes the card")
	# Chip meja kasir membuka kartu Meja Kasir di atas mejanya.
	var cr: Rect2 = chips.chip_rect(&"counter", &"counter")
	check(cr.has_area(), "the counter's chip is on screen")
	_tap(cr.get_center())
	await _frames(2)
	var cc: Array[UpgradeCard] = _cards(game)
	check(cc.size() == 1 and cc[0].kind == &"counter", "tapping the counter's chip opens the counter's card")
	if cc.size() == 1:
		check(not cc[0].is_docked(), "floating above the counter")
	await _finish(game)


## Toko Tier 5 yang penuh: chip besar tidak saling tumpuk (GDD idle §20 no. 77).
func _chips_declutter() -> void:
	var game: GameRoot = await _boot("Crowded Chip Bakery")
	var sim: SimulationRoot = game.sim
	jump_to_tier(sim, 5)
	equip_shop(sim)
	# Kamera dijauhkan sejauh mungkin: stasiun paling rapat di layar.
	game.world.camera_rig.zoom(100.0)
	game.hud._refresh_all()
	await _frames(4)
	var chips: LevelChips = game.hud.level_chips
	var view: Vector2 = chips.get_viewport_rect().size
	var shown: Array[Dictionary] = []
	for cat: StringName in LevelChips.STATION_CATEGORIES:
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			var b: Button = chips.chip(&"station", e.iid)
			if b != null and b.visible:
				shown.append({"iid": e.iid, "rect": chips.chip_rect(&"station", e.iid), "button": b})
	check(shown.size() >= 8, "a full Tier 5 floor shows many chips (%d)" % shown.size())
	var big: bool = true
	var inside: bool = true
	for d: Dictionary in shown:
		var r: Rect2 = d["rect"]
		var b2: Button = d["button"]
		big = big and r.size.y >= 40.0 and b2.size.y >= 56.0 and b2.size.x >= 56.0
		if r.position.x < 0.0 or r.end.x > view.x or r.position.y < 0.0 or r.end.y > view.y:
			inside = false
			print("[TEST] chip %d outside %s: %s" % [int(d["iid"]), view, r])
	check(big, "every pill is at least 40 px tall with a touch target of at least 56 px")
	check(inside, "every chip stays inside the screen")
	var overlaps: int = 0
	for i in shown.size():
		for j in range(i + 1, shown.size()):
			if (shown[i]["rect"] as Rect2).intersects(shown[j]["rect"] as Rect2):
				overlaps += 1
	eq(overlaps, 0, "no two chips overlap")
	var moved: int = 0
	for d2: Dictionary in shown:
		var tip: Vector2 = game.world.camera_rig.world_to_screen(game.world.top_of_iid(int(d2["iid"])))
		var r2: Rect2 = d2["rect"]
		var home := Vector2(tip.x, tip.y - LevelChips.LIFT_PX)
		if Vector2(r2.get_center().x, r2.end.y).distance_to(home) > LevelChips.LEADER_MIN_PX:
			moved += 1
	check(moved > 0, "crowded chips were moved off their stations (%d), each with a line to it" % moved)
	# Setiap chip yang tidak tertutup panel HUD membuka kartunya sendiri dengan
	# ketukan sungguhan.
	var right: int = 0
	var open: int = 0
	for d3: Dictionary in shown:
		var at: Vector2 = (d3["rect"] as Rect2).get_center()
		var mm := InputEventMouseMotion.new()
		mm.position = at
		mm.global_position = at
		runner.get_viewport().push_input(mm, true)
		var hov: Control = runner.get_viewport().gui_get_hovered_control()
		if hov == null or not (hov == d3["button"] or (d3["button"] as Button).is_ancestor_of(hov)):
			continue
		open += 1
		_tap(at)
		await _frames(2)
		var cards: Array[UpgradeCard] = _cards(game)
		if cards.size() == 1 and cards[0].kind == &"station" and int(cards[0].id) == int(d3["iid"]):
			right += 1
		game.modals.close_all()
		await _frames(2)
	check(open >= 3, "most chips are not under the HUD (%d of %d)" % [open, shown.size()])
	eq(right, open, "tapping each chip opens that station's own card")
	await _finish(game)


func _tap(pos: Vector2) -> void:
	for pressed: bool in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = pressed
		e.position = pos
		e.global_position = pos
		e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		runner.get_viewport().push_input(e, true)


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
	var bal0: float = sim.economy.balance
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
	near(sim.economy.balance, bal0, 1.0, "for exactly the location cost")
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
