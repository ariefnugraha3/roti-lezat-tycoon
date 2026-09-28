class_name CharacterFactory
extends RefCounted
## Pabrik karakter chibi 100% prosedural bergaya "Warm, Cozy & Cute" (GDD 4.1,
## 4.2, 12.3, 31, 130.2). Tanpa skeletal armature: setiap segmen yang digerakkan
## animasi (Body, Head, ArmL/R, LegL/R, Apron) adalah Node3D pivot di sendinya,
## dan semua bentuk statis milik segmen itu dijahit MeshBuilder menjadi SATU mesh
## berwarna verteks. Hasilnya siluet bulat-empuk low-poly dengan ~12 draw call
## per karakter (GDD 37.4).
##
## Hierarki (GDD 31.1):
##   Character
##     Body (pivot pinggul): BodyMesh, Apron -> ApronMesh, ArmL, ArmR (pivot bahu)
##     Head (pivot leher): HeadMesh (kepala, telinga, pipi, rambut, topi),
##       Face -> EyeL, EyeR, BrowL, BrowR, Mouth; Hair, Hat (penanda kontrak)
##     LegL, LegR (pivot pinggul), CarryAnchor, ShadowBlob, [PropsMesh]
##
## Proporsi (GDD 130.2) pada height 1.0: tinggi ~0.90 m; kepala ~42 %, torso
## ~30 %, kaki ~28 %; garis mata ~45 % tinggi kepala dari dagu. Wajah menghadap
## -Z (FRONT). Poni selalu berakhir di atas alis agar ekspresi terbaca.
##
## Kunci `spec` kanonik: {kind, role, tier, skin, hair, hair_style, apron,
## accessory, chubby, rainy}. Kunci opsional dari spec_for_*(): hat, cloth,
## pants, shoes, legwear, sleeve, skirt, lashes, dots, prop, mood, height, lean,
## head_tilt, archetype.
##
## Anggaran 500-2000 segitiga per karakter (GDD 12.2). Tiap mesh menyimpan meta
## "tris" & "aabb" (ruang lokal) agar test bisa memeriksanya tanpa renderer.

const FRONT: float = -1.0

# --- Proporsi & sendi (meter, height 1.0) ---
const HIP_Y: float = 0.25
const HIP_X: float = 0.066
const LEG_LENGTH: float = 0.170
const LEG_RADIUS: float = 0.058
const NECK_Y: float = 0.515
const HEAD_CENTER_Y: float = 0.19
const HEAD_RX: float = 0.205
const HEAD_RY: float = 0.19
const HEAD_RZ: float = 0.196
## Garis bahu = garis dada chibi (GDD 4.2: meja kasir ±0,44 m). Juga dipakai
## EquipmentFactory.CHEST_HEIGHT, jadi nilainya tidak boleh berubah.
const SHOULDER_Y: float = 0.44
const SHOULDER_X: float = 0.142
const ARM_LENGTH: float = 0.150
const ARM_RADIUS: float = 0.046

# --- Wajah (relatif pusat kepala) ---
## Garis mata ~45 % tinggi kepala dari dagu (GDD 130.2): mata besar tepat di
## bawah tengah kepala, dahi tertutup poni -- proporsi chibi.
const EYE_X: float = 0.078
const EYE_Y: float = -0.019
const EYE_RADII := Vector3(0.030, 0.039, 0.013)
const BROW_Y: float = 0.036
const NOSE_Y: float = -0.066
const MOUTH_Y: float = -0.094
const CHEEK_X: float = 0.124
const CHEEK_Y: float = -0.074
const EAR_Y: float = -0.030
## Ujung bawah poni: tepat di atas alis.
const BANG_BOTTOM: float = 0.050
## Tepi depan topi & bandana: di atas ujung poni, jadi poni tetap mengintip.
const BRIM_Y: float = BANG_BOTTOM + 0.040

## Profil torso (r, y) relatif pinggul, dari bawah ke atas: pinggul bulat, perut
## empuk, bahu landai, leher pendek. Pasangan titik yang nyaris sama membuat
## batas warna tegas (celana | ikat pinggang | baju | kulit leher).
const TORSO_PROFILE: Array[Vector2] = [
	Vector2(0.0, -0.036), Vector2(0.092, -0.032), Vector2(0.127, -0.004), Vector2(0.136, 0.0255),
	Vector2(0.136, 0.0265), Vector2(0.1365, 0.0435),
	Vector2(0.1365, 0.0445), Vector2(0.134, 0.082), Vector2(0.125, 0.130), Vector2(0.109, 0.180),
	Vector2(0.090, 0.221), Vector2(0.064, 0.254),
	Vector2(0.043, 0.268), Vector2(0.040, 0.292), Vector2(0.0, 0.296),
]
## Indeks titik profil pertama bagian baju (dipakai torso bergaun: bagian
## bawahnya tertutup rok sehingga tidak perlu digambar).
const TORSO_SHIRT_START: int = 6
const Y_PANTS_TOP: float = 0.026
const Y_BELT_TOP: float = 0.044
const Y_COLLAR: float = 0.258

## Barang yang dipeluk di depan badan: kedua lengan maju memegangnya.
const FRONT_PROPS: Array[String] = ["kardus", "loyang_roti", "mangkuk_adonan", "kantong_kertas"]
## Penutup kepala yang menutupi ubun-ubun, dan yang turun sampai pelipis.
const CROWN_HATS: Array[String] = ["bandana", "helm", "topi_pet", "peci", "topi_koki", "toque"]
const SIDE_HATS: Array[String] = ["bandana", "helm", "topi_pet"]

# --- Resolusi (segmen eksplisit agar anggaran segitiga terkendali) ---
const SEG_HEAD := Vector2i(14, 8)
const SEG_HAIR := Vector2i(14, 5)
const SEG_LOCK := Vector2i(5, 3)
const SEG_TORSO: int = 9
const SEG_LIMB: int = 6
const SEG_SMALL := Vector2i(6, 3)
const SEG_TINY := Vector2i(5, 2)

# --- Warna ---
const SKIN_LIGHT: Color = Color(0.980, 0.851, 0.737)   # #FAD9BC
const SKIN_MID: Color = Color(0.949, 0.788, 0.627)     # #F2C9A0
const SKIN_TAN: Color = Color(0.878, 0.659, 0.486)     # #E0A87C
const SKIN_DEEP: Color = Color(0.788, 0.541, 0.369)    # #C98A5E
const HAIR_BLACK: Color = Color(0.169, 0.129, 0.094)   # #2B2118
const HAIR_BROWN: Color = Color(0.290, 0.192, 0.129)   # #4A3121
const HAIR_LIGHT_BROWN: Color = Color(0.478, 0.306, 0.176)  # #7A4E2D
const HAIR_BLONDE: Color = Color(0.878, 0.753, 0.439)  # #E0C070
const HAIR_PASTEL: Color = Color(0.910, 0.706, 0.847)  # #E8B4D8
const HAIR_GREY: Color = Color(0.788, 0.761, 0.729)    # #C9C2BA
## Manik mata: atas gelap, bawah cokelat hangat (kesan berbinar).
const EYE_COLOR: Color = Color(0.129, 0.090, 0.075)    # #21170F
const EYE_IRIS: Color = Color(0.435, 0.259, 0.169)     # #6F422B
const MOUTH_COLOR: Color = Color(0.451, 0.204, 0.180)  # #73342E
const TONGUE_COLOR: Color = Color(0.910, 0.502, 0.541)  # #E8808A
const GLINT_COLOR: Color = Color(1.0, 1.0, 1.0)
const DARK_GLASS: Color = Color(0.141, 0.157, 0.192)   # #24282F
const SHOE_BROWN: Color = Color(0.380, 0.247, 0.169)   # #613F2B
const SOLE_CREAM: Color = Color(0.953, 0.906, 0.824)   # #F3E7D2
const PANTS_COFFEE: Color = Color(0.435, 0.318, 0.247)  # #6F513F
const PECI_BLACK: Color = Color(0.141, 0.149, 0.231)   # #24263B
const SHADOW_COLOR: Color = Color(0.294, 0.176, 0.106, 0.30)

## Parameter tiap suasana hati. `*_scale` adalah PENGALI atas skala dasar,
## `*_offset` geseran posisi, `brow_tilt` derajat (positif = ujung dalam alis
## turun alias marah), `mouth_roll` memutar mulut "D" menjadi cemberut.
const EXPRESSIONS: Dictionary = {
	"netral": {
		"eye_scale": Vector3(1.0, 1.0, 1.0), "eye_offset": Vector3(0.0, 0.0, 0.0),
		"mouth_scale": Vector3(0.80, 0.55, 1.0), "mouth_offset": Vector3(0.0, 0.0, 0.0), "mouth_roll": 0.0,
		"brow_offset": Vector3(0.0, 0.0, 0.0), "brow_tilt": 0.0,
	},
	"senang": {
		"eye_scale": Vector3(1.06, 0.84, 1.0), "eye_offset": Vector3(0.0, 0.003, 0.0),
		"mouth_scale": Vector3(1.25, 1.20, 1.0), "mouth_offset": Vector3(0.0, 0.0, 0.0), "mouth_roll": 0.0,
		"brow_offset": Vector3(0.0, 0.005, 0.0), "brow_tilt": -4.0,
	},
	"kesal": {
		"eye_scale": Vector3(1.0, 0.66, 1.0), "eye_offset": Vector3(0.0, -0.004, 0.0),
		"mouth_scale": Vector3(0.62, 0.34, 1.0), "mouth_offset": Vector3(0.0, -0.010, 0.0), "mouth_roll": 180.0,
		"brow_offset": Vector3(0.0, -0.008, 0.0), "brow_tilt": 18.0,
	},
	"sedih": {
		"eye_scale": Vector3(0.95, 0.90, 1.0), "eye_offset": Vector3(0.0, -0.004, 0.0),
		"mouth_scale": Vector3(0.60, 0.45, 1.0), "mouth_offset": Vector3(0.0, -0.012, 0.0), "mouth_roll": 180.0,
		"brow_offset": Vector3(0.0, -0.002, 0.0), "brow_tilt": -16.0,
	},
	"kaget": {
		"eye_scale": Vector3(1.18, 1.22, 1.0), "eye_offset": Vector3(0.0, 0.004, 0.0),
		"mouth_scale": Vector3(0.62, 1.50, 1.0), "mouth_offset": Vector3(0.0, -0.004, 0.0), "mouth_roll": 0.0,
		"brow_offset": Vector3(0.0, 0.010, 0.0), "brow_tilt": -2.0,
	},
	# Lega sambil mengelap keringat (GDD 31.6): mata terpejam senang.
	"lega": {
		"eye_scale": Vector3(1.08, 0.30, 1.0), "eye_offset": Vector3(0.0, -0.004, 0.0),
		"mouth_scale": Vector3(1.0, 0.9, 1.0), "mouth_offset": Vector3(0.0, 0.0, 0.0), "mouth_roll": 0.0,
		"brow_offset": Vector3(0.0, 0.006, 0.0), "brow_tilt": -6.0,
	},
	# Terkantuk-kantuk (GDD 31.6): mata nyaris terpejam, mulut kecil menguap.
	"ngantuk": {
		"eye_scale": Vector3(1.06, 0.16, 1.0), "eye_offset": Vector3(0.0, -0.008, 0.0),
		"mouth_scale": Vector3(0.45, 0.75, 1.0), "mouth_offset": Vector3(0.0, -0.004, 0.0), "mouth_roll": 0.0,
		"brow_offset": Vector3(0.0, -0.004, 0.0), "brow_tilt": -10.0,
	},
}

## Gaya rambut: garis rambut cangkang depan/samping/belakang (derajat dari
## puncak), ketebalan, jenis poni, ujung rambut pembingkai wajah (y relatif
## pusat kepala), dan pengembangan tepi (bob).
const HAIR_STYLES: Dictionary = {
	"pendek": {"front": 54.0, "side": 98.0, "back": 138.0, "puff": 0.022, "bangs": "tuft", "frame": -0.010},
	"cepak": {"front": 46.0, "side": 86.0, "back": 128.0, "puff": 0.009, "bangs": "none"},
	"belah_samping": {"front": 54.0, "side": 100.0, "back": 138.0, "puff": 0.024, "bangs": "side", "frame": -0.020},
	"bob": {"front": 55.0, "side": 128.0, "back": 140.0, "puff": 0.026, "bangs": "straight", "flare": 0.10, "cut": [30.0, 62.0]},
	"spike": {"front": 50.0, "side": 90.0, "back": 134.0, "puff": 0.016, "bangs": "spike", "frame": 0.000},
	"panjang_kepang": {"front": 54.0, "side": 104.0, "back": 140.0, "puff": 0.024, "bangs": "tuft", "frame": -0.060},
	"kuncir_ganda": {"front": 54.0, "side": 100.0, "back": 138.0, "puff": 0.022, "bangs": "tuft", "frame": -0.050},
	"sanggul": {"front": 52.0, "side": 96.0, "back": 134.0, "puff": 0.020, "bangs": "part", "frame": -0.040},
	"ikal": {"front": 54.0, "side": 108.0, "back": 140.0, "puff": 0.030, "bangs": "tuft", "frame": -0.070},
	"ombre": {"front": 55.0, "side": 124.0, "back": 140.0, "puff": 0.026, "bangs": "straight", "flare": 0.07, "cut": [30.0, 62.0]},
	"jenggot": {"front": 52.0, "side": 96.0, "back": 134.0, "puff": 0.018, "bangs": "part", "frame": -0.020},
}

## Gaya rambut & aksesori yang memberi karakter bulu mata lentik (murni visual).
const LASH_STYLES: Array[String] = ["bob", "ombre", "kuncir_ganda", "panjang_kepang", "sanggul", "ikal"]
const LASH_ACCESSORIES: Array[String] = ["jepit_stroberi", "bando_gingham", "pita_kuning", "anting_mutiara", "kalung_mutiara"]
const LASH_HATS: Array[String] = ["bando", "bando_kelinci"]

## Varian visual per arketipe kanonik (GDD 78.6). Kunci internal tidak pernah
## tampil ke pemain.
const ARCHETYPE_VISUAL: Dictionary = {
	"customer_school_child": "anak_sekolah",
	"customer_office_worker": "pekerja_kantoran",
	"customer_bulk_buyer": "emak_arisan",
	"customer_snob": "sosialita",
	"customer_indecisive": "si_galau",
	"customer_critic": "food_vlogger",
	"customer_generic": "warga",
}


# ===========================================================================
# API PUBLIK
# ===========================================================================

