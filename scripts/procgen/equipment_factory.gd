class_name EquipmentFactory
extends RefCounted

## Pabrik peralatan dapur & interior toko Roti Lezat Tycoon -- 100% mesh primitif.
##
## Seluruh bentuk dirakit dari ProceduralMeshFactory (BoxMesh / CylinderMesh /
## SphereMesh / TorusMesh / SurfaceTool). TIDAK ADA aset eksternal sama sekali
## (GDD 4 & 12.2). Material hanya StandardMaterial3D warna solid + roughness,
## aman untuk renderer Compatibility (OpenGL ES 3.0 / WebGL2) di Android kelas
## bawah dan browser.
##
## SKALA DUNIA: karakter chibi CharacterFactory tingginya +/- 1,0 m (kepala bola
## r 0,22 + badan kapsul 0,30 + kaki). Semua perabot di sini memakai skala yang
## sama: meja kerja setinggi 0,38 m, meja kasir 0,57 m, oven Tier 4 setinggi
## 0,96 m. Node hasil pabrik ini TIDAK pernah diberi skala pada root-nya supaya
## roti dari BreadFactory yang di-parent ke "Slot0".."Slot5" tetap berukuran asli.
##
## ORIENTASI: semua alat menghadap +Z (sisi pelanggan / sisi kamera). Sisi -Z
## adalah punggung alat yang biasanya menempel dinding dapur.
##
## MUTASI PARAMETRIK PER TIER (GDD 4.2 + nama alat GDD 5.1):
##   Tier 1 kayu pinus & timah tua manual  ->  Tier 3 baja + enamel karamel
##   ->  Tier 5 krom otomatis dengan aksen pastel menyala. Warna, jumlah bagian,
##   dan proporsi dihitung per tier, bukan model terpisah hasil impor.
##
## KONTRAK ANIMASI (dipakai ProceduralAnimationSystem):
##   - setiap mixer punya anak Node3D "Whisk"  -> mixer_spin() memutar sumbu Y
##     dan mengorbitkannya sejauh MIXER_ORBIT_RADIUS (0,035 m), jadi mangkuk
##     selalu dibuat cukup lebar untuk menampung orbit itu.
##   - setiap oven punya anak Node3D "Door" berporos di TEPI BAWAH pintu,
##     "Window" (kaca gelap), dan "GlowLight" (OmniLight3D bara hangat).
##     oven_door() memutar "rotation:x" ke arah NEGATIF, sehingga poros pintu
##     sengaja diberi yaw 180 derajat: dengan begitu putaran negatif membuat
##     pintu berayun keluar-bawah ke arah +Z (lihat _oven_door()).
##   - setiap display punya anak "Slot0".."Slot5" (GameConfig.SLOTS_PER_RACK)
##     berjajar kiri ke kanan di sisi depan rak, tempat roti di-parent.
##
## Anggaran geometri GDD 12.2: 500 - 2.000 triangle per objek rakitan.
## Gunakan ProceduralMeshFactory.tri_count(node) untuk mengukur ulang.

# ---------------------------------------------------------------------------
# Warna non-palet: logam, kaca, dan bambu.
# Palette hanya memuat warna kuliner hangat; GDD 4.2 secara eksplisit meminta
# "logam tembaga/krom klasik" untuk peralatan, jadi nuansa itu didefinisikan di
# sini (bukan diambil dari Palette) dan tetap ditulis lengkap dengan kode heks.
# ---------------------------------------------------------------------------

## Krom klasik mengilap pada mangkuk mixer dan rangka etalase modern.
const METAL_CHROME: Color = Color(0.807843, 0.831373, 0.850980)  # #CED4D9
## Baja abu gelap untuk badan alat industri.
const METAL_STEEL: Color = Color(0.556863, 0.588235, 0.619608)  # #8E969E
## Tembaga hangat untuk lis dekoratif toko tier menengah.
const METAL_COPPER: Color = Color(0.721569, 0.450980, 0.200000)  # #B87333
## Timah tua kusam khas oven tangkring warisan.
const TIN_AGED: Color = Color(0.603922, 0.639216, 0.627451)  # #9AA3A0
## Kaca gelap jendela oven (memantulkan bara dengan lembut).
const DARK_GLASS: Color = Color(0.164706, 0.129412, 0.109804)  # #2A211C
## Kaca bening etalase (dipakai dengan alpha rendah).
const GLASS_PANE: Color = Color(0.909804, 0.956863, 0.949020)  # #E8F4F2
## Anyaman bambu keranjang display Tier 1.
const BAMBOO: Color = Color(0.850980, 0.705882, 0.513725)  # #D9B483
## Karet gelap: ban berjalan oven Tier 5 & alas tablet.
const RUBBER_DARK: Color = Color(0.168627, 0.168627, 0.168627)  # #2B2B2B

## Tingkat transparansi kaca etalase (cukup buram supaya roti tetap terbaca).
const GLASS_ALPHA: float = 0.24

# ---------------------------------------------------------------------------
# Dimensi ruang per tier lokasi (GDD 6). Indeks 0 = Tier 1.
# ---------------------------------------------------------------------------

## Lebar ruangan (sumbu X) per tier lokasi, meter.
## Tier 1 = garasi rumah 3 x 6 m: sempit tapi memanjang ke dalam, persis satu
## kavling mobil. Tier 2 ke atas melebar dan memendek — luasnya tetap naik.
##
## SETIAP sisi wajib kelipatan FLOOR_TILE. Ubin lantai adalah satuan patokan
## seluruh permainan: ia juga menjadi petak Mode Dekorasi dan kisi tempat
## perabot berdiri. Sisi yang bukan kelipatan ubin membuat _checker_plane()
## meregangkan ubinnya (49,1 cm, 48,6 cm ...) dan seluruh kisi ikut meleset.
const ROOM_WIDTHS: Array[float] = [3.0, 5.5, 7.0, 8.5, 10.5]
## Kedalaman ruangan (sumbu Z) per tier lokasi, meter. Kelipatan FLOOR_TILE.
const ROOM_DEPTHS: Array[float] = [6.0, 4.5, 5.5, 6.5, 8.0]
## Kedalaman zona DAPUR dalam UBIN, dihitung dari dinding belakang.
##
## Ditulis dalam ubin, bukan persen, supaya garis pembatas selalu jatuh tepat di
## tepi ubin — meja kasir yang membelah ruangan di tengah-tengah ubin terlihat
## salah pasang pada tampilan isometrik. Garasi dibelah persis dua (6 + 6).
const KITCHEN_TILES: Array[int] = [6, 4, 5, 6, 7]
## Tinggi dinding per tier lokasi, meter.
const WALL_HEIGHTS: Array[float] = [1.80, 1.90, 2.05, 2.20, 2.50]
## Ukuran sisi ubin terakota (pola papan catur dua warna), meter.
##
## Ini TARGET, bukan jaminan: _checker_plane() membulatkan jumlah ubin ke
## bilangan bulat terdekat lalu meregangkannya supaya pas selebar ruangan —
## lebih baik sedikit meleset daripada ada ubin terpotong di tepi dinding.
## Ubin jadi tepat 50 x 50 cm hanya bila sisi ruangannya kelipatan 0,5 m;
## Garasi Tier 1 yang 3 x 6 m memenuhi syarat itu (6 x 12 ubin bulat).
const FLOOR_TILE: float = 0.50
## Ketebalan dinding pinus.
const WALL_THICK: float = 0.10

## Rentang X tempat "Slot0".."Slot5" dijajarkan pada rak display, meter.
const SLOT_SPAN: float = 0.78

# ---------------------------------------------------------------------------
# Meja kasir pembatas (build_divider_counter): pemisah area toko dan dapur.
# ---------------------------------------------------------------------------

## Tebal meja pembatas pada sumbu Z — TEPAT satu ubin.
## Meja ini menempati satu baris ubin penuh (lihat counter_row()), bukan
## menunggangi garis di antara dua baris seperti dulu.
const DIVIDER_DEPTH: float = FLOOR_TILE
## Tinggi DADA karakter chibi, meter.
##
## Diturunkan dari CharacterFactory.SHOULDER_Y, bukan ditulis sebagai angka
## lepas: begitu proporsi karakter digeser, batas ini ikut bergeser sendiri.
const CHEST_HEIGHT: float = CharacterFactory.SHOULDER_Y

## Tinggi PERMUKAAN setiap meja tempat orang berdiri melayani, meter.
##
## Harus berada DI BAWAH CHEST_HEIGHT. Meja setinggi dada masih terbaca sebagai
## meja; meja yang melewatinya menenggelamkan orang yang berdiri di baliknya --
## dan meja pembatas pernah berdiri setinggi 0,95 m dengan mesin kasir menjulang
## sampai 1,22 m, sementara pelanggan chibi hanya setinggi 0,92 m.
const COUNTER_HEIGHT: float = 0.42

## Tinggi permukaan meja pembatas. Sama dengan meja layan lainnya: pembeli
## berdiri di satu sisi dan kasir di sisi lain, jadi tidak ada alasan ia
## berbeda tinggi.
const DIVIDER_HEIGHT: float = COUNTER_HEIGHT
## Tonjolan papan atas meja pembatas di setiap sisi.
const DIVIDER_TOP_OVERHANG: float = 0.04
## Panjang minimum meja pembatas, dalam UBIN.
const DIVIDER_MIN_TILES: int = 2
## Bagian lebar ruangan yang ditutup meja pembatas; sisanya jadi celah jalan staf.
## Hasilnya dibulatkan ke bilangan ubin utuh (lihat divider_metrics()).
const DIVIDER_SPAN_RATIO: float = 0.70


## Ukuran dan penempatan meja kasir pembatas untuk satu tier lokasi.
##
## EquipmentFactory memegang angka ini SENDIRIAN. ShopWorld dan suite tes
## memanggil fungsi ini alih-alih menghitung ulang — persis seperti dimensi
## ruangan. Dua pihak yang menghitung angka yang sama adalah akar dari seluruh
## bug "perabot menembus dinding" di proyek ini.
static func divider_metrics(tier: int) -> Dictionary:
	var w: float = room_width(tier)
	var wall: float = room_wall_thickness()
	# Bentang meja diukur dalam UBIN, bukan meter bebas: meja yang berakhir di
	# tengah-tengah ubin membuat seluruh kisi lantai terbaca miring.
	var span_tiles: int = clampi(
		int(round(w * DIVIDER_SPAN_RATIO / FLOOR_TILE)),
		DIVIDER_MIN_TILES, maxi(DIVIDER_MIN_TILES, floor_cols(tier) - 1))
	var span: float = float(span_tiles) * FLOOR_TILE
	# Meja dimulai dari TEPI UBIN kolom 0, bukan dari permukaan dalam dinding.
	# Ujung kirinya karena itu terbenam 5 cm di dalam dinding samping — tidak
	# terlihat, dan itulah harga supaya seluruh mejanya sejajar kisi lantai.
	return {
		"span": span,
		"gap": w - wall * 2.0 - span,
		"cx": -w * 0.5 + span * 0.5,
		"z": counter_z(tier),
		"depth": DIVIDER_DEPTH,
		"top_y": DIVIDER_HEIGHT,
	}


## Posisi X satu mesin kasir di atas meja sepanjang `span`, dalam koordinat
## lokal meja. Dipakai BERSAMA oleh mesh meja dan penempatan kasir di ShopWorld,
## supaya kasir selalu berdiri tepat di belakang mesinnya.
static func divider_register_x(index: int, count: int, span: float) -> float:
	return _slot_x(index, count, maxf(span - 0.46, 0.02))
## Batas jumlah mesin kasir di atas meja pembatas (anggaran tris GDD 12.2).
const MAX_REGISTERS: int = 4


# ---------------------------------------------------------------------------
# MIXER (GDD 5.1)
# ---------------------------------------------------------------------------

## Mixer Tier 1..5. Selalu memiliki anak Node3D "Whisk" yang bisa diputar
## ProceduralAnimationSystem.mixer_spin().
static func build_mixer(tier: int) -> Node3D:
	var t: int = clampi(tier, 1, 5)
	var root: Node3D = _root("Mixer", t)
	match t:
		1:
			_mixer_manual(root)
		2:
			_mixer_electric(root)
		3:
			_mixer_heavy(root)
		4:
			_mixer_industrial(root)
		_:
			_mixer_robot(root)
	return root


## Tier 1 -- "Mangkuk Kayu & Pengocok Manual": meja pinus, mangkuk kayu bubut,
## dan pengocok balon kawat yang diputar tangan.
static func _mixer_manual(root: Node3D) -> void:
	var pine: Color = Palette.PINE_WOOD
	var pine_dark: Color = Palette.PINE_WOOD.darkened(0.28)
	_work_table(root, Vector3(0.50, 0.38, 0.40), pine, pine_dark)

	# Mangkuk kayu dibubut lewat lathe() supaya bibirnya membulat empuk.
	var bowl_profile := PackedVector2Array([
		Vector2(0.000, 0.000),
		Vector2(0.085, 0.006),
		Vector2(0.150, 0.055),
		Vector2(0.168, 0.120),
		Vector2(0.155, 0.135),
	])
	_lathe(root, bowl_profile, 12, Palette.CARAMEL.lightened(0.22), Vector3(0.0, 0.38, 0.0))
	_tor(root, 0.150, 0.176, Palette.CARAMEL.lightened(0.32), Vector3(0.0, 0.513, 0.0))

	# Adonan montok di dasar mangkuk (GDD 4.1 "Cute").
	var dough: MeshInstance3D = _sph(root, 0.105, Palette.RAW_DOUGH, Vector3(0.0, 0.445, 0.0))
	dough.scale = Vector3(1.0, 0.46, 1.0)

	var whisk: Node3D = _whisk_pivot(root, Vector3(0.0, 0.600, 0.0))
	_cyl(whisk, 0.16, 0.020, 0.024, pine_dark, Vector3(0.0, 0.080, 0.0))
	_balloon_loops(whisk, 3, 0.036, 0.048, METAL_CHROME, -0.090, 1.7)


## Tier 2 -- "Stand Mixer Elektrik Murah": plastik pastel, badan kecil, satu tuas
## kecepatan. Masih berdiri di atas meja pinus yang sama.
static func _mixer_electric(root: Node3D) -> void:
	var pine: Color = Palette.PINE_WOOD
	_work_table(root, Vector3(0.48, 0.38, 0.38), pine, pine.darkened(0.28))

	var shell: Color = Palette.PASTEL_MINT
	_slab(root, Vector3(0.26, 0.05, 0.20), 0.015, shell, Vector3(0.0, 0.405, 0.0))
	_box(root, Vector3(0.10, 0.22, 0.12), shell, Vector3(0.0, 0.500, -0.080))
	_slab(root, Vector3(0.13, 0.10, 0.24), 0.028, shell, Vector3(0.0, 0.660, 0.020))
	_sph(root, 0.062, shell.darkened(0.06), Vector3(0.0, 0.660, -0.080))

	_cyl(root, 0.13, 0.110, 0.080, METAL_CHROME, Vector3(0.0, 0.495, 0.030), Vector3.ZERO, 0.35)
	# Tuas kecepatan merah muda: aksen "cute" satu-satunya di alat murah ini.
	_box(root, Vector3(0.030, 0.055, 0.040), Palette.PASTEL_STRAWBERRY, Vector3(0.082, 0.665, 0.090))

	var whisk: Node3D = _whisk_pivot(root, Vector3(0.0, 0.570, 0.030))
	_cyl(whisk, 0.08, 0.014, 0.014, METAL_CHROME, Vector3(0.0, 0.040, 0.0))
	_balloon_loops(whisk, 2, 0.028, 0.038, METAL_CHROME, -0.050, 1.6)


