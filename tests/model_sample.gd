class_name ModelSample
extends RefCounted
## Toko contoh Tier 1-5 untuk menguji model KR/s (GDD idle 9.1,
## ACC_IDLE_MODEL_MATCH) dan probe-nya: semua stasiun terbuka pada level yang
## wajar untuk tier itu, staf penuh, resep yang bisa dibuat terbuka, dan KR
## cukup untuk bahan. Hanya memakai API yang juga dipakai UI.

## Level stasiun, kasir, dan staf per tier.
const STATION_LEVELS: Array[int] = [8, 20, 40, 60, 90]
## Level resep per tier.
const RECIPE_LEVELS: Array[int] = [3, 10, 25, 50, 80]


static func build(sim: SimulationRoot, tier: int) -> void:
	sim.tutorial.skip()
	while sim.world.location.tier < tier:
		sim.debug_add_kr(SimulationRoot.location_cost(sim.world.location.tier + 1))
		if sim.upgrade_location() != "":
			break
	sim.debug_add_kr(1.0e15)
	var lv: int = mini(STATION_LEVELS[tier - 1], sim.upgrades.level_cap())
	# Seperti pemain: semua stasiun (murah) dibuka dulu, baru dinaikkan levelnya.
	for cat: StringName in [&"display", &"oven", &"mixer"]:
		while sim.upgrades.open_station(cat) >= 0:
			pass
	for cat2: StringName in [&"display", &"oven", &"mixer"]:
		for e: EquipmentInstance in sim.equipment.placed_list(cat2):
			sim.upgrades.set_station_level(e.iid, lv)
	sim.upgrades.counter_level = lv
	for role: StringName in [&"cashier", &"baker"]:
		for st: StaffDefinition in DataRegistry.staff_list():
			if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
				break
			if st.role_id == role and not sim.staff.is_employed(st.id):
				sim.staff.hire(st.id, true)
	for sid: StringName in sim.staff.employed_ids():
		sim.upgrades.staff_levels[sid] = lv
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.upgrades.unlock_block(r.id) == &"":
			sim.upgrades.unlock_recipe(r.id)
		if sim.upgrades.is_unlocked(r.id):
			sim.upgrades.recipe_levels[r.id] = RECIPE_LEVELS[tier - 1]
	# Petak rak memakai Auto: resep paling untung.
	for d: EquipmentInstance in sim.equipment.placed_list(&"display"):
		for i in sim.display.slot_count(d.iid):
			sim.display.set_assignment(d.iid, i, &"")
	no_boosts(sim)


## Model dibandingkan tanpa boost (GDD idle 9.1): semua pencapaian ditandai
## sudah didapat tanpa hadiah supaya boost ×2-nya tidak muncul di tengah
## pengukuran, lalu boost yang sudah jalan dihentikan.
static func no_boosts(sim: SimulationRoot) -> void:
	for x: Variant in DataRegistry.achievements():
		sim.achievements.unlocked[String((x as MiscDefinitions.AchievementDefinition).id)] = sim.time.day
	sim.boosts.new_run()
	sim.idle_economy.invalidate()


