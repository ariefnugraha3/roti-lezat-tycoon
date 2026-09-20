extends Node

# GameState (autoload) — penyimpan tunggal seluruh data permainan yang sedang berjalan.
# Semua sistem simulasi membaca dan menulis data lewat kelas ini, lalu mengabarkan
# perubahannya melalui EventBus.
#
# ATURAN PENTING: tidak boleh ada nilai bertipe Color atau Vector2i tersimpan di state,
# karena seluruh isi state wajib aman diserialisasi bolak-balik ke JSON (GDD 12.6).
# Simpan ID/teks/angka saja; warna diambil dari Palette memakai ID tersebut.

# Batas jumlah ledger harian yang disimpan di riwayat.
const HISTORY_MAX: int = 30

# Enam bahan dasar (ARCHITECTURE 2.1) — isi gudang awal permainan baru.
const BASIC_INGREDIENTS: Array[String] = [
	"tepung_terigu",
	"gula_pasir",
	"ragi",
	"telur",
	"mentega",
	"air_garam",
]

# Jumlah tiap bahan dasar yang diberikan saat permainan baru dimulai.
const STARTER_PANTRY_QTY: int = 2

# Pilihan karakter pemain, ditetapkan sekali saat menekan "Main Baru".
const PLAYER_GENDERS: Array[String] = ["pria", "wanita"]
const PLAYER_GENDER_DEFAULT: String = "pria"

# Bobot undian cuaca untuk permainan baru. GDD 10 hanya menyatakan bahwa cuaca
# "cerah" adalah kondisi paling umum dan stabil (GDD 10.1) tanpa mencantumkan angka
# peluang eksplisit; bobot di bawah hanya dipakai untuk mengundi cuaca hari pertama.
# Pergantian cuaca harian selanjutnya menjadi tanggung jawab WeatherSim.
const WEATHER_WEIGHTS: Dictionary = {
	"cerah": 0.60,
	"hujan": 0.30,
	"liburan": 0.10,
}

# Daftar kunci statistik harian beserta tipenya (dipakai saat memuat berkas simpanan).
const STATS_FLOAT_KEYS: Array[String] = [
	"income_store",
	"income_delivery",
	"tips",
	"spent_ingredients",
	"utility",
	"salary",
	"rating_start",
	"rotifood_start",
]
const STATS_INT_KEYS: Array[String] = [
	"customers_total",
	"customers_angry",
	"delivery_done",
	"delivery_cancelled",
	"bread_sold",
	"bread_left",
	"burned",
	"best_recipe_count",
]
const STATS_BOOL_KEYS: Array[String] = [
	"vip_visited",
	"solo_first_day",
]

# --- Data inti -------------------------------------------------------------

var coins: float = GameConfig.STARTING_COINS
var day: int = 1
var location_tier: int = 1
var mixer_tier: int = 1
var oven_tier: int = 1
var display_tier: int = 1
var pantry: Dictionary = {}          # ingredient_id -> int
var unlocked_recipes: Array = []     # String
var recipe_prices: Dictionary = {}   # recipe_id -> float (harga per BUAH)
var display_slots: Array = []        # {recipe_id, count, quality, rack, slot, baked_hour}
var staff: Array = []                # {staff_id, role, tier, on_leave}
var store_rating: float = 3.0
var rotifood_rating: float = 4.0
var campaign: Dictionary = {}        # {} atau {tier, days_left}
var weather: String = "cerah"
var forecast: String = "cerah"
var solo_mode: bool = false
var bailout_count: int = 0
var last_bailout_day: int = 0
var decor: Dictionary = {}
var stats: Dictionary = {}           # statistik hari ini
var history: Array = []              # ledger harian, maks 30
var baker_mode: Dictionary = {}      # staff_id -> {"mode", "recipe_id"}
var player: Dictionary = {"gender": PLAYER_GENDER_DEFAULT}  # karakter yang dimainkan


func _ready() -> void:
	if stats.is_empty():
		reset_daily_stats()


# --- Siklus permainan ------------------------------------------------------

