class_name MiscDefinitions
extends RefCounted
## Pabrik definisi kecil (GDD 101.7): Achievement, AudioEvent, Decoration,
## Weather, MarketingCampaign, QualityPreset. Dipisah dari file resep/staf karena
## masing-masing hanya beberapa field; tetap bertipe lewat kelas dalam.


class AchievementDefinition:
	extends RefCounted
	var id: StringName
	var localization_key: StringName
	var requirement: Dictionary = {}
	var reward_id: StringName

	static func from_dict(d: Dictionary) -> AchievementDefinition:
		var a := AchievementDefinition.new()
		a.id = StringName(str(d.get("id", "")))
		a.localization_key = StringName(str(d.get("localization_key", "")))
		a.requirement = d.get("requirement", {})
		a.reward_id = StringName(str(d.get("reward_id", "")))
		return a


class AudioEventDefinition:
	extends RefCounted
	var id: StringName
	var bus: StringName
	var priority: int = 2
	var generator: StringName
	var loop: bool = false
	var cooldown: float = 0.0
	var volume_db: float = 0.0

	static func from_dict(d: Dictionary) -> AudioEventDefinition:
		var a := AudioEventDefinition.new()
		a.id = StringName(str(d.get("id", "")))
		a.bus = StringName(str(d.get("bus", "SFX")))
		a.priority = int(d.get("priority", 2))
		a.generator = StringName(str(d.get("generator", "")))
		a.loop = bool(d.get("loop", false))
		a.cooldown = float(d.get("cooldown", 0.0))
		a.volume_db = float(d.get("volume_db", 0.0))
		return a


class DecorationDefinition:
	extends RefCounted
	var id: StringName
	var localization_key: StringName
	var placement_type: StringName
	var price_kr: float = 0.0
	var source: StringName
	## Hanya floor_prop (GDD 101.7).
	var footprint_tiles: Vector2i = Vector2i.ZERO
	var overlay_size_tiles: Vector2i = Vector2i.ZERO
	var skin_target: StringName
	var visual_profile_id: StringName

	static func from_dict(d: Dictionary) -> DecorationDefinition:
		var x := DecorationDefinition.new()
		x.id = StringName(str(d.get("id", "")))
		x.localization_key = StringName(str(d.get("localization_key", "")))
		x.placement_type = StringName(str(d.get("placement_type", "")))
		x.price_kr = float(d.get("price_kr", 0.0))
		x.source = StringName(str(d.get("source", "shop")))
		var fp: Variant = d.get("footprint_tiles")
		if fp is Array:
			x.footprint_tiles = Vector2i(int(fp[0]), int(fp[1]))
		var ov: Variant = d.get("overlay_size_tiles")
		if ov is Array:
			x.overlay_size_tiles = Vector2i(int(ov[0]), int(ov[1]))
		x.skin_target = StringName(str(d.get("skin_target", "")))
		x.visual_profile_id = StringName(str(d.get("visual_profile_id", "")))
		return x

	func uses_floor_cell() -> bool:
		return placement_type == &"floor_prop"

	func is_placeable() -> bool:
		return placement_type in [&"wall", &"floor_prop", &"floor_overlay", &"counter_prop"]


class WeatherDefinition:
	extends RefCounted
	var id: StringName
	var localization_key: StringName
	var physical_traffic_multiplier_min: float = 1.0
	var physical_traffic_multiplier_max: float = 1.0
	var delivery_multiplier_min: float = 1.0
	var delivery_multiplier_max: float = 1.0
	var visual_profile: StringName
	var audio_profile: StringName

	static func from_dict(d: Dictionary) -> WeatherDefinition:
		var w := WeatherDefinition.new()
		w.id = StringName(str(d.get("id", "")))
		w.localization_key = StringName(str(d.get("localization_key", "")))
		w.physical_traffic_multiplier_min = float(d.get("physical_traffic_multiplier_min", 1.0))
		w.physical_traffic_multiplier_max = float(d.get("physical_traffic_multiplier_max", 1.0))
		w.delivery_multiplier_min = float(d.get("delivery_multiplier_min", 1.0))
		w.delivery_multiplier_max = float(d.get("delivery_multiplier_max", 1.0))
		w.visual_profile = StringName(str(d.get("visual_profile", "")))
		w.audio_profile = StringName(str(d.get("audio_profile", "")))
		return w


class MarketingCampaignDefinition:
	extends RefCounted
	var id: StringName
	var localization_key: StringName
	var tier: int = 1
	var cost_kr: float = 0.0
	var traffic_multiplier: float = 1.0
	var rating_per_day: float = 0.0
	var rating_requires_smooth_queue: bool = false
	var recipe_preference_multipliers: Dictionary = {}
	var archetype_multipliers: Dictionary = {}
	var archetype_time_block_multipliers: Dictionary = {}
	var critic_chance_multiplier: float = 1.0

	static func from_dict(d: Dictionary) -> MarketingCampaignDefinition:
		var m := MarketingCampaignDefinition.new()
		m.id = StringName(str(d.get("id", "")))
		m.localization_key = StringName(str(d.get("localization_key", "")))
		m.tier = int(d.get("tier", 1))
		m.cost_kr = float(d.get("cost_kr", 0.0))
		m.traffic_multiplier = float(d.get("traffic_multiplier", 1.0))
		m.rating_per_day = float(d.get("rating_per_day", 0.0))
		m.rating_requires_smooth_queue = bool(d.get("rating_requires_smooth_queue", false))
		var rp: Dictionary = d.get("recipe_preference_multipliers", {})
		for k: Variant in rp.keys():
			m.recipe_preference_multipliers[StringName(str(k))] = float(rp[k])
		var am: Dictionary = d.get("archetype_multipliers", {})
		for k2: Variant in am.keys():
			m.archetype_multipliers[StringName(str(k2))] = float(am[k2])
		var at: Dictionary = d.get("archetype_time_block_multipliers", {})
		for k3: Variant in at.keys():
			var inner: Dictionary = {}
			var src: Dictionary = at[k3]
			for b: Variant in src.keys():
				inner[StringName(str(b))] = float(src[b])
			m.archetype_time_block_multipliers[StringName(str(k3))] = inner
		m.critic_chance_multiplier = float(d.get("critic_chance_multiplier", 1.0))
		return m


class QualityPresetDefinition:
	extends RefCounted
	var id: StringName
	var localization_key: StringName
	var shadows: bool = false
	var particle_scale: float = 1.0
	var resolution_scale: float = 1.0
	var msaa: int = 0
	var decor_density: float = 1.0
	var offfloor_visual_hz: float = 4.0

	static func from_dict(d: Dictionary) -> QualityPresetDefinition:
		var q := QualityPresetDefinition.new()
		q.id = StringName(str(d.get("id", "")))
		q.localization_key = StringName(str(d.get("localization_key", "")))
		q.shadows = bool(d.get("shadows", false))
		q.particle_scale = float(d.get("particle_scale", 1.0))
		q.resolution_scale = float(d.get("resolution_scale", 1.0))
		q.msaa = int(d.get("msaa", 0))
		q.decor_density = float(d.get("decor_density", 1.0))
		q.offfloor_visual_hz = float(d.get("offfloor_visual_hz", 4.0))
		return q
