class_name ActorView
extends Node3D
## Tampilan satu aktor logis (GDD 16, 20.8, 31). Node ini hanya MENGIKUTI
## SimActor: posisi, arah, barang bawaan, patience bar, dan balon "!". Aktor
## pelanggan/driver/kurir berasal dari pool dan wajib bersih lewat
## `reset_for_pool()` sebelum dipakai ulang (GDD 91.2, 115.2).
##
## Pemain & staf juga punya gerak menganggur murni visual (GDD 31.6): setiap
## `idle_wipe_every_seconds` detik NYATA tanpa aktivitas mereka memainkan satu
## gerakan. Pemain selalu mengelap wajah dengan kain lap; staf bergiliran
## mengelap wajah, meregangkan badan, bersenandung, minum teh, dan gerak khas
## perannya (keputusan maintainer 2026-10-04, `set_idle_gestures`). Hanya pemain
## yang bisa terkantuk-kantuk, saat gelembung pikiran terakhir hilang
## (`DataRegistry.player_doze_after_seconds`, diatur WorldView); staf tidak
## pernah tertidur. Timer tidak berjalan saat game di-pause dan tidak pernah
## memengaruhi simulasi.

const PATIENCE_Y: float = 1.08
const BUBBLE_Y: float = 1.30
const TURN_SPEED: float = 10.0

const GESTURE_NONE: int = 0
const GESTURE_WIPE: int = 1
const GESTURE_DOZE: int = 2
const GESTURE_STRETCH: int = 3
const GESTURE_HUM: int = 4
const GESTURE_TEA: int = 5
## Gerak khas peran: kasir melempar koin, koki menepuk tepung dari celemek.
const GESTURE_ROLE: int = 6
## Nama gerakan di data (`presentation.staff_idle_gestures`) -> konstanta.
const GESTURE_IDS: Dictionary = {
	"wipe": GESTURE_WIPE, "stretch": GESTURE_STRETCH, "hum": GESTURE_HUM, "tea": GESTURE_TEA, "role": GESTURE_ROLE,
}
## Benda melayang dari gerak menganggur: jarak antar-kemunculan dan umur
## (detik), serta skala puncaknya. Batas jumlah sekaligus per aktor.
const FLOAT_EVERY: Dictionary = {"z": 1.5, "note": 0.55, "steam": 0.32, "flour": 0.24}
const FLOAT_LIFE: Dictionary = {"z": 2.0, "note": 1.6, "steam": 1.1, "flour": 0.7}
const FLOAT_SCALE: Dictionary = {"note": 1.5, "steam": 2.2, "flour": 1.8}
const FLOATER_MAX: int = 6
## Huruf "Z" kantuk: jumlah maksimum sekaligus.
const Z_MAX: int = 3
## Titik lahir huruf "Z": sedikit ke samping, tepat di atas puncak kepala/topi.
const Z_SIDE: float = 0.12
const Z_GAP: float = 0.02
## Skala puncak huruf "Z" agar terbaca pada zoom gameplay.
const Z_SCALE: float = 1.6

var actor_id: StringName = &""
var model: Node3D = null
var spec_key: String = ""
var _t: float = 0.0
var _carry: Node3D = null
var _carry_key: String = ""
var _patience: PatienceBar = null
var _bubble: StationMarker = null
var _thought: Label3D = null
var _sparkle_cd: float = 0.0
## Gerak menganggur hanya untuk pemain & staf (diaktifkan WorldView).
var _idle_enabled: bool = false
var _busy: bool = true
var _action: StringName = &""
## Progres fase membungkus (0..1, -1 = siklus sendiri) dan jumlah roti (GDD 21.4).
var _pack_p: float = -1.0
var _pack_n: int = 3
## Pembeli mengulurkan tangan menerima kantong (0..1, GDD 21.4).
var _receive_k: float = 0.0
## Pengunjung lihat-lihat sedang mengamati rak (GDD 20.12).
var _looking: bool = false
## Tidur ditahan sementara (pemain: rangkaian pikiran toko sepi belum selesai, GDD 31.6).
var _doze_blocked: bool = false
## Ambang tidur aktor ini (detik nyata); INF = tidak pernah tertidur (staf).
var _doze_after: float = INF
var _idle_real: float = 0.0
var _gesture: int = GESTURE_NONE
var _cloth: Node3D = null
## Cangkir teh & koin kasir: anak ActorView yang ditempatkan di tangan kanan
## tiap frame (bukan anak lengan, supaya tetap tegak / bebas melambung).
var _cup: Node3D = null
var _coin: Node3D = null
## Gerakan yang dipakai bergiliran tiap tanda (pemain: lap wajah saja), geseran
## urutannya (staf: urutan roster), dan apakah ia koki (gerak khas perannya).
var _rotation: Array[int] = [GESTURE_WIPE]
var _rotation_offset: int = 0
var _baker: bool = false
## Benda melayang yang sedang hidup ("z", "note", "steam", "flour").
var _floaters: Array[Node3D] = []
var _float_timer: float = 0.0
var _float_count: int = 0
static var _staff_rotation: Array[int] = []
## Langkah (GDD 4.2): fase siklus yang maju terus, bobot jalan 0..1 yang
## dilunakkan, dan kecepatan model di layar (meter/detik nyata, dilunakkan).
var _walk_phase: float = 0.0
var _walk_w: float = 0.0
var _vis_speed: float = 0.0
## Titik duduk dunia (permukaan bantal kursi koki, GDD 5.1.4); INF = berdiri.
var _seat: Vector3 = Vector3.INF