## Rakit satu karakter chibi lengkap dari `spec`. Kunci yang tidak dikenal
## diabaikan dan kunci yang hilang memakai nilai bawaan, jadi `build({})` tetap
## menghasilkan karakter.
static func build(spec: Dictionary) -> Node3D:
	var s: Dictionary = _normalize(spec)
	var chubby: float = s["chubby"]
	var root := Node3D.new()
	root.name = "Character"

	var body: Node3D = _pivot(root, "Body", Vector3(0.0, HIP_Y, 0.0))
	var apron: Node3D = _pivot(body, "Apron", Vector3.ZERO)
	var head: Node3D = _pivot(root, "Head", Vector3(0.0, NECK_Y, 0.0))
	var face: Node3D = _pivot(head, "Face", Vector3(0.0, HEAD_CENTER_Y, 0.0))
	_pivot(head, "Hair", Vector3(0.0, HEAD_CENTER_Y, 0.0))
	_pivot(head, "Hat", Vector3(0.0, HEAD_CENTER_Y, 0.0))
	var shoulder: float = _shoulder_x(chubby)
	var arm_l: Node3D = _pivot(body, "ArmL", Vector3(-shoulder, SHOULDER_Y - HIP_Y, 0.0))
	var arm_r: Node3D = _pivot(body, "ArmR", Vector3(shoulder, SHOULDER_Y - HIP_Y, 0.0))
	arm_l.rotation = _arm_pose(s, -1.0)
	arm_r.rotation = _arm_pose(s, 1.0)
	arm_l.set_meta("swing_scale", _arm_swing(s, -1.0))
	arm_r.set_meta("swing_scale", _arm_swing(s, 1.0))
	var hip: float = HIP_X * (1.0 + 0.2 * chubby)
	var leg_l: Node3D = _pivot(root, "LegL", Vector3(-hip, HIP_Y, 0.0))
	var leg_r: Node3D = _pivot(root, "LegR", Vector3(hip, HIP_Y, 0.0))
	_pivot(root, "CarryAnchor", Vector3(0.0, 0.40, FRONT * 0.20))

	var mb: Dictionary = {}
	for key: String in ["body", "apron", "head", "arm_l", "arm_r", "leg_l", "leg_r", "extra"]:
		mb[key] = MeshBuilder.new()
	_build_torso(s, mb["body"])
	_build_skirt(s, mb["body"])
	_build_apron(s, mb["apron"])
	_build_head(s, mb["head"])
	_build_hair(s, mb["head"])
	_build_hat(s, mb["head"])
	_build_arm(s, mb["arm_l"])
	_build_arm(s, mb["arm_r"])
	_build_leg(s, mb["leg_l"])
	_build_leg(s, mb["leg_r"])
	for acc_id: String in s["accessory"]:
		_attach_accessory(acc_id, s, mb)
	for prop_id: String in s["prop"]:
		_attach_prop(prop_id, s, mb)
	_build_face(s, face)

	body.add_child((mb["body"] as MeshBuilder).commit("BodyMesh"))
	apron.add_child((mb["apron"] as MeshBuilder).commit("ApronMesh"))
	head.add_child((mb["head"] as MeshBuilder).commit("HeadMesh"))
	arm_l.add_child((mb["arm_l"] as MeshBuilder).commit("ArmLMesh"))
	arm_r.add_child((mb["arm_r"] as MeshBuilder).commit("ArmRMesh"))
	leg_l.add_child((mb["leg_l"] as MeshBuilder).commit("LegLMesh"))
	leg_r.add_child((mb["leg_r"] as MeshBuilder).commit("LegRMesh"))
	var extra: MeshBuilder = mb["extra"]
	if not extra.is_empty():
		root.add_child(extra.commit("PropsMesh"))
	var shadow := MeshBuilder.new()
	var blob: float = 0.20 * (1.0 + 0.3 * chubby)
	shadow.disc(Transform3D(Basis(), Vector3(0.0, 0.004, 0.0)), blob, SHADOW_COLOR, Color(SHADOW_COLOR, 0.0), 14)
	root.add_child(shadow.commit("ShadowBlob", MeshBuilder.SHADOW))

	# Postur: lean positif = condong ke depan (arah wajah); kepala ikut leher.
	var lean: float = s["lean"]
	if not is_zero_approx(lean):
		var neck: float = NECK_Y - HIP_Y
		body.rotation.x = deg_to_rad(-lean)
		head.position += Vector3(0.0, neck * (cos(deg_to_rad(lean)) - 1.0), FRONT * neck * sin(deg_to_rad(lean)))
	var tilt: float = s["head_tilt"]
	if not is_zero_approx(tilt):
		head.rotation.z = deg_to_rad(tilt)
	for n: Node3D in [body, apron, head, face, arm_l, arm_r, leg_l, leg_r]:
		_remember(n)

	root.scale = Vector3.ONE * float(s["height"])
	root.set_meta("spec", s)
	set_expression(root, str(s["mood"]))
	_assign_owner(root, root)
	return root


## Jumlah segitiga seluruh karakter (dari meta MeshBuilder, tanpa renderer).
static func triangle_count(actor: Node) -> int:
	var t: int = int(actor.get_meta("tris", 0)) if actor is MeshInstance3D else 0
	for c: Node in actor.get_children():
		t += triangle_count(c)
	return t


## Jumlah mesh yang benar-benar digambar (perkiraan draw call) satu karakter.
static func mesh_count(actor: Node) -> int:
	var n: int = 1 if actor is MeshInstance3D and (actor as MeshInstance3D).mesh != null else 0
	for c: Node in actor.get_children():
		n += mesh_count(c)
	return n


## Spec staf dari data/catalog/staff.json; deterministik per staff_id (GDD 31.4).
static func spec_for_staff(staff_id: String) -> Dictionary:
	var def: StaffDefinition = DataRegistry.staff(StringName(staff_id))
	var role: String = "cashier"
	var tier: int = 1
	var visual: Dictionary = {}
	if def != null:
		role = String(def.role_id)
		tier = clampi(def.tier, 1, 5)
		visual = def.visual
	var hair_style: String = str(visual.get("hair_style", "pendek"))
	var hat: String = str(visual.get("hat", "none"))
	var accessories: PackedStringArray = _as_names(visual.get("accessory"))
	var spec: Dictionary = {
		"kind": "staff", "role": role, "tier": tier,
		"skin": _as_color(visual.get("skin"), SKIN_MID),
		"hair": _as_color(visual.get("hair"), HAIR_BLACK),
		"hair_style": hair_style,
		"hat": hat,
		"apron": _as_color(visual.get("apron"), Palette.apron_for_tier(role, tier)),
		"accessory": accessories,
		"chubby": clampf(float(visual.get("chubby", 0.0)), 0.0, 1.0),
		"cloth": Palette.VANILLA_CREAM if role == "baker" else Palette.FLOUR_WHITE,
		"pants": PANTS_COFFEE,
		"shoes": SHOE_BROWN,
		"sleeve": "short",
		"lashes": _soft_features(hair_style, hat, accessories),
		"prop": PackedStringArray(),
		"rainy": false,
		# Staf toko selalu menyambut dengan senyum (GDD 4.1 "Cute").
		"mood": "senang",
		"height": 1.0,
	}
	return spec


## Spec karakter PEMAIN (GDD 2, 4.2): satu perakit, dua masukan berbeda --
## gaya rambut, penutup kepala, warna celemek, dan proporsi badan.
static func spec_for_player(gender: String) -> Dictionary:
	var wanita: bool = gender == "wanita"
	return {
		"kind": "player", "role": "baker", "tier": 1,
		"skin": SKIN_LIGHT if wanita else SKIN_MID,
		"hair": HAIR_BROWN if wanita else HAIR_BLACK,
		"hair_style": "panjang_kepang" if wanita else "pendek",
		"hat": "bandana" if wanita else "topi_koki",
		"apron": Palette.APRON_ORANGE_PASTEL if wanita else Palette.APRON_COFFEE_BROWN,
		"accessory": PackedStringArray(),
		"chubby": 0.10 if wanita else 0.18,
		"cloth": Palette.FLOUR_WHITE,
		"pants": PANTS_COFFEE,
		"skirt": Palette.PASTEL_STRAWBERRY if wanita else null,
		"legwear": "skin" if wanita else "pants",
		"shoes": Palette.APRON_MAROON if wanita else SHOE_BROWN,
		"sleeve": "short",
		"lashes": wanita,
		"prop": PackedStringArray(),
		"rainy": false,
		"mood": "senang",
		"height": 1.04 if wanita else 1.08,
		"lean": 0.0,
		"head_tilt": 0.0,
	}


## Spec pelanggan yang deterministik terhadap `seed_i` (GDD 31.5).
static func spec_for_customer(customer_id: String, seed_i: int, rainy: bool = false) -> Dictionary:
	var rng: RandomNumberGenerator = _seeded_rng(customer_id, seed_i)
	if customer_id == "driver_rotifood":
		var driver: Dictionary = spec_for_driver(rainy)
		driver["skin"] = _pick_color(_skin_tones(), rng)
		driver["hair"] = _pick_color(_hair_tones(), rng)
		return driver
	if customer_id == "courier_supply":
		var courier: Dictionary = spec_for_courier()
		courier["skin"] = _pick_color(_skin_tones(), rng)
		courier["hair"] = _pick_color(_hair_tones(), rng)
		return courier

	var archetype: String = str(ARCHETYPE_VISUAL.get(customer_id, "warga"))
	var spec: Dictionary = {
		"kind": "customer", "archetype": archetype, "role": "", "tier": 1,
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
	# Undian pakaian: SELALU sesudah undian dasar agar urutan RNG tetap stabil.
	spec["pants"] = _pick_color(_pants_tones(), rng)
	spec["shoes"] = _pick_color(_shoe_tones(), rng)
	spec["sleeve"] = "long" if rng.randf() < 0.35 else "short"
	var skirt_roll: float = rng.randf()
	var soft: bool = str(spec["hair_style"]) in LASH_STYLES
	if soft and skirt_roll < 0.45:
		spec["skirt"] = _shift(spec["cloth"] as Color, -0.12)
		spec["legwear"] = "skin"
	spec["lashes"] = soft

	match archetype:
		"anak_sekolah":
			spec["height"] = rng.randf_range(0.78, 0.84)
			spec["chubby"] = rng.randf_range(0.10, 0.30)
			spec["cloth"] = Palette.FLOUR_WHITE
			spec["hair_style"] = _pick_name(_pack(["pendek", "kuncir_ganda", "spike", "bob"]), rng)
			spec["accessory"] = _pack(["kerah_kemeja", "dasi_merah"])
			spec["prop"] = _pack(["tas_sekolah"])
			spec["pants"] = Palette.APRON_NAVY
			spec["legwear"] = "shorts"
			spec["skirt"] = null
			spec["sleeve"] = "short"
			spec["shoes"] = Palette.DANGER
			spec["lashes"] = str(spec["hair_style"]) in LASH_STYLES
			spec["mood"] = "senang"
		"pekerja_kantoran":
			spec["cloth"] = _pick_color(_office_tones(), rng)
			spec["hair_style"] = _pick_name(_pack(["belah_samping", "cepak", "bob", "sanggul"]), rng)
			spec["accessory"] = _pack(["kerah_kemeja", "dasi_kerja"])
			spec["prop"] = _pack(["koper"])
			spec["pants"] = Color(0.290, 0.302, 0.369)  # abu arang #4A4D5E
			spec["legwear"] = "pants"
			spec["skirt"] = null
			spec["sleeve"] = "long"
			spec["shoes"] = HAIR_BLACK
			spec["lashes"] = str(spec["hair_style"]) in LASH_STYLES
			spec["lean"] = 9.0
			spec["mood"] = "kesal"
		"emak_arisan":
			spec["chubby"] = rng.randf_range(0.55, 0.80)
			spec["height"] = rng.randf_range(0.92, 0.98)
			spec["cloth"] = _pick_color(_floral_tones(), rng)
			spec["hair_style"] = "sanggul"
			spec["accessory"] = _pack(["anting_mutiara"])
			spec["prop"] = _pack(["tas_belanja"])
			spec["skirt"] = _shift(spec["cloth"] as Color, -0.10)
			spec["legwear"] = "skin"
			spec["sleeve"] = "long"
			spec["lashes"] = true
			spec["dots"] = true
			spec["mood"] = "senang"
		"sosialita":
			spec["height"] = rng.randf_range(1.04, 1.10)
			spec["chubby"] = 0.0
			spec["cloth"] = _pick_color(_elegant_tones(), rng)
			spec["hair_style"] = _pick_name(_pack(["sanggul", "ikal"]), rng)
			spec["accessory"] = _pack(["anting_mutiara", "kalung_mutiara"])
			spec["prop"] = _pack(["tas_tangan"])
			spec["skirt"] = _shift(spec["cloth"] as Color, -0.08)
			spec["legwear"] = "skin"
			spec["sleeve"] = "long"
			spec["shoes"] = Palette.APRON_MAROON
			spec["lashes"] = true
			spec["mood"] = "netral"
		"si_galau":
			spec["head_tilt"] = rng.randf_range(10.0, 16.0)
			spec["cloth"] = Palette.PASTEL_PERIWINKLE
			spec["sleeve"] = "long"
			spec["prop"] = _pack(["tanda_tanya"])
			spec["mood"] = "sedih"
		"food_vlogger":
			spec["cloth"] = _pick_color(_vivid_tones(), rng)
			spec["hat"] = "topi_pet"
			spec["sleeve"] = "short"
			spec["prop"] = _pack(["kamera"])
			spec["mood"] = "senang"
		_:
			pass
	return spec


## Kurir RotiFood (GDD 3.6): seragam hijau, helm bundar, ransel termal kubus;
## saat hujan jas hujan kuning (GDD 10.2).
static func spec_for_driver(rainy: bool) -> Dictionary:
	var uniform: Color = Palette.OJOL_GREEN
	var accessories: Array[String] = ["ponsel"]
	if rainy:
		uniform = Palette.RAINCOAT_YELLOW
		accessories.append("jas_hujan")
	return {
		"kind": "driver", "role": "driver", "tier": 1,
		"skin": SKIN_MID, "hair": HAIR_BLACK, "hair_style": "pendek",
		"hat": "helm", "apron": null,
		"accessory": _pack(accessories),
		"chubby": 0.1,
		"cloth": uniform,
		"pants": _shift(Palette.OJOL_GREEN, -0.45),
		"shoes": HAIR_BLACK,
		"sleeve": "long",
		"prop": _pack(["ransel_termal"]),
		"rainy": rainy,
		"mood": "senang",
		"height": 1.0,
	}


## Kurir paket bahan baku (GDD 5.2.3.C): seragam cokelat kardus dan topi pet.
static func spec_for_courier() -> Dictionary:
	return {
		"kind": "courier", "role": "courier", "tier": 1,
		"skin": SKIN_MID, "hair": HAIR_BLACK, "hair_style": "cepak",
		"hat": "topi_pet", "apron": null,
		"accessory": PackedStringArray(),
		"chubby": 0.15,
		"cloth": Color(0.620, 0.447, 0.286),
		"pants": Color(0.408, 0.314, 0.231),
		"shoes": SHOE_BROWN,
		"sleeve": "short",
		"prop": _pack(["kardus"]),
		"rainy": false,
		"mood": "netral",
		"height": 1.0,
	}


## Pak Lurah (GDD 3.0.A): chibi tambun ramah, berpeci, koper dan amplop resmi.
static func spec_for_lurah() -> Dictionary:
	return {
		"kind": "lurah", "role": "lurah", "tier": 1,
		"skin": SKIN_TAN, "hair": HAIR_GREY, "hair_style": "cepak",
		"hat": "peci", "apron": null,
		"accessory": _pack(["kumis", "kerah_kemeja"]),
		"chubby": 0.85,
		"cloth": Color(0.827, 0.780, 0.596),  # safari krem #D3C798
		"pants": Color(0.749, 0.702, 0.525),
		"shoes": HAIR_BLACK,
		"sleeve": "long",
		"prop": _pack(["koper", "amplop"]),
		"rainy": false,
		"mood": "senang",
		"height": 0.98,
	}


## Ganti ekspresi: "senang", "netral", "kesal", "sedih", "kaget". Hanya
## menskala, menggeser, dan memutar mata/alis/mulut -- tanpa tekstur.
static func set_expression(actor: Node3D, mood: String) -> void:
	if actor == null:
		return
	var face: Node3D = part(actor, "Face")
	if face == null:
		return
	var key: String = mood if EXPRESSIONS.has(mood) else "netral"
	var e: Dictionary = EXPRESSIONS[key]
	for i in 2:
		var side: String = "L" if i == 0 else "R"
		var dir: float = -1.0 if i == 0 else 1.0
		_apply_part(_child3d(face, "Eye" + side), e["eye_scale"], e["eye_offset"])
		var brow: Node3D = _child3d(face, "Brow" + side)
		if brow != null:
			# Sumbu x lokal wajah = -X dunia, jadi ujung dalam BrowL ada di -x lokal
			# dan ujung dalam BrowR di +x lokal: tanda putarannya berlawanan.
			var base_basis: Basis = brow.get_meta("base_basis", brow.basis)
			brow.basis = base_basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(-float(e["brow_tilt"]) * dir))
			var base_pos: Vector3 = brow.get_meta("base_position", brow.position)
			brow.position = base_pos + (e["brow_offset"] as Vector3)
	var mouth: Node3D = _child3d(face, "Mouth")
	if mouth != null:
		var mouth_basis: Basis = mouth.get_meta("base_basis", mouth.basis)
		mouth.basis = mouth_basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(float(e["mouth_roll"])))
		_apply_part(mouth, e["mouth_scale"], e["mouth_offset"])
	actor.set_meta("mood", key)


