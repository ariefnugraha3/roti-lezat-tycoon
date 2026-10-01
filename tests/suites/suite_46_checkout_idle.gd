extends TestSuite
## Checkout yang seluruhnya fase membungkus (GDD 21.4), durasi batch x3/x5 (GDD
## 18.5, 18.9), gerak menganggur pemain & staf (GDD 31.6), dan gelembung pikiran
## saat toko sepi (GDD 31.7).


func tests() -> Array:
	return [
		{"id": "ACC_21_PACKING", "name": "every checkout is a 3 s packing phase from its first moment, then payment, then the bag leaves with the customer", "fn": _packing},
		{"id": "ACC_31_DOZE_AFTER_THOUGHTS", "name": "the player falls asleep when the last quiet-shop thought ends (45 s), never under a bubble", "fn": _doze_after_thoughts},
		{"id": "ACC_21_PACK_CHOREOGRAPHY", "name": "packing reads as open bag, bread hops in one by one, ribbon, offer; cashier and customer hands follow", "fn": _pack_choreography},
		{"id": "ACC_18_BATCH_DURATION", "name": "x3/x5 batches multiply ingredients and yield but only stretch durations by 20%/40%", "fn": _batch_duration},
		{"id": "ACC_31_IDLE_GESTURES", "name": "idle player/staff wipe their face every 7.5 s; staff doze at 12.5 s, the player at 45 s", "fn": _idle_gestures},
		{"id": "ACC_31_THOUGHTS", "name": "player thought bubbles appear every 10 s only while the open shop has no customers", "fn": _thoughts},
	]


