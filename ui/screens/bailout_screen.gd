class_name BailoutScreen
extends UIScreen
## Cutscene kunjungan Pak Lurah (GDD 3.0.A, 45). Transaksi bantuan sudah
## diterapkan tepat sekali oleh BailoutManager pukul 05:00; cutscene hanya
## presentasi, jadi Skip tidak pernah menggandakan atau menghilangkan bantuan
## (GDD 45.2). Lima shot diringkas: ketukan pintu -> masuk -> dialog -> amplop
## ke HUD -> penutup + tip Mode Solo.

var _shot: int = 0
var _text: Label = null
var _full: String = ""
var _chars: float = 0.0
var _portrait: Control = null


func build() -> void:
	var shade := ColorRect.new()
	shade.color = Color(Palette.DARK_CHOCOLATE, 0.35)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PANEL, 24, true))
	pc.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	pc.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pc.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pc.offset_bottom = -24
	pc.custom_minimum_size = Vector2(minf(980.0, get_viewport_rect().size.x - 40.0), 260)
	add_child(pc)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	pc.add_child(row)
	_portrait = _LurahPortrait.new()
	_portrait.custom_minimum_size = Vector2(180, 220)
	row.add_child(_portrait)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(v)
	lbl(v, Tx.t("npc_pak_lurah"), 22, Palette.UI_WOOD)
	_text = lbl(v, "", 18, Palette.TEXT, true)
	var nav: HBoxContainer = hbox(v, 12)
	nav.alignment = BoxContainer.ALIGNMENT_END
	btn(nav, Tx.t("ui_skip"), "ghost", _finish)
	btn(nav, Tx.t("ui_next"), "primary", _next)
	EventBus.sfx.emit(&"door_bell_enter", &"")
	EventBus.music_state_changed.emit(&"BAILOUT_CUTSCENE")
	if game != null and game.world != null:
		var lane: QueueLane = sim.queue.main_lane()
		game.world.camera_rig.soft_focus(GridMath.cell_center3(sim.world.entrance_cell()), 3.0)
	_show_shot()


func _show_shot() -> void:
	match _shot:
		0:
			_full = Tx.t("dlg_bailout_repeat") if bool(params.get("repeat", false)) else Tx.t("dlg_bailout_first")
		1:
			_full = Tx.t("dlg_bailout_grant", {"amount": Tx.kr(DataRegistry.balf("bailout.grant_kr"))})
			EventBus.coin_popup.emit(DataRegistry.balf("bailout.grant_kr"), sim.world.entrance_cell(), sim.world.store_floor())
			EventBus.sfx.emit(&"cashier_coin", &"")
		2:
			_full = Tx.t("dlg_bailout_solo")
			if bool(params.get("repeat", false)):
				_full += "\n" + Tx.t("tip_low_cash")
	_chars = 0.0
	_text.text = ""


func _process(delta: float) -> void:
	if _chars < float(_full.length()):
		_chars += delta * 45.0
		_text.text = _full.substr(0, int(_chars))


## Ketuk mempercepat typewriter lebih dulu (GDD 45.1 shot 3).
func _next() -> void:
	if _chars < float(_full.length()):
		_chars = float(_full.length())
		_text.text = _full
		return
	_shot += 1
	if _shot > 2:
		_finish()
		return
	_show_shot()


func _finish() -> void:
	close()


func on_closed() -> void:
	if sim != null:
		sim.bailout.cutscene_pending = false
		sim.tutorial.on_event(&"bailout_seen")


func on_back() -> bool:
	_finish()
	return true


## Potret chibi Pak Lurah digambar dengan _draw() (GDD 12.3.3 potret 2D).
class _LurahPortrait extends Control:
	func _draw() -> void:
		var c: Vector2 = size * Vector2(0.5, 0.42)
		var r: float = minf(size.x, size.y) * 0.28
		draw_circle(c + Vector2(0, r * 1.9), r * 1.35, Color(0.827, 0.780, 0.596))
		draw_circle(c, r, CharacterFactory.SKIN_TAN)
		draw_rect(Rect2(c.x - r * 0.8, c.y - r * 1.25, r * 1.6, r * 0.5), Color(0.15, 0.15, 0.18))
		for s: float in [-1.0, 1.0]:
			draw_circle(c + Vector2(s * r * 0.38, -r * 0.05), r * 0.11, CharacterFactory.EYE_COLOR)
			draw_circle(c + Vector2(s * r * 0.55, r * 0.28), r * 0.14, Color(Palette.ROSY_CHEEK, 0.6))
		draw_arc(c + Vector2(0, r * 0.25), r * 0.3, 0.2, PI - 0.2, 12, CharacterFactory.MOUTH_COLOR, 3.0)
		draw_rect(Rect2(c.x - r * 0.35, c.y + r * 0.12, r * 0.7, r * 0.1), CharacterFactory.HAIR_GREY)
		draw_rect(Rect2(c.x + r * 0.9, c.y + r * 1.6, r * 0.9, r * 0.6), Palette.CARAMEL)
