class_name BreadArt
extends Control
## Gambar roti & kue 2D untuk Buku Resep (keputusan maintainer 2026-10-04,
## GDD 7, 130.6). Satu gambar per `visual_profile_id` resep, senada dengan roti
## 3D di rak (BreadFactory): bentuk, warna kulit panggang, dan toppingnya sama.
##
## Gayanya flat seperti potret chibi: bidang warna polos tanpa garis tepi,
## bayangan, kilap, atau gradasi. Roti duduk di atas alas renda (doily) pastel
## hangat yang warnanya mengikuti rasa resepnya. Gambar besar mendapat dua garis
## aroma yang mengepul, tanda roti baru keluar dari oven.
##
## Bentuk dirancang sekali per profil di ruang satuan [-0.5 .. 0.5] (y ke bawah)
## menjadi daftar primitif polos (lihat [method shapes]), lalu diskalakan ke
## `art_size` saat digambar. Tanpa gambar, tekstur, atau SubViewport.

const POLY: StringName = &"poly"
const CIRCLE: StringName = &"circle"
const LINE: StringName = &"line"

## Profil yang punya gambar sendiri; profil lain jatuh ke bun polos.
const PROFILES: Array[String] = [
	"loaf.plain", "loaf.pullapart", "bun.fried", "bun.chocolate", "bun.cheese",
	"bun.sausage", "bun.truffle", "bun.basque", "donut.sugar", "donut.jam",
	"baguette", "croissant.classic", "croissant.almond", "croissant.luxury",
	"croissant.pain", "roll.cinnamon", "pastry.cheese", "pastry.cream_cheese",
	"brioche.gourmet", "brioche.matcha", "boule", "crepes", "signature",
]

## Warna alas renda per rasa (lihat [method _accent]).
const BUTTER: StringName = &"butter"
const PEACH: StringName = &"peach"
const BERRY: StringName = &"berry"
const MINT: StringName = &"mint"
const LAVENDER: StringName = &"lavender"
const GOLD: StringName = &"gold"
const PLATE_TINT: Dictionary = {
	"loaf.plain": BUTTER, "loaf.pullapart": LAVENDER, "bun.fried": BUTTER,
	"bun.chocolate": PEACH, "bun.cheese": BUTTER, "bun.sausage": PEACH,
	"bun.truffle": LAVENDER, "bun.basque": PEACH, "donut.sugar": BERRY,
	"donut.jam": BERRY, "baguette": LAVENDER, "croissant.classic": PEACH,
	"croissant.almond": MINT, "croissant.luxury": BERRY, "croissant.pain": PEACH,
	"roll.cinnamon": PEACH, "pastry.cheese": BUTTER, "pastry.cream_cheese": BERRY,
	"brioche.gourmet": BUTTER, "brioche.matcha": MINT, "boule": LAVENDER,
	"crepes": BUTTER, "signature": GOLD,
}

## Gambar sebesar ini (piksel) ke atas mendapat garis aroma.
const AROMA_MIN_SIZE: float = 64.0
## Jumlah lengkung renda di tepi alas.
const SCALLOPS: int = 16

## Taburan donat gula: [x, y, sudut] dalam ruang satuan.
const SPRINKLES: Array = [
	[-0.22, -0.02, 0.6], [-0.16, -0.10, -0.5], [-0.05, -0.13, 0.2], [0.07, -0.12, -0.7],
	[0.18, -0.08, 0.4], [0.24, 0.02, -0.3], [0.16, 0.09, 0.8], [0.04, 0.11, -0.2],
	[-0.09, 0.10, 0.5], [-0.20, 0.07, -0.6],
]

## Daftar primitif per "profil|aroma" (dibangun sekali, dipakai semua gambar).
static var _cache: Dictionary = {}

## `visual_profile_id` resep yang digambar.
var profile: String = "":
	set(value):
		profile = value
		queue_redraw()

## Sisi bujur sangkar gambar (piksel); ikut menyetel `custom_minimum_size`.
var art_size: float = 48.0:
	set(value):
		art_size = maxf(value, 8.0)
		custom_minimum_size = Vector2(art_size, art_size)
		queue_redraw()


