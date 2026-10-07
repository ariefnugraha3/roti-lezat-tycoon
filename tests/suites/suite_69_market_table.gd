extends TestSuite
## Tabel Pasar (GDD 5.1.2, 6, 7, perbaikan 2026-10-07). Keluhan: daftar bahan
## tidak lurus. Kolom harga, stok, dan tombol bergeser mengikuti panjang nama
## dan harga, dan "In storage" menempel di bagian atas baris. Tab Equipment
## berisi kartu besar yang info dan tombolnya tidak rata (termasuk "Buy for 0 KR"
## dan mengganti alat dengan alat yang sama), dan Store Upgrade membuat popup
## memanjang. Kini ketiga tab berupa tabel papan kapur berkolom tetap.


func tests() -> Array:
	return [
		{"id": "ACC_7_MARKET_TABLE", "name": "7 the Market's ingredient table lines up: a header (Ingredient, Price, In Storage, Amount) over fixed columns, prices right-aligned, stock centred in its row, and the minus/amount/plus/Max controls in the same place on every row, at 100, 125 and 150% text scale", "fn": _table},
		{"id": "ACC_7_MARKET_EQUIPMENT_TABLE", "name": "5.1.2, 7 the Equipment tab is one chalk table per category whose columns (speed or capacity, utility, size, price, action) line up with their header on every row at 100, 125 and 150%; each row offers one action: Buy, Replace, a tier lock, or Owned", "fn": _equipment},
		{"id": "ACC_7_MARKET_UPGRADE_TABLE", "name": "6, 7 Store Upgrade compares the current and next location side by side in one table that fits the popup at 100%, gains in yellow with the difference, the button with its reason below; the top tier shows the current location only", "fn": _upgrade},
		{"id": "ACC_5_EQUIPMENT_REPLACE_PICK", "name": "5.1.2 with every slot full, Replace asks which placed item to swap out when there is more than one, never offers swapping an item for the same model, and greys out items in use", "fn": _replace_pick},
	]


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_market_table"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", profile_name)
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


## Selisih terbesar antar-nilai (0 = semuanya sama).
static func _spread(values: Array[float]) -> float:
	var lo: float = INF
	var hi: float = -INF
	for v: float in values:
		lo = minf(lo, v)
		hi = maxf(hi, v)
	return hi - lo if not values.is_empty() else 0.0


static func _rect(root: Node, child: String) -> Rect2:
	var c: Control = root.find_child(child, true, false) as Control
	return c.get_global_rect() if c != null else Rect2()


