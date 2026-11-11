class_name StoreScreen
extends UISheet
## Store (GDD idle 22.5-22.9): satu lembar bawah dengan lima tab.
##   Offers  penawaran berbatas waktu, Baker's Club, Golden Oven, Night
##           Manager, No Ads, dan Restore purchases.
##   Pass    Bakery Pass musim ini: XP, tingkat, hadiah gratis dan premium.
##   Crumbs  Golden Crumbs gratis lewat iklan dan paket Golden Crumbs.
##   Boosts  boost ×2 (iklan atau crumbs) dan time warp.
##   Style   kosmetik premium dengan Golden Crumbs.
## Harga uang sungguhan selalu tertulis di tombolnya. Di toko uji (GDD idle
## 22.2) catatan di bawah daftar menjelaskan bahwa tidak ada uang yang ditarik.
## Halaman dibangun ulang hanya bila keadaannya berubah (`_state_key`); sisa
## waktu dan tombol iklan diperbarui di tempat.

const TAB_KEYS: Array[String] = ["ui_store_tab_offers", "ui_store_tab_pass", "ui_store_tab_crumbs", "ui_store_tab_boosts", "ui_store_tab_style"]
const TAB_OFFERS: int = 0
const TAB_PASS: int = 1
const TAB_CRUMBS: int = 2
const TAB_BOOSTS: int = 3
const TAB_STYLE: int = 4

var _tab: int = -1
var _crumb_label: Label = null
## Label waktu yang diperbarui setiap tick: [{label, fn}].
var _timers: Array[Dictionary] = []
var _ad_buttons: Array[Button] = []
var _crumb_buttons: Array[Dictionary] = []
var _shown_key: String = ""
var _keep_scroll: int = 0
var _scroll: ScrollContainer = null


func sheet_title() -> String:
	return Tx.t("ui_store_title")


func sheet_icon() -> String:
	return "gift"


func build_page(body: VBoxContainer) -> void:
	if _tab < 0:
		_tab = clampi(int(params.get("tab", TAB_OFFERS)), 0, TAB_KEYS.size() - 1)
	_timers.clear()
	_ad_buttons.clear()
	_crumb_buttons.clear()
	var top: HBoxContainer = hbox(body, 8)
	top.name = "Balance"
	top.add_child(ProceduralUIFactory.icon("crumb", 30, Palette.GOLD_STAR))
	_crumb_label = lbl(top, "", 18, Palette.UI_WOOD_DEEP)
	_crumb_label.name = "Crumbs"
	_crumb_label.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var labels: Array = []
	for k: String in TAB_KEYS:
		labels.append(Tx.t(k))
	var tabs: ProceduralUIFactory.CozyTabs = ProceduralUIFactory.tab_bar(labels, _tab, func(i: int) -> void:
		_tab = i
		refresh()
		_keep_scroll = 0)
	tabs.name = "Tabs"
	body.add_child(tabs)
	var list: VBoxContainer = scroll_box(body)
	list.name = "StoreList"
	_scroll = list.get_parent() as ScrollContainer
	match _tab:
		TAB_OFFERS:
			_offers(list)
		TAB_PASS:
			_pass(list)
		TAB_CRUMBS:
			_crumbs(list)
		TAB_BOOSTS:
			_boosts(list)
		TAB_STYLE:
			_style(list)
	if Monetization.provider != null and Monetization.provider.id() == &"dummy" and _tab != TAB_STYLE:
		var note: Label = lbl(list, Tx.t("ui_store_test_note"), 13, Palette.TEXT_MUTED, true)
		note.name = "TestNote"
		note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_shown_key = _state_key()
	tick_page()
	_restore_scroll.call_deferred(_keep_scroll)


## Buka tab `i` (tes dan tombol HUD).
func show_tab(i: int) -> void:
	_tab = clampi(i, 0, TAB_KEYS.size() - 1)
	_keep_scroll = 0
	refresh()


func current_tab() -> int:
	return _tab


## Bangun ulang tanpa melompat ke atas daftar.
func refresh() -> void:
	if _scroll != null and is_instance_valid(_scroll):
		_keep_scroll = _scroll.scroll_vertical
	super.refresh()


