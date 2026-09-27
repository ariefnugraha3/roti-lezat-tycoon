class_name EconomyManager
extends SimManager
## EconomyManager — satu-satunya pemilik saldo KR dan ledger (GDD 24, 73, 98, 99.2).
##
## Setiap perubahan KR lewat `post()`. Pembelian manual tidak boleh membuat
## saldo negatif; tagihan settlement yang melebihi kas di-nol-kan dan sisanya
## dihapus (tidak ada utang, GDD 49.1). Saldo float64; +INF hanya lewat overflow
## guard endless-economy (GDD 73).

const CATEGORIES: Array[StringName] = [
	&"SALE_PHYSICAL", &"SALE_ROTIFOOD", &"TIP_PHYSICAL", &"TIP_ROTIFOOD",
	&"INGREDIENT_PURCHASE", &"INGREDIENT_DELIVERY_COMMIT", &"EQUIPMENT_PURCHASE",
	&"EQUIPMENT_SALE", &"STORE_UPGRADE", &"STAFF_WAGE", &"UTILITY_COST",
	&"MARKETING_COST", &"BAILOUT_GRANT", &"OTHER_ADJUSTMENT",
]
const INCOME: Array[StringName] = [&"SALE_PHYSICAL", &"SALE_ROTIFOOD", &"TIP_PHYSICAL", &"TIP_ROTIFOOD", &"EQUIPMENT_SALE", &"BAILOUT_GRANT"]

var balance: float = 0.0
var overflowed: bool = false
var tx_sequence: int = 0
## Entri terbaru di memori (GDD 129: 2.048); yang lebih lama diringkas.
var ledger: Array[Dictionary] = []
var historical_totals: Dictionary = {}
## Total per kategori hari ini (direset saat hari mulai).
var today: Dictionary = {}
## Metrik non-kas hari ini (GDD 24.4, 19.7.3).
var cogs_consumed_today: float = 0.0
var waste_cost_today: float = 0.0
var written_off_today: float = 0.0
var lifetime_earned: float = 0.0
var lifetime_spent: float = 0.0

var _hot_limit: int = 2048


func setup(s: SimulationRoot) -> void:
	super.setup(s)
	_hot_limit = DataRegistry.bali("economy.ledger_hot_entries")


func new_game() -> void:
	balance = 0.0
	overflowed = false
	tx_sequence = 0
	ledger.clear()
	historical_totals.clear()
	reset_day()
	# Saldo awal dicatat lewat ledger supaya dapat diaudit (GDD 55.1).
	post(DataRegistry.balf("economy.starting_cash_kr"), &"OTHER_ADJUSTMENT", &"opening_balance", {})


func reset_day() -> void:
	today.clear()
	cogs_consumed_today = 0.0
	waste_cost_today = 0.0
	written_off_today = 0.0


func can_afford(amount: float) -> bool:
	return amount <= balance + 0.0001


## Transaksi mentah. amount positif = pemasukan, negatif = pengeluaran.
## Semua nilai di-commit dalam KR utuh (half-up).
func post(amount: float, category: StringName, source_id: StringName, metadata: Dictionary) -> bool:
	if is_nan(amount):
		GameLogger.error("ECONOMY", "rejected NaN transaction %s" % category)
		return false
	if not CATEGORIES.has(category):
		GameLogger.error("ECONOMY", "unknown ledger category %s" % category)
		return false
	var amt: float = Money.round_half_up(amount)
	if overflowed:
		# Setelah overflow, transaksi tidak lagi menambah nilai terbatas (GDD 73).
		return true
	var new_balance: float = balance + amt
	if is_nan(new_balance):
		GameLogger.error("ECONOMY", "transaction would produce NaN; restoring last finite balance")
		return false
	balance = new_balance
	tx_sequence += 1
	var entry: Dictionary = {
		"tx_id": tx_sequence, "day": sim.time.day, "game_time": sim.time.time_seconds,
		"category": String(category), "amount": amt, "source_id": String(source_id), "metadata": metadata,
	}
	ledger.append(entry)
	if ledger.size() > _hot_limit:
		var old: Dictionary = ledger.pop_front()
		var k: String = str(old["category"])
		historical_totals[k] = float(historical_totals.get(k, 0.0)) + float(old["amount"])
	today[category] = float(today.get(category, 0.0)) + amt
	if amt > 0.0 and INCOME.has(category):
		lifetime_earned += amt
	elif amt < 0.0:
		lifetime_spent += -amt
	if is_inf(balance):
		_enter_overflow()
	EventBus.balance_changed.emit(balance)
	sim.statistics.note_balance(balance)
	return true


