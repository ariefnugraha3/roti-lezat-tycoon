extends TestSuite
## Monetisasi (GDD idle 22): iklan berhadiah yang dipilih pemain, Supporter
## Pack, dan preset portal web. Semua lewat TestMonetizationProvider; tidak ada
## SDK sungguhan di tes.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_ADS", "name": "idle 22.1, 22.3 rewarded ads: buttons hide without ads, the shop pauses and goes quiet while one plays, the reward comes only after a finished ad and spends one of the day's turns, a failed ad costs nothing, turns refill on a new device day, and Collect x2, another coffee, skip wait and golden x2 give their rewards", "fn": _ads},
		{"id": "ACC_IDLE_SUPPORTER", "name": "idle 22.4 Supporter Pack: shown in Shop only when a store exists, buying makes every ad reward free without an ad, survives a restart, comes back with Restore, and puts the Supporter Heart badge in the profile's decorations", "fn": _supporter},
		{"id": "ACC_IDLE_PORTALS", "name": "idle 22.2 the CrazyGames and Poki presets load their SDK with their feature tag and no PWA, the plain Web build loads none, desktop has no ad provider, and the portal hears loading finished and gameplay start/stop", "fn": _portals},
	]


func _setup_ads() -> TestMonetizationProvider:
	Monetization.path = "user://test_monetization.json"
	Monetization.reset_for_tests()
	var p := TestMonetizationProvider.new()
	Monetization.use_provider(p)
	return p


func _teardown_ads() -> void:
	Monetization.reset_for_tests()
	Monetization.use_provider(MonetizationProvider.new())
	Monetization.path = "user://monetization.json"
	BoostManager.date_override = ""
	PauseManager.clear_all()
	AudioManager.stop_all_sounds()


