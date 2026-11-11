class_name StartScene
extends Control
## Halaman start (GDD idle 19 no. 21, Seksi 20 no. 105-106): Crumbtown dilihat
## dari meja kafe di seberang jalan. Langit dengan awan yang bergeser pelan,
## siluet kota di kejauhan, toko roti dua lantai di tengah (papan namanya
## bertuliskan nama toko pemain), trotoar tempat tombol "Tap to Start", dan
## taplak gingham berisi roti di depan.
##
## Siang dan malam mengikuti jam perangkat (Seksi 20 no. 106): siang (06.00 -
## 17.59) langit biru muda dengan matahari pucat dan semua lampu mati; malam
## langit biru tua dengan bulan dan bintang, warna dunia meredup kebiruan, dan
## lampu menyala: jendela toko dan kota, lentera, lampu papan nama, lampu
## jalan, serta cahaya hangat di trotoar. Diperiksa ulang tiap 30 detik.
##
## Gaya flat (v3.1 130.6): bidang warna polos tanpa garis tepi, bayangan, atau
## gradasi; cahaya berupa bidang transparan polos. Semua digambar di `_draw()`
## (v3.1 4.3, 111). Lapisan langit dan uap cerobong beranimasi; lapisan jalan
## dan toko hanya digambar ulang saat ukuran atau waktunya berubah. Reduced
## Motion = diam.
##
## `show_front` = false memakai adegan ini sebagai latar saja (popup toko baru,
## layar loading): tanpa logo dan tombol.

## Tata letak selesai dihitung ulang (ukuran berubah); `shop_top()` sudah baru.
signal laid_out
## Siang berganti malam atau sebaliknya.
signal night_changed(is_night: bool)

## Malam menurut jam perangkat: mulai jam ini sampai sebelum NIGHT_UNTIL.
const NIGHT_FROM: int = 18
const NIGHT_UNTIL: int = 6
## Jam perangkat diperiksa ulang tiap sekian detik.
const CLOCK_CHECK: float = 30.0

## Langit siang dan malam.
const SKY_DAY: Color = Color(0.8, 0.9, 0.97)
const HORIZON_DAY: Color = Color(0.89, 0.95, 0.99)
const SUN_HALO: Color = Color(1.0, 0.99, 0.9, 0.42)
const SUN: Color = Color(1.0, 0.98, 0.86, 0.72)
const CLOUD_DAY: Color = Color(1.0, 1.0, 1.0, 0.95)
const SKY_NIGHT: Color = Color(0.15, 0.18, 0.33)
const HORIZON_NIGHT: Color = Color(0.21, 0.24, 0.41)
const NIGHT_HALO: Color = Color(0.27, 0.31, 0.5, 0.55)
const NIGHT_GLOW: Color = Color(0.31, 0.35, 0.55, 0.6)
const CLOUD_NIGHT: Color = Color(0.28, 0.31, 0.49, 0.85)
const MOON: Color = Color(1.0, 0.96, 0.82)
const MOON_SPOT: Color = Color(0.95, 0.9, 0.74)
const MOON_HALO: Color = Color(0.85, 0.88, 1.0, 0.1)
const STAR: Color = Color(1.0, 0.96, 0.84)
## Huruf "Crumbtown" di langit malam.
const LOGO_NIGHT: Color = Color(1.0, 0.95, 0.84)
## Kota di kejauhan: [badan, atap] siang dan malam untuk baris jauh dan dekat.
const FAR_DAY: Array[Color] = [Color(0.94, 0.88, 0.85), Color(0.88, 0.79, 0.76)]
const NEAR_DAY: Array[Color] = [Color(0.97, 0.85, 0.75), Color(0.87, 0.62, 0.52)]
const FAR_NIGHT: Array[Color] = [Color(0.24, 0.26, 0.42), Color(0.21, 0.23, 0.38)]
const NEAR_NIGHT: Array[Color] = [Color(0.19, 0.21, 0.35), Color(0.16, 0.17, 0.29)]
const WINDOW_DAY: Color = Color(0.82, 0.89, 0.95)
const WINDOW_LIT: Color = Color(1.0, 0.86, 0.52)
const TREE: Color = Color(0.6, 0.76, 0.5)
const TREE_DARK: Color = Color(0.5, 0.67, 0.42)
## Toko (warna siang; malam diredupkan oleh `_k`).
const UPPER_WALL: Color = Color(0.99, 0.87, 0.58)
const TRIM: Color = Color(0.995, 0.96, 0.9)
const SHOP_WOOD: Color = Color(0.55, 0.34, 0.2)
const SHOP_WOOD_DARK: Color = Color(0.46, 0.27, 0.16)
const GLASS_DAY: Color = Color(0.84, 0.92, 0.96)
const GLASS_LIT: Color = Color(1.0, 0.89, 0.62)
const SHELF: Color = Color(0.7, 0.46, 0.27)
const DOOR: Color = Color(0.46, 0.62, 0.53)
const DOOR_DARK: Color = Color(0.4, 0.55, 0.47)
const SIGN_BOARD: Color = Color(0.995, 0.96, 0.9)
const SIGN_LIT: Color = Color(1.0, 0.95, 0.84)
const AWNING_A: Color = Color(1.0, 0.72, 0.7)
const AWNING_B: Color = Palette.FLOUR_WHITE
const IRON: Color = Color(0.32, 0.25, 0.22)
const LAMP_OFF: Color = Color(0.9, 0.91, 0.9)
const GLOW: Color = Color(1.0, 0.86, 0.5, 0.2)
const GLOW_CORE: Color = Color(1.0, 0.9, 0.6, 0.38)
const LIGHT_SPILL: Color = Color(1.0, 0.84, 0.48, 0.24)
const POT_RIM: Color = Color(0.86, 0.5, 0.32)
## Trotoar.
const PAVE: Color = Color(0.94, 0.88, 0.8)
const PAVE_JOINT: Color = Color(0.89, 0.82, 0.73)
const CURB: Color = Color(0.85, 0.77, 0.68)
## Taplak dan roti di depan sedikit meredup di malam hari.
const TABLE_NIGHT: Color = Color(0.1, 0.12, 0.28, 0.3)
const BREAD_NIGHT: Color = Color(0.8, 0.82, 0.94)
## Roti di taplak: [profil BreadArt, x (0..1), ukuran px] (sama dengan CozyBackdrop).
const TABLE_BREADS: Array = [
	["croissant.classic", 0.115, 104.0], ["donut.jam", 0.255, 66.0],
	["roll.cinnamon", 0.745, 66.0], ["loaf.plain", 0.885, 108.0],
]
## Awan: [x (0..1), y (bagian tinggi layar), lebar px, kecepatan px/detik].
const CLOUDS: Array = [
	[0.12, 0.09, 150.0, 7.0], [0.78, 0.17, 120.0, 5.0], [0.42, 0.31, 170.0, 4.0], [0.9, 0.43, 130.0, 6.0],
]
const STARS: int = 28
const LOGO_SIZE: int = 84
const LOGO_BREAD: int = 164
## Ukuran huruf nama di papan toko (mengecil bila namanya panjang).
const SIGN_FONT: int = 24

