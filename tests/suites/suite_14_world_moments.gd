extends TestSuite
## Momen dunia (GDD idle §20 no. 71): staf baru masuk lewat pintu dan menyapa,
## stasiun baru datang dalam kardus. Murni tontonan; toko tidak di-pause.

const SPEED: float = 4.0
const WAIT_FRAMES: int = 6000


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_HIRE_WELCOME", "name": "idle 20 no. 71 a new hire walks in from the pavement through the door as a look-alike, waves and greets with a bubble, then takes over from the real staff member (hidden meanwhile) who has been working since the hire; hiring from the Staff sheet closes it; Reduced Motion only shows the greeting", "fn": _welcome},
		{"id": "ACC_IDLE_RECIPE_REVEAL", "name": "idle 20 no. 73 unlocking a recipe in the Menu sheet shows a non-blocking spotlight over it (bread art popping in on rays, 'New on the menu!' with its name and price) that closes by itself after a moment or at a tap, the bread flying into the Menu tab; the sheet stays open and the shop keeps running", "fn": _recipe_reveal},
		{"id": "ACC_IDLE_MOMENTS_REBUILD", "name": "idle 20 no. 71, 84 a station delivery and a new hire's welcome that are still playing when the whole world is rebuilt (moving location, visiting a branch) end quietly: no freed box or look-alike is touched, the moments clear, the new shelf shows and the staff member is visible again", "fn": _moments_rebuild},
		{"id": "ACC_IDLE_STATION_DELIVERY", "name": "idle 20 no. 71 a newly opened station arrives in a cardboard box that drops, lands, opens and gives way to the station popping out; an upstairs station is shown briefly before the camera returns; opening from the Shop sheet closes it; Reduced Motion only sparkles", "fn": _delivery},
	]


func _boot(label: String, tier: int = 1) -> GameRoot:
	SaveManager.dir = "user://test_saves_moments"
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
	jump_to_tier(game.sim, tier)
	game.modals.close_all()
	PauseManager.clear_all()
	game.sim.debug_add_kr(1.0e9)
	game.playing = true
	await _frames(3)
	return game


func _finish(game: GameRoot) -> void:
	Engine.time_scale = 1.0
	SettingsManager.values["reduced_motion"] = false
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


func _until(cond: Callable) -> bool:
	for i in WAIT_FRAMES:
		if cond.call():
			return true
		await runner.get_tree().process_frame
	return bool(cond.call())


func _candidate(sim: SimulationRoot, role: StringName) -> StringName:
	for st: StaffDefinition in DataRegistry.staff_list():
		if st.role_id == role and sim.staff.hire_block(st.id) == &"":
			return st.id
	return &""


func _welcome() -> void:
	var game: GameRoot = await _boot("Welcome Bakery")
	var sim: SimulationRoot = game.sim
	var moments: WorldMoments = game.world.moments
	var sid: StringName = _candidate(sim, &"cashier")
	# Lewat lembar Staff: tombol Hire di halaman detail.
	var st: StaffScreen = game.modals.open(&"staff", {}) as StaffScreen
	await _frames(1)
	st.push_page(DataRegistry.staff(sid).display_name, st._detail.bind(sid))
	await _frames(1)
	var hire: Button = st.content().find_child("Hire", true, false) as Button
	if not check(hire != null and not hire.disabled, "a cashier can be hired"):
		await _finish(game)
		return
	hire.pressed.emit()
	await _frames(1)
	check(sim.staff.is_employed(sid), "the cashier is hired")
	check(not game.modals.is_open(&"staff"), "the Staff sheet closes so the welcome shows")
	eq(moments.welcomes.size(), 1, "a welcome starts")
	check(game.world.hidden_actors.has(sid), "the real cashier is hidden while the look-alike walks in")
	await _frames(2)
	var w: Dictionary = moments.welcomes[0] if not moments.welcomes.is_empty() else {}
	var puppet: ActorView = w.get("puppet")
	check(puppet != null and is_instance_valid(puppet), "a look-alike appears")
	var a: SimActor = w.get("actor")
	check(a != null and a.pos.y < 0.0, "outside the shop, on the pavement")
	check(not PauseManager.is_paused(), "the shop keeps running")
	Engine.time_scale = SPEED
	# Lambda menyalin variabel lokal: catatan lewat Dictionary (referensi).
	var seen: Dictionary = {"greeted": false, "text": ""}
	check(await _until(func() -> bool:
		if not moments.welcomes.is_empty() and String(moments.welcomes[0]["state"]) == "greet":
			seen["greeted"] = true
			var b: Variant = moments.welcomes[0].get("bubble")
			if b != null and is_instance_valid(b):
				seen["text"] = (b as ThoughtBubble).text()
		return moments.welcomes.is_empty()), "the welcome finishes")
	check(bool(seen["greeted"]), "the look-alike stops at the door to greet")
	check(str(seen["text"]).contains(DataRegistry.staff(sid).display_name), "with a greeting that says their name (%s)" % seen["text"])
	check(not game.world.hidden_actors.has(sid), "the real cashier shows again")
	check(puppet == null or not is_instance_valid(puppet) or puppet.is_queued_for_deletion(), "and the look-alike is gone")
	var rv: ActorView = game.world.views.get(sim.staff.actors[sid].id)
	await _frames(1)
	check(rv != null and rv.visible, "the cashier is visible at work")
	Engine.time_scale = 1.0
	# Reduced Motion: tanpa boneka, hanya sapaan pada staf aslinya.
	SettingsManager.values["reduced_motion"] = true
	var sid2: StringName = _candidate(sim, &"baker")
	eq(sim.staff.hire(sid2), &"", "a baker is hired")
	check(not game.world.hidden_actors.has(sid2), "Reduced Motion never hides the new hire")
	await _frames(3)
	var w2: Dictionary = moments.welcomes[0] if not moments.welcomes.is_empty() else {}
	check(not w2.is_empty() and w2.get("puppet") == null, "and walks no look-alike in")
	check(not w2.is_empty() and w2.get("bubble") != null, "but still greets")
	Engine.time_scale = SPEED
	check(await _until(func() -> bool: return moments.welcomes.is_empty()), "the greeting ends")
	await _finish(game)


