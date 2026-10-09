class_name NeighborhoodFactory
extends RefCounted
## Lingkungan di luar toko (keputusan maintainer 2026-10-08, GDD 32.5): toko
## berdiri di lingkungan yang sesuai tier lokasinya, bukan di atas warna polos.
##
## Tier 1 (Garasi Rumah) berada di pinggir jalan aspal komplek di sebuah
## perumahan kampung kota: got beton di kedua tepi jalan, rumah pemilik garasi di
## sebelahnya, rumah tetangga berpagar besi di sekelilingnya, tiang listrik,
## pohon mangga dan pisang, motor parkir, dan jemuran. Suasananya tenang, tidak
## ramai.
##
## Tier 2 (Ruko 1 Pintu) adalah ruko paling ujung di deretan ruko dua lantai yang
## menghadap jalan dua lajur bermarka: pintu gulung, kanopi, papan nama tanpa
## tulisan, motor parkir di pelataran, gerobak, dan pohon ketapang kencana. Di
## samping toko ada jalan kecil masuk kampung, dan di balik deretan ruko ada gang
## serta rumah-rumah kampung. Dari dapur di lantai atas, jalan tampak di bawah
## bersama lantai dasar ruko sendiri (show_for_floor).
##
## Tier 3 (Toko Bakery Mandiri) adalah toko dua lantai yang berdiri sendiri di
## tepi jalan raya kota dekat perkantoran dan kampus: trotoar lebar berubin
## pemandu, jalan empat lajur bermedian, minimarket di sebelah, teras kafe
## berpayung dan parkir mobil di samping toko, halaman servis di belakang, lalu
## taman kampus. Tanpa kabel listrik di atas jalan.
##
## Tier 4 (Flagship Store) berdiri di kawasan premium kota: pelataran granit
## dengan karpet merah bertiang tali kuningan, trotoar berpohon tabebuya merah
## muda, mobil mewah dan meja valet, median berpohon palem, deretan butik di satu
## sisi, taman air mancur dan kafe patisserie di sisi lain, dan menara apartemen
## di belakang.
##
## Tier 5 (Mega Bakery Landmark) menghadap alun-alun kota bergaya heritage: menara
## jam di tengah alun-alun, pohon beringin berpagar, becak yang mangkal, lampu
## antik, gedung kolonial putih berjendela hijau dengan onthel sewaan dan
## umbul-umbul di satu sisi, pujasera bertenda di sisi lain, dan halaman servis
## bertembok bata di belakang.
##
## Jalan dan semua isinya dijahit menjadi SATU mesh berwarna verteks (MeshBuilder,
## material MATTE bersama), jadi satu draw call tanpa kombinasi shader baru
## (GDD 89.5); lantai dasar ruko sendiri satu mesh lagi. Tidak ada yang bisa
## diketuk, dan simulasi tidak tahu lingkungan ini ada. Kejauhan memudar ke warna
## latar.
##
## Koordinat dunia sama dengan RoomFactory: toko di x 0..w, z 0..d, pintu di
## z = 0 menghadap jalan. Kamera memandang dari depan-kiri, jadi titik setinggi h
## tampak di atas titik tanah yang bergeser kira-kira h ke +x dan +z. Benda di
## depan (z < 0) dan di kiri (x < 0) toko karena itu dijaga cukup rendah atau
## cukup jauh supaya tidak pernah menutupi isi toko (ACC_32_NEIGHBORHOOD_CLEAR).

const T: float = GridMath.WORLD_METERS_PER_TILE
## Pudar ke warna latar: utuh sampai FADE_START meter dari tengah toko, lalu
## menyatu penuh pada FADE_END.
const FADE_START: float = 11.0
const FADE_END: float = 28.0
## Setengah diagonal lantai toko Tier 1-3 (3 x 6 m). Lantai yang lebih besar
## memudar lebih jauh sebanyak selisih setengah diagonalnya (fade_radii).
const BASE_HALF_DIAG: float = 3.3541
## Jalan komplek di depan toko: tepi sisi toko dan tepi seberang (z), panjangnya.
const ROAD_NEAR: float = -1.25
const ROAD_FAR: float = -4.75
const ROAD_X0: float = -40.0
const ROAD_X1: float = 44.0
## Lebar got beton dan tebal bibirnya.
const GUTTER_W: float = 0.4
const LIP: float = 0.07
## Lapisan tanah (m): rumput, paving halaman, aspal.
const Y_GROUND: float = -0.04
const Y_YARD: float = -0.035
const Y_ROAD: float = -0.03
## Garis pagar depan rumah sederetan toko dan pagar seberang jalan (z).
const FENCE_Z: float = -0.8
const FAR_FENCE_Z: float = -5.35
## Bidang dan bibir got yang panjang dipotong paling panjang segini (m): pudar ke
## warna latar dihitung per verteks, jadi potongan sepanjang jalan akan ikut
## pudar seluruhnya.
const PIECE: float = 2.5
## Tiang listrik di seberang jalan: posisi z dan tingginya. Cukup rendah supaya
## kabelnya tampak melintas di atas jalan, bukan di depan muka toko.
const POLE_Z: float = -5.25
const POLE_H: float = 4.0
## Tinggi satu lantai (m). Lantai atas toko melihat jalan sejauh ini per lantai di
## bawahnya, jadi seluruh lingkungan turun sebanyak itu (show_for_floor).
const STOREY: float = 2.5

# --- Tier 2: pertokoan ruko -------------------------------------------------
## Jalan utama dua lajur: tepi sisi toko dan tepi seberang (z).
const T2_ROAD_NEAR: float = -2.6
const T2_ROAD_FAR: float = -8.6
## Pelataran parkir di depan deretan ruko, dari z ini sampai muka ruko (z = 0).
const T2_APRON_Z: float = -2.2
## Jalan kecil masuk kampung di samping toko (x).
const T2_LANE_X0: float = -5.4
const T2_LANE_X1: float = -1.8
## Gang di balik deretan ruko (z) dan pagar rumah kampung di seberangnya.
const T2_ALLEY_Z0: float = 6.1
const T2_ALLEY_Z1: float = 7.7
const T2_KAMPUNG_FENCE_Z: float = 7.85
## Trotoar seberang (sampai z ini), zebra cross (x), dan tiang listrik.
const T2_WALK_Z: float = -11.4
const T2_ZEBRA_X0: float = 8.0
const T2_ZEBRA_X1: float = 10.4
const T2_POLE_Z: float = -9.35
const T2_POLE_H: float = 5.4
## Ruko: tinggi lantai dasar (= STOREY), lantai atas, dan dinding pembatas atap.
const RUKO_GROUND: float = STOREY
const RUKO_UPPER: float = 2.2
const PARAPET: float = 0.45

# --- Tier 3: jalan raya kota ------------------------------------------------
## Teras depan toko sampai z ini, lalu trotoar sampai tepi jalan raya.
const T3_YARD_Z: float = -1.8
## Jalan raya: dua lajur sisi toko, median, dan dua lajur seberang (z).
const T3_ROAD_NEAR: float = -4.6
const T3_ROAD_FAR: float = -11.6
const T3_MEDIAN_Z: float = -13.1
const T3_ROAD2_FAR: float = -20.1
## Zebra cross (x).
const T3_ZEBRA_X0: float = 5.5
const T3_ZEBRA_X1: float = 8.0
## Teras kafe (x sampai dinding toko) dan parkir mobil (x sampai teras).
const T3_TERRACE_X: float = -4.6
const T3_LOT_X: float = -11.6
## Minimarket di sebelah toko: x dan garis mukanya (z).
const T3_MART_X0: float = 4.4
const T3_MART_X1: float = 10.4
const T3_MART_Z: float = 0.6
## Tembok belakang halaman servis dan tepi seberang gang belakang (z).
const T3_BACK_Z: float = 8.6
const T3_ALLEY_Z: float = 10.2

# --- Tier 4: kawasan premium ------------------------------------------------
## Pelataran granit sampai z ini, lalu trotoar sampai tepi jalan.
const T4_PLAZA_Z: float = -3.0
## Jalan: jalur parkir, dua lajur, median berpalem, dua lajur seberang (z).
const T4_ROAD_NEAR: float = -6.4
const T4_PARK_Z: float = -8.6
const T4_ROAD_FAR: float = -13.4
const T4_MEDIAN_Z: float = -15.4
const T4_ROAD2_FAR: float = -22.4
## Lorong samping berpot pakis di antara toko dan deretan butik (x sampai sini).
const T4_PASSAGE_X1: float = 9.4
## Taman air mancur di sisi lain toko, dari x ini sampai dinding toko.
const T4_GARDEN_X: float = -6.0
## Tepi seberang jalan servis di belakang toko (z).
const T4_LANE_Z: float = 11.0

# --- Tier 5: alun-alun kota -------------------------------------------------
## Teras batu depan toko sampai z ini, lalu alun-alun sampai tepi jalan.
const T5_TERRACE_Z: float = -2.0
const T5_ROAD_NEAR: float = -9.0
const T5_ROAD_FAR: float = -16.0
## Lorong batu di samping toko sampai x ini, lalu gedung kolonial.
const T5_PASSAGE_X1: float = 11.0
## Pujasera di sisi lain toko, dari x ini sampai dinding toko.
const T5_COURT_X: float = -9.6
## Tembok bata di ujung halaman servis belakang (z).
const T5_BACK_Z: float = 13.0
## Skala mobil terhadap ukuran sebenarnya (dunia chibi).
const CAR_SCALE: float = 0.68
## Pendar lampu jalan saat senja dan fajar (GDD 32.6): cakram lembut menghadap
## kamera di kepala lampu, dan genangan cahaya di tanah di bawahnya. Keduanya
## memakai material SHADOW (tanpa bayangan, transparan) milik bayangan karakter.
const GLOW_RADIUS: float = 0.5
const GLOW_COLOR: Color = Color(1.0, 0.86, 0.55, 0.7)
const POOL_RADIUS: float = 1.0
const POOL_COLOR: Color = Color(1.0, 0.85, 0.55, 0.24)
## Tinggi genangan cahaya: tepat di atas bibir got dan trotoar.
const POOL_Y: float = 0.075

## Hujan (GDD 32.8): permukaan dekat tanah digelapkan, dan genangan air
## kebiruan muncul di jalan, trotoar, dan alun-alun dekat toko.
const WET_DARKEN: float = 0.16
const WET_MAX_Y: float = 0.25
const PUDDLE_COLOR: Color = Color(0.565, 0.635, 0.69)
const PUDDLE_RIM: Color = Color(0.49, 0.565, 0.62)
const PUDDLE_SHINE: Color = Color(0.87, 0.9, 0.93)

## Kepala lampu jalan yang dirakit `build()` terakhir (titik pendarnya).
static var _lamp_heads: PackedVector3Array = PackedVector3Array()
## Genangan yang dirakit `build()` terakhir: Vector4(x, y, z, jari-jari).
static var _puddles: Array[Vector4] = []


## Lingkungan untuk lokasi `loc` (lantai toko `f`), atau null bila tier itu belum
## punya lingkungan. Lokasi bertingkat juga mendapat "OwnBuilding": lantai dasar
## ruko sendiri, yang hanya tampil saat kamera di lantai atas.
static func build(loc: LocationDefinition, f: FloorDefinition, wet: bool = false) -> Node3D:
	if loc == null or f == null or not has_street(loc.tier):
		return null
	var w: float = float(f.size.x) * T
	var d: float = float(f.size.y) * T
	var center := Vector3(w * 0.5, 0.0, d * 0.5)
	_lamp_heads = PackedVector3Array()
	_puddles = []
	var mb := MeshBuilder.new()
	_ground(mb, Vector2(center.x, center.z))
	match loc.tier:
		1:
			_tier1(mb, w, d)
		2:
			_tier2(mb, w)
		3:
			_tier3(mb, w)
		4:
			_tier4(mb, w, d, _door_x(f))
		_:
			_tier5(mb, w, d, _door_x(f))
	if wet:
		mb.darken_ground(WET_MAX_Y, WET_DARKEN)
		for pd: Vector4 in puddle_spots(loc.tier):
			_puddle(mb, pd)
	var fade: Vector2 = fade_radii(w, d)
	mb.fade_to(center, fade.x, fade.y, Palette.BG, 1.0)
	var root := Node3D.new()
	root.name = "Neighborhood"
	root.set_meta("wet", wet)
	root.set_meta("puddles", _puddles.duplicate())
	root.add_child(mb.commit("Street"))
	var glow := MeshBuilder.new()
	for p: Vector3 in _lamp_heads:
		_lamp_glow(glow, p, center, fade)
	var glow_mi: MeshInstance3D = glow.commit("LampGlow", MeshBuilder.SHADOW)
	glow_mi.visible = false
	root.add_child(glow_mi)
	if loc.floors.size() > 1:
		var upper_d: float = d
		for uf: FloorDefinition in loc.floors:
			if floor_level(loc, uf.id) == 1:
				upper_d = float(uf.size.y) * T
		var own := MeshBuilder.new()
		if loc.tier == 3:
			_own_t3(own, w, d)
		else:
			_own_t2(own, w, upper_d)
		var own_mi: MeshInstance3D = own.commit("OwnBuilding")
		own_mi.visible = false
		root.add_child(own_mi)
	return root


## Tier yang sudah punya lingkungan; tier lain memakai warna latar polos.
static func has_street(tier: int) -> bool:
	return tier >= 1 and tier <= 5


## Jari-jari pudar (mulai, habis) untuk lantai toko w x d: lantai yang lebih
## besar dari Tier 1-3 memudar lebih jauh sebanyak selisih setengah diagonalnya.
static func fade_radii(w: float, d: float) -> Vector2:
	var extra: float = maxf(0.0, Vector2(w, d).length() * 0.5 - BASE_HALF_DIAG)
	return Vector2(FADE_START + extra, FADE_END + extra)


## Pusat x pintu masuk lantai toko (petak entrance).
static func _door_x(f: FloorDefinition) -> float:
	if f.entrance.is_empty():
		return float(f.size.x) * T * 0.5
	var x0: float = INF
	var x1: float = -INF
	for c: Vector2i in f.entrance:
		x0 = minf(x0, float(c.x) * T)
		x1 = maxf(x1, float(c.x + 1) * T)
	return (x0 + x1) * 0.5


## Tepi jalan utama di depan toko tier ini: (z sisi toko, z seberang).
static func road_edges(tier: int) -> Vector2:
	if tier == 2:
		return Vector2(T2_ROAD_NEAR, T2_ROAD_FAR)
	if tier == 3:
		return Vector2(T3_ROAD_NEAR, T3_ROAD_FAR)
	if tier == 4:
		return Vector2(T4_ROAD_NEAR, T4_ROAD_FAR)
	if tier == 5:
		return Vector2(T5_ROAD_NEAR, T5_ROAD_FAR)
	return Vector2(ROAD_NEAR, ROAD_FAR)


## Lantai ke berapa `floor_id` di atas jalan (0 = lantai toko), dari angka di
## belakang id-nya ("floor_2" di atas "floor_1" = 1); -1 bila tidak dikenal.
static func floor_level(loc: LocationDefinition, floor_id: StringName) -> int:
	if loc == null:
		return -1
	var base: String = str(loc.store_floor())
	var s: String = str(floor_id)
	if s == base:
		return 0
	if not s.begins_with("floor_") or not base.begins_with("floor_"):
		return -1
	var level: int = int(s.trim_prefix("floor_")) - int(base.trim_prefix("floor_"))
	return level if level > 0 else -1


## Pasang lingkungan untuk lantai yang sedang tampil: lantai toko berdiri di
## jalan; dari lantai di atasnya jalan tampak STOREY meter per lantai di bawah,
## dengan lantai dasar ruko sendiri di bawah ruangan itu.
static func show_for_floor(node: Node3D, loc: LocationDefinition, floor_id: StringName) -> void:
	var level: int = floor_level(loc, floor_id)
	node.visible = level >= 0
	node.position = Vector3(0.0, -STOREY * float(maxi(level, 0)), 0.0)
	var own: Node3D = node.get_node_or_null("OwnBuilding") as Node3D
	if own != null:
		own.visible = level > 0


## Lalu-lalang di luar toko (GDD 32.7). `lanes` = lajur kendaraan sejajar muka
## toko: z tengah lajur, arah (+1 = ke +x), ujung x0..x1 (kendaraan muncul dan
## hilang di ujung yang sudah memudar penuh atau di luar layar), jenis dan
## bobotnya, jeda nyata antar kendaraan (detik), dan geser samping acak untuk
## roda dua. Lalu lintas berjalan di kiri: arah +x di lajur yang lebih jauh dari
## toko. `walks` = jalur pejalan kaki (dua arah), `looks` = arketipe rupa
## pejalan kaki. Semua lajur cukup jauh dari muka toko supaya kendaraan dan orang
## yang lewat tidak menutupi lantai toko di layar (ACC_32_STREET_LIFE).
static func traffic(tier: int) -> Dictionary:
	var two: Dictionary = {&"motor": 5, &"motor_pair": 2, &"ojol": 3, &"bicycle": 2, &"gerobak": 1, &"car": 1}
	match tier:
		1:
			return {
				"lanes": [
					{"z": -2.45, "dir": -1, "x0": -26.0, "x1": 30.0, "kinds": two, "gap": Vector2(7.0, 15.0), "jitter": 0.12},
					{"z": -3.75, "dir": 1, "x0": -26.0, "x1": 30.0, "kinds": two, "gap": Vector2(8.0, 16.0), "jitter": 0.12},
				],
				"walks": [{"z": -1.75, "x0": -9.0, "x1": 15.0, "gap": Vector2(7.0, 15.0)}],
				"looks": [&"customer_generic", &"customer_school_child", &"customer_indecisive"],
			}
		2:
			var road: Dictionary = {&"motor": 6, &"ojol": 3, &"motor_pair": 2, &"angkot": 3, &"car": 3, &"van": 1}
			return {
				"lanes": [
					{"z": -4.1, "dir": -1, "x0": -26.0, "x1": 30.0, "kinds": road, "gap": Vector2(4.5, 9.0), "jitter": 0.35},
					{"z": -7.1, "dir": 1, "x0": -26.0, "x1": 30.0, "kinds": road, "gap": Vector2(5.0, 10.0), "jitter": 0.35},
				],
				"walks": [{"z": -2.95, "x0": -8.0, "x1": 14.0, "gap": Vector2(7.0, 15.0)}],
				"looks": [&"customer_generic", &"customer_office_worker", &"customer_school_child"],
			}
		3:
			return {
				"lanes": [
					{"z": -6.35, "dir": -1, "x0": -26.0, "x1": 30.0, "kinds": {&"car": 6, &"ojol": 3, &"motor": 3, &"bus": 1, &"van": 1, &"angkot": 1},
						"gap": Vector2(3.5, 7.5), "jitter": 0.3},
					{"z": -9.85, "dir": -1, "x0": -26.0, "x1": 30.0, "kinds": {&"car": 6, &"bus": 2, &"van": 1, &"ojol": 1},
						"gap": Vector2(4.0, 8.0), "jitter": 0.2},
				],
				"walks": [{"z": -2.9, "x0": -8.0, "x1": 11.0, "gap": Vector2(6.0, 13.0)}],
				"looks": [&"customer_office_worker", &"customer_generic", &"customer_school_child"],
			}
		4:
			return {
				"lanes": [
					{"z": -9.8, "dir": -1, "x0": -27.0, "x1": 33.0, "kinds": {&"luxury": 6, &"car": 2, &"van": 1, &"ojol": 1},
						"gap": Vector2(4.0, 8.0), "jitter": 0.15},
					{"z": -12.2, "dir": -1, "x0": -27.0, "x1": 33.0, "kinds": {&"luxury": 5, &"car": 3, &"bus": 1},
						"gap": Vector2(5.0, 10.0), "jitter": 0.15},
				],
				"walks": [{"z": -4.7, "x0": -14.0, "x1": 20.0, "gap": Vector2(7.0, 15.0)}],
				"looks": [&"customer_snob", &"customer_office_worker", &"customer_generic"],
			}
		5:
			return {
				"lanes": [
					{"z": -10.7, "dir": -1, "x0": -27.0, "x1": 33.0, "kinds": {&"vintage": 3, &"car": 3, &"motor": 3, &"becak": 1, &"ojol": 1},
						"gap": Vector2(4.5, 9.0), "jitter": 0.25},
					{"z": -14.3, "dir": 1, "x0": -27.0, "x1": 33.0, "kinds": {&"car": 3, &"vintage": 2, &"bus": 1, &"motor": 2},
						"gap": Vector2(5.0, 10.0), "jitter": 0.25},
					# Becak dan onthel berangkat dari pangkalan becak melintasi alun-alun.
					{"z": -4.75, "dir": 1, "x0": -1.6, "x1": 26.0, "kinds": {&"becak": 3, &"onthel": 3},
						"gap": Vector2(9.0, 18.0), "jitter": 0.0, "pop": true},
				],
				"walks": [{"z": -3.0, "x0": -1.6, "x1": 24.0, "gap": Vector2(6.0, 13.0)}],
				"looks": [&"customer_generic", &"customer_bulk_buyer", &"customer_school_child", &"customer_critic"],
			}
	return {"lanes": [], "walks": [], "looks": []}


## Genangan hujan per tier: Vector4(x, tinggi permukaan, z, jari-jari), di jalan,
## trotoar, dan alun-alun yang tampak dari kamera (GDD 32.8).
static func puddle_spots(tier: int) -> Array[Vector4]:
	var road: float = Y_ROAD + 0.006
	var yard: float = Y_YARD + 0.014
	var out: Array[Vector4] = []
	match tier:
		1:
			out = [Vector4(-0.5, road, -2.0, 0.55), Vector4(2.6, road, -3.2, 0.7), Vector4(6.4, road, -2.3, 0.45),
				Vector4(-3.8, road, -3.6, 0.6), Vector4(9.4, road, -3.9, 0.5), Vector4(13.0, road, -2.6, 0.55)]
		2:
			out = [Vector4(1.0, road, -3.5, 0.6), Vector4(4.4, road, -5.3, 0.8), Vector4(-2.6, road, -4.6, 0.5),
				Vector4(8.2, road, -3.3, 0.55), Vector4(11.5, road, -6.4, 0.7)]
		3:
			out = [Vector4(2.2, yard, -3.5, 0.45), Vector4(-2.8, yard, -3.9, 0.55), Vector4(6.2, yard, -2.4, 0.4),
				Vector4(1.0, road, -5.7, 0.7), Vector4(4.2, road, -7.9, 0.8)]
		4:
			out = [Vector4(2.4, yard, -3.6, 0.5), Vector4(6.0, yard, -4.8, 0.6), Vector4(-2.0, yard, -5.0, 0.45),
				Vector4(10.0, yard, -3.4, 0.5), Vector4(1.0, road, -10.6, 0.8)]
		5:
			out = [Vector4(1.5, yard, -4.2, 0.6), Vector4(8.8, yard, -3.1, 0.5), Vector4(2.6, yard, -6.3, 0.7),
				Vector4(-0.6, yard, -5.9, 0.55), Vector4(11.0, yard, -5.2, 0.6), Vector4(2.0, road, -11.6, 0.8)]
	return out


## Satu genangan: tiga cakram lonjong bertumpuk supaya bentuknya tidak bulat
## sempurna, dengan kilau tipis memantulkan langit. Jari-jari dicatat untuk riak
## tetes hujan.
static func _puddle(mb: MeshBuilder, pd: Vector4) -> void:
	var p := Vector3(pd.x, pd.y, pd.z)
	var r: float = pd.w
	var oval := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.62))
	mb.disc(Transform3D(oval, p), r, PUDDLE_COLOR, PUDDLE_RIM, 16)
	mb.disc(Transform3D(oval, p + Vector3(r * 0.6, 0.001, r * 0.18)), r * 0.6, PUDDLE_COLOR, PUDDLE_RIM, 12)
	mb.disc(Transform3D(oval, p + Vector3(-r * 0.5, 0.001, -r * 0.2)), r * 0.5, PUDDLE_COLOR, PUDDLE_RIM, 12)
	var streak := Basis.IDENTITY.scaled(Vector3(1.0, 1.0, 0.16))
	mb.disc(Transform3D(streak, p + Vector3(-r * 0.1, 0.002, -r * 0.12)), r * 0.42, PUDDLE_SHINE, PUDDLE_COLOR, 10)
	_puddles.append(pd)


## Nyalakan atau padamkan pendar lampu jalan (Daylight, GDD 32.6).
static func set_lamps(node: Node3D, on: bool) -> void:
	var glow: Node3D = node.get_node_or_null("LampGlow") as Node3D
	if glow != null:
		glow.visible = on


## Arah dari dunia menuju kamera yang terkunci (yaw/pitch dari katalog).
static func toward_camera() -> Vector3:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	return Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()


## Pendar satu lampu: cakram menghadap kamera dan genangan cahaya di tanah.
## Lampu di kejauhan meredup bersama pudarnya lingkungan.
static func _lamp_glow(mb: MeshBuilder, p: Vector3, center: Vector3, fade: Vector2) -> void:
	var dist: float = Vector2(p.x - center.x, p.z - center.z).length()
	var keep: float = 1.0 - clampf((dist - fade.x) / maxf(fade.y - fade.x, 0.001), 0.0, 1.0)
	if keep <= 0.05:
		return
	var n: Vector3 = toward_camera()
	var x: Vector3 = Vector3.UP.cross(n).normalized()
	var face := Basis(x, n, x.cross(n).normalized())
	var halo := Color(GLOW_COLOR, GLOW_COLOR.a * keep)
	# Titik di tinggi y tampak di atas tanah z + k y (k = cos(yaw) / tan(pitch)).
	# Di cakram setegak layar, z + k y naik paling cepat searah gradien (0, k, 1)
	# yang diproyeksikan ke bidang cakram. Lampu dekat muka toko (teras Tier 5)
	# mendapat cakram lebih kecil supaya pendarnya tidak menutupi lantai toko.
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var k: float = cos(yaw) / tan(pitch)
	var g := Vector3(0.0, k, 1.0)
	var along: float = maxf((g - n * g.dot(n)).length(), 0.001)
	var r: float = minf(GLOW_RADIUS, (-0.05 - (p.z + p.y * k)) / along)
	if r >= 0.12:
		mb.disc(Transform3D(face, p), r, halo, Color(halo, 0.0), 14)
	var pool := Color(POOL_COLOR, POOL_COLOR.a * keep)
	mb.disc(Transform3D(Basis.IDENTITY, Vector3(p.x, POOL_Y, p.z)), POOL_RADIUS, pool, Color(pool, 0.0), 16)


