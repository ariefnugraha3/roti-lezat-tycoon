class_name AnalyticsManager
extends SimManager
## AnalyticsManager — analitik seumur hidup per resep (GDD 92.4, 118). Hanya
## diperbarui dari event otoritatif yang sudah di-commit, tidak dari prediksi UI.

var per_recipe: Dictionary = {}
## Catatan harian terperinci: [{day, sold: {recipe: units}}], maksimal 1.000 hari.
var daily: Array = []
var _today_sold: Dictionary = {}


func new_game() -> void:
	per_recipe.clear()
	daily.clear()
	_today_sold.clear()


func _entry(recipe_id: StringName) -> Dictionary:
	var k: String = String(recipe_id)
	if not per_recipe.has(k):
		per_recipe[k] = {
			"batches_started": 0, "batches_completed": 0, "units_produced": 0,
			"units_sold_physical": 0, "units_sold_rotifood": 0, "units_wasted_burnt": 0,
			"units_wasted_expired": 0, "stale_sold_units": 0, "gross_revenue_kr": 0.0,
			"ingredient_cost_allocated_kr": 0.0, "highest_single_day_units_sold": 0,
		}
	return per_recipe[k]


func note_batch_started(recipe_id: StringName) -> void:
	var e: Dictionary = _entry(recipe_id)
	e["batches_started"] = int(e["batches_started"]) + 1


func note_batch_completed(recipe_id: StringName, units: int) -> void:
	var e: Dictionary = _entry(recipe_id)
	e["batches_completed"] = int(e["batches_completed"]) + 1
	e["units_produced"] = int(e["units_produced"]) + units


func note_sold(recipe_id: StringName, units: int, revenue: float, channel: StringName, stale: bool) -> void:
	var e: Dictionary = _entry(recipe_id)
	var key: String = "units_sold_physical" if channel == &"physical" else "units_sold_rotifood"
	e[key] = int(e[key]) + units
	e["gross_revenue_kr"] = float(e["gross_revenue_kr"]) + revenue
	e["ingredient_cost_allocated_kr"] = float(e["ingredient_cost_allocated_kr"]) + DataRegistry.recipe(recipe_id).unit_cogs_kr() * units
	if stale:
		e["stale_sold_units"] = int(e["stale_sold_units"]) + units
	_today_sold[String(recipe_id)] = int(_today_sold.get(String(recipe_id), 0)) + units


func note_wasted(recipe_id: StringName, units: int, cost: float, _reason: StringName) -> void:
	var e: Dictionary = _entry(recipe_id)
	e["units_wasted_expired"] = int(e["units_wasted_expired"]) + units
	e["ingredient_cost_allocated_kr"] = float(e["ingredient_cost_allocated_kr"]) + cost


func note_burnt(recipe_id: StringName, units: int, cost: float) -> void:
	var e: Dictionary = _entry(recipe_id)
	e["units_wasted_burnt"] = int(e["units_wasted_burnt"]) + units
	e["ingredient_cost_allocated_kr"] = float(e["ingredient_cost_allocated_kr"]) + cost


## Ringkasan tampilan (GDD 92.4 formula).
func view(recipe_id: StringName) -> Dictionary:
	var e: Dictionary = _entry(recipe_id)
	var sold: int = int(e["units_sold_physical"]) + int(e["units_sold_rotifood"])
	var wasted: int = int(e["units_wasted_burnt"]) + int(e["units_wasted_expired"])
	var revenue: float = float(e["gross_revenue_kr"])
	return {
		"produced": int(e["units_produced"]), "sold": sold, "wasted": wasted, "revenue": revenue,
		"average_price": revenue / float(sold) if sold > 0 else 0.0,
		"margin": revenue - float(e["ingredient_cost_allocated_kr"]),
		"unlocked": int(e["batches_completed"]) >= 1,
		"stale_sold": int(e["stale_sold_units"]),
		"best_day": int(e["highest_single_day_units_sold"]),
	}


func top_recipe_today() -> Dictionary:
	var best: String = ""
	var best_n: int = 0
	var keys: Array = _today_sold.keys()
	keys.sort()
	for k: Variant in keys:
		if int(_today_sold[k]) > best_n:
			best_n = int(_today_sold[k])
			best = str(k)
	return {"recipe": best, "count": best_n}


func end_day(day: int) -> void:
	for k: Variant in _today_sold.keys():
		var e: Dictionary = _entry(StringName(str(k)))
		e["highest_single_day_units_sold"] = maxi(int(e["highest_single_day_units_sold"]), int(_today_sold[k]))
	daily.append({"day": day, "sold": _today_sold.duplicate()})
	# Batas 1.000 hari terperinci; yang lebih lama sudah terlipat di agregat (GDD 129).
	var limit: int = DataRegistry.bali("limits.analytics_detailed_days")
	while daily.size() > limit:
		daily.pop_front()
	_today_sold.clear()


func capture() -> Dictionary:
	return {"per_recipe": per_recipe.duplicate(true), "daily": daily.duplicate(true), "today_sold": _today_sold.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	var pr: Dictionary = d.get("per_recipe", {})
	for k: Variant in pr.keys():
		if DataRegistry.recipe(StringName(str(k))) != null:
			per_recipe[str(k)] = (pr[k] as Dictionary).duplicate()
	daily = d.get("daily", [])
	_today_sold = d.get("today_sold", {})
