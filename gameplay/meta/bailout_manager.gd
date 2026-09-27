class_name BailoutManager
extends SimManager
## BailoutManager — financial distress, bantuan Pak Lurah, dan Mode Solo
## (GDD 3.0, 24.7, 49). Tidak ada Game Over: kas habis berujung bantuan,
## bukan kekalahan. Bailout tidak pernah menurunkan rating.

var bailout_pending: bool = false
var repeat_visit: bool = false
var solo_mode: bool = false
var bailout_count: int = 0
var last_bailout_day: int = -100
var solo_start_day: int = -1
var wage_warning: bool = false
## Bailout baru saja diterapkan pagi ini; UI memutar cutscene sekali.
var cutscene_pending: bool = false


func new_game() -> void:
	bailout_pending = false
	repeat_visit = false
	solo_mode = false
	bailout_count = 0
	last_bailout_day = -100
	solo_start_day = -1
	wage_warning = false
	cutscene_pending = false


## Resep yang tier alatnya dimiliki pemain (GDD 49.1).
func producible_recipes() -> Array[RecipeDefinition]:
	var out: Array[RecipeDefinition] = []
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.production.owns_equipment_for(r):
			out.append(r)
	return out


func cheapest_producible_batch_cost() -> float:
	var best: float = INF
	for r: RecipeDefinition in producible_recipes():
		best = minf(best, r.batch_cost_kr)
	return best if best < INF else 0.0


## Cek setelah settlement 18:00 (GDD 49.1). "Stok bahan" diuji sebagai
## kombinasi yang benar-benar menyelesaikan satu batch.
func check_after_settlement() -> void:
	var can_operate: bool = false
	for r: RecipeDefinition in producible_recipes():
		if sim.inventory.missing_cost(r) <= sim.economy.balance + 0.0001:
			can_operate = true
			break
	var has_display: bool = _sellable_after_overnight()
	if not can_operate and not has_display:
		bailout_pending = true
		repeat_visit = sim.time.day - last_bailout_day <= int(DataRegistry.bal("bailout.repeat_window_days"))
	# Peringatan lunak: kas < gaji terjadwal tetapi masih bisa beli bahan (GDD 3.0.E).
	wage_warning = sim.economy.balance < sim.staff.scheduled_wages() and sim.economy.balance >= cheapest_producible_batch_cost()


func _sellable_after_overnight() -> bool:
	var hours: float = DataRegistry.balf("clock.overnight_aging_hours")
	for iid: Variant in sim.display.display_ids():
		var rate: float = sim.display.def_of(int(iid)).aging_rate
		for s: Dictionary in sim.display.slots(int(iid)):
			for st: BreadStack in s["stacks"]:
				if st.quantity > 0 and (st.age_ingame_hours + hours * rate) / st.base_expiry_hours < DataRegistry.balf("freshness.unsaleable_ratio"):
					return true
	return false


## 05:00 esok hari: terapkan bantuan tepat sekali (GDD 45.2, 49.2).
func apply_if_pending() -> void:
	if not bailout_pending:
		return
	bailout_pending = false
	sim.economy.credit(DataRegistry.balf("bailout.grant_kr"), &"BAILOUT_GRANT", &"pak_lurah", {"repeat": repeat_visit})
	sim.inventory.add_items(DataRegistry.bal("bailout.emergency_ingredients"))
	sim.staff.put_all_off_duty()
	solo_mode = true
	solo_start_day = sim.time.day
	bailout_count += 1
	last_bailout_day = sim.time.day
	cutscene_pending = true
	sim.statistics.add(&"bailout_count", 1)
	GameLogger.important("ECONOMY", "bailout applied (repeat=%s)" % repeat_visit)
	EventBus.bailout_cutscene_requested.emit(repeat_visit)


## Mode Solo berakhir saat pemain kembali punya staf bertugas (GDD 49.3), atau
## bila tidak ada kontrak sama sekali dan kas sudah pulih.
func begin_day_check() -> void:
	if solo_mode and not sim.staff.working_ids().is_empty():
		solo_mode = false


func note_balance(balance: float) -> void:
	if bailout_count > 0 and balance > DataRegistry.balf("achievements.solo_recovery_balance_kr"):
		sim.achievements.check_condition(&"solo_recovery")


func capture() -> Dictionary:
	return {"bailout_pending": bailout_pending, "repeat_visit": repeat_visit, "solo_mode": solo_mode,
		"bailout_count": bailout_count, "last_bailout_day": last_bailout_day, "solo_start_day": solo_start_day,
		"wage_warning": wage_warning, "cutscene_pending": cutscene_pending}


func restore(d: Dictionary) -> void:
	bailout_pending = bool(d.get("bailout_pending", false))
	repeat_visit = bool(d.get("repeat_visit", false))
	solo_mode = bool(d.get("solo_mode", false))
	bailout_count = int(d.get("bailout_count", 0))
	last_bailout_day = int(d.get("last_bailout_day", -100))
	solo_start_day = int(d.get("solo_start_day", -1))
	wage_warning = bool(d.get("wage_warning", false))
	cutscene_pending = bool(d.get("cutscene_pending", false))
