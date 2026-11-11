class_name WorldMoments
extends Node3D
## Momen kecil di dunia (GDD idle §20 no. 71), tanpa mem-pause toko:
##
## - **Staf baru** (`welcome`, EventBus.staff_hired): boneka salinan modelnya
##   berjalan di trotoar ke pintu, masuk, menghadap kamera, melompat dan melambai
##   dengan kilau dan gelembung sapaan, lalu menyusul aktor aslinya (yang sudah
##   bekerja sejak direkrut) dan bertukar tempat dengannya. Koki yang bekerja di
##   dapur lantai atas naik lewat pintu tangga.
## - **Stasiun baru** (`deliver`, EventBus.station_opened): kardus jatuh di
##   tempatnya, mendarat dengan debu, tutupnya terbuka, lalu kardus mengecil dan
##   stasiunnya melompat keluar dengan kilau. Stasiun di lantai lain diperlihatkan
##   sebentar (kamera pindah lantai lalu kembali).
##
## Murni tontonan: simulasi tidak tahu dan tidak berubah (aktor dan stasiunnya
## sudah bekerja sejak dibeli; hanya tampilannya disembunyikan selama boneka atau
## kardus menggantikannya). Gerak dalam detik nyata. Reduced Motion: hanya kilau
## dan gelembung, tanpa boneka dan tanpa kardus jatuh. Kardus dan debu memakai
## material MATTE bersama, tanpa kombinasi shader baru.

## Boneka staf baru: kecepatan jalan (m/s nyata), jarak mulai di trotoar dari
## garis pintu, lama menyapa, batas waktu menyusul, dan jarak bertukar tempat.
const WALK_SPEED: float = 2.6
const ENTER_FROM: float = 1.6
const GREET_SECONDS: float = 1.5
const CHASE_LIMIT: float = 8.0
const SWAP_DIST: float = 0.3
const REROUTE_SECONDS: float = 0.35
## Kardus stasiun baru: tinggi jatuh (m), lama jatuh, dan urutan sesudah mendarat.
const DROP_HEIGHT: float = 3.2
const DROP_SECONDS: float = 0.42
const SQUASH_SECONDS: float = 0.24
const FLAPS_AT: float = 0.28
const FLAPS_SECONDS: float = 0.3
const REVEAL_AT: float = 0.62
const BOX_SHRINK_SECONDS: float = 0.24
const DELIVERY_END: float = 1.1
## Setelah stasiun di lantai lain terungkap, kamera kembali sesudah sekian detik.
const PEEK_HOLD: float = 0.9
const CARDBOARD: Color = Color(0.749, 0.580, 0.380)
const TAPE: Color = Color(0.86, 0.74, 0.52)
const DUST: Color = Palette.UI_CREAM_DEEP
const DUST_PUFFS: int = 6

var sim: SimulationRoot = null
var view: WorldView = null
## Sambutan yang berjalan: [{id, state, t, puppet, actor, path, wp, bubble, reroute}].
var welcomes: Array[Dictionary] = []
## Kiriman yang berjalan: [{iid, floor, t, box, flaps, puffs, revealed, peek, prev}].
var deliveries: Array[Dictionary] = []


func setup(s: SimulationRoot, wv: WorldView) -> WorldMoments:
	sim = s
	view = wv
	name = "WorldMoments"
	return self


func _process(delta: float) -> void:
	if sim == null or view == null:
		return
	var i: int = 0
	while i < welcomes.size():
		if _step_welcome(welcomes[i], delta):
			welcomes.remove_at(i)
			continue
		i += 1
	var k: int = 0
	while k < deliveries.size():
		if _step_delivery(deliveries[k], delta):
			deliveries.remove_at(k)
			continue
		k += 1


## Node yang tersimpan di momen, atau null bila sudah dibebaskan (dunia
## dibangun ulang saat pindah lokasi atau kunjungan cabang).
static func _alive(v: Variant) -> Node:
	if v == null or not is_instance_valid(v):
		return null
	return v as Node


