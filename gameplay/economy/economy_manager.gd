class_name EconomyManager
extends SimManager
## EconomyManager — satu-satunya pemilik saldo KR dan ledger (GDD idle 7;
## v3.1 24.1, 73, 98, 99.2).
##
## Setiap perubahan KR lewat `post()`. Pembelian tidak boleh membuat saldo
## negatif; satu-satunya pengeluaran otomatis adalah biaya bahan batch, dan
## batch tidak dimulai bila KR kurang (GDD idle 4.4, 7.3). Pemasukan dicatat ke
## `run_earned_kr` dan `alltime_earned_kr` (StatisticsManager). Saldo float64;
## +INF hanya lewat penjaga overflow (v3.1 73).

const CATEGORIES: Array[StringName] = [
	&"SALE_PHYSICAL", &"SALE_ROTIFOOD", &"OFFLINE_EARNINGS", &"GIFT", &"INGREDIENT_COST",
	&"UPGRADE_STATION", &"UPGRADE_RECIPE", &"RECIPE_UNLOCK", &"STATION_OPEN", &"STAFF_HIRE",
	&"STAFF_UPGRADE", &"LOCATION_UPGRADE", &"DECOR_PURCHASE", &"PROMO", &"GLOBAL_UPGRADE",
	&"FRANCHISE_RESET", &"OTHER_ADJUSTMENT",
]
## Pemasukan yang dihitung sebagai penghasilan (GDD idle 7.4).
const INCOME: Array[StringName] = [&"SALE_PHYSICAL", &"SALE_ROTIFOOD", &"OFFLINE_EARNINGS", &"GIFT"]

var balance: float = 0.0
var overflowed: bool = false
var tx_sequence: int = 0
## Entri terbaru di memori (v3.1 129: 2.048); yang lebih lama diringkas.
var ledger: Array[Dictionary] = []
var historical_totals: Dictionary = {}

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


## Saldo awal putaran (GDD idle 7.1): dicatat lewat ledger supaya dapat diaudit,
## bukan sebagai penghasilan.
func open_run(amount: float) -> void:
	if amount > 0.0:
		post(amount, &"OTHER_ADJUSTMENT", &"opening_balance", {})


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
		# Setelah overflow, transaksi tidak lagi menambah nilai terbatas (v3.1 73).
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
	if amt > 0.0 and INCOME.has(category):
		sim.statistics.note_income(amt)
	elif amt < 0.0:
		sim.statistics.note_spending(-amt)
	if is_inf(balance):
		_enter_overflow()
	EventBus.balance_changed.emit(balance)
	sim.statistics.note_balance(balance)
	return true


## Pengeluaran: ditolak bila saldo tidak cukup (v3.1 24.3).
func spend(amount: float, category: StringName, source_id: StringName, metadata: Dictionary = {}) -> bool:
	var amt: float = Money.round_half_up(amount)
	if amt < 0.0 or not can_afford(amt):
		return false
	if amt == 0.0:
		return true
	return post(-amt, category, source_id, metadata)


func credit(amount: float, category: StringName, source_id: StringName, metadata: Dictionary = {}) -> bool:
	return post(absf(amount), category, source_id, metadata)


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
	return absf(total - balance) <= maxf(0.5, absf(balance) * 1.0e-9)


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
	}


func restore(d: Dictionary) -> void:
	balance = SaveManager.decode_money(d.get("balance_kr", 0.0))
	tx_sequence = int(d.get("ledger_sequence", 0))
	overflowed = bool(d.get("overflowed", false)) or is_inf(balance)
	ledger.clear()
	for e: Variant in d.get("ledger_recent", []):
		ledger.append(e as Dictionary)
	historical_totals = d.get("historical_totals", {})