## Jam palsu untuk tes dan alat (0-23); -1 = jam perangkat.
static var hour_override: int = -1

## Logo dan tombol "Tap to Start" (false = latar saja).
var show_front: bool = true
## Nama di papan toko: nama toko yang diketik pemain; tanpa save "Bakery"
## (Seksi 20 no. 107).
var bakery_name: String = ""
## Malam (lampu menyala) menurut jam perangkat.
var night: bool = false

var _t: float = 0.0
var _clock: float = 0.0
var _sky: Layer = null
var _street: Layer = null
var _steam: Layer = null
var _sign: Label = null
var _breads: Array[BreadArt] = []
var _logo_box: CenterContainer = null
var _logo_title: Label = null
var _tap_box: CenterContainer = null
var _tap: PanelContainer = null
## Pilihan bahasa EN / ID di pojok kanan atas (Seksi 19 no. 25).
var _lang: HBoxContainer = null
var _stars: Array[Vector3] = []
## Ukuran tata letak (px): tinggi taplak, tinggi trotoar, garis dasar toko,
## lebar toko, dan titik tengahnya.
var _band: float = 108.0
var _pave: float = 128.0
var _gy: float = 1000.0
var _sw: float = 480.0
var _cx: float = 360.0


## Satu lapisan gambar: memanggil `paint(self)`; yang beranimasi digambar ulang
## tiap frame.
class Layer extends Control:
	var paint: Callable
	var animated: bool = false

	func _init(p: Callable, anim: bool) -> void:
		paint = p
		animated = anim
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _process(_delta: float) -> void:
		if animated and is_visible_in_tree() and not SettingsManager.reduced_motion():
			queue_redraw()

	func _draw() -> void:
		paint.call(self)


## Jam perangkat sekarang (0-23), atau `hour_override`.
static func device_hour() -> int:
	if hour_override >= 0:
		return hour_override % 24
	return int(Time.get_time_dict_from_system().get("hour", 12))


static func is_night_hour(hour: int) -> bool:
	return hour >= NIGHT_FROM or hour < NIGHT_UNTIL


func _init() -> void:
	name = "StartScene"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	night = is_night_hour(device_hour())


func _ready() -> void:
	if bakery_name.strip_edges() == "":
		bakery_name = Tx.t("ui_start_sign_default")
	_sky = Layer.new(_paint_sky, true)
	_sky.name = "Sky"
	add_child(_sky)
	_street = Layer.new(_paint_street, false)
	_street.name = "Street"
	add_child(_street)
	_steam = Layer.new(_paint_steam, true)
	_steam.name = "Steam"
	add_child(_steam)
	_sign = ProceduralUIFactory.label(bakery_name, SIGN_FONT, Palette.UI_WOOD_DEEP)
	_sign.name = "SignName"
	_sign.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_sign.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_sign.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_sign)
	for tb: Array in TABLE_BREADS:
		var art := BreadArt.new()
		art.name = "TableBread"
		art.profile = str(tb[0])
		art.art_size = float(tb[2])
		add_child(art)
		_breads.append(art)
	if show_front:
		_build_front()
	# Bintang: posisi tetap (bagian lebar x, bagian langit y, jari-jari px).
	var rng := RandomNumberGenerator.new()
	rng.seed = 2611
	for i in STARS:
		_stars.append(Vector3(rng.randf(), rng.randf(), rng.randf_range(1.2, 2.6)))
	_apply_mode()
	resized.connect(_layout)
	_layout()


func _process(delta: float) -> void:
	if not SettingsManager.reduced_motion() and is_visible_in_tree():
		_t += delta
	_clock += delta
	if _clock >= CLOCK_CHECK:
		_clock = 0.0
		var n: bool = is_night_hour(device_hour())
		if n != night:
			night = n
			_apply_mode()
			night_changed.emit(night)


## Warna yang mengikuti siang/malam di luar gambar: huruf logo dan roti di taplak.
func _apply_mode() -> void:
	if _logo_title != null:
		if night:
			_logo_title.add_theme_color_override("font_color", LOGO_NIGHT)
		else:
			_logo_title.remove_theme_color_override("font_color")
			_logo_title.add_theme_color_override("font_color", Palette.UI_WOOD_DEEP)
	for b: BreadArt in _breads:
		b.modulate = BREAD_NIGHT if night else Color.WHITE
	for l: Layer in [_sky, _street, _steam]:
		if l != null:
			l.queue_redraw()


