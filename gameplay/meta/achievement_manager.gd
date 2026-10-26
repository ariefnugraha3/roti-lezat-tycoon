class_name AchievementManager
extends SimManager
## AchievementManager — pencapaian & hadiahnya (GDD idle 11.4; v3.1 72.1, 74,
## 92.1, 118). Hadiahnya badge dinding (dekorasi kosmetik) dan satu boost.
## Pencapaian bertahan lintas Waralaba (GDD idle 10.5).

var unlocked: Dictionary = {}


func new_game() -> void:
	unlocked.clear()


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(String(id))


func _unlock(a: MiscDefinitions.AchievementDefinition) -> void:
	if is_unlocked(a.id):
		return
	unlocked[String(a.id)] = sim.time.day
	sim.decoration.grant(a.reward_id)
	sim.boosts.grant_achievement_boost()
	EventBus.achievement_unlocked.emit(a.id)
	EventBus.sfx.emit(&"achievement_unlock", &"")
	EventBus.notify.emit(3, "ui_achievement_unlocked", {"name": Tx.t(String(a.localization_key))}, &"trophy")


func _check(pred: Callable) -> void:
	for x: Variant in DataRegistry.achievements():
		var a: MiscDefinitions.AchievementDefinition = x
		if not is_unlocked(a.id) and bool(pred.call(a)):
			_unlock(a)


func check_stat(stat: String) -> void:
	_check(func(a: MiscDefinitions.AchievementDefinition) -> bool:
		var r: Dictionary = a.requirement
		return str(r.get("type", "")) == "stat_at_least" and str(r.get("stat", "")) == stat \
			and sim.statistics.get_stat(stat) >= float(r.get("value", 0)))


func check_balance(_balance: float) -> void:
	pass


func check_tier(tier: int) -> void:
	_check(func(a: MiscDefinitions.AchievementDefinition) -> bool:
		var r: Dictionary = a.requirement
		return str(r.get("type", "")) == "location_tier_at_least" and tier >= int(r.get("value", 0)))


## Semua jenis syarat sekaligus: dipanggil setelah level naik, resep dibuka,
## dan overflow (peristiwa yang jarang).
func check_all() -> void:
	_check(met)


## Syarat pencapaian `a` terpenuhi sekarang.
func met(a: MiscDefinitions.AchievementDefinition) -> bool:
	var r: Dictionary = a.requirement
	match str(r.get("type", "")):
		"stat_at_least":
			return sim.statistics.get_stat(str(r.get("stat", ""))) >= float(r.get("value", 0))
		"location_tier_at_least":
			return sim.world.location.tier >= int(r.get("value", 0))
		"station_level_at_least":
			for e: EquipmentInstance in sim.equipment.all_sorted():
				if [&"mixer", &"oven", &"display"].has(e.category()) and sim.upgrades.station_level(e.iid) >= int(r.get("value", 0)):
					return true
			return false
		"recipe_level_at_least":
			for rid: StringName in sim.upgrades.unlocked_recipes():
				if sim.upgrades.recipe_level(rid) >= int(r.get("value", 0)):
					return true
			return false
		"condition":
			match str(r.get("condition", "")):
				"all_recipes_unlocked":
					return sim.upgrades.unlocked_recipes().size() >= DataRegistry.recipes().size()
				"economy_overflow":
					return sim.economy.overflowed
	return false


func note_recipe_produced(_recipe_id: StringName) -> void:
	pass


func capture() -> Dictionary:
	return {"unlocked": unlocked.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	unlocked = (d.get("unlocked", {}) as Dictionary).duplicate()
