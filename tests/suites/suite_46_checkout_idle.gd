extends TestSuite
## Checkout dengan fase membungkus (GDD 21.4), durasi batch x3/x5 (GDD 18.5,
## 18.9), gerak menganggur pemain & staf (GDD 31.6), dan gelembung pikiran saat
## toko sepi (GDD 31.7).


func tests() -> Array:
	return [
		{"id": "ACC_21_PACKING", "name": "checkout ends with a 3 s packing phase, then payment, then the bag leaves with the customer", "fn": _packing},
		{"id": "ACC_18_BATCH_DURATION", "name": "x3/x5 batches multiply ingredients and yield but only stretch durations by 20%/40%", "fn": _batch_duration},
		{"id": "ACC_31_IDLE_GESTURES", "name": "idle player/staff wipe their face at 15 s and doze at 25 s of real time", "fn": _idle_gestures},
		{"id": "ACC_31_THOUGHTS", "name": "player thought bubbles appear only while the open shop has no customers", "fn": _thoughts},
	]


func _packing() -> void:
	var s: SimulationRoot = new_sim(515)
	PauseManager.clear_all()
	var pack: float = DataRegistry.packing_seconds()
	near(pack, 3.0, 0.0001, "packing lasts 3 s (GDD 21.4)")
	var lane: QueueLane = s.queue.main_lane()
	# 1. Waktu layan minimal 3 s: pemain & T1-T3 tetap, T4/T5 dijepit ke 3 s.
	near(s.cashier.expected_service_seconds(lane, &"customer_generic"), 7.0 * 1.5, 0.001, "manual service stays 10.5 s")
	var cases: Dictionary = {"staff_cashier_budi": 7.0, "staff_cashier_nadia": 5.0, "staff_cashier_maya": 3.5,
		"staff_cashier_hendra": 3.0, "staff_cashier_grace": 3.0}
	for sid: String in cases.keys():
		s.staff.lane_assign = {sid: lane.id}
		near(s.cashier.expected_service_seconds(lane, &"customer_generic"), float(cases[sid]), 0.001,
			"%s transaction lasts %.1f s" % [sid, float(cases[sid])])
	s.staff.lane_assign = {}
	# 2. Transaksi manual sungguhan sampai pembayaran.
	var bot := SimBot.new(s)
	var guard: int = 0
	while guard < 400000 and s.cashier.transaction_for(lane.id).is_empty() and s.is_running():
		bot.think()
		s.step(s.tick_seconds)
		guard += 1
	var td: Dictionary = s.cashier.transaction_for(lane.id)
	check(not td.is_empty(), "a manual transaction started on day 1")
	if td.is_empty():
		free_sim(s)
		return
	var c: Customer = s.customers.customer(td["customer"])
	near(float(td["duration"]), s.cashier.expected_service_seconds(lane, c.archetype), 0.001, "transaction uses the expected service time")
	var sounds: Array = [0]
	var on_sfx := func(id: StringName, _floor_id: StringName) -> void:
		if id == &"cashier_pack":
			sounds[0] += 1
	EventBus.sfx.connect(on_sfx)
	var cash_before: float = s.economy.balance
	var early_ok: bool = true
	var packing_ok: bool = true
	var saw_packing: bool = false
	var guard2: int = 0
	while guard2 < 20000 and not s.cashier.transaction_for(lane.id).is_empty():
		var t: Dictionary = s.cashier.transaction_for(lane.id)
		var remaining: float = float(t["duration"]) - float(t["elapsed"])
		var prog: float = s.cashier.packing_progress(lane.id)
		if remaining > pack + 0.001 and prog >= 0.0:
			early_ok = false
		if remaining < pack - s.tick_seconds:
			saw_packing = true
			if prog < 0.0 or c.state != Customer.BEING_SERVED or not is_equal_approx(s.economy.balance, cash_before):
				packing_ok = false
		s.step(s.tick_seconds)
		guard2 += 1
	EventBus.sfx.disconnect(on_sfx)
	check(early_ok, "no packing before the last 3 s of the transaction")
	check(saw_packing and packing_ok, "during packing the customer waits and no coins arrive yet")
	eq(int(sounds[0]), 1, "paper bag sound plays once, when packing starts")
	eq(c.state, Customer.CELEBRATING, "customer pays after packing")
	check(s.economy.balance > cash_before, "coins arrive only after packing (GDD 21.6)")
	# Pembeli yang sudah membayar pulang lewat CELEBRATING -> LEAVING, yaitu
	# satu-satunya jalur yang ditampilkan membawa kantong.
	s.run_for(3.0)
	check(c.state == Customer.LEAVING or c.state == Customer.DESPAWNED or s.customers.customer(c.id) == null,
		"paid customer walks out (with the paper bag)")
	free_sim(s)


