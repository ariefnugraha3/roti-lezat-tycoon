class_name RotiFoodButton
extends Control
## Tombol RotiFood di HUD (GDD 7, 22; keputusan maintainer 2026-10-02).
##
## Pemain kadang tidak sadar ada pesanan RotiFood, jadi tombolnya "berdering"
## selama ada pesanan yang BELUM DIKEMAS: mukanya hijau, lencana merah di
## pojoknya menghitung pesanan itu, dan ia bergetar seperti ponsel, membesar
## sesaat, lalu memancarkan lingkaran gelombang, berulang tiap RING_PERIOD detik
## nyata. Pesanan baru langsung memicu dering. Bila driver sudah menunggu
## pesanan yang belum dikemas, tombolnya merah dan berdering dua kali lebih
## sering. Pesanan yang sudah dikemas tidak butuh tindakan, jadi tidak membuatnya
## berdering. Reduced Motion: tanpa getar, denyut, dan gelombang; warna dan
## lencana tetap memberi tahu (ikon + angka + warna, GDD 130.4).

signal pressed

const BUTTON_SIZE: float = 56.0
## Jeda antar-dering (detik nyata): biasa, dan saat driver sudah menunggu.
const RING_PERIOD: float = 2.4
const URGENT_PERIOD: float = 1.2
## Getar: lama, ayunan per detik, dan sudut terbesar (radian, ~12 derajat).
const BUZZ_TIME: float = 0.55
const BUZZ_HZ: float = 7.0
const BUZZ_ANGLE: float = 0.21
## Membesar sesaat di awal dering.
const POP_TIME: float = 0.32
const POP_SCALE: float = 0.16
## Lingkaran gelombang: lama, pertambahan jari-jari (px), dan tebal garis.
const RIPPLE_TIME: float = 0.9
const RIPPLE_GROW: float = 24.0
const RIPPLE_WIDTH: float = 6.0

var button: Button = null
var _body: Control = null
var _badge: PanelContainer = null
var _count: Label = null
var _waiting: int = 0
var _urgent: bool = false
## Detik sejak dering terakhir dimulai; negatif = tidak berdering.
var _ring_t: float = -1.0
## Progres lingkaran gelombang 0..1; negatif = tidak ada.
var _ripple: float = -1.0


func _init() -> void:
	name = "RotiFoodButton"
	custom_minimum_size = Vector2(BUTTON_SIZE + 8.0, BUTTON_SIZE + 8.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Badan yang bergetar; gelombangnya digambar di belakangnya oleh node ini.
	_body = Control.new()
	_body.name = "Body"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	button = ProceduralUIFactory.icon_button("bag", Tx.t("ui_rotifood"), "secondary", 30, Palette.OJOL_GREEN)
	button.name = "Open"
	button.custom_minimum_size = Vector2(BUTTON_SIZE, BUTTON_SIZE)
	button.size = button.custom_minimum_size
	button.pressed.connect(func() -> void: pressed.emit())
	_body.add_child(button)
	_badge = PanelContainer.new()
	_badge.name = "Count"
	_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Palette.DANGER
	sb.set_corner_radius_all(14)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.border_color = Palette.FLOUR_WHITE
	sb.set_border_width_all(2)
	sb.content_margin_left = 7.0
	sb.content_margin_right = 7.0
	sb.content_margin_top = 0.0
	sb.content_margin_bottom = 1.0
	_badge.add_theme_stylebox_override("panel", sb)
	_badge.custom_minimum_size = Vector2(26, 26)
	_count = ProceduralUIFactory.label("", 14, Palette.FLOUR_WHITE)
	_count.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_badge.add_child(_count)
	_badge.visible = false
	_body.add_child(_badge)
	resized.connect(_layout)
	_badge.resized.connect(_layout)


## Jumlah pesanan yang belum dikemas dan apakah driver sudah menunggu salah satunya.
func set_orders(waiting: int, urgent: bool) -> void:
	var n: int = maxi(waiting, 0)
	var u: bool = urgent and n > 0
	if n == _waiting and u == _urgent:
		return
	var ring: bool = n > _waiting or (u and not _urgent)
	_waiting = n
	_urgent = u
	_apply_look()
	if _waiting == 0:
		_ring_t = -1.0
		_rest()
	elif ring:
		ring_now()


## Mulai dering sekarang juga (pesanan baru).
func ring_now() -> void:
	if _waiting > 0:
		_ring_t = 0.0


func waiting() -> int:
	return _waiting


func is_urgent() -> bool:
	return _urgent


func is_ringing() -> bool:
	return _waiting > 0 and _ring_t >= 0.0


func badge_text() -> String:
	return _count.text if _badge.visible else ""


func body() -> Control:
	return _body


func ripple() -> float:
	return _ripple


func _apply_look() -> void:
	var kind: String = "danger" if _urgent else ("success" if _waiting > 0 else "secondary")
	ProceduralUIFactory.apply_kind(button, kind)
	var ink: Color = ProceduralUIFactory.kind_colors(kind)["ink"]
	(button.get_meta("icon") as IconCanvas).configure("bag", 30.0, Palette.OJOL_GREEN if kind == "secondary" else ink)
	_badge.visible = _waiting > 0
	_count.text = str(_waiting) if _waiting < 10 else "9+"
	_layout()


## Lencana di pojok kanan atas tombol, tetap di dalam bantalan panel (juga saat
## tombol membesar), jadi tidak terpotong tepi layar.
func _layout() -> void:
	_body.size = size
	_body.pivot_offset = size * 0.5
	button.size = button.custom_minimum_size
	button.position = (size - button.size) * 0.5
	_badge.size = _badge.get_combined_minimum_size()
	_badge.position = Vector2(size.x - _badge.size.x + 2.0, button.position.y - 6.0)


func _process(delta: float) -> void:
	if _ring_t < 0.0:
		return
	if SettingsManager.reduced_motion() or not is_visible_in_tree():
		_rest()
		return
	var period: float = URGENT_PERIOD if _urgent else RING_PERIOD
	_ring_t = fposmod(_ring_t + delta, period)
	var u: float = _ring_t
	var rot: float = 0.0
	if u < BUZZ_TIME:
		rot = sin(u * TAU * BUZZ_HZ) * BUZZ_ANGLE * (1.0 - u / BUZZ_TIME)
	var k: float = 1.0
	if u < POP_TIME:
		k = 1.0 + POP_SCALE * sin(PI * u / POP_TIME)
	_body.rotation = rot
	_body.scale = Vector2(k, k)
	var was: float = _ripple
	_ripple = u / RIPPLE_TIME if u < RIPPLE_TIME else -1.0
	if _ripple >= 0.0 or was >= 0.0:
		queue_redraw()


## Kembali diam: tanpa getar, ukuran normal, tanpa gelombang.
func _rest() -> void:
	_body.rotation = 0.0
	_body.scale = Vector2.ONE
	if _ripple >= 0.0:
		_ripple = -1.0
		queue_redraw()


func _draw() -> void:
	if _ripple < 0.0:
		return
	var col: Color = Palette.DANGER if _urgent else Palette.OJOL_GREEN
	var fade: float = 1.0 - _ripple
	var r: float = BUTTON_SIZE * 0.5 + 2.0 + RIPPLE_GROW * _ripple
	draw_arc(size * 0.5, r, 0.0, TAU, 48, Color(col, 0.95 * fade), RIPPLE_WIDTH * (1.0 - 0.6 * _ripple), true)
