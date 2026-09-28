extends Node
## DataRegistry — katalog kanonik read-only (GDD 35.2, 101, 133.1, 134).
##
## Satu-satunya representasi runtime adalah file JSON di res://data/catalog.
## Registry memuatnya sekali saat boot, membangun definisi bertipe, menghitung
## nilai turunan (batas harga 63.2), lalu memvalidasi seluruh referensi. Bila
## validasi gagal, `errors` berisi daftar pesan dan boot berhenti dengan layar
## galat (GDD 114, 117: jangan lanjut setelah katalog rusak).
##
## Autoload ini sengaja tidak bergantung pada autoload lain supaya validator
## dan test dapat memakainya lebih dulu.

const CATALOG_DIR: String = "res://data/catalog"
const TAG_VOCABULARY: Array[StringName] = [&"sweet", &"savory", &"practical", &"family", &"premium", &"artisan"]
const FRESHNESS_STATES: Array[StringName] = [&"FRESH", &"GOOD", &"STALE", &"UNSALEABLE"]
const ACHIEVEMENT_CONDITIONS: Array[String] = [
	"no_burn_day", "no_abandon_day", "rotifood_five_stars", "all_recipes_produced",
	"price_experiment", "rain_delivery_day", "solo_recovery", "big_day", "economy_overflow",
]
const ACHIEVEMENT_STATS: Array[String] = ["total_bread_sold", "no_burn_streak_days"]
## Gelembung pikiran pemain saat toko sepi, berurutan (GDD 31.7, 127.12).
const THOUGHT_KEYS: Array[String] = ["thought_quiet_1", "thought_quiet_2", "thought_quiet_3", "thought_quiet_4"]
const CATALOG_FILES: Array[String] = [
	"ingredients.json", "recipes.json", "equipment.json", "customers.json", "staff.json",
	"locations.json", "weather.json", "marketing.json", "opening.json", "balance.json",
	"achievements.json", "decorations.json", "audio_events.json", "quality_presets.json",
	"strings_en.json",
]

var loaded: bool = false
var errors: Array[String] = []
var catalog_versions: Dictionary = {"catalog_schema_version": 1, "content_version": 1}

var _raw: Dictionary = {}
var _strings: Dictionary = {}
var _balance: Dictionary = {}

var _ingredients: Array[IngredientDefinition] = []
var _ingredient_map: Dictionary = {}
var _recipes: Array[RecipeDefinition] = []
var _recipe_map: Dictionary = {}
var _equipment: Array[EquipmentDefinition] = []
var _equipment_map: Dictionary = {}
var _archetypes: Array[CustomerArchetypeDefinition] = []
var _archetype_map: Dictionary = {}
var _customers_raw: Dictionary = {}
var _staff: Array[StaffDefinition] = []
var _staff_map: Dictionary = {}
var _locations: Array[LocationDefinition] = []
var _location_map: Dictionary = {}
var _weather: Array = []
var _weather_map: Dictionary = {}
var _weather_raw: Dictionary = {}
var _campaigns: Array = []
var _campaign_map: Dictionary = {}
var _marketing_raw: Dictionary = {}
var _opening: Dictionary = {}
var _achievements: Array = []
var _achievement_map: Dictionary = {}
var _decorations: Array = []
var _decoration_map: Dictionary = {}
var _audio: Array = []
var _audio_map: Dictionary = {}
var _quality: Array = []
var _quality_raw: Dictionary = {}
var _staff_raw: Dictionary = {}
var _equipment_raw: Dictionary = {}
var _sci_threshold: float = 1.0e12
var _bal_cache: Dictionary = {}
## Naik setiap katalog dimuat ulang; cache statis di luar registry memeriksanya.
var generation: int = 0


func _ready() -> void:
	load_catalogs()


## Memuat dan memvalidasi semua katalog. Aman dipanggil ulang (test).
func load_catalogs() -> bool:
	errors.clear()
	_bal_cache.clear()
	generation += 1
	_raw.clear()
	for file_name: String in CATALOG_FILES:
		var data: Variant = _read_json(CATALOG_DIR.path_join(file_name))
		if data is Dictionary:
			_raw[file_name] = data
		else:
			errors.append("[DATA] %s could not be parsed" % file_name)
	if not errors.is_empty():
		loaded = false
		return false
	_build()
	_validate()
	loaded = errors.is_empty()
	if not loaded:
		for e: String in errors:
			push_error(e)
	return loaded


func is_valid() -> bool:
	return loaded and errors.is_empty()


# ===========================================================================
# AKSES
# ===========================================================================

