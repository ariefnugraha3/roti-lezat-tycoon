class_name SaveSummary
extends RefCounted
## Ringkasan toko satu save (GDD idle 15.3, 20 no. 57): dipakai Export Save dan
## pratinjau Import Save. Gambar toko sesuai tier lokasi, nama, hari dan lokasi,
## saldo, lalu medali badge achievement (GDD 72.1). `h` dari SaveManager.header_of
## atau read_header.


static func row(h: Dictionary, art_size: float) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.name = "Summary"
	r.add_theme_constant_override("separation", 16)
	var art := ShopFrontArt.new()
	art.name = "ShopArt"
	art.custom_minimum_size = Vector2(art_size, art_size)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ldef: LocationDefinition = DataRegistry.location(StringName(str(h.get("location_id", ""))))
	art.tier = ldef.tier if ldef != null else 1
	r.add_child(art)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override("separation", 4)
	r.add_child(info)
	var nm: Label = UIScreen.lbl(info, str(h.get("bakery_name", "")), 22, Palette.UI_WOOD_DEEP)
	nm.name = "BakeryName"
	nm.add_theme_font_override("font", ProceduralUIFactory.display_font())
	nm.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	nm.clip_text = true
	nm.custom_minimum_size = Vector2(100.0, 0.0)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var loc: String = str(h.get("location_id", ""))
	var where: String = Tx.t("ui_profile_day", {"day": h.get("day", 1)})
	if loc != "":
		where += " · " + (Tx.t(loc) if DataRegistry.has_text(loc) else loc)
	UIScreen.lbl(info, where, 16, Palette.TEXT_MUTED, true)
	var money: HBoxContainer = ProceduralUIFactory.icon_value("coin", Tx.kr(float(h.get("balance_kr", 0.0))), 22, 18, Palette.GOLDEN_CRUST)
	(money.get_meta("value") as Label).add_theme_color_override("font_color", Palette.GOLDEN_CRUST)
	info.add_child(money)
	var medals: Control = badges(h.get("badges", []))
	if medals != null:
		(medals as HBoxContainer).alignment = BoxContainer.ALIGNMENT_BEGIN
		info.add_child(medals)
	return r


## Satu lingkaran berwarna pita badge itu dengan ikonnya; namanya muncul sebagai
## tooltip. null tanpa badge.
static func badges(ids: Array) -> Control:
	if ids.is_empty():
		return null
	var r := HBoxContainer.new()
	r.name = "Badges"
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", 8)
	for id: Variant in ids:
		var def: MiscDefinitions.DecorationDefinition = DataRegistry.decoration(StringName(str(id)))
		if def == null or not def.is_badge():
			continue
		var medal: PanelContainer = ProceduralUIFactory.badge(String(def.badge_icon), DecorFactory.badge_ribbon(def.visual_profile_id), Palette.FLOUR_WHITE, 40)
		medal.tooltip_text = Tx.t(String(def.localization_key))
		medal.mouse_filter = Control.MOUSE_FILTER_PASS
		r.add_child(medal)
	if r.get_child_count() == 0:
		r.free()
		return null
	return r
