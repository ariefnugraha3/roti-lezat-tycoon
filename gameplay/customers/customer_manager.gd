class_name CustomerManager
extends SimManager
## CustomerManager — pemilik siklus hidup logis pelanggan fisik (GDD idle 6.1-6.4;
## v3.1 20, 58, 83, 84, 98). Pelanggan baru hanya "masuk toko" setelah
## memperoleh token kapasitas antrean; sebelum itu ia hanya data pending di
## DemandManager. Arketipe hanya menentukan tampilan, jumlah beli, dan
## preferensi resep; harga tidak lagi disetel pemain, jadi tidak ada aturan
## sensitivitas harga, kualitas, atau kesegaran (GDD idle 6.1, 6.2).
## Pengunjung lihat-lihat (v3.1 20.12) juga tinggal di sini, dengan id "w…" yang
## selalu diurutkan sesudah pembeli "c…", dan tidak pernah menyentuh antrean.

const BROWSE_SECONDS: float = 1.0
const CELEBRATE_SECONDS: float = 0.8
## Bobot terkecil satu resep di rak, supaya setiap resep tetap bisa dipilih.
const PREFERENCE_FLOOR: float = 0.05

var customers: Dictionary = {}
var _sorted_cache: Array[Customer] = []
var next_num: int = 1
var next_window_num: int = 1


func new_game() -> void:
	customers.clear()
	next_num = 1
	next_window_num = 1


func customer(id: StringName) -> Customer:
	return customers.get(id)


## Pelanggan terurut ID (Ids.sort), read-only. Disusun ulang hanya bila
## himpunannya berubah (ukuran sama dan setiap pelanggan lama masih terdaftar);
## array lama tidak pernah diubah, jadi loop yang sedang berjalan aman. Dulu
## disortir ulang setiap tick (GDD 109).
func sorted() -> Array[Customer]:
	var same: bool = _sorted_cache.size() == customers.size()
	if same:
		for c: Customer in _sorted_cache:
			if customers.get(c.id) != c:
				same = false
				break
	if not same:
		var out: Array[Customer] = []
		for k: Variant in Ids.sort(customers.keys()):
			out.append(customers[k])
		out.make_read_only()
		_sorted_cache = out
	return _sorted_cache


func archetype_of(actor_id: StringName) -> StringName:
	var c: Customer = customers.get(actor_id)
	if c != null:
		return c.archetype
	return &"driver_rotifood"


func active_count() -> int:
	return customers.size()


## Pembeli (bukan pengunjung lihat-lihat) yang paling awal masuk dan belum
## selesai di toko, atau null.
func first_buyer() -> Customer:
	var best: Customer = null
	for c: Customer in sorted():
		if c.window_shopper or c.state in [Customer.APPROACHING, Customer.CELEBRATING, Customer.LEAVING, Customer.ABANDONING, Customer.LEAVE_NO_STOCK, Customer.DESPAWNED]:
			continue
		if best == null or c.spawned_at < best.spawned_at:
			best = c
	return best


# ===========================================================================
# ADMISSION (GDD 20.5, 83.2)
# ===========================================================================

## Coba memasukkan satu kedatangan pending. true = aktor muncul di pintu.
func try_admit(arrival: Dictionary) -> bool:
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
	c.patience_max = def.base_patience_seconds * sim.upgrades.patience_mult()
	c.patience = c.patience_max
	c.lane_id = lane.id
	c.actor = SimActor.new()
	c.actor.id = c.id
	c.actor.kind = &"customer"
	c.actor.nav_class = FloorGrid.NAV_PUBLIC
	c.actor.speed_mps = def.movement_speed_mps
	c.actor.visual_key = archetype
	c.actor.visual_seed = sim.rng.stream(&"cosmetic_rng").randi()
	customers[c.id] = c
	_start_approach(c)
	return true


## Datang dari ujung trotoar (keputusan maintainer 2026-10-09, GDD 20.1): slot
## antrean sudah dipesan saat diterima, lalu ia berjalan sepanjang trotoar ke
## pintu. Sisinya bergantian menurut nomor pelanggan, tanpa RNG.
func _start_approach(c: Customer) -> void:
	var num: int = int(String(c.id).substr(1))
	var side: int = -1 if num % 2 == 1 else 1
	c.actor.walk_path(sim.world.store_floor(), StreetPaths.approach(sim.world.location, side))
	c.state = Customer.APPROACHING


