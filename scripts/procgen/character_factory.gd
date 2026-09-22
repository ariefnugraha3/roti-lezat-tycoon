class_name CharacterFactory
extends RefCounted

## Pabrik karakter chibi 100% prosedural bergaya "Warm, Cozy & Cute" (GDD 4.1 & 4.2).
##
## Seluruh karakter dirakit dari mesh primitif Godot (SphereMesh, CapsuleMesh, BoxMesh,
## CylinderMesh, TorusMesh) tanpa satu pun aset eksternal dan TANPA skeletal armature
## (GDD 4.2). Setiap anggota badan adalah Node3D "pivot" di sendi (bahu / pinggul),
## sehingga ProceduralAnimationSystem cukup memutar pivot itu dengan gelombang sinus
## agar terlihat berjalan.
##
## Nama node anak WAJIB (kontrak ARCHITECTURE seksi 8):
##   Head, Body, ArmL, ArmR, LegL, LegR, Face, Hat, Apron
## Head / Body / ArmL / ArmR / LegL / LegR adalah anak langsung root; Face, Hair, dan Hat
## menempel pada Head (ikut mengangguk), Apron menempel pada Body (ikut membal).
## Seluruh node diberi `owner = root` supaya tetap ditemukan `find_child()` bawaan Godot.
##
## Arah hadap karakter adalah -Z (konvensi Godot), jadi seluruh detail wajah memakai
## pengali konstanta `FRONT`.
##
## Kunci `spec` kanonik:
##   {kind, role, tier, skin, hair, hair_style, apron, accessory, chubby, rainy}
## Kunci opsional tambahan yang diisi otomatis oleh spec_for_*():
##   hat, cloth, prop, mood, height, lean, head_tilt, archetype
##
## Anggaran geometri: <= ~900 segitiga per karakter (GDD 12.2), karena itu jumlah
## segmen setiap primitif SELALU ditulis eksplisit dan tidak pernah memakai nilai
## bawaan Godot yang sangat tinggi.

# ---------------------------------------------------------------------------
# Proporsi tubuh chibi (satuan meter)
# ---------------------------------------------------------------------------

## Pengali arah depan karakter. Godot memakai -Z sebagai arah hadap.
const FRONT: float = -1.0

## Jari-jari kepala bola besar (GDD 4.1: kepala bulat besar ala adonan).
const HEAD_RADIUS: float = 0.22
## Tinggi pivot leher, tempat node "Head" berdiri.
const NECK_Y: float = 0.50
## Titik pusat bola kepala relatif terhadap pivot "Head".
const HEAD_CENTER_Y: float = 0.19

## Tinggi total kapsul badan.
const BODY_HEIGHT: float = 0.30
## Jari-jari kapsul badan.
const BODY_RADIUS: float = 0.125
## Tinggi pivot pinggul, tempat node "Body", "LegL", dan "LegR" berdiri.
const HIP_Y: float = 0.20

## Tinggi pivot bahu, tempat node "ArmL" dan "ArmR" berdiri.
const SHOULDER_Y: float = 0.440
## Jarak bahu dari sumbu tengah (dilebarkan mengikuti `chubby`).
const SHOULDER_X: float = 0.140
## Panjang kapsul lengan.
const ARM_LENGTH: float = 0.17
## Jari-jari kapsul lengan.
const ARM_RADIUS: float = 0.042

## Jarak pangkal kaki dari sumbu tengah.
const HIP_X: float = 0.062
## Panjang kapsul kaki.
const LEG_LENGTH: float = 0.18
## Jari-jari kapsul kaki.
const LEG_RADIUS: float = 0.050

# ---------------------------------------------------------------------------
# Jumlah segmen primitif (ditulis eksplisit demi anggaran 500-2000 tris)
# ---------------------------------------------------------------------------

const SEG_HEAD_RADIAL: int = 12
const SEG_HEAD_RINGS: int = 5
const SEG_BODY_RADIAL: int = 8
const SEG_BODY_RINGS: int = 1
const SEG_LIMB_RADIAL: int = 5
const SEG_LIMB_RINGS: int = 1
const SEG_BLOB_RADIAL: int = 5
const SEG_BLOB_RINGS: int = 2
const SEG_TINY_RADIAL: int = 4
const SEG_TINY_RINGS: int = 1
const SEG_CAP_RADIAL: int = 8
const SEG_CAP_RINGS: int = 2
const SEG_CYL: int = 8
const SEG_CYL_LOW: int = 6
const SEG_TORUS_RINGS: int = 7
const SEG_TORUS_SEGMENTS: int = 3

# ---------------------------------------------------------------------------
# Ukuran detail wajah (ruang lokal, relatif terhadap pusat kepala)
# ---------------------------------------------------------------------------

const EYE_RADIUS: float = 0.036
const EYE_X: float = 0.080
const EYE_Y: float = 0.030
const EYE_Z: float = 0.190
const GLINT_RADIUS: float = 0.012
const MOUTH_RADIUS: float = 0.030
const MOUTH_Y: float = -0.058
const MOUTH_Z: float = 0.202
const CHEEK_RADIUS: float = 0.040
const BROW_Y: float = 0.092
const BROW_Z: float = 0.178

## Jari-jari tempurung rambut; sedikit lebih besar dari kepala agar rambut terasa tebal.
const HAIR_CAP_RADIUS: float = 0.245

# ---------------------------------------------------------------------------
# Warna dasar yang tidak ada di Palette (khusus anatomi chibi)
# ---------------------------------------------------------------------------

## Warna kulit chibi, dari paling terang ke paling gelap (selaras StaffDB).
const SKIN_LIGHT: Color = Color(0.980, 0.851, 0.737)   # #FAD9BC
const SKIN_MID: Color = Color(0.949, 0.788, 0.627)     # #F2C9A0
const SKIN_TAN: Color = Color(0.878, 0.659, 0.486)     # #E0A87C
const SKIN_DEEP: Color = Color(0.788, 0.541, 0.369)    # #C98A5E

## Warna rambut.
const HAIR_BLACK: Color = Color(0.169, 0.129, 0.094)   # #2B2118
const HAIR_BROWN: Color = Color(0.290, 0.192, 0.129)   # #4A3121
const HAIR_LIGHT_BROWN: Color = Color(0.478, 0.306, 0.176)  # #7A4E2D
const HAIR_BLONDE: Color = Color(0.878, 0.753, 0.439)  # #E0C070
const HAIR_PASTEL: Color = Color(0.910, 0.706, 0.847)  # #E8B4D8
const HAIR_GREY: Color = Color(0.788, 0.761, 0.729)    # #C9C2BA

## Manik mata gelap dan mulut mungil.
const EYE_COLOR: Color = Color(0.129, 0.090, 0.075)    # #21170F
const MOUTH_COLOR: Color = Color(0.451, 0.204, 0.180)  # #73342E
## Kilau kecil pada manik mata.
const GLINT_COLOR: Color = Color(1.0, 1.0, 1.0)

## Warna gelap untuk kaca helm, layar ponsel, dan sejenisnya.
const DARK_GLASS: Color = Color(0.141, 0.157, 0.192)   # #24282F

# ---------------------------------------------------------------------------
# Tabel ekspresi wajah (GDD 4.2: ekspresi memakai squash & stretch, bukan tekstur)
# ---------------------------------------------------------------------------

## Parameter tiap suasana hati. `eye_scale` & `mouth_scale` adalah PENGALI atas skala
## dasar, `*_offset` adalah geseran posisi, `brow_tilt` derajat (positif = alis turun
## ke arah hidung alias marah), `cheek_scale` pengali besar rona pipi.
const EXPRESSIONS: Dictionary = {
	"netral": {
		"eye_scale": Vector3(1.0, 1.0, 1.0),
		"eye_offset": Vector3(0.0, 0.0, 0.0),
		"mouth_scale": Vector3(1.0, 1.0, 1.0),
		"mouth_offset": Vector3(0.0, 0.0, 0.0),
		"brow_offset": Vector3(0.0, 0.0, 0.0),
		"brow_tilt": 0.0,
		"cheek_scale": 1.0,
	},
	"senang": {
		"eye_scale": Vector3(1.10, 0.45, 1.0),
		"eye_offset": Vector3(0.0, 0.012, 0.0),
		"mouth_scale": Vector3(1.70, 1.45, 1.0),
		"mouth_offset": Vector3(0.0, -0.008, 0.0),
		"brow_offset": Vector3(0.0, 0.012, 0.0),
		"brow_tilt": -4.0,
		"cheek_scale": 1.25,
	},
	"kesal": {
		"eye_scale": Vector3(0.95, 0.62, 1.0),
		"eye_offset": Vector3(0.0, -0.004, 0.0),
		"mouth_scale": Vector3(0.85, 0.70, 1.0),
		"mouth_offset": Vector3(0.0, -0.006, 0.0),
		"brow_offset": Vector3(0.0, -0.014, 0.0),
		"brow_tilt": 16.0,
		"cheek_scale": 1.05,
	},
	"sedih": {
		"eye_scale": Vector3(0.90, 0.88, 1.0),
		"eye_offset": Vector3(0.0, -0.008, 0.0),
		"mouth_scale": Vector3(0.80, 0.80, 1.0),
		"mouth_offset": Vector3(0.0, -0.014, 0.0),
		"brow_offset": Vector3(0.0, -0.004, 0.0),
		"brow_tilt": -14.0,
		"cheek_scale": 0.90,
	},
	"kaget": {
		"eye_scale": Vector3(1.35, 1.35, 1.0),
		"eye_offset": Vector3(0.0, 0.004, 0.0),
		"mouth_scale": Vector3(0.90, 1.80, 1.0),
		"mouth_offset": Vector3(0.0, -0.012, 0.0),
		"brow_offset": Vector3(0.0, 0.020, 0.0),
		"brow_tilt": -2.0,
		"cheek_scale": 1.0,
	},
}


# ===========================================================================
# API PUBLIK
# ===========================================================================

