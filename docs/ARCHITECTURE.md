# Roti Lezat Tycoon — Kontrak Arsitektur (SINGLE SOURCE OF TRUTH)

Semua kode WAJIB mengikuti dokumen ini persis. Sumber angka/balans adalah
`docs/gdd-roti-lezaat-tycoon.md` (GDD). Dokumen ini hanya menetapkan **struktur, ID, dan API**.

## 0. Aturan GDScript (Godot 4.7.2)

- GDScript 2.0. Baris pertama: `class_name X` (bila ada) lalu `extends Y`.
- Gunakan **static typing**: `var x: float = 0.0`, `func f(a: int) -> String:`.
- Signal: `signal foo(a: int)`; emit `foo.emit(1)`; connect `obj.foo.connect(_on_foo)`.
- `await get_tree().create_timer(1.0).timeout` — TIDAK ADA `yield`.
- `Array[String]` boleh. Untuk data yang di-serialize ke JSON pakai `Array`/`Dictionary` polos.
- Jangan pakai `@tool`. Jangan `preload` script yang sudah punya `class_name` — panggil nama kelasnya.
- Jangan `randf()`/`randi()` global — gunakan `GameConfig.rng`.
- **DILARANG** aset eksternal: `.png .jpg .jpeg .gltf .glb .fbx .obj .ogg .wav .mp3 .ttf`
  (`icon.svg` yang sudah ada adalah satu-satunya pengecualian).
  Semua visual = mesh primitif / `SurfaceTool` / `_draw()`. Semua audio = PCM `AudioStreamWAV` hasil hitung.
  Font = bawaan Godot (`ThemeDB.fallback_font`), hanya diatur ukuran/spasi.
- Komentar & string UI dalam **Bahasa Indonesia**. Nama variabel/fungsi dalam bahasa Inggris.
- Mata uang **KR**. Format `1.234 KR` via `GameConfig.kr(v)`.
- Satu `class_name` per file. Nama file `snake_case.gd`.

## 1. Struktur File & Kepemilikan

```
scripts/core/game_config.gd          GameConfig   (autoload)
scripts/core/palette.gd              Palette      (autoload)
scripts/core/event_bus.gd            EventBus     (autoload)
scripts/core/game_state.gd           GameState    (autoload)
scripts/core/save_manager.gd         SaveManager  (autoload)
scripts/data/ingredient_db.gd        class_name IngredientDB
scripts/data/recipe_db.gd            class_name RecipeDB
scripts/data/equipment_db.gd         class_name EquipmentDB
scripts/data/location_db.gd          class_name LocationDB
scripts/data/staff_db.gd             class_name StaffDB
scripts/data/marketing_db.gd         class_name MarketingDB
scripts/data/customer_db.gd          class_name CustomerDB
scripts/data/weather_db.gd           class_name WeatherDB
scripts/data/dialog_db.gd            class_name DialogDB
scripts/data/opening_db.gd           class_name OpeningDB
scripts/audio/synth.gd               class_name Synth
scripts/audio/audio_bus.gd           AudioBus     (autoload)
scripts/procgen/mesh_factory.gd      class_name ProceduralMeshFactory
scripts/procgen/bread_factory.gd     class_name BreadFactory
scripts/procgen/equipment_factory.gd class_name EquipmentFactory
scripts/procgen/character_factory.gd class_name CharacterFactory
scripts/procgen/anim_system.gd       class_name ProceduralAnimationSystem
scripts/procgen/ui_factory.gd        class_name ProceduralUIFactory
scripts/procgen/icon_canvas.gd       class_name IconCanvas
scripts/procgen/fx.gd                class_name FX
scripts/sim/day_cycle.gd             class_name DayCycle
scripts/sim/production.gd            class_name ProductionSystem
scripts/sim/player_task.gd           class_name PlayerTaskSystem
scripts/sim/customer_sim.gd          class_name CustomerSim
scripts/sim/delivery_sim.gd          class_name DeliverySim
scripts/sim/staff_sim.gd             class_name StaffSim
scripts/sim/economy.gd               class_name EconomySystem
scripts/sim/reputation.gd            class_name ReputationSystem
scripts/sim/weather_sim.gd           class_name WeatherSim
scripts/sim/marketing_sim.gd         class_name MarketingSim
scripts/sim/bailout.gd               class_name BailoutSystem
scripts/world/shop_world.gd          class_name ShopWorld
scripts/world/actor_base.gd          class_name ActorBase
scripts/world/customer_actor.gd      class_name CustomerActor
scripts/world/staff_actor.gd         class_name StaffActor
scripts/world/driver_actor.gd        class_name DriverActor
scripts/world/player_actor.gd        class_name PlayerActor
scripts/world/station_marker.gd      class_name StationMarker
scripts/ui/screen_router.gd          ScreenRouter (autoload)
scripts/ui/hud.gd                    class_name HUD
scripts/ui/main_menu.gd              class_name MainMenu
scripts/ui/market_screen.gd          class_name MarketScreen
scripts/ui/recipe_book_screen.gd     class_name RecipeBookScreen
scripts/ui/staff_screen.gd           class_name StaffScreen
scripts/ui/marketing_screen.gd       class_name MarketingScreen
scripts/ui/customer_order_screen.gd  class_name CustomerOrderScreen
scripts/ui/delivery_order_screen.gd  class_name DeliveryOrderScreen
scripts/ui/daily_summary_screen.gd   class_name DailySummaryScreen
scripts/ui/decoration_screen.gd      class_name DecorationScreen
scripts/ui/bailout_cutscene.gd       class_name BailoutCutscene
scripts/main.gd                      class_name Main
scenes/main.tscn                     root Node "Main" + script main.gd
tools/validate.gd                    headless: load semua script
tools/sim_test.gd                    headless: simulasi 3 hari + assert
```

## 2. ID Kanonik (JANGAN mengarang ID lain)

### 2.1 Ingredient ID (18)
Dasar: `tepung_terigu`, `gula_pasir`, `ragi`, `telur`, `mentega`, `air_garam`
Isian: `cokelat`, `keju`, `selai`, `susu`, `sosis`, `kayu_manis`
Premium: `whole_wheat`, `butter_organik`, `almond`, `cream_cheese`, `matcha`, `truffle`

### 2.2 Recipe ID (23)
T1: `roti_tawar_polos`, `donat_gula`, `roti_goreng_polos`
T2: `roti_cokelat`, `roti_sosis_gulung`, `roti_keju_manis`, `donat_selai_stroberi`, `baguette_klasik`
T3: `croissant_klasik`, `cinnamon_roll`, `pain_au_chocolat`, `danish_cheese_pastry`, `roti_sobek_susu`
T4: `croissant_artisan_almond`, `sourdough_whole_wheat`, `brioche_gourmet`, `matcha_sweet_brioche`, `basque_burnt_cheese_bun`
T5: `matcha_mille_crepes`, `truffle_mushroom_bun`, `almond_croissant_mewah`, `premium_cream_cheese_danish`, `roti_emas_artisan`

### 2.3 Staff ID (30)
Kasir: `budi`, `sari`, `dimas`, `nadia`, `rian`, `lili`, `maya`, `reza`, `dewi`, `hendra`, `citra`, `kenji`, `grace`, `tejo`, `luna`
Baker: `joko`, `ani`, `bagus`, `fajar`, `rina`, `doni`, `aris`, `tari`, `gilang`, `sophie`, `danu`, `aoi`, `pierre`, `mawar`, `alistair`

