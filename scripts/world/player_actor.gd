class_name PlayerActor
extends ActorBase
## Karakter yang dimainkan pemain (GDD 2: pemain sendiri yang mengambil bahan
## dari gudang, mengoperasikan alat, dan menata roti ke rak).
##
## Aktor ini SENGAJA tidak memutuskan apa pun. Ia hanya tahu tiga hal:
##   1. berjalan ke sebuah titik lalu melapor sudah sampai,
##   2. sedang membawa apa (tangan kosong / mangkuk adonan / loyang roti),
##   3. berdiri di mana saat menganggur.
##
## Urutan tugas, alat mana yang harus dituju, dan kapan prosesnya dimulai adalah
## urusan PlayerTaskSystem. Pemisahan itu yang membuat seluruh alur produksi bisa
## diuji headless tanpa pernah menggambar satu pun mesh.

## Apa yang sedang dibawa karakter.
const CARRY_NONE: String = ""
const CARRY_DOUGH: String = "mangkuk_adonan"
const CARRY_TRAY: String = "loyang_roti"

## Pemain berjalan sedikit lebih cepat dari pelanggan: ia yang ditunggu, bukan
## sebaliknya, dan ritme dapur langsung terasa lamban kalau ia selambat mereka.
const PLAYER_WALK_SPEED: float = 1.45

## Jarak berdiri di depan sebuah perabot, meter. Cukup dekat untuk terbaca
## "sedang mengoperasikan", cukup jauh untuk tidak tertanam di dalam badannya.
const STAND_OFFSET: float = 0.52

## Karakter sampai di satu tujuan bertag. Diteruskan dari ActorBase agar
## PlayerTaskSystem tidak perlu mengenal ActorBase sama sekali.
signal task_arrived(tag: String)

## Titik berdiri saat tidak ada tugas.
var idle_pos: Vector3 = Vector3.ZERO

var _carry: String = CARRY_NONE
var _busy_t: float = 0.0
var _working: bool = false


func setup_player(gender: String) -> void:
	build_from_spec(CharacterFactory.spec_for_player(gender))
	walk_speed = PLAYER_WALK_SPEED
	if not arrived.is_connected(_on_arrived):
		arrived.connect(_on_arrived)


func _on_arrived(tag: String) -> void:
	task_arrived.emit(tag)


# ===========================================================================
# BAWAAN TANGAN
# ===========================================================================

## Mengganti barang bawaan. String kosong = tangan kosong.
##
## Model dibangun ulang, bukan ditambah-tempel: props CharacterFactory dipasang
## sebagai anak `Body` saat perakitan, dan menyisipkannya belakangan berarti
## menduplikasi setengah logika pabrik di sini.
func set_carry(what: String) -> void:
	if _carry == what:
		return
	_carry = what
	var spec: Dictionary = CharacterFactory.spec_for_player(GameState.player_gender())
	if what != CARRY_NONE:
		spec["prop"] = PackedStringArray([what])
	build_from_spec(spec)


func carrying() -> String:
	return _carry


func is_carrying() -> bool:
	return _carry != CARRY_NONE


# ===========================================================================
# BERJALAN & BEKERJA
# ===========================================================================

## Titik berdiri di depan satu perabot, dihitung MURNI GEOMETRIS.
##
## Ini hanya cadangan untuk aktor yang berdiri di luar ruangan ber-kisi: titik
## berdiri yang sesungguhnya ditanyakan ke ShopWorld.stand_spot(), karena hanya
## dunia yang tahu petak mana yang terhalang meja kasir atau perabot lain.
## Pergeseran buta seperti di sini pernah mendaratkan karakter di atas meja
## kasir setiap kali ia menghampiri rak display.
func stand_spot(titik: Vector3) -> Vector3:
	var dari: Vector3 = idle_pos if idle_pos != Vector3.ZERO else global_position
	var arah: Vector3 = Vector3(dari.x - titik.x, 0.0, dari.z - titik.z)
	if arah.length_squared() < 0.0004:
		arah = Vector3(0.0, 0.0, 1.0)
	return titik + arah.normalized() * STAND_OFFSET


## Pulang ke titik menganggur.
func go_idle() -> void:
	if idle_pos != Vector3.ZERO:
		goto(idle_pos, "idle", 0.0)


## Menandai karakter sedang mengoperasikan alat: badannya bergoyang kecil di
## tempat, seperti orang yang sedang menguleni.
func set_working(v: bool) -> void:
	_working = v
	if model != null and is_instance_valid(model):
		CharacterFactory.set_expression(model, "senang" if v else "netral")


func is_working() -> bool:
	return _working


func tick(delta: float) -> void:
	super.tick(delta)
	if not _working or is_walking:
		return
	_busy_t += delta
	if model == null or not is_instance_valid(model):
		return
	# Goyangan kerja: gelombang sinus pada lengan, bukan rig (GDD 12.3).
	for nama in ["ArmL", "ArmR"]:
		var lengan: Node3D = CharacterFactory.part(model, nama)
		if lengan != null:
			lengan.rotation.x = sin(_busy_t * 7.5) * 0.55
