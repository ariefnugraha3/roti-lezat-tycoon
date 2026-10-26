extends TestSuite
## Gambar roti datar per resep (BreadArt, v3.1 7, keputusan maintainer
## 2026-10-04). Tampilannya di lembar Menu diuji bersama lembar itu.


func tests() -> Array:
	return [
		{"id": "ACC_7_RECIPE_ART", "name": "7 every recipe has its own flat picture: one opaque colour per shape, inside its square, never reused", "fn": _art},
	]


func _art() -> void:
	# Gambarnya sendiri: satu per profil, tidak ada dua roti yang sama, flat
	# (setiap bentuk satu warna polos tanpa transparansi: tanpa bayangan, kilap,
	# atau gradasi), dan tidak keluar dari kotaknya. Alas renda dilewati saat
	# membandingkan, karena warnanya memang dipakai bersama.
	var plate_ops: int = BreadArt.SCALLOPS + 2
	var seen: Dictionary = {}
	for r: RecipeDefinition in DataRegistry.recipes():
		var p: String = String(r.visual_profile_id)
		check(BreadArt.has_art(p), "%s has its own picture (%s)" % [r.id, p])
		var ops: Array = BreadArt.shapes(p, true)
		var bad: Array[String] = []
		for op: Dictionary in ops:
			var c: Color = op["c"]
			if c.a < 0.999:
				bad.append("translucent %s" % op["t"])
			if not _inside(op):
				bad.append("%s outside the square" % op["t"])
		check(bad.is_empty(), "%s is drawn flat inside its square %s" % [p, bad])
		var sig: String = var_to_str(BreadArt.shapes(p, false).slice(plate_ops))
		check(not seen.has(sig), "%s does not reuse the picture of %s" % [p, seen.get(sig, "")])
		seen[sig] = p


## true bila primitif BreadArt tetap di dalam kotak satuan [-0.5 .. 0.5].
static func _inside(op: Dictionary) -> bool:
	var box := Rect2(-0.5, -0.5, 1.0, 1.0)
	match op["t"]:
		BreadArt.POLY:
			for v: Vector2 in (op["pts"] as PackedVector2Array):
				if not box.has_point(v):
					return false
		BreadArt.CIRCLE:
			var r: float = float(op["r"])
			return box.grow(-r).has_point(op["p"] as Vector2)
		BreadArt.LINE:
			var w: float = float(op["w"]) * 0.5
			for v2: Vector2 in (op["pts"] as PackedVector2Array):
				if not box.grow(-w).has_point(v2):
					return false
	return true
