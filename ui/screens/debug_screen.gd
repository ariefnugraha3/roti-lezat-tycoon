class_name DebugScreen
extends UIScreen
## Panel debug (GDD 39): hanya di debug build. Tidak ada di release export.

var _out: Label = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_debug_title"), Vector2(640, 900))
	lbl(body, "day_seed: %d · master_seed: %d" % [sim.rng.day_seed, sim.rng.master_seed], 14, Palette.TEXT_MUTED)
	var grid := GridContainer.new()
	grid.columns = 2
	body.add_child(grid)
	var cmds: Array = [
		["+1K KR", func() -> void: sim.debug_add_kr(1000.0)],
		["+1M KR", func() -> void: sim.debug_add_kr(1.0e6)],
		["+1 h", func() -> void: sim.debug_set_time(sim.time.time_seconds + 3600.0)],
		["Rain", func() -> void: sim.debug_force_weather(&"weather_rain")],
		["Sun", func() -> void: sim.debug_force_weather(&"weather_sunny")],
		["Customer", func() -> void: sim.debug_spawn_customer(&"customer_generic")],
		["RotiFood order", func() -> void: sim.debug_spawn_order()],
		["Finish stations", func() -> void: sim.production.debug_complete_all()],
		["Reputation 5", func() -> void: sim.debug_set_reputation(5.0)],
		["Reputation 1", func() -> void: sim.debug_set_reputation(1.0)],
		["Ledger", func() -> void: _out.text = JSON.stringify(sim.debug_ledger_dump().slice(-8), " ")],
		["Jobs", func() -> void: _out.text = JSON.stringify(sim.debug_jobs_dump(), " ")],
		["Invariants", func() -> void: _out.text = "OK" if sim.check_invariants() == "" else sim.check_invariants()],
	]
	for c: Array in cmds:
		var b: Button = ProceduralUIFactory.button(str(c[0]), "secondary")
		b.pressed.connect(c[1])
		b.custom_minimum_size = Vector2(280, 48)
		grid.add_child(b)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(sc)
	_out = ProceduralUIFactory.label("", 12, Palette.TEXT)
	_out.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_out.custom_minimum_size = Vector2(580, 0)
	sc.add_child(_out)
