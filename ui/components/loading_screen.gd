class_name LoadingScreen
extends CanvasLayer
## Layar loading bertahap (GDD 89.5, 114): teks tahap berbahasa Inggris dan bar
## kemajuan menurut tahap yang sudah selesai, bukan persentase palsu. Menutup
## seluruh layar dan menahan ketukan sampai dunia siap, lalu memudar.
##
## GameRoot memberi satu frame di antara tahap berat, jadi teks dan bar terbaru
## sempat tergambar sebelum tahap berikutnya berjalan.

const LAYER: int = 60
const FADE_OUT: float = 0.25
## Bar mengejar target dengan halus (per detik).
const BAR_EASE: float = 9.0
const BAR_WIDTH: float = 460.0

var _root: Control = null
var _icon: IconCanvas = null
var _stage: Label = null
var _bar: ProgressBar = null
var _target: float = 0.0
var _shown: float = 0.0
var _t: float = 0.0
var _stages: PackedStringArray = PackedStringArray()


func _init() -> void:
	layer = LAYER
	name = "LoadingScreen"
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_root)
	ProceduralUIFactory.apply_theme(_root)
	_root.add_child(ProceduralUIFactory.backdrop())
	var center := CenterContainer.new()
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 18)
	center.add_child(v)
	var art := CenterContainer.new()
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.custom_minimum_size = Vector2(0, 104)
	v.add_child(art)
	_icon = ProceduralUIFactory.icon("bread", 96, Palette.GOLDEN_CRUST)
	art.add_child(_icon)
	_stage = ProceduralUIFactory.title("", 28)
	v.add_child(_stage)
	_bar = ProgressBar.new()
	_bar.name = "Bar"
	_bar.show_percentage = false
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.custom_minimum_size = Vector2(BAR_WIDTH, 28)
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(_bar)


## Tahap baru: teks tahap dan target bar (0..1, tidak pernah mundur).
func set_stage(text: String, progress_value: float) -> void:
	_stage.text = text
	_stages.append(text)
	set_progress(progress_value)


func set_progress(p: float) -> void:
	_target = maxf(_target, clampf(p, 0.0, 1.0))


func progress() -> float:
	return _target


func stage_text() -> String:
	return _stage.text


## Semua teks tahap yang pernah tampil, berurutan.
func stages() -> PackedStringArray:
	return _stages


func _process(delta: float) -> void:
	_t += delta
	_shown = lerpf(_shown, _target, minf(1.0, delta * BAR_EASE))
	if _target - _shown < 0.002:
		_shown = _target
	_bar.value = _shown
	if not SettingsManager.reduced_motion():
		# Roti memantul pelan: tanda game masih hidup di antara tahap.
		_icon.position.y = -absf(sin(_t * 4.0)) * 10.0


## Bar penuh, ketukan langsung dilepas, lalu memudar dan hilang.
func finish() -> void:
	_target = 1.0
	_bar.value = 1.0
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not is_inside_tree():
		queue_free()
		return
	var tw: Tween = _root.create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, FADE_OUT)
	tw.tween_callback(queue_free)
