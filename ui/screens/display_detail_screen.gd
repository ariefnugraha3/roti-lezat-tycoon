class_name DisplayDetailScreen
extends UIScreen
## Detail rak (GDD 19.7.1, 19.7.5, 61.3): label freshness dan estimasi sisa
## waktu tiap petak (tanpa hitung mundur per unit), plus tombol buang roti
## basi/kedaluwarsa. Tidak ada refund bahan.

var _body: VBoxContainer = null
var _tour: CoachMarks = null


func build() -> void:
	var iid: int = int(params.get("display", -1))
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	var title_text: String = Tx.item_name(e.def_id) if e != null else Tx.t("ui_display_detail")
	var body: VBoxContainer = make_popup(title_text, Vector2(900, 580))
	_body = scroll_box(body)
	var row: HBoxContainer = hbox(body, 12)
	row.alignment = BoxContainer.ALIGNMENT_END
	var discard: Button = btn(row, Tx.t("ui_display_discard"), "danger", func() -> void:
		host.confirm(Tx.t("ui_display_discard_confirm"), _discard, true))
	discard.name = "Discard"
	discard.disabled = not sim.display.has_discardable(iid)
	_render()
	# Roti basi pertama yang bisa dibuang: sorot Discard sekali (GDD 88.4).
	if sim.display.has_discardable(iid) and sim.tutorial.screen_tour(&"discard"):
		sim.tutorial.mark_tour(&"discard")
		_start_tour.call_deferred(discard)


func _start_tour(discard: Button) -> void:
	if is_queued_for_deletion():
		return
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup([{"targets": func() -> Array: return [discard], "key": "tut_discard", "next": true}])


func tour() -> CoachMarks:
	return _tour if _tour != null and is_instance_valid(_tour) else null


func _render() -> void:
	clear(_body)
	var iid: int = int(params.get("display", -1))
	var slots: Array = sim.display.slots(iid)
	var def: EquipmentDefinition = sim.display.def_of(iid)
	lbl(_body, "%d / %d" % [sim.display.used(iid), sim.display.capacity(iid)], 18, Palette.UI_WOOD)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var card: PanelContainer = ProceduralUIFactory.card("")
		_body.add_child(card)
		var cb: VBoxContainer = ProceduralUIFactory.content_of(card)
		var units: int = sim.display.slot_units(iid, i)
		if units == 0:
			lbl(cb, "#%d · %s" % [i + 1, Tx.t("ui_slot_empty")], 16, Palette.TEXT_MUTED)
			continue
		lbl(cb, "#%d · %s · %s" % [i + 1, Tx.recipe_name(s["recipe"]), Tx.t("ui_slot_fill", {"count": units, "max": def.max_per_slot})], 17)
		for st: BreadStack in s["stacks"]:
			var remaining: float = maxf(0.0, (st.base_expiry_hours - st.age_ingame_hours) / maxf(def.aging_rate, 0.01))
			var state_key: String = "ui_freshness_%s" % String(st.freshness_state).to_lower()
			var r2: HBoxContainer = hbox(cb, 8)
			r2.add_child(ProceduralUIFactory.icon(_state_icon(st.freshness_state), 18, _state_color(st.freshness_state)))
			lbl(r2, "%d × %s · %s" % [st.quantity, Tx.t(state_key), Tx.t("ui_display_remaining", {"hours": "%.1f" % remaining})], 15)


static func _state_icon(s: StringName) -> String:
	match s:
		&"FRESH":
			return "star"
		&"GOOD":
			return "check"
		&"STALE":
			return "hourglass"
	return "cross"


static func _state_color(s: StringName) -> Color:
	match s:
		&"FRESH":
			return Palette.SUCCESS
		&"GOOD":
			return Palette.GOLD_STAR
		&"STALE":
			return Palette.WARNING
	return Palette.DANGER


func _discard() -> void:
	sim.display.discard(int(params.get("display", -1)), true)
	_render()
