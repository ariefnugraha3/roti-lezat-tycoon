class_name CustomerManager
extends SimManager
## CustomerManager — pemilik siklus hidup logis pelanggan fisik (GDD 20, 58,
## 69, 83, 84, 98). Pelanggan baru hanya "masuk toko" setelah memperoleh token
## kapasitas antrean; sebelum itu ia hanya data pending di DemandManager.
## Pengunjung lihat-lihat (GDD 20.12) juga tinggal di sini, dengan id "w…" yang
## selalu diurutkan sesudah pembeli "c…", dan tidak pernah menyentuh antrean.

const BROWSE_SECONDS: float = 1.0
const CELEBRATE_SECONDS: float = 0.8

var customers: Dictionary = {}
var next_num: int = 1
var next_window_num: int = 1
var entered_today: int = 0
var served_today: int = 0
var abandoned_today: int = 0
var no_stock_today: int = 0
var window_shoppers_today: int = 0
var _smart_slow_armed: bool = true


func new_game() -> void:
	customers.clear()
	next_num = 1
	next_window_num = 1
	reset_day()


func reset_day() -> void:
	entered_today = 0
	served_today = 0
	abandoned_today = 0
	no_stock_today = 0
	window_shoppers_today = 0


func customer(id: StringName) -> Customer:
	return customers.get(id)


func sorted() -> Array[Customer]:
	var keys: Array = Ids.sort(customers.keys())
	var out: Array[Customer] = []
	for k: Variant in keys:
		out.append(customers[k])
	return out


func archetype_of(actor_id: StringName) -> StringName:
	var c: Customer = customers.get(actor_id)
	if c != null:
		return c.archetype
	return &"driver_rotifood"


func active_count() -> int:
	return customers.size()


## Skala delta rating per pelanggan (GDD 25.2).
func tier_scale() -> float:
	return DataRegistry.balf("rating.tier_scale_numerator") / sim.world.location.base_physical_rate


# ===========================================================================
# ADMISSION (GDD 20.5, 83.2)
# ===========================================================================

## Coba memasukkan satu kedatangan pending. true = aktor muncul di pintu.
func try_admit(arrival: Dictionary) -> bool:
	if not sim.time.is_open():
		return false
	if customers.size() + sim.rotifood.driver_count() >= DataRegistry.bali("queue.max_visible_customer_actors"):
		return false
	var archetype: StringName = StringName(str(arrival["archetype"]))
	var def: CustomerArchetypeDefinition = DataRegistry.archetype(archetype)
	if def == null:
		return true
	var door: Vector2i = sim.world.entrance_cell()
	var lane: QueueLane = sim.queue.choose_physical_lane(door, def.movement_speed_mps)
	if lane == null:
		return false
	var c := Customer.new()
	c.id = StringName("c%d" % next_num)
	next_num += 1
	if not sim.queue.reserve(lane, c.id):
		return false
	c.archetype = archetype
	c.scripted = bool(arrival.get("scripted", false))
	c.requested_recipe = StringName(str(arrival.get("recipe", "")))
	c.requested_qty = int(arrival.get("quantity", 0))
	c.is_critic = archetype == &"customer_critic"
	c.patience_max = def.base_patience_seconds
	if arrival.get("patience_override") != null:
		c.patience_max = float(arrival["patience_override"])
	c.patience = c.patience_max
	c.lane_id = lane.id
	c.spawned_at = sim.time.sim_seconds
	c.actor = SimActor.new()
	c.actor.id = c.id
	c.actor.kind = &"customer"
	c.actor.nav_class = FloorGrid.NAV_PUBLIC
	c.actor.speed_mps = def.movement_speed_mps
	c.actor.visual_key = archetype
	c.actor.visual_seed = sim.rng.stream(&"cosmetic_rng").randi()
	c.actor.place_at(sim.world.store_floor(), door)
	c.state = Customer.ENTERING
	customers[c.id] = c
	entered_today += 1
	EventBus.customer_spawned.emit(0)
	EventBus.sfx.emit(&"door_bell_enter", c.actor.floor_id)
	_choose_target(c)
	sim.tutorial.on_customer_entered(c)
	return true


# ===========================================================================
# PENGUNJUNG LIHAT-LIHAT (GDD 20.12)
# ===========================================================================

## Pengunjung lihat-lihat yang sedang di dalam toko.
func window_shopper_count() -> int:
	var n: int = 0
	for c: Variant in customers.values():
		if (c as Customer).window_shopper:
			n += 1
	return n


## Aktor yang bergerak di lokasi: pemain, staf, pelanggan, driver, kurir (GDD 37.2).
func active_actor_count() -> int:
	return 1 + sim.staff.actors.size() + customers.size() + sim.rotifood.driver_count() + sim.supply.couriers.size()