# Mengatur ulang seluruh state ke kondisi hari pertama (GDD 3 & GDD 5.3.1).
func reset_new_game() -> void:
	coins = GameConfig.STARTING_COINS
	day = 1
	location_tier = 1
	mixer_tier = 1
	oven_tier = 1
	display_tier = 1
	store_rating = 3.0
	rotifood_rating = 4.0

	# Resep bawaan Tier 1 sudah terbuka sejak hari pertama (GDD 5.3.1).
	unlocked_recipes = []
	for rid: String in RecipeDB.starter():
		unlocked_recipes.append(rid)

	# Harga jual awal tiap resep = harga sweet spot per buah dari GDD.
	recipe_prices = {}
	for rid2: String in RecipeDB.ids():
		recipe_prices[rid2] = RecipeDB.unit_price_default(rid2)

	# Gudang awal: sedikit bahan dasar agar pemain bisa langsung berproduksi.
	pantry = {}
	for ing: String in BASIC_INGREDIENTS:
		pantry[ing] = STARTER_PANTRY_QTY

	display_slots = []
	staff = []
	campaign = {}
	decor = {}
	history = []
	baker_mode = {}
	# `player` sengaja TIDAK dikosongkan: pilihan karakter dibuat di menu SEBELUM
	# permainan baru dirakit, dan Main menuliskannya lewat set_player_gender().
	solo_mode = false
	bailout_count = 0
	last_bailout_day = 0

	weather = _roll_weather()
	forecast = _roll_weather()

	reset_daily_stats()

	EventBus.coins_changed.emit(coins)
	EventBus.pantry_changed.emit()
	EventBus.display_changed.emit()
	EventBus.rating_changed.emit(store_rating, rotifood_rating)
	EventBus.weather_changed.emit(weather, forecast)


# Mengosongkan statistik harian (kunci wajib ARCHITECTURE 6, isian laporan GDD 11.1).
func reset_daily_stats() -> void:
	stats = {
		"income_store": 0.0,
		"income_delivery": 0.0,
		"tips": 0.0,
		"spent_ingredients": 0.0,
		"utility": 0.0,
		"salary": 0.0,
		"customers_total": 0,
		"customers_angry": 0,
		"delivery_done": 0,
		"delivery_cancelled": 0,
		"bread_sold": 0,
		"bread_left": 0,
		"burned": 0,
		"best_recipe": "",
		"best_recipe_count": 0,
		"vip_visited": false,
		"rating_start": store_rating,
		"rotifood_start": rotifood_rating,
		"solo_first_day": false,
	}


# --- Karakter pemain -------------------------------------------------------

# Jenis karakter yang sedang dimainkan; selalu salah satu PLAYER_GENDERS.
func player_gender() -> String:
	var g: String = String(player.get("gender", PLAYER_GENDER_DEFAULT))
	return g if PLAYER_GENDERS.has(g) else PLAYER_GENDER_DEFAULT


# Menetapkan karakter pemain. Nilai asing jatuh ke bawaan, bukan ditolak diam-diam,
# supaya berkas simpanan lama yang belum punya kunci ini tetap bisa dibuka (GDD 12.6).
func set_player_gender(g: String) -> void:
	player = {"gender": g if PLAYER_GENDERS.has(g) else PLAYER_GENDER_DEFAULT}


# --- Uang ------------------------------------------------------------------

func add_coins(v: float, reason: String) -> void:
	if v == 0.0:
		return
	coins += v
	if coins < 0.0:
		coins = 0.0
	if not reason.is_empty():
		print_verbose("[koin] %s (%s)" % [GameConfig.kr(v), reason])
	EventBus.coins_changed.emit(coins)


func spend_coins(v: float, reason: String) -> bool:
	if v <= 0.0:
		return true
	if coins < v:
		return false
	coins -= v
	if not reason.is_empty():
		print_verbose("[koin] -%s (%s)" % [GameConfig.kr(v), reason])
	EventBus.coins_changed.emit(coins)
	return true


# --- Gudang bahan baku (GDD 5.2.2) -----------------------------------------

func pantry_total() -> int:
	var total: int = 0
	for k: Variant in pantry:
		total += int(pantry[k])
	return total