## Logo di langit dan tombol "Tap to Start" di trotoar.
func _build_front() -> void:
	_logo_box = CenterContainer.new()
	_logo_box.name = "Logo"
	_logo_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_logo_box)
	var lockup: VBoxContainer = ProceduralUIFactory.logo_lockup(Tx.t("game_title"), LOGO_SIZE, LOGO_BREAD)
	_logo_box.add_child(lockup)
	_logo_title = lockup.find_child("Logo", true, false) as Label
	ProceduralAnimationSystem.idle_wobble(lockup.get_meta("bread"))
	_tap_box = CenterContainer.new()
	_tap_box.name = "TapRow"
	_tap_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tap_box)
	# "Tap to Start": pil madu besar yang membesar-mengecil pelan.
	_tap = PanelContainer.new()
	_tap.name = "TapToStart"
	_tap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.HONEY, 40, false)
	tsb.content_margin_left = 40.0
	tsb.content_margin_right = 44.0
	tsb.content_margin_top = 14.0
	tsb.content_margin_bottom = 14.0
	_tap.add_theme_stylebox_override("panel", tsb)
	var tap_h := HBoxContainer.new()
	tap_h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tap_h.add_theme_constant_override("separation", 12)
	_tap.add_child(tap_h)
	tap_h.add_child(ProceduralUIFactory.icon("play", 34, Palette.FLOUR_WHITE))
	var tap_l: Label = ProceduralUIFactory.label(Tx.t("ui_tap_to_start"), 30, Palette.FLOUR_WHITE)
	tap_l.add_theme_font_override("font", ProceduralUIFactory.display_font())
	tap_h.add_child(tap_l)
	_tap_box.add_child(_tap)
	_build_language()
	if not SettingsManager.reduced_motion():
		_tap.resized.connect(func() -> void: _tap.pivot_offset = _tap.size * 0.5)
		var pulse := _tap.create_tween().set_loops()
		pulse.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		pulse.tween_property(_tap, "scale", Vector2(1.06, 1.06), 0.8)
		pulse.tween_property(_tap, "scale", Vector2.ONE, 0.8)


## Dua tombol kecil EN / ID: pemain bisa memilih bahasa sebelum masuk toko.
## Ketukannya tidak dihitung sebagai "Tap to Start" (tombol menahan ketukan).
func _build_language() -> void:
	_lang = HBoxContainer.new()
	_lang.name = "Language"
	_lang.add_theme_constant_override("separation", 6)
	add_child(_lang)
	for code: String in ["en", "id"]:
		var on: bool = SettingsManager.language() == code
		var b: Button = ProceduralUIFactory.button(code.to_upper(), "primary" if on else "secondary")
		b.name = "Lang_" + code
		b.custom_minimum_size = Vector2(64, 48)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(func() -> void:
			if SettingsManager.language() != code:
				SettingsManager.set_value("language", code))
		_lang.add_child(b)


## Tombol bahasa (tes), atau null bila latar saja.
func language_buttons() -> HBoxContainer:
	return _lang


## Tata letak dari bawah ke atas: taplak, trotoar, toko berdiri di trotoar,
## lalu logo di tengah langit yang tersisa.
func _layout() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 2.0 or h < 2.0:
		return
	_band = clampf(h * 0.085, 96.0, 130.0)
	_pave = clampf(h * 0.10, 120.0, 150.0)
	_gy = h - _band - _pave
	_sw = clampf((h - 770.0) / 1.05, 360.0, w * 0.7)
	_cx = w * 0.5
	var sign_r: Rect2 = sign_rect()
	_sign.position = sign_r.position
	_sign.size = sign_r.size
	var f: Font = ProceduralUIFactory.display_font()
	_sign.add_theme_font_size_override("font_size",
		ProceduralUIFactory.fit_font_size(f, _sign.text, mini(ProceduralUIFactory.scaled(SIGN_FONT), int(sign_r.size.y * 0.62)), sign_r.size.x - 40.0, 12))
	var surface: float = h - _band * 0.30
	for i in _breads.size():
		var px: float = float(TABLE_BREADS[i][2])
		_breads[i].size = Vector2(px, px)
		_breads[i].position = Vector2(w * float(TABLE_BREADS[i][1]) - px * 0.5, surface - px * 0.86)
	if _logo_box != null:
		_logo_box.position = Vector2(0.0, 24.0)
		_logo_box.size = Vector2(w, maxf(10.0, shop_top() - 36.0))
	if _tap_box != null:
		_tap_box.position = Vector2(0.0, _gy + 6.0)
		_tap_box.size = Vector2(w, _pave - 12.0)
	if _lang != null:
		_lang.size = _lang.get_combined_minimum_size()
		_lang.position = Vector2(w - _lang.size.x - 16.0, 16.0)
	for l: Layer in [_sky, _street, _steam]:
		if l != null:
			l.queue_redraw()
	laid_out.emit()


## Tepi atas toko (puncak tutup cerobong), px.
func shop_top() -> float:
	return _gy - 1.10 * _sw


## Garis dasar toko = tepi atas trotoar, px.
func ground_y() -> float:
	return _gy


## Papan nama toko (px).
func sign_rect() -> Rect2:
	return _srect(-0.34, -0.455, 0.34, -0.38)


## Kotak trotoar (px).
func pavement_rect() -> Rect2:
	return Rect2(0.0, _gy, size.x, _pave)


## Kanopi termasuk lengkung bawahnya (px).
func awning_rect() -> Rect2:
	return _srect(-0.44, AWNING_TOP, 0.44, AWNING_BOTTOM + AWNING_SCALLOP)


## Pintu beserta kusennya dan lentera di sampingnya (px).
func door_rect() -> Rect2:
	return _srect(0.095, DOOR_TOP, 0.325, 0.0)


func lantern_rect() -> Rect2:
	return _srect(0.345, LANTERN_TOP, 0.375, LANTERN_TOP + 0.075)


## Label nama toko di papan (tes).
func sign_label() -> Label:
	return _sign


## Lampu toko, kota, dan jalan menyala (malam).
func lamps_on() -> bool:
	return night


