class_name WorldView
extends Node3D
## WorldRoot (GDD 36): visual dunia yang dibangun dari state simulasi. Tidak
## memiliki state gameplay; semua posisi berasal dari SimActor & EquipmentManager.
##
## Hanya satu lantai dirender penuh (GDD 30.3). Lantai lain tetap disimulasikan
## penuh oleh SimulationRoot; node visualnya disembunyikan dan disinkronkan lagi
## saat lantai itu aktif.

const MARKER_HZ: float = 12.0
const BREAD_HZ: float = 4.0
const MAX_BREAD_PER_SLOT: int = 3
## Isi Meja Tunggu digambar lebih kecil dari barang di tangan agar enam muat.
const TABLE_ITEM_SCALE: float = 0.75
## Warna adonan yang hampir basi di meja.
const TABLE_DOUGH_STALE: Color = Color(0.72, 0.74, 0.58)
const PICK_CUSTOMER_PX: float = 56.0
## Jarak ujung ekor gelembung pikiran di atas puncak kepala/topi pemain (m).
const THOUGHT_ANCHOR_GAP: float = 0.08
## Roti yang tampak masuk ke kantong di meja kasir saat membungkus.
const PACK_BREAD_MAX: int = 3
## Geser kantong sepanjang meja agar tidak tertutup mesin kasir (m).
const PACK_BAG_SIDE: float = 0.24
## Decoration Mode: barang yang dipegang terangkat sedikit dan mengambang pelan (m).
const LIFT_M: float = 0.06
const LIFT_BOB_M: float = 0.015
## Karpet yang dipegang tetap rata di lantai, cukup terangkat agar tidak berkedip
## di atas lantai atau karpet lain (m).
const RUG_LIFT_M: float = 0.012

## Decoration Mode: jarak layar maksimum ketukan ke penanda slot (px).
const PICK_SLOT_PX: float = 56.0
## Ayunan bandul jam dinding dekorasi: kecepatan sudut (rad/s) dan simpangan (rad).
const SWING_SPEED: float = 3.2
const SWING_ANGLE: float = 0.2

var sim: SimulationRoot = null
var camera_rig: CameraRig = null
var floors: Dictionary = {}
var furniture: Dictionary = {}
var markers: Dictionary = {}
var _bread_sig: Dictionary = {}
## Tanda isi Meja Tunggu terakhir yang digambar (GDD 5.1.3).
var _table_sig: String = ""
var _aabbs: Dictionary = {}
var _counter_aabbs: Array[Dictionary] = []
var views: Dictionary = {}
var _pool: Array[ActorView] = []
## Body pelanggan/driver/kurir yang pernah dibuat (aktif + di pool).
var _pooled_bodies: int = 0
var _marker_timer: float = 0.0
var _bread_timer: float = 0.0
var _rain: Node = null
var _rain_layer: CanvasLayer = null
var _highlight: Node3D = null
var _ghosts: Node3D = null
## Overlay ubin Decoration Mode (ubin wajib kosong & area salah).
var _tile_overlay: Node3D = null
var _env: WorldEnvironment = null
var _t: float = 0.0
var _smoke: Dictionary = {}
var decoration_mode: bool = false
## Panaskan shader alat tier baru setelah upgrade lokasi (diset GameRoot).
var shader_warmup: bool = false
## Decoration Mode boleh melihat lantai lain selama simulasi di-pause.
var view_floor_override: StringName = &""
## lane_id -> kantong kertas yang sedang diisi di meja kasir (GDD 21.4).
var _pack_bags: Dictionary = {}
var _thought_layer: CanvasLayer = null
var _thought_bubble: ThoughtBubble = null
## customer_id -> gelembung celetukan pengunjung lihat-lihat (GDD 20.12).
var _shopper_bubbles: Dictionary = {}
## Detik NYATA toko buka tanpa satu pun pelanggan (GDD 31.7).
var _quiet_real: float = 0.0
## Barang yang sedang dipegang di Decoration Mode (GDD 72.2): {kind
## (&"equipment"/&"decor"), id, floor, cell, rot, slot}; kosong = tidak ada.
## Modelnya digambar di posisi calon itu; tata letak simulasi tidak berubah.
var _hold: Dictionary = {}
## Node yang digambar untuk barang yang dipegang: model aslinya, atau model
## sementara (`_hold_temp`) untuk barang yang belum terpasang.
var _hold_node: Node3D = null
var _hold_temp: bool = false
## Posisi dasar (sebelum terangkat) dan kotak dunia model yang dipegang.
var _hold_base: Vector3 = Vector3.ZERO
var _hold_aabb: AABB = AABB()
## Dekorasi terpasang (GDD 72.1, 72.3): uid -> {node, floor, type, aabb, base}.
var _decor: Dictionary = {}
## Bandul jam dinding dekorasi yang diayun (GDD 12.3 animasi trigonometri).
var _swing: Array[Node3D] = []
## Bandul jam dinding bawaan ruangan (RoomFactory), diayun dengan cara yang sama.
var _room_swing: Array[Node3D] = []
## Penanda slot dinding/meja Decoration Mode: [{index, node, aabb, pos}].
var _slot_markers: Node3D = null
var _slot_marker_list: Array[Dictionary] = []


func setup(s: SimulationRoot) -> void:
	sim = s
	name = "WorldRoot"
	_env = EquipmentFactory.build_environment()
	add_child(_env)
	camera_rig = CameraRig.new()
	add_child(camera_rig)
	camera_rig.active_floor_changed.connect(_on_camera_floor_changed)
	_rain_layer = CanvasLayer.new()
	_rain_layer.layer = 2
	add_child(_rain_layer)
	_ghosts = Node3D.new()
	_ghosts.name = "PlacementGhosts"
	add_child(_ghosts)
	_tile_overlay = Node3D.new()
	_tile_overlay.name = "TileOverlay"
	add_child(_tile_overlay)
	_slot_markers = Node3D.new()
	_slot_markers.name = "SlotMarkers"
	add_child(_slot_markers)
	_thought_layer = CanvasLayer.new()
	_thought_layer.name = "ThoughtLayer"
	_thought_layer.layer = 3
	add_child(_thought_layer)
	_thought_bubble = ThoughtBubble.new()
	_thought_layer.add_child(_thought_bubble)
	sim.world.layout_changed.connect(rebuild_furniture)
	EventBus.location_changed.connect(func(_id: StringName) -> void: _on_location_changed())
	EventBus.storage_door.connect(_on_storage_door)
	EventBus.weather_changed.connect(func(_a: StringName, _b: StringName) -> void: _apply_weather())
	EventBus.sale_completed.connect(_on_sale)
	SettingsManager.settings_changed.connect(func(_k: String) -> void: _apply_brightness())
	rebuild_all()
	camera_rig.active_floor = sim.player.actor.floor_id
	camera_rig.snap_to(_v3(sim.player.actor.pos))
	_apply_floor_visibility()


## Upgrade lokasi: ruangan baru dibangun, lalu shader alat tier baru dipanaskan
## di bawah lantai (tak terlihat) supaya tidak macet saat alat itu dibeli nanti.
func _on_location_changed() -> void:
	rebuild_all()
	if shader_warmup:
		var w: ShaderWarmup = ShaderWarmup.start(self)
		for i in 2:
			await get_tree().process_frame
		if is_instance_valid(w):
			w.finish()


func rebuild_all() -> void:
	for f: Variant in floors.values():
		(f as Node3D).queue_free()
	floors.clear()
	# Kantong di meja ikut lantai lamanya; dibuat ulang saat membungkus berikutnya.
	_pack_bags.clear()
	_counter_aabbs.clear()
	var skins: Dictionary = sim.decoration.equipped.duplicate()
	_room_swing.clear()
	for fd: FloorDefinition in sim.world.location.floors:
		var node: Node3D = RoomFactory.build_floor(sim.world.location, fd, sim.bakery_name, skins)
		add_child(node)
		floors[fd.id] = node
		var pend: Node3D = node.find_child(DecorFactory.SWING_NODE, true, false) as Node3D
		if pend != null:
			_room_swing.append(pend)
	rebuild_furniture()
	_apply_weather()
	_apply_brightness()
	_update_counter_aabbs()
	_apply_floor_visibility()
	MaterialKeep.scan(self)