func _packing() -> void:
	var s: SimulationRoot = new_sim(515)
	PauseManager.clear_all()
	var pack: float = DataRegistry.packing_seconds()
	near(pack, 3.0, 0.0001, "packing lasts 3 s (GDD 21.4)")
	# 1. Transaksi = fase membungkus, sama untuk semua (keputusan maintainer 2026-09-30).
	near(CashierManager.transaction_seconds(), pack, 0.0001, "every transaction lasts exactly the packing phase")
	var lane: QueueLane = s.queue.main_lane()
	# 2. Transaksi manual sungguhan sampai pembayaran.
	var sounds: Array = [0]
	var on_sfx := func(id: StringName, _floor_id: StringName) -> void:
		if id == &"cashier_pack":
			sounds[0] += 1
	EventBus.sfx.connect(on_sfx)
	var bot := SimBot.new(s)
	var guard: int = 0
	while guard < 400000 and s.cashier.transaction_for(lane.id).is_empty() and s.is_running():
		bot.think()
		s.step(s.tick_seconds)
		guard += 1
	var td: Dictionary = s.cashier.transaction_for(lane.id)
	check(not td.is_empty(), "a manual transaction started on day 1")
	if td.is_empty():
		EventBus.sfx.disconnect(on_sfx)
		free_sim(s)
		return
	var c: Customer = s.customers.customer(td["customer"])
	check(bool(td["manual"]), "the player serves it (no cashier on day 1)")
	near(float(td["duration"]), pack, 0.001, "the player's checkout lasts 3 s")
	var cash_before: float = s.economy.balance
	var packing_ok: bool = true
	var guard2: int = 0
	while guard2 < 20000 and not s.cashier.transaction_for(lane.id).is_empty():
		var t: Dictionary = s.cashier.transaction_for(lane.id)
		var prog: float = s.cashier.packing_progress(lane.id)
		# Packing sejak detik pertama: progres tidak pernah -1 dan mengikuti waktu.
		if prog < 0.0 or absf(prog - float(t["elapsed"]) / float(t["duration"])) > 0.001:
			packing_ok = false
		if c.state != Customer.BEING_SERVED or not is_equal_approx(s.economy.balance, cash_before):
			packing_ok = false
		s.step(s.tick_seconds)
		guard2 += 1
	EventBus.sfx.disconnect(on_sfx)
	check(packing_ok, "packing runs from the first moment; the customer waits and no coins arrive yet")
	check(float(guard2) * s.tick_seconds <= pack + 0.001, "the whole checkout took no longer than 3 s")
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
	var every: float = DataRegistry.balf("presentation.idle_wipe_every_seconds")
	var staff_doze: float = DataRegistry.balf("presentation.staff_doze_after_seconds")
	var player_doze: float = DataRegistry.player_doze_after_seconds()
	near(every, 7.5, 0.0001, "a face wipe every 7.5 s (GDD 31.6)")
	near(staff_doze, 12.5, 0.0001, "staff doze after 12.5 s (GDD 31.6)")
	near(player_doze, 45.0, 0.0001, "the player dozes when the last thought ends: 40 s + 5 s")
	# Staf: ambang tidur bawaan.
	var v := ActorView.new()
	runner.add_child(v)
	v.bind(&"staff_cashier_budi", "staff|idle_test", CharacterFactory.spec_for_player("pria"))
	v.set_idle_enabled(true)
	v.set_busy(false)
	near(v.doze_after(), staff_doze, 0.0001, "views use the staff threshold unless told otherwise")
	var a := SimActor.new()
	_run_view(v, a, every - 0.2)
	eq(v.gesture(), ActorView.GESTURE_NONE, "nothing special before 7.5 s")
	_run_view(v, a, 0.4)
	eq(v.gesture(), ActorView.GESTURE_WIPE, "wipes the face at 7.5 s")
	var cloth: Node = v.model.find_child("WipeCloth", true, false)
	check(cloth != null and (cloth as Node3D).visible, "a cloth appears in the right hand")
	eq(v.model.get_meta("mood"), "lega", "relieved face while wiping")
	var arm: Node3D = CharacterFactory.part(v.model, "ArmR")
	_run_view(v, a, 0.3)
	check(arm.rotation.z > 1.5, "right arm is raised to the face")
	_run_view(v, a, 2.0)
	eq(v.gesture(), ActorView.GESTURE_NONE, "wipe ends after the gesture")
	check(not (cloth as Node3D).visible, "cloth is put away")
	eq(v.model.get_meta("mood"), "senang", "normal face again")
	_run_view(v, a, staff_doze - v.idle_seconds() + 0.2)
	eq(v.gesture(), ActorView.GESTURE_DOZE, "staff doze at 12.5 s")
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
	# Pemain: lap wajah di detik 7,5, 15, 22,5, 30, 37,5, lalu tidur di detik 45.
	var pv := ActorView.new()
	runner.add_child(pv)
	pv.bind(&"player", "player|idle_test", CharacterFactory.spec_for_player("wanita"))
	pv.set_idle_enabled(true)
	pv.set_busy(false)
	pv.set_doze_after(player_doze)
	var pa := SimActor.new()
	var wipes: int = 0
	var marks_ok: bool = true
	var last: int = ActorView.GESTURE_NONE
	var first_doze: float = -1.0
	while pv.idle_seconds() < 50.0:
		_run_view(pv, pa, 0.1)
		var g: int = pv.gesture()
		if g == ActorView.GESTURE_WIPE and last != ActorView.GESTURE_WIPE:
			wipes += 1
			if fposmod(pv.idle_seconds(), every) > 0.25:
				marks_ok = false
		if g == ActorView.GESTURE_DOZE and first_doze < 0.0:
			first_doze = pv.idle_seconds()
		last = g
	eq(wipes, 5, "the player wipes five times before sleeping (7.5/15/22.5/30/37.5 s)")
	check(marks_ok, "every wipe starts on a 7.5 s mark")
	check(first_doze >= player_doze - 0.001 and first_doze < player_doze + 0.25, "the player falls asleep at 45 s (%.2f)" % first_doze)
	# Tidur ditahan (rangkaian pikiran toko sepi belum selesai): lap tetap berulang.
	pv.set_doze_blocked(true)
	var wiped_while_blocked: bool = false
	var slept_while_blocked: bool = false
	for i in 200:
		_run_view(pv, pa, 0.1)
		wiped_while_blocked = wiped_while_blocked or pv.gesture() == ActorView.GESTURE_WIPE
		slept_while_blocked = slept_while_blocked or pv.gesture() == ActorView.GESTURE_DOZE
	check(not slept_while_blocked, "no sleep while it is held back")
	check(wiped_while_blocked, "face wipes keep coming while sleep is held back")
	pv.set_doze_blocked(false)
	_run_view(pv, pa, 0.1)
	eq(pv.gesture(), ActorView.GESTURE_DOZE, "sleeps as soon as the hold is lifted")
	# Pelanggan tidak pernah memakai gerak menganggur.
	var cust := ActorView.new()
	runner.add_child(cust)
	cust.bind(&"c1", "cust|test", CharacterFactory.spec_for_customer("customer_generic", 3))
	_run_view(cust, SimActor.new(), 30.0)
	eq(cust.gesture(), ActorView.GESTURE_NONE, "customers have no idle gestures")
	cust.queue_free()
	pv.queue_free()
	v.queue_free()
	PauseManager.clear_all()