func _init() -> void:
	custom_minimum_size = Vector2(art_size, art_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER


## Gambar resep `recipe_id` (profil dari katalog resep) sebesar `px` piksel.
static func for_recipe(recipe_id: StringName, px: float) -> BreadArt:
	var art := BreadArt.new()
	art.name = "BreadArt"
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	art.profile = String(r.visual_profile_id) if r != null else ""
	art.art_size = px
	return art


## true bila profil `p` punya gambar sendiri (bukan cadangan bun polos).
static func has_art(p: String) -> bool:
	return PROFILES.has(p)


static func clear_cache() -> void:
	_cache.clear()


func _draw() -> void:
	var s: float = art_size
	var c: Vector2 = size * 0.5 if size.x > 0.0 and size.y > 0.0 else Vector2(s, s) * 0.5
	for op: Dictionary in shapes(profile, s >= AROMA_MIN_SIZE):
		var col: Color = op["c"]
		match op["t"]:
			POLY:
				var src: PackedVector2Array = op["pts"]
				var pts := PackedVector2Array()
				pts.resize(src.size())
				for i in src.size():
					pts[i] = c + src[i] * s
				draw_colored_polygon(pts, col)
				# Tepi halus: garis 1 px sewarna isiannya, bukan garis tepi.
				pts.append(pts[0])
				draw_polyline(pts, col, 1.0, true)
			CIRCLE:
				draw_circle(c + (op["p"] as Vector2) * s, float(op["r"]) * s, col, true, -1.0, true)
			LINE:
				var src2: PackedVector2Array = op["pts"]
				var w: float = maxf(float(op["w"]) * s, 1.0)
				var pts2 := PackedVector2Array()
				pts2.resize(src2.size())
				for i in src2.size():
					pts2[i] = c + src2[i] * s
				draw_polyline(pts2, col, w, true)
				# Ujung membulat (kesan empuk, GDD 4.1).
				draw_circle(pts2[0], w * 0.5, col, true, -1.0, true)
				draw_circle(pts2[pts2.size() - 1], w * 0.5, col, true, -1.0, true)


## Primitif gambar profil `p` dalam ruang satuan, urut dari belakang ke depan:
## {t: POLY, pts, c} | {t: CIRCLE, p, r, c} | {t: LINE, pts, w, c}. Setiap
## primitif satu warna polos (GDD 130.6: tanpa gradasi).
static func shapes(p: String, aroma: bool = false) -> Array:
	var key: String = "%s|%d" % [p, int(aroma)]
	if not _cache.has(key):
		_cache[key] = _build(p, aroma)
	return _cache[key]


static func _build(p: String, aroma: bool) -> Array:
	var sk := Sketch.new()
	var tint: Color = _accent(p)
	var k: Dictionary = _tones(p)
	k["plate"] = _plate(sk, tint)
	var start: int = sk.ops.size()
	match p:
		"loaf.plain":
			_loaf(sk, k)
		"loaf.pullapart":
			_pullapart(sk, k)
		"bun.fried":
			_fried(sk, k)
		"bun.chocolate":
			_chocolate(sk, k)
		"bun.cheese":
			_cheese_bun(sk, k)
		"bun.sausage":
			_sausage(sk, k)
		"bun.truffle":
			_truffle(sk, k)
		"bun.basque":
			_basque(sk, k)
		"donut.sugar":
			_donut(sk, k, false)
		"donut.jam":
			_donut(sk, k, true)
		"baguette":
			_baguette(sk, k)
		"croissant.classic":
			_croissant(sk, k, "")
		"croissant.almond":
			_croissant(sk, k, "almond")
		"croissant.luxury":
			_croissant(sk, k, "luxury")
		"croissant.pain":
			_pain(sk, k)
		"roll.cinnamon":
			_cinnamon(sk, k)
		"pastry.cheese":
			_danish(sk, k, false)
		"pastry.cream_cheese":
			_danish(sk, k, true)
		"brioche.gourmet":
			_brioche(sk, k, false)
		"brioche.matcha":
			_brioche(sk, k, true)
		"boule":
			_boule(sk, k)
		"crepes":
			_crepes(sk, k)
		"signature":
			_signature(sk, k)
		_:
			_bun(sk, k)
	if not aroma:
		return sk.ops
	# Uap naik dari BALIK roti: disisipkan di antara alas dan roti.
	var steam := Sketch.new()
	_aroma(steam, tint, _top_of(sk.ops.slice(start)))
	return sk.ops.slice(0, start) + steam.ops + sk.ops.slice(start)


# ---------------------------------------------------------------------------
# Warna
# ---------------------------------------------------------------------------

## Warna alas renda: pastel hangat dari Palette, mengikuti rasa resepnya.
static func _accent(p: String) -> Color:
	match PLATE_TINT.get(p, BUTTER):
		PEACH:
			return Palette.PASTEL_STRAWBERRY.lerp(Palette.BUTTER_YELLOW, 0.5)
		BERRY:
			return Palette.PASTEL_STRAWBERRY
		MINT:
			return Palette.PASTEL_MINT
		LAVENDER:
			return Palette.PASTEL_PERIWINKLE
		GOLD:
			return Palette.BUTTER_YELLOW.lerp(Palette.GOLD_STAR, 0.35)
	return Palette.BUTTER_YELLOW


## Warna kulit matang sempurna profil ini (geser panggang sama dengan roti 3D,
## BreadFactory.BAKE_BIAS) beserta turunannya.
static func _tones(p: String) -> Dictionary:
	var crust: Color = BreadFactory.bake_color(Palette.BAKE_PERFECT_T + float(BreadFactory.BAKE_BIAS.get(p, 0.0)))
	return {
		"crust": crust,
		"deep": crust.darkened(0.22),
		"crumb": Palette.VANILLA_CREAM.lerp(Palette.FLOUR_WHITE, 0.35),
		"pale": Palette.RAW_DOUGH.lerp(crust, 0.25),
		"choco": Palette.DARK_CHOCOLATE,
		"cream": Palette.VANILLA_CREAM.lerp(Palette.FLOUR_WHITE, 0.55),
		"jam": Palette.PASTEL_STRAWBERRY.lerp(Palette.DANGER, 0.55),
		# Hijau matcha 2D dibuat lebih segar dari versi 3D supaya tidak kusam.
		"matcha": Palette.MATCHA.lerp(Palette.BUTTER_YELLOW, 0.25),
	}


# ---------------------------------------------------------------------------
# Alas & aroma
# ---------------------------------------------------------------------------

## Alas renda: cakram bertepi lengkung warna rasa, bagian dalam lebih terang.
## Mengembalikan warna bagian dalam (dipakai lubang donat).
static func _plate(sk: Sketch, tint: Color) -> Color:
	var inner: Color = tint.lerp(Palette.FLOUR_WHITE, 0.55)
	sk.circle(Vector2.ZERO, 0.43, tint)
	for i in SCALLOPS:
		var a: float = TAU * float(i) / float(SCALLOPS)
		sk.circle(Vector2(cos(a), sin(a)) * 0.43, 0.058, tint)
	sk.circle(Vector2.ZERO, 0.37, inner)
	return inner


## Dua garis uap bergelombang yang naik dari puncak roti `top` (hanya gambar
## besar).
static func _aroma(sk: Sketch, tint: Color, top: float) -> void:
	var col: Color = tint.darkened(0.16)
	var y1: float = top + 0.04
	var y0: float = maxf(top - 0.13, -0.43)
	for x: float in [-0.09, 0.08]:
		var pts := PackedVector2Array()
		for i in 13:
			var f: float = float(i) / 12.0
			pts.append(Vector2(x + sin(f * TAU * 1.2 + (PI if x > 0.0 else 0.0)) * 0.026, lerpf(y0, y1, f)))
		sk.line(pts, 0.024, col)


## Titik tertinggi (y terkecil) dari sekumpulan primitif.
static func _top_of(ops: Array) -> float:
	var top: float = 0.0
	for op: Dictionary in ops:
		match op["t"]:
			POLY:
				for v: Vector2 in (op["pts"] as PackedVector2Array):
					top = minf(top, v.y)
			CIRCLE:
				top = minf(top, (op["p"] as Vector2).y - float(op["r"]))
			LINE:
				for v2: Vector2 in (op["pts"] as PackedVector2Array):
					top = minf(top, v2.y - float(op["w"]) * 0.5)
	return top


# ---------------------------------------------------------------------------
# Roti per profil (ruang satuan, y ke bawah; alas roti sekitar y = 0,24)
# ---------------------------------------------------------------------------

## Bun polos: alas kulit gelap di bawah kubah kulit.
static func _bun_body(sk: Sketch, rx: float, ry: float, top: Color) -> void:
	sk.ell(Vector2(0.0, 0.07), rx, ry * 0.92, top.darkened(0.22))
	sk.ell(Vector2(0.0, 0.01), rx * 0.985, ry, top)


static func _bun(sk: Sketch, k: Dictionary) -> void:
	_bun_body(sk, 0.31, 0.19, k["crust"])


## Roti Tawar (GDD 5.3.1): loaf 3/4 seperti emoji roti, muka potongnya berremah
## krem di depan.
static func _loaf(sk: Sketch, k: Dictionary) -> void:
	var front: PackedVector2Array = _tomb(-0.31, 0.09, -0.15, 0.0, 0.25)
	var all: PackedVector2Array = front.duplicate()
	all.append_array(_moved(front, Vector2(0.21, -0.12)))
	sk.poly(_hull(all), k["crust"])
	sk.poly(front, k["deep"])
	var crumb: Color = k["crumb"]
	sk.poly(_tomb(-0.275, 0.055, -0.115, 0.0, 0.215), crumb)
	for d: Vector3 in [Vector3(-0.17, 0.08, 0.014), Vector3(-0.07, 0.15, 0.011), Vector3(-0.04, 0.03, 0.010), Vector3(-0.20, 0.17, 0.009)]:
		sk.circle(Vector2(d.x, d.y), d.z, crumb.darkened(0.08))


## Roti Sobek Susu (GDD 5.3.3): dua baris tiga gundukan dalam loyang, bergaris
## sobekan pucat.
static func _pullapart(sk: Sketch, k: Dictionary) -> void:
	var crust: Color = k["crust"]
	sk.rrect(-0.34, 0.0, 0.68, 0.24, 0.07, k["deep"])
	for i in 3:
		sk.ell(Vector2((float(i) - 1.0) * 0.20, -0.08), 0.115, 0.10, crust.darkened(0.10))
	for i in 3:
		sk.ell(Vector2((float(i) - 1.0) * 0.22, 0.05), 0.13, 0.12, crust)
	for j in 2:
		var xs: float = (float(j) * 2.0 - 1.0) * 0.11
		sk.bar(Vector2(xs, 0.0), Vector2(xs, 0.11), 0.016, k["pale"])


## Roti Goreng (GDD 5.3.1): bun dengan sabuk pucat bekas garis minyak.
static func _fried(sk: Sketch, k: Dictionary) -> void:
	sk.ell(Vector2(0.0, 0.10), 0.31, 0.14, k["deep"])
	sk.ell(Vector2(0.0, 0.065), 0.315, 0.13, (k["crust"] as Color).lerp(Palette.RAW_DOUGH, 0.55))
	sk.ell(Vector2(0.0, -0.02), 0.30, 0.18, k["crust"])


## Roti Cokelat (GDD 5.3.2): cokelat mengintip di puncak dan drizzle zig-zag.
static func _chocolate(sk: Sketch, k: Dictionary) -> void:
	_bun_body(sk, 0.31, 0.19, k["crust"])
	var choco: Color = k["choco"]
	for row: Vector2 in [Vector2(-0.12, 0.15), Vector2(-0.05, 0.22), Vector2(0.02, 0.23)]:
		sk.line(_wave_line(-row.y, row.y, row.x, 0.016, 2.5), 0.024, choco)


## Roti Keju Manis (GDD 5.3.2): parutan cheddar di punggungnya.
static func _cheese_bun(sk: Sketch, k: Dictionary) -> void:
	_bun_body(sk, 0.32, 0.18, k["crust"])
	sk.poly(_wavy(Vector2(0.0, -0.07), 0.20, 0.085, 0.012, 9), Palette.BUTTER_YELLOW)
	var cheddar: Color = Palette.CUSTARD.lerp(Palette.GOLDEN_CRUST, 0.35)
	for s: Vector3 in [Vector3(-0.12, -0.08, 0.5), Vector3(-0.04, -0.11, -0.4), Vector3(0.05, -0.07, 0.35),
			Vector3(0.12, -0.10, -0.5), Vector3(-0.01, -0.03, 0.1)]:
		var d := Vector2(cos(s.z), sin(s.z)) * 0.032
		sk.bar(Vector2(s.x, s.y) - d, Vector2(s.x, s.y) + d, 0.022, cheddar)


## Roti Sosis Gulung (GDD 5.3.2): sosis terbaring diikat tiga jalinan adonan.
static func _sausage(sk: Sketch, k: Dictionary) -> void:
	var crust: Color = k["crust"]
	sk.ell(Vector2(0.0, 0.10), 0.36, 0.13, k["deep"])
	sk.ell(Vector2(0.0, 0.05), 0.355, 0.13, crust)
	sk.capsule(Vector2(-0.27, -0.04), Vector2(0.27, -0.04), 0.068, Palette.CARAMEL.lerp(Palette.DANGER, 0.45))
	for i in 3:
		var x: float = (float(i) - 1.0) * 0.14
		sk.bar(Vector2(x - 0.035, -0.115), Vector2(x + 0.035, 0.035), 0.05, crust)


## Truffle Artisan Bun (GDD 5.3.5): topi jamur gandum gelap berkaki rendah,
## bergurat silang dan bertabur serpihan truffle.
static func _truffle(sk: Sketch, k: Dictionary) -> void:
	var crust: Color = k["crust"]
	var wheat: Color = crust.lerp(Palette.DARK_CHOCOLATE, 0.32)
	sk.rrect(-0.20, 0.03, 0.40, 0.20, 0.06, crust)
	sk.ell(Vector2(0.0, 0.06), 0.34, 0.06, wheat.darkened(0.30))
	sk.poly(_dome(Vector2(0.0, 0.06), 0.34, 0.30), wheat)
	var score: Color = Palette.RAW_DOUGH
	sk.line(_arc(Vector2(0.0, 0.07), 0.21, 0.14, PI * 1.12, PI * 1.88), 0.022, score)
	sk.bar(Vector2(0.0, -0.20), Vector2(0.0, 0.02), 0.022, score)
	var flake: Color = Palette.BURNT_BLACK.lerp(Palette.DARK_CHOCOLATE, 0.45)
	for f: Vector3 in [Vector3(-0.16, -0.12, 0.5), Vector3(0.13, -0.15, -0.4), Vector3(-0.10, -0.01, -0.2), Vector3(0.18, -0.02, 0.6)]:
		sk.ell(Vector2(f.x, f.y), 0.032, 0.018, flake, f.z)


## Basque Burnt Cheese Bun (GDD 5.3.4): rok bergelombang, puncak karamel gosong,
## cream cheese mengintip.
static func _basque(sk: Sketch, k: Dictionary) -> void:
	var body: Color = k["crust"]
	sk.poly(_wavy(Vector2(0.0, 0.13), 0.35, 0.11, 0.01, 20), BreadFactory.bake_color(Palette.BAKE_PERFECT_T))
	sk.ell(Vector2(0.0, 0.07), 0.30, 0.15, body.darkened(0.18))
	sk.ell(Vector2(0.0, 0.0), 0.30, 0.17, body)
	sk.poly(_wavy(Vector2(0.0, -0.035), 0.25, 0.125, 0.012, 7), BreadFactory.bake_color(Palette.BAKE_PERFECT_T + 0.32))
	sk.poly(_lens(Vector2(-0.09, -0.06), Vector2(0.11, -0.10), 0.032), k["cream"])


## Donat (GDD 5.3.1-5.3.2): "gula" bertabur sprinkles warna-warni, "selai"
## berglazur stroberi meleleh dengan bekas suntikan selai.
static func _donut(sk: Sketch, k: Dictionary, jam: bool) -> void:
	sk.ell(Vector2(0.0, 0.07), 0.34, 0.19, k["deep"])
	sk.ell(Vector2(0.0, 0.01), 0.34, 0.19, k["crust"])
	if jam:
		var glaze: Color = k["jam"]
		sk.poly(_drippy(Vector2(0.0, -0.005), 0.30, 0.155), glaze)
		sk.ell(Vector2(0.25, 0.165), 0.032, 0.02, glaze.darkened(0.25))
	else:
		var cols: Array[Color] = [Palette.STRAWBERRY, Palette.BUTTER_YELLOW, Palette.PASTEL_MINT.darkened(0.12),
			Palette.FLOUR_WHITE, Palette.PASTEL_PERIWINKLE.darkened(0.10)]
		for i in SPRINKLES.size():
			var sp: Array = SPRINKLES[i]
			var d := Vector2(cos(float(sp[2])), sin(float(sp[2]))) * 0.026
			var at := Vector2(float(sp[0]), float(sp[1]))
			sk.bar(at - d, at + d, 0.022, cols[i % cols.size()])
	# Lubang: dinding dalam, lalu alas yang terlihat menembus lubangnya.
	sk.ell(Vector2(0.0, -0.005), 0.10, 0.055, k["deep"])
	sk.ell(Vector2(0.0, -0.02), 0.095, 0.042, k["plate"])


## Baguette Klasik (GDD 5.3.2): batang panjang miring dengan empat sayatan.
static func _baguette(sk: Sketch, k: Dictionary) -> void:
	var a := Vector2(-0.29, 0.16)
	var b := Vector2(0.29, -0.15)
	var down := Vector2(0.0, 0.035)
	sk.capsule(a + down, b + down, 0.095, k["deep"])
	sk.capsule(a, b, 0.095, k["crust"])
	var ang: float = (b - a).angle()
	for i in 4:
		sk.ell(a.lerp(b, 0.2 + 0.2 * float(i)), 0.066, 0.022, k["pale"], ang + 0.62)


## Croissant: lima cuping di busur bulan sabit, ujungnya lebih matang.
## "almond" bertabur irisan almond & gula halus, "luxury" ditambah suntikan
## cream cheese dan serpih emas (GDD 5.3.4-5.3.5).
static func _croissant(sk: Sketch, k: Dictionary, variant: String) -> void:
	var crust: Color = k["crust"]
	var hub := Vector2(0.0, 0.28)
	var arm: float = 0.30
	var spread: Array[float] = [0.0, 0.50, 0.92]
	var radial: Array[float] = [0.17, 0.14, 0.09]
	var tangential: Array[float] = [0.12, 0.10, 0.075]
	for ring: int in [2, 1, 0]:
		for side: float in ([0.0] if ring == 0 else [-1.0, 1.0]):
			var th: float = -PI * 0.5 + side * spread[ring]
			sk.ell(hub + Vector2(cos(th), sin(th)) * arm, radial[ring], tangential[ring],
				crust.darkened(0.10) if ring == 2 else crust, th)
	# Garis lipatan melengkung ke arah cuping tengah, di batas antarcuping.
	for side2: float in [-1.0, 1.0]:
		for b in 2:
			var phi: float = -PI * 0.5 + side2 * (spread[b] + spread[b + 1]) * 0.5
			var toward := Vector2(-sin(phi), cos(phi)) * -side2
			var seam := PackedVector2Array()
			for i in 7:
				var f: float = float(i) / 6.0
				var r: float = lerpf(arm - radial[b + 1] * 0.8, arm + radial[b + 1] * 0.8, f)
				seam.append(hub + Vector2(cos(phi), sin(phi)) * r + toward * sin(f * PI) * 0.03)
			sk.line(seam, 0.016, k["deep"])
	if variant == "":
		return
	var flake: Color = Palette.VANILLA_CREAM
	for f: Vector3 in [Vector3(-0.17, 0.0, 0.7), Vector3(-0.08, -0.08, -0.3), Vector3(0.0, -0.02, 0.4),
			Vector3(0.08, -0.09, 0.9), Vector3(0.16, -0.01, -0.5)]:
		sk.ell(Vector2(f.x, f.y), 0.036, 0.014, flake, f.z)
	if variant == "almond":
		for d: Vector2 in [Vector2(-0.12, -0.05), Vector2(-0.03, -0.10), Vector2(0.05, -0.04), Vector2(0.12, -0.06)]:
			sk.circle(d, 0.011, Palette.FLOUR_WHITE)
		return
	var cream: Color = k["cream"]
	for x: float in [-0.13, 0.0, 0.13]:
		var y: float = -0.06 if x == 0.0 else -0.02
		sk.circle(Vector2(x, y), 0.034, cream)
		sk.circle(Vector2(x, y - 0.035), 0.02, cream)
	sk.poly(PackedVector2Array([Vector2(0.06, -0.15), Vector2(0.085, -0.125), Vector2(0.06, -0.10), Vector2(0.035, -0.125)]), Palette.GOLD_STAR)


## Pain au Chocolat (GDD 5.3.3): billet persegi berlapis, ujung dua batang
## cokelat mengintip di kedua sisi.
static func _pain(sk: Sketch, k: Dictionary) -> void:
	var choco: Color = k["choco"]
	for x: float in [-0.37, 0.25]:
		sk.rrect(x, -0.04, 0.12, 0.055, 0.02, choco)
		sk.rrect(x, 0.05, 0.12, 0.055, 0.02, choco)
	sk.rrect(-0.31, -0.07, 0.62, 0.27, 0.08, k["deep"])
	sk.rrect(-0.31, -0.12, 0.62, 0.25, 0.08, k["crust"])
	for x: float in [-0.15, 0.0, 0.15]:
		sk.bar(Vector2(x - 0.035, -0.08), Vector2(x + 0.035, 0.09), 0.018, k["deep"])


## Cinnamon Roll (GDD 5.3.3): silinder pendek berpusaran kayu manis, disiram
## glazur putih.
static func _cinnamon(sk: Sketch, k: Dictionary) -> void:
	var deep: Color = k["deep"]
	sk.ell(Vector2(0.0, 0.10), 0.32, 0.15, deep)
	sk.rrect(-0.32, -0.02, 0.64, 0.12, 0.0, deep)
	sk.ell(Vector2(0.0, -0.02), 0.32, 0.16, k["crust"])
	var swirl := PackedVector2Array()
	for i in 49:
		var f: float = float(i) / 48.0
		var th: float = f * 2.2 * TAU + 0.5
		var r: float = 0.025 + f * 0.25
		swirl.append(Vector2(cos(th) * r, -0.02 + sin(th) * r * 0.5))
	sk.line(swirl, 0.03, Palette.CARAMEL.lerp(Palette.DARK_CHOCOLATE, 0.40))
	for row: Vector2 in [Vector2(-0.08, 0.21), Vector2(0.02, 0.24)]:
		sk.line(_wave_line(-row.y, row.y, row.x, 0.03, 2.0), 0.026, Palette.FLOUR_WHITE)


## Danish: alas laminasi persegi (tampak 3/4) bersudut terlipat dan isian di
## tengah. Keju cheddar (GDD 5.3.3), atau cream cheese + selai + almond
## (GDD 5.3.5).
static func _danish(sk: Sketch, k: Dictionary, cream_cheese: bool) -> void:
	var deep: Color = k["deep"]
	var tips: Array[Vector2] = [Vector2(-0.34, 0.06), Vector2(0.0, -0.13), Vector2(0.34, 0.06), Vector2(0.0, 0.25)]
	var ctr := Vector2(0.0, 0.06)
	sk.poly(_round_poly(_moved(PackedVector2Array(tips), Vector2(0.0, 0.035)), 0.05), deep)
	sk.poly(_round_poly(PackedVector2Array(tips), 0.05), k["crust"])
	for t: Vector2 in tips:
		sk.bar(ctr + (t - ctr) * 0.80, ctr + (t - ctr) * 0.58, 0.018, deep)
	if cream_cheese:
		sk.poly(_wavy(Vector2(0.0, 0.05), 0.145, 0.08, 0.01, 8), k["cream"])
		sk.poly(_heart(Vector2(0.0, 0.045), 0.055), k["jam"])
		for f: Vector3 in [Vector3(-0.20, 0.06, 0.4), Vector3(0.20, 0.06, -0.4), Vector3(-0.06, -0.06, -0.6), Vector3(0.07, 0.17, 0.5)]:
			sk.ell(Vector2(f.x, f.y), 0.032, 0.013, Palette.VANILLA_CREAM, f.z)
		return
	sk.ell(Vector2(0.0, 0.05), 0.14, 0.075, Palette.CUSTARD)
	for i in 2:
		var y: float = 0.03 + 0.04 * float(i)
		sk.bar(Vector2(-0.06, y), Vector2(0.05, y - 0.02), 0.018, Palette.BUTTER_YELLOW)


## Brioche (GDD 5.3.4): alas beralur, badan kubah, dan topknot. "gourmet"
## bertabur gula mutiara; "matcha" berkulit hijau dengan salib glazur putih.
static func _brioche(sk: Sketch, k: Dictionary, matcha: bool) -> void:
	var crust: Color = k["crust"]
	if matcha:
		crust = crust.lerp(k["matcha"], 0.85)
	var deep: Color = crust.darkened(0.22)
	sk.ell(Vector2(0.0, 0.12), 0.29, 0.10, deep)
	for i in 7:
		var ph: float = lerpf(0.12, 0.88, float(i) / 6.0) * PI
		sk.circle(Vector2(cos(ph) * 0.25, 0.13 + sin(ph) * 0.07), 0.065, deep)
	sk.ell(Vector2(0.0, 0.01), 0.27, 0.16, crust)
	sk.ell(Vector2(0.0, -0.14), 0.085, 0.04, deep)
	sk.circle(Vector2(0.0, -0.20), 0.085, crust)
	var white: Color = Palette.FLOUR_WHITE
	if matcha:
		sk.line(_arc(Vector2(0.0, -0.20), 0.07, 0.03, PI * 1.05, PI * 1.95), 0.02, white)
		sk.bar(Vector2(0.0, -0.27), Vector2(0.0, -0.14), 0.02, white)
		return
	for d: Vector2 in [Vector2(-0.16, -0.03), Vector2(-0.07, -0.09), Vector2(0.08, -0.08), Vector2(0.17, -0.02), Vector2(0.02, 0.03)]:
		sk.circle(d, 0.015, white)


## Sourdough Whole Wheat (GDD 5.3.4): boule bulat bergurat silang dan bertabur
## tepung.
static func _boule(sk: Sketch, k: Dictionary) -> void:
	var crust: Color = (k["crust"] as Color).lerp(Palette.CARAMEL, 0.30)
	sk.ell(Vector2(0.0, 0.09), 0.34, 0.16, crust.darkened(0.22))
	sk.ell(Vector2(0.0, 0.0), 0.335, 0.21, crust)
	var score: Color = Palette.RAW_DOUGH.lerp(crust, 0.25)
	sk.line(_arc(Vector2(0.0, 0.11), 0.23, 0.17, PI * 1.15, PI * 1.85), 0.042, score)
	sk.bar(Vector2(0.0, -0.17), Vector2(0.0, 0.07), 0.042, score)
	for d: Vector3 in [Vector3(-0.22, -0.09, 0.016), Vector3(-0.12, -0.15, 0.012), Vector3(0.11, -0.14, 0.014),
			Vector3(0.21, -0.07, 0.012), Vector3(-0.18, 0.06, 0.012), Vector3(0.17, 0.07, 0.015)]:
		sk.circle(Vector2(d.x, d.y), d.z, Palette.FLOUR_WHITE)


## Matcha Mille Crepes (GDD 5.3.5): sembilan lapis krem dan hijau matcha,
## puncak bertabur matcha dengan dolop krim.
static func _crepes(sk: Sketch, k: Dictionary) -> void:
	var sheet: Color = Palette.VANILLA_CREAM.lerp(k["crust"], 0.15)
	var matcha: Color = k["matcha"]
	var green: Color = matcha.lerp(Palette.FLOUR_WHITE, 0.35)
	var rx: float = 0.29
	var ry: float = 0.10
	var h: float = 0.033
	var y_bot: float = 0.15
	for i in 9:
		var y0: float = y_bot - h * float(i)
		var col: Color = sheet if i % 2 == 0 else green
		sk.ell(Vector2(0.0, y0), rx, ry, col)
		sk.rrect(-rx, y0 - h, rx * 2.0, h + 0.002, 0.0, col)
	var top: float = y_bot - h * 9.0
	sk.ell(Vector2(0.0, top), rx, ry, matcha)
	var cream: Color = Palette.FLOUR_WHITE
	sk.ell(Vector2(0.0, top - 0.02), 0.075, 0.045, cream)
	sk.circle(Vector2(0.0, top - 0.065), 0.04, cream)
	sk.circle(Vector2(0.0, top - 0.10), 0.02, cream)
	sk.circle(Vector2(-0.025, top - 0.035), 0.009, matcha)
	sk.circle(Vector2(0.02, top - 0.07), 0.008, matcha)


## Roti Emas Artisan (GDD 5.3.5): kubah emas bermahkota, guratan bintang,
## mutiara emas, dan bunga edible di puncaknya.
static func _signature(sk: Sketch, k: Dictionary) -> void:
	var gold: Color = (k["crust"] as Color).lerp(Palette.GOLD_STAR, 0.55)
	var gold_deep: Color = gold.lerp(Palette.CARAMEL, 0.35)
	var bright: Color = Palette.GOLD_STAR.lerp(Palette.BUTTER_YELLOW, 0.35)
	sk.ell(Vector2(0.0, 0.12), 0.34, 0.12, gold_deep)
	for i in 7:
		var ph: float = lerpf(0.10, 0.90, float(i) / 6.0) * PI
		sk.circle(Vector2(cos(ph) * 0.31, 0.13 + sin(ph) * 0.095), 0.022, bright)
	sk.ell(Vector2(0.0, 0.0), 0.30, 0.19, gold)
	var star := Vector2(0.0, -0.05)
	for i in 3:
		var a: float = PI / 3.0 * float(i)
		var d := Vector2(cos(a) * 0.15, sin(a) * 0.15 * 0.55)
		sk.bar(star - d, star + d, 0.022, bright)
	for d2: Vector2 in [Vector2(-0.19, -0.03), Vector2(0.19, -0.03), Vector2(-0.10, 0.08), Vector2(0.10, 0.08)]:
		sk.circle(d2, 0.02, bright)
	var bloom := Vector2(0.0, -0.17)
	for i in 5:
		var a2: float = TAU * float(i) / 5.0 - PI * 0.5
		sk.ell(bloom + Vector2(cos(a2), sin(a2) * 0.7) * 0.035, 0.032, 0.022, Palette.PASTEL_STRAWBERRY, a2)
	sk.circle(bloom, 0.022, Palette.BUTTER_YELLOW)


# ---------------------------------------------------------------------------
# Titik-titik bentuk (ruang satuan)
# ---------------------------------------------------------------------------

static func ellipse(p: Vector2, rx: float, ry: float, rot: float = 0.0, n: int = 36) -> PackedVector2Array:
	var out := PackedVector2Array()
	var cr: float = cos(rot)
	var sr: float = sin(rot)
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var v := Vector2(cos(a) * rx, sin(a) * ry)
		out.append(p + Vector2(v.x * cr - v.y * sr, v.x * sr + v.y * cr))
	return out


## Busur elips terbuka dari sudut a0 ke a1 (untuk garis).
static func _arc(p: Vector2, rx: float, ry: float, a0: float, a1: float, n: int = 16) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a: float = lerpf(a0, a1, float(i) / float(n))
		out.append(p + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Separuh atas elips (kubah) yang ditutup garis datar di bawahnya.
static func _dome(p: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var a: float = PI + PI * float(i) / float(n)
		out.append(p + Vector2(cos(a) * rx, sin(a) * ry))
	return out


## Siluet irisan roti tawar: kubah setengah elips di atas badan persegi yang
## sudut bawahnya membulat.
static func _tomb(x0: float, x1: float, top: float, shoulder: float, bottom: float) -> PackedVector2Array:
	var out: PackedVector2Array = _dome(Vector2((x0 + x1) * 0.5, shoulder), (x1 - x0) * 0.5, shoulder - top, 20)
	var rc: float = minf(0.045, (bottom - shoulder) * 0.5)
	for i in 4:
		var a: float = PI * 0.5 * float(i) / 3.0
		out.append(Vector2(x1 - rc + cos(a) * rc, bottom - rc + sin(a) * rc))
	for i in 4:
		var a2: float = PI * 0.5 + PI * 0.5 * float(i) / 3.0
		out.append(Vector2(x0 + rc + cos(a2) * rc, bottom - rc + sin(a2) * rc))
	return out


## Persegi panjang bersudut membulat (x, y = pojok kiri atas).
static func _round_rect(x: float, y: float, w: float, h: float, r: float) -> PackedVector2Array:
	var out := PackedVector2Array()
	var rr: float = clampf(r, 0.0, minf(w, h) * 0.5)
	if rr <= 0.0001:
		return PackedVector2Array([Vector2(x, y), Vector2(x + w, y), Vector2(x + w, y + h), Vector2(x, y + h)])
	var cx: Array[float] = [x + w - rr, x + w - rr, x + rr, x + rr]
	var cy: Array[float] = [y + rr, y + h - rr, y + h - rr, y + rr]
	for i in 4:
		var base: float = -PI * 0.5 + PI * 0.5 * float(i)
		for j in 5:
			var a: float = base + PI * 0.5 * float(j) / 4.0
			var v := Vector2(cx[i] + cos(a) * rr, cy[i] + sin(a) * rr)
			if out.is_empty() or not out[out.size() - 1].is_equal_approx(v):
				out.append(v)
	if out.size() > 1 and out[0].is_equal_approx(out[out.size() - 1]):
		out.resize(out.size() - 1)
	return out


## Kapsul (stadion) di antara dua titik pusat berjari-jari r.
static func _stadium(a: Vector2, b: Vector2, r: float, n: int = 12) -> PackedVector2Array:
	var out := PackedVector2Array()
	var ang: float = (b - a).angle()
	for i in n + 1:
		var t: float = ang - PI * 0.5 + PI * float(i) / float(n)
		out.append(b + Vector2(cos(t), sin(t)) * r)
	for i in n + 1:
		var t2: float = ang + PI * 0.5 + PI * float(i) / float(n)
		out.append(a + Vector2(cos(t2), sin(t2)) * r)
	return out


## Elips bertepi bergelombang (parutan keju, rok kertas).
static func _wavy(p: Vector2, rx: float, ry: float, amp: float, waves: int, n: int = 64) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var k: float = 1.0 + amp / maxf(ry, 0.001) * sin(a * float(waves))
		out.append(p + Vector2(cos(a) * rx * k, sin(a) * ry * k))
	return out


## Garis bergelombang mendatar dari x0 ke x1 di ketinggian y, sedikit
## melengkung mengikuti kubah roti (drizzle, glazur).
static func _wave_line(x0: float, x1: float, y: float, amp: float, periods: float, n: int = 24) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n + 1:
		var f: float = float(i) / float(n)
		var u: float = f * 2.0 - 1.0
		out.append(Vector2(lerpf(x0, x1, f), y + sin(f * TAU * periods) * amp + (1.0 - u * u) * 0.02))
	return out


## Lensa runcing dari a ke b selebar `w` (retakan, sayatan).
static func _lens(a: Vector2, b: Vector2, w: float, n: int = 10) -> PackedVector2Array:
	var out := PackedVector2Array()
	var d: Vector2 = b - a
	var perp := Vector2(-d.y, d.x).normalized()
	for i in n + 1:
		var f: float = float(i) / float(n)
		out.append(a + d * f + perp * sin(f * PI) * w * 0.5)
	for i in range(n - 1, 0, -1):
		var f2: float = float(i) / float(n)
		out.append(a + d * f2 - perp * sin(f2 * PI) * w * 0.5)
	return out


## Hati montok berpusat di p (selai, GDD 4.1 "cute").
static func _heart(p: Vector2, r: float, n: int = 40) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in n:
		var t: float = TAU * float(i) / float(n)
		var hx: float = 16.0 * pow(sin(t), 3.0)
		var hy: float = 13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t)
		out.append(p + Vector2(hx, -hy) * (r / 16.0))
	return out


## Glazur donat: elips bertepi lembut dengan tiga tetesan di bagian depan.
static func _drippy(p: Vector2, rx: float, ry: float, n: int = 72) -> PackedVector2Array:
	var out := PackedVector2Array()
	var drips: Array[Vector2] = [Vector2(PI * 0.5 - 0.62, 0.05), Vector2(PI * 0.5 + 0.08, 0.075), Vector2(PI * 0.5 + 0.78, 0.045)]
	for i in n:
		var a: float = TAU * float(i) / float(n)
		var k: float = 1.0 + 0.03 * sin(a * 8.0)
		var v := Vector2(cos(a) * rx * k, sin(a) * ry * k)
		for d: Vector2 in drips:
			var off: float = wrapf(a - d.x, -PI, PI)
			v.y += d.y * exp(-pow(off / 0.13, 2.0))
		out.append(p + v)
	return out


## Poligon yang setiap sudutnya dibulatkan dengan lengkung kuadrat sepanjang r.
static func _round_poly(pts: PackedVector2Array, r: float, steps: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n: int = pts.size()
	for i in n:
		var prev: Vector2 = pts[(i + n - 1) % n]
		var cur: Vector2 = pts[i]
		var nxt: Vector2 = pts[(i + 1) % n]
		var a: Vector2 = cur + (prev - cur).normalized() * minf(r, prev.distance_to(cur) * 0.45)
		var b: Vector2 = cur + (nxt - cur).normalized() * minf(r, nxt.distance_to(cur) * 0.45)
		for j in steps + 1:
			var t: float = float(j) / float(steps)
			out.append(a.lerp(cur, t).lerp(cur.lerp(b, t), t))
	return out


static func _moved(pts: PackedVector2Array, d: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v: Vector2 in pts:
		out.append(v + d)
	return out


static func _hull(pts: PackedVector2Array) -> PackedVector2Array:
	var h: PackedVector2Array = Geometry2D.convex_hull(pts)
	if h.size() > 1 and h[0].is_equal_approx(h[h.size() - 1]):
		h.resize(h.size() - 1)
	return h


## Penampung primitif satu gambar (ruang satuan).
class Sketch:
	var ops: Array = []

	func poly(pts: PackedVector2Array, col: Color) -> void:
		if pts.size() >= 3:
			ops.append({"t": BreadArt.POLY, "pts": pts, "c": col})

	func circle(p: Vector2, r: float, col: Color) -> void:
		ops.append({"t": BreadArt.CIRCLE, "p": p, "r": r, "c": col})

	func line(pts: PackedVector2Array, w: float, col: Color) -> void:
		if pts.size() >= 2:
			ops.append({"t": BreadArt.LINE, "pts": pts, "w": w, "c": col})

	func bar(a: Vector2, b: Vector2, w: float, col: Color) -> void:
		line(PackedVector2Array([a, b]), w, col)

	func ell(p: Vector2, rx: float, ry: float, col: Color, rot: float = 0.0) -> void:
		poly(BreadArt.ellipse(p, rx, ry, rot), col)

	func rrect(x: float, y: float, w: float, h: float, r: float, col: Color) -> void:
		poly(BreadArt._round_rect(x, y, w, h, r), col)

	func capsule(a: Vector2, b: Vector2, r: float, col: Color) -> void:
		poly(BreadArt._stadium(a, b, r), col)
