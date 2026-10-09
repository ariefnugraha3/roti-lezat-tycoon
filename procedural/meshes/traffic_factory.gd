class_name TrafficFactory
extends RefCounted
## Kendaraan yang lalu-lalang dan diparkir di luar toko (keputusan maintainer
## 2026-10-09, GDD 32.7): skuter matik, ojol, sepeda dan onthel, gerobak bakso
## yang didorong, mobil kompak, sedan dan mobil mewah, angkot, van, bus kota,
## becak, dan mobil antik.
##
## Bentuknya mainan yang membulat: kotak bersudut bulat (`MeshBuilder.rounded_box`),
## kapsul, elipsoid, dan roda lathe berpelek, berukuran dunia chibi. Pengendara,
## pembonceng, pengayuh becak, dan pedagang gerobak adalah model karakter yang
## sama dengan pembeli (`CharacterFactory`), diberi pose lalu "dipanggang" ke mesh
## kendaraan (`MeshBuilder.append_arrays`), jadi satu kendaraan tetap satu mesh
## berwarna verteks dengan material MATTE bersama (satu draw call, tanpa
## kombinasi shader baru). Sepeda, becak, dan gerobak punya beberapa bingkai
## (kaki mengayuh atau melangkah) yang dipilih StreetLife.
##
## Depan model menghadap -Z lokal dan alasnya di y = 0. `detail` 0 dipakai
## kendaraan parkir yang ikut mesh jalan (lebih sedikit segitiga), 1 kendaraan
## yang lewat.

## Ukuran (m) dan kecepatan nyata (m/s) tiap jenis: `length`/`width`/`height`
## untuk jarak antar-kendaraan, `bob` = ayun naik-turun saat melaju,
## `variants` = jumlah varian warna/pengendara, `frames` = bingkai gerak kaki
## (1 = diam), `stride` = jarak tempuh (m) per satu putaran kayuh atau langkah.
const KINDS: Dictionary = {
	&"motor": {"speed": Vector2(4.0, 5.2), "length": 1.05, "width": 0.52, "height": 1.24, "bob": 0.012, "variants": 4, "frames": 1},
	&"motor_pair": {"speed": Vector2(3.8, 4.8), "length": 1.1, "width": 0.52, "height": 1.2, "bob": 0.012, "variants": 3, "frames": 1},
	&"ojol": {"speed": Vector2(4.2, 5.4), "length": 1.05, "width": 0.52, "height": 1.2, "bob": 0.012, "variants": 3, "frames": 1},
	&"bicycle": {"speed": Vector2(2.0, 2.6), "length": 1.08, "width": 0.52, "height": 1.16, "bob": 0.006, "variants": 3, "frames": 4, "stride": 1.25},
	&"onthel": {"speed": Vector2(1.8, 2.3), "length": 1.1, "width": 0.52, "height": 1.18, "bob": 0.006, "variants": 3, "frames": 4, "stride": 1.3},
	&"gerobak": {"speed": Vector2(0.8, 1.0), "length": 1.9, "width": 0.74, "height": 1.36, "bob": 0.004, "variants": 3, "frames": 4, "stride": 0.8},
	&"car": {"speed": Vector2(5.0, 6.4), "length": 2.8, "width": 1.32, "height": 0.98, "bob": 0.004, "variants": 4, "frames": 1},
	&"luxury": {"speed": Vector2(4.6, 5.8), "length": 3.05, "width": 1.34, "height": 0.84, "bob": 0.003, "variants": 4, "frames": 1},
	&"angkot": {"speed": Vector2(4.2, 5.2), "length": 3.15, "width": 1.22, "height": 1.22, "bob": 0.006, "variants": 3, "frames": 1},
	&"van": {"speed": Vector2(4.4, 5.4), "length": 3.15, "width": 1.22, "height": 1.16, "bob": 0.005, "variants": 2, "frames": 1},
	&"bus": {"speed": Vector2(3.8, 4.6), "length": 6.7, "width": 1.72, "height": 1.97, "bob": 0.004, "variants": 2, "frames": 1},
	&"becak": {"speed": Vector2(1.5, 2.0), "length": 1.5, "width": 1.0, "height": 1.36, "bob": 0.006, "variants": 4, "frames": 4, "stride": 1.1},
	&"vintage": {"speed": Vector2(3.4, 4.4), "length": 2.35, "width": 1.18, "height": 0.97, "bob": 0.006, "variants": 4, "frames": 1},
}
## Kaca mobil: biru batu yang tetap terbaca sebagai kaca di bawah cahaya hangat.
const GLASS: Color = Color(0.44, 0.54, 0.65)
const LAMP: Color = Color(1.0, 0.95, 0.74)
## Tinggi jok skuter (pinggul karakter chibi yang duduk) dan permukaan pijakan
## kakinya.
const SEAT_Y: float = 0.45
const SCOOTER_FLOOR: float = 0.317
## Sepeda: tinggi sadel, posisi pinggul pengayuh, dan jari-jari engkol. As pedal
## ada tepat di telapak kaki chibi yang lurus (kakinya tidak bertekuk).
const BIKE_SEAT_Y: float = 0.42
const BIKE_RIDER_Z: float = 0.09
const CRANK: float = 0.045
const PEDAL_METAL: Color = Color(0.62, 0.61, 0.6)
## Kursi pengayuh becak dan pinggulnya (z, tinggi duduk).
const BECAK_RIDER: Vector2 = Vector2(0.45, 0.62)
## Pose (radian dari pose istirahat): lengan memegang setang, kaki di pijakan
## skuter, lengan mendorong gerobak, lengan dan kaki pembonceng.
const RIDE_ARM: float = 1.3
const RIDE_LEG: float = 0.82
const PUSH_ARM: float = 1.45
const PASSENGER_ARM: float = 0.9
const PASSENGER_LEG: float = 0.9
const PASSENGER_SPLAY: float = 0.6
## Kaki pengayuh: sudut rata-rata yang menentukan letak as pedal. Tiap bingkai
## kakinya diarahkan tepat ke pedalnya.
const PEDAL_LEG: float = 0.6


static func info(kind: StringName) -> Dictionary:
	return KINDS.get(kind, KINDS[&"car"])


static func frames(kind: StringName) -> int:
	return int(info(kind).get("frames", 1))


