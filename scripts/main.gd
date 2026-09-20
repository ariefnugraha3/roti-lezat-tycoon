class_name Main
extends Node
## Titik masuk permainan.
##
## Tugas Main hanya tiga:
##   1. Merakit dunia 3D dan seluruh sistem simulasi.
##   2. Menjalankan loop tick dengan URUTAN TETAP (ARCHITECTURE.md 7.0) supaya
##      simulasi deterministik dan bisa di-step headless.
##   3. Mendaftarkan layar UI ke ScreenRouter.
##
## Main SENGAJA tidak mendefinisikan run_day_start()/run_day_end(): DayCycle sudah
## melakukan fan-out awal/akhir hari sendiri. Kalau Main ikut mendefinisikannya,
## fan-out akan berjalan dua kali dan Daily Summary muncul dobel.

## Urutan pemanggilan sim_tick per frame (ARCHITECTURE.md 7.0). Jangan diubah:
## cuaca dan kampanye menentukan pengali sebelum pelanggan di-spawn; ekonomi
## menagih setelah semuanya bergerak; bailout menilai saldo paling akhir.
## "player" berdetak TEPAT SESUDAH "prod": ia membaca kemajuan job yang baru saja
## dimajukan pada tick yang sama, jadi tanda seru berpindah di frame yang sama
## dengan selesainya adukan — bukan satu frame setelahnya.
const TICK_ORDER: Array[String] = [
	"weather", "mkt", "day", "prod", "player", "staff", "cust", "deliv",
	"econ", "rep", "bailout",
]

## Sistem yang berhenti berdetak saat toko sudah tutup (ARCHITECTURE.md 7.0).
const PAUSED_WHEN_CLOSED: Array[String] = ["prod", "player", "cust", "deliv"]

## Dibaca sistem lain lewat `_main.get("systems")`. Kunci sesuai ARCHITECTURE.md 7.
var systems: Dictionary = {}

var world: Node3D = null

var _booted: bool = false
var _splash: Control = null


func _ready() -> void:
	# Splash wajib untuk kebijakan autoplay browser (GDD 12.1): audio baru boleh
	# hidup setelah gestur pengguna pertama.
	_build_splash()


# ===========================================================================
# BOOTSTRAP
# ===========================================================================

