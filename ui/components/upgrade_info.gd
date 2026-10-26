class_name UpgradeInfo
extends RefCounted
## Teks dan ikon untuk satu penawaran upgrade (UpgradeManager.offer, GDD idle
## 8, 12.2): judul "Oven 2 · Lv 12", efek sekarang -> berikutnya, dan milestone
## berikutnya. Dipakai kartu upgrade, layar Upgrades, Menu, Staff, dan Shop.

const ICONS: Dictionary = {
	&"mixer": "kitchen", &"oven": "fire", &"display": "bread", &"counter": "bag",
	&"global_offline_hours": "moon", &"global_offline_efficiency": "hourglass", &"global_tap_power": "bolt",
	&"global_walk_speed": "scooter", &"global_queue_patience": "heart",
}


## Kategori stasiun penawaran (mixer/oven/display), &"counter", atau &"".
static func station_category(sim: SimulationRoot, o: Dictionary) -> StringName:
	if o.is_empty():
		return &""
	if o["kind"] == &"counter":
		return &"counter"
	if o["kind"] == &"station":
		var e: EquipmentInstance = sim.equipment.get_inst(int(o["id"]))
		return e.category() if e != null else &""
	return &""


## Nama tanpa level: "Oven 2", "Plain White Loaf", "Budi", "Strong Hands".
static func name_of(sim: SimulationRoot, o: Dictionary) -> String:
	match o.get("kind", &""):
		&"station":
			var e: EquipmentInstance = sim.equipment.get_inst(int(o["id"]))
			if e == null:
				return ""
			var base: String = Tx.t("ui_station_" + String(e.category()))
			var same: Array[EquipmentInstance] = sim.equipment.placed_list(e.category())
			return Tx.t("ui_station_numbered", {"station": base, "n": same.find(e) + 1}) if same.size() > 1 else base
		&"counter":
			return Tx.t("ui_station_counter")
		&"recipe":
			return Tx.recipe_name(StringName(str(o["id"])))
		&"staff":
			var d: StaffDefinition = DataRegistry.staff(StringName(str(o["id"])))
			return d.display_name if d != null else ""
		&"global":
			return Tx.t(String(o["id"]))
	return ""


## "Oven 2 · Lv 12" (global: "Strong Hands · Lv 3/20").
static func title(sim: SimulationRoot, o: Dictionary) -> String:
	if o.is_empty():
		return ""
	if o["kind"] == &"global":
		return Tx.t("ui_title_level_of", {"name": name_of(sim, o), "level": int(o["level"]), "max": int(o["cap"])})
	return Tx.t("ui_title_level", {"name": name_of(sim, o), "level": int(o["level"])})


## Efek pada level `level` sebagai teks (mis. "Speed ×2.30").
static func effect_at(sim: SimulationRoot, o: Dictionary, level: int) -> String:
	match o["kind"]:
		&"station":
			var cat: StringName = station_category(sim, o)
			if cat == &"display":
				var cap: int = UpgradeManager.slot_capacity_for(level)
				var bonus: float = DataRegistry.idlef("station.display.price_per_level") * float(level - 1)
				return Tx.t("ui_effect_capacity", {"value": cap}) + " · " + Tx.t("ui_effect_price", {"value": _x(1.0 + bonus)})
			return Tx.t("ui_effect_speed", {"value": _x(UpgradeManager.speed_for(cat, level))})
		&"counter":
			return Tx.t("ui_effect_checkout", {"value": "%.2f" % DataRegistry.real_seconds(UpgradeManager.checkout_seconds_for(level))})
		&"recipe":
			var r: RecipeDefinition = DataRegistry.recipe(StringName(str(o["id"])))
			var mult: float = UpgradeManager.recipe_price_mult_for(level, sim.upgrades.recipe_milestone_mult())
			return Tx.t("ui_effect_recipe_price", {"value": Tx.kr(r.base_sell_price_kr * mult * sim.price_mult())})
		&"staff":
			return Tx.t("ui_effect_speed", {"value": _x(1.0 + DataRegistry.idlef("staff.speed_per_level") * float(level - 1))})
		&"global":
			var g: Dictionary = DataRegistry.global_upgrade(StringName(str(o["id"])))
			var v: float = float(g.get("per_level", 0.0)) * float(level)
			match StringName(str(o["id"])):
				&"global_offline_hours":
					return Tx.t("ui_effect_offline_hours", {"value": int(DataRegistry.idlef("offline.base_cap_hours") + v)})
				&"global_offline_efficiency":
					return Tx.t("ui_effect_offline_efficiency", {"value": Tx.percent(minf(DataRegistry.idlef("offline.max_efficiency"), DataRegistry.idlef("offline.base_efficiency") + v))})
				&"global_tap_power":
					return Tx.t("ui_effect_tap_power", {"value": _x(1.0 + v)})
				&"global_walk_speed":
					return Tx.t("ui_effect_walk_speed", {"value": _x(1.0 + v)})
				&"global_queue_patience":
					return Tx.t("ui_effect_patience", {"value": _x(1.0 + v)})
	return ""