## Jalankan `warm` jam in-game, lalu ukur `hours` jam: rata-rata KR/s model
## (diambil tiap seperempat jam) dan laba bersih nyata per detik nyata.
static func measure(sim: SimulationRoot, warm: float, hours: float) -> Dictionary:
	var per_hour: int = int(round(sim.time.sim_seconds_for_hours(1.0) / sim.tick_seconds))
	for i in int(per_hour * warm):
		sim.step(sim.tick_seconds)
	var net0: float = net_total(sim)
	var sales0: float = sales_total(sim)
	var sold0: float = sim.statistics.get_stat("total_bread_sold")
	var st0: Dictionary = sim.statistics.stats.duplicate()
	var stock0: float = stock_value(sim)
	var model_sum: float = 0.0
	var units_sum: float = 0.0
	var demand_sum: float = 0.0
	var prod_sum: float = 0.0
	var samples: int = 0
	var quarter: int = maxi(1, per_hour / 4)
	var ticks: int = int(per_hour * hours)
	for t in ticks:
		if t % quarter == 0:
			var m: Dictionary = sim.idle_economy.compute(false)
			model_sum += float(m["rate"])
			units_sum += float(m["units_per_hour"])
			demand_sum += float(m["demand"])
			prod_sum += float(m["production"])
			samples += 1
		sim.step(sim.tick_seconds)
	var net: float = net_total(sim) - net0
	var sales: float = sales_total(sim) - sales0
	# Bahan yang dibayar untuk roti yang belum terjual (rak penuh, batch berjalan)
	# bukan biaya roti terjual: selisih nilai stok dikembalikan.
	net += stock_value(sim) - stock0
	var real_s: float = DataRegistry.real_seconds(sim.time.sim_seconds_for_hours(hours))
	var n: float = float(maxi(samples, 1))
	return {"model": model_sum / n, "live": net / maxf(real_s, 0.0001), "units_model": units_sum / n,
		"units_live": (sim.statistics.get_stat("total_bread_sold") - sold0) / hours,
		"demand": demand_sum / n, "production": prod_sum / n,
		"entered": (sim.statistics.get_stat("total_customers_entered") - float(st0["total_customers_entered"])) / hours,
		"served": (sim.statistics.get_stat("total_customers_served") - float(st0["total_customers_served"])) / hours,
		"missed": (sim.statistics.get_stat("total_customers_missed") - float(st0["total_customers_missed"])) / hours,
		"lost": (sim.statistics.get_stat("total_customers_lost_patience") - float(st0["total_customers_lost_patience"])) / hours,
		"nostock": (sim.statistics.get_stat("total_customers_left_no_purchase") - float(st0["total_customers_left_no_purchase"])) / hours,
		"rf_done": (sim.statistics.get_stat("total_rotifood_orders_completed") - float(st0["total_rotifood_orders_completed"])) / hours,
		"rf_exp": (sim.statistics.get_stat("total_rotifood_orders_expired") - float(st0["total_rotifood_orders_expired"])) / hours,
		"rep": sim.reputation.reputation,
		"produced": (sim.statistics.get_stat("total_bread_produced") - float(st0["total_bread_produced"])) / hours,
		"jobs": sim.production.jobs.size(), "table": sim.production.table_jobs().size(),
		"live_price": sales / maxf(sim.statistics.get_stat("total_bread_sold") - sold0, 1.0),
		"model_net": float(sim.idle_economy.compute(false)["net_per_unit"]), "auto": String(sim.auto_recipe())}


## Nilai bahan (biaya per unit) dari semua roti yang sudah dibayar tetapi belum
## terjual: di rak, di tangan pembeli, dipesan RotiFood, dan batch yang berjalan.
static func stock_value(sim: SimulationRoot) -> float:
	var v: float = 0.0
	for iid: Variant in sim.display.display_ids():
		for sl: Variant in sim.display.slots(int(iid)):
			for st: BreadStack in (sl as Dictionary)["stacks"]:
				v += float(st.quantity) * DataRegistry.recipe(st.recipe_id).unit_cogs_kr()
	for c: Customer in sim.customers.sorted():
		for lot: Variant in c.held:
			var st2: BreadStack = (lot as Dictionary)["stack"]
			v += float(st2.quantity) * DataRegistry.recipe(st2.recipe_id).unit_cogs_kr()
	for o: DeliveryOrder in sim.rotifood.active_orders():
		for lot2: Variant in o.reserved_lots:
			var st3: BreadStack = (lot2 as Dictionary)["stack"]
			v += float(st3.quantity) * DataRegistry.recipe(st3.recipe_id).unit_cogs_kr()
	for j: ProductionJob in sim.production.sorted_jobs():
		v += float(j.quantity_output) * DataRegistry.recipe(j.recipe_id).unit_cogs_kr()
	return v


## Jumlah sepanjang permainan satu kategori ledger (entri lama yang sudah
## diringkas ikut dihitung, v3.1 129).
static func category_total(sim: SimulationRoot, cat: String) -> float:
	var v: float = float(sim.economy.historical_totals.get(cat, 0.0))
	for e: Dictionary in sim.economy.ledger:
		if str(e["category"]) == cat:
			v += float(e["amount"])
	return v


static func sales_total(sim: SimulationRoot) -> float:
	return category_total(sim, "SALE_PHYSICAL") + category_total(sim, "SALE_ROTIFOOD")


## Penjualan dikurangi bahan.
static func net_total(sim: SimulationRoot) -> float:
	return sales_total(sim) + category_total(sim, "INGREDIENT_COST")

