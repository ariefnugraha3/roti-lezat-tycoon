class_name MasteryManager
extends SimManager
## Mastery resep (GDD idle 23.3): roti terjual sepanjang masa per resep (semua
## cabang, toko dan RotiFood) menaikkan bintang mastery 1–5 pada
## `mastery.thresholds`; setiap bintang menambah harga jual resep itu sebesar
## `mastery.price_bonus_per_level`. Tidak direset Waralaba, jadi menjadi tujuan
## jangka panjang dan alasan menjual resep lain. Harga mastery bagian dari harga
## biasa (SimulationRoot.plain_price), sehingga ikut model KR/s dan offline.

## Roti terjual sepanjang masa per resep (id String -> int).
var sold: Dictionary = {}
## Naik setiap kali bintang mastery mana pun naik (kunci cache resep Auto).
var version: int = 0


func new_game() -> void:
	sold.clear()
	version = 0


## Catat `units` roti resep `recipe_id` yang terjual. Bintang yang naik memberi
## toast dan membuat ulang model penghasilan.
func note_sold(recipe_id: StringName, units: int) -> void:
	if units <= 0 or DataRegistry.recipe(recipe_id) == null:
		return
	var before: int = level(recipe_id)
	var key: String = String(recipe_id)
	sold[key] = int(sold.get(key, 0)) + units
	var after: int = level(recipe_id)
	if after == before:
		return
	version += 1
	sim.idle_economy.invalidate()
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	EventBus.notify.emit(2, "ui_mastery_up", {"recipe": Tx.t(String(r.localization_key)), "level": after,
		"percent": Tx.percent(price_bonus() * float(after))}, &"star")
	EventBus.sfx.emit(&"level_up", &"")


func units(recipe_id: StringName) -> int:
	return int(sold.get(String(recipe_id), 0))


## Bintang mastery resep itu (0..jumlah ambang).
func level(recipe_id: StringName) -> int:
	return level_for(units(recipe_id))


static func level_for(n: int) -> int:
	var lv: int = 0
	for t: Variant in DataRegistry.idle("mastery.thresholds"):
		if n >= int(t):
			lv += 1
	return lv


static func max_level() -> int:
	return (DataRegistry.idle("mastery.thresholds") as Array).size()


static func price_bonus() -> float:
	return DataRegistry.idlef("mastery.price_bonus_per_level")


## Roti terjual yang dibutuhkan untuk bintang berikutnya, atau -1 bila sudah penuh.
func next_threshold(recipe_id: StringName) -> int:
	var lv: int = level(recipe_id)
	var th: Array = DataRegistry.idle("mastery.thresholds")
	return int(th[lv]) if lv < th.size() else -1


## Pengali harga dari mastery: 1 + bonus × bintang.
func price_mult(recipe_id: StringName) -> float:
	return 1.0 + price_bonus() * float(level(recipe_id))


## Jumlah bintang mastery semua resep.
func total_stars() -> int:
	var n: int = 0
	for k: Variant in sold.keys():
		n += level_for(int(sold[k]))
	return n


func capture() -> Dictionary:
	return {"sold": sold.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	var s: Variant = d.get("sold", {})
	if s is Dictionary:
		for k: Variant in (s as Dictionary).keys():
			if DataRegistry.recipe(StringName(str(k))) != null and int((s as Dictionary)[k]) > 0:
				sold[str(k)] = int((s as Dictionary)[k])
	version = 0
