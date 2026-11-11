class_name ItemStage
extends SubViewportContainer
## Panggung 3D kecil untuk perayaan barang baru di Store (GDD idle 22.11): model
## asli barangnya (dekorasi, pemilik yang memakai pakaian baru, atau pintu masuk
## dengan kanopi baru) berputar pelan di bawah cahaya golden hour, di SubViewport
## sendiri berlatar tembus pandang. Memakai lingkungan, cahaya, dan material yang
## sama dengan dunia (EquipmentFactory.build_environment, material MeshBuilder),
## jadi tidak ada kombinasi shader baru (ACC_89_FEW_SHADERS).
##
## Dekorasi lantai, karpet, dan pakaian berputar penuh; barang dinding dan papan
## nama hanya mengayun, karena bagian belakangnya menempel ke dinding.

## Detik per putaran penuh dan sudut ayunan (derajat).
const SPIN_SECONDS: float = 9.0
const SWING_DEGREES: float = 32.0

var _vp: SubViewport = null
var _pivot: Node3D = null
var _swing: bool = false
var _t: float = 0.0
## Tinggi napas naik-turun (sebanding ukuran model).
var _bob: float = 0.0
## false = diam (Reduce motion).
var motion: bool = true


## Panggung untuk dekorasi `def` (null bila barang itu tidak punya model).
static func for_item(def: MiscDefinitions.DecorationDefinition, sim: SimulationRoot, px: int) -> ItemStage:
	var model: Node3D = model_for(def, sim)
	if model == null:
		return null
	var st := ItemStage.new()
	st.setup(model, px, def.placement_type, def.placement_type == &"wall" or def.placement_type == &"skin")
	return st


## Model barang: pemilik berpakaian baru, pintu masuk berkanopi, atau dekorasinya.
static func model_for(def: MiscDefinitions.DecorationDefinition, sim: SimulationRoot) -> Node3D:
	if def == null:
		return null
	match def.placement_type:
		&"outfit":
			var gender: String = str(sim.player.appearance.get("gender", "male")) if sim != null else "female"
			return CharacterFactory.build(WorldView.owner_spec(gender, String(def.id)))
		&"skin":
			if def.skin_target in [&"storefront", &"storefront_sign", &"door"]:
				var name_text: String = sim.bakery_name if sim != null else "Crumbtown Bakery"
				var skins: Dictionary = sim.decoration.equipped.duplicate() if sim != null else {}
				skins[String(def.skin_target)] = String(def.id)
				var tier: int = sim.world.location.tier if sim != null and sim.world.location != null else 1
				return RoomFactory.sign_preview(name_text, skins, tier)
			return null
	if def.is_placeable() and DecorFactory.has_model(def.visual_profile_id):
		return DecorFactory.build(def.id)
	return null


func setup(model: Node3D, px: int, placement: StringName, swing: bool) -> void:
	_swing = swing
	stretch = true
	custom_minimum_size = Vector2(px, px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.name = "Stage"
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.size = Vector2i(px, px)
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	var we: WorldEnvironment = EquipmentFactory.build_environment()
	we.environment.background_mode = Environment.BG_CLEAR_COLOR
	_vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.light_color = Palette.GOLDEN_HOUR
	sun.light_energy = 1.05
	sun.shadow_enabled = false
	sun.rotation_degrees = Vector3(-48.0, -150.0, 0.0)
	_vp.add_child(sun)
	# Model berputar mengelilingi pusat kotaknya sendiri.
	var box: AABB = EquipmentFactory._mesh_bounds(model)
	_pivot = Node3D.new()
	_pivot.name = "Pivot"
	_vp.add_child(_pivot)
	_pivot.add_child(model)
	model.position = -box.get_center()
	var cam := Camera3D.new()
	cam.name = "Camera"
	cam.fov = 30.0
	_vp.add_child(cam)
	# Karpet dilihat lebih dari atas supaya polanya terbaca; barang dinding dari depan.
	var pitch: float = deg_to_rad(55.0 if placement == &"floor_overlay" else (12.0 if swing else 20.0))
	# Yang berputar penuh butuh bola pembatasnya; yang hanya mengayun cukup
	# lebar dan tingginya, jadi bisa dibingkai lebih rapat.
	var radius: float = maxf((maxf(box.size.x, box.size.y) * 0.56) if swing else box.size.length() * 0.5, 0.05)
	var dist: float = radius / sin(deg_to_rad(cam.fov * 0.5)) * 1.08
	_bob = radius * 0.035
	# Kamera diarahkan lewat basisnya sendiri: panggung belum masuk pohon scene.
	var eye: Vector3 = Vector3(0.0, sin(pitch), -cos(pitch)) * dist
	cam.transform = Transform3D(Basis.looking_at(-eye, Vector3.UP), eye)
	_apply(0.0)


func _process(delta: float) -> void:
	if not motion or _pivot == null:
		return
	_t += delta
	_apply(_t)


func _apply(t: float) -> void:
	if _pivot == null:
		return
	if _swing:
		_pivot.rotation.y = deg_to_rad(SWING_DEGREES) * sin(t * TAU / SPIN_SECONDS * 1.5)
	else:
		_pivot.rotation.y = t * TAU / SPIN_SECONDS
	# Napas kecil naik-turun supaya barangnya terasa "hidup".
	_pivot.position.y = _bob * sin(t * 2.2)


## Tes: viewport panggung.
func viewport() -> SubViewport:
	return _vp
