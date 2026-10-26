class_name CustomerArchetypeDefinition
extends RefCounted
## Arketipe pelanggan fisik (v3.1 20.2, 20.11, 58, 59, 84.1, 101.4). Tanpa
## kesegaran, kualitas, dan batas harga (GDD idle 4.6, 6.2).

var id: StringName
var localization_key: StringName
var base_patience_seconds: float = 0.0
var movement_speed_mps: float = 0.0
var quantity_preferred: int = 1
var quantity_min: int = 1
var quantity_max: int = 1
## &"weighted" atau &"triangular"
var quantity_mode: StringName = &"weighted"
## Bulk buyer: stok kurang tetap diterima sampai minimal ini (GDD 84.1).
var quantity_partial_min: int = 0
## tag -> bobot preferensi.
var preferred_tags: Dictionary = {}
var spawn_weight_by_tier: Array[float] = []
## blok jam -> pengali bobot (GDD 20.11).
var time_modifiers: Dictionary = {}
var time_modifier_default: float = 1.0
var visual_profile_id: StringName


static func from_dict(d: Dictionary) -> CustomerArchetypeDefinition:
	var c := CustomerArchetypeDefinition.new()
	c.id = StringName(str(d.get("id", "")))
	c.localization_key = StringName(str(d.get("localization_key", "")))
	c.base_patience_seconds = float(d.get("base_patience_seconds", 0.0))
	c.movement_speed_mps = float(d.get("movement_speed_mps", 0.0))
	var q: Dictionary = d.get("quantity", {})
	c.quantity_preferred = int(q.get("preferred", 1))
	c.quantity_min = int(q.get("min", 1))
	c.quantity_max = int(q.get("max", 1))
	c.quantity_mode = StringName(str(q.get("mode", "weighted")))
	c.quantity_partial_min = int(q.get("partial_min", 0))
	var tags: Dictionary = d.get("preferred_tags", {})
	for k: Variant in tags.keys():
		c.preferred_tags[StringName(str(k))] = float(tags[k])
	for w: Variant in d.get("spawn_weight_by_tier", []):
		c.spawn_weight_by_tier.append(float(w))
	var tm: Dictionary = d.get("time_modifiers", {})
	for k2: Variant in tm.keys():
		c.time_modifiers[StringName(str(k2))] = float(tm[k2])
	c.time_modifier_default = float(d.get("time_modifier_default", 1.0))
	c.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
	return c


func time_modifier(block: StringName) -> float:
	return float(time_modifiers.get(block, time_modifier_default))


func spawn_weight(location_tier: int) -> float:
	var i: int = clampi(location_tier, 1, 5) - 1
	if i >= spawn_weight_by_tier.size():
		return 0.0
	return spawn_weight_by_tier[i]


## Bobot preferensi sebuah resep = bobot tertinggi di antara tag resep (GDD 20.11).
func preference_for(recipe: RecipeDefinition) -> float:
	var best: float = 0.0
	for t: StringName in recipe.customer_tags:
		best = maxf(best, float(preferred_tags.get(t, 0.0)))
	return best
