class_name PortraitShell
extends Control
## Bingkai potret (GDD idle 12.0.2): seluruh game digambar di dalam satu bingkai
## di tengah jendela, dan di luarnya hanya ada taplak (TableclothSides).
##
## Lebar logis bingkai selalu 720. Rasio lebar : tinggi dijepit antara 9:16 dan
## 9:21: layar yang lebih lebar dari 9:16 mendapat bingkai 9:16 setinggi layar
## dengan taplak di kiri dan kanan, layar di antara keduanya terisi penuh, dan
## layar yang lebih ramping dari 9:21 mendapat bingkai 9:21 dengan pita taplak
## di atas dan bawah.
##
## Camera3D tidak bisa merender hanya ke sebagian viewport, dan pita hitam mode
## aspect `keep` tidak bisa digambari, jadi GameRoot hidup di dalam SubViewport.
## `size_2d_override` menjaga koordinat UI logis 720 x H, sedangkan ukuran render
## SubViewport mengikuti piksel layar sebenarnya supaya gambar tetap tajam.
## SubViewportContainer meneruskan ketukan yang jatuh di dalam bingkai; ketukan,
## seretan, dan roda mouse di atas taplak tidak sampai ke game.
##
## Tes yang membuat GameRoot langsung (scenes/game_root.tscn) bekerja tanpa shell.

const LOGICAL_WIDTH: float = 720.0
## Rasio lebar : tinggi bingkai paling lebar (9:16) dan paling ramping (9:21).
const MAX_ASPECT: float = 9.0 / 16.0
const MIN_ASPECT: float = 9.0 / 21.0
const GAME_SCENE: String = "res://scenes/game_root.tscn"

## Shell yang sedang berjalan (null di tes yang membuat GameRoot langsung).
static var current: PortraitShell = null

var game: GameRoot = null
var cloth: TableclothSides = null
var container: SubViewportContainer = null
var viewport: SubViewport = null
## Kotak bingkai dalam koordinat logis jendela, dan piksel layar per satuan itu.
var frame: Rect2 = Rect2()
var pixel_scale: float = 1.0


func _ready() -> void:
	name = "PortraitShell"
	current = self
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.name = "Bg"
	bg.color = Palette.GINGHAM_B
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	cloth = TableclothSides.new()
	add_child(cloth)
	container = SubViewportContainer.new()
	container.name = "Frame"
	container.stretch = false
	container.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(container)
	viewport = SubViewport.new()
	viewport.name = "Game"
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	viewport.msaa_3d = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", 0)) as Viewport.MSAA
	container.add_child(viewport)
	get_viewport().size_changed.connect(_layout)
	_layout()
	game = (load(GAME_SCENE) as PackedScene).instantiate()
	viewport.add_child(game)


func _exit_tree() -> void:
	if current == self:
		current = null


## Kotak bingkai untuk jendela berukuran logis `root_size` (GDD idle 12.0.2).
static func frame_rect(root_size: Vector2) -> Rect2:
	if root_size.x <= 0.0 or root_size.y <= 0.0:
		return Rect2(Vector2.ZERO, root_size.max(Vector2.ZERO))
	var aspect: float = root_size.x / root_size.y
	var sz: Vector2 = root_size
	if aspect > MAX_ASPECT:
		sz = Vector2(root_size.y * MAX_ASPECT, root_size.y)
	elif aspect < MIN_ASPECT:
		sz = Vector2(root_size.x, root_size.x / MIN_ASPECT)
	return Rect2((root_size - sz) * 0.5, sz)


## Ukuran logis isi bingkai: lebar selalu 720, tinggi mengikuti rasio bingkai.
static func logical_size(r: Rect2) -> Vector2i:
	if r.size.x <= 0.0:
		return Vector2i(int(LOGICAL_WIDTH), 1280)
	return Vector2i(int(LOGICAL_WIDTH), int(round(LOGICAL_WIDTH * r.size.y / r.size.x)))


func _layout() -> void:
	var xf: Transform2D = get_viewport().get_final_transform()
	layout_for(get_viewport_rect().size, maxf(absf(xf.x.x), 0.0001))


## Susun bingkai untuk jendela logis `root_size` dengan `px_scale` piksel layar
## per satuan logis (dipakai juga oleh tes).
func layout_for(root_size: Vector2, px_scale: float) -> void:
	frame = frame_rect(root_size)
	pixel_scale = px_scale
	var px: Vector2i = Vector2i(maxi(1, int(round(frame.size.x * px_scale))), maxi(1, int(round(frame.size.y * px_scale))))
	viewport.size = px
	viewport.size_2d_override = logical_size(frame)
	# Isi kontainer dalam piksel layar; skala 1/px mengembalikannya ke ukuran bingkai.
	container.position = frame.position
	container.scale = Vector2.ONE / px_scale
	container.size = Vector2(px)
	cloth.set_frame(frame)


## Tepi aman layar dalam koordinat logis isi bingkai (GDD idle 12.0.5): notch
## dan bar gestur yang menimpa bingkai menggeser HUD ke dalam. `screen_insets`
## dalam piksel jendela: Vector4(kiri, atas, kanan, bawah).
func frame_insets(screen_insets: Vector4) -> Vector4:
	if frame.size.x <= 0.0:
		return Vector4.ZERO
	var win: Vector2 = get_viewport_rect().size * pixel_scale
	var fr: Rect2 = Rect2(frame.position * pixel_scale, frame.size * pixel_scale)
	var k: float = fr.size.x / LOGICAL_WIDTH
	return Vector4(
		maxf(0.0, screen_insets.x - fr.position.x) / k,
		maxf(0.0, screen_insets.y - fr.position.y) / k,
		maxf(0.0, screen_insets.z - (win.x - fr.end.x)) / k,
		maxf(0.0, screen_insets.w - (win.y - fr.end.y)) / k)
