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
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if prices.has(recipe_id) and not prices_locked():
		return float(prices[recipe_id])
	return r.base_sell_price_kr if r != null else 0.0


## Hari 1-3 (manifest, GDD 20.3) selalu memakai harga referensi: pembeli skenario
## tidak bereaksi pada harga. Slider aktif lagi sejak after-hours Hari 3, yang
## merencanakan Hari 4 (GDD 63.2).
func prices_locked() -> bool:
	var selling_day: int = sim.time.day + (1 if sim.time.is_after_hours() else 0)
	return not DataRegistry.opening_day(selling_day).is_empty()


## Set harga; di-clamp ke min..max dan kelipatan step (GDD 63.2). Selama harga
## terkunci tidak ada yang berubah.
func set_price(recipe_id: StringName, value: float) -> float:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	if r == null:
		return 0.0
	if prices_locked():
		return price_of(recipe_id)
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