func _init() -> void:
	name = "Actor"


## Rakit ulang model hanya bila spesifikasinya berubah.
func bind(id: StringName, key: String, spec: Dictionary) -> void:
	actor_id = id
	if key == spec_key and model != null:
		return
	spec_key = key
	if model != null and is_instance_valid(model):
		model.queue_free()
	_clear_idle_fx()
	model = CharacterFactory.build(spec)
	add_child(model)
	_apply_carry_pose()


func reset_for_pool() -> void:
	actor_id = &""
	visible = false
	set_look_around(false)
	_set_carry("")
	if _patience != null:
		_patience.visible = false
	if _bubble != null:
		_bubble.hide_marker()
	if _thought != null:
		_thought.visible = false
	_t = 0.0
	_walk_phase = 0.0
	_walk_w = 0.0
	_vis_speed = 0.0
	_idle_enabled = false
	_busy = true
	_action = &""
	_seat = Vector3.INF
	_clear_idle_fx()


## Sinkron dengan state logis (dipanggil tiap frame oleh WorldView).
func sync(a: SimActor, delta: float, animate: bool) -> void:
	_t += delta
	var target := Vector3(a.pos.x, 0.0, a.pos.y)
	if _seat != Vector3.INF:
		target = Vector3(_seat.x, 0.0, _seat.z)
	var before: Vector3 = global_position
	var jumped: bool = global_position.distance_to(target) > 1.5
	global_position = target if jumped else global_position.lerp(target, minf(1.0, delta * 18.0))
	_update_walk(a, before, jumped, delta)
	if a.facing.length_squared() > 0.0001:
		# Wajah karakter menghadap -Z (CharacterFactory.FRONT).
		var want: float = atan2(-a.facing.x, -a.facing.y)
		rotation.y = lerp_angle(rotation.y, want, minf(1.0, TURN_SPEED * delta))
	if model == null or not animate:
		return
	_update_idle(a, delta)
	if _seat != Vector3.INF:
		ProceduralAnimationSystem.idle_bob(model, _t)
		_play_gesture()
		ProceduralAnimationSystem.sit(model, _t, _seat.y, _gesture == GESTURE_NONE)
	elif _action == &"pack" and not a.moving:
		ProceduralAnimationSystem.pack(model, _t, _pack_p, _pack_n)
	elif _walk_w > 0.0:
		ProceduralAnimationSystem.walk_cycle(model, _walk_phase, _walk_w)
	else:
		ProceduralAnimationSystem.idle_bob(model, _t)
		if _looking:
			ProceduralAnimationSystem.look_around(model, _t)
		if _receive_k > 0.0:
			ProceduralAnimationSystem.receive(model, _t, _receive_k)
		_play_gesture()
	_update_props()
	_update_floaters(delta)


# ===========================================================================
# GERAK MENGANGGUR (GDD 31.6) & AKSI
# ===========================================================================

