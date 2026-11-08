extends TestSuite
## Cutscene pindah lokasi (GDD idle §20 no. 70): Move di lembar Shop memutar
## truk pindahan; kru mengangkut perabot, naik, truk pergi, lokasi pindah tepat
## sekali di balik layar krem, truk tiba di toko baru, Pak Lurah memberi selamat,
## lalu permainan berlanjut. Waktu nyata dipercepat dengan Engine.time_scale.

const SPEED: float = 6.0
## Batas tunggu (frame) satu kondisi.
const WAIT_FRAMES: int = 20000


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_MOVE_CUTSCENE", "name": "idle 20 no. 70 Move plays the moving-truck cutscene: the shop pauses and the HUD hides, owner and staff carry every piece of furniture into the truck and ride it away, the location changes exactly once behind the cream cover, the truck arrives at the new shop where the furniture pops in and Pak Lurah's card greets the lined-up crew, and Let's bake! lets the crew walk in and resumes play with the HUD and camera restored", "fn": _full},
		{"id": "ACC_IDLE_MOVE_SKIP", "name": "idle 20 no. 70 Skip (and Back) during the moving cutscene jumps straight to Pak Lurah's card at the new shop, still charging the move exactly once, and a second Skip continues into the shop", "fn": _skip},
		{"id": "ACC_IDLE_MOVE_TRAFFIC", "name": "idle 20 no. 70 the moving truck has its own driver in the right seat and the owner rides in the passenger seat; street traffic keeps moving during the cutscene without walkers, the truck's lane spawns nothing new, vehicles behind it queue, it follows a slow cart ahead, and no vehicle body ever overlaps the truck", "fn": _traffic},
		{"id": "ACC_IDLE_MOVE_CLOSED_EARLY", "name": "idle 20 no. 70 a moving cutscene closed before the truck leaves (session end) moves nothing, charges nothing, and restores the furniture, HUD, camera and pause state", "fn": _closed_early},
	]


func _boot(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_moving"
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
	var sim: SimulationRoot = game.sim
	sim.debug_add_kr(1.0e6)
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id, true)
				break
	game.playing = true
	await _frames(3)
	return game


func _finish(game: GameRoot) -> void:
	Engine.time_scale = 1.0
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


## Tunggu sampai `cond` true (atau batas frame); true bila tercapai.
func _until(cond: Callable) -> bool:
	for i in WAIT_FRAMES:
		if cond.call():
			return true
		await runner.get_tree().process_frame
	return bool(cond.call())


func _cutscene(game: GameRoot) -> MovingCutscene:
	return game.modals.screen(&"moving_cutscene") as MovingCutscene


func _full() -> void:
	var game: GameRoot = await _boot("Moving Bakery")
	var sim: SimulationRoot = game.sim
	var rig: CameraRig = game.world.camera_rig
	var width0: float = rig.ortho_size
	var price: float = sim.location_price(2)
	var kr0: float = sim.economy.balance
	var pieces: int = sim.equipment.placed_list().size()
	eq(game.start_move(), "", "Move starts the cutscene")
	var scr: MovingCutscene = _cutscene(game)
	check(scr != null, "the moving cutscene opens")
	if scr == null:
		await _finish(game)
		return
	Engine.time_scale = SPEED
	await _frames(2)
	var d: MovingDay = scr.director
	check(d != null and is_instance_valid(d), "with its director in the world")
	check(PauseManager.is_paused(), "the shop pauses")
	check(not game.hud.visible, "the HUD hides")
	check(game.world.cutscene, "the world hides the simulated actors")
	eq(d.crew.size(), 1 + sim.staff.actors.size(), "the owner and every staff member are in the crew")
	eq(sim.world.location.tier, 1, "nothing has moved yet")
	near(sim.economy.balance, kr0, 0.01, "and nothing is charged yet")
	var t0: float = sim.time.sim_seconds
	check(await _until(func() -> bool: return d.hidden_furniture() > 0), "the crew picks up furniture")
	check(await _until(func() -> bool: return d.phase >= MovingDay.Phase.DEPART), "everyone boards and the truck leaves")
	eq(d.cargo_count(), pieces, "every piece of furniture is in the truck (%d)" % pieces)
	var riding: int = 0
	for c: Dictionary in d.crew:
		if String(c["mode"]) == "ride":
			riding += 1
	eq(riding, d.crew.size(), "the whole crew rides along")
	check(await _until(func() -> bool: return scr.continue_button() != null), "Pak Lurah's card appears at the new shop")
	eq(sim.world.location.tier, 2, "the shop has moved to the next location")
	near(sim.economy.balance, kr0 - price, 0.01, "charged exactly once")
	eq(int(sim.statistics.get_stat("location_upgrades_count")), 1, "one location upgrade recorded")
	eq(sim.time.sim_seconds, t0, "the shop clock stood still during the cutscene")
	eq(d.phase, MovingDay.Phase.GREET, "the crew lines up")
	eq(d.hidden_furniture(), 0, "every piece of furniture is back in place")
	check(d.lurah != null and d.lurah.visible, "Pak Lurah stands by the new shop")
	var all_visible: bool = true
	for n: Variant in game.world.furniture.values():
		all_visible = all_visible and (n as Node3D).visible
	check(all_visible, "the new shop's furniture is all shown")
	scr.continue_button().pressed.emit()
	check(await _until(func() -> bool: return not game.modals.is_open(&"moving_cutscene")), "Let's bake! lets the crew walk in and ends the cutscene")
	check(game.hud.visible, "the HUD is back")
	check(not game.world.cutscene, "the simulated actors are back")
	check(not PauseManager.is_paused(), "the shop runs again")
	check(await _until(func() -> bool: return rig.cutscene_focus == Vector3.INF), "the camera returns to the shop")
	near(rig.ortho_size, width0, 0.05, "at its old width")
	check(await _until(func() -> bool: return game.world.find_child("MovingDay", false, false) == null), "the truck drives off and the director is freed")
	near(sim.economy.balance, kr0 - price, 1000.0, "still charged only once after play resumes")
	await _finish(game)


