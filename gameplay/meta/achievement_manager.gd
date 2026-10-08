class_name AchievementManager
extends SimManager
## AchievementManager — pencapaian & hadiah kosmetik (GDD 72.1, 74, 92.1, 118).
## Tidak pernah memberi KR, bahan, atau keuntungan gameplay.

var unlocked: Dictionary = {}
var produced_recipes: Dictionary = {}
var rain_orders_today: int = 0


func new_game() -> void:
	unlocked.clear()
	produced_recipes.clear()
	rain_orders_today = 0


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(String(id))


func _unlock(a: MiscDefinitions.AchievementDefinition) -> void:
	if is_unlocked(a.id):
		return
	unlocked[String(a.id)] = sim.time.day
	sim.decoration.grant(a.reward_id)
	EventBus.achievement_unlocked.emit(a.id)
	EventBus.sfx.emit(&"achievement_unlock", &"")
	EventBus.notify.emit(3, "ui_achievement_unlocked", {"name": Tx.t(String(a.localization_key))}, &"trophy")
	sim.tutorial.on_event(&"achievement")


func _check(pred: Callable) -> void:
	for x: Variant in DataRegistry.achievements():
		var a: MiscDefinitions.AchievementDefinition = x
		if not is_unlocked(a.id) and bool(pred.call(a)):
			_unlock(a)


func check_stat(stat: String) -> void:
	_check(func(a: MiscDefinitions.AchievementDefinition) -> bool:
		var r: Dictionary = a.requirement
		return str(r.get("type", "")) == "stat_at_least" and str(r.get("stat", "")) == stat \
			and sim.statistics.get_stat(stat) >= float(r.get("value", 0)))


func check_balance(balance: float) -> void:
	_check(func(a: MiscDefinitions.AchievementDefinition) -> bool:
		var r: Dictionary = a.requirement
		return str(r.get("type", "")) == "balance_at_least" and balance >= float(r.get("value", 0)))


func check_tier(tier: int) -> void:
	_check(func(a: MiscDefinitions.AchievementDefinition) -> bool:
		var r: Dictionary = a.requirement
		return str(r.get("type", "")) == "location_tier_at_least" and tier >= int(r.get("value", 0)))


func check_condition(condition: StringName) -> void:
	if not _condition_met(condition):
		return
	_check(func(a: MiscDefinitions.AchievementDefinition) -> bool:
		var r: Dictionary = a.requirement
		return str(r.get("type", "")) == "condition" and StringName(str(r.get("condition", ""))) == condition)


func _condition_met(condition: StringName) -> bool:
	match condition:
		&"rotifood_five_stars":
			return sim.reputation.rotifood >= DataRegistry.balf("rating.max") - 0.0001
		&"all_recipes_produced":
			return produced_recipes.size() >= DataRegistry.recipes().size()
		&"price_experiment":
			return sim.pricing.experiment_low_sold and sim.pricing.experiment_high_sold
		&"big_day":
			return float(sim.statistics.today.get("revenue", 0.0)) > DataRegistry.balf("achievements.big_day_revenue_kr")
		&"solo_recovery":
			return sim.bailout.bailout_count > 0 and sim.economy.balance > DataRegistry.balf("achievements.solo_recovery_balance_kr")
		&"economy_overflow":
			return sim.economy.overflowed
		&"rain_delivery_day":
			return sim.weather.is_rain() and rain_orders_today >= DataRegistry.bali("achievements.rain_delivery_orders")
		&"no_burn_day", &"no_abandon_day":
			return true
	return false


func note_recipe_produced(recipe_id: StringName) -> void:
	produced_recipes[String(recipe_id)] = true
	check_condition(&"all_recipes_produced")


func on_rotifood_completed() -> void:
	if sim.weather.is_rain():
		rain_orders_today += 1
		check_condition(&"rain_delivery_day")


## Settlement: pencapaian harian.
func end_day(burnt_batches: int, abandoned: int) -> void:
	if burnt_batches == 0 and sim.production.completed_today.size() > 0:
		check_condition(&"no_burn_day")
	if abandoned == 0 and sim.customers.served_today > 0:
		check_condition(&"no_abandon_day")
	check_stat("no_burn_streak_days")
	rain_orders_today = 0


func capture() -> Dictionary:
	return {"unlocked": unlocked.duplicate(), "produced_recipes": produced_recipes.keys(), "rain_orders_today": rain_orders_today}


func restore(d: Dictionary) -> void:
	new_game()
	unlocked = (d.get("unlocked", {}) as Dictionary).duplicate()
	for r: Variant in d.get("produced_recipes", []):
		produced_recipes[str(r)] = true
	rain_orders_today = int(d.get("rain_orders_today", 0))