func _thoughts() -> void:
	PauseManager.clear_all()
	eq(ThoughtBubble.key_for(9.9), "", "no thought before 10 s")
	eq(ThoughtBubble.key_for(10.0), "thought_quiet_1", "10 s: first thought")
	eq(ThoughtBubble.key_for(14.9), "thought_quiet_1", "each thought stays for 5 s")
	eq(ThoughtBubble.key_for(15.1), "", "then hides until the next one")
	eq(ThoughtBubble.key_for(19.9), "", "nothing between thoughts")
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


## Koreografi membungkus (GDD 21.4): PackBagRig dan pose kasir memakai babak
## yang sama; pembeli mengulurkan tangan saat kantong disodorkan.
func _pack_choreography() -> void:
	var toward := Vector3(0.0, 0.0, 1.0)
	var rig := PackBagRig.new()
	runner.add_child(rig)
	rig.setup("loaf.plain", 3, toward)
	var ph: Vector3 = ProceduralAnimationSystem.pack_phases(3)
	check(rig.bag().scale.y < PackBagRig.BAG_SCALE * 0.5, "the bag starts folded")
	rig.animate(ph.x)
	near(rig.bag().scale.y, PackBagRig.BAG_SCALE, 0.02, "the bag is open after the opening beat")
	for i in 3:
		check(rig.bread(i).visible and rig.bread(i).position.y < 0.001, "bread %d waits on the counter" % i)
	var w: Vector2 = ProceduralAnimationSystem.pack_bread_window(0, 3)
	rig.animate(lerpf(w.x, w.y, 0.62))
	check(rig.bread(0).position.y > PackBagRig.MOUTH_Y, "the first bread arcs above the bag mouth")
	check(rig.bread(1).position.y < 0.001, "the next bread still waits")
	rig.animate(w.y + 0.001)
	check(not rig.bread(0).visible, "the first bread is inside the bag")
	rig.animate(lerpf(ph.y, ph.z, 0.6))
	check((rig.bag().get_node("Seal") as Node3D).visible, "the ribbon appears")
	check((rig.bag().get_node("Peek") as Node3D).visible, "the top bread peeks out")
	rig.animate(ph.z + ProceduralAnimationSystem.PACK_OFFER_SPAN)
	near(rig.bag().position.z, PackBagRig.OFFER_SLIDE, 0.005, "the bag slides toward the customer")
	# Event: satu per roti dan satu untuk pita, meski digerakkan langkah kecil.
	var rig2 := PackBagRig.new()
	runner.add_child(rig2)
	rig2.setup("loaf.plain", 3, toward)
	var ins: int = 0
	var seals: int = 0
	var p: float = 0.0
	while p <= 1.0:
		for ev: StringName in rig2.animate(p):
			if ev == &"bread_in":
				ins += 1
			elif ev == &"sealed":
				seals += 1
		p += 0.004
	eq(ins, 3, "one bread_in event per bread")
	eq(seals, 1, "one seal event")
	var rig3 := PackBagRig.new()
	runner.add_child(rig3)
	rig3.setup("loaf.plain", 3, toward)
	eq(rig3.animate(0.95).size(), 0, "a bag rebuilt late in the phase replays no events")
	# Roti sedikit: babak berikutnya maju, lompatan roti tetap singkat.
	var ph1: Vector3 = ProceduralAnimationSystem.pack_phases(1)
	check(ph1.y < ph.y, "one bread reaches the ribbon earlier")
	check(ph1.y - ph1.x <= ProceduralAnimationSystem.PACK_BREAD_SPAN_MAX + 0.0001, "a single bread still hops briskly")
	# Kasir: tangan kiri mengambil roti, tangan kanan menahan; menyodorkan meluruskan keduanya.
	var cv := ActorView.new()
	runner.add_child(cv)
	cv.bind(&"player", "player|pack_test", CharacterFactory.spec_for_player("pria"))
	cv.set_action(&"pack")
	var arm_l: Node3D = CharacterFactory.part(cv.model, "ArmL")
	var arm_r: Node3D = CharacterFactory.part(cv.model, "ArmR")
	var a := SimActor.new()
	cv.set_pack_progress(lerpf(w.x, w.y, 0.65), 3)
	cv.sync(a, 0.05, true)
	check(arm_l.rotation.x > arm_r.rotation.x + 0.2, "the left hand lifts the bread while the right hand holds the bag")
	cv.set_pack_progress(ph.z + ProceduralAnimationSystem.PACK_OFFER_SPAN * 0.5, 3)
	cv.sync(a, 0.05, true)
	check(arm_l.rotation.x > ProceduralAnimationSystem.PACK_ARM_PITCH + 0.15 and arm_r.rotation.x > ProceduralAnimationSystem.PACK_ARM_PITCH + 0.15, "both arms stretch out to offer the bag")
	# Pembeli: mengulurkan tangan, lalu kembali normal.
	var bv := ActorView.new()
	runner.add_child(bv)
	bv.bind(&"customer_school_child", "cust|pack_test", CharacterFactory.spec_for_player("wanita"))
	var b_arm: Node3D = CharacterFactory.part(bv.model, "ArmL")
	bv.set_receive(1.0)
	bv.sync(a, 0.05, true)
	check(b_arm.rotation.x > ProceduralAnimationSystem.RECEIVE_ARM_PITCH - 0.1, "the customer reaches out for the bag")
	bv.set_receive(0.0)
	bv.sync(a, 0.05, true)
	check(b_arm.rotation.x < 0.5, "the customer's arms relax again")
	for n: Node in [rig, rig2, rig3, cv, bv]:
		n.queue_free()