## Huruf "Crumbtown" di logo (tes), atau null bila latar saja.
func logo_title() -> Label:
	return _logo_title


## Ganti nama di papan (mis. layar loading yang sudah tampil).
func set_bakery_name(n: String) -> void:
	bakery_name = n if n.strip_edges() != "" else Tx.t("ui_start_sign_default")
	if _sign != null:
		_sign.text = bakery_name
		_layout()


## Pil "Tap to Start" (tes), atau null bila latar saja.
func tap_pill() -> Control:
	return _tap


## Logo (tes), atau null bila latar saja.
func logo() -> Control:
	return _logo_box


# ===========================================================================
# LANGIT
# ===========================================================================

func _paint_sky(ci: CanvasItem) -> void:
	var w: float = size.x
	var h: float = size.y
	ci.draw_rect(Rect2(0.0, 0.0, w, h), SKY_NIGHT if night else SKY_DAY)
	# Cahaya cakrawala di belakang kota.
	ci.draw_rect(Rect2(0.0, _gy - _sw * 0.95, w, _sw * 0.95), HORIZON_NIGHT if night else HORIZON_DAY)
	var glow := Vector2(w * 0.5, (24.0 + shop_top()) * 0.5 - 20.0)
	if night:
		for st: Vector3 in _stars:
			var p := Vector2(st.x * w, 12.0 + st.y * maxf(40.0, shop_top() - 40.0))
			var a: float = 0.55 + 0.45 * sin(_t * 1.6 + st.x * 40.0)
			ci.draw_circle(p, st.z, Color(STAR, a), true, -1.0, true)
		# Cahaya bulan lembut di belakang logo supaya hurufnya tetap terbaca.
		ci.draw_circle(glow, w * 0.42, NIGHT_HALO, true, -1.0, true)
		ci.draw_circle(glow, w * 0.3, NIGHT_GLOW, true, -1.0, true)
		var moon := Vector2(w * 0.86, h * 0.07)
		ci.draw_circle(moon, w * 0.1, MOON_HALO, true, -1.0, true)
		ci.draw_circle(moon, w * 0.05, MOON, true, -1.0, true)
		ci.draw_circle(moon + Vector2(-0.012, 0.01) * w, w * 0.011, MOON_SPOT, true, -1.0, true)
		ci.draw_circle(moon + Vector2(0.016, -0.014) * w, w * 0.007, MOON_SPOT, true, -1.0, true)
	else:
		# Matahari pucat di belakang logo.
		ci.draw_circle(glow, w * 0.42, SUN_HALO, true, -1.0, true)
		ci.draw_circle(glow, w * 0.3, SUN, true, -1.0, true)
	for cl: Array in CLOUDS:
		var cw: float = float(cl[2])
		var x: float = fposmod(float(cl[0]) * w + float(cl[3]) * _t, w + cw * 1.2) - cw * 0.6
		var y: float = h * float(cl[1])
		if y > _gy - _sw * 0.5:
			continue
		_cloud(ci, Vector2(x, y), cw, CLOUD_NIGHT if night else CLOUD_DAY)


## Awan flat: alas membulat dan tiga gumpalan.
func _cloud(ci: CanvasItem, c: Vector2, cw: float, col: Color) -> void:
	# Radius di bawah setengah tinggi: lengkung yang bertemu tepat di tengah
	# membuat titik kembar dan poligonnya gagal dipecah segitiga.
	ProceduralUIFactory.fill_aa(ci, ProceduralUIFactory.rounded_points(Rect2(c + Vector2(-0.45, -0.05) * cw, Vector2(0.9, 0.17) * cw), 0.075 * cw, 6), col)
	ci.draw_circle(c + Vector2(-0.2, -0.06) * cw, 0.17 * cw, col, true, -1.0, true)
	ci.draw_circle(c + Vector2(0.04, -0.13) * cw, 0.22 * cw, col, true, -1.0, true)
	ci.draw_circle(c + Vector2(0.27, -0.03) * cw, 0.14 * cw, col, true, -1.0, true)


# ===========================================================================
# JALAN: KOTA, TROTOAR, TOKO, TAPLAK
# ===========================================================================

func _paint_street(ci: CanvasItem) -> void:
	var w: float = size.x
	var h: float = size.y
	_paint_town(ci, w)
	_paint_pavement(ci, w)
	_paint_shop(ci)
	_chalkboard(ci, Vector2(_cx - 0.62 * _sw, _gy + _pave * 0.34))
	_street_lamp(ci, Vector2(_cx + 0.63 * _sw, _gy + _pave * 0.22))
	ProceduralUIFactory.draw_gingham(ci, Rect2(0.0, h - _band, w, _band), SIDE_TOP)
	if night:
		ci.draw_rect(Rect2(0.0, h - _band - ProceduralUIFactory.LACE_SCALLOP, w, _band + ProceduralUIFactory.LACE_SCALLOP), TABLE_NIGHT)


## Warna dunia: siang apa adanya, malam diredupkan kebiruan.
func _k(c: Color) -> Color:
	if not night:
		return c
	return Color(c.r * 0.5 + 0.06, c.g * 0.46 + 0.06, c.b * 0.52 + 0.15, c.a)