## Mesh kendaraan `kind` varian `variant` (bingkai `frame`), utuh atau dipudarkan
## seragam ke `Palette.BG` sebesar `fade`.
static func build(kind: StringName, variant: int, rain: bool, fade: float, frame: int = 0) -> MeshInstance3D:
	var p: Dictionary = plan(kind, variant, rain)
	while not plan_step(p):
		pass
	var arr: Array = frame_arrays(p, frame)
	var mi := MeshInstance3D.new()
	mi.name = String(kind)
	mi.mesh = mesh_from(arr, fade)
	mi.material_override = MeshBuilder.material(MeshBuilder.MATTE)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("tris", (arr[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3)
	return mi


## ArrayMesh dari isi `src` dengan warna verteks dipudarkan seragam ke
## `Palette.BG` sebesar `fade` (sama dengan pudar jalan di bawahnya).
static func mesh_from(src: Array, fade: float) -> ArrayMesh:
	var out: Array = src.duplicate()
	var t: float = clampf(fade, 0.0, 1.0)
	if t > 0.0:
		var c: PackedColorArray = (src[Mesh.ARRAY_COLOR] as PackedColorArray).duplicate()
		for i in c.size():
			c[i] = c[i].lerp(Palette.BG, t)
		out[Mesh.ARRAY_COLOR] = c
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, out)
	return mesh


## Rencana rakitan satu kendaraan (jenis, varian, hujan): isi bodi yang diam,
## pedal yang berputar, dan pengendara yang sudah dipose untuk tiap bingkai.
## Bagian mahalnya dibuat sekali: bodi di sini, lalu satu pengendara per
## `plan_step` (model karakter, ~5 ms di desktop), supaya satu frame tidak
## menanggung semuanya. Tiap bingkai lalu disusun murah oleh `frame_arrays`.
## Tanpa node dan tanpa mesh GPU, jadi StreetLife bisa menyimpannya sementara.
static func plan(kind: StringName, variant: int, rain: bool) -> Dictionary:
	var mb := MeshBuilder.new()
	var v: int = posmod(variant, int(info(kind)["variants"]))
	var n: int = frames(kind)
	var pedals: Array = []
	var jobs: Array = []
	var o := Transform3D.IDENTITY
	match kind:
		&"motor", &"motor_pair", &"ojol":
			var bodies: Array[Color] = [Palette.STRAWBERRY, Palette.SIGN_BLUE, Palette.FLOUR_WHITE.darkened(0.04), Palette.HONEY]
			var body: Color = bodies[v % bodies.size()]
			if kind == &"ojol":
				body = Palette.TIRE.lightened(0.14) if v != 1 else Palette.FLOUR_WHITE.darkened(0.04)
			scooter(mb, o, body, 1)
			if kind == &"motor_pair":
				jobs.append([_rider_spec(&"customer_generic", v, rain, "helm"), _at(Vector3(0.0, 0.0, 0.04)), "ride", SEAT_Y, 1])
				var back: StringName = &"customer_school_child" if v % 2 == 0 else &"customer_bulk_buyer"
				jobs.append([_rider_spec(back, v + 7, rain, "helm"), _at(Vector3(0.0, 0.0, 0.33)), "passenger", SEAT_Y + 0.02, 1])
			elif kind == &"ojol":
				jobs.append([_rider_spec(&"driver_rotifood", v, rain, ""), _at(Vector3(0.0, 0.0, 0.06)), "ride", SEAT_Y, 1])
			else:
				var looks: Array[StringName] = [&"customer_office_worker", &"customer_generic", &"customer_school_child", &"customer_snob"]
				jobs.append([_rider_spec(looks[v % looks.size()], v, rain, "helm"), _at(Vector3(0.0, 0.0, 0.06)), "ride", SEAT_Y, 1])
		&"bicycle", &"onthel":
			var onthel: bool = kind == &"onthel"
			var paints: Array[Color] = [Palette.SIGN_BLUE, Palette.STRAWBERRY, Palette.MATCHA]
			if onthel:
				paints = [Palette.MATCHA_DEEP, Palette.ROSY_CHEEK, Palette.CABLE.lightened(0.12)]
			bicycle(mb, o, paints[v % paints.size()], onthel, NAN, 1)
			var bike_bb: Vector3 = _bb(BIKE_RIDER_Z, BIKE_SEAT_Y)
			pedals.append({"xf": o, "bb": bike_bb})
			var who: StringName = &"customer_school_child" if not onthel and v == 0 else &"customer_generic"
			jobs.append([_rider_spec(who, v + 3, rain, "topi_pet" if onthel else ""), _at(Vector3(0.0, 0.0, BIKE_RIDER_Z)), "pedal", BIKE_SEAT_Y, n,
				bike_bb - Vector3(0.0, 0.0, BIKE_RIDER_Z)])
		&"gerobak":
			var carts: Array[Color] = [Palette.SIGN_BLUE, Palette.SIGN_RED, Palette.SIGN_GREEN]
			o = _at(Vector3(0.0, 0.0, -0.17))
			gerobak(mb, o, carts[v % carts.size()], 1)
			jobs.append([_rider_spec(&"customer_generic", v + 11, rain, "peci"), o * _at(Vector3(0.0, 0.0, 0.9)), "push", 0.0, n])
		&"car":
			var cars: Array[Color] = [Palette.SIGN_RED, Palette.SIGN_BLUE, Palette.FLOUR_WHITE.darkened(0.04), Palette.MATCHA]
			car(mb, o, cars[v % cars.size()], v % 2, 1)
		&"luxury":
			var lux: Array[Color] = [Palette.TIRE.lightened(0.04), Palette.FLOUR_WHITE, Palette.STRAWBERRY_DEEP.darkened(0.3), Palette.CABLE.lightened(0.42)]
			car(mb, o, lux[v % lux.size()], 2, 1)
		&"angkot":
			var ak: Array[Color] = [Palette.HOUSE_SKY.darkened(0.28), Palette.SIGN_GREEN, Palette.SIGN_ORANGE]
			boxy(mb, o, ak[v % ak.size()], true, 1)
		&"van":
			boxy(mb, o, Palette.FLOUR_WHITE if v == 0 else Palette.BUTTER_YELLOW, false, 1)
		&"bus":
			bus(mb, o, Palette.SIGN_BLUE if v == 0 else Palette.SIGN_ORANGE, 1)
		&"becak":
			var bk: Array[Color] = [Palette.SIGN_BLUE, Palette.SIGN_RED, Palette.MATCHA, Palette.HONEY]
			o = _at(Vector3(0.0, 0.0, -0.1))
			becak(mb, o, bk[v % bk.size()], NAN, 1)
			var becak_bb: Vector3 = _bb(BECAK_RIDER.x, BECAK_RIDER.y)
			pedals.append({"xf": o, "bb": becak_bb})
			jobs.append([_rider_spec(&"customer_generic", v + 5, rain, "topi_pet"), o * _at(Vector3(0.0, 0.0, BECAK_RIDER.x)), "pedal", BECAK_RIDER.y, n,
				becak_bb - Vector3(0.0, 0.0, BECAK_RIDER.x)])
			if v % 2 == 0:
				var guest: StringName = &"customer_bulk_buyer" if v == 0 else &"customer_snob"
				jobs.append([_rider_spec(guest, v + 9, rain, ""), o * _at(Vector3(0.0, 0.0, -0.17)), "seat", 0.44, 1])
		&"vintage":
			vintage(mb, o, v, 1)
		_:
			car(mb, o, Palette.SIGN_RED, 0, 1)
	return {"kind": kind, "frames": n, "body": mb.arrays(), "body_tris": mb.tri_count(), "pedals": pedals, "riders": [], "jobs": jobs}


## Rakit satu pengendara rencana `p` yang belum jadi. true bila rencana sudah
## lengkap (tidak ada lagi yang perlu dirakit).
static func plan_step(p: Dictionary) -> bool:
	var jobs: Array = p["jobs"]
	if not jobs.is_empty():
		var j: Array = jobs.pop_front()
		(p["riders"] as Array).append(_rig(j[0], j[1], j[2], float(j[3]), int(j[4]), j[5] if j.size() > 5 else Vector3.ZERO))
	return jobs.is_empty()


static func plan_ready(p: Dictionary) -> bool:
	return (p["jobs"] as Array).is_empty()


## Isi mesh bingkai `frame` dari rencana `p`: bodi, pedal pada sudut bingkai
## itu, dan pengendara dalam posenya.
static func frame_arrays(p: Dictionary, frame: int) -> Array:
	var pedals: Array = p["pedals"]
	var riders: Array = p["riders"]
	if pedals.is_empty() and riders.is_empty():
		return p["body"]
	var n: int = maxi(int(p["frames"]), 1)
	var f: int = posmod(frame, n)
	var mb := MeshBuilder.new()
	mb.append_arrays(p["body"], Transform3D.IDENTITY)
	for pd: Dictionary in pedals:
		_pedals(mb, pd["xf"], pd["bb"], TAU * float(f) / float(n), PEDAL_METAL)
	for r: Dictionary in riders:
		var rows: Array = r["xfs"]
		var row: Array = rows[f % rows.size()]
		var parts: Array = r["parts"]
		for i in parts.size():
			if row[i] != null:
				mb.append_arrays(parts[i], row[i])
	return mb.arrays()


static func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


## Kotak bersudut bulat (`k` >= 1) atau kotak biasa (`k` 0, detail rendah).
static func _rb(mb: MeshBuilder, xf: Transform3D, c: Vector3, size: Vector3, r: float, color: Color, k: int) -> void:
	if k <= 0:
		mb.box(xf * _at(c), size, color)
	else:
		mb.rounded_box(xf * _at(c), size, r, color, k)


static func _box(mb: MeshBuilder, xf: Transform3D, c: Vector3, size: Vector3, color: Color) -> void:
	mb.box(xf * _at(c), size, color)


## Roda mobil: ban gemuk dan pelek menonjol dalam satu lathe, pelek hanya di sisi
## luar (`side` -1 = sisi kiri, menghadap -X).
static func _wheel(mb: MeshBuilder, xf: Transform3D, c: Vector3, radius: float, width: float, rim: Color, side: float, radial: int) -> void:
	var w: float = width * 0.5
	var rr: float = radius * 0.56
	var prof := PackedVector2Array([Vector2(radius, -w), Vector2(radius, w), Vector2(rr, w), Vector2(rr, w + 0.012), Vector2(0.0, w + 0.012)])
	var fn := func(y: float, _phi: float) -> Color: return rim if y > w + 0.006 else Palette.TIRE
	var b := Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5 if side < 0.0 else -PI * 0.5)
	mb.lathe(xf * Transform3D(b, c), prof, Palette.TIRE, radial, fn)


