extends TestSuite
## Tanpa bar kesabaran (keputusan maintainer 2026-11-04, GDD idle 6.4): toko
## idle berjalan sendiri, jadi pembeli yang mengantre dan driver RotiFood tidak
## lagi memamerkan bar di atas kepala. Kesabarannya tetap berkurang di simulasi,
## dan pembeli yang kesabarannya habis tetap pulang.


func tests() -> Array:
	return [
		{"id": "ACC_20_NO_PATIENCE_BAR", "name": "idle 6.4 a queuing buyer shows no patience bar above the head, yet their patience still runs down and they leave when it runs out", "fn": _no_bar},
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
	while not c.drains_patience() and t < 120.0:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
		t += s.tick_seconds
	check(c.drains_patience(), "the buyer reaches the cashier queue")
	var v: ActorView = world.views.get(c.id)
	world._process(0.016)
	check(v != null and not _has_bar(v), "no patience bar above a queuing buyer")
	var first: float = c.patience_ratio()
	for i in 200:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
	check(c.patience_ratio() < first - 0.1, "patience still runs down while waiting (%.2f -> %.2f)" % [first, c.patience_ratio()])
	check(v != null and not _has_bar(v), "and still no bar")
	var lost: float = s.statistics.get_stat("total_customers_lost_patience")
	while c.drains_patience() and t < 600.0:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
		t += s.tick_seconds
	eq(s.statistics.get_stat("total_customers_lost_patience"), lost + 1.0, "a buyer whose patience runs out still leaves")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)
