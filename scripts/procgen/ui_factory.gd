class_name ProceduralUIFactory
extends RefCounted
## Pembangkit seluruh komponen UI 2D Roti Lezat Tycoon — 100% prosedural.
##
## GDD 4.3, 7, dan 12.3: tidak ada satu pun tekstur, font, atau gambar eksternal.
## Panel dan tombol dibangun dari [StyleBoxFlat] bersudut membulat tebal
## (kesan bantalan empuk), ikon digambar di `_draw()` lewat [IconCanvas], dan
## seluruh teks memakai `ThemeDB.fallback_font` (dibungkus [FontVariation] bila
## butuh spasi huruf ala mesin tik).
##
## Aturan wajib GDD 7:
## - Sudut membulat minimal 18 px (tombol memakai bentuk pil).
## - Hitbox interaktif minimal 48x48 dp.
## - `focus_mode = FOCUS_NONE` (kontrol tap-first, bebas keyboard).
## - Setiap tombol otomatis memantul (`press_bounce`) + bunyi ketukan kayu.
##
## Tata letak selalu memakai container + anchor sehingga benar di 1280x720
## lanskap maupun layar ponsel sempit (GDD 12.5).


# ---------------------------------------------------------------------------
# Konstanta tata letak (GDD 7)
# ---------------------------------------------------------------------------

## Sisi minimum zona sentuh yang nyaman untuk jari (48x48 dp).
const TOUCH_MIN: float = 48.0
## Radius sudut tombol pil.
const RADIUS_PILL: int = 24
## Radius sudut panel standar.
const RADIUS_PANEL: int = 20
## Ukuran font teks isi.
const FONT_BODY: int = 18
## Ukuran font judul.
const FONT_TITLE: int = 28
## Ukuran font keterangan kecil.
const FONT_SMALL: int = 14
## Lama toast bertahan di layar (detik) sebelum memudar.
const TOAST_SECONDS: float = 2.2
## Rasio isi gudang saat bar kapasitas mulai berwarna peringatan (GDD 12.3).
const PANTRY_WARN: float = 0.75
## Rasio isi gudang saat bar kapasitas berwarna bahaya (hampir penuh).
const PANTRY_FULL: float = 0.92

## Ukuran baku kartu popup dalam piksel GUI pada resolusi acuan 1280x720
## (GDD 12.5). Sengaja jauh lebih kecil dari layar: popup harus menyisakan
## dapur dan HUD tetap terlihat di belakangnya.
const POPUP_SIZE: Vector2 = Vector2(760.0, 520.0)
## Jarak isi dari tepi kartu popup.
const POPUP_PAD: int = 18


# Cache agar objek berat (Theme, FontVariation, tekstur grabber) dibuat sekali.
static var _theme_cache: Theme = null
static var _font_cache: Dictionary = {}
static var _grabber_cache: ImageTexture = null
static var _grabber_hi_cache: ImageTexture = null


# ---------------------------------------------------------------------------
# Panel & kartu
# ---------------------------------------------------------------------------

## StyleBoxFlat krem hangat bersudut membulat penuh, bergaris tepi kayu lembut,
## dan (opsional) bayangan jatuh halus khas GDD 4.3.
static func panel(color: Color, radius := 20, shadow := true) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(maxi(radius, 0))
	sb.corner_detail = 10
	sb.anti_aliasing = true
	sb.set_border_width_all(2)
	sb.border_color = Color(Palette.UI_WOOD, 0.20)
	sb.set_content_margin_all(14.0)
	if shadow:
		sb.shadow_color = Palette.SHADOW
		sb.shadow_size = 8
		sb.shadow_offset = Vector2(0.0, 4.0)
	return sb


## Kartu bersudut membulat dengan baris judul opsional.
## Isi kartu ditambahkan ke container hasil [method content_of].
static func card(title_text: String, radius := 22) -> PanelContainer:
	var root: PanelContainer = PanelContainer.new()
	root.name = "Card"
	root.add_theme_stylebox_override("panel", panel(Palette.PANEL_ALT, radius, true))

	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	_set_margins(pad, 4, 4, 2, 2)
	root.add_child(pad)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 10)
	pad.add_child(body)

	if not title_text.is_empty():
		var head: HBoxContainer = HBoxContainer.new()
		head.name = "TitleRow"
		head.add_theme_constant_override("separation", 10)

		var accent: Panel = Panel.new()
		accent.name = "Accent"
		accent.custom_minimum_size = Vector2(6.0, 24.0)
		accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		accent.add_theme_stylebox_override("panel", panel(Palette.GOLDEN_CRUST, 3, false))
		head.add_child(accent)

		var cap: Label = label(title_text, 20, Palette.UI_WOOD)
		cap.name = "Title"
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(cap)

		body.add_child(head)
		body.add_child(_line_separator(Color(Palette.UI_WOOD, 0.22)))
		root.set_meta("title_label", cap)

	root.set_meta("body", body)
	return root


## Kerangka POPUP: kaca gelap tembus pandang + satu kartu di tengah layar.
##
## Bedanya dengan layar penuh: dapur dan HUD tetap TERLIHAT di belakangnya, jadi
## pemain tidak kehilangan pandangan atas oven yang sedang memanggang hanya
## karena ia membuka daftar karyawan. Ketukan tetap tertahan di sini — kartu
## boleh tembus pandang, tetapi tidak boleh tembus jari.
##
## UKURANNYA DIPATOK, bukan mengikuti isi. Kartu yang mengembang mengikuti teks
## terpanjang akan melar melewati tepi layar pada resep bernama panjang, dan
## yang melar itu tidak bisa digulir kembali. Isi yang kepanjangan digulir di
## dalam kartu; isi yang kelebaran dipotong tepinya.
##
## Mengembalikan Control akar penuh layar dengan tiga meta:
##   "body"  VBoxContainer — tempat pemanggil menaruh isinya
##   "head"  HBoxContainer — baris judul, tempat menambahkan tombol tutup
##   "scrim" ColorRect     — sambungkan `gui_input` untuk "ketuk di luar = tutup"
static func popup(title_text: String, ukuran: Vector2 = POPUP_SIZE) -> Control:
	var root: Control = Control.new()
	root.name = "Popup"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(Palette.DARK_CHOCOLATE.r, Palette.DARK_CHOCOLATE.g,
		Palette.DARK_CHOCOLATE.b, 0.45)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scrim)

	var kartu: PanelContainer = PanelContainer.new()
	kartu.name = "Kartu"
	kartu.add_theme_stylebox_override("panel", panel(Palette.PANEL, 24, true))
	kartu.clip_contents = true
	kartu.anchor_left = 0.5
	kartu.anchor_right = 0.5
	kartu.anchor_top = 0.5
	kartu.anchor_bottom = 0.5
	kartu.grow_horizontal = Control.GROW_DIRECTION_BOTH
	kartu.grow_vertical = Control.GROW_DIRECTION_BOTH
	kartu.offset_left = -ukuran.x * 0.5
	kartu.offset_right = ukuran.x * 0.5
	kartu.offset_top = -ukuran.y * 0.5
	kartu.offset_bottom = ukuran.y * 0.5
	root.add_child(kartu)

	var pad: MarginContainer = MarginContainer.new()
	_set_margins(pad, POPUP_PAD, POPUP_PAD, POPUP_PAD, POPUP_PAD)
	kartu.add_child(pad)

	var kolom: VBoxContainer = VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 10)
	pad.add_child(kolom)

	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 10)
	kolom.add_child(head)
	var judul: Label = title(title_text, 24)
	judul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	judul.clip_text = true
	head.add_child(judul)

	kolom.add_child(_line_separator(Color(Palette.UI_WOOD, 0.22)))

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	kolom.add_child(body)

	root.set_meta("body", body)
	root.set_meta("head", head)
	root.set_meta("scrim", scrim)
	root.set_meta("kartu", kartu)
	return root


