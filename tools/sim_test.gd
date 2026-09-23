extends Node
## Tes simulasi headless: menjalankan permainan sungguhan selama beberapa hari
## dan memeriksa invarian ekonomi serta batas-batas kapasitas.
##
## Ini bukan tes unit — Main, ShopWorld, seluruh sistem sim, dan layar UI benar-benar
## hidup. Kalau ada yang crash saat bermain, tes ini yang menangkapnya.
##
## Jalankan: godot --headless --path . res://tools/sim_test.tscn

## Delta tetap untuk uji RINCI (ketukan, perjalanan kaki, animasi). Bukan 1/60
## supaya tes selesai cepat, tapi cukup halus agar timer produksi dan kesabaran
## pelanggan tetap masuk akal.
const DT: float = 0.05

## Delta untuk menjalankan HARI PENUH. Satu hari in-game kini 70 menit nyata
## (GameConfig.SECONDS_PER_GAME_HOUR = 300 detik/jam), jadi menjalankannya
## dengan butiran 0,05 detik berarti 84.000 langkah per hari — suite yang
## seharusnya dijalankan sesudah SETIAP perubahan berubah jadi belasan menit.
## Butiran 0,5 detik masih jauh lebih halus daripada peristiwa tersingkat di
## dalam simulasi (layan Kasir Superstar 1,2 detik).
const DT_HARI: float = 0.5

## Seberapa sering "pemain" meniru ketukan (angkat roti, layani antrean, kemas
## pesanan) selama hari penuh, dalam detik simulasi.
const AKSI_TIAP_DETIK: float = 2.0

const DAYS_TO_RUN: int = 3
## Pagar pengaman supaya tes tidak menggantung bila jam tidak pernah maju.
const MAX_STEPS_PER_DAY: int = 40000

## Pengali kecepatan untuk uji yang MENUNGGU ARUS PEMBELI. Kedatangan dihitung
## per jam in-game (GDD 9.1), jadi memperlambat jam otomatis memperlambat
## kedatangan dalam detik nyata. Tanpa percepatan ini, uji yang dulu cukup
## menunggu satu menit harus menunggu sepuluh menit untuk melihat pembeli yang
## sama — bukan karena perilakunya berubah, melainkan karena jamnya.
const SKALA_UJI_PEMBELI: float = 8.0

## --- Spesifikasi kamera isometrik ---
## Angka-angka ini sengaja ditulis ulang di sini alih-alih dibaca dari
## ShopWorld: tes harus memegang spesifikasinya sendiri. Kalau konstanta di
## ShopWorld bergeser diam-diam, tes inilah yang berteriak, bukan ikut berubah.
## Dimensi RUANGAN tetap dibaca dari EquipmentFactory (pemilik tunggalnya).
##
## Isometrik sejati: ortografik + yaw 45 derajat + kemiringan atan(1/sqrt(2)).
const CAM_YAW_DEG: float = 45.0
const CAM_PITCH_DEG: float = 35.264389682754654
## Rasio layar acuan GDD 12.5 (1280x720); Camera3D.size mengatur sisi tegak.
const VIEW_ASPECT: float = 16.0 / 9.0
## Toleransi sudut, dalam derajat. Isometrik tidak boleh "kira-kira".
const ANGLE_EPS: float = 0.25

## --- Spesifikasi meja kasir pembatas ---
## Meja menutup 70% lebar ruangan, DIBULATKAN ke bilangan ubin utuh; sisanya
## celah jalan staf di sisi +X.
const COUNTER_SPAN_RATIO: float = 0.70
const COUNTER_MIN_TILES: int = 2

## --- Spesifikasi kisi ubin ---
## Satu ubin 50 x 50 cm adalah satuan patokan seluruh penempatan perabot.
const TILE: float = 0.50
## Toleransi posisi terhadap kisi, meter.
const TILE_EPS: float = 0.001


## Bentang meja pembatas menurut SPESIFIKASI tes, bukan menurut kode produksi.
func _counter_span(w: float, cols: int) -> float:
	var tiles: int = clampi(int(round(w * COUNTER_SPAN_RATIO / TILE)),
		COUNTER_MIN_TILES, maxi(COUNTER_MIN_TILES, cols - 1))
	return float(tiles) * TILE
## Jarak Z minimal rak roti dari meja pembatas supaya mesh tidak saling tembus.
const RACK_CLEARANCE: float = 0.50
## Toleransi saat menguji kasir masih berada di atas bidang mejanya.
const SPAN_EPS: float = 0.001

var _fail: int = 0
var _pass: int = 0
var _main: Main = null
var _ledgers: Array = []


func _ready() -> void:
	print("=== TES SIMULASI HEADLESS ===")
	GameConfig.seed_rng(20260418)

	_main = Main.new()
	_main.name = "Main"
	add_child(_main)
	_main.boot()

	_ok("Main punya %d sistem" % Main.TICK_ORDER.size(),
		_main.systems.size() == Main.TICK_ORDER.size())
	for key in Main.TICK_ORDER:
		_ok("sistem '%s' ada" % key, _main.systems.has(key))
	_ok("dunia 3D terbangun", _main.world != null)

	EventBus.day_ended.connect(_on_day_ended)

	_main.new_game()
	_ok("saldo awal = STARTING_COINS",
		is_equal_approx(GameState.coins, GameConfig.STARTING_COINS))
	_ok("resep starter terbuka", GameState.unlocked_recipes.size() == 3)

	# Tiga hari pembukaan: gudang awal diisi PAS sebanyak permintaan hari itu.
	# Kalau ada kelebihan sebutir saja, hari pertama bisa diselesaikan sambil
	# menggosongkan roti dan pelajarannya hilang.
	_ok("hari pertama terjadwal", OpeningDB.has_plan(1))
	_ok("jatah bahan hari 1 = permintaan hari 1 (%d roti)" % OpeningDB.demand(1),
		OpeningDB.supply(1) == OpeningDB.demand(1))
	_ok("gudang awal berisi PERSIS jatah hari 1, tanpa bahan lain",
		_gudang_persis(OpeningDB.pantry_for(1)))

	for day_i in DAYS_TO_RUN:
		_run_one_day(day_i + 1)

	_check_ledgers()
	_check_save_roundtrip()
	_check_world_layout()
	_check_grid_alignment()
	_check_decor_tile_fidelity()
	_check_rotation()
	_check_decor_drag()
	_check_decor_pick()
	_check_storage()
	_check_player_flow()
	_check_hampiri_perabot()
	_check_alur_pembeli()
	_check_kasir_manual()
	_check_kasir_asisten()
	_check_popup_layar()
	_check_menu_ingame()
	_check_pesanan_ojol()
	_check_layar_karyawan()
	_check_beban_etalase()
	_check_actor_facing()
	_check_actor_collision()
	_check_camera_views()
	_check_staff_clearance()
	_check_decoration_roundtrip()

	print("")
	print("=== HASIL ===")
	print("LULUS : %d" % _pass)
	print("GAGAL : %d" % _fail)
	get_tree().quit(1 if _fail > 0 else 0)


func _ok(label: String, cond: bool) -> void:
	if cond:
		_pass += 1
	else:
		_fail += 1
		print("GAGAL  %s" % label)


func _run_one_day(day_num: int) -> void:
	var day: DayCycle = _main.systems["day"]
	var world: ShopWorld = _main.world as ShopWorld
	var steps: int = 0

	# Sebagian roti dibuat di tahap persiapan supaya etalase tidak kosong melompong.
	_queue_some_bread()

	# Tanpa kasir yang disewa, PEMAIN yang melayani (GDD 3.0.C) -- dan sejak
	# pelayanan manual menuntut kehadirannya, hari yang dijalankan tanpa
	# menempatkannya di meja kasir hanya mensimulasikan toko yang ditinggal
	# pemiliknya: seluruh pembeli pulang marah dan pemasukan toko nol.
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	if pt != null:
		pt.tap(PlayerTaskSystem.STATION_CASHIER, 0)

	var tiap: int = maxi(1, int(round(AKSI_TIAP_DETIK / DT_HARI)))
	while day.phase != GameConfig.PHASE_CLOSE and steps < MAX_STEPS_PER_DAY:
		_main.step(DT_HARI)
		# Dunia 3D ikut dimajukan: tanpa ini kaki karakter tidak pernah melangkah
		# dan ia tidak akan pernah sampai ke meja kasir.
		if world != null:
			world.tick_world(DT_HARI)
		steps += 1
		_check_invariants_fast()
		# Sesekali kumpulkan roti matang dan kemas pesanan, meniru pemain aktif.
		if steps % tiap == 0:
			_player_actions()

	_ok("hari %d mencapai fase tutup" % day_num, day.phase == GameConfig.PHASE_CLOSE)
	_ok("hari %d tidak menggantung (%d langkah)" % [day_num, steps],
		steps < MAX_STEPS_PER_DAY)

	print("  hari %d: %d langkah, saldo %s, rating %.2f / RotiFood %.2f"
		% [day_num, steps, GameConfig.kr(GameState.coins),
			GameState.store_rating, GameState.rotifood_rating])

	# Meniru pemain yang mampir ke Pasar tiap sore sebelum lanjut (GDD 11.6).
	_restock_pantry()

	# Meniru tombol "Lanjut ke Besok" pada Daily Summary (GDD 11.5).
	day.start_day()
	_ok("hari bertambah setelah start_day (%d)" % GameState.day,
		GameState.day == day_num + 1)


## Membeli bahan dasar sampai gudang terisi wajar, persis seperti pemain
## berbelanja di Pasar Bahan Baku pada Tahap Tutup.
## Apakah isi gudang PERSIS sama dengan `harap` — tidak kurang, dan tidak ada
## bahan lain yang menempel sebagai cadangan diam-diam.
func _gudang_persis(harap: Dictionary) -> bool:
	for k: Variant in harap:
		if int(GameState.pantry.get(String(k), 0)) != int(harap[k]):
			return false
	for k2: Variant in GameState.pantry:
		if int(GameState.pantry[k2]) <= 0:
			continue
		if not harap.has(String(k2)):
			return false
	return true


func _restock_pantry() -> void:
	var dasar: Array[String] = IngredientDB.by_category("dasar")
	var target: int = int(float(GameState.pantry_capacity()) * 0.6)
	var guard: int = 0
	while GameState.pantry_total() < target and guard < 500:
		guard += 1
		var terbeli: bool = false
		for id in dasar:
			var harga: int = IngredientDB.price(id)
			if GameState.coins < float(harga):
				continue
			if GameState.pantry_total() >= GameState.pantry_capacity():
				break
			if not GameState.spend_coins(float(harga), "tes_belanja"):
				continue
			GameState.pantry_add(id, 1)
			terbeli = true
		if not terbeli:
			break


func _queue_some_bread() -> void:
	var prod: ProductionSystem = _main.systems["prod"]
	# Hari terjadwal (OpeningDB): panggang PERSIS sebanyak jatahnya, resep hari
	# itu saja. Menyenggol resep lain berarti memakan bahan yang sudah dihitung
	# pas untuk permintaan hari ini — persis kesalahan yang diajarkan hari-hari
	# pembukaan untuk dihindari.
	if OpeningDB.has_plan(GameState.day):
		prod.queue_batch(OpeningDB.recipe_id(GameState.day),
			OpeningDB.batches(GameState.day))
		return
	for rid in GameState.unlocked_recipes:
		prod.queue_batch(String(rid), 2)


func _player_actions() -> void:
	var prod: ProductionSystem = _main.systems["prod"]
	if prod.has_method("collect_all"):
		prod.call("collect_all")

	# Pembeli fisik tidak lagi terlayani sendiri: sejak balon pesanan harus
	# diketuk (GDD 2 "Tahap Jualan"), hari yang dijalankan tanpa menekan OK
	# hanya mensimulasikan kasir yang bengong. Di sinilah tes meniru jari pemain.
	_layani_antrean()
	# Antre ulang bila mixer menganggur dan bahan masih ada. Hari terjadwal
	# dilewati: jatahnya sudah dipanggang sekaligus di awal hari.
	if OpeningDB.has_plan(GameState.day):
		pass
	elif prod.free_mixer_slots() > 0 and not GameState.unlocked_recipes.is_empty():
		var rid: String = String(GameState.unlocked_recipes[
			GameConfig.rng.randi_range(0, GameState.unlocked_recipes.size() - 1)])
		prod.queue_batch(rid, 1)

	var deliv: DeliverySim = _main.systems["deliv"]
	var id: int = deliv.next_packable_order()
	if id >= 0:
		deliv.pack(id)
	id = deliv.next_handover_order()
	if id >= 0:
		deliv.handover(id)


## Pemeriksaan yang dijalankan tiap langkah — harus murah.
func _check_invariants_fast() -> void:
	if is_nan(GameState.coins) or is_inf(GameState.coins):
		_ok("saldo tetap angka yang sah", false)
	if GameState.coins < 0.0:
		_ok("saldo tidak pernah negatif (GDD: tidak ada game over)", false)
	if GameState.pantry_total() > GameState.pantry_capacity():
		_ok("gudang tidak melewati kapasitas", false)
	if GameState.display_total() > GameState.display_capacity():
		_ok("etalase tidak melewati kapasitas", false)
	if GameState.store_rating < 0.0 or GameState.store_rating > 5.0:
		_ok("rating toko dalam 0..5", false)
	if GameState.rotifood_rating < 1.0 or GameState.rotifood_rating > 5.0:
		_ok("rating RotiFood dalam 1..5", false)


func _on_day_ended(ledger: Dictionary) -> void:
	_ledgers.append(ledger)


## Invarian aritmetika ledger (ARCHITECTURE.md 7.1).
func _check_ledgers() -> void:
	print("\n-- Ledger --")
	_ok("ada %d ledger" % DAYS_TO_RUN, _ledgers.size() == DAYS_TO_RUN)

	var wajib: Array[String] = [
		"day", "weather", "income_store", "income_delivery", "tips", "total_income",
		"spent_ingredients", "utility", "salary", "salary_detail", "total_expense",
		"profit", "balance", "customers_total", "customers_angry", "delivery_done",
		"delivery_cancelled", "bread_sold", "bread_left", "burned", "best_recipe",
		"best_recipe_count", "rating_store", "rating_rotifood", "rating_delta",
		"rotifood_delta", "mood", "highlights", "lurah_tip",
	]

	for i in _ledgers.size():
		var l: Dictionary = _ledgers[i]
		for k in wajib:
			_ok("ledger %d punya kunci '%s'" % [i + 1, k], l.has(k))

		var inc: float = float(l.get("total_income", 0.0))
		var inc_parts: float = float(l.get("income_store", 0.0)) \
			+ float(l.get("income_delivery", 0.0)) + float(l.get("tips", 0.0))
		_ok("ledger %d: total_income = toko + delivery + tip (%.2f vs %.2f)"
			% [i + 1, inc, inc_parts], is_equal_approx(inc, inc_parts))

		var exp_total: float = float(l.get("total_expense", 0.0))
		var exp_parts: float = float(l.get("spent_ingredients", 0.0)) \
			+ float(l.get("utility", 0.0)) + float(l.get("salary", 0.0))
		_ok("ledger %d: total_expense = bahan + utilitas + gaji (%.2f vs %.2f)"
			% [i + 1, exp_total, exp_parts], is_equal_approx(exp_total, exp_parts))

		var profit: float = float(l.get("profit", 0.0))
		_ok("ledger %d: profit = pemasukan - pengeluaran (%.2f vs %.2f)"
			% [i + 1, profit, inc - exp_total], is_equal_approx(profit, inc - exp_total))

		_ok("ledger %d: mood terisi" % [i + 1],
			(l.get("mood", {}) as Dictionary).size() > 0)

		# Tiga hari pembukaan: bahan disediakan PAS sebanyak permintaan, jadi
		# hari yang dijalani tanpa menggosongkan apa pun harus berakhir dengan
		# seluruh permintaan terpenuhi DAN tanpa sisa roti satu butir pun.
		# Kalau salah satunya meleset, "pas" itu cuma klaim di komentar.
		var d: int = int(l.get("day", 0))
		if not OpeningDB.has_plan(d):
			continue
		var minta: int = OpeningDB.demand(d)
		_ok("hari terjadwal %d: seluruh permintaan terpenuhi (%d dari %d roti)"
			% [d, int(l.get("bread_sold", 0)), minta],
			int(l.get("bread_sold", 0)) == minta)
		_ok("hari terjadwal %d: tidak ada pembeli yang pulang marah (%d)"
			% [d, int(l.get("customers_angry", 0))],
			int(l.get("customers_angry", 0)) == 0)
		_ok("hari terjadwal %d: tidak ada pesanan ojol yang batal (%d)"
			% [d, int(l.get("delivery_cancelled", 0))],
			int(l.get("delivery_cancelled", 0)) == 0)
		_ok("hari terjadwal %d: tidak ada roti tersisa (%d)"
			% [d, int(l.get("bread_left", 0))],
			int(l.get("bread_left", 0)) == 0)
		_ok("hari terjadwal %d: tidak ada roti gosong (%d)"
			% [d, int(l.get("burned", 0))], int(l.get("burned", 0)) == 0)

		print("  hari %d: toko %s + ojol %s, laba %s, pelanggan %d (marah %d), ojol %d/%d"
			% [int(l.get("day", 0)),
				GameConfig.kr(float(l.get("income_store", 0.0))),
				GameConfig.kr(float(l.get("income_delivery", 0.0))),
				GameConfig.kr(profit),
				int(l.get("customers_total", 0)), int(l.get("customers_angry", 0)),
				int(l.get("delivery_done", 0)), int(l.get("delivery_cancelled", 0))])

	_ok("riwayat tersimpan di GameState", GameState.history.size() >= DAYS_TO_RUN)


## Save harus bolak-balik lewat JSON tanpa kehilangan data (GDD 12.6).
func _check_save_roundtrip() -> void:
	print("\n-- Save / Load --")
	var sebelum: Dictionary = GameState.to_dict()
	var coins_sebelum: float = GameState.coins
	var hari_sebelum: int = GameState.day
	var gender_sebelum: String = GameState.player_gender()

	_ok("save_game() berhasil", SaveManager.save_game())
	_ok("has_save() true setelah menyimpan", SaveManager.has_save())

	# Rusak keadaan, lalu muat ulang.
	GameState.coins = -999.0
	GameState.day = 999
	_ok("load_game() berhasil", SaveManager.load_game())
	_ok("saldo pulih setelah load", is_equal_approx(GameState.coins, coins_sebelum))
	_ok("hari pulih setelah load", GameState.day == hari_sebelum)
	_ok("pilihan karakter pulih setelah load",
		GameState.player_gender() == gender_sebelum)

	# Simpanan versi lama tidak punya kunci "player" sama sekali; ia harus jatuh
	# ke bawaan, bukan menggagalkan pemuatan (GDD 12.6).
	var lama: Dictionary = GameState.to_dict()
	lama.erase("player")
	GameState.from_dict(lama)
	_ok("simpanan tanpa kunci 'player' tetap terbaca",
		GameState.PLAYER_GENDERS.has(GameState.player_gender()))
	GameState.set_player_gender(gender_sebelum)

	# JSON harus bisa menampung seluruh state tanpa tipe yang tidak serializable.
	var teks: String = JSON.stringify(sebelum)
	_ok("state bisa di-stringify ke JSON", teks != "" and teks != "null")
	var kembali: Variant = JSON.parse_string(teks)
	_ok("JSON bisa dibaca kembali", kembali is Dictionary)

	SaveManager.delete_save()
	_ok("delete_save() membersihkan simpanan", not SaveManager.has_save())


