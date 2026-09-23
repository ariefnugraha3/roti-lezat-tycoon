class_name SettingsScreen
extends Control
## Menu dalam permainan: suara, kembali ke menu utama, dan keluar.
##
## Dibuka dari tombol roda gigi di HUD atau dari tombol/gestur "Back" Android
## (GDD 12.1) — dua-duanya sampai di layar yang sama, sehingga pemain ponsel dan
## pemain web memakai jalur yang persis sama.
##
## Layar ini POPUP: dapur dan HUD tetap terlihat di belakangnya. Selama menu
## terbuka waktu DIJEDA, lalu keadaan jeda sebelumnya dikembalikan saat ditutup
## — oven yang sedang memanggang tidak boleh hangus hanya karena pemain membuka
## menu untuk mematikan suara. Kalau pemain sendiri yang sudah menjeda permainan
## sebelum membuka menu, permainan tetap terjeda setelah menu ditutup.
##
## Aksi merusak (keluar ke menu utama / menutup permainan) selalu lewat satu
## langkah konfirmasi di dalam kartu yang sama, bukan dialog sistem: satu
## ketukan tidak boleh membuang hari yang sedang berjalan.

## Ukuran kartu: setinggi POPUP_SIZE, tapi jauh lebih ramping — isinya satu
## kolom tombol, bukan daftar yang perlu digulir.
const CARD_SIZE: Vector2 = Vector2(460.0, 520.0)

var _content: VBoxContainer = null
var _main: Node = null

## "" = daftar menu biasa, "menu" / "quit" = sedang menunggu konfirmasi.
var _pending: String = ""
## Keadaan jeda SEBELUM menu dibuka, untuk dikembalikan saat menu ditutup.
var _was_paused: bool = false
## True selagi menu memegang jeda; menjaga agar jeda tidak dikembalikan dua kali.
var _holding_pause: bool = false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)
	_build_shell()
	# Ditutup lewat jalur mana pun (tombol X, kaca gelap, tombol Back Android),
	# hasilnya satu: waktu berjalan lagi seperti sebelum menu dibuka.
	visibility_changed.connect(_on_visibility_changed)
	_render()


func setup(_args: Dictionary) -> void:
	_main = _find_main()
	_pending = ""
	_hold_time()
	_render()


func _build_shell() -> void:
	var popup: Control = ProceduralUIFactory.popup("Menu", CARD_SIZE)
	add_child(popup)
	var head: HBoxContainer = popup.get_meta("head")
	var body: VBoxContainer = popup.get_meta("body")
	(popup.get_meta("scrim") as Control).gui_input.connect(_on_scrim_input)

	var tutup: Button = ProceduralUIFactory.icon_button("cross", "Tutup", "ghost", 22)
	tutup.pressed.connect(_on_close)
	head.add_child(tutup)

	_content = VBoxContainer.new()
	_content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content.add_theme_constant_override("separation", 10)
	body.add_child(_content)


# ===========================================================================
# ISI
# ===========================================================================

func _render() -> void:
	if _content == null or not is_instance_valid(_content):
		return
	# Anak lama DILEPAS dari pohon, bukan sekadar di-queue_free(): node yang
	# menunggu dibuang masih ikut dihitung layout dan masih bisa menerima
	# ketukan pada frame yang sama.
	for c in _content.get_children():
		_content.remove_child(c)
		c.queue_free()

	if _pending != "":
		_render_confirm()
		return

	_content.add_child(_baris_suara())
	_content.add_child(ProceduralUIFactory.dashed_separator())

	var lanjut: Button = ProceduralUIFactory.button("Lanjut Main", "primary")
	lanjut.pressed.connect(_on_close)
	_content.add_child(lanjut)

	var ke_menu: Button = ProceduralUIFactory.button("Simpan & ke Menu Utama", "secondary")
	ke_menu.pressed.connect(_on_ask.bind("menu"))
	_content.add_child(ke_menu)

	# Di Web tidak ada "keluar aplikasi": tab peramban hanya bisa ditutup oleh
	# pemainnya sendiri, jadi tombolnya diganti keterangan (GDD 12.1).
	if OS.has_feature("web"):
		var catatan: Label = ProceduralUIFactory.label(
			"Di peramban, tutup tabnya untuk keluar. Progres tersimpan otomatis.",
			13, Palette.TEXT_MUTED)
		catatan.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		catatan.custom_minimum_size = Vector2(CARD_SIZE.x - 80.0, 0.0)
		_content.add_child(catatan)
	else:
		var keluar: Button = ProceduralUIFactory.button("Simpan & Keluar", "danger")
		keluar.pressed.connect(_on_ask.bind("quit"))
		_content.add_child(keluar)

	_content.add_child(_pengisi())

	var info: Label = ProceduralUIFactory.label(
		"Waktu dijeda selama menu terbuka.", 13, Palette.TEXT_MUTED)
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(info)


