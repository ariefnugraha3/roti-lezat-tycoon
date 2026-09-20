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

var _content: VBoxContainer = null
var _coin_label: Label = null
var _gudang_label: Label = null
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
	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	margin.add_theme_constant_override("margin_left", int(safe.x) + 20)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 16)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 20)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 16)
	add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	margin.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	var judul: Label = ProceduralUIFactory.title("Buku Resep", 28)
	judul.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(judul)
	head.add_child(ProceduralUIFactory.icon("coin", 22, Palette.GOLD_STAR))
	_coin_label = ProceduralUIFactory.label(GameConfig.kr(GameState.coins), 18)
	head.add_child(_coin_label)
	var tutup: Button = ProceduralUIFactory.button("Tutup", "ghost")
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	var gudang := HBoxContainer.new()
	gudang.add_theme_constant_override("separation", 8)
	v.add_child(gudang)
	gudang.add_child(ProceduralUIFactory.icon("box", 18, Palette.UI_WOOD))
	_gudang_label = ProceduralUIFactory.label(_gudang_text(), 13, Palette.TEXT_MUTED)
	gudang.add_child(_gudang_label)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	v.add_child(tabs)
	for t in range(0, 6):
		var teks: String = "Semua" if t == 0 else "Tier %d" % t
		var b: Button = ProceduralUIFactory.button(teks, "secondary")
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
	v.add_child(ProceduralUIFactory.label(
		"Modal %s  •  Sweet spot %s / batch  •  Profit %s  •  %.0f detik  •  %d per batch"
		% [GameConfig.kr(float(e.get("modal", 0))),
			GameConfig.kr(float(e.get("batch_price", 0))),
			GameConfig.kr(float(e.get("profit", 0))),
			float(e.get("time_sec", 0.0)), int(e.get("yield_count", 1))],
		12, Palette.TEXT_MUTED))
	v.add_child(ProceduralUIFactory.label(_ingredient_text(e), 12, Palette.TEXT_MUTED))

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


func _ingredient_text(e: Dictionary) -> String:
	var parts: PackedStringArray = []
	var ings: Dictionary = e.get("ingredients", {})
	for id in ings.keys():
		parts.append("%s (%d)" % [
			String(IngredientDB.entry(id).get("name", id)), int(ings[id])])
	return "Bahan: " + " + ".join(parts)


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
