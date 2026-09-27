class_name PricingManager
extends SimManager
## PricingManager — pemilik harga jual per resep yang diatur pemain (GDD 34.2
## "price settings per recipe", 63.2). Harga dikunci per transaksi saat roti
## diambil dari rak atau saat pesanan RotiFood dibuat.

var prices: Dictionary = {}
var experiment_low_sold: bool = false
var experiment_high_sold: bool = false


func new_game() -> void:
	prices.clear()
	experiment_low_sold = false
	experiment_high_sold = false


func price_of(recipe_id: StringName) -> float:
	if prices.has(recipe_id):
		return float(prices[recipe_id])
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	return r.base_sell_price_kr if r != null else 0.0


## Set harga; di-clamp ke min..max dan kelipatan step (GDD 63.2).
func set_price(recipe_id: StringName, value: float) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	var v: float = Money.round_to(value, r.price_step_kr)
	v = clampf(v, r.min_price_kr, r.max_price_kr)
	if absf(v - r.base_sell_price_kr) < 0.001:
		prices.erase(recipe_id)
	else:
		prices[recipe_id] = v
	return v


func ratio(recipe_id: StringName) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	return price_of(recipe_id) / r.base_sell_price_kr


## Pengali permintaan harga baseline untuk emoji slider (GDD 84.5).
func baseline_demand(recipe_id: StringName) -> float:
	return DataRegistry.price_demand(ratio(recipe_id))


## Catat harga jual untuk achievement Market Research (GDD 74).
func note_sold_at(recipe_id: StringName, unit_price: float) -> void:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	var q: float = unit_price / r.base_sell_price_kr
	if q < DataRegistry.balf("achievements.price_low_ratio"):
		experiment_low_sold = true
	if q > DataRegistry.balf("achievements.price_high_ratio"):
		experiment_high_sold = true
	if experiment_low_sold and experiment_high_sold:
		sim.achievements.check_condition(&"price_experiment")


func capture() -> Dictionary:
	return {"prices": sn_dict_to_json(prices), "experiment_low_sold": experiment_low_sold,
		"experiment_high_sold": experiment_high_sold}


func restore(d: Dictionary) -> void:
	prices.clear()
	var p: Dictionary = d.get("prices", {})
	for k: Variant in p.keys():
		if DataRegistry.recipe(StringName(str(k))) != null:
			prices[StringName(str(k))] = float(p[k])
	experiment_low_sold = bool(d.get("experiment_low_sold", false))
	experiment_high_sold = bool(d.get("experiment_high_sold", false))