## Dua baris rumah di kejauhan dan dua pohon di samping toko. Rumah:
## [kiri, kanan (bagian lebar layar), tinggi (bagian lebar toko), atap pelana].
func _paint_town(ci: CanvasItem, w: float) -> void:
	var far_c: Array[Color] = FAR_NIGHT if night else FAR_DAY
	var near_c: Array[Color] = NEAR_NIGHT if night else NEAR_DAY
	var far: Array = [[-0.02, 0.1, 0.66, false], [0.09, 0.2, 0.5, true], [0.19, 0.3, 0.74, false],
		[0.7, 0.8, 0.7, true], [0.79, 0.9, 0.52, false], [0.89, 1.02, 0.78, true]]
	for b: Array in far:
		_house(ci, w * float(b[0]), w * float(b[1]), _sw * float(b[2]), bool(b[3]), far_c[0], far_c[1])
	# Menara jam kecil di kiri jauh.
	var tx: float = w * 0.135
	ci.draw_rect(Rect2(tx - 0.035 * _sw, _gy - 0.86 * _sw, 0.07 * _sw, 0.4 * _sw), far_c[0].darkened(0.03))
	ProceduralUIFactory.fill_aa(ci, PackedVector2Array([Vector2(tx - 0.05 * _sw, _gy - 0.86 * _sw), Vector2(tx + 0.05 * _sw, _gy - 0.86 * _sw),
		Vector2(tx, _gy - 0.97 * _sw)]), far_c[1])
	ci.draw_circle(Vector2(tx, _gy - 0.79 * _sw), 0.024 * _sw, WINDOW_LIT if night else Palette.FLOUR_WHITE, true, -1.0, true)
	var near: Array = [[-0.03, 0.12, 0.42, true], [0.11, 0.22, 0.32, false], [0.78, 0.9, 0.36, false], [0.89, 1.03, 0.46, true]]
	for b2: Array in near:
		_house(ci, w * float(b2[0]), w * float(b2[1]), _sw * float(b2[2]), bool(b2[3]), near_c[0], near_c[1])
	for tx2: float in [_cx - 0.53 * _sw, _cx + 0.54 * _sw]:
		ci.draw_rect(Rect2(tx2 - 0.012 * _sw, _gy - 0.12 * _sw, 0.024 * _sw, 0.12 * _sw), _k(Palette.TRUNK))
		ci.draw_circle(Vector2(tx2, _gy - 0.2 * _sw), 0.1 * _sw, _k(TREE), true, -1.0, true)
		ci.draw_circle(Vector2(tx2 - 0.05 * _sw, _gy - 0.15 * _sw), 0.07 * _sw, _k(TREE_DARK), true, -1.0, true)
		ci.draw_circle(Vector2(tx2 + 0.055 * _sw, _gy - 0.16 * _sw), 0.075 * _sw, _k(TREE), true, -1.0, true)


## Rumah sederhana: badan, atap pelana atau datar, dan jendela kecil (malam:
## sebagian menyala).
func _house(ci: CanvasItem, x0: float, x1: float, hh: float, gable: bool, body: Color, roof: Color) -> void:
	var top: float = _gy - hh
	ci.draw_rect(Rect2(x0, top, x1 - x0, hh), body)
	if gable:
		ProceduralUIFactory.fill_aa(ci, PackedVector2Array([Vector2(x0 - 4.0, top), Vector2(x1 + 4.0, top),
			Vector2((x0 + x1) * 0.5, top - (x1 - x0) * 0.36)]), roof)
	else:
		ci.draw_rect(Rect2(x0 - 3.0, top - 6.0, x1 - x0 + 6.0, 7.0), roof)
	var cols: int = maxi(1, int((x1 - x0) / 34.0))
	var gap: float = (x1 - x0) / float(cols)
	var rows: int = maxi(1, int(hh / 52.0))
	for r in rows:
		for k in cols:
			var on: bool = (r + k + int(x0)) % 3 != 0
			var wr := Rect2(x0 + gap * (float(k) + 0.3), top + 18.0 + float(r) * 52.0, gap * 0.4, 18.0)
			if wr.end.y < _gy - 8.0:
				var col: Color = WINDOW_DAY.lerp(body, 0.35)
				if night:
					col = WINDOW_LIT if on else body.lightened(0.06)
				ci.draw_rect(wr, col)


func _paint_pavement(ci: CanvasItem, w: float) -> void:
	ci.draw_rect(Rect2(0.0, _gy, w, _pave), _k(PAVE))
	# Ubin trotoar berselang-seling dan tepi jalan di bawahnya.
	var rows: int = 3
	var rh: float = (_pave - 12.0) / float(rows)
	for r in rows:
		var y: float = _gy + float(r) * rh
		if r > 0:
			ci.draw_rect(Rect2(0.0, y - 1.0, w, 2.0), _k(PAVE_JOINT))
		var off: float = 0.0 if r % 2 == 0 else 45.0
		var x: float = -off
		while x < w:
			ci.draw_rect(Rect2(x - 1.0, y, 2.0, rh), _k(PAVE_JOINT))
			x += 90.0
	ci.draw_rect(Rect2(0.0, _gy + _pave - 12.0, w, 12.0), _k(CURB))
	if not night:
		return
	# Malam: cahaya hangat dari etalase, pintu, dan lampu jalan jatuh di trotoar.
	var a: Vector2 = _s(-0.36, 0.0)
	var b: Vector2 = _s(0.04, 0.0)
	ProceduralUIFactory.fill_aa(ci, PackedVector2Array([a, b, b + Vector2(0.06 * _sw, _pave * 0.55), a + Vector2(-0.06 * _sw, _pave * 0.55)]), LIGHT_SPILL)
	var d0: Vector2 = _s(0.11, 0.0)
	var d1: Vector2 = _s(0.31, 0.0)
	ProceduralUIFactory.fill_aa(ci, PackedVector2Array([d0, d1, d1 + Vector2(0.04 * _sw, _pave * 0.4), d0 + Vector2(-0.04 * _sw, _pave * 0.4)]), LIGHT_SPILL)
	var lamp := Vector2(_cx + 0.63 * _sw, _gy + _pave * 0.22)
	ProceduralUIFactory.fill_aa(ci, _ellipse(lamp, Vector2(0.16, 0.035) * _sw), LIGHT_SPILL)


## Batas kanopi dan pintu (satuan lebar toko, y negatif ke atas): kanopi di
## atas, lengkung bawahnya berakhir di atas pintu, etalase, dan lentera.
const AWNING_TOP: float = -0.36
const AWNING_BOTTOM: float = -0.3
const AWNING_SCALLOP: float = 0.04
const DOOR_TOP: float = -0.245
const LANTERN_TOP: float = -0.225