### 2.4 Customer ID (7)
`anak_sekolah`, `pekerja_kantoran`, `emak_arisan`, `sosialita`, `si_galau`, `food_vlogger`, `driver_ojol`

### 2.5 Enum string
- Cuaca: `cerah`, `hujan`, `liburan`
- Fase hari: `prep`, `sell`, `close`
- Kualitas roti: `mentah`, `prima`, `normal`, `dingin`, `hampir_gosong`, `gosong`
- Peran staf: `kasir`, `baker`
- Jenis alat: `mixer`, `oven`, `display`

## 3. Kontrak Data Layer

Setiap DB: `extends RefCounted` + `class_name`, isi `const` Dictionary + static func.
WAJIB ada `static func entry(id) -> Dictionary` (kembalikan `{}` bila tidak ada) dan
`static func ids() -> Array[String]`. **Namanya `entry()`, BUKAN `get()`** (bentrok `Object.get`).

### IngredientDB
`entry(id) -> {id, name, unit, price, role, used_in, category}`
- `category`: `"dasar"` | `"isian"` | `"premium"`. `price`: int KR.
- `static func price(id: String) -> int`
- `static func by_category(cat: String) -> Array[String]`

### RecipeDB
```
entry(id) -> {
  id, name, tier,
  ingredients: Dictionary,   # ingredient_id -> int qty
  modal: int,                # "Modal Bahan (KR)" PERSIS dari tabel GDD
  batch_price: int,          # "Harga Jual Sweet Spot (KR)" PERSIS dari GDD (harga SATU BATCH)
  profit: int,               # "Profit Bersih (KR)" PERSIS dari GDD (= batch_price - modal)
  time_sec: float,           # "Waktu Produksi" tabel GDD — TIDAK dipakai simulasi:
                             # durasi nyata diambil dari EquipmentDB per tier alat
                             # (lihat Buku Resep: ia menampilkan waktu alat, bukan kolom ini)
  yield_count: int,          # "Hasil per Batch"
  unlock_price: int,         # "Harga Beli Resep" (0 untuk Tier 1)
  targets: Array,            # customer id
  steps: Array,              # langkah produksi (GDD 5.3.x)
  min_mixer: int,            # = tier resep
  min_oven: int,             # = tier resep
  min_baker_tier: int        # 0 untuk T1/T2, 3 untuk T3, 4 untuk T4, 5 untuk T5
}
```
- `static func unit_price_default(id) -> float` = `float(batch_price) / yield_count`
- `static func sweet_spot_range(id) -> Vector2` = `Vector2(u*0.85, u*1.25)` dengan `u = unit_price_default`
- `static func by_tier(t: int) -> Array[String]`, `static func starter() -> Array[String]` (= tier 1)
- `static func modal_computed(id) -> int` = Σ `IngredientDB.price(i) * qty`

> CATATAN PENTING: `modal` dari GDD TIDAK selalu sama dengan `modal_computed`. `modal` dipakai untuk
> tampilan perencanaan di Buku Resep (agar angka profit persis GDD). Arus kas nyata memakai harga
> bahan aktual saat belanja di Pasar.

### EquipmentDB
`entry(kind: String, tier: int) -> {kind, tier, name, price, value}`
- `mixer` → value = detik proses: 20, 15, 10, 6, 3 | price: 0, 1500, 4500, 12000, 35000
- `oven` → value = detik panggang: 30, 22, 15, 10, 5 | price: 0, 2000, 6000, 15000, 50000
- `display` → value = kapasitas roti PER RAK: 50, 100, 200, 350, 600 | price: 0, 1500, 4500, 12000, 30000
- `static func mixer_time(tier) -> float`, `oven_time(tier) -> float`, `rack_capacity(tier) -> int`, `price(kind, tier) -> int`

Nama alat memakai GDD 5.1 sebagai kanonik (mis. Tier 4 oven = "Convection Oven Besar";
GDD 5.3.4 menyebut "Rotary Rack Oven" — simpan sebagai `alt_name`).

### LocationDB
`entry(tier) -> {tier, name, price, mixer_slots, oven_slots, rack_slots, cashier_slots, max_kasir, max_baker, queue_cap, pantry_cap, desc, targets}`

| tier | price | mixer | oven | rack | cashier | max_kasir | max_baker | queue_cap | pantry_cap |
|---|---|---|---|---|---|---|---|---|---|
| 1 | 0 | 1 | 1 | 1 | 1 | 1 | 1 | 4 | 150 |
| 2 | 15000 | 2 | 2 | 2 | 1 | 1 | 2 | 8 | 400 |
| 3 | 55000 | 3 | 3 | 3 | 2 | 2 | 2 | 14 | 1000 |
| 4 | 180000 | 4 | 4 | 4 | 2 | 2 | 3 | 20 | 2500 |
| 5 | 600000 | 5 | 5 | 6 | 3 | 3 | 4 | 35 | 6000 |

- `static func has_pickup_counter(tier) -> bool` → `tier >= 3` (GDD 3.6.B)
- `static func display_capacity(loc_tier, display_tier) -> int` = `rack_slots * EquipmentDB.rack_capacity(display_tier)`

### StaffDB
`entry(id) -> {id, name, role, tier, salary, speed, perk, profile, visual, extra}`
- Kasir: `speed` = detik/pelanggan → 7.0, 5.0, 3.5, 2.2, 1.2 | salary → 150, 350, 800, 1800, 4000
- Baker: `speed` = pengali kecepatan → 1.0, 1.25, 1.60, 2.00, 2.80 | salary → 180, 400, 950, 2200, 5000
  dan `extra.anti_burn` → 0.0, 0.25, 0.60, 0.90, 1.00
- Kasir `extra`: T3 `{"queue_stress": -0.15}`; T4 `{"galau_speedup": 2.0}`; T5 `{"tip_chance": 0.05}`
- `profile` = teks kepribadian dari GDD 3.5 (persis). `visual` = Dictionary parameter untuk CharacterFactory
  (turunkan dari kolom "Ciri Visual Prosedural").
- `static func by_role(role) -> Array[String]`, `by_tier(role, tier) -> Array[String]`, `apron_color(role, tier) -> Color`

### MarketingDB
`entry(tier) -> {tier, name, cost, per_day, visitor_boost, rating_per_day, req_location, desc, effect}`
- cost: 300, 1200, 3500, 10000, 30000 | per_day: 60, 240, 700, 2000, 6000
- visitor_boost: 0.20, 0.45, 0.75, 1.10, 1.60 | rating_per_day: 0.0, 0.08, 0.15, 0.30, 0.50
- `req_location` = tier. `const DURATION_DAYS := 5`

### CustomerDB
`entry(id) -> {id, name, patience, budget_factor, bulk_min, bulk_max, prefers: Array,
peak_hours: Array, min_recipe_tier, min_store_tier, rating_impact, rating_delay_days,
cashier_time_mult, spawn_weight, pickup_window, refuse_quality: Array, walk_in: bool, desc}`

> Skema CustomerDB **datar** (tidak ada sub-Dictionary `extra`), berbeda dari StaffDB.
> `si_galau.cashier_time_mult = 2.0`; arketipe lain `1.0`.
- `patience` detik; `peak_hours` berisi `Vector2i(mulai, selesai)` jam in-game.
- Sesuai GDD "Perilaku Konsumen": anak sekolah sabar & sensitif harga, puncak sore;
  pekerja kantoran sabar rendah, puncak 08:00–10:00; emak arisan beli 5–15;
  sosialita hanya resep tier ≥ 3 dan menolak kualitas buruk; si galau proses kasir 2x;
  food vlogger langka, dampak rating besar dua arah.