# ===========================================================================
# TIER 1 — PERUMAHAN KAMPUNG KOTA
# ===========================================================================

static func _tier1(mb: MeshBuilder, w: float, _d: float) -> void:
	_road(mb)
	_gutter(mb, ROAD_NEAR, 1.0)
	_gutter(mb, ROAD_FAR, -1.0)
	# Teras semen garasi dan tutup got di depan pintu toko.
	mb.box(_at(Vector3((w - 0.15) * 0.5, -0.026, -0.45)), Vector3(w + 0.45, 0.028, 0.8), Palette.CONCRETE)
	for span: Vector2 in [Vector2(0.0, w), Vector2(5.2, 7.6), Vector2(-3.5, -1.0), Vector2(13.2, 15.2),
			Vector2(-14.4, -12.6), Vector2(20.0, 22.0), Vector2(-21.0, -19.0)]:
		_slab(mb, span.x, span.y, ROAD_NEAR, 1.0)
	for span2: Vector2 in [Vector2(-6.6, -4.6), Vector2(6.6, 8.6), Vector2(-14.0, -12.0), Vector2(14.0, 16.0)]:
		_slab(mb, span2.x, span2.y, ROAD_FAR, -1.0)
	_pot(mb, Vector3(w + 0.05, 0.0, -0.35), Palette.TERRACOTTA, Palette.LEAF)
	_pot(mb, Vector3(-0.8, 0.0, -0.3), Palette.TERRACOTTA, Palette.ROSY_CHEEK)
	_owner_house(mb, w)
	_left_neighbor(mb)
	_row_houses(mb)
	_back_row(mb, w)
	_across_street(mb)
	_street_life(mb)


## Rumah pemilik garasi tepat di kanan toko: teras berkursi, pagar besi dengan
## gerbang geser, dan toren di belakang.
static func _owner_house(mb: MeshBuilder, w: float) -> void:
	var x0: float = w + 0.2
	var hw: float = 6.2
	var cx: float = x0 + hw * 0.5
	_paving(mb, x0, x0 + hw + 0.35, FENCE_Z, 0.0, Palette.PAVING)
	_house(mb, _at(Vector3(cx, 0.0, 1.5)), {
		"w": hw, "dpt": 7.0, "h": 2.8, "wall": Palette.HOUSE_CREAM, "ridge": &"x", "rise": 1.3,
		"ov": 0.35, "ov_side": 0.12, "porch": 1.5, "door": 0.0, "windows": [-1.95, 1.95], "chairs": true})
	for px: float in [cx - 2.6, cx - 1.5, cx + 1.5, cx + 2.6]:
		_pot(mb, Vector3(px, 0.08, 0.15), Palette.TERRACOTTA, Palette.LEAF if px < cx else Palette.LEAF_DEEP)
	_fence(mb, x0 + 0.1, x0 + hw + 0.35, FENCE_Z, Palette.HOUSE_CREAM, [[cx - 1.1, cx + 1.3, true]])
	_water_tower(mb, Vector3(cx + 2.4, 0.0, 9.3), Palette.WATER_TANK, 2.6)
	_bin(mb, Vector3(x0 + hw, 0.0, -0.45), Palette.OJOL_GREEN.darkened(0.15))


## Tetangga kiri: rumah mint dengan carport terbuka, motor parkir, jemuran, dan
## pagar tanaman rendah di batas garasi. Semuanya cukup jauh atau cukup rendah
## supaya tidak menutupi toko.
static func _left_neighbor(mb: MeshBuilder) -> void:
	_paving(mb, -9.4, -3.55, FENCE_Z, 1.6, Palette.PAVING)
	mb.box(_at(Vector3(-2.1, -0.026, 1.15)), Vector3(2.9, 0.028, 4.0), Palette.CONCRETE_DARK)
	_house(mb, _at(Vector3(-6.25, 0.0, 1.6)), {
		"w": 5.2, "dpt": 6.0, "h": 2.6, "wall": Palette.HOUSE_MINT, "ridge": &"x", "rise": 1.15,
		"ov": 0.35, "porch": 0.9, "door": 0.9, "windows": [-1.4], "side_windows": [1.6, 4.3]})
	_fence(mb, -9.4, -3.55, FENCE_Z, Palette.HOUSE_MINT, [[-5.75, -4.3, true]])
	_motorbike(mb, Vector3(-2.3, 0.0, 0.9), 0.0, Palette.STRAWBERRY)
	# Bak tanaman rendah berisi semak bulat di batas garasi.
	mb.box(_at(Vector3(-0.6, (0.16 + Y_GROUND) * 0.5, 3.6)), Vector3(0.3, 0.16 - Y_GROUND, 4.8), Palette.CONCRETE_DARK)
	for i in 8:
		var hz: float = 1.5 + 0.6 * float(i)
		mb.ellipsoid(_at(Vector3(-0.6, 0.3, hz)), Vector3(0.2, 0.17, 0.3), Palette.LEAF if i % 2 == 0 else Palette.LEAF_DEEP, 7, 4)
	_clothesline(mb, -2.9, 3.4, 6.2)


## Rumah-rumah lain sederetan toko, ke kiri dan ke kanan.
static func _row_houses(mb: MeshBuilder) -> void:
	# Kanan: rumah persik berpelana depan dengan pohon mangga di halaman.
	_paving(mb, 13.2, 15.2, FENCE_Z, 2.8, Palette.PAVING)
	_house(mb, _at(Vector3(13.6, 0.0, 2.8)), {
		"w": 5.6, "dpt": 6.4, "h": 2.65, "wall": Palette.HOUSE_PEACH, "ridge": &"z", "rise": 1.4,
		"ov": 0.3, "door": 0.9, "windows": [-1.4], "canopy": true})
	_fence(mb, 9.95, 16.8, FENCE_Z, Palette.HOUSE_PEACH, [[13.2, 15.2, false]])
	_mango_tree(mb, Vector3(11.3, 0.0, 1.2), 1.0)
	_house(mb, _at(Vector3(20.4, 0.0, 2.0)), {
		"w": 5.6, "dpt": 6.2, "h": 2.6, "wall": Palette.HOUSE_BUTTER, "ridge": &"x", "rise": 1.2,
		"ov": 0.35, "porch": 1.0, "door": -0.6, "windows": [1.4]})
	_fence(mb, 17.3, 23.6, FENCE_Z, Palette.HOUSE_BUTTER, [[20.0, 22.0, false]])
	# Kiri: rumah biru berpelana depan, pohon pisang di batas pagar.
	_paving(mb, -14.4, -12.6, FENCE_Z, 2.0, Palette.PAVING)
	_house(mb, _at(Vector3(-13.2, 0.0, 2.0)), {
		"w": 5.4, "dpt": 6.0, "h": 2.6, "wall": Palette.HOUSE_SKY, "ridge": &"z", "rise": 1.35,
		"ov": 0.3, "door": -1.0, "windows": [1.2], "canopy": true, "side_windows": [2.5]})
	_fence(mb, -16.4, -9.9, FENCE_Z, Palette.HOUSE_SKY, [[-14.4, -12.6, false]])
	_banana_tree(mb, Vector3(-10.3, 0.0, 0.5), 0.3)
	_banana_tree(mb, Vector3(-9.7, 0.0, 1.5), 1.2)
	_house(mb, _at(Vector3(-19.8, 0.0, 1.8)), {
		"w": 5.6, "dpt": 6.0, "h": 2.6, "wall": Palette.HOUSE_PEACH, "ridge": &"x", "rise": 1.2,
		"ov": 0.35, "porch": 0.9, "door": 0.8, "windows": [-1.3], "side_windows": [2.0]})
	_fence(mb, -23.0, -16.7, FENCE_Z, Palette.HOUSE_PEACH, [[-21.0, -19.0, false]])
	_bin(mb, Vector3(-9.6, 0.0, -0.45), Palette.PASTEL_PERIWINKLE.darkened(0.25))


## Deretan rumah di belakang (menghadap jalan sebelah): kamera melihat dinding
## belakang dan atapnya. Di halaman belakang toko ada toren kecil dan pohon pisang.
static func _back_row(mb: MeshBuilder, w: float) -> void:
	var specs: Array = [
		[-13.2, 5.6, Palette.HOUSE_PEACH, &"x"], [-6.2, 5.6, Palette.HOUSE_BUTTER, &"x"],
		[1.4, 6.0, Palette.HOUSE_SKY, &"z"], [8.6, 6.2, Palette.HOUSE_MINT, &"x"], [15.6, 5.4, Palette.HOUSE_CREAM, &"z"],
	]
	for s: Array in specs:
		_house(mb, _at_yaw(Vector3(float(s[0]), 0.0, 17.0), PI), {
			"w": float(s[1]), "dpt": 6.0, "h": 2.6, "wall": s[2], "ridge": s[3], "rise": 1.2, "ov": 0.3,
			"back_windows": [-1.3, 1.4], "front_detail": false})
	_water_tower(mb, Vector3(w * 0.5 + 0.1, 0.0, 7.6), Palette.WATER_TANK_BLUE, 2.0)
	_banana_tree(mb, Vector3(-1.4, 0.0, 8.6), 0.9)
	_shrub(mb, Vector3(5.8, 0.0, 9.8), 0.7)
	_shrub(mb, Vector3(-4.6, 0.0, 9.6), 0.6)
	_mango_tree(mb, Vector3(-8.8, 0.0, 9.9), 0.9)


## Seberang jalan: rumah-rumah yang menghadap jalan (kamera melihat punggung dan
## atapnya), dan taman kecil berbangku dengan pohon mangga tepat di seberang toko.
static func _across_street(mb: MeshBuilder) -> void:
	var specs: Array = [
		[-20.2, 5.6, Palette.HOUSE_BUTTER, &"x"], [-13.0, 5.6, Palette.HOUSE_CREAM, &"x"],
		[-5.6, 5.8, Palette.HOUSE_PEACH, &"z"], [7.6, 6.0, Palette.HOUSE_MINT, &"x"], [15.0, 5.6, Palette.HOUSE_SKY, &"z"],
	]
	for s: Array in specs:
		var cx: float = float(s[0])
		var hw: float = float(s[1])
		_house(mb, _at_yaw(Vector3(cx, 0.0, -6.9), PI), {
			"w": hw, "dpt": 6.0, "h": 2.6, "wall": s[2], "ridge": s[3], "rise": 1.2, "ov": 0.3,
			"back_windows": [-1.2, 1.5], "front_detail": false})
		_fence(mb, cx - hw * 0.5 - 0.3, cx + hw * 0.5 + 0.3, FAR_FENCE_Z, s[2], [[cx - 0.8, cx + 0.8, true]])
	# Taman kecil: rumput, bangku, pohon mangga besar, dan bunga.
	_paving(mb, -2.6, 4.4, FAR_FENCE_Z - 2.6, FAR_FENCE_Z + 0.2, Palette.GRASS_DEEP)
	_mango_tree(mb, Vector3(1.0, 0.0, -7.5), 1.15)
	_bench(mb, Vector3(-0.6, 0.0, -5.75), 0.0)
	_shrub(mb, Vector3(3.4, 0.0, -6.0), 0.5)
	_shrub(mb, Vector3(-2.0, 0.0, -6.6), 0.45)


## Tiang listrik berkabel di seberang jalan, polisi tidur, dan tutup gorong-gorong.
static func _street_life(mb: MeshBuilder) -> void:
	var tops: Array[Vector3] = []
	for px: float in [-23.0, -9.0, 4.6, 18.2, 32.0]:
		tops.append(_pole(mb, Vector3(px, 0.0, POLE_Z), POLE_H))
	for i in tops.size() - 1:
		for dz: float in [-0.3, 0.3]:
			_cable(mb, tops[i] + Vector3(0.0, 0.0, dz), tops[i + 1] + Vector3(0.0, 0.0, dz), 0.25)
	_bump(mb, Vector2(-5.0, ROAD_FAR), Vector2(-5.0, ROAD_NEAR))
	mb.disc(_at(Vector3(9.5, Y_ROAD + 0.004, -3.0)), 0.32, Palette.ASPHALT.darkened(0.22), Palette.ASPHALT.darkened(0.12), 12)
	mb.disc(_at(Vector3(-13.0, Y_ROAD + 0.004, -2.4)), 0.32, Palette.ASPHALT.darkened(0.22), Palette.ASPHALT.darkened(0.12), 12)


# ===========================================================================
# TIER 2 — PERTOKOAN RUKO
# ===========================================================================

## Toko adalah ruko paling ujung di deretan ruko dua lantai yang menghadap jalan
## dua lajur. Di sampingnya jalan kecil masuk kampung; di balik deretan ruko ada
## gang dan rumah-rumah kampung; dari ruko di seberang jalan hanya atapnya yang
## tampak. Ruko di sisi kiri layar (x < 0) dimulai di seberang jalan kampung,
## cukup jauh supaya tidak menutupi toko.
static func _tier2(mb: MeshBuilder, w: float) -> void:
	_t2_streets(mb)
	_t2_row_east(mb, w)
	_t2_row_west(mb)
	_t2_kampung(mb)
	_t2_across(mb)
	_t2_street_life(mb)


## Jalan utama bermarka, pelataran parkir ruko di atas got tertutup, jalan
## kampung di samping toko, gang belakang, dan trotoar seberang.
static func _t2_streets(mb: MeshBuilder) -> void:
	var lane_e: float = T2_LANE_X1 + GUTTER_W
	var lane_w: float = T2_LANE_X0 - GUTTER_W
	_flat(mb, ROAD_X0, ROAD_X1, T2_ROAD_FAR, T2_ROAD_NEAR, Y_ROAD, Palette.ASPHALT)
	for r: Rect2 in [Rect2(-12.5, -7.9, 2.2, 1.0), Rect2(4.6, -4.4, 1.6, 1.2), Rect2(16.0, -7.4, 2.6, 0.9), Rect2(-20.0, -3.7, 1.8, 0.8)]:
		_flat(mb, r.position.x, r.end.x, r.position.y, r.end.y, Y_ROAD + 0.002, Palette.ASPHALT_PATCH)
	# Marka: garis tepi (putus di mulut jalan kampung), garis tengah putus-putus,
	# dan zebra cross.
	var y_paint: float = Y_ROAD + 0.004
	var near_line: float = T2_ROAD_NEAR - 0.22
	for span: Vector2 in [Vector2(ROAD_X0, T2_LANE_X0 - 0.3), Vector2(T2_LANE_X1 + 0.3, ROAD_X1)]:
		_flat(mb, span.x, span.y, near_line - 0.04, near_line + 0.04, y_paint, Palette.ROAD_PAINT)
	var far_line: float = T2_ROAD_FAR + 0.22
	_flat(mb, ROAD_X0, ROAD_X1, far_line - 0.04, far_line + 0.04, y_paint, Palette.ROAD_PAINT)
	var mid: float = (T2_ROAD_NEAR + T2_ROAD_FAR) * 0.5
	var x: float = ROAD_X0
	while x < ROAD_X1:
		if x + 1.6 < T2_ZEBRA_X0 - 0.5 or x > T2_ZEBRA_X1 + 0.5:
			_flat(mb, x, x + 1.6, mid - 0.06, mid + 0.06, y_paint, Palette.ROAD_PAINT)
		x += 3.2
	var zz: float = T2_ROAD_NEAR - 0.4
	while zz - 0.4 > T2_ROAD_FAR + 0.35:
		_flat(mb, T2_ZEBRA_X0, T2_ZEBRA_X1, zz - 0.4, zz, y_paint, Palette.ROAD_PAINT)
		zz -= 0.8
	# Pelataran parkir berpaving, got tertutup berkisi di tepinya, dan bibir jalan.
	for span2: Vector2 in [Vector2(lane_e, ROAD_X1), Vector2(ROAD_X0, lane_w)]:
		_pavers(mb, span2.x, span2.y, T2_APRON_Z, 0.0)
		_flat(mb, span2.x, span2.y, T2_ROAD_NEAR, T2_APRON_Z, Y_YARD + 0.012, Palette.CONCRETE)
		_ledge(mb, span2.x, span2.y, T2_ROAD_NEAR + 0.04, 0.08, Y_GROUND, 0.02, Palette.CONCRETE_DARK)
		var gx: float = span2.x + 1.2
		while gx < span2.y - 0.8:
			_flat(mb, gx, gx + 0.6, T2_ROAD_NEAR + 0.12, T2_APRON_Z - 0.06, Y_YARD + 0.014, Palette.GUTTER)
			gx += 3.0
	# Lorong berpaving di samping toko sampai gang belakang.
	_pavers(mb, lane_e, -RoomFactory.WALL_THICK, 0.0, T2_ALLEY_Z0)
	# Jalan kampung bergot di kedua tepinya; gotnya terputus di mulut gang.
	_flat(mb, T2_LANE_X0, T2_LANE_X1, T2_ROAD_NEAR, ROAD_X1, Y_ROAD, Palette.ASPHALT)
	for gz: Vector2 in [Vector2(T2_ROAD_NEAR, T2_ALLEY_Z0), Vector2(T2_ALLEY_Z1, ROAD_X1)]:
		_gutter_z(mb, T2_LANE_X1, 1.0, gz.x, gz.y)
		_gutter_z(mb, T2_LANE_X0, -1.0, gz.x, gz.y)
	# Gang belakang (beton) di balik deretan ruko.
	_flat(mb, T2_LANE_X1, ROAD_X1, T2_ALLEY_Z0, T2_ALLEY_Z1, Y_YARD, Palette.CONCRETE)
	_flat(mb, ROAD_X0, T2_LANE_X0, T2_ALLEY_Z0, T2_ALLEY_Z1, Y_YARD, Palette.CONCRETE)
	# Got dan trotoar di seberang jalan.
	_gutter(mb, T2_ROAD_FAR, -1.0)
	for span3: Vector2 in [Vector2(-6.0, -4.0), Vector2(2.0, 4.0), Vector2(12.0, 14.0)]:
		_slab(mb, span3.x, span3.y, T2_ROAD_FAR, -1.0)
	var walk_near: float = T2_ROAD_FAR - GUTTER_W
	_ledge(mb, ROAD_X0, ROAD_X1, (walk_near + T2_WALK_Z) * 0.5, walk_near - T2_WALK_Z, Y_GROUND, 0.09, Palette.PAVING)


## Deretan ruko di samping toko (kiri atas layar), menempel dinding toko.
## Masing-masing punya warna, papan nama, dan keadaan pintu sendiri.
static func _t2_row_east(mb: MeshBuilder, w: float) -> void:
	var specs: Array[Dictionary] = [
		{"w": 3.8, "wall": Palette.RUKO_GREY, "sign": Palette.SIGN_GREEN, "logo": &"cross", "door": &"open",
			"goods": [Palette.FLOUR_WHITE, Palette.PASTEL_MINT, Palette.PASTEL_PERIWINKLE, Palette.ROSY_CHEEK],
			"counter": true, "upper": &"windows", "ac": true, "party_wall": true},
		{"w": 3.6, "wall": Palette.RUKO_SAND, "sign": Palette.SIGN_RED, "logo": &"phone", "door": &"open",
			"goods": [Palette.CABLE.lightened(0.25), Palette.PASTEL_PERIWINKLE, Palette.ROSY_CHEEK, Palette.FLOUR_WHITE],
			"counter": true, "upper": &"balcony", "tank": Palette.WATER_TANK_BLUE},
		{"w": 4.0, "wall": Palette.HOUSE_CREAM, "sign": Palette.SIGN_YELLOW, "logo": &"bars", "door": &"open",
			"goods": [Palette.HONEY, Palette.STRAWBERRY, Palette.MATCHA, Palette.BUTTER_YELLOW, Palette.PASTEL_PERIWINKLE],
			"sachets": true, "upper": &"windows", "ac": true},
		{"w": 3.6, "wall": Palette.RUKO_BLUSH, "sign": Palette.SIGN_BLUE, "logo": &"bubbles", "door": &"half",
			"goods": [Palette.FLOUR_WHITE, Palette.HOUSE_SKY, Palette.PASTEL_MINT], "upper": &"windows", "tank": Palette.WATER_TANK},
		{"w": 3.8, "wall": Palette.RUKO_LILAC, "sign": Palette.SIGN_PURPLE, "logo": &"stripes", "door": &"closed", "upper": &"balcony"},
		{"w": 3.8, "wall": Palette.RUKO_SAGE, "sign": Palette.SIGN_ORANGE, "logo": &"bars", "door": &"closed", "upper": &"windows", "ac": true},
		{"w": 4.0, "wall": Palette.HOUSE_SKY, "sign": Palette.SIGN_RED, "logo": &"phone", "door": &"closed", "upper": &"windows"},
	]
	var x: float = w + RoomFactory.WALL_THICK + 0.02
	for s: Dictionary in specs:
		var uw: float = float(s["w"])
		_ruko(mb, _at(Vector3(x + uw * 0.5, 0.0, 0.0)), s)
		x += uw


## Deretan ruko di seberang jalan kampung (kanan bawah layar). Toren di atapnya
## diletakkan di sisi yang jauh dari toko.
static func _t2_row_west(mb: MeshBuilder) -> void:
	var specs: Array[Dictionary] = [
		{"w": 3.8, "wall": Palette.RUKO_SAGE, "sign": Palette.SIGN_ORANGE, "logo": &"bars", "door": &"open",
			"goods": [Palette.HONEY, Palette.STRAWBERRY, Palette.CUSTARD, Palette.MATCHA], "counter": true,
			"upper": &"windows", "ac": true, "tank": Palette.WATER_TANK, "tank_x": -0.25},
		{"w": 3.8, "wall": Palette.HOUSE_BUTTER, "sign": Palette.SIGN_BLUE, "logo": &"phone", "door": &"half",
			"goods": [Palette.CABLE.lightened(0.25), Palette.ROSY_CHEEK, Palette.PASTEL_MINT], "upper": &"balcony"},
		{"w": 3.6, "wall": Palette.RUKO_GREY, "sign": Palette.SIGN_RED, "logo": &"stripes", "door": &"closed", "upper": &"windows", "ac": true},
		{"w": 4.0, "wall": Palette.RUKO_BLUSH, "sign": Palette.SIGN_GREEN, "logo": &"bubbles", "door": &"closed", "upper": &"windows"},
	]
	var x: float = T2_LANE_X0 - GUTTER_W - 0.2
	for s: Dictionary in specs:
		var uw: float = float(s["w"])
		_ruko(mb, _at(Vector3(x - uw * 0.5, 0.0, 0.0)), s)
		x -= uw


## Rumah-rumah kampung di balik gang belakang, menghadap gang (dan kamera): teras,
## pintu, jendela, pagar besi, dan tanaman di halaman.
static func _t2_kampung(mb: MeshBuilder) -> void:
	var fz: float = T2_KAMPUNG_FENCE_Z
	var houses: Array = [
		[1.6, 5.0, Palette.HOUSE_PEACH, &"x", 0.9, 0.9, [-1.4]],
		[7.6, 5.6, Palette.HOUSE_MINT, &"z", 0.0, -0.9, [1.3]],
		[14.0, 5.2, Palette.HOUSE_BUTTER, &"x", 0.9, -0.8, [1.3]],
		[20.4, 5.6, Palette.HOUSE_SKY, &"z", 0.0, 1.0, [-1.2]],
		[-8.9, 5.2, Palette.HOUSE_CREAM, &"x", 0.9, 0.8, [-1.3]],
		[-15.3, 5.6, Palette.HOUSE_PEACH, &"z", 0.0, -1.0, [1.2]],
	]
	for hs: Array in houses:
		var cx: float = float(hs[0])
		var hw: float = float(hs[1])
		var ridge: StringName = hs[3]
		var door: float = float(hs[5])
		_house(mb, _at(Vector3(cx, 0.0, fz + 1.05)), {
			"w": hw, "dpt": 6.0, "h": 2.6, "wall": hs[2], "ridge": ridge, "rise": 1.2 if ridge == &"x" else 1.35,
			"ov": 0.3, "porch": float(hs[4]), "door": door, "windows": hs[6], "canopy": ridge == &"z"})
		_fence(mb, cx - hw * 0.5 - 0.3, cx + hw * 0.5 + 0.3, fz, hs[2], [[cx + door - 0.8, cx + door + 0.8, false]])
	_mango_tree(mb, Vector3(10.9, 0.0, 9.4), 0.9)
	_shrub(mb, Vector3(4.6, 0.0, 8.6), 0.5)
	_shrub(mb, Vector3(17.1, 0.0, 8.6), 0.45)
	_shrub(mb, Vector3(-12.0, 0.0, 8.5), 0.5)


## Seberang jalan: deretan kios satu lantai beratap seng yang menghadap jalan, agak
## mundur di balik trotoar lebar. Kamera hanya melihat punggung dan atapnya, dan
## kios cukup rendah supaya seluruh lebar jalan beserta markanya tetap terlihat.
static func _t2_across(mb: MeshBuilder) -> void:
	var walls: Array[Color] = [Palette.RUKO_GREY, Palette.HOUSE_CREAM, Palette.RUKO_SAND, Palette.RUKO_SAGE, Palette.RUKO_BLUSH, Palette.HOUSE_SKY]
	var x: float = -21.0
	var i: int = 0
	while x < 21.0:
		var kw: float = 3.2 + 0.4 * float(i % 3)
		_house(mb, _at_yaw(Vector3(x + kw * 0.5, 0.0, T2_WALK_Z - 0.2), PI), {
			"w": kw, "dpt": 4.0, "h": 2.6, "wall": walls[i % walls.size()], "ridge": &"x", "rise": 0.5, "ov": 0.3,
			"roof": Palette.ZINC_ROOF, "roof_deep": Palette.ZINC_ROOF.darkened(0.15), "back_windows": [-0.6],
			"front_detail": false})
		x += kw + 0.1
		i += 1


