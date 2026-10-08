class_name MarketingScreen
extends UIScreen
## Kampanye iklan (GDD 8, 48): satu kampanye aktif, dibayar di muka, tanpa
## refund, diluncurkan after-hours, terbuka bertahap menurut tier lokasi.
## Tutorial Hari 1 (GDD 88.1): dibuka setelah Staff Management, layar ini
## menjalankan tur sorotan kampanye pertama, tombol Launch-nya, lalu daftarnya.

var _tour: CoachMarks = null


func build() -> void:
	sim.tutorial.on_event(&"marketing_opened")
	var body: VBoxContainer = make_popup(Tx.t("ui_marketing"), Vector2(1000, 640))
	var list: VBoxContainer = scroll_box(body)
	list.get_parent().name = "CampaignList"
	var active: Dictionary = sim.marketing.active
	if not sim.time.is_after_hours():
		lbl(list, Tx.t("ui_marketing_after_hours"), 16, Palette.TEXT_MUTED)
	for x: Variant in DataRegistry.campaigns():
		var c: MiscDefinitions.MarketingCampaignDefinition = x
		var card: PanelContainer = ProceduralUIFactory.card(Tx.t(String(c.localization_key)))
		card.name = String(c.id)
		list.add_child(card)
		var cb: VBoxContainer = ProceduralUIFactory.content_of(card)
		lbl(cb, Tx.t(String(c.id) + "_desc"), 15, Palette.TEXT, true)
		var row: HBoxContainer = hbox(cb, 16)
		lbl(row, Tx.t("ui_marketing_cost", {"cost": Tx.kr(c.cost_kr)}), 16, Palette.GOLDEN_CRUST)
		lbl(row, Tx.t("ui_marketing_boost", {"percent": int(Money.round_half_up((c.traffic_multiplier - 1.0) * 100.0))}), 16, Palette.SUCCESS)
		var spacer := Control.new()
		spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(spacer)
		if not active.is_empty() and StringName(str(active["campaign_id"])) == c.id:
			lbl(row, Tx.t("ui_marketing_active", {"days": active["remaining_days"]}), 16, Palette.UI_WOOD)
			continue
		var reason: StringName = sim.marketing.can_launch(c.id)
		var b: Button = btn(row, Tx.t("ui_marketing_launch"), "primary", func() -> void:
			host.confirm(Tx.t("ui_marketing_confirm", {"campaign": Tx.t(String(c.localization_key)), "cost": Tx.kr(c.cost_kr)}), _launch.bind(c.id)))
		b.name = "Launch"
		b.disabled = reason != &""
		if reason == &"locked":
			lbl(cb, Tx.t("ui_marketing_locked", {"location": Tx.t(String(DataRegistry.location_by_tier(c.tier).localization_key))}), 14, Palette.TEXT_MUTED)
		elif reason == &"busy":
			lbl(cb, Tx.t("ui_marketing_busy"), 14, Palette.TEXT_MUTED)
	if sim.tutorial.marketing_tour():
		_start_tour.call_deferred(list)


## Tur sorotan kampanye (GDD 88.1): kartu pertama, tombol Launch-nya, lalu daftar.
func _start_tour(list: VBoxContainer) -> void:
	if is_queued_for_deletion() or list.get_child_count() == 0:
		return
	var first: Control = null
	for c: Node in list.get_children():
		if c is PanelContainer:
			first = c as Control
			break
	if first == null:
		return
	var launch: Node = first.find_child("Launch", true, false)
	_tour = CoachMarks.new()
	add_child(_tour)
	_tour.setup([
		{"targets": func() -> Array: return [first], "key": "tut_tour_marketing_card", "next": true},
		{"targets": func() -> Array: return [launch] if launch != null else [first], "key": "tut_tour_marketing_launch", "next": true},
		{"targets": func() -> Array: return [list.get_parent()], "key": "tut_tour_marketing_later", "next": true},
	])


func tour() -> CoachMarks:
	return _tour if _tour != null and is_instance_valid(_tour) else null


func on_closed() -> void:
	sim.tutorial.on_event(&"marketing_closed")


func _launch(id: StringName) -> void:
	var r: StringName = sim.marketing.launch(id)
	if r != &"":
		EventBus.notify.emit(1, "ui_feedback_not_enough_kr" if r == &"kr" else "ui_marketing_busy", {}, &"megaphone")
	close()
	host.open(&"marketing")
