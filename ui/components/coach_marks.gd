class_name CoachMarks
extends Control
## Tur sorotan tutorial (GDD 27.5, 88.1; keputusan maintainer 2026-10-07): layar
## diredupkan kecuali bagian yang sedang dijelaskan, dengan balon penjelasan dan
## tombol Next. Langkah terakhir tidak punya Next bila pemain harus mengetuk
## sasarannya sendiri (mis. Make); tur yang hanya menjelaskan berakhir dengan
## Got it. Bagian yang disorot tetap bisa diketuk, bagian lain tertutup lapisan
## redup yang lubangnya mengikuti bentuk sasaran (persegi membulat atau kapsul)
## dengan tepi yang memudar lembut (keputusan maintainer 2026-11-05: bukan
## lubang kotak bersudut tajam). Sasaran dicari ulang tiap frame, jadi tur tetap benar walau isi
## layarnya dibangun ulang atau sasarannya bergerak. Sasaran boleh Control atau
## Rect2 di koordinat kanvas (mis. model di dunia, dari WorldView). Langkah
## yang meminta ketukan (`flash`, TutorialGuide) membuat sasarannya berkedip
## terang. Flat: warna polos tanpa bayangan.

signal finished

const DIM: Color = Color(0.17, 0.11, 0.06, 0.55)
## Lebar pudar tepi lubang (px) dan jari-jari sudut lubang terbesar: chip dan
## tombol menjadi kapsul, panel besar persegi membulat.
const FEATHER: float = 30.0
const MAX_RADIUS: float = 32.0
## Jarak sorotan dari tepi sasaran, tebal cincin, dan jarak balon (px).
const PAD: float = 8.0
const RING_PX: int = 4
const GAP: float = 14.0
const EDGE: float = 12.0
const CALLOUT_TEXT_W: float = 380.0
const PERIOD: float = 0.9
## Kilau kedip di atas sasaran yang harus diketuk (keputusan maintainer
## 2026-11-02): ritmenya sama dengan kedip model di dunia
## (`WorldView.blink_alpha`), alfanya dikali FLASH_ALPHA supaya tulisan tombol
## tetap terbaca di puncak kedip.
const FLASH_ALPHA: float = 0.75
const FLASH_RADIUS: int = 16

## [{targets: Callable -> Array (Control atau Rect2), key: String, next: bool,
##   enter: Callable (opsional, dipanggil saat langkah dimulai, mis. pindah tab),
##   flash: bool (opsional, sasaran berkedip), skip_key: String (opsional, teks
##   tombol Skip)}]
var _steps: Array[Dictionary] = []
var _i: int = 0
var _dim: Dim = null
var _ring: Control = null
var _callout: PanelContainer = null
var _text: Label = null
var _count: Label = null
var _skip: Button = null
var _next: Button = null
var _hole: Rect2 = Rect2()
## Sasaran tanpa jarak PAD (lokal), tempat kilau kedip digambar.
var _target: Rect2 = Rect2()
var _t: float = 0.0
var _ring_box := StyleBoxFlat.new()
var _flash_box := StyleBoxFlat.new()


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


## Ganti teks penjelasan langkah ini (mis. panduan yang maju ke tombol
## berikutnya di lembar yang baru terbuka).
func set_text(key: String) -> void:
	var t: String = Tx.t(key)
	if _text == null or _text.text == t:
		return
	_text.text = t
	_callout.reset_size()
	_layout()


## Alfa kilau kedip di atas sasaran saat ini; 0 bila langkah ini tidak berkedip
## atau sasarannya tidak terlihat.
func flash_alpha() -> float:
	if _steps.is_empty() or not bool(_steps[_i].get("flash", false)) or not _target.has_area():
		return 0.0
	return WorldView.blink_alpha(_t, SettingsManager.reduced_motion()) * FLASH_ALPHA


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
	_dim = Dim.new()
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_dim)
	_ring = Control.new()
	_ring.name = "Ring"
	_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ring.draw.connect(_draw_ring)
	add_child(_ring)
	_ring_box.draw_center = false
	_ring_box.set_border_width_all(RING_PX)
	_ring_box.anti_aliasing = true
	_flash_box.set_corner_radius_all(FLASH_RADIUS)
	_flash_box.anti_aliasing = true
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
	_skip.text = Tx.t(str(s.get("skip_key", "ui_tour_skip")))
	_t = 0.0
	_next.visible = has_next
	_next.text = Tx.t("ui_tutorial_got_it") if last else Tx.t("ui_tour_next")
	_callout.reset_size()
	_layout()


func _process(delta: float) -> void:
	_t += delta
	_layout()
	_ring.queue_redraw()


## Kotak gabungan sasaran langkah ini (lokal), tanpa jarak PAD. Rect2 kosong
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
	return r if any else Rect2()