## Nota parchment Daily Summary (GDD 11.1 & 11.7): kertas krem berserat,
## bingkai tanaman sulur daun yang digambar prosedural, dan rasa mesin tik
## lewat spasi huruf pada font bawaan.
static func parchment_panel() -> PanelContainer:
	var root: PanelContainer = PanelContainer.new()
	root.name = "Parchment"

	var sb: StyleBoxFlat = panel(Palette.PARCHMENT, 22, true)
	sb.border_color = Color(Palette.UI_WOOD, 0.38)
	sb.set_border_width_all(3)
	sb.set_content_margin_all(10.0)
	sb.shadow_size = 12
	sb.shadow_offset = Vector2(0.0, 6.0)
	root.add_theme_stylebox_override("panel", sb)

	# Tema lokal: seluruh Label di dalam nota otomatis memakai rasa mesin tik.
	var local: Theme = Theme.new()
	local.default_font = cozy_font(2)
	local.default_font_size = FONT_BODY
	local.set_color("font_color", "Label", Palette.TEXT)
	local.set_constant("line_spacing", "Label", 6)
	root.theme = local

	var vine: VineBorder = VineBorder.new()
	vine.name = "Vine"
	root.add_child(vine)

	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	_set_margins(pad, 26, 26, 22, 22)
	root.add_child(pad)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	pad.add_child(body)

	root.set_meta("body", body)
	root.set_meta("vine", vine)
	return root


## Papan tulis kapur Pasar Bahan Baku ala toko kelontong tempo dulu (GDD 7):
## bidang batu tulis gelap, bingkai kayu pinus tebal, tinta kapur terang.
static func chalkboard_panel() -> PanelContainer:
	var root: PanelContainer = PanelContainer.new()
	root.name = "Chalkboard"

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Palette.CHALKBOARD
	sb.set_corner_radius_all(18)
	sb.corner_detail = 10
	sb.anti_aliasing = true
	sb.set_border_width_all(14)
	sb.border_color = Palette.PINE_WOOD
	sb.set_content_margin_all(8.0)
	sb.shadow_color = Palette.SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0.0, 5.0)
	root.add_theme_stylebox_override("panel", sb)

	# Tema lokal: tinta kapur untuk seluruh teks di dalam papan.
	var local: Theme = Theme.new()
	local.default_font = cozy_font(1)
	local.default_font_size = FONT_BODY
	local.set_color("font_color", "Label", Palette.CHALK_WHITE)
	root.theme = local

	var dust: ChalkDust = ChalkDust.new()
	dust.name = "Dust"
	root.add_child(dust)

	var pad: MarginContainer = MarginContainer.new()
	pad.name = "Pad"
	_set_margins(pad, 20, 20, 16, 26)
	root.add_child(pad)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 10)
	pad.add_child(body)

	root.set_meta("body", body)
	root.set_meta("ink", Palette.CHALK_WHITE)
	return root


# ---------------------------------------------------------------------------
# Tombol & teks
# ---------------------------------------------------------------------------

## Tombol pil empuk. [param kind] = "primary" | "secondary" | "danger" | "ghost".
## Setiap tombol otomatis memantul (GDD 7 "squishy bounce") dan berbunyi
## ketukan kayu lembut saat ditekan.
static func button(text: String, kind := "primary") -> Button:
	var fill: Color = Palette.GOLDEN_CRUST
	var fg: Color = Palette.FLOUR_WHITE
	var edge: Color = Palette.CARAMEL
	var ghost: bool = false
	match kind:
		"secondary":
			fill = Palette.VANILLA_CREAM
			fg = Palette.TEXT
			edge = Color(Palette.UI_WOOD, 0.45)
		"danger":
			fill = Palette.DANGER
			fg = Palette.FLOUR_WHITE
			edge = Palette.DANGER.darkened(0.28)
		"ghost":
			fill = Color(Palette.UI_CREAM, 0.0)
			fg = Palette.UI_WOOD
			edge = Color(Palette.UI_WOOD, 0.55)
			ghost = true
		_:
			pass

	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(TOUCH_MIN * 2.0, TOUCH_MIN)
	b.clip_text = false
	b.add_theme_font_override("font", cozy_font(0))
	b.add_theme_font_size_override("font_size", FONT_BODY)
	b.add_theme_color_override("font_color", fg)
	b.add_theme_color_override("font_hover_color", fg)
	b.add_theme_color_override("font_pressed_color", fg)
	b.add_theme_color_override("font_focus_color", fg)
	b.add_theme_color_override("font_disabled_color", Color(fg, 0.55))
	b.add_theme_stylebox_override("normal", _pill(fill, edge, ghost, 0.0))
	b.add_theme_stylebox_override("hover", _pill(fill.lightened(0.10), edge, ghost, 0.0))
	b.add_theme_stylebox_override("pressed", _pill(fill.darkened(0.12), edge, ghost, 2.0))
	b.add_theme_stylebox_override("disabled", _pill(Color(fill, 0.40), Color(edge, 0.30), ghost, 0.0))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.pivot_offset = b.custom_minimum_size * 0.5

	# Titik putar selalu di tengah agar pantulan squash & stretch simetris.
	b.resized.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
	)
	b.button_down.connect(func() -> void:
		AudioBus.sfx("tap")
		ProceduralAnimationSystem.press_bounce(b)
	)
	return b


## Tombol IKON persegi: satu gambar, tanpa teks (GDD 7 "tap-first").
##
## `tooltip` WAJIB diisi. Ikon tanpa teks hanya bisa ditebak dari gambarnya, dan
## tebakan yang meleset di tombol "Pecat" jauh lebih mahal daripada tebakan yang
## meleset di tombol "Pasar" — jadi setiap ikon membawa namanya sendiri untuk
## pemain desktop/web yang mengarahkan tetikus.
##
## Sisinya dikunci ke TOUCH_MIN: ikon boleh mengecil, zona sentuhnya tidak
## (GDD 12.4: hitbox minimal 48x48 dp).
static func icon_button(icon_name: String, tooltip: String, kind := "secondary",
		icon_size := 26, tint := Palette.UI_WOOD) -> Button:
	var b: Button = button("", kind)
	b.tooltip_text = tooltip
	b.custom_minimum_size = Vector2(TOUCH_MIN, TOUCH_MIN)
	b.pivot_offset = b.custom_minimum_size * 0.5

	# Ikon dipasang sebagai anak yang MENGABAIKAN tetikus: yang menangkap
	# ketukan tetap tombolnya, jadi seluruh 48x48 tetap bisa ditekan.
	var ic: IconCanvas = icon(icon_name, icon_size, tint)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center: CenterContainer = CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.add_child(ic)
	b.add_child(center)
	# Gambarnya disimpan di meta supaya bisa DIGANTI di tempat (jeda <-> lanjut)
	# tanpa membangun ulang tombolnya.
	b.set_meta("icon", ic)
	return b


## Baris "ikon + nilai" untuk HUD: ikon yang menjelaskan artinya, teks yang
## membawa angkanya. Mengembalikan HBox; labelnya ada di meta "value".
static func icon_value(icon_name: String, text: String, icon_size := 22,
		font_size := 18, tint := Palette.UI_WOOD) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(icon(icon_name, icon_size, tint))
	var l: Label = label(text, font_size)
	h.add_child(l)
	h.set_meta("value", l)
	return h


