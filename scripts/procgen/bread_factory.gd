class_name BreadFactory
extends RefCounted

## Pabrik mesh roti & pastry prosedural (GDD 4.2 "Varian Roti & Pastry",
## GDD 5.3.1 - 5.3.5).
##
## Ke-23 resep kanonik (ARCHITECTURE.md 2.2) dirakit MURNI dari mesh primitif
## bawaan Godot -- BoxMesh, SphereMesh, CylinderMesh, TorusMesh, CapsuleMesh --
## tanpa satu pun aset eksternal. Jumlah segmen setiap primitif selalu diisi
## eksplisit dengan angka rendah (bawaan Godot jauh terlalu tinggi) supaya satu
## roti tetap di bawah ~600 segitiga: ratusan roti bisa berdiri berbarengan di
## rak display, dan target kita adalah renderer Compatibility / WebGL 2 pada
## ponsel Android kelas bawah (GDD 12.2).
##
## Kematangan HANYA mengubah material, tidak pernah mengubah geometri:
##     quality_shade(quality) -> t   lalu   bake_color(t) -> warna kulit roti.
##
## Sumbu: roti dibangun berdiri di atas bidang Y = 0, satuan meter. Lebar roti
## biasa +- 0,17 m, loaf +- 0,26 m, baguette +- 0,40 m.
##
## CATATAN KONTRAK: file ini sengaja tidak memanggil ProceduralMeshFactory.
## API pabrik itu (`sphere(r, color, rough)`, `torus(inner, outer, color)`)
## tidak menyediakan parameter jumlah segmen, sedangkan budget segitiga di atas
## menuntut segmen rendah yang eksplisit. Helper privat `_box` / `_sphere` /
## `_cylinder` / `_torus` / `_capsule` di bawah adalah pembungkus tipis yang
## setara dengan tambahan parameter segmen.


# ---------------------------------------------------------------------------
# Tabel kualitas
# ---------------------------------------------------------------------------

## Posisi t pada kurva panggang untuk enam string kualitas kanonik
## (ARCHITECTURE.md 2.5): 0 = adonan pucat, 0,6 = keemasan sempurna, 1 = gosong.
const QUALITY_T: Dictionary = {
	"mentah": 0.05,
	"prima": 0.60,
	"normal": 0.52,
	"dingin": 0.44,
	"hampir_gosong": 0.84,
	"gosong": 1.00,
}

## Kekasaran permukaan per kualitas. Roti prima mengkilap karena olesan mentega
## (GDD 5.3.3 langkah "Finishing"), roti dingin kusam, roti gosong berjelaga.
## Ini membuat "prima" dan "normal" tetap terbaca beda walau warnanya berdekatan.
const QUALITY_ROUGHNESS: Dictionary = {
	"mentah": 0.95,
	"prima": 0.42,
	"normal": 0.70,
	"dingin": 0.94,
	"hampir_gosong": 0.66,
	"gosong": 0.52,
}

## Beberapa resep memang tampil lebih gelap / lebih pucat dari standar walau
## kualitasnya sama. Nilai ini digeser ke t sebelum masuk bake_color().
const BAKE_BIAS: Dictionary = {
	"roti_tawar_polos": -0.06,
	"roti_goreng_polos": -0.04,
	"roti_sobek_susu": -0.05,
	"matcha_mille_crepes": -0.10,
	"truffle_mushroom_bun": 0.06,
	"sourdough_whole_wheat": 0.08,
	"basque_burnt_cheese_bun": 0.16,
}

## Nilai t cadangan bila string kualitas tidak dikenali.
const FALLBACK_T: float = 0.55

## Cache material: ratusan roti di satu rak harus berbagi StandardMaterial3D
## yang sama agar perubahan state GPU tetap sedikit. Material tidak pernah
## diubah setelah dibuat, jadi aman dipakai bersama.
static var _material_cache: Dictionary = {}


# ---------------------------------------------------------------------------
# API publik (ARCHITECTURE.md 8 - BreadFactory)
# ---------------------------------------------------------------------------

## Bangun satu roti utuh untuk `recipe_id` dengan tampilan kematangan
## `quality`. Selalu mengembalikan Node3D; id tak dikenal jatuh ke bun polos.
static func build(recipe_id: String, quality: String) -> Node3D:
	var t: float = clampf(quality_shade(quality) + float(BAKE_BIAS.get(recipe_id, 0.0)), 0.0, 1.0)
	var ctx: Dictionary = {
		"crust": bake_color(t),
		"rough": float(QUALITY_ROUGHNESS.get(quality, 0.78)),
		"t": t,
	}
	var root: Node3D = Node3D.new()
	root.name = "Bread_" + recipe_id

	match recipe_id:
		# --- Keluarga loaf: adonan tinggi mengembang berpunggung kubah ---
		"roti_tawar_polos":
			_build_loaf(root, ctx, "tawar")
		"roti_sobek_susu":
			_build_loaf(root, ctx, "sobek")
		# --- Keluarga bun: bola gepeng + detail isian ---
		"roti_goreng_polos":
			_build_bun(root, ctx, "goreng")
		"roti_cokelat":
			_build_bun(root, ctx, "cokelat")
		"roti_keju_manis":
			_build_bun(root, ctx, "keju")
		"roti_sosis_gulung":
			_build_bun(root, ctx, "sosis")
		"truffle_mushroom_bun":
			_build_bun(root, ctx, "truffle")
		"basque_burnt_cheese_bun":
			_build_bun(root, ctx, "basque")
		# --- Keluarga donat: torus ---
		"donat_gula":
			_build_donut(root, ctx, "gula")
		"donat_selai_stroberi":
			_build_donut(root, ctx, "selai")
		# --- Keluarga baguette ---
		"baguette_klasik":
			_build_baguette(root, ctx)
		# --- Keluarga croissant: busur segmen meruncing ---
		"croissant_klasik":
			_build_croissant(root, ctx, "klasik")
		"croissant_artisan_almond":
			_build_croissant(root, ctx, "almond")
		"almond_croissant_mewah":
			_build_croissant(root, ctx, "mewah")
		"pain_au_chocolat":
			_build_croissant(root, ctx, "pain")
		# --- Keluarga roll spiral ---
		"cinnamon_roll":
			_build_roll(root, ctx)
		# --- Keluarga pastry: alas persegi berlipat + cakram isian ---
		"danish_cheese_pastry":
			_build_pastry(root, ctx, "keju")
		"premium_cream_cheese_danish":
			_build_pastry(root, ctx, "cream_cheese")
		# --- Keluarga brioche: bun beralur dengan topknot ---
		"brioche_gourmet":
			_build_brioche(root, ctx, "gourmet")
		"matcha_sweet_brioche":
			_build_brioche(root, ctx, "matcha")
		# --- Keluarga boule rustic ---
		"sourdough_whole_wheat":
			_build_boule(root, ctx)
		# --- Keluarga crepes bertumpuk ---
		"matcha_mille_crepes":
			_build_crepes(root, ctx)
		# --- Signature ---
		"roti_emas_artisan":
			_build_signature(root, ctx)
		_:
			# Resep tak dikenal: tetap kembalikan roti, jangan pernah null.
			_build_bun(root, ctx, "goreng")

	root.set_meta("recipe_id", recipe_id)
	root.set_meta("quality", quality)
	root.set_meta("bake_t", t)
	_disable_shadows(root)
	return root