## Kain lap hijau mint bergaris putih di tangan kanan saat mengelap wajah
## (GDD 31.6); warnanya kontras dengan semua warna kulit. Dipasang sebagai anak
## ArmR, di depan telapak (ke arah kamera saat lengan terangkat) dan sedikit
## lebih lebar dari tangan agar terbaca menutupi pipi.
static func wipe_cloth() -> MeshInstance3D:
	var mb := MeshBuilder.new()
	var stripe := func(u: Vector3) -> Color:
		return Palette.FLOUR_WHITE if absf(u.y) > 0.55 and absf(u.y) < 0.75 else Palette.PASTEL_MINT.darkened(0.05)
	var hand_y: float = -ARM_LENGTH - 0.024
	mb.ellipsoid(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(10.0)), Vector3(0.020, hand_y - 0.004, -0.044)),
		Vector3(0.018, 0.072, 0.056), Palette.PASTEL_MINT, 7, 5, stripe)
	return mb.commit("WipeCloth")


static var _z_mesh: ArrayMesh = null


## Huruf "Z" kantuk berbentuk geometri (bukan teks), selalu menghadap kamera.
static func sleep_z() -> MeshInstance3D:
	if _z_mesh == null:
		var mb := MeshBuilder.new()
		var c: Color = Palette.PASTEL_PERIWINKLE.darkened(0.45)
		var w: float = 0.078
		var h: float = 0.084
		var t: float = 0.019
		mb.polygon(Transform3D(), PackedVector2Array([Vector2(-w * 0.5, h * 0.5 - t), Vector2(w * 0.5, h * 0.5 - t),
			Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)]), c)
		mb.polygon(Transform3D(), PackedVector2Array([Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5),
			Vector2(w * 0.5, -h * 0.5 + t), Vector2(-w * 0.5, -h * 0.5 + t)]), c)
		mb.polygon(Transform3D(), PackedVector2Array([Vector2(-w * 0.5, -h * 0.5 + t), Vector2(-w * 0.5 + t * 1.4, -h * 0.5 + t),
			Vector2(w * 0.5, h * 0.5 - t), Vector2(w * 0.5 - t * 1.4, h * 0.5 - t)]), c)
		var tmp: MeshInstance3D = mb.commit("Z", MeshBuilder.SIGN)
		_z_mesh = tmp.mesh as ArrayMesh
		tmp.free()
	var mi := MeshInstance3D.new()
	mi.name = "SleepZ"
	mi.mesh = _z_mesh
	mi.material_override = MeshBuilder.material(MeshBuilder.SIGN)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func clear_caches() -> void:
	_z_mesh = null


## Cari bagian karakter ("Head", "Body", "ArmL", ..., "Apron") dengan aman.
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
# BADAN
# ===========================================================================

## Pengali lemak: paling besar di perut, nol di leher.
static func _belly(y: float, chubby: float) -> float:
	var d: float = (y - 0.085) / 0.10
	return 1.0 + 0.34 * chubby * exp(-d * d)


## Jari-jari torso pada ketinggian y (lokal pinggul), termasuk lemak. Di luar
## rentang profil nilainya dijepit ke cincin terdekat (bukan kutub).
static func _torso_r(y: float, chubby: float) -> float:
	var p: Array[Vector2] = TORSO_PROFILE
	var last: int = p.size() - 2
	var yy: float = clampf(y, p[1].y, p[last].y)
	for k in range(2, last + 1):
		if yy <= p[k].y:
			var t: float = (yy - p[k - 1].y) / maxf(p[k].y - p[k - 1].y, 0.0001)
			return lerpf(p[k - 1].x, p[k].x, t) * _belly(yy, chubby)
	return p[last].x * _belly(yy, chubby)


## Transform di permukaan torso pada ketinggian y dan azimut `ang` (0 = depan),
## menghadap normal permukaan (ikut kemiringan bahu), didorong keluar `push`.
static func _torso_surface(y: float, ang: float, chubby: float, push: float) -> Transform3D:
	var r: float = _torso_r(y, chubby)
	var drdy: float = (_torso_r(y + 0.004, chubby) - _torso_r(y - 0.004, chubby)) / 0.008
	var n2 := Vector2(1.0, -drdy).normalized()
	var n := Vector3(sin(ang) * n2.x, n2.y, -cos(ang) * n2.x)
	var p := Vector3(sin(ang) * r, y, -cos(ang) * r)
	return Transform3D(_basis_facing(n), p + n * push)


static func _build_torso(s: Dictionary, mb: MeshBuilder) -> void:
	var chubby: float = s["chubby"]
	var cloth: Color = s["cloth"]
	var skin: Color = s["skin"]
	var dress: bool = s["skirt"] is Color
	var lower: Color = s["skirt"] if dress else s["pants"]
	var belt: Color = lower if dress else _shift(lower, -0.28)
	var profile := PackedVector2Array()
	var first: int = 0
	if dress:
		# Bagian bawah torso tertutup rok: cukup mulai dari kutub di pinggang.
		profile.append(Vector2(0.0, Y_PANTS_TOP))
		first = TORSO_SHIRT_START
	for k in range(first, TORSO_PROFILE.size()):
		var pt: Vector2 = TORSO_PROFILE[k]
		profile.append(Vector2(pt.x * _belly(pt.y, chubby), pt.y))
	var shade := func(y: float, _phi: float) -> Color:
		if y >= Y_COLLAR:
			return skin
		if y < Y_PANTS_TOP:
			return lower
		if y < Y_BELT_TOP:
			return belt
		return cloth.lightened(0.07 * clampf((y - Y_BELT_TOP) / 0.2, 0.0, 1.0))
	mb.lathe(Transform3D(), profile, cloth, SEG_TORSO, shade)
	if bool(s["dots"]):
		# Blus bermotif bunga (emak-emak arisan): titik-titik lembut di badan.
		var dot: Color = cloth.lerp(Palette.FLOUR_WHITE, 0.55)
		for k in 8:
			var y2: float = 0.075 + 0.055 * float(k % 3)
			var ang: float = deg_to_rad(-70.0 + 20.0 * float(k) + (8.0 if k % 2 == 0 else 0.0))
			mb.polygon(_torso_surface(y2, ang, chubby, 0.002), _circle(0.013, 7), dot)


## Rok/gaun yang mengembang dari pinggang (spec "skirt").
static func _build_skirt(s: Dictionary, mb: MeshBuilder) -> void:
	if not (s["skirt"] is Color):
		return
	var chubby: float = s["chubby"]
	var col: Color = s["skirt"]
	var r0: float = _torso_r(0.05, chubby)
	var profile := PackedVector2Array([
		Vector2(r0 - 0.012, -0.100), Vector2(r0 + 0.044, -0.104), Vector2(r0 + 0.052, -0.094),
		Vector2(r0 + 0.050, -0.0865), Vector2(r0 + 0.049, -0.0855),
		Vector2(r0 + 0.034, -0.030), Vector2(r0 + 0.012, 0.024), Vector2(r0 + 0.003, 0.058),
	])
	var hem: Color = col.lerp(Palette.FLOUR_WHITE, 0.35)
	var shade := func(y: float, _phi: float) -> Color:
		return hem if y < -0.086 else col
	mb.lathe(Transform3D(), profile, col, SEG_TORSO + 1, shade)


## Celemek staf/pemain (GDD 3.4: warnanya = tier keahlian): rok melengkung
## mengikuti badan dengan lis terang, dada celemek, saku, tali leher, dan pita
## di punggung.
static func _build_apron(s: Dictionary, mb: MeshBuilder) -> void:
	if not (s["apron"] is Color):
		return
	var color: Color = s["apron"]
	var chubby: float = s["chubby"]
	var trim: Color = color.lerp(Palette.FLOUR_WHITE, 0.45)
	var waist: float = _torso_r(Y_BELT_TOP, chubby)
	var skirt := PackedVector2Array([
		Vector2(waist + 0.028, -0.074), Vector2(waist + 0.027, -0.0605),
		Vector2(waist + 0.027, -0.0595), Vector2(waist + 0.020, -0.010),
		Vector2(_torso_r(0.060, chubby) + 0.011, 0.060), Vector2(_torso_r(0.110, chubby) + 0.010, 0.110),
		Vector2(_torso_r(0.132, chubby) + 0.010, 0.132),
	])
	var skirt_shade := func(y: float, _phi: float) -> Color:
		return trim if y < -0.060 else color
	mb.lathe(Transform3D(), skirt, color, 8, skirt_shade, deg_to_rad(-72.0), deg_to_rad(72.0))
	var bib := PackedVector2Array()
	for y: float in [0.128, 0.170, 0.206]:
		bib.append(Vector2(_torso_r(y, chubby) + 0.010, y))
	mb.lathe(Transform3D(), bib, color, 5, Callable(), deg_to_rad(-36.0), deg_to_rad(36.0))
	# Saku depan dengan lis terang.
	var pocket_r: float = waist + 0.018
	var pa: float = deg_to_rad(-22.0)
	var pn := Vector3(sin(pa), 0.0, -cos(pa))
	mb.box(Transform3D(_basis_facing(pn), Vector3(pn.x * pocket_r, 0.022, pn.z * pocket_r)), Vector3(0.056, 0.040, 0.006), trim)
	# Tali leher melingkari tengkuk.
	var ny: float = 0.236
	mb.torus(Transform3D(Basis(), Vector3(0.0, ny, 0.0)), _torso_r(ny, chubby) + 0.004, 0.0075, color, 7, 3,
		deg_to_rad(36.0), deg_to_rad(324.0))
	# Pita di punggung.
	var back := Vector3(0.0, 0.110, -FRONT * (_torso_r(0.110, chubby) + 0.010))
	_bow(mb, back, color, 1.0, Vector3(0.0, 0.0, -FRONT))


# ===========================================================================
# KEPALA, WAJAH, RAMBUT, TOPI
# ===========================================================================

static func _head_radii(s: Dictionary) -> Vector3:
	var fat: float = 1.0 + 0.06 * float(s["chubby"])
	return Vector3(HEAD_RX * fat, HEAD_RY, HEAD_RZ * fat)


static func _style(s: Dictionary) -> Dictionary:
	return HAIR_STYLES.get(str(s["hair_style"]), HAIR_STYLES["pendek"])


## Jari-jari cangkang rambut (kepala + ketebalan rambut gaya ini).
static func _hair_radii(s: Dictionary) -> Vector3:
	return _head_radii(s) + Vector3.ONE * float(_style(s)["puff"])


## Titik & normal di permukaan depan kepala pada koordinat wajah (x, y) relatif
## pusat kepala, didorong `push` sepanjang normal.
static func _head_surface(radii: Vector3, x: float, y: float, push: float) -> Transform3D:
	var nx: float = x / radii.x
	var ny: float = y / radii.y
	var z: float = FRONT * sqrt(maxf(1.0 - nx * nx - ny * ny, 0.0)) * radii.z
	var p := Vector3(x, y, z)
	var n := Vector3(x / (radii.x * radii.x), y / (radii.y * radii.y), z / (radii.z * radii.z)).normalized()
	return Transform3D(_basis_facing(n), p + n * push)


