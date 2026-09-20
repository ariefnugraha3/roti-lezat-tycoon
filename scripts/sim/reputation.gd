class_name ReputationSystem
extends Node

## ReputationSystem — pemilik tunggal KEDUA rating permainan (GDD Seksi 9).
##
## GDD 9.1 "Rating Reputasi Toko Fisik" (rentang 0.0 - 5.0):
##   NAIK  : transaksi pembelian yang berhasil, pelayanan kasir yang cepat & ramah,
##           serta boost otomatis selama kampanye iklan berjalan aktif.
##   TURUN : pembelian gagal (stok habis saat pelanggan sudah di kasir), pelanggan
##           kabur karena antrean terlalu panjang, dan menjual roti berkualitas
##           buruk / hampir gosong.
##
## GDD 9.2 "Rating Aplikasi RotiFood" (rentang 1.0 - 5.0): lima baris tabel dampak,
##   diterapkan DeliverySim lewat apply_rotifood().
##
## ATURAN KEPEMILIKAN: hanya kelas ini yang boleh menulis GameState.store_rating dan
## GameState.rotifood_rating. Sistem lain memanggil apply_rotifood() atau cukup
## meng-emit sinyal EventBus yang sudah didengarkan di sini (customer_served,
## customer_left_angry, bread_burned).
##
## SUMBER ANGKA. Tabel GDD 9.2 dipakai persis. GDD 9.1 bersifat kualitatif (tidak
## memuat angka), sehingga besar perubahan rating toko diturunkan dari data yang
## sudah ada di basis data, bukan dikarang:
##   - besar dampak per pelanggan  = CustomerDB.rating_impact (lookup DB)
##   - penundaan verdict food vlogger = CustomerDB.rating_delay_days (lookup DB)
##   - boost kampanye harian       = MarketingDB.rating_per_day (lookup DB)
## Hanya pengali relatif (cepat/marah/kualitas) yang ditetapkan di sini, masing-masing
## disertai kutipan kalimat GDD yang mendasarinya.

# ---------------------------------------------------------------------------
# Batas rating (ARCHITECTURE 6 & GDD 9)
# ---------------------------------------------------------------------------

## GDD 9.1 — rating toko fisik memakai skala bintang 0..5.
const STORE_MIN: float = 0.0
const STORE_MAX: float = 5.0

## GDD 9.2 — "skor bintang (1.0 hingga 5.0)".
const ROTIFOOD_MIN: float = 1.0
const ROTIFOOD_MAX: float = 5.0

# ---------------------------------------------------------------------------
# GDD 9.2 — tabel dampak rating RotiFood (lima baris, disalin persis)
# ---------------------------------------------------------------------------

## Pesanan siap sebelum driver tiba (Instant Handover).
const ROTIFOOD_INSTANT_HANDOVER: float = 0.10
## Pesanan siap dalam batas waktu normal.
const ROTIFOOD_ON_TIME: float = 0.0
## Driver menunggu lebih dari 10 detik.
const ROTIFOOD_DRIVER_WAIT: float = -0.10
## Pesanan dibatalkan karena stok habis / overtime.
const ROTIFOOD_CANCELLED: float = -0.20
## Bonus kualitas roti prima (baru matang sempurna).
const ROTIFOOD_PRIME_BONUS: float = 0.05

# ---------------------------------------------------------------------------
# GDD 3.6.C — ambang waktu yang menentukan baris tabel di atas
# ---------------------------------------------------------------------------

## "waktu tunggu driver < 3 detik" dihitung sebagai Instant Handover.
const INSTANT_HANDOVER_SEC: float = 3.0
## "Driver menunggu >10 detik" (GDD 9.2 baris 3).
const DRIVER_WAIT_LIMIT_SEC: float = 10.0
## "Toko dengan rating 4.5 ke atas mendapatkan badge Toko Terpercaya".
const TRUSTED_BADGE_MIN: float = 4.5
## Badge menaikkan volume order harian "hingga +80%" (GDD 9.2 & GDD 3.6.C).
const TRUSTED_BADGE_ORDER_BOOST: float = 0.80

# ---------------------------------------------------------------------------
# Pengali rating toko fisik (GDD 9.1 kualitatif — diturunkan di sini)
# ---------------------------------------------------------------------------

## Pelanggan dianggap dilayani "cepat dan ramah" bila ia menunggu tidak lebih dari
## 25% jatah kesabarannya (CustomerDB.patience).
const FAST_SERVICE_RATIO: float = 0.25

