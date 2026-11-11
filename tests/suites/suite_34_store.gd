extends TestSuite
## Toko, Golden Crumbs, Bakery Pass, dan hak beli (GDD idle 22.3-22.9). Semua
## lewat TestMonetizationProvider atau toko uji tanpa pendengar; tidak ada SDK
## sungguhan di tes.


func tests() -> Array:
	return [
		{"id": "ACC_IDLE_CRUMBS", "name": "idle 22.3 Golden Crumbs: a new bakery starts with start_crumbs; goals, stamps (more on the seventh), achievements, endless milestones and franchises give crumbs and pass XP; spending never goes below zero; crumbs, pass and ad boost survive save and load, and a save from before the store starts with start_crumbs", "fn": _crumbs},
		{"id": "ACC_IDLE_AD_BOOST", "name": "idle 22.4 the x2 boost from ads or crumbs stacks up to max_hours, multiplies live income on top of other boosts, counts down in real seconds while playing, keeps running while away (the boosted part of offline earnings is doubled) and leaves the offline model without boosts", "fn": _ad_boost},
		{"id": "ACC_IDLE_TIME_WARP", "name": "idle 22.6 a time warp pays the no-boost model KR/s for its hours at once, counts as income (stars), and costs its crumbs; without crumbs nothing happens", "fn": _warp},
		{"id": "ACC_IDLE_PERKS", "name": "idle 22.5 Golden Oven doubles every price and the offline model, Night Manager adds offline hours at the full rate, Baker's Club adds income, offline hours, free ad rewards and daily crumbs once per device day; perks belong to the device and never enter the save", "fn": _perks},
		{"id": "ACC_IDLE_PASS", "name": "idle 22.7 Bakery Pass: XP fills 30 tiers, free rewards can be claimed, premium ones only after unlocking, Claim all takes everything, a new month auto-claims last season's earned rewards and starts over, and a season item already owned turns into crumbs", "fn": _pass},
		{"id": "ACC_IDLE_STORE_PURCHASES", "name": "idle 22.5, 22.9 purchases: crumb packs and pass deliver into the save, entitlements stay on the device and come back with Restore, a limited offer starts once its condition holds, pops up once, runs out after its hours, and its contents arrive only once; v1 Supporter files become No Ads", "fn": _purchases},
		{"id": "ACC_IDLE_STORE_UI", "name": "idle 22.2, 22.5, 22.8 the HUD Store button and Golden Crumbs chip open the Store with five tabs; the test store asks to confirm a purchase and shows a countdown ad whose early close gives nothing; buying a style item with crumbs puts it on; Decoration Mode lists Golden Crumbs items", "fn": _store_ui},
		{"id": "ACC_IDLE_STORE_CELEBRATION", "name": "idle 22.11 every Store success is celebrated: a style item opens a reveal with its own turning 3D model (outfit on the owner, storefront, decoration) and Place it, a product opens a badge reveal, crumbs fly from the button into the balance and count up, a boost pulses its HUD chip, toasts wait while a reveal is open, and Reduce motion shows everything at once without particles", "fn": _celebration},
		{"id": "ACC_IDLE_DOORS", "name": "32.3, idle 22.8 every location tier has its own entrance and shop sign (more luxurious each tier) and at least five themed door skins, each with its matching sign, are sold for Golden Crumbs; every door stays under the sign, within the triangle budget, the awning rises above sign ornaments, and a bought door replaces the tier entrance and sign in the shop and in its celebration", "fn": _doors},
		{"id": "ACC_IDLE_SIGN_FITS_NAME", "name": "idle 20 no. 103 the shop sign is as wide as the bakery name measured in its own font, within the shop front; a name too wide for the front shrinks until it fits, so no name is ever cut off or covered by sign ornaments, and the 2D signs shrink long names instead of trimming them", "fn": _sign_fits_name},
		{"id": "ACC_IDLE_PREMIUM_DECOR", "name": "idle 22.8 premium, offer and pass decorations build within the triangle budget, their bonus stays on in every branch without buying it again, outfits change the owner's apron and hat, and awning skins recolour the storefront", "fn": _premium_decor},
	]


func _setup_store() -> TestMonetizationProvider:
	Monetization.reset_for_tests()
	var p := TestMonetizationProvider.new()
	Monetization.use_provider(p)
	return p


func _teardown_store() -> void:
	Monetization.reset_for_tests()
	Monetization.use_provider(MonetizationProvider.new())
	BoostManager.date_override = ""
	PauseManager.clear_all()
	AudioManager.stop_all_sounds()


func _crumbs() -> void:
	var s: SimulationRoot = new_sim(3401)
	s.tutorial.skip()
	var start: int = DataRegistry.idlei("premium.start_crumbs")
	eq(s.premium.crumbs, start, "a new bakery starts with the starting crumbs")
	var xp0: int = s.premium.pass_xp
	s.premium.on_goal()
	eq(s.premium.crumbs, start + DataRegistry.idlei("premium.earn.goal"), "a daily goal gives crumbs")
	eq(s.premium.pass_xp - xp0, DataRegistry.idlei("pass.xp.goal"), "and pass XP")
	var c1: int = s.premium.crumbs
	s.premium.on_calendar(false)
	s.premium.on_calendar(true)
	eq(s.premium.crumbs - c1, 2 * DataRegistry.idlei("premium.earn.calendar") + DataRegistry.idlei("premium.earn.calendar_week"), "stamps give crumbs, the seventh more")
	var c2: int = s.premium.crumbs
	s.premium.on_series(2)
	eq(s.premium.crumbs - c2, 2 * DataRegistry.idlei("premium.earn.series"), "every milestone level gives crumbs")
	var c3: int = s.premium.crumbs
	s.premium.on_franchise(8)
	eq(s.premium.crumbs - c3, 8 * DataRegistry.idlei("premium.earn.franchise_per_star"), "a franchise gives crumbs per star")
	# Hadiah sungguhan lewat manajernya.
	var c4: int = s.premium.crumbs
	for a: Variant in DataRegistry.achievements():
		s.achievements._unlock(a)
		break
	eq(s.premium.crumbs - c4, DataRegistry.idlei("premium.earn.achievement"), "an achievement gives crumbs")
	s.calendar.note_date("2026-11-01")
	var c5: int = s.premium.crumbs
	check(not s.calendar.claim("2026-11-02").is_empty(), "a stamp is claimed")
	eq(s.premium.crumbs - c5, DataRegistry.idlei("premium.earn.calendar"), "and gives its crumbs")
	# Belanja.
	var have: int = s.premium.crumbs
	check(not s.premium.spend(have + 1, &"test"), "cannot spend more than you have")
	eq(s.premium.crumbs, have, "nothing taken")
	check(s.premium.spend(have, &"test"), "can spend everything")
	eq(s.premium.crumbs, 0, "down to zero")
	eq(s.premium.spent_total, have, "spending is counted")
	# Save.
	s.premium.earn(77, &"test")
	s.premium.add_boost(2.0)
	s.premium.ensure_season("2026-11-10")
	s.premium.add_xp(250)
	s.premium.unlock_pass()
	s.premium.claim(&"free", 1)
	var d: Dictionary = json_copy(s.capture_save())
	check(d.has("premium"), "the save has a premium part")
	var t: SimulationRoot = load_sim(d)
	eq(t.premium.crumbs, s.premium.crumbs, "crumbs survive a reload")
	near(t.premium.ad_boost_left, s.premium.ad_boost_left, 1e-6, "the boost survives")
	eq(t.premium.pass_xp, s.premium.pass_xp, "pass XP survives")
	check(t.premium.pass_premium and t.premium.is_claimed(&"free", 1), "premium and claims survive")
	eq(t.premium.pass_season, "2026-11", "the season survives")
	free_sim(t)
	d.erase("premium")
	var u: SimulationRoot = load_sim(d)
	eq(u.premium.crumbs, start, "a save from before the store starts with the starting crumbs")
	free_sim(u)
	free_sim(s)