## Ia tidak memakai token antrean. Ia masuk hanya bila jumlahnya di bawah batas
## tier, aktor aktif di bawah anggaran lokasi (GDD 37.2), dan ada tempat berdiri
## bebas. Bila tidak, kedatangan itu dilewati: ia bukan permintaan, jadi tidak
## pernah pending dan tidak dihitung sebagai permintaan yang terlewat.
func try_admit_window_shopper(archetype: StringName) -> bool:
	if not sim.time.is_open():
		return false
	var def: CustomerArchetypeDefinition = DataRegistry.archetype(archetype)
	if def == null:
		return false
	var caps: Array = DataRegistry.bal("window_shopper.max_inside_by_tier")
	if window_shopper_count() >= int(caps[clampi(sim.world.location.tier - 1, 0, caps.size() - 1)]):
		return false
	if active_actor_count() >= sim.world.location.active_actor_budget:
		return false
	if customers.size() + sim.rotifood.driver_count() >= DataRegistry.bali("queue.max_visible_customer_actors"):
		return false
	var door: Vector2i = sim.world.entrance_cell()
	var spot: Dictionary = _pick_look_spot(-1)
	if spot.is_empty():
		return false
	var r: RandomNumberGenerator = sim.rng.stream(&"cosmetic_rng")
	var c := Customer.new()
	c.id = StringName("w%d" % next_window_num)
	next_window_num += 1
	c.archetype = archetype
	c.window_shopper = true
	c.looks_left = 2 if r.randf() < DataRegistry.balf("window_shopper.second_look_chance") else 1
	c.spawned_at = sim.time.sim_seconds
	c.actor = _window_shopper_actor(c)
	c.actor.visual_seed = r.randi()
	c.actor.place_at(sim.world.store_floor(), door)
	customers[c.id] = c
	window_shoppers_today += 1
	EventBus.sfx.emit(&"door_bell_enter", c.actor.floor_id)
	_go_look(c, spot)
	sim.tutorial.on_window_shopper_entered()
	return true


func _window_shopper_actor(c: Customer) -> SimActor:
	var a := SimActor.new()
	a.id = c.id
	a.kind = &"customer"
	a.nav_class = FloorGrid.NAV_PUBLIC
	a.speed_mps = c.def().movement_speed_mps * DataRegistry.balf("window_shopper.stroll_speed_factor")
	a.visual_key = c.archetype
	return a


## Tempat berdiri melihat-lihat: sel publik di depan atau di samping rak, tidak
## pernah di belakangnya. Titik eksklusif GDD 83.3, pintu, sel yang sedang dituju
## pembeli, dan sel pengunjung lain tidak pernah dipilih. Tatapan kedua
## mendahulukan rak lain; tanpa tempat di dekat rak mana pun ia melihat-lihat
## ruangan. {cell, display} atau {} bila tidak ada tempat.
func _pick_look_spot(avoid_display: int) -> Dictionary:
	var floor_id: StringName = sim.world.store_floor()
	var fg: FloorGrid = sim.world.grid(floor_id)
	var wait: Dictionary = _buyer_wait_cells(floor_id)
	var busy: Dictionary = _buyer_goal_cells(floor_id)
	var r: RandomNumberGenerator = sim.rng.stream(&"cosmetic_rng")
	var options: Array = []
	var others: Array = []
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		if e.floor_id != floor_id:
			continue
		var cells: Array[Vector2i] = _look_cells(fg, floor_id, e, wait, busy)
		if cells.is_empty():
			continue
		options.append([e.iid, cells])
		if e.iid != avoid_display:
			others.append([e.iid, cells])
	if not others.is_empty():
		options = others
	if options.is_empty():
		var room: Array[Vector2i] = _look_cells(fg, floor_id, null, wait, busy)
		if room.is_empty():
			return {}
		return {"cell": room[r.randi_range(0, room.size() - 1)], "display": -1}
	var pick: Array = options[r.randi_range(0, options.size() - 1)]
	var list: Array[Vector2i] = pick[1]
	return {"cell": list[r.randi_range(0, list.size() - 1)], "display": int(pick[0])}


## Sel sah dengan skor terkecil di sekitar rak `e` (null = seluruh zona toko).
## Skor: depan rak 0, samping 2 (belakang tidak pernah); cincin kedua +1; lorong
## terlindung +1; sel tunggu pembeli +2. Urutan sel tetap, jadi undian kosmetik
## atas hasilnya deterministik.
func _look_cells(fg: FloorGrid, floor_id: StringName, e: EquipmentInstance, wait: Dictionary, busy: Dictionary) -> Array[Vector2i]:
	var footprint: Array[Vector2i] = []
	var center := Vector2.ZERO
	var ahead_dir := Vector2.ZERO
	if e != null:
		footprint = e.footprint_cells()
		center = _cells_center(footprint)
		ahead_dir = (_cells_center(e.front_cells()) - center).normalized()
	var best: Array[Vector2i] = []
	var best_score: int = 1 << 30
	for z in fg.size.y:
		for x in fg.size.x:
			var c := Vector2i(x, z)
			var score: int = 0
			if e != null:
				var ring: int = 1 << 30
				for f: Vector2i in footprint:
					ring = mini(ring, maxi(absi(c.x - f.x), absi(c.y - f.y)))
				if ring < 1 or ring > 2:
					continue
				var ahead: float = (GridMath.cell_center(c) - center).dot(ahead_dir)
				if ahead < -0.01:
					continue
				score = (0 if ahead > 0.01 else 2) + ring - 1
			if busy.has(c) or not _look_cell_ok(fg, floor_id, c):
				continue
			if fg.flag(c) == FloorGrid.Flag.WALKABLE_NO_BUILD:
				score += 1
			if wait.has(c):
				score += 2
			if score < best_score:
				best_score = score
				best.clear()
			if score == best_score:
				best.append(c)
	return best


