extends TestSuite
## Kejutan kosmetik di toko (keputusan maintainer 2026-10-04, GDD 31.9): tiap
## hari 2-3 adegan kecil acak saat toko buka (kucing oren, anak dikejar ibunya,
## Pak Lurah, maskot roti, pengamen ukulele, turis, kupu-kupu, burung pipit).
## Murni tontonan: simulasi tidak pernah tersentuh.

## Kalimat tiap kejutan, urut seperti diucapkan.
const LINES: Dictionary = {
	"cat": ["surprise_cat_meow"],
	"kid_chase": ["surprise_kid_whee", "surprise_mom_call", "surprise_kid_sorry", "surprise_mom_sorry"],
	"lurah": ["surprise_lurah_hello"],
	"mascot": ["surprise_mascot_hello"],
	"busker": ["surprise_busker_thanks"],
	"tourists": ["surprise_tourist_cheese", "surprise_tourist_cute"],
	"butterfly": [],
	"sparrow": ["surprise_sparrow_tweet"],
}


func tests() -> Array:
	return [
		{"id": "ACC_31_SURPRISE_PLAN", "name": "31.9 every day plans 2-3 different surprises at random times in opening hours; none comes back the next day and all eight come round within any four days", "fn": _plan},
		{"id": "ACC_31_SURPRISE_SKITS", "name": "31.9 each of the eight surprises plays out in the shop, says its English lines one at a time, and leaves nothing behind", "fn": _skits},
		{"id": "ACC_31_SURPRISE_WHEN", "name": "31.9 a surprise starts at its time only while the shop is open, unpaused, outside Decoration Mode and on screen; pause freezes it, Decoration Mode hides it, closing ends it", "fn": _when},
		{"id": "ACC_31_SURPRISE_COSMETIC", "name": "31.9/116 surprises are only a show: a day with one always playing plays out exactly like a day without", "fn": _cosmetic},
	]


func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.tutorial.skip()
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	return s


func _plan() -> void:
	var kinds: Array = DataRegistry.bal("presentation.surprise_kinds")
	eq(kinds.size(), 8, "eight kinds of surprise")
	for k: Variant in kinds:
		check(DataRegistry.SURPRISE_KINDS.has(str(k)), "%s is a known surprise" % k)
	var per_day: Array = DataRegistry.bal("presentation.surprise_per_day")
	eq([int(per_day[0]), int(per_day[1])], [2, 3], "two or three a day")
	var hours: Array = DataRegistry.bal("presentation.surprise_hours")
	var lo: float = float(hours[0]) * 3600.0
	var hi: float = float(hours[1]) * 3600.0
	check(lo >= DataRegistry.balf("clock.open_seconds") and hi <= DataRegistry.balf("clock.close_seconds"), "the window lies inside opening hours")
	var problems: Array[String] = []
	var sizes: Dictionary = {}
	var first_days: Dictionary = {}
	for seed_i in 12:
		var seed_value: int = 66000 + seed_i * 37
		var days: Array = []
		for d in range(1, 29):
			var p: Array[Dictionary] = SurpriseDirector.plan(seed_value, d)
			if JSON.stringify(p) != JSON.stringify(SurpriseDirector.plan(seed_value, d)):
				problems.append("seed %d day %d: the plan is not reproducible" % [seed_value, d])
			sizes[p.size()] = true
			var today: Array[String] = []
			var last_at: float = -INF
			for e: Dictionary in p:
				var k: String = str(e["kind"])
				var at: float = float(e["at"])
				if today.has(k):
					problems.append("seed %d day %d: %s twice" % [seed_value, d, k])
				today.append(k)
				if at < lo or at > hi:
					problems.append("seed %d day %d: %s at %.0f s is outside the window" % [seed_value, d, k, at])
				if at - last_at < 2400.0:
					problems.append("seed %d day %d: %s only %.0f s after the one before" % [seed_value, d, k, at - last_at])
				last_at = at
			if p.size() < 2 or p.size() > 3:
				problems.append("seed %d day %d: %d surprises" % [seed_value, d, p.size()])
			if not days.is_empty():
				for k2: String in today:
					if (days[-1] as Array).has(k2):
						problems.append("seed %d day %d: %s again the day after" % [seed_value, d, k2])
			days.append(today)
			if d == 1:
				first_days[",".join(today)] = true
		for start in range(0, days.size() - 3):
			var seen: Dictionary = {}
			for d2 in range(start, start + 4):
				for k3: String in days[d2]:
					seen[k3] = true
			if seen.size() != kinds.size():
				problems.append("seed %d days %d-%d: only %d kinds" % [seed_value, start + 1, start + 4, seen.size()])
	eq(problems, [] as Array[String], "every day of 12 games x 28 days follows the rules")
	check(sizes.has(2) and sizes.has(3), "some days have two surprises, some three")
	check(first_days.size() >= 6, "different games start with different surprises (%d different first days in 12 games)" % first_days.size())


