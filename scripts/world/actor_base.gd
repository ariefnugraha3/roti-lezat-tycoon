class_name ActorBase
extends Node3D
## Dasar bersama untuk semua karakter yang berjalan di dalam toko.
##
## Aktor hanya mengurus GERAK dan TAMPILAN. Keputusan siapa yang dilayani, apa
## yang dibeli, dan kapan pergi adalah urusan lapisan simulasi — aktor cuma
## mengikuti daftar tujuan yang diberikan padanya.
##
## Animasi berjalan memakai gelombang sinus (GDD 4.2), bukan skeleton.

## Kecepatan jalan default dalam satuan dunia per detik.
const WALK_SPEED: float = 1.15
## Jarak yang dianggap "sudah sampai".
const ARRIVE_EPS: float = 0.06
## Kecepatan memutar badan ke arah jalan (radian per detik).
const TURN_SPEED: float = 9.0

signal arrived(tag: String)
signal path_finished()

## Model chibi hasil CharacterFactory.
var model: Node3D = null
## Antrean tujuan: [{pos: Vector3, tag: String, wait: float}]
var waypoints: Array = []
## Pemandu jalan (ShopWorld). Diisi saat aktor lahir. Bila kosong, aktor
## berjalan lurus ke tujuan seperti dulu -- itu yang membuat aktor lepas tetap
## bisa diuji tanpa merakit satu ruangan penuh.
var nav: Object = null
var walk_speed: float = WALK_SPEED
var is_walking: bool = false

var _t: float = 0.0
var _wait_left: float = 0.0
var _spec: Dictionary = {}


## Membangun model dari spec CharacterFactory dan memasangnya sebagai anak.
func build_from_spec(spec: Dictionary) -> void:
	_spec = spec
	if model != null and is_instance_valid(model):
		model.queue_free()
	model = CharacterFactory.build(spec)
	if model != null:
		add_child(model)


func spec() -> Dictionary:
	return _spec


## Menambah satu tujuan. `wait` = detik berdiam setelah sampai.
##
## Rutenya ditanyakan ke `nav` lebih dulu, jadi aktor MENGITARI perabot alih-alih
## menembusnya. Titik singgah tambahan disisipkan tanpa tag: hanya tujuan
## terakhir yang memicu sinyal `arrived`, sehingga seluruh pemanggil goto() yang
## sudah ada tetap menerima tepat satu kabar "sudah sampai" seperti sebelumnya.
func goto(pos: Vector3, tag: String = "", wait: float = 0.0) -> void:
	if nav == null or not is_instance_valid(nav) or not nav.has_method("route"):
		waypoints.append({"pos": pos, "tag": tag, "wait": wait})
		return

	var rute: PackedVector3Array = nav.call("route", _titik_terakhir(), pos)
	if rute.is_empty():
		waypoints.append({"pos": pos, "tag": tag, "wait": wait})
		return
	for i in range(rute.size() - 1):
		waypoints.append({"pos": rute[i], "tag": "", "wait": 0.0})
	waypoints.append({"pos": rute[rute.size() - 1], "tag": tag, "wait": wait})


## Titik pangkal rute berikutnya: ujung antrean yang sudah ada, atau tempat
## aktor berdiri sekarang bila antreannya kosong.
##
## Memakai posisi sekarang untuk rute yang disambung di belakang antrean akan
## menghasilkan jalur yang berangkat dari tempat yang salah.
func _titik_terakhir() -> Vector3:
	if not waypoints.is_empty():
		return (waypoints[waypoints.size() - 1] as Dictionary)["pos"]
	if is_inside_tree():
		return global_position
	return position


## Mengosongkan rute dan langsung berhenti.
func clear_path() -> void:
	waypoints.clear()
	_wait_left = 0.0
	is_walking = false


## Dipanggil setiap frame oleh ShopWorld. Aktor tidak memakai _process sendiri
## agar seluruh dunia bisa ikut di-pause dan di-fast-forward oleh Main.
func tick(delta: float) -> void:
	_t += delta

	if _wait_left > 0.0:
		_wait_left = maxf(0.0, _wait_left - delta)
		_idle(delta)
		return

	if waypoints.is_empty():
		is_walking = false
		_idle(delta)
		return

	var wp: Dictionary = waypoints[0]
	var target: Vector3 = wp["pos"]
	var flat_target := Vector3(target.x, global_position.y, target.z)
	var to_target: Vector3 = flat_target - global_position
	var dist: float = to_target.length()

	if dist <= ARRIVE_EPS:
		global_position = flat_target
		waypoints.pop_front()
		_wait_left = float(wp.get("wait", 0.0))
		is_walking = false
		var tag: String = String(wp.get("tag", ""))
		if tag != "":
			arrived.emit(tag)
		if waypoints.is_empty():
			path_finished.emit()
		return

	var dir: Vector3 = to_target / dist
	var step: float = minf(walk_speed * delta, dist)
	global_position += dir * step
	is_walking = true

	_face(dir, delta)
	if model != null and is_instance_valid(model):
		ProceduralAnimationSystem.walk(model, _t, 7.0)


func _idle(delta: float) -> void:
	if model != null and is_instance_valid(model):
		ProceduralAnimationSystem.idle_bob(model, _t)
	# delta sengaja tidak dipakai di sini; _t sudah dimajukan di tick().
	if delta < 0.0:
		pass


## Memutar badan mulus ke arah jalan.
##
## Wajah karakter dibangun di sisi -Z (CharacterFactory.FRONT), BUKAN +Z. Jadi
## yang harus diarahkan ke tujuan adalah sumbu -Z, dan itu sebabnya kedua
## komponen arah dinegasikan sebelum masuk atan2().
##
## Tanpa negasi itu, atan2(dir.x, dir.z) mengarahkan +Z ke tujuan — punggung
## karakter yang berjalan lebih dulu, dan pemain hanya melihat belakang kepala
## sepanjang permainan.
func _face(dir: Vector3, delta: float) -> void:
	if dir.length_squared() < 0.0001:
		return
	var want: float = atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, TURN_SPEED * delta))


## Menghadapkan badan ke satu titik SEKETIKA, tanpa animasi berputar.
## Dipakai saat menempatkan aktor yang memang sudah berdiri di posnya.
func face_towards(titik: Vector3) -> void:
	var dir := Vector3(titik.x - global_position.x, 0.0, titik.z - global_position.z)
	if dir.length_squared() < 0.0001:
		return
	rotation.y = atan2(-dir.x, -dir.z)


## Reaksi emosional (GDD 4.2 squash & stretch lewat Tween).
func react(mood: String) -> void:
	if model == null or not is_instance_valid(model):
		return
	CharacterFactory.set_expression(model, mood)
	match mood:
		"senang":
			ProceduralAnimationSystem.happy_jump(model)
		"kesal", "sedih":
			ProceduralAnimationSystem.sad_shake(model)


## Menghilang perlahan lalu membebaskan diri.
func leave_and_free(dur: float = 0.4) -> void:
	clear_path()
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.01, 0.01, 0.01), dur) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)
