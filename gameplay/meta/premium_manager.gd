class_name PremiumManager
extends SimManager
## Golden Crumbs, boost iklan ×2, time warp, Bakery Pass, dan hadiah harian
## Baker's Club (GDD idle 22). Milik seluruh Crumbtown: Waralaba dan kunjungan
## cabang tidak memulainya ulang (bukan bagian BRANCH_KEYS).
##
## Hak beli perangkat (No Ads, Golden Oven, Night Manager, Baker's Club) milik
## Monetization, bukan save: GameRoot menyalinnya ke `perks` setiap kali
## berubah. Tanpa salinan itu (tes, alat ukur) `perks` = tanpa pembelian, jadi
## simulasi tetap fungsi murni dari save dan seed. Isi produk yang masuk ke save
## (Golden Crumbs, isi paket, Pass premium) diberikan lewat `deliver`.

signal changed()

## Saldo Golden Crumbs dan totalnya sepanjang permainan.
var crumbs: int = 0
var earned_total: int = 0
var spent_total: int = 0
## Sisa detik nyata boost iklan (GDD idle 22.4): berjalan saat bermain dan
## dipotong waktu pergi saat kembali (OfflineManager.settle), seperti jam nyata.
var ad_boost_left: float = 0.0
## Bakery Pass musim ini ("YYYY-MM" tanggal perangkat, GDD idle 22.7).
var pass_season: String = ""
var pass_xp: int = 0
var pass_premium: bool = false
var pass_claimed_free: Array[int] = []
var pass_claimed_premium: Array[int] = []
## Tanggal perangkat hadiah harian Baker's Club terakhir diambil.
var club_claim_date: String = ""
## Paket sekali beli yang isinya sudah masuk save ini.
var delivered: Array[String] = []
## Hak beli perangkat ini (tidak disimpan): {income_mult, offline_hours,
## offline_full, club}.
var perks: Dictionary = no_perks()


func new_game() -> void:
	crumbs = DataRegistry.idlei("premium.start_crumbs")
	earned_total = 0
	spent_total = 0
	ad_boost_left = 0.0
	pass_season = ""
	pass_xp = 0
	pass_premium = false
	pass_claimed_free.clear()
	pass_claimed_premium.clear()
	club_claim_date = ""
	delivered.clear()


func step(dt: float) -> void:
	if ad_boost_left > 0.0:
		ad_boost_left = maxf(0.0, ad_boost_left - DataRegistry.real_seconds(dt))
		if ad_boost_left <= 0.0:
			sim.idle_economy.invalidate()
			changed.emit()


# ===========================================================================
# HAK BELI PERANGKAT
# ===========================================================================

static func no_perks() -> Dictionary:
	return {"income_mult": 1.0, "offline_hours": 0.0, "offline_full": false, "club": false}


## Salin hak beli perangkat (GameRoot, dari Monetization.perks()).
func set_perks(p: Dictionary) -> void:
	var next: Dictionary = no_perks()
	for k: Variant in p.keys():
		next[k] = p[k]
	if str(next) == str(perks):
		return
	perks = next
	sim.idle_economy.invalidate()
	changed.emit()


## Pengali semua penghasilan dari Golden Oven dan Baker's Club (bagian harga
## biasa, jadi juga offline dan model KR/s).
func income_mult() -> float:
	return maxf(1.0, float(perks.get("income_mult", 1.0)))


## Jam offline tambahan di atas batas biasa (Night Manager, Baker's Club).
func offline_hours() -> float:
	return maxf(0.0, float(perks.get("offline_hours", 0.0)))


## Night Manager: penghasilan offline penuh.
func offline_full() -> bool:
	return bool(perks.get("offline_full", false))


func club_active() -> bool:
	return bool(perks.get("club", false))


# ===========================================================================
# GOLDEN CRUMBS
# ===========================================================================

func earn(n: int, reason: StringName) -> void:
	if n <= 0:
		return
	crumbs += n
	earned_total += n
	GameLogger.info("ECONOMY", "+%d golden crumbs (%s)" % [n, reason])
	changed.emit()


func can_spend(n: int) -> bool:
	return n >= 0 and crumbs >= n


func spend(n: int, reason: StringName) -> bool:
	if not can_spend(n):
		return false
	crumbs -= n
	spent_total += n
	GameLogger.info("ECONOMY", "-%d golden crumbs (%s)" % [n, reason])
	changed.emit()
	SaveManager.request_autosave("crumbs")
	return true