## Rakit satu karakter chibi lengkap dari `spec`. Kunci yang tidak dikenal diabaikan,
## kunci yang hilang memakai nilai bawaan, jadi `build({})` tetap menghasilkan karakter.
static func build(spec: Dictionary) -> Node3D:
	var s: Dictionary = _normalize(spec)

	var root: Node3D = Node3D.new()
	root.name = "Character"

	# --- Badan + celemek ---
	var body: Node3D = _build_body(s)
	root.add_child(body)
	var apron: Node3D = _build_apron(s)
	body.add_child(apron)

	# --- Kepala + wajah + rambut + topi ---
	var head: Node3D = _build_head(s)
	root.add_child(head)
	var face: Node3D = _build_face(s)
	head.add_child(face)
	var hair: Node3D = _build_hair(s)
	head.add_child(hair)
	var hat: Node3D = _build_hat(s)
	head.add_child(hat)

	# --- Anggota gerak (pivot di bahu & pinggul) ---
	var arm_l: Node3D = _build_arm(s, -1.0)
	var arm_r: Node3D = _build_arm(s, 1.0)
	var leg_l: Node3D = _build_leg(s, -1.0)
	var leg_r: Node3D = _build_leg(s, 1.0)
	root.add_child(arm_l)
	root.add_child(arm_r)
	root.add_child(leg_l)
	root.add_child(leg_r)

	var parts: Dictionary = {
		"root": root,
		"head": head,
		"face": face,
		"hair": hair,
		"hat": hat,
		"body": body,
		"apron": apron,
		"arm_l": arm_l,
		"arm_r": arm_r,
		"leg_l": leg_l,
		"leg_r": leg_r,
	}

	var accessories: PackedStringArray = s["accessory"]
	for acc_id: String in accessories:
		_attach_accessory(acc_id, s, parts)
	var props: PackedStringArray = s["prop"]
	for prop_id: String in props:
		_attach_prop(prop_id, s, parts)

	# --- Postur (membungkuk terburu-buru / kepala miring bingung) ---
	var lean: float = s["lean"]
	if not is_zero_approx(lean):
		body.rotation_degrees = Vector3(lean, 0.0, 0.0)
		_remember(body)
	var tilt: float = s["head_tilt"]
	if not is_zero_approx(tilt):
		head.rotation_degrees = Vector3(0.0, 0.0, tilt)
		_remember(head)

	var height: float = s["height"]
	root.scale = Vector3.ONE * height

	root.set_meta("spec", s)
	root.set_meta("base_scale", root.scale)
	root.set_meta("base_position", root.position)

	var mood: String = s["mood"]
	set_expression(root, mood)
	_assign_owner(root, root)
	return root


## Terjemahkan satu entri StaffDB menjadi spec CharacterFactory.
## ID yang tidak dikenal tetap menghasilkan staf generik Tier 1 (tidak pernah crash).
static func spec_for_staff(staff_id: String) -> Dictionary:
	var entry: Dictionary = StaffDB.entry(staff_id)
	var role: String = "kasir"
	var tier: int = 1
	if not entry.is_empty():
		role = str(entry.get("role", "kasir"))
		tier = clampi(int(entry.get("tier", 1)), 1, 5)

	var visual: Dictionary = {}
	var raw_visual: Variant = entry.get("visual")
	if raw_visual is Dictionary:
		visual = raw_visual

	var spec: Dictionary = {
		"kind": "staff",
		"role": role,
		"tier": tier,
		"skin": _as_color(visual.get("skin"), SKIN_MID),
		"hair": _as_color(visual.get("hair"), HAIR_BLACK),
		"hair_style": str(visual.get("hair_style", "pendek")),
		"hat": str(visual.get("hat", "none")),
		"apron": _as_color(visual.get("apron"), Palette.apron_for_tier(role, tier)),
		"accessory": _as_names(visual.get("accessory")),
		"chubby": clampf(float(visual.get("chubby", 0.0)), 0.0, 1.0),
		"cloth": Palette.FLOUR_WHITE,
		"prop": PackedStringArray(),
		"rainy": false,
		# Staf toko selalu menyambut dengan senyum (GDD 4.1 "Cute").
		"mood": "senang",
		"height": 1.0,
	}

	# Baker memakai kaus dalam krem hangat, kasir kemeja putih gandum.
	if role == "baker":
		spec["cloth"] = Palette.VANILLA_CREAM
	return spec


## Spec karakter PEMAIN (GDD 2: pemain sendiri yang mengoperasikan alat).
##
## Hanya ada dua pilihan, dan keduanya dibedakan lewat parameter chibi yang sudah
## ada -- gaya rambut, proporsi, dan warna celemek -- bukan lewat model terpisah.
## Itu yang menjaga janji 100% prosedural: satu perakit karakter, dua nilai
## masukan berbeda.
##
## Pemain memakai celemek baker Tier 1 supaya langsung terbaca sebagai "yang
## memanggang", dan berdiri sedikit lebih tinggi dari pelanggan biasa agar mudah
## dicari mata di antara kerumunan.
static func spec_for_player(gender: String) -> Dictionary:
	var wanita: bool = gender == "wanita"
	return {
		"kind": "player",
		"role": "baker",
		"tier": 1,
		"skin": SKIN_LIGHT if wanita else SKIN_MID,
		"hair": HAIR_BROWN if wanita else HAIR_BLACK,
		"hair_style": "panjang_kepang" if wanita else "pendek",
		"hat": "bandana" if wanita else "topi_koki",
		"apron": Palette.APRON_ORANGE_PASTEL if wanita else Palette.APRON_COFFEE_BROWN,
		"accessory": PackedStringArray(),
		"chubby": 0.10 if wanita else 0.18,
		"cloth": Palette.FLOUR_WHITE,
		"prop": PackedStringArray(),
		"rainy": false,
		"mood": "senang",
		"height": 1.04 if wanita else 1.08,
		"lean": 0.0,
		"head_tilt": 0.0,
	}


## Spec pelanggan yang deterministik terhadap `seed_i`: pelanggan dengan seed sama
## SELALU tampil sama. Sengaja memakai RandomNumberGenerator lokal, bukan GameConfig.rng.
static func spec_for_customer(customer_id: String, seed_i: int) -> Dictionary:
	var rng: RandomNumberGenerator = _seeded_rng(customer_id, seed_i)

	# Driver ojol punya seragam tetap (GDD 3.6); hanya wajahnya yang bervariasi.
	if customer_id == "driver_ojol":
		var driver: Dictionary = spec_for_driver(false)
		driver["skin"] = _pick_color(_skin_tones(), rng)
		driver["hair"] = _pick_color(_hair_tones(), rng)
		return driver

	var archetype: String = customer_id
	if CustomerDB.entry(customer_id).is_empty():
		archetype = "warga"  # ID asing: pejalan kaki biasa, tidak crash.

	var spec: Dictionary = {
		"kind": "customer",
		"archetype": archetype,
		"role": "",
		"tier": 1,
		"skin": _pick_color(_skin_tones(), rng),
		"hair": _pick_color(_hair_tones(), rng),
		"hair_style": _pick_name(_hair_styles(), rng),
		"hat": "none",
		"apron": null,
		"accessory": PackedStringArray(),
		"chubby": rng.randf_range(0.0, 0.35),
		"cloth": _pick_color(_cloth_tones(), rng),
		"prop": PackedStringArray(),
		"rainy": false,
		"mood": "netral",
		"height": rng.randf_range(0.96, 1.04),
		"lean": 0.0,
		"head_tilt": 0.0,
	}

	match archetype:
		"anak_sekolah":
			# Bertubuh mungil, seragam putih, dasi merah, ransel sekolah (The Sweet Tooth).
			spec["height"] = rng.randf_range(0.78, 0.84)
			spec["chubby"] = rng.randf_range(0.10, 0.30)
			spec["cloth"] = Palette.FLOUR_WHITE
			spec["hair_style"] = _pick_name(_pack(["pendek", "kuncir_ganda", "spike", "bob"]), rng)
			spec["accessory"] = _pack(["dasi_merah"])
			spec["prop"] = _pack(["tas_sekolah"])
			spec["mood"] = "senang"
		"pekerja_kantoran":
			# Berkerah, berdasi, membawa koper, badan condong ke depan karena terburu-buru.
			spec["cloth"] = _pick_color(_office_tones(), rng)
			spec["hair_style"] = _pick_name(_pack(["belah_samping", "cepak", "bob", "sanggul"]), rng)
			spec["accessory"] = _pack(["kerah_kemeja", "dasi_kerja"])
			spec["prop"] = _pack(["koper"])
			spec["lean"] = 9.0
			spec["mood"] = "kesal"
		"emak_arisan":
			# Tambun keibuan, sanggul, anting, dan tas belanja besar (The Bulk Buyer).
			spec["chubby"] = rng.randf_range(0.55, 0.80)
			spec["height"] = rng.randf_range(0.92, 0.98)
			spec["cloth"] = _pick_color(_floral_tones(), rng)
			spec["hair_style"] = "sanggul"
			spec["accessory"] = _pack(["anting_mutiara"])
			spec["prop"] = _pack(["tas_belanja"])
			spec["mood"] = "senang"
		"sosialita":
			# Jangkung, anggun, mutiara, dan tas tangan kecil (The Snob).
			spec["height"] = rng.randf_range(1.04, 1.10)
			spec["chubby"] = 0.0
			spec["cloth"] = _pick_color(_elegant_tones(), rng)
			spec["hair_style"] = _pick_name(_pack(["sanggul", "ikal"]), rng)
			spec["accessory"] = _pack(["anting_mutiara", "kalung_mutiara"])
			spec["prop"] = _pack(["tas_tangan"])
			spec["mood"] = "netral"
		"si_galau":
			# Kepala miring bingung dengan tanda tanya melayang (The Indecisive).
			spec["head_tilt"] = rng.randf_range(10.0, 16.0)
			spec["cloth"] = Palette.PASTEL_PERIWINKLE
			spec["prop"] = _pack(["tanda_tanya"])
			spec["mood"] = "sedih"
		"food_vlogger":
			# Topi pet dan kamera mungil yang selalu diacungkan (The VIP Critic).
			spec["cloth"] = _pick_color(_vivid_tones(), rng)
			spec["hat"] = "topi_pet"
			spec["prop"] = _pack(["kamera"])
			spec["mood"] = "senang"
		_:
			pass
	return spec


