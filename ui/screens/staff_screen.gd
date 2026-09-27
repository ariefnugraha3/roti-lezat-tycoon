class_name StaffScreen
extends UIScreen
## Manajemen Karyawan (GDD 3.1-3.5, 7, 23.4, 23.7, 49.3, 87). Roster tetap
## tanpa RNG; rekrut hanya after-hours, pecat/libur kapan saja.

var _tab: int = 0
var _body: VBoxContainer = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_staff"), Vector2(1200, 660))
	var head: HBoxContainer = hbox(body, 8)
	btn(head, Tx.t("ui_staff_team"), "secondary", func() -> void:
		_tab = 0
		_render())
	btn(head, Tx.t("ui_staff_applicants"), "secondary", func() -> void:
		_tab = 1
		_render())
	_body = VBoxContainer.new()
	_body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_body)
	_render()


func _render() -> void:
	clear(_body)
	var loc: LocationDefinition = sim.world.location
	lbl(_body, Tx.t("ui_staff_capacity", {"cashiers": sim.staff.employed_ids(&"cashier").size(), "max_cashiers": loc.staff_capacity(&"cashier"),
		"bakers": sim.staff.employed_ids(&"baker").size(), "max_bakers": loc.staff_capacity(&"baker")}), 16, Palette.UI_WOOD)
	lbl(_body, Tx.t("ui_staff_projected", {"cash": Tx.kr(sim.staff.projected_cash_after_wages())}), 15, Palette.TEXT_MUTED)
	if sim.bailout.wage_warning or sim.staff.projected_cash_after_wages() < 0.0:
		lbl(_body, Tx.t("ui_staff_wage_warning"), 15, Palette.DANGER, true)
	if not sim.staff.can_hire_now():
		lbl(_body, Tx.t("ui_staff_hire_after_hours"), 15, Palette.TEXT_MUTED)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_body.add_child(sc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	sc.add_child(row)
	var ids: Array[StringName] = []
	if _tab == 0:
		ids = sim.staff.employed_ids()
	else:
		for s: StaffDefinition in DataRegistry.staff_list():
			if not sim.staff.is_employed(s.id):
				ids.append(s.id)
	if ids.is_empty():
		lbl(row, Tx.t("ui_record_none"), 18, Palette.TEXT_MUTED)
	for id: StringName in ids:
		row.add_child(_staff_card(id))


func _staff_card(id: StringName) -> Control:
	var def: StaffDefinition = DataRegistry.staff(id)
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(230, 0)
	holder.add_theme_constant_override("separation", 6)
	holder.add_child(ProceduralUIFactory.polaroid(String(id)))
	var bio: Label = lbl(holder, Tx.t(String(id)), 13, Palette.TEXT_MUTED, true)
	bio.custom_minimum_size = Vector2(220, 0)
	var sp: String = ""
	if def.is_cashier():
		if def.special.has("queue_patience_drain_multiplier"):
			sp = "staff_special_queue"
		elif def.special.has("indecisive_service_multiplier"):
			sp = "staff_special_indecisive"
		elif def.special.has("physical_tip_chance"):
			sp = "staff_special_tip"
	if sp != "":
		lbl(holder, Tx.t(sp), 13, Palette.GOLDEN_CRUST, true)
	if not sim.staff.is_employed(id):
		var full: bool = sim.staff.employed_ids(def.role_id).size() >= sim.staff.capacity(def.role_id)
		var hire: Button = btn(holder, Tx.t("ui_staff_hire"), "primary", func() -> void:
			var r: StringName = sim.staff.hire(id)
			if r != &"":
				EventBus.notify.emit(1, "ui_staff_full" if r == &"full" else "ui_staff_hire_after_hours",
					{"role": Tx.t("ui_staff_role_cashier") if def.is_cashier() else Tx.t("ui_staff_role_baker")}, &"warning")
			else:
				EventBus.notify.emit(2, "ui_staff_starts_tomorrow", {}, &"people")
			_render())
		hire.disabled = full or not sim.staff.can_hire_now()
		return holder
	var c: Dictionary = sim.staff.contract(id)
	var on: bool = bool(c.get("on_duty", false))
	lbl(holder, Tx.t("ui_staff_on_duty") if on else Tx.t("ui_staff_off_duty"), 15, Palette.SUCCESS if on else Palette.TEXT_MUTED)
	btn(holder, Tx.t("ui_staff_set_off_duty") if on else Tx.t("ui_staff_set_on_duty"), "secondary", func() -> void:
		var r2: StringName = sim.staff.set_on_duty(id, not on)
		if r2 == &"kr":
			EventBus.notify.emit(1, "ui_staff_wage_warning", {}, &"coin")
		_render())
	if def.is_baker():
		var mode: String = str(c.get("mode", "auto"))
		btn(holder, "%s: %s" % [Tx.t("ui_staff_mode"), Tx.t("ui_staff_mode_auto") if mode == "auto" else Tx.t("ui_staff_mode_target")], "ghost", func() -> void:
			sim.staff.set_mode(id, "target" if mode == "auto" else "auto", StringName(str(c.get("target_recipe", ""))))
			_render())
		if mode == "target":
			var tr: String = str(c.get("target_recipe", ""))
			btn(holder, Tx.t("ui_staff_target_pick", {"recipe": Tx.recipe_name(StringName(tr)) if tr != "" else "—"}), "ghost", _cycle_target.bind(id))
		var batch: int = int(c.get("batch", 0))
		btn(holder, "%s: %s" % [Tx.t("ui_staff_batch_size"), Tx.t("ui_batch_auto") if batch == 0 else "x%d" % batch], "ghost", func() -> void:
			var order: Array[int] = [0, 1, 3, 5]
			sim.staff.set_batch(id, order[(order.find(batch) + 1) % order.size()])
			_render())
	btn(holder, Tx.t("ui_staff_fire"), "danger", func() -> void:
		host.confirm(Tx.t("ui_staff_fire_confirm", {"name": def.display_name}), _fire.bind(id), true))
	return holder


## Mode Target Resep: berputar di antara resep yang tier alatnya dimiliki.
func _cycle_target(id: StringName) -> void:
	var c: Dictionary = sim.staff.contract(id)
	var options: Array[StringName] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.production.owns_equipment_for(r):
			options.append(r.id)
	if options.is_empty():
		return
	var cur: StringName = StringName(str(c.get("target_recipe", "")))
	var i: int = options.find(cur)
	sim.staff.set_mode(id, "target", options[(i + 1) % options.size()])
	_render()


func _fire(id: StringName) -> void:
	sim.staff.fire(id)
	_render()
