class_name MaterialKeep
extends RefCounted
## Satu material penjaga untuk setiap kombinasi fitur shader, disimpan seumur
## proses (GDD 89.5, 109).
##
## BaseMaterial3D berbagi satu shader untuk semua material dengan kombinasi fitur
## yang sama, tetapi MEMBUANG shader itu begitu material terakhir dengan kombinasi
## tersebut dibebaskan. Visual yang datang dan pergi (jejak penempatan, arsiran
## ubin, penanda stasiun, bar kesabaran, perabot yang dibangun ulang setelah
## ditata) lalu memaksa shader yang sama dikompilasi lagi setiap kali muncul. Di
## browser satu kompilasi WebGL makan sekitar 0,2 detik bila cache GPU browser
## sudah hangat dan beberapa detik bila belum; itulah macet saat memilih perabot
## di Decoration Mode. Selama penjaganya hidup, shadernya tidak pernah dibuang,
## jadi setiap kombinasi hanya dikompilasi sekali (saat pemanasan loading,
## `ShaderWarmup`).

static var _kept: Dictionary = {}


## Simpan penjaga untuk setiap kombinasi fitur yang dipakai di bawah `root`.
## Mengembalikan jumlah kombinasi baru.
static func scan(root: Node) -> int:
	if root == null:
		return 0
	var added: int = 0
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for c: Node in n.get_children():
			stack.append(c)
		var gi := n as GeometryInstance3D
		if gi == null:
			continue
		added += keep(gi.material_override)
		var mi := n as MeshInstance3D
		if mi != null and mi.mesh != null:
			for s in mi.mesh.get_surface_count():
				added += keep(mi.mesh.surface_get_material(s))
				added += keep(mi.get_surface_override_material(s))
		var cp := n as CPUParticles3D
		if cp != null and cp.mesh != null:
			for s2 in cp.mesh.get_surface_count():
				added += keep(cp.mesh.surface_get_material(s2))
	return added


## Simpan penjaga untuk kombinasi fitur `m` bila belum ada (1 = baru).
static func keep(m: Material) -> int:
	var b := m as BaseMaterial3D
	if b == null:
		return 0
	var k: String = key_of(b)
	if _kept.has(k):
		return 0
	# Salinan, supaya pemilik aslinya bebas mengubah materialnya nanti.
	_kept[k] = b.duplicate()
	return 1


## Kombinasi fitur yang menentukan kode shader BaseMaterial3D. Warna, roughness,
## dan nilai lain yang hanya menjadi uniform tidak ikut.
static func key_of(m: BaseMaterial3D) -> String:
	return var_to_str([m.shading_mode, m.diffuse_mode, m.specular_mode, m.transparency, m.blend_mode,
		m.cull_mode, m.depth_draw_mode, m.no_depth_test, m.vertex_color_use_as_albedo, m.vertex_color_is_srgb,
		m.emission_enabled, m.normal_enabled, m.rim_enabled, m.clearcoat_enabled, m.anisotropy_enabled,
		m.ao_enabled, m.heightmap_enabled, m.subsurf_scatter_enabled, m.backlight_enabled, m.refraction_enabled,
		m.detail_enabled, m.proximity_fade_enabled, m.distance_fade_mode, m.billboard_mode, m.billboard_keep_scale,
		m.use_point_size, m.fixed_size, m.disable_receive_shadows, m.disable_ambient_light, m.shadow_to_opacity,
		m.texture_filter, m.albedo_texture != null, m.get_class()])


static func count() -> int:
	return _kept.size()


static func clear() -> void:
	_kept.clear()