func _skip() -> void:
	var game: GameRoot = await _boot("Skip Bakery")
	var sim: SimulationRoot = game.sim
	var price: float = sim.location_price(2)
	var kr0: float = sim.economy.balance
	eq(game.start_move(), "", "Move starts the cutscene")
	var scr: MovingCutscene = _cutscene(game)
	if not check(scr != null, "the moving cutscene opens"):
		await _finish(game)
		return
	Engine.time_scale = SPEED
	var d: MovingDay = scr.director
	await _until(func() -> bool: return d.hidden_furniture() > 0)
	check(scr.skip_button() != null and scr.skip_button().visible, "a Skip button shows")
	scr.skip_button().pressed.emit()
	scr.skip_button().pressed.emit()
	check(await _until(func() -> bool: return scr.continue_button() != null), "Skip jumps to Pak Lurah's card")
	eq(sim.world.location.tier, 2, "after moving the shop")
	near(sim.economy.balance, kr0 - price, 0.01, "charged exactly once, even with two taps")
	eq(d.phase, MovingDay.Phase.GREET, "the crew is lined up")
	eq(d.cargo_count(), 0, "no leftover cargo")
	eq(d.hidden_furniture(), 0, "and no hidden furniture")
	var card: Control = scr.find_child("LurahCard", true, false) as Control
	var vis := Rect2(Vector2.ZERO, scr.get_viewport_rect().size)
	check(card != null and vis.grow(1.0).encloses(card.get_global_rect()), "the card fits the frame")
	check(not scr.skip_button().visible, "Skip hides while the card shows")
	# Back = tombol kartu.
	game._on_back()
	check(await _until(func() -> bool: return not game.modals.is_open(&"moving_cutscene")), "Back continues into the shop")
	check(game.hud.visible and not PauseManager.is_paused(), "and play resumes")
	await _finish(game)


## Badan kendaraan StreetLife yang bertumpuk dengan badan truk (0 = aman).
static func _overlaps(street: StreetLife) -> int:
	if street == null or street.guest.is_empty():
		return 0
	var g: Dictionary = street.guest
	var n: int = 0
	for lane: Dictionary in street.lanes:
		for car: Dictionary in lane["cars"]:
			var cz: float = float(car["z"]) + float(car.get("offset", 0.0))
			var dx: float = absf(float(car["x"]) - float(g["x"])) - (float(g["len"]) + float(car["len"])) * 0.5
			var dz: float = absf(cz - float(g["z"])) - (float(g["width"]) + float(TrafficFactory.info(car["kind"])["width"])) * 0.5
			if dx < -0.02 and dz < -0.02:
				n += 1
	return n


