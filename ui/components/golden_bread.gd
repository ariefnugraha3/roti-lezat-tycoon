class_name GoldenBread
extends CanvasLayer
## Roti Emas yang terbang melintasi bingkai (GDD idle 21.9). Posisinya mengikuti
## sisa waktu terbang di simulasi (`GoldenManager.progress`), jadi ikut berhenti
## saat toko di-pause. Lapisannya di atas lembar bawah (bisa ditangkap selagi
## lembar terbuka), tetapi disembunyikan selama modal pemblokir, Decoration Mode,
## dan Photo mode. Satu ketukan menangkapnya; hadiahnya ditulis di toast.

const SIZE: float = 112.0

var game: GameRoot = null
var sim: SimulationRoot = null
var button: Button = null
var _art: GoldenArt = null
## Lapisan efek koin saat tertangkap.
var _fx: Control = null


func _ready() -> void:
	layer = 21
	name = "GoldenBread"
	button = Button.new()
	button.name = "Golden"
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.custom_minimum_size = Vector2(SIZE, SIZE)
	button.size = Vector2(SIZE, SIZE)
	button.tooltip_text = Tx.t("ui_golden_tip")
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "focus", "disabled"]:
		button.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	button.pressed.connect(_catch)
	add_child(button)
	_art = GoldenArt.new()
	_art.set_anchors_preset(Control.PRESET_FULL_RECT)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(_art)
	button.visible = false
	_fx = Control.new()
	_fx.name = "FX"
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fx)


func _process(_delta: float) -> void:
	if sim == null or game == null:
		return
	var show: bool = sim.golden.is_flying() and game.modals != null and not game.modals.has_blocking() \
		and game.hud != null and not game.hud.decoration_active
	button.visible = show
	if not show:
		return
	var vp: Vector2 = button.get_viewport_rect().size
	var t: float = sim.golden.progress()
	var ltr: bool = sim.golden.flight % 2 == 1
	var band: float = 0.30 + 0.22 * float(posmod(sim.golden.flight * 7, 5)) / 4.0
	var x: float = lerpf(-SIZE * 0.5, vp.x - SIZE * 0.5, t if ltr else 1.0 - t)
	var y: float = vp.y * band + sin(t * TAU * 1.5) * 40.0
	button.position = Vector2(x - SIZE * 0.5, y - SIZE * 0.5)
	_art.phase = t


func _catch() -> void:
	var r: Dictionary = sim.golden.catch()
	if r.is_empty():
		return
	var at: Vector2 = button.position + Vector2(SIZE, SIZE) * 0.5
	button.visible = false
	var id: String = str(r["id"])
	EventBus.notify.emit(1, id, {"amount": Tx.kr(float(r["kr"])), "mult": Tx.mult(float(r["mult"])), "seconds": int(r["seconds"])}, &"bread")
	if id == "golden_kr" and not SettingsManager.reduced_motion():
		FX.coin_pop(_fx, at, float(r["kr"]))
		if game.hud != null:
			game.hud.coin_shower()


## Gambar roti emas: lingkar cahaya yang berdenyut, roti emas bergaris, dan dua
## kilau bintang. Flat: bidang warna polos (cahayanya bidang transparan).
class GoldenArt:
	extends Control
	var phase: float = 0.0:
		set(v):
			phase = v
			queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var s: float = minf(size.x, size.y)
		var pulse: float = 0.5 + 0.5 * sin(phase * TAU * 6.0)
		draw_circle(c, s * (0.40 + 0.05 * pulse), Color(Palette.GOLD_STAR, 0.22))
		draw_circle(c, s * 0.31, Color(Palette.BUTTER_YELLOW, 0.35))
		var loaf := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			var ry: float = s * (0.20 if sin(a) < 0.0 else 0.14)
			loaf.append(c + Vector2(cos(a) * s * 0.27, sin(a) * ry + s * 0.02))
		draw_colored_polygon(loaf, Palette.GOLD_STAR)
		draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.27, s * 0.04), c + Vector2(s * 0.27, s * 0.04),
			c + Vector2(s * 0.25, s * 0.12), c + Vector2(-s * 0.25, s * 0.12)]), Palette.GOLDEN_CRUST)
		for k in 3:
			var x: float = -s * 0.12 + s * 0.12 * float(k)
			draw_line(c + Vector2(x - s * 0.03, -s * 0.10), c + Vector2(x + s * 0.03, -s * 0.01), Palette.FLOUR_WHITE, s * 0.035, true)
		for sp: Vector2 in [Vector2(0.30, -0.26), Vector2(-0.33, 0.20)]:
			var p: Vector2 = c + sp * s
			var r: float = s * (0.07 + 0.03 * pulse)
			draw_colored_polygon(PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.3), p + Vector2(r, 0),
				p + Vector2(r * 0.3, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.3, r * 0.3), p + Vector2(-r, 0),
				p + Vector2(-r * 0.3, -r * 0.3)]), Palette.FLOUR_WHITE)
