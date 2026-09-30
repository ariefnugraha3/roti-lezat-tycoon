class_name OrientationGuard
extends CanvasLayer
## Browser HP dalam posisi tegak (keputusan maintainer 2026-09-30, GDD 12.5,
## 128.3). Game dimainkan landscape, jadi selama HP tegak layar ini menutup
## semuanya, menahan ketukan, dan mem-pause simulasi; begitu HP dimiringkan ia
## hilang sendiri. Di browser yang bisa mengunci orientasi (Chrome Android),
## mengetuknya langsung masuk layar penuh landscape, supaya pemain yang
## mematikan putar otomatis tidak tertahan di sini.
##
## Hanya dipasang GameRoot di browser HP (WebPlatform.is_mobile_web()).

const LAYER: int = 90
const REASON: StringName = &"orientation"
## Satu siklus animasi HP berputar (detik).
const CYCLE: float = 2.6
## Layar ini hanya tampil saat HP tegak, ketika kanvas logis selebar 1280 px
## dikecilkan sekitar 3x agar muat di lebar HP; ukurannya dibuat besar supaya
## tetap terbaca (px logis).
const TITLE_SIZE: int = 96
const BODY_SIZE: int = 56
const HINT_SIZE: int = 46
const TEXT_WIDTH: float = 1080.0

var _root: Control = null
var _phone: PhoneGlyph = null
var _tap_hint: Label = null
var _portrait: bool = false
var _t: float = 0.0


func _init() -> void:
	layer = LAYER
	name = "OrientationGuard"
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.gui_input.connect(_on_input)
	add_child(_root)
	ProceduralUIFactory.apply_theme(_root)
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 56)
	center.add_child(v)
	var art := CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(art)
	_phone = PhoneGlyph.new()
	art.add_child(_phone)
	var title: Label = ProceduralUIFactory.title(Tx.t("ui_rotate_title"), TITLE_SIZE)
	v.add_child(title)
	var body: Label = ProceduralUIFactory.label(Tx.t("ui_rotate_body"), BODY_SIZE, Palette.TEXT)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	v.add_child(body)
	_tap_hint = ProceduralUIFactory.label(Tx.t("ui_rotate_tap"), HINT_SIZE, Palette.TEXT_MUTED)
	_tap_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tap_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tap_hint.custom_minimum_size = Vector2(TEXT_WIDTH, 0)
	_tap_hint.visible = false
	v.add_child(_tap_hint)
	_root.visible = false


func _ready() -> void:
	_tap_hint.visible = WebPlatform.can_lock_landscape()


func _process(delta: float) -> void:
	apply(WebPlatform.is_portrait())
	if not _portrait:
		return
	_t += delta
	_phone.angle = 0.0 if SettingsManager.reduced_motion() else _phone_angle(_t)
	_phone.queue_redraw()


## Tegak: tampil dan pause. Landscape: hilang dan pause dilepas. Dicek tiap
## frame karena PauseManager.clear_all() (masuk gameplay) ikut menghapus alasannya.
func apply(portrait: bool) -> void:
	_portrait = portrait
	_root.visible = portrait
	if portrait and not PauseManager.has(REASON):
		PauseManager.push(REASON)
	elif not portrait and PauseManager.has(REASON):
		PauseManager.clear(REASON)


func is_blocking() -> bool:
	return _portrait


## HP tegak diam, berputar ke samping, diam sebentar, lalu kembali (radian).
static func _phone_angle(t: float) -> float:
	var k: float = fposmod(t, CYCLE) / CYCLE
	var turn: float = smoothstep(0.15, 0.45, k) * (1.0 - smoothstep(0.80, 0.98, k))
	return -PI * 0.5 * turn


## Ketukan dilepas: di Chrome Android langsung layar penuh landscape.
func _on_input(event: InputEvent) -> void:
	var released: bool = (event is InputEventScreenTouch and not (event as InputEventScreenTouch).pressed) \
		or (event is InputEventMouseButton and not (event as InputEventMouseButton).pressed)
	if released and _tap_hint.visible:
		WebPlatform.enter_fullscreen_landscape()


func _exit_tree() -> void:
	if PauseManager.has(REASON):
		PauseManager.clear(REASON)


## HP bergaya chibi (badan membulat, layar, tombol) yang bisa diputar, digambar
## di `_draw()` tanpa aset (GDD 12.2).
class PhoneGlyph extends Control:
	const K: float = 2.6
	const W: float = 96.0 * K
	const H: float = 168.0 * K
	var angle: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(H + 24.0 * K, H + 24.0 * K)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		draw_set_transform(c, angle, Vector2.ONE)
		var body := Rect2(Vector2(-W * 0.5, -H * 0.5), Vector2(W, H))
		draw_colored_polygon(ProceduralUIFactory.rounded_points(body.grow(4.0 * K), 22.0 * K), Palette.CARAMEL)
		draw_colored_polygon(ProceduralUIFactory.rounded_points(body, 18.0 * K), Palette.UI_WOOD)
		var screen := Rect2(body.position + Vector2(9.0, 18.0) * K, body.size - Vector2(18.0, 40.0) * K)
		draw_colored_polygon(ProceduralUIFactory.rounded_points(screen, 8.0 * K), Palette.BUTTER_YELLOW)
		draw_circle(Vector2(0.0, body.end.y - 11.0 * K), 5.0 * K, Palette.BUTTER_YELLOW)
		# Roti tawar di layar tetap tegak saat HP berputar: isi game yang landscape.
		draw_set_transform(c + screen.get_center().rotated(angle), 0.0, Vector2.ONE)
		var loaf := Rect2(Vector2(-24.0, -13.0) * K, Vector2(48.0, 26.0) * K)
		draw_colored_polygon(ProceduralUIFactory.rounded_points(loaf, 12.0 * K), Palette.GOLDEN_CRUST)
		for i in 3:
			var x: float = loaf.position.x + (13.0 + 11.0 * float(i)) * K
			draw_line(Vector2(x, loaf.position.y + 6.0 * K), Vector2(x + 5.0 * K, loaf.position.y + 12.0 * K), Palette.CARAMEL, 2.5 * K, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
