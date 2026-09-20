class_name ProceduralMeshFactory
extends RefCounted

## Pabrik mesh primitif -- fondasi seluruh visual 3D Roti Lezat Tycoon (GDD 4.2 & 12.2).
##
## Semua objek 3D di game ini dirakit dari mesh primitif bawaan Godot (BoxMesh,
## CylinderMesh, SphereMesh, TorusMesh, CapsuleMesh) atau dibentuk secara matematis
## lewat SurfaceTool. TIDAK ADA satu pun aset eksternal (.png/.gltf/.obj/...).
##
## Anggaran geometri GDD 12.2 adalah 500 - 2.000 triangle per objek rakitan. Karena
## satu objek (mis. oven Tier 5) bisa terdiri dari belasan primitif, jumlah segmen di
## kelas ini ditetapkan RENDAH secara eksplisit. Nilai default Godot
## (radial_segments = 64, rings = 32) jauh terlalu mahal untuk target kita:
## Android kelas bawah dan browser WebGL2 dengan renderer Compatibility.
##
## Perkiraan biaya per primitif dengan konstanta di bawah:
##   box       12 tris | cylinder  ~40 tris | sphere ~144 tris
##   torus    192 tris | capsule  ~160 tris | rounded_slab 44 tris
##   lathe    segments x (titik profil - 1) x 2 tris
##
## CATATAN WINDING: Godot memakai urutan vertex searah jarum jam (clockwise) untuk
## sisi depan triangle, sehingga cross product tangan-kanan sebuah segitiga sisi
## depan menghadap KE DALAM benda. Helper `_add_tri()` membetulkan urutan vertex
## secara otomatis berdasarkan normal luar yang diminta, lalu
## `SurfaceTool.generate_normals()` menurunkan normal akhir dari winding tersebut.

# ---------------------------------------------------------------------------
# Anggaran segmen (GDD 12.2) -- jangan naikkan tanpa mengukur ulang tri budget
# ---------------------------------------------------------------------------

## Segmen melingkar bola: cukup bulat untuk kepala chibi, tetap murah.
const SPHERE_RADIAL_SEGMENTS: int = 12
## Cincin vertikal bola.
const SPHERE_RINGS: int = 6
## Segmen melingkar silinder (badan mixer, baguette, kaki meja).
const CYLINDER_RADIAL_SEGMENTS: int = 10
## Silinder tidak perlu subdivisi sisi.
const CYLINDER_RINGS: int = 1
## Jumlah segmen sepanjang lingkaran besar torus (donat).
const TORUS_RINGS: int = 12
## Jumlah segmen penampang torus.
const TORUS_RING_SEGMENTS: int = 8
## Segmen melingkar kapsul (badan & lengan chibi).
const CAPSULE_RADIAL_SEGMENTS: int = 10
## Cincin kubah kapsul.
const CAPSULE_RINGS: int = 4

## Batas minimum segmen radial `lathe()` agar tetap membentuk volume.
const LATHE_MIN_SEGMENTS: int = 3
## Batas maksimum segmen radial `lathe()` demi anggaran triangle.
const LATHE_MAX_SEGMENTS: int = 32
## Sudut lipat profil (derajat) yang dianggap "tajam" pada `lathe()`. Di bawah nilai
## ini normal dihaluskan (permukaan mulus), di atasnya dibiarkan patah (tepi tegas).
const LATHE_SMOOTH_ANGLE_DEG: float = 40.0

## Dimensi minimum yang masih aman dipakai (mencegah mesh nol / error Godot).
const MIN_DIM: float = 0.001
## Toleransi perbandingan float umum.
const EPS: float = 0.00001
## Ambang luas (kuadrat) segitiga yang dianggap nol dan dibuang.
const AREA_EPS: float = 0.000000001

## Nilai specular default: logam tembaga/krom klasik tetap terlihat lembut.
const DEFAULT_SPECULAR: float = 0.5

## Pasangan tanda +/- untuk iterasi sisi, rusuk, dan sudut pada rounded_slab().
const SIGNS: Array[float] = [1.0, -1.0]


