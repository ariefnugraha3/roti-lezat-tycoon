extends TestSuite
## Model KR/s dan penghasilan saat pergi (GDD idle 9): akurasi model terhadap
## simulasi hidup, rumus offline, dan popup Selamat Datang.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_MODEL_MATCH", "name": "idle 9.1 the steady-state KR/s model is within 20% of the live simulation's net income over 24 h at the Tier 1-5 sample shops and at a brand-new shop", "fn": _model_match},
		{"id": "ACC_IDLE_OFFLINE", "name": "idle 9.2-9.4 offline earnings = saved rate x min(away, cap) x efficiency; cap and efficiency grow with upgrades and perks up to 12 h and 100%; under a minute is ignored, under 5 min is credited quietly, longer waits for Collect (kept in the save); a clock that goes backwards earns nothing and resets; earnings count into the stats", "fn": _offline},
		{"id": "ACC_IDLE_WELCOME_BACK", "name": "idle 9.3, 9.5 coming back shows the Welcome Back popup (time away, amount, Pak Lurah, Collect) above an open sheet without closing it; Collect and Back credit the KR once; a short absence only shows a toast", "fn": _welcome},
	]


# ===========================================================================
# MODEL
# ===========================================================================

func _model_match() -> void:
	var cases: Array = [[0, 1], [1, 1], [2, 2], [3, 3], [4, 4], [5, 5]]
	for c: Array in cases:
		var tier: int = int(c[1])
		var bare: bool = int(c[0]) == 0
		var s: SimulationRoot = new_sim(7 + tier)
		if bare:
			s.tutorial.skip()
			ModelSample.no_boosts(s)
		else:
			ModelSample.build(s, tier)
		var r: Dictionary = ModelSample.measure(s, 1.0 if bare else 2.0, 24.0)
		var ratio: float = float(r["model"]) / maxf(float(r["live"]), 0.0001)
		print("      %s Tier %d: model %s/s, live %s/s, ratio %.3f" % ["new shop" if bare else "sample", tier,
			Tx.rate(float(r["model"])), Tx.rate(float(r["live"])), ratio])
		check(float(r["live"]) > 0.0, "the %s Tier %d shop earns" % ["new" if bare else "sample", tier])
		check(ratio >= 0.8 and ratio <= 1.2, "the %s Tier %d model is within 20%% of the live income (ratio %.3f)" % [
			"new shop" if bare else "sample", tier, ratio])
		free_sim(s)


# ===========================================================================
# OFFLINE
# ===========================================================================

func _offline_sim() -> SimulationRoot:
	var s: SimulationRoot = new_sim(901)
	s.tutorial.skip()
	return s