## Spec kurir RotiFood (GDD 3.6): seragam hijau toska pastel #4EBA6F, helm bundar,
## ransel termal kubus. Saat `rainy` seragam diganti jas hujan kuning (GDD 10.2).
static func spec_for_driver(rainy: bool) -> Dictionary:
	var uniform: Color = Palette.OJOL_GREEN
	var accessories: Array[String] = ["ponsel"]
	if rainy:
		uniform = Palette.RAINCOAT_YELLOW
		accessories.append("jas_hujan")

	return {
		"kind": "driver",
		"role": "driver",
		"tier": 1,
		"skin": SKIN_MID,
		"hair": HAIR_BLACK,
		"hair_style": "pendek",
		"hat": "helm",
		"apron": null,
		"accessory": _pack(accessories),
		"chubby": 0.1,
		"cloth": uniform,
		"prop": _pack(["ransel_termal"]),
		"rainy": rainy,
		"mood": "senang",
		"height": 1.0,
	}


## Spec Pak Lurah (GDD 3.0.A): chibi tambun berwajah ramah, berpeci, membawa koper
## kecil dan amplop berstempel resmi pemerintah daerah.
static func spec_for_lurah() -> Dictionary:
	return {
		"kind": "lurah",
		"role": "lurah",
		"tier": 1,
		"skin": SKIN_TAN,
		"hair": HAIR_GREY,
		"hair_style": "cepak",
		"hat": "peci",
		"apron": null,
		"accessory": _pack(["kumis", "kerah_kemeja"]),
		"chubby": 0.85,
		"cloth": Color(0.827, 0.780, 0.596),  # safari krem pemerintah daerah #D3C798
		"prop": _pack(["koper", "amplop"]),
		"rainy": false,
		"mood": "senang",
		"height": 0.98,
	}


## Ganti ekspresi wajah karakter: "senang", "netral", "kesal", "sedih", "kaget".
## Hanya mengubah skala & posisi mesh mata/mulut/alis/pipi — tanpa tekstur apa pun.
static func set_expression(actor: Node3D, mood: String) -> void:
	if actor == null:
		return
	var face: Node3D = part(actor, "Face")
	if face == null:
		return

	var key: String = mood
	if not EXPRESSIONS.has(key):
		key = "netral"
	var e: Dictionary = EXPRESSIONS[key]

	var eye_scale: Vector3 = e["eye_scale"]
	var eye_offset: Vector3 = e["eye_offset"]
	var mouth_scale: Vector3 = e["mouth_scale"]
	var mouth_offset: Vector3 = e["mouth_offset"]
	var brow_offset: Vector3 = e["brow_offset"]
	var brow_tilt: float = e["brow_tilt"]
	var cheek_scale: float = e["cheek_scale"]

	for i: int in 2:
		var side: String = "L"
		var dir: float = -1.0
		if i == 1:
			side = "R"
			dir = 1.0
		_apply_part(_child3d(face, "Eye" + side), eye_scale, eye_offset)
		_apply_part(_child3d(face, "Cheek" + side), Vector3.ONE * cheek_scale, Vector3.ZERO)
		var brow: Node3D = _child3d(face, "Brow" + side)
		if brow != null:
			_apply_part(brow, Vector3.ONE, brow_offset)
			var base_rot: Vector3 = brow.get_meta("base_rotation", Vector3.ZERO)
			brow.rotation = Vector3(base_rot.x, base_rot.y, base_rot.z + deg_to_rad(brow_tilt * dir))
	_apply_part(_child3d(face, "Mouth"), mouth_scale, mouth_offset)

	actor.set_meta("mood", key)


## Cari salah satu bagian karakter ("Head", "Body", "ArmL", ... "Apron") dengan aman.
## Mengembalikan null bila tidak ada, sehingga pemanggil boleh menganggap opsional.
static func part(actor: Node3D, part_name: String) -> Node3D:
	if actor == null:
		return null
	var direct: Node = actor.get_node_or_null(NodePath(part_name))
	if direct is Node3D:
		return direct
	var found: Node = actor.find_child(part_name, true, false)
	if found is Node3D:
		return found
	return null


# ===========================================================================
# PERAKITAN BAGIAN TUBUH
# ===========================================================================

## Pivot pinggul + kapsul badan yang membulat seperti adonan.
static func _build_body(s: Dictionary) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "Body"
	pivot.position = Vector3(0.0, HIP_Y, 0.0)

	var chubby: float = s["chubby"]
	var cloth: Color = s["cloth"]
	var mesh: MeshInstance3D = _capsule("BodyMesh", BODY_HEIGHT, BODY_RADIUS, cloth,
		SEG_BODY_RADIAL, SEG_BODY_RINGS)
	mesh.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)
	var fat: float = 1.0 + 0.32 * chubby
	mesh.scale = Vector3(fat, 1.0, fat)
	pivot.add_child(mesh)

	_remember(pivot)
	return pivot


## Pivot leher + bola kepala besar.
static func _build_head(s: Dictionary) -> Node3D:
	var pivot: Node3D = Node3D.new()
	pivot.name = "Head"
	pivot.position = Vector3(0.0, NECK_Y, 0.0)

	var skin: Color = s["skin"]
	var chubby: float = s["chubby"]
	var mesh: MeshInstance3D = _sphere("HeadMesh", HEAD_RADIUS, skin,
		SEG_HEAD_RADIAL, SEG_HEAD_RINGS)
	mesh.position = Vector3(0.0, HEAD_CENTER_Y, 0.0)
	var fat: float = 1.0 + 0.10 * chubby
	mesh.scale = Vector3(fat, 1.0, fat)
	pivot.add_child(mesh)

	_remember(pivot)
	return pivot


## Wajah: dua manik mata berkilau, mulut mungil, pipi merona, dan alis tipis.
static func _build_face(s: Dictionary) -> Node3D:
	var face: Node3D = Node3D.new()
	face.name = "Face"
	face.position = Vector3(0.0, HEAD_CENTER_Y, 0.0)

	var hair_color: Color = s["hair"]

	for i: int in 2:
		var side: String = "L"
		var dir: float = -1.0
		if i == 1:
			side = "R"
			dir = 1.0

		# Manik mata bulat mengkilap.
		var eye: MeshInstance3D = _sphere("Eye" + side, EYE_RADIUS, EYE_COLOR,
			SEG_LIMB_RADIAL + 1, SEG_BLOB_RINGS, 0.35)
		eye.position = Vector3(EYE_X * dir, EYE_Y, FRONT * EYE_Z)
		_remember(eye)
		face.add_child(eye)

		# Titik kilau putih kecil di sudut atas mata.
		var glint: MeshInstance3D = _sphere("Glint", GLINT_RADIUS, GLINT_COLOR,
			SEG_TINY_RADIAL, SEG_TINY_RINGS, 0.15)
		glint.position = Vector3(0.011 * dir, 0.012, FRONT * 0.026)
		eye.add_child(glint)

		# Pipi merona ditempel menempel kurva kepala (GDD 4.1 rosy cheeks #FF9AA2).
		var cheek: MeshInstance3D = _sphere("Cheek" + side, CHEEK_RADIUS, Palette.ROSY_CHEEK,
			SEG_BLOB_RADIAL, SEG_BLOB_RINGS)
		var normal: Vector3 = Vector3(0.52 * dir, -0.16, FRONT * 0.84).normalized()
		cheek.transform = Transform3D(_basis_facing(normal), normal * (HEAD_RADIUS - 0.012))
		cheek.scale = Vector3(1.0, 0.78, 0.30)
		_remember(cheek)
		face.add_child(cheek)

		# Alis tipis, sedikit dipuntir keluar agar menempel pada lengkung dahi.
		var brow: MeshInstance3D = _box("Brow" + side, Vector3(0.050, 0.013, 0.012), hair_color)
		brow.position = Vector3(EYE_X * dir, BROW_Y, FRONT * BROW_Z)
		brow.rotation_degrees = Vector3(0.0, -12.0 * dir * FRONT, 0.0)
		_remember(brow)
		face.add_child(brow)

	# Mulut mungil berbentuk oval pipih; ekspresi hanya menskala node ini.
	var mouth: MeshInstance3D = _sphere("Mouth", MOUTH_RADIUS, MOUTH_COLOR,
		SEG_BLOB_RADIAL, SEG_BLOB_RINGS, 0.5)
	mouth.position = Vector3(0.0, MOUTH_Y, FRONT * MOUTH_Z)
	mouth.scale = Vector3(1.0, 0.50, 0.45)
	_remember(mouth)
	face.add_child(mouth)

	return face


## Pivot bahu + kapsul lengan yang menggantung ke bawah.
static func _build_arm(s: Dictionary, dir: float) -> Node3D:
	var side: String = "R"
	if dir < 0.0:
		side = "L"
	var chubby: float = s["chubby"]
	var pivot: Node3D = Node3D.new()
	pivot.name = "Arm" + side
	pivot.position = Vector3(SHOULDER_X * (1.0 + 0.28 * chubby) * dir, SHOULDER_Y, 0.0)

	var cloth: Color = s["cloth"]
	var mesh: MeshInstance3D = _capsule("Arm" + side + "Mesh", ARM_LENGTH, ARM_RADIUS, cloth,
		SEG_LIMB_RADIAL, SEG_LIMB_RINGS)
	mesh.position = Vector3(0.0, -ARM_LENGTH * 0.5, 0.0)
	pivot.add_child(mesh)

	# Telapak tangan mungil berwarna kulit di ujung lengan.
	var skin: Color = s["skin"]
	var hand: MeshInstance3D = _sphere("Hand" + side, ARM_RADIUS * 1.15, skin,
		SEG_TINY_RADIAL, SEG_TINY_RINGS)
	hand.position = Vector3(0.0, -ARM_LENGTH + 0.01, 0.0)
	pivot.add_child(hand)

	_remember(pivot)
	return pivot


## Pivot pinggul + kapsul kaki pendek.
static func _build_leg(s: Dictionary, dir: float) -> Node3D:
	var side: String = "R"
	if dir < 0.0:
		side = "L"
	var pivot: Node3D = Node3D.new()
	pivot.name = "Leg" + side
	pivot.position = Vector3(HIP_X * dir, HIP_Y, 0.0)

	var cloth: Color = s["cloth"]
	var trousers: Color = _shift(cloth, -0.22)
	var mesh: MeshInstance3D = _capsule("Leg" + side + "Mesh", LEG_LENGTH, LEG_RADIUS, trousers,
		SEG_LIMB_RADIAL, SEG_LIMB_RINGS)
	mesh.position = Vector3(0.0, -LEG_LENGTH * 0.5, 0.0)
	pivot.add_child(mesh)

	_remember(pivot)
	return pivot