## Gradasi warna panggang: t = 0 adonan mentah pucat, t = 0,6 kulit cokelat
## keemasan sempurna, t = 1 hitam gosong berjelaga (GDD 4.2).
static func bake_color(t: float) -> Color:
	return Palette.bake_shade(clampf(t, 0.0, 1.0))


## Pemetaan enam string kualitas kanonik ke nilai t untuk bake_color().
static func quality_shade(quality: String) -> float:
	return float(QUALITY_T.get(quality, FALLBACK_T))


## Kemasan RotiFood: kantong kardus cokelat berpita manis (GDD 3.6.A langkah 2).
## Sekitar 290 segitiga.
static func build_paper_bag() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "PaperBag"
	var kraft: Color = _kraft_brown()
	var kraft_dark: Color = kraft.lerp(Palette.CARAMEL, 0.40)
	var ribbon: Color = Palette.PASTEL_STRAWBERRY

	# Badan kantong.
	_place(root, _box(Vector3(0.150, 0.190, 0.085), kraft, 0.92), Vector3(0.0, 0.095, 0.0),
			Vector3.ZERO, Vector3.ONE, "Bag")
	# Lipatan bibir atas.
	_place(root, _box(Vector3(0.157, 0.026, 0.092), kraft_dark, 0.92), Vector3(0.0, 0.203, 0.0))
	# Alas kantong yang sedikit menonjol.
	_place(root, _box(Vector3(0.155, 0.014, 0.090), kraft_dark, 0.92), Vector3(0.0, 0.007, 0.0))
	# Dua garis lipatan (gusset) di muka kantong.
	for s: float in [-1.0, 1.0]:
		_place(root, _box(Vector3(0.005, 0.180, 0.006), kraft_dark, 0.92),
				Vector3(0.052 * s, 0.098, 0.0425))
	# Pita manis melingkar + simpulnya.
	_place(root, _box(Vector3(0.158, 0.022, 0.093), ribbon, 0.55), Vector3(0.0, 0.148, 0.0),
			Vector3.ZERO, Vector3.ONE, "Ribbon")
	for s2: float in [-1.0, 1.0]:
		_place(root, _sphere(0.024, ribbon, 0.55, 8, 2), Vector3(0.030 * s2, 0.150, 0.054),
				Vector3(0.0, 0.0, 28.0 * s2), Vector3(1.0, 0.55, 0.38))
	_place(root, _sphere(0.014, ribbon, 0.50, 8, 2), Vector3(0.0, 0.150, 0.056))
	# Ujung roti hangat mengintip dari mulut kantong.
	_place(root, _sphere(0.045, Palette.GOLDEN_CRUST, 0.62, 10, 3), Vector3(0.0, 0.208, 0.0),
			Vector3.ZERO, Vector3(1.28, 0.70, 0.95), "Peek")
	return root


## Kemasan premium Tier 5: kotak gift box cokelat elegan berpita emas
## (GDD 5.3.5 langkah 5). Sekitar 300 segitiga.
static func build_gift_box() -> Node3D:
	var root: Node3D = Node3D.new()
	root.name = "GiftBox"
	var box_color: Color = Palette.DARK_CHOCOLATE
	var lid_color: Color = Palette.CARAMEL
	var gold: Color = Palette.GOLD_STAR

	# Badan kotak + tutup yang sedikit lebih lebar.
	_place(root, _box(Vector3(0.180, 0.095, 0.180), box_color, 0.60), Vector3(0.0, 0.0475, 0.0),
			Vector3.ZERO, Vector3.ONE, "Box")
	_place(root, _box(Vector3(0.194, 0.030, 0.194), lid_color, 0.55), Vector3(0.0, 0.110, 0.0),
			Vector3.ZERO, Vector3.ONE, "Lid")
	# Pita emas menyilang di atas tutup.
	_place(root, _box(Vector3(0.200, 0.008, 0.026), gold, 0.30), Vector3(0.0, 0.127, 0.0))
	_place(root, _box(Vector3(0.026, 0.008, 0.200), gold, 0.30), Vector3(0.0, 0.127, 0.0))
	# Pita emas turun membungkus badan kotak.
	_place(root, _box(Vector3(0.186, 0.097, 0.026), gold, 0.30), Vector3(0.0, 0.0475, 0.0))
	_place(root, _box(Vector3(0.026, 0.097, 0.186), gold, 0.30), Vector3(0.0, 0.0475, 0.0))
	# Simpul pita: dua daun, dua juntai, satu inti.
	for s: float in [-1.0, 1.0]:
		_place(root, _sphere(0.030, gold, 0.30, 8, 2), Vector3(0.036 * s, 0.140, 0.0),
				Vector3(0.0, 26.0 * s, 0.0), Vector3(1.0, 0.42, 0.55))
		_place(root, _box(Vector3(0.050, 0.006, 0.016), gold, 0.30),
				Vector3(0.040 * s, 0.133, 0.030 * s), Vector3(0.0, 30.0 * s, -10.0 * s))
	_place(root, _sphere(0.016, gold, 0.28, 8, 2), Vector3(0.0, 0.142, 0.0))
	# Medali emas kecil di muka tutup.
	_place(root, _cylinder(0.006, 0.026, 0.026, gold, 0.25, 12), Vector3(0.0, 0.110, 0.099),
			Vector3(90.0, 0.0, 0.0), Vector3.ONE, "Emblem")
	return root