## Tambahan rating untuk pelayanan cepat: +50% dari rating_impact arketipe.
const FAST_SERVICE_BONUS: float = 0.50

## GDD 8.3 menegaskan pelanggan yang kabur "menurunkan reputasi toko secara drastis",
## jadi satu pelanggan kabur berbobot lebih besar daripada satu transaksi sukses.
const ANGRY_WEIGHT_SEVERE: float = 2.00   # stok habis di kasir / kabur dari antrean
const ANGRY_WEIGHT_MILD: float = 1.00     # sekadar mengeluh harga lalu pergi
const ANGRY_WEIGHT_DEFAULT: float = 1.50  # alasan lain yang belum terdaftar

## Menjual roti buruk mengubah transaksi menjadi kerugian rating sebesar
## rating_impact arketipe (GDD 9.1: "menjual roti dengan kualitas buruk/hampir gosong").
const POOR_QUALITY_PENALTY: float = 1.00

## Roti yang sudah dingin belum tergolong "buruk", tetapi kepuasan pembeli berkurang:
## kenaikan rating dipangkas setengah.
const STALE_QUALITY_GAIN: float = 0.50

## Kualitas kanonik (ARCHITECTURE 2.5) yang dihitung sebagai "kualitas buruk".
const POOR_QUALITIES: Array[String] = ["mentah", "hampir_gosong", "gosong"]

## Kualitas yang hanya memangkas kenaikan, tanpa menurunkan rating.
const STALE_QUALITIES: Array[String] = ["dingin"]

## Roti gosong di oven berarti dapur lengah; GDD tidak memberi angka, jadi dipakai
## potongan kecil per roti dengan batas atas agar satu kelalaian tidak merusak rating.
const BURN_PENALTY_PER_BREAD: float = 0.005
const BURN_PENALTY_MAX: float = 0.10

## GDD 8.2: boost reputasi kampanye berlaku "jika antrean kasir berjalan lancar".
## Antrean dianggap lancar bila pelanggan kabur tidak lebih dari 20% total pengunjung.
const CAMPAIGN_SMOOTH_MAX_ANGRY_RATIO: float = 0.20

## Perubahan sekecil ini belum perlu memicu rating_changed (menahan spam sinyal
## saat boost kampanye dicicil tiap tick).
const EMIT_EPSILON: float = 0.01

# ---------------------------------------------------------------------------
# Keadaan internal
# ---------------------------------------------------------------------------

var _main: Node = null

## Nilai rating saat hari dibuka — dasar perhitungan rating_delta di ledger.
var _day_start_store: float = 0.0
var _day_start_rotifood: float = 0.0

## Verdict tertunda (GDD "Perilaku Konsumen": food vlogger berdampak KEESOKAN harinya).
## Tiap isian: {"delta": float, "reason": String}.
var _pending_verdicts: Array = []

## Tier kampanye yang berlaku hari ini beserta sisa jatah boost hari ini.
var _campaign_tier: int = 0
var _campaign_credit_left: float = 0.0

## Akumulasi perubahan halus yang belum di-emit.
var _unemitted: float = 0.0

# ---------------------------------------------------------------------------
# Antarmuka tick deterministik (ARCHITECTURE 7.0)
# ---------------------------------------------------------------------------

func setup(main: Node) -> void:
	_main = main
	_day_start_store = GameState.store_rating
	_day_start_rotifood = GameState.rotifood_rating

	if not EventBus.customer_served.is_connected(_on_customer_served):
		EventBus.customer_served.connect(_on_customer_served)
	if not EventBus.customer_left_angry.is_connected(_on_customer_left_angry):
		EventBus.customer_left_angry.connect(_on_customer_left_angry)
	if not EventBus.bread_burned.is_connected(_on_bread_burned):
		EventBus.bread_burned.connect(_on_bread_burned)
	if not EventBus.campaign_started.is_connected(_on_campaign_started):
		EventBus.campaign_started.connect(_on_campaign_started)
	if not EventBus.campaign_ended.is_connected(_on_campaign_ended):
		EventBus.campaign_ended.connect(_on_campaign_ended)


