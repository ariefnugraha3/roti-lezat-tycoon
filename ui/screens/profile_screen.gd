class_name ProfileScreen
extends UIScreen
## Tiga profil save independen (GDD 89.3). Mode "new" memilih profil kosong
## atau menimpa (dengan konfirmasi); mode "load" memuat profil.


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(Palette.BG, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var body: VBoxContainer = make_popup(Tx.t("ui_profile_title"), Vector2(1100, 560))
	var row: HBoxContainer = hbox(body, 18)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var headers: Array[Dictionary] = SaveManager.scan_headers()
	for i in headers.size():
		row.add_child(_card(i + 1, headers[i]))


func _card(n: int, h: Dictionary) -> Control:
	var pid: StringName = h["profile_id"]
	var card: PanelContainer = ProceduralUIFactory.card(Tx.t("ui_profile_slot", {"n": n}))
	card.custom_minimum_size = Vector2(320, 380)
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var body: VBoxContainer = ProceduralUIFactory.content_of(card)
	var mode: String = str(params.get("mode", "load"))
	var exists: bool = bool(h.get("exists", false))
	var corrupt: bool = bool(h.get("corrupt", false))
	var ic := CenterContainer.new()
	ic.add_child(ProceduralUIFactory.icon("shop", 56, Palette.GOLDEN_CRUST if exists else Palette.TEXT_MUTED))
	body.add_child(ic)
	if not exists:
		lbl(body, Tx.t("ui_profile_empty"), 20, Palette.TEXT_MUTED)
	elif corrupt:
		lbl(body, Tx.t("ui_save_error"), 18, Palette.DANGER, true)
	else:
		lbl(body, str(h.get("bakery_name", "")), 22, Palette.UI_WOOD, true)
		lbl(body, Tx.t("ui_profile_day", {"day": h.get("day", 1)}), 18)
		var loc: String = str(h.get("location_id", ""))
		lbl(body, Tx.t(loc) if DataRegistry.has_text(loc) else loc, 16, Palette.TEXT_MUTED, true)
		lbl(body, Tx.kr(float(h.get("balance_kr", 0.0))), 18, Palette.GOLDEN_CRUST)
		lbl(body, Tx.t("ui_profile_last_played", {"when": str(h.get("last_played_at", "")).replace("T", " ").replace("Z", "")}), 14, Palette.TEXT_MUTED, true)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(spacer)
	if mode == "new":
		btn(body, Tx.t("ui_main_new_game"), "primary", _on_new.bind(pid, exists))
	elif exists and not corrupt:
		btn(body, Tx.t("ui_main_continue"), "primary", _on_load.bind(pid))
	if exists:
		btn(body, Tx.t("ui_profile_delete"), "danger", _on_delete.bind(pid))
	return card


func _on_new(pid: StringName, exists: bool) -> void:
	if exists:
		host.confirm(Tx.t("ui_profile_overwrite"), _start_new.bind(pid), true)
	else:
		_start_new(pid)


func _on_load(pid: StringName) -> void:
	close()
	game.load_profile(pid)


func _on_delete(pid: StringName) -> void:
	host.confirm(Tx.t("ui_profile_delete_confirm"), _do_delete.bind(pid), true)


func _do_delete(pid: StringName) -> void:
	SaveManager.delete_profile(pid)
	var p: Dictionary = params
	close()
	host.open(&"profiles", p)


func _start_new(pid: StringName) -> void:
	close()
	host.open(&"new_game", {"profile_id": pid})
