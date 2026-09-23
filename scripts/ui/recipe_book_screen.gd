class_name RecipeBookScreen
extends Control
## Buku Resep (GDD 5.3 dan GDD 7 "Buku Menu & Harga").
##
## Dibuka setelah karakter pemain BERJALAN ke Gudang Penyimpanan dan pintunya
## terbuka (GDD 2: "pemain mengambil bahan dari gudang ... lalu mengikuti
## instruksi resep"). Karena itu kepala layar memasang nama dan isi gudang yang
## sedang dibuka -- resep yang bahannya habis harus terbaca sebelum tombol
## "Buat" ditekan, bukan sesudahnya.
##
## Menekan "Buat" TIDAK langsung mengaduk apa pun. Ia hanya memesan: daftar dan
## pintu gudang tertutup, lalu tanda seru muncul di mixer yang harus dihampiri
## karakter. Seluruh urutan itu milik PlayerTaskSystem; layar ini cuma pemilih.
##
## Tiga fungsi dalam satu layar:
##   • membuka resep Tier 2-5 dengan KR (GDD 5.3 "Penguncian Resep")
##   • mengatur harga jual lewat slider yang memunculkan emoji reaksi pelanggan
##   • memproduksi batch (mengantre ke mixer lewat ProductionSystem)
##
## Angka modal, harga sweet spot, dan profit ditampilkan PERSIS seperti tabel GDD.

## Tinggi rak "Isi Gudang" di kepala popup, piksel. Cukup untuk dua baris chip;
## sisanya digulir supaya daftar resep tidak terdesak keluar kartu.
const BAHAN_TINGGI: int = 76
## Lebar tombol saringan tier. Enam tombol harus muat dalam satu baris kartu.
const TAB_LEBAR: int = 88

var _content: VBoxContainer = null
var _coin_label: Label = null
var _gudang_label: Label = null
var _bahan_box: HFlowContainer = null
var _tier_filter: int = 0  ## 0 = semua
var _main: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build_shell()
	_render()


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	_render()


func _build_shell() -> void:
	var popup: Control = ProceduralUIFactory.popup("Buku Resep")
	add_child(popup)
	var head: HBoxContainer = popup.get_meta("head")
	var v: VBoxContainer = popup.get_meta("body")
	# Mengetuk kaca gelap di luar kartu sama artinya dengan menekan "Tutup".
	(popup.get_meta("scrim") as Control).gui_input.connect(_on_scrim_input)

	head.add_child(ProceduralUIFactory.icon("coin", 22, Palette.GOLD_STAR))
	_coin_label = ProceduralUIFactory.label(GameConfig.kr(GameState.coins), 18)
	head.add_child(_coin_label)
	var tutup: Button = ProceduralUIFactory.icon_button("cross", "Tutup", "ghost", 22)
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	var gudang := HBoxContainer.new()
	gudang.add_theme_constant_override("separation", 8)
	v.add_child(gudang)
	gudang.add_child(ProceduralUIFactory.icon("box", 18, Palette.UI_WOOD))
	_gudang_label = ProceduralUIFactory.label(_gudang_text(), 13, Palette.TEXT_MUTED)
	_gudang_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_gudang_label.clip_text = true
	gudang.add_child(_gudang_label)

	# Isi gudang yang sebenarnya, bukan cuma totalnya: pemain harus bisa
	# menghitung sendiri apakah bahannya cukup SEBELUM menekan "Buat"
	# (GDD 2 "Tahap Persiapan": resep yang bahannya habis harus terbaca duluan).
	var rak_bahan := ScrollContainer.new()
	rak_bahan.custom_minimum_size = Vector2(0, BAHAN_TINGGI)
	rak_bahan.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(rak_bahan)
	_bahan_box = HFlowContainer.new()
	_bahan_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bahan_box.add_theme_constant_override("h_separation", 6)
	_bahan_box.add_theme_constant_override("v_separation", 6)
	rak_bahan.add_child(_bahan_box)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in range(0, 6):
		var teks: String = "Semua" if t == 0 else "T%d" % t
		var b: Button = ProceduralUIFactory.button(teks, "secondary")
		b.custom_minimum_size = Vector2(TAB_LEBAR, ProceduralUIFactory.TOUCH_MIN)
		b.pressed.connect(_on_filter.bind(t))
		tabs.add_child(b)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)

	_content = VBoxContainer.new()
	_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 8)
	scroll.add_child(_content)


