extends TestSuite
## Penanda bar progres setelah tata letak dibangun ulang (v3.1 7, 18.6).


func tests() -> Array:
	return [
		{"id": "ACC_7_MARKER_REBUILD", "name": "7 a rebuilt layout leaves no frozen progress bar behind; a finished station shows a full bar until it is emptied; markers hide in Decoration Mode", "fn": _marker_rebuild},
	]


## Sebelum perbaikan, penanda menempel di node lantai dan tidak ikut dibebaskan
## saat perabot dibangun ulang: bar progres lama membeku di atas alat selamanya.
func _marker_rebuild() -> void:
	PauseManager.clear_all()
	var s: SimulationRoot = new_sim(707)
	s.tutorial.skip()
	freeze_production(s)
	var world := WorldView.new()
	runner.add_child(world)
	world.setup(s)
	var mixer: EquipmentInstance = s.equipment.placed_list(&"mixer")[0]
	var j: ProductionJob = s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
	check(j != null and j.mixer_id == mixer.iid, "a job waits at the mixer")
	if j == null:
		world.queue_free()
		free_sim(s)
		return
	s.production.start_mixing(j.job_id, &"test")
	world._update_markers()
	var old: StationMarker = world.markers[mixer.iid]
	eq(old.mode, StationMarker.MODE_PROGRESS, "the mixing mixer shows a progress bar")
	# Tata letak berubah di tengah jalan (Decoration Mode, stasiun baru, evolusi).
	s.world.layout_changed.emit()
	await runner.get_tree().process_frame
	check(not is_instance_valid(old), "the old marker is freed together with the old furniture")
	eq(_markers_in(world).size(), world.markers.size(), "only the current markers exist in the world")
	s.run_for(j.stage_duration + 0.5)
	eq(j.stage, ProductionJob.MIX_DONE_WAITING_PICKUP, "mixing finished")
	world._update_markers()
	eq((world.markers[mixer.iid] as StationMarker).mode, StationMarker.MODE_PROGRESS, "the finished mixer keeps a full bar while it holds the dough")
	s.production.pickup_dough(j.job_id, &"test")
	world._update_markers()
	var bars: int = 0
	for m: StationMarker in _markers_in(world):
		if m.visible and m.mode == StationMarker.MODE_PROGRESS:
			bars += 1
	eq(bars, 0, "no progress bar is left once the station is emptied")
	s.production.create_job(&"recipe_plain_loaf", 1, mixer, -1, -1, &"test")
	s.production.start_mixing(mixer.job_id, &"test")
	world.decoration_mode = true
	world._update_markers()
	var shown: int = 0
	for m2: StationMarker in _markers_in(world):
		if m2.visible:
			shown += 1
	eq(shown, 0, "markers hide while the layout is being arranged")
	world.queue_free()
	await runner.get_tree().process_frame
	free_sim(s)


func _markers_in(root: Node) -> Array[StationMarker]:
	var out: Array[StationMarker] = []
	var todo: Array[Node] = [root]
	while not todo.is_empty():
		var n: Node = todo.pop_back()
		for c: Node in n.get_children():
			todo.append(c)
		if n is StationMarker and not n.is_queued_for_deletion():
			out.append(n as StationMarker)
	return out