func _skits() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(6611)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	var director: SurpriseDirector = world.surprises
	var before: String = fingerprint(s)
	var fg: FloorGrid = s.world.grid(s.world.store_floor())
	for kind: String in DataRegistry.SURPRISE_KINDS:
		check(director.start(StringName(kind)), "%s starts" % kind)
		eq(director.running(), StringName(kind), "%s is playing" % kind)
		var said: Array[String] = []
		var wrong_text: Array[String] = []
		var together: int = 0
		var inside: bool = false
		var t: float = 0.0
		while director.running() != &"" and t < SurpriseDirector.MAX_SECONDS + 1.0:
			world._process(0.05)
			t += 0.05
			var showing: Array[ThoughtBubble] = director.bubbles_showing()
			together = maxi(together, showing.size())
			for b: ThoughtBubble in showing:
				if not said.has(b.current_key()):
					said.append(b.current_key())
				if b.text().replace("\n", " ") != Tx.t(b.current_key()):
					wrong_text.append(b.current_key())
			for n: Node3D in director.cast_nodes():
				var c: Vector2i = GridMath.world_to_cell(Vector2(n.global_position.x, n.global_position.z))
				if fg.in_bounds(c) and fg.is_store(c) and c != s.world.entrance_cell():
					inside = true
		eq(director.running(), &"", "%s ends on its own" % kind)
		check(t < 60.0, "%s is over within a minute (%.1f s)" % [kind, t])
		eq(said, LINES[kind] as Array[String], "%s says its lines in order" % kind)
		eq(wrong_text, [] as Array[String], "%s speaks English from the string catalog" % kind)
		check(together <= 1, "%s: one speaker at a time" % kind)
		check(inside, "%s comes into the shop" % kind)
		await runner.get_tree().process_frame
		eq(director.get_child_count(), 0, "%s leaves no model or effect behind" % kind)
		var left: int = 0
		for c2: Node in world._thought_layer.get_children():
			if String(c2.name).contains("SurpriseLine") and not c2.is_queued_for_deletion():
				left += 1
		eq(left, 0, "%s leaves no bubble behind" % kind)
	eq(fingerprint(s), before, "the simulation is untouched")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


