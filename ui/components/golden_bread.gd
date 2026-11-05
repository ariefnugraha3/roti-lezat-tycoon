class_name GoldenBread
extends CanvasLayer
## Roti Emas yang terbang melintasi bingkai (GDD idle 21.9). Posisinya mengikuti
## sisa waktu terbang di simulasi (`GoldenManager.progress`), jadi ikut berhenti
## saat toko di-pause. Lapisannya di atas lembar bawah (bisa ditangkap selagi
## lembar terbuka), tetapi disembunyikan selama modal pemblokir, Decoration Mode,
## dan Photo mode. Satu ketukan menangkapnya; hadiahnya ditulis di toast.
## Sesudah roti berhadiah KR, tombol kecil ×2 muncul beberapa detik di tempat
## tangkapan bila iklan berhadiah tersedia (GDD idle 22.3 `golden_double`).

const SIZE: float = 112.0

var game: GameRoot = null
var sim: SimulationRoot = null
var button: Button = null
var _art: GoldenArt = null
## Lapisan efek koin saat tertangkap.
var _fx: Control = null
## Tombol ×2 lewat iklan, KR yang digandakan, dan sisa detik tawarannya.
var double_button: Button = null
var _double_kr: float = 0.0
var _double_left: float = 0.0


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
	double_button = AdButton.make(&"golden_double", Tx.t("ui_golden_double"), "success", 18, 15)
	double_button.pressed.connect(_double)
	add_child(double_button)
	double_button.visible = false


func _process(delta: float) -> void:
	if sim == null or game == null:
		return
	_tick_double(delta)
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
	if id == "golden_kr" and Monetization.can_offer(&"golden_double"):
		_double_kr = float(r["kr"])
		_double_left = float(Monetization.placement(&"golden_double").get("offer_seconds", 8.0))
		var vp: Vector2 = button.get_viewport_rect().size
		var sz: Vector2 = double_button.get_combined_minimum_size()
		double_button.position = Vector2(clampf(at.x - sz.x * 0.5, 16.0, vp.x - sz.x - 16.0), clampf(at.y + SIZE * 0.4, 16.0, vp.y - sz.y - 16.0))


## Tawaran ×2 berjalan dalam detik nyata dan hilang sendiri; disembunyikan juga
## selama modal pemblokir dan Decoration Mode, seperti rotinya.
func _tick_double(delta: float) -> void:
	if _double_left <= 0.0:
		double_button.visible = false
		return
	if not Monetization.busy:
		_double_left -= delta
	AdButton.refresh(double_button)
	var hidden: bool = game.modals != null and game.modals.has_blocking() and not Monetization.busy
	double_button.visible = double_button.visible and not hidden and _double_left > 0.0


## Tonton iklan, lalu KR roti emas itu sekali lagi (REWARD).
func _double() -> void:
	double_button.disabled = true
	var kr: float = _double_kr
	Monetization.show_rewarded(&"golden_double", func(ok: bool) -> void:
		if not is_instance_valid(double_button):
			return
		double_button.disabled = false
		_double_left = 0.0
		double_button.visible = false
		if ok and sim != null and kr > 0.0:
			sim.economy.credit(kr, &"REWARD", &"golden_double", {})
			EventBus.notify.emit(1, "ui_golden_doubled", {"amount": Tx.kr(kr)}, &"bread")
			EventBus.sfx.emit(&"coin_shower", &"")
			if game.hud != null and not SettingsManager.reduced_motion():
				game.hud.coin_shower())


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
		draw_circle(c, s * (0.40 + 0.05 * pulse), Color(Palette.GOLD_STAR, 0.22), true, -1.0, true)
		draw_circle(c, s * 0.31, Color(Palette.BUTTER_YELLOW, 0.35), true, -1.0, true)
		var loaf := PackedVector2Array()
		for i in 24:
			var a: float = TAU * float(i) / 24.0
			var ry: float = s * (0.20 if sin(a) < 0.0 else 0.14)
			loaf.append(c + Vector2(cos(a) * s * 0.27, sin(a) * ry + s * 0.02))
		ProceduralUIFactory.fill_aa(self, loaf, Palette.GOLD_STAR)
		ProceduralUIFactory.fill_aa(self, PackedVector2Array([c + Vector2(-s * 0.27, s * 0.04), c + Vector2(s * 0.27, s * 0.04),
			c + Vector2(s * 0.25, s * 0.12), c + Vector2(-s * 0.25, s * 0.12)]), Palette.GOLDEN_CRUST)
		for k in 3:
			var x: float = -s * 0.12 + s * 0.12 * float(k)
			draw_line(c + Vector2(x - s * 0.03, -s * 0.10), c + Vector2(x + s * 0.03, -s * 0.01), Palette.FLOUR_WHITE, s * 0.035, true)
		for sp: Vector2 in [Vector2(0.30, -0.26), Vector2(-0.33, 0.20)]:
			var p: Vector2 = c + sp * s
			var r: float = s * (0.07 + 0.03 * pulse)
			ProceduralUIFactory.fill_aa(self, PackedVector2Array([p + Vector2(0, -r), p + Vector2(r * 0.3, -r * 0.3), p + Vector2(r, 0),
				p + Vector2(r * 0.3, r * 0.3), p + Vector2(0, r), p + Vector2(-r * 0.3, r * 0.3), p + Vector2(-r, 0),
				p + Vector2(-r * 0.3, -r * 0.3)]), Palette.FLOUR_WHITE)