func rebuild_furniture() -> void:
	for n: Variant in furniture.values():
		(n as Node3D).queue_free()
	furniture.clear()
	# Penanda menempel di node lantai, bukan di perabot: tanpa dibebaskan di sini
	# penanda lama tertinggal membeku (bar progres yang tidak pernah hilang).
	for m: Variant in markers.values():
		if is_instance_valid(m):
			(m as Node3D).queue_free()
	markers.clear()
	_bread_sig.clear()
	_table_sig = ""
	_aabbs.clear()
	for e: EquipmentInstance in sim.equipment.placed_list():
		var parent: Node3D = floors.get(e.floor_id)
		if parent == null:
			continue
		var node: Node3D = _build_furniture(e)
		parent.add_child(node)
		furniture[e.iid] = node
		if e.category() != &"storage" and e.category() != &"chair":
			var m := StationMarker.new()
			parent.add_child(m)
			m.pasang_di(node)
			markers[e.iid] = m
		_aabbs[e.iid] = {"floor": e.floor_id, "aabb": _world_aabb(node)}
	_update_counter_aabbs()
	_rebuild_decor()
	_apply_hold()


## Model dekorasi terpasang (GDD 72.1, 72.3). Posisi dinding/meja dari
## DecorSlots, lantai dari ubinnya, karpet dari jejaknya.
func _rebuild_decor() -> void:
	for d: Variant in _decor.values():
		var old: Variant = (d as Dictionary)["node"]
		if is_instance_valid(old):
			(old as Node).queue_free()
	_decor.clear()
	_swing.clear()
	var loc: LocationDefinition = sim.world.location
	for o: Dictionary in sim.decoration.owned:
		if not bool(o["placed"]):
			continue
		var def: MiscDefinitions.DecorationDefinition = sim.decoration.def_of(o)
		if def == null or not def.is_placeable():
			continue
		var fid: StringName = StringName(str(o["floor_id"]))
		var parent: Node3D = floors.get(fid)
		var xf: Variant = DecorSlots.transform_of(loc, def, o)
		if parent == null or xf == null:
			continue
		var node: Node3D = DecorFactory.build_cached(def.id)
		node.name = "Decor_%d" % int(o["uid"])
		parent.add_child(node)
		node.transform = xf
		var sw: Node3D = node.find_child(DecorFactory.SWING_NODE, true, false) as Node3D
		if sw != null:
			_swing.append(sw)
		_decor[int(o["uid"])] = {"node": node, "floor": fid, "type": def.placement_type,
			"aabb": node.transform * EquipmentFactory._mesh_bounds(node), "base": node.position}


func _build_furniture(e: EquipmentInstance) -> Node3D:
	var def: EquipmentDefinition = e.def()
	var node: Node3D = _equipment_model(e)
	_pose_furniture(node, def, e.anchor, e.rotation)
	if def.category_id == &"oven" and sim.decoration.equipped.has("oven"):
		var decal := ProceduralMeshFactory.box(Vector3(0.18, 0.06, 0.01), Palette.GOLD_STAR)
		node.add_child(decal)
		decal.position = Vector3(0.0, def.height_m * 0.5 / node.scale.x, 0.26)
	return node


## Model alat menurut kategori dan tier-nya, belum diletakkan. Kotak mesh
## aslinya disimpan sebagai meta "bounds" untuk _pose_furniture.
func _equipment_model(e: EquipmentInstance) -> Node3D:
	var def: EquipmentDefinition = e.def()
	var node: Node3D
	match def.category_id:
		&"mixer":
			node = EquipmentFactory.build_mixer(def.tier)
		&"oven":
			node = EquipmentFactory.build_oven(def.tier)
		&"display":
			node = EquipmentFactory.build_display(def.tier)
		&"table":
			node = EquipmentFactory.build_holding_table()
		&"chair":
			node = EquipmentFactory.build_staff_chair()
		_:
			node = EquipmentFactory.build_storage(def.tier)
	node.name = "Equip_%d" % e.iid
	node.set_meta("iid", e.iid)
	node.set_meta("bounds", EquipmentFactory._mesh_bounds(node))
	return node


## Skala, arah hadap, dan posisi model alat untuk jangkar & putaran ini (GDD 60).
## Dipakai saat membangun dunia dan untuk barang yang dipegang di Decoration Mode.
func _pose_furniture(node: Node3D, def: EquipmentDefinition, anchor: Vector2i, rot: int) -> void:
	var fp: Vector2i = GridMath.rotated_footprint(def.footprint_tiles, rot)
	var center := Vector3((float(anchor.x) + float(fp.x) * 0.5) * GridMath.WORLD_METERS_PER_TILE, 0.0,
		(float(anchor.y) + float(fp.y) * 0.5) * GridMath.WORLD_METERS_PER_TILE)
	# Skala seragam agar mesh muat di footprint logis (GDD 60: inset maks 0,05 m).
	var b: AABB = node.get_meta("bounds", EquipmentFactory._mesh_bounds(node))
	var fp0: Vector2 = Vector2(def.footprint_tiles) * GridMath.WORLD_METERS_PER_TILE - Vector2(0.06, 0.06)
	var k: float = 1.0
	if b.size.x > 0.0 and b.size.z > 0.0:
		k = minf(fp0.x / b.size.x, fp0.y / b.size.z)
		if b.size.y * k > def.height_m * 1.2:
			k = def.height_m * 1.2 / b.size.y
	node.scale = Vector3(k, k, k)
	var d: Vector2i = GridMath.face_dir(rot)
	if def.interaction_face == &"short_end":
		var dd: Vector2i = GridMath.face_dir(rot, &"short_end")
		node.rotation.y = atan2(-float(dd.y), float(dd.x))
	else:
		node.rotation.y = atan2(float(d.x), float(d.y))
	var bc: Vector3 = b.get_center() * k
	var rotated_bc: Vector3 = Basis(Vector3.UP, node.rotation.y) * Vector3(bc.x, 0.0, bc.z)
	node.position = center - rotated_bc


func _world_aabb(node: Node3D) -> AABB:
	var local: AABB = EquipmentFactory._mesh_bounds(node)
	var t: Transform3D = Transform3D(Basis(Vector3.UP, node.rotation.y).scaled(node.scale), node.position)
	return t * local


func _update_counter_aabbs() -> void:
	_counter_aabbs.clear()
	for fid: Variant in floors.keys():
		var root: Node3D = floors[fid]
		for c: Node in root.get_children():
			if c.name.begins_with("Counter_") or c.name == "Tablet" or c.name == "Portal":
				var n3: Node3D = c as Node3D
				var local: AABB = EquipmentFactory._mesh_bounds(n3)
				var t: Transform3D = Transform3D(Basis(Vector3.UP, n3.rotation.y).scaled(n3.scale), n3.position)
				_counter_aabbs.append({"floor": fid, "aabb": (t * local).grow(0.04), "name": String(c.name),
					"counter_id": c.get_meta("counter_id", &"")})


# ===========================================================================
# FRAME SYNC
# ===========================================================================

func _process(delta: float) -> void:
	if sim == null:
		return
	_t += delta
	var player: SimActor = sim.player.actor
	var want_floor: StringName = view_floor_override if view_floor_override != &"" else player.floor_id
	if sim.world.grid(want_floor) == null:
		want_floor = player.floor_id
	if want_floor != camera_rig.active_floor:
		var focus: Vector3 = _v3(player.pos) if want_floor == player.floor_id else Vector3(Vector2(sim.world.grid(want_floor).size).x * 0.25, 0.0, Vector2(sim.world.grid(want_floor).size).y * 0.25)
		camera_rig.change_floor(want_floor, focus)
		if want_floor == player.floor_id:
			EventBus.active_floor_changed.emit(player.floor_id)
			EventBus.sfx.emit(&"stairs_floor_switch", player.floor_id)
	camera_rig.set_floor_bounds(Vector2(sim.world.grid(camera_rig.active_floor).size) * GridMath.WORLD_METERS_PER_TILE)
	if want_floor == player.floor_id:
		camera_rig.follow(_v3(player.pos), delta)
	else:
		camera_rig.follow(camera_rig.follow_target, delta)
	_sync_actors(delta)
	_update_thoughts(delta)
	_update_shopper_lines()
	_marker_timer -= delta
	if _marker_timer <= 0.0:
		_marker_timer = 1.0 / MARKER_HZ
		_update_markers()
	_bread_timer -= delta
	if _bread_timer <= 0.0:
		_bread_timer = 1.0 / BREAD_HZ
		_update_bread()
		_update_table()
	_animate_stations(delta)
	_animate_lift()
	_animate_swing()


func _v3(p: Vector2) -> Vector3:
	return Vector3(p.x, 0.0, p.y)