## Roda tunggal di tengah (skuter): pelek di kedua sisi. Detail rendah: ban
## membulat saja.
static func _wheel2(mb: MeshBuilder, xf: Transform3D, c: Vector3, radius: float, width: float, rim: Color, detail: int) -> void:
	var w: float = width * 0.5
	var b := Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5)
	if detail == 0:
		var lo := PackedVector2Array([Vector2(0.0, -w), Vector2(radius, -w), Vector2(radius, w), Vector2(0.0, w)])
		mb.lathe(xf * Transform3D(b, c), lo, Palette.TIRE, 8)
		return
	var rr: float = radius * 0.56
	var e: float = 0.01
	var prof := PackedVector2Array([Vector2(0.0, -w - e), Vector2(rr, -w - e), Vector2(rr, -w), Vector2(radius, -w),
		Vector2(radius, w), Vector2(rr, w), Vector2(rr, w + e), Vector2(0.0, w + e)])
	var fn := func(y: float, _phi: float) -> Color: return rim if absf(y) > w + e * 0.5 else Palette.TIRE
	mb.lathe(xf * Transform3D(b, c), prof, Palette.TIRE, 10, fn)


## Roda sepeda: ban tipis melingkar dan (detail 1) tromol kecil; poros sepanjang X.
static func _ring(mb: MeshBuilder, xf: Transform3D, c: Vector3, radius: float, tube: float, hub: Color, detail: int) -> void:
	var wxf: Transform3D = xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), c)
	mb.torus(wxf, radius - tube, tube, Palette.TIRE, 10 if detail == 0 else 14, 3)
	if detail > 0:
		mb.cylinder(wxf, 0.05, 0.024, 0.024, hub, 6)


# ===========================================================================
# RODA DUA
# ===========================================================================

## Skuter matik chibi: pelindung kaki, kepala setang berlampu, spion, pijakan
## kaki, jok, bodi belakang membulat, lampu rem, dan knalpot. Jok setinggi
## SEAT_Y; setang tepat di depan perut pengendara (tangan chibi pendek).
## Detail 0 (motor parkir, ~300 segitiga): bentuk utama yang sama, tanpa
## pernak-pernik kecil.
static func scooter(mb: MeshBuilder, xf: Transform3D, body: Color, detail: int = 1) -> void:
	var lo: bool = detail == 0
	var kp: int = 0 if lo else 1
	var metal: Color = Palette.CABLE.lightened(0.5)
	var dark: Color = Palette.CABLE.lightened(0.05)
	for wz: float in [-0.38, 0.36]:
		_wheel2(mb, xf, Vector3(0.0, 0.14, wz), 0.14, 0.08, metal, detail)
	# Pijakan kaki, bodi belakang, jok, dan lengan ayun.
	_rb(mb, xf, Vector3(0.0, SCOOTER_FLOOR - 0.025, -0.12), Vector3(0.26, 0.05, 0.4), 0.02, dark, kp)
	_rb(mb, xf, Vector3(0.0, 0.33, 0.2), Vector3(0.32, 0.26, 0.5), 0.11, body, 1 if lo else 2)
	_rb(mb, xf, Vector3(0.0, 0.468, 0.14), Vector3(0.26, 0.06, 0.44), 0.028, Palette.DARK_CHOCOLATE.darkened(0.25), kp)
	_rb(mb, xf, Vector3(0.0, 0.2, 0.33), Vector3(0.12, 0.07, 0.24), 0.03, dark, kp)
	# Pelindung kaki dan kepala setang.
	var shield := Transform3D(Basis(Vector3.RIGHT, -0.16), Vector3(0.0, 0.43, -0.31))
	if lo:
		mb.box(xf * shield, Vector3(0.32, 0.36, 0.09), body)
	else:
		mb.rounded_box(xf * shield, Vector3(0.32, 0.36, 0.09), 0.04, body, 1)
	mb.ellipsoid(xf * _at(Vector3(0.0, 0.625, -0.24)), Vector3(0.13, 0.065, 0.1), body, 6 if lo else 10, 3 if lo else 5)
	if lo:
		_box(mb, xf, Vector3(0.0, 0.635, -0.335), Vector3(0.1, 0.06, 0.03), LAMP)
		_box(mb, xf, Vector3(0.0, 0.62, -0.16), Vector3(0.4, 0.025, 0.025), Palette.TIRE)
		_box(mb, xf, Vector3(0.0, 0.36, 0.452), Vector3(0.12, 0.05, 0.03), Palette.STRAWBERRY)
		return
	mb.ellipsoid(xf * _at(Vector3(0.0, 0.635, -0.335)), Vector3(0.06, 0.045, 0.025), LAMP, 8, 3)
	# Spakbor depan dan garpu.
	mb.ellipsoid(xf * _at(Vector3(0.0, 0.235, -0.38)), Vector3(0.062, 0.045, 0.15), body, 8, 4)
	mb.capsule(xf * Vector3(0.0, 0.14, -0.38), xf * Vector3(0.0, 0.4, -0.33), 0.016, 0.016, metal, 6, 1)
	# Setang, pegangan, dan spion.
	mb.capsule(xf * Vector3(-0.19, 0.62, -0.16), xf * Vector3(0.19, 0.62, -0.16), 0.013, 0.013, metal, 6, 1)
	for sx: float in [-1.0, 1.0]:
		mb.capsule(xf * Vector3(sx * 0.13, 0.62, -0.16), xf * Vector3(sx * 0.2, 0.62, -0.16), 0.02, 0.02, Palette.TIRE, 6, 1)
		mb.capsule(xf * Vector3(sx * 0.11, 0.63, -0.18), xf * Vector3(sx * 0.16, 0.74, -0.2), 0.007, 0.007, metal, 4, 1)
		mb.ellipsoid(xf * _at(Vector3(sx * 0.165, 0.75, -0.2)), Vector3(0.032, 0.022, 0.012), dark, 6, 2)
	# Lampu rem, pelat, knalpot.
	mb.ellipsoid(xf * _at(Vector3(0.0, 0.36, 0.452)), Vector3(0.07, 0.03, 0.02), Palette.STRAWBERRY, 8, 3)
	_box(mb, xf, Vector3(0.0, 0.25, 0.48), Vector3(0.14, 0.05, 0.01), Palette.TIRE)
	mb.capsule(xf * Vector3(0.11, 0.15, 0.18), xf * Vector3(0.11, 0.19, 0.47), 0.03, 0.024, metal.darkened(0.15), 6, 1)