func _offline() -> void:
	var s: SimulationRoot = _offline_sim()
	var off: OfflineManager = s.offline
	# Acuan belum diketahui (profil baru): tidak ada penghasilan, acuan dipasang.
	off.now_override = 100000.0
	eq(off.settle(), {}, "an unknown reference earns nothing")
	near(off.last_active_unix, 100000.0, 0.001, "and starts the reference now")
	# Rate tersimpan = model tanpa boost.
	off.mark_active()
	near(off.rate_kr_per_s, s.idle_economy.rate(false), 1e-9, "the saved rate is the model KR/s without boosts")
	off.rate_kr_per_s = 10.0
	near(off.cap_seconds(), 2.0 * 3600.0, 0.001, "the base cap is 2 h")
	near(off.efficiency(), 0.5, 1e-9, "the base efficiency is 50%")
	# Satu jam pergi: popup, KR menunggu Collect.
	var bal0: float = s.economy.balance
	var run0: float = s.statistics.get_stat("run_earned_kr")
	var all0: float = s.statistics.get_stat("alltime_earned_kr")
	off.now_override = 100000.0 + 3600.0
	var r: Dictionary = off.settle()
	near(float(r.get("amount", 0.0)), 10.0 * 3600.0 * 0.5, 0.001, "1 h away at 10 KR/s and 50% earns 18,000")
	check(bool(r.get("popup", false)), "an hour away asks for the Welcome Back popup")
	near(s.economy.balance, bal0, 0.001, "nothing is credited before Collect")
	near(float(off.pending.get("amount", 0.0)), 18000.0, 0.001, "the amount waits in pending")
	# Pending ikut save/load.
	var saved: Dictionary = json_copy(s.capture_save())
	check(saved.has("offline") and (saved["offline"] as Dictionary).has("last_active_unix") and (saved["offline"] as Dictionary).has("rate_kr_per_s"),
		"the save keeps offline.last_active_unix and rate_kr_per_s")
	var s2: SimulationRoot = load_sim(saved)
	near(float(s2.offline.pending.get("amount", 0.0)), 18000.0, 0.001, "pending survives a save and load")
	near(s2.offline.last_active_unix, off.last_active_unix, 0.001, "and so does the reference")
	free_sim(s2)
	near(off.collect(), 18000.0, 0.001, "Collect returns the amount")
	near(s.economy.balance, bal0 + 18000.0, 0.001, "Collect credits it")
	eq(off.pending, {}, "and clears pending")
	near(off.collect(), 0.0, 0.001, "a second Collect gives nothing")
	near(s.economy.balance, bal0 + 18000.0, 0.001, "so the KR is credited once")
	var entry: Dictionary = s.economy.ledger[s.economy.ledger.size() - 1]
	eq(str(entry["category"]), "OFFLINE_EARNINGS", "the ledger entry is OFFLINE_EARNINGS")
	near(s.statistics.get_stat("run_earned_kr") - run0, 18000.0, 0.001, "it counts into run_earned_kr")
	near(s.statistics.get_stat("alltime_earned_kr") - all0, 18000.0, 0.001, "and alltime_earned_kr")
	near(s.statistics.get_stat("offline_seconds_total"), 3600.0, 0.001, "the time away is counted")
	near(s.statistics.get_stat("offline_earned_kr"), 18000.0, 0.001, "and the offline earnings")
	# Batas: 5 jam pergi dihitung 2 jam.
	off.rate_kr_per_s = 10.0
	off.last_active_unix = 200000.0
	off.now_override = 200000.0 + 5.0 * 3600.0
	r = off.settle()
	near(float(r["seconds"]), 7200.0, 0.001, "5 h away counts as the 2 h cap")
	near(float(r["away"]), 5.0 * 3600.0, 0.001, "while the real time away is kept for the popup")
	near(float(r["amount"]), 10.0 * 7200.0 * 0.5, 0.001, "and earns 2 h worth")
	off.collect()
	# Upgrade global dan perk menaikkan batas dan efisiensi sampai 12 jam / 100%.
	s.upgrades.global_levels[&"global_offline_hours"] = 3
	near(off.cap_seconds(), 5.0 * 3600.0, 0.001, "+1 h per Longer Away Shifts level")
	s.prestige.stars = int(DataRegistry.perk(&"perk_offline_plus").get("stars", 1))
	near(off.cap_seconds(), 6.0 * 3600.0, 0.001, "the offline perk adds 1 h")
	s.upgrades.global_levels[&"global_offline_hours"] = 40
	near(off.cap_seconds(), 12.0 * 3600.0, 0.001, "the cap never passes 12 h")
	s.upgrades.global_levels[&"global_offline_efficiency"] = 4
	near(off.efficiency(), 0.7, 1e-9, "+5% per Trusted Night Crew level")
	s.prestige.stars = int(DataRegistry.perk(&"perk_offline_efficiency").get("stars", 50))
	near(off.efficiency(), 0.95, 1e-9, "the efficiency perk adds 25%")
	s.upgrades.global_levels[&"global_offline_efficiency"] = 10
	near(off.efficiency(), 1.0, 1e-9, "efficiency never passes 100%")
	s.upgrades.global_levels.clear()
	s.prestige.stars = 0
	# Di bawah satu menit diabaikan.
	off.rate_kr_per_s = 10.0
	off.last_active_unix = 300000.0
	off.now_override = 300030.0
	var bal1: float = s.economy.balance
	eq(off.settle(), {}, "30 s away is ignored")
	near(off.last_active_unix, 300030.0, 0.001, "and the reference moves on")
	near(s.economy.balance, bal1, 0.001, "nothing is credited")
	# 1-5 menit: langsung masuk tanpa popup.
	off.rate_kr_per_s = 10.0
	off.now_override = 300030.0 + 120.0
	r = off.settle()
	check(not bool(r.get("popup", true)), "2 min away needs no popup")
	near(s.economy.balance, bal1 + 10.0 * 120.0 * 0.5, 0.001, "and is credited at once")
	eq(off.pending, {}, "nothing waits in pending")
	# Jam mundur: tidak ada penghasilan dan acuan direset.
	off.rate_kr_per_s = 10.0
	off.last_active_unix = 500000.0
	off.now_override = 400000.0
	var bal2: float = s.economy.balance
	eq(off.settle(), {}, "a clock that went backwards earns nothing")
	near(off.last_active_unix, 400000.0, 0.001, "and resets the reference")
	near(s.economy.balance, bal2, 0.001, "the balance is untouched")
	off.rate_kr_per_s = 10.0
	off.now_override = 400000.0 + 600.0
	near(float(off.settle().get("amount", 0.0)), 10.0 * 600.0 * 0.5, 0.001, "counting resumes from the reset reference")
	off.collect()
	# Di latar: acuan dibekukan, save di latar tidak menghapus waktu pergi.
	off.now_override = 600000.0
	off.freeze()
	off.rate_kr_per_s = 10.0
	off.now_override = 600500.0
	off.mark_active()
	near(off.last_active_unix, 600000.0, 0.001, "a save while in the background keeps the reference")
	off.now_override = 601000.0
	r = off.thaw()
	near(float(r.get("away", 0.0)), 1000.0, 0.001, "coming back counts the whole time in the background")
	check(not off.is_frozen(), "and unfreezes")
	off.collect()
	free_sim(s)


