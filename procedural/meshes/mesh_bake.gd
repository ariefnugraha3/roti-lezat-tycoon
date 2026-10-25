class_name MeshBake
extends RefCounted
## Memanggang bagian statis model rakitan menjadi satu mesh berwarna verteks
## (GDD 12.3, 37, 109).
##
## Perabot, ruangan, dan roti dirakit dari puluhan sampai ratusan primitif, dan
## setiap primitif adalah satu draw call: satu rak Tier 5 saja hampir 300, dan
## toko Tier 5 yang lengkap lebih dari 2.500 per frame (tools/render_probe). Di
## renderer Compatibility (WebGL, Android kelas bawah) jumlah draw call adalah
## biaya utama. Bagian yang tidak pernah bergerak dijahit menjadi satu ArrayMesh
## dengan satu permukaan per kelompok material; warnanya pindah ke warna verteks.
##
## Material kelompok sama dengan material bagian aslinya kecuali albedo putih,
## jadi kombinasi fitur shadernya tetap (ACC_89_FEW_SHADERS). Yang dipanggang:
## - bagian ber-cahaya dengan warna verteks sRGB sebagai albedo (semua
##   `ProceduralMeshFactory.material` dan material roti), satu kelompok per
##   roughness/metalik dan per warna emisi bila bercahaya;
## - kaca tipis tanpa cahaya (`ProceduralMeshFactory._flat_overlay`): warnanya,
##   termasuk alfa, pindah ke warna verteks sRGB, kombinasi yang sama dengan kaca
##   toples dekorasi.
## Bagian yang digerakkan atau dicari namanya saat main (KEEP_NAMES,
## KEEP_PREFIXES, meta "live") dipanggang tersendiri di dalam node-nya, jadi
## tetap bergerak utuh. Petak isi (HANDS_OFF_PREFIXES) tidak disentuh, begitu
## pula node tersembunyi, billboard, dan geometri yang tidak dikenal. Geometri
## disusun ulang dari parameter primitifnya atau dari meta "surface_arrays" mesh
## SurfaceTool (`ProceduralMeshFactory.kept_commit`), tidak pernah dibaca balik
## dari GPU.

## Bagian yang dianimasikan atau dicari namanya oleh WorldView/animasi.
const KEEP_NAMES: Array[String] = ["Whisk", "Beater", "Agitator", "Door", "OvenDoor", "Pendulum"]
const KEEP_PREFIXES: Array[String] = ["Pintu"]
## Titik yang anak-anaknya diganti saat main (petak roti rak display).
const HANDS_OFF_PREFIXES: Array[String] = ["Slot"]
const BAKED_NAME: String = "Baked"

## kunci kelompok -> material bersama (albedo putih).
static var _materials: Dictionary = {}
## Selama `bake(..., true)`: roughness tidak memisahkan kelompok (roti kecil di
## rak; kilaunya tak terbedakan, satu petak jadi satu draw call).
static var _unify: bool = false


static func clear_caches() -> void:
	_materials.clear()


## Panggang bagian statis di bawah `root`. Node di `skip` (dan anak-anaknya)
## dilewati. `unify_roughness` menyatukan kelompok yang hanya berbeda roughness
## (roughness bagian pertama yang dipakai). Mengembalikan jumlah bagian yang
## dipanggang (0 = tidak berubah).
static func bake(root: Node3D, skip: Array = [], unify_roughness: bool = false) -> int:
	var was: bool = _unify
	_unify = unify_roughness
	var n: int = _bake(root, skip)
	_unify = was
	return n


static func _bake(root: Node3D, skip: Array) -> int:
	var groups: Dictionary = {}
	var order: Array[String] = []
	var done: Array[MeshInstance3D] = []
	var inner: Array[Node3D] = []
	_walk(root, Transform3D.IDENTITY, skip, groups, order, done, inner)
	var count: int = 0
	for k: Node3D in inner:
		count += _bake(k, [])
	# Satu bagian saja tidak menghemat apa pun, kecuali kelompok roughness-nya disatukan.
	if done.is_empty() or (done.size() == 1 and not _unify):
		return count
	var mesh := ArrayMesh.new()
	var kept: Array = []
	for key: String in order:
		var mb: MeshBuilder = groups[key]
		if mb.is_empty():
			continue
		var arrays: Array = mb.arrays()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _materials[key])
		kept.append(arrays)
	# Hasilnya bisa dipanggang lagi bersama yang lain (isi satu petak roti).
	mesh.set_meta("surface_arrays", kept)
	var out := MeshInstance3D.new()
	out.name = BAKED_NAME
	out.mesh = mesh
	out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	out.set_meta("baked_parts", done.size())
	root.add_child(out)
	for mi: MeshInstance3D in done:
		if mi.get_child_count() == 0:
			mi.get_parent().remove_child(mi)
			mi.free()
		else:
			mi.mesh = null
	return count + done.size()


static func is_kept(n: Node) -> bool:
	var nm: String = String(n.name)
	if KEEP_NAMES.has(nm) or n.has_meta("live"):
		return true
	for p: String in KEEP_PREFIXES:
		if nm.begins_with(p):
			return true
	return false


static func _hands_off(n: Node) -> bool:
	var nm: String = String(n.name)
	for p: String in HANDS_OFF_PREFIXES:
		if nm.begins_with(p):
			return true
	return false


