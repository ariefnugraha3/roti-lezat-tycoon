class_name TrafficFactory
extends RefCounted
## Kendaraan yang lalu-lalang di luar toko (keputusan maintainer 2026-10-09,
## GDD 32.7): motor dan ojol berpengendara, sepeda dan onthel, gerobak bakso yang
## didorong, mobil, mobil mewah, angkot, van, bus kota, becak, dan mobil antik.
##
## Satu kendaraan = satu mesh berwarna verteks dengan material MATTE bersama
## (MeshBuilder), jadi tidak ada kombinasi shader baru. Pengendaranya bagian dari
## mesh yang sama. Depan model menghadap -Z lokal dan alasnya di y = 0. Mesh bisa
## dipudarkan seragam ke `Palette.BG` (`fade`) supaya menyatu dengan jalan yang
## memudar di kejauhan (GDD 32.5).

## Ukuran (m) dan kecepatan nyata (m/s) tiap jenis: `length`/`width`/`height`
## dipakai untuk jarak antar-kendaraan dan cek tidak menutupi toko, `bob` = ayun
## naik-turun saat melaju, `variants` = jumlah varian warna.
const KINDS: Dictionary = {
	&"motor": {"speed": Vector2(4.0, 5.2), "length": 1.25, "width": 0.64, "height": 1.52, "bob": 0.012, "variants": 4},
	&"motor_pair": {"speed": Vector2(3.8, 4.8), "length": 1.25, "width": 0.64, "height": 1.52, "bob": 0.012, "variants": 3},
	&"ojol": {"speed": Vector2(4.2, 5.4), "length": 1.25, "width": 0.64, "height": 1.52, "bob": 0.012, "variants": 3},
	&"bicycle": {"speed": Vector2(2.0, 2.6), "length": 1.25, "width": 0.52, "height": 1.62, "bob": 0.01, "variants": 3},
	&"onthel": {"speed": Vector2(1.8, 2.3), "length": 1.25, "width": 0.52, "height": 1.66, "bob": 0.01, "variants": 3},
	&"gerobak": {"speed": Vector2(0.8, 1.0), "length": 2.3, "width": 0.92, "height": 1.8, "bob": 0.006, "variants": 3},
	&"car": {"speed": Vector2(5.0, 6.4), "length": 2.85, "width": 1.2, "height": 1.0, "bob": 0.004, "variants": 4},
	&"luxury": {"speed": Vector2(4.6, 5.8), "length": 2.85, "width": 1.2, "height": 1.0, "bob": 0.003, "variants": 4},
	&"angkot": {"speed": Vector2(4.2, 5.2), "length": 3.15, "width": 1.25, "height": 1.38, "bob": 0.006, "variants": 3},
	&"van": {"speed": Vector2(4.4, 5.4), "length": 3.15, "width": 1.25, "height": 1.24, "bob": 0.005, "variants": 2},
	&"bus": {"speed": Vector2(3.8, 4.6), "length": 6.9, "width": 1.72, "height": 2.26, "bob": 0.004, "variants": 2},
	&"becak": {"speed": Vector2(1.5, 2.0), "length": 2.1, "width": 1.22, "height": 1.78, "bob": 0.008, "variants": 4},
	&"vintage": {"speed": Vector2(3.4, 4.4), "length": 2.5, "width": 1.12, "height": 1.08, "bob": 0.006, "variants": 4},
}
## Pusat jauh untuk pudar seragam: semua verteks berjarak sama jauhnya.
const FAR: Vector3 = Vector3(1.0e5, 0.0, 1.0e5)


static func info(kind: StringName) -> Dictionary:
	return KINDS.get(kind, KINDS[&"car"])


