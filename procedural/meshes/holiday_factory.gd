class_name HolidayFactory
extends RefCounted
## Hiasan hari libur (keputusan maintainer 2026-10-09, GDD 32.10): selama hari
## libur (GDD 26.6) untaian bendera segitiga terpasang di bagian atas kedua
## dinding belakang lantai toko, dan dua umbul-umbul berdiri di samping muka toko.
## Temanya bergantian setiap kali libur datang: merah-putih, pastel dengan
## lampion, lalu hijau-kuning dengan ketupat.
##
## Murni tampilan: satu mesh berwarna verteks dengan material MATTE bersama per
## bagian (tanpa kombinasi shader baru), tidak bisa diketuk, tidak disimpan.
## Umbul-umbul berdiri di sisi +x muka toko, jadi dari kamera yang terkunci
## tidak pernah menutupi lantai (geser layarnya selalu ke +x, GDD 32.5).

const THEMES: int = 3
const PENNANT_W: float = 0.13
const PENNANT_H: float = 0.15
const PENNANT_STEP: float = 0.17
## Jarak pengait tali (m) dan lendutnya.
const HOOK_STEP: float = 1.2
const SAG: float = 0.07
## Tali terpasang sedikit di bawah puncak dinding, sedikit di depan permukaannya.
const TOP_GAP: float = 0.05
const WALL_GAP: float = 0.03
## Celah di sekitar jam dinding bawaan di tengah dinding belakang.
const CLOCK_CLEAR: float = 0.24


## Tema hiasan untuk hari `day` (0..THEMES-1), bergiliran per kemunculan libur.
static func theme_for(day: int) -> int:
	var ev: Dictionary = DataRegistry.holiday_event()
	var start: int = int(ev.get("start_day", 12))
	var period: int = maxi(1, int(ev.get("period_days", 14)))
	return posmod(int(floor(float(day - start) / float(period))), THEMES)


static func _colors(theme: int) -> Array[Color]:
	var out: Array[Color] = []
	match theme:
		0:
			out = [Palette.SIGN_RED, Palette.FLOUR_WHITE]
		1:
			out = [Palette.PASTEL_STRAWBERRY, Palette.BUTTER_YELLOW, Palette.PASTEL_MINT, Palette.PASTEL_PERIWINKLE]
		_:
			out = [Palette.MATCHA, Palette.BUTTER_YELLOW]
	return out


## Untaian bendera di dinding belakang (z = d) dan kanan (x = w) lantai `f`.
static func build_inside(loc: LocationDefinition, f: FloorDefinition, theme: int) -> MeshInstance3D:
	var t: float = GridMath.WORLD_METERS_PER_TILE
	var w: float = float(f.size.x) * t
	var d: float = float(f.size.y) * t
	var y: float = RoomFactory.wall_height(loc.tier) - TOP_GAP
	var mb := MeshBuilder.new()
	var back_n := Vector3(0.0, 0.0, -1.0)
	var bz: float = d - WALL_GAP
	_string(mb, Vector3(0.08, y, bz), Vector3(w * 0.5 - CLOCK_CLEAR, y, bz), back_n, theme)
	_string(mb, Vector3(w * 0.5 + CLOCK_CLEAR, y, bz), Vector3(w - 0.08, y, bz), back_n, theme)
	var right_n := Vector3(-1.0, 0.0, 0.0)
	var rx: float = w - WALL_GAP
	_string(mb, Vector3(rx, y, d - 0.08), Vector3(rx, y, 0.08), right_n, theme)
	var mi: MeshInstance3D = mb.commit("HolidayInside")
	return mi


## Dua umbul-umbul di samping muka toko (sisi +x), dari jalan tampak di kiri atas
## pintu.
static func build_outside(f: FloorDefinition, theme: int) -> MeshInstance3D:
	var w: float = float(f.size.x) * GridMath.WORLD_METERS_PER_TILE
	var c: Array[Color] = _colors(theme)
	var mb := MeshBuilder.new()
	NeighborhoodFactory._umbul(mb, Vector3(w + 0.45, 0.0, -1.35), c[0], c[1 % c.size()])
	NeighborhoodFactory._umbul(mb, Vector3(w + 1.55, 0.0, -1.35), c[2 % c.size()], c[(3 % c.size())])
	return mb.commit("HolidayOutside")


## Satu tali dari `a` ke `b` yang melendut di antara pengait, dengan bendera
## segitiga menghadap `n`. Tema 1 menggantung lampion, tema 2 ketupat.
static func _string(mb: MeshBuilder, a: Vector3, b: Vector3, n: Vector3, theme: int) -> void:
	var length: float = a.distance_to(b)
	if length < PENNANT_STEP:
		return
	var hooks: int = maxi(1, int(round(length / HOOK_STEP)))
	var span: float = length / float(hooks)
	var colors: Array[Color] = _colors(theme)
	var at := func(s: float) -> Vector3:
		var local: float = fposmod(s, span) / span
		return a.lerp(b, s / length) + Vector3(0.0, -SAG * 4.0 * local * (1.0 - local), 0.0)
	var prev: Vector3 = a
	var steps: int = maxi(2, int(length / 0.1))
	for i in range(1, steps + 1):
		var q: Vector3 = at.call(length * float(i) / float(steps))
		NeighborhoodFactory._stick(mb, prev, q, 0.012, Palette.CABLE.lightened(0.25))
		prev = q
	var dir: Vector3 = (b - a).normalized()
	var count: int = int((length - PENNANT_W) / PENNANT_STEP)
	for k in count + 1:
		var s: float = PENNANT_W * 0.5 + PENNANT_STEP * float(k)
		var mid: Vector3 = at.call(s)
		var p0: Vector3 = mid - dir * PENNANT_W * 0.5
		var p1: Vector3 = mid + dir * PENNANT_W * 0.5
		var tip: Vector3 = mid + Vector3(0.0, -PENNANT_H, 0.0)
		mb.triangle(p0, p1, tip, n, colors[k % colors.size()])
		if theme != 0 and k % 4 == 2:
			_ornament(mb, mid + Vector3(0.0, -PENNANT_H - 0.07, 0.0) + n * 0.03, theme)


## Lampion merah bertutup emas (tema 1), atau ketupat anyaman hijau (tema 2).
static func _ornament(mb: MeshBuilder, p: Vector3, theme: int) -> void:
	if theme == 1:
		mb.ellipsoid(Transform3D(Basis.IDENTITY, p), Vector3(0.055, 0.065, 0.055), Palette.SIGN_RED, 8, 4)
		mb.cylinder(Transform3D(Basis.IDENTITY, p + Vector3(0.0, 0.068, 0.0)), 0.02, 0.03, 0.03, Palette.BRASS, 6)
		mb.cylinder(Transform3D(Basis.IDENTITY, p + Vector3(0.0, -0.068, 0.0)), 0.02, 0.03, 0.03, Palette.BRASS, 6)
	else:
		mb.ellipsoid(Transform3D(Basis(Vector3.UP, PI * 0.25), p), Vector3(0.06, 0.07, 0.06), Palette.MATCHA_DEEP, 4, 2)
		mb.box(Transform3D(Basis.IDENTITY, p + Vector3(0.0, -0.1, 0.0)), Vector3(0.012, 0.07, 0.012), Palette.BUTTER_YELLOW)
