class_name ProceduralAnimationSystem
extends RefCounted

## Sistem animasi prosedural tanpa rig skeleton (GDD 4.2, GDD 7, ARCHITECTURE 8).
##
## Dua keluarga fungsi:
##
## 1. **Per-frame & stateless** — `walk()`, `idle_bob()`, `mixer_spin()`.
##    Dipanggil setiap `_process(delta)` dengan waktu akumulatif `t`. Seluruh pose
##    dihitung ulang dari `t` memakai gelombang sinus (GDD 4.2: `sin(time * speed)`
##    untuk ayunan kaki/tangan serta anggukan kepala ceria). Tidak ada state yang
##    disimpan di dalam kelas ini; satu-satunya hal yang di-cache adalah **pose
##    istirahat** tiap node anak, disimpan sebagai metadata pada node itu sendiri
##    saat pertama kali disentuh, supaya offset animasi selalu relatif terhadap
##    posisi asli hasil CharacterFactory.
##
## 2. **Berbasis Tween** — `squash_pop()`, `press_bounce()`, `happy_jump()`,
##    `sad_shake()`, `oven_door()`. Mengembalikan `Tween` supaya pemanggil bisa
##    `await tw.finished`. Semua memakai interpolasi squash & stretch agar terasa
##    kenyal seperti memencet adonan roti hangat (GDD 4.1 "Cute").
##
## Nama node anak yang dicari mengikuti kontrak CharacterFactory (ARCHITECTURE 8):
## `Head`, `Body`, `ArmL`, `ArmR`, `LegL`, `LegR`, `Face`, `Hat`, `Apron`.
## Semua pencarian memakai `get_node_or_null` dan diam-diam dilewati bila node
## tidak ada, sehingga aktor yang dirakit sebagian tidak pernah membuat game crash.

# ---------------------------------------------------------------------------
# Kunci metadata (dipasang pada node target, bukan pada kelas ini)
# ---------------------------------------------------------------------------

## Posisi lokal istirahat sebuah bagian tubuh.
const META_REST_POS: String = "rlt_rest_pos"
## Rotasi lokal istirahat sebuah bagian tubuh.
const META_REST_ROT: String = "rlt_rest_rot"
## Skala dasar sebuah node (agar pop berulang tidak menumpuk/mengecil terus).
const META_BASE_SCALE: String = "rlt_base_scale"
## Tween yang sedang berjalan untuk kategori tertentu, supaya bisa dibatalkan.
const META_TWEEN_POP: String = "rlt_tween_pop"
const META_TWEEN_UI: String = "rlt_tween_ui"
const META_TWEEN_ACTOR: String = "rlt_tween_actor"
const META_TWEEN_DOOR: String = "rlt_tween_door"

# ---------------------------------------------------------------------------
# GDD 4.2 — parameter jalan (gelombang sinus)
# ---------------------------------------------------------------------------

## Frekuensi dasar langkah dalam radian/detik pada speed = 1.0.
const WALK_FREQ: float = 5.6
## Amplitudo ayunan lengan (radian).
const WALK_ARM_SWING: float = 0.52
## Amplitudo ayunan kaki (radian).
const WALK_LEG_SWING: float = 0.68
## Tinggi pantulan badan tiap langkah (meter).
const WALK_BOB: float = 0.030
## Amplitudo anggukan kepala ceria (radian).
const WALK_HEAD_NOD: float = 0.10
## Kemiringan kepala kiri-kanan mengikuti langkah (radian).
const WALK_HEAD_TILT: float = 0.055
## Goyangan badan kiri-kanan (radian).
const WALK_SWAY: float = 0.045
## Ayunan celemek yang menyusul gerak badan (radian).
const WALK_APRON_SWAY: float = 0.038
## Pengali gerak susulan topi koki terhadap kemiringan kepala.
const HAT_FOLLOW_THROUGH: float = 1.35
## Batas bawah pengali amplitudo agar aktor sangat lambat tetap terlihat hidup.
const WALK_AMP_MIN: float = 0.25
## Batas atas pengali amplitudo agar aktor cepat tidak jadi kincir angin.
const WALK_AMP_MAX: float = 1.6

# ---------------------------------------------------------------------------
# Parameter diam (napas)
# ---------------------------------------------------------------------------

