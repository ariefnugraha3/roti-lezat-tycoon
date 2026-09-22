class_name DeliveryOrderScreen
extends Control
## Popup pesanan RotiFood (GDD 3.6.A).
##
## Bentuknya sengaja KEMBAR dengan popup pesanan pembeli fisik: ketuk balon →
## popup memperlihatkan isi pesanan → satu tombol menyelesaikannya. Dua arus
## pembeli yang berbeda tidak boleh menuntut dua cara berpikir yang berbeda.
##
## Satu pesanan ojol melewati dua ketukan, bukan satu (GDD 3.6.A langkah 2 dan 4):
##   1. "Kemas Pesanan"      — roti diambil dari etalase, dibungkus paper bag
##   2. "Serahkan ke Driver" — paket berpindah ke tas termal, koin masuk
## Di antara keduanya ada jeda pengemasan dan penantian driver yang bukan urusan
## pemain; tombolnya mati dan menjelaskan sedang menunggu apa.
##
## Layar ini TIDAK menghentikan waktu: jendela persiapan terus berjalan, dan
## isinya menyegarkan diri sendiri supaya "menunggu driver" berubah menjadi
## "serahkan" tanpa pemain harus menutup lalu membuka lagi.

## Lebar kartu popup, piksel pada resolusi acuan 1280x720 (GDD 12.5).
const LEBAR_KARTU: int = 480
## Jeda penyegaran isi popup, detik.
const REFRESH_INTERVAL: float = 0.25

# Status pesanan (ARCHITECTURE 7.1).
const STATE_MASUK: String = "masuk"
const STATE_DIKEMAS: String = "dikemas"
const STATE_SIAP: String = "siap"
const STATE_DRIVER: String = "driver_menunggu"

var _main: Node = null
var _order_id: int = -1
var _acc: float = 0.0

var _judul: Label = null
var _status: Label = null
var _daftar: VBoxContainer = null
var _nilai: Label = null
var _aksi_btn: Button = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build()


func setup(args: Dictionary) -> void:
	_main = _find_main()
	_order_id = int(args.get("order_id", -1))
	_render()


## Isi disegarkan berkala, TAPI tombolnya tidak pernah dibangun ulang — tombol
## yang dibuang di sela tekan-lepas jari akan menelan ketukan pemain tanpa jejak.
func _process(delta: float) -> void:
	if not visible:
		return
	_acc += delta
	if _acc < REFRESH_INTERVAL:
		return
	_acc = 0.0
	_render()


# ===========================================================================
# PERAKITAN
# ===========================================================================

func _build() -> void:
	# Kaca gelap yang sama dengan popup lain: dapur dan HUD tetap terlihat.
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
	var ikon: IconCanvas = ProceduralUIFactory.icon("scooter", 34, Palette.OJOL_GREEN)
	ikon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kepala.add_child(ikon)

	var kolom := VBoxContainer.new()
	kolom.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	kolom.add_theme_constant_override("separation", 2)
	kepala.add_child(kolom)
	_judul = ProceduralUIFactory.title("Pesanan RotiFood", 24)
	kolom.add_child(_judul)
	_status = ProceduralUIFactory.label("", 14, Palette.TEXT_MUTED)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	kolom.add_child(_status)

	v.add_child(ProceduralUIFactory.dashed_separator())

	_daftar = VBoxContainer.new()
	_daftar.add_theme_constant_override("separation", 8)
	v.add_child(_daftar)

	v.add_child(ProceduralUIFactory.dashed_separator())

	var baris := HBoxContainer.new()
	v.add_child(baris)
	var cap: Label = ProceduralUIFactory.label("Nilai pesanan", 18, Palette.TEXT_MUTED)
	cap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	baris.add_child(cap)
	_nilai = ProceduralUIFactory.title("", 22)
	baris.add_child(_nilai)

	var tombol := HBoxContainer.new()
	tombol.add_theme_constant_override("separation", 10)
	v.add_child(tombol)

	var nanti: Button = ProceduralUIFactory.button("Nanti", "ghost")
	nanti.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nanti.pressed.connect(_on_tutup)
	tombol.add_child(nanti)

	_aksi_btn = ProceduralUIFactory.button("Kemas Pesanan", "primary")
	_aksi_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_aksi_btn.pressed.connect(_on_aksi)
	tombol.add_child(_aksi_btn)


# ===========================================================================
# ISI
# ===========================================================================

