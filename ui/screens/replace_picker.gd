class_name ReplacePicker
extends UIScreen
## Pilih alat terpasang yang diganti (GDD 5.1.2 Replace): satu tombol per alat
## sekategori yang terpasang. Alat yang sedang dipakai (IN_USE, Seksi 72) tidak
## bisa dipilih. Berada di atas Pasar sebagai overlay (GDD 28.2), jadi Pasar
## tetap terbuka di bawahnya.


func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var def: EquipmentDefinition = DataRegistry.equipment(StringName(str(params.get("def_id", ""))))
	var body: VBoxContainer = make_popup(Tx.t("ui_equipment_pick_replace"), Vector2(640, 460), false)
	if def != null:
		lbl(body, Tx.t("ui_equipment_replace_note", {"item": Tx.item_name(def.id), "price": Tx.kr(def.price_kr)}), 17, Palette.TEXT, true)
	var list: VBoxContainer = scroll_box(body)
	for v: Variant in params.get("candidates", []):
		var iid: int = int(v)
		var e: EquipmentInstance = sim.equipment.get_inst(iid)
		if e == null:
			continue
		var busy: bool = sim.equipment.is_in_use(iid)
		var text: String = "%s · T%d" % [Tx.item_name(e.def_id), e.tier()]
		if busy:
			text += " · " + Tx.t("ui_feedback_in_use")
		var b: Button = btn(list, text, "secondary", _pick.bind(iid))
		b.name = "Pick_%d" % iid
		b.custom_minimum_size = Vector2(0.0, 56.0)
		b.disabled = busy
	var row: HBoxContainer = hbox(body, 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var cancel: Button = btn(row, Tx.t("ui_cancel"), "secondary", _cancel)
	cancel.name = "Cancel"


func _pick(iid: int) -> void:
	var cb: Callable = params.get("on_pick", Callable())
	close()
	if cb.is_valid():
		cb.call(iid)


func _cancel() -> void:
	EventBus.sfx.emit(&"ui_cancel", &"")
	close()