func _layout() -> void:
	if _steps.is_empty() or _callout == null:
		return
	var view := Rect2(Vector2.ZERO, size)
	var target: Rect2 = _target_rect()
	_target = target.intersection(view) if target.has_area() else Rect2()
	_hole = target.grow(PAD).intersection(view) if target.has_area() else Rect2()
	# Tepi di piksel utuh: sasaran dunia jatuh di pecahan piksel, dan lapisan
	# redup yang bertemu di pecahan piksel menyisakan garis terang.
	if _hole.has_area():
		var p0: Vector2 = _hole.position.floor()
		_hole = Rect2(p0, _hole.end.ceil() - p0)
	var h: Rect2 = _hole if _hole.has_area() else Rect2(size * 0.5, Vector2.ZERO)
	_dim.set_hole(_hole, hole_radius())
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


## Jari-jari sudut lubang: setengah sisi pendeknya (kapsul), paling besar
## MAX_RADIUS.
func hole_radius() -> float:
	return minf(minf(_hole.size.x, _hole.size.y) * 0.5, MAX_RADIUS) if _hole.has_area() else 0.0


## Lapisan redup (tes).
func dim() -> Dim:
	return _dim


func _draw_ring() -> void:
	if not _hole.has_area():
		return
	var r: float = hole_radius()
	var flash: float = flash_alpha()
	if flash > 0.0:
		_flash_box.bg_color = Color(Palette.FLOUR_WHITE, flash)
		_flash_box.set_corner_radius_all(int(maxf(4.0, r - PAD)))
		_ring.draw_style_box(_flash_box, _target)
	var k: float = 0.5 if SettingsManager.reduced_motion() else 0.5 - 0.5 * cos(TAU * _t / PERIOD)
	_ring_box.border_color = Color(Palette.HONEY, 1.0 - 0.45 * k)
	var grow: float = 2.0 * k
	_ring_box.set_corner_radius_all(int(r + grow))
	_ring.draw_style_box(_ring_box, _hole.grow(grow))


## Lapisan redup satu bidang: gelap rata di luar, memudar ke bening sepanjang
## FEATHER px menuju lubang yang berbentuk persegi membulat. Digambar sebagai
## tiga keliling persegi membulat dengan pusat sudut yang sama (lubang, tepi
## pudar, dan keliling jauh di luar layar) berwarna per titik, tanpa shader.
## Ketukan di dalam lubang diteruskan ke sasarannya; di luar lubang ditahan.
class Dim:
	extends Control

	## Titik per sudut membulat.
	const CORNER_STEPS: int = 10
	var hole: Rect2 = Rect2()
	var radius: float = 0.0

	func _init() -> void:
		name = "Dim"
		mouse_filter = Control.MOUSE_FILTER_STOP

	func set_hole(h: Rect2, r: float) -> void:
		if h == hole and is_equal_approx(r, radius):
			return
		hole = h
		radius = r
		queue_redraw()

	## Ketukan di titik ini ditahan (di luar lubang).
	func blocks(p: Vector2) -> bool:
		return _has_point(p)

	func _has_point(p: Vector2) -> bool:
		return Rect2(Vector2.ZERO, size).has_point(p) and not (hole.has_area() and hole.has_point(p))

	func _draw() -> void:
		if not hole.has_area():
			draw_rect(Rect2(Vector2.ZERO, size), DIM)
			return
		var far: float = (size.length() + FEATHER) * 2.0
		var rings: Array[PackedVector2Array] = [_ring(0.0), _ring(FEATHER), _ring(FEATHER + far)]
		var alphas: Array[float] = [0.0, DIM.a, DIM.a]
		var n: int = rings[0].size()
		var pts := PackedVector2Array()
		var cols := PackedColorArray()
		for k in 3:
			pts.append_array(rings[k])
			for i in n:
				cols.append(Color(DIM, alphas[k]))
		var idx := PackedInt32Array()
		for k in 2:
			var a: int = k * n
			var b: int = (k + 1) * n
			for i in n:
				var j: int = (i + 1) % n
				idx.append_array([a + i, b + i, b + j, a + i, b + j, a + j])
		RenderingServer.canvas_item_add_triangle_array(get_canvas_item(), idx, pts, cols)

	## Keliling lubang yang digeser `d` px keluar. Pusat sudutnya tetap, jadi
	## setiap titik keliling luar sejajar titik yang sama di keliling dalam.
	func _ring(d: float) -> PackedVector2Array:
		var r: float = minf(radius, minf(hole.size.x, hole.size.y) * 0.5)
		var c: Array[Vector2] = [hole.position + Vector2(r, r), Vector2(hole.end.x - r, hole.position.y + r),
			hole.end - Vector2(r, r), Vector2(hole.position.x + r, hole.end.y - r)]
		var out := PackedVector2Array()
		for q in 4:
			var a0: float = PI + float(q) * PI * 0.5
			for s in CORNER_STEPS + 1:
				var a: float = a0 + PI * 0.5 * float(s) / float(CORNER_STEPS)
				out.append(c[q] + Vector2(cos(a), sin(a)) * (r + d))
		return out