## Toko dua lantai selebar 0,84 lebar toko. Satuan: lebar toko; asal di tengah
## garis dasar, y negatif ke atas. Kanopi digambar terakhir supaya tidak ada
## yang menimpanya.
func _paint_shop(ci: CanvasItem) -> void:
	# Cerobong (di belakang atap) dan atap genting yang menjorok.
	_box(ci, 0.2, -1.07, 0.28, -0.9, _k(Palette.TERRACOTTA))
	_box(ci, 0.185, -1.1, 0.295, -1.06, _k(Palette.ROOF_TILE_DEEP), 0.008)
	_quad(ci, Vector2(-0.48, -0.84), Vector2(0.48, -0.84), Vector2(0.34, -1.0), Vector2(-0.34, -1.0), _k(Palette.ROOF_TILE))
	for ly: float in [-0.893, -0.946]:
		var k: float = (ly + 0.84) / -0.16
		var half: float = lerpf(0.48, 0.34, k)
		_box(ci, -half + 0.012, ly - 0.004, half - 0.012, ly + 0.004, _k(Palette.ROOF_TILE_DEEP))
	_box(ci, -0.485, -0.85, 0.485, -0.832, _k(Palette.ROOF_TILE_DEEP), 0.006)
	# Lantai atas: dinding kuning mentega, lis krem, dua jendela berkotak bunga,
	# dan medali roti di antaranya.
	_box(ci, -0.42, -0.832, 0.42, -0.47, _k(UPPER_WALL))
	_box(ci, -0.44, -0.832, 0.44, -0.808, _k(TRIM), 0.008)
	for sx: float in [-1.0, 1.0]:
		var wx: float = 0.21 * sx
		_box(ci, wx - 0.085, -0.77, wx + 0.085, -0.575, _k(TRIM), 0.04)
		_box(ci, wx - 0.065, -0.75, wx + 0.065, -0.595, GLASS_LIT if night else GLASS_DAY, 0.03)
		_box(ci, wx - 0.004, -0.75, wx + 0.004, -0.595, _k(TRIM))
		_box(ci, wx - 0.065, -0.676, wx + 0.065, -0.668, _k(TRIM))
		_box(ci, wx - 0.1, -0.585, wx + 0.1, -0.545, _k(Palette.CARAMEL), 0.008)
		var flowers: Array[Color] = [Palette.STRAWBERRY, Palette.FLOUR_WHITE, Palette.PASTEL_STRAWBERRY, Palette.BUTTER_YELLOW, Palette.STRAWBERRY]
		for i in 5:
			var fx: float = wx - 0.08 + float(i) * 0.04
			_dot(ci, fx, -0.59, 0.022, _k(Palette.LEAF if i % 2 == 0 else Palette.LEAF_DEEP))
			_dot(ci, fx + 0.01, -0.605, 0.015, _k(flowers[i]))
	_dot(ci, 0.0, -0.69, 0.058, _k(TRIM))
	_dot(ci, 0.0, -0.69, 0.046, _k(Palette.HONEY))
	ProceduralUIFactory.fill_aa(ci, _ellipse(_s(0.0, -0.685), Vector2(0.03, 0.019) * _sw), _k(Palette.FLOUR_WHITE))
	for k2 in 3:
		var sx2: float = -0.014 + float(k2) * 0.014
		ci.draw_line(_s(sx2 - 0.004, -0.681), _s(sx2 + 0.004, -0.692), _k(Palette.HONEY), 0.005 * _sw, true)
	# Lantai dasar kayu dengan tiang di kedua ujung dan alas batu.
	_box(ci, -0.42, -0.47, 0.42, 0.0, _k(SHOP_WOOD))
	_box(ci, -0.42, -0.47, -0.39, 0.0, _k(SHOP_WOOD_DARK))
	_box(ci, 0.39, -0.47, 0.42, 0.0, _k(SHOP_WOOD_DARK))
	_box(ci, -0.43, -0.022, 0.43, 0.0, _k(Palette.CONCRETE), 0.004)
	# Papan nama (menyala di malam hari) dan dua lampu sorot kecil di atasnya.
	_box(ci, -0.36, -0.468, 0.36, -0.367, _k(SHOP_WOOD_DARK), 0.015)
	_box(ci, -0.34, -0.455, 0.34, -0.38, SIGN_LIT if night else SIGN_BOARD, 0.012)
	for lx: float in [-0.22, 0.22]:
		_box(ci, lx - 0.004, -0.5, lx + 0.004, -0.472, _k(IRON))
		_quad(ci, Vector2(lx - 0.022, -0.474), Vector2(lx + 0.022, -0.474), Vector2(lx + 0.012, -0.488), Vector2(lx - 0.012, -0.488), _k(IRON))
		if night:
			_quad(ci, Vector2(lx - 0.02, -0.468), Vector2(lx + 0.02, -0.468), Vector2(lx + 0.09, -0.41), Vector2(lx - 0.09, -0.41), GLOW)
	# Etalase: bingkai krem, kaca (malam: menyala hangat), dua rak berisi roti.
	_box(ci, -0.37, -0.235, 0.05, -0.04, _k(TRIM), 0.012)
	_box(ci, -0.35, -0.218, 0.03, -0.056, GLASS_LIT if night else GLASS_DAY, 0.008)
	for sy: float in [-0.155, -0.086]:
		_box(ci, -0.35, sy, 0.03, sy + 0.011, SHELF)
	_loaf(ci, -0.3, -0.169)
	_bun(ci, -0.215, -0.166)
	_croissant(ci, -0.03, -0.166)
	_bun(ci, -0.3, -0.098)
	_croissant(ci, -0.2, -0.1)
	_loaf(ci, -0.035, -0.101)
	_box(ci, -0.165, -0.218, -0.155, -0.056, _k(TRIM))
	_box(ci, -0.38, -0.04, 0.06, -0.022, _k(SHOP_WOOD_DARK))
	# Pintu hijau sage berkaca melengkung dengan kusen silang.
	_box(ci, 0.095, DOOR_TOP, 0.325, -0.01, _k(TRIM), 0.06)
	_box(ci, 0.115, DOOR_TOP + 0.017, 0.305, -0.01, _k(DOOR), 0.05)
	var glass: Color = GLASS_LIT if night else GLASS_DAY
	_box(ci, 0.14, DOOR_TOP + 0.04, 0.28, -0.125, glass, 0.035)
	_box(ci, 0.206, DOOR_TOP + 0.04, 0.214, -0.125, _k(DOOR))
	_box(ci, 0.14, -0.168, 0.28, -0.161, _k(DOOR))
	_box(ci, 0.14, -0.095, 0.28, -0.03, _k(DOOR_DARK), 0.01)
	_dot(ci, 0.272, -0.11, 0.011, _k(Palette.BUTTER_YELLOW))
	_box(ci, 0.08, -0.012, 0.34, 0.01, _k(Palette.CONCRETE), 0.006)
	# Lentera dinding di samping pintu, di bawah kanopi (malam: menyala).
	if night:
		_dot(ci, 0.36, LANTERN_TOP + 0.04, 0.07, GLOW)
		_dot(ci, 0.36, LANTERN_TOP + 0.04, 0.042, GLOW_CORE)
	_box(ci, 0.35, LANTERN_TOP, 0.37, LANTERN_TOP + 0.007, _k(IRON))
	_box(ci, 0.345, LANTERN_TOP + 0.007, 0.375, LANTERN_TOP + 0.075, _k(IRON), 0.008)
	_box(ci, 0.351, LANTERN_TOP + 0.015, 0.369, LANTERN_TOP + 0.066, WINDOW_LIT if night else LAMP_OFF, 0.004)
	# Pot tanaman bulat di kedua sisi muka toko.
	for px: float in [-0.475, 0.465]:
		_dot(ci, px, -0.135, 0.06, _k(TREE))
		_dot(ci, px - 0.025, -0.115, 0.04, _k(TREE_DARK))
		_quad(ci, Vector2(px - 0.05, -0.075), Vector2(px + 0.05, -0.075), Vector2(px + 0.038, 0.0), Vector2(px - 0.038, 0.0), _k(Palette.TERRACOTTA))
		_box(ci, px - 0.058, -0.088, px + 0.058, -0.07, _k(POT_RIM), 0.006)
	_awning(ci)