## Label teks isi dengan font bawaan, warna tinta hangat, dan jarak baris enak.
static func label(text: String, size := 18, color := Palette.TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	l.add_theme_font_override("font", cozy_font(0))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", maxi(3, int(round(float(size) * 0.28))))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Judul layar / panel: lebih besar, rata tengah, berspasi huruf sedikit lega.
static func title(text: String, size := 28) -> Label:
	var l: Label = label(text, size, Palette.UI_WOOD)
	l.add_theme_font_override("font", cozy_font(1))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", maxi(4, int(round(float(size) * 0.22))))
	return l


## Label bergaya mesin tik untuk nota Daily Summary (GDD 11.7).
static func typewriter_label(text: String, size := 18, color := Palette.TEXT) -> Label:
	var l: Label = label(text, size, color)
	l.add_theme_font_override("font", cozy_font(2))
	return l


## Label tinta kapur untuk isi [method chalkboard_panel].
static func chalk_label(text: String, size := 18) -> Label:
	var l: Label = label(text, size, Palette.CHALK_WHITE)
	l.add_theme_font_override("font", cozy_font(1))
	return l


## Garis pemisah putus-putus bergaya nota (GDD 11.7 "dashed").
static func dashed_separator(color := Palette.UI_WOOD) -> Control:
	var d: DashedSeparator = DashedSeparator.new()
	d.line_color = Color(color, 0.50)
	return d


# ---------------------------------------------------------------------------
# Widget khusus
# ---------------------------------------------------------------------------

## Bar kapasitas gudang (GDD 12.3). Menampilkan "N / M" dan berubah menjadi
## warna peringatan lalu bahaya saat gudang mendekati penuh.
## Perbarui nilainya dengan `bar.set_values(value, max_value)`.
static func pantry_bar(value: int, max_value: int) -> Control:
	var bar: PantryBar = PantryBar.new()
	bar.name = "PantryBar"
	bar.set_values(value, max_value)
	return bar


## Baris slider berlabel dengan pembacaan nilai langsung (GDD 7: slider harga
## di Buku Resep). Tinggi baris dan tombol geser >= 48 px agar ramah jari.
static func slider_row(label_text: String, min_v: float, max_v: float, value: float) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "SliderRow"
	row.add_theme_constant_override("separation", 14)
	row.custom_minimum_size = Vector2(0.0, TOUCH_MIN)

	var cap: Label = label(label_text, FONT_BODY, Palette.TEXT)
	cap.name = "Caption"
	cap.custom_minimum_size = Vector2(110.0, TOUCH_MIN)
	row.add_child(cap)

	var lo: float = minf(min_v, max_v)
	var hi: float = maxf(max_v, lo + 0.001)
	var sl: HSlider = HSlider.new()
	sl.name = "Slider"
	sl.min_value = lo
	sl.max_value = hi
	sl.step = 1.0 if (hi - lo) >= 10.0 else 0.1
	sl.value = clampf(value, lo, hi)
	sl.focus_mode = Control.FOCUS_NONE
	sl.custom_minimum_size = Vector2(150.0, TOUCH_MIN)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_style_slider(sl)
	row.add_child(sl)

	var out: Label = label(_fmt_value(sl.value, sl.step), FONT_BODY, Palette.UI_WOOD)
	out.name = "Value"
	out.custom_minimum_size = Vector2(84.0, TOUCH_MIN)
	out.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(out)

	sl.value_changed.connect(func(v: float) -> void:
		out.text = ProceduralUIFactory._fmt_value(v, sl.step)
	)

	row.set_meta("slider", sl)
	row.set_meta("value_label", out)
	return row


## Kartu polaroid / ID Card staf (GDD 3.4 & 7): bingkai foto putih bersudut
## membulat, potret chibi prosedural, nama, tier bintang, gaji, dan kecepatan.
## Potret digambar di `_draw()` — TIDAK memakai SubViewport 3D.
static func polaroid(staff_id: String) -> Control:
	var root: PanelContainer = PanelContainer.new()
	root.name = "Polaroid"
	root.custom_minimum_size = Vector2(196.0, 300.0)

	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Palette.FLOUR_WHITE
	sb.set_corner_radius_all(14)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.set_border_width_all(2)
	sb.border_color = Color(Palette.UI_WOOD, 0.18)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 18.0
	sb.shadow_color = Palette.SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0.0, 4.0)
	root.add_theme_stylebox_override("panel", sb)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.add_theme_constant_override("separation", 6)
	root.add_child(body)
	root.set_meta("body", body)
	root.set_meta("staff_id", staff_id)

	var e: Dictionary = StaffDB.entry(staff_id)
	if e.is_empty():
		var miss: Label = label("Kandidat tidak dikenal", FONT_SMALL, Palette.TEXT_MUTED)
		miss.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		body.add_child(miss)
		return root

	var role: String = String(e.get("role", "kasir"))
	var tier: int = clampi(int(e.get("tier", 1)), 1, 5)
	var visual: Dictionary = e.get("visual", {})
	var extra: Dictionary = e.get("extra", {})

	var face: ChibiPortrait = ChibiPortrait.new()
	face.name = "Portrait"
	face.configure(visual, role, tier)
	body.add_child(face)
	root.set_meta("portrait", face)

	var nama: Label = label(String(e.get("name", staff_id)), 20, Palette.TEXT)
	nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(nama)

	var jabatan: String = "Kasir" if role == "kasir" else "Baker"
	var peran: Label = label("%s · Tier %d" % [jabatan, tier], FONT_SMALL, Palette.TEXT_MUTED)
	peran.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(peran)

	var stars: HBoxContainer = HBoxContainer.new()
	stars.name = "Tier"
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 2)
	for i in 5:
		var on: bool = i < tier
		stars.add_child(icon("star", 15, Palette.GOLD_STAR if on else Color(Palette.TEXT_MUTED, 0.28)))
	body.add_child(stars)

	var gaji: float = float(e.get("salary", 0))
	body.add_child(_stat_row("coin", Palette.GOLD_STAR, "%s / hari" % GameConfig.kr(gaji)))

	var speed: float = float(e.get("speed", 0.0))
	var speed_text: String = ""
	if role == "baker":
		speed_text = "x%.2f kecepatan" % speed
	else:
		speed_text = "%.1f dtk / pelanggan" % speed
	body.add_child(_stat_row("bolt", Palette.WARMER_LAMP, speed_text))

	if role == "baker" and extra.has("anti_burn"):
		var ab: int = int(round(float(extra["anti_burn"]) * 100.0))
		body.add_child(_stat_row("fire", Palette.DANGER, "%d%% anti-gosong" % ab))

	return root


## Ikon prosedural siap pakai (lihat [IconCanvas] untuk daftar 30 namanya).
static func icon(name: String, size := 32, color := Color.WHITE) -> IconCanvas:
	var ic: IconCanvas = IconCanvas.new()
	ic.icon_name = name
	ic.icon_size = float(size)
	ic.icon_color = color
	return ic


# ---------------------------------------------------------------------------
# Tema global
# ---------------------------------------------------------------------------

## Pasang tema cozy GDD 7 ke sebuah subtree UI. Cukup dipanggil di akar tiap
## layar; seluruh anaknya mewarisi font, warna, dan StyleBox yang sama.
static func apply_theme(root: Control) -> void:
	if root == null or not is_instance_valid(root):
		return
	root.theme = build_theme()