## Tier 3 -- "Heavy Duty Stand Mixer": kabinet baja sendiri, badan enamel
## karamel, mangkuk krom besar, dan tombol putar kuning custard.
static func _mixer_heavy(root: Node3D) -> void:
	var enamel: Color = Palette.CARAMEL
	_slab(root, Vector3(0.46, 0.42, 0.40), 0.03, METAL_STEEL, Vector3(0.0, 0.210, 0.0))
	_box(root, Vector3(0.42, 0.04, 0.36), METAL_STEEL.darkened(0.25), Vector3(0.0, 0.020, 0.0))
	_box(root, Vector3(0.50, 0.035, 0.44), METAL_CHROME, Vector3(0.0, 0.4375, 0.0), Vector3.ZERO, 0.30)

	_slab(root, Vector3(0.30, 0.06, 0.24), 0.018, enamel, Vector3(0.0, 0.485, 0.0))
	_box(root, Vector3(0.13, 0.26, 0.15), enamel, Vector3(0.0, 0.640, -0.090))
	_slab(root, Vector3(0.16, 0.12, 0.28), 0.032, enamel, Vector3(0.0, 0.790, 0.020))
	_sph(root, 0.072, enamel.darkened(0.12), Vector3(0.0, 0.790, -0.100))

	_cyl(root, 0.17, 0.140, 0.100, METAL_CHROME, Vector3(0.0, 0.600, 0.030), Vector3.ZERO, 0.30)
	_tor(root, 0.135, 0.156, METAL_CHROME, Vector3(0.0, 0.685, 0.030))

	# Tombol putar kecepatan menghadap +X di sisi kepala mixer.
	_cyl(root, 0.022, 0.034, 0.034, Palette.CUSTARD, Vector3(0.088, 0.790, 0.040), Vector3(0.0, 0.0, 90.0))

	var whisk: Node3D = _whisk_pivot(root, Vector3(0.0, 0.705, 0.030))
	_cyl(whisk, 0.08, 0.016, 0.016, METAL_CHROME, Vector3(0.0, 0.040, 0.0))
	_balloon_loops(whisk, 3, 0.032, 0.044, METAL_CHROME, -0.060, 1.7)


## Tier 4 -- "Industrial Dough Kneader": mesin spiral lantai, bak besar, lengan
## menjorok, dan panel kontrol digital mungil.
static func _mixer_industrial(root: Node3D) -> void:
	_slab(root, Vector3(0.56, 0.40, 0.46), 0.035, METAL_STEEL, Vector3(0.0, 0.200, 0.0))
	_box(root, Vector3(0.52, 0.05, 0.42), METAL_STEEL.darkened(0.3), Vector3(0.0, 0.025, 0.0))

	# Panel kontrol miring di muka mesin + layar kecil menyala pastel.
	_slab(root, Vector3(0.22, 0.13, 0.03), 0.01, Palette.FLOUR_WHITE, Vector3(0.0, 0.330, 0.235), Vector3(-18.0, 0.0, 0.0))
	var screen: MeshInstance3D = _box(root, Vector3(0.150, 0.045, 0.012), Palette.PASTEL_PERIWINKLE, Vector3(0.0, 0.338, 0.252), Vector3(-18.0, 0.0, 0.0))
	_set_glow(screen, Palette.PASTEL_PERIWINKLE, 0.55)

	_cyl(root, 0.20, 0.240, 0.220, METAL_CHROME, Vector3(0.0, 0.500, 0.0), Vector3.ZERO, 0.30)
	_tor(root, 0.235, 0.262, METAL_CHROME, Vector3(0.0, 0.600, 0.0))
	var dough: MeshInstance3D = _sph(root, 0.150, Palette.RAW_DOUGH, Vector3(0.0, 0.470, 0.0))
	dough.scale = Vector3(1.0, 0.42, 1.0)

	_box(root, Vector3(0.16, 0.30, 0.16), METAL_STEEL, Vector3(0.0, 0.630, -0.260))
	_box(root, Vector3(0.16, 0.10, 0.34), METAL_STEEL, Vector3(0.0, 0.730, -0.110))
	# Batang pemecah adonan yang diam di dalam bak (ciri mixer spiral).
	_box(root, Vector3(0.035, 0.18, 0.035), METAL_CHROME, Vector3(0.150, 0.510, 0.0))

	# Hook spiral: tiga cincin bertumpuk dengan radius membesar ke bawah.
	var whisk: Node3D = _whisk_pivot(root, Vector3(0.0, 0.660, 0.0))
	_cyl(whisk, 0.09, 0.030, 0.030, METAL_CHROME, Vector3(0.0, -0.045, 0.0))
	for i in 3:
		var r: float = 0.070 + float(i) * 0.030
		_tor(whisk, r - 0.012, r + 0.012, METAL_CHROME, Vector3(0.0, -0.100 - float(i) * 0.045, 0.0))


## Tier 5 -- "Automated Mixing Robot": lengan robot dua ruas di atas cakram
## pemutar, dengan cincin status pastel yang menyala lembut.
static func _mixer_robot(root: Node3D) -> void:
	var shell: Color = Palette.FLOUR_WHITE
	_cyl(root, 0.07, 0.250, 0.260, METAL_CHROME, Vector3(0.0, 0.035, 0.0), Vector3.ZERO, 0.30)
	_cyl(root, 0.05, 0.190, 0.190, shell, Vector3(0.0, 0.095, 0.0))
	var ring: MeshInstance3D = _tor(root, 0.190, 0.214, Palette.PASTEL_MINT, Vector3(0.0, 0.120, 0.0))
	_set_glow(ring, Palette.PASTEL_MINT, 0.70)

	_cyl(root, 0.34, 0.075, 0.085, shell, Vector3(0.0, 0.290, 0.0))
	_sph(root, 0.085, shell.darkened(0.05), Vector3(0.0, 0.470, 0.0))
	_box(root, Vector3(0.08, 0.28, 0.08), shell, Vector3(0.0, 0.597, 0.059), Vector3(25.0, 0.0, 0.0))
	_sph(root, 0.062, shell.darkened(0.05), Vector3(0.0, 0.724, 0.118))
	_box(root, Vector3(0.07, 0.26, 0.07), shell, Vector3(0.0, 0.632, 0.210), Vector3(135.0, 0.0, 0.0))
	_sph(root, 0.052, METAL_CHROME, Vector3(0.0, 0.540, 0.302))
	# Mata sensor pastel: satu-satunya "wajah" robot supaya tetap ramah.
	var eye: MeshInstance3D = _box(root, Vector3(0.060, 0.020, 0.012), Palette.PASTEL_PERIWINKLE, Vector3(0.0, 0.520, 0.070))
	_set_glow(eye, Palette.PASTEL_PERIWINKLE, 0.6)

	# Mangkuk berdiri sendiri di depan lengan.
	_cyl(root, 0.30, 0.080, 0.090, METAL_CHROME, Vector3(0.0, 0.150, 0.302), Vector3.ZERO, 0.30)
	_cyl(root, 0.14, 0.160, 0.120, METAL_CHROME, Vector3(0.0, 0.370, 0.302), Vector3.ZERO, 0.30)

	var whisk: Node3D = _whisk_pivot(root, Vector3(0.0, 0.470, 0.302))
	_cyl(whisk, 0.08, 0.018, 0.018, METAL_CHROME, Vector3(0.0, 0.040, 0.0))
	_balloon_loops(whisk, 3, 0.030, 0.040, METAL_CHROME, -0.100, 1.6)


# ---------------------------------------------------------------------------
# OVEN (GDD 5.1)
# ---------------------------------------------------------------------------

## Oven Tier 1..5. Selalu memiliki anak "Door" (poros di tepi bawah),
## "Window" (kaca gelap), dan "GlowLight" (OmniLight3D bara hangat).
static func build_oven(tier: int) -> Node3D:
	var t: int = clampi(tier, 1, 5)
	var root: Node3D = _root("Oven", t)
	match t:
		1:
			_oven_tangkring(root)
		2:
			_oven_mini_electric(root)
		3:
			_oven_deck(root)
		4:
			_oven_convection(root)
		_:
			_oven_conveyor(root)
	return root


## Tier 1 -- "Oven Tangkring Tua": kotak timah kusam bertengger di atas kompor
## minyak tanah, lengkap dengan cerobong mungil dan paku keling tembaga.
static func _oven_tangkring(root: Node3D) -> void:
	_cyl(root, 0.16, 0.140, 0.160, TIN_AGED.darkened(0.15), Vector3(0.0, 0.080, 0.0))
	_tor(root, 0.100, 0.126, METAL_STEEL, Vector3(0.0, 0.165, 0.0))
	_cyl(root, 0.020, 0.030, 0.030, Palette.CUSTARD, Vector3(0.120, 0.090, 0.110), Vector3(0.0, 0.0, 90.0))

	_slab(root, Vector3(0.32, 0.26, 0.28), 0.022, TIN_AGED, Vector3(0.0, 0.300, 0.0))
	_box(root, Vector3(0.34, 0.030, 0.30), TIN_AGED.darkened(0.12), Vector3(0.0, 0.445, 0.0))
	_cyl(root, 0.09, 0.020, 0.024, TIN_AGED.darkened(0.2), Vector3(0.110, 0.500, -0.090))

	# Paku keling tembaga di keempat sudut muka -- detail "tua" yang murah.
	for i in 4:
		var sx: float = -1.0 if i < 2 else 1.0
		var sy: float = -1.0 if (i % 2) == 0 else 1.0
		_box(root, Vector3(0.020, 0.020, 0.012), METAL_COPPER, Vector3(sx * 0.140, 0.300 + sy * 0.110, 0.140))

	_oven_window(root, "Window", Vector2(0.140, 0.070), Vector3(0.0, 0.310, 0.138))
	_oven_door(root, "Door", 0.280, 0.220, Vector3(0.0, 0.190, 0.144), TIN_AGED.darkened(0.08), METAL_COPPER, 0.030)
	_oven_glow(root, Vector3(0.0, 0.300, 0.050), 0.50, 0.90)


## Tier 2 -- "Oven Listrik Mini": bodi krem di atas dudukan pinus, dua kenop
## bulat, dan lis krom tipis.
static func _oven_mini_electric(root: Node3D) -> void:
	_work_table(root, Vector3(0.52, 0.36, 0.40), Palette.PINE_WOOD, Palette.PINE_WOOD.darkened(0.28))
	_slab(root, Vector3(0.44, 0.24, 0.32), 0.025, Palette.FLOUR_WHITE, Vector3(0.0, 0.480, 0.0))
	_box(root, Vector3(0.45, 0.025, 0.33), METAL_CHROME, Vector3(0.0, 0.368, 0.0), Vector3.ZERO, 0.30)
	_box(root, Vector3(0.44, 0.070, 0.32), Palette.FLOUR_WHITE.darkened(0.06), Vector3(0.0, 0.635, 0.0))
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_cyl(root, 0.020, 0.022, 0.022, Palette.CARAMEL, Vector3(sx * 0.150, 0.635, 0.170), Vector3(90.0, 0.0, 0.0))
	var lamp: MeshInstance3D = _box(root, Vector3(0.030, 0.014, 0.010), Palette.DANGER, Vector3(0.0, 0.635, 0.166))
	_set_glow(lamp, Palette.DANGER, 0.8)

	_oven_window(root, "Window", Vector2(0.240, 0.100), Vector3(0.0, 0.480, 0.158))
	_oven_door(root, "Door", 0.400, 0.200, Vector3(0.0, 0.380, 0.164), Palette.FLOUR_WHITE.darkened(0.1), METAL_CHROME, 0.032)
	_oven_glow(root, Vector3(0.0, 0.480, 0.020), 0.55, 1.00)


## Tier 3 -- "Deck Oven 2 Tray": dua dek bertumpuk, panel kontrol di tengah,
## cerobong uap di atas. Dek atas memakai nama kontrak "Door"/"Window",
## dek bawah memakai "DoorLower"/"WindowLower".
static func _oven_deck(root: Node3D) -> void:
	for i in 4:
		var sx: float = -1.0 if i < 2 else 1.0
		var sz: float = -1.0 if (i % 2) == 0 else 1.0
		_cyl(root, 0.10, 0.024, 0.028, METAL_STEEL.darkened(0.3), Vector3(sx * 0.250, 0.050, sz * 0.170))

	_slab(root, Vector3(0.60, 0.68, 0.44), 0.03, METAL_STEEL, Vector3(0.0, 0.440, 0.0))
	_box(root, Vector3(0.61, 0.030, 0.45), Palette.CARAMEL, Vector3(0.0, 0.780, 0.0))
	_box(root, Vector3(0.60, 0.060, 0.45), Palette.FLOUR_WHITE, Vector3(0.0, 0.430, 0.0))
	var readout: MeshInstance3D = _box(root, Vector3(0.180, 0.030, 0.012), Palette.PASTEL_MINT, Vector3(0.0, 0.430, 0.228))
	_set_glow(readout, Palette.PASTEL_MINT, 0.6)
	for i in 2:
		var sx2: float = -1.0 if i == 0 else 1.0
		_cyl(root, 0.018, 0.022, 0.022, Palette.CARAMEL, Vector3(sx2 * 0.230, 0.430, 0.230), Vector3(90.0, 0.0, 0.0))

	_box(root, Vector3(0.34, 0.050, 0.20), METAL_STEEL.darkened(0.15), Vector3(0.0, 0.805, -0.060))
	_cyl(root, 0.10, 0.028, 0.032, METAL_STEEL.darkened(0.25), Vector3(0.0, 0.870, -0.100))

	_oven_window(root, "Window", Vector2(0.300, 0.130), Vector3(0.0, 0.590, 0.222))
	_oven_door(root, "Door", 0.540, 0.260, Vector3(0.0, 0.460, 0.228), METAL_STEEL.darkened(0.12), Palette.CARAMEL, 0.035)
	_oven_window(root, "WindowLower", Vector2(0.300, 0.130), Vector3(0.0, 0.270, 0.222))
	_oven_door(root, "DoorLower", 0.540, 0.260, Vector3(0.0, 0.140, 0.228), METAL_STEEL.darkened(0.12), Palette.CARAMEL, 0.035)
	_oven_glow(root, Vector3(0.0, 0.580, 0.050), 0.60, 1.20)


