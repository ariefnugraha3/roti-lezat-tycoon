class_name HUD
extends Control
## HUD utama saat bermain (GDD 7 "Main HUD").
##
## Tata letak sesuai GDD:
##   kiri atas   : Saldo Koin Roti + Rating Toko
##   kanan atas  : Jam in-game + Meteran Biaya Utilitas + Menu/Jeda/Kecepatan
##   kanan layar : Counter Stok Roti di etalase
##   kanan bawah : Quick Menu (Pasar, Karyawan, Iklan, Dekorasi)
##
## Buku Resep TIDAK ada di Quick Menu: pemain mengetuk Gudang Penyimpanan di
## dapur, karakternya berjalan ke sana, pintunya terbuka, barulah daftar resep
## muncul (GDD 2). Ketukan pada perabot lain juga lewat sini — HUD hanya
## meneruskannya ke PlayerTaskSystem, yang memutuskan apakah ketukan itu berarti
## sesuatu untuk pesanan yang sedang berjalan.
##
## HUD hanya MEMBACA keadaan; semua aksi diteruskan ke sistem simulasi.

const REFRESH_INTERVAL: float = 0.15


var _coin_label: Label = null
var _rating_label: Label = null
var _rotifood_label: Label = null
var _clock_label: Label = null
var _phase_icon: IconCanvas = null
var _utility_label: Label = null
var _weather_icon: IconCanvas = null

var _stock_box: VBoxContainer = null
var _order_box: VBoxContainer = null
var _order_empty: Label = null
## Baris "Permintaan hari ini", hanya tampil pada tiga hari pembukaan.
var _target_row: HBoxContainer = null
var _target_label: Label = null
## order_id -> Button. Tombol dipakai ULANG antar penyegaran; lihat _refresh_orders().
var _order_buttons: Dictionary = {}
var _pause_btn: Button = null
var _speed_btn: Button = null
var _view_buttons: Dictionary = {}
var _toast_layer: CanvasLayer = null

var _main: Node = null
var _acc: float = 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ProceduralUIFactory.apply_theme(self)

	# Tata letak dibangun dengan container bersarang, BUKAN anchor + position
	# manual. Mencampur keduanya membuat seluruh panel menumpuk di pojok kiri
	# atas, karena `position` ditimpa ulang begitu container menghitung layout.
	#
	#  HUD (full rect)
	#  └── MarginContainer (safe area)
	#      └── VBox
	#          ├── HBox atas   : [saldo+rating]        ~ [jam+utilitas+cuaca]
	#          ├── HBox tengah : [pesanan RotiFood]    ~ [stok etalase]
	#          └── HBox bawah  :                       ~ [quick menu]
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margin.add_theme_constant_override("margin_left", int(safe.x) + 16)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 12)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 16)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 12)
	add_child(margin)

	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_theme_constant_override("separation", 8)
	margin.add_child(rows)

	var row_top := HBoxContainer.new()
	row_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(row_top)
	_build_top_left(row_top)
	row_top.add_child(_spacer())
	_build_top_right(row_top)

	var row_mid := HBoxContainer.new()
	row_mid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row_mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	rows.add_child(row_mid)
	_build_order_panel(row_mid)
	row_mid.add_child(_spacer())
	_build_stock_panel(row_mid)

	var row_bottom := HBoxContainer.new()
	row_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(row_bottom)
	_build_view_switcher(row_bottom)
	row_bottom.add_child(_spacer())
	_build_quick_menu(row_bottom)

	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 20
	add_child(_toast_layer)

	EventBus.toast.connect(_on_toast)
	EventBus.day_ended.connect(_on_day_ended)
	EventBus.bailout_triggered.connect(_on_bailout)


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	_connect_world()
	_refresh()


## Menyambung ketukan perabot dunia 3D. Dilakukan di setup(), bukan _ready():
## saat HUD pertama dibangun ShopWorld belum tentu sudah dirakit Main.
func _connect_world() -> void:
	var w: ShopWorld = _world()
	if w == null:
		return
	if not w.fixture_tapped.is_connected(_on_fixture_tapped):
		w.fixture_tapped.connect(_on_fixture_tapped)


