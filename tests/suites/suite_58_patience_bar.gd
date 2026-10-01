extends TestSuite
## Bar kesabaran di atas kepala pembeli (GDD 20.8, keputusan maintainer
## 2026-10-01). Laporan: bar tampak tidak berjalan. Ternyata isinya tidak pernah
## tergambar (latar cokelat menutupinya), dan bar penuh yang diam sudah tampil
## sejak pembeli masuk. Kini bar hanya tampil selama pembeli mengantre di kasir.


func tests() -> Array:
	return [
		{"id": "ACC_20_PATIENCE_BAR_QUEUE_ONLY", "name": "20.8 a buyer's patience bar shows only while they queue at the cashier and follows their patience; entering, browsing and leaving buyers show none", "fn": _queue_only},
		{"id": "TEST_VIS_PATIENCE_FILL_ON_TOP", "name": "20.8 the patience fill draws on top of its dark backing, so the bar visibly runs down", "fn": _fill_on_top},
	]


func _open_store(seed_value: int) -> SimulationRoot:
	var s: SimulationRoot = new_sim(seed_value)
	s.demand.scripted_walkins.clear()
	s.demand.scripted_orders.clear()
	s.demand.scripted_window_shoppers.clear()
	run_until(s, 8.0 * 3600.0 + 10.0)
	return s


func _queue_only() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = _open_store(5811)
	stock(s, &"recipe_plain_loaf", 6)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	world._process(0.016)
	s.customers.try_admit({"archetype": &"customer_generic", "scripted": false, "recipe": &"", "quantity": 1, "patience_override": null})
	var c: Customer = s.customers.sorted()[0]
	var seen_before_queue: Dictionary = {}
	var t: float = 0.0
	while not c.drains_patience() and t < 120.0:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
		t += s.tick_seconds
		var v0: ActorView = world.views.get(c.id)
		if v0 != null and not c.drains_patience():
			seen_before_queue[c.state] = v0._patience != null and v0._patience.visible
	check(c.drains_patience(), "the buyer reaches the cashier queue")
	for st: Variant in seen_before_queue.keys():
		check(not bool(seen_before_queue[st]), "no patience bar while %s" % st)
	check(seen_before_queue.has(Customer.BROWSING) or seen_before_queue.has(Customer.ENTERING), "the buyer was drawn before queueing")
	# Mengantre tanpa dilayani: bar tampil dan mengikuti kesabaran.
	var v: ActorView = world.views.get(c.id)
	world._process(0.016)
	check(v != null and v._patience != null and v._patience.visible, "the bar appears in the cashier queue")
	var first: float = c.patience_ratio()
	for i in 200:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
	check(c.patience_ratio() < first - 0.1, "patience runs down while waiting (%.2f -> %.2f)" % [first, c.patience_ratio()])
	# Lebar isi diperbarui di _process bar itu sendiri (satu frame mesin).
	await runner.get_tree().process_frame
	if v != null and v._patience != null:
		near((v._patience as ActorView.PatienceBar).fill_ratio(), c.patience_ratio(), 0.02, "the fill follows the patience ratio")
	# Kesabaran habis: pergi, dan bar hilang.
	while c.drains_patience() and t < 600.0:
		s.step(s.tick_seconds)
		world._process(s.tick_seconds)
		t += s.tick_seconds
	world._process(0.016)
	var v2: ActorView = world.views.get(c.id)
	check(v2 == null or v2._patience == null or not v2._patience.visible, "the bar disappears once the buyer gives up and leaves")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


func _fill_on_top() -> void:
	var view := ActorView.new()
	runner.add_child(view)
	view.bind(&"bar_test", "bar_test", CharacterFactory.spec_for_customer("customer_generic", 3, false))
	view.set_patience(0.4, true, false)
	await runner.get_tree().process_frame
	var bar: ActorView.PatienceBar = view._patience
	var back: MeshInstance3D = bar.get_node("Back") as MeshInstance3D
	var fill: MeshInstance3D = bar.get_node("Fill") as MeshInstance3D
	var back_mat: BaseMaterial3D = back.material_override as BaseMaterial3D
	var fill_mat: BaseMaterial3D = fill.material_override as BaseMaterial3D
	check(back_mat.no_depth_test and fill_mat.no_depth_test, "both layers ignore depth, so the draw order decides what shows")
	check(fill_mat.render_priority > back_mat.render_priority, "the fill is drawn after (on top of) the backing")
	near(bar.fill_ratio(), 0.4, 0.001, "the fill is 40% wide at 40% patience")
	view.queue_free()
	await runner.get_tree().process_frame