## Mesh kendaraan `kind` varian `variant`; `rain` = pengendara berjas hujan,
## `fade` = 0 (utuh) sampai 1 (warna latar).
static func build(kind: StringName, variant: int, rain: bool, fade: float) -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var v: int = posmod(variant, int(info(kind)["variants"]))
	match kind:
		&"motor", &"motor_pair", &"ojol":
			_motor(mb, kind, v, rain)
		&"bicycle", &"onthel":
			_cyclist(mb, kind == &"onthel", v, rain)
		&"gerobak":
			_gerobak(mb, v, rain)
		&"luxury":
			var lux: Array[Color] = [Palette.TIRE, Palette.FLOUR_WHITE, Palette.STRAWBERRY_DEEP.darkened(0.35), Palette.MATCHA_DEEP.darkened(0.35)]
			NeighborhoodFactory._car(mb, Vector3.ZERO, 0.0, lux[v % lux.size()])
		&"angkot":
			_angkot(mb, v)
		&"van":
			NeighborhoodFactory._van(mb, Vector3.ZERO, 0.0, Palette.FLOUR_WHITE if v == 0 else Palette.BUTTER_YELLOW)
		&"bus":
			_bus(mb, v)
		&"becak":
			_becak(mb, v, rain)
		&"vintage":
			_vintage(mb, v)
		_:
			var cars: Array[Color] = [Palette.SIGN_RED, Palette.FLOUR_WHITE.darkened(0.06), Palette.CABLE.lightened(0.15), Palette.PASTEL_PERIWINKLE.darkened(0.3)]
			NeighborhoodFactory._car(mb, Vector3.ZERO, 0.0, cars[v % cars.size()])
	if fade > 0.0:
		mb.fade_to(FAR, 0.0, 0.001, Palette.BG, clampf(fade, 0.0, 1.0))
	var mi: MeshInstance3D = mb.commit(String(kind))
	return mi


# ===========================================================================
# PENGENDARA
# ===========================================================================

## Pengendara duduk menghadap -Z: pinggul di `hip`, tangan di `hands`, kaki di
## `feet` (kiri lalu kanan). `helmet` = warna helm, atau transparan untuk rambut
## (pesepeda). Saat hujan bajunya jas hujan berponco.
static func _rider(mb: MeshBuilder, hip: Vector3, hands: Array, feet: Array, look: Dictionary, rain: bool) -> void:
	var jacket: Color = look["jacket"]
	var pants: Color = look["pants"]
	var skin: Color = look["skin"]
	var helmet: Color = look["helmet"]
	if rain:
		jacket = look.get("raincoat", Palette.RAINCOAT_YELLOW)
	var shoulder: Vector3 = hip + Vector3(0.0, 0.34, -0.07)
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var h: Vector3 = hip + Vector3(side * 0.08, 0.0, 0.0)
		var f: Vector3 = feet[i]
		var knee: Vector3 = (h + f) * 0.5 + Vector3(side * 0.03, 0.12, -0.1)
		mb.capsule(h, knee, 0.065, 0.055, pants, 6, 1)
		mb.capsule(knee, f, 0.055, 0.05, pants, 6, 1)
		mb.ellipsoid(Transform3D(Basis.IDENTITY, f + Vector3(0.0, -0.01, -0.04)), Vector3(0.06, 0.04, 0.09), Palette.TIRE, 6, 3)
		var s: Vector3 = shoulder + Vector3(side * 0.13, -0.03, 0.0)
		var hand: Vector3 = hands[i]
		mb.capsule(s, hand, 0.05, 0.045, jacket, 6, 1)
		mb.ellipsoid(Transform3D(Basis.IDENTITY, hand), Vector3.ONE * 0.045, skin, 6, 3)
	mb.capsule(hip + Vector3(0.0, 0.05, 0.0), shoulder, 0.15, 0.13, jacket, 8, 2)
	if rain:
		# Ponco: jubah lebar yang menutupi badan dan pangkuan.
		mb.ellipsoid(Transform3D(Basis.IDENTITY, hip + Vector3(0.0, 0.2, -0.02)), Vector3(0.22, 0.24, 0.26), jacket.darkened(0.06), 8, 4)
	var head: Vector3 = shoulder + Vector3(0.0, 0.23, -0.02)
	mb.ellipsoid(Transform3D(Basis.IDENTITY, head), Vector3(0.18, 0.17, 0.17), skin, 10, 6)
	var cap: Color = helmet
	if cap.a < 0.5:
		cap = look["hair"]
	var front: float = 1.05 if helmet.a >= 0.5 else 0.95
	var back: float = 1.95 if helmet.a >= 0.5 else 1.7
	mb.ellipsoid(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.025, 0.012)), Vector3(0.195, 0.185, 0.19), cap, 10, 5,
		Callable(), func(phi: float) -> float: return lerpf(front, back, (1.0 - cos(phi)) * 0.5))
	if rain and helmet.a < 0.5:
		# Tudung jas hujan untuk pesepeda.
		mb.ellipsoid(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.03, 0.02)), Vector3(0.205, 0.19, 0.2), jacket, 10, 5,
			Callable(), func(phi: float) -> float: return lerpf(1.1, 1.9, (1.0 - cos(phi)) * 0.5))