## Pemain mengetuk satu perabot di dunia 3D.
##
## Seluruh arti ketukan ditentukan PlayerTaskSystem: gudang berarti "ambil
## bahan", perabot yang sedang menunggu berarti "kerjakan tahap berikutnya", dan
## perabot yang tidak menunggu apa-apa tetap dihampiri karakter. Mengetuk MEJA
## KASIR menyuruhnya berjaga di sana, dan selama ia berdiri di situ ia yang
## melayani pembeli (GDD 3.0.C). Yang senyap hanyalah ketukan yang benar-benar
## tidak mengubah apa pun -- misalnya mengetuk perabot yang karakternya sudah
## berdiri di depannya.
func _on_fixture_tapped(kind: String, index: int) -> void:
	var pt: PlayerTaskSystem = _tasks()
	if pt == null:
		return
	if pt.tap(kind, index):
		AudioBus.sfx("tap")


func _tasks() -> PlayerTaskSystem:
	return _systems().get("player") as PlayerTaskSystem


# ===========================================================================
# PERAKITAN PANEL
# ===========================================================================

## Pengisi elastis yang mendorong panel ke tepi berlawanan.
func _spacer() -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


## Membuat satu panel cozy dan menambahkannya ke baris yang diberikan.
## Mengembalikan VBox isi panel supaya pemanggil tinggal menaruh barisnya.
func _panel_box(parent: Node) -> VBoxContainer:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PANEL, 20, true))
	pc.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	pc.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	m.add_child(v)
	parent.add_child(pc)
	return v


func _build_top_left(parent: Node) -> void:
	var v: VBoxContainer = _panel_box(parent)

	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 8)
	h1.add_child(ProceduralUIFactory.icon("coin", 26, Palette.GOLD_STAR))
	_coin_label = ProceduralUIFactory.label(GameConfig.kr(GameState.coins), 22)
	h1.add_child(_coin_label)
	v.add_child(h1)

	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 8)
	h2.add_child(ProceduralUIFactory.icon("star", 20, Palette.GOLD_STAR))
	_rating_label = ProceduralUIFactory.label("3.0", 16)
	h2.add_child(_rating_label)
	h2.add_child(ProceduralUIFactory.icon("scooter", 20, Palette.OJOL_GREEN))
	_rotifood_label = ProceduralUIFactory.label("4.0", 16)
	h2.add_child(_rotifood_label)
	v.add_child(h2)


