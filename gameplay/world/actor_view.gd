class_name ActorView
extends Node3D
## Tampilan satu aktor logis (GDD 16, 20.8, 31). Node ini hanya MENGIKUTI
## SimActor: posisi, arah, barang bawaan, patience bar, dan balon "!". Aktor
## pelanggan/driver/kurir berasal dari pool dan wajib bersih lewat
## `reset_for_pool()` sebelum dipakai ulang (GDD 91.2, 115.2).

const PATIENCE_Y: float = 1.08
const BUBBLE_Y: float = 1.30
const TURN_SPEED: float = 10.0

var actor_id: StringName = &""
var model: Node3D = null
var spec_key: String = ""
var _t: float = 0.0
var _carry: Node3D = null
var _carry_key: String = ""
var _patience: PatienceBar = null
var _bubble: StationMarker = null
var _thought: Label3D = null
var _sparkle_cd: float = 0.0


func _init() -> void:
	name = "Actor"


## Rakit ulang model hanya bila spesifikasinya berubah.
func bind(id: StringName, key: String, spec: Dictionary) -> void:
	actor_id = id
	if key == spec_key and model != null:
		return
	spec_key = key
	if model != null and is_instance_valid(model):
		model.queue_free()
	model = CharacterFactory.build(spec)
	add_child(model)


func reset_for_pool() -> void:
	actor_id = &""
	visible = false
	_set_carry("")
	if _patience != null:
		_patience.visible = false
	if _bubble != null:
		_bubble.hide_marker()
	if _thought != null:
		_thought.visible = false
	_t = 0.0


## Sinkron dengan state logis (dipanggil tiap frame oleh WorldView).
func sync(a: SimActor, delta: float, animate: bool) -> void:
	_t += delta
	var target := Vector3(a.pos.x, 0.0, a.pos.y)
	global_position = target if global_position.distance_to(target) > 1.5 else global_position.lerp(target, minf(1.0, delta * 18.0))
	if a.facing.length_squared() > 0.0001:
		# Wajah karakter menghadap -Z (CharacterFactory.FRONT).
		var want: float = atan2(-a.facing.x, -a.facing.y)
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, TURN_SPEED * delta))
	if model == null or not animate:
		return
	if a.moving:
		ProceduralAnimationSystem.walk(model, _t, a.speed_mps * 4.5)
	else:
		ProceduralAnimationSystem.idle_bob(model, _t)


## Barang bawaan terlihat di depan torso (GDD 4.2, 31.2): "dough", "tray",
## "bag", "package", atau "" (kosong).
func set_carry(kind: String, recipe_profile: String = "", quality: float = 1.0) -> void:
	var key: String = "%s|%s" % [kind, recipe_profile]
	if key == _carry_key:
		return
	_carry_key = key
	_set_carry(kind, recipe_profile, quality)


func _set_carry(kind: String, recipe_profile: String = "", quality: float = 1.0) -> void:
	if _carry != null and is_instance_valid(_carry):
		_carry.queue_free()
	_carry = null
	if kind == "":
		_carry_key = "|"
		return
	_carry = Node3D.new()
	_carry.name = "Carry"
	add_child(_carry)
	_carry.position = Vector3(0.0, 0.40, -0.22)
	match kind:
		"dough":
			var bowl := ProceduralMeshFactory.cylinder(0.09, 0.13, 0.09, Palette.PINE_WOOD)
			_carry.add_child(bowl)
			var dough := ProceduralMeshFactory.sphere(0.10, Palette.RAW_DOUGH)
			dough.scale = Vector3(1.0, 0.55, 1.0)
			dough.position = Vector3(0.0, 0.05, 0.0)
			_carry.add_child(dough)
		"tray":
			var tray := ProceduralMeshFactory.box(Vector3(0.34, 0.025, 0.24), EquipmentFactory.METAL_STEEL)
			_carry.add_child(tray)
			for i in 3:
				var b: Node3D = BreadFactory.build_cached(recipe_profile, quality, &"FRESH")
				b.scale = Vector3(0.55, 0.55, 0.55)
				b.position = Vector3(-0.10 + 0.10 * float(i), 0.015, 0.0)
				_carry.add_child(b)
		"bag":
			var bag: Node3D = BreadFactory.build_paper_bag()
			bag.scale = Vector3(0.8, 0.8, 0.8)
			_carry.add_child(bag)
			_carry.position = Vector3(0.14, 0.18, -0.10)
		"package":
			var box := ProceduralMeshFactory.box(Vector3(0.22, 0.16, 0.16), Color(0.749, 0.580, 0.380))
			_carry.add_child(box)


