extends Node
## QA visual adegan dunia sungguhan (GDD 21.4, 31.6, 31.7, 130.5): simulasi
## dijalankan SimBot, lalu layar dipotret dengan kamera gameplay. Menangkap
## kantong di meja kasir saat membungkus, gelembung pikiran pemain di toko sepi,
## dan pemain yang terkantuk-kantuk.
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
	# 1. Membungkus di meja kasir (manual, pemain berjaga).
	var ok: bool = await _advance(bot, func() -> bool: return sim.cashier.packing_progress(lane.id) >= 0.45)
	print("packing reached: ", ok)
	await _frames(12)
	await _shot("world_packing")
	# Close-up meja kasir: kantong di samping mesin kasir, pose membungkus.
	var rig: CameraRig = world.camera_rig
	var normal_size: float = rig.ortho_size
	rig.ortho_size = 2.6
	rig.camera.size = 2.6
	await _frames(12)
	await _shot("world_packing_close")
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
