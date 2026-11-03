class_name CravingManager
extends SimManager
## Craving harian dan selera lingkungan (GDD idle 21.1).
##
## Selera: dua roti favorit per lokasi (`craving.favorites_by_tier`) dijual
## ×`craving.favorite_mult`, selalu, juga di model offline.
##
## Craving: mulai hari `craving.first_day`, setiap pukul 00:00 kota mengidam
## satu resep yang alatnya sudah ada (terbuka maupun belum), bukan craving
## kemarin. Undiannya dari seed master dan nomor hari, jadi tidak menggeser
## stream RNG lain. Selama resepnya terbuka, rotinya dijual ×`craving.best_mult`
## harga biasa roti termahal yang bisa dijual, termasuk dirinya sendiri
## (SimulationRoot.recipe_price). Craving seperti boost: tidak ikut penghasilan
## offline.

## Tes yang mengukur harga dan ekonomi mematikannya (TestRunner); tes craving
## menyalakannya lagi.
static var enabled: bool = true

## Hari in-game undian terakhir, resep craving hari itu, dan craving kemarin.
var day: int = 0
var recipe: StringName = &""
var previous: StringName = &""


func new_game() -> void:
	day = 0
	recipe = &""
	previous = &""


## Pukul 00:00 (SimulationRoot._on_new_day): undian craving hari baru.
func on_new_day() -> void:
	_pick(sim.time.day)
	if recipe != &"":
		EventBus.notify.emit(1, "ui_craving_today", {"recipe": Tx.recipe_name(recipe)}, &"bread")


## Pastikan craving milik hari ini (setelah load atau awal permainan).
func ensure_today() -> void:
	if day != sim.time.day:
		_pick(sim.time.day)


func _pick(d: int) -> void:
	if recipe != &"":
		previous = recipe
	day = d
	recipe = &""
	if enabled and d >= DataRegistry.idlei("craving.first_day"):
		var options: Array[StringName] = []
		for r: RecipeDefinition in DataRegistry.recipes():
			if r.id != previous and sim.production.owns_equipment_for(r):
				options.append(r.id)
		if not options.is_empty():
			var rng := RandomNumberGenerator.new()
			rng.seed = RNGManager._derive(sim.rng.master_seed, "craving_%d" % d)
			recipe = options[rng.randi_range(0, options.size() - 1)]
	sim.idle_economy.invalidate()


## Resep craving hari ini (&"" = tidak ada), terbuka maupun belum.
func today() -> StringName:
	return recipe if enabled else &""


## Resep craving yang sedang berlaku: sudah terbuka (&"" bila tidak ada).
func active() -> StringName:
	var r: StringName = today()
	return r if r != &"" and sim.upgrades.is_unlocked(r) else &""


## Pengali selera lingkungan untuk resep `recipe_id` di lokasi sekarang.
func favorite_mult(recipe_id: StringName) -> float:
	return DataRegistry.idlef("craving.favorite_mult") if is_favorite(recipe_id) else 1.0


func is_favorite(recipe_id: StringName) -> bool:
	return favorites().has(recipe_id)


## Roti favorit lokasi sekarang.
func favorites() -> Array[StringName]:
	var out: Array[StringName] = []
	var by_tier: Array = DataRegistry.idle("craving.favorites_by_tier")
	var t: int = clampi(sim.world.location.tier - 1, 0, by_tier.size() - 1) if sim.world.location != null else 0
	for rid: Variant in by_tier[t]:
		out.append(StringName(str(rid)))
	return out


func capture() -> Dictionary:
	return {"day": day, "recipe": String(recipe), "previous": String(previous)}


func restore(d: Dictionary) -> void:
	day = int(d.get("day", 0))
	recipe = StringName(str(d.get("recipe", "")))
	previous = StringName(str(d.get("previous", "")))
	if recipe != &"" and DataRegistry.recipe(recipe) == null:
		recipe = &""