## Pemain di toko sepi (GDD 31.6, 31.7): gelembung pikiran di detik 20/40/60/80,
## lalu tertidur tepat saat gelembung terakhir hilang (detik 85), tidak pernah
## saat gelembung tampil. Di persiapan pun tidurnya di detik 85. Yang tertidur
## sejak persiapan terbangun saat toko buka sepi.
func _doze_after_thoughts() -> void:
	PauseManager.clear_all()
	var after: Array = DataRegistry.bal("presentation.thought_after_seconds")
	var doze_at: float = DataRegistry.player_doze_after_seconds()
	near(doze_at, float(after[after.size() - 1]) + DataRegistry.balf("presentation.thought_show_seconds"), 0.0001,
		"sleep comes exactly when the last thought bubble ends")
	near(doze_at, 45.0, 0.0001, "the last thought (40 s) ends at 45 s")
	var s: SimulationRoot = new_sim(718)
	s.tutorial.skip()
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	var pv: ActorView = world.views.get(s.player.actor.id)
	var bubble: ThoughtBubble = world.thought_bubble()
	# Persiapan: tanpa gelembung, tetap baru tertidur di detik 85 (sama seperti toko sepi).
	var prep_doze: float = -1.0
	for i in 360:
		world._process(0.25)
		if pv.gesture() == ActorView.GESTURE_DOZE and prep_doze < 0.0:
			prep_doze = pv.idle_seconds()
	check(prep_doze >= doze_at - 0.001 and prep_doze < doze_at + 0.5, "idle during preparation: asleep at 45 s too (got %.2f)" % prep_doze)
	eq(pv.gesture(), ActorView.GESTURE_DOZE, "stays asleep")
	# Toko buka dan sepi: terbangun, berpikir, baru tertidur di detik 85.
	s.time.phase = TimeManager.OPEN
	s.customers.customers.clear()
	var overlap: bool = false
	var first_doze: float = -1.0
	var thoughts_seen: int = 0
	var last_key: String = ""
	world._process(0.25)
	check(pv.gesture() != ActorView.GESTURE_DOZE, "the player wakes up when the quiet shop opens")
	for i2 in 400:
		world._process(0.25)
		if pv.gesture() == ActorView.GESTURE_DOZE and bubble.is_showing():
			overlap = true
		if pv.gesture() == ActorView.GESTURE_DOZE and first_doze < 0.0:
			first_doze = world.quiet_seconds()
		if bubble.is_showing() and bubble.current_key() != last_key:
			last_key = bubble.current_key()
			thoughts_seen += 1
	check(not overlap, "never asleep while a thought bubble shows")
	eq(thoughts_seen, 4, "all four thoughts play before sleep")
	check(first_doze >= doze_at - 0.001 and first_doze < doze_at + 0.5, "falls asleep at 45 s of quiet (got %.2f)" % first_doze)
	eq(pv.gesture(), ActorView.GESTURE_DOZE, "stays asleep afterwards")
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