## Perabot WAJIB berada di DALAM dinding dan pada zona yang benar. Sejak
## rombakan sudut pandang, sumbu Z dibaca begini: -Z = belakang, +Z = pintu.
##
##   dinding belakang -> mixer & oven -> MEJA KASIR PEMBATAS -> rak roti
##   -> antrean -> pintu
##
## Penjaga ini ada karena pernah terjadi: ShopWorld punya rumus lebar ruangan
## sendiri yang berbeda dari EquipmentFactory, sehingga mixer dan oven mendarat
## di balik dinding belakang dan area dapur tidak pernah terlihat pemain.
## Semua angka di bawah diturunkan dari EquipmentFactory - pemilik tunggal
## dimensi ruangan - supaya tes tidak ikut mengarang rumusnya sendiri.
func _check_world_layout() -> void:
	print("\n-- Tata Letak Dunia --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		GameState.location_tier = tier
		world.rebuild()

		var w: float = EquipmentFactory.room_width(tier)
		var d: float = EquipmentFactory.room_depth(tier)
		var wall: float = EquipmentFactory.room_wall_thickness()
		var part_z: float = EquipmentFactory.partition_z(tier)
		var x_lim: float = w * 0.5 - wall
		var z_lim: float = d * 0.5 - wall

		# Meja kasir pembatas menempel ke dinding kiri; celah jalan staf ada di
		# sisi +X. Kasir yang terlanjur berdiri di celah itu menutup satu-satunya
		# jalan tembus ke dapur, jadi posisi X-nya ikut diuji.
		var span: float = _counter_span(w, EquipmentFactory.floor_cols(tier))
		var walk_gap: float = w - wall * 2.0 - span
		var cx: float = -w * 0.5 + span * 0.5
		var span_min: float = cx - span * 0.5
		var span_max: float = cx + span * 0.5

		var loc: Dictionary = LocationDB.entry(tier)
		_ok("T%d jumlah mixer sesuai slot" % tier,
			world.mixer_pos.size() == int(loc.get("mixer_slots", 1)))
		_ok("T%d jumlah oven sesuai slot" % tier,
			world.oven_pos.size() == int(loc.get("oven_slots", 1)))
		_ok("T%d jumlah rak sesuai slot" % tier,
			world.display_pos.size() == int(loc.get("rack_slots", 1)))
		_ok("T%d jumlah kasir sesuai slot" % tier,
			world.cashier_pos.size() == int(loc.get("cashier_slots", 1)))

		_inside(tier, "mixer", world.mixer_pos, x_lim, z_lim)
		_inside(tier, "oven", world.oven_pos, x_lim, z_lim)
		_inside(tier, "rak display", world.display_pos, x_lim, z_lim)
		_inside(tier, "kasir", world.cashier_pos, x_lim, z_lim)
		_check_fixture_bounds(tier)

		# Kasus terburuk yang benar-benar bisa dicapai pemain: Pasar TIDAK mengunci
		# tier peralatan berdasarkan tier lokasi, jadi Oven Tier 5 (Conveyor Belt,
		# lebar 1,7 m) bisa berdiri di Garasi Tier 1 yang lebarnya cuma 3 m.
		var simpan := [GameState.mixer_tier, GameState.oven_tier, GameState.display_tier]
		GameState.mixer_tier = 5
		GameState.oven_tier = 5
		GameState.display_tier = 5
		world.rebuild()
		_check_fixture_bounds(tier)
		GameState.mixer_tier = int(simpan[0])
		GameState.oven_tier = int(simpan[1])
		GameState.display_tier = int(simpan[2])
		world.rebuild()

		# --- Zona: dapur di belakang garis pembatas, toko di depannya ---
		for p in world.mixer_pos:
			_ok("T%d mixer di area dapur (z %.2f < %.2f)" % [tier, p.z, part_z], p.z < part_z)
		for p in world.oven_pos:
			_ok("T%d oven di area dapur (z %.2f < %.2f)" % [tier, p.z, part_z], p.z < part_z)
		for p in world.display_pos:
			_ok("T%d rak di area toko, di DEPAN pembatas (z %.2f > %.2f)"
				% [tier, p.z, part_z], p.z > part_z)
			# Rak yang menempel ke meja pembatas akan saling menembus mesh.
			_ok("T%d rak tidak menabrak meja pembatas (selisih z %.2f >= %.2f)"
				% [tier, p.z - part_z, RACK_CLEARANCE], p.z - part_z >= RACK_CLEARANCE)

		# --- Kasir: TEPAT di baris ubin meja, dan tidak menyumbat celah jalan ---
		# Dulu diuji terhadap partition_z (garis zona). Sejak meja punya baris
		# ubinnya sendiri, garis zona dan baris meja adalah dua angka berbeda.
		var z_meja: float = EquipmentFactory.counter_z(tier)
		_ok("T%d baris meja kasir = baris pertama zona toko" % tier,
			EquipmentFactory.counter_row(tier) == EquipmentFactory.kitchen_tiles(tier))
		_ok("T%d meja kasir setebal satu ubin (%.2f m)"
			% [tier, EquipmentFactory.DIVIDER_DEPTH],
			absf(EquipmentFactory.DIVIDER_DEPTH - TILE) < TILE_EPS)
		for p in world.cashier_pos:
			_ok("T%d kasir tepat di baris meja (z %.3f vs %.3f)"
				% [tier, p.z, z_meja], is_equal_approx(p.z, z_meja))
			_ok("T%d kasir tidak masuk celah jalan (x %.2f dalam %.2f..%.2f)"
				% [tier, p.x, span_min, span_max],
				p.x >= span_min - SPAN_EPS and p.x <= span_max + SPAN_EPS)

		# --- Urutan z dari belakang ke depan ---
		var z_kitchen: float = maxf(_max_z(world.mixer_pos), _max_z(world.oven_pos))
		var z_cash: float = _min_z(world.cashier_pos)
		var z_rack: float = _min_z(world.display_pos)
		var z_queue: float = INF
		if not world.queue_pos.is_empty():
			z_queue = world.queue_pos[0].z
		var z_door: float = world.door_pos.z

		_ok("T%d antrean punya titik" % tier, not world.queue_pos.is_empty())
		_ok("T%d urutan: dapur (%.2f) di belakang kasir (%.2f)" % [tier, z_kitchen, z_cash],
			z_kitchen < z_cash)
		_ok("T%d urutan: kasir (%.2f) di belakang rak (%.2f)" % [tier, z_cash, z_rack],
			z_cash < z_rack)
		_ok("T%d urutan: rak (%.2f) di belakang antrean (%.2f)" % [tier, z_rack, z_queue],
			z_rack < z_queue)
		_ok("T%d urutan: antrean (%.2f) di belakang pintu (%.2f)" % [tier, z_queue, z_door],
			z_queue < z_door)
		_ok("T%d pintu masih di dalam ruangan (z %.2f)" % [tier, z_door],
			absf(z_door) < z_lim)

		# Mixer dan oven tidak boleh saling menimpa.
		for a in world.mixer_pos:
			for b in world.oven_pos:
				_ok("T%d mixer & oven tidak bertumpuk" % tier,
					a.distance_to(b) > 0.60)

		# GDD 3.6.B: Meja Khusus Ojol hanya ada mulai Tier 3.
		_ok("T%d meja ojol sesuai aturan tier" % tier,
			(world.pickup_pos != Vector3.ZERO) == (tier >= 3))

		print("  T%d: ruang %.1f x %.1f, pembatas z=%.2f, meja x %.2f..%.2f (celah %.2f), %d mixer / %d oven / %d rak / %d kasir"
			% [tier, w, d, part_z, span_min, span_max, walk_gap,
				world.mixer_pos.size(), world.oven_pos.size(),
				world.display_pos.size(), world.cashier_pos.size()])

	GameState.location_tier = 1
	world.rebuild()


## Setiap perabot wajib berdiri di KISI UBIN 50 cm.
##
## Ini penjaga untuk aturan "satu ubin 50 x 50 cm adalah satuan patokan seluruh
## perabotan". Tanpa penjaga ini kisi itu cuma niat baik: perabot ditempatkan
## lewat empat jalur berbeda (denah bawaan, penjepitan dinding, Mode Dekorasi,
## dan penskalaan alat kebesaran), dan cukup SATU jalur lupa mengunci ke kisi
## untuk membuat rak berdiri menyerong terhadap ubin di bawahnya.
##
## Dua pengecualian yang disengaja dan ikut diuji di sini:
##   - meja kasir pembatas berdiri di TEPI ubin (garis partition_z), bukan di
##     pusat ubin, karena ia membelah ruangan alih-alih menempati satu petak;
##   - perabot yang lebih lebar daripada ruang geraknya (Oven Conveyor Tier 5
##     di garasi) boleh lepas dari kisi — menariknya ke pusat ubin terdekat
##     justru menanamkannya di dalam dinding.
func _check_grid_alignment() -> void:
	print("
-- Kisi Ubin 50 cm --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	_ok("ubin patokan = %.0f cm" % (TILE * 100.0),
		is_equal_approx(EquipmentFactory.FLOOR_TILE, TILE))
	# Mode Dekorasi tidak lagi punya petaknya sendiri — ia menata langsung di
	# ubin lantai. Yang diuji sekarang: terjemahan LAYAR -> UBIN benar, karena
	# itulah satu-satunya jembatan antara jari pemain dan kisi.

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.decor.clear()
		world.rebuild()

		var w: float = EquipmentFactory.room_width(tier)
		var d: float = EquipmentFactory.room_depth(tier)
		var cols: int = EquipmentFactory.floor_cols(tier)
		var rows: int = EquipmentFactory.floor_rows(tier)

		_ok("T%d lebar %.2f m = %d ubin utuh" % [tier, w, cols],
			absf(w - float(cols) * TILE) < TILE_EPS)
		_ok("T%d kedalaman %.2f m = %d ubin utuh" % [tier, d, rows],
			absf(d - float(rows) * TILE) < TILE_EPS)

		# Garis pembatas jatuh di TEPI ubin, bukan di tengah-tengahnya.
		var part_z: float = EquipmentFactory.partition_z(tier)
		_ok("T%d garis pembatas di tepi ubin (z %.3f)" % [tier, part_z],
			_on_tile_edge(part_z + d * 0.5))

		# Bentang meja pembatas berjumlah ubin utuh.
		var span: float = float(EquipmentFactory.divider_metrics(tier)["span"])
		_ok("T%d bentang meja %.2f m = %d ubin utuh"
			% [tier, span, int(round(span / TILE))],
			absf(span - float(int(round(span / TILE))) * TILE) < TILE_EPS)

		# Invarian: SATU PERABOT = SATU UBIN, dan tidak ada dua perabot yang
		# berbagi ubin. Sengaja tidak menuntut "tepat di pusat ubin": perabot di
		# baris tepi memang digeser merapat ke dinding, persis seperti lemari
		# yang didorong ke tembok. Yang haram adalah pindah ke ubin LAIN.
		var huni: Dictionary = {}
		var bentrok: Array[String] = []
		var di_luar: Array[String] = []
		for nama_v in [["mixer", world.mixer_pos, GameState.mixer_tier],
				["oven", world.oven_pos, GameState.oven_tier],
				["display", world.display_pos, GameState.display_tier]]:
			var nama: String = String((nama_v as Array)[0])
			var jejak: Vector2i = EquipmentFactory.footprint(nama, int((nama_v as Array)[2]))
			for p_v in ((nama_v as Array)[1] as Array):
				var p: Vector3 = p_v
				# Titik pusat perabot wajib berada di dalam ruangan.
				if absf(p.x) > w * 0.5 or absf(p.z) > d * 0.5:
					di_luar.append("%s(%.2f, %.2f)" % [nama, p.x, p.z])
					continue
				bentrok.append_array(_huni_jejak(
					huni, _anchor_of(tier, p, jejak), jejak, nama))
		_ok("T%d tidak ada perabot di luar ruangan%s"
			% [tier, "" if di_luar.is_empty() else " — " + ", ".join(di_luar)],
			di_luar.is_empty())
		_ok("T%d tidak ada dua perabot berbagi ubin%s"
			% [tier, "" if bentrok.is_empty() else " — " + ", ".join(bentrok)],
			bentrok.is_empty())
		var terkunci: int = huni.size()

		# Terjemahan LAYAR -> UBIN harus pulang ke ubin yang sama. Kalau meleset
		# satu ubin saja, pemain akan mengetuk rak dan yang terpilih justru
		# tetangganya — dan itu tidak akan terlihat sebagai angka yang salah
		# di mana pun, hanya sebagai "kontrolnya terasa aneh".
		var meleset: Array[String] = []
		for col in [0, cols / 2, cols - 1]:
			for row in [0, rows / 2, rows - 1]:
				var dunia := Vector3(EquipmentFactory.tile_x(tier, col), 0.0,
					EquipmentFactory.tile_z(tier, row))
				var layar_pos: Vector2 = world.camera.unproject_position(dunia)
				var balik: Vector2i = world.decor_tile_at_screen(layar_pos)
				if balik != Vector2i(col, row):
					meleset.append("(%d,%d)->(%d,%d)" % [col, row, balik.x, balik.y])
		_ok("T%d ubin <-> titik layar pulang ke ubin yang sama%s"
			% [tier, "" if meleset.is_empty() else " — " + ", ".join(meleset)],
			meleset.is_empty())

		print("  T%d: %d perabot terkunci, kisi %d x %d petak, pembatas z=%.2f"
			% [tier, terkunci, cols, rows, part_z])

	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()


## Denah pemain harus mendarat di UBIN YANG IA PILIH, dan tidak boleh ada dua
## perabot yang menumpuk.
##
## Regresi dari laporan bug nyata: oven ditaruh di petak (0,0) dan mixer di
## petak (0,1) — keduanya mendarat menumpuk di ubin (1,1). Penyebabnya
## _clamp_zone() lama memakai kelonggaran dinding 0,45 m lalu mencari "pusat
## ubin sah terdekat"; seluruh cincin ubin tepi karena itu runtuh ke cincin di
## dalamnya, dan dua petak berbeda menjadi satu titik.
##
## Diuji dua skenario yang menuntut hal berbeda:
##   A. Petak renggang — setiap perabot MUAT di petaknya, jadi ia wajib mendarat
##      persis di situ. Inilah skenario laporan.
##   B. Petak berdempetan — rak display selebar ~2 ubin memang TIDAK mungkin
##      berjajar di petak bersebelahan, jadi yang dituntut bukan kesetiaan
##      petak melainkan: tidak ada yang menumpuk dan tidak ada yang hilang.
func _check_decor_tile_fidelity() -> void:
	print("
-- Kesetiaan Petak Dekorasi --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		_decor_exact_case(world, tier)
		_decor_crowd_case(world, tier)

	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()


## Skenario A: persis seperti yang dilaporkan pemain — oven di petak pojok
## belakang-kiri, mixer tepat di bawahnya, rak satu kolom ke dalam. Ketiganya
## muat di petaknya, jadi ketiganya WAJIB mendarat di petak itu juga.
func _decor_exact_case(world: ShopWorld, tier: int) -> void:
	GameState.location_tier = tier
	var toko_min: int = EquipmentFactory.shop_row_min(tier)
	var baris_mixer: int = mini(1, EquipmentFactory.kitchen_row_max(tier))
	var harap := {
		Vector2i(0, 0): "oven",
		Vector2i(0, baris_mixer): "mixer",
		Vector2i(1, toko_min): "display",
	}
	GameState.decor.clear()
	GameState.decor["grid"] = {
		"w": EquipmentFactory.floor_cols(tier),
		"h": EquipmentFactory.floor_rows(tier),
		"cell": TILE}
	var denah: Dictionary = {}
	for k in harap.keys():
		denah["%d,%d" % [(k as Vector2i).x, (k as Vector2i).y]] = String(harap[k])
	GameState.decor["layout"] = denah
	world.rebuild()

	var salah: Array[String] = []
	var dapat: Dictionary = {}
	for nama_v in [["mixer", world.mixer_pos, GameState.mixer_tier],
			["oven", world.oven_pos, GameState.oven_tier],
			["display", world.display_pos, GameState.display_tier]]:
		var jenis: String = String((nama_v as Array)[0])
		var tier_alat: int = int((nama_v as Array)[2])
		var jejak: Vector2i = EquipmentFactory.footprint(jenis, tier_alat)
		for p_v in ((nama_v as Array)[1] as Array):
			var petak: Vector2i = _anchor_of(tier, p_v as Vector3, jejak)
			dapat[petak] = jenis
			if String(harap.get(petak, "")) != jenis:
				salah.append("%s anchor di ubin %d,%d (bukan petak pilihan)"
					% [jenis, petak.x, petak.y])

	_ok("T%d denah renggang mendarat persis di petak pilihan%s"
		% [tier, "" if salah.is_empty() else " — " + ", ".join(salah)],
		salah.is_empty())
	_ok("T%d ketiga perabot pilihan hadir (%d dari 3)" % [tier, dapat.size()],
		dapat.size() == 3)
	print("  T%d renggang: oven(0,0) mixer(0,%d) rak(1,%d) -> %d petak tepat"
		% [tier, baris_mixer, toko_min, dapat.size()])


## Skenario B: seluruh slot dijejalkan ke petak bersebelahan di cincin ubin
## paling tepi — cincin yang dulu runtuh. Yang dijaga: tidak ada dua perabot
## berbagi ubin, tidak ada mesh yang saling menembus, dan tidak ada yang hilang.
func _decor_crowd_case(world: ShopWorld, tier: int) -> void:
	GameState.location_tier = tier
	var loc: Dictionary = LocationDB.entry(tier)
	var dapur_max: int = EquipmentFactory.kitchen_row_max(tier)
	var toko_min: int = EquipmentFactory.shop_row_min(tier)
	var denah: Dictionary = {}
	var diminta: int = 0
	for i in int(loc.get("oven_slots", 1)):
		denah["%d,0" % i] = "oven"
		diminta += 1
	for i in int(loc.get("mixer_slots", 1)):
		denah["%d,%d" % [i, mini(1, dapur_max)]] = "mixer"
		diminta += 1
	for i in int(loc.get("rack_slots", 1)):
		denah["%d,%d" % [i, toko_min]] = "display"
		diminta += 1

	GameState.decor.clear()
	GameState.decor["grid"] = {
		"w": EquipmentFactory.floor_cols(tier),
		"h": EquipmentFactory.floor_rows(tier),
		"cell": TILE}
	GameState.decor["layout"] = denah
	world.rebuild()

	var huni: Dictionary = {}
	var kotak: Array[AABB] = []
	var bentrok: Array[String] = []
	var jumlah: int = 0
	for nama_v in [["mixer", world.mixer_pos, GameState.mixer_tier],
			["oven", world.oven_pos, GameState.oven_tier],
			["display", world.display_pos, GameState.display_tier]]:
		var jenis: String = String((nama_v as Array)[0])
		var jejak: Vector2i = EquipmentFactory.footprint(jenis, int((nama_v as Array)[2]))
		for p_v in ((nama_v as Array)[1] as Array):
			jumlah += 1
			bentrok.append_array(_huni_jejak(
				huni, _anchor_of(tier, p_v as Vector3, jejak), jejak, jenis))

	# Tabrakan mesh sesungguhnya, bukan cuma ubin.
	for child in world.fixtures.get_children():
		var n := child as Node3D
		if n == null:
			continue
		var cocok: bool = false
		for pre in ["Mixer", "Oven", "Display"]:
			if String(n.name).begins_with(pre):
				cocok = true
				break
		if not cocok:
			continue
		var b: AABB = _world_aabb(n)
		if b.size == Vector3.ZERO:
			continue
		var datar := AABB(Vector3(b.position.x, 0.0, b.position.z),
			Vector3(b.size.x, 1.0, b.size.z)).grow(-0.03)
		for lain in kotak:
			if datar.intersects(lain):
				bentrok.append("mesh %s menembus perabot lain" % n.name)
				break
		kotak.append(datar)

	_ok("T%d denah berdempetan: tidak ada yang menumpuk%s"
		% [tier, "" if bentrok.is_empty() else " — " + ", ".join(bentrok)],
		bentrok.is_empty())
	_ok("T%d denah berdempetan: tidak ada perabot hilang (%d dari %d)"
		% [tier, jumlah, diminta], jumlah == diminta)
	print("  T%d berdempetan: %d perabot diminta, %d berdiri, %d ubin berbeda"
		% [tier, diminta, jumlah, huni.size()])


## Perabot harus bisa DIPUTAR, dan putarannya harus nyata di tiga tempat:
## jejak petaknya tertukar, badan mesh-nya benar-benar berputar di dunia 3D, dan
## rotasinya bertahan saat denah disimpan lalu dimuat lagi.
##
## Rak display 2 x 1 adalah kasus utamanya: diputar ia menjadi 1 x 2, dan sebuah
## rak yang "diputar" tapi jejaknya tidak ikut bertukar akan menembus perabot di
## petak sebelahnya tanpa ada satu pun angka yang terlihat keliru.
func _check_rotation() -> void:
	print("
-- Rotasi Perabot --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		GameState.location_tier = tier
		var cols: int = EquipmentFactory.floor_cols(tier)
		var rows: int = EquipmentFactory.floor_rows(tier)
		var baris: int = EquipmentFactory.shop_row_min(tier)
		var dasar: Vector2i = EquipmentFactory.footprint("display", GameState.display_tier)

		GameState.decor.clear()
		GameState.decor["grid"] = {"w": cols, "h": rows, "cell": TILE}
		GameState.decor["layout"] = {"0,%d" % baris: {"kind": "display", "rot": 90}}
		world.rebuild()

		_ok("T%d rotasi rak tersimpan di dunia" % tier,
			not world.display_rot.is_empty() and world.display_rot[0] == 90)
		var jejak: Vector2i = EquipmentFactory.footprint_rotated(
			"display", GameState.display_tier, 90)
		_ok("T%d jejak rak diputar = %dx%d (dari %dx%d)"
			% [tier, jejak.x, jejak.y, dasar.x, dasar.y],
			jejak == Vector2i(dasar.y, dasar.x))

		# Badan mesh-nya benar-benar berputar, bukan cuma angka rotasinya.
		if not world._displays.is_empty():
			var n: Node3D = world._displays[0]
			var b: AABB = _world_aabb(n)
			_ok("T%d badan rak ikut berputar (dalam %.2f > lebar %.2f m)"
				% [tier, b.size.z, b.size.x], b.size.z > b.size.x)
			_ok("T%d rak terputar tetap di dalam ruangan" % tier,
				b.position.x > -EquipmentFactory.room_width(tier) * 0.5 - 0.01
				and b.position.x + b.size.x < EquipmentFactory.room_width(tier) * 0.5 + 0.01)

		# Anchor tetap petak yang dipilih, walau jejaknya sudah tertukar.
		if not world.display_pos.is_empty():
			_ok("T%d rak terputar tetap di petak pilihannya" % tier,
				_anchor_of(tier, world.display_pos[0], jejak) == Vector2i(0, baris))

		# --- Tombol Putar di Mode Dekorasi mengembalikannya ke 2x1 ---
		var dekor: DecorController = world.decor_controller()
		dekor.mulai()
		dekor.pilih("display", 0)
		var huni_sebelum: int = _petak_terhuni(world, "display", 0)
		dekor.putar()
		var huni_sesudah: int = _petak_terhuni(world, "display", 0)
		_ok("T%d memutar di Mode Dekorasi mengembalikan rotasi ke 0" % tier,
			world.decor_rot_of("display", 0) == 0)
		_ok("T%d jumlah petak terhuni tetap %d setelah diputar (%d -> %d)"
			% [tier, dasar.x * dasar.y, huni_sebelum, huni_sesudah],
			huni_sebelum == dasar.x * dasar.y and huni_sesudah == dasar.x * dasar.y)
		dekor.batal_pilih()
		dekor.selesai()

		print("  T%d: rak %dx%d -> diputar %dx%d, %d petak terhuni"
			% [tier, dasar.x, dasar.y, jejak.x, jejak.y, huni_sesudah])

	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()


## Berapa petak yang dihuni satu perabot menurut dunia 3D.
func _petak_terhuni(world: ShopWorld, kind: String, index: int) -> int:
	var n: int = 0
	var id: String = "%s:%d" % [kind, index]
	for v in world.decor_occupancy().values():
		if String(v) == id:
			n += 1
	return n


## Menyentuh BADAN perabot harus memilih perabot itu, bukan penghuni ubin di
## bawah kursor.
##
## Pada pandangan isometrik keduanya berbeda jauh: badan oven tergambar di atas
## ubinnya sendiri, jadi sinar dari puncak oven menembus lantai satu-dua baris
## DI BELAKANGNYA. Selama pemilihan memakai ubin, pemain mengetuk oven dan yang
## terangkat justru rak di belakangnya.
##
## Tes ini juga membuktikan dirinya sendiri tidak sia-sia: ia menghitung berapa
## perabot yang titik badannya memetakan ke ubin milik orang lain (atau ke
## lantai kosong), dan menuntut jumlah itu lebih dari nol. Kalau suatu hari
## kamera berubah jadi tegak lurus dari atas, kedua cara menjadi sama dan tes
## ini akan berteriak alih-alih lulus diam-diam.
## Gudang Penyimpanan: perabot yang jejaknya ikut tier LOKASI, dan satu-satunya
## pintu masuk ke Buku Resep sejak tombol "Resep" dicabut dari Quick Menu.
##
## Yang dijaga di sini adalah rantai yang menghubungkan keduanya:
##   - gudang benar-benar terpasang di setiap tier, di zona DAPUR, dengan jejak
##     yang persis sama dengan tabel EquipmentFactory untuk tier toko itu;
##   - mengetuk badannya melaporkan ketukan sebagai "storage";
##   - menyeret jari (bukan mengetuk) TIDAK melaporkan apa-apa — kalau tidak,
##     setiap usaha menggeser layar akan membuka Buku Resep;
##   - selama Mode Dekorasi ketukan itu diam, karena di sana ketukan berarti
##     "pilih perabot untuk digeser".
## Mengetuk perabot yang TIDAK sedang menunggu pekerjaan tetap memanggil karakter.
##
## Perabot di dunia 3D adalah tombolnya sendiri. Tombol yang kadang menjawab
## kadang tidak membuat pemain mengira ketukannya tidak terbaca -- jadi ketukan
## kosong pun harus menghasilkan sesuatu yang kasatmata: karakter berjalan ke
## sana dan berdiri di situ.
##
## Yang dijaga di sini justru batas-batasnya, karena itu yang gampang rusak:
## kunjungan kosong tidak boleh melahirkan pesanan atau job, tidak boleh
## menggeser giliran tugas KERJA, dan ketukan beruntun tidak boleh menumpuk
## menjadi tur keliling dapur.
func _check_hampiri_perabot() -> void:
	print("\n-- Menghampiri Perabot yang Diketuk --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	if world == null or pt == null or prod == null:
		_ok("sistem tugas pemain tersedia", false)
		return

	_siapkan_dapur(world, pt, prod)
	var aktor: PlayerActor = world.player_actor()
	if aktor == null:
		_ok("karakter pemain tersedia", false)
		return

	# --- 1. Ketukan pada mixer kosong memanggil karakter ke sana ---
	var mixer: Vector3 = world.stand_spot("mixer", 0, aktor.global_position)
	var jauh_awal: float = aktor.global_position.distance_to(mixer)
	_ok("mixer kosong itu memang belum dihampiri", jauh_awal > PlayerTaskSystem.DEKAT)
	_ok("ketukan mixer tanpa pesanan tetap diterima", pt.tap("mixer", 0))
	_ok("kunjungan kosong tidak melahirkan pesanan", pt.order_count() == 0)
	_ok("kunjungan kosong tidak melahirkan job produksi", prod.jobs().is_empty())

	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 25.0)
	_ok("karakter berdiri di depan mixer yang diketuk (%.2f m)"
		% aktor.global_position.distance_to(mixer),
		aktor.global_position.distance_to(mixer) < PlayerTaskSystem.DEKAT)
	_ok("setelah menghampiri, tidak ada pesanan yang tercipta", pt.order_count() == 0)

	# --- 2. Mengetuk perabot yang sudah dihampiri tidak mengulang apa-apa ---
	_ok("ketukan ulang pada perabot yang sudah dihampiri diabaikan",
		not pt.tap("mixer", 0))
	_ok("karakter tidak diberi tugas baru", not pt.is_busy())

	# --- 3. Ketukan beruntun: yang TERAKHIR yang dituruti, bukan semuanya ---
	if world.station_points("oven").size() > 0 \
			and world.station_points("display").size() > 0:
		var oven: Vector3 = world.stand_spot("oven", 0, aktor.global_position)
		var rak: Vector3 = world.stand_spot("display", 0, aktor.global_position)
		_ok("ketukan oven diterima", pt.tap("oven", 0))
		_ok("ketukan rak menyusul diterima", pt.tap("display", 0))
		_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 40.0)
		var ke_rak: float = aktor.global_position.distance_to(rak)
		var ke_oven: float = aktor.global_position.distance_to(oven)
		_ok("karakter berhenti di rak, ketukan terakhir (%.2f m)" % ke_rak,
			ke_rak < PlayerTaskSystem.DEKAT)
		_ok("karakter tidak berkeliling lewat oven dulu", ke_rak < ke_oven)

	# --- 4. Tugas KERJA tidak pernah digeser kunjungan kosong ---
	var rid: String = _resep_uji(prod)
	if rid != "":
		_ok("resep terpesan untuk uji giliran", pt.choose_recipe(rid, 1))
		var oid: int = int((pt.orders()[0] as Dictionary).get("id", -1))
		# Ketukan kerja pada mixer, lalu ketukan kosong pada rak menyusulnya.
		_ok("ketukan kerja pada mixer diterima", pt.tap("mixer", 0))
		_ok("ketukan kosong pada rak ikut diantre", pt.tap("display", 0))
		_pompa_sampai(world, func() -> bool:
			return _state_pesanan(pt, oid) == PlayerTaskSystem.STATE_BEKERJA, 30.0)
		_ok("adonan tetap teraduk walau ada kunjungan kosong mengantre",
			_state_pesanan(pt, oid) == PlayerTaskSystem.STATE_BEKERJA)
		_ok("job produksi benar-benar lahir", not prod.jobs().is_empty())

	print("  ketukan kosong memanggil karakter tanpa menyentuh antrean produksi")
	_bersihkan_dapur(pt, prod)


## Mengetuk meja kasir menyuruh karakter berjaga, dan selama ia berjaga ia yang
## melayani pembeli (GDD 3.0.C Mode Solo).
##
## Yang diuji bukan cuma "ia sampai di meja", melainkan akibat ekonominya: tanpa
## kasir yang disewa, pembeli hanya terlayani bila karakter benar-benar berdiri
## di mejanya. Itu seluruh arti fiturnya — kalau transaksi tetap jalan saat ia
## pergi, mengetuk meja kasir tidak berarti apa-apa.
## Alur pembeli fisik dari pintu sampai membayar (GDD 2 "Tahap Jualan").
##
## Yang diuji di sini bukan "apakah pembeli terlayani" — itu urusan
## _check_kasir_manual() — melainkan URUTANNYA: roti berpindah tangan di RAK,
## bukan di meja kasir, dan roti yang sudah terlanjur diambil wajib kembali ke
## raknya begitu pembelinya batal membayar.
##
## Invarian pokoknya satu kalimat: selama belum ada yang membayar, jumlah roti
## di rak DITAMBAH roti di tangan seluruh pembeli tidak pernah berubah. Tanpa
## penjaga ini, pembeli yang kehabisan kesabaran diam-diam memusnahkan stok dan
## baru ketahuan berhari-hari kemudian sebagai "roti sisa" yang tidak masuk akal.
func _check_alur_pembeli() -> void:
	print("\n-- Alur Pembeli: Rak -> Kasir -> Bayar --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	var day: DayCycle = _main.systems.get("day") as DayCycle
	var cust: CustomerSim = _main.systems.get("cust") as CustomerSim
	if world == null or pt == null or prod == null or day == null or cust == null:
		_ok("sistem tersedia untuk uji alur pembeli", false)
		return

	_siapkan_dapur(world, pt, prod)
	_siapkan_toko_ramai()
	var rid: String = _resep_uji(prod)
	if rid == "":
		_ok("ada resep untuk diisi ke rak", false)
		return

	_maju_ke_jualan(world, day)
	_ok("toko sudah masuk tahap jualan", day.phase == GameConfig.PHASE_SELL)

	GameState.display_slots.clear()
	GameState.display_add(rid, 40, ProductionSystem.QUALITY_PRIME, day.hour)
	var stok_awal: int = GameState.display_total()
	_ok("rak terisi %d roti sebelum toko didatangi" % stok_awal, stok_awal > 0)
	_ok("karakter pemain sedang TIDAK berjaga di kasir", pt.manning_lane() < 0)

	# --- 1. Roti diambil DI RAK, bukan di meja kasir ---
	_pompa_sampai(world, func() -> bool:
		return not _pembeli_antre(cust).is_empty(), 120.0)
	var c: Dictionary = _pembeli_antre(cust)
	_ok("ada pembeli yang sudah masuk antrean kasir", not c.is_empty())
	_ok("pembeli mengantre sambil MEMBAWA rotinya (%d buah)" % _isi_keranjang(c),
		_isi_keranjang(c) > 0)
	_ok("stok rak sudah berkurang sejak ia masih berjalan ke kasir",
		GameState.display_total() < stok_awal)

	# --- 2. Balon "!" muncul di atas kepalanya, bukan di atas perabot ---
	var cid: int = int(c.get("id", -1))
	_ok("pembeli itu tercatat menunggu ketukan pemain",
		cust.waiting_for_player().has(cid))
	_pompa_sampai(world, func() -> bool:
		var a: CustomerActor = _aktor_pembeli(world, cid)
		return a != null and a.has_alert(), 20.0)
	var aktor_c: CustomerActor = _aktor_pembeli(world, cid)
	_ok("balon '!' tampil di atas pembeli yang sudah berdiri di meja",
		aktor_c != null and aktor_c.has_alert())
	_ok("rotinya TERLIHAT di tangannya, bukan sekadar angka di simulasi",
		aktor_c != null and aktor_c.has_belanjaan())

	# Ketukan layar pada badan/balonnya memang mengenai PEMBELI, bukan perabot
	# di belakangnya.
	if aktor_c != null and world.camera != null:
		var titik: Vector2 = world.camera.unproject_position(
			aktor_c.global_position + Vector3(0.0, CustomerActor.ALERT_Y, 0.0))
		var kena: Dictionary = world.tap_pick_at_screen(titik)
		_ok("ketukan pada balon terbaca sebagai pembeli, bukan perabot",
			String(kena.get("kind", "")) == PlayerTaskSystem.STATION_CUSTOMER
				and int(kena.get("index", -1)) == cid)

	# --- 3. Balon hanya membuka popup bila pemain berdiri di mejanya ---
	var diminta: Array = []
	var tangkap := func(id: int) -> void: diminta.append(id)
	pt.customer_requested.connect(tangkap)

	_ok("ketukan balon dari dapur tetap dilayani", pt.tap(
		PlayerTaskSystem.STATION_CUSTOMER, cid))
	_ok("tapi popup pesanan TIDAK terbuka dari seberang dapur", diminta.is_empty())
	_pompa_sampai(world, func() -> bool: return pt.manning_lane() == 0, 30.0)
	_ok("ketukan itu menyuruh karakter berjalan ke meja kasir",
		pt.manning_lane() == 0)

	# Pembeli bisa saja sudah pulang selama karakter berjalan; yang diuji di
	# sini adalah siapa pun yang sedang menunggu sekarang.
	var menunggu: Array[int] = cust.waiting_for_player()
	if menunggu.is_empty():
		_pompa_sampai(world, func() -> bool:
			return not cust.waiting_for_player().is_empty(), 90.0)
		menunggu = cust.waiting_for_player()
	var cid2: int = menunggu[0] if not menunggu.is_empty() else -1
	diminta.clear()
	_ok("ketukan balon saat berjaga diterima",
		cid2 >= 0 and pt.tap(PlayerTaskSystem.STATION_CUSTOMER, cid2))
	_ok("popup pesanan terbuka untuk pembeli yang tepat",
		diminta.size() == 1 and int(diminta[0]) == cid2)
	pt.customer_requested.disconnect(tangkap)

	# Layar popupnya benar-benar dibangun Main — sistem sim tidak pernah
	# memanggil ScreenRouter sendiri (ARCHITECTURE 7.0.1) — dan isinya memang
	# belanjaan pembeli itu, bukan angka kosong.
	_ok("layar 'customer_order' terbuka lewat ScreenRouter",
		ScreenRouter.current == "customer_order")
	if cid2 >= 0:
		var total: float = 0.0
		var isi: Dictionary = cust.customer(cid2).get("basket", {})
		for k: Variant in isi:
			total += GameState.recipe_price(String(k)) * float(isi[k])
		_ok("popup menampilkan total belanja %s" % GameConfig.kr(total),
			_ada_teks(ScreenRouter, GameConfig.kr(total)))
	ScreenRouter.go("hud")

	# --- 4. Roti yang tidak jadi dibayar KEMBALI ke rak ---
	# Karakter sengaja ditarik ke dapur supaya tidak ada satu pun transaksi yang
	# selesai: seluruh pembeli akan pulang marah, dan seluruh rotinya wajib
	# kembali utuh ke etalase.
	pt.tap("mixer", 0)
	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 30.0)
	var seimbang: bool = true
	var marah: Array = [0]
	var hitung_marah := func(_c: Dictionary, _r: String) -> void: marah[0] += 1
	EventBus.customer_left_angry.connect(hitung_marah)
	for _i: int in range(int(140.0 / DT)):
		_main.step(DT)
		world.tick_world(DT)
		if GameState.display_total() + _roti_di_tangan(cust) != stok_awal:
			seimbang = false
			break
	EventBus.customer_left_angry.disconnect(hitung_marah)
	_ok("roti tidak pernah lenyap: isi rak + isi tangan pembeli tetap %d"
		% stok_awal, seimbang)
	_ok("memang ada pembeli yang pulang marah selama uji (%d orang)" % marah[0],
		marah[0] > 0)

	# Pukul 18:00 pintu ditutup: pembeli yang masih di dalam pulang membawa apa
	# pun yang ada di tangannya, dan seluruhnya wajib kembali ke rak. Ditutup
	# paksa, bukan ditunggu, karena pembeli baru terus berdatangan selama toko
	# masih buka dan "tangan semua orang kosong" tidak pernah benar-benar terjadi.
	day.end_day()
	_ok("tidak ada lagi pembeli di dalam toko setelah tutup",
		cust.queue_length() == 0)
	_ok("seluruh roti kembali ke rak setelah toko tutup (%d dari %d)"
		% [GameState.display_total(), stok_awal],
		GameState.display_total() == stok_awal)

	print("  %d roti di rak, %d pembeli pulang marah, tidak satu pun roti hilang"
		% [GameState.display_total(), marah[0]])

	_bersihkan_dapur(pt, prod)
	day.start_day()


## Pembeli pertama yang sudah berdiri di antrean kasir; {} bila belum ada.
func _pembeli_antre(cust: CustomerSim) -> Dictionary:
	for e: Variant in cust.customers():
		var c: Dictionary = e
		if String(c.get("state", "")) == "antre":
			return c
	return {}


## Jumlah roti di keranjang satu pembeli.
func _isi_keranjang(c: Dictionary) -> int:
	var n: int = 0
	for k: Variant in (c.get("basket", {}) as Dictionary):
		n += int((c["basket"] as Dictionary)[k])
	return n


## Jumlah roti yang sedang dipegang SELURUH pembeli di dalam toko.
func _roti_di_tangan(cust: CustomerSim) -> int:
	var n: int = 0
	for e: Variant in cust.customers():
		n += _isi_keranjang(e)
	return n


## Layar resep, karyawan, dan iklan adalah POPUP, bukan layar penuh.
##
## Dua hal yang diuji, dan keduanya pernah rusak sendiri-sendiri:
##
##   1. HUD di belakangnya TETAP TERLIHAT. Itulah bedanya popup dengan layar
##      penuh — pemain tidak boleh kehilangan pandangan atas oven yang sedang
##      memanggang hanya karena ia membuka daftar karyawan.
##   2. Kartunya TIDAK MELAR melewati ukuran patokan. Ukuran minimum isi diukur
##      langsung: sebuah label panjang yang lupa dibungkus akan mendorong kartu
##      melewati tepi layar, dan tepi yang lewat itu tidak bisa digulir kembali.
func _check_popup_layar() -> void:
	print("\n-- Popup: Resep / Karyawan / Iklan --")
	ScreenRouter.go("hud")
	var hud: Control = _layar_hidup("hud")
	_ok("HUD tersedia sebagai latar popup", hud != null)

	for nama: String in ["recipe_book", "staff", "marketing"]:
		_ok("'%s' terdaftar sebagai popup" % nama,
			ScreenRouter.POPUP_SCREENS.has(nama))
		ScreenRouter.go(nama)
		_ok("popup '%s' terbuka" % nama, ScreenRouter.current == nama)
		_ok("HUD tetap terlihat di belakang popup '%s'" % nama,
			hud != null and hud.visible)

		var layar: Control = _layar_hidup(nama)
		var kartu: Control = _kartu_popup(layar)
		_ok("popup '%s' memakai kartu popup bersama" % nama, kartu != null)
		if kartu != null:
			var minimum: Vector2 = kartu.get_combined_minimum_size()
			_ok("kartu '%s' tidak melar melebihi lebar patokan (%.0f <= %.0f px)"
				% [nama, minimum.x, ProceduralUIFactory.POPUP_SIZE.x],
				minimum.x <= ProceduralUIFactory.POPUP_SIZE.x + 0.5)
			_ok("kartu '%s' tidak melar melebihi tinggi patokan (%.0f <= %.0f px)"
				% [nama, minimum.y, ProceduralUIFactory.POPUP_SIZE.y],
				minimum.y <= ProceduralUIFactory.POPUP_SIZE.y + 0.5)

		if kartu != null:
			var m: Vector2 = kartu.get_combined_minimum_size()
			print("  %s: isi minimum %.0f x %.0f px di dalam kartu %.0f x %.0f"
				% [nama, m.x, m.y, ProceduralUIFactory.POPUP_SIZE.x,
					ProceduralUIFactory.POPUP_SIZE.y])

		ScreenRouter.back()
		_ok("popup '%s' menutup kembali ke HUD" % nama,
			ScreenRouter.current == "hud" and hud != null and hud.visible)

	# Buku resep harus memperlihatkan ISI GUDANG, bukan cuma totalnya (permintaan
	# pemain: "tampilkan juga sisa bahan baku yang dimiliki").
	GameState.pantry["tepung_terigu"] = 42
	ScreenRouter.go("recipe_book")
	var resep: Control = _layar_hidup("recipe_book")
	_ok("popup resep menampilkan sisa bahan yang dimiliki",
		_ada_teks(resep, "%s 42" % String(
			IngredientDB.entry("tepung_terigu").get("name", "tepung_terigu"))))
	ScreenRouter.back()
	ScreenRouter.go("hud")
	print("  tiga popup tampil di atas HUD tanpa menutupinya")


## Menu dalam permainan (suara / simpan & ke menu utama / keluar).
##
## Tiga hal yang diperiksa, dan ketiganya gampang lepas diam-diam:
##
##   1. Menu adalah POPUP yang MENJEDA waktu selama terbuka, lalu MENGEMBALIKAN
##      keadaan jeda seperti semula saat ditutup. Menu yang lupa melepas jeda
##      membuat permainan tampak macet total sesudah pemain mengatur suara.
##   2. Tombol suara benar-benar membalik AudioBus.muted, dan labelnya ikut
##      berubah — tombol yang teksnya beku membuat pemain menekan dua kali dan
##      malah menyalakan suara yang baru saja ia matikan.
##   3. Preferensi suara ditulis ke user://settings.cfg, BUKAN ke savegame:
##      pemain yang mematikan suara lalu menekan "Main Baru" tetap dapat
##      permainan yang diam.
func _check_menu_ingame() -> void:
	print("
-- Menu dalam permainan --")
	var day: DayCycle = _main.systems.get("day") as DayCycle
	if day == null:
		_ok("DayCycle tersedia untuk uji menu", false)
		return

	ScreenRouter.go("hud")
	var hud: Control = _layar_hidup("hud")
	day.set_paused(false)

	_ok("'settings' terdaftar sebagai popup",
		ScreenRouter.POPUP_SCREENS.has("settings"))
	ScreenRouter.go("settings")
	_ok("menu terbuka", ScreenRouter.current == "settings")
	_ok("HUD tetap terlihat di belakang menu", hud != null and hud.visible)

	var layar: Control = _layar_hidup("settings")
	var kartu: Control = _kartu_popup(layar)
	_ok("menu memakai kartu popup bersama", kartu != null)
	if kartu != null:
		var minimum: Vector2 = kartu.get_combined_minimum_size()
		_ok("kartu menu tidak melar melebihi lebar patokan (%.0f <= %.0f px)"
			% [minimum.x, SettingsScreen.CARD_SIZE.x],
			minimum.x <= SettingsScreen.CARD_SIZE.x + 0.5)
		_ok("kartu menu tidak melar melebihi tinggi patokan (%.0f <= %.0f px)"
			% [minimum.y, SettingsScreen.CARD_SIZE.y],
			minimum.y <= SettingsScreen.CARD_SIZE.y + 0.5)

	_ok("waktu dijeda selama menu terbuka", day.is_paused())

	# --- Tombol suara ---
	var semula: bool = AudioBus.muted
	_ok("label suara sesuai keadaan awal",
		_ada_teks(layar, "Mati" if semula else "Nyala"))
	_tekan_tombol(layar, "Mati" if semula else "Nyala")
	_ok("tombol suara membalik keadaan senyap", AudioBus.muted != semula)
	_ok("label suara ikut berubah",
		_ada_teks(layar, "Nyala" if semula else "Mati"))

	var cfg := ConfigFile.new()
	_ok("preferensi suara ditulis ke %s" % AudioBus.SETTINGS_PATH,
		cfg.load(AudioBus.SETTINGS_PATH) == OK
			and bool(cfg.get_value("audio", "muted", not AudioBus.muted)) == AudioBus.muted)
	_ok("preferensi suara TIDAK ikut masuk savegame",
		not GameState.to_dict().has("muted"))

	# Dikembalikan supaya uji berikutnya tetap berjalan dengan suara semula.
	AudioBus.set_muted(semula)

	# --- Konfirmasi keluar ---
	_tekan_tombol(layar, "Simpan & ke Menu Utama")
	_ok("aksi keluar minta konfirmasi dulu",
		_ada_teks(layar, "Ya, ke Menu Utama") and _ada_teks(layar, "Batal"))
	_tekan_tombol(layar, "Batal")
	_ok("Batal mengembalikan daftar menu", _ada_teks(layar, "Lanjut Main"))

	# --- Menutup menu mengembalikan waktu berjalan ---
	_tekan_tombol(layar, "Lanjut Main")
	_ok("menu tertutup kembali ke HUD",
		ScreenRouter.current == "hud" and hud != null and hud.visible)
	_ok("waktu berjalan lagi setelah menu ditutup", not day.is_paused())

	# Jeda milik PEMAIN harus bertahan: menu tidak boleh diam-diam melanjutkan
	# permainan yang sengaja ia hentikan.
	day.set_paused(true)
	ScreenRouter.go("settings")
	ScreenRouter.back()
	_ok("jeda pilihan pemain tetap bertahan setelah menu ditutup", day.is_paused())
	day.set_paused(false)
	ScreenRouter.go("hud")
	print("  menu menjeda waktu selagi terbuka, mengembalikannya saat ditutup;"
		+ " suara tersimpan di %s" % AudioBus.SETTINGS_PATH)


## Menekan tombol pertama yang teksnya PERSIS `teks` di dalam `akar`.
func _tekan_tombol(akar: Node, teks: String) -> bool:
	var antrean: Array[Node] = [akar]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var b := n as Button
		if b != null and b.text == teks:
			b.pressed.emit()
			return true
	_ok("tombol '%s' ada" % teks, false)
	return false


## Tab "Lamaran" di layar Karyawan harus benar-benar bisa dibuka.
##
## Uji ini lahir dari crash yang dilaporkan pemain: StaffSim.roster()
## mengembalikan Dictionary sementara StaffScreen memperlakukannya sebagai ID
## ("Nonexistent 'String' constructor"). Bug itu TIDAK pernah tertangkap karena
## layar ini punya jalur cadangan `StaffDB.by_role()` yang bentuknya benar —
## jadi ia bekerja sempurna selama StaffSim belum terpasang, dan runtuh persis
## di permainan sungguhan.
##
## Yang dikunci di sini dua-duanya: bentuk data dari kedua sumber harus SAMA,
## dan keempat tab layar harus bisa dibuka tanpa menghilangkan isinya.
func _check_layar_karyawan() -> void:
	print("\n-- Layar Karyawan: tab lamaran --")
	var staff: StaffSim = _main.systems.get("staff") as StaffSim
	if staff == null:
		_ok("StaffSim tersedia", false)
		return

	for role: String in [StaffDB.ROLE_KASIR, StaffDB.ROLE_BAKER]:
		var dari_sim: Array = staff.roster(role)
		var dari_db: Array = StaffDB.roster(role, GameState.location_tier)
		_ok("roster '%s' dari StaffSim tidak kosong" % role, not dari_sim.is_empty())
		var semua_id: bool = true
		for e: Variant in dari_sim:
			if not (e is String) or StaffDB.entry(String(e)).is_empty():
				semua_id = false
		_ok("roster '%s' berisi ID staf, bukan entri Dictionary" % role, semua_id)
		_ok("bentuknya sama dengan StaffDB.roster() yang dibungkusnya",
			dari_sim.is_empty() or dari_db.is_empty()
				or typeof(dari_sim[0]) == typeof(dari_db[0]))

	# Layarnya benar-benar dibuka dan keempat tabnya ditekan, persis seperti
	# jari pemain. Tab lamaran inilah yang dulu melempar error.
	ScreenRouter.go("staff")
	var layar: Control = _layar_hidup("staff")
	_ok("layar karyawan terbuka", layar != null and ScreenRouter.current == "staff")
	if layar == null:
		return
	for tab: Array in [["kasir", "aktif"], ["baker", "aktif"],
			["kasir", "lamar"], ["baker", "lamar"]]:
		layar.call("_on_tab", String(tab[0]), String(tab[1]))
		var isi: Variant = layar.get("_content")
		_ok("tab %s/%s terisi (%d baris)"
			% [String(tab[0]), String(tab[1]),
				(isi as Node).get_child_count() if isi is Node else -1],
			isi is Node and (isi as Node).get_child_count() > 0)

	# Satu nama pelamar sungguhan harus muncul di daftar lamaran kasir.
	layar.call("_on_tab", StaffDB.ROLE_KASIR, "lamar")
	var kandidat: String = _kasir_termurah()
	var nama: String = String(StaffDB.entry(kandidat).get("name", ""))
	_ok("nama pelamar '%s' tampil di tab lamaran" % nama,
		nama.is_empty() or _ada_teks(layar, nama))

	ScreenRouter.back()
	ScreenRouter.go("hud")
	print("  empat tab layar karyawan terbuka tanpa error")


## Biaya etalase adalah beban BERDIRI: besarnya ditentukan JAM TOKO, bukan
## lamanya pemain duduk di depan layar.
##
## Penjaga ini ada karena satu konstanta bisa diam-diam menjungkirkan seluruh
## ekonomi: ditulis "KR per detik nyata", tagihan etalase ikut melar sepuluh
## kali lipat begitu satu jam in-game diperlambat dari 30 detik menjadi 5 menit
## — toko bangkrut tiap hari tanpa ada satu pun angka balans yang sengaja
## diubah. Mixer dan oven sengaja TIDAK ikut aturan ini: lama kerjanya memang
## ditulis dalam detik nyata oleh tabel resep GDD 5.3, jadi ongkos per batch-nya
## harus tetap sama.
func _check_beban_etalase() -> void:
	print("\n-- Beban Berdiri Etalase --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	var day: DayCycle = _main.systems.get("day") as DayCycle
	var econ: EconomySystem = _main.systems.get("econ") as EconomySystem
	if world == null or pt == null or prod == null or day == null or econ == null:
		_ok("sistem tersedia untuk uji beban etalase", false)
		return

	_siapkan_dapur(world, pt, prod)
	_maju_ke_jualan(world, day)
	day.set_time_scale(1.0)
	# Dapur dikosongkan: yang diukur hanya etalase, bukan mixer/oven yang bekerja.
	prod.reset()
	econ.reset()

	var rak: int = maxi(0, int(LocationDB.entry(GameState.location_tier).get("rack_slots", 0)))
	var langkah: int = 240
	for _i: int in range(langkah):
		econ.sim_tick(GameConfig.SECONDS_PER_GAME_HOUR / float(langkah), day.hour)

	var harap: float = GameConfig.UTILITY_DISPLAY_PER_HOUR * float(rak)
	var nyata: float = econ.utility_today()
	_ok("satu JAM TOKO menagih %.1f KR untuk %d rak (terukur %.1f)"
		% [harap, rak, nyata], absf(nyata - harap) < 0.01)

	var sehari: float = harap * (GameConfig.HOUR_CLOSE - GameConfig.HOUR_OPEN)
	_ok("tagihan sehari penuh masuk akal untuk toko Tier 1 (%s)"
		% GameConfig.kr(sehari), sehari > 0.0 and sehari < GameConfig.STARTING_COINS * 0.1)
	print("  %d rak: %s per jam toko -> %s per hari, tidak terikat kecepatan jam"
		% [rak, GameConfig.kr(harap), GameConfig.kr(sehari)])

	_bersihkan_dapur(pt, prod)
	day.start_day()


## Pesanan RotiFood: ketuk balon -> popup -> selesaikan (GDD 3.6.A).
##
## Uji ini lahir dari bug yang dilaporkan pemain: "klik pesanan RotiFood tidak
## terjadi apa-apa". Penyebabnya bukan logika pesanan, melainkan HUD yang
## MEMBANGUN ULANG seluruh tombol balon tiap 0,15 detik — tombol yang dibuang
## di sela jari menekan dan melepas tidak pernah sempat mengirim `pressed`.
##
## Karena itu yang dijaga di sini dua-duanya: tombolnya harus BERTAHAN antar
## penyegaran, dan menekannya harus benar-benar membuka popup lalu
## menyelesaikan pesanan sampai koin masuk.
func _check_pesanan_ojol() -> void:
	print("\n-- Pesanan RotiFood: Klik -> Popup -> Selesai --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	var day: DayCycle = _main.systems.get("day") as DayCycle
	var deliv: DeliverySim = _main.systems.get("deliv") as DeliverySim
	if world == null or pt == null or prod == null or day == null or deliv == null:
		_ok("sistem tersedia untuk uji pesanan ojol", false)
		return

	_siapkan_dapur(world, pt, prod)
	_siapkan_toko_ramai()
	var rid: String = _resep_uji(prod)
	if rid == "":
		_ok("ada resep untuk diisi ke rak", false)
		return

	_maju_ke_jualan(world, day)
	GameState.display_slots.clear()
	GameState.display_add(rid, 40, ProductionSystem.QUALITY_PRIME, day.hour)

	ScreenRouter.go("hud")
	var hud: HUD = _layar_hidup("hud") as HUD
	if hud == null:
		_ok("HUD tersedia sebagai pembawa balon pesanan", false)
		return

	# Satu pesanan dipaksa masuk: uji tidak boleh bergantung pada undian jam
	# kedatangan, tapi jalurnya tetap jalur sungguhan (_spawn_order).
	deliv.call("_spawn_order", day.hour)
	_ok("satu pesanan RotiFood masuk ke tablet", deliv.pending_count() > 0)
	if deliv.pending_count() <= 0:
		return
	var oid: int = int((deliv.orders()[0] as Dictionary).get("id", -1))

	# --- 1. Tombol balon BERTAHAN antar penyegaran (inti bug-nya) ---
	hud.call("_refresh")
	var b1: Button = _tombol_ojol(hud, oid)
	_ok("balon pesanan muncul di HUD", b1 != null)
	for _i: int in range(3):
		hud.call("_refresh")
	var b2: Button = _tombol_ojol(hud, oid)
	_ok("tombol balon TIDAK dibangun ulang tiap penyegaran",
		b1 != null and b2 != null and b1 == b2)
	_ok("tombol balon masih hidup setelah penyegaran berulang",
		b2 != null and is_instance_valid(b2))
	if b2 == null:
		return

	# --- 2. Ketukan membuka popup, bukan langsung beraksi diam-diam ---
	b2.pressed.emit()
	_ok("popup pesanan ojol terbuka", ScreenRouter.current == "delivery_order")
	var layar: Control = _layar_hidup("delivery_order")
	_ok("popup menyebut nomor pesanannya",
		_ada_teks(layar, "Pesanan RotiFood #%d" % oid))

	var items: Dictionary = deliv.order_by_id(oid).get("items", {})
	var baris_ada: bool = false
	for k: Variant in items:
		var nama: String = String(RecipeDB.entry(String(k)).get("name", String(k)))
		if _ada_teks(layar, "%s  x%d" % [nama, int(items[k])]):
			baris_ada = true
	_ok("popup merinci roti yang dipesan", baris_ada)

	# --- 2b. Balon yang sama juga menyala DI DUNIA 3D, di atas tablet ---
	ScreenRouter.go("hud")
	world.tick_world(DT)
	_ok("balon '!' menyala di atas tablet RotiFood", world.tablet_alert())
	if world.camera != null:
		var tablet_n: Node3D = world.get("_tablet") as Node3D
		var titik: Vector2 = world.camera.unproject_position(
			tablet_n.global_position + Vector3(0.0, ShopWorld.TABLET_ALERT_Y, 0.0))
		var kena: Dictionary = world.tap_pick_at_screen(titik)
		_ok("ketukan pada balon tablet terbaca sebagai tablet, bukan meja kasir",
			String(kena.get("kind", "")) == PlayerTaskSystem.STATION_TABLET
				and int(kena.get("index", -1)) == oid)
	var diminta: Array = []
	var tangkap := func(id: int) -> void: diminta.append(id)
	pt.delivery_requested.connect(tangkap)
	_ok("ketukan tablet diterima", pt.tap(PlayerTaskSystem.STATION_TABLET, oid))
	_ok("ketukan tablet membuka popup pesanan yang tepat",
		diminta.size() == 1 and int(diminta[0]) == oid)
	pt.delivery_requested.disconnect(tangkap)
	_ok("popup terbuka lewat jalur dunia 3D juga",
		ScreenRouter.current == "delivery_order")

	# --- 3. "Kemas Pesanan" benar-benar mengemas ---
	var aksi: Button = layar.get("_aksi_btn") as Button
	_ok("tombol aksi menawarkan pengemasan",
		aksi != null and aksi.text == "Kemas Pesanan" and not aksi.disabled)
	var stok_sebelum: int = GameState.display_total()
	if aksi != null:
		aksi.pressed.emit()
	_ok("pesanan tidak lagi berstatus 'masuk'",
		String(deliv.order_by_id(oid).get("state", "")) != "masuk")
	_ok("roti pesanan diambil dari etalase",
		GameState.display_total() < stok_sebelum)
	_ok("popup menutup kembali ke HUD", ScreenRouter.current == "hud")

	# --- 4. Driver tiba: popup yang sama menawarkan serah terima ---
	_pompa_sampai(world, func() -> bool:
		return String(deliv.order_by_id(oid).get("state", "")) == "driver_menunggu", 240.0)
	_ok("driver tiba dan menunggu di kasir",
		String(deliv.order_by_id(oid).get("state", "")) == "driver_menunggu")
	_cek_hadap_driver(world, oid)
	hud.call("_refresh")
	var b3: Button = _tombol_ojol(hud, oid)
	_ok("balon pesanan masih ada saat driver menunggu", b3 != null)
	if b3 == null:
		return
	b3.pressed.emit()
	_ok("popup terbuka lagi untuk serah terima",
		ScreenRouter.current == "delivery_order")
	var aksi2: Button = layar.get("_aksi_btn") as Button
	_ok("tombol aksi berubah menjadi serah terima",
		aksi2 != null and aksi2.text == "Serahkan ke Driver" and not aksi2.disabled)

	var koin: float = GameState.coins
	if aksi2 != null:
		aksi2.pressed.emit()
	_ok("uang pesanan masuk ke kas (%s -> %s)"
		% [GameConfig.kr(koin), GameConfig.kr(GameState.coins)],
		GameState.coins > koin)
	_ok("pesanan hilang dari tablet setelah diserahkan",
		deliv.order_by_id(oid).is_empty())
	_ok("popup menutup kembali ke HUD", ScreenRouter.current == "hud")
	hud.call("_refresh")
	_ok("balon pesanannya ikut hilang dari HUD", _tombol_ojol(hud, oid) == null)

	print("  pesanan #%d: klik balon -> kemas -> driver -> serahkan, kas +%s"
		% [oid, GameConfig.kr(GameState.coins - koin)])

	_bersihkan_dapur(pt, prod)
	day.start_day()


## Driver yang menunggu harus MENGHADAP KAMERA, bukan memunggunginya.
##
## Punggung driver adalah kotak ransel termal sebesar badannya. Driver yang
## berhenti menghadap -Z hanya memperlihatkan kardus hijau itu, dan model yang
## dibangun benar pun terbaca "terpasang terbalik" — persis keluhan yang masuk.
##
## Diuji sebagai ARAH HADAP terhadap kamera, bukan sebagai sudut tetap: kelak
## tempat jemputnya boleh pindah, yang tidak boleh berubah adalah wajahnya tetap
## terlihat. Sekalian dipastikan bagian depan modelnya memang di sisi -Z.
func _cek_hadap_driver(world: ShopWorld, order_id: int) -> void:
	var drv: DriverActor = _aktor_driver(world, order_id)
	_ok("aktor driver ada di dunia 3D", drv != null)
	if drv == null or world.camera == null:
		return

	var hadap: Vector3 = drv.global_transform.basis * Vector3(0.0, 0.0, -1.0)
	var ke_kamera: Vector3 = world.camera.global_position - drv.global_position
	ke_kamera.y = 0.0
	var sejajar: float = hadap.normalized().dot(ke_kamera.normalized())
	_ok("driver menunggu sambil menghadap kamera, bukan memunggunginya (%.2f)"
		% sejajar, sejajar > 0.3)

	var wajah: Node3D = CharacterFactory.part(drv.model, "Face")
	var ransel: Node3D = drv.find_child("ThermalBox", true, false) as Node3D
	if wajah != null and ransel != null:
		var ke_wajah: Vector3 = _world_aabb(wajah).get_center() - drv.global_position
		var ke_ransel: Vector3 = _world_aabb(ransel).get_center() - drv.global_position
		ke_wajah.y = 0.0
		ke_ransel.y = 0.0
		_ok("wajah driver di sisi yang menghadap kamera",
			ke_wajah.normalized().dot(ke_kamera.normalized()) > 0.0)
		_ok("ransel termal di sisi SEBERANG wajah (punggung)",
			ke_ransel.normalized().dot(ke_wajah.normalized()) < -0.5)

	print("  driver #%d berdiri di %s, wajahnya menghadap kamera (%.2f)"
		% [order_id, str(drv.global_position), sejajar])


## Aktor 3D driver ojol untuk satu pesanan; null bila ia sudah tidak di layar.
func _aktor_driver(world: ShopWorld, order_id: int) -> DriverActor:
	var raw: Variant = world.get("_drivers")
	if not (raw is Dictionary):
		return null
	return (raw as Dictionary).get(order_id) as DriverActor


## Tombol balon satu pesanan ojol di HUD; null bila tidak ada.
func _tombol_ojol(hud: HUD, order_id: int) -> Button:
	var raw: Variant = hud.get("_order_buttons")
	if not (raw is Dictionary):
		return null
	var b: Variant = (raw as Dictionary).get(order_id)
	if b == null or not is_instance_valid(b):
		return null
	return b as Button


## Instance layar yang sedang hidup di ScreenRouter; null bila belum dibangun.
func _layar_hidup(nama: String) -> Control:
	var raw: Variant = ScreenRouter.get("_live")
	if not (raw is Dictionary):
		return null
	return (raw as Dictionary).get(nama) as Control


## Kartu popup di dalam satu layar; null bila layar itu bukan popup.
func _kartu_popup(layar: Control) -> Control:
	if layar == null:
		return null
	for c in layar.get_children():
		if c is Control and (c as Control).has_meta("kartu"):
			return (c as Control).get_meta("kartu") as Control
	return null


## Apakah ada satu Label / Button keturunan `akar` yang teksnya PERSIS `teks`.
## Dipakai untuk memeriksa isi layar tanpa mengintip variabel dalamnya.
func _ada_teks(akar: Node, teks: String) -> bool:
	var antrean: Array[Node] = [akar]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var l := n as Label
		if l != null and l.text == teks:
			return true
		var b := n as Button
		if b != null and b.text == teks:
			return true
	return false


## Aktor 3D satu pembeli menurut idnya; null bila ia sudah tidak di layar.
func _aktor_pembeli(world: ShopWorld, cid: int) -> CustomerActor:
	var raw: Variant = world.get("_customers")
	if not (raw is Dictionary):
		return null
	return (raw as Dictionary).get(cid) as CustomerActor


func _check_kasir_manual() -> void:
	print("\n-- Berjaga di Meja Kasir --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	var day: DayCycle = _main.systems.get("day") as DayCycle
	if world == null or pt == null or prod == null or day == null:
		_ok("sistem tersedia untuk uji kasir", false)
		return

	_siapkan_dapur(world, pt, prod)
	_siapkan_toko_ramai()
	_ok("tidak ada kasir yang disewa (jalur manual aktif)",
		GameState.active_staff(StaffDB.ROLE_KASIR).is_empty())

	var aktor: PlayerActor = world.player_actor()
	if aktor == null:
		_ok("karakter pemain tersedia", false)
		return

	# --- 1. Meja kasir bisa diketuk, dan titik layannya di SISI DAPUR ---
	var layan: Vector3 = world.cashier_stand_spot(0)
	var meja: Vector3 = world.station_points(PlayerTaskSystem.STATION_CASHIER)[0]
	_ok("titik layan berada di sisi dapur meja, bukan di sisi pembeli",
		layan.z < meja.z)
	_ok("titik layan sejajar mesin kasirnya", absf(layan.x - meja.x) < 0.001)

	_ok("ketukan meja kasir diterima",
		pt.tap(PlayerTaskSystem.STATION_CASHIER, 0))
	_ok("belum berjaga selama masih berjalan", pt.manning_lane() < 0)
	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 30.0)
	_ok("karakter berdiri di titik layan (%.2f m)"
		% aktor.global_position.distance_to(layan),
		aktor.global_position.distance_to(layan) < PlayerTaskSystem.DEKAT)
	_ok("karakter berjaga di mesin kasir 0", pt.manning_lane() == 0)

	# Menghadap pembeli, bukan membelakangi mereka. Pembeli ada di arah +Z.
	var hadap: Vector3 = aktor.global_transform.basis * Vector3(0.0, 0.0, -1.0)
	_ok("karakter menghadap pembeli (+Z), bukan ke dapur (z hadap %.2f)" % hadap.z,
		hadap.z > 0.7)

	# --- 2. Melangkah pergi berarti berhenti melayani ---
	_ok("ketukan mixer memanggilnya pergi", pt.tap("mixer", 0))
	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 30.0)
	_ok("karakter berhenti berjaga setelah pergi dari meja", pt.manning_lane() < 0)

	# --- 3. Akibat ekonominya: pembeli hanya terlayani bila ia berjaga ---
	var rid: String = _resep_uji(prod)
	if rid == "":
		_ok("ada resep untuk diisi ke rak", false)
		return

	var terlayani: Array = [0]
	var hitung := func(_c: Dictionary, _r: float) -> void: terlayani[0] += 1
	EventBus.customer_served.connect(hitung)

	# Maju ke tahap jualan dengan rak yang penuh terisi. Tahap persiapan
	# dilewati dengan tombol percepat -- tidak ada pembeli sebelum pukul 08:00,
	# jadi mempercepatnya tidak mengubah apa pun yang sedang diuji.
	_maju_ke_jualan(world, day)
	_ok("toko sudah masuk tahap jualan", day.phase == GameConfig.PHASE_SELL)
	GameState.display_add(rid, 60, ProductionSystem.QUALITY_PRIME, day.hour)
	_ok("rak terisi roti untuk dijual", GameState.display_total() > 0)

	# A) Karakter JAUH dari meja: tidak ada transaksi sama sekali.
	var marah: Array = [0]
	var hitung_marah := func(_c: Dictionary, _r: String) -> void: marah[0] += 1
	EventBus.customer_left_angry.connect(hitung_marah)
	terlayani[0] = 0
	marah[0] = 0
	_pompa(world, 70.0)
	_ok("tanpa penjaga kasir, tidak ada satu pun pembeli terlayani (%d)"
		% terlayani[0], terlayani[0] == 0)
	# Antrean tidak diperiksa langsung: pembeli yang lama menunggu PERGI, jadi
	# antrean bisa saja kosong lagi saat diukur. Yang membuktikan toko memang
	# ramai adalah permintaan yang datang -- entah masih mengantre atau sudah
	# pulang marah karena tidak ada yang melayani.
	var permintaan: int = _antrean_kasir() + marah[0]
	_ok("toko memang kedatangan pembeli yang tidak terlayani (%d orang)"
		% permintaan, permintaan > 0)
	EventBus.customer_left_angry.disconnect(hitung_marah)

	# B) Karakter kembali berjaga -- TAPI diam saja. Balon pesanan yang belum
	#    diketuk tidak pernah berjalan sendiri (GDD 2: klik bubble, klik OK).
	pt.tap(PlayerTaskSystem.STATION_CASHIER, 0)
	_pompa_sampai(world, func() -> bool: return pt.manning_lane() == 0, 30.0)
	_ok("karakter kembali berjaga", pt.manning_lane() == 0)
	terlayani[0] = 0
	var cust: CustomerSim = _main.systems.get("cust") as CustomerSim
	if cust == null:
		_ok("CustomerSim tersedia untuk uji balon pesanan", false)
		EventBus.customer_served.disconnect(hitung)
		return
	_pompa_sampai(world, func() -> bool:
		return not cust.waiting_for_player().is_empty(), 90.0)
	_ok("ada pembeli yang menunggu dengan balon pesanan",
		not cust.waiting_for_player().is_empty())
	_pompa(world, 30.0)
	_ok("balon yang tidak diketuk tidak pernah melayani dirinya sendiri (%d)"
		% terlayani[0], terlayani[0] == 0)
	_ok("jalur kasir tetap menganggur selama balon belum diketuk",
		cust.serving_id(0) < 0)

	# C) Ketukan balon + OK: barulah roti dibungkus dan uang masuk.
	#    Pembeli yang tadi menunggu bisa saja keburu pulang selama 30 detik
	#    pembuktian di atas — yang dilayani adalah siapa pun yang menunggu kini.
	if cust.waiting_for_player().is_empty():
		_pompa_sampai(world, func() -> bool:
			return not cust.waiting_for_player().is_empty(), 90.0)
	var menunggu: Array[int] = cust.waiting_for_player()
	var cid: int = menunggu[0] if not menunggu.is_empty() else -1
	_ok("ketukan balon pembeli diterima saat berjaga",
		cid >= 0 and pt.tap(PlayerTaskSystem.STATION_CUSTOMER, cid))
	_ok("popup pesanan tahu isi keranjang pembeli",
		cid >= 0 and not (cust.customer(cid).get("basket", {}) as Dictionary).is_empty())
	_ok("konfirmasi OK memulai transaksi", cid >= 0 and cust.confirm_service(cid))
	_ok("jalur kasir sedang memproses pembeli itu",
		cid >= 0 and cust.serving_id(0) == cid)
	# Gerak membungkus disetel dunia 3D saat menyegarkan diri, bukan oleh
	# simulasi — satu detak dulu sebelum ia terlihat memegang kantong.
	_pompa(world, 0.2)
	_ok("karakter terlihat membungkus pesanan",
		aktor.is_wrapping() and aktor.carrying() == PlayerActor.CARRY_BAG)
	_pompa(world, 30.0)
	var dibayar: int = terlayani[0]
	_ok("pembeli yang dikonfirmasi akhirnya membayar (%d orang)" % dibayar,
		dibayar > 0)

	# D) Balon yang sama tidak bisa dikonfirmasi dua kali.
	_ok("konfirmasi ulang pembeli yang sudah dilayani ditolak",
		cid >= 0 and not cust.confirm_service(cid))

	# E) Dari seberang dapur, OK ditolak -- tangannya tidak sampai ke meja.
	terlayani[0] = 0
	pt.tap("mixer", 0)
	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 30.0)
	_pompa_sampai(world, func() -> bool:
		return not cust.waiting_for_player().is_empty(), 90.0)
	var jauh: Array[int] = cust.waiting_for_player()
	_ok("pembeli tetap menunggu walau pemain di dapur", not jauh.is_empty())
	_ok("OK ditolak saat karakter tidak berjaga di meja kasir",
		jauh.is_empty() or not cust.confirm_service(jauh[0]))
	_ok("tidak ada yang terbayar dari seberang dapur (%d)" % terlayani[0],
		terlayani[0] == 0)

	EventBus.customer_served.disconnect(hitung)
	print("  tanpa penjaga: 0 terlayani; balon tanpa ketukan: 0 terlayani; "
		+ "sesudah ditekan OK: %d terlayani" % dibayar)

	# --- 4. Meja kasir tetap TIDAK bisa dipindah di Mode Dekorasi ---
	_ok("meja kasir bukan perabot yang bisa digeser",
		not ShopWorld.DECOR_KINDS.has(PlayerTaskSystem.STATION_CASHIER))
	_ok("meja kasir tidak punya entri di daftar perabot yang bisa dipindah",
		world.decor_count(PlayerTaskSystem.STATION_CASHIER) == 0)

	_bersihkan_dapur(pt, prod)
	day.start_day()


## Meniru pemain yang menekan "Bungkus & Terima" pada setiap balon pesanan yang
## sedang menyala. Mengembalikan jumlah pesanan yang benar-benar mulai dibungkus.
func _layani_antrean() -> int:
	var cust: CustomerSim = _main.systems.get("cust") as CustomerSim
	if cust == null:
		return 0
	var n: int = 0
	for cid: int in cust.waiting_for_player():
		if cust.confirm_service(cid):
			n += 1
	return n


## Memajukan simulasi sambil terus menekan OK pada balon pesanan yang muncul.
func _pompa_melayani(world: ShopWorld, detik: float) -> void:
	for _i: int in range(int(detik / DT)):
		_layani_antrean()
		_main.step(DT)
		world.tick_world(DT)


## Berapa pembeli yang sedang mengantre di kasir.
func _antrean_kasir() -> int:
	var cust: CustomerSim = _main.systems.get("cust") as CustomerSim
	if cust == null:
		return 0
	return cust.queue_length()


## Memajukan simulasi dan dunia selama `detik`, tanpa syarat berhenti.
func _pompa(world: ShopWorld, detik: float) -> void:
	for _i: int in range(int(detik / DT)):
		_main.step(DT)
		world.tick_world(DT)


## Dengan Asisten Kasir yang disewa, pembeli dilayani OTOMATIS -- kehadiran
## karakter pemain tidak lagi diperlukan.
##
## Ini paruh kedua dari aturan meja kasir; paruh pertamanya ada di
## _check_kasir_manual(). Keduanya harus diuji bersama, karena yang menentukan
## rasa permainan justru PERBEDAAN di antara keduanya: menyewa kasir adalah
## satu-satunya hal yang membebaskan kaki pemain dari meja.
##
## Tanpa tes ini, gerbang pelayanan manual bisa saja diperketat sedikit demi
## sedikit sampai ikut membekukan jalur yang dijaga staf, dan tidak ada yang
## keberatan sampai pemain mengeluh kasirnya berdiri diam.
func _check_kasir_asisten() -> void:
	print("\n-- Meja Kasir Dijaga Asisten --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	var staff: StaffSim = _main.systems.get("staff") as StaffSim
	var day: DayCycle = _main.systems.get("day") as DayCycle
	if world == null or pt == null or prod == null or staff == null or day == null:
		_ok("sistem tersedia untuk uji asisten kasir", false)
		return

	_siapkan_dapur(world, pt, prod)
	_siapkan_toko_ramai()

	# --- Sewa satu Asisten Kasir termurah yang tersedia ---
	var kandidat: String = _kasir_termurah()
	_ok("ada kandidat Asisten Kasir di roster", kandidat != "")
	if kandidat == "":
		return

	# Modal dulu, baru merekrut. Karyawan yang direkrut SELAMA Mode Solo memang
	# langsung diliburkan (GDD 3.0.C), dan uji ini menguji meja kasir yang
	# dijaga asisten — bukan Mode Solo. BailoutSystem baru menilai ulang saldo
	# pada detak berikutnya, jadi simulasi dimajukan sebentar sampai padam.
	GameState.coins = maxf(GameState.coins, 50000.0)
	_pompa_sampai(world, func() -> bool: return not GameState.solo_mode, 5.0)
	_ok("Mode Solo padam setelah kas terisi", not GameState.solo_mode)
	_ok("Asisten Kasir '%s' berhasil disewa" % kandidat, staff.hire(kandidat))
	_ok("kasir tercatat aktif",
		GameState.active_staff(StaffDB.ROLE_KASIR).size() == 1)
	_ok("jalur kasir bukan lagi jalur manual", not _lane_manual(0))

	# --- Karakter pemain sengaja dijauhkan dari meja kasir ---
	var aktor: PlayerActor = world.player_actor()
	if aktor != null and not world.station_points("mixer").is_empty():
		pt.tap("mixer", 0)
		_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 30.0)
	_ok("karakter pemain TIDAK berjaga di kasir", pt.manning_lane() < 0)

	# --- Maju ke tahap jualan dengan rak terisi ---
	var rid: String = _resep_uji(prod)
	if rid == "":
		_ok("ada resep untuk diisi ke rak", false)
		return
	_maju_ke_jualan(world, day)
	_ok("toko sudah masuk tahap jualan", day.phase == GameConfig.PHASE_SELL)
	GameState.display_add(rid, 60, ProductionSystem.QUALITY_PRIME, day.hour)
	_ok("rak terisi roti untuk dijual", GameState.display_total() > 0)

	var terlayani: Array = [0]
	var hitung := func(_c: Dictionary, _r: float) -> void: terlayani[0] += 1
	EventBus.customer_served.connect(hitung)
	_pompa(world, 90.0)
	EventBus.customer_served.disconnect(hitung)

	_ok("asisten melayani sendiri tanpa kehadiran pemain (%d pembeli)"
		% terlayani[0], terlayani[0] > 0)
	_ok("karakter pemain tetap jauh dari meja sepanjang uji", pt.manning_lane() < 0)

	print("  asisten '%s' melayani %d pembeli; pemain tidak pernah menyentuh meja kasir"
		% [kandidat, terlayani[0]])

	# --- Kasir yang DILIBURKAN sama dengan tidak ada kasir (Mode Solo 3.0.C) ---
	_ok("kasir bisa diliburkan", staff.set_leave(kandidat, true))
	_ok("kasir yang diliburkan tidak lagi terhitung aktif",
		GameState.active_staff(StaffDB.ROLE_KASIR).is_empty())
	_ok("jalur kasir kembali menuntut kehadiran pemain saat kasir diliburkan",
		_lane_manual(0))
	_ok("kasir bisa dipanggil bekerja lagi", staff.set_leave(kandidat, false))
	_ok("jalur kasir otomatis lagi setelah kasir kembali", not _lane_manual(0))

	# --- Pulihkan: pecat kembali supaya uji lain kembali ke Mode Solo ---
	staff.fire(kandidat)
	_ok("kasir bisa dipecat kembali",
		GameState.active_staff(StaffDB.ROLE_KASIR).is_empty())
	_ok("jalur kasir kembali menjadi jalur manual", _lane_manual(0))

	_bersihkan_dapur(pt, prod)
	day.start_day()


## Apakah jalur kasir ke-`i` berstatus MANUAL (dilayani pemain).
func _lane_manual(i: int) -> bool:
	var cust: CustomerSim = _main.systems.get("cust") as CustomerSim
	if cust == null:
		return false
	var raw: Variant = cust.get("_lanes")
	if not (raw is Array):
		return false
	var lanes: Array = raw
	if i < 0 or i >= lanes.size():
		return false
	return bool((lanes[i] as Dictionary).get("manual", false))


## ID Asisten Kasir dengan tier terendah di roster; "" bila tidak ada.
func _kasir_termurah() -> String:
	var terbaik: String = ""
	var tier_terbaik: int = 99
	for sid in StaffDB.ids():
		var e: Dictionary = StaffDB.entry(sid)
		if String(e.get("role", "")) != StaffDB.ROLE_KASIR:
			continue
		var t: int = int(e.get("tier", 99))
		if t < tier_terbaik:
			tier_terbaik = t
			terbaik = sid
	return terbaik


## Aktor tidak boleh menembus perabot.
##
## Diuji pada dua tingkat, karena keduanya bisa rusak sendiri-sendiri:
##
##   1. RUTE — polyline yang dikembalikan ShopWorld.route() tidak boleh
##      menyentuh satu pun petak terhuni, bahkan ketika garis lurus dari asal ke
##      tujuan jelas-jelas membelah sebuah perabot.
##   2. LANGKAH — karakter yang benar-benar BERJALAN menyusuri rute itu tidak
##      boleh singgah di petak terlarang pada satu frame pun. Rute yang benar
##      tapi diikuti dengan cara yang salah tetap berarti karakter menembus meja.
##
## Yang dijamin adalah TITIK PUSAT aktor, bukan lingkar badannya: petak 50 cm
## dan dapur Garasi yang cuma 6 x 5 petak tidak menyisakan ruang untuk
## menggelembungkan penghalang tanpa menutup lorongnya sama sekali.
func _check_actor_collision() -> void:
	print("\n-- Tabrakan Aktor vs Perabot --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	if world == null or pt == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.decor.clear()
		world.rebuild()
		pt.reset()

		var terlarang: Dictionary = world.blocked_tiles()
		_ok("T%d ada perabot yang menghalangi (%d petak)" % [tier, terlarang.size()],
			terlarang.size() > 0)

		# --- 1. Rute mengitari, bukan menembus ---
		var diuji: int = 0
		var tembus: int = 0
		var tanpa_belokan: int = 0
		# Untuk setiap perabot dicari sepasang petak bebas yang berseberangan
		# TEPAT melewatinya. Dicoba mendatar dan tegak, pada jarak 2 lalu 3 petak,
		# supaya perabot yang merapat dinding pun tetap kebagian kasus uji.
		var arah: Array = [Vector2i(1, 0), Vector2i(0, 1)]
		for kunci in terlarang.keys():
			var halangan: Vector2i = kunci
			for d_v in arah:
				var d: Vector2i = d_v
				var ketemu: bool = false
				for jarak in [2, 3]:
					if ketemu:
						break
					var p1: Vector2i = halangan - d * jarak
					var p2: Vector2i = halangan + d * jarak
					if not _petak_sah(tier, p1) or not _petak_sah(tier, p2):
						continue
					if terlarang.has(p1) or terlarang.has(p2):
						continue
					var dari: Vector3 = _titik_petak(tier, p1)
					var ke: Vector3 = _titik_petak(tier, p2)
					# Hanya berarti bila garis LURUS-nya memang terhalang.
					if _polyline_bebas(world, tier, dari,
							PackedVector3Array([ke]), terlarang):
						continue
					ketemu = true
					diuji += 1
					var rute: PackedVector3Array = world.route(dari, ke)
					# Garis lurusnya membelah perabot, jadi rutenya WAJIB berbelok.
					if rute.size() <= 1:
						tanpa_belokan += 1
					if not _polyline_bebas(world, tier, dari, rute, terlarang):
						tembus += 1

		if diuji > 0:
			_ok("T%d rute mengitari %d perabot tanpa satu pun menembus" % [tier, diuji],
				tembus == 0)
			_ok("T%d rute yang terhalang benar-benar berbelok" % tier,
				tanpa_belokan == 0)

		# --- 2. Langkah kaki yang sesungguhnya ---
		var aktor: PlayerActor = world.player_actor()
		if aktor == null:
			_ok("T%d karakter pemain tersedia" % tier, false)
			continue

		# Tujuan dipilih sebagai petak bebas TERJAUH yang garis lurusnya terhalang
		# perabot. Menyuruh karakter menyeberang lapangan kosong tidak
		# membuktikan apa pun soal tabrakan.
		var asal: Vector2i = world.nearest_free_tile(Vector2i(0, 0))
		var tujuan: Vector2i = _tujuan_terhalang_terjauh(world, tier, asal, terlarang)
		_ok("T%d ada rute panjang yang benar-benar terhalang perabot" % tier,
			tujuan.x >= 0)
		if tujuan.x < 0:
			continue
		aktor.clear_path()
		aktor.global_position = _titik_petak(tier, asal)
		aktor.goto(_titik_petak(tier, tujuan), "uji", 0.0)

		var pelanggaran: int = 0
		var langkah: int = 0
		while not aktor.waypoints.is_empty() and langkah < 4000:
			aktor.tick(DT)
			langkah += 1
			var k: Vector2i = Vector2i(
				EquipmentFactory.tile_col_at(tier, aktor.global_position.x),
				EquipmentFactory.tile_row_at(tier, aktor.global_position.z))
			if terlarang.has(k):
				pelanggaran += 1
		_ok("T%d karakter menyeberangi dapur tanpa menembus perabot "
			% tier + "(%d langkah, %d pelanggaran)" % [langkah, pelanggaran],
			pelanggaran == 0)
		_ok("T%d karakter benar-benar sampai" % tier,
			aktor.global_position.distance_to(_titik_petak(tier, tujuan)) < 0.2)

		print("  T%d: %d petak terhalang, %d rute diuji, karakter tiba dalam %d langkah"
			% [tier, terlarang.size(), diuji, langkah])

	# --- 3. Aktor tanpa pemandu tetap berjalan lurus (kontrak lama) ---
	var lepas := ActorBase.new()
	add_child(lepas)
	lepas.global_position = Vector3.ZERO
	lepas.goto(Vector3(2.0, 0.0, 0.0), "lurus", 0.0)
	_ok("aktor tanpa nav tetap dapat satu tujuan lurus", lepas.waypoints.size() == 1)
	lepas.free()

	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()
	pt.reset()


## Apakah seluruh ruas polyline (dari `dari` menyusuri `rute`) bebas petak terlarang.
func _polyline_bebas(world: ShopWorld, tier: int, dari: Vector3,
		rute: PackedVector3Array, terlarang: Dictionary) -> bool:
	var a: Vector3 = dari
	for i in range(rute.size()):
		var b: Vector3 = rute[i]
		var jarak: float = Vector3(b.x - a.x, 0.0, b.z - a.z).length()
		var n: int = maxi(1, int(ceil(jarak / 0.1)))
		for s in range(n + 1):
			var p: Vector3 = a.lerp(b, float(s) / float(n))
			var k := Vector2i(
				EquipmentFactory.tile_col_at(tier, p.x),
				EquipmentFactory.tile_row_at(tier, p.z))
			# Petak di luar ruangan tidak dihitung: driver yang pergi memang
			# berjalan keluar lewat pintu.
			if absf(p.x) > EquipmentFactory.room_width(tier) * 0.5 \
					or absf(p.z) > EquipmentFactory.room_depth(tier) * 0.5:
				continue
			if terlarang.has(k):
				return false
		a = b
	return true


## Petak bebas TERJAUH dari `asal` yang garis lurusnya terhalang perabot.
## (-1, -1) bila seluruh ruangan bisa dicapai lurus-lurus saja.
func _tujuan_terhalang_terjauh(world: ShopWorld, tier: int, asal: Vector2i,
		terlarang: Dictionary) -> Vector2i:
	var dari: Vector3 = _titik_petak(tier, asal)
	var terbaik := Vector2i(-1, -1)
	var terjauh: float = 0.0
	for kolom in EquipmentFactory.floor_cols(tier):
		for baris in EquipmentFactory.floor_rows(tier):
			var k := Vector2i(kolom, baris)
			if terlarang.has(k) or k == asal:
				continue
			var ke: Vector3 = _titik_petak(tier, k)
			var jarak: float = dari.distance_to(ke)
			if jarak <= terjauh:
				continue
			if _polyline_bebas(world, tier, dari, PackedVector3Array([ke]), terlarang):
				continue
			terjauh = jarak
			terbaik = k
	return terbaik


func _petak_sah(tier: int, petak: Vector2i) -> bool:
	return petak.x >= 0 and petak.y >= 0 \
		and petak.x < EquipmentFactory.floor_cols(tier) \
		and petak.y < EquipmentFactory.floor_rows(tier)


func _titik_petak(tier: int, petak: Vector2i) -> Vector3:
	return Vector3(EquipmentFactory.tile_x(tier, petak.x), 0.0,
		EquipmentFactory.tile_z(tier, petak.y))


## Arah hadap aktor: WAJAH yang berjalan lebih dulu, bukan punggung.
##
## Penjaga ini ada karena pernah terjadi: ActorBase._face() memakai
## atan2(dir.x, dir.z), yang mengarahkan sumbu +Z ke tujuan — padahal
## CharacterFactory membangun seluruh detail wajah di sisi -Z (FRONT = -1.0).
## Akibatnya setiap karakter di toko berjalan mundur, dan yang terlihat pemain
## sepanjang permainan hanyalah belakang kepala.
##
## Diuji sebagai GEOMETRI, bukan sebagai sudut: yang diperiksa adalah ke mana
## sumbu -Z aktor benar-benar menunjuk setelah ia berputar, dan di sisi mana
## node "Face" berada relatif terhadap titik berdirinya. Uji yang hanya
## membandingkan rotation.y dengan atan2 akan ikut salah bila rumusnya salah.
func _check_actor_facing() -> void:
	print("\n-- Arah Hadap Aktor --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	# --- Wajah memang dibangun di sisi -Z ---
	var model: Node3D = CharacterFactory.build(CharacterFactory.spec_for_player("pria"))
	add_child(model)
	var wajah: Node3D = CharacterFactory.part(model, "Face")
	_ok("model punya node 'Face'", wajah != null)
	if wajah != null:
		var z_wajah: float = _world_aabb(wajah).get_center().z
		_ok("wajah dibangun di sisi -Z model (z = %.3f)" % z_wajah, z_wajah < -0.05)
	model.free()

	# --- Karakter yang berjalan menghadap tujuannya ---
	var aktor: PlayerActor = world.player_actor()
	if aktor == null:
		_ok("karakter pemain tersedia", false)
		return

	var arah_uji: Array = [
		[Vector3(1.0, 0.0, 0.0), "+X"],
		[Vector3(-1.0, 0.0, 0.0), "-X"],
		[Vector3(0.0, 0.0, 1.0), "+Z"],
		[Vector3(0.0, 0.0, -1.0), "-Z"],
	]
	for e: Variant in arah_uji:
		var pasangan: Array = e
		var arah: Vector3 = pasangan[0]
		var nama: String = String(pasangan[1])

		aktor.clear_path()
		aktor.global_position = Vector3.ZERO
		aktor.rotation.y = 0.0
		aktor.goto(arah * 3.0, "uji", 0.0)
		# Beberapa tick sudah cukup: putaran badan diinterpolasi, bukan seketika.
		for _i: int in range(40):
			aktor.tick(DT)

		var hadap: Vector3 = aktor.global_transform.basis * Vector3(0.0, 0.0, -1.0)
		var sejajar: float = hadap.normalized().dot(arah.normalized())
		_ok("berjalan ke %s: wajah ikut menghadap %s (kesejajaran %.2f)"
			% [nama, nama, sejajar], sejajar > 0.95)

		# Node Face harus benar-benar berada DI DEPAN titik berdiri aktor.
		var f: Node3D = CharacterFactory.part(aktor.model, "Face")
		if f != null:
			var maju: Vector3 = _world_aabb(f).get_center() - aktor.global_position
			_ok("berjalan ke %s: node 'Face' berada di sisi depan" % nama,
				Vector3(maju.x, 0.0, maju.z).normalized().dot(arah.normalized()) > 0.8)

	aktor.clear_path()
	aktor.global_position = world.player_idle_spot()
	aktor.idle_pos = aktor.global_position
	aktor.rotation.y = PI

	# --- Kasir menghadap pembeli, bukan dinding dapur ---
	# Kasir berdiri di sisi dapur meja pembatas; pembeli mengantre di sisi +Z.
	var kasir_hadap: Vector3 = Transform3D(Basis(Vector3.UP, PI), Vector3.ZERO) \
		* Vector3(0.0, 0.0, -1.0)
	_ok("rotation.y = PI menghadapkan wajah ke +Z (arah pembeli)",
		kasir_hadap.z > 0.95)

	print("  wajah memimpin ke empat arah mata angin, kasir menghadap antrean")


## Alur produksi manual karakter pemain, diuji dari ketukan sampai roti di rak.
##
## Ini tes yang paling berharga di berkas ini: seluruh rantai baru — ketuk gudang,
## pilih resep, ketuk mixer, ketuk oven, ketuk rak, pilih petak — melewati enam
## lapisan berbeda (UI, PlayerTaskSystem, ProductionSystem, GameState, ShopWorld,
## PlayerActor), dan satu sambungan yang putus di mana pun akan membuat pemain
## berdiri di depan perabot yang tidak pernah merespons.
##
## Waktu dimajukan dengan delta tetap lewat _pompa(): dunia 3D tidak pernah
## mendapat frame nyata di dalam tes ini, jadi kaki karakter harus dilangkahkan
## sendiri lewat ShopWorld.tick_world().
func _check_player_flow() -> void:
	print("\n-- Alur Produksi Manual Pemain --")
	var world: ShopWorld = _main.world as ShopWorld
	var pt: PlayerTaskSystem = _main.systems.get("player") as PlayerTaskSystem
	var prod: ProductionSystem = _main.systems.get("prod") as ProductionSystem
	if world == null or pt == null or prod == null:
		_ok("sistem tugas pemain tersedia", false)
		return

	_siapkan_dapur(world, pt, prod)

	var aktor: PlayerActor = world.player_actor()
	if aktor == null:
		_ok("karakter pemain terbangun", false)
		return
	_ok("karakter pemain terbangun", true)
	_ok("karakter memakai pilihan yang tersimpan",
		String(aktor.spec().get("kind", "")) == "player")

	var rid: String = _resep_uji(prod)
	if rid == "":
		_ok("ada resep yang bisa diproduksi", false)
		return

	# --- 1. Ketuk gudang: karakter berjalan, pintu terbuka, daftar resep muncul.
	var buka: Array = [0]
	var pintu: Array = [0]
	var rak_diminta: Array = []
	pt.storage_opened.connect(func() -> void: buka[0] += 1)
	pt.storage_door.connect(func(open: bool) -> void: pintu[0] += (1 if open else -1))
	pt.rack_requested.connect(func(oid: int, r: int) -> void: rak_diminta.append([oid, r]))

	var jauh: float = aktor.global_position.distance_to(world.station_points("storage")[0])
	_ok("ketukan gudang diterima", pt.tap("storage", 0))
	_ok("daftar resep BELUM terbuka sebelum karakter sampai", buka[0] == 0)
	_pompa_sampai(world, func() -> bool: return buka[0] > 0, 20.0)
	_ok("daftar resep terbuka setelah karakter tiba di gudang", buka[0] == 1)
	_ok("pintu gudang ikut terbuka", pintu[0] == 1)
	_ok("karakter benar-benar berpindah ke gudang (%.2f m)" % jauh,
		aktor.global_position.distance_to(world.station_points("storage")[0])
			< jauh - 0.1 + 0.0001)

	# --- 2. Pilih resep: daftar & pintu tertutup, tanda "!" muncul di mixer.
	_ok("resep terpilih", pt.choose_recipe(rid, 1))
	_ok("pintu gudang tertutup lagi", pintu[0] == 0)
	_ok("satu pesanan tercatat", pt.order_count() == 1)
	var oid: int = int((pt.orders()[0] as Dictionary).get("id", -1))
	_ok("pesanan menunggu di MIXER",
		_state_pesanan(pt, oid) == PlayerTaskSystem.STATE_MENUNGGU
			and _stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_MIXER)
	_ok("tanda seru tampil di mixer, bukan di alat lain",
		_penanda(pt, "mixer:0") == StationMarker.MODE_ALERT
			and _penanda(pt, "oven:0") == "")

	# Ketukan pada alat yang bukan gilirannya kini MEMANGGIL karakter ke sana,
	# tapi tidak boleh menggeser pesanan yang sedang menunggu di mixer.
	_ok("ketukan oven di luar giliran tetap dilayani", pt.tap("oven", 0))
	_ok("pesanan tetap menunggu di mixer setelah ketukan nyasar",
		_stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_MIXER
			and _state_pesanan(pt, oid) == PlayerTaskSystem.STATE_MENUNGGU)
	_ok("ketukan nyasar tidak melahirkan job", prod.jobs().is_empty())

	# --- 3. Ketuk mixer: karakter berjalan, adonan mulai diaduk.
	_ok("ketukan mixer diterima", pt.tap("mixer", 0))
	_ok("belum ada job selama karakter masih berjalan", prod.jobs().is_empty())
	_pompa_sampai(world, func() -> bool:
		return _state_pesanan(pt, oid) == PlayerTaskSystem.STATE_BEKERJA, 20.0)
	_ok("adonan mulai diaduk setelah karakter tiba di mixer",
		_state_pesanan(pt, oid) == PlayerTaskSystem.STATE_BEKERJA)
	_ok("job produksi lahir dan ditandai manual", _job_manual(prod, pt, oid))
	_ok("bar progres menggantikan tanda seru di mixer",
		_penanda(pt, "mixer:0") == StationMarker.MODE_PROGRESS)

	# --- 4. Aduk selesai: tanda "!" TETAP di mixer — adonannya harus diambil.
	_pompa_sampai(world, func() -> bool:
		return _menunggu_diambil(pt, oid), 120.0)
	_ok("tanda seru tetap di mixer setelah adukan selesai",
		_stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_MIXER
			and _penanda(pt, "mixer:0") == StationMarker.MODE_ALERT
			and _penanda(pt, "oven:0") == "")
	_ok("pesanan berstatus 'menunggu diambil'", _menunggu_diambil(pt, oid))
	_ok("adonan manual TIDAK melompat sendiri ke oven",
		String(_job(prod, pt, oid).get("stage", "")) == ProductionSystem.STAGE_MIXING)

	# Mengetuk oven sebelum adonannya diambil TIDAK memindahkan apa pun: yang
	# terjadi paling jauh hanya karakter berjalan ke sana dengan tangan kosong.
	# (Nilai balik tap() sengaja tidak diuji: di dapur Garasi yang sempit, titik
	# berdiri mixer dan oven bisa jatuh di petak yang sama, dan ketukan pada
	# tempat yang sudah ditempati karakter memang mengembalikan false.)
	pt.tap("oven", 0)
	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 20.0)
	_ok("adonan tidak berpindah hanya karena oven diketuk",
		String(_job(prod, pt, oid).get("stage", "")) == ProductionSystem.STAGE_MIXING
			and not aktor.is_carrying())
	_ok("tanda serunya pun tidak bergeser dari mixer",
		_stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_MIXER)

	# --- 5. Ketuk MIXER: karakter mengambil adonannya, tanda pindah ke oven.
	_ok("ketukan mixer untuk mengambil adonan diterima", pt.tap("mixer", 0))
	_pompa_sampai(world, func() -> bool: return aktor.is_carrying(), 20.0)
	_ok("karakter memegang mangkuk adonan",
		aktor.carrying() == PlayerActor.CARRY_DOUGH)
	_ok("tanda seru baru pindah ke oven SESUDAH adonan di tangan",
		_stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_OVEN
			and _penanda(pt, "oven:0") == StationMarker.MODE_ALERT
			and _penanda(pt, "mixer:0") == "")
	_ok("adonan masih tercatat di mixer selama dibawa, bukan di oven",
		String(_job(prod, pt, oid).get("stage", "")) == ProductionSystem.STAGE_MIXING)

	# --- 6. Ketuk OVEN: adonan diantar dan mulai dipanggang.
	_ok("ketukan oven diterima", pt.tap("oven", 0))
	_pompa_sampai(world, func() -> bool:
		return String(_job(prod, pt, oid).get("stage", "")) == ProductionSystem.STAGE_BAKING,
		20.0)
	_ok("adonan masuk oven setelah diantar",
		String(_job(prod, pt, oid).get("stage", "")) == ProductionSystem.STAGE_BAKING)
	_ok("tangan karakter kosong lagi setelah menaruh adonan", not aktor.is_carrying())
	_ok("mixer kembali bebas", prod.free_mixer_slots() == prod.mixer_slot_count())

	# --- 7. Paralel: selagi memanggang, pesanan kedua bisa dimulai.
	_ok("resep kedua bisa dipilih selagi oven bekerja", pt.choose_recipe(rid, 1))
	_ok("dua pesanan berjalan bersamaan", pt.order_count() == 2)
	var oid2: int = _pesanan_lain(pt, oid)
	_ok("pesanan kedua menunggu di mixer",
		_stasiun_pesanan(pt, oid2) == PlayerTaskSystem.STATION_MIXER)
	_ok("ketukan mixer untuk pesanan kedua diterima", pt.tap("mixer", 0))
	_pompa_sampai(world, func() -> bool:
		return _state_pesanan(pt, oid2) == PlayerTaskSystem.STATE_BEKERJA, 20.0)
	_ok("mixer mengaduk pesanan kedua selagi oven memanggang pesanan pertama",
		_state_pesanan(pt, oid2) == PlayerTaskSystem.STATE_BEKERJA
			and String(_job(prod, pt, oid).get("stage", "")) == ProductionSystem.STAGE_BAKING)

	# --- 8. Matang: tanda "!" TETAP di oven — loyangnya harus diangkat.
	_pompa_sampai(world, func() -> bool:
		return _menunggu_diambil(pt, oid), 200.0)
	_ok("tanda seru tetap di oven setelah roti matang",
		_stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_OVEN
			and _penanda(pt, "oven:0") == StationMarker.MODE_ALERT
			and _penanda(pt, "display:0") == "")

	# Tangan cuma sepasang: pesanan kedua yang juga selesai diaduk tidak bisa
	# diambil sampai loyang ini diantar.
	_pompa_sampai(world, func() -> bool: return _menunggu_diambil(pt, oid2), 200.0)
	_ok("pesanan kedua ikut menunggu diambil di mixer", _menunggu_diambil(pt, oid2))

	# --- 9. Ketuk OVEN: loyang diangkat, tanda pindah ke rak.
	_ok("ketukan oven untuk mengangkat loyang diterima", pt.tap("oven", 0))
	_pompa_sampai(world, func() -> bool: return aktor.is_carrying(), 20.0)
	_ok("karakter memegang loyang roti", aktor.carrying() == PlayerActor.CARRY_TRAY)
	_ok("tanda seru pindah ke rak sesudah loyang di tangan",
		_stasiun_pesanan(pt, oid) == PlayerTaskSystem.STATION_DISPLAY
			and _penanda(pt, "display:0") == StationMarker.MODE_ALERT)

	pt.tap("mixer", 0)
	_ok("adonan kedua TIDAK ikut terangkat selagi tangannya penuh",
		_menunggu_diambil(pt, oid2))
	_pompa_sampai(world, func() -> bool: return not pt.is_busy(), 20.0)
	_ok("loyang tetap di tangan setelah ketukan yang ditolak itu",
		aktor.carrying() == PlayerActor.CARRY_TRAY and _menunggu_diambil(pt, oid2))

	# --- 10. Ketuk rak: karakter mengantar loyang, layar rak terbuka.
	_ok("ketukan rak diterima", pt.tap("display", 0))
	_pompa_sampai(world, func() -> bool: return not rak_diminta.is_empty(), 20.0)
	_ok("layar rak diminta setelah karakter tiba", rak_diminta.size() == 1)
	_ok("layar rak menunjuk pesanan dan rak yang benar",
		rak_diminta.size() == 1 and int((rak_diminta[0] as Array)[0]) == oid)
	_ok("karakter membawa loyang roti ke rak",
		aktor.carrying() == PlayerActor.CARRY_TRAY
			or _state_pesanan(pt, oid) == PlayerTaskSystem.STATE_MEMILIH)

	# --- 11. Pilih petak: roti mendarat PERSIS di petak yang ditunjuk.
	var petak: int = 3
	var sebelum: int = GameState.display_total()
	var masuk: int = pt.place_bread(oid, petak)
	_ok("roti masuk ke rak (%d buah)" % masuk, masuk > 0)
	_ok("roti mendarat di petak yang dipilih, bukan petak lain",
		not GameState.display_entry_at(petak).is_empty()
			and String(GameState.display_entry_at(petak).get("recipe_id", "")) == rid)
	_ok("jumlah roti di rak bertambah", GameState.display_total() == sebelum + masuk)
	_ok("pesanan pertama selesai dan hilang dari daftar",
		pt.order(oid).is_empty() and pt.order_count() == 1)
	_ok("tidak ada lagi penanda untuk pesanan yang sudah selesai",
		_penanda(pt, "display:0") == "")
	_ok("tangan karakter kosong lagi setelah loyangnya ditata",
		not aktor.is_carrying())

	print("  rantai penuh gudang -> mixer -> (ambil) -> oven -> (angkat) -> rak "
		+ "tuntas, %d roti mendarat di petak %d" % [masuk, petak])

	_bersihkan_dapur(pt, prod)


# --- Pembantu alur pemain ---------------------------------------------------

## Menyiapkan dapur bersih: tahap persiapan, gudang penuh bahan, tanpa job sisa.
## Melewati tahap persiapan sampai toko buka, lalu MENAHAN pengali kecepatan di
## SKALA_UJI_PEMBELI untuk sisa uji.
##
## Anggaran waktunya dihitung dari konstanta jam, bukan angka tetap. Begitu
## kecepatan jam diubah — satu jam in-game kini 5 menit nyata — angka tetap apa
## pun kedaluwarsa diam-diam, dan uji gagal karena kehabisan sabar, bukan karena
## ada yang rusak.
func _maju_ke_jualan(world: ShopWorld, day: DayCycle) -> void:
	day.set_time_scale(DayCycle.TIME_SCALE_MAX)
	var prep: float = (GameConfig.HOUR_OPEN - GameConfig.HOUR_START) \
		* GameConfig.SECONDS_PER_GAME_HOUR / DayCycle.TIME_SCALE_MAX
	_pompa_sampai(world, func() -> bool:
		return day.phase == GameConfig.PHASE_SELL, prep * 1.5)
	day.set_time_scale(SKALA_UJI_PEMBELI)


func _siapkan_dapur(world: ShopWorld, pt: PlayerTaskSystem, prod: ProductionSystem) -> void:
	GameState.location_tier = 1
	GameState.decor.clear()
	GameState.display_slots.clear()
	for ing: String in GameState.BASIC_INGREDIENTS:
		GameState.pantry[ing] = 200
	prod.reset()
	pt.reset()
	world.rebuild()
	var day: DayCycle = _main.systems.get("day") as DayCycle
	if day != null:
		day.set_time_scale(1.0)
		day.start_day()


## Menjadikan toko RAMAI: cuaca cerah dan rating toko yang sehat.
##
## Arus pembeli berbanding lurus dengan rating toko (GDD 9.1) dan anjlok 60-80%
## saat hujan (GDD 10.2). Uji-uji pelayanan di bawah ini justru sengaja membuat
## pembeli pulang marah berkali-kali, jadi tanpa dipulihkan setiap uji
## berikutnya menunggu pembeli yang datangnya makin jarang — dan yang gagal
## bukan lagi perilaku yang sedang diuji, melainkan kesabaran tesnya.
##
## Dipanggil SESUDAH _siapkan_dapur(): start_day() mengundi cuaca baru, dan
## sinyal weather_changed di bawah inilah yang menyuruh CustomerSim menghitung
## ulang pengali pejalan kakinya.
func _siapkan_toko_ramai() -> void:
	GameState.weather = WeatherDB.CERAH
	GameState.store_rating = 4.5
	EventBus.weather_changed.emit(WeatherDB.CERAH, WeatherDB.CERAH)


func _bersihkan_dapur(pt: PlayerTaskSystem, prod: ProductionSystem) -> void:
	pt.reset()
	prod.reset()
	GameState.display_slots.clear()
	# Kembalikan kecepatan normal supaya percepatan _maju_ke_jualan() tidak
	# bocor ke uji berikutnya.
	var day: DayCycle = _main.systems.get("day") as DayCycle
	if day != null:
		day.set_time_scale(1.0)


## Memajukan simulasi DAN dunia 3D dengan delta tetap sampai `cond` terpenuhi.
func _pompa_sampai(world: ShopWorld, cond: Callable, batas_detik: float) -> void:
	var langkah: int = int(batas_detik / DT)
	for _i: int in range(langkah):
		if bool(cond.call()):
			return
		_main.step(DT)
		world.tick_world(DT)


## Resep starter pertama yang benar-benar bisa diproduksi sekarang.
func _resep_uji(prod: ProductionSystem) -> String:
	for rid: String in RecipeDB.starter():
		if prod.can_queue(rid, 1):
			return rid
	return ""


func _state_pesanan(pt: PlayerTaskSystem, oid: int) -> String:
	return String(pt.order(oid).get("state", ""))


func _stasiun_pesanan(pt: PlayerTaskSystem, oid: int) -> String:
	return String(pt.order(oid).get("station", ""))


## Apakah pesanan itu sedang MENUNGGU DIAMBIL dari alat yang baru selesai.
func _menunggu_diambil(pt: PlayerTaskSystem, oid: int) -> bool:
	var o: Dictionary = pt.order(oid)
	return not o.is_empty() and bool(o.get("ambil", false)) \
		and String(o.get("state", "")) == PlayerTaskSystem.STATE_MENUNGGU


## Mode penanda pada satu stasiun; "" berarti tidak ada penanda sama sekali.
func _penanda(pt: PlayerTaskSystem, kunci: String) -> String:
	var m: Dictionary = pt.markers()
	if not m.has(kunci):
		return ""
	return String((m[kunci] as Dictionary).get("mode", ""))


func _job(prod: ProductionSystem, pt: PlayerTaskSystem, oid: int) -> Dictionary:
	return prod.job(int(pt.order(oid).get("job_id", 0)))


func _job_manual(prod: ProductionSystem, pt: PlayerTaskSystem, oid: int) -> bool:
	var j: Dictionary = _job(prod, pt, oid)
	return not j.is_empty() and bool(j.get("manual", false))


func _pesanan_lain(pt: PlayerTaskSystem, kecuali: int) -> int:
	for e: Variant in pt.orders():
		var o: Dictionary = e
		if int(o.get("id", -1)) != kecuali:
			return int(o.get("id", -1))
	return -1


func _check_storage() -> void:
	print("\n-- Gudang Penyimpanan --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	var terlapor: Array = []
	var tangkap := func(kind: String, index: int) -> void:
		terlapor.append("%s:%d" % [kind, index])
	world.fixture_tapped.connect(tangkap)

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.decor.clear()
		world.rebuild()

		_ok("T%d gudang terpasang tepat satu" % tier, world.decor_count("storage") == 1)
		if world.decor_count("storage") != 1:
			continue

		var jejak: Vector2i = world.decor_jejak("storage", 0)
		_ok("T%d jejak gudang = tabel lokasi" % tier,
			jejak == EquipmentFactory.footprint("storage", tier))
		_ok("T%d gudang satu baris ubin dalam" % tier, jejak.y == 1)
		_ok("T%d gudang melebar ke samping, bukan menebal ke belakang" % tier,
			jejak.x >= 2)

		# Gudang berbagi zona dapur dengan mixer dan oven, jadi ia tidak boleh
		# berdiri di baris meja kasir maupun di area toko.
		var anchor: Vector2i = world.decor_anchor("storage", 0)
		var zona: Vector2i = world.decor_zone("storage")
		_ok("T%d gudang berdiri di zona dapur (baris %d-%d dari %d-%d)"
			% [tier, anchor.y, anchor.y + jejak.y - 1, zona.x, zona.y],
			anchor.y >= zona.x and anchor.y + jejak.y - 1 <= zona.y)
		_ok("T%d tempat gudang bawaan memang sah" % tier,
			world.decor_reason("storage", 0, anchor, world.decor_rot_of("storage", 0)) == "")

		# Tidak boleh tertindih perabot lain: decor_occupancy() melewati gudang
		# sendiri, jadi sisa isinya adalah mixer, oven, dan rak.
		var huni: Dictionary = world.decor_occupancy("storage", 0)
		var bentrok: int = 0
		for dx in jejak.x:
			for dy in jejak.y:
				if huni.has(Vector2i(anchor.x + dx, anchor.y + dy)):
					bentrok += 1
		_ok("T%d gudang tidak menindih perabot lain" % tier, bentrok == 0)

		# Diputar tegak, gudang menjadi 1 x N dan harus masih muat di zona dapur.
		# Di T2 dan T3 kedalaman dapur pas-pasan, jadi ini bukan formalitas.
		var tegak: Vector2i = world.decor_jejak("storage", 90)
		_ok("T%d jejak gudang diputar = sisi tertukar" % tier,
			tegak == Vector2i(jejak.y, jejak.x))
		var muat: bool = false
		for kolom in EquipmentFactory.floor_cols(tier):
			if world.decor_reason("storage", 0, Vector2i(kolom, zona.x), 90) == "":
				muat = true
				break
		_ok("T%d gudang masih bisa diputar tegak di zona dapur" % tier, muat)

		var titik: Vector2 = _titik_badan(world, "storage", 0)

		terlapor.clear()
		_ketuk(world, titik, titik)
		_ok("T%d mengetuk gudang melaporkan ketukan 'storage:0' (dapat %s)"
			% [tier, str(terlapor)], terlapor == ["storage:0"])

		# Seretan sejauh 40 px: jauh melewati TAP_SLOP, jadi bukan ketukan.
		terlapor.clear()
		_ketuk(world, titik, titik + Vector2(40.0, 0.0))
		_ok("T%d menyeret layar dari gudang tidak dihitung ketukan" % tier,
			terlapor.is_empty())

		# Selama Mode Dekorasi, ketukan milik DecorController.
		var dekor: DecorController = world.decor_controller()
		dekor.mulai()
		terlapor.clear()
		_ketuk(world, titik, titik)
		_ok("T%d ketukan gudang diam selama Mode Dekorasi" % tier, terlapor.is_empty())
		dekor.batal_pilih()
		dekor.selesai()
		GameState.decor.clear()
		world.rebuild()

		print("  T%d: gudang %s, jejak %d x %d petak di anchor (%d,%d)"
			% [tier, LocationDB.storage_name(tier), jejak.x, jejak.y, anchor.x, anchor.y])

	# --- Gudang yang dipindah pemain ikut tersimpan di denah dekorasi ---
	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()
	var tujuan: Vector2i = _petak_gudang_kosong(world, 1)
	if tujuan.x >= 0:
		world.decor_place("storage", 0, tujuan, 0)
		world.decor_save_layout()
		world.rebuild()
		_ok("gudang yang dipindah tetap di petak (%d,%d) setelah rebuild"
			% [tujuan.x, tujuan.y], world.decor_anchor("storage", 0) == tujuan)

	world.fixture_tapped.disconnect(tangkap)
	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()


## Titik layar di tengah BADAN satu perabot (bukan di kakinya).
func _titik_badan(world: ShopWorld, kind: String, index: int) -> Vector2:
	var n: Node3D = world.decor_node(kind, index)
	if n == null:
		return Vector2.ZERO
	var b: AABB = _world_aabb(n)
	return world.camera.unproject_position(Vector3(
		b.position.x + b.size.x * 0.5,
		b.position.y + b.size.y * 0.6,
		b.position.z + b.size.z * 0.5))


## Satu siklus tekan-lepas tetikus pada ShopWorld, dari `dari` ke `sampai`.
##
## Event-nya disuapkan langsung alih-alih lewat Input.parse_input_event():
## yang terakhir itu tertunda sampai frame berikutnya, dan suite ini berjalan
## tanpa menunggu frame sama sekali.
func _ketuk(world: ShopWorld, dari: Vector2, sampai: Vector2) -> void:
	var tekan := InputEventMouseButton.new()
	tekan.button_index = MOUSE_BUTTON_LEFT
	tekan.pressed = true
	tekan.position = dari
	world._unhandled_input(tekan)

	var lepas := InputEventMouseButton.new()
	lepas.button_index = MOUSE_BUTTON_LEFT
	lepas.pressed = false
	lepas.position = sampai
	world._unhandled_input(lepas)


## Petak dapur kosong tempat gudang masih muat, atau (-1,-1) bila tidak ada.
func _petak_gudang_kosong(world: ShopWorld, tier: int) -> Vector2i:
	var jejak: Vector2i = world.decor_jejak("storage", 0)
	var zona: Vector2i = world.decor_zone("storage")
	var sekarang: Vector2i = world.decor_anchor("storage", 0)
	for baris in range(zona.x, zona.y - jejak.y + 2):
		for kolom in EquipmentFactory.floor_cols(tier):
			var k := Vector2i(kolom, baris)
			if k == sekarang:
				continue
			if world.decor_reason("storage", 0, k, 0) == "":
				return k
	return Vector2i(-1, -1)


func _check_decor_pick() -> void:
	print("\n-- Memilih Perabot Lewat Badannya --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.decor.clear()
		world.rebuild()

		var salah: Array[String] = []
		var beda_dari_ubin: int = 0
		var diperiksa: int = 0
		for kind in ShopWorld.DECOR_KINDS:
			for i in world.decor_count(kind):
				var n: Node3D = world.decor_node(kind, i)
				if n == null:
					continue
				var b: AABB = _world_aabb(n)
				if b.size == Vector3.ZERO:
					continue
				diperiksa += 1
				# Titik di tengah badan perabot, bukan di kakinya.
				var tengah := Vector3(
					b.position.x + b.size.x * 0.5,
					b.position.y + b.size.y * 0.6,
					b.position.z + b.size.z * 0.5)
				var titik: Vector2 = world.camera.unproject_position(tengah)

				var kena: Dictionary = world.decor_pick_at_screen(titik)
				if kena.is_empty() or String(kena["kind"]) != kind \
						or int(kena["index"]) != i:
					salah.append("%s%d -> %s" % [kind, i,
						"kosong" if kena.is_empty()
						else "%s%d" % [String(kena["kind"]), int(kena["index"])]])

				# Cara LAMA (ubin di bawah kursor) di titik yang sama.
				var lewat_ubin: Dictionary = world.decor_at(
					world.decor_tile_at_screen(titik))
				if lewat_ubin.is_empty() or String(lewat_ubin["kind"]) != kind \
						or int(lewat_ubin["index"]) != i:
					beda_dari_ubin += 1

		_ok("T%d menyentuh badan perabot memilih perabot itu%s"
			% [tier, "" if salah.is_empty() else " — meleset: " + ", ".join(salah)],
			salah.is_empty())
		_ok("T%d ada perabot yang diperiksa" % tier, diperiksa > 0)
		_ok("T%d pemilihan lewat badan memang berbeda dari lewat ubin (%d dari %d)"
			% [tier, beda_dari_ubin, diperiksa], beda_dari_ubin > 0)

		# Menyentuh lantai kosong tetap tidak memilih apa pun.
		var huni: Dictionary = world.decor_occupancy()
		var kosong := Vector2i(-1, -1)
		for kolom in EquipmentFactory.floor_cols(tier):
			var k := Vector2i(kolom, EquipmentFactory.floor_rows(tier) - 1)
			if not huni.has(k):
				kosong = k
				break
		if kosong.x >= 0:
			var titik_lantai: Vector2 = world.camera.unproject_position(Vector3(
				EquipmentFactory.tile_x(tier, kosong.x), 0.0,
				EquipmentFactory.tile_z(tier, kosong.y)))
			_ok("T%d menyentuh lantai kosong tidak memilih apa pun" % tier,
				world.decor_pick_at_screen(titik_lantai).is_empty())

		print("  T%d: %d perabot, semuanya kena lewat badannya (%d di antaranya "
			% [tier, diperiksa, beda_dari_ubin]
			+ "tidak akan kena lewat ubin)")

	GameState.location_tier = 1
	world.rebuild()


## Apakah dua daftar posisi persis sama.
## Apakah dua daftar posisi persis sama.
func _sama_posisi(a: Array, b: Array) -> bool:
	if a.size() != b.size():
		return false
	for i in a.size():
		if (a[i] as Vector3).distance_to(b[i] as Vector3) > TILE_EPS:
			return false
	return true


## Alur pilih - seret - lepas di Mode Dekorasi, diuji sebagai LOGIKA PETAK.
##
## Titik layar sengaja tidak dipalsukan: terjemahan layar->ubin sudah diuji
## tersendiri di _check_grid_alignment(). Yang dijaga di sini adalah yang
## tersisa, dan justru yang paling mudah salah:
##   - perabot terpilih benar-benar TERANGKAT (syarat visual dari pemain);
##   - seretan ke tempat terlarang tetap mengikuti jari tapi ditandai TIDAK SAH
##     (itulah yang membuatnya berkedip merah, bukan putih);
##   - melepas di tempat terlarang MEMULANGKAN perabot, bukan meninggalkannya
##     menembus perabot lain;
##   - melepas pilihan menurunkannya kembali ke lantai.
func _check_decor_drag() -> void:
	print("\n-- Seret Perabot (Mode Dekorasi) --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.decor.clear()
		world.rebuild()
		var dekor: DecorController = world.decor_controller()
		dekor.mulai()

		var asal: Vector2i = world.decor_anchor("display", 0)
		var node: Node3D = world.decor_node("display", 0)
		_ok("T%d rak pertama punya node" % tier, node != null)
		if node == null:
			dekor.selesai()
			continue

		# --- Memilih lewat petak yang benar-benar dihuni rak itu ---
		_ok("T%d menyentuh petak rak memilih rak itu" % tier, dekor.mulai_seret(asal))
		_ok("T%d perabot terpilih terangkat (y %.2f > 0)" % [tier, node.position.y],
			node.position.y > 0.01)

		# --- Seret ke area DAPUR: dilarang, harus ditandai tidak sah ---
		var petak_dapur := Vector2i(asal.x, 0)
		dekor.seret(petak_dapur)
		_ok("T%d seret ke area dapur ditandai TIDAK SAH (kedip merah)" % tier,
			not dekor.tempat_sah())
		_ok("T%d perabot tetap mengikuti jari walau tempatnya terlarang" % tier,
			world.decor_anchor("display", 0) != asal)

		# --- Dilepas di tempat terlarang: pulang ke tempat semula ---
		dekor.lepas()
		_ok("T%d dilepas di tempat terlarang -> pulang ke petak semula" % tier,
			world.decor_anchor("display", 0) == asal)
		_ok("T%d setelah pulang, tempatnya sah lagi" % tier, dekor.tempat_sah())

		# --- Seret ke petak sah di sebelahnya: diterima ---
		var tujuan := Vector2i(-1, -1)
		var zona: Vector2i = world.decor_zone("display")
		for baris in range(zona.x, zona.y + 1):
			for kolom in EquipmentFactory.floor_cols(tier):
				var kandidat := Vector2i(kolom, baris)
				if kandidat == asal:
					continue
				if world.decor_reason("display", 0, kandidat,
						world.decor_rot_of("display", 0)) == "":
					tujuan = kandidat
					break
			if tujuan.x >= 0:
				break
		if tujuan.x >= 0:
			dekor.mulai_seret(world.decor_anchor("display", 0))
			dekor.seret(tujuan)
			dekor.lepas()
			_ok("T%d seret ke petak sah diterima (%d,%d)" % [tier, tujuan.x, tujuan.y],
				world.decor_anchor("display", 0) == tujuan and dekor.tempat_sah())
			_ok("T%d tidak ada perabot berbagi ubin setelah dipindah" % tier,
				_tidak_ada_bentrok(world))

		# --- Melepas pilihan menurunkannya kembali ---
		dekor.batal_pilih()
		_ok("T%d melepas pilihan menurunkan perabot (y %.2f)" % [tier, node.position.y],
			absf(node.position.y) < 0.001)

		# --- Menyentuh lantai kosong tidak memilih apa pun ---
		var kosong := Vector2i(-1, -1)
		var huni: Dictionary = world.decor_occupancy()
		for kolom2 in EquipmentFactory.floor_cols(tier):
			var k := Vector2i(kolom2, EquipmentFactory.floor_rows(tier) - 1)
			if not huni.has(k):
				kosong = k
				break
		if kosong.x >= 0:
			_ok("T%d menyentuh lantai kosong tidak memilih apa pun" % tier,
				not dekor.mulai_seret(kosong))

		# --- Denah tersimpan saat Selesai, dan bertahan setelah rebuild ---
		var akhir: Vector2i = world.decor_anchor("display", 0)
		dekor.selesai()
		world.rebuild()
		_ok("T%d denah hasil seret bertahan setelah rebuild" % tier,
			world.decor_anchor("display", 0) == akhir)

		print("  T%d: rak %d,%d -> %d,%d, denah bertahan"
			% [tier, asal.x, asal.y, akhir.x, akhir.y])

	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()


## Apakah ada dua perabot yang berbagi ubin.
func _tidak_ada_bentrok(world: ShopWorld) -> bool:
	var total: int = 0
	for kind in ShopWorld.DECOR_KINDS:
		for i in world.decor_count(kind):
			var j: Vector2i = world.decor_jejak(kind, world.decor_rot_of(kind, i))
			total += j.x * j.y
	return world.decor_occupancy().size() == total


## Petak ANCHOR sebuah perabot: pojok belakang-kiri jejaknya.
## Petak ANCHOR sebuah perabot: pojok belakang-kiri jejaknya.
##
## Tidak bisa memakai "ubin yang memuat titik pusat": jejak berukuran genap
## (rak 2x1) berpusat tepat di TEPI ubin, sehingga pembulatan pusat bisa jatuh
## ke petak mana pun di antara keduanya. Anchor adalah satu-satunya identitas
## petak yang stabil.
func _anchor_of(tier: int, pusat: Vector3, jejak: Vector2i) -> Vector2i:
	return Vector2i(
		EquipmentFactory.tile_col_at(tier, pusat.x - float(jejak.x - 1) * 0.5 * TILE),
		EquipmentFactory.tile_row_at(tier, pusat.z - float(jejak.y - 1) * 0.5 * TILE))


## Mencatat seluruh petak jejak ke `huni`; mengembalikan daftar petak yang
## ternyata SUDAH terisi perabot lain.
func _huni_jejak(huni: Dictionary, anchor: Vector2i, jejak: Vector2i,
		nama: String) -> Array[String]:
	var bentrok: Array[String] = []
	for dx in jejak.x:
		for dy in jejak.y:
			var k := Vector2i(anchor.x + dx, anchor.y + dy)
			if huni.has(k):
				bentrok.append("%s & %s di ubin %d,%d" % [nama, String(huni[k]), k.x, k.y])
			huni[k] = nama
	return bentrok


## Apakah `jarak` (diukur dari sudut belakang-kiri ruangan) tepat di tepi ubin.
## Apakah `jarak` (diukur dari sudut belakang-kiri ruangan) tepat di tepi ubin.
func _on_tile_edge(jarak: float) -> bool:
	return absf(jarak - roundf(jarak / TILE) * TILE) < TILE_EPS


func _inside(tier: int, label: String, list: Array, x_lim: float, z_lim: float) -> void:
	for p_v in list:
		var p: Vector3 = p_v
		_ok("T%d %s di dalam dinding (x %.2f, |lim| %.2f)" % [tier, label, p.x, x_lim],
			absf(p.x) < x_lim)
		_ok("T%d %s di dalam dinding (z %.2f, |lim| %.2f)" % [tier, label, p.z, z_lim],
			absf(p.z) < z_lim)


## Nama perabot yang wajib muat sepenuhnya di dalam dinding. Node "Room" sengaja
## dikecualikan: dindingnya memang BERADA di batas itu.
const FIXTURE_PREFIXES: Array[String] = [
	"Mixer", "Oven", "Display", "Divider", "PickupCounter", "Counter", "Tablet",
]


## Kotak pembatas sebuah node di ruang dunia, digabung dari seluruh MeshInstance3D
## keturunannya. Mengembalikan AABB berukuran nol bila tidak ada mesh sama sekali.
func _world_aabb(node: Node3D) -> AABB:
	var box := AABB()
	var ada: bool = false
	var antrean: Array[Node] = [node]
	while not antrean.is_empty():
		var n: Node = antrean.pop_back()
		for c in n.get_children():
			antrean.append(c)
		var mi := n as MeshInstance3D
		if mi == null or mi.mesh == null:
			continue
		var lokal: AABB = mi.get_aabb()
		var dunia: AABB = mi.global_transform * lokal
		if ada:
			box = box.merge(dunia)
		else:
			box = dunia
			ada = true
	return box


## Memeriksa GEOMETRI NYATA setiap perabot terhadap dinding, bukan titik pusatnya.
##
## Pemeriksaan titik pusat pernah meloloskan Oven Tier 5 menembus dinding samping
## sejauh setengah meter: pusatnya sah, badannya tidak. Yang dijaga di sini adalah
## rentang mesh sesungguhnya.
func _check_fixture_bounds(tier: int) -> void:
	var world: ShopWorld = _main.world as ShopWorld
	if world == null or world.fixtures == null:
		return
	var w: float = EquipmentFactory.room_width(tier)
	var d: float = EquipmentFactory.room_depth(tier)
	var wall: float = EquipmentFactory.room_wall_thickness()
	# Batasnya permukaan DALAM dinding yang sesungguhnya: dinding digambar tepat
	# di atas tepi lantai, jadi ia cuma memakan setengah tebalnya ke dalam
	# ruangan. Toleransi kecil karena hiasan tipis boleh menyentuhnya.
	var x_lim: float = w * 0.5 - wall * 0.5 + 0.02
	var z_lim: float = d * 0.5 - wall * 0.5 + 0.02

	for child in world.fixtures.get_children():
		var n := child as Node3D
		if n == null:
			continue
		var cocok: bool = false
		for pre in FIXTURE_PREFIXES:
			if String(n.name).begins_with(pre):
				cocok = true
				break
		if not cocok:
			continue
		var box: AABB = _world_aabb(n)
		if box.size == Vector3.ZERO:
			continue
		var kiri: float = box.position.x
		var kanan: float = box.position.x + box.size.x
		var belakang: float = box.position.z
		var depan: float = box.position.z + box.size.z

		# Meja kasir pembatas sengaja rata dengan TEPI UBIN kolom 0, bukan dengan
		# permukaan dalam dinding, sehingga ujungnya terbenam di dalam tembok
		# samping. Itu tersembunyi dan tidak apa-apa — yang haram adalah keluar
		# dari badan bangunan, jadi batasnya diukur sampai sisi luar dinding.
		var lim_x: float = x_lim
		if String(n.name).begins_with("Divider"):
			lim_x = w * 0.5 + wall * 0.5 + 0.02
		_ok("T%d %s tidak menembus dinding kiri/kanan (%.2f..%.2f, lim %.2f)"
			% [tier, n.name, kiri, kanan, lim_x],
			kiri > -lim_x and kanan < lim_x)
		_ok("T%d %s tidak menembus dinding depan/belakang (%.2f..%.2f, lim %.2f)"
			% [tier, n.name, belakang, depan, z_lim],
			belakang > -z_lim and depan < z_lim)


## Titik paling depan dari sekumpulan posisi. Daftar kosong mengembalikan -INF
## supaya perbandingan urutan tidak pernah lulus secara diam-diam.
func _max_z(list: Array) -> float:
	var m: float = -INF
	for p_v in list:
		var p: Vector3 = p_v
		m = maxf(m, p.z)
	return m


## Titik paling belakang. Daftar kosong mengembalikan INF, dengan alasan sama.
func _min_z(list: Array) -> float:
	var m: float = INF
	for p_v in list:
		var p: Vector3 = p_v
		m = minf(m, p.z)
	return m


## Kamera kini ISOMETRIK. Yang diuji bukan cuma "fokusnya di zona yang benar",
## tapi tiga hal yang menjadikannya isometrik dan bukan sekadar tampilan 3/4:
## proyeksinya ortografik, yaw-nya tepat 45 derajat, dan kemiringannya tepat
## atan(1/sqrt(2)). Ketiganya harus PERSIS - isometrik yang meleset dua derajat
## akan terlihat sebagai ubin lantai yang juling di seluruh layar.
##
## Framing ikut diuji karena pada ortografik jarak kamera tidak lagi mengatur
## zoom: kalau `size` salah hitung, ruangan terpotong tanpa ada satu pun angka
## posisi yang terlihat keliru.
func _check_camera_views() -> void:
	print("
-- Sudut Pandang Kamera (Isometrik) --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null or world.camera == null:
		_ok("kamera tersedia", false)
		return

	_ok("daftar sudut pandang ada 3", ShopWorld.VIEWS.size() == 3)
	_ok("proyeksi kamera ORTOGRAFIK (inti isometrik)",
		world.camera.projection == Camera3D.PROJECTION_ORTHOGONAL)
	_ok("size kamera mengatur sisi tegak (KEEP_HEIGHT)",
		world.camera.keep_aspect == Camera3D.KEEP_HEIGHT)

	for tier in range(1, 6):
		GameState.location_tier = tier
		world.rebuild()

		var w: float = EquipmentFactory.room_width(tier)
		var d: float = EquipmentFactory.room_depth(tier)
		var h: float = EquipmentFactory.room_height(tier)
		var part_z: float = EquipmentFactory.partition_z(tier)
		var ukuran: Dictionary = {}
		var cam_y: float = 0.0

		# Dinding yang menghadap kamera wajib disembunyikan, kalau tidak pemain
		# hanya menatap papan kayu selama tujuh menit.
		for nama in ShopWorld.NEAR_WALLS:
			var dinding := world.room.get_node_or_null(NodePath(nama)) as Node3D
			_ok("T%d dinding dekat '%s' disembunyikan" % [tier, nama],
				dinding != null and not dinding.visible)
		# ...dan dinding jauh justru WAJIB tampak, karena ialah latar ruangan.
		for nama2 in ["WallBack", "WallLeft"]:
			var jauh := world.room.get_node_or_null(NodePath(nama2)) as Node3D
			_ok("T%d dinding jauh '%s' tetap tampak" % [tier, nama2],
				jauh != null and jauh.visible)

		for v in ShopWorld.VIEWS:
			world.set_view(String(v), true)
			_ok("T%d sudut pandang '%s' tersimpan" % [tier, v], world.view == String(v))

			var pose: Array = world._camera_pose(String(v))
			var pos: Vector3 = pose[0]
			var focus: Vector3 = pose[1]
			var size: float = float(pose[2])
			ukuran[String(v)] = size

			# Pose yang dihitung tapi tidak pernah dipasang sama saja dengan bug.
			_ok("T%d '%s': pose benar-benar dipasang ke kamera" % [tier, v],
				world.camera.position.distance_to(pos) < 0.02)
			_ok("T%d '%s': size benar-benar dipasang ke kamera" % [tier, v],
				is_equal_approx(world.camera.size, size))

			# Kamera melayang di kuadran (+X, +Z): itulah yang membuat dinding
			# belakang dan kiri menjadi latar, bukan penghalang.
			_ok("T%d '%s': kamera di atas tinggi dinding (y %.2f > %.2f)"
				% [tier, v, pos.y, h], pos.y > h)
			_ok("T%d '%s': kamera di belakang fokus" % [tier, v], pos.z > focus.z)
			_ok("T%d '%s': kamera di sisi kanan fokus" % [tier, v], pos.x > focus.x)
			_ok("T%d '%s': fokus di dalam ruangan" % [tier, v],
				absf(focus.z) < d * 0.5)

			var dir: Vector3 = (focus - pos).normalized()
			var horiz: float = Vector2(dir.x, dir.z).length()

			# Kemiringan: harus PERSIS isometrik, bukan sekadar "dari atas".
			var pitch: float = rad_to_deg(atan2(-dir.y, horiz))
			_ok("T%d '%s': kemiringan isometrik (%.3f vs %.3f drjt)"
				% [tier, v, pitch, CAM_PITCH_DEG],
				absf(pitch - CAM_PITCH_DEG) < ANGLE_EPS)

			# Yaw: 45 derajat berarti komponen X dan Z arah pandang sama besar.
			var yaw: float = rad_to_deg(atan2(-dir.x, -dir.z))
			_ok("T%d '%s': yaw isometrik (%.3f vs %.3f drjt)"
				% [tier, v, yaw, CAM_YAW_DEG],
				absf(yaw - CAM_YAW_DEG) < ANGLE_EPS)

			match String(v):
				ShopWorld.VIEW_KITCHEN:
					_ok("T%d fokus Dapur di zona dapur (z %.2f < %.2f)"
						% [tier, focus.z, part_z], focus.z < part_z)
				ShopWorld.VIEW_SHOP:
					_ok("T%d fokus Toko di zona toko (z %.2f > %.2f)"
						% [tier, focus.z, part_z], focus.z > part_z)
				_:
					_ok("T%d fokus Semua di garis pembatas" % tier,
						is_equal_approx(focus.z, part_z))
					cam_y = pos.y
					# Lantai w x d dari yaw 45 derajat tergambar sebagai belah
					# ketupat; kotak ortografik wajib memuat KEDUA sisinya,
					# termasuk tinggi dinding yang ikut naik ke layar.
					var ketupat_w: float = (w + d) * cos(deg_to_rad(CAM_YAW_DEG))
					var ketupat_h: float = ketupat_w * sin(deg_to_rad(CAM_PITCH_DEG)) 						+ h * cos(deg_to_rad(CAM_PITCH_DEG))
					_ok("T%d Semua: sisi tegak muat (%.2f >= %.2f)"
						% [tier, size, ketupat_h], size >= ketupat_h)
					_ok("T%d Semua: sisi mendatar muat (%.2f >= %.2f)"
						% [tier, size * VIEW_ASPECT, ketupat_w],
						size * VIEW_ASPECT >= ketupat_w)

		# Pada ortografik, "mendekat" = size mengecil. Kalau tidak, tombol sudut
		# pandang tidak terasa melakukan apa-apa.
		var penuh: float = float(ukuran[ShopWorld.VIEW_ALL])
		_ok("T%d Dapur lebih rapat dari Semua (%.2f < %.2f)"
			% [tier, float(ukuran[ShopWorld.VIEW_KITCHEN]), penuh],
			float(ukuran[ShopWorld.VIEW_KITCHEN]) < penuh)
		_ok("T%d Toko lebih rapat dari Semua (%.2f < %.2f)"
			% [tier, float(ukuran[ShopWorld.VIEW_SHOP]), penuh],
			float(ukuran[ShopWorld.VIEW_SHOP]) < penuh)

		print("  T%d: size dapur %.2f  semua %.2f  toko %.2f, kamera setinggi %.2f vs dinding %.2f"
			% [tier, float(ukuran[ShopWorld.VIEW_KITCHEN]), penuh,
				float(ukuran[ShopWorld.VIEW_SHOP]), cam_y, h])

	# Sudut pandang asing harus diabaikan, bukan membuat kamera melompat.
	world.set_view(ShopWorld.VIEW_ALL, true)
	world.set_view("sudut_yang_tidak_ada", true)
	_ok("sudut pandang tak dikenal diabaikan", world.view == ShopWorld.VIEW_ALL)

	GameState.location_tier = 1
	world.rebuild()


## Tidak satu pun karakter boleh berdiri di dalam badan perabot.
##
## Penjaga ini ada karena kasir pernah berdiri 0,05 m di dalam dinding sekat,
## terpisah dari mejanya sendiri, sehingga tidak terlihat sama sekali pada sudut
## pandang "Toko" di Tier 2-4. Tidak ada satu pun assertion yang menangkapnya
## waktu itu karena suite hanya menguji posisi PERABOT, tidak pernah posisi STAF.
func _check_staff_clearance() -> void:
	print("\n-- Ruang Gerak Staf --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return
	var staff_sim: StaffSim = _main.systems["staff"]
	# Radius badan chibi; dipakai sebagai lingkar tubuh minimum.
	var r: float = 0.125

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.staff.clear()
		world.rebuild()

		# Pekerjakan satu kasir dan satu baker supaya aktornya benar-benar ada.
		staff_sim.hire("budi")
		staff_sim.hire("joko")
		world.rebuild()

		# Hanya perabot bernama yang diperiksa. Node wadah tanpa nama (dan ruangan
		# itu sendiri) punya AABB sebesar seluruh gedung, jadi apa pun "menembus"nya.
		var boxes: Array = []
		for child in world.fixtures.get_children():
			var n := child as Node3D
			if n == null:
				continue
			var cocok: bool = false
			for pre in FIXTURE_PREFIXES:
				if String(n.name).begins_with(pre):
					cocok = true
					break
			if not cocok:
				continue
			var b: AABB = _world_aabb(n)
			if b.size != Vector3.ZERO:
				boxes.append({"nama": String(n.name), "box": b})

		var diperiksa: int = 0
		for a in world.actors.get_children():
			var sa := a as StaffActor
			if sa == null:
				continue
			diperiksa += 1
			# Badan karakter sebagai kotak setinggi pinggang di sekitar home_pos.
			var p: Vector3 = sa.home_pos
			var tubuh := AABB(Vector3(p.x - r, 0.05, p.z - r), Vector3(r * 2.0, 0.90, r * 2.0))
			for e_v in boxes:
				var e: Dictionary = e_v
				var b: AABB = e["box"]
				_ok("T%d %s (%s) tidak menembus %s"
					% [tier, sa.staff_id, sa.role, String(e["nama"])],
					not tubuh.intersects(b))
			# Staf juga wajib berada di dalam ruangan.
			var wall: float = EquipmentFactory.room_wall_thickness()
			_ok("T%d %s di dalam ruangan" % [tier, sa.staff_id],
				absf(p.x) < EquipmentFactory.room_width(tier) * 0.5 - wall
				and absf(p.z) < EquipmentFactory.room_depth(tier) * 0.5 - wall)

		_ok("T%d ada aktor staf yang diperiksa" % tier, diperiksa >= 2)

		# Driver ojol juga tidak boleh berdiri menembus perabot -- titik tunggunya
		# pernah jatuh persis di dalam badan rak roti paling kanan di Ruko Tier 2.
		var dw: Vector3 = world._driver_wait_spot()
		var badan_driver := AABB(
			Vector3(dw.x - r, 0.05, dw.z - r), Vector3(r * 2.0, 0.90, r * 2.0))
		for e_v in boxes:
			var e2: Dictionary = e_v
			_ok("T%d titik tunggu driver tidak menembus %s" % [tier, String(e2["nama"])],
				not badan_driver.intersects(e2["box"] as AABB))
		_ok("T%d titik tunggu driver di dalam ruangan" % tier,
			absf(dw.x) < EquipmentFactory.room_width(tier) * 0.5
			and absf(dw.z) < EquipmentFactory.room_depth(tier) * 0.5)

		# Kasir harus berada di SISI DAPUR meja, bukan di sisi pembeli.
		var z_div: float = EquipmentFactory.partition_z(tier)
		for a in world.actors.get_children():
			var sa := a as StaffActor
			if sa == null or sa.role != "kasir":
				continue
			_ok("T%d kasir di sisi dapur meja (z %.2f < %.2f)"
				% [tier, sa.home_pos.z, z_div], sa.home_pos.z < z_div)

		print("  T%d: %d aktor staf diperiksa terhadap %d perabot"
			% [tier, diperiksa, boxes.size()])

		staff_sim.fire("budi")
		staff_sim.fire("joko")

	GameState.location_tier = 1
	GameState.staff.clear()
	world.rebuild()


## Membuka lalu menutup Mode Dekorasi tanpa memindahkan apa pun TIDAK BOLEH
## mengubah apa pun, apalagi merusak denah.
##
## Penjaga ini ada karena grid dekorasi dulu berukuran tetap 12x10 (6,6 x 5,5 m)
## sementara Garasi Tier 1 hanya 3 x 6 m: sekali buka-tutup, mixer dan oven
## terlempar 0,68 m ke belakang dinding dan antrean berdiri di luar gedung.
func _check_decoration_roundtrip() -> void:
	print("\n-- Mode Dekorasi --")
	var world: ShopWorld = _main.world as ShopWorld
	if world == null:
		_ok("ShopWorld tersedia", false)
		return

	for tier in range(1, 6):
		GameState.location_tier = tier
		GameState.decor.clear()
		world.rebuild()

		var sebelum_mixer: Array[Vector3] = world.mixer_pos.duplicate()
		var sebelum_oven: Array[Vector3] = world.oven_pos.duplicate()
		var sebelum_rak: Array[Vector3] = world.display_pos.duplicate()

		# Buka lalu tutup Mode Dekorasi tanpa menyentuh satu perabot pun.
		var dekor: DecorController = world.decor_controller()
		dekor.mulai()
		dekor.selesai()
		world.rebuild()

		_ok("T%d buka-tutup dekorasi tidak menggeser mixer" % tier,
			_sama_posisi(sebelum_mixer, world.mixer_pos))
		_ok("T%d buka-tutup dekorasi tidak menggeser oven" % tier,
			_sama_posisi(sebelum_oven, world.oven_pos))
		_ok("T%d buka-tutup dekorasi tidak menggeser rak" % tier,
			_sama_posisi(sebelum_rak, world.display_pos))

		var wall: float = EquipmentFactory.room_wall_thickness()
		var z_div: float = EquipmentFactory.partition_z(tier)
		var x_lim: float = EquipmentFactory.room_width(tier) * 0.5 - wall
		var z_lim: float = EquipmentFactory.room_depth(tier) * 0.5 - wall

		for p in world.mixer_pos:
			_ok("T%d pasca-dekorasi mixer di dapur & dalam ruangan" % tier,
				p.z < z_div and absf(p.x) < x_lim and absf(p.z) < z_lim)
		for p in world.oven_pos:
			_ok("T%d pasca-dekorasi oven di dapur & dalam ruangan" % tier,
				p.z < z_div and absf(p.x) < x_lim and absf(p.z) < z_lim)
		for p in world.display_pos:
			_ok("T%d pasca-dekorasi rak di toko & dalam ruangan" % tier,
				p.z > z_div and absf(p.x) < x_lim and absf(p.z) < z_lim)
		# Meja kasir tidak bisa dipindah pemain sama sekali, jadi yang diuji
		# bukan "tetap di garisnya" melainkan "tidak bergeser sedikit pun".
		for p in world.cashier_pos:
			_ok("T%d pasca-dekorasi kasir tetap di baris mejanya" % tier,
				is_equal_approx(p.z, EquipmentFactory.counter_z(tier)))
		# Titik antrean pertama harus tetap di dalam gedung.
		if not world.queue_pos.is_empty():
			_ok("T%d pasca-dekorasi antrean mulai di dalam gedung" % tier,
				absf(world.queue_pos[0].z) < z_lim)

		_check_fixture_bounds(tier)
		print("  T%d: denah tetap sah dan tidak bergeser setelah buka-tutup dekorasi"
			% tier)

	GameState.location_tier = 1
	GameState.decor.clear()
	world.rebuild()
