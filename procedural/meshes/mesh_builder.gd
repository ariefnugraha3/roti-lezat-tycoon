class_name MeshBuilder
extends RefCounted
## Perakit mesh gabungan berwarna verteks (GDD 12.3, 37.4). Banyak bentuk dasar
## (elipsoid, kapsul meruncing, lathe, torus, kotak, poligon) dijahit menjadi
## SATU ArrayMesh sehingga satu segmen karakter = satu draw call, sementara
## warnanya tetap per-bagian lewat warna verteks. Normal dihitung analitik agar
## bentuk low-poly tetap terlihat bulat dan empuk.
##
## Arah hadap ikut konvensi karakter: sudut azimut 0 = depan (-Z). Urutan verteks
## tiap segitiga diorientasikan otomatis dari normalnya (Godot memakai urutan
## searah jarum jam untuk sisi depan), jadi pemanggil tidak perlu memikirkannya.

const MATTE: StringName = &"matte"
const SATIN: StringName = &"satin"
const SHADOW: StringName = &"shadow"
## Tanda kecil yang selalu menghadap kamera tanpa pencahayaan (huruf "Z" kantuk).
const SIGN: StringName = &"sign"

static var _materials: Dictionary = {}

var _v := PackedVector3Array()
var _n := PackedVector3Array()
var _c := PackedColorArray()
var _i := PackedInt32Array()
var _min := Vector3(INF, INF, INF)
var _max := Vector3(-INF, -INF, -INF)


func is_empty() -> bool:
	return _i.is_empty()


func tri_count() -> int:
	return _i.size() / 3


# ===========================================================================
# BENTUK DASAR
# ===========================================================================

## Elipsoid penuh atau terpotong. `theta_max` (Callable(phi) -> radian, dari
## puncak) memotong bagian bawah per arah hadap -- dipakai untuk garis rambut,
## tudung, dan topi. `radius_scale` (Callable(theta, t) -> float, t = 0 di
## puncak s.d. 1 di tepi potongan) mengembangkan atau menyelipkan tepi (rambut
## bob, rambut yang menempel ke kulit). `color_fn` (Callable(unit: Vector3) ->
## Color) memberi gradasi warna.
func ellipsoid(xf: Transform3D, radii: Vector3, color: Color, radial: int, rings: int,
		color_fn: Callable = Callable(), theta_max: Callable = Callable(),
		radius_scale: Callable = Callable()) -> void:
	radial = maxi(3, radial)
	rings = maxi(2, rings)
	var nb: Basis = xf.basis.inverse().transposed()
	var rows: Array[PackedInt32Array] = []
	for r in rings + 1:
		var t: float = float(r) / float(rings)
		var row := PackedInt32Array()
		for j in radial:
			var phi: float = TAU * float(j) / float(radial)
			var tmax: float = PI if not theta_max.is_valid() else float(theta_max.call(phi))
			var theta: float = t * tmax
			var u := Vector3(sin(phi) * sin(theta), cos(theta), -cos(phi) * sin(theta))
			var k: float = 1.0 if not radius_scale.is_valid() else float(radius_scale.call(theta, t))
			var p := Vector3(u.x * radii.x, u.y * radii.y, u.z * radii.z) * k
			var nl := Vector3(u.x / radii.x, u.y / radii.y, u.z / radii.z)
			var col: Color = color if not color_fn.is_valid() else Color(color_fn.call(u))
			row.append(_vert(xf * p, nb * nl, col))
		rows.append(row)
	_stitch(rows, true)