## Tier 4 -- "Convection Oven Besar": bodi tinggi krem berbingkai krom, pintu
## kaca besar, dan panel digital di atas.
static func _oven_convection(root: Node3D) -> void:
	_box(root, Vector3(0.70, 0.100, 0.50), METAL_CHROME, Vector3(0.0, 0.050, 0.0), Vector3.ZERO, 0.30)
	_slab(root, Vector3(0.70, 0.86, 0.50), 0.035, Palette.FLOUR_WHITE, Vector3(0.0, 0.530, 0.0))
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_box(root, Vector3(0.035, 0.86, 0.51), METAL_CHROME, Vector3(sx * 0.335, 0.530, 0.0), Vector3.ZERO, 0.30)
	_box(root, Vector3(0.72, 0.040, 0.52), METAL_CHROME, Vector3(0.0, 0.980, 0.0), Vector3.ZERO, 0.30)

	_box(root, Vector3(0.66, 0.110, 0.020), DARK_GLASS, Vector3(0.0, 0.880, 0.255), Vector3.ZERO, 0.30)
	var readout: MeshInstance3D = _box(root, Vector3(0.240, 0.045, 0.010), Palette.PASTEL_MINT, Vector3(-0.140, 0.880, 0.266))
	_set_glow(readout, Palette.PASTEL_MINT, 0.65)
	for i in 3:
		_box(root, Vector3(0.040, 0.040, 0.010), Palette.CUSTARD, Vector3(0.120 + float(i) * 0.075, 0.880, 0.266))

	_oven_window(root, "Window", Vector2(0.420, 0.340), Vector3(0.0, 0.500, 0.248))
	_oven_door(root, "Door", 0.620, 0.600, Vector3(0.0, 0.200, 0.256), Palette.FLOUR_WHITE.darkened(0.12), METAL_CHROME, 0.045)
	_oven_glow(root, Vector3(0.0, 0.500, 0.080), 0.70, 1.40)


## Tier 5 -- "Conveyor Belt Oven": terowongan panggang dengan ban berjalan yang
## menembus kedua ujung, menara kontrol, dan garis aksen pastel menyala.
static func _oven_conveyor(root: Node3D) -> void:
	for i in 4:
		var sx: float = -1.0 if i < 2 else 1.0
		var sz: float = -1.0 if (i % 2) == 0 else 1.0
		_cyl(root, 0.52, 0.030, 0.036, METAL_STEEL, Vector3(sx * 0.520, 0.260, sz * 0.160))

	_box(root, Vector3(1.34, 0.035, 0.34), RUBBER_DARK, Vector3(0.0, 0.545, 0.0))
	for i in 2:
		var sx2: float = -1.0 if i == 0 else 1.0
		_cyl(root, 0.36, 0.050, 0.050, METAL_CHROME, Vector3(sx2 * 0.670, 0.545, 0.0), Vector3(0.0, 0.0, 90.0), 0.30)

	_slab(root, Vector3(1.02, 0.36, 0.42), 0.04, METAL_CHROME, Vector3(0.0, 0.740, 0.0), Vector3.ZERO, 0.32)
	for i in 2:
		var sx3: float = -1.0 if i == 0 else 1.0
		_box(root, Vector3(0.025, 0.140, 0.300), DARK_GLASS, Vector3(sx3 * 0.508, 0.620, 0.0))
	var stripe: MeshInstance3D = _box(root, Vector3(1.02, 0.025, 0.43), Palette.PASTEL_MINT, Vector3(0.0, 0.905, 0.0))
	_set_glow(stripe, Palette.PASTEL_MINT, 0.5)

	_slab(root, Vector3(0.20, 0.22, 0.20), 0.02, Palette.FLOUR_WHITE, Vector3(0.400, 1.030, 0.0))
	var panel: MeshInstance3D = _box(root, Vector3(0.140, 0.070, 0.012), Palette.PASTEL_PERIWINKLE, Vector3(0.400, 1.055, 0.105))
	_set_glow(panel, Palette.PASTEL_PERIWINKLE, 0.6)

	_oven_window(root, "Window", Vector2(0.500, 0.140), Vector3(0.0, 0.740, 0.212))
	_oven_door(root, "Door", 0.560, 0.260, Vector3(0.0, 0.620, 0.220), METAL_CHROME.darkened(0.12), Palette.APRON_GOLD, 0.032)
	_oven_glow(root, Vector3(0.0, 0.720, 0.0), 0.80, 1.60)


# ---------------------------------------------------------------------------
# DISPLAY / RAK ETALASE (GDD 5.1)
# ---------------------------------------------------------------------------

## Rak display Tier 1..5. Selalu memiliki anak "Slot0".."Slot5"
## (GameConfig.SLOTS_PER_RACK) berjajar kiri ke kanan di sisi depan.
static func build_display(tier: int) -> Node3D:
	var t: int = clampi(tier, 1, 5)
	var root: Node3D = _root("Display", t)
	match t:
		1:
			_display_basket(root)
		2:
			_display_glass_case(root)
		3:
			_display_warm_showcase(root)
		4:
			_display_smart_showcase(root)
		_:
			_display_dispenser(root)
	return root


## Tier 1 -- "Keranjang Bambu Terbuka": keranjang anyam persegi beralas kain
## gingham pastel di atas meja kuda-kuda pinus.
static func _display_basket(root: Node3D) -> void:
	_work_table(root, Vector3(0.92, 0.36, 0.42), Palette.PINE_WOOD, Palette.PINE_WOOD.darkened(0.28))
	_box(root, Vector3(0.84, 0.030, 0.34), BAMBOO, Vector3(0.0, 0.375, 0.0))
	_box(root, Vector3(0.84, 0.090, 0.025), BAMBOO, Vector3(0.0, 0.435, -0.170))
	_box(root, Vector3(0.84, 0.090, 0.025), BAMBOO, Vector3(0.0, 0.435, 0.170))
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_box(root, Vector3(0.025, 0.090, 0.340), BAMBOO, Vector3(sx * 0.420, 0.435, 0.0))
	# Bilah anyaman: garis vertikal tipis supaya keranjang terbaca "dianyam".
	for i in 7:
		var x: float = -0.36 + float(i) * 0.12
		_box(root, Vector3(0.022, 0.092, 0.028), BAMBOO.darkened(0.22), Vector3(x, 0.435, 0.172))

	var cloth: MeshInstance3D = _checker_plane(0.78, 0.30, 0.09, Palette.GINGHAM_A, Palette.GINGHAM_B, true)
	ProceduralMeshFactory.attach(root, cloth, Vector3(0.0, 0.393, 0.0))

	# Papan harga kapur kecil bersandar di ujung meja.
	_box(root, Vector3(0.200, 0.120, 0.012), Palette.CHALKBOARD, Vector3(0.300, 0.300, 0.220), Vector3(-12.0, 0.0, 0.0))
	_box(root, Vector3(0.130, 0.010, 0.004), Palette.CHALK_WHITE, Vector3(0.300, 0.320, 0.228), Vector3(-12.0, 0.0, 0.0))
	_box(root, Vector3(0.090, 0.010, 0.004), Palette.CHALK_WHITE, Vector3(0.285, 0.290, 0.234), Vector3(-12.0, 0.0, 0.0))

	_add_slots(root, 0.400, 0.000, 0.72)


## Tier 2 -- "Etalase Kaca Sederhana": lemari pinus dengan kotak kaca polos.
static func _display_glass_case(root: Node3D) -> void:
	var pine: Color = Palette.PINE_WOOD
	_slab(root, Vector3(0.95, 0.42, 0.40), 0.03, pine, Vector3(0.0, 0.210, 0.0))
	_box(root, Vector3(0.88, 0.050, 0.36), pine.darkened(0.3), Vector3(0.0, 0.025, 0.0))
	_box(root, Vector3(1.00, 0.040, 0.44), pine.darkened(0.16), Vector3(0.0, 0.440, 0.0))
	_glass_case(root, 0.98, 0.42, 0.30, 0.460, pine.darkened(0.16), 0.030)
	_box(root, Vector3(0.90, 0.020, 0.36), Palette.FLOUR_WHITE, Vector3(0.0, 0.500, 0.0))
	_add_slots(root, 0.520, 0.000, SLOT_SPAN)


## Tier 3 -- "Showcase Kaca dengan Lampu Penghangat": kayu karamel, rangka krom,
## strip lampu penghangat #FFAA44 di langit-langit etalase.
static func _display_warm_showcase(root: Node3D) -> void:
	_slab(root, Vector3(1.00, 0.46, 0.42), 0.03, Palette.CARAMEL, Vector3(0.0, 0.230, 0.0))
	_box(root, Vector3(0.94, 0.050, 0.38), Palette.DARK_CHOCOLATE, Vector3(0.0, 0.025, 0.0))
	_box(root, Vector3(1.04, 0.040, 0.46), METAL_CHROME, Vector3(0.0, 0.480, 0.0), Vector3.ZERO, 0.30)
	_glass_case(root, 1.02, 0.44, 0.34, 0.500, METAL_CHROME, 0.026)
	_box(root, Vector3(0.96, 0.020, 0.38), Palette.FLOUR_WHITE, Vector3(0.0, 0.540, 0.0))

	var strip: MeshInstance3D = _box(root, Vector3(0.90, 0.025, 0.060), Palette.WARMER_LAMP, Vector3(0.0, 0.808, -0.100))
	_set_glow(strip, Palette.WARMER_LAMP, 1.1)
	_warm_lamp(root, Vector3(0.0, 0.760, 0.0), 0.45, 0.90)

	_box(root, Vector3(1.02, 0.050, 0.020), Palette.CARAMEL.darkened(0.2), Vector3(0.0, 0.455, 0.225))
	_add_slots(root, 0.560, 0.000, 0.80)


## Tier 4 -- "Smart Temperature Showcase": bodi navy, rangka krom tipis, layar
## suhu digital, dan garis LED pastel di kaki lemari.
static func _display_smart_showcase(root: Node3D) -> void:
	_slab(root, Vector3(1.05, 0.48, 0.44), 0.03, Palette.APRON_NAVY, Vector3(0.0, 0.240, 0.0))
	_box(root, Vector3(1.10, 0.040, 0.48), METAL_CHROME, Vector3(0.0, 0.500, 0.0), Vector3.ZERO, 0.28)
	_glass_case(root, 1.08, 0.46, 0.38, 0.520, METAL_CHROME, 0.022)
	_box(root, Vector3(1.00, 0.020, 0.40), Palette.FLOUR_WHITE, Vector3(0.0, 0.560, 0.0))

	var led: MeshInstance3D = _box(root, Vector3(1.05, 0.020, 0.45), Palette.PASTEL_PERIWINKLE, Vector3(0.0, 0.018, 0.0))
	_set_glow(led, Palette.PASTEL_PERIWINKLE, 0.7)
	_box(root, Vector3(0.220, 0.070, 0.015), DARK_GLASS, Vector3(0.360, 0.440, 0.225))
	var temp: MeshInstance3D = _box(root, Vector3(0.160, 0.035, 0.008), Palette.PASTEL_MINT, Vector3(0.360, 0.440, 0.234))
	_set_glow(temp, Palette.PASTEL_MINT, 0.7)

	var strip: MeshInstance3D = _box(root, Vector3(0.96, 0.022, 0.060), Palette.WARMER_LAMP, Vector3(0.0, 0.868, -0.110))
	_set_glow(strip, Palette.WARMER_LAMP, 1.0)
	_warm_lamp(root, Vector3(0.0, 0.800, 0.0), 0.40, 0.95)
	_add_slots(root, 0.580, 0.000, 0.84)


## Tier 5 -- "Premium Auto-Dispenser Showcase": lemari cokelat gelap berlis emas
## dengan enam tabung penjatuh roti tepat di atas tiap slot.
static func _display_dispenser(root: Node3D) -> void:
	var gold: Color = Palette.APRON_GOLD
	_slab(root, Vector3(1.10, 0.50, 0.46), 0.03, Palette.DARK_CHOCOLATE, Vector3(0.0, 0.250, 0.0))
	_box(root, Vector3(1.12, 0.030, 0.48), gold, Vector3(0.0, 0.505, 0.0), Vector3.ZERO, 0.40)
	_glass_case(root, 1.12, 0.48, 0.46, 0.520, gold, 0.022)
	_box(root, Vector3(1.04, 0.020, 0.40), Palette.VANILLA_CREAM, Vector3(0.0, 0.560, 0.0))

	var slots: int = maxi(1, GameConfig.SLOTS_PER_RACK)
	var span: float = 0.86
	for i in slots:
		var x: float = _slot_x(i, slots, span)
		_cyl(root, 0.18, 0.052, 0.058, Palette.FLOUR_WHITE, Vector3(x, 0.850, -0.060))
		var band: MeshInstance3D = _cyl(root, 0.018, 0.060, 0.060, Palette.PASTEL_MINT, Vector3(x, 0.755, -0.060))
		_set_glow(band, Palette.PASTEL_MINT, 0.8)

	_warm_lamp(root, Vector3(0.0, 0.820, 0.050), 0.50, 1.05)
	_add_slots(root, 0.580, 0.000, span)


# ---------------------------------------------------------------------------
# GUDANG PENYIMPANAN (kulkas + lemari bahan, SATU perabot)
# ---------------------------------------------------------------------------

## Tebal setiap unit gudang pada sumbu Z.
##
## Gudang berdiri dalam SATU baris ubin, jadi angka ini harus menyisakan ruang
## untuk daun pintu dan gagangnya yang menonjol ke depan — kalau tidak,
## fit_to_footprint() akan mengecilkan seluruh perabot hanya karena gagangnya.
const STORAGE_DEPTH: float = 0.36
## Bidang tempat SELURUH daun pintu gudang bergantung (sisi depan, +Z).
const STORAGE_DOOR_Z: float = 0.186
## Jarak antar-unit gudang pada sumbu X: lebar unit + celah sambungan.
const STORAGE_UNIT_PITCH: float = 0.48
## Lebar satu unit gudang.
const STORAGE_UNIT_WIDTH: float = 0.46


## Gudang Penyimpanan: kulkas dan lemari bahan yang menyatu menjadi satu perabot.
##
## Parameternya TIER LOKASI, bukan tier alat, dan itu disengaja: gudang tidak
## pernah muncul di Pasar seperti mixer/oven/rak. Ia sepaket dengan bangunan,
## jadi bentuk dan kapasitasnya (LocationDB.pantry_cap) ikut naik sendiri begitu
## toko di-upgrade (GDD 5.2.2). Yang tetap milik pemain hanyalah TEMPATNYA --
## gudang boleh digeser di Mode Dekorasi seperti perabot lepas lainnya.
##
## Seluruh unitnya BERJAJAR DALAM SATU BARIS dan semua pintunya menghadap +Z,
## bersebelahan di sisi depan: kulkas, lalu lemari bahan di sampingnya. Karena
## itu jejak dasarnya selalu N x 1 ubin dan melebar seiring tier, dan memutarnya
## 90 derajat menjadikannya 1 x N (satu kolom merapat ke dinding samping).
##
## Menyusunnya depan-belakang akan membuat separuh gudang membelakangi kamera
## isometrik: pintu baris belakang tidak akan pernah terlihat, dan pemain tidak
## punya cara menebak sisi mana yang bisa dibuka.
##
## Setiap daun pintu adalah anak Node3D yang namanya diawali "Pintu"
## ("Pintu", "Pintu2", "PintuLemari"). ProceduralAnimationSystem.storage_door()
## membuka SEMUANYA sekaligus saat pemain mengetuk gudang.
static func build_storage(loc_tier: int) -> Node3D:
	var t: int = clampi(loc_tier, 1, 5)
	var root: Node3D = _root("Storage", t)
	match t:
		1:
			_storage_garasi(root)
		2:
			_storage_ruko(root)
		3:
			_storage_chiller(root)
		4:
			_storage_fresh(root)
		_:
			_storage_cold_room(root)
	return root


## Titik tengah unit ke-`i` dari `count` unit yang berjajar pada sumbu X.
static func _storage_unit_x(i: int, count: int) -> float:
	return (float(i) - float(count - 1) * 0.5) * STORAGE_UNIT_PITCH