func _build_top_right(parent: Node) -> void:
	var v: VBoxContainer = _panel_box(parent)

	var h1 := HBoxContainer.new()
	h1.add_theme_constant_override("separation", 8)
	h1.add_child(ProceduralUIFactory.icon("clock", 24, Palette.UI_WOOD))
	_clock_label = ProceduralUIFactory.label("05:00", 22)
	h1.add_child(_clock_label)
	# Fase hari dibaca dari IKON, bukan kata: koki = menyiapkan stok, orang =
	# toko sedang melayani, bulan = pintu sudah ditutup.
	_phase_icon = ProceduralUIFactory.icon("chef", 20, Palette.TEXT_MUTED)
	_phase_icon.tooltip_text = "Tahap Persiapan"
	_phase_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	h1.add_child(_phase_icon)
	v.add_child(h1)

	var h2 := HBoxContainer.new()
	h2.add_theme_constant_override("separation", 8)
	h2.add_child(ProceduralUIFactory.icon("bolt", 20, Palette.WARNING))
	_utility_label = ProceduralUIFactory.label("0 KR", 15, Palette.TEXT_MUTED)
	h2.add_child(_utility_label)
	v.add_child(h2)

	# Cuaca: cukup ikonnya. Namanya ("Cerah"/"Hujan"/"Liburan") sudah dibawa
	# gambar matahari / hujan / balon pesta itu sendiri.
	var h3 := HBoxContainer.new()
	h3.add_theme_constant_override("separation", 8)
	_weather_icon = ProceduralUIFactory.icon("sun", 20, Palette.GOLD_STAR)
	_weather_icon.mouse_filter = Control.MOUSE_FILTER_PASS
	h3.add_child(_weather_icon)
	v.add_child(h3)

	var h4 := HBoxContainer.new()
	h4.add_theme_constant_override("separation", 6)
	# Roda gigi: Menu dalam permainan (suara, simpan, keluar). Sengaja duduk di
	# samping tombol jeda, bukan di Quick Menu — isinya bukan bagian dari
	# mengelola toko, melainkan dari mengelola sesi bermain.
	var menu_btn: Button = ProceduralUIFactory.icon_button("gear", "Menu", "ghost", 22)
	menu_btn.pressed.connect(_on_menu)
	h4.add_child(menu_btn)
	_pause_btn = ProceduralUIFactory.icon_button("pause", "Jeda", "ghost", 22)
	_pause_btn.pressed.connect(_on_pause)
	h4.add_child(_pause_btn)
	# Tombol kecepatan tetap membawa ANGKA: "2x" bukan label yang bisa diganti
	# gambar — nilainya sendiri yang menjadi isinya.
	_speed_btn = ProceduralUIFactory.button("1x", "ghost")
	_speed_btn.custom_minimum_size = Vector2(
		ProceduralUIFactory.TOUCH_MIN, ProceduralUIFactory.TOUCH_MIN)
	_speed_btn.pressed.connect(_on_speed)
	h4.add_child(_speed_btn)
	v.add_child(h4)


## Baris "Permintaan hari ini" untuk tiga hari pembukaan (OpeningDB).
##
## Tanpa angka ini di layar, "bahan pas permintaan" berubah menjadi tebak-tebakan:
## pemain baru tahu kurang roti ketika sudah ada yang pulang dengan tangan kosong.
func _refresh_target() -> void:
	if _target_label == null or not is_instance_valid(_target_label):
		return
	var day: int = GameState.day
	if not OpeningDB.has_plan(day):
		_target_row.visible = false
		return
	var minta: int = OpeningDB.demand(day)
	var terjual: int = int(GameState.stats.get("bread_sold", 0))
	_target_row.visible = true
	_target_label.text = "%d / %d" % [mini(terjual, minta), minta]
	_target_label.tooltip_text = "Permintaan hari ini"
	_target_label.add_theme_color_override("font_color",
		Palette.SUCCESS if terjual >= minta else Palette.TEXT)


func _build_stock_panel(parent: Node) -> void:
	var v: VBoxContainer = _panel_box(parent)
	# Judul panel diganti ikon roti: satu gambar cukup untuk "ini isi etalase".
	var t: IconCanvas = ProceduralUIFactory.icon("bread", 20, Palette.GOLDEN_CRUST)
	t.tooltip_text = "Stok Etalase"
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(t)
	_stock_box = VBoxContainer.new()
	_stock_box.add_theme_constant_override("separation", 2)
	v.add_child(_stock_box)
	# Baris target: ikon keranjang belanja + angka "terpenuhi / diminta".
	var baris_target: HBoxContainer = ProceduralUIFactory.icon_value(
		"bag", "", 18, 13, Palette.UI_WOOD)
	_target_label = baris_target.get_meta("value") as Label
	baris_target.visible = false
	_target_row = baris_target
	v.add_child(baris_target)


func _build_order_panel(parent: Node) -> void:
	var v: VBoxContainer = _panel_box(parent)
	var t: IconCanvas = ProceduralUIFactory.icon("scooter", 20, Palette.OJOL_GREEN)
	t.tooltip_text = "Pesanan RotiFood"
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	v.add_child(t)
	_order_box = VBoxContainer.new()
	_order_box.add_theme_constant_override("separation", 4)
	v.add_child(_order_box)
	# Label "tidak ada" dibuat SEKALI dan disembunyikan, bukan dibuat-buang tiap
	# penyegaran — satu-satunya anak _order_box yang bukan tombol pesanan.
	_order_empty = ProceduralUIFactory.label("tidak ada", 13, Palette.TEXT_MUTED)
	_order_box.add_child(_order_empty)


