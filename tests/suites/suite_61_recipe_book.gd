extends TestSuite
## Buku Resep (GDD 7, perbaikan 2026-10-02): hanya daftar resep yang digulir.
## Rincian resep (bahan, rincian, harga, batch, Make) muat tanpa gulir untuk
## setiap resep dan ukuran batch, pada skala teks 100% dan 125%, baik saat harga
## masih terkunci (Hari 1-3) maupun sesudahnya.


func tests() -> Array:
	return [
		{"id": "ACC_7_RECIPE_BOOK_NO_SCROLL", "name": "7 the Recipe Book detail fits without scrolling for every recipe and batch size at 100% and 125% text scale, with prices locked or not; only the recipe list scrolls", "fn": _no_scroll},
	]


func _no_scroll() -> void:
	SaveManager.dir = "user://test_saves_recipe_book"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Recipe Bakery")
	await runner.get_tree().process_frame
	game.modals.close_all()
	game.sim.tutorial.skip()
	PauseManager.clear_all()
	game.playing = false
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
	game.modals.close_all()
	game.playing = true
	game.return_to_menu()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	PauseManager.clear_all()
	PauseManager.lifecycle_enabled = false
