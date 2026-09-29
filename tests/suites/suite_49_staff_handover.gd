extends TestSuite
## Baker yang pergi tidak meninggalkan job yatim (GDD 18.8, 87.2, 105 no.11).
## Sebelumnya loyang bisa terlindung untuk baker yang sudah dipecat: tidak ada yang
## boleh mengambilnya, oven macet selamanya, dan upgrade lokasi tertahan.


func tests() -> Array:
	return [
		{"id": "ACC_18_RETRIEVE_ABSENT_BAKER", "name": "18.8 auto-retrieve only protects a tray for a baker who is still on shift; a fired or benched baker's trays and jobs pass to the player", "fn": _absent_baker},
		{"id": "ACC_18_RETRIEVE_NEXT_DAY", "name": "18.8 a protected tray left at 18:00 is claimed again by the baker who baked it", "fn": _next_day},
		{"id": "ACC_23_BAKER_CUTOFF", "name": "23.3 bakers only start a batch that finishes by staff_ai.baker_finish_by_seconds, so the kitchen is empty at closing", "fn": _baker_cutoff},
	]


## Batas mulai batch baker (GDD 23.3, keputusan maintainer 2026-09-29).
func _baker_cutoff() -> void:
	var s: SimulationRoot = new_sim(2330)
	var sid: StringName = &"staff_baker_joko"
	var def: StaffDefinition = DataRegistry.staff(sid)
	var loaf: RecipeDefinition = DataRegistry.recipe(&"recipe_plain_loaf")
	var finish_by: float = DataRegistry.balf("staff_ai.baker_finish_by_seconds")
	near(finish_by, 17.5 * 3600.0, 0.001, "bakers must be done by 17:30")
	s.debug_set_time(16.0 * 3600.0)
	var plan: Dictionary = s.staff._plan_new_job(sid, def)
	eq(StringName(str(plan.get("recipe", ""))), loaf.id, "at 16:00 the baker still starts a batch")
	var b: int = int(plan.get("batch", 0))
	var secs: float = s.production.mixer_stage_seconds(loaf, 1, b, 1.0) + s.production.oven_stage_seconds(loaf, 1, b, 1.0)
	check(s.time.time_seconds + secs * s.time.ratio <= finish_by, "and it finishes before 17:30")
	# Batch terbesar tidak selesai, batch lebih kecil masih sempat.
	var x3: float = (s.production.mixer_stage_seconds(loaf, 1, 3, 1.0) + s.production.oven_stage_seconds(loaf, 1, 3, 1.0)) * s.time.ratio
	var x1: float = (s.production.mixer_stage_seconds(loaf, 1, 1, 1.0) + s.production.oven_stage_seconds(loaf, 1, 1, 1.0)) * s.time.ratio
	s.debug_set_time(finish_by - (x1 + x3) * 0.5)
	eq(int(s.staff._plan_new_job(sid, def).get("batch", 0)), 1, "close to the cutoff only a small batch still fits")
	s.debug_set_time(finish_by - x1 * 0.5)
	check(s.staff._plan_new_job(sid, def).is_empty(), "after that the baker starts nothing new")
	check(s.staff.finishes_before_cutoff(loaf, 1, def.work_speed_multiplier * 10.0), "a much faster baker would still make it")
	free_sim(s)


func _step_production(s: SimulationRoot, cond: Callable, max_ticks: int = 6000) -> bool:
	for i in max_ticks:
		if cond.call():
			return true
		s.production.step(s.tick_seconds)
	return cond.call()


## Dua baker Tier 5 (auto-retrieve 100%) bertugas di Ruko pada Hari 3.
func _sim_with_bakers() -> SimulationRoot:
	var s: SimulationRoot = new_sim(1880)
	s.tutorial.skip()
	jump_to_tier(s, 2)
	s.time.set_phase(TimeManager.AFTER_HOURS)
	eq(s.staff.hire(&"staff_baker_pierre"), &"", "hire Pierre")
	eq(s.staff.hire(&"staff_baker_mawar"), &"", "hire Mawar")
	s.continue_to_next_day()
	check(s.staff.is_working(&"staff_baker_pierre") and s.staff.is_working(&"staff_baker_mawar"), "both bakers are on shift")
	return s