func _table() -> void:
	var game: GameRoot = await _boot("Market Table")
	var sim: SimulationRoot = game.sim
	sim.supply.market_unlocked = true
	sim.debug_add_kr(5000.0)
	check(bool(sim.supply.purchase({"ingredient_butter": 5}).get("ok", false)), "some butter is on the way")
	var was_scale: float = ProceduralUIFactory.text_scale
	for pct: int in [100, 125, 150]:
		ProceduralUIFactory.text_scale = float(pct) / 100.0
		game.modals.close_all()
		var scr: MarketScreen = game.modals.open(&"market", {"tab": 0}) as MarketScreen
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		var rows: Array[Node] = scr.find_children("Row_*", "PanelContainer", true, false)
		eq(rows.size(), DataRegistry.ingredients().size(), "%d%%: one row per ingredient" % pct)
		var header: HBoxContainer = scr.find_child("Columns", true, false) as HBoxContainer
		check(header != null, "%d%%: a column header" % pct)
		if rows.is_empty() or header == null:
			continue
		var price_end: Array[float] = []
		var stock_mid: Array[float] = []
		var minus_x: Array[float] = []
		var max_end: Array[float] = []
		var off_centre: float = 0.0
		var overlap: int = 0
		var small: float = INF
		for row: Node in rows:
			var price: Rect2 = _rect(row, "Price")
			var stock: Rect2 = _rect(row, "StockCell")
			var minus: Rect2 = _rect(row, "Minus")
			var mx: Rect2 = _rect(row, "Max")
			var name_cell: Rect2 = _rect(row, "NameCell")
			price_end.append(price.end.x)
			stock_mid.append(stock.get_center().x)
			minus_x.append(minus.position.x)
			max_end.append(mx.end.x)
			var row_rect: Rect2 = (row as Control).get_global_rect()
			off_centre = maxf(off_centre, absf(stock.get_center().y - row_rect.get_center().y))
			if name_cell.end.x > price.position.x + 0.5:
				overlap += 1
			small = minf(small, minf(minus.size.y, minf(mx.size.y, _rect(row, "Plus").size.x)))
		check(_spread(price_end) <= 0.5, "%d%%: every price ends in the same column (spread %.1f px)" % [pct, _spread(price_end)])
		check(_spread(stock_mid) <= 0.5, "%d%%: stock is centred in one column" % pct)
		check(_spread(minus_x) <= 0.5 and _spread(max_end) <= 0.5, "%d%%: the amount controls line up on every row" % pct)
		check(off_centre <= 1.5, "%d%%: stock sits in the middle of its row, not at the top (off by %.1f px)" % [pct, off_centre])
		eq(overlap, 0, "%d%%: no name runs into the price" % pct)
		check(small >= ProceduralUIFactory.TOUCH_MIN - 0.5, "%d%%: buttons stay full-size touch targets (%.0f px)" % [pct, small])
		# Header tepat di atas kolomnya.
		var hp: Rect2 = _rect(header, "ui_market_col_price")
		var hs: Rect2 = _rect(header, "ui_market_col_stock")
		var ha: Rect2 = _rect(header, "ui_market_col_amount")
		near(hp.end.x, price_end[0], 1.0, "%d%%: the Price header ends over the prices" % pct)
		near(hs.get_center().x, stock_mid[0], 1.0, "%d%%: In Storage sits over the stock" % pct)
		near(ha.position.x, minus_x[0], 1.0, "%d%%: Amount starts over the minus buttons" % pct)
		near(ha.end.x, max_end[0], 1.0, "%d%%: and ends over the Max buttons" % pct)
		for key: String in ["ui_market_col_ingredient", "ui_market_col_price", "ui_market_col_stock", "ui_market_col_amount"]:
			eq((header.find_child(key, true, false) as Label).text, Tx.t(key), "%d%%: header %s in English" % [pct, key])
		# Satuan di bawah nama; barang yang sedang dikirim di bawah stok.
		var flour: Node = scr.find_child("Row_ingredient_flour", true, false)
		eq((flour.find_child("Unit", true, false) as Label).text, Tx.t("ui_market_per_unit", {"unit": Tx.t("unit_kg_portion")}), "%d%%: the unit sits under the name" % pct)
		var butter: Node = scr.find_child("Row_ingredient_butter", true, false)
		var arriving: Label = butter.find_child("Arriving", true, false) as Label
		check(arriving != null, "%d%%: butter on the way shows under its stock" % pct)
		if arriving != null:
			eq(arriving.text, Tx.t("ui_market_arriving", {"count": 5, "time": Tx.clock(sim.supply.next_eta_of(&"ingredient_butter"))}), "%d%%: with how many and when" % pct)
			check(arriving.get_global_rect().end.x <= _rect(butter, "Minus").position.x, "%d%%: without touching the buttons" % pct)
	# Jumlah yang dipilih ditulis kapur kuning.
	ProceduralUIFactory.text_scale = 1.0
	game.modals.close_all()
	var m: MarketScreen = game.modals.open(&"market", {"tab": 0}) as MarketScreen
	await runner.get_tree().process_frame
	var row0: Node = m.find_child("Row_ingredient_flour", true, false)
	var qty: Label = row0.find_child("Qty", true, false) as Label
	eq(qty.get_theme_color("font_color"), Palette.CHALK_WHITE, "an unpicked amount is white chalk")
	(row0.find_child("Plus", true, false) as Button).pressed.emit()
	eq(qty.text, "1", "plus adds one")
	eq(qty.get_theme_color("font_color"), MarketScreen.CHALK_YELLOW, "a picked amount turns yellow")
	ProceduralUIFactory.text_scale = was_scale
	await _finish(game)


## Naikkan toko satu tier lewat alur sungguhan (after-hours, KR cukup).
func _upgrade_once(sim: SimulationRoot) -> String:
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	var nxt: LocationDefinition = sim.next_location()
	sim.debug_add_kr(nxt.upgrade_cost_kr)
	return sim.upgrade_location()


static func _mid_x(root: Node, child: String) -> float:
	return _rect(root, child).get_center().x