func _ads() -> void:
	BoostManager.date_override = "2026-11-05"
	Monetization.path = "user://test_monetization.json"
	Monetization.reset_for_tests()
	Monetization.use_provider(MonetizationProvider.new())
	for id: StringName in [&"offline_double", &"coffee_refill", &"promo_skip", &"golden_double"]:
		check(not Monetization.can_offer(id), "%s is not offered without an ad provider" % id)
	var b: Button = AdButton.make(&"coffee_refill", "Another cup")
	check(not b.visible, "an ad button hides without ads")
	var p: TestMonetizationProvider = _setup_ads()
	AdButton.refresh(b)
	check(b.visible, "it shows once ads are ready")
	check((b.get_meta("caption") as Label).text.contains("Ad"), "and says an ad will play (%s)" % (b.get_meta("caption") as Label).text)
	b.free()
	var per_day: int = int(Monetization.placement(&"coffee_refill")["per_day"])
	eq(Monetization.left_today(&"coffee_refill"), per_day, "a full day of coffee refills")
	var got: Array = []
	Monetization.show_rewarded(&"coffee_refill", func(ok: bool) -> void: got.append(ok))
	check(p.showing(), "the ad is playing")
	check(PauseManager.has(Monetization.PAUSE_REASON), "the shop pauses during the ad")
	check(AudioManager.ad_muted, "and goes quiet")
	check(not Monetization.can_offer(&"golden_double"), "no second ad while one plays")
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq(got, [true], "a finished ad reports success once")
	check(not PauseManager.has(Monetization.PAUSE_REASON) and not AudioManager.ad_muted, "the shop runs and sounds again")
	eq(Monetization.left_today(&"coffee_refill"), per_day - 1, "one turn used")
	p.succeed = false
	got.clear()
	Monetization.show_rewarded(&"coffee_refill", func(ok: bool) -> void: got.append(ok))
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq(got, [false], "an unfinished ad gives nothing")
	eq(Monetization.left_today(&"coffee_refill"), per_day - 1, "and keeps the turn")
	p.succeed = true
	for i in per_day:
		Monetization.show_rewarded(&"coffee_refill", func(_ok: bool) -> void: pass)
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
	eq(Monetization.left_today(&"coffee_refill"), 0, "the day's refills run out")
	check(not Monetization.can_offer(&"coffee_refill"), "and the button hides")
	BoostManager.date_override = "2026-11-06"
	eq(Monetization.left_today(&"coffee_refill"), per_day, "a new device day refills them")
	# Hadiah di game sungguhan.
	SaveManager.dir = "user://test_saves_ads"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", "Ad Bakery")
	await runner.get_tree().process_frame
	game.sim.tutorial.skip()
	game.modals.close_all()
	game.playing = false
	PauseManager.clear_all()
	var s: SimulationRoot = game.sim
	# Collect ×2.
	s.offline.pending = {"amount": 100.0, "seconds": 600.0, "away": 600.0}
	var wb: UIScreen = game.modals.open(&"welcome_back")
	await runner.get_tree().process_frame
	var dbl: Button = wb.find_child("Ad_offline_double", true, false) as Button
	check(dbl != null and dbl.visible, "Welcome Back offers Collect x2")
	var before: float = s.economy.balance
	if dbl != null:
		dbl.pressed.emit()
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
	near(s.economy.balance - before, 100.0 * float(Monetization.placement(&"offline_double")["mult"]), 0.01, "Collect x2 credits double after the ad")
	check(not game.modals.is_open(&"welcome_back"), "and closes the popup")
	# Kopi lagi.
	var up: UIScreen = game.modals.open(&"upgrades")
	await runner.get_tree().process_frame
	(up as UpgradesScreen).tick_page()
	var coffee: Control = up.find_child("Coffee", true, false) as Control
	check(coffee != null and coffee.visible, "Upgrades offers another cup of coffee")
	var cb: Button = up.find_child("Ad_coffee_refill", true, false) as Button
	# Kopi harian hari ini sudah dituang saat game mulai: mulai dari tanpa boost.
	s.boosts.new_run()
	var mult0: float = s.boosts.income_now()
	if cb != null:
		cb.pressed.emit()
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
	near(s.boosts.income_now(), DataRegistry.idlef("boosts.daily_gift.mult") * mult0, 1e-6, "the coffee boost runs")
	# Lewati jeda promosi.
	s.debug_add_kr(1.0e6)
	check(s.boosts.start_promo(&"promo_flyer"), "a promotion starts")
	s.boosts.promo_left = 0.0
	s.boosts.promo_id = &""
	(up as UpgradesScreen).tick_page()
	var skip: Button = up.find_child("Promo_promo_flyer", true, false).find_child("Skip", true, false) as Button
	check(skip != null and skip.visible, "a cooling promotion offers Skip wait")
	var radio_skip: Button = up.find_child("Promo_promo_radio", true, false).find_child("Skip", true, false) as Button
	check(radio_skip != null and not radio_skip.visible, "a ready promotion does not")
	if skip != null:
		skip.pressed.emit()
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
	eq(s.boosts.cooldown_left(&"promo_flyer"), 0.0, "the wait is over")
	eq(s.boosts.promo_block(&"promo_flyer"), &"", "and the promotion can start again")
	game.modals.close_all()
	# Roti emas ×2.
	var golden: GoldenBread = game.hud.golden
	check(golden != null, "the HUD has the golden bread layer")
	if golden != null:
		# Tawaran sesudah roti emas berhadiah 12 KR tertangkap.
		var kr0: float = s.economy.balance
		golden._double_kr = 12.0
		golden._double_left = 5.0
		golden._tick_double(0.0)
		check(golden.double_button.visible, "a caught golden bread offers x2")
		golden.double_button.pressed.emit()
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		near(s.economy.balance - kr0, 12.0, 0.01, "x2 credits the golden KR once more")
		check(not golden.double_button.visible, "and the offer goes away")
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	_teardown_ads()