## Boost reputasi kampanye dicicil sepanjang jam jualan, bukan diberikan sekaligus,
## dan hanya mengalir selama antrean kasir masih lancar (syarat GDD 8.2).
func sim_tick(delta: float, hour: float) -> void:
	if delta <= 0.0:
		return
	if _campaign_tier <= 0 or _campaign_credit_left <= 0.0:
		return
	if hour < GameConfig.HOUR_OPEN or hour >= GameConfig.HOUR_CLOSE:
		return
	if not _queue_is_smooth():
		return

	var window_sec: float = (GameConfig.HOUR_CLOSE - GameConfig.HOUR_OPEN) * GameConfig.SECONDS_PER_GAME_HOUR
	if window_sec <= 0.0:
		return

	var per_day: float = _campaign_rating_per_day(_campaign_tier)
	if per_day <= 0.0:
		_campaign_credit_left = 0.0
		return

	var step: float = minf(per_day * (delta / window_sec), _campaign_credit_left)
	if step <= 0.0:
		return
	_campaign_credit_left -= step
	_add_store(step, "kampanye iklan", true)


func on_day_start(day: int) -> void:
	# Nilai pembuka dicatat SEBELUM verdict tertunda diterapkan, supaya lonjakan
	# rating dari food vlogger kemarin terbaca sebagai rating_delta hari ini.
	_day_start_store = GameState.store_rating
	_day_start_rotifood = GameState.rotifood_rating
	GameState.stats["rating_start"] = _day_start_store
	GameState.stats["rotifood_start"] = _day_start_rotifood

	_unemitted = 0.0

	# GDD "Perilaku Konsumen": verdict kritikus baru berlaku keesokan harinya.
	var pending: Array = _pending_verdicts.duplicate()
	_pending_verdicts.clear()
	for e: Variant in pending:
		if typeof(e) != TYPE_DICTIONARY:
			continue
		var v: Dictionary = e
		var d: float = float(v.get("delta", 0.0))
		if is_zero_approx(d):
			continue
		var reason: String = String(v.get("reason", "ulasan kemarin"))
		_add_store(d, reason, false)
		var icon: String = "star" if d > 0.0 else "sad"
		var arrow: String = "naik" if d > 0.0 else "turun"
		EventBus.toast.emit(
			"Ulasan %s tayang hari ini: rating toko %s %.2f bintang." % [reason, arrow, absf(d)],
			icon
		)

	# Jatah boost kampanye hari ini (GDD 8.2), dicatat di awal hari supaya tetap
	# benar walaupun MarketingSim menutup kampanye lebih dulu di akhir hari.
	_campaign_tier = int(GameState.campaign.get("tier", 0))
	_campaign_credit_left = _campaign_rating_per_day(_campaign_tier)

	# Parameter `day` dipakai untuk catatan verbose agar mudah dilacak headless.
	print_verbose("[rating] hari %d dibuka: toko %.2f, RotiFood %.2f" % [day, _day_start_store, _day_start_rotifood])


func on_day_end(ledger: Dictionary) -> void:
	_flush_emit()
	ledger["rating_store"] = GameState.store_rating
	ledger["rating_rotifood"] = GameState.rotifood_rating
	ledger["rating_delta"] = GameState.store_rating - _day_start_store
	ledger["rotifood_delta"] = GameState.rotifood_rating - _day_start_rotifood
	_campaign_tier = 0
	_campaign_credit_left = 0.0


func reset() -> void:
	_pending_verdicts.clear()
	_campaign_tier = int(GameState.campaign.get("tier", 0))
	_campaign_credit_left = 0.0
	_unemitted = 0.0
	_day_start_store = GameState.store_rating
	_day_start_rotifood = GameState.rotifood_rating

# ---------------------------------------------------------------------------
# API publik
# ---------------------------------------------------------------------------

## Menerapkan satu baris tabel GDD 9.2. Dipanggil DeliverySim dengan salah satu
## konstanta ROTIFOOD_* di atas. `reason` hanya untuk catatan/log.
func apply_rotifood(delta: float, reason: String) -> void:
	if is_zero_approx(delta):
		return
	var before: float = GameState.rotifood_rating
	GameState.rotifood_rating = clampf(before + delta, ROTIFOOD_MIN, ROTIFOOD_MAX)
	if is_equal_approx(before, GameState.rotifood_rating):
		return
	if not reason.is_empty():
		print_verbose("[rating] RotiFood %+.2f (%s) -> %.2f" % [delta, reason, GameState.rotifood_rating])
	_emit_now()


## GDD 9.2 / 3.6.C — badge "Toko Terpercaya" untuk rating RotiFood >= 4.5.
func has_trusted_badge() -> bool:
	return GameState.rotifood_rating >= TRUSTED_BADGE_MIN