## Tier 1 -- "Kulkas Bekas & Rak Kayu": kulkas enamel mint warisan yang catnya
## sudah kusam, bersebelahan dengan lemari pinus berpintu bawah dan rak
## terbuka di atasnya. Kedua pintunya membuka ke arah berlawanan seperti
## sepasang daun pintu.
static func _storage_garasi(root: Node3D) -> void:
	var kusam: Color = Palette.PASTEL_MINT.darkened(0.16)
	var pine: Color = Palette.PINE_WOOD
	var kiri: float = _storage_unit_x(0, 2)
	var kanan: float = _storage_unit_x(1, 2)

	_storage_badan(root, Vector3(kiri, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 0.96, STORAGE_DEPTH), kusam, pine.darkened(0.38))
	# Garis pemisah laci freezer, supaya badan kulkas tidak terbaca satu papan.
	_box(root, Vector3(0.42, 0.014, 0.012), kusam.darkened(0.30),
		Vector3(kiri, 0.742, STORAGE_DOOR_Z))
	_storage_door(root, "Pintu", 0.42, 0.68,
		Vector3(kiri - 0.210, 0.036, STORAGE_DOOR_Z),
		Palette.PASTEL_MINT, METAL_CHROME, true)

	# Badan lemari hanya setinggi pintunya; rak terbuka bertengger DI ATASNYA.
	# Rak yang ditaruh di dalam badan masif tidak akan terlihat sama sekali.
	_storage_badan(root, Vector3(kanan, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 0.50, STORAGE_DEPTH), pine, pine.darkened(0.38))
	_storage_door(root, "PintuLemari", 0.42, 0.44,
		Vector3(kanan + 0.210, 0.030, STORAGE_DOOR_Z),
		pine.lightened(0.10), METAL_COPPER, false)
	_storage_rak(root, 0.44, 0.34, Vector3(kanan, 0.500, 0.0), pine, 2)


## Tier 2 -- "Kulkas Dua Pintu & Lemari Bahan": satu kulkas krem berdaun ganda
## memakan dua petak, lalu lemari pinus berpintu di petak ketiga.
static func _storage_ruko(root: Node3D) -> void:
	var enamel: Color = Palette.VANILLA_CREAM
	var pine: Color = Palette.PINE_WOOD
	var x0: float = _storage_unit_x(0, 3)
	var x1: float = _storage_unit_x(1, 3)
	var x2: float = _storage_unit_x(2, 3)

	# Kulkas satu badan selebar dua petak -- dua daun pintu yang membuka keluar.
	var lebar_kulkas: float = STORAGE_UNIT_PITCH + STORAGE_UNIT_WIDTH
	var pusat_kulkas: float = (x0 + x1) * 0.5
	_storage_badan(root, Vector3(pusat_kulkas, 0.0, 0.0),
		Vector3(lebar_kulkas, 1.10, STORAGE_DEPTH), enamel, Palette.UI_WOOD)
	_storage_door(root, "Pintu", 0.44, 0.84,
		Vector3(pusat_kulkas - lebar_kulkas * 0.5 + 0.010, 0.040, STORAGE_DOOR_Z),
		enamel.lightened(0.05), METAL_CHROME, true)
	_storage_door(root, "Pintu2", 0.44, 0.84,
		Vector3(pusat_kulkas + lebar_kulkas * 0.5 - 0.010, 0.040, STORAGE_DOOR_Z),
		enamel.lightened(0.05), METAL_CHROME, false)

	_storage_badan(root, Vector3(x2, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 0.56, STORAGE_DEPTH), pine, pine.darkened(0.30))
	_storage_door(root, "PintuLemari", 0.42, 0.50,
		Vector3(x2 + 0.210, 0.034, STORAGE_DOOR_Z), pine.lightened(0.10), METAL_COPPER, false)
	_storage_rak(root, 0.44, 0.50, Vector3(x2, 0.560, 0.0), pine, 2)


## Tier 3 -- "Chiller Tegak & Lemari Stainless": dua chiller pintu kaca menyala
## sejuk, lemari stainless berpintu di sampingnya, dan rak gudang terbuka di
## ujung kanan. Keempat unit berjajar menghadap pemain.
static func _storage_chiller(root: Node3D) -> void:
	var x0: float = _storage_unit_x(0, 4)
	var x1: float = _storage_unit_x(1, 4)
	var x2: float = _storage_unit_x(2, 4)
	var x3: float = _storage_unit_x(3, 4)

	for x in [x0, x1]:
		_storage_badan(root, Vector3(x, 0.0, 0.0),
			Vector3(STORAGE_UNIT_WIDTH, 1.20, STORAGE_DEPTH),
			METAL_STEEL, METAL_STEEL.darkened(0.30))
		var kaca: MeshInstance3D = _box(root, Vector3(0.36, 0.92, 0.014),
			Color(GLASS_PANE.r, GLASS_PANE.g, GLASS_PANE.b, GLASS_ALPHA),
			Vector3(x, 0.650, STORAGE_DOOR_Z - 0.010), Vector3.ZERO, 0.12)
		_set_glow(kaca, Palette.PASTEL_MINT, 0.35)

	_storage_door(root, "Pintu", 0.42, 0.98,
		Vector3(x0 - 0.210, 0.110, STORAGE_DOOR_Z), METAL_CHROME, METAL_STEEL, true)
	_storage_door(root, "Pintu2", 0.42, 0.98,
		Vector3(x1 + 0.210, 0.110, STORAGE_DOOR_Z), METAL_CHROME, METAL_STEEL, false)

	# Lemari stainless berlaci.
	_storage_badan(root, Vector3(x2, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 0.94, STORAGE_DEPTH), METAL_CHROME, METAL_STEEL)
	_storage_door(root, "PintuLemari", 0.42, 0.56,
		Vector3(x2 - 0.210, 0.040, STORAGE_DOOR_Z), METAL_CHROME, METAL_STEEL, true)
	for i in 2:
		_cyl(root, 0.30, 0.012, 0.012, METAL_STEEL,
			Vector3(x2, 0.680 + float(i) * 0.170, STORAGE_DOOR_Z + 0.014),
			Vector3(0.0, 0.0, 90.0))

	_storage_rak(root, STORAGE_UNIT_WIDTH, 1.10, Vector3(x3, 0.0, 0.0), METAL_STEEL, 3)


## Tier 4 -- "Chiller Ganda & Lemari Bahan Segar": bodi navy berlis krom, lis
## LED pastel di kaki, panel suhu digital di atas lemari, dan rak bahan segar
## di ujung kanan.
static func _storage_fresh(root: Node3D) -> void:
	var navy: Color = Palette.APRON_NAVY
	var x0: float = _storage_unit_x(0, 4)
	var x1: float = _storage_unit_x(1, 4)
	var x2: float = _storage_unit_x(2, 4)
	var x3: float = _storage_unit_x(3, 4)

	for x in [x0, x1]:
		_storage_badan(root, Vector3(x, 0.0, 0.0),
			Vector3(STORAGE_UNIT_WIDTH, 1.34, STORAGE_DEPTH), navy, METAL_CHROME)
		var kaca: MeshInstance3D = _box(root, Vector3(0.36, 1.04, 0.014),
			Color(GLASS_PANE.r, GLASS_PANE.g, GLASS_PANE.b, GLASS_ALPHA),
			Vector3(x, 0.730, STORAGE_DOOR_Z - 0.010), Vector3.ZERO, 0.12)
		_set_glow(kaca, Palette.PASTEL_PERIWINKLE, 0.45)
		var led: MeshInstance3D = _box(root, Vector3(0.46, 0.022, STORAGE_DEPTH),
			Palette.PASTEL_PERIWINKLE, Vector3(x, 0.014, 0.0))
		_set_glow(led, Palette.PASTEL_PERIWINKLE, 0.70)

	_storage_door(root, "Pintu", 0.42, 1.10,
		Vector3(x0 - 0.210, 0.130, STORAGE_DOOR_Z), METAL_CHROME, Palette.FLOUR_WHITE, true)
	_storage_door(root, "Pintu2", 0.42, 1.10,
		Vector3(x1 + 0.210, 0.130, STORAGE_DOOR_Z), METAL_CHROME, Palette.FLOUR_WHITE, false)

	# Lemari bahan segar, dengan panel suhu digital di atas pintunya.
	_storage_badan(root, Vector3(x2, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 1.12, STORAGE_DEPTH), navy.lightened(0.10), METAL_CHROME)
	_storage_door(root, "PintuLemari", 0.42, 0.72,
		Vector3(x2 - 0.210, 0.040, STORAGE_DOOR_Z), METAL_CHROME, Palette.FLOUR_WHITE, true)
	_box(root, Vector3(0.200, 0.075, 0.015), DARK_GLASS,
		Vector3(x2, 0.930, STORAGE_DOOR_Z + 0.006))
	var suhu: MeshInstance3D = _box(root, Vector3(0.150, 0.036, 0.008), Palette.PASTEL_MINT,
		Vector3(x2, 0.930, STORAGE_DOOR_Z + 0.014))
	_set_glow(suhu, Palette.PASTEL_MINT, 0.80)

	_storage_rak(root, STORAGE_UNIT_WIDTH, 1.16, Vector3(x3, 0.0, 0.0), METAL_CHROME, 3)


## Tier 5 -- "Cold Room & Rak Gudang Industri": bilik pendingin berjalan-masuk
## selebar dua petak, chiller kaca, lemari gudang, lalu rak palet terbuka --
## semuanya sebaris menghadap pemain.
static func _storage_cold_room(root: Node3D) -> void:
	var dinding: Color = Palette.FLOUR_WHITE.darkened(0.08)
	var x0: float = _storage_unit_x(0, 5)
	var x1: float = _storage_unit_x(1, 5)
	var x2: float = _storage_unit_x(2, 5)
	var x3: float = _storage_unit_x(3, 5)
	var x4: float = _storage_unit_x(4, 5)

	# --- Bilik cold room selebar dua petak ---
	var lebar_bilik: float = STORAGE_UNIT_PITCH + STORAGE_UNIT_WIDTH
	var pusat_bilik: float = (x0 + x1) * 0.5
	_storage_badan(root, Vector3(pusat_bilik, 0.0, 0.0),
		Vector3(lebar_bilik, 1.56, STORAGE_DEPTH), dinding, METAL_STEEL.darkened(0.30))
	# Kusen pintu tebal khas ruang pendingin.
	_box(root, Vector3(0.60, 1.28, 0.026), METAL_STEEL,
		Vector3(pusat_bilik - 0.120, 0.700, STORAGE_DOOR_Z - 0.010), Vector3.ZERO, 0.35)
	_storage_door(root, "Pintu", 0.54, 1.18,
		Vector3(pusat_bilik - 0.400, 0.080, STORAGE_DOOR_Z), dinding, METAL_STEEL, true)
	# Unit kompresor di atap bilik.
	_box(root, Vector3(0.44, 0.20, 0.30), METAL_STEEL,
		Vector3(pusat_bilik + 0.190, 1.680, 0.0), Vector3.ZERO, 0.40)
	for i in 3:
		_box(root, Vector3(0.34, 0.016, 0.026), METAL_CHROME,
			Vector3(pusat_bilik + 0.190, 1.630 + float(i) * 0.050, 0.150))
	var papan: MeshInstance3D = _box(root, Vector3(0.170, 0.055, 0.012), Palette.PASTEL_MINT,
		Vector3(pusat_bilik + 0.190, 1.440, STORAGE_DOOR_Z))
	_set_glow(papan, Palette.PASTEL_MINT, 0.85)

	# --- Chiller kaca ---
	_storage_badan(root, Vector3(x2, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 1.32, STORAGE_DEPTH), METAL_STEEL, METAL_STEEL.darkened(0.30))
	var kaca: MeshInstance3D = _box(root, Vector3(0.36, 1.02, 0.014),
		Color(GLASS_PANE.r, GLASS_PANE.g, GLASS_PANE.b, GLASS_ALPHA),
		Vector3(x2, 0.720, STORAGE_DOOR_Z - 0.010), Vector3.ZERO, 0.12)
	_set_glow(kaca, Palette.PASTEL_MINT, 0.40)
	_storage_door(root, "Pintu2", 0.42, 1.08,
		Vector3(x2 - 0.210, 0.130, STORAGE_DOOR_Z), METAL_CHROME, METAL_STEEL, true)

	# --- Lemari gudang berpintu, lalu rak palet terbuka ---
	_storage_badan(root, Vector3(x3, 0.0, 0.0),
		Vector3(STORAGE_UNIT_WIDTH, 1.14, STORAGE_DEPTH), METAL_CHROME, METAL_STEEL)
	_storage_door(root, "PintuLemari", 0.42, 0.74,
		Vector3(x3 + 0.210, 0.040, STORAGE_DOOR_Z), METAL_CHROME, METAL_STEEL, false)
	_storage_rak(root, STORAGE_UNIT_WIDTH, 1.24, Vector3(x4, 0.0, 0.0), METAL_STEEL, 3)


## Badan satu unit gudang: kotak utama bersudut tumpul, alas, dan lis atas.
## `origin` adalah titik tengah ALAS unit, bukan pusat badannya.
static func _storage_badan(parent: Node3D, origin: Vector3, size: Vector3,
		badan: Color, alas: Color) -> void:
	_slab(parent, size, 0.030, badan, origin + Vector3(0.0, size.y * 0.5, 0.0))
	_box(parent, Vector3(size.x, 0.045, size.z), alas, origin + Vector3(0.0, 0.022, 0.0))
	_box(parent, Vector3(size.x, 0.028, size.z), badan.darkened(0.20),
		origin + Vector3(0.0, size.y - 0.014, 0.0))


## Daun pintu gudang: berengsel TEGAK (sumbu Y) dan menghadap +Z.
##
## `hinge` adalah titik engselnya. Bila `engsel_kiri`, daun membentang ke arah
## +X dan berayun keluar saat rotasi Y negatif; bila tidak, ia membentang ke
## -X dan berayun keluar saat rotasi Y positif. Dua pintu bersebelahan karena
## itu bisa dipasang saling membelakangi engsel dan membuka seperti sepasang
## daun pintu lemari.
##
## Metadata open_sign dibaca ProceduralAnimationSystem.storage_door(), jadi
## arah ayun tidak pernah perlu ditebak ulang di lapisan animasi.
static func _storage_door(parent: Node3D, node_name: String, width: float, height: float,
		hinge: Vector3, panel: Color, handle: Color, engsel_kiri: bool) -> Node3D:
	var door := Node3D.new()
	door.name = node_name
	parent.add_child(door)
	door.position = hinge
	var arah: float = 1.0 if engsel_kiri else -1.0
	door.set_meta("hinge_axis", "y")
	door.set_meta("open_sign", -arah)

	_slab(door, Vector3(width, height, 0.030), 0.012, panel,
		Vector3(arah * width * 0.5, height * 0.5, 0.0))
	# Gagang batang tegak di tepi yang jauh dari engsel.
	var gx: float = arah * (width - 0.046)
	_cyl(door, height * 0.45, 0.013, 0.013, handle, Vector3(gx, height * 0.5, 0.026))
	for i in 2:
		var sy: float = -1.0 if i == 0 else 1.0
		_box(door, Vector3(0.026, 0.026, 0.042), handle,
			Vector3(gx, height * 0.5 + sy * height * 0.225, 0.018))
	return door


