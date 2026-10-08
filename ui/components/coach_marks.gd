class_name CoachMarks
extends Control
## Tur sorotan tutorial (GDD 27.5, 88.1; keputusan maintainer 2026-10-07): layar
## diredupkan kecuali bagian yang sedang dijelaskan, dengan balon penjelasan dan
## tombol Next. Langkah terakhir tidak punya Next bila pemain harus mengetuk
## sasarannya sendiri (mis. Make); tur yang hanya menjelaskan berakhir dengan
## Got it. Bagian yang disorot tetap bisa diketuk, bagian lain tertutup lapisan
## redup. Sasaran dicari ulang tiap frame, jadi tur tetap benar walau isi
## layarnya dibangun ulang atau sasarannya bergerak. Sasaran boleh Control atau
## Rect2 di koordinat kanvas (mis. model di dunia, dari WorldView). Flat: warna
## polos tanpa bayangan.

signal finished

const DIM: Color = Color(0.17, 0.11, 0.06, 0.55)
## Jarak sorotan dari tepi sasaran, tebal cincin, dan jarak balon (px).
const PAD: float = 8.0
const RING_PX: int = 4
const GAP: float = 14.0
const EDGE: float = 12.0
const CALLOUT_TEXT_W: float = 380.0
const PERIOD: float = 0.9

## [{targets: Callable -> Array (Control atau Rect2), key: String, next: bool,
##   enter: Callable (opsional, dipanggil saat langkah dimulai, mis. pindah tab)}]
var _steps: Array[Dictionary] = []
var _i: int = 0
var _blockers: Array[ColorRect] = []
var _ring: Control = null
var _callout: PanelContainer = null
var _text: Label = null
var _count: Label = null
var _skip: Button = null
var _next: Button = null
var _hole: Rect2 = Rect2()
var _t: float = 0.0
var _ring_box := StyleBoxFlat.new()


func _init() -> void:
	name = "CoachMarks"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


## Mulai tur. Setiap langkah: `targets` mengembalikan Control atau Rect2 yang
## disorot (gabungan kotaknya), `key` teks penjelasan, `next` = ada tombol Next
## (pada langkah terakhir: Got it).
func setup(steps: Array[Dictionary]) -> void:
	_steps = steps
	_i = 0
	_build()
	_show_step()


func index() -> int:
	return _i


func step_count() -> int:
	return _steps.size()


## Kotak yang sedang disorot (koordinat lokal lapisan ini); kosong bila
## sasarannya tidak terlihat.
func hole() -> Rect2:
	return _hole


func next_button() -> Button:
	return _next


func skip_button() -> Button:
	return _skip


func callout() -> PanelContainer:
	return _callout


## Teks penjelasan langkah saat ini.
func text() -> String:
	return _text.text if _text != null else ""


## Langkah berikutnya; melewati langkah terakhir mengakhiri tur.
func next_step() -> void:
	if _i + 1 >= _steps.size():
		_finish()
		return
	_i += 1
	_show_step()


## Akhiri tur sekarang (Skip, Back).
func finish() -> void:
	_finish()


func _finish() -> void:
	if is_queued_for_deletion():
		return
	finished.emit()
	queue_free()


func _build() -> void:
	for i in 4:
		var b := ColorRect.new()
		b.name = "Dim%d" % i
		b.color = DIM
		b.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(b)
		_blockers.append(b)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_ring_box.draw_center = false
	_ring_box.set_border_width_all(RING_PX)
	_ring_box.anti_aliasing = true
	_callout = PanelContainer.new()
	_callout.name = "Callout"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.BUTTER_YELLOW, 20, true)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_callout.add_theme_stylebox_override("panel", sb)
	_callout.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_callout)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_callout.add_child(row)
	var badge: PanelContainer = ProceduralUIFactory.badge("chef", Palette.FLOUR_WHITE, Palette.UI_WOOD, 44)
	badge.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(badge)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	row.add_child(col)
	_text = ProceduralUIFactory.label("", 18, Palette.UI_WOOD_DEEP)
	_text.name = "Text"
	_text.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.custom_minimum_size = Vector2(CALLOUT_TEXT_W, 0.0)
	col.add_child(_text)
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 10)
	col.add_child(nav)
	_count = ProceduralUIFactory.label("", 14, Palette.TEXT_MUTED)
	_count.name = "Count"
	_count.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(_count)
	_skip = ProceduralUIFactory.button(Tx.t("ui_tour_skip"), "ghost")
	_skip.name = "Skip"
	_skip.pressed.connect(_finish)
	nav.add_child(_skip)
	_next = ProceduralUIFactory.button(Tx.t("ui_tour_next"), "primary")
	_next.name = "Next"
	_next.pressed.connect(next_step)
	nav.add_child(_next)