- `driver_ojol` punya `pickup_window` (detik).

### WeatherDB
`entry(id) -> {id, name, icon, foot_traffic_mult: Vector2, delivery_mult: Vector2, desc}`
- `cerah`: foot `(1.0, 1.0)`, delivery `(1.0, 1.0)`
- `hujan`: foot `(0.20, 0.40)`, delivery `(2.50, 3.00)`
- `liburan`: foot `(1.8, 2.2)`, delivery `(1.3, 1.6)`

### OpeningDB — tiga hari pembukaan (hari 1-3)

Hari 1-3 **tidak diundi**. Permintaannya ditulis pasti, dan gudang diisi PAS sebanyak itu: satu
loyang gosong berarti ada pembeli atau pesanan RotiFood yang tidak kebagian.

```gdscript
static func has_plan(day: int) -> bool
static func plan(day: int) -> Dictionary   # {recipe_id, batches, walk_ins, deliveries}
static func recipe_id(day: int) -> String  # SATU resep starter per hari
static func batches(day: int) -> int
static func walk_ins(day: int) -> Array    # [{hour, archetype, count}]
static func deliveries(day: int) -> Array  # [{hour, count}]
static func demand(day: int) -> int        # total roti yang diminta hari itu
static func supply(day: int) -> int        # batches x yield_count
static func pantry_for(day: int) -> Dictionary
```

**Invarian yang tidak boleh dilanggar: `demand(day) == supply(day)`.** Lebih sebutir, hari itu bisa
diselesaikan sambil menggosongkan roti dan pelajarannya hilang; kurang sebutir, hari itu mustahil
diselesaikan sempurna. `tools/data_audit.gd` (`_audit_opening`) menguncinya, lengkap dengan:
jumlah belanja tiap arketipe harus di dalam rentang `bulk_min..bulk_max`-nya, arketipe yang menolak
resep Tier 1 tidak boleh dijadwalkan, seluruh jam kedatangan di dalam jam buka, dan jatah bahannya
muat di gudang Tier 1.

Satu hari memakai SATU resep saja: dengan dua resep, pembeli yang mengambil roti "yang salah" dari
rak membuat hitungan per resep meleset walau totalnya pas.

Pelaksananya tersebar sesuai kepemilikan masing-masing: `CustomerSim` dan `DeliverySim` memuat
jadwalnya di `on_day_start()` dan mematikan undian kedatangan selama jadwal itu ada
(`scheduled_today()`), sementara `EconomySystem.on_day_start()` mengisi gudang lewat
`GameState.stock_opening_pantry(day)` lalu mengumumkan angkanya lewat toast. Pada hari terjadwal
`CustomerSim` TIDAK menjalankan `_apply_price_mood()` — jumlah belanja yang bergeser berarti
permintaan tidak lagi sama dengan bahan. HUD menampilkan baris "Permintaan: x / N roti" selama
hari terjadwal; tanpa angka itu di layar, "bahan pas permintaan" hanya jebakan.

### DialogDB
- `static func lurah_bailout(times: int) -> String` (dialog GDD 3.0.A; kunjungan berulang beri tip spesifik)
- `static func lurah_tip(ctx: Dictionary) -> String` (tabel GDD 11.4)
- `static func highlights(stats: Dictionary) -> Array` → maks 3 × `{icon, text}` (tabel GDD 11.3)
- `static func mood(profit: float, rating_delta: float, bailout: bool) -> Dictionary` → `{emoji, bg_color, text}` (tabel GDD 11.2)

## 4. GameConfig (autoload)

```gdscript
const SECONDS_PER_GAME_HOUR := 180.0 # 1 jam in-game = 3 menit nyata → hari 05:00-18:00 = 39 menit
                                     # (persiapan 9 menit + jualan 30 menit)
const HOUR_START := 5.0
const HOUR_OPEN := 8.0
const HOUR_CLOSE := 18.0
const SLOTS_PER_RACK := 6
const STARTING_COINS := 2000.0
const BAILOUT_COINS := 650.0
const SOLO_MODE_MAX_COINS := 500.0
const UTILITY_MIXER_PER_SEC := 0.8    # KR per DETIK NYATA alat bekerja
const UTILITY_OVEN_PER_SEC := 1.6     # (lama kerja alat = detik nyata, GDD 5.3)
const UTILITY_DISPLAY_PER_HOUR := 7.5 # KR per JAM TOKO, bukan per detik
const BURN_GRACE_RATIO := 0.35        # roti mulai gosong setelah 35% waktu panggang terlewat
var rng: RandomNumberGenerator
```
**Beban BERDIRI ditulis per jam in-game, beban PEMAKAIAN per detik nyata.** Etalase menyala
sepanjang toko buka, jadi tagihannya ditentukan jam toko (10 jam × 7,5 KR = 75 KR/hari per rak) dan
tidak ikut berubah saat `SECONDS_PER_GAME_HOUR` diubah. Mixer dan oven ditagih per detik nyata
karena lama kerjanya memang ditetapkan dalam detik nyata oleh tabel resep GDD 5.3 — ongkos per
batch harus tetap sama. Menulis beban berdiri "per detik" akan melarkan tagihan sepuluh kali lipat
begitu jam diperlambat, dan toko bangkrut tiap hari tanpa satu pun angka balans sengaja diubah;
`tools/sim_test.gd` (`_check_beban_etalase`) menjaganya.

Util (method di GameConfig, bukan class terpisah):
`kr(v: float) -> String` → `"1.234 KR"`; `clock(hour: float) -> String` → `"08:30"`;
`day_name(day: int) -> String` → Senin..Minggu; `date_label(day: int) -> String`.

## 5. EventBus (autoload) — signal WAJIB

```gdscript
signal phase_changed(phase: String)
signal clock_tick(hour: float)
signal day_started(day: int)
signal day_ended(ledger: Dictionary)
signal coins_changed(coins: float)
signal pantry_changed()
signal display_changed()
signal production_started(job: Dictionary)
signal production_finished(job: Dictionary)
signal bread_burned(recipe_id: String, count: int)
signal customer_spawned(c: Dictionary)
signal customer_served(c: Dictionary, revenue: float)
signal customer_left_angry(c: Dictionary, reason: String)
signal delivery_order_received(order: Dictionary)
signal delivery_order_packed(order: Dictionary)
signal delivery_order_handover(order: Dictionary, tip: float)
signal delivery_order_expired(order: Dictionary)
signal rating_changed(store: float, rotifood: float)
signal weather_changed(today: String, forecast: String)
signal staff_hired(staff_id: String)
signal staff_fired(staff_id: String)
signal staff_leave_toggled(staff_id: String, on_leave: bool)
signal campaign_started(tier: int)
signal campaign_ended(tier: int)
signal bailout_triggered(times: int)
signal solo_mode_changed(active: bool)
signal upgrade_purchased(kind: String, tier: int)
signal recipe_unlocked(recipe_id: String)
signal toast(text: String, icon: String)
signal screen_requested(screen: String, args: Dictionary)
```

## 6. GameState (autoload)