## Koordinat Z tepat di depan permukaan kapsul badan pada ketinggian `y` (koordinat
## lokal badan, 0.0 di pangkal), ditambah `offset` supaya kain celemek tidak menembus
## badan. Radius kapsul menyempit di tutup atas/bawah, jadi celemek mengikuti lekuk
## badan alih-alih melayang.
##
## Hasilnya sudah dikalikan FRONT, jadi ia BERTANDA NEGATIF seperti seluruh
## detail depan lainnya. Tanpa itu fungsi ini mengembalikan jari-jari telanjang
## dan celemek mendarat di punggung karakter -- persis kebalikan dari namanya.
static func _body_front_z(s: Dictionary, y: float, offset: float) -> float:
	var half: float = BODY_HEIGHT * 0.5
	var cyl_half: float = maxf(half - BODY_RADIUS, 0.0)
	var dy: float = absf(y - half)
	var r: float = BODY_RADIUS
	if dy > cyl_half:
		# Berada di tutup setengah bola: radius mengecil mengikuti lingkaran.
		var t: float = dy - cyl_half
		r = sqrt(maxf(BODY_RADIUS * BODY_RADIUS - t * t, 0.0))
	var chubby: float = s["chubby"]
	var fat: float = 1.0 + 0.32 * chubby
	return FRONT * (r * fat + offset)


## Celemek staf (GDD 3.4: warnanya mencerminkan tier keahlian). Node "Apron" selalu
## dibuat agar kontrak nama terpenuhi, walau pelanggan biasa tidak memakai celemek.
static func _build_apron(s: Dictionary) -> Node3D:
	var apron: Node3D = Node3D.new()
	apron.name = "Apron"

	var raw: Variant = s["apron"]
	if not (raw is Color):
		return apron
	var color: Color = raw

	var chubby: float = s["chubby"]
	var fat: float = 1.0 + 0.32 * chubby

	# Rok celemek lebar menutup perut.
	var skirt: MeshInstance3D = _box("ApronSkirt", Vector3(0.215 * fat, 0.170, 0.018), color)
	skirt.position = Vector3(0.0, 0.105, _body_front_z(s, 0.105, 0.010))
	apron.add_child(skirt)

	# Dada celemek yang lebih sempit mengikuti kapsul badan yang meruncing.
	var bib: MeshInstance3D = _box("ApronBib", Vector3(0.135, 0.100, 0.016), color)
	bib.position = Vector3(0.0, 0.222, _body_front_z(s, 0.222, 0.008))
	apron.add_child(bib)

	# Dua tali bahu.
	for i: int in 2:
		var dir: float = -1.0
		if i == 1:
			dir = 1.0
		var strap: MeshInstance3D = _box("ApronStrap", Vector3(0.024, 0.095, 0.014), color)
		strap.position = Vector3(0.052 * dir, 0.272, _body_front_z(s, 0.272, 0.004) * 0.75)
		strap.rotation_degrees = Vector3(0.0, 0.0, 10.0 * dir)
		apron.add_child(strap)

	return apron


# ===========================================================================
# RAMBUT
# ===========================================================================

## Rambut: tempurung dasar + variasi sesuai `hair_style`. Gaya asing jatuh ke "pendek".
static func _build_hair(s: Dictionary) -> Node3D:
	var hair: Node3D = Node3D.new()
	hair.name = "Hair"
	hair.position = Vector3(0.0, HEAD_CENTER_Y, 0.0)

	var color: Color = s["hair"]
	var style: String = s["hair_style"]

	# Tempurung kepala dipakai semua gaya, tinggi & tebalnya saja yang berbeda.
	var cap_scale: float = 1.0
	match style:
		"cepak":
			cap_scale = 0.72
		"jenggot":
			cap_scale = 0.80
		"spike":
			cap_scale = 0.92
		_:
			cap_scale = 1.0
	var cap: MeshInstance3D = _hemisphere("HairCap", HAIR_CAP_RADIUS, color,
		SEG_CAP_RADIAL, SEG_CAP_RINGS)
	cap.position = Vector3(0.0, -0.020, 0.0)
	cap.scale = Vector3(1.0, cap_scale, 1.0)
	hair.add_child(cap)

	match style:
		"belah_samping":
			# Poni belah samping: satu sisi lebar, satu sisi tipis.
			var wide: MeshInstance3D = _box("HairFringeA", Vector3(0.135, 0.085, 0.035), color)
			wide.position = Vector3(-0.045, 0.100, FRONT * 0.197)
			hair.add_child(wide)
			var thin: MeshInstance3D = _box("HairFringeB", Vector3(0.080, 0.062, 0.032), color)
			thin.position = Vector3(0.085, 0.112, FRONT * 0.190)
			hair.add_child(thin)
		"kuncir_ganda":
			_add_fringe(hair, color)
			for i: int in 2:
				var dir: float = -1.0
				if i == 1:
					dir = 1.0
				var tail: MeshInstance3D = _capsule("HairTail", 0.135, 0.046, color,
					SEG_TINY_RADIAL, SEG_LIMB_RINGS)
				tail.position = Vector3(0.215 * dir, -0.010, 0.020)
				tail.rotation_degrees = Vector3(0.0, 0.0, 22.0 * dir)
				hair.add_child(tail)
		"bob":
			_add_fringe(hair, color)
			# Rok rambut lurus sebatas rahang.
			var skirt: MeshInstance3D = _cylinder("HairBob", 0.135, HAIR_CAP_RADIUS * 0.99,
				HAIR_CAP_RADIUS * 0.94, color, SEG_CAP_RADIAL, false, false)
			skirt.position = Vector3(0.0, -0.075, 0.0)
			hair.add_child(skirt)
		"spike":
			for i: int in 3:
				var spike: MeshInstance3D = _cylinder("HairSpike", 0.085, 0.0, 0.045, color,
					SEG_BLOB_RADIAL, false, true)
				spike.position = Vector3(-0.085 + 0.085 * float(i), 0.215, FRONT * 0.055)
				spike.rotation_degrees = Vector3(-18.0, 0.0, -14.0 + 14.0 * float(i))
				hair.add_child(spike)
		"panjang_kepang":
			_add_fringe(hair, color)
			var braid: MeshInstance3D = _capsule("HairBraid", 0.240, 0.050, color,
				SEG_BLOB_RADIAL, SEG_LIMB_RINGS)
			braid.position = Vector3(0.0, -0.135, 0.165)
			braid.rotation_degrees = Vector3(-12.0, 0.0, 0.0)
			hair.add_child(braid)
			var knot: MeshInstance3D = _sphere("HairKnot", 0.032, _shift(color, -0.12),
				SEG_TINY_RADIAL, SEG_TINY_RINGS)
			knot.position = Vector3(0.0, -0.250, 0.195)
			hair.add_child(knot)
		"sanggul":
			_add_fringe(hair, color)
			var bun: MeshInstance3D = _sphere("HairBun", 0.092, color,
				SEG_BLOB_RADIAL, SEG_BLOB_RINGS)
			bun.position = Vector3(0.0, 0.135, 0.185)
			hair.add_child(bun)
		"ikal":
			_add_fringe(hair, color)
			for i: int in 3:
				var curl: MeshInstance3D = _sphere("HairCurl", 0.070, color,
					SEG_TINY_RADIAL, SEG_TINY_RINGS)
				var ang: float = deg_to_rad(-55.0 + 55.0 * float(i))
				curl.position = Vector3(sin(ang) * 0.205, -0.045, cos(ang) * 0.180)
				hair.add_child(curl)
		"ombre":
			_add_fringe(hair, color)
			# Ujung rambut memudar ke pastel manis (GDD 3.5: "rambut ombre pastel").
			var tip_color: Color = color.lerp(Palette.PASTEL_STRAWBERRY, 0.65)
			for i: int in 2:
				var dir: float = -1.0
				if i == 1:
					dir = 1.0
				var tip: MeshInstance3D = _sphere("HairOmbre", 0.072, tip_color,
					SEG_TINY_RADIAL, SEG_TINY_RINGS)
				tip.position = Vector3(0.190 * dir, -0.070, 0.035)
				hair.add_child(tip)
		"jenggot":
			_add_fringe(hair, color)
			# Jenggot koki terpangkas rapi di sekeliling dagu.
			var beard: MeshInstance3D = _sphere("Beard", 0.135, color,
				SEG_BLOB_RADIAL, SEG_BLOB_RINGS)
			beard.position = Vector3(0.0, -0.115, FRONT * 0.095)
			beard.scale = Vector3(1.05, 0.85, 0.95)
			hair.add_child(beard)
		"cepak":
			pass  # Cukup tempurung tipis, tanpa poni.
		_:
			_add_fringe(hair, color)  # "pendek" dan seluruh nilai tak dikenal.
	return hair


## Poni sederhana menutup dahi.
static func _add_fringe(hair: Node3D, color: Color) -> void:
	var fringe: MeshInstance3D = _box("HairFringe", Vector3(0.200, 0.080, 0.035), color)
	fringe.position = Vector3(0.0, 0.102, FRONT * 0.196)
	fringe.rotation_degrees = Vector3(6.0, 0.0, 0.0)
	hair.add_child(fringe)


# ===========================================================================
# TOPI
# ===========================================================================

