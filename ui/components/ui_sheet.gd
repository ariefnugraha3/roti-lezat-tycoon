class_name UISheet
extends UIScreen
## Lembar bawah idle (GDD idle 12.0.5): panel selebar bingkai yang naik dari atas
## bar tab, tingginya paling banyak `MAX_HEIGHT_RATIO` bingkai. Isinya daftar
## yang hanya bergulir vertikal; detail item terbuka sebagai halaman berikutnya
## di lembar yang sama dengan tombol Back. Lembar tidak mem-pause toko, hanya
## satu yang terbuka dalam satu waktu, dan bar tab di bawahnya tetap bisa
## diketuk.
##
## Turunan mengisi `sheet_title()`, `sheet_icon()` dan `build_page(body)`, lalu
## membuka detail dengan `push_page(title, builder)`. `refresh()` membangun ulang
## halaman yang sedang tampil; turunan memanggilnya saat isi berubah (mis.
## setelah membeli).
##
## Tampilan (pemolesan UI flat 2026-11-03): latar krem `Palette.SHEET` dengan
## setiap baris sebagai kartu `Palette.CARD` (`card`, `row`), judul bagian
## berhuruf kapital kecil (`section`), dan kepala berisi lencana ikon tab, judul
## rata kiri, serta tombol tutup bundar krem.

const MAX_HEIGHT_RATIO: float = 0.85
## Jarak dari tepi bawah bingkai: tinggi bar tab HUD + celah.
const BOTTOM_GAP: float = 8.0

var _panel: PanelContainer = null
var _title: Label = null
var _back: Button = null
var _badge: Control = null
var _content: VBoxContainer = null
## Halaman detail yang terbuka: [{title, builder}]. Kosong = halaman utama.
var _pages: Array[Dictionary] = []
var _refresh_timer: float = 0.0
## Detik nyata antar-refresh otomatis (angka KR dan tombol beli ikut berubah).
var auto_refresh_seconds: float = 0.5


func _init() -> void:
	super._init()
	blocking = false
	sheet = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func sheet_title() -> String:
	return ""


## Ikon lencana di kepala lembar (nama IconCanvas), atau "" tanpa lencana.
func sheet_icon() -> String:
	return ""


## Diisi turunan: halaman utama.
func build_page(_body: VBoxContainer) -> void:
	pass


func build() -> void:
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	_panel = PanelContainer.new()
	_panel.name = "Sheet"
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.SHEET, 26, true)
	sb.corner_radius_bottom_left = 22
	sb.corner_radius_bottom_right = 22
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	_panel.add_theme_stylebox_override("panel", sb)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_panel.anchor_left = 0.0
	_panel.anchor_right = 1.0
	_panel.anchor_top = 1.0 - MAX_HEIGHT_RATIO
	_panel.anchor_bottom = 1.0
	_panel.offset_left = inset.x + 8.0
	_panel.offset_right = -inset.z - 8.0
	_panel.offset_top = 0.0
	_panel.offset_bottom = -(inset.w + HUD.TAB_BAR_H + BOTTOM_GAP)
	add_child(_panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_panel.add_child(v)
	var head := HBoxContainer.new()
	head.name = "Head"
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	_back = ProceduralUIFactory.icon_button("back", Tx.t("ui_back"), "plain", 24, Palette.UI_WOOD_DEEP)
	_back.name = "Back"
	_back.pressed.connect(pop_page)
	head.add_child(_back)
	if sheet_icon() != "":
		_badge = ProceduralUIFactory.badge(sheet_icon(), Palette.HONEY, Palette.FLOUR_WHITE, 48)
		_badge.name = "Badge"
		_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		head.add_child(_badge)
	_title = ProceduralUIFactory.title("", 26)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.clip_text = true
	head.add_child(_title)
	var close_b: Button = ProceduralUIFactory.icon_button("cross", Tx.t("ui_close"), "plain", 22, Palette.UI_WOOD_DEEP)
	close_b.name = "Close"
	close_b.pressed.connect(close)
	head.add_child(close_b)
	_content = VBoxContainer.new()
	_content.name = "Content"
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	v.add_child(_content)
	_render()


func _render() -> void:
	clear(_content)
	_back.visible = not _pages.is_empty()
	if _badge != null:
		_badge.visible = _pages.is_empty()
	if _pages.is_empty():
		_title.text = sheet_title()
		build_page(_content)
	else:
		var p: Dictionary = _pages[_pages.size() - 1]
		_title.text = str(p["title"])
		(p["builder"] as Callable).call(_content)


## Buka halaman detail di lembar yang sama.
func push_page(title_text: String, builder: Callable) -> void:
	_pages.append({"title": title_text, "builder": builder})
	_render.call_deferred()


func pop_page() -> void:
	if _pages.is_empty():
		return
	_pages.pop_back()
	_render.call_deferred()


func page_depth() -> int:
	return _pages.size()


## Bangun ulang halaman yang tampil (sesudah sinyal tombol selesai).
func refresh() -> void:
	_render.call_deferred()


## Halaman diperbarui berkala saat terbuka (KR berubah terus di game idle).
## Turunan boleh memperbarui label di `tick_page` tanpa membangun ulang.
func _process(delta: float) -> void:
	_refresh_timer -= delta
	if _refresh_timer <= 0.0:
		_refresh_timer = auto_refresh_seconds
		tick_page()


func tick_page() -> void:
	pass


func on_back() -> bool:
	if not _pages.is_empty():
		pop_page()
		return true
	close()
	return true


func panel() -> PanelContainer:
	return _panel


func content() -> VBoxContainer:
	return _content


## Judul bagian di daftar lembar (lihat `ProceduralUIFactory.section_label`).
static func section(parent: Control, text: String) -> Label:
	var l: Label = ProceduralUIFactory.section_label(text)
	parent.add_child(l)
	return l


## Kartu kosong selebar daftar di `parent` (baris dengan tata letak sendiri).
static func card(parent: Control) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.card_box())
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(pc)
	return pc


## Baris daftar standar: ikon/gambar kiri, judul + subjudul, kontrol di kanan.
static func row(parent: Control, title_text: String, sub_text: String, left: Control = null) -> HBoxContainer:
	var pc: PanelContainer = card(parent)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	pc.add_child(h)
	if left != null:
		left.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(left)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var t: Label = ProceduralUIFactory.label(title_text, 18, Palette.UI_WOOD_DEEP)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(t)
	if sub_text != "":
		var s: Label = ProceduralUIFactory.label(sub_text, 14, Palette.TEXT_MUTED)
		s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		s.name = "Sub"
		v.add_child(s)
	return h
