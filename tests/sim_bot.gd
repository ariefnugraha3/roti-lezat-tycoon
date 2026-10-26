class_name SimBot
extends RefCounted
## Pemain otomatis untuk test integrasi, soak, dan probe (GDD idle 17 P7). Toko
## idle berjalan sendiri, jadi bot hanya melakukan yang dilakukan pemain lewat
## UI: menutup tip onboarding dan (dengan `manage`) pindah lokasi, merekrut
## staf, membuka stasiun, membuka resep yang lebih untung, dan membeli upgrade
## "best value". Ia tidak pernah memutasi state gameplay secara langsung.

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
## Upgrade "best value" dipertimbangkan paling sering tiap sekian detik-simulasi
## (urutan model mahal dihitung).
var upgrade_every_seconds: float = 5.0
var _next_upgrade_at: float = 0.0


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


## Satu langkah pengelolaan, seperti pemain lewat tab Shop, Staff, Menu, dan
## Upgrades: paling banyak satu pembelian per langkah.
func _manage() -> void:
	if sim.upgrade_block_reason() == "" and sim.upgrade_location() == "":
		return
	for role: StringName in [&"baker", &"cashier"]:
		if sim.staff.employed_ids(role).size() >= sim.staff.capacity(role):
			continue
		for def: StaffDefinition in DataRegistry.staff_list():
			if def.role_id == role and sim.staff.hire_block(def.id) == &"":
				sim.staff.hire(def.id)
				return
	for cat: StringName in [&"display", &"mixer", &"oven"]:
		if sim.upgrades.open_station_block(cat) == &"":
			sim.upgrades.open_station(cat)
			return
	var best: StringName = sim.auto_recipe()
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.upgrades.unlock_block(r.id) == &"" and (best == &"" or sim.net_per_unit(r.id) > sim.net_per_unit(best)):
			sim.upgrades.unlock_recipe(r.id)
			return
	if sim.time.sim_seconds < _next_upgrade_at:
		return
	_next_upgrade_at = sim.time.sim_seconds + upgrade_every_seconds
	for item: Dictionary in sim.idle_economy.ranked_offers():
		if float(item["delta"]) <= 0.0:
			break
		var o: Dictionary = item["offer"]
		if sim.upgrades.offer_count(o, &"x1") > 0:
			sim.upgrades.buy_offer(o, 1)
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
