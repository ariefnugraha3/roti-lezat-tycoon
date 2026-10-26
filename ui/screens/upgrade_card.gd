class_name UpgradeCard
extends UIScreen
## Kartu upgrade stasiun (GDD idle 12.2): dibuka dengan mengetuk chip level di
## atas mixer, oven, rak, atau meja kasir. Kartu melayang di atas stasiunnya
## seperti toolbar Decoration Mode; bila tidak muat di atasnya, kartu menempel
## tepat di atas bar tab. Isinya judul "Oven · Lv 12", efek sekarang ->
## berikutnya, bar ke milestone berikutnya, dan tombol ×1 / ×10 / Max.
## Tidak mem-pause toko. Params: {kind: &"station"|&"counter", id}.

const WIDTH: float = 560.0
const GAP: float = 18.0

var kind: StringName = &"station"
var id: Variant = null
var _panel: PanelContainer = null
var _title: Label = null
var _effect: Label = null
var _mile_text: Label = null
var _mile_fill: Panel = null
var _mile_track: Control = null
var _buy: BuyButtons = null
var _refresh_left: float = 0.0


func _init() -> void:
	super._init()
	blocking = false
	sheet = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func build() -> void:
	kind = StringName(str(params.get("kind", "station")))
	id = params.get("id", &"counter")
	_panel = PanelContainer.new()
	_panel.name = "Card"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PARCHMENT, 20, true)
	sb.border_color = Color(Palette.UI_WOOD, 0.45)
	sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.custom_minimum_size = Vector2(WIDTH, 0)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	_panel.add_child(v)
	var head: HBoxContainer = hbox(v, 10)
	head.add_child(UpgradeInfo.icon(sim, _offer(), 40))
	_title = lbl(head, "", 20, Palette.UI_WOOD_DEEP, true)
	_title.name = "Title"
	_title.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var close_b: Button = ProceduralUIFactory.icon_button("cross", Tx.t("ui_close"), "ghost")
	close_b.name = "Close"
	close_b.pressed.connect(close)
	head.add_child(close_b)
	_effect = lbl(v, "", 16, Palette.TEXT, true)
	_effect.name = "Effect"
	_mile_text = lbl(v, "", 14, Palette.UI_WOOD, true)
	_mile_text.name = "Milestone"
	_mile_track = Panel.new()
	_mile_track.name = "MilestoneBar"
	_mile_track.custom_minimum_size = Vector2(0, 12)
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Palette.UI_CREAM_DEEP
	tsb.set_corner_radius_all(6)
	_mile_track.add_theme_stylebox_override("panel", tsb)
	_mile_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_mile_track)
	_mile_fill = Panel.new()
	var fsb := StyleBoxFlat.new()
	fsb.bg_color = Palette.GOLD_STAR
	fsb.set_corner_radius_all(6)
	_mile_fill.add_theme_stylebox_override("panel", fsb)
	_mile_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mile_track.add_child(_mile_fill)
	var row := CenterContainer.new()
	v.add_child(row)
	_buy = BuyButtons.new().setup(sim, kind, id, 150.0)
	_buy.bought.connect(func(_n: int) -> void: _render())
	row.add_child(_buy)
	_render()
	_place()


func _offer() -> Dictionary:
	return sim.upgrades.offer(kind, id) if sim != null else {}


func _render() -> void:
	var o: Dictionary = _offer()
	if o.is_empty():
		close.call_deferred()
		return
	_title.text = UpgradeInfo.title(sim, o)
	_effect.text = UpgradeInfo.effect(sim, o)
	var m: Dictionary = UpgradeInfo.milestone(sim, o)
	_mile_text.visible = not m.is_empty()
	_mile_track.visible = not m.is_empty()
	if not m.is_empty():
		_mile_text.text = str(m["text"])
		var k: float = clampf(float(int(o["level"]) - int(m["from"])) / maxf(float(int(m["level"]) - int(m["from"])), 1.0), 0.0, 1.0)
		_mile_fill.set_meta("ratio", k)
	_buy.refresh()


## Rasio bar milestone (tes).
func milestone_ratio() -> float:
	return float(_mile_fill.get_meta("ratio", 0.0)) if _mile_track.visible else -1.0


func buttons() -> BuyButtons:
	return _buy


func panel() -> PanelContainer:
	return _panel


func _process(delta: float) -> void:
	if sim == null or _panel == null:
		return
	_refresh_left -= delta
	if _refresh_left <= 0.0:
		_refresh_left = 0.5
		_render()
	_place()


## Titik dunia di atas stasiun ini (puncak model), atau Vector3.INF.
func _anchor_world() -> Vector3:
	if game == null or game.world == null:
		return Vector3.INF
	if kind == &"counter":
		var c: Node3D = game.world.main_counter()
		if c == null or not c.is_visible_in_tree():
			return Vector3.INF
		var b: AABB = EquipmentFactory._mesh_bounds(c)
		return c.global_transform * Vector3(b.get_center().x, b.end.y, b.get_center().z)
	var e: EquipmentInstance = sim.equipment.get_inst(int(id))
	if e == null or e.floor_id != game.world.camera_rig.active_floor:
		return Vector3.INF
	return game.world.top_of_iid(e.iid)


## Melayang di atas stasiunnya; bila tidak muat, menempel di atas bar tab.
func _place() -> void:
	var view: Vector2 = get_viewport_rect().size
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var sz: Vector2 = _panel.get_combined_minimum_size()
	sz.x = minf(maxf(sz.x, WIDTH), view.x - 24.0)
	var top_limit: float = inset.y + HUD.TOP_BAR_H
	var bottom_limit: float = view.y - inset.w - HUD.TAB_BAR_H - 8.0
	var docked: Vector2 = Vector2((view.x - sz.x) * 0.5, bottom_limit - sz.y)
	var pos: Vector2 = docked
	var at: Vector3 = _anchor_world()
	if at != Vector3.INF:
		var s: Vector2 = game.world.camera_rig.world_to_screen(at)
		var above: Vector2 = Vector2(clampf(s.x - sz.x * 0.5, 12.0, view.x - sz.x - 12.0), s.y - GAP - sz.y)
		if above.y >= top_limit and s.y <= bottom_limit:
			pos = above
	_panel.position = pos
	_panel.size = sz
	if _mile_track.visible:
		_mile_fill.size = Vector2(maxf(12.0, _mile_track.size.x * float(_mile_fill.get_meta("ratio", 0.0))), 12.0)


## true bila kartu sedang menempel di atas bar tab (tes).
func is_docked() -> bool:
	var view: Vector2 = get_viewport_rect().size
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	return absf(_panel.position.y + _panel.size.y - (view.y - inset.w - HUD.TAB_BAR_H - 8.0)) < 1.0