## Sepeda chibi: dua roda tipis, rangka tabung, sadel, setang melengkung ke
## belakang sampai tangan pengayuh, engkol dan pedal (bila `phase` bukan NAN;
## rencana StreetLife menambahkannya per bingkai). Onthel: rangka rendah,
## keranjang rotan di depan, dan boncengan.
static func bicycle(mb: MeshBuilder, xf: Transform3D, paint: Color, onthel: bool, phase: float = NAN, detail: int = 1) -> void:
	var metal: Color = Palette.CABLE.lightened(0.5)
	var cr: int = 4 if detail == 0 else 6
	var r: float = 0.19
	var front := Vector3(0.0, r, -0.36)
	var rear := Vector3(0.0, r, 0.34)
	_ring(mb, xf, front, r, 0.018, metal, detail)
	_ring(mb, xf, rear, r, 0.018, metal, detail)
	var bb: Vector3 = _bb(BIKE_RIDER_Z, BIKE_SEAT_Y)
	var seat := Vector3(0.0, BIKE_SEAT_Y - 0.03, BIKE_RIDER_Z - 0.01)
	var head_lo := Vector3(0.0, 0.42, -0.27)
	var head_hi := Vector3(0.0, 0.52, -0.25)
	var t: float = 0.016
	mb.capsule(xf * bb, xf * seat, t, t, paint, cr, 1)
	mb.capsule(xf * bb, xf * head_lo, t, t, paint, cr, 1)
	mb.capsule(xf * head_lo, xf * head_hi, t * 1.2, t * 1.2, paint, cr, 1)
	if onthel:
		mb.capsule(xf * (bb + Vector3(0.0, 0.03, -0.02)), xf * (head_lo + Vector3(0.0, 0.03, 0.0)), t, t, paint, cr, 1)
	else:
		mb.capsule(xf * (seat + Vector3(0.0, -0.03, -0.01)), xf * head_hi, t, t, paint, cr, 1)
	for sx: float in [-0.025, 0.025]:
		mb.capsule(xf * (bb + Vector3(sx, 0.0, 0.0)), xf * (rear + Vector3(sx, 0.0, 0.0)), t * 0.75, t * 0.75, paint, cr - 1, 1)
		mb.capsule(xf * (seat + Vector3(sx, -0.02, 0.0)), xf * (rear + Vector3(sx, 0.0, 0.0)), t * 0.75, t * 0.75, paint, cr - 1, 1)
	mb.capsule(xf * head_lo, xf * front, t, t, paint, cr, 1)
	# Setang melengkung ke belakang dan pegangannya.
	var stem := Vector3(0.0, 0.6, -0.22)
	mb.capsule(xf * head_hi, xf * stem, 0.012, 0.012, metal, cr - 1, 1)
	for sx2: float in [-1.0, 1.0]:
		var grip := Vector3(sx2 * 0.15, 0.59, -0.1)
		mb.capsule(xf * (stem + Vector3(sx2 * 0.04, 0.0, 0.0)), xf * grip, 0.01, 0.01, metal, cr - 1, 1)
		if detail > 0:
			mb.capsule(xf * grip, xf * (grip + Vector3(0.0, -0.005, 0.05)), 0.016, 0.016, Palette.TIRE, 5, 1)
	_rb(mb, xf, seat + Vector3(0.0, 0.022, 0.0), Vector3(0.1, 0.035, 0.17), 0.016, Palette.DARK_CHOCOLATE.darkened(0.2), mini(detail, 1))
	if not is_nan(phase):
		_pedals(mb, xf, bb, phase, metal)
	# Pelindung rantai; onthel: keranjang dan boncengan.
	_rb(mb, xf, Vector3(0.045, bb.y - 0.01, (bb.z + rear.z) * 0.5), Vector3(0.016, 0.07, rear.z - bb.z + 0.06), 0.008, paint.darkened(0.2), mini(detail, 1))
	if onthel:
		_rb(mb, xf, Vector3(0.0, 0.49, -0.4), Vector3(0.22, 0.11, 0.15), 0.03, Palette.HONEY.darkened(0.2), mini(detail, 1))
		_box(mb, xf, Vector3(0.0, 0.43, 0.32), Vector3(0.12, 0.016, 0.2), metal)
		mb.capsule(xf * Vector3(0.0, 0.43, 0.42), xf * rear, 0.008, 0.008, metal, 4, 1)


## As pedal: tempat telapak kaki chibi yang duduk di `seat_y` dengan pinggul di
## z `rider_z`, kaki condong PEDAL_LEG (kaki sepanjang ~0,21 m sampai tengah
## sepatu).
static func _bb(rider_z: float, seat_y: float) -> Vector3:
	var hip: float = seat_y + ProceduralAnimationSystem.SIT_HIP_LIFT
	return Vector3(0.0, hip - 0.21 * cos(PEDAL_LEG), rider_z - 0.21 * sin(PEDAL_LEG))


