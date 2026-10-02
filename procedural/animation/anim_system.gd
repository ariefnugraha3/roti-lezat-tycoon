class_name ProceduralAnimationSystem
extends RefCounted

## Sistem animasi prosedural tanpa rig skeleton (GDD 4.2, GDD 7, ARCHITECTURE 5).
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
## Nama node anak yang dicari mengikuti kontrak CharacterFactory (ARCHITECTURE 5):
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
## Pengali ayunan lengan yang dipasang CharacterFactory / set_carry_pose():
## lengan yang memegang barang hampir tidak berayun.
const META_SWING: String = "swing_scale"
## Pengali ayunan lengan saat memeluk barang bawaan.
const CARRY_SWING: float = 0.15
## Tween yang sedang berjalan untuk kategori tertentu, supaya bisa dibatalkan.
const META_TWEEN_POP: String = "rlt_tween_pop"
const META_TWEEN_UI: String = "rlt_tween_ui"
const META_TWEEN_ACTOR: String = "rlt_tween_actor"
const META_TWEEN_DOOR: String = "rlt_tween_door"

# ---------------------------------------------------------------------------
# GDD 4.2 — parameter jalan (gelombang sinus)
# ---------------------------------------------------------------------------

## Frekuensi dasar langkah dalam radian/detik pada speed = 1.0 (hanya untuk
## pemanggil lama `walk()`; aktor di dunia memakai `walk_cycle()`).
const WALK_FREQ: float = 5.6
## Irama langkah aktor di dunia (perbaikan 2026-10-01): langkah per detik NYATA
## = kecepatan model di layar / panjang langkah, dibatasi supaya tidak pernah
## tergopoh-gopoh (dulu ~12 langkah/detik) dan tetap hidup saat pelan. Pada
## kecepatan 2x/3x iramanya tertahan di batas atas; kaki sedikit meluncur,
## tetapi langkahnya tetap tenang.
const WALK_STEP_LENGTH: float = 0.7
const WALK_STEPS_MIN: float = 1.6
const WALK_STEPS_MAX: float = 3.6
## Laju peralihan diam <-> jalan (bobot per detik): mulai dan berhenti melangkah
## dalam ~0,2 detik, tanpa pose yang patah.
const WALK_BLEND_RATE: float = 5.5
## Amplitudo ayunan lengan (radian).
const WALK_ARM_SWING: float = 0.45
## Amplitudo ayunan kaki (radian).
const WALK_LEG_SWING: float = 0.60
## Tinggi pantulan badan tiap langkah (meter).
const WALK_BOB: float = 0.022
## Amplitudo anggukan kepala ceria (radian).
const WALK_HEAD_NOD: float = 0.05
## Kemiringan kepala kiri-kanan mengikuti langkah (radian).
const WALK_HEAD_TILT: float = 0.045
## Goyangan badan kiri-kanan (radian).
const WALK_SWAY: float = 0.035
## Ayunan celemek yang menyusul gerak badan (radian).
const WALK_APRON_SWAY: float = 0.032
## Keterlambatan fase lengan dan celemek di belakang kaki (radian): gerak susulan
## yang membuat langkah terasa luwes, bukan kaku serempak.
const WALK_ARM_LAG: float = 0.28
const WALK_APRON_LAG: float = 0.6
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
# GDD 21.4 — membungkus roti di meja kasir
# ---------------------------------------------------------------------------

#
# Kasir dan kantongnya (PackBagRig) membaca progres fase yang sama (0..1), jadi
# tangan dan kantong selalu sinkron di 1x/2x/3x: buka kantong -> roti masuk satu
# per satu -> ikat pita -> sodorkan ke pembeli.