## Potongan cangkang elipsoid: sektor azimut phi_from..phi_to (radian, 0 =
## depan, tidak menyambung) dari theta_top sampai theta_bottom(phi) -- dipakai
## untuk poni bergerigi yang menyatu dengan cangkang rambut. `radius_scale` =
## Callable(theta, t) seperti ellipsoid(); `color_fn` = Callable(unit) -> Color.
func shell(xf: Transform3D, radii: Vector3, color: Color, phi_from: float, phi_to: float, cols: int,
		rings: int, theta_top: float, theta_bottom: Callable, color_fn: Callable = Callable(),
		radius_scale: Callable = Callable()) -> void:
	cols = maxi(1, cols)
	rings = maxi(1, rings)
	var nb: Basis = xf.basis.inverse().transposed()
	var rows: Array[PackedInt32Array] = []
	for r in rings + 1:
		var t: float = float(r) / float(rings)
		var row := PackedInt32Array()
		for j in cols + 1:
			var phi: float = lerpf(phi_from, phi_to, float(j) / float(cols))
			var theta: float = lerpf(theta_top, float(theta_bottom.call(phi)), t)
			var u := Vector3(sin(phi) * sin(theta), cos(theta), -cos(phi) * sin(theta))
			var k: float = 1.0 if not radius_scale.is_valid() else float(radius_scale.call(theta, t))
			var p := Vector3(u.x * radii.x, u.y * radii.y, u.z * radii.z) * k
			var nl := Vector3(u.x / radii.x, u.y / radii.y, u.z / radii.z)
			var col: Color = color if not color_fn.is_valid() else Color(color_fn.call(u))
			row.append(_vert(xf * p, nb * nl, col))
		rows.append(row)
	_stitch(rows, false)


## Kapsul meruncing dari titik `a` (jari-jari ra) ke `b` (jari-jari rb).
## `color_fn` menerima f = posisi sepanjang batang (0 di a, 1 di b; negatif /
## lebih dari 1 di tutup bulat). `cuts` menambah cincin verteks pada f tertentu
## supaya batas warna (lengan baju, kaus kaki) tegas, bukan gradasi.
## `end_rings` (bila >= 1) memberi resolusi berbeda untuk tutup di `b` -- tutup
## yang tersembunyi di dalam tangan/sepatu cukup satu cincin.
func capsule(a: Vector3, b: Vector3, ra: float, rb: float, color: Color, radial: int,
		cap_rings: int = 3, color_fn: Callable = Callable(),
		cuts: PackedFloat32Array = PackedFloat32Array(), end_rings: int = -1) -> void:
	var axis: Vector3 = b - a
	var length: float = axis.length()
	if length < 0.0001:
		ellipsoid(Transform3D(Basis(), a), Vector3.ONE * maxf(ra, rb), color, radial, cap_rings * 2)
		return
	var profile := PackedVector2Array()
	var cr: int = maxi(1, cap_rings)
	var er: int = cr if end_rings < 1 else end_rings
	for k in cr + 1:
		var al: float = -PI * 0.5 + PI * 0.5 * float(k) / float(cr)
		profile.append(Vector2(ra * cos(al), ra * sin(al)))
	var sorted_cuts: PackedFloat32Array = cuts.duplicate()
	sorted_cuts.sort()
	for c: float in sorted_cuts:
		if c > 0.0 and c < 1.0:
			profile.append(Vector2(lerpf(ra, rb, c), length * c))
	for k2 in er + 1:
		var al2: float = PI * 0.5 * float(k2) / float(er)
		profile.append(Vector2(rb * cos(al2), length + rb * sin(al2)))
	var xf := Transform3D(frame_y(axis / length), a)
	var fn: Callable = Callable()
	if color_fn.is_valid():
		fn = func(y: float, _phi: float) -> Color: return color_fn.call(y / length)
	lathe(xf, profile, color, radial, fn)