## Kanopi bergaris merah muda-krem dengan tepi bawah bergelombang.
func _awning(ci: CanvasItem) -> void:
	var n: int = 9
	for i in n:
		var t0: float = float(i) / float(n)
		var t1: float = float(i + 1) / float(n)
		var col: Color = _k(AWNING_A if i % 2 == 0 else AWNING_B)
		_quad(ci, Vector2(lerpf(-0.41, 0.41, t0), AWNING_TOP), Vector2(lerpf(-0.41, 0.41, t1), AWNING_TOP),
			Vector2(lerpf(-0.44, 0.44, t1), AWNING_BOTTOM), Vector2(lerpf(-0.44, 0.44, t0), AWNING_BOTTOM), col)
		var mx: float = lerpf(-0.44, 0.44, (t0 + t1) * 0.5)
		var r: float = 0.88 / float(n) * 0.5
		var cup := PackedVector2Array()
		for k in 11:
			var a: float = PI * float(k) / 10.0
			cup.append(_s(mx + cos(a) * r, AWNING_BOTTOM - 0.002 + sin(a) * AWNING_SCALLOP))
		ProceduralUIFactory.fill_aa(ci, cup, col)
	_box(ci, -0.43, AWNING_TOP - 0.012, 0.43, AWNING_TOP + 0.004, _k(SHOP_WOOD_DARK), 0.006)


## Roti di etalase (selalu terang: diterangi siang hari atau lampu toko).
func _loaf(ci: CanvasItem, x: float, y: float) -> void:
	ProceduralUIFactory.fill_aa(ci, _ellipse(_s(x, y), Vector2(0.04, 0.022) * _sw), Palette.GOLDEN_CRUST)
	for k in 3:
		var sx: float = x - 0.02 + float(k) * 0.02
		ci.draw_line(_s(sx - 0.006, y + 0.006), _s(sx + 0.006, y - 0.008), Color(1.0, 0.88, 0.63), 0.006 * _sw, true)


func _bun(ci: CanvasItem, x: float, y: float) -> void:
	ProceduralUIFactory.fill_aa(ci, _ellipse(_s(x, y + 0.002), Vector2(0.026, 0.02) * _sw), Color(0.9, 0.6, 0.3))
	for k in 3:
		_dot(ci, x - 0.01 + float(k) * 0.01, y - 0.008 + (0.004 if k == 1 else 0.0), 0.003, Palette.FLOUR_WHITE)


func _croissant(ci: CanvasItem, x: float, y: float) -> void:
	for k in [-1, 1]:
		ProceduralUIFactory.fill_aa(ci, _ellipse(_s(x + 0.024 * float(k), y + 0.006), Vector2(0.018, 0.012) * _sw), Palette.GOLDEN_CRUST)
	ProceduralUIFactory.fill_aa(ci, _ellipse(_s(x, y), Vector2(0.024, 0.018) * _sw), Color(0.95, 0.7, 0.36))