func _sync_actors(delta: float) -> void:
	var live: Dictionary = {}
	var packers: Dictionary = _update_packing()
	var player: SimActor = sim.player.actor
	var pkey: String = "player|%s|%s" % [sim.player.appearance.get("gender", "male"), sim.decoration.equipped.get("outfit", "")]
	var pv: ActorView = views.get(player.id)
	if pv != null:
		# Aksi & status sibuk diatur sebelum sync supaya animasinya frame ini juga.
		pv.set_idle_enabled(true)
		pv.set_busy(_player_busy())
		pv.set_doze_after(DataRegistry.player_doze_after_seconds())
		pv.set_doze_blocked(_player_doze_blocked())
		pv.set_action(&"pack" if packers.has(player.id) else &"")
		_apply_pack(pv, packers.get(player.id))
	_sync_one(player, pkey, _player_spec, delta, live, false)
	pv = views.get(player.id)
	if pv != null:
		var pj: ProductionJob = sim.player.carried_job()
		_apply_carry(pv, player, pj)
	for sid: Variant in sim.staff.actors.keys():
		var a: SimActor = sim.staff.actors[sid]
		var sv0: ActorView = views.get(a.id)
		if sv0 != null:
			sv0.set_idle_enabled(true)
			sv0.set_busy(_staff_busy(StringName(str(sid)), a))
			sv0.set_action(&"pack" if packers.has(a.id) else &"")
			_apply_pack(sv0, packers.get(a.id))
			sv0.set_seat(_seat_of(a))
		_sync_one(a, "staff|" + String(sid), _staff_spec.bind(String(sid)), delta, live, false)
		var sv: ActorView = views.get(a.id)
		if sv != null:
			_apply_carry(sv, a, sim.production.get_job(int(a.carried.get("job_id", -1))) if not a.carried.is_empty() else null)
	var rainy: bool = sim.weather.is_rain()
	var large: bool = SettingsManager.get_bool("patience_bar_large")
	for c: Customer in sim.customers.sorted():
		var a2: SimActor = c.actor
		_sync_one(a2, "cust|%s|%d" % [c.archetype, a2.visual_seed], _npc_spec.bind(String(c.archetype), a2.visual_seed, false), delta, live, true)
		var v: ActorView = views.get(a2.id)
		if v == null:
			continue
		_apply_customer_carry(v, c)
		v.set_receive(_receive_amount(c))
		# Bar kesabaran hanya selama pembeli mengantre di kasir, satu-satunya saat
		# kesabarannya berkurang (keputusan maintainer 2026-10-01, GDD 20.8). Saat
		# masuk dan memilih roti, bar penuh yang diam hanya membingungkan.
		# Pengunjung lihat-lihat tidak pernah mengantre (GDD 20.12).
		var show_bar: bool = not c.window_shopper and c.drains_patience()
		v.set_patience(c.patience_ratio(), show_bar, large)
		v.set_look_around(c.window_shopper and c.state == Customer.BROWSING and not a2.moving)
		# Hanya pembeli di jalur pemain yang menunggu ketukan (GDD 21.2).
		v.set_alert(c.awaiting_tap and c.state == Customer.FRONT_OF_QUEUE and not a2.has_route())
		var thought: String = ""
		if c.drains_patience() and c.patience_ratio() < 0.3:
			thought = "..."
		elif c.state == Customer.ENTERING and (c.price_label == &"UNHAPPY" or c.price_label == &"VERY_UNHAPPY" or c.price_label == &"REFUSE"):
			thought = "$"
		v.set_thought(thought)
	for o: DeliveryOrder in sim.rotifood.orders.values():
		if o.driver == null:
			continue
		_sync_one(o.driver, "drv|%d|%s" % [o.driver.visual_seed, rainy], _npc_spec.bind("driver_rotifood", o.driver.visual_seed, rainy), delta, live, true)
		var dv: ActorView = views.get(o.driver.id)
		if dv != null:
			dv.set_carry("bag" if o.driver_phase == &"leaving" and o.state == DeliveryOrder.COMPLETED else "")
			dv.set_patience(o.driver_patience / maxf(o.driver_patience_max, 0.01), o.driver_phase in [&"entering", &"queued", &"at_service"], large)
	for oid: Variant in sim.supply.couriers.keys():
		var ca: SimActor = sim.supply.couriers[oid]
		_sync_one(ca, "cour|%d" % ca.visual_seed, _npc_spec.bind("courier_supply", ca.visual_seed, false), delta, live, true)
	# Kembalikan view yang aktornya sudah hilang ke pool (GDD 83.2: dibersihkan di pintu).
	for k: Variant in views.keys():
		if not live.has(k):
			var old: ActorView = views[k]
			views.erase(k)
			if bool(old.get_meta("pooled", false)):
				old.reset_for_pool()
				_pool.append(old)
			else:
				old.queue_free()


func _staff_spec(staff_id: String) -> Dictionary:
	return CharacterFactory.spec_for_staff(staff_id)


func _npc_spec(visual_key: String, seed_value: int, rainy: bool) -> Dictionary:
	return CharacterFactory.spec_for_customer(visual_key, seed_value, rainy)


## Spec karakter pemain (GDD 31.3): pilihan pria/wanita murni visual; outfit
## hadiah achievement mengganti celemek (GDD 72.1).
func _player_spec() -> Dictionary:
	var female: bool = str(sim.player.appearance.get("gender", "male")) == "female"
	var sp: Dictionary = CharacterFactory.spec_for_player("wanita" if female else "pria")
	match str(sim.decoration.equipped.get("outfit", "")):
		"outfit_apron_neighborhood":
			sp["apron"] = Palette.GINGHAM_A
		"outfit_chef_hat_perfect":
			sp["hat"] = "toque"
	return sp


func _sync_one(a: SimActor, key: String, spec_fn: Callable, delta: float, live: Dictionary, pooled: bool) -> void:
	live[a.id] = true
	var v: ActorView = views.get(a.id)
	if v == null:
		if pooled and not _pool.is_empty():
			v = _pool.pop_back()
		else:
			# Pool berhenti tumbuh di batas GDD 129; aktor tetap ada secara logis,
			# hanya tidak digambar sampai ada body yang kembali ke pool.
			if pooled and _pooled_bodies >= DataRegistry.bali("limits.pooled_customer_bodies"):
				return
			v = ActorView.new()
			add_child(v)
			v.set_meta("pooled", pooled)
			if pooled:
				_pooled_bodies += 1
		views[a.id] = v
		v.bind(a.id, key, spec_fn.call())
		v.visible = true
		v.global_position = _v3(a.pos)
	elif v.spec_key != key:
		v.bind(a.id, key, spec_fn.call())
	var on_floor: bool = a.floor_id == camera_rig.active_floor
	v.visible = on_floor
	v.sync(a, delta, on_floor)


func _apply_carry(v: ActorView, a: SimActor, j: ProductionJob) -> void:
	if a.carried.is_empty() or j == null:
		v.set_carry("")
		return
	var t: String = str(a.carried.get("type", ""))
	v.set_carry(t, String(j.recipe().visual_profile_id), j.bake_quality)


## Pembeli menenteng roti lepas dari rak ke kasir; saat fase membungkus roti itu
## sudah di meja; setelah membayar ia pulang membawa kantong kertas (GDD 2, 21.4).
## Bagi pembeli, LEAVING hanya dicapai lewat CELEBRATING, yaitu setelah membayar;
## pengunjung lihat-lihat datang dan pulang dengan tangan kosong (GDD 20.12).
func _apply_customer_carry(v: ActorView, c: Customer) -> void:
	if c.window_shopper:
		v.set_carry("")
		return
	if c.state == Customer.CELEBRATING or c.state == Customer.LEAVING:
		v.set_carry("bag")
		return
	if c.held_units() <= 0 or (c.state == Customer.BEING_SERVED and sim.cashier.packing_progress(c.lane_id) >= 0.0):
		v.set_carry("")
		return
	var lot: Dictionary = c.held[0]
	var st: BreadStack = lot["stack"]
	var r: RecipeDefinition = DataRegistry.recipe(st.recipe_id)
	v.set_carry("bread", String(r.visual_profile_id) if r != null else "", st.bake_quality, mini(c.held_units(), PACK_BREAD_MAX))