## Titik pada elipsoid (pusat kepala) di azimut `phi_deg` (0 = depan, positif =
## +X dunia) dan sudut puncak `theta_deg`, menghadap normal permukaan.
static func _shell_point(radii: Vector3, phi_deg: float, theta_deg: float, push: float) -> Transform3D:
	var phi: float = deg_to_rad(phi_deg)
	var th: float = deg_to_rad(theta_deg)
	var u := Vector3(sin(phi) * sin(th), cos(th), -cos(phi) * sin(th))
	var p := Vector3(u.x * radii.x, u.y * radii.y, u.z * radii.z)
	var n := Vector3(u.x / radii.x, u.y / radii.y, u.z / radii.z).normalized()
	return Transform3D(_basis_facing(n), p + n * push)


## Seperti _shell_point, tetapi ketinggian dinyatakan sebagai y (pusat kepala).
static func _shell_at_y(radii: Vector3, phi_deg: float, y: float) -> Transform3D:
	return _shell_point(radii, phi_deg, rad_to_deg(acos(clampf(y / radii.y, -1.0, 1.0))), 0.0)


## Jari-jari lingkar elipsoid pada ketinggian y (untuk pita, peci, topi).
static func _ring_r(radii: Vector3, y: float) -> float:
	var k: float = sqrt(maxf(1.0 - (y / radii.y) * (y / radii.y), 0.0))
	return (radii.x + radii.z) * 0.5 * k


## Geser transform dari ruang pusat-kepala ke ruang pivot "Head".
static func _hc(xf: Transform3D) -> Transform3D:
	return Transform3D(xf.basis, xf.origin + Vector3(0.0, HEAD_CENTER_Y, 0.0))


static func _build_head(s: Dictionary, mb: MeshBuilder) -> void:
	var skin: Color = s["skin"]
	var radii: Vector3 = _head_radii(s)
	var hc := Vector3(0.0, HEAD_CENTER_Y, 0.0)
	# Kepala mochi: sedikit lebih hangat ke arah dagu.
	var shade := func(u: Vector3) -> Color:
		return skin.lerp(skin.darkened(0.05), clampf(-u.y, 0.0, 1.0))
	mb.ellipsoid(Transform3D(Basis(), hc), radii, skin, SEG_HEAD.x, SEG_HEAD.y, shade)
	# Telinga hanya dibuat bila rambut tidak menutupinya (hemat segitiga).
	var ears: bool = float(_style(s)["side"]) < 95.0 and s["hat"] != "helm"
	# Pipi merona (GDD 4.1 rosy cheeks #FF9AA2): lensa pipih yang memudar ke
	# warna kulit di tepinya.
	var blush := func(u: Vector3) -> Color:
		return Palette.ROSY_CHEEK.lerp(skin, 0.55 * (1.0 - absf(u.y)))
	for side: float in [-1.0, 1.0]:
		if ears:
			var ear := Transform3D(Basis(Vector3.UP, deg_to_rad(-12.0 * side)), hc + Vector3(side * (radii.x - 0.008), EAR_Y, 0.014))
			mb.ellipsoid(ear, Vector3(0.026, 0.036, 0.030), skin, SEG_SMALL.x, SEG_SMALL.y)
		var cheek: Transform3D = _hc(_head_surface(radii, CHEEK_X * side, CHEEK_Y, 0.0015))
		mb.ellipsoid(Transform3D(cheek.basis * Basis(Vector3.RIGHT, PI * 0.5), cheek.origin), Vector3(0.036, 0.005, 0.023),
			Palette.ROSY_CHEEK, 8, 2, blush)
	# Hidung kecil yang nyaris tak terlihat, memberi bentuk pada sudut 3/4.
	mb.ellipsoid(_hc(_head_surface(radii, 0.0, NOSE_Y, -0.003)), Vector3(0.013, 0.010, 0.010), skin.darkened(0.04), SEG_TINY.x, SEG_TINY.y)


## Wajah: mata manik berkilau, alis, dan mulut -- node terpisah karena ekspresi
## menskala masing-masing (GDD 4.1 "mata manik bulat berbinar").
static func _build_face(s: Dictionary, face: Node3D) -> void:
	var radii: Vector3 = _head_radii(s)
	var brow_col: Color = (s["hair"] as Color).lerp(EYE_COLOR, 0.35)
	var lashes: bool = s["lashes"]
	var eye_shade := func(u: Vector3) -> Color:
		return EYE_COLOR.lerp(EYE_IRIS, clampf(0.15 - u.y * 0.85, 0.0, 1.0))
	for i in 2:
		var dir: float = -1.0 if i == 0 else 1.0
		var side: String = "L" if i == 0 else "R"
		# Sumbu x lokal wajah = -X dunia, jadi sudut luar mata ada di -dir.
		var outer: float = -dir
		var em := MeshBuilder.new()
		var rx: float = EYE_RADII.x
		var ry: float = EYE_RADII.y
		em.ellipsoid(Transform3D(), EYE_RADII, EYE_COLOR, 8, 5, eye_shade)
		# Dua kilau di sisi yang sama untuk kedua mata (gaya anime).
		em.ellipsoid(Transform3D(Basis(), Vector3(0.31 * rx, 0.34 * ry, EYE_RADII.z * 0.80)), Vector3(0.32 * rx, 0.28 * ry, 0.004),
			GLINT_COLOR, 6, 2)
		em.ellipsoid(Transform3D(Basis(), Vector3(-0.30 * rx, -0.37 * ry, EYE_RADII.z * 0.76)), Vector3.ONE * 0.17 * rx * Vector3(1.0, 1.0, 0.6),
			GLINT_COLOR, 4, 2)
		if lashes:
			var lash := Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(32.0 * outer)), Vector3(0.82 * rx * outer, 0.74 * ry, 0.004))
			em.ellipsoid(lash, Vector3(0.44 * rx, 0.0048, 0.004), EYE_COLOR, 5, 2)
		var eye: MeshInstance3D = em.commit("Eye" + side)
		eye.transform = _head_surface(radii, EYE_X * dir, EYE_Y, -0.003)
		face.add_child(eye)
		_remember(eye)

		var bm := MeshBuilder.new()
		bm.capsule(Vector3(-0.019, 0.0, 0.0), Vector3(0.019, 0.0, 0.0), 0.0058, 0.0058, brow_col, 4, 1)
		var brow: MeshInstance3D = bm.commit("Brow" + side)
		brow.transform = _head_surface(radii, EYE_X * dir, BROW_Y, 0.001)
		face.add_child(brow)
		_remember(brow)

	# Mulut senyum berbentuk "D" dengan lidah merah muda; ekspresi menskala dan
	# memutarnya (180° = cemberut).
	var mm := MeshBuilder.new()
	var d := PackedVector2Array()
	for k in 9:
		var a: float = PI * float(k) / 8.0
		d.append(Vector2(0.020 * cos(a), -0.018 * sin(a)))
	mm.polygon(Transform3D(), d, MOUTH_COLOR)
	var tongue := PackedVector2Array()
	for k2 in 7:
		var a2: float = PI * float(k2) / 6.0
		tongue.append(Vector2(0.0105 * cos(a2), -0.0105 - 0.0045 * sin(a2)))
	mm.polygon(Transform3D(Basis(), Vector3(0.0, 0.0, 0.0006)), tongue, TONGUE_COLOR)
	var mouth: MeshInstance3D = mm.commit("Mouth")
	mouth.transform = _head_surface(radii, 0.0, MOUTH_Y, 0.0012)
	face.add_child(mouth)
	_remember(mouth)


## Warna rambut dengan kilau anime melingkar di ubun-ubun dan tepi yang sedikit
## lebih gelap. `tip` (opsional) memudarkan ujung rambut (ombre).
static func _hair_shader(base: Color, tip: Variant = null) -> Callable:
	return func(u: Vector3) -> Color:
		var th: float = acos(clampf(u.y, -1.0, 1.0))
		var shine: float = 0.20 * maxf(0.0, 1.0 - absf(th - 0.55) / 0.28)
		var c: Color = base.lightened(shine)
		c = c.darkened(clampf((th - 1.25) * 0.20, 0.0, 0.16))
		if tip is Color and th > 1.40:
			c = c.lerp(tip, clampf((th - 1.40) / 0.60, 0.0, 1.0))
		return c


## Garis rambut per azimut (0 = depan): dahi, samping, tengkuk (derajat dari
## puncak). Peralihan dahi -> samping terjadi di antara azimut cut_a..cut_b;
## rentang sempit menghasilkan potongan rata setinggi rahang (bob).
static func _hairline(front_deg: float, side_deg: float, back_deg: float,
		cut_a: float = 15.0, cut_b: float = 95.0) -> Callable:
	var f: float = deg_to_rad(front_deg)
	var sd: float = deg_to_rad(side_deg)
	var bk: float = deg_to_rad(back_deg)
	var a: float = deg_to_rad(cut_a)
	var b: float = deg_to_rad(cut_b)
	return func(phi: float) -> float:
		var p: float = absf(wrapf(phi, -PI, PI))
		var t: float = lerpf(f, sd, smoothstep(a, b, p))
		if p > PI * 0.5:
			t = lerpf(t, bk, smoothstep(PI * 0.5, PI, p))
		return clampf(t, 0.2, PI)


## Garis rambut cangkang untuk gaya `st`.
static func _style_hairline(st: Dictionary) -> Callable:
	var cut: Array = st.get("cut", [15.0, 95.0])
	return _hairline(float(st["front"]), float(st["side"]), float(st["back"]), float(cut[0]), float(cut[1]))


static func _build_hair(s: Dictionary, mb: MeshBuilder) -> void:
	var style: String = s["hair_style"]
	var st: Dictionary = _style(s)
	var color: Color = s["hair"]
	var puff: float = st["puff"]
	var radii: Vector3 = _hair_radii(s)
	var tip: Variant = color.lerp(Palette.PASTEL_STRAWBERRY, 0.75) if style == "ombre" else null
	var flare: float = float(st.get("flare", 0.0))
	# Tepi cangkang diselipkan ke kulit (tanpa celah), kecuali tepi bob yang mengembang.
	var tuck: float = puff / (HEAD_RY + puff)
	var shape := func(theta: float, t: float) -> float:
		var out: float = smoothstep(deg_to_rad(80.0), deg_to_rad(130.0), theta)
		return (1.0 + flare * out) * (1.0 - tuck * (1.0 - out) * smoothstep(0.72, 1.0, t))
	var line: Callable = _style_hairline(st)
	# Ubun-ubun yang tertutup topi tidak butuh resolusi penuh.
	var rings: int = SEG_HAIR.y - 1 if s["hat"] in CROWN_HATS else SEG_HAIR.y
	mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, HEAD_CENTER_Y, 0.0)), radii, color, SEG_HAIR.x, rings,
		_hair_shader(color, tip), line, shape)
	_build_bangs(s, mb, radii, color, tip)
	_build_hair_extras(s, mb, radii, color, line)


## Gerigi poni per gaya: [azimut ujung rumbai (derajat), panjang relatif 0..1].
## Lembah di antara dua ujung selalu sedikit di bawah tepi cangkang, jadi garis
## bawah poni sepenuhnya zig-zag.
const FRINGES: Dictionary = {
	# Poni "M": dua rumbai tengah terpanjang, rumbai tepi lebih pendek.
	"tuft": [[-40.0, 0.62], [-20.0, 0.94], [0.0, 1.0], [20.0, 0.94], [40.0, 0.62]],
	# Poni rata (hime): gerigi kecil dan rapat.
	"straight": [[-40.0, 0.92], [-30.0, 0.98], [-20.0, 1.0], [-10.0, 1.0], [0.0, 1.0], [10.0, 1.0], [20.0, 1.0],
		[30.0, 0.98], [40.0, 0.92]],
	# Poni menyapu ke satu sisi (paling panjang di kanan layar).
	"side": [[-40.0, 1.0], [-20.0, 0.92], [0.0, 0.78], [20.0, 0.58], [40.0, 0.40]],
	# Belah tengah bergaya tirai: dahi terlihat di tengah.
	"part": [[-35.0, 0.92], [-15.0, 0.62], [15.0, 0.62], [35.0, 0.92]],
	# Jambul pendek di bawah rambut runcing.
	"spike": [[-20.0, 0.45], [0.0, 0.55], [20.0, 0.45]],
}
const FRINGE_HALF_WIDTH: float = 55.0


## Poni: satu potongan cangkang di atas dahi yang menyatu dengan rambut (warna
## & kilau sama), menggembung sedikit, lalu menyelip ke kulit dengan tepi bawah
## bergerigi. Ujung terpanjang berhenti di BANG_BOTTOM supaya alis & mata selalu
## terlihat; di bawah topi, bagian atasnya ikut tersembunyi.
static func _build_bangs(s: Dictionary, mb: MeshBuilder, radii: Vector3, color: Color, tip: Variant) -> void:
	var st: Dictionary = _style(s)
	var bangs: String = st["bangs"]
	var f: Dictionary = _fringe(s)
	if not f.is_empty():
		var tuck_k: float = f["tuck"]
		var shape := func(_theta: float, t: float) -> float:
			# Kurva Bezier: tersembunyi di bawah cangkang -> menggembung -> menyelip.
			return (1.0 - t) * (1.0 - t) * 0.99 + 2.0 * t * (1.0 - t) * 1.10 + t * t * tuck_k
		var half: float = f["half"]
		mb.shell(Transform3D(Basis(), Vector3(0.0, HEAD_CENTER_Y, 0.0)), radii, color, -half, half,
			int(f["cols"]), 2, float(f["top"]), f["bottom"], _hair_shader(color, tip), shape)
	if bangs == "spike":
		# Jambul runcing dengan tinggi & kemiringan bervariasi (bukan mahkota rata).
		var y_top: float = cos(deg_to_rad(float(st["front"]) - 16.0)) * radii.y
		var heights: Array[float] = [0.056, 0.074, 0.084, 0.070, 0.060]
		var leans: Array[float] = [-30.0, -18.0, -10.0, -20.0, -32.0]
		var rolls: Array[float] = [16.0, 8.0, 0.0, -8.0, -16.0]
		for k4 in 5:
			var base: Transform3D = _shell_at_y(radii, -44.0 + 22.0 * float(k4), y_top - 0.010)
			var tilt := Basis(base.basis.x, deg_to_rad(leans[k4])) * Basis(base.basis.y, deg_to_rad(rolls[k4]))
			var xf := Transform3D(tilt * base.basis * Basis(Vector3.RIGHT, PI * 0.5), base.origin + Vector3(0.0, HEAD_CENTER_Y, 0.0))
			var h: float = heights[k4]
			mb.lathe(xf, PackedVector2Array([Vector2(0.036, -0.012), Vector2(0.024, h * 0.48), Vector2(0.0, h)]), color.lightened(0.05), 6)
	if st.has("frame") and not (s["hat"] in SIDE_HATS):
		# Rambut samping menempel di atas cangkang, membingkai pipi (kecuali
		# tertutup topi yang turun sampai pelipis).
		for side2: float in [-1.0, 1.0]:
			_hair_lock(mb, radii - Vector3.ONE * 0.010, radii + Vector3.ONE * 0.005, 70.0 * side2, 0.112, float(st["frame"]),
				0.026, 0.018, color, 0.0, tip)