func _equipment() -> void:
	var game: GameRoot = await _boot("Market Equipment")
	var sim: SimulationRoot = game.sim
	eq(_upgrade_once(sim), "", "the shop moves to Tier 2")
	game.world.rebuild_all()
	sim.debug_add_kr(5000.0)
	check(bool(sim.equipment.buy(&"mixer_t2").get("ok", false)), "a Tier 2 mixer is bought into storage")
	var was_scale: float = ProceduralUIFactory.text_scale
	for pct: int in [100, 125, 150]:
		ProceduralUIFactory.text_scale = float(pct) / 100.0
		game.modals.close_all()
		var scr: MarketScreen = game.modals.open(&"market", {"tab": 1}) as MarketScreen
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		for cat: String in ["mixer", "oven", "display"]:
			var rows: Array[Node] = scr.find_children("Row_%s_t*" % cat, "PanelContainer", true, false)
			eq(rows.size(), 5, "%d%% %s: five tiers" % [pct, cat])
			var header: HBoxContainer = scr.find_child("Columns_%s" % cat, true, false) as HBoxContainer
			if rows.is_empty() or header == null:
				check(false, "%d%% %s: a table with a header" % [pct, cat])
				continue
			var cols: Dictionary = {"Stat": [], "Utility": [], "Size": [], "PriceEnd": [], "Action": []}
			var overlap: int = 0
			for row: Node in rows:
				(cols["Stat"] as Array).append(_mid_x(row, "Stat"))
				(cols["Utility"] as Array).append(_mid_x(row, "Utility"))
				(cols["Size"] as Array).append(_mid_x(row, "Size"))
				(cols["PriceEnd"] as Array).append(_rect(row, "Price").end.x)
				(cols["Action"] as Array).append(_mid_x(row, "Action"))
				if _rect(row, "ItemCell").end.x > _rect(row, "Stat").position.x + 0.5:
					overlap += 1
			for key: String in cols.keys():
				var vals: Array[float] = []
				vals.assign(cols[key])
				check(_spread(vals) <= 0.5, "%d%% %s: the %s column lines up (spread %.1f px)" % [pct, cat, key, _spread(vals)])
			eq(overlap, 0, "%d%% %s: no name runs into the numbers" % [pct, cat])
			near(_mid_x(header, str(MarketScreen.STAT_HEADERS[StringName(cat)])), float(cols["Stat"][0]), 1.0, "%d%% %s: the first number header sits over its column" % [pct, cat])
			near(_rect(header, "ui_equipment_col_price").end.x, float(cols["PriceEnd"][0]), 1.0, "%d%% %s: Price ends over the prices" % [pct, cat])
			var spacer: Control = header.get_child(header.get_child_count() - 1) as Control
			near(spacer.get_global_rect().get_center().x, float(cols["Action"][0]), 1.0, "%d%% %s: the action column lines up with the header" % [pct, cat])
		# Satu aksi per baris, sesuai keadaannya.
		var t1: Node = scr.find_child("Row_mixer_t1", true, false)
		check(t1.find_child("Buy", true, false) == null and t1.find_child("Replace", true, false) == null, "%d%%: no Buy or Replace to swap the Tier 1 mixer for itself" % pct)
		eq((t1.find_child("Owned", true, false) as Label).text, Tx.t("ui_equipment_owned_count", {"count": 1}), "%d%%: it is simply Owned" % pct)
		var t2: Node = scr.find_child("Row_mixer_t2", true, false)
		check(t2.find_child("Replace", true, false) != null, "%d%%: with both slots taken, Tier 2 offers Replace" % pct)
		eq((t2.find_child("OwnedCount", true, false) as Label).text, Tx.t("ui_equipment_owned_count", {"count": 1}), "%d%%: and says one is owned" % pct)
		var t3: Node = scr.find_child("Row_mixer_t3", true, false)
		eq((t3.find_child("Locked", true, false) as Label).text, Tx.t("ui_equipment_tier_locked", {"tier": 3}), "%d%%: Tier 3 needs a Tier 3 store" % pct)
		check(t3.find_child("Buy", true, false) == null and t3.find_child("Replace", true, false) == null, "%d%%: with no button" % pct)
		check((t3.find_child("ItemCell", true, false) as Control).modulate.a < 1.0, "%d%%: and is dimmed" % pct)
		check(scr.find_child("Row_oven_t1", true, false).find_child("Buy", true, false) != null, "%d%%: an oven slot is free, so Buy" % pct)
		var stored: Array[Node] = scr.find_children("Stored_*", "PanelContainer", true, false)
		eq(stored.size(), 1, "%d%%: the stored mixer is listed" % pct)
		if pct == 100 and not stored.is_empty():
			check(stored[0].find_child("Place", true, false) != null and stored[0].find_child("Sell", true, false) != null, "with Place and Sell")
			var short: Array[String] = []
			for b: Node in scr.find_child("EquipmentRows", true, false).find_children("*", "Button", true, false):
				if (b as Control).is_visible_in_tree() and (b as Control).size.y < ProceduralUIFactory.TOUCH_MIN - 0.5:
					short.append("%s %.0f px" % [b.name, (b as Control).size.y])
			eq(short, [] as Array[String], "every button in the table is a full-size touch target")
	# Siang hari: hanya-baca.
	ProceduralUIFactory.text_scale = 1.0
	sim.time.set_phase(TimeManager.OPEN)
	game.modals.close_all()
	var day: MarketScreen = game.modals.open(&"market", {"tab": 1}) as MarketScreen
	await runner.get_tree().process_frame
	var enabled: int = 0
	for b2: Node in day.find_children("*", "Button", true, false):
		if String(b2.name) in ["Buy", "Replace", "Sell"] and not (b2 as Button).disabled:
			enabled += 1
	eq(enabled, 0, "during the day Buy, Replace and Sell are read-only")
	ProceduralUIFactory.text_scale = was_scale
	await _finish(game)