## Dua engkol dan pedal di as `bb`, berputar menurut `phase` (pedal kiri di
## puncak pada fase 0, di depan pada fase PI/2, seperti kaki kirinya).
static func _pedals(mb: MeshBuilder, xf: Transform3D, bb: Vector3, phase: float, metal: Color) -> void:
	for side in 2:
		var a: float = phase + PI * float(side)
		var sx: float = -0.06 if side == 0 else 0.06
		var pedal := Vector3(sx, bb.y + CRANK * cos(a), bb.z - CRANK * sin(a))
		mb.capsule(xf * Vector3(sx * 0.6, bb.y, bb.z), xf * pedal, 0.009, 0.009, metal, 4, 1)
		_box(mb, xf, pedal + Vector3(sx * 0.35, 0.0, 0.0), Vector3(0.05, 0.014, 0.04), Palette.TIRE)


# ===========================================================================
# GEROBAK DAN BECAK
# ===========================================================================

## Gerobak bakso seukuran chibi: lemari kayu dengan etalase kaca dan dandang,
## atap kanopi berpapan nama, dua roda, kaki penyangga, dan gagang dorong di
## belakang (+Z) setinggi tangan pedagang yang berjalan di belakangnya (z 0,9).
static func gerobak(mb: MeshBuilder, xf: Transform3D, color: Color, detail: int = 1) -> void:
	var k: int = 1 if detail == 0 else 2
	var kp: int = mini(detail, 1)
	var metal: Color = Palette.CABLE.lightened(0.55)
	_rb(mb, xf, Vector3(0.0, 0.47, -0.15), Vector3(0.56, 0.34, 1.0), 0.05, color, k)
	_rb(mb, xf, Vector3(0.0, 0.47, -0.15), Vector3(0.575, 0.06, 1.015), 0.02, Palette.FLOUR_WHITE, kp)
	_rb(mb, xf, Vector3(0.0, 0.655, -0.15), Vector3(0.62, 0.03, 1.06), 0.012, Palette.FLOUR_WHITE, kp)
	_rb(mb, xf, Vector3(0.0, 0.79, -0.32), Vector3(0.46, 0.24, 0.54), 0.03, GLASS.lightened(0.25), kp)
	mb.cylinder(xf * _at(Vector3(0.0, 0.8, 0.12)), 0.26, 0.12, 0.12, metal, 8 if detail == 0 else 10)
	mb.ellipsoid(xf * _at(Vector3(0.0, 0.93, 0.12)), Vector3(0.12, 0.04, 0.12), metal.darkened(0.1), 8 if detail == 0 else 10, 2 if detail == 0 else 3)
	for sx: float in [-0.27, 0.27]:
		for sz: float in [-0.6, 0.3]:
			if detail == 0:
				_box(mb, xf, Vector3(sx, 0.98, sz), Vector3(0.024, 0.64, 0.024), Palette.FLOUR_WHITE.darkened(0.08))
			else:
				mb.capsule(xf * Vector3(sx, 0.66, sz), xf * Vector3(sx, 1.3, sz), 0.012, 0.012, Palette.FLOUR_WHITE.darkened(0.08), 4, 1)
	_rb(mb, xf, Vector3(0.0, 1.32, -0.15), Vector3(0.74, 0.05, 1.18), 0.025, Palette.SIGN_YELLOW, k)
	_rb(mb, xf, Vector3(0.0, 1.23, -0.72), Vector3(0.6, 0.14, 0.025), 0.01, Palette.FLOUR_WHITE, kp)
	_box(mb, xf, Vector3(0.0, 1.23, -0.736), Vector3(0.44, 0.05, 0.006), color)
	for sx2: float in [-1.0, 1.0]:
		_wheel(mb, xf, Vector3(sx2 * 0.32, 0.16, -0.38), 0.16, 0.05, Palette.FLOUR_WHITE.darkened(0.1), sx2, 8 if detail == 0 else 10)
	mb.capsule(xf * Vector3(0.0, 0.3, 0.28), xf * Vector3(0.0, 0.06, 0.28), 0.02, 0.02, Palette.TIRE, 4 if detail == 0 else 5, 1)
	for hx: float in [-0.15, 0.15]:
		mb.capsule(xf * Vector3(hx, 0.52, 0.33), xf * Vector3(hx, 0.45, 0.72), 0.018, 0.018, Palette.DOOR_WOOD, 4 if detail == 0 else 6, 1)


## Becak: kursi penumpang berkap di depan dengan dua roda, sepeda pengayuh di
## belakang dengan setang di punggung kursi, pedal bila `phase` bukan NAN.
## Ukurannya untuk penumpang chibi yang duduk di z -0,17 dan pengayuh di
## BECAK_RIDER.
static func becak(mb: MeshBuilder, xf: Transform3D, color: Color, phase: float = NAN, detail: int = 1) -> void:
	var lo: bool = detail == 0
	var k: int = 1 if lo else 2
	var kp: int = 0 if lo else 1
	var cr: int = 4 if lo else 6
	var metal: Color = Palette.CABLE.lightened(0.45)
	var hood: Color = Palette.CABLE.lightened(0.14)
	# Kursi penumpang, bantal, sandaran, dan sandaran tangan.
	_rb(mb, xf, Vector3(0.0, 0.28, -0.2), Vector3(0.8, 0.24, 0.42), 0.06, color, k)
	_rb(mb, xf, Vector3(0.0, 0.42, -0.19), Vector3(0.72, 0.05, 0.36), 0.022, Palette.STRAWBERRY_DEEP, kp)
	_rb(mb, xf, Vector3(0.0, 0.64, 0.0), Vector3(0.8, 0.5, 0.08), 0.035, color, 1)
	_rb(mb, xf, Vector3(0.0, 0.62, -0.045), Vector3(0.7, 0.34, 0.03), 0.015, Palette.STRAWBERRY_DEEP, kp)
	for sx: float in [-0.4, 0.4]:
		_rb(mb, xf, Vector3(sx, 0.48, -0.18), Vector3(0.06, 0.18, 0.4), 0.025, color, kp)
	_box(mb, xf, Vector3(0.0, 0.15, -0.5), Vector3(0.6, 0.03, 0.2), color.darkened(0.25))
	# Kap kain seperti kap kereta bayi: kubah yang terbuka di depan, dengan lapisan
	# dalam yang lebih gelap supaya bagian dalamnya tidak tembus pandang.
	var hc: Transform3D = xf * _at(Vector3(0.0, 0.84, -0.12))
	var hr := Vector3(0.44, 0.44, 0.36)
	var cut := func(phi: float) -> float: return lerpf(0.55, PI * 0.5, (1.0 - cos(phi)) * 0.5)
	var hseg: int = 8 if lo else 14
	mb.ellipsoid(hc, hr, hood, hseg, 4 if lo else 5, Callable(), cut)
	var inner: Vector2i = mb.mark()
	mb.ellipsoid(hc, hr * 0.97, hood.darkened(0.3), hseg, 4 if lo else 5, Callable(), cut)
	mb.flip_since(inner)
	# Roda depan dan spakbornya.
	for wx: float in [-0.47, 0.47]:
		_ring(mb, xf, Vector3(wx, 0.2, -0.25), 0.2, 0.024, metal, detail)
		_box(mb, xf, Vector3(wx, 0.42, -0.25), Vector3(0.06, 0.02, 0.3), color.darkened(0.15))
	# Sepeda pengayuh: sadel, rangka, roda belakang, setang, engkol.
	var bb: Vector3 = _bb(BECAK_RIDER.x, BECAK_RIDER.y)
	var saddle := Vector3(0.0, BECAK_RIDER.y - 0.03, BECAK_RIDER.x - 0.01)
	var rear := Vector3(0.0, 0.2, 0.68)
	_ring(mb, xf, rear, 0.2, 0.024, metal, detail)
	var frame_c: Color = color.darkened(0.25)
	mb.capsule(xf * Vector3(0.0, 0.3, 0.04), xf * bb, 0.026, 0.026, frame_c, cr, 1)
	mb.capsule(xf * Vector3(0.0, 0.2, 0.02), xf * rear, 0.022, 0.022, frame_c, cr, 1)
	mb.capsule(xf * bb, xf * saddle, 0.02, 0.02, frame_c, cr, 1)
	mb.capsule(xf * saddle, xf * rear, 0.016, 0.016, frame_c, cr - 1, 1)
	mb.capsule(xf * bb, xf * rear, 0.016, 0.016, frame_c, cr - 1, 1)
	_rb(mb, xf, saddle + Vector3(0.0, 0.022, 0.0), Vector3(0.11, 0.035, 0.17), 0.016, Palette.TIRE, kp)
	for hx: float in [-0.15, 0.15]:
		mb.capsule(xf * Vector3(hx, 0.84, 0.04), xf * Vector3(hx, 0.8, 0.26), 0.012, 0.012, metal, cr - 1, 1)
	mb.capsule(xf * Vector3(-0.2, 0.8, 0.26), xf * Vector3(0.2, 0.8, 0.26), 0.014, 0.014, metal, cr, 1)
	if not is_nan(phase):
		_pedals(mb, xf, bb, phase, metal)


