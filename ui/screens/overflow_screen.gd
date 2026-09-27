class_name OverflowScreen
extends UIScreen
## Overlay perayaan "You Broke the Bakery Economy!" (GDD 73). Bukan ending:
## permainan tetap berjalan.


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_overflow_title"), Vector2(620, 360))
	var c := CenterContainer.new()
	c.add_child(ProceduralUIFactory.icon("trophy", 72, Palette.GOLD_STAR))
	body.add_child(c)
	lbl(body, Tx.t("ui_overflow_body"), 18, Palette.TEXT, true)
	btn(body, Tx.t("ui_ok"), "primary", close)
	if sim != null:
		sim.achievements.check_condition(&"economy_overflow")
