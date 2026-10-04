extends TestSuite
## Roster ringkas dan celetukan staf (keputusan maintainer 2026-10-04, GDD 3.5,
## 31.6, 31.8, 106): lima calon kasir dan lima calon koki; staf yang menganggur
## hanya mengelap wajah dan sesekali berceletuk dalam bahasa Inggris; save lama
## yang merekrut calon yang dihapus memindahkannya ke calon tersisa.


func tests() -> Array:
	return [
		{"id": "ACC_3_STAFF_ROSTER", "name": "3.5 the roster has five cashier and five baker candidates, each with a bio and a line of their own", "fn": _roster},
		{"id": "ACC_31_STAFF_LINES", "name": "31.8 idle staff say an English line in a bubble at most once a minute: the first each day counts their days, the rest rotate without repeats; busy staff and Decoration Mode hide it", "fn": _lines},
		{"id": "ACC_31_STAFF_IDLE_GESTURES", "name": "31.6 idle staff take turns wiping their face, stretching, humming, sipping tea and a role gesture (cashiers toss a coin, bakers pat flour off the apron), standing or seated", "fn": _gestures},
		{"id": "TEST_SAVE_STAFF_V6", "name": "106 a v5 save that hired removed candidates moves them to remaining candidates of the same role, everywhere in the save", "fn": _save_v6},
	]


func _roster() -> void:
	eq(DataRegistry.STAFF_CANDIDATES_PER_ROLE, 5, "at most five candidates per role")
	var per_role: Dictionary = {&"cashier": 0, &"baker": 0}
	for s: StaffDefinition in DataRegistry.staff_list():
		per_role[s.role_id] = int(per_role.get(s.role_id, 0)) + 1
		check(DataRegistry.has_text(String(s.id)), "%s has a bio" % s.id)
		check(DataRegistry.has_text(DataRegistry.staff_personal_line(s.id)), "%s has a line of their own" % s.id)
	eq(per_role, {&"cashier": 5, &"baker": 5}, "five cashier and five baker candidates")


