class_name MovingCutscene
extends UIScreen
## Cutscene pindah lokasi (GDD idle §20 no. 70): dibuka GameRoot.start_move
## setelah pemain mengonfirmasi Move di lembar Shop. Adegan 3D-nya dimainkan
## MovingDay di dunia (truk, kru, perabot); layar ini menyembunyikan HUD, memberi
## pita judul dan tombol Skip, menutup layar dengan warna krem saat truk sudah
## pergi lalu menjalankan pindah lokasi TEPAT SEKALI (`SimulationRoot.
## upgrade_location`, mekanisme v3.1 §45.2: Skip mempercepat tetapi transaksi
## tetap sekali), lalu menampilkan kartu ucapan selamat Pak Lurah saat kru sudah
## berbaris di depan toko baru. Tombol kartunya membuat kru masuk toko dan
## permainan berlanjut.
##
## Modal pemblokir (simulasi di-pause, input dunia mati) yang `keep_open`; Back
## sama dengan Skip, dan saat kartu tampil sama dengan tombol kartunya.

const FADE_SECONDS: float = 0.35

var director: MovingDay = null
## true setelah lokasi benar-benar pindah.
var moved: bool = false
var _swapping: bool = false
var _ended: bool = false
var _saved_width: float = 0.0
var _to_key: String = ""
var _cover: ColorRect = null
var _cover_text: Label = null
var _caption: Control = null
var _skip: Button = null
var _card: Control = null


func _init() -> void:
	super._init()
	blocking = true
	keep_open = true


func build() -> void:
	var nxt: LocationDefinition = sim.next_location() if sim != null else null
	_to_key = String(nxt.localization_key) if nxt != null else ""
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	# Pita judul di atas dan Skip di kanan atas.
	var top := MarginContainer.new()
	top.name = "Top"
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.add_theme_constant_override("margin_left", int(inset.x) + 16)
	top.add_theme_constant_override("margin_right", int(inset.z) + 16)
	top.add_theme_constant_override("margin_top", int(inset.y) + 16)
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(top)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(row)
	_caption = ProceduralUIFactory.chip("shop", Palette.HONEY_DEEP, Tx.t("ui_moving_caption", {"location": Tx.t(_to_key)}), 20, 28)
	_caption.name = "Caption"
	_caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cap_label: Label = _caption.get_meta("value")
	cap_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	cap_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_caption)
	_skip = ProceduralUIFactory.button(Tx.t("ui_moving_skip"), "plain")
	_skip.name = "Skip"
	_skip.custom_minimum_size = Vector2(120, 56)
	_skip.pressed.connect(skip)
	row.add_child(_skip)
	# Layar krem saat truk di jalan (pindah lokasi dijalankan di baliknya).
	_cover = ColorRect.new()
	_cover.name = "Cover"
	_cover.color = Color(Palette.UI_CREAM, 0.0)
	_cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	_cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cover)
	var cc := CenterContainer.new()
	cc.set_anchors_preset(Control.PRESET_FULL_RECT)
	cc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cover.add_child(cc)
	_cover_text = ProceduralUIFactory.label(Tx.t("ui_moving_road", {"location": Tx.t(_to_key)}), 26, Palette.UI_WOOD_DEEP)
	_cover_text.name = "Road"
	_cover_text.add_theme_font_override("font", ProceduralUIFactory.display_font())
	_cover_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cover_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cover_text.custom_minimum_size = Vector2(minf(560.0, get_viewport_rect().size.x - 64.0), 0)
	_cover_text.modulate.a = 0.0
	cc.add_child(_cover_text)
	if game == null or game.world == null:
		return
	_saved_width = game.world.camera_rig.ortho_size
	if game.hud != null:
		game.hud.visible = false
	game.world.set_cutscene(true)
	director = MovingDay.new().setup(sim, game.world)
	game.world.add_child(director)
	director.departed.connect(_on_departed)
	director.greeting.connect(_on_greeting)
	director.finished.connect(_on_finished)
	var t0: int = Time.get_ticks_usec()
	director.begin()
	GameLogger.info("UI", "moving cutscene to %s built in %.1f ms" % [_to_key, float(Time.get_ticks_usec() - t0) / 1000.0])


## Skip / Back: lompat ke kru berbaris di depan toko baru (pindah lokasi tetap
## dijalankan sekali); saat kartu tampil = tombol kartunya; saat kru masuk = selesai.
func skip() -> void:
	if _ended or _swapping:
		return
	if _card != null:
		_continue()
		return
	if director == null:
		close()
		return
	if director.phase == MovingDay.Phase.ENTER or director.phase == MovingDay.Phase.DONE:
		close()
		return
	if not moved:
		_swap(true)
		return
	director.skip_to_greet()


