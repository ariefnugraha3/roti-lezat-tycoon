class_name MovingDay
extends Node3D
## Cutscene pindah lokasi (GDD idle §20 no. 70; arah cutscene v3.1 §45): truk
## bak kayu dengan sopirnya sendiri berhenti di jalan depan toko, pemilik dan
## staf mengangkut perabot di atas kepala ke bak truk, staf naik ke bak dan
## pemilik ke kursi penumpang, lalu truk berangkat. Truk ikut lalu lintas
## StreetLife sebagai kendaraan tamu: lajurnya tidak memunculkan kendaraan baru,
## kendaraan di belakangnya mengantre, dan truk menjaga jarak dengan kendaraan di
## depannya. Di balik layar krem MovingCutscene menjalankan pindah lokasi
## tepat sekali (`SimulationRoot.upgrade_location`) lalu memanggil `arrive()`:
## truk datang di jalan depan toko baru, kru turun, perabot "melompat" masuk
## lewat pintu dan muncul di tempatnya, kru berbaris di depan toko bersama Pak
## Lurah (kartu ucapan selamat), lalu masuk toko lewat `enter()`.
##
## Murni tontonan seperti StreetLife: boneka ActorView sendiri yang tidak
## didaftarkan ke simulasi, gerak dalam detik nyata, tanpa RNG dan tanpa save.
## Simulasi di-pause selama cutscene (modal pemblokir), jadi rute dalam toko
## dihitung dari WorldManager yang tidak berubah. Perabot memakai prototipe
## yang sudah dipanggang (`WorldView.equipment_model`) dan truk satu material
## MATTE bersama: tidak ada kombinasi shader baru.

## Truk sudah keluar layar: saatnya MovingCutscene menutup layar dan pindah lokasi.
signal departed()
## Kru berbaris di depan toko baru: kartu Pak Lurah.
signal greeting()
## Kru sudah masuk toko.
signal finished()

enum Phase { PACK, DEPART, GONE, ARRIVE, GREET, ENTER, DONE, LEFTOVER }

## Kecepatan jalan kru (m/s nyata), lebih cepat dari jalan biasa supaya ringkas;
## di toko yang lebih luas dari toko Tier 1 (diagonal WALK_REF_M) kru berlari
## lebih cepat, sampai WALK_FAST kali.
const WALK_SPEED: float = 3.0
const WALK_REF_M: float = 6.7
const WALK_FAST: float = 1.5
## Truk: kecepatan jelajah, percepatan, dan perlambatan (m/s, m/s²).
const TRUCK_SPEED: float = 8.0
const TRUCK_ACCEL: float = 7.0
const TRUCK_BRAKE: float = 6.0
## Truk datang dari sejauh ini di sisi +x titik berhentinya, dan pergi sampai
## sejauh ini di sisi -x (m).
const TRUCK_IN_FROM: float = 12.0
const TRUCK_OUT_TO: float = 11.0
## Truk diparkir di tepi jalan sisi toko, sejauh ini dari bibir trotoar (m).
const CURB_GAP: float = 0.12
## Tempat parkir per tier lokasi (disetel terhadap NeighborhoodFactory, seperti
## StreetPaths untuk pembeli): `rear` = x ujung belakang truk dikurangi x pintu;
## `via` = titik jalan kru antara garis trotoar dan belakang truk, bebas dari
## lampu, pohon, bangku, dan mobil parkir; `line_z` = garis barisan sambutan di
## depan pintu toko baru (bebas dari pot, papan menu, dan tiang tali); `lurah` =
## sisi barisan tempat Pak Lurah berdiri (+1 = sisi +x pintu). Truk melaju dan
## berhenti di garis z yang sama (tanpa pindah lajur): tepi jalan, atau `z` bila
## diisi (T4: di lajur dekat, karena jalur parkirnya berisi mobil parkir).
## `cab_z` = garis trotoar tempat pemilik berjalan ke pintu penumpang (T3: di
## belakang deret tiang lampu). Opsional:
## `line_x` = geser tengah barisan dari pintu, `gap` = jarak antarkru, dan
## `lurah_at` = tempat Pak Lurah yang tetap (T4: di karpet merah, karena kanopi
## tabebuya menutupi plaza di kiri-kanan barisan dari sudut kamera).
const PARKING: Dictionary = {
	1: {"rear": 0.55, "via": [], "line_z": -0.8, "lurah": -1},
	2: {"rear": 0.55, "via": [], "line_z": -1.33, "lurah": -1},
	3: {"rear": 0.55, "via": [], "line_z": -2.3, "lurah": 1, "cab_z": -3.6},
	4: {"rear": -1.45, "via": [Vector2(1.0, -6.0)], "line_z": -3.6, "lurah": 1, "line_x": 2.5, "gap": 0.52, "z": -9.8,
		"lurah_at": Vector2(1.4, -1.5)},
	5: {"rear": -1.0, "via": [Vector2(2.6, -4.6), Vector2(2.5, -8.7)], "line_z": -2.6, "lurah": 1},
}
## Lama mengangkat satu perabot, menghilang di tangga untuk mengambil perabot
## lantai atas, jeda antarbarang saat menurunkan, dan lompatan naik/turun truk.
const PICK_SECONDS: float = 0.26
const FETCH_SECONDS: float = 0.6
const UNLOAD_EACH: float = 0.12
const HOP_SECONDS: float = 0.42
const HOP_ARC: float = 0.45
## Perabot yang diangkut: sisi telapak terbesar dan tinggi maksimal (m).
const ITEM_SIZE: float = 0.5
const ITEM_HEIGHT: float = 0.42
## Tumpukan yang terlihat di atas kepala paling banyak sekian barang.
const STACK_VISIBLE: int = 4
## Batas fase angkut (detik nyata): sesudahnya sisa kru langsung naik truk.
const PACK_LIMIT: float = 16.0
## Tempat barang di bak (x lokal, z lokal), diisi berlapis.
const CARGO_SLOTS: Array[Vector2] = [Vector2(-0.33, -0.5), Vector2(0.33, -0.5), Vector2(-0.33, 0.0), Vector2(0.33, 0.0),
	Vector2(-0.33, 0.48), Vector2(0.33, 0.48)]
## Tempat berdiri staf di bak (x lokal, z lokal).
const RIDER_SLOTS: Array[Vector2] = [Vector2(-0.34, 1.05), Vector2(0.34, 1.05), Vector2(-0.34, 1.55), Vector2(0.34, 1.55)]
## Tempat kru menurunkan barang di belakang truk (dx, dz dari ujung belakangnya).
const UNLOAD_SPOTS: Array[Vector2] = [Vector2(0.55, 0.3), Vector2(0.55, -0.3), Vector2(1.0, 0.55), Vector2(1.0, 0.0), Vector2(1.0, -0.55)]
## Rupa sopir truk: pembeli biasa berbenih tetap, bertopi pet dan berkemeja biru.
const DRIVER_SEED: int = 7031
const DRIVER_SHIRT: Color = Palette.SIGN_BLUE
## Setelah cutscene, truk dibebaskan sejauh ini di sisi -x titik berhentinya (m).
const TRUCK_GONE_AT: float = 18.0
## Jarak antarkru saat berbaris di depan toko baru (m).
const LINE_GAP: float = 0.62
## Lebar pandang kamera cutscene (m) paling kecil dan paling besar.
const VIEW_MIN: float = 6.8
const VIEW_MAX: float = 15.0
## Ruang layar (px logis) yang dibiarkan kosong di atas (tombol Skip) dan di
## bawah (kartu Pak Lurah saat berbaris).
const VIEW_TOP_PX: float = 150.0
const VIEW_BOTTOM_PX: float = 90.0
const VIEW_CARD_PX: float = 470.0