func _render() -> void:
	if _daftar == null:
		return
	for c in _daftar.get_children():
		c.queue_free()

	var o: Dictionary = _order()
	if o.is_empty():
		_judul.text = "Pesanan RotiFood"
		_status.text = "Pesanan ini sudah tidak ada di tablet."
		_nilai.text = GameConfig.kr(0.0)
		_aksi_btn.disabled = true
		_aksi_btn.text = "Tutup"
		return

	_judul.text = "Pesanan RotiFood #%d" % int(o.get("id", 0))
	_status.text = _status_text(o)

	var items: Dictionary = o.get("items", {})
	var stok: Dictionary = _display_stock()
	var cukup: bool = true
	for k: Variant in items:
		var rid: String = String(k)
		var n: int = int(items[k])
		if n <= 0:
			continue
		var punya: int = int(stok.get(rid, 0))
		if punya < n:
			cukup = false
		_daftar.add_child(_baris(rid, n, punya))
	if _daftar.get_child_count() == 0:
		_daftar.add_child(ProceduralUIFactory.label(
			"Pesanan kosong.", 15, Palette.TEXT_MUTED))

	_nilai.text = GameConfig.kr(float(o.get("value", 0.0)))
	_sync_aksi(String(o.get("state", "")), cukup)


## Satu baris pesanan: roti yang diminta beserta sisa stok etalase, supaya
## pemain tahu PERSIS roti mana yang membuat tombol "Kemas" mati.
func _baris(recipe_id: String, minta: int, punya: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var kurang: bool = punya < minta
	var ikon: IconCanvas = ProceduralUIFactory.icon("bread", 26,
		Palette.GOLDEN_CRUST if not kurang else Palette.DANGER)
	ikon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ikon)

	var nama: String = String(RecipeDB.entry(recipe_id).get("name", recipe_id))
	var kiri: Label = ProceduralUIFactory.label("%s  x%d" % [nama, minta], 16)
	kiri.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(kiri)

	row.add_child(ProceduralUIFactory.label("stok %d" % punya, 14,
		Palette.TEXT_MUTED if not kurang else Palette.DANGER))
	return row


## Kalimat keadaan: sedang menunggu apa, dan berapa lama lagi.
func _status_text(o: Dictionary) -> String:
	var state: String = String(o.get("state", ""))
	match state:
		STATE_MASUK:
			var sisa: float = maxf(0.0, float(o.get("prep_window", 0.0))
				- float(o.get("elapsed", 0.0)))
			return "Menunggu dikemas — sisa %d detik." % int(sisa)
		STATE_DIKEMAS:
			return "Sedang dibungkus ke dalam paper bag."
		STATE_SIAP:
			return "Paket siap. Driver tiba dalam %d detik." % int(
				maxf(0.0, float(o.get("driver_eta", 0.0))))
		STATE_DRIVER:
			return "Driver sudah menunggu (%d detik). Serahkan sekarang!" % int(
				float(o.get("driver_wait", 0.0)))
	return "Pesanan sudah ditutup."


## Tombol aksi mengikuti keadaan pesanan. Teks dan nyala-matinya diperbarui di
## tempat, tombolnya tidak pernah diganti.
func _sync_aksi(state: String, cukup: bool) -> void:
	match state:
		STATE_MASUK:
			_aksi_btn.text = "Kemas Pesanan" if cukup else "Stok Kurang"
			_aksi_btn.disabled = not cukup
		STATE_DIKEMAS:
			_aksi_btn.text = "Sedang Dikemas…"
			_aksi_btn.disabled = true
		STATE_SIAP:
			_aksi_btn.text = "Menunggu Driver…"
			_aksi_btn.disabled = true
		STATE_DRIVER:
			_aksi_btn.text = "Serahkan ke Driver"
			_aksi_btn.disabled = false
		_:
			_aksi_btn.text = "Tutup"
			_aksi_btn.disabled = true


# ===========================================================================
# AKSI
# ===========================================================================

func _on_aksi() -> void:
	var deliv: DeliverySim = _delivery()
	if deliv == null:
		_kembali()
		return
	var state: String = String(_order().get("state", ""))
	if state == STATE_DRIVER:
		if deliv.handover(_order_id):
			AudioBus.sfx("coin")
			_kembali()
		else:
			EventBus.toast.emit("Paketnya belum bisa diserahkan.", "warning")
		return
	if deliv.pack(_order_id):
		AudioBus.sfx("paper")
		_kembali()
		return
	EventBus.toast.emit("Stok roti di etalase tidak cukup untuk pesanan ini.", "warning")
	_render()


func _on_tutup() -> void:
	AudioBus.sfx("tap")
	_kembali()


func _kembali() -> void:
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


# ===========================================================================
# Pembantu
# ===========================================================================

func _order() -> Dictionary:
	var deliv: DeliverySim = _delivery()
	if deliv == null:
		return {}
	return deliv.order_by_id(_order_id)


## Isi etalase sekarang: recipe_id -> jumlah.
func _display_stock() -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in GameState.display_slots:
		var s: Dictionary = e
		var rid: String = String(s.get("recipe_id", ""))
		if rid.is_empty():
			continue
		out[rid] = int(out.get(rid, 0)) + int(s.get("count", 0))
	return out


func _delivery() -> DeliverySim:
	if _main == null or not is_instance_valid(_main):
		_main = _find_main()
	if _main == null:
		return null
	var raw: Variant = _main.get("systems")
	if not (raw is Dictionary):
		return null
	return (raw as Dictionary).get("deliv") as DeliverySim


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