## Tiba di pintu: baru sekarang ia masuk toko, membunyikan bel, dan memilih roti
## (atau tempat melihat-lihat).
func _enter_shop(c: Customer) -> void:
	c.actor.place_at(sim.world.store_floor(), sim.world.entrance_cell())
	c.spawned_at = sim.time.sim_seconds
	EventBus.sfx.emit(&"door_bell_enter", c.actor.floor_id)
	if c.window_shopper:
		c.state = Customer.ENTERING
		if not c.actor.go_to(sim.world, sim.world.store_floor(), c.look_cell):
			_window_leave(c)
		return
	c.state = Customer.ENTERING
	sim.statistics.add(&"total_customers_entered", 1)
	EventBus.customer_spawned.emit(0)
	_choose_target(c)


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
	return 1 + sim.staff.actors.size() + customers.size() + sim.rotifood.driver_count()


## Ia tidak memakai token antrean. Ia masuk hanya bila jumlahnya di bawah batas
## tier, aktor aktif di bawah anggaran lokasi (GDD 37.2), dan ada tempat berdiri
## bebas. Bila tidak, kedatangan itu dilewati: ia bukan permintaan, jadi tidak
## pernah pending dan tidak dihitung sebagai permintaan yang terlewat.
func try_admit_window_shopper(archetype: StringName) -> bool:
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
	c.actor = _window_shopper_actor(c)
	c.actor.visual_seed = r.randi()
	# Tempatnya dipesan sekarang; ia berjalan ke sana setelah tiba di pintu.
	c.look_cell = spot["cell"]
	c.look_display = int(spot["display"])
	sim.world.reserve_point(sim.world.store_floor(), c.look_cell, c.id)
	customers[c.id] = c
	_start_approach(c)
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
	# Sama dengan _buyer_goal_cells(...).has(cell), tanpa menyusun kamus setiap tick.
	if cell.x < 0:
		return false
	var fid: StringName = sim.world.store_floor()
	for v: Variant in customers.values():
		var b: Customer = v
		if not b.window_shopper and b.actor.goal_floor == fid and b.actor.goal_cell == cell:
			return true
	return false


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
# PEMILIHAN PRODUK (GDD idle 6.2; v3.1 84.1)
# ===========================================================================

## Pilih resep & rak target di antara petak yang berisi. Bila tidak ada roti
## sama sekali, pembeli pulang: penjualan hilang (GDD idle 6.2).
func _choose_target(c: Customer) -> void:
	var def: CustomerArchetypeDefinition = c.def()
	var avail: Dictionary = sim.display.sellable_by_recipe()
	if c.substitution_used and c.target_recipe != &"":
		avail.erase(c.target_recipe)
	if avail.is_empty():
		_leave_no_stock(c)
		return
	var recipe_id: StringName = pick_recipe(def, avail.keys(), sim.rng.stream(&"customer_choice_rng"))
	if recipe_id == &"":
		_leave_no_stock(c)
		return
	var qty: int = _pick_quantity(def)
	var display_iid: int = _nearest_display_with(c, recipe_id)
	if display_iid < 0:
		_leave_no_stock(c)
		return
	var in_display: int = sim.display.count_recipe(recipe_id, display_iid)
	if def.quantity_partial_min > 0 and in_display < def.quantity_partial_min and not c.substitution_used:
		# Pembeli borongan pindah sekali ke resep lain bila stok raknya kurang (v3.1 84.1).
		var others: Array = avail.keys()
		others.erase(recipe_id)
		if not others.is_empty():
			c.substitution_used = true
			recipe_id = pick_recipe(def, others, sim.rng.stream(&"customer_choice_rng"))
			display_iid = _nearest_display_with(c, recipe_id)
			if display_iid < 0:
				_leave_no_stock(c)
				return
			in_display = sim.display.count_recipe(recipe_id, display_iid)
	qty = clampi(mini(qty, in_display), 1, maxi(1, in_display))
	c.target_recipe = recipe_id
	c.target_display = display_iid
	c.target_qty = qty
	_walk_to_display(c)


