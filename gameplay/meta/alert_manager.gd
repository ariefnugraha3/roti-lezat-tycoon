class_name AlertManager
extends SimManager
## AlertManager — alert off-floor & notifikasi peristiwa penting (GDD 30.4, 131).
## Alert diturunkan dari state otoritatif setiap kali diminta; tidak ada salinan
## state gameplay yang disimpan di sini selain penanda staf terhalang.

## staff_id -> {floor_id, until}
var staff_blocked: Dictionary = {}


func new_game() -> void:
	staff_blocked.clear()


## Oven siap/terbakar: notifikasi P1/P0 (GDD 131.1). Kamera tidak dipindah.
func raise_oven(iid: int, kind: StringName) -> void:
	var e: EquipmentInstance = sim.equipment.get_inst(iid)
	if e == null:
		return
	if kind == &"burning":
		EventBus.notify.emit(0, "ui_alert_oven_burning", {"arrow": ""}, &"fire")
	else:
		EventBus.notify.emit(1, "ui_alert_oven_ready", {"arrow": ""}, &"bread")
	EventBus.off_floor_alerts_changed.emit()


func clear_oven(_iid: int) -> void:
	EventBus.off_floor_alerts_changed.emit()


func raise_staff_blocked(staff_id: StringName, floor_id: StringName) -> void:
	staff_blocked[staff_id] = {"floor_id": floor_id, "until": sim.time.sim_seconds + 10.0}
	EventBus.off_floor_alerts_changed.emit()


## Semua alert aktif: [{type, floor_id, iid, priority}] — priority 0 = kritis.
func active_alerts() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for j: ProductionJob in sim.production.sorted_jobs():
		# Langkah yang diurus koki (pesanan dapur, atau sedang dituju koki) tidak
		# memanggil pemain (GDD 23.3).
		if sim.staff.handles(j):
			continue
		if j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP and j.owner_actor_id == PlayerTaskManager.PLAYER_ID:
			var m: EquipmentInstance = sim.equipment.get_inst(j.mixer_id)
			if m != null:
				out.append({"type": &"mixer_ready", "floor_id": m.floor_id, "iid": m.iid, "priority": 2})
		elif j.is_waiting_oven_pickup():
			var o: EquipmentInstance = sim.equipment.get_inst(j.oven_id)
			if o != null:
				var burning: bool = j.stage == ProductionJob.OVERBAKING or j.stage == ProductionJob.BURNT
				out.append({"type": &"oven_burning" if burning else &"oven_ready", "floor_id": o.floor_id,
					"iid": o.iid, "priority": 0 if burning else 1})
	for sid: Variant in staff_blocked.keys():
		var sb: Dictionary = staff_blocked[sid]
		if float(sb["until"]) >= sim.time.sim_seconds:
			out.append({"type": &"staff_access", "floor_id": sb["floor_id"], "iid": -1, "priority": 2})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["priority"]) < int(b["priority"]))
	return out


## Alert yang terjadi di lantai lain dari pemain (GDD 30.4).
func off_floor_alerts(player_floor: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for a: Dictionary in active_alerts():
		if StringName(str(a["floor_id"])) != player_floor:
			out.append(a)
	return out


func step(_dt: float) -> void:
	for sid: Variant in staff_blocked.keys():
		if float((staff_blocked[sid] as Dictionary)["until"]) < sim.time.sim_seconds:
			staff_blocked.erase(sid)
