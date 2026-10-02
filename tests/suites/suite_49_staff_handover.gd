extends TestSuite
## Pesanan "Ask a Baker" tidak pernah menjadi job yatim (GDD 3.2, 23.3, 87.2,
## 105 no.11). Job pesanan milik dapur: koki mana pun yang bertugas
## mengerjakannya, dan begitu koki terakhir pergi job itu berpindah ke pemain.

const LOAF: StringName = &"recipe_plain_loaf"


func tests() -> Array:
	return [
		{"id": "ACC_23_KITCHEN_HANDOVER", "name": "23.3 a kitchen order passes to the player, with a '!' on its station, when the last baker on shift leaves", "fn": _handover},
		{"id": "ACC_23_KITCHEN_NEXT_DAY", "name": "23.3 a kitchen order still in the oven at 18:00 is finished by a baker the next morning", "fn": _next_day},
	]


## Dua koki (Tier 4, batas 2) bertugas sejak 05:00, bahan Plain Loaf cukup.
func _sim_with_bakers() -> SimulationRoot:
	var s: SimulationRoot = new_sim(1880)
	s.tutorial.skip()
	jump_to_tier(s, 4)
	s.time.set_phase(TimeManager.AFTER_HOURS)
	eq(s.staff.hire(&"staff_baker_joko"), &"", "hire Joko")
	eq(s.staff.hire(&"staff_baker_ani"), &"", "hire Ani")
	s.continue_to_next_day()
	check(s.staff.is_working(&"staff_baker_joko") and s.staff.is_working(&"staff_baker_ani"), "both bakers are on shift")
	give(s, LOAF, 4)
	return s


static func give(s: SimulationRoot, recipe_id: StringName, batches: int) -> void:
	var r: RecipeDefinition = DataRegistry.recipe(recipe_id)
	var items: Dictionary = {}
	for ing: StringName in r.ingredients.keys():
		items[ing] = int(r.ingredients[ing]) * batches
	s.inventory.add_items(items)


static func step_until(s: SimulationRoot, cond: Callable, max_ticks: int = 6000) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		s.step(s.tick_seconds)
	return cond.call()


static func only_job(s: SimulationRoot) -> ProductionJob:
	var list: Array[ProductionJob] = s.production.sorted_jobs()
	return list[list.size() - 1] if not list.is_empty() else null


func _handover() -> void:
	var s: SimulationRoot = _sim_with_bakers()
	eq(s.staff.order_recipe(LOAF, 1), "", "ask a baker for one batch of Plain Loaf")
	var j: ProductionJob = only_job(s)
	eq(j.owner_actor_id, StaffManager.KITCHEN_ID, "the order belongs to the kitchen")
	check(step_until(s, func() -> bool: return j.stage == ProductionJob.MIXING), "a baker starts mixing without a tap")
	eq(s.staff.set_on_duty(&"staff_baker_joko", false), &"", "bench Joko")
	eq(j.owner_actor_id, StaffManager.KITCHEN_ID, "Ani is still on shift, so the order stays with the kitchen")
	eq(s.staff.set_on_duty(&"staff_baker_ani", false), &"", "bench Ani too")
	eq(j.owner_actor_id, PlayerTaskManager.PLAYER_ID, "with no baker left the order passes to the player")
	check(step_until(s, func() -> bool: return j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP), "the dough finishes")
	var m: Dictionary = s.player.station_markers().get(j.mixer_id, {})
	eq(m.get("mode", &""), &"alert", "the mixer shows the player's '!'")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _next_day() -> void:
	var s: SimulationRoot = _sim_with_bakers()
	eq(s.staff.order_recipe(LOAF, 1), "", "ask a baker for one batch")
	var j: ProductionJob = only_job(s)
	var jid: int = j.job_id
	check(step_until(s, func() -> bool: return j.stage == ProductionJob.BAKING), "the batch reaches the oven")
	s.time.time_seconds = s.time.close_time
	s.close_day()
	check(s.staff.actors.is_empty(), "the bakers go home at closing")
	eq(j.stage, ProductionJob.BAKING, "the batch waits in the oven overnight")
	eq(j.owner_actor_id, StaffManager.KITCHEN_ID, "still a kitchen order")
	s.enter_after_hours()
	check(s.continue_to_next_day(), "the next day starts")
	var before: int = s.display.total_units()
	check(step_until(s, func() -> bool: return s.production.get_job(jid) == null), "a baker finishes the order next morning")
	eq(s.display.total_units(), before + DataRegistry.recipe(LOAF).batch_yield, "the bread reaches a shelf")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)
