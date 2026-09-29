extends TestSuite
## Aturan balance keputusan maintainer 2026-09-29: Pasar hanya menjual alat
## setinggi tier lokasi (GDD 5.1.2), harga terkunci selama Hari 1-3 (63.2), dan
## pesanan RotiFood memilih resep berbobot penerimaan harga (22.9).


func tests() -> Array:
	return [
		{"id": "ACC_5_TIER_GATE", "name": "5.1.2 the Market sells equipment only up to the store tier; owned equipment is unaffected", "fn": _tier_gate},
		{"id": "ACC_63_PRICE_LOCK", "name": "63.2 prices stay at the reference price through Day 3 and unlock in the Day 3 after-hours", "fn": _price_lock},
		{"id": "ACC_22_ROTIFOOD_WEIGHTS", "name": "22.9 RotiFood picks menu recipes by price acceptance, so overpriced bread is rarely ordered", "fn": _rotifood_weights},
	]


func _tier_gate() -> void:
	var s: SimulationRoot = new_sim(5120)
	s.time.set_phase(TimeManager.AFTER_HOURS)
	s.debug_add_kr(500000.0)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var start: float = s.economy.balance
	eq(str(s.equipment.buy(&"oven_t2").get("reason", "")), "tier_locked", "a Tier 1 store cannot buy a Tier 2 oven")
	eq(str(s.equipment.buy_replace(&"mixer_t3", mixer.iid).get("reason", "")), "tier_locked", "nor replace its mixer with a Tier 3 one")
	near(s.economy.balance, start, 0.001, "refused purchases cost nothing")
	check(s.equipment.tier_allowed(DataRegistry.equipment(&"display_t1")), "Tier 1 equipment is always for sale")
	eq(s.upgrade_location(), "", "upgrade to Tier 2")
	s.time.set_phase(TimeManager.AFTER_HOURS)
	check(bool(s.equipment.buy(&"oven_t2").get("ok", false)), "the Tier 2 store sells a Tier 2 oven")
	eq(str(s.equipment.buy(&"mixer_t3").get("reason", "")), "tier_locked", "but not a Tier 3 mixer")
	var r: Dictionary = s.equipment.buy_replace(&"mixer_t2", mixer.iid)
	check(bool(r.get("ok", false)), "replacing with a Tier 2 mixer works")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _price_lock() -> void:
	var s: SimulationRoot = new_sim(6320)
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	check(s.pricing.prices_locked(), "Day 1 prices are locked")
	near(s.pricing.set_price(loaf.id, 150.0), loaf.base_sell_price_kr, 0.001, "setting a price on Day 1 changes nothing")
	check(not s.pricing.prices.has(loaf.id), "no override is stored")
	s.time.set_phase(TimeManager.AFTER_HOURS)
	check(s.pricing.prices_locked(), "the Day 1 after-hours plans Day 2, still locked")
	s.time.day = 2
	check(s.pricing.prices_locked(), "the Day 2 after-hours plans Day 3, still locked")
	s.time.day = 3
	s.time.set_phase(TimeManager.OPEN)
	check(s.pricing.prices_locked(), "Day 3 itself is locked")
	s.time.set_phase(TimeManager.AFTER_HOURS)
	check(not s.pricing.prices_locked(), "the Day 3 after-hours plans Day 4 and unlocks prices")
	near(s.pricing.set_price(loaf.id, 120.0), 120.0, 0.001, "prices can be set for Day 4")
	# Save lama dengan harga kustom di hari manifest tetap menjual di harga referensi.
	s.time.day = 2
	s.time.set_phase(TimeManager.OPEN)
	near(s.pricing.price_of(loaf.id), loaf.base_sell_price_kr, 0.001, "a stored override does not apply on Days 1-3")
	s.time.day = 4
	near(s.pricing.price_of(loaf.id), 120.0, 0.001, "and applies again from Day 4")
	free_sim(s)


## Unit tiap resep dari `n` order acak.
func _order_units(s: SimulationRoot, n: int) -> Dictionary:
	var units: Dictionary = {}
	for i in n:
		var o: DeliveryOrder = s.rotifood.create_random_order()
		for rid: Variant in o.items.keys():
			units[rid] = int(units.get(rid, 0)) + int(o.items[rid])
	return units


func _rotifood_weights() -> void:
	var s: SimulationRoot = new_sim(2290)
	s.time.day = 4
	s.time.set_phase(TimeManager.OPEN)
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var donut: RecipeDefinition = DataRegistry.recipe(&"recipe_sugar_donut")
	stock(s, loaf.id, 10, 0)
	stock(s, donut.id, 10, 1)
	near(s.rotifood.menu_weight(loaf.id), 0.8, 0.0001, "reference price: acceptance 1.0 / 1.25")
	var even: Dictionary = _order_units(s, 300)
	var share_even: float = float(even.get(donut.id, 0)) / float(int(even.get(donut.id, 0)) + int(even.get(loaf.id, 0)))
	check(share_even > 0.4 and share_even < 0.6, "equal price ratios share orders evenly (%.2f)" % share_even)
	s.pricing.set_price(donut.id, donut.max_price_kr)
	near(s.rotifood.menu_weight(donut.id), 0.08, 0.0001, "1.8× the reference price: acceptance 0.10 / 1.25")
	var skew: Dictionary = _order_units(s, 300)
	var share_high: float = float(skew.get(donut.id, 0)) / float(int(skew.get(donut.id, 0)) + int(skew.get(loaf.id, 0)))
	check(share_high < 0.3, "the overpriced donut gets far fewer units (%.2f)" % share_high)
	free_sim(s)
