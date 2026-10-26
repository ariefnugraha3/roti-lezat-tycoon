class_name PrestigeManager
extends SimManager
## PrestigeManager — Bintang Waralaba, perk, dan nomor putaran (GDD idle 10).
## Bintang tidak dibelanjakan: setiap bintang menambah pengali penghasilan, dan
## total bintang membuka perk permanen (GDD idle 10.3, 10.4).

## Bintang Waralaba yang dimiliki (ID `franchise_stars`).
var stars: int = 0
## Nomor putaran: 1 untuk toko pertama, naik setiap Waralaba.
var run_index: int = 1
## Resep yang pernah dibuka di putaran mana pun (perk_recipe_memory).
var recipes_ever: Dictionary = {}


func new_game() -> void:
	stars = 0
	run_index = 1
	recipes_ever.clear()


## Perk `id` sudah terbuka oleh total bintang (GDD idle 10.4).
func has_perk(id: StringName) -> bool:
	var p: Dictionary = DataRegistry.perk(id)
	return not p.is_empty() and stars >= int(p.get("stars", 0))


## Daftar perk yang terbuka, urut katalog.
func perks() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Variant in DataRegistry.idle("perks"):
		var id: StringName = StringName(str((p as Dictionary)["id"]))
		if has_perk(id):
			out.append(id)
	return out


## Pengali penghasilan dari bintang (GDD idle 10.3).
func income_mult() -> float:
	return 1.0 + DataRegistry.idlef("prestige.income_per_star") * float(stars)


func tap_mult() -> float:
	return float(DataRegistry.perk(&"perk_tap_double").get("tap_mult", 2)) if has_perk(&"perk_tap_double") else 1.0


func recipe_milestone_mult() -> float:
	return float(DataRegistry.perk(&"perk_milestone_triple").get("recipe_milestone_mult", 3)) if has_perk(&"perk_milestone_triple") else 0.0


func offline_hours_bonus() -> float:
	return float(DataRegistry.perk(&"perk_offline_plus").get("offline_hours", 1)) if has_perk(&"perk_offline_plus") else 0.0


func offline_efficiency_bonus() -> float:
	return float(DataRegistry.perk(&"perk_offline_efficiency").get("offline_efficiency", 0.25)) if has_perk(&"perk_offline_efficiency") else 0.0


func note_recipe_unlocked(recipe_id: StringName) -> void:
	recipes_ever[String(recipe_id)] = true


func capture() -> Dictionary:
	return {"stars": stars, "run_index": run_index, "perks": Array(perks()).map(func(x: StringName) -> String: return String(x)),
		"recipes_ever": recipes_ever.keys()}


func restore(d: Dictionary) -> void:
	new_game()
	stars = maxi(0, int(d.get("stars", 0)))
	run_index = maxi(1, int(d.get("run_index", 1)))
	for r: Variant in d.get("recipes_ever", []):
		if DataRegistry.recipe(StringName(str(r))) != null:
			recipes_ever[str(r)] = true
