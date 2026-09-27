class_name GridMath
extends RefCounted
## Skala ruang kanonik (GDD 6.1, 17.1): 1 tile = 0,5 m × 0,5 m, tidak pernah
## di-override per tier atau per scene. Dimensi gameplay disimpan dalam tile
## integer; meter hanya dipakai saat membangun transform dunia 3D.

const WORLD_METERS_PER_TILE: float = 0.5
const TILES_PER_METER: float = 2.0

## Arah rotasi: 0° = interaction face menghadap -Z (ke z yang lebih kecil).
const FACE_DIRS: Array[Vector2i] = [Vector2i(0, -1), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(1, 0)]


## Pusat tile dalam meter (x, z).
static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2((float(cell.x) + 0.5) * WORLD_METERS_PER_TILE, (float(cell.y) + 0.5) * WORLD_METERS_PER_TILE)


static func cell_center3(cell: Vector2i, y: float = 0.0) -> Vector3:
	var c: Vector2 = cell_center(cell)
	return Vector3(c.x, y, c.y)


## Tile yang memuat titik (meter). Menggunakan floor, bukan round, karena asal
## tile berada di sudutnya.
static func world_to_cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / WORLD_METERS_PER_TILE)), int(floor(p.y / WORLD_METERS_PER_TILE)))


static func tiles_to_meters(tiles: float) -> float:
	return tiles * WORLD_METERS_PER_TILE


## Footprint setelah rotasi: X/Z ditukar pada 90° dan 270° (GDD 60.1).
static func rotated_footprint(fp: Vector2i, rotation_quarters: int) -> Vector2i:
	if rotation_quarters % 2 == 1:
		return Vector2i(fp.y, fp.x)
	return fp


## Semua sel yang ditempati footprint dengan anchor di sudut kiri-bawah.
static func footprint_cells(anchor: Vector2i, fp: Vector2i, rotation_quarters: int) -> Array[Vector2i]:
	var r: Vector2i = rotated_footprint(fp, rotation_quarters)
	var out: Array[Vector2i] = []
	for x in r.x:
		for z in r.y:
			out.append(anchor + Vector2i(x, z))
	return out


## Sel akses tepat di depan interaction face (GDD 60.1). Untuk footprint lebar,
## seluruh sisi depan dikembalikan; pemanggil memilih yang paling dekat.
static func front_cells(anchor: Vector2i, fp: Vector2i, rotation_quarters: int, face: StringName = &"front") -> Array[Vector2i]:
	var r: Vector2i = rotated_footprint(fp, rotation_quarters)
	var q: int = posmod(rotation_quarters, 4)
	var out: Array[Vector2i] = []
	# Oven T5 memakai sisi pendek (ujung conveyor): pada rotasi 0 footprint 3×1
	# memanjang di X, jadi ujung pendeknya menghadap -X.
	if face == &"short_end":
		q = posmod(q + 1, 4)
	match q:
		0:
			for x in r.x:
				out.append(anchor + Vector2i(x, -1))
		1:
			for z in r.y:
				out.append(anchor + Vector2i(-1, z))
		2:
			for x in r.x:
				out.append(anchor + Vector2i(x, r.y))
		3:
			for z in r.y:
				out.append(anchor + Vector2i(r.x, z))
	if face == &"short_end" and out.size() > 1:
		# Hanya satu tile masuk conveyor: yang di tengah sisi pendek.
		var mid: Vector2i = out[out.size() / 2]
		out.clear()
		out.append(mid)
	return out


## Arah hadap (vektor tile) interaction face.
static func face_dir(rotation_quarters: int, face: StringName = &"front") -> Vector2i:
	var q: int = posmod(rotation_quarters, 4)
	if face == &"short_end":
		q = posmod(q + 1, 4)
	return FACE_DIRS[q]


static func manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)