## Babak membungkus (progres 0..1): buka kantong sampai PACK_OPEN_END; tiap roti
## paling lama PACK_BREAD_SPAN_MAX dan semua roti selesai paling lambat
## PACK_FILL_MAX_END; mengikat pita PACK_SEAL_SPAN; menggeser kantong ke pembeli
## PACK_OFFER_SPAN; sisanya menunggu pembayaran (lihat pack_phases).
const PACK_OPEN_END: float = 0.14
const PACK_BREAD_SPAN_MAX: float = 0.20
const PACK_FILL_MAX_END: float = 0.72
const PACK_SEAL_SPAN: float = 0.16
const PACK_OFFER_SPAN: float = 0.12
## Lengan hampir mendatar: tangan chibi yang pendek tepat di atas permukaan meja
## kasir (0,42 m), memegang kantong (radian).
const PACK_ARM_PITCH: float = 1.50
## Lengan sedikit merapat ke tengah (radian).
const PACK_ARM_IN: float = 0.10
## Sentakan membuka kantong: kedua tangan terangkat sejauh ini (radian).
const PACK_OPEN_SNAP: float = 0.38
## Tangan yang meraih roti: sedikit maju dan melebar, lalu terangkat ke mulut
## kantong (radian, relatif PACK_ARM_PITCH).
const PACK_REACH: float = 0.08
const PACK_REACH_OUT: float = 0.16
const PACK_LIFT: float = 0.34
## Tangan yang tidak meraih menahan kantong sedikit lebih rendah (radian).
const PACK_HOLD: float = -0.05
## Badan condong dan berputar ke arah tangan yang meraih (radian).
const PACK_LEAN: float = 0.10
const PACK_TWIST: float = 0.14
## Tepukan saat mengikat pita (radian) dan jumlah tepukan per babak.
const PACK_PAT: float = 0.16
const PACK_PATS: float = 2.0
## Menyodorkan kantong: lengan lurus ke depan, badan sedikit condong (radian).
const PACK_OFFER_PITCH: float = 1.72
const PACK_OFFER_LEAN: float = 0.08
## Menunggu pembayaran: tangan santai di tepi meja dan badan bergoyang pelan
## (radian, radian/detik).
const PACK_WAIT_PITCH: float = 1.30
const PACK_WAIT_SWAY: float = 0.05
const PACK_WAIT_FREQ: float = 3.0
## Kepala menunduk melihat kantong dan menoleh ke tangan yang bekerja (radian,
## negatif = menunduk).
const PACK_HEAD_NOD: float = -0.16
const PACK_HEAD_FOLLOW: float = 0.10
## Pembeli mengulurkan kedua tangan menerima kantong (radian), dengan goyang kecil
## berlawanan arah (radian, radian/detik) dan kepala menunduk-miring senang.
const RECEIVE_ARM_PITCH: float = 1.15
const RECEIVE_ARM_IN: float = 0.12
const RECEIVE_WIGGLE: float = 0.05
const RECEIVE_FREQ: float = 7.0
const RECEIVE_HEAD_NOD: float = -0.10
const RECEIVE_HEAD_TILT: float = 0.10

# ---------------------------------------------------------------------------
# GDD 31.6 — gerak saat menganggur
# ---------------------------------------------------------------------------

## Lengan kanan terangkat ke sisi wajah (radian): gulung ke atas dan sedikit maju.
const WIPE_ARM_ROLL: float = 2.76
const WIPE_ARM_PITCH: float = -0.32
## Usapan kain maju-mundur di pipi.
const WIPE_FREQ: float = 11.0
const WIPE_SWING: float = 0.22
## Kepala miring menyambut tangan (radian, negatif = ke kanan karakter).
const WIPE_HEAD_TILT: float = -0.18
## Satu siklus terkantuk: kepala pelan menunduk lalu tersentak bangun (detik).
const DOZE_CYCLE: float = 4.8
const DOZE_SNAP: float = 0.35
const DOZE_HEAD_DROOP: float = 0.30
## Pengunjung lihat-lihat (GDD 20.12): kepala menyapu rak kiri-kanan (radian,
## rad/detik), badan ikut sebagian dan sedikit condong, pandangan agak turun.
const LOOK_SWEEP: float = 0.42
const LOOK_SWEEP_FREQ: float = 1.5
const LOOK_BODY_FOLLOW: float = 0.3
const LOOK_LEAN: float = 0.06
const LOOK_HEAD_DOWN: float = -0.10
## Tangan kanan sesekali menopang dagu: maju-naik lalu masuk ke tengah badan.
const LOOK_CHIN_FREQ: float = 0.9
const LOOK_CHIN_PITCH: float = 2.1
const LOOK_CHIN_ROLL: float = -0.45
const LOOK_HEAD_TILT: float = 0.08

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