## Pengali volume order harian dari badge (GDD 9.2: "hingga +80%").
func trusted_badge_multiplier() -> float:
	if has_trusted_badge():
		return 1.0 + TRUSTED_BADGE_ORDER_BOOST
	return 1.0


## Perubahan rating toko sejak hari dibuka (dipakai HUD & Daily Summary).
func rating_delta_today() -> float:
	return GameState.store_rating - _day_start_store


## Perubahan rating RotiFood sejak hari dibuka.
func rotifood_delta_today() -> float:
	return GameState.rotifood_rating - _day_start_rotifood


## Benar bila masih ada verdict kritikus yang menunggu tayang besok pagi.
func has_pending_verdict() -> bool:
	return not _pending_verdicts.is_empty()

# ---------------------------------------------------------------------------
# Penanganan sinyal (GDD 9.1)
# ---------------------------------------------------------------------------

## Transaksi berhasil: rating naik sebesar rating_impact arketipe, ditambah bonus
## bila pelayanan cepat, atau berbalik menjadi penurunan bila roti yang dijual buruk.
func _on_customer_served(c: Dictionary, _revenue: float) -> void:
	var archetype: String = String(c.get("archetype", ""))
	var cust: Dictionary = CustomerDB.entry(archetype)
	if cust.is_empty():
		return

	var impact: float = float(cust.get("rating_impact", 0.0))
	if is_zero_approx(impact):
		return

	var quality: String = _sold_quality(c)
	var gain: float = impact
	if POOR_QUALITIES.has(quality):
		# GDD 9.1: menjual roti buruk / hampir gosong MENURUNKAN rating.
		gain = -impact * POOR_QUALITY_PENALTY
	else:
		if STALE_QUALITIES.has(quality):
			gain *= STALE_QUALITY_GAIN
		if _served_fast(c, cust):
			gain += impact * FAST_SERVICE_BONUS

	if archetype == "food_vlogger":
		GameState.stats["vip_visited"] = true

	var cust_name: String = String(cust.get("name", archetype))
	var reason: String = "%s puas" % cust_name
	if gain < 0.0:
		reason = "%s kecewa (roti %s)" % [cust_name, quality]
	_route_delta(gain, cust, reason)


## Pelanggan pergi marah: pembelian gagal atau kabur dari antrean (GDD 9.1).
func _on_customer_left_angry(c: Dictionary, reason: String) -> void:
	var archetype: String = String(c.get("archetype", ""))
	var cust: Dictionary = CustomerDB.entry(archetype)
	if cust.is_empty():
		return

	var impact: float = float(cust.get("rating_impact", 0.0))
	if is_zero_approx(impact):
		return

	if archetype == "food_vlogger":
		GameState.stats["vip_visited"] = true

	var loss: float = -impact * _angry_weight(reason)
	_route_delta(loss, cust, "%s kecewa" % String(cust.get("name", archetype)))


## Roti gosong di oven: dapur lengah, reputasi ikut tergerus sedikit.
func _on_bread_burned(recipe_id: String, count: int) -> void:
	if count <= 0:
		return
	var penalty: float = minf(float(count) * BURN_PENALTY_PER_BREAD, BURN_PENALTY_MAX)
	_add_store(-penalty, "roti gosong (%s)" % recipe_id, false)


func _on_campaign_started(tier: int) -> void:
	_campaign_tier = tier
	_campaign_credit_left = _campaign_rating_per_day(tier)


func _on_campaign_ended(_tier: int) -> void:
	_campaign_tier = 0
	_campaign_credit_left = 0.0

# ---------------------------------------------------------------------------
# Pembantu internal
# ---------------------------------------------------------------------------

## Menyalurkan perubahan rating: langsung, atau ditunda bila arketipe pelanggan
## memang berdampak keesokan harinya (CustomerDB.rating_delay_days, GDD "Perilaku
## Konsumen" untuk Food Vlogger).
func _route_delta(delta: float, cust: Dictionary, reason: String) -> void:
	if is_zero_approx(delta):
		return
	var delay: int = int(cust.get("rating_delay_days", 0))
	if delay > 0:
		_pending_verdicts.append({"delta": delta, "reason": reason})
		var teaser: String = "Ulasan %s akan tayang besok pagi." % String(cust.get("name", "kritikus"))
		EventBus.toast.emit(teaser, "note")
		return
	_add_store(delta, reason, false)


