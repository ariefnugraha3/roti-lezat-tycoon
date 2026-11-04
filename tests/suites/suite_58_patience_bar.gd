extends TestSuite
## Tanpa kesabaran pembeli (keputusan maintainer 2026-11-04, GDD idle 6.4): toko
## idle berjalan sendiri, jadi pembeli yang mengantre menunggu sampai dilayani
## dan tidak ada bar di atas kepala pembeli maupun driver RotiFood.


func tests() -> Array:
	return [
		{"id": "ACC_20_NO_PATIENCE_BAR", "name": "idle 6.4 a queuing buyer shows no patience bar above the head and keeps waiting until served", "fn": _no_bar},
	]


## Toko tanpa kedatangan acak dan tanpa pelayan, supaya pembeli uji menunggu.
func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	freeze_production(s)
	park_owner(s)
	s.demand.next_physical_at = NEVER
	s.demand.next_rotifood_at = NEVER
	s.demand.next_window_shopper_at = NEVER
	return s


## Tidak ada bar (quad tembus tanpa uji kedalaman) di atas kepala tampilan `v`.
static func _has_bar(v: ActorView) -> bool:
	for n: Node in v.find_children("*", "MeshInstance3D", true, false):
		var mat: BaseMaterial3D = (n as MeshInstance3D).material_override as BaseMaterial3D
		if mat != null and mat.no_depth_test and mat.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA and (n as MeshInstance3D).mesh is BoxMesh:
			return true
	return false


func _no_bar() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(5811)
	stock(s, &"recipe_plain_loaf", 6)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	s.customers.try_admit({"archetype": &"customer_generic"})
	var c: Customer = s.customers.sorted()[0]
	var t: float = 0.0
	while not c.is_waiting() and t < 120.0:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
		t += s.tick_seconds
	check(c.is_waiting(), "the buyer reaches the cashier queue")
	var v: ActorView = world.views.get(c.id)
	world._process(0.016)
	check(v != null and not _has_bar(v), "no patience bar above a queuing buyer")
	for i in 1200:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
	check(c.is_waiting() and s.customers.customer(c.id) != null, "a minute later the buyer is still in line")
	check(v != null and not _has_bar(v), "still without a bar")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
