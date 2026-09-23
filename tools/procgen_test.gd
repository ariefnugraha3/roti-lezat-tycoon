extends Node
## Tes struktural lapisan procedural generation.
##
## Bukan sekadar cek compile: setiap factory benar-benar DIJALANKAN, lalu hasilnya
## diperiksa terhadap kontrak (docs/ARCHITECTURE.md bagian 8) dan anggaran geometri
## GDD 12.2 (500-2000 tris per objek rakitan).
##
## Jalankan: godot --headless --path . res://tools/procgen_test.tscn
## (harus lewat scene, bukan --script: mode --script tidak menyediakan autoload)

## GDD 12.2: "jumlah poligon terkontrol (500 - 2.000 tris per perakitan objek)".
const TRI_BUDGET: int = 2000

const QUALITIES: Array[String] = [
	"mentah", "prima", "normal", "dingin", "hampir_gosong", "gosong",
]

const ICON_NAMES: Array[String] = [
	"coin", "star", "clock", "bolt", "bread", "bag", "cart", "people", "heart",
	"angry", "sad", "happy", "rain", "sun", "party", "bubble", "check", "cross",
	"plus", "minus", "warning", "fire", "box", "megaphone", "chef", "trophy",
	"note", "moon", "scooter", "hourglass",
	# Ikon kendali & sudut pandang HUD, dipakai tombol tanpa teks.
	"pause", "play", "kitchen", "shop", "frame",
	# Menu dalam permainan: roda gigi di HUD + keadaan suara.
	"gear", "sound", "mute",
]

const CHAR_NODES: Array[String] = [
	"Head", "Body", "ArmL", "ArmR", "LegL", "LegR", "Face", "Hat", "Apron",
]

var _fail: int = 0
var _pass: int = 0
var _max_bread_tris: int = 0
var _max_bread_id: String = ""
var _max_char_tris: int = 0
var _max_char_id: String = ""
var _max_equip_tris: int = 0
var _max_equip_id: String = ""


func _ready() -> void:
	print("=== TES STRUKTURAL PROCGEN ===")
	_test_mesh_primitives()
	_test_bread()
	_test_equipment()
	_test_characters()
	_test_player_visuals()
	_test_icons()
	_test_ui()
	_test_fx()
	_test_anim()
	_test_determinism()

	print("")
	print("=== PUNCAK ANGGARAN GEOMETRI (GDD 12.2, batas %d tris) ===" % TRI_BUDGET)
	print("  roti tertinggi    : %-28s %d tris" % [_max_bread_id, _max_bread_tris])
	print("  karakter tertinggi: %-28s %d tris" % [_max_char_id, _max_char_tris])
	print("  peralatan tertinggi: %-27s %d tris" % [_max_equip_id, _max_equip_tris])
	print("")
	print("=== HASIL ===")
	print("LULUS : %d" % _pass)
	print("GAGAL : %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("GAGAL  %s" % label)


func _node_ok(label: String, n: Variant) -> bool:
	var good: bool = n != null and n is Node3D
	_ok(label, good)
	return good


## Memeriksa anggaran tris dan membebaskan node agar tidak bocor.
func _budget(label: String, n: Node, kind: String, id: String) -> void:
	var tris: int = ProceduralMeshFactory.tri_count(n)
	_ok("%s punya geometri (tris > 0)" % label, tris > 0)
	_ok("%s dalam anggaran (%d <= %d)" % [label, tris, TRI_BUDGET], tris <= TRI_BUDGET)
	match kind:
		"bread":
			if tris > _max_bread_tris:
				_max_bread_tris = tris
				_max_bread_id = id
		"char":
			if tris > _max_char_tris:
				_max_char_tris = tris
				_max_char_id = id
		"equip":
			if tris > _max_equip_tris:
				_max_equip_tris = tris
				_max_equip_id = id
	n.free()


# --- A. Primitif -------------------------------------------------------------

func _test_mesh_primitives() -> void:
	print("\n-- ProceduralMeshFactory --")
	var c: Color = Color(0.8, 0.5, 0.2)
	var made: Array[Node] = [
		ProceduralMeshFactory.box(Vector3(0.2, 0.2, 0.2), c),
		ProceduralMeshFactory.cylinder(0.3, 0.1, 0.12, c),
		ProceduralMeshFactory.sphere(0.15, c),
		ProceduralMeshFactory.torus(0.05, 0.12, c),
		ProceduralMeshFactory.capsule(0.3, 0.1, c),
		ProceduralMeshFactory.rounded_slab(Vector3(0.4, 0.2, 0.3), 0.04, c),
	]
	var names: Array[String] = ["box", "cylinder", "sphere", "torus", "capsule", "rounded_slab"]
	for i in made.size():
		var n: Node = made[i]
		if _node_ok("%s() mengembalikan MeshInstance3D" % names[i], n):
			var tris: int = ProceduralMeshFactory.tri_count(n)
			_ok("%s() punya tris" % names[i], tris > 0)
			_ok("%s() hemat (<= 600 tris)" % names[i], tris <= 600)
		if n != null:
			n.free()

	# lathe() dengan profil yang menyentuh sumbu (kutub) tidak boleh bikin segitiga degenerate.
	var prof := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(0.10, 0.02), Vector2(0.12, 0.10), Vector2(0.0, 0.14),
	])
	var lathe_node: Node = ProceduralMeshFactory.lathe(prof, 10, c)
	if _node_ok("lathe() dengan kutub", lathe_node):
		_ok("lathe() punya tris", ProceduralMeshFactory.tri_count(lathe_node) > 0)
		lathe_node.free()

	var mat: StandardMaterial3D = ProceduralMeshFactory.material(c, 0.7, 0.0)
	_ok("material() mengembalikan StandardMaterial3D", mat != null)
	if mat != null:
		_ok("material() per-pixel shading", mat.shading_mode == BaseMaterial3D.SHADING_MODE_PER_PIXEL)

	var g: Node3D = ProceduralMeshFactory.group("Uji")
	_ok("group() bernama benar", g != null and g.name == "Uji")
	if g != null:
		g.free()


# --- B. Roti -----------------------------------------------------------------