## Rak terbuka berisi karung tepung dan stoples bahan, menghadap +Z.
## `origin` adalah titik tengah ALAS rak.
##
## Isinya sengaja dibuat berisi: rak kosong terbaca sebagai lemari rusak,
## bukan sebagai stok bahan yang siap dipakai.
static func _storage_rak(parent: Node3D, w: float, h: float, origin: Vector3,
		warna: Color, tingkat: int) -> void:
	var d: float = STORAGE_DEPTH
	var post: float = 0.034
	var n: int = maxi(tingkat, 1)
	for i in 4:
		var sx: float = -1.0 if i < 2 else 1.0
		var sz: float = -1.0 if (i % 2) == 0 else 1.0
		_box(parent, Vector3(post, h, post), warna.darkened(0.28),
			origin + Vector3(sx * (w * 0.5 - post * 0.5), h * 0.5, sz * (d * 0.5 - post * 0.5)))
	for i in n + 1:
		_box(parent, Vector3(w, 0.026, d), warna,
			origin + Vector3(0.0, h * float(i) / float(n), 0.0))

	# Isi tiap tingkat: karung tepung di kiri, stoples bahan di kanan.
	var karung: float = minf(w * 0.40, 0.26)
	for i in n:
		var y: float = h * float(i) / float(n)
		_slab(parent, Vector3(karung, 0.13, d * 0.62), 0.028, Palette.FLOUR_WHITE,
			origin + Vector3(-w * 0.5 + karung * 0.62, y + 0.078, 0.0))
		_cyl(parent, 0.14, 0.044, 0.044, Palette.BUTTER_YELLOW,
			origin + Vector3(w * 0.5 - 0.080, y + 0.083, 0.0))



# ---------------------------------------------------------------------------
# MEJA KASIR & MEJA KHUSUS OJOL
# ---------------------------------------------------------------------------

## Meja kasir. `tier` (tier lokasi 1..5) hanya menaikkan mutu finishing:
## pinus polos -> cat pastel -> karamel + tembaga -> navy + krom -> cokelat emas.
## Selalu memiliki anak Node3D "Tablet": titik pasang tablet RotiFood
## (sudah diputar 180 derajat supaya layar menghadap kasir di sisi -Z).
static func build_counter(tier: int) -> Node3D:
	var t: int = clampi(tier, 1, 5)
	var root: Node3D = _root("Counter", t)

	var body_colors: Array[Color] = [
		Palette.PINE_WOOD,
		Palette.PASTEL_MINT,
		Palette.CARAMEL,
		Palette.APRON_NAVY,
		Palette.DARK_CHOCOLATE,
	]
	var top_colors: Array[Color] = [
		Palette.PINE_WOOD.darkened(0.18),
		Palette.PINE_WOOD,
		Palette.VANILLA_CREAM,
		Palette.FLOUR_WHITE,
		Palette.VANILLA_CREAM,
	]
	var trim_colors: Array[Color] = [
		Palette.CARAMEL,
		Palette.FLOUR_WHITE,
		METAL_COPPER,
		METAL_CHROME,
		Palette.APRON_GOLD,
	]
	var body: Color = body_colors[t - 1]
	var top: Color = top_colors[t - 1]
	var trim: Color = trim_colors[t - 1]

	# Seluruh ketinggian diturunkan dari `h`, bukan ditulis satu per satu: badan
	# meja MENYUSUT saat mejanya dipendekkan, sedangkan barang yang berdiri DI
	# ATASNYA tetap seukuran semula dan ikut turun bersama papannya.
	var h: float = COUNTER_HEIGHT
	var top_th: float = 0.050
	var body_h: float = maxf(h - top_th, 0.10)

	_slab(root, Vector3(1.00, body_h, 0.42), 0.035, body, Vector3(0.0, body_h * 0.5, 0.0))
	_box(root, Vector3(0.92, 0.050, 0.38), body.darkened(0.3), Vector3(0.0, 0.025, 0.0))
	_slab(root, Vector3(1.08, top_th, 0.48), 0.018, top, Vector3(0.0, h - top_th * 0.5, 0.0))
	_box(root, Vector3(1.01, 0.035, 0.43), trim, Vector3(0.0, body_h * 0.78, 0.0))

	# Mesin kasir: bentuknya tetap, warnanya ikut finishing tier.
	_slab(root, Vector3(0.20, 0.12, 0.17), 0.02, top.darkened(0.08), Vector3(-0.320, h + 0.060, -0.030))
	_box(root, Vector3(0.140, 0.060, 0.010), DARK_GLASS, Vector3(-0.320, h + 0.130, 0.040), Vector3(-25.0, 0.0, 0.0))
	for i in 3:
		_box(root, Vector3(0.030, 0.012, 0.030), trim, Vector3(-0.380 + float(i) * 0.060, h + 0.122, -0.010))

	if t <= 3:
		# Bel meja kuningan: manis dan sangat "tahun 2000-an".
		var bell: MeshInstance3D = _sph(root, 0.038, METAL_COPPER, Vector3(0.150, h + 0.015, 0.130))
		bell.scale = Vector3(1.0, 0.62, 1.0)
		_cyl(root, 0.012, 0.045, 0.045, METAL_COPPER.darkened(0.2), Vector3(0.150, h + 0.006, 0.130))
	else:
		# Tier tinggi: garis LED pastel di bawah bibir meja.
		var led: MeshInstance3D = _box(root, Vector3(1.02, 0.014, 0.020), Palette.PASTEL_PERIWINKLE, Vector3(0.0, h - 0.058, 0.222))
		_set_glow(led, Palette.PASTEL_PERIWINKLE, 0.65)

	var tablet_spot := Node3D.new()
	tablet_spot.name = "Tablet"
	root.add_child(tablet_spot)
	tablet_spot.position = Vector3(0.340, h + 0.002, -0.020)
	tablet_spot.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	return root


# ---------------------------------------------------------------------------
# MEJA KASIR PEMBATAS (toko di depan +Z, dapur di belakang -Z)
# ---------------------------------------------------------------------------

## Meja kasir panjang yang menjadi PEMBATAS FISIK antara area toko dan dapur.
## ShopWorld menaruhnya tepat di `partition_z(tier)`, sehingga urutan ruangan
## dari belakang ke depan terbaca jelas:
##   dinding belakang -> mixer & oven -> MEJA PEMBATAS -> rak roti -> antrean -> pintu
##
## Dibangun terpusat di origin lokal: memanjang `span` pada sumbu X, tebal
## DIVIDER_DEPTH pada sumbu Z, permukaan atas tepat di y = DIVIDER_HEIGHT.
## Sisi +Z adalah muka pembeli (panel gelap berlis), sisi -Z adalah sisi kasir
## (laci uang dan layar menghadap ke sana).
##
## Anak wajib:
##   "Register0".."RegisterN" -- mesin kasir berdiri di ATAS meja, tersebar merata
##   "Tablet"                 -- titik pasang tablet RotiFood di ujung kanan meja
##                               (sudah di-yaw 180 agar layarnya menghadap kasir)
##   "Surface"                -- titik tengah permukaan meja untuk menaruh barang
##
## `registers` dibatasi 0..MAX_REGISTERS demi anggaran 2.000 tris (GDD 12.2).
## LocationDB paling banyak memberi 3 `cashier_slots`, jadi batas itu tidak
## pernah tersentuh dalam permainan normal.
static func build_divider_counter(tier: int, span: float, registers: int) -> Node3D:
	var t: int = clampi(tier, 1, 5)
	var root: Node3D = _root("DividerCounter", t)

	var sp: float = maxf(span, float(DIVIDER_MIN_TILES) * FLOOR_TILE)
	var dep: float = DIVIDER_DEPTH
	var h: float = DIVIDER_HEIGHT
	var top_th: float = 0.06
	var kick_h: float = 0.06

	var body: Color = Palette.PINE_WOOD
	var front: Color = Palette.PINE_WOOD.darkened(0.22)
	var top: Color = Palette.CARAMEL
	# Lis aksen ikut naik kelas bersama tier lokasi, sama seperti build_counter().
	var trim_colors: Array[Color] = [
		Palette.CARAMEL,
		METAL_COPPER,
		METAL_COPPER,
		METAL_CHROME,
		Palette.APRON_GOLD,
	]
	var trim: Color = trim_colors[t - 1]

	# --- Badan meja ---------------------------------------------------------
	# Alas terpendam (toe kick) supaya meja terbaca berat dan membumi.
	_box(root, Vector3(sp - 0.12, kick_h, dep - 0.10), body.darkened(0.38), Vector3(0.0, kick_h * 0.5, 0.0))
	var body_h: float = h - top_th - kick_h
	_slab(root, Vector3(sp, body_h, dep), 0.035, body, Vector3(0.0, kick_h + body_h * 0.5, 0.0))

	# Panel muka pembeli (+Z): sedikit lebih gelap dan sedikit menonjol.
	_slab(root, Vector3(sp - 0.06, body_h - 0.10, 0.030), 0.012, front, Vector3(0.0, kick_h + body_h * 0.5, dep * 0.5 + 0.008))
	# Tiga list mendatar tipis sebagai aksen panel muka.
	for i in 3:
		var ly: float = kick_h + body_h * (0.24 + float(i) * 0.26)
		_box(root, Vector3(sp - 0.14, 0.018, 0.012), trim, Vector3(0.0, ly, dep * 0.5 + 0.026))

	# --- Papan atas ---------------------------------------------------------
	# Papan karamel menonjol DIVIDER_TOP_OVERHANG di tiap sisi, sudut tumpul
	# lewat rounded_slab() supaya terasa empuk (GDD 4.1), bukan kotak tajam.
	var over: float = DIVIDER_TOP_OVERHANG
	_slab(root, Vector3(sp + over * 2.0, top_th, dep + over * 2.0), 0.022, top, Vector3(0.0, h - top_th * 0.5, 0.0))
	var lip_pos := Vector3(0.0, h - top_th - 0.012, dep * 0.5 + over)
	if t <= 3:
		_box(root, Vector3(sp + over * 2.0, 0.016, 0.014), trim, lip_pos)
	else:
		# Tier tinggi: garis LED pastel di bawah bibir meja (senada build_counter).
		var led: MeshInstance3D = _box(root, Vector3(sp + over * 2.0, 0.016, 0.014), Palette.PASTEL_PERIWINKLE, lip_pos)
		_set_glow(led, Palette.PASTEL_PERIWINKLE, 0.65)

	# --- Mesin kasir di atas meja -------------------------------------------
	var n: int = clampi(registers, 0, MAX_REGISTERS)
	var reg_span: float = maxf(sp - 0.46, 0.02)
	for i in n:
		_divider_register(root, i, Vector3(_slot_x(i, n, reg_span), h, -0.030), trim)

	# --- Penanda untuk ShopWorld --------------------------------------------
	var tablet_spot := Node3D.new()
	tablet_spot.name = "Tablet"
	root.add_child(tablet_spot)
	tablet_spot.position = Vector3(sp * 0.5 - 0.17, h, -0.020)
	tablet_spot.rotation_degrees = Vector3(0.0, 180.0, 0.0)

	var surface := Node3D.new()
	surface.name = "Surface"
	root.add_child(surface)
	surface.position = Vector3(0.0, h, 0.0)
	return root


## Satu mesin kasir di atas meja pembatas: badan kotak krem, laci uang dan layar
## kecil miring yang sama-sama menghadap kasir di sisi -Z.
static func _divider_register(parent: Node3D, index: int, pos: Vector3, trim: Color) -> Node3D:
	var reg := Node3D.new()
	reg.name = "Register%d" % index
	parent.add_child(reg)
	reg.position = pos

	var shell: Color = Palette.VANILLA_CREAM
	_slab(reg, Vector3(0.22, 0.13, 0.18), 0.020, shell, Vector3(0.0, 0.065, 0.0))
	# Laci uang: mukanya sedikit menjorok keluar di sisi kasir.
	_box(reg, Vector3(0.19, 0.050, 0.016), shell.darkened(0.16), Vector3(0.0, 0.045, -0.094))
	_box(reg, Vector3(0.070, 0.014, 0.014), trim, Vector3(0.0, 0.045, -0.104))
	# Tiga tombol besar di permukaan atas badan.
	for i in 3:
		_box(reg, Vector3(0.040, 0.012, 0.034), trim, Vector3(-0.058 + float(i) * 0.058, 0.136, 0.030))

	# Layar dimiringkan 18 derajat: mukanya (-Z lokal) condong ke atas, pas
	# dibaca kasir yang berdiri di sisi dapur.
	_box(reg, Vector3(0.050, 0.075, 0.030), shell.darkened(0.10), Vector3(0.0, 0.155, -0.040), Vector3(18.0, 0.0, 0.0))
	var panel: MeshInstance3D = _slab(reg, Vector3(0.160, 0.105, 0.014), 0.008, DARK_GLASS, Vector3(0.0, 0.215, -0.052), Vector3(18.0, 0.0, 0.0))
	var screen: MeshInstance3D = _box(panel, Vector3(0.130, 0.082, 0.004), Palette.PASTEL_MINT, Vector3(0.0, 0.0, -0.009))
	_set_glow(screen, Palette.PASTEL_MINT, 0.6)
	return reg


## Meja Khusus Ojol (GDD 3.6.B) -- tersedia mulai lokasi Tier 3.
## Sengaja dibedakan total dari meja kasir: badan hijau RotiFood #4EBA6F,
## papan nama bergambar skuter, dan titik "BagSpot" tempat kantong siap ambil.
static func build_pickup_counter() -> Node3D:
	var root: Node3D = _root("PickupCounter", 0)
	var green: Color = Palette.OJOL_GREEN

	# Setinggi meja layan lainnya: driver ojol berdiri di depannya, dan meja yang
	# melewati dadanya membuat serah-terima paket terlihat mustahil.
	var h: float = COUNTER_HEIGHT
	var top_th: float = 0.050
	var body_h: float = maxf(h - top_th, 0.10)

	_slab(root, Vector3(0.72, body_h, 0.40), 0.035, green, Vector3(0.0, body_h * 0.5, 0.0))
	_box(root, Vector3(0.66, 0.050, 0.36), green.darkened(0.32), Vector3(0.0, 0.025, 0.0))
	_slab(root, Vector3(0.78, top_th, 0.44), 0.018, Palette.VANILLA_CREAM, Vector3(0.0, h - top_th * 0.5, 0.0))
	_box(root, Vector3(0.73, 0.030, 0.41), Palette.FLOUR_WHITE, Vector3(0.0, body_h * 0.82, 0.0))

	# Tiang + papan nama. Papannya sengaja tetap DI ATAS kepala: ia rambu yang
	# harus terbaca dari jauh, bukan bidang meja.
	var papan_y: float = h + 0.30
	_cyl(root, 0.26, 0.018, 0.022, METAL_CHROME, Vector3(0.280, h + 0.130, -0.100))
	_slab(root, Vector3(0.34, 0.16, 0.025), 0.02, green, Vector3(0.180, papan_y, -0.100))
	_box(root, Vector3(0.30, 0.020, 0.010), Palette.FLOUR_WHITE, Vector3(0.180, papan_y - 0.055, -0.086))

	# Ikon skuter mungil di papan: dua roda cakram + badan + setang.
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_cyl(root, 0.012, 0.030, 0.030, Palette.DARK_CHOCOLATE, Vector3(0.180 + sx * 0.085, papan_y - 0.015, -0.086), Vector3(90.0, 0.0, 0.0))
	_box(root, Vector3(0.130, 0.035, 0.012), Palette.FLOUR_WHITE, Vector3(0.180, papan_y + 0.008, -0.086))
	_box(root, Vector3(0.016, 0.055, 0.012), Palette.FLOUR_WHITE, Vector3(0.245, papan_y + 0.035, -0.086))

	# Rak kecil di bawah meja untuk kantong cadangan.
	_box(root, Vector3(0.62, 0.020, 0.34), Palette.VANILLA_CREAM.darkened(0.1), Vector3(0.0, body_h * 0.48, 0.0))

	var bag_spot := Node3D.new()
	bag_spot.name = "BagSpot"
	root.add_child(bag_spot)
	bag_spot.position = Vector3(-0.140, h + 0.025, 0.020)
	return root