func _ad_boost() -> void:
	var s: SimulationRoot = new_sim(3402)
	s.tutorial.skip()
	freeze_production(s)
	s.boosts.new_run()
	var hours: float = DataRegistry.idlef("premium.ad_boost.hours")
	var mult: float = DataRegistry.idlef("premium.ad_boost.mult")
	near(s.boost_income_mult(), 1.0, 1e-9, "no boost at first")
	s.premium.add_boost(hours)
	near(s.premium.ad_boost_left, hours * 3600.0, 1e-6, "one boost = its hours")
	near(s.boost_income_mult(), mult, 1e-9, "income x2")
	s.boosts.add_income(2.0, 60.0)
	near(s.boost_income_mult(), mult * 2.0, 1e-9, "on top of the coffee")
	s.boosts.new_run()
	var r_live: float = s.recipe_price(SimulationRoot.first_free_recipe())
	var r_plain: float = s.recipe_price(SimulationRoot.first_free_recipe(), false)
	near(r_live, r_plain * mult, 1e-6, "the live price doubles, the offline model does not")
	for i in 10:
		s.premium.add_boost(hours)
	near(s.premium.ad_boost_left, s.premium.ad_boost_max(), 1e-6, "stacks up to the maximum")
	check(not s.premium.can_add_boost(), "and then it is full")
	check(not s.premium.buy_boost(), "a full boost cannot be bought")
	# Berjalan dalam detik nyata.
	var left: float = s.premium.ad_boost_left
	run_for(s, 20.0)
	near(left - s.premium.ad_boost_left, DataRegistry.real_seconds(20.0), 0.01, "counts down in real seconds while playing")
	# Waktu pergi.
	s.premium.ad_boost_left = 600.0
	s.offline.now_override = 10000.0
	s.offline.last_active_unix = 10000.0 - 1800.0
	s.offline.rate_kr_per_s = 10.0
	var eff: float = s.offline.efficiency()
	var r: Dictionary = s.offline.settle()
	near(float(r["boosted"]), 600.0, 1e-6, "ten minutes of the half hour away were boosted")
	near(float(r["amount"]), Money.round_cents(10.0 * 1800.0 * eff) + Money.round_cents(10.0 * 600.0 * eff * (mult - 1.0)), 0.02, "the boosted part is doubled")
	near(s.premium.ad_boost_left, 0.0, 1e-9, "the boost ran out while away")
	near(s.boost_income_mult(), 1.0, 1e-9, "and income is back to normal")
	s.premium.ad_boost_left = 7200.0
	s.offline.last_active_unix = 10000.0 - 600.0
	s.offline.settle()
	near(s.premium.ad_boost_left, 6600.0, 1e-6, "time away shortens a longer boost")
	# Beli dengan crumbs.
	s.premium.ad_boost_left = 0.0
	s.premium.crumbs = DataRegistry.idlei("premium.ad_boost.crumbs")
	check(s.premium.buy_boost(), "a boost can be bought with crumbs")
	eq(s.premium.crumbs, 0, "for its price")
	near(s.premium.ad_boost_left, hours * 3600.0, 1e-6, "for its hours")
	check(not s.premium.buy_boost(), "not without crumbs")
	s.offline.now_override = -1.0
	free_sim(s)


func _warp() -> void:
	var s: SimulationRoot = new_sim(3403)
	s.tutorial.skip()
	jump_to_tier(s, 2)
	equip_shop(s, 10)
	s.idle_economy.invalidate()
	var rate: float = s.idle_economy.rate(false)
	check(rate > 0.0, "the shop earns (%s KR/s)" % rate)
	near(s.premium.warp_amount(3600.0), Money.round_cents(rate * 3600.0), 0.01, "one hour = the no-boost model KR/s x 3600")
	var w: Dictionary = PremiumManager.warp(&"warp_1h")
	check(not w.is_empty(), "a one-hour warp exists")
	s.premium.crumbs = int(w["crumbs"]) - 1
	var b0: float = s.economy.balance
	eq(s.premium.buy_warp(&"warp_1h"), -1.0, "not enough crumbs")
	near(s.economy.balance, b0, 1e-9, "and no KR")
	s.premium.crumbs = int(w["crumbs"])
	var earned0: float = s.statistics.get_stat("alltime_earned_kr")
	var got: float = s.premium.buy_warp(&"warp_1h")
	near(got, Money.round_cents(rate * 3600.0), 0.01, "the warp pays an hour of income")
	near(s.economy.balance - b0, got, 0.5, "into the wallet")
	near(s.statistics.get_stat("alltime_earned_kr") - earned0, got, 0.5, "and it counts as income")
	eq(s.premium.spent_total, int(w["crumbs"]), "for its crumbs")
	free_sim(s)