## Rupa pengendara varian `v` (warna baju, helm, kulit, rambut).
static func _look(v: int, helmet: Color, jacket: Color = Color(0, 0, 0, 0)) -> Dictionary:
	var skins: Array[Color] = CharacterFactory._skin_tones()
	var hairs: Array[Color] = CharacterFactory._hair_tones()
	var cloths: Array[Color] = [Palette.PASTEL_PERIWINKLE.darkened(0.15), Palette.ROSY_CHEEK, Palette.HONEY, Palette.APRON_NAVY, Palette.PASTEL_MINT.darkened(0.15)]
	var pants: Array[Color] = CharacterFactory._pants_tones()
	var coats: Array[Color] = [Palette.RAINCOAT_YELLOW, Palette.SIGN_BLUE, Palette.STRAWBERRY, Palette.PASTEL_MINT.darkened(0.1)]
	return {
		"jacket": jacket if jacket.a > 0.5 else cloths[v % cloths.size()],
		"raincoat": coats[v % coats.size()],
		"pants": pants[(v + 1) % pants.size()],
		"shoes": Palette.TIRE,
		"skin": skins[(v * 3 + 1) % skins.size()],
		"hair": hairs[(v * 2) % mini(3, hairs.size())],
		"helmet": helmet,
	}


# ===========================================================================
# KENDARAAN
# ===========================================================================

## Motor bebek berpengendara; `motor_pair` membonceng satu orang, `ojol` berjaket
## dan berhelm hijau, sebagian membawa kotak pesanan.
static func _motor(mb: MeshBuilder, kind: StringName, v: int, rain: bool) -> void:
	var bodies: Array[Color] = [Palette.STRAWBERRY, Palette.SIGN_BLUE, Palette.TIRE, Palette.FLOUR_WHITE.darkened(0.1)]
	var helmets: Array[Color] = [Palette.FLOUR_WHITE, Palette.SIGN_RED, Palette.TIRE, Palette.BUTTER_YELLOW]
	var body: Color = bodies[v % bodies.size()]
	var look: Dictionary = _look(v, helmets[v % helmets.size()])
	if kind == &"ojol":
		body = Palette.TIRE if v != 1 else Palette.FLOUR_WHITE.darkened(0.1)
		look = _look(v + 2, Palette.OJOL_GREEN, Palette.OJOL_GREEN)
		look["raincoat"] = Palette.OJOL_GREEN.darkened(0.2)
	NeighborhoodFactory._motorbike(mb, Vector3.ZERO, 0.0, body)
	var hands: Array = [Vector3(-0.26, 0.93, -0.4), Vector3(0.26, 0.93, -0.4)]
	var feet: Array = [Vector3(-0.12, 0.34, -0.14), Vector3(0.12, 0.34, -0.14)]
	_rider(mb, Vector3(0.0, 0.73, 0.16), hands, feet, look, rain)
	if kind == &"motor_pair" or (kind == &"ojol" and v == 2):
		var p_look: Dictionary = _look(v + 3, Palette.OJOL_GREEN if kind == &"ojol" else Palette.PASTEL_PERIWINKLE)
		var p_hands: Array = [Vector3(-0.15, 0.86, 0.2), Vector3(0.15, 0.86, 0.2)]
		var p_feet: Array = [Vector3(-0.17, 0.36, 0.3), Vector3(0.17, 0.36, 0.3)]
		_rider(mb, Vector3(0.0, 0.76, 0.46), p_hands, p_feet, p_look, rain)
	elif kind == &"ojol":
		# Kotak pesanan di jok belakang.
		mb.box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.98, 0.5)), Vector3(0.42, 0.36, 0.36), Palette.OJOL_GREEN.darkened(0.12))
		mb.box(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.17, 0.5)), Vector3(0.44, 0.03, 0.38), Palette.FLOUR_WHITE)


## Pesepeda (onthel = sepeda tua berwarna pastel, pengendara bertopi caping lebar).
static func _cyclist(mb: MeshBuilder, onthel: bool, v: int, rain: bool) -> void:
	var frames: Array[Color] = [Palette.SIGN_BLUE, Palette.TIRE, Palette.STRAWBERRY]
	if onthel:
		frames = [Palette.ROSY_CHEEK, Palette.PASTEL_MINT, Palette.BUTTER_YELLOW]
	NeighborhoodFactory._bicycle(mb, Vector3.ZERO, 0.0, frames[v % frames.size()])
	var look: Dictionary = _look(v + 1, Color(0, 0, 0, 0))
	var hands: Array = [Vector3(-0.21, 0.96, -0.36), Vector3(0.21, 0.96, -0.36)]
	var feet: Array = [Vector3(-0.12, 0.3, -0.06), Vector3(0.12, 0.46, 0.12)]
	_rider(mb, Vector3(0.0, 0.9, 0.14), hands, feet, look, rain)
	if onthel and not rain:
		# Topi lebar khas pesepeda wisata.
		mb.cylinder(Transform3D(Basis.IDENTITY, Vector3(0.0, 1.62, 0.07)), 0.06, 0.13, 0.3, Palette.HONEY.lightened(0.25), 10)