# ---------------------------------------------------------------------------
# Material
# ---------------------------------------------------------------------------

## Material solid ala GDD 12.2: hanya warna + roughness (+ emisi opsional).
## Semua fitur mahal (normal map, rim, clearcoat, SSS, refraksi, proximity fade)
## dimatikan karena renderer Compatibility tidak membutuhkannya.
## `emis` hanya mengaktifkan emisi bila benar-benar memancarkan cahaya
## (dipakai untuk bara oven dan lampu penghangat etalase `#FFAA44`).
static func material(color: Color, rough := 0.85, metal := 0.0, emis := Color.BLACK) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	m.albedo_color = color
	m.roughness = clampf(rough, 0.0, 1.0)
	m.metallic = clampf(metal, 0.0, 1.0)
	m.metallic_specular = DEFAULT_SPECULAR
	# Lambert lebih murah daripada Burley dan sudah pas untuk gaya warna solid kartun.
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT
	m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
	m.cull_mode = BaseMaterial3D.CULL_BACK
	m.vertex_color_use_as_albedo = false

	# Emisi: aktif hanya bila warnanya memang memancar (bukan hitam).
	var glowing: bool = emis != Color.BLACK and (emis.r + emis.g + emis.b) > 0.0
	m.emission_enabled = glowing
	if glowing:
		m.emission = emis
		m.emission_energy_multiplier = 1.0

	# Transparansi hanya dinyalakan bila alpha memang < 1 (mis. kaca etalase Tier 2+).
	if color.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY
	else:
		m.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
		m.blend_mode = BaseMaterial3D.BLEND_MODE_MIX
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_OPAQUE_ONLY

	# --- Matikan semua fitur yang tidak dipakai (hemat uniform & cabang shader) ---
	m.normal_enabled = false
	m.rim_enabled = false
	m.clearcoat_enabled = false
	m.anisotropy_enabled = false
	m.ao_enabled = false
	m.heightmap_enabled = false
	m.subsurf_scatter_enabled = false
	m.backlight_enabled = false
	m.refraction_enabled = false
	m.detail_enabled = false
	m.proximity_fade_enabled = false
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_DISABLED
	m.disable_ambient_light = false
	m.use_point_size = false
	m.no_depth_test = false
	return m


# ---------------------------------------------------------------------------
# Primitif
# ---------------------------------------------------------------------------

## Balok. Tanpa subdivisi -- 12 triangle saja.
static func box(size: Vector3, color: Color, rough := 0.85) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(
		maxf(absf(size.x), MIN_DIM),
		maxf(absf(size.y), MIN_DIM),
		maxf(absf(size.z), MIN_DIM)
	)
	mesh.subdivide_width = 0
	mesh.subdivide_height = 0
	mesh.subdivide_depth = 0
	mesh.material = material(color, rough)
	return _instance(mesh, "Box")


## Silinder / kerucut terpotong. `rt` radius atas, `rb` radius bawah.
## Salah satu radius boleh 0 untuk membentuk kerucut (mis. ujung topi koki).
static func cylinder(h: float, rt: float, rb: float, color: Color, rough := 0.85) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = maxf(absf(h), MIN_DIM)
	mesh.top_radius = maxf(absf(rt), 0.0)
	mesh.bottom_radius = maxf(absf(rb), 0.0)
	# Kedua radius nol akan menghasilkan mesh kosong; beri sedikit ketebalan.
	if mesh.top_radius <= EPS and mesh.bottom_radius <= EPS:
		mesh.bottom_radius = MIN_DIM
	mesh.radial_segments = CYLINDER_RADIAL_SEGMENTS
	mesh.rings = CYLINDER_RINGS
	mesh.cap_top = mesh.top_radius > EPS
	mesh.cap_bottom = mesh.bottom_radius > EPS
	mesh.material = material(color, rough)
	return _instance(mesh, "Cylinder")


## Bola penuh. Dipakai untuk kepala chibi, bun bulat, dan knob alat.
static func sphere(r: float, color: Color, rough := 0.9) -> MeshInstance3D:
	var radius: float = maxf(absf(r), MIN_DIM)
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = SPHERE_RADIAL_SEGMENTS
	mesh.rings = SPHERE_RINGS
	mesh.is_hemisphere = false
	mesh.material = material(color, rough)
	return _instance(mesh, "Sphere")