## Ketukan pada kaca gelap di luar kartu = tutup (GDD 12.4: satu ketukan).
func _on_scrim_input(event: InputEvent) -> void:
	var tekan: bool = (event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tekan:
		_on_close()


func _on_filter(t: int) -> void:
	_tier_filter = t
	AudioBus.sfx("tap")
	_render()


func _on_close() -> void:
	AudioBus.sfx("tap")
	# Menutup daftar berarti karakter batal mengambil bahan: pintu gudang ikut
	# ditutup dan ia dilepaskan untuk tugas berikutnya.
	var pt: PlayerTaskSystem = _tasks()
	if pt != null:
		pt.cancel_storage()
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


func _render() -> void:
	if _content == null:
		return
	_coin_label.text = GameConfig.kr(GameState.coins)
	if _gudang_label != null:
		_gudang_label.text = _gudang_text()
	_render_bahan()
	for c in _content.get_children():
		c.queue_free()
	for rid in RecipeDB.ids():
		var e: Dictionary = RecipeDB.entry(rid)
		if _tier_filter > 0 and int(e.get("tier", 1)) != _tier_filter:
			continue
		_content.add_child(_recipe_card(rid, e))


## Baris keterangan gudang: nama perabot + isi terhadap kapasitasnya.
## Kapasitas mengikuti tier LOKASI (GDD 5.2.2), bukan alat yang dibeli terpisah.
func _gudang_text() -> String:
	return "%s  •  %d / %d unit bahan" % [
		LocationDB.storage_name(GameState.location_tier),
		GameState.pantry_total(), GameState.pantry_capacity()]


func _recipe_card(rid: String, e: Dictionary) -> Control:
	var terbuka: bool = GameState.unlocked_recipes.has(rid)
	var tersedia: bool = GameState.is_recipe_available(rid)

	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL if terbuka else Palette.PANEL_ALT, 18, true))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	pc.add_child(m)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	m.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	head.add_child(ProceduralUIFactory.icon("bread", 26, Palette.GOLDEN_CRUST))
	var nama: Label = ProceduralUIFactory.label(
		"%s   (Tier %d)" % [String(e.get("name", rid)), int(e.get("tier", 1))], 18)
	nama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(nama)
	v.add_child(head)

	# Angka ekonomi PERSIS dari tabel GDD 5.3.
	var angka: Label = ProceduralUIFactory.label(
		"Modal %s  •  Sweet spot %s / batch  •  Profit %s"
		% [GameConfig.kr(float(e.get("modal", 0))),
			GameConfig.kr(float(e.get("batch_price", 0))),
			GameConfig.kr(float(e.get("profit", 0)))],
		12, Palette.TEXT_MUTED)
	angka.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(angka)

	# Waktu yang BENAR-BENAR terjadi di dapur, bukan `time_sec` tabel GDD.
	var d: Dictionary = _durasi_alat()
	var waktu: Label = ProceduralUIFactory.label(
		"Aduk %.0f dtk + panggang %.0f dtk = %.0f dtk per siklus  •  %d roti per batch"
		% [float(d["aduk"]), float(d["panggang"]), float(d["total"]),
			int(e.get("yield_count", 1))],
		12, Palette.TEXT_MUTED)
	waktu.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(waktu)
	v.add_child(_ingredient_chips(e))

	if not terbuka:
		var harga: int = int(e.get("unlock_price", 0))
		var beli: Button = ProceduralUIFactory.button(
			"Buka Resep " + GameConfig.kr(float(harga)), "primary")
		beli.disabled = GameState.coins < float(harga)
		beli.pressed.connect(_on_unlock.bind(rid, harga))
		v.add_child(beli)
		return pc

	v.add_child(_price_row(rid, e))

	var aksi := HBoxContainer.new()
	aksi.add_theme_constant_override("separation", 8)
	var prod: ProductionSystem = _production()
	for n in [1, 3, 5]:
		var b: Button = ProceduralUIFactory.button("Buat x%d" % n, "primary")
		# Tombol dimatikan sejak awal bila bahannya memang tidak cukup untuk
		# jumlah batch itu — lebih jujur daripada menerima ketukan lalu menolak.
		b.disabled = not tersedia or (prod != null and not prod.can_queue(rid, n))
		b.pressed.connect(_on_produce.bind(rid, n))
		aksi.add_child(b)
	v.add_child(aksi)

	if not tersedia:
		v.add_child(ProceduralUIFactory.label(_why_unavailable(e), 12, Palette.DANGER))
	return pc