## Bangun (sekali) Theme bersama untuk seluruh game.
static func build_theme() -> Theme:
	if _theme_cache != null:
		return _theme_cache

	var t: Theme = Theme.new()
	t.default_font = cozy_font(0)
	t.default_font_size = FONT_BODY
	t.default_base_scale = 1.0

	# --- Label ---
	t.set_color("font_color", "Label", Palette.TEXT)
	t.set_color("font_outline_color", "Label", Color(0.0, 0.0, 0.0, 0.0))
	t.set_font_size("font_size", "Label", FONT_BODY)
	t.set_constant("line_spacing", "Label", 5)
	t.set_constant("outline_size", "Label", 0)

	# --- Panel & PanelContainer ---
	t.set_stylebox("panel", "Panel", panel(Palette.PANEL, RADIUS_PANEL, true))
	t.set_stylebox("panel", "PanelContainer", panel(Palette.PANEL, RADIUS_PANEL, true))
	t.set_stylebox("panel", "ScrollContainer", StyleBoxEmpty.new())

	# --- Button (bentuk pil, GDD 7) ---
	var fill: Color = Palette.GOLDEN_CRUST
	t.set_stylebox("normal", "Button", _pill(fill, Palette.CARAMEL, false, 0.0))
	t.set_stylebox("hover", "Button", _pill(fill.lightened(0.10), Palette.CARAMEL, false, 0.0))
	t.set_stylebox("pressed", "Button", _pill(fill.darkened(0.12), Palette.CARAMEL, false, 2.0))
	t.set_stylebox("disabled", "Button",
		_pill(Color(fill, 0.40), Color(Palette.CARAMEL, 0.30), false, 0.0))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_hover_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_pressed_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_focus_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_disabled_color", "Button", Color(Palette.FLOUR_WHITE, 0.55))
	t.set_font_size("font_size", "Button", FONT_BODY)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("outline_size", "Button", 0)

	# --- HSlider / VSlider (thumb besar untuk sentuh) ---
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(Palette.UI_WOOD, 0.16)
	track.set_corner_radius_all(6)
	track.anti_aliasing = true
	track.content_margin_top = 6.0
	track.content_margin_bottom = 6.0
	track.content_margin_left = 6.0
	track.content_margin_right = 6.0

	var filled: StyleBoxFlat = StyleBoxFlat.new()
	filled.bg_color = Palette.GOLDEN_CRUST
	filled.set_corner_radius_all(6)
	filled.anti_aliasing = true

	var filled_hi: StyleBoxFlat = filled.duplicate()
	filled_hi.bg_color = Palette.GOLDEN_CRUST.lightened(0.12)

	for slider_type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", slider_type, track)
		t.set_stylebox("grabber_area", slider_type, filled)
		t.set_stylebox("grabber_area_highlight", slider_type, filled_hi)
		t.set_icon("grabber", slider_type, _grabber_texture(false))
		t.set_icon("grabber_highlight", slider_type, _grabber_texture(true))
		t.set_icon("grabber_disabled", slider_type, _grabber_texture(false))
		t.set_constant("center_grabber", slider_type, 1)
		t.set_constant("grabber_offset", slider_type, 0)

	# --- ProgressBar ---
	var pb_bg: StyleBoxFlat = StyleBoxFlat.new()
	pb_bg.bg_color = Color(Palette.UI_WOOD, 0.14)
	pb_bg.set_corner_radius_all(12)
	pb_bg.anti_aliasing = true
	var pb_fill: StyleBoxFlat = StyleBoxFlat.new()
	pb_fill.bg_color = Palette.SUCCESS
	pb_fill.set_corner_radius_all(12)
	pb_fill.anti_aliasing = true
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", Palette.TEXT)

	# --- ScrollBar ---
	var sc_bg: StyleBoxFlat = StyleBoxFlat.new()
	sc_bg.bg_color = Color(Palette.UI_WOOD, 0.10)
	sc_bg.set_corner_radius_all(8)
	sc_bg.set_content_margin_all(2.0)
	var sc_grab: StyleBoxFlat = StyleBoxFlat.new()
	sc_grab.bg_color = Color(Palette.UI_WOOD, 0.45)
	sc_grab.set_corner_radius_all(8)
	sc_grab.set_content_margin_all(2.0)
	var sc_grab_hi: StyleBoxFlat = sc_grab.duplicate()
	sc_grab_hi.bg_color = Color(Palette.UI_WOOD, 0.62)
	for bar_type in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar_type, sc_bg)
		t.set_stylebox("scroll_focus", bar_type, sc_bg)
		t.set_stylebox("grabber", bar_type, sc_grab)
		t.set_stylebox("grabber_highlight", bar_type, sc_grab_hi)
		t.set_stylebox("grabber_pressed", bar_type, sc_grab_hi)

	# --- Separator ---
	t.set_stylebox("separator", "HSeparator", _line_stylebox(Color(Palette.UI_WOOD, 0.22), false))
	t.set_stylebox("separator", "VSeparator", _line_stylebox(Color(Palette.UI_WOOD, 0.22), true))
	t.set_constant("separation", "HSeparator", 8)
	t.set_constant("separation", "VSeparator", 8)

	# --- Container ---
	t.set_constant("separation", "HBoxContainer", 12)
	t.set_constant("separation", "VBoxContainer", 10)
	t.set_constant("h_separation", "GridContainer", 12)
	t.set_constant("v_separation", "GridContainer", 12)
	t.set_constant("margin_left", "MarginContainer", 12)
	t.set_constant("margin_right", "MarginContainer", 12)
	t.set_constant("margin_top", "MarginContainer", 10)
	t.set_constant("margin_bottom", "MarginContainer", 10)

	_theme_cache = t
	return t


## Font bawaan Godot dibungkus [FontVariation] agar bisa diatur spasi hurufnya
## (satu-satunya cara "tipografi bulat lega" tanpa memuat berkas .ttf).
static func cozy_font(glyph_spacing: int = 0) -> FontVariation:
	if _font_cache.has(glyph_spacing):
		return _font_cache[glyph_spacing]
	var fv: FontVariation = FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.set_spacing(TextServer.SPACING_GLYPH, glyph_spacing)
	fv.set_spacing(TextServer.SPACING_TOP, 1)
	fv.set_spacing(TextServer.SPACING_BOTTOM, 1)
	_font_cache[glyph_spacing] = fv
	return fv


# ---------------------------------------------------------------------------
# Utilitas layar (GDD 7)
# ---------------------------------------------------------------------------

## Inset aman layar dalam satuan piksel GUI: Vector4(kiri, atas, kanan, bawah).
## Melindungi HUD dari punch-hole/notch dan sudut membulat ponsel modern.
## Di desktop dan web selalu nol karena jendela tidak punya area terpotong.
static func safe_area_margin() -> Vector4:
	var os_name: String = OS.get_name()
	if os_name != "Android" and os_name != "iOS":
		return Vector4.ZERO
	var win: Vector2i = DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	var left: float = maxf(float(safe.position.x), 0.0)
	var top: float = maxf(float(safe.position.y), 0.0)
	var right: float = maxf(float(win.x - safe.end.x), 0.0)
	var bottom: float = maxf(float(win.y - safe.end.y), 0.0)
	var k: float = _gui_scale(Vector2(win))
	return Vector4(left / k, top / k, right / k, bottom / k)