func pantry_capacity() -> int:
	var loc: Dictionary = LocationDB.entry(location_tier)
	return int(loc.get("pantry_cap", 0))


# Menambah bahan ke gudang sebatas kapasitas; mengembalikan jumlah yang benar-benar masuk.
func pantry_add(ing_id: String, n: int) -> int:
	if ing_id.is_empty() or n <= 0:
		return 0
	var room: int = pantry_capacity() - pantry_total()
	if room <= 0:
		return 0
	var added: int = mini(n, room)
	pantry[ing_id] = int(pantry.get(ing_id, 0)) + added
	EventBus.pantry_changed.emit()
	return added


# Mengambil beberapa bahan sekaligus secara atomik: seluruh bahan tersedia lalu
# dipotong, atau tidak ada satu pun yang dipotong.
func pantry_take(costs: Dictionary) -> bool:
	if costs.is_empty():
		return true
	for k: Variant in costs:
		var need: int = int(costs[k])
		if need <= 0:
			continue
		if int(pantry.get(String(k), 0)) < need:
			return false
	for k2: Variant in costs:
		var need2: int = int(costs[k2])
		if need2 <= 0:
			continue
		var key: String = String(k2)
		var left: int = int(pantry.get(key, 0)) - need2
		if left > 0:
			pantry[key] = left
		else:
			pantry.erase(key)
	EventBus.pantry_changed.emit()
	return true


# Memeriksa apakah stok gudang cukup untuk satu batch resep.
func can_afford_recipe(recipe_id: String) -> bool:
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return false
	var need: Dictionary = rec.get("ingredients", {})
	for k: Variant in need:
		if int(pantry.get(String(k), 0)) < int(need[k]):
			return false
	return true


# --- Rak display (GDD 5.1 & GDD 6) -----------------------------------------

func display_total() -> int:
	var total: int = 0
	for e: Variant in display_slots:
		var s: Dictionary = e
		total += int(s.get("count", 0))
	return total


func display_capacity() -> int:
	return LocationDB.display_capacity(location_tier, display_tier)


# Jumlah slot fisik seluruh rak = jumlah rak x GameConfig.SLOTS_PER_RACK.
func display_slot_count() -> int:
	var loc: Dictionary = LocationDB.entry(location_tier)
	return int(loc.get("rack_slots", 0)) * GameConfig.SLOTS_PER_RACK


# Daya tampung satu slot = kapasitas satu rak dibagi jumlah slot per rak.
# CATATAN: hasil bagi dibulatkan ke bawah, sehingga slot_cap x jumlah slot bisa sedikit
# di bawah display_capacity() (mis. Tier 1: 50/6 = 8 -> 6 slot x 8 = 48 dari 50 roti).
# Kedua batas tetap dihormati; yang paling kecil yang berlaku.
func display_slot_cap() -> int:
	var per_rack: int = EquipmentDB.rack_capacity(display_tier)
	return maxi(1, floori(float(per_rack) / float(GameConfig.SLOTS_PER_RACK)))


# Menaruh roti ke rak; mengembalikan jumlah yang benar-benar tertampung.
func display_add(recipe_id: String, count: int, quality: String, hour: float) -> int:
	if recipe_id.is_empty() or count <= 0:
		return 0
	var room_total: int = display_capacity() - display_total()
	if room_total <= 0:
		return 0

	var remaining: int = mini(count, room_total)
	var slot_cap: int = display_slot_cap()
	var slot_count: int = display_slot_count()
	var placed: int = 0

	var occupied: Dictionary = {}
	for e: Variant in display_slots:
		var s: Dictionary = e
		occupied[_slot_index(s)] = s

	# 1) Tumpuk ke slot yang sudah berisi resep dan kualitas sama, mulai dari depan.
	for gi: int in range(slot_count):
		if remaining <= 0:
			break
		if not occupied.has(gi):
			continue
		var cur: Dictionary = occupied[gi]
		if String(cur.get("recipe_id", "")) != recipe_id:
			continue
		if String(cur.get("quality", "")) != quality:
			continue
		var space: int = slot_cap - int(cur.get("count", 0))
		if space <= 0:
			continue
		var n: int = mini(space, remaining)
		cur["count"] = int(cur.get("count", 0)) + n
		# Pakai jam panggang paling awal agar tumpukan lama tidak "diremajakan" roti baru.
		cur["baked_hour"] = minf(float(cur.get("baked_hour", hour)), hour)
		remaining -= n
		placed += n

	# 2) Isi slot kosong berikutnya dari depan; satu resep untuk satu slot.
	for gi2: int in range(slot_count):
		if remaining <= 0:
			break
		if occupied.has(gi2):
			continue
		var n2: int = mini(slot_cap, remaining)
		var entry: Dictionary = {
			"recipe_id": recipe_id,
			"count": n2,
			"quality": quality,
			"rack": floori(float(gi2) / float(GameConfig.SLOTS_PER_RACK)),
			"slot": gi2 % GameConfig.SLOTS_PER_RACK,
			"baked_hour": hour,
		}
		display_slots.append(entry)
		occupied[gi2] = entry
		remaining -= n2
		placed += n2

	if placed > 0:
		display_slots.sort_custom(_cmp_slots)
		EventBus.display_changed.emit()
	return placed


