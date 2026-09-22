class_name CustomerOrderScreen
extends Control
## Popup pesanan pembeli fisik (GDD 2 "Tahap Jualan": pemain klik bubble
## pesanan, mengemas roti, klik OK, lalu uang masuk).
##
## Muncul saat pemain mengetuk balon "!" di atas kepala pembeli SEMBARI berjaga
## di meja kasir. Isinya cuma satu: apa yang ada di tangan pembeli itu dan
## berapa yang harus dibayar. Tidak ada pilihan apa pun yang bisa salah — roti
## sudah diambil sendiri oleh pembelinya dari rak, jadi layar ini menutup
## transaksi, bukan menyusunnya.
##
## Latarnya sengaja TEMBUS PANDANG: pemain harus tetap melihat antrean yang
## mengular di belakang pembeli ini, karena itulah yang membuat ia buru-buru
## menekan OK dan kembali ke dapur.
##
## Layar TIDAK menghentikan waktu. Pembeli yang kehabisan kesabaran tetap boleh
## pergi walau popupnya sedang terbuka, dan "Bungkus" akan menjawab jujur bahwa
## orangnya sudah tidak ada.

## Lebar kartu popup, piksel pada resolusi acuan 1280x720 (GDD 12.5).
const LEBAR_KARTU: int = 460

var _main: Node = null
var _customer_id: int = -1

var _judul: Label = null
var _arketipe: Label = null
var _daftar: VBoxContainer = null
var _total: Label = null
var _ok_btn: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build()


func setup(args: Dictionary) -> void:
	_main = _find_main()
	_customer_id = int(args.get("customer_id", -1))
	_render()


# ===========================================================================
# PERAKITAN
# ===========================================================================

func _build() -> void:
	# Kaca gelap yang sama dengan popup lain (ProceduralUIFactory.popup): dapur
	# dan HUD tetap terlihat di belakang kartu.
	var bg := ColorRect.new()
	bg.color = Color(Palette.DARK_CHOCOLATE.r, Palette.DARK_CHOCOLATE.g,
		Palette.DARK_CHOCOLATE.b, 0.45)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	margin.add_theme_constant_override("margin_left", int(safe.x) + 24)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 20)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 24)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 20)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var kartu := PanelContainer.new()
	kartu.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL, 24, true))
	kartu.custom_minimum_size = Vector2(LEBAR_KARTU, 0)
	center.add_child(kartu)

	var m := MarginContainer.new()
	for sisi in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + sisi, 20)
	kartu.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	m.add_child(v)

	var kepala := HBoxContainer.new()
	kepala.add_theme_constant_override("separation", 10)
	v.add_child(kepala)
	var ikon: IconCanvas = ProceduralUIFactory.icon("people", 34, Palette.GOLDEN_CRUST)
	ikon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kepala.add_child(ikon)

	var judul_kolom := VBoxContainer.new()
	judul_kolom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	judul_kolom.add_theme_constant_override("separation", 2)
	kepala.add_child(judul_kolom)

	_judul = ProceduralUIFactory.title("Pesanan Pembeli", 24)
	judul_kolom.add_child(_judul)
	_arketipe = ProceduralUIFactory.label("", 14, Palette.TEXT_MUTED)
	judul_kolom.add_child(_arketipe)

	v.add_child(ProceduralUIFactory.dashed_separator())

	_daftar = VBoxContainer.new()
	_daftar.add_theme_constant_override("separation", 8)
	v.add_child(_daftar)

	v.add_child(ProceduralUIFactory.dashed_separator())

	var baris_total := HBoxContainer.new()
	v.add_child(baris_total)
	var cap: Label = ProceduralUIFactory.label("Total", 18, Palette.TEXT_MUTED)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baris_total.add_child(cap)
	_total = ProceduralUIFactory.title("", 22)
	baris_total.add_child(_total)

	var tombol := HBoxContainer.new()
	tombol.add_theme_constant_override("separation", 10)
	v.add_child(tombol)

	var nanti: Button = ProceduralUIFactory.button("Nanti", "ghost")
	nanti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nanti.pressed.connect(_on_tutup)
	tombol.add_child(nanti)

	_ok_btn = ProceduralUIFactory.button("Bungkus & Terima", "primary")
	_ok_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ok_btn.pressed.connect(_on_ok)
	tombol.add_child(_ok_btn)


# ===========================================================================
# ISI
# ===========================================================================

func _render() -> void:
	if _daftar == null:
		return
	for c in _daftar.get_children():
		c.queue_free()

	var cust: CustomerSim = _customers()
	var c: Dictionary = cust.customer(_customer_id) if cust != null else {}
	if c.is_empty():
		_arketipe.text = "Pembelinya sudah pergi."
		_total.text = GameConfig.kr(0.0)
		if _ok_btn != null:
			_ok_btn.disabled = true
		return

	if _ok_btn != null:
		_ok_btn.disabled = false
	var arch: Dictionary = CustomerDB.entry(String(c.get("archetype", "")))
	_arketipe.text = String(arch.get("name", "Pembeli"))

	var basket: Dictionary = c.get("basket", {})
	var total: float = 0.0
	for k: Variant in basket:
		var rid: String = String(k)
		var n: int = int(basket[k])
		if n <= 0:
			continue
		var harga: float = GameState.recipe_price(rid) * float(n)
		total += harga
		_daftar.add_child(_baris(rid, n, harga))
	if _daftar.get_child_count() == 0:
		_daftar.add_child(ProceduralUIFactory.label(
			"Keranjangnya kosong.", 15, Palette.TEXT_MUTED))
	_total.text = GameConfig.kr(total)


## Satu baris belanjaan: ikon roti, nama resep dengan jumlahnya, lalu harganya.
func _baris(recipe_id: String, jumlah: int, harga: float) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var ikon: IconCanvas = ProceduralUIFactory.icon("bread", 26, Palette.GOLDEN_CRUST)
	ikon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ikon)

	var nama: String = String(RecipeDB.entry(recipe_id).get("name", recipe_id))
	var kiri: Label = ProceduralUIFactory.label("%s  x%d" % [nama, jumlah], 16)
	kiri.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kiri)

	row.add_child(ProceduralUIFactory.label(GameConfig.kr(harga), 16, Palette.TEXT_MUTED))
	return row


# ===========================================================================
# AKSI
# ===========================================================================

## "Bungkus & Terima": karakter mulai membungkus pesanan, dan uang baru masuk
## setelah bungkusannya selesai (CustomerSim yang menghitung waktunya).
func _on_ok() -> void:
	var cust: CustomerSim = _customers()
	if cust == null:
		_kembali()
		return
	if not cust.confirm_service(_customer_id):
		# Pembelinya keburu pulang, atau karakter keburu dipanggil pergi dari
		# meja kasir sementara popup ini terbuka.
		EventBus.toast.emit("Pesanan itu sudah tidak bisa dilayani.", "warning")
		_kembali()
		return
	AudioBus.sfx("paper")
	_kembali()


func _on_tutup() -> void:
	AudioBus.sfx("tap")
	_kembali()


func _kembali() -> void:
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


# ===========================================================================
# Pembantu
# ===========================================================================

func _customers() -> CustomerSim:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return null
	var raw: Variant = _main.get("systems")
	if not (raw is Dictionary):
		return null
	return (raw as Dictionary).get("cust") as CustomerSim


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