## Notifikasi sekejap di tepi atas layar (GDD 7). Muncul memudar masuk,
## bertahan [constant TOAST_SECONDS] detik, lalu hilang dan membebaskan diri.
static func toast(parent: CanvasLayer, text: String, icon_name: String) -> void:
	if parent == null or not is_instance_valid(parent):
		return

	var holder: Control = Control.new()
	holder.name = "Toast"
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	parent.add_child(holder)

	var inset: Vector4 = safe_area_margin()
	var slot: CenterContainer = CenterContainer.new()
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_anchors_preset(Control.PRESET_TOP_WIDE)
	slot.offset_left = inset.x
	slot.offset_right = -inset.z
	slot.offset_top = inset.y + 18.0
	slot.offset_bottom = inset.y + 100.0
	holder.add_child(slot)

	var box: PanelContainer = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = panel(Palette.PANEL, 24, true)
	sb.border_color = Color(Palette.UI_WOOD, 0.35)
	sb.content_margin_left = 20.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	box.add_theme_stylebox_override("panel", sb)
	slot.add_child(box)

	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	if not icon_name.is_empty():
		row.add_child(icon(icon_name, 26, Palette.GOLDEN_CRUST))
	row.add_child(label(text, FONT_BODY, Palette.TEXT))

	holder.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw: Tween = holder.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(holder, "modulate:a", 1.0, 0.18)
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.tween_callback(holder.queue_free)


## Container isi dari panel/kartu hasil factory ini (meta "body").
## Mengembalikan node itu sendiri bila tidak punya meta tersebut.
static func content_of(node: Node) -> Node:
	if node == null or not is_instance_valid(node):
		return null
	if node.has_meta("body"):
		var b: Variant = node.get_meta("body")
		if b is Node and is_instance_valid(b):
			return b
	return node


## Titik-titik persegi panjang bersudut membulat, dipakai bersama oleh seluruh
## kelas dalam berkas ini saat menggambar di `_draw()`.
static func rounded_points(rect: Rect2, radius: float, steps: int = 4) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	var w: float = rect.size.x
	var h: float = rect.size.y
	if w <= 0.0 or h <= 0.0:
		return out
	var r: float = clampf(radius, 0.0, minf(w, h) * 0.5)
	if r <= 0.5:
		out.append(rect.position)
		out.append(Vector2(rect.end.x, rect.position.y))
		out.append(rect.end)
		out.append(Vector2(rect.position.x, rect.end.y))
		return out
	var cx: Array = [rect.end.x - r, rect.end.x - r, rect.position.x + r, rect.position.x + r]
	var cy: Array = [rect.position.y + r, rect.end.y - r, rect.end.y - r, rect.position.y + r]
	var a0: Array = [-PI * 0.5, 0.0, PI * 0.5, PI]
	var st: int = maxi(steps, 1)
	for i in 4:
		var px: float = cx[i]
		var py: float = cy[i]
		var base: float = a0[i]
		for k in st + 1:
			var a: float = base + PI * 0.5 * (float(k) / float(st))
			out.append(Vector2(px + cos(a) * r, py + sin(a) * r))
	return out


# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

## StyleBox tombol pil. [param shift] menggeser isi ke bawah saat status ditekan.
static func _pill(fill: Color, edge: Color, ghost: bool, shift: float) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = fill
	sb.set_corner_radius_all(RADIUS_PILL)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.set_border_width_all(3 if ghost else 2)
	sb.border_color = edge
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 12.0 + shift
	sb.content_margin_bottom = 12.0 - shift
	if not ghost:
		sb.shadow_color = Palette.SHADOW
		sb.shadow_size = 6
		sb.shadow_offset = Vector2(0.0, 3.0)
	return sb


static func _line_stylebox(color: Color, vertical: bool) -> StyleBoxLine:
	var sb: StyleBoxLine = StyleBoxLine.new()
	sb.color = color
	sb.thickness = 2
	sb.vertical = vertical
	return sb


static func _line_separator(color: Color) -> HSeparator:
	var sep: HSeparator = HSeparator.new()
	sep.add_theme_stylebox_override("separator", _line_stylebox(color, false))
	return sep


static func _set_margins(m: MarginContainer, left: int, right: int, top: int, bottom: int) -> void:
	m.add_theme_constant_override("margin_left", left)
	m.add_theme_constant_override("margin_right", right)
	m.add_theme_constant_override("margin_top", top)
	m.add_theme_constant_override("margin_bottom", bottom)


static func _stat_row(icon_name: String, tint: Color, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.add_child(icon(icon_name, 18, tint))
	row.add_child(label(text, FONT_SMALL, Palette.TEXT))
	return row


static func _fmt_value(v: float, step: float) -> String:
	if step >= 1.0:
		return str(int(round(v)))
	return "%.1f" % v


static func _style_slider(sl: Range) -> void:
	var track: StyleBoxFlat = StyleBoxFlat.new()
	track.bg_color = Color(Palette.UI_WOOD, 0.16)
	track.set_corner_radius_all(7)
	track.anti_aliasing = true
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	track.content_margin_left = 7.0
	track.content_margin_right = 7.0

	var filled: StyleBoxFlat = StyleBoxFlat.new()
	filled.bg_color = Palette.GOLDEN_CRUST
	filled.set_corner_radius_all(7)
	filled.anti_aliasing = true

	var filled_hi: StyleBoxFlat = filled.duplicate()
	filled_hi.bg_color = Palette.GOLDEN_CRUST.lightened(0.12)

	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", filled)
	sl.add_theme_stylebox_override("grabber_area_highlight", filled_hi)
	sl.add_theme_icon_override("grabber", _grabber_texture(false))
	sl.add_theme_icon_override("grabber_highlight", _grabber_texture(true))
	sl.add_theme_icon_override("grabber_disabled", _grabber_texture(false))
	sl.add_theme_constant_override("center_grabber", 1)
	sl.add_theme_constant_override("grabber_offset", 0)


## Tombol geser bundar 44 px dibangkitkan piksel demi piksel (bukan berkas PNG).
static func _grabber_texture(highlight: bool) -> ImageTexture:
	if highlight and _grabber_hi_cache != null:
		return _grabber_hi_cache
	if not highlight and _grabber_cache != null:
		return _grabber_cache

	var d: int = 44
	var fill: Color = Palette.GOLDEN_CRUST
	if highlight:
		fill = Palette.GOLDEN_CRUST.lightened(0.18)
	var ring: Color = Palette.FLOUR_WHITE
	var img: Image = Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))

	var mid: float = (float(d) - 1.0) * 0.5
	var r_in: float = mid - maxf(3.0, float(d) * 0.13)
	for y in d:
		for x in d:
			var dist: float = Vector2(float(x) - mid, float(y) - mid).length()
			if dist > mid:
				continue
			var a: float = clampf(mid - dist, 0.0, 1.0)
			var col: Color = fill if dist <= r_in else ring
			img.set_pixel(x, y, Color(col.r, col.g, col.b, a))

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	if highlight:
		_grabber_hi_cache = tex
	else:
		_grabber_cache = tex
	return tex


## Faktor skala piksel layar nyata -> piksel GUI (stretch canvas_items/expand).
static func _gui_scale(window_size: Vector2) -> float:
	var base: Vector2 = Vector2(GameConfig.REF_RESOLUTION)
	var loop: MainLoop = Engine.get_main_loop()
	var tree: SceneTree = loop as SceneTree
	if tree != null and tree.root != null:
		var cs: Vector2i = tree.root.content_scale_size
		if cs.x > 0 and cs.y > 0:
			base = Vector2(cs)
	if base.x <= 0.0 or base.y <= 0.0:
		return 1.0
	return maxf(minf(window_size.x / base.x, window_size.y / base.y), 0.0001)