# Menaruh roti ke SATU slot rak yang dipilih pemain; mengembalikan jumlah yang
# benar-benar tertampung.
#
# Berbeda dari display_add() yang mencari slot sendiri, fungsi ini tidak pernah
# meluber ke slot lain: pemain sudah memilih petaknya, dan diam-diam memindahkan
# roti ke petak sebelah akan membuat tata letak rak yang ia susun tidak berarti
# (GDD 2: posisi penempatan mempengaruhi penjualan).
#
# Slot yang sudah berisi resep/kualitas berbeda ditolak (mengembalikan 0).
func display_add_at(recipe_id: String, count: int, quality: String, hour: float,
		global_slot: int) -> int:
	if recipe_id.is_empty() or count <= 0:
		return 0
	if global_slot < 0 or global_slot >= display_slot_count():
		return 0
	var room_total: int = display_capacity() - display_total()
	if room_total <= 0:
		return 0

	var cur: Dictionary = display_entry_at(global_slot)
	var slot_cap: int = display_slot_cap()
	var space: int = slot_cap
	if not cur.is_empty():
		if String(cur.get("recipe_id", "")) != recipe_id:
			return 0
		if String(cur.get("quality", "")) != quality:
			return 0
		space = slot_cap - int(cur.get("count", 0))
	if space <= 0:
		return 0

	var placed: int = mini(mini(count, space), room_total)
	if placed <= 0:
		return 0

	if cur.is_empty():
		display_slots.append({
			"recipe_id": recipe_id,
			"count": placed,
			"quality": quality,
			"rack": floori(float(global_slot) / float(GameConfig.SLOTS_PER_RACK)),
			"slot": global_slot % GameConfig.SLOTS_PER_RACK,
			"baked_hour": hour,
		})
	else:
		cur["count"] = int(cur.get("count", 0)) + placed
		cur["baked_hour"] = minf(float(cur.get("baked_hour", hour)), hour)

	display_slots.sort_custom(_cmp_slots)
	EventBus.display_changed.emit()
	return placed


# Isi satu slot rak menurut indeks globalnya; {} bila slot kosong.
func display_entry_at(global_slot: int) -> Dictionary:
	for e: Variant in display_slots:
		var s: Dictionary = e
		if _slot_index(s) == global_slot and int(s.get("count", 0)) > 0:
			return s
	return {}


# Berapa roti lagi yang muat di satu slot rak untuk resep & kualitas tertentu.
# 0 berarti slot itu penuh atau sudah dipakai resep/kualitas lain.
func display_room_at(global_slot: int, recipe_id: String, quality: String) -> int:
	if global_slot < 0 or global_slot >= display_slot_count():
		return 0
	var sisa_rak: int = display_capacity() - display_total()
	if sisa_rak <= 0:
		return 0
	var cur: Dictionary = display_entry_at(global_slot)
	if cur.is_empty():
		return mini(display_slot_cap(), sisa_rak)
	if String(cur.get("recipe_id", "")) != recipe_id:
		return 0
	if String(cur.get("quality", "")) != quality:
		return 0
	return mini(maxi(0, display_slot_cap() - int(cur.get("count", 0))), sisa_rak)


