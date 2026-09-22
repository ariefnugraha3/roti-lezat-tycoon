extends SceneTree
## Audit fidelitas data terhadap GDD.
##
## Setiap angka di bawah ini disalin langsung dari docs/gdd-roti-lezaat-tycoon.md.
## Script ini membandingkannya dengan isi data layer. Gagal satu pun -> exit 1.
##
## Jalankan: godot --headless --path . --script res://tools/data_audit.gd

var _fail: int = 0
var _pass: int = 0


func _initialize() -> void:
	print("=== AUDIT DATA vs GDD ===")
	_audit_ingredients()
	_audit_recipes()
	_audit_equipment()
	_audit_locations()
	_audit_storage()
	_audit_counter_height()
	_audit_staff()
	_audit_marketing()
	_audit_customers()
	_audit_weather()
	_audit_opening()
	_audit_cross_references()

	print("")
	print("=== HASIL AUDIT ===")
	print("LULUS : %d" % _pass)
	print("GAGAL : %d" % _fail)
	quit(1 if _fail > 0 else 0)


func _eq(label: String, actual: Variant, expected: Variant) -> void:
	if typeof(actual) == TYPE_FLOAT or typeof(expected) == TYPE_FLOAT:
		if is_equal_approx(float(actual), float(expected)):
			_pass += 1
			return
	elif actual == expected:
		_pass += 1
		return
	_fail += 1
	print("GAGAL  %s : dapat=%s, GDD=%s" % [label, str(actual), str(expected)])


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("GAGAL  %s" % label)


# --- GDD 5.2.1 A/B/C -----------------------------------------------------------

const ING_PRICE: Dictionary = {
	"tepung_terigu": 150, "gula_pasir": 80, "ragi": 50, "telur": 100,
	"mentega": 120, "air_garam": 20,
	"cokelat": 250, "keju": 300, "selai": 200, "susu": 150,
	"sosis": 350, "kayu_manis": 180,
	"whole_wheat": 400, "butter_organik": 600, "almond": 500,
	"cream_cheese": 750, "matcha": 800, "truffle": 1200,
}


func _audit_ingredients() -> void:
	print("\n-- Bahan Baku (GDD 5.2.1) --")
	_eq("jumlah bahan", IngredientDB.ids().size(), 18)
	for id in ING_PRICE:
		var e: Dictionary = IngredientDB.entry(id)
		_ok("bahan '%s' ada" % id, not e.is_empty())
		if e.is_empty():
			continue
		_eq("harga %s" % id, IngredientDB.price(id), ING_PRICE[id])
	_eq("kategori dasar", IngredientDB.by_category("dasar").size(), 6)
	_eq("kategori isian", IngredientDB.by_category("isian").size(), 6)
	_eq("kategori premium", IngredientDB.by_category("premium").size(), 6)


# --- GDD 5.3.1 .. 5.3.5 --------------------------------------------------------
# [tier, modal, batch_price, profit, time_sec, yield_count, unlock_price]