var sim: SimulationRoot = null
var view: WorldView = null
var phase: int = Phase.PACK
var truck: Node3D = null
## Sopir truk (boneka sendiri), di kursi kanan sepanjang cutscene.
var driver: ActorView = null
var lurah: ActorView = null
## Kru: [{id, view, actor, steps, t, mode, hidden, slot, cab, stack, items,
## hop, path, wp, wave}]. Pemilik selalu yang pertama dan duduk di kabin (`cab`).
var crew: Array[Dictionary] = []

var _site: Dictionary = {}
var _store: StringName = &""
var _tailgate: Node3D = null
var _truck_x: float = 0.0
var _truck_v: float = 0.0
## Laju truk (m/s, >= 0) menuju -x.
var _speed: float = 0.0
var _driver_wave: float = 0.0
var _parked: bool = false
var _t: float = 0.0
var _phase_t: float = 0.0
## Semua salinan perabot yang sedang hidup (tumpukan, bak, sedang terbang).
var _items: Array[Node3D] = []
var _cargo: Array[Node3D] = []
var _flying: int = 0
## iid perabot dunia yang disembunyikan (asli diangkut, atau baru menunggu tiba).
var _hidden_furniture: Array[int] = []
var _lurah_actor: SimActor = null
var _lurah_path: PackedVector2Array = PackedVector2Array()
var _lurah_wp: int = 0
var _cam_focus: Vector3 = Vector3.INF
var _cam_width: float = VIEW_MIN
var _cam_want_focus: Vector3 = Vector3.ZERO
var _cam_want_width: float = VIEW_MIN
var _depart_wait: float = -1.0
var _arrive_wait: float = -1.0
var _leftover_t: float = 0.0
## Lebar pandang gameplay sebelum cutscene, dan apakah kamera sudah dilepas.
var _restore_width: float = 0.0
var _cam_released: bool = false


func setup(s: SimulationRoot, wv: WorldView) -> MovingDay:
	sim = s
	view = wv
	name = "MovingDay"
	return self


# ===========================================================================
# FASE 1: MENGANGKUT DI TOKO LAMA
# ===========================================================================

## Mulai: truk datang, kru mulai mengangkut. Dipanggil sekali sesudah node masuk
## pohon scene (WorldView sudah dalam mode cutscene).
func begin() -> void:
	var t0: int = Time.get_ticks_usec()
	_store = sim.world.store_floor()
	_site = _site_of(sim.world.location)
	truck = TrafficFactory.moving_truck()
	add_child(truck)
	_tailgate = truck.get_node("Tailgate") as Node3D
	_truck_x = float(_site["stop_x"]) + TRUCK_IN_FROM
	_speed = TRUCK_SPEED
	_spawn_driver()
	_clear_road()
	_place_truck()
	var t1: int = Time.get_ticks_usec()
	_build_crew()
	var t2: int = Time.get_ticks_usec()
	_plan_packing()
	var t3: int = Time.get_ticks_usec()
	var rig: CameraRig = view.camera_rig
	_cam_focus = rig._focus if rig._focus != Vector3.ZERO else Vector3(_site["door"].x, 0.0, 0.0)
	_cam_width = rig.ortho_size
	_restore_width = rig.ortho_size
	_frame_pack()
	phase = Phase.PACK
	_phase_t = 0.0
	GameLogger.info("WORLD", "moving day: truck %.1f ms, %d crew %.1f ms, plan %.1f ms, camera %.1f ms" % [float(t1 - t0) / 1000.0,
		crew.size(), float(t2 - t1) / 1000.0, float(t3 - t2) / 1000.0, float(Time.get_ticks_usec() - t3) / 1000.0])


## Titik-titik penting sebuah lokasi: pintu, lajur jalan terdekat, garis
## trotoar, dan posisi truk berhenti.
func _site_of(loc: LocationDefinition) -> Dictionary:
	var door: Vector2 = GridMath.cell_center(loc.entrance_cell)
	var walk_z: float = StreetPaths.walk_z(loc.tier)
	var park: Dictionary = PARKING.get(clampi(loc.tier, 1, 5), PARKING[1])
	var lane_z: float = float(park.get("z", NeighborhoodFactory.road_edges(loc.tier).x - TrafficFactory.TRUCK_WIDTH * 0.5 - CURB_GAP))
	var fg: FloorGrid = sim.world.grid(sim.world.store_floor())
	var size: Vector2 = Vector2(fg.size) * GridMath.WORLD_METERS_PER_TILE if fg != null else Vector2(3.0, 6.0)
	var via := PackedVector2Array()
	for p: Variant in park["via"]:
		via.append(p)
	return {"door": door, "walk_z": walk_z, "lane_z": lane_z, "size": size, "tier": loc.tier, "via": via,
		"line_z": float(park["line_z"]), "lurah": int(park["lurah"]), "line_x": float(park.get("line_x", 0.0)),
		"gap": float(park.get("gap", LINE_GAP)), "lurah_at": park.get("lurah_at", Vector2.INF),
		"cab_z": float(park.get("cab_z", NAN)),
		"speed": WALK_SPEED * clampf(size.length() / WALK_REF_M, 1.0, WALK_FAST),
		"stop_x": door.x + float(park["rear"]) - TrafficFactory.TRUCK_LENGTH * 0.5}


## Sopir truk: pembeli biasa bertopi pet, kedua tangan di setir.
func _spawn_driver() -> void:
	driver = ActorView.new()
	add_child(driver)
	var spec: Dictionary = CharacterFactory.spec_for_customer("customer_generic", DRIVER_SEED, false)
	spec["hat"] = "topi_pet"
	spec["cloth"] = DRIVER_SHIRT
	spec["prop"] = PackedStringArray()
	driver.bind(&"moving_driver", "moving|driver", spec)
	ProceduralAnimationSystem.set_carry_pose(driver.model, true)


## Kendaraan yang menimpa tempat truk muncul dihapus (di luar layar).
func _clear_road() -> void:
	var street: StreetLife = view.street_life
	if street != null:
		street.remove_near(_truck_x, float(_site["lane_z"]), TrafficFactory.TRUCK_WIDTH * 0.5, TrafficFactory.TRUCK_LENGTH)


func _truck_xf(x: float) -> Transform3D:
	return Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0.0, float(_site["lane_z"])))


func _place_truck() -> void:
	truck.transform = _truck_xf(_truck_x)
	var bob: float = 0.012 * sin(_t * 18.0) * clampf(_speed / TRUCK_SPEED, 0.0, 1.0)
	truck.position.y = bob
	# Kendaraan tamu bagi lalu lintas (StreetLife).
	if view.street_life != null:
		view.street_life.set_guest({"x": _truck_x, "z": float(_site["lane_z"]), "len": TrafficFactory.TRUCK_LENGTH,
			"width": TrafficFactory.TRUCK_WIDTH, "speed": _speed, "dir": -1.0})


## Ujung belakang truk (x dunia) saat berhenti.
func _rear_x() -> float:
	return float(_site["stop_x"]) + TrafficFactory.TRUCK_LENGTH * 0.5