```gdscript
var coins: float
var day: int                  # mulai 1
var location_tier: int        # 1..5
var mixer_tier: int
var oven_tier: int
var display_tier: int
var pantry: Dictionary        # ingredient_id -> int
var unlocked_recipes: Array   # String
var recipe_prices: Dictionary # recipe_id -> float (harga per BUAH)
var display_slots: Array      # {recipe_id, count, quality, rack, slot, baked_hour}
var staff: Array              # {staff_id, role, tier, on_leave}
var store_rating: float       # 0..5, mulai 3.0
var rotifood_rating: float    # 1..5, mulai 4.0
var campaign: Dictionary      # {} atau {tier, days_left}
var weather: String
var forecast: String
var solo_mode: bool
var bailout_count: int
var last_bailout_day: int
var decor: Dictionary
var stats: Dictionary         # statistik hari ini
var history: Array            # ledger harian, maks 30
var baker_mode: Dictionary    # staff_id -> {"mode": "auto_replenish"|"target", "recipe_id": String}
var player: Dictionary        # {"gender": "pria"|"wanita"} — karakter yang dimainkan
```
API wajib:
```gdscript
func reset_new_game() -> void
func to_dict() -> Dictionary
func from_dict(d: Dictionary) -> void
func add_coins(v: float, reason: String) -> void
func spend_coins(v: float, reason: String) -> bool
func pantry_total() -> int
func pantry_capacity() -> int
func pantry_add(ing_id: String, n: int) -> int      # jumlah yang benar-benar masuk
func pantry_take(costs: Dictionary) -> bool         # atomik
func can_afford_recipe(recipe_id: String) -> bool
func display_total() -> int
func display_capacity() -> int
func display_add(recipe_id: String, count: int, quality: String, hour: float) -> int
func display_take(recipe_id: String, count: int) -> int
func active_staff(role: String) -> Array
func best_staff(role: String) -> Dictionary
func recipe_price(recipe_id: String) -> float
func is_recipe_available(recipe_id: String) -> bool
func reset_daily_stats() -> void
```
Key `stats` wajib: `income_store, income_delivery, tips, spent_ingredients, utility, salary,
customers_total, customers_angry, delivery_done, delivery_cancelled, bread_sold, bread_left,
burned, best_recipe, best_recipe_count, vip_visited, rating_start, rotifood_start, solo_first_day`.

## 7. Sistem Simulasi

Semua sistem `extends Node`, di-`add_child` oleh `Main`, berkomunikasi lewat `EventBus` + `GameState`.
`Main.systems` = `{"day","prod","player","cust","deliv","staff","econ","rep","weather","mkt","bailout"}`.

### 7.0 Siklus tick yang deterministik (WAJIB)

Sistem sim **TIDAK BOLEH** memakai `_process`/`_physics_process` sendiri. `Main` yang menjalankan
loop, memanggil tiap sistem dalam urutan tetap. Ini membuat simulasi bisa di-step headless dan
hasilnya bisa diulang persis.

Setiap sistem WAJIB mengimplementasikan antarmuka ini:
```gdscript
func setup(main: Node) -> void            # simpan rujukan, sambungkan signal
func sim_tick(delta: float, hour: float) -> void   # delta = detik NYATA, hour = jam in-game
func on_day_start(day: int) -> void
func on_day_end(ledger: Dictionary) -> void        # boleh menulis ke `ledger`
func reset() -> void                               # dipanggil saat new game / load
```
Urutan panggilan `sim_tick` per frame, ditetapkan `Main`:
`weather → mkt → day → prod → player → staff → cust → deliv → econ → rep → bailout`

`player` berdetak TEPAT SESUDAH `prod`: ia membaca kemajuan job yang baru saja dimajukan pada tick
yang sama, jadi tanda seru berpindah stasiun di frame yang sama dengan selesainya adukan.

`DayCycle` adalah satu-satunya yang memajukan `hour`. Bila `phase == "close"`, `Main` berhenti
memanggil `sim_tick` untuk `cust`/`deliv`/`prod`/`player`.

**Kepemilikan `GameState.day`**: HANYA `DayCycle.start_day()` yang menaikkannya, dan hanya bila
hari sebelumnya benar-benar sudah ditutup (`_day_ended == true`). Jadi `start_day()` pertama
sesudah `new_game()` atau `load_game()` tidak menggeser hari. Sistem lain WAJIB memperlakukan
`GameState.day` sebagai baca-saja.

**`Main` TIDAK BOLEH mendefinisikan `run_day_start()` / `run_day_end()`.** `DayCycle` sudah
melakukan fan-out awal/akhir hari sendiri; bila `Main` ikut mendefinisikannya, fan-out berjalan
dua kali dan Daily Summary muncul dobel.

**`EventBus.day_ended` hanya diemit `EconomySystem`**, bukan `DayCycle` — ledger-nya yang
disusun paling akhir. `DayCycle` yang memicu urutannya.

### 7.0.05 Navigasi aktor (ShopWorld)

Aktor berjalan di **kisi ubin yang sama** dengan Mode Dekorasi, bukan di atas collider fisika.
Perabot di proyek ini memang tidak punya collider sama sekali (lihat `decor_pick_at_screen`), dan
menambahkannya hanya demi tabrakan pejalan kaki berarti dua sumber kebenaran bentuk per perabot —
satu mesh, satu collider — yang pasti berbeda diam-diam begitu jejak lantai berubah.

```gdscript
func blocked_tiles() -> Dictionary          # Vector2i -> true
func is_tile_blocked(petak: Vector2i) -> bool
func nearest_free_tile(petak: Vector2i) -> Vector2i
func route(dari: Vector3, ke: Vector3) -> PackedVector3Array
func nav_invalidate() -> void               # dipanggil rebuild() & decor_place()
```
Terlarang = seluruh jejak `DECOR_KINDS` + kolom yang benar-benar tertutup bentang meja kasir
pembatas (celah jalan sisi +X tetap terbuka) + meja khusus ojol. `AStarGrid2D` dengan
`DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES`, lalu hasilnya diluruskan kembali dengan uji garis pandang
supaya karakter tidak melangkah zig-zag dari pusat ubin ke pusat ubin.

**Aktor yang BERHENTI MENUNGGU wajib ditetapkan arah hadapnya**, tidak dibiarkan memakai sisa
langkah terakhir. Kamera isometrik melayang di kuadran (+X, +Z): aktor yang berhenti menghadap −Z
hanya memperlihatkan punggungnya. Untuk driver ojol punggung itu adalah kotak ransel termal
sebesar badannya — model yang dibangun benar pun terbaca "terpasang terbalik" oleh pemain.
`DriverActor.wait_facing_entrance()` (dipanggil saat `arrived("jemput")`) dan
`_player.rotation.y = PI` pada kelahiran karakter pemain adalah penerapan aturan yang sama.
Pembeli di antrean justru dibiarkan menghadap meja kasir (jadi memunggungi kamera): itu yang
membuat mereka terbaca sedang dilayani. `tools/sim_test.gd` menguji arah hadap driver sebagai
KESEJAJARAN dengan arah kamera, bukan sudut tetap.

Sisi DEPAN karakter ada di −Z (`CharacterFactory.FRONT = -1.0`). Setiap barang yang dipegang atau
dipakai di depan badan wajib memakai `FRONT * jarak`, bukan nilai +Z — kantong serah terima driver
pernah mendarat persis di balik ranselnya karena ini.