## Motor parkir menghadap toko, gerobak bakso, ketapang kencana di pot beton,
## tiang listrik di seberang jalan, polisi tidur di jalan kampung, tutup
## gorong-gorong, dan pot bunga di samping toko.
static func _t2_street_life(mb: MeshBuilder) -> void:
	var bikes: Array = [
		[4.3, Palette.STRAWBERRY], [5.1, Palette.PASTEL_PERIWINKLE.darkened(0.25)], [8.3, Palette.TIRE],
		[11.4, Palette.OJOL_GREEN], [15.5, Palette.HONEY], [16.3, Palette.FLOUR_WHITE.darkened(0.12)],
		[-7.1, Palette.SIGN_BLUE], [-10.9, Palette.STRAWBERRY_DEEP], [-11.7, Palette.PASTEL_MINT.darkened(0.2)],
	]
	for b: Array in bikes:
		_motorbike(mb, Vector3(float(b[0]), 0.0, -1.3), PI, b[1])
	_cart(mb, Vector3(13.2, 0.0, -1.45), 0.0, Palette.SIGN_BLUE)
	for tx: float in [6.92, 18.12, -9.8]:
		_umbrella_tree(mb, Vector3(tx, 0.0, T2_APRON_Z + 0.4))
	var tops: Array[Vector3] = []
	for px: float in [-24.0, -11.0, 6.2, 19.0, 32.0]:
		tops.append(_pole(mb, Vector3(px, 0.0, T2_POLE_Z), T2_POLE_H))
	for i in tops.size() - 1:
		for dz: float in [-0.3, 0.3]:
			_cable(mb, tops[i] + Vector3(0.0, 0.0, dz), tops[i + 1] + Vector3(0.0, 0.0, dz), 0.3)
	_bump(mb, Vector2(T2_LANE_X0, 3.4), Vector2(T2_LANE_X1, 3.4))
	mb.disc(_at(Vector3(-9.0, Y_ROAD + 0.004, -4.0)), 0.32, Palette.ASPHALT.darkened(0.22), Palette.ASPHALT.darkened(0.12), 12)
	mb.disc(_at(Vector3(12.6, Y_ROAD + 0.004, -7.0)), 0.32, Palette.ASPHALT.darkened(0.22), Palette.ASPHALT.darkened(0.12), 12)
	_pot(mb, Vector3(-0.8, 0.0, -0.3), Palette.TERRACOTTA, Palette.ROSY_CHEEK)
	_pot(mb, Vector3(-0.85, 0.0, 2.6), Palette.TERRACOTTA, Palette.LEAF)
	_bin(mb, Vector3(-1.0, 0.0, 5.6), Palette.OJOL_GREEN.darkened(0.15))


## Lantai dasar ruko toko sendiri, hanya tampil saat kamera di lantai atas (dapur
## Tier 2): muka toko berkaca dengan tenda bergaris dan papan roti, jendela
## samping, dan dak di belakang dapur dengan toren. Semuanya di bawah lantai
## dapur kecuali dak di belakangnya, jadi tidak menutupi dapur.
static func _own_t2(mb: MeshBuilder, w: float, upper_d: float) -> void:
	var t: float = RoomFactory.WALL_THICK
	var x0: float = -t
	var x1: float = w + t
	var top: float = STOREY - 0.02
	var wall: Color = Palette.HOUSE_BUTTER
	var nf: Vector3 = Vector3(0.0, 0.0, -1.0)
	var front: Transform3D = _at(Vector3(w * 0.5, 0.0, -t))
	mb.box(_at(Vector3((x0 + x1) * 0.5, (top + Y_GROUND) * 0.5, (T2_ALLEY_Z0 - t) * 0.5)), Vector3(x1 - x0, top - Y_GROUND, T2_ALLEY_Z0 + t), wall)
	# Muka toko: dua kaca etalase mengapit pintu kaca di petak pintu toko.
	for gx: Vector2 in [Vector2(-w * 0.5 + 0.12, -0.55), Vector2(0.55, w * 0.5 - 0.12)]:
		_panel(mb, front, Vector2((gx.x + gx.y) * 0.5, 1.15), Vector2(gx.y - gx.x + 0.1, 1.75), -0.01, nf, Palette.FLOUR_WHITE)
		_panel(mb, front, Vector2((gx.x + gx.y) * 0.5, 1.15), Vector2(gx.y - gx.x - 0.04, 1.61), -0.015, nf, Palette.WINDOW_GLASS)
	_panel(mb, front, Vector2(0.0, 1.05), Vector2(0.98, 2.1), -0.01, nf, Palette.DARK_CHOCOLATE)
	_panel(mb, front, Vector2(0.0, 1.05), Vector2(0.84, 1.98), -0.015, nf, Palette.WINDOW_GLASS.lightened(0.1))
	# Tenda bergaris karamel-krem di atas muka toko, dengan roti cokelat di lis
	# depannya (bagian muka di bawah tenda tidak tampak kamera).
	var stripes: int = 10
	var aw: float = w + 0.2
	var n_awn: Vector3 = Vector3(0.0, 0.64, -0.28).normalized()
	for k in stripes:
		var xa: float = -aw * 0.5 + aw * float(k) / float(stripes)
		var xb: float = -aw * 0.5 + aw * float(k + 1) / float(stripes)
		var col: Color = Palette.CARAMEL if k % 2 == 0 else Palette.FLOUR_WHITE
		mb.quad(front * Vector3(xa, 2.44, -0.06), front * Vector3(xb, 2.44, -0.06), front * Vector3(xb, 2.16, -0.7), front * Vector3(xa, 2.16, -0.7), n_awn, col)
	_panel(mb, front, Vector2(0.0, 2.04), Vector2(aw, 0.24), -0.71, nf, Palette.CARAMEL)
	mb.ellipsoid(front * _at(Vector3(-0.55, 2.04, -0.73)), Vector3(0.15, 0.075, 0.03), Palette.GOLDEN_CRUST, 8, 3)
	_panel(mb, front, Vector2(0.12, 2.08), Vector2(0.8, 0.055), -0.72, nf, Palette.BUTTER_YELLOW)
	_panel(mb, front, Vector2(0.02, 2.0), Vector2(0.6, 0.045), -0.72, nf, Palette.BUTTER_YELLOW)
	# Sisi lorong: jendela berteralis dan pipa talang.
	var side: Transform3D = _at_yaw(Vector3(x0, 0.0, 3.2), PI * 0.5)
	_window_on(mb, side * _face(Vector3(0.0, 1.45, 0.0), 0.0), Vector2(0.9, 0.8))
	_grille(mb, side, 0.0, 1.45, 0.9, 0.8)
	mb.box(_at(Vector3(x0 - 0.04, top * 0.5, 0.4)), Vector3(0.07, top, 0.07), Palette.CONCRETE_DARK)
	# Dak di belakang dapur: dinding pembatas dan toren.
	var deck_z0: float = upper_d + t
	mb.box(_at(Vector3(x0 + 0.05, top + PARAPET * 0.5, (deck_z0 + T2_ALLEY_Z0) * 0.5)), Vector3(0.1, PARAPET, T2_ALLEY_Z0 - deck_z0), wall)
	mb.box(_at(Vector3((x0 + x1) * 0.5, top + PARAPET * 0.5, T2_ALLEY_Z0 - 0.05)), Vector3(x1 - x0, PARAPET, 0.1), wall)
	_water_tower(mb, Vector3(w - 0.7, top, T2_ALLEY_Z0 - 0.8), Palette.WATER_TANK_BLUE, 0.35)


# ===========================================================================
# TIER 3 — JALAN RAYA KOTA
# ===========================================================================

## Toko bakery mandiri di tepi jalan raya kota. Kamera hanya melihat sekitar toko
## (layar mendatar mengikuti z - x, tegak mengikuti x + z), jadi isinya dipusatkan
## di trotoar, minimarket di sebelah, teras kafe dan parkir di samping, dan
## halaman servis di belakang; jalan raya dan kampus tampak di tepi layar.
static func _tier3(mb: MeshBuilder, w: float) -> void:
	_t3_ground(mb, w)
	_t3_road(mb)
	_t3_left(mb)
	_t3_right(mb)
	_t3_back(mb)
	_t3_street_life(mb)


## Lantai luar: teras depan toko berubin terakota, trotoar berubin dua warna
## dengan ubin pemandu kuning, lorong samping dan pelataran berpaving, teras kafe
## berlantai papan, parkir beraspal bergaris, halaman servis dan gang beton.
static func _t3_ground(mb: MeshBuilder, w: float) -> void:
	var t: float = RoomFactory.WALL_THICK
	_tiles(mb, -t, w + t, T3_YARD_Z, 0.0, Y_YARD, Palette.TERRACOTTA.lightened(0.35), Palette.TERRACOTTA.lightened(0.45), 0.6, 0.6)
	_tiles(mb, ROAD_X0, ROAD_X1, T3_ROAD_NEAR, T3_YARD_Z, Y_YARD, Palette.CONCRETE.lightened(0.06), Palette.CONCRETE.darkened(0.04), 1.2, 0.93)
	_flat(mb, ROAD_X0, ROAD_X1, -3.05, -2.75, Y_YARD + 0.003, Palette.TACTILE)
	_pavers(mb, w + t, T3_MART_X0, T3_YARD_Z, 6.1)
	_pavers(mb, T3_MART_X0, ROAD_X1, T3_YARD_Z, T3_MART_Z)
	_pavers(mb, ROAD_X0, T3_LOT_X, T3_YARD_Z, 0.0)
	var x: float = T3_TERRACE_X
	var k: int = 0
	while x < -t - 0.01:
		var x1: float = minf(x + 0.3, -t)
		_flat(mb, x, x1, T3_YARD_Z, 6.1, Y_YARD + 0.01, Palette.PINE_WOOD if k % 2 == 0 else Palette.PINE_WOOD.darkened(0.08))
		x = x1
		k += 1
	_flat(mb, T3_LOT_X, T3_TERRACE_X, T3_YARD_Z, 6.1, Y_ROAD, Palette.ASPHALT)
	for bx: float in [-11.4, -9.1, -6.8, -4.85]:
		_flat(mb, bx - 0.04, bx + 0.04, 0.4, 5.6, Y_ROAD + 0.004, Palette.ROAD_PAINT)
	_flat(mb, T3_TERRACE_X, T3_MART_X0, 6.1, T3_BACK_Z, Y_YARD, Palette.CONCRETE)
	_flat(mb, ROAD_X0, ROAD_X1, T3_BACK_Z, T3_ALLEY_Z, Y_YARD, Palette.CONCRETE.darkened(0.05))


## Jalan raya empat lajur: dua lajur di sisi toko bermarka dengan zebra cross,
## bibir trotoar, median berumput, dua lajur seberang, dan trotoar seberang.
static func _t3_road(mb: MeshBuilder) -> void:
	_flat(mb, ROAD_X0, ROAD_X1, T3_ROAD_FAR, T3_ROAD_NEAR, Y_ROAD, Palette.ASPHALT)
	_flat(mb, ROAD_X0, ROAD_X1, T3_ROAD2_FAR, T3_MEDIAN_Z, Y_ROAD, Palette.ASPHALT)
	_flat(mb, ROAD_X0, ROAD_X1, T3_ROAD2_FAR - 2.2, T3_ROAD2_FAR, Y_YARD, Palette.PAVING)
	for r: Rect2 in [Rect2(-14.0, -11.0, 2.4, 0.9), Rect2(3.0, -7.4, 1.4, 1.0), Rect2(18.0, -6.6, 2.0, 0.8)]:
		_flat(mb, r.position.x, r.end.x, r.position.y, r.end.y, Y_ROAD + 0.002, Palette.ASPHALT_PATCH)
	var y_paint: float = Y_ROAD + 0.004
	for ez: float in [T3_ROAD_NEAR - 0.2, T3_ROAD_FAR + 0.2]:
		_flat(mb, ROAD_X0, ROAD_X1, ez - 0.05, ez + 0.05, y_paint, Palette.ROAD_PAINT)
	var mid: float = (T3_ROAD_NEAR + T3_ROAD_FAR) * 0.5
	var x: float = ROAD_X0
	while x < ROAD_X1:
		if x + 2.0 < T3_ZEBRA_X0 - 0.5 or x > T3_ZEBRA_X1 + 0.5:
			_flat(mb, x, x + 2.0, mid - 0.06, mid + 0.06, y_paint, Palette.ROAD_PAINT)
		x += 4.0
	var zz: float = T3_ROAD_NEAR - 0.45
	while zz - 0.45 > T3_ROAD_FAR + 0.3:
		_flat(mb, T3_ZEBRA_X0, T3_ZEBRA_X1, zz - 0.45, zz, y_paint, Palette.ROAD_PAINT)
		zz -= 0.9
	mb.disc(_at(Vector3(-7.5, Y_ROAD + 0.004, -6.2)), 0.32, Palette.ASPHALT.darkened(0.22), Palette.ASPHALT.darkened(0.12), 12)
	_ledge(mb, ROAD_X0, ROAD_X1, T3_ROAD_NEAR + 0.06, 0.12, Y_GROUND, 0.12, Palette.CONCRETE_DARK)
	_ledge(mb, ROAD_X0, ROAD_X1, (T3_ROAD_FAR + T3_MEDIAN_Z) * 0.5, T3_ROAD_FAR - T3_MEDIAN_Z, Y_GROUND, 0.15, Palette.CONCRETE)
	_flat(mb, ROAD_X0, ROAD_X1, T3_MEDIAN_Z + 0.12, T3_ROAD_FAR - 0.12, 0.152, Palette.GRASS_DEEP)


## Sisi kiri atas layar: minimarket bermuka kaca dengan pelataran parkir motor,
## lalu kedai kopi dan bank dua lantai.
static func _t3_left(mb: MeshBuilder) -> void:
	_minimarket(mb, _at(Vector3((T3_MART_X0 + T3_MART_X1) * 0.5, 0.0, T3_MART_Z)), T3_MART_X1 - T3_MART_X0, T3_BACK_Z - T3_MART_Z)
	var x: float = T3_MART_X1 + 0.4
	var specs: Array[Dictionary] = [
		{"w": 6.2, "dpt": T3_BACK_Z, "wall": Palette.RUKO_SAND, "sign": Palette.SIGN_ORANGE, "logo": &"bubbles", "door": &"glass",
			"goods": [Palette.CARAMEL, Palette.FLOUR_WHITE, Palette.HONEY], "upper": &"windows", "ac": true},
		{"w": 7.0, "dpt": T3_BACK_Z, "wall": Palette.FLOUR_WHITE.darkened(0.06), "sign": Palette.SIGN_BLUE, "logo": &"bars", "door": &"glass",
			"goods": [Palette.HOUSE_SKY, Palette.FLOUR_WHITE], "upper": &"windows"},
	]
	for s: Dictionary in specs:
		var uw: float = float(s["w"])
		_ruko(mb, _at(Vector3(x + uw * 0.5, 0.0, 0.0)), s)
		x += uw + 0.4


## Sisi kanan bawah layar: teras kafe toko dengan dua meja berpayung dan pot
## tanaman rendah di tepinya, parkir mobil bertembok belakang, lalu gedung dua
## lantai di seberang parkir. Semuanya cukup rendah atau cukup jauh dari toko.
static func _t3_right(mb: MeshBuilder) -> void:
	_parasol_set(mb, Vector3(-3.2, Y_YARD + 0.01, 0.9), Palette.SIGN_GREEN)
	_parasol_set(mb, Vector3(-3.2, Y_YARD + 0.01, 3.7), Palette.CARAMEL)
	var t: float = RoomFactory.WALL_THICK
	mb.box(_at(Vector3((T3_TERRACE_X - t) * 0.5, 0.2, T3_YARD_Z + 0.18)), Vector3(-t - T3_TERRACE_X, 0.4, 0.3), Palette.CONCRETE_DARK)
	mb.box(_at(Vector3(T3_TERRACE_X + 0.15, 0.2, (T3_YARD_Z + 6.1) * 0.5)), Vector3(0.3, 0.4, 6.1 - T3_YARD_Z), Palette.CONCRETE_DARK)
	var hx: float = T3_TERRACE_X + 0.35
	while hx < -0.4:
		mb.ellipsoid(_at(Vector3(hx, 0.5, T3_YARD_Z + 0.18)), Vector3(0.24, 0.14, 0.16), Palette.LEAF_DEEP, 7, 4)
		hx += 0.55
	var hz: float = T3_YARD_Z + 0.6
	while hz < 5.9:
		mb.ellipsoid(_at(Vector3(T3_TERRACE_X + 0.15, 0.5, hz)), Vector3(0.16, 0.14, 0.24), Palette.LEAF if int(hz * 2.0) % 2 == 0 else Palette.LEAF_DEEP, 7, 4)
		hz += 0.55
	_car(mb, Vector3(-7.95, 0.0, 3.2), PI, Palette.SIGN_RED)
	_car(mb, Vector3(-5.85, 0.0, 3.0), PI, Palette.FLOUR_WHITE.darkened(0.08))
	mb.box(_at(Vector3((T3_LOT_X + T3_TERRACE_X) * 0.5, 0.6, 6.05)), Vector3(T3_TERRACE_X - T3_LOT_X, 1.2, 0.15), Palette.CONCRETE)
	_ruko(mb, _at(Vector3(T3_LOT_X - 0.4 - 3.9, 0.0, 0.0)), {"w": 7.8, "dpt": T3_BACK_Z, "wall": Palette.HOUSE_SKY, "sign": Palette.SIGN_PURPLE,
		"logo": &"phone", "door": &"glass", "goods": [Palette.CABLE.lightened(0.25), Palette.PASTEL_PERIWINKLE], "upper": &"windows", "ac": true})


## Belakang toko: halaman servis dengan toren, tabung gas, dan krat roti, tembok
## belakang bergerbang, gang beton, lalu pagar dan taman kampus dengan pohon
## besar serta gedung kuliah di kejauhan.
static func _t3_back(mb: MeshBuilder) -> void:
	_water_tower(mb, Vector3(-3.4, 0.0, 7.4), Palette.WATER_TANK_BLUE, 1.5)
	for i in 4:
		_lpg(mb, Vector3(2.4 + 0.32 * float(i % 2), 0.0, 7.75 + 0.32 * float(i / 2)))
	_crates(mb, Vector3(1.5, 0.0, 8.15), 3, Palette.SIGN_RED)
	_crates(mb, Vector3(0.7, 0.0, 8.15), 2, Palette.SIGN_BLUE)
	mb.box(_at(Vector3((T3_TERRACE_X + T3_MART_X0) * 0.5, 0.8, T3_BACK_Z - 0.08)), Vector3(T3_MART_X0 - T3_TERRACE_X, 1.6, 0.16), Palette.HOUSE_CREAM)
	_panel(mb, _at(Vector3(-1.2, 0.0, T3_BACK_Z - 0.16)), Vector2(0.0, 0.75), Vector2(1.4, 1.5), -0.005, Vector3(0.0, 0.0, -1.0), Palette.DOOR_WOOD)
	_fence(mb, -16.0, 22.0, T3_ALLEY_Z + 0.25, Palette.CONCRETE, [[-1.0, 1.4, false]])
	for tr: Vector3 in [Vector3(-3.0, 13.6, 1.3), Vector3(6.5, 14.2, 1.25), Vector3(14.5, 12.9, 1.2), Vector3(-11.0, 13.2, 1.2)]:
		_mango_tree(mb, Vector3(tr.x, 0.0, tr.y), tr.z)
	_campus(mb, _at(Vector3(4.0, 0.0, 18.5)), 26.0, 8.0, 3)


## Pohon peneduh dan lampu jalan di trotoar, lampu di median, halte, tempat
## sampah pilah, motor dan freezer di pelataran minimarket, dan pot bunga serta
## papan menu di teras toko.
static func _t3_street_life(mb: MeshBuilder) -> void:
	for tx: float in [-13.0, 4.6, 11.8, 19.0]:
		_mango_tree(mb, Vector3(tx, 0.0, -3.7), 0.75)
	for lx: float in [-6.0, 1.2, 8.6, 16.0]:
		_lamp_post(mb, Vector3(lx, 0.0, T3_ROAD_NEAR + 0.3), 4.0, [Vector3(0.0, 0.0, -1.0)])
	for mx: float in [-20.0, -6.0, 8.0, 22.0]:
		_lamp_post(mb, Vector3(mx, 0.15, (T3_ROAD_FAR + T3_MEDIAN_Z) * 0.5), 5.5, [Vector3(0.0, 0.0, 1.0), Vector3(0.0, 0.0, -1.0)])
	_halte(mb, _at(Vector3(13.0, 0.0, -3.3)))
	_bin(mb, Vector3(-1.25, 0.0, -2.3), Palette.MATCHA_DEEP)
	_bin(mb, Vector3(-0.75, 0.0, -2.3), Palette.HONEY)
	var bikes: Array = [[5.0, Palette.SIGN_RED], [5.8, Palette.TIRE], [6.6, Palette.PASTEL_PERIWINKLE.darkened(0.25)], [7.4, Palette.FLOUR_WHITE.darkened(0.12)]]
	for b: Array in bikes:
		_motorbike(mb, Vector3(float(b[0]), 0.0, -0.8), PI, b[1])
	_freezer(mb, Vector3(9.6, 0.0, 0.15))
	_galon_rack(mb, Vector3(8.5, 0.0, 0.2))
	_planter(mb, Vector3(0.45, 0.0, -1.0))
	_planter(mb, Vector3(2.55, 0.0, -1.0))
	_menu_board(mb, Vector3(1.5, 0.0, -1.45))


## Lantai dasar toko bakery mandiri Tier 3, hanya tampil saat kamera di dapur
## lantai atas: dinding krem berlis kayu gelap, kaca lebar mengapit pintu kaca,
## tenda karamel polos dengan roti di lisnya, dan di sisi teras pintu kaca,
## jendela, serta lambang roti bundar. Semuanya di bawah lantai dapur.
static func _own_t3(mb: MeshBuilder, w: float, d: float) -> void:
	var t: float = RoomFactory.WALL_THICK
	var x0: float = -t
	var x1: float = w + t
	var top: float = STOREY - 0.02
	var trim: Color = Palette.DARK_CHOCOLATE
	var nf := Vector3(0.0, 0.0, -1.0)
	var front: Transform3D = _at(Vector3(w * 0.5, 0.0, -t))
	mb.box(_at(Vector3((x0 + x1) * 0.5, (top + Y_GROUND) * 0.5, d * 0.5)), Vector3(x1 - x0, top - Y_GROUND, d + t * 2.0), Palette.HOUSE_CREAM)
	_panel(mb, front, Vector2(0.0, 0.2), Vector2(x1 - x0, 0.4), -0.005, nf, trim)
	for gx: Vector2 in [Vector2(-w * 0.5 + 0.1, -0.55), Vector2(0.55, w * 0.5 - 0.1)]:
		var gc: float = (gx.x + gx.y) * 0.5
		var gw: float = gx.y - gx.x
		_panel(mb, front, Vector2(gc, 1.35), Vector2(gw + 0.08, 1.9), -0.01, nf, trim)
		_panel(mb, front, Vector2(gc, 1.35), Vector2(gw - 0.06, 1.78), -0.015, nf, Palette.WINDOW_GLASS.lightened(0.12))
		_panel(mb, front, Vector2(gc, 1.85), Vector2(gw - 0.06, 0.05), -0.02, nf, trim)
	_panel(mb, front, Vector2(0.0, 1.07), Vector2(0.98, 2.15), -0.01, nf, trim)
	_panel(mb, front, Vector2(0.0, 1.05), Vector2(0.84, 2.0), -0.015, nf, Palette.WINDOW_GLASS.lightened(0.2))
	_panel(mb, front, Vector2(0.3, 1.05), Vector2(0.04, 0.5), -0.02, nf, Palette.GOLD_STAR)
	var aw: float = w + 0.3
	var n_awn: Vector3 = Vector3(0.0, 0.69, -0.24).normalized()
	mb.quad(front * Vector3(-aw * 0.5, 2.44, -0.06), front * Vector3(aw * 0.5, 2.44, -0.06),
		front * Vector3(aw * 0.5, 2.2, -0.75), front * Vector3(-aw * 0.5, 2.2, -0.75), n_awn, Palette.CARAMEL)
	_panel(mb, front, Vector2(0.0, 2.1), Vector2(aw, 0.2), -0.76, nf, Palette.CARAMEL.darkened(0.12))
	_panel(mb, front, Vector2(0.0, 2.0), Vector2(aw, 0.035), -0.765, nf, Palette.VANILLA_CREAM)
	mb.ellipsoid(front * _at(Vector3(-0.5, 2.11, -0.79)), Vector3(0.14, 0.07, 0.03), Palette.GOLDEN_CRUST, 8, 3)
	_panel(mb, front, Vector2(0.15, 2.14), Vector2(0.7, 0.05), -0.77, nf, Palette.VANILLA_CREAM)
	_panel(mb, front, Vector2(0.05, 2.07), Vector2(0.5, 0.04), -0.77, nf, Palette.VANILLA_CREAM)
	# Sisi teras: pintu kaca, jendela, dan lambang roti bundar di dinding.
	var side: Transform3D = _at_yaw(Vector3(x0, 0.0, 1.6), PI * 0.5)
	var ns: Vector3 = side.basis * Vector3(0.0, 0.0, -1.0)
	_panel(mb, side, Vector2(0.0, 1.07), Vector2(1.0, 2.15), -0.01, ns, trim)
	_panel(mb, side, Vector2(0.0, 1.05), Vector2(0.86, 2.0), -0.015, ns, Palette.WINDOW_GLASS.lightened(0.2))
	_window_on(mb, side * _face(Vector3(-2.6, 1.45, 0.0), 0.0), Vector2(1.2, 0.9))
	_dot(mb, side, Vector2(-1.15, 1.75), 0.32, -0.01, Palette.CARAMEL)
	_dot(mb, side, Vector2(-1.15, 1.75), 0.25, -0.015, Palette.VANILLA_CREAM)
	mb.ellipsoid(side * _at(Vector3(-1.15, 1.75, -0.04)), Vector3(0.15, 0.075, 0.025), Palette.GOLDEN_CRUST, 8, 3)


# ===========================================================================
# TIER 4 — KAWASAN PREMIUM
# ===========================================================================

## Flagship store di kawasan premium kota. Lantainya 8 x 8 m dan kamera mengikuti
## pemain, jadi keempat sisi bergantian tampak: depan (pelataran, trotoar, jalan),
## kiri atas layar (dinding hijau dan butik), kanan bawah layar (taman air mancur dan
## kafe), dan belakang (jalan servis dan menara apartemen).
static func _tier4(mb: MeshBuilder, w: float, d: float, door_x: float) -> void:
	_t4_ground(mb, w, d)
	_t4_road(mb)
	_t4_front(mb, door_x)
	_t4_left(mb, w, d)
	_t4_right(mb, d)
	_t4_back(mb, w, d)