static func _cells_center(cells: Array[Vector2i]) -> Vector2:
	var sum := Vector2.ZERO
	for c: Vector2i in cells:
		sum += GridMath.cell_center(c)
	return sum / float(maxi(cells.size(), 1))


func _look_cell_ok(fg: FloorGrid, floor_id: StringName, c: Vector2i) -> bool:
	if not fg.is_public_walkable(c) or fg.is_door(c) or fg.access_at.has(c):
		return false
	var f: int = fg.flag(c)
	if f == FloorGrid.Flag.QUEUE_RESERVED or f == FloorGrid.Flag.INTERACTION_RESERVED:
		return false
	return sim.world.point_holder(floor_id, c) == &""


## Sel tujuan terakhir setiap pembeli di lantai ini: tempat ia sedang berjalan
## atau berdiri. Pengunjung lihat-lihat tidak pernah memilihnya.
func _buyer_goal_cells(floor_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	for v: Variant in customers.values():
		var b: Customer = v
		if not b.window_shopper and b.actor.goal_floor == floor_id and b.actor.goal_cell.x >= 0:
			out[b.actor.goal_cell] = true
	return out


## Sel tempat pembeli menunggu saat titik browsing rak sedang dipakai (GDD 83.3).
func _buyer_wait_cells(floor_id: StringName) -> Dictionary:
	var out: Dictionary = {}
	for e: EquipmentInstance in sim.equipment.placed_list(&"display"):
		var acc: Dictionary = sim.world.access_of(e.iid)
		if acc.is_empty() or StringName(str(acc["floor"])) != floor_id:
			continue
		var w: Vector2i = _neighbor_wait_cell(floor_id, acc["cell"])
		if w.x >= 0:
			out[w] = true
	return out


func _go_look(c: Customer, spot: Dictionary) -> void:
	var floor_id: StringName = sim.world.store_floor()
	c.look_cell = spot["cell"]
	c.look_display = int(spot["display"])
	sim.world.reserve_point(floor_id, c.look_cell, c.id)
	c.state = Customer.ENTERING
	if not c.actor.go_to(sim.world, floor_id, c.look_cell):
		_window_leave(c)


## Tempat berdiri masih sah (Decoration Mode bisa menaruh perabot di atasnya).
func _look_spot_valid(c: Customer) -> bool:
	var fg: FloorGrid = sim.world.grid(sim.world.store_floor())
	return fg != null and c.look_cell.x >= 0 and fg.is_public_walkable(c.look_cell) and not fg.access_at.has(c.look_cell)


## Pembeli yang menuju atau berdiri di sel itu (mis. menunggu giliran di rak).
func _buyer_heading_to(cell: Vector2i) -> bool:
	return _buyer_goal_cells(sim.world.store_floor()).has(cell)


## Pembeli selalu didahulukan: bila ada pembeli yang perlu sel tempat ia berdiri,
## pengunjung lihat-lihat minggir ke tempat lain atau pulang. Pembelinya sendiri
## tidak pernah menunggu karena itu.
func _step_window_shopper(c: Customer, dt: float) -> void:
	match c.state:
		Customer.ENTERING:
			if not _look_spot_valid(c) or _buyer_heading_to(c.look_cell):
				_next_look_or_leave(c, false)
			elif c.actor.has_route():
				pass
			elif c.actor.cell() != c.look_cell:
				if not c.actor.go_to(sim.world, sim.world.store_floor(), c.look_cell):
					_window_leave(c)
			else:
				var span: Array = DataRegistry.bal("window_shopper.look_seconds")
				c.state = Customer.BROWSING
				c.browse_left = sim.rng.stream(&"cosmetic_rng").randf_range(float(span[0]), float(span[1]))
				_face_look_target(c)
		Customer.BROWSING:
			c.browse_left -= dt
			if not _look_spot_valid(c):
				_window_leave(c)
			elif c.browse_left <= 0.0 or _buyer_heading_to(c.look_cell):
				_next_look_or_leave(c)
		_:
			if not c.actor.has_route():
				_despawn(c)


## Tempat lama tetap terkunci selama memilih tempat baru, jadi ia tidak memilih
## sel yang sama lagi. `looked` false = ia minggir sebelum sempat melihat.
func _next_look_or_leave(c: Customer, looked: bool = true) -> void:
	if looked:
		c.looks_left -= 1
	var spot: Dictionary = _pick_look_spot(c.look_display) if c.looks_left > 0 else {}
	sim.world.release_all_for(c.id)
	if spot.is_empty():
		_window_leave(c)
	else:
		_go_look(c, spot)


## Pulang tanpa membeli: tanpa penalti rating dan tanpa statistik "gagal beli".
func _window_leave(c: Customer) -> void:
	sim.world.release_all_for(c.id)
	c.look_cell = Vector2i(-1, -1)
	c.state = Customer.LEAVING
	_walk_out(c)


## Menghadap ke tengah rak yang dilihat.
func _face_look_target(c: Customer) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(c.look_display) if c.look_display >= 0 else null
	if e == null or not e.placed:
		return
	var to: Vector2 = _cells_center(e.footprint_cells()) - c.actor.pos
	if to.length_squared() > 0.0001:
		c.actor.facing = to.normalized()


# ===========================================================================
# PEMILIHAN PRODUK (GDD 20.6, 69, 84.1-84.3)
# ===========================================================================

func _filter_for(c: Customer) -> Callable:
	var def: CustomerArchetypeDefinition = c.def()
	return func(st: BreadStack) -> bool:
		if st.bake_quality < def.quality_requirement:
			return false
		if not def.accepts_freshness(st.freshness_state):
			return false
		var r: RecipeDefinition = DataRegistry.recipe(st.recipe_id)
		if r.recipe_tier() < def.min_recipe_tier:
			return false
		if def.max_unit_price_kr > 0.0 and sim.pricing.price_of(st.recipe_id) > def.max_unit_price_kr:
			return false
		return true


## Pilih resep & rak target. Bila tidak ada roti yang boleh ia beli, pelanggan
## langsung pulang tanpa antre (GDD 69.4, 84.2.12).
func _choose_target(c: Customer) -> void:
	var def: CustomerArchetypeDefinition = c.def()
	var filter: Callable = _filter_for(c)
	var avail: Dictionary = {}
	for m: Dictionary in sim.display.matching_stacks(filter):
		var st: BreadStack = m["stack"]
		avail[st.recipe_id] = int(avail.get(st.recipe_id, 0)) + st.quantity
	if avail.is_empty():
		_leave_no_stock(c)
		return
	var recipe_id: StringName = &""
	if c.scripted and avail.has(c.requested_recipe) and not c.substitution_used:
		recipe_id = c.requested_recipe
	elif c.substitution_used:
		# Substitusi memakai skor alternatif deterministik (GDD 84.3).
		var original: StringName = c.target_recipe if c.target_recipe != &"" else c.requested_recipe
		recipe_id = best_alternative(c, avail, original)
	else:
		recipe_id = _pick_recipe(c, avail, def)
	if recipe_id == &"":
		_leave_no_stock(c)
		return
	var qty: int = _pick_quantity(c, def, recipe_id)
	var display_iid: int = _nearest_display_with(c, recipe_id, filter)
	if display_iid < 0:
		_leave_no_stock(c)
		return
	var in_display: int = sim.display.count_matching(recipe_id, filter, display_iid)
	if def.quantity_partial_min > 0 and in_display < qty:
		if in_display < def.quantity_partial_min and not c.substitution_used:
			c.substitution_used = true
			avail.erase(recipe_id)
			var alt: StringName = best_alternative(c, avail, recipe_id)
			if alt == &"":
				_leave_no_stock(c)
				return
			recipe_id = alt
			display_iid = _nearest_display_with(c, recipe_id, filter)
			in_display = sim.display.count_matching(recipe_id, filter, display_iid)
	qty = clampi(mini(qty, in_display), 1, maxi(1, in_display))
	c.target_recipe = recipe_id
	c.target_display = display_iid
	c.target_qty = qty
	var price_ratio: float = sim.pricing.price_of(recipe_id) / DataRegistry.recipe(recipe_id).base_sell_price_kr
	c.price_label = DataRegistry.price_reaction_label(DataRegistry.effective_price_demand(price_ratio, def.price_sensitivity))
	_walk_to_display(c)


## Bobot pilihan resep: preferensi tag × penerimaan harga × pengali kampanye;
## bila semua preferensi nol, fallback ke atraksi umum (GDD 69, 84.3).
func _pick_recipe(c: Customer, avail: Dictionary, def: CustomerArchetypeDefinition) -> StringName:
	var weights: Dictionary = {}
	var fallback: Dictionary = {}
	for rid: Variant in avail.keys():
		var r: RecipeDefinition = DataRegistry.recipe(rid)
		var ratio: float = sim.pricing.price_of(rid) / r.base_sell_price_kr
		var acc: float = clampf(DataRegistry.effective_price_demand(ratio, def.price_sensitivity) / DataRegistry.balf("substitution.price_acceptance_divisor"), 0.0, 1.0)
		var pref: float = def.preference_for(r) * sim.marketing.recipe_preference_multiplier(rid)
		if pref > 0.0:
			weights[String(rid)] = pref * maxf(acc, 0.01)
		fallback[String(rid)] = maxf(acc, 0.01) * _best_quality(rid)
	var pick: Variant = RNGManager.weighted_pick(sim.rng.stream(&"customer_choice_rng"), weights if not weights.is_empty() else fallback)
	return StringName(str(pick)) if pick != null else &""


## Skor substitusi (GDD 84.3): kemiripan preferensi 0.45 + penerimaan harga
## 0.25 + freshness 0.20 + jarak 0.10, semua ternormalisasi 0..1; skor
## tertinggi menang, seri diputus recipe_id terkecil. Kemiripan = irisan/gabungan
## tag resep terhadap resep semula; tanpa resep semula dipakai preferensi tag
## arketipe.
func best_alternative(c: Customer, avail: Dictionary, original: StringName) -> StringName:
	var def: CustomerArchetypeDefinition = c.def()
	var filter: Callable = _filter_for(c)
	var orig: RecipeDefinition = DataRegistry.recipe(original) if original != &"" else null
	var dist: Dictionary = {}
	var dmin: int = 1 << 30
	for rid: Variant in avail.keys():
		var iid: int = _nearest_display_with(c, rid, filter)
		if iid < 0:
			continue
		var d: int = GridMath.manhattan(c.actor.cell(), sim.world.access_of(iid)["cell"])
		dist[rid] = d
		dmin = mini(dmin, d)
	var keys: Array = Ids.sort(dist.keys())
	var sub: Dictionary = DataRegistry.balance_section("substitution")
	var best: StringName = &""
	var best_score: float = -1.0
	for rid2: Variant in keys:
		var r: RecipeDefinition = DataRegistry.recipe(rid2)
		var similarity: float = tag_similarity(orig, r) if orig != null else clampf(def.preference_for(r), 0.0, 1.0)
		var ratio: float = sim.pricing.price_of(rid2) / r.base_sell_price_kr
		var acc: float = clampf(DataRegistry.effective_price_demand(ratio, def.price_sensitivity) / float(sub["price_acceptance_divisor"]), 0.0, 1.0)
		var fresh: float = _best_freshness(rid2, filter) / 100.0
		var near_score: float = float(dmin + 1) / float(int(dist[rid2]) + 1)
		var score: float = similarity * float(sub["weight_preference"]) + acc * float(sub["weight_price"]) 			+ fresh * float(sub["weight_freshness"]) + near_score * float(sub["weight_distance"])
		if score > best_score + 0.000001:
			best_score = score
			best = StringName(str(rid2))
	return best


static func tag_similarity(a: RecipeDefinition, b: RecipeDefinition) -> float:
	if a == null or b == null:
		return 0.0
	if a.id == b.id:
		return 1.0
	var union: Dictionary = {}
	var inter: int = 0
	for t: StringName in a.customer_tags:
		union[t] = true
	for t2: StringName in b.customer_tags:
		if union.has(t2):
			inter += 1
		union[t2] = true
	return float(inter) / float(maxi(1, union.size()))


func _best_freshness(recipe_id: StringName, filter: Callable) -> float:
	var best: float = 0.0
	for m: Dictionary in sim.display.matching_stacks(filter):
		var st: BreadStack = m["stack"]
		if st.recipe_id == recipe_id:
			best = maxf(best, st.freshness_score())
	return best


func _best_quality(recipe_id: StringName) -> float:
	var best: float = 0.0
	for m: Dictionary in sim.display.matching_stacks(Callable()):
		var st: BreadStack = m["stack"]
		if st.recipe_id == recipe_id:
			best = maxf(best, st.bake_quality * float(DataRegistry.bal("freshness.attractiveness")[String(st.freshness_state)]))
	return maxf(best, 0.05)


## Jumlah beli (GDD 84.1): 50% preferred, 20% ±1, sisa berbagi 10%; bulk
## memakai distribusi segitiga berpusat 8.
func _pick_quantity(c: Customer, def: CustomerArchetypeDefinition, recipe_id: StringName) -> int:
	if c.scripted:
		return maxi(1, c.requested_qty)
	var r: RandomNumberGenerator = sim.rng.stream(&"customer_choice_rng")
	if def.quantity_mode == &"triangular":
		var a: float = float(def.quantity_min)
		var b: float = float(def.quantity_max)
		var m: float = float(def.quantity_preferred)
		var u: float = r.randf()
		var fc: float = (m - a) / (b - a)
		var x: float = a + sqrt(u * (b - a) * (m - a)) if u < fc else b - sqrt((1.0 - u) * (b - a) * (b - m))
		return clampi(int(round(x)), def.quantity_min, def.quantity_max)
	var qw: Dictionary = DataRegistry.quantity_weights()
	var weights: Dictionary = {}
	var rest: Array[int] = []
	for q in range(def.quantity_min, def.quantity_max + 1):
		if q == def.quantity_preferred:
			weights[q] = float(qw["preferred"])
		elif absi(q - def.quantity_preferred) == 1:
			weights[q] = float(qw["adjacent"])
		else:
			rest.append(q)
	for q2: int in rest:
		weights[q2] = float(qw["remaining_total"]) / float(rest.size())
	var pick: int = int(RNGManager.weighted_pick(r, weights))
	# Anak sekolah jarang membeli 2 bila harga di atas referensi (GDD 84.1).
	if c.archetype == &"customer_school_child" and sim.pricing.price_of(recipe_id) > DataRegistry.recipe(recipe_id).base_sell_price_kr:
		pick = mini(pick, 1)
	return pick


func _nearest_display_with(c: Customer, recipe_id: StringName, filter: Callable) -> int:
	var best: int = -1
	var best_d: int = 1 << 30
	for iid: Variant in sim.display.display_ids():
		if sim.display.count_matching(recipe_id, filter, int(iid)) <= 0:
			continue
		var acc: Dictionary = sim.world.access_of(int(iid))
		if acc.is_empty() or StringName(str(acc["floor"])) != c.actor.floor_id:
			continue
		var d: int = GridMath.manhattan(c.actor.cell(), acc["cell"])
		if d < best_d:
			best_d = d
			best = int(iid)
	return best


func _walk_to_display(c: Customer) -> void:
	var acc: Dictionary = sim.world.access_of(c.target_display)
	if acc.is_empty():
		_leave_no_stock(c)
		return
	c.state = Customer.ENTERING
	if not c.actor.go_to(sim.world, acc["floor"], acc["cell"]):
		_leave_no_stock(c)


func _leave_no_stock(c: Customer) -> void:
	# Pelanggan sudah masuk tetapi tidak menemukan roti yang boleh ia beli (GDD 25.2).
	sim.reputation.physical_event(&"stockout_failure", tier_scale())
	sim.statistics.add(&"total_customers_left_no_purchase", 1)
	no_stock_today += 1
	if c.is_critic:
		c.outcome = &"vip_failure"
		sim.reputation.queue_vip(&"vip_failure")
	sim.world.release_all_for(c.id)
	sim.queue.release(c.id)
	c.state = Customer.LEAVE_NO_STOCK
	_walk_out(c)


func _walk_out(c: Customer) -> void:
	if not c.actor.go_to(sim.world, sim.world.store_floor(), sim.world.entrance_cell()):
		c.actor.place_at(sim.world.store_floor(), sim.world.entrance_cell())


# ===========================================================================
# TICK (P4)
# ===========================================================================

func step(dt: float) -> void:
	var lowest: float = 1.0
	for c: Customer in sorted():
		var arrived: bool = c.actor.step(dt, sim.world)
		if c.window_shopper:
			_step_window_shopper(c, dt)
			continue
		match c.state:
			Customer.ENTERING:
				_step_entering(c, arrived)
			Customer.BROWSING:
				c.browse_left -= dt
				if c.browse_left <= 0.0:
					_select(c)
			Customer.CARRYING_TO_QUEUE:
				_step_to_queue(c, arrived)
			Customer.QUEUING:
				_step_queuing(c, dt)
			Customer.FRONT_OF_QUEUE, Customer.BEING_SERVED:
				_drain(c, dt)
			Customer.CELEBRATING:
				c.celebrate_left -= dt
				if c.celebrate_left <= 0.0:
					c.state = Customer.LEAVING
					_walk_out(c)
			Customer.LEAVING, Customer.LEAVE_NO_STOCK, Customer.ABANDONING:
				if not c.actor.has_route():
					_despawn(c)
		if c.drains_patience():
			lowest = minf(lowest, c.patience_ratio())
	# Smart Speed Safety: sekali per klaster peristiwa (GDD 71.1).
	if lowest < DataRegistry.balf("smart_speed.patience_ratio"):
		if _smart_slow_armed:
			_smart_slow_armed = false
			sim.time.smart_slowdown("tut_patience")
	else:
		_smart_slow_armed = true


func _step_entering(c: Customer, _arrived: bool) -> void:
	if c.actor.has_route():
		return
	var acc: Dictionary = sim.world.access_of(c.target_display)
	if acc.is_empty():
		_choose_target(c)
		return
	if c.actor.cell() != acc["cell"]:
		# Titik browsing sedang dipakai: tunggu di sel sebelahnya (GDD 83.3).
		if sim.world.point_holder(acc["floor"], acc["cell"]) == &"":
			c.actor.go_to(sim.world, acc["floor"], acc["cell"])
		return
	if not sim.world.reserve_point(acc["floor"], acc["cell"], c.id):
		var wait: Vector2i = _neighbor_wait_cell(acc["floor"], acc["cell"])
		if wait.x >= 0:
			c.actor.go_to(sim.world, acc["floor"], wait)
		return
	c.state = Customer.BROWSING
	c.browse_left = BROWSE_SECONDS


func _neighbor_wait_cell(floor_id: StringName, cell: Vector2i) -> Vector2i:
	var fg: FloorGrid = sim.world.grid(floor_id)
	for d: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = cell + d
		if fg.is_public_walkable(n) and fg.flag(n) != FloorGrid.Flag.QUEUE_RESERVED and fg.flag(n) != FloorGrid.Flag.INTERACTION_RESERVED:
			return n
	return Vector2i(-1, -1)


## Tiba di rak: validasi ulang stok secara atomik lalu ambil (GDD 84.2 langkah 9-11).
func _select(c: Customer) -> void:
	c.state = Customer.SELECTING
	var def: CustomerArchetypeDefinition = c.def()
	var filter: Callable = _filter_for(c)
	var price: float = sim.pricing.price_of(c.target_recipe)
	var partial: bool = true
	var lots: Array[Dictionary] = sim.display.take(c.target_recipe, c.target_qty, filter, c.target_display, price, partial)
	var got: int = 0
	for l: Dictionary in lots:
		got += (l["stack"] as BreadStack).quantity
	var min_ok: int = def.quantity_partial_min if def.quantity_partial_min > 0 else 1
	min_ok = mini(min_ok, c.target_qty)
	if got < min_ok:
		sim.display.return_lots(lots)
		var acc: Dictionary = sim.world.access_of(c.target_display)
		if not acc.is_empty():
			sim.world.release_point(acc["floor"], acc["cell"], c.id)
		if not c.substitution_used:
			# Substitusi sekali terhadap seluruh stok terbaru (GDD 84.2 langkah 11).
			c.substitution_used = true
			_choose_target(c)
			return
		_leave_no_stock(c)
		return
	c.held = lots
	EventBus.sfx.emit(&"customer_pick_bread", c.actor.floor_id)
	var acc2: Dictionary = sim.world.access_of(c.target_display)
	if not acc2.is_empty():
		sim.world.release_point(acc2["floor"], acc2["cell"], c.id)
	c.state = Customer.CARRYING_TO_QUEUE
	_go_to_tail(c)


func _go_to_tail(c: Customer) -> void:
	var lane: QueueLane = sim.queue.lane(c.lane_id)
	var index: int = lane.line.size()
	c.actor.go_to(sim.world, lane.floor_id, sim.queue.slot_cell(lane, index))


func _step_to_queue(c: Customer, _arrived: bool) -> void:
	var lane: QueueLane = sim.queue.lane(c.lane_id)
	var tail: Vector2i = sim.queue.slot_cell(lane, lane.line.size())
	if c.actor.has_route():
		# Ekor antrean bergeser selagi berjalan: arahkan ulang.
		if c.actor.goal_cell != tail:
			c.actor.go_to(sim.world, lane.floor_id, tail)
		return
	if c.actor.cell() != tail:
		c.actor.go_to(sim.world, lane.floor_id, tail)
		return
	var index: int = sim.queue.join_line(lane, c.id)
	c.last_slot = index
	c.stall_time = 0.0
	c.state = Customer.QUEUING
	sim.tutorial.on_event(&"customer_queued")


func _step_queuing(c: Customer, dt: float) -> void:
	var lane: QueueLane = sim.queue.lane(c.lane_id)
	var index: int = lane.slot_index_of(c.id)
	if index < 0:
		return
	if index != c.last_slot:
		c.last_slot = index
		c.stall_time = 0.0
		c.actor.go_to(sim.world, lane.floor_id, sim.queue.slot_cell(lane, index))
	if index == 0 and lane.service_occupant == &"" and not c.actor.has_route():
		if sim.queue.advance_to_service(lane, c.id):
			c.stall_time = 0.0
			c.state = Customer.FRONT_OF_QUEUE
			c.awaiting_tap = true
			c.actor.go_to(sim.world, lane.floor_id, lane.service_point)
			return
	_drain(c, dt)


## Drain patience (GDD 58): dasar 1.0/detik, modifier multiplikatif, clamp 0.5..1.6.
func _drain(c: Customer, dt: float) -> void:
	var lane: QueueLane = sim.queue.lane(c.lane_id)
	# Transaksi yang sedang berjalan tidak mengurangi patience; yang membeku ya (GDD 20.8).
	if c.state == Customer.BEING_SERVED and sim.cashier.is_progressing(c.id):
		return
	c.queue_wait += dt
	c.stall_time += dt
	var m: float = DataRegistry.balf("patience.drain_base")
	var cashier: StaffDefinition = sim.staff.cashier_def_for_lane(c.lane_id)
	if cashier != null:
		m *= cashier.special_value("queue_patience_drain_multiplier", 1.0)
	if lane != null and lane.occupancy_ratio() >= DataRegistry.balf("patience.near_full_occupancy_ratio"):
		m *= DataRegistry.balf("patience.near_full_multiplier")
	if c.stall_time > DataRegistry.balf("patience.stall_seconds"):
		m *= DataRegistry.balf("patience.stall_multiplier")
	m = clampf(m, DataRegistry.balf("patience.drain_clamp_min"), DataRegistry.balf("patience.drain_clamp_max"))
	c.patience = maxf(0.0, c.patience - m * dt)
	if c.patience <= 0.0:
		abandon(c)


## Patience habis: roti kembali ke rak persis seperti semula, penalti sekali (GDD 20.9).
func abandon(c: Customer) -> void:
	if c.state == Customer.ABANDONING:
		return
	sim.cashier.cancel_for(c.id)
	sim.display.return_lots(c.held)
	c.held.clear()
	sim.queue.release(c.id)
	sim.world.release_all_for(c.id)
	sim.reputation.physical_event(&"customer_abandoned", tier_scale())
	sim.statistics.add(&"total_customers_lost_patience", 1)
	abandoned_today += 1
	if c.is_critic:
		c.outcome = &"vip_failure"
		sim.reputation.queue_vip(&"vip_failure")
	c.state = Customer.ABANDONING
	EventBus.customer_abandoned.emit(0)
	EventBus.sfx.emit(&"customer_leave_angry", c.actor.floor_id)
	_walk_out(c)


## Dipanggil CashierManager setelah commit penjualan (GDD 103.1).
func on_paid(c: Customer) -> void:
	served_today += 1
	c.held.clear()
	c.awaiting_tap = false
	sim.queue.release(c.id)
	c.state = Customer.CELEBRATING
	c.celebrate_left = CELEBRATE_SECONDS
	EventBus.sfx.emit(&"customer_happy", c.actor.floor_id)


func _despawn(c: Customer) -> void:
	c.state = Customer.DESPAWNED
	sim.world.release_all_for(c.id)
	sim.queue.release(c.id)
	customers.erase(c.id)
	EventBus.sfx.emit(&"door_bell_exit", c.actor.floor_id)


## Pukul 18:00 (GDD 104): semua yang belum commit mengembalikan roti tanpa
## penalti lalu pergi. Aktor langsung dikeluarkan di balik layar Daily Summary.
func shutdown() -> void:
	for c: Customer in sorted():
		sim.cashier.cancel_for(c.id)
		if not c.held.is_empty():
			sim.display.return_lots(c.held)
			c.held.clear()
		if c.is_critic and c.outcome == &"":
			c.outcome = &"neutral"
		sim.world.release_all_for(c.id)
		sim.queue.release(c.id)
	customers.clear()


# ===========================================================================
# SAVE (GDD 77.2: snapshot logis, aktor direkonstruksi ke slot kanonik)
# ===========================================================================

func capture() -> Dictionary:
	var list: Array = []
	for c: Customer in sorted():
		list.append(c.to_dict())
	return {"next_num": next_num, "next_window_num": next_window_num, "customers": list, "entered_today": entered_today,
		"served_today": served_today, "abandoned_today": abandoned_today, "no_stock_today": no_stock_today,
		"window_shoppers_today": window_shoppers_today}


func restore(d: Dictionary) -> void:
	customers.clear()
	next_num = int(d.get("next_num", 1))
	next_window_num = int(d.get("next_window_num", 1))
	entered_today = int(d.get("entered_today", 0))
	served_today = int(d.get("served_today", 0))
	abandoned_today = int(d.get("abandoned_today", 0))
	no_stock_today = int(d.get("no_stock_today", 0))
	window_shoppers_today = int(d.get("window_shoppers_today", 0))
	for item: Variant in d.get("customers", []):
		var cd: Dictionary = item
		var c := Customer.new()
		c.id = StringName(str(cd["id"]))
		c.archetype = StringName(str(cd["archetype"]))
		if c.def() == null:
			continue
		c.state = StringName(str(cd.get("state", Customer.ENTERING)))
		c.scripted = bool(cd.get("scripted", false))
		c.requested_recipe = StringName(str(cd.get("requested_recipe", "")))
		c.requested_qty = int(cd.get("requested_qty", 0))
		c.patience_max = float(cd.get("patience_max", 30.0))
		c.patience = float(cd.get("patience", c.patience_max))
		c.lane_id = StringName(str(cd.get("lane_id", "")))
		c.held = Customer.held_from(cd.get("held", []))
		c.target_recipe = StringName(str(cd.get("target_recipe", "")))
		c.target_display = int(cd.get("target_display", -1))
		c.target_qty = int(cd.get("target_qty", 0))
		c.substitution_used = bool(cd.get("substitution_used", false))
		c.browse_left = float(cd.get("browse_left", 0.0))
		c.celebrate_left = float(cd.get("celebrate_left", 0.0))
		c.queue_wait = float(cd.get("queue_wait", 0.0))
		c.stall_time = float(cd.get("stall_time", 0.0))
		c.awaiting_tap = bool(cd.get("awaiting_tap", false))
		c.is_critic = bool(cd.get("is_critic", false))
		c.spawned_at = float(cd.get("spawned_at", 0.0))
		c.window_shopper = bool(cd.get("window_shopper", false))
		c.look_cell = arr_to_cell(cd.get("look_cell", [-1, -1]))
		c.look_display = int(cd.get("look_display", -1))
		c.looks_left = int(cd.get("looks_left", 0))
		if c.window_shopper:
			c.actor = _window_shopper_actor(c)
		else:
			c.actor = SimActor.new()
			c.actor.id = c.id
			c.actor.kind = &"customer"
			c.actor.nav_class = FloorGrid.NAV_PUBLIC
			c.actor.speed_mps = c.def().movement_speed_mps
		c.actor.apply_dict(cd.get("actor", {}))
		customers[c.id] = c


## Setelah semua manajer pulih: tempatkan aktor ke posisi kanonik dan
## lanjutkan rute (GDD 77.2). Tidak ada penjualan/roti ganda.
func reconstruct() -> void:
	for c: Customer in sorted():
		if c.window_shopper:
			_reconstruct_window_shopper(c)
			continue
		var lane: QueueLane = sim.queue.lane(c.lane_id)
		match c.state:
			Customer.QUEUING:
				var i: int = lane.slot_index_of(c.id) if lane != null else -1
				if i < 0:
					abandon(c)
					continue
				c.last_slot = i
				c.actor.place_at(lane.floor_id, sim.queue.slot_cell(lane, i))
			Customer.FRONT_OF_QUEUE, Customer.BEING_SERVED:
				if lane == null or lane.service_occupant != c.id:
					abandon(c)
					continue
				c.actor.place_at(lane.floor_id, lane.service_point)
			Customer.ENTERING:
				_choose_target(c)
			Customer.CARRYING_TO_QUEUE:
				_go_to_tail(c)
			Customer.BROWSING, Customer.SELECTING:
				var acc: Dictionary = sim.world.access_of(c.target_display)
				if acc.is_empty():
					_choose_target(c)
				else:
					c.actor.place_at(acc["floor"], acc["cell"])
					sim.world.reserve_point(acc["floor"], acc["cell"], c.id)
					c.state = Customer.BROWSING
			_:
				_walk_out(c)


## Pengunjung lihat-lihat kembali ke tempat berdirinya, atau pulang bila tempat
## itu sudah tidak sah atau sudah dipakai orang lain.
func _reconstruct_window_shopper(c: Customer) -> void:
	var floor_id: StringName = sim.world.store_floor()
	match c.state:
		Customer.ENTERING, Customer.BROWSING:
			if not _look_spot_valid(c) or not sim.world.reserve_point(floor_id, c.look_cell, c.id):
				_window_leave(c)
			elif c.state == Customer.BROWSING:
				c.actor.place_at(floor_id, c.look_cell)
				_face_look_target(c)
			elif not c.actor.go_to(sim.world, floor_id, c.look_cell):
				_window_leave(c)
		_:
			c.state = Customer.LEAVING
			_walk_out(c)