## Torus (donat). Urutan argumen bebas: nilai kecil dipakai sebagai radius dalam.
static func torus(inner: float, outer: float, color: Color, rough := 0.9) -> MeshInstance3D:
	var lo: float = maxf(minf(absf(inner), absf(outer)), MIN_DIM)
	var hi: float = maxf(absf(inner), absf(outer))
	if hi - lo < MIN_DIM:
		hi = lo + MIN_DIM
	var mesh := TorusMesh.new()
	mesh.inner_radius = lo
	mesh.outer_radius = hi
	mesh.rings = TORUS_RINGS
	mesh.ring_segments = TORUS_RING_SEGMENTS
	mesh.material = material(color, rough)
	return _instance(mesh, "Torus")


## Kapsul: bentuk empuk membulat untuk badan dan lengan karakter chibi.
## `h` adalah tinggi TOTAL termasuk kedua kubah, jadi minimal 2 x radius.
static func capsule(h: float, r: float, color: Color) -> MeshInstance3D:
	var radius: float = maxf(absf(r), MIN_DIM)
	var mesh := CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(absf(h), radius * 2.0 + MIN_DIM)
	mesh.radial_segments = CAPSULE_RADIAL_SEGMENTS
	mesh.rings = CAPSULE_RINGS
	mesh.material = material(color, 0.9)
	return _instance(mesh, "Capsule")


# ---------------------------------------------------------------------------
# Bentuk SurfaceTool
# ---------------------------------------------------------------------------

## Balok dengan 12 rusuk dipangkas (chamfer) sebesar `bevel` -- tulang punggung
## perabot cozy, meja kasir, dan roti tawar montok (GDD 4.1).
## Terdiri dari 6 sisi utama (12 tris) + 12 pita rusuk (24 tris) + 8 sudut (8 tris)
## = 44 triangle. Sisi utama tetap rata/tegas, sedangkan pita rusuk dan sudut
## dihaluskan bersama agar tepinya terasa lembut seperti adonan.
static func rounded_slab(size: Vector3, bevel: float, color: Color) -> MeshInstance3D:
	var half := Vector3(
		maxf(absf(size.x), MIN_DIM) * 0.5,
		maxf(absf(size.y), MIN_DIM) * 0.5,
		maxf(absf(size.z), MIN_DIM) * 0.5
	)
	var smallest: float = minf(minf(half.x, half.y), half.z)
	# Bevel dibatasi 90% setengah-dimensi terkecil supaya sisi utama tidak lenyap.
	var b: float = clampf(bevel, 0.0, smallest * 0.9)
	var inner := Vector3(half.x - b, half.y - b, half.z - b)
	var chamfered: bool = b > MIN_DIM

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- 6 sisi utama, masing-masing grup halus sendiri agar tetap rata ---
	var group_id: int = 1
	for axis in range(3):
		var u: int = (axis + 1) % 3
		var v: int = (axis + 2) % 3
		var a_len: float = _comp(half, axis)
		var u_len: float = _comp(inner, u)
		var v_len: float = _comp(inner, v)
		for s in SIGNS:
			var n: Vector3 = _axis_unit(axis) * s
			var p0: Vector3 = _pt(axis, s * a_len, u, -u_len, v, -v_len)
			var p1: Vector3 = _pt(axis, s * a_len, u, u_len, v, -v_len)
			var p2: Vector3 = _pt(axis, s * a_len, u, u_len, v, v_len)
			var p3: Vector3 = _pt(axis, s * a_len, u, -u_len, v, v_len)
			_add_quad(st, p0, p1, p2, p3, n, group_id)
			group_id += 1

	if chamfered:
		# --- 12 pita rusuk: menghubungkan dua sisi yang bersebelahan ---
		for a in range(3):
			for c in range(a + 1, 3):
				var e: int = 3 - a - c
				var ea: float = _comp(inner, e)
				for sa in SIGNS:
					for sc in SIGNS:
						var n: Vector3 = (_axis_unit(a) * sa + _axis_unit(c) * sc).normalized()
						var a0: Vector3 = _pt(a, sa * _comp(half, a), c, sc * _comp(inner, c), e, -ea)
						var a1: Vector3 = _pt(a, sa * _comp(half, a), c, sc * _comp(inner, c), e, ea)
						var b1: Vector3 = _pt(a, sa * _comp(inner, a), c, sc * _comp(half, c), e, ea)
						var b0: Vector3 = _pt(a, sa * _comp(inner, a), c, sc * _comp(half, c), e, -ea)
						_add_quad(st, a0, a1, b1, b0, n, 0)

		# --- 8 sudut: satu segitiga per oktan ---
		for sx in SIGNS:
			for sy in SIGNS:
				for sz in SIGNS:
					var px := Vector3(sx * half.x, sy * inner.y, sz * inner.z)
					var py := Vector3(sx * inner.x, sy * half.y, sz * inner.z)
					var pz := Vector3(sx * inner.x, sy * inner.y, sz * half.z)
					var n := Vector3(sx, sy, sz).normalized()
					_add_tri(st, px, py, pz, n, 0)

	st.generate_normals()
	st.index()
	st.set_material(material(color, 0.85))
	return _instance(st.commit(), "Slab")