## Frekuensi napas dalam radian/detik (~13 tarikan napas per menit).
const IDLE_FREQ: float = 1.35
## Tinggi naik-turun badan saat bernapas (meter).
const IDLE_BOB: float = 0.012
## Ayunan lengan santai saat diam (radian).
const IDLE_ARM: float = 0.05
## Gelengan kepala pelan saat diam (radian).
const IDLE_HEAD_TILT: float = 0.035

# ---------------------------------------------------------------------------
# GDD 4.1 / 7 — squash & stretch
# ---------------------------------------------------------------------------

## Seberapa kuat sumbu lateral memampat saat sumbu tegak meregang
## (kesan volume adonan yang tetap, bukan sekadar diperbesar).
const SQUASH_VOLUME: float = 0.6

## GDD 7: "mengecil lembut ke skala 0.92x lalu membal ke 1.05x sebelum kembali normal".
const PRESS_DOWN: float = 0.92
const PRESS_UP: float = 1.05
const PRESS_T_DOWN: float = 0.07
const PRESS_T_UP: float = 0.09
const PRESS_T_BACK: float = 0.11

## Lompat gembira (GDD 12.3 "melompat gembira").
const JUMP_HEIGHT: float = 0.34
const JUMP_CROUCH: float = 0.86
const JUMP_STRETCH: float = 1.14
const JUMP_LAND: float = 0.90

## Gelengan kecewa (GDD 12.3 "menggeleng kecewa", GDD 3.6.C driver kecewa).
const SAD_TURN: float = 0.26
const SAD_SLUMP: float = 0.045

## Sudut pintu oven terbuka penuh (radian, berputar pada sumbu X / engsel bawah).
const OVEN_DOOR_ANGLE: float = 1.62

## Sudut pintu gudang terbuka (radian, berputar pada sumbu Y / engsel tegak).
## Lebih kecil dari pintu oven: lemari yang menganga 90 derajat menutupi
## separuh dapur pada pandangan isometrik.
const STORAGE_DOOR_ANGLE: float = 1.15
## Berapa lama pintu gudang tetap terbuka sebelum menutup sendiri (detik).
const STORAGE_DOOR_HOLD: float = 0.55

## Kecepatan putar pengocok mixer (radian/detik).
const MIXER_SPIN_SPEED: float = 11.0
## Kecepatan orbit planet pengocok mengelilingi mangkuk (radian/detik).
const MIXER_ORBIT_SPEED: float = 3.4
## Jari-jari orbit planet pengocok (meter).
const MIXER_ORBIT_RADIUS: float = 0.035

# ---------------------------------------------------------------------------
# Teks mengambang "+250 KR"
# ---------------------------------------------------------------------------

const FLOAT_TEXT_WIDTH: float = 220.0
const FLOAT_TEXT_HEIGHT: float = 42.0
const FLOAT_TEXT_RISE: float = 72.0
const FLOAT_TEXT_LIFE: float = 1.05
const FLOAT_TEXT_FONT_SIZE: int = 24
const FLOAT_TEXT_OUTLINE: int = 6
const FLOAT_TEXT_Z: int = 120


# ---------------------------------------------------------------------------
# Animasi per-frame (stateless)
# ---------------------------------------------------------------------------

