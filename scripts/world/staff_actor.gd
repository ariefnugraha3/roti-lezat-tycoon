class_name StaffActor
extends ActorBase
## Karyawan yang terlihat bekerja di dalam toko.
##
## Kasir berdiri di meja kasir; baker mondar-mandir antara gudang, mixer, oven,
## dan rak display. Gerakannya murni kosmetik — produksi sebenarnya dihitung
## ProductionSystem/StaffSim — tapi ritmenya mengikuti keadaan sim supaya toko
## terasa hidup dan pemain bisa membaca situasi sekilas.

var staff_id: String = ""
var role: String = "kasir"
var tier: int = 1

## Pos kerja tetap (kasir) atau titik pangkal (baker).
var home_pos: Vector3 = Vector3.ZERO
## Titik-titik kerja baker, diisi ShopWorld: {"mixer": [...], "oven": [...], "display": [...]}
var stations: Dictionary = {}

var _busy: bool = false
var _loop_t: float = 0.0


func setup_staff(id: String) -> void:
	staff_id = id
	var e: Dictionary = StaffDB.entry(id)
	role = String(e.get("role", "kasir"))
	tier = int(e.get("tier", 1))
	build_from_spec(CharacterFactory.spec_for_staff(id))
	# Karyawan tier tinggi bergerak lebih gesit (GDD 3.1/3.2 work speed).
	walk_speed = WALK_SPEED * (0.9 + 0.09 * float(tier))


## Menandai karyawan sedang melayani/memproduksi. Dipakai untuk ekspresi & pose.
func set_busy(v: bool) -> void:
	if _busy == v:
		return
	_busy = v
	if model != null and is_instance_valid(model):
		CharacterFactory.set_expression(model, "senang" if v else "netral")


func is_busy() -> bool:
	return _busy


## Karyawan yang sedang diliburkan (Mode Solo, GDD 3.0.C) ditampilkan redup
## dan tidak bergerak.
func set_on_leave(on_leave: bool) -> void:
	visible = not on_leave
	if on_leave:
		clear_path()


func tick(delta: float) -> void:
	super.tick(delta)
	_loop_t += delta

	if role == "kasir":
		# Kasir tetap di mejanya; saat sibuk ia mengangguk cepat seolah menghitung.
		if _busy and model != null and is_instance_valid(model):
			var head: Node3D = CharacterFactory.part(model, "Head")
			if head != null:
				head.rotation.x = sin(_loop_t * 9.0) * 0.10
		return

	# Baker: kalau tidak ada rute, buat rute keliling stasiun kerja.
	if waypoints.is_empty() and _busy:
		_patrol_stations()


func _patrol_stations() -> void:
	var mixers: Array = stations.get("mixer", [])
	var ovens: Array = stations.get("oven", [])
	var displays: Array = stations.get("display", [])
	if mixers.is_empty() and ovens.is_empty() and displays.is_empty():
		return
	# Urutan kerja nyata seorang baker: aduk -> panggang -> tata ke etalase.
	if not mixers.is_empty():
		goto(mixers[0] as Vector3, "mixer", 0.8)
	if not ovens.is_empty():
		goto(ovens[0] as Vector3, "oven", 0.9)
	if not displays.is_empty():
		goto(displays[0] as Vector3, "display", 0.6)
	if home_pos != Vector3.ZERO:
		goto(home_pos, "home", 0.4)
