class_name ConfirmDialog
extends UIScreen
## Dialog konfirmasi (GDD 28.1). Untuk aksi destruktif, opsi "hold to confirm"
## (GDD 75.4) mengharuskan tombol ditahan 1 detik.

const HOLD_SECONDS: float = 1.0

var _hold_left: float = -1.0
var _yes: Button = null


## Dialog konfirmasi berada di atas modal apa pun (GDD 28.2).
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_confirm"), Vector2(560, 300), false)
	lbl(body, str(params.get("text", "")), 20, Palette.TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	var row: HBoxContainer = hbox(body, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	btn(row, Tx.t("ui_cancel"), "secondary", _cancel)
	var destructive: bool = bool(params.get("destructive", false))
	var hold: bool = destructive and SettingsManager.get_bool("hold_to_confirm")
	_yes = ProceduralUIFactory.button(Tx.t("ui_hold_to_confirm") if hold else Tx.t("ui_confirm"), "danger" if destructive else "primary")
	row.add_child(_yes)
	if hold:
		_yes.button_down.connect(func() -> void: _hold_left = HOLD_SECONDS)
		_yes.button_up.connect(func() -> void: _hold_left = -1.0)
	else:
		_yes.pressed.connect(_accept)


func _process(delta: float) -> void:
	if _hold_left < 0.0:
		return
	_hold_left -= delta
	_yes.modulate = Color(1, 1, 1, 0.5 + 0.5 * (1.0 - _hold_left / HOLD_SECONDS))
	if _hold_left <= 0.0:
		_hold_left = -1.0
		_accept()


func _accept() -> void:
	var cb: Callable = params.get("on_yes", Callable())
	close()
	EventBus.sfx.emit(&"ui_confirm", &"")
	if cb.is_valid():
		cb.call()


func _cancel() -> void:
	EventBus.sfx.emit(&"ui_cancel", &"")
	close()