## Kunci yang diminta tetapi tidak ada (TEST_UI_001 memeriksanya kosong).
var missing_keys: Dictionary = {}


func text(key: String, params: Dictionary = {}) -> String:
	var s: String = str(_strings.get(key, ""))
	if s == "":
		if not missing_keys.has(key):
			missing_keys[key] = true
			push_warning("[UI] missing string key: %s" % key)
		return key
	if params.is_empty():
		return s
	for k: Variant in params.keys():
		s = s.replace("{%s}" % str(k), str(params[k]))
	return s


func has_text(key: String) -> bool:
	return _strings.has(key)


func all_string_keys() -> Array:
	return _strings.keys()


func strings_table() -> Dictionary:
	return _strings


## Satu nilai balance lewat path bertitik, mis. "clock.open_seconds". Hasil
## di-cache per path (dipanggil tiap tick oleh banyak manajer); cache
## dikosongkan setiap katalog dimuat ulang.
func bal(path: String) -> Variant:
	if _bal_cache.has(path):
		return _bal_cache[path]
	var v: Variant = _bal_lookup(path)
	_bal_cache[path] = v
	return v


func _bal_lookup(path: String) -> Variant:
	var node: Variant = _balance
	for part: String in path.split("."):
		if node is Dictionary and (node as Dictionary).has(part):
			node = (node as Dictionary)[part]
		else:
			push_error("[DATA] missing balance path: %s" % path)
			return null
	return node


func balf(path: String) -> float:
	return float(bal(path))


func bali(path: String) -> int:
	return int(bal(path))


func balance_section(section: String) -> Dictionary:
	return _balance.get(section, {})


func economy_sci_threshold() -> float:
	return _sci_threshold


func ingredients() -> Array[IngredientDefinition]:
	return _ingredients


func ingredient(id: StringName) -> IngredientDefinition:
	return _ingredient_map.get(id)


func recipes() -> Array[RecipeDefinition]:
	return _recipes


func recipe(id: StringName) -> RecipeDefinition:
	return _recipe_map.get(id)


func equipment_list() -> Array[EquipmentDefinition]:
	return _equipment


func equipment(id: StringName) -> EquipmentDefinition:
	return _equipment_map.get(id)


func equipment_for(category: StringName, tier: int) -> EquipmentDefinition:
	return _equipment_map.get(StringName("%s_t%d" % [category, tier]))


func equipment_in_category(category: StringName) -> Array[EquipmentDefinition]:
	var out: Array[EquipmentDefinition] = []
	for e: EquipmentDefinition in _equipment:
		if e.category_id == category:
			out.append(e)
	return out


func equipment_sell_ratio() -> float:
	return float(_equipment_raw.get("sell_back_ratio", 0.5))


func archetypes() -> Array[CustomerArchetypeDefinition]:
	return _archetypes


func archetype(id: StringName) -> CustomerArchetypeDefinition:
	return _archetype_map.get(id)


func driver_def() -> Dictionary:
	return _customers_raw.get("driver_rotifood", {})


func courier_def() -> Dictionary:
	return _customers_raw.get("courier_supply", {})


func quantity_weights() -> Dictionary:
	return _customers_raw.get("quantity_weights", {})


func vip_rules() -> Dictionary:
	return _customers_raw.get("vip_rules", {})


## Blok jam (GDD 66): nama -> Vector2(mulai, selesai) detik in-game.
func time_blocks() -> Dictionary:
	var out: Dictionary = {}
	var tb: Dictionary = _customers_raw.get("time_blocks", {})
	for k: Variant in tb.keys():
		var a: Array = tb[k]
		out[StringName(str(k))] = Vector2(float(a[0]), float(a[1]))
	return out


func staff_list() -> Array[StaffDefinition]:
	return _staff


func staff(id: StringName) -> StaffDefinition:
	return _staff_map.get(id)


## Pengali durasi tahap untuk batch x1/x3/x5 (GDD 18.5, 18.9): bahan dan hasil
## tetap berlipat linear, durasi hanya naik sesuai tabel ini.
func batch_duration_factor(batch: int) -> float:
	var table: Variant = bal("production.batch_duration_factor")
	if table is Dictionary and (table as Dictionary).has(str(batch)):
		return float((table as Dictionary)[str(batch)])
	return 1.0


## Lama fase membungkus di akhir setiap transaksi kasir (GDD 21.4).
func packing_seconds() -> float:
	return balf("cashier.packing_seconds")


func manual_cashier_penalty() -> float:
	return float(_staff_raw.get("manual_cashier_penalty", 1.5))