## Pemindah sudut pandang kamera (GDD 2: persiapan di dapur, jualan di kasir).
## Tombol yang sedang aktif ditandai supaya pemain tahu sedang melihat zona mana.
func _build_view_switcher(parent: Node) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PANEL, 22, true))
	pc.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(pc)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	pc.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	m.add_child(h)

	h.add_child(ProceduralUIFactory.icon("clock", 20, Palette.TEXT_MUTED))

	_view_buttons.clear()
	var entries: Array = [
		[ShopWorld.VIEW_KITCHEN, "Dapur", "kitchen"],
		[ShopWorld.VIEW_ALL, "Semua", "frame"],
		[ShopWorld.VIEW_SHOP, "Toko", "shop"],
	]
	for e_v in entries:
		var e: Array = e_v
		var id: String = String(e[0])
		var b: Button = ProceduralUIFactory.icon_button(
			String(e[2]), String(e[1]), "secondary")
		b.pressed.connect(_on_view.bind(id))
		h.add_child(b)
		_view_buttons[id] = b
	_sync_view_buttons()


func _on_view(id: String) -> void:
	var w: ShopWorld = _world()
	if w == null:
		return
	w.set_view(id)
	_sync_view_buttons()


## Menyorot tombol yang sesuai sudut pandang aktif. Dibaca langsung dari
## ShopWorld supaya tetap benar walau kamera diubah dari tempat lain.
func _sync_view_buttons() -> void:
	if _view_buttons.is_empty():
		return
	var w: ShopWorld = _world()
	var aktif: String = w.view if w != null else ShopWorld.VIEW_ALL
	for id in _view_buttons.keys():
		var b: Button = _view_buttons[id]
		if b == null or not is_instance_valid(b):
			continue
		var on: bool = String(id) == aktif
		b.modulate = Color.WHITE if on else Color(1.0, 1.0, 1.0, 0.55)


func _world() -> ShopWorld:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return null
	var w: Variant = _main.get("world")
	return w as ShopWorld


func _build_quick_menu(parent: Node) -> void:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PANEL, 22, true))
	pc.size_flags_vertical = Control.SIZE_SHRINK_END
	parent.add_child(pc)

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 10)
	m.add_theme_constant_override("margin_right", 10)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 8)
	pc.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	m.add_child(h)

	var entries: Array = [
		["Pasar", "cart", "market"],
		["Karyawan", "people", "staff"],
		["Iklan", "megaphone", "marketing"],
		["Dekorasi", "box", "decoration"],
	]
	for e_v in entries:
		var e: Array = e_v
		var b: Button = ProceduralUIFactory.icon_button(
			String(e[1]), String(e[0]), "secondary")
		b.pressed.connect(_on_quick.bind(String(e[2])))
		h.add_child(b)


# ===========================================================================
# PEMBARUAN
# ===========================================================================

func _process(delta: float) -> void:
	_acc += delta
	if _acc < REFRESH_INTERVAL:
		return
	_acc = 0.0
	_refresh()