## Selesaikan semua momen sekarang (tes, dunia dibangun ulang).
func finish_all() -> void:
	for w: Dictionary in welcomes:
		_end_welcome(w)
	welcomes.clear()
	for d: Dictionary in deliveries:
		_end_delivery(d)
	deliveries.clear()


func _exit_tree() -> void:
	finish_all()


# ===========================================================================
# STAF BARU
# ===========================================================================

func welcome(staff_id: StringName) -> void:
	if view.cutscene or not sim.staff.actors.has(staff_id):
		return
	var w: Dictionary = {"id": staff_id, "state": "wait", "t": 0.0, "puppet": null, "actor": null, "path": PackedVector2Array(),
		"wp": 0, "bubble": null, "reroute": 0.0}
	if not SettingsManager.reduced_motion():
		view.hidden_actors[staff_id] = true
	welcomes.append(w)


func _store() -> StringName:
	return sim.world.store_floor()


func _door() -> Vector2:
	return GridMath.cell_center(sim.world.location.entrance_cell)


## true bila sambutan `w` sudah selesai.
func _step_welcome(w: Dictionary, delta: float) -> bool:
	var sid: StringName = w["id"]
	# Boneka yang dibebaskan karena dunia dibangun ulang (pindah lokasi,
	# kunjungi cabang) mengakhiri momennya.
	if not sim.staff.actors.has(sid) or (w.get("puppet") != null and _alive(w.get("puppet")) == null):
		_end_welcome(w)
		return true
	var real: SimActor = sim.staff.actors[sid]
	var real_view: ActorView = view.views.get(real.id)
	w["t"] = float(w["t"]) + delta
	match String(w["state"]):
		"wait":
			# Tampilan aslinya dibuat WorldView pada sinkron berikutnya.
			if real_view == null:
				if float(w["t"]) > 1.0:
					_end_welcome(w)
					return true
				return false
			if SettingsManager.reduced_motion():
				_greet_bubble(w, real_view)
				_sparkle_at(real_view.head_anchor(), real.floor_id)
				w["state"] = "still"
				w["t"] = 0.0
				return false
			_start_puppet(w, real_view)
			return false
		"still":
			_place_bubble(w, real_view)
			if float(w["t"]) >= GREET_SECONDS + 0.6:
				_end_welcome(w)
				return true
			return false
		"walk_in":
			_walk(w, delta)
			_sync_puppet(w, delta)
			if (w["actor"] as SimActor).moving:
				return false
			w["state"] = "greet"
			w["t"] = 0.0
			var p: ActorView = _alive(w.get("puppet")) as ActorView
			if p == null:
				_end_welcome(w)
				return true
			(w["actor"] as SimActor).facing = _toward_camera()
			_greet_bubble(w, p)
			_sparkle_at(p.head_anchor(), _store())
			EventBus.sfx.emit(&"customer_happy", _store())
			if p.model != null:
				ProceduralAnimationSystem.happy_jump(p.model)
			return false
		"greet":
			_sync_puppet(w, delta)
			var pv: ActorView = _alive(w.get("puppet")) as ActorView
			if pv == null:
				_end_welcome(w)
				return true
			ProceduralAnimationSystem.wave(pv.model, clampf(minf(float(w["t"]), GREET_SECONDS - float(w["t"])) * 4.0, 0.0, 1.0), float(w["t"]))
			_place_bubble(w, pv)
			if float(w["t"]) < GREET_SECONDS:
				return false
			ProceduralAnimationSystem.end_pose(pv.model)
			_hide_bubble(w)
			w["state"] = "chase"
			w["t"] = 0.0
			w["reroute"] = 0.0
			return false
		"chase":
			return _chase(w, real, delta)
	return false


