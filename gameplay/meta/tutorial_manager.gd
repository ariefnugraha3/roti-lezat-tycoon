class_name TutorialManager
extends SimManager
## TutorialManager — onboarding idle (GDD idle 13). Setiap langkah terpicu
## sekali oleh keadaan permainan, bisa ditutup, dan tidak pernah menahan
## ekonomi: tidak ada ketukan yang ditahan dan tidak ada fitur yang dikunci.

## Langkah onboarding, urut seperti tabel GDD idle 13.
const STEPS: Array[String] = ["onb_welcome", "onb_first_sale", "onb_first_upgrade", "onb_tap_boost", "onb_hire",
	"onb_recipe", "onb_offline", "onb_location", "onb_franchise"]

## Prompt aktif: {key, target} atau {}.
var prompt: Dictionary = {}
var done: Dictionary = {}
var skipped: bool = false
var _queue: Array[Dictionary] = []


func new_game() -> void:
	prompt = {}
	done.clear()
	skipped = false
	_queue.clear()


func skip() -> void:
	skipped = true
	prompt = {}
	_queue.clear()
	EventBus.tutorial_step_changed.emit(&"")


func hints_enabled() -> bool:
	return not skipped and SettingsManager.get_bool("tutorial_hints")


func has_done(key: String) -> bool:
	return done.has(key)


## Tampilkan langkah `key` sekali. `target` = sasaran sorotan HUD/dunia.
func show_step(key: String, target: StringName = &"") -> void:
	if done.has(key) or skipped:
		return
	done[key] = true
	if not hints_enabled():
		return
	var p: Dictionary = {"key": key, "target": String(target)}
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
