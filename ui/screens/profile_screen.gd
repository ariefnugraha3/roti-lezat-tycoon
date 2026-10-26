class_name ProfileScreen
extends UIScreen
## Tiga profil save independen (v3.1 89.3; GDD idle 15.3). Mode "new" memilih profil kosong
## atau menimpa (dengan konfirmasi); mode "load" memuat profil.


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Color(Palette.BG, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var body: VBoxContainer = make_popup(Tx.t("ui_profile_title"), Vector2(640, 760))
	# Bingkai potret (GDD idle 12.0.5): tiga kartu bertumpuk, satu per baris.
	var list: VBoxContainer = scroll_box(body)
	list.add_theme_constant_override("separation", 14)
	var headers: Array[Dictionary] = SaveManager.scan_headers()
	for i in headers.size():
		list.add_child(_card(i + 1, headers[i]))


func _card(n: int, h: Dictionary) -> Control:
	var pid: StringName = h["profile_id"]
	var card: PanelContainer = ProceduralUIFactory.card(Tx.t("ui_profile_slot", {"n": n}))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var content: VBoxContainer = ProceduralUIFactory.content_of(card)
	var row: HBoxContainer = hbox(content, 14)
	var mode: String = str(params.get("mode", "load"))
	var exists: bool = bool(h.get("exists", false))
	var corrupt: bool = bool(h.get("corrupt", false))
	var classic: bool = bool(h.get("classic", false))
	var ic := CenterContainer.new()
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.add_child(ProceduralUIFactory.icon("shop", 48, Palette.GOLDEN_CRUST if exists else Palette.TEXT_MUTED))
	row.add_child(ic)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 4)
	row.add_child(body)
	if not exists:
		lbl(body, Tx.t("ui_profile_empty"), 20, Palette.TEXT_MUTED)
	elif classic:
		# Save tycoon v3.1 tidak didukung (GDD idle 15.3): hanya bisa dihapus.
		var cl: Label = lbl(body, Tx.t("ui_classic_save"), 18, Palette.TEXT_MUTED, true)
		cl.name = "ClassicSave"
	elif corrupt:
		lbl(body, Tx.t("ui_save_error"), 18, Palette.DANGER, true)
	else:
		lbl(body, str(h.get("bakery_name", "")), 22, Palette.UI_WOOD, true)
		lbl(body, Tx.t("ui_profile_day", {"day": h.get("day", 1)}), 18)
		var loc: String = str(h.get("location_id", ""))
		lbl(body, Tx.t(loc) if DataRegistry.has_text(loc) else loc, 16, Palette.TEXT_MUTED, true)
		lbl(body, Tx.kr(float(h.get("balance_kr", 0.0))), 18, Palette.GOLDEN_CRUST)
		var medals: Control = badge_row(h.get("badges", []))
		if medals != null:
			body.add_child(medals)
		lbl(body, Tx.t("ui_profile_last_played", {"when": str(h.get("last_played_at", "")).replace("T", " ").replace("Z", "")}), 14, Palette.TEXT_MUTED, true)
	var actions := VBoxContainer.new()
	actions.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	actions.add_theme_constant_override("separation", 8)
	row.add_child(actions)
	if mode == "new":
		btn(actions, Tx.t("ui_main_new_game"), "primary", _on_new.bind(pid, exists))
	elif exists and not corrupt and not classic:
		btn(actions, Tx.t("ui_main_continue"), "primary", _on_load.bind(pid))
	if exists:
		btn(actions, Tx.t("ui_profile_delete"), "danger", _on_delete.bind(pid))
	for b: Node in actions.get_children():
		(b as Control).custom_minimum_size = Vector2(170, 52)
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


## Medali badge achievement di kartu profil (GDD 72.1): satu lingkaran berwarna
## pita badge itu dengan ikonnya; namanya muncul sebagai tooltip.
static func badge_row(ids: Array) -> Control:
	if ids.is_empty():
		return null
	var row := HBoxContainer.new()
	row.name = "Badges"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	for id: Variant in ids:
		var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(StringName(str(id)))
		if def == null or not def.is_badge():
			continue
		var medal: PanelContainer = ProceduralUIFactory.badge(String(def.badge_icon), DecorFactory.badge_ribbon(def.visual_profile_id), Palette.FLOUR_WHITE, 40)
		medal.tooltip_text = Tx.t(String(def.localization_key))
		medal.mouse_filter = Control.MOUSE_FILTER_PASS
		row.add_child(medal)
	return row if row.get_child_count() > 0 else null