## Boneka salinan model staf baru, mulai di trotoar di samping pintu.
func _start_puppet(w: Dictionary, real_view: ActorView) -> void:
	var p := ActorView.new()
	add_child(p)
	var dup: Node3D = real_view.puppet_model()
	if dup != null:
		p.bind_model(StringName("welcome_%s" % w["id"]), "welcome|" + String(w["id"]), dup)
	else:
		p.bind(StringName("welcome_%s" % w["id"]), "welcome|" + String(w["id"]), CharacterFactory.spec_for_staff(String(w["id"])))
	var a := SimActor.new()
	a.id = StringName("welcome_%s" % w["id"])
	a.floor_id = _store()
	var door: Vector2 = _door()
	var walk_z: float = StreetPaths.walk_z(sim.world.location.tier)
	# Jalur pembeli: menyusuri garis trotoar, lalu lurus masuk lewat pintu.
	var start := Vector2(door.x + ENTER_FROM, walk_z)
	a.pos = start
	a.facing = Vector2(-1.0, 0.0)
	w["path"] = PackedVector2Array([Vector2(door.x, walk_z), door])
	w["wp"] = 0
	p.global_position = Vector3(start.x, 0.0, start.y)
	w["puppet"] = p
	w["actor"] = a
	w["state"] = "walk_in"
	w["t"] = 0.0
	a.moving = true
	EventBus.sfx.emit(&"door_bell_enter", _store())
	view.camera_rig.soft_focus(Vector3(door.x, 0.0, door.y), 2.6)


func _walk(w: Dictionary, delta: float) -> void:
	var a: SimActor = w["actor"]
	var path: PackedVector2Array = w["path"]
	var i: int = int(w["wp"])
	var budget: float = WALK_SPEED * delta
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
	w["wp"] = i
	a.moving = i < path.size()


func _sync_puppet(w: Dictionary, delta: float) -> void:
	var p: ActorView = _alive(w.get("puppet")) as ActorView
	if p == null:
		return
	p.sync(w["actor"], delta, true)
	p.visible = view.camera_rig.active_floor == _store() and not view.cutscene


## Menyusul aktor asli (atau pintu tangga bila ia di lantai lain), lalu bertukar
## tempat dengannya. true bila selesai.
func _chase(w: Dictionary, real: SimActor, delta: float) -> bool:
	var a: SimActor = w["actor"]
	var upstairs: bool = real.floor_id != _store()
	var target: Vector2 = real.pos
	if upstairs:
		var fd: FloorDefinition = sim.world.location.floor_def(_store())
		target = GridMath.cell_center(fd.portal["access"]) if fd != null and fd.has_portal() else _door()
	w["reroute"] = float(w["reroute"]) - delta
	if float(w["reroute"]) <= 0.0:
		w["reroute"] = REROUTE_SECONDS
		var path := PackedVector2Array()
		for wp: Dictionary in sim.world.find_route(_store(), a.pos, _store(), GridMath.world_to_cell(target), FloorGrid.NAV_STAFF):
			if not bool(wp.get("portal", false)) and StringName(str(wp["floor"])) == _store():
				path.append(wp["pos"])
		path.append(target)
		w["path"] = path
		w["wp"] = 0
	_walk(w, delta)
	_sync_puppet(w, delta)
	var close: bool = a.pos.distance_to(target) <= SWAP_DIST
	if close or float(w["t"]) > CHASE_LIMIT:
		if not upstairs:
			var real_view: ActorView = view.views.get(real.id)
			if real_view != null:
				_sparkle_at(real_view.head_anchor(), real.floor_id)
		_end_welcome(w)
		return true
	return false


## Selesai: aktor asli tampil lagi, boneka dan gelembungnya dibuang.
func _end_welcome(w: Dictionary) -> void:
	view.hidden_actors.erase(w["id"])
	var p: Variant = w.get("puppet")
	if p != null and is_instance_valid(p):
		(p as Node).queue_free()
	w["puppet"] = null
	var b: Variant = w.get("bubble")
	if b != null and is_instance_valid(b):
		(b as Node).queue_free()
	w["bubble"] = null