# ===========================================================================
# MOBIL
# ===========================================================================

## Mobil mainan: bodi bawah membulat, kabin kaca bersudut bulat dengan atap dan
## pilar sewarna bodi, lampu, gril, bemper, pelat, spion, garis pintu, dan roda
## besar berpelek. `style` 0 = kompak (hatchback), 1 = sedan, 2 = mewah
## (panjang, rendah, lis krom).
static func car(mb: MeshBuilder, xf: Transform3D, body: Color, style: int, detail: int = 1) -> void:
	var st: int = clampi(style, 0, 2)
	var lo: bool = detail == 0
	var k: int = 1 if lo else 2
	var kp: int = 0 if lo else 1
	var length: float = [2.4, 2.65, 2.9][st]
	var width: float = 1.18 if st != 2 else 1.2
	var wr: float = 0.22 if st != 2 else 0.21
	var bot: float = 0.15
	var body_h: float = [0.44, 0.4, 0.36][st]
	var top: float = bot + body_h
	var cab_len: float = [1.5, 1.25, 1.3][st]
	var cab_z: float = [0.22, 0.1, 0.16][st]
	var cab_h: float = [0.38, 0.35, 0.31][st]
	var metal: Color = Palette.CABLE.lightened(0.55)
	var wz: float = length * 0.5 - 0.44
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_wheel(mb, xf, Vector3(sx * (width * 0.5 - 0.09), wr, sz * wz), wr, 0.16, metal, sx, 8 if lo else 10)
	_rb(mb, xf, Vector3(0.0, bot + body_h * 0.5, 0.0), Vector3(width, body_h, length), 0.17 if st == 0 else 0.15, body, k)
	# Kabin kaca, atap, dan pilar.
	var cy: float = top + cab_h * 0.5 - 0.05
	_rb(mb, xf, Vector3(0.0, cy, cab_z), Vector3(width - 0.12, cab_h + 0.05, cab_len), 0.13, GLASS, k)
	_rb(mb, xf, Vector3(0.0, top + cab_h - 0.025, cab_z), Vector3(width - 0.17, 0.06, cab_len - 0.16), 0.025, body, kp)
	var px: float = (width - 0.12) * 0.5 + 0.002
	for sx2: float in [-1.0, 1.0]:
		for pz: float in [cab_z - cab_len * 0.5 + 0.1, cab_z + 0.05, cab_z + cab_len * 0.5 - 0.1]:
			_box(mb, xf, Vector3(sx2 * px, cy + 0.01, pz), Vector3(0.02, cab_h - 0.05, 0.055), body)
		_rb(mb, xf, Vector3(sx2 * (width * 0.5 + 0.035), top + 0.03, cab_z - cab_len * 0.5 + 0.06), Vector3(0.07, 0.05, 0.08), 0.02, body, kp)
		_box(mb, xf, Vector3(sx2 * (width * 0.5 + 0.001), bot + body_h * 0.5, cab_z + 0.05), Vector3(0.006, body_h * 0.7, 0.012), body.darkened(0.25))
		if not lo:
			_box(mb, xf, Vector3(sx2 * (width * 0.5 + 0.003), bot + body_h * 0.68, cab_z + 0.2), Vector3(0.01, 0.02, 0.08), metal)
		if st == 2:
			_box(mb, xf, Vector3(sx2 * (width * 0.5 + 0.004), bot + 0.11, 0.0), Vector3(0.008, 0.024, length - 0.5), metal)
	# Depan: lampu, gril, bemper, pelat. Belakang: lampu rem, bemper, pelat.
	var fz: float = -length * 0.5
	for lx: float in [-0.36, 0.36]:
		mb.ellipsoid(xf * _at(Vector3(lx, bot + body_h * 0.62, fz + 0.02)), Vector3(0.11, 0.06, 0.03), LAMP, 6 if lo else 8, 2 if lo else 3)
		mb.ellipsoid(xf * _at(Vector3(lx * 1.05, bot + body_h * 0.66, -fz - 0.02)), Vector3(0.09, 0.05, 0.025), Palette.STRAWBERRY, 6 if lo else 8, 2 if lo else 3)
	_box(mb, xf, Vector3(0.0, bot + body_h * 0.42, fz - 0.003), Vector3(0.42, 0.08, 0.02), Palette.CABLE)
	for bz: float in [fz - 0.02, -fz + 0.02]:
		_rb(mb, xf, Vector3(0.0, bot + 0.06, bz), Vector3(width + 0.02, 0.1, 0.1), 0.04, Palette.CABLE.lightened(0.2), kp)
		_box(mb, xf, Vector3(0.0, bot + 0.1, bz + signf(bz) * 0.055), Vector3(0.28, 0.07, 0.01), Palette.TIRE)