## Topi. Node "Hat" selalu dibuat (kontrak nama), isinya bisa kosong untuk "none"
## maupun untuk nilai yang tidak dikenal.
static func _build_hat(s: Dictionary) -> Node3D:
	var hat: Node3D = Node3D.new()
	hat.name = "Hat"
	hat.position = Vector3(0.0, HEAD_CENTER_Y, 0.0)

	var kind: String = s["hat"]
	var cloth: Color = s["cloth"]
	var accent: Color = Palette.PASTEL_MINT
	var raw_apron: Variant = s["apron"]
	if raw_apron is Color:
		accent = raw_apron

	match kind:
		"topi_pet":
			# Topi pet kasir, sengaja dipakai miring (GDD 3.5: Dimas).
			var crown: MeshInstance3D = _hemisphere("HatCrown", 0.232, accent,
				SEG_CAP_RADIAL, SEG_CAP_RINGS)
			crown.position = Vector3(0.0, 0.005, 0.0)
			crown.scale = Vector3(1.0, 0.85, 1.0)
			hat.add_child(crown)
			var visor: MeshInstance3D = _box("HatVisor", Vector3(0.235, 0.020, 0.130),
				_shift(accent, -0.10))
			visor.position = Vector3(0.0, 0.020, FRONT * 0.190)
			visor.rotation_degrees = Vector3(-8.0, 0.0, 0.0)
			hat.add_child(visor)
			hat.rotation_degrees = Vector3(-5.0, 0.0, -14.0)
		"bando":
			hat.add_child(_headband(Palette.PASTEL_STRAWBERRY))
		"bando_kelinci":
			# Bando telinga kelinci empuk (GDD 3.5: Luna).
			hat.add_child(_headband(Palette.PASTEL_STRAWBERRY))
			for i: int in 2:
				var dir: float = -1.0
				if i == 1:
					dir = 1.0
				var ear: MeshInstance3D = _capsule("BunnyEar", 0.150, 0.034,
					Palette.PASTEL_STRAWBERRY, SEG_TINY_RADIAL, SEG_LIMB_RINGS)
				ear.position = Vector3(0.088 * dir, 0.290, 0.0)
				ear.rotation_degrees = Vector3(0.0, 0.0, -13.0 * dir)
				hat.add_child(ear)
		"topi_koki":
			hat.add_child(_toque_band(Palette.FLOUR_WHITE, 0.060, 0.205))
			var puff: MeshInstance3D = _sphere("ChefPuff", 0.170, Palette.FLOUR_WHITE,
				SEG_LIMB_RADIAL + 1, SEG_BLOB_RINGS)
			puff.position = Vector3(0.0, 0.290, 0.0)
			puff.scale = Vector3(1.15, 0.82, 1.15)
			hat.add_child(puff)
			hat.rotation_degrees = Vector3(0.0, 0.0, 8.0)
		"toque":
			# Topi toque Prancis yang menjulang (GDD 3.5: Sophie & Pierre).
			hat.add_child(_toque_band(Palette.FLOUR_WHITE, 0.065, 0.208))
			var tower: MeshInstance3D = _cylinder("ToqueTower", 0.190, 0.172, 0.178,
				Palette.FLOUR_WHITE, SEG_CAP_RADIAL, false, false)
			tower.position = Vector3(0.0, 0.335, 0.0)
			hat.add_child(tower)
			var top: MeshInstance3D = _sphere("ToqueTop", 0.175, Palette.FLOUR_WHITE,
				SEG_LIMB_RADIAL + 1, SEG_TINY_RINGS)
			top.position = Vector3(0.0, 0.425, 0.0)
			top.scale = Vector3(1.05, 0.62, 1.05)
			hat.add_child(top)
		"bandana":
			var wrap: MeshInstance3D = _hemisphere("BandanaWrap", 0.238, Palette.GOLDEN_CRUST,
				SEG_CAP_RADIAL, SEG_TINY_RINGS)
			wrap.position = Vector3(0.0, -0.010, 0.0)
			wrap.scale = Vector3(1.0, 0.62, 1.0)
			hat.add_child(wrap)
			var knot: MeshInstance3D = _sphere("BandanaKnot", 0.045, Palette.GOLDEN_CRUST,
				SEG_TINY_RADIAL, SEG_TINY_RINGS)
			knot.position = Vector3(0.0, 0.030, 0.215)
			hat.add_child(knot)
			var tail: MeshInstance3D = _box("BandanaTail", Vector3(0.035, 0.090, 0.020),
				Palette.GOLDEN_CRUST)
			tail.position = Vector3(0.0, -0.035, 0.225)
			tail.rotation_degrees = Vector3(18.0, 0.0, 0.0)
			hat.add_child(tail)
		"hachimaki":
			# Ikat kepala hachimaki hitam-putih khas chef Jepang (GDD 3.5: Aoi).
			hat.add_child(_headband(Palette.FLOUR_WHITE))
			var mark: MeshInstance3D = _box("HachimakiMark", Vector3(0.048, 0.048, 0.014),
				Palette.DANGER)
			mark.position = Vector3(0.0, 0.135, FRONT * 0.185)
			hat.add_child(mark)
			var tail2: MeshInstance3D = _box("HachimakiTail", Vector3(0.030, 0.120, 0.016),
				Palette.FLOUR_WHITE)
			tail2.position = Vector3(0.045, 0.040, 0.225)
			tail2.rotation_degrees = Vector3(14.0, 0.0, -10.0)
			hat.add_child(tail2)
		"helm":
			# Helm bundar menggemaskan kurir RotiFood (GDD 3.6).
			var shell: MeshInstance3D = _hemisphere("HelmetShell", 0.252, cloth,
				SEG_CAP_RADIAL, SEG_CAP_RINGS, 0.55)
			shell.position = Vector3(0.0, -0.030, 0.0)
			shell.scale = Vector3(1.0, 1.05, 1.0)
			hat.add_child(shell)
			var visor2: MeshInstance3D = _box("HelmetVisor", Vector3(0.245, 0.080, 0.040),
				DARK_GLASS)
			visor2.position = Vector3(0.0, 0.035, FRONT * 0.195)
			visor2.rotation_degrees = Vector3(6.0, 0.0, 0.0)
			hat.add_child(visor2)
			var strap: MeshInstance3D = _box("HelmetStrap", Vector3(0.230, 0.018, 0.018),
				DARK_GLASS)
			strap.position = Vector3(0.0, -0.140, FRONT * 0.060)
			hat.add_child(strap)
		"peci":
			# Peci hitam Pak Lurah (GDD 3.0.A).
			var peci: MeshInstance3D = _cylinder("Peci", 0.115, 0.186, 0.196,
				Color(0.129, 0.141, 0.220), SEG_CAP_RADIAL, true, false)
			peci.position = Vector3(0.0, 0.195, 0.0)
			peci.rotation_degrees = Vector3(0.0, 0.0, 5.0)
			hat.add_child(peci)
		_:
			pass  # "none" dan nilai tak dikenal: tanpa topi.
	return hat


## Bando melengkung dari ubun-ubun ke telinga (torus diputar tegak).
static func _headband(color: Color) -> MeshInstance3D:
	var band: MeshInstance3D = _torus("Headband", 0.208, 0.240, color,
		SEG_CYL_LOW, SEG_TORUS_SEGMENTS)
	band.position = Vector3(0.0, 0.020, 0.0)
	band.rotation_degrees = Vector3(90.0, 0.0, 0.0)
	return band


## Pita bawah topi koki / toque.
static func _toque_band(color: Color, height: float, y: float) -> MeshInstance3D:
	var band: MeshInstance3D = _cylinder("ToqueBand", height, 0.190, 0.190, color,
		SEG_CAP_RADIAL, false, false)
	band.position = Vector3(0.0, y, 0.0)
	return band


# ===========================================================================
# AKSESORI (kosakata StaffDB + tambahan pelanggan / kurir / Pak Lurah)
# ===========================================================================