## Tablet kasir digital RotiFood (GDD 3.6.A): papan gelap miring di atas dudukan
## kecil, dengan muka layar pastel yang menyala lembut.
static func build_tablet() -> Node3D:
	var root: Node3D = _root("Tablet", 0)
	_box(root, Vector3(0.100, 0.012, 0.075), RUBBER_DARK, Vector3(0.0, 0.006, 0.0))
	_box(root, Vector3(0.028, 0.080, 0.016), RUBBER_DARK, Vector3(0.0, 0.046, -0.018), Vector3(-14.0, 0.0, 0.0))

	var slab: MeshInstance3D = _slab(root, Vector3(0.115, 0.155, 0.012), 0.008, DARK_GLASS, Vector3(0.0, 0.095, 0.0), Vector3(-14.0, 0.0, 0.0))
	slab.name = "Slab"

	var screen: MeshInstance3D = _box(slab, Vector3(0.098, 0.136, 0.004), Palette.PASTEL_PERIWINKLE, Vector3(0.0, 0.0, 0.008))
	screen.name = "Screen"
	_set_glow(screen, Palette.PASTEL_PERIWINKLE, 0.55)

	# Isi layar: balon pesanan hijau RotiFood + dua baris daftar roti.
	_box(slab, Vector3(0.048, 0.032, 0.002), Palette.OJOL_GREEN, Vector3(0.0, 0.034, 0.011))
	_box(slab, Vector3(0.062, 0.007, 0.002), Palette.FLOUR_WHITE, Vector3(0.0, -0.014, 0.011))
	_box(slab, Vector3(0.044, 0.007, 0.002), Palette.FLOUR_WHITE, Vector3(-0.009, -0.032, 0.011))
	return root


# ---------------------------------------------------------------------------
# RUANG TOKO (GDD 4.1 Cozy + GDD 6 progresi lokasi)
# ---------------------------------------------------------------------------

## Interior toko lengkap untuk tier lokasi 1..5.
## Isi: lantai ubin terakota papan catur, dinding pinus hangat, jendela kayu
## bertirai gingham pastel, jam dinding bandul, cahaya
## golden hour, dan WorldEnvironment hangat.
##
## Sekat mengikuti GDD 6:
##   T1 garasi  -> dapur & display menyatu tanpa sekat (3 x 3 m + 3 x 3 m)
##   T2 ruko    -> sekat penuh antara dapur dan area pembeli (ada celah pintu)
##   T3 bakery  -> sekat setinggi dada, ruang lebih lebar
##   T4 flagship-> sekat rendah ala open kitchen
##   T5 mega    -> tanpa sekat, hanya dua kolom penanda
## EquipmentFactory adalah PEMILIK TUNGGAL dimensi ruangan. ShopWorld wajib
## menanyakannya lewat fungsi-fungsi ini, tidak boleh punya rumus sendiri —
## kalau dua pihak menghitung sendiri, perabot bisa tertanam di balik dinding.
static func room_width(loc_tier: int) -> float:
	return ROOM_WIDTHS[clampi(loc_tier, 1, 5) - 1]


static func room_depth(loc_tier: int) -> float:
	return ROOM_DEPTHS[clampi(loc_tier, 1, 5) - 1]


static func room_height(loc_tier: int) -> float:
	return WALL_HEIGHTS[clampi(loc_tier, 1, 5) - 1]


## Tebal dinding, dipakai untuk menjaga perabot tidak menembus permukaan dalam.
static func room_wall_thickness() -> float:
	return WALL_THICK


## Jarak permukaan DALAM dinding dari tepi lantai.
##
## Dinding digambar TEPAT DI ATAS tepi lantai (_room_walls memusatkannya di
## +-w/2), jadi ia hanya memakan setengah tebalnya ke dalam ruangan — 5 cm,
## bukan 10 cm. Penjepit perabot dulu memakai WALL_THICK penuh plus kelonggaran,
## dan 9 cm ruang hantu itulah yang mendorong oven di ubin terluar sampai
## menembus tetangganya.
static func wall_inset() -> float:
	return WALL_THICK * 0.5


## Garis pemisah dapur dan area toko pada sumbu Z. Z lebih kecil = area dapur.
## Tier 1 tidak punya sekat fisik (GDD 6: "menyatu tanpa sekat"), tapi garis ini
## tetap dipakai sebagai batas penataan supaya dua zona tetap terbaca.
##
## Selalu jatuh di TEPI ubin: dihitung sebagai sekian ubin dari dinding
## belakang, bukan sebagai persentase kedalaman.
static func partition_z(loc_tier: int) -> float:
	var t: int = clampi(loc_tier, 1, 5)
	return -room_depth(t) * 0.5 + float(KITCHEN_TILES[t - 1]) * FLOOR_TILE


# ---------------------------------------------------------------------------
# KISI UBIN 50 CM — satuan patokan seluruh penempatan perabot
# ---------------------------------------------------------------------------
# Lantai, petak Mode Dekorasi, dan titik berdiri setiap perabot memakai kisi
# yang SAMA. Sebelumnya masing-masing punya rumusnya sendiri, sehingga rak yang
# terlihat rapi di layar dekor mendarat setengah ubin meleset di dunia 3D.

## Jumlah ubin pada sumbu X (kolom). Bulat karena ROOM_WIDTHS kelipatan ubin.
static func floor_cols(loc_tier: int) -> int:
	return maxi(1, int(round(room_width(loc_tier) / FLOOR_TILE)))


## Jumlah ubin pada sumbu Z (baris).
static func floor_rows(loc_tier: int) -> int:
	return maxi(1, int(round(room_depth(loc_tier) / FLOOR_TILE)))


## Jumlah baris ubin yang menjadi zona DAPUR, dihitung dari dinding belakang.
## Baris 0..kitchen_tiles-1 = dapur, sisanya area toko.
static func kitchen_tiles(loc_tier: int) -> int:
	return KITCHEN_TILES[clampi(loc_tier, 1, 5) - 1]


## Titik tengah ubin kolom ke-`col` (0 = mepet dinding kiri) pada sumbu X.
static func tile_x(loc_tier: int, col: int) -> float:
	return -room_width(loc_tier) * 0.5 + (float(col) + 0.5) * FLOOR_TILE


## Titik tengah ubin baris ke-`row` (0 = mepet dinding belakang) pada sumbu Z.
static func tile_z(loc_tier: int, row: int) -> float:
	return -room_depth(loc_tier) * 0.5 + (float(row) + 0.5) * FLOOR_TILE


## Kolom ubin terdekat dengan koordinat X bebas.
static func tile_col_at(loc_tier: int, x: float) -> int:
	var col: int = int(floor((x + room_width(loc_tier) * 0.5) / FLOOR_TILE))
	return clampi(col, 0, floor_cols(loc_tier) - 1)


## Baris ubin terdekat dengan koordinat Z bebas.
static func tile_row_at(loc_tier: int, z: float) -> int:
	var row: int = int(floor((z + room_depth(loc_tier) * 0.5) / FLOOR_TILE))
	return clampi(row, 0, floor_rows(loc_tier) - 1)


## Pusat ubin yang MEMUAT koordinat `x`, tanpa memedulikan dinding.
##
## Fungsi ini TIDAK PERNAH memindahkan perabot ke ubin lain — itu disengaja.
## Pendahulunya memilih "pusat ubin sah terdekat", dan karena ubin tepi tidak
## pernah sah, ia dan ubin di sebelahnya jatuh ke titik yang sama: dua perabot
## di dua petak berbeda berakhir menumpuk. Perabot yang badannya menjorok ke
## dinding cukup digeser DI DALAM ubinnya sendiri (lihat
## ShopWorld._fit_inside_walls()), seperti lemari yang dirapatkan ke tembok.
static func snap_x(loc_tier: int, x: float) -> float:
	return tile_x(loc_tier, tile_col_at(loc_tier, x))


## Pusat ubin yang memuat koordinat `z`.
static func snap_z(loc_tier: int, z: float) -> float:
	return tile_z(loc_tier, tile_row_at(loc_tier, z))


# ---------------------------------------------------------------------------
# JEJAK LANTAI PERABOT (footprint)
# ---------------------------------------------------------------------------
# Setiap perabot menempati bilangan UBIN utuh: minimal 1 x 1 (50 x 50 cm), rak
# 2 x 1 (100 x 50 cm), Oven Conveyor Tier 5 bahkan 4 x 1 (200 x 50 cm).
#
# Ini tabel DESAIN, bukan hasil pengukuran mesh. Membulatkan ukuran mesh secara
# otomatis terlalu peka di ambang: mixer Tier 4 yang cuma 6 cm lebih lebar dari
# satu ubin akan melompat jadi 2 x 2 dan tiba-tiba memakan empat petak. Angka
# di sini dipilih supaya penskalaan mesh tetap wajar (0,78x - 1,21x).

## Jejak lantai per jenis perabot dan tier, dalam ubin [lebar X, kedalaman Z].
const FOOTPRINTS: Dictionary = {
	"mixer": [Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 1), Vector2i(1, 2), Vector2i(1, 2)],
	"oven": [Vector2i(1, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(2, 1), Vector2i(3, 1)],
	"display": [Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 1)],
	"pickup": [Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 1), Vector2i(2, 1)],
	# Gudang Penyimpanan diindeks TIER LOKASI, bukan tier alat: ia sepaket
	# dengan bangunan (GDD 5.2.2), jadi jejaknya melebar begitu toko naik kelas
	# — 2 ubin di Garasi sampai 5 ubin untuk cold room skala industri.
	#
	# Selalu SATU baris ubin dalam: kulkas dan lemari berjajar bersebelahan
	# dengan semua pintu menghadap depan, jadi gudang bertambah besar dengan
	# melebar ke samping, bukan dengan menebal ke belakang.
	"storage": [Vector2i(2, 1), Vector2i(3, 1), Vector2i(4, 1), Vector2i(4, 1), Vector2i(5, 1)],
}

## Sisa ruang total pada tiap sumbu supaya dua perabot bersebelahan tidak
## berdempet tanpa celah sama sekali (0,03 m di tiap sisi).
##
## Juga penyangga terhadap dinding: perabot di ubin terluar berdiri di pusat
## ubinnya, padahal 5 cm ubin itu berada DI BAWAH dinding. Margin inilah yang
## membuat penjepit dinding hanya perlu menggesernya 2 cm, bukan setengah ubin.
const FOOTPRINT_MARGIN: float = 0.06


## Jejak lantai satu perabot dalam ubin. Vector2i(1, 1) bila jenisnya tak dikenal —
## satu ubin adalah lantai minimum setiap perabot.
static func footprint(kind: String, tier: int) -> Vector2i:
	if not FOOTPRINTS.has(kind):
		return Vector2i.ONE
	var baris: Array = FOOTPRINTS[kind]
	return baris[clampi(tier, 1, 5) - 1]


## Jejak lantai setelah diputar. Rotasi 90/270 derajat menukar sisi lebar dan
## kedalaman; 0/180 tidak mengubah apa pun.
static func footprint_rotated(kind: String, tier: int, rot_deg: int) -> Vector2i:
	var f: Vector2i = footprint(kind, tier)
	if posmod(rot_deg, 180) == 90:
		return Vector2i(f.y, f.x)
	return f


## Ukuran jejak dalam meter (sudah dikurangi margin antar-perabot).
static func footprint_meters(tiles: Vector2i) -> Vector2:
	return Vector2(
		float(tiles.x) * FLOOR_TILE - FOOTPRINT_MARGIN,
		float(tiles.y) * FLOOR_TILE - FOOTPRINT_MARGIN)


## Menskalakan satu perabot SERAGAM supaya badannya pas mengisi jejak lantainya.
##
## Seragam, bukan per sumbu: meregangkan mixer 1,1x pada X saja akan membuat
## mangkuknya lonjong. Sumbu yang paling sesak yang menentukan, sehingga perabot
## selalu MUAT di jejaknya dan tidak pernah menjorok ke petak tetangga.
##
## Dipanggil SEBELUM node diputar — jejak yang dipakai di sini selalu jejak
## dasar (rot 0), sama seperti mesh-nya.
static func fit_to_footprint(node: Node3D, kind: String, tier: int) -> float:
	if node == null:
		return 1.0
	var box: AABB = _mesh_bounds(node)
	if box.size.x <= 0.0001 or box.size.z <= 0.0001:
		return 1.0
	var target: Vector2 = footprint_meters(footprint(kind, tier))
	var skala: float = minf(target.x / box.size.x, target.y / box.size.z)
	node.scale = Vector3(skala, skala, skala)
	return skala


## Kotak pembatas seluruh mesh keturunan `node`, dalam koordinat lokal node.
static func _mesh_bounds(node: Node3D) -> AABB:
	var box := AABB()
	var ada: bool = false
	var antrean: Array[Node] = [node]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var rel: Transform3D = node.transform.affine_inverse() * _rel_transform(node, mi)
		var dunia: AABB = rel * mi.get_aabb()
		if ada:
			box = box.merge(dunia)
		else:
			box = dunia
			ada = true
	return box


## Transform `mi` relatif terhadap `root`, dirangkai manual supaya tidak
## bergantung pada node sudah masuk pohon scene atau belum.
static func _rel_transform(root: Node3D, mi: Node3D) -> Transform3D:
	var t: Transform3D = mi.transform
	var n: Node = mi.get_parent()
	while n != null and n != root:
		var n3 := n as Node3D
		if n3 != null:
			t = n3.transform * t
		n = n.get_parent()
	return root.transform * t


## Baris ubin yang DITEMPATI meja kasir pembatas: baris pertama zona toko.
## Baris ubin yang DITEMPATI meja kasir pembatas: baris pertama zona toko.
##
## Garasi 6 x 12: baris dapur 0-5, meja kasir di baris 6, rak display mulai
## baris 7. Dalam hitungan pemain (mulai dari 1) meja kasir berada di baris 7.
##
## Meja ini TIDAK bisa dipindah pemain — ia bagian dari bangunan, bukan perabot
## lepas — jadi barisnya ditentukan di sini sekali untuk selamanya.
static func counter_row(loc_tier: int) -> int:
	return mini(kitchen_tiles(loc_tier), floor_rows(loc_tier) - 1)


## Titik tengah baris meja kasir pada sumbu Z.
static func counter_z(loc_tier: int) -> float:
	return tile_z(loc_tier, counter_row(loc_tier))


## Baris ubin TERAKHIR yang boleh ditempati alat dapur (mixer/oven).
##
## Satu baris terakhir zona dapur disisakan sebagai LORONG JALAN STAF, tepat di
## belakang meja kasir. Tanpa lorong ini baker tidak punya jalan untuk mencapai
## meja, dan alat dapur berdempetan langsung dengan punggung meja.
static func kitchen_row_max(loc_tier: int) -> int:
	return maxi(kitchen_tiles(loc_tier) - 2, 0)


## Baris ubin PERTAMA yang boleh ditempati rak display: tepat di depan meja
## kasir, karena baris meja kasir itu sendiri sudah terpakai.
static func shop_row_min(loc_tier: int) -> int:
	return mini(kitchen_tiles(loc_tier) + 1, floor_rows(loc_tier) - 1)