## Bobot pilihan resep (GDD idle 6.2): preferensi tag arketipe (paling kecil
## PREFERENCE_FLOOR) × harga relatif = (harga dasar termurah di antara pilihan
## ÷ harga dasar resep)^`customers.price_weight_exponent`. Harga dasar dipakai
## supaya menaikkan level resep tidak pernah menurunkan permintaannya.
static func recipe_weights(def: CustomerArchetypeDefinition, options: Array) -> Dictionary:
	var cheapest: float = INF
	for rid: Variant in options:
		cheapest = minf(cheapest, DataRegistry.recipe(StringName(str(rid))).base_sell_price_kr)
	var ex: float = DataRegistry.idlef("customers.price_weight_exponent")
	var out: Dictionary = {}
	for rid2: Variant in options:
		var r: RecipeDefinition = DataRegistry.recipe(StringName(str(rid2)))
		var pref: float = maxf(def.preference_for(r), PREFERENCE_FLOOR)
		out[String(r.id)] = pref * pow(cheapest / maxf(r.base_sell_price_kr, 0.0001), ex)
	return out


static func pick_recipe(def: CustomerArchetypeDefinition, options: Array, r: RandomNumberGenerator) -> StringName:
	if options.is_empty():
		return &""
	var pick: Variant = RNGManager.weighted_pick(r, recipe_weights(def, options))
	return StringName(str(pick)) if pick != null else &""


## Jumlah beli (v3.1 84.1): 50% preferred, 20% ±1, sisa berbagi 10%; pembeli
## borongan memakai distribusi segitiga.
func _pick_quantity(def: CustomerArchetypeDefinition) -> int:
	var r: RandomNumberGenerator = sim.rng.stream(&"customer_choice_rng")
	if def.quantity_mode == &"triangular":
		var a: float = float(def.quantity_min)
		var b: float = float(def.quantity_max)
		var m: float = float(def.quantity_preferred)
		var u: float = r.randf()
		var fc: float = (m - a) / (b - a)
		var x: float = a + sqrt(u * (b - a) * (m - a)) if u < fc else b - sqrt((1.0 - u) * (b - a) * (b - m))
		return clampi(int(round(x)), def.quantity_min, def.quantity_max)
	var weights: Dictionary = quantity_weights(def)
	return int(RNGManager.weighted_pick(r, weights))


## Bobot jumlah beli satu arketipe (v3.1 84.1); juga dipakai IdleEconomy.
static func quantity_weights(def: CustomerArchetypeDefinition) -> Dictionary:
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
	return weights


## Rata-rata jumlah beli arketipe (tanpa batas stok).
static func mean_quantity(def: CustomerArchetypeDefinition) -> float:
	if def.quantity_mode == &"triangular":
		return (float(def.quantity_min) + float(def.quantity_max) + float(def.quantity_preferred)) / 3.0
	var w: Dictionary = quantity_weights(def)
	var tot: float = 0.0
	var acc: float = 0.0
	for q: Variant in w.keys():
		tot += float(w[q])
		acc += float(q) * float(w[q])
	return acc / maxf(tot, 0.0001)


func _nearest_display_with(c: Customer, recipe_id: StringName) -> int:
	var best: int = -1
	var best_d: int = 1 << 30
	for iid: Variant in sim.display.display_ids():
		if sim.display.count_recipe(recipe_id, int(iid)) <= 0:
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


## Pembeli sudah masuk tetapi tidak menemukan roti: penjualan hilang, reputasi
## turun (GDD idle 6.2, 6.6).
func _leave_no_stock(c: Customer) -> void:
	sim.reputation.on_lost()
	sim.statistics.add(&"total_customers_left_no_purchase", 1)
	sim.world.release_all_for(c.id)
	sim.queue.release(c.id)
	c.state = Customer.LEAVE_NO_STOCK
	_walk_out(c)


func _walk_out(c: Customer) -> void:
	if not c.actor.go_to(sim.world, sim.world.store_floor(), sim.world.entrance_cell()):
		c.actor.place_at(sim.world.store_floor(), sim.world.entrance_cell())


# ===========================================================================
# TICK
# ===========================================================================

func step(dt: float) -> void:
	for c: Customer in sorted():
		var arrived: bool = c.actor.step(dt, sim.world)
		if c.state == Customer.APPROACHING:
			if not c.actor.has_route():
				_enter_shop(c)
			continue
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


func _step_entering(c: Customer, _arrived: bool) -> void:
	if c.actor.has_route():
		return
	var acc: Dictionary = sim.world.access_of(c.target_display)
	if acc.is_empty():
		_choose_target(c)
		return
	if c.actor.cell() != acc["cell"]:
		# Titik browsing sedang dipakai: tunggu di sel sebelahnya (v3.1 83.3).
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