## Pasang satu aksesori. Nilai yang tidak dikenal diabaikan tanpa error (degradasi aman).
static func _attach_accessory(id: String, s: Dictionary, parts: Dictionary) -> void:
	var head: Node3D = parts["head"]
	var face: Node3D = parts["face"]
	var hair: Node3D = parts["hair"]
	var body: Node3D = parts["body"]
	var apron: Node3D = parts["apron"]
	var arm_l: Node3D = parts["arm_l"]
	var arm_r: Node3D = parts["arm_r"]

	match id:
		"kacamata_bulat":
			_add_glasses(face, Palette.DARK_CHOCOLATE, 0.0)
		"kacamata_emas":
			_add_glasses(face, Palette.GOLD_STAR, 0.65)
		"kacamata_rantai":
			# Kacamata rantai emas vintage (GDD 3.5: Mawar).
			_add_glasses(face, Palette.GOLD_STAR, 0.65)
			for i: int in 2:
				var dir: float = -1.0
				if i == 1:
					dir = 1.0
				var chain: MeshInstance3D = _box("Chain", Vector3(0.012, 0.075, 0.012),
					Palette.GOLD_STAR, 0.4, 0.6)
				chain.position = Vector3(0.130 * dir, -0.045, FRONT * 0.135)
				chain.rotation_degrees = Vector3(0.0, 0.0, 12.0 * dir)
				face.add_child(chain)
		"pita_kuning":
			# Dua pita kuning mentega di pangkal kuncir (GDD 3.5: Sari).
			for i: int in 2:
				var dir: float = -1.0
				if i == 1:
					dir = 1.0
				for j: int in 2:
					var wing: float = -1.0
					if j == 1:
						wing = 1.0
					var petal: MeshInstance3D = _box("Ribbon", Vector3(0.052, 0.038, 0.022),
						Palette.BUTTER_YELLOW)
					petal.position = Vector3(0.185 * dir, 0.075 + 0.035 * wing, 0.030)
					petal.rotation_degrees = Vector3(0.0, 0.0, 26.0 * wing)
					hair.add_child(petal)
		"jepit_stroberi":
			# Jepit rambut stroberi imut (GDD 3.5: Lili).
			var berry: MeshInstance3D = _sphere("Strawberry", 0.032, Palette.DANGER,
				SEG_TINY_RADIAL, SEG_TINY_RINGS)
			berry.position = Vector3(-0.165, 0.125, FRONT * 0.105)
			hair.add_child(berry)
			var leaf: MeshInstance3D = _box("StrawberryLeaf", Vector3(0.030, 0.012, 0.022),
				Palette.SUCCESS)
			leaf.position = Vector3(-0.165, 0.152, FRONT * 0.105)
			hair.add_child(leaf)
		"bando_gingham":
			# Kotak-kotak gingham di atas bando (GDD 3.5: Maya).
			for i: int in 3:
				var ang: float = deg_to_rad(-42.0 + 42.0 * float(i))
				var square: MeshInstance3D = _box("GinghamSquare",
					Vector3(0.042, 0.042, 0.026), Palette.GINGHAM_B)
				square.position = Vector3(sin(ang) * 0.224, cos(ang) * 0.224, 0.0)
				square.rotation_degrees = Vector3(0.0, 0.0, -rad_to_deg(ang))
				head.add_child(square)
		"pin_senyum":
			var pin: MeshInstance3D = _cylinder("PinSenyum", 0.010, 0.024, 0.024,
				Palette.BUTTER_YELLOW, SEG_CYL_LOW, true, true)
			pin.position = Vector3(0.060, 0.255, FRONT * 0.145)
			pin.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			body.add_child(pin)
		"pin_bintang":
			var star: MeshInstance3D = _cylinder("PinBintang", 0.010, 0.028, 0.028,
				Palette.GOLD_STAR, SEG_BLOB_RADIAL, true, true, 0.35, 0.6)
			star.position = Vector3(-0.058, 0.250, FRONT * 0.145)
			star.rotation_degrees = Vector3(90.0, 0.0, 18.0)
			body.add_child(star)
		"jam_vintage":
			# Jam tangan era 2000-an di pergelangan kiri (GDD 3.5: Reza).
			var strap: MeshInstance3D = _box("WatchStrap", Vector3(0.100, 0.026, 0.100),
				Palette.DARK_CHOCOLATE)
			strap.position = Vector3(0.0, -0.132, 0.0)
			strap.scale = Vector3(1.0, 1.0, 1.0)
			arm_l.add_child(strap)
			var dial: MeshInstance3D = _box("WatchDial", Vector3(0.042, 0.030, 0.014),
				Palette.CHALK_WHITE)
			dial.position = Vector3(0.0, -0.132, FRONT * 0.046)
			arm_l.add_child(dial)
		"buku_saku":
			# Buku catatan mini di saku celemek (GDD 3.5: Dewi).
			var book: MeshInstance3D = _box("PocketBook", Vector3(0.062, 0.082, 0.014),
				Palette.PARCHMENT)
			book.position = Vector3(0.062, 0.135, FRONT * 0.150)
			book.rotation_degrees = Vector3(0.0, 0.0, -8.0)
			apron.add_child(book)
		"dasi_kupu":
			# Dasi kupu-kupu merah marun (GDD 3.5: Kenji).
			for i: int in 2:
				var dir2: float = -1.0
				if i == 1:
					dir2 = 1.0
				var wing2: MeshInstance3D = _box("BowTieWing", Vector3(0.042, 0.034, 0.020),
					Palette.APRON_MAROON)
				wing2.position = Vector3(0.033 * dir2, 0.300, FRONT * 0.120)
				wing2.rotation_degrees = Vector3(0.0, 0.0, 22.0 * dir2)
				body.add_child(wing2)
			var knot2: MeshInstance3D = _box("BowTieKnot", Vector3(0.020, 0.024, 0.022),
				_shift(Palette.APRON_MAROON, -0.10))
			knot2.position = Vector3(0.0, 0.300, FRONT * 0.126)
			body.add_child(knot2)
		"anting_mutiara":
			for i: int in 2:
				var dir3: float = -1.0
				if i == 1:
					dir3 = 1.0
				var pearl: MeshInstance3D = _sphere("Pearl", 0.022, Palette.FLOUR_WHITE,
					SEG_TINY_RADIAL, SEG_TINY_RINGS, 0.25, 0.25)
				pearl.position = Vector3(0.208 * dir3, -0.055, 0.010)
				head.add_child(pearl)
		"kalung_mutiara":
			var necklace: MeshInstance3D = _torus("Necklace", 0.088, 0.106,
				Palette.FLOUR_WHITE, SEG_CYL_LOW, SEG_TORUS_SEGMENTS, 0.25, 0.25)
			necklace.position = Vector3(0.0, 0.292, 0.0)
			body.add_child(necklace)
		"kumis":
			# Kumis tipis retro (GDD 3.5: Tejo, Aris) & kumis ramah Pak Lurah.
			for i: int in 2:
				var dir4: float = -1.0
				if i == 1:
					dir4 = 1.0
				var whisker: MeshInstance3D = _box("Moustache", Vector3(0.042, 0.015, 0.014),
					HAIR_BLACK)
				whisker.position = Vector3(0.024 * dir4, -0.030, FRONT * 0.203)
				whisker.rotation_degrees = Vector3(0.0, 0.0, 10.0 * dir4)
				face.add_child(whisker)
		"pena_telinga":
			var pen: MeshInstance3D = _cylinder("EarPen", 0.075, 0.009, 0.009,
				Palette.PASTEL_PERIWINKLE, SEG_BLOB_RADIAL, true, true)
			pen.position = Vector3(0.190, 0.010, 0.025)
			pen.rotation_degrees = Vector3(18.0, 0.0, -24.0)
			head.add_child(pen)
		"sarung_tangan":
			_add_mittens(arm_l, arm_r, Palette.VANILLA_CREAM, 0.9)
		"sarung_tangan_satin":
			_add_mittens(arm_l, arm_r, Palette.FLOUR_WHITE, 0.25)
		"handuk_pundak":
			# Handuk kecil tersampir di pundak (GDD 3.5: Doni).
			var towel: MeshInstance3D = _box("Towel", Vector3(0.105, 0.022, 0.150),
				Palette.PASTEL_MINT)
			towel.position = Vector3(-0.115, 0.292, 0.0)
			towel.rotation_degrees = Vector3(0.0, 0.0, 16.0)
			body.add_child(towel)
		"tusuk_konde":
			# Tusuk konde kayu menembus sanggul (GDD 3.5: Tari).
			var stick: MeshInstance3D = _cylinder("HairPin", 0.150, 0.008, 0.008,
				Palette.PINE_WOOD, SEG_TINY_RADIAL, true, true)
			stick.position = Vector3(0.0, 0.135, 0.185)
			stick.rotation_degrees = Vector3(0.0, 0.0, 90.0)
			head.add_child(stick)
		"syal_merah":
			# Syal leher merah (GDD 3.5: Sophie).
			var scarf: MeshInstance3D = _torus("Scarf", 0.102, 0.140, Palette.DANGER,
				SEG_CYL_LOW, SEG_TORUS_SEGMENTS)
			scarf.position = Vector3(0.0, 0.295, 0.0)
			body.add_child(scarf)
		"pisau_kayu":
			# Pisau roti bergagang kayu di kantong celemek (GDD 3.5: Danu).
			var knife: MeshInstance3D = _box("BreadKnife", Vector3(0.016, 0.115, 0.032),
				Palette.PINE_WOOD)
			knife.position = Vector3(-0.062, 0.150, FRONT * 0.150)
			knife.rotation_degrees = Vector3(0.0, 0.0, 7.0)
			apron.add_child(knife)
		"medali":
			# Medali kuliner (GDD 3.5: Pierre).
			var ribbon: MeshInstance3D = _box("MedalRibbon", Vector3(0.026, 0.070, 0.012),
				Palette.DANGER)
			ribbon.position = Vector3(0.0, 0.292, FRONT * 0.128)
			body.add_child(ribbon)
			var medal: MeshInstance3D = _cylinder("Medal", 0.012, 0.032, 0.032,
				Palette.GOLD_STAR, SEG_CYL_LOW, true, true, 0.3, 0.7)
			medal.position = Vector3(0.0, 0.245, FRONT * 0.134)
			medal.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			body.add_child(medal)
		"gelang_karet":
			# Gelang karet oranye sporty (GDD 3.5: Rian).
			var band2: MeshInstance3D = _torus("RubberBand", 0.044, 0.058,
				Palette.WARMER_LAMP, SEG_CYL_LOW, SEG_TORUS_SEGMENTS)
			band2.position = Vector3(0.0, -0.140, 0.0)
			arm_r.add_child(band2)
		"kerah_kemeja":
			for i: int in 2:
				var dir5: float = -1.0
				if i == 1:
					dir5 = 1.0
				var collar: MeshInstance3D = _box("Collar", Vector3(0.062, 0.048, 0.022),
					Palette.FLOUR_WHITE)
				collar.position = Vector3(0.052 * dir5, 0.288, FRONT * 0.105)
				collar.rotation_degrees = Vector3(0.0, 0.0, 26.0 * dir5)
				body.add_child(collar)
		"dasi_kerja":
			var tie: MeshInstance3D = _box("NeckTie", Vector3(0.032, 0.130, 0.016),
				Palette.APRON_NAVY)
			tie.position = Vector3(0.0, 0.215, FRONT * 0.128)
			body.add_child(tie)
		"dasi_merah":
			var tie2: MeshInstance3D = _box("SchoolTie", Vector3(0.030, 0.095, 0.016),
				Palette.DANGER)
			tie2.position = Vector3(0.0, 0.230, FRONT * 0.126)
			body.add_child(tie2)
		"ponsel":
			# Ponsel berisi nomor pesanan digital (GDD 3.6.A.3).
			var phone: MeshInstance3D = _box("Phone", Vector3(0.046, 0.076, 0.012), DARK_GLASS)
			phone.position = Vector3(0.0, -0.170, FRONT * 0.030)
			phone.rotation_degrees = Vector3(28.0, 0.0, 0.0)
			arm_r.add_child(phone)
		"jas_hujan":
			# Jas hujan kuning menggemaskan (GDD 10.2) menutup badan + tudung di kepala.
			var poncho: MeshInstance3D = _cylinder("Raincoat", 0.300, 0.105, 0.215,
				Palette.RAINCOAT_YELLOW, SEG_CAP_RADIAL, false, false, 0.6)
			poncho.position = Vector3(0.0, 0.150, 0.0)
			body.add_child(poncho)
			var hood: MeshInstance3D = _hemisphere("RaincoatHood", 0.268,
				Palette.RAINCOAT_YELLOW, SEG_CAP_RADIAL, SEG_TINY_RINGS, 0.6)
			hood.position = Vector3(0.0, -0.075, 0.030)
			hood.scale = Vector3(1.0, 1.12, 1.05)
			head.add_child(hood)
		_:
			pass  # Aksesori tak dikenal: diabaikan dengan aman.


## Kacamata bulat: dua bingkai torus tegak + jembatan hidung.
static func _add_glasses(face: Node3D, color: Color, metal: float) -> void:
	for i: int in 2:
		var dir: float = -1.0
		if i == 1:
			dir = 1.0
		var rim: MeshInstance3D = _torus("Rim", 0.030, 0.048, color,
			SEG_TORUS_RINGS, SEG_TORUS_SEGMENTS, 0.4, metal)
		rim.position = Vector3(EYE_X * dir, EYE_Y, FRONT * (EYE_Z - 0.004))
		rim.rotation_degrees = Vector3(90.0, 0.0, 0.0)
		face.add_child(rim)
	var bridge: MeshInstance3D = _box("GlassBridge", Vector3(0.048, 0.010, 0.010),
		color, 0.4, metal)
	bridge.position = Vector3(0.0, EYE_Y, FRONT * (EYE_Z + 0.006))
	face.add_child(bridge)


