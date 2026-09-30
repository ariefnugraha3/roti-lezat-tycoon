class_name CameraRig
extends Node3D
## CameraManager (GDD 30, 98, 130.1) — kamera isometrik ortografis yang mengikuti
## karakter pemain. Yaw 45°, pitch 35°, rotasi dikunci. Lantai aktif selalu
## lantai tempat pemain berada; perpindahan lantai memakai crossfade 0,20 detik
## nyata tanpa menambah waktu in-game. Event rutin tidak pernah memindahkan
## kamera (GDD 30.7).

signal active_floor_changed(floor_id: StringName)

var camera: Camera3D = null
var active_floor: StringName = &"floor_1"
## true selama Decoration Mode: pan bebas tanpa kembali otomatis ke tengah.
var free_pan: bool = false
## Seberapa jauh fokus boleh keluar dari tepi lantai saat pan bebas (meter).
const FREE_PAN_MARGIN_M: float = 2.0
var floor_size_m: Vector2 = Vector2(3.0, 6.0)
var ortho_size: float = 6.6
var pan_offset: Vector3 = Vector3.ZERO
var follow_target: Vector3 = Vector3.ZERO
var _focus: Vector3 = Vector3.ZERO
var _fade: ColorRect = null
var _fade_layer: CanvasLayer = null
var _pan_idle: float = 0.0
var _nudge: Vector3 = Vector3.ZERO
var _nudge_left: float = 0.0


func _ready() -> void:
	name = "CameraRig"
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.near = 0.05
	camera.far = 200.0
	add_child(camera)
	camera.current = true
	ortho_size = DataRegistry.balf("camera.default_ortho_size")
	camera.size = ortho_size
	_fade_layer = CanvasLayer.new()
	_fade_layer.layer = 5
	add_child(_fade_layer)
	_fade = ColorRect.new()
	_fade.color = Color(Palette.BG, 0.0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade_layer.add_child(_fade)


func set_floor_bounds(size_m: Vector2) -> void:
	floor_size_m = size_m


## Dipanggil WorldView tiap frame dengan posisi pemain.
func follow(target: Vector3, delta: float) -> void:
	follow_target = target
	_pan_idle += delta
	if _pan_idle > 2.5:
		pan_offset = pan_offset.lerp(Vector3.ZERO, minf(1.0, delta * 1.5))
	# Lantai yang muat di viewport dibingkai utuh dari center_anchor-nya; hanya
	# lantai yang lebih besar mengikuti pemain dan boleh di-pan (GDD 30.1, 30.6).
	var want: Vector3 = target + pan_offset
	if free_pan:
		# Decoration Mode: tampilan bebas digeser, tidak kembali otomatis.
		want = Vector3(floor_size_m.x * 0.5, 0.0, floor_size_m.y * 0.5) + pan_offset
		_pan_idle = 0.0
	elif not _floor_exceeds_view():
		want = Vector3(floor_size_m.x * 0.5, 0.0, floor_size_m.y * 0.5)
	if _nudge_left > 0.0:
		_nudge_left -= delta
		want = want.lerp(_nudge, 0.6)
	var margin: float = FREE_PAN_MARGIN_M if free_pan else 0.0
	want.x = clampf(want.x, -margin, floor_size_m.x + margin)
	want.z = clampf(want.z, -margin, floor_size_m.y + margin)
	_focus = _focus.lerp(want, minf(1.0, delta * 6.0)) if _focus != Vector3.ZERO else want
	_apply()


## Decoration Mode (GDD 72): pan bebas walau lantai muat di layar. `inset_left_px`
## menggeser tampilan awal supaya lantai tidak tertutup panel di kiri layar.
func set_free_pan(on: bool, inset_left_px: float = 0.0) -> void:
	free_pan = on
	pan_offset = Vector3.ZERO
	if on and inset_left_px > 0.0:
		var vp: Vector2 = get_viewport().get_visible_rect().size
		var m_per_px: float = ortho_size / maxf(vp.y, 1.0)
		var right: Vector3 = camera.global_transform.basis.x
		right.y = 0.0
		pan_offset = -right.normalized() * (inset_left_px * 0.5 * m_per_px)


## Pan bebas (Decoration Mode): arahkan tampilan ke titik dunia `p`.
func focus_free_pan(p: Vector3) -> void:
	if not free_pan:
		return
	var off := Vector3(p.x - floor_size_m.x * 0.5, 0.0, p.z - floor_size_m.y * 0.5)
	pan_offset = off.limit_length(maxf(floor_size_m.x, floor_size_m.y))
	_pan_idle = 0.0


func snap_to(target: Vector3) -> void:
	_focus = target
	pan_offset = Vector3.ZERO
	_apply()


func _apply() -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var dist: float = 30.0
	var offset := Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)) * dist
	camera.global_position = _focus + offset
	camera.look_at(_focus, Vector3.UP)
	camera.size = ortho_size


## Pan dengan drag (hanya bila lantai lebih besar dari viewport, GDD 30.1).
func pan_by_screen(delta_px: Vector2) -> void:
	if not free_pan and not _floor_exceeds_view():
		return
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var m_per_px: float = ortho_size / maxf(vp.y, 1.0)
	var right: Vector3 = camera.global_transform.basis.x
	var fwd: Vector3 = Vector3(camera.global_transform.basis.z.x, 0.0, camera.global_transform.basis.z.z).normalized()
	pan_offset += (-right * delta_px.x + fwd * -delta_px.y) * m_per_px
	pan_offset.y = 0.0
	var lim: float = maxf(floor_size_m.x, floor_size_m.y)
	pan_offset = pan_offset.limit_length(lim)
	_pan_idle = 0.0


func _floor_exceeds_view() -> bool:
	var diag: float = (floor_size_m.x + floor_size_m.y) * 0.7071
	var vp: Vector2 = get_viewport().get_visible_rect().size
	var view_w: float = ortho_size * vp.x / maxf(vp.y, 1.0)
	return diag > view_w * 0.8 or floor_size_m.length() > ortho_size * 1.2


func zoom(step: float) -> void:
	ortho_size = clampf(ortho_size + step, DataRegistry.balf("camera.min_ortho_size"), DataRegistry.balf("camera.max_ortho_size"))
	camera.size = ortho_size


## Titik tanah (y = 0) di bawah posisi layar.
func screen_to_ground(screen_pos: Vector2) -> Vector3:
	var from: Vector3 = camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera.project_ray_normal(screen_pos)
	if absf(dir.y) < 0.0001:
		return Vector3(INF, 0.0, INF)
	var t: float = -from.y / dir.y
	return from + dir * t


func world_to_screen(p: Vector3) -> Vector2:
	return camera.unproject_position(p)


## Pindah lantai: crossfade visual 0,20 s nyata (GDD 30.2); simulasi tidak menunggu.
func change_floor(floor_id: StringName, focus: Vector3) -> void:
	if floor_id == active_floor:
		return
	active_floor = floor_id
	var dur: float = DataRegistry.balf("camera.crossfade_seconds")
	var tw := create_tween()
	_fade.color = Color(Palette.BG, 0.0)
	tw.tween_property(_fade, "color:a", 1.0, dur * 0.5)
	tw.tween_callback(func() -> void:
		snap_to(focus)
		active_floor_changed.emit(floor_id))
	tw.tween_property(_fade, "color:a", 0.0, dur * 0.5)


## Sorotan lembut sementara (cutscene, upgrade reveal, VIP; GDD 30.7).
func soft_focus(p: Vector3, seconds: float) -> void:
	if SettingsManager.reduced_motion():
		return
	_nudge = p
	_nudge_left = seconds
