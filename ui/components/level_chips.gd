class_name LevelChips
extends Control
## Chip level di atas setiap stasiun (GDD idle 12.1): "Lv 12" di atas mixer,
## oven, rak, dan meja kasir di lantai yang sedang dilihat, dengan panah naik
## yang berdenyut bila upgrade ×1 terjangkau. Chip adalah kontrol 2D yang
## diproyeksikan dari dunia, dengan target sentuh paling sedikit 48 px, dan
## mengetuknya membuka kartu upgrade (mengetuk stasiunnya = Semangat).
##
## Chip disimpan per stasiun (pool, v3.1 §129) dan hanya dibuat/dibuang saat
## daftar stasiun berubah, jadi ketukan tidak pernah hilang karena tombolnya
## diganti di tengah tekan. Posisi diperbarui tiap frame; teks dan panah pada
## refresh HUD.

## Tinggi chip di atas puncak model (px layar).
const LIFT: float = 22.0
const CHIP_SIZE: Vector2 = Vector2(84.0, 48.0)

var game: GameRoot = null
var sim: SimulationRoot = null
## key ("s<iid>" / "counter") -> {button, label, arrow, kind, id}
var _chips: Dictionary = {}
var _t: float = 0.0


func _init() -> void:
	name = "LevelChips"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	EventBus.level_up.connect(_on_level_up)


## Kunci chip untuk penawaran.
static func key_of(kind: StringName, id: Variant) -> String:
	return "counter" if kind == &"counter" else "s%d" % int(id)


func chip(kind: StringName, id: Variant) -> Button:
	var c: Variant = _chips.get(key_of(kind, id))
	return (c as Dictionary)["button"] if c is Dictionary else null


## Perbarui daftar chip, teks levelnya, dan panah "terjangkau".
func refresh() -> void:
	if sim == null or game == null or game.world == null:
		return
	var want: Dictionary = {}
	for cat: StringName in [&"mixer", &"oven", &"display"]:
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			want[key_of(&"station", e.iid)] = [&"station", e.iid]
	want["counter"] = [&"counter", &"counter"]
	for k: Variant in _chips.keys():
		if not want.has(k):
			((_chips[k] as Dictionary)["button"] as Node).queue_free()
			_chips.erase(k)
	for k2: Variant in want.keys():
		if not _chips.has(k2):
			_chips[k2] = _make(want[k2][0], want[k2][1])
		var c: Dictionary = _chips[k2]
		var o: Dictionary = sim.upgrades.offer(c["kind"], c["id"])
		(c["label"] as Label).text = Tx.t("ui_level_chip", {"level": int(o.get("level", 1))})
		(c["arrow"] as Control).visible = not o.is_empty() and sim.upgrades.offer_count(o, &"x1") > 0


func _make(kind: StringName, id: Variant) -> Dictionary:
	var b := Button.new()
	b.name = "Chip_" + key_of(kind, id)
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = CHIP_SIZE
	b.size = CHIP_SIZE
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	var pill := PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.PANEL, 16, true)
	sb.border_color = Color(Palette.UI_WOOD, 0.5)
	sb.set_border_width_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	pill.add_theme_stylebox_override("panel", sb)
	pill.set_anchors_preset(Control.PRESET_CENTER)
	pill.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pill.grow_vertical = Control.GROW_DIRECTION_BOTH
	b.add_child(pill)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 2)
	pill.add_child(row)
	var l: Label = ProceduralUIFactory.label("", 14, Palette.UI_WOOD_DEEP)
	l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	row.add_child(l)
	var arrow: IconCanvas = ProceduralUIFactory.icon("up", 16, Palette.MATCHA)
	arrow.name = "Arrow"
	arrow.visible = false
	row.add_child(arrow)
	var k: StringName = kind
	var i: Variant = id
	b.pressed.connect(func() -> void: open_card(k, i))
	add_child(b)
	return {"button": b, "label": l, "arrow": arrow, "kind": kind, "id": id, "pill": pill}


## Buka kartu upgrade stasiun itu.
func open_card(kind: StringName, id: Variant) -> void:
	if game == null:
		return
	game.modals.close_id(&"upgrade_card")
	game.modals.open(&"upgrade_card", {"kind": kind, "id": id})


func _process(delta: float) -> void:
	_t += delta
	if game == null or game.world == null or sim == null:
		return
	var rig: CameraRig = game.world.camera_rig
	var view: Vector2 = get_viewport_rect().size
	var pulse: float = 1.0 if SettingsManager.reduced_motion() else 1.0 + 0.12 * sin(_t * TAU * 1.2)
	for k: Variant in _chips.keys():
		var c: Dictionary = _chips[k]
		var b: Button = c["button"]
		var at: Vector3 = _anchor(c)
		if at == Vector3.INF:
			b.visible = false
			continue
		var s: Vector2 = rig.world_to_screen(at)
		b.visible = s.x > -CHIP_SIZE.x and s.x < view.x + CHIP_SIZE.x and s.y > 0.0 and s.y < view.y
		b.position = s - Vector2(CHIP_SIZE.x * 0.5, CHIP_SIZE.y + LIFT - 24.0)
		var arrow: Control = c["arrow"]
		if arrow.visible:
			arrow.pivot_offset = arrow.size * 0.5
			arrow.scale = Vector2(pulse, pulse)


func _anchor(c: Dictionary) -> Vector3:
	var rig: CameraRig = game.world.camera_rig
	if c["kind"] == &"counter":
		var lane: QueueLane = sim.queue.main_lane()
		if lane == null or lane.floor_id != rig.active_floor:
			return Vector3.INF
		var n: Node3D = game.world.main_counter()
		if n == null:
			return Vector3.INF
		var b: AABB = EquipmentFactory._mesh_bounds(n)
		return n.global_transform * Vector3(b.get_center().x, b.end.y, b.get_center().z)
	var e: EquipmentInstance = sim.equipment.get_inst(int(c["id"]))
	if e == null or not e.placed or e.floor_id != rig.active_floor:
		return Vector3.INF
	return game.world.top_of_iid(e.iid)


## Naik level: chip-nya memantul sebentar (Reduced Motion: tidak).
func _on_level_up(kind: StringName, id: Variant, _level: int, _milestone: bool) -> void:
	if kind != &"station" and kind != &"counter":
		return
	refresh()
	var c: Variant = _chips.get(key_of(kind, id))
	if c is Dictionary and not SettingsManager.reduced_motion():
		ProceduralAnimationSystem.squash_pop((c as Dictionary)["pill"], 1.25, 0.25)