# ---------------------------------------------------------------------------
# Kelas gambar internal (Control dengan _draw sendiri, tanpa class_name global)
# ---------------------------------------------------------------------------

## Bar kapasitas gudang: jalur membulat + isian berwarna + teks "N / M".
class PantryBar extends Control:

	var value: int = 0
	var max_value: int = 1

	func _init() -> void:
		custom_minimum_size = Vector2(180.0, 30.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		size_flags_vertical = Control.SIZE_SHRINK_CENTER

	## Perbarui isi gudang; menggambar ulang otomatis.
	func set_values(v: int, m: int) -> void:
		value = maxi(v, 0)
		max_value = maxi(m, 1)
		queue_redraw()

	## Rasio keterisian 0..1.
	func ratio() -> float:
		return clampf(float(value) / float(max_value), 0.0, 1.0)

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if r.size.x < 8.0 or r.size.y < 6.0:
			return
		var rad: float = r.size.y * 0.5
		draw_colored_polygon(ProceduralUIFactory.rounded_points(r, rad),
			Color(Palette.UI_WOOD, 0.14))

		var k: float = ratio()
		if k > 0.001:
			var w: float = maxf(r.size.y, r.size.x * k)
			draw_colored_polygon(
				ProceduralUIFactory.rounded_points(Rect2(r.position, Vector2(w, r.size.y)), rad),
				_fill_color(k))

		var edge: PackedVector2Array = ProceduralUIFactory.rounded_points(r, rad)
		if edge.size() > 2:
			edge.append(edge[0])
			draw_polyline(edge, Color(Palette.UI_WOOD, 0.32), 2.0, true)

		var f: Font = ThemeDB.fallback_font
		var fs: int = int(clampf(r.size.y * 0.52, 11.0, 18.0))
		var txt: String = "%d / %d" % [value, max_value]
		var baseline: float = r.size.y * 0.5 + (f.get_ascent(fs) - f.get_descent(fs)) * 0.5
		var tint: Color = Palette.TEXT if k < 0.5 else Palette.FLOUR_WHITE
		draw_string(f, Vector2(0.0, baseline + 1.0), txt, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, fs, Color(0.0, 0.0, 0.0, 0.15))
		draw_string(f, Vector2(0.0, baseline), txt, HORIZONTAL_ALIGNMENT_CENTER,
			r.size.x, fs, tint)

	func _fill_color(k: float) -> Color:
		if k >= ProceduralUIFactory.PANTRY_FULL:
			return Palette.DANGER
		if k >= ProceduralUIFactory.PANTRY_WARN:
			return Palette.WARNING
		return Palette.SUCCESS


## Bingkai sulur daun kecil untuk nota Daily Summary (GDD 11.1).
class VineBorder extends Control:

	var inset: float = 12.0
	var vine_color: Color = Color(0.42, 0.60, 0.42, 0.55)
	var leaf_color: Color = Color(0.56, 0.74, 0.55, 0.65)

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size).grow(-inset)
		if r.size.x < 40.0 or r.size.y < 40.0:
			return
		var tl: Vector2 = r.position
		var tr: Vector2 = Vector2(r.end.x, r.position.y)
		var br: Vector2 = r.end
		var bl: Vector2 = Vector2(r.position.x, r.end.y)
		_edge(tl, tr, Vector2(0.0, 1.0))
		_edge(tr, br, Vector2(-1.0, 0.0))
		_edge(br, bl, Vector2(0.0, -1.0))
		_edge(bl, tl, Vector2(1.0, 0.0))
		for p in [tl, tr, br, bl]:
			draw_circle(p, 3.5, vine_color)

	## Satu sisi sulur: garis bergelombang + daun bergantian sisi.
	func _edge(a: Vector2, b: Vector2, inward: Vector2) -> void:
		var span: float = a.distance_to(b)
		if span < 24.0:
			return
		var dir: Vector2 = (b - a) / span
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var steps: int = maxi(12, int(span / 9.0))
		var pts: PackedVector2Array = PackedVector2Array()
		for i in steps + 1:
			var t: float = float(i) / float(steps)
			pts.append(a + dir * (span * t) + perp * (sin(t * TAU * 3.0) * 2.6))
		draw_polyline(pts, vine_color, 2.0, true)

		var leaves: int = maxi(3, int(span / 34.0))
		for i in leaves:
			var t: float = (float(i) + 0.5) / float(leaves)
			var base: Vector2 = a + dir * (span * t)
			var side: float = 1.0 if i % 2 == 0 else -1.0
			_leaf(base, (perp * side + inward * 0.4).normalized(), 9.0)

	func _leaf(base: Vector2, dir: Vector2, length: float) -> void:
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([
			base,
			base + dir * (length * 0.5) + perp * (length * 0.34),
			base + dir * length,
			base + dir * (length * 0.5) - perp * (length * 0.34),
		]), leaf_color)


## Sapuan kapur samar + ambalan kayu untuk papan Pasar Bahan Baku (GDD 7).
class ChalkDust extends Control:

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if r.size.x < 40.0 or r.size.y < 40.0:
			return
		var dust: Color = Color(Palette.CHALK_WHITE, 0.055)
		for i in 5:
			var y: float = r.size.y * (0.16 + 0.17 * float(i))
			var x: float = r.size.x * (0.28 + 0.14 * float(i % 3))
			draw_arc(Vector2(x, y), r.size.x * 0.30, PI * 0.15, PI * 0.85, 18, dust, 7.0, true)
		var frame: Rect2 = r.grow(-9.0)
		if frame.size.x > 10.0 and frame.size.y > 10.0:
			draw_rect(frame, Color(Palette.CHALK_WHITE, 0.14), false, 2.0)
		var ledge: Rect2 = Rect2(0.0, r.size.y - 9.0, r.size.x, 9.0)
		draw_colored_polygon(ProceduralUIFactory.rounded_points(ledge, 4.0),
			Color(Palette.PINE_WOOD, 0.85))