## Pembeli mengulurkan tangan sejak kantong disodorkan sampai membayar (GDD 21.4).
func _receive_amount(c: Customer) -> float:
	if c.state != Customer.BEING_SERVED:
		return 0.0
	var p: float = sim.cashier.packing_progress(c.lane_id)
	if p < 0.0:
		return 0.0
	var rig: PackBagRig = _pack_bags.get(c.lane_id) as PackBagRig
	var ph: Vector3 = ProceduralAnimationSystem.pack_phases(rig.count if rig != null else 1)
	return smoothstep(ph.z, ph.z + ProceduralAnimationSystem.PACK_OFFER_SPAN, p)


## Pemain sedang mengerjakan sesuatu: berjalan, berinteraksi, membawa barang,
## punya perintah antre, atau melayani transaksi di meja kasir.
func _player_busy() -> bool:
	var p: PlayerTaskManager = sim.player
	if not p.actor.carried.is_empty() or not p.commands.is_empty() or not p.current.is_empty():
		return true
	if p.actor.state == &"WALKING" or p.actor.state == &"INTERACTING":
		return true
	return p.manning_lane != &"" and not sim.cashier.transaction_for(p.manning_lane).is_empty()


## Permukaan bantal kursi tempat koki duduk (GDD 5.1.4), atau INF bila berdiri.
func _seat_of(a: SimActor) -> Vector3:
	if a.seat_iid < 0:
		return Vector3.INF
	var node: Node3D = furniture.get(a.seat_iid) as Node3D
	if node == null or not is_instance_valid(node) or not node.is_inside_tree():
		return Vector3.INF
	var seat: Node3D = node.get_node_or_null("Seat") as Node3D
	return seat.global_position if seat != null else Vector3.INF


func _staff_busy(sid: StringName, a: SimActor) -> bool:
	if not a.carried.is_empty() or a.state == &"WALKING" or a.state == &"INTERACTING" or sim.staff.tasks.has(sid):
		return true
	var lane_id: Variant = sim.staff.lane_assign.get(sid)
	return lane_id != null and not sim.cashier.transaction_for(StringName(str(lane_id))).is_empty()


## Kantong kertas di meja kasir selama fase membungkus (GDD 21.4), digerakkan
## PackBagRig pada progres yang sama dengan pose kasir. Mengembalikan
## {actor_id: {p, n}} untuk kasir (pemain/staf) yang sedang membungkus.
func _update_packing() -> Dictionary:
	var packers: Dictionary = {}
	var seen: Dictionary = {}
	for lane: QueueLane in sim.queue.lanes:
		var prog: float = sim.cashier.packing_progress(lane.id)
		if prog < 0.0:
			continue
		var n: int = _pack_count(lane)
		if lane.floor_id == camera_rig.active_floor and floors.has(lane.floor_id):
			seen[lane.id] = true
			var rig: PackBagRig = _pack_bags.get(lane.id) as PackBagRig
			if rig == null or not is_instance_valid(rig):
				rig = _build_pack_bag(lane)
				(floors[lane.floor_id] as Node3D).add_child(rig)
				_pack_bags[lane.id] = rig
			n = rig.count
			for ev: StringName in rig.animate(prog):
				if ev == &"bread_in":
					EventBus.sfx.emit(&"customer_pick_bread", lane.floor_id)
				elif ev == &"sealed":
					EventBus.sfx.emit(&"bread_place_display", lane.floor_id)
					FX.sugar_sparkle(floors[lane.floor_id], rig.position + Vector3(0.0, PackBagRig.MOUTH_Y + 0.04, 0.0))
		var info: Dictionary = {"p": prog, "n": n}
		var td: Dictionary = sim.cashier.transaction_for(lane.id)
		if bool(td.get("manual", false)):
			packers[sim.player.actor.id] = info
		else:
			for sid: Variant in sim.staff.lane_assign.keys():
				if StringName(str(sim.staff.lane_assign[sid])) == lane.id and sim.staff.actors.has(sid):
					packers[(sim.staff.actors[sid] as SimActor).id] = info
	for k: Variant in _pack_bags.keys():
		if not seen.has(k):
			var old: Node3D = _pack_bags[k]
			if is_instance_valid(old):
				old.queue_free()
			_pack_bags.erase(k)
	return packers


func _apply_pack(view: ActorView, info: Variant) -> void:
	if info is Dictionary:
		view.set_pack_progress(float((info as Dictionary)["p"]), int((info as Dictionary)["n"]))


## Roti pembeli yang digambar saat dibungkus (maksimal PACK_BREAD_MAX).
func _pack_count(lane: QueueLane) -> int:
	var c: Customer = sim.customers.customer(lane.service_occupant)
	if c == null or c.held.is_empty():
		return 1
	return clampi(c.held_units(), 1, PACK_BREAD_MAX)


func _build_pack_bag(lane: QueueLane) -> PackBagRig:
	var rig := PackBagRig.new()
	rig.name = "PackBag_%s" % lane.id
	# Mesin kasir berdiri tepat di tengah meja lane; kantong di sampingnya,
	# sedikit ke arah pembeli, dan roti pembeli berjajar di tepi meja.
	var sp: Vector2 = GridMath.cell_center(lane.service_point)
	var cp: Vector2 = GridMath.cell_center(lane.cashier_point)
	var to_customer: Vector2 = (sp - cp).normalized()
	var along := Vector2(to_customer.y, -to_customer.x)
	# Mesin kasir ada di tengah MEJA; pada meja dua ubin (Tier 3-5) titik itu
	# bergeser setengah ubin dari garis lane, dan kantong dulu menembus mesinnya.
	# Meja dua jalur (Tier 1-2): mesin kasir tiap jalur di ubinnya sendiri dan
	# kantong di sisi ubin yang kosong (DecorSlots.lane_frame).
	var anchor: Vector2 = (sp + cp) * 0.5
	var f: FloorDefinition = sim.world.location.floor_def(lane.floor_id)
	if f != null:
		for ld: Dictionary in f.lanes:
			if ld["id"] == lane.id:
				var lf: Dictionary = DecorSlots.lane_frame(f, ld)
				if not lf.is_empty():
					anchor = lf["register"]
					along = lf["bag_side"]
	var pos: Vector2 = anchor + along * PACK_BAG_SIDE + to_customer * 0.04
	rig.position = Vector3(pos.x, EquipmentFactory.COUNTER_HEIGHT, pos.y)
	var profile: String = ""
	var c: Customer = sim.customers.customer(lane.service_occupant)
	if c != null and not c.held.is_empty():
		var st: BreadStack = (c.held[0] as Dictionary)["stack"]
		var r: RecipeDefinition = DataRegistry.recipe(st.recipe_id)
		profile = String(r.visual_profile_id) if r != null else ""
	rig.setup(profile, _pack_count(lane), Vector3(to_customer.x, 0.0, to_customer.y))
	return rig


## Gelembung pikiran pemain saat toko buka tanpa satu pun pelanggan (GDD 31.7):
## tidak ada pembeli di toko dan tidak ada pesanan RotiFood aktif. Waktunya detik
## nyata, berhenti saat pause, dan langsung hilang begitu ada pelanggan.
func _update_thoughts(delta: float) -> void:
	if _thought_bubble == null:
		return
	var quiet: bool = _shop_quiet()
	if not quiet:
		_quiet_real = 0.0
	elif not PauseManager.is_paused():
		_quiet_real += delta
	var key: String = ThoughtBubble.key_for(_quiet_real) if quiet else ""
	var pv: ActorView = views.get(sim.player.actor.id)
	if key == "" or pv == null or not pv.visible or decoration_mode:
		_thought_bubble.hide_bubble()
		return
	_thought_bubble.show_key(key)
	_thought_bubble.point_at(camera_rig.world_to_screen(pv.global_position + Vector3(0.0, pv.head_top() + THOUGHT_ANCHOR_GAP, 0.0)))


func quiet_seconds() -> float:
	return _quiet_real


## Celetukan pengunjung lihat-lihat (GDD 20.12, 127.19): satu kalimat lucu per
## orang, tampil sejak tatapan terakhirnya sampai ia keluar pintu. Murni
## presentasi; tidak menangkap ketukan dan disembunyikan di Decoration Mode atau
## bila ia di lantai lain.
func _update_shopper_lines() -> void:
	var live: Dictionary = {}
	if not decoration_mode:
		for c: Customer in sim.customers.sorted():
			if not shopper_speaking(c):
				continue
			var v: ActorView = views.get(c.id)
			if v == null or not v.visible:
				continue
			live[c.id] = true
			var b: ThoughtBubble = _shopper_bubbles.get(c.id)
			if b == null:
				b = ThoughtBubble.new()
				b.name = "ShopperLine"
				_thought_layer.add_child(b)
				_shopper_bubbles[c.id] = b
			b.show_key(shopper_line_key(c))
			b.point_at(camera_rig.world_to_screen(v.global_position + Vector3(0.0, v.head_top() + THOUGHT_ANCHOR_GAP, 0.0)))
	for id: Variant in _shopper_bubbles.keys():
		if not live.has(id):
			(_shopper_bubbles[id] as ThoughtBubble).queue_free()
			_shopper_bubbles.erase(id)


