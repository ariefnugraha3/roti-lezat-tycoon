class_name InventoryManager
extends SimManager
## InventoryManager — satu-satunya pemilik isi Gudang (bahan `on_hand`, GDD 5.2.2,
## 24A.2, 98). Barang in_transit milik SupplyOrderManager dan TIDAK pernah dapat
## dipakai produksi sebelum commit pengiriman.

var on_hand: Dictionary = {}


func new_game() -> void:
	on_hand.clear()


func capacity() -> int:
	var storage: EquipmentDefinition = DataRegistry.equipment(sim.world.location.storage_id)
	return storage.capacity if storage != null else 0


func count(ingredient_id: StringName) -> int:
	return int(on_hand.get(ingredient_id, 0))


func total_units() -> int:
	var t: int = 0
	for k: Variant in on_hand.keys():
		t += int(on_hand[k])
	return t


func free_capacity() -> int:
	return maxi(0, capacity() - total_units())


func is_empty() -> bool:
	return total_units() <= 0


## Cukupkah bahan untuk `recipe` dengan batch `mult`? (hanya on_hand, GDD 24A.2)
func has_for_recipe(recipe: RecipeDefinition, mult: int) -> bool:
	for ing: StringName in recipe.ingredients.keys():
		if count(ing) < int(recipe.ingredients[ing]) * mult:
			return false
	return true


## Kekurangan bahan dalam KR untuk satu batch (GDD 49.1 missing_cost).
func missing_cost(recipe: RecipeDefinition) -> float:
	var cost: float = 0.0
	for ing: StringName in recipe.ingredients.keys():
		var need: int = int(recipe.ingredients[ing])
		var short: int = maxi(0, need - count(ing))
		cost += float(short) * DataRegistry.ingredient(ing).fixed_buy_price_kr
	return cost


## Pemotongan atomik: validasi dulu, lalu kurangi semua atau tidak sama sekali
## (GDD 38.3, 103). Mengembalikan dictionary bahan yang dipotong ({} bila gagal).
func consume_for_recipe(recipe: RecipeDefinition, mult: int) -> Dictionary:
	if not has_for_recipe(recipe, mult):
		return {}
	var taken: Dictionary = {}
	for ing: StringName in recipe.ingredients.keys():
		var n: int = int(recipe.ingredients[ing]) * mult
		on_hand[ing] = count(ing) - n
		if int(on_hand[ing]) <= 0:
			on_hand.erase(ing)
		taken[ing] = n
	GameLogger.info("INVENTORY", "consumed %s x%d" % [recipe.id, mult])
	return taken


## Mengembalikan bahan (refund job yang batal sebelum MIXING, GDD 18.3).
## Refund boleh melampaui kapasitas: bahan itu memang berasal dari Gudang.
func refund(items: Dictionary) -> void:
	for k: Variant in items.keys():
		var id: StringName = StringName(str(k))
		on_hand[id] = count(id) + int(items[k])


## Menambah bahan hasil pengiriman/bailout. Kapasitas sudah divalidasi saat
## pembelian (termasuk in_transit), jadi commit selalu utuh.
func add_items(items: Dictionary) -> void:
	for k: Variant in items.keys():
		var id: StringName = StringName(str(k))
		if DataRegistry.ingredient(id) == null:
			GameLogger.error("INVENTORY", "unknown ingredient %s ignored" % id)
			continue
		on_hand[id] = count(id) + int(items[k])


func value_of(items: Dictionary) -> float:
	var v: float = 0.0
	for k: Variant in items.keys():
		var def: IngredientDefinition = DataRegistry.ingredient(StringName(str(k)))
		if def != null:
			v += def.fixed_buy_price_kr * float(items[k])
	return v


## Berapa batch x1 `recipe` yang dapat dibuat dari stok sekarang.
func batches_available(recipe: RecipeDefinition) -> int:
	var best: int = 1 << 30
	for ing: StringName in recipe.ingredients.keys():
		best = mini(best, count(ing) / int(recipe.ingredients[ing]))
	return best if best < (1 << 30) else 0


func capture() -> Dictionary:
	return sn_dict_to_json(on_hand)


func restore(d: Dictionary) -> void:
	on_hand.clear()
	for k: Variant in d.keys():
		var id: StringName = StringName(str(k))
		if DataRegistry.ingredient(id) == null:
			GameLogger.error("SAVE", "quarantined unknown ingredient %s" % id)
			continue
		on_hand[id] = int(d[k])