## Lantai luar: pelataran, trotoar, lorong samping, dan taman air mancur berubin
## granit, dan jalan servis beraspal di belakang.
static func _t4_ground(mb: MeshBuilder, w: float, d: float) -> void:
	var t: float = RoomFactory.WALL_THICK
	_tiles(mb, ROAD_X0, ROAD_X1, T4_PLAZA_Z, 0.0, Y_YARD, Palette.GRANITE_LIGHT, Palette.GRANITE, 1.0, 1.0)
	_tiles(mb, ROAD_X0, ROAD_X1, T4_ROAD_NEAR, T4_PLAZA_Z, Y_YARD, Palette.GRANITE, Palette.GRANITE.darkened(0.06), 1.5, 1.13)
	_tiles(mb, w + t, T4_PASSAGE_X1, 0.0, d + t, Y_YARD, Palette.GRANITE_LIGHT, Palette.GRANITE, 0.65, 1.0)
	_tiles(mb, T4_GARDEN_X, -t, 0.0, d + t, Y_YARD, Palette.GRANITE_LIGHT, Palette.GRANITE, 1.0, 1.0)
	_flat(mb, ROAD_X0, ROAD_X1, d + t, T4_LANE_Z, Y_ROAD, Palette.ASPHALT)


## Jalan: jalur parkir bergaris, dua lajur bermarka, bibir trotoar granit, median
## berumput dengan pohon palem, dan dua lajur seberang.
static func _t4_road(mb: MeshBuilder) -> void:
	_flat(mb, ROAD_X0, ROAD_X1, T4_ROAD_FAR, T4_ROAD_NEAR, Y_ROAD, Palette.ASPHALT)
	_flat(mb, ROAD_X0, ROAD_X1, T4_ROAD2_FAR, T4_MEDIAN_Z, Y_ROAD, Palette.ASPHALT)
	var y_paint: float = Y_ROAD + 0.004
	_flat(mb, ROAD_X0, ROAD_X1, T4_PARK_Z - 0.05, T4_PARK_Z + 0.05, y_paint, Palette.ROAD_PAINT)
	var bx: float = ROAD_X0
	while bx < ROAD_X1:
		_flat(mb, bx - 0.05, bx + 0.05, T4_PARK_Z, T4_PARK_Z + 0.5, y_paint, Palette.ROAD_PAINT)
		bx += 5.5
	var mid: float = (T4_PARK_Z + T4_ROAD_FAR) * 0.5
	var x: float = ROAD_X0
	while x < ROAD_X1:
		_flat(mb, x, x + 2.0, mid - 0.06, mid + 0.06, y_paint, Palette.ROAD_PAINT)
		x += 4.0
	_flat(mb, ROAD_X0, ROAD_X1, T4_ROAD_FAR + 0.15, T4_ROAD_FAR + 0.25, y_paint, Palette.ROAD_PAINT)
	_ledge(mb, ROAD_X0, ROAD_X1, T4_ROAD_NEAR + 0.07, 0.14, Y_GROUND, 0.14, Palette.GRANITE.darkened(0.1))
	var mz: float = (T4_ROAD_FAR + T4_MEDIAN_Z) * 0.5
	_ledge(mb, ROAD_X0, ROAD_X1, mz, T4_ROAD_FAR - T4_MEDIAN_Z, Y_GROUND, 0.18, Palette.GRANITE)
	_flat(mb, ROAD_X0, ROAD_X1, T4_MEDIAN_Z + 0.15, T4_ROAD_FAR - 0.15, 0.182, Palette.GRASS_DEEP)
	for px: float in [-17.0, -9.0, -1.0, 7.0, 15.0, 23.0]:
		_palm(mb, Vector3(px, 0.18, mz), 5.0)


## Pelataran depan: karpet merah dari pintu ke trotoar diapit tiang tali
## kuningan, topiari di pot, bak bunga di depan dapur, dan totem roti di sudut.
## Di trotoar: pohon tabebuya, lampu bola, bangku, meja valet, dan mobil mewah di
## jalur parkir. Semuanya cukup rendah di dekat toko (ACC_32_NEIGHBORHOOD_CLEAR).
static func _t4_front(mb: MeshBuilder, door_x: float) -> void:
	var cx: float = door_x
	_flat(mb, cx - 0.45, cx + 0.45, T4_PLAZA_Z + 0.05, -0.12, Y_YARD + 0.008, Palette.STRAWBERRY_DEEP)
	for ex: float in [cx - 0.47, cx + 0.47]:
		_flat(mb, ex - 0.02, ex + 0.02, T4_PLAZA_Z + 0.05, -0.12, Y_YARD + 0.009, Palette.BRASS)
	for sx: float in [cx - 0.75, cx + 0.75]:
		var prev := Vector3.ZERO
		for i in 3:
			var p := Vector3(sx, 0.0, -0.95 - 0.9 * float(i))
			_stanchion(mb, p)
			if i > 0:
				_cable(mb, prev + Vector3(0.0, 0.66, 0.0), p + Vector3(0.0, 0.66, 0.0), 0.12, Palette.STRAWBERRY_DEEP, 0.035)
			prev = p
	_topiary(mb, Vector3(cx - 1.3, 0.0, -1.45))
	_topiary(mb, Vector3(cx + 1.3, 0.0, -1.45))
	# Bak bunga granit di depan dapur.
	var bed_z: float = -1.8
	mb.box(_at(Vector3(6.1, 0.16, bed_z)), Vector3(3.4, 0.32, 1.0), Palette.GRANITE.darkened(0.15))
	var blooms: Array[Color] = [Palette.BLOSSOM, Palette.FLOUR_WHITE, Palette.BUTTER_YELLOW]
	var k: int = 0
	var fx: float = 4.7
	while fx < 7.6:
		for fz: float in [bed_z - 0.25, bed_z + 0.25]:
			mb.ellipsoid(_at(Vector3(fx, 0.42, fz)), Vector3(0.19, 0.12, 0.19), Palette.LEAF_DEEP, 6, 3)
			mb.ellipsoid(_at(Vector3(fx + 0.04, 0.5, fz - 0.03)), Vector3(0.09, 0.06, 0.09), blooms[k % blooms.size()], 6, 3)
			k += 1
		fx += 0.55
	_totem(mb, Vector3(-1.4, 0.0, -2.5))
	for tx: float in [-12.5, -6.0, -1.0, 5.0, 11.0, 17.0]:
		_tabebuya(mb, Vector3(tx, 0.0, -5.4))
	for lx: float in [-3.5, 2.0, 8.0, 14.0]:
		_globe_lamp(mb, Vector3(lx, 0.0, T4_ROAD_NEAR + 0.4), 3.4)
	_bench(mb, Vector3(-3.0, 0.0, -4.0), 0.0)
	_bench(mb, Vector3(7.5, 0.0, -4.0), 0.0)
	_valet(mb, Vector3(0.0, 0.0, -3.7))
	var lane: float = (T4_ROAD_NEAR + T4_PARK_Z) * 0.5
	_car(mb, Vector3(3.2, 0.0, lane), PI * 0.5, Palette.MATCHA_DEEP.darkened(0.35))
	_car(mb, Vector3(-6.6, 0.0, lane), PI * 0.5, Palette.FLOUR_WHITE.darkened(0.05))


## Sisi kiri atas layar: lorong samping dengan pot pakis, lalu deretan butik.
## Toko perhiasan putih berlis kuningan menempel paling dekat, dan dinding
## sampingnya yang tampak di atas dinding toko diberi taman vertikal berbingkai
## kuningan. Sesudahnya toko bunga dengan ember bunga dan butik pakaian bermanekin.
static func _t4_left(mb: MeshBuilder, w: float, d: float) -> void:
	_green_wall(mb, T4_PASSAGE_X1, 1.6, d - 1.6, 0.9, 3.6)
	for i in 4:
		var fz: float = 1.2 + 1.8 * float(i)
		mb.box(_at(Vector3((w + T4_PASSAGE_X1) * 0.5 + 0.05, 0.2, fz)), Vector3(0.5, 0.4, 0.8), Palette.GRANITE.darkened(0.15))
		mb.ellipsoid(_at(Vector3((w + T4_PASSAGE_X1) * 0.5 + 0.05, 0.52, fz)), Vector3(0.32, 0.2, 0.46), Palette.LEAF if i % 2 == 0 else Palette.LEAF_DEEP, 8, 4)
	var x: float = T4_PASSAGE_X1
	var specs: Array[Dictionary] = [
		{"w": 5.0, "floors": 2, "wall": Palette.FLOUR_WHITE.darkened(0.03), "awning": Palette.BRASS, "kind": &"jewelry"},
		{"w": 4.2, "floors": 1, "wall": Palette.MATCHA_DEEP.lightened(0.25), "awning": Palette.FLOUR_WHITE, "kind": &"florist"},
		{"w": 5.2, "floors": 2, "wall": Palette.CABLE.lightened(0.2), "awning": Palette.CABLE, "kind": &"fashion"},
	]
	for s: Dictionary in specs:
		var bw: float = float(s["w"])
		_boutique(mb, _at(Vector3(x + bw * 0.5, 0.0, 0.0)), d + RoomFactory.WALL_THICK, s)
		x += bw


## Sisi kanan bawah layar: taman air mancur dengan dua bangku dan dua meja
## berpayung putih, pagar tanaman rendah, lalu kafe patisserie dua lantai.
static func _t4_right(mb: MeshBuilder, d: float) -> void:
	var t: float = RoomFactory.WALL_THICK
	var fc := Vector3(-3.2, 0.0, d * 0.45)
	_fountain(mb, fc, 1.15)
	_bench(mb, fc + Vector3(0.0, 0.0, 2.0), 0.0)
	_bench(mb, fc + Vector3(-2.0, 0.0, 0.0), -PI * 0.5)
	_parasol_set(mb, Vector3(-4.7, Y_YARD + 0.01, 0.75), Palette.FLOUR_WHITE)
	_parasol_set(mb, Vector3(-4.7, Y_YARD + 0.01, d - 0.9), Palette.FLOUR_WHITE)
	mb.box(_at(Vector3(T4_GARDEN_X + 0.15, 0.2, (d + t) * 0.5)), Vector3(0.3, 0.4, d + t), Palette.GRANITE.darkened(0.15))
	var hz: float = 0.4
	while hz < d:
		mb.ellipsoid(_at(Vector3(T4_GARDEN_X + 0.15, 0.5, hz)), Vector3(0.18, 0.15, 0.26), Palette.LEAF_DEEP if int(hz * 2.0) % 2 == 0 else Palette.LEAF, 7, 4)
		hz += 0.55
	_boutique(mb, _at(Vector3(T4_GARDEN_X - 1.0 - 4.0, 0.0, 0.0)), d + t, {"w": 8.0, "floors": 2, "wall": Palette.HOUSE_PEACH, "awning": Palette.ROSY_CHEEK, "kind": &"cafe"})


## Belakang toko: jalan servis dengan van antar dan tempat sampah pilah, lalu
## menara apartemen mewah dengan lobi berkanopi.
static func _t4_back(mb: MeshBuilder, w: float, d: float) -> void:
	_van(mb, Vector3(w * 0.6, 0.0, (d + T4_LANE_Z) * 0.5 + 0.1), PI * 0.5, Palette.FLOUR_WHITE)
	_bin(mb, Vector3(0.6, 0.0, d + 0.5), Palette.MATCHA_DEEP)
	_bin(mb, Vector3(1.15, 0.0, d + 0.5), Palette.HONEY)
	_tower(mb, _at(Vector3(w * 0.5, 0.0, T4_LANE_Z + 0.4)), 20.0, 10.0, 6)


## Toko di deretan premium. `xf` = pusat dasar muka toko; -Z lokal ke jalan.
## Spec: w, floors (1 atau 2), wall (cat atau pelapis muka), awning (warna tenda;
## BRASS = tanpa tenda, dengan plakat kuningan), kind (&"fashion" manekin,
## &"florist" ember bunga, &"jewelry" etalase perhiasan, &"cafe" kue dan meja).
static func _boutique(mb: MeshBuilder, xf: Transform3D, dpt: float, s: Dictionary) -> void:
	var w: float = float(s["w"])
	var floors: int = int(s.get("floors", 2))
	var g: float = 3.0
	var top: float = g + 2.6 * float(floors - 1)
	var wall: Color = s["wall"]
	var awning: Color = s.get("awning", Palette.CABLE)
	var kind: StringName = s.get("kind", &"fashion")
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	var frame: Color = Palette.BRASS if wall.v > 0.75 else Palette.CABLE.lightened(0.1)
	mb.box(xf * _at(Vector3(0.0, (top + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, top - Y_GROUND, dpt), wall)
	mb.box(xf * _at(Vector3(0.0, top + 0.12, dpt * 0.5)), Vector3(w + 0.08, 0.24, dpt + 0.08), wall.darkened(0.15))
	for ax: float in [-w * 0.22, w * 0.22]:
		var cp: Vector3 = Vector3(ax, top + 0.5, dpt * 0.55)
		mb.box(xf * _at(cp), Vector3(0.7, 0.52, 0.5), Palette.FLOUR_WHITE.darkened(0.08))
		mb.disc(xf * _at(cp + Vector3(0.0, 0.265, 0.0)), 0.2, Palette.CABLE.lightened(0.15), Palette.CABLE.lightened(0.35), 10)
	# Muka kaca lantai dasar dengan isi sesuai jenis toko.
	var ow: float = w - 0.6
	var oh: float = 2.4
	_panel(mb, xf, Vector2(0.0, oh * 0.5 + 0.05), Vector2(ow + 0.12, oh + 0.1), -0.01, nrm, frame)
	_panel(mb, xf, Vector2(0.0, oh * 0.5 + 0.05), Vector2(ow, oh - 0.02), -0.015, nrm, Palette.FLOUR_WHITE.darkened(0.08))
	match kind:
		&"fashion":
			var dresses: Array[Color] = [Palette.ROSY_CHEEK, Palette.PASTEL_PERIWINKLE, Palette.FLOUR_WHITE]
			for i in 3:
				var mx: float = -ow * 0.5 + 0.55 + 0.6 * float(i)
				mb.cylinder(xf * _at(Vector3(mx, 0.7, -0.12)), 0.8, 0.07, 0.22, dresses[i], 8)
				mb.ellipsoid(xf * _at(Vector3(mx, 1.2, -0.12)), Vector3(0.08, 0.1, 0.08), Palette.FLOUR_WHITE.darkened(0.1), 6, 4)
				mb.cylinder(xf * _at(Vector3(mx, 0.15, -0.12)), 0.3, 0.02, 0.02, frame, 4)
		&"florist":
			for i in 6:
				var bxp: float = -ow * 0.5 + 0.3 + (ow - 0.6) * float(i) / 5.0
				var bz: float = -0.45 if i % 2 == 0 else -0.85
				mb.cylinder(xf * _at(Vector3(bxp, 0.14, bz)), 0.28, 0.13, 0.11, Palette.GRANITE.darkened(0.1), 8)
				mb.ellipsoid(xf * _at(Vector3(bxp, 0.38, bz)), Vector3(0.17, 0.13, 0.17), [Palette.BLOSSOM, Palette.BUTTER_YELLOW, Palette.STRAWBERRY, Palette.FLOUR_WHITE, Palette.PASTEL_PERIWINKLE, Palette.HONEY][i], 7, 4)
			for j in 4:
				_panel(mb, xf, Vector2(-ow * 0.5 + 0.4 + (ow - 0.8) * float(j) / 3.0, 1.0), Vector2(0.35, 0.5), -0.03, nrm, Palette.LEAF if j % 2 == 0 else Palette.LEAF_DEEP)
		&"jewelry":
			for i in 2:
				var jx: float = -ow * 0.25 + ow * 0.5 * float(i)
				mb.box(xf * _at(Vector3(jx, 0.45, -0.15)), Vector3(ow * 0.38, 0.9, 0.3), Palette.CABLE.lightened(0.1))
				mb.box(xf * _at(Vector3(jx, 0.92, -0.15)), Vector3(ow * 0.38, 0.04, 0.3), Palette.WINDOW_GLASS.lightened(0.15))
				for g2 in 4:
					mb.ellipsoid(xf * _at(Vector3(jx - ow * 0.12 + ow * 0.08 * float(g2), 0.97, -0.15)), Vector3(0.035, 0.025, 0.035), Palette.BRASS.lightened(0.2), 5, 3)
		_:
			var cakes: Array[Color] = [Palette.ROSY_CHEEK, Palette.FLOUR_WHITE, Palette.CUSTARD, Palette.PASTEL_MINT]
			for row in 2:
				mb.box(xf * _at(Vector3(0.0, 0.7 + 0.5 * float(row), -0.05)), Vector3(ow - 0.3, 0.03, 0.1), Palette.FLOUR_WHITE)
				for i in 5:
					mb.cylinder(xf * _at(Vector3(-ow * 0.4 + ow * 0.2 * float(i), 0.82 + 0.5 * float(row), -0.07)), 0.2, 0.12, 0.12, cakes[(i + row) % cakes.size()], 8)
			for tx: float in [-w * 0.3, w * 0.25]:
				mb.cylinder(xf * _at(Vector3(tx, 0.72, -1.4)), 0.04, 0.32, 0.32, Palette.FLOUR_WHITE, 10)
				mb.cylinder(xf * _at(Vector3(tx, 0.36, -1.4)), 0.72, 0.03, 0.05, frame, 6)
	for i in 4:
		var mx2: float = -ow * 0.5 + ow * float(i) / 3.0
		_panel(mb, xf, Vector2(mx2, oh * 0.5 + 0.05), Vector2(0.06, oh), -0.16, nrm, frame)
	_panel(mb, xf, Vector2(0.0, oh + 0.02), Vector2(ow, 0.06), -0.16, nrm, frame)
	# Tenda (atau plakat kuningan) dan papan nama tanpa tulisan.
	if awning == Palette.BRASS:
		mb.box(xf * _at(Vector3(0.0, 2.75, -0.05)), Vector3(w * 0.6, 0.3, 0.06), Palette.BRASS)
		for sx: float in [-w * 0.42, w * 0.42]:
			mb.ellipsoid(xf * _at(Vector3(sx, 2.2, -0.08)), Vector3(0.09, 0.12, 0.06), Palette.FLOUR_WHITE, 6, 3)
	else:
		var aw: float = w - 0.2
		var n_awn: Vector3 = xf.basis * Vector3(0.0, 0.94, -0.33).normalized()
		mb.quad(xf * Vector3(-aw * 0.5, 2.8, -0.05), xf * Vector3(aw * 0.5, 2.8, -0.05),
			xf * Vector3(aw * 0.5, 2.5, -0.9), xf * Vector3(-aw * 0.5, 2.5, -0.9), n_awn, awning)
		var teeth: int = int(aw / 0.4)
		for i in teeth:
			var xa: float = -aw * 0.5 + aw * float(i) / float(teeth)
			var xb: float = -aw * 0.5 + aw * float(i + 1) / float(teeth)
			mb.triangle(xf * Vector3(xa, 2.5, -0.9), xf * Vector3(xb, 2.5, -0.9), xf * Vector3((xa + xb) * 0.5, 2.32, -0.9), nrm, awning.darkened(0.1))
		if awning.v < 0.4:
			_panel(mb, xf, Vector2(0.0, 2.5), Vector2(aw, 0.03), -0.91, nrm, Palette.BRASS)
	_dot(mb, xf, Vector2(-w * 0.5 + 0.55, 2.92), 0.11, -0.01, frame)
	_panel(mb, xf, Vector2(-w * 0.5 + 1.25, 2.92), Vector2(0.9, 0.05), -0.01, nrm, frame)
	# Lantai atas: jendela tinggi dengan kotak bunga.
	if floors > 1:
		for i in 3:
			var ux: float = -w * 0.32 + w * 0.32 * float(i)
			_window_on(mb, xf * _face(Vector3(ux, g + 1.25, 0.0), 0.0), Vector2(0.75, 1.45))
			mb.box(xf * _at(Vector3(ux, g + 0.38, -0.14)), Vector3(0.8, 0.16, 0.2), frame)
			for f2 in 3:
				mb.ellipsoid(xf * _at(Vector3(ux - 0.25 + 0.25 * float(f2), g + 0.5, -0.14)), Vector3(0.1, 0.07, 0.08), Palette.BLOSSOM if f2 != 1 else Palette.LEAF, 5, 3)


## Menara apartemen mewah: lobi kaca dengan kanopi bertiang, lantai-lantai
## berpita putih dengan kaca dan balkon berpagar kaca, dan mahkota di atap.
## `xf` = pusat dasar muka menara; -Z lokal menghadap kamera.
static func _tower(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float, floors: int) -> void:
	var g: float = 4.0
	var fh: float = 3.0
	var top: float = g + fh * float(floors - 1)
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	var white: Color = Palette.FLOUR_WHITE.darkened(0.04)
	mb.box(xf * _at(Vector3(0.0, (top + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, top - Y_GROUND, dpt), Palette.RUKO_GREY.lightened(0.12))
	_panel(mb, xf, Vector2(0.0, (g - 0.5) * 0.5), Vector2(w - 1.0, g - 0.5), -0.01, nrm, Palette.WINDOW_GLASS.lightened(0.1))
	mb.box(xf * _at(Vector3(0.0, g - 0.45, -1.6)), Vector3(5.0, 0.22, 3.2), white)
	for sx: float in [-2.2, 2.2]:
		mb.box(xf * _at(Vector3(sx, (g - 0.55) * 0.5, -2.95)), Vector3(0.3, g - 0.55, 0.3), white)
	for f in range(1, floors):
		var y0: float = g + fh * float(f - 1)
		mb.box(xf * _at(Vector3(0.0, y0, -0.15)), Vector3(w + 0.3, 0.22, 0.3), white)
		_panel(mb, xf, Vector2(0.0, y0 + fh * 0.5 + 0.05), Vector2(w - 0.6, fh - 0.5), -0.01, nrm, Palette.WINDOW_GLASS)
		_panel(mb, xf, Vector2(0.0, y0 + 0.6), Vector2(w - 0.6, 0.9), -0.3, nrm, Palette.WINDOW_GLASS.lightened(0.25))
	mb.box(xf * _at(Vector3(0.0, top + 0.3, dpt * 0.5)), Vector3(w + 0.4, 0.6, dpt + 0.4), white)


## Van antar barang (diperkecil seperti mobil): badan kotak tinggi, kaca depan
## dan samping, empat roda, dan lampu. -Z lokal = depan.
static func _van(mb: MeshBuilder, p: Vector3, yaw: float, body: Color) -> void:
	var xf: Transform3D = _at_yaw(p, yaw) * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CAR_SCALE), Vector3.ZERO)
	var glass: Color = Palette.WINDOW_GLASS.darkened(0.2)
	mb.box(xf * _at(Vector3(0.0, 1.05, 0.0)), Vector3(1.8, 1.5, 4.6), body)
	mb.box(xf * _at(Vector3(0.0, 1.45, -2.31)), Vector3(1.6, 0.55, 0.04), glass)
	mb.box(xf * _at(Vector3(0.0, 1.5, -1.45)), Vector3(1.82, 0.45, 1.2), glass)
	mb.box(xf * _at(Vector3(0.0, 0.95, 0.7)), Vector3(1.82, 0.5, 2.0), Palette.SIGN_GREEN)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(sx * 0.8, 0.33, sz * 1.5)), 0.26, 0.33, 0.33, Palette.TIRE, 10)
	for lx: float in [-0.65, 0.65]:
		mb.box(xf * _at(Vector3(lx, 0.75, -2.31)), Vector3(0.3, 0.14, 0.04), Palette.BUTTER_YELLOW)
		mb.box(xf * _at(Vector3(lx, 0.8, 2.31)), Vector3(0.28, 0.12, 0.04), Palette.STRAWBERRY)


## Pohon tabebuya berbunga merah muda di lubang pohon berkisi.
static func _tabebuya(mb: MeshBuilder, p: Vector3) -> void:
	mb.box(_at(p + Vector3(0.0, Y_YARD + 0.006, 0.0)), Vector3(0.9, 0.004, 0.9), Palette.CABLE.lightened(0.3))
	mb.cylinder(_at(p + Vector3(0.0, 0.85, 0.0)), 1.7, 0.07, 0.1, Palette.TRUNK, 7)
	mb.capsule(p + Vector3(0.0, 1.4, 0.0), p + Vector3(0.4, 1.9, 0.15), 0.05, 0.04, Palette.TRUNK, 5, 1)
	mb.capsule(p + Vector3(0.0, 1.5, 0.0), p + Vector3(-0.35, 1.95, -0.2), 0.05, 0.04, Palette.TRUNK, 5, 1)
	mb.ellipsoid(_at(p + Vector3(0.0, 2.25, 0.0)), Vector3(1.0, 0.62, 1.0), Palette.BLOSSOM, 10, 5)
	mb.ellipsoid(_at(p + Vector3(0.55, 2.05, -0.3)), Vector3(0.6, 0.42, 0.6), Palette.BLOSSOM_DEEP, 8, 4)
	mb.ellipsoid(_at(p + Vector3(-0.5, 2.15, 0.4)), Vector3(0.62, 0.45, 0.62), Palette.BLOSSOM.lightened(0.08), 8, 4)
	mb.ellipsoid(_at(p + Vector3(0.1, 2.75, 0.05)), Vector3(0.55, 0.38, 0.55), Palette.BLOSSOM.lightened(0.12), 8, 4)