func _upgrade() -> void:
	var game: GameRoot = await _boot("Market Upgrade")
	var sim: SimulationRoot = game.sim
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	var was_scale: float = ProceduralUIFactory.text_scale
	for pct: int in [100, 125, 150]:
		ProceduralUIFactory.text_scale = float(pct) / 100.0
		game.modals.close_all()
		var scr: MarketScreen = game.modals.open(&"market", {"tab": 2}) as MarketScreen
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		var rows: Array[Node] = scr.find_children("Compare_*", "PanelContainer", true, false)
		eq(rows.size(), 9, "%d%%: nine rows compare the locations" % pct)
		var head: Node = scr.find_child("UpgradeColumns", true, false)
		var now_x: Array[float] = []
		var next_x: Array[float] = []
		for row: Node in rows:
			now_x.append(_mid_x(row, "Now"))
			next_x.append(_mid_x(row, "Next"))
		check(_spread(now_x) <= 0.5 and _spread(next_x) <= 0.5, "%d%%: both value columns line up" % pct)
		near(_mid_x(head, "Now"), now_x[0], 1.0, "%d%%: under the current location name" % pct)
		near(_mid_x(head, "Next"), next_x[0], 1.0, "%d%%: and the next location name" % pct)
		if pct == 100:
			var list: Control = scr.find_child("UpgradeRows", true, false) as Control
			check(list.get_combined_minimum_size().y <= (list.get_parent() as Control).size.y + 0.5, "at 100% every row fits without scrolling")
			var popup_h: float = 0.0
			for c: Node in scr.find_children("*", "PanelContainer", true, false):
				popup_h = maxf(popup_h, (c as Control).size.y)
			check(popup_h <= 660.5, "the popup keeps its size (%.0f px)" % popup_h)
			var mixers: Node = scr.find_child("Compare_ui_upgrade_row_mixers", true, false)
			eq((mixers.find_child("Next", true, false) as Label).text, "2  (+1)", "Tier 2 adds a mixer")
			eq((mixers.find_child("Next", true, false) as Label).get_theme_color("font_color"), MarketScreen.CHALK_YELLOW, "written in yellow chalk")
			var lanes: Node = scr.find_child("Compare_ui_upgrade_row_lanes", true, false)
			eq((lanes.find_child("Next", true, false) as Label).text, "2", "the same number of lanes has no mark")
			eq((lanes.find_child("Next", true, false) as Label).get_theme_color("font_color"), Palette.CHALK_WHITE, "and stays white")
			for row2: Node in rows:
				var key: String = String(row2.name).trim_prefix("Compare_")
				eq((row2.find_child("Label", true, false) as Label).text, Tx.t(key), "%s in English" % key)
			var up: Button = scr.find_child("Upgrade", true, false) as Button
			check(up != null and up.disabled, "without the money the upgrade waits")
			eq((scr.find_child("Reason", true, false) as Label).text, Tx.t("ui_feedback_not_enough_kr"), "and says why")
	# Tier tertinggi: hanya lokasi sekarang.
	ProceduralUIFactory.text_scale = 1.0
	while sim.next_location() != null:
		eq(_upgrade_once(sim), "", "upgrade to Tier %d" % (sim.world.location.tier + 1))
	game.world.rebuild_all()
	game.modals.close_all()
	var top: MarketScreen = game.modals.open(&"market", {"tab": 2}) as MarketScreen
	await runner.get_tree().process_frame
	check(top.find_child("Next", true, false) == null, "at the top tier there is no next location")
	eq((top.find_child("TopTier", true, false) as Label).text, Tx.t("ui_upgrade_max"), "but a proud line")
	check(top.find_child("Upgrade", true, false) == null, "and no upgrade button")
	ProceduralUIFactory.text_scale = was_scale
	await _finish(game)