func player_speed_mps() -> float:
	return float(_staff_raw.get("player_movement_speed_mps", 1.5))


## Waktu layan Asisten Kasir Tier 1: dasar kecepatan layan manual (GDD 3.0.C).
func tier1_cashier_seconds() -> float:
	var best: float = 0.0
	for s: StaffDefinition in _staff:
		if s.is_cashier() and s.tier == 1:
			best = s.cashier_service_seconds
			break
	return best


func locations() -> Array[LocationDefinition]:
	return _locations


func location(id: StringName) -> LocationDefinition:
	return _location_map.get(id)


func location_by_tier(tier: int) -> LocationDefinition:
	for l: LocationDefinition in _locations:
		if l.tier == tier:
			return l
	return null


func weather_list() -> Array:
	return _weather


func weather(id: StringName) -> MiscDefinitions.WeatherDefinition:
	return _weather_map.get(id)


func weather_raw() -> Dictionary:
	return _weather_raw


func holiday_event() -> Dictionary:
	var ev: Array = _weather_raw.get("events", [])
	return ev[0] if not ev.is_empty() else {}


func campaigns() -> Array:
	return _campaigns


func campaign(id: StringName) -> MiscDefinitions.MarketingCampaignDefinition:
	return _campaign_map.get(id)


func marketing_raw() -> Dictionary:
	return _marketing_raw


func opening_day(day: int) -> Dictionary:
	for d: Variant in _opening.get("days", []):
		if int((d as Dictionary).get("day", 0)) == day:
			return d
	return {}


func opening_raw() -> Dictionary:
	return _opening


func achievements() -> Array:
	return _achievements


func achievement(id: StringName) -> MiscDefinitions.AchievementDefinition:
	return _achievement_map.get(id)


func decorations() -> Array:
	return _decorations


func decoration(id: StringName) -> MiscDefinitions.DecorationDefinition:
	return _decoration_map.get(id)


func audio_events() -> Array:
	return _audio


func audio_event(id: StringName) -> MiscDefinitions.AudioEventDefinition:
	return _audio_map.get(id)


func quality_presets() -> Array:
	return _quality


func quality_auto_default() -> StringName:
	return StringName(str(_quality_raw.get("auto_default", "quality_medium")))


## Pengali permintaan harga baseline (GDD 63.2), kontinu piecewise linear.
func price_demand(ratio: float) -> float:
	var curve: Array = _balance["price"]["demand_curve"]
	var first: Array = curve[0]
	if ratio <= float(first[0]):
		return float(first[1])
	for i in range(1, curve.size()):
		var a: Array = curve[i - 1]
		var b: Array = curve[i]
		if ratio <= float(b[0]):
			var t: float = (ratio - float(a[0])) / (float(b[0]) - float(a[0]))
			return lerpf(float(a[1]), float(b[1]), t)
	var last: Array = curve[curve.size() - 1]
	return float(last[1])


## effective_price_demand = clamp(1 + s × (price_demand − 1), 0, 1.5) (GDD 63.2).
func effective_price_demand(ratio: float, sensitivity: float) -> float:
	var clamp_arr: Array = _balance["price"]["effective_demand_clamp"]
	return clampf(1.0 + sensitivity * (price_demand(ratio) - 1.0), float(clamp_arr[0]), float(clamp_arr[1]))


## Label reaksi harga (GDD 84.5).
func price_reaction_label(multiplier: float) -> StringName:
	for entry: Variant in _balance["price"]["reaction_labels"]:
		var e: Array = entry
		if multiplier >= float(e[0]):
			return StringName(str(e[1]))
	return &"REFUSE"


# ===========================================================================
# BUILD
# ===========================================================================

func _read_json(path: String) -> Variant:
	if not FileAccess.file_exists(path):
		return null
	var text_data: String = FileAccess.get_file_as_string(path)
	var json := JSON.new()
	if json.parse(text_data) != OK:
		errors.append("[DATA] %s: %s (line %d)" % [path, json.get_error_message(), json.get_error_line()])
		return null
	return json.data