## Satu-satunya jalur penulisan GameState.store_rating.
## `quiet` menahan emit sinyal sampai akumulasi perubahan cukup terasa.
func _add_store(delta: float, reason: String, quiet: bool) -> void:
	if is_zero_approx(delta):
		return
	var before: float = GameState.store_rating
	GameState.store_rating = clampf(before + delta, STORE_MIN, STORE_MAX)
	var applied: float = GameState.store_rating - before
	if is_zero_approx(applied):
		return
	if not reason.is_empty():
		print_verbose("[rating] toko %+.3f (%s) -> %.2f" % [applied, reason, GameState.store_rating])
	if quiet:
		_unemitted += absf(applied)
		if _unemitted < EMIT_EPSILON:
			return
	_emit_now()


func _emit_now() -> void:
	_unemitted = 0.0
	EventBus.rating_changed.emit(GameState.store_rating, GameState.rotifood_rating)


func _flush_emit() -> void:
	if _unemitted > 0.0:
		_emit_now()


## Pelayanan "cepat dan ramah" (GDD 9.1) = menunggu <= 25% jatah kesabaran arketipe.
func _served_fast(c: Dictionary, cust: Dictionary) -> bool:
	var patience: float = float(cust.get("patience", 0.0))
	if patience <= 0.0:
		return false
	var waited: float = float(c.get("waited", 0.0))
	return waited <= patience * FAST_SERVICE_RATIO


## Kualitas roti yang benar-benar terjual. Kontrak ARCHITECTURE 7.1 tidak mewajibkan
## kunci kualitas pada Dictionary pelanggan, jadi kunci opsional dibaca dengan aman:
## "quality" (satu String) atau "qualities" (recipe_id -> String). Bila tidak ada
## keduanya, transaksi dianggap berkualitas normal.
func _sold_quality(c: Dictionary) -> String:
	var direct: String = String(c.get("quality", ""))
	if not direct.is_empty():
		return direct

	var raw: Variant = c.get("qualities", null)
	if typeof(raw) != TYPE_DICTIONARY:
		return "normal"
	var qs: Dictionary = raw

	# Ambil kualitas terburuk dalam keranjang: itulah yang diingat pembeli.
	var worst: String = "normal"
	var worst_rank: int = 0
	for k: Variant in qs:
		var q: String = String(qs[k])
		var rank: int = 0
		if POOR_QUALITIES.has(q):
			rank = 2
		elif STALE_QUALITIES.has(q):
			rank = 1
		if rank > worst_rank:
			worst_rank = rank
			worst = q
	return worst


## Bobot penurunan rating menurut alasan kepergian. CustomerSim bebas menamai
## alasannya, jadi pencocokan dilakukan atas kata kunci, bukan string persis.
func _angry_weight(reason: String) -> float:
	var r: String = reason.to_lower()
	if r.contains("stok") or r.contains("habis") or r.contains("kosong"):
		return ANGRY_WEIGHT_SEVERE
	if r.contains("antre") or r.contains("antri") or r.contains("sabar") or r.contains("lama"):
		return ANGRY_WEIGHT_SEVERE
	if r.contains("harga") or r.contains("mahal"):
		return ANGRY_WEIGHT_MILD
	return ANGRY_WEIGHT_DEFAULT


## Antrean dianggap lancar bila pelanggan kabur masih di bawah ambang (GDD 8.2).
func _queue_is_smooth() -> bool:
	var total: int = int(GameState.stats.get("customers_total", 0))
	if total <= 0:
		return true
	var angry: int = int(GameState.stats.get("customers_angry", 0))
	return float(angry) / float(total) <= CAMPAIGN_SMOOTH_MAX_ANGRY_RATIO


## Boost reputasi harian kampanye. Diambil dari MarketingSim bila sistem itu sudah
## terpasang (agar efek tambahan miliknya ikut terhitung), selain itu langsung dari
## MarketingDB sesuai tabel GDD 8.1.
func _campaign_rating_per_day(tier: int) -> float:
	if tier <= 0:
		return 0.0
	var mkt: Node = _system("mkt")
	if mkt != null and mkt.has_method("rating_per_day"):
		return float(mkt.call("rating_per_day"))
	return MarketingDB.rating_per_day(tier)


## Mengambil sistem simulasi lain lewat Main.systems (ARCHITECTURE 7).
func _system(key: String) -> Node:
	if _main == null:
		return null
	if not ("systems" in _main):
		return null
	var raw: Variant = _main.get("systems")
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var d: Dictionary = raw
	var n: Variant = d.get(key, null)
	if n is Node:
		return n
	return null