## "Speed ×2.30 → Speed ×2.40", atau efek sekarang + "Max level" di batas.
static func effect(sim: SimulationRoot, o: Dictionary) -> String:
	if o.is_empty():
		return ""
	var lv: int = int(o["level"])
	var now: String = effect_at(sim, o, lv)
	if lv >= int(o["cap"]):
		return Tx.t("ui_effect_maxed", {"effect": now})
	return Tx.t("ui_effect_change", {"now": now, "next": effect_at(sim, o, lv + 1)})


## Milestone berikutnya: {level, text, from} (`from` = milestone sebelumnya,
## untuk bar kemajuan), atau {} bila tidak ada lagi.
static func milestone(sim: SimulationRoot, o: Dictionary) -> Dictionary:
	if o.is_empty():
		return {}
	var lv: int = int(o["level"])
	var list: Array = []
	var text_for: Callable
	match o["kind"]:
		&"station":
			var cat: StringName = station_category(sim, o)
			if cat == &"display":
				list = DataRegistry.idle("station.model_tier_thresholds")
				text_for = func(_m: int) -> String: return Tx.t("ui_milestone_shelf_model")
			else:
				list = DataRegistry.idle("station.milestones")
				var mult: float = DataRegistry.idlef("station.%s.milestone_mult" % cat)
				var tiers: Array = DataRegistry.idle("station.model_tier_thresholds")
				text_for = func(m: int) -> String:
					var t: String = Tx.t("ui_milestone_speed", {"value": _x(mult)})
					return Tx.t("ui_milestone_and_model", {"effect": t}) if tiers.has(m) or tiers.has(float(m)) else t
		&"counter":
			list = DataRegistry.idle("station.milestones")
			text_for = func(_m: int) -> String: return Tx.t("ui_milestone_gold_badge")
		&"recipe":
			list = DataRegistry.idle("recipe.milestones")
			var rm: float = sim.upgrades.recipe_milestone_mult()
			text_for = func(_m: int) -> String: return Tx.t("ui_milestone_price", {"value": _x(rm)})
		_:
			return {}
	var nxt: int = UpgradeManager.next_milestone(lv, list)
	if nxt < 0 or nxt > int(o["cap"]):
		return {}
	var prev: int = 1
	for m: Variant in list:
		if int(m) <= lv:
			prev = int(m)
	return {"level": nxt, "from": prev, "text": Tx.t("ui_next_milestone", {"level": nxt, "effect": text_for.call(nxt)})}


## Ikon kiri baris untuk penawaran.
static func icon(sim: SimulationRoot, o: Dictionary, px: float) -> Control:
	match o.get("kind", &""):
		&"recipe":
			return BreadArt.for_recipe(StringName(str(o["id"])), px)
		&"staff":
			var d: StaffDefinition = DataRegistry.staff(StringName(str(o["id"])))
			var baker: bool = d != null and d.is_baker()
			return ProceduralUIFactory.badge("chef" if baker else "coin", Palette.HONEY if baker else Palette.MATCHA, Palette.FLOUR_WHITE, int(px))
		&"global":
			return ProceduralUIFactory.badge(str(ICONS.get(StringName(str(o["id"])), "star")), Palette.PASTEL_PERIWINKLE, Palette.FLOUR_WHITE, int(px))
	var cat: StringName = station_category(sim, o)
	return ProceduralUIFactory.badge(str(ICONS.get(cat, "gear")), Palette.CARAMEL, Palette.FLOUR_WHITE, int(px))


static func _x(v: float) -> String:
	return "%.2f" % v