## Irama langkah dari kecepatan model DI LAYAR (GDD 4.2, perbaikan 2026-10-01).
## Dulu irama = kecepatan simulasi x 4,5 sehingga pemain melangkah ~12 kali per
## detik. Kini langkah per detik mengikuti kecepatan nyata (termasuk kecepatan
## 2x/3x dan pause) dengan batas atas yang tenang; fase maju terus tanpa
## melompat, dan bobotnya naik-turun dalam ~0,2 detik saat mulai dan berhenti.
## Saat game di-pause aktor yang sedang berjalan berhenti melangkah perlahan.
func _update_walk(a: SimActor, before: Vector3, jumped: bool, delta: float) -> void:
	if delta <= 0.0:
		return
	var moved: float = 0.0 if jumped else Vector2(global_position.x - before.x, global_position.z - before.z).length()
	_vis_speed = lerpf(_vis_speed, moved / delta, minf(1.0, delta * 10.0))
	var walking: bool = a.moving and _vis_speed > 0.15
	_walk_w = move_toward(_walk_w, 1.0 if walking else 0.0, delta * ProceduralAnimationSystem.WALK_BLEND_RATE)
	if _walk_w > 0.0:
		var steps: float = ProceduralAnimationSystem.walk_steps_per_second(_vis_speed)
		_walk_phase = fposmod(_walk_phase + delta * PI * steps, TAU)
	else:
		_walk_phase = 0.0


## Bobot langkah saat ini (0 = diam, 1 = berjalan penuh).
func walk_weight() -> float:
	return _walk_w


## Koki duduk di kursinya: WorldView memberi titik bantal (dunia); INF = berdiri.
func set_seat(p: Vector3) -> void:
	if p == _seat:
		return
	var was: bool = _seat != Vector3.INF
	_seat = p
	if was and p == Vector3.INF and model != null and is_instance_valid(model):
		ProceduralAnimationSystem.stand_up(model)
		_apply_carry_pose()


func is_seated() -> bool:
	return _seat != Vector3.INF


## Aktifkan gerak menganggur (pemain & staf). Pelanggan tidak pernah memakainya.
func set_idle_enabled(on: bool) -> void:
	_idle_enabled = on


## Gerak menganggur staf (GDD 31.6): `gestures` dimainkan bergiliran, satu per
## tanda `idle_wipe_every_seconds`, mulai dari urutan ke-`offset`; `baker`
## memilih gerak khas koki (menepuk tepung) alih-alih kasir (melempar koin).
func set_idle_gestures(gestures: Array[int], offset: int, baker: bool) -> void:
	_rotation = gestures
	_rotation_offset = offset
	_baker = baker


## Urutan gerak menganggur staf dari data (`presentation.staff_idle_gestures`).
static func staff_gestures() -> Array[int]:
	if _staff_rotation.is_empty():
		for g: Variant in DataRegistry.bal("presentation.staff_idle_gestures"):
			_staff_rotation.append(int(GESTURE_IDS.get(str(g), GESTURE_WIPE)))
	return _staff_rotation


## Lama satu gerakan (detik nyata): lap wajah memakai `wipe_gesture_seconds`,
## gerakan staf lainnya `staff_gesture_seconds`.
static func gesture_seconds(g: int) -> float:
	if g == GESTURE_WIPE:
		return DataRegistry.balf("presentation.wipe_gesture_seconds")
	var durations: Dictionary = DataRegistry.bal("presentation.staff_gesture_seconds")
	for key: Variant in GESTURE_IDS.keys():
		if int(GESTURE_IDS[key]) == g:
			return float(durations.get(key, 1.0))
	return 1.0


## Apakah aktor sedang mengerjakan sesuatu (dihitung WorldView dari state sim).
func set_busy(busy: bool) -> void:
	_busy = busy


## Aksi tangan khusus: &"pack" (membungkus di meja kasir) atau &"" (tidak ada).
func set_action(action: StringName) -> void:
	if action == _action:
		return
	var was_pack: bool = _action == &"pack"
	_action = action
	if was_pack:
		_pack_p = -1.0
	if was_pack and model != null:
		ProceduralAnimationSystem.end_pose(model)
		_apply_carry_pose()


## Tahan tidur walau sudah lama diam; yang sedang tidur langsung terbangun.
## Selama ditahan, lap wajah tetap berulang sesuai jadwalnya.
func set_doze_blocked(on: bool) -> void:
	_doze_blocked = on


## Ambang tidur aktor ini (pemain, GDD 31.6). Tanpa ambang (staf) ia tidak
## pernah tertidur.
func set_doze_after(seconds: float) -> void:
	_doze_after = seconds


func doze_after() -> float:
	return _doze_after


## Pembeli mengulurkan tangan menerima kantong (0..1). Saat kembali ke 0, lengan
## dan kepala dipulihkan ke pose istirahat.
func set_receive(k: float) -> void:
	var was: bool = _receive_k > 0.0
	_receive_k = clampf(k, 0.0, 1.0)
	if was and _receive_k <= 0.0 and model != null:
		ProceduralAnimationSystem.end_pose(model)
		_apply_carry_pose()


