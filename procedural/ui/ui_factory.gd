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
## UI kit "bantal empuk" (pemolesan UI 2026-09-30): tombol timbul bergaris tepi
## dengan bibir tebal di bawah yang benar-benar turun saat ditekan, kilap lembut
## di muka tombol berwarna, huruf tebal bergaris tepi (FontVariation embolden
## dari font bawaan), popup berpita judul, tab bersegmen, sakelar, slider, dan
## chip nilai HUD. Semuanya tetap StyleBoxFlat + gambar `_draw()` + tekstur yang
## dibangkitkan piksel demi piksel.
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
## Tebal bibir bawah tombol (kesan tombol timbul yang bisa ditekan).
const LIP: int = 6
## Seberapa jauh muka tombol turun saat ditekan (px).
const PRESS_SHIFT: int = 4
## Tebal garis tepi tombol.
const EDGE: int = 2
## Tinggi pita judul popup yang menumpang di tepi atas kartu.
const RIBBON_H: float = 52.0
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
static var _switch_cache: Dictionary = {}
static var _paper_cache: ImageTexture = null


static func clear_caches() -> void:
	_theme_cache = null
	_font_cache.clear()
	_grabber_cache = null
	_grabber_hi_cache = null
	_switch_cache.clear()
	_paper_cache = null


## Panel "bantal": muka warna [param color], garis tepi hangat, bibir tebal di
## bawah, dan bayangan jatuh lembut (GDD 4.3 "cushiony feel"). Warna tepi dan
## bibir diturunkan dari mukanya, jadi panel kuning mentega pun tetap serasi.
static func panel(color: Color, radius := 20, shadow := true) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(maxi(radius, 0))
	sb.corner_detail = 10
	sb.anti_aliasing = true
	var lip: Color = rim_color(color)
	sb.border_color = Color(lip, maxf(color.a, 0.85))
	sb.set_border_width_all(2)
	sb.border_width_bottom = 5
	sb.set_content_margin_all(14.0)
	sb.content_margin_bottom = 17.0
	if shadow:
		sb.shadow_color = Color(0.24, 0.12, 0.04, 0.26)
		sb.shadow_size = 10
		sb.shadow_offset = Vector2(0.0, 5.0)
	return sb


## Warna tepi/bibir hangat untuk muka [param face]: ditarik ke cokelat kayu.
static func rim_color(face: Color) -> Color:
	return Color(face.lerp(Palette.UI_WOOD, 0.34), 1.0)


## Kartu bersudut membulat dengan baris judul opsional (lencana madu + judul
## tebal). Isi kartu ditambahkan ke container hasil [method content_of].
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
		accent.custom_minimum_size = Vector2(8.0, 26.0)
		accent.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		accent.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var acc: StyleBoxFlat = StyleBoxFlat.new()
		acc.bg_color = Palette.HONEY
		acc.set_corner_radius_all(4)
		acc.anti_aliasing = true
		acc.border_color = Palette.HONEY_DEEP
		acc.border_width_bottom = 3
		accent.add_theme_stylebox_override("panel", acc)
		head.add_child(accent)

		var cap: Label = label(title_text, 20, Palette.UI_WOOD_DEEP)
		cap.add_theme_font_override("font", display_font())
		cap.name = "Title"
		cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(cap)

		body.add_child(head)
		body.add_child(dashed_separator(Palette.CREAM_LIP))
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
## Tampilan (pemolesan UI 2026-09-30): kartu krem berserat kertas dengan bibir
## tebal, pita judul madu yang menumpang di tepi atasnya, dan slot tombol tutup
## bundar di sudut kanan atas.
##
## Mengembalikan Control akar penuh layar dengan meta:
##   "body"  VBoxContainer — tempat pemanggil menaruh isinya
##   "head"  HBoxContainer — baris atas di dalam kartu untuk kontrol tambahan
##   "scrim" ColorRect     — sambungkan `gui_input` untuk "ketuk di luar = tutup"
##   "close_slot" Control  — tempat tombol tutup di sudut kartu
##   "title_label" Label   — teks pita judul
static func popup(title_text: String, ukuran: Vector2 = POPUP_SIZE) -> Control:
	var root: Control = Control.new()
	root.name = "Popup"
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim: ColorRect = ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = Color(Palette.DARK_CHOCOLATE.r, Palette.DARK_CHOCOLATE.g,
		Palette.DARK_CHOCOLATE.b, 0.50)
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(scrim)

	var kartu: PanelContainer = PanelContainer.new()
	kartu.name = "Kartu"
	var face: StyleBoxFlat = panel(Palette.PANEL, 26, true)
	face.border_color = Palette.CREAM_LIP
	face.set_border_width_all(3)
	face.border_width_bottom = 9
	face.shadow_color = Color(0.20, 0.09, 0.02, 0.36)
	face.shadow_size = 24
	face.shadow_offset = Vector2(0.0, 10.0)
	face.set_content_margin_all(6.0)
	kartu.add_theme_stylebox_override("panel", face)
	_center_box(kartu, ukuran)
	root.add_child(kartu)
	kartu.add_child(paper_grain())

	# Isi yang kelebaran dipotong di sini, BUKAN di kartu: clip_contents pada kartu
	# ikut memotong bayangannya sendiri (sudut gelap persegi di balik kartu).
	var pad: MarginContainer = MarginContainer.new()
	pad.clip_contents = true
	_set_margins(pad, POPUP_PAD, POPUP_PAD, int(RIBBON_H * 0.5) + 12, POPUP_PAD - 4)
	kartu.add_child(pad)

	var kolom: VBoxContainer = VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 10)
	pad.add_child(kolom)

	var head: HBoxContainer = HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 10)
	kolom.add_child(head)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "Body"
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	kolom.add_child(body)

	# Pita judul menumpang di tepi atas kartu, di tengah.
	var strip: CenterContainer = CenterContainer.new()
	strip.name = "RibbonStrip"
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_center_box(strip, Vector2(ukuran.x, RIBBON_H))
	strip.offset_top = -ukuran.y * 0.5 - RIBBON_H * 0.5
	strip.offset_bottom = -ukuran.y * 0.5 + RIBBON_H * 0.5
	root.add_child(strip)
	var ribbon: PanelContainer = ribbon_plate(title_text, 26, ukuran.x - 150.0)
	strip.add_child(ribbon)

	# Slot tombol tutup: bundar, menumpang di sudut kanan atas kartu.
	var slot: Control = Control.new()
	slot.name = "CloseSlot"
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.anchor_left = 0.5
	slot.anchor_right = 0.5
	slot.anchor_top = 0.5
	slot.anchor_bottom = 0.5
	slot.offset_left = ukuran.x * 0.5 - 44.0
	slot.offset_right = ukuran.x * 0.5 + 8.0
	slot.offset_top = -ukuran.y * 0.5 - 18.0
	slot.offset_bottom = -ukuran.y * 0.5 + 38.0
	root.add_child(slot)

	root.set_meta("body", body)
	root.set_meta("head", head)
	root.set_meta("scrim", scrim)
	root.set_meta("kartu", kartu)
	root.set_meta("ribbon", ribbon)
	root.set_meta("title_label", ribbon.get_meta("label"))
	root.set_meta("close_slot", slot)
	return root


## Pita judul madu (popup, kartu penting): huruf tebal krem bergaris tepi madu
## gelap dengan bayangan timbul. Lebarnya mengikuti judul, paling lebar
## [param max_w].
static func ribbon_plate(text: String, size := 26, max_w := 640.0) -> PanelContainer:
	var pc: PanelContainer = PanelContainer.new()
	pc.name = "Ribbon"
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = cushion(Palette.HONEY, Palette.HONEY_DEEP, 22, "normal")
	sb.content_margin_left = 34.0
	sb.content_margin_right = 34.0
	sb.content_margin_top = 5.0
	sb.content_margin_bottom = 5.0 + float(LIP)
	pc.add_theme_stylebox_override("panel", sb)
	var l: Label = hero_label(text, size, Palette.FLOUR_WHITE, Palette.HONEY_DEEP, 6, 3)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.clip_text = true
	l.custom_minimum_size = Vector2(minf(maxf(180.0, _text_width(text, size, true) + 8.0), max_w), 0.0)
	pc.add_child(l)
	var gloss: ButtonGloss = ButtonGloss.new()
	gloss.radius = 22.0
	pc.add_child(gloss)
	pc.set_meta("label", l)
	return pc


## Tombol tutup bundar merah stroberi di slot sudut popup (lihat [method popup]).
static func add_popup_close(popup_root: Control, tooltip: String, on_close: Callable) -> Button:
	var slot: Control = popup_root.get_meta("close_slot")
	var x: Button = icon_button("cross", tooltip, "danger", 24, Palette.FLOUR_WHITE)
	x.name = "Close"
	x.custom_minimum_size = Vector2(52.0, 52.0)
	x.set_anchors_preset(Control.PRESET_FULL_RECT)
	x.pressed.connect(on_close)
	slot.add_child(x)
	return x


## Pasang Control berukuran [param ukuran] tepat di tengah induknya.
static func _center_box(c: Control, ukuran: Vector2) -> void:
	c.anchor_left = 0.5
	c.anchor_right = 0.5
	c.anchor_top = 0.5
	c.anchor_bottom = 0.5
	c.grow_horizontal = Control.GROW_DIRECTION_BOTH
	c.grow_vertical = Control.GROW_DIRECTION_BOTH
	c.offset_left = -ukuran.x * 0.5
	c.offset_right = ukuran.x * 0.5
	c.offset_top = -ukuran.y * 0.5
	c.offset_bottom = ukuran.y * 0.5


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