## Ia berceletuk pada tatapan terakhirnya dan selama berjalan pulang.
static func shopper_speaking(c: Customer) -> bool:
	return c.window_shopper and ((c.state == Customer.BROWSING and c.looks_left <= 1) or c.state == Customer.LEAVING)


## Kalimatnya diturunkan dari visual_seed (kosmetik), jadi tetap sama setelah load.
static func shopper_line_key(c: Customer) -> String:
	var lines: Array[String] = DataRegistry.WINDOW_SHOPPER_LINES
	return lines[posmod(c.actor.visual_seed, lines.size())]


func shopper_bubble(customer_id: StringName) -> ThoughtBubble:
	return _shopper_bubbles.get(customer_id)


## Toko buka tanpa pembeli di dalam dan tanpa pesanan RotiFood aktif (GDD 31.7).
func _shop_quiet() -> bool:
	return sim.time.is_open() and sim.customers.customers.is_empty() and sim.rotifood.active_orders().is_empty()


## Pemain tidak tertidur saat gelembung pikiran tampil, dan selama toko sepi baru
## boleh tertidur saat gelembung pikiran terakhir hilang (GDD 31.6, 31.7). Yang
## sudah tertidur sejak persiapan terbangun begitu toko buka dan sepi, lalu
## rangkaian pikirannya berjalan lebih dulu.
func _player_doze_blocked() -> bool:
	if _thought_bubble != null and _thought_bubble.is_showing():
		return true
	if not _shop_quiet():
		return false
	return _quiet_real < DataRegistry.player_doze_after_seconds()


func thought_bubble() -> ThoughtBubble:
	return _thought_bubble


func _update_markers() -> void:
	# Decoration Mode: penanda "!" dan bar progres hanya menutupi perabot yang ditata.
	if decoration_mode:
		for m0: Variant in markers.values():
			(m0 as StationMarker).hide_marker()
		return
	var data: Dictionary = sim.player.station_markers()
	var hc: bool = SettingsManager.get_bool("high_contrast_markers")
	# Maks. alert dunia yang tampil (GDD 129): alert (terbakar lebih dulu)
	# didahulukan daripada bar progres; urutan stabil menurut iid.
	var order: Array = data.keys()
	order.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: Dictionary = data[a]
		var db: Dictionary = data[b]
		var ra: int = 0 if da["mode"] != &"progress" else 1
		var rb: int = 0 if db["mode"] != &"progress" else 1
		if ra != rb:
			return ra < rb
		if float(da.get("burn", 0.0)) != float(db.get("burn", 0.0)):
			return float(da.get("burn", 0.0)) > float(db.get("burn", 0.0))
		return int(a) < int(b))
	var shown: Dictionary = {}
	for i in mini(order.size(), DataRegistry.bali("limits.world_alerts_visible")):
		shown[order[i]] = true
	for iid: Variant in markers.keys():
		var m: StationMarker = markers[iid]
		m.set_high_contrast(hc)
		var md: Variant = data.get(iid)
		if md == null or not shown.has(iid):
			m.hide_marker()
		elif (md as Dictionary)["mode"] == &"progress":
			m.show_progress(float((md as Dictionary)["value"]))
		else:
			m.show_alert(float((md as Dictionary)["burn"]))


func _update_bread() -> void:
	for iid: Variant in furniture.keys():
		var e: EquipmentInstance = sim.equipment.get_inst(int(iid))
		if e == null or e.category() != &"display":
			continue
		var sig: String = _display_signature(e.iid)
		if _bread_sig.get(e.iid, "") == sig:
			continue
		_bread_sig[e.iid] = sig
		var node: Node3D = furniture[iid]
		var slots: Array = sim.display.slots(e.iid)
		for i in slots.size():
			var slot_node: Node3D = node.find_child("Slot%d" % i, true, false) as Node3D
			if slot_node == null:
				continue
			for c: Node in slot_node.get_children():
				c.queue_free()
			var s: Dictionary = slots[i]
			var units: int = sim.display.slot_units(e.iid, i)
			if units <= 0 or s["recipe"] == &"":
				continue
			var r: RecipeDefinition = DataRegistry.recipe(s["recipe"])
			var first: BreadStack = (s["stacks"] as Array)[0]
			var n: int = mini(MAX_BREAD_PER_SLOT, int(ceil(float(units) / 4.0)))
			for k in n:
				var b: Node3D = BreadFactory.build_cached(String(r.visual_profile_id), first.bake_quality, first.freshness_state)
				b.scale = Vector3(0.45, 0.45, 0.45)
				b.position = Vector3((float(k) - float(n - 1) * 0.5) * 0.06, 0.0, float(k % 2) * 0.03)
				slot_node.add_child(b)


## Isi Meja Tunggu (GDD 5.1.3): mangkuk adonan dan loyang di atas daun meja,
## maksimal `limits.table_items_visible`. Adonan memucat kehijauan dan roti
## memakai tampilan kesegarannya saat mendekati basi.
func _update_table() -> void:
	var table: EquipmentInstance = sim.equipment.table_instance()
	if table == null or not furniture.has(table.iid):
		return
	var items: Array[ProductionJob] = sim.production.table_jobs()
	var shown: int = mini(items.size(), DataRegistry.bali("limits.table_items_visible"))
	var parts: PackedStringArray = PackedStringArray([str(table.iid)])
	for i in shown:
		var j: ProductionJob = items[i]
		parts.append("%d:%s:%s" % [j.job_id, j.stage, BreadStack.state_for_ratio(sim.production.table_spoil_ratio(j))])
	var sig: String = ",".join(parts)
	if sig == _table_sig:
		return
	_table_sig = sig
	var top: Node3D = (furniture[table.iid] as Node3D).find_child("Top", true, false) as Node3D
	if top == null:
		return
	for c: Node in top.get_children():
		c.queue_free()
	for i2 in shown:
		var j2: ProductionJob = items[i2]
		var state: StringName = BreadStack.state_for_ratio(sim.production.table_spoil_ratio(j2))
		var item: Node3D
		if j2.stage == ProductionJob.DOUGH_ON_TABLE:
			var stale: float = 0.0 if state == &"FRESH" else (0.45 if state == &"GOOD" else 1.0)
			item = EquipmentFactory.dough_bowl(Palette.RAW_DOUGH.lerp(TABLE_DOUGH_STALE, stale))
		else:
			item = EquipmentFactory.bread_tray(String(j2.recipe().visual_profile_id), j2.bake_quality, state)
		item.scale = Vector3(TABLE_ITEM_SCALE, TABLE_ITEM_SCALE, TABLE_ITEM_SCALE)
		item.position = Vector3((float(i2 % 3) - 1.0) * 0.30, 0.0, (floorf(float(i2) / 3.0) - 0.5) * 0.20)
		top.add_child(item)


func _display_signature(iid: int) -> String:
	var parts: PackedStringArray = PackedStringArray()
	var slots: Array = sim.display.slots(iid)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var st: String = ""
		if not (s["stacks"] as Array).is_empty():
			st = String(((s["stacks"] as Array)[0] as BreadStack).freshness_state)
		parts.append("%s:%d:%s" % [s["recipe"], mini(MAX_BREAD_PER_SLOT, int(ceil(float(sim.display.slot_units(iid, i)) / 4.0))), st])
	return ",".join(parts)