func _build() -> void:
	var ing_raw: Dictionary = _raw["ingredients.json"]
	catalog_versions = {
		"catalog_schema_version": int(ing_raw.get("catalog_schema_version", 1)),
		"content_version": int(ing_raw.get("content_version", 1)),
	}
	_strings = (_raw["strings_en.json"] as Dictionary).get("strings", {})
	_balance = _raw["balance.json"]
	_sci_threshold = float(_balance["economy"]["hud_scientific_threshold_kr"])

	_ingredients.clear()
	_ingredient_map.clear()
	for d: Variant in ing_raw.get("items", []):
		var i: IngredientDefinition = IngredientDefinition.from_dict(d)
		_ingredients.append(i)
		_ingredient_map[i.id] = i

	_recipes.clear()
	_recipe_map.clear()
	for d2: Variant in (_raw["recipes.json"] as Dictionary).get("items", []):
		var r: RecipeDefinition = RecipeDefinition.from_dict(d2)
		_recipes.append(r)
		_recipe_map[r.id] = r

	_equipment_raw = _raw["equipment.json"]
	_equipment.clear()
	_equipment_map.clear()
	for d3: Variant in _equipment_raw.get("items", []):
		var e: EquipmentDefinition = EquipmentDefinition.from_dict(d3)
		_equipment.append(e)
		_equipment_map[e.id] = e

	_customers_raw = _raw["customers.json"]
	_archetypes.clear()
	_archetype_map.clear()
	for d4: Variant in _customers_raw.get("archetypes", []):
		var c: CustomerArchetypeDefinition = CustomerArchetypeDefinition.from_dict(d4)
		_archetypes.append(c)
		_archetype_map[c.id] = c

	_staff_raw = _raw["staff.json"]
	_staff.clear()
	_staff_map.clear()
	for d5: Variant in _staff_raw.get("items", []):
		var s: StaffDefinition = StaffDefinition.from_dict(d5)
		_staff.append(s)
		_staff_map[s.id] = s

	_locations.clear()
	_location_map.clear()
	for d6: Variant in (_raw["locations.json"] as Dictionary).get("items", []):
		var l: LocationDefinition = LocationDefinition.from_dict(d6)
		_locations.append(l)
		_location_map[l.id] = l

	_weather_raw = _raw["weather.json"]
	_weather.clear()
	_weather_map.clear()
	for d7: Variant in _weather_raw.get("items", []):
		var w := MiscDefinitions.WeatherDefinition.from_dict(d7)
		_weather.append(w)
		_weather_map[w.id] = w

	_marketing_raw = _raw["marketing.json"]
	_campaigns.clear()
	_campaign_map.clear()
	for d8: Variant in _marketing_raw.get("items", []):
		var m := MiscDefinitions.MarketingCampaignDefinition.from_dict(d8)
		_campaigns.append(m)
		_campaign_map[m.id] = m

	_opening = _raw["opening.json"]

	_achievements.clear()
	_achievement_map.clear()
	for d9: Variant in (_raw["achievements.json"] as Dictionary).get("items", []):
		var a := MiscDefinitions.AchievementDefinition.from_dict(d9)
		_achievements.append(a)
		_achievement_map[a.id] = a

	_decorations.clear()
	_decoration_map.clear()
	for d10: Variant in (_raw["decorations.json"] as Dictionary).get("items", []):
		var x := MiscDefinitions.DecorationDefinition.from_dict(d10)
		_decorations.append(x)
		_decoration_map[x.id] = x

	_audio.clear()
	_audio_map.clear()
	for d11: Variant in (_raw["audio_events.json"] as Dictionary).get("items", []):
		var ae := MiscDefinitions.AudioEventDefinition.from_dict(d11)
		_audio.append(ae)
		_audio_map[ae.id] = ae

	_quality_raw = _raw["quality_presets.json"]
	_quality.clear()
	for d12: Variant in _quality_raw.get("items", []):
		_quality.append(MiscDefinitions.QualityPresetDefinition.from_dict(d12))

	_derive_prices()


## Batas slider harga (GDD 63.2).
func _derive_prices() -> void:
	var p: Dictionary = _balance["price"]
	var round_step: float = float(p["round_to"])
	for r: RecipeDefinition in _recipes:
		var hpp: float = r.unit_cogs_kr()
		r.min_price_kr = maxf(Money.round_to(hpp * float(p["min_hpp_factor"]), round_step),
			Money.round_to(r.base_sell_price_kr * float(p["min_default_factor"]), round_step))
		r.max_price_kr = Money.round_to(r.base_sell_price_kr * float(p["max_default_factor"]), round_step)
		if r.base_sell_price_kr < float(p["slider_step_threshold"]):
			r.price_step_kr = float(p["slider_step_small"])
		else:
			r.price_step_kr = float(p["slider_step_large"])


# ===========================================================================
# VALIDASI (GDD 101.7, 133.1)
# ===========================================================================

func _err(msg: String) -> void:
	errors.append("[DATA] " + msg)


