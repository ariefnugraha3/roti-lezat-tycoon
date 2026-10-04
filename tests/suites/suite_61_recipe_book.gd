extends TestSuite
## Buku Resep (GDD 7, perbaikan 2026-10-02): hanya daftar resep yang digulir.
## Rincian resep (bahan, rincian, harga, batch, Make) muat tanpa gulir untuk
## setiap resep dan ukuran batch, pada skala teks 100% dan 125%, baik saat harga
## masih terkunci (Hari 1-3) maupun sesudahnya.
##
## Gambar roti flat (keputusan maintainer 2026-10-04): setiap resep punya
## gambarnya sendiri di baris daftar dan di samping judul rincian.


func tests() -> Array:
	return [
		{"id": "ACC_7_RECIPE_BOOK_NO_SCROLL", "name": "7 the Recipe Book detail fits without scrolling for every recipe and batch size at 100% and 125% text scale, with prices locked or not; only the recipe list scrolls", "fn": _no_scroll},
		{"id": "ACC_7_RECIPE_ART", "name": "7 every recipe has its own flat picture (one opaque colour per shape, inside its square) beside its name in the list and beside the detail title", "fn": _art},
	]


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_recipe_book"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", profile_name)
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
	return game


func _finish(game: GameRoot) -> void:
	game.modals.close_all()
	game.playing = true
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false


func _no_scroll() -> void:
	var game: GameRoot = await _boot("Recipe Bakery")
	var was_scale: float = ProceduralUIFactory.text_scale
	var day0: int = game.sim.time.day
	for day: int in [day0, 4]:
		game.sim.time.day = day
		var locked: bool = game.sim.pricing.prices_locked()
		for pct: int in [100, 125]:
			ProceduralUIFactory.text_scale = float(pct) / 100.0
			game.modals.close_all()
			var rb: RecipeBookScreen = game.modals.open(&"recipe_book", {}) as RecipeBookScreen
			await runner.get_tree().process_frame
			var worst: float = -INF
			var worst_id: String = ""
			for r: RecipeDefinition in DataRegistry.recipes():
				for b: Variant in DataRegistry.bal("production.batch_multipliers"):
					rb._selected = r.id
					rb._batch = int(b)
					rb._render_detail()
					await runner.get_tree().process_frame
					var area: Control = rb._detail.get_parent() as Control
					var over: float = rb._detail.get_combined_minimum_size().y - area.size.y
					if over > worst:
						worst = over
						worst_id = "%s x%d" % [r.id, int(b)]
			check(worst <= 0.5, "%d%%, prices %s: every detail fits without scrolling (worst %s by %.0f px)" % [pct, "locked" if locked else "open", worst_id, maxf(worst, 0.0)])
			var list_area: Control = rb._list.get_parent() as Control
			check(rb._list.get_combined_minimum_size().y > list_area.size.y, "%d%%: the recipe list is the part that scrolls" % pct)
	ProceduralUIFactory.text_scale = was_scale
	game.sim.time.day = day0
	await _finish(game)


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
	# Di Buku Resep: gambar kecil di setiap baris, gambar besar di samping judul.
	var game: GameRoot = await _boot("Art Bakery")
	var was_scale: float = ProceduralUIFactory.text_scale
	var rb: RecipeBookScreen = game.modals.open(&"recipe_book", {}) as RecipeBookScreen
	await runner.get_tree().process_frame
	var shown: int = 0
	for r2: RecipeDefinition in DataRegistry.recipes():
		var row: Button = rb._list.get_node_or_null(String(r2.id)) as Button
		var art: BreadArt = row.find_child("BreadArt", true, false) as BreadArt if row != null else null
		if art != null and art.profile == String(r2.visual_profile_id) and art.art_size == RecipeBookScreen.LIST_ART:
			shown += 1
	eq(shown, DataRegistry.recipes().size(), "every row in the list shows its recipe's picture")
	var pick: RecipeDefinition = DataRegistry.recipe(&"recipe_cinnamon_roll")
	(rb._list.get_node(String(pick.id)) as Button).pressed.emit()
	await runner.get_tree().process_frame
	var hero: BreadArt = (rb._detail.get_child(0) as Node).find_child("BreadArt", true, false) as BreadArt
	check(hero != null and hero.profile == String(pick.visual_profile_id), "tapping a row shows that recipe's picture beside the title")
	eq(hero.art_size if hero != null else 0.0, RecipeBookScreen.HERO_ART, "at 100% text the title picture is the big one")
	ProceduralUIFactory.text_scale = 1.25
	rb._render_detail()
	await runner.get_tree().process_frame
	hero = (rb._detail.get_child(0) as Node).find_child("BreadArt", true, false) as BreadArt
	eq(hero.art_size if hero != null else 0.0, RecipeBookScreen.HERO_ART_LARGE_TEXT, "at 125% text it shrinks to the title's height so the detail still fits")
	ProceduralUIFactory.text_scale = was_scale
	await _finish(game)


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
