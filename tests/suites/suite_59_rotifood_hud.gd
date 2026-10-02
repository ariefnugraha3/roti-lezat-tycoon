extends TestSuite
## Pesanan RotiFood di HUD (GDD 7, 22; keputusan maintainer 2026-10-02). Keluhan:
## pemain kadang tidak sadar ada pesanan RotiFood. Panelnya pindah ke kanan
## bawah tepat di atas Quick Menu, dan tombol RotiFood berdering selama ada
## pesanan yang belum dikemas. Baris pesanan kini hanya dibangun ulang bila
## isinya berubah: dulu dibangun ulang 5x per detik, sehingga ketukan yang
## melewati satu refresh hilang. Label ubin Quick Menu di bawahnya kini selalu
## muat di muka ubin (dulu label dua baris keluar dari ubin).


func tests() -> Array:
	return [
		{"id": "ACC_7_ROTIFOOD_PANEL", "name": "7 the RotiFood orders panel sits right above the Quick Menu, right-aligned with it and as wide as the Display Stock panel, which moves up only when they would overlap", "fn": _panel},
		{"id": "ACC_22_ROTIFOOD_BUTTON_RINGS", "name": "22 the RotiFood button rings with a count badge while an order waits to be packed, rings red and twice as often while the driver waits, and rests once everything is packed; Reduced Motion keeps the color and badge without the motion", "fn": _rings},
		{"id": "ACC_22_ROTIFOOD_ROWS_KEEP", "name": "22 order rows survive the HUD refresh, so a tap that spans a refresh still opens the order", "fn": _rows_keep},
		{"id": "ACC_7_QUICK_MENU_LABELS", "name": "7, 28.5 Quick Menu labels fit inside their tiles above the lip at 100, 125 and 150% text scale, in at most two whole-word lines; tiles share one size, icons line up, and the tutorial hint and after-hours buttons stay clear of the bottom panels", "fn": _quick_labels},
	]


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_rotifood_hud"
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
	# Simulasi dibekukan: status pesanan hanya berubah oleh tes ini.
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


func _order(game: GameRoot, qty: int) -> DeliveryOrder:
	var o: DeliveryOrder = game.sim.rotifood.create_scripted_order(&"recipe_plain_loaf", qty)
	# Popup tutorial RotiFood tidak boleh menutupi HUD.
	game.modals.close_all()
	game.hud._refresh_all()
	return o


func _button(pos: Vector2, pressed: bool) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = MOUSE_BUTTON_LEFT
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	runner.get_viewport().push_input(e, true)


## Jalankan animasi tombol dengan langkah waktu tetap (deterministik, tanpa
## menunggu detik nyata) dan catat gerak terbesar serta awal tiap gelombang.
func _watch(rb: RotiFoodButton, seconds: float) -> Dictionary:
	var out: Dictionary = {"rot": 0.0, "scale": 1.0, "ripples": 0}
	var last: float = -1.0
	var dt: float = 1.0 / 60.0
	var steps: int = int(round(seconds / dt))
	for i in steps:
		rb._process(dt)
		out["rot"] = maxf(float(out["rot"]), absf(rb.body().rotation))
		out["scale"] = maxf(float(out["scale"]), rb.body().scale.x)
		var r: float = rb.ripple()
		if r >= 0.0 and (last < 0.0 or r < last):
			out["ripples"] = int(out["ripples"]) + 1
		last = r
	return out


func _panel() -> void:
	var game: GameRoot = await _boot("Panel Bakery")
	var hud: HUD = game.hud
	await _frames(3)
	var quick: Rect2 = hud.quick_menu().get_global_rect()
	var rf: Rect2 = hud.rotifood_panel().get_global_rect()
	var st: Rect2 = hud.stock_panel().get_global_rect()
	near(rf.end.y, quick.position.y - HUD.PANEL_GAP, 1.0, "the panel rests just above the Quick Menu")
	near(rf.end.x, quick.end.x, 1.0, "right-aligned with the Quick Menu")
	near(rf.size.x, st.size.x, 0.5, "as wide as the Display Stock panel")
	check(not rf.intersects(st), "no overlap with the Display Stock panel")
	var st_y0: float = st.position.y
	# Lima pesanan dan rak penuh empat resep: panel RotiFood tumbuh ke atas dan
	# stok display bergeser naik secukupnya.
	for i in 5:
		_order(game, 2 + i % 3)
	var idx: int = 0
	for rid: StringName in [&"recipe_plain_loaf", &"recipe_sugar_donut", &"recipe_plain_fried_bread", &"recipe_chocolate_bread"]:
		stock(game.sim, rid, 3, idx)
		idx += 1
	hud._refresh_all()
	await _frames(4)
	rf = hud.rotifood_panel().get_global_rect()
	st = hud.stock_panel().get_global_rect()
	near(rf.end.y, quick.position.y - HUD.PANEL_GAP, 1.0, "with five orders it still rests on the Quick Menu and grows upward")
	eq(hud._orders_box.get_child_count(), HUD.ORDER_ROWS + 1, "three order rows and a \"+2 more\" row")
	eq((hud._orders_box.get_node("More") as Button).text, Tx.t("ui_rotifood_more", {"count": 2}), "the extra row counts the hidden orders")
	check(not rf.intersects(st), "the Display Stock panel moves up instead of overlapping")
	check(st.position.y < st_y0 - 1.0, "it moved up (%.0f -> %.0f)" % [st_y0, st.position.y])
	check(st.position.y >= hud._top_right.get_global_rect().end.y, "but not over the top-right corner")
	near(rf.size.x, st.size.x, 0.5, "both panels keep one width")
	await _finish(game)