## Rak "Isi Gudang": seluruh bahan yang benar-benar dimiliki, beserta sisanya.
##
## Hanya bahan yang stoknya ada yang ditampilkan — daftar 18 bahan dengan
## belasan angka nol lebih sulit dibaca daripada empat angka yang berarti.
func _render_bahan() -> void:
	if _bahan_box == null:
		return
	for c in _bahan_box.get_children():
		c.queue_free()

	var ada: int = 0
	for id in IngredientDB.ids():
		var n: int = int(GameState.pantry.get(id, 0))
		if n <= 0:
			continue
		ada += 1
		_bahan_box.add_child(_chip("%s %d" % [_nama_bahan(id), n],
			Palette.PANEL_ALT, Palette.TEXT))
	if ada == 0:
		_bahan_box.add_child(_chip("Gudang kosong — belanja dulu di Pasar.",
			Palette.PANEL_ALT, Palette.DANGER))


## Kebutuhan satu resep, DIBANDINGKAN dengan isi gudang: "Tepung 3 / 12".
## Bahan yang kurang diberi warna bahaya, jadi penyebab tombol "Buat" mati
## terbaca tanpa perlu menghitung sendiri.
func _ingredient_chips(e: Dictionary) -> Control:
	var flow := HFlowContainer.new()
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 4)

	var ings: Dictionary = e.get("ingredients", {})
	for id_v in ings.keys():
		var id: String = String(id_v)
		var butuh: int = int(ings[id_v])
		var punya: int = int(GameState.pantry.get(id, 0))
		var cukup: bool = punya >= butuh
		flow.add_child(_chip("%s %d / %d" % [_nama_bahan(id), butuh, punya],
			Palette.PANEL_ALT if cukup else Color(Palette.DANGER, 0.16),
			Palette.TEXT_MUTED if cukup else Palette.DANGER))
	return flow


## Satu kapsul kecil berisi teks. Dipakai untuk daftar bahan supaya angka
## stoknya terbaca sebagai butiran terpisah, bukan satu kalimat panjang.
func _chip(teks: String, latar: Color, tinta: Color) -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(latar, 10, false))
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 8)
	m.add_theme_constant_override("margin_right", 8)
	m.add_theme_constant_override("margin_top", 2)
	m.add_theme_constant_override("margin_bottom", 2)
	pc.add_child(m)
	m.add_child(ProceduralUIFactory.label(teks, 12, tinta))
	return pc


func _nama_bahan(id: String) -> String:
	return String(IngredientDB.entry(id).get("name", id))


## Lama satu siklus produksi yang SEBENARNYA, menurut alat yang dimiliki pemain
## sekarang: {"aduk", "panggang", "total"} dalam detik nyata.
##
## Bukan `time_sec` dari tabel GDD. ProductionSystem tidak pernah membaca kolom
## itu — durasinya diambil dari EquipmentDB menurut tier mixer/oven, lalu dibagi
## kecepatan Asisten Dapur (GDD 3.2). Menampilkan angka tabel di sini berarti
## Buku Resep menjanjikan durasi yang tidak pernah terjadi: Roti Goreng tertulis
## 35 detik padahal di dapur Tier 1 ia sama-sama 50 detik seperti yang lain.
##
## Karena diturunkan dari alat, angkanya ikut mengecil begitu pemain meng-upgrade
## oven atau menyewa baker — dan itu justru memperlihatkan gunanya belanja.
func _durasi_alat() -> Dictionary:
	var speed: float = 1.0
	var prod: ProductionSystem = _production()
	if prod != null:
		speed = maxf(0.05, prod.baker_speed())
	var aduk: float = EquipmentDB.mixer_time(GameState.mixer_tier) / speed
	var panggang: float = EquipmentDB.oven_time(GameState.oven_tier) / speed
	return {"aduk": aduk, "panggang": panggang, "total": aduk + panggang}