## Baris suara: ikon yang ikut berubah (pengeras suara / disilang) + tombolnya.
func _baris_suara() -> Control:
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel",
		ProceduralUIFactory.panel(Palette.PANEL_ALT, 18, false))

	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 14)
	m.add_theme_constant_override("margin_right", 14)
	m.add_theme_constant_override("margin_top", 10)
	m.add_theme_constant_override("margin_bottom", 10)
	pc.add_child(m)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	m.add_child(h)

	var senyap: bool = AudioBus.muted
	h.add_child(ProceduralUIFactory.icon(
		"mute" if senyap else "sound", 26,
		Palette.TEXT_MUTED if senyap else Palette.UI_WOOD))

	var nama: Label = ProceduralUIFactory.label("Suara", 18)
	nama.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nama)

	var b: Button = ProceduralUIFactory.button(
		"Mati" if senyap else "Nyala", "secondary" if senyap else "primary")
	b.tooltip_text = "Nyalakan suara" if senyap else "Matikan suara"
	b.pressed.connect(_on_toggle_sound)
	h.add_child(b)
	return pc


## Satu langkah konfirmasi sebelum hari yang sedang berjalan ditinggalkan.
func _render_confirm() -> void:
	var judul: String = "Keluar ke menu utama?" if _pending == "menu" \
		else "Tutup permainan sekarang?"
	var l: Label = ProceduralUIFactory.label(judul, 20)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(CARD_SIZE.x - 80.0, 0.0)
	_content.add_child(l)

	var ket: Label = ProceduralUIFactory.label(
		"Progres hari ini disimpan lebih dulu.", 14, Palette.TEXT_MUTED)
	ket.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_content.add_child(ket)

	_content.add_child(_pengisi())

	var ya: Button = ProceduralUIFactory.button(
		"Ya, ke Menu Utama" if _pending == "menu" else "Ya, Keluar", "danger")
	ya.pressed.connect(_on_confirm)
	_content.add_child(ya)

	var batal: Button = ProceduralUIFactory.button("Batal", "secondary")
	batal.pressed.connect(_on_cancel)
	_content.add_child(batal)


## Ruang elastis yang mendorong tombol ke bawah kartu.
func _pengisi() -> Control:
	var s := Control.new()
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


# ===========================================================================
# AKSI
# ===========================================================================

func _on_toggle_sound() -> void:
	var senyap: bool = AudioBus.toggle_mute()
	# Bunyi konfirmasi hanya masuk akal saat suara BARU SAJA dinyalakan.
	if not senyap:
		AudioBus.sfx("pop")
	EventBus.toast.emit("Suara dimatikan" if senyap else "Suara dinyalakan",
		"mute" if senyap else "sound")
	_render()


func _on_ask(what: String) -> void:
	AudioBus.sfx("tap")
	_pending = what
	_render()


func _on_cancel() -> void:
	AudioBus.sfx("pop")
	_pending = ""
	_render()


func _on_confirm() -> void:
	var what: String = _pending
	_pending = ""
	SaveManager.save_game()
	if what == "menu":
		_to_main_menu()
		return
	get_tree().quit()


## Kembali ke menu utama tanpa menutup aplikasi.
##
## Menu ditutup lebih dulu lewat jalur biasa supaya HUD kembali menjadi layar
## teratas; barulah `go("main_menu")` menyembunyikannya. Melompat langsung ke
## menu utama akan meninggalkan HUD tetap terlihat di belakangnya.
func _to_main_menu() -> void:
	_release_time(true)
	if not ScreenRouter.back():
		ScreenRouter.close_all()
	AudioBus.start_music("menu")
	ScreenRouter.go("main_menu")


func _on_close() -> void:
	AudioBus.sfx("tap")
	_pending = ""
	if not ScreenRouter.back():
		ScreenRouter.close_all()


## Ketukan pada kaca gelap di luar kartu = tutup (GDD 12.4: satu ketukan).
func _on_scrim_input(event: InputEvent) -> void:
	var tekan: bool = (event is InputEventMouseButton
			and (event as InputEventMouseButton).pressed) \
		or (event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed)
	if tekan:
		_on_close()


func _on_visibility_changed() -> void:
	if not visible:
		_release_time(false)


# ===========================================================================
# JEDA
# ===========================================================================

## Menjeda waktu selama menu terbuka, sambil mengingat keadaan sebelumnya.
func _hold_time() -> void:
	var day: DayCycle = _day()
	if day == null or _holding_pause:
		return
	_was_paused = day.is_paused()
	_holding_pause = true
	day.set_paused(true)


## Mengembalikan keadaan jeda seperti sebelum menu dibuka.
## [param force_paused] dipakai saat pemain keluar ke menu utama: di sana
## simulasi memang harus berhenti sampai ia menekan "Lanjutkan" atau "Main Baru".
func _release_time(force_paused: bool) -> void:
	var day: DayCycle = _day()
	if day == null:
		_holding_pause = false
		return
	if not _holding_pause and not force_paused:
		return
	_holding_pause = false
	day.set_paused(true if force_paused else _was_paused)


func _day() -> DayCycle:
	return _systems().get("day") as DayCycle


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
