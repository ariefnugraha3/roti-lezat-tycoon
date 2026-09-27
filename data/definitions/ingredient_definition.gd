class_name IngredientDefinition
extends RefCounted
## Bahan baku harga tetap (GDD 5.2.1, 101.2).

var id: StringName
var localization_key: StringName
var unit_label_key: StringName
var fixed_buy_price_kr: float = 0.0
var storage_units_per_purchase: int = 1
var category_id: StringName


static func from_dict(d: Dictionary) -> IngredientDefinition:
	var i := IngredientDefinition.new()
	i.id = StringName(str(d.get("id", "")))
	i.localization_key = StringName(str(d.get("localization_key", "")))
	i.unit_label_key = StringName(str(d.get("unit_label_key", "")))
	i.fixed_buy_price_kr = float(d.get("fixed_buy_price_kr", 0.0))
	i.storage_units_per_purchase = int(d.get("storage_units_per_purchase", 1))
	i.category_id = StringName(str(d.get("category_id", "")))
	return i