func _when() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(6612)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	var director: SurpriseDirector = world.surprises
	world._process(0.016)
	var todo: Array[Dictionary] = director.todo().duplicate()
	eq(JSON.stringify(todo), JSON.stringify(SurpriseDirector.plan(s.rng.master_seed, s.time.day)), "today's plan waits in line")
	if todo.size() < 2:
		check(false, "at least two surprises today")
		world.queue_free()
		await runner.get_tree().process_frame
		free_sim(s)
		return
	var first: StringName = todo[0]["kind"]
	var at: float = float(todo[0]["at"])
	# Belum waktunya: tidak terjadi apa-apa.
	s.time.time_seconds = at - 30.0
	world._process(0.05)
	eq(director.running(), &"", "nothing before its time")
	# Sudah waktunya, tetapi game di-pause atau Decoration Mode: menunggu.
	s.time.time_seconds = at + 1.0
	PauseManager.push(PauseManager.USER)
	world._process(0.05)
	eq(director.running(), &"", "not while the game is paused")
	PauseManager.pop(PauseManager.USER)
	world.decoration_mode = true
	world._process(0.05)
	eq(director.running(), &"", "not in Decoration Mode")
	world.decoration_mode = false
	world._process(0.05)
	eq(director.running(), first, "then it starts")
	eq(director.todo().size(), todo.size() - 1, "and leaves the plan")
	for i in 40:
		world._process(0.05)
	var cast: Array[Node3D] = director.cast_nodes()
	check(not cast.is_empty(), "its cast is in the shop")
	# Pause membekukan adegan; Decoration Mode menyembunyikannya.
	var where: Array[Vector3] = []
	for n: Node3D in cast:
		where.append(n.global_position)
	PauseManager.push(PauseManager.USER)
	for i2 in 20:
		world._process(0.05)
	var moved: bool = false
	for j in cast.size():
		moved = moved or cast[j].global_position.distance_to(where[j]) > 0.0001
	check(not moved, "pause freezes the scene")
	eq(director.running(), first, "and it is still playing")
	PauseManager.pop(PauseManager.USER)
	world.decoration_mode = true
	world._process(0.05)
	var hidden: bool = true
	for n2: Node3D in director.cast_nodes():
		hidden = hidden and not n2.visible
	check(hidden, "Decoration Mode hides the cast")
	eq(director.bubbles_showing().size(), 0, "and their lines")
	world.decoration_mode = false
	world._process(0.05)
	var shown: bool = true
	for n3: Node3D in director.cast_nodes():
		shown = shown and n3.visible
	check(shown, "and shows them again afterwards")
	var t: float = 0.0
	while director.running() != &"" and t < SurpriseDirector.MAX_SECONDS:
		world._process(0.05)
		t += 0.05
	eq(director.running(), &"", "the first surprise ends")
	# Kejutan yang tertunda terlalu lama (pemain di Decoration Mode) dibatalkan.
	var second: Dictionary = director.todo()[0]
	world.decoration_mode = true
	s.time.time_seconds = float(second["at"]) + SurpriseDirector.LATE_SECONDS + 1.0
	world._process(0.05)
	world.decoration_mode = false
	check(director.todo().is_empty() or director.todo()[0] != second, "a surprise held up for over 1.5 in-game hours is dropped")
	eq(director.running(), &"", "instead of playing late")
	# Toko tutup: adegan langsung berakhir dan pemerannya hilang.
	check(director.start(&"mascot"), "another surprise plays")
	for i3 in 30:
		world._process(0.05)
	check(s.close_early(), "the shop closes")
	world._process(0.05)
	eq(director.running(), &"", "closing ends the surprise at once")
	eq(director.cast_nodes().size(), 0, "and sends its cast away")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
	PauseManager.clear_all()


func _cosmetic() -> void:
	PauseManager.clear_all()
	var a: SimulationRoot = new_sim(6613)
	var b: SimulationRoot = new_sim(6613)
	var bot_a := SimBot.new(a)
	var bot_b := SimBot.new(b)
	run_until(a, 8.0 * 3600.0, bot_a)
	run_until(b, 8.0 * 3600.0, bot_b)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(a)
	var real_dt: float = a.tick_seconds / DataRegistry.sim_seconds_per_real_second()
	var kinds: Array[String] = DataRegistry.SURPRISE_KINDS
	var next: int = 0
	var played: Dictionary = {}
	while a.is_running() and a.time.time_seconds < 13.0 * 3600.0 and not (played.size() == kinds.size() and world.surprises.running() == &""):
		bot_a.think()
		a.step(a.tick_seconds)
		bot_b.think()
		b.step(b.tick_seconds)
		if world.surprises.running() == &"" and a.time.is_open() and next < kinds.size():
			if world.surprises.start(StringName(kinds[next])):
				played[kinds[next]] = true
			next += 1
		world._process(real_dt)
	eq(played.size(), kinds.size(), "all eight surprises played during the morning")
	check(a.customers.entered_today > 0, "while customers came and went (%d)" % a.customers.entered_today)
	same_state(state_of(b), state_of(a), "the morning plays out the same with the surprises")
	var clock: int = int(a.time.time_seconds)
	print("      all eight surprises over by %02d:%02d, %d walk-ins so far" % [clock / 3600, (clock / 60) % 60, a.customers.entered_today])
	world.queue_free()
	await runner.get_tree().process_frame
	run_day(a, bot_a)
	run_day(b, bot_b)
	same_state(state_of(b), state_of(a), "and so does the rest of the day")
	free_sim(a)
	free_sim(b)