## Palem raja: batang abu-abu ramping, pucuk hijau, dan delapan pelepah melengkung.
static func _palm(mb: MeshBuilder, p: Vector3, h: float) -> void:
	mb.cylinder(_at(p + Vector3(0.0, h * 0.5, 0.0)), h, 0.11, 0.17, Palette.CONCRETE_DARK, 7)
	mb.cylinder(_at(p + Vector3(0.0, h + 0.3, 0.0)), 0.6, 0.1, 0.12, Palette.LEAF, 7)
	for i in 8:
		var a: float = TAU * float(i) / 8.0 + 0.3
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var tilt: float = -0.25 + 0.15 * float(i % 2)
		var length: float = 1.5
		var axis: Vector3 = (dir * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
		var across: Vector3 = Vector3.UP.cross(dir).normalized()
		var normal: Vector3 = axis.cross(across).normalized()
		var center: Vector3 = p + Vector3(0.0, h + 0.55, 0.0) + axis * (length * 0.5)
		mb.box(Transform3D(Basis(across, normal, axis), center), Vector3(0.28, 0.02, length), Palette.LEAF if i % 2 == 0 else Palette.LEAF_DEEP)


## Taman vertikal di bidang x tetap yang menghadap -X: petak-petak daun hijau
## senada yang diacak dengan bunga kecil, bingkai kuningan, dan bak di kakinya.
static func _green_wall(mb: MeshBuilder, x: float, z0: float, z1: float, y0: float, y1: float) -> void:
	var greens: Array[Color] = [Palette.LEAF, Palette.LEAF.darkened(0.07), Palette.LEAF_DEEP.lightened(0.12), Palette.MATCHA.darkened(0.06)]
	var xs: float = x - 0.006
	var cols: int = maxi(1, int(round((z1 - z0) / 0.55)))
	var rows: int = maxi(1, int(round((y1 - y0) / 0.55)))
	for i in cols:
		var za: float = lerpf(z0, z1, float(i) / float(cols))
		var zb: float = lerpf(z0, z1, float(i + 1) / float(cols))
		for j in rows:
			var ya: float = lerpf(y0, y1, float(j) / float(rows))
			var yb: float = lerpf(y0, y1, float(j + 1) / float(rows))
			mb.quad(Vector3(xs, ya, za), Vector3(xs, ya, zb), Vector3(xs, yb, zb), Vector3(xs, yb, za), Vector3.LEFT, greens[(i * 7 + j * 3 + (i * j) % 5) % greens.size()])
			if (i * 5 + j * 3) % 7 == 0:
				var zc: float = (za + zb) * 0.5
				var yc: float = (ya + yb) * 0.5
				mb.quad(Vector3(xs - 0.004, yc - 0.06, zc - 0.06), Vector3(xs - 0.004, yc - 0.06, zc + 0.06),
					Vector3(xs - 0.004, yc + 0.06, zc + 0.06), Vector3(xs - 0.004, yc + 0.06, zc - 0.06), Vector3.LEFT,
					Palette.BLOSSOM if (i + j) % 2 == 0 else Palette.FLOUR_WHITE)
	mb.box(_at(Vector3(x - 0.15, y0 - 0.12, (z0 + z1) * 0.5)), Vector3(0.3, 0.24, z1 - z0 + 0.2), Palette.GRANITE.darkened(0.1))
	for fy: float in [y0 - 0.02, y1 + 0.02]:
		mb.box(_at(Vector3(x - 0.02, fy, (z0 + z1) * 0.5)), Vector3(0.04, 0.05, z1 - z0 + 0.1), Palette.BRASS)
	for fz: float in [z0 - 0.03, z1 + 0.03]:
		mb.box(_at(Vector3(x - 0.02, (y0 + y1) * 0.5, fz)), Vector3(0.04, y1 - y0 + 0.08, 0.05), Palette.BRASS)


## Air mancur: kolam granit bundar penuh air berbibir, tiang tengah dengan mangkuk
## berisi air, dan pancaran air di puncaknya.
static func _fountain(mb: MeshBuilder, p: Vector3, r: float) -> void:
	mb.cylinder(_at(p + Vector3(0.0, (0.42 + Y_GROUND) * 0.5, 0.0)), 0.42 - Y_GROUND, r, r, Palette.GRANITE_LIGHT, 18)
	mb.cylinder(_at(p + Vector3(0.0, 0.43, 0.0)), 0.02, r - 0.1, r - 0.1, Palette.WATER, 18)
	mb.torus(_at(p + Vector3(0.0, 0.43, 0.0)), r - 0.05, 0.06, Palette.GRANITE, 18, 4)
	mb.cylinder(_at(p + Vector3(0.0, 0.75, 0.0)), 0.7, 0.1, 0.14, Palette.GRANITE_LIGHT, 8)
	mb.cylinder(_at(p + Vector3(0.0, 1.12, 0.0)), 0.1, 0.38, 0.28, Palette.GRANITE_LIGHT, 12)
	mb.cylinder(_at(p + Vector3(0.0, 1.18, 0.0)), 0.02, 0.33, 0.33, Palette.WATER, 12)
	mb.ellipsoid(_at(p + Vector3(0.0, 1.42, 0.0)), Vector3(0.07, 0.24, 0.07), Palette.WATER.lightened(0.25), 6, 4)


## Tiang tali kuningan berkaki bundar.
static func _stanchion(mb: MeshBuilder, p: Vector3) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.02, 0.0)), 0.04, 0.13, 0.14, Palette.BRASS.darkened(0.1), 10)
	mb.cylinder(_at(p + Vector3(0.0, 0.38, 0.0)), 0.68, 0.025, 0.03, Palette.BRASS, 6)
	mb.ellipsoid(_at(p + Vector3(0.0, 0.74, 0.0)), Vector3(0.045, 0.045, 0.045), Palette.BRASS.lightened(0.15), 6, 3)


## Topiari bola di pot persegi gelap berbibir kuningan.
static func _topiary(mb: MeshBuilder, p: Vector3) -> void:
	mb.box(_at(p + Vector3(0.0, 0.22, 0.0)), Vector3(0.44, 0.44, 0.44), Palette.DARK_CHOCOLATE.lightened(0.1))
	mb.box(_at(p + Vector3(0.0, 0.45, 0.0)), Vector3(0.48, 0.03, 0.48), Palette.BRASS)
	mb.ellipsoid(_at(p + Vector3(0.0, 0.7, 0.0)), Vector3(0.26, 0.26, 0.26), Palette.LEAF_DEEP, 9, 5)


## Totem penanda toko: pilar ramping cokelat tua dengan lingkaran kuningan berisi
## roti dan garis kuningan, tanpa tulisan.
static func _totem(mb: MeshBuilder, p: Vector3) -> void:
	var xf: Transform3D = _at(p)
	var nrm := Vector3(0.0, 0.0, -1.0)
	mb.box(xf * _at(Vector3(0.0, 1.0, 0.0)), Vector3(0.55, 2.0, 0.2), Palette.DARK_CHOCOLATE)
	mb.box(xf * _at(Vector3(0.0, 0.04, 0.0)), Vector3(0.7, 0.08, 0.35), Palette.BRASS.darkened(0.1))
	_dot(mb, xf, Vector2(0.0, 1.5), 0.2, -0.105, Palette.BRASS)
	_dot(mb, xf, Vector2(0.0, 1.5), 0.15, -0.11, Palette.DARK_CHOCOLATE)
	mb.ellipsoid(xf * _at(Vector3(0.0, 1.5, -0.12)), Vector3(0.1, 0.05, 0.02), Palette.GOLDEN_CRUST, 8, 3)
	_panel(mb, xf, Vector2(0.0, 1.05), Vector2(0.3, 0.04), -0.105, nrm, Palette.BRASS)
	_panel(mb, xf, Vector2(0.0, 0.95), Vector2(0.22, 0.03), -0.105, nrm, Palette.BRASS)


## Lampu taman kota: tiang hitam dengan palang dan dua bola lampu putih.
static func _globe_lamp(mb: MeshBuilder, p: Vector3, h: float) -> void:
	var post: Color = Palette.CABLE.lightened(0.1)
	mb.cylinder(_at(p + Vector3(0.0, h * 0.5, 0.0)), h, 0.04, 0.07, post, 6)
	mb.box(_at(p + Vector3(0.0, h - 0.05, 0.0)), Vector3(0.7, 0.04, 0.04), post)
	for sx: float in [-0.33, 0.33]:
		mb.ellipsoid(_at(p + Vector3(sx, h + 0.1, 0.0)), Vector3(0.13, 0.13, 0.13), Palette.FLOUR_WHITE, 8, 4)
		_lamp_heads.append(p + Vector3(sx, h + 0.1, 0.0))


## Meja valet: podium kayu gelap berpelat kuningan.
static func _valet(mb: MeshBuilder, p: Vector3) -> void:
	mb.box(_at(p + Vector3(0.0, 0.5, 0.0)), Vector3(0.55, 1.0, 0.4), Palette.DARK_CHOCOLATE)
	mb.box(_at(p + Vector3(0.0, 1.02, 0.0)), Vector3(0.62, 0.04, 0.46), Palette.BRASS)
	mb.box(_at(p + Vector3(0.0, 0.6, -0.205)), Vector3(0.3, 0.2, 0.01), Palette.BRASS.lightened(0.1))


# ===========================================================================
# TIER 5 — ALUN-ALUN KOTA
# ===========================================================================

## Mega bakery yang menjadi ikon kota, menghadap alun-alun bergaya heritage.
## Kamera hanya memuat benda setinggi sekitar 6 m dalam satu layar, jadi menara
## jamnya dibuat sekitar 5,8 m dan diletakkan dekat di depan toko.
static func _tier5(mb: MeshBuilder, w: float, d: float, door_x: float) -> void:
	_t5_ground(mb, w, d)
	_t5_square(mb, door_x)
	_t5_left(mb, d)
	_t5_right(mb, d)
	_t5_back(mb)


## Lantai luar: teras dan alun-alun berubin batu andesit dengan pita batu gelap,
## jalan beraspal di seberang alun-alun, lorong samping, pujasera, dan halaman
## servis di belakang.
static func _t5_ground(mb: MeshBuilder, w: float, d: float) -> void:
	var t: float = RoomFactory.WALL_THICK
	_tiles(mb, ROAD_X0, ROAD_X1, T5_TERRACE_Z, 0.0, Y_YARD, Palette.STONE_LIGHT, Palette.STONE_LIGHT.darkened(0.05), 0.8, 0.67)
	_tiles(mb, ROAD_X0, ROAD_X1, T5_ROAD_NEAR, T5_TERRACE_Z, Y_YARD, Palette.STONE, Palette.STONE.lightened(0.06), 1.4, 1.4)
	for bz: Vector2 in [Vector2(T5_TERRACE_Z - 0.3, T5_TERRACE_Z), Vector2(T5_ROAD_NEAR, T5_ROAD_NEAR + 0.3)]:
		_flat(mb, ROAD_X0, ROAD_X1, bz.x, bz.y, Y_YARD + 0.003, Palette.STONE.darkened(0.15))
	_flat(mb, ROAD_X0, ROAD_X1, T5_ROAD_FAR, T5_ROAD_NEAR, Y_ROAD, Palette.ASPHALT)
	_flat(mb, ROAD_X0, ROAD_X1, T5_ROAD_FAR - 2.0, T5_ROAD_FAR, Y_YARD, Palette.STONE_LIGHT)
	var mid: float = (T5_ROAD_NEAR + T5_ROAD_FAR) * 0.5
	var x: float = ROAD_X0
	while x < ROAD_X1:
		_flat(mb, x, x + 2.0, mid - 0.06, mid + 0.06, Y_ROAD + 0.004, Palette.ROAD_PAINT)
		x += 4.0
	_ledge(mb, ROAD_X0, ROAD_X1, T5_ROAD_NEAR - 0.07, 0.14, Y_GROUND, 0.15, Palette.STONE.darkened(0.1))
	_tiles(mb, w + t, T5_PASSAGE_X1, 0.0, d + t, Y_YARD, Palette.STONE_LIGHT, Palette.STONE_LIGHT.darkened(0.05), 0.45, 0.8)
	_tiles(mb, T5_COURT_X, -t, 0.0, d + t, Y_YARD, Palette.STONE_LIGHT, Palette.STONE_LIGHT.darkened(0.05), 0.8, 0.8)
	_flat(mb, T5_COURT_X, T5_PASSAGE_X1, d + t, T5_BACK_Z, Y_YARD, Palette.CONCRETE)


## Alun-alun di depan toko: pot besar dan lampu antik di teras, menara jam
## dengan bangku di kiri-kanannya, pohon beringin berpagar, dua becak yang
## mangkal, dan lampu antik di tepi alun-alun. Semuanya cukup rendah atau cukup
## jauh dari muka toko (ACC_32_NEIGHBORHOOD_CLEAR).
static func _t5_square(mb: MeshBuilder, door_x: float) -> void:
	for px: float in [door_x - 1.6, door_x + 1.6, 7.4, 9.2]:
		mb.cylinder(_at(Vector3(px, 0.25, -1.45)), 0.5, 0.3, 0.24, Palette.TERRACOTTA.darkened(0.1), 10)
		mb.ellipsoid(_at(Vector3(px, 0.7, -1.45)), Vector3(0.32, 0.26, 0.32), Palette.LEAF_DEEP, 8, 4)
		mb.ellipsoid(_at(Vector3(px + 0.08, 0.86, -1.5)), Vector3(0.12, 0.08, 0.12), Palette.ROSY_CHEEK, 6, 3)
	for lx: float in [door_x - 2.6, 6.2]:
		_vintage_lamp(mb, Vector3(lx, 0.0, -3.7), 3.0)
	var tower := Vector3(5.5, 0.0, -6.5)
	_clock_tower(mb, tower)
	_bench(mb, tower + Vector3(-2.1, 0.0, 0.0), -PI * 0.5)
	_bench(mb, tower + Vector3(2.1, 0.0, 0.0), PI * 0.5)
	_banyan(mb, Vector3(-9.5, 0.0, -6.0))
	_becak(mb, Vector3(-2.7, 0.0, -3.6), 0.15, Palette.SIGN_BLUE)
	_becak(mb, Vector3(-4.3, 0.0, -3.8), -0.1, Palette.SIGN_RED)
	for sx: float in [-14.0, -2.0, 10.0, 22.0]:
		_vintage_lamp(mb, Vector3(sx, 0.0, T5_ROAD_NEAR + 0.5), 3.0)


## Sisi kiri atas layar: lorong batu, lalu gedung kolonial putih berjendela tinggi
## berdaun jendela hijau (dinding sampingnya tampak di atas dinding toko), dengan
## onthel sewaan berwarna pastel dan umbul-umbul di depannya; sesudahnya gedung
## kolonial kuning.
static func _t5_left(mb: MeshBuilder, d: float) -> void:
	var dpt: float = d + RoomFactory.WALL_THICK
	_heritage(mb, _at(Vector3(T5_PASSAGE_X1 + 4.0, 0.0, 0.0)), 8.0, dpt, {"wall": Palette.COLONIAL_WHITE})
	_heritage(mb, _at(Vector3(T5_PASSAGE_X1 + 8.4 + 4.0, 0.0, 0.0)), 8.0, dpt, {"wall": Palette.HOUSE_BUTTER})
	var bikes: Array[Color] = [Palette.ROSY_CHEEK, Palette.PASTEL_MINT, Palette.BUTTER_YELLOW, Palette.PASTEL_PERIWINKLE, Palette.HONEY, Palette.PASTEL_STRAWBERRY]
	for i in bikes.size():
		_bicycle(mb, Vector3(T5_PASSAGE_X1 + 0.7 + 0.75 * float(i), 0.0, -1.0), 0.0, bikes[i])
	var flags: Array = [[Palette.STRAWBERRY, Palette.FLOUR_WHITE], [Palette.BUTTER_YELLOW, Palette.MATCHA], [Palette.SIGN_BLUE, Palette.FLOUR_WHITE], [Palette.ROSY_CHEEK, Palette.BUTTER_YELLOW]]
	for j in flags.size():
		_umbul(mb, Vector3(T5_PASSAGE_X1 + 0.9 + 2.3 * float(j), 0.0, -1.85), flags[j][0], flags[j][1])


## Sisi kanan bawah layar: pujasera terbuka dengan tiga tenda kaki lima dan meja
## panjang berbangku, lalu gedung kolonial di seberangnya. Tenda cukup jauh dari
## dinding toko supaya tidak menutupi toko.
static func _t5_right(mb: MeshBuilder, d: float) -> void:
	var tents: Array[Color] = [Palette.SIGN_RED, Palette.SIGN_YELLOW, Palette.SIGN_BLUE]
	for i in tents.size():
		_tent_stall(mb, Vector3(-3.5, 0.0, 1.8 + 3.1 * float(i)), tents[i])
	_long_table(mb, Vector3(-6.7, 0.0, 5.0), 7.0)
	_heritage(mb, _at(Vector3(T5_COURT_X - 1.0 - 4.0, 0.0, 0.0)), 8.0, d + RoomFactory.WALL_THICK, {"wall": Palette.HOUSE_PEACH})


## Belakang toko: halaman servis dengan krat roti, tabung gas, dan tempat sampah,
## tembok bata bercoping putih, dan pohon-pohon besar di baliknya.
static func _t5_back(mb: MeshBuilder) -> void:
	_crates(mb, Vector3(1.5, 0.0, 11.2), 3, Palette.SIGN_RED)
	_crates(mb, Vector3(2.3, 0.0, 11.2), 2, Palette.SIGN_BLUE)
	for i in 4:
		_lpg(mb, Vector3(4.0 + 0.32 * float(i % 2), 0.0, 11.0 + 0.32 * float(i / 2)))
	_bin(mb, Vector3(7.0, 0.0, 11.3), Palette.MATCHA_DEEP)
	_bin(mb, Vector3(7.55, 0.0, 11.3), Palette.HONEY)
	var wx0: float = T5_COURT_X
	var wx1: float = T5_PASSAGE_X1 + 8.0
	mb.box(_at(Vector3((wx0 + wx1) * 0.5, (1.6 + Y_GROUND) * 0.5, T5_BACK_Z + 0.12)), Vector3(wx1 - wx0, 1.6 - Y_GROUND, 0.25), Palette.TERRACOTTA.darkened(0.12))
	mb.box(_at(Vector3((wx0 + wx1) * 0.5, 1.64, T5_BACK_Z + 0.12)), Vector3(wx1 - wx0 + 0.04, 0.08, 0.33), Palette.COLONIAL_WHITE)
	for tr: Vector3 in [Vector3(-4.0, 15.5, 1.3), Vector3(5.0, 16.0, 1.4), Vector3(13.0, 15.0, 1.3)]:
		_mango_tree(mb, Vector3(tr.x, 0.0, tr.y), tr.z)


## Gedung kolonial dua lantai. `xf` = pusat dasar muka gedung; -Z lokal ke
## alun-alun. Dinding berlis di kaki batu, pintu utama diapit dua tiang dengan
## pediment, jendela tinggi berlengkung dengan daun jendela hijau di muka dan di
## sisi -X yang tampak kamera, dan atap genteng.
static func _heritage(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float, s: Dictionary) -> void:
	var wall: Color = s.get("wall", Palette.COLONIAL_WHITE)
	var g: float = 3.4
	var top: float = g + 3.0
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	mb.box(xf * _at(Vector3(0.0, (top + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, top - Y_GROUND, dpt), wall)
	mb.box(xf * _at(Vector3(0.0, 0.25, dpt * 0.5)), Vector3(w + 0.04, 0.5, dpt + 0.04), Palette.STONE)
	mb.box(xf * _at(Vector3(0.0, g, dpt * 0.5)), Vector3(w + 0.1, 0.18, dpt + 0.1), wall.darkened(0.06))
	mb.box(xf * _at(Vector3(0.0, top, dpt * 0.5)), Vector3(w + 0.2, 0.25, dpt + 0.2), wall.darkened(0.08))
	_roof_x(mb, xf, w + 0.1, dpt, top + 0.12, 1.8, 0.5, 0.4, 0.0, wall, Palette.ROOF_TILE, Palette.ROOF_TILE_DEEP)
	# Pintu utama, tiang, pediment, dan tangga.
	_dot(mb, xf, Vector2(0.0, 2.9), 0.65, -0.008, wall.darkened(0.12))
	_panel(mb, xf, Vector2(0.0, 1.7), Vector2(1.3, 2.4), -0.01, nrm, Palette.COLONIAL_GREEN.darkened(0.2))
	_panel(mb, xf, Vector2(0.0, 1.7), Vector2(0.03, 2.4), -0.012, nrm, Palette.COLONIAL_GREEN.darkened(0.45))
	for cx: float in [-0.95, 0.95]:
		mb.cylinder(xf * _at(Vector3(cx, 0.5 + 1.45, -0.4)), 2.9, 0.13, 0.15, wall.lightened(0.3), 10)
		mb.box(xf * _at(Vector3(cx, 3.45, -0.4)), Vector3(0.38, 0.12, 0.38), wall.darkened(0.06))
	mb.box(xf * _at(Vector3(0.0, 3.55, -0.32)), Vector3(2.8, 0.14, 0.64), wall.darkened(0.04))
	mb.triangle(xf * Vector3(-1.4, 3.62, -0.62), xf * Vector3(1.4, 3.62, -0.62), xf * Vector3(0.0, 4.3, -0.62), nrm, wall.darkened(0.03))
	mb.box(xf * _at(Vector3(0.0, 0.12, -0.45)), Vector3(2.6, 0.25, 0.6), Palette.STONE_LIGHT)
	# Jendela muka bawah dan atas.
	for wx: float in [-w * 0.5 + 1.0, -w * 0.5 + 2.3, w * 0.5 - 2.3, w * 0.5 - 1.0]:
		_colonial_window(mb, xf, Vector2(wx, 1.95), 0.7, 1.6)
	for i in 5:
		_colonial_window(mb, xf, Vector2(-w * 0.5 + 1.0 + (w - 2.0) * float(i) / 4.0, g + 1.45), 0.7, 1.5)
	# Sisi -X: jendela di kedua lantai.
	var side: Transform3D = xf * _at_yaw(Vector3(-w * 0.5, 0.0, 0.0), PI * 0.5)
	var zz: float = 1.4
	while zz < dpt - 0.8:
		_colonial_window(mb, side, Vector2(-zz, 1.95), 0.7, 1.6)
		_colonial_window(mb, side, Vector2(-zz, g + 1.45), 0.7, 1.5)
		zz += 2.3


## Jendela kolonial: kusen putih, kaca, lengkung di atasnya, ambang, dan dua daun
## jendela hijau yang terbuka di kiri-kanan. Pusat jendela di (x, y) muka `xf`.
static func _colonial_window(mb: MeshBuilder, xf: Transform3D, c: Vector2, ww: float, wh: float) -> void:
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	var glass: Color = Palette.WINDOW_GLASS.darkened(0.1)
	_dot(mb, xf, Vector2(c.x, c.y + wh * 0.5), ww * 0.5 + 0.06, -0.012, Palette.FLOUR_WHITE)
	_dot(mb, xf, Vector2(c.x, c.y + wh * 0.5), ww * 0.5, -0.016, glass)
	_panel(mb, xf, c, Vector2(ww + 0.12, wh + 0.06), -0.014, nrm, Palette.FLOUR_WHITE)
	_panel(mb, xf, c, Vector2(ww, wh), -0.018, nrm, glass)
	_panel(mb, xf, c, Vector2(0.04, wh), -0.02, nrm, Palette.FLOUR_WHITE)
	for sx: float in [-1.0, 1.0]:
		_panel(mb, xf, Vector2(c.x + sx * (ww * 0.5 + 0.08 + ww * 0.24), c.y), Vector2(ww * 0.48, wh), -0.014, nrm, Palette.COLONIAL_GREEN)
	_panel(mb, xf, Vector2(c.x, c.y - wh * 0.5 - 0.06), Vector2(ww + 0.3, 0.07), -0.03, nrm, Palette.FLOUR_WHITE.darkened(0.05))


## Menara jam alun-alun: alas batu bertangga, badan putih berlis, kepala jam
## dengan muka jam di dua sisi yang tampak kamera, atap limas genteng, dan
## puncak kuningan.
static func _clock_tower(mb: MeshBuilder, p: Vector3) -> void:
	mb.box(_at(p + Vector3(0.0, 0.15, 0.0)), Vector3(2.2, 0.3, 2.2), Palette.STONE)
	mb.box(_at(p + Vector3(0.0, 0.55, 0.0)), Vector3(1.7, 0.5, 1.7), Palette.STONE_LIGHT)
	mb.box(_at(p + Vector3(0.0, 2.3, 0.0)), Vector3(1.2, 3.0, 1.2), Palette.COLONIAL_WHITE)
	mb.box(_at(p + Vector3(0.0, 3.85, 0.0)), Vector3(1.42, 0.15, 1.42), Palette.COLONIAL_WHITE.darkened(0.08))
	mb.box(_at(p + Vector3(0.0, 4.35, 0.0)), Vector3(1.3, 0.9, 1.3), Palette.COLONIAL_WHITE)
	var faces: Array[Transform3D] = [_at(p + Vector3(0.0, 0.0, -0.65)), _at_yaw(p + Vector3(-0.65, 0.0, 0.0), PI * 0.5)]
	for fx: Transform3D in faces:
		var nrm: Vector3 = fx.basis * Vector3(0.0, 0.0, -1.0)
		_dot(mb, fx, Vector2(0.0, 4.35), 0.4, -0.01, Palette.DARK_CHOCOLATE)
		_dot(mb, fx, Vector2(0.0, 4.35), 0.34, -0.015, Palette.FLOUR_WHITE)
		_panel(mb, fx, Vector2(0.0, 4.47), Vector2(0.04, 0.24), -0.02, nrm, Palette.DARK_CHOCOLATE)
		_panel(mb, fx, Vector2(0.08, 4.35), Vector2(0.18, 0.035), -0.02, nrm, Palette.DARK_CHOCOLATE)
	var c: Array[Vector3] = [p + Vector3(-0.75, 4.8, -0.75), p + Vector3(0.75, 4.8, -0.75), p + Vector3(0.75, 4.8, 0.75), p + Vector3(-0.75, 4.8, 0.75)]
	var apex: Vector3 = p + Vector3(0.0, 5.55, 0.0)
	for k in 4:
		var a: Vector3 = c[k]
		var b: Vector3 = c[(k + 1) % 4]
		var n: Vector3 = (b - a).cross(apex - a).normalized()
		if n.y < 0.0:
			n = -n
		mb.triangle(a, b, apex, n, Palette.ROOF_TILE if k % 2 == 0 else Palette.ROOF_TILE_DEEP)
	mb.cylinder(_at(p + Vector3(0.0, 5.62, 0.0)), 0.14, 0.03, 0.05, Palette.BRASS, 6)
	mb.ellipsoid(_at(p + Vector3(0.0, 5.73, 0.0)), Vector3(0.06, 0.06, 0.06), Palette.BRASS, 6, 3)


## Pohon beringin alun-alun: batang besar bercabang, akar gantung, tajuk lebar
## rimbun, dan pagar rendah persegi bertiang putih di sekelilingnya.
static func _banyan(mb: MeshBuilder, p: Vector3) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 1.2, 0.0)), 2.4, 0.35, 0.5, Palette.TRUNK, 9)
	for b: Vector3 in [Vector3(1.0, 3.0, 0.4), Vector3(-0.9, 3.1, 0.5), Vector3(0.1, 3.2, -1.0)]:
		mb.capsule(p + Vector3(0.0, 2.2, 0.0), p + b, 0.16, 0.1, Palette.TRUNK, 6, 1)
	mb.ellipsoid(_at(p + Vector3(0.0, 3.6, 0.0)), Vector3(2.3, 1.3, 2.3), Palette.LEAF_DEEP, 12, 6)
	for k in 4:
		var a: float = TAU * float(k) / 4.0 + 0.4
		mb.ellipsoid(_at(p + Vector3(cos(a) * 1.5, 3.3, sin(a) * 1.5)), Vector3(1.3, 0.9, 1.3), Palette.LEAF if k % 2 == 0 else Palette.LEAF_DEEP.lightened(0.05), 9, 5)
	for k2 in 6:
		var a2: float = TAU * float(k2) / 6.0
		var r: float = 1.2 + 0.4 * float(k2 % 2)
		var top: Vector3 = p + Vector3(cos(a2) * r, 2.6, sin(a2) * r)
		_stick(mb, top, top + Vector3(0.0, -1.8, 0.0), 0.04, Palette.TRUNK.darkened(0.15))
	var hs: float = 1.6
	var posts: Array[Vector3] = [p + Vector3(-hs, 0.0, -hs), p + Vector3(hs, 0.0, -hs), p + Vector3(hs, 0.0, hs), p + Vector3(-hs, 0.0, hs)]
	for k3 in 4:
		var a3: Vector3 = posts[k3]
		var b3: Vector3 = posts[(k3 + 1) % 4]
		for t2 in 4:
			var q: Vector3 = a3.lerp(b3, float(t2) / 4.0)
			mb.box(_at(q + Vector3(0.0, 0.3, 0.0)), Vector3(0.1, 0.6, 0.1), Palette.FLOUR_WHITE)
		_cable(mb, a3 + Vector3(0.0, 0.52, 0.0), b3 + Vector3(0.0, 0.52, 0.0), 0.08, Palette.CABLE.lightened(0.2), 0.03)


