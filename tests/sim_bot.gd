class_name SimBot
extends RefCounted
## Pemain otomatis untuk test integrasi & soak (GDD 94, 107). Bot hanya memakai
## API yang sama dengan UI: tap perabot, pilih resep, pilih petak, konfirmasi
## pesanan, kemas RotiFood, beli di Pasar. Ia tidak pernah memutasi state
## gameplay secara langsung.

var sim: SimulationRoot
var preferred_recipe: StringName = &""
var batch: int = 1
var serve_customers: bool = true
var pack_orders: bool = true
var buy_ingredients: bool = true
## false = hanya menyelesaikan job yang sudah berjalan (menutup dapur).
var start_new_batches: bool = true
## true = after-hours juga merekrut staf, membeli & memasang alat, dan upgrade
## lokasi bila kas cukup (untuk soak panjang, GDD 94).
var manage: bool = false
var decisions: int = 0
## Bot berpikir tiap `think_interval` tick (respons modal tetap segera), seperti
## pemain yang mengetuk beberapa kali per detik, bukan 20 kali.
var think_interval: int = 5
var _cooldown: int = 0


func _init(s: SimulationRoot) -> void:
	sim = s


func think() -> void:
	var p: PlayerTaskManager = sim.player
	# 1. Respons "modal" yang diminta lapisan tugas pemain.
	if sim.ui_requests.recipe_book_storage >= 0:
		_choose_recipe()
		p.close_storage()
		return
	if sim.ui_requests.slot_picker_display >= 0:
		_fill_slots(sim.ui_requests.slot_picker_display)
		p.close_slot_picker()
		return
	if sim.ui_requests.customer_order != &"":
		sim.cashier.confirm_manual(sim.ui_requests.customer_order)
		sim.ui_requests.customer_order = &""
		return
	if sim.ui_requests.display_detail >= 0:
		sim.ui_requests.display_detail = -1
	_cooldown -= 1
	if _cooldown > 0:
		return
	_cooldown = think_interval
	if pack_orders:
		for o: DeliveryOrder in sim.rotifood.active_orders():
			if not o.packed and sim.rotifood.shortages(o).is_empty():
				sim.rotifood.pack(o.order_id)
	if not p.current.is_empty() or not p.commands.is_empty():
		return
	decisions += 1
	_decide()


func _decide() -> void:
	var p: PlayerTaskManager = sim.player
	var carried: ProductionJob = p.carried_job()
	if carried != null:
		if carried.stage == ProductionJob.CARRIED_TO_OVEN:
			for e: EquipmentInstance in sim.equipment.placed_list(&"oven"):
				if e.job_id < 0 and e.tier() >= carried.recipe().required_oven_tier:
					p.tap_equipment(e.iid)
					return
		elif carried.stage == ProductionJob.CARRIED_TO_DISPLAY:
			for e2: EquipmentInstance in sim.equipment.placed_list(&"display"):
				if sim.display.free_units(e2.iid) > 0:
					p.tap_equipment(e2.iid)
					return
		_serve_if_needed()
		return
	# Oven siap: selamatkan dari gosong lebih dulu.
	for j: ProductionJob in sim.production.sorted_jobs():
		if j.is_waiting_oven_pickup() and not j.protected:
			p.tap_equipment(j.oven_id)
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
	# Mulai batch baru bila ada mixer bebas, bahan, dan ruang rak.
	var r: RecipeDefinition = _recipe_to_make()
	var busy_ovens: int = 0
	for e3: EquipmentInstance in sim.equipment.placed_list(&"oven"):
		if e3.job_id >= 0:
			busy_ovens += 1
	var pending_jobs: int = sim.production.jobs.size()
	if start_new_batches and r != null and pending_jobs <= sim.equipment.placed_count(&"oven"):
		var storage: EquipmentInstance = sim.equipment.storage_instance()
		if storage != null:
			p.tap_equipment(storage.iid)
			return
	# Berjaga di kasir saat toko buka.
	if sim.time.is_open() and not sim.staff.any_cashier_working() and p.manning_lane == &"":
		p.tap_cashier(sim.queue.main_lane().id, false)


func _serve_if_needed() -> bool:
	if not serve_customers or sim.staff.any_cashier_working():
		return false
	var lane: QueueLane = sim.queue.main_lane()
	if lane.service_occupant == &"":
		return false
	var c: Customer = sim.customers.customer(lane.service_occupant)
	if c == null or not c.awaiting_tap:
		return false
	sim.player.tap_customer(c.id)
	return true


func _recipe_to_make() -> RecipeDefinition:
	var free_display: int = sim.display.total_free_units()
	var in_flight: int = 0
	for j: ProductionJob in sim.production.sorted_jobs():
		in_flight += j.quantity_output
	if preferred_recipe != &"":
		var pr: RecipeDefinition = DataRegistry.recipe(preferred_recipe)
		if sim.production.make_block_reason(pr.id, batch) == "" and pr.batch_yield * batch + in_flight <= free_display:
			return pr
	var plan: Dictionary = DataRegistry.opening_day(sim.time.day)
	if not plan.is_empty():
		var r0: RecipeDefinition = DataRegistry.recipe(StringName(str(plan["recipe_id"])))
		if sim.production.make_block_reason(r0.id, batch) == "" and r0.batch_yield * batch + in_flight <= free_display:
			return r0
		return null
	var best: RecipeDefinition = null
	var stock: Dictionary = sim.display.sellable_by_recipe()
	var best_stock: int = 1 << 30
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.production.make_block_reason(r.id, batch) != "":
			continue
		if r.batch_yield * batch + in_flight > free_display:
			continue
		var s: int = int(stock.get(r.id, 0))
		if s < best_stock:
			best = r
			best_stock = s
	return best


