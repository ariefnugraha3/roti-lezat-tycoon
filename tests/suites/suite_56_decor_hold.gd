extends TestSuite
## Decoration Mode seperti The Sims (GDD 72.2, keputusan maintainer 2026-10-01):
## perabot diangkat, diseret per ubin atau dipindah dengan ketukan ke ubin mana
## pun (juga ubin yang tertutup perabot lain), dan baru ditaruh saat Place.
## Gestur dikirim sebagai event mouse sungguhan lewat viewport, jadi
## CommandLayer ikut diuji. Keluhan yang diperbaiki: ketukan pada ubin yang
## tertutup perabot lain malah memilih perabot itu, dan ketukan pada perabot
## terpilih (saat ingin menggesernya satu ubin) malah meletakkannya.


func tests() -> Array:
	return [
		{"id": "ACC_72_DECOR_DRAG", "name": "72.2 dragging furniture moves it tile by tile under the finger, the shop changes only on Place, and Cancel or Back puts it back", "fn": _drag},
		{"id": "ACC_72_DECOR_TAP_THROUGH", "name": "72.2 while holding, a tap lands on the floor under the finger (also behind other furniture), never picks another piece and never drops the held one; dragging the floor pans the camera", "fn": _tap_through},
		{"id": "ACC_72_DECOR_NEW_ITEM", "name": "72.2 an item from the tray appears on a free spot on screen and stays in storage until placed; Done places a validly held item", "fn": _new_item},
	]


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_decor_hold"
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
	return game


func _open(game: GameRoot) -> DecorationScreen:
	var deco: DecorationScreen = game.modals.open(&"decoration", {}) as DecorationScreen
	# Satu frame agar GameRoot menyalakan CommandLayer untuk layar dunia ini.
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	await _settle_camera(game)
	return deco


## Kamera Decoration Mode meluncur pelan ke tengah ruangan selama beberapa frame.
## Gestur yang dihitung dari posisi layar baru tepat setelah kamera diam; kalau
## tidak, lantai di bawah jari ikut bergeser di tengah drag.
func _settle_camera(game: GameRoot) -> void:
	var cam: Camera3D = game.world.camera_rig.camera
	var last: Vector3 = cam.global_position
	for i in 240:
		await runner.get_tree().process_frame
		var now: Vector3 = cam.global_position
		if now.distance_to(last) < 0.0005:
			return
		last = now


func _finish(game: GameRoot) -> void:
	game.modals.close_all()
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


# ===========================================================================
# EVENT MOUSE
# ===========================================================================