## Pengunjung lihat-lihat berdiri mengamati rak (GDD 20.12). Saat berhenti,
## kepala, badan, dan lengan kembali ke pose istirahat.
func set_look_around(on: bool) -> void:
	if on == _looking:
		return
	_looking = on
	if not on and model != null and is_instance_valid(model):
		ProceduralAnimationSystem.end_pose(model)
		_apply_carry_pose()


func is_looking_around() -> bool:
	return _looking


## Progres fase membungkus dari kasir ini, supaya tangannya sinkron dengan kantong.
func set_pack_progress(p: float, n: int) -> void:
	_pack_p = p
	_pack_n = maxi(n, 1)


func gesture() -> int:
	return _gesture


## Tinggi puncak kepala/topi model di ruang ActorView (m), dari meta "aabb"
## HeadMesh; dipakai huruf "Z" dan gelembung pikiran.
func head_top() -> float:
	if model == null or not is_instance_valid(model):
		return 0.95
	var head: Node3D = CharacterFactory.part(model, "Head")
	var hm: Node = head.get_node_or_null("HeadMesh") if head != null else null
	if hm == null or not hm.has_meta("aabb"):
		return 0.95
	var box: AABB = hm.get_meta("aabb")
	return (head.position.y + box.end.y) * model.scale.y


## Titik dunia tepat di puncak kepala, juga saat duduk (model terangkat ke
## bantal kursi); dipakai gelembung pikiran dan celetukan.
func head_anchor() -> Vector3:
	var lift: float = model.position.y if model != null and is_instance_valid(model) else 0.0
	return global_position + Vector3(0.0, lift + head_top(), 0.0)


func idle_seconds() -> float:
	return _idle_real


## Gerak menganggur untuk lama menganggur `idle_seconds` (detik nyata, GDD 31.6):
## tidur sejak `doze_at`; sebelumnya di tiap kelipatan `idle_wipe_every_seconds`
## gerakan berikutnya dari `rotation` (mulai urutan ke-`offset`) selama
## gesture_seconds() gerakan itu.
static func gesture_for(idle_seconds_value: float, doze_at: float, rotation: Array[int] = [GESTURE_WIPE], offset: int = 0) -> int:
	if idle_seconds_value >= doze_at:
		return GESTURE_DOZE
	var every: float = DataRegistry.balf("presentation.idle_wipe_every_seconds")
	if idle_seconds_value < every or rotation.is_empty():
		return GESTURE_NONE
	var n: int = int(floor(idle_seconds_value / every))
	var g: int = rotation[posmod(n - 1 + offset, rotation.size())]
	return g if fposmod(idle_seconds_value, every) < gesture_seconds(g) else GESTURE_NONE


func _update_idle(a: SimActor, delta: float) -> void:
	if not _idle_enabled:
		return
	if a.moving or _busy or _action != &"":
		_idle_real = 0.0
	elif not PauseManager.is_paused():
		_idle_real += delta
	_set_gesture(gesture_for(_idle_real, INF if _doze_blocked else doze_after(), _rotation, _rotation_offset))


## Progres gerakan yang sedang dimainkan (0..1).
func _gesture_progress() -> float:
	var every: float = DataRegistry.balf("presentation.idle_wipe_every_seconds")
	return clampf(fposmod(_idle_real, every) / gesture_seconds(_gesture), 0.0, 1.0)


## Pose gerakan yang sedang dimainkan, dipanggil setelah idle_bob() tiap frame.
func _play_gesture() -> void:
	var k: float = _gesture_progress()
	match _gesture:
		GESTURE_WIPE:
			ProceduralAnimationSystem.wipe_face(model, k, _t)
		GESTURE_DOZE:
			ProceduralAnimationSystem.doze(model, _t)
		GESTURE_STRETCH:
			ProceduralAnimationSystem.stretch(model, k, _t)
		GESTURE_HUM:
			ProceduralAnimationSystem.hum(model, k, _t)
		GESTURE_TEA:
			ProceduralAnimationSystem.sip_tea(model, k, _t)
		GESTURE_ROLE:
			if _baker:
				ProceduralAnimationSystem.pat_flour(model, k, _t)
			else:
				ProceduralAnimationSystem.toss_coin(model, k, _t)


