class_name TutorialSpotlight
extends UIScreen
## Sorotan onboarding (GDD idle 13): layar diredupkan kecuali bagian yang
## sedang dijelaskan (chip KR dan KR/s, tombol tab, kartu upgrade, atau model di
## dunia). Langkahnya dari params {key, target} atau {steps: [[key, target], …]};
## sasaran dicari ulang tiap frame. Selesai (Got it, Skip, Back) menutup prompt
## lewat `TutorialManager.dismiss_key`. Sorotan hanya menjelaskan: bagian yang
## disorot tidak menerima ketukan.

## Sorotan dunia paling kecil (px).
const MIN_WORLD_HOLE := Vector2(120.0, 120.0)

var _marks: CoachMarks = null


## Lapisan sistem: di atas modal lain, tidak menutupnya (v3.1 28.2).
func _init() -> void:
	super._init()
	overlay = true


func build() -> void:
	var raw: Array = params.get("steps", [[str(params.get("key", "")), str(params.get("target", ""))]])
	var steps: Array[Dictionary] = []
	for st: Variant in raw:
		var a: Array = st
		steps.append({"targets": _targets.bind(StringName(str(a[1]))), "key": str(a[0]), "next": true})
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


## Sasaran sorotan: chip HUD, tombol tab (`tab_<id>`), atau alat di dunia
## (`station_<iid>`).
func _targets(target: StringName) -> Array:
	var hud: HUD = game.hud if game != null else null
	var world: WorldView = game.world if game != null else null
	var t: String = String(target)
	if hud != null:
		match t:
			"cash":
				return [hud.cash_chip(), hud.rate_label()]
			"reputation":
				return [hud.reputation_chip()]
		if t.begins_with("tab_"):
			var b: Button = hud.tab_button(StringName(t.substr(4)))
			return [b] if b != null else []
	if world != null and t.begins_with("station_"):
		var node: Variant = world.furniture.get(int(t.substr(8)))
		return [world.screen_rect_of([node], MIN_WORLD_HOLE)] if node != null else []
	return []