func _build_splash() -> void:
	var layer := CanvasLayer.new()
	layer.name = "SplashLayer"
	layer.layer = 100
	add_child(layer)

	_splash = Control.new()
	_splash.name = "Splash"
	_splash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(_splash)

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_splash.add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 18)
	_splash.add_child(box)

	var judul: Label = ProceduralUIFactory.title("Roti Lezat Tycoon", 44)
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(judul)

	var roti: IconCanvas = ProceduralUIFactory.icon("bread", 96, Palette.GOLDEN_CRUST)
	var tengah := CenterContainer.new()
	tengah.add_child(roti)
	box.add_child(tengah)

	var ajakan: Label = ProceduralUIFactory.label("Tap / Klik untuk Mulai", 22, Palette.TEXT_MUTED)
	ajakan.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(ajakan)

	# Denyut lembut pada ajakan supaya terasa hidup (GDD 7 micro-interactions).
	var tw := create_tween().set_loops()
	tw.tween_property(ajakan, "modulate:a", 0.45, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(ajakan, "modulate:a", 1.0, 0.9).set_trans(Tween.TRANS_SINE)

	_splash.gui_input.connect(_on_splash_input)


func _on_splash_input(event: InputEvent) -> void:
	var tapped: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		tapped = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tapped = true
	if not tapped:
		return
	_splash.gui_input.disconnect(_on_splash_input)
	AudioBus.unlock_audio()
	boot()


## Merakit game. Dipanggil sekali setelah splash disentuh.
func boot() -> void:
	if _booted:
		return
	_booted = true

	if _splash != null and is_instance_valid(_splash):
		var fade := create_tween()
		fade.tween_property(_splash, "modulate:a", 0.0, 0.35)
		fade.tween_callback(_splash.get_parent().queue_free)

	_build_world()
	_build_systems()
	_register_screens()

	AudioBus.start_music("menu")
	ScreenRouter.go("main_menu")


func _build_world() -> void:
	world = ShopWorld.new()
	world.name = "ShopWorld"
	add_child(world)
	if world.has_method("setup"):
		world.call("setup", self)


func _build_systems() -> void:
	systems = {
		"day": DayCycle.new(),
		"prod": ProductionSystem.new(),
		"player": PlayerTaskSystem.new(),
		"cust": CustomerSim.new(),
		"deliv": DeliverySim.new(),
		"staff": StaffSim.new(),
		"econ": EconomySystem.new(),
		"rep": ReputationSystem.new(),
		"weather": WeatherSim.new(),
		"mkt": MarketingSim.new(),
		"bailout": BailoutSystem.new(),
	}
	# Ditambahkan mengikuti TICK_ORDER supaya urutan node di scene tree
	# mencerminkan urutan simulasi -- memudahkan saat debug di remote inspector.
	for key in TICK_ORDER:
		var node: Node = systems[key]
		node.name = key.capitalize() + "System"
		add_child(node)
	for key in TICK_ORDER:
		var node: Node = systems[key]
		if node.has_method("setup"):
			node.call("setup", self)
	_connect_player_tasks()


## Menyambungkan alur tugas pemain ke dunia 3D dan ke layar.
##
## Disambung di Main, bukan di dalam PlayerTaskSystem, karena sistem simulasi
## tidak boleh memanggil ScreenRouter sendiri — ia hanya melaporkan bahwa
## karakter sudah sampai, dan Main yang memutuskan layar apa yang terbuka.
func _connect_player_tasks() -> void:
	var pt: PlayerTaskSystem = systems.get("player") as PlayerTaskSystem
	if pt == null:
		return
	pt.storage_opened.connect(_on_storage_opened)
	pt.rack_requested.connect(_on_rack_requested)
	pt.storage_door.connect(_on_storage_door)


func _on_storage_opened() -> void:
	ScreenRouter.go("recipe_book")


func _on_rack_requested(order_id: int, rack_index: int) -> void:
	ScreenRouter.go("rack", {"order_id": order_id, "rack": rack_index})


func _on_storage_door(open: bool) -> void:
	var w: ShopWorld = world as ShopWorld
	if w != null and is_instance_valid(w):
		w.set_storage_open(open)


func _register_screens() -> void:
	ScreenRouter.register("main_menu", func() -> Control: return MainMenu.new())
	ScreenRouter.register("character_select",
		func() -> Control: return CharacterSelectScreen.new())
	ScreenRouter.register("rack", func() -> Control: return RackScreen.new())
	ScreenRouter.register("hud", func() -> Control: return HUD.new())
	ScreenRouter.register("market", func() -> Control: return MarketScreen.new())
	ScreenRouter.register("recipe_book", func() -> Control: return RecipeBookScreen.new())
	ScreenRouter.register("staff", func() -> Control: return StaffScreen.new())
	ScreenRouter.register("marketing", func() -> Control: return MarketingScreen.new())
	ScreenRouter.register("daily_summary", func() -> Control: return DailySummaryScreen.new())
	ScreenRouter.register("decoration", func() -> Control: return DecorationScreen.new())
	ScreenRouter.register("bailout", func() -> Control: return BailoutCutscene.new())


# ===========================================================================
# LOOP SIMULASI
# ===========================================================================

func _process(delta: float) -> void:
	if not _booted or systems.is_empty():
		return
	step(delta)


## Satu langkah simulasi. Dipisah dari _process agar tools/sim_test.tscn bisa
## memanggilnya berkali-kali dengan delta tetap tanpa menunggu frame nyata.
func step(delta: float) -> void:
	var day: DayCycle = systems.get("day") as DayCycle
	if day == null:
		return

	# DayCycle menerima delta MENTAH (ia yang mengalikan time_scale sendiri).
	# Sistem lain menerima delta yang sudah diskalakan -- 0.0 saat pause.
	var eff: float = day.effective_delta(delta)
	var hour: float = day.hour
	var closed: bool = day.phase == GameConfig.PHASE_CLOSE

	for key in TICK_ORDER:
		var node: Node = systems.get(key)
		if node == null or not is_instance_valid(node):
			continue
		if closed and PAUSED_WHEN_CLOSED.has(key):
			continue
		if not node.has_method("sim_tick"):
			continue
		if key == "day":
			node.call("sim_tick", delta, hour)
			# Jam bisa berubah di tick ini; segarkan agar sistem berikutnya
			# melihat waktu yang sama dengan yang baru saja maju.
			hour = day.hour
			closed = day.phase == GameConfig.PHASE_CLOSE
		else:
			node.call("sim_tick", eff, hour)


# ===========================================================================
# ALUR PERMAINAN
# ===========================================================================

## Memulai permainan baru dengan karakter pilihan pemain.
##
## Karakter ditetapkan SESUDAH reset_new_game() — reset sengaja tidak menyentuh
## `player`, jadi urutan ini yang menjadikan pilihan di layar sebelumnya berlaku.
func new_game(gender: String = "") -> void:
	GameState.reset_new_game()
	if gender != "":
		GameState.set_player_gender(gender)
	_reset_systems()
	var day: DayCycle = systems.get("day") as DayCycle
	if day != null:
		day.start_day()
	AudioBus.start_music("cozy")
	ScreenRouter.go("hud")
	EventBus.toast.emit("Selamat memulai, Nak!", "bread")


func continue_game() -> bool:
	if not SaveManager.load_game():
		return false
	_reset_systems()
	var day: DayCycle = systems.get("day") as DayCycle
	if day != null:
		day.start_day()
	AudioBus.start_music("cozy")
	ScreenRouter.go("hud")
	return true


func _reset_systems() -> void:
	for key in TICK_ORDER:
		var node: Node = systems.get(key)
		if node != null and is_instance_valid(node) and node.has_method("reset"):
			node.call("reset")
	if world != null and is_instance_valid(world) and world.has_method("rebuild"):
		world.call("rebuild")
	# Karakter pemain dirakit ulang: pilihan pria/wanita baru saja berubah, atau
	# berkas simpanan membawa pilihan yang berbeda dari yang sedang berdiri.
	if world != null and is_instance_valid(world) and world.has_method("rebuild_player"):
		world.call("rebuild_player")


func _notification(what: int) -> void:
	# GDD 12.1: auto-pause saat aplikasi Android masuk background, dan simpan
	# progres supaya tidak hilang bila sistem menutup aplikasi.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		var day: DayCycle = systems.get("day") as DayCycle
		if day != null and is_instance_valid(day):
			day.set_paused(true)
		if _booted:
			SaveManager.save_game()