## Parameter potongan poni untuk spec `s` (kosong bila gaya ini tanpa poni):
## {tuck, top, bottom: Callable(phi) -> theta, half, cols}.
static func _fringe(s: Dictionary) -> Dictionary:
	var st: Dictionary = _style(s)
	var bangs: String = st["bangs"]
	if not FRINGES.has(bangs):
		return {}
	var radii: Vector3 = _hair_radii(s)
	var tuck_k: float = (_head_radii(s).y + 0.004) / radii.y
	var theta_long: float = acos(clampf(BANG_BOTTOM / (radii.y * tuck_k), -1.0, 1.0))
	var theta_edge: float = deg_to_rad(float(st["front"]))
	return {
		"tuck": tuck_k,
		"top": theta_edge - deg_to_rad(22.0),
		"bottom": _fringe_line(FRINGES[bangs], theta_edge + deg_to_rad(2.0), theta_long, _style_hairline(st)),
		"half": deg_to_rad(FRINGE_HALF_WIDTH),
		"cols": int(FRINGE_HALF_WIDTH * 2.0 / 5.0),
	}


## Titik terendah tepi rambut (poni maupun cangkang) yang berada di depan mata
## & alis untuk gaya `hair_style` (y relatif pusat kepala, height 1.0).
## Kontrak visual: selalu di atas alis supaya mata & ekspresi terbaca (dipakai
## test). INF bila tidak ada rambut di zona itu.
static func lowest_hair_over_eyes(hair_style: String) -> float:
	var s: Dictionary = _normalize({"hair_style": hair_style})
	var st: Dictionary = _style(s)
	var radii: Vector3 = _hair_radii(s)
	var zone: float = EYE_X + EYE_RADII.x + 0.006
	var lowest: float = INF
	# Tepi cangkang (diselipkan ke kulit di depan).
	var line: Callable = _style_hairline(st)
	var tuck: float = float(st["puff"]) / (HEAD_RY + float(st["puff"]))
	for deg in range(-90, 91):
		var phi: float = deg_to_rad(float(deg))
		var th: float = float(line.call(phi))
		var k: float = 1.0 - tuck * (1.0 - smoothstep(deg_to_rad(80.0), deg_to_rad(130.0), th))
		if absf(sin(phi) * sin(th) * radii.x * k) <= zone:
			lowest = minf(lowest, cos(th) * radii.y * k)
	# Tepi bawah poni.
	var f: Dictionary = _fringe(s)
	if not f.is_empty():
		var bottom: Callable = f["bottom"]
		var half: float = f["half"]
		var cols: int = f["cols"]
		var fk: float = f["tuck"]
		for j in cols + 1:
			var phi2: float = lerpf(-half, half, float(j) / float(cols))
			var th2: float = float(bottom.call(phi2))
			if absf(sin(phi2) * sin(th2) * radii.x * fk) <= zone:
				lowest = minf(lowest, cos(th2) * radii.y * fk)
	return lowest


## Garis bawah poni (theta per azimut) dari daftar ujung rumbai: segitiga antara
## tiap ujung dan lembahnya, lalu melandai ke garis rambut cangkang di tepi.
static func _fringe_line(teeth: Array, theta_valley: float, theta_long: float, line: Callable) -> Callable:
	var phis := PackedFloat32Array()
	var thetas := PackedFloat32Array()
	for tooth: Array in teeth:
		phis.append(deg_to_rad(float(tooth[0])))
		thetas.append(lerpf(theta_valley, theta_long, float(tooth[1])))
	var edge: float = deg_to_rad(FRINGE_HALF_WIDTH)
	return func(phi: float) -> float:
		var p: float = wrapf(phi, -PI, PI)
		var n: int = phis.size()
		if p <= phis[0]:
			var side_l: float = float(line.call(-edge)) - deg_to_rad(3.0)
			return lerpf(side_l, thetas[0], clampf((p + edge) / maxf(phis[0] + edge, 0.001), 0.0, 1.0))
		if p >= phis[n - 1]:
			var side_r: float = float(line.call(edge)) - deg_to_rad(3.0)
			return lerpf(thetas[n - 1], side_r, clampf((p - phis[n - 1]) / maxf(edge - phis[n - 1], 0.001), 0.0, 1.0))
		for k in range(1, n):
			if p <= phis[k]:
				var mid: float = (phis[k - 1] + phis[k]) * 0.5
				if p <= mid:
					return lerpf(thetas[k - 1], theta_valley, (p - phis[k - 1]) / (mid - phis[k - 1]))
				return lerpf(theta_valley, thetas[k], (p - mid) / (phis[k] - mid))
		return theta_valley


## Satu rumbai rambut dari ketinggian y_top (pada elipsoid `top_r`) ke y_bottom
## (pada elipsoid `bottom_r`), relatif pusat kepala, di azimut phi_deg.
## twist_deg positif menggeser ujung bawah ke kanan layar (-X dunia).
static func _hair_lock(mb: MeshBuilder, top_r: Vector3, bottom_r: Vector3, phi_deg: float, y_top: float, y_bottom: float,
		width: float, thick: float, color: Color, twist_deg: float, tip: Variant = null) -> void:
	var a: Transform3D = _shell_at_y(top_r, phi_deg, y_top)
	var b: Transform3D = _shell_at_y(bottom_r, phi_deg, y_bottom)
	var span: Vector3 = a.origin - b.origin
	var half: float = span.length() * 0.5
	if half < 0.004:
		return
	var y_dir: Vector3 = span / (half * 2.0)
	var n: Vector3 = (a.basis.z + b.basis.z).normalized()
	var x_dir: Vector3 = y_dir.cross(n).normalized()
	var z_dir: Vector3 = x_dir.cross(y_dir).normalized()
	var basis := Basis(x_dir, y_dir, z_dir) * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(twist_deg))
	var center: Vector3 = (a.origin + b.origin) * 0.5
	mb.ellipsoid(Transform3D(basis, center + Vector3(0.0, HEAD_CENTER_Y, 0.0)), Vector3(width, half, thick),
		color, SEG_LOCK.x, SEG_LOCK.y, _hair_shader(color, tip))


## Posisi sanggul (pusat kepala): di atas-belakang agar terlihat dari depan.
static func _bun_offset() -> Vector3:
	return Vector3(0.0, 0.150, 0.130)


## Bentuk rambut khusus: kuncir, kepang, sanggul, ikal, jenggot.
static func _build_hair_extras(s: Dictionary, mb: MeshBuilder, radii: Vector3, color: Color, line: Callable) -> void:
	var hc := Vector3(0.0, HEAD_CENTER_Y, 0.0)
	match str(s["hair_style"]):
		"kuncir_ganda":
			for side: float in [-1.0, 1.0]:
				_tail(mb, hc + Vector3(0.200 * side, 0.082, 0.060), hc + Vector3(0.280 * side, -0.120, 0.112), 0.046, color)
		"panjang_kepang":
			var beads: Array[Vector3] = [Vector3(0.0, -0.100, 0.192), Vector3(0.006, -0.158, 0.166), Vector3(-0.005, -0.212, 0.148)]
			for k in beads.size():
				var r: float = 0.046 - 0.005 * float(k)
				var roll: float = 16.0 if k % 2 == 0 else -16.0
				mb.ellipsoid(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(roll)), hc + beads[k]),
					Vector3(r, r * 0.95, r * 0.80), color.lightened(0.05 * float(k % 2)), SEG_SMALL.x - 1, SEG_SMALL.y, _hair_shader(color))
			mb.torus(Transform3D(Basis(), hc + Vector3(0.0, -0.250, 0.142)), 0.021, 0.009, Palette.PASTEL_STRAWBERRY, 6, 3)
			mb.ellipsoid(Transform3D(Basis(), hc + Vector3(0.0, -0.280, 0.144)), Vector3(0.028, 0.032, 0.022), color, SEG_SMALL.x - 1, SEG_SMALL.y)
		"sanggul":
			mb.ellipsoid(Transform3D(Basis(), hc + _bun_offset()), Vector3(0.078, 0.072, 0.074), color,
				SEG_SMALL.x + 2, SEG_SMALL.y + 1, _hair_shader(color))
		"ikal":
			# Cincin ikal empuk menutupi tepi cangkang di samping & belakang.
			for k2 in 9:
				var phi: float = 70.0 + 27.5 * float(k2)
				var edge: float = rad_to_deg(float(line.call(deg_to_rad(phi))))
				var curl: Transform3D = _shell_point(radii, phi, edge - 10.0 - 8.0 * float(k2 % 2), -0.004)
				mb.ellipsoid(Transform3D(curl.basis, curl.origin + hc), Vector3(0.042, 0.044, 0.034),
					color.lightened(0.05 * float(k2 % 2)), SEG_SMALL.x, SEG_SMALL.y)
		"jenggot":
			# Jenggot rapi di sepanjang rahang, di bawah mulut.
			mb.ellipsoid(Transform3D(Basis(), hc + Vector3(0.0, -0.166, FRONT * 0.070)), Vector3(0.142, 0.056, 0.092), color, 10, 4)
		_:
			pass


## Kuncir: lathe menggembung dari ikatan pita di akar ke ujung yang meruncing.
static func _tail(mb: MeshBuilder, root_p: Vector3, tip_p: Vector3, r: float, color: Color) -> void:
	var axis: Vector3 = root_p - tip_p
	var length: float = axis.length()
	var basis: Basis = MeshBuilder.frame_y(axis / length)
	var profile := PackedVector2Array([
		Vector2(0.0, 0.0), Vector2(r * 0.45, length * 0.06), Vector2(r * 0.95, length * 0.34),
		Vector2(r * 0.90, length * 0.70), Vector2(r * 0.45, length), Vector2(0.0, length + 0.006),
	])
	var shade := func(y: float, _phi: float) -> Color:
		return color.lightened(0.10 * clampf(y / length, 0.0, 1.0))
	mb.lathe(Transform3D(basis, tip_p), profile, color, 6, shade)
	mb.torus(Transform3D(basis, tip_p + basis.y * (length * 0.95)), r * 0.52, 0.009, Palette.PASTEL_STRAWBERRY, 6, 3)