## Ayunan langkah berbasis gelombang sinus (GDD 4.2), versi stateless untuk
## pemanggil lama dan tes: `t` = waktu akumulatif detik, `speed` = pengali.
## Aktor di dunia memakai `walk_cycle()` dengan fase dan bobot milik ActorView.
static func walk(actor: Node3D, t: float, speed: float) -> void:
	var rate: float = maxf(speed, 0.15)
	walk_cycle(actor, t * WALK_FREQ * rate, clampf(rate, WALK_AMP_MIN, 1.0))


## Langkah kaki per detik nyata untuk model yang bergerak `speed_real` m/detik
## di layar (lihat WALK_STEP_LENGTH).
static func walk_steps_per_second(speed_real: float) -> float:
	return clampf(speed_real / WALK_STEP_LENGTH, WALK_STEPS_MIN, WALK_STEPS_MAX)


## Pose satu titik siklus langkah (GDD 4.2). `phase` (radian) maju terus-menerus
## (pi per langkah), jadi perubahan kecepatan tidak membuat pose melompat.
## `weight` 0..1 membaurkan dari pose diam ke langkah penuh, sehingga mulai dan
## berhenti berjalan tidak patah. Semua gerak berupa kurva mulus: kaki = sin,
## pantulan badan = kosinus dua kali per siklus (tertinggi saat kaki lurus di
## bawah badan), lengan dan celemek menyusul sedikit di belakang kaki.
static func walk_cycle(actor: Node3D, phase: float, weight: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var w: float = clampf(weight, 0.0, 1.0)
	var swing: float = sin(phase)
	var arm_swing: float = sin(phase - WALK_ARM_LAG)
	var lift: float = 0.5 + 0.5 * cos(phase * 2.0)

	# Kaki berlawanan fase satu sama lain.
	var leg_l: Node3D = _part(actor, "LegL")
	if leg_l != null:
		leg_l.rotation.x = _rest_rot(leg_l).x + swing * WALK_LEG_SWING * w
	var leg_r: Node3D = _part(actor, "LegR")
	if leg_r != null:
		leg_r.rotation.x = _rest_rot(leg_r).x - swing * WALK_LEG_SWING * w

	# Lengan berlawanan fase terhadap kaki di sisi yang sama.
	var arm_l: Node3D = _part(actor, "ArmL")
	if arm_l != null:
		arm_l.rotation.x = _rest_rot(arm_l).x - arm_swing * WALK_ARM_SWING * w * _swing_of(arm_l)
	var arm_r: Node3D = _part(actor, "ArmR")
	if arm_r != null:
		arm_r.rotation.x = _rest_rot(arm_r).x + arm_swing * WALK_ARM_SWING * w * _swing_of(arm_r)

	# Badan naik saat kaki lurus di bawahnya, turun saat melangkah lebar.
	var body: Node3D = _part(actor, "Body")
	if body != null:
		body.position.y = _rest_pos(body).y + lift * WALK_BOB * w
		body.rotation.z = _rest_rot(body).z + swing * WALK_SWAY * w

	# Kepala ikut naik-turun dan mengangguk pelan sedikit di belakang badan.
	var head_dy: float = lift * WALK_BOB * 1.1 * w
	var head_roll: float = -arm_swing * WALK_HEAD_TILT * w
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var head_rot: Vector3 = _rest_rot(head)
		head.position.y = _rest_pos(head).y + head_dy
		head.rotation.x = head_rot.x + sin(phase * 2.0 - 0.6) * WALK_HEAD_NOD * w
		head.rotation.z = head_rot.z + head_roll
	_follow_head(actor, head_dy, head_roll * HAT_FOLLOW_THROUGH)

	# Celemek ikut berayun menyusul badan (GDD 4.1 -- kesan kain empuk).
	var apron: Node3D = _part(actor, "Apron")
	if apron != null:
		apron.rotation.z = _rest_rot(apron).z + sin(phase - WALK_APRON_LAG) * WALK_APRON_SWAY * w


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
		arm_l.rotation.x = _rest_rot(arm_l).x + breathe * IDLE_ARM * _swing_of(arm_l)
	var arm_r: Node3D = _part(actor, "ArmR")
	if arm_r != null:
		arm_r.rotation.x = _rest_rot(arm_r).x - breathe * IDLE_ARM * _swing_of(arm_r)

	var leg_l: Node3D = _part(actor, "LegL")
	if leg_l != null:
		leg_l.rotation.x = _rest_rot(leg_l).x
	var leg_r: Node3D = _part(actor, "LegR")
	if leg_r != null:
		leg_r.rotation.x = _rest_rot(leg_r).x


## Batas babak membungkus untuk `n` roti: x = akhir membuka kantong, y = akhir
## memasukkan roti, z = akhir mengikat pita. Roti sedikit tidak melayang lambat:
## babak berikutnya maju lebih awal dan sisa waktunya dipakai menunggu bayaran.
static func pack_phases(n: int) -> Vector3:
	var count: int = maxi(n, 1)
	var span: float = minf((PACK_FILL_MAX_END - PACK_OPEN_END) / float(count), PACK_BREAD_SPAN_MAX)
	var fill_end: float = PACK_OPEN_END + span * float(count)
	return Vector3(PACK_OPEN_END, fill_end, fill_end + PACK_SEAL_SPAN)


## Jendela progres roti ke-`i` dari `n` yang dimasukkan ke kantong: [mulai, selesai].
static func pack_bread_window(i: int, n: int) -> Vector2:
	var ph: Vector3 = pack_phases(n)
	var span: float = (ph.y - ph.x) / float(maxi(n, 1))
	var start: float = ph.x + span * float(i)
	return Vector2(start, start + span)


## Membungkus di meja kasir (GDD 21.4) mengikuti progres fase `p` (0..1) dan
## jumlah roti `n`: kedua tangan menyentak membuka kantong; tangan kiri (sisi
## kantong dan roti, lihat PackBagRig) meraih tiap roti lalu mengangkatnya ke
## mulut kantong sementara tangan kanan menahan kantong dan badan condong serta
## menoleh; dua tepukan saat pita diikat; kedua lengan menyodorkan kantong; lalu
## tangan santai menunggu pembayaran. `p` < 0 memutar siklus 3 detik.
static func pack(actor: Node3D, t: float, p: float = -1.0, n: int = 3) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if p < 0.0:
		p = fmod(t / 3.0, 1.0)
	var ph: Vector3 = pack_phases(n)
	var pitch: Array[float] = [PACK_ARM_PITCH, PACK_ARM_PITCH]
	var spread: Array[float] = [0.0, 0.0]
	var lean: float = 0.0
	var twist: float = 0.0
	var follow: float = 0.0
	var nod: float = PACK_HEAD_NOD
	var bounce: float = 0.0
	if p < ph.x:
		var snap: float = sin(clampf(p / ph.x, 0.0, 1.0) * PI)
		pitch[0] += snap * PACK_OPEN_SNAP
		pitch[1] += snap * PACK_OPEN_SNAP
		bounce = snap
	elif p < ph.y:
		var count: int = maxi(n, 1)
		for i in count:
			var w: Vector2 = pack_bread_window(i, count)
			if p < w.x or p >= w.y:
				continue
			var k: float = (p - w.x) / (w.y - w.x)
			# Meraih roti di samping kantong, lalu mengangkatnya ke mulut kantong.
			var reach: float = smoothstep(0.0, 0.30, k) * (1.0 - smoothstep(0.40, 0.65, k))
			var lift: float = sin(clampf((k - 0.35) / 0.65, 0.0, 1.0) * PI)
			pitch[0] += PACK_REACH * reach + PACK_LIFT * lift
			pitch[1] += PACK_HOLD
			spread[0] = PACK_REACH_OUT * reach
			lean = PACK_LEAN * reach
			twist = PACK_TWIST * maxf(reach, lift * 0.5)
			follow = PACK_HEAD_FOLLOW * maxf(reach, lift)
	elif p < ph.z:
		var ks: float = (p - ph.y) / (ph.z - ph.y)
		var pat: float = absf(sin(ks * PI * PACK_PATS))
		pitch[0] += PACK_PAT * pat
		pitch[1] += PACK_PAT * pat
		nod -= 0.06 * pat
		bounce = pat * 0.5
	else:
		# Sodorkan (lengan lurus), lalu santai menunggu pembeli membayar.
		var ko: float = clampf((p - ph.z) / PACK_OFFER_SPAN, 0.0, 1.0)
		var offer: float = sin(ko * PI)
		var wait: float = smoothstep(0.5, 1.0, ko)
		var sway: float = sin(t * PACK_WAIT_FREQ) * PACK_WAIT_SWAY * wait
		pitch[0] = lerpf(PACK_ARM_PITCH, PACK_WAIT_PITCH, wait) + (PACK_OFFER_PITCH - PACK_ARM_PITCH) * offer + sway
		pitch[1] = lerpf(PACK_ARM_PITCH, PACK_WAIT_PITCH, wait) + (PACK_OFFER_PITCH - PACK_ARM_PITCH) * offer - sway
		lean = PACK_OFFER_LEAN * offer
		nod = lerpf(PACK_HEAD_NOD, PACK_HEAD_NOD * 0.3, maxf(offer, wait))
		follow = 0.08 * maxf(offer, wait)
	for a in 2:
		var arm: Node3D = _part(actor, "ArmL" if a == 0 else "ArmR")
		if arm == null:
			continue
		var dir: float = -1.0 if a == 0 else 1.0
		arm.rotation = Vector3(pitch[a], 0.0, -(PACK_ARM_IN - spread[a]) * dir)
	# Badan (induk kedua lengan) condong dan menoleh; kepala bukan anak badan,
	# jadi posisinya ikut digeser supaya tetap menempel di leher.
	var body: Node3D = _part(actor, "Body")
	var bp: Vector3 = _rest_pos(body) if body != null else Vector3.ZERO
	var lift_y: float = bounce * 0.008
	if body != null:
		var br: Vector3 = _rest_rot(body)
		body.position = Vector3(bp.x, bp.y + lift_y, bp.z)
		body.rotation = Vector3(br.x - lean, br.y + twist, br.z)
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var hp: Vector3 = _rest_pos(head)
		var hr: Vector3 = _rest_rot(head)
		var h: float = hp.y - bp.y
		head.position = Vector3(hp.x, bp.y + lift_y + h * cos(lean), hp.z - h * sin(lean))
		head.rotation = Vector3(hr.x + nod - lean, hr.y + twist, hr.z + follow)
	for leg_name: String in ["LegL", "LegR"]:
		var leg: Node3D = _part(actor, leg_name)
		if leg != null:
			leg.rotation.x = _rest_rot(leg).x


## Pembeli mengulurkan kedua tangan menerima kantong yang disodorkan kasir
## (GDD 21.4). `k` 0..1 memudarkan pose masuk; dipanggil setelah idle_bob().
static func receive(actor: Node3D, t: float, k: float) -> void:
	if actor == null or not is_instance_valid(actor) or k <= 0.0:
		return
	var wiggle: float = sin(t * RECEIVE_FREQ) * RECEIVE_WIGGLE
	for a in 2:
		var arm: Node3D = _part(actor, "ArmL" if a == 0 else "ArmR")
		if arm == null:
			continue
		var rest: Vector3 = _rest_rot(arm)
		var dir: float = -1.0 if a == 0 else 1.0
		arm.rotation = Vector3(lerpf(rest.x, RECEIVE_ARM_PITCH + wiggle * dir, k), rest.y,
			lerpf(rest.z, -RECEIVE_ARM_IN * dir, k))
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var hr: Vector3 = _rest_rot(head)
		head.rotation.x = lerpf(head.rotation.x, hr.x + RECEIVE_HEAD_NOD, k)
		head.rotation.z = lerpf(head.rotation.z, hr.z + RECEIVE_HEAD_TILT, k)


## Mengelap wajah dengan kain lap setelah lama menganggur (GDD 31.6): lengan
## kanan terangkat ke sisi wajah, mengusap maju-mundur, lalu turun lagi. `k`
## 0..1 sepanjang gerakan; dipanggil setelah idle_bob() tiap frame.
static func wipe_face(actor: Node3D, k: float, t: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var up: float = smoothstep(0.0, 0.18, k) * (1.0 - smoothstep(0.82, 1.0, k))
	var rub: float = smoothstep(0.16, 0.26, k) * (1.0 - smoothstep(0.74, 0.84, k))
	var arm: Node3D = _part(actor, "ArmR")
	if arm != null:
		var rest: Vector3 = _rest_rot(arm)
		arm.rotation = Vector3(lerpf(rest.x, WIPE_ARM_PITCH, up) + sin(t * WIPE_FREQ) * WIPE_SWING * rub,
			rest.y, lerpf(rest.z, WIPE_ARM_ROLL, up))
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var head_rot: Vector3 = _rest_rot(head)
		head.rotation.z = head_rot.z + WIPE_HEAD_TILT * up
		head.rotation.x = head_rot.x - 0.05 * up


## Terkantuk-kantuk setelah menganggur lebih lama (GDD 31.6): kepala pelan-pelan
## menunduk lalu tersentak bangun, badan sedikit merosot, lengan lemas.
## Dipanggil setelah idle_bob() tiap frame.
static func doze(actor: Node3D, t: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var cycle: float = fposmod(t, DOZE_CYCLE)
	var droop: float = smoothstep(0.0, DOZE_CYCLE - DOZE_SNAP, cycle)
	if cycle > DOZE_CYCLE - DOZE_SNAP:
		droop = 1.0 - smoothstep(DOZE_CYCLE - DOZE_SNAP, DOZE_CYCLE, cycle)
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var head_rot: Vector3 = _rest_rot(head)
		head.rotation.x = head_rot.x - (0.08 + DOZE_HEAD_DROOP * droop)
		head.rotation.z = head_rot.z + 0.06 * sin(t * 0.7)
		head.position.y = _rest_pos(head).y - 0.012 * droop
	var body: Node3D = _part(actor, "Body")
	if body != null:
		body.position.y = _rest_pos(body).y - 0.008 + sin(t * 1.1) * 0.004
		body.rotation.z = _rest_rot(body).z
	for i in 2:
		var arm: Node3D = _part(actor, "ArmL" if i == 0 else "ArmR")
		if arm != null:
			arm.rotation.x = _rest_rot(arm).x + 0.04 * sin(t * 1.1 + float(i))


## Pengunjung lihat-lihat (GDD 20.12): kepala menoleh pelan kiri-kanan menyapu
## rak, badan ikut sedikit dan condong ke depan, dan kira-kira sepertiga waktu
## tangan kanan menopang dagu ("hmm"). Stateless; dipanggil setelah idle_bob().
static func look_around(actor: Node3D, t: float) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var sweep: float = sin(t * LOOK_SWEEP_FREQ) * LOOK_SWEEP
	var chin: float = smoothstep(0.25, 0.6, sin(t * LOOK_CHIN_FREQ))
	var body: Node3D = _part(actor, "Body")
	var bp: Vector3 = _rest_pos(body) if body != null else Vector3.ZERO
	if body != null:
		var br: Vector3 = _rest_rot(body)
		body.rotation = Vector3(br.x - LOOK_LEAN, br.y + sweep * LOOK_BODY_FOLLOW, body.rotation.z)
	var head: Node3D = _part(actor, "Head")
	if head != null:
		var hp: Vector3 = _rest_pos(head)
		var hr: Vector3 = _rest_rot(head)
		var h: float = hp.y - bp.y
		# Kepala bukan anak badan: digeser supaya tetap menempel di leher saat condong.
		head.position = Vector3(hp.x, head.position.y - h * (1.0 - cos(LOOK_LEAN)), hp.z - h * sin(LOOK_LEAN))
		head.rotation = Vector3(head.rotation.x + LOOK_HEAD_DOWN, hr.y + sweep, head.rotation.z + chin * LOOK_HEAD_TILT)
	var arm: Node3D = _part(actor, "ArmR")
	if arm != null:
		arm.rotation.x = lerpf(arm.rotation.x, LOOK_CHIN_PITCH, chin)
		arm.rotation.z = lerpf(_rest_rot(arm).z, LOOK_CHIN_ROLL, chin)


## Sudut ayunan kaki ke depan saat duduk (rad) dan ayunan kecil kaki yang
## menjuntai; pinggul sedikit di atas bantal; lengan bertumpu di pangkuan.
const SIT_LEG_ANGLE: float = 1.22
const SIT_LEG_DANGLE: float = 0.07
const SIT_HIP_LIFT: float = 0.03
const SIT_ARM_ANGLE: float = 0.55


## Duduk di kursi koki (GDD 5.1.4): seluruh model diturunkan supaya pinggulnya
## tepat di atas bantal (`seat_y`, meter dunia dari lantai), kedua kaki terayun
## ke depan dan menjuntai pelan seperti anak kecil di kursi tinggi, dan tangan
## bertumpu di pangkuan (kecuali `arms` false, saat lap wajah atau terkantuk).
## Dipanggil setelah idle_bob() tiap frame.
static func sit(actor: Node3D, t: float, seat_y: float, arms: bool = true) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	var leg_l: Node3D = _part(actor, "LegL")
	var hip: float = (_rest_pos(leg_l).y if leg_l != null else 0.25) * _base_scale(actor).y
	actor.position.y = seat_y + SIT_HIP_LIFT - hip
	for i in 2:
		var leg: Node3D = _part(actor, "LegL" if i == 0 else "LegR")
		if leg != null:
			leg.rotation.x = _rest_rot(leg).x + SIT_LEG_ANGLE + sin(t * 1.4 + float(i) * PI) * SIT_LEG_DANGLE
	if not arms:
		return
	for j in 2:
		var arm: Node3D = _part(actor, "ArmL" if j == 0 else "ArmR")
		if arm != null:
			arm.rotation.x = _rest_rot(arm).x + SIT_ARM_ANGLE


## Berdiri lagi dari kursi: model kembali ke lantai dan kaki serta lengan ke
## pose istirahat.
static func stand_up(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	actor.position.y = 0.0
	for part_name: String in ["LegL", "LegR", "ArmL", "ArmR"]:
		var n: Node3D = _part(actor, part_name)
		if n != null:
			n.rotation = _rest_rot(n)


## Kembalikan lengan, kepala & badan ke pose istirahat setelah gerakan khusus (pack,
## wipe_face, doze, look_around) berakhir; walk()/idle_bob() hanya mengatur sumbu X lengan.
static func end_pose(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	for part_name: String in ["ArmL", "ArmR", "Head", "Body"]:
		var n: Node3D = _part(actor, part_name)
		if n != null:
			n.rotation = _rest_rot(n)
			n.position = _rest_pos(n)


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
## Goyang pelan tanpa henti untuk ikon hiasan (logo roti di splash & menu):
## miring kiri-kanan dengan easing sinus. Reduced Motion = diam.
static func idle_wobble(node: Control, angle := 0.06, period := 2.6) -> void:
	if node == null or not is_instance_valid(node) or SettingsManager.reduced_motion():
		return
	if not node.is_inside_tree():
		node.tree_entered.connect(func() -> void: idle_wobble(node, angle, period), CONNECT_ONE_SHOT)
		return
	node.pivot_offset = node.size * 0.5 if node.size != Vector2.ZERO else node.custom_minimum_size * 0.5
	var tw: Tween = _fresh_tween(node, META_TWEEN_POP)
	if tw == null:
		return
	tw.set_loops()
	tw.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(node, "rotation", angle, period * 0.5)
	tw.tween_property(node, "rotation", -angle, period * 0.5)


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

## Pose membawa barang di depan badan (GDD 4.2, 31.2): kedua lengan maju
## memeluk barang dan ayunannya diredam. `carrying` false mengembalikan pose
## istirahat asli dari CharacterFactory. Aman dipanggil berulang kali.
static func set_carry_pose(actor: Node3D, carrying: bool) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	for i in 2:
		var arm: Node3D = _part(actor, "ArmL" if i == 0 else "ArmR")
		if arm == null:
			continue
		if not arm.has_meta("carry_base_rotation"):
			arm.set_meta("carry_base_rotation", arm.get_meta("base_rotation", arm.rotation))
			arm.set_meta("carry_base_swing", arm.get_meta(META_SWING, 1.0))
		var rest: Vector3 = arm.get_meta("carry_base_rotation")
		var swing_k: float = float(arm.get_meta("carry_base_swing"))
		if carrying:
			rest = CharacterFactory.carry_arm_rotation(-1.0 if i == 0 else 1.0)
			swing_k = CARRY_SWING
		arm.set_meta(META_REST_ROT, rest)
		arm.set_meta(META_SWING, swing_k)
		arm.rotation = rest


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


## Pengali ayunan lengan (1 bila tidak diatur).
static func _swing_of(node: Node3D) -> float:
	if node.has_meta(META_SWING):
		return float(node.get_meta(META_SWING))
	return 1.0


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