# ===========================================================================
# BOOST IKLAN ×2 (GDD idle 22.4, 22.6)
# ===========================================================================

func ad_boost_mult() -> float:
	return DataRegistry.idlef("premium.ad_boost.mult") if ad_boost_left > 0.0 else 1.0


func ad_boost_max() -> float:
	return DataRegistry.idlef("premium.ad_boost.max_hours") * 3600.0


## Masih ada ruang untuk satu boost lagi (paling tidak satu menit).
func can_add_boost() -> bool:
	return ad_boost_left < ad_boost_max() - 60.0


## Tambah `hours` jam boost ×2, paling lama `max_hours`.
func add_boost(hours: float) -> void:
	if hours <= 0.0:
		return
	ad_boost_left = minf(ad_boost_left + hours * 3600.0, ad_boost_max())
	sim.idle_economy.invalidate()
	changed.emit()


## Beli boost dengan Golden Crumbs. false bila penuh atau crumbs kurang.
func buy_boost() -> bool:
	if not can_add_boost() or not spend(DataRegistry.idlei("premium.ad_boost.crumbs"), &"boost"):
		return false
	add_boost(DataRegistry.idlef("premium.ad_boost.hours"))
	return true


## Detik pergi `seconds` yang ikut boost: boost habis lebih dulu bila lebih pendek.
func boosted_seconds(seconds: float) -> float:
	return clampf(minf(ad_boost_left, seconds), 0.0, INF)


## Waktu pergi memotong boost (jam nyata).
func consume_away(seconds: float) -> void:
	if ad_boost_left <= 0.0 or seconds <= 0.0:
		return
	ad_boost_left = maxf(0.0, ad_boost_left - seconds)
	if ad_boost_left <= 0.0:
		sim.idle_economy.invalidate()
	changed.emit()


# ===========================================================================
# TIME WARP (GDD idle 22.6)
# ===========================================================================

## KR yang didapat dari `seconds` detik penghasilan: KR/s model tanpa boost.
func warp_amount(seconds: float) -> float:
	return Money.round_cents(maxf(sim.idle_economy.rate(false), 0.0) * maxf(seconds, 0.0))


## Langsung dapat penghasilan `seconds` detik. Mengembalikan jumlahnya.
func time_warp(seconds: float, reason: StringName) -> float:
	var amount: float = warp_amount(seconds)
	if amount > 0.0:
		sim.economy.credit(amount, &"TIME_WARP", reason, {"seconds": seconds})
	SaveManager.request_autosave("time_warp")
	return amount


static func warp(id: StringName) -> Dictionary:
	for w: Variant in DataRegistry.idle("premium.warps"):
		if StringName(str((w as Dictionary)["id"])) == id:
			return w
	return {}


## Beli time warp `id` dengan Golden Crumbs. -1 bila crumbs kurang.
func buy_warp(id: StringName) -> float:
	var w: Dictionary = warp(id)
	if w.is_empty() or not spend(int(w["crumbs"]), id):
		return -1.0
	return time_warp(float(w["hours"]) * 3600.0, id)


# ===========================================================================
# BAKERY PASS (GDD idle 22.7)
# ===========================================================================

## Musim tanggal perangkat `date` ("YYYY-MM-DD" -> "YYYY-MM").
static func season_of(date: String) -> String:
	return date.substr(0, 7) if date.length() >= 7 else ""


## Indeks musim untuk memilih barang musim: tahun × 12 + bulan.
static func season_index(season: String) -> int:
	var parts: PackedStringArray = season.split("-")
	if parts.size() < 2:
		return 0
	return maxi(0, int(parts[0]) * 12 + int(parts[1]) - 1)


## Barang musim `kind` ("outfit" atau "decor") untuk musim `season`.
static func season_item(season: String, kind: String) -> StringName:
	var items: Array = DataRegistry.idle("pass.season_items")
	if items.is_empty():
		return &""
	return StringName(str((items[season_index(season) % items.size()] as Dictionary).get(kind, "")))


static func tiers() -> int:
	return DataRegistry.idlei("pass.tiers")


static func xp_per_tier() -> int:
	return maxi(1, DataRegistry.idlei("pass.xp_per_tier"))