func _check_id(id: StringName, seen: Dictionary, kind: String) -> void:
	var s: String = String(id)
	if s == "":
		_err("%s has an empty id" % kind)
		return
	if seen.has(id):
		_err("duplicate %s id %s" % [kind, s])
	seen[id] = true
	if s != s.to_lower() or s.contains(" "):
		_err("%s id %s is not lowercase snake_case" % [kind, s])


func _check_text(key: StringName, owner: String) -> void:
	if not _strings.has(String(key)):
		_err("%s references missing string %s" % [owner, key])


func _validate() -> void:
	_validate_ingredients()
	_validate_recipes()
	_validate_equipment()
	_validate_customers()
	_validate_staff()
	_validate_locations()
	_validate_weather_marketing()
	_validate_opening()
	_validate_meta()
	_validate_balance()


func _validate_ingredients() -> void:
	var seen: Dictionary = {}
	for i: IngredientDefinition in _ingredients:
		_check_id(i.id, seen, "ingredient")
		if i.fixed_buy_price_kr <= 0.0:
			_err("ingredient %s has a non-positive price" % i.id)
		if i.storage_units_per_purchase < 1:
			_err("ingredient %s storage units < 1" % i.id)
		_check_text(i.localization_key, String(i.id))
		_check_text(i.unit_label_key, String(i.id))
		_check_text(StringName("ingredient_category_" + String(i.category_id)), String(i.id))


func _validate_recipes() -> void:
	var seen: Dictionary = {}
	for r: RecipeDefinition in _recipes:
		_check_id(r.id, seen, "recipe")
		_check_text(r.localization_key, String(r.id))
		if r.batch_yield <= 0:
			_err("recipe %s yield must be > 0" % r.id)
		if r.required_mixer_tier < 1 or r.required_mixer_tier > 5 or r.required_oven_tier < 1 or r.required_oven_tier > 5:
			_err("recipe %s has tiers outside 1..5" % r.id)
		if equipment_for(&"mixer", r.required_mixer_tier) == null or equipment_for(&"oven", r.required_oven_tier) == null:
			_err("recipe %s requires missing equipment" % r.id)
		if r.mix_duration_seconds < 0.0 or r.prep_duration_seconds < 0.0 or r.bake_duration_seconds <= 0.0:
			_err("recipe %s has invalid stage durations" % r.id)
		if absf(r.mix_duration_seconds + r.prep_duration_seconds + r.bake_duration_seconds - r.recipe_total_time) > 0.001:
			_err("recipe %s mix+prep+bake != recipe_total_time" % r.id)
		if r.expired_duration_hours <= 0.0:
			_err("recipe %s expiry must be > 0" % r.id)
		if r.base_sell_price_kr <= 0.0:
			_err("recipe %s price must be > 0" % r.id)
		var cost: float = 0.0
		for ing_id: StringName in r.ingredients.keys():
			var ing: IngredientDefinition = ingredient(ing_id)
			if ing == null:
				_err("recipe %s uses unknown ingredient %s" % [r.id, ing_id])
				continue
			if int(r.ingredients[ing_id]) <= 0:
				_err("recipe %s ingredient %s amount <= 0" % [r.id, ing_id])
			cost += ing.fixed_buy_price_kr * float(r.ingredients[ing_id])
		if absf(cost - r.batch_cost_kr) > 0.001:
			_err("recipe %s batch_cost_kr %s != ingredient sum %s" % [r.id, r.batch_cost_kr, cost])
		for tag: StringName in r.customer_tags:
			if not TAG_VOCABULARY.has(tag):
				_err("recipe %s has unknown tag %s" % [r.id, tag])
		for st: StringName in r.required_station_ids:
			if not [&"mixer", &"oven"].has(st):
				_err("recipe %s requires unknown station %s" % [r.id, st])
		if r.min_price_kr > r.base_sell_price_kr or r.max_price_kr < r.base_sell_price_kr:
			_err("recipe %s default price outside derived slider range" % r.id)