func _build_crew() -> void:
	crew.clear()
	var ids: Array[StringName] = [sim.player.actor.id]
	var staff_ids: Array[StringName] = []
	for sid: Variant in sim.staff.actors.keys():
		staff_ids.append(StringName(str(sid)))
	Ids.sort(staff_ids)
	ids.append_array(staff_ids)
	var rider: int = 0
	for i in ids.size():
		var owner: bool = i == 0
		var a := SimActor.new()
		a.id = StringName("moving_%s" % ids[i])
		var real: SimActor = sim.player.actor if owner else sim.staff.actors[ids[i]]
		a.pos = real.pos if real.floor_id == _store else _portal_or_door()
		a.facing = real.facing
		a.floor_id = _store
		var v := ActorView.new()
		add_child(v)
		# Salinan model aktor yang sudah tampil (murah); merakit dari spec hanya
		# bila aktornya belum punya tampilan.
		var real_view: ActorView = view.views.get(real.id)
		var dup: Node3D = real_view.puppet_model() if real_view != null and is_instance_valid(real_view) else null
		if dup != null:
			v.bind_model(a.id, "moving|" + String(ids[i]), dup)
		else:
			var spec: Dictionary = view.player_spec() if owner else CharacterFactory.spec_for_staff(String(ids[i]))
			v.bind(a.id, "moving|" + String(ids[i]), spec)
		v.global_position = Vector3(a.pos.x, 0.0, a.pos.y)
		var stack := Node3D.new()
		stack.name = "Stack"
		v.add_child(stack)
		var slot: Vector3 = Vector3(-TrafficFactory.TRUCK_DRIVER.x, 0.0, TrafficFactory.TRUCK_DRIVER.z)
		if not owner:
			var rs: Vector2 = RIDER_SLOTS[rider % RIDER_SLOTS.size()]
			slot = Vector3(rs.x, TrafficFactory.TRUCK_BED_Y, rs.y + 0.1 * float(rider / RIDER_SLOTS.size()))
			rider += 1
		crew.append({"id": ids[i], "view": v, "actor": a, "steps": [], "t": 0.0, "started": false, "mode": "foot", "hidden": false,
			"slot": slot, "cab": owner, "stack": stack, "items": [], "hop": {}, "path": PackedVector2Array(), "wp": 0,
			"wave": 0.0, "upstairs": real.floor_id != _store})


## Titik di lantai toko tempat kru dari lantai atas muncul (pintu tangga), atau
## pintu masuk bila tidak ada tangga.
func _portal_or_door() -> Vector2:
	var fd: FloorDefinition = sim.world.location.floor_def(_store)
	if fd != null and fd.has_portal():
		return GridMath.cell_center(fd.portal["access"])
	return _site["door"]


## Bagi perabot ke kru: perabot lantai toko dijemput berurutan dari yang
## terdekat; perabot lantai atas dibawa turun oleh kru yang memang di atas,
## atau dijemput lewat pintu tangga.
func _plan_packing() -> void:
	var store_pieces: Array[int] = []
	var up_pieces: Array[int] = []
	for e: EquipmentInstance in sim.equipment.placed_list():
		if e.floor_id == _store:
			store_pieces.append(e.iid)
		else:
			up_pieces.append(e.iid)
	store_pieces.sort()
	up_pieces.sort()
	var n: int = crew.size()
	var picks: Array = []
	var cursor: Array[Vector2] = []
	for c: Dictionary in crew:
		picks.append([])
		cursor.append((c["actor"] as SimActor).pos)
	var left: Array[int] = store_pieces.duplicate()
	while not left.is_empty():
		for i in n:
			if left.is_empty():
				break
			var best: int = 0
			var best_d: float = INF
			for j in left.size():
				var d: float = cursor[i].distance_to(_access_pos(left[j]))
				if d < best_d:
					best_d = d
					best = j
			var iid: int = left[best]
			left.remove_at(best)
			(picks[i] as Array).append(iid)
			cursor[i] = _access_pos(iid)
	# Lantai atas: kru yang di atas membawanya turun; selain itu dijemput.
	var up_by: Array = []
	for i2 in n:
		up_by.append([])
	var carriers: Array[int] = []
	for i3 in n:
		if bool(crew[i3]["upstairs"]):
			carriers.append(i3)
	if carriers.is_empty():
		for i4 in n:
			carriers.append(i4)
	for k in up_pieces.size():
		(up_by[carriers[k % carriers.size()]] as Array).append(up_pieces[k])
	for i5 in n:
		var c: Dictionary = crew[i5]
		var steps: Array = []
		var ups: Array = up_by[i5]
		if not ups.is_empty():
			if bool(c["upstairs"]):
				# Turun tangga sudah membawa perabot lantai atas.
				for iid2: Variant in ups:
					_stack_add(c, _new_item(int(iid2)), false)
			else:
				var portal: Vector2 = _portal_or_door()
				steps.append({"do": "walk", "cell": GridMath.world_to_cell(portal)})
				steps.append({"do": "fetch", "iids": ups})
		for iid3: Variant in picks[i5]:
			var to: Vector2 = _access_pos(int(iid3))
			steps.append({"do": "walk", "cell": GridMath.world_to_cell(to)})
			steps.append({"do": "pick", "iid": int(iid3)})
		var door: Vector2 = _site["door"]
		var spot: Vector2 = _unload_spot(i5)
		# Keluar lewat jalur pembeli (pintu lurus ke garis trotoar), lalu titik jalan tier.
		var out := PackedVector2Array([Vector2(door.x, float(_site["walk_z"]))])
		out.append_array(_site["via"])
		out.append(spot)
		steps.append({"do": "walk", "cell": GridMath.world_to_cell(door), "then": out})
		steps.append({"do": "face", "dir": Vector2(-1.0, 0.0)})
		steps.append({"do": "wait_truck"})
		steps.append({"do": "unload"})
		if bool(c["cab"]):
			# Pemilik ke pintu penumpang (sisi trotoar), memutar lewat belakang truk.
			var door_p: Vector3 = _truck_xf(float(_site["stop_x"])) * _cab_door_local()
			var wz: float = _cab_walk_z(door_p.z)
			steps.append({"do": "walk", "path": PackedVector2Array([Vector2(_rear_x() + 0.6, wz), Vector2(door_p.x, wz),
				Vector2(door_p.x, door_p.z)])})
		steps.append({"do": "board"})
		_set_steps(c, steps)
		if not (c["items"] as Array).is_empty():
			ProceduralAnimationSystem.set_overhead_pose((c["view"] as ActorView).model, true)


## Ganti daftar langkah kru `c`; langkah pertama dimulai dari awal.
func _set_steps(c: Dictionary, steps: Array) -> void:
	c["steps"] = steps
	c["t"] = 0.0
	c["started"] = false


func _unload_spot(i: int) -> Vector2:
	var o: Vector2 = UNLOAD_SPOTS[i % UNLOAD_SPOTS.size()]
	return Vector2(_rear_x() + o.x + 0.45 * float(i / UNLOAD_SPOTS.size()), float(_site["lane_z"]) + o.y)


## Titik di samping pintu penumpang (sisi trotoar, kiri truk), dalam ruang lokal truk.
func _cab_door_local() -> Vector3:
	return Vector3(-TrafficFactory.TRUCK_WIDTH * 0.5 - 0.38, 0.0, TrafficFactory.TRUCK_DRIVER.z)


## Garis z tempat pemilik berjalan menyusuri truk ke pintu penumpang.
func _cab_walk_z(door_z: float) -> float:
	var cz: float = float(_site["cab_z"])
	return door_z if is_nan(cz) else cz


func _access_pos(iid: int) -> Vector2:
	var acc: Dictionary = sim.world.access_of(iid)
	if acc.has("cell"):
		return GridMath.cell_center(acc["cell"])
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	var c: Vector2i = sim.world.nearest_walkable(_store, e.anchor, FloorGrid.NAV_STAFF) if e != null else Vector2i(-1, -1)
	return GridMath.cell_center(c) if c.x >= 0 else _site["door"]