## Topi & penutup kepala. Semua geometri masuk HeadMesh; tepi depannya selalu
## di atas alis.
static func _build_hat(s: Dictionary, mb: MeshBuilder) -> void:
	var kind: String = s["hat"]
	var hr: Vector3 = _hair_radii(s) + Vector3.ONE * 0.006
	var hc := Vector3(0.0, HEAD_CENTER_Y, 0.0)
	var cloth: Color = s["cloth"]
	var accent: Color = s["apron"] if s["apron"] is Color else Palette.PASTEL_MINT
	match kind:
		"topi_koki", "toque":
			var tall: bool = kind == "toque"
			var tilt := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(0.0 if tall else 6.0))
			var y0: float = BRIM_Y
			var band_r: float = _ring_r(hr, y0)
			var band_h: float = 0.072
			mb.cylinder(Transform3D(tilt, hc + tilt * Vector3(0.0, y0 + band_h * 0.5, 0.0)), band_h, band_r * 0.99, band_r,
				Palette.FLOUR_WHITE, 14, false, false)
			var top: PackedVector2Array
			var folds: int = 8 if tall else 5
			if tall:
				top = PackedVector2Array([Vector2(band_r, 0.0), Vector2(band_r + 0.010, 0.120), Vector2(band_r + 0.018, 0.200),
					Vector2(band_r + 0.006, 0.236), Vector2(band_r * 0.62, 0.256), Vector2(0.0, 0.260)])
			else:
				top = PackedVector2Array([Vector2(band_r - 0.004, 0.0), Vector2(band_r + 0.020, 0.040), Vector2(band_r + 0.028, 0.092),
					Vector2(band_r + 0.016, 0.140), Vector2(band_r * 0.80, 0.172), Vector2(band_r * 0.33, 0.186), Vector2(0.0, 0.188)])
			var fold_shade := func(y: float, phi: float) -> Color:
				var k: float = 0.5 + 0.5 * cos(phi * float(folds))
				return Palette.FLOUR_WHITE.darkened(0.07 * k * clampf(1.2 - y / 0.26, 0.0, 1.0))
			mb.lathe(Transform3D(tilt, hc + tilt * Vector3(0.0, y0 + band_h - 0.004, 0.0)), top, Palette.FLOUR_WHITE, 16, fold_shade)
		"bandana":
			# Cukup jauh dari rambut agar faset bandana tidak ditembus gembungan poni.
			var br: Vector3 = hr + Vector3.ONE * 0.012
			var band: Color = Palette.GOLDEN_CRUST
			var bshade := func(u: Vector3) -> Color:
				return band.lightened(0.12 * clampf(u.y, 0.0, 1.0))
			var front: float = rad_to_deg(acos(BRIM_Y / br.y))
			# Segmen radial sama dengan cangkang rambut agar faset sejajar (rambut
			# tidak menembus bandana).
			mb.ellipsoid(Transform3D(Basis(), hc), br, band, SEG_HAIR.x, 4, bshade, _hairline(front, 92.0, 106.0))
			# Polkadot krem.
			for k in 3:
				var dot: Transform3D = _shell_point(br, -34.0 + 34.0 * float(k), 32.0 + 12.0 * float(k % 2), 0.002)
				mb.polygon(_hc(dot), _circle(0.014, 7), Palette.VANILLA_CREAM)
			var knot: Vector3 = hc + Vector3(0.0, 0.020, -FRONT * (br.z * 0.93))
			_bow(mb, knot, band, 1.1, Vector3(0.0, 0.0, -FRONT))
			for side: float in [-1.0, 1.0]:
				mb.ellipsoid(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(10.0 * side)), knot + Vector3(0.018 * side, -0.050, 0.010)),
					Vector3(0.016, 0.038, 0.010), band.darkened(0.06), SEG_TINY.x + 1, SEG_TINY.y)
		"bando", "bando_kelinci":
			_headband(mb, hr, Palette.PASTEL_STRAWBERRY)
			if kind == "bando_kelinci":
				for side2: float in [-1.0, 1.0]:
					var ear_b := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(-14.0 * side2))
					var base: Vector3 = hc + Vector3(0.070 * side2, hr.y - 0.012, 0.030)
					mb.ellipsoid(Transform3D(ear_b, base + ear_b * Vector3(0.0, 0.072, 0.0)), Vector3(0.034, 0.084, 0.020),
						Palette.PASTEL_STRAWBERRY, SEG_SMALL.x, SEG_SMALL.y + 1)
					mb.ellipsoid(Transform3D(ear_b, base + ear_b * Vector3(0.0, 0.070, FRONT * 0.013)), Vector3(0.018, 0.060, 0.010),
						Palette.ROSY_CHEEK.lightened(0.25), SEG_SMALL.x, SEG_SMALL.y)
		"hachimaki":
			var y1: float = BRIM_Y
			var rr: float = _ring_r(hr, y1)
			mb.torus(Transform3D(Basis(), hc + Vector3(0.0, y1, 0.0)), rr, 0.017, Palette.FLOUR_WHITE, 16, 4)
			var mark: Transform3D = _shell_at_y(Vector3(rr, hr.y, rr) + Vector3.ONE * 0.017, 0.0, y1)
			mb.polygon(Transform3D(mark.basis, mark.origin + hc + mark.basis.z * 0.002), _circle(0.017, 10), Palette.DANGER)
			var back: Vector3 = hc + Vector3(0.0, y1, -FRONT * (rr + 0.012))
			for side3: float in [-1.0, 1.0]:
				mb.ellipsoid(Transform3D(Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(14.0 * side3)), back + Vector3(0.020 * side3, -0.046, 0.004)),
					Vector3(0.014, 0.046, 0.006), Palette.FLOUR_WHITE, SEG_TINY.x, SEG_TINY.y)
		"topi_pet":
			# Warna topi: celemek staf, atau versi gelap seragam (kurir cokelat).
			var cap_col: Color = accent if s["apron"] is Color else _shift(cloth, -0.22)
			var cr: Vector3 = hr + Vector3(0.014, 0.010, 0.014)
			var cap_b := Basis.from_euler(Vector3(deg_to_rad(-4.0), 0.0, deg_to_rad(-8.0)))
			var cshade := func(u: Vector3) -> Color:
				return cap_col.lightened(0.10 * clampf(u.y, 0.0, 1.0))
			var vy: float = BRIM_Y - 0.004
			var cfront: float = rad_to_deg(acos(vy / cr.y))
			mb.ellipsoid(Transform3D(cap_b, hc), cr, cap_col, SEG_HAIR.x, 5, cshade, _hairline(cfront, 88.0, 96.0))
			var vz: float = _ring_r(cr, vy)
			# Pet pendek dan sedikit terangkat agar tidak menutupi mata dari kamera atas.
			var bill := cap_b * Basis(Vector3.RIGHT, deg_to_rad(10.0))
			mb.ellipsoid(Transform3D(bill, hc + cap_b * Vector3(0.0, vy, FRONT * (vz + 0.004))), Vector3(0.112, 0.013, 0.048),
				cap_col.darkened(0.16), SEG_SMALL.x + 2, SEG_SMALL.y)
			mb.ellipsoid(Transform3D(cap_b, hc + cap_b * Vector3(0.0, cr.y, 0.0)), Vector3(0.018, 0.010, 0.018), cap_col.darkened(0.12), SEG_TINY.x, SEG_TINY.y)
		"helm":
			var shell: Vector3 = _head_radii(s) + Vector3.ONE * 0.046
			var stripe := func(u: Vector3) -> Color:
				if absf(u.x) < 0.16 and u.y > 0.2:
					return Palette.FLOUR_WHITE
				return cloth.lightened(0.10 * clampf(u.y, 0.0, 1.0))
			var hfront: float = rad_to_deg(acos((BRIM_Y - 0.010) / shell.y))
			mb.ellipsoid(Transform3D(Basis(), hc + Vector3(0.0, 0.008, 0.0)), shell, cloth, SEG_HAIR.x, 6, stripe, _hairline(hfront, 104.0, 112.0))
			# Kaca helm terangkat di atas dahi.
			var visor: Transform3D = _shell_at_y(shell, 0.0, BANG_BOTTOM + 0.050)
			mb.ellipsoid(Transform3D(visor.basis, visor.origin + hc + Vector3(0.0, 0.008, 0.0)), Vector3(0.130, 0.036, 0.018), DARK_GLASS, SEG_SMALL.x + 2, SEG_SMALL.y)
			# Tali dagu.
			var sx: float = HEAD_RX + 0.012
			var strap := Basis.from_scale(Vector3(1.0, (HEAD_RY + 0.010) / sx, 1.0)) * Basis(Vector3.RIGHT, PI * 0.5)
			mb.torus(Transform3D(strap, hc + Vector3(0.0, 0.0, FRONT * 0.030)), sx, 0.005, DARK_GLASS, 10, 3,
				deg_to_rad(118.0), deg_to_rad(242.0))
		"peci":
			var tilt2 := Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(4.0))
			var yb: float = BRIM_Y + 0.010
			var rb: float = _ring_r(hr, yb) + 0.004
			# Tutup datar peci selalu sedikit di atas ubun-ubun.
			var h: float = hr.y + 0.012 - yb
			mb.cylinder(Transform3D(tilt2 * Basis.from_scale(Vector3(1.03, 1.0, 0.97)), hc + tilt2 * Vector3(0.0, yb + h * 0.5, 0.0)),
				h, rb * 0.94, rb, PECI_BLACK, 14, true, false)
		_:
			pass


## Bando melengkung dari telinga ke telinga lewat ubun-ubun (mengikuti elips kepala).
static func _headband(mb: MeshBuilder, hr: Vector3, color: Color) -> void:
	var r: float = hr.x + 0.004
	var basis := Basis.from_scale(Vector3(1.0, (hr.y + 0.004) / r, 1.0)) * Basis(Vector3.RIGHT, PI * 0.5)
	mb.torus(Transform3D(basis, Vector3(0.0, HEAD_CENTER_Y, 0.030)), r, 0.013, color, 12, 4, deg_to_rad(-100.0), deg_to_rad(100.0))


# ===========================================================================
# ANGGOTA GERAK
# ===========================================================================

static func _shoulder_x(chubby: float) -> float:
	return SHOULDER_X * (1.0 + 0.28 * chubby)


## Rotasi lengan saat memeluk barang di depan badan (kardus, adonan, loyang).
## `dir` -1 = ArmL, +1 = ArmR. Dipakai juga oleh ProceduralAnimationSystem.
static func carry_arm_rotation(dir: float) -> Vector3:
	return Vector3(deg_to_rad(52.0), 0.0, deg_to_rad(-6.0 * dir))


## Pose istirahat lengan: sedikit terbuka (siluet "A"); kedua lengan maju memeluk
## barang di depan badan; tangan kanan terangkat memegang kamera.
static func _arm_pose(s: Dictionary, dir: float) -> Vector3:
	for p: String in s["prop"]:
		if p in FRONT_PROPS:
			return carry_arm_rotation(dir)
		if p == "kamera" and dir > 0.0:
			return Vector3(deg_to_rad(78.0), 0.0, deg_to_rad(-10.0))
	return Vector3(0.0, 0.0, deg_to_rad(7.0 * dir))


## Lengan yang memegang barang hampir tidak berayun saat berjalan.
static func _arm_swing(s: Dictionary, dir: float) -> float:
	for p: String in s["prop"]:
		if p in FRONT_PROPS or (p == "kamera" and dir > 0.0):
			return 0.15
	return 1.0


static func _build_arm(s: Dictionary, mb: MeshBuilder) -> void:
	var chubby: float = s["chubby"]
	var cloth: Color = s["cloth"]
	var skin: Color = s["skin"]
	var r0: float = ARM_RADIUS * (1.0 + 0.25 * chubby)
	var cuff: Color = cloth.darkened(0.10)
	var long_sleeve: bool = s["sleeve"] == "long"
	var sleeve_end: float = 0.84 if long_sleeve else 0.36
	var cuff_end: float = 1.2 if long_sleeve else 0.48
	var cuts := PackedFloat32Array([sleeve_end, sleeve_end + 0.01])
	if not long_sleeve:
		cuts.append(cuff_end)
		cuts.append(cuff_end + 0.01)
	var shade := func(f: float) -> Color:
		if f < sleeve_end + 0.005:
			return cloth
		return cuff if f < cuff_end + 0.005 else skin
	# Tutup bahu tetap bulat; tutup pergelangan tertutup tangan, cukup satu cincin.
	mb.capsule(Vector3.ZERO, Vector3(0.0, -ARM_LENGTH, 0.0), r0, r0 * 0.84, cloth, SEG_LIMB, 2, shade, cuts, 1)
	var hand_col: Color = skin
	var hand_r := Vector3(0.046, 0.050, 0.042) * (1.0 + 0.2 * chubby)
	for acc: String in s["accessory"]:
		if acc == "sarung_tangan":
			hand_col = Palette.VANILLA_CREAM
			hand_r *= 1.12
		elif acc == "sarung_tangan_satin":
			hand_col = Palette.FLOUR_WHITE
			hand_r *= 1.12
	mb.ellipsoid(Transform3D(Basis(), Vector3(0.0, -ARM_LENGTH - 0.024, 0.0)), hand_r, hand_col, SEG_LIMB, 4)


static func _build_leg(s: Dictionary, mb: MeshBuilder) -> void:
	var chubby: float = s["chubby"]
	var pants: Color = s["pants"]
	var skin: Color = s["skin"]
	var legwear: String = s["legwear"]
	var r0: float = LEG_RADIUS * (1.0 + 0.2 * chubby)
	var socks: Color = Palette.FLOUR_WHITE
	var hem: Color = pants.darkened(0.14)
	var cuts := PackedFloat32Array()
	var shade: Callable
	match legwear:
		"skin":
			cuts = PackedFloat32Array([0.72, 0.73])
			shade = func(f: float) -> Color: return skin if f < 0.725 else socks
		"shorts":
			cuts = PackedFloat32Array([0.40, 0.41, 0.72, 0.73])
			shade = func(f: float) -> Color:
				if f < 0.405:
					return pants
				return skin if f < 0.725 else socks
		_:
			shade = func(f: float) -> Color: return pants.lerp(hem, clampf(f, 0.0, 1.0))
	# Kedua ujung kaki tersembunyi (di dalam torso & sepatu): satu cincin cukup.
	mb.capsule(Vector3.ZERO, Vector3(0.0, -LEG_LENGTH, 0.0), r0, r0 * 0.86, pants, SEG_LIMB, 1, shade, cuts, 1)
	# Sepatu mochi bersol datar krem: lathe lonjong, alasnya tepat di lantai.
	var shoe: Color = s["shoes"]
	var fat: float = 1.0 + 0.12 * chubby
	var sole_top: float = -0.034
	var shoe_profile := PackedVector2Array([
		Vector2(0.0, -0.044), Vector2(0.051, -0.044), Vector2(0.057, sole_top - 0.0005),
		Vector2(0.0572, sole_top + 0.0005), Vector2(0.046, 0.026), Vector2(0.0, 0.044),
	])
	var shoe_shade := func(y: float, _phi: float) -> Color:
		if y < sole_top:
			return SOLE_CREAM
		return shoe.lightened(0.14 * clampf(y / 0.044, 0.0, 1.0))
	var foot := Basis.from_scale(Vector3(fat, 1.0, 1.38 * fat))
	mb.lathe(Transform3D(foot, Vector3(0.0, -0.206, FRONT * 0.020)), shoe_profile, shoe, 8, shoe_shade)


# ===========================================================================
# AKSESORI
# ===========================================================================