func _greet_bubble(w: Dictionary, v: ActorView) -> void:
	var def: StaffDefinition = DataRegistry.staff(StringName(str(w["id"])))
	var b := ThoughtBubble.new()
	b.name = "WelcomeLine"
	view.thought_layer().add_child(b)
	var key: String = "ui_staff_welcome_baker" if def != null and def.is_baker() else "ui_staff_welcome_cashier"
	b.show_key(key, {"name": def.display_name if def != null else ""})
	w["bubble"] = b
	_place_bubble(w, v)


func _place_bubble(w: Dictionary, v: ActorView) -> void:
	var b: Variant = w.get("bubble")
	if b == null or not is_instance_valid(b) or v == null or not is_instance_valid(v):
		return
	(b as ThoughtBubble).visible = v.visible
	(b as ThoughtBubble).point_at(view.camera_rig.world_to_screen(v.head_anchor() + Vector3(0.0, WorldView.THOUGHT_ANCHOR_GAP, 0.0)))


func _hide_bubble(w: Dictionary) -> void:
	var b: Variant = w.get("bubble")
	if b != null and is_instance_valid(b):
		(b as Node).queue_free()
	w["bubble"] = null


func _toward_camera() -> Vector2:
	var yaw: float = deg_to_rad(DataRegistry.balf("camera.yaw_degrees"))
	return Vector2(-sin(yaw), -cos(yaw)).normalized()


func _sparkle_at(p: Vector3, floor_id: StringName) -> void:
	var parent: Node3D = view.floors.get(floor_id)
	if parent != null:
		FX.sugar_sparkle(parent, p)


# ===========================================================================
# STASIUN BARU
# ===========================================================================

func deliver(iid: int) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if view.cutscene or e == null or not e.placed:
		return
	if SettingsManager.reduced_motion():
		var top: Vector3 = view.top_of_iid(iid)
		if top != Vector3.INF:
			_sparkle_at(top, e.floor_id)
		return
	var box: AABB = view.furniture_box(iid)
	if box.size == Vector3.ZERO or not view.floors.has(e.floor_id):
		return
	view.hidden_furniture[iid] = true
	var node: Node3D = _alive(view.furniture.get(iid)) as Node3D
	if node != null:
		node.visible = false
	var d: Dictionary = {"iid": iid, "floor": e.floor_id, "t": 0.0, "revealed": false, "landed": false, "peek": false,
		"prev": view.view_floor_override}
	# Stasiun di lantai lain: kamera melihat ke sana sebentar.
	if view.camera_rig.active_floor != e.floor_id:
		view.view_floor_override = e.floor_id
		d["peek"] = true
	var size := Vector3(maxf(box.size.x * 0.92, 0.3), clampf(box.size.y * 0.7, 0.32, 0.8), maxf(box.size.z * 0.92, 0.3))
	var root: Node3D = _build_box(size)
	(view.floors[e.floor_id] as Node3D).add_child(root)
	root.position = Vector3(box.get_center().x, box.position.y + DROP_HEIGHT, box.get_center().z)
	d["box"] = root
	d["base"] = Vector3(box.get_center().x, box.position.y, box.get_center().z)
	d["size"] = size
	d["puffs"] = []
	deliveries.append(d)
	view.camera_rig.soft_focus(d["base"], DROP_SECONDS + DELIVERY_END)


