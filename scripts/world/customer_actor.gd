class_name CustomerActor
extends ActorBase
## Pelanggan fisik yang masuk toko, memilih roti di rak, lalu mengantre di kasir.
##
## Aktor ini adalah CERMIN dari satu entri pelanggan di CustomerSim — ia tidak
## memutuskan apa pun sendiri. Balon pikiran (GDD 7) muncul saat sim melaporkan
## pelanggan mulai kesal.

## Tinggi balon "!" di atas titik kaki pelanggan, meter. Sedikit di atas kepala
## chibi dan sedikit ke samping supaya wajahnya tidak tertutup.
const ALERT_Y: float = 1.05
const ALERT_X: float = 0.16

## Id pelanggan di CustomerSim (kunci `id` pada Dictionary pelanggan).
var customer_id: int = -1
var archetype: String = ""

var _bubble: Node3D = null
var _bubble_kind: String = ""
var _alert: StationMarker = null
var _belanjaan: Node3D = null


func setup_customer(cust: Dictionary, seed_i: int) -> void:
	customer_id = int(cust.get("id", -1))
	archetype = String(cust.get("archetype", "anak_sekolah"))
	build_from_spec(CharacterFactory.spec_for_customer(archetype, seed_i))
	# Emak-emak arisan memborong, jadi jalannya santai; pekerja kantoran buru-buru.
	match archetype:
		"pekerja_kantoran":
			walk_speed = WALK_SPEED * 1.35
		"emak_arisan":
			walk_speed = WALK_SPEED * 0.85
		"sosialita":
			walk_speed = WALK_SPEED * 0.9
		_:
			walk_speed = WALK_SPEED