func _show_step() -> void:
	var s: Dictionary = _steps[_i]
	var enter: Variant = s.get("enter")
	if enter is Callable and (enter as Callable).is_valid():
		(enter as Callable).call()
	var has_next: bool = bool(s.get("next", true))
	var last: bool = _i == _steps.size() - 1
	_text.text = Tx.t(str(s["key"]))
	# Satu langkah saja: tanpa nomor; Skip hanya bila tidak ada Got it.
	_count.text = Tx.t("ui_tour_count", {"n": _i + 1, "total": _steps.size()}) if _steps.size() > 1 else ""
	_skip.visible = _steps.size() > 1 or not has_next
	_next.visible = has_next
	_next.text = Tx.t("ui_tutorial_got_it") if last else Tx.t("ui_tour_next")
	_callout.reset_size()
	_layout()


func _process(delta: float) -> void:
	_t += delta
	_layout()
	_ring.queue_redraw()


## Kotak gabungan sasaran langkah ini (lokal), diberi jarak PAD. Rect2 kosong
## bila tidak ada sasaran yang terlihat.
func _target_rect() -> Rect2:
	var r := Rect2()
	var any: bool = false
	var fn: Callable = _steps[_i]["targets"]
	var inv: Transform2D = get_global_transform().affine_inverse()
	for c: Variant in fn.call():
		var g := Rect2()
		if c is Rect2:
			var rr: Rect2 = c
			if not rr.has_area():
				continue
			g = inv * rr
		else:
			var ctl: Control = c as Control
			if ctl == null or not is_instance_valid(ctl) or not ctl.is_visible_in_tree():
				continue
			g = inv * ctl.get_global_rect()
		r = g if not any else r.merge(g)
		any = true
	return r.grow(PAD) if any else Rect2()


func _layout() -> void:
	if _steps.is_empty() or _callout == null:
		return
	var view := Rect2(Vector2.ZERO, size)
	var target: Rect2 = _target_rect()
	_hole = target.intersection(view) if target.has_area() else Rect2()
	# Tepi di piksel utuh: sasaran dunia jatuh di pecahan piksel, dan lapisan
	# redup yang bertemu di pecahan piksel menyisakan garis terang.
	if _hole.has_area():
		var p0: Vector2 = _hole.position.floor()
		_hole = Rect2(p0, _hole.end.ceil() - p0)
	var h: Rect2 = _hole if _hole.has_area() else Rect2(size * 0.5, Vector2.ZERO)
	var parts: Array[Rect2] = [
		Rect2(0.0, 0.0, size.x, h.position.y),
		Rect2(0.0, h.end.y, size.x, size.y - h.end.y),
		Rect2(0.0, h.position.y, h.position.x, h.size.y),
		Rect2(h.end.x, h.position.y, size.x - h.end.x, h.size.y),
	]
	for i in 4:
		_blockers[i].position = parts[i].position
		_blockers[i].size = Vector2(maxf(parts[i].size.x, 0.0), maxf(parts[i].size.y, 0.0))
	_ring.position = Vector2.ZERO
	_ring.size = size
	# Balon di bawah sorotan bila muat, selain itu di atasnya, lalu di samping.
	# Tanpa sasaran yang terlihat, balonnya di tengah layar.
	var cs: Vector2 = _callout.get_combined_minimum_size()
	var pos := (size - cs) * 0.5
	if _hole.has_area():
		pos = Vector2(h.get_center().x - cs.x * 0.5, h.end.y + GAP)
		if pos.y + cs.y > size.y - EDGE:
			pos.y = h.position.y - GAP - cs.y
			if pos.y < EDGE:
				pos = Vector2(h.end.x + GAP, h.get_center().y - cs.y * 0.5)
				if pos.x + cs.x > size.x - EDGE:
					pos.x = h.position.x - GAP - cs.x
	pos.x = clampf(pos.x, EDGE, maxf(EDGE, size.x - cs.x - EDGE))
	pos.y = clampf(pos.y, EDGE, maxf(EDGE, size.y - cs.y - EDGE))
	_callout.position = pos
	_callout.size = cs


func _draw_ring() -> void:
	if not _hole.has_area():
		return
	var k: float = 0.5 if SettingsManager.reduced_motion() else 0.5 - 0.5 * cos(TAU * _t / PERIOD)
	_ring_box.border_color = Color(Palette.HONEY, 1.0 - 0.45 * k)
	_ring_box.set_corner_radius_all(16)
	var grow: float = 2.0 * k
	_ring.draw_style_box(_ring_box, _hole.grow(grow))