## Memutar profil 2D (x = radius, y = tinggi) mengelilingi sumbu Y.
## Dipakai untuk mangkuk mixer, kubah tudung saji, bentuk lonceng, dan segmen
## croissant. Profil WAJIB berurutan dari bawah ke atas; bila terbalik profil
## dibalik otomatis agar normal tetap menghadap ke luar.
## Titik dengan radius 0 diperlakukan sebagai pole: hanya dibuat kipas segitiga,
## tanpa quad berluas nol. Penutup atas/bawah tidak dibuat otomatis -- tutup
## profilnya sendiri (turunkan radius ke 0) bila ingin permukaan tertutup.
static func lathe(profile: PackedVector2Array, segments: int, color: Color) -> MeshInstance3D:
	var prof: PackedVector2Array = _clean_profile(profile)
	if prof.size() < 2:
		push_warning("ProceduralMeshFactory.lathe(): profil kurang dari 2 titik valid.")
		return _instance(ArrayMesh.new(), "LatheInvalid")

	var seg: int = clampi(segments, LATHE_MIN_SEGMENTS, LATHE_MAX_SEGMENTS)

	# Pra-hitung cos/sin per segmen. Vertex dipakai ulang dari array yang sama
	# supaya posisinya identik bit-per-bit dan generate_normals() bisa menyatukan
	# normal di sambungan (termasuk sambungan 360 derajat).
	var cos_v := PackedFloat32Array()
	var sin_v := PackedFloat32Array()
	var mid_cos := PackedFloat32Array()
	var mid_sin := PackedFloat32Array()
	cos_v.resize(seg)
	sin_v.resize(seg)
	mid_cos.resize(seg)
	mid_sin.resize(seg)
	for j in range(seg):
		var ang: float = TAU * float(j) / float(seg)
		var ang_mid: float = ang + TAU / (2.0 * float(seg))
		cos_v[j] = cos(ang)
		sin_v[j] = sin(ang)
		mid_cos[j] = cos(ang_mid)
		mid_sin[j] = sin(ang_mid)

	# Cincin vertex per titik profil.
	var rings: Array[PackedVector3Array] = []
	for i in range(prof.size()):
		var ring := PackedVector3Array()
		ring.resize(seg)
		var r: float = prof[i].x
		var y: float = prof[i].y
		for j in range(seg):
			ring[j] = Vector3(r * cos_v[j], y, r * sin_v[j])
		rings.append(ring)

	var groups: PackedInt32Array = _profile_smooth_groups(prof)

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	for i in range(prof.size() - 1):
		var r0: float = prof[i].x
		var y0: float = prof[i].y
		var r1: float = prof[i + 1].x
		var y1: float = prof[i + 1].y
		var bottom_pole: bool = r0 <= EPS
		var top_pole: bool = r1 <= EPS
		if bottom_pole and top_pole:
			continue  # segmen di sepanjang sumbu: tidak menghasilkan permukaan

		# Normal luar pada bidang (radius, tinggi): (dy, -dr) untuk profil bawah-ke-atas.
		var dr: float = r1 - r0
		var dy: float = y1 - y0
		var plane_n := Vector2(dy, -dr)
		if plane_n.length_squared() <= EPS * EPS:
			continue
		plane_n = plane_n.normalized()

		var g: int = groups[i]
		var ring0: PackedVector3Array = rings[i]
		var ring1: PackedVector3Array = rings[i + 1]
		for j in range(seg):
			var j2: int = (j + 1) % seg
			var n := Vector3(plane_n.x * mid_cos[j], plane_n.y, plane_n.x * mid_sin[j])
			if bottom_pole:
				_add_tri(st, ring0[0], ring1[j], ring1[j2], n, g)
			elif top_pole:
				_add_tri(st, ring1[0], ring0[j], ring0[j2], n, g)
			else:
				_add_quad(st, ring0[j], ring0[j2], ring1[j2], ring1[j], n, g)

	st.generate_normals()
	st.index()
	st.set_material(material(color, 0.85))
	return _instance(st.commit(), "Lathe")


