class_name TutorialSpotlight
extends UIScreen
## Sorotan tutorial yang mem-pause game (GDD 27.5, 88.1; keputusan maintainer
## 2026-10-08). Layar diredupkan kecuali bagian yang sedang dijelaskan: chip
## rating dan panel RotiFood di HUD saat toko buka, atau di dunia pembeli
## pertama, meja kasir, pengunjung lihat-lihat yang pulang, dan pemeran
## kejutan. Langkahnya dari `TutorialManager.SPOTLIGHTS`; sasaran dunia dicari
## ulang tiap frame lewat `WorldView.screen_rect_of`. Selesai (Got it, Skip,
## Back) menutup prompt-nya lewat `TutorialManager.dismiss_key`, jadi tutorial
## lanjut. Sorotan ini hanya menjelaskan: bagian yang disorot tidak menerima
## ketukan.

## Sorotan dunia paling kecil (px), supaya kupu-kupu atau burung pipit tetap
## jelas terlihat.
const MIN_WORLD_HOLE := Vector2(120.0, 120.0)

var _marks: CoachMarks = null


## Lapisan sistem: di atas modal lain, tidak menutupnya (GDD 28.2).
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var steps: Array[Dictionary] = []
	for st: Variant in TutorialManager.spotlight_steps(StringName(str(params.get("spotlight", "")))):
		var a: Array = st
		steps.append({"targets": _targets.bind(StringName(a[1])), "key": str(a[0]), "next": true})
	if steps.is_empty():
		_done.call_deferred()
		return
	_marks = CoachMarks.new()
	_marks.finished.connect(_done)
	add_child(_marks)
	_marks.setup(steps)


## Tur sorotannya (untuk tes), atau null.
func marks() -> CoachMarks:
	return _marks if _marks != null and is_instance_valid(_marks) else null


func on_back() -> bool:
	if marks() != null:
		_marks.finish()
	else:
		_done()
	return true


func _done() -> void:
	if is_queued_for_deletion():
		return
	close()
	if sim != null:
		sim.tutorial.dismiss_key(str(params.get("key", "")))


func _targets(target: StringName) -> Array:
	var hud: HUD = game.hud if game != null else null
	var world: WorldView = game.world if game != null else null
	match target:
		&"store_rating":
			return [hud.rating_chip()] if hud != null else []
		&"rotifood_rating":
			return [hud.rotifood_rating_chip()] if hud != null else []
		&"rotifood_panel":
			return [hud.rotifood_panel()] if hud != null else []
		&"rotifood_order":
			# Seluruh panel: pesanan barunya dan tombol RotiFood yang berdering.
			return [hud.rotifood_panel()] if hud != null else []
		&"buyer":
			# Pembelinya dan rak yang ia tuju ("ambil roti dari rak").
			var c: Customer = sim.customers.first_buyer()
			var out: Array = _actor_rects(world, c)
			if world != null and c != null and c.target_display >= 0:
				out.append(world.screen_rect_of([world.furniture.get(c.target_display)]))
			return out
		&"counter":
			return [world.screen_rect_of([world.main_counter()], MIN_WORLD_HOLE)] if world != null else []
		&"window_shopper":
			return _actor_rects(world, _window_shopper())
		&"surprise":
			if world == null:
				return []
			var cast: Array = [world.screen_rect_of(world.surprises.cast_nodes(), MIN_WORLD_HOLE)]
			for b: ThoughtBubble in world.surprises.bubbles_showing():
				cast.append(b.panel_rect())
			return cast
		&"speed_row":
			return [hud.speed_row()] if hud != null else []
		&"close_early":
			return [hud.close_early_button()] if hud != null else []
		&"weather":
			return [hud.weather_icon()] if hud != null else []
		&"holiday":
			return [hud.holiday_label()] if hud != null else []
		&"floors":
			return [hud.floor_buttons()] if hud != null else []
		&"solo":
			return [hud.solo_label()] if hud != null else []
		&"decor_button":
			return [hud.decoration_button()] if hud != null else []
		&"portal":
			return [world.screen_rect_of([world.portal_node()], MIN_WORLD_HOLE)] if world != null else []
		&"cashier_staff":
			return _cashier_rects(world)
		&"critic":
			return _actor_rects(world, _critic())
		&"shelf":
			var iid: int = int(params.get("target_iid", -1))
			if world == null or iid < 0:
				return []
			return [world.screen_rect_of([world.furniture.get(iid)], MIN_WORLD_HOLE)]
	return []


## Kasir staf yang sedang bertugas dan meja jalurnya (GDD 21.2).
func _cashier_rects(world: WorldView) -> Array:
	if world == null:
		return []
	var out: Array = []
	for sid: Variant in sim.staff.lane_assign.keys():
		var a: SimActor = sim.staff.actors.get(sid)
		var nodes: Array = [world.counter_of(sim.queue.lane(StringName(str(sim.staff.lane_assign[sid]))))]
		if a != null:
			nodes.append(world.views.get(a.id))
		out.append(world.screen_rect_of(nodes, MIN_WORLD_HOLE))
	return out


## Food Vlogger yang sedang di toko, atau null.
func _critic() -> Customer:
	for c: Customer in sim.customers.sorted():
		if c.is_critic:
			return c
	return null


## Model pelanggan `c` di layar, beserta gelembung celetukannya bila ada.
func _actor_rects(world: WorldView, c: Customer) -> Array:
	if world == null or c == null:
		return []
	var out: Array = [world.screen_rect_of([world.views.get(c.id)], MIN_WORLD_HOLE)]
	var b: ThoughtBubble = world.shopper_bubble(c.id)
	if b != null:
		out.append(b.panel_rect())
	return out


## Pengunjung lihat-lihat yang sedang pulang (yang memicu tip ini), atau yang
## masih melihat-lihat bila tidak ada.
func _window_shopper() -> Customer:
	var looking: Customer = null
	for c: Customer in sim.customers.sorted():
		if not c.window_shopper:
			continue
		if c.state == Customer.LEAVING:
			return c
		if looking == null:
			looking = c
	return looking