# ---------------------------------------------------------------------------
# Keluarga bentuk
# ---------------------------------------------------------------------------

## Loaf: slab gembur tinggi dengan punggung kubah.
## "tawar" = satu kubah panjang + sisi potong remah pucat (+- 145 tris);
## "sobek" = tiga gundukan menyatu siap disobek (+- 325 tris).
static func _build_loaf(root: Node3D, ctx: Dictionary, variant: String) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]
	var crumb: Color = _shade(Palette.VANILLA_CREAM.lerp(Palette.RAW_DOUGH, 0.45), t)

	if variant == "sobek":
		# Roti Sobek Susu (GDD 5.3.3): dijual per 6 potong, bentuknya pull-apart.
		_place(root, _box(Vector3(0.250, 0.085, 0.130), crust, rough), Vector3(0.0, 0.0425, 0.0),
				Vector3.ZERO, Vector3.ONE, "Crust")
		for i in 3:
			var x: float = (float(i) - 1.0) * 0.070
			_place(root, _sphere(0.058, crust, rough * 0.85, 10, 4), Vector3(x, 0.084, 0.0),
					Vector3.ZERO, Vector3(1.05, 0.95, 1.10))
		# Garis sobekan pucat di antara gundukan.
		for j in 2:
			var xs: float = (float(j) * 2.0 - 1.0) * 0.035
			_place(root, _box(Vector3(0.006, 0.020, 0.126), crumb, 0.92), Vector3(xs, 0.096, 0.0))
		return

	# Roti Tawar Polos (GDD 5.3.1): loaf empuk yang mengembang tebal.
	_place(root, _box(Vector3(0.255, 0.110, 0.140), crust, rough), Vector3(0.0, 0.055, 0.0),
			Vector3.ZERO, Vector3.ONE, "Crust")
	_place(root, _sphere(0.075, crust, rough, 12, 4), Vector3(0.0, 0.110, 0.0),
			Vector3.ZERO, Vector3(1.70, 0.80, 0.93), "Dome")
	# Sisi potong memperlihatkan remah putih gembur.
	_place(root, _box(Vector3(0.007, 0.104, 0.132), crumb, 0.95), Vector3(0.128, 0.054, 0.0))