## Jejak satu perabot dalam satuan ubin, dibulatkan ke atas. Dipakai suite tes
## dan Mode Dekorasi untuk melaporkan "alat ini makan berapa petak".
static func footprint_tiles(size_x: float, size_z: float) -> Vector2i:
	return Vector2i(
		maxi(1, int(ceil(size_x / FLOOR_TILE - 0.0001))),
		maxi(1, int(ceil(size_z / FLOOR_TILE - 0.0001))))


static func build_room(loc_tier: int) -> Node3D:
	var t: int = clampi(loc_tier, 1, 5)
	var root: Node3D = _root("Room", t)

	var w: float = ROOM_WIDTHS[t - 1]
	var d: float = ROOM_DEPTHS[t - 1]
	var h: float = WALL_HEIGHTS[t - 1]
	var pine: Color = Palette.PINE_WOOD
	var pine_soft: Color = Palette.PINE_WOOD.lightened(0.18)

	_room_floor(root, w, d, partition_z(t))
	_room_walls(root, w, d, h, pine_soft)
	_room_partition(root, t, w, h, pine_soft)

	# Jendela: satu di Tier 1-2, dua mulai Tier 3, plus jendela samping Tier 4+.
	var win_y: float = minf(1.15, h * 0.62)
	_cozy_window(root, 0, Vector3(-w * 0.22, win_y, -d * 0.5 + WALL_THICK * 0.5), 0.0, 0.95, 0.70)
	if t >= 3:
		_cozy_window(root, 1, Vector3(w * 0.22, win_y, -d * 0.5 + WALL_THICK * 0.5), 0.0, 0.95, 0.70)
	if t >= 4:
		_cozy_window(root, 2, Vector3(-w * 0.5 + WALL_THICK * 0.5, win_y, -d * 0.10), 90.0, 1.10, 0.70)

	_wall_clock(root, Vector3(w * 0.06, h - 0.45, -d * 0.5 + WALL_THICK * 0.55))

	# Meja sudut beserta radio kasetnya DIHAPUS atas permintaan pemain: ia
	# berdiri sendirian di tengah lantai toko, tidak menempati ubin mana pun,
	# dan terbaca sebagai perabot yang bisa dipindah padahal bukan.

	_room_lighting(root, w, d, h)
	root.add_child(build_environment())
	return root


## Lantai dua zona: ubin terakota hangat di area toko (z > split_z) dan ubin
## krem netral di area dapur (z < split_z), supaya pemain langsung paham mana
## dapur mana toko walaupun Garasi Tier 1 "menyatu tanpa sekat" (GDD 6).
## Keduanya tetap SATU mesh papan catur (maksimal empat surface) lewat
## SurfaceTool, bukan ratusan MeshInstance3D, agar draw call tetap sedikit.
static func _room_floor(parent: Node3D, w: float, d: float, split_z: float) -> void:
	var base: Color = Palette.TERRACOTTA.darkened(0.35)
	_box(parent, Vector3(w, 0.08, d), base, Vector3(0.0, -0.04, 0.0), Vector3.ZERO, 0.95)
	var shop_a: Color = Palette.TERRACOTTA
	var shop_b: Color = Palette.TERRACOTTA.lightened(0.24)
	var kitchen_a: Color = Palette.VANILLA_CREAM.darkened(0.08)
	var kitchen_b: Color = Palette.FLOUR_WHITE
	var checker: MeshInstance3D = _checker_plane(w, d, FLOOR_TILE, shop_a, shop_b, true, split_z, kitchen_a, kitchen_b)
	checker.name = "Floor"
	ProceduralMeshFactory.attach(parent, checker, Vector3(0.0, 0.002, 0.0))

	# Garis ambang karamel tepat di garis pembatas: tetap terbaca pada celah
	# jalan staf, satu-satunya tempat meja pembatas tidak menutupi lantai.
	var threshold: MeshInstance3D = _box(parent, Vector3(w, 0.014, 0.06), Palette.CARAMEL, Vector3(0.0, 0.009, split_z), Vector3.ZERO, 0.9)
	threshold.name = "ZoneThreshold"


## Dinding pinus: belakang, kiri, kanan, plus dua tunggak di sisi depan agar
## bukaan tengah tetap bebas untuk kamera.
static func _room_walls(parent: Node3D, w: float, d: float, h: float, wall_color: Color) -> void:
	var skirt: Color = Palette.CARAMEL
	_wall(parent, "WallBack", Vector3(w, h, WALL_THICK), Vector3(0.0, h * 0.5, -d * 0.5), wall_color)
	_wall(parent, "WallLeft", Vector3(WALL_THICK, h, d), Vector3(-w * 0.5, h * 0.5, 0.0), wall_color)
	_wall(parent, "WallRight", Vector3(WALL_THICK, h, d), Vector3(w * 0.5, h * 0.5, 0.0), wall_color)

	var stub: float = w * 0.20
	_wall(parent, "WallFrontLeft", Vector3(stub, h, WALL_THICK), Vector3(-w * 0.5 + stub * 0.5, h * 0.5, d * 0.5), wall_color)
	_wall(parent, "WallFrontRight", Vector3(stub, h, WALL_THICK), Vector3(w * 0.5 - stub * 0.5, h * 0.5, d * 0.5), wall_color)

	# Lis kaki dinding karamel: menyatukan lantai terakota dengan dinding pinus.
	_box(parent, Vector3(w, 0.09, 0.04), skirt, Vector3(0.0, 0.045, -d * 0.5 + WALL_THICK * 0.5 + 0.02))
	_box(parent, Vector3(0.04, 0.09, d), skirt, Vector3(-w * 0.5 + WALL_THICK * 0.5 + 0.02, 0.045, 0.0))
	_box(parent, Vector3(0.04, 0.09, d), skirt, Vector3(w * 0.5 - WALL_THICK * 0.5 - 0.02, 0.045, 0.0))


## Sekat dapur-pembeli yang makin terbuka seiring tier lokasi (GDD 6).
## Meja kasir pembatas kini berdiri tepat di partition_z(), jadi sekat lama
## digeser DIVIDER_CLEARANCE ke sisi dapur supaya keduanya tidak menembus.
static func _room_partition(parent: Node3D, t: int, w: float, h: float, wall_color: Color) -> void:
	# MEJA KASIR PEMBATAS kini yang memisahkan dapur dari area toko, jadi tidak
	# ada lagi dinding sekat berdiri sendiri.
	#
	# Dinding sekat lama TIDAK BISA hidup berdampingan dengan meja: kasir harus
	# berdiri di sisi dapur meja (z_div - 0,555), sementara sekat menempati
	# z_div - 0,50 .. z_div - 0,40. Koridor yang tersisa hanya 0,125 m, padahal
	# badan karakter saja berdiameter 0,25 m — kasirnya tertanam di dalam tembok.
	# Menggeser sekat lebih ke belakang juga tidak bisa: kedalaman Ruko Tier 2
	# hanya 4,5 m, tidak muat untuk dinding + alat dapur + koridor + meja.
	var z: float = partition_z(t)
	if t < 5:
		return
	# Mega Bakery: dua kolom krem penanda alur, menempel dinding samping supaya
	# tidak pernah bertabrakan dengan bentang meja pembatas.
	var kolom_x: float = w * 0.5 - WALL_THICK - 0.30
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_cyl(parent, h, 0.130, 0.150, Palette.VANILLA_CREAM,
			Vector3(sx * kolom_x, h * 0.5, z))


