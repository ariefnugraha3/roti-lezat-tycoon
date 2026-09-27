class_name MarketingManager
extends SimManager
## MarketingManager — kampanye iklan aktif (GDD 8, 24.8, 48). Satu kampanye
## dalam satu waktu, dibayar di muka, berlaku pada lima DAY_OPEN berikutnya
## setelah aktivasi. Tidak ada cancel/refund.

## {} atau {campaign_id, start_day, remaining_days, upfront_cost_paid}
var active: Dictionary = {}


func new_game() -> void:
	active = {}


func campaign_def() -> MiscDefinitions.MarketingCampaignDefinition:
	if active.is_empty():
		return null
	return DataRegistry.campaign(StringName(str(active["campaign_id"])))


## Berlaku hari ini? Aktivasi after-hours berlaku mulai hari berikutnya.
func effective_today() -> bool:
	return not active.is_empty() and sim.time.day >= int(active["start_day"])


func can_launch(campaign_id: StringName) -> StringName:
	var c: MiscDefinitions.MarketingCampaignDefinition = DataRegistry.campaign(campaign_id)
	if c == null:
		return &"invalid"
	if not active.is_empty():
		return &"busy"
	if not sim.time.is_after_hours():
		return &"after_hours"
	if sim.world.location.tier < c.tier:
		return &"locked"
	if not sim.economy.can_afford(c.cost_kr):
		return &"kr"
	return &""


func launch(campaign_id: StringName) -> StringName:
	var reason: StringName = can_launch(campaign_id)
	if reason != &"":
		return reason
	var c: MiscDefinitions.MarketingCampaignDefinition = DataRegistry.campaign(campaign_id)
	sim.economy.spend(c.cost_kr, &"MARKETING_COST", campaign_id, {})
	active = {"campaign_id": String(campaign_id), "start_day": sim.time.day + 1,
		"remaining_days": int(DataRegistry.marketing_raw().get("duration_days", 5)), "upfront_cost_paid": c.cost_kr}
	SaveManager.request_autosave("marketing")
	return &""


func traffic_multiplier() -> float:
	return campaign_def().traffic_multiplier if effective_today() else 1.0


func recipe_preference_multiplier(recipe_id: StringName) -> float:
	if not effective_today():
		return 1.0
	return float(campaign_def().recipe_preference_multipliers.get(recipe_id, 1.0))


func archetype_multiplier(archetype_id: StringName, block: StringName) -> float:
	if not effective_today():
		return 1.0
	var c: MiscDefinitions.MarketingCampaignDefinition = campaign_def()
	var m: float = float(c.archetype_multipliers.get(archetype_id, 1.0))
	var tb: Dictionary = c.archetype_time_block_multipliers.get(archetype_id, {})
	m *= float(tb.get(block, 1.0))
	return m


func critic_chance_multiplier() -> float:
	return campaign_def().critic_chance_multiplier if effective_today() else 1.0


## Hari kampanye ke-n (1..5) untuk highlight.
func day_number() -> int:
	if not effective_today():
		return 0
	return int(DataRegistry.marketing_raw().get("duration_days", 5)) - int(active["remaining_days"]) + 1


## Settlement: bonus rating harian lalu kurangi sisa hari (GDD 8.2, 25.2).
func end_of_day(abandon_ratio: float) -> float:
	if not effective_today():
		return 0.0
	var c: MiscDefinitions.MarketingCampaignDefinition = campaign_def()
	var bonus: float = c.rating_per_day
	if c.rating_requires_smooth_queue and abandon_ratio > float(DataRegistry.marketing_raw().get("smooth_queue_max_abandon_ratio", 0.1)):
		bonus = 0.0
	if bonus > 0.0:
		sim.reputation.add_physical(bonus)
	active["remaining_days"] = int(active["remaining_days"]) - 1
	if int(active["remaining_days"]) <= 0:
		active = {}
	return bonus


func capture() -> Dictionary:
	return active.duplicate()


func restore(d: Dictionary) -> void:
	active = d.duplicate()
	if not active.is_empty() and DataRegistry.campaign(StringName(str(active.get("campaign_id", "")))) == null:
		active = {}