func _traffic() -> void:
	var game: GameRoot = await _boot("Traffic Bakery")
	var sim: SimulationRoot = game.sim
	var street: StreetLife = game.world.street_life
	check(street != null and not street.lanes.is_empty(), "the street has traffic lanes")
	eq(game.start_move(), "", "Move starts the cutscene")
	var scr: MovingCutscene = _cutscene(game)
	if not check(scr != null and street != null, "the moving cutscene opens"):
		await _finish(game)
		return
	var d: MovingDay = scr.director
	await _frames(1)
	check(d.driver != null and d.driver.visible, "the truck arrives with its own driver")
	check(street.walkers.is_empty(), "no walkers on the pavement during the cutscene")
	# Lajur dekat (yang dipakai truk) dan kendaraan sisipan: gerobak lambat di
	# depan truk, mobil dan motor menyusul dari belakang.
	var near: int = -1
	var near_dz: float = INF
	for i in street.lanes.size():
		var dz: float = absf(float(street.lanes[i]["def"]["z"]) - float(street.guest["z"]))
		if street.lane_blocked(street.lanes[i]) and dz < near_dz:
			near = i
			near_dz = dz
	check(near >= 0, "the truck's lane is closed to new vehicles")
	var stop: float = float(d._site["stop_x"])
	street.debug_add_car(near, &"gerobak", stop + 5.0, 0.9)
	var car: Dictionary = street.debug_add_car(near, &"car", stop + 22.0, 6.0)
	street.debug_add_car(near, &"motor", stop + 28.0, 5.0)
	var near_lane: Dictionary = street.lanes[near]
	var near_max: int = (near_lane["cars"] as Array).size()
	var near_grew: bool = false
	var spawned0: int = 0
	for lane: Dictionary in street.lanes:
		spawned0 += (lane["cars"] as Array).size()
	Engine.time_scale = SPEED
	var worst: int = 0
	var queued: bool = false
	var other_moving: bool = false
	var cab_ok: bool = true
	var driver_ok: bool = true
	var was_riding: bool = false
	var t0: float = sim.time.sim_seconds
	for f in WAIT_FRAMES:
		await runner.get_tree().process_frame
		if not is_instance_valid(scr) or not scr.is_inside_tree():
			break
		worst = maxi(worst, _overlaps(street))
		if d.phase <= MovingDay.Phase.DEPART and (near_lane["cars"] as Array).size() > near_max:
			near_grew = true
		if d._parked and d.phase == MovingDay.Phase.PACK and float(car["speed"]) < 0.05 and float(car["x"]) > stop:
			queued = true
		for i2 in street.lanes.size():
			if i2 != near:
				for oc: Dictionary in street.lanes[i2]["cars"]:
					other_moving = other_moving or float(oc["speed"]) > 0.5
		if d.truck != null and d.driver != null:
			var local: Vector3 = d.truck.global_transform.affine_inverse() * d.driver.global_position
			driver_ok = driver_ok and local.x > 0.1
		var owner: Dictionary = d.crew[0]
		if String(owner["mode"]) == "ride" and d.truck != null:
			was_riding = true
			var lo: Vector3 = d.truck.global_transform.affine_inverse() * (owner["view"] as ActorView).global_position
			cab_ok = cab_ok and lo.x < -0.1 and lo.z < TrafficFactory.TRUCK_BED_Z.x
		if scr.continue_button() != null:
			scr.continue_button().pressed.emit()
	eq(worst, 0, "no vehicle ever overlaps the truck")
	check(not near_grew, "no new vehicle appears in the truck's lane")
	check(queued, "the car behind the parked truck stops and waits")
	check(other_moving, "the other lane keeps moving during the cutscene")
	check(driver_ok, "the driver stays in the right-hand seat")
	check(was_riding and cab_ok, "the owner rides in the passenger seat (cab, left side)")
	eq(sim.time.sim_seconds, t0, "the shop still stands still during the cutscene")
	check(not game.modals.is_open(&"moving_cutscene"), "the cutscene ends")
	check(spawned0 > 0, "vehicles were on the road")
	# Truk pergi sendiri bersama sopirnya; setelah itu lajurnya dibuka lagi.
	check(await _until(func() -> bool: return game.world.find_child("MovingDay", false, false) == null), "the truck drives off with its driver")
	check(street.guest.is_empty(), "the street no longer knows a truck")
	await _finish(game)


func _closed_early() -> void:
	var game: GameRoot = await _boot("Early Bakery")
	var sim: SimulationRoot = game.sim
	var rig: CameraRig = game.world.camera_rig
	var width0: float = rig.ortho_size
	var kr0: float = sim.economy.balance
	eq(game.start_move(), "", "Move starts the cutscene")
	var scr: MovingCutscene = _cutscene(game)
	if not check(scr != null, "the moving cutscene opens"):
		await _finish(game)
		return
	Engine.time_scale = SPEED
	var d: MovingDay = scr.director
	check(await _until(func() -> bool: return d.hidden_furniture() > 0), "furniture is being carried")
	Engine.time_scale = 1.0
	game.modals.close_all()
	await _frames(2)
	eq(sim.world.location.tier, 1, "closing early moves nothing")
	near(sim.economy.balance, kr0, 0.01, "and charges nothing")
	var all_visible: bool = true
	for n: Variant in game.world.furniture.values():
		all_visible = all_visible and (n as Node3D).visible
	check(all_visible, "every piece of furniture is back")
	check(game.hud.visible and not game.world.cutscene, "the HUD and actors are back")
	check(not PauseManager.is_paused(), "the shop is not left paused")
	check(rig.cutscene_focus == Vector3.INF, "the camera is released")
	near(rig.ortho_size, width0, 0.01, "at its old width")
	check(game.world.find_child("MovingDay", false, false) == null or game.world.find_child("MovingDay", false, false).is_queued_for_deletion(),
		"the director is freed")
	await _finish(game)