## Umbul-umbul: tiang bambu tinggi yang melengkung di puncak dengan kain panjang
## dua warna menjuntai, khas perayaan. Kain menghadap kamera (-Z).
static func _umbul(mb: MeshBuilder, p: Vector3, a: Color, b: Color) -> void:
	var top: Vector3 = p + Vector3(0.0, 4.4, 0.0)
	_stick(mb, p, top, 0.06, Palette.PINE_WOOD)
	var tip: Vector3 = top + Vector3(0.0, 0.45, -0.4)
	_stick(mb, top, tip, 0.045, Palette.PINE_WOOD)
	var nrm := Vector3(0.0, 0.0, -1.0)
	var seg: int = 6
	for i in seg:
		var y0: float = tip.y - 0.05 - 0.5 * float(i)
		var y1: float = y0 - 0.5
		var sway0: float = 0.06 * sin(float(i) * 1.3)
		var sway1: float = 0.06 * sin(float(i + 1) * 1.3)
		var z: float = tip.z - 0.01
		mb.quad(Vector3(tip.x - 0.17 + sway0, y0, z), Vector3(tip.x + 0.17 + sway0, y0, z),
			Vector3(tip.x + 0.17 + sway1, y1, z), Vector3(tip.x - 0.17 + sway1, y1, z), nrm, a if i % 2 == 0 else b)


## Sepeda onthel sewaan: dua roda, rangka berwarna, sadel, setang, dan keranjang
## rotan di depan. -Z lokal = depan.
static func _bicycle(mb: MeshBuilder, p: Vector3, yaw: float, color: Color) -> void:
	var xf: Transform3D = _at_yaw(p, yaw)
	for wz: float in [-0.45, 0.45]:
		mb.torus(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(0.0, 0.32, wz)), 0.29, 0.025, Palette.TIRE, 10, 3)
	var bb: Vector3 = xf * Vector3(0.0, 0.36, 0.02)
	var seat: Vector3 = xf * Vector3(0.0, 0.84, 0.16)
	var head: Vector3 = xf * Vector3(0.0, 0.86, -0.36)
	_stick(mb, xf * Vector3(0.0, 0.32, 0.45), seat, 0.035, color)
	_stick(mb, bb, seat, 0.035, color)
	_stick(mb, bb, head, 0.035, color)
	_stick(mb, seat, head, 0.035, color)
	_stick(mb, head, xf * Vector3(0.0, 0.32, -0.45), 0.035, color)
	mb.box(xf * _at(Vector3(0.0, 0.88, 0.18)), Vector3(0.12, 0.05, 0.22), Palette.TIRE)
	mb.box(xf * _at(Vector3(0.0, 0.96, -0.38)), Vector3(0.44, 0.03, 0.04), Palette.TIRE)
	mb.box(xf * _at(Vector3(0.0, 0.84, -0.6)), Vector3(0.3, 0.2, 0.24), Palette.DOOR_WOOD.lightened(0.15))


## Becak: kursi penumpang berkap dengan dua roda di depan, pijakan kaki, dan
## sepeda pengayuh di belakang. -Z lokal = depan.
static func _becak(mb: MeshBuilder, p: Vector3, yaw: float, color: Color) -> void:
	var xf: Transform3D = _at_yaw(p, yaw)
	mb.box(xf * _at(Vector3(0.0, 0.72, -0.3)), Vector3(1.0, 0.42, 0.62), color)
	mb.box(xf * _at(Vector3(0.0, 0.97, -0.26)), Vector3(0.9, 0.1, 0.5), Palette.STRAWBERRY_DEEP)
	mb.box(xf * _at(Vector3(0.0, 1.22, 0.0)), Vector3(1.0, 0.55, 0.1), color)
	mb.box(Transform3D(xf.basis * Basis(Vector3(1.0, 0.0, 0.0), 0.35), xf * Vector3(0.0, 1.6, -0.2)), Vector3(1.06, 0.06, 0.78), Palette.CABLE.lightened(0.15))
	mb.box(xf * _at(Vector3(0.0, 0.44, -0.78)), Vector3(0.9, 0.04, 0.32), color.darkened(0.2))
	for wx: float in [-0.56, 0.56]:
		mb.torus(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(wx, 0.3, -0.38)), 0.27, 0.035, Palette.TIRE, 10, 3)
	_stick(mb, xf * Vector3(0.0, 0.6, 0.05), xf * Vector3(0.0, 0.92, 0.8), 0.05, color.darkened(0.25))
	mb.box(xf * _at(Vector3(0.0, 0.96, 0.78)), Vector3(0.14, 0.06, 0.24), Palette.TIRE)
	mb.box(xf * _at(Vector3(0.0, 1.05, 0.5)), Vector3(0.5, 0.03, 0.04), Palette.TIRE)
	mb.torus(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(0.0, 0.3, 1.05)), 0.27, 0.035, Palette.TIRE, 10, 3)


## Lampu antik: tiang hitam berkaki, lentera kaca hangat bertudung di puncak.
static func _vintage_lamp(mb: MeshBuilder, p: Vector3, h: float) -> void:
	var black: Color = Palette.CABLE.lightened(0.05)
	mb.cylinder(_at(p + Vector3(0.0, 0.25, 0.0)), 0.5, 0.09, 0.13, black, 8)
	mb.cylinder(_at(p + Vector3(0.0, h * 0.5, 0.0)), h, 0.045, 0.06, black, 6)
	mb.box(_at(p + Vector3(0.0, h + 0.15, 0.0)), Vector3(0.24, 0.3, 0.24), Palette.BUTTER_YELLOW.lightened(0.3))
	mb.cylinder(_at(p + Vector3(0.0, h + 0.37, 0.0)), 0.14, 0.02, 0.2, black, 4)
	_lamp_heads.append(p + Vector3(0.0, h + 0.15, 0.0))


## Tenda kaki lima: meja dagangan bertaplak dengan mangkuk-mangkuk, empat tiang,
## dan atap limas kain berwarna.
static func _tent_stall(mb: MeshBuilder, p: Vector3, color: Color) -> void:
	mb.box(_at(p + Vector3(0.0, 0.4, 0.0)), Vector3(0.7, 0.8, 1.6), Palette.DOOR_WOOD)
	mb.box(_at(p + Vector3(0.0, 0.81, 0.0)), Vector3(0.76, 0.03, 1.66), Palette.FLOUR_WHITE)
	var bowls: Array[Color] = [Palette.HONEY, Palette.STRAWBERRY, Palette.MATCHA, Palette.CUSTARD]
	for i in 4:
		mb.cylinder(_at(p + Vector3(0.0, 0.87, -0.6 + 0.4 * float(i))), 0.08, 0.13, 0.09, bowls[i], 8)
	for sx: float in [-0.85, 0.85]:
		for sz: float in [-0.85, 0.85]:
			mb.box(_at(p + Vector3(sx, 1.0, sz)), Vector3(0.05, 2.0, 0.05), Palette.CONCRETE_DARK)
	var c: Array[Vector3] = [p + Vector3(-1.0, 2.0, -1.0), p + Vector3(1.0, 2.0, -1.0), p + Vector3(1.0, 2.0, 1.0), p + Vector3(-1.0, 2.0, 1.0)]
	var apex: Vector3 = p + Vector3(0.0, 2.5, 0.0)
	for k in 4:
		var a: Vector3 = c[k]
		var b: Vector3 = c[(k + 1) % 4]
		var n: Vector3 = (b - a).cross(apex - a).normalized()
		if n.y < 0.0:
			n = -n
		mb.triangle(a, b, apex, n, color if k % 2 == 0 else color.darkened(0.1))


## Meja panjang dengan dua bangku untuk pengunjung pujasera, memanjang sepanjang z.
static func _long_table(mb: MeshBuilder, p: Vector3, length: float) -> void:
	mb.box(_at(p + Vector3(0.0, 0.72, 0.0)), Vector3(0.8, 0.05, length), Palette.PINE_WOOD)
	for sz: float in [-length * 0.45, length * 0.45]:
		mb.box(_at(p + Vector3(0.0, 0.35, sz)), Vector3(0.7, 0.7, 0.06), Palette.PINE_WOOD.darkened(0.2))
	for sx: float in [-0.65, 0.65]:
		mb.box(_at(p + Vector3(sx, 0.42, 0.0)), Vector3(0.3, 0.05, length), Palette.PINE_WOOD.darkened(0.08))
		for sz2: float in [-length * 0.45, length * 0.45]:
			mb.box(_at(p + Vector3(sx, 0.2, sz2)), Vector3(0.24, 0.4, 0.05), Palette.PINE_WOOD.darkened(0.2))


# ===========================================================================
# RUKO
# ===========================================================================