# Mengambil roti dari rak mulai dari slot paling depan (indeks slot menaik);
# mengembalikan jumlah yang benar-benar terambil.
func display_take(recipe_id: String, count: int) -> int:
	if recipe_id.is_empty() or count <= 0:
		return 0
	display_slots.sort_custom(_cmp_slots)
	var remaining: int = count
	var taken: int = 0
	var keep: Array = []
	for e: Variant in display_slots:
		var cur: Dictionary = e
		if remaining > 0 and String(cur.get("recipe_id", "")) == recipe_id:
			var n: int = mini(int(cur.get("count", 0)), remaining)
			cur["count"] = int(cur.get("count", 0)) - n
			remaining -= n
			taken += n
		if int(cur.get("count", 0)) > 0:
			keep.append(cur)
	display_slots = keep
	if taken > 0:
		EventBus.display_changed.emit()
	return taken


# --- Karyawan (GDD 3.1–3.4) ------------------------------------------------

# Karyawan yang sedang bekerja (tidak sedang diliburkan) untuk satu peran.
func active_staff(role: String) -> Array:
	var out: Array = []
	for e: Variant in staff:
		var s: Dictionary = e
		if String(s.get("role", "")) != role:
			continue
		if bool(s.get("on_leave", false)):
			continue
		out.append(s)
	return out


# Karyawan aktif bertier tertinggi untuk satu peran; {} bila tidak ada.
func best_staff(role: String) -> Dictionary:
	var best: Dictionary = {}
	var best_tier: int = -1
	for e: Variant in active_staff(role):
		var s: Dictionary = e
		var t: int = int(s.get("tier", 0))
		if t > best_tier:
			best_tier = t
			best = s
	return best


# --- Resep -----------------------------------------------------------------

# Harga jual per buah yang diatur pemain; bila belum diatur memakai sweet spot GDD.
func recipe_price(recipe_id: String) -> float:
	if recipe_prices.has(recipe_id):
		return float(recipe_prices[recipe_id])
	return RecipeDB.unit_price_default(recipe_id)


# Resep siap diproduksi bila sudah dibuka, alat memenuhi syarat minimum, dan
# (untuk resep Tier 3 ke atas) ada baker aktif dengan tier minimum yang diminta.
func is_recipe_available(recipe_id: String) -> bool:
	if not unlocked_recipes.has(recipe_id):
		return false
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	if rec.is_empty():
		return false
	if mixer_tier < int(rec.get("min_mixer", 1)):
		return false
	if oven_tier < int(rec.get("min_oven", 1)):
		return false
	var need_baker: int = int(rec.get("min_baker_tier", 0))
	if need_baker <= 0:
		return true
	for e: Variant in active_staff("baker"):
		var s: Dictionary = e
		if int(s.get("tier", 0)) >= need_baker:
			return true
	return false


# --- Serialisasi (GDD 12.6) ------------------------------------------------

func to_dict() -> Dictionary:
	_trim_history()
	return {
		"coins": coins,
		"day": day,
		"location_tier": location_tier,
		"mixer_tier": mixer_tier,
		"oven_tier": oven_tier,
		"display_tier": display_tier,
		"pantry": _json_safe(pantry),
		"unlocked_recipes": _json_safe(unlocked_recipes),
		"recipe_prices": _json_safe(recipe_prices),
		"display_slots": _json_safe(display_slots),
		"staff": _json_safe(staff),
		"store_rating": store_rating,
		"rotifood_rating": rotifood_rating,
		"campaign": _json_safe(campaign),
		"weather": weather,
		"forecast": forecast,
		"solo_mode": solo_mode,
		"bailout_count": bailout_count,
		"last_bailout_day": last_bailout_day,
		"decor": _json_safe(decor),
		"stats": _json_safe(stats),
		"history": _json_safe(history),
		"baker_mode": _json_safe(baker_mode),
		"player": _json_safe(player),
	}


