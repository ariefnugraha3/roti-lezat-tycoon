class_name DriverActor
extends ActorBase
## Driver Ojek Online yang menjemput pesanan RotiFood (GDD 3.6).
##
## Seragam hijau toska pastel, helm bundar, ransel termal kubus. Saat hari hujan
## seragamnya otomatis berganti jas hujan kuning (GDD 10.2) — itu ditentukan saat
## dibangun lewat spec_for_driver(rainy).

## Id pesanan di DeliverySim.
var order_id: int = -1
var rainy: bool = false

var _bag: Node3D = null
var _waiting_t: float = 0.0
var _impatient: bool = false


func setup_driver(order: Dictionary, is_rainy: bool) -> void:
	order_id = int(order.get("id", -1))
	rainy = is_rainy
	build_from_spec(CharacterFactory.spec_for_driver(is_rainy))
	# Driver selalu bergegas — ia dikejar tenggat pengantaran.
	walk_speed = WALK_SPEED * 1.4


func tick(delta: float) -> void:
	super.tick(delta)
	# Menunggu terlalu lama: driver mulai gelisah (GDD 9.2 penalti -0.1 bintang
	# setelah 10 detik), ditandai tetes keringat sekali saja.
	if waypoints.is_empty() and not is_walking and order_id >= 0:
		_waiting_t += delta
		if _waiting_t > 10.0 and not _impatient:
			_impatient = true
			react("kesal")
			FX.sweat_drop(self)


## Serah terima berhasil: driver menerima paper bag, melambai, lalu pergi.
func receive_bag() -> void:
	_waiting_t = 0.0
	_impatient = false
	if _bag == null or not is_instance_valid(_bag):
		_bag = BreadFactory.build_paper_bag()
		if _bag != null:
			_bag.position = Vector3(0.16, 0.38, 0.10)
			add_child(_bag)
	react("senang")
	FX.sugar_sparkle(self, Vector3(0.0, 0.6, 0.0))
	AudioBus.sfx("pop")


## Pesanan dibatalkan: driver pergi kecewa (GDD 3.6.C animasi sweat drop).
func reject() -> void:
	react("sedih")
	FX.sweat_drop(self)
	AudioBus.sfx("sad")