## Musim berganti di tanggal `date` (GameRoot, tanggal perangkat; simulasi
## sendiri tidak pernah membaca jam dinding): hadiah musim lama yang sudah
## tercapai tetapi belum diambil langsung diberikan (tidak ada yang hilang), lalu
## XP dan Pass premium mulai dari nol. Save tanpa musim mengambil musim ini
## dengan XP yang sudah terkumpul. Mengembalikan hadiah yang diberikan.
func ensure_season(date: String) -> Array[Dictionary]:
	var s: String = season_of(date)
	var got: Array[Dictionary] = []
	if s == "" or s == pass_season:
		return got
	if pass_season == "":
		pass_season = s
		changed.emit()
		return got
	got = claim_all()
	pass_season = s
	pass_xp = 0
	pass_premium = false
	pass_claimed_free.clear()
	pass_claimed_premium.clear()
	changed.emit()
	return got


## Tingkat yang sudah tercapai (0..tiers).
func pass_tier() -> int:
	return mini(pass_xp / xp_per_tier(), tiers())


## XP di dalam tingkat berikutnya (penuh di tingkat terakhir).
func tier_progress() -> int:
	return xp_per_tier() if pass_tier() >= tiers() else pass_xp % xp_per_tier()


func add_xp(n: int) -> void:
	if n <= 0:
		return
	var before: int = pass_tier()
	pass_xp += n
	if pass_tier() > before:
		EventBus.notify.emit(1, "ui_pass_tier_up", {"tier": pass_tier()}, &"ticket")
	changed.emit()


static func reward(track: StringName, tier: int) -> Dictionary:
	var arr: Array = DataRegistry.idle("pass.premium" if track == &"premium" else "pass.free")
	return (arr[tier - 1] as Dictionary) if tier >= 1 and tier <= arr.size() else {}


func is_claimed(track: StringName, tier: int) -> bool:
	return (pass_claimed_premium if track == &"premium" else pass_claimed_free).has(tier)


func can_claim(track: StringName, tier: int) -> bool:
	if tier < 1 or tier > pass_tier() or is_claimed(track, tier):
		return false
	return track != &"premium" or pass_premium


func claim(track: StringName, tier: int) -> bool:
	if not can_claim(track, tier):
		return false
	(pass_claimed_premium if track == &"premium" else pass_claimed_free).append(tier)
	grant_reward(reward(track, tier))
	SaveManager.request_autosave("pass")
	return true


func claimable_count() -> int:
	var n: int = 0
	for t in range(1, pass_tier() + 1):
		n += 1 if can_claim(&"free", t) else 0
		n += 1 if can_claim(&"premium", t) else 0
	return n


## Ambil semua hadiah yang bisa diambil. Mengembalikan hadiahnya.
func claim_all() -> Array[Dictionary]:
	var got: Array[Dictionary] = []
	for t in range(1, pass_tier() + 1):
		for track: StringName in [&"free", &"premium"]:
			if claim(track, t):
				got.append(reward(track, t))
	return got


## Beri satu hadiah Pass. Barang musim yang sudah dimiliki (musim berulang)
## diganti Golden Crumbs.
func grant_reward(r: Dictionary) -> void:
	if r.has("crumbs"):
		earn(int(r["crumbs"]), &"pass")
	elif r.has("warp_minutes"):
		time_warp(float(r["warp_minutes"]) * 60.0, &"pass")
	elif r.has("boost_hours"):
		add_boost(float(r["boost_hours"]))
	elif r.has("season"):
		var item: StringName = season_item(pass_season, str(r["season"]))
		if item == &"" or sim.decoration.owns(item):
			earn(DataRegistry.idlei("pass.duplicate_crumbs"), &"pass_duplicate")
		else:
			sim.decoration.grant(item)


## Pass premium musim ini (pembelian).
func unlock_pass() -> void:
	pass_premium = true
	changed.emit()


# ===========================================================================
# HADIAH (crumbs + XP Pass)
# ===========================================================================

func on_goal() -> void:
	earn(DataRegistry.idlei("premium.earn.goal"), &"goal")
	add_xp(DataRegistry.idlei("pass.xp.goal"))


## Cap kalender; `week` = cap ketujuh.
func on_calendar(week: bool) -> void:
	earn(DataRegistry.idlei("premium.earn.calendar") + (DataRegistry.idlei("premium.earn.calendar_week") if week else 0), &"calendar")
	add_xp(DataRegistry.idlei("pass.xp.calendar"))


func on_achievement() -> void:
	earn(DataRegistry.idlei("premium.earn.achievement"), &"achievement")
	add_xp(DataRegistry.idlei("pass.xp.achievement"))