## GDD 5.3 "Cara Kerja Resep": slider harga memunculkan emoji reaksi pelanggan.
func _price_row(rid: String, e: Dictionary) -> Control:
	var rentang: Vector2 = RecipeDB.sweet_spot_range(rid)
	var sekarang: float = GameState.recipe_price(rid)
	var min_v: float = maxf(1.0, rentang.x * 0.5)
	var max_v: float = rentang.y * 1.8

	var v := VBoxContainer.new()
	var row: HBoxContainer = ProceduralUIFactory.slider_row(
		"Harga per buah", min_v, max_v, sekarang)
	v.add_child(row)

	var reaksi: Label = ProceduralUIFactory.label(
		DialogDB.price_reaction(sekarang, rentang), 13)
	v.add_child(reaksi)
	v.add_child(ProceduralUIFactory.label(
		"Sweet spot: %s – %s per buah" % [GameConfig.kr(rentang.x), GameConfig.kr(rentang.y)],
		12, Palette.TEXT_MUTED))

	var slider: HSlider = _find_slider(row)
	if slider != null:
		slider.value_changed.connect(func(val: float) -> void:
			GameState.recipe_prices[rid] = val
			reaksi.text = DialogDB.price_reaction(val, rentang)
		)
	return v


func _find_slider(node: Node) -> HSlider:
	if node is HSlider:
		return node
	for c in node.get_children():
		var found: HSlider = _find_slider(c)
		if found != null:
			return found
	return null


func _why_unavailable(e: Dictionary) -> String:
	var tier: int = int(e.get("tier", 1))
	if GameState.mixer_tier < int(e.get("min_mixer", tier)):
		return "Butuh Mixer Tier %d." % int(e.get("min_mixer", tier))
	if GameState.oven_tier < int(e.get("min_oven", tier)):
		return "Butuh Oven Tier %d." % int(e.get("min_oven", tier))
	var butuh: int = int(e.get("min_baker_tier", 0))
	if butuh > 0:
		return "Butuh Asisten Dapur Tier %d yang sedang aktif." % butuh
	return "Belum bisa diproduksi."


func _on_unlock(rid: String, harga: int) -> void:
	if not GameState.spend_coins(float(harga), "buka_resep"):
		EventBus.toast.emit("Koin tidak cukup.", "warning")
		return
	if not GameState.unlocked_recipes.has(rid):
		GameState.unlocked_recipes.append(rid)
	if not GameState.recipe_prices.has(rid):
		GameState.recipe_prices[rid] = RecipeDB.unit_price_default(rid)
	AudioBus.sfx("coin")
	EventBus.recipe_unlocked.emit(rid)
	EventBus.toast.emit("Resep %s terbuka!" % String(
		RecipeDB.entry(rid).get("name", rid)), "note")
	_render()


## Memesan satu resep. Yang terjadi setelah ini bukan urusan layar: karakter
## menutup gudang, dan tanda seru muncul di mixer yang harus ia hampiri.
func _on_produce(rid: String, batches: int) -> void:
	var pt: PlayerTaskSystem = _tasks()
	if pt == null:
		EventBus.toast.emit("Karakter belum siap bekerja.", "warning")
		return
	if not pt.choose_recipe(rid, batches):
		EventBus.toast.emit("Tidak bisa: bahan kurang atau mixer penuh.", "warning")
		_render()
		return
	# Daftar ditutup TANPA cancel_storage(): pintunya sudah diurus choose_recipe().
	if not ScreenRouter.back():
		ScreenRouter.go("hud")


func _tasks() -> PlayerTaskSystem:
	return _systems().get("player") as PlayerTaskSystem


func _production() -> ProductionSystem:
	return _systems().get("prod") as ProductionSystem


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
