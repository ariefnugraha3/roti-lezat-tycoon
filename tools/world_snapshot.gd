extends Node
## QA visual adegan dunia sungguhan (GDD 20.12, 21.4, 31.6, 31.7, 130.5): simulasi
## dijalankan SimBot, lalu layar dipotret dengan kamera gameplay. Menangkap
## kantong di meja kasir saat membungkus, pengunjung lihat-lihat di depan rak,
## gelembung pikiran pemain di toko sepi, dan pemain yang terkantuk-kantuk.
## Jalankan dengan jendela (bukan --headless, karena perlu renderer):
##   godot --path . --resolution 1920x1080 res://tools/world_snapshot.tscn
## Folder keluaran: env LINEUP_OUT, atau user://lineup bila tidak diisi.

var _out: String = ""
var sim: SimulationRoot = null
var world: WorldView = null


func _ready() -> void:
	_out = OS.get_environment("LINEUP_OUT")
	if _out == "":
		_out = ProjectSettings.globalize_path("user://lineup")
	DirAccess.make_dir_recursive_absolute(_out)
	sim = SimulationRoot.new()
	add_child(sim)
	sim.start_new_game(&"profile_snapshot", "Snapshot Bakery", "male", 4242)
	world = WorldView.new()
	add_child(world)
	world.setup(sim)
	PauseManager.clear_all()
	await _run()
	world.queue_free()
	sim.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	ProceduralCaches.clear_all()
	get_tree().quit(0)


