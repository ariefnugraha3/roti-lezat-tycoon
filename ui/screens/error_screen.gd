class_name ErrorScreen
extends UIScreen
## Galat yang dapat dipulihkan (GDD 89.5, 114, 132). Save rusak tidak pernah
## ditimpa otomatis: memulai baru di profil itu memerlukan konfirmasi.


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_confirm") if DataRegistry.is_valid() else "Error", Vector2(600, 320))
	lbl(body, str(params.get("text", "")), 20, Palette.TEXT, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	if not DataRegistry.is_valid():
		return
	var row: HBoxContainer = hbox(body, 16)
	row.alignment = BoxContainer.ALIGNMENT_END
	btn(row, Tx.t("ui_back"), "secondary", close)
	if bool(params.get("offer_new", false)):
		var pid: StringName = StringName(str(params.get("profile_id", "")))
		btn(row, Tx.t("ui_start_new_here"), "danger", _ask_new.bind(pid))


func _ask_new(pid: StringName) -> void:
	host.confirm(Tx.t("ui_profile_overwrite"), _start_new.bind(pid), true)


func _start_new(pid: StringName) -> void:
	close()
	host.open(&"new_game", {"profile_id": pid})