## Profil (r, y) diputar mengelilingi sumbu Y lokal. `angle_from/to` membuat
## sektor terbuka (celemek). `color_fn` = Callable(y, phi) -> Color.
func lathe(xf: Transform3D, profile: PackedVector2Array, color: Color, radial: int,
		color_fn: Callable = Callable(), angle_from: float = 0.0, angle_to: float = TAU) -> void:
	radial = maxi(3, radial)
	var closed: bool = is_equal_approx(angle_to - angle_from, TAU)
	var steps: int = radial if closed else radial + 1
	var nb: Basis = xf.basis.inverse().transposed()
	var rows: Array[PackedInt32Array] = []
	var count: int = profile.size()
	for k in count:
		var prev: Vector2 = profile[maxi(k - 1, 0)]
		var next: Vector2 = profile[mini(k + 1, count - 1)]
		var tan2: Vector2 = next - prev
		var n2 := Vector2(tan2.y, -tan2.x).normalized()
		var row := PackedInt32Array()
		for j in steps:
			var phi: float = angle_from + (angle_to - angle_from) * float(j) / float(radial)
			var s: float = sin(phi)
			var c: float = -cos(phi)
			var p := Vector3(s * profile[k].x, profile[k].y, c * profile[k].x)
			var nl := Vector3(s * n2.x, n2.y, c * n2.x)
			var col: Color = color if not color_fn.is_valid() else Color(color_fn.call(profile[k].y, phi))
			row.append(_vert(xf * p, nb * nl, col))
		rows.append(row)
	_stitch(rows, closed)


## Silinder / kerucut terpotong setinggi `h` berpusat di xf (sumbu Y).
func cylinder(xf: Transform3D, h: float, r_top: float, r_bottom: float, color: Color, radial: int,
		cap_top: bool = true, cap_bottom: bool = true) -> void:
	var p := PackedVector2Array()
	if cap_bottom:
		p.append(Vector2(0.0, -h * 0.5))
		p.append(Vector2(r_bottom * 0.999, -h * 0.5))
	p.append(Vector2(r_bottom, -h * 0.5))
	p.append(Vector2(r_top, h * 0.5))
	if cap_top:
		p.append(Vector2(r_top * 0.999, h * 0.5))
		p.append(Vector2(0.0, h * 0.5))
	lathe(xf, p, color, radial)


## Torus di bidang XZ lokal. `arc_from/to` (radian, 0 = depan) membuat busur.
## `color_fn` = Callable(phi) -> Color (motif kotak-kotak, manik-manik).
func torus(xf: Transform3D, ring_r: float, tube_r: float, color: Color, segs: int, tube_segs: int,
		arc_from: float = 0.0, arc_to: float = TAU, color_fn: Callable = Callable()) -> void:
	segs = maxi(3, segs)
	tube_segs = maxi(3, tube_segs)
	var closed: bool = is_equal_approx(arc_to - arc_from, TAU)
	var steps: int = segs if closed else segs + 1
	var nb: Basis = xf.basis.inverse().transposed()
	var rows: Array[PackedInt32Array] = []
	for j in steps:
		var phi: float = arc_from + (arc_to - arc_from) * float(j) / float(segs)
		var radial_dir := Vector3(sin(phi), 0.0, -cos(phi))
		var col: Color = color if not color_fn.is_valid() else Color(color_fn.call(phi))
		var row := PackedInt32Array()
		for k in tube_segs:
			var a: float = TAU * float(k) / float(tube_segs)
			var nl: Vector3 = radial_dir * cos(a) + Vector3.UP * sin(a)
			var p: Vector3 = radial_dir * ring_r + nl * tube_r
			row.append(_vert(xf * p, nb * nl, col))
		rows.append(row)
	_stitch(rows, true, closed)


