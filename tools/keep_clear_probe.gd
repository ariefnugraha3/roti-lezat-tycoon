extends Node
## Probe aturan keep-clear (v3.1 17.3-17.4, 56.1, idle 20 no. 86): untuk setiap
## tier, toko yang terisi penuh (semua slot stasiun dibuka) dicetak per lantai:
##   # perabot   a ubin akses   w jalur terlindung   q antrean   s titik layan
##   c leher botol   . bebas   x struktur   P portal   (spasi) di luar zona
## lalu setiap ubin leher botol dan bebas diperiksa brute force: ditutup sendirian,
## apakah jalur wajib putus? Juga ubin bebas yang tidak bisa ditempati perabot
## yang sudah ada di lantai itu (rotasi mana pun).
##   godot --headless --path . res://tools/keep_clear_probe.tscn [-- --tier=2] [-- --save=C:/copy/of/save.json]

var _issues: int = 0
## Toko baru tanpa slot tambahan (--bare): layout awal setiap tier.
var _bare: bool = false


func _ready() -> void:
	var only: int = 0
	var save_path: String = ""
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--tier="):
			only = int(a.substr(7))
		elif a.begins_with("--save="):
			save_path = a.substr(7)
		elif a == "--bare":
			_bare = true
	if save_path != "":
		# Layout dari salinan save (hanya dibaca, tidak pernah ditulis).
		var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
		var ls := SimulationRoot.new()
		add_child(ls)
		ls.load_from_save(d)
		for lf: StringName in ls.world.floor_ids():
			_report(ls, ls.world.location.tier, lf)
		remove_child(ls)
		ls.free()
		print("KEEP_CLEAR_PROBE done, %d issues" % _issues)
		get_tree().quit()
		return
	for tier in range(1, 6):
		if only > 0 and tier != only:
			continue
		var s := SimulationRoot.new()
		add_child(s)
		s.start_new_game(&"probe", "Probe Bakery", "male", 4242)
		s.tutorial.skip()
		while s.world.location.tier < tier:
			s.debug_add_kr(s.location_price(s.world.location.tier + 1))
			if s.upgrade_location() != "":
				break
		s.debug_add_kr(1.0e15)
		for cat: StringName in [&"display", &"oven", &"mixer"]:
			while not _bare and s.upgrades.open_station(cat) >= 0:
				pass
		for fid: StringName in s.world.floor_ids():
			_report(s, tier, fid)
		remove_child(s)
		s.free()
	print("KEEP_CLEAR_PROBE done, %d issues" % _issues)
	get_tree().quit()


func _report(s: SimulationRoot, tier: int, fid: StringName) -> void:
	var w: WorldManager = s.world
	var fg: FloorGrid = w.grid(fid)
	var kc: Dictionary = w.keep_clear_cells(fid)
	print("--- tier %d %s (%dx%d) ---" % [tier, fid, fg.size.x, fg.size.y])
	var free: Array[Vector2i] = []
	for z in fg.size.y:
		var row: String = ""
		for x in fg.size.x:
			var c := Vector2i(x, z)
			var ch: String = " "
			if c == fg.portal_cell:
				ch = "P"
			elif fg.furniture_at.has(c):
				ch = "#"
			elif fg.decor_at.has(c):
				ch = "d"
			elif kc.has(c):
				ch = {&"walkway": "w", &"queue": "q", &"service": "s", &"access": "a", &"chokepoint": "c"}.get(kc[c], "?")
			elif fg.def.zone_at(c) == &"":
				ch = " "
			elif fg.flag(c) == FloorGrid.Flag.WALKABLE_BUILDABLE:
				ch = "."
				free.append(c)
			else:
				ch = "x"
			row += ch
		print("  " + row)
	# Brute force: tutup satu ubin (dekor palsu), apakah jalur wajib putus?
	for c2: Vector2i in kc.keys():
		if kc[c2] != &"chokepoint":
			continue
		if not _cuts(w, fg, c2):
			print("  FALSE CHOKEPOINT %s" % str(c2))
			_issues += 1
	for c3: Vector2i in free:
		if _cuts(w, fg, c3):
			print("  MISSED CHOKEPOINT %s" % str(c3))
			_issues += 1
	# Ubin bebas yang tidak bisa ditempati perabot mana pun di lantai ini.
	var kinds: Dictionary = {}
	for e: EquipmentInstance in s.equipment.placed_list():
		if e.floor_id == fid and not kinds.has(e.def().id):
			kinds[e.def().id] = e
	var coverable: Dictionary = {}
	for e2: EquipmentInstance in kinds.values():
		for z2 in fg.size.y:
			for x2 in fg.size.x:
				for rot in 4:
					var anchor := Vector2i(x2, z2)
					if w.validate_placement(e2, fid, anchor, rot) != &"":
						continue
					for fc: Vector2i in GridMath.footprint_cells(anchor, e2.def().footprint_tiles, rot):
						if not coverable.has(fc):
							coverable[fc] = []
						if not (coverable[fc] as Array).has(String(e2.def().id)):
							(coverable[fc] as Array).append(String(e2.def().id))
	var dead: Array = []
	for c4: Vector2i in free:
		if not coverable.has(c4):
			dead.append(c4)
	print("  free %d, no furniture fits on %d: %s" % [free.size(), dead.size(), str(dead)])
	print("  kinds on floor: %s" % str(kinds.keys()))
	for e3: EquipmentInstance in s.equipment.placed_list():
		if e3.floor_id == fid:
			if e3.iid < 0:
				continue
			print("  %s iid %d anchor %s rot %d cells %s access %s" % [e3.def().id, e3.iid, str(e3.anchor), e3.rotation,
				str(e3.footprint_cells()), str(w.access_of(e3.iid).get("cell", "-"))])


func _cuts(w: WorldManager, fg: FloorGrid, c: Vector2i) -> bool:
	if not w._connectivity_ok():
		return true
	fg.decor_at[c] = -99
	var ok: bool = w._connectivity_ok()
	fg.decor_at.erase(c)
	return not ok
