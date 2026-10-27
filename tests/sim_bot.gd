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
## Pemain biasa menabung untuk lokasi berikutnya bila lokasi itu pembelian
## bernilai terbaik dan biayanya paling banyak sekian menit penghasilan (KR/s
## model tanpa boost).
var save_location_minutes: float = 30.0
## ...dan menunggu pembelian bernilai terbaik bila biayanya paling banyak
## sekian menit penghasilan; selain itu ia membeli yang terbaik yang terjangkau.
var wait_best_minutes: float = 3.0
## Probe: bot tidak pindah melewati tier ini.
var max_tier: int = 5


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


## Satu langkah pengelolaan, seperti pemain biasa lewat tab Shop, Staff, Menu,
## dan Upgrades: pindah lokasi begitu terjangkau, merekrut dan membuka stasiun
## begitu terjangkau, lalu membeli yang bernilai terbaik (Δ KR/s ÷ biaya) di
## antara upgrade, membuka resep, dan "mengejar resep" (menaikkan mixer dan oven
## terbaik sampai tier model yang diminta resep yang lebih untung, seperti
## pemain yang membaca syarat resep di layar Menu). Ia menabung untuk lokasi
## berikutnya yang sudah dekat dan untuk pembelian terbaik yang sebentar lagi
## terjangkau. Paling banyak satu pembelian per langkah.
func _manage() -> void:
	var may_move: bool = sim.world.location.tier < max_tier
	if may_move and sim.upgrade_block_reason() == "" and sim.upgrade_location() == "":
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
	if sim.time.sim_seconds < _next_upgrade_at:
		return
	_next_upgrade_at = sim.time.sim_seconds + upgrade_every_seconds
	var per_minute: float = sim.idle_economy.rate(false) * 60.0
	var cands: Array[Dictionary] = []
	# Lokasi berikutnya: kenaikan perkiraan = KR/s × (kedatangan dasar berikutnya
	# ÷ sekarang − 1).
	var nxt: LocationDefinition = sim.next_location()
	if may_move and nxt != null:
		var arr: Array = DataRegistry.idle("location.base_arrivals_per_hour")
		var gain: float = float(arr[nxt.tier - 1]) / float(arr[sim.world.location.tier - 1]) - 1.0
		var lc: float = SimulationRoot.location_cost(nxt.tier)
		if lc <= per_minute * save_location_minutes:
			cands.append({"value": sim.idle_economy.rate(false) * gain / maxf(lc, 0.000001), "cost": lc, "location": true})
	for item: Dictionary in sim.idle_economy.ranked_offers():
		if float(item["delta"]) > 0.0:
			cands.append({"value": float(item["value"]), "cost": float(item["cost"]), "offer": item["offer"]})
	for r: RecipeDefinition in DataRegistry.recipes():
		var block: StringName = sim.upgrades.unlock_block(r.id)
		if block != &"" and block != &"kr":
			continue
		var cost: float = UpgradeManager.unlock_cost(r)
		var d: float = sim.idle_economy.delta_unlock(r.id)
		if d > 0.0:
			cands.append({"value": d / maxf(cost, 0.000001), "cost": cost, "recipe": r.id})
	cands.append_array(_recipe_goals())
	if cands.is_empty():
		return
	cands.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a["value"]) > float(b["value"]))
	var top: Dictionary = cands[0]
	if top.has("location"):
		return
	if not sim.economy.can_afford(float(top["cost"])) and float(top["cost"]) <= per_minute * wait_best_minutes:
		return
	for c: Dictionary in cands:
		if c.has("location"):
			continue
		if sim.economy.can_afford(float(c["cost"])):
			if c.has("recipe"):
				sim.upgrades.unlock_recipe(StringName(str(c["recipe"])))
			else:
				sim.upgrades.buy_offer(c["offer"], 1)
			return


## Kandidat "kejar resep": untuk resep terkunci yang laba per rotinya di Lv 1
## lebih besar dari resep Auto sekarang, tetapi alatnya belum cukup: biaya total
## = level mixer dan oven terbaik sampai ambang tier modelnya + biaya buka;
## nilainya perkiraan kenaikan KR/s ÷ biaya total. Langkah berikutnya adalah satu
## level stasiun yang paling murah dari paket itu.
func _recipe_goals() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var auto: StringName = sim.auto_recipe()
	var cur_net: float = sim.net_per_unit(auto) if auto != &"" else 0.0
	var cap: int = sim.upgrades.level_cap()
	var thresholds: Array = DataRegistry.idle("station.model_tier_thresholds")
	var rate: float = sim.idle_economy.rate(false)
	for r: RecipeDefinition in DataRegistry.recipes():
		if sim.upgrades.is_unlocked(r.id) or sim.production.owns_equipment_for(r):
			continue
		var need_tier: int = maxi(r.required_mixer_tier, r.required_oven_tier)
		var need_level: int = 1 if need_tier <= 1 else int(thresholds[need_tier - 2])
		if need_level > cap:
			continue
		var net_new: float = sim.net_per_unit(r.id)
		if net_new <= cur_net or cur_net <= 0.0:
			continue
		var total: float = UpgradeManager.unlock_cost(r)
		var step: Dictionary = {}
		var step_cost: float = INF
		for cat: StringName in [&"mixer", &"oven"]:
			var best: EquipmentInstance = null
			for e: EquipmentInstance in sim.equipment.placed_list(cat):
				if best == null or sim.upgrades.station_level(e.iid) > sim.upgrades.station_level(best.iid):
					best = e
			if best == null:
				continue
			var lv: int = sim.upgrades.station_level(best.iid)
			if lv >= need_level:
				continue
			var o: Dictionary = sim.upgrades.offer(&"station", best.iid)
			total += UpgradeManager.offer_cost(o, need_level - lv)
			var c1: float = UpgradeManager.offer_cost(o, 1)
			if c1 < step_cost:
				step_cost = c1
				step = o
		if step.is_empty():
			continue
		var delta: float = rate * (net_new / cur_net - 1.0)
		out.append({"value": delta / maxf(total, 0.000001), "cost": step_cost, "offer": step, "goal": r.id})
	return out


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