func _batch_duration() -> void:
	var s: SimulationRoot = new_sim(616)
	var r: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var base_mix: float = s.production.mixer_stage_seconds(r, r.required_mixer_tier, 1, 1.0)
	var base_bake: float = s.production.oven_stage_seconds(r, r.required_oven_tier, 1, 1.0)
	near(s.production.mixer_stage_seconds(r, r.required_mixer_tier, 3, 1.0), base_mix * 1.2, 0.001, "x3 mixing only +20%")
	near(s.production.mixer_stage_seconds(r, r.required_mixer_tier, 5, 1.0), base_mix * 1.4, 0.001, "x5 mixing only +40%")
	near(s.production.oven_stage_seconds(r, r.required_oven_tier, 3, 1.0), base_bake * 1.2, 0.001, "x3 baking only +20%")
	near(s.production.oven_stage_seconds(r, r.required_oven_tier, 5, 1.0), base_bake * 1.4, 0.001, "x5 baking only +40%")
	# Job x5 sungguhan: bahan & hasil tetap x5.
	var j: ProductionJob = s.production.create_job(r.id, 5, &"test")
	check(j != null, "x5 job created from day 1 stock")
	if j == null:
		free_sim(s)
		return
	for ing: Variant in r.ingredients.keys():
		eq(int(j.reserved_ingredients.get(ing, 0)), int(r.ingredients[ing]) * 5, "x5 takes 5x %s" % ing)
	eq(j.quantity_output, r.batch_yield * 5, "x5 yields 5x bread")
	s.production.start_mixing(j.job_id, &"test", 1.0)
	near(j.stage_duration, base_mix * 1.4, 0.001, "real x5 mixing stage lasts base x1.4")
	free_sim(s)


func _idle_gestures() -> void:
	PauseManager.clear_all()
	var v := ActorView.new()
	runner.add_child(v)
	v.bind(&"player", "player|idle_test", CharacterFactory.spec_for_player("pria"))
	v.set_idle_enabled(true)
	v.set_busy(false)
	var a := SimActor.new()
	var wipe_at: float = DataRegistry.balf("presentation.idle_wipe_after_seconds")
	var doze_at: float = DataRegistry.balf("presentation.idle_doze_after_seconds")
	near(wipe_at, 15.0, 0.0001, "wipe after 15 s (GDD 31.6)")
	near(doze_at, 25.0, 0.0001, "doze after 25 s (GDD 31.6)")
	_run_view(v, a, 14.8)
	eq(v.gesture(), ActorView.GESTURE_NONE, "nothing special before 15 s")
	_run_view(v, a, 0.4)
	eq(v.gesture(), ActorView.GESTURE_WIPE, "wipes the face at 15 s")
	var cloth: Node = v.model.find_child("WipeCloth", true, false)
	check(cloth != null and (cloth as Node3D).visible, "a cloth appears in the right hand")
	eq(v.model.get_meta("mood"), "lega", "relieved face while wiping")
	var arm: Node3D = CharacterFactory.part(v.model, "ArmR")
	_run_view(v, a, 0.8)
	check(arm.rotation.z > 1.5, "right arm is raised to the face")
	_run_view(v, a, 2.0)
	eq(v.gesture(), ActorView.GESTURE_NONE, "wipe ends after the gesture")
	check(not (cloth as Node3D).visible, "cloth is put away")
	eq(v.model.get_meta("mood"), "senang", "normal face again")
	_run_view(v, a, doze_at - v.idle_seconds() + 0.2)
	eq(v.gesture(), ActorView.GESTURE_DOZE, "dozes at 25 s")
	eq(v.model.get_meta("mood"), "ngantuk", "sleepy face")
	var head: Node3D = CharacterFactory.part(v.model, "Head")
	_run_view(v, a, 2.0)
	check(head.rotation.x < -0.05, "head droops forward")
	check(v.find_child("SleepZ", true, false) != null, "floating Z letters appear")
	# Game di-pause: timer berhenti.
	var before: float = v.idle_seconds()
	PauseManager.push(&"test_idle")
	_run_view(v, a, 5.0)
	near(v.idle_seconds(), before, 0.0001, "idle timer freezes while paused")
	PauseManager.pop(&"test_idle")
	# Aktivitas apa pun mengembalikan pose normal seketika.
	v.set_busy(true)
	_run_view(v, a, 0.1)
	eq(v.gesture(), ActorView.GESTURE_NONE, "any activity ends the idle gesture")
	near(v.idle_seconds(), 0.0, 0.0001, "idle timer resets")
	eq(v.model.get_meta("mood"), "senang", "face back to normal")
	v.set_busy(false)
	a.moving = true
	_run_view(v, a, 20.0)
	eq(v.gesture(), ActorView.GESTURE_NONE, "walking never counts as idle")
	a.moving = false
	# Membungkus di meja kasir: lengan hampir mendatar di atas meja, tiap frame.
	v.set_action(&"pack")
	_run_view(v, a, 0.5)
	check(arm.rotation.x > 1.4, "packing holds both arms over the counter (%.2f rad)" % arm.rotation.x)
	eq(v.gesture(), ActorView.GESTURE_NONE, "packing is not idling")
	v.set_action(&"")
	_run_view(v, a, 0.1)
	check(arm.rotation.x < 0.5, "arms return after packing")
	# Pelanggan tidak pernah memakai gerak menganggur.
	var cust := ActorView.new()
	runner.add_child(cust)
	cust.bind(&"c1", "cust|test", CharacterFactory.spec_for_customer("customer_generic", 3))
	_run_view(cust, SimActor.new(), 30.0)
	eq(cust.gesture(), ActorView.GESTURE_NONE, "customers have no idle gestures")
	cust.queue_free()
	v.queue_free()
	PauseManager.clear_all()


