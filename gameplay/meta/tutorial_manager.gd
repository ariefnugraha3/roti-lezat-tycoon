class_name TutorialManager
extends SimManager
## TutorialManager — onboarding idle (GDD idle 13). Setiap langkah terpicu
## sekali oleh keadaan permainan, bisa ditutup, dan tidak pernah menahan
## ekonomi: tidak ada ketukan yang ditahan dan tidak ada fitur yang dikunci.

## Langkah onboarding, urut seperti tabel GDD idle 13.
const STEPS: Array[String] = ["onb_welcome", "onb_first_sale", "onb_first_upgrade", "onb_tap_boost", "onb_hire",
	"onb_recipe", "onb_offline", "onb_location", "onb_franchise"]
## Detik-simulasi antar-pemeriksaan pemicu.
const CHECK_SECONDS: float = 0.5

## Prompt aktif: {key, target} atau {}.
var prompt: Dictionary = {}
var done: Dictionary = {}
var skipped: bool = false
var _queue: Array[Dictionary] = []
var _check_left: float = 0.0


func new_game() -> void:
	prompt = {}
	done.clear()
	skipped = false
	_queue.clear()
	_check_left = 0.0


func skip() -> void:
	skipped = true
	prompt = {}
	_queue.clear()
	EventBus.tutorial_step_changed.emit(&"")


func hints_enabled() -> bool:
	return not skipped and SettingsManager.get_bool("tutorial_hints")


func has_done(key: String) -> bool:
	return done.has(key)


## Tampilkan langkah `key` sekali. `target` = sasaran sorotan HUD/dunia
## (`cash`, `tab_<id>`, `chip_<iid>`, `station_<iid>`); `style` = hint
## (petunjuk di atas bar tab), popup (sapaan Pak Lurah), atau spotlight.
func show_step(key: String, target: StringName = &"", style: String = "hint") -> void:
	if done.has(key) or skipped:
		return
	done[key] = true
	if not hints_enabled():
		return
	var p: Dictionary = {"key": key, "target": String(target), "style": style}
	if prompt.is_empty():
		prompt = p
		EventBus.tutorial_step_changed.emit(StringName(key))
	else:
		_queue.append(p)


## Pemain menutup prompt yang tampil.
func dismiss() -> void:
	prompt = _queue.pop_front() if not _queue.is_empty() else {}
	EventBus.tutorial_step_changed.emit(StringName(str(prompt.get("key", ""))))


func dismiss_key(key: String) -> void:
	if str(prompt.get("key", "")) == key:
		dismiss()


## Peristiwa permainan yang bisa memicu langkah onboarding.
func on_event(_ev: StringName) -> void:
	pass


## Pemicu GDD idle 13, diperiksa tiap CHECK_SECONDS. Hanya membaca state
## simulasi, jadi deterministik; tidak ada yang ditahan atau dikunci.
func step(dt: float) -> void:
	if skipped:
		return
	_check_left -= dt
	if _check_left > 0.0:
		return
	_check_left = CHECK_SECONDS
	_check()
	_auto_close()


func _check() -> void:
	show_step("onb_welcome", &"", "popup")
	if not done.has("onb_first_sale") and sim.statistics.get_stat("total_bread_sold") >= 1.0:
		show_step("onb_first_sale", &"cash", "spotlight")
	if not done.has("onb_first_upgrade") and done.has("onb_first_sale"):
		var oven: EquipmentInstance = _first(&"oven")
		if oven != null and sim.upgrades.offer_count(sim.upgrades.offer(&"station", oven.iid), &"x1") > 0:
			show_step("onb_first_upgrade", StringName("chip_%d" % oven.iid))
	if not done.has("onb_tap_boost") and _any_upgrade():
		show_step("onb_tap_boost")
	if not done.has("onb_hire") and done.has("onb_first_sale"):
		var cost: float = sim.staff.next_hire_cost()
		if cost >= 0.0 and sim.staff.hired_count() == 0 and sim.economy.can_afford(cost):
			show_step("onb_hire", &"tab_staff")
	if not done.has("onb_recipe") and done.has("onb_first_sale"):
		for r: RecipeDefinition in DataRegistry.recipes():
			if sim.upgrades.unlock_block(r.id) == &"":
				show_step("onb_recipe", &"tab_menu")
				break
	if not done.has("onb_location") and done.has("onb_first_sale") and sim.world.location.tier == 1 and sim.upgrade_block_reason() == "":
		show_step("onb_location", &"tab_shop")
	if not done.has("onb_franchise") and sim.prestige.franchise_block() == &"":
		show_step("onb_franchise", &"tab_franchise")


## Petunjuk yang sudah dikerjakan pemain menutup sendiri.
func _auto_close() -> void:
	if prompt.is_empty():
		return
	var key: String = str(prompt.get("key", ""))
	var finished: bool = false
	match key:
		"onb_first_upgrade", "onb_tap_boost":
			finished = key == "onb_first_upgrade" and _any_upgrade()
		"onb_hire":
			finished = sim.staff.hired_count() > 0
		"onb_recipe":
			finished = sim.upgrades.unlocked_recipes().size() > 1
		"onb_location":
			finished = sim.world.location.tier > 1
	if finished:
		dismiss()


func _first(cat: StringName) -> EquipmentInstance:
	var list: Array[EquipmentInstance] = sim.equipment.placed_list(cat)
	return list[0] if not list.is_empty() else null


## Pemain sudah membeli setidaknya satu level apa pun.
func _any_upgrade() -> bool:
	if sim.upgrades.counter_level > 1:
		return true
	for v: Variant in sim.upgrades.station_levels.values():
		if int(v) > 1:
			return true
	for v2: Variant in sim.upgrades.recipe_levels.values():
		if int(v2) > 1:
			return true
	for v3: Variant in sim.upgrades.staff_levels.values():
		if int(v3) > 1:
			return true
	for v4: Variant in sim.upgrades.global_levels.values():
		if int(v4) > 0:
			return true
	return false


## Arsip bantuan: kunci prompt yang sudah pernah tampil (v3.1 27.6).
func archive() -> Array[String]:
	var out: Array[String] = []
	for k: Variant in done.keys():
		var s: String = str(k)
		if s.begins_with("onb_"):
			out.append(s)
	return out


func capture() -> Dictionary:
	return {"done": done.keys(), "skipped": skipped, "prompt": prompt.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	for k: Variant in d.get("done", []):
		done[str(k)] = true
	skipped = bool(d.get("skipped", false))
	prompt = (d.get("prompt", {}) as Dictionary).duplicate()