func _button(pos: Vector2, pressed: bool, index: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var e := InputEventMouseButton.new()
	e.button_index = index
	e.pressed = pressed
	e.position = pos
	e.global_position = pos
	e.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed and index == MOUSE_BUTTON_LEFT else 0
	runner.get_viewport().push_input(e, true)


func _motion(from: Vector2, to: Vector2, steps: int) -> void:
	var last: Vector2 = from
	for i in range(1, steps + 1):
		var p: Vector2 = from.lerp(to, float(i) / float(steps))
		var m := InputEventMouseMotion.new()
		m.position = p
		m.global_position = p
		m.relative = p - last
		m.button_mask = MOUSE_BUTTON_MASK_LEFT
		runner.get_viewport().push_input(m, true)
		last = p


func _tap(pos: Vector2) -> void:
	_button(pos, true)
	_button(pos, false)


func _drag_gesture(from: Vector2, to: Vector2) -> void:
	_button(from, true)
	_motion(from, to, 8)
	_button(to, false)


## true bila titik layar tertutup bilah atas, tab bawah, atau toolbar.
func _over_ui(deco: DecorationScreen, p: Vector2) -> bool:
	for c: Control in [deco._top, deco._bottom, deco.toolbar().panel]:
		if c.is_visible_in_tree() and c.get_global_rect().grow(8.0).has_point(p):
			return true
	return false


## Titik layar di badan perabot `iid` (pusat kotaknya), atau (-1, -1).
func _body_point(world: WorldView, iid: int) -> Vector2:
	var ad: Variant = world._aabbs.get(iid)
	if not (ad is Dictionary):
		return Vector2(-1, -1)
	return world.camera_rig.world_to_screen(((ad as Dictionary)["aabb"] as AABB).get_center())


## Titik layar yang digeser satu langkah `d` (ubin) di lantai dari titik `p`.
func _shift(world: WorldView, p: Vector2, d: Vector2i) -> Vector2:
	var g: Vector3 = world.camera_rig.screen_to_ground(p)
	return world.camera_rig.world_to_screen(g + Vector3(float(d.x), 0.0, float(d.y)) * GridMath.WORLD_METERS_PER_TILE)


## Perabot yang badannya bisa ditekan di layar dan muat digeser satu ubin:
## {e, d, at}; kosong bila tidak ada.
func _movable(game: GameRoot) -> Dictionary:
	var world: WorldView = game.world
	for e: EquipmentInstance in game.sim.equipment.placed_list():
		if e.floor_id != world.camera_rig.active_floor or game.sim.equipment.is_in_use(e.iid):
			continue
		var at: Vector2 = _body_point(world, e.iid)
		var p: Dictionary = world.pick(at)
		if int(p.get("iid", -1)) != e.iid or p.has("cell"):
			continue
		for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			if game.sim.world.validate_placement(e, e.floor_id, e.anchor + d, e.rotation) == &"":
				return {"e": e, "d": d, "at": at}
	return {}


# ===========================================================================
# TES
# ===========================================================================

func _drag() -> void:
	var game: GameRoot = await _boot("Drag Bakery")
	var deco: DecorationScreen = await _open(game)
	var world: WorldView = game.world
	var mv: Dictionary = _movable(game)
	check(not mv.is_empty(), "some furniture can move one tile")
	if mv.is_empty():
		await _finish(game)
		return
	var e: EquipmentInstance = mv["e"]
	var d: Vector2i = mv["d"]
	var a0: Vector2i = e.anchor
	var from: Vector2 = mv["at"]
	var to: Vector2 = _shift(world, from, d)
	var pan0: Vector3 = world.camera_rig.pan_offset
	# 1. Tekan badan perabot lalu seret: perabot terangkat dan ikut jari.
	_button(from, true)
	_motion(from, from.lerp(to, 0.5), 4)
	check(game.commands.is_dragging_capture(), "pressing on furniture and moving drags it")
	eq(world.lifted_iid(), e.iid, "the drag picks the furniture up at once")
	await runner.get_tree().process_frame
	check(not deco.toolbar().visible, "the toolbar hides while dragging")
	_motion(from.lerp(to, 0.5), to, 4)
	_button(to, false)
	await runner.get_tree().process_frame
	check(not game.commands.is_dragging_capture(), "lifting the finger ends the drag")
	eq(Vector2i(world.held()["cell"]), a0 + d, "the furniture followed the finger by exactly one tile")
	eq(e.anchor, a0, "the shop layout does not change before Place")
	check(world.camera_rig.pan_offset.is_equal_approx(pan0), "the camera stays put while furniture is dragged")
	check(deco.toolbar().visible, "the toolbar comes back above it after the drop")
	eq(deco._cand_reason, &"", "the new spot is valid")
	eq(deco._status.text, Tx.t("ui_decor_valid"), "the hint says it fits and to tap Place")
	# 2. Place lewat tombol toolbar.
	deco._tb_place.pressed.emit()
	await runner.get_tree().process_frame
	eq(e.anchor, a0 + d, "Place moves it in the shop")
	check(not deco.has_selection(), "and lets go of it")
	# 3. Seret kembali lalu Cancel: tetap di tempat terakhir yang ditaruh.
	from = _body_point(world, e.iid)
	_drag_gesture(from, _shift(world, from, -d))
	await runner.get_tree().process_frame
	eq(Vector2i(world.held()["cell"]), a0, "dragged back by one tile")
	deco._tb_cancel.pressed.emit()
	await runner.get_tree().process_frame
	eq(e.anchor, a0 + d, "Cancel leaves it where it was placed")
	check(not deco.has_selection(), "Cancel lets go of it")
	# 4. Seret lagi lalu klik kanan (Back): juga kembali, mode tetap terbuka.
	from = _body_point(world, e.iid)
	_drag_gesture(from, _shift(world, from, -d))
	await runner.get_tree().process_frame
	check(deco.has_selection(), "dragging picks it up again")
	_button(from, true, MOUSE_BUTTON_RIGHT)
	_button(from, false, MOUSE_BUTTON_RIGHT)
	await runner.get_tree().process_frame
	check(not deco.has_selection(), "a right-click puts it back")
	eq(e.anchor, a0 + d, "without moving it")
	check(game.modals.is_open(&"decoration"), "and Decoration Mode stays open")
	await _finish(game)


func _tap_through() -> void:
	var game: GameRoot = await _boot("Tap Through Bakery")
	var deco: DecorationScreen = await _open(game)
	var world: WorldView = game.world
	var rig: CameraRig = world.camera_rig
	# Satu perabot dipegang, satu perabot lain menutupi lantai di belakangnya.
	var held: EquipmentInstance = null
	var other: EquipmentInstance = null
	var over: Vector2 = Vector2(-1, -1)
	for x: EquipmentInstance in game.sim.equipment.placed_list():
		if x.floor_id != rig.active_floor:
			continue
		var box: AABB = world._aabbs[x.iid]["aabb"]
		var p: Vector2 = rig.world_to_screen(Vector3(box.get_center().x, box.end.y - 0.02, box.get_center().z))
		var pk: Dictionary = world.pick(p)
		if other == null and int(pk.get("iid", -1)) == x.iid and not pk.has("cell"):
			other = x
			over = p
		elif held == null and not game.sim.equipment.is_in_use(x.iid):
			held = x
	check(held != null and other != null, "two pieces of furniture on screen")
	if held == null or other == null:
		await _finish(game)
		return
	var a0: Vector2i = held.anchor
	deco._hold_equipment(held.iid)
	await runner.get_tree().process_frame
	eq(deco._sel_iid, held.iid, "the furniture is held")
	# Ketuk badan perabot lain: yang dituju lantai di bawah jari, bukan perabot itu.
	var under: Vector2i = world.cell_at_screen(over)
	_tap(over)
	await runner.get_tree().process_frame
	eq(deco._sel_iid, held.iid, "tapping another piece while holding never picks it")
	eq(Vector2i(world.held()["cell"]), deco._clamp_anchor(deco._anchor_for(under)),
		"the held piece moves to the floor tile under the finger, behind the other piece")
	eq(held.anchor, a0, "nothing is placed yet")
	# Ketuk badan barang yang dipegang: tidak pernah meletakkan atau membatalkannya.
	var top: Vector3 = world.hold_top()
	_tap(rig.world_to_screen(top - Vector3(0.0, 0.08, 0.0)))
	await runner.get_tree().process_frame
	eq(deco._sel_iid, held.iid, "tapping the held piece itself never drops it")
	eq(held.anchor, a0, "and never places it by accident")
	# Drag di lantai kosong menggeser kamera dan tidak menyentuh barang yang dipegang.
	var floor_pt: Vector2 = Vector2(-1, -1)
	var view: Vector2 = runner.get_viewport().get_visible_rect().size
	for gy in range(6, 15):
		for gx in range(4, 17):
			var q: Vector2 = Vector2(view.x * float(gx) / 20.0, view.y * float(gy) / 20.0)
			if floor_pt.x < 0.0 and world.pick(q).get("kind", &"") == &"cell" and not world.hold_hit(q) and not _over_ui(deco, q):
				floor_pt = q
	check(floor_pt.x >= 0.0, "found an empty bit of floor on screen")
	var before: Dictionary = world.held()
	var pan0: Vector3 = rig.pan_offset
	_drag_gesture(floor_pt, floor_pt + Vector2(90.0, 40.0))
	await runner.get_tree().process_frame
	check(rig.pan_offset.distance_to(pan0) > 0.05, "dragging the floor pans the camera")
	eq(world.held(), before, "and leaves the held piece where it was")
	deco._cancel()
	eq(held.anchor, a0, "Cancel leaves the shop as it was")
	await _finish(game)


func _new_item() -> void:
	var game: GameRoot = await _boot("New Item Bakery")
	var deco: DecorationScreen = await _open(game)
	var world: WorldView = game.world
	var e: EquipmentInstance = null
	for x: EquipmentInstance in game.sim.equipment.placed_list():
		if not EquipmentManager.is_fixture(x.category()) and not game.sim.equipment.is_in_use(x.iid):
			e = x
			break
	check(e != null, "some furniture can be put away")
	if e == null:
		await _finish(game)
		return
	deco._hold_equipment(e.iid)
	deco._put_away()
	check(not e.placed and not deco.has_selection(), "Put Away stores it")
	# Kartu baki: barang muncul di tempat sah di layar, tetap di gudang sampai Place.
	deco._set_tab(DecorationScreen.TAB_EQUIPMENT)
	await runner.get_tree().process_frame
	deco._pick_equipment_card(e.iid)
	await runner.get_tree().process_frame
	eq(deco._sel_iid, e.iid, "the tray card picks the stored item up")
	eq(deco._cand_reason, &"", "it appears on a free spot")
	check(not e.placed, "it stays in storage until it is placed")
	var node: Node3D = world.hold_node()
	check(node != null and node.visible and not world.furniture.values().has(node), "a preview model shows it in the room")
	var at: Vector2 = world.camera_rig.world_to_screen(world.hold_top())
	check(runner.get_viewport().get_visible_rect().has_point(at), "on screen (%s)" % at)
	eq(deco._status.text, Tx.t("ui_decor_place_hint"), "the hint says to drag it or tap a tile, then Place")
	var spot: Vector2i = world.held()["cell"]
	# Done menaruh barang yang dipegang di tempat yang sah, lalu menutup mode.
	deco._done()
	await runner.get_tree().process_frame
	check(e.placed and e.anchor == spot, "Done puts the held item down where it was shown")
	check(not game.modals.is_open(&"decoration"), "and closes Decoration Mode")
	check(node == null or not is_instance_valid(node) or node.is_queued_for_deletion(), "the preview model is gone")
	await _finish(game)