## Ruko dua lantai berdak beton. `xf` = pusat dasar muka ruko; -Z lokal
## menghadap jalan. Spec:
##   w, dpt          lebar dan kedalaman (m); dpt bawaan sampai gang belakang
##   wall            cat muka dan dinding
##   sign, logo      warna papan nama dan gambarnya (&"cross" apotek, &"phone"
##                   konter ponsel, &"bubbles" laundry, &"bars" toko kelontong,
##                   &"stripes" tukang cukur); papan tanpa tulisan
##   door            &"open", &"half", atau &"closed" (pintu gulung)
##   goods, sachets  warna barang di rak di balik pintu yang terbuka; renteng
##                   sachet yang tergantung (warung)
##   counter         etalase kaca di depan pintu yang terbuka
##   upper           &"windows" (jendela berteralis) atau &"balcony" (balkon
##                   dengan jemuran)
##   ac              unit AC luar di muka
##   party_wall      dinding samping -X yang tampak di atas dinding toko: lis
##                   lantai, roster angin, dan pipa talang
##   tank, tank_x    warna toren di dak (tanpa = tidak ada) dan posisi x-nya
##                   sebagai bagian lebar ruko
##   front_detail    false: muka tidak tampak kamera (ruko seberang jalan);
##                   punggungnya yang diberi jendela dan AC
static func _ruko(mb: MeshBuilder, xf: Transform3D, s: Dictionary) -> void:
	var w: float = float(s["w"])
	var dpt: float = float(s.get("dpt", T2_ALLEY_Z0))
	var top: float = RUKO_GROUND + RUKO_UPPER
	var wall: Color = s["wall"]
	mb.box(xf * _at(Vector3(0.0, (top + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, top - Y_GROUND, dpt), wall)
	# Dak beton dikelilingi dinding pembatas, dengan lis di muka.
	mb.box(xf * _at(Vector3(0.0, top + 0.015, dpt * 0.5)), Vector3(w - 0.2, 0.03, dpt - 0.2), Palette.CONCRETE_DARK)
	for sx: float in [-1.0, 1.0]:
		mb.box(xf * _at(Vector3(sx * (w * 0.5 - 0.05), top + PARAPET * 0.5, dpt * 0.5)), Vector3(0.1, PARAPET, dpt), wall)
	for pz: float in [0.05, dpt - 0.05]:
		mb.box(xf * _at(Vector3(0.0, top + PARAPET * 0.5, pz)), Vector3(w - 0.2, PARAPET, 0.1), wall)
	mb.box(xf * _at(Vector3(0.0, top + PARAPET + 0.03, 0.04)), Vector3(w + 0.02, 0.06, 0.16), wall.darkened(0.12))
	if bool(s.get("front_detail", true)):
		_shopfront(mb, xf, w, s)
		_ruko_upper(mb, xf, w, s)
		if bool(s.get("party_wall", false)):
			_party_wall(mb, xf, w, dpt, wall)
	else:
		_window_on(mb, xf * _face(Vector3(-w * 0.2, RUKO_GROUND + 1.35, dpt), PI), Vector2(0.7, 0.6))
		if bool(s.get("ac", false)):
			mb.box(xf * _at(Vector3(w * 0.22, RUKO_GROUND + 1.15, dpt + 0.13)), Vector3(0.6, 0.42, 0.26), Palette.FLOUR_WHITE.darkened(0.06))
	if s.has("tank"):
		var tx: float = float(s.get("tank_x", 0.22)) * w
		_water_tower(mb, xf * Vector3(tx, top, dpt * 0.62), s["tank"], 0.4)


## Dinding samping -X ruko yang tampak di atas dinding toko: lis lantai, dua
## roster angin, dan pipa talang. Semuanya menempel di dinding (tidak menjorok ke
## atas toko), jadi tidak menutupi isi toko.
static func _party_wall(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float, wall: Color) -> void:
	var x: float = -w * 0.5 - 0.004
	var n: Vector3 = xf.basis * Vector3.LEFT
	var band: Color = wall.darkened(0.08)
	mb.quad(xf * Vector3(x, RUKO_GROUND - 0.06, 0.0), xf * Vector3(x, RUKO_GROUND - 0.06, dpt),
		xf * Vector3(x, RUKO_GROUND + 0.06, dpt), xf * Vector3(x, RUKO_GROUND + 0.06, 0.0), n, band)
	for zc: float in [dpt * 0.3, dpt * 0.68]:
		mb.quad(xf * Vector3(x, 3.85, zc - 0.45), xf * Vector3(x, 3.85, zc + 0.45),
			xf * Vector3(x, 4.25, zc + 0.45), xf * Vector3(x, 4.25, zc - 0.45), n, Palette.CONCRETE_DARK)
		for k in 3:
			var hz: float = zc - 0.3 + 0.3 * float(k)
			mb.quad(xf * Vector3(x - 0.004, 3.95, hz - 0.09), xf * Vector3(x - 0.004, 3.95, hz + 0.09),
				xf * Vector3(x - 0.004, 4.15, hz + 0.09), xf * Vector3(x - 0.004, 4.15, hz - 0.09), n, Palette.GUTTER)
	var top: float = RUKO_GROUND + RUKO_UPPER
	mb.box(xf * _at(Vector3(-w * 0.5 - 0.04, (top + 1.9) * 0.5, 0.35)), Vector3(0.07, top - 1.9, 0.07), Palette.CONCRETE_DARK)


## Paving blok dua warna (petak 1 x 1,1 m) di x0..x1, z0..z1.
static func _pavers(mb: MeshBuilder, x0: float, x1: float, z0: float, z1: float) -> void:
	_tiles(mb, x0, x1, z0, z1, Y_YARD, Palette.CONCRETE.lightened(0.05), Palette.CONCRETE.darkened(0.03), 1.0, 1.1)


## Ubin dua warna berpola papan catur (petak kira-kira tx x tz m) di x0..x1,
## z0..z1 setinggi y.
static func _tiles(mb: MeshBuilder, x0: float, x1: float, z0: float, z1: float, y: float, a: Color, b: Color, tx: float, tz: float) -> void:
	var nx: int = maxi(1, int(round((x1 - x0) / tx)))
	var nz: int = maxi(1, int(round((z1 - z0) / tz)))
	for i in nx:
		var xa: float = lerpf(x0, x1, float(i) / float(nx))
		var xb: float = lerpf(x0, x1, float(i + 1) / float(nx))
		for j in nz:
			var za: float = lerpf(z0, z1, float(j) / float(nz))
			var zb: float = lerpf(z0, z1, float(j + 1) / float(nz))
			mb.quad(Vector3(xa, y, za), Vector3(xb, y, za), Vector3(xb, y, zb), Vector3(xa, y, zb),
				Vector3.UP, a if (i + j) % 2 == 0 else b)


## Lantai dasar ruko: pintu gulung (tertutup, setengah, atau terbuka dengan
## barang dagangan), kotak gulungannya, kanopi beton, dan papan nama.
static func _shopfront(mb: MeshBuilder, xf: Transform3D, w: float, s: Dictionary) -> void:
	var ow: float = w - 0.5
	var oh: float = RUKO_GROUND - 0.4
	var door: StringName = s.get("door", &"closed")
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	if door == &"glass":
		_glass_front(mb, xf, ow, oh, s)
		mb.box(xf * _at(Vector3(0.0, RUKO_GROUND, -0.45)), Vector3(w, 0.1, 0.9), (s["wall"] as Color).darkened(0.08))
		_signboard(mb, xf, w, s)
		return
	var open_h: float = oh
	if door == &"closed":
		open_h = 0.0
	elif door == &"half":
		open_h = oh * 0.55
	if open_h > 0.0:
		_panel(mb, xf, Vector2(0.0, open_h * 0.5), Vector2(ow, open_h), -0.01, nrm, Palette.SHOP_INTERIOR)
		_goods(mb, xf, ow, open_h, s)
	if open_h < oh:
		var sh: float = oh - open_h
		mb.box(xf * _at(Vector3(0.0, open_h + sh * 0.5, -0.02)), Vector3(ow, sh, 0.04), Palette.SHUTTER)
		var n: int = maxi(1, int(sh / 0.13))
		for i in n:
			var y: float = open_h + sh * (float(i) + 0.45) / float(n)
			_panel(mb, xf, Vector2(0.0, y), Vector2(ow, 0.025), -0.041, nrm, Palette.SHUTTER_LINE)
		mb.box(xf * _at(Vector3(0.0, open_h + 0.04, -0.05)), Vector3(ow, 0.06, 0.03), Palette.SHUTTER_LINE)
	mb.box(xf * _at(Vector3(0.0, oh + 0.11, -0.07)), Vector3(ow + 0.12, 0.22, 0.14), Palette.SHUTTER.darkened(0.1))
	mb.box(xf * _at(Vector3(0.0, RUKO_GROUND, -0.45)), Vector3(w, 0.1, 0.9), (s["wall"] as Color).darkened(0.08))
	_signboard(mb, xf, w, s)


## Muka kaca toko modern: bagian dalam terang dengan rak barang, tiang-tiang kaca,
## dan pintu kaca di tengah (tanpa pintu gulung).
static func _glass_front(mb: MeshBuilder, xf: Transform3D, ow: float, oh: float, s: Dictionary) -> void:
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	var frame: Color = Palette.CABLE.lightened(0.45)
	_panel(mb, xf, Vector2(0.0, oh * 0.5), Vector2(ow, oh), -0.01, nrm, Palette.FLOUR_WHITE.darkened(0.12))
	_goods(mb, xf, ow, oh - 0.1, s)
	for i in 5:
		var mx: float = -ow * 0.5 + ow * float(i) / 4.0
		_panel(mb, xf, Vector2(mx, oh * 0.5), Vector2(0.06, oh), -0.1, nrm, frame)
	_panel(mb, xf, Vector2(0.0, oh - 0.03), Vector2(ow, 0.06), -0.1, nrm, frame)
	_panel(mb, xf, Vector2(0.0, 1.0), Vector2(1.0, 2.0), -0.11, nrm, frame)
	_panel(mb, xf, Vector2(0.0, 1.0), Vector2(0.88, 1.92), -0.115, nrm, Palette.WINDOW_GLASS.lightened(0.15))


## Barang dagangan di balik pintu yang terbuka: rak bersusun berisi kemasan
## warna-warni, renteng sachet (warung), dan etalase kaca di depan pintu.
static func _goods(mb: MeshBuilder, xf: Transform3D, ow: float, open_h: float, s: Dictionary) -> void:
	var colors: Array = s.get("goods", [Palette.HONEY, Palette.PASTEL_MINT, Palette.ROSY_CHEEK])
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	var rows: int = clampi(int((open_h - 0.2) / 0.42), 1, 4)
	var k: int = 0
	for r in rows:
		var y: float = 0.22 + 0.42 * float(r)
		mb.box(xf * _at(Vector3(0.0, y, -0.04)), Vector3(ow - 0.16, 0.035, 0.07), Palette.DOOR_WOOD)
		var x: float = -ow * 0.5 + 0.14
		while x < ow * 0.5 - 0.3:
			var bw: float = 0.14 + 0.06 * float((k * 7) % 3)
			var bh: float = 0.16 + 0.05 * float((k * 5) % 3)
			_panel(mb, xf, Vector2(x + bw * 0.5, y + 0.0175 + bh * 0.5), Vector2(bw, bh), -0.05, nrm, colors[k % colors.size()])
			x += bw + 0.05
			k += 1
	if bool(s.get("sachets", false)):
		var x2: float = -ow * 0.5 + 0.15
		var j: int = 0
		while x2 < ow * 0.5 - 0.1:
			_panel(mb, xf, Vector2(x2, open_h - 0.3), Vector2(0.09, 0.48), -0.09, nrm, colors[(j + 1) % colors.size()])
			x2 += 0.2
			j += 1
	if bool(s.get("counter", false)):
		var cw: float = ow * 0.4
		var cx: float = ow * 0.22
		mb.box(xf * _at(Vector3(cx, 0.4, -0.3)), Vector3(cw, 0.8, 0.36), Palette.FLOUR_WHITE.darkened(0.06))
		_panel(mb, xf, Vector2(cx, 0.48), Vector2(cw - 0.08, 0.5), -0.485, nrm, Palette.WINDOW_GLASS)


## Papan nama tanpa tulisan di atas kanopi: warna toko, gambar sederhana jenis
## usahanya, dan dua garis pengganti tulisan.
static func _signboard(mb: MeshBuilder, xf: Transform3D, w: float, s: Dictionary) -> void:
	var sw: float = w - 0.3
	var sh: float = 0.6
	var cy: float = RUKO_GROUND + 0.1 + sh * 0.5
	var color: Color = s.get("sign", Palette.SIGN_BLUE)
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	mb.box(xf * _at(Vector3(0.0, cy, -0.055)), Vector3(sw + 0.06, sh + 0.06, 0.06), color.darkened(0.25))
	mb.box(xf * _at(Vector3(0.0, cy, -0.06)), Vector3(sw, sh, 0.08), color)
	var logo: StringName = s.get("logo", &"bars")
	var ink: Color = Palette.STRAWBERRY_DEEP if logo == &"bars" else Palette.FLOUR_WHITE
	var zf: float = -0.102
	var lx: float = -sw * 0.5 + 0.38
	match logo:
		&"cross":
			_panel(mb, xf, Vector2(lx, cy), Vector2(0.34, 0.1), zf, nrm, ink)
			_panel(mb, xf, Vector2(lx, cy), Vector2(0.1, 0.34), zf - 0.002, nrm, ink)
		&"phone":
			_panel(mb, xf, Vector2(lx, cy), Vector2(0.2, 0.36), zf, nrm, ink)
			_panel(mb, xf, Vector2(lx, cy + 0.02), Vector2(0.14, 0.24), zf - 0.002, nrm, color.darkened(0.3))
		&"bubbles":
			_dot(mb, xf, Vector2(lx - 0.07, cy - 0.06), 0.1, zf, ink)
			_dot(mb, xf, Vector2(lx + 0.1, cy + 0.05), 0.075, zf, ink)
			_dot(mb, xf, Vector2(lx - 0.03, cy + 0.16), 0.05, zf, ink)
		&"stripes":
			for i in 4:
				_panel(mb, xf, Vector2(lx - 0.15 + 0.1 * float(i), cy), Vector2(0.07, 0.4), zf, nrm, Palette.STRAWBERRY if i % 2 == 0 else Palette.FLOUR_WHITE)
		_:
			_dot(mb, xf, Vector2(lx, cy), 0.16, zf, ink)
	var tx: float = lx + 0.32
	var avail: float = sw * 0.5 - 0.15 - tx
	_panel(mb, xf, Vector2(tx + avail * 0.5, cy + 0.1), Vector2(avail, 0.11), zf, nrm, ink)
	_panel(mb, xf, Vector2(tx + avail * 0.35, cy - 0.1), Vector2(avail * 0.7, 0.07), zf, nrm, ink)


## Lantai atas ruko: dua jendela berteralis dengan AC di antaranya, atau balkon
## berpagar dengan jemuran.
static func _ruko_upper(mb: MeshBuilder, xf: Transform3D, w: float, s: Dictionary) -> void:
	var g: float = RUKO_GROUND
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	if s.get("upper", &"windows") == &"balcony":
		var bw: float = w - 0.5
		mb.box(xf * _at(Vector3(0.0, g + 0.86, -0.28)), Vector3(bw, 0.08, 0.56), Palette.CONCRETE)
		_window_on(mb, xf * _face(Vector3(0.0, g + 1.5, 0.0), 0.0), Vector2(bw - 0.7, 1.1))
		var n: int = int(bw / 0.13)
		for i in n:
			var bx: float = -bw * 0.5 + bw * (float(i) + 0.5) / float(n)
			_panel(mb, xf, Vector2(bx, g + 1.2), Vector2(0.035, 0.6), -0.54, nrm, Palette.IRON_FENCE)
		mb.box(xf * _at(Vector3(0.0, g + 1.51, -0.54)), Vector3(bw, 0.04, 0.05), Palette.IRON_FENCE)
		var clothes: Array[Color] = [Palette.ROSY_CHEEK, Palette.PASTEL_MINT, Palette.BUTTER_YELLOW]
		for i2 in clothes.size():
			_panel(mb, xf, Vector2(-bw * 0.5 + 0.45 + 0.42 * float(i2), g + 1.32), Vector2(0.3, 0.38), -0.565, nrm, clothes[i2])
	else:
		for wx: float in [-w * 0.25, w * 0.25]:
			_window_on(mb, xf * _face(Vector3(wx, g + 1.45, 0.0), 0.0), Vector2(0.9, 0.85))
			_grille(mb, xf, wx, g + 1.45, 0.9, 0.85)
		if bool(s.get("ac", false)):
			mb.box(xf * _at(Vector3(0.0, g + 1.2, -0.14)), Vector3(0.6, 0.42, 0.26), Palette.FLOUR_WHITE.darkened(0.06))
			_dot(mb, xf, Vector2(-0.06, g + 1.2), 0.14, -0.275, Palette.CABLE.lightened(0.3))


## Teralis besi di depan jendela berpusat di (x, y) muka `xf`.
static func _grille(mb: MeshBuilder, xf: Transform3D, x: float, y: float, ww: float, wh: float) -> void:
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	for i in 5:
		var bx: float = x - ww * 0.5 + ww * (float(i) + 0.5) / 5.0
		_panel(mb, xf, Vector2(bx, y), Vector2(0.025, wh), -0.07, nrm, Palette.IRON_FENCE)
	for hy: float in [y - wh * 0.25, y + wh * 0.25]:
		_panel(mb, xf, Vector2(x, hy), Vector2(ww, 0.025), -0.072, nrm, Palette.IRON_FENCE)


## Segi empat datar di bidang XY lokal `xf` setebal nol pada z lokal `z`.
static func _panel(mb: MeshBuilder, xf: Transform3D, c: Vector2, size: Vector2, z: float, nrm: Vector3, color: Color) -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y * 0.5
	mb.quad(xf * Vector3(c.x - hx, c.y - hy, z), xf * Vector3(c.x + hx, c.y - hy, z),
		xf * Vector3(c.x + hx, c.y + hy, z), xf * Vector3(c.x - hx, c.y + hy, z), nrm, color)


## Lingkaran datar menghadap -Z lokal `xf`, berpusat di (x, y) pada z lokal `z`.
static func _dot(mb: MeshBuilder, xf: Transform3D, c: Vector2, r: float, z: float, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 12:
		var a: float = TAU * float(k) / 12.0
		pts.append(Vector2(cos(a) * r, sin(a) * r))
	mb.polygon(xf * _at(Vector3(c.x, c.y, z)), pts, color, Vector3(0.0, 0.0, -1.0))


# ===========================================================================
# TANAH, JALAN, GOT
# ===========================================================================

## Rumput berbentuk cincin konsentris supaya pudarnya ke warna latar mulus.
static func _ground(mb: MeshBuilder, c: Vector2) -> void:
	var radii: Array[float] = [0.0, 6.0, 11.0, 15.0, 19.0, 24.0, 30.0, 42.0, 60.0]
	var segs: int = 32
	for r in radii.size() - 1:
		var r0: float = radii[r]
		var r1: float = radii[r + 1]
		for k in segs:
			var a0: float = TAU * float(k) / float(segs)
			var a1: float = TAU * float(k + 1) / float(segs)
			mb.quad(Vector3(c.x + cos(a0) * r0, Y_GROUND, c.y + sin(a0) * r0), Vector3(c.x + cos(a1) * r0, Y_GROUND, c.y + sin(a1) * r0),
				Vector3(c.x + cos(a1) * r1, Y_GROUND, c.y + sin(a1) * r1), Vector3(c.x + cos(a0) * r1, Y_GROUND, c.y + sin(a0) * r1),
				Vector3.UP, Palette.GRASS)


static func _road(mb: MeshBuilder) -> void:
	_flat(mb, ROAD_X0, ROAD_X1, ROAD_FAR, ROAD_NEAR, Y_ROAD, Palette.ASPHALT)
	# Tambalan aspal: jalan komplek yang sudah lama dipakai.
	for r: Rect2 in [Rect2(-7.5, -3.9, 1.6, 1.1), Rect2(3.2, -2.3, 2.2, 0.8), Rect2(15.5, -4.2, 1.4, 1.5), Rect2(-17.0, -2.0, 2.6, 0.7)]:
		_flat(mb, r.position.x, r.end.x, r.position.y, r.end.y, Y_ROAD + 0.002, Palette.ASPHALT_PATCH)


## Got beton di tepi jalan: dua bibir beton dan saluran gelap di antaranya.
## `edge_z` = tepi jalan, `out` = arah menjauhi jalan (+1 sisi toko, -1 seberang).
static func _gutter(mb: MeshBuilder, edge_z: float, out: float) -> void:
	var z_out: float = edge_z + out * GUTTER_W
	for zc: float in [edge_z + out * LIP * 0.5, z_out - out * LIP * 0.5]:
		_ledge(mb, ROAD_X0, ROAD_X1, zc, LIP, Y_GROUND, 0.03, Palette.CONCRETE)
	var za: float = minf(edge_z, z_out) + LIP
	var zb: float = maxf(edge_z, z_out) - LIP
	_flat(mb, ROAD_X0, ROAD_X1, za, zb, Y_ROAD, Palette.GUTTER)


## Tutup got beton selebar x0..x1 (jalan masuk rumah dan toko).
static func _slab(mb: MeshBuilder, x0: float, x1: float, edge_z: float, out: float) -> void:
	var zc: float = edge_z + out * GUTTER_W * 0.5
	mb.box(_at(Vector3((x0 + x1) * 0.5, 0.02, zc)), Vector3(x1 - x0, 0.05, GUTTER_W + 0.02), Palette.CONCRETE.lightened(0.05))


## Paving halaman x0..x1, z0..z1.
static func _paving(mb: MeshBuilder, x0: float, x1: float, z0: float, z1: float, color: Color) -> void:
	_flat(mb, x0, x1, minf(z0, z1), maxf(z0, z1), Y_YARD, color)


## Balok rendah memanjang x0..x1 berpusat di z `zc` (bibir got). Hanya sisi atas
## dan sisi yang menghadap kamera (-Z) yang dibuat, dipotong per PIECE.
static func _ledge(mb: MeshBuilder, x0: float, x1: float, zc: float, depth: float, y0: float, y1: float, color: Color) -> void:
	var n: int = maxi(1, ceili((x1 - x0) / PIECE))
	var za: float = zc - depth * 0.5
	var zb: float = zc + depth * 0.5
	for i in n:
		var xa: float = lerpf(x0, x1, float(i) / float(n))
		var xb: float = lerpf(x0, x1, float(i + 1) / float(n))
		mb.quad(Vector3(xa, y1, za), Vector3(xb, y1, za), Vector3(xb, y1, zb), Vector3(xa, y1, zb), Vector3.UP, color)
		mb.quad(Vector3(xa, y0, za), Vector3(xb, y0, za), Vector3(xb, y1, za), Vector3(xa, y1, za), Vector3.FORWARD, color)


## Seperti _ledge, memanjang z0..z1 berpusat di x `xc`: sisi atas dan sisi -X.
static func _ledge_z(mb: MeshBuilder, z0: float, z1: float, xc: float, width: float, y0: float, y1: float, color: Color) -> void:
	var n: int = maxi(1, ceili((z1 - z0) / PIECE))
	var xa: float = xc - width * 0.5
	var xb: float = xc + width * 0.5
	for i in n:
		var za: float = lerpf(z0, z1, float(i) / float(n))
		var zb: float = lerpf(z0, z1, float(i + 1) / float(n))
		mb.quad(Vector3(xa, y1, za), Vector3(xb, y1, za), Vector3(xb, y1, zb), Vector3(xa, y1, zb), Vector3.UP, color)
		mb.quad(Vector3(xa, y0, za), Vector3(xa, y0, zb), Vector3(xa, y1, zb), Vector3(xa, y1, za), Vector3.LEFT, color)


## Got beton sepanjang z (jalan kampung Tier 2): `edge_x` = tepi aspal, `out` =
## arah menjauhi jalan (+1 ke +x, -1 ke -x).
static func _gutter_z(mb: MeshBuilder, edge_x: float, out: float, z0: float, z1: float) -> void:
	var x_out: float = edge_x + out * GUTTER_W
	for xc: float in [edge_x + out * LIP * 0.5, x_out - out * LIP * 0.5]:
		_ledge_z(mb, z0, z1, xc, LIP, Y_GROUND, 0.03, Palette.CONCRETE)
	_flat(mb, minf(edge_x, x_out) + LIP, maxf(edge_x, x_out) - LIP, z0, z1, Y_ROAD, Palette.GUTTER)


## Bidang datar x0..x1, z0..z1 setinggi y, dipotong menjadi petak paling lebar
## PIECE supaya pudarnya mengikuti jarak.
static func _flat(mb: MeshBuilder, x0: float, x1: float, z0: float, z1: float, y: float, color: Color) -> void:
	var nx: int = maxi(1, ceili((x1 - x0) / PIECE))
	var nz: int = maxi(1, ceili((z1 - z0) / PIECE))
	for i in nx:
		var xa: float = lerpf(x0, x1, float(i) / float(nx))
		var xb: float = lerpf(x0, x1, float(i + 1) / float(nx))
		for j in nz:
			var za: float = lerpf(z0, z1, float(j) / float(nz))
			var zb: float = lerpf(z0, z1, float(j + 1) / float(nz))
			mb.quad(Vector3(xa, y, za), Vector3(xb, y, za), Vector3(xb, y, zb), Vector3(xa, y, zb), Vector3.UP, color)


# ===========================================================================
# RUMAH
# ===========================================================================

## Rumah satu lantai. `xf` = pusat dasar dinding depan; -Z lokal menghadap keluar
## (ke jalan), +Z lokal ke belakang. Spec:
##   w, dpt, h       lebar, kedalaman, tinggi dinding (m)
##   wall            warna cat
##   roof, roof_deep atap sisi terang dan sisi teduh (bawaan genteng ROOF_TILE)
##   ridge           &"x" bubungan sejajar muka rumah, &"z" pelana menghadap depan
##   rise, ov        tinggi atap di atas dinding, tritisan; ov_side tritisan samping
##   porch           kedalaman teras berlantai keramik di depan (0 = tanpa)
##   door, windows   posisi x lokal pintu dan jendela depan
##   back_windows    posisi x lokal jendela belakang
##   side_windows    posisi z lokal jendela di sisi yang menghadap kamera
##   chairs, canopy  kursi teras, kanopi kecil di atas pintu
##   front_detail    false: muka rumah tidak terlihat kamera, pintu dan jendela
##                   depannya tidak dibuat
static func _house(mb: MeshBuilder, xf: Transform3D, s: Dictionary) -> void:
	var w: float = float(s["w"])
	var dpt: float = float(s["dpt"])
	var h: float = float(s["h"])
	var wall: Color = s["wall"]
	var rise: float = float(s.get("rise", 1.2))
	var ov: float = float(s.get("ov", 0.35))
	var porch: float = float(s.get("porch", 0.0))
	mb.box(xf * _at(Vector3(0.0, (h + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, h - Y_GROUND, dpt), wall)
	mb.box(xf * _at(Vector3(0.0, 0.11, dpt * 0.5)), Vector3(w + 0.04, 0.3, dpt + 0.04), wall.darkened(0.14))
	var roof: Color = s.get("roof", Palette.ROOF_TILE)
	var roof_deep: Color = s.get("roof_deep", Palette.ROOF_TILE_DEEP)
	if s.get("ridge", &"x") == &"x":
		_roof_x(mb, xf, w, dpt, h, rise, ov, float(s.get("ov_side", ov)), porch, wall, roof, roof_deep)
	else:
		_roof_z(mb, xf, w, dpt, h, rise, ov, wall, roof, roof_deep)
	if porch > 0.0:
		_porch(mb, xf, w, h, rise / (dpt * 0.5), porch, bool(s.get("chairs", false)))
	if bool(s.get("front_detail", true)):
		if s.has("door"):
			_door_on(mb, xf * _face(Vector3(float(s["door"]), 0.0, 0.0), 0.0), wall)
			if bool(s.get("canopy", false)):
				mb.box(xf * _at(Vector3(float(s["door"]), 2.3, -0.35)), Vector3(1.3, 0.06, 0.7), roof_deep)
		for wx: Variant in s.get("windows", []):
			_window_on(mb, xf * _face(Vector3(float(wx), h * 0.5, 0.0), 0.0), Vector2(1.0, 1.0))
	for bx: Variant in s.get("back_windows", []):
		_window_on(mb, xf * _face(Vector3(float(bx), h * 0.55, dpt), PI), Vector2(0.7, 0.6))
	# Jendela samping pada sisi yang menghadap kamera (dunia -X).
	var cam_side: float = -1.0 if (xf.basis * Vector3.RIGHT).x > 0.0 else 1.0
	for sz: Variant in s.get("side_windows", []):
		_window_on(mb, xf * _face(Vector3(cam_side * w * 0.5, h * 0.5, float(sz)), -cam_side * PI * 0.5), Vector2(0.8, 0.9))


## Atap pelana dengan bubungan sejajar muka rumah; tritisan depan menaungi teras.
static func _roof_x(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float, h: float, rise: float,
		ov: float, ov_side: float, porch: float, wall: Color, roof: Color, roof_deep: Color) -> void:
	var half: float = dpt * 0.5
	var slope: float = rise / half
	var x0: float = -w * 0.5 - ov_side
	var x1: float = w * 0.5 + ov_side
	var zf: float = -maxf(ov, porch)
	var zb: float = dpt + ov
	var yf: float = h + zf * slope
	var yb: float = h - ov * slope
	var yr: float = h + rise
	var nf: Vector3 = xf.basis * Vector3(0.0, half, -rise).normalized()
	var nbk: Vector3 = xf.basis * Vector3(0.0, half, rise).normalized()
	mb.quad(xf * Vector3(x0, yf, zf), xf * Vector3(x1, yf, zf), xf * Vector3(x1, yr, half), xf * Vector3(x0, yr, half), nf, roof)
	mb.quad(xf * Vector3(x0, yr, half), xf * Vector3(x1, yr, half), xf * Vector3(x1, yb, zb), xf * Vector3(x0, yb, zb), nbk, roof_deep)
	# Bubungan dan lisplang (papan tepi atap).
	mb.box(xf * _at(Vector3(0.0, yr + 0.02, half)), Vector3(x1 - x0 + 0.04, 0.1, 0.16), roof_deep.darkened(0.08))
	mb.box(xf * _at(Vector3(0.0, yf - 0.05, zf)), Vector3(x1 - x0, 0.1, 0.04), Palette.FLOUR_WHITE.darkened(0.04))
	mb.box(xf * _at(Vector3(0.0, yb - 0.05, zb)), Vector3(x1 - x0, 0.1, 0.04), Palette.FLOUR_WHITE.darkened(0.08))
	for sx: float in [-1.0, 1.0]:
		var x: float = sx * w * 0.5
		mb.triangle(xf * Vector3(x, h, 0.0), xf * Vector3(x, h, dpt), xf * Vector3(x, yr - 0.02, half), xf.basis * Vector3(sx, 0.0, 0.0), wall)


## Atap pelana yang menghadap depan: segitiga pelana tampak di muka rumah.
static func _roof_z(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float, h: float, rise: float,
		ov: float, wall: Color, roof: Color, roof_deep: Color) -> void:
	var half: float = w * 0.5
	var slope: float = rise / half
	var z0: float = -ov
	var z1: float = dpt + ov
	var ye: float = h - ov * slope
	var yr: float = h + rise
	var xl: float = -half - ov
	var xr: float = half + ov
	var nl: Vector3 = xf.basis * Vector3(-rise, half, 0.0).normalized()
	var nr: Vector3 = xf.basis * Vector3(rise, half, 0.0).normalized()
	mb.quad(xf * Vector3(xl, ye, z0), xf * Vector3(0.0, yr, z0), xf * Vector3(0.0, yr, z1), xf * Vector3(xl, ye, z1), nl, roof)
	mb.quad(xf * Vector3(0.0, yr, z0), xf * Vector3(xr, ye, z0), xf * Vector3(xr, ye, z1), xf * Vector3(0.0, yr, z1), nr, roof_deep)
	mb.box(xf * _at(Vector3(0.0, yr + 0.02, dpt * 0.5)), Vector3(0.16, 0.1, z1 - z0 + 0.04), roof_deep.darkened(0.08))
	mb.triangle(xf * Vector3(-half, h, 0.0), xf * Vector3(half, h, 0.0), xf * Vector3(0.0, yr - 0.02, 0.0), xf.basis * Vector3(0.0, 0.0, -1.0), wall)
	mb.triangle(xf * Vector3(-half, h, dpt), xf * Vector3(half, h, dpt), xf * Vector3(0.0, yr - 0.02, dpt), xf.basis * Vector3(0.0, 0.0, 1.0), wall)
	# Lisplang putih mengikuti kedua tepi pelana depan dan belakang.
	for z: float in [z0, z1]:
		_stick(mb, xf * Vector3(xl, ye - 0.04, z), xf * Vector3(0.0, yr - 0.04, z), 0.07, Palette.FLOUR_WHITE.darkened(0.04))
		_stick(mb, xf * Vector3(0.0, yr - 0.04, z), xf * Vector3(xr, ye - 0.04, z), 0.07, Palette.FLOUR_WHITE.darkened(0.04))


## Teras berlantai keramik di depan rumah, tiang di kedua sudut depan, dan
## (bila diminta) sepasang kursi dengan meja kecil.
static func _porch(mb: MeshBuilder, xf: Transform3D, w: float, h: float, slope: float, depth: float, chairs: bool) -> void:
	mb.box(xf * _at(Vector3(0.0, 0.04, -depth * 0.5)), Vector3(w, 0.16, depth), Palette.TERRACE_TILE)
	mb.box(xf * _at(Vector3(0.0, -0.01, -depth - 0.12)), Vector3(w * 0.5, 0.08, 0.24), Palette.CONCRETE)
	var pz: float = -depth + 0.15
	var top: float = h + pz * slope - 0.08
	for sx: float in [-1.0, 1.0]:
		mb.box(xf * _at(Vector3(sx * (w * 0.5 - 0.15), (top + 0.12) * 0.5, pz)), Vector3(0.16, top - 0.12, 0.16), Palette.FLOUR_WHITE.darkened(0.03))
	if chairs:
		for cx: float in [-w * 0.5 + 0.9, -w * 0.5 + 1.9]:
			_chair(mb, xf * _at(Vector3(cx, 0.12, -depth * 0.5)))
		mb.box(xf * _at(Vector3(-w * 0.5 + 1.4, 0.38, -depth * 0.5)), Vector3(0.42, 0.04, 0.42), Palette.DOOR_WOOD)
		mb.box(xf * _at(Vector3(-w * 0.5 + 1.4, 0.24, -depth * 0.5)), Vector3(0.08, 0.26, 0.08), Palette.DOOR_WOOD)


static func _chair(mb: MeshBuilder, xf: Transform3D) -> void:
	mb.box(xf * _at(Vector3(0.0, 0.3, 0.0)), Vector3(0.42, 0.05, 0.42), Palette.CARAMEL)
	mb.box(xf * _at(Vector3(0.0, 0.55, 0.19)), Vector3(0.42, 0.45, 0.05), Palette.CARAMEL)
	for k in 4:
		var lx: float = -0.18 if k < 2 else 0.18
		var lz: float = -0.18 if k % 2 == 0 else 0.18
		mb.box(xf * _at(Vector3(lx, 0.14, lz)), Vector3(0.04, 0.3, 0.04), Palette.DARK_CHOCOLATE)


## Bidang dinding untuk jendela atau pintu: titik `p` (lokal rumah) dengan -Z
## lokal menghadap keluar setelah diputar `yaw`.
static func _face(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## Jendela berkusen putih dengan kaca, tiang tengah, dan ambang.
static func _window_on(mb: MeshBuilder, fx: Transform3D, size: Vector2) -> void:
	mb.box(fx * _at(Vector3(0.0, 0.0, -0.02)), Vector3(size.x + 0.12, size.y + 0.12, 0.05), Palette.FLOUR_WHITE)
	mb.box(fx * _at(Vector3(0.0, 0.0, -0.045)), Vector3(size.x, size.y, 0.02), Palette.WINDOW_GLASS)
	mb.box(fx * _at(Vector3(0.0, 0.0, -0.057)), Vector3(0.04, size.y, 0.012), Palette.FLOUR_WHITE)
	mb.box(fx * _at(Vector3(0.0, -size.y * 0.5 - 0.08, -0.06)), Vector3(size.x + 0.18, 0.05, 0.1), Palette.FLOUR_WHITE.darkened(0.06))


## Pintu kayu berkusen dengan gagang dan lubang angin di atasnya.
static func _door_on(mb: MeshBuilder, fx: Transform3D, wall: Color) -> void:
	mb.box(fx * _at(Vector3(0.0, 1.03, -0.02)), Vector3(1.0, 2.1, 0.05), Palette.FLOUR_WHITE)
	mb.box(fx * _at(Vector3(0.0, 1.0, -0.045)), Vector3(0.84, 1.98, 0.03), Palette.DOOR_WOOD)
	mb.box(fx * _at(Vector3(0.28, 1.0, -0.07)), Vector3(0.06, 0.06, 0.03), Palette.GOLD_STAR)
	mb.box(fx * _at(Vector3(0.0, 2.24, -0.03)), Vector3(0.84, 0.14, 0.04), wall.lightened(0.25))


# ===========================================================================
# PAGAR, POHON, BENDA KECIL
# ===========================================================================

## Pagar depan sepanjang X: tembok rendah bercat, tiang bata, jeruji besi, dan
## gerbang. `gates` = [[x0, x1, tertutup], ...]; gerbang tertutup berjeruji
## sampai bawah, yang terbuka dibiarkan kosong.
static func _fence(mb: MeshBuilder, x0: float, x1: float, z: float, paint: Color, gates: Array) -> void:
	var base_h: float = 0.36
	var top_h: float = 1.0
	var cuts: Array[Vector2] = []
	var a: float = x0
	for g: Variant in gates:
		var ga: Array = g
		cuts.append(Vector2(a, float(ga[0])))
		a = float(ga[1])
		if bool(ga[2]):
			_bars(mb, float(ga[0]) + 0.05, float(ga[1]) - 0.05, z, 0.05, top_h - 0.04)
			mb.box(_at(Vector3((float(ga[0]) + float(ga[1])) * 0.5, top_h - 0.04, z)), Vector3(float(ga[1]) - float(ga[0]) - 0.1, 0.05, 0.05), Palette.IRON_FENCE)
			mb.box(_at(Vector3((float(ga[0]) + float(ga[1])) * 0.5, 0.08, z)), Vector3(float(ga[1]) - float(ga[0]) - 0.1, 0.05, 0.05), Palette.IRON_FENCE)
	cuts.append(Vector2(a, x1))
	for c: Vector2 in cuts:
		if c.y - c.x < 0.05:
			continue
		var mid: float = (c.x + c.y) * 0.5
		var length: float = c.y - c.x
		mb.box(_at(Vector3(mid, (base_h + Y_GROUND) * 0.5, z)), Vector3(length, base_h - Y_GROUND, 0.14), paint.darkened(0.05))
		mb.box(_at(Vector3(mid, base_h + 0.02, z)), Vector3(length + 0.02, 0.04, 0.18), paint.darkened(0.15))
		_bars(mb, c.x, c.y, z, base_h + 0.04, top_h)
		mb.box(_at(Vector3(mid, top_h - 0.02, z)), Vector3(length, 0.04, 0.05), Palette.IRON_FENCE)
		var pillars: int = maxi(1, int(ceil(length / 2.4)))
		for k in pillars + 1:
			var px: float = c.x + length * float(k) / float(pillars)
			mb.box(_at(Vector3(px, (top_h + 0.12 + Y_GROUND) * 0.5, z)), Vector3(0.24, top_h + 0.12 - Y_GROUND, 0.24), paint)
			mb.box(_at(Vector3(px, top_h + 0.15, z)), Vector3(0.3, 0.06, 0.3), paint.darkened(0.15))


## Jeruji besi tegak di antara x0..x1 setinggi y0..y1. Setiap jeruji cukup satu
## bidang yang menghadap kamera (-Z): ratusan jeruji tetap murah.
static func _bars(mb: MeshBuilder, x0: float, x1: float, z: float, y0: float, y1: float) -> void:
	var n: int = maxi(1, int((x1 - x0) / 0.17))
	var hw: float = 0.022
	var zf: float = z - 0.013
	for k in n:
		var x: float = x0 + (x1 - x0) * (float(k) + 0.5) / float(n)
		mb.quad(Vector3(x - hw, y0, zf), Vector3(x + hw, y0, zf), Vector3(x + hw, y1, zf), Vector3(x - hw, y1, zf), Vector3.FORWARD, Palette.IRON_FENCE)


## Pohon mangga: batang bercabang dan tajuk bulat rimbun. `s` = skala.
static func _mango_tree(mb: MeshBuilder, p: Vector3, s: float) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.8 * s + Y_GROUND * 0.5, 0.0)), 1.6 * s - Y_GROUND, 0.12 * s, 0.18 * s, Palette.TRUNK, 7)
	mb.capsule(p + Vector3(0.0, 1.3 * s, 0.0), p + Vector3(0.5 * s, 1.95 * s, 0.25 * s), 0.08 * s, 0.06 * s, Palette.TRUNK, 5, 1)
	mb.capsule(p + Vector3(0.0, 1.4 * s, 0.0), p + Vector3(-0.45 * s, 2.0 * s, -0.3 * s), 0.08 * s, 0.06 * s, Palette.TRUNK, 5, 1)
	mb.ellipsoid(_at(p + Vector3(0.0, 2.45 * s, 0.0)), Vector3(1.35, 1.0, 1.35) * s, Palette.LEAF, 10, 6)
	mb.ellipsoid(_at(p + Vector3(0.75 * s, 2.2 * s, -0.35 * s)), Vector3(0.8, 0.65, 0.8) * s, Palette.LEAF_DEEP, 8, 5)
	mb.ellipsoid(_at(p + Vector3(-0.65 * s, 2.3 * s, 0.5 * s)), Vector3(0.85, 0.7, 0.85) * s, Palette.LEAF.darkened(0.06), 8, 5)
	mb.ellipsoid(_at(p + Vector3(0.1 * s, 3.1 * s, 0.1 * s)), Vector3(0.8, 0.55, 0.8) * s, Palette.LEAF.lightened(0.06), 8, 5)


## Pohon pisang: batang hijau dan enam pelepah daun lebar yang melengkung keluar.
static func _banana_tree(mb: MeshBuilder, p: Vector3, yaw: float) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.75 + Y_GROUND * 0.5, 0.0)), 1.5 - Y_GROUND, 0.09, 0.13, Palette.GRASS_DEEP.darkened(0.18), 7)
	for i in 6:
		var a: float = yaw + TAU * float(i) / 6.0
		var dir := Vector3(sin(a), 0.0, -cos(a))
		var tilt: float = 0.45 + 0.2 * float(i % 2)
		var length: float = 1.15
		var axis: Vector3 = (dir * cos(tilt) + Vector3.UP * sin(tilt)).normalized()
		var across: Vector3 = Vector3.UP.cross(dir).normalized()
		var normal: Vector3 = axis.cross(across).normalized()
		var center: Vector3 = p + Vector3(0.0, 1.5, 0.0) + axis * (length * 0.5)
		mb.box(Transform3D(Basis(across, normal, axis), center), Vector3(0.36, 0.02, length), Palette.LEAF if i % 2 == 0 else Palette.LEAF_DEEP)


