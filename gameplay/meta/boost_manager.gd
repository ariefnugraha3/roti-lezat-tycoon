class_name BoostManager
extends SimManager
## Boost & hadiah (GDD idle 11): Kopi Pak Lurah sekali per hari kalender
## perangkat, promosi berbayar, dan boost hadiah pencapaian. Semua timer berjalan
## dalam detik nyata permainan aktif (detik-simulasi ÷
## `clock.sim_seconds_per_real_second`), jadi berhenti saat pause, di latar,
## dan selama offline; sisanya ikut tersimpan (GDD idle 11.1, 9.2).
##
## Boost penghasilan tidak menumpuk: boost baru menyegarkan sisa waktu ke yang
## lebih panjang dan memakai pengali terbesar, jadi pencapaian yang beruntun
## tidak membuat ×2 berjalan berjam-jam. Promosi berjalan satu per satu, dan
## jedanya dihitung sejak promosi dimulai.

## Pengali dan sisa detik nyata boost penghasilan yang aktif.
var income_mult: float = 1.0
var income_left: float = 0.0
## Promosi yang berjalan (&"" = tidak ada) dan sisa detik nyatanya.
var promo_id: StringName = &""
var promo_left: float = 0.0
## Sisa jeda (detik nyata) per promosi.
var cooldowns: Dictionary = {}
## Tanggal perangkat (YYYY-MM-DD) Kopi Pak Lurah terakhir diberikan.
var last_gift_date: String = ""


func new_game() -> void:
	new_run()
	last_gift_date = ""


## Waralaba (GDD idle 10.5): boost aktif dan jeda direset; tanggal kopi tetap,
## jadi kopi hari ini tidak bisa diambil dua kali.
func new_run() -> void:
	income_mult = 1.0
	income_left = 0.0
	promo_id = &""
	promo_left = 0.0
	cooldowns.clear()


func step(dt: float) -> void:
	var r: float = DataRegistry.real_seconds(dt)
	if income_left > 0.0:
		income_left = maxf(0.0, income_left - r)
		if income_left <= 0.0:
			income_mult = 1.0
			sim.idle_economy.invalidate()
	if promo_left > 0.0:
		promo_left = maxf(0.0, promo_left - r)
		if promo_left <= 0.0:
			promo_id = &""
			sim.idle_economy.invalidate()
	if not cooldowns.is_empty():
		for k: Variant in cooldowns.keys():
			var left: float = float(cooldowns[k]) - r
			if left <= 0.0:
				cooldowns.erase(k)
			else:
				cooldowns[k] = left


# ===========================================================================
# PENGALI
# ===========================================================================

func income_now() -> float:
	return income_mult if income_left > 0.0 else 1.0


func arrival_now() -> float:
	return float(promo(promo_id).get("arrival_mult", 1.0)) if promo_left > 0.0 else 1.0


func rotifood_now() -> float:
	return float(promo(promo_id).get("rotifood_mult", 1.0)) if promo_left > 0.0 else 1.0


## Boost penghasilan ×`mult` selama `seconds` detik nyata; selagi satu berjalan,
## sisa waktunya menjadi yang lebih panjang.
func add_income(mult: float, seconds: float) -> void:
	if income_left > 0.0:
		income_mult = maxf(income_mult, mult)
		income_left = maxf(income_left, seconds)
	else:
		income_mult = mult
		income_left = seconds
	sim.idle_economy.invalidate()


## Hadiah pencapaian (GDD idle 11.4).
func grant_achievement_boost() -> void:
	add_income(DataRegistry.idlef("boosts.achievement.mult"), DataRegistry.idlef("boosts.achievement.minutes") * 60.0)


# ===========================================================================
# KOPI PAK LURAH (GDD idle 11.1)
# ===========================================================================

## Tes: tanggal perangkat palsu ("" = tanggal sistem).
static var date_override: String = ""


## Tanggal perangkat hari ini untuk kopi.
static func today() -> String:
	return date_override if date_override != "" else Time.get_date_string_from_system()


func gift_available(date: String) -> bool:
	return date != "" and date != last_gift_date


## Beri kopi hari ini bila belum. true bila diberikan.
func claim_gift(date: String) -> bool:
	if not gift_available(date):
		return false
	last_gift_date = date
	add_income(DataRegistry.idlef("boosts.daily_gift.mult"), DataRegistry.idlef("boosts.daily_gift.minutes") * 60.0)
	return true


# ===========================================================================
# PROMOSI (GDD idle 11.2)
# ===========================================================================

static func promo(id: StringName) -> Dictionary:
	if id == &"":
		return {}
	for p: Variant in DataRegistry.idle("boosts.promo"):
		if StringName(str((p as Dictionary)["id"])) == id:
			return p
	return {}


static func promo_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Variant in DataRegistry.idle("boosts.promo"):
		out.append(StringName(str((p as Dictionary)["id"])))
	return out


## Biaya = KR/s model tanpa boost × menit penghasilan, paling sedikit 1 KR.
func promo_cost(id: StringName) -> float:
	var p: Dictionary = promo(id)
	if p.is_empty():
		return -1.0
	return maxf(1.0, Money.round_half_up(sim.idle_economy.rate(false) * float(p["cost_income_minutes"]) * 60.0))


## &"" bila promosi boleh dimulai; selain itu invalid, running, cooldown, kr.
func promo_block(id: StringName) -> StringName:
	if promo(id).is_empty():
		return &"invalid"
	if promo_left > 0.0:
		return &"running"
	if float(cooldowns.get(String(id), 0.0)) > 0.0:
		return &"cooldown"
	if not sim.economy.can_afford(promo_cost(id)):
		return &"kr"
	return &""


func cooldown_left(id: StringName) -> float:
	return float(cooldowns.get(String(id), 0.0))


func start_promo(id: StringName) -> bool:
	if promo_block(id) != &"":
		return false
	var p: Dictionary = promo(id)
	if not sim.economy.spend(promo_cost(id), &"PROMO", id, {}):
		return false
	promo_id = id
	promo_left = float(p["minutes"]) * 60.0
	cooldowns[String(id)] = float(p["cooldown_minutes"]) * 60.0
	sim.idle_economy.invalidate()
	EventBus.sfx.emit(&"ui_confirm", &"")
	SaveManager.request_autosave("promo")
	return true


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	return {"income_mult": income_mult, "income_left": income_left, "promo_id": String(promo_id), "promo_left": promo_left,
		"cooldowns": cooldowns.duplicate(), "last_gift_date": last_gift_date}


func restore(d: Dictionary) -> void:
	new_game()
	income_left = maxf(0.0, float(d.get("income_left", 0.0)))
	income_mult = maxf(1.0, float(d.get("income_mult", 1.0))) if income_left > 0.0 else 1.0
	promo_id = StringName(str(d.get("promo_id", "")))
	promo_left = maxf(0.0, float(d.get("promo_left", 0.0)))
	if promo(promo_id).is_empty() or promo_left <= 0.0:
		promo_id = &""
		promo_left = 0.0
	for k: Variant in (d.get("cooldowns", {}) as Dictionary).keys():
		if not promo(StringName(str(k))).is_empty() and float(d["cooldowns"][k]) > 0.0:
			cooldowns[str(k)] = float(d["cooldowns"][k])
	last_gift_date = str(d.get("last_gift_date", ""))