func _perks() -> void:
	var s: SimulationRoot = new_sim(3404)
	s.tutorial.skip()
	jump_to_tier(s, 2)
	equip_shop(s, 5)
	s.boosts.new_run()
	var rid: StringName = SimulationRoot.first_free_recipe()
	var plain: float = s.plain_price(rid)
	s.idle_economy.invalidate()
	var rate0: float = s.idle_economy.rate(false)
	Monetization.reset_for_tests()
	var oven: Dictionary = PremiumManager.product_of_kind("income")
	Monetization.owned.append(str(oven["id"]))
	s.premium.set_perks(Monetization.perks())
	near(s.plain_price(rid), plain * float(oven["income_mult"]), 1e-6, "Golden Oven doubles every price")
	# Biaya bahan tidak ikut naik, jadi laba bersih naik sedikit lebih dari dua kali.
	var rate2: float = s.idle_economy.rate(false)
	check(rate2 >= rate0 * float(oven["income_mult"]) * 0.97 and rate2 <= rate0 * float(oven["income_mult"]) * 1.6,
		"and the offline model (%s -> %s KR/s)" % [rate0, rate2])
	var cap0: float = s.offline.cap_seconds()
	var night: Dictionary = PremiumManager.product_of_kind("offline")
	Monetization.owned.append(str(night["id"]))
	s.premium.set_perks(Monetization.perks())
	near(s.offline.cap_seconds() - cap0, float(night["offline_hours"]) * 3600.0, 1.0, "Night Manager adds its hours")
	near(s.offline.efficiency(), DataRegistry.idlef("offline.max_efficiency"), 1e-9, "at the full rate")
	# Club.
	var club: Dictionary = PremiumManager.product_of_kind("club")
	Monetization.now_override = 1000000.0
	check(not Monetization.club_active(), "no club yet")
	Monetization._on_bought(StringName(str(club["id"])))
	check(Monetization.club_active(), "the club is active after buying")
	near(Monetization.club_left(), float(club["days"]) * 86400.0, 1.0, "for its days")
	check(Monetization.ads_free(), "ad rewards come without ads")
	s.premium.set_perks(Monetization.perks())
	near(s.plain_price(rid), plain * float(oven["income_mult"]) * float(club["income_mult"]), 1e-6, "club income on top")
	check(s.premium.club_available("2026-11-10"), "the daily crumbs are there")
	var c0: int = s.premium.crumbs
	eq(s.premium.claim_club("2026-11-10"), int(club["daily_crumbs"]), "claimed")
	eq(s.premium.crumbs - c0, int(club["daily_crumbs"]), "into the wallet")
	eq(s.premium.claim_club("2026-11-10"), 0, "once per device day")
	eq(s.premium.claim_club("2026-11-11"), int(club["daily_crumbs"]), "and again the next day")
	Monetization._on_bought(StringName(str(club["id"])))
	near(Monetization.club_left(), 2.0 * float(club["days"]) * 86400.0, 1.0, "buying again extends it")
	Monetization.now_override = 1000000.0 + 2.0 * float(club["days"]) * 86400.0 + 1.0
	check(not Monetization.club_active(), "and it ends after its days")
	s.premium.set_perks(Monetization.perks())
	check(not s.premium.club_active(), "the shop loses the club perks")
	eq(s.premium.claim_club("2026-12-30"), 0, "and the daily crumbs")
	var d: Dictionary = json_copy(s.capture_save())
	check(not str(d["premium"]).contains("income_mult"), "perks never enter the save")
	var t: SimulationRoot = load_sim(d)
	near(t.plain_price(rid), plain, 1e-6, "a loaded save without the device's perks uses plain prices")
	free_sim(t)
	free_sim(s)
	Monetization.reset_for_tests()


func _pass() -> void:
	var s: SimulationRoot = new_sim(3405)
	s.tutorial.skip()
	var per: int = PremiumManager.xp_per_tier()
	var tiers: int = PremiumManager.tiers()
	eq(tiers, 30, "thirty tiers")
	s.premium.ensure_season("2026-11-10")
	eq(s.premium.pass_season, "2026-11", "a season is a device month")
	eq(s.premium.pass_tier(), 0, "no tier yet")
	s.premium.add_xp(per * 3 + per / 2)
	eq(s.premium.pass_tier(), 3, "XP fills tiers")
	eq(s.premium.tier_progress(), per / 2, "with progress into the next")
	check(s.premium.can_claim(&"free", 1), "a reached free reward can be claimed")
	check(not s.premium.can_claim(&"free", 4), "an unreached one cannot")
	check(not s.premium.can_claim(&"premium", 1), "premium needs the unlock")
	var c0: int = s.premium.crumbs
	var r1: Dictionary = PremiumManager.reward(&"free", 1)
	check(s.premium.claim(&"free", 1), "claim tier 1")
	if r1.has("crumbs"):
		eq(s.premium.crumbs - c0, int(r1["crumbs"]), "its crumbs arrive")
	check(not s.premium.claim(&"free", 1), "only once")
	s.premium.unlock_pass()
	eq(s.premium.claimable_count(), 2 + 3, "two free and three premium rewards wait")
	var got: Array[Dictionary] = s.premium.claim_all()
	eq(got.size(), 5, "Claim all takes them")
	eq(s.premium.claimable_count(), 0, "nothing left")
	# Barang musim di tingkat 15 premium.
	var item: StringName = PremiumManager.season_item("2026-11", "outfit")
	check(DataRegistry.decoration(item) != null, "the season has an outfit (%s)" % item)
	s.premium.add_xp(per * 20)
	s.premium.claim_all()
	check(s.decoration.owns(item), "the season outfit arrives at tier 15")
	var dup_c: int = s.premium.crumbs
	s.premium.grant_reward({"season": "outfit"})
	eq(s.premium.crumbs - dup_c, DataRegistry.idlei("pass.duplicate_crumbs"), "an owned season item becomes crumbs")
	# Musim berganti.
	s.premium.add_xp(per * 10)
	var waiting: int = s.premium.claimable_count()
	check(waiting > 0, "rewards are waiting at the end of the month")
	var old: Array[Dictionary] = s.premium.ensure_season("2026-12-01")
	eq(old.size(), waiting, "a new month hands them out")
	eq(s.premium.pass_season, "2026-12", "the new season starts")
	check(s.premium.pass_xp == 0 and not s.premium.pass_premium, "from zero, without premium")
	check(s.premium.ensure_season("2026-12-15").is_empty(), "the same month changes nothing")
	# Tanpa musim: XP awal tetap.
	var t: SimulationRoot = new_sim(3406)
	t.premium.add_xp(per)
	t.premium.ensure_season("2027-01-02")
	eq(t.premium.pass_xp, per, "XP earned before the first season date is kept")
	free_sim(t)
	free_sim(s)