func _test_bread() -> void:
	print("\n-- BreadFactory (23 resep x 6 kualitas) --")
	for rid in RecipeDB.ids():
		for q in QUALITIES:
			var n: Node3D = BreadFactory.build(rid, q)
			if not _node_ok("roti %s/%s" % [rid, q], n):
				continue
			if q == "prima":
				_budget("roti %s" % rid, n, "bread", rid)
			else:
				n.free()

	# Kualitas harus mengubah warna kerak secara kasatmata (GDD 4.2).
	var raw: Color = BreadFactory.bake_color(BreadFactory.quality_shade("mentah"))
	var done: Color = BreadFactory.bake_color(BreadFactory.quality_shade("prima"))
	var burnt: Color = BreadFactory.bake_color(BreadFactory.quality_shade("gosong"))
	_ok("mentah lebih terang dari prima", raw.get_luminance() > done.get_luminance())
	_ok("gosong lebih gelap dari prima", burnt.get_luminance() < done.get_luminance())

	for fn in ["paper_bag", "gift_box"]:
		var n: Node3D = BreadFactory.build_paper_bag() if fn == "paper_bag" else BreadFactory.build_gift_box()
		if _node_ok("kemasan %s" % fn, n):
			_ok("%s punya geometri" % fn, ProceduralMeshFactory.tri_count(n) > 0)
			n.free()


# --- C. Peralatan ------------------------------------------------------------

func _test_equipment() -> void:
	print("\n-- EquipmentFactory --")
	for tier in range(1, 6):
		var mixer: Node3D = EquipmentFactory.build_mixer(tier)
		if _node_ok("mixer T%d" % tier, mixer):
			_ok("mixer T%d punya node 'Whisk'" % tier, mixer.get_node_or_null("Whisk") != null)
			_budget("mixer T%d" % tier, mixer, "equip", "mixer T%d" % tier)

		var oven: Node3D = EquipmentFactory.build_oven(tier)
		if _node_ok("oven T%d" % tier, oven):
			_ok("oven T%d punya node 'Door'" % tier, oven.get_node_or_null("Door") != null)
			_ok("oven T%d punya node 'Window'" % tier, oven.get_node_or_null("Window") != null)
			var glow: Node = oven.get_node_or_null("GlowLight")
			_ok("oven T%d punya OmniLight3D 'GlowLight'" % tier, glow != null and glow is OmniLight3D)
			_budget("oven T%d" % tier, oven, "equip", "oven T%d" % tier)

		var disp: Node3D = EquipmentFactory.build_display(tier)
		if _node_ok("display T%d" % tier, disp):
			for s in GameConfig.SLOTS_PER_RACK:
				_ok("display T%d punya 'Slot%d'" % [tier, s],
					disp.get_node_or_null("Slot%d" % s) != null)
			_budget("display T%d" % tier, disp, "equip", "display T%d" % tier)

		# Gudang Penyimpanan diparameteri tier LOKASI, jadi `tier` di sini berarti
		# tier toko -- bukan tier alat seperti tiga pemeriksaan di atas.
		var gudang: Node3D = EquipmentFactory.build_storage(tier)
		# Dimasukkan ke pohon lebih dulu: di luar pohon, global_transform
		# mengembalikan matriks satuan, dan seluruh daun pintu akan terbaca
		# bertumpuk di titik nol.
		if gudang != null:
			add_child(gudang)
		if _node_ok("gudang T%d" % tier, gudang):
			_ok("gudang T%d punya daun pintu kulkas 'Pintu'" % tier,
				gudang.get_node_or_null("Pintu") != null)
			# Bentuk yang diminta: kulkas dan lemari berdiri BERSEBELAHAN, dan
			# kedua pintunya menghadap sisi depan.
			_ok("gudang T%d punya daun pintu lemari 'PintuLemari'" % tier,
				gudang.get_node_or_null("PintuLemari") != null)
			_cek_pintu_depan(tier, gudang)
			_budget("gudang T%d" % tier, gudang, "equip", "gudang T%d" % tier)

		var counter: Node3D = EquipmentFactory.build_counter(tier)
		if _node_ok("counter T%d" % tier, counter):
			_ok("counter T%d punya penanda 'Tablet'" % tier,
				counter.get_node_or_null("Tablet") != null)
			_budget("counter T%d" % tier, counter, "equip", "counter T%d" % tier)

		var room: Node3D = EquipmentFactory.build_room(tier)
		if _node_ok("ruangan T%d" % tier, room):
			# Ruangan adalah rakitan besar; hanya dicek punya geometri dan cahaya hangat.
			_ok("ruangan T%d punya geometri" % tier, ProceduralMeshFactory.tri_count(room) > 0)
			_ok("ruangan T%d punya DirectionalLight3D" % tier, _find_type(room, "DirectionalLight3D"))
			_check_floor_tile(tier, room)
			room.free()

	_check_footprints()

	var pickup: Node3D = EquipmentFactory.build_pickup_counter()
	if _node_ok("meja khusus ojol", pickup):
		_budget("meja ojol", pickup, "equip", "pickup_counter")

	var tablet: Node3D = EquipmentFactory.build_tablet()
	if _node_ok("tablet kasir", tablet):
		_budget("tablet", tablet, "equip", "tablet")

	var env: WorldEnvironment = EquipmentFactory.build_environment()
	_ok("build_environment() mengembalikan WorldEnvironment", env != null)
	if env != null:
		_ok("environment punya Environment", env.environment != null)
		env.free()


## Seluruh daun pintu gudang wajib menghadap SISI DEPAN (+Z) dan berjajar
## bersebelahan pada sumbu X. `gudang` harus SUDAH berada di dalam pohon.
##
## Ini yang menjaga bentuk yang diminta tetap begitu: kulkas dan lemari berdiri
## sebaris dengan kedua pintunya di muka, bukan bertumpuk depan-belakang di mana
## daun baris belakang mustahil terlihat -- apalagi terjangkau -- dari kamera
## isometrik.
func _cek_pintu_depan(tier: int, gudang: Node3D) -> void:
	var rentang: Array = []
	for c in gudang.get_children():
		var d := c as Node3D
		if d == null or not String(d.name).begins_with("Pintu"):
			continue
		_ok("gudang T%d daun '%s' bergantung di muka perabot (z = %.3f)"
			% [tier, d.name, d.position.z], d.position.z > 0.0)

		var b: AABB = _world_aabb_of(d)
		# Daun yang menghadap depan selalu JAUH lebih lebar daripada tebalnya.
		# Daun yang menghadap samping akan membalik perbandingan ini.
		_ok("gudang T%d daun '%s' menghadap depan (lebar %.2f m vs tebal %.2f m)"
			% [tier, d.name, b.size.x, b.size.z], b.size.x > b.size.z * 2.0)

		# Arah ayun dibawa metadata; titik ujung daun harus BERGERAK ke +Z.
		var tanda: float = float(d.get_meta("open_sign", 0.0))
		_ok("gudang T%d daun '%s' membawa open_sign" % [tier, d.name], tanda != 0.0)
		var ujung := Vector3(b.position.x if tanda > 0.0 else b.position.x + b.size.x,
			0.0, d.position.z)
		var lengan: Vector3 = ujung - Vector3(d.position.x, 0.0, d.position.z)
		var ayun: Vector3 = lengan.rotated(Vector3.UP, tanda * 1.0)
		_ok("gudang T%d daun '%s' berayun KELUAR ke depan" % [tier, d.name],
			ayun.z > lengan.z + 0.05)

		rentang.append([b.position.x, b.position.x + b.size.x, String(d.name)])

	_ok("gudang T%d punya minimal dua daun pintu (ada %d)"
		% [tier, rentang.size()], rentang.size() >= 2)

	for i in rentang.size():
		for j in range(i + 1, rentang.size()):
			var a: Array = rentang[i]
			var b2: Array = rentang[j]
			_ok("gudang T%d daun '%s' dan '%s' bersebelahan, tidak bertumpuk"
				% [tier, String(a[2]), String(b2[2])],
				float(a[1]) <= float(b2[0]) + 0.001 or float(b2[1]) <= float(a[0]) + 0.001)