func _restore_scroll(v: int) -> void:
	if v <= 0 or not is_inside_tree():
		return
	await get_tree().process_frame
	if _scroll != null and is_instance_valid(_scroll):
		_scroll.scroll_vertical = v


## Keadaan yang mengubah isi halaman (bukan sekadar angka).
func _state_key() -> String:
	var p: PremiumManager = sim.premium
	return "|".join(PackedStringArray([str(_tab), str(Monetization.owned), str(Monetization.live_offers()), str(Monetization.club_active()),
		str(p.crumbs), str(p.pass_tier()), str(p.pass_premium), str(p.pass_claimed_free.size()), str(p.pass_claimed_premium.size()),
		str(sim.decoration.owned.size()), str(sim.decoration.equipped), str(p.can_add_boost()), str(Monetization.store_available())]))


func tick_page() -> void:
	if sim == null or _crumb_label == null or not is_instance_valid(_crumb_label) or page_depth() > 0:
		return
	if _state_key() != _shown_key:
		refresh()
		return
	_crumb_label.text = Tx.t("ui_store_balance", {"n": Tx.big(float(sim.premium.crumbs))})
	for t: Dictionary in _timers:
		var l: Label = t["label"]
		if is_instance_valid(l):
			l.text = (t["fn"] as Callable).call()
	for b: Button in _ad_buttons:
		AdButton.refresh(b)
	for cb: Dictionary in _crumb_buttons:
		var b2: Button = cb["button"]
		if is_instance_valid(b2):
			b2.disabled = not sim.premium.can_spend(int(cb["cost"])) or not bool((cb["ok"] as Callable).call())


# ===========================================================================
# TOMBOL
# ===========================================================================