func on_back() -> bool:
	skip()
	return true


func _on_departed() -> void:
	_swap(false)


## Tutup layar dengan krem, pindah lokasi, bangun dunia baru, lalu buka lagi.
func _swap(instant: bool) -> void:
	if _swapping or moved:
		return
	_swapping = true
	var tw: Tween = create_tween()
	tw.tween_property(_cover, "color:a", 1.0, FADE_SECONDS * (0.6 if instant else 1.0))
	tw.parallel().tween_property(_cover_text, "modulate:a", 1.0, FADE_SECONDS)
	await tw.finished
	if not is_inside_tree() or _ended:
		return
	var r: String = sim.upgrade_location()
	if r != "":
		EventBus.notify.emit(1, r, {}, &"warning")
		_swapping = false
		close()
		return
	moved = true
	# Dunia baru dibangun saat location_changed; beri beberapa frame (pemanasan shader).
	for i in 3:
		await get_tree().process_frame
	if not is_inside_tree() or _ended:
		return
	if director != null and is_instance_valid(director):
		director.arrive(instant)
	var tw2: Tween = create_tween()
	tw2.tween_property(_cover, "color:a", 0.0, FADE_SECONDS)
	tw2.parallel().tween_property(_cover_text, "modulate:a", 0.0, FADE_SECONDS * 0.6)
	_swapping = false


func _on_greeting() -> void:
	if _card != null or _ended:
		return
	_skip.visible = false
	_card = _build_card()
	add_child(_card)
	if not SettingsManager.reduced_motion():
		ProceduralAnimationSystem.squash_pop(_card, 1.04, 0.2)
	EventBus.sfx.emit(&"welcome_back_chime", &"")


## Kartu Pak Lurah di bawah layar: potret, ucapan, dan tombol lanjut.
func _build_card() -> Control:
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var m := MarginContainer.new()
	m.name = "LurahCard"
	m.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	m.grow_vertical = Control.GROW_DIRECTION_BEGIN
	m.add_theme_constant_override("margin_left", int(inset.x) + 20)
	m.add_theme_constant_override("margin_right", int(inset.z) + 20)
	m.add_theme_constant_override("margin_bottom", int(inset.w) + 24)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pc := PanelContainer.new()
	var sb: StyleBoxFlat = ProceduralUIFactory.panel(Palette.CARD, 24, true)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 18
	sb.content_margin_bottom = 20
	pc.add_theme_stylebox_override("panel", sb)
	m.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	pc.add_child(v)
	var h: HBoxContainer = hbox(v, 16)
	var portrait := LurahPortrait.new()
	portrait.name = "Lurah"
	portrait.custom_minimum_size = Vector2(120, 120)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	words.add_theme_constant_override("separation", 4)
	h.add_child(words)
	var who: Label = lbl(words, Tx.t("ui_moving_lurah_name"), 18, Palette.UI_WOOD)
	who.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var line: Label = lbl(words, Tx.t("ui_moving_lurah", {"location": Tx.t(_to_key), "name": sim.bakery_name if sim != null else ""}), 20, Palette.TEXT, true)
	line.name = "Line"
	var c := CenterContainer.new()
	v.add_child(c)
	var b: Button = btn(c, Tx.t("ui_moving_start"), "primary", _continue)
	b.name = "Continue"
	b.custom_minimum_size = Vector2(300, 64)
	return m


func _continue() -> void:
	if _card == null or _ended:
		return
	_card.queue_free()
	_card = null
	_skip.visible = true
	if director != null and is_instance_valid(director):
		director.enter()
	else:
		close()


func _on_finished() -> void:
	close()


## Tombol kartu Pak Lurah bila tampil (tes, panduan), atau null.
func continue_button() -> Button:
	return _card.find_child("Continue", true, false) as Button if _card != null else null


func skip_button() -> Button:
	return _skip


## Kamera dikembalikan sutradara pelan-pelan (atau langsung bila ia sudah tidak
## ada); HUD dan aktor simulasi tampil lagi.
func on_closed() -> void:
	_ended = true
	var world_ok: bool = game != null and game.world != null and is_instance_valid(game.world)
	if director != null and is_instance_valid(director):
		director.release(_saved_width)
	elif world_ok:
		game.world.camera_rig.cutscene_focus = Vector3.INF
		if _saved_width > 0.0:
			game.world.camera_rig.ortho_size = _saved_width
	director = null
	if world_ok:
		game.world.set_cutscene(false)
	if game != null and game.hud != null and is_instance_valid(game.hud):
		game.hud.visible = true