## Van antar atau angkot: bodi tinggi membulat, moncong pendek, kaca depan
## miring, kaca samping, roda, lampu. Angkot: kaca keliling, garis putih, pintu
## samping terbuka, rak atap.
static func boxy(mb: MeshBuilder, xf: Transform3D, body: Color, angkot: bool, detail: int = 1) -> void:
	var lo: bool = detail == 0
	var k: int = 1 if lo else 2
	var kp: int = 0 if lo else 1
	var length: float = 3.0
	var width: float = 1.2
	var metal: Color = Palette.CABLE.lightened(0.55)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_wheel(mb, xf, Vector3(sx * (width * 0.5 - 0.1), 0.21, sz * (length * 0.5 - 0.5)), 0.21, 0.16, metal, sx, 8 if lo else 10)
	_rb(mb, xf, Vector3(0.0, 0.68, 0.08), Vector3(width, 0.94, length - 0.16), 0.15, body, k)
	_rb(mb, xf, Vector3(0.0, 0.42, -length * 0.5 + 0.24), Vector3(width - 0.02, 0.44, 0.5), 0.13, body, 1)
	var screen := Transform3D(Basis(Vector3.RIGHT, 0.3), Vector3(0.0, 0.88, -length * 0.5 + 0.47))
	if lo:
		mb.box(xf * screen, Vector3(width - 0.16, 0.34, 0.05), GLASS)
	else:
		mb.rounded_box(xf * screen, Vector3(width - 0.16, 0.34, 0.05), 0.03, GLASS, 1)
	if angkot:
		_rb(mb, xf, Vector3(0.0, 0.92, 0.18), Vector3(width + 0.012, 0.28, length - 0.75), 0.06, GLASS, kp)
		_rb(mb, xf, Vector3(0.0, 0.66, 0.08), Vector3(width + 0.014, 0.07, length - 0.2), 0.03, Palette.FLOUR_WHITE, kp)
		for sx2: float in [-1.0, 1.0]:
			_box(mb, xf, Vector3(sx2 * (width * 0.5 + 0.004), 0.58, 0.32), Vector3(0.012, 0.56, 0.42), Palette.TIRE.lightened(0.1))
		for rz: float in [-0.6, 0.25, 1.1]:
			_box(mb, xf, Vector3(0.0, 1.17, rz), Vector3(width - 0.3, 0.035, 0.05), metal)
		for rx: float in [-0.45, 0.45]:
			_box(mb, xf, Vector3(rx, 1.19, 0.25), Vector3(0.04, 0.035, 1.8), metal)
	else:
		for sx3: float in [-1.0, 1.0]:
			_rb(mb, xf, Vector3(sx3 * (width * 0.5 + 0.004), 0.92, -length * 0.5 + 0.86), Vector3(0.012, 0.26, 0.5), 0.04, GLASS, kp)
			_box(mb, xf, Vector3(sx3 * (width * 0.5 + 0.003), 0.55, 0.55), Vector3(0.01, 0.12, 1.5), Palette.SIGN_RED if body.get_luminance() > 0.9 else Palette.SIGN_BLUE)
		_rb(mb, xf, Vector3(0.0, 0.85, length * 0.5 - 0.06), Vector3(width - 0.3, 0.26, 0.012), 0.03, GLASS, kp)
	var fz: float = -length * 0.5
	for lx: float in [-0.38, 0.38]:
		mb.ellipsoid(xf * _at(Vector3(lx, 0.46, fz + 0.01)), Vector3(0.1, 0.06, 0.03), LAMP, 6 if lo else 8, 2 if lo else 3)
		mb.ellipsoid(xf * _at(Vector3(lx, 0.55, -fz + 0.01)), Vector3(0.07, 0.07, 0.025), Palette.STRAWBERRY, 6 if lo else 8, 2 if lo else 3)
	for bz: float in [fz - 0.01, -fz + 0.02]:
		_rb(mb, xf, Vector3(0.0, 0.24, bz), Vector3(width + 0.02, 0.1, 0.1), 0.04, Palette.CABLE.lightened(0.2), kp)
		_box(mb, xf, Vector3(0.0, 0.29, bz + signf(bz) * 0.055), Vector3(0.28, 0.07, 0.01), Palette.TIRE)


## Bus kota: bodi panjang membulat dua warna, pita kaca memanjang, kaca depan
## besar, pintu, roda besar.
static func bus(mb: MeshBuilder, xf: Transform3D, top: Color, detail: int = 1) -> void:
	var k: int = 1 if detail == 0 else 2
	var length: float = 6.6
	var width: float = 1.7
	var metal: Color = Palette.CABLE.lightened(0.55)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-2.2, 2.0]:
			_wheel(mb, xf, Vector3(sx * (width * 0.5 - 0.14), 0.28, sz), 0.28, 0.2, metal, sx, 8 if detail == 0 else 10)
	_rb(mb, xf, Vector3(0.0, 1.13, 0.0), Vector3(width, 1.66, length), 0.2, top, k)
	_rb(mb, xf, Vector3(0.0, 0.62, 0.0), Vector3(width + 0.012, 0.56, length - 0.06), 0.16, Palette.FLOUR_WHITE.darkened(0.04), 1)
	_rb(mb, xf, Vector3(0.0, 1.38, 0.3), Vector3(width + 0.014, 0.5, length - 1.0), 0.1, GLASS, 1)
	_rb(mb, xf, Vector3(0.0, 1.3, -length * 0.5 + 0.01), Vector3(width - 0.2, 0.74, 0.04), 0.05, GLASS, 1)
	for sx2: float in [-1.0, 1.0]:
		_box(mb, xf, Vector3(sx2 * (width * 0.5 + 0.007), 1.0, -length * 0.5 + 0.85), Vector3(0.012, 1.1, 0.55), Palette.CABLE)
	for lx: float in [-0.6, 0.6]:
		mb.ellipsoid(xf * _at(Vector3(lx, 0.6, -length * 0.5 - 0.005)), Vector3(0.12, 0.07, 0.03), LAMP, 8, 3)
		mb.ellipsoid(xf * _at(Vector3(lx, 0.7, length * 0.5 + 0.005)), Vector3(0.08, 0.1, 0.03), Palette.STRAWBERRY, 8, 3)
	_box(mb, xf, Vector3(0.0, 1.86, -length * 0.5 - 0.004), Vector3(0.9, 0.16, 0.01), Palette.TIRE)