func _recipe_reveal() -> void:
	var game: GameRoot = await _boot("Reveal Bakery")
	var sim: SimulationRoot = game.sim
	var menu: MenuScreen = game.modals.open(&"menu", {}) as MenuScreen
	await _frames(3)
	var unlock: Button = menu.unlock_button()
	if not check(unlock != null, "the Menu offers a recipe to unlock"):
		await _finish(game)
		return
	var before: int = sim.upgrades.recipe_levels.size()
	unlock.pressed.emit()
	await _frames(2)
	eq(sim.upgrades.recipe_levels.size(), before + 1, "the recipe unlocks")
	var rv: RecipeReveal = game.modals.screen(&"recipe_reveal") as RecipeReveal
	check(rv != null, "a spotlight shows the new recipe")
	check(game.modals.is_open(&"menu"), "over the Menu sheet, which stays open")
	check(not PauseManager.is_paused(), "and the shop keeps running")
	if rv != null:
		var art: BreadArt = rv.find_child("Bread", true, false) as BreadArt
		var r: RecipeDefinition = DataRegistry.recipe(rv.recipe_id)
		check(art != null and r != null and art.profile == String(r.visual_profile_id), "with the recipe's bread art")
		var name_l: Label = rv.find_child("Name", true, false) as Label
		eq(name_l.text if name_l != null else "", Tx.recipe_name(rv.recipe_id), "its name")
		var price_l: Label = rv.find_child("Price", true, false) as Label
		eq(price_l.text if price_l != null else "", Tx.t("ui_menu_price", {"price": Tx.kr(sim.recipe_price(rv.recipe_id))}), "and its price")
	# Tertutup sendiri sesudah sebentar.
	Engine.time_scale = SPEED
	check(await _until(func() -> bool: return not game.modals.is_open(&"recipe_reveal")), "it closes by itself")
	Engine.time_scale = 1.0
	check(game.modals.is_open(&"menu"), "leaving the Menu sheet open")
	# Ketukan menutupnya lebih awal.
	sim.debug_add_kr(1.0e12)
	menu = game.modals.screen(&"menu") as MenuScreen
	menu.refresh()
	await _frames(2)
	var unlock2: Button = menu.unlock_button()
	if unlock2 != null:
		unlock2.pressed.emit()
		await _frames(2)
		var rv2: RecipeReveal = game.modals.screen(&"recipe_reveal") as RecipeReveal
		check(rv2 != null, "the next unlock shows its own spotlight")
		await _frames(30)
		if rv2 != null:
			var tap := InputEventMouseButton.new()
			tap.button_index = MOUSE_BUTTON_LEFT
			tap.pressed = false
			rv2._gui_input(tap)
			check(rv2.is_leaving(), "a tap sends it off early")
		check(await _until(func() -> bool: return not game.modals.is_open(&"recipe_reveal")), "and it closes")
	await _finish(game)