## Kardus berukuran `size` (alas di y = 0) dengan empat tutup berengsel di tepi
## atasnya (`Flap0..3`, rotation.x/z = 0 tertutup) dan selotip di atasnya.
func _build_box(size: Vector3) -> Node3D:
	var root := Node3D.new()
	root.name = "DeliveryBox"
	var mb := MeshBuilder.new()
	mb.rounded_box(Transform3D(Basis.IDENTITY, Vector3(0.0, size.y * 0.5, 0.0)), size, 0.03, CARDBOARD, 1)
	for sx: float in [-1.0, 1.0]:
		mb.box(Transform3D(Basis.IDENTITY, Vector3(sx * (size.x * 0.5 + 0.002), size.y * 0.55, 0.0)), Vector3(0.004, size.y * 0.5, 0.08), TAPE)
	var body: MeshInstance3D = mb.commit("Body", MeshBuilder.MATTE)
	root.add_child(body)
	# Tutup depan/belakang (sepanjang x) dan samping (sepanjang z), berengsel di tepi atas.
	var half_x: float = size.x * 0.5
	var half_z: float = size.z * 0.5
	var specs: Array = [
		[Vector3(0.0, size.y, -half_z), Vector3(size.x - 0.02, 0.012, half_z), Vector3(0.0, 0.006, half_z * 0.5)],
		[Vector3(0.0, size.y, half_z), Vector3(size.x - 0.02, 0.012, half_z), Vector3(0.0, 0.006, -half_z * 0.5)],
		[Vector3(-half_x, size.y - 0.004, 0.0), Vector3(half_x, 0.01, size.z - 0.06), Vector3(half_x * 0.5, 0.005, 0.0)],
		[Vector3(half_x, size.y - 0.004, 0.0), Vector3(half_x, 0.01, size.z - 0.06), Vector3(-half_x * 0.5, 0.005, 0.0)],
	]
	for i in specs.size():
		var hinge := Node3D.new()
		hinge.name = "Flap%d" % i
		hinge.position = specs[i][0]
		root.add_child(hinge)
		var fm := MeshBuilder.new()
		fm.box(Transform3D(Basis.IDENTITY, specs[i][2]), specs[i][1], CARDBOARD.lightened(0.05 if i < 2 else 0.0))
		if i < 2:
			fm.box(Transform3D(Basis.IDENTITY, specs[i][2] + Vector3(0.0, 0.007, 0.0)), Vector3(0.08, 0.002, half_z), TAPE)
		hinge.add_child(fm.commit("Flap", MeshBuilder.MATTE))
	return root


## Kepulan debu kecil di sekitar alas kardus saat mendarat.
func _dust(d: Dictionary) -> void:
	var parent: Node3D = view.floors.get(StringName(str(d["floor"])))
	if parent == null:
		return
	var mb := MeshBuilder.new()
	mb.ellipsoid(Transform3D.IDENTITY, Vector3(0.09, 0.06, 0.09), DUST, 8, 4)
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, mb.arrays())
	var base: Vector3 = d["base"]
	var size: Vector3 = d["size"]
	var puffs: Array = d["puffs"]
	for i in DUST_PUFFS:
		var ang: float = TAU * float(i) / float(DUST_PUFFS) + 0.4
		var dir := Vector3(cos(ang), 0.0, sin(ang))
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = MeshBuilder.material(MeshBuilder.MATTE)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		parent.add_child(mi)
		mi.position = base + Vector3(dir.x * size.x * 0.5, 0.05, dir.z * size.z * 0.5)
		mi.scale = Vector3.ONE * 0.4
		var tw: Tween = mi.create_tween()
		tw.set_parallel(true)
		tw.tween_property(mi, "position", mi.position + dir * 0.35 + Vector3(0.0, 0.12, 0.0), 0.45).set_ease(Tween.EASE_OUT)
		tw.tween_property(mi, "scale", Vector3.ONE * 1.3, 0.2).set_ease(Tween.EASE_OUT)
		tw.chain().tween_property(mi, "scale", Vector3.ONE * 0.01, 0.25).set_ease(Tween.EASE_IN)
		tw.chain().tween_callback(mi.queue_free)
		puffs.append(mi)