func _set_gesture(g: int) -> void:
	if g == _gesture:
		return
	var had: int = _gesture
	_gesture = g
	if model == null:
		return
	if had != GESTURE_NONE:
		ProceduralAnimationSystem.end_pose(model)
	_show_cloth(g == GESTURE_WIPE)
	_show_cup(g == GESTURE_TEA)
	_show_coin(g == GESTURE_ROLE and not _baker)
	_float_timer = 0.15
	match g:
		GESTURE_WIPE, GESTURE_STRETCH, GESTURE_TEA:
			CharacterFactory.set_expression(model, "lega")
		GESTURE_HUM, GESTURE_ROLE:
			CharacterFactory.set_expression(model, "senang")
		GESTURE_DOZE:
			CharacterFactory.set_expression(model, "ngantuk")
			_float_timer = 0.3
		_:
			CharacterFactory.set_expression(model, _base_mood())


func _base_mood() -> String:
	if model != null and model.has_meta("spec"):
		return str((model.get_meta("spec") as Dictionary).get("mood", "netral"))
	return "netral"


func _show_cloth(on: bool) -> void:
	if on and (_cloth == null or not is_instance_valid(_cloth)):
		var arm: Node3D = CharacterFactory.part(model, "ArmR")
		if arm == null:
			return
		_cloth = CharacterFactory.wipe_cloth()
		arm.add_child(_cloth)
	if _cloth != null and is_instance_valid(_cloth):
		_cloth.visible = on


func _show_cup(on: bool) -> void:
	if on and (_cup == null or not is_instance_valid(_cup)):
		_cup = CharacterFactory.tea_cup()
		add_child(_cup)
	if _cup != null and is_instance_valid(_cup):
		_cup.visible = on


func _show_coin(on: bool) -> void:
	if on and (_coin == null or not is_instance_valid(_coin)):
		_coin = CharacterFactory.toss_coin()
		add_child(_coin)
	if _coin != null and is_instance_valid(_coin):
		_coin.visible = on


## Titik telapak tangan `arm_name` di dunia (ujung lengan).
func _hand_world(arm_name: String) -> Vector3:
	var arm: Node3D = CharacterFactory.part(model, arm_name) if model != null else null
	if arm == null or not arm.is_inside_tree():
		return global_position + Vector3(0.0, 0.4, 0.0)
	return arm.global_transform * Vector3(0.0, -CharacterFactory.ARM_LENGTH - 0.02, 0.0)


## Arah hadap karakter di dunia (wajahnya menghadap -Z lokal).
func _forward() -> Vector3:
	return (global_basis * Vector3(0.0, 0.0, -1.0)).normalized()


## Cangkir tetap tegak di tangan kanan dan miring ke mulut saat diseruput;
## koin berputar melambung di atas telapak (GDD 31.6).
func _update_props() -> void:
	if model == null or not is_inside_tree():
		return
	var k: float = _gesture_progress()
	var yaw := Basis(Vector3.UP, global_rotation.y)
	var s: float = model.scale.y
	# Di depan telapak menurut arah hadap badan (bukan sumbu lengan, yang ikut
	# berputar saat lengan terangkat).
	var front: Vector3 = _forward() * 0.035 * s
	if _cup != null and is_instance_valid(_cup) and _cup.visible:
		var cup_basis: Basis = (yaw * Basis(Vector3.RIGHT, ProceduralAnimationSystem.cup_tilt(k))).scaled(model.scale)
		_cup.global_transform = Transform3D(cup_basis, _hand_world("ArmR") + front - Vector3(0.0, 0.035 * s, 0.0))
	if _coin != null and is_instance_valid(_coin) and _coin.visible:
		var coin_basis: Basis = (yaw * Basis(Vector3.RIGHT, k * TAU * 3.0)).scaled(model.scale)
		var lift: Vector3 = Vector3.UP * ProceduralAnimationSystem.coin_height(k) * s
		_coin.global_transform = Transform3D(coin_basis, _hand_world("ArmR") + front + Vector3(0.0, 0.02 * s, 0.0) + lift)


## Tinggi puncak kepala di ruang ActorView, juga saat duduk (model terangkat).
func _head_y() -> float:
	return (model.position.y if model != null and is_instance_valid(model) else 0.0) + head_top()


## Jenis benda melayang untuk gerakan yang sedang dimainkan, atau "".
func _floater_kind() -> String:
	match _gesture:
		GESTURE_DOZE:
			return "z"
		GESTURE_HUM:
			return "note"
		GESTURE_TEA:
			return "steam" if ProceduralAnimationSystem.tea_hold(_gesture_progress()) > 0.5 else ""
		GESTURE_ROLE:
			return "flour" if _baker else ""
	return ""