func _choose_recipe() -> void:
	if not start_new_batches:
		return
	var r: RecipeDefinition = _recipe_to_make()
	if r != null:
		sim.player.order_recipe(r.id, batch)


func _fill_slots(iid: int) -> void:
	var j: ProductionJob = sim.player.carried_job()
	if j == null:
		return
	var sl: Array = sim.display.slots(iid)
	# Petak resep sama lebih dulu, lalu petak kosong (GDD 85).
	for pass_i in 2:
		for i in sl.size():
			if sim.player.carried_job() == null:
				return
			var s: Dictionary = sl[i]
			var same: bool = s["recipe"] == j.recipe_id and sim.display.slot_units(iid, i) > 0
			var empty: bool = sim.display.slot_units(iid, i) == 0
			if (pass_i == 0 and same) or (pass_i == 1 and empty):
				sim.player.place_into_slot(iid, i, j.carried_units)


## Selesaikan semua job & loyang yang dibawa tanpa memulai batch baru.
## true bila dapur bersih sebelum toko tutup.
func finish_production() -> bool:
	start_new_batches = false
	while sim.is_running() and (not sim.production.jobs.is_empty() or not sim.player.actor.carried.is_empty()):
		think()
		sim.step(sim.tick_seconds)
	start_new_batches = true
	return sim.production.jobs.is_empty() and sim.player.actor.carried.is_empty()


## After-hours: beli bahan untuk resep termurah yang bisa dibuat, lalu lanjut.
func after_hours() -> void:
	sim.enter_after_hours()
	if manage:
		_manage()
	if buy_ingredients and sim.supply.market_unlocked:
		_shop()
	sim.continue_to_next_day()


## Satu hari penuh yang menutup dapur sebelum 18:00 (upgrade butuh job kosong,
## GDD 105 no.11), lalu after-hours.
func play_day() -> void:
	while sim.is_running() and sim.time.time_seconds < 17.0 * 3600.0:
		think()
		sim.step(sim.tick_seconds)
	finish_production()
	while sim.is_running():
		think()
		sim.step(sim.tick_seconds)
	after_hours()


func _manage() -> void:
	var reserve: float = sim.staff.scheduled_wages() * 3.0 + 1500.0
	var nxt: LocationDefinition = sim.next_location()
	if nxt != null and sim.economy.balance - nxt.upgrade_cost_kr > reserve * 2.0 and sim.upgrade_block_reason() == "":
		sim.upgrade_location()
	# Alat: tambah slot yang masih kosong dengan tier tertinggi yang terjangkau.
	for cat: StringName in [&"oven", &"mixer", &"display"]:
		if sim.equipment.placed_count(cat) + sim.equipment.unplaced_list(cat).size() >= sim.equipment.slot_limit(cat):
			continue
		var best: EquipmentDefinition = null
		for def: EquipmentDefinition in DataRegistry.equipment_in_category(cat):
			if def.for_sale and sim.economy.balance - def.price_kr > reserve and (best == null or def.tier > best.tier):
				best = def
		if best != null:
			var r: Dictionary = sim.equipment.buy(best.id)
			if bool(r.get("ok", false)):
				_place(int(r["iid"]))
	for e: EquipmentInstance in sim.equipment.unplaced_list():
		if sim.equipment.placed_count(e.category()) < sim.equipment.slot_limit(e.category()):
			_place(e.iid)
	# Staf: isi kapasitas bila gaji 5 hari tertutup kas.
	for role: StringName in [&"cashier", &"baker"]:
		if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
			continue
		for st: StaffDefinition in DataRegistry.staff_list():
			if st.role_id != role or sim.staff.is_employed(st.id):
				continue
			if st.tier <= sim.world.location.tier and sim.economy.balance - st.daily_wage_kr * 5.0 > reserve:
				sim.staff.hire(st.id)
				break


## Pasang lewat API yang sama dengan Decoration Mode: coba setiap sel & rotasi.
func _place(iid: int) -> bool:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	for fid: StringName in sim.world.floors_for_category(e.category()):
		var fg: FloorGrid = sim.world.grid(fid)
		for z in fg.size.y:
			for x in fg.size.x:
				for rot in 4:
					if sim.equipment.place(iid, fid, Vector2i(x, z), rot) == &"":
						return true
	return false


func _shop() -> void:
	var target: RecipeDefinition = null
	if preferred_recipe != &"":
		target = DataRegistry.recipe(preferred_recipe)
	if target == null or not sim.production.owns_equipment_for(target):
		target = DataRegistry.recipe(&"recipe_plain_loaf")
	var budget: float = sim.economy.balance - sim.staff.scheduled_wages() - 200.0
	var cap: int = sim.supply.max_additional_units()
	var per_batch_units: int = 0
	for ing: StringName in target.ingredients.keys():
		per_batch_units += int(target.ingredients[ing])
	var batches: int = mini(int(budget / target.batch_cost_kr), cap / maxi(1, per_batch_units))
	batches = mini(batches, 12)
	if batches <= 0:
		return
	var items: Dictionary = {}
	for ing2: StringName in target.ingredients.keys():
		items[ing2] = int(target.ingredients[ing2]) * batches
	sim.supply.purchase(items)