## Garis pemisah putus-putus bergaya nota kasir (GDD 11.7).
class DashedSeparator extends Control:

	var line_color: Color = Color(0.549, 0.345, 0.208, 0.5)
	var dash: float = 8.0
	var gap: float = 6.0
	var thickness: float = 2.0

	func _init() -> void:
		custom_minimum_size = Vector2(0.0, 12.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	func _draw() -> void:
		var step: float = maxf(dash + gap, 1.0)
		var y: float = size.y * 0.5
		var x: float = 0.0
		while x < size.x:
			var x2: float = minf(x + dash, size.x)
			draw_line(Vector2(x, y), Vector2(x2, y), line_color, thickness, true)
			x += step


## Potret chibi 2D untuk kartu polaroid staf (GDD 3.4, 3.5, 7).
## Seluruh bentuk digambar dari lingkaran + poligon membulat — tanpa gambar,
## tanpa SubViewport 3D.
class ChibiPortrait extends Control:

	var skin: Color = Color(0.949, 0.788, 0.627)
	var hair: Color = Color(0.169, 0.129, 0.094)
	var apron: Color = Color(1.0, 0.984, 0.961)
	var backdrop: Color = Color(0.976, 0.941, 0.878)
	var hair_style: String = "pendek"
	var hat: String = "none"
	var accessory: Array = []
	var chubby: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(168.0, 156.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL

	## Isi parameter visual dari `StaffDB.entry(id).visual`.
	func configure(visual: Dictionary, role: String, tier: int) -> void:
		var v_skin: Variant = visual.get("skin")
		if v_skin is Color:
			skin = v_skin
		var v_hair: Variant = visual.get("hair")
		if v_hair is Color:
			hair = v_hair
		var v_apron: Variant = visual.get("apron")
		if v_apron is Color:
			apron = v_apron
		else:
			apron = Palette.apron_for_tier(role, tier)
		var v_acc: Variant = visual.get("accessory", [])
		if v_acc is Array:
			accessory = v_acc
		else:
			accessory = []
		hair_style = String(visual.get("hair_style", "pendek"))
		hat = String(visual.get("hat", "none"))
		chubby = clampf(float(visual.get("chubby", 0.0)), 0.0, 1.0)
		backdrop = Palette.apron_for_tier(role, tier).lerp(Palette.VANILLA_CREAM, 0.72)
		queue_redraw()

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if r.size.x < 24.0 or r.size.y < 24.0:
			return
		draw_colored_polygon(ProceduralUIFactory.rounded_points(r, 10.0), backdrop)

		var s: float = minf(r.size.x, r.size.y)
		var hr: float = s * 0.23
		var c: Vector2 = Vector2(r.size.x * 0.5, r.size.y * 0.55)
		var body_top: float = c.y + hr * 0.68
		var body_w: float = s * (0.66 + chubby * 0.16)
		var body_h: float = maxf(r.size.y - body_top - s * 0.02, hr * 0.7)

		_hair_back(c, hr)

		# Badan + celemek (GDD 3.4: warna celemek mencerminkan tier keahlian).
		draw_colored_polygon(ProceduralUIFactory.rounded_points(
			Rect2(c.x - body_w * 0.5, body_top, body_w, body_h), body_w * 0.30), apron)
		# Kerah V memperlihatkan kulit leher.
		draw_colored_polygon(PackedVector2Array([
			Vector2(c.x - hr * 0.42, body_top - hr * 0.08),
			Vector2(c.x + hr * 0.42, body_top - hr * 0.08),
			Vector2(c.x, body_top + hr * 0.52),
		]), skin)

		# Telinga lalu kepala bulat khas chibi.
		draw_circle(Vector2(c.x - hr * 0.98, c.y + hr * 0.10), hr * 0.20, skin)
		draw_circle(Vector2(c.x + hr * 0.98, c.y + hr * 0.10), hr * 0.20, skin)
		draw_circle(c, hr, skin)

		_hair_front(c, hr)
		_face(c, hr)
		_accessories(c, hr, body_top)
		_hat(c, hr)

	# --- rambut -------------------------------------------------------------

	func _hair_back(c: Vector2, hr: float) -> void:
		match hair_style:
			"kuncir_ganda":
				draw_circle(c + Vector2(-hr * 1.24, -hr * 0.05), hr * 0.36, hair)
				draw_circle(c + Vector2(hr * 1.24, -hr * 0.05), hr * 0.36, hair)
				draw_circle(c + Vector2(-hr * 1.32, hr * 0.42), hr * 0.26, hair)
				draw_circle(c + Vector2(hr * 1.32, hr * 0.42), hr * 0.26, hair)
			"panjang_kepang":
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 1.06, c.y - hr * 0.60, hr * 2.12, hr * 1.90), hr * 0.52), hair)
				for i in 3:
					draw_circle(c + Vector2(hr * 0.92, hr * (1.10 + 0.40 * float(i))), hr * 0.20, hair)
			"bob":
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 1.12, c.y - hr * 0.90, hr * 2.24, hr * 1.85), hr * 0.62), hair)
			"ikal", "ombre":
				draw_circle(c + Vector2(-hr * 1.02, hr * 0.26), hr * 0.42, hair)
				draw_circle(c + Vector2(hr * 1.02, hr * 0.26), hr * 0.42, hair)
				draw_circle(c + Vector2(-hr * 0.88, hr * 0.76), hr * 0.32, hair)
				draw_circle(c + Vector2(hr * 0.88, hr * 0.76), hr * 0.32, hair)
			"sanggul":
				draw_circle(c + Vector2(0.0, -hr * 1.12), hr * 0.34, hair)
			_:
				pass

	func _hair_front(c: Vector2, hr: float) -> void:
		if hair_style == "cepak":
			_hair_cap(c, hr * 1.01, -0.32)
		else:
			_hair_cap(c, hr * 1.05, -0.06)
		match hair_style:
			"belah_samping":
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x - hr * 1.02, c.y - hr * 0.30),
					Vector2(c.x - hr * 0.10, c.y - hr * 1.00),
					Vector2(c.x + hr * 0.74, c.y - hr * 0.32),
					Vector2(c.x - hr * 0.24, c.y - hr * 0.10),
				]), hair)
			"spike":
				for i in 5:
					var t: float = -0.70 + 0.35 * float(i)
					draw_colored_polygon(PackedVector2Array([
						Vector2(c.x + hr * (t - 0.17), c.y - hr * 0.84),
						Vector2(c.x + hr * t, c.y - hr * 1.34),
						Vector2(c.x + hr * (t + 0.17), c.y - hr * 0.84),
					]), hair)
			"ombre":
				var tip: Color = hair.lerp(Palette.PASTEL_STRAWBERRY, 0.62)
				draw_circle(c + Vector2(-hr * 1.00, hr * 0.62), hr * 0.30, tip)
				draw_circle(c + Vector2(hr * 1.00, hr * 0.62), hr * 0.30, tip)
			"jenggot":
				draw_arc(c + Vector2(0.0, hr * 0.08), hr * 0.90, PI * 0.16, PI * 0.84,
					18, hair, hr * 0.30, true)
			"sanggul":
				draw_circle(c + Vector2(0.0, -hr * 1.08), hr * 0.30, hair)
			_:
				pass

	## Tudung rambut: busur atas kepala ditutup garis lurus di bawahnya.
	func _hair_cap(c: Vector2, rad: float, cut: float) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		var steps: int = 18
		var a0: float = PI * 0.97
		var a1: float = TAU + PI * 0.03
		for i in steps + 1:
			var a: float = a0 + (a1 - a0) * (float(i) / float(steps))
			pts.append(c + Vector2(cos(a) * rad, sin(a) * rad))
		pts.append(c + Vector2(rad * 0.86, rad * cut))
		pts.append(c + Vector2(-rad * 0.86, rad * cut))
		draw_colored_polygon(pts, hair)

	# --- wajah --------------------------------------------------------------

	func _face(c: Vector2, hr: float) -> void:
		var eye: Color = Palette.DARK_CHOCOLATE
		var blush: Color = Color(Palette.ROSY_CHEEK, 0.75)
		draw_circle(c + Vector2(-hr * 0.60, hr * 0.30), hr * 0.17, blush)
		draw_circle(c + Vector2(hr * 0.60, hr * 0.30), hr * 0.17, blush)
		draw_circle(c + Vector2(-hr * 0.36, -hr * 0.02), hr * 0.125, eye)
		draw_circle(c + Vector2(hr * 0.36, -hr * 0.02), hr * 0.125, eye)
		draw_circle(c + Vector2(-hr * 0.31, -hr * 0.08), hr * 0.045, Palette.FLOUR_WHITE)
		draw_circle(c + Vector2(hr * 0.41, -hr * 0.08), hr * 0.045, Palette.FLOUR_WHITE)
		draw_arc(c + Vector2(0.0, hr * 0.18), hr * 0.24, PI * 0.18, PI * 0.82,
			14, eye, hr * 0.07, true)

	# --- aksesori & topi ----------------------------------------------------

	func _accessories(c: Vector2, hr: float, body_top: float) -> void:
		for item in accessory:
			var id: String = String(item)
			if id.begins_with("kacamata"):
				var rim: Color = Palette.GOLD_STAR if id != "kacamata_bulat" else Palette.DARK_CHOCOLATE
				_glasses(c, hr, rim)
				if id == "kacamata_rantai":
					draw_arc(c + Vector2(0.0, hr * 0.22), hr * 1.02, PI * 0.08, PI * 0.92,
						16, Palette.GOLD_STAR, hr * 0.05, true)
			elif id == "kumis":
				draw_arc(c + Vector2(-hr * 0.16, hr * 0.04), hr * 0.22, PI * 0.05, PI * 0.72,
					12, hair, hr * 0.10, true)
				draw_arc(c + Vector2(hr * 0.16, hr * 0.04), hr * 0.22, PI * 0.28, PI * 0.95,
					12, hair, hr * 0.10, true)
			elif id == "pita_kuning":
				_bow(c + Vector2(-hr * 0.88, -hr * 0.58), hr * 0.30, Palette.BUTTER_YELLOW)
			elif id == "jepit_stroberi":
				draw_circle(c + Vector2(-hr * 0.82, -hr * 0.52), hr * 0.16, Palette.PASTEL_STRAWBERRY)
				draw_circle(c + Vector2(-hr * 0.82, -hr * 0.66), hr * 0.09, Palette.PASTEL_MINT)
			elif id == "anting_mutiara":
				draw_circle(c + Vector2(-hr * 1.02, hr * 0.34), hr * 0.10, Palette.FLOUR_WHITE)
				draw_circle(c + Vector2(hr * 1.02, hr * 0.34), hr * 0.10, Palette.FLOUR_WHITE)
			elif id == "dasi_kupu":
				_bow(Vector2(c.x, body_top + hr * 0.32), hr * 0.32, Palette.APRON_MAROON)
			elif id == "syal_merah":
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 0.62, body_top - hr * 0.10, hr * 1.24, hr * 0.34),
					hr * 0.16), Palette.DANGER)
			elif id == "medali":
				draw_line(Vector2(c.x - hr * 0.30, body_top + hr * 0.10),
					Vector2(c.x, body_top + hr * 0.72), Palette.GOLD_STAR, hr * 0.07, true)
				draw_circle(Vector2(c.x, body_top + hr * 0.80), hr * 0.20, Palette.GOLD_STAR)
			elif id == "pena_telinga":
				draw_line(c + Vector2(hr * 0.94, -hr * 0.12), c + Vector2(hr * 1.12, hr * 0.38),
					Palette.OJOL_GREEN, hr * 0.10, true)
			elif id == "jam_vintage":
				draw_circle(Vector2(c.x - hr * 1.02, body_top + hr * 0.95), hr * 0.16, Palette.PINE_WOOD)
			elif id == "gelang_karet":
				draw_circle(Vector2(c.x - hr * 1.02, body_top + hr * 0.95), hr * 0.14, Palette.WARMER_LAMP)
			elif id == "sarung_tangan" or id == "sarung_tangan_satin":
				draw_circle(Vector2(c.x - hr * 1.04, body_top + hr * 1.05), hr * 0.22, Palette.FLOUR_WHITE)
				draw_circle(Vector2(c.x + hr * 1.04, body_top + hr * 1.05), hr * 0.22, Palette.FLOUR_WHITE)
			elif id == "handuk_pundak":
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x + hr * 0.40, body_top - hr * 0.04, hr * 0.44, hr * 1.10),
					hr * 0.14), Palette.PASTEL_PERIWINKLE)
			elif id == "buku_saku" or id == "pisau_kayu":
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x + hr * 0.18, body_top + hr * 0.62, hr * 0.34, hr * 0.46),
					hr * 0.06), Palette.CARAMEL)
			elif id == "tusuk_konde":
				draw_line(c + Vector2(-hr * 0.30, -hr * 1.20), c + Vector2(hr * 0.30, -hr * 0.98),
					Palette.CARAMEL, hr * 0.08, true)
			else:
				# Pin kecil di celemek untuk aksesori yang belum punya bentuk khusus.
				draw_circle(Vector2(c.x + hr * 0.44, body_top + hr * 0.48), hr * 0.12, Palette.GOLD_STAR)

	func _glasses(c: Vector2, hr: float, rim: Color) -> void:
		draw_arc(c + Vector2(-hr * 0.36, -hr * 0.02), hr * 0.27, 0.0, TAU, 18, rim, hr * 0.07, true)
		draw_arc(c + Vector2(hr * 0.36, -hr * 0.02), hr * 0.27, 0.0, TAU, 18, rim, hr * 0.07, true)
		draw_line(c + Vector2(-hr * 0.09, -hr * 0.02), c + Vector2(hr * 0.09, -hr * 0.02),
			rim, hr * 0.06, true)

	func _bow(pos: Vector2, r: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([
			pos, pos + Vector2(-r, -r * 0.62), pos + Vector2(-r, r * 0.62),
		]), col)
		draw_colored_polygon(PackedVector2Array([
			pos, pos + Vector2(r, -r * 0.62), pos + Vector2(r, r * 0.62),
		]), col)
		draw_circle(pos, r * 0.30, col.darkened(0.18))

	func _hat(c: Vector2, hr: float) -> void:
		var white: Color = Palette.FLOUR_WHITE
		match hat:
			"topi_koki":
				draw_circle(c + Vector2(-hr * 0.52, -hr * 1.06), hr * 0.40, white)
				draw_circle(c + Vector2(0.0, -hr * 1.26), hr * 0.46, white)
				draw_circle(c + Vector2(hr * 0.52, -hr * 1.06), hr * 0.40, white)
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 0.78, c.y - hr * 1.14, hr * 1.56, hr * 0.46), hr * 0.14), white)
			"toque":
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 0.72, c.y - hr * 1.98, hr * 1.44, hr * 1.06), hr * 0.26), white)
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 0.80, c.y - hr * 1.18, hr * 1.60, hr * 0.44), hr * 0.12), white)
			"topi_pet":
				draw_arc(c + Vector2(0.0, -hr * 0.16), hr * 0.90, PI * 1.02, TAU - PI * 0.02,
					20, Palette.PASTEL_PERIWINKLE, hr * 0.46, true)
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 1.34, c.y - hr * 0.74, hr * 1.10, hr * 0.24), hr * 0.10),
					Palette.PASTEL_PERIWINKLE)
			"bandana", "hachimaki":
				var band: Color = Palette.WARMER_LAMP if hat == "bandana" else white
				draw_colored_polygon(ProceduralUIFactory.rounded_points(
					Rect2(c.x - hr * 1.00, c.y - hr * 0.88, hr * 2.00, hr * 0.38), hr * 0.14), band)
				if hat == "hachimaki":
					draw_circle(c + Vector2(0.0, -hr * 0.69), hr * 0.13, Palette.DANGER)
			"bando", "bando_kelinci":
				draw_arc(c, hr * 1.06, PI * 1.12, TAU - PI * 0.12, 18,
					Palette.PASTEL_STRAWBERRY, hr * 0.13, true)
				if hat == "bando_kelinci":
					draw_colored_polygon(ProceduralUIFactory.rounded_points(
						Rect2(c.x - hr * 0.64, c.y - hr * 1.84, hr * 0.28, hr * 0.88), hr * 0.14),
						Palette.PASTEL_STRAWBERRY)
					draw_colored_polygon(ProceduralUIFactory.rounded_points(
						Rect2(c.x + hr * 0.36, c.y - hr * 1.84, hr * 0.28, hr * 0.88), hr * 0.14),
						Palette.PASTEL_STRAWBERRY)
			_:
				pass
