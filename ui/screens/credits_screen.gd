class_name CreditsScreen
extends UIScreen
## Credits (GDD 28.1, 111.3).


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_credits_title"), Vector2(640, 440))
	var c := CenterContainer.new()
	c.add_child(ProceduralUIFactory.icon("bread", 64, Palette.GOLDEN_CRUST))
	body.add_child(c)
	var l: Label = lbl(body, Tx.t("ui_credits_body"), 18, Palette.TEXT, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