func _animate_stations(_delta: float) -> void:
	for iid: Variant in furniture.keys():
		var e: EquipmentInstance = sim.equipment.get_inst(int(iid))
		if e == null or e.job_id < 0:
			if _smoke.has(iid):
				var gone: Variant = _smoke[iid]
				if gone is Node and is_instance_valid(gone):
					(gone as Node).queue_free()
				_smoke.erase(iid)
			continue
		var j: ProductionJob = sim.production.get_job(e.job_id)
		if j == null:
			continue
		var node: Node3D = furniture[iid]
		if e.category() == &"mixer" and j.stage == ProductionJob.MIXING and not PauseManager.is_paused():
			ProceduralAnimationSystem.mixer_spin(node, _t)
		if e.category() == &"oven":
			var burning: bool = j.stage == ProductionJob.OVERBAKING or j.stage == ProductionJob.BURNT
			if burning and not _smoke.has(iid):
				var parent: Node3D = floors.get(e.floor_id)
				# Di batas partikel (GDD 129) efek dilewati dan dicoba lagi nanti.
				var fx: CPUParticles3D = FX.burn_smoke(parent, node.position + Vector3(0.0, e.def().height_m, 0.0))
				if fx != null:
					_smoke[iid] = fx
			elif not burning and _smoke.has(iid):
				var old_fx: Variant = _smoke[iid]
				if old_fx is Node and is_instance_valid(old_fx):
					(old_fx as Node).queue_free()
				_smoke.erase(iid)


# ===========================================================================
# EVENT VISUAL
# ===========================================================================

func _on_camera_floor_changed(_floor_id: StringName) -> void:
	_apply_floor_visibility()


func _apply_floor_visibility() -> void:
	for fid: Variant in floors.keys():
		(floors[fid] as Node3D).visible = StringName(str(fid)) == camera_rig.active_floor
	if _slot_markers != null:
		_slot_markers.visible = camera_rig.active_floor == sim.world.location.store_floor()


func _on_storage_door(iid: int, open: bool) -> void:
	var node: Node3D = furniture.get(iid)
	if node != null:
		ProceduralAnimationSystem.storage_door_hold(node, open)


func _on_sale(_amount: float, channel: StringName) -> void:
	if channel == &"physical" and sim.bailout.solo_mode:
		var pv: ActorView = views.get(sim.player.actor.id)
		if pv != null:
			pv.sparkle()


func _apply_weather() -> void:
	if _rain != null and is_instance_valid(_rain):
		_rain.queue_free()
		_rain = null
	if sim.weather.is_rain():
		_rain = FX.rain_overlay(_rain_layer)
	AudioManager.set_ambience(ambience_for(sim.weather.is_rain()))


## Lapisan ambience untuk cuaca hari ini (juga disiapkan di layar loading).
static func ambience_for(rain: bool) -> Array[StringName]:
	var ids: Array[StringName] = [&"rain_loop" if rain else &"sunny_ambience", &"shop_ambience_room"]
	return ids


func _apply_brightness() -> void:
	if _env == null or _env.environment == null:
		return
	var b: float = float(SettingsManager.get_int("brightness")) / 100.0
	_env.environment.adjustment_enabled = true
	_env.environment.adjustment_brightness = b * (0.82 if sim.weather.is_rain() else 1.0)


# ===========================================================================
# PICKING (GDD 12.4: perabot adalah tombolnya sendiri)
# ===========================================================================

## {kind, iid, lane, customer, cell, floor}; kind: equipment/cashier/tablet/
## customer/portal/cell/none.
func pick(screen_pos: Vector2) -> Dictionary:
	var floor_id: StringName = camera_rig.active_floor
	# 1. Balon "!" pembeli terdepan.
	for c: Customer in sim.customers.sorted():
		if not c.awaiting_tap or c.actor.floor_id != floor_id:
			continue
		var head: Vector2 = camera_rig.world_to_screen(_v3(c.actor.pos) + Vector3(0.0, 1.1, 0.0))
		if head.distance_to(screen_pos) <= PICK_CUSTOMER_PX:
			return {"kind": &"customer", "customer": c.id, "floor": floor_id}
	var from: Vector3 = camera_rig.camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera_rig.camera.project_ray_normal(screen_pos)
	var best_d: float = INF
	var best: Dictionary = {}
	for iid: Variant in _aabbs.keys():
		var ad: Dictionary = _aabbs[iid]
		if StringName(str(ad["floor"])) != floor_id:
			continue
		var hit: Variant = (ad["aabb"] as AABB).grow(0.03).intersects_ray(from, dir)
		if hit != null:
			var d: float = from.distance_to(hit)
			if d < best_d:
				best_d = d
				best = {"kind": &"equipment", "iid": int(iid), "floor": floor_id}
	for cd: Dictionary in _counter_aabbs:
		if StringName(str(cd["floor"])) != floor_id:
			continue
		var hit2: Variant = (cd["aabb"] as AABB).intersects_ray(from, dir)
		if hit2 != null:
			var d2: float = from.distance_to(hit2)
			if d2 < best_d:
				best_d = d2
				best = _counter_pick(cd, floor_id)
	# Decoration Mode: dekorasi berdiri (dinding, meja, lantai) juga tombolnya sendiri.
	if decoration_mode:
		for uid: Variant in _decor.keys():
			var dd: Dictionary = _decor[uid]
			if StringName(str(dd["floor"])) != floor_id or dd["type"] == &"floor_overlay":
				continue
			var hit3: Variant = (dd["aabb"] as AABB).grow(0.03).intersects_ray(from, dir)
			if hit3 != null:
				var d3: float = from.distance_to(hit3)
				if d3 < best_d:
					best_d = d3
					best = {"kind": &"decor", "uid": int(uid), "floor": floor_id}
	if not best.is_empty():
		return best
	var g: Vector3 = camera_rig.screen_to_ground(screen_pos)
	if is_inf(g.x):
		return {"kind": &"none"}
	var cell: Vector2i = GridMath.world_to_cell(Vector2(g.x, g.z))
	var fg: FloorGrid = sim.world.grid(floor_id)
	if fg != null and fg.in_bounds(cell):
		# Karpet: ubin di bawah jari (bersama "cell", karena ubinnya tetap sasaran).
		var rug: int = rug_at(floor_id, cell) if decoration_mode else -1
		if rug >= 0:
			return {"kind": &"decor", "uid": rug, "floor": floor_id, "cell": cell}
		if fg.access_at.has(cell):
			return {"kind": &"equipment", "iid": int(fg.access_at[cell]), "floor": floor_id, "cell": cell}
		for lane: QueueLane in sim.queue.lanes:
			if lane.floor_id == floor_id and (cell == lane.cashier_point or cell == lane.service_point):
				return {"kind": &"cashier", "lane": lane.id, "floor": floor_id}
	return {"kind": &"cell", "cell": cell, "floor": floor_id}


func _counter_pick(cd: Dictionary, floor_id: StringName) -> Dictionary:
	var n: String = str(cd["name"])
	if n == "Tablet":
		return {"kind": &"tablet", "floor": floor_id}
	if n == "Portal":
		return {"kind": &"portal", "floor": floor_id}
	var cid: StringName = StringName(str(cd["counter_id"]))
	if cid == &"counter_rotifood":
		return {"kind": &"tablet", "floor": floor_id}
	for lane: QueueLane in sim.queue.lanes:
		if lane.counter_id == cid and lane.floor_id == floor_id:
			return {"kind": &"cashier", "lane": lane.id, "floor": floor_id}
	return {"kind": &"none"}


func cell_at_screen(screen_pos: Vector2) -> Vector2i:
	var g: Vector3 = camera_rig.screen_to_ground(screen_pos)
	if is_inf(g.x):
		return Vector2i(-1, -1)
	return GridMath.world_to_cell(Vector2(g.x, g.z))


## Titik tengah puncak perabot di dunia, atau Vector3.INF bila tidak digambar.
func top_of_iid(iid: int) -> Vector3:
	if lifted_iid() == iid:
		return hold_top()
	var ad: Variant = _aabbs.get(iid)
	if not (ad is Dictionary):
		return Vector3.INF
	var b: AABB = (ad as Dictionary)["aabb"]
	var c: Vector3 = b.get_center()
	return Vector3(c.x, b.end.y, c.z)


# ===========================================================================
# PEGANGAN DECORATION MODE (GDD 72.2)
# ===========================================================================

## Pegang barang (seperti The Sims): modelnya terangkat, mengambang pelan, dan
## digambar di posisi calon `h` = {kind, id, floor, cell, rot, slot}. Simulasi
## tidak berubah; release_hold() mengembalikan modelnya ke tempat tersimpan.
## Barang yang belum terpasang memakai model sementara. Dekorasi dinding/meja
## tanpa slot (`slot` < 0) dan alat/dekorasi lantai tanpa ubin (`cell.x` < 0)
## belum digambar.
func hold(h: Dictionary) -> void:
	if not _hold.is_empty() and (_hold["kind"] != h["kind"] or int(_hold["id"]) != int(h["id"])):
		release_hold()
	_hold = h.duplicate()
	_apply_hold()


