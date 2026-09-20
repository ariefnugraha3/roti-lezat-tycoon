class_name MainMenu
extends Control
## Menu utama. Dibangun sepenuhnya lewat ProceduralUIFactory (GDD 4.3).

var _main: Node = null


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	ProceduralUIFactory.apply_theme(self)

	var bg := ColorRect.new()
	bg.color = Palette.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	var safe: Vector4 = ProceduralUIFactory.safe_area_margin()
	margin.add_theme_constant_override("margin_left", int(safe.x) + 28)
	margin.add_theme_constant_override("margin_top", int(safe.y) + 24)
	margin.add_theme_constant_override("margin_right", int(safe.z) + 28)
	margin.add_theme_constant_override("margin_bottom", int(safe.w) + 24)
	add_child(margin)

	var center := CenterContainer.new()
	margin.add_child(center)

	var kartu: PanelContainer = ProceduralUIFactory.card("")
	kartu.custom_minimum_size = Vector2(460, 0)
	center.add_child(kartu)

	var kolom := VBoxContainer.new()
	kolom.add_theme_constant_override("separation", 14)
	var isi: Node = ProceduralUIFactory.content_of(kartu)
	isi.add_child(kolom)

	var judul: Label = ProceduralUIFactory.title("Roti Lezat Tycoon", 38)
	judul.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(judul)

	var sub: Label = ProceduralUIFactory.label(
		"Bangun kerajaan roti dari garasi rumah", 16, Palette.TEXT_MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kolom.add_child(sub)

	var hias := CenterContainer.new()
	hias.add_child(ProceduralUIFactory.icon("bread", 72, Palette.GOLDEN_CRUST))
	kolom.add_child(hias)

	kolom.add_child(ProceduralUIFactory.dashed_separator())

	var punya_save: bool = SaveManager.has_save()

	if punya_save:
		var lanjut: Button = ProceduralUIFactory.button("Lanjutkan", "primary")
		lanjut.pressed.connect(_on_continue)
		kolom.add_child(lanjut)

	var baru: Button = ProceduralUIFactory.button(
		"Main Baru", "primary" if not punya_save else "secondary")
	baru.pressed.connect(_on_new_game)
	kolom.add_child(baru)

	if punya_save:
		var info: Label = ProceduralUIFactory.label(
			"Main Baru akan menimpa progres tersimpan.", 13, Palette.TEXT_MUTED)
		info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		kolom.add_child(info)

	var keluar: Button = ProceduralUIFactory.button("Keluar", "ghost")
	keluar.pressed.connect(_on_quit)
	kolom.add_child(keluar)


func setup(_args: Dictionary) -> void:
	_main = _find_main()


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


## "Main Baru" tidak langsung memulai: pemain memilih karakternya dulu, dan
## layar itulah yang memanggil Main.new_game() dengan pilihannya.
func _on_new_game() -> void:
	AudioBus.sfx("pop")
	ScreenRouter.go("character_select")


func _on_continue() -> void:
	AudioBus.sfx("pop")
	var m: Node = _main if _main != null else _find_main()
	if m == null or not m.has_method("continue_game"):
		return
	if not bool(m.call("continue_game")):
		EventBus.toast.emit("Gagal memuat simpanan. Coba Main Baru.", "warning")


func _on_quit() -> void:
	AudioBus.sfx("tap")
	get_tree().quit()