static func _walk(n: Node, xf: Transform3D, skip: Array, groups: Dictionary, order: Array[String],
		done: Array[MeshInstance3D], inner: Array[Node3D]) -> void:
	for c: Node in n.get_children():
		var c3 := c as Node3D
		if c3 == null or not c3.visible or skip.has(c3) or _hands_off(c3):
			continue
		if is_kept(c3):
			inner.append(c3)
			continue
		var cxf: Transform3D = xf * c3.transform
		var mi := c3 as MeshInstance3D
		if mi != null and _add(mi, cxf, groups, order):
			done.append(mi)
		_walk(c3, cxf, skip, groups, order, done, inner)


## Material permukaan `s` yang benar-benar dipakai `mi`.
static func _material_of(mi: MeshInstance3D, s: int) -> Material:
	if mi.material_override != null:
		return mi.material_override
	var o: Material = mi.get_surface_override_material(s)
	if o != null:
		return o
	if mi.mesh is PrimitiveMesh:
		return (mi.mesh as PrimitiveMesh).material
	return mi.mesh.surface_get_material(s)


static func _is_glass(b: StandardMaterial3D) -> bool:
	return b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED and b.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA \
		and not b.vertex_color_is_srgb and not b.emission_enabled


## Kunci kelompok untuk material `m`, atau "" bila bagian itu tidak boleh dipanggang.
static func _group_key(m: Material) -> String:
	var b := m as StandardMaterial3D
	if b == null or not b.vertex_color_use_as_albedo or b.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
		return ""
	if b.albedo_texture != null or b.no_depth_test or b.blend_mode != BaseMaterial3D.BLEND_MODE_MIX:
		return ""
	var glass: bool = _is_glass(b)
	var lit: bool = b.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL and b.vertex_color_is_srgb \
		and b.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and b.albedo_color.a >= 1.0
	if not glass and not lit:
		return ""
	var key: String = "%s|%s|%.3f|%.3f" % [MaterialKeep.key_of(b), "u" if _unify else "%.3f" % b.roughness,
		b.metallic, b.metallic_specular]
	if b.emission_enabled:
		key += "|%s|%.3f" % [b.emission.to_html(), b.emission_energy_multiplier]
	if not _materials.has(key):
		var g: StandardMaterial3D = b.duplicate()
		g.albedo_color = Color.WHITE
		if glass:
			g.vertex_color_is_srgb = true
		_materials[key] = g
	return key


## Warna verteks pengganti albedo `m`: kaca membawa alfanya, yang lain buram.
static func _vertex_color(m: Material) -> Color:
	var b: StandardMaterial3D = m as StandardMaterial3D
	if _is_glass(b):
		return b.albedo_color
	return Color(b.albedo_color, 1.0)


static func _builder(key: String, groups: Dictionary, order: Array[String]) -> MeshBuilder:
	if not groups.has(key):
		groups[key] = MeshBuilder.new()
		order.append(key)
	return groups[key]


static func _add(mi: MeshInstance3D, xf: Transform3D, groups: Dictionary, order: Array[String]) -> bool:
	var m: Mesh = mi.mesh
	if m == null or mi.material_overlay != null or mi.transparency > 0.0:
		return false
	if m is PrimitiveMesh:
		var mat: Material = _material_of(mi, 0)
		var key: String = _group_key(mat)
		if key == "":
			return false
		var color: Color = _vertex_color(mat)
		if m is BoxMesh:
			_builder(key, groups, order).box(xf, (m as BoxMesh).size, color)
		elif m is CylinderMesh:
			var cy := m as CylinderMesh
			_builder(key, groups, order).cylinder_hard(xf, cy.height, cy.top_radius, cy.bottom_radius, color,
				cy.radial_segments, cy.cap_top, cy.cap_bottom)
		elif m is SphereMesh:
			var sp := m as SphereMesh
			if sp.is_hemisphere:
				return false
			_builder(key, groups, order).ellipsoid(xf, Vector3(sp.radius, sp.height * 0.5, sp.radius), color,
				sp.radial_segments, sp.rings + 1)
		elif m is TorusMesh:
			var to := m as TorusMesh
			_builder(key, groups, order).torus(xf, (to.inner_radius + to.outer_radius) * 0.5,
				(to.outer_radius - to.inner_radius) * 0.5, color, to.rings, to.ring_segments)
		elif m is CapsuleMesh:
			var ca := m as CapsuleMesh
			_capsule(_builder(key, groups, order), xf, ca.radius, ca.height, color, ca.radial_segments, ca.rings)
		else:
			return false
		return true
	var am := m as ArrayMesh
	if am == null or not am.has_meta("surface_arrays"):
		return false
	var kept: Array = am.get_meta("surface_arrays")
	if kept.size() != am.get_surface_count():
		return false
	var keys: Array[String] = []
	for s in kept.size():
		var k: String = _group_key(_material_of(mi, s))
		if k == "":
			return false
		keys.append(k)
	for s2 in kept.size():
		_builder(keys[s2], groups, order).append_arrays(kept[s2], xf, _vertex_color(_material_of(mi, s2)))
	return true


## CapsuleMesh Godot: tinggi total termasuk kedua tutup, sumbu Y, berpusat.
static func _capsule(mb: MeshBuilder, xf: Transform3D, r: float, height: float, color: Color, radial: int, rings: int) -> void:
	var half: float = maxf(height * 0.5 - r, 0.0)
	var cr: int = maxi(2, rings + 1)
	var profile := PackedVector2Array()
	for k in cr + 1:
		var al: float = -PI * 0.5 + PI * 0.5 * float(k) / float(cr)
		profile.append(Vector2(r * cos(al), -half + r * sin(al)))
	for k2 in range(0 if half > 0.0001 else 1, cr + 1):
		var al2: float = PI * 0.5 * float(k2) / float(cr)
		profile.append(Vector2(r * cos(al2), half + r * sin(al2)))
	mb.lathe(xf, profile, color, radial)