## Kotak bersudut tegas (6 sisi, normal datar).
func box(xf: Transform3D, size: Vector3, color: Color) -> void:
	var h: Vector3 = size * 0.5
	var nb: Basis = xf.basis.inverse().transposed()
	var faces: Array = [
		[Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)],
		[Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, -1)],
		[Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)],
		[Vector3(0, -1, 0), Vector3(0, 0, -1), Vector3(1, 0, 0)],
		[Vector3(0, 0, 1), Vector3(1, 0, 0), Vector3(0, 1, 0)],
		[Vector3(0, 0, -1), Vector3(-1, 0, 0), Vector3(0, 1, 0)],
	]
	for f: Array in faces:
		var n: Vector3 = f[0]
		var u: Vector3 = f[1]
		var w: Vector3 = f[2]
		var center := Vector3(n.x * h.x, n.y * h.y, n.z * h.z)
		var du := Vector3(u.x * h.x, u.y * h.y, u.z * h.z)
		var dw := Vector3(w.x * h.x, w.y * h.y, w.z * h.z)
		var wn: Vector3 = nb * n
		var a: int = _vert(xf * (center - du - dw), wn, color)
		var b: int = _vert(xf * (center + du - dw), wn, color)
		var c: int = _vert(xf * (center + du + dw), wn, color)
		var d: int = _vert(xf * (center - du + dw), wn, color)
		_tri(a, b, c)
		_tri(a, c, d)


## Poligon cembung pipih di bidang XY lokal, menghadap `normal_local`
## (bawaan +Z). Dipakai untuk mulut, lencana, dan tanda lain yang datar.
func polygon(xf: Transform3D, pts: PackedVector2Array, color: Color,
		normal_local: Vector3 = Vector3(0.0, 0.0, 1.0)) -> void:
	if pts.size() < 3:
		return
	var nb: Basis = xf.basis.inverse().transposed()
	var wn: Vector3 = nb * normal_local
	var centroid := Vector2.ZERO
	for p: Vector2 in pts:
		centroid += p
	centroid /= float(pts.size())
	var c: int = _vert(xf * Vector3(centroid.x, centroid.y, 0.0), wn, color)
	var ring := PackedInt32Array()
	for p2: Vector2 in pts:
		ring.append(_vert(xf * Vector3(p2.x, p2.y, 0.0), wn, color))
	for k in ring.size():
		_tri(c, ring[k], ring[(k + 1) % ring.size()])


## Segi empat datar a-b-c-d (berurutan keliling) satu warna, menghadap `normal`.
## Dipakai bidang lebar seperti atap dan jalan.
func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, color: Color) -> void:
	quad_colors(a, b, c, d, normal, [color, color, color, color])


## Seperti quad(), dengan warna per sudut (a, b, c, d) untuk gradasi.
func quad_colors(a: Vector3, b: Vector3, c: Vector3, d: Vector3, normal: Vector3, colors: Array) -> void:
	var ia: int = _vert(a, normal, colors[0])
	var ib: int = _vert(b, normal, colors[1])
	var ic: int = _vert(c, normal, colors[2])
	var id: int = _vert(d, normal, colors[3])
	_tri(ia, ib, ic)
	_tri(ia, ic, id)


## Segitiga datar menghadap `normal` (ujung atap pelana).
func triangle(a: Vector3, b: Vector3, c: Vector3, normal: Vector3, color: Color) -> void:
	_tri(_vert(a, normal, color), _vert(b, normal, color), _vert(c, normal, color))


## Warna verteks memudar ke `to` menurut jarak datar dari `center`: utuh sampai
## `start` meter, lalu naik linear sampai `max_t` pada `end` dan sesudahnya.
## Kejauhan lingkungan luar toko menyatu dengan warna latar (GDD 32.5).
func fade_to(center: Vector3, start: float, end: float, to: Color, max_t: float) -> void:
	for k in _v.size():
		var p: Vector3 = _v[k]
		var dist: float = Vector2(p.x - center.x, p.z - center.z).length()
		var t: float = clampf((dist - start) / maxf(end - start, 0.001), 0.0, 1.0) * max_t
		if t > 0.0:
			_c[k] = _c[k].lerp(to, t)


## Semua verteks yang sudah dirakit (untuk tes).
func vertices() -> PackedVector3Array:
	return _v


