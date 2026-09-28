class_name ActorView
extends Node3D
## Tampilan satu aktor logis (GDD 16, 20.8, 31). Node ini hanya MENGIKUTI
## SimActor: posisi, arah, barang bawaan, patience bar, dan balon "!". Aktor
## pelanggan/driver/kurir berasal dari pool dan wajib bersih lewat
## `reset_for_pool()` sebelum dipakai ulang (GDD 91.2, 115.2).
##
## Pemain & staf juga punya gerak menganggur murni visual (GDD 31.6): setelah
## `idle_wipe_after_seconds` detik NYATA tanpa aktivitas mereka mengelap wajah
## dengan kain lap, setelah `idle_doze_after_seconds` mulai terkantuk-kantuk.
## Timer tidak berjalan saat game di-pause dan tidak pernah memengaruhi simulasi.

const PATIENCE_Y: float = 1.08
const BUBBLE_Y: float = 1.30
const TURN_SPEED: float = 10.0

const GESTURE_NONE: int = 0
const GESTURE_WIPE: int = 1
const GESTURE_DOZE: int = 2
## Huruf "Z" kantuk: jarak antar-kemunculan, umur, jumlah maksimum sekaligus.
const Z_EVERY: float = 1.5
const Z_LIFE: float = 2.0
const Z_MAX: int = 3
## Titik lahir huruf "Z": sedikit ke samping, tepat di atas puncak kepala/topi.
const Z_SIDE: float = 0.12
const Z_GAP: float = 0.02
## Skala puncak huruf "Z" agar terbaca pada zoom gameplay.
const Z_SCALE: float = 1.6

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
## Gerak menganggur hanya untuk pemain & staf (diaktifkan WorldView).
var _idle_enabled: bool = false
var _busy: bool = true
var _action: StringName = &""
var _idle_real: float = 0.0
var _gesture: int = GESTURE_NONE
var _cloth: Node3D = null
var _zs: Array[Node3D] = []
var _z_timer: float = 0.0


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
	_clear_idle_fx()
	model = CharacterFactory.build(spec)
	add_child(model)
	_apply_carry_pose()


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
	_idle_enabled = false
	_busy = true
	_action = &""
	_clear_idle_fx()


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
	_update_idle(a, delta)
	if _action == &"pack" and not a.moving:
		ProceduralAnimationSystem.pack(model, _t)
	elif a.moving:
		ProceduralAnimationSystem.walk(model, _t, a.speed_mps * 4.5)
	else:
		ProceduralAnimationSystem.idle_bob(model, _t)
		match _gesture:
			GESTURE_WIPE:
				ProceduralAnimationSystem.wipe_face(model, _wipe_progress(), _t)
			GESTURE_DOZE:
				ProceduralAnimationSystem.doze(model, _t)
	_update_zs(delta)


# ===========================================================================
# GERAK MENGANGGUR (GDD 31.6) & AKSI
# ===========================================================================

## Aktifkan gerak menganggur (pemain & staf). Pelanggan tidak pernah memakainya.
func set_idle_enabled(on: bool) -> void:
	_idle_enabled = on


## Apakah aktor sedang mengerjakan sesuatu (dihitung WorldView dari state sim).
func set_busy(busy: bool) -> void:
	_busy = busy


## Aksi tangan khusus: &"pack" (membungkus di meja kasir) atau &"" (tidak ada).
func set_action(action: StringName) -> void:
	if action == _action:
		return
	var was_pack: bool = _action == &"pack"
	_action = action
	if was_pack and model != null:
		ProceduralAnimationSystem.end_pose(model)
		_apply_carry_pose()


func gesture() -> int:
	return _gesture


## Tinggi puncak kepala/topi model di ruang ActorView (m), dari meta "aabb"
## HeadMesh; dipakai huruf "Z" dan gelembung pikiran.
func head_top() -> float:
	if model == null or not is_instance_valid(model):
		return 0.95
	var head: Node3D = CharacterFactory.part(model, "Head")
	var hm: Node = head.get_node_or_null("HeadMesh") if head != null else null
	if hm == null or not hm.has_meta("aabb"):
		return 0.95
	var box: AABB = hm.get_meta("aabb")
	return (head.position.y + box.end.y) * model.scale.y


func idle_seconds() -> float:
	return _idle_real


## Gerak menganggur untuk lama menganggur `idle_seconds` (detik nyata, GDD 31.6).
static func gesture_for(idle_seconds_value: float) -> int:
	var wipe_at: float = DataRegistry.balf("presentation.idle_wipe_after_seconds")
	if idle_seconds_value >= DataRegistry.balf("presentation.idle_doze_after_seconds"):
		return GESTURE_DOZE
	if idle_seconds_value >= wipe_at and idle_seconds_value < wipe_at + DataRegistry.balf("presentation.wipe_gesture_seconds"):
		return GESTURE_WIPE
	return GESTURE_NONE


func _update_idle(a: SimActor, delta: float) -> void:
	if not _idle_enabled:
		return
	if a.moving or _busy or _action != &"":
		_idle_real = 0.0
	elif not PauseManager.is_paused():
		_idle_real += delta
	_set_gesture(gesture_for(_idle_real))


func _wipe_progress() -> float:
	var wipe_at: float = DataRegistry.balf("presentation.idle_wipe_after_seconds")
	return clampf((_idle_real - wipe_at) / DataRegistry.balf("presentation.wipe_gesture_seconds"), 0.0, 1.0)