## Benda kecil yang melayang dari gerak menganggur: huruf "Z" saat terkantuk,
## not musik saat bersenandung, uap dari cangkir teh, dan debu tepung dari
## celemek. Masing-masing naik, membesar-mengecil, lalu hilang; huruf "Z" hilang
## begitu kantuknya selesai.
func _update_floaters(delta: float) -> void:
	var step: float = 0.0 if PauseManager.is_paused() else delta
	var kind: String = _floater_kind()
	if kind != "" and visible and step > 0.0:
		_float_timer -= step
		var cap: int = Z_MAX if kind == "z" else FLOATER_MAX
		if _float_timer <= 0.0 and _floaters.size() < cap:
			_float_timer = float(FLOAT_EVERY[kind])
			_spawn_floater(kind)
	for i in range(_floaters.size() - 1, -1, -1):
		var f: Node3D = _floaters[i]
		var fk: String = str(f.get_meta("kind"))
		var age: float = float(f.get_meta("age")) + step
		f.set_meta("age", age)
		var k: float = age / float(FLOAT_LIFE[fk])
		if k >= 1.0 or (fk == "z" and _gesture != GESTURE_DOZE):
			f.queue_free()
			_floaters.remove_at(i)
			continue
		var origin: Vector3 = f.get_meta("origin")
		var drift: Vector3 = f.get_meta("drift")
		match fk:
			"z":
				f.position = origin + Vector3(0.10 * k + 0.02 * sin(k * 6.0), 0.30 * k, 0.0)
				f.scale = Vector3.ONE * maxf(sin(PI * k) * (0.7 + 0.5 * k) * Z_SCALE, 0.001)
			"note":
				f.position = origin + Vector3(drift.x * k + 0.025 * sin(k * 9.0), 0.26 * k, 0.0)
				f.scale = Vector3.ONE * maxf(sin(PI * minf(k * 1.4, 1.0)) * float(FLOAT_SCALE[fk]), 0.001)
			"steam":
				f.position = origin + Vector3(0.012 * sin(k * 7.0 + drift.x * 40.0), 0.12 * k, 0.0)
				f.scale = Vector3.ONE * maxf((0.5 + 0.8 * k) * (1.0 - k) * float(FLOAT_SCALE[fk]), 0.001)
			"flour":
				f.position = origin + drift * k + Vector3(0.0, 0.05 * k, 0.0)
				f.scale = Vector3.ONE * maxf((1.0 - k) * float(FLOAT_SCALE[fk]), 0.001)


func _spawn_floater(kind: String) -> void:
	_float_count += 1
	var side: float = 1.0 if _float_count % 2 == 0 else -1.0
	var node: MeshInstance3D
	var origin: Vector3
	var drift := Vector3.ZERO
	match kind:
		"z":
			node = CharacterFactory.sleep_z()
			origin = Vector3(Z_SIDE, _head_y() + Z_GAP, 0.0)
		"note":
			node = CharacterFactory.music_note(_float_count)
			origin = Vector3(0.11 * side, _head_y() + 0.02, 0.0)
			drift = Vector3(0.05 * side, 0.0, 0.0)
		"steam":
			node = CharacterFactory.puff()
			origin = to_local(_cup.global_position) + Vector3(0.0, 0.08 * model.scale.y, 0.0) if _cup != null and is_instance_valid(_cup) else Vector3(0.0, 0.5, -0.1)
			drift = Vector3(0.01 * side, 0.0, 0.0)
		_:
			node = CharacterFactory.puff()
			origin = to_local(_hand_world("ArmR" if side > 0.0 else "ArmL"))
			drift = Vector3(0.06 * side, 0.02, -0.05)
	node.set_meta("kind", kind)
	node.set_meta("age", 0.0)
	node.set_meta("origin", origin)
	node.set_meta("drift", drift)
	add_child(node)
	node.position = origin
	node.scale = Vector3.ONE * 0.001
	_floaters.append(node)


func _clear_idle_fx() -> void:
	for f: Node3D in _floaters:
		if is_instance_valid(f):
			f.queue_free()
	_floaters.clear()
	for prop: Node3D in [_cup, _coin]:
		if prop != null and is_instance_valid(prop):
			prop.queue_free()
	_cup = null
	_coin = null
	_cloth = null
	_gesture = GESTURE_NONE
	_idle_real = 0.0