## Patience bar di atas kepala (GDD 20.8, 58): tanpa angka, berkedip makin cepat.
func set_patience(ratio: float, show: bool, large: bool) -> void:
	if not show:
		if _patience != null:
			_patience.visible = false
		return
	if _patience == null:
		_patience = PatienceBar.new()
		add_child(_patience)
		_patience.position = Vector3(0.0, PATIENCE_Y, 0.0)
	_patience.visible = true
	_patience.set_ratio(ratio, large)


## Balon "!" di atas pembeli terdepan yang menunggu diketuk (GDD 2 langkah 4).
func set_alert(on: bool) -> void:
	if not on:
		if _bubble != null:
			_bubble.hide_marker()
		return
	if _bubble == null:
		_bubble = StationMarker.new()
		add_child(_bubble)
		_bubble.position = Vector3(0.0, BUBBLE_Y, 0.0)
	_bubble.show_alert()


## Balon pikiran (GDD 7): jam pasir saat antre lama, koin saat harga mahal.
func set_thought(text: String) -> void:
	if text == "":
		if _thought != null:
			_thought.visible = false
		return
	if _thought == null:
		_thought = Label3D.new()
		_thought.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_thought.no_depth_test = true
		_thought.font_size = 56
		_thought.pixel_size = 0.004
		_thought.outline_size = 10
		_thought.outline_modulate = Palette.FLOUR_WHITE
		_thought.modulate = Palette.TEXT
		add_child(_thought)
		_thought.position = Vector3(0.22, 1.02, 0.0)
	_thought.visible = true
	_thought.text = text


func react_happy() -> void:
	if model != null:
		CharacterFactory.set_expression(model, "senang")
		if not SettingsManager.reduced_motion():
			ProceduralAnimationSystem.happy_jump(model)


func react_sad() -> void:
	if model != null:
		CharacterFactory.set_expression(model, "sedih")
		if not SettingsManager.reduced_motion():
			ProceduralAnimationSystem.sad_shake(model)


## Bintang semangat Mode Solo di atas karakter pemain (GDD 3.0.C).
func sparkle() -> void:
	if SettingsManager.reduced_motion():
		return
	FX.sugar_sparkle(self, Vector3(0.0, 1.0, 0.0))


## Widget bar patience berbasis mesh unshaded, diputar menghadap kamera.
class PatienceBar extends Node3D:
	const W: float = 0.40
	const H: float = 0.055
	var _fill: MeshInstance3D = null
	var _mat: StandardMaterial3D = null
	var _ratio: float = 1.0
	var _t: float = 0.0
	var _large: bool = false

	func _ready() -> void:
		var bg := _quad(Vector2(W + 0.03, H + 0.03), Palette.DARK_CHOCOLATE)
		add_child(bg)
		_fill = _quad(Vector2(W, H), Palette.SUCCESS)
		_fill.position = Vector3(0.0, 0.0, 0.004)
		_mat = _fill.material_override as StandardMaterial3D
		add_child(_fill)

	func set_ratio(r: float, large: bool) -> void:
		_ratio = clampf(r, 0.0, 1.0)
		_large = large

	func _process(delta: float) -> void:
		if not visible or _fill == null:
			return
		_t += delta
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			var tr: Transform3D = global_transform
			tr.basis = cam.global_transform.basis
			global_transform = tr
		var s: float = 1.45 if _large else 1.0
		scale = Vector3(s, s, s)
		_fill.scale = Vector3(maxf(_ratio, 0.001), 1.0, 1.0)
		_fill.position.x = -W * 0.5 + W * _ratio * 0.5
		# >60% tenang, 30-60% waspada, 10-30% kedip pelan, <10% kedip cepat (GDD 58).
		var c: Color = Palette.SUCCESS
		var blink_hz: float = 0.0
		if _ratio <= 0.6:
			c = Palette.WARNING
		if _ratio <= 0.3:
			c = Palette.WARMER_LAMP
			blink_hz = 1.2
		if _ratio <= 0.1:
			c = Palette.DANGER
			blink_hz = 4.0
		var a: float = 1.0
		if blink_hz > 0.0 and not SettingsManager.reduced_motion():
			a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * TAU * blink_hz))
		_mat.albedo_color = Color(c, a)
		_mat.emission = c

	func _quad(size: Vector2, color: Color) -> MeshInstance3D:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x, size.y, 0.006)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.4
		mat.no_depth_test = true
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi
