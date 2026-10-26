class_name StatisticsManager
extends SimManager
## StatisticsManager — statistik & rekor (GDD idle 7.4, 9.2, 12.3 Stats; v3.1
## 92.2, 92.3, 118). Murni observasional; tidak pernah mengubah hasil simulasi.
##
## `run_earned_kr` hanya menghitung pemasukan putaran ini dan direset saat
## Waralaba; `alltime_earned_kr` dan statistik lain bertahan lintas putaran
## (GDD idle 10.5).

const STAT_KEYS: Array[String] = [
	"run_earned_kr", "alltime_earned_kr", "alltime_spent_kr", "highest_balance",
	"total_bread_produced", "total_bread_sold", "total_customers_entered", "total_customers_served",
	"total_customers_left_no_purchase", "total_customers_lost_patience", "total_customers_missed",
	"total_rotifood_orders_received", "total_rotifood_orders_completed", "total_rotifood_orders_expired",
	"staff_hired_count", "location_upgrades_count", "total_play_time_real_seconds",
	"offline_seconds_total", "offline_earned_kr", "days_passed", "franchise_count",
]
const RECORD_KEYS: Array[String] = [
	"largest_transaction", "highest_reputation", "highest_rate_kr_per_s", "highest_queue",
]

var stats: Dictionary = {}
var records: Dictionary = {}
## location_id -> hari pertama mencapai tier itu (putaran ini).
var tier_reached_day: Dictionary = {}


func new_game() -> void:
	stats.clear()
	for k: String in STAT_KEYS:
		stats[k] = 0.0
	records.clear()
	for r: String in RECORD_KEYS:
		records[r] = 0.0
	tier_reached_day = {"location_t1_garage": 1}


## Putaran baru (Waralaba, GDD idle 10.5): hanya penghasilan putaran dan hari
## pencapaian tier yang direset.
func begin_run(start_location: StringName) -> void:
	stats["run_earned_kr"] = 0.0
	tier_reached_day = {String(start_location): sim.time.day}


func get_stat(key: String) -> float:
	return float(stats.get(key, 0.0))


func add(key: StringName, amount: float) -> void:
	var k: String = String(key)
	stats[k] = float(stats.get(k, 0.0)) + amount
	if DataRegistry.ACHIEVEMENT_STATS.has(k):
		sim.achievements.check_stat(k)


func note_income(amount: float) -> void:
	stats["run_earned_kr"] = float(stats.get("run_earned_kr", 0.0)) + amount
	stats["alltime_earned_kr"] = float(stats.get("alltime_earned_kr", 0.0)) + amount
	sim.achievements.check_stat("alltime_earned_kr")


func note_spending(amount: float) -> void:
	stats["alltime_spent_kr"] = float(stats.get("alltime_spent_kr", 0.0)) + amount


func note_balance(balance: float) -> void:
	if not is_inf(balance) and balance > float(stats.get("highest_balance", 0.0)):
		stats["highest_balance"] = balance
	sim.achievements.check_balance(balance)


func note_physical_sale(units: int, amount: float) -> void:
	add(&"total_bread_sold", units)
	add(&"total_customers_served", 1)
	records["largest_transaction"] = maxf(float(records["largest_transaction"]), amount)


func note_rotifood_sale(units: int, amount: float) -> void:
	add(&"total_bread_sold", units)
	add(&"total_rotifood_orders_completed", 1)
	records["largest_transaction"] = maxf(float(records["largest_transaction"]), amount)


func note_queue_occupancy(n: int) -> void:
	records["highest_queue"] = maxf(float(records["highest_queue"]), float(n))


func note_reputation(rep: float) -> void:
	records["highest_reputation"] = maxf(float(records["highest_reputation"]), rep)


func note_rate(rate: float) -> void:
	if not is_inf(rate) and not is_nan(rate):
		records["highest_rate_kr_per_s"] = maxf(float(records["highest_rate_kr_per_s"]), rate)


func note_tier_reached(location_id: StringName, day: int) -> void:
	if not tier_reached_day.has(String(location_id)):
		tier_reached_day[String(location_id)] = day


func note_offline(seconds: float, earned: float) -> void:
	stats["offline_seconds_total"] = float(stats.get("offline_seconds_total", 0.0)) + seconds
	stats["offline_earned_kr"] = float(stats.get("offline_earned_kr", 0.0)) + earned
	sim.achievements.check_stat("offline_seconds_total")


func add_play_time(real_seconds: float) -> void:
	stats["total_play_time_real_seconds"] = float(stats.get("total_play_time_real_seconds", 0.0)) + real_seconds


func on_new_day() -> void:
	add(&"days_passed", 1)


func capture() -> Dictionary:
	return {"stats": stats.duplicate(), "records": records.duplicate(), "tier_reached_day": tier_reached_day.duplicate()}


func restore(d: Dictionary) -> void:
	new_game()
	var s: Dictionary = d.get("stats", {})
	for k: Variant in s.keys():
		stats[str(k)] = float(s[k])
	var r: Dictionary = d.get("records", {})
	for k2: Variant in r.keys():
		records[str(k2)] = float(r[k2])
	tier_reached_day = d.get("tier_reached_day", tier_reached_day)
