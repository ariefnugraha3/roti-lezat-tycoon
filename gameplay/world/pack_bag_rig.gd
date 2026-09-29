class_name PackBagRig
extends Node3D
## Kantong kertas di meja kasir selama fase membungkus (GDD 21.4). Membaca
## progres fase `p` (0..1) dan batas babak yang sama dengan pose kasir
## (ProceduralAnimationSystem.pack / pack_phases), jadi tangan dan kantong
## selalu sinkron:
##   1. kantong yang masih terlipat disentak terbuka (squash & stretch);
##   2. roti yang diserahkan pembeli melompat satu per satu dari samping kantong
##      ke mulutnya sambil berputar, dan kantong memantul tiap roti masuk;
##   3. roti teratas mengintip, lalu pita dan simpulnya muncul;
##   4. kantong digeser ke arah pembeli dan menunggu di sana sampai dibayar.
## Hanya tampilan: simulasi tidak pernah membaca node ini.

## Skala kantong jadi, sama dengan kantong yang lalu dibawa pembeli.
const BAG_SCALE: float = 0.78
## Tinggi mulut kantong di atas meja (m, pada BAG_SCALE).
const MOUTH_Y: float = 0.17
## Kantong terlipat sebelum dibuka: tinggi relatif dan pelebaran sisinya.
const FOLDED_HEIGHT: float = 0.12
const FOLDED_SPREAD: float = 0.30
## Roti pembeli menunggu di samping kantong, di sisi kiri kasir yang menjauhi
## mesin kasir (lompatannya menyamping, jadi selalu terlihat kamera): jarak ke
## samping, ke arah pembeli, dan antar-roti (m).
const PILE_SIDE: float = 0.13
const PILE_FORWARD: float = 0.02
const PILE_SPACING: float = 0.07
## Skala roti di meja dan saat masuk ke kantong.
const BREAD_SCALE: float = 0.45
const BREAD_SCALE_IN: float = 0.28
## Puncak lengkung lompatan roti di atas garis lurusnya (m) dan pembesaran
## sesaat di puncaknya supaya terbaca dari kamera.
const ARC_HEIGHT: float = 0.17
const APEX_GROW: float = 0.12
## Di dalam jendela satu roti: kapan roti terangkat dan kapan masuk ke kantong.
const LIFT_AT: float = 0.35
const LAND_AT: float = 0.90
## Roti bergoyang sesaat sebelum diangkat (bagian jendela dan sudutnya).
const WIGGLE_SPAN: float = 0.10
const WIGGLE_ANGLE: float = 0.18
## Kantong memantul sesudah tiap roti masuk (lama dalam progres, besar pantulan).
const BOUNCE_SPAN: float = 0.06
const BOUNCE_SQUASH: float = 0.10
## Pita muncul pada bagian ini dari babak mengikat, dengan pop selama POP_SPAN.
const SEAL_POP_AT: float = 0.25
const POP_SPAN: float = 0.06
## Loncatan kecil kantong saat pita diikat dan saat disodorkan (m).
const SEAL_HOP: float = 0.012
const OFFER_HOP: float = 0.010
## Kantong disodorkan sejauh ini ke arah pembeli di babak terakhir (m).
const OFFER_SLIDE: float = 0.07

var count: int = 0
var _toward := Vector3(0.0, 0.0, 1.0)
var _along := Vector3(1.0, 0.0, 0.0)
var _bag: Node3D = null
var _peek_base := Vector3.ONE
var _breads: Array[Node3D] = []
var _last_p: float = -1.0


## `profile` = visual roti pembeli, `n` = jumlah roti yang digambar, `toward` =
## arah datar dari kantong ke pembeli.
func setup(profile: String, n: int, toward: Vector3) -> void:
	count = maxi(n, 1)
	_toward = Vector3(toward.x, 0.0, toward.z).normalized()
	_along = Vector3(_toward.z, 0.0, -_toward.x)
	_bag = BreadFactory.build_paper_bag()
	_bag.name = "Bag"
	add_child(_bag)
	var peek: Node3D = _bag.get_node_or_null("Peek") as Node3D
	if peek != null:
		_peek_base = peek.scale
	for i in count:
		var b: Node3D = BreadFactory.build_cached(profile, 1.0, &"FRESH")
		b.name = "Bread%d" % i
		add_child(b)
		_breads.append(b)
	animate(0.0)
	_last_p = -1.0


## Tempat roti ke-`i` menunggu di samping kantong.
func pile_position(i: int) -> Vector3:
	return _along * PILE_SIDE + _toward * (PILE_FORWARD + PILE_SPACING * (float(i) - float(count - 1) * 0.5))


## Progres saat roti ke-`i` masuk ke kantong.
func land_progress(i: int) -> float:
	var w: Vector2 = ProceduralAnimationSystem.pack_bread_window(i, count)
	return w.x + (w.y - w.x) * LAND_AT


## Progres saat pita muncul.
func seal_progress() -> float:
	var ph: Vector3 = ProceduralAnimationSystem.pack_phases(count)
	return ph.y + (ph.z - ph.y) * SEAL_POP_AT


