extends Node
## ScreenRouter (autoload) — satu-satunya pengelola layar UI.
##
## Seluruh layar hidup di satu CanvasLayer overlay. Router menyimpan tumpukan
## (stack) sehingga tombol "Back" Android (GDD 12.1) dan tombol kembali di layar
## bisa memakai jalur yang sama.
##
## Layar dibuat lewat `register()` oleh Main, bukan lewat preload, supaya file ini
## tidak bergantung pada kelas layar yang mungkin belum ada saat bootstrap.

## Nama layar yang sah (kontrak ARCHITECTURE.md bagian 10).
const SCREENS: Array[String] = [
	"main_menu", "character_select", "hud", "market", "recipe_book", "staff",
	"marketing", "daily_summary", "decoration", "bailout", "rack",
	"customer_order", "delivery_order",
]

## Layar yang menutupi seluruh layar; HUD di bawahnya disembunyikan.
const FULLSCREEN_SCREENS: Array[String] = [
	"main_menu", "character_select", "daily_summary", "bailout", "decoration",
]

## Layar POPUP: kartu di tengah layar yang TIDAK menyembunyikan layar di
## bawahnya. Dapur dan HUD tetap terlihat di belakangnya, sehingga pemain bisa
## mengawasi oven yang sedang memanggang sambil membuka daftar resep.
##
## Hanya `go()` yang menghormati daftar ini. `back()` dan `close_all()` tetap
## menyembunyikan layar teratas apa pun jenisnya — itu memang cara popup ditutup.
const POPUP_SCREENS: Array[String] = [
	"recipe_book", "staff", "marketing", "customer_order", "delivery_order",
]

## Nama layar yang sedang tampil paling atas ("" bila tidak ada).
var current: String = ""

var _layer: CanvasLayer = null
## screen name -> Callable yang mengembalikan Control baru.
var _builders: Dictionary = {}
## screen name -> instance Control yang sedang hidup (dibuat sesuai kebutuhan).
var _live: Dictionary = {}
## Tumpukan nama layar; elemen terakhir adalah yang tampil.
var _stack: Array[String] = []
var _exit_dialog: ConfirmationDialog = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

	_layer = CanvasLayer.new()
	_layer.name = "ScreenLayer"
	_layer.layer = 10
	add_child(_layer)

	# Tombol/gestur "Back" Android harus ditangani manual (GDD 12.1).
	get_window().set_flag(Window.FLAG_BORDERLESS, false)
	EventBus.screen_requested.connect(_on_screen_requested)


## Mendaftarkan pembangun layar. `builder` harus mengembalikan Control baru.
## Dipanggil Main saat bootstrap untuk setiap layar yang tersedia.
func register(screen: String, builder: Callable) -> void:
	if not SCREENS.has(screen):
		push_error("ScreenRouter: layar tidak dikenal '%s'" % screen)
		return
	_builders[screen] = builder


func has_screen(screen: String) -> bool:
	return _builders.has(screen)


## Membuka layar. Layar sebelumnya tetap di tumpukan supaya back() bisa kembali.
func go(screen: String, args: Dictionary = {}) -> void:
	if not _builders.has(screen):
		push_error("ScreenRouter: layar '%s' belum didaftarkan" % screen)
		return
	if current == screen:
		# Sudah tampil: cukup segarkan argumennya.
		_setup(_live.get(screen), args)
		return

	# Popup dibiarkan menumpuk DI ATAS layar yang sedang tampil; layar biasa
	# menggantikannya seperti sebelumnya.
	if not POPUP_SCREENS.has(screen):
		_hide_top()
	if _stack.has(screen):
		_stack.erase(screen)
	_stack.append(screen)
	_show(screen, args)


## Mengganti layar teratas tanpa menambah tumpukan (mis. hud -> daily_summary -> hud).
func replace(screen: String, args: Dictionary = {}) -> void:
	if not _stack.is_empty():
		_hide_top()
		_stack.pop_back()
	go(screen, args)


## Kembali ke layar sebelumnya. Mengembalikan false bila tidak ada tujuan.
func back() -> bool:
	if _stack.size() <= 1:
		return false
	_hide_top()
	_stack.pop_back()
	var prev: String = _stack[_stack.size() - 1]
	_show(prev, {})
	AudioBus.sfx("pop")
	return true


func close_all() -> void:
	_hide_top()
	_stack.clear()
	current = ""


func _show(screen: String, args: Dictionary) -> void:
	var ctrl: Control = _live.get(screen)
	if ctrl == null or not is_instance_valid(ctrl):
		var builder: Callable = _builders[screen]
		ctrl = builder.call() as Control
		if ctrl == null:
			push_error("ScreenRouter: builder '%s' tidak mengembalikan Control" % screen)
			return
		ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
		_layer.add_child(ctrl)
		_live[screen] = ctrl
	_setup(ctrl, args)
	ctrl.visible = true
	ctrl.move_to_front()
	current = screen


func _setup(ctrl: Variant, args: Dictionary) -> void:
	if ctrl == null or not is_instance_valid(ctrl):
		return
	var node: Control = ctrl as Control
	if node.has_method("setup"):
		node.call("setup", args)


func _hide_top() -> void:
	if _stack.is_empty():
		return
	var top: String = _stack[_stack.size() - 1]
	var ctrl: Variant = _live.get(top)
	if ctrl != null and is_instance_valid(ctrl):
		(ctrl as Control).visible = false


func _on_screen_requested(screen: String, args: Dictionary) -> void:
	go(screen, args)


func _notification(what: int) -> void:
	# Tombol / gestur "Back" Android (GDD 12.1): tutup dialog atau mundur satu layar;
	# di menu utama tampilkan konfirmasi keluar.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_handle_back_request()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_handle_back_request()
		get_viewport().set_input_as_handled()


func _handle_back_request() -> void:
	if back():
		return
	if current == "main_menu" or current == "":
		_confirm_exit()


func _confirm_exit() -> void:
	if _exit_dialog != null and is_instance_valid(_exit_dialog):
		_exit_dialog.popup_centered()
		return
	_exit_dialog = ConfirmationDialog.new()
	_exit_dialog.title = "Keluar"
	_exit_dialog.dialog_text = "Yakin mau menutup Roti Lezat Tycoon?"
	_exit_dialog.ok_button_text = "Keluar"
	_exit_dialog.cancel_button_text = "Batal"
	_exit_dialog.confirmed.connect(func() -> void:
		SaveManager.save_game()
		get_tree().quit()
	)
	_layer.add_child(_exit_dialog)
	_exit_dialog.popup_centered()