## Ayunan langkah berbasis gelombang sinus (GDD 4.2).
## `t` = waktu akumulatif detik, `speed` = pengali kecepatan jalan aktor.
## Dipanggil tiap frame; seluruh pose dihitung ulang dari `t` sehingga aman
## dipanggil dari mana pun tanpa menyimpan state.
static func walk(actor: Node3D, t: float, speed: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var rate: float = maxf(speed, 0.15)
	var phase: float = t * WALK_FREQ * rate
	var swing: float = sin(phase)
	var bounce: float = absf(sin(phase))
	var amp: float = clampf(rate, WALK_AMP_MIN, WALK_AMP_MAX)

	# Kaki berlawanan fase satu sama lain.
	var leg_l: Node3D = _part(actor, "LegL")
	if leg_l != null:
		leg_l.rotation.x = _rest_rot(leg_l).x + swing * WALK_LEG_SWING * amp
	var leg_r: Node3D = _part(actor, "LegR")
	if leg_r != null:
		leg_r.rotation.x = _rest_rot(leg_r).x - swing * WALK_LEG_SWING * amp

	# Lengan berlawanan fase terhadap kaki di sisi yang sama.
	var arm_l: Node3D = _part(actor, "ArmL")
	if arm_l != null:
		arm_l.rotation.x = _rest_rot(arm_l).x - swing * WALK_ARM_SWING * amp
	var arm_r: Node3D = _part(actor, "ArmR")
	if arm_r != null:
		arm_r.rotation.x = _rest_rot(arm_r).x + swing * WALK_ARM_SWING * amp

	# Badan memantul dua kali per siklus langkah dan sedikit bergoyang.
	var body: Node3D = _part(actor, "Body")
	if body != null:
		var body_rest: Vector3 = _rest_pos(body)
		body.position.y = body_rest.y + bounce * WALK_BOB * amp
		body.rotation.z = _rest_rot(body).z + swing * WALK_SWAY * amp

	# Anggukan kepala ceria: dua kali lebih cepat dari ayunan kaki.
	var head_dy: float = bounce * WALK_BOB * 1.25 * amp
	var head_roll: float = -swing * WALK_HEAD_TILT * amp
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var head_rest: Vector3 = _rest_pos(head)
		var head_rot: Vector3 = _rest_rot(head)
		head.position.y = head_rest.y + head_dy
		head.rotation.x = head_rot.x + sin(phase * 2.0) * WALK_HEAD_NOD * amp
		head.rotation.z = head_rot.z + head_roll
	_follow_head(actor, head_dy, head_roll * HAT_FOLLOW_THROUGH)

	# Celemek ikut berayun menyusul badan (GDD 4.1 -- kesan kain empuk).
	var apron: Node3D = _part(actor, "Apron")
	if apron != null:
		apron.rotation.z = _rest_rot(apron).z + swing * WALK_APRON_SWAY * amp


## Napas tenang saat aktor berdiri diam. Juga mengembalikan tangan & kaki ke pose
## istirahat, sehingga peralihan dari `walk()` ke `idle_bob()` tidak meninggalkan
## anggota badan yang tertinggal mengambang. Stateless, dipanggil tiap frame.
static func idle_bob(actor: Node3D, t: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return

	var phase: float = t * IDLE_FREQ
	var breathe: float = sin(phase)

	var body: Node3D = _part(actor, "Body")
	if body != null:
		var body_rest: Vector3 = _rest_pos(body)
		body.position.y = body_rest.y + breathe * IDLE_BOB
		body.rotation.z = _rest_rot(body).z

	var head_dy: float = sin(phase + 0.6) * IDLE_BOB * 1.4
	var head_roll: float = sin(phase * 0.5) * IDLE_HEAD_TILT
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var head_rest: Vector3 = _rest_pos(head)
		var head_rot: Vector3 = _rest_rot(head)
		head.position.y = head_rest.y + head_dy
		head.rotation.x = head_rot.x + breathe * IDLE_HEAD_TILT * 0.5
		head.rotation.z = head_rot.z + head_roll
	_follow_head(actor, head_dy, head_roll * HAT_FOLLOW_THROUGH)

	var apron: Node3D = _part(actor, "Apron")
	if apron != null:
		apron.rotation.z = _rest_rot(apron).z + breathe * WALK_APRON_SWAY * 0.4

	var arm_l: Node3D = _part(actor, "ArmL")
	if arm_l != null:
		arm_l.rotation.x = _rest_rot(arm_l).x + breathe * IDLE_ARM
	var arm_r: Node3D = _part(actor, "ArmR")
	if arm_r != null:
		arm_r.rotation.x = _rest_rot(arm_r).x - breathe * IDLE_ARM

	var leg_l: Node3D = _part(actor, "LegL")
	if leg_l != null:
		leg_l.rotation.x = _rest_rot(leg_l).x
	var leg_r: Node3D = _part(actor, "LegR")
	if leg_r != null:
		leg_r.rotation.x = _rest_rot(leg_r).x


## Pengocok mixer berputar sekaligus mengorbit mangkuk ala planetary mixer.
## Mencari anak bernama `Whisk` / `Beater` / `Agitator`; bila tidak ada, seluruh
## node diputar pada sumbu Y saja. Stateless, dipanggil tiap frame.
static func mixer_spin(node: Node3D, t: float) -> void:
	if node == null or not is_instance_valid(node):
		return

	var whisk: Node3D = node.get_node_or_null(NodePath("Whisk")) as Node3D
	if whisk == null:
		whisk = node.get_node_or_null(NodePath("Beater")) as Node3D
	if whisk == null:
		whisk = node.get_node_or_null(NodePath("Agitator")) as Node3D

	if whisk == null:
		# Tidak ada pengocok terpisah: putar node apa adanya, jangan digeser
		# supaya badan mixer tidak ikut bergetar dari tempatnya.
		node.rotation.y = _rest_rot(node).y + wrapf(t * MIXER_SPIN_SPEED, 0.0, TAU)
		return

	whisk.rotation.y = _rest_rot(whisk).y + wrapf(t * MIXER_SPIN_SPEED, 0.0, TAU)
	var orbit: float = t * MIXER_ORBIT_SPEED
	var rest: Vector3 = _rest_pos(whisk)
	whisk.position = Vector3(
		rest.x + cos(orbit) * MIXER_ORBIT_RADIUS,
		rest.y,
		rest.z + sin(orbit) * MIXER_ORBIT_RADIUS
	)


# ---------------------------------------------------------------------------
# Animasi berbasis Tween
# ---------------------------------------------------------------------------

## Pop kenyal serba guna: membesar ke `scale_to` lalu membal kembali ke skala
## dasar. Menerima Node3D, Control, maupun Node2D. Sumbu tegak meregang sementara
## sumbu lateral sedikit memampat agar terasa seperti adonan (squash & stretch).
static func squash_pop(node: Node, scale_to := 1.05, dur := 0.18) -> Tween:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null

	if node is Control:
		_center_pivot(node as Control)

	var base: Vector3 = _base_scale(node)
	var tw: Tween = _fresh_tween(node, META_TWEEN_POP)
	if tw == null:
		return null

	var setter: Callable = func(k: float) -> void:
		ProceduralAnimationSystem._apply_pop(node, base, k)

	var up: float = maxf(dur, 0.02) * 0.42
	var down: float = maxf(dur, 0.02) * 0.58
	tw.tween_method(setter, 1.0, scale_to, up).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(setter, scale_to, 1.0, down).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Umpan balik sentuh tombol UI (GDD 7): 0.92x -> 1.05x -> 1.0x.
## `pivot_offset` dipusatkan lebih dulu agar tombol mengempis dari tengah,
## bukan dari sudut kiri atas.
static func press_bounce(node: Control) -> Tween:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null

	_center_pivot(node)

	var base3: Vector3 = _base_scale(node)
	var base: Vector2 = Vector2(base3.x, base3.y)
	var tw: Tween = _fresh_tween(node, META_TWEEN_UI)
	if tw == null:
		return null

	tw.tween_property(node, "scale", base * PRESS_DOWN, PRESS_T_DOWN) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base * PRESS_UP, PRESS_T_UP) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(node, "scale", base, PRESS_T_BACK) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Lompatan gembira pelanggan/staf: jongkok sebentar (antisipasi), melenting ke
## atas sambil meregang, mendarat dengan memampat, lalu kembali normal.
static func happy_jump(actor: Node3D) -> Tween:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return null

	var base_y: float = actor.position.y
	var base: Vector3 = _base_scale(actor)
	var tw: Tween = _fresh_tween(actor, META_TWEEN_ACTOR)
	if tw == null:
		return null

	var setter: Callable = func(k: float) -> void:
		ProceduralAnimationSystem._apply_pop(actor, base, k)

	# 1. Antisipasi: jongkok kecil.
	tw.tween_method(setter, 1.0, JUMP_CROUCH, 0.09) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 2. Melenting naik sambil meregang.
	tw.tween_property(actor, "position:y", base_y + JUMP_HEIGHT, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(setter, JUMP_CROUCH, JUMP_STRETCH, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 3. Jatuh kembali.
	tw.tween_property(actor, "position:y", base_y, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.parallel().tween_method(setter, JUMP_STRETCH, 1.0, 0.18) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# 4. Mendarat: memampat lalu membal ke normal.
	tw.tween_method(setter, 1.0, JUMP_LAND, 0.07) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(setter, JUMP_LAND, 1.0, 0.16) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	return tw


## Gelengan kepala kecewa dengan bahu sedikit merosot (GDD 3.6.C, GDD 12.3).
## Kepala dipakai sebagai poros bila ada; kalau tidak, seluruh aktor yang menggeleng.
static func sad_shake(actor: Node3D) -> Tween:
	if actor == null or not is_instance_valid(actor) or not actor.is_inside_tree():
		return null

	var head: Node3D = _part(actor, "Head")
	var pivot: Node3D = head if head != null else actor
	# Diambil saat ini juga, BUKAN dari cache pose istirahat: bila porosnya adalah
	# akar aktor, rotasi Y-nya adalah arah hadap yang memang berubah-ubah.
	var rest_y: float = pivot.rotation.y
	var base_y: float = actor.position.y

	var tw: Tween = _fresh_tween(actor, META_TWEEN_ACTOR)
	if tw == null:
		return null

	# Bahu merosot.
	tw.tween_property(actor, "position:y", base_y - SAD_SLUMP, 0.14) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# Gelengan kiri-kanan yang meredam.
	tw.tween_property(pivot, "rotation:y", rest_y - SAD_TURN, 0.14) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:y", rest_y + SAD_TURN, 0.22) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:y", rest_y - SAD_TURN * 0.5, 0.20) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(pivot, "rotation:y", rest_y, 0.16) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	# Bangkit lagi.
	tw.tween_property(actor, "position:y", base_y, 0.20) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	return tw


## Pintu oven berayun pada engsel bawah. `node` boleh berupa daun pintu langsung
## atau badan oven yang punya anak bernama `Door` / `OvenDoor`.
static func oven_door(node: Node3D, open: bool) -> Tween:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null

	var door: Node3D = node.get_node_or_null(NodePath("Door")) as Node3D
	if door == null:
		door = node.get_node_or_null(NodePath("OvenDoor")) as Node3D
	if door == null:
		door = node

	var rest_x: float = _rest_rot(door).x
	var tw: Tween = _fresh_tween(door, META_TWEEN_DOOR)
	if tw == null:
		return null

	if open:
		# Membuka: berayun turun dan sedikit melewati batas, lalu tenang.
		tw.tween_property(door, "rotation:x", rest_x - OVEN_DOOR_ANGLE, 0.34) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	else:
		# Menutup: tarik sedikit dulu sebagai antisipasi, lalu tutup dan memantul.
		tw.tween_property(door, "rotation:x", rest_x - OVEN_DOOR_ANGLE * 1.06, 0.08) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(door, "rotation:x", rest_x, 0.22) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.tween_property(door, "rotation:x", rest_x - 0.07, 0.07) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(door, "rotation:x", rest_x, 0.10) \
			.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw


## Pintu gudang (kulkas) berayun pada engsel TEGAK lalu menutup sendiri.
##
## Berbeda dari oven yang pintunya dibuka-tutup mengikuti tahap panggang, gudang
## dibuka hanya sebagai jawaban atas satu ketukan pemain -- jadi satu panggilan
## menjalankan seluruh gerakan buka-tahan-tutup, dan pemanggil tidak perlu
## mengingat keadaan pintu sama sekali.
##
## Gudang punya LEBIH DARI SATU daun: kulkas dan lemari bahan berdiri
## bersebelahan, masing-masing berpintu sendiri di sisi depan. Semuanya dibuka
## sekaligus, karena yang diketuk pemain adalah satu perabot, bukan satu pintu.
## Daunnya dikenali dari nama berawalan "Pintu" ("Pintu", "Pintu2",
## "PintuLemari").
##
## `node` boleh juga berupa daun pintu langsung; yang dikembalikan selalu tween
## daun pertama.
static func storage_door(node: Node3D) -> Tween:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null

	var daun: Array[Node3D] = []
	for c in node.get_children():
		var d := c as Node3D
		if d != null and String(d.name).begins_with("Pintu"):
			daun.append(d)
	if daun.is_empty():
		daun.append(node)

	var pertama: Tween = null
	for d in daun:
		var tw_d: Tween = _ayun_pintu_gudang(d)
		if pertama == null:
			pertama = tw_d
	return pertama


## Membuka atau menutup pintu gudang dan MEMBIARKANNYA begitu.
##
## Dipakai saat daftar resep terbuka: pintu harus tetap menganga selama pemain
## membaca, lalu menutup persis ketika daftarnya ditutup. Berbeda dari
## storage_door() yang sekali jalan buka-tahan-tutup untuk sekadar umpan balik.
static func storage_door_hold(node: Node3D, open: bool) -> Tween:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null

	var pertama: Tween = null
	for c in node.get_children():
		var d := c as Node3D
		if d == null or not String(d.name).begins_with("Pintu"):
			continue
		var rest_y: float = _rest_rot(d).y
		var tw: Tween = _fresh_tween(d, META_TWEEN_DOOR)
		if tw == null:
			continue
		var arah: float = float(d.get_meta("open_sign", -1.0))
		var tujuan: float = rest_y + (arah * STORAGE_DOOR_ANGLE if open else 0.0)
		tw.tween_property(d, "rotation:y", tujuan, 0.26) \
			.set_trans(Tween.TRANS_BACK if open else Tween.TRANS_QUAD) \
			.set_ease(Tween.EASE_OUT if open else Tween.EASE_IN)
		if pertama == null:
			pertama = tw
	return pertama


## Satu daun pintu gudang: berayun keluar, tertahan sejenak, lalu menutup.
##
## Tanda arah dibawa mesh-nya sendiri (EquipmentFactory._storage_door), jadi
## daun yang engselnya di sisi berlawanan tetap berayun ke depan tanpa perlu
## satu pun cabang khusus di lapisan animasi.
static func _ayun_pintu_gudang(door: Node3D) -> Tween:
	var rest_y: float = _rest_rot(door).y
	var tw: Tween = _fresh_tween(door, META_TWEEN_DOOR)
	if tw == null:
		return null

	var arah: float = float(door.get_meta("open_sign", -1.0))
	tw.tween_property(door, "rotation:y", rest_y + arah * STORAGE_DOOR_ANGLE, 0.26) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(STORAGE_DOOR_HOLD)
	tw.tween_property(door, "rotation:y", rest_y, 0.30) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	return tw


# ---------------------------------------------------------------------------
# Teks mengambang
# ---------------------------------------------------------------------------

## Teks umpan balik yang melayang naik lalu memudar, misalnya "+250 KR".
## `pos` memakai koordinat lokal `parent`. `parent` sebaiknya bukan Container
## (Container akan menata ulang posisi anaknya sendiri).
## Label membersihkan dirinya sendiri setelah animasi selesai.
static func float_text(parent: CanvasItem, pos: Vector2, text: String, color: Color) -> void:
	if parent == null or not is_instance_valid(parent) or not parent.is_inside_tree():
		return

	var label := Label.new()
	label.name = "FloatText"
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Font bawaan Godot saja -- proyek ini tidak memuat berkas .ttf sama sekali.
	var fallback: Font = ThemeDB.fallback_font
	if fallback != null:
		label.add_theme_font_override("font", fallback)
	label.add_theme_font_size_override("font_size", FLOAT_TEXT_FONT_SIZE)
	label.add_theme_color_override("font_color", color)
	# Garis tepi krem supaya tetap terbaca di atas dunia 3D yang ramai.
	label.add_theme_color_override("font_outline_color", Palette.FLOUR_WHITE)
	label.add_theme_constant_override("outline_size", FLOAT_TEXT_OUTLINE)
	parent.add_child(label)

	var half := Vector2(FLOAT_TEXT_WIDTH * 0.5, FLOAT_TEXT_HEIGHT * 0.5)
	label.size = Vector2(FLOAT_TEXT_WIDTH, FLOAT_TEXT_HEIGHT)
	label.pivot_offset = half
	label.position = pos - half
	label.z_index = FLOAT_TEXT_Z
	label.scale = Vector2(0.55, 0.55)

	var tw: Tween = label.create_tween()
	tw.set_parallel(true)
	tw.tween_property(label, "scale", Vector2.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position", label.position - Vector2(0.0, FLOAT_TEXT_RISE), FLOAT_TEXT_LIFE) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "modulate:a", 0.0, FLOAT_TEXT_LIFE * 0.42) \
		.set_delay(FLOAT_TEXT_LIFE * 0.58)
	tw.chain().tween_callback(label.queue_free)


# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

## Ambil bagian tubuh sebagai anak langsung; bila hierarki aktor menaruhnya di
## bawah `Body`, coba jalur itu juga. Selalu boleh mengembalikan null.
static func _part(actor: Node3D, part_name: String) -> Node3D:
	if actor == null or not is_instance_valid(actor):
		return null
	var n: Node3D = actor.get_node_or_null(NodePath(part_name)) as Node3D
	if n != null:
		return n
	return actor.get_node_or_null(NodePath("Body/" + part_name)) as Node3D


## Jaga `Face` dan `Hat` tetap menempel pada kepala.
##
## Bila CharacterFactory merakit keduanya sebagai ANAK dari `Head`, keduanya
## sudah ikut bergerak sendiri dan `get_node_or_null` di sini mengembalikan null
## (jalur "Face" hanya cocok untuk anak langsung aktor), sehingga fungsi ini
## tidak melakukan apa-apa. Bila keduanya dirakit sebagai SAUDARA `Head`, offset
## yang sama diteruskan supaya wajah tidak lepas melayang dari kepalanya.
static func _follow_head(actor: Node3D, dy: float, roll: float) -> void:
	var face: Node3D = actor.get_node_or_null(NodePath("Face")) as Node3D
	if face != null:
		face.position.y = _rest_pos(face).y + dy
	var hat: Node3D = actor.get_node_or_null(NodePath("Hat")) as Node3D
	if hat != null:
		hat.position.y = _rest_pos(hat).y + dy
		hat.rotation.z = _rest_rot(hat).z + roll


## Posisi lokal istirahat, direkam sekali saat pertama kali dibutuhkan.
static func _rest_pos(node: Node3D) -> Vector3:
	if node.has_meta(META_REST_POS):
		var cached: Vector3 = node.get_meta(META_REST_POS)
		return cached
	var p: Vector3 = node.position
	node.set_meta(META_REST_POS, p)
	return p


## Rotasi lokal istirahat, direkam sekali saat pertama kali dibutuhkan.
static func _rest_rot(node: Node3D) -> Vector3:
	if node.has_meta(META_REST_ROT):
		var cached: Vector3 = node.get_meta(META_REST_ROT)
		return cached
	var r: Vector3 = node.rotation
	node.set_meta(META_REST_ROT, r)
	return r


## Skala dasar node sebagai Vector3 (komponen z = 1.0 untuk node 2D/Control).
static func _base_scale(node: Node) -> Vector3:
	if node.has_meta(META_BASE_SCALE):
		var cached: Vector3 = node.get_meta(META_BASE_SCALE)
		return cached
	var s: Vector3 = Vector3.ONE
	if node is Node3D:
		s = (node as Node3D).scale
	elif node is Control:
		var c: Vector2 = (node as Control).scale
		s = Vector3(c.x, c.y, 1.0)
	elif node is Node2D:
		var d: Vector2 = (node as Node2D).scale
		s = Vector3(d.x, d.y, 1.0)
	node.set_meta(META_BASE_SCALE, s)
	return s


## Terapkan faktor pop `k` dengan kompensasi volume pada sumbu lateral.
static func _apply_pop(node: Node, base: Vector3, k: float) -> void:
	if node == null or not is_instance_valid(node):
		return
	var lateral: float = 1.0 + (1.0 - k) * SQUASH_VOLUME
	if node is Node3D:
		(node as Node3D).scale = Vector3(base.x * lateral, base.y * k, base.z * lateral)
	elif node is Control:
		(node as Control).scale = Vector2(base.x * lateral, base.y * k)
	elif node is Node2D:
		(node as Node2D).scale = Vector2(base.x * lateral, base.y * k)


## Pusatkan titik poros Control agar penskalaan terjadi dari tengah (GDD 7).
static func _center_pivot(node: Control) -> void:
	node.pivot_offset = node.size * 0.5


## Buat Tween baru untuk satu kategori animasi, membatalkan yang lama pada node
## yang sama supaya dua animasi tidak saling menarik properti yang sama.
static func _fresh_tween(node: Node, key: String) -> Tween:
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return null
	if node.has_meta(key):
		var prev: Variant = node.get_meta(key)
		if prev is Tween:
			var old: Tween = prev
			if old.is_valid():
				old.kill()
	var tw: Tween = node.create_tween()
	if tw == null:
		return null
	node.set_meta(key, tw)
	return tw