func from_dict(d: Dictionary) -> void:
	if d.is_empty():
		return

	coins = maxf(0.0, _as_float(d.get("coins", GameConfig.STARTING_COINS), GameConfig.STARTING_COINS))
	day = maxi(1, _as_int(d.get("day", 1), 1))
	location_tier = clampi(_as_int(d.get("location_tier", 1), 1), 1, 5)
	mixer_tier = clampi(_as_int(d.get("mixer_tier", 1), 1), 1, 5)
	oven_tier = clampi(_as_int(d.get("oven_tier", 1), 1), 1, 5)
	display_tier = clampi(_as_int(d.get("display_tier", 1), 1), 1, 5)
	store_rating = clampf(_as_float(d.get("store_rating", 3.0), 3.0), 0.0, 5.0)
	rotifood_rating = clampf(_as_float(d.get("rotifood_rating", 4.0), 4.0), 1.0, 5.0)

	# Gudang bahan.
	pantry = {}
	var raw_pantry: Variant = d.get("pantry", {})
	if typeof(raw_pantry) == TYPE_DICTIONARY:
		var pd: Dictionary = raw_pantry
		for k: Variant in pd:
			var ing: String = String(k)
			if IngredientDB.entry(ing).is_empty():
				continue
			var qty: int = _as_int(pd[k], 0)
			if qty > 0:
				pantry[ing] = qty

	# Resep yang sudah terbuka.
	unlocked_recipes = []
	var raw_unlocked: Variant = d.get("unlocked_recipes", [])
	if typeof(raw_unlocked) == TYPE_ARRAY:
		var ua: Array = raw_unlocked
		for v: Variant in ua:
			var rid: String = String(v)
			if rid.is_empty() or RecipeDB.entry(rid).is_empty():
				continue
			if not unlocked_recipes.has(rid):
				unlocked_recipes.append(rid)

	# Harga jual per resep; resep yang belum tercatat memakai sweet spot GDD.
	recipe_prices = {}
	for rid2: String in RecipeDB.ids():
		recipe_prices[rid2] = RecipeDB.unit_price_default(rid2)
	var raw_prices: Variant = d.get("recipe_prices", {})
	if typeof(raw_prices) == TYPE_DICTIONARY:
		var rp: Dictionary = raw_prices
		for k2: Variant in rp:
			var rid3: String = String(k2)
			if RecipeDB.entry(rid3).is_empty():
				continue
			recipe_prices[rid3] = maxf(0.0, _as_float(rp[k2], 0.0))

	# Isi rak display.
	display_slots = []
	var raw_slots: Variant = d.get("display_slots", [])
	if typeof(raw_slots) == TYPE_ARRAY:
		var sa: Array = raw_slots
		for v2: Variant in sa:
			if typeof(v2) != TYPE_DICTIONARY:
				continue
			var s: Dictionary = v2
			var rid4: String = String(s.get("recipe_id", ""))
			if rid4.is_empty() or RecipeDB.entry(rid4).is_empty():
				continue
			var cnt: int = _as_int(s.get("count", 0), 0)
			if cnt <= 0:
				continue
			display_slots.append({
				"recipe_id": rid4,
				"count": cnt,
				"quality": String(s.get("quality", "normal")),
				"rack": maxi(0, _as_int(s.get("rack", 0), 0)),
				"slot": maxi(0, _as_int(s.get("slot", 0), 0)),
				"baked_hour": _as_float(s.get("baked_hour", GameConfig.HOUR_OPEN), GameConfig.HOUR_OPEN),
			})
	_normalize_display()

	# Karyawan.
	staff = []
	var raw_staff: Variant = d.get("staff", [])
	if typeof(raw_staff) == TYPE_ARRAY:
		var fa: Array = raw_staff
		for v3: Variant in fa:
			if typeof(v3) != TYPE_DICTIONARY:
				continue
			var st: Dictionary = v3
			var sid: String = String(st.get("staff_id", ""))
			var db: Dictionary = StaffDB.entry(sid)
			if db.is_empty():
				continue
			staff.append({
				"staff_id": sid,
				"role": String(st.get("role", db.get("role", ""))),
				"tier": clampi(_as_int(st.get("tier", db.get("tier", 1)), 1), 1, 5),
				"on_leave": _as_bool(st.get("on_leave", false), false),
			})

	# Kampanye pemasaran yang masih berjalan.
	campaign = {}
	var raw_campaign: Variant = d.get("campaign", {})
	if typeof(raw_campaign) == TYPE_DICTIONARY:
		var c: Dictionary = raw_campaign
		var c_tier: int = clampi(_as_int(c.get("tier", 0), 0), 0, 5)
		var c_days: int = maxi(0, _as_int(c.get("days_left", 0), 0))
		if c_tier > 0 and c_days > 0:
			campaign = {"tier": c_tier, "days_left": c_days}

	# Karakter pemain. Simpanan lama tidak punya kunci ini; ia jatuh ke bawaan
	# alih-alih menggagalkan pemuatan (GDD 12.6).
	var raw_player: Variant = d.get("player", {})
	var gender: String = PLAYER_GENDER_DEFAULT
	if typeof(raw_player) == TYPE_DICTIONARY:
		gender = String((raw_player as Dictionary).get("gender", PLAYER_GENDER_DEFAULT))
	set_player_gender(gender)

	weather = _valid_weather(String(d.get("weather", "cerah")))
	forecast = _valid_weather(String(d.get("forecast", "cerah")))
	solo_mode = _as_bool(d.get("solo_mode", false), false)
	bailout_count = maxi(0, _as_int(d.get("bailout_count", 0), 0))
	last_bailout_day = maxi(0, _as_int(d.get("last_bailout_day", 0), 0))

	decor = {}
	var raw_decor: Variant = d.get("decor", {})
	if typeof(raw_decor) == TYPE_DICTIONARY:
		var safe_decor: Variant = _json_safe(raw_decor)
		decor = safe_decor

	# Statistik harian: mulai dari set lengkap, lalu timpa dengan nilai tersimpan.
	reset_daily_stats()
	var raw_stats: Variant = d.get("stats", {})
	if typeof(raw_stats) == TYPE_DICTIONARY:
		var sd: Dictionary = raw_stats
		for key: String in STATS_FLOAT_KEYS:
			if sd.has(key):
				stats[key] = _as_float(sd[key], float(stats[key]))
		for key2: String in STATS_INT_KEYS:
			if sd.has(key2):
				stats[key2] = _as_int(sd[key2], int(stats[key2]))
		for key3: String in STATS_BOOL_KEYS:
			if sd.has(key3):
				stats[key3] = _as_bool(sd[key3], bool(stats[key3]))
		if sd.has("best_recipe"):
			stats["best_recipe"] = String(sd["best_recipe"])

	# Riwayat ledger harian (maksimal 30 hari terakhir).
	history = []
	var raw_history: Variant = d.get("history", [])
	if typeof(raw_history) == TYPE_ARRAY:
		var ha: Array = raw_history
		for v4: Variant in ha:
			if typeof(v4) == TYPE_DICTIONARY:
				history.append(_json_safe(v4))
	_trim_history()

	# Mode kerja tiap baker.
	baker_mode = {}
	var raw_modes: Variant = d.get("baker_mode", {})
	if typeof(raw_modes) == TYPE_DICTIONARY:
		var md: Dictionary = raw_modes
		for k3: Variant in md:
			if typeof(md[k3]) != TYPE_DICTIONARY:
				continue
			var m: Dictionary = md[k3]
			var mode_name: String = String(m.get("mode", "auto_replenish"))
			if mode_name != "auto_replenish" and mode_name != "target":
				mode_name = "auto_replenish"
			baker_mode[String(k3)] = {
				"mode": mode_name,
				"recipe_id": String(m.get("recipe_id", "")),
			}

	EventBus.coins_changed.emit(coins)
	EventBus.pantry_changed.emit()
	EventBus.display_changed.emit()
	EventBus.rating_changed.emit(store_rating, rotifood_rating)
	EventBus.weather_changed.emit(weather, forecast)