## Rute dalam toko dari `from` ke sel `cell` (tanpa portal), atau garis lurus.
func _route(from: Vector2, cell: Vector2i) -> PackedVector2Array:
	var out := PackedVector2Array()
	for wp: Dictionary in sim.world.find_route(_store, from, _store, cell, FloorGrid.NAV_STAFF):
		if not bool(wp.get("portal", false)) and StringName(str(wp["floor"])) == _store:
			out.append(wp["pos"])
	if out.is_empty():
		out.append(GridMath.cell_center(cell))
	return out


# ===========================================================================
# PERABOT YANG DIANGKUT
# ===========================================================================

## Salinan model perabot `iid`, diskalakan ke ukuran angkut, dengan alasnya di
## y = 0 dan tengahnya di sumbu node pembungkus.
func _new_item(iid: int) -> Node3D:
	var holder := Node3D.new()
	holder.name = "Item_%d" % iid
	holder.set_meta("iid", iid)
	var m: Node3D = view.equipment_model(iid)
	if m == null:
		m = ProceduralMeshFactory.box(Vector3(0.4, 0.3, 0.3), Palette.PINE_WOOD)
	var b: AABB = m.get_meta("bounds", EquipmentFactory._mesh_bounds(m))
	var k: float = 1.0
	if b.size.x > 0.0 and b.size.z > 0.0 and b.size.y > 0.0:
		k = minf(minf(ITEM_SIZE / b.size.x, ITEM_SIZE / b.size.z), ITEM_HEIGHT / b.size.y)
	m.scale = Vector3(k, k, k)
	m.position = Vector3(-b.get_center().x * k, -b.position.y * k, -b.get_center().z * k)
	holder.add_child(m)
	holder.set_meta("h", b.size.y * k)
	add_child(holder)
	_items.append(holder)
	return holder


## Tinggi tumpukan barang `c` sampai sebelum barang ke-`n` (m).
func _stack_height(items: Array, n: int) -> float:
	var h: float = 0.0
	for i in mini(n, items.size()):
		h += float((items[i] as Node3D).get_meta("h", ITEM_HEIGHT)) + 0.02
	return h


## Taruh `item` di puncak tumpukan kru `c` (terbang dari tempatnya bila `fly`).
func _stack_add(c: Dictionary, item: Node3D, fly: bool) -> void:
	var items: Array = c["items"]
	var v: ActorView = c["view"]
	var stack: Node3D = c["stack"]
	var base: float = v.head_top() + 0.08
	var at := Transform3D(Basis(Vector3.UP, 0.12 * float(items.size() % 3 - 1)), Vector3(0.0, base + _stack_height(items, items.size()), 0.0))
	items.append(item)
	item.visible = items.size() <= STACK_VISIBLE
	if fly:
		_fly(item, stack, at, PICK_SECONDS, 0.25)
	else:
		item.reparent(stack, false)
		item.transform = at


## Terbangkan `item` ke `parent` dengan transform lokal `to` dalam `dur` detik,
## melengkung setinggi `arc`; `then` dipanggil di akhir.
func _fly(item: Node3D, parent: Node3D, to: Transform3D, dur: float, arc: float, then: Callable = Callable()) -> void:
	_kill_tween(item)
	if item.get_parent() != parent:
		item.reparent(parent, true)
	var from: Transform3D = item.transform
	_flying += 1
	var tw: Tween = item.create_tween()
	item.set_meta("tween", tw)
	tw.tween_method(func(k: float) -> void:
		var xf: Transform3D = from.interpolate_with(to, ease(k, -1.8))
		xf.origin.y += arc * sin(PI * k)
		item.transform = xf, 0.0, 1.0, dur)
	tw.tween_callback(func() -> void:
		_flying = maxi(0, _flying - 1)
		if then.is_valid():
			then.call())


## Hentikan gerak terbang/tunda yang sedang berjalan pada `item`.
func _kill_tween(item: Node3D) -> void:
	if not item.has_meta("tween"):
		return
	var old: Variant = item.get_meta("tween")
	if old is Tween and (old as Tween).is_valid():
		(old as Tween).kill()
	item.remove_meta("tween")


## Angkat perabot dunia `iid`: model aslinya disembunyikan dan salinannya
## terbang ke puncak tumpukan (`fly` false: langsung di tumpukan).
func _pick(c: Dictionary, iid: int, fly: bool = true) -> void:
	var item: Node3D = _new_item(iid)
	var orig: Node3D = view.furniture.get(iid)
	if orig != null and is_instance_valid(orig):
		var b: AABB = EquipmentFactory._mesh_bounds(orig)
		item.global_position = orig.global_transform * Vector3(b.get_center().x, b.position.y, b.get_center().z)
		orig.visible = false
		_hidden_furniture.append(iid)
	else:
		item.global_position = (c["view"] as ActorView).global_position
	_stack_add(c, item, fly)
	ProceduralAnimationSystem.set_overhead_pose((c["view"] as ActorView).model, true)


## Transform lokal tempat barang ke-`n` di bak truk.
func _cargo_xf(n: int) -> Transform3D:
	var s: Vector2 = CARGO_SLOTS[n % CARGO_SLOTS.size()]
	var layer: int = n / CARGO_SLOTS.size()
	var y: float = TrafficFactory.TRUCK_BED_Y + float(layer) * (ITEM_HEIGHT + 0.02)
	return Transform3D(Basis(Vector3.UP, 0.08 * float(n % 3 - 1)), Vector3(s.x, y, s.y))


## Turunkan seluruh tumpukan ke bak, satu per satu.
func _unload(c: Dictionary) -> void:
	var items: Array = (c["items"] as Array).duplicate()
	(c["items"] as Array).clear()
	for i in items.size():
		var it: Node3D = items[i]
		var to: Transform3D = _cargo_xf(_cargo.size())
		_cargo.append(it)
		it.visible = true
		var delay: float = UNLOAD_EACH * float(i)
		if delay <= 0.0:
			_fly(it, truck, to, 0.34, 0.5)
		else:
			_kill_tween(it)
			_flying += 1
			var tw: Tween = it.create_tween()
			it.set_meta("tween", tw)
			tw.tween_interval(delay)
			tw.tween_callback(func() -> void:
				_flying = maxi(0, _flying - 1)
				_fly(it, truck, to, 0.34, 0.5))


# ===========================================================================
# LANGKAH KRU
# ===========================================================================

func _process(delta: float) -> void:
	if sim == null or view == null or (truck == null and phase != Phase.LEFTOVER):
		return
	_t += delta
	_phase_t += delta
	_drive(delta)
	match phase:
		Phase.PACK:
			_update_pack()
		Phase.DEPART:
			if _depart_wait >= 0.0:
				_depart_wait -= delta
			elif _truck_x < float(_site["stop_x"]) - TRUCK_OUT_TO * 0.6:
				phase = Phase.GONE
				departed.emit()
		Phase.ARRIVE:
			_update_arrive(delta)
		Phase.ENTER:
			var all_in: bool = true
			for c: Dictionary in crew:
				all_in = all_in and String(c["mode"]) == "gone"
			if all_in:
				phase = Phase.DONE
				finished.emit()
		Phase.LEFTOVER:
			_update_leftover(delta)
	for c2: Dictionary in crew:
		_run(c2, delta)
	_ride_driver(delta)
	_update_lurah(delta)
	_update_camera(delta)