func _lines() -> void:
	PauseManager.clear_all()
	var show: float = DataRegistry.balf("presentation.thought_show_seconds")
	# Jadwal: paling sering sekali per 60 detik, dan hanya setelah diam 6 detik.
	# Kalimat pertama hari itu jatuh tempo setelah urutan roster x 7 detik.
	near(DataRegistry.balf("presentation.staff_line_every_seconds"), 60.0, 0.0001, "one line a minute at most")
	check(not WorldView.staff_line_due(59.9, 30.0), "not before a minute has passed")
	check(not WorldView.staff_line_due(60.0, 5.9), "nor before they have been idle for 6 s")
	check(WorldView.staff_line_due(60.0, 6.0), "then they may speak")
	near(WorldView.staff_line_first_wait(0), 60.0, 0.0001, "the first staff member may speak first thing")
	near(WorldView.staff_line_first_wait(1), 53.0, 0.0001, "the next one 7 s later, so they do not all talk at once")
	# Kalimat pertama tiap hari menghitung hari kerja.
	var budi := &"staff_cashier_budi"
	eq(WorldView.staff_line(budi, 0, 1, 2)["key"], DataRegistry.STAFF_LINE_FIRST_DAY, "the first line on the first day")
	var day_n: Dictionary = WorldView.staff_line(budi, 0, 4, 5)
	eq(day_n["key"], DataRegistry.STAFF_LINE_DAY_N, "later days start by counting")
	eq(Tx.t(str(day_n["key"]), day_n["params"]), "Whoa, day 4 working here!", "with the number of the day")
	# Sisanya bergiliran tanpa berulang, termasuk kalimat peran dan kalimat khas.
	var pool: Array[String] = WorldView.staff_line_pool(budi)
	var said: Dictionary = {}
	for i in pool.size():
		said[str(WorldView.staff_line(budi, i + 1, 3, 3)["key"])] = true
	eq(said.size(), pool.size(), "a day's lines never repeat before every line was said")
	check(pool.has("staff_line_cat") and pool.has("staff_line_cashier_cardio") and pool.has("staff_cashier_budi_line"),
		"general, cashier and personal lines are all in Budi's set")
	check(not WorldView.staff_line_pool(&"staff_baker_joko").has("staff_line_cashier_cardio"), "bakers do not get cashier lines")
	eq(DataRegistry.STAFF_LINES.size() + DataRegistry.STAFF_LINES_CASHIER.size() + DataRegistry.STAFF_LINES_BAKER.size(), 46,
		"30 general, 8 cashier and 8 baker lines (20 added on 2026-10-04)")
	for k: String in DataRegistry.STAFF_LINES + DataRegistry.STAFF_LINES_CASHIER + DataRegistry.STAFF_LINES_BAKER:
		check(DataRegistry.has_text(k), "%s has English text" % k)
	# Di dunia: kasir Budi dan koki Joko pada hari pertama mereka, menganggur.
	var s: SimulationRoot = new_sim(6501)
	s.tutorial.skip()
	s.time.set_phase(TimeManager.AFTER_HOURS)
	eq(s.staff.hire(budi), &"", "hire Budi")
	eq(s.staff.hire(&"staff_baker_joko"), &"", "hire Joko")
	check(s.continue_to_next_day(), "their first day starts")
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	var bv: ActorView = null
	for i in 300:
		world._process(0.05)
		bv = world.views.get((s.staff.actors[budi] as SimActor).id)
		if bv != null and bv.idle_seconds() >= 6.05:
			break
	var bb: ThoughtBubble = world.staff_bubble(budi)
	check(bb != null and bb.is_showing(), "an idle cashier says something after 6 s")
	if bb == null:
		world.queue_free()
		free_sim(s)
		return
	eq(bb.current_key(), DataRegistry.STAFF_LINE_FIRST_DAY, "on the first day: the first-day line")
	eq(bb.text().replace("\n", " "), Tx.t(DataRegistry.STAFF_LINE_FIRST_DAY), "in English from the catalog")
	var jb: ThoughtBubble = world.staff_bubble(&"staff_baker_joko")
	check(jb == null or not jb.is_showing(), "Joko waits his own turn")
	while bv.idle_seconds() < 6.0 + show + 0.2:
		world._process(0.05)
	check(not bb.is_showing(), "the bubble goes after 5 s")
	# Joko ke-5 di roster: kalimat pertamanya jatuh tempo 35 detik setelah pagi.
	while bv.idle_seconds() < 35.1:
		world._process(0.05)
	jb = world.staff_bubble(&"staff_baker_joko")
	check(jb != null and jb.is_showing(), "the seated baker speaks in his own turn")
	while bv.idle_seconds() < 65.9:
		world._process(0.05)
	check(not bb.is_showing(), "Budi stays quiet for a full minute")
	while bv.idle_seconds() < 66.1:
		world._process(0.05)
	check(bb.is_showing(), "a minute after his first line Budi says something else")
	eq(bb.current_key(), str(WorldView.staff_line(budi, 1, 1, s.time.day)["key"]), "the next line in his set")
	check(bb.current_key() != DataRegistry.STAFF_LINE_FIRST_DAY, "not the same line again")
	# Begitu sibuk, gelembungnya hilang; Decoration Mode juga menyembunyikannya.
	s.staff.tasks[budi] = {"type": "probe"}
	world._process(0.05)
	world._process(0.3)
	check(not bb.is_showing(), "a busy cashier stops talking")
	s.staff.tasks.erase(budi)
	world.decoration_mode = true
	for i2 in 900:
		world._process(0.05)
	check(not bb.is_showing() and (jb == null or not jb.is_showing()), "no staff lines in Decoration Mode")
	world.decoration_mode = false
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
	PauseManager.clear_all()


