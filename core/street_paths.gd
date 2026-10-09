class_name StreetPaths
extends RefCounted
## Jalur jalan kaki di luar toko (keputusan maintainer 2026-10-09, GDD 20.1):
## pembeli, pengunjung lihat-lihat, driver RotiFood, kurir, dan pemeran kejutan
## datang dari ujung trotoar di luar layar, berjalan sepanjang trotoar, lalu
## berbelok tegak lurus masuk lewat pintu; saat pulang mereka menempuh jalur
## sebaliknya. Dipakai bersama oleh simulasi (lama perjalanan datang) dan lapisan
## dunia (pejalan kaki, kepergian), jadi tidak bergantung pada pembangun mesh.
##
## Koordinat dunia (meter) sama dengan lantai toko: x mendatar sepanjang muka
## toko, z < 0 di depan toko. Jalur trotoar setiap tier cukup jauh dari muka toko
## dan bebas dari benda-benda lingkungan (ACC_20_STREET_ARRIVAL).

## Garis trotoar (z) tempat orang berjalan di depan toko, per tier.
const WALK_Z: Array[float] = [-1.75, -2.95, -2.9, -4.7, -3.0]
## Ujung trotoar (x) tempat kedatangan dimulai, kiri dan kanan, per tier. NAN =
## sisi itu tidak dipakai (Tier 5: sisi kiri melewati pangkalan becak).
const ENDS: Array[Vector2] = [Vector2(-10.75, 13.25), Vector2(-10.75, 13.25), Vector2(-10.75, 11.0),
	Vector2(-10.25, 13.75), Vector2(NAN, 14.75)]


static func walk_z(tier: int) -> float:
	return WALK_Z[clampi(tier, 1, WALK_Z.size()) - 1]


## Sisi kedatangan yang sah: -1 (kiri) atau +1 (kanan). Sisi yang tidak dipakai
## di tier itu diganti sisi lainnya.
static func side_for(tier: int, want: int) -> int:
	var e: Vector2 = ENDS[clampi(tier, 1, ENDS.size()) - 1]
	if want < 0 and not is_nan(e.x):
		return -1
	if want > 0 and not is_nan(e.y):
		return 1
	return 1 if is_nan(e.x) else -1


## Jalur datang dari ujung trotoar sisi `side` sampai tengah sel pintu.
static func approach(loc: LocationDefinition, side: int) -> PackedVector2Array:
	var tier: int = loc.tier
	var s: int = side_for(tier, side)
	var e: Vector2 = ENDS[clampi(tier, 1, ENDS.size()) - 1]
	var door: Vector2 = GridMath.cell_center(loc.entrance_cell)
	var z: float = walk_z(tier)
	return PackedVector2Array([Vector2(e.x if s < 0 else e.y, z), Vector2(door.x, z), door])


## Jalur pulang dari pintu ke ujung trotoar sisi `side`.
static func leave(loc: LocationDefinition, side: int) -> PackedVector2Array:
	var p: PackedVector2Array = approach(loc, side)
	p.reverse()
	return p


## Berbalik pulang dari titik `pos` di jalur datang sisi `side` (order batal di
## tengah jalan, toko tutup).
static func retreat(loc: LocationDefinition, side: int, pos: Vector2) -> PackedVector2Array:
	var p: PackedVector2Array = approach(loc, side)
	if pos.y > p[1].y + 0.01:
		return PackedVector2Array([pos, p[1], p[0]])
	return PackedVector2Array([pos, p[0]])


## Jalur pulang dari `pos` (di dalam toko di sel pintu, atau di trotoar) ke ujung
## trotoar sisi `side`.
static func leave_from(loc: LocationDefinition, side: int, pos: Vector2) -> PackedVector2Array:
	var p: PackedVector2Array = leave(loc, side)
	if pos.y < 0.0:
		return retreat(loc, side, pos)
	p[0] = pos
	return p


static func length(path: PackedVector2Array) -> float:
	var total: float = 0.0
	for i in range(1, path.size()):
		total += path[i - 1].distance_to(path[i])
	return total


## Lama perjalanan datang (detik-simulasi) pada kecepatan `speed_mps`.
static func approach_seconds(loc: LocationDefinition, side: int, speed_mps: float) -> float:
	return length(approach(loc, side)) / maxf(speed_mps, 0.01)