func _update_pack() -> void:
	if _phase_t > PACK_LIMIT:
		_force_board()
	var all_ride: bool = true
	for c: Dictionary in crew:
		all_ride = all_ride and String(c["mode"]) == "ride"
	if all_ride and _flying == 0:
		phase = Phase.DEPART
		_phase_t = 0.0
		_depart_wait = 0.4
		_gate(false)
		EventBus.sfx.emit(&"truck_horn", &"")
		for c2: Dictionary in crew:
			c2["wave"] = 1.6


## Truk: menuju titik berhenti (datang) atau meninggalkan layar (pergi).
## Truk: menuju titik berhenti (datang) atau meninggalkan layar (pergi), selalu
## menjaga jarak dengan kendaraan StreetLife di depannya.
func _drive(delta: float) -> void:
	if truck == null:
		return
	var leaving: bool = (phase == Phase.DEPART and _depart_wait < 0.0) or (phase == Phase.LEFTOVER and not _parked)
	var arriving: bool = (phase == Phase.PACK or phase == Phase.ARRIVE) and not _parked
	if not leaving and not arriving:
		_speed = 0.0
		_place_truck()
		return
	var want: float = TRUCK_SPEED
	var stop: float = float(_site["stop_x"])
	if arriving:
		var d: float = _truck_x - stop
		if d <= 0.005:
			_truck_x = stop
			_speed = 0.0
			_parked = true
			_on_parked()
			_place_truck()
			return
		want = minf(TRUCK_SPEED, sqrt(2.0 * TRUCK_BRAKE * d) + 0.2)
	var street: StreetLife = view.street_life
	if street != null:
		var g: Vector2 = street.gap_ahead(_truck_x, float(_site["lane_z"]), TrafficFactory.TRUCK_WIDTH * 0.5, TrafficFactory.TRUCK_LENGTH, -1.0)
		if g.x < StreetLife._brake_gap(_speed, g.y):
			want = minf(want, g.y * (0.8 if g.x < StreetLife.SAFE_GAP else 1.0))
	_speed = move_toward(_speed, want, (TRUCK_ACCEL if want > _speed else TRUCK_BRAKE * 1.5) * delta)
	_truck_x -= _speed * delta
	if arriving:
		_truck_x = maxf(stop, _truck_x)
	_truck_v = -_speed
	_place_truck()


func _on_parked() -> void:
	EventBus.sfx.emit(&"truck_horn", &"")
	_driver_wave = 1.6
	_gate(true)
	if phase == Phase.ARRIVE:
		_arrive_wait = 0.25