## Ukuran ubin lantai diukur dari GEOMETRI yang benar-benar terbangun, bukan
## dari konstanta FLOOR_TILE.
##
## Keduanya tidak selalu sama: _checker_plane() membulatkan jumlah ubin lalu
## meregangkannya agar pas selebar ruangan, jadi konstanta 0,50 m bisa saja
## terbit sebagai ubin 0,487 m tanpa ada satu pun angka yang terlihat keliru.
## Yang diuji di sini adalah ubin yang akan dilihat pemain.
func _check_floor_tile(tier: int, room: Node3D) -> void:
	var floor_node := room.get_node_or_null("Floor") as MeshInstance3D
	var ada: bool = floor_node != null and floor_node.mesh != null
	_ok("ruangan T%d punya mesh 'Floor'" % tier, ada)
	if not ada:
		return
	var arrays: Array = floor_node.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var cukup: bool = verts.size() >= 6
	_ok("T%d lantai punya simpul cukup untuk satu ubin" % tier, cukup)
	if not cukup:
		return

	# Satu ubin = dua segitiga = enam simpul pertama pada surface.
	var kotak := AABB(verts[0], Vector3.ZERO)
	for i in 6:
		kotak = kotak.expand(verts[i])
	var sisi_x: float = kotak.size.x
	var sisi_z: float = kotak.size.z

	# TEPAT 50 x 50 cm di kelima tier, bukan sekadar mendekati. Inilah satu-satunya
	# alasan setiap sisi ROOM_WIDTHS/ROOM_DEPTHS wajib kelipatan FLOOR_TILE:
	# begitu ada sisi yang bukan kelipatan, _checker_plane() meregangkan ubinnya
	# dan seluruh kisi penempatan perabot ikut meleset.
	var tile: float = EquipmentFactory.FLOOR_TILE
	_ok("T%d ubin tepat %.0f x %.0f cm (dapat %.2f x %.2f cm)"
		% [tier, tile * 100.0, tile * 100.0, sisi_x * 100.0, sisi_z * 100.0],
		absf(sisi_x - tile) < 0.0005 and absf(sisi_z - tile) < 0.0005)

	# Jumlah ubin yang terbangun harus sama dengan yang dijanjikan kisi.
	var kolom: int = int(round(EquipmentFactory.room_width(tier) / tile))
	var baris: int = int(round(EquipmentFactory.room_depth(tier) / tile))
	_ok("T%d jumlah ubin %dx%d cocok dengan kisi" % [tier, kolom, baris],
		EquipmentFactory.floor_cols(tier) == kolom
		and EquipmentFactory.floor_rows(tier) == baris)
	_ok("T%d sisi ruangan kelipatan ubin" % tier,
		absf(EquipmentFactory.room_width(tier) - float(kolom) * tile) < 0.0005
		and absf(EquipmentFactory.room_depth(tier) - float(baris) * tile) < 0.0005)

	print("  T%d: ubin lantai %.1f x %.1f cm, kisi %d x %d petak"
		% [tier, sisi_x * 100.0, sisi_z * 100.0, kolom, baris])


## Setiap perabot wajib MUAT di jejak lantai resminya setelah diskalakan.
##
## Jejak bukan sekadar label di tabel: ia janji kepada Mode Dekorasi bahwa rak
## 2x1 benar-benar cukup dua petak. Kalau mesh-nya ternyata melimpah keluar,
## rak akan menembus perabot di petak sebelah — dan tidak ada satu pun angka
## posisi yang terlihat keliru.
##
## Penskalaan juga dijaga tetap wajar: jejak yang salah pilih akan terlihat di
## sini sebagai mesh yang harus dikecilkan setengah atau digandakan dua kali.
const SKALA_MIN: float = 0.60
const SKALA_MAKS: float = 1.60

