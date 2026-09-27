class_name BreadStack
extends RefCounted
## Satu-satunya skema tumpukan roti (GDD 19.1). Roti tidak pernah menjadi node
## per unit (GDD 37.3); satu stack = satu batch dengan umur dan kualitas sama.
##
## `produced_at_game_time` memakai detik-simulasi kumulatif TimeManager supaya
## urutan FIFO tetap benar lintas hari.

var recipe_id: StringName
var quantity: int = 0
var slot_id: StringName
var source_job_id: int = -1
var produced_at_game_time: float = 0.0
var bake_quality: float = 1.0
var age_ingame_hours: float = 0.0
var base_expiry_hours: float = 1.0
var freshness_state: StringName = &"FRESH"
var display_tier: int = 1


func duplicate_stack() -> BreadStack:
	var b := BreadStack.new()
	b.recipe_id = recipe_id
	b.quantity = quantity
	b.slot_id = slot_id
	b.source_job_id = source_job_id
	b.produced_at_game_time = produced_at_game_time
	b.bake_quality = bake_quality
	b.age_ingame_hours = age_ingame_hours
	b.base_expiry_hours = base_expiry_hours
	b.freshness_state = freshness_state
	b.display_tier = display_tier
	return b


## Rasio usia terhadap umur simpan dasar. Umur sudah dikali aging rate display,
## sehingga rasio ini setara `age / effective_expiry` (GDD 19.7.1-19.7.2).
func age_ratio() -> float:
	return age_ingame_hours / maxf(base_expiry_hours, 0.0001)


## freshness_score turunan, tidak disimpan (GDD 19.1, 19.7.1).
func freshness_score() -> float:
	return clampf(100.0 * (1.0 - age_ratio()), 0.0, 100.0)


func refresh_state() -> void:
	freshness_state = state_for_ratio(age_ratio())


## Ambang GDD 19.7.1 di-cache (dipanggil untuk setiap stack setiap tick).
static var _gen: int = -1
static var _fresh_max: float = 0.4
static var _good_max: float = 0.7
static var _unsale: float = 1.0


static func state_for_ratio(r: float) -> StringName:
	if _gen != DataRegistry.generation:
		_gen = DataRegistry.generation
		_fresh_max = DataRegistry.balf("freshness.fresh_max_ratio")
		_good_max = DataRegistry.balf("freshness.good_max_ratio")
		_unsale = DataRegistry.balf("freshness.unsaleable_ratio")
	if r >= _unsale:
		return &"UNSALEABLE"
	if r > _good_max:
		return &"STALE"
	if r > _fresh_max:
		return &"GOOD"
	return &"FRESH"


func is_sellable() -> bool:
	return quantity > 0 and freshness_state != &"UNSALEABLE"


func to_dict() -> Dictionary:
	return {
		"recipe_id": String(recipe_id), "quantity": quantity, "slot_id": String(slot_id),
		"source_job_id": source_job_id, "produced_at_game_time": produced_at_game_time,
		"bake_quality": bake_quality, "age_ingame_hours": age_ingame_hours,
		"base_expiry_hours": base_expiry_hours, "freshness_state": String(freshness_state),
		"display_tier": display_tier,
	}


static func from_dict(d: Dictionary) -> BreadStack:
	var b := BreadStack.new()
	b.recipe_id = StringName(str(d.get("recipe_id", "")))
	b.quantity = int(d.get("quantity", 0))
	b.slot_id = StringName(str(d.get("slot_id", "")))
	b.source_job_id = int(d.get("source_job_id", -1))
	b.produced_at_game_time = float(d.get("produced_at_game_time", 0.0))
	b.bake_quality = float(d.get("bake_quality", 1.0))
	b.age_ingame_hours = float(d.get("age_ingame_hours", 0.0))
	b.base_expiry_hours = float(d.get("base_expiry_hours", 1.0))
	b.freshness_state = StringName(str(d.get("freshness_state", "FRESH")))
	b.display_tier = int(d.get("display_tier", 1))
	return b