## Lepaskan pegangan tanpa menaruh: model sementara dibuang, model asli kembali
## ke posisi yang tersimpan di simulasi.
func release_hold() -> void:
	if _hold.is_empty():
		return
	var h: Dictionary = _hold
	_hold = {}
	var node: Node3D = _hold_node if is_instance_valid(_hold_node) else null
	_hold_node = null
	if node == null:
		_hold_temp = false
		return
	if _hold_temp:
		_hold_temp = false
		node.queue_free()
		return
	node.visible = true
	var id: int = int(h["id"])
	if h["kind"] == &"equipment":
		var e: EquipmentInstance = sim.equipment.get_inst(id)
		var parent: Node3D = floors.get(e.floor_id) if e != null else null
		if e == null or not e.placed or parent == null:
			return
		_reparent(node, parent)
		_pose_furniture(node, e.def(), e.anchor, e.rotation)
		_aabbs[id] = {"floor": e.floor_id, "aabb": _world_aabb(node)}
	else:
		var o: Dictionary = sim.decoration.item(id)
		var dd: Variant = _decor.get(id)
		var xf: Variant = DecorSlots.transform_of(sim.world.location, sim.decoration.def_of(o), o) if not o.is_empty() else null
		if not (dd is Dictionary) or xf == null:
			return
		node.transform = xf
		(dd as Dictionary)["base"] = node.position
		(dd as Dictionary)["aabb"] = node.transform * EquipmentFactory._mesh_bounds(node)


## Pegangan yang sedang berlaku (salinan), atau {} bila tidak ada.
func held() -> Dictionary:
	return _hold.duplicate()


## Alat yang sedang dipegang, atau -1.
func lifted_iid() -> int:
	return int(_hold["id"]) if not _hold.is_empty() and _hold["kind"] == &"equipment" else -1


## Dekorasi yang sedang dipegang, atau -1.
func lifted_decor() -> int:
	return int(_hold["id"]) if not _hold.is_empty() and _hold["kind"] == &"decor" else -1


## Node model barang yang dipegang (asli atau sementara), atau null.
func hold_node() -> Node3D:
	return _hold_node if is_instance_valid(_hold_node) else null


## Pasang ulang pegangan pada model saat ini. Dipanggil juga sesudah setiap
## pembangunan ulang dunia, yang mengganti node perabot & dekorasi.
func _apply_hold() -> void:
	if _hold.is_empty():
		return
	var parent: Node3D = floors.get(StringName(str(_hold["floor"])))
	var node: Node3D = _hold_model()
	if node == null:
		return
	if parent == null:
		node.visible = false
		return
	_reparent(node, parent)
	var id: int = int(_hold["id"])
	var cell: Vector2i = _hold["cell"]
	if _hold["kind"] == &"equipment":
		var e: EquipmentInstance = sim.equipment.get_inst(id)
		node.visible = cell.x >= 0
		_pose_furniture(node, e.def(), cell, int(_hold["rot"]))
		_hold_base = node.position
		_hold_aabb = _world_aabb(node)
		if not _hold_temp:
			_aabbs[id] = {"floor": StringName(str(_hold["floor"])), "aabb": _hold_aabb}
	else:
		var def: MiscDefinitions.DecorationDefinition = sim.decoration.def_of(sim.decoration.item(id))
		var cand: Dictionary = {"slot": int(_hold["slot"]), "cell": [cell.x, cell.y], "rot": int(_hold["rot"])}
		var xf: Variant = DecorSlots.transform_of(sim.world.location, def, cand)
		var on_slot: bool = def.placement_type == &"wall" or def.placement_type == &"counter_prop"
		var shown: bool = xf != null and (on_slot or cell.x >= 0)
		node.visible = shown
		if shown:
			node.transform = xf
		_hold_base = node.position
		_hold_aabb = node.transform * EquipmentFactory._mesh_bounds(node)
		var dd: Variant = _decor.get(id)
		if not _hold_temp and dd is Dictionary:
			(dd as Dictionary)["base"] = _hold_base
			(dd as Dictionary)["aabb"] = _hold_aabb
	_animate_lift()


## Model untuk barang yang dipegang: model aslinya bila terpasang, selain itu
## model sementara yang dibuat sekali selama pegangan berlangsung.
func _hold_model() -> Node3D:
	var id: int = int(_hold["id"])
	var real: Node3D = null
	if _hold["kind"] == &"equipment":
		real = furniture.get(id)
	else:
		var dd: Variant = _decor.get(id)
		if dd is Dictionary:
			real = (dd as Dictionary)["node"] as Node3D
	if real != null and is_instance_valid(real):
		if _hold_temp and is_instance_valid(_hold_node):
			_hold_node.queue_free()
		_hold_node = real
		_hold_temp = false
		return real
	if _hold_temp and is_instance_valid(_hold_node):
		return _hold_node
	if _hold["kind"] == &"equipment":
		var e: EquipmentInstance = sim.equipment.get_inst(id)
		if e == null:
			return null
		_hold_node = _equipment_model(e)
	else:
		var o: Dictionary = sim.decoration.item(id)
		if o.is_empty():
			return null
		_hold_node = DecorFactory.build_cached(StringName(str(o["deco_id"])))
		var sw: Node3D = _hold_node.find_child(DecorFactory.SWING_NODE, true, false) as Node3D
		if sw != null:
			_swing.append(sw)
	_hold_node.name = "Held_%s_%d" % [_hold["kind"], id]
	_hold_temp = true
	return _hold_node


static func _reparent(node: Node3D, parent: Node3D) -> void:
	var old: Node = node.get_parent()
	if old == parent:
		return
	if old != null:
		old.remove_child(node)
	parent.add_child(node)


## Titik tengah puncak model yang dipegang (ikut terangkat), atau Vector3.INF
## bila tidak ada pegangan atau modelnya tidak digambar di lantai yang dilihat.
## Toolbar aksi Decoration Mode menunjuk ke titik ini.
func hold_top() -> Vector3:
	var node: Node3D = hold_node()
	if node == null or not node.visible or StringName(str(_hold["floor"])) != camera_rig.active_floor:
		return Vector3.INF
	var c: Vector3 = _hold_aabb.get_center()
	return Vector3(c.x, _hold_aabb.end.y + _lift_height(), c.z)


## Seberapa tinggi barang yang dipegang terangkat: karpet hanya sedikit.
func _lift_height() -> float:
	if _hold.is_empty():
		return 0.0
	if _hold["kind"] == &"decor" and sim.decoration.type_of(sim.decoration.item(int(_hold["id"]))) == &"floor_overlay":
		return RUG_LIFT_M
	return LIFT_M


## Ubin lantai yang ditempati barang yang dipegang di posisi calonnya (kosong
## untuk dekorasi dinding/meja).
func hold_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if _hold.is_empty():
		return out
	var cell: Vector2i = _hold["cell"]
	if cell.x < 0:
		return out
	var id: int = int(_hold["id"])
	if _hold["kind"] == &"equipment":
		var e: EquipmentInstance = sim.equipment.get_inst(id)
		return GridMath.footprint_cells(cell, e.def().footprint_tiles, int(_hold["rot"])) if e != null else out
	var o: Dictionary = sim.decoration.item(id)
	match sim.decoration.type_of(o):
		&"floor_prop":
			out.append(cell)
		&"floor_overlay":
			return DecorSlots.overlay_cells(sim.decoration.def_of(o), cell, int(_hold["rot"]))
	return out


## true bila titik layar mengenai barang yang dipegang: badan modelnya, atau
## ubin jejaknya di lantai. Drag yang dimulai di sini menyeret barang itu.
func hold_hit(screen_pos: Vector2) -> bool:
	var node: Node3D = hold_node()
	if node == null or not node.visible or StringName(str(_hold["floor"])) != camera_rig.active_floor:
		return false
	var from: Vector3 = camera_rig.camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera_rig.camera.project_ray_normal(screen_pos)
	var box: AABB = _hold_aabb
	box.size.y += _lift_height()
	if box.grow(0.05).intersects_ray(from, dir) != null:
		return true
	return hold_cells().has(cell_at_screen(screen_pos))


func _animate_lift() -> void:
	var node: Node3D = hold_node()
	if node == null:
		return
	var lift: float = _lift_height()
	var bob: float = 0.0 if SettingsManager.reduced_motion() or lift < LIFT_M else LIFT_BOB_M * sin(_t * 5.0)
	node.position = _hold_base + Vector3(0.0, lift + bob, 0.0)