## Bun: bola gepeng dengan detail isian sesuai resepnya. 180 - 355 tris.
static func _build_bun(root: Node3D, ctx: Dictionary, variant: String) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]

	match variant:
		"goreng":
			# Roti Goreng Polos (GDD 5.3.1): ada sabuk pucat bekas garis minyak.
			_place(root, _sphere(0.078, crust, rough, 12, 4), Vector3(0.0, 0.056, 0.0),
					Vector3.ZERO, Vector3(1.05, 0.74, 1.05), "Crust")
			var belt: Color = _shade(crust.lerp(Palette.RAW_DOUGH, 0.55), t)
			_place(root, _torus(0.060, 0.090, belt, rough, 10, 5), Vector3(0.0, 0.050, 0.0),
					Vector3.ZERO, Vector3(1.0, 0.46, 1.0), "Belt")

		"cokelat":
			# Roti Cokelat (GDD 5.3.2): cokelat batang mengintip + drizzle.
			_place(root, _sphere(0.080, crust, rough, 12, 4), Vector3(0.0, 0.056, 0.0),
					Vector3.ZERO, Vector3(1.02, 0.72, 1.02), "Crust")
			var choco: Color = _shade(Palette.DARK_CHOCOLATE, t)
			_place(root, _sphere(0.030, choco, 0.45, 8, 3), Vector3(0.0, 0.106, 0.0),
					Vector3.ZERO, Vector3(1.10, 0.52, 1.10), "Filling")
			for i in 4:
				_place(root, _box(Vector3(0.130, 0.008, 0.011), choco, 0.45),
						Vector3(0.0, 0.106, 0.0), Vector3(0.0, -48.0 + 32.0 * float(i), 0.0))

		"keju":
			# Roti Keju Manis (GDD 5.3.2): parutan cheddar di punggungnya.
			_place(root, _sphere(0.080, crust, rough, 12, 4), Vector3(0.0, 0.055, 0.0),
					Vector3.ZERO, Vector3(1.14, 0.68, 0.96), "Crust")
			var cheese: Color = _shade(Palette.CUSTARD, t)
			_place(root, _box(Vector3(0.100, 0.011, 0.068), cheese, 0.55), Vector3(0.0, 0.102, 0.0))
			var cheese_hi: Color = cheese.lerp(Palette.BUTTER_YELLOW, 0.50)
			for i in 4:
				var z: float = (float(i) - 1.5) * 0.017
				_place(root, _box(Vector3(0.086, 0.009, 0.010), cheese_hi, 0.50),
						Vector3(0.0, 0.110, z), Vector3(0.0, 6.0 - 4.0 * float(i), 0.0))

		"sosis":
			# Roti Sosis Gulung (GDD 5.3.2): sosis sapi terbaring, diikat tiga
			# jalinan adonan.
			_place(root, _sphere(0.075, crust, rough, 12, 4), Vector3(0.0, 0.050, 0.0),
					Vector3.ZERO, Vector3(1.70, 0.62, 0.98), "Crust")
			var sausage: Color = _shade(_sausage_brown(), t)
			_place(root, _capsule(0.150, 0.026, sausage, 0.55, 8, 2), Vector3(0.0, 0.094, 0.0),
					Vector3(0.0, 0.0, 90.0), Vector3.ONE, "Sausage")
			for i in 3:
				var xs: float = (float(i) - 1.0) * 0.046
				_place(root, _box(Vector3(0.017, 0.016, 0.098), crust, rough), Vector3(xs, 0.098, 0.0))

		"truffle":
			# Truffle Mushroom Artisan Bun (GDD 5.3.5): kubah whole wheat gelap
			# seperti topi jamur, berkaki rendah, bertabur serpihan truffle.
			var wheat: Color = crust.lerp(Palette.DARK_CHOCOLATE, 0.32)
			var stem: Color = crust.lerp(Palette.CARAMEL, 0.25)
			_place(root, _cylinder(0.024, 0.062, 0.056, stem, rough, 10), Vector3(0.0, 0.012, 0.0),
					Vector3.ZERO, Vector3.ONE, "Stem")
			_place(root, _sphere(0.085, wheat, rough, 12, 4), Vector3(0.0, 0.056, 0.0),
					Vector3.ZERO, Vector3(1.02, 0.64, 1.02), "Crust")
			var score: Color = _shade(Palette.RAW_DOUGH, t)
			for i in 2:
				_place(root, _box(Vector3(0.098, 0.007, 0.009), score, 0.90),
						Vector3(0.0, 0.104, 0.0), Vector3(0.0, 90.0 * float(i), 0.0))
			var truffle: Color = _shade(Palette.DARK_CHOCOLATE.lerp(Palette.TEXT, 0.35), t)
			for i in 4:
				var a: float = TAU * float(i) / 4.0 + 0.6
				_place(root, _box(Vector3(0.021, 0.005, 0.013), truffle, 0.35),
						Vector3(cos(a) * 0.040, 0.104, sin(a) * 0.040),
						Vector3(0.0, rad_to_deg(-a), 0.0))

		"basque":
			# Basque Burnt Cheese Bun (GDD 5.3.4): permukaan sengaja hangus
			# karamel, tepi bergelombang, cream cheese mengintip di puncak.
			_place(root, _sphere(0.082, crust, rough, 12, 4), Vector3(0.0, 0.058, 0.0),
					Vector3.ZERO, Vector3(1.02, 0.76, 1.02), "Crust")
			var burnt_top: Color = bake_color(t + 0.16)
			_place(root, _sphere(0.060, burnt_top, rough * 0.80, 10, 3), Vector3(0.0, 0.104, 0.0),
					Vector3.ZERO, Vector3(1.24, 0.50, 1.24), "BurntTop")
			_place(root, _torus(0.060, 0.094, crust, rough, 12, 5), Vector3(0.0, 0.032, 0.0),
					Vector3.ZERO, Vector3(1.0, 0.62, 1.0), "Ruffle")
			_place(root, _cylinder(0.014, 0.022, 0.024, _shade(Palette.VANILLA_CREAM, t), 0.60, 8),
					Vector3(0.0, 0.122, 0.0), Vector3.ZERO, Vector3.ONE, "CreamCheese")

		_:
			_place(root, _sphere(0.080, crust, rough, 12, 4), Vector3(0.0, 0.056, 0.0),
					Vector3.ZERO, Vector3(1.02, 0.72, 1.02), "Crust")


## Donat: torus mendatar. "gula" bertabur sprinkles warna-warni (GDD 4.1),
## "selai" berglazur stroberi dengan bekas suntikan selai. 250 - 330 tris.
static func _build_donut(root: Node3D, ctx: Dictionary, variant: String) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]

	_place(root, _torus(0.032, 0.088, crust, rough, 12, 6), Vector3(0.0, 0.028, 0.0),
			Vector3.ZERO, Vector3.ONE, "Crust")

	if variant == "selai":
		# Donat Selai Stroberi (GDD 5.3.2).
		var jam: Color = _shade(Palette.PASTEL_STRAWBERRY.lerp(Palette.DANGER, 0.55), t)
		_place(root, _torus(0.030, 0.091, jam, 0.45, 12, 5), Vector3(0.0, 0.040, 0.0),
				Vector3.ZERO, Vector3(1.0, 0.55, 1.0), "Glaze")
		# Lubang bekas suntikan selai di sisi donat.
		_place(root, _sphere(0.020, jam.lerp(Palette.DARK_CHOCOLATE, 0.25), 0.40, 8, 3),
				Vector3(0.074, 0.030, 0.0), Vector3.ZERO, Vector3(0.70, 1.0, 1.0), "JamDimple")
		return

	# Donat Gula (GDD 5.3.1): taburan gula warna-warni.
	var sprinkles: Array[Color] = [
		Palette.PASTEL_STRAWBERRY,
		Palette.PASTEL_MINT,
		Palette.PASTEL_PERIWINKLE,
		Palette.BUTTER_YELLOW,
	]
	for i in 9:
		var a: float = TAU * float(i) / 9.0
		var r: float = 0.048 + 0.012 * float(i % 3)
		var col: Color = _shade(sprinkles[i % sprinkles.size()], t)
		_place(root, _box(Vector3(0.014, 0.005, 0.005), col, 0.45),
				Vector3(cos(a) * r, 0.052, sin(a) * r),
				Vector3(0.0, rad_to_deg(-a) + 35.0 * float(i % 2), 0.0))