func _validate_equipment() -> void:
	var seen: Dictionary = {}
	for e: EquipmentDefinition in _equipment:
		_check_id(e.id, seen, "equipment")
		_check_text(e.localization_key, String(e.id))
		if e.tier < 1 or e.tier > 5:
			_err("equipment %s tier outside 1..5" % e.id)
		if e.footprint_tiles.x < 1 or e.footprint_tiles.y < 1:
			_err("equipment %s invalid footprint" % e.id)
		if e.price_kr < 0.0 or e.capacity < 0 or e.utility_cost_kr_per_ingame_hour < 0.0:
			_err("equipment %s has negative price/capacity/utility" % e.id)
		for rot: int in e.rotations_allowed:
			if not [0, 90, 180, 270].has(rot):
				_err("equipment %s invalid rotation %d" % [e.id, rot])
		match e.category_id:
			&"mixer", &"oven":
				if e.reference_seconds <= 0.0 or e.process_multiplier <= 0.0:
					_err("equipment %s needs reference seconds" % e.id)
				if e.category_id == &"oven" and (e.perfect_window_seconds <= 0.0 or e.overbake_window_seconds <= 0.0):
					_err("oven %s needs burn windows" % e.id)
			&"display":
				if e.slot_count <= 0 or e.max_per_slot <= 0 or e.slot_count * e.max_per_slot < e.capacity:
					_err("display %s slots cannot hold its capacity" % e.id)
				if e.aging_rate <= 0.0:
					_err("display %s aging rate must be > 0" % e.id)
			&"storage":
				if e.capacity <= 0:
					_err("storage %s capacity must be > 0" % e.id)
			&"counter":
				pass
			_:
				_err("equipment %s unknown category %s" % [e.id, e.category_id])
	for cat: StringName in [&"mixer", &"oven", &"display", &"storage"]:
		for t in range(1, 6):
			if equipment_for(cat, t) == null:
				_err("missing equipment %s_t%d" % [cat, t])
	# Waktu referensi makin cepat tiap tier (GDD 5.1); process_multiplier =
	# referensi T1 / referensi tier itu (GDD 101.3).
	for cat: StringName in [&"mixer", &"oven"]:
		var t1: EquipmentDefinition = equipment_for(cat, 1)
		if t1 == null or t1.reference_seconds <= 0.0:
			continue
		var prev: float = INF
		for t in range(1, 6):
			var e: EquipmentDefinition = equipment_for(cat, t)
			if e == null or e.reference_seconds <= 0.0:
				continue
			if e.reference_seconds >= prev:
				_err("equipment %s must be faster than the tier below" % e.id)
			prev = e.reference_seconds
			if absf(e.process_multiplier - t1.reference_seconds / e.reference_seconds) > 0.001:
				_err("equipment %s process_multiplier must equal T1 reference / its reference" % e.id)


func _validate_customers() -> void:
	var seen: Dictionary = {}
	var tier_sums: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0]
	for c: CustomerArchetypeDefinition in _archetypes:
		_check_id(c.id, seen, "customer")
		_check_text(c.localization_key, String(c.id))
		if c.base_patience_seconds <= 0.0 or is_inf(c.base_patience_seconds):
			_err("customer %s patience must be finite and > 0" % c.id)
		if c.movement_speed_mps <= 0.0:
			_err("customer %s speed must be > 0" % c.id)
		if c.quantity_min < 1 or c.quantity_max < c.quantity_min or c.quantity_preferred < c.quantity_min or c.quantity_preferred > c.quantity_max:
			_err("customer %s invalid quantity range" % c.id)
		for s: StringName in c.allowed_freshness_states:
			if not FRESHNESS_STATES.has(s):
				_err("customer %s unknown freshness %s" % [c.id, s])
		for tag: StringName in c.preferred_tags.keys():
			if not TAG_VOCABULARY.has(tag):
				_err("customer %s unknown tag %s" % [c.id, tag])
		if c.spawn_weight_by_tier.size() != 5:
			_err("customer %s needs 5 tier weights" % c.id)
		else:
			for i in 5:
				tier_sums[i] += c.spawn_weight_by_tier[i]
	for i2 in 5:
		if absf(tier_sums[i2] - 1.0) > 0.001:
			_err("archetype weights for tier %d sum to %s, not 1.0" % [i2 + 1, tier_sums[i2]])
	for extra: String in ["driver_rotifood", "courier_supply"]:
		var d: Dictionary = _customers_raw.get(extra, {})
		if float(d.get("movement_speed_mps", 0.0)) <= 0.0:
			_err("%s needs a movement speed" % extra)
		_check_text(StringName(extra), extra)


func _validate_staff() -> void:
	var seen: Dictionary = {}
	for s: StaffDefinition in _staff:
		_check_id(s.id, seen, "staff")
		_check_text(s.id, String(s.id))
		_check_text(StringName(s.title_key()), String(s.id))
		if not [&"cashier", &"baker"].has(s.role_id):
			_err("staff %s unknown role %s" % [s.id, s.role_id])
		if s.tier < 1 or s.tier > 5:
			_err("staff %s tier outside 1..5" % s.id)
		if s.daily_wage_kr <= 0.0 or s.work_speed_multiplier <= 0.0:
			_err("staff %s invalid wage/speed" % s.id)
		if s.is_cashier() and s.cashier_service_seconds <= 0.0:
			_err("cashier %s needs service seconds" % s.id)
		if s.auto_retrieve_probability < 0.0 or s.auto_retrieve_probability > 1.0:
			_err("staff %s auto-retrieve outside 0..1" % s.id)