## Job `baker` sampai tahap BAKING di oven bebas.
func _baking_by(s: SimulationRoot, baker: StringName) -> ProductionJob:
	var r: RecipeDefinition = DataRegistry.recipe(&"recipe_sugar_donut")
	var j: ProductionJob = s.production.create_job(r.id, 1, baker)
	s.production.start_mixing(j.job_id, baker, 2.8)
	_step_production(s, func() -> bool: return j.stage == ProductionJob.MIX_DONE_WAITING_PICKUP)
	s.production.pickup_dough(j.job_id, baker)
	s.production.insert_oven(j.job_id, s.production.free_oven_for(r).iid, baker, 2.8)
	eq(j.stage, ProductionJob.BAKING, "%s's batch is baking" % baker)
	return j


func _absent_baker() -> void:
	var s: SimulationRoot = _sim_with_bakers()
	# Pierre diliburkan saat batch-nya masih di oven.
	var a: ProductionJob = _baking_by(s, &"staff_baker_pierre")
	eq(s.staff.set_on_duty(&"staff_baker_pierre", false), &"", "bench Pierre mid-bake")
	eq(a.owner_actor_id, PlayerTaskManager.PLAYER_ID, "his unfinished batch passes to the player")
	_step_production(s, func() -> bool: return a.is_waiting_oven_pickup())
	check(not a.protected and a.claimed_by == &"", "no protection for a baker who left: the player is alerted instead")
	check(s.player.station_markers().has(a.oven_id), "the oven shows the player's '!' marker")
	check(bool(s.production.pickup_tray(a.job_id, PlayerTaskManager.PLAYER_ID).get("ok", false)), "the player takes it out")
	s.production.auto_place_tray(a.job_id, -1)
	# Mawar masih bertugas: loyangnya terlindung, lalu ia dipecat sebelum mengambilnya.
	var b: ProductionJob = _baking_by(s, &"staff_baker_mawar")
	_step_production(s, func() -> bool: return b.is_waiting_oven_pickup())
	check(b.protected and b.claimed_by == &"staff_baker_mawar", "a baker on shift protects her tray (100% auto-retrieve)")
	eq(s.staff.fire(&"staff_baker_mawar"), &"", "fire Mawar before she collects it")
	check(not b.protected and b.claimed_by == &"", "the tray is released to the player")
	eq(b.owner_actor_id, PlayerTaskManager.PLAYER_ID, "and belongs to the player")
	check(s.player.station_markers().has(b.oven_id), "with a '!' marker on the oven")
	var r: Dictionary = s.production.pickup_tray(b.job_id, PlayerTaskManager.PLAYER_ID)
	check(bool(r.get("ok", false)), "the player can take it out")
	eq(s.check_invariants(), "", "invariants")
	free_sim(s)


func _next_day() -> void:
	var s: SimulationRoot = _sim_with_bakers()
	var j: ProductionJob = _baking_by(s, &"staff_baker_pierre")
	_step_production(s, func() -> bool: return j.is_waiting_oven_pickup())
	check(j.protected, "Pierre's tray is protected")
	# 18:00 melepas klaim; baker yang sama mengklaimnya lagi keesokan hari.
	s.staff.end_day()
	eq(j.claimed_by, &"", "the claim is released at closing")
	check(j.protected, "the tray stays protected overnight")
	s.staff.begin_day()
	var sid: StringName = &"staff_baker_pierre"
	var task: Dictionary = s.staff._choose_task(sid, s.staff.actors[sid], DataRegistry.staff(sid))
	eq(str(task.get("type", "")), "pickup_tray", "Pierre goes back for his own tray")
	eq(int(task.get("job_id", -1)), j.job_id, "the right tray")
	eq(j.claimed_by, sid, "and claims it again")
	free_sim(s)