func _refresh() -> void:
	if _coin_label == null:
		return
	_coin_label.text = GameConfig.kr(GameState.coins)
	_rating_label.text = "%.1f" % GameState.store_rating
	_rotifood_label.text = "%.1f" % GameState.rotifood_rating

	var sys: Dictionary = _systems()
	var day: Variant = sys.get("day")
	if day is DayCycle:
		var d: DayCycle = day
		_clock_label.text = GameConfig.clock(d.hour)
		_phase_icon.icon_name = _phase_icon_name(d.phase)
		_phase_icon.tooltip_text = _phase_text(d.phase)
		_set_icon_button(_pause_btn, "play" if d.is_paused() else "pause",
			"Lanjut" if d.is_paused() else "Jeda")
		_speed_btn.text = "%.0fx" % d.time_scale

	var econ: Variant = sys.get("econ")
	if econ != null and (econ as Object).has_method("utility_today"):
		_utility_label.text = GameConfig.kr(float((econ as Object).call("utility_today")))

	_weather_icon.icon_name = _weather_icon_name(GameState.weather)
	_weather_icon.tooltip_text = String(
		WeatherDB.entry(GameState.weather).get("name", "Cerah"))

	_refresh_stock()
	_refresh_target()
	_refresh_orders(sys)
	_sync_view_buttons()


func _phase_text(p: String) -> String:
	match p:
		GameConfig.PHASE_PREP: return "Persiapan"
		GameConfig.PHASE_SELL: return "Jualan"
		GameConfig.PHASE_CLOSE: return "Tutup"
	return p


## Ikon fase hari: koki = menyiapkan stok, orang = melayani pembeli,
## bulan = pintu sudah ditutup.
func _phase_icon_name(p: String) -> String:
	match p:
		GameConfig.PHASE_SELL: return "people"
		GameConfig.PHASE_CLOSE: return "moon"
	return "chef"


## Mengganti gambar di dalam tombol ikon tanpa membangun ulang tombolnya —
## tombol yang dibuang di sela tekan-lepas jari menelan ketukan pemain.
func _set_icon_button(b: Button, icon_name: String, tooltip: String) -> void:
	if b == null or not is_instance_valid(b):
		return
	b.tooltip_text = tooltip
	var ic: IconCanvas = b.get_meta("icon", null) as IconCanvas
	if ic != null and is_instance_valid(ic):
		ic.icon_name = icon_name


func _weather_icon_name(w: String) -> String:
	match w:
		"hujan": return "rain"
		"liburan": return "party"
	return "sun"


func _refresh_stock() -> void:
	var total: Dictionary = {}
	for e_v in GameState.display_slots:
		var e: Dictionary = e_v
		var rid: String = String(e.get("recipe_id", ""))
		if rid == "":
			continue
		total[rid] = int(total.get(rid, 0)) + int(e.get("count", 0))

	for c in _stock_box.get_children():
		c.queue_free()

	if total.is_empty():
		_stock_box.add_child(ProceduralUIFactory.label("kosong", 13, Palette.DANGER))
		return

	for rid in total.keys():
		var nama: String = String(RecipeDB.entry(rid).get("name", rid))
		var l: Label = ProceduralUIFactory.label("%s  %d" % [nama, int(total[rid])], 13)
		_stock_box.add_child(l)


## Menyegarkan balon pesanan RotiFood.
##
## Tombolnya DIPAKAI ULANG, tidak dibangun ulang tiap 0,15 detik seperti dulu.
## Tombol yang di-queue_free() di sela jari menekan dan melepas tidak pernah
## sempat mengirim sinyal `pressed`: ketukan pemain hilang tanpa jejak, dan
## pesanan ojol terasa "tidak bisa diklik" — persis bug yang dilaporkan.
func _refresh_orders(sys: Dictionary) -> void:
	var deliv: Variant = sys.get("deliv")
	var list: Array = []
	if deliv != null and (deliv as Object).has_method("orders"):
		list = (deliv as Object).call("orders")

	var hidup: Dictionary = {}
	for o_v in list:
		var o: Dictionary = o_v
		var state: String = String(o.get("state", ""))
		if state == "selesai" or state == "batal":
			continue
		var id: int = int(o.get("id", 0))
		hidup[id] = true
		var b: Button = _tombol_pesanan(id)
		b.text = _teks_pesanan(o)
		# Terang = menunggu ketukan pemain, redup = sedang berjalan sendiri.
		b.modulate = Color.WHITE if _pesanan_minta_ketukan(o) \
			else Color(1.0, 1.0, 1.0, 0.55)

	for id_v in _order_buttons.keys():
		if hidup.has(int(id_v)):
			continue
		var mati: Variant = _order_buttons[id_v]
		if mati != null and is_instance_valid(mati):
			(mati as Node).queue_free()
		_order_buttons.erase(id_v)

	if _order_empty != null and is_instance_valid(_order_empty):
		_order_empty.visible = hidup.is_empty()