## Pasang satu aksesori ke builder segmen yang tepat. Nilai tak dikenal
## diabaikan tanpa error (degradasi aman).
static func _attach_accessory(id: String, s: Dictionary, mb: Dictionary) -> void:
	var head: MeshBuilder = mb["head"]
	var body: MeshBuilder = mb["body"]
	var apron: MeshBuilder = mb["apron"]
	var arm_l: MeshBuilder = mb["arm_l"]
	var arm_r: MeshBuilder = mb["arm_r"]
	var radii: Vector3 = _head_radii(s)
	var hair_r: Vector3 = _hair_radii(s)
	var chubby: float = s["chubby"]
	var hc := Vector3(0.0, HEAD_CENTER_Y, 0.0)
	# Lencana di dada menempel di atas celemek bila ada.
	var chest_push: float = 0.013 if s["apron"] is Color else 0.003
	match id:
		"kacamata_bulat":
			_glasses(head, radii, Palette.DARK_CHOCOLATE)
		"kacamata_emas":
			_glasses(head, radii, Palette.GOLD_STAR)
		"kacamata_rantai":
			_glasses(head, radii, Palette.GOLD_STAR)
			for side: float in [-1.0, 1.0]:
				var a: Vector3 = _hc(_head_surface(radii, (EYE_X + EYE_RADII.y + 0.004) * side, EYE_Y, 0.010)).origin
				head.capsule(a, a + Vector3(0.020 * side, -0.100, 0.030), 0.0035, 0.0035, Palette.GOLD_STAR, 4, 1)
		"pita_kuning":
			for side2: float in [-1.0, 1.0]:
				var at: Vector3
				if s["hair_style"] == "kuncir_ganda":
					at = hc + Vector3(0.214 * side2, 0.090, 0.060)
				else:
					at = hc + _shell_at_y(hair_r, 66.0 * side2, 0.105).origin
				_bow(head, at, Palette.BUTTER_YELLOW, 1.0, at - hc)
		"jepit_stroberi":
			var clip: Transform3D = _shell_at_y(hair_r, -40.0, 0.150)
			var cxf := Transform3D(clip.basis, clip.origin + hc + clip.basis.z * 0.010)
			head.ellipsoid(cxf, Vector3(0.022, 0.026, 0.016), Palette.DANGER, SEG_SMALL.x, SEG_SMALL.y)
			head.ellipsoid(Transform3D(cxf.basis, cxf.origin + cxf.basis.y * 0.024), Vector3(0.017, 0.007, 0.012), Palette.SUCCESS, SEG_TINY.x, SEG_TINY.y)
		"bando_gingham":
			var at2: Vector3 = hc + _shell_at_y(hair_r, -58.0, 0.150).origin
			var checks := func(u: Vector3) -> Color:
				return Palette.GINGHAM_A if int(floorf((u.x + 1.0) * 3.0) + floorf((u.y + 1.0) * 3.0)) % 2 == 0 else Palette.GINGHAM_B
			var gb: Basis = _basis_facing(at2 - hc)
			for side3: float in [-1.0, 1.0]:
				var wing := gb * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(22.0 * side3))
				head.ellipsoid(Transform3D(wing, at2 + gb.x * (0.030 * side3)), Vector3(0.032, 0.022, 0.013), Palette.GINGHAM_A, 6, 3, checks)
			head.ellipsoid(Transform3D(gb, at2 + gb.z * 0.004), Vector3(0.012, 0.014, 0.014), Palette.GINGHAM_A.darkened(0.12), SEG_TINY.x, SEG_TINY.y)
		"anting_mutiara":
			for side4: float in [-1.0, 1.0]:
				head.ellipsoid(Transform3D(Basis(), hc + Vector3(side4 * (radii.x + 0.004), EAR_Y - 0.048, 0.016)), Vector3.ONE * 0.015,
					Palette.FLOUR_WHITE, SEG_TINY.x + 1, SEG_TINY.y + 1)
		"kumis":
			var stache: Color = _shift(s["hair"] as Color, -0.12)
			for side5: float in [-1.0, 1.0]:
				var m: Transform3D = _hc(_head_surface(radii, 0.022 * side5, (NOSE_Y + MOUTH_Y) * 0.5 - 0.002, 0.004))
				head.ellipsoid(Transform3D(m.basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(14.0 * side5)), m.origin),
					Vector3(0.026, 0.011, 0.009), stache, SEG_TINY.x + 1, SEG_TINY.y)
		"pena_telinga":
			var pen := hc + Vector3(radii.x + 0.012, EAR_Y + 0.036, 0.004)
			head.capsule(pen + Vector3(0.0, -0.004, FRONT * 0.040), pen + Vector3(0.004, 0.006, -FRONT * 0.044), 0.0075, 0.0065, Palette.PASTEL_PERIWINKLE, 5, 1)
		"tusuk_konde":
			var bun: Vector3 = hc + _bun_offset()
			head.capsule(bun + Vector3(-0.100, 0.024, 0.0), bun + Vector3(0.100, -0.010, 0.0), 0.006, 0.006, Palette.PINE_WOOD, 5, 1)
			head.ellipsoid(Transform3D(Basis(), bun + Vector3(0.104, -0.010, 0.0)), Vector3.ONE * 0.012, Palette.ROSY_CHEEK, SEG_TINY.x, SEG_TINY.y)
		"kerah_kemeja":
			for side6: float in [-1.0, 1.0]:
				var col_xf: Transform3D = _torso_surface(0.244, deg_to_rad(24.0 * side6), chubby, 0.004)
				var flap := col_xf.basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(38.0 * side6))
				body.ellipsoid(Transform3D(flap, col_xf.origin), Vector3(0.030, 0.018, 0.006), Palette.FLOUR_WHITE, SEG_SMALL.x, 2)
		"dasi_kerja", "dasi_merah":
			var tie_col: Color = Palette.APRON_NAVY if id == "dasi_kerja" else Palette.DANGER
			body.ellipsoid(_torso_surface(0.236, 0.0, chubby, 0.004), Vector3(0.013, 0.011, 0.008), tie_col.darkened(0.12), SEG_TINY.x + 1, SEG_TINY.y)
			var y_end: float = 0.150 if id == "dasi_kerja" else 0.182
			var top: Vector3 = _torso_surface(0.228, 0.0, chubby, 0.005).origin
			var bottom: Vector3 = _torso_surface(y_end, 0.0, chubby, 0.005).origin
			var yd: Vector3 = (top - bottom).normalized()
			var xd: Vector3 = yd.cross(Vector3(0.0, 0.0, FRONT)).normalized()
			var zd: Vector3 = xd.cross(yd).normalized()
			body.ellipsoid(Transform3D(Basis(xd, yd, zd), (top + bottom) * 0.5), Vector3(0.016, (top - bottom).length() * 0.5 + 0.006, 0.005),
				tie_col, SEG_SMALL.x, SEG_SMALL.y)
		"dasi_kupu":
			var bt: Transform3D = _torso_surface(0.238, 0.0, chubby, 0.008)
			_bow(body, bt.origin, Palette.APRON_MAROON, 0.85, bt.basis.z)
		"pin_senyum":
			var pin: Transform3D = _torso_surface(0.190, deg_to_rad(20.0), chubby, chest_push)
			body.polygon(pin, _circle(0.016, 10), Palette.BUTTER_YELLOW)
			body.polygon(Transform3D(pin.basis, pin.origin + pin.basis.z * 0.001), _arc_points(0.009, 7), Palette.DARK_CHOCOLATE)
		"pin_bintang":
			body.polygon(_torso_surface(0.190, deg_to_rad(-20.0), chubby, chest_push), _star(0.020, 0.009), Palette.GOLD_STAR)
		"medali":
			var rib_top: Transform3D = _torso_surface(0.212, 0.0, chubby, chest_push)
			var disc: Transform3D = _torso_surface(0.168, 0.0, chubby, chest_push + 0.004)
			body.box(Transform3D(rib_top.basis, (rib_top.origin + disc.origin) * 0.5), Vector3(0.020, 0.046, 0.003), Palette.DANGER)
			body.cylinder(Transform3D(disc.basis * Basis(Vector3.RIGHT, PI * 0.5), disc.origin), 0.007, 0.024, 0.024, Palette.GOLD_STAR, 10)
		"kalung_mutiara":
			var pearls := func(phi: float) -> Color:
				return Palette.FLOUR_WHITE if int(round(phi / (TAU / 16.0))) % 2 == 0 else Palette.VANILLA_CREAM
			var ky: float = 0.246
			body.torus(Transform3D(Basis(), Vector3(0.0, ky, 0.0)), _torso_r(ky, chubby) + 0.004, 0.008, Palette.FLOUR_WHITE, 16, 3,
				0.0, TAU, pearls)
		"syal_merah":
			var sy: float = 0.250
			body.torus(Transform3D(Basis(), Vector3(0.0, sy, 0.0)), _torso_r(sy, chubby) - 0.004, 0.022, Palette.DANGER, 10, 4)
			var tail: Transform3D = _torso_surface(0.190, deg_to_rad(22.0), chubby, 0.012)
			body.ellipsoid(Transform3D(tail.basis * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(8.0)), tail.origin), Vector3(0.026, 0.056, 0.010),
				Palette.DANGER.darkened(0.06), SEG_SMALL.x, SEG_SMALL.y)
		"handuk_pundak":
			var sh: Transform3D = _torso_surface(0.225, deg_to_rad(-90.0), chubby, 0.004)
			body.ellipsoid(Transform3D(sh.basis, sh.origin), Vector3(0.100, 0.052, 0.014), Palette.PASTEL_MINT, SEG_SMALL.x + 1, SEG_SMALL.y)
		"buku_saku":
			var pocket: float = _torso_r(Y_BELT_TOP, chubby) + 0.020
			var ba: float = deg_to_rad(-22.0)
			var bn := Vector3(sin(ba), 0.0, -cos(ba))
			apron.box(Transform3D(_basis_facing(bn) * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(-8.0)), Vector3(bn.x * pocket, 0.048, bn.z * pocket)),
				Vector3(0.044, 0.056, 0.010), Palette.PASTEL_PERIWINKLE)
		"pisau_kayu":
			var kr: float = _torso_r(Y_BELT_TOP, chubby) + 0.020
			var ka: float = deg_to_rad(24.0)
			var kn := Vector3(sin(ka), 0.0, -cos(ka))
			var kp := Vector3(kn.x * kr, 0.040, kn.z * kr)
			apron.capsule(kp + Vector3(0.0, -0.030, 0.0), kp + Vector3(0.004, 0.030, 0.0), 0.0085, 0.0085, Palette.PINE_WOOD, 5, 1)
			apron.ellipsoid(Transform3D(_basis_facing(kn), kp + Vector3(0.006, 0.070, 0.0)), Vector3(0.016, 0.034, 0.004), Palette.PINE_WOOD.lightened(0.18), SEG_SMALL.x, SEG_SMALL.y)
		"jam_vintage":
			var wy: float = -ARM_LENGTH * 0.78
			arm_l.torus(Transform3D(Basis(), Vector3(0.0, wy, 0.0)), ARM_RADIUS * 0.90, 0.008, Palette.DARK_CHOCOLATE, 10, 3)
			arm_l.cylinder(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, wy, FRONT * (ARM_RADIUS * 0.90 + 0.004))), 0.006, 0.016, 0.016, Palette.CHALK_WHITE, 8)
		"gelang_karet":
			arm_r.torus(Transform3D(Basis(), Vector3(0.0, -ARM_LENGTH * 0.80, 0.0)), ARM_RADIUS * 0.88, 0.009, Palette.WARMER_LAMP, 10, 3)
		"ponsel":
			arm_r.box(Transform3D(Basis(Vector3.RIGHT, deg_to_rad(28.0)), Vector3(0.0, -ARM_LENGTH - 0.040, FRONT * 0.034)), Vector3(0.044, 0.070, 0.010), DARK_GLASS)
		"jas_hujan":
			var fat := PackedVector2Array()
			for pt: Vector2 in [Vector2(0.150, -0.074), Vector2(0.192, -0.068), Vector2(0.188, 0.010), Vector2(0.168, 0.120),
					Vector2(0.132, 0.205), Vector2(0.088, 0.250), Vector2(0.054, 0.272)]:
				fat.append(Vector2(pt.x * _belly(pt.y, chubby), pt.y))
			var coat := func(y: float, _p: float) -> Color:
				return Palette.RAINCOAT_YELLOW.lightened(0.14) if y < -0.06 else Palette.RAINCOAT_YELLOW
			body.lathe(Transform3D(), fat, Palette.RAINCOAT_YELLOW, SEG_TORSO + 2, coat)
			if s["hat"] == "none":
				var hood: Vector3 = hair_r + Vector3(0.050, 0.046, 0.050)
				var hshade := func(u: Vector3) -> Color:
					return Palette.RAINCOAT_YELLOW.lightened(0.10 * clampf(u.y, 0.0, 1.0))
				var hfront: float = rad_to_deg(acos((BANG_BOTTOM + 0.030) / hood.y))
				head.ellipsoid(Transform3D(Basis(), hc + Vector3(0.0, 0.006, 0.006)), hood, Palette.RAINCOAT_YELLOW, SEG_HAIR.x, 6,
					hshade, _hairline(hfront, 118.0, 130.0))
		_:
			pass


## Kacamata bulat: dua bingkai + jembatan hidung, di depan mata.
static func _glasses(head: MeshBuilder, radii: Vector3, color: Color) -> void:
	var rim_r: float = EYE_RADII.y + 0.004
	var rims: Array[Transform3D] = []
	for side: float in [-1.0, 1.0]:
		var e: Transform3D = _hc(_head_surface(radii, EYE_X * side, EYE_Y, 0.014))
		head.torus(Transform3D(e.basis * Basis(Vector3.RIGHT, PI * 0.5), e.origin), rim_r, 0.0055, color, 9, 3)
		rims.append(e)
	var bridge: Vector3 = _hc(_head_surface(radii, 0.0, EYE_Y + 0.008, 0.014)).origin
	for rim: Transform3D in rims:
		var inner: Vector3 = rim.origin + (bridge - rim.origin).normalized() * rim_r
		head.capsule(inner, bridge, 0.0045, 0.0045, color, 4, 1)


## Pita kupu-kupu: dua sayap bulat + simpul, menghadap `facing`.
static func _bow(mb: MeshBuilder, center: Vector3, color: Color, size: float, facing: Vector3) -> void:
	var b: Basis = _basis_facing(facing)
	for side: float in [-1.0, 1.0]:
		var wing := b * Basis(Vector3(0.0, 0.0, 1.0), deg_to_rad(22.0 * side))
		mb.ellipsoid(Transform3D(wing, center + b.x * (0.024 * side * size)), Vector3(0.026, 0.018, 0.011) * size, color, SEG_TINY.x + 1, SEG_TINY.y)
	mb.ellipsoid(Transform3D(b, center + b.z * 0.004), Vector3(0.010, 0.012, 0.012) * size, color.darkened(0.12), SEG_TINY.x, SEG_TINY.y)


# ===========================================================================
# BARANG BAWAAN
# ===========================================================================