## Baguette Klasik (GDD 5.3.2): silinder panjang meruncing dengan empat gurat
## sayatan miring. +- 190 tris.
static func _build_baguette(root: Node3D, ctx: Dictionary) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]

	_place(root, _capsule(0.400, 0.048, crust, rough, 10, 2), Vector3(0.0, 0.046, 0.0),
			Vector3(0.0, 0.0, 90.0), Vector3(1.0, 1.0, 0.94), "Crust")
	# Sayatan diagonal memperlihatkan remah pucat yang merekah.
	var score: Color = _shade(Palette.RAW_DOUGH.lerp(crust, 0.30), t)
	for i in 4:
		var x: float = (float(i) - 1.5) * 0.082
		_place(root, _box(Vector3(0.013, 0.012, 0.082), score, 0.90), Vector3(x, 0.082, 0.0),
				Vector3(0.0, 34.0, 0.0))


## Croissant: busur segmen bola yang meruncing ke kedua ujung.
## "klasik" polos, "almond" / "mewah" bertabur irisan almond (GDD 5.3.4 langkah
## 4), "pain" = Pain au Chocolat -- busurnya diluruskan jadi billet persegi
## berisi dua batang cokelat. 265 - 510 tris.
static func _build_croissant(root: Node3D, ctx: Dictionary, variant: String) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]

	var seg_count: int = 7
	var arc: float = deg_to_rad(112.0)
	var arc_radius: float = 0.105
	var seg_radius: float = 0.042
	var taper: float = 0.70
	var seg_scale: Vector3 = Vector3(1.0, 0.82, 1.30)

	if variant == "pain":
		# Pain au Chocolat bukan bulan sabit: bentuk aslinya billet persegi
		# panjang. Busur dinolkan dan segmennya tidak meruncing.
		seg_count = 5
		arc = 0.0
		arc_radius = 0.0
		seg_radius = 0.046
		taper = 0.0
		seg_scale = Vector3(0.66, 0.78, 1.46)

	for i in seg_count:
		var u: float = 0.0
		if seg_count > 1:
			u = float(i) / float(seg_count - 1) * 2.0 - 1.0
		var r: float = seg_radius * (1.0 - taper * pow(absf(u), 1.7))
		var pos: Vector3 = Vector3.ZERO
		var yaw: float = 0.0
		if arc > 0.0:
			var a: float = u * arc * 0.5
			pos = Vector3(arc_radius * sin(a), r * seg_scale.y + 0.004,
					arc_radius * (1.0 - cos(a)))
			yaw = rad_to_deg(-a)
			if absf(u) > 0.8:
				# Ujung bulan sabit sedikit terangkat.
				pos.y += 0.008
		else:
			pos = Vector3(u * 0.074, r * seg_scale.y, 0.0)
		var seg_name: String = ""
		if i == 0:
			seg_name = "Crust"
		_place(root, _sphere(r, crust, rough, 8, 2), pos, Vector3(0.0, yaw, 0.0), seg_scale, seg_name)

	if variant == "pain":
		# Dua batang cokelat membujur, ujungnya mengintip di kedua sisi.
		var choco: Color = _shade(Palette.DARK_CHOCOLATE, t)
		for s: float in [-1.0, 1.0]:
			_place(root, _box(Vector3(0.196, 0.013, 0.013), choco, 0.42),
					Vector3(0.0, 0.030, 0.028 * s))
		return

	if variant == "almond" or variant == "mewah":
		var flake: Color = _shade(Palette.VANILLA_CREAM, t)
		for i in 6:
			var a: float = lerpf(-arc * 0.40, arc * 0.40, float(i) / 5.0)
			_place(root, _box(Vector3(0.023, 0.004, 0.010), flake, 0.55),
					Vector3(arc_radius * sin(a), 0.062, arc_radius * (1.0 - cos(a)) + 0.004),
					Vector3(-16.0, rad_to_deg(-a) + 26.0, 0.0))

	if variant == "mewah":
		# Almond Croissant Mewah (GDD 5.3.5): suntikan cream cheese berlapis.
		var cream: Color = _shade(Palette.VANILLA_CREAM.lerp(Palette.FLOUR_WHITE, 0.50), t)
		for i in 3:
			var a2: float = lerpf(-arc * 0.26, arc * 0.26, float(i) / 2.0)
			_place(root, _cylinder(0.012, 0.019, 0.017, cream, 0.50, 8),
					Vector3(arc_radius * sin(a2), 0.066, arc_radius * (1.0 - cos(a2))),
					Vector3(0.0, rad_to_deg(-a2), 0.0))
	elif variant == "almond":
		# Taburan gula halus di punggung croissant.
		var dust: Color = _shade(Palette.FLOUR_WHITE, t)
		for i in 3:
			_place(root, _box(Vector3(0.040, 0.003, 0.008), dust, 0.95),
					Vector3(-0.030 + 0.030 * float(i), 0.070, 0.010),
					Vector3(0.0, -22.0 + 22.0 * float(i), 0.0))


