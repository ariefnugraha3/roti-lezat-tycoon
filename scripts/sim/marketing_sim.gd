class_name MarketingSim
extends Node

## MarketingSim -- Sistem Pemasaran & Iklan (GDD Seksi 8).
##
## Aturan pokok GDD 8: biaya kampanye dibayar DI MUKA, masa aktif 5 hari in-game
## (MarketingDB.DURATION_DAYS), dan hanya SATU kampanye boleh aktif dalam satu waktu.
## Kampanye tersimpan di `GameState.campaign` dengan bentuk `{}` atau `{tier, days_left}`
## (ARCHITECTURE 6) sehingga ikut tersimpan ke berkas simpanan tanpa kunci tambahan.
##
## Sistem ini TIDAK memakai _process: Main yang menjalankan antarmuka lima metode
## ARCHITECTURE 7.0. Hitungan durasi kampanye memakai satuan HARI, bukan detik, jadi
## pengurangannya terjadi di `on_day_end()`.
##
## Pembagian tugas: MarketingSim hanya MENYEDIAKAN angka. CustomerSim yang memakai
## `footfall_mult()`, `archetype_weight_mult()`, `recipe_weight_mult()`, `bulk_override()`,
## `vip_chance_mult()`, dan `all_day_rush()`; ReputationSystem yang memakai
## `rating_per_day()`. MarketingSim tidak pernah menyentuh rating atau pelanggan sendiri.

## Jam sibuk pagi untuk efek khusus kampanye Tier 2 (GDD 8.2 butir 2: "08:00 - 10:00").
const MORNING_RUSH_START: float = 8.0
const MORNING_RUSH_END: float = 10.0

## Tier kampanye yang punya syarat tambahan / efek khusus menurut GDD 8.2.
const TIER_FLYER: int = 1        # butir 1: mendongkrak penjualan roti dasar
const TIER_BANNER: int = 2       # butir 2: Pekerja Kantoran pagi + boost rating bersyarat
const TIER_RADIO: int = 3        # butir 3: pelanggan borongan
const TIER_INFLUENCER: int = 4   # butir 4: Sosialita + peluang Kritikus VIP +40%
const TIER_FESTIVAL: int = 5     # butir 5: rush hour seharian

## GDD 8.2 butir 3: pelanggan borongan memborong 5-10 roti dalam satu struk.
const BULK_RADIO_MIN: int = 5
const BULK_RADIO_MAX: int = 10

## ID pelanggan yang disebut eksplisit oleh efek tambahan GDD 8.2.
const ARCH_OFFICE: String = "pekerja_kantoran"

# --- Keadaan internal ----------------------------------------------------------

## Rujukan ke Main (ARCHITECTURE 7.0); disimpan agar sistem lain bisa ditemukan bila perlu.
var _main: Node = null

## Jam in-game terakhir yang diketahui; dipakai sebagai nilai bawaan efek berbasis jam.
var _hour: float = GameConfig.HOUR_START

## Jumlah pelanggan yang kabur hari ini. GDD 8.2 butir 2 menjadikan kelancaran antrean
## sebagai SYARAT boost rating kampanye Tier 2, jadi angka ini harus dipantau sendiri
## dan tidak boleh sekadar diasumsikan.
var _angry_today: int = 0


# --- Antarmuka sistem simulasi (ARCHITECTURE 7.0) ------------------------------

func setup(main: Node) -> void:
	_main = main
	if not EventBus.customer_left_angry.is_connected(_on_customer_left_angry):
		EventBus.customer_left_angry.connect(_on_customer_left_angry)
	reset()


func reset() -> void:
	_hour = GameConfig.HOUR_START
	_angry_today = 0
	_sanitize_campaign()


## Kampanye dihitung per hari, bukan per detik. Yang dikerjakan tiap tick hanyalah
## mencatat jam berjalan -- dipakai efek Tier 2 yang hanya berlaku pada jam sibuk pagi
## (GDD 8.2) -- dan menjaga bentuk data kampanye tetap sah bila berkas simpanan cacat.
func sim_tick(delta: float, hour: float) -> void:
	if delta <= 0.0:
		return
	_hour = hour
	_sanitize_campaign()


func on_day_start(day: int) -> void:
	_hour = GameConfig.HOUR_START
	_angry_today = 0
	_sanitize_campaign()
	if is_active():
		print_verbose("[iklan] hari %d: %s, sisa %d hari" % [day, campaign_name(), days_left()])


## Satu hari kampanye habis terpakai. Saat sisa hari mencapai nol kampanye berakhir
## (GDD 8: masa aktif 5 hari in-game).
func on_day_end(ledger: Dictionary) -> void:
	if is_active():
		var c: Dictionary = GameState.campaign
		var tier: int = int(c.get("tier", 0))
		var left: int = maxi(0, int(c.get("days_left", 0)) - 1)
		if left <= 0:
			GameState.campaign = {}
			AudioBus.sfx("pop")
			EventBus.campaign_ended.emit(tier)
			EventBus.toast.emit("Kampanye %s sudah selesai." % _tier_name(tier), "megaphone")
		else:
			c["days_left"] = left
	# Ledger GDD 11.1 menyimpan status kampanye SETELAH hari ini diperhitungkan.
	ledger["campaign"] = GameState.campaign.duplicate(true)
	_angry_today = 0


