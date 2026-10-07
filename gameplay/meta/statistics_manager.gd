class_name StatisticsManager
extends SimManager
## StatisticsManager — statistik seumur hidup & rekor pribadi (GDD 92.2, 92.3,
## 118). Murni observasional; tidak pernah mengubah hasil simulasi.

const STAT_KEYS: Array[String] = [
	"days_played", "total_play_time_real_seconds", "total_kr_earned", "total_kr_spent",
	"highest_balance", "total_bread_produced", "total_bread_sold", "total_bread_wasted",
	"total_bread_burned", "total_customers_served", "total_customers_left_no_purchase",
	"total_customers_lost_patience", "total_rotifood_orders_received",
	"total_rotifood_orders_completed", "total_rotifood_orders_expired", "total_rotifood_orders_rejected",
	"total_supply_orders",
	"bailout_count", "staff_hired_count", "location_upgrades_count",
]
const RECORD_KEYS: Array[String] = [
	"highest_daily_revenue", "highest_daily_profit", "most_bread_sold_day", "most_customers_day",
	"most_rotifood_day", "longest_no_burn", "highest_physical_rating", "highest_rotifood_rating",
	"largest_transaction", "highest_queue",
]

var stats: Dictionary = {}
var records: Dictionary = {}
## location_id -> hari pertama mencapai tier itu.
var tier_reached_day: Dictionary = {}
var no_burn_streak_days: int = 0
var today: Dictionary = {}


func new_game() -> void:
	stats.clear()
	for k: String in STAT_KEYS:
		stats[k] = 0.0
	records.clear()
	for r: String in RECORD_KEYS:
		records[r] = 0.0
	tier_reached_day = {"location_t1_garage": 1}
	no_burn_streak_days = 0
	reset_day()


func reset_day() -> void:
	today = {"bread_sold": 0, "customers_served": 0, "rotifood_completed": 0, "revenue": 0.0, "physical_revenue": 0.0, "rotifood_revenue": 0.0}


func get_stat(key: String) -> float:
	if key == "no_burn_streak_days":
		return float(no_burn_streak_days)
	return float(stats.get(key, 0.0))


func add(key: StringName, amount: float) -> void:
	var k: String = String(key)
	stats[k] = float(stats.get(k, 0.0)) + amount
	if k == "total_bread_sold":
		sim.achievements.check_stat(k)


func note_balance(balance: float) -> void:
	if not is_inf(balance) and balance > float(stats.get("highest_balance", 0.0)):
		stats["highest_balance"] = balance
	sim.achievements.check_balance(balance)
	sim.bailout.note_balance(balance)


func note_purchase() -> void:
	pass


func note_physical_sale(units: int, amount: float) -> void:
	add(&"total_bread_sold", units)
	add(&"total_customers_served", 1)
	today["bread_sold"] = int(today["bread_sold"]) + units
	today["customers_served"] = int(today["customers_served"]) + 1
	today["revenue"] = float(today["revenue"]) + amount
	today["physical_revenue"] = float(today["physical_revenue"]) + amount
	records["largest_transaction"] = maxf(float(records["largest_transaction"]), amount)
	sim.achievements.check_condition(&"big_day")


func note_rotifood_sale(units: int, amount: float) -> void:
	add(&"total_bread_sold", units)
	add(&"total_rotifood_orders_completed", 1)
	today["bread_sold"] = int(today["bread_sold"]) + units
	today["rotifood_completed"] = int(today["rotifood_completed"]) + 1
	today["revenue"] = float(today["revenue"]) + amount
	today["rotifood_revenue"] = float(today["rotifood_revenue"]) + amount
	sim.achievements.check_condition(&"big_day")


func note_queue_occupancy(n: int) -> void:
	records["highest_queue"] = maxf(float(records["highest_queue"]), float(n))


func note_rating(physical: float, rotifood: float) -> void:
	records["highest_physical_rating"] = maxf(float(records["highest_physical_rating"]), physical)
	records["highest_rotifood_rating"] = maxf(float(records["highest_rotifood_rating"]), rotifood)


func note_tier_reached(location_id: StringName, day: int) -> void:
	if not tier_reached_day.has(String(location_id)):
		tier_reached_day[String(location_id)] = day


func add_play_time(real_seconds: float) -> void:
	stats["total_play_time_real_seconds"] = float(stats.get("total_play_time_real_seconds", 0.0)) + real_seconds


## Settlement: rekor harian & streak tanpa gosong.
func end_day(net_profit: float, burnt_batches: int) -> void:
	add(&"days_played", 1)
	stats["total_kr_earned"] = sim.economy.lifetime_earned
	stats["total_kr_spent"] = sim.economy.lifetime_spent
	records["highest_daily_revenue"] = maxf(float(records["highest_daily_revenue"]), float(today["revenue"]))
	records["highest_daily_profit"] = maxf(float(records["highest_daily_profit"]), net_profit)
	records["most_bread_sold_day"] = maxf(float(records["most_bread_sold_day"]), float(today["bread_sold"]))
	records["most_customers_day"] = maxf(float(records["most_customers_day"]), float(today["customers_served"]))
	records["most_rotifood_day"] = maxf(float(records["most_rotifood_day"]), float(today["rotifood_completed"]))
	if burnt_batches == 0:
		no_burn_streak_days += 1
	else:
		no_burn_streak_days = 0
	records["longest_no_burn"] = maxf(float(records["longest_no_burn"]), float(no_burn_streak_days))


func capture() -> Dictionary:
	return {"stats": stats.duplicate(), "records": records.duplicate(), "tier_reached_day": tier_reached_day.duplicate(),
		"no_burn_streak_days": no_burn_streak_days, "today": today.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	var s: Dictionary = d.get("stats", {})
	for k: Variant in s.keys():
		stats[str(k)] = float(s[k])
	var r: Dictionary = d.get("records", {})
	for k2: Variant in r.keys():
		records[str(k2)] = float(r[k2])
	tier_reached_day = d.get("tier_reached_day", tier_reached_day)
	no_burn_streak_days = int(d.get("no_burn_streak_days", 0))
	var t: Dictionary = d.get("today", {})
	for k3: Variant in t.keys():
		today[str(k3)] = t[k3]