## Satu bidang dinding bernama.
static func _wall(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mi: MeshInstance3D = _box(parent, size, color, pos, Vector3.ZERO, 0.95)
	mi.name = node_name
	return mi


## Jendela kayu + tirai gingham pastel (GDD 4.1). `yaw` 0 = menempel dinding
## belakang menghadap +Z; `yaw` 90 = dinding kiri menghadap +X.
static func _cozy_window(parent: Node3D, index: int, pos: Vector3, yaw: float, w: float, h: float) -> Node3D:
	var win := Node3D.new()
	win.name = "Window%d" % index
	parent.add_child(win)
	win.position = pos
	win.rotation_degrees = Vector3(0.0, yaw, 0.0)

	var frame: Color = Palette.PINE_WOOD.darkened(0.2)
	var bar: float = 0.07
	# Kaca: sedikit emisi supaya terbaca sebagai cahaya sore di luar jendela.
	var glass: MeshInstance3D = _box(win, Vector3(w - bar, h - bar, 0.02), Palette.GOLDEN_HOUR, Vector3(0.0, 0.0, 0.01))
	_set_glow(glass, Palette.GOLDEN_HOUR, 0.85)

	_box(win, Vector3(w, bar, 0.06), frame, Vector3(0.0, h * 0.5 - bar * 0.5, 0.02))
	_box(win, Vector3(w, bar, 0.06), frame, Vector3(0.0, -h * 0.5 + bar * 0.5, 0.02))
	_box(win, Vector3(bar, h, 0.06), frame, Vector3(-w * 0.5 + bar * 0.5, 0.0, 0.02))
	_box(win, Vector3(bar, h, 0.06), frame, Vector3(w * 0.5 - bar * 0.5, 0.0, 0.02))
	_box(win, Vector3(0.035, h - bar, 0.05), frame, Vector3(0.0, 0.0, 0.025))
	_box(win, Vector3(w - bar, 0.035, 0.05), frame, Vector3(0.0, 0.0, 0.025))
	# Ambang jendela menjorok ke dalam ruangan.
	_box(win, Vector3(w + 0.10, 0.045, 0.12), Palette.PINE_WOOD, Vector3(0.0, -h * 0.5 - 0.02, 0.06))

	# Batang tirai + dua helai kain gingham kotak-kotak pastel.
	_cyl(win, w + 0.14, 0.014, 0.014, METAL_COPPER, Vector3(0.0, h * 0.5 + 0.06, 0.07), Vector3(0.0, 0.0, 90.0))
	var curtain_w: float = w * 0.34
	var curtain_h: float = h * 0.92
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		var cloth: MeshInstance3D = _checker_plane(curtain_w, curtain_h, 0.10, Palette.GINGHAM_A, Palette.GINGHAM_B, false)
		cloth.name = "Curtain%d" % i
		ProceduralMeshFactory.attach(win, cloth, Vector3(sx * (w * 0.5 - curtain_w * 0.5 + 0.02), h * 0.5 - curtain_h * 0.5 - 0.02, 0.07))
	return win


## Jam dinding bandul kayu (GDD 4.1). Anak Node3D "Pendulum" berporos di puncak
## bandul sehingga bisa diayun pelan oleh sistem lain.
static func _wall_clock(parent: Node3D, pos: Vector3) -> Node3D:
	var clock := Node3D.new()
	clock.name = "Clock"
	parent.add_child(clock)
	clock.position = pos

	var wood: Color = Palette.PINE_WOOD.darkened(0.25)
	_slab(clock, Vector3(0.17, 0.28, 0.07), 0.015, wood, Vector3(0.0, 0.0, 0.035))
	_box(clock, Vector3(0.20, 0.030, 0.09), wood.darkened(0.15), Vector3(0.0, 0.155, 0.040))
	_box(clock, Vector3(0.20, 0.025, 0.09), wood.darkened(0.15), Vector3(0.0, -0.150, 0.040))

	_cyl(clock, 0.016, 0.062, 0.062, Palette.FLOUR_WHITE, Vector3(0.0, 0.070, 0.075), Vector3(90.0, 0.0, 0.0))
	_box(clock, Vector3(0.010, 0.042, 0.006), Palette.DARK_CHOCOLATE, Vector3(0.0, 0.088, 0.083))
	_box(clock, Vector3(0.034, 0.009, 0.006), Palette.DARK_CHOCOLATE, Vector3(0.016, 0.070, 0.083))
	_box(clock, Vector3(0.006, 0.006, 0.004), Palette.CARAMEL, Vector3(0.0, 0.118, 0.083))

	var pendulum := Node3D.new()
	pendulum.name = "Pendulum"
	clock.add_child(pendulum)
	pendulum.position = Vector3(0.0, 0.020, 0.072)
	_box(pendulum, Vector3(0.008, 0.110, 0.006), METAL_COPPER, Vector3(0.0, -0.055, 0.0))
	_cyl(pendulum, 0.010, 0.030, 0.030, Palette.GOLD_STAR, Vector3(0.0, -0.118, 0.0), Vector3(90.0, 0.0, 0.0))
	return clock


## Wadah satu perabot. Tier disimpan sebagai metadata, bukan ditempel ke nama:
## ShopWorld menamai ulang node ini ("Mixer0", "Oven1", ...) saat memasangnya.
static func _root(node_name: String, tier: int) -> Node3D:
	var n := Node3D.new()
	n.name = node_name
	n.set_meta("tier", tier)
	return n


# ---------------------------------------------------------------------------
# Pembungkus primitif.
#
# ProceduralMeshFactory yang membuat mesh-nya; fungsi-fungsi di bawah hanya
# menempelkannya ke induk pada posisi dan rotasi tertentu. Dipisah supaya badan
# setiap build_*() terbaca sebagai daftar bentuk, bukan sebagai rangkaian
# new()/add_child()/position= yang menenggelamkan bentuknya sendiri.
# ---------------------------------------------------------------------------

static func _box(parent: Node3D, size: Vector3, color: Color, pos: Vector3,
		rot := Vector3.ZERO, rough := 0.85) -> MeshInstance3D:
	var mi: MeshInstance3D = ProceduralMeshFactory.box(size, color, rough)
	ProceduralMeshFactory.attach(parent, mi, pos, rot)
	return mi


## Kotak bersudut tumpul (GDD 4.1: bentuk membulat, tidak ada sudut tajam).
static func _slab(parent: Node3D, size: Vector3, bevel: float, color: Color,
		pos: Vector3, rot := Vector3.ZERO, rough := 0.85) -> MeshInstance3D:
	var mi: MeshInstance3D = ProceduralMeshFactory.rounded_slab(size, bevel, color)
	_set_rough(mi, rough)
	ProceduralMeshFactory.attach(parent, mi, pos, rot)
	return mi


static func _cyl(parent: Node3D, h: float, rt: float, rb: float, color: Color,
		pos: Vector3, rot := Vector3.ZERO, rough := 0.85) -> MeshInstance3D:
	var mi: MeshInstance3D = ProceduralMeshFactory.cylinder(h, rt, rb, color, rough)
	ProceduralMeshFactory.attach(parent, mi, pos, rot)
	return mi


static func _sph(parent: Node3D, r: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = ProceduralMeshFactory.sphere(r, color)
	ProceduralMeshFactory.attach(parent, mi, pos)
	return mi


static func _tor(parent: Node3D, inner: float, outer: float, color: Color,
		pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = ProceduralMeshFactory.torus(inner, outer, color)
	ProceduralMeshFactory.attach(parent, mi, pos)
	return mi


static func _lathe(parent: Node3D, profile: PackedVector2Array, segments: int,
		color: Color, pos: Vector3) -> MeshInstance3D:
	var mi: MeshInstance3D = ProceduralMeshFactory.lathe(profile, segments, color)
	ProceduralMeshFactory.attach(parent, mi, pos)
	return mi


static func _set_rough(mi: MeshInstance3D, rough: float) -> void:
	var mat := mi.material_override as StandardMaterial3D
	if mat != null:
		mat.roughness = rough


## Membuat satu permukaan MENYALA lembut. Dipakai untuk kaca oven, layar kasir,
## lis LED tier tinggi, dan jendela sore.
static func _set_glow(mi: MeshInstance3D, color: Color, energy: float) -> void:
	if mi == null:
		return
	var mat := mi.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy


## Pencahayaan ruangan: satu matahari sore yang menembus jendela belakang, plus
## lampu gantung hangat di langit-langit.
##
## DirectionalLight3D-nya wajib ada — suite tes memeriksanya sebagai tanda
## ruangan benar-benar terbangun lengkap, bukan cuma lantai dan dinding.
static func _room_lighting(parent: Node3D, w: float, d: float, h: float) -> void:
	var matahari := DirectionalLight3D.new()
	matahari.name = "SunLight"
	parent.add_child(matahari)
	matahari.position = Vector3(0.0, h + 1.2, -d * 0.5)
	# Menukik dari arah jendela belakang, sedikit menyerong supaya perabot
	# punya sisi terang dan sisi teduh alih-alih rata tanpa bentuk.
	matahari.rotation_degrees = Vector3(-52.0, 24.0, 0.0)
	matahari.light_color = Palette.GOLDEN_HOUR
	matahari.light_energy = 1.15
	matahari.light_specular = 0.2
	matahari.shadow_enabled = false

	var isi := OmniLight3D.new()
	isi.name = "FillLight"
	parent.add_child(isi)
	isi.position = Vector3(0.0, h * 0.92, 0.0)
	isi.light_color = Palette.GOLDEN_HOUR
	isi.light_energy = 0.55
	isi.light_specular = 0.05
	isi.omni_range = maxf(w, d) * 0.9
	isi.omni_attenuation = 1.2
	isi.shadow_enabled = false

	# Dua lampu gantung hangat: satu di dapur, satu di area toko.
	_warm_lamp(parent, Vector3(0.0, h - 0.25, -d * 0.25), 0.9, maxf(w, d) * 0.55)
	_warm_lamp(parent, Vector3(0.0, h - 0.25, d * 0.25), 0.9, maxf(w, d) * 0.55)


## WorldEnvironment hangat khas sore (GDD 4.1 "cozy").
##
## Tanpa bayangan dan tanpa SSAO: target render adalah Compatibility/WebGL 2.0
## di ponsel kelas bawah (GDD 12.2), dan efek layar penuh yang mahal adalah hal
## pertama yang membuat frame-nya jatuh di sana.
static func build_environment() -> WorldEnvironment:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Palette.BG
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Palette.GOLDEN_HOUR
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_white = 1.2

	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	return we


## `size` = (lebar, TINGGI PERMUKAAN, kedalaman).
static func _work_table(parent: Node3D, size: Vector3, top_color: Color, leg_color: Color, origin := Vector3.ZERO) -> void:
	var top_th: float = 0.05
	_slab(parent, Vector3(size.x, top_th, size.z), 0.015, top_color, origin + Vector3(0.0, size.y - top_th * 0.5, 0.0))
	var lx: float = size.x * 0.5 - 0.055
	var lz: float = size.z * 0.5 - 0.055
	var leg_h: float = size.y - top_th
	for i in 4:
		var sx: float = -1.0 if i < 2 else 1.0
		var sz: float = -1.0 if (i % 2) == 0 else 1.0
		_cyl(parent, leg_h, 0.026, 0.030, leg_color, origin + Vector3(sx * lx, leg_h * 0.5, sz * lz))
	_box(parent, Vector3(size.x - 0.13, 0.035, 0.035), leg_color, origin + Vector3(0.0, 0.130, -lz))
	_box(parent, Vector3(size.x - 0.13, 0.035, 0.035), leg_color, origin + Vector3(0.0, 0.130, lz))


## Poros pengocok. WAJIB bernama "Whisk": mixer_spin() memutarnya pada sumbu Y
## sekaligus mengorbitkannya sejauh 0,035 m, jadi mangkuk harus lebih lega dari
## radius loop + radius orbit.
static func _whisk_pivot(parent: Node3D, pos: Vector3) -> Node3D:
	var whisk := Node3D.new()
	whisk.name = "Whisk"
	parent.add_child(whisk)
	whisk.position = pos
	return whisk


## Kurungan kawat pengocok balon: `count` cincin berdiri yang saling menyilang.
## Torus default rebah di bidang XZ; diputar 90 derajat pada X agar berdiri,
## lalu di-yaw merata, dan dipanjangkan pada sumbu lokal Z (yang setelah rotasi
## menjadi sumbu tegak) supaya berbentuk lonjong seperti pengocok sungguhan.
static func _balloon_loops(whisk: Node3D, count: int, inner: float, outer: float, color: Color, y_offset: float, stretch: float) -> void:
	var n: int = maxi(1, count)
	for i in n:
		var loop: MeshInstance3D = _tor(whisk, inner, outer, color, Vector3(0.0, y_offset, 0.0))
		loop.rotation_degrees = Vector3(90.0, float(i) * (180.0 / float(n)), 0.0)
		loop.scale = Vector3(1.0, 1.0, stretch)


## Pintu oven berengsel di TEPI BAWAH.
##
## ProceduralAnimationSystem.oven_door() menganimasikan "rotation:x" ke arah
## NEGATIF (rest_x - 1,62 rad). Pada poros tanpa rotasi, putaran negatif akan
## melempar pintu ke -Z alias masuk ke dalam oven. Karena itu poros diberi yaw
## 180 derajat: sumbu X lokalnya terbalik, sehingga putaran negatif membuat
## daun pintu berayun turun keluar ke +Z persis seperti oven sungguhan.
## Konsekuensinya seluruh geometri anak dicerminkan pada X dan Z.
static func _oven_door(parent: Node3D, node_name: String, width: float, height: float, hinge: Vector3, frame: Color, handle: Color, bar: float) -> Node3D:
	var door := Node3D.new()
	door.name = node_name
	parent.add_child(door)
	door.position = hinge
	door.rotation_degrees = Vector3(0.0, 180.0, 0.0)
	door.set_meta("hinge_axis", "x")
	door.set_meta("open_sign", -1.0)

	var depth: float = 0.045
	# Empat batang bingkai; bagian tengah sengaja kosong agar kaca "Window"
	# di badan oven tetap terlihat saat pintu tertutup.
	_box(door, Vector3(width, bar, depth), frame, Vector3(0.0, bar * 0.5, 0.0))
	_box(door, Vector3(width, bar, depth), frame, Vector3(0.0, height - bar * 0.5, 0.0))
	_box(door, Vector3(bar, height, depth), frame, Vector3(-width * 0.5 + bar * 0.5, height * 0.5, 0.0))
	_box(door, Vector3(bar, height, depth), frame, Vector3(width * 0.5 - bar * 0.5, height * 0.5, 0.0))

	# Gagang batang mendatar (lokal -Z = sisi luar oven setelah yaw 180).
	_cyl(door, width * 0.72, 0.016, 0.016, handle, Vector3(0.0, height - bar * 0.5, -0.055), Vector3(0.0, 0.0, 90.0))
	for i in 2:
		var sx: float = -1.0 if i == 0 else 1.0
		_box(door, Vector3(0.030, 0.030, 0.060), handle, Vector3(sx * width * 0.33, height - bar * 0.5, -0.032))
	return door


## Kaca gelap jendela oven, sedikit memantulkan bara di dalam.
static func _oven_window(parent: Node3D, node_name: String, size: Vector2, pos: Vector3) -> MeshInstance3D:
	var pane: MeshInstance3D = _box(parent, Vector3(size.x, size.y, 0.020), DARK_GLASS, pos, Vector3.ZERO, 0.20)
	pane.name = node_name
	var mat: StandardMaterial3D = ProceduralMeshFactory.material(DARK_GLASS, 0.20, 0.10, Palette.GOLDEN_CRUST)
	mat.emission_energy_multiplier = 0.30
	pane.material_override = mat
	return pane


## Bara oven: OmniLight3D hangat berenergi rendah, tanpa bayangan.
static func _oven_glow(parent: Node3D, pos: Vector3, energy: float, radius: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "GlowLight"
	parent.add_child(lamp)
	lamp.position = pos
	lamp.light_color = Palette.WARMER_LAMP
	lamp.light_energy = energy
	lamp.light_specular = 0.15
	lamp.omni_range = radius
	lamp.omni_attenuation = 1.5
	lamp.shadow_enabled = false
	return lamp


## Lampu penghangat etalase #FFAA44 (GDD 4.1), lembut dan tanpa bayangan.
static func _warm_lamp(parent: Node3D, pos: Vector3, energy: float, radius: float) -> OmniLight3D:
	var lamp := OmniLight3D.new()
	lamp.name = "WarmLamp"
	parent.add_child(lamp)
	lamp.position = pos
	lamp.light_color = Palette.WARMER_LAMP
	lamp.light_energy = energy
	lamp.light_specular = 0.1
	lamp.omni_range = radius
	lamp.omni_attenuation = 1.4
	lamp.shadow_enabled = false
	return lamp


## Kotak kaca etalase: empat tiang sudut, rangka atas, dan panel kaca tembus
## pandang (alpha rendah otomatis mengaktifkan transparansi di material()).
static func _glass_case(parent: Node3D, width: float, depth: float, height: float, base_y: float, frame_color: Color, frame_th: float) -> void:
	var hx: float = width * 0.5 - frame_th * 0.5
	var hz: float = depth * 0.5 - frame_th * 0.5
	for i in 4:
		var sx: float = -1.0 if i < 2 else 1.0
		var sz: float = -1.0 if (i % 2) == 0 else 1.0
		_box(parent, Vector3(frame_th, height, frame_th), frame_color, Vector3(sx * hx, base_y + height * 0.5, sz * hz), Vector3.ZERO, 0.4)
	_box(parent, Vector3(width, frame_th, depth), frame_color, Vector3(0.0, base_y + height - frame_th * 0.5, 0.0), Vector3.ZERO, 0.4)

	var glass := Color(GLASS_PANE.r, GLASS_PANE.g, GLASS_PANE.b, GLASS_ALPHA)
	var inner_h: float = height - frame_th * 2.0
	_box(parent, Vector3(width - frame_th * 2.0, inner_h, 0.012), glass, Vector3(0.0, base_y + height * 0.5, depth * 0.5 - 0.016), Vector3.ZERO, 0.12)
	_box(parent, Vector3(width - frame_th * 2.0, inner_h, 0.012), glass, Vector3(0.0, base_y + height * 0.5, -depth * 0.5 + 0.016), Vector3.ZERO, 0.12)
	for i in 2:
		var sx2: float = -1.0 if i == 0 else 1.0
		_box(parent, Vector3(0.012, inner_h, depth - frame_th * 2.0), glass, Vector3(sx2 * (width * 0.5 - 0.016), base_y + height * 0.5, 0.0), Vector3.ZERO, 0.12)
	_box(parent, Vector3(width - frame_th * 2.0, 0.012, depth - frame_th * 2.0), glass, Vector3(0.0, base_y + height - frame_th - 0.008, 0.0), Vector3.ZERO, 0.12)


## Posisi X slot ke-`i` dari `count` slot yang dijajarkan sepanjang `span`.
static func _slot_x(i: int, count: int, span: float) -> float:
	if count <= 1:
		return 0.0
	return -span * 0.5 + span * (float(i) + 0.5) / float(count)


## Menambahkan "Slot0".."Slot5" (GameConfig.SLOTS_PER_RACK) berjajar kiri ke
## kanan di sisi depan rak. Roti dari BreadFactory di-parent ke node-node ini.
static func _add_slots(parent: Node3D, y: float, z: float, span: float) -> void:
	var count: int = maxi(1, GameConfig.SLOTS_PER_RACK)
	for i in count:
		var slot := Node3D.new()
		slot.name = "Slot%d" % i
		parent.add_child(slot)
		slot.position = Vector3(_slot_x(i, count, span), y, z)


## Bidang papan catur dari SurfaceTool: satu mesh dengan sedikit surface, jadi
## lantai terakota dan tirai gingham tetap murah dalam draw call.
## `horizontal` true = bidang XZ (lantai, kain meja); false = bidang XY (tirai).
##
## `split_v` membelah bidang menjadi dua zona pada sumbu kedua (z untuk bidang
## mendatar, y untuk bidang tegak): petak yang pusatnya di bawah `split_v`
## memakai pasangan warna `color_c`/`color_d`. Nilai bawaan -INF berarti tidak
## ada pembelahan dan hasilnya tetap dua surface persis seperti sebelumnya.
static func _checker_plane(width: float, height: float, cell_target: float, color_a: Color, color_b: Color, horizontal: bool, split_v: float = -INF, color_c: Color = Color.BLACK, color_d: Color = Color.BLACK) -> MeshInstance3D:
	var cell: float = maxf(cell_target, 0.02)
	var cols: int = maxi(2, int(round(width / cell)))
	var rows: int = maxi(2, int(round(height / cell)))
	var cw: float = width / float(cols)
	var ch: float = height / float(rows)
	var normal: Vector3 = Vector3.UP if horizontal else Vector3.BACK

	var zone_colors: Array[Color] = [color_a, color_b, color_c, color_d]
	var mesh := ArrayMesh.new()
	# Empat pass: zona atas genap, zona atas ganjil, zona bawah genap, zona
	# bawah ganjil. Pass yang tidak menghasilkan petak dilewati, jadi bidang
	# tanpa pembelahan tetap menghasilkan dua surface saja.
	for pass_idx in 4:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var emitted: int = 0
		for r in rows:
			for c in cols:
				var u0: float = -width * 0.5 + float(c) * cw
				var u1: float = u0 + cw
				var v0: float = -height * 0.5 + float(r) * ch
				var v1: float = v0 + ch
				# Zona ditentukan dari PUSAT petak supaya garis batas jatuh rapi
				# di tepi ubin terdekat, bukan memotong satu ubin jadi dua warna.
				var lower: bool = (v0 + v1) * 0.5 < split_v
				var want: int = (2 if lower else 0) + ((r + c) % 2)
				if want != pass_idx:
					continue
				emitted += 1
				var p00: Vector3 = Vector3(u0, 0.0, v0) if horizontal else Vector3(u0, v0, 0.0)
				var p10: Vector3 = Vector3(u1, 0.0, v0) if horizontal else Vector3(u1, v0, 0.0)
				var p11: Vector3 = Vector3(u1, 0.0, v1) if horizontal else Vector3(u1, v1, 0.0)
				var p01: Vector3 = Vector3(u0, 0.0, v1) if horizontal else Vector3(u0, v1, 0.0)
				_checker_tri(st, p00, p01, p11, normal)
				_checker_tri(st, p00, p11, p10, normal)
		if emitted == 0:
			continue
		var mat: StandardMaterial3D = ProceduralMeshFactory.material(zone_colors[pass_idx], 0.94)
		# Dua sisi: lantai dan tirai hanya selembar, jadi urutan winding
		# tidak boleh menentukan terlihat atau tidaknya permukaan.
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		st.set_material(mat)
		st.commit(mesh)

	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.name = "Checker"
	return mi


## Satu segitiga papan catur dengan normal eksplisit (tanpa generate_normals()
## supaya dua surface tidak saling mempengaruhi).
static func _checker_tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, normal: Vector3) -> void:
	st.set_normal(normal)
	st.add_vertex(a)
	st.set_normal(normal)
	st.add_vertex(b)
	st.set_normal(normal)
	st.add_vertex(c)