## Cinnamon Roll (GDD 5.3.3): silinder pendek dengan pusaran kayu manis yang
## dirakit dari tumpukan segmen berputar, lalu disiram glazur putih.
## +- 290 tris.
static func _build_roll(root: Node3D, ctx: Dictionary) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]

	_place(root, _cylinder(0.062, 0.082, 0.076, crust, rough, 12), Vector3(0.0, 0.031, 0.0),
			Vector3.ZERO, Vector3.ONE, "Crust")

	# Pusaran: 16 segmen kecil pada spiral Archimedes, masing-masing diputar
	# mengikuti garis singgung sehingga terbaca sebagai gulungan utuh.
	var cinnamon: Color = _shade(Palette.CARAMEL.lerp(Palette.DARK_CHOCOLATE, 0.40), t)
	var turns: float = 2.1
	var steps: int = 16
	var d_theta: float = turns * TAU / float(steps - 1)
	for i in steps:
		var f: float = float(i) / float(steps - 1)
		var theta: float = f * turns * TAU
		var r: float = 0.013 + f * 0.062
		var chord: float = maxf(0.014, 2.0 * r * sin(d_theta * 0.5) * 1.25)
		_place(root, _box(Vector3(chord, 0.007, 0.011), cinnamon, 0.60),
				Vector3(cos(theta) * r, 0.064, sin(theta) * r),
				Vector3(0.0, rad_to_deg(-theta) + 90.0, 0.0))

	# Glazur gula putih yang meleleh di punggungnya.
	var icing: Color = _shade(Palette.FLOUR_WHITE, t * 0.70)
	for i in 4:
		_place(root, _box(Vector3(0.150, 0.006, 0.013), icing, 0.40),
				Vector3(0.0, 0.069, (float(i) - 1.5) * 0.024),
				Vector3(0.0, -8.0 + 5.0 * float(i), 0.0))


## Pastry Danish: alas persegi berlipat dengan bibir terangkat dan cakram isian
## di tengah. "keju" = Danish Cheese Pastry (GDD 5.3.3), "cream_cheese" =
## Premium Cream Cheese Danish (GDD 5.3.5, tambah selai + irisan almond).
## 185 - 265 tris.
static func _build_pastry(root: Node3D, ctx: Dictionary, variant: String) -> void:
	var crust: Color = ctx["crust"]
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]

	# Alas adonan laminasi.
	_place(root, _box(Vector3(0.152, 0.026, 0.152), crust, rough), Vector3(0.0, 0.013, 0.0),
			Vector3.ZERO, Vector3.ONE, "Crust")
	# Empat bibir lipatan yang terangkat.
	for s: float in [-1.0, 1.0]:
		_place(root, _box(Vector3(0.152, 0.024, 0.030), crust, rough), Vector3(0.0, 0.032, 0.061 * s))
		_place(root, _box(Vector3(0.030, 0.024, 0.152), crust, rough), Vector3(0.061 * s, 0.032, 0.0))
	# Empat sudut yang dipuntir.
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + PI * 0.25
		_place(root, _box(Vector3(0.036, 0.022, 0.036), crust, rough),
				Vector3(cos(a) * 0.062, 0.038, sin(a) * 0.062), Vector3(0.0, 45.0, 0.0))

	if variant == "cream_cheese":
		var cream: Color = _shade(Palette.VANILLA_CREAM.lerp(Palette.FLOUR_WHITE, 0.45), t)
		_place(root, _cylinder(0.018, 0.050, 0.046, cream, 0.50, 12), Vector3(0.0, 0.033, 0.0),
				Vector3.ZERO, Vector3.ONE, "Filling")
		var jam: Color = _shade(Palette.PASTEL_STRAWBERRY.lerp(Palette.DANGER, 0.50), t)
		_place(root, _sphere(0.020, jam, 0.42, 8, 2), Vector3(0.0, 0.044, 0.0),
				Vector3.ZERO, Vector3(1.0, 0.45, 1.0), "Jam")
		var flake: Color = _shade(Palette.VANILLA_CREAM, t)
		for i in 4:
			var af: float = TAU * float(i) / 4.0 + 0.4
			_place(root, _box(Vector3(0.022, 0.004, 0.010), flake, 0.55),
					Vector3(cos(af) * 0.044, 0.047, sin(af) * 0.044),
					Vector3(-12.0, rad_to_deg(-af), 0.0))
		return

	# Danish Cheese Pastry: cakram keju cheddar meleleh di tengah.
	var cheese: Color = _shade(Palette.CUSTARD, t)
	_place(root, _cylinder(0.018, 0.050, 0.046, cheese, 0.55, 12), Vector3(0.0, 0.033, 0.0),
			Vector3.ZERO, Vector3.ONE, "Filling")
	var cheese_hi: Color = cheese.lerp(Palette.BUTTER_YELLOW, 0.55)
	for i in 2:
		_place(root, _box(Vector3(0.072, 0.006, 0.010), cheese_hi, 0.50), Vector3(0.0, 0.043, 0.0),
				Vector3(0.0, -24.0 + 48.0 * float(i), 0.0))


## Brioche: bun beralur enam cuping dengan topknot khas brioche a tete.
## "matcha" mewarnai kulitnya hijau matcha dan menambah salib glazur.
## 450 - 475 tris.
static func _build_brioche(root: Node3D, ctx: Dictionary, variant: String) -> void:
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]
	var crust: Color = ctx["crust"]
	if variant == "matcha":
		# Matcha Sweet Brioche (GDD 5.3.4): adonan hijau, tetap ikut kurva
		# kematangan supaya versi gosongnya benar-benar menghitam.
		crust = crust.lerp(_matcha_green(), 0.55)

	_place(root, _cylinder(0.016, 0.072, 0.062, crust, rough, 12), Vector3(0.0, 0.008, 0.0),
			Vector3.ZERO, Vector3.ONE, "Base")
	_place(root, _sphere(0.070, crust, rough, 12, 4), Vector3(0.0, 0.050, 0.0),
			Vector3.ZERO, Vector3(1.02, 0.74, 1.02), "Crust")
	# Enam cuping beralur mengelilingi badan.
	for i in 6:
		var a: float = TAU * float(i) / 6.0
		_place(root, _sphere(0.030, crust, rough, 6, 2),
				Vector3(cos(a) * 0.056, 0.040, sin(a) * 0.056),
				Vector3(0.0, rad_to_deg(-a), 0.0), Vector3(1.0, 0.86, 1.18))
	_place(root, _sphere(0.030, crust, rough, 8, 3), Vector3(0.0, 0.098, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.94, 1.0), "Topknot")

	if variant == "matcha":
		var icing: Color = _shade(Palette.FLOUR_WHITE, t * 0.60)
		for i in 2:
			_place(root, _box(Vector3(0.056, 0.005, 0.008), icing, 0.42), Vector3(0.0, 0.124, 0.0),
					Vector3(0.0, 90.0 * float(i), 0.0))