## Barang bawaan terlihat di depan torso (GDD 4.2, 31.2): "dough", "tray",
## "bag", "package", "bread" (roti lepas di tangan pembeli), atau "" (kosong).
func set_carry(kind: String, recipe_profile: String = "", quality: float = 1.0, count: int = 1) -> void:
	var key: String = _carry_key_for(kind, recipe_profile, count)
	if key == _carry_key:
		return
	_carry_key = key
	_set_carry(kind, recipe_profile, quality, count)


## Kunci barang bawaan: set_carry() yang sama berturut-turut tidak berbuat apa-apa,
## jadi pose lengan tidak direset tiap frame.
static func _carry_key_for(kind: String, recipe_profile: String, count: int) -> String:
	return "%s|%s|%d" % [kind, recipe_profile, count]


func _set_carry(kind: String, recipe_profile: String = "", quality: float = 1.0, count: int = 1) -> void:
	if _carry != null and is_instance_valid(_carry):
		_carry.queue_free()
	_carry = null
	if kind == "":
		_carry_key = _carry_key_for("", "", 1)
		_apply_carry_pose()
		return
	_carry = Node3D.new()
	_carry.name = "Carry"
	add_child(_carry)
	_carry.position = Vector3(0.0, 0.40, -0.22)
	match kind:
		"dough":
			var bowl: Node3D = EquipmentFactory.dough_bowl()
			bowl.position = Vector3(0.0, -0.045, 0.0)
			_carry.add_child(bowl)
		"tray":
			var tray: Node3D = EquipmentFactory.bread_tray(recipe_profile, quality, &"FRESH")
			tray.position = Vector3(0.0, -0.0125, 0.0)
			_carry.add_child(tray)
		"bag":
			var bag: Node3D = BreadFactory.build_paper_bag()
			bag.scale = Vector3(0.8, 0.8, 0.8)
			_carry.add_child(bag)
			_carry.position = Vector3(0.14 * _bag_side(), 0.18, -0.10)
		"package":
			var box := ProceduralMeshFactory.box(Vector3(0.22, 0.16, 0.16), Color(0.749, 0.580, 0.380))
			_carry.add_child(box)
		"bread":
			# Roti yang diambil sendiri dari rak, ditenteng ke kasir (GDD 2 langkah 3).
			var n: int = clampi(count, 1, 3)
			for i2 in n:
				var br: Node3D = BreadFactory.build_cached(recipe_profile, quality, &"FRESH")
				br.scale = Vector3(0.6, 0.6, 0.6)
				br.position = Vector3(-0.06 * float(n - 1) + 0.12 * float(i2), 0.012 * float(i2 % 2), 0.0)
				_carry.add_child(br)
			_carry.position = Vector3(0.0, 0.36, -0.20)
	_apply_carry_pose()


## Kantong kertas dijinjing di tangan kanan, kecuali tangan itu sudah memegang
## tas belanja atau koper bawaan karakter (+1 kanan, -1 kiri).
func _bag_side() -> float:
	if model != null and model.has_meta("spec"):
		var props: PackedStringArray = (model.get_meta("spec") as Dictionary).get("prop", PackedStringArray())
		if props.has("tas_belanja") or props.has("koper"):
			return -1.0
	return 1.0


## Kedua lengan memeluk barang yang dibawa di depan badan; tas kertas dijinjing
## di samping sehingga lengan tetap bebas.
func _apply_carry_pose() -> void:
	if model == null or not is_instance_valid(model):
		return
	var kind: String = _carry_key.get_slice("|", 0)
	ProceduralAnimationSystem.set_carry_pose(model, kind in ["dough", "tray", "package", "bread"])


## Patience bar di atas kepala (GDD 20.8, 58): tanpa angka, berkedip makin cepat.
func set_patience(ratio: float, show: bool, large: bool) -> void:
	if not show:
		if _patience != null:
			_patience.visible = false
		return
	if _patience == null:
		_patience = PatienceBar.new()
		add_child(_patience)
		_patience.position = Vector3(0.0, PATIENCE_Y, 0.0)
	_patience.visible = true
	_patience.set_ratio(ratio, large)


## Balon "!" di atas pembeli terdepan yang menunggu diketuk (GDD 2 langkah 4).
func set_alert(on: bool) -> void:
	if not on:
		if _bubble != null:
			_bubble.hide_marker()
		return
	if _bubble == null:
		_bubble = StationMarker.new()
		add_child(_bubble)
		_bubble.position = Vector3(0.0, BUBBLE_Y, 0.0)
	_bubble.show_alert()