## Pengeluaran manual: ditolak bila saldo tidak cukup (GDD 24.3).
func spend(amount: float, category: StringName, source_id: StringName, metadata: Dictionary = {}) -> bool:
	var amt: float = Money.round_half_up(amount)
	if amt < 0.0 or not can_afford(amt):
		return false
	return post(-amt, category, source_id, metadata)


func credit(amount: float, category: StringName, source_id: StringName, metadata: Dictionary = {}) -> bool:
	return post(absf(amount), category, source_id, metadata)


## Tagihan settlement (gaji/utilitas). Bila melebihi kas, saldo menjadi 0 dan
## sisanya dihapus serta dicatat di metadata (GDD 49.1 langkah 1).
func charge_settlement(amount: float, category: StringName, source_id: StringName, metadata: Dictionary = {}) -> float:
	var amt: float = Money.round_half_up(maxf(0.0, amount))
	if amt <= 0.0:
		return 0.0
	var payable: float = minf(amt, maxf(0.0, balance))
	var written_off: float = amt - payable
	var meta: Dictionary = metadata.duplicate()
	if written_off > 0.0:
		meta["written_off_kr"] = written_off
		written_off_today += written_off
	post(-payable, category, source_id, meta)
	# Laporan harian tetap menampilkan tagihan penuh.
	today[category] = float(today.get(category, 0.0)) - written_off
	return written_off


func note_cogs(value: float) -> void:
	cogs_consumed_today += value


func note_waste(value: float) -> void:
	waste_cost_today += value


func today_total(category: StringName) -> float:
	return float(today.get(category, 0.0))


func _enter_overflow() -> void:
	if overflowed:
		return
	overflowed = true
	balance = INF
	GameLogger.important("ECONOMY", "economy overflow guard entered")
	EventBus.economy_overflowed.emit()


## Rekonsiliasi: saldo == jumlah semua transaksi (TEST_ECONOMY_001).
func reconcile() -> bool:
	if overflowed:
		return true
	var total: float = 0.0
	for k: Variant in historical_totals.keys():
		total += float(historical_totals[k])
	for e: Dictionary in ledger:
		total += float(e["amount"])
	return absf(total - balance) < 0.5


func capture() -> Dictionary:
	var recent: Array = []
	var start: int = maxi(0, ledger.size() - 200)
	for i in range(start, ledger.size()):
		recent.append(ledger[i])
	# Entri yang tidak disimpan dilipat ke total historis agar rekonsiliasi tetap utuh.
	var hist: Dictionary = historical_totals.duplicate()
	for i2 in range(0, start):
		var e: Dictionary = ledger[i2]
		var k: String = str(e["category"])
		hist[k] = float(hist.get(k, 0.0)) + float(e["amount"])
	return {
		"balance_kr": SaveManager.encode_money(balance),
		"ledger_sequence": tx_sequence,
		"overflowed": overflowed,
		"ledger_recent": recent,
		"historical_totals": hist,
		"today": sn_dict_to_json(today),
		"cogs_consumed_today": cogs_consumed_today,
		"waste_cost_today": waste_cost_today,
		"written_off_today": written_off_today,
		"lifetime_earned": lifetime_earned,
		"lifetime_spent": lifetime_spent,
	}


func restore(d: Dictionary) -> void:
	balance = SaveManager.decode_money(d.get("balance_kr", 0.0))
	tx_sequence = int(d.get("ledger_sequence", 0))
	overflowed = bool(d.get("overflowed", false)) or is_inf(balance)
	ledger.clear()
	for e: Variant in d.get("ledger_recent", []):
		ledger.append(e as Dictionary)
	historical_totals = d.get("historical_totals", {})
	today = json_to_sn_dict(d.get("today", {}))
	cogs_consumed_today = float(d.get("cogs_consumed_today", 0.0))
	waste_cost_today = float(d.get("waste_cost_today", 0.0))
	written_off_today = float(d.get("written_off_today", 0.0))
	lifetime_earned = float(d.get("lifetime_earned", 0.0))
	lifetime_spent = float(d.get("lifetime_spent", 0.0))