# ---------------------------------------------------------------------------
# Helper perakitan
# ---------------------------------------------------------------------------

## Node3D kosong bernama, dipakai sebagai induk kelompok bagian objek rakitan.
static func group(name: String) -> Node3D:
	var n := Node3D.new()
	n.name = name if not name.is_empty() else "Group"
	return n


## Menempelkan `child` ke `parent` sekaligus mengatur posisi, rotasi (derajat),
## dan skala. Mengembalikan `child` agar bisa dirangkai berantai.
static func attach(parent: Node3D, child: Node3D, pos: Vector3, rot_deg := Vector3.ZERO, scale := Vector3.ONE) -> Node3D:
	if parent == null or child == null:
		push_warning("ProceduralMeshFactory.attach(): parent atau child null.")
		return child
	var old_parent: Node = child.get_parent()
	if old_parent != null and old_parent != parent:
		old_parent.remove_child(child)
		old_parent = null
	if old_parent == null:
		parent.add_child(child)
	child.position = pos
	child.rotation_degrees = rot_deg
	child.scale = scale
	return child


## Menjumlahkan triangle seluruh MeshInstance3D di dalam `root` (termasuk root
## sendiri). Dipakai test untuk menegaskan anggaran GDD 12.2: 500 - 2.000 tris.
static func tri_count(root: Node) -> int:
	if root == null:
		return 0
	var total: int = 0
	if root is MeshInstance3D:
		total += _mesh_tris((root as MeshInstance3D).mesh)
	for child in root.get_children():
		total += tri_count(child)
	return total


# ---------------------------------------------------------------------------
# Internal
# ---------------------------------------------------------------------------

## Membungkus mesh menjadi MeshInstance3D bernama.
static func _instance(mesh: Mesh, node_name: String) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = node_name
	return mi


## Komponen Vector3 berdasarkan indeks sumbu (0 = x, 1 = y, 2 = z).
static func _comp(v: Vector3, axis: int) -> float:
	if axis == 0:
		return v.x
	if axis == 1:
		return v.y
	return v.z


## Vektor satuan sumbu (0 = +X, 1 = +Y, 2 = +Z).
static func _axis_unit(axis: int) -> Vector3:
	if axis == 0:
		return Vector3.RIGHT
	if axis == 1:
		return Vector3.UP
	return Vector3.BACK


## Menyusun titik dari tiga pasangan (indeks sumbu, nilai) yang saling berbeda.
static func _pt(a0: int, v0: float, a1: int, v1: float, a2: int, v2: float) -> Vector3:
	return _axis_unit(a0) * v0 + _axis_unit(a1) * v1 + _axis_unit(a2) * v2