## Mobil antik membulat berwarna pastel (VW kodok): dasar membulat, kubah kabin
## berpita kaca, empat spakbor gembung, lampu bulat di spakbor depan, bemper
## krom.
static func vintage(mb: MeshBuilder, xf: Transform3D, v: int, detail: int = 1) -> void:
	var bodies: Array[Color] = [Palette.PASTEL_MINT.darkened(0.12), Palette.BUTTER_YELLOW, Palette.PASTEL_PERIWINKLE.darkened(0.08), Palette.ROSY_CHEEK]
	var body: Color = bodies[posmod(v, bodies.size())]
	var k: int = 1 if detail == 0 else 2
	var chrome: Color = Palette.FLOUR_WHITE.darkened(0.1)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-0.74, 0.72]:
			_wheel(mb, xf, Vector3(sx * 0.46, 0.2, sz), 0.2, 0.14, chrome, sx, 8 if detail == 0 else 10)
			mb.ellipsoid(xf * _at(Vector3(sx * 0.47, 0.34, sz)), Vector3(0.13, 0.15, 0.3), body.darkened(0.06), 10, 4)
	_rb(mb, xf, Vector3(0.0, 0.33, 0.0), Vector3(0.96, 0.3, 2.2), 0.14, body, k)
	# Kubah kabin dan pita kacanya: kolom segi pita sejajar dengan kubah dan
	# sedikit di luarnya, supaya tepinya rapi.
	var dome: Transform3D = xf * _at(Vector3(0.0, 0.46, 0.06))
	var dr := Vector3(0.47, 0.5, 0.76)
	var half := func(_phi: float) -> float: return PI * 0.5
	mb.ellipsoid(dome, dr, body, 14, 6, Callable(), half)
	var band := func(_phi: float) -> float: return 1.12
	mb.shell(dome, dr * 1.015, GLASS, 0.0, TAU, 14, 3, 0.5, band)
	var post := func(_phi: float) -> float: return 1.16
	for ph: float in [PI * 0.25, PI * 0.75, PI * 1.25, PI * 1.75]:
		mb.shell(dome, dr * 1.025, body, ph - 0.08, ph + 0.08, 1, 3, 0.46, post)
	for lx: float in [-0.33, 0.33]:
		mb.ellipsoid(xf * _at(Vector3(lx, 0.46, -0.96)), Vector3(0.07, 0.07, 0.04), LAMP, 8, 3)
		mb.ellipsoid(xf * _at(Vector3(lx * 1.1, 0.42, 1.02)), Vector3(0.05, 0.06, 0.03), Palette.STRAWBERRY, 6, 3)
	for bz: float in [-1.13, 1.13]:
		_rb(mb, xf, Vector3(0.0, 0.2, bz), Vector3(1.04, 0.06, 0.06), 0.025, chrome, 1)


# ===========================================================================
# PENGENDARA: model karakter yang sama dengan pembeli
# ===========================================================================

## Rupa pengendara: spec pembeli (atau driver ojol) varian `v`, dengan helm atau
## topi, tanpa barang bawaan, dan berjas hujan saat hujan.
static func _rider_spec(look: StringName, v: int, rain: bool, hat: String) -> Dictionary:
	var spec: Dictionary = CharacterFactory.spec_for_customer(String(look), 4099 + v * 97 + String(look).length(), rain)
	if hat != "":
		spec["hat"] = hat
	if look != &"driver_rotifood":
		spec["prop"] = PackedStringArray()
		if rain:
			var acc := PackedStringArray(spec.get("accessory", PackedStringArray()))
			if not acc.has("jas_hujan"):
				acc.append("jas_hujan")
			spec["accessory"] = acc
	return spec


## Model karakter yang sama dengan pembeli, berpose untuk tiap bingkai, tanpa
## node: isi mesh tiap bagiannya (ruang lokal bagian) dan transform bagian itu
## per bingkai (null = bagian tersembunyi). Modelnya dibangun sekali dalam mode
## tangkap MeshBuilder (tanpa unggah dan baca balik GPU), lalu dibebaskan.
## pose: "ride" (memegang setang, kaki di pijakan), "passenger" (dibonceng),
## "seat" (duduk di kursi), "pedal" (mengayuh), "push" (melangkah sambil
## mendorong). `count` bingkai merata sepanjang satu putaran.
static func _rig(spec: Dictionary, xf: Transform3D, pose: String, seat_y: float, count: int, bb: Vector3 = Vector3.ZERO) -> Dictionary:
	MeshBuilder.capture = true
	var model: Node3D = CharacterFactory.build(spec)
	MeshBuilder.capture = false
	var nodes: Array[MeshInstance3D] = []
	var parts: Array = []
	var names: PackedStringArray = PackedStringArray()
	for nd: Node in model.find_children("*", "MeshInstance3D", true, false):
		var mi: MeshInstance3D = nd
		if mi.has_meta("arrays") and StringName(mi.get_meta("finish", MeshBuilder.MATTE)) == MeshBuilder.MATTE:
			nodes.append(mi)
			parts.append(mi.get_meta("arrays"))
			names.append(String(mi.name))
	var rows: Array = []
	var c: int = maxi(count, 1)
	for f in c:
		_pose(model, pose, TAU * float(f) / float(c), seat_y, bb)
		var row: Array = []
		for mi2: MeshInstance3D in nodes:
			row.append(xf * _model_xf(mi2, model) if _shown(mi2, model) else null)
		rows.append(row)
	model.free()
	return {"parts": parts, "names": names, "xfs": rows, "spec": spec, "pose": pose}


## `bb` (pose "pedal"): as pedal relatif terhadap titik asal pengayuh.
static func _pose(model: Node3D, pose: String, phase: float, seat_y: float, bb: Vector3 = Vector3.ZERO) -> void:
	if pose == "push":
		ProceduralAnimationSystem.walk_cycle(model, phase, 1.0)
		_limbs(model, ["ArmL", "ArmR"], PUSH_ARM)
		return
	ProceduralAnimationSystem.sit(model, 0.0, seat_y, true)
	match pose:
		"ride":
			_limbs(model, ["ArmL", "ArmR"], RIDE_ARM)
			_limbs(model, ["LegL", "LegR"], RIDE_LEG)
		"passenger":
			_limbs(model, ["ArmL", "ArmR"], PASSENGER_ARM)
			_limbs(model, ["LegL", "LegR"], PASSENGER_LEG)
			for i in 2:
				var leg: Node3D = ProceduralAnimationSystem._part(model, "LegL" if i == 0 else "LegR")
				if leg != null:
					leg.rotation.z = ProceduralAnimationSystem._rest_rot(leg).z + PASSENGER_SPLAY * (-1.0 if i == 0 else 1.0)
		"pedal":
			_limbs(model, ["ArmL", "ArmR"], RIDE_ARM)
			# Kaki chibi tidak bertekuk: tiap kaki diarahkan dari pinggul ke pedalnya.
			var hip_y: float = seat_y + ProceduralAnimationSystem.SIT_HIP_LIFT
			for i2 in 2:
				var leg2: Node3D = ProceduralAnimationSystem._part(model, "LegL" if i2 == 0 else "LegR")
				if leg2 != null:
					var a: float = phase + PI * float(i2)
					var pz: float = bb.z - CRANK * sin(a)
					var py: float = bb.y + CRANK * cos(a)
					leg2.rotation.x = ProceduralAnimationSystem._rest_rot(leg2).x + atan2(-pz, hip_y - py)


## Putar bagian-bagian `names` ke `angle` radian (sumbu X) dari pose istirahatnya.
static func _limbs(model: Node3D, names: Array, angle: float) -> void:
	for nm: Variant in names:
		var part: Node3D = ProceduralAnimationSystem._part(model, str(nm))
		if part != null:
			part.rotation.x = ProceduralAnimationSystem._rest_rot(part).x + angle


## Node tampak bila ia dan semua induknya sampai `root` terlihat (model belum
## masuk pohon scene, jadi is_visible_in_tree() tidak bisa dipakai).
static func _shown(n: Node, root: Node) -> bool:
	var cur: Node = n
	while cur != null:
		if cur is Node3D and not (cur as Node3D).visible:
			return false
		if cur == root:
			return true
		cur = cur.get_parent()
	return true


## Transform node `n` relatif terhadap induk model `root` (termasuk transform
## root itu sendiri: tinggi duduk dan skala tinggi badan).
static func _model_xf(n: Node, root: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		if cur == root:
			break
		cur = cur.get_parent()
	return t