func _moments_rebuild() -> void:
	var game: GameRoot = await _boot("Rebuild Bakery", 2)
	var sim: SimulationRoot = game.sim
	var world: WorldView = game.world
	var moments: WorldMoments = world.moments
	sim.debug_add_kr(1.0e9)
	var iid: int = -1
	for cat: StringName in [&"display", &"mixer", &"oven"]:
		iid = sim.upgrades.open_station(cat)
		if iid >= 0:
			break
	check(iid >= 0, "a station opens")
	var hired: StringName = &""
	for def: StaffDefinition in DataRegistry.staff_list():
		if sim.staff.hire(def.id) == &"":
			hired = def.id
			break
	check(hired != &"", "someone is hired")
	await _frames(3)
	check(not moments.deliveries.is_empty(), "the delivery is playing")
	# Dunia dibangun ulang di tengah momen.
	world.rebuild_all()
	await _frames(30)
	eq(moments.deliveries.size(), 0, "the delivery ends after the rebuild")
	if iid >= 0:
		var n: Variant = world.furniture.get(iid)
		check(n != null and is_instance_valid(n) and (n as Node3D).visible, "the new station shows")
	Engine.time_scale = SPEED
	check(await _until(func() -> bool: return moments.welcomes.is_empty()), "the welcome ends too")
	Engine.time_scale = 1.0
	check(not world.hidden_actors.has(hired), "the new hire is visible again")
	await _finish(game)


func _delivery() -> void:
	var game: GameRoot = await _boot("Delivery Bakery", 2)
	var sim: SimulationRoot = game.sim
	var world: WorldView = game.world
	var moments: WorldMoments = world.moments
	var store: StringName = sim.world.store_floor()
	# Rak baru lewat lembar Shop.
	var sheet: ShopScreen = game.modals.open(&"shop", {}) as ShopScreen
	await _frames(2)
	var row: Node = sheet.content().find_child("Open_display", true, false)
	var open_b: Button = row.find_child("Open", true, false) as Button if row != null else null
	if not check(open_b != null and not open_b.disabled, "a second shelf can be opened"):
		await _finish(game)
		return
	var before: int = sim.equipment.placed_count(&"display")
	open_b.pressed.emit()
	await _frames(1)
	eq(sim.equipment.placed_count(&"display"), before + 1, "the shelf opens")
	check(not game.modals.is_open(&"shop"), "the Shop sheet closes so the delivery shows")
	eq(moments.deliveries.size(), 1, "a delivery starts")
	var d: Dictionary = moments.deliveries[0] if not moments.deliveries.is_empty() else {}
	var iid: int = int(d.get("iid", -1))
	var node: Node3D = world.furniture.get(iid)
	check(node != null and not node.visible, "the new shelf hides while its box drops")
	var box: Node3D = d.get("box")
	check(box != null and box.position.y > 1.0, "the box starts high above its spot")
	# Perabot dibangun ulang di tengah jalan: tetap tersembunyi.
	world.rebuild_furniture()
	check(not (world.furniture[iid] as Node3D).visible, "a furniture rebuild keeps it hidden")
	Engine.time_scale = SPEED
	var seen: Dictionary = {"landed": false, "opened": false}
	check(await _until(func() -> bool:
		if not moments.deliveries.is_empty():
			var dd: Dictionary = moments.deliveries[0]
			if bool(dd.get("landed", false)):
				seen["landed"] = true
			var bx: Variant = dd.get("box")
			if bx != null and is_instance_valid(bx):
				var f: Node3D = (bx as Node3D).get_node_or_null("Flap0") as Node3D
				if f != null and absf(f.rotation.x) > 1.0:
					seen["opened"] = true
		return moments.deliveries.is_empty()), "the delivery finishes")
	check(bool(seen["landed"]), "the box lands")
	check(bool(seen["opened"]), "and opens its flaps")
	node = world.furniture.get(iid)
	check(node != null and node.visible, "the new shelf stands in its place")
	await _frames(20)
	check(not world.hidden_furniture.has(iid), "nothing stays hidden")
	check(box == null or not is_instance_valid(box) or box.is_queued_for_deletion(), "and the box is gone")
	Engine.time_scale = 1.0
	# Mixer di dapur atas: kamera melihat ke sana, lalu kembali ke lantai toko.
	eq(world.camera_rig.active_floor, store, "the camera shows the shop floor")
	var mixer: int = sim.upgrades.open_station(&"mixer")
	check(mixer >= 0, "a second mixer opens")
	var kitchen: StringName = sim.equipment.get_inst(mixer).floor_id if mixer >= 0 else &""
	check(kitchen != store, "upstairs in the kitchen")
	eq(world.view_floor_override, kitchen, "the camera goes up to show it")
	Engine.time_scale = SPEED
	check(await _until(func() -> bool: return moments.deliveries.is_empty()), "the mixer delivery finishes")
	eq(world.view_floor_override, &"", "and the camera comes back down")
	Engine.time_scale = 1.0
	# Reduced Motion: tanpa kardus.
	SettingsManager.values["reduced_motion"] = true
	var oven: int = sim.upgrades.open_station(&"oven")
	check(oven >= 0, "a second oven opens")
	eq(moments.deliveries.size(), 0, "Reduced Motion drops no box")
	check(not world.hidden_furniture.has(oven), "and hides nothing")
	await _finish(game)
