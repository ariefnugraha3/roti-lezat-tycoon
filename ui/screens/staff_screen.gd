class_name StaffScreen
extends UIScreen
## Manajemen Karyawan (GDD 3.1-3.5, 7, 49.3, 87). Roster tetap tanpa RNG;
## rekrut hanya after-hours, pecat/libur kapan saja.
##
## Keputusan maintainer 2026-10-02: staf setara (tanpa tier, bintang, maupun
## kemampuan khusus), gaji sama untuk semua menurut tier lokasi, dan koki
## disuruh lewat "Ask a Baker" di Buku Resep, jadi layar ini tidak lagi punya
## pengaturan kerja koki.
##
## Tata letak (perbaikan 2026-10-02): tanpa gulir ke samping. Daftar di kiri,
## dikelompokkan per peran, adalah satu-satunya bagian yang digulir (ke bawah).
## Rincian karyawan terpilih di kanan (kartu polaroid, bio, tugas perannya, dan
## tombol aksinya) muat tanpa gulir.

var _tab: int = 0
var _body: VBoxContainer = null
var _list: VBoxContainer = null
var _detail: VBoxContainer = null
var _ids: Array[StringName] = []
## Karyawan terpilih per tab (Your Team, Applicants).
var _selected: Array[StringName] = [&"", &""]


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_staff"), Vector2(1200, 660))
	body.add_child(ProceduralUIFactory.tab_bar([Tx.t("ui_staff_team"), Tx.t("ui_staff_applicants")], _tab, func(idx: int) -> void:
		_tab = idx
		_render()))
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_body)
	_render()


