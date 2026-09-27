class_name MainMenuScreen
extends UIScreen
## Main Menu (GDD 89.2): Continue, New Game, Load Game, Settings, Credits, Exit.
## Muncul tanpa membangun dunia apa pun (GDD 89.1).


func _init() -> void:
	super._init()
	blocking = false


func build() -> void:
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var deco := _Backdrop.new()
	deco.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(deco)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card: PanelContainer = ProceduralUIFactory.card("")
	card.custom_minimum_size = Vector2(420, 0)
	center.add_child(card)
	var body: VBoxContainer = ProceduralUIFactory.content_of(card)
	body.add_theme_constant_override("separation", 14)
	var ic := CenterContainer.new()
	ic.add_child(ProceduralUIFactory.icon("bread", 72, Palette.GOLDEN_CRUST))
	body.add_child(ic)
	body.add_child(ProceduralUIFactory.title(Tx.t("game_title"), 38))
	var latest: StringName = SaveManager.latest_profile()
	var cont: Button = btn(body, Tx.t("ui_main_continue"), "primary", func() -> void: game.load_profile(latest))
	cont.disabled = latest == &""
	btn(body, Tx.t("ui_main_new_game"), "primary", func() -> void: host.open(&"profiles", {"mode": "new"}))
	btn(body, Tx.t("ui_main_load"), "secondary", func() -> void: host.open(&"profiles", {"mode": "load"}))
	btn(body, Tx.t("ui_main_settings"), "secondary", func() -> void: host.open(&"settings"))
	btn(body, Tx.t("ui_main_credits"), "ghost", func() -> void: host.open(&"credits"))
	# Web boleh menyembunyikan Quit (GDD 89.2).
	if not OS.has_feature("web"):
		btn(body, Tx.t("ui_main_exit"), "ghost", func() -> void: host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit()))
	for c: Node in body.get_children():
		if c is Button:
			(c as Button).custom_minimum_size = Vector2(320, 56)


func on_back() -> bool:
	host.confirm(Tx.t("ui_exit_confirm"), func() -> void: get_tree().quit())
	return true


## Latar hangat: potongan roti dan koin yang digambar prosedural.
class _Backdrop extends Control:
	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var s: Vector2 = size
		for i in 14:
			var p := Vector2(fmod(float(i) * 173.0, s.x), fmod(float(i) * 97.0 + 40.0, s.y))
			draw_circle(p, 18.0 + float(i % 4) * 6.0, Color(Palette.GOLDEN_CRUST, 0.10))
		draw_rect(Rect2(0, s.y - 70.0, s.x, 70.0), Color(Palette.TERRACOTTA, 0.25))