func _purchases() -> void:
	BoostManager.date_override = "2026-11-10"
	var p: TestMonetizationProvider = _setup_store()
	var bought: Array = []
	var catch := func(id: StringName) -> void: bought.append(id)
	Monetization.purchased.connect(catch)
	var s: SimulationRoot = new_sim(3407)
	s.tutorial.skip()
	# Paket crumbs.
	var pack: Dictionary = Monetization.products("crumbs")[0]
	var res: Array = []
	Monetization.buy(StringName(str(pack["id"])), func(ok: bool) -> void: res.append(ok))
	eq(res, [true], "a crumb pack is bought")
	eq(bought, [StringName(str(pack["id"]))], "and announced for the save")
	var c0: int = s.premium.crumbs
	s.premium.deliver(StringName(str(pack["id"])))
	eq(s.premium.crumbs - c0, int(pack["crumbs"]), "its crumbs arrive")
	check(not Monetization.owns(StringName(str(pack["id"]))), "a consumable is never owned")
	# Hak beli tetap.
	var oven: StringName = Monetization.product_id("income")
	Monetization.buy(oven, func(_ok: bool) -> void: pass)
	check(Monetization.owns(oven), "Golden Oven is owned")
	check(not Monetization.can_buy(oven), "and cannot be bought twice")
	Monetization.load_state()
	check(Monetization.owns(oven), "it survives a restart")
	Monetization.reset_for_tests()
	check(not Monetization.owns(oven), "a wiped device forgets it")
	var any: Array = []
	Monetization.restore_purchases(func(a: bool) -> void: any.append(a))
	eq(any, [true], "Restore finds it")
	check(Monetization.owns(oven), "and brings it back")
	# Pass.
	s.premium.ensure_season(BoostManager.today())
	s.premium.deliver(Monetization.product_id("pass"))
	check(s.premium.pass_premium, "buying the pass unlocks premium in the save")
	# Penawaran.
	Monetization.now_override = 5000000.0
	eq(Monetization.update_offers(1, 0), &"", "no offer in the garage")
	eq(Monetization.live_offers().size(), 0, "nothing running")
	var starter: StringName = &"starter_pack"
	eq(Monetization.update_offers(2, 0), starter, "the starter pack starts after the first move")
	near(Monetization.offer_left(starter), float(Monetization.offer_rule(starter)["hours"]) * 3600.0, 1.0, "for its hours")
	Monetization.mark_offer_shown(starter)
	eq(Monetization.update_offers(2, 0), &"", "it pops up only once")
	check(Monetization.live_offers().has(starter), "but waits in the Store")
	eq(Monetization.update_offers(2, 1), &"branch_pack", "the branch pack starts after the first franchise")
	Monetization.mark_offer_shown(&"branch_pack")
	Monetization.now_override = 5000000.0 + float(Monetization.offer_rule(&"branch_pack")["hours"]) * 3600.0 + 1.0
	eq(Monetization.offer_left(&"branch_pack"), 0.0, "an offer runs out")
	check(not Monetization.can_buy(&"branch_pack"), "and can no longer be bought")
	Monetization.now_override = 5000000.0 + 60.0
	bought.clear()
	Monetization.buy(starter, func(_ok: bool) -> void: pass)
	check(Monetization.owns(starter), "the starter pack is bought")
	eq(Monetization.offer_left(starter), 0.0, "and leaves the offers")
	var sp: Dictionary = PremiumManager.product(starter)
	var c1: int = s.premium.crumbs
	check(s.premium.deliver(starter), "its contents arrive")
	eq(s.premium.crumbs - c1, int(sp["crumbs"]), "with its crumbs")
	check(s.decoration.owns(StringName(str(sp["decor"]))), "and its outfit")
	near(s.premium.ad_boost_left, float(sp["boost_hours"]) * 3600.0, 1.0, "and its boost")
	check(not s.premium.deliver(starter), "only once per save")
	# Berkas versi 1.
	Monetization.reset_for_tests()
	var f: FileAccess = FileAccess.open(Monetization.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"version": 1, "supporter": true, "day": "", "used": {}}))
	f.close()
	Monetization.load_state()
	check(Monetization.owns(&"no_ads") and Monetization.supporter, "a v1 Supporter file becomes No Ads")
	check(Monetization.owns(&"supporter_pack"), "the old product id still answers")
	Monetization.purchased.disconnect(catch)
	free_sim(s)
	_teardown_store()


func _game(label: String) -> GameRoot:
	SaveManager.dir = "user://test_saves_store"
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	var game: GameRoot = (load("res://scenes/game_root.tscn") as PackedScene).instantiate()
	runner.add_child(game)
	await runner.get_tree().process_frame
	game.skip_splash_for_tests()
	await game.start_new_game(&"profile_1", "female", label)
	await runner.get_tree().process_frame
	game.sim.tutorial.skip()
	game.modals.close_all()
	PauseManager.clear_all()
	game.playing = false
	return game


func _end(game: GameRoot) -> void:
	game.modals.close_all()
	game.playing = true
	game.end_session()
	game.queue_free()
	await runner.get_tree().process_frame
	for pid: StringName in SaveManager.PROFILE_IDS:
		SaveManager.delete_profile(pid)
	SaveManager.dir = "user://saves"