## Balon pikiran (GDD 7): jam pasir saat antre lama, koin saat harga mahal.
func set_thought(text: String) -> void:
	if text == "":
		if _thought != null:
			_thought.visible = false
		return
	if _thought == null:
		_thought = Label3D.new()
		_thought.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_thought.no_depth_test = true
		_thought.font_size = 56
		_thought.pixel_size = 0.004
		_thought.outline_size = 10
		_thought.outline_modulate = Palette.FLOUR_WHITE
		_thought.modulate = Palette.TEXT
		add_child(_thought)
		_thought.position = Vector3(0.22, 1.02, 0.0)
	_thought.visible = true
	_thought.text = text


func react_happy() -> void:
	if model != null:
		CharacterFactory.set_expression(model, "senang")
		if not SettingsManager.reduced_motion():
			ProceduralAnimationSystem.happy_jump(model)


func react_sad() -> void:
	if model != null:
		CharacterFactory.set_expression(model, "sedih")
		if not SettingsManager.reduced_motion():
			ProceduralAnimationSystem.sad_shake(model)


## Bintang semangat Mode Solo di atas karakter pemain (GDD 3.0.C).
func sparkle() -> void:
	if SettingsManager.reduced_motion():
		return
	FX.sugar_sparkle(self, Vector3(0.0, 1.0, 0.0))


## Widget bar patience berbasis mesh unshaded, diputar menghadap kamera.
class PatienceBar extends Node3D:
	const W: float = 0.40
	const H: float = 0.055
	var _fill: MeshInstance3D = null
	var _mat: StandardMaterial3D = null
	var _ratio: float = 1.0
	var _t: float = 0.0
	var _large: bool = false

	func _ready() -> void:
		var bg := _quad(Vector2(W + 0.03, H + 0.03), Palette.DARK_CHOCOLATE)
		bg.name = "Back"
		add_child(bg)
		_fill = _quad(Vector2(W, H), Palette.SUCCESS)
		_fill.name = "Fill"
		_fill.position = Vector3(0.0, 0.0, 0.004)
		_mat = _fill.material_override as StandardMaterial3D
		# Kedua lapis tembus tanpa uji kedalaman, jadi urutan gambarnya ditentukan
		# pengurutan objek tembus. Kamera ortografis mengurutkan menurut sudut
		# kotak pembatas yang terdekat; latar yang sedikit lebih besar selalu
		# terhitung "lebih dekat", digambar terakhir, dan menutupi isinya (bug
		# 2026-10-01: bar tampak cokelat diam). Prioritas render memaksa isinya
		# selalu di atas latar.
		_mat.render_priority = 1
		add_child(_fill)

	func fill_ratio() -> float:
		return _fill.scale.x if _fill != null else -1.0

	func set_ratio(r: float, large: bool) -> void:
		_ratio = clampf(r, 0.0, 1.0)
		_large = large

	func _process(delta: float) -> void:
		if not visible or _fill == null:
			return
		_t += delta
		var cam: Camera3D = get_viewport().get_camera_3d()
		if cam != null:
			var tr: Transform3D = global_transform
			tr.basis = cam.global_transform.basis
			global_transform = tr
		var s: float = 1.45 if _large else 1.0
		scale = Vector3(s, s, s)
		_fill.scale = Vector3(maxf(_ratio, 0.001), 1.0, 1.0)
		_fill.position.x = -W * 0.5 + W * _ratio * 0.5
		# >60% tenang, 30-60% waspada, 10-30% kedip pelan, <10% kedip cepat (GDD 58).
		var c: Color = Palette.SUCCESS
		var blink_hz: float = 0.0
		if _ratio <= 0.6:
			c = Palette.WARNING
		if _ratio <= 0.3:
			c = Palette.WARMER_LAMP
			blink_hz = 1.2
		if _ratio <= 0.1:
			c = Palette.DANGER
			blink_hz = 4.0
		var a: float = 1.0
		if blink_hz > 0.0 and not SettingsManager.reduced_motion():
			a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_t * TAU * blink_hz))
		_mat.albedo_color = Color(c, a)
		_mat.emission = c

	func _quad(size: Vector2, color: Color) -> MeshInstance3D:
		var mesh := BoxMesh.new()
		mesh.size = Vector3(size.x, size.y, 0.006)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.4
		mat.no_depth_test = true
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		return mi