const RECIPES: Dictionary = {
	"roti_tawar_polos":            [1, 340, 550, 210, 50.0, 6, 0],
	"donat_gula":                  [1, 500, 750, 250, 55.0, 5, 0],
	"roti_goreng_polos":           [1, 220, 400, 180, 35.0, 6, 0],
	"roti_cokelat":                [2, 820, 1200, 380, 45.0, 5, 500],
	"roti_sosis_gulung":           [2, 710, 1100, 390, 40.0, 5, 500],
	"roti_keju_manis":             [2, 880, 1350, 470, 50.0, 5, 600],
	"donat_selai_stroberi":        [2, 680, 1050, 370, 55.0, 5, 500],
	"baguette_klasik":             [2, 220, 650, 430, 60.0, 3, 400],
	"croissant_klasik":            [3, 940, 1600, 660, 75.0, 4, 1200],
	"cinnamon_roll":               [3, 870, 1500, 630, 70.0, 4, 1200],
	"pain_au_chocolat":            [3, 1090, 1800, 710, 80.0, 4, 1500],
	"danish_cheese_pastry":        [3, 1070, 1750, 680, 80.0, 4, 1500],
	"roti_sobek_susu":             [3, 920, 1550, 630, 65.0, 6, 1000],
	"croissant_artisan_almond":    [4, 1470, 2800, 1330, 90.0, 4, 3000],
	"sourdough_whole_wheat":       [4, 470, 2200, 1730, 120.0, 2, 3500],
	"brioche_gourmet":             [4, 1600, 3000, 1400, 100.0, 4, 3000],
	"matcha_sweet_brioche":        [4, 1870, 3500, 1630, 110.0, 4, 4000],
	"basque_burnt_cheese_bun":     [4, 1130, 2500, 1370, 95.0, 4, 3500],
	"matcha_mille_crepes":         [5, 2450, 5500, 3050, 150.0, 2, 8000],
	"truffle_mushroom_bun":        [5, 1870, 6000, 4130, 140.0, 3, 10000],
	"almond_croissant_mewah":      [5, 2470, 5000, 2530, 130.0, 4, 7000],
	"premium_cream_cheese_danish": [5, 2170, 4500, 2330, 120.0, 4, 6000],
	"roti_emas_artisan":           [5, 3070, 8000, 4930, 180.0, 2, 15000],
}


func _audit_recipes() -> void:
	print("\n-- Resep (GDD 5.3) --")
	_eq("jumlah resep", RecipeDB.ids().size(), 23)
	for id in RECIPES:
		var want: Array = RECIPES[id]
		var e: Dictionary = RecipeDB.entry(id)
		_ok("resep '%s' ada" % id, not e.is_empty())
		if e.is_empty():
			continue
		_eq("%s.tier" % id, e.get("tier"), want[0])
		_eq("%s.modal" % id, e.get("modal"), want[1])
		_eq("%s.batch_price" % id, e.get("batch_price"), want[2])
		_eq("%s.profit" % id, e.get("profit"), want[3])
		_eq("%s.time_sec" % id, e.get("time_sec"), want[4])
		_eq("%s.yield_count" % id, e.get("yield_count"), want[5])
		_eq("%s.unlock_price" % id, e.get("unlock_price"), want[6])
		# Invarian GDD: Profit Bersih = Harga Jual Sweet Spot - Modal Bahan.
		_eq("%s invarian profit" % id, int(e.get("profit")),
			int(e.get("batch_price")) - int(e.get("modal")))
		# Alat minimum = tier resep (kontrak arsitektur 3).
		_eq("%s.min_mixer" % id, e.get("min_mixer"), want[0])
		_eq("%s.min_oven" % id, e.get("min_oven"), want[0])
		var want_baker: int = 0 if want[0] <= 2 else int(want[0])
		_eq("%s.min_baker_tier" % id, e.get("min_baker_tier"), want_baker)
		# Harga satuan default = harga batch / hasil per batch.
		_eq("%s.unit_price_default" % id, RecipeDB.unit_price_default(id),
			float(want[2]) / float(want[5]))

	_eq("resep tier 1", RecipeDB.by_tier(1).size(), 3)
	_eq("resep tier 2", RecipeDB.by_tier(2).size(), 5)
	_eq("resep tier 3", RecipeDB.by_tier(3).size(), 5)
	_eq("resep tier 4", RecipeDB.by_tier(4).size(), 5)
	_eq("resep tier 5", RecipeDB.by_tier(5).size(), 5)
	_eq("resep starter gratis", RecipeDB.starter().size(), 3)


# --- GDD 5.1 -------------------------------------------------------------------

const MIXER_TIME: Array = [20.0, 15.0, 10.0, 6.0, 3.0]
const MIXER_PRICE: Array = [0, 1500, 4500, 12000, 35000]
const OVEN_TIME: Array = [30.0, 22.0, 15.0, 10.0, 5.0]
const OVEN_PRICE: Array = [0, 2000, 6000, 15000, 50000]
const DISPLAY_CAP: Array = [50, 100, 200, 350, 600]
const DISPLAY_PRICE: Array = [0, 1500, 4500, 12000, 30000]