# --- Pembantu internal -----------------------------------------------------

func _slot_index(e: Dictionary) -> int:
	return int(e.get("rack", 0)) * GameConfig.SLOTS_PER_RACK + int(e.get("slot", 0))


func _cmp_slots(a: Dictionary, b: Dictionary) -> bool:
	return _slot_index(a) < _slot_index(b)


# Merapikan isi rak setelah dimuat dari berkas simpanan: buang slot ganda atau slot
# di luar jangkauan, lalu potong tumpukan yang melebihi daya tampung slot maupun rak.
func _normalize_display() -> void:
	var slot_count: int = display_slot_count()
	var slot_cap: int = display_slot_cap()
	var cap_total: int = display_capacity()
	display_slots.sort_custom(_cmp_slots)

	var used: Dictionary = {}
	var kept: Array = []
	var total: int = 0
	for e: Variant in display_slots:
		var s: Dictionary = e
		var gi: int = _slot_index(s)
		if gi < 0 or gi >= slot_count or used.has(gi):
			continue
		var n: int = mini(int(s.get("count", 0)), slot_cap)
		n = mini(n, maxi(0, cap_total - total))
		if n <= 0:
			continue
		s["count"] = n
		used[gi] = true
		total += n
		kept.append(s)
	display_slots = kept


