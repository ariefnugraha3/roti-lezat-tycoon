class_name FX
extends RefCounted

## Efek partikel "Visual Juice" (GDD 4.3, ARCHITECTURE 8).
##
## Seluruh efek memakai **CPUParticles3D / CPUParticles2D saja**. GPUParticles
## sengaja dihindari: renderer proyek ini adalah Compatibility (OpenGL ES 3.0 /
## WebGL 2.0, GDD 12.2) dan particle shader GPU tidak dapat diandalkan di sana
## maupun di Android kelas bawah.
##
## Tidak ada satu pun berkas gambar dipakai. Partikel 3D memakai mesh primitif
## beranggaran rendah (SphereMesh 8x3, BoxMesh) dan partikel 2D memakai
## `GradientTexture2D` yang dibangkitkan runtime dari `Gradient` — generator
## gradient bawaan Godot yang memang direstui GDD 4.3.
##
## Jumlah partikel dijaga di rentang 8-24 demi anggaran ponsel.
##
## ATURAN KEPEMILIKAN NODE:
## - Fungsi yang **mengembalikan** emitter (`steam`, `rain_overlay`) bersifat
##   menerus (`one_shot = false`). Pemanggil yang memilikinya dan wajib
##   memanggil `queue_free()` saat efek tidak dibutuhkan lagi.
## - Fungsi ledakan sekali jalan (`sugar_sparkle`, `burn_smoke`, `coin_pop`,
##   `sweat_drop`) memakai `one_shot = true` dan **membebaskan dirinya sendiri**
##   lewat SceneTreeTimer setelah partikel terakhir habis. Jangan menyimpan
##   referensinya tanpa `is_instance_valid()`.

# ---------------------------------------------------------------------------
# Anggaran jumlah partikel (GDD 12.2 -- target Android entry level & WebGL2)
# ---------------------------------------------------------------------------

const STEAM_AMOUNT: int = 12
const SPARKLE_AMOUNT: int = 18
const SMOKE_AMOUNT: int = 14
const COIN_AMOUNT: int = 10
const SWEAT_AMOUNT: int = 5
const RAIN_AMOUNT: int = 24

# ---------------------------------------------------------------------------
# Umur partikel (detik)
# ---------------------------------------------------------------------------

const STEAM_LIFETIME: float = 2.3
const SPARKLE_LIFETIME: float = 0.85
const SMOKE_LIFETIME: float = 2.6
const COIN_LIFETIME: float = 0.95
const SWEAT_LIFETIME: float = 0.9
const RAIN_LIFETIME: float = 1.7

## Tambahan waktu sebelum emitter sekali-jalan dibuang, supaya partikel
## terakhir benar-benar sudah selesai (umur + acak umur + jeda semburan).
const AUTO_FREE_MARGIN: float = 0.45

## Lapisan gambar overlay 2D agar berada di atas HUD dunia tapi di bawah dialog.
const RAIN_Z_INDEX: int = 60
const COIN_Z_INDEX: int = 110

# ---------------------------------------------------------------------------
# Cache sumber daya bersama
# ---------------------------------------------------------------------------

## Material dan tekstur di bawah ini isinya selalu sama, jadi dipakai ulang
## antar-emitter supaya ponsel kelas bawah tidak menyiapkan sumber daya yang
## identik berulang kali sepanjang hari bermain.
static var _mat_soft: StandardMaterial3D = null
static var _mat_glint: StandardMaterial3D = null
static var _tex_coin: GradientTexture2D = null
static var _tex_rain: GradientTexture2D = null


# ---------------------------------------------------------------------------
# Efek 3D
# ---------------------------------------------------------------------------