func _rings() -> void:
	var game: GameRoot = await _boot("Ring Bakery")
	var hud: HUD = game.hud
	var rb: RotiFoodButton = hud.rotifood_button()
	var was_rm: Variant = SettingsManager.values.get("reduced_motion", false)
	SettingsManager.values["reduced_motion"] = false
	hud._refresh_all()
	eq(rb.waiting(), 0, "no orders: nothing waits")
	eq(rb.badge_text(), "", "no badge")
	check(not rb.is_ringing(), "the button rests")
	eq(str(rb.button.get_meta("kind")), "secondary", "cream button at rest")
	# Pesanan baru: lencana 1, hijau, dan berdering.
	var o: DeliveryOrder = _order(game, 2)
	eq(rb.waiting(), 1, "one order waits to be packed")
	eq(rb.badge_text(), "1", "the badge counts it")
	check(rb.is_ringing(), "a new order rings the button at once")
	eq(str(rb.button.get_meta("kind")), "success", "the button turns green")
	var m: Dictionary = _watch(rb, RotiFoodButton.RING_PERIOD * 2.0 - 0.1)
	check(float(m["rot"]) > 0.08, "it shakes like a phone (%.3f rad)" % float(m["rot"]))
	check(float(m["scale"]) > 1.08, "it pops bigger (%.2fx)" % float(m["scale"]))
	eq(int(m["ripples"]), 2, "a ripple ring every %.1f s" % RotiFoodButton.RING_PERIOD)
	var o2: DeliveryOrder = _order(game, 3)
	eq(rb.badge_text(), "2", "a second order raises the count")
	# Driver sudah menunggu pesanan yang belum dikemas: merah, dua kali lebih sering.
	o2.driver_phase = &"queued"
	hud._refresh_all()
	check(rb.is_urgent(), "a waiting driver makes it urgent")
	eq(str(rb.button.get_meta("kind")), "danger", "the button turns red")
	var row: Button = hud._orders_box.get_node_or_null("Order%d" % o2.order_id)
	check(row != null and str(row.get_meta("kind")) == "danger", "that order's row turns red too")
	var m2: Dictionary = _watch(rb, RotiFoodButton.RING_PERIOD * 2.0 - 0.1)
	eq(int(m2["ripples"]), 4, "it rings twice as often")
	o2.driver_phase = &"none"
	# Semua dikemas: diam lagi.
	stock(game.sim, &"recipe_plain_loaf", 8)
	check(game.sim.rotifood.pack(o.order_id) and game.sim.rotifood.pack(o2.order_id), "both orders are packed")
	hud._refresh_all()
	eq(rb.waiting(), 0, "nothing left to pack")
	eq(rb.badge_text(), "", "the badge goes away")
	check(not rb.is_ringing(), "packed orders do not ring")
	near(rb.body().rotation, 0.0, 0.0001, "upright again")
	near(rb.body().scale.x, 1.0, 0.0001, "normal size again")
	check(rb.ripple() < 0.0, "no ripple")
	eq(str(rb.button.get_meta("kind")), "secondary", "back to the cream button")
	eq(game.sim.rotifood.active_orders().size(), 2, "the packed orders still wait for their drivers")
	# Reduced Motion: warna dan lencana tetap, gerak tidak ada.
	SettingsManager.values["reduced_motion"] = true
	_order(game, 2)
	eq(rb.badge_text(), "1", "Reduced Motion keeps the badge")
	eq(str(rb.button.get_meta("kind")), "success", "and the green face")
	var m3: Dictionary = _watch(rb, RotiFoodButton.RING_PERIOD * 2.0 - 0.1)
	near(float(m3["rot"]), 0.0, 0.0001, "but does not shake")
	near(float(m3["scale"]), 1.0, 0.0001, "or pop")
	eq(int(m3["ripples"]), 0, "or ripple")
	SettingsManager.values["reduced_motion"] = was_rm
	await _finish(game)


