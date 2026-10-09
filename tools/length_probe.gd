extends Node
## Alat ukur panjang game (target maintainer 2026-09-29: pemain biasa memiliki
## lokasi Tier 5, alat Tier 5 di semua slot mixer/oven/rak, dan semua dekorasi
## toko dalam ~26 hari in-game ≈ 6 jam di 1×). Bot memainkan game baru hanya
## lewat API yang juga dipakai UI, lalu mencetak hari tercapainya target.
##
## Varian:
## - typical: harga referensi, dua resep dengan laba per potong terbesar, naik
##   lokasi lalu ganti alat, belanja hanya bila kas longgar (2× harga).
## - eager: sama, tetapi berinvestasi begitu kas cukup (batas bawah kasar).
##
## Jalankan sebagai scene (bukan --script):
##   godot --headless --path . res://tools/length_probe.tscn -- --seed=101 --variant=typical [--days=60]


func _ready() -> void:
	var seed_value: int = 101
	var variant: String = "typical"
	var max_days: int = 60
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
		elif a.begins_with("--variant="):
			variant = a.get_slice("=", 1)
		elif a.begins_with("--days="):
			max_days = int(a.get_slice("=", 1))
	PauseManager.clear_all()
	var sim := SimulationRoot.new()
	add_child(sim)
	sim.start_new_game(&"profile_length_probe", "Probe Bakery", "male", seed_value)
	sim.tutorial.skip()
	var bot := LengthBot.new(sim)
	bot.variant = variant
	var t0: int = Time.get_ticks_msec()
	print("variant %s seed %d" % [variant, seed_value])
	for i in max_days:
		bot.play_day()
		print(bot.day_line())
		if bot.goal_day > 0:
			break
	print("MILESTONES ", bot.milestones)
	print("RESULT variant=%s seed=%d goal_day=%d days_played=%d wall=%.0fs" % [variant, seed_value, bot.goal_day,
		sim.time.day - 1, (Time.get_ticks_msec() - t0) / 1000.0])
	remove_child(sim)
	sim.free()
	get_tree().quit(0)