func _supporter() -> void:
	BoostManager.date_override = "2026-11-05"
	var p: TestMonetizationProvider = _setup_ads()
	p.store = false
	SaveManager.dir = "user://test_saves_supporter"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "male", "Fan Bakery")
	await runner.get_tree().process_frame
	game.sim.tutorial.skip()
	game.modals.close_all()
	game.playing = false
	PauseManager.clear_all()
	var shop: UIScreen = game.modals.open(&"shop")
	await runner.get_tree().process_frame
	check(shop.find_child("Supporter", true, false) == null, "no Supporter Pack without a store")
	game.modals.close_all()
	p.store = true
	shop = game.modals.open(&"shop")
	await runner.get_tree().process_frame
	var buy: Button = shop.find_child("Supporter", true, false).find_child("Buy", true, false) as Button if shop.find_child("Supporter", true, false) != null else null
	check(buy != null, "Shop shows the Supporter Pack with a Buy button")
	check(buy != null and (buy.get_meta("caption") as Label).text.contains("$2.99"), "with the store's price")
	var badge: StringName = StringName(str(DataRegistry.idle("monetization.supporter_badge")))
	check(not game.sim.decoration.owns(badge), "no Supporter badge before buying")
	if buy != null:
		buy.pressed.emit()
	await runner.get_tree().process_frame
	check(Monetization.supporter, "buying makes this device a Supporter")
	check(game.sim.decoration.owns(badge), "the Supporter Heart badge joins the decorations")
	var shop2: UIScreen = game.modals.screen(&"shop")
	var body: Label = shop2.find_child("Supporter", true, false).find_child("Body", true, false) as Label if shop2 != null else null
	eq(body.text if body != null else "", Tx.t("ui_supporter_owned"), "the card says thank you")
	game.modals.close_all()
	# Hadiah tanpa iklan.
	p.ready = false
	var shown: int = p.shown
	check(Monetization.can_offer(&"coffee_refill"), "rewards are offered without an ad provider")
	var b: Button = AdButton.make(&"coffee_refill", "Another cup")
	check((b.get_meta("caption") as Label).text.contains("Free"), "and say Free")
	eq((b.get_meta("icon") as IconCanvas).icon_name, "heart", "with a heart")
	b.free()
	var got: Array = []
	Monetization.show_rewarded(&"coffee_refill", func(ok: bool) -> void: got.append(ok))
	eq(got, [true], "the reward comes at once")
	eq(p.shown, shown, "without an ad")
	eq(Monetization.left_today(&"coffee_refill"), int(Monetization.placement(&"coffee_refill")["per_day"]) - 1, "the daily limit still counts")
	# Bertahan setelah restart, dan Restore.
	Monetization.load_state()
	check(Monetization.supporter, "Supporter survives a restart")
	Monetization.reset_for_tests()
	check(not Monetization.supporter, "a wiped device forgets it")
	var ok_restore: Array = []
	Monetization.restore_purchases(func(owned: bool) -> void: ok_restore.append(owned))
	eq(ok_restore, [true], "Restore brings it back from the store")
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	_teardown_ads()


func _portals() -> void:
	var cfg := ConfigFile.new()
	eq(cfg.load("res://export_presets.cfg"), OK, "export presets load")
	var found: Dictionary = {}
	for sec: String in cfg.get_sections():
		if sec.ends_with(".options") or str(cfg.get_value(sec, "platform", "")) != "Web":
			continue
		var opt: String = sec + ".options"
		found[str(cfg.get_value(sec, "name", ""))] = {"features": str(cfg.get_value(sec, "custom_features", "")),
			"head": str(cfg.get_value(opt, "html/head_include", "")), "pwa": bool(cfg.get_value(opt, "progressive_web_app/enabled", false)),
			"threads": bool(cfg.get_value(opt, "variant/thread_support", true))}
	check(found.has("Web") and found.has("Web CrazyGames") and found.has("Web Poki"), "three Web presets (%s)" % str(found.keys()))
	if found.has("Web"):
		eq(found["Web"]["head"], "", "the plain Web build loads no SDK")
		eq(found["Web"]["features"], "", "and has no portal feature")
	if found.has("Web CrazyGames"):
		check(str(found["Web CrazyGames"]["head"]).contains("sdk.crazygames.com/crazygames-sdk-v3.js"), "CrazyGames loads its v3 SDK")
		eq(found["Web CrazyGames"]["features"], "crazygames", "with the crazygames feature")
		check(not found["Web CrazyGames"]["pwa"] and not found["Web CrazyGames"]["threads"], "single-threaded, no PWA")
	if found.has("Web Poki"):
		check(str(found["Web Poki"]["head"]).contains("game-cdn.poki.com/scripts/v2/poki-sdk.js"), "Poki loads its v2 SDK")
		eq(found["Web Poki"]["features"], "poki", "with the poki feature")
		check(not found["Web Poki"]["pwa"] and not found["Web Poki"]["threads"], "single-threaded, no PWA")
	eq(Monetization._platform_provider().id(), &"none", "desktop has no ad provider")
	# Siklus hidup yang didengar portal.
	var p: TestMonetizationProvider = _setup_ads()
	SaveManager.dir = "user://test_saves_portal"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	game.begin()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(p.events.has(&"loading_finished"), "the portal hears that loading finished")
	await game.start_new_game(&"profile_1", "female", "Portal Bakery")
	for i in 3:
		await runner.get_tree().process_frame
	check(p.events.has(&"gameplay_start"), "and that play started")
	PauseManager.push(&"test_pause")
	for i2 in 2:
		await runner.get_tree().process_frame
	eq(p.events[p.events.size() - 1], &"gameplay_stop", "a pause stops gameplay")
	PauseManager.pop(&"test_pause")
	game.modals.close_all()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid2: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid2)
	SaveManager.dir = "user://saves"
	_teardown_ads()