## Sarung tangan empuk di kedua telapak.
static func _add_mittens(arm_l: Node3D, arm_r: Node3D, color: Color, rough: float) -> void:
	var arms: Array[Node3D] = [arm_l, arm_r]
	for arm: Node3D in arms:
		var mitten: MeshInstance3D = _sphere("Mitten", ARM_RADIUS * 1.45, color,
			SEG_BLOB_RADIAL, SEG_TINY_RINGS, rough)
		mitten.position = Vector3(0.0, -ARM_LENGTH + 0.008, 0.0)
		arm.add_child(mitten)


# ===========================================================================
# BARANG BAWAAN
# ===========================================================================

## Pasang satu barang bawaan. Nilai tak dikenal diabaikan dengan aman.
static func _attach_prop(id: String, s: Dictionary, parts: Dictionary) -> void:
	var root: Node3D = parts["root"]
	var body: Node3D = parts["body"]
	var arm_l: Node3D = parts["arm_l"]
	var arm_r: Node3D = parts["arm_r"]
	var cloth: Color = s["cloth"]

	match id:
		"tas_belanja":
			# Tas belanja besar Emak-Emak Arisan (The Bulk Buyer).
			var bag: MeshInstance3D = _box("ShoppingBag", Vector3(0.165, 0.185, 0.095),
				Palette.GINGHAM_A)
			bag.position = Vector3(0.020, -0.290, 0.0)
			arm_r.add_child(bag)
			var handle: MeshInstance3D = _box("BagHandle", Vector3(0.105, 0.055, 0.016),
				Palette.CARAMEL)
			handle.position = Vector3(0.020, -0.200, 0.0)
			arm_r.add_child(handle)
		"tas_sekolah":
			var pack: MeshInstance3D = _box("SchoolBag", Vector3(0.170, 0.180, 0.090),
				Palette.APRON_NAVY)
			pack.position = Vector3(0.0, 0.195, 0.145)
			body.add_child(pack)
			var flap: MeshInstance3D = _box("SchoolBagFlap", Vector3(0.160, 0.055, 0.080),
				_shift(Palette.APRON_NAVY, 0.12))
			flap.position = Vector3(0.0, 0.265, 0.150)
			body.add_child(flap)
		"ransel_termal":
			# Ransel termal kubus kurir RotiFood (GDD 3.6).
			var box_bag: MeshInstance3D = _box("ThermalBox", Vector3(0.205, 0.215, 0.135),
				_shift(cloth, -0.18))
			box_bag.position = Vector3(0.0, 0.225, 0.165)
			body.add_child(box_bag)
			var logo: MeshInstance3D = _box("ThermalLogo", Vector3(0.100, 0.100, 0.014),
				Palette.FLOUR_WHITE)
			logo.position = Vector3(0.0, 0.228, 0.238)
			body.add_child(logo)
			for i: int in 2:
				var dir: float = -1.0
				if i == 1:
					dir = 1.0
				var strap: MeshInstance3D = _box("ThermalStrap", Vector3(0.028, 0.170, 0.020),
					_shift(cloth, -0.32))
				strap.position = Vector3(0.070 * dir, 0.245, FRONT * 0.115)
				body.add_child(strap)
		"mangkuk_adonan":
			# Mangkuk adonan yang dipeluk di depan dada saat memindahkan adonan
			# dari mixer ke oven. Ditempel ke BADAN, bukan ke satu lengan, supaya
			# tetap terbaca "dijunjung dua tangan" saat karakter berjalan.
			var bowl: MeshInstance3D = _sphere("DoughBowl", 0.092,
				Color(0.807843, 0.831373, 0.850980), SEG_BLOB_RADIAL, SEG_BLOB_RINGS)
			bowl.scale = Vector3(1.0, 0.62, 1.0)
			bowl.position = Vector3(0.0, 0.105, FRONT * 0.165)
			body.add_child(bowl)
			var dough: MeshInstance3D = _sphere("DoughBall", 0.062, Palette.RAW_DOUGH,
				SEG_BLOB_RADIAL, SEG_BLOB_RINGS)
			dough.scale = Vector3(1.0, 0.72, 1.0)
			dough.position = Vector3(0.0, 0.150, FRONT * 0.165)
			body.add_child(dough)
		"loyang_roti":
			# Loyang roti matang yang dibawa dari oven ke rak display.
			var tray: MeshInstance3D = _box("BreadTray", Vector3(0.230, 0.022, 0.150),
				Color(0.556863, 0.588235, 0.619608))
			tray.position = Vector3(0.0, 0.120, FRONT * 0.170)
			body.add_child(tray)
			for i: int in 3:
				var bun: MeshInstance3D = _sphere("TrayBun", 0.040, Palette.GOLDEN_CRUST,
					SEG_BLOB_RADIAL, SEG_BLOB_RINGS)
				bun.scale = Vector3(1.0, 0.70, 1.0)
				bun.position = Vector3(-0.072 + float(i) * 0.072, 0.152, FRONT * 0.170)
				body.add_child(bun)
		"kantong_kertas":
			# Kantong kardus cokelat berpita yang sedang dibungkus di meja kasir
			# (GDD 3.6.A "Procedural Paper Bag"). Ditempel ke BADAN, bukan ke
			# satu lengan: kedua tangan yang sedang melipat tepinya bergerak
			# berlawanan arah, dan kantong yang ikut salah satu lengan akan
			# terlihat dikibas-kibaskan alih-alih dipegangi.
			var sack: MeshInstance3D = _box("PaperBag", Vector3(0.150, 0.170, 0.105),
				Palette.CARAMEL.lightened(0.28))
			sack.position = Vector3(0.0, 0.130, FRONT * 0.175)
			body.add_child(sack)
			# Bibir kantong yang terlipat ke luar.
			var lipat: MeshInstance3D = _box("PaperBagFold", Vector3(0.162, 0.034, 0.115),
				Palette.CARAMEL.lightened(0.42))
			lipat.position = Vector3(0.0, 0.222, FRONT * 0.175)
			body.add_child(lipat)
			# Pita manis melintang di badan kantong.
			var pita: MeshInstance3D = _box("PaperBagRibbon", Vector3(0.158, 0.026, 0.113),
				Palette.ROSY_CHEEK)
			pita.position = Vector3(0.0, 0.150, FRONT * 0.176)
			body.add_child(pita)
		"koper":
			# Koper kecil (Pak Lurah GDD 3.0.A / tas kerja pekerja kantoran).
			var case_mesh: MeshInstance3D = _box("Suitcase", Vector3(0.175, 0.130, 0.058),
				Palette.CARAMEL)
			case_mesh.position = Vector3(0.0, -0.255, 0.0)
			arm_r.add_child(case_mesh)
			var grip: MeshInstance3D = _box("SuitcaseGrip", Vector3(0.060, 0.032, 0.016),
				Palette.DARK_CHOCOLATE)
			grip.position = Vector3(0.0, -0.182, 0.0)
			arm_r.add_child(grip)
		"amplop":
			# Amplop berstempel resmi pemerintah daerah (GDD 3.0.A).
			var env: MeshInstance3D = _box("Envelope", Vector3(0.125, 0.088, 0.010),
				Palette.PARCHMENT)
			env.position = Vector3(0.0, -0.195, FRONT * 0.048)
			env.rotation_degrees = Vector3(62.0, 0.0, 0.0)
			arm_l.add_child(env)
			var stamp: MeshInstance3D = _box("EnvelopeStamp", Vector3(0.032, 0.032, 0.006),
				Palette.DANGER)
			stamp.position = Vector3(0.036, -0.186, FRONT * 0.070)
			stamp.rotation_degrees = Vector3(62.0, 0.0, 0.0)
			arm_l.add_child(stamp)
		"kamera":
			# Kamera kecil Food Vlogger yang selalu diacungkan.
			var cam: MeshInstance3D = _box("Camera", Vector3(0.090, 0.062, 0.050),
				DARK_GLASS)
			cam.position = Vector3(0.115, 0.585, FRONT * 0.165)
			root.add_child(cam)
			var lens: MeshInstance3D = _cylinder("CameraLens", 0.034, 0.024, 0.024,
				Palette.CHALKBOARD, SEG_CYL_LOW, true, true, 0.3, 0.4)
			lens.position = Vector3(0.115, 0.585, FRONT * 0.205)
			lens.rotation_degrees = Vector3(90.0, 0.0, 0.0)
			root.add_child(lens)
		"tas_tangan":
			var clutch: MeshInstance3D = _box("Handbag", Vector3(0.105, 0.082, 0.048),
				Palette.APRON_MAROON)
			clutch.position = Vector3(0.0, -0.250, 0.0)
			arm_l.add_child(clutch)
			var chain2: MeshInstance3D = _box("HandbagChain", Vector3(0.062, 0.042, 0.012),
				Palette.GOLD_STAR, 0.35, 0.6)
			chain2.position = Vector3(0.0, -0.196, 0.0)
			arm_l.add_child(chain2)
		"tanda_tanya":
			# Tanda tanya melayang untuk pelanggan "Si Galau" (The Indecisive).
			var mark: Node3D = Node3D.new()
			mark.name = "QuestionMark"
			mark.position = Vector3(0.155, 1.010, 0.0)
			mark.rotation_degrees = Vector3(0.0, 0.0, 8.0)
			root.add_child(mark)
			var qc: Color = Palette.WARMER_LAMP
			var bar_top: MeshInstance3D = _box("QTop", Vector3(0.070, 0.022, 0.022), qc)
			bar_top.position = Vector3(0.0, 0.120, 0.0)
			mark.add_child(bar_top)
			var bar_side: MeshInstance3D = _box("QSide", Vector3(0.022, 0.048, 0.022), qc)
			bar_side.position = Vector3(0.034, 0.096, 0.0)
			mark.add_child(bar_side)
			var bar_diag: MeshInstance3D = _box("QDiag", Vector3(0.022, 0.056, 0.022), qc)
			bar_diag.position = Vector3(0.012, 0.055, 0.0)
			bar_diag.rotation_degrees = Vector3(0.0, 0.0, 34.0)
			mark.add_child(bar_diag)
			var bar_stem: MeshInstance3D = _box("QStem", Vector3(0.022, 0.030, 0.022), qc)
			bar_stem.position = Vector3(0.0, 0.022, 0.0)
			mark.add_child(bar_stem)
			var dot: MeshInstance3D = _box("QDot", Vector3(0.024, 0.024, 0.024), qc)
			dot.position = Vector3(0.0, -0.022, 0.0)
			mark.add_child(dot)
		_:
			pass  # Barang bawaan tak dikenal: diabaikan dengan aman.