## Tombol beli dengan harga toko (uang sungguhan).
func _price_button(id: StringName, text_key: String = "ui_store_buy_price", kind: String = "primary") -> Button:
	var price: String = Monetization.price(id)
	var text: String = Tx.t(text_key, {"price": price}) if price != "" else Tx.t("ui_store_buy")
	var b: Button = ProceduralUIFactory.button(text, kind)
	b.name = "Buy"
	b.custom_minimum_size = Vector2(maxf(120.0, ProceduralUIFactory._text_width(text, 16, true) + 40.0), 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.disabled = not Monetization.store_available() or not Monetization.can_buy(id)
	b.pressed.connect(_buy.bind(id, b))
	return b


func _buy(id: StringName, b: Button) -> void:
	_mark_origin(b)
	b.disabled = true
	Monetization.buy(id, func(ok: bool) -> void:
		if not is_inside_tree():
			return
		if is_instance_valid(b):
			b.disabled = false
		if not ok:
			EventBus.notify.emit(1, "ui_store_failed", {}, &"warning")
		refresh())


## Tombol Golden Crumbs: ikon crumb dan harganya; mati bila crumbs kurang atau
## `ok` bernilai false.
func _crumb_button(cost: int, text: String, cb: Callable, ok: Callable = Callable()) -> Button:
	var label_text: String = Tx.t("ui_store_crumb_price", {"text": text, "n": Tx.big(float(cost))}) if text != "" else Tx.big(float(cost))
	var b: Button = ProceduralUIFactory.icon_text_button("crumb", label_text, "primary", 20, 16)
	b.name = "Crumbs"
	b.custom_minimum_size = Vector2(maxf(120.0, ProceduralUIFactory._text_width(label_text, 16, true) + 64.0), 52)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(cb)
	var okf: Callable = ok if ok.is_valid() else func() -> bool: return true
	_crumb_buttons.append({"button": b, "cost": cost, "ok": okf})
	b.disabled = not sim.premium.can_spend(cost) or not bool(okf.call())
	return b


func _ad_button(placement: StringName, text: String, cb: Callable) -> Button:
	var b: Button = AdButton.make(placement, text, "soft", 18, 15)
	b.custom_minimum_size.y = 52
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.pressed.connect(func() -> void:
		_mark_origin(b)
		Monetization.show_rewarded(placement, func(ok: bool) -> void:
			if ok and sim != null:
				cb.call()
			if is_inside_tree():
				refresh()))
	_ad_buttons.append(b)
	return b


func _owned_pill(key: String = "ui_store_owned") -> PanelContainer:
	var p: PanelContainer = ProceduralUIFactory.pill("check", Tx.t(key), Palette.MATCHA_SOFT, Palette.MATCHA_DEEP, 14)
	p.name = "Owned"
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return p


func _celebrate() -> void:
	EventBus.sfx.emit(&"coin_shower", &"")
	if game != null and game.hud != null and not SettingsManager.reduced_motion():
		game.hud.coin_shower()


# ===========================================================================
# PERAYAAN (GDD idle 22.11)
# ===========================================================================

## Tombol `b` menjadi asal crumbs yang akan terbang ke saldo.
func _mark_origin(b: Control) -> void:
	if game != null and game.hud != null and is_instance_valid(b) and b.is_inside_tree():
		game.hud.purchase_origin = b.get_global_rect().get_center()


## Perayaan barang baru (RewardReveal).
func _reveal(params_v: Dictionary) -> void:
	if game != null and game.modals != null:
		game.modals.open(&"reward_reveal", params_v)


func _fly(amount: int) -> void:
	if game != null and game.hud != null and amount > 0:
		game.hud.fly_crumbs(Vector2(-1.0, -1.0), amount)


func _pulse_boost() -> void:
	if game != null and game.hud != null:
		game.hud.pulse_boost()


## Jalankan `fn` (klaim hadiah Pass) lalu rayakan hasilnya sesuai isinya:
## barang musim dirayakan penuh, Golden Crumbs terbang dari tombolnya, boost
## memantul di HUD, dan time warp menghujani koin.
func _claim_celebrated(b: Control, fn: Callable) -> void:
	var p: PremiumManager = sim.premium
	var c0: int = p.crumbs
	var boost0: float = p.ad_boost_left
	var kr0: float = sim.economy.balance
	var had: Dictionary = {}
	for o: Dictionary in sim.decoration.owned:
		had[str(o["deco_id"])] = true
	_mark_origin(b)
	fn.call()
	var fresh: StringName = &""
	for o2: Dictionary in sim.decoration.owned:
		if not had.has(str(o2["deco_id"])):
			fresh = StringName(str(o2["deco_id"]))
			break
	if fresh != &"":
		_reveal({"deco": fresh})
	if p.crumbs > c0:
		_fly(p.crumbs - c0)
	if p.ad_boost_left > boost0 + 1.0:
		_pulse_boost()
	if sim.economy.balance > kr0 + 0.005:
		_celebrate()
	refresh()


# ===========================================================================
# OFFERS
# ===========================================================================

func _offers(list: VBoxContainer) -> void:
	if not Monetization.store_available():
		var es: VBoxContainer = ProceduralUIFactory.empty_state("gift", Tx.t("ui_store_unavailable"))
		es.name = "Unavailable"
		list.add_child(es)
		return
	var live: Array[StringName] = Monetization.live_offers()
	if not live.is_empty():
		section(list, Tx.t("ui_store_limited"))
		for id: StringName in live:
			_offer_card(list, id)
	section(list, Tx.t("ui_store_specials"))
	_club_card(list)
	for kind: String in ["income", "offline", "no_ads"]:
		_perm_card(list, kind)
	var restore: Button = ProceduralUIFactory.button(Tx.t("ui_store_restore"), "plain")
	restore.name = "Restore"
	restore.custom_minimum_size.y = 52
	restore.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	restore.pressed.connect(func() -> void:
		Monetization.restore_purchases(func(any: bool) -> void:
			EventBus.notify.emit(1, "ui_store_restored" if any else "ui_store_restore_none", {}, &"check" if any else &"warning")
			if is_inside_tree():
				refresh()))
	list.add_child(restore)


## Isi produk sebagai baris teks ("+300 Golden Crumbs", nama pakaian, ...).
static func contents(p: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	if int(p.get("crumbs", 0)) > 0:
		out.append(Tx.t("ui_reward_crumbs", {"n": Tx.big(float(p["crumbs"]))}))
	var item: String = str(p.get("decor", ""))
	if item != "":
		out.append(Tx.item_name(StringName(item)))
	if float(p.get("boost_hours", 0.0)) > 0.0:
		out.append(Tx.t("ui_reward_boost", {"mult": Tx.mult(DataRegistry.idlef("premium.ad_boost.mult")), "hours": Tx.mult(float(p["boost_hours"]))}))
	if float(p.get("warp_hours", 0.0)) > 0.0:
		out.append(Tx.t("ui_reward_warp", {"time": Tx.duration(float(p["warp_hours"]) * 3600.0)}))
	return out


func _offer_card(list: VBoxContainer, id: StringName) -> void:
	var p: Dictionary = Monetization.product(id)
	var pc: PanelContainer = card(list)
	pc.name = "Offer_" + String(id)
	pc.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.BUTTER_SOFT, 18, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var head: HBoxContainer = hbox(v, 10)
	var badge: PanelContainer = ProceduralUIFactory.badge("gift", Palette.STRAWBERRY, Palette.FLOUR_WHITE, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var t: Label = lbl(tv, Tx.t(String(id)), 20, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var tag: PanelContainer = ProceduralUIFactory.pill("star", Tx.t("ui_store_value", {"mult": int(p.get("value_mult", 1))}), Palette.STRAWBERRY, Palette.FLOUR_WHITE, 13)
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tv.add_child(tag)
	for line: String in contents(p):
		var l: Label = lbl(v, "• " + line, 16, Palette.TEXT, true)
		l.name = "Line"
	var row: HBoxContainer = hbox(v, 10)
	var timer: Label = lbl(row, "", 15, Palette.STRAWBERRY_DEEP, true)
	timer.name = "Timer"
	timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timers.append({"label": timer, "fn": func() -> String: return Tx.t("ui_store_ends_in", {"time": Tx.timer(Monetization.offer_left(id))})})
	row.add_child(_price_button(id))


func _club_card(list: VBoxContainer) -> void:
	var p: Dictionary = PremiumManager.product_of_kind("club")
	var id: StringName = StringName(str(p["id"]))
	var pc: PanelContainer = card(list)
	pc.name = "Club"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var head: HBoxContainer = hbox(v, 10)
	var badge: PanelContainer = ProceduralUIFactory.badge("crown", Palette.SIGN_PURPLE, Palette.FLOUR_WHITE, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)
	var t: Label = lbl(head, Tx.t("bakers_club"), 20, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line: String in [Tx.t("ui_club_income", {"mult": Tx.mult(float(p["income_mult"]))}), Tx.t("ui_club_ads"),
			Tx.t("ui_club_daily", {"n": int(p["daily_crumbs"])}), Tx.t("ui_club_offline", {"hours": Tx.mult(float(p["offline_hours"]))})]:
		lbl(v, "• " + line, 15, Palette.TEXT, true)
	var row: HBoxContainer = hbox(v, 10)
	var status: Label = lbl(row, "", 15, Palette.MATCHA_DEEP, true)
	status.name = "Status"
	status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_timers.append({"label": status, "fn": func() -> String:
		return Tx.t("ui_club_active", {"time": Tx.duration(Monetization.club_left())}) if Monetization.club_active() \
			else Tx.t("ui_club_days", {"days": int(p["days"])})})
	row.add_child(_price_button(id, "ui_club_extend" if Monetization.club_active() else "ui_club_join"))


## Kartu hak beli tetap: Golden Oven (income), Night Manager (offline), No Ads.
func _perm_card(list: VBoxContainer, kind: String) -> void:
	var p: Dictionary = PremiumManager.product_of_kind(kind)
	var id: StringName = StringName(str(p["id"]))
	var icon: String = {"income": "fire", "offline": "moon", "no_ads": "heart"}.get(kind, "gift")
	var face: Color = {"income": Palette.HONEY, "offline": Palette.APRON_NAVY, "no_ads": Palette.STRAWBERRY}.get(kind, Palette.HONEY)
	var desc: String = ""
	match kind:
		"income":
			desc = Tx.t("ui_store_income_desc", {"mult": Tx.mult(float(p["income_mult"]))})
		"offline":
			desc = Tx.t("ui_store_offline_desc", {"hours": Tx.mult(float(p["offline_hours"]))})
		"no_ads":
			desc = Tx.t("ui_supporter_owned") if Monetization.owns(id) else Tx.t("ui_store_no_ads_desc")
	var row: HBoxContainer = UISheet.row(list, Tx.t(String(id)), desc, ProceduralUIFactory.badge(icon, face, Palette.FLOUR_WHITE, 48))
	row.get_parent().name = "Product_" + String(id)
	if Monetization.owns(id):
		row.add_child(_owned_pill())
	else:
		row.add_child(_price_button(id))


# ===========================================================================
# BAKERY PASS (GDD idle 22.7)
# ===========================================================================

## Nama musim ("November Pass") dari "YYYY-MM".
static func season_name(season: String) -> String:
	var m: int = int(season.substr(5, 2)) if season.length() >= 7 else 0
	return Tx.t("ui_pass_season", {"month": Tx.t("ui_month_full_%d" % clampi(m, 1, 12))})


## Hari tersisa di bulan tanggal `date` ("YYYY-MM-DD"), termasuk hari ini.
static func days_left(date: String) -> int:
	if date.length() < 10:
		return 0
	var y: int = int(date.substr(0, 4))
	var m: int = int(date.substr(5, 2))
	var d: int = int(date.substr(8, 2))
	var dim: Array[int] = [31, 29 if (y % 4 == 0 and (y % 100 != 0 or y % 400 == 0)) else 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]
	return maxi(1, dim[clampi(m, 1, 12) - 1] - d + 1)


## Teks satu hadiah Pass.
static func reward_text(s: SimulationRoot, r: Dictionary) -> String:
	if r.has("crumbs"):
		return Tx.t("ui_reward_crumbs", {"n": Tx.big(float(r["crumbs"]))})
	if r.has("warp_minutes"):
		return Tx.t("ui_reward_warp", {"time": Tx.duration(float(r["warp_minutes"]) * 60.0)})
	if r.has("boost_hours"):
		return Tx.t("ui_reward_boost", {"mult": Tx.mult(DataRegistry.idlef("premium.ad_boost.mult")), "hours": Tx.mult(float(r["boost_hours"]))})
	if r.has("season"):
		return Tx.item_name(PremiumManager.season_item(s.premium.pass_season, str(r["season"])))
	return ""


func _pass(list: VBoxContainer) -> void:
	var p: PremiumManager = sim.premium
	var head: PanelContainer = card(list)
	head.name = "PassHead"
	head.add_theme_stylebox_override("panel", ProceduralUIFactory.panel(Palette.PASTEL_PERIWINKLE.lightened(0.55), 18, false))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	head.add_child(v)
	var top: HBoxContainer = hbox(v, 10)
	var badge: PanelContainer = ProceduralUIFactory.badge("ticket", Palette.SIGN_PURPLE, Palette.FLOUR_WHITE, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	top.add_child(badge)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(tv)
	var t: Label = lbl(tv, season_name(p.pass_season if p.pass_season != "" else PremiumManager.season_of(BoostManager.today())), 20, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	var days: Label = lbl(tv, "", 14, Palette.TEXT_MUTED, true)
	days.name = "Days"
	_timers.append({"label": days, "fn": func() -> String: return Tx.t("ui_pass_days_left", {"days": days_left(BoostManager.today())})})
	var tier_l: Label = lbl(v, Tx.t("ui_pass_tier_of", {"tier": p.pass_tier(), "tiers": PremiumManager.tiers()}), 16, Palette.UI_WOOD_DEEP, true)
	tier_l.name = "Tier"
	var bar := GoalsScreen.GoalBar.new()
	bar.name = "Bar"
	bar.custom_minimum_size = Vector2(0, 14)
	bar.set_progress(float(p.tier_progress()) / float(PremiumManager.xp_per_tier()), p.pass_tier() >= PremiumManager.tiers())
	v.add_child(bar)
	lbl(v, Tx.t("ui_pass_how"), 14, Palette.TEXT_MUTED, true)
	var row: HBoxContainer = hbox(v, 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var n: int = p.claimable_count()
	if n > 0:
		var all: Button = ProceduralUIFactory.button(Tx.t("ui_pass_claim_all", {"n": n}), "success")
		all.name = "ClaimAll"
		all.custom_minimum_size.y = 52
		all.pressed.connect(func() -> void: _claim_celebrated(all, func() -> void: p.claim_all()))
		row.add_child(all)
	if p.pass_premium:
		row.add_child(_owned_pill("ui_pass_premium_on"))
	elif Monetization.store_available():
		var pid: StringName = Monetization.product_id("pass")
		var buy: Button = _price_button(pid, "ui_pass_unlock")
		row.add_child(buy)
	for tier in range(1, PremiumManager.tiers() + 1):
		_tier_row(list, tier)


func _tier_row(list: VBoxContainer, tier: int) -> void:
	var p: PremiumManager = sim.premium
	var reached: bool = tier <= p.pass_tier()
	var face: Color = Palette.SIGN_PURPLE if reached else Palette.UI_CREAM_DEEP
	var num := PanelContainer.new()
	var nsb: StyleBoxFlat = ProceduralUIFactory.panel(face, 24, false)
	nsb.content_margin_left = 6.0
	nsb.content_margin_right = 6.0
	num.add_theme_stylebox_override("panel", nsb)
	num.custom_minimum_size = Vector2(48, 48)
	var nl: Label = ProceduralUIFactory.label(str(tier), 18, Palette.FLOUR_WHITE if reached else Palette.TEXT_MUTED)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	nl.add_theme_font_override("font", ProceduralUIFactory.display_font())
	num.add_child(nl)
	var row: HBoxContainer = UISheet.row(list, _track_text(&"free", tier), _track_text(&"premium", tier), num)
	row.get_parent().name = "Tier_%d" % tier
	if p.can_claim(&"free", tier) or p.can_claim(&"premium", tier):
		var claim: Button = ProceduralUIFactory.button(Tx.t("ui_goals_claim"), "primary")
		claim.name = "Claim"
		claim.custom_minimum_size = Vector2(110, 48)
		claim.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		claim.pressed.connect(func() -> void: _claim_celebrated(claim, func() -> void:
			p.claim(&"free", tier)
			p.claim(&"premium", tier)))
		row.add_child(claim)


## "Free: 10 Golden Crumbs ✓" / "Premium: ... (locked)".
func _track_text(track: StringName, tier: int) -> String:
	var p: PremiumManager = sim.premium
	var text: String = reward_text(sim, PremiumManager.reward(track, tier))
	var state: String = ""
	if p.is_claimed(track, tier):
		state = Tx.t("ui_pass_claimed_mark")
	elif track == &"premium" and not p.pass_premium:
		state = Tx.t("ui_pass_locked_mark")
	return Tx.t("ui_pass_free_line" if track == &"free" else "ui_pass_premium_line", {"reward": text, "state": state}).strip_edges()


# ===========================================================================
# GOLDEN CRUMBS
# ===========================================================================

func _crumbs(list: VBoxContainer) -> void:
	section(list, Tx.t("ui_store_free_crumbs"))
	var n: int = int(Monetization.placement(&"ad_crumbs").get("crumbs", 0))
	var fr: HBoxContainer = UISheet.row(list, Tx.t("ui_store_ad_crumbs_title", {"n": n}), Tx.t("ui_store_free_crumbs_desc"),
		ProceduralUIFactory.badge("crumb", Palette.HONEY_SOFT, Palette.HONEY_DEEP, 48))
	fr.get_parent().name = "FreeCrumbs"
	fr.add_child(_ad_button(&"ad_crumbs", Tx.t("ui_store_ad_crumbs_btn", {"n": n}), func() -> void:
		sim.premium.earn(n, &"ad")
		_fly(n)))
	if not Monetization.store_available():
		return
	section(list, Tx.t("ui_store_crumb_packs"))
	var base: float = 0.0
	for p: Dictionary in Monetization.products("crumbs"):
		var per: float = float(p["crumbs"]) / float(p["price_usd"])
		base = per if base <= 0.0 else minf(base, per)
	for p2: Dictionary in Monetization.products("crumbs"):
		var id: StringName = StringName(str(p2["id"]))
		var bonus: int = int(round((float(p2["crumbs"]) / float(p2["price_usd"]) / base - 1.0) * 100.0))
		var sub: String = ""
		match str(p2.get("tag", "")):
			"popular":
				sub = Tx.t("ui_store_tag_popular")
			"best":
				sub = Tx.t("ui_store_tag_best")
		if bonus >= 5:
			sub = (sub + " · " if sub != "" else "") + Tx.t("ui_store_bonus", {"percent": bonus})
		var row: HBoxContainer = UISheet.row(list, Tx.t("ui_reward_crumbs", {"n": Tx.big(float(p2["crumbs"]))}), sub,
			ProceduralUIFactory.badge("crumb", Palette.GOLD_STAR if str(p2.get("tag", "")) != "" else Palette.HONEY_SOFT, Palette.HONEY_DEEP, 48))
		row.get_parent().name = "Pack_" + String(id)
		row.add_child(_price_button(id))


# ===========================================================================
# BOOSTS (GDD idle 22.4, 22.6)
# ===========================================================================

func _boosts(list: VBoxContainer) -> void:
	var p: PremiumManager = sim.premium
	var hours: float = DataRegistry.idlef("premium.ad_boost.hours")
	var mult: String = Tx.mult(DataRegistry.idlef("premium.ad_boost.mult"))
	section(list, Tx.t("ui_store_boost_section"))
	var pc: PanelContainer = card(list)
	pc.name = "AdBoost"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	pc.add_child(v)
	var head: HBoxContainer = hbox(v, 10)
	var badge: PanelContainer = ProceduralUIFactory.badge("bolt", Palette.HONEY, Palette.FLOUR_WHITE, 52)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head.add_child(badge)
	var tv := VBoxContainer.new()
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tv)
	var t: Label = lbl(tv, Tx.t("ui_store_boost_title", {"mult": mult}), 20, Palette.UI_WOOD_DEEP, true)
	t.add_theme_font_override("font", ProceduralUIFactory.display_font())
	lbl(tv, Tx.t("ui_store_boost_desc", {"max": Tx.mult(DataRegistry.idlef("premium.ad_boost.max_hours"))}), 14, Palette.TEXT_MUTED, true)
	var status: Label = lbl(v, "", 16, Palette.MATCHA_DEEP, true)
	status.name = "Status"
	_timers.append({"label": status, "fn": func() -> String:
		return Tx.t("ui_store_boost_active", {"time": Tx.timer(p.ad_boost_left)}) if p.ad_boost_left > 0.0 else Tx.t("ui_store_boost_off")})
	var row: HBoxContainer = hbox(v, 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var hours_text: String = Tx.t("ui_store_plus_hours", {"hours": Tx.mult(hours)})
	if p.can_add_boost():
		row.add_child(_ad_button(&"ad_boost", hours_text, func() -> void:
			sim.premium.add_boost(hours)
			_pulse_boost()
			EventBus.notify.emit(1, "ui_store_boost_added", {"mult": mult, "hours": Tx.mult(hours)}, &"bolt")))
		row.add_child(_crumb_button(DataRegistry.idlei("premium.ad_boost.crumbs"), hours_text, func() -> void:
			if sim.premium.buy_boost():
				_pulse_boost()
				EventBus.notify.emit(1, "ui_store_boost_added", {"mult": mult, "hours": Tx.mult(hours)}, &"bolt")
			refresh(), p.can_add_boost))
	else:
		row.add_child(_owned_pill("ui_store_boost_full"))
	section(list, Tx.t("ui_store_warp_section"))
	var per_hour: float = p.warp_amount(3600.0)
	var info: Label = lbl(list, Tx.t("ui_store_warp_desc", {"amount": Tx.kr(per_hour)}), 15, Palette.TEXT_MUTED, true)
	info.name = "WarpInfo"
	var minutes: float = float(Monetization.placement(&"ad_warp").get("minutes", 30.0))
	var ar: HBoxContainer = UISheet.row(list, Tx.t("ui_reward_warp", {"time": Tx.duration(minutes * 60.0)}), "+" + Tx.kr(p.warp_amount(minutes * 60.0)),
		ProceduralUIFactory.badge("warp", Palette.SIGN_BLUE, Palette.FLOUR_WHITE, 48))
	ar.get_parent().name = "Warp_ad"
	ar.add_child(_ad_button(&"ad_warp", Tx.t("ui_store_free"), func() -> void:
		var got: float = sim.premium.time_warp(minutes * 60.0, &"ad_warp")
		_celebrate()
		EventBus.notify.emit(1, "ui_store_warp_done", {"amount": Tx.kr(got)}, &"warp")))
	for w: Variant in DataRegistry.idle("premium.warps"):
		var wd: Dictionary = w
		var wid: StringName = StringName(str(wd["id"]))
		var secs: float = float(wd["hours"]) * 3600.0
		var wr: HBoxContainer = UISheet.row(list, Tx.t("ui_reward_warp", {"time": Tx.duration(secs)}), "+" + Tx.kr(p.warp_amount(secs)),
			ProceduralUIFactory.badge("warp", Palette.SIGN_BLUE, Palette.FLOUR_WHITE, 48))
		wr.get_parent().name = "Warp_" + String(wid)
		wr.add_child(_crumb_button(int(wd["crumbs"]), "", func() -> void:
			var got2: float = sim.premium.buy_warp(wid)
			if got2 >= 0.0:
				_celebrate()
				EventBus.notify.emit(1, "ui_store_warp_done", {"amount": Tx.kr(got2)}, &"warp")
			refresh()))


# ===========================================================================
# STYLE (GDD idle 22.8)
# ===========================================================================

func _style(list: VBoxContainer) -> void:
	var groups: Array = [["ui_store_style_outfits", [&"outfit"]], ["ui_store_style_storefront", [&"skin"]],
		["ui_store_style_decor", [&"wall", &"counter_prop", &"floor_prop", &"floor_overlay"]]]
	for g: Array in groups:
		section(list, Tx.t(str(g[0])))
		for x: Variant in DataRegistry.decorations():
			var d: MiscDefinitions.DecorationDefinition = x
			if d.source == &"premium" and (g[1] as Array).has(d.placement_type):
				_style_row(list, d)
	var note: Label = lbl(list, Tx.t("ui_store_style_note"), 13, Palette.TEXT_MUTED, true)
	note.name = "StyleNote"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


func _style_row(list: VBoxContainer, d: MiscDefinitions.DecorationDefinition) -> void:
	var sub: String = DecorationScreen.shop_sub(sim, d) if d.has_bonus() else Tx.t("decor_type_" + String(d.placement_type))
	var row: HBoxContainer = UISheet.row(list, Tx.t(String(d.localization_key)), sub, DecorIcons.badge(DecorIcons.of_decor(d)))
	row.get_parent().name = "Style_" + String(d.id)
	if sim.decoration.owns(d.id):
		if d.placement_type == &"outfit" or d.placement_type == &"skin":
			var on: bool = sim.decoration.equipped.values().has(String(d.id))
			if on:
				row.add_child(_owned_pill("ui_decor_equipped"))
			else:
				var use: Button = ProceduralUIFactory.button(Tx.t("ui_decor_equip"), "secondary")
				use.name = "Use"
				use.custom_minimum_size = Vector2(110, 52)
				use.size_flags_vertical = Control.SIZE_SHRINK_CENTER
				use.pressed.connect(func() -> void:
					sim.decoration.equip(d.id)
					if game != null and game.world != null:
						game.world.rebuild_all()
					refresh())
				row.add_child(use)
		else:
			row.add_child(_owned_pill())
		return
	row.add_child(_crumb_button(d.price_crumbs, "", func() -> void:
		if sim.decoration.buy(d.id) == &"":
			if game != null and game.world != null:
				game.world.rebuild_all()
			_reveal({"deco": d.id})
		refresh()))
