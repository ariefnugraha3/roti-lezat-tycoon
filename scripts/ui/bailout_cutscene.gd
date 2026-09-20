class_name BailoutCutscene
extends Control
## Cutscene "Kunjungan Pak Lurah" (GDD 3.0.A).
##
## Muncul pagi hari sebelum toko buka saat bailout terpicu. Nadanya hangat dan
## menenangkan — GDD tegas menyatakan tidak ada Game Over, tidak ada stigma, dan
## tidak ada penalti rating.

const TYPE_SPEED: float = 42.0  ## karakter per detik

var _times: int = 1
var _dialog_label: Label = null
var _full_text: String = ""
var _shown: float = 0.0
var _done: bool = false
var _lanjut: Button = null
var _viewport: SubViewport = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)


func setup(args: Dictionary) -> void:
	_times = int(args.get("times", 1))
	_rebuild()


func _rebuild() -> void:
	for c in get_children():
		c.queue_free()
	_done = false
	_shown = 0.0

	var bg := ColorRect.new()
	# Pagi hari yang lembut, bukan layar gelap menghukum.
	bg.color = Palette.GOLDEN_HOUR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 10)
	add_child(root)

	# Pak Lurah digambar sungguhan sebagai model 3D prosedural, bukan gambar.
	var frame := CenterContainer.new()
	root.add_child(frame)
	frame.add_child(_build_lurah_portrait())

	var nama: Label = ProceduralUIFactory.title("Pak Lurah", 26)
	nama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(nama)

	var center := CenterContainer.new()
	root.add_child(center)

	var kartu: PanelContainer = ProceduralUIFactory.card("")
	kartu.custom_minimum_size = Vector2(620, 0)
	center.add_child(kartu)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	ProceduralUIFactory.content_of(kartu).add_child(v)

	_full_text = DialogDB.lurah_bailout(_times)
	_dialog_label = ProceduralUIFactory.label("", 17)
	_dialog_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_label.custom_minimum_size = Vector2(0, 96)
	v.add_child(_dialog_label)

	v.add_child(ProceduralUIFactory.dashed_separator())

	# GDD 3.0.B — isi paket bantuan, ditulis apa adanya supaya pemain paham.
	var paket: Label = ProceduralUIFactory.label(
		"Bantuan diterima: %s  +  Bahan Baku Darurat Tier 1 (Tepung, Ragi, Gula, Air & Garam)"
		% GameConfig.kr(GameConfig.BAILOUT_COINS), 15, Palette.SUCCESS)
	paket.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(paket)

	# GDD 3.0.B peringatan: 650 KR tidak cukup untuk menggaji karyawan.
	var ingat: Label = ProceduralUIFactory.label(
		"Bantuan ini belum cukup untuk membayar gaji harian. Karyawan diliburkan "
		+ "sementara — kamu jalan sendiri dulu sampai kas pulih (Mode Solo).",
		14, Palette.TEXT_MUTED)
	ingat.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(ingat)

	_lanjut = ProceduralUIFactory.button("Terima kasih, Pak!", "primary")
	_lanjut.disabled = true
	_lanjut.pressed.connect(_on_continue)
	v.add_child(_lanjut)

	AudioBus.sfx("door")
	AudioBus.start_music("cozy")


## Potret 3D Pak Lurah di dalam SubViewport kecil — tetap 100% prosedural.
func _build_lurah_portrait() -> Control:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(220, 220)
	_viewport.transparent_bg = true
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS

	var world := Node3D.new()
	_viewport.add_child(world)

	var lurah: Node3D = CharacterFactory.build(CharacterFactory.spec_for_lurah())
	lurah.position = Vector3(0.0, -0.45, 0.0)
	lurah.rotation_degrees = Vector3(0.0, 18.0, 0.0)
	world.add_child(lurah)

	var cam := Camera3D.new()
	cam.position = Vector3(0.0, 0.25, 1.35)
	cam.fov = 44.0
	world.add_child(cam)

	var lamp := DirectionalLight3D.new()
	lamp.light_color = Palette.GOLDEN_HOUR
	lamp.light_energy = 1.25
	lamp.rotation_degrees = Vector3(-32.0, 28.0, 0.0)
	world.add_child(lamp)

	var vc := SubViewportContainer.new()
	vc.stretch = true
	vc.custom_minimum_size = Vector2(220, 220)
	vc.add_child(_viewport)
	return vc


func _process(delta: float) -> void:
	if _done or _dialog_label == null:
		return
	_shown += delta * TYPE_SPEED
	var n: int = mini(int(_shown), _full_text.length())
	_dialog_label.text = _full_text.substr(0, n)
	if n >= _full_text.length():
		_done = true
		if _lanjut != null:
			_lanjut.disabled = false
			ProceduralAnimationSystem.press_bounce(_lanjut)


## Tap di mana saja melewatkan animasi ketik (tap-first, GDD 12.4).
func _gui_input(event: InputEvent) -> void:
	var tapped: bool = false
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		tapped = true
	elif event is InputEventScreenTouch and (event as InputEventScreenTouch).pressed:
		tapped = true
	if tapped and not _done:
		_shown = float(_full_text.length())


func _on_continue() -> void:
	AudioBus.sfx("coin")
	ScreenRouter.go("hud")
