class_name SlotPickerScreen
extends UIScreen
## Pemilih Petak Rak (GDD 7, 19.3, 85): kisi tombol sebanyak petak rak yang
## sesungguhnya, kiri ke kanan. Satu loyang boleh disebar ke beberapa petak;
## layar tidak menutup sampai loyangnya habis. Petak resep sama disorot dulu.

var _grid: GridContainer = null
var _info: Label = null


func build() -> void:
	var body: VBoxContainer = make_popup(Tx.t("ui_slot_picker_title"), Vector2(980, 560))
	_info = lbl(body, "", 18, Palette.UI_WOOD, true)
	_grid = GridContainer.new()
	_grid.add_theme_constant_override("h_separation", 12)
	_grid.add_theme_constant_override("v_separation", 12)
	_grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_grid)
	_render()


func _iid() -> int:
	return int(params.get("display", -1))


func _render() -> void:
	clear(_grid)
	var j: ProductionJob = sim.player.carried_job()
	if j == null:
		close()
		return
	_info.text = Tx.t("ui_slot_picker_tray", {"count": j.carried_units, "recipe": Tx.recipe_name(j.recipe_id)})
	var iid: int = _iid()
	var slots: Array = sim.display.slots(iid)
	var per_row: int = mini(6, slots.size())
	_grid.columns = maxi(1, per_row)
	var def: EquipmentDefinition = sim.display.def_of(iid)
	for i in slots.size():
		var s: Dictionary = slots[i]
		var units: int = sim.display.slot_units(iid, i)
		var room: int = sim.display.slot_room(iid, i, j.recipe_id)
		var same: bool = s["recipe"] == j.recipe_id and units > 0
		var kind: String = "primary" if same else ("secondary" if room > 0 else "ghost")
		var text: String = Tx.t("ui_slot_empty") if units == 0 else "%s\n%s" % [Tx.recipe_name(s["recipe"]), Tx.t("ui_slot_fill", {"count": units, "max": def.max_per_slot})]
		var b: Button = ProceduralUIFactory.button(text, kind)
		b.custom_minimum_size = Vector2(140, 110)
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.add_theme_font_size_override("font_size", ProceduralUIFactory.scaled(15))
		b.disabled = room <= 0
		var idx: int = i
		b.pressed.connect(func() -> void: _place(idx))
		_grid.add_child(b)


func _place(index: int) -> void:
	var j: ProductionJob = sim.player.carried_job()
	if j == null:
		close()
		return
	var n: int = sim.player.place_into_slot(_iid(), index, j.carried_units)
	if n <= 0:
		EventBus.sfx.emit(&"ui_error", &"")
	if sim.player.carried_job() == null:
		close()
		return
	_render()


func on_closed() -> void:
	sim.player.close_slot_picker()