func on_series(levels: int) -> void:
	earn(DataRegistry.idlei("premium.earn.series") * maxi(levels, 0), &"series")
	add_xp(DataRegistry.idlei("pass.xp.series") * maxi(levels, 0))


func on_franchise(stars: int) -> void:
	earn(DataRegistry.idlei("premium.earn.franchise_per_star") * maxi(stars, 0), &"franchise")
	add_xp(DataRegistry.idlei("pass.xp.franchise"))


func on_ad() -> void:
	add_xp(DataRegistry.idlei("pass.xp.ad"))


# ===========================================================================
# BAKER'S CLUB DAN PRODUK
# ===========================================================================

static func product(id: StringName) -> Dictionary:
	for x: Variant in DataRegistry.idle("monetization.products"):
		if StringName(str((x as Dictionary)["id"])) == id:
			return x
	return {}


static func product_of_kind(kind: String) -> Dictionary:
	for x: Variant in DataRegistry.idle("monetization.products"):
		if str((x as Dictionary)["kind"]) == kind:
			return x
	return {}


func club_available(date: String) -> bool:
	return club_active() and date != "" and date != club_claim_date


## Hadiah harian Baker's Club. Mengembalikan crumbs yang diberikan.
func claim_club(date: String) -> int:
	if not club_available(date):
		return 0
	club_claim_date = date
	var n: int = int(product_of_kind("club").get("daily_crumbs", 0))
	earn(n, &"club")
	SaveManager.request_autosave("club")
	return n


## Isi produk `id` yang masuk ke save ini setelah dibeli: Golden Crumbs, isi
## paket (sekali per save), atau Pass premium. Hak beli lain (No Ads, Golden
## Oven, Night Manager, Club) tidak masuk save. true bila ada yang diberikan.
func deliver(id: StringName) -> bool:
	var p: Dictionary = product(id)
	if p.is_empty():
		return false
	match str(p["kind"]):
		"crumbs":
			earn(int(p["crumbs"]), &"purchase")
		"pass":
			unlock_pass()
		"offer":
			if delivered.has(String(id)):
				return false
			delivered.append(String(id))
			earn(int(p.get("crumbs", 0)), &"purchase")
			var item: StringName = StringName(str(p.get("decor", "")))
			if item != &"":
				sim.decoration.grant(item)
			if float(p.get("boost_hours", 0.0)) > 0.0:
				add_boost(float(p["boost_hours"]))
			if float(p.get("warp_hours", 0.0)) > 0.0:
				time_warp(float(p["warp_hours"]) * 3600.0, id)
		_:
			return false
	SaveManager.request_autosave("purchase", true)
	return true


# ===========================================================================
# SAVE
# ===========================================================================

func capture() -> Dictionary:
	return {"crumbs": crumbs, "earned_total": earned_total, "spent_total": spent_total, "ad_boost_left": ad_boost_left,
		"pass": {"season": pass_season, "xp": pass_xp, "premium": pass_premium, "claimed_free": pass_claimed_free.duplicate(),
			"claimed_premium": pass_claimed_premium.duplicate()},
		"club_claim_date": club_claim_date, "delivered": delivered.duplicate()}


## Save dari sebelum monetisasi (tanpa kunci "premium") mulai dengan crumbs awal.
func restore(d: Dictionary) -> void:
	new_game()
	crumbs = maxi(0, int(d.get("crumbs", crumbs)))
	earned_total = maxi(0, int(d.get("earned_total", 0)))
	spent_total = maxi(0, int(d.get("spent_total", 0)))
	ad_boost_left = clampf(float(d.get("ad_boost_left", 0.0)), 0.0, ad_boost_max())
	var p: Variant = d.get("pass", {})
	if p is Dictionary:
		var pd: Dictionary = p
		pass_season = str(pd.get("season", ""))
		pass_xp = maxi(0, int(pd.get("xp", 0)))
		pass_premium = bool(pd.get("premium", false))
		for t: Variant in pd.get("claimed_free", []):
			if not pass_claimed_free.has(int(t)):
				pass_claimed_free.append(int(t))
		for t2: Variant in pd.get("claimed_premium", []):
			if not pass_claimed_premium.has(int(t2)):
				pass_claimed_premium.append(int(t2))
	club_claim_date = str(d.get("club_claim_date", ""))
	for x: Variant in d.get("delivered", []):
		if not delivered.has(str(x)):
			delivered.append(str(x))