## Uap hangat yang mengepul pelan dari oven dan rak roti yang baru matang
## (GDD 4.1 "Baking Vapor"). Menerus: pemanggil yang membebaskan node ini.
static func steam(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	if parent == null or not is_instance_valid(parent):
		return null

	var p := CPUParticles3D.new()
	p.name = "SteamFX"
	p.emitting = false
	p.one_shot = false
	p.amount = STEAM_AMOUNT
	p.lifetime = STEAM_LIFETIME
	p.lifetime_randomness = 0.35
	p.explosiveness = 0.0
	p.randomness = 0.5
	p.local_coords = false
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.09
	p.direction = Vector3.UP
	p.spread = 14.0
	p.initial_velocity_min = 0.22
	p.initial_velocity_max = 0.45
	# Gravitasi positif kecil = daya apung uap, bukan jatuh.
	p.gravity = Vector3(0.0, 0.16, 0.0)
	p.damping_min = 0.25
	p.damping_max = 0.55
	p.scale_amount_min = 0.55
	p.scale_amount_max = 0.95
	p.scale_amount_curve = _curve(PackedVector2Array([
		Vector2(0.0, 0.30), Vector2(0.30, 1.00), Vector2(1.0, 1.35),
	]))

	# Putih gandum yang dihangatkan cahaya golden hour, timbul lalu larut.
	var warm: Color = Palette.FLOUR_WHITE.lerp(Palette.GOLDEN_HOUR, 0.45)
	p.color = Color.WHITE
	p.color_ramp = _gradient(
		PackedFloat32Array([0.0, 0.18, 0.60, 1.0]),
		PackedColorArray([
			Color(warm.r, warm.g, warm.b, 0.0),
			Color(warm.r, warm.g, warm.b, 0.42),
			Color(warm.r, warm.g, warm.b, 0.26),
			Color(warm.r, warm.g, warm.b, 0.0),
		])
	)

	p.mesh = _puff_mesh(0.075, 0.15, 8, 3, _particle_material(false))

	parent.add_child(p)
	p.position = pos
	p.emitting = true
	return p


## Serpihan gula halus berkilauan saat pesanan sukses (GDD 4.3). Ledakan sekali
## jalan; node membebaskan dirinya sendiri setelah partikel terakhir habis.
static func sugar_sparkle(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	if parent == null or not is_instance_valid(parent):
		return null

	var p := CPUParticles3D.new()
	p.name = "SugarSparkleFX"
	p.emitting = false
	p.one_shot = true
	p.amount = SPARKLE_AMOUNT
	p.lifetime = SPARKLE_LIFETIME
	p.lifetime_randomness = 0.4
	p.explosiveness = 0.9
	p.randomness = 0.6
	p.local_coords = false
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12
	p.direction = Vector3.UP
	p.spread = 68.0
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.35
	p.gravity = Vector3(0.0, -1.7, 0.0)
	p.damping_min = 0.1
	p.damping_max = 0.3
	p.scale_amount_min = 0.7
	p.scale_amount_max = 1.3
	# Kurva bergelombang = kelip-kelip butiran gula yang memantulkan cahaya.
	p.scale_amount_curve = _curve(PackedVector2Array([
		Vector2(0.0, 0.25), Vector2(0.18, 1.30), Vector2(0.42, 0.55),
		Vector2(0.66, 1.15), Vector2(1.0, 0.0),
	]))

	p.color = Color.WHITE
	p.color_ramp = _gradient(
		PackedFloat32Array([0.0, 0.25, 0.70, 1.0]),
		PackedColorArray([
			Color(Palette.FLOUR_WHITE.r, Palette.FLOUR_WHITE.g, Palette.FLOUR_WHITE.b, 1.0),
			Color(Palette.BUTTER_YELLOW.r, Palette.BUTTER_YELLOW.g, Palette.BUTTER_YELLOW.b, 1.0),
			Color(Palette.CUSTARD.r, Palette.CUSTARD.g, Palette.CUSTARD.b, 0.75),
			Color(Palette.CUSTARD.r, Palette.CUSTARD.g, Palette.CUSTARD.b, 0.0),
		])
	)

	# Butir gula = kubus mungil (12 tris) supaya kilaunya tajam dan murah.
	var grain := BoxMesh.new()
	grain.size = Vector3(0.035, 0.035, 0.035)
	grain.subdivide_width = 0
	grain.subdivide_height = 0
	grain.subdivide_depth = 0
	grain.material = _particle_material(true)
	p.mesh = grain

	parent.add_child(p)
	p.position = pos
	p.emitting = true
	_auto_free(p, SPARKLE_LIFETIME * (1.0 + 0.4) + AUTO_FREE_MARGIN)
	return p


## Asap jelaga gelap untuk roti gosong (GDD 4.3). Ledakan sekali jalan yang
## membebaskan dirinya sendiri; panggil ulang bila oven masih terus membakar.
static func burn_smoke(parent: Node3D, pos: Vector3) -> CPUParticles3D:
	if parent == null or not is_instance_valid(parent):
		return null

	var p := CPUParticles3D.new()
	p.name = "BurnSmokeFX"
	p.emitting = false
	p.one_shot = true
	p.amount = SMOKE_AMOUNT
	p.lifetime = SMOKE_LIFETIME
	p.lifetime_randomness = 0.3
	p.explosiveness = 0.35
	p.randomness = 0.55
	p.local_coords = false
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.07
	p.direction = Vector3.UP
	p.spread = 20.0
	p.initial_velocity_min = 0.35
	p.initial_velocity_max = 0.7
	p.gravity = Vector3(0.0, 0.28, 0.0)
	p.damping_min = 0.4
	p.damping_max = 0.8
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.1
	p.scale_amount_curve = _curve(PackedVector2Array([
		Vector2(0.0, 0.35), Vector2(0.35, 1.05), Vector2(1.0, 1.70),
	]))

	# Jelaga = hitam gosong yang sedikit dicerahkan agar tetap terbaca.
	var soot: Color = Palette.BURNT_BLACK.lerp(Color.WHITE, 0.32)
	p.color = Color.WHITE
	p.color_ramp = _gradient(
		PackedFloat32Array([0.0, 0.12, 0.55, 1.0]),
		PackedColorArray([
			Color(soot.r, soot.g, soot.b, 0.0),
			Color(soot.r, soot.g, soot.b, 0.72),
			Color(soot.r, soot.g, soot.b, 0.40),
			Color(soot.r, soot.g, soot.b, 0.0),
		])
	)

	p.mesh = _puff_mesh(0.07, 0.14, 8, 3, _particle_material(false))

	parent.add_child(p)
	p.position = pos
	p.emitting = true
	_auto_free(p, SMOKE_LIFETIME * (1.0 + 0.3) + SMOKE_LIFETIME * 0.65 + AUTO_FREE_MARGIN)
	return p


## Tetes keringat driver ojol yang kecewa karena pesanan batal (GDD 3.6.C).
## Sekali jalan, membebaskan dirinya sendiri. Murni visual; pemanggil yang
## mengurus `ProceduralAnimationSystem.sad_shake()` dan `AudioBus.sfx("sad")`.
static func sweat_drop(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	# Muncul di samping kepala; bila kepala belum dirakit, pakai perkiraan tinggi chibi.
	var head: Node3D = actor.get_node_or_null(NodePath("Head")) as Node3D
	if head == null:
		head = actor.get_node_or_null(NodePath("Body/Head")) as Node3D
	var anchor: Vector3 = Vector3(0.0, 0.62, 0.0)
	if head != null:
		anchor = head.position + Vector3(0.0, 0.10, 0.0)
	anchor += Vector3(0.20, 0.06, 0.14)

	var p := CPUParticles3D.new()
	p.name = "SweatDropFX"
	p.emitting = false
	p.one_shot = true
	p.amount = SWEAT_AMOUNT
	p.lifetime = SWEAT_LIFETIME
	p.lifetime_randomness = 0.25
	p.explosiveness = 0.55
	p.randomness = 0.4
	p.local_coords = false
	p.draw_order = CPUParticles3D.DRAW_ORDER_VIEW_DEPTH
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.03
	p.direction = Vector3(0.55, 1.0, 0.28).normalized()
	p.spread = 24.0
	p.initial_velocity_min = 0.45
	p.initial_velocity_max = 0.9
	p.gravity = Vector3(0.0, -3.1, 0.0)
	p.damping_min = 0.0
	p.damping_max = 0.2
	p.scale_amount_min = 0.75
	p.scale_amount_max = 1.15
	p.scale_amount_curve = _curve(PackedVector2Array([
		Vector2(0.0, 0.2), Vector2(0.15, 1.0), Vector2(0.8, 1.0), Vector2(1.0, 0.35),
	]))

	var drop: Color = Palette.FLOUR_WHITE.lerp(Palette.PASTEL_PERIWINKLE, 0.65)
	p.color = Color.WHITE
	p.color_ramp = _gradient(
		PackedFloat32Array([0.0, 0.15, 0.75, 1.0]),
		PackedColorArray([
			Color(drop.r, drop.g, drop.b, 0.0),
			Color(drop.r, drop.g, drop.b, 0.90),
			Color(drop.r, drop.g, drop.b, 0.80),
			Color(drop.r, drop.g, drop.b, 0.0),
		])
	)

	# Bulir memanjang: bola dengan tinggi lebih besar dari diameternya.
	p.mesh = _puff_mesh(0.030, 0.095, 6, 3, _particle_material(false))

	actor.add_child(p)
	p.position = anchor
	p.emitting = true
	_auto_free(p, SWEAT_LIFETIME * (1.0 + 0.25) + SWEAT_LIFETIME * 0.45 + AUTO_FREE_MARGIN)


# ---------------------------------------------------------------------------
# Efek 2D
# ---------------------------------------------------------------------------

## Koin emas melompat gembira disertai teks "+X KR" (GDD 4.3).
## `pos` memakai koordinat lokal `parent`. Emitter membuang dirinya sendiri.
static func coin_pop(parent: CanvasItem, pos: Vector2, amount: float) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var p := CPUParticles2D.new()
	p.name = "CoinPopFX"
	p.emitting = false
	p.one_shot = true
	p.amount = COIN_AMOUNT
	p.lifetime = COIN_LIFETIME
	p.lifetime_randomness = 0.25
	p.explosiveness = 0.92
	p.randomness = 0.45
	p.local_coords = true
	p.z_index = COIN_Z_INDEX
	p.draw_order = CPUParticles2D.DRAW_ORDER_LIFETIME

	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 10.0
	p.direction = Vector2(0.0, -1.0)
	p.spread = 44.0
	p.initial_velocity_min = 190.0
	p.initial_velocity_max = 330.0
	p.gravity = Vector2(0.0, 640.0)
	p.damping_min = 0.0
	p.damping_max = 20.0
	# Koin berputar di udara.
	p.angular_velocity_min = -260.0
	p.angular_velocity_max = 260.0
	p.scale_amount_min = 0.65
	p.scale_amount_max = 1.05
	# Lebar menyempit-melebar berulang = keping koin yang berjungkir di udara,
	# sementara tinggi memakai kurva pop biasa.
	p.split_scale = true
	p.scale_curve_x = _curve(PackedVector2Array([
		Vector2(0.0, 1.0), Vector2(0.22, 0.14), Vector2(0.44, 1.0),
		Vector2(0.66, 0.14), Vector2(0.88, 1.0), Vector2(1.0, 0.6),
	]))
	p.scale_curve_y = _curve(PackedVector2Array([
		Vector2(0.0, 0.35), Vector2(0.16, 1.15), Vector2(0.75, 1.0), Vector2(1.0, 0.45),
	]))

	p.color = Color.WHITE
	p.color_ramp = _gradient(
		PackedFloat32Array([0.0, 0.70, 1.0]),
		PackedColorArray([
			Color(1.0, 1.0, 1.0, 1.0),
			Color(1.0, 1.0, 1.0, 0.95),
			Color(1.0, 1.0, 1.0, 0.0),
		])
	)
	p.texture = _coin_texture()

	parent.add_child(p)
	p.position = pos
	p.emitting = true
	_auto_free(p, COIN_LIFETIME * (1.0 + 0.25) + AUTO_FREE_MARGIN)

	# Angka pendapatan menyertai koinnya (GDD 4.3 "koin emas melompat gembira (+KR)").
	var text: String = "+" + GameConfig.kr(amount)
	ProceduralAnimationSystem.float_text(parent, pos + Vector2(0.0, -22.0), text, Palette.GOLD_STAR)


## Lapisan hujan 2D satu layar penuh untuk hari hujan (GDD 10.2).
## Rintik dibuat jarang, pucat, dan miring lembut supaya terasa cozy — bukan
## badai suram. Menerus: pemanggil yang memanggil `queue_free()` saat cuaca
## berganti. `parent` sebaiknya CanvasLayer atau Control non-Container.
static func rain_overlay(parent: Node) -> CPUParticles2D:
	if parent == null or not is_instance_valid(parent):
		return null

	var screen: Vector2 = _screen_size(parent)

	var p := CPUParticles2D.new()
	p.name = "RainOverlay"
	p.emitting = false
	p.one_shot = false
	p.amount = RAIN_AMOUNT
	p.lifetime = RAIN_LIFETIME
	p.lifetime_randomness = 0.2
	p.explosiveness = 0.0
	p.randomness = 0.6
	p.local_coords = true
	p.z_index = RAIN_Z_INDEX
	p.draw_order = CPUParticles2D.DRAW_ORDER_LIFETIME
	# Layar sudah penuh rintik sejak frame pertama, tidak ada "hujan mulai kosong".
	p.preprocess = RAIN_LIFETIME * 1.2

	# Pita pemancar melebar jauh di atas layar agar tetap menutup penuh
	# walau aspek rasio perangkat jauh lebih lebar dari 1280x720.
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(screen.x * 1.2, 10.0)

	# Miring sedikit ke kanan; rintik menghadap arah jatuhnya.
	p.direction = Vector2(0.16, 1.0)
	p.spread = 3.0
	p.particle_flag_align_y = true
	p.initial_velocity_min = screen.y * 0.75
	p.initial_velocity_max = screen.y * 1.05
	p.gravity = Vector2(0.0, 240.0)
	p.damping_min = 0.0
	p.damping_max = 0.0
	p.scale_amount_min = 0.8
	p.scale_amount_max = 1.5

	var drizzle: Color = Palette.FLOUR_WHITE.lerp(Palette.PASTEL_PERIWINKLE, 0.7)
	p.color = Color.WHITE
	p.color_ramp = _gradient(
		PackedFloat32Array([0.0, 0.12, 0.85, 1.0]),
		PackedColorArray([
			Color(drizzle.r, drizzle.g, drizzle.b, 0.0),
			Color(drizzle.r, drizzle.g, drizzle.b, 0.50),
			Color(drizzle.r, drizzle.g, drizzle.b, 0.45),
			Color(drizzle.r, drizzle.g, drizzle.b, 0.0),
		])
	)
	p.texture = _raindrop_texture()

	parent.add_child(p)
	p.position = Vector2(screen.x * 0.5, -24.0)
	p.emitting = true
	return p


# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

## Material partikel: warna solid, tanpa shader kustom, tanpa bayangan.
## `vertex_color_use_as_albedo` wajib agar `color_ramp` CPUParticles3D terlihat.
static func _particle_material(additive: bool) -> StandardMaterial3D:
	if additive and _mat_glint != null:
		return _mat_glint
	if not additive and _mat_soft != null:
		return _mat_soft

	var m := StandardMaterial3D.new()
	m.albedo_color = Color.WHITE
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.disable_ambient_light = true
	m.disable_receive_shadows = true
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat_glint = m
	else:
		_mat_soft = m
	return m


## Bola gumpalan beranggaran rendah. 8x3 segmen ~ 64 tris, jauh di bawah
## batas 500-2.000 tris per objek rakitan (GDD 12.2) walau dikalikan 12-14.
static func _puff_mesh(radius: float, height: float, radial: int, rings: int, mat: Material) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = radial
	m.rings = rings
	m.material = mat
	return m


## Gradient dari daftar offset + warna. Kedua properti mengubah ukuran daftar
## titik, jadi offset diisi lebih dulu lalu warna dengan jumlah yang sama.
static func _gradient(offsets: PackedFloat32Array, colors: PackedColorArray) -> Gradient:
	var g := Gradient.new()
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_LINEAR
	g.offsets = offsets
	g.colors = colors
	return g


## Kurva skala partikel. `max_value` dinaikkan lebih dulu karena `add_point()`
## memotong nilai y ke rentang [min_value, max_value].
static func _curve(points: PackedVector2Array) -> Curve:
	var c := Curve.new()
	c.min_value = 0.0
	c.max_value = 2.0
	for pt in points:
		c.add_point(pt)
	return c


## Keping koin emas: gradient radial 24x24 px, dibangkitkan runtime tanpa berkas.
static func _coin_texture() -> GradientTexture2D:
	if _tex_coin != null:
		return _tex_coin
	var tex := GradientTexture2D.new()
	tex.width = 24
	tex.height = 24
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	var rim: Color = Palette.GOLDEN_CRUST
	var face: Color = Palette.GOLD_STAR
	var shine: Color = Palette.GOLD_STAR.lerp(Color.WHITE, 0.55)
	tex.gradient = _gradient(
		PackedFloat32Array([0.0, 0.40, 0.78, 0.86, 0.94]),
		PackedColorArray([
			Color(shine.r, shine.g, shine.b, 1.0),
			Color(face.r, face.g, face.b, 1.0),
			Color(rim.r, rim.g, rim.b, 1.0),
			Color(rim.r, rim.g, rim.b, 0.95),
			Color(rim.r, rim.g, rim.b, 0.0),
		])
	)
	_tex_coin = tex
	return tex


## Rintik hujan: goresan tegak 4x18 px yang memudar di kedua ujungnya.
static func _raindrop_texture() -> GradientTexture2D:
	if _tex_rain != null:
		return _tex_rain
	var tex := GradientTexture2D.new()
	tex.width = 4
	tex.height = 18
	tex.fill = GradientTexture2D.FILL_LINEAR
	tex.fill_from = Vector2(0.5, 0.0)
	tex.fill_to = Vector2(0.5, 1.0)
	tex.gradient = _gradient(
		PackedFloat32Array([0.0, 0.35, 0.72, 1.0]),
		PackedColorArray([
			Color(1.0, 1.0, 1.0, 0.0),
			Color(1.0, 1.0, 1.0, 0.85),
			Color(1.0, 1.0, 1.0, 0.85),
			Color(1.0, 1.0, 1.0, 0.0),
		])
	)
	_tex_rain = tex
	return tex


## Ukuran ruang gambar kanvas saat ini. Dengan stretch `canvas_items` nilai ini
## sudah berupa koordinat UI (1280x720 yang melebar mengikuti aspek layar).
static func _screen_size(node: Node) -> Vector2:
	if node != null and node.is_inside_tree():
		var vp: Viewport = node.get_viewport()
		if vp != null:
			var s: Vector2 = vp.get_visible_rect().size
			if s.x > 1.0 and s.y > 1.0:
				return s
	var w: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 1280))
	var h: float = float(ProjectSettings.get_setting("display/window/size/viewport_height", 720))
	return Vector2(w, h)


## Buang emitter sekali-jalan setelah partikel terakhir selesai, supaya tidak
## ada node yang menumpuk sepanjang hari bermain. Timer ikut berhenti saat
## pohon scene dijeda (process_always = false).
static func _auto_free(node: Node, delay: float) -> void:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return
	var tree: SceneTree = node.get_tree()
	if tree == null:
		return
	var timer: SceneTreeTimer = tree.create_timer(maxf(delay, 0.1), false)
	var cleanup: Callable = func() -> void:
		if is_instance_valid(node):
			node.queue_free()
	timer.timeout.connect(cleanup)