## Gerobak bakso didorong pedagang yang berjalan di belakangnya.
static func _gerobak(mb: MeshBuilder, v: int, rain: bool) -> void:
	var bodies: Array[Color] = [Palette.SIGN_BLUE, Palette.SIGN_RED, Palette.SIGN_GREEN]
	NeighborhoodFactory._cart(mb, Vector3.ZERO, -PI * 0.5, bodies[v % bodies.size()])
	var look: Dictionary = _look(v + 4, Color(0, 0, 0, 0))
	var hip := Vector3(0.0, 0.62, 1.32)
	var hands: Array = [Vector3(-0.24, 0.84, 1.0), Vector3(0.24, 0.84, 1.0)]
	# Kaki melangkah: satu maju, satu tertinggal.
	var feet: Array = [Vector3(-0.09, 0.04, 1.12), Vector3(0.09, 0.04, 1.55)]
	var jacket: Color = Palette.RAINCOAT_YELLOW if rain else Palette.FLOUR_WHITE.darkened(0.04)
	var shoulder: Vector3 = hip + Vector3(0.0, 0.42, -0.04)
	for i in 2:
		var side: float = -1.0 if i == 0 else 1.0
		var hp: Vector3 = hip + Vector3(side * 0.08, 0.0, 0.0)
		mb.capsule(hp, feet[i], 0.065, 0.05, look["pants"] as Color, 6, 1)
		mb.ellipsoid(Transform3D(Basis.IDENTITY, (feet[i] as Vector3) + Vector3(0.0, 0.03, -0.04)), Vector3(0.06, 0.04, 0.09), Palette.TIRE, 6, 3)
		mb.capsule(shoulder + Vector3(side * 0.13, -0.03, 0.0), hands[i], 0.05, 0.045, jacket, 6, 1)
	mb.capsule(hip + Vector3(0.0, 0.04, 0.0), shoulder, 0.15, 0.13, jacket, 8, 2)
	var head: Vector3 = shoulder + Vector3(0.0, 0.23, -0.02)
	mb.ellipsoid(Transform3D(Basis.IDENTITY, head), Vector3(0.18, 0.17, 0.17), look["skin"] as Color, 10, 6)
	# Topi pedagang.
	mb.cylinder(Transform3D(Basis.IDENTITY, head + Vector3(0.0, 0.15, 0.0)), 0.1, 0.16, 0.19, Palette.TIRE if not rain else Palette.RAINCOAT_YELLOW.darkened(0.1), 10)


## Angkot: minibus berjendela keliling, garis putih, pintu samping terbuka, dan
## rak atap.
static func _angkot(mb: MeshBuilder, v: int) -> void:
	var bodies: Array[Color] = [Palette.HOUSE_SKY.darkened(0.28), Palette.SIGN_GREEN, Palette.SIGN_ORANGE]
	var body: Color = bodies[v % bodies.size()]
	var s: float = NeighborhoodFactory.CAR_SCALE
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	var glass: Color = Palette.WINDOW_GLASS.darkened(0.2)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 1.05, 0.0)), Vector3(1.8, 1.5, 4.6), body)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 1.45, -0.1)), Vector3(1.83, 0.42, 3.9), glass)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 1.45, -2.31)), Vector3(1.6, 0.5, 0.04), glass)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 0.92, 0.0)), Vector3(1.84, 0.12, 4.62), Palette.FLOUR_WHITE)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.92, 1.0, 0.2)), Vector3(0.02, 1.1, 0.75), Palette.CABLE)
	for rz: float in [-1.4, 0.0, 1.4]:
		mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 1.86, rz)), Vector3(1.5, 0.06, 0.06), Palette.CABLE.lightened(0.2))
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(sx * 0.8, 0.33, sz * 1.5)), 0.26, 0.33, 0.33, Palette.TIRE, 10)
	for lx: float in [-0.65, 0.65]:
		mb.box(xf * NeighborhoodFactory._at(Vector3(lx, 0.75, -2.31)), Vector3(0.3, 0.14, 0.04), Palette.BUTTER_YELLOW)
		mb.box(xf * NeighborhoodFactory._at(Vector3(lx, 0.8, 2.31)), Vector3(0.28, 0.12, 0.04), Palette.STRAWBERRY)