## Menampilkan balon pikiran keluhan (GDD 7). `kind` dipakai untuk memilih ikon:
## "antrean_lama" -> jam pasir, "harga_mahal" -> uang terbang, "stok_habis" -> kotak.
func show_thought(kind: String) -> void:
	if kind == _bubble_kind:
		return
	_bubble_kind = kind
	_clear_bubble()

	var icon_name: String = "bubble"
	match kind:
		"antrean_lama":
			icon_name = "hourglass"
		"harga_mahal":
			icon_name = "coin"
		"stok_habis":
			icon_name = "box"
		"roti_gosong":
			icon_name = "fire"
		"senang":
			icon_name = "heart"

	_bubble = ProceduralMeshFactory.group("Thought")
	# Awan empuk: tiga bola menumpuk (GDD 4.3 "balon pesanan berbentuk awan empuk").
	var putih: Color = Palette.FLOUR_WHITE
	ProceduralMeshFactory.attach(_bubble,
		ProceduralMeshFactory.sphere(0.085, putih), Vector3(0.0, 0.0, 0.0))
	ProceduralMeshFactory.attach(_bubble,
		ProceduralMeshFactory.sphere(0.060, putih), Vector3(-0.075, -0.020, 0.0))
	ProceduralMeshFactory.attach(_bubble,
		ProceduralMeshFactory.sphere(0.052, putih), Vector3(0.072, -0.015, 0.0))
	ProceduralMeshFactory.attach(_bubble,
		ProceduralMeshFactory.sphere(0.028, putih), Vector3(-0.055, -0.105, 0.0))

	var tint: Color = Palette.TEXT
	if kind == "harga_mahal":
		tint = Palette.GOLD_STAR
	elif kind == "senang":
		tint = Palette.ROSY_CHEEK
	var mark: MeshInstance3D = ProceduralMeshFactory.box(
		Vector3(0.055, 0.055, 0.012), tint)
	ProceduralMeshFactory.attach(_bubble, mark, Vector3(0.0, 0.0, 0.088))
	mark.name = "Mark_" + icon_name

	_bubble.position = Vector3(0.14, 0.78, 0.0)
	add_child(_bubble)

	# Muncul dengan pantulan membal (GDD 7).
	_bubble.scale = Vector3.ZERO
	var tw := create_tween()
	tw.tween_property(_bubble, "scale", Vector3.ONE, 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func hide_thought() -> void:
	_bubble_kind = ""
	_clear_bubble()


func _clear_bubble() -> void:
	if _bubble != null and is_instance_valid(_bubble):
		_bubble.queue_free()
	_bubble = null


# ===========================================================================
# BELANJAAN DI TANGAN
# ===========================================================================

## Menampilkan / menyembunyikan roti yang sudah diambil pembeli dari rak.
##
## Pembeli mengambil rotinya SENDIRI di depan rak lalu membawanya ke kasir
## (GDD 2), jadi sejak itu tangannya memang tidak lagi kosong. Tanpa isyarat
## ini pemain tidak punya cara melihat siapa yang sudah selesai memilih dan
## siapa yang masih melihat-lihat.
##
## Ditempel ke `Body` supaya ikut mengayun saat badan berjalan, dan dibangun
## dari kotak seperti bawaan lain — bukan model terpisah (GDD 12.2).
func set_belanjaan(ada: bool) -> void:
	if ada == (_belanjaan != null and is_instance_valid(_belanjaan)):
		return
	if not ada:
		if _belanjaan != null and is_instance_valid(_belanjaan):
			_belanjaan.queue_free()
		_belanjaan = null
		return
	var badan: Node3D = CharacterFactory.part(model, "Body")
	if badan == null:
		return
	_belanjaan = ProceduralMeshFactory.group("Belanjaan")
	# Kantong kertas cokelat muda dengan roti mengintip dari bibirnya.
	ProceduralMeshFactory.attach(_belanjaan, ProceduralMeshFactory.box(
		Vector3(0.115, 0.130, 0.080), Palette.CARAMEL.lightened(0.28)),
		Vector3(0.0, 0.0, 0.0))
	ProceduralMeshFactory.attach(_belanjaan, ProceduralMeshFactory.box(
		Vector3(0.125, 0.026, 0.088), Palette.CARAMEL.lightened(0.42)),
		Vector3(0.0, 0.072, 0.0))
	ProceduralMeshFactory.attach(_belanjaan, ProceduralMeshFactory.sphere(
		0.036, Palette.GOLDEN_CRUST), Vector3(0.0, 0.098, 0.0))
	_belanjaan.position = Vector3(0.0, 0.085, CharacterFactory.FRONT * 0.150)
	badan.add_child(_belanjaan)

	# Muncul dengan pantulan kecil: roti baru saja berpindah ke tangannya.
	ProceduralAnimationSystem.squash_pop(_belanjaan, 1.12, 0.20)


func has_belanjaan() -> bool:
	return _belanjaan != null and is_instance_valid(_belanjaan)


# ===========================================================================
# BALON "!" — PEMBELI MENUNGGU DILAYANI
# ===========================================================================

## Menampilkan balon tanda seru: pembeli ini sudah berdiri di meja kasir
## sambil menenteng belanjaannya dan menunggu pemain mengetuknya (GDD 2).
##
## Memakai StationMarker yang sama dengan perabot dapur, bukan balon pikiran di
## atas: tanda seru adalah PERINTAH "ketuk aku", sementara balon pikiran adalah
## keluhan. Bentuk yang sama untuk perintah yang sama membuat pemain tidak perlu
## belajar dua bahasa isyarat.
func show_alert() -> void:
	if _alert != null and is_instance_valid(_alert):
		if _alert.mode != StationMarker.MODE_ALERT:
			_alert.show_alert()
		return
	_alert = StationMarker.new()
	_alert.name = "AlertPembeli"
	_alert.position = Vector3(ALERT_X, ALERT_Y, 0.0)
	add_child(_alert)
	_alert.show_alert()


func hide_alert() -> void:
	if _alert == null or not is_instance_valid(_alert):
		return
	_alert.hide_marker()


## Apakah balon "!"-nya sedang tampil. Dipakai ShopWorld untuk memutuskan
## pelanggan mana yang boleh menangkap ketukan layar.
func has_alert() -> bool:
	return _alert != null and is_instance_valid(_alert) \
		and _alert.mode == StationMarker.MODE_ALERT


## Pelanggan puas: melompat gembira lalu pergi.
func serve_happy() -> void:
	hide_alert()
	hide_thought()
	react("senang")
	FX.sugar_sparkle(self, Vector3(0.0, 0.55, 0.0))


## Pelanggan kabur karena kecewa (GDD 9.1 menurunkan rating).
func leave_angry(reason: String) -> void:
	hide_alert()
	show_thought(reason)
	react("kesal")
	FX.sweat_drop(self)