`ActorBase.nav` diisi ShopWorld saat aktor lahir; `goto()` memperluas rutenya sendiri, jadi seluruh
pemanggil `goto()` yang sudah ada ikut berhenti menembus perabot tanpa diubah. Hanya titik
TERAKHIR yang membawa tag, sehingga tiap `goto()` tetap memicu tepat satu `arrived`.
Aktor tanpa `nav` berjalan lurus seperti dulu. Yang dijamin adalah **titik pusat** aktor, bukan
lingkar badannya: ubin 50 cm dan dapur Garasi 6 x 5 petak tidak menyisakan ruang untuk
menggelembungkan penghalang tanpa menutup lorongnya.

### 7.0.055 Tinggi meja terikat proporsi karakter

`EquipmentFactory.CHEST_HEIGHT` = `CharacterFactory.SHOULDER_Y`, dan
`COUNTER_HEIGHT` (= `DIVIDER_HEIGHT`) wajib berada DI BAWAHNYA. Setiap meja tempat orang berdiri
melayani — meja pembatas, meja kasir, meja ojol — menurunkan seluruh ketinggiannya dari `h =
COUNTER_HEIGHT`, jadi badan meja menyusut sementara barang yang berdiri di atasnya tetap seukuran
semula. Jangan menulis ulang koordinat Y satu per satu.

### 7.0.06 Meja kasir dijaga pemain (GDD 3.0.C)

Mengetuk meja kasir menyuruh karakter berjaga di `ShopWorld.cashier_stand_spot(i)` — sisi DAPUR
meja pembatas, menghadap +Z ke arah pembeli. `"cashier"` BUKAN anggota `DECOR_KINDS`: meja pembatas
bagian bangunan dan tidak bisa digeser, jadi ia punya jalur pemilihan sendiri
(`ShopWorld.tap_pick_at_screen()` = perabot yang bisa digeser, lalu meja kasir). Dua daftar terpisah
supaya menambah sasaran ketukan tidak diam-diam membuat sesuatu bisa diseret.

`CustomerSim` menjalankan jalur kasir MANUAL (lane tanpa staf, dibuat saat tidak ada kasir yang
disewa) **hanya selama `PlayerTaskSystem.manning_lane()` menunjuk lane itu**. Transaksi yang sedang
berjalan MEMBEKU saat pemain pergi, tidak dibatalkan — pembelinya masih berdiri menunggu.

### 7.0.07 Melayani pembeli fisik (GDD 2 "Tahap Jualan")

Urutan satu pembeli, dari pintu sampai pulang:

1. **masuk** — berjalan dari pintu ke rak display.
2. **memilih** — di depan rak; selesai memilih ia **MENGAMBIL rotinya dari rak saat itu juga**
   (`_fill_basket` dipanggil di `_finish_browsing`, bukan di meja kasir). Stok etalase berkurang
   sejak detik itu, dan yang ia bawa ke antrean memang sudah ada di tangannya.
3. **antre** — berdiri di depan meja kasir.
4. **balon "!"** muncul DI ATAS KEPALANYA begitu ia menjadi kepala antrean jalur manual.
5. Pemain mengetuk balon itu. Ketukan hanya membuka popup bila karakter sedang berjaga di meja
   kasir tersebut; bila tidak, ketukan itu menyuruh karakter berjalan ke sana.
6. **popup pesanan** (`customer_order`) menampilkan isi keranjang + total; tombol OK.
7. OK → `confirm_service()` → **dilayani**: karakter membungkus (`PlayerActor.set_wrapping(true)`,
   kantong kertas di tangan) selama `base_time` jalur itu.
8. **selesai** — uang masuk, pembeli pergi.

Aturan yang tidak boleh dibalik:

- **Jalur manual TIDAK PERNAH memulai transaksi sendiri.** `_update_lanes()` hanya memanggil
  `_start_service()` untuk lane yang dijaga staf. Inilah yang benar-benar dibeli pemain saat
  menggaji Asisten Kasir (GDD 3.1: "membebaskan pemain dari keharusan mengklik balon pesanan").
- **Roti yang sudah diambil WAJIB kembali ke rak** bila pembelinya batal membayar
  (`_return_basket()` di `_leave_angry()`, termasuk saat toko tutup lewat `_flush_customers()`).
  Kualitas dan `baked_hour` ikut dikembalikan apa adanya. Invarian yang diuji `tools/sim_test.gd`:
  selama belum ada yang membayar, **isi rak + isi seluruh keranjang pembeli tidak pernah berubah**.

### 7.0.08 Pesanan RotiFood mengikuti bentuk yang sama (GDD 3.6.A)

Pesanan ojol memakai POLA KETUKAN yang sama dengan pembeli fisik: balon → popup
(`delivery_order`) → satu tombol yang menyelesaikannya. Dua arus pembeli yang berbeda tidak boleh
menuntut dua cara berpikir yang berbeda. Bedanya hanya jumlah ketukan: ojol butuh dua kali
(`pack()` lalu `handover()`), dengan jeda pengemasan dan penantian driver di antaranya.

```gdscript
func waiting_for_player() -> Array[int]   # id pesanan yang menunggu ketukan,
                                          # yang paling mendesak (driver menunggu) di depan
func needs_player(order_id: int) -> bool
```

Balonnya muncul di DUA tempat, keduanya membuka popup yang sama:
- panel "Pesanan RotiFood" di HUD, dan
- tanda "!" di atas **tablet** di ujung meja kasir (`ShopWorld._refresh_tablet()`,
  `tap_pick_at_screen()` → `PlayerTaskSystem.tap("tablet", order_id)` → `delivery_requested`).

Berbeda dari balon pembeli fisik, balon tablet TIDAK menuntut karakter berdiri di meja kasir:
GDD 3.6 tidak pernah mengikat pesanan aplikasi ke posisi karakter.

**Tombol HUD yang berubah setiap 0,15 detik WAJIB dipakai ulang, bukan dibangun ulang.** Tombol
yang di-`queue_free()` di sela jari menekan dan melepas tidak pernah sempat mengirim `pressed`:
ketukan pemain hilang tanpa jejak. `HUD._order_buttons` memetakan `order_id -> Button` dan hanya
memperbarui `text`/`modulate`; hal yang sama berlaku untuk tombol di dalam popup mana pun yang
menyegarkan dirinya sendiri (lihat `DeliveryOrderScreen`).

API `CustomerSim` untuk jalur ini:
```gdscript
func waiting_for_player() -> Array[int]        # id pembeli berbalon "!" (kepala tiap lane manual)
func waiting_lane(customer_id: int) -> int     # lane manual tempat ia menunggu, -1 bila bukan
func confirm_service(customer_id: int) -> bool # pemain menekan OK; false = sudah tidak sah
func serving_id(lane_index: int) -> int        # pembeli yang sedang diproses, -1 bila menganggur
func customer(customer_id: int) -> Dictionary  # salinan untuk UI
```

Dunia 3D tidak menghitung sendiri kapan balon muncul — `ShopWorld.refresh_service()` menggambar
apa yang dilaporkan `waiting_for_player()`, persis seperti `refresh_markers()` terhadap perabot.
Balonnya `StationMarker` yang sama (`CustomerActor.show_alert/hide_alert/has_alert`), dan ketukan
layar mengenalinya lewat `ShopWorld.tap_pick_at_screen()` yang MENDAHULUKAN pembeli berbalon di
atas perabot di belakangnya.

`manning_lane()` DITURUNKAN dari posisi karakter (tidak sibuk + berada dalam `DEKAT` dari titik
layan), bukan disimpan sebagai penanda. Penanda harus dibersihkan di setiap jalur yang menyuruh
karakter pergi, dan satu jalur yang terlupa berarti pemain terus "melayani" dari seberang dapur.

