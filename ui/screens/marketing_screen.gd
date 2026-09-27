class_name MarketingScreen
extends UIScreen
## Kampanye iklan (GDD 8, 48): satu kampanye aktif, dibayar di muka, tanpa
## refund, diluncurkan after-hours, terbuka bertahap menurut tier lokasi.


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_marketing"), Vector2(1000, 640))
	var list: VBoxContainer = scroll_box(body)
	var active: Dictionary = sim.marketing.active
	if not sim.time.is_after_hours():
		lbl(list, Tx.t("ui_marketing_after_hours"), 16, Palette.TEXT_MUTED)
	for x: Variant in DataRegistry.campaigns():
		var c: MiscDefinitions.MarketingCampaignDefinition = x
		var card: PanelContainer = ProceduralUIFactory.card(Tx.t(String(c.localization_key)))
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
		b.disabled = reason != &""
		if reason == &"locked":
			lbl(cb, Tx.t("ui_marketing_locked", {"location": Tx.t(String(DataRegistry.location_by_tier(c.tier).localization_key))}), 14, Palette.TEXT_MUTED)
		elif reason == &"busy":
			lbl(cb, Tx.t("ui_marketing_busy"), 14, Palette.TEXT_MUTED)


func _launch(id: StringName) -> void:
	var r: StringName = sim.marketing.launch(id)
	if r != &"":
		EventBus.notify.emit(1, "ui_feedback_not_enough_kr" if r == &"kr" else "ui_marketing_busy", {}, &"megaphone")
	close()
	host.open(&"marketing")