## true bila kiriman `d` sudah selesai.
func _step_delivery(d: Dictionary, delta: float) -> bool:
	var iid: int = int(d["iid"])
	if sim.equipment.get_inst(iid) == null:
		_end_delivery(d)
		return true
	var box: Node3D = _alive(d.get("box")) as Node3D
	if box == null or not box.is_inside_tree():
		_end_delivery(d)
		return true
	d["t"] = float(d["t"]) + delta
	var t: float = float(d["t"])
	var base: Vector3 = d["base"]
	# Stasiun tetap tersembunyi walau perabot dibangun ulang di tengah jalan.
	if not bool(d["revealed"]):
		var hidden: Node3D = _alive(view.furniture.get(iid)) as Node3D
		if hidden != null:
			hidden.visible = false
	if t < DROP_SECONDS:
		var k: float = t / DROP_SECONDS
		box.position = base + Vector3(0.0, DROP_HEIGHT * (1.0 - k * k), 0.0)
		return false
	var after: float = t - DROP_SECONDS
	if not bool(d["landed"]):
		d["landed"] = true
		box.position = base
		_dust(d)
		EventBus.sfx.emit(&"storage_close", StringName(str(d["floor"])))
	# Squash saat mendarat, lalu memantul kembali.
	if after < SQUASH_SECONDS:
		var s: float = sin(PI * after / SQUASH_SECONDS)
		box.scale = Vector3(1.0 + 0.16 * s, 1.0 - 0.26 * s, 1.0 + 0.16 * s)
	elif after < REVEAL_AT:
		box.scale = Vector3.ONE
	# Tutup terbuka ke luar.
	var fk: float = clampf((after - FLAPS_AT) / FLAPS_SECONDS, 0.0, 1.0)
	var open: float = ease(fk, -2.0) * 2.2
	for i in 4:
		var f: Node3D = box.get_node_or_null("Flap%d" % i) as Node3D
		if f == null:
			continue
		match i:
			0:
				f.rotation.x = open
			1:
				f.rotation.x = -open
			2:
				f.rotation.z = -open
			3:
				f.rotation.z = open
	# Stasiun melompat keluar, kardus mengecil.
	if after >= REVEAL_AT and not bool(d["revealed"]):
		d["revealed"] = true
		_reveal(d)
	if after >= REVEAL_AT:
		var sk: float = clampf((after - REVEAL_AT) / BOX_SHRINK_SECONDS, 0.0, 1.0)
		box.scale = Vector3.ONE * maxf(0.01, 1.0 - ease(sk, 2.0))
	var end_at: float = DELIVERY_END + (PEEK_HOLD if bool(d["peek"]) else 0.0)
	if after >= end_at:
		_end_delivery(d)
		return true
	return false


func _reveal(d: Dictionary) -> void:
	var iid: int = int(d["iid"])
	view.hidden_furniture.erase(iid)
	var node: Node3D = _alive(view.furniture.get(iid)) as Node3D
	if node == null:
		return
	node.visible = true
	var full: Vector3 = node.scale
	node.scale = full * 0.05
	var tw: Tween = node.create_tween()
	tw.tween_property(node, "scale", full, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var top: Vector3 = view.top_of_iid(iid)
	if top != Vector3.INF:
		_sparkle_at(top, StringName(str(d["floor"])))
	EventBus.sfx.emit(&"tap_boost_pop", StringName(str(d["floor"])))


## Selesai: stasiun tampil, kardus dibuang, kamera kembali ke lantai semula.
func _end_delivery(d: Dictionary) -> void:
	var iid: int = int(d["iid"])
	if not bool(d.get("revealed", false)):
		view.hidden_furniture.erase(iid)
		var node: Node3D = _alive(view.furniture.get(iid)) as Node3D
		if node != null:
			node.visible = true
		d["revealed"] = true
	var box: Variant = d.get("box")
	if box != null and is_instance_valid(box):
		(box as Node).queue_free()
	d["box"] = null
	if bool(d.get("peek", false)) and view.view_floor_override == StringName(str(d["floor"])):
		view.view_floor_override = StringName(str(d["prev"]))
	d["peek"] = false