func _save_v6() -> void:
	# Save sungguhan dengan Budi & Joko bertugas, lalu dijadikan save v5 yang
	# merekrut dua calon yang kini dihapus (Hendra & Pierre).
	var s: SimulationRoot = new_sim(6502)
	s.tutorial.skip()
	s.time.set_phase(TimeManager.AFTER_HOURS)
	s.staff.hire(&"staff_cashier_budi")
	s.staff.hire(&"staff_baker_joko")
	s.continue_to_next_day()
	var now: Dictionary = json_copy(s.capture_save())
	free_sim(s)
	var text: String = JSON.stringify(now).replace("staff_cashier_budi", "staff_cashier_hendra").replace("staff_baker_joko", "staff_baker_pierre")
	var old: Dictionary = JSON.parse_string(text)
	old["schema_version"] = 5
	var m: Dictionary = SaveManager.migrate(old)
	check(bool(m.get("ok", false)), "a v5 save migrates")
	if not bool(m.get("ok", false)):
		return
	var d: Dictionary = m["data"]
	eq(int(d["schema_version"]), SaveManager.current_schema_version(), "to the current schema")
	var migrated: String = JSON.stringify(d)
	check(not migrated.contains("staff_cashier_hendra") and not migrated.contains("staff_baker_pierre"), "no removed candidate is left anywhere in the save")
	d["schema_version"] = now["schema_version"]
	eq(diff_state(normalize_save(d), normalize_save(now)), [] as Array[String], "they become the first free candidates of their role (Budi, Joko), so the save is the same as before")
	var u: SimulationRoot = load_sim(m["data"])
	eq(u.staff.employed_ids(), [&"staff_cashier_budi", &"staff_baker_joko"] as Array[StringName], "the shop keeps a cashier and a baker")
	check(u.staff.is_working(&"staff_cashier_budi") and u.staff.is_working(&"staff_baker_joko"), "and both are still on shift")
	eq(u.check_invariants(), "", "invariants")
	free_sim(u)
	# Calon tersisa yang sudah direkrut tidak diambil dua kali.
	var two: Dictionary = (JSON.parse_string(text) as Dictionary)
	two["schema_version"] = 5
	var cs: Dictionary = (two["staff"] as Dictionary)["contracts"]
	cs["staff_cashier_budi"] = (cs["staff_cashier_hendra"] as Dictionary).duplicate()
	(cs["staff_cashier_budi"] as Dictionary)["hired_day"] = 0
	var m2: Dictionary = SaveManager.migrate(two)
	var cs2: Dictionary = ((m2["data"] as Dictionary)["staff"] as Dictionary)["contracts"]
	check(cs2.has("staff_cashier_budi") and cs2.has("staff_cashier_sari") and cs2.size() == 3,
		"with Budi already hired, Hendra becomes Sari, the next free cashier")