## Sourdough Whole Wheat (GDD 5.3.4): boule rustic bulat dengan guratan silang
## dan taburan tepung. +- 205 tris.
static func _build_boule(root: Node3D, ctx: Dictionary) -> void:
	var rough: float = ctx["rough"]
	var t: float = ctx["t"]
	var base: Color = ctx["crust"]
	var crust: Color = base.lerp(Palette.CARAMEL, 0.30)

	_place(root, _sphere(0.095, crust, rough, 12, 4), Vector3(0.0, 0.061, 0.0),
			Vector3.ZERO, Vector3(1.02, 0.66, 1.02), "Crust")
	# Scoring silang khas sourdough (GDD 5.3.4 langkah 4).
	var score: Color = _shade(Palette.RAW_DOUGH.lerp(crust, 0.25), t)
	for i in 2:
		_place(root, _box(Vector3(0.140, 0.010, 0.013), score, 0.92), Vector3(0.0, 0.118, 0.0),
				Vector3(0.0, 90.0 * float(i), 0.0))
	# Taburan tepung whole wheat.
	var flour: Color = _shade(Palette.FLOUR_WHITE, t * 0.50)
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + 0.35
		_place(root, _box(Vector3(0.017, 0.004, 0.017), flour, 0.96),
				Vector3(cos(a) * 0.050, 0.112, sin(a) * 0.050), Vector3(0.0, 24.0 * float(i), 0.0))


## Matcha Mille Crepes (GDD 5.3.5): tumpukan sembilan lembar crepe tipis
## berselang-seling hijau matcha dan krim. +- 450 tris.
static func _build_crepes(root: Node3D, ctx: Dictionary) -> void:
	var t: float = ctx["t"]
	var rough: float = ctx["rough"]
	var base: Color = ctx["crust"]
	var sheet: Color = base.lerp(Palette.VANILLA_CREAM, 0.45)
	var matcha: Color = _shade(_matcha_green().lerp(Palette.FLOUR_WHITE, 0.30), t)

	var layers: int = 9
	var layer_h: float = 0.013
	for i in layers:
		var f: float = float(i) / float(layers - 1)
		var r: float = lerpf(0.082, 0.072, f)
		var col: Color = sheet
		if i % 2 == 1:
			col = matcha
		var layer_name: String = ""
		if i == 0:
			layer_name = "Crust"
		_place(root, _cylinder(layer_h, r, r + 0.002, col, rough, 10),
				Vector3(0.0, layer_h * (float(i) + 0.5), 0.0), Vector3.ZERO, Vector3.ONE, layer_name)
	# Taburan bubuk matcha + dolop krim di puncak.
	var top_y: float = layer_h * float(layers)
	_place(root, _cylinder(0.005, 0.072, 0.072, _shade(_matcha_green(), t), 0.95, 10),
			Vector3(0.0, top_y + 0.0025, 0.0), Vector3.ZERO, Vector3.ONE, "MatchaDust")
	_place(root, _sphere(0.019, _shade(Palette.FLOUR_WHITE, t * 0.40), 0.45, 8, 2),
			Vector3(0.0, top_y + 0.012, 0.0), Vector3.ZERO, Vector3(1.0, 0.80, 1.0), "Cream")


## Roti Emas Artisan (GDD 5.3.5): resep terprestisius di seluruh game. Kubah
## berkulit emas, mahkota torus, guratan bintang, mutiara emas, dan bunga
## edible prosedural di puncaknya. +- 520 tris.
static func _build_signature(root: Node3D, ctx: Dictionary) -> void:
	var t: float = ctx["t"]
	var rough: float = ctx["rough"]
	var base: Color = ctx["crust"]
	var gold_crust: Color = base.lerp(Palette.GOLD_STAR, 0.55)
	var gold_deep: Color = gold_crust.lerp(Palette.CARAMEL, 0.35)
	var gold_bright: Color = _shade(Palette.GOLD_STAR, t * 0.60)

	_place(root, _sphere(0.092, gold_crust, minf(rough, 0.45), 12, 4), Vector3(0.0, 0.062, 0.0),
			Vector3.ZERO, Vector3(1.02, 0.72, 1.02), "Crust")
	# Mahkota di pangkal roti.
	_place(root, _torus(0.068, 0.100, gold_deep, minf(rough, 0.40), 12, 5), Vector3(0.0, 0.020, 0.0),
			Vector3.ZERO, Vector3(1.0, 0.56, 1.0), "Crown")
	# Guratan bintang tiga arah.
	for i in 3:
		_place(root, _box(Vector3(0.132, 0.008, 0.011), gold_bright, 0.30), Vector3(0.0, 0.122, 0.0),
				Vector3(0.0, 60.0 * float(i), 0.0))
	# Mutiara emas.
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + 0.8
		_place(root, _sphere(0.014, gold_bright, 0.25, 6, 2),
				Vector3(cos(a) * 0.056, 0.116, sin(a) * 0.056))
	# Bunga edible prosedural di puncak (GDD 5.3.5 langkah 4).
	var petal: Color = _shade(Palette.PASTEL_STRAWBERRY, t)
	for i in 5:
		var af: float = TAU * float(i) / 5.0
		_place(root, _box(Vector3(0.024, 0.005, 0.013), petal, 0.55),
				Vector3(cos(af) * 0.016, 0.130, sin(af) * 0.016), Vector3(0.0, rad_to_deg(-af), 0.0))
	_place(root, _sphere(0.011, _shade(Palette.BUTTER_YELLOW, t), 0.40, 6, 2),
			Vector3(0.0, 0.133, 0.0), Vector3.ZERO, Vector3.ONE, "FlowerCore")