## Cakram datar menghadap +Y dengan gradasi pusat -> tepi (bayangan kaki).
func disc(xf: Transform3D, radius: float, center_color: Color, rim_color: Color, segs: int) -> void:
	var nb: Basis = xf.basis.inverse().transposed()
	var up: Vector3 = nb * Vector3.UP
	var c: int = _vert(xf * Vector3.ZERO, up, center_color)
	var ring := PackedInt32Array()
	for k in segs:
		var a: float = TAU * float(k) / float(segs)
		ring.append(_vert(xf * Vector3(sin(a) * radius, 0.0, -cos(a) * radius), up, rim_color))
	for k2 in segs:
		_tri(c, ring[k2], ring[(k2 + 1) % segs])


# ===========================================================================
# HASIL
# ===========================================================================

## Satu MeshInstance3D dengan material bersama. Builder kosong menghasilkan node
## tanpa mesh (tetap bernama, supaya kontrak node terpenuhi).
func commit(node_name: String, finish: StringName = MATTE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("tris", tri_count())
	if _i.is_empty():
		mi.set_meta("aabb", AABB())
		return mi
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _v
	arrays[Mesh.ARRAY_NORMAL] = _n
	arrays[Mesh.ARRAY_COLOR] = _c
	arrays[Mesh.ARRAY_INDEX] = _i
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mi.mesh = mesh
	mi.material_override = material(finish)
	mi.set_meta("aabb", AABB(_min, _max - _min))
	return mi


## Material bersama untuk semua karakter: warna datang dari verteks (sRGB,
## sama dengan nilai Palette), jadi ribuan bagian berbagi segelintir material.
static func material(finish: StringName) -> StandardMaterial3D:
	if _materials.has(finish):
		return _materials[finish]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	match finish:
		SATIN:
			m.roughness = 0.42
			m.metallic = 0.25
		SHADOW:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			m.disable_receive_shadows = true
		SIGN:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
			m.disable_receive_shadows = true
		_:
			m.roughness = 0.86
	_materials[finish] = m
	return m


static func clear_materials() -> void:
	_materials.clear()


## Basis tangan-kanan dengan sumbu Y lokal = `y_axis` (untuk kapsul/lathe miring).
static func frame_y(y_axis: Vector3) -> Basis:
	var y: Vector3 = y_axis.normalized()
	var helper: Vector3 = Vector3.FORWARD if absf(y.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
	var x: Vector3 = helper.cross(y).normalized()
	var z: Vector3 = x.cross(y).normalized()
	return Basis(x, y, z)


# ===========================================================================
# INTERNAL
# ===========================================================================

func _vert(p: Vector3, n: Vector3, c: Color) -> int:
	_v.append(p)
	_n.append(n.normalized())
	_c.append(c)
	_min = _min.min(p)
	_max = _max.max(p)
	return _v.size() - 1


## Segitiga dengan orientasi otomatis: sisi depan (searah jarum jam di Godot)
## selalu menghadap ke arah normal verteksnya. Segitiga nol (kutub) dilewati.
func _tri(a: int, b: int, c: int) -> void:
	var f: Vector3 = (_v[b] - _v[a]).cross(_v[c] - _v[a])
	if f.length_squared() < 1e-16:
		return
	if f.dot(_n[a] + _n[b] + _n[c]) > 0.0:
		_i.append(a)
		_i.append(c)
		_i.append(b)
	else:
		_i.append(a)
		_i.append(b)
		_i.append(c)


## Jahit baris-baris verteks menjadi pita segi empat. `wrap_row` menyambung
## ujung tiap baris (bentuk tertutup), `wrap_rows` menyambung baris terakhir ke
## baris pertama (torus penuh).
func _stitch(rows: Array[PackedInt32Array], wrap_row: bool, wrap_rows: bool = false) -> void:
	var count: int = rows.size()
	var last: int = count if wrap_rows else count - 1
	for r in last:
		var a: PackedInt32Array = rows[r]
		var b: PackedInt32Array = rows[(r + 1) % count]
		var w: int = a.size()
		var cols: int = w if wrap_row else w - 1
		for j in cols:
			var j2: int = (j + 1) % w
			_tri(a[j], a[j2], b[j2])
			_tri(a[j], b[j2], b[j])
