class_name StaffScreen
extends UISheet
## Layar Staff (GDD idle 8.6, 12.3): daftar staf dan kandidat vertikal di
## lembar bawah; detail sebagai halaman berikutnya. Merekrut dibayar sekali
## (`staff.hire_cost[n]`), tanpa gaji dan tanpa tombol bertugas (GDD idle 5.5).
## Roster tetap 5 kasir + 5 koki (v3.1 3.5).

## Tombol Hire yang tampil: sid -> Button, diperbarui tiap tick saat KR berubah.
var _hire_buttons: Dictionary = {}


func sheet_title() -> String:
	return Tx.t("ui_tab_staff")


func build_page(body: VBoxContainer) -> void:
	_hire_buttons.clear()
	var loc: LocationDefinition = sim.world.location
	var cap: Label = lbl(body, Tx.t("ui_staff_capacity", {"cashiers": sim.staff.employed_ids(&"cashier").size(),
		"max_cashiers": loc.staff_capacity(&"cashier"), "bakers": sim.staff.employed_ids(&"baker").size(),
		"max_bakers": loc.staff_capacity(&"baker")}), 16, Palette.UI_WOOD, true)
	cap.name = "Capacity"
	var list: VBoxContainer = scroll_box(body)
	list.name = "StaffList"
	var team: Array[StringName] = sim.staff.employed_ids()
	if not team.is_empty():
		lbl(list, Tx.t("ui_staff_team"), 15, Palette.TEXT_MUTED)
		for id: StringName in team:
			_staff_row(list, DataRegistry.staff(id))
	for role: StringName in [&"cashier", &"baker"]:
		lbl(list, Tx.t("ui_staff_candidates_" + String(role)), 15, Palette.TEXT_MUTED)
		for def: StaffDefinition in DataRegistry.staff_list():
			if def.role_id == role and not sim.staff.is_employed(def.id):
				_staff_row(list, def)


func _staff_row(parent: Control, def: StaffDefinition) -> void:
	var icon: Control = ProceduralUIFactory.badge("chef" if def.is_baker() else "coin", Palette.HONEY if def.is_baker() else Palette.MATCHA, Palette.FLOUR_WHITE, 44)
	var hired: bool = sim.staff.is_employed(def.id)
	var sub: String = Tx.t(def.title_key())
	if hired:
		sub = "%s · %s" % [sub, Tx.t("ui_level_chip", {"level": sim.upgrades.staff_level(def.id)})]
	var h: HBoxContainer = UISheet.row(parent, def.display_name, sub, icon)
	h.get_parent().name = String(def.id)
	if not hired:
		var b: Button = _hire_button(def)
		h.add_child(b)
	var open: Button = ProceduralUIFactory.icon_button("play", Tx.t("ui_staff_details"), "ghost")
	open.name = "Details"
	var sid: StringName = def.id
	open.pressed.connect(func() -> void: push_page(def.display_name, _detail.bind(sid)))
	h.add_child(open)


func _hire_button(def: StaffDefinition) -> Button:
	var cost: float = sim.staff.next_hire_cost()
	var reason: StringName = sim.staff.hire_block(def.id)
	var text: String = Tx.t("ui_staff_role_full") if reason == &"full" else Tx.t("ui_staff_hire_for", {"price": Tx.big(cost)})
	var b: Button = ProceduralUIFactory.icon_text_button("coin", text, "primary", 20, 16)
	b.name = "Hire"
	b.disabled = reason != &""
	# Lebar mengikuti teksnya, supaya skala teks 150% tetap muat (GDD idle 12.0.5).
	b.custom_minimum_size = Vector2(maxf(150.0, ProceduralUIFactory._text_width(text, 16, true) + 20.0 + 8.0 + 36.0), 52)
	var sid: StringName = def.id
	_hire_buttons[sid] = b
	b.pressed.connect(func() -> void:
		if sim.staff.hire(sid) == &"":
			EventBus.sfx.emit(&"ui_confirm", &"")
		refresh())
	return b


## Detail staf: polaroid, bio, tugas perannya, kegiatannya sekarang, lalu
## rekrut atau level.
func _detail(body: VBoxContainer, sid: StringName) -> void:
	_hire_buttons.clear()
	var def: StaffDefinition = DataRegistry.staff(sid)
	var list: VBoxContainer = scroll_box(body)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	list.add_child(top)
	top.add_child(ProceduralUIFactory.polaroid(String(def.id)))
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 8)
	top.add_child(col)
	lbl(col, Tx.t(def.title_key()), 18, Palette.UI_WOOD_DEEP)
	lbl(col, Tx.t("ui_staff_duty_baker" if def.is_baker() else "ui_staff_duty_cashier"), 15, Palette.GOLDEN_CRUST, true)
	var doing: String = activity_text(def)
	if doing != "":
		var act: Label = lbl(col, doing, 15, Palette.UI_WOOD, true)
		act.name = "Activity"
	lbl(list, Tx.t(String(def.id)), 16, Palette.TEXT, true)
	if not sim.staff.is_employed(sid):
		list.add_child(_hire_button(def))
	else:
		lbl(list, Tx.t("ui_level_chip", {"level": sim.upgrades.staff_level(sid)}), 18, Palette.UI_WOOD_DEEP)


## Kegiatan staf yang sedang bekerja, sebagai kalimat; kosong bila tidak.
func activity_text(def: StaffDefinition) -> String:
	match sim.staff.activity(def.id):
		&"serving":
			return Tx.t("ui_staff_activity_counter")
		&"packing":
			return Tx.t("ui_staff_activity_packing")
		&"working":
			return Tx.t("ui_staff_activity_working")
		&"sitting", &"walking":
			return Tx.t("ui_staff_activity_resting")
	return ""


## KR terus berubah: tombol Hire menyala begitu terjangkau.
func tick_page() -> void:
	for sid: Variant in _hire_buttons.keys():
		var b: Button = _hire_buttons[sid]
		if is_instance_valid(b):
			b.disabled = sim.staff.hire_block(sid) != &""
