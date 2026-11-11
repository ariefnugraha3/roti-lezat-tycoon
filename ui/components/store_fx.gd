class_name StoreFX
extends RefCounted
## Efek 2D perayaan Store (GDD idle 22.11): confetti, ledakan kilau, dan kelip
## yang berputar di sekitar barang baru. Semuanya CPUParticles2D dengan tekstur
## gradien yang dibuat sekali (tanpa aset, GDD 4, 111), flat, dan berhenti
## sendiri. Pemanggil memeriksa Reduce motion sebelum memanggilnya.

const CONFETTI_COLORS: Array[Color] = [Palette.STRAWBERRY, Palette.HONEY, Palette.MATCHA, Palette.SIGN_BLUE, Palette.SIGN_PURPLE,
	Palette.GOLD_STAR]

static var _tex_confetti: GradientTexture2D = null
static var _tex_glint: GradientTexture2D = null


## Confetti pita kecil yang meledak ke atas dari `pos` lalu jatuh sambil
## berkibar (lebar menyempit-melebar seperti kertas yang berputar).
static func confetti(parent: CanvasItem, pos: Vector2, amount: int = 70, power: float = 1.0) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var p := CPUParticles2D.new()
	p.name = "ConfettiFX"
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 2.2
	p.lifetime_randomness = 0.3
	p.explosiveness = 0.95
	p.randomness = 0.5
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 24.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 70.0
	p.initial_velocity_min = 420.0 * power
	p.initial_velocity_max = 720.0 * power
	p.gravity = Vector2(0.0, 900.0)
	p.damping_min = 40.0
	p.damping_max = 90.0
	p.angular_velocity_min = -420.0
	p.angular_velocity_max = 420.0
	p.angle_min = 0.0
	p.angle_max = 360.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.3
	p.split_scale = true
	p.scale_curve_x = FX._curve(PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(0.15, 0.2), Vector2(0.3, 1.0), Vector2(0.45, 0.2), Vector2(0.6, 1.0),
		Vector2(0.75, 0.2), Vector2(0.9, 1.0), Vector2(1.0, 0.5),
	]))
	p.scale_curve_y = FX._curve(PackedVector2Array([Vector2(0.0, 1.0), Vector2(1.0, 1.0)]))
	var ramp := Gradient.new()
	ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in CONFETTI_COLORS.size():
		offs.append(float(i) / float(CONFETTI_COLORS.size()))
		cols.append(CONFETTI_COLORS[i])
	ramp.offsets = offs
	ramp.colors = cols
	p.color_initial_ramp = ramp
	p.color_ramp = FX._gradient(PackedFloat32Array([0.0, 0.8, 1.0]), PackedColorArray([Color.WHITE, Color.WHITE, Color(1, 1, 1, 0)]))
	p.texture = confetti_texture()
	parent.add_child(p)
	p.position = pos
	p.emitting = true
	FX._auto_free(p, 2.2 * 1.3 + 0.5)
	return p


## Kilau bundar yang memancar ke segala arah dari `pos` lalu memudar.
static func sparkle_burst(parent: CanvasItem, pos: Vector2, amount: int = 26, radius: float = 260.0, tint: Color = Palette.GOLD_STAR) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return null
	var p := CPUParticles2D.new()
	p.name = "SparkleFX"
	p.emitting = false
	p.one_shot = true
	p.amount = amount
	p.lifetime = 0.9
	p.explosiveness = 1.0
	p.randomness = 0.4
	p.local_coords = true
	p.direction = Vector2(0.0, -1.0)
	p.spread = 180.0
	p.initial_velocity_min = radius * 0.9
	p.initial_velocity_max = radius * 1.6
	p.damping_min = radius * 1.2
	p.damping_max = radius * 1.8
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	p.scale_amount_curve = FX._curve(PackedVector2Array([Vector2(0.0, 0.2), Vector2(0.2, 1.0), Vector2(1.0, 0.0)]))
	p.color = tint.lightened(0.35)
	p.texture = glint_texture()
	parent.add_child(p)
	p.position = pos
	p.emitting = true
	FX._auto_free(p, 1.4)
	return p


## Kelip yang terus muncul dan hilang di cincin sekitar `pos` (berhenti saat
## node induknya dibebaskan).
static func twinkles(parent: CanvasItem, pos: Vector2, ring: float) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent):
		return null
	var p := CPUParticles2D.new()
	p.name = "TwinkleFX"
	p.amount = 12
	p.lifetime = 1.4
	p.randomness = 0.6
	p.local_coords = true
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = ring
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 0.0
	p.initial_velocity_max = 8.0
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.0
	p.scale_amount_curve = FX._curve(PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.5, 1.0), Vector2(1.0, 0.0)]))
	p.color = Palette.FLOUR_WHITE
	p.texture = glint_texture()
	parent.add_child(p)
	p.position = pos
	p.emitting = true
	return p


## Pita confetti 8 x 14 px, putih (diwarnai warna partikelnya).
static func confetti_texture() -> GradientTexture2D:
	if _tex_confetti != null:
		return _tex_confetti
	var t := GradientTexture2D.new()
	t.width = 8
	t.height = 14
	t.fill = GradientTexture2D.FILL_LINEAR
	t.gradient = FX._gradient(PackedFloat32Array([0.0, 1.0]), PackedColorArray([Color.WHITE, Color(0.92, 0.92, 0.92)]))
	_tex_confetti = t
	return t


## Titik cahaya bundar lembut 28 px.
static func glint_texture() -> GradientTexture2D:
	if _tex_glint != null:
		return _tex_glint
	var t := GradientTexture2D.new()
	t.width = 28
	t.height = 28
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.gradient = FX._gradient(PackedFloat32Array([0.0, 0.25, 0.6, 1.0]),
		PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.95), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0)]))
	_tex_glint = t
	return t


static func clear_caches() -> void:
	_tex_confetti = null
	_tex_glint = null