func _gestures() -> void:
	PauseManager.clear_all()
	var every: float = DataRegistry.balf("presentation.idle_wipe_every_seconds")
	var order: Array[int] = ActorView.staff_gestures()
	eq(order, [ActorView.GESTURE_WIPE, ActorView.GESTURE_STRETCH, ActorView.GESTURE_HUM, ActorView.GESTURE_TEA, ActorView.GESTURE_ROLE] as Array[int],
		"staff take turns: wipe, stretch, hum, tea, role gesture")
	eq(ActorView.gesture_for(every + 0.1, INF, order, 0), ActorView.GESTURE_WIPE, "the first turn at 7.5 s")
	eq(ActorView.gesture_for(every * 2.0 + 0.1, INF, order, 0), ActorView.GESTURE_STRETCH, "the next turn 7.5 s later")
	eq(ActorView.gesture_for(every + 0.1, INF, order, 2), ActorView.GESTURE_HUM, "a staff member further down the roster starts elsewhere in the turn")
	eq(ActorView.gesture_for(every * 6.0 + 0.1, INF, order, 0), ActorView.GESTURE_WIPE, "and the turn comes round again")
	eq(ActorView.gesture_for(every * 2.0 + ActorView.gesture_seconds(ActorView.GESTURE_STRETCH) + 0.1, INF, order, 0), ActorView.GESTURE_NONE,
		"each gesture ends before the next mark")
	# Kasir: satu putaran penuh, berdiri.
	var v := ActorView.new()
	runner.add_child(v)
	v.bind(&"staff_cashier_budi", "staff|gesture_test", CharacterFactory.spec_for_staff("staff_cashier_budi"))
	v.set_idle_enabled(true)
	v.set_busy(false)
	v.set_idle_gestures(order, 0, false)
	var a := SimActor.new()
	var arm_l: Node3D = CharacterFactory.part(v.model, "ArmL")
	var arm_r: Node3D = CharacterFactory.part(v.model, "ArmR")
	_run_to(v, a, every + 0.5)
	eq(v.gesture(), ActorView.GESTURE_WIPE, "7.5 s: wipes the face")
	_run_to(v, a, every * 2.0 + 0.9)
	eq(v.gesture(), ActorView.GESTURE_STRETCH, "15 s: stretches")
	check(arm_l.rotation.x > 2.0 and arm_r.rotation.x > 2.0, "both arms high above the head (%.2f, %.2f)" % [arm_l.rotation.x, arm_r.rotation.x])
	eq(v.model.get_meta("mood"), "lega", "eyes closed, relieved")
	_run_to(v, a, every * 3.0 + 1.5)
	eq(v.gesture(), ActorView.GESTURE_HUM, "22.5 s: hums along")
	check(not v.find_children("MusicNote*", "", false, false).is_empty(), "little music notes float up")
	eq(v.model.get_meta("mood"), "senang", "happy face")
	_run_to(v, a, every * 4.0 + 1.6)
	eq(v.gesture(), ActorView.GESTURE_TEA, "30 s: sips tea")
	check(v._cup != null and v._cup.visible, "a teacup in the hand")
	if v._cup != null:
		check(v._cup.global_position.distance_to(v._hand_world("ArmR")) < 0.06, "held in the right hand")
		check(v._cup.global_position.y > 0.35, "lifted towards the mouth (%.2f m)" % v._cup.global_position.y)
	check(not v.find_children("Puff*", "", false, false).is_empty(), "with steam rising from it")
	_run_to(v, a, every * 5.0 + 1.0)
	eq(v.gesture(), ActorView.GESTURE_ROLE, "37.5 s: the cashier's own gesture")
	check(v._coin != null and v._coin.visible, "a coin")
	if v._coin != null:
		check(v._coin.global_position.y > v._hand_world("ArmR").y + 0.15, "tossed up over the hand")
	_run_to(v, a, every * 5.0 + 2.6)
	eq(v.gesture(), ActorView.GESTURE_NONE, "the gesture ends")
	check(not v._coin.visible and not v._cup.visible, "cup and coin are put away")
	eq(v.model.get_meta("mood"), "senang", "normal face again")
	_run_to(v, a, every * 6.0 + 0.3)
	eq(v.gesture(), ActorView.GESTURE_WIPE, "then wiping again, round and round")
	var dozed: bool = false
	while v.idle_seconds() < 120.0:
		_run_to(v, a, v.idle_seconds() + 0.1)
		dozed = dozed or v.gesture() == ActorView.GESTURE_DOZE
	check(not dozed, "never dozes")
	v.set_busy(true)
	_run_to(v, a, v.idle_seconds() + 0.1)
	eq(v.gesture(), ActorView.GESTURE_NONE, "any activity ends the gesture at once")
	# Koki yang duduk: gerak khas perannya menepuk tepung, kakinya tetap menjuntai.
	var bv := ActorView.new()
	runner.add_child(bv)
	bv.bind(&"staff_baker_joko", "staff|gesture_test_b", CharacterFactory.spec_for_staff("staff_baker_joko"))
	bv.set_idle_enabled(true)
	bv.set_busy(false)
	bv.set_idle_gestures(order, 4, true)
	bv.set_seat(Vector3(0.0, 0.30, 0.0))
	var ba := SimActor.new()
	_run_to(bv, ba, every + 1.1)
	eq(bv.gesture(), ActorView.GESTURE_ROLE, "the baker's turn starts with his own gesture")
	check(bv._coin == null or not bv._coin.visible, "bakers do not toss coins")
	check(not bv.find_children("Puff*", "", false, false).is_empty(), "flour puffs off the apron")
	var leg: Node3D = CharacterFactory.part(bv.model, "LegL")
	check(leg.rotation.x > 1.0, "still seated, legs dangling")
	_run_to(bv, ba, every * 2.0 + 0.9)
	eq(bv.gesture(), ActorView.GESTURE_WIPE, "then wipes his face")
	_run_to(bv, ba, every * 3.0 + 0.9)
	eq(bv.gesture(), ActorView.GESTURE_STRETCH, "and stretches in his chair")
	check(CharacterFactory.part(bv.model, "ArmL").rotation.x > 2.0, "arms up while seated")
	check(leg.rotation.x > 1.0, "without standing up")
	v.queue_free()
	bv.queue_free()
	await runner.get_tree().process_frame


func _run_to(v: ActorView, a: SimActor, idle_target: float) -> void:
	while v.idle_seconds() < idle_target - 0.0001:
		var dt: float = minf(0.05, idle_target - v.idle_seconds())
		v.sync(a, maxf(dt, 0.001), true)
		if v.gesture() == ActorView.GESTURE_NONE and v.idle_seconds() <= 0.0:
			break