func _audit_equipment() -> void:
	print("\n-- Peralatan (GDD 5.1) --")
	for i in 5:
		var t: int = i + 1
		_eq("mixer T%d waktu" % t, EquipmentDB.mixer_time(t), MIXER_TIME[i])
		_eq("mixer T%d harga" % t, EquipmentDB.price("mixer", t), MIXER_PRICE[i])
		_eq("oven T%d waktu" % t, EquipmentDB.oven_time(t), OVEN_TIME[i])
		_eq("oven T%d harga" % t, EquipmentDB.price("oven", t), OVEN_PRICE[i])
		_eq("display T%d kapasitas" % t, EquipmentDB.rack_capacity(t), DISPLAY_CAP[i])
		_eq("display T%d harga" % t, EquipmentDB.price("display", t), DISPLAY_PRICE[i])


# --- GDD 6 + 3.3 + 5.2.2 -------------------------------------------------------
# [price, mixer_slots, oven_slots, rack_slots, cashier_slots,
#  max_kasir, max_baker, queue_cap, pantry_cap, total_display]

const LOCATIONS: Array = [
	[0,      1, 1, 1, 1, 1, 1, 4,  150,  50],
	[15000,  2, 2, 2, 1, 1, 2, 8,  400,  200],
	[55000,  3, 3, 3, 2, 2, 2, 14, 1000, 600],
	[180000, 4, 4, 4, 2, 2, 3, 20, 2500, 1400],
	[600000, 5, 5, 6, 3, 3, 4, 35, 6000, 3600],
]


# --- GDD 5.1.1 + 6 (tabel Gudang Penyimpanan) ---------------------------------
# [nama gudang, jejak lebar, jejak dalam]
#
# Gudang ikut tier LOKASI, bukan tier alat: ia sepaket dengan bangunan dan tidak
# pernah dijual di Pasar. Jejaknya selalu N x 1 ubin -- kulkas dan lemari berjajar
# sebaris dengan semua pintu menghadap depan.
const STORAGE: Array = [
	["Kulkas Bekas & Rak Kayu", 2, 1],
	["Kulkas Dua Pintu & Lemari Bahan", 3, 1],
	["Chiller Tegak & Lemari Stainless", 4, 1],
	["Chiller Ganda & Lemari Bahan Segar", 4, 1],
	["Cold Room & Rak Gudang Industri", 5, 1],
]