## Menambahkan satu segitiga dengan winding yang dibetulkan agar sisi depannya
## menghadap `outward`. Godot memakai winding clockwise untuk sisi depan, jadi
## cross product tangan-kanan harus berlawanan arah dengan normal luar.
## Segitiga berluas nol dibuang supaya generate_normals() tidak menghasilkan NaN.
static func _add_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, outward: Vector3, smooth_group: int) -> void:
	var rhr: Vector3 = (b - a).cross(c - a)
	if rhr.length_squared() <= AREA_EPS:
		return
	st.set_smooth_group(smooth_group)
	if rhr.dot(outward) > 0.0:
		st.add_vertex(a)
		st.add_vertex(c)
		st.add_vertex(b)
	else:
		st.add_vertex(a)
		st.add_vertex(b)
		st.add_vertex(c)


## Menambahkan quad (p0-p1-p2-p3 berurutan mengelilingi permukaan) sebagai 2 tris.
static func _add_quad(st: SurfaceTool, p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, outward: Vector3, smooth_group: int) -> void:
	_add_tri(st, p0, p1, p2, outward, smooth_group)
	_add_tri(st, p0, p2, p3, outward, smooth_group)


## Membersihkan profil lathe: radius negatif dicerminkan, titik kembar dibuang,
## dan urutan dipastikan dari bawah ke atas (y menaik) agar normal ke luar.
static func _clean_profile(profile: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in profile:
		var point := Vector2(maxf(absf(p.x), 0.0), p.y)
		if out.size() > 0 and out[out.size() - 1].distance_squared_to(point) <= EPS * EPS:
			continue  # titik kembar: lewati
		out.append(point)
	if out.size() >= 2 and out[out.size() - 1].y < out[0].y:
		out.reverse()
	return out


## Menentukan grup halus per segmen profil. Segmen dengan lipatan lebih landai
## dari LATHE_SMOOTH_ANGLE_DEG berbagi grup (normal dihaluskan / mulus),
## lipatan tajam memulai grup baru (tepi tetap tegas seperti bibir mangkuk).
static func _profile_smooth_groups(prof: PackedVector2Array) -> PackedInt32Array:
	var groups := PackedInt32Array()
	var band_count: int = prof.size() - 1
	if band_count <= 0:
		return groups
	var dirs: Array[Vector2] = []
	for i in range(band_count):
		dirs.append((prof[i + 1] - prof[i]).normalized())
	var g: int = 0
	groups.append(g)
	for i in range(1, band_count):
		var d0: Vector2 = dirs[i - 1]
		var d1: Vector2 = dirs[i]
		if d0.length_squared() < 0.5 or d1.length_squared() < 0.5:
			g += 1
		elif rad_to_deg(acos(clampf(d0.dot(d1), -1.0, 1.0))) > LATHE_SMOOTH_ANGLE_DEG:
			g += 1
		groups.append(g)
	return groups


## Jumlah triangle sebuah Mesh (bekerja untuk PrimitiveMesh maupun ArrayMesh).
static func _mesh_tris(mesh: Mesh) -> int:
	if mesh == null:
		return 0
	var total: int = 0
	# surface_get_primitive_type() hanya tersedia di ArrayMesh. PrimitiveMesh bawaan
	# (BoxMesh, SphereMesh, CylinderMesh, TorusMesh, CapsuleMesh) selalu segitiga,
	# jadi pemeriksaan tipe dilewati untuk mesh jenis itu.
	var arr_mesh: ArrayMesh = mesh as ArrayMesh
	for s in range(mesh.get_surface_count()):
		if arr_mesh != null and arr_mesh.surface_get_primitive_type(s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arrays: Array = mesh.surface_get_arrays(s)
		if arrays.is_empty():
			continue
		var index_data: Variant = arrays[Mesh.ARRAY_INDEX]
		if index_data is PackedInt32Array and (index_data as PackedInt32Array).size() > 0:
			total += floori(float((index_data as PackedInt32Array).size()) / 3.0)
			continue
		var vertex_data: Variant = arrays[Mesh.ARRAY_VERTEX]
		if vertex_data is PackedVector3Array:
			total += floori(float((vertex_data as PackedVector3Array).size()) / 3.0)
	return total