func _thoughts() -> void:
	PauseManager.clear_all()
	eq(ThoughtBubble.key_for(9.9), "", "no thought before 10 s")
	eq(ThoughtBubble.key_for(10.0), "thought_quiet_1", "10 s: first thought")
	eq(ThoughtBubble.key_for(14.9), "thought_quiet_1", "each thought stays for 5 s")
	eq(ThoughtBubble.key_for(15.1), "", "then hides until the next one")
	eq(ThoughtBubble.key_for(20.5), "thought_quiet_2", "20 s: second thought")
	eq(ThoughtBubble.key_for(31.0), "thought_quiet_3", "30 s: third thought")
	eq(ThoughtBubble.key_for(44.0), "thought_quiet_4", "40 s: fourth thought")
	eq(ThoughtBubble.key_for(45.5), "", "no more thoughts after the fourth")
	for k: String in DataRegistry.THOUGHT_KEYS:
		check(DataRegistry.has_text(k), "%s has English text" % k)
	# Integrasi WorldView: toko buka, tidak ada pelanggan sama sekali.
	var s: SimulationRoot = new_sim(717)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	s.time.phase = TimeManager.OPEN
	s.customers.customers.clear()
	var bubble: ThoughtBubble = world.thought_bubble()
	world._update_thoughts(10.5)
	check(bubble.is_showing(), "bubble shows after 10 s with no customers")
	eq(bubble.current_key(), "thought_quiet_1", "first thought shown")
	eq(bubble.text().replace("\n", " "), Tx.t("thought_quiet_1"), "English text from the catalog (wrapped into lines)")
	# Ada pelanggan: gelembung langsung hilang dan hitungan diulang.
	s.customers.customers[&"cust_probe"] = Customer.new()
	world._update_thoughts(0.1)
	check(not bubble.is_showing(), "bubble hides as soon as a customer is in the shop")
	near(world.quiet_seconds(), 0.0, 0.0001, "quiet timer resets")
	s.customers.customers.erase(&"cust_probe")
	# Pause menghentikan hitungan.
	PauseManager.push(&"test_thought")
	world._update_thoughts(30.0)
	near(world.quiet_seconds(), 0.0, 0.0001, "quiet timer freezes while paused")
	PauseManager.pop(&"test_thought")
	# Toko belum buka: tidak ada pikiran walau sepi.
	s.time.phase = TimeManager.PREPARATION
	world._update_thoughts(50.0)
	check(not bubble.is_showing(), "no thought bubbles before the shop opens")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
	PauseManager.clear_all()


## Sinkronkan satu ActorView selama `seconds` detik nyata dengan langkah 0,1 s,
## persis seperti WorldView: sync() lalu set_carry() setiap frame.
func _run_view(v: ActorView, a: SimActor, seconds: float) -> void:
	var t: float = 0.0
	while t < seconds - 0.0001:
		var dt: float = minf(0.1, seconds - t)
		v.sync(a, dt, true)
		v.set_carry("")
		t += dt