## Tombol "bantal" timbul. [param kind] = "primary" (madu) | "secondary" (krem) |
## "danger" (stroberi) | "success" (matcha) | "ghost" (bergaris saja) | "tab".
## Setiap tombol otomatis memantul (GDD 7 "squishy bounce"), berbunyi ketukan
## kayu lembut, dan mukanya turun PRESS_SHIFT px selama ditekan.
static func button(text: String, kind := "primary") -> Button:
	var b: Button = Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.custom_minimum_size = Vector2(TOUCH_MIN * 2.0, TOUCH_MIN)
	b.clip_text = false
	var gloss: ButtonGloss = ButtonGloss.new()
	gloss.name = "Gloss"
	b.add_child(gloss)
	apply_kind(b, kind)
	b.pivot_offset = b.custom_minimum_size * 0.5

	# Titik putar selalu di tengah agar pantulan squash & stretch simetris.
	b.resized.connect(func() -> void:
		b.pivot_offset = b.size * 0.5
	)
	b.button_down.connect(func() -> void:
		AudioManager.play(&"ui_tap_soft")
		ProceduralAnimationSystem.press_bounce(b)
		ProceduralUIFactory._shift_content(b, PRESS_SHIFT)
	)
	b.button_up.connect(func() -> void:
		ProceduralUIFactory._shift_content(b, 0)
	)
	return b


## Warna tombol per jenis: face (muka), deep (tepi & bibir), ink (teks),
## outline (garis tepi teks; alfa 0 = tanpa), gloss (kilap di muka).
static func kind_colors(kind: String) -> Dictionary:
	match kind:
		"secondary":
			return {"face": Palette.UI_CREAM, "deep": Palette.CREAM_LIP, "ink": Palette.UI_WOOD_DEEP,
				"outline": Color(0.0, 0.0, 0.0, 0.0), "gloss": false}
		"danger":
			return {"face": Palette.STRAWBERRY, "deep": Palette.STRAWBERRY_DEEP, "ink": Palette.FLOUR_WHITE,
				"outline": Palette.STRAWBERRY_DEEP, "gloss": true}
		"success":
			return {"face": Palette.MATCHA, "deep": Palette.MATCHA_DEEP, "ink": Palette.FLOUR_WHITE,
				"outline": Palette.MATCHA_DEEP, "gloss": true}
		"ghost":
			return {"face": Color(Palette.UI_CREAM, 0.0), "deep": Color(Palette.UI_WOOD, 0.45), "ink": Palette.UI_WOOD,
				"outline": Color(0.0, 0.0, 0.0, 0.0), "gloss": false}
		"tab":
			return {"face": Color(Palette.UI_CREAM, 0.0), "deep": Color(Palette.UI_WOOD, 0.0), "ink": Palette.UI_WOOD,
				"outline": Color(0.0, 0.0, 0.0, 0.0), "gloss": false}
		_:
			return {"face": Palette.HONEY, "deep": Palette.HONEY_DEEP, "ink": Palette.FLOUR_WHITE,
				"outline": Palette.HONEY_DEEP, "gloss": true}


## Pasang (ulang) seluruh gaya satu jenis ke tombol yang sudah ada: muka, tepi,
## bibir, huruf, dan kilap. Dipakai tab aktif/tidak, tombol kecepatan, pilihan.
static func apply_kind(b: Button, kind: String) -> void:
	var k: Dictionary = kind_colors(kind)
	var face: Color = k["face"]
	var deep: Color = k["deep"]
	var ink: Color = k["ink"]
	var outline: Color = k["outline"]
	var flat: bool = kind == "ghost" or kind == "tab"
	var radius: int = RADIUS_PILL
	b.set_meta("kind", kind)
	b.add_theme_font_override("font", display_font())
	if not b.has_theme_font_size_override("font_size"):
		b.add_theme_font_size_override("font_size", scaled(FONT_BODY))
	b.add_theme_color_override("font_color", ink)
	b.add_theme_color_override("font_hover_color", ink)
	b.add_theme_color_override("font_pressed_color", ink)
	b.add_theme_color_override("font_hover_pressed_color", ink)
	b.add_theme_color_override("font_focus_color", ink)
	b.add_theme_color_override("font_disabled_color", Color(Palette.FLOUR_WHITE, 0.95) if outline.a > 0.0 else Color(Palette.TEXT_MUTED, 0.85))
	b.add_theme_color_override("font_outline_color", Color(outline, 0.55) if outline.a > 0.0 else outline)
	b.add_theme_constant_override("outline_size", 5 if outline.a > 0.0 else 0)
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		var sbx: StyleBoxFlat = cushion(face, deep, radius, "pressed" if st == "hover_pressed" else st, flat)
		# Tab rata menyisakan ruang bibir supaya teksnya sejajar dengan tab aktif.
		if kind == "tab":
			sbx.content_margin_bottom += float(LIP)
		b.add_theme_stylebox_override(st, sbx)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	var gloss: Node = b.get_node_or_null("Gloss")
	if gloss is ButtonGloss:
		(gloss as ButtonGloss).enabled = bool(k["gloss"])
		(gloss as ButtonGloss).radius = float(radius)
		(gloss as ButtonGloss).queue_redraw()


## Tombol IKON bundar: satu gambar, tanpa teks (GDD 7 "tap-first").
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
	# ketukan tetap tombolnya, jadi seluruh 48x48 tetap bisa ditekan. Pusatnya
	# di tengah MUKA tombol (di atas bibir), dan ikut turun saat ditekan.
	var ic: IconCanvas = icon(icon_name, icon_size, tint)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var center: CenterContainer = CenterContainer.new()
	center.name = "IconBox"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.offset_bottom = -float(LIP) + 1.0
	center.add_child(ic)
	b.add_child(center)
	# Gambarnya disimpan di meta supaya bisa DIGANTI di tempat (jeda <-> lanjut)
	# tanpa membangun ulang tombolnya.
	b.set_meta("icon", ic)
	return b


## Tombol ikon + teks dalam satu pil (Rotate, Skip to Open, dsb.). Seluruh
## tombol tetap bidang sentuhnya; isinya ikut turun saat ditekan.
static func icon_text_button(icon_name: String, text: String, kind := "primary",
		icon_size := 22, font_size := 17) -> Button:
	var b: Button = button("", kind)
	var k: Dictionary = kind_colors(kind)
	var row: HBoxContainer = HBoxContainer.new()
	row.name = "Row"
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.set_anchors_preset(Control.PRESET_FULL_RECT)
	row.offset_bottom = -float(LIP) + 1.0
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	var ink: Color = k["ink"]
	var ic: IconCanvas = icon(icon_name, icon_size, ink)
	row.add_child(ic)
	var l: Label = label(text, font_size, ink)
	l.add_theme_font_override("font", display_font())
	var outline: Color = k["outline"]
	if outline.a > 0.0:
		l.add_theme_color_override("font_outline_color", outline)
		l.add_theme_constant_override("outline_size", 5)
	row.add_child(l)
	b.add_child(row)
	b.set_meta("icon", ic)
	b.set_meta("caption", l)
	b.custom_minimum_size = Vector2(l.get_combined_minimum_size().x + float(icon_size) + 52.0, TOUCH_MIN)
	b.tooltip_text = text
	return b


## Baris "ikon + nilai" untuk HUD: ikon yang menjelaskan artinya, teks yang
## membawa angkanya. Mengembalikan HBox; labelnya ada di meta "value".
static func icon_value(icon_name: String, text: String, icon_size := 22,
		font_size := 18, tint := Palette.UI_WOOD) -> HBoxContainer:
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.add_child(icon(icon_name, icon_size, tint))
	var l: Label = label(text, font_size)
	l.add_theme_font_override("font", display_font())
	h.add_child(l)
	h.set_meta("value", l)
	return h