### 7.0.1 PlayerTaskSystem — produksi manual karakter pemain

Pemain mengoperasikan dapur sendiri lewat satu karakter (GDD 2). `PlayerTaskSystem` menerjemahkan
KETUKAN di dunia 3D menjadi perintah ke `ProductionSystem`, dan sebaliknya menerjemahkan keadaan
produksi menjadi penanda yang mengambang di atas perabot.

Rantai satu pesanan:
`ketuk gudang → pilih resep → ketuk mixer → (aduk) → ketuk mixer (AMBIL adonan) → ketuk oven →
(panggang) → ketuk oven (ANGKAT loyang) → ketuk rak → pilih petak`

Aturan yang tidak boleh dibalik: **alat yang selesai bekerja MENAHAN isinya sampai diambil.**
Tanda seru tetap di alat itu (`ambil == true`), dan baru berpindah ke stasiun berikutnya SESUDAH
barangnya ada di tangan karakter (`ditangan == true`). Satu tanda, dua bacaan: "ambil dari sini"
saat tangannya kosong, "antar ke sini" saat ia sudah menenteng sesuatu.

Sepasang tangan, satu bawaan: selama `ditangan` masih menunjuk satu pesanan, ketukan untuk
MENGAMBIL pesanan lain ditolak (karakter tetap dihampirkan ke sana + toast). Mengantar tidak
pernah ditolak.

Barangnya tidak berpindah di mata `ProductionSystem` saat diambil — adonan tetap tercatat di mixer
sampai `move_to_oven()`, dan loyang tetap di oven (**tetap bisa gosong**) sampai `collect_to_slot()`.
Yang berubah hanyalah siapa yang memegangnya.

Bawaan tangan DITURUNKAN dari keadaan pesanan lewat `_segarkan_bawaan()`, bukan disimpan di aktor:
karakter yang sedang menenteng adonan boleh disuruh mampir ke gudang atau berjaga di kasir di tengah
jalan, dan satu jalur yang lupa memasang ulang bawaannya berarti adonan itu lenyap dari tangannya
padahal pesanannya masih berjalan. `refresh_carry()` adalah pintu publiknya (dipakai ShopWorld
sesudah kantong kertas pembungkus pesanan pembeli dilepas).

Pesanan yang barangnya sudah di tangan tetapi alat tujuannya penuh berstatus `STATE_TERTAHAN`
(tanpa tanda seru) dan dicoba ulang tiap tick oleh `_maju_tahap()`.

Beberapa pesanan berjalan SEKALIGUS; yang antre hanyalah kaki karakter. Mixer dan oven terus
berdetak sendiri, jadi selagi roti dipanggang pemain tetap bisa memilih resep baru.

```gdscript
func tap(kind: String, index: int) -> bool          # "storage"|"mixer"|"oven"|"display"|"cashier"
    #                                                 |"customer" (index = ID PELANGGAN)
    #                                                 |"tablet"   (index = ID PESANAN OJOL)
    # Perabot yang tidak menunggu pekerjaan tetap DIHAMPIRI karakter (TASK_HAMPIRI).
    # Kunjungan kosong yang belum selesai diganti ketukan terbaru; tugas KERJA
    # tidak pernah ikut dibatalkan. false = ketukan tidak mengubah apa pun.
    # "customer": balon "!" pembeli. Sedang berjaga -> customer_requested;
    # masih di dapur -> karakter disuruh berjalan ke meja kasir itu.
func manning_lane() -> int                          # mesin kasir yang sedang dijaga, -1 bila tidak
func choose_recipe(recipe_id: String, batches: int) -> bool
func place_bread(order_id: int, global_slot: int) -> int
func cancel_storage() -> void
func cancel_rack(order_id: int) -> void
func orders() -> Array
func markers() -> Dictionary        # "jenis:indeks" -> {"mode","value"}
func on_actor_arrived(tag: String) -> void
signal orders_changed()
signal storage_opened()
signal rack_requested(order_id: int, rack_index: int)
signal customer_requested(customer_id: int)
signal delivery_requested(order_id: int)
signal storage_door(open: bool)
```
Sistem sim TIDAK memanggil `ScreenRouter` sendiri: ia hanya melapor lewat signal, dan `Main` yang
memutuskan layar apa yang terbuka.

Job `ProductionSystem` yang lahir dari jalur ini membawa `"manual": true`. Bedanya hanya satu:
job manual **berhenti di setiap ujung tahap** dan menunggu perintah pemain — adonan tidak melompat
sendiri ke oven, roti matang tidak menata dirinya ke rak. Waktu, biaya bahan, dan kegosongan
dihitung dengan rumus yang sama persis. Asisten dapur yang disewa tetap bekerja otomatis seperti
biasa (GDD 3.2): itulah bentuk otomasinya.

API `ProductionSystem` untuk jalur manual:
```gdscript
func queue_manual(recipe_id: String, batches: int, mixer_slot: int) -> int   # -> job_id, 0 = ditolak
func move_to_oven(job_id: int, oven_slot: int = -1) -> int
func collect_to_slot(job_id: int, global_slot: int) -> int
func job(job_id: int) -> Dictionary
func job_at_slot(kind: String, slot_index: int) -> Dictionary
func progress(job_id: int) -> float
func mixing_done(job_id: int) -> bool
func baking_done(job_id: int) -> bool
```

### 7.1 Struktur data bersama (JANGAN mengubah bentuknya)

**Job produksi** (`EventBus.production_started/finished`):
```gdscript
{
  "id": int, "recipe_id": String, "batches": int,
  "stage": String,        # "mixing" | "baking" | "ready" | "burned" | "collected"
  "slot_kind": String,    # "mixer" | "oven"
  "slot_index": int,
  "elapsed": float,       # detik nyata di tahap ini
  "duration": float,      # detik nyata yang dibutuhkan tahap ini (sudah dikali speed baker)
  "overtime": float,      # detik nyata melewati matang (memicu gosong)
  "quality": String,      # kualitas kanonik
  "started_hour": float,
}
```

**Pelanggan fisik** (`EventBus.customer_spawned/served/left_angry`):
```gdscript
{
  "id": int, "archetype": String,
  "want": Array,          # recipe_id yang diincar, urut prioritas
  "count": int,           # jumlah roti yang dibeli
  "patience": float,      # detik nyata
  "waited": float,
  "state": String,        # "masuk" | "memilih" | "antre" | "dilayani" | "selesai" | "kabur"
  "cashier_index": int,   # -1 bila belum sampai kasir
  "spawn_hour": float,
  "basket": Dictionary,   # recipe_id -> int yang benar-benar diambil
  "paid": float,
}
```

**Pesanan RotiFood** (`EventBus.delivery_order_*`):
```gdscript
{
  "id": int,
  "items": Dictionary,    # recipe_id -> int
  "prep_window": float,   # detik nyata (GDD 3.6.A: 60-90 detik)
  "elapsed": float,
  "state": String,        # "masuk" | "dikemas" | "siap" | "driver_menunggu" | "selesai" | "batal"
  "driver_eta": float,    # detik nyata sampai driver tiba
  "driver_wait": float,   # detik nyata driver sudah menunggu
  "value": float,         # KR bila selesai
  "tip": float,
  "rainy": bool,
}
```