func _check_footprints() -> void:
	print("
-- Jejak Lantai Perabot --")
	var tile: float = EquipmentFactory.FLOOR_TILE
	for kind in ["mixer", "oven", "display", "storage"]:
		for tier in range(1, 6):
			var n: Node3D = null
			match kind:
				"mixer": n = EquipmentFactory.build_mixer(tier)
				"oven": n = EquipmentFactory.build_oven(tier)
				"display": n = EquipmentFactory.build_display(tier)
				"storage": n = EquipmentFactory.build_storage(tier)
			if n == null:
				_ok("%s T%d terbangun" % [kind, tier], false)
				continue
			add_child(n)
			var jejak: Vector2i = EquipmentFactory.footprint(kind, tier)
			var skala: float = EquipmentFactory.fit_to_footprint(n, kind, tier)
			var batas: Vector2 = EquipmentFactory.footprint_meters(jejak)
			var b: AABB = _world_aabb_of(n)

			_ok("%s T%d muat di jejak %dx%d (%.2f x %.2f <= %.2f x %.2f m)"
				% [kind, tier, jejak.x, jejak.y, b.size.x, b.size.z, batas.x, batas.y],
				b.size.x <= batas.x + 0.001 and b.size.z <= batas.y + 0.001)
			_ok("%s T%d jejak minimal satu ubin" % [kind, tier],
				jejak.x >= 1 and jejak.y >= 1)
			_ok("%s T%d penskalaan wajar (%.2fx)" % [kind, tier, skala],
				skala >= SKALA_MIN and skala <= SKALA_MAKS)
			# Jejak diputar 90 derajat hanya menukar sisi, tidak menambah petak.
			var putar: Vector2i = EquipmentFactory.footprint_rotated(kind, tier, 90)
			_ok("%s T%d jejak putar = sisi tertukar" % [kind, tier],
				putar == Vector2i(jejak.y, jejak.x))

			print("  %-8s T%d: jejak %d x %d petak (%d x %d cm), mesh %.2f x %.2f m, skala %.2fx"
				% [kind, tier, jejak.x, jejak.y,
					int(round(float(jejak.x) * tile * 100.0)),
					int(round(float(jejak.y) * tile * 100.0)),
					b.size.x, b.size.z, skala])
			n.free()


## AABB gabungan seluruh mesh keturunan, dalam koordinat dunia.
func _world_aabb_of(node: Node3D) -> AABB:
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
		var w: AABB = mi.global_transform * mi.get_aabb()
		if ada:
			box = box.merge(w)
		else:
			box = w
			ada = true
	return box


func _find_type(root: Node, type_name: String) -> bool:
	if root.is_class(type_name):
		return true
	for child in root.get_children():
		if _find_type(child, type_name):
			return true
	return false


# --- D. Karakter -------------------------------------------------------------

func _test_characters() -> void:
	print("\n-- CharacterFactory --")

	for sid in StaffDB.ids():
		var spec: Dictionary = CharacterFactory.spec_for_staff(sid)
		_ok("spec staf '%s' tidak kosong" % sid, not spec.is_empty())
		var n: Node3D = CharacterFactory.build(spec)
		if not _node_ok("karakter staf '%s'" % sid, n):
			continue
		for req in CHAR_NODES:
			_ok("staf '%s' punya node '%s'" % [sid, req], CharacterFactory.part(n, req) != null)
		_budget("staf %s" % sid, n, "char", sid)

	for cid in CustomerDB.ids():
		var spec: Dictionary = CharacterFactory.spec_for_customer(cid, 3)
		_ok("spec pelanggan '%s' tidak kosong" % cid, not spec.is_empty())
		var n: Node3D = CharacterFactory.build(spec)
		if not _node_ok("karakter pelanggan '%s'" % cid, n):
			continue
		for req in CHAR_NODES:
			_ok("pelanggan '%s' punya node '%s'" % [cid, req], CharacterFactory.part(n, req) != null)
		_budget("pelanggan %s" % cid, n, "char", cid)

	for rainy in [false, true]:
		var spec: Dictionary = CharacterFactory.spec_for_driver(rainy)
		var n: Node3D = CharacterFactory.build(spec)
		var tag: String = "hujan" if rainy else "cerah"
		if _node_ok("driver ojol (%s)" % tag, n):
			for req in CHAR_NODES:
				_ok("driver %s punya node '%s'" % [tag, req], CharacterFactory.part(n, req) != null)
			_budget("driver %s" % tag, n, "char", "driver_%s" % tag)

	var lurah: Node3D = CharacterFactory.build(CharacterFactory.spec_for_lurah())
	if _node_ok("Pak Lurah", lurah):
		for req in CHAR_NODES:
			_ok("Pak Lurah punya node '%s'" % req, CharacterFactory.part(lurah, req) != null)
		# set_expression harus aman untuk semua mood yang dikontrakkan.
		for mood in ["senang", "netral", "kesal", "sedih", "kaget"]:
			CharacterFactory.set_expression(lurah, mood)
			_pass += 1
		# Mood tak dikenal tidak boleh membuat game crash.
		CharacterFactory.set_expression(lurah, "mood_tidak_ada")
		_pass += 1
		_budget("Pak Lurah", lurah, "char", "lurah")


# --- D2. Karakter pemain & penanda stasiun -----------------------------------

## Dua pilihan karakter harus benar-benar BERBEDA, bukan sekadar dua nama.
##
## Kalau pria dan wanita menghasilkan spec yang identik, layar pemilihan menjadi
## kebohongan -- dan itu tidak akan pernah tertangkap oleh tes yang cuma
## memeriksa "modelnya terbangun".
func _test_player_visuals() -> void:
	print("
-- Karakter Pemain & Penanda Stasiun --")
	var spec_pria: Dictionary = CharacterFactory.spec_for_player("pria")
	var spec_wanita: Dictionary = CharacterFactory.spec_for_player("wanita")
	_ok("spec pria & wanita berbeda", spec_pria != spec_wanita)
	_ok("keduanya berperan baker",
		String(spec_pria.get("role", "")) == "baker"
			and String(spec_wanita.get("role", "")) == "baker")
	_ok("gaya rambut berbeda",
		String(spec_pria.get("hair_style", "")) != String(spec_wanita.get("hair_style", "")))
	_ok("penutup kepala berbeda",
		String(spec_pria.get("hat", "")) != String(spec_wanita.get("hat", "")))
	# Nilai asing tidak boleh menghasilkan karakter rusak; ia jatuh ke "pria".
	_ok("gender tak dikenal jatuh ke bawaan",
		CharacterFactory.spec_for_player("naga") == spec_pria)

	for gender in ["pria", "wanita"]:
		var s: Dictionary = CharacterFactory.spec_for_player(gender)
		var polos: Node3D = CharacterFactory.build(s)
		if not _node_ok("karakter pemain %s" % gender, polos):
			continue
		for bagian in CHAR_NODES:
			_ok("pemain %s punya '%s'" % [gender, bagian],
				CharacterFactory.part(polos, bagian) != null)
		var tris_polos: int = ProceduralMeshFactory.tri_count(polos)
		polos.free()

		# Barang bawaan MENAMBAH geometri, bukan menggantinya: karakter yang
		# membawa loyang harus tetap punya seluruh anggota badannya.
		for bawaan in ["mangkuk_adonan", "loyang_roti", "kantong_kertas"]:
			var s2: Dictionary = CharacterFactory.spec_for_player(gender)
			s2["prop"] = PackedStringArray([bawaan])
			var n: Node3D = CharacterFactory.build(s2)
			if not _node_ok("pemain %s membawa %s" % [gender, bawaan], n):
				continue
			_ok("%s menambah geometri pada %s" % [bawaan, gender],
				ProceduralMeshFactory.tri_count(n) > tris_polos)
			_ok("pemain %s tetap utuh sambil membawa %s" % [gender, bawaan],
				CharacterFactory.part(n, "Head") != null
					and CharacterFactory.part(n, "LegL") != null)
			_budget("pemain %s + %s" % [gender, bawaan], n, "char",
				"pemain %s + %s" % [gender, bawaan])

	_cek_sisi_depan()
	_cek_tinggi_meja()

	var marker := StationMarker.new()
	add_child(marker)
	_ok("penanda lahir tersembunyi", not marker.visible)
	marker.show_alert()
	_ok("tanda seru tampil", marker.visible and marker.mode == StationMarker.MODE_ALERT)
	marker.show_progress(0.5)
	_ok("bar progres menggantikan tanda seru",
		marker.visible and marker.mode == StationMarker.MODE_PROGRESS)
	_cek_bar_progres(marker)
	marker.hide_marker()
	_ok("penanda bisa disembunyikan lagi", not marker.visible)
	_ok("penanda punya geometri", ProceduralMeshFactory.tri_count(marker) > 0)
	_ok("penanda hemat (<= 200 tris)", ProceduralMeshFactory.tri_count(marker) <= 200)
	marker.free()

	_cek_balon_pembeli()


## Balon "!" di atas kepala pembeli yang menunggu dilayani (GDD 2).
##
## Memakai penanda yang sama dengan perabot dapur, jadi yang diuji di sini
## bukan bentuknya melainkan PEMASANGANNYA: balon harus melayang di atas kepala
## dan hilang lagi tanpa meninggalkan node menggantung.
func _cek_balon_pembeli() -> void:
	var a := CustomerActor.new()
	a.setup_customer({"id": 1, "archetype": "anak_sekolah"}, 7)
	add_child(a)

	_ok("pembeli lahir tanpa balon '!'", not a.has_alert())
	a.show_alert()
	_ok("balon '!' bisa ditampilkan", a.has_alert())

	var kepala: Node3D = CharacterFactory.part(a.model, "Head")
	var balon: Node3D = a.get_node_or_null("AlertPembeli") as Node3D
	_ok("balon terpasang sebagai anak pembeli", balon != null)
	if balon != null and kepala != null:
		_ok("balon melayang DI ATAS kepala (%.2f m vs %.2f m)"
			% [balon.position.y, kepala.global_position.y - a.global_position.y],
			balon.position.y > kepala.global_position.y - a.global_position.y)

	a.show_alert()
	_ok("memanggil show_alert() dua kali tidak menumpuk balon kedua",
		a.get_children().filter(func(n: Node) -> bool:
			return n is StationMarker).size() == 1)

	a.hide_alert()
	_ok("balon bisa disembunyikan lagi", not a.has_alert())
	a.free()


## Tidak satu pun meja layan boleh lebih tinggi dari DADA orang yang berdiri di
## baliknya.
##
## Penjaga ini ada karena pernah terjadi: meja kasir pembatas berdiri setinggi
## 0,95 m dengan mesin kasir menjulang sampai 1,22 m, sementara pelanggan chibi
## hanya setinggi 0,92 m. Mejanya lebih tinggi daripada orangnya, dan tidak ada
## satu pun tes yang keberatan -- semuanya cuma memeriksa "mejanya terbangun".
##
## Diukur dari GEOMETRI NYATA di kedua sisi: bahu karakter dan puncak meja
## sama-sama dibaca dari mesh yang benar-benar dirakit, bukan dari konstanta.
## Uji yang membandingkan konstanta dengan konstanta akan ikut lolos walau
## mesh-nya dirakit dengan angka yang sama sekali lain.
func _cek_tinggi_meja() -> void:
	var bahu_min: float = INF
	var tinggi_min: float = INF
	var nama_terpendek: String = ""

	var orang: Array = [
		["pemain pria", CharacterFactory.spec_for_player("pria")],
		["pemain wanita", CharacterFactory.spec_for_player("wanita")],
	]
	# Beberapa benih pelanggan dewasa: tingginya diundi, jadi satu contoh saja
	# tidak mewakili yang terpendek.
	for benih in [3, 11, 29]:
		orang.append(["pelanggan %d" % benih,
			CharacterFactory.spec_for_customer("warga", benih)])

	for e_v in orang:
		var e: Array = e_v
		var n: Node3D = CharacterFactory.build(e[1] as Dictionary)
		add_child(n)
		var bahu: Node3D = CharacterFactory.part(n, "ArmL")
		if bahu != null:
			var b: AABB = _world_aabb_of(bahu)
			bahu_min = minf(bahu_min, b.position.y + b.size.y)
		var t: AABB = _world_aabb_of(n)
		var tinggi: float = t.position.y + t.size.y
		if tinggi < tinggi_min:
			tinggi_min = tinggi
			nama_terpendek = String(e[0])
		n.free()

	_ok("ada karakter yang bisa diukur", bahu_min < INF and tinggi_min < INF)
	if bahu_min == INF:
		return

	# Garis dada bersumber dari proporsi karakter, bukan angka lepas: kalau
	# CharacterFactory menggeser bahunya, batas meja ikut bergeser sendiri.
	_ok("CHEST_HEIGHT bersumber dari proporsi karakter",
		is_equal_approx(EquipmentFactory.CHEST_HEIGHT, CharacterFactory.SHOULDER_Y))
	_ok("permukaan meja (%.2f m) tidak melewati garis dada (%.2f m)"
		% [EquipmentFactory.COUNTER_HEIGHT, EquipmentFactory.CHEST_HEIGHT],
		EquipmentFactory.COUNTER_HEIGHT <= EquipmentFactory.CHEST_HEIGHT)
	_ok("permukaan meja tidak melewati bahu terpendek (%.3f m)" % bahu_min,
		EquipmentFactory.COUNTER_HEIGHT <= bahu_min)
	_ok("meja pembatas setinggi meja layan lain",
		is_equal_approx(EquipmentFactory.DIVIDER_HEIGHT, EquipmentFactory.COUNTER_HEIGHT))

	# Papan meja pembatas benar-benar dirakit di ketinggian itu, bukan sekadar
	# konstantanya yang berubah.
	var dv: Dictionary = EquipmentFactory.divider_metrics(1)
	var pembatas: Node3D = EquipmentFactory.build_divider_counter(
		1, float(dv["span"]), 1)
	add_child(pembatas)
	var surface: Node3D = pembatas.get_node_or_null("Surface") as Node3D
	_ok("meja pembatas punya penanda 'Surface'", surface != null)
	if surface != null:
		_ok("papan meja pembatas dirakit di %.2f m, sesuai konstantanya"
			% surface.position.y,
			is_equal_approx(surface.position.y, EquipmentFactory.DIVIDER_HEIGHT))
	pembatas.free()

	# Seluruh rakitan meja -- termasuk mesin kasir dan papan nama di atasnya --
	# harus tetap lebih pendek dari orang terpendek di ruangan.
	var meja: Array = [
		["meja pembatas", EquipmentFactory.build_divider_counter(
			1, float(dv["span"]), EquipmentFactory.MAX_REGISTERS)],
		["meja kasir", EquipmentFactory.build_counter(5)],
		["meja ojol", EquipmentFactory.build_pickup_counter()],
	]
	for m_v in meja:
		var m: Array = m_v
		var node: Node3D = m[1]
		add_child(node)
		var b2: AABB = _world_aabb_of(node)
		var puncak: float = b2.position.y + b2.size.y
		_ok("%s (%.2f m) lebih pendek dari %s (%.2f m)"
			% [String(m[0]), puncak, nama_terpendek, tinggi_min],
			puncak < tinggi_min)
		node.free()

	print("  garis dada %.2f m, permukaan meja %.2f m, karakter terpendek %.2f m"
		% [EquipmentFactory.CHEST_HEIGHT, EquipmentFactory.COUNTER_HEIGHT, tinggi_min])


## Seluruh pakaian dan detail depan karakter harus berada di SISI YANG SAMA
## dengan wajahnya.
##
## Penjaga ini ada karena pernah terjadi: _body_front_z() mengembalikan jari-jari
## kapsul badan apa adanya -- bilangan POSITIF -- padahal depan karakter ada di
## -Z (CharacterFactory.FRONT). Celemeknya mendarat rapi di punggung, dan tidak
## ada satu pun tes yang keberatan karena semuanya hanya memeriksa "node Apron
## ada".
##
## Diuji sebagai TANDA KOORDINAT, bukan sebagai angka pasti: proporsi badan boleh
## berubah, sisi depan tidak boleh.
func _cek_sisi_depan() -> void:
	var kasus: Array = [
		["pemain pria", CharacterFactory.spec_for_player("pria")],
		["pemain wanita", CharacterFactory.spec_for_player("wanita")],
	]
	for sid in StaffDB.ids():
		var sp: Dictionary = CharacterFactory.spec_for_staff(sid)
		if sp.get("apron") is Color:
			kasus.append(["staf " + sid, sp])
			break

	for e_v in kasus:
		var e: Array = e_v
		var nama: String = String(e[0])
		var n: Node3D = CharacterFactory.build(e[1] as Dictionary)
		add_child(n)

		var z_wajah: float = _z_tengah(CharacterFactory.part(n, "Face"))
		var z_celemek: float = _z_tengah(CharacterFactory.part(n, "Apron"))
		_ok("%s: wajah di sisi depan (z = %+.3f)" % [nama, z_wajah], z_wajah < -0.02)
		_ok("%s: celemek di sisi depan, bukan di punggung (z = %+.3f)"
			% [nama, z_celemek], z_celemek < -0.02)
		_ok("%s: celemek sesisi dengan wajah" % nama,
			signf(z_celemek) == signf(z_wajah))
		# Celemek menempel di badan, jadi ia tidak boleh lebih menonjol dari wajah.
		_ok("%s: celemek menempel di badan, tidak melayang di depan wajah" % nama,
			z_celemek > z_wajah)
		n.free()

	_cek_sisi_depan_driver()


## Driver ojol punya bagian yang HARUS berada di sisi berlawanan: helm dan tali
## ransel di depan, kotak termalnya di PUNGGUNG. Dites terpisah karena ia
## satu-satunya karakter tanpa celemek dan satu-satunya yang membawa beban di
## belakang badan — justru di sanalah sisi depan-belakang paling mudah tertukar.
func _cek_sisi_depan_driver() -> void:
	var n: Node3D = CharacterFactory.build(CharacterFactory.spec_for_driver(false))
	add_child(n)

	var z_wajah: float = _z_tengah(CharacterFactory.part(n, "Face"))
	var z_visor: float = _z_tengah(n.find_child("HelmetVisor", true, false) as Node3D)
	var z_kotak: float = _z_tengah(n.find_child("ThermalBox", true, false) as Node3D)
	var z_logo: float = _z_tengah(n.find_child("ThermalLogo", true, false) as Node3D)
	var z_tali: float = _z_tengah(n.find_child("ThermalStrap", true, false) as Node3D)
	var z_ponsel: float = _z_tengah(n.find_child("Phone", true, false) as Node3D)
	print("  driver: wajah %+.3f  visor %+.3f  ransel %+.3f  logo %+.3f  tali %+.3f  ponsel %+.3f"
		% [z_wajah, z_visor, z_kotak, z_logo, z_tali, z_ponsel])
	_ok("driver: ponsel dipegang di depan badan (z = %+.3f)" % z_ponsel, z_ponsel < 0.0)

	_ok("driver: wajah di sisi depan (z = %+.3f)" % z_wajah, z_wajah < -0.02)
	_ok("driver: kaca helm di depan wajah (z = %+.3f)" % z_visor, z_visor < z_wajah)
	_ok("driver: ransel termal di PUNGGUNG (z = %+.3f)" % z_kotak, z_kotak > 0.02)
	_ok("driver: logo ransel di sisi luar ransel (z = %+.3f)" % z_logo, z_logo > z_kotak)
	_ok("driver: tali ransel menyilang di DADA (z = %+.3f)" % z_tali, z_tali < 0.0)
	n.free()

	# Paper bag hasil serah terima harus ada DI TANGAN, bukan menempel di
	# punggung. Nilai +Z pernah menaruhnya persis di balik ransel termal.
	var aktor := DriverActor.new()
	aktor.setup_driver({"id": 1}, false)
	add_child(aktor)
	aktor.receive_bag()
	var tas: Node3D = aktor.get_node_or_null("PaperBag") as Node3D
	if tas == null:
		for c in aktor.get_children():
			if c is Node3D and c != aktor.model:
				tas = c as Node3D
				break
	_ok("driver: kantong serah terima terpasang", tas != null)
	if tas != null:
		_ok("driver: kantong dipegang di DEPAN badan (z = %+.3f)" % tas.position.z,
			tas.position.z < 0.0)
	aktor.free()


## Titik tengah sumbu Z seluruh mesh keturunan satu bagian tubuh.
func _z_tengah(bagian: Node3D) -> float:
	if bagian == null:
		return 0.0
	var b: AABB = _world_aabb_of(bagian)
	return b.position.z + b.size.z * 0.5


## Bar progres harus benar-benar TUMBUH, dan tumbuh DI DALAM alurnya.
##
## Penjaga ini ada karena pernah terjadi: seluruh lapisan penanda memakai
## `billboard_mode` pada materialnya masing-masing. Billboard mengganti basis
## tiap MESH di sekitar posisi dunia mesh itu sendiri, jadi isi bar -- yang
## digeser sampai setengah lebar bar pada sumbu X -- berputar mengelilingi titik
## yang berbeda dari alurnya dan melenceng diagonal keluar. Di layar yang terlihat
## hanya alur putihnya, tanpa sedikit pun progres.
##
## Karena itu yang diperiksa di sini dua hal: lebar isi bar sebanding dengan
## nilainya, dan TIDAK ADA satu pun material penanda yang memakai billboard.
func _cek_bar_progres(marker: StationMarker) -> void:
	var isi: MeshInstance3D = marker.find_child("Isi", true, false) as MeshInstance3D
	var alur: MeshInstance3D = marker.find_child("Alur", true, false) as MeshInstance3D
	_ok("bar punya node 'Isi' dan 'Alur'", isi != null and alur != null)
	if isi == null or alur == null:
		return

	var lebar_alur: float = _lebar_lokal(marker, alur)
	var kiri_alur: float = _kiri_lokal(marker, alur)
	var sebelumnya: float = -1.0
	for nilai in [0.25, 0.5, 0.75, 1.0]:
		marker.show_progress(nilai)
		var lebar: float = _lebar_lokal(marker, isi)
		var harap: float = lebar_alur * float(nilai)
		_ok("isi bar pada %d%% selebar %.0f%% alur (%.3f vs %.3f m)"
			% [int(nilai * 100.0), nilai * 100.0, lebar, harap],
			absf(lebar - harap) < 0.005)
		_ok("isi bar pada %d%% tumbuh dari yang sebelumnya" % int(nilai * 100.0),
			lebar > sebelumnya)
		# Tepi KIRI isi bar tidak boleh bergeser: bar tumbuh ke kanan, bukan melebar
		# dari tengah dan bukan berpindah tempat.
		_ok("tepi kiri isi bar tetap menempel di tepi alur pada %d%%"
			% int(nilai * 100.0),
			absf(_kiri_lokal(marker, isi) - kiri_alur) < 0.006)
		sebelumnya = lebar

	# Warna berubah seiring kemajuan (hijau -> keemasan), bukan satu blok mati.
	marker.show_progress(0.0)
	var awal: Color = (isi.material_override as StandardMaterial3D).albedo_color
	marker.show_progress(1.0)
	var akhir: Color = (isi.material_override as StandardMaterial3D).albedo_color
	_ok("warna isi bar berubah seiring kemajuan", awal != akhir)

	var pakai_billboard: int = 0
	var antrean: Array[Node] = [marker]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var mi := n as MeshInstance3D
		if mi == null:
			continue
		var mat := mi.material_override as StandardMaterial3D
		if mat != null and mat.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED:
			pakai_billboard += 1
	_ok("tidak ada lapisan penanda yang memakai billboard per-material",
		pakai_billboard == 0)


## Lebar sebuah lapisan penanda pada sumbu X, dalam koordinat penanda.
func _lebar_lokal(marker: Node3D, mi: MeshInstance3D) -> float:
	return _aabb_lokal(marker, mi).size.x


## Tepi kiri sebuah lapisan penanda pada sumbu X, dalam koordinat penanda.
func _kiri_lokal(marker: Node3D, mi: MeshInstance3D) -> float:
	return _aabb_lokal(marker, mi).position.x


func _aabb_lokal(marker: Node3D, mi: MeshInstance3D) -> AABB:
	var rel: Transform3D = marker.global_transform.affine_inverse() * mi.global_transform
	return rel * mi.get_aabb()


# --- E. Ikon -----------------------------------------------------------------

func _test_icons() -> void:
	print("\n-- IconCanvas (%d ikon) --" % ICON_NAMES.size())
	# Daftar di tes memegang KONTRAKNYA; daftar di kelasnya boleh saja bertambah
	# diam-diam, dan justru itu yang harus ketahuan.
	_ok("jumlah ikon sesuai kontrak (%d)" % ICON_NAMES.size(),
		IconCanvas.NAMES.size() == ICON_NAMES.size())
	for name in ICON_NAMES:
		_ok("ikon '%s' dikenal" % name, IconCanvas.has_icon(name))
		var ic: IconCanvas = ProceduralUIFactory.icon(name, 32, Color.WHITE)
		if ic != null:
			_ok("ikon '%s' terbentuk" % name, ic.icon_name == name)
			_ok("ikon '%s' punya ukuran minimum" % name, ic.custom_minimum_size.x >= 16.0)
			ic.free()
		else:
			_ok("ikon '%s' terbentuk" % name, false)
	# Nama ikon asing harus ditolak, bukan diam-diam digambar sebagai sesuatu.
	_ok("ikon tak dikenal ditolak", not IconCanvas.has_icon("ikon_yang_tidak_ada"))

	_cek_tombol_ikon()


## Tombol ikon HUD: tanpa teks, tetapi TIDAK boleh tanpa penjelasan dan tidak
## boleh mengecilkan zona sentuh.
##
## Ikon yang salah tebak di tombol "Berhentikan" jauh lebih mahal daripada di
## tombol "Pasar", jadi tooltip diwajibkan — dan jari tetap butuh 48x48 dp
## (GDD 12.4) sekalipun gambarnya cuma 22 piksel.
func _cek_tombol_ikon() -> void:
	var b: Button = ProceduralUIFactory.icon_button("cart", "Pasar", "secondary", 22)
	add_child(b)
	_ok("tombol ikon terbentuk", b != null)
	_ok("tombol ikon tidak memakai teks", b.text == "")
	_ok("tombol ikon membawa tooltip", b.tooltip_text == "Pasar")
	_ok("tombol ikon tetap 48x48 dp",
		b.custom_minimum_size.x >= ProceduralUIFactory.TOUCH_MIN
			and b.custom_minimum_size.y >= ProceduralUIFactory.TOUCH_MIN)

	var ic: IconCanvas = b.get_meta("icon", null) as IconCanvas
	_ok("gambar tombol bisa diganti di tempat lewat meta 'icon'", ic != null)
	if ic != null:
		ic.icon_name = "play"
		_ok("gambar tombol berganti tanpa membangun ulang tombolnya",
			ic.icon_name == "play")
		_ok("gambar tombol tidak menelan ketukan",
			ic.mouse_filter == Control.MOUSE_FILTER_IGNORE)
	b.free()


# --- F. UI -------------------------------------------------------------------

func _test_ui() -> void:
	print("\n-- ProceduralUIFactory --")
	var made: Dictionary = {
		"panel": ProceduralUIFactory.panel(Palette.PANEL, 20, true),
		"button": ProceduralUIFactory.button("Uji", "primary"),
		"label": ProceduralUIFactory.label("Uji"),
		"title": ProceduralUIFactory.title("Uji"),
		"card": ProceduralUIFactory.card("Uji"),
		"parchment": ProceduralUIFactory.parchment_panel(),
		"chalkboard": ProceduralUIFactory.chalkboard_panel(),
		"pantry_bar": ProceduralUIFactory.pantry_bar(60, 150),
		"slider_row": ProceduralUIFactory.slider_row("Harga", 0.0, 100.0, 50.0),
	}
	for key in made:
		_ok("%s() tidak null" % key, made[key] != null)

	for kind in ["primary", "secondary", "danger", "ghost"]:
		var b: Button = ProceduralUIFactory.button("Uji", kind)
		if b != null:
			# GDD 7: zona sentuh minimal 48x48 dan tap-first (tanpa fokus keyboard).
			_ok("tombol '%s' hitbox >= 48x48" % kind,
				b.custom_minimum_size.x >= 48.0 and b.custom_minimum_size.y >= 48.0)
			_ok("tombol '%s' focus_mode NONE" % kind, b.focus_mode == Control.FOCUS_NONE)
			b.free()
		else:
			_ok("tombol '%s' terbentuk" % kind, false)

	# Polaroid harus bisa dibuat untuk SEMUA staf, bukan cuma segelintir.
	for sid in StaffDB.ids():
		var p: Control = ProceduralUIFactory.polaroid(sid)
		_ok("polaroid '%s'" % sid, p != null)
		if p != null:
			p.free()

	var theme: Theme = ProceduralUIFactory.build_theme()
	_ok("build_theme() tidak null", theme != null)
	if theme != null:
		_ok("theme punya style Button", theme.has_stylebox("normal", "Button"))

	for key in made:
		var v: Variant = made[key]
		if v is Node:
			(v as Node).free()

	var margin: Vector4 = ProceduralUIFactory.safe_area_margin()
	_ok("safe_area_margin() tidak negatif",
		margin.x >= 0.0 and margin.y >= 0.0 and margin.z >= 0.0 and margin.w >= 0.0)


# --- G. FX -------------------------------------------------------------------

func _test_fx() -> void:
	print("\n-- FX (CPUParticles saja, GDD 4.3) --")
	var host: Node3D = Node3D.new()
	add_child(host)

	var steam: CPUParticles3D = FX.steam(host, Vector3.ZERO)
	_ok("steam() CPUParticles3D", steam != null and steam is CPUParticles3D)
	if steam != null:
		_ok("steam() amount hemat mobile (<= 24)", steam.amount <= 24)

	var sparkle: CPUParticles3D = FX.sugar_sparkle(host, Vector3.ZERO)
	_ok("sugar_sparkle() CPUParticles3D", sparkle != null and sparkle is CPUParticles3D)

	var smoke: CPUParticles3D = FX.burn_smoke(host, Vector3.ZERO)
	_ok("burn_smoke() CPUParticles3D", smoke != null and smoke is CPUParticles3D)

	var actor: Node3D = CharacterFactory.build(CharacterFactory.spec_for_driver(false))
	add_child(actor)
	FX.sweat_drop(actor)
	_pass += 1

	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	var ci: Control = Control.new()
	layer.add_child(ci)
	FX.coin_pop(ci, Vector2(100, 100), 250.0)
	_pass += 1

	var rain: CPUParticles2D = FX.rain_overlay(layer)
	_ok("rain_overlay() CPUParticles2D", rain != null and rain is CPUParticles2D)

	# Tidak boleh ada GPUParticles di mana pun (tidak andal di Compatibility / HP lawas).
	_ok("tidak ada GPUParticles3D", not _find_type(host, "GPUParticles3D"))
	_ok("tidak ada GPUParticles2D", not _find_type(layer, "GPUParticles2D"))

	host.queue_free()
	actor.queue_free()
	layer.queue_free()


# --- H. Animasi --------------------------------------------------------------

func _test_anim() -> void:
	print("\n-- ProceduralAnimationSystem --")
	var actor: Node3D = CharacterFactory.build(CharacterFactory.spec_for_staff("budi"))
	add_child(actor)

	# walk/idle_bob stateless, dipanggil tiap frame -- panggil berkali-kali.
	for i in 10:
		ProceduralAnimationSystem.walk(actor, float(i) * 0.1, 6.0)
		ProceduralAnimationSystem.idle_bob(actor, float(i) * 0.1)
	_pass += 2

	_ok("happy_jump() mengembalikan Tween", ProceduralAnimationSystem.happy_jump(actor) != null)
	_ok("sad_shake() mengembalikan Tween", ProceduralAnimationSystem.sad_shake(actor) != null)
	_ok("squash_pop() mengembalikan Tween", ProceduralAnimationSystem.squash_pop(actor) != null)

	var ctrl: Control = ProceduralUIFactory.button("Uji")
	add_child(ctrl)
	_ok("press_bounce() mengembalikan Tween", ProceduralAnimationSystem.press_bounce(ctrl) != null)

	var oven: Node3D = EquipmentFactory.build_oven(2)
	add_child(oven)
	var door: Node3D = oven.get_node_or_null("Door") as Node3D
	if door != null:
		_ok("oven_door(buka) mengembalikan Tween",
			ProceduralAnimationSystem.oven_door(door, true) != null)
	else:
		_ok("oven punya Door untuk dianimasikan", false)

	var mixer: Node3D = EquipmentFactory.build_mixer(2)
	add_child(mixer)
	var whisk: Node3D = mixer.get_node_or_null("Whisk") as Node3D
	if whisk != null:
		for i in 5:
			ProceduralAnimationSystem.mixer_spin(whisk, float(i) * 0.1)
		_pass += 1
	else:
		_ok("mixer punya Whisk untuk diputar", false)

	# Aktor kosong tanpa node anak tidak boleh membuat animasi crash.
	var bare: Node3D = Node3D.new()
	add_child(bare)
	ProceduralAnimationSystem.walk(bare, 0.5, 6.0)
	ProceduralAnimationSystem.idle_bob(bare, 0.5)
	_pass += 1

	actor.queue_free()
	ctrl.queue_free()
	oven.queue_free()
	mixer.queue_free()
	bare.queue_free()


# --- I. Determinisme ---------------------------------------------------------

func _test_determinism() -> void:
	print("\n-- Determinisme --")
	# Pelanggan dengan seed sama harus selalu tampak sama (kontrak spec_for_customer).
	for cid in CustomerDB.ids():
		var a: Dictionary = CharacterFactory.spec_for_customer(cid, 42)
		var b: Dictionary = CharacterFactory.spec_for_customer(cid, 42)
		_ok("spec '%s' deterministik untuk seed sama" % cid, a == b)
	var s1: Dictionary = CharacterFactory.spec_for_customer("anak_sekolah", 1)
	var s2: Dictionary = CharacterFactory.spec_for_customer("anak_sekolah", 2)
	_ok("seed berbeda menghasilkan variasi", s1 != s2)
