class_name RecipeDefinition
extends RefCounted
## Resep kanonik (GDD 61.2, 101.1). Diisi DataRegistry dari recipes.json; immutable.

var id: StringName
var localization_key: StringName
var category_id: StringName
## ingredient_id (StringName) -> jumlah per batch x1.
var ingredients: Dictionary = {}
var batch_yield: int = 0
var required_mixer_tier: int = 1
var required_oven_tier: int = 1
var recipe_total_time: float = 0.0
var mix_duration_seconds: float = 0.0
var prep_duration_seconds: float = 0.0
var bake_duration_seconds: float = 0.0
var expired_duration_hours: float = 0.0
var base_sell_price_kr: float = 0.0
var batch_cost_kr: float = 0.0
var required_station_ids: Array[StringName] = []
var customer_tags: Array[StringName] = []
var visual_profile_id: StringName

## Batas slider harga (GDD 63.2), dihitung DataRegistry saat boot.
var min_price_kr: float = 0.0
var max_price_kr: float = 0.0
var price_step_kr: float = 5.0


static func from_dict(d: Dictionary) -> RecipeDefinition:
	var r := RecipeDefinition.new()
	r.id = StringName(str(d.get("id", "")))
	r.localization_key = StringName(str(d.get("localization_key", "")))
	r.category_id = StringName(str(d.get("category_id", "")))
	var ing: Dictionary = d.get("ingredients", {})
	for k: Variant in ing.keys():
		r.ingredients[StringName(str(k))] = int(ing[k])
	r.batch_yield = int(d.get("batch_yield", 0))
	r.required_mixer_tier = int(d.get("required_mixer_tier", 0))
	r.required_oven_tier = int(d.get("required_oven_tier", 0))
	r.recipe_total_time = float(d.get("recipe_total_time", 0.0))
	r.mix_duration_seconds = float(d.get("mix_duration_seconds", -1.0))
	r.prep_duration_seconds = float(d.get("prep_duration_seconds", -1.0))
	r.bake_duration_seconds = float(d.get("bake_duration_seconds", 0.0))
	r.expired_duration_hours = float(d.get("expired_duration_hours", 0.0))
	r.base_sell_price_kr = float(d.get("base_sell_price_kr", 0.0))
	r.batch_cost_kr = float(d.get("batch_cost_kr", -1.0))
	for s: Variant in d.get("required_station_ids", []):
		r.required_station_ids.append(StringName(str(s)))
	for t: Variant in d.get("customer_tags", []):
		r.customer_tags.append(StringName(str(t)))
	r.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
	return r


## Tier resep untuk aturan pelanggan (Socialite: tier minimum >= 3, GDD 20.11).
func recipe_tier() -> int:
	return maxi(required_mixer_tier, required_oven_tier)


func unit_cogs_kr() -> float:
	return batch_cost_kr / float(maxi(batch_yield, 1))
