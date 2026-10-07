extends TestSuite
## Jarak scrollbar (keputusan maintainer 2026-10-07, GDD 130.6): di setiap menu
## yang bisa digulir, scrollbar berjarak dari isinya dan tidak menempel di
## daftarnya. Diatur sekali di tema bersama (`scrollbar_v_separation`).


func tests() -> Array:
	return [
		{"id": "ACC_130_SCROLLBAR_GAP", "name": "130.6 in every scrolling menu the scrollbar keeps a gap from the list (theme scrollbar_v_separation), so it never touches the items", "fn": _gap},
	]


func _boot(profile_name: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_scroll_gap"
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


func _gap() -> void:
	var gap_px: int = ProceduralUIFactory.SCROLLBAR_GAP
	check(gap_px >= 8, "the gap is wide enough to see (%d px)" % gap_px)
	eq(ProceduralUIFactory.build_theme().get_constant("scrollbar_v_separation", &"ScrollContainer"), gap_px, "set once in the shared theme")
	var game: GameRoot = await _boot("Scroll Gap")
	game.sim.supply.market_unlocked = true
	var checked: Array[String] = []
	var tight: Array[String] = []
	# [layar, params, tab Staff Management (-1 = biarkan)]
	for c: Array in [[&"staff", {}, 1], [&"staff", {}, 0], [&"recipe_book", {}, -1], [&"market", {"tab": 0}, -1],
			[&"market", {"tab": 1}, -1], [&"help", {}, -1], [&"stats", {}, -1]]:
		game.modals.close_all()
		var scr: UIScreen = game.modals.open(c[0], c[1])
		if scr == null:
			continue
		if int(c[2]) >= 0 and scr is StaffScreen:
			(scr as StaffScreen)._tab = int(c[2])
			(scr as StaffScreen)._render()
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		for n: Node in scr.find_children("*", "ScrollContainer", true, false):
			var sc: ScrollContainer = n as ScrollContainer
			var bar: VScrollBar = sc.get_v_scroll_bar()
			if not sc.is_visible_in_tree() or not bar.visible:
				continue
			var content: Control = null
			for ch: Node in sc.get_children():
				if ch is Control:
					content = ch
					break
			if content == null:
				continue
			var where: String = "%s%s/%s" % [c[0], c[1], sc.name]
			checked.append(where)
			var gap: float = bar.get_global_rect().position.x - content.get_global_rect().end.x
			if gap < float(gap_px) - 0.5:
				tight.append("%s %.1f px" % [where, gap])
	check(checked.size() >= 5, "scrolling lists in several menus were checked (%d)" % checked.size())
	eq(tight, [] as Array[String], "every scrollbar stands at least %d px from its list" % gap_px)
	await _finish(game)