## Bus kota dua warna dengan jendela memanjang.
static func _bus(mb: MeshBuilder, v: int) -> void:
	var top: Color = Palette.SIGN_BLUE if v == 0 else Palette.SIGN_ORANGE
	var s: float = NeighborhoodFactory.CAR_SCALE
	var xf := Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * s), Vector3.ZERO)
	var glass: Color = Palette.WINDOW_GLASS.darkened(0.22)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 1.0, 0.0)), Vector3(2.5, 1.2, 10.0), Palette.FLOUR_WHITE.darkened(0.04))
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 2.25, 0.0)), Vector3(2.5, 1.3, 10.0), top)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 2.05, 0.2)), Vector3(2.53, 0.85, 8.8), glass)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 1.95, -5.01)), Vector3(2.2, 1.1, 0.04), glass)
	mb.box(xf * NeighborhoodFactory._at(Vector3(0.0, 0.62, 0.0)), Vector3(2.52, 0.14, 10.02), top.darkened(0.15))
	mb.box(xf * NeighborhoodFactory._at(Vector3(1.26, 1.3, -3.7)), Vector3(0.02, 1.9, 1.0), Palette.CABLE)
	for sz: float in [-3.4, 3.2]:
		for sx: float in [-1.0, 1.0]:
			mb.cylinder(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(sx * 1.1, 0.48, sz)), 0.3, 0.48, 0.48, Palette.TIRE, 10)
	for lx: float in [-0.9, 0.9]:
		mb.box(xf * NeighborhoodFactory._at(Vector3(lx, 0.85, -5.01)), Vector3(0.36, 0.16, 0.04), Palette.BUTTER_YELLOW)


## Becak dikayuh pengemudinya dari belakang; sebagian membawa penumpang.
static func _becak(mb: MeshBuilder, v: int, rain: bool) -> void:
	var bodies: Array[Color] = [Palette.SIGN_BLUE, Palette.SIGN_RED, Palette.MATCHA, Palette.HONEY]
	NeighborhoodFactory._becak(mb, Vector3.ZERO, 0.0, bodies[v % bodies.size()])
	var driver: Dictionary = _look(v + 2, Color(0, 0, 0, 0))
	var hands: Array = [Vector3(-0.24, 1.06, 0.5), Vector3(0.24, 1.06, 0.5)]
	var feet: Array = [Vector3(-0.12, 0.36, 0.68), Vector3(0.12, 0.52, 0.86)]
	_rider(mb, Vector3(0.0, 1.0, 0.82), hands, feet, driver, rain)
	if v % 2 == 0:
		var guest: Dictionary = _look(v + 5, Color(0, 0, 0, 0))
		var g_hands: Array = [Vector3(-0.3, 0.86, -0.35), Vector3(0.3, 0.86, -0.35)]
		var g_feet: Array = [Vector3(-0.12, 0.48, -0.8), Vector3(0.12, 0.48, -0.8)]
		_rider(mb, Vector3(0.0, 0.95, -0.25), g_hands, g_feet, guest, rain)


## Mobil antik membulat berwarna pastel (VW kodok).
static func _vintage(mb: MeshBuilder, v: int) -> void:
	var bodies: Array[Color] = [Palette.PASTEL_MINT.darkened(0.1), Palette.BUTTER_YELLOW, Palette.PASTEL_PERIWINKLE, Palette.ROSY_CHEEK]
	var body: Color = bodies[v % bodies.size()]
	var s: float = NeighborhoodFactory.CAR_SCALE
	var glass: Color = Palette.WINDOW_GLASS.darkened(0.2)
	mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.55, 0.0) * s), Vector3(0.85, 0.42, 1.95) * s, body, 14, 7)
	mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.95, 0.15) * s), Vector3(0.72, 0.42, 1.05) * s, body, 12, 6)
	mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.97, 0.15) * s), Vector3(0.74, 0.3, 0.92) * s, glass, 12, 5)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(sx * 0.72, 0.32, sz * 1.25) * s), 0.24 * s, 0.32 * s, 0.32 * s, Palette.TIRE, 10)
			mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(sx * 0.7, 0.5, sz * 1.25) * s), Vector3(0.22, 0.2, 0.42) * s, body.darkened(0.08), 8, 4)
	for lx: float in [-0.5, 0.5]:
		mb.ellipsoid(Transform3D(Basis.IDENTITY, Vector3(lx, 0.62, -1.82) * s), Vector3(0.14, 0.14, 0.06) * s, Palette.BUTTER_YELLOW, 8, 4)
	mb.box(Transform3D(Basis.IDENTITY, Vector3(0.0, 0.32, -1.98) * s), Vector3(1.5, 0.1, 0.08) * s, Palette.FLOUR_WHITE.darkened(0.08))
