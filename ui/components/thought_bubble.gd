class_name ThoughtBubble
extends Control
## Gelembung pikiran karakter pemain saat toko sepi (GDD 31.7, 127.12): panel
## awan krem dengan tiga lingkaran kecil yang menunjuk ke kepala. Digambar di
## ruang layar supaya teks selalu tajam dan terbaca di semua zoom, mengikuti
## posisi kepala tiap frame, dan tidak pernah menangkap ketukan.

const MAX_TEXT_WIDTH: float = 250.0
const FONT_SIZE: int = 17
## Jarak dasar panel ke ujung ekor (px) dan jari-jari tiga lingkaran ekor.
const TAIL_LENGTH: float = 40.0
const TAIL_RADII: Array[float] = [8.0, 5.5, 3.5]
const EDGE_MARGIN: float = 12.0
const FADE_SECONDS: float = 0.18

var _panel: PanelContainer = null
var _label: Label = null
var _style: StyleBoxFlat = null
var _key: String = ""
var _params: Dictionary = {}
var _anchor: Vector2 = Vector2.ZERO
var _tween: Tween = null


func _init() -> void:
	name = "ThoughtBubble"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	modulate.a = 0.0
	visible = false
	_style = ProceduralUIFactory.panel(Palette.PARCHMENT, 18, true)
	_style.border_color = Color(Palette.UI_WOOD, 0.35)
	_style.set_content_margin_all(10.0)
	_panel = PanelContainer.new()
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_theme_stylebox_override("panel", _style)
	add_child(_panel)
	_label = ProceduralUIFactory.label("", FONT_SIZE, Palette.TEXT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_panel.add_child(_label)


## Kunci pikiran untuk lama toko sepi `quiet_seconds` (detik nyata), atau ""
## di sela-sela: tiap pikiran tampil `thought_show_seconds` detik (GDD 31.7).
static func key_for(quiet_seconds: float) -> String:
	var after: Array = DataRegistry.bal("presentation.thought_after_seconds")
	var show_for: float = DataRegistry.balf("presentation.thought_show_seconds")
	for i in range(after.size() - 1, -1, -1):
		var at: float = float(after[i])
		if quiet_seconds >= at:
			return DataRegistry.THOUGHT_KEYS[i] if quiet_seconds < at + show_for else ""
	return ""


func current_key() -> String:
	return _key


func text() -> String:
	return _label.text


func is_showing() -> bool:
	return visible and _key != ""


## Kotak awan teksnya di layar (untuk sorotan tutorial), atau Rect2() bila tidak
## tampil.
func panel_rect() -> Rect2:
	return _panel.get_global_rect() if is_showing() else Rect2()


## Tampilkan pikiran `key` (teks dari katalog string, dengan `params`). Pikiran
## baru muncul dengan pop kecil; memanggil ulang dengan kunci dan parameter yang
## sama tidak berbuat apa-apa.
func show_key(key: String, params: Dictionary = {}) -> void:
	if key == _key and params == _params and visible:
		return
	_key = key
	_params = params
	# Baris dibungkus manual agar ukuran panel selalu pasti (autowrap Label
	# belum punya lebar saat pertama kali diukur).
	_label.text = _wrap(Tx.t(key, params), _label.get_theme_font("font"), _label.get_theme_font_size("font_size"), MAX_TEXT_WIDTH)
	_panel.reset_size()
	visible = true
	_fade_to(1.0)
	_layout()
	if not SettingsManager.reduced_motion():
		_panel.scale = Vector2(0.85, 0.85)
		if is_inside_tree():
			var pop: Tween = create_tween()
			pop.tween_property(_panel, "scale", Vector2.ONE, 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		else:
			_panel.scale = Vector2.ONE


## Pecah teks per kata menjadi baris-baris selebar paling banyak `max_w` piksel.
static func _wrap(s: String, font: Font, font_size: int, max_w: float) -> String:
	var lines: PackedStringArray = PackedStringArray()
	var line: String = ""
	for word: String in s.split(" ", false):
		var candidate: String = word if line == "" else line + " " + word
		if line != "" and font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x > max_w:
			lines.append(line)
			line = word
		else:
			line = candidate
	if line != "":
		lines.append(line)
	return "\n".join(lines)


func hide_bubble() -> void:
	if _key == "" and not visible:
		return
	_key = ""
	_fade_to(0.0)


## Ujung ekor gelembung menunjuk titik layar ini (biasanya di atas kepala).
func point_at(screen_pos: Vector2) -> void:
	if screen_pos.distance_squared_to(_anchor) < 0.25:
		return
	_anchor = screen_pos
	_layout()


func _layout() -> void:
	var sz: Vector2 = _panel.get_combined_minimum_size()
	_panel.size = sz
	_panel.pivot_offset = sz * Vector2(0.5, 1.0)
	var view: Vector2 = get_viewport_rect().size if is_inside_tree() else Vector2(1280.0, 720.0)
	var pos := Vector2(_anchor.x - sz.x * 0.5, _anchor.y - TAIL_LENGTH - sz.y)
	pos.x = clampf(pos.x, EDGE_MARGIN, maxf(EDGE_MARGIN, view.x - sz.x - EDGE_MARGIN))
	pos.y = clampf(pos.y, EDGE_MARGIN, maxf(EDGE_MARGIN, view.y - sz.y - EDGE_MARGIN))
	_panel.position = pos
	queue_redraw()


func _draw() -> void:
	# Tanpa ekor bila panel terpaksa digeser ke bawah titik jangkar (tepi layar).
	if _key == "" or _anchor.y < _panel.position.y + _panel.size.y + 6.0:
		return
	# Tiga lingkaran awan dari dasar panel ke kepala, makin kecil.
	var base := Vector2(clampf(_anchor.x, _panel.position.x + 18.0, _panel.position.x + _panel.size.x - 18.0),
		_panel.position.y + _panel.size.y)
	for i in TAIL_RADII.size():
		var t: float = (float(i) + 0.8) / (float(TAIL_RADII.size()) + 0.3)
		var c: Vector2 = base.lerp(_anchor, t)
		if not ProceduralUIFactory.flat_style:
			draw_circle(c, TAIL_RADII[i] + 1.5, Color(Palette.UI_WOOD, 0.35))
		draw_circle(c, TAIL_RADII[i], Palette.PARCHMENT)


func _fade_to(alpha: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if not is_inside_tree():
		modulate.a = alpha
		visible = alpha > 0.0
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, FADE_SECONDS)
	if alpha <= 0.0:
		_tween.tween_callback(func() -> void: visible = false)