func _audit_storage() -> void:
	print("
-- Gudang Penyimpanan (GDD 5.1.1, 5.2.2, 6) --")
	for i in 5:
		var t: int = i + 1
		var w: Array = STORAGE[i]
		_eq("gudang T%d nama" % t, LocationDB.storage_name(t), String(w[0]))
		var jejak: Vector2i = EquipmentFactory.footprint("storage", t)
		_eq("gudang T%d jejak lebar" % t, jejak.x, int(w[1]))
		_eq("gudang T%d jejak dalam" % t, jejak.y, int(w[2]))
		# Kapasitasnya satu angka dengan pantry_cap: gudang adalah wujud fisik
		# kapasitas itu, bukan tabel kedua yang bisa berbeda diam-diam.
		_eq("gudang T%d kapasitas = pantry_cap" % t,
			LocationDB.pantry_cap(t), int(LOCATIONS[i][8]))
	# GDD 5.1.1: gudang TIDAK pernah dijual di Pasar.
	_ok("gudang tidak terdaftar sebagai alat yang dibeli",
		not EquipmentDB.has_kind("storage"))


# --- GDD 4.2 (proporsi perabot terikat karakter) ------------------------------

func _audit_counter_height() -> void:
	print("
-- Tinggi Meja Layan (GDD 4.2) --")
	_eq("garis dada = bahu karakter chibi",
		EquipmentFactory.CHEST_HEIGHT, CharacterFactory.SHOULDER_Y)
	_ok("permukaan meja (%.2f m) tidak melewati garis dada (%.2f m)"
		% [EquipmentFactory.COUNTER_HEIGHT, EquipmentFactory.CHEST_HEIGHT],
		EquipmentFactory.COUNTER_HEIGHT <= EquipmentFactory.CHEST_HEIGHT)
	_eq("meja pembatas setinggi meja layan lain",
		EquipmentFactory.DIVIDER_HEIGHT, EquipmentFactory.COUNTER_HEIGHT)


func _audit_locations() -> void:
	print("\n-- Lokasi Toko (GDD 6, 3.3, 5.2.2) --")
	for i in 5:
		var t: int = i + 1
		var w: Array = LOCATIONS[i]
		var e: Dictionary = LocationDB.entry(t)
		_ok("lokasi T%d ada" % t, not e.is_empty())
		if e.is_empty():
			continue
		_eq("lokasi T%d harga" % t, e.get("price"), w[0])
		_eq("lokasi T%d mixer_slots" % t, e.get("mixer_slots"), w[1])
		_eq("lokasi T%d oven_slots" % t, e.get("oven_slots"), w[2])
		_eq("lokasi T%d rack_slots" % t, e.get("rack_slots"), w[3])
		_eq("lokasi T%d cashier_slots" % t, e.get("cashier_slots"), w[4])
		_eq("lokasi T%d max_kasir" % t, e.get("max_kasir"), w[5])
		_eq("lokasi T%d max_baker" % t, e.get("max_baker"), w[6])
		_eq("lokasi T%d queue_cap" % t, e.get("queue_cap"), w[7])
		_eq("lokasi T%d pantry_cap" % t, e.get("pantry_cap"), w[8])
		# GDD 6 menyebut total kapasitas etalase per tier; harus = rak x kapasitas per rak.
		_eq("lokasi T%d total display" % t, LocationDB.display_capacity(t, t), w[9])
		# GDD 3.6.B: Meja Khusus Ojol mulai tersedia di Tier 3.
		_eq("lokasi T%d pickup counter" % t, LocationDB.has_pickup_counter(t), t >= 3)


# --- GDD 3.1, 3.2, 3.5 ---------------------------------------------------------

const KASIR_SALARY: Array = [150, 350, 800, 1800, 4000]
const KASIR_SPEED: Array = [7.0, 5.0, 3.5, 2.2, 1.2]
const BAKER_SALARY: Array = [180, 400, 950, 2200, 5000]
const BAKER_SPEED: Array = [1.0, 1.25, 1.60, 2.00, 2.80]
const BAKER_ANTIBURN: Array = [0.0, 0.25, 0.60, 0.90, 1.00]

const KASIR_IDS: Array = [
	"budi", "sari", "dimas", "nadia", "rian", "lili", "maya", "reza",
	"dewi", "hendra", "citra", "kenji", "grace", "tejo", "luna",
]
const BAKER_IDS: Array = [
	"joko", "ani", "bagus", "fajar", "rina", "doni", "aris", "tari",
	"gilang", "sophie", "danu", "aoi", "pierre", "mawar", "alistair",
]


func _audit_staff() -> void:
	print("\n-- Karyawan (GDD 3.1, 3.2, 3.5) --")
	_eq("jumlah staf total", StaffDB.ids().size(), 30)
	_eq("jumlah kasir", StaffDB.by_role("kasir").size(), 15)
	_eq("jumlah baker", StaffDB.by_role("baker").size(), 15)

	for id in KASIR_IDS:
		var e: Dictionary = StaffDB.entry(id)
		_ok("kasir '%s' ada" % id, not e.is_empty())
		if e.is_empty():
			continue
		_eq("%s.role" % id, e.get("role"), "kasir")
		var t: int = int(e.get("tier", 0))
		_ok("%s tier 1..5" % id, t >= 1 and t <= 5)
		if t >= 1 and t <= 5:
			_eq("%s.salary" % id, e.get("salary"), KASIR_SALARY[t - 1])
			_eq("%s.speed" % id, e.get("speed"), KASIR_SPEED[t - 1])

	for id in BAKER_IDS:
		var e: Dictionary = StaffDB.entry(id)
		_ok("baker '%s' ada" % id, not e.is_empty())
		if e.is_empty():
			continue
		_eq("%s.role" % id, e.get("role"), "baker")
		var t: int = int(e.get("tier", 0))
		_ok("%s tier 1..5" % id, t >= 1 and t <= 5)
		if t >= 1 and t <= 5:
			_eq("%s.salary" % id, e.get("salary"), BAKER_SALARY[t - 1])
			_eq("%s.speed" % id, e.get("speed"), BAKER_SPEED[t - 1])
			var extra: Dictionary = e.get("extra", {})
			_eq("%s.anti_burn" % id, float(extra.get("anti_burn", -1.0)),
				BAKER_ANTIBURN[t - 1])

	# GDD 3.5: tiap tier punya tepat 3 kandidat per peran.
	for t in range(1, 6):
		_eq("kandidat kasir T%d" % t, StaffDB.by_tier("kasir", t).size(), 3)
		_eq("kandidat baker T%d" % t, StaffDB.by_tier("baker", t).size(), 3)


# --- GDD 8.1 -------------------------------------------------------------------

const MKT_COST: Array = [300, 1200, 3500, 10000, 30000]
const MKT_PER_DAY: Array = [60, 240, 700, 2000, 6000]
const MKT_BOOST: Array = [0.20, 0.45, 0.75, 1.10, 1.60]
const MKT_RATING: Array = [0.0, 0.08, 0.15, 0.30, 0.50]


func _audit_marketing() -> void:
	print("\n-- Kampanye Pemasaran (GDD 8.1) --")
	_eq("durasi kampanye", MarketingDB.DURATION_DAYS, 5)
	for i in 5:
		var t: int = i + 1
		var e: Dictionary = MarketingDB.entry(t)
		_ok("kampanye T%d ada" % t, not e.is_empty())
		if e.is_empty():
			continue
		_eq("kampanye T%d biaya" % t, e.get("cost"), MKT_COST[i])
		_eq("kampanye T%d per hari" % t, e.get("per_day"), MKT_PER_DAY[i])
		_eq("kampanye T%d boost" % t, e.get("visitor_boost"), MKT_BOOST[i])
		_eq("kampanye T%d rating/hari" % t, e.get("rating_per_day"), MKT_RATING[i])
		_eq("kampanye T%d syarat lokasi" % t, e.get("req_location"), t)
		# Beban rata-rata per hari harus konsisten dengan biaya / 5 hari.
		_eq("kampanye T%d biaya/5" % t, int(e.get("cost")) / 5, MKT_PER_DAY[i])


# --- GDD "Perilaku Konsumen" + 3.6 ---------------------------------------------

const CUSTOMER_IDS: Array = [
	"anak_sekolah", "pekerja_kantoran", "emak_arisan", "sosialita",
	"si_galau", "food_vlogger", "driver_ojol",
]


## Tiga hari pembukaan (OpeningDB): bahan yang disediakan harus PAS sebanyak
## permintaan hari itu.
##
## Ini satu-satunya tabel di proyek ini yang angkanya saling mengunci: permintaan
## ditulis butir per butir, pasokan ditulis sebagai jumlah batch, dan keduanya
## harus bertemu PERSIS. Lebih satu butir, hari itu bisa diselesaikan sambil
## menggosongkan roti — pelajarannya hilang. Kurang satu butir, hari itu mustahil
## diselesaikan sempurna sekalipun pemain tidak berbuat salah.
func _audit_opening() -> void:
	print("\n-- Skenario Tiga Hari Pembukaan --")
	_ok("ada hari terjadwal", OpeningDB.DAYS.size() > 0)

	for day: int in range(OpeningDB.FIRST_DAY, OpeningDB.last_day() + 1):
		var rid: String = OpeningDB.recipe_id(day)
		var rec: Dictionary = RecipeDB.entry(rid)
		_ok("hari %d: resep '%s' ada" % [day, rid], not rec.is_empty())
		if rec.is_empty():
			continue

		# Resepnya wajib resep bawaan: hari pembukaan tidak boleh menuntut
		# pembelian resep lebih dulu.
		_ok("hari %d: '%s' resep starter Tier 1" % [day, rid],
			RecipeDB.starter().has(rid))

		var minta: int = OpeningDB.demand(day)
		var punya: int = OpeningDB.supply(day)
		_eq("hari %d: permintaan == pasokan (%d roti)" % [day, minta], minta, punya)
		_ok("hari %d: permintaan masuk akal untuk Tier 1 (%d roti)" % [day, minta],
			minta > 0 and minta <= LocationDB.display_capacity(1, 1))

		# Gudang Tier 1 harus sanggup menampung jatah sehari.
		var gudang: Dictionary = OpeningDB.pantry_for(day)
		var unit: int = 0
		for k: Variant in gudang:
			unit += int(gudang[k])
		_ok("hari %d: jatah bahan %d unit muat di gudang Tier 1 (%d)"
			% [day, unit, LocationDB.pantry_cap(1)], unit <= LocationDB.pantry_cap(1))

		for e: Variant in OpeningDB.walk_ins(day):
			var w: Dictionary = e
			var arch: String = String(w.get("archetype", ""))
			var db: Dictionary = CustomerDB.entry(arch)
			var n: int = int(w.get("count", 0))
			var jam: float = float(w.get("hour", 0.0))
			_ok("hari %d: arketipe '%s' dikenal" % [day, arch], not db.is_empty())
			if db.is_empty():
				continue
			# Jumlah belanja harus masuk akal untuk arketipe itu, kalau tidak
			# angkanya cuma tempelan yang kebetulan berjumlah pas.
			_ok("hari %d: %s membeli %d roti, dalam rentang %d-%d"
				% [day, arch, n, int(db.get("bulk_min", 1)), int(db.get("bulk_max", 1))],
				n >= int(db.get("bulk_min", 1)) and n <= int(db.get("bulk_max", 1)))
			# Arketipe yang menolak resep Tier 1 tidak boleh dijadwalkan sama
			# sekali: ia akan datang, menolak, lalu pulang marah tanpa bisa dicegah.
			_ok("hari %d: %s mau membeli resep Tier 1" % [day, arch],
				CustomerDB.accepts_recipe_tier(arch, 1))
			_ok("hari %d: %s datang dalam jam buka (%.2f)" % [day, arch, jam],
				jam >= GameConfig.HOUR_OPEN and jam < GameConfig.HOUR_CLOSE)

		for d2: Variant in OpeningDB.deliveries(day):
			var o: Dictionary = d2
			var jam2: float = float(o.get("hour", 0.0))
			_ok("hari %d: pesanan ojol berisi roti (%d)" % [day, int(o.get("count", 0))],
				int(o.get("count", 0)) > 0)
			_ok("hari %d: pesanan ojol masuk dalam jam buka (%.2f)" % [day, jam2],
				jam2 >= GameConfig.HOUR_OPEN and jam2 < GameConfig.HOUR_CLOSE)

		print("  hari %d: %d roti diminta, %d batch %s disediakan"
			% [day, minta, OpeningDB.batches(day), String(rec.get("name", rid))])


func _audit_customers() -> void:
	print("\n-- Pelanggan (GDD Perilaku Konsumen, 3.6) --")
	_eq("jumlah arketipe", CustomerDB.ids().size(), 7)
	for id in CUSTOMER_IDS:
		var e: Dictionary = CustomerDB.entry(id)
		_ok("pelanggan '%s' ada" % id, not e.is_empty())
	# GDD: Emak-Emak Arisan memborong 5-15 roti sekaligus.
	var emak: Dictionary = CustomerDB.entry("emak_arisan")
	if not emak.is_empty():
		_eq("emak_arisan.bulk_min", emak.get("bulk_min"), 5)
		_eq("emak_arisan.bulk_max", emak.get("bulk_max"), 15)
	# GDD: Sosialita hanya mau resep Tier 3 ke atas.
	var sos: Dictionary = CustomerDB.entry("sosialita")
	if not sos.is_empty():
		_eq("sosialita.min_recipe_tier", sos.get("min_recipe_tier"), 3)
	# GDD: Si Galau butuh waktu kasir 2x lipat.
	var galau: Dictionary = CustomerDB.entry("si_galau")
	if not galau.is_empty():
		_eq("si_galau.cashier_time_mult", float(galau.get("cashier_time_mult", 0.0)), 2.0)
	# GDD 3.6: driver ojol punya batas waktu penjemputan.
	var drv: Dictionary = CustomerDB.entry("driver_ojol")
	if not drv.is_empty():
		_ok("driver_ojol.pickup_window > 0", float(drv.get("pickup_window", 0.0)) > 0.0)
	# Pekerja kantoran harus paling tidak sabar dari semua pelanggan fisik.
	var kerja: Dictionary = CustomerDB.entry("pekerja_kantoran")
	var anak: Dictionary = CustomerDB.entry("anak_sekolah")
	if not kerja.is_empty() and not anak.is_empty():
		_ok("pekerja_kantoran lebih tidak sabar dari anak_sekolah",
			float(kerja.get("patience", 0.0)) < float(anak.get("patience", 0.0)))


# --- GDD 10 --------------------------------------------------------------------

func _audit_weather() -> void:
	print("\n-- Cuaca (GDD 10) --")
	_eq("jumlah kondisi cuaca", WeatherDB.ids().size(), 3)
	for id in ["cerah", "hujan", "liburan"]:
		_ok("cuaca '%s' ada" % id, not WeatherDB.entry(id).is_empty())
	var hujan: Dictionary = WeatherDB.entry("hujan")
	if not hujan.is_empty():
		var foot: Vector2 = hujan.get("foot_traffic_mult", Vector2.ZERO)
		var deliv: Vector2 = hujan.get("delivery_mult", Vector2.ZERO)
		# GDD 10.2: foot traffic anjlok 60-80%  -> pengali 0.20 .. 0.40
		_eq("hujan foot min", foot.x, 0.20)
		_eq("hujan foot max", foot.y, 0.40)
		# GDD 10.2: order RotiFood meledak +150% .. +200% -> pengali 2.50 .. 3.00
		_eq("hujan delivery min", deliv.x, 2.50)
		_eq("hujan delivery max", deliv.y, 3.00)
	var cerah: Dictionary = WeatherDB.entry("cerah")
	if not cerah.is_empty():
		_eq("cerah foot netral", cerah.get("foot_traffic_mult"), Vector2(1.0, 1.0))


# --- Konsistensi silang --------------------------------------------------------

func _audit_cross_references() -> void:
	print("\n-- Konsistensi Silang --")
	# Setiap bahan yang dirujuk resep harus ada di IngredientDB.
	for rid in RecipeDB.ids():
		var e: Dictionary = RecipeDB.entry(rid)
		var ings: Dictionary = e.get("ingredients", {})
		_ok("%s punya daftar bahan" % rid, ings.size() > 0)
		for ing_id in ings:
			_ok("%s -> bahan '%s' dikenal" % [rid, ing_id],
				not IngredientDB.entry(ing_id).is_empty())
			_ok("%s -> jumlah '%s' > 0" % [rid, ing_id], int(ings[ing_id]) > 0)
	# Setiap target pelanggan yang dirujuk resep harus arketipe yang dikenal.
	for rid in RecipeDB.ids():
		var e: Dictionary = RecipeDB.entry(rid)
		for cid in e.get("targets", []):
			_ok("%s -> target '%s' dikenal" % [rid, cid], CUSTOMER_IDS.has(cid))
	# Resep Tier 1 harus gratis; resep Tier 2+ harus berbayar (GDD 5.3).
	for rid in RecipeDB.ids():
		var e: Dictionary = RecipeDB.entry(rid)
		if int(e.get("tier")) == 1:
			_eq("%s gratis (tier 1)" % rid, e.get("unlock_price"), 0)
		else:
			_ok("%s berbayar (tier %d)" % [rid, int(e.get("tier"))],
				int(e.get("unlock_price")) > 0)
