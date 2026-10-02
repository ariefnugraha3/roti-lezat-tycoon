extends TestSuite
## UI flat (GDD 130.6, keputusan maintainer 2026-10-02): seluruh UI 2D berupa
## bidang warna polos tanpa bayangan, bibir, kilap, garis tepi huruf, maupun
## gradasi. Tes ini menjaga agar kedalaman tidak kembali lewat helper kit.


func tests() -> Array:
	return [
		{"id": "ACC_130_FLAT_UI", "name": "130.6 the UI kit draws flat: no drop shadows, lips, gloss or text outlines on panels, buttons, badges, chips and titles, and button content sits centred on the face", "fn": _flat},
	]


func _flat() -> void:
	check(ProceduralUIFactory.flat_style, "the release UI is flat")
	eq(ProceduralUIFactory.lip(), 0, "no button lip")
	eq(ProceduralUIFactory.press_shift(), 0, "the face does not sink when pressed")
	near(ProceduralUIFactory.content_lift(), 0.0, 0.0001, "button content is centred on the face")
	var p: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 20, true)
	eq(p.shadow_size, 0, "panels cast no shadow")
	eq(p.border_width_bottom, 0, "panels have no lip")
	eq(p.content_margin_top, p.content_margin_bottom, "panel content is centred")
	for kind: String in ["primary", "secondary", "success", "danger", "ghost", "tab"]:
		var k: Dictionary = ProceduralUIFactory.kind_colors(kind)
		check(not bool(k["gloss"]), "%s has no gloss" % kind)
		check((k["outline"] as Color).a == 0.0, "%s text has no outline" % kind)
		for st: String in ["normal", "hover", "pressed", "disabled"]:
			var sb: StyleBoxFlat = ProceduralUIFactory.cushion(k["face"], k["deep"], ProceduralUIFactory.RADIUS_PILL, st)
			eq(sb.shadow_size, 0, "%s %s casts no shadow" % [kind, st])
			eq(sb.border_width_bottom, sb.border_width_top, "%s %s has no lip" % [kind, st])
			near(sb.expand_margin_top, 0.0, 0.0001, "%s %s does not sink" % [kind, st])
	var b: Button = ProceduralUIFactory.button("Go", "primary")
	eq(b.get_theme_constant("outline_size"), 0, "button text has no outline")
	b.free()
	var badge: PanelContainer = ProceduralUIFactory.badge("cart", Palette.HONEY, Palette.FLOUR_WHITE, 36)
	var bs: StyleBoxFlat = badge.get_theme_stylebox("panel") as StyleBoxFlat
	check(bs.border_width_bottom == 0 and bs.shadow_size == 0, "badges are flat circles")
	badge.free()
	var chip: PanelContainer = ProceduralUIFactory.chip("coin", Palette.GOLD_STAR, "1", 20, 28)
	var cs: StyleBoxFlat = chip.get_theme_stylebox("panel") as StyleBoxFlat
	check(cs.border_width_bottom == 0 and cs.shadow_size == 0, "HUD chips are flat pills")
	chip.free()
	var title: Label = ProceduralUIFactory.hero_label("Title", 26, Palette.FLOUR_WHITE, Palette.HONEY_DEEP)
	eq(title.get_theme_constant("outline_size"), 0, "titles have no outline")
	near(title.get_theme_color("font_shadow_color").a, 0.0, 0.0001, "titles have no extruded shadow")
	title.free()
	var pop: Control = ProceduralUIFactory.popup("Title")
	var card: PanelContainer = pop.get_meta("kartu")
	check(card.find_child("PaperGrain", false, false) == null, "popups have no paper grain")
	var face: StyleBoxFlat = card.get_theme_stylebox("panel") as StyleBoxFlat
	check(face.shadow_size == 0 and face.border_width_bottom == 0, "popup cards are flat")
	pop.free()