# ===========================================================================
# PEMBANTU MESH PRIMITIF (jumlah segmen SELALU eksplisit)
# ===========================================================================

## Material standar: warna solid + roughness saja (GDD 12.2, renderer Compatibility).
static func _material(color: Color, rough: float = 0.9, metal: float = 0.0) -> StandardMaterial3D:
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = clampf(rough, 0.0, 1.0)
	mat.metallic = clampf(metal, 0.0, 1.0)
	return mat


## Bungkus sebuah PrimitiveMesh menjadi MeshInstance3D bermaterial.
static func _instance(node_name: String, mesh: Mesh, color: Color,
		rough: float, metal: float) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.name = node_name
	mi.mesh = mesh
	mi.material_override = _material(color, rough, metal)
	# Tanpa bayangan real-time demi performa Android entry-level (GDD 12.2).
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _sphere(node_name: String, radius: float, color: Color, radial: int, rings: int,
		rough: float = 0.9, metal: float = 0.0) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = maxi(3, radial)
	mesh.rings = maxi(1, rings)
	return _instance(node_name, mesh, color, rough, metal)


static func _hemisphere(node_name: String, radius: float, color: Color, radial: int, rings: int,
		rough: float = 0.9) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius
	mesh.is_hemisphere = true
	mesh.radial_segments = maxi(3, radial)
	mesh.rings = maxi(1, rings)
	return _instance(node_name, mesh, color, rough, 0.0)


static func _capsule(node_name: String, height: float, radius: float, color: Color,
		radial: int, rings: int) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.001)
	mesh.radial_segments = maxi(3, radial)
	mesh.rings = maxi(1, rings)
	return _instance(node_name, mesh, color, 0.9, 0.0)


static func _box(node_name: String, size: Vector3, color: Color,
		rough: float = 0.9, metal: float = 0.0) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	return _instance(node_name, mesh, color, rough, metal)


static func _cylinder(node_name: String, height: float, top_r: float, bottom_r: float,
		color: Color, radial: int, cap_top: bool = true, cap_bottom: bool = true,
		rough: float = 0.9, metal: float = 0.0) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.radial_segments = maxi(3, radial)
	mesh.rings = 1
	mesh.cap_top = cap_top
	mesh.cap_bottom = cap_bottom
	return _instance(node_name, mesh, color, rough, metal)


static func _torus(node_name: String, inner: float, outer: float, color: Color,
		rings: int, ring_segments: int, rough: float = 0.9,
		metal: float = 0.0) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = maxi(3, rings)
	mesh.ring_segments = maxi(3, ring_segments)
	return _instance(node_name, mesh, color, rough, metal)


## Basis dengan sumbu -Z/+Z lokal mengarah ke `normal` (dipakai menempelkan pipi
## agar rata mengikuti lengkung kepala).
static func _basis_facing(normal: Vector3) -> Basis:
	var z_axis: Vector3 = normal.normalized()
	var up: Vector3 = Vector3.UP
	if absf(z_axis.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var x_axis: Vector3 = up.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


# ===========================================================================
# PEMBANTU DATA & UTILITAS
# ===========================================================================

## Lengkapi spec dengan seluruh nilai bawaan sehingga build() tidak pernah gagal.
static func _normalize(spec: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	out["kind"] = str(spec.get("kind", "customer"))
	out["role"] = str(spec.get("role", ""))
	out["tier"] = clampi(int(spec.get("tier", 1)), 1, 5)
	out["skin"] = _as_color(spec.get("skin"), SKIN_MID)
	out["hair"] = _as_color(spec.get("hair"), HAIR_BLACK)
	out["hair_style"] = str(spec.get("hair_style", "pendek"))
	out["hat"] = str(spec.get("hat", "none"))
	out["cloth"] = _as_color(spec.get("cloth"), Palette.FLOUR_WHITE)
	out["chubby"] = clampf(float(spec.get("chubby", 0.0)), 0.0, 1.0)
	out["rainy"] = bool(spec.get("rainy", false))
	out["mood"] = str(spec.get("mood", "netral"))
	out["height"] = clampf(float(spec.get("height", 1.0)), 0.5, 1.6)
	out["lean"] = clampf(float(spec.get("lean", 0.0)), -25.0, 25.0)
	out["head_tilt"] = clampf(float(spec.get("head_tilt", 0.0)), -30.0, 30.0)
	out["accessory"] = _as_names(spec.get("accessory"))
	out["prop"] = _as_names(spec.get("prop"))
	out["archetype"] = str(spec.get("archetype", ""))

	# Celemek bersifat opsional: hanya Color yang dianggap sah.
	var apron: Variant = spec.get("apron")
	if apron is Color:
		out["apron"] = apron
	else:
		out["apron"] = null
	return out


## Ambil Color dari nilai Variant apa pun, dengan cadangan bila tipenya salah.
static func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		var c: Color = value
		return c
	return fallback


## Ubah Array / PackedStringArray / String menjadi PackedStringArray yang rapi.
static func _as_names(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed.duplicate()
	if value is Array:
		var arr: Array = value
		for item: Variant in arr:
			out.append(str(item))
		return out
	if value is String:
		out.append(str(value))
	return out


## Pembungkus ringkas untuk membuat PackedStringArray dari literal Array.
static func _pack(names: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for n: Variant in names:
		out.append(str(n))
	return out


## Generator acak lokal yang deterministik per pelanggan + seed (bukan GameConfig.rng),
## supaya pelanggan dengan seed sama selalu tampil persis sama.
static func _seeded_rng(customer_id: String, seed_i: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash(customer_id) * 1000003 + seed_i
	return rng


static func _pick_color(list: Array[Color], rng: RandomNumberGenerator) -> Color:
	if list.is_empty():
		return SKIN_MID
	return list[rng.randi_range(0, list.size() - 1)]


static func _pick_name(list: PackedStringArray, rng: RandomNumberGenerator) -> String:
	if list.is_empty():
		return "pendek"
	return list[rng.randi_range(0, list.size() - 1)]


static func _skin_tones() -> Array[Color]:
	var list: Array[Color] = [SKIN_LIGHT, SKIN_MID, SKIN_TAN, SKIN_DEEP]
	return list


static func _hair_tones() -> Array[Color]:
	var list: Array[Color] = [HAIR_BLACK, HAIR_BROWN, HAIR_LIGHT_BROWN, HAIR_BLONDE,
		HAIR_PASTEL, HAIR_GREY]
	return list


## Warna baju pelanggan umum: pastel manis GDD 4.1.
static func _cloth_tones() -> Array[Color]:
	var list: Array[Color] = [
		Palette.PASTEL_STRAWBERRY,
		Palette.PASTEL_PERIWINKLE,
		Palette.PASTEL_MINT,
		Palette.BUTTER_YELLOW,
		Palette.VANILLA_CREAM,
		Palette.CUSTARD,
	]
	return list


## Warna kemeja kerja.
static func _office_tones() -> Array[Color]:
	var list: Array[Color] = [
		Palette.FLOUR_WHITE,
		Palette.PASTEL_PERIWINKLE,
		Color(0.784, 0.851, 0.902),  # biru kemeja pudar #C8D9E6
	]
	return list


## Warna daster/blus bermotif bunga untuk emak-emak arisan.
static func _floral_tones() -> Array[Color]:
	var list: Array[Color] = [
		Palette.GINGHAM_A,
		Palette.MOOD_BG_ROUGH,
		Palette.MOOD_BG_BAILOUT,
		Palette.CUSTARD,
	]
	return list


## Warna busana elegan sosialita.
static func _elegant_tones() -> Array[Color]:
	var list: Array[Color] = [
		Palette.APRON_NAVY,
		Palette.APRON_MAROON,
		Palette.APRON_GOLD,
		Color(0.286, 0.243, 0.325),  # ungu tua elegan #493E53
	]
	return list


## Warna baju cerah food vlogger.
static func _vivid_tones() -> Array[Color]:
	var list: Array[Color] = [
		Palette.WARMER_LAMP,
		Palette.SUCCESS,
		Palette.DANGER,
		Palette.GOLD_STAR,
	]
	return list


## Daftar gaya rambut yang boleh diundi untuk pelanggan.
static func _hair_styles() -> PackedStringArray:
	return _pack(["pendek", "belah_samping", "bob", "sanggul", "ikal", "cepak",
		"kuncir_ganda", "panjang_kepang", "spike"])


## Geser kecerahan warna: `amount` positif menerangkan, negatif menggelapkan.
static func _shift(color: Color, amount: float) -> Color:
	if amount >= 0.0:
		return color.lerp(Color(1.0, 1.0, 1.0), clampf(amount, 0.0, 1.0))
	return color.lerp(Color(0.0, 0.0, 0.0), clampf(-amount, 0.0, 1.0))


## Simpan transform dasar sebagai metadata agar animasi & ekspresi bisa kembali ke pose awal.
static func _remember(node: Node3D) -> void:
	node.set_meta("base_position", node.position)
	node.set_meta("base_rotation", node.rotation)
	node.set_meta("base_scale", node.scale)


## Terapkan pengali skala + geseran posisi terhadap transform dasar sebuah bagian wajah.
static func _apply_part(node: Node3D, scale_mul: Vector3, offset: Vector3) -> void:
	if node == null:
		return
	var base_scale: Vector3 = node.get_meta("base_scale", Vector3.ONE)
	var base_pos: Vector3 = node.get_meta("base_position", node.position)
	node.scale = Vector3(base_scale.x * scale_mul.x, base_scale.y * scale_mul.y,
		base_scale.z * scale_mul.z)
	node.position = base_pos + offset


## Ambil anak langsung bertipe Node3D berdasarkan nama.
static func _child3d(parent: Node3D, child_name: String) -> Node3D:
	if parent == null:
		return null
	var node: Node = parent.get_node_or_null(NodePath(child_name))
	if node is Node3D:
		return node
	return null


## Jadikan root sebagai owner seluruh keturunan, supaya find_child() bawaan Godot
## (yang secara bawaan hanya mencari node ber-owner) tetap menemukan Head, Hat, dsb.
static func _assign_owner(root: Node, node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_assign_owner(root, child)