## Tiba di rak: validasi ulang stok secara atomik lalu ambil (v3.1 84.2). Harga
## dikunci sekarang (GDD idle 7.2).
func _select(c: Customer) -> void:
	c.state = Customer.SELECTING
	var def: CustomerArchetypeDefinition = c.def()
	var price: float = sim.unit_price(c.target_recipe, c.target_display)
	var lots: Array[Dictionary] = sim.display.take(c.target_recipe, c.target_qty, c.target_display, price, true)
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
			# Pindah sekali ke resep lain terhadap stok terbaru (v3.1 84.2).
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
			c.actor.go_to(sim.world, lane.floor_id, lane.service_point)
			return
	_drain(c, dt)


## Drain patience (v3.1 58): dasar 1.0/detik, modifier multiplikatif.
func _drain(c: Customer, dt: float) -> void:
	var lane: QueueLane = sim.queue.lane(c.lane_id)
	# Transaksi yang sedang berjalan tidak mengurangi patience (v3.1 20.8).
	if c.state == Customer.BEING_SERVED and sim.cashier.is_progressing(c.id):
		return
	c.queue_wait += dt
	c.stall_time += dt
	var pt: PackedFloat64Array = DataRegistry.patience_tuning()
	var m: float = pt[0]
	if lane != null and lane.occupancy_ratio() >= pt[1]:
		m *= pt[2]
	if c.stall_time > pt[3]:
		m *= pt[4]
	m = clampf(m, pt[5], pt[6])
	c.patience = maxf(0.0, c.patience - m * dt)
	if c.patience <= 0.0:
		abandon(c)


# ===========================================================================
# JALUR KASIR: ANTREAN MENGALIR KE JALUR YANG AKTIF (v3.1 21.3)
# ===========================================================================

## Dipanggil tiap tick sebelum admission (SimulationRoot.step), supaya pembeli
## yang sudah di dalam toko mendapat slot lebih dulu daripada kedatangan baru.
## - Jalur yang tutup melepas pembeli yang belum dilayani ke jalur terbuka yang
##   masih punya slot.
## - Jalur terbuka yang bebannya lebih besar 2 atau lebih dari jalur terbuka lain
##   melepas pembeli terdepannya yang masih antre ke jalur itu, sampai seimbang.
## Pembeli yang transaksinya sudah dimulai tidak pernah dipindah, dan driver
## RotiFood tetap di jalurnya.
func rebalance_lanes() -> void:
	var anyone: bool = false
	for l0: QueueLane in sim.queue.lanes:
		if not l0.reservations.is_empty() or not l0.line.is_empty() or l0.service_occupant != &"":
			anyone = true
			break
	if not anyone:
		return
	var open: Array[QueueLane] = sim.queue.open_physical_lanes()
	if open.is_empty():
		return
	for lane: QueueLane in sim.queue.lanes:
		if open.has(lane):
			continue
		for cid: StringName in _movable(lane, true):
			var to: QueueLane = _lightest(open)
			if to == null:
				break
			_move_customer(customer(cid), lane, to)
	if open.size() < 2:
		return
	for _i in 32:
		var heavy: QueueLane = null
		for l: QueueLane in open:
			if heavy == null or sim.queue.load_of(l) > sim.queue.load_of(heavy):
				heavy = l
		var light: QueueLane = _lightest(open)
		if heavy == null or light == null or heavy == light:
			return
		if sim.queue.load_of(heavy) - sim.queue.load_of(light) < 2:
			return
		var cand: Array[StringName] = _movable(heavy, false)
		if cand.is_empty():
			return
		_move_customer(customer(cand[0]), heavy, light)


func _lightest(open: Array[QueueLane]) -> QueueLane:
	var best: QueueLane = null
	for l: QueueLane in open:
		if l.free_capacity() <= 0:
			continue
		if best == null or sim.queue.load_of(l) < sim.queue.load_of(best):
			best = l
	return best