## Papan kapur berdiri di trotoar dengan gambar roti dan dua garis tulisan.
func _chalkboard(ci: CanvasItem, foot: Vector2) -> void:
	var u: float = _sw
	var bw: float = 0.15 * u
	var bh: float = 0.19 * u
	var top: float = foot.y - bh - 0.03 * u
	var wood: Color = _k(Palette.CARAMEL)
	var chalk: Color = _k(Palette.CHALK_WHITE)
	ci.draw_line(foot + Vector2(-bw * 0.42, 0.0), Vector2(foot.x - bw * 0.3, top + bh * 0.5), wood, 0.012 * u, true)
	ci.draw_line(foot + Vector2(bw * 0.42, 0.0), Vector2(foot.x + bw * 0.3, top + bh * 0.5), wood, 0.012 * u, true)
	ProceduralUIFactory.fill_aa(ci, ProceduralUIFactory.rounded_points(Rect2(foot.x - bw * 0.5, top, bw, bh), 0.012 * u, 4), wood)
	ProceduralUIFactory.fill_aa(ci, ProceduralUIFactory.rounded_points(Rect2(foot.x - bw * 0.42, top + 0.012 * u, bw * 0.84, bh - 0.024 * u), 0.008 * u, 4), _k(Palette.CHALKBOARD))
	var c := Vector2(foot.x, top + bh * 0.36)
	ci.draw_arc(c, 0.03 * u, PI, TAU, 12, chalk, 0.006 * u, true)
	for k3 in 3:
		var sx3: float = c.x + (float(k3) - 1.0) * 0.016 * u
		ci.draw_line(Vector2(sx3 - 0.004 * u, c.y - 0.004 * u), Vector2(sx3 + 0.004 * u, c.y - 0.018 * u), chalk, 0.005 * u, true)
	ci.draw_line(c + Vector2(-0.03 * u, 0.0), c + Vector2(0.03 * u, 0.0), chalk, 0.006 * u, true)
	for k in 2:
		var y: float = top + bh * (0.64 + 0.14 * float(k))
		var half: float = bw * (0.28 - 0.08 * float(k))
		ci.draw_line(Vector2(foot.x - half, y), Vector2(foot.x + half, y), Color(chalk, 0.8), 0.006 * u, true)


## Lampu jalan besi (malam: menyala hangat dengan cahaya lembut).
func _street_lamp(ci: CanvasItem, base: Vector2) -> void:
	var u: float = _sw
	var top: float = base.y - 0.72 * u
	var iron: Color = _k(IRON)
	ProceduralUIFactory.fill_aa(ci, ProceduralUIFactory.rounded_points(Rect2(base.x - 0.03 * u, base.y - 0.05 * u, 0.06 * u, 0.05 * u), 0.01 * u, 3), iron)
	ci.draw_rect(Rect2(base.x - 0.009 * u, top, 0.018 * u, base.y - top - 0.04 * u), iron)
	if night:
		ci.draw_circle(Vector2(base.x, top - 0.035 * u), 0.11 * u, GLOW, true, -1.0, true)
		ci.draw_circle(Vector2(base.x, top - 0.035 * u), 0.065 * u, GLOW_CORE, true, -1.0, true)
	ProceduralUIFactory.fill_aa(ci, PackedVector2Array([Vector2(base.x - 0.035 * u, top - 0.075 * u), Vector2(base.x + 0.035 * u, top - 0.075 * u),
		Vector2(base.x, top - 0.11 * u)]), iron)
	ProceduralUIFactory.fill_aa(ci, ProceduralUIFactory.rounded_points(Rect2(base.x - 0.028 * u, top - 0.075 * u, 0.056 * u, 0.07 * u), 0.012 * u, 3),
		WINDOW_LIT if night else LAMP_OFF)
	ci.draw_rect(Rect2(base.x - 0.034 * u, top - 0.008 * u, 0.068 * u, 0.012 * u), iron)


# ===========================================================================
# UAP CEROBONG
# ===========================================================================

func _paint_steam(ci: CanvasItem) -> void:
	var src: Vector2 = _s(0.24, -1.11)
	var puff: Color = Color(0.72, 0.76, 0.9) if night else Color(1.0, 1.0, 1.0)
	for i in 3:
		var k: float = fposmod(_t * 0.22 + float(i) / 3.0, 1.0)
		var p: Vector2 = src + Vector2(k * 0.07 * _sw + sin(k * 5.0 + float(i)) * 0.012 * _sw, -k * 0.1 * _sw)
		var r: float = lerpf(0.016, 0.034, k) * _sw
		ci.draw_circle(p, r, Color(puff, 0.75 * (1.0 - k)), true, -1.0, true)


# ===========================================================================
# ALAT GAMBAR (satuan toko)
# ===========================================================================

## Titik toko (x, y dalam lebar toko) ke px.
func _s(x: float, y: float) -> Vector2:
	return Vector2(_cx + x * _sw, _gy + y * _sw)


func _srect(x0: float, y0: float, x1: float, y1: float) -> Rect2:
	var a: Vector2 = _s(x0, y0)
	var b: Vector2 = _s(x1, y1)
	return Rect2(Vector2(minf(a.x, b.x), minf(a.y, b.y)), (b - a).abs())


func _box(ci: CanvasItem, x0: float, y0: float, x1: float, y1: float, col: Color, r: float = 0.0) -> void:
	var rect: Rect2 = _srect(x0, y0, x1, y1)
	if r <= 0.0:
		ci.draw_rect(rect, col)
	else:
		ProceduralUIFactory.fill_aa(ci, ProceduralUIFactory.rounded_points(rect, r * _sw, 4), col)


func _quad(ci: CanvasItem, a: Vector2, b: Vector2, c: Vector2, d: Vector2, col: Color) -> void:
	ProceduralUIFactory.fill_aa(ci, PackedVector2Array([_s(a.x, a.y), _s(b.x, b.y), _s(c.x, c.y), _s(d.x, d.y)]), col)


func _dot(ci: CanvasItem, x: float, y: float, r: float, col: Color) -> void:
	ci.draw_circle(_s(x, y), r * _sw, col, true, -1.0, true)


static func _ellipse(ctr: Vector2, r: Vector2, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		out.append(ctr + Vector2(cos(a) * r.x, sin(a) * r.y))
	return out
