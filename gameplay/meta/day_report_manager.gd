class_name DayReportManager
extends SimManager
## DayReportManager — DayReportSnapshot immutable pukul 18:00 (GDD 11, 46).
## Membuka ulang Daily Summary tidak pernah menghitung ulang gaji atau rating.

var last_report: Dictionary = {}
var history: Array = []


func new_game() -> void:
	last_report = {}
	history.clear()


func build(settlement: Dictionary) -> Dictionary:
	var econ: EconomyManager = sim.economy
	var physical: float = econ.today_total(&"SALE_PHYSICAL")
	var rotifood: float = econ.today_total(&"SALE_ROTIFOOD")
	var tips: float = econ.today_total(&"TIP_PHYSICAL") + econ.today_total(&"TIP_ROTIFOOD")
	var cogs: float = Money.round_half_up(econ.cogs_consumed_today)
	var utility: float = float(settlement.get("utility", 0.0))
	var wages: float = float(settlement.get("wages", 0.0))
	var marketing: float = -econ.today_total(&"MARKETING_COST")
	var income: float = physical + rotifood + tips
	var expenses: float = cogs + utility + wages + marketing
	var net: float = income - expenses
	var top: Dictionary = sim.analytics.top_recipe_today()
	var report: Dictionary = {
		"day_number": sim.time.day,
		"weekday": sim.time.weekday(),
		"weather": String(sim.weather.today),
		"holiday": sim.weather.holiday_today(),
		"physical_sales": physical,
		"rotifood_sales": rotifood,
		"tips": tips,
		"total_income": income,
		"cogs_consumed": cogs,
		"utility_cost": utility,
		"wages": wages,
		"wage_lines": sim.staff.wage_lines_today.duplicate(true),
		"marketing_cost_if_charged_today": marketing,
		"waste_cost": Money.round_half_up(econ.waste_cost_today),
		"total_expenses": expenses,
		"net_profit": net,
		"ending_balance": SaveManager.encode_money(econ.balance),
		"written_off": econ.written_off_today,
		"physical_customer_count": sim.customers.served_today,
		"customers_entered": sim.customers.entered_today,
		"delivery_completed": sim.rotifood.completed_today,
		"delivery_cancelled": sim.rotifood.cancelled_today,
		"bread_sold": int(sim.statistics.today.get("bread_sold", 0)),
		"bread_leftover": sim.display.total_sellable(),
		"rating_start": sim.reputation.day_start_physical,
		"rating_end": sim.reputation.physical,
		"rotifood_rating_start": sim.reputation.day_start_rotifood,
		"rotifood_rating_end": sim.reputation.rotifood,
		"top_recipe": top["recipe"],
		"top_recipe_count": top["count"],
		"burnt_batches": sim.production.batches_burnt_today,
		"bailout_pending": sim.bailout.bailout_pending,
		"wage_warning": sim.bailout.wage_warning,
		"campaign": sim.marketing.active.duplicate(),
		"weather_tomorrow": String(sim.weather.tomorrow),
	}
	report["mood"] = _mood(report)
	report["highlights"] = _highlights(report)
	report["tip_from_pak_lurah"] = _tip(report)
	last_report = report
	history.append({"day": report["day_number"], "income": income, "expenses": expenses, "net": net})
	while history.size() > DataRegistry.bali("limits.analytics_detailed_days"):
		history.pop_front()
	return report


func _mood(r: Dictionary) -> String:
	var s: Dictionary = DataRegistry.balance_section("summary")
	var net: float = float(r["net_profit"])
	if bool(r["bailout_pending"]):
		return "mood_bailout"
	if net > float(s["great_profit_kr"]) and float(r["rating_end"]) > float(r["rating_start"]):
		return "mood_great"
	if net > float(s["small_profit_kr"]):
		return "mood_good"
	if net >= 0.0:
		return "mood_even"
	return "mood_rough"