func _movable(lane: QueueLane, include_front: bool) -> Array[StringName]:
	var out: Array[StringName] = []
	if include_front and lane.service_occupant != &"":
		var f: Customer = customer(lane.service_occupant)
		if f != null and f.state == Customer.FRONT_OF_QUEUE:
			out.append(f.id)
	for id: StringName in lane.line:
		var c: Customer = customer(id)
		if c != null and c.state == Customer.QUEUING:
			out.append(c.id)
	for id2: StringName in lane.reservations:
		var c2: Customer = customer(id2)
		if c2 != null and not lane.line.has(id2) and not out.has(id2) \
				and c2.state in [Customer.APPROACHING, Customer.ENTERING, Customer.BROWSING, Customer.CARRYING_TO_QUEUE]:
			out.append(c2.id)
	return out


func _move_customer(c: Customer, from: QueueLane, to: QueueLane) -> void:
	if c == null or not sim.queue.move_actor(c.id, from, to):
		return
	c.lane_id = to.id
	if c.state == Customer.QUEUING or c.state == Customer.FRONT_OF_QUEUE:
		sim.cashier.cancel_for(c.id)
		c.state = Customer.CARRYING_TO_QUEUE
		c.last_slot = -1
		_go_to_tail(c)


## Patience habis: roti kembali ke rak persis seperti semula, reputasi turun
## (GDD idle 6.4, 6.6).
func abandon(c: Customer) -> void:
	if c.state == Customer.ABANDONING:
		return
	sim.cashier.cancel_for(c.id)
	sim.display.return_lots(c.held)
	c.held.clear()
	sim.queue.release(c.id)
	sim.world.release_all_for(c.id)
	sim.reputation.on_lost()
	sim.statistics.add(&"total_customers_lost_patience", 1)
	c.state = Customer.ABANDONING
	EventBus.customer_abandoned.emit(0)
	EventBus.sfx.emit(&"customer_leave_angry", c.actor.floor_id)
	_walk_out(c)


## Dipanggil CashierManager setelah commit penjualan (v3.1 103.1).
func on_paid(c: Customer) -> void:
	c.held.clear()
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


## Semua pelanggan keluar tanpa penalti dan rotinya kembali ke rak, misalnya
## sebelum upgrade lokasi atau Waralaba (GDD idle 8.7, 10.6).
func shutdown() -> void:
	for c: Customer in sorted():
		sim.cashier.cancel_for(c.id)
		if not c.held.is_empty():
			sim.display.return_lots(c.held)
			c.held.clear()
		sim.world.release_all_for(c.id)
		sim.queue.release(c.id)
	customers.clear()


# ===========================================================================
# SAVE (v3.1 77.2: snapshot logis, aktor direkonstruksi ke slot kanonik)
# ===========================================================================

func capture() -> Dictionary:
	var list: Array = []
	for c: Customer in sorted():
		list.append(c.to_dict())
	return {"next_num": next_num, "next_window_num": next_window_num, "customers": list}


func restore(d: Dictionary) -> void:
	customers.clear()
	next_num = int(d.get("next_num", 1))
	next_window_num = int(d.get("next_window_num", 1))
	for item: Variant in d.get("customers", []):
		var cd: Dictionary = item
		var c := Customer.new()
		c.id = StringName(str(cd["id"]))
		c.archetype = StringName(str(cd["archetype"]))
		if c.def() == null:
			continue
		c.state = StringName(str(cd.get("state", Customer.ENTERING)))
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
## lanjutkan rute (v3.1 77.2). Tidak ada penjualan/roti ganda.
func reconstruct() -> void:
	for c: Customer in sorted():
		if c.window_shopper:
			_reconstruct_window_shopper(c)
			continue
		var lane: QueueLane = sim.queue.lane(c.lane_id)
		match c.state:
			Customer.APPROACHING:
				_start_approach(c)
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
				# Pilihan roti yang sudah dibuat dipertahankan tanpa menarik RNG lagi,
				# seperti di game yang tidak di-load: ia melanjutkan jalannya ke rak
				# (atau menunggu di tempatnya) dan _step_entering menangani sisanya.
				if c.target_recipe != &"" and not sim.world.access_of(c.target_display).is_empty():
					if c.actor.goal_cell.x >= 0 and c.actor.cell() != c.actor.goal_cell:
						c.actor.go_to(sim.world, c.actor.goal_floor, c.actor.goal_cell)
				else:
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
		Customer.APPROACHING:
			if _look_spot_valid(c):
				sim.world.reserve_point(floor_id, c.look_cell, c.id)
			_start_approach(c)
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
