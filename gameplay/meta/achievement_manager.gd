class_name AchievementManager
extends SimManager
## AchievementManager — pencapaian & hadiahnya (GDD idle 11.4; v3.1 72.1, 74,
## 92.1, 118). Hadiahnya badge dinding (dekorasi kosmetik) dan satu boost.
## Pencapaian bertahan lintas Waralaba (GDD idle 10.5).

var unlocked: Dictionary = {}
## Seri pencapaian tanpa ujung (GDD idle 11.4, §20 no. 90): id seri -> level
## yang sudah dicapai. Setiap level memberi boost pencapaian dan toast.
var series: Dictionary = {}


func new_game() -> void:
	unlocked.clear()
	series.clear()


## Target statistik level ke-`level` (0 = pertama) seri `s`.
static func series_target(s: Dictionary, level: int) -> float:
	return float(s["first"]) * pow(float(s["factor"]), float(level))


## Level seri `id` yang sudah dicapai.
func series_level(id: String) -> int:
	return int(series.get(id, 0))


## Seri yang statistiknya bertambah: setiap target yang terlewati menaikkan
## levelnya, memberi boost pencapaian, dan mengumumkannya.
func check_series(stat: String = "") -> void:
	for x: Variant in DataRegistry.idle("endless.series"):
		var s: Dictionary = x
		if stat != "" and str(s["stat"]) != stat:
			continue
		var id: String = str(s["id"])
		var lv: int = series_level(id)
		var v: float = sim.statistics.get_stat(str(s["stat"]))
		var gained: int = 0
		while gained < 64 and v >= series_target(s, lv) and is_finite(series_target(s, lv)):
			lv += 1
			gained += 1
		if gained == 0:
			continue
		series[id] = lv
		sim.boosts.grant_achievement_boost()
		sim.premium.on_series(gained)
		EventBus.sfx.emit(&"achievement_unlock", &"")
		EventBus.notify.emit(3, "ui_series_unlocked", {"name": series_text(s, lv - 1)}, &"trophy")


## Teks satu level seri ("Earn 1.00Qa KR").
static func series_text(s: Dictionary, level: int) -> String:
	var v: float = series_target(s, level)
	return Tx.t("ui_series_" + str(s["id"]), {"value": Tx.big(v)})


func is_unlocked(id: StringName) -> bool:
	return unlocked.has(String(id))


func _unlock(a: MiscDefinitions.AchievementDefinition) -> void:
	if is_unlocked(a.id):
		return
	unlocked[String(a.id)] = sim.time.day
	sim.decoration.grant(a.reward_id)
	sim.boosts.grant_achievement_boost()
	sim.premium.on_achievement()
	EventBus.achievement_unlocked.emit(a.id)
	EventBus.sfx.emit(&"achievement_unlock", &"")
	EventBus.notify.emit(3, "ui_achievement_unlocked", {"name": Tx.t(String(a.localization_key))}, &"trophy")


func _check(pred: Callable) -> void:
	for x: Variant in DataRegistry.achievements():
		var a: MiscDefinitions.AchievementDefinition = x
		if not is_unlocked(a.id) and bool(pred.call(a)):
			_unlock(a)


func check_stat(stat: String) -> void:
	check_series(stat)
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
	check_series()


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
	return {"unlocked": unlocked.duplicate(), "series": series.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	unlocked = (d.get("unlocked", {}) as Dictionary).duplicate()
	var sr: Variant = d.get("series", {})
	if sr is Dictionary:
		for k: Variant in (sr as Dictionary).keys():
			series[str(k)] = maxi(0, int((sr as Dictionary)[k]))