func _run() -> void:
	var bot := SimBot.new(sim)
	var lane: QueueLane = sim.queue.main_lane()
	# 1. Urutan membungkus di meja kasir (GDD 21.4, manual, pemain berjaga):
	# buka kantong, roti melompat masuk, pita diikat, kantong disodorkan, lalu
	# menunggu bayaran. Titik fotonya dihitung dari jumlah roti yang dibungkus.
	var ok: bool = await _advance(bot, func() -> bool: return sim.cashier.packing_progress(lane.id) >= 0.0)
	print("packing reached: ", ok)
	await _frames(2)
	var rig: CameraRig = world.camera_rig
	var normal_size: float = rig.ortho_size
	rig.ortho_size = 1.9
	rig.camera.size = 1.9
	var bag_rig: PackBagRig = world._pack_bags.get(lane.id) as PackBagRig
	var n: int = bag_rig.count if bag_rig != null else 1
	var ph: Vector3 = ProceduralAnimationSystem.pack_phases(n)
	var w0: Vector2 = ProceduralAnimationSystem.pack_bread_window(0, n)
	var marks: Array[float] = [0.05, lerpf(w0.x, w0.y, 0.30), lerpf(w0.x, w0.y, 0.62),
		lerpf(ph.y, ph.z, 0.45), ph.z + ProceduralAnimationSystem.PACK_OFFER_SPAN * 0.7, 0.93]
	print("pack breads: ", n, " marks: ", marks)
	var strip: Image = null
	for i in marks.size():
		await _advance(bot, func() -> bool: return sim.cashier.packing_progress(lane.id) >= marks[i])
		await _frames(8)
		await RenderingServer.frame_post_draw
		var img: Image = get_viewport().get_texture().get_image()
		img.save_png(_out.path_join("pack_seq_%d.png" % (i + 1)))
		var crop: Image = img.get_region(Rect2i(img.get_width() / 2 - 420, img.get_height() / 2 - 330, 840, 660))
		if strip == null:
			strip = Image.create(crop.get_width() * marks.size(), crop.get_height(), false, crop.get_format())
		strip.blit_rect(crop, Rect2i(Vector2i.ZERO, crop.get_size()), Vector2i(crop.get_width() * i, 0))
	if strip != null:
		strip.save_png(_out.path_join("pack_sequence.png"))
	# Gambaran toko dan close-up meja kasir saat membungkus berikutnya.
	rig.ortho_size = normal_size
	rig.camera.size = normal_size
	await _advance(bot, func() -> bool: return sim.cashier.packing_progress(lane.id) < 0.0)
	await _advance(bot, func() -> bool: return sim.cashier.packing_progress(lane.id) >= 0.45)
	await _frames(12)
	await _shot("world_packing")
	rig.ortho_size = 2.6
	rig.camera.size = 2.6
	await _frames(12)
	await _shot("world_packing_close")
	rig.ortho_size = normal_size
	rig.camera.size = normal_size
	# Pengunjung lihat-lihat (GDD 20.12): berdiri di depan rak, menoleh, tanpa
	# patience bar, dengan celetukannya, pada gambaran toko dan dari dekat.
	var looking := func() -> bool:
		for c: Customer in sim.customers.sorted():
			if WorldView.shopper_speaking(c) and c.state == Customer.BROWSING and not c.actor.moving:
				return true
		return false
	print("window shopper reached: ", await _advance(bot, looking))
	await _frames(30)
	await _shot("world_window_shopper")
	rig.ortho_size = 4.2
	rig.camera.size = 4.2
	await _frames(20)
	await _shot("world_window_shopper_close")
	rig.ortho_size = normal_size
	rig.camera.size = normal_size
	# 2. Toko sepi: semua pembeli pergi, pemain berjaga tanpa transaksi.
	for c: Customer in sim.customers.sorted():
		sim.world.release_all_for(c.id)
		sim.queue.release(c.id)
	sim.customers.customers.clear()
	sim.cashier.transactions.clear()
	world._quiet_real = 20.5
	await _frames(20)
	await _shot("world_thought")
	# 3. Pemain menganggur lama: terkantuk-kantuk (tanpa gelembung).
	world._quiet_real = 0.0
	sim.time.phase = TimeManager.PREPARATION
	var pv: ActorView = world.views.get(sim.player.actor.id)
	if pv != null:
		pv._idle_real = 27.0
	await _frames(90)
	await _shot("world_doze")
	# 4. Meja Tunggu berisi adonan dan loyang dengan kesegaran berbeda (GDD 5.1.3).
	if pv != null:
		pv._idle_real = 0.0
	var table: EquipmentInstance = sim.equipment.table_instance()
	var recipes: Array[StringName] = [&"recipe_plain_loaf", &"recipe_plain_loaf", &"recipe_sugar_donut", &"recipe_plain_fried_bread", &"recipe_sugar_donut"]
	var ages: Array[float] = [0.0, 1.0, 4.5, 3.0, 9.0]
	for i in recipes.size():
		var j := ProductionJob.new()
		j.job_id = 90000 + i
		j.recipe_id = recipes[i]
		j.quantity_output = DataRegistry.recipe(recipes[i]).batch_yield
		j.carried_units = j.quantity_output
		j.stage = ProductionJob.DOUGH_ON_TABLE if i % 2 == 0 else ProductionJob.TRAY_ON_TABLE
		j.table_seq = i + 1
		j.table_age_hours = ages[i]
		sim.production.jobs[j.job_id] = j
	var acc: Dictionary = sim.world.access_of(table.iid)
	sim.player.actor.place_at(acc["floor"], acc["cell"])
	rig.ortho_size = 2.4
	rig.camera.size = 2.4
	await _frames(40)
	await _shot("world_table")
	# Tanpa penanda "!" agar isi meja terlihat utuh.
	world._marker_timer = 1.0e9
	(world.markers[table.iid] as StationMarker).hide_marker()
	await _frames(6)
	await _shot("world_table_items")
	world._marker_timer = 0.0
	rig.ortho_size = normal_size
	rig.camera.size = normal_size


## Majukan simulasi (bot bermain) sampai `cond` benar, sambil tetap merender.
func _advance(bot: SimBot, cond: Callable) -> bool:
	var ticks: int = 0
	while ticks < 400000 and sim.is_running():
		for i in 40:
			bot.think()
			sim.step(sim.tick_seconds)
			ticks += 1
			if cond.call():
				return true
		await get_tree().process_frame
	return false


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(shot_name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(_out.path_join(shot_name + ".png"))