# --- Kendali kampanye ----------------------------------------------------------

## Meluncurkan kampanye `tier`. Biaya penuh dipotong di muka (GDD 8.1) dan hanya satu
## kampanye boleh aktif (GDD 8).
func start_campaign(tier: int) -> bool:
	var db: Dictionary = MarketingDB.entry(tier)
	if db.is_empty():
		return false
	if is_active():
		EventBus.toast.emit("Hanya satu kampanye yang boleh aktif dalam satu waktu.", "warning")
		return false
	if not MarketingDB.is_available(tier, GameState.location_tier):
		var need: int = int(db.get("req_location", tier))
		EventBus.toast.emit("Kampanye ini baru terbuka di %s." % LocationDB.display_name(need), "warning")
		return false

	var cost: float = float(MarketingDB.cost(tier))
	if not GameState.spend_coins(cost, "kampanye %s" % _tier_name(tier)):
		EventBus.toast.emit("Koin belum cukup, butuh %s." % GameConfig.kr(cost), "coin")
		return false

	GameState.campaign = {"tier": tier, "days_left": MarketingDB.DURATION_DAYS}
	AudioBus.sfx("coin")
	EventBus.campaign_started.emit(tier)
	EventBus.toast.emit("%s berjalan %d hari, pengunjung +%d%%." % [
		_tier_name(tier),
		MarketingDB.DURATION_DAYS,
		int(round(MarketingDB.visitor_boost(tier) * 100.0)),
	], "megaphone")
	return true


## Kampanye yang sudah terbuka di tier lokasi sekarang (GDD 8.1).
func available_tiers() -> Array[int]:
	return MarketingDB.available(GameState.location_tier)


## Benar bila kampanye `tier` boleh diluncurkan detik ini juga.
func can_start(tier: int) -> bool:
	if MarketingDB.entry(tier).is_empty():
		return false
	if is_active():
		return false
	if not MarketingDB.is_available(tier, GameState.location_tier):
		return false
	return GameState.coins >= float(MarketingDB.cost(tier))


func is_active() -> bool:
	return active_tier() > 0


## Tier kampanye yang sedang berjalan, atau 0 bila tidak ada.
func active_tier() -> int:
	var c: Dictionary = GameState.campaign
	if c.is_empty():
		return 0
	var tier: int = int(c.get("tier", 0))
	if MarketingDB.entry(tier).is_empty():
		return 0
	if int(c.get("days_left", 0)) <= 0:
		return 0
	return tier


func days_left() -> int:
	if not is_active():
		return 0
	return maxi(0, int(GameState.campaign.get("days_left", 0)))


func campaign_name() -> String:
	return _tier_name(active_tier())


## Ringkasan untuk MarketingScreen dan HUD; {} bila tidak ada kampanye berjalan.
func info() -> Dictionary:
	var tier: int = active_tier()
	if tier <= 0:
		return {}
	var db: Dictionary = MarketingDB.entry(tier)
	return {
		"tier": tier,
		"name": String(db.get("name", "")),
		"days_left": days_left(),
		"cost": MarketingDB.cost(tier),
		"per_day": MarketingDB.per_day(tier),
		"visitor_boost": MarketingDB.visitor_boost(tier),
		"rating_per_day": rating_per_day(),
		"desc": String(db.get("desc", "")),
		"effect": String(db.get("effect", "")),
	}


# --- Angka yang dibaca CustomerSim & ReputationSystem --------------------------

## Peningkatan pengunjung sebagai pecahan (+20% -> 0.20); 0.0 bila tidak ada kampanye.
func visitor_boost() -> float:
	var tier: int = active_tier()
	if tier <= 0:
		return 0.0
	return MarketingDB.visitor_boost(tier)


## Pengali arus pengunjung harian, yaitu 1.0 + peningkatan kolom GDD 8.1.
## Tier 5 bernilai 2.6x sehingga arus antrean lebih dari sekadar berlipat ganda,
## sesuai GDD 8.2 butir 5 ("menggandakan arus antrean ... rush hour seharian").
func footfall_mult() -> float:
	return 1.0 + visitor_boost()


## GDD 8.2 butir 5: kampanye Tier 5 membuat toko ramai SEPANJANG HARI, bukan hanya
## pada jam puncak tiap arketipe. CustomerSim memakai ini untuk mengabaikan jendela
## jam sibuk saat menghitung laju kedatangan.
func all_day_rush() -> bool:
	return active_tier() == TIER_FESTIVAL


## Pengali peluang kedatangan Kritikus Makanan VIP. GDD 8.2 butir 4: Tier 4 menaikkan
## peluangnya +40% -> 1.40. Tier lain 1.0.
func vip_chance_mult() -> float:
	var tier: int = active_tier()
	if tier <= 0:
		return 1.0
	return 1.0 + MarketingDB.vip_chance_bonus(tier)


