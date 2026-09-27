class_name TutorialManager
extends SimManager
## TutorialManager — timeline Hari 1-3 (GDD 27, 88, 127.5). Mengajar lewat aksi
## dunia; hard-block hanya di awal Hari 1 sampai Storage dipilih. Setiap langkah
## auto-complete bila kondisinya sudah tercapai lebih dulu. Skip tidak mengubah
## demand terjadwal (GDD 27.6).

## Prompt aktif: {key, modal, highlight_kind, highlight_iid}
var prompt: Dictionary = {}
var done: Dictionary = {}
var skipped: bool = false
var _queue: Array[Dictionary] = []


func new_game() -> void:
	prompt = {}
	done.clear()
	skipped = false
	_queue.clear()


func active() -> bool:
	return not skipped and sim.time.day <= 3


func hints_enabled() -> bool:
	if skipped:
		return false
	if sim.time.day > 3:
		return SettingsManager.get_bool("tutorial_hints")
	return true


func skip() -> void:
	skipped = true
	prompt = {}
	_queue.clear()
	EventBus.tutorial_step_changed.emit(&"")


## Hard-block Hari 1: input dunia lain nonaktif sampai Storage dipilih (GDD 88.1 no. 2).
func allows_tap(kind: StringName) -> bool:
	if not active() or sim.time.day != 1 or done.has("storage_opened"):
		return true
	return kind == &"storage"


func _show(key: String, modal: bool, highlight_kind: StringName = &"", once_key: String = "") -> void:
	var k: String = once_key if once_key != "" else key
	if done.has(k) or not hints_enabled():
		return
	done[k] = true
	var p: Dictionary = {"key": key, "modal": modal, "highlight_kind": String(highlight_kind), "highlight_iid": _iid_for(highlight_kind)}
	if prompt.is_empty() or not bool(prompt.get("modal", false)):
		prompt = p
		EventBus.tutorial_step_changed.emit(StringName(key))
	else:
		_queue.append(p)


func _iid_for(kind: StringName) -> int:
	if kind == &"" or kind == &"cashier" or kind == &"tablet":
		return -1
	var l: Array[EquipmentInstance] = sim.equipment.placed_list(kind)
	return l[0].iid if not l.is_empty() else -1


## Pemain menutup prompt (tombol "Got it" atau langkah berikut tercapai).
func dismiss() -> void:
	prompt = {}
	if not _queue.is_empty():
		prompt = _queue.pop_front()
	EventBus.tutorial_step_changed.emit(StringName(str(prompt.get("key", ""))))


func _hint_done(key: String) -> void:
	if str(prompt.get("key", "")) == key and not bool(prompt.get("modal", false)):
		dismiss()


func begin_day() -> void:
	if not active():
		return
	match sim.time.day:
		1:
			_show("tut_welcome", true)
			_show("tut_tap_storage", false, &"storage")
		2:
			_show("tut_day2_prep", false)
		3:
			_show("tut_day3_balance", true)


func on_event(ev: StringName) -> void:
	if skipped:
		return
	done["ev_" + String(ev)] = true
	match ev:
		&"storage_opened":
			done["storage_opened"] = true
			_hint_done("tut_tap_storage")
			_show("tut_choose_recipe", false)
		&"recipe_ordered":
			_hint_done("tut_choose_recipe")
			_show("tut_tap_mixer", false, &"mixer")
		&"mixing_started":
			_hint_done("tut_tap_mixer")
			_show("tut_equipment_works", false)
		&"mixer_done":
			_hint_done("tut_equipment_works")
			_show("tut_mixer_done", false, &"mixer")
		&"dough_picked":
			_hint_done("tut_mixer_done")
			_show("tut_to_oven", false, &"oven")
		&"oven_inserted":
			_hint_done("tut_to_oven")
		&"oven_ready":
			_show("tut_burn_risk", true, &"oven")
		&"tray_picked":
			_show("tut_choose_slot", false, &"display")
		&"bread_placed":
			_hint_done("tut_choose_slot")
		&"near_burn":
			if sim.time.day >= 2:
				_show("tut_smart_speed", false)
		&"customer_queued":
			if sim.queue.main_lane() != null and sim.queue.main_lane().reservations.size() >= 2 and sim.time.day >= 2:
				_show("tut_queue_capacity", false)
		&"player_at_cashier", &"manual_service_started":
			_hint_done("tut_manual_cashier")
		&"first_payment":
			_show("tut_income", false)
		&"rotifood_order":
			_show("tut_rotifood", true, &"tablet")
		&"summary":
			_show("tut_summary", true)
			if sim.time.day == 3:
				_show("tut_market_unlock", true)
				_show("tut_market_teaser", false)
		&"pricing_opened":
			if sim.time.day >= 2:
				_show("tut_pricing", false)
		&"store_open":
			if sim.time.day == 2 and sim.inventory.is_empty():
				_show("tut_fried_bread_stale", false)


func on_customer_entered(c: Customer) -> void:
	if skipped:
		return
	_show("tut_patience", true)
	if c.archetype == &"customer_office_worker":
		_show("tut_office_worker", false)


func on_customer_front(_c: Customer) -> void:
	if sim.staff.any_cashier_working():
		return
	_show("tut_manual_cashier", false, &"cashier")


func on_freshness_changed(state: StringName) -> void:
	if state == &"GOOD" and sim.time.day <= 3:
		_show("tut_freshness", true)


## Arsip bantuan: kunci prompt yang sudah pernah tampil (GDD 27.6 replay).
func archive() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in done.keys():
		var s: String = str(k)
		if s.begins_with("tut_"):
			out.append(s)
	return out


func capture() -> Dictionary:
	return {"done": done.keys(), "skipped": skipped, "prompt": prompt.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	for k: Variant in d.get("done", []):
		done[str(k)] = true
	skipped = bool(d.get("skipped", false))
	prompt = (d.get("prompt", {}) as Dictionary).duplicate()