func _validate_locations() -> void:
	var seen: Dictionary = {}
	for l: LocationDefinition in _locations:
		_check_id(l.id, seen, "location")
		_check_text(l.localization_key, String(l.id))
		if equipment(l.storage_id) == null:
			_err("location %s storage %s missing" % [l.id, l.storage_id])
		if l.floors.is_empty():
			_err("location %s has no floors" % l.id)
			continue
		var q_phys: int = 0
		var q_rf: int = 0
		for f: FloorDefinition in l.floors:
			if f.size.x <= 0 or f.size.y <= 0:
				_err("location %s floor %s has no size" % [l.id, f.id])
			var cell_lists: Array = [f.entrance, f.protected_cells, f.staff_only, f.walls]
			for lst: Variant in cell_lists:
				for cell: Vector2i in lst:
					if not f.in_bounds(cell):
						_err("location %s floor %s cell %s out of bounds" % [l.id, f.id, cell])
			for lane: Dictionary in f.lanes:
				q_phys += (lane["queue"] as Array).size()
				for qc: Vector2i in lane["queue"]:
					if not f.in_bounds(qc):
						_err("location %s lane %s slot out of bounds" % [l.id, lane["id"]])
				if f.counter(lane["counter_id"]).is_empty():
					_err("location %s lane %s references missing counter" % [l.id, lane["id"]])
			if not f.rotifood_counter.is_empty():
				q_rf += (f.rotifood_counter["queue"] as Array).size()
			if f.has_portal():
				var target: FloorDefinition = l.floor_def(f.portal["target_floor"])
				if target == null or not target.has_portal():
					_err("location %s portal on %s has no paired portal" % [l.id, f.id])
		if q_phys != l.queue_capacity_physical:
			_err("location %s queue slots %d != capacity %d" % [l.id, q_phys, l.queue_capacity_physical])
		if q_rf != l.queue_capacity_rotifood:
			_err("location %s rotifood slots %d != capacity %d" % [l.id, q_rf, l.queue_capacity_rotifood])
	for t in range(1, 6):
		if location_by_tier(t) == null:
			_err("missing location for tier %d" % t)


func _validate_weather_marketing() -> void:
	var markov: Dictionary = _weather_raw.get("markov", {})
	for k: Variant in markov.keys():
		if weather(StringName(str(k))) == null:
			_err("weather markov row %s unknown" % k)
		var total: float = 0.0
		var row: Dictionary = markov[k]
		for k2: Variant in row.keys():
			if weather(StringName(str(k2))) == null:
				_err("weather markov target %s unknown" % k2)
			total += float(row[k2])
		if absf(total - 1.0) > 0.001:
			_err("weather markov row %s sums to %s" % [k, total])
	for w: Variant in _weather:
		_check_text((w as MiscDefinitions.WeatherDefinition).localization_key, "weather")
	var seen: Dictionary = {}
	for m: Variant in _campaigns:
		var c: MiscDefinitions.MarketingCampaignDefinition = m
		_check_id(c.id, seen, "campaign")
		_check_text(c.localization_key, String(c.id))
		_check_text(StringName(String(c.id) + "_desc"), String(c.id))
		if c.cost_kr < 0.0 or c.traffic_multiplier <= 0.0:
			_err("campaign %s invalid cost/multiplier" % c.id)
		for rid: StringName in c.recipe_preference_multipliers.keys():
			if recipe(rid) == null:
				_err("campaign %s references unknown recipe %s" % [c.id, rid])
		for aid: StringName in c.archetype_multipliers.keys():
			if archetype(aid) == null:
				_err("campaign %s references unknown archetype %s" % [c.id, aid])


func _validate_opening() -> void:
	for d: Variant in _opening.get("days", []):
		var day: Dictionary = d
		var r: RecipeDefinition = recipe(StringName(str(day.get("recipe_id", ""))))
		if r == null:
			_err("opening day %s recipe unknown" % day.get("day"))
			continue
		var total: int = 0
		for w: Variant in day.get("walk_ins", []):
			var wd: Dictionary = w
			total += int(wd["requested_quantity"])
			if archetype(StringName(str(wd["customer_archetype"]))) == null:
				_err("opening day %s unknown archetype" % day.get("day"))
		for o: Variant in day.get("rotifood_orders", []):
			total += int((o as Dictionary)["requested_quantity"])
		if total != int(day.get("batches", 0)) * r.batch_yield:
			_err("opening day %s demand %d != batches x yield" % [day.get("day"), total])