## Pembobotan ulang komposisi pengunjung menurut sasaran kampanye (GDD 8.1 kolom
## "Target Pelanggan Utama" + efek tambahan GDD 8.2). Nilai ini mengubah SIAPA yang
## datang, bukan berapa banyak; volume total diatur `footfall_mult()` supaya kedua
## angka GDD tidak terkalikan dua kali.
func archetype_weight_mult(archetype: String, hour: float = -1.0) -> float:
	var tier: int = active_tier()
	if tier <= 0 or archetype.is_empty():
		return 1.0
	var targets: Array = MarketingDB.targets(tier)
	if not targets.has(archetype):
		return 1.0
	var h: float = hour
	if h < 0.0:
		h = _hour
	# GDD 8.2 butir 2: spanduk jalanan hanya menambah Pekerja Kantoran pada jam sibuk
	# pagi hari 08:00-10:00, bukan sepanjang hari.
	if tier == TIER_BANNER and archetype == ARCH_OFFICE:
		if h < MORNING_RUSH_START or h >= MORNING_RUSH_END:
			return 1.0
	return 1.0 + MarketingDB.visitor_boost(tier)


## GDD 8.2 butir 1: selebaran kertas roti sangat efektif mendongkrak penjualan varian
## roti dasar (Donat Gula & Roti Tawar), yaitu seluruh resep Tier 1.
func recipe_weight_mult(recipe_id: String) -> float:
	if active_tier() != TIER_FLYER:
		return 1.0
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return 1.0
	if int(rec.get("tier", 0)) != 1:
		return 1.0
	return 1.0 + MarketingDB.visitor_boost(TIER_FLYER)


## Rentang belanja pelanggan borongan yang dipicu kampanye Tier 3 (GDD 8.2 butir 3).
## Vector2i.ZERO berarti kampanye ini tidak mengubah jumlah belanja arketipe tersebut.
func bulk_range(archetype: String) -> Vector2i:
	if active_tier() != TIER_RADIO:
		return Vector2i.ZERO
	if not MarketingDB.targets(TIER_RADIO).has(archetype):
		return Vector2i.ZERO
	return Vector2i(BULK_RADIO_MIN, BULK_RADIO_MAX)


## Jumlah roti borongan hasil undian pada rentang GDD 8.2 butir 3; 0 bila tidak berlaku.
## Memakai GameConfig.rng agar simulasi tetap bisa diulang dari benih yang sama.
func bulk_override(archetype: String) -> int:
	var r: Vector2i = bulk_range(archetype)
	if r == Vector2i.ZERO:
		return 0
	return GameConfig.rng.randi_range(r.x, r.y)


## Tambahan bintang rating toko per hari kampanye (GDD 8.2 "Boost Reputasi").
## Khusus Tier 2 bonus HANYA diberikan pada hari yang antrean kasirnya lancar.
func rating_per_day() -> float:
	var tier: int = active_tier()
	if tier <= 0:
		return 0.0
	var bonus: float = MarketingDB.rating_per_day(tier)
	if bonus <= 0.0:
		return 0.0
	if tier == TIER_BANNER and not queue_smooth():
		return 0.0
	return bonus


## Antrean dianggap lancar bila hari ini belum ada satu pun pelanggan yang kabur.
## Dihitung dari dua sumber sekaligus (sinyal yang didengar sendiri dan statistik
## harian GameState) supaya tetap benar walau salah satunya belum terisi.
func queue_smooth() -> bool:
	if _angry_today > 0:
		return false
	return int(GameState.stats.get("customers_angry", 0)) <= 0


## Jumlah pelanggan yang kabur hari ini menurut catatan MarketingSim.
func angry_today() -> int:
	return maxi(_angry_today, int(GameState.stats.get("customers_angry", 0)))


# --- Pendengar EventBus --------------------------------------------------------

## GDD 8.3: risiko kampanye adalah antrean meluber. Pelanggan yang kabur membatalkan
## syarat "antrean berjalan lancar" milik boost rating Tier 2.
func _on_customer_left_angry(c: Dictionary, reason: String) -> void:
	_angry_today += 1
	print_verbose("[iklan] antrean tidak lancar: %s pergi (%s)" % [
		String(c.get("archetype", "")), reason,
	])


# --- Pembantu internal ---------------------------------------------------------

## Membuang kampanye yang bentuknya tidak sah (mis. berkas simpanan lama yang rusak)
## supaya tidak ada tier di luar tabel GDD 8.1 yang ikut terhitung.
func _sanitize_campaign() -> void:
	var c: Dictionary = GameState.campaign
	if c.is_empty():
		return
	var tier: int = int(c.get("tier", 0))
	var days: int = int(c.get("days_left", 0))
	if MarketingDB.entry(tier).is_empty() or days <= 0:
		GameState.campaign = {}


func _tier_name(tier: int) -> String:
	var db: Dictionary = MarketingDB.entry(tier)
	if db.is_empty():
		return ""
	return String(db.get("name", ""))