# ---------------------------------------------------------------------------
# Warna turunan (tidak ada di Palette, diturunkan agar tetap satu keluarga)
# ---------------------------------------------------------------------------

## Hijau matcha. Palette tidak punya konstanta matcha, jadi warnanya diturunkan
## dari PASTEL_MINT yang dihangatkan ke arah CARAMEL supaya tetap "warm & cozy".
static func _matcha_green() -> Color:
	return Palette.PASTEL_MINT.lerp(Palette.CARAMEL, 0.34)


## Cokelat kemerahan sosis sapi, turunan CARAMEL ke arah DANGER.
static func _sausage_brown() -> Color:
	return Palette.CARAMEL.lerp(Palette.DANGER, 0.45)


## Cokelat kertas kraft kantong RotiFood, turunan PINE_WOOD ke arah CARAMEL.
static func _kraft_brown() -> Color:
	return Palette.PINE_WOOD.lerp(Palette.CARAMEL, 0.25)


## Topping ikut menghitam kalau rotinya kelewat panggang; di bawah titik matang
## sempurna warnanya dibiarkan apa adanya.
static func _shade(color: Color, t: float) -> Color:
	if t <= Palette.BAKE_PERFECT_T:
		return color
	var k: float = (t - Palette.BAKE_PERFECT_T) / (1.0 - Palette.BAKE_PERFECT_T)
	return color.lerp(Palette.BURNT_BLACK, k * 0.80)


# ---------------------------------------------------------------------------
# Helper primitif -- jumlah segmen SELALU diisi eksplisit (budget GDD 12.2)
# ---------------------------------------------------------------------------

## StandardMaterial3D warna solid + roughness saja, di-cache supaya ratusan roti
## di rak berbagi material yang sama.
static func _material(color: Color, rough: float) -> StandardMaterial3D:
	var r: float = clampf(rough, 0.0, 1.0)
	var key: String = "%d_%d" % [color.to_rgba32(), int(round(r * 100.0))]
	if _material_cache.has(key):
		return _material_cache[key] as StandardMaterial3D
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = r
	mat.metallic = 0.0
	_material_cache[key] = mat
	return mat


## Balok. 12 segitiga.
static func _box(size: Vector3, color: Color, rough: float = 0.85) -> MeshInstance3D:
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh.subdivide_width = 0
	mesh.subdivide_height = 0
	mesh.subdivide_depth = 0
	mesh.material = _material(color, rough)
	return _instance(mesh)


## Bola. 2 * radial * (rings + 1) segitiga -- radial 12 / rings 4 = 120 tris.
static func _sphere(radius: float, color: Color, rough: float = 0.90,
		radial: int = 10, rings: int = 4) -> MeshInstance3D:
	var mesh: SphereMesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = radial
	mesh.rings = rings
	mesh.is_hemisphere = false
	mesh.material = _material(color, rough)
	return _instance(mesh)


## Silinder / kerucut terpancung. 4 * radial segitiga (rings dinolkan).
static func _cylinder(height: float, top_r: float, bottom_r: float, color: Color,
		rough: float = 0.85, radial: int = 10) -> MeshInstance3D:
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.height = height
	mesh.top_radius = top_r
	mesh.bottom_radius = bottom_r
	mesh.radial_segments = radial
	mesh.rings = 0
	mesh.cap_top = true
	mesh.cap_bottom = true
	mesh.material = _material(color, rough)
	return _instance(mesh)


## Torus mendatar (lubangnya searah sumbu Y). 2 * rings * ring_segments tris.
static func _torus(inner: float, outer: float, color: Color, rough: float = 0.90,
		rings: int = 12, ring_segments: int = 6) -> MeshInstance3D:
	var mesh: TorusMesh = TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = rings
	mesh.ring_segments = ring_segments
	mesh.material = _material(color, rough)
	return _instance(mesh)


## Kapsul membujur sumbu Y; `height` sudah termasuk kedua tutup setengah bola.
static func _capsule(height: float, radius: float, color: Color, rough: float = 0.90,
		radial: int = 10, rings: int = 2) -> MeshInstance3D:
	var mesh: CapsuleMesh = CapsuleMesh.new()
	mesh.radius = radius
	mesh.height = maxf(height, radius * 2.0 + 0.001)
	mesh.radial_segments = radial
	mesh.rings = rings
	mesh.material = _material(color, rough)
	return _instance(mesh)


static func _instance(mesh: Mesh) -> MeshInstance3D:
	var mi: MeshInstance3D = MeshInstance3D.new()
	mi.mesh = mesh
	return mi


## Pasang node ke induk sekaligus mengatur posisi / rotasi / skala / nama.
static func _place(parent: Node3D, node: Node3D, pos: Vector3,
		rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE,
		node_name: String = "") -> Node3D:
	if node_name != "":
		node.name = node_name
	node.position = pos
	node.rotation_degrees = rot_deg
	node.scale = scl
	parent.add_child(node)
	return node


## Roti tidak pernah ikut menghitung bayangan real-time: satu rak display bisa
## memuat ratusan roti sekaligus dan targetnya Android kelas bawah (GDD 12.2).
static func _disable_shadows(node: Node) -> void:
	for child in node.get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if child is Node3D:
			_disable_shadows(child)