static func _attach_prop(id: String, s: Dictionary, mb: Dictionary) -> void:
	var body: MeshBuilder = mb["body"]
	var arm_l: MeshBuilder = mb["arm_l"]
	var arm_r: MeshBuilder = mb["arm_r"]
	var extra: MeshBuilder = mb["extra"]
	var cloth: Color = s["cloth"]
	var chubby: float = s["chubby"]
	var back_z: float = -FRONT * (_torso_r(0.14, chubby) + 0.058)
	var front_z: float = FRONT * (_torso_r(0.14, chubby) + 0.090)
	match id:
		"kardus":
			body.box(Transform3D(Basis(), Vector3(0.0, 0.140, front_z)), Vector3(0.200, 0.150, 0.150), Color(0.749, 0.580, 0.380))
			body.box(Transform3D(Basis(), Vector3(0.0, 0.140, front_z)), Vector3(0.204, 0.026, 0.154), Palette.PASTEL_MINT)
		"tas_belanja":
			arm_r.box(Transform3D(Basis(), Vector3(0.020, -ARM_LENGTH - 0.140, 0.0)), Vector3(0.150, 0.160, 0.090), Palette.GINGHAM_A)
			arm_r.box(Transform3D(Basis(), Vector3(0.020, -ARM_LENGTH - 0.140, 0.0)), Vector3(0.154, 0.030, 0.094), Palette.GINGHAM_B)
			arm_r.torus(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.020, -ARM_LENGTH - 0.060, 0.0)), 0.040, 0.007, Palette.CARAMEL, 10, 3,
				deg_to_rad(-90.0), deg_to_rad(90.0))
		"tas_sekolah":
			var bag_c := Vector3(0.0, 0.150, back_z)
			body.box(Transform3D(Basis(), bag_c), Vector3(0.170, 0.170, 0.090), Palette.APRON_NAVY)
			body.ellipsoid(Transform3D(Basis(), bag_c + Vector3(0.0, -0.040, 0.046)), Vector3(0.070, 0.040, 0.020), _shift(Palette.APRON_NAVY, 0.18), SEG_SMALL.x, SEG_SMALL.y)
			for side: float in [-1.0, 1.0]:
				var top: Transform3D = _torso_surface(0.238, deg_to_rad(28.0 * side), chubby, 0.004)
				var low: Transform3D = _torso_surface(0.120, deg_to_rad(34.0 * side), chubby, 0.004)
				body.capsule(top.origin, low.origin, 0.010, 0.010, _shift(Palette.APRON_NAVY, 0.25), 5, 1)
		"ransel_termal":
			# Warna merek RotiFood tetap hijau, juga saat kurir berjas hujan.
			var brand: Color = Palette.OJOL_GREEN
			var box_c := Vector3(0.0, 0.160, back_z + 0.012)
			body.box(Transform3D(Basis(), box_c), Vector3(0.205, 0.215, 0.135), _shift(brand, -0.12))
			body.box(Transform3D(Basis(), box_c + Vector3(0.0, 0.020, 0.068)), Vector3(0.100, 0.070, 0.006), Palette.FLOUR_WHITE)
			for side2: float in [-1.0, 1.0]:
				var top2: Transform3D = _torso_surface(0.240, deg_to_rad(30.0 * side2), chubby, 0.004)
				var low2: Transform3D = _torso_surface(0.110, deg_to_rad(36.0 * side2), chubby, 0.004)
				body.capsule(top2.origin, low2.origin, 0.011, 0.011, _shift(brand, -0.35), 5, 1)
		"mangkuk_adonan":
			body.ellipsoid(Transform3D(Basis(), Vector3(0.0, 0.105, front_z)), Vector3(0.092, 0.057, 0.092), Color(0.808, 0.831, 0.851), SEG_SMALL.x + 2, SEG_SMALL.y)
			body.ellipsoid(Transform3D(Basis(), Vector3(0.0, 0.150, front_z)), Vector3(0.062, 0.045, 0.062), Palette.RAW_DOUGH, SEG_SMALL.x + 2, SEG_SMALL.y)
		"loyang_roti":
			body.box(Transform3D(Basis(), Vector3(0.0, 0.120, front_z)), Vector3(0.230, 0.022, 0.150), EquipmentFactory.METAL_STEEL)
			for k in 3:
				body.ellipsoid(Transform3D(Basis(), Vector3(-0.072 + float(k) * 0.072, 0.150, front_z)), Vector3(0.040, 0.028, 0.040), Palette.GOLDEN_CRUST, SEG_SMALL.x, SEG_SMALL.y)
		"kantong_kertas":
			body.box(Transform3D(Basis(), Vector3(0.0, 0.130, front_z)), Vector3(0.150, 0.170, 0.105), Palette.CARAMEL.lightened(0.28))
			body.box(Transform3D(Basis(), Vector3(0.0, 0.222, front_z)), Vector3(0.162, 0.034, 0.115), Palette.CARAMEL.lightened(0.42))
			body.box(Transform3D(Basis(), Vector3(0.0, 0.150, front_z)), Vector3(0.158, 0.026, 0.113), Palette.ROSY_CHEEK)
		"koper":
			arm_r.box(Transform3D(Basis(), Vector3(0.0, -ARM_LENGTH - 0.118, 0.0)), Vector3(0.170, 0.125, 0.056), Palette.CARAMEL)
			arm_r.box(Transform3D(Basis(), Vector3(0.0, -ARM_LENGTH - 0.118, 0.0)), Vector3(0.174, 0.016, 0.060), Palette.CARAMEL.darkened(0.25))
			arm_r.torus(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, -ARM_LENGTH - 0.056, 0.0)), 0.024, 0.006, Palette.DARK_CHOCOLATE, 8, 3,
				deg_to_rad(-90.0), deg_to_rad(90.0))
		"amplop":
			var env := Transform3D(Basis(Vector3.RIGHT, deg_to_rad(62.0)), Vector3(0.0, -ARM_LENGTH - 0.046, FRONT * 0.050))
			arm_l.box(env, Vector3(0.120, 0.084, 0.008), Palette.PARCHMENT)
			arm_l.box(Transform3D(env.basis, env.origin + env.basis * Vector3(0.032, 0.012, -0.006)), Vector3(0.030, 0.030, 0.004), Palette.DANGER)
		"tas_tangan":
			arm_l.box(Transform3D(Basis(), Vector3(0.0, -ARM_LENGTH - 0.096, 0.0)), Vector3(0.100, 0.076, 0.046), Palette.APRON_MAROON)
			arm_l.torus(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0.0, -ARM_LENGTH - 0.056, 0.0)), 0.030, 0.005, Palette.GOLD_STAR, 8, 3,
				deg_to_rad(-90.0), deg_to_rad(90.0))
		"kamera":
			# Dipegang tangan kanan yang terangkat; lensa searah lengan (ke depan).
			var cam := Vector3(0.0, -ARM_LENGTH - 0.064, 0.0)
			arm_r.box(Transform3D(Basis(), cam), Vector3(0.090, 0.050, 0.062), DARK_GLASS)
			arm_r.cylinder(Transform3D(Basis(), cam + Vector3(0.0, -0.036, 0.0)), 0.026, 0.023, 0.025, Palette.CHALKBOARD, 10)
			arm_r.box(Transform3D(Basis(), cam + Vector3(-0.026, 0.0, -0.036)), Vector3(0.020, 0.014, 0.012), Palette.DANGER)
		"tanda_tanya":
			# Tanda tanya empuk melayang (Si Galau): busur + batang + titik.
			var q := Vector3(0.155, 1.010, 0.0)
			extra.torus(Transform3D(Basis(Vector3.RIGHT, PI * 0.5), q + Vector3(0.0, 0.080, 0.0)), 0.036, 0.013, Palette.WARMER_LAMP, 10, 4,
				deg_to_rad(-120.0), deg_to_rad(150.0))
			extra.capsule(q + Vector3(0.0, 0.044, 0.0), q + Vector3(0.0, 0.018, 0.0), 0.013, 0.013, Palette.WARMER_LAMP, 6, 1)
			extra.ellipsoid(Transform3D(Basis(), q + Vector3(0.0, -0.020, 0.0)), Vector3.ONE * 0.016, Palette.WARMER_LAMP, SEG_SMALL.x, SEG_SMALL.y)
		_:
			pass


# ===========================================================================
# PEMBANTU GEOMETRI
# ===========================================================================

static func _pivot(parent: Node3D, pivot_name: String, pos: Vector3) -> Node3D:
	var n := Node3D.new()
	n.name = pivot_name
	n.position = pos
	parent.add_child(n)
	return n


static func _circle(r: float, segs: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in segs:
		var a: float = TAU * float(k) / float(segs)
		p.append(Vector2(cos(a), sin(a)) * r)
	return p


## Busur senyum kecil (setengah lingkaran bawah) untuk lencana.
static func _arc_points(r: float, segs: int) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in segs:
		var a: float = PI + PI * float(k) / float(segs - 1)
		p.append(Vector2(cos(a) * r, sin(a) * r * 0.8))
	return p


static func _star(outer: float, inner: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in 10:
		var a: float = PI * 0.5 + TAU * float(k) / 10.0
		p.append(Vector2(cos(a), sin(a)) * (outer if k % 2 == 0 else inner))
	return p


## Basis dengan sumbu Z lokal = `normal` dan Y lokal mengarah ke atas.
static func _basis_facing(normal: Vector3) -> Basis:
	var z_axis: Vector3 = normal.normalized()
	var up: Vector3 = Vector3.UP
	if absf(z_axis.dot(up)) > 0.95:
		up = Vector3.FORWARD
	var x_axis: Vector3 = up.cross(z_axis).normalized()
	var y_axis: Vector3 = z_axis.cross(x_axis).normalized()
	return Basis(x_axis, y_axis, z_axis)


# ===========================================================================
# DATA & UTILITAS
# ===========================================================================

## Lengkapi spec dengan seluruh nilai bawaan sehingga build() tidak pernah gagal.
static func _normalize(spec: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	out["kind"] = str(spec.get("kind", "customer"))
	out["role"] = str(spec.get("role", ""))
	out["tier"] = clampi(int(spec.get("tier", 1)), 1, 5)
	out["skin"] = _as_color(spec.get("skin"), SKIN_MID)
	out["hair"] = _as_color(spec.get("hair"), HAIR_BLACK)
	var style: String = str(spec.get("hair_style", "pendek"))
	out["hair_style"] = style if HAIR_STYLES.has(style) else "pendek"
	out["hat"] = str(spec.get("hat", "none"))
	out["cloth"] = _as_color(spec.get("cloth"), Palette.FLOUR_WHITE)
	out["pants"] = _as_color(spec.get("pants"), PANTS_COFFEE)
	out["shoes"] = _as_color(spec.get("shoes"), SHOE_BROWN)
	var legwear: String = str(spec.get("legwear", "pants"))
	out["legwear"] = legwear if legwear in ["pants", "skin", "shorts"] else "pants"
	var sleeve: String = str(spec.get("sleeve", "short"))
	out["sleeve"] = sleeve if sleeve in ["short", "long"] else "short"
	var skirt: Variant = spec.get("skirt")
	out["skirt"] = skirt if skirt is Color else null
	out["lashes"] = bool(spec.get("lashes", false))
	out["dots"] = bool(spec.get("dots", false))
	out["chubby"] = clampf(float(spec.get("chubby", 0.0)), 0.0, 1.0)
	out["rainy"] = bool(spec.get("rainy", false))
	out["mood"] = str(spec.get("mood", "netral"))
	out["height"] = clampf(float(spec.get("height", 1.0)), 0.5, 1.6)
	out["lean"] = clampf(float(spec.get("lean", 0.0)), -25.0, 25.0)
	out["head_tilt"] = clampf(float(spec.get("head_tilt", 0.0)), -30.0, 30.0)
	out["accessory"] = _as_names(spec.get("accessory"))
	out["prop"] = _as_names(spec.get("prop"))
	out["archetype"] = str(spec.get("archetype", ""))
	var apron: Variant = spec.get("apron")
	out["apron"] = apron if apron is Color else null
	return out


## Petunjuk visual (bukan data gameplay) untuk bulu mata lentik staf.
static func _soft_features(hair_style: String, hat: String, accessories: PackedStringArray) -> bool:
	if hair_style in LASH_STYLES or hat in LASH_HATS:
		return true
	for a: String in accessories:
		if a in LASH_ACCESSORIES:
			return true
	return false


static func _as_color(value: Variant, fallback: Color) -> Color:
	if value is Color:
		var c: Color = value
		return c
	if value is String and Color.html_is_valid(str(value)):
		return Color.html(str(value))
	return fallback


static func _as_names(value: Variant) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if value is PackedStringArray:
		var packed: PackedStringArray = value
		return packed.duplicate()
	if value is Array:
		for item: Variant in value:
			out.append(str(item))
		return out
	if value is String:
		out.append(str(value))
	return out


static func _pack(names: Array) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	for n: Variant in names:
		out.append(str(n))
	return out


## Generator acak lokal yang deterministik per pelanggan + seed (bukan stream
## gameplay), supaya pelanggan dengan seed sama selalu tampil persis sama.
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
	var list: Array[Color] = [HAIR_BLACK, HAIR_BROWN, HAIR_LIGHT_BROWN, HAIR_BLONDE, HAIR_PASTEL, HAIR_GREY]
	return list


## Warna baju pelanggan umum: pastel manis GDD 4.1.
static func _cloth_tones() -> Array[Color]:
	var list: Array[Color] = [Palette.PASTEL_STRAWBERRY, Palette.PASTEL_PERIWINKLE, Palette.PASTEL_MINT,
		Palette.BUTTER_YELLOW, Palette.VANILLA_CREAM, Palette.CUSTARD]
	return list


## Celana hangat: denim pastel, khaki, cokelat susu, abu lembut, navy.
static func _pants_tones() -> Array[Color]:
	var list: Array[Color] = [
		Color(0.451, 0.537, 0.702),  # denim pastel #7389B3
		Color(0.769, 0.651, 0.478),  # khaki #C4A67A
		PANTS_COFFEE,
		Color(0.463, 0.443, 0.494),  # abu lembut #76717E
		Palette.APRON_NAVY,
	]
	return list


static func _shoe_tones() -> Array[Color]:
	var list: Array[Color] = [SHOE_BROWN, HAIR_BLACK, Palette.FLOUR_WHITE, Palette.APRON_MAROON, Palette.CARAMEL]
	return list


static func _office_tones() -> Array[Color]:
	var list: Array[Color] = [Palette.FLOUR_WHITE, Palette.PASTEL_PERIWINKLE, Color(0.784, 0.851, 0.902)]
	return list


static func _floral_tones() -> Array[Color]:
	var list: Array[Color] = [Palette.GINGHAM_A, Palette.MOOD_BG_ROUGH, Palette.MOOD_BG_BAILOUT, Palette.CUSTARD]
	return list


static func _elegant_tones() -> Array[Color]:
	var list: Array[Color] = [Palette.APRON_NAVY, Palette.APRON_MAROON, Palette.APRON_GOLD, Color(0.286, 0.243, 0.325)]
	return list


static func _vivid_tones() -> Array[Color]:
	var list: Array[Color] = [Palette.WARMER_LAMP, Palette.SUCCESS, Palette.DANGER, Palette.GOLD_STAR]
	return list


static func _hair_styles() -> PackedStringArray:
	return _pack(["pendek", "belah_samping", "bob", "sanggul", "ikal", "cepak", "kuncir_ganda", "panjang_kepang", "spike"])


## Geser kecerahan warna: `amount` positif menerangkan, negatif menggelapkan.
static func _shift(color: Color, amount: float) -> Color:
	if amount >= 0.0:
		return color.lerp(Color(1.0, 1.0, 1.0), clampf(amount, 0.0, 1.0))
	return color.lerp(Color(0.0, 0.0, 0.0), clampf(-amount, 0.0, 1.0))


## Simpan transform dasar sebagai metadata agar animasi & ekspresi bisa kembali
## ke pose awal.
static func _remember(node: Node3D) -> void:
	node.set_meta("base_position", node.position)
	node.set_meta("base_rotation", node.rotation)
	node.set_meta("base_scale", node.scale)
	node.set_meta("base_basis", node.basis)


## Terapkan pengali skala + geseran posisi terhadap transform dasar bagian wajah.
static func _apply_part(node: Node3D, scale_mul: Vector3, offset: Vector3) -> void:
	if node == null:
		return
	var base_scale: Vector3 = node.get_meta("base_scale", Vector3.ONE)
	var base_pos: Vector3 = node.get_meta("base_position", node.position)
	node.scale = Vector3(base_scale.x * scale_mul.x, base_scale.y * scale_mul.y, base_scale.z * scale_mul.z)
	node.position = base_pos + offset


static func _child3d(parent: Node3D, child_name: String) -> Node3D:
	if parent == null:
		return null
	var node: Node = parent.get_node_or_null(NodePath(child_name))
	if node is Node3D:
		return node
	return null


## Jadikan root owner seluruh keturunan, supaya find_child() menemukan Head, Hat, dsb.
static func _assign_owner(root: Node, node: Node) -> void:
	for child: Node in node.get_children():
		child.owner = root
		_assign_owner(root, child)