func _set_gesture(g: int) -> void:
	if g == _gesture:
		return
	var had: int = _gesture
	_gesture = g
	if model == null:
		return
	if had != GESTURE_NONE:
		ProceduralAnimationSystem.end_pose(model)
	_show_cloth(g == GESTURE_WIPE)
	match g:
		GESTURE_WIPE:
			CharacterFactory.set_expression(model, "lega")
		GESTURE_DOZE:
			CharacterFactory.set_expression(model, "ngantuk")
			_z_timer = 0.3
		_:
			CharacterFactory.set_expression(model, _base_mood())


func _base_mood() -> String:
	if model != null and model.has_meta("spec"):
		return str((model.get_meta("spec") as Dictionary).get("mood", "netral"))
	return "netral"


func _show_cloth(on: bool) -> void:
	if on and (_cloth == null or not is_instance_valid(_cloth)):
		var arm: Node3D = CharacterFactory.part(model, "ArmR")
		if arm == null:
			return
		_cloth = CharacterFactory.wipe_cloth()
		arm.add_child(_cloth)
	if _cloth != null and is_instance_valid(_cloth):
		_cloth.visible = on


## Huruf "Z" melayang naik dari atas kepala selama terkantuk-kantuk.
func _update_zs(delta: float) -> void:
	if _gesture == GESTURE_DOZE and visible and not PauseManager.is_paused():
		_z_timer -= delta
		if _z_timer <= 0.0 and _zs.size() < Z_MAX:
			_z_timer = Z_EVERY
			var z: MeshInstance3D = CharacterFactory.sleep_z()
			z.set_meta("age", 0.0)
			z.set_meta("origin", Vector3(Z_SIDE, head_top() + Z_GAP, 0.0))
			add_child(z)
			z.position = z.get_meta("origin")
			z.scale = Vector3.ONE * 0.001
			_zs.append(z)
	for i in range(_zs.size() - 1, -1, -1):
		var zn: Node3D = _zs[i]
		var age: float = float(zn.get_meta("age")) + (0.0 if PauseManager.is_paused() else delta)
		zn.set_meta("age", age)
		var k: float = age / Z_LIFE
		if k >= 1.0 or _gesture != GESTURE_DOZE:
			zn.queue_free()
			_zs.remove_at(i)
			continue
		var origin: Vector3 = zn.get_meta("origin")
		zn.position = origin + Vector3(0.10 * k + 0.02 * sin(k * 6.0), 0.30 * k, 0.0)
		zn.scale = Vector3.ONE * maxf(sin(PI * k) * (0.7 + 0.5 * k) * Z_SCALE, 0.001)


func _clear_idle_fx() -> void:
	for z: Node3D in _zs:
		if is_instance_valid(z):
			z.queue_free()
	_zs.clear()
	_cloth = null
	_gesture = GESTURE_NONE
	_idle_real = 0.0


## Barang bawaan terlihat di depan torso (GDD 4.2, 31.2): "dough", "tray",
## "bag", "package", "bread" (roti lepas di tangan pembeli), atau "" (kosong).
func set_carry(kind: String, recipe_profile: String = "", quality: float = 1.0, count: int = 1) -> void:
	var key: String = _carry_key_for(kind, recipe_profile, count)
	if key == _carry_key:
		return
	_carry_key = key
	_set_carry(kind, recipe_profile, quality, count)


## Kunci barang bawaan: set_carry() yang sama berturut-turut tidak berbuat apa-apa,
## jadi pose lengan tidak direset tiap frame.
static func _carry_key_for(kind: String, recipe_profile: String, count: int) -> String:
	return "%s|%s|%d" % [kind, recipe_profile, count]


func _set_carry(kind: String, recipe_profile: String = "", quality: float = 1.0, count: int = 1) -> void:
	if _carry != null and is_instance_valid(_carry):
		_carry.queue_free()
	_carry = null
	if kind == "":
		_carry_key = _carry_key_for("", "", 1)
		_apply_carry_pose()
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
			_carry.position = Vector3(0.14 * _bag_side(), 0.18, -0.10)
		"package":
			var box := ProceduralMeshFactory.box(Vector3(0.22, 0.16, 0.16), Color(0.749, 0.580, 0.380))
			_carry.add_child(box)
		"bread":
			# Roti yang diambil sendiri dari rak, ditenteng ke kasir (GDD 2 langkah 3).
			var n: int = clampi(count, 1, 3)
			for i2 in n:
				var br: Node3D = BreadFactory.build_cached(recipe_profile, quality, &"FRESH")
				br.scale = Vector3(0.6, 0.6, 0.6)
				br.position = Vector3(-0.06 * float(n - 1) + 0.12 * float(i2), 0.012 * float(i2 % 2), 0.0)
				_carry.add_child(br)
			_carry.position = Vector3(0.0, 0.36, -0.20)
	_apply_carry_pose()


## Kantong kertas dijinjing di tangan kanan, kecuali tangan itu sudah memegang
## tas belanja atau koper bawaan karakter (+1 kanan, -1 kiri).
func _bag_side() -> float:
	if model != null and model.has_meta("spec"):
		var props: PackedStringArray = (model.get_meta("spec") as Dictionary).get("prop", PackedStringArray())
		if props.has("tas_belanja") or props.has("koper"):
			return -1.0
	return 1.0


## Kedua lengan memeluk barang yang dibawa di depan badan; tas kertas dijinjing
## di samping sehingga lengan tetap bebas.
func _apply_carry_pose() -> void:
	if model == null or not is_instance_valid(model):
		return
	var kind: String = _carry_key.get_slice("|", 0)
	ProceduralAnimationSystem.set_carry_pose(model, kind in ["dough", "tray", "package", "bread"])


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