func _validate_meta() -> void:
	var seen: Dictionary = {}
	for a: Variant in _achievements:
		var ach: MiscDefinitions.AchievementDefinition = a
		_check_id(ach.id, seen, "achievement")
		_check_text(ach.localization_key, String(ach.id))
		_check_text(StringName(String(ach.id) + "_desc"), String(ach.id))
		if decoration(ach.reward_id) == null:
			_err("achievement %s reward %s missing" % [ach.id, ach.reward_id])
		var req: Dictionary = ach.requirement
		match str(req.get("type", "")):
			"stat_at_least":
				if not ACHIEVEMENT_STATS.has(str(req.get("stat", ""))):
					_err("achievement %s unknown stat" % ach.id)
			"condition":
				if not ACHIEVEMENT_CONDITIONS.has(str(req.get("condition", ""))):
					_err("achievement %s unknown condition" % ach.id)
			"balance_at_least", "location_tier_at_least":
				pass
			_:
				_err("achievement %s unknown requirement type" % ach.id)
	var seen_d: Dictionary = {}
	var types: Array = (_raw["decorations.json"] as Dictionary).get("placement_types", [])
	for x: Variant in _decorations:
		var dd: MiscDefinitions.DecorationDefinition = x
		_check_id(dd.id, seen_d, "decoration")
		_check_text(dd.localization_key, String(dd.id))
		if not types.has(String(dd.placement_type)):
			_err("decoration %s unknown placement type" % dd.id)
		if dd.price_kr < 0.0:
			_err("decoration %s negative price" % dd.id)
		if dd.placement_type == &"floor_prop" and dd.footprint_tiles == Vector2i.ZERO:
			_err("decoration %s floor_prop needs a footprint" % dd.id)
		if dd.placement_type != &"floor_prop" and dd.footprint_tiles != Vector2i.ZERO:
			_err("decoration %s footprint only allowed for floor_prop" % dd.id)
	var seen_a: Dictionary = {}
	for ae: Variant in _audio:
		var aed: MiscDefinitions.AudioEventDefinition = ae
		_check_id(aed.id, seen_a, "audio event")
		if not [&"Music", &"SFX", &"UI", &"Ambient"].has(aed.bus):
			_err("audio %s unknown bus %s" % [aed.id, aed.bus])
		if aed.priority < 0 or aed.priority > 4:
			_err("audio %s priority outside P0..P4" % aed.id)
	for q: Variant in _quality:
		_check_text((q as MiscDefinitions.QualityPresetDefinition).localization_key, "quality")


## Nilai balance yang saling bergantung (GDD 18.9, 21.4, 31.6, 31.7).
func _validate_balance() -> void:
	var factors: Dictionary = (_balance.get("production", {}) as Dictionary).get("batch_duration_factor", {})
	for m: Variant in (_balance.get("production", {}) as Dictionary).get("batch_multipliers", []):
		var key: String = str(int(m))
		if not factors.has(key):
			_err("production.batch_duration_factor has no entry for x%s" % key)
		elif float(factors[key]) < 1.0 or (key == "1" and not is_equal_approx(float(factors[key]), 1.0)):
			_err("production.batch_duration_factor x%s must be >= 1.0 (x1 exactly 1.0)" % key)
	if float((_balance.get("cashier", {}) as Dictionary).get("packing_seconds", 0.0)) <= 0.0:
		_err("cashier.packing_seconds must be positive")
	var p: Dictionary = _balance.get("presentation", {})
	var wipe: float = float(p.get("idle_wipe_after_seconds", 0.0))
	var doze: float = float(p.get("idle_doze_after_seconds", 0.0))
	if wipe <= 0.0 or doze <= wipe + float(p.get("wipe_gesture_seconds", 0.0)):
		_err("presentation idle gesture thresholds must be positive and the wipe must end before dozing")
	var thoughts: Array = p.get("thought_after_seconds", [])
	if thoughts.size() != THOUGHT_KEYS.size():
		_err("presentation.thought_after_seconds needs %d entries" % THOUGHT_KEYS.size())
	for i in thoughts.size():
		if float(thoughts[i]) <= (float(thoughts[i - 1]) + float(p.get("thought_show_seconds", 0.0)) if i > 0 else 0.0):
			_err("presentation.thought_after_seconds must rise and leave room for each bubble")
	for k: String in THOUGHT_KEYS:
		_check_text(StringName(k), "presentation")