## Tombol satu pesanan; dibuat sekali lalu dipakai ulang.
func _tombol_pesanan(order_id: int) -> Button:
	var ada: Variant = _order_buttons.get(order_id)
	if ada != null and is_instance_valid(ada):
		return ada as Button
	var b: Button = ProceduralUIFactory.button("", "primary")
	b.pressed.connect(_on_order_tap.bind(order_id))
	_order_box.add_child(b)
	_order_buttons[order_id] = b
	return b


## Isi tombol: nomor pesanan + keadaannya sekarang (ARCHITECTURE 7.1).
func _teks_pesanan(o: Dictionary) -> String:
	var id: int = int(o.get("id", 0))
	match String(o.get("state", "")):
		"masuk":
			var sisa: float = maxf(0.0,
				float(o.get("prep_window", 0.0)) - float(o.get("elapsed", 0.0)))
			return "#%d  %ds" % [id, int(sisa)]
		"dikemas":
			return "#%d  dikemas" % id
		"siap":
			return "#%d  siap" % id
		"driver_menunggu":
			return "#%d  driver!" % id
	return "#%d" % id


## Apakah pesanan ini sedang menunggu ketukan pemain (GDD 3.6.A langkah 2 & 4).
func _pesanan_minta_ketukan(o: Dictionary) -> bool:
	var state: String = String(o.get("state", ""))
	return state == "masuk" or state == "driver_menunggu"


# ===========================================================================
# AKSI
# ===========================================================================

func _systems() -> Dictionary:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return {}
	var raw: Variant = _main.get("systems")
	return raw if raw is Dictionary else {}


func _find_main() -> Node:
	var t := get_tree()
	if t == null:
		return null
	var node: Node = t.current_scene
	if node is Main:
		return node
	if node != null:
		for c in node.get_children():
			if c is Main:
				return c
	return null


func _on_quick(screen: String) -> void:
	AudioBus.sfx("tap")
	ScreenRouter.go(screen)


## Membuka Menu dalam permainan. Waktu dijeda oleh layar itu sendiri, lalu
## dikembalikan ke keadaan semula saat ditutup.
func _on_menu() -> void:
	AudioBus.sfx("tap")
	ScreenRouter.go("settings")


func _on_pause() -> void:
	var day: Variant = _systems().get("day")
	if day is DayCycle:
		(day as DayCycle).toggle_paused()
	AudioBus.sfx("tap")


func _on_speed() -> void:
	var day: Variant = _systems().get("day")
	if day is DayCycle:
		(day as DayCycle).toggle_fast_forward()
	AudioBus.sfx("tap")


## Tap balon pesanan ojol: membuka popup pesanan, PERSIS seperti balon pembeli
## fisik. Yang memutuskan "kemas" atau "serahkan" adalah popup itu, bukan HUD —
## satu ketukan tidak boleh berarti dua aksi yang berbeda tergantung keadaan
## yang tidak terlihat pemain (GDD 3.6.A: klik bubble, lalu klik OK).
func _on_order_tap(order_id: int) -> void:
	AudioBus.sfx("tap")
	ScreenRouter.go("delivery_order", {"order_id": order_id})


func _on_toast(text: String, icon: String) -> void:
	if _toast_layer != null:
		ProceduralUIFactory.toast(_toast_layer, text, icon)


func _on_day_ended(ledger: Dictionary) -> void:
	ScreenRouter.go("daily_summary", {"ledger": ledger})


func _on_bailout(times: int) -> void:
	ScreenRouter.go("bailout", {"times": times})