func _highlights(r: Dictionary) -> Array:
	var s: Dictionary = DataRegistry.balance_section("summary")
	var out: Array = []
	if sim.bailout.solo_mode and sim.bailout.solo_start_day == sim.time.day:
		out.append({"key": "hl_solo_day", "params": {}, "icon": "chef"})
	if sim.reputation.vip_today:
		out.append({"key": "hl_vip_visit", "params": {}, "icon": "star"})
	if bool(r["holiday"]):
		out.append({"key": "hl_holiday", "params": {}, "icon": "party"})
	if sim.weather.is_rain() and int(r["delivery_completed"]) > 0:
		out.append({"key": "hl_rain_surge", "params": {"percent": int(Money.round_half_up((sim.weather.delivery_multiplier() - 1.0) * 100.0))}, "icon": "rain"})
	if str(r["top_recipe"]) != "":
		out.append({"key": "hl_top_recipe", "params": {"recipe": Tx.recipe_name(StringName(str(r["top_recipe"]))), "count": r["top_recipe_count"]}, "icon": "trophy"})
	if int(r["delivery_cancelled"]) > 0:
		out.append({"key": "hl_orders_cancelled", "params": {"count": r["delivery_cancelled"]}, "icon": "warning"})
	if int(r["burnt_batches"]) > 0:
		out.append({"key": "hl_burnt_batches", "params": {"count": r["burnt_batches"]}, "icon": "fire"})
	for sid: StringName in sim.staff.employed_ids(&"baker"):
		var c: Dictionary = sim.staff.contract(sid)
		if int(c.get("batches_today", 0)) >= int(s["staff_star_min_batches"]):
			var def: StaffDefinition = DataRegistry.staff(sid)
			out.append({"key": "hl_staff_star", "params": {"name": def.display_name, "multiplier": "%.2f" % def.work_speed_multiplier}, "icon": "chef"})
			break
	if _low_ingredients(int(s["low_ingredient_batches"])):
		out.append({"key": "hl_low_ingredients", "params": {}, "icon": "box"})
	var camp: Dictionary = sim.marketing.active
	if not camp.is_empty() and sim.marketing.effective_today():
		out.append({"key": "hl_campaign_running", "params": {"campaign": Tx.t(str(camp["campaign_id"])), "day": sim.marketing.day_number()}, "icon": "megaphone"})
	return out.slice(0, 3)


func _low_ingredients(min_batches: int) -> bool:
	for rr: RecipeDefinition in sim.bailout.producible_recipes():
		if sim.inventory.batches_available(rr) >= min_batches:
			return false
	return true


func _tip(r: Dictionary) -> String:
	var s: Dictionary = DataRegistry.balance_section("summary")
	if sim.time.day == 1:
		return "tip_first_day"
	if sim.bailout.solo_mode:
		return "tip_solo_mode"
	if sim.economy.balance < float(s["low_cash_tip_kr"]):
		return "tip_low_cash"
	if int(r["delivery_cancelled"]) >= int(s["cancelled_orders_tip"]):
		return "tip_cancelled_orders"
	var produced: int = int(r["bread_sold"]) + int(r["bread_leftover"])
	if produced > 0 and float(r["bread_leftover"]) / float(produced) > float(s["leftover_tip_ratio"]):
		return "tip_leftover"
	if float(r["rating_end"]) < float(r["rating_start"]):
		return "tip_rating_drop"
	if StringName(str(r["weather_tomorrow"])) == &"weather_rain":
		return "tip_rain_tomorrow"
	if WeatherManager.is_holiday(sim.time.day + 1) and not WeatherManager.is_holiday(sim.time.day):
		return "tip_holiday_soon"
	if float(r["net_profit"]) > float(s["high_profit_tip_kr"]):
		return "tip_high_profit"
	return "tip_default"


## Tombol Continue to Next Day (GDD 11.5).
func can_continue() -> bool:
	if sim.time.day <= 2 or sim.bailout.bailout_pending:
		return true
	return not sim.inventory.is_empty()


func capture() -> Dictionary:
	return {"last_report": last_report.duplicate(true), "history": history.duplicate(true)}


func restore(d: Dictionary) -> void:
	last_report = (d.get("last_report", {}) as Dictionary).duplicate(true)
	history = (d.get("history", []) as Array).duplicate(true)