func _store_ui() -> void:
	BoostManager.date_override = "2026-11-10"
	Monetization.reset_for_tests()
	# Toko uji dengan layar tiruannya (GameRoot mendengarkan).
	Monetization.use_provider(DummyMonetizationProvider.new())
	var game: GameRoot = await _game("Store Bakery")
	var s: SimulationRoot = game.sim
	var orphans0: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var store_b: Button = game.hud.store_button()
	check(store_b != null and store_b.visible, "the HUD has a Store button")
	store_b.pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var st: StoreScreen = game.modals.screen(&"store") as StoreScreen
	check(st != null, "it opens the Store")
	if st == null:
		await _end(game)
		_teardown_store()
		return
	var tabs: Control = st.find_child("Tabs", true, false) as Control
	check(tabs != null, "with tabs")
	for i in StoreScreen.TAB_KEYS.size():
		st.show_tab(i)
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		check(st.find_child("StoreList", true, false) != null, "tab %d builds" % i)
	st.show_tab(StoreScreen.TAB_OFFERS)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(st.find_child("Club", true, false) != null, "Offers shows the Baker's Club")
	check(st.find_child("Product_golden_oven", true, false) != null, "and Golden Oven")
	check(st.find_child("Product_no_ads", true, false) != null, "and No Ads")
	check(st.find_child("TestNote", true, false) != null, "the test store says no money is charged")
	# Beli lewat toko uji: konfirmasi dulu.
	var buy: Button = st.find_child("Product_golden_oven", true, false).find_child("Buy", true, false) as Button
	check(buy != null and not buy.disabled, "Golden Oven can be bought")
	if buy != null:
		buy.pressed.emit()
	await runner.get_tree().process_frame
	var tp: TestPurchaseScreen = game.modals.screen(&"test_purchase") as TestPurchaseScreen
	check(tp != null, "the test store asks to confirm")
	if tp != null:
		(tp.find_child("Cancel", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(not Monetization.owns(&"golden_oven"), "Cancel buys nothing")
	st = game.modals.screen(&"store") as StoreScreen
	check(st != null, "the Store stays open under the test store")
	buy = st.find_child("Product_golden_oven", true, false).find_child("Buy", true, false) as Button if st != null else null
	if buy != null:
		buy.pressed.emit()
	await runner.get_tree().process_frame
	tp = game.modals.screen(&"test_purchase") as TestPurchaseScreen
	if tp != null:
		(tp.find_child("Confirm", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(Monetization.owns(&"golden_oven"), "Confirm buys it")
	near(s.premium.income_mult(), float(PremiumManager.product(&"golden_oven")["income_mult"]), 1e-9, "and the shop gets the perk at once")
	# Iklan tiruan: ditutup lebih awal = tanpa hadiah.
	st = game.modals.screen(&"store") as StoreScreen
	if st == null:
		game.hud.open_store(StoreScreen.TAB_CRUMBS)
		await runner.get_tree().process_frame
		st = game.modals.screen(&"store") as StoreScreen
	st.show_tab(StoreScreen.TAB_CRUMBS)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var ad: Button = st.find_child("Ad_ad_crumbs", true, false) as Button
	check(ad != null and ad.visible, "Crumbs offers free crumbs for an ad")
	var c0: int = s.premium.crumbs
	if ad != null:
		ad.pressed.emit()
	await runner.get_tree().process_frame
	var da: DummyAdScreen = game.modals.screen(&"dummy_ad") as DummyAdScreen
	check(da != null, "the test ad plays")
	check(PauseManager.has(Monetization.PAUSE_REASON), "the shop pauses during it")
	var claim: Button = da.find_child("Claim", true, false) as Button if da != null else null
	check(claim != null and claim.disabled, "the reward waits for the countdown")
	if da != null:
		(da.find_child("Skip", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	eq(s.premium.crumbs, c0, "closing early gives nothing")
	check(not PauseManager.has(Monetization.PAUSE_REASON), "and the shop runs again")
	ad = (game.modals.screen(&"store") as StoreScreen).find_child("Ad_ad_crumbs", true, false) as Button
	if ad != null:
		ad.pressed.emit()
	await runner.get_tree().process_frame
	da = game.modals.screen(&"dummy_ad") as DummyAdScreen
	if da != null:
		da.skip_countdown()
		(da.find_child("Claim", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	eq(s.premium.crumbs - c0, int(Monetization.placement(&"ad_crumbs")["crumbs"]), "a finished ad pays the crumbs")
	check(s.premium.pass_xp >= DataRegistry.idlei("pass.xp.ad"), "and pass XP")
	# Style: beli pakaian dengan crumbs.
	s.premium.earn(1000, &"test")
	st = game.modals.screen(&"store") as StoreScreen
	st.show_tab(StoreScreen.TAB_STYLE)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var row: Control = st.find_child("Style_outfit_strawberry_baker", true, false) as Control
	check(row != null, "Style lists premium outfits")
	var cb: Button = row.find_child("Crumbs", true, false) as Button if row != null else null
	if cb != null:
		cb.pressed.emit()
	await runner.get_tree().process_frame
	check(s.decoration.owns(&"outfit_strawberry_baker"), "the outfit is bought with crumbs")
	eq(str(s.decoration.equipped.get("outfit", "")), "outfit_strawberry_baker", "and worn at once")
	# Chip crumbs membuka tab Crumbs.
	game.modals.close_all()
	await runner.get_tree().process_frame
	game.hud.open_store(StoreScreen.TAB_CRUMBS)
	await runner.get_tree().process_frame
	st = game.modals.screen(&"store") as StoreScreen
	eq(st.current_tab() if st != null else -1, StoreScreen.TAB_CRUMBS, "the crumbs chip opens the Crumbs tab")
	game.modals.close_all()
	# Decoration Mode: bagian Golden Crumbs.
	var deco: DecorationScreen = game.modals.open(&"decoration") as DecorationScreen
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	if deco != null:
		deco._expanded = true
		deco._set_tab(DecorationScreen.tab_for_type(&"wall"))
		await runner.get_tree().process_frame
		await runner.get_tree().process_frame
		check(deco.find_child("Premium_decor_neon_bread_sign", true, false) != null, "Decoration Mode lists Golden Crumbs items")
		deco._cancel()
	game.modals.close_all()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans0, "no orphan UI nodes")
	await _end(game)
	_teardown_store()


func _premium_decor() -> void:
	for x: Variant in DataRegistry.decorations():
		var d: MiscDefinitions.DecorationDefinition = x
		if not [&"premium", &"offer", &"pass"].has(d.source):
			continue
		if d.is_placeable():
			check(DecorFactory.has_model(d.visual_profile_id), "%s has a model" % d.id)
			var n: Node3D = DecorFactory.build(d.id)
			var tris: int = 0
			for mi: Node in n.find_children("*", "MeshInstance3D", true, false):
				tris += int((mi as MeshInstance3D).get_meta("tris", 0)) if (mi as MeshInstance3D).has_meta("tris") else 0
			check(tris > 0 and tris <= DecorFactory.MAX_TRIS, "%s builds within the budget (%d tris)" % [d.id, tris])
			n.free()
	DecorFactory.clear_caches()
	var s: SimulationRoot = new_sim(3408)
	s.tutorial.skip()
	var base: float = s.decoration.bonus_mult(&"price")
	s.decoration.grant(&"decor_golden_loaf_statue")
	var bonus: float = float(DataRegistry.decoration(&"decor_golden_loaf_statue").bonus["value"])
	near(s.decoration.bonus_mult(&"price"), base + bonus, 1e-9, "an offer decoration's bonus is on once owned")
	check(s.decoration.is_bonus_active(&"decor_golden_loaf_statue"), "and reads as active")
	s.decoration.begin_run()
	near(s.decoration.bonus_mult(&"price"), base + bonus, 1e-9, "it stays on in a new branch without buying it again")
	s.premium.crumbs = 0
	eq(s.decoration.can_buy(&"decor_marble_rug"), &"crumbs", "premium items need crumbs")
	s.premium.crumbs = 1000
	eq(s.decoration.buy(&"decor_marble_rug"), &"", "bought with crumbs")
	eq(s.premium.crumbs, 1000 - DataRegistry.decoration(&"decor_marble_rug").price_crumbs, "for its price")
	eq(s.decoration.can_buy(&"decor_marble_rug"), &"owned", "only one copy")
	free_sim(s)
	# Pakaian dan kanopi di dunia.
	var game: GameRoot = await _game("Style Bakery")
	var gs: SimulationRoot = game.sim
	gs.decoration.grant(&"outfit_night_owl")
	var spec: Dictionary = game.world._player_spec()
	eq(str(spec.get("hat", "")), str(DataRegistry.decoration(&"outfit_night_owl").look["hat"]), "the outfit sets the owner's hat")
	check((spec.get("apron", Color.BLACK) as Color).is_equal_approx(Color.html(str(DataRegistry.decoration(&"outfit_night_owl").look["apron"]))), "and apron")
	gs.premium.crumbs = 1000
	eq(gs.decoration.buy(&"skin_awning_gold"), &"", "an awning skin is bought")
	eq(str(gs.decoration.equipped.get("storefront", "")), "skin_awning_gold", "and put on the storefront")
	await _end(game)
	# Kanopi: warna dari skin yang dipakai.
	var loc: LocationDefinition = DataRegistry.location_by_tier(1)
	var fd: FloorDefinition = loc.floors[0]
	var room: Node3D = RoomFactory.build_floor(loc, fd, "Awning Test", {"storefront": "skin_awning_gold"})
	var aw: MeshInstance3D = room.find_child("Awning", true, false) as MeshInstance3D
	check(aw != null, "the storefront gets an awning")
	if aw != null and aw.mesh != null:
		var want: Color = DataRegistry.decoration(&"skin_awning_gold").colors[0]
		var hit: bool = false
		for i in aw.mesh.get_surface_count():
			var m: StandardMaterial3D = aw.mesh.surface_get_material(i) as StandardMaterial3D
			hit = hit or (m != null and m.albedo_color.is_equal_approx(want))
		check(hit, "in the skin's colour")
	room.free()


func _celebration() -> void:
	BoostManager.date_override = "2026-11-10"
	_setup_store()
	var game: GameRoot = await _game("Party Bakery")
	var s: SimulationRoot = game.sim
	var orphans0: float = Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)
	var was_motion: bool = SettingsManager.reduced_motion()
	SettingsManager.set_value("reduced_motion", false)
	# Style: perayaan penuh dengan model 3D barangnya.
	s.premium.earn(5000, &"test")
	game.hud.open_store(StoreScreen.TAB_STYLE)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var st: StoreScreen = game.modals.screen(&"store") as StoreScreen
	var cb: Button = st.find_child("Style_outfit_matcha_chef", true, false).find_child("Crumbs", true, false) as Button
	cb.pressed.emit()
	await runner.get_tree().process_frame
	var rv: RewardReveal = game.modals.screen(&"reward_reveal") as RewardReveal
	check(rv != null, "buying a style item opens the celebration")
	check(rv != null and rv.hero() is ItemStage, "with the item's own 3D model on a stage")
	check(rv != null and rv.hero() is ItemStage and (rv.hero() as ItemStage).viewport().own_world_3d, "in its own little world")
	check(not game.hud._toast_layer.visible, "toasts wait while it is open")
	check(game.modals.is_open(&"store"), "the Store stays open underneath")
	for i in 30:
		await runner.get_tree().process_frame
	check(rv != null and rv.find_child("ConfettiFX", true, false) != null, "confetti bursts out")
	if rv != null:
		(rv.find_child("Ok", true, false) as Button).pressed.emit()
	await runner.get_tree().create_timer(0.35).timeout
	check(not game.modals.is_open(&"reward_reveal"), "Awesome! closes it")
	check(game.hud._toast_layer.visible, "and toasts come back")
	# Barang yang bisa dipasang: Place it membuka Decoration Mode dengan barangnya di tangan.
	st = game.modals.screen(&"store") as StoreScreen
	st.show_tab(StoreScreen.TAB_STYLE)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	(st.find_child("Style_decor_neon_bread_sign", true, false).find_child("Crumbs", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	rv = game.modals.screen(&"reward_reveal") as RewardReveal
	var place: Button = rv.find_child("Place", true, false) as Button if rv != null else null
	check(place != null, "a decoration offers Place it")
	if place != null:
		place.pressed.emit()
	for i2 in 4:
		await runner.get_tree().process_frame
	var deco: DecorationScreen = game.modals.screen(&"decoration") as DecorationScreen
	check(deco != null, "Place it opens Decoration Mode")
	check(not game.modals.is_open(&"store"), "and closes the Store")
	check(deco != null and deco.has_selection(), "with the new decoration in hand")
	game.modals.close_all()
	await runner.get_tree().process_frame
	# Produk: lencana besar.
	game.hud.open_store(StoreScreen.TAB_OFFERS)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	st = game.modals.screen(&"store") as StoreScreen
	(st.find_child("Product_night_manager", true, false).find_child("Buy", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	rv = game.modals.screen(&"reward_reveal") as RewardReveal
	check(rv != null and rv.hero().name == "HeroBadge", "a product opens a badge celebration")
	game.modals.close_id(&"reward_reveal")
	await runner.get_tree().process_frame
	# Golden Crumbs terbang dari tombol beli ke saldo.
	st = game.modals.screen(&"store") as StoreScreen
	st.show_tab(StoreScreen.TAB_CRUMBS)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	var pack: Dictionary = Monetization.products("crumbs")[1]
	var before: int = s.premium.crumbs
	(st.find_child("Pack_" + str(pack["id"]), true, false).find_child("Buy", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	check(not game.modals.is_open(&"reward_reveal"), "a crumb pack needs no celebration screen")
	var fx: Control = game.hud.fx_root()
	var flying: int = 0
	for n: Node in fx.get_children():
		flying += 1 if String(n.name).begins_with("FlyingCrumb") else 0
	check(flying >= 4, "crumbs fly to the balance (%d)" % flying)
	eq(s.premium.crumbs - before, int(pack["crumbs"]), "and arrive")
	await runner.get_tree().create_timer(1.6).timeout
	var left: int = 0
	for n2: Node in fx.get_children():
		left += 1 if String(n2.name).begins_with("FlyingCrumb") else 0
	eq(left, 0, "the flying crumbs are gone afterwards")
	eq(game.hud._crumbs.text, Tx.big(float(s.premium.crumbs)), "the balance counted up to the new amount")
	# Boost: chip HUD muncul dan memantul.
	st.show_tab(StoreScreen.TAB_BOOSTS)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	(st.find_child("AdBoost", true, false).find_child("Crumbs", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	check(game.hud._ad_boost.visible, "the x2 chip appears")
	check(not game.hud._ad_boost.scale.is_equal_approx(Vector2.ONE), "and pulses")
	# Pass: barang musim ikut dirayakan.
	game.modals.close_all()
	await runner.get_tree().process_frame
	s.premium.ensure_season("2026-11-10")
	s.premium.unlock_pass()
	s.premium.add_xp(PremiumManager.xp_per_tier() * 15)
	game.hud.open_store(StoreScreen.TAB_PASS)
	await runner.get_tree().process_frame
	await runner.get_tree().process_frame
	st = game.modals.screen(&"store") as StoreScreen
	(st.find_child("ClaimAll", true, false) as Button).pressed.emit()
	await runner.get_tree().process_frame
	rv = game.modals.screen(&"reward_reveal") as RewardReveal
	check(rv != null and rv.hero() is ItemStage, "the season outfit from the pass gets its celebration")
	game.modals.close_all()
	await runner.get_tree().process_frame
	# Reduce motion: semuanya langsung, tanpa partikel dan tanpa crumbs terbang
	# (crumbs klaim Pass tadi mendarat dulu).
	await runner.get_tree().create_timer(1.6).timeout
	SettingsManager.set_value("reduced_motion", true)
	var calm: RewardReveal = game.modals.open(&"reward_reveal", {"deco": &"skin_awning_mint"}) as RewardReveal
	for i3 in 3:
		await runner.get_tree().process_frame
	check(calm != null and calm._shade.color.a > 0.8, "Reduce motion shows the celebration at once")
	check(calm != null and calm.find_child("ConfettiFX", true, false) == null, "without confetti")
	game.modals.close_all()
	await runner.get_tree().process_frame
	game.hud.fly_crumbs(Vector2(100, 100), 50)
	var calm_fly: int = 0
	for n3: Node in fx.get_children():
		calm_fly += 1 if String(n3.name).begins_with("FlyingCrumb") else 0
	eq(calm_fly, 0, "and no flying crumbs")
	SettingsManager.set_value("reduced_motion", was_motion)
	await runner.get_tree().create_timer(0.3).timeout
	# Prototipe model dekorasi yang baru diangkat disimpan di cache DecorFactory (bukan bocor).
	DecorFactory.clear_caches()
	check(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT) <= orphans0, "no orphan UI nodes")
	await _end(game)
	_teardown_store()


func _doors() -> void:
	var styles: Dictionary = {}
	for t in range(1, 6):
		var d: Node3D = DoorFactory.build(t, &"", 1.0, RoomFactory.interior_style(t)["frame"])
		var style: String = str(d.get_meta("door_style", ""))
		check(not styles.has(style), "tier %d has its own entrance (%s)" % [t, style])
		styles[style] = true
		var box: AABB = EquipmentFactory._mesh_bounds(d)
		check(box.end.y <= DoorFactory.MAX_H + 0.03, "tier %d entrance stays under the sign (top %.2f m)" % [t, box.end.y])
		var tris: int = ProceduralMeshFactory.tri_count(d)
		check(tris > 0 and tris <= 6000, "tier %d entrance within budget (%d tris)" % [t, tris])
		# Makin tinggi makin mewah: lampu mulai Tier 3, karpet ke trotoar mulai Tier 4.
		eq(d.find_child("Glow", true, false) != null, t >= 3, "tier %d %s lamps" % [t, "has" if t >= 3 else "has no"])
		eq(box.position.z < -0.5, t >= 4, "tier %d %s a carpet out to the pavement" % [t, "rolls out" if t >= 4 else "has no"])
		d.free()
	var skins: Array[MiscDefinitions.DecorationDefinition] = []
	for x: Variant in DataRegistry.decorations():
		var dd: MiscDefinitions.DecorationDefinition = x
		if dd.skin_target == &"door":
			skins.append(dd)
	check(skins.size() >= 5, "at least five door skins (%d)" % skins.size())
	for dd2: MiscDefinitions.DecorationDefinition in skins:
		check(dd2.source == &"premium" and dd2.price_crumbs > 0, "%s is sold for Golden Crumbs" % dd2.id)
		check(IconCanvas.NAMES.has(str(DecorIcons.of_decor(dd2)[0])), "%s has an icon" % dd2.id)
		var d2: Node3D = DoorFactory.build(3, dd2.visual_profile_id, 1.0)
		var style2: String = str(d2.get_meta("door_style", ""))
		check(not styles.has(style2), "%s looks like no other door (%s)" % [dd2.id, style2])
		styles[style2] = true
		var box2: AABB = EquipmentFactory._mesh_bounds(d2)
		check(box2.end.y <= DoorFactory.MAX_H + 0.03, "%s stays under the sign (top %.2f m)" % [dd2.id, box2.end.y])
		var tris2: int = ProceduralMeshFactory.tri_count(d2)
		check(tris2 > 0 and tris2 <= 6000, "%s within budget (%d tris)" % [dd2.id, tris2])
		d2.free()
	# Di toko: pintu tier, lalu skin pintu yang dibeli.
	# Papan nama sepaket dengan pintunya.
	var signs: Dictionary = {}
	var inks: Dictionary = {}
	for t2 in range(1, 6):
		var sg: Node3D = RoomFactory.make_sign("Sign Test", {}, t2)
		var st: String = str(sg.get_meta("sign_style", ""))
		eq(st, "tier_%d" % t2, "tier %d has its own sign" % t2)
		signs[st] = true
		inks[str((sg.find_child("SignText", true, false) as Label3D).modulate)] = true
		sg.free()
	for dd3: MiscDefinitions.DecorationDefinition in skins:
		var sg2: Node3D = RoomFactory.make_sign("Sign Test", {"door": String(dd3.id)}, 2)
		eq(str(sg2.get_meta("sign_style", "")), String(dd3.visual_profile_id), "%s brings its matching sign" % dd3.id)
		var body: Node3D = sg2.get_child(0) as Node3D
		var tris3: int = ProceduralMeshFactory.tri_count(body)
		check(tris3 > 0 and tris3 <= 4000, "%s sign within budget (%d tris)" % [dd3.id, tris3])
		sg2.free()
	check(inks.size() >= 4, "the tier signs use different lettering colours (%d)" % inks.size())
	var carved: Node3D = RoomFactory.make_sign("Sign Test", {"storefront_sign": "skin_storefront_sign_carved_wood"}, 3)
	eq(str(carved.get_meta("sign_style", "")), "carved", "the carved sign skin still works without a door skin")
	carved.free()
	var both: Node3D = RoomFactory.make_sign("Sign Test", {"storefront_sign": "skin_storefront_sign_carved_wood", "door": "skin_door_candy"}, 3)
	eq(str(both.get_meta("sign_style", "")), "door_candy", "a door skin's sign comes first")
	both.free()
	# Kanopi naik di atas hiasan papan (telinga kucing).
	var kit: Node3D = RoomFactory.make_sign("Sign Test", {"door": "skin_door_kitty", "storefront": "skin_awning_mint"}, 2)
	var lift: float = float((kit.get_child(0) as Node3D).get_meta("top_extra", 0.0))
	var trim: Node3D = kit.find_child("AwningTrim", true, false) as Node3D
	check(lift > 0.0 and trim != null and trim.position.y > RoomFactory.SIGN_H * 0.5 + lift, "the awning sits above the cat ears")
	kit.free()
	var s2: SimulationRoot = new_sim(3409)
	s2.tutorial.skip()
	var loc: LocationDefinition = s2.world.location
	var room: Node3D = RoomFactory.build_floor(loc, loc.floors[0], "Door Test", s2.decoration.equipped.duplicate())
	var ent: Node3D = room.find_child("Entrance", true, false) as Node3D
	check(ent != null and str(ent.get_meta("door_style", "")) == "tier_%d" % loc.tier, "the shop has its tier entrance")
	room.free()
	s2.premium.crumbs = 1000
	eq(s2.decoration.buy(&"skin_door_galaxy"), &"", "a door skin is bought with crumbs")
	eq(str(s2.decoration.equipped.get("door", "")), "skin_door_galaxy", "and put on at once")
	room = RoomFactory.build_floor(loc, loc.floors[0], "Door Test", s2.decoration.equipped.duplicate())
	ent = room.find_child("Entrance", true, false) as Node3D
	check(ent != null and str(ent.get_meta("door_style", "")) == "door_galaxy", "the shop now has the galaxy door")
	var sgn: Node3D = room.find_child("Sign", true, false) as Node3D
	check(sgn != null and str(sgn.get_meta("sign_style", "")) == "door_galaxy", "and the galaxy sign")
	room.free()
	var stage: ItemStage = ItemStage.for_item(DataRegistry.decoration(&"skin_door_galaxy"), s2, 200)
	check(stage != null, "the door gets its own celebration stage")
	if stage != null:
		stage.free()
	free_sim(s2)


## Lebar tulisan Label3D papan nama dalam meter (huruf, ukuran, garis tepi, skala).
func _label_w(l: Label3D) -> float:
	var px: float = RoomFactory.sign_font().get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, l.font_size).x
	return (px + float(l.outline_size) * 2.0) * l.pixel_size


func _sign_fits_name() -> void:
	var names: Array[String] = ["A", "Sign Test", Tx.t("ui_bakery_name_default"), "Toko Roti Pak Budi Jaya",
		"WWWWWWWWWWWWWWWWWWWWWWWW", "iiiiiiiiiiiiiiiiiiiiiiii", "MMMMMMMMMMM MMMMMMMMMMMM",
		"Roti Lezat Bu Sri Jaya Abadi Sentosa Makmur Selalu Ramai Pembeli Tiap Hari"]
	var looks: Array[Dictionary] = [{}, {"storefront_sign": "skin_storefront_sign_carved_wood", "storefront": "skin_awning_gold"}]
	for dd: MiscDefinitions.DecorationDefinition in DataRegistry.decorations():
		if dd.placement_type == &"skin" and dd.skin_target == &"door":
			looks.append({"door": String(dd.id), "storefront": "skin_awning_mint"})
	check(looks.size() >= 7, "every door sign is checked (%d looks)" % looks.size())
	var pad: float = RoomFactory.SIGN_TEXT_PAD
	for tier in range(1, 6):
		var loc: LocationDefinition = DataRegistry.location_by_tier(tier)
		var f: FloorDefinition = loc.floor_def(loc.entrance_floor)
		var x0: float = INF
		var x1: float = -INF
		for c: Vector2i in f.entrance:
			x0 = minf(x0, float(c.x) * RoomFactory.T)
			x1 = maxf(x1, float(c.x + 1) * RoomFactory.T)
		var mid: float = (x0 + x1) * 0.5
		var half: float = minf(mid, float(f.size.x) * RoomFactory.T - mid)
		var room: float = RoomFactory.sign_room(f)
		near(room, RoomFactory.sign_room_for_tier(tier), 0.0001, "tier %d: the sign preview uses the same front width" % tier)
		var bad: Array[String] = []
		for n: String in names:
			for look: Dictionary in looks:
				var sg: Node3D = RoomFactory.make_sign(n, look, tier)
				var board: float = float(sg.get_meta("board_w", 0.0))
				var lab: Label3D = sg.find_child("SignText", true, false) as Label3D
				var tw: float = _label_w(lab)
				if lab.text != n:
					bad.append("%s: text changed" % n)
				if tw > board - pad * 2.0 + 0.002:
					bad.append("%s %s: text %.2f m on a %.2f m board" % [n, look, tw, board])
				if board > room + 0.0001 or board < RoomFactory.SIGN_MIN_W - 0.0001:
					bad.append("%s: board %.2f m (room %.2f)" % [n, board, room])
				var box: AABB = EquipmentFactory._mesh_bounds(sg)
				if box.position.x < -half - 0.01 or box.end.x > half + 0.01:
					bad.append("%s %s: sign spans %.2f..%.2f m, front half %.2f m" % [n, look, box.position.x, box.end.x, half])
				sg.free()
		check(bad.is_empty(), "tier %d: every name fits its board and every board fits the shop front %s" % [tier, bad.slice(0, 4)])
	# Papan tumbuh mengikuti nama; nama bawaan tampil penuh tanpa diperkecil.
	var w_short: float = RoomFactory.sign_width("A", RoomFactory.sign_room_for_tier(5))
	var w_mid: float = RoomFactory.sign_width(Tx.t("ui_bakery_name_default"), RoomFactory.sign_room_for_tier(5))
	var w_long: float = RoomFactory.sign_width("Toko Roti Pak Budi Jaya", RoomFactory.sign_room_for_tier(5))
	near(w_short, RoomFactory.SIGN_MIN_W, 0.0001, "a short name keeps the smallest board")
	check(w_mid > w_short and w_long > w_mid, "a longer name gets a longer board (%.2f < %.2f < %.2f m)" % [w_short, w_mid, w_long])
	var dflt: Node3D = RoomFactory.make_sign(Tx.t("ui_bakery_name_default"), {}, 1)
	near(float(dflt.get_meta("text_scale", 0.0)), 1.0, 0.0001, "the default name is written at full size on Tier 1")
	dflt.free()
	var wide: Node3D = RoomFactory.make_sign("WWWWWWWWWWWWWWWWWWWWWWWW", {}, 1)
	check(float(wide.get_meta("text_scale", 1.0)) < 1.0, "the widest 24-letter name shrinks to fit the Tier 1 front")
	near(float(wide.get_meta("board_w", 0.0)), RoomFactory.sign_room_for_tier(1), 0.0001, "on a board as wide as the front allows")
	wide.free()
	# Di toko sungguhan: papan dan hiasannya di dalam muka toko.
	var loc1: LocationDefinition = DataRegistry.location_by_tier(1)
	var f1: FloorDefinition = loc1.floor_def(loc1.entrance_floor)
	var shop: Node3D = RoomFactory.build_floor(loc1, f1, "WWWWWWWWWWWWWWWWWWWWWWWW", {"door": "skin_door_ocean", "storefront": "skin_awning_mint"})
	var sgn: Node3D = shop.find_child("Sign", true, false) as Node3D
	var sb: AABB = EquipmentFactory._mesh_bounds(sgn)
	var fw: float = float(f1.size.x) * RoomFactory.T
	check(sgn.position.x + sb.position.x >= -0.01 and sgn.position.x + sb.end.x <= fw + 0.01,
		"the Tier 1 sign stays inside the 3 m front (%.2f..%.2f m)" % [sgn.position.x + sb.position.x, sgn.position.x + sb.end.x])
	shop.free()
	# Papan 2D: nama panjang mengecil, tidak dipotong.
	var font: Font = ProceduralUIFactory.display_font()
	var sz: int = ProceduralUIFactory.fit_font_size(font, "WWWWWWWWWWWWWWWWWWWWWWWW", 22, NewGameScreen.SIGN_MAX_W - 8.0)
	check(sz < 22 and font.get_string_size("WWWWWWWWWWWWWWWWWWWWWWWW", HORIZONTAL_ALIGNMENT_LEFT, -1, sz).x <= NewGameScreen.SIGN_MAX_W - 8.0,
		"the New Game sign preview shrinks a 24-letter name to fit (%d px)" % sz)
	eq(ProceduralUIFactory.fit_font_size(font, "Bakery", 22, 400.0), 22, "a short name keeps its size")
	var board2 := Signboard.new()
	board2.custom_minimum_size = Vector2(520, 300)
	board2.title_text = "WWWWWWWWWWWWWWWWWWWWWWWW"
	runner.add_child(board2)
	await runner.get_tree().process_frame
	var title: Label = board2.find_child("Title", true, false) as Label
	var ts: int = title.get_theme_font_size("font_size")
	check(font.get_string_size(title.text, HORIZONTAL_ALIGNMENT_LEFT, -1, ts).x <= title.size.x + 1.0 and title.get_line_count() == 1,
		"the franchise signboard writes a long name on one line (%d px)" % ts)
	board2.queue_free()
	await runner.get_tree().process_frame