func _trim_history() -> void:
	if history.size() > HISTORY_MAX:
		history = history.slice(history.size() - HISTORY_MAX, history.size())


func _valid_weather(id: String) -> String:
	if WeatherDB.entry(id).is_empty():
		return "cerah"
	return id


# Mengundi cuaca memakai GameConfig.rng (dilarang memakai randf() global).
func _roll_weather() -> String:
	var total: float = 0.0
	for k: Variant in WEATHER_WEIGHTS:
		total += float(WEATHER_WEIGHTS[k])
	if total <= 0.0:
		return "cerah"
	var pick: float = GameConfig.rng.randf() * total
	for k2: Variant in WEATHER_WEIGHTS:
		pick -= float(WEATHER_WEIGHTS[k2])
		if pick <= 0.0:
			return String(k2)
	return "cerah"


# Menyalin nilai ke bentuk yang dijamin aman untuk JSON.
func _json_safe(value: Variant) -> Variant:
	var t: int = typeof(value)
	if t == TYPE_DICTIONARY:
		var src: Dictionary = value
		var out: Dictionary = {}
		for k: Variant in src:
			out[String(k)] = _json_safe(src[k])
		return out
	if t == TYPE_ARRAY:
		var src_arr: Array = value
		var arr: Array = []
		for v: Variant in src_arr:
			arr.append(_json_safe(v))
		return arr
	if t == TYPE_NIL or t == TYPE_BOOL or t == TYPE_INT or t == TYPE_FLOAT or t == TYPE_STRING:
		return value
	if t == TYPE_STRING_NAME:
		return String(value)
	# Tipe non-JSON (Color, Vector2i, dan sejenisnya) seharusnya tidak pernah masuk state.
	# Bila terlanjur ada, simpan bentuk teksnya agar berkas simpanan tetap sah.
	push_warning("State memuat tipe non-JSON (%d); disimpan sebagai teks." % t)
	return var_to_str(value)


func _as_int(value: Variant, fallback: int) -> int:
	var t: int = typeof(value)
	if t == TYPE_INT:
		return int(value)
	if t == TYPE_FLOAT:
		return int(roundf(float(value)))
	if t == TYPE_BOOL:
		return 1 if bool(value) else 0
	if t == TYPE_STRING:
		var s: String = value
		if s.is_valid_int():
			return s.to_int()
	return fallback


func _as_float(value: Variant, fallback: float) -> float:
	var t: int = typeof(value)
	if t == TYPE_FLOAT or t == TYPE_INT:
		return float(value)
	if t == TYPE_BOOL:
		return 1.0 if bool(value) else 0.0
	if t == TYPE_STRING:
		var s: String = value
		if s.is_valid_float():
			return s.to_float()
	return fallback


func _as_bool(value: Variant, fallback: bool) -> bool:
	var t: int = typeof(value)
	if t == TYPE_BOOL:
		return bool(value)
	if t == TYPE_INT or t == TYPE_FLOAT:
		return float(value) != 0.0
	if t == TYPE_STRING:
		var s: String = value
		return s.to_lower() == "true"
	return fallback