## Kapsul nilai HUD (GDD 7): ikon bergaris tepi di kiri + angka tebal, di atas
## pil krem berbibir. Labelnya ada di meta "value", ikonnya di meta "icon".
static func chip(icon_name: String, tint: Color, text: String, font_size := 20, icon_size := 28) -> PanelContainer:
	var pc: PanelContainer = PanelContainer.new()
	pc.name = "Chip"
	var sb: StyleBoxFlat = panel(Color(Palette.UI_CREAM, 0.97), 22, true)
	sb.content_margin_left = 6.0
	sb.content_margin_right = 16.0
	sb.content_margin_top = 3.0
	sb.content_margin_bottom = 6.0
	sb.border_width_bottom = 4
	sb.shadow_size = 6
	sb.shadow_offset = Vector2(0.0, 3.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var h: HBoxContainer = HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var ic: IconCanvas = icon(icon_name, icon_size, tint)
	h.add_child(ic)
	var l: Label = label(text, font_size, Palette.UI_WOOD_DEEP)
	l.add_theme_font_override("font", display_font())
	h.add_child(l)
	pc.set_meta("value", l)
	pc.set_meta("icon", ic)
	return pc


## Tab bersegmen (GDD 7): jalur krem cekung berisi tombol tab; tab aktif timbul
## madu, tab lain rata. `on_select(i)` dipanggil setelah tab diketuk.
static func tab_bar(labels: Array, active: int, on_select: Callable) -> CozyTabs:
	var t: CozyTabs = CozyTabs.new()
	t.setup(labels, active, on_select)
	return t


## Sakelar nyala/mati (Settings): CheckButton bergambar jalur + kenop yang
## dibangkitkan piksel demi piksel. Tetap CheckButton, jadi `toggled` dan
## `button_pressed` bekerja seperti biasa.
static func toggle(on: bool) -> CheckButton:
	var cb: CheckButton = CheckButton.new()
	cb.button_pressed = on
	cb.focus_mode = Control.FOCUS_NONE
	cb.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	cb.custom_minimum_size = Vector2(80.0, TOUCH_MIN)
	_style_toggle(cb)
	cb.toggled.connect(func(_on: bool) -> void:
		AudioManager.play(&"ui_tap_soft")
	)
	return cb


static func _style_toggle(cb: Control) -> void:
	for st: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		cb.add_theme_stylebox_override(st, StyleBoxEmpty.new())
	for suffix: String in ["", "_mirrored"]:
		cb.add_theme_icon_override("checked" + suffix, _switch_texture(true, false))
		cb.add_theme_icon_override("unchecked" + suffix, _switch_texture(false, false))
		cb.add_theme_icon_override("checked_disabled" + suffix, _switch_texture(true, true))
		cb.add_theme_icon_override("unchecked_disabled" + suffix, _switch_texture(false, true))


## Pengali ukuran teks UI dari Settings (100% / 125% / 150%, GDD 28.5, 75.4).
## Ukuran hasil tidak pernah di bawah 14 px logis.
static var text_scale: float = 1.0


static func scaled(size: int) -> int:
	return maxi(14, int(round(float(size) * text_scale)))


static func label(text: String, size := 18, color := Palette.TEXT) -> Label:
	var l: Label = Label.new()
	l.text = text
	# Judul bagian & angka besar (>= 20 px) memakai huruf tebal "chunky cozy".
	l.add_theme_font_override("font", display_font() if size >= 20 else cozy_font(0))
	l.add_theme_font_size_override("font_size", scaled(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_constant_override("line_spacing", maxi(3, int(round(float(size) * 0.28))))
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


## Judul layar / panel: huruf tebal cokelat kayu tua, rata tengah.
static func title(text: String, size := 28) -> Label:
	var l: Label = label(text, size, Palette.UI_WOOD_DEEP)
	l.add_theme_font_override("font", display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_constant_override("line_spacing", maxi(4, int(round(float(size) * 0.22))))
	return l


## Label "stiker" untuk judul penting: huruf tebal [param ink] bergaris tepi
## [param edge] setebal [param outline] px dan bayangan timbul [param depth] px
## berwarna sama dengan garis tepinya (kesan huruf tebal sampul buku cerita).
static func hero_label(text: String, size: int, ink: Color, edge: Color, outline := 8, depth := 5) -> Label:
	var l: Label = label(text, size, ink)
	l.add_theme_font_override("font", display_font())
	l.add_theme_color_override("font_outline_color", edge)
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_shadow_color", edge)
	l.add_theme_constant_override("shadow_offset_x", 0)
	l.add_theme_constant_override("shadow_offset_y", depth)
	l.add_theme_constant_override("shadow_outline_size", outline)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


## Logo judul game (splash & menu): huruf krem tebal bergaris cokelat tua
## dengan ekstrusi timbul.
static func logo(text: String, size := 64) -> Label:
	var l: Label = hero_label(text, size, Color(1.0, 0.953, 0.843), Palette.UI_WOOD_DEEP,
		maxi(8, int(round(float(size) * 0.18))), maxi(5, int(round(float(size) * 0.11))))
	l.name = "Logo"
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

	var def: StaffDefinition = DataRegistry.staff(StringName(staff_id))
	if def == null:
		return root

	var role: String = String(def.role_id)
	var tier: int = clampi(def.tier, 1, 5)

	var face: ChibiPortrait = ChibiPortrait.new()
	face.name = "Portrait"
	face.configure(def.visual, role, tier)
	body.add_child(face)
	root.set_meta("portrait", face)

	var nama: Label = label(def.display_name, 20, Palette.TEXT)
	nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(nama)

	var peran: Label = label(Tx.t(def.title_key()), FONT_SMALL, Palette.TEXT_MUTED)
	peran.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	peran.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(peran)

	var stars: HBoxContainer = HBoxContainer.new()
	stars.name = "Tier"
	stars.alignment = BoxContainer.ALIGNMENT_CENTER
	stars.add_theme_constant_override("separation", 2)
	for i in 5:
		var on: bool = i < tier
		stars.add_child(icon("star", 15, Palette.GOLD_STAR if on else Color(Palette.TEXT_MUTED, 0.28)))
	body.add_child(stars)

	body.add_child(_stat_row("coin", Palette.GOLD_STAR, Tx.t("ui_staff_wage", {"wage": Tx.kr(def.daily_wage_kr)})))

	var speed_text: String = ""
	if def.is_baker():
		speed_text = Tx.t("ui_staff_speed", {"speed": "%.2f" % def.work_speed_multiplier})
	else:
		# Semua transaksi sama lamanya, siapa pun kasirnya (GDD 21.4).
		speed_text = Tx.t("ui_staff_service", {"seconds": "%.1f" % DataRegistry.real_seconds(DataRegistry.packing_seconds())})
	body.add_child(_stat_row("bolt", Palette.WARMER_LAMP, speed_text))

	if def.is_baker():
		var ab: int = int(round(def.auto_retrieve_probability * 100.0))
		body.add_child(_stat_row("fire", Palette.DANGER, Tx.t("ui_staff_auto_retrieve", {"percent": ab})))

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

	# --- Button (bantal madu, GDD 7) ---
	var k: Dictionary = kind_colors("primary")
	for st: String in ["normal", "hover", "pressed", "disabled"]:
		t.set_stylebox(st, "Button", cushion(k["face"], k["deep"], RADIUS_PILL, st, false))
	t.set_stylebox("hover_pressed", "Button", cushion(k["face"], k["deep"], RADIUS_PILL, "pressed", false))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_font("font", "Button", display_font())
	t.set_color("font_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_hover_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_pressed_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_hover_pressed_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_focus_color", "Button", Palette.FLOUR_WHITE)
	t.set_color("font_disabled_color", "Button", Color(Palette.FLOUR_WHITE, 0.95))
	t.set_color("font_outline_color", "Button", Color(Palette.HONEY_DEEP, 0.55))
	t.set_font_size("font_size", "Button", FONT_BODY)
	t.set_constant("h_separation", "Button", 8)
	t.set_constant("outline_size", "Button", 5)

	# --- CheckButton (sakelar) ---
	for st2: String in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		t.set_stylebox(st2, "CheckButton", StyleBoxEmpty.new())
	for suffix: String in ["", "_mirrored"]:
		t.set_icon("checked" + suffix, "CheckButton", _switch_texture(true, false))
		t.set_icon("unchecked" + suffix, "CheckButton", _switch_texture(false, false))
		t.set_icon("checked_disabled" + suffix, "CheckButton", _switch_texture(true, true))
		t.set_icon("unchecked_disabled" + suffix, "CheckButton", _switch_texture(false, true))
	t.set_color("font_color", "CheckButton", Palette.TEXT)
	t.set_font("font", "CheckButton", display_font())

	# --- HSlider / VSlider (thumb besar untuk sentuh) ---
	var track: StyleBoxFlat = _inset_box(Palette.UI_CREAM_DEEP, 8)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	track.content_margin_left = 7.0
	track.content_margin_right = 7.0
	var filled: StyleBoxFlat = _fill_box(Palette.HONEY, 8)
	var filled_hi: StyleBoxFlat = _fill_box(Palette.HONEY.lightened(0.10), 8)
	for slider_type in ["HSlider", "VSlider"]:
		t.set_stylebox("slider", slider_type, track)
		t.set_stylebox("grabber_area", slider_type, filled)
		t.set_stylebox("grabber_area_highlight", slider_type, filled_hi)
		t.set_icon("grabber", slider_type, _grabber_texture(false))
		t.set_icon("grabber_highlight", slider_type, _grabber_texture(true))
		t.set_icon("grabber_disabled", slider_type, _grabber_texture(false))
		t.set_constant("center_grabber", slider_type, 0)
		t.set_constant("grabber_offset", slider_type, 0)

	# --- ProgressBar ---
	var pb_bg: StyleBoxFlat = _inset_box(Palette.UI_CREAM_DEEP, 12)
	var pb_fill: StyleBoxFlat = _fill_box(Palette.MATCHA, 12)
	t.set_stylebox("background", "ProgressBar", pb_bg)
	t.set_stylebox("fill", "ProgressBar", pb_fill)
	t.set_color("font_color", "ProgressBar", Palette.TEXT)

	# --- ScrollBar (ramping, membulat) ---
	var sc_bg: StyleBoxFlat = StyleBoxFlat.new()
	sc_bg.bg_color = Color(Palette.UI_CREAM_DEEP, 0.85)
	sc_bg.set_corner_radius_all(8)
	sc_bg.anti_aliasing = true
	sc_bg.set_content_margin_all(3.0)
	var sc_grab: StyleBoxFlat = StyleBoxFlat.new()
	sc_grab.bg_color = Palette.CREAM_LIP
	sc_grab.set_corner_radius_all(8)
	sc_grab.anti_aliasing = true
	sc_grab.set_content_margin_all(4.0)
	var sc_grab_hi: StyleBoxFlat = sc_grab.duplicate()
	sc_grab_hi.bg_color = Palette.UI_WOOD.lightened(0.15)
	for bar_type in ["HScrollBar", "VScrollBar"]:
		t.set_stylebox("scroll", bar_type, sc_bg)
		t.set_stylebox("scroll_focus", bar_type, sc_bg)
		t.set_stylebox("grabber", bar_type, sc_grab)
		t.set_stylebox("grabber_highlight", bar_type, sc_grab_hi)
		t.set_stylebox("grabber_pressed", bar_type, sc_grab_hi)

	# --- LineEdit (nama toko) ---
	var le: StyleBoxFlat = _inset_box(Palette.FLOUR_WHITE, 18)
	le.set_border_width_all(2)
	le.border_width_top = 4
	le.border_color = Palette.CREAM_LIP
	le.content_margin_left = 16.0
	le.content_margin_right = 16.0
	le.content_margin_top = 10.0
	le.content_margin_bottom = 10.0
	var le_focus: StyleBoxFlat = le.duplicate()
	le_focus.border_color = Palette.HONEY
	le_focus.set_border_width_all(3)
	le_focus.border_width_top = 4
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_font("font", "LineEdit", display_font())
	t.set_color("font_color", "LineEdit", Palette.UI_WOOD_DEEP)
	t.set_color("font_placeholder_color", "LineEdit", Color(Palette.TEXT_MUTED, 0.7))
	t.set_color("caret_color", "LineEdit", Palette.HONEY_DEEP)
	t.set_color("selection_color", "LineEdit", Color(Palette.HONEY, 0.35))

	# --- Tooltip ---
	var tip: StyleBoxFlat = panel(Palette.UI_CREAM, 14, true)
	tip.content_margin_left = 12.0
	tip.content_margin_right = 12.0
	tip.content_margin_top = 6.0
	tip.content_margin_bottom = 9.0
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", Palette.TEXT)
	t.set_font_size("font_size", "TooltipLabel", FONT_SMALL + 1)

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


## Huruf "chunky cozy" (GDD 7) untuk judul, tombol, dan angka HUD: font bawaan
## yang dipertebal lewat FontVariation (GDD 111.2 tetap: tanpa berkas font).
static func display_font() -> FontVariation:
	if _font_cache.has("display"):
		return _font_cache["display"]
	var fv: FontVariation = FontVariation.new()
	fv.base_font = ThemeDB.fallback_font
	fv.variation_embolden = 0.62
	fv.set_spacing(TextServer.SPACING_GLYPH, 1)
	fv.set_spacing(TextServer.SPACING_TOP, 1)
	fv.set_spacing(TextServer.SPACING_BOTTOM, 1)
	_font_cache["display"] = fv
	return fv


## Lebar teks satu baris pada ukuran [param size] (px GUI).
static func _text_width(text: String, size: int, bold := false) -> float:
	var f: Font = display_font() if bold else cozy_font(0)
	return f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, scaled(size)).x


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

	var box: PanelContainer = toast_card(text, icon_name, 2)
	slot.add_child(box)

	holder.modulate = Color(1.0, 1.0, 1.0, 0.0)
	var tw: Tween = holder.create_tween()
	tw.set_ease(Tween.EASE_OUT)
	tw.set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(holder, "modulate:a", 1.0, 0.18)
	tw.tween_interval(TOAST_SECONDS)
	tw.tween_property(holder, "modulate:a", 0.0, 0.35)
	tw.tween_callback(holder.queue_free)


## Kartu toast (GDD 131): pil krem berbibir dengan lencana ikon bundar di kiri.
## Prioritas 0 (kritis) memakai lencana stroberi dan tepi merah; prioritas 1
## lencana madu; sisanya lencana krem.
static func toast_card(text: String, icon_name: String, priority: int) -> PanelContainer:
	var box: PanelContainer = PanelContainer.new()
	box.name = "Toast"
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = panel(Palette.UI_CREAM, 26, true)
	sb.content_margin_left = 8.0
	sb.content_margin_right = 20.0
	sb.content_margin_top = 6.0
	sb.content_margin_bottom = 10.0
	if priority == 0:
		sb.border_color = Palette.STRAWBERRY_DEEP
		sb.set_border_width_all(3)
		sb.border_width_bottom = 6
	box.add_theme_stylebox_override("panel", sb)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(row)
	if not icon_name.is_empty() and IconCanvas.has_icon(icon_name):
		var face: Color = Palette.STRAWBERRY if priority == 0 else (Palette.HONEY if priority == 1 else Palette.UI_CREAM_DEEP)
		var tint: Color = Palette.FLOUR_WHITE if priority <= 1 else Palette.UI_WOOD
		row.add_child(badge(icon_name, face, tint, 36))
	var l: Label = label(text, 17, Palette.UI_WOOD_DEEP)
	l.add_theme_font_override("font", display_font())
	row.add_child(l)
	box.set_meta("label", l)
	return box


## Lencana bundar berbibir berisi satu ikon (toast, kartu, tombol menu).
static func badge(icon_name: String, face: Color, tint: Color, diameter := 36) -> PanelContainer:
	var pc: PanelContainer = PanelContainer.new()
	pc.name = "Badge"
	pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(diameter)
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.border_color = rim_color(face)
	sb.set_border_width_all(2)
	sb.border_width_bottom = 4
	sb.set_content_margin_all(0.0)
	pc.add_theme_stylebox_override("panel", sb)
	pc.custom_minimum_size = Vector2(float(diameter), float(diameter))
	var c: CenterContainer = CenterContainer.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(c)
	c.add_child(icon(icon_name, int(round(float(diameter) * 0.62)), tint))
	return pc


## Latar hangat layar pembuka (splash, menu utama, loading): gradasi krem
## mentega, sinar matahari sore yang berputar pelan, roti & bintang samar yang
## melayang, dan taplak gingham bergelombang di tepi bawah (GDD 4.1, 7).
static func backdrop() -> Control:
	var b: CozyBackdrop = CozyBackdrop.new()
	b.name = "Backdrop"
	return b


## Logo judul bertumpuk: ikon roti besar yang memantul, kata pertama judul
## sebagai huruf timbul, dan kata terakhirnya di pita madu (mis. "Roti Lezat" +
## "Tycoon"). Judul satu kata tampil utuh tanpa pita.
static func logo_lockup(title_text: String, size := 76, icon_size := 104) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "LogoLockup"
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	var art: CenterContainer = CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(0.0, float(icon_size) + 14.0)
	v.add_child(art)
	var bread: IconCanvas = icon("bread", icon_size, Palette.GOLDEN_CRUST)
	bread.name = "LogoBread"
	art.add_child(bread)
	var words: PackedStringArray = title_text.split(" ", false)
	var main_text: String = title_text
	var tail: String = ""
	if words.size() >= 2:
		tail = words[words.size() - 1]
		main_text = " ".join(words.slice(0, words.size() - 1))
	v.add_child(logo(main_text, size))
	if tail != "":
		var strip: CenterContainer = CenterContainer.new()
		strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		v.add_child(strip)
		var rb: PanelContainer = ribbon_plate(tail.to_upper(), int(round(float(size) * 0.40)), 420.0)
		(rb.get_meta("label") as Label).add_theme_constant_override("outline_size", 6)
		strip.add_child(rb)
	v.set_meta("bread", bread)
	return v


## Keadaan kosong yang ramah: ikon besar pudar di atas teks keterangan, di
## tengah ruang yang tersedia (daftar pesanan kosong, tim kosong, dsb.).
static func empty_state(icon_name: String, text: String) -> VBoxContainer:
	var v: VBoxContainer = VBoxContainer.new()
	v.name = "EmptyState"
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.custom_minimum_size = Vector2(320.0, 240.0)
	v.add_theme_constant_override("separation", 10)
	var c: CenterContainer = CenterContainer.new()
	var ic: IconCanvas = icon(icon_name, 88, Palette.CREAM_LIP)
	c.add_child(ic)
	v.add_child(c)
	var l: Label = label(text, 18, Palette.TEXT_MUTED)
	l.add_theme_font_override("font", display_font())
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(l)
	return v


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


## StyleBox "bantal empuk" untuk tombol (GDD 4.3, 7): muka membulat, garis tepi
## tipis, bibir tebal di bawah, dan bayangan jatuh lembut. Saat ditekan mukanya
## turun PRESS_SHIFT px dan bibirnya menipis, jadi tombol terasa benar-benar
## tertekan. [param flat] = tanpa bibir & bayangan (ghost, tab tidak aktif).
static func cushion(face: Color, deep: Color, radius: int = RADIUS_PILL, state: String = "normal", flat: bool = false) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.corner_detail = 12
	sb.anti_aliasing = true
	sb.set_corner_radius_all(radius)
	var pressed: bool = state == "pressed"
	var lip: int = 0 if flat else LIP
	var f: Color = face
	var d: Color = deep
	match state:
		"hover":
			f = face.lightened(0.08) if face.a > 0.01 else Color(Palette.UI_CREAM, 0.55)
		"pressed":
			f = face.darkened(0.06) if face.a > 0.01 else Color(Palette.UI_CREAM_DEEP, 0.75)
		"disabled":
			f = face.lerp(Palette.UI_CREAM_DEEP, 0.62) if face.a > 0.01 else face
			d = Color(deep.lerp(Palette.CREAM_LIP, 0.6), deep.a * 0.7)
	sb.bg_color = f
	sb.border_color = d
	var edge: int = EDGE if d.a > 0.01 else 0
	sb.border_width_left = edge
	sb.border_width_right = edge
	sb.border_width_top = edge
	sb.border_width_bottom = edge + (maxi(lip - PRESS_SHIFT, 0) if pressed else lip)
	if pressed and not flat:
		sb.expand_margin_top = -float(PRESS_SHIFT)
	sb.content_margin_left = 22.0
	sb.content_margin_right = 22.0
	sb.content_margin_top = 7.0 + (float(PRESS_SHIFT) if pressed and not flat else 0.0)
	sb.content_margin_bottom = 7.0 + float(lip) - (float(PRESS_SHIFT) if pressed and not flat else 0.0)
	if not flat and state != "disabled":
		sb.shadow_color = Color(0.24, 0.12, 0.04, 0.30 if not pressed else 0.22)
		sb.shadow_size = 3 if pressed else 7
		sb.shadow_offset = Vector2(0.0, 2.0 if pressed else 4.0)
	return sb


## Geser isi khusus tombol (baris ikon+teks, ikon) mengikuti mukanya saat ditekan.
static func _shift_content(b: Button, dy: int) -> void:
	var cur: int = int(b.get_meta("press_dy", 0))
	if cur == dy or not is_instance_valid(b):
		return
	for c: Node in b.get_children():
		if c is Control and not (c is ButtonGloss):
			(c as Control).position.y += float(dy - cur)
	b.set_meta("press_dy", dy)


## Bidang cekung (jalur slider, bar, kolom isian): muka + tepi atas lebih tebal
## sebagai bayangan dalam.
static func _inset_box(face: Color, radius: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.border_color = Color(Palette.CREAM_LIP, 0.9)
	sb.border_width_top = 3
	sb.border_width_left = 1
	sb.border_width_right = 1
	sb.border_width_bottom = 1
	return sb


## Isian bar/slider: muka warna + kilap tipis di tepi atas yang melebur.
static func _fill_box(face: Color, radius: int) -> StyleBoxFlat:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = face
	sb.set_corner_radius_all(radius)
	sb.corner_detail = 8
	sb.anti_aliasing = true
	sb.border_color = face.lightened(0.42)
	sb.border_width_top = 4
	sb.border_blend = true
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
	var track: StyleBoxFlat = _inset_box(Palette.UI_CREAM_DEEP, 8)
	track.content_margin_top = 7.0
	track.content_margin_bottom = 7.0
	track.content_margin_left = 7.0
	track.content_margin_right = 7.0
	sl.add_theme_stylebox_override("slider", track)
	sl.add_theme_stylebox_override("grabber_area", _fill_box(Palette.HONEY, 8))
	sl.add_theme_stylebox_override("grabber_area_highlight", _fill_box(Palette.HONEY.lightened(0.10), 8))
	sl.add_theme_icon_override("grabber", _grabber_texture(false))
	sl.add_theme_icon_override("grabber_highlight", _grabber_texture(true))
	sl.add_theme_icon_override("grabber_disabled", _grabber_texture(false))
	sl.add_theme_constant_override("center_grabber", 0)
	sl.add_theme_constant_override("grabber_offset", 0)


## Kenop slider bundar 44 px bergaya bantal (tepi cokelat, muka krem, kilap),
## dibangkitkan piksel demi piksel pada resolusi 2x agar tetap tajam.
static func _grabber_texture(highlight: bool) -> ImageTexture:
	if highlight and _grabber_hi_cache != null:
		return _grabber_hi_cache
	if not highlight and _grabber_cache != null:
		return _grabber_cache
	var logical: int = 44
	var k: int = 2
	var d: int = logical * k
	var img: Image = Image.create_empty(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var face: Color = Palette.FLOUR_WHITE if not highlight else Color(1.0, 0.98, 0.93)
	var rim: Color = Palette.HONEY_DEEP
	var mid: float = (float(d) - 1.0) * 0.5
	var r_out: float = mid - 2.0 * float(k)
	var r_face: float = r_out - 2.5 * float(k)
	var r_dot: float = r_face * 0.34
	for y in d:
		for x in d:
			var p: Vector2 = Vector2(float(x) - mid, float(y) - mid)
			var dist: float = p.length()
			# Bayangan lembut di bawah kenop.
			var sh: float = clampf((r_out + 3.0 * float(k) - Vector2(p.x, p.y - 2.5 * float(k)).length()) / (3.0 * float(k)), 0.0, 1.0)
			var col: Color = Color(0.24, 0.12, 0.04, 0.28 * sh)
			if dist <= r_out + 0.5:
				var a: float = clampf(r_out + 0.5 - dist, 0.0, 1.0)
				var c: Color = rim
				if dist <= r_face:
					# Muka krem dengan gradasi atas-terang ke bawah.
					var t: float = clampf((p.y + r_face) / (2.0 * r_face), 0.0, 1.0)
					c = face.lerp(face.darkened(0.10), t)
					if dist <= r_dot:
						c = Palette.HONEY if not highlight else Palette.HONEY.lightened(0.12)
					var hl: float = clampf(1.0 - Vector2(p.x + r_face * 0.28, p.y + r_face * 0.40).length() / (r_face * 0.42), 0.0, 1.0)
					c = c.lerp(Color.WHITE, hl * 0.55)
				col = col.blend(Color(c.r, c.g, c.b, a))
			img.set_pixel(x, y, col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(logical, logical))
	if highlight:
		_grabber_hi_cache = tex
	else:
		_grabber_cache = tex
	return tex


## Gambar sakelar 60x34 px (dibangkitkan 2x): jalur membulat matcha saat nyala
## atau krem saat mati, kenop krem bergaris tepi dengan kilap.
static func _switch_texture(on: bool, disabled: bool) -> ImageTexture:
	var key: String = "%s|%s" % [on, disabled]
	if _switch_cache.has(key):
		return _switch_cache[key]
	var lw: int = 60
	var lh: int = 34
	var k: int = 2
	var w: int = lw * k
	var h: int = lh * k
	var img: Image = Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.0, 0.0, 0.0, 0.0))
	var track: Color = Palette.MATCHA if on else Palette.UI_CREAM_DEEP
	var rim: Color = Palette.MATCHA_DEEP if on else Palette.CREAM_LIP
	if disabled:
		track = track.lerp(Palette.UI_CREAM_DEEP, 0.6)
		rim = rim.lerp(Palette.CREAM_LIP, 0.6)
	var r: float = float(h) * 0.5 - 1.0
	var cy: float = float(h) * 0.5
	var x0: float = r + 1.0
	var x1: float = float(w) - r - 1.0
	var knob_r: float = r - 4.0 * float(k)
	var knob_x: float = x1 if on else x0
	for y in h:
		for x in w:
			var px: float = float(x)
			var py: float = float(y)
			var qx: float = clampf(px, x0, x1)
			var dist: float = Vector2(px - qx, py - cy).length()
			var col: Color = Color(0.0, 0.0, 0.0, 0.0)
			if dist <= r + 0.5:
				var a: float = clampf(r + 0.5 - dist, 0.0, 1.0)
				var c: Color = rim
				if dist <= r - 2.0 * float(k):
					c = track
					# Bayangan dalam di bagian atas jalur.
					if py < cy - (r - 6.0 * float(k)):
						c = track.darkened(0.08)
				col = Color(c.r, c.g, c.b, a)
			var kd: float = Vector2(px - knob_x, py - cy + 1.0 * float(k)).length()
			var shd: float = Vector2(px - knob_x, py - cy - 1.5 * float(k)).length()
			if shd <= knob_r + 2.0 * float(k):
				col = col.blend(Color(0.24, 0.12, 0.04, 0.22 * clampf((knob_r + 2.0 * float(k) - shd) / (2.0 * float(k)), 0.0, 1.0)))
			if kd <= knob_r + 0.5:
				var ka: float = clampf(knob_r + 0.5 - kd, 0.0, 1.0)
				var kc: Color = rim
				if kd <= knob_r - 1.6 * float(k):
					kc = Palette.FLOUR_WHITE
					var hl: float = clampf(1.0 - Vector2(px - knob_x + knob_r * 0.3, py - cy + knob_r * 0.45).length() / (knob_r * 0.5), 0.0, 1.0)
					kc = kc.lerp(Color.WHITE, hl * 0.6)
				col = col.blend(Color(kc.r, kc.g, kc.b, ka))
			img.set_pixel(x, y, col)
	var tex: ImageTexture = ImageTexture.create_from_image(img)
	tex.set_size_override(Vector2i(lw, lh))
	_switch_cache[key] = tex
	return tex


## Serat kertas halus untuk kartu popup & nota (GDD 4.3 "parchment paper" lewat
## generator noise bawaan Godot): 96x96 px tanpa sambungan. Noise-nya dibangkitkan
## native; hanya bagian terangnya yang menjadi serat cokelat tipis beralfa, jadi
## kartu tetap krem bersih (bukan diwarnai kusam seluruhnya).
static func paper_texture() -> ImageTexture:
	if _paper_cache != null:
		return _paper_cache
	var n: FastNoiseLite = FastNoiseLite.new()
	n.seed = 1907
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.11
	n.fractal_octaves = 3
	var sz: int = 96
	var src: Image = n.get_seamless_image(sz, sz, false, false, 0.1, true)
	var img: Image = Image.create_empty(sz, sz, false, Image.FORMAT_RGBA8)
	var ink: Color = Palette.UI_WOOD
	for y in sz:
		for x in sz:
			var v: float = src.get_pixel(x, y).r
			var speck: float = 0.05 if ((x * 73 + y * 151 + (x * y) % 97) % 89) == 0 else 0.0
			img.set_pixel(x, y, Color(ink.r, ink.g, ink.b, clampf((v - 0.55) * 0.14, 0.0, 0.045) + speck))
	_paper_cache = ImageTexture.create_from_image(img)
	return _paper_cache


## Lapisan serat kertas yang mengisi induknya (tidak menangkap ketukan).
static func paper_grain() -> TextureRect:
	var tr: TextureRect = TextureRect.new()
	tr.name = "PaperGrain"
	tr.texture = paper_texture()
	tr.stretch_mode = TextureRect.STRETCH_TILE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return tr


## Faktor skala piksel layar nyata -> piksel GUI (stretch canvas_items/expand).
static func _gui_scale(window_size: Vector2) -> float:
	var base: Vector2 = Vector2(1280.0, 720.0)
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

## Kilap lembut di bagian atas muka tombol/pita berwarna: sorot putih yang
## memudar ke bawah, ikut turun saat tombolnya ditekan. Tidak menangkap ketukan.
class ButtonGloss extends Control:

	var enabled: bool = true
	var radius: float = 24.0

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)

	func _ready() -> void:
		var b: BaseButton = get_parent() as BaseButton
		if b != null:
			b.button_down.connect(queue_redraw)
			b.button_up.connect(queue_redraw)
			b.mouse_entered.connect(queue_redraw)
			b.mouse_exited.connect(queue_redraw)
		resized.connect(queue_redraw)

	func _draw() -> void:
		if not enabled or size.x < 16.0 or size.y < 16.0:
			return
		var b: BaseButton = get_parent() as BaseButton
		var down: bool = false
		if b != null:
			if b.disabled:
				return
			var mode: int = b.get_draw_mode()
			down = mode == BaseButton.DRAW_PRESSED or mode == BaseButton.DRAW_HOVER_PRESSED
		var edge: float = float(ProceduralUIFactory.EDGE)
		var lip: float = float(ProceduralUIFactory.LIP)
		var top: float = edge + 2.0 + (float(ProceduralUIFactory.PRESS_SHIFT) if down else 0.0)
		var face_h: float = size.y - edge * 2.0 - lip
		var h: float = maxf(face_h * 0.42, 6.0)
		var inset: float = minf(radius * 0.62, size.x * 0.24)
		var r: Rect2 = Rect2(inset, top, size.x - inset * 2.0, h)
		if r.size.x < 8.0:
			return
		var pts: PackedVector2Array = ProceduralUIFactory.rounded_points(r, minf(h * 0.5, radius * 0.5), 5)
		var cols: PackedColorArray = PackedColorArray()
		cols.resize(pts.size())
		for i in pts.size():
			var t: float = clampf((pts[i].y - r.position.y) / r.size.y, 0.0, 1.0)
			cols[i] = Color(1.0, 1.0, 1.0, lerpf(0.40, 0.0, t))
		draw_polygon(pts, cols)


## Tab bersegmen di jalur krem cekung (lihat [method ProceduralUIFactory.tab_bar]).
class CozyTabs extends PanelContainer:

	var buttons: Array[Button] = []
	var active: int = 0
	var _on_select: Callable = Callable()

	func setup(labels: Array, active_index: int, on_select: Callable) -> void:
		name = "Tabs"
		_on_select = on_select
		active = active_index
		size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var sb: StyleBoxFlat = ProceduralUIFactory._inset_box(Palette.UI_CREAM_DEEP, 26)
		sb.set_content_margin_all(4.0)
		sb.content_margin_top = 5.0
		add_theme_stylebox_override("panel", sb)
		var row: HBoxContainer = HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		add_child(row)
		for i in labels.size():
			var idx: int = i
			var b: Button = ProceduralUIFactory.button(str(labels[i]), "tab")
			b.name = "Tab%d" % i
			b.custom_minimum_size = Vector2(96.0, 46.0)
			b.pressed.connect(func() -> void:
				select(idx)
				if _on_select.is_valid():
					_on_select.call(idx))
			row.add_child(b)
			buttons.append(b)
		select(active)

	## Tandai tab [param index] sebagai aktif (tanpa memanggil on_select).
	func select(index: int) -> void:
		active = index
		for i in buttons.size():
			ProceduralUIFactory.apply_kind(buttons[i], "primary" if i == active else "tab")


## Latar hangat layar pembuka (lihat [method ProceduralUIFactory.backdrop]).
class CozyBackdrop extends Control:

	const TOP: Color = Color(0.992, 0.937, 0.839)
	const BOTTOM: Color = Color(0.953, 0.824, 0.643)
	## Ikon samar yang melayang: [nama, x (0..1), y (0..1), ukuran, sudut].
	const FLOATERS: Array = [
		["bread", 0.08, 0.16, 54.0, -0.3], ["star", 0.20, 0.72, 34.0, 0.2], ["coin", 0.88, 0.20, 44.0, 0.25],
		["heart", 0.93, 0.62, 36.0, -0.2], ["bread", 0.78, 0.80, 48.0, 0.35], ["star", 0.66, 0.10, 28.0, -0.1],
		["coin", 0.14, 0.44, 32.0, 0.0], ["heart", 0.30, 0.10, 26.0, 0.3], ["star", 0.50, 0.86, 24.0, 0.15],
		["bread", 0.36, 0.60, 30.0, -0.25],
	]

	var _t: float = 0.0
	var _icons: Array[IconCanvas] = []

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_preset(Control.PRESET_FULL_RECT)
		for f: Array in FLOATERS:
			var ic: IconCanvas = ProceduralUIFactory.icon(str(f[0]), int(f[3]), Palette.GOLDEN_CRUST if str(f[0]) != "heart" else Palette.PASTEL_STRAWBERRY)
			ic.outlined = false
			ic.modulate = Color(1.0, 1.0, 1.0, 0.20)
			ic.rotation = float(f[4])
			add_child(ic)
			_icons.append(ic)
		resized.connect(_place)

	func _place() -> void:
		for i in _icons.size():
			var f: Array = FLOATERS[i]
			var ic: IconCanvas = _icons[i]
			ic.position = Vector2(size.x * float(f[1]), size.y * float(f[2])) - ic.custom_minimum_size * 0.5

	func _process(delta: float) -> void:
		if SettingsManager.reduced_motion() or not is_visible_in_tree():
			return
		_t += delta
		for i in _icons.size():
			var f: Array = FLOATERS[i]
			_icons[i].position.y = size.y * float(f[2]) - _icons[i].custom_minimum_size.y * 0.5 + sin(_t * 0.8 + float(i) * 1.7) * 6.0
		queue_redraw()

	func _draw() -> void:
		var w: float = size.x
		var h: float = size.y
		if w < 2.0 or h < 2.0:
			return
		draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(w, 0.0), Vector2(w, h), Vector2(0.0, h)]),
			PackedColorArray([TOP, TOP, BOTTOM, BOTTOM]))
		# Sinar matahari sore dari atas tengah, berputar sangat pelan.
		var c: Vector2 = Vector2(w * 0.5, h * 0.30)
		var reach: float = Vector2(w, h).length()
		var rays: int = 18
		for i in rays:
			if i % 2 == 1:
				continue
			var a0: float = _t * 0.05 + TAU * float(i) / float(rays)
			var a1: float = a0 + TAU / float(rays)
			draw_polygon(PackedVector2Array([c, c + Vector2(cos(a0), sin(a0)) * reach, c + Vector2(cos(a1), sin(a1)) * reach]),
				PackedColorArray([Color(1.0, 1.0, 1.0, 0.22), Color(1.0, 1.0, 1.0, 0.0), Color(1.0, 1.0, 1.0, 0.0)]))
		draw_circle(c, minf(w, h) * 0.30, Color(1.0, 0.97, 0.88, 0.35))
		# Taplak gingham bergelombang di tepi bawah.
		var band: float = minf(96.0, h * 0.14)
		var top_y: float = h - band
		var cell: float = 22.0
		var y: float = top_y
		var row: int = 0
		while y < h:
			var x: float = 0.0
			var col_i: int = 0
			while x < w:
				var a: bool = row % 2 == 0
				var b: bool = col_i % 2 == 0
				var tone: Color = Palette.GINGHAM_B
				if a and b:
					tone = Palette.GINGHAM_A.darkened(0.06)
				elif a or b:
					tone = Palette.GINGHAM_A.lerp(Palette.GINGHAM_B, 0.45)
				draw_rect(Rect2(x, y, cell + 0.5, cell + 0.5), tone)
				x += cell
				col_i += 1
			y += cell
			row += 1
		# Tepi atas taplak: lengkung renda.
		var scallop: float = 18.0
		var x2: float = 0.0
		while x2 < w + scallop:
			draw_circle(Vector2(x2, top_y), scallop * 0.62, Palette.GINGHAM_B)
			x2 += scallop * 1.1
		draw_rect(Rect2(0.0, top_y - 3.0, w, 3.0), Color(Palette.UI_WOOD, 0.10))


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