## Terapkan progres `p`. Mengembalikan event yang terlewati sejak panggilan
## sebelumnya: &"bread_in" tiap roti masuk dan &"sealed" saat pita muncul.
## Panggilan pertama tidak pernah memicu event (kantong yang dibangun ulang di
## tengah fase tidak memutar ulang suaranya).
func animate(p: float) -> Array[StringName]:
	var events: Array[StringName] = []
	var prev: float = _last_p if _last_p >= 0.0 else p
	_last_p = p
	var ph: Vector3 = ProceduralAnimationSystem.pack_phases(count)
	var open_end: float = ph.x
	var seal_end: float = ph.z
	# --- Kantong: dibuka, memantul tiap roti masuk, meloncat saat diikat, disodorkan.
	var sy: float = 1.0
	var sxz: float = 1.0
	var offset := Vector3.ZERO
	if p < open_end:
		var open: float = _ease_out_back(p / open_end)
		sy = lerpf(FOLDED_HEIGHT, 1.0, open)
		sxz = 1.0 + FOLDED_SPREAD * (1.0 - clampf(open, 0.0, 1.0))
	for i in count:
		var land: float = land_progress(i)
		var d: float = (p - land) / BOUNCE_SPAN
		if d >= 0.0 and d < 1.0:
			var sq: float = sin(d * PI) * BOUNCE_SQUASH * (1.0 - d)
			sy *= 1.0 - sq
			sxz *= 1.0 + sq * 0.5
		if prev < land and p >= land:
			events.append(&"bread_in")
	var seal_p: float = seal_progress()
	if prev < seal_p and p >= seal_p:
		events.append(&"sealed")
	if p >= seal_p and p < seal_end:
		offset.y += SEAL_HOP * sin(clampf((p - seal_p) / (seal_end - seal_p), 0.0, 1.0) * PI)
	if p >= seal_end:
		var ko: float = clampf((p - seal_end) / ProceduralAnimationSystem.PACK_OFFER_SPAN, 0.0, 1.0)
		offset += _toward * OFFER_SLIDE * _ease_out_cubic(ko)
		offset.y += OFFER_HOP * sin(ko * PI)
	_bag.scale = Vector3(BAG_SCALE * sxz, BAG_SCALE * sy, BAG_SCALE * sxz)
	_bag.position = offset
	var peek: Node3D = _bag.get_node_or_null("Peek") as Node3D
	if peek != null:
		var peek_p: float = land_progress(count - 1)
		peek.visible = p >= peek_p
		peek.scale = _peek_base * _ease_out_back(clampf((p - peek_p) / POP_SPAN, 0.0, 1.0))
	var seal: Node3D = _bag.get_node_or_null("Seal") as Node3D
	if seal != null:
		seal.visible = p >= seal_p
		seal.scale = Vector3.ONE * _ease_out_back(clampf((p - seal_p) / POP_SPAN, 0.0, 1.0))
	# --- Roti: menunggu di tepi meja, bergoyang saat tangan tiba, melompat ke kantong.
	var mouth := Vector3(0.0, MOUTH_Y, 0.0)
	for i2 in count:
		var b: Node3D = _breads[i2]
		var w: Vector2 = ProceduralAnimationSystem.pack_bread_window(i2, count)
		var k: float = (p - w.x) / (w.y - w.x)
		var start: Vector3 = pile_position(i2)
		if k < LIFT_AT:
			var wig: float = clampf((k - (LIFT_AT - WIGGLE_SPAN)) / WIGGLE_SPAN, 0.0, 1.0)
			b.visible = true
			b.position = start
			b.rotation = Vector3(0.0, 0.0, sin(wig * PI * 2.0) * WIGGLE_ANGLE)
			b.scale = Vector3.ONE * BREAD_SCALE
		elif k < LAND_AT:
			var f: float = (k - LIFT_AT) / (LAND_AT - LIFT_AT)
			var pos: Vector3 = start.lerp(mouth, f)
			pos.y += 4.0 * ARC_HEIGHT * f * (1.0 - f)
			b.visible = true
			b.position = pos
			b.rotation = Vector3(0.0, f * PI, sin(f * PI) * 0.35)
			b.scale = Vector3.ONE * (lerpf(BREAD_SCALE, BREAD_SCALE_IN, f * f) + APEX_GROW * sin(f * PI) * BREAD_SCALE)
		else:
			b.visible = false
	return events


func bag() -> Node3D:
	return _bag


func bread(i: int) -> Node3D:
	return _breads[i] if i >= 0 and i < _breads.size() else null


## 0 -> ~1.1 -> 1: masuk dengan sedikit kelebihan lalu menetap.
static func _ease_out_back(k: float) -> float:
	var c1: float = 1.70158
	var c3: float = c1 + 1.0
	var x: float = clampf(k, 0.0, 1.0) - 1.0
	return 1.0 + c3 * x * x * x + c1 * x * x


static func _ease_out_cubic(k: float) -> float:
	var x: float = 1.0 - clampf(k, 0.0, 1.0)
	return 1.0 - x * x * x