## Minimarket satu lantai: muka kaca dengan rak warna-warni di baliknya, pintu kaca
## di tengah, kanopi tipis, pita papan nama bergaris tanpa tulisan, dak berdinding
## pembatas dengan unit AC dan toren, dan di sisi -X pintu servis serta unit AC.
static func _minimarket(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float) -> void:
	var h: float = 3.4
	var wall: Color = Palette.FLOUR_WHITE.darkened(0.05)
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	mb.box(xf * _at(Vector3(0.0, (h + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, h - Y_GROUND, dpt), wall)
	mb.box(xf * _at(Vector3(0.0, h + 0.015, dpt * 0.5)), Vector3(w - 0.2, 0.03, dpt - 0.2), Palette.CONCRETE_DARK)
	for sx: float in [-1.0, 1.0]:
		mb.box(xf * _at(Vector3(sx * (w * 0.5 - 0.05), h + 0.2, dpt * 0.5)), Vector3(0.1, 0.4, dpt), wall)
	mb.box(xf * _at(Vector3(0.0, h + 0.2, dpt - 0.05)), Vector3(w - 0.2, 0.4, 0.1), wall)
	for i in 3:
		var cp: Vector3 = Vector3(-w * 0.3 + w * 0.3 * float(i), h + 0.3, dpt * 0.35)
		mb.box(xf * _at(cp), Vector3(0.8, 0.6, 0.55), Palette.FLOUR_WHITE.darkened(0.08))
		mb.disc(xf * _at(cp + Vector3(0.0, 0.305, 0.0)), 0.22, Palette.CABLE.lightened(0.15), Palette.CABLE.lightened(0.35), 10)
	_water_tower(mb, xf * Vector3(w * 0.3, h, dpt * 0.72), Palette.WATER_TANK_BLUE, 0.4)
	mb.box(xf * _at(Vector3(0.0, h - 0.25, -0.06)), Vector3(w + 0.1, 0.9, 0.12), Palette.SIGN_GREEN)
	_panel(mb, xf, Vector2(0.0, h - 0.56), Vector2(w + 0.1, 0.14), -0.125, nrm, Palette.SIGN_ORANGE)
	_dot(mb, xf, Vector2(-w * 0.5 + 0.7, h - 0.2), 0.24, -0.125, Palette.FLOUR_WHITE)
	_panel(mb, xf, Vector2(-w * 0.5 + 2.2, h - 0.12), Vector2(1.9, 0.14), -0.125, nrm, Palette.FLOUR_WHITE)
	_panel(mb, xf, Vector2(-w * 0.5 + 1.95, h - 0.33), Vector2(1.4, 0.09), -0.125, nrm, Palette.FLOUR_WHITE)
	mb.box(xf * _at(Vector3(0.0, 2.62, -0.45)), Vector3(w, 0.08, 0.9), Palette.CONCRETE)
	_glass_front(mb, xf, w - 0.3, 2.5, {"goods": [Palette.STRAWBERRY, Palette.HONEY, Palette.MATCHA, Palette.PASTEL_PERIWINKLE, Palette.BUTTER_YELLOW]})
	var sn: Vector3 = xf.basis * Vector3.LEFT
	var sxw: float = -w * 0.5 - 0.004
	mb.quad(xf * Vector3(sxw, 0.0, dpt - 1.6), xf * Vector3(sxw, 0.0, dpt - 0.7), xf * Vector3(sxw, 2.0, dpt - 0.7), xf * Vector3(sxw, 2.0, dpt - 1.6), sn, Palette.SHUTTER)
	mb.box(xf * _at(Vector3(-w * 0.5 - 0.13, 2.55, dpt * 0.45)), Vector3(0.26, 0.42, 0.6), Palette.FLOUR_WHITE.darkened(0.06))


## Mobil yang diparkir: badan, kabin berkaca, empat roda, bemper, dan lampu.
## Diperkecil (CAR_SCALE) seperti motor dan perabot supaya pas dengan dunia chibi.
## -Z lokal = depan mobil.
static func _car(mb: MeshBuilder, p: Vector3, yaw: float, body: Color) -> void:
	var xf: Transform3D = _at_yaw(p, yaw) * Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * CAR_SCALE), Vector3.ZERO)
	var glass: Color = Palette.WINDOW_GLASS.darkened(0.2)
	mb.box(xf * _at(Vector3(0.0, 0.58, 0.0)), Vector3(1.72, 0.56, 4.1), body)
	mb.box(xf * _at(Vector3(0.0, 1.1, 0.25)), Vector3(1.5, 0.5, 2.2), body)
	mb.box(xf * _at(Vector3(0.0, 1.12, 0.25)), Vector3(1.53, 0.34, 1.96), glass)
	mb.box(xf * _at(Vector3(0.0, 1.12, 0.25)), Vector3(1.36, 0.34, 2.24), glass)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			mb.cylinder(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(sx * 0.76, 0.33, sz * 1.32)), 0.26, 0.33, 0.33, Palette.TIRE, 10)
	for bz: float in [-2.07, 2.07]:
		mb.box(xf * _at(Vector3(0.0, 0.38, bz)), Vector3(1.74, 0.16, 0.08), Palette.CABLE.lightened(0.15))
	for lx: float in [-0.6, 0.6]:
		mb.box(xf * _at(Vector3(lx, 0.72, -2.06)), Vector3(0.3, 0.12, 0.04), Palette.BUTTER_YELLOW)
		mb.box(xf * _at(Vector3(lx, 0.74, 2.06)), Vector3(0.28, 0.1, 0.04), Palette.STRAWBERRY)


## Meja bundar teras kafe dengan dua kursi dan payung.
static func _parasol_set(mb: MeshBuilder, p: Vector3, canopy: Color) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.73, 0.0)), 0.04, 0.4, 0.4, Palette.FLOUR_WHITE, 12)
	mb.cylinder(_at(p + Vector3(0.0, 0.36, 0.0)), 0.72, 0.035, 0.06, Palette.CABLE.lightened(0.3), 6)
	mb.cylinder(_at(p + Vector3(0.0, 1.45, 0.0)), 1.3, 0.025, 0.025, Palette.FLOUR_WHITE.darkened(0.1), 6)
	mb.cylinder(_at(p + Vector3(0.0, 2.0, 0.0)), 0.3, 0.03, 0.85, canopy, 10)
	for sx: float in [-1.0, 1.0]:
		_chair(mb, _at_yaw(p + Vector3(sx * 0.62, 0.0, 0.0), sx * PI * 0.5))


## Lampu jalan kota: tiang ramping dan satu atau dua lengan (`arms` = arah datar)
## dengan kepala lampu. Dasar tiang di `p`.
static func _lamp_post(mb: MeshBuilder, p: Vector3, h: float, arms: Array) -> void:
	var steel: Color = Palette.CABLE.lightened(0.35)
	mb.cylinder(_at(p + Vector3(0.0, h * 0.5, 0.0)), h, 0.045, 0.075, steel, 6)
	var top: Vector3 = p + Vector3(0.0, h, 0.0)
	for a: Variant in arms:
		var dir: Vector3 = a
		var end: Vector3 = top + dir * 1.0 + Vector3(0.0, 0.12, 0.0)
		_stick(mb, top + Vector3(0.0, -0.25, 0.0), end, 0.045, steel)
		var along_x: bool = absf(dir.x) > 0.5
		mb.box(_at(end + dir * 0.12), Vector3(0.36 if along_x else 0.18, 0.07, 0.18 if along_x else 0.36), Palette.FLOUR_WHITE.darkened(0.05))
		_lamp_heads.append(end + dir * 0.12 + Vector3(0.0, -0.06, 0.0))


## Halte bus di trotoar: atap, empat tiang, dinding belakang kaca, bangku, dan
## tiang rambu tanpa tulisan. -Z lokal menghadap jalan.
static func _halte(mb: MeshBuilder, xf: Transform3D) -> void:
	var steel: Color = Palette.CABLE.lightened(0.35)
	mb.box(xf * _at(Vector3(0.0, 2.45, 0.0)), Vector3(3.0, 0.1, 1.4), Palette.SIGN_BLUE.lightened(0.15))
	for sx: float in [-1.35, 1.35]:
		for sz: float in [-0.55, 0.55]:
			mb.box(xf * _at(Vector3(sx, 1.2, sz)), Vector3(0.07, 2.4, 0.07), steel)
	mb.box(xf * _at(Vector3(0.0, 1.35, 0.6)), Vector3(2.7, 1.5, 0.03), Palette.WINDOW_GLASS.lightened(0.1))
	mb.box(xf * _at(Vector3(0.0, 0.45, 0.35)), Vector3(2.4, 0.06, 0.38), steel)
	for bx: float in [-1.0, 1.0]:
		mb.box(xf * _at(Vector3(bx, 0.22, 0.35)), Vector3(0.05, 0.44, 0.3), steel.darkened(0.2))
	mb.cylinder(xf * _at(Vector3(1.75, 1.3, -0.5)), 2.6, 0.03, 0.03, steel, 6)
	mb.box(xf * _at(Vector3(1.75, 2.45, -0.5)), Vector3(0.05, 0.4, 0.4), Palette.SIGN_BLUE)


## Tabung gas 3 kg hijau.
static func _lpg(mb: MeshBuilder, p: Vector3) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.18, 0.0)), 0.34, 0.13, 0.13, Palette.MATCHA, 10)
	mb.ellipsoid(_at(p + Vector3(0.0, 0.35, 0.0)), Vector3(0.13, 0.07, 0.13), Palette.MATCHA, 8, 3)
	mb.cylinder(_at(p + Vector3(0.0, 0.45, 0.0)), 0.06, 0.04, 0.04, Palette.MATCHA_DEEP, 6)


## Tumpukan `n` krat roti plastik.
static func _crates(mb: MeshBuilder, p: Vector3, n: int, color: Color) -> void:
	for i in n:
		mb.box(_at(p + Vector3(0.0, 0.14 + 0.28 * float(i), 0.0)), Vector3(0.6, 0.26, 0.42), color if i % 2 == 0 else color.darkened(0.12))


## Freezer es krim bertutup biru.
static func _freezer(mb: MeshBuilder, p: Vector3) -> void:
	mb.box(_at(p + Vector3(0.0, 0.42, 0.0)), Vector3(1.0, 0.84, 0.6), Palette.FLOUR_WHITE)
	mb.box(_at(p + Vector3(0.0, 0.86, 0.0)), Vector3(0.96, 0.05, 0.56), Palette.SIGN_BLUE)
	mb.box(_at(p + Vector3(0.0, 0.5, -0.31)), Vector3(0.7, 0.36, 0.02), Palette.ROSY_CHEEK)


## Rak galon air minum: dua papan dan empat galon biru muda.
static func _galon_rack(mb: MeshBuilder, p: Vector3) -> void:
	for y: float in [0.06, 0.52]:
		mb.box(_at(p + Vector3(0.0, y, 0.0)), Vector3(0.7, 0.04, 0.36), Palette.CABLE.lightened(0.4))
	for gx: float in [-0.18, 0.18]:
		for gy: float in [0.08, 0.54]:
			mb.cylinder(_at(p + Vector3(gx, gy + 0.2, 0.0)), 0.4, 0.13, 0.14, Palette.WATER_TANK_BLUE.lightened(0.35), 8)


## Pot tanaman persegi berbunga di teras toko.
static func _planter(mb: MeshBuilder, p: Vector3) -> void:
	mb.box(_at(p + Vector3(0.0, 0.2, 0.0)), Vector3(0.7, 0.4, 0.38), Palette.DARK_CHOCOLATE.lightened(0.2))
	mb.ellipsoid(_at(p + Vector3(0.0, 0.45, 0.0)), Vector3(0.32, 0.13, 0.15), Palette.LEAF_DEEP, 8, 4)
	for i in 3:
		var fx: float = -0.18 + 0.18 * float(i)
		mb.ellipsoid(_at(p + Vector3(fx, 0.54, 0.0)), Vector3(0.06, 0.05, 0.06), Palette.ROSY_CHEEK if i != 1 else Palette.BUTTER_YELLOW, 6, 3)


## Papan menu kapur berdiri (berbentuk A) di teras toko.
static func _menu_board(mb: MeshBuilder, p: Vector3) -> void:
	for sz: float in [-1.0, 1.0]:
		var tilt := Basis(Vector3(1.0, 0.0, 0.0), sz * 0.22)
		mb.box(Transform3D(tilt, p + Vector3(0.0, 0.42, sz * 0.1)), Vector3(0.5, 0.84, 0.03), Palette.DOOR_WOOD)
		mb.box(Transform3D(tilt, p + Vector3(0.0, 0.45, sz * 0.118)), Vector3(0.42, 0.62, 0.01), Palette.CHALKBOARD)
	for i in 3:
		mb.box(Transform3D(Basis(Vector3(1.0, 0.0, 0.0), -0.22), p + Vector3(0.0, 0.62 - 0.14 * float(i), -0.127 + 0.03 * float(i))), Vector3(0.3 - 0.06 * float(i), 0.03, 0.006), Palette.CHALK_WHITE)


## Gedung kuliah tiga lantai beratap genteng di kejauhan: pita jendela tiap lantai.
static func _campus(mb: MeshBuilder, xf: Transform3D, w: float, dpt: float, floors: int) -> void:
	var fh: float = 3.0
	var top: float = fh * float(floors)
	var wall: Color = Palette.HOUSE_CREAM
	var nrm: Vector3 = xf.basis * Vector3(0.0, 0.0, -1.0)
	mb.box(xf * _at(Vector3(0.0, (top + Y_GROUND) * 0.5, dpt * 0.5)), Vector3(w, top - Y_GROUND, dpt), wall)
	for f in floors:
		_panel(mb, xf, Vector2(0.0, fh * float(f) + 1.6), Vector2(w - 0.8, 1.2), -0.01, nrm, Palette.WINDOW_GLASS)
	_roof_x(mb, xf, w, dpt, top, 2.0, 0.6, 0.6, 0.0, wall, Palette.ROOF_TILE, Palette.ROOF_TILE_DEEP)


## Ketapang kencana di pot beton bundar: batang lurus dengan tajuk datar
## bersusun, pohon khas pelataran ruko.
static func _umbrella_tree(mb: MeshBuilder, p: Vector3) -> void:
	mb.cylinder(_at(p + Vector3(0.0, (0.34 + Y_GROUND) * 0.5, 0.0)), 0.34 - Y_GROUND, 0.36, 0.33, Palette.CONCRETE, 10)
	mb.disc(_at(p + Vector3(0.0, 0.345, 0.0)), 0.31, Palette.TRUNK.darkened(0.25), Palette.TRUNK.darkened(0.1), 10)
	mb.cylinder(_at(p + Vector3(0.0, 1.6, 0.0)), 2.6, 0.05, 0.08, Palette.TRUNK, 6)
	var tiers: Array = [[1.45, 1.0], [2.0, 0.85], [2.5, 0.66], [2.9, 0.42]]
	for i in tiers.size():
		var tr: Array = tiers[i]
		mb.ellipsoid(_at(p + Vector3(0.0, float(tr[0]), 0.0)), Vector3(float(tr[1]), 0.13, float(tr[1])), Palette.LEAF if i % 2 == 0 else Palette.LEAF_DEEP, 10, 4)


## Gerobak dagangan kaki lima: badan kotak di atas dua roda, etalase kaca, atap
## kecil bertiang, dan pegangan dorong.
static func _cart(mb: MeshBuilder, p: Vector3, yaw: float, body: Color) -> void:
	var xf: Transform3D = _at_yaw(p, yaw)
	mb.box(xf * _at(Vector3(0.0, 0.62, 0.0)), Vector3(1.3, 0.5, 0.62), body)
	mb.box(xf * _at(Vector3(0.0, 0.9, 0.0)), Vector3(1.34, 0.06, 0.66), Palette.FLOUR_WHITE)
	mb.box(xf * _at(Vector3(-0.15, 1.1, 0.0)), Vector3(0.8, 0.34, 0.5), Palette.WINDOW_GLASS)
	for sx: float in [-0.6, 0.6]:
		for sz: float in [-0.28, 0.28]:
			mb.box(xf * _at(Vector3(sx, 1.33, sz)), Vector3(0.035, 0.8, 0.035), Palette.FLOUR_WHITE.darkened(0.1))
	mb.box(xf * _at(Vector3(0.0, 1.75, 0.0)), Vector3(1.5, 0.05, 0.82), Palette.SIGN_YELLOW)
	for wz: float in [-0.35, 0.35]:
		mb.torus(xf * Transform3D(Basis(Vector3(1.0, 0.0, 0.0), PI * 0.5), Vector3(-0.3, 0.26, wz)), 0.2, 0.05, Palette.TIRE, 10, 4)
	mb.box(xf * _at(Vector3(0.55, 0.2, 0.0)), Vector3(0.06, 0.4, 0.06), Palette.TIRE)
	for hz: float in [-0.24, 0.24]:
		_stick(mb, xf * Vector3(0.65, 0.78, hz), xf * Vector3(1.0, 0.85, hz), 0.04, Palette.DOOR_WOOD)


static func _shrub(mb: MeshBuilder, p: Vector3, r: float) -> void:
	mb.ellipsoid(_at(p + Vector3(0.0, r * 0.55, 0.0)), Vector3(r, r * 0.7, r), Palette.LEAF_DEEP, 8, 5)
	mb.ellipsoid(_at(p + Vector3(r * 0.4, r * 0.75, -r * 0.2)), Vector3(r * 0.6, r * 0.5, r * 0.6), Palette.LEAF, 7, 4)


## Pot bunga tanah liat dengan tanaman (`leaf` = warna daun atau bunganya).
static func _pot(mb: MeshBuilder, p: Vector3, clay: Color, leaf: Color) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.16, 0.0)), 0.32, 0.17, 0.12, clay, 8)
	mb.ellipsoid(_at(p + Vector3(0.0, 0.42, 0.0)), Vector3(0.22, 0.2, 0.22), Palette.LEAF_DEEP, 7, 4)
	if leaf != Palette.LEAF_DEEP:
		mb.ellipsoid(_at(p + Vector3(0.05, 0.52, -0.04)), Vector3(0.11, 0.09, 0.11), leaf, 6, 3)


## Tong sampah plastik bertutup.
static func _bin(mb: MeshBuilder, p: Vector3, color: Color) -> void:
	mb.cylinder(_at(p + Vector3(0.0, 0.3, 0.0)), 0.6, 0.22, 0.19, color, 9)
	mb.cylinder(_at(p + Vector3(0.0, 0.63, 0.0)), 0.06, 0.24, 0.24, color.darkened(0.2), 9)


## Bangku taman kayu.
static func _bench(mb: MeshBuilder, p: Vector3, yaw: float) -> void:
	var xf: Transform3D = _at_yaw(p, yaw)
	mb.box(xf * _at(Vector3(0.0, 0.42, 0.0)), Vector3(1.4, 0.06, 0.4), Palette.DOOR_WOOD)
	mb.box(xf * _at(Vector3(0.0, 0.68, 0.18)), Vector3(1.4, 0.24, 0.05), Palette.DOOR_WOOD)
	for sx: float in [-0.6, 0.6]:
		mb.box(xf * _at(Vector3(sx, 0.2, 0.0)), Vector3(0.06, 0.44, 0.36), Palette.IRON_FENCE)


## Toren air di atas menara besi kecil bercat abu-abu muda.
static func _water_tower(mb: MeshBuilder, p: Vector3, color: Color, height: float) -> void:
	var steel: Color = Palette.CONCRETE_DARK
	for k in 4:
		var lx: float = -0.38 if k < 2 else 0.38
		var lz: float = -0.38 if k % 2 == 0 else 0.38
		mb.box(_at(p + Vector3(lx, height * 0.5, lz)), Vector3(0.06, height, 0.06), steel)
	mb.box(_at(p + Vector3(0.0, height * 0.55, 0.0)), Vector3(0.82, 0.04, 0.04), steel)
	mb.box(_at(p + Vector3(0.0, height + 0.03, 0.0)), Vector3(1.0, 0.06, 1.0), steel.darkened(0.12))
	mb.cylinder(_at(p + Vector3(0.0, height + 0.5, 0.0)), 0.9, 0.44, 0.44, color, 12)
	mb.cylinder(_at(p + Vector3(0.0, height + 1.0, 0.0)), 0.1, 0.24, 0.42, color.lightened(0.12), 12)


## Motor bebek yang diparkir menghadap jalan.
static func _motorbike(mb: MeshBuilder, p: Vector3, yaw: float, body: Color) -> void:
	var xf: Transform3D = _at_yaw(p, yaw)
	for wz: float in [-0.5, 0.5]:
		mb.torus(xf * Transform3D(Basis(Vector3(0.0, 0.0, 1.0), PI * 0.5), Vector3(0.0, 0.25, wz)), 0.19, 0.07, Palette.TIRE, 10, 5)
	mb.box(xf * _at(Vector3(0.0, 0.46, 0.12)), Vector3(0.26, 0.28, 0.62), body)
	mb.box(xf * _at(Vector3(0.0, 0.58, -0.38)), Vector3(0.3, 0.46, 0.09), body)
	mb.box(xf * _at(Vector3(0.0, 0.3, -0.12)), Vector3(0.24, 0.05, 0.42), Palette.TIRE)
	mb.box(xf * _at(Vector3(0.0, 0.65, 0.22)), Vector3(0.25, 0.09, 0.56), Palette.TIRE)
	_stick(mb, xf * Vector3(0.0, 0.25, -0.5), xf * Vector3(0.0, 0.92, -0.42), 0.05, Palette.CONCRETE_DARK)
	mb.box(xf * _at(Vector3(0.0, 0.94, -0.42)), Vector3(0.58, 0.04, 0.04), Palette.TIRE)
	mb.box(xf * _at(Vector3(0.0, 0.86, -0.48)), Vector3(0.14, 0.1, 0.06), Palette.BUTTER_YELLOW)


## Jemuran: dua tiang, seutas tali sepanjang Z, dan pakaian warna-warni.
static func _clothesline(mb: MeshBuilder, x: float, z0: float, z1: float) -> void:
	for z: float in [z0, z1]:
		mb.box(_at(Vector3(x, (1.55 + Y_GROUND) * 0.5, z)), Vector3(0.05, 1.55 - Y_GROUND, 0.05), Palette.CONCRETE_DARK)
	_stick(mb, Vector3(x, 1.5, z0), Vector3(x, 1.46, z1), 0.015, Palette.CABLE)
	var clothes: Array[Color] = [Palette.ROSY_CHEEK, Palette.PASTEL_MINT, Palette.PASTEL_PERIWINKLE, Palette.BUTTER_YELLOW]
	for i in clothes.size():
		var z2: float = lerpf(z0, z1, (float(i) + 0.8) / (float(clothes.size()) + 0.6))
		mb.box(_at(Vector3(x, 1.24, z2)), Vector3(0.03, 0.46, 0.4), clothes[i])


## Tiang listrik beton dengan palang, isolator, dan lampu jalan yang menjorok ke
## jalan. Mengembalikan titik pangkal kabel di puncaknya.
static func _pole(mb: MeshBuilder, p: Vector3, h: float) -> Vector3:
	mb.cylinder(_at(p + Vector3(0.0, (h + Y_GROUND) * 0.5, 0.0)), h - Y_GROUND, 0.08, 0.12, Palette.CONCRETE_DARK, 6)
	mb.box(_at(p + Vector3(0.0, h - 0.25, 0.0)), Vector3(0.08, 0.08, 0.85), Palette.CABLE.lightened(0.2))
	for dz: float in [-0.3, 0.3]:
		mb.cylinder(_at(p + Vector3(0.0, h - 0.15, dz)), 0.12, 0.035, 0.05, Palette.FLOUR_WHITE, 6)
	var arm_end: Vector3 = p + Vector3(0.0, h - 0.85, 0.75)
	_stick(mb, p + Vector3(0.0, h - 1.0, 0.0), arm_end, 0.05, Palette.CONCRETE_DARK)
	mb.box(_at(arm_end + Vector3(0.0, -0.04, 0.08)), Vector3(0.18, 0.07, 0.34), Palette.FLOUR_WHITE.darkened(0.05))
	_lamp_heads.append(arm_end + Vector3(0.0, -0.1, 0.08))
	return p + Vector3(0.0, h - 0.1, 0.0)


## Kabel melengkung di antara dua titik, `sag` = lendut di tengah.
static func _cable(mb: MeshBuilder, a: Vector3, b: Vector3, sag: float, color: Color = Palette.CABLE, thick: float = 0.02) -> void:
	var segs: int = 6
	var prev: Vector3 = a
	for i in range(1, segs + 1):
		var t: float = float(i) / float(segs)
		var q: Vector3 = a.lerp(b, t) + Vector3(0.0, -sag * 4.0 * t * (1.0 - t), 0.0)
		_stick(mb, prev, q, thick, color)
		prev = q


## Polisi tidur berbelang kuning-hitam melintang jalan dari a ke b (x, z).
static func _bump(mb: MeshBuilder, a: Vector2, b: Vector2) -> void:
	var n: int = 8
	for k in n:
		var p0: Vector2 = a.lerp(b, float(k) / float(n))
		var p1: Vector2 = a.lerp(b, float(k + 1) / float(n))
		var c: Vector2 = (p0 + p1) * 0.5
		var size := Vector3(maxf(absf(p1.x - p0.x), 0.42), 0.06, maxf(absf(p1.y - p0.y), 0.42))
		mb.box(_at(Vector3(c.x, Y_ROAD + 0.03, c.y)), size, Palette.RAINCOAT_YELLOW if k % 2 == 0 else Palette.TIRE)


# ===========================================================================
# BANTUAN
# ===========================================================================

static func _at(p: Vector3) -> Transform3D:
	return Transform3D(Basis.IDENTITY, p)


static func _at_yaw(p: Vector3, yaw: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, yaw), p)


## Batang kotak tipis dari a ke b (kabel, tiang miring, lisplang).
static func _stick(mb: MeshBuilder, a: Vector3, b: Vector3, t: float, color: Color) -> void:
	var dir: Vector3 = b - a
	var length: float = dir.length()
	if length < 0.001:
		return
	mb.box(Transform3D(MeshBuilder.frame_y(dir / length), (a + b) * 0.5), Vector3(t, length, t), color)