## Potret chibi 2D untuk kartu polaroid staf dan layar pilih karakter (GDD 3.4,
## 3.5, 7, 12.3). Gaya flat sederhana: bidang warna polos tanpa garis tepi,
## gradasi, atau kilau, dari elips dan poligon membulat di `_draw()` (tanpa
## gambar dan tanpa SubViewport 3D). Semua ukuran diturunkan dari `hr`
## (jari-jari kepala), jadi tetap rapi di ukuran berapa pun.
class ChibiPortrait extends Control:

	const EYE: Color = Color(0.24, 0.13, 0.07)

	var skin: Color = Color(0.949, 0.788, 0.627)
	var hair: Color = Color(0.169, 0.129, 0.094)
	var apron: Color = Color(1.0, 0.984, 0.961)
	var shirt: Color = Palette.FLOUR_WHITE
	var backdrop: Color = Color(0.976, 0.941, 0.878)
	var hair_style: String = "pendek"
	var hat: String = "none"
	var accessory: Array = []
	var chubby: float = 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(168.0, 156.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		size_flags_horizontal = Control.SIZE_EXPAND_FILL
		clip_contents = true

	## Isi parameter visual dari StaffDefinition.visual (warna "#rrggbb").
	func configure(visual: Dictionary, role: String, tier: int) -> void:
		skin = _col(visual.get("skin"), skin)
		hair = _col(visual.get("hair"), hair)
		apron = _col(visual.get("apron"), Palette.apron_for_tier(role, tier))
		var v_acc: Variant = visual.get("accessory", [])
		if v_acc is Array:
			accessory = v_acc
		else:
			accessory = []
		hair_style = String(visual.get("hair_style", "pendek"))
		hat = String(visual.get("hat", "none"))
		chubby = clampf(float(visual.get("chubby", 0.0)), 0.0, 1.0)
		backdrop = Palette.apron_for_tier(role, tier).lerp(Palette.VANILLA_CREAM, 0.72)
		# Celemek terang di atas kemeja krem hangat; celemek berwarna di atas kemeja putih.
		shirt = Color(0.93, 0.86, 0.76) if apron.get_luminance() > 0.85 else Palette.FLOUR_WHITE
		queue_redraw()

	static func _col(v: Variant, fallback: Color) -> Color:
		if v is Color:
			return v
		if v is String and Color.html_is_valid(str(v)):
			return Color.html(str(v))
		return fallback

	func _draw() -> void:
		var r: Rect2 = Rect2(Vector2.ZERO, size)
		if r.size.x < 24.0 or r.size.y < 24.0:
			return
		var s: float = minf(r.size.x, r.size.y)
		var hr: float = s * 0.25
		var c: Vector2 = Vector2(r.size.x * 0.5, r.size.y * 0.52)
		draw_colored_polygon(ProceduralUIFactory.rounded_points(r, 10.0), backdrop)
		_disc(c + Vector2(0.0, -hr * 0.05), hr * 1.50, backdrop.lightened(0.18))
		var body_top: float = c.y + hr * 0.78
		_hair_back(c, hr)
		_body(c, hr, body_top, r.size.y)
		_head(c, hr)
		_face(c, hr)
		_hair_front(c, hr)
		_accessories(c, hr, body_top)
		_hat(c, hr)

	# --- alat gambar ----------------------------------------------------------

	func _disc(p: Vector2, rad: float, col: Color) -> void:
		draw_circle(p, rad, col, true, -1.0, true)

	func _oval(p: Vector2, rx: float, ry: float, col: Color) -> void:
		draw_colored_polygon(_ell(p, rx, ry), col)

	## Titik-titik elips: penuh bila a1 - a0 = TAU, sebagian ditutup tali busur.
	static func _ell(p: Vector2, rx: float, ry: float, a0: float = 0.0, a1: float = TAU, n: int = 28) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		var full: bool = absf(a1 - a0 - TAU) < 0.001
		var count: int = n if full else n + 1
		for i in count:
			var a: float = a0 + (a1 - a0) * float(i) / float(n)
			pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
		return pts

	func _box(rect: Rect2, radius: float, col: Color) -> void:
		draw_colored_polygon(ProceduralUIFactory.rounded_points(rect, radius), col)

	func _head_rx(hr: float) -> float:
		return hr * (1.0 + chubby * 0.08)

	# --- badan ----------------------------------------------------------------

	func _body(c: Vector2, hr: float, body_top: float, bottom: float) -> void:
		var bw: float = hr * (2.5 + chubby * 0.4)
		var deep: float = bottom - body_top + hr * 2.0
		var shade: Color = skin.darkened(0.08)
		_box(Rect2(c.x - hr * 0.21, c.y + hr * 0.55, hr * 0.42, body_top - c.y - hr * 0.40), hr * 0.06, shade)
		_box(Rect2(c.x - bw * 0.5, body_top, bw, deep), bw * 0.36, shirt)
		# Leher baju berbentuk V.
		draw_colored_polygon(PackedVector2Array([Vector2(c.x - hr * 0.30, body_top - hr * 0.01),
			Vector2(c.x + hr * 0.30, body_top - hr * 0.01), Vector2(c.x, body_top + hr * 0.30)]), shade)
		# Celemek polos dengan tali leher.
		var bib: Rect2 = Rect2(c.x - bw * 0.28, body_top + hr * 0.30, bw * 0.56, deep)
		draw_line(Vector2(c.x - bw * 0.24, bib.position.y + hr * 0.04), Vector2(c.x - hr * 0.32, body_top + hr * 0.02), apron, hr * 0.11, true)
		draw_line(Vector2(c.x + bw * 0.24, bib.position.y + hr * 0.04), Vector2(c.x + hr * 0.32, body_top + hr * 0.02), apron, hr * 0.11, true)
		_box(bib, hr * 0.16, apron)

	# --- kepala & wajah -------------------------------------------------------

	func _head(c: Vector2, hr: float) -> void:
		var rx: float = _head_rx(hr)
		_disc(Vector2(c.x - rx * 0.97, c.y + hr * 0.10), hr * 0.20, skin)
		_disc(Vector2(c.x + rx * 0.97, c.y + hr * 0.10), hr * 0.20, skin)
		_oval(c, rx, hr * 0.95, skin)

	func _face(c: Vector2, hr: float) -> void:
		var blush: Color = Color(Palette.ROSY_CHEEK, 0.5)
		for sx: float in [-1.0, 1.0]:
			_oval(c + Vector2(sx * hr * 0.60, hr * 0.33), hr * 0.17, hr * 0.10, blush)
			var e: Vector2 = c + Vector2(sx * hr * 0.36, hr * 0.06)
			_oval(e, hr * 0.11, hr * 0.15, EYE)
			_disc(e + Vector2(-hr * 0.035, -hr * 0.05), hr * 0.045, Palette.FLOUR_WHITE)
		if hair_style == "jenggot":
			var rx: float = _head_rx(hr)
			var band: PackedVector2Array = _ell(c + Vector2(0.0, hr * 0.02), rx * 0.99, hr * 0.97, PI * 0.12, PI * 0.88, 18)
			var inner: PackedVector2Array = _ell(c + Vector2(0.0, -hr * 0.02), rx * 0.88, hr * 0.80, PI * 0.12, PI * 0.88, 18)
			inner.reverse()
			band.append_array(inner)
			draw_colored_polygon(band, hair)
		draw_arc(c + Vector2(0.0, hr * 0.24), hr * 0.16, PI * 0.2, PI * 0.8, 12, EYE, hr * 0.055, true)

	# --- rambut ---------------------------------------------------------------

	func _hair_back(c: Vector2, hr: float) -> void:
		var rx: float = _head_rx(hr)
		var back: Color = hair.darkened(0.06)
		match hair_style:
			"kuncir_ganda":
				for sx: float in [-1.0, 1.0]:
					_oval(c + Vector2(sx * rx * 1.26, hr * 0.26), hr * 0.32, hr * 0.52, hair)
					_disc(Vector2(c.x + sx * rx * 1.14, c.y - hr * 0.16), hr * 0.10, Palette.STRAWBERRY)
			"panjang_kepang":
				_box(Rect2(c.x - rx * 1.12, c.y - hr * 0.70, rx * 2.24, hr * 2.60), rx * 0.62, back)
			"bob":
				_box(Rect2(c.x - rx * 1.14, c.y - hr * 0.90, rx * 2.28, hr * 1.74), rx * 0.62, back)
			"ikal", "ombre":
				for sx2: float in [-1.0, 1.0]:
					_disc(Vector2(c.x + sx2 * rx * 1.06, c.y - hr * 0.28), hr * 0.36, back)
					_disc(Vector2(c.x + sx2 * rx * 1.10, c.y + hr * 0.14), hr * 0.38, back)
					var low: Color = hair.lerp(Palette.PASTEL_STRAWBERRY, 0.65) if hair_style == "ombre" else back
					_disc(Vector2(c.x + sx2 * rx * 0.98, c.y + hr * 0.60), hr * 0.32, low)
			"sanggul":
				_disc(Vector2(c.x, c.y - hr * 1.10), hr * 0.38, hair)
			_:
				pass

	func _hair_front(c: Vector2, hr: float) -> void:
		var rx: float = _head_rx(hr)
		var base: float = -0.38
		var bumps: int = 3
		var amp: float = 0.10
		var tilt: float = 0.0
		var locks: float = 0.38
		match hair_style:
			"cepak", "spike":
				base = -0.58
				bumps = 4
				amp = 0.04
				locks = 0.0
			"belah_samping":
				base = -0.44
				bumps = 1
				amp = 0.05
				tilt = 0.26
			"bob":
				base = -0.30
				bumps = 0
				locks = 0.70
			"panjang_kepang", "ikal", "ombre":
				bumps = 2
				locks = 0.60
			"sanggul":
				bumps = 2
				amp = 0.08
			"jenggot":
				locks = 0.28
		draw_colored_polygon(_cap(c, hr, rx, base, bumps, amp, tilt), hair)
		if locks > 0.0:
			for sx: float in [-1.0, 1.0]:
				var top: Vector2 = c + Vector2(sx * rx * 0.90, 0.0)
				draw_colored_polygon(PackedVector2Array([
					top + Vector2(-hr * 0.19, -hr * 0.30), top + Vector2(hr * 0.19, -hr * 0.30),
					top + Vector2(hr * 0.17, hr * locks * 0.62), top + Vector2(0.0, hr * locks),
					top + Vector2(-hr * 0.17, hr * locks * 0.62),
				]), hair)
		if hair_style == "spike":
			for i in 5:
				var t: float = -0.60 + 0.30 * float(i)
				draw_colored_polygon(PackedVector2Array([
					Vector2(c.x + rx * (t - 0.15), c.y - hr * 0.84), Vector2(c.x + rx * (t + 0.02), c.y - hr * 1.32),
					Vector2(c.x + rx * (t + 0.15), c.y - hr * 0.84),
				]), hair)
		if hair_style == "panjang_kepang":
			var b: Vector2 = c + Vector2(rx * 0.92, hr * 0.62)
			for k in 3:
				_oval(b + Vector2(0.0, hr * 0.30 * float(k)), hr * 0.16, hr * 0.18, hair)
			_disc(b + Vector2(0.0, hr * 0.80), hr * 0.08, Palette.STRAWBERRY)

	## Tudung rambut: busur atas kepala, lalu tepi poni dari pelipis kanan ke kiri
	## yang turun mengikuti dahi. `bumps` lekukan lembut sedalam `amp`; `tilt`
	## membuat poni menyamping (belah samping).
	func _cap(c: Vector2, hr: float, rx: float, base: float, bumps: int, amp: float, tilt: float) -> PackedVector2Array:
		var pts: PackedVector2Array = PackedVector2Array()
		var top: Vector2 = c + Vector2(0.0, -hr * 0.03)
		for i in 25:
			var a: float = PI * 0.97 + PI * 1.06 * float(i) / 24.0
			pts.append(top + Vector2(cos(a) * rx * 1.06, sin(a) * hr * 1.03))
		for j in 31:
			var t: float = float(j) / 30.0
			var x: float = lerpf(c.x + rx * 0.99, c.x - rx * 0.99, t)
			var u: float = (x - c.x) / rx
			var y: float = base + 0.30 * u * u + tilt * t
			if bumps > 0:
				y += amp * (0.5 - 0.5 * cos(TAU * float(bumps) * t))
			pts.append(Vector2(x, c.y + hr * y))
		return pts

	# --- aksesori & topi ------------------------------------------------------

	func _accessories(c: Vector2, hr: float, body_top: float) -> void:
		var rx: float = _head_rx(hr)
		for item: Variant in accessory:
			var id: String = String(item)
			if id.begins_with("kacamata"):
				var rim: Color = Palette.GOLD_STAR.darkened(0.15) if id != "kacamata_bulat" else Palette.DARK_CHOCOLATE
				for sx: float in [-1.0, 1.0]:
					draw_arc(c + Vector2(sx * hr * 0.36, hr * 0.06), hr * 0.22, 0.0, TAU, 24, rim, hr * 0.05, true)
				draw_line(c + Vector2(-hr * 0.14, hr * 0.04), c + Vector2(hr * 0.14, hr * 0.04), rim, hr * 0.045, true)
				if id == "kacamata_rantai":
					draw_arc(c + Vector2(0.0, hr * 0.22), rx * 1.0, PI * 0.08, PI * 0.92, 18, Palette.GOLD_STAR, hr * 0.03, true)
			elif id == "kumis":
				for sx2: float in [-1.0, 1.0]:
					_oval(c + Vector2(sx2 * hr * 0.12, hr * 0.20), hr * 0.13, hr * 0.06, hair)
			elif id == "pita_kuning":
				_bow(c + Vector2(-rx * 0.80, -hr * 0.66), hr * 0.28, Palette.BUTTER_YELLOW)
			elif id == "jepit_stroberi":
				_disc(Vector2(c.x - rx * 0.78, c.y - hr * 0.56), hr * 0.14, Palette.STRAWBERRY)
				_oval(Vector2(c.x - rx * 0.78, c.y - hr * 0.70), hr * 0.09, hr * 0.05, Palette.MATCHA)
			elif id == "bando_gingham":
				_band(c, rx, hr, Palette.GINGHAM_A, 0.15)
			elif id == "anting_mutiara":
				for sx3: float in [-1.0, 1.0]:
					_disc(Vector2(c.x + sx3 * rx * 0.97, c.y + hr * 0.34), hr * 0.07, Palette.FLOUR_WHITE)
			elif id == "dasi_kupu":
				_bow(Vector2(c.x, body_top + hr * 0.12), hr * 0.26, Palette.APRON_MAROON)
			elif id == "syal_merah":
				_box(Rect2(c.x - hr * 0.68, body_top - hr * 0.12, hr * 1.36, hr * 0.30), hr * 0.14, Palette.DANGER)
			elif id == "medali":
				for sx4: float in [-1.0, 1.0]:
					draw_line(Vector2(c.x + sx4 * hr * 0.28, body_top + hr * 0.08), Vector2(c.x, body_top + hr * 0.60), Palette.STRAWBERRY, hr * 0.06, true)
				_disc(Vector2(c.x, body_top + hr * 0.70), hr * 0.16, Palette.GOLD_STAR)
			elif id == "pena_telinga":
				draw_line(c + Vector2(rx * 0.92, -hr * 0.14), c + Vector2(rx * 1.10, hr * 0.34), Palette.OJOL_GREEN, hr * 0.08, true)
			elif id in ["jam_vintage", "gelang_karet", "sarung_tangan", "sarung_tangan_satin"]:
				# Aksesori tangan: potret tidak menggambar tangan, jadi tidak tampil.
				pass
			elif id == "handuk_pundak":
				_box(Rect2(c.x + hr * 0.50, body_top - hr * 0.06, hr * 0.42, hr * 1.06), hr * 0.12, Palette.PASTEL_PERIWINKLE)
			elif id == "buku_saku" or id == "pisau_kayu":
				_box(Rect2(c.x + hr * 0.46, body_top + hr * 0.50, hr * 0.24, hr * 0.40), hr * 0.04, Palette.CARAMEL)
			elif id == "tusuk_konde":
				draw_line(c + Vector2(-hr * 0.34, -hr * 1.24), c + Vector2(hr * 0.34, -hr * 1.02), Palette.CARAMEL, hr * 0.06, true)
			elif id == "pin_bintang":
				_star(Vector2(c.x - hr * 0.60, body_top + hr * 0.56), hr * 0.14, Palette.GOLD_STAR)
			else:
				# Pin bulat untuk aksesori lain (mis. pin senyum).
				_disc(Vector2(c.x - hr * 0.60, body_top + hr * 0.56), hr * 0.12, Palette.BUTTER_YELLOW)

	func _bow(pos: Vector2, rad: float, col: Color) -> void:
		draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(-rad, -rad * 0.64), pos + Vector2(-rad, rad * 0.64)]), col)
		draw_colored_polygon(PackedVector2Array([pos, pos + Vector2(rad, -rad * 0.64), pos + Vector2(rad, rad * 0.64)]), col)
		_disc(pos, rad * 0.28, col.darkened(0.15))

	func _star(p: Vector2, rad: float, col: Color) -> void:
		var pts: PackedVector2Array = PackedVector2Array()
		for i in 10:
			var a: float = -PI * 0.5 + PI * float(i) / 5.0
			var rr: float = rad if i % 2 == 0 else rad * 0.45
			pts.append(p + Vector2(cos(a) * rr, sin(a) * rr))
		draw_colored_polygon(pts, col)

	## Pita melengkung di atas kepala (bando, bandana, ikat kepala).
	func _band(c: Vector2, rx: float, hr: float, col: Color, width: float) -> void:
		var band: PackedVector2Array = _ell(c + Vector2(0.0, -hr * 0.02), rx * 1.09, hr * 1.05, PI * 1.08, PI * 1.92, 20)
		var inner: PackedVector2Array = _ell(c + Vector2(0.0, -hr * 0.02), rx * (1.09 - width), hr * (1.05 - width), PI * 1.08, PI * 1.92, 20)
		inner.reverse()
		band.append_array(inner)
		draw_colored_polygon(band, col)

	func _hat(c: Vector2, hr: float) -> void:
		var rx: float = _head_rx(hr)
		var white: Color = Palette.FLOUR_WHITE
		match hat:
			"topi_koki":
				_disc(Vector2(c.x - rx * 0.50, c.y - hr * 1.10), hr * 0.38, white)
				_disc(Vector2(c.x, c.y - hr * 1.30), hr * 0.46, white)
				_disc(Vector2(c.x + rx * 0.50, c.y - hr * 1.10), hr * 0.38, white)
				_box(Rect2(c.x - rx * 0.80, c.y - hr * 1.16, rx * 1.60, hr * 0.44), hr * 0.12, white)
			"toque":
				_box(Rect2(c.x - rx * 0.70, c.y - hr * 1.80, rx * 1.40, hr * 0.94), hr * 0.28, white)
				_box(Rect2(c.x - rx * 0.82, c.y - hr * 1.16, rx * 1.64, hr * 0.44), hr * 0.12, white)
			"topi_pet":
				var cap: Color = Palette.PASTEL_PERIWINKLE
				_oval(c + Vector2(-rx * 0.62, -hr * 0.66), rx * 0.60, hr * 0.14, cap.darkened(0.15))
				draw_colored_polygon(_ell(c + Vector2(0.0, -hr * 0.52), rx * 1.03, hr * 0.60, PI, TAU, 20), cap)
				_disc(Vector2(c.x, c.y - hr * 1.12), hr * 0.07, cap.darkened(0.2))
			"bandana", "hachimaki":
				var col: Color = Palette.WARMER_LAMP if hat == "bandana" else white
				var knot: Vector2 = c + Vector2(rx * 1.0, -hr * 0.40)
				_oval(knot + Vector2(hr * 0.22, hr * 0.10), hr * 0.20, hr * 0.10, col)
				_oval(knot + Vector2(hr * 0.16, hr * 0.32), hr * 0.10, hr * 0.20, col)
				_band(c, rx, hr, col, 0.28)
				_disc(knot, hr * 0.11, col.darkened(0.12))
				if hat == "hachimaki":
					_disc(Vector2(c.x, c.y - hr * 0.92), hr * 0.10, Palette.DANGER)
			"bando", "bando_kelinci":
				if hat == "bando_kelinci":
					for sx: float in [-1.0, 1.0]:
						var ear: Vector2 = c + Vector2(sx * rx * 0.44, -hr * 1.36)
						_oval(ear, hr * 0.15, hr * 0.44, white)
						_oval(ear + Vector2(0.0, hr * 0.04), hr * 0.07, hr * 0.30, Palette.PASTEL_STRAWBERRY)
				_band(c, rx, hr, Palette.PASTEL_STRAWBERRY, 0.15)
			_:
				pass