# ===========================================================================
# POPUP
# ===========================================================================

func _boot(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_offline_ui"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", label)
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


func _frames(n: int) -> void:
	for i in n:
		await runner.get_tree().process_frame


func _welcome() -> void:
	var game: GameRoot = await _boot("Welcome Bakery")
	var sim: SimulationRoot = game.sim
	var off: OfflineManager = sim.offline
	game.modals.open(&"upgrades")
	await _frames(2)
	off.now_override = 1000000.0
	off.mark_active()
	off.rate_kr_per_s = 4.0
	off.now_override = 1000000.0 + 2.0 * 3600.0 + 15.0 * 60.0
	var bal0: float = sim.economy.balance
	game.check_offline()
	await _frames(2)
	check(game.modals.is_open(&"welcome_back"), "2 h 15 min away opens the Welcome Back popup")
	check(game.modals.top() is WelcomeBackScreen, "the popup is on top")
	check(game.modals.is_open(&"upgrades"), "the open Upgrades sheet stays open under it")
	check(PauseManager.is_paused(), "the game waits while the popup is open")
	var pop: WelcomeBackScreen = game.modals.top() as WelcomeBackScreen
	var amount: float = 4.0 * 7200.0 * 0.5
	var body: Label = pop.find_child("AwayText", true, false) as Label
	check(body != null and body.text == Tx.t("ui_welcome_back_body", {"time": Tx.duration(8100.0), "amount": Tx.kr(amount)}),
		"the body says the real time away and the amount")
	check(body != null and body.text.contains("2 h 15 min"), "the time away reads '2 h 15 min'")
	check(pop.find_child("Lurah", true, false) is LurahPortrait, "Pak Lurah greets the player")
	check(pop.find_child("Capped", true, false) != null, "a note explains the 2 h cap")
	var info: Label = pop.find_child("CapInfo", true, false) as Label
	check(info != null and info.text == Tx.t("ui_offline_cap", {"hours": "2", "percent": 50}), "the cap and efficiency are shown")
	var collect: Button = pop.find_child("Collect", true, false) as Button
	check(collect != null and collect.size.y >= 48.0, "Collect is a full-size button")
	near(sim.economy.balance, bal0, 0.001, "nothing is credited before Collect")
	collect.pressed.emit()
	await _frames(2)
	near(sim.economy.balance, bal0 + amount, 0.001, "Collect credits the earnings")
	check(not game.modals.is_open(&"welcome_back"), "and closes the popup")
	check(game.modals.is_open(&"upgrades"), "the sheet is still there")
	check(game.hud.find_child("CoinShowerFX", true, false) != null or SettingsManager.reduced_motion(), "coins shower over the HUD")
	# Back sama dengan Collect.
	off.rate_kr_per_s = 4.0
	off.now_override += 3600.0
	game.check_offline()
	await _frames(2)
	var bal1: float = sim.economy.balance
	check(game.modals.is_open(&"welcome_back"), "another hour away opens it again")
	game.modals.top().on_back()
	await _frames(2)
	near(sim.economy.balance, bal1 + 4.0 * 3600.0 * 0.5, 0.001, "Back collects too")
	check(not game.modals.is_open(&"welcome_back"), "and closes it")
	# Pergi sebentar: toast saja.
	off.rate_kr_per_s = 4.0
	off.now_override += 120.0
	var bal2: float = sim.economy.balance
	game.check_offline()
	await _frames(2)
	check(not game.modals.is_open(&"welcome_back"), "2 min away shows no popup")
	near(sim.economy.balance, bal2 + 4.0 * 120.0 * 0.5, 0.001, "but the KR is already in")
	var toast_text: String = Tx.t("ui_offline_toast", {"amount": Tx.kr(4.0 * 120.0 * 0.5)})
	var toasts: Node = game.hud.find_child("Toasts", true, false)
	var found: bool = false
	for c: Node in toasts.get_children():
		if str(c.get_meta("text", "")) == toast_text:
			found = true
	check(found, "a small toast says what came in")
	off.now_override = -1.0
	await _finish(game)
