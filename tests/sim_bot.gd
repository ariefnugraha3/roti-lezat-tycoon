class_name SimBot
extends RefCounted
## Pemain otomatis untuk test integrasi, soak, dan probe (GDD idle 17 P7). Toko
## idle berjalan sendiri, jadi bot hanya melakukan yang dilakukan pemain lewat
## UI: menutup tip onboarding, merekrut staf, dan (dengan `manage`) membeli
## upgrade "best value". Ia tidak pernah memutasi state gameplay secara langsung.

var sim: SimulationRoot
## true = merekrut staf dan membeli upgrade bila kas cukup.
var manage: bool = false
## true = menutup tip onboarding seperti pemain ("Got it").
var dismiss_tips: bool = true
var decisions: int = 0
## Bot berpikir tiap `think_interval` tick, seperti pemain yang mengetuk
## beberapa kali per detik, bukan 20 kali.
var think_interval: int = 10
var _cooldown: int = 0


func _init(s: SimulationRoot) -> void:
	sim = s


func think() -> void:
	if dismiss_tips and not sim.tutorial.prompt.is_empty():
		sim.tutorial.dismiss()
	_cooldown -= 1
	if _cooldown > 0:
		return
	_cooldown = think_interval
	if not manage:
		return
	decisions += 1
	_manage()


## Satu langkah pengelolaan: rekrut staf yang terjangkau.
func _manage() -> void:
	for role: StringName in [&"baker", &"cashier"]:
		if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
			continue
		for def: StaffDefinition in DataRegistry.staff_list():
			if def.role_id == role and sim.staff.hire_block(def.id) == &"":
				sim.staff.hire(def.id)
				return


## Majukan simulasi `seconds` detik-simulasi sambil berpikir tiap tick.
func play_for(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		think()
		sim.step(sim.tick_seconds)
		t += sim.tick_seconds


## Majukan sampai hari in-game berikutnya dimulai.
func play_day() -> void:
	var day: int = sim.time.day
	while sim.time.day == day:
		think()
		sim.step(sim.tick_seconds)