func _replace_pick() -> void:
	var game: GameRoot = await _boot("Market Replace")
	var sim: SimulationRoot = game.sim
	eq(_upgrade_once(sim), "", "Tier 2")
	eq(_upgrade_once(sim), "", "Tier 3: three mixer slots")
	sim.time.set_phase(TimeManager.AFTER_HOURS)
	sim.debug_add_kr(20000.0)
	for def_id: StringName in [&"mixer_t1", &"mixer_t2"]:
		var r: Dictionary = sim.equipment.buy(def_id)
		var e: EquipmentInstance = sim.equipment.get_inst(int(r.get("iid", -1)))
		check(e != null and sim.world.auto_place(e), "a %s is placed" % def_id)
		sim.equipment.invalidate_lists()
	game.world.rebuild_all()
	eq(sim.equipment.placed_count(&"mixer"), 3, "three mixers stand in the kitchen")
	game.modals.close_all()
	var scr: MarketScreen = game.modals.open(&"market", {"tab": 1}) as MarketScreen
	await runner.get_tree().process_frame
	# Tier 1: hanya Tier 2 yang bisa digantikan (dua Tier 1 tidak ditawarkan).
	eq(scr._replace_candidates(DataRegistry.equipment(&"mixer_t1")).size(), 1, "a Tier 1 can only take the Tier 2 place")
	var t2_iid: int = -1
	for e2: EquipmentInstance in sim.equipment.placed_list(&"mixer"):
		if e2.def_id == &"mixer_t2":
			t2_iid = e2.iid
	var rep: Button = scr.find_child("Row_mixer_t3", true, false).find_child("Replace", true, false) as Button
	check(rep != null and not rep.disabled, "Tier 3 offers Replace")
	if rep == null:
		await _finish(game)
		return
	rep.pressed.emit()
	await runner.get_tree().process_frame
	check(game.modals.is_open(&"replace_picker"), "with three candidates it asks which one")
	var picker: ReplacePicker = game.modals.top() as ReplacePicker
	if picker == null:
		await _finish(game)
		return
	eq(picker.find_children("Pick_*", "Button", true, false).size(), 3, "one button per placed mixer")
	check(game.modals.is_open(&"market"), "the Market stays open underneath")
	(picker.find_child("Pick_%d" % t2_iid, true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var old: EquipmentInstance = sim.equipment.get_inst(t2_iid)
	check(old != null and not old.placed, "the chosen Tier 2 goes to storage")
	# Mixer Tier 3 berjejak 2x1, jadi tidak muat di tempat Tier 2 (1x1): ia
	# menunggu ditempatkan dan Decoration Mode terbuka (GDD 5.1.2).
	var t3: Array[EquipmentInstance] = []
	for e3: EquipmentInstance in sim.equipment.placed_list(&"mixer") + sim.equipment.unplaced_list(&"mixer"):
		if e3.def_id == &"mixer_t3":
			t3.append(e3)
	eq(t3.size(), 1, "a Tier 3 mixer was bought in its place")
	if t3.size() == 1 and not t3[0].placed:
		check(game.modals.is_open(&"decoration"), "and Decoration Mode opens to place it")
	# Alat yang sedang dipakai tidak bisa dipilih.
	var shelf: int = sim.equipment.placed_list(&"display")[0].iid
	stock(sim, &"recipe_plain_loaf", 3, 0, shelf)
	check(sim.equipment.is_in_use(shelf), "a shelf with bread is in use")
	game.modals.close_all()
	game.modals.open(&"market", {"tab": 1})
	var picked: Array[int] = []
	var p2: ReplacePicker = game.modals.open(&"replace_picker", {"def_id": &"display_t2", "candidates": [shelf],
		"on_pick": func(i: int) -> void: picked.append(i)}) as ReplacePicker
	await runner.get_tree().process_frame
	var b: Button = p2.find_child("Pick_%d" % shelf, true, false) as Button
	check(b != null and b.disabled, "a shelf holding bread cannot be chosen")
	check(b != null and b.text.ends_with(Tx.t("ui_feedback_in_use")), "and says it is in use")
	(p2.find_child("Cancel", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	check(not game.modals.is_open(&"replace_picker") and picked.is_empty(), "Cancel closes it without a choice")
	await _finish(game)