func _gate(open: bool) -> void:
	if _tailgate == null:
		return
	var tw: Tween = _tailgate.create_tween()
	tw.tween_property(_tailgate, "rotation:x", PI * 0.5 if open else 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _run(c: Dictionary, delta: float) -> void:
	var v: ActorView = c["view"]
	var a: SimActor = c["actor"]
	c["wave"] = maxf(0.0, float(c["wave"]) - delta)
	match String(c["mode"]):
		"ride":
			_ride(c)
			return
		"hop":
			_hop(c, delta)
			return
		"gone":
			v.visible = false
			return
	a.moving = false
	var steps: Array = c["steps"]
	if not steps.is_empty():
		var s: Dictionary = steps[0]
		var first: bool = not bool(c["started"])
		c["started"] = true
		c["t"] = float(c["t"]) + delta
		if _step(c, s, delta, first) and is_same(c["steps"], steps) and not steps.is_empty():
			steps.pop_front()
			c["t"] = 0.0
			c["started"] = false
	v.visible = not bool(c["hidden"])
	v.sync(a, delta, true)
	if float(c["wave"]) > 0.0:
		ProceduralAnimationSystem.wave(v.model, clampf(float(c["wave"]) * 2.0, 0.0, 1.0), _t)


## Satu langkah kru; true bila selesai.
func _step(c: Dictionary, s: Dictionary, delta: float, first: bool) -> bool:
	var a: SimActor = c["actor"]
	match String(s["do"]):
		"walk":
			if first:
				# Rute dalam toko dihitung saat langkahnya mulai (tersebar antar-frame).
				var path: PackedVector2Array = _route(a.pos, s["cell"]) if s.has("cell") else s["path"]
				if s.has("then"):
					path.append_array(s["then"])
				c["path"] = path
				c["wp"] = 0
			return _walk(c, delta)
		"face":
			a.facing = s["dir"]
			return true
		"pick":
			if first:
				var iid: int = int(s["iid"])
				var e: EquipmentInstance = sim.equipment.get_inst(iid)
				if e != null:
					var to: Vector2 = GridMath.cell_center(e.anchor) - a.pos
					if to.length() > 0.01:
						a.facing = to.normalized()
				_pick(c, iid)
			return float(c["t"]) >= PICK_SECONDS
		"fetch":
			if first:
				c["hidden"] = true
			if float(c["t"]) < FETCH_SECONDS:
				return false
			c["hidden"] = false
			for iid2: Variant in s["iids"]:
				_stack_add(c, _new_item(int(iid2)), false)
			ProceduralAnimationSystem.set_overhead_pose((c["view"] as ActorView).model, true)
			return true
		"wait_truck":
			return _parked
		"unload":
			if first:
				if (c["items"] as Array).is_empty():
					return true
				c["unload_n"] = (c["items"] as Array).size()
				_unload(c)
			if float(c["t"]) >= UNLOAD_EACH * float(int(c.get("unload_n", 1))) + 0.2:
				ProceduralAnimationSystem.set_overhead_pose((c["view"] as ActorView).model, false)
				return true
			return false
		"board":
			var target: Vector3 = truck.global_transform * Vector3(c["slot"])
			if bool(c["cab"]):
				target = truck.global_transform * Vector3(-TrafficFactory.TRUCK_DRIVER.x, TrafficFactory.TRUCK_DRIVER.y, TrafficFactory.TRUCK_DRIVER.z)
			_start_hop(c, target, "ride")
			return true
		"vanish":
			c["mode"] = "gone"
			return true
		"idle":
			return false
	return true


func _walk(c: Dictionary, delta: float) -> bool:
	var a: SimActor = c["actor"]
	var path: PackedVector2Array = c["path"]
	var i: int = int(c["wp"])
	var budget: float = float(_site.get("speed", WALK_SPEED)) * delta
	while budget > 0.0 and i < path.size():
		var to: Vector2 = path[i] - a.pos
		var d: float = to.length()
		if d <= budget:
			a.pos = path[i]
			budget -= d
			i += 1
			if d > 0.0001:
				a.facing = to / d
		else:
			a.facing = to / d
			a.pos += a.facing * budget
			budget = 0.0
	c["wp"] = i
	a.moving = i < path.size()
	return not a.moving


## Lompat dari tempatnya sekarang (juga dari kursi sopir) ke `to`, lalu `then`
## ("ride" naik truk, "foot" berjalan lagi).
func _start_hop(c: Dictionary, to: Vector3, then: String) -> void:
	var v: ActorView = c["view"]
	var lift: float = v.model.position.y if v.model != null else 0.0
	c["hop"] = {"from": v.global_position + Vector3(0.0, lift, 0.0), "to": to, "t": 0.0, "then": then}
	c["mode"] = "hop"
	ProceduralAnimationSystem.set_overhead_pose(v.model, false)
	ProceduralAnimationSystem.stand_up(v.model)


func _hop(c: Dictionary, delta: float) -> void:
	var v: ActorView = c["view"]
	var h: Dictionary = c["hop"]
	h["t"] = float(h["t"]) + delta
	var k: float = clampf(float(h["t"]) / HOP_SECONDS, 0.0, 1.0)
	var from: Vector3 = h["from"]
	var to: Vector3 = h["to"]
	v.global_position = from.lerp(to, k) + Vector3(0.0, HOP_ARC * sin(PI * k), 0.0)
	var flat := Vector2(to.x - from.x, to.z - from.z)
	if flat.length() > 0.01:
		var want: float = atan2(-flat.x, -flat.y)
		v.rotation.y = lerp_angle(v.rotation.y, want, minf(1.0, delta * 12.0))
	ProceduralAnimationSystem.idle_bob(v.model, _t)
	v.visible = true
	if k < 1.0:
		return
	if String(h["then"]) == "ride":
		c["mode"] = "ride"
	else:
		c["mode"] = "foot"
		var a: SimActor = c["actor"]
		a.pos = Vector2(to.x, to.z)
		ProceduralAnimationSystem.stand_up(v.model)
		ProceduralAnimationSystem.end_pose(v.model)


func _ride(c: Dictionary) -> void:
	var v: ActorView = c["view"]
	v.visible = true
	var slot: Vector3 = c["slot"]
	v.global_position = truck.global_transform * slot
	if bool(c["cab"]):
		v.rotation.y = PI * 0.5
		ProceduralAnimationSystem.idle_bob(v.model, _t)
		ProceduralAnimationSystem.sit(v.model, _t, TrafficFactory.TRUCK_DRIVER.y, false)
	else:
		v.rotation.y = _camera_yaw()
		ProceduralAnimationSystem.idle_bob(v.model, _t)
		if float(c["wave"]) > 0.0:
			ProceduralAnimationSystem.wave(v.model, clampf(float(c["wave"]) * 2.0, 0.0, 1.0), _t)


## Sopir duduk di kursi kanan dengan tangan di setir; melambai saat truk berhenti.
func _ride_driver(delta: float) -> void:
	if driver == null or truck == null:
		return
	driver.global_position = truck.global_transform * Vector3(TrafficFactory.TRUCK_DRIVER.x, 0.0, TrafficFactory.TRUCK_DRIVER.z)
	driver.rotation.y = PI * 0.5
	ProceduralAnimationSystem.idle_bob(driver.model, _t)
	ProceduralAnimationSystem.sit(driver.model, _t, TrafficFactory.TRUCK_DRIVER.y, false)
	if _driver_wave > 0.0:
		_driver_wave -= delta
		ProceduralAnimationSystem.wave(driver.model, clampf(_driver_wave * 2.0, 0.0, 1.0), _t)
		if _driver_wave <= 0.0:
			ProceduralAnimationSystem.end_pose(driver.model)


## Arah hadap (rotation.y ActorView) ke kamera.
func _camera_yaw() -> float:
	var f: Vector2 = _toward_camera()
	return atan2(-f.x, -f.y)


func _toward_camera() -> Vector2:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	return Vector2(-sin(yaw), -cos(yaw)).normalized()


## Batas waktu angkut: yang belum selesai langsung naik truk dengan barangnya.
func _force_board() -> void:
	for c: Dictionary in crew:
		if String(c["mode"]) == "ride":
			continue
		for st: Dictionary in c["steps"]:
			if String(st["do"]) == "pick" and not (bool(c["started"]) and st == (c["steps"] as Array)[0]):
				_pick(c, int(st["iid"]), false)
			elif String(st["do"]) == "fetch":
				for iid: Variant in st["iids"]:
					_stack_add(c, _new_item(int(iid)), false)
		for it: Variant in c["items"]:
			var item: Node3D = it
			_kill_tween(item)
			item.visible = true
			item.reparent(truck, false)
			item.transform = _cargo_xf(_cargo.size())
			_cargo.append(item)
		(c["items"] as Array).clear()
		_set_steps(c, [])
		c["hidden"] = false
		c["mode"] = "ride"
		ProceduralAnimationSystem.set_overhead_pose((c["view"] as ActorView).model, false)
	_flying = 0


# ===========================================================================
# FASE 2: TIBA DI TOKO BARU
# ===========================================================================

## Lokasi sudah pindah dan dunia sudah dibangun ulang: truk datang di toko baru.
## `instant` = langsung ke kru berbaris (Skip).
func arrive(instant: bool = false) -> void:
	_store = sim.world.store_floor()
	_site = _site_of(sim.world.location)
	_parked = false
	_truck_x = float(_site["stop_x"]) + TRUCK_IN_FROM
	_speed = TRUCK_SPEED
	_depart_wait = -1.0
	_clear_road()
	_hidden_furniture.clear()
	for iid: Variant in view.furniture.keys():
		var e: EquipmentInstance = sim.equipment.get_inst(int(iid))
		if e != null and e.floor_id == _store:
			(view.furniture[iid] as Node3D).visible = false
			_hidden_furniture.append(int(iid))
	_spawn_lurah()
	phase = Phase.ARRIVE
	_phase_t = 0.0
	_arrive_wait = -1.0
	for c: Dictionary in crew:
		_set_steps(c, [])
		c["hidden"] = false
		if String(c["mode"]) != "ride":
			c["mode"] = "ride"
	_gate(false)
	if _tailgate != null:
		_tailgate.rotation.x = 0.0
	_place_truck()
	_frame_arrive(false)
	_cam_focus = _cam_want_focus
	_cam_width = _cam_want_width
	if instant:
		_place_greet()


## Barisan di depan toko baru: tempat kru ke-`i` dan Pak Lurah.
func _line_spot(i: int) -> Vector2:
	var n: int = crew.size()
	var cx: float = (_site["door"] as Vector2).x + float(_site["line_x"])
	return Vector2(cx + (float(i) - float(n - 1) * 0.5) * float(_site["gap"]), float(_site["line_z"]))


func _lurah_spot() -> Vector2:
	if _site["lurah_at"] != Vector2.INF:
		return _site["lurah_at"]
	var n: int = crew.size()
	var cx: float = (_site["door"] as Vector2).x + float(_site["line_x"])
	var side: float = float(int(_site["lurah"]))
	return Vector2(cx + side * (float(n - 1) * 0.5 + 1.7) * float(_site["gap"]), float(_site["line_z"]) - 0.1)


## Jalan dari belakang truk ke barisan: titik jalan tier dibalik, hanya yang
## lebih jauh dari toko daripada garis barisan.
func _to_line(from: Vector2, line: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array([from])
	var via: PackedVector2Array = _site["via"]
	for k in range(via.size() - 1, -1, -1):
		if via[k].y < line.y - 0.3:
			out.append(via[k])
	out.append(line)
	return out


func _spawn_lurah() -> void:
	if lurah == null:
		lurah = ActorView.new()
		add_child(lurah)
		lurah.bind(&"moving_lurah", "moving|lurah", CharacterFactory.spec_for_lurah())
		_lurah_actor = SimActor.new()
		_lurah_actor.id = &"moving_lurah"
	_lurah_actor.pos = _lurah_spot()
	_lurah_actor.moving = false
	_lurah_actor.facing = (_line_spot(0) - _lurah_actor.pos).normalized().lerp(_toward_camera(), 0.5).normalized()
	_lurah_path = PackedVector2Array()
	lurah.global_position = Vector3(_lurah_actor.pos.x, 0.0, _lurah_actor.pos.y)
	lurah.rotation.y = atan2(-_lurah_actor.facing.x, -_lurah_actor.facing.y)
	lurah.visible = true


func _update_arrive(delta: float) -> void:
	if not _parked:
		return
	if _arrive_wait >= 0.0:
		_arrive_wait -= delta
		if _arrive_wait < 0.0:
			_unpack_new()
		return
	var lined: bool = true
	for c: Dictionary in crew:
		var steps: Array = c["steps"]
		lined = lined and String(c["mode"]) == "foot" and steps.size() == 1 and String((steps[0] as Dictionary)["do"]) == "idle"
	if lined and _flying == 0 and _cargo.is_empty():
		_show_all_furniture()
		_to_greet()


## Kru turun dan berjalan ke barisan; perabot dari bak melompat masuk pintu.
func _unpack_new() -> void:
	for i in crew.size():
		var c: Dictionary = crew[i]
		var line: Vector2 = _line_spot(i)
		var ground: Vector2
		if bool(c["cab"]):
			var cab: Vector3 = truck.global_transform * _cab_door_local()
			ground = Vector2(cab.x, cab.z)
		else:
			ground = _unload_spot(i)
		var hop_to := Vector3(ground.x, 0.0, ground.y)
		var walk: PackedVector2Array
		if bool(c["cab"]):
			# Turun dari pintu penumpang ke trotoar.
			walk = PackedVector2Array([ground])
			walk.append_array(_to_line(Vector2(ground.x, _cab_walk_z(ground.y)), line))
		else:
			walk = _to_line(ground, line)
		_set_steps(c, [{"do": "walk", "path": walk}, {"do": "face", "dir": _toward_camera()}, {"do": "idle"}])
		(c["actor"] as SimActor).facing = Vector2(1.0, 0.0)
		c["hop_delay"] = 0.12 * float(i)
		_start_hop(c, hop_to, "foot")
		(c["hop"] as Dictionary)["t"] = -float(c["hop_delay"])
	var door: Vector2 = _site["door"]
	for n in _cargo.size():
		var it: Node3D = _cargo[n]
		var iid: int = int(it.get_meta("iid", -1))
		var to := Transform3D(Basis.IDENTITY.scaled(Vector3(0.2, 0.2, 0.2)), Vector3(door.x, 0.4, door.y + 0.3))
		_flying += 1
		var tw: Tween = it.create_tween()
		tw.tween_interval(0.2 + 0.07 * float(n))
		tw.tween_callback(func() -> void:
			_flying = maxi(0, _flying - 1)
			_fly(it, self, to, 0.42, 0.9, func() -> void:
				_reveal(iid)
				_items.erase(it)
				it.queue_free()))
	_cargo.clear()


## Perabot `iid` di toko baru muncul dengan pop kecil (barangnya baru masuk).
func _reveal(iid: int) -> void:
	if not _hidden_furniture.has(iid):
		return
	_hidden_furniture.erase(iid)
	var n: Node3D = view.furniture.get(iid)
	if n != null and is_instance_valid(n):
		n.visible = true
		if not SettingsManager.reduced_motion():
			ProceduralAnimationSystem.squash_pop(n, 1.12, 0.22)


func _show_all_furniture() -> void:
	for iid: int in _hidden_furniture:
		var n: Node3D = view.furniture.get(iid)
		if n != null and is_instance_valid(n):
			n.visible = true
	_hidden_furniture.clear()


func _to_greet() -> void:
	phase = Phase.GREET
	_phase_t = 0.0
	_frame_arrive(true)
	for c: Dictionary in crew:
		var v: ActorView = c["view"]
		if not SettingsManager.reduced_motion():
			ProceduralAnimationSystem.happy_jump(v.model)
	greeting.emit()


## Skip: langsung ke kru berbaris di depan toko baru, truk terparkir.
func _place_greet() -> void:
	for it: Node3D in _items:
		if is_instance_valid(it):
			it.queue_free()
	_items.clear()
	_cargo.clear()
	_flying = 0
	_truck_x = float(_site["stop_x"])
	_truck_v = 0.0
	_speed = 0.0
	_parked = true
	_place_truck()
	if _tailgate != null:
		_tailgate.rotation.x = PI * 0.5
	_show_all_furniture()
	for i in crew.size():
		var c: Dictionary = crew[i]
		var v: ActorView = c["view"]
		var a: SimActor = c["actor"]
		a.pos = _line_spot(i)
		a.facing = _toward_camera()
		a.moving = false
		c["mode"] = "foot"
		c["hidden"] = false
		_set_steps(c, [{"do": "idle"}])
		(c["items"] as Array).clear()
		ProceduralAnimationSystem.set_overhead_pose(v.model, false)
		ProceduralAnimationSystem.stand_up(v.model)
		ProceduralAnimationSystem.end_pose(v.model)
		v.global_position = Vector3(a.pos.x, 0.0, a.pos.y)
		v.rotation.y = _camera_yaw()
	_spawn_lurah()
	_frame_arrive(true)
	_cam_focus = _cam_want_focus
	_cam_width = _cam_want_width
	phase = Phase.GREET
	_phase_t = 0.0
	greeting.emit()


## Kartu ditutup: kru masuk toko lewat pintu.
func enter() -> void:
	if phase != Phase.GREET:
		return
	phase = Phase.ENTER
	_phase_t = 0.0
	var door: Vector2 = _site["door"]
	for i in crew.size():
		var c: Dictionary = crew[i]
		if String(c["mode"]) == "gone":
			continue
		var a: SimActor = c["actor"]
		# Ke garis tengah pintu dulu, lalu lurus masuk seperti pembeli.
		var lane_x: float = door.x + (float(i) - float(crew.size() - 1) * 0.5) * 0.12
		_set_steps(c, [{"do": "walk", "path": PackedVector2Array([Vector2(lane_x, float(_site["line_z"])), Vector2(lane_x, -0.15),
			Vector2(door.x, door.y)])}, {"do": "vanish"}])
		a.moving = true


## Skip setelah pindah lokasi: langsung ke kru berbaris.
func skip_to_greet() -> void:
	if phase == Phase.ARRIVE:
		_place_greet()


## Cutscene ditutup: boneka kru langsung disembunyikan (aktor simulasi tampil
## lagi), kamera kembali pelan ke lebar `restore_width`, lalu truk dan Pak Lurah
## pergi sendiri dan node ini dibebaskan.
func release(restore_width: float = 0.0) -> void:
	if restore_width > 0.0:
		_restore_width = restore_width
	for c: Dictionary in crew:
		(c["view"] as ActorView).visible = false
		c["mode"] = "gone"
	_show_all_furniture()
	for it: Node3D in _items:
		if is_instance_valid(it):
			it.queue_free()
	_items.clear()
	_cargo.clear()
	if phase == Phase.LEFTOVER:
		return
	var on_new_site: bool = phase >= Phase.ARRIVE
	phase = Phase.LEFTOVER
	_leftover_t = 0.0
	if not on_new_site or truck == null:
		_release_camera()
		queue_free()
		return
	_gate(false)
	if lurah != null and _lurah_actor != null:
		ProceduralAnimationSystem.end_pose(lurah.model)
		var end_x: float = -14.0
		_lurah_path = PackedVector2Array([Vector2(_lurah_actor.pos.x, float(_site["walk_z"])), Vector2(end_x, float(_site["walk_z"]))])
		_lurah_wp = 0


func _update_leftover(delta: float) -> void:
	_leftover_t += delta
	if _leftover_t > 0.3:
		_parked = false
	var truck_gone: bool = _truck_x < float(_site["stop_x"]) - TRUCK_GONE_AT
	var lurah_gone: bool = lurah == null or _lurah_wp >= _lurah_path.size()
	if truck_gone and truck != null:
		_clear_guest()
		truck.queue_free()
		truck = null
		_tailgate = null
		if driver != null:
			driver.queue_free()
			driver = null
	if (truck_gone and lurah_gone) or _leftover_t > 12.0:
		queue_free()


func _update_lurah(delta: float) -> void:
	if lurah == null or _lurah_actor == null:
		return
	var a: SimActor = _lurah_actor
	a.moving = false
	if phase == Phase.LEFTOVER and _lurah_wp < _lurah_path.size():
		var budget: float = 1.6 * delta
		while budget > 0.0 and _lurah_wp < _lurah_path.size():
			var to: Vector2 = _lurah_path[_lurah_wp] - a.pos
			var d: float = to.length()
			if d <= budget:
				a.pos = _lurah_path[_lurah_wp]
				budget -= d
				_lurah_wp += 1
			else:
				a.facing = to / d
				a.pos += a.facing * budget
				budget = 0.0
		a.moving = _lurah_wp < _lurah_path.size()
	lurah.sync(a, delta, true)
	if phase == Phase.GREET or phase == Phase.ENTER or (phase == Phase.ARRIVE and _parked):
		ProceduralAnimationSystem.wave(lurah.model, 1.0, _t)


# ===========================================================================
# KAMERA
# ===========================================================================

## Toko lama: seluruh lantai toko dan truk di jalan.
func _frame_pack() -> void:
	var size: Vector2 = _site["size"]
	var pts: Array[Vector3] = []
	for x: float in [0.0, size.x]:
		for z: float in [0.0, minf(size.y, 6.5)]:
			pts.append(Vector3(x, 0.0, z))
			pts.append(Vector3(x, 1.4, z))
	_truck_points(pts)
	_frame(pts, VIEW_TOP_PX, VIEW_BOTTOM_PX)


## Toko baru: muka toko di sekitar pintu, barisan, Pak Lurah, dan truk.
func _frame_arrive(card: bool) -> void:
	var door: Vector2 = _site["door"]
	var pts: Array[Vector3] = []
	var ls: Vector2 = _lurah_spot()
	var right: Vector2 = _line_spot(crew.size() - 1)
	var left: Vector2 = _line_spot(0)
	for x: float in [minf(minf(ls.x, left.x) - 0.4, door.x - 1.5), maxf(maxf(ls.x, right.x) + 0.4, door.x + 1.8)]:
		for z: float in [1.6, float(_site["line_z"]) - 0.3]:
			pts.append(Vector3(x, 0.0, z))
			pts.append(Vector3(x, 1.7, z))
	_truck_points(pts)
	_frame(pts, VIEW_TOP_PX, VIEW_CARD_PX if card else VIEW_BOTTOM_PX)


func _truck_points(pts: Array[Vector3]) -> void:
	var lane: float = float(_site["lane_z"])
	var half_w: float = TrafficFactory.TRUCK_WIDTH * 0.5
	var x0: float = float(_site["stop_x"]) - TrafficFactory.TRUCK_LENGTH * 0.5
	var x1: float = _rear_x() + 1.2
	for x: float in [x0, x1]:
		for z: float in [lane - half_w, lane + half_w]:
			pts.append(Vector3(x, 0.0, z))
			pts.append(Vector3(x, 1.9, z))


## Fokus dan lebar pandang supaya semua `pts` muat di antara `top_px` dan
## `bottom_px` layar (kamera ortografis, yaw/pitch tetap).
func _frame(pts: Array[Vector3], top_px: float, bottom_px: float) -> void:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	var pitch: float = deg_to_rad(DataRegistry.balf("camera.pitch_degrees"))
	var fwd := -Vector3(-sin(yaw) * cos(pitch), sin(pitch), -cos(yaw) * cos(pitch)).normalized()
	var right: Vector3 = Vector3.UP.cross(-fwd).normalized()
	var up: Vector3 = (-fwd).cross(right).normalized()
	var u0: float = INF
	var u1: float = -INF
	var v0: float = INF
	var v1: float = -INF
	for p: Vector3 in pts:
		u0 = minf(u0, p.dot(right))
		u1 = maxf(u1, p.dot(right))
		v0 = minf(v0, p.dot(up))
		v1 = maxf(v1, p.dot(up))
	var vp: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(720, 1280)
	var inset: Vector4 = ProceduralUIFactory.safe_area_margin()
	var top: float = top_px + inset.y
	var bottom: float = bottom_px + inset.w
	var band: float = maxf(200.0, vp.y - top - bottom)
	var width: float = maxf((u1 - u0) * 1.08, (v1 - v0) * 1.08 * vp.x / band)
	width = clampf(width, VIEW_MIN, VIEW_MAX)
	var mpp: float = width / maxf(vp.x, 1.0)
	# Titik fokus tampil hud_shift_px di atas tengah layar (CameraRig._apply);
	# geser supaya tengah kotak jatuh di tengah pita yang kosong.
	var focus_y: float = vp.y * 0.5 - CameraRig.hud_shift_px()
	var band_mid: float = top + band * 0.5
	var uc: float = (u0 + u1) * 0.5
	var vc: float = (v0 + v1) * 0.5 + (band_mid - focus_y) * mpp
	var p0: Vector3 = right * uc + up * vc
	_cam_want_focus = p0 - fwd * (p0.y / fwd.y)
	_cam_want_width = width


## Kamera kembali ke kamera gameplay (lebar semula, fokus dipegang CameraRig).
func _release_camera() -> void:
	if view == null or not is_instance_valid(view) or _cam_released:
		return
	_cam_released = true
	view.camera_rig.cutscene_focus = Vector3.INF
	if _restore_width > 0.0:
		view.camera_rig.ortho_size = _restore_width


func _exit_tree() -> void:
	_release_camera()
	_clear_guest()


func _clear_guest() -> void:
	if view != null and is_instance_valid(view) and view.street_life != null:
		view.street_life.set_guest({})


func _update_camera(delta: float) -> void:
	if view == null or _cam_released:
		return
	if phase == Phase.LEFTOVER:
		# Kembali pelan ke tengah lantai toko dan lebar semula, lalu dilepas.
		var size: Vector2 = _site.get("size", Vector2(3.0, 6.0))
		var home := Vector3(size.x * 0.5, 0.0, size.y * 0.5)
		var kk: float = 1.0 - exp(-delta * 5.0)
		_cam_focus = _cam_focus.lerp(home, kk)
		if _restore_width > 0.0:
			_cam_width = lerpf(_cam_width, _restore_width, kk)
		view.camera_rig.cutscene_focus = _cam_focus
		view.camera_rig.ortho_size = _cam_width
		if _leftover_t > 0.8:
			_release_camera()
		return
	var want: Vector3 = _cam_want_focus
	if phase == Phase.DEPART and _depart_wait < 0.0:
		# Kamera ikut sedikit ke arah truk yang pergi.
		want.x += minf(0.0, _truck_x - float(_site["stop_x"])) * 0.35
	var k: float = 1.0 - exp(-delta * 2.6)
	_cam_focus = _cam_focus.lerp(want, k)
	_cam_width = lerpf(_cam_width, _cam_want_width, k)
	view.camera_rig.cutscene_focus = _cam_focus
	view.camera_rig.ortho_size = _cam_width


## Untuk tes: jumlah salinan perabot yang sedang ada di bak truk.
func cargo_count() -> int:
	return _cargo.size()


## Untuk tes: jumlah perabot dunia yang sedang disembunyikan.
func hidden_furniture() -> int:
	return _hidden_furniture.size()