func _rows_keep() -> void:
	var game: GameRoot = await _boot("Rows Bakery")
	var hud: HUD = game.hud
	var o: DeliveryOrder = _order(game, 2)
	var row: Button = hud._orders_box.get_node_or_null("Order%d" % o.order_id)
	check(row != null, "the order has a row")
	for i in 5:
		hud._refresh_all()
	check(is_instance_valid(row) and row.get_parent() == hud._orders_box, "refreshing without changes keeps the same row")
	await _frames(3)
	# Ketukan sungguhan yang melewati satu refresh HUD.
	var pos: Vector2 = row.get_global_rect().get_center()
	_button(pos, true)
	await _frames(1)
	hud._refresh_all()
	await _frames(1)
	_button(pos, false)
	await _frames(1)
	check(game.modals.is_open(&"rotifood"), "the tap opens the RotiFood order")
	game.modals.close_all()
	# Isinya berubah (dikemas): barisnya diganti.
	stock(game.sim, &"recipe_plain_loaf", 4)
	check(game.sim.rotifood.pack(o.order_id), "the order is packed")
	hud._refresh_all()
	var row2: Button = hud._orders_box.get_node_or_null("Order%d" % o.order_id)
	check(row2 != null and row2 != row, "a changed order gets a fresh row")
	check(row2 != null and (row2.find_child("Text", true, false) as Label).text.ends_with(Tx.t("ui_rotifood_row_packed")), "the row now says Packed")
	await _finish(game)


## Ubin Quick Menu pada tiga skala teks (GDD 28.5): HUD dibangun ulang untuk
## setiap skala, karena ukurannya dihitung saat dibangun.
func _quick_labels() -> void:
	var game: GameRoot = await _boot("Quick Bakery")
	var was: float = ProceduralUIFactory.text_scale
	for pct: int in [100, 125, 150]:
		ProceduralUIFactory.text_scale = float(pct) / 100.0
		var hud := HUD.new()
		hud.game = game
		hud.sim = game.sim
		runner.add_child(hud)
		hud.show_tutorial_hint("tut_rotifood", &"", -1)
		hud._after_hours.visible = true
		hud.set_process(false)
		await _frames(3)
		var tiles: Array[Node] = hud.quick_menu().get_children()
		eq(tiles.size(), 4, "%d%%: four tiles" % pct)
		var first: Rect2 = (tiles[0] as Control).get_global_rect()
		var icon_y: float = (tiles[0].find_child("Icon", true, false) as Control).get_global_rect().position.y
		for t: Node in tiles:
			var r: Rect2 = (t as Control).get_global_rect()
			var cap: Label = t.find_child("Caption", true, false) as Label
			var c: Rect2 = cap.get_global_rect()
			check(r.size.is_equal_approx(first.size), "%d%%: %s has the shared tile size" % [pct, cap.text])
			check(c.end.y <= r.end.y - ProceduralUIFactory.lip() + 0.5, "%d%%: %s stays above the tile's lip (%.0f <= %.0f)" % [pct, cap.text, c.end.y, r.end.y - ProceduralUIFactory.lip()])
			check(c.position.x >= r.position.x and c.end.x <= r.end.x, "%d%%: %s stays inside the tile sideways" % [pct, cap.text])
			check(cap.get_line_count() <= HUD.QUICK_LINES, "%d%%: %s needs at most two lines, no word is broken (%d)" % [pct, cap.text, cap.get_line_count()])
			eq(cap.get_visible_line_count(), cap.get_line_count(), "%d%%: every line of %s is shown" % [pct, cap.text])
			near((t.find_child("Icon", true, false) as Control).get_global_rect().position.y, icon_y, 0.5, "%d%%: %s's icon lines up" % [pct, cap.text])
		var bottoms: Array[Rect2] = [hud.quick_menu().get_global_rect(), hud._clock_panel.get_global_rect()]
		for b: Rect2 in bottoms:
			check(not hud._hint.get_global_rect().intersects(b), "%d%%: the tutorial hint clears the bottom panels" % pct)
			check(not hud._after_hours.get_global_rect().intersects(b), "%d%%: the after-hours buttons clear the bottom panels" % pct)
		check(not hud.rotifood_panel().get_global_rect().intersects(bottoms[0]), "%d%%: the RotiFood panel rests above the taller tiles" % pct)
		hud.queue_free()
		await _frames(1)
	ProceduralUIFactory.text_scale = was
	await _finish(game)