**Ledger harian** — payload `EventBus.day_ended` dan isi `GameState.history`.
Kunci ini WAJIB ada semua (dipakai langsung oleh DailySummaryScreen dan GDD 11.1):
```gdscript
{
  "day": int, "weather": String, "forecast": String,
  "income_store": float, "income_delivery": float, "tips": float, "total_income": float,
  "spent_ingredients": float, "utility": float, "salary": float,
  "salary_detail": Array,      # [{staff_id, name, role, tier, salary}]
  "total_expense": float, "profit": float, "balance": float,
  "customers_total": int, "customers_angry": int,
  "delivery_done": int, "delivery_cancelled": int,
  "bread_sold": int, "bread_left": int, "burned": int,
  "best_recipe": String, "best_recipe_count": int,
  "rating_store": float, "rating_rotifood": float,
  "rating_delta": float, "rotifood_delta": float,
  "vip_visited": bool, "solo_mode": bool, "bailout": bool,
  "mood": Dictionary,          # dari DialogDB.mood()
  "highlights": Array,         # dari DialogDB.highlights()
  "lurah_tip": String,         # dari DialogDB.lurah_tip()
  "campaign": Dictionary,      # {} atau {tier, days_left}
}
```
Invarian yang diuji `tools/sim_test.gd`:
`total_income == income_store + income_delivery + tips`,
`total_expense == spent_ingredients + utility + salary`,
`profit == total_income - total_expense`.
`spent_ingredients` adalah biaya bahan yang **benar-benar terpakai produksi hari itu**, dihitung dari
harga `IngredientDB` (bukan kolom `modal` GDD — lihat catatan di bagian RecipeDB).

- **DayCycle** — `var hour: float`, `var phase: String`. Maju di `_process(delta)`,
  emit `clock_tick`. `func start_day()`, `func end_day()`, `func set_paused(b)`.
- **ProductionSystem** — antrean job per slot mixer/oven.
  `func queue_batch(recipe_id: String, batches: int) -> bool` (ambil bahan pantry),
  `func collect(slot_index: int) -> void`, auto-burn lewat `BURN_GRACE_RATIO`.
- **CustomerSim** — spawn menurut rating, cuaca, kampanye, jam sibuk; antrean kasir; beli dari display.
- **DeliverySim** — order RotiFood, packing, kedatangan driver, handover, expire.
- **StaffSim** — otomasi kasir (speed) & baker (speed multiplier, anti_burn, mode kerja).
- **EconomySystem** — utilitas real-time, ledger harian, potong gaji saat `close`.
- **ReputationSystem** — rating toko & RotiFood sesuai tabel GDD 9.2.
- **WeatherSim** — cuaca hari ini + prakiraan besok.
- **MarketingSim** — kampanye aktif, hitung mundur 5 hari.
- **BailoutSystem** — kondisi GDD 3.0.E, cutscene, 650 KR + set bahan Tier 1, Mode Solo.

## 8. Procedural Generation — API

### ProceduralMeshFactory (semua static)
```gdscript
static func material(color: Color, rough := 0.85, metal := 0.0, emis := Color.BLACK) -> StandardMaterial3D
static func box(size: Vector3, color: Color, rough := 0.85) -> MeshInstance3D
static func cylinder(h: float, rt: float, rb: float, color: Color, rough := 0.85) -> MeshInstance3D
static func sphere(r: float, color: Color, rough := 0.9) -> MeshInstance3D
static func torus(inner: float, outer: float, color: Color, rough := 0.9) -> MeshInstance3D
static func capsule(h: float, r: float, color: Color) -> MeshInstance3D
static func rounded_slab(size: Vector3, bevel: float, color: Color) -> MeshInstance3D
static func lathe(profile: PackedVector2Array, segments: int, color: Color) -> MeshInstance3D
```
Budget 500–2000 tris per objek rakitan. `StandardMaterial3D` warna solid + roughness saja.

### BreadFactory
```gdscript
static func build(recipe_id: String, quality: String) -> Node3D
static func bake_color(t: float) -> Color      # t: 0 = mentah, 0.6 = matang, 1 = gosong
static func quality_shade(quality: String) -> float
```
Bentuk berbeda per resep: loaf kotak mengembang, donat (torus), croissant (segmen melengkung),
baguette (silinder panjang bergurat), roll spiral, crepes bertumpuk, bun bulat.

### EquipmentFactory
```gdscript
static func build_mixer(tier: int) -> Node3D
static func build_oven(tier: int) -> Node3D
static func build_display(tier: int) -> Node3D
static func build_storage(loc_tier: int) -> Node3D  # Gudang Penyimpanan: kulkas + lemari bahan
                                                    # jadi SATU perabot; diparameteri tier LOKASI
                                                    # (GDD 5.2.2), tidak dijual di Pasar.
                                                    # Unitnya BERJAJAR SEBARIS, semua pintu
                                                    # menghadap +Z; jejak N x 1 ubin.
                                                    # Anak wajib: daun pintu berengsel tegak
                                                    # bernama "Pintu", "Pintu2", "PintuLemari"
                                                    # (awalan "Pintu" = daun pintu).
static func build_counter(tier: int) -> Node3D
static func build_pickup_counter() -> Node3D
static func build_tablet() -> Node3D
static func build_room(loc_tier: int) -> Node3D   # lantai terakota, dinding, jendela kayu,
                                                  # tirai gingham, jam bandul, radio kaset
```
Bentuk bermutasi parametrik per tier (kayu manual T1 → industri/otomatis T5).

### CharacterFactory
```gdscript
static func build(spec: Dictionary) -> Node3D
static func spec_for_staff(staff_id: String) -> Dictionary
static func spec_for_player(gender: String) -> Dictionary   # "pria" | "wanita"
static func spec_for_customer(customer_id: String, seed_i: int) -> Dictionary
static func spec_for_driver(rainy: bool) -> Dictionary
static func spec_for_lurah() -> Dictionary
```
`spec`: `{kind, role, tier, skin, hair, hair_style, apron, accessory, chubby, rainy}`.
Chibi tanpa skeleton: kepala bola r≈0.22, badan kapsul h≈0.30, pipi merona `#FF9AA2`.

Hierarki node WAJIB (nama persis; `Face`/`Hat` sengaja bersarang di bawah `Head`
agar ikut bergerak saat kepala mengangguk, `Apron` di bawah `Body`):
```
Character
├── Body
│   └── Apron
├── Head
│   ├── Face   (anak: EyeL, EyeR, Mouth, BrowL, BrowR, CheekL, CheekR)
│   ├── Hair
│   └── Hat
├── ArmL, ArmR
└── LegL, LegR
```
Jangan pernah mengambil bagian tubuh dengan `get_node_or_null("Face")` — pakai
`CharacterFactory.part(actor, name)` yang mencari rekursif.
Driver ojol: seragam `#4EBA6F`, helm bundar, ransel termal kubus; saat `rainy` → jas hujan kuning.

### ProceduralAnimationSystem
```gdscript
static func walk(actor: Node3D, t: float, speed: float) -> void
static func idle_bob(actor: Node3D, t: float) -> void
static func squash_pop(node: Node, scale_to := 1.05, dur := 0.18) -> Tween
static func press_bounce(node: Control) -> Tween     # 0.92x → 1.05x → 1.0x
static func happy_jump(actor: Node3D) -> Tween
static func sad_shake(actor: Node3D) -> Tween
static func oven_door(node: Node3D, open: bool) -> Tween
static func storage_door(node: Node3D) -> Tween      # buka-tahan-tutup sekali jalan
static func storage_door_hold(node: Node3D, open: bool) -> Tween   # buka/tutup lalu DIAM
static func mixer_spin(node: Node3D, t: float) -> void
```