class LengthBot extends SimBot:
	var variant: String = "typical"
	var goal_day: int = -1
	var milestones: Dictionary = {}
	## [{id: StringName, w: float}]: resep yang dibuat dan porsinya.
	var portfolio: Array = []
	var sold_today_units: int = 0
	var profit_today: float = 0.0
	var revenue_today: float = 0.0
	var _port_key: String = ""
	var _next_reorder_sim: float = 0.0
	var _bal_open: float = 0.0
	var _actions: Array[String] = []
	var _cust_stats: String = ""
	var _rf_stats: String = ""
	## Rak lama yang sedang dikosongkan supaya bisa diganti (rak berisi roti
	## tidak bisa diganti, GDD 5.1.2): pemain tidak menaruh roti di sana.
	var _drain: Dictionary = {}

	func _init(s: SimulationRoot) -> void:
		super(s)
		think_interval = 6

	# -----------------------------------------------------------------------
	# HARI
	# -----------------------------------------------------------------------

	func play_day() -> void:
		_actions.clear()
		_cust_stats = ""
		_rf_stats = ""
		_bal_open = sim.economy.balance
		_refresh_portfolio()
		while sim.is_running():
			think()
			if sim.time.time_seconds >= sim.time.close_time - 60.0 and _cust_stats == "":
				# Tepat sebelum 18:00 (penutupan mengosongkan penghitung harian).
				_cust_stats = "in %d paid %d quit %d nostock %d missed %d" % [sim.customers.entered_today,
					sim.customers.served_today, sim.customers.abandoned_today, sim.customers.no_stock_today, sim.demand.missed_today]
				_rf_stats = "got %d ok %d fail %d" % [sim.rotifood.received_today, sim.rotifood.completed_today, sim.rotifood.cancelled_today]
			sim.step(sim.tick_seconds)
		sold_today_units = 0
		if not sim.analytics.daily.is_empty():
			var last: Dictionary = sim.analytics.daily[sim.analytics.daily.size() - 1]["sold"]
			for k: Variant in last.keys():
				sold_today_units += int(last[k])
		revenue_today = sim.economy.today_total(&"SALE_PHYSICAL") + sim.economy.today_total(&"SALE_ROTIFOOD")
		profit_today = sim.economy.balance - _bal_open
		sim.enter_after_hours()
		_after_hours_plan()
		_check_goal()
		sim.continue_to_next_day()

	## Hari yang sedang direncanakan: after-hours merencanakan esok hari.
	func _plan_day() -> int:
		return sim.time.day + 1 if sim.time.is_after_hours() else sim.time.day

	func _scripted_day() -> bool:
		return not DataRegistry.opening_day(_plan_day()).is_empty()

	func eq_tier() -> int:
		return mini(sim.equipment.best_tier(&"mixer"), sim.equipment.best_tier(&"oven"))

	func _tiers(cat: StringName) -> String:
		var t: Array[String] = []
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			t.append(str(e.tier()))
		return "".join(t)

	func day_line() -> String:
		var port: Array[String] = []
		for e: Dictionary in portfolio:
			port.append(String(e["id"]).replace("recipe_", ""))
		return "D%02d L%d mix[%s] ovn[%s] dsp[%s] | bal %s | profit %s rev %s sold %d | cust %s | rf %s | rating %.2f rf %.2f | staff c%d b%d | %s | %s" % [
			sim.time.day - 1, sim.world.location.tier, _tiers(&"mixer"), _tiers(&"oven"), _tiers(&"display"),
			Tx.kr(sim.economy.balance), Tx.kr(profit_today), Tx.kr(revenue_today), sold_today_units, _cust_stats, _rf_stats,
			sim.reputation.physical, sim.reputation.rotifood, sim.staff.employed_ids(&"cashier").size(),
			sim.staff.employed_ids(&"baker").size(), ",".join(port), "; ".join(_actions)]

	# -----------------------------------------------------------------------
	# PORTOFOLIO (GDD 61, 63.2): harga referensi, dua resep laba per potong
	# terbesar yang bisa dibuat dengan alat terpasang.
	# -----------------------------------------------------------------------

	func _refresh_portfolio() -> void:
		if _scripted_day():
			portfolio = []
			_port_key = ""
			return
		var key: String = "%d_%d" % [sim.equipment.best_tier(&"mixer"), sim.equipment.best_tier(&"oven")]
		if key == _port_key:
			return
		_port_key = key
		var ranked: Array[RecipeDefinition] = []
		for r: RecipeDefinition in DataRegistry.recipes():
			if sim.production.owns_equipment_for(r):
				ranked.append(r)
		ranked.sort_custom(func(a: RecipeDefinition, b: RecipeDefinition) -> bool:
			var ma: float = a.base_sell_price_kr - a.unit_cogs_kr()
			var mb: float = b.base_sell_price_kr - b.unit_cogs_kr()
			return ma > mb if not is_equal_approx(ma, mb) else String(a.id) < String(b.id))
		portfolio = []
		for i in mini(2, ranked.size()):
			portfolio.append({"id": ranked[i].id, "w": 1.0})

	func _share(e: Dictionary) -> float:
		var tot: float = 0.0
		for x: Dictionary in portfolio:
			tot += float(x["w"])
		return float(e["w"]) / maxf(tot, 0.0001)

	## Perkiraan unit terjual per jam in-game (fisik + RotiFood).
	func _units_per_hour(t: float) -> float:
		var tt: float = maxf(t, sim.time.open_time)
		var phys: float = sim.demand.physical_rate_per_hour(tt) * 2.3
		var rf: float = 0.0
		if tt < DataRegistry.balf("rotifood.last_order_time_seconds"):
			rf = sim.demand.rotifood_rate_per_hour(tt) * 4.0
		return phys + rf

	func _target_units(e: Dictionary) -> float:
		var now: float = maxf(sim.time.time_seconds, sim.time.open_time)
		var hours_left: float = maxf(0.0, (sim.time.close_time - now) / 3600.0)
		var target: float = _units_per_hour(now) * _share(e) * minf(2.5, hours_left)
		if now < DataRegistry.balf("rotifood.last_order_time_seconds"):
			target += 6.0
		return target

	# -----------------------------------------------------------------------
	# DAPUR
	# -----------------------------------------------------------------------

	func think() -> void:
		super.think()
		if not _scripted_day() and sim.time.is_running_phase() and sim.time.sim_seconds >= _next_reorder_sim:
			_next_reorder_sim = sim.time.sim_seconds + 10.0
			_midday_reorder()

	func _decide() -> void:
		if _scripted_day():
			super._decide()
			return
		var p: PlayerTaskManager = sim.player
		var carried: ProductionJob = p.carried_job()
		var table: EquipmentInstance = sim.equipment.table_instance()
		if carried != null:
			if carried.stage == ProductionJob.CARRIED_TO_OVEN:
				var oven: EquipmentInstance = sim.production.free_oven_for(carried.recipe())
				if oven != null:
					p.tap_equipment(oven.iid)
					return
				if table != null:
					p.tap_equipment(table.iid)
					return
			elif carried.stage == ProductionJob.CARRIED_TO_DISPLAY:
				# Rak tier tertinggi yang masih punya ruang untuk resep ini, bukan
				# rak yang sedang dikosongkan; kalau tidak ada, ke Meja Tunggu.
				var best_d: EquipmentInstance = null
				for e2: EquipmentInstance in sim.equipment.placed_list(&"display"):
					if _drain.has(e2.iid):
						continue
					if _display_room(e2.iid, carried.recipe_id) > 0 and (best_d == null or e2.tier() > best_d.tier()):
						best_d = e2
				if best_d != null:
					p.tap_equipment(best_d.iid)
					return
				if table != null:
					p.tap_equipment(table.iid)
					return
			_serve_if_needed()
			return
		for j: ProductionJob in sim.production.sorted_jobs():
			if j.is_waiting_oven_pickup() and not sim.staff.handles(j):
				p.tap_equipment(j.oven_id)
				return
		if table != null and sim.production.table_pick() != null and sim.production.table_has_destination(sim.production.table_pick()):
			p.tap_equipment(table.iid)
			return
		for j2: ProductionJob in sim.production.sorted_jobs():
			if j2.owner_actor_id == PlayerTaskManager.PLAYER_ID and j2.stage == ProductionJob.MIX_DONE_WAITING_PICKUP:
				if sim.production.free_oven_for(j2.recipe()) != null:
					p.tap_equipment(j2.mixer_id)
					return
		for j3: ProductionJob in sim.production.sorted_jobs():
			if j3.owner_actor_id == PlayerTaskManager.PLAYER_ID and j3.stage == ProductionJob.ORDERED:
				p.tap_equipment(j3.mixer_id)
				return
		if _serve_if_needed():
			return
		if not _plan_batch().is_empty():
			var storage: EquipmentInstance = sim.equipment.storage_instance()
			if storage != null:
				p.tap_equipment(storage.iid)
				return
		if sim.time.is_open() and p.manning_lane == &"":
			p.tap_cashier(sim.queue.main_lane().id, false)

	## Buku Resep: koki yang bertugas mendapat pesanan (Ask a Baker, GDD 23.3);
	## kalau tidak bisa, pemain membuatnya sendiri.
	func _choose_recipe() -> void:
		if _scripted_day():
			super._choose_recipe()
			return
		var plan: Dictionary = _plan_batch()
		if plan.is_empty():
			return
		if sim.staff.kitchen_staffed() and sim.staff.order_recipe(plan["recipe"], int(plan["batch"])) == "":
			return
		sim.player.order_recipe(plan["recipe"], int(plan["batch"]))

	func _plan_batch() -> Dictionary:
		if portfolio.is_empty():
			return {}
		if sim.production.free_mixer_for(DataRegistry.recipe(portfolio[0]["id"])) == null \
				and (portfolio.size() < 2 or sim.production.free_mixer_for(DataRegistry.recipe(portfolio[1]["id"])) == null):
			return {}
		var stock: Dictionary = sim.display.sellable_by_recipe()
		var rf_need: Dictionary = {}
		for o: DeliveryOrder in sim.rotifood.active_orders():
			if not o.packed:
				for rid: Variant in o.items.keys():
					rf_need[rid] = int(rf_need.get(rid, 0)) + int(o.items[rid])
		var inflight: Dictionary = {}
		var inflight_total: int = 0
		for j: ProductionJob in sim.production.sorted_jobs():
			var lifted: bool = j.stage in [ProductionJob.CARRIED_TO_DISPLAY, ProductionJob.PLACEMENT_UI, ProductionJob.TRAY_ON_TABLE]
			var u: int = j.carried_units if lifted else j.quantity_output
			inflight[j.recipe_id] = int(inflight.get(j.recipe_id, 0)) + u
			inflight_total += u
		var free_disp: int = sim.display.total_free_units() - inflight_total
		var best: Dictionary = {}
		var best_score: float = 0.0
		var best_def: float = 0.0
		for e: Dictionary in portfolio:
			var r: RecipeDefinition = DataRegistry.recipe(e["id"])
			var target: float = _target_units(e) + float(int(rf_need.get(r.id, 0)))
			var have: float = float(int(stock.get(r.id, 0)) + int(inflight.get(r.id, 0)))
			var deficit: float = target - have
			if deficit <= 0.0:
				continue
			if sim.production.make_block_reason(r.id, 1) != "":
				continue
			if not _fits_before_close(r, 1):
				continue
			var score: float = deficit / maxf(target, 1.0)
			if score > best_score:
				best_score = score
				best = e
				best_def = deficit
		if best.is_empty():
			return {}
		var rb: RecipeDefinition = DataRegistry.recipe(best["id"])
		var room: int = 0
		for d: EquipmentInstance in sim.equipment.placed_list(&"display"):
			if not _drain.has(d.iid):
				room += _display_room(d.iid, rb.id)
		room = mini(room - int(inflight.get(rb.id, 0)), free_disp)
		for b: int in [5, 3, 1]:
			if rb.batch_yield * b > room:
				continue
			if not sim.inventory.has_for_recipe(rb, b):
				continue
			if b > 1 and float(rb.batch_yield * b) > best_def + float(rb.batch_yield) * 2.0:
				continue
			if not _fits_before_close(rb, b):
				continue
			return {"recipe": rb.id, "batch": b}
		return {}

	## Unit resep ini yang masih muat di rak (petak resep sama atau petak kosong).
	func _display_room(iid: int, rid: StringName) -> int:
		var n: int = 0
		for i in sim.display.slots(iid).size():
			n += sim.display.slot_room(iid, i, rid)
		return mini(n, sim.display.free_units(iid))

	## Batch harus selesai dan terpajang sebelum toko tutup (dapur kosong untuk
	## upgrade lokasi, GDD 105).
	func _fits_before_close(r: RecipeDefinition, b: int) -> bool:
		var mt: int = 1
		for m: EquipmentInstance in sim.equipment.placed_list(&"mixer"):
			if m.tier() >= r.required_mixer_tier and m.job_id < 0:
				mt = m.tier()
				break
		var ot: int = sim.equipment.best_tier(&"oven")
		var secs: float = sim.production.mixer_stage_seconds(r, mt, b, 1.0) + sim.production.oven_stage_seconds(r, ot, b, 1.0) + 60.0
		return sim.time.time_seconds + secs * sim.time.ratio < sim.time.close_time - 1800.0

	# -----------------------------------------------------------------------
	# BAHAN (GDD 5.2, 24A)
	# -----------------------------------------------------------------------

	func _units_for(hours: float, from_t: float) -> Dictionary:
		var out: Dictionary = {}
		var per_hour: float = _units_per_hour(from_t)
		for e: Dictionary in portfolio:
			out[e["id"]] = per_hour * _share(e) * hours
		return out

	func _ingredient_gap(units_by_recipe: Dictionary) -> Dictionary:
		var need: Dictionary = {}
		for rid: Variant in units_by_recipe.keys():
			var r: RecipeDefinition = DataRegistry.recipe(rid)
			var batches: int = int(ceil(float(units_by_recipe[rid]) / float(r.batch_yield)))
			for ing: StringName in r.ingredients.keys():
				need[ing] = int(need.get(ing, 0)) + int(r.ingredients[ing]) * batches
		var items: Dictionary = {}
		for ing2: Variant in need.keys():
			var gap: int = int(need[ing2]) - sim.inventory.count(ing2) - sim.supply.in_transit_of(ing2)
			if gap > 0:
				items[ing2] = gap
		return items

	func _cost_of(items: Dictionary) -> float:
		var c: float = 0.0
		for k: Variant in items.keys():
			c += DataRegistry.ingredient(StringName(str(k))).fixed_buy_price_kr * int(items[k])
		return c

	## Pesan sesuai kapasitas Gudang dan kas; dipotong proporsional bila tidak muat.
	func _buy(items: Dictionary, budget: float) -> void:
		if items.is_empty():
			return
		var units: int = 0
		for k: Variant in items.keys():
			units += int(items[k])
		var f: float = 1.0
		var cap: int = sim.supply.max_additional_units()
		if units > cap:
			f = minf(f, float(cap) / float(units))
		var cost: float = _cost_of(items)
		if cost > budget:
			f = minf(f, budget / maxf(cost, 1.0))
		if f <= 0.0:
			return
		var scaled: Dictionary = {}
		for k2: Variant in items.keys():
			var q: int = int(floor(float(items[k2]) * f))
			if q > 0:
				scaled[k2] = q
		if not scaled.is_empty():
			sim.supply.purchase(scaled)

	## Kurir tiba 3 jam in-game kemudian: stok bahan cukup untuk 6 jam ke depan.
	func _midday_reorder() -> void:
		if not sim.supply.market_unlocked or portfolio.is_empty() or sim.time.time_seconds > 15.5 * 3600.0:
			return
		_buy(_ingredient_gap(_units_for(6.0, sim.time.time_seconds)), sim.economy.balance - sim.staff.scheduled_wages() - 500.0)

	func _tomorrow_units() -> Dictionary:
		var total: float = 0.0
		var t: float = sim.time.open_time
		while t < sim.time.close_time:
			total += _units_per_hour(t)
			t += 3600.0
		total = maxf(total, float(sold_today_units) * 1.3) + _units_per_hour(sim.time.open_time) * 2.5
		var out: Dictionary = {}
		for e: Dictionary in portfolio:
			out[e["id"]] = total * _share(e)
		return out

	# -----------------------------------------------------------------------
	# AFTER-HOURS: alat, lokasi, staf, iklan, dekorasi, bahan
	# -----------------------------------------------------------------------

	func _slack() -> float:
		return 1.0 if variant == "eager" else 2.0

	func _after_hours_plan() -> void:
		if not sim.supply.market_unlocked:
			return
		if sim.upgrade_block_reason() == "ui_upgrade_blocked_jobs":
			_actions.append("upgrade blocked by kitchen jobs")
		_refresh_portfolio()
		var reserve: float = _reserve()
		_invest(reserve)
		_hire_staff(_reserve())
		_plan_drain()
		_marketing(_reserve())
		_decorations(_reserve())
		_refresh_portfolio()
		_buy(_ingredient_gap(_tomorrow_units()), sim.economy.balance - sim.staff.scheduled_wages() - 100.0)

	## Cadangan: bahan ~6 jam pertama esok + gaji + sedikit kas.
	func _reserve() -> float:
		return _cost_of(_ingredient_gap(_units_for(6.0, sim.time.open_time))) * 1.1 + sim.staff.scheduled_wages() + 300.0

	func _invest(reserve: float) -> void:
		var guard: int = 0
		while guard < 40:
			guard += 1
			var loc: int = sim.world.location.tier
			var bal: float = sim.economy.balance
			var nxt: LocationDefinition = sim.next_location()
			if nxt != null and bal - nxt.upgrade_cost_kr >= reserve and sim.upgrade_block_reason() == "":
				var r: String = sim.upgrade_location()
				if r == "":
					_place_all_unplaced()
					_note("L%d" % sim.world.location.tier)
					_actions.append("location T%d" % sim.world.location.tier)
					reserve = _reserve()
					continue
				_actions.append("upgrade failed: " + r)
			var md: EquipmentDefinition = DataRegistry.equipment_for(&"mixer", loc)
			var od: EquipmentDefinition = DataRegistry.equipment_for(&"oven", loc)
			var pair_cost: float = md.price_kr + od.price_kr
			var lm: EquipmentInstance = _lowest(&"mixer")
			var lo: EquipmentInstance = _lowest(&"oven")
			# Pasangan pertama tier baru dibeli begitu terjangkau (resep baru).
			var first: bool = eq_tier() < loc
			var slack: float = 1.0 if first else _slack()
			if lm != null and lo != null and (lm.tier() < loc or lo.tier() < loc) and bal - pair_cost * slack >= reserve:
				if lm.tier() < loc:
					_replace(lm.iid, md.id)
				if lo.tier() < loc:
					_replace(lo.iid, od.id)
				if eq_tier() >= loc:
					_note("E%d" % loc)
				_actions.append("equip T%d" % loc)
				_refresh_portfolio()
				reserve = _reserve()
				continue
			if _pairs() < sim.equipment.slot_limit(&"mixer") and _pairs() < sim.equipment.slot_limit(&"oven") \
					and bal - pair_cost * _slack() >= reserve:
				if sim.equipment.placed_count(&"mixer") < sim.equipment.slot_limit(&"mixer"):
					_buy_place(md.id)
				if sim.equipment.placed_count(&"oven") < sim.equipment.slot_limit(&"oven"):
					_buy_place(od.id)
				_actions.append("pair T%d" % loc)
				continue
			var dd: EquipmentDefinition = DataRegistry.equipment_for(&"display", maxi(2, loc))
			if bal - dd.price_kr * _slack() >= reserve:
				var done: bool = false
				if sim.equipment.placed_count(&"display") < sim.equipment.slot_limit(&"display"):
					done = _buy_place(dd.id)
				else:
					var low: EquipmentInstance = _empty_low_display(dd.tier)
					if low != null:
						done = _replace(low.iid, dd.id)
				if done:
					_actions.append("display T%d" % dd.tier)
					continue
			break

	func _pairs() -> int:
		return mini(sim.equipment.placed_count(&"mixer"), sim.equipment.placed_count(&"oven"))

	func _lowest(cat: StringName) -> EquipmentInstance:
		var low: EquipmentInstance = null
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			if not sim.equipment.is_in_use(e.iid) and (low == null or e.tier() < low.tier()):
				low = e
		return low

	func _empty_low_display(below: int) -> EquipmentInstance:
		var low: EquipmentInstance = null
		for d: EquipmentInstance in sim.equipment.placed_list(&"display"):
			if d.tier() < below and not sim.equipment.is_in_use(d.iid) and (low == null or d.tier() < low.tier()):
				low = d
		return low

	func _replace(old_iid: int, def_id: StringName) -> bool:
		var r: Dictionary = sim.equipment.buy_replace(def_id, old_iid)
		if not bool(r.get("ok", false)):
			_actions.append("replace failed %s: %s" % [def_id, r.get("reason", "?")])
			return false
		if not bool(r.get("placed", false)) and not _place(int(r["iid"])):
			_actions.append("place failed %s" % def_id)
		var old: EquipmentInstance = sim.equipment.get_inst(old_iid)
		if old != null and not old.placed:
			sim.equipment.sell(old_iid)
		_drain.erase(old_iid)
		return true

	func _buy_place(def_id: StringName) -> bool:
		var r: Dictionary = sim.equipment.buy(def_id)
		if not bool(r.get("ok", false)):
			_actions.append("buy failed %s: %s" % [def_id, r.get("reason", "?")])
			return false
		if not _place(int(r["iid"])):
			_actions.append("place failed %s" % def_id)
		return true

	func _place_all_unplaced() -> void:
		for e: EquipmentInstance in sim.equipment.unplaced_list().duplicate():
			if EquipmentManager.is_fixture(e.category()):
				continue
			if sim.equipment.placed_count(e.category()) < sim.equipment.slot_limit(e.category()):
				_place(e.iid)

	## Staf: isi kapasitas bila kas di atas cadangan menutup gaji 5 hari
	## (kasir dulu, lalu koki). Wajib setelah Tier 2 supaya produksi tidak macet.
	func _hire_staff(reserve: float) -> void:
		for role: StringName in [&"cashier", &"baker"]:
			for st: StaffDefinition in DataRegistry.staff_list():
				if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
					break
				if st.role_id != role or sim.staff.is_employed(st.id):
					continue
				if sim.economy.balance - reserve < sim.staff.daily_wage() * 5.0:
					break
				if sim.staff.hire(st.id) == &"":
					_actions.append("hire %s" % role)

	## Rak lama di lokasi Tier 5 yang masih berisi roti: roti basi dibuang, lalu
	## esok koki libur dan pemain tidak mengisinya, supaya rak itu habis terjual
	## dan bisa diganti (GDD 5.1.2).
	func _plan_drain() -> void:
		_drain.clear()
		var need: bool = false
		if sim.world.location.tier == 5 and eq_tier() == 5 and not _needs_t5(&"mixer") and not _needs_t5(&"oven"):
			for d: EquipmentInstance in sim.equipment.placed_list(&"display"):
				if d.tier() < 5 and sim.equipment.is_in_use(d.iid):
					sim.display.discard(d.iid, true)
					if sim.equipment.is_in_use(d.iid):
						_drain[d.iid] = true
						need = true
		for bid: StringName in sim.staff.employed_ids(&"baker"):
			sim.staff.set_on_duty(bid, not need)
		if need:
			_actions.append("drain %d old display(s)" % _drain.size())

	func _marketing(reserve: float) -> void:
		if not sim.marketing.active.is_empty():
			return
		var best: MiscDefinitions.MarketingCampaignDefinition = null
		for c: Variant in DataRegistry.campaigns():
			var cd: MiscDefinitions.MarketingCampaignDefinition = c
			if cd.tier > sim.world.location.tier or sim.economy.balance - cd.cost_kr * (_slack() + 1.0) < reserve:
				continue
			if best == null or cd.traffic_multiplier > best.traffic_multiplier:
				best = cd
		if best != null and sim.marketing.launch(best.id) == &"":
			_actions.append("ad " + String(best.id).replace("campaign_", ""))

	## Dekorasi dibeli setelah lokasi Tier 5, seperti pada pengukuran 2026-09-29,
	## supaya hasilnya bisa dibandingkan.
	func _decorations(reserve: float) -> void:
		if sim.world.location.tier < 5:
			return
		for d: Variant in DataRegistry.decorations():
			var dd: MiscDefinitions.DecorationDefinition = d
			if dd.source != &"shop" or sim.decoration.owns(dd.id):
				continue
			if sim.economy.balance - dd.price_kr * 4.0 >= reserve and sim.decoration.buy(dd.id) == &"":
				_actions.append("decor")

	func _needs_t5(cat: StringName) -> bool:
		var n: int = 0
		for e: EquipmentInstance in sim.equipment.placed_list(cat):
			if e.tier() == 5:
				n += 1
		return n < sim.equipment.slot_limit(cat)

	func _note(m: String) -> void:
		if not milestones.has(m):
			milestones[m] = sim.time.day

	func _check_goal() -> void:
		if goal_day > 0 or sim.world.location.tier < 5:
			return
		for cat: StringName in [&"mixer", &"oven", &"display"]:
			if _needs_t5(cat):
				return
		_note("all_equipment_T5")
		for d: Variant in DataRegistry.decorations():
			var dd: MiscDefinitions.DecorationDefinition = d
			if dd.source == &"shop" and not sim.decoration.owns(dd.id):
				return
		_note("all_decor")
		goal_day = sim.time.day