func _render() -> void:
	clear(_body)
	var loc: LocationDefinition = sim.world.location
	# Ringkasan dalam satu baris: kapasitas per peran di kiri, proyeksi kas di kanan.
	var top: HBoxContainer = hbox(_body, 16)
	var cap: Label = lbl(top, Tx.t("ui_staff_capacity", {"cashiers": sim.staff.employed_ids(&"cashier").size(), "max_cashiers": loc.staff_capacity(&"cashier"),
		"bakers": sim.staff.employed_ids(&"baker").size(), "max_bakers": loc.staff_capacity(&"baker")}), 16, Palette.UI_WOOD)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lbl(top, Tx.t("ui_staff_wage_each", {"wage": Tx.kr(sim.staff.daily_wage())}), 15, Palette.GOLDEN_CRUST)
	lbl(top, Tx.t("ui_staff_projected", {"cash": Tx.kr(sim.staff.projected_cash_after_wages())}), 15, Palette.TEXT_MUTED)
	if sim.bailout.wage_warning or sim.staff.projected_cash_after_wages() < 0.0:
		lbl(_body, Tx.t("ui_staff_wage_warning"), 15, Palette.DANGER, true)
	_ids = _tab_ids()
	if _ids.is_empty():
		_body.add_child(ProceduralUIFactory.empty_state("people", Tx.t("ui_staff_empty") if _tab == 0 else Tx.t("ui_record_none")))
		return
	if not _ids.has(_selected[_tab]):
		_selected[_tab] = _ids[0]
	var split: HBoxContainer = hbox(_body, 14)
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(400, 0)
	split.add_child(left)
	_list = scroll_box(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(right)
	_detail = scroll_box(right)
	_render_list()
	_render_detail()


func _tab_ids() -> Array[StringName]:
	if _tab == 0:
		return sim.staff.employed_ids()
	var out: Array[StringName] = []
	for s: StaffDefinition in DataRegistry.staff_list():
		if not sim.staff.is_employed(s.id):
			out.append(s.id)
	return out


func _render_list() -> void:
	clear(_list)
	var last_role: StringName = &""
	for id: StringName in _ids:
		var def: StaffDefinition = DataRegistry.staff(id)
		if def.role_id != last_role:
			last_role = def.role_id
			lbl(_list, _role_name(def), 14, Palette.TEXT_MUTED)
		_list.add_child(_row(def))


static func _role_name(def: StaffDefinition) -> String:
	return Tx.t("ui_staff_role_cashier") if def.is_cashier() else Tx.t("ui_staff_role_baker")


func _role_full(def: StaffDefinition) -> bool:
	return sim.staff.employed_ids(def.role_id).size() >= sim.staff.capacity(def.role_id)


## Pelamar yang bisa direkrut sekarang, atau karyawan yang bertugas besok.
func _active(def: StaffDefinition) -> bool:
	if sim.staff.is_employed(def.id):
		return bool(sim.staff.contract(def.id).get("on_duty", false))
	return sim.staff.can_hire_now() and not _role_full(def)


## Satu baris daftar: ikon peran, nama, lalu gaji (pelamar) atau status tugas
## (tim) di kanan. Nama yang terlalu panjang dipotong dengan elipsis supaya lebar
## daftar tetap.
func _row(def: StaffDefinition) -> Button:
	var selected: bool = def.id == _selected[_tab]
	var kind: String = "primary" if selected else ("secondary" if _active(def) else "ghost")
	var b: Button = ProceduralUIFactory.button("", kind)
	b.name = String(def.id)
	b.custom_minimum_size = Vector2(0, 52)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.tooltip_text = "%s · %s" % [def.display_name, _role_name(def)]
	var ink: Color = ProceduralUIFactory.kind_colors(kind)["ink"]
	var row := HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16.0
	row.offset_right = -16.0
	row.offset_bottom = -ProceduralUIFactory.content_lift()
	row.add_theme_constant_override("separation", 8)
	b.add_child(row)
	row.add_child(ProceduralUIFactory.icon("chef" if def.is_baker() else "coin", 22, ink))
	var n: Label = ProceduralUIFactory.label(def.display_name, 17, ink)
	n.add_theme_font_override("font", ProceduralUIFactory.display_font())
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	n.clip_text = true
	n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	row.add_child(n)
	var right: String = Tx.t("ui_staff_wage", {"wage": Tx.kr(sim.staff.daily_wage())})
	var right_ink: Color = ink
	if sim.staff.is_employed(def.id):
		var on: bool = bool(sim.staff.contract(def.id).get("on_duty", false))
		right = Tx.t("ui_staff_on_duty") if on else Tx.t("ui_staff_off_duty")
		if not selected:
			right_ink = Palette.SUCCESS if on else Palette.TEXT_MUTED
	var r: Label = ProceduralUIFactory.label(right, 14, right_ink)
	r.name = "Status"
	row.add_child(r)
	var sid: StringName = def.id
	b.pressed.connect(func() -> void:
		_selected[_tab] = sid
		_render_list()
		_render_detail())
	return b


## Rincian karyawan terpilih: polaroid di kiri; bio, tugas perannya, kegiatannya
## sekarang, dan tombol aksi di kanan (tombol didorong ke bawah, sejajar kaki
## polaroid).
func _render_detail() -> void:
	clear(_detail)
	var def: StaffDefinition = DataRegistry.staff(_selected[_tab])
	if def == null:
		return
	var row: HBoxContainer = hbox(_detail, 18)
	row.add_child(ProceduralUIFactory.polaroid(String(def.id), sim.staff.daily_wage()))
	var col := VBoxContainer.new()
	col.name = "Info"
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	lbl(col, Tx.t(String(def.id)), 17, Palette.TEXT, true)
	lbl(col, Tx.t("ui_staff_duty_baker" if def.is_baker() else "ui_staff_duty_cashier"), 15, Palette.GOLDEN_CRUST, true)
	var doing: String = activity_text(def)
	if doing != "":
		var act: Label = lbl(col, doing, 15, Palette.UI_WOOD, true)
		act.name = "Activity"
	var push := Control.new()
	push.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(push)
	if sim.staff.is_employed(def.id):
		_team_actions(def, col)
	else:
		_hire_action(def, col)


func _hire_action(def: StaffDefinition, col: VBoxContainer) -> void:
	var hire: Button = btn(col, Tx.t("ui_staff_hire"), "primary", func() -> void:
		var r: StringName = sim.staff.hire(def.id)
		if r != &"":
			EventBus.notify.emit(1, "ui_staff_full" if r == &"full" else "ui_staff_hire_after_hours",
				{"role": _role_name(def)}, &"warning")
		else:
			EventBus.notify.emit(2, "ui_staff_starts_tomorrow", {}, &"people")
		_render())
	hire.name = "Hire"
	hire.custom_minimum_size = Vector2(220, 52)
	hire.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	hire.disabled = _role_full(def) or not sim.staff.can_hire_now()
	if not sim.staff.can_hire_now():
		lbl(col, Tx.t("ui_staff_hire_after_hours"), 15, Palette.TEXT_MUTED, true)
	elif _role_full(def):
		lbl(col, Tx.t("ui_staff_full", {"role": _role_name(def)}), 15, Palette.DANGER, true)


func _team_actions(def: StaffDefinition, col: VBoxContainer) -> void:
	var id: StringName = def.id
	var c: Dictionary = sim.staff.contract(id)
	var on: bool = bool(c.get("on_duty", false))
	var duty: HBoxContainer = hbox(col, 12)
	var st: Label = lbl(duty, Tx.t("ui_staff_on_duty") if on else Tx.t("ui_staff_off_duty"), 17, Palette.SUCCESS if on else Palette.TEXT_MUTED)
	st.add_theme_font_override("font", ProceduralUIFactory.display_font())
	btn(duty, Tx.t("ui_staff_set_off_duty") if on else Tx.t("ui_staff_set_on_duty"), "secondary", func() -> void:
		var r2: StringName = sim.staff.set_on_duty(id, not on)
		if r2 == &"kr":
			EventBus.notify.emit(1, "ui_staff_wage_warning", {}, &"coin")
		_render())
	var fire: Button = btn(col, Tx.t("ui_staff_fire"), "danger", func() -> void:
		host.confirm(Tx.t("ui_staff_fire_confirm", {"name": def.display_name}), _fire.bind(id), true))
	fire.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN


## Kegiatan karyawan yang sedang bertugas, sebagai kalimat; kosong bila tidak.
func activity_text(def: StaffDefinition) -> String:
	if not sim.staff.is_working(def.id):
		return ""
	if def.is_cashier():
		return Tx.t("ui_staff_activity_counter")
	return Tx.t("ui_staff_activity_working") if sim.staff.activity(def.id) == &"working" else Tx.t("ui_staff_activity_resting")


func _fire(id: StringName) -> void:
	sim.staff.fire(id)
	_render()