### ProceduralUIFactory
```gdscript
static func panel(color: Color, radius := 20, shadow := true) -> StyleBoxFlat
static func button(text: String, kind := "primary") -> Button
static func label(text: String, size := 18, color := Palette.TEXT) -> Label
static func title(text: String, size := 28) -> Label
static func card(title_text: String, radius := 22) -> PanelContainer
static func parchment_panel() -> PanelContainer
static func chalkboard_panel() -> PanelContainer
static func pantry_bar(value: int, max_value: int) -> Control
static func slider_row(label_text: String, min_v: float, max_v: float, value: float) -> HBoxContainer
static func polaroid(staff_id: String) -> Control
static func icon(name: String, size := 32, color := Color.WHITE) -> IconCanvas
static func apply_theme(root: Control) -> void
```
Sudut membulat ≥ 18 px. Hitbox interaktif minimal 48×48 px. `focus_mode = FOCUS_NONE`.
Semua tombol memanggil `ProceduralAnimationSystem.press_bounce` + `AudioBus.sfx("tap")`.

### IconCanvas (`extends Control`, gambar di `_draw`)
Properti: `icon_name: String`, `icon_color: Color`, `icon_size: float`.
Nama ikon wajib: `coin`, `star`, `clock`, `bolt`, `bread`, `bag`, `cart`, `people`, `heart`,
`angry`, `sad`, `happy`, `rain`, `sun`, `party`, `bubble`, `check`, `cross`, `plus`, `minus`,
`warning`, `fire`, `box`, `megaphone`, `chef`, `trophy`, `note`, `moon`, `scooter`, `hourglass`.

### FX
```gdscript
static func steam(parent: Node3D, pos: Vector3) -> CPUParticles3D
static func sugar_sparkle(parent: Node3D, pos: Vector3) -> CPUParticles3D
static func burn_smoke(parent: Node3D, pos: Vector3) -> CPUParticles3D
static func coin_pop(parent: CanvasItem, pos: Vector2, amount: float) -> void
static func sweat_drop(actor: Node3D) -> void
static func rain_overlay(parent: Node) -> CPUParticles2D
```

## 9. Audio Prosedural

`Synth` (static) → `AudioStreamWAV` dari PCM yang dihitung:
```gdscript
static func tone(freq: float, dur: float, wave: String, env: Dictionary) -> AudioStreamWAV
static func wooden_tap() -> AudioStreamWAV
static func bubble_pop() -> AudioStreamWAV
static func oven_ting() -> AudioStreamWAV
static func coin_chime() -> AudioStreamWAV
static func paper_rustle() -> AudioStreamWAV
static func door_click() -> AudioStreamWAV
static func chime_alert() -> AudioStreamWAV        # ting-ting-ting RotiFood
static func sad_soft() -> AudioStreamWAV
```
`AudioBus` (autoload): `func sfx(name: String, pitch := 1.0) -> void`,
`func start_music(mood: String) -> void`, `func stop_music() -> void`, `func unlock_audio() -> void`.
Nama sfx: `tap`, `pop`, `ting`, `coin`, `paper`, `door`, `chime`, `sad`.
Musik: progresi akor bossa-nova lo-fi dibangkitkan runtime (Rhodes sine+detune, petikan nilon).
`unlock_audio()` dipanggil dari splash "Tap untuk Mulai" (kebijakan autoplay browser).

## 10. UI / ScreenRouter

`ScreenRouter` (autoload) mengelola satu `CanvasLayer` overlay.
```gdscript
func go(screen: String, args := {}) -> void
func back() -> void
func close_all() -> void
var current: String
```
Screen: `main_menu`, `character_select`, `hud`, `market`, `recipe_book`, `staff`, `marketing`,
`daily_summary`, `decoration`, `bailout`, `rack`, `customer_order`, `delivery_order`.

`ScreenRouter.POPUP_SCREENS` (`recipe_book`, `staff`, `marketing`, `customer_order`,
`delivery_order`) TIDAK
menyembunyikan layar di bawahnya: kartunya mengambang di tengah dengan HUD dan dapur tetap terlihat
di belakangnya. Kerangkanya satu, `ProceduralUIFactory.popup(judul, ukuran)`, dengan meta
`"body"` / `"head"` / `"scrim"` / `"kartu"`. **Ukuran kartu dipatok** (`POPUP_SIZE`), tidak
mengikuti isi: kartu yang mengembang mengikuti teks terpanjang akan melar melewati tepi layar, dan
tepi yang lewat itu tidak bisa digulir kembali. `tools/sim_test.gd` mengukur
`get_combined_minimum_size()` tiap kartu terhadap patokan itu.
`character_select` muncul saat menekan "Main Baru" dan memanggil `Main.new_game(gender)`.
`recipe_book`, `rack`, dan `customer_order` TIDAK punya tombol di mana pun: ketiganya dibuka oleh
`PlayerTaskSystem` setelah karakter pemain benar-benar TIBA di gudang / di rak / di meja kasir
(GDD 2). `ShopWorld` melaporkan ketukan lewat signal lokalnya sendiri
`fixture_tapped(kind: String, index: int)` — bukan lewat EventBus — `HUD` meneruskannya ke
`PlayerTaskSystem.tap()`, dan sistem itu yang memutuskan apakah ketukan tersebut berarti sesuatu.
Perabot yang bisa diketuk/digeser ada di `ShopWorld.DECOR_KINDS` (`mixer`, `oven`, `display`,
`storage`); sasaran ketukan lain (meja kasir, pembeli berbalon, tablet RotiFood) punya jalur
pemilihannya sendiri. `delivery_order` dibuka dari DUA tempat: panel pesanan di HUD dan balon di
atas tablet.
Tombol Back Android (`NOTIFICATION_WM_GO_BACK_REQUEST` / `ui_cancel`) → `back()`;
di `main_menu` → dialog konfirmasi keluar.
Setiap layar `extends Control`, membangun UI sendiri di `_ready()` via `ProceduralUIFactory`,
dan punya `func setup(args: Dictionary) -> void` yang dipanggil ScreenRouter sebelum ditampilkan.

## 11. Save System

`SaveManager` (autoload):
```gdscript
const PATH := "user://savegame.json"
const VERSION := 1
func save_game() -> bool
func load_game() -> bool
func has_save() -> bool
func delete_save() -> void
func _migrate(d: Dictionary) -> Dictionary
```
Format `{"version": 1, "state": {...}}`. Autosave pada `day_ended`.

## 12. Main

`scenes/main.tscn` root `Node` bernama `Main`, script `scripts/main.gd`:
1. Bangun dunia 3D via `ShopWorld`.
2. Instansiasi semua sistem sim sebagai child, isi `systems`.
3. Splash "Tap untuk Mulai" → `AudioBus.unlock_audio()` → `main_menu`.
4. `func new_game()`, `func continue_game()`.

## 13. Validasi

- `tools/validate.gd` — `extends SceneTree`, `_initialize()`: load setiap `.gd` di `res://scripts`,
  cetak `OK <path>` / `FAIL <path>`, `quit(1)` bila ada yang gagal.
- `tools/sim_test.gd` — `extends SceneTree`: jalankan 3 hari headless, assert saldo bukan NaN,
  pantry ≤ kapasitas, display ≤ kapasitas, rating dalam rentang, ledger konsisten.