## Karpet terpasang yang jejaknya menutupi `cell`, atau -1.
func rug_at(floor_id: StringName, cell: Vector2i) -> int:
	for uid: Variant in _decor.keys():
		var dd: Dictionary = _decor[uid]
		if dd["type"] != &"floor_overlay" or StringName(str(dd["floor"])) != floor_id:
			continue
		if sim.decoration.overlay_cells(sim.decoration.item(int(uid))).has(cell):
			return int(uid)
	return -1


## Titik tengah puncak dekorasi terpasang, atau Vector3.INF bila tidak digambar.
func top_of_decor(uid: int) -> Vector3:
	if lifted_decor() == uid:
		return hold_top()
	var dd: Variant = _decor.get(uid)
	if not (dd is Dictionary):
		return Vector3.INF
	var b: AABB = (dd as Dictionary)["aabb"]
	var c: Vector3 = b.get_center()
	return Vector3(c.x, b.end.y, c.z)


func decor_node(uid: int) -> Node3D:
	var dd: Variant = _decor.get(uid)
	return (dd as Dictionary)["node"] as Node3D if dd is Dictionary else null


func _animate_swing() -> void:
	var a: float = 0.0 if SettingsManager.reduced_motion() else sin(_t * SWING_SPEED) * SWING_ANGLE
	for p: Node3D in _swing + _room_swing:
		if is_instance_valid(p):
			p.rotation.z = a


## Decoration Mode (GDD 72.3): tandai slot dinding/meja `indexes`; `current`
## (slot barang terpilih) disorot emas. Penanda berdenyut pelan kecuali Reduced
## Motion.
func show_slot_markers(placement_type: StringName, indexes: Array[int], current: int) -> void:
	clear_slot_markers()
	var list: Array[Dictionary] = DecorSlots.slots(sim.world.location, placement_type)
	for i: int in indexes:
		if i < 0 or i >= list.size():
			continue
		var sd: Dictionary = list[i]
		var mi: MeshInstance3D = DecorFactory.slot_marker(placement_type, i == current)
		mi.name = "Slot%d" % i
		_slot_markers.add_child(mi)
		mi.transform = Transform3D(Basis(Vector3.UP, float(sd["yaw"])), sd["pos"])
		_slot_marker_list.append({"index": i, "node": mi, "aabb": mi.transform * mi.get_aabb(), "pos": sd["pos"]})
		if not SettingsManager.reduced_motion():
			var tw := mi.create_tween().set_loops()
			tw.tween_property(mi, "scale", Vector3(1.08, 1.08, 1.08), 0.55)
			tw.tween_property(mi, "scale", Vector3.ONE, 0.55)
	_apply_floor_visibility()


func clear_slot_markers() -> void:
	for c: Node in _slot_markers.get_children():
		c.queue_free()
	_slot_marker_list.clear()


func slot_marker_count() -> int:
	return _slot_marker_list.size()


## Slot yang ditandai di bawah titik layar: kotak penanda yang ditembus sinar
## lebih dulu, lalu penanda terdekat dalam PICK_SLOT_PX. -1 bila tidak ada.
func slot_at_screen(screen_pos: Vector2) -> int:
	if _slot_marker_list.is_empty() or not _slot_markers.visible:
		return -1
	var from: Vector3 = camera_rig.camera.project_ray_origin(screen_pos)
	var dir: Vector3 = camera_rig.camera.project_ray_normal(screen_pos)
	var best: int = -1
	var best_d: float = INF
	for m: Dictionary in _slot_marker_list:
		var hit: Variant = (m["aabb"] as AABB).grow(0.05).intersects_ray(from, dir)
		if hit != null and from.distance_to(hit) < best_d:
			best_d = from.distance_to(hit)
			best = int(m["index"])
	if best >= 0:
		return best
	var best_px: float = PICK_SLOT_PX
	for m2: Dictionary in _slot_marker_list:
		var px: float = camera_rig.world_to_screen(m2["pos"]).distance_to(screen_pos)
		if px <= best_px:
			best_px = px
			best = int(m2["index"])
	return best


## Titik layar pusat penanda slot `index` (untuk tes dan tutorial), atau (-1, -1).
func slot_screen_pos(index: int) -> Vector2:
	for m: Dictionary in _slot_marker_list:
		if int(m["index"]) == index:
			return camera_rig.world_to_screen(m["pos"])
	return Vector2(-1, -1)


func screen_of_iid(iid: int) -> Vector2:
	var node: Node3D = furniture.get(iid)
	if node == null:
		return Vector2(-1, -1)
	return camera_rig.world_to_screen(node.global_position + Vector3(0.0, 0.6, 0.0))


# ===========================================================================
# SOROTAN TUTORIAL & PRATINJAU PENEMPATAN
# ===========================================================================

func highlight(kind: StringName, iid: int) -> void:
	if _highlight != null and is_instance_valid(_highlight):
		_highlight.queue_free()
	_highlight = null
	var pos := Vector3.INF
	var floor_id: StringName = &""
	if iid >= 0 and furniture.has(iid):
		var e: EquipmentInstance = sim.equipment.get_inst(iid)
		pos = (furniture[iid] as Node3D).position
		floor_id = e.floor_id
	elif kind == &"cashier" or kind == &"tablet":
		var lane: QueueLane = sim.queue.main_lane()
		pos = GridMath.cell_center3(lane.cashier_point)
		floor_id = lane.floor_id
	if pos == Vector3.INF or not floors.has(floor_id):
		return
	_highlight = ProceduralMeshFactory.torus(0.30, 0.36, Palette.GOLD_STAR)
	(floors[floor_id] as Node3D).add_child(_highlight)
	_highlight.position = Vector3(pos.x, 0.02, pos.z)
	if not SettingsManager.reduced_motion():
		var tw := _highlight.create_tween().set_loops()
		tw.tween_property(_highlight, "scale", Vector3(1.25, 1.0, 1.25), 0.6)
		tw.tween_property(_highlight, "scale", Vector3.ONE, 0.6)


func show_ghost(cells: Array[Vector2i], floor_id: StringName, valid: bool) -> void:
	clear_ghost()
	var parent: Node3D = floors.get(floor_id)
	if parent == null:
		return
	for c: Vector2i in cells:
		var g: Node3D = ghost_tile(valid)
		_ghosts.add_child(g)
		g.global_position = GridMath.cell_center3(c, 0.03)


## Satu ubin jejak penempatan: putih tembus bila sah, merah bersilang bila tidak
## (tanda silang: status tidak bergantung warna saja, GDD 44.2). Mesh dan
## materialnya dipakai bersama, dan shadernya sama dengan arsiran ubin, jadi
## memindah pratinjau tidak pernah memicu kompilasi shader baru (MaterialKeep).
static func ghost_tile(valid: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Ghost"
	var q := MeshInstance3D.new()
	q.mesh = ProceduralMeshFactory.shared_box(Vector3(0.46, 0.02, 0.46))
	q.material_override = ProceduralMeshFactory.tint_material(Color(Palette.FLOUR_WHITE if valid else Palette.DANGER, 0.55))
	q.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(q)
	if not valid:
		for s: float in [45.0, -45.0]:
			var x := MeshInstance3D.new()
			x.mesh = ProceduralMeshFactory.shared_box(Vector3(0.40, 0.03, 0.06))
			x.material_override = ProceduralMeshFactory.tint_material(Palette.DANGER)
			x.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			x.position = Vector3(0.0, 0.02, 0.0)
			x.rotation_degrees = Vector3(0.0, s, 0.0)
			root.add_child(x)
	return root


## Decoration Mode: tandai ubin yang harus tetap kosong (arsiran merah) dan,
## bila ada perabot terpilih, ubin di luar area perabot itu (abu-abu bertitik).
func show_tile_overlay(clear_cells: Array[Vector2i], wrong_zone_cells: Array[Vector2i]) -> void:
	clear_tile_overlay()
	_tile_overlay.add_child(ProceduralMeshFactory.tile_overlay(clear_cells, Color(Palette.DANGER, 0.20), Color(Palette.DANGER, 0.70), &"stripes"))
	if not wrong_zone_cells.is_empty():
		_tile_overlay.add_child(ProceduralMeshFactory.tile_overlay(wrong_zone_cells, Color(Palette.TEXT_MUTED, 0.22), Color(Palette.TEXT_MUTED, 0.55), &"dot"))


func clear_tile_overlay() -> void:
	for c: Node in _tile_overlay.get_children():
		c.queue_free()


func clear_ghost() -> void:
	for c: Node in _ghosts.get_children():
		c.queue_free()
