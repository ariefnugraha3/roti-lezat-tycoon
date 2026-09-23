class_name StaffSim
extends Node

## StaffSim -- otomasi Asisten Kasir & Asisten Dapur (GDD 3.1-3.2), batas kapasitas
## staf (GDD 3.3), rekrutmen/penggajian/pemecatan (GDD 3.4), serta Mode Solo (GDD 3.0.C).
##
## Sistem ini TIDAK memakai _process: seluruh langkahnya dijalankan oleh Main lewat
## antarmuka lima metode ARCHITECTURE 7.0, supaya simulasi bisa di-step headless dan
## hasilnya bisa diulang persis dari sebuah benih acak.
##
## Pembagian tugas dengan sistem tetangga (ARCHITECTURE 7) -- StaffSim sengaja TIDAK
## menduplikasi logika mereka:
##   * ProductionSystem tetap pemilik antrean job mixer/oven, durasi tahap, dan
##     mekanisme gosong. Baker di sini hanya MEMUTUSKAN resep apa yang dibuat lalu
##     memanggil `queue_batch()`, dan mengangkat loyang matang lewat `collect()`
##     (Proteksi Roti Gosong / Auto-Retrieve GDD 3.2).
##   * CustomerSim tetap pemilik antrean pelanggan, keranjang belanja, harga, dan
##     rating. StaffSim menyediakan "lane" kasir: berapa meja yang benar-benar terisi
##     staf, berapa detik satu pelanggan diproses, dan hitung mundur pelayanannya.
##   * EconomySystem tetap pemilik ledger dan pemotong gaji; StaffSim hanya menyiapkan
##     rincian gaji lewat `salary_detail()` / `salary_total()`.

# --- ID kanonik (ARCHITECTURE 2.5) ---------------------------------------------

const ROLE_KASIR: String = "kasir"
const ROLE_BAKER: String = "baker"

## Mode kerja Asisten Dapur (GDD 3.2 "Catatan Dapur").
const MODE_AUTO: String = "auto_replenish"
const MODE_TARGET: String = "target"

## Status pelanggan kanonik yang boleh disentuh StaffSim (ARCHITECTURE 7.1).
const STATE_QUEUE: String = "antre"
const STATE_SERVED: String = "dilayani"
const STATE_DONE: String = "selesai"

## Jenis slot alat pada job produksi (ARCHITECTURE 7.1).
const SLOT_OVEN: String = "oven"

## Tahap job yang urusannya sudah selesai, tidak perlu diangkat lagi.
const STAGE_COLLECTED: String = "collected"
const STAGE_BURNED: String = "burned"

## Arketipe yang diproses 2x lebih lambat di kasir (CustomerDB.cashier_time_mult = 2.0)
## dan menjadi sasaran perk Kasir Tier 4 (GDD 3.1).
const ARCH_GALAU: String = "si_galau"

# --- Keadaan internal ----------------------------------------------------------

## Rujukan ke Main; dipakai untuk menemukan ProductionSystem lewat `Main.systems`.
var _main: Node = null

## Fase hari berjalan; diperbarui dari EventBus.phase_changed.
var _phase: String = GameConfig.PHASE_PREP

## Satu entri per meja kasir yang benar-benar terisi staf:
## {staff_id, tier, speed, busy, remaining, customer}
var _lanes: Array = []

## Cap kondisi lane terakhir supaya penataan ulang hanya terjadi saat ada perubahan.
var _lane_stamp: String = ""

## staff_id -> sisa detik sampai baker boleh menaruh adonan berikutnya.
var _baker_cooldown: Dictionary = {}

## Indeks slot oven yang akan diangkat baker pada tick berikutnya (anti-gosong).
var _pending_collect: Array[int] = []

## staff_id -> true untuk staf yang diliburkan PAKSA oleh Mode Solo (GDD 3.0.C),
## sehingga hanya mereka yang dipanggil kembali saat Mode Solo padam.
var _benched_by_solo: Dictionary = {}

## Benar bila Mode Solo sudah diterapkan ke seluruh staf.
var _solo_applied: bool = false

## Rincian gaji staf yang dipecat hari ini: GDD 3.4 mewajibkan gaji hari tersebut
## tetap dibayar penuh pada laporan penutupan sore itu.
var _fired_today: Array = []

## Callback opsional milik CustomerSim, dipanggil saat satu pelayanan kasir selesai:
## `func(customer: Dictionary, lane: int) -> void`.
var _service_cb: Callable = Callable()


# --- Antarmuka sistem simulasi (ARCHITECTURE 7.0) ------------------------------

func setup(main: Node) -> void:
	_main = main
	if not EventBus.phase_changed.is_connected(_on_phase_changed):
		EventBus.phase_changed.connect(_on_phase_changed)
	if not EventBus.production_finished.is_connected(_on_production_finished):
		EventBus.production_finished.connect(_on_production_finished)
	if not EventBus.solo_mode_changed.is_connected(_on_solo_mode_changed):
		EventBus.solo_mode_changed.connect(_on_solo_mode_changed)
	reset()


func reset() -> void:
	_release_all_lanes(false)
	_lanes.clear()
	_lane_stamp = ""
	_baker_cooldown.clear()
	_pending_collect.clear()
	_benched_by_solo.clear()
	_fired_today.clear()
	_phase = GameConfig.PHASE_PREP
	_solo_applied = GameState.solo_mode
	_enforce_solo()
	_rebuild_lanes()


func sim_tick(delta: float, hour: float) -> void:
	if delta <= 0.0:
		return
	_enforce_solo()
	if _roster_stamp() != _lane_stamp:
		_rebuild_lanes()
	_flush_pending_collect()
	_tick_cashiers(delta)
	_tick_bakers(delta, hour)


func on_day_start(day: int) -> void:
	_phase = GameConfig.PHASE_PREP
	_fired_today.clear()
	_pending_collect.clear()
	# Semua baker boleh langsung menaruh adonan pertama pukul 05:00.
	_baker_cooldown.clear()
	_release_all_lanes(false)
	_enforce_solo()
	_rebuild_lanes()
	print_verbose("[staf] hari %d: %d kasir aktif, %d baker aktif" % [
		day,
		GameState.active_staff(ROLE_KASIR).size(),
		GameState.active_staff(ROLE_BAKER).size(),
	])


func on_day_end(ledger: Dictionary) -> void:
	# Toko tutup: pelanggan yang masih di meja kasir dilepas agar tidak tersangkut.
	_release_all_lanes(false)
	_pending_collect.clear()
	# EconomySystem yang memotong kas dan memiliki ledger. StaffSim hanya menitipkan
	# rincian bila belum diisi, supaya Daily Summary tetap punya data apa pun urutan
	# pemanggilan on_day_end.
	if not ledger.has("salary_detail"):
		ledger["salary_detail"] = salary_detail()
	if not ledger.has("salary"):
		ledger["salary"] = salary_total()
	_fired_today.clear()


# --- Rekrutmen & penggajian (GDD 3.3 & 3.4) ------------------------------------

## Daftar ID pelamar yang MASIH bisa direkrut untuk satu peran ("kasir"|"baker").
## Rekrutmen gratis (GDD 3.4); yang membatasi hanya slot lokasi (GDD 3.3).
##
## Mengembalikan ID, BUKAN entri lengkap — bentuknya harus sama dengan
## `StaffDB.roster()` yang dibungkusnya, karena StaffScreen memakai keduanya
## bergantian: sumber data yang dipilih tidak boleh mengubah bentuk datanya.
## Dulu fungsi ini mengembalikan Dictionary dan layar lamaran ikut runtuh
## ("Nonexistent 'String' constructor") begitu StaffSim benar-benar terpasang.
func roster(role: String) -> Array:
	var out: Array = []
	if role != ROLE_KASIR and role != ROLE_BAKER:
		return out
	for sid: String in StaffDB.roster(role, GameState.location_tier):
		if _index_of(sid) >= 0:
			continue
		out.append(sid)
	return out


## Jumlah staf yang dipekerjakan untuk satu peran, termasuk yang sedang diliburkan
## (slot tetap terpakai selama belum dipecat).
func staff_count(role: String) -> int:
	var n: int = 0
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if String(s.get("role", "")) == role:
			n += 1
	return n


## Jumlah staf yang benar-benar bekerja hari ini.
func active_count(role: String) -> int:
	return GameState.active_staff(role).size()


## Batas jumlah staf untuk satu peran di tier lokasi sekarang (GDD 3.3).
func capacity(role: String) -> int:
	return maxi(0, LocationDB.max_staff(GameState.location_tier, role))


func can_hire(role: String) -> bool:
	if role != ROLE_KASIR and role != ROLE_BAKER:
		return false
	return staff_count(role) < capacity(role)


## Merekrut satu pelamar. GRATIS (GDD 3.4) -- beban hanya gaji harian.
func hire(staff_id: String) -> bool:
	var db: Dictionary = StaffDB.entry(staff_id)
	if db.is_empty():
		return false
	var person: String = String(db.get("name", staff_id))
	if _index_of(staff_id) >= 0:
		EventBus.toast.emit("%s sudah bekerja di toko." % person, "warning")
		return false
	var role: String = String(db.get("role", ""))
	if role != ROLE_KASIR and role != ROLE_BAKER:
		return false
	if not can_hire(role):
		EventBus.toast.emit("Slot %s di %s sudah penuh (maks %d orang)." % [
			_role_label(role), LocationDB.display_name(GameState.location_tier), capacity(role),
		], "warning")
		return false

	var tier: int = clampi(int(db.get("tier", 1)), 1, 5)
	# GDD 3.0.C: selama Mode Solo semua karyawan diliburkan, termasuk yang baru direkrut.
	var benched: bool = GameState.solo_mode
	GameState.staff.append({
		"staff_id": staff_id,
		"role": role,
		"tier": tier,
		"on_leave": benched,
	})
	if role == ROLE_BAKER and not GameState.baker_mode.has(staff_id):
		GameState.baker_mode[staff_id] = {"mode": MODE_AUTO, "recipe_id": ""}
	if benched:
		_benched_by_solo[staff_id] = true

	_rebuild_lanes()
	AudioBus.sfx("paper")
	EventBus.staff_hired.emit(staff_id)
	EventBus.toast.emit("%s bergabung sebagai %s, gaji %s/hari." % [
		person, _role_label(role), GameConfig.kr(float(StaffDB.salary_for(role, tier))),
	], "people")
	if benched:
		EventBus.staff_leave_toggled.emit(staff_id, true)
		EventBus.toast.emit("Mode Solo masih aktif, %s diliburkan dulu." % person, "moon")
	return true


## Memberhentikan staf. Tanpa denda, tetapi gaji hari ini tetap dibayar penuh (GDD 3.4).
func fire(staff_id: String) -> bool:
	var idx: int = _index_of(staff_id)
	if idx < 0:
		return false
	var s: Dictionary = GameState.staff[idx]
	var db: Dictionary = StaffDB.entry(staff_id)
	var person: String = String(db.get("name", staff_id))
	if not bool(s.get("on_leave", false)):
		_fired_today.append(_salary_row(s))

	GameState.staff.remove_at(idx)
	GameState.baker_mode.erase(staff_id)
	_benched_by_solo.erase(staff_id)
	_baker_cooldown.erase(staff_id)
	_release_staff_lane(staff_id)
	_rebuild_lanes()

	AudioBus.sfx("door")
	EventBus.staff_fired.emit(staff_id)
	EventBus.toast.emit("%s berhenti bekerja. Gaji hari ini tetap dibayar penuh." % person, "sad")
	return true


## Meliburkan atau memanggil kembali seorang staf (GDD 3.0.C & 3.4).
func set_leave(staff_id: String, on_leave: bool) -> bool:
	var idx: int = _index_of(staff_id)
	if idx < 0:
		return false
	var s: Dictionary = GameState.staff[idx]
	if bool(s.get("on_leave", false)) == on_leave:
		return true
	if GameState.solo_mode and not on_leave:
		EventBus.toast.emit("Mode Solo aktif: karyawan dipanggil lagi setelah kas pulih.", "warning")
		return false

	s["on_leave"] = on_leave
	if on_leave:
		_release_staff_lane(staff_id)
		_baker_cooldown.erase(staff_id)
	else:
		_benched_by_solo.erase(staff_id)
	_rebuild_lanes()
	AudioBus.sfx("tap")
	EventBus.staff_leave_toggled.emit(staff_id, on_leave)
	return true


## Mengatur mode kerja Asisten Dapur (GDD 3.2): "auto_replenish" atau "target".
func set_baker_mode(staff_id: String, mode: String, recipe_id: String = "") -> bool:
	var idx: int = _index_of(staff_id)
	if idx < 0:
		return false
	var s: Dictionary = GameState.staff[idx]
	if String(s.get("role", "")) != ROLE_BAKER:
		return false
	var m: String = mode
	if m != MODE_AUTO and m != MODE_TARGET:
		m = MODE_AUTO
	var rid: String = recipe_id
	if m == MODE_TARGET:
		if RecipeDB.entry(rid).is_empty():
			return false
	else:
		rid = ""
	GameState.baker_mode[staff_id] = {"mode": m, "recipe_id": rid}
	AudioBus.sfx("tap")
	return true


## Mode kerja seorang baker; selalu mengembalikan bentuk lengkap walau belum diatur.
func baker_mode_of(staff_id: String) -> Dictionary:
	var cfg: Dictionary = GameState.baker_mode.get(staff_id, {})
	var m: String = String(cfg.get("mode", MODE_AUTO))
	if m != MODE_AUTO and m != MODE_TARGET:
		m = MODE_AUTO
	return {"mode": m, "recipe_id": String(cfg.get("recipe_id", ""))}


## Rincian gaji hari ini untuk ledger (ARCHITECTURE 7.1: {staff_id, name, role, tier, salary}).
## Staf yang diliburkan TIDAK digaji (GDD 3.0.C); staf yang dipecat hari ini tetap digaji
## penuh (GDD 3.4).
func salary_detail() -> Array:
	var out: Array = []
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if bool(s.get("on_leave", false)):
			continue
		out.append(_salary_row(s))
	for f: Variant in _fired_today:
		var row: Dictionary = f
		out.append(row.duplicate())
	return out


func salary_total() -> float:
	var total: float = 0.0
	for e: Variant in salary_detail():
		var row: Dictionary = e
		total += float(row.get("salary", 0))
	return total


# --- API kasir untuk CustomerSim -----------------------------------------------

## CustomerSim mendaftarkan callback `func(customer: Dictionary, lane: int) -> void`
## yang dipanggil begitu satu pelayanan kasir rampung.
func set_service_callback(cb: Callable) -> void:
	_service_cb = cb


## Jumlah meja kasir yang benar-benar terisi staf. 0 berarti pemain melayani sendiri
## (hari-hari awal atau Mode Solo GDD 3.0.C).
func cashier_lanes() -> int:
	return _lanes.size()


func has_active_cashier() -> bool:
	return not _lanes.is_empty()


## Indeks lane yang menganggur, atau -1 bila semua sibuk / tidak ada kasir.
func free_lane() -> int:
	for i: int in range(_lanes.size()):
		var lane: Dictionary = _lanes[i]
		if String(lane.get("staff_id", "")).is_empty():
			continue
		if not bool(lane.get("busy", false)):
			return i
	return -1


func is_lane_busy(lane: int) -> bool:
	if lane < 0 or lane >= _lanes.size():
		return false
	var l: Dictionary = _lanes[lane]
	return bool(l.get("busy", false))


## Data staf yang menjaga sebuah lane ({} bila lane tidak sah).
func lane_staff(lane: int) -> Dictionary:
	if lane < 0 or lane >= _lanes.size():
		return {}
	var l: Dictionary = _lanes[lane]
	return StaffDB.entry(String(l.get("staff_id", "")))


## Lama proses kasir untuk satu pelanggan, dalam detik nyata (GDD 3.1).
## `lane` = -1 memakai kasir aktif tercepat. 0.0 berarti tidak ada kasir sama sekali.
func service_time(archetype: String, lane: int = -1) -> float:
	var sid: String = ""
	if lane >= 0 and lane < _lanes.size():
		var l: Dictionary = _lanes[lane]
		sid = String(l.get("staff_id", ""))
	else:
		sid = _fastest_cashier_id()
	if sid.is_empty():
		return 0.0
	var db: Dictionary = StaffDB.entry(sid)
	if db.is_empty():
		return 0.0
	var base: float = float(db.get("speed", 0.0))
	if base <= 0.0:
		return 0.0

	var mult: float = 1.0
	var c: Dictionary = CustomerDB.entry(archetype)
	if not c.is_empty():
		mult = float(c.get("cashier_time_mult", 1.0))
	if archetype == ARCH_GALAU:
		# GDD 3.1 perk Tier 4: memproses "Si Galau" 2x lebih cepat.
		var extra: Dictionary = db.get("extra", {})
		var speedup: float = float(extra.get("galau_speedup", 0.0))
		if speedup > 0.0:
			mult /= speedup
	return maxf(0.0, base * mult)


## Menempatkan seorang pelanggan ke meja kasir yang kosong. Mengubah `state` dan
## `cashier_index` pada Dictionary pelanggan (bentuk ARCHITECTURE 7.1) tanpa menambah
## kunci baru. False bila tidak ada kasir yang menganggur.
func begin_service(customer: Dictionary) -> bool:
	if customer.is_empty():
		return false
	var lane: int = free_lane()
	if lane < 0:
		return false
	var archetype: String = String(customer.get("archetype", ""))
	var dur: float = service_time(archetype, lane)
	if dur <= 0.0:
		return false
	var l: Dictionary = _lanes[lane]
	l["busy"] = true
	l["remaining"] = dur
	l["customer"] = customer
	customer["cashier_index"] = lane
	customer["state"] = STATE_SERVED
	return true


## Membatalkan pelayanan (mis. pelanggan kabur) tanpa mengembalikannya ke antrean.
func abort_service(lane: int) -> void:
	if lane < 0 or lane >= _lanes.size():
		return
	var l: Dictionary = _lanes[lane]
	_release_lane_dict(l, false)


## Pengali stres antrean dari perk Kasir Tier 3 (-15%, GDD 3.1). 1.0 bila tidak ada.
func queue_stress_mult() -> float:
	var mult: float = 1.0
	for e: Variant in GameState.active_staff(ROLE_KASIR):
		var s: Dictionary = e
		var db: Dictionary = StaffDB.entry(String(s.get("staff_id", "")))
		if db.is_empty():
			continue
		var extra: Dictionary = db.get("extra", {})
		var v: float = 1.0 + float(extra.get("queue_stress", 0.0))
		if v < mult:
			mult = v
	return maxf(0.0, mult)


## Peluang pelanggan memberi tip berkat perk Kasir Tier 5 (+5%, GDD 3.1).
func tip_chance() -> float:
	var best: float = 0.0
	for e: Variant in GameState.active_staff(ROLE_KASIR):
		var s: Dictionary = e
		var db: Dictionary = StaffDB.entry(String(s.get("staff_id", "")))
		if db.is_empty():
			continue
		var extra: Dictionary = db.get("extra", {})
		best = maxf(best, float(extra.get("tip_chance", 0.0)))
	return clampf(best, 0.0, 1.0)


# --- API baker untuk ProductionSystem ------------------------------------------

## Pengali kecepatan kerja baker terbaik yang sedang bertugas (GDD 3.2).
## 1.0 = waktu standar alat, yaitu juga nilai saat pemain bekerja sendirian.
func baker_speed_mult() -> float:
	var best: float = 1.0
	var found: bool = false
	for e: Variant in GameState.active_staff(ROLE_BAKER):
		var s: Dictionary = e
		var v: float = StaffDB.speed_for(ROLE_BAKER, clampi(int(s.get("tier", 1)), 1, 5))
		if not found or v > best:
			best = v
			found = true
	if not found:
		return 1.0
	return maxf(0.01, best)


## Peluang Proteksi Roti Gosong (Auto-Retrieve) baker terbaik (GDD 3.2). 0.0 bila tidak
## ada baker: pemain harus mengangkat loyang sendiri.
func anti_burn_chance() -> float:
	var best: float = 0.0
	for e: Variant in GameState.active_staff(ROLE_BAKER):
		var s: Dictionary = e
		best = maxf(best, StaffDB.anti_burn(clampi(int(s.get("tier", 1)), 1, 5)))
	return clampf(best, 0.0, 1.0)


# --- Langkah per tick ----------------------------------------------------------

## Kasir melayani antrean secara otomatis pada kecepatan tier-nya (GDD 3.1).
## Beberapa meja kasir bekerja paralel -- masing-masing punya hitung mundur sendiri.
func _tick_cashiers(delta: float) -> void:
	if _lanes.is_empty():
		return
	for i: int in range(_lanes.size()):
		var lane: Dictionary = _lanes[i]
		if not bool(lane.get("busy", false)):
			continue
		var remaining: float = float(lane.get("remaining", 0.0)) - delta
		if remaining > 0.0:
			lane["remaining"] = remaining
			continue
		var customer: Dictionary = lane.get("customer", {})
		lane["busy"] = false
		lane["remaining"] = 0.0
		lane["customer"] = {}
		if customer.is_empty():
			continue
		if _service_cb.is_valid():
			# CustomerSim yang menghitung keranjang, uang, dan sinyal customer_served.
			_service_cb.call(customer, i)
		else:
			customer["state"] = STATE_DONE
			customer["cashier_index"] = -1


## Baker memproduksi roti secara otomatis (GDD 3.2) menurut mode kerjanya.
func _tick_bakers(delta: float, hour: float) -> void:
	if _phase == GameConfig.PHASE_CLOSE:
		return
	var bakers: Array = GameState.active_staff(ROLE_BAKER)
	if bakers.is_empty():
		return
	var prod: Node = _system("prod")
	if prod == null or not prod.has_method("queue_batch"):
		return

	# Rak penuh: percuma menambah adonan, roti matang tidak akan tertampung.
	var display_room: int = GameState.display_capacity() - GameState.display_total()
	# Sisa waktu operasional hari ini dalam detik nyata; batch yang tidak akan sempat
	# matang sebelum pukul 18:00 hanya membuang bahan dan berisiko gosong.
	var day_left: float = maxf(0.0, (GameConfig.HOUR_CLOSE - hour) * GameConfig.SECONDS_PER_GAME_HOUR)

	for e: Variant in bakers:
		var s: Dictionary = e
		var sid: String = String(s.get("staff_id", ""))
		if sid.is_empty():
			continue
		var cd: float = float(_baker_cooldown.get(sid, 0.0)) - delta
		if cd > 0.0:
			_baker_cooldown[sid] = cd
			continue
		# Satu siklus kerja = selama mixer terpakai, dipercepat kemampuan baker.
		_baker_cooldown[sid] = _baker_cycle(s)
		if display_room <= 0:
			continue
		if _batch_seconds(s) > day_left:
			continue
		var rid: String = _pick_recipe(sid)
		if rid.is_empty():
			continue
		if not bool(prod.call("queue_batch", rid, 1)):
			continue
		var rec: Dictionary = RecipeDB.entry(rid)
		display_room -= maxi(0, int(rec.get("yield_count", 0)))


## Mengangkat loyang yang dijadwalkan pada tick sebelumnya (anti-gosong GDD 3.2).
func _flush_pending_collect() -> void:
	if _pending_collect.is_empty():
		return
	var prod: Node = _system("prod")
	if prod == null or not prod.has_method("collect"):
		_pending_collect.clear()
		return
	for slot: int in _pending_collect:
		prod.call("collect", slot)
	_pending_collect.clear()


## Resep yang akan dibuat seorang baker, atau "" bila tidak ada yang bisa dibuat.
func _pick_recipe(staff_id: String) -> String:
	var cfg: Dictionary = baker_mode_of(staff_id)
	if String(cfg.get("mode", MODE_AUTO)) == MODE_TARGET:
		# GDD 3.2 Mode Target Resep: satu resep terus-menerus HINGGA BAHAN HABIS.
		# Saat bahan habis baker berhenti, bukan berganti resep sendiri.
		var target: String = String(cfg.get("recipe_id", ""))
		if target.is_empty():
			return ""
		if not GameState.is_recipe_available(target):
			return ""
		if not GameState.can_afford_recipe(target):
			return ""
		return target
	return _lowest_stock_recipe()


## GDD 3.2 Mode Auto-Replenish: resep yang stoknya PALING SEDIKIT di rak display.
## Urutan pemilihan sepenuhnya deterministik (stok terkecil, lalu tier terendah, lalu
## urutan daftar resep terbuka) sehingga simulasi bisa diulang dari benih yang sama.
func _lowest_stock_recipe() -> String:
	var stock: Dictionary = {}
	for e: Variant in GameState.display_slots:
		var slot: Dictionary = e
		var rid: String = String(slot.get("recipe_id", ""))
		if rid.is_empty():
			continue
		stock[rid] = int(stock.get(rid, 0)) + int(slot.get("count", 0))

	var best: String = ""
	var best_count: int = 0
	var best_tier: int = 0
	for v: Variant in GameState.unlocked_recipes:
		var rid2: String = String(v)
		if not GameState.is_recipe_available(rid2):
			continue
		if not GameState.can_afford_recipe(rid2):
			continue
		var count: int = int(stock.get(rid2, 0))
		var tier: int = int(RecipeDB.entry(rid2).get("tier", 1))
		if best.is_empty() or count < best_count or (count == best_count and tier < best_tier):
			best = rid2
			best_count = count
			best_tier = tier
	return best


## Jeda antar adonan seorang baker: selama mixer bekerja, dibagi pengali kecepatannya.
func _baker_cycle(s: Dictionary) -> float:
	var mix: float = EquipmentDB.mixer_time(GameState.mixer_tier)
	if mix <= 0.0:
		mix = EquipmentDB.mixer_time(1)
	return maxf(0.0, mix / _baker_speed_of(s))


## Perkiraan lama satu batch dari adonan sampai matang (mixer + oven), sudah dipercepat
## kemampuan baker -- dipakai untuk menahan produksi menjelang toko tutup.
func _batch_seconds(s: Dictionary) -> float:
	var total: float = EquipmentDB.mixer_time(GameState.mixer_tier) + EquipmentDB.oven_time(GameState.oven_tier)
	return maxf(0.0, total / _baker_speed_of(s))


func _baker_speed_of(s: Dictionary) -> float:
	var speed: float = StaffDB.speed_for(ROLE_BAKER, clampi(int(s.get("tier", 1)), 1, 5))
	return maxf(0.01, speed)


# --- Penataan meja kasir -------------------------------------------------------

## Cap kondisi yang menentukan susunan lane: tier lokasi + daftar kasir aktif.
func _roster_stamp() -> String:
	var parts: PackedStringArray = PackedStringArray()
	parts.append(str(GameState.location_tier))
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if String(s.get("role", "")) != ROLE_KASIR:
			continue
		if bool(s.get("on_leave", false)):
			continue
		parts.append(String(s.get("staff_id", "")))
	return "|".join(parts)


## GDD 3.1 "Catatan Kasir": lebih dari satu meja kasir membuka antrean paralel.
## Jumlah lane = min(kasir aktif, jumlah meja kasir lokasi).
func _rebuild_lanes() -> void:
	var desks: int = maxi(0, LocationDB.cashier_slots(GameState.location_tier))
	var actives: Array = GameState.active_staff(ROLE_KASIR)
	actives.sort_custom(_cmp_cashier)
	var want: int = mini(desks, actives.size())

	while _lanes.size() > want:
		var dropped: Dictionary = _lanes.pop_back()
		_release_lane_dict(dropped, true)
	while _lanes.size() < want:
		_lanes.append({
			"staff_id": "",
			"tier": 0,
			"speed": 0.0,
			"busy": false,
			"remaining": 0.0,
			"customer": {},
		})

	for i: int in range(want):
		var s: Dictionary = actives[i]
		var sid: String = String(s.get("staff_id", ""))
		var lane: Dictionary = _lanes[i]
		if String(lane.get("staff_id", "")) == sid:
			continue
		# Petugas lane berganti: pelanggannya dikembalikan ke antrean, bukan hilang.
		_release_lane_dict(lane, true)
		var tier: int = clampi(int(s.get("tier", 1)), 1, 5)
		lane["staff_id"] = sid
		lane["tier"] = tier
		lane["speed"] = StaffDB.speed_for(ROLE_KASIR, tier)

	_lane_stamp = _roster_stamp()


## Urutan tetap: tier tertinggi lebih dulu, lalu abjad ID agar hasilnya deterministik.
func _cmp_cashier(a: Dictionary, b: Dictionary) -> bool:
	var ta: int = int(a.get("tier", 0))
	var tb: int = int(b.get("tier", 0))
	if ta != tb:
		return ta > tb
	return String(a.get("staff_id", "")) < String(b.get("staff_id", ""))


func _release_lane_dict(lane: Dictionary, requeue: bool) -> void:
	var was_busy: bool = bool(lane.get("busy", false))
	var customer: Dictionary = lane.get("customer", {})
	lane["busy"] = false
	lane["remaining"] = 0.0
	lane["customer"] = {}
	if not was_busy or customer.is_empty():
		return
	customer["cashier_index"] = -1
	if requeue:
		customer["state"] = STATE_QUEUE


func _release_staff_lane(staff_id: String) -> void:
	for e: Variant in _lanes:
		var lane: Dictionary = e
		if String(lane.get("staff_id", "")) != staff_id:
			continue
		_release_lane_dict(lane, true)
		lane["staff_id"] = ""
		lane["tier"] = 0
		lane["speed"] = 0.0


func _release_all_lanes(requeue: bool) -> void:
	for e: Variant in _lanes:
		var lane: Dictionary = e
		_release_lane_dict(lane, requeue)


func _fastest_cashier_id() -> String:
	var best: String = ""
	var best_speed: float = 0.0
	for e: Variant in GameState.active_staff(ROLE_KASIR):
		var s: Dictionary = e
		var sid: String = String(s.get("staff_id", ""))
		var speed: float = StaffDB.speed_for(ROLE_KASIR, clampi(int(s.get("tier", 1)), 1, 5))
		if speed <= 0.0:
			continue
		if best.is_empty() or speed < best_speed or (speed == best_speed and sid < best):
			best = sid
			best_speed = speed
	return best


# --- Mode Solo (GDD 3.0.C) -----------------------------------------------------

## Menjaga keadaan staf tetap sesuai GameState.solo_mode pada setiap tick.
func _enforce_solo() -> void:
	if GameState.solo_mode:
		_solo_applied = true
		_bench_all_for_solo()
	elif _solo_applied:
		_solo_applied = false
		_restore_from_solo()


## Semua karyawan aktif DILIBURKAN (bukan dipecat) dan tidak digaji.
func _bench_all_for_solo() -> void:
	var changed: bool = false
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if bool(s.get("on_leave", false)):
			continue
		var sid: String = String(s.get("staff_id", ""))
		s["on_leave"] = true
		_benched_by_solo[sid] = true
		_baker_cooldown.erase(sid)
		_release_staff_lane(sid)
		changed = true
		EventBus.staff_leave_toggled.emit(sid, true)
	if changed:
		_rebuild_lanes()
		EventBus.toast.emit("Mode Solo: semua karyawan diliburkan sementara.", "moon")


## Kas sudah pulih: karyawan yang tadi dipaksa libur dipanggil kembali bekerja.
func _restore_from_solo() -> void:
	# Berkas simpanan lama tidak menyimpan daftar ini; bila kosong, panggil semuanya
	# kembali sesuai janji GDD 3.0.C bahwa mereka memang akan kembali.
	var restore_all: bool = _benched_by_solo.is_empty()
	var changed: bool = false
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if not bool(s.get("on_leave", false)):
			continue
		var sid: String = String(s.get("staff_id", ""))
		if not restore_all and not _benched_by_solo.has(sid):
			continue
		s["on_leave"] = false
		changed = true
		EventBus.staff_leave_toggled.emit(sid, false)
	_benched_by_solo.clear()
	if changed:
		_rebuild_lanes()
		EventBus.toast.emit("Kas pulih: karyawan dipanggil kembali bekerja.", "people")


# --- Pendengar EventBus --------------------------------------------------------

func _on_phase_changed(phase: String) -> void:
	_phase = phase


## Proteksi Roti Gosong (GDD 3.2): saat oven selesai, baker berpeluang mengangkat
## loyang sendiri. Pengangkatannya dititipkan ke tick berikutnya agar tetap lewat
## ProductionSystem.collect() dan tidak menduplikasi logikanya.
func _on_production_finished(job: Dictionary) -> void:
	if String(job.get("slot_kind", "")) != SLOT_OVEN:
		return
	var stage: String = String(job.get("stage", ""))
	if stage == STAGE_COLLECTED or stage == STAGE_BURNED:
		return
	var chance: float = anti_burn_chance()
	if chance <= 0.0:
		return
	if chance < 1.0 and GameConfig.rng.randf() >= chance:
		return
	var slot: int = int(job.get("slot_index", -1))
	if slot < 0:
		return
	if not _pending_collect.has(slot):
		_pending_collect.append(slot)


func _on_solo_mode_changed(active: bool) -> void:
	if active:
		_solo_applied = true
		_bench_all_for_solo()
	else:
		_solo_applied = false
		_restore_from_solo()


# --- Pembantu internal ---------------------------------------------------------

func _index_of(staff_id: String) -> int:
	for i: int in range(GameState.staff.size()):
		var s: Dictionary = GameState.staff[i]
		if String(s.get("staff_id", "")) == staff_id:
			return i
	return -1


func _salary_row(s: Dictionary) -> Dictionary:
	var sid: String = String(s.get("staff_id", ""))
	var db: Dictionary = StaffDB.entry(sid)
	var role: String = String(s.get("role", db.get("role", "")))
	var tier: int = clampi(int(s.get("tier", db.get("tier", 1))), 1, 5)
	return {
		"staff_id": sid,
		"name": String(db.get("name", sid)),
		"role": role,
		"tier": tier,
		"salary": StaffDB.salary_for(role, tier),
	}


func _role_label(role: String) -> String:
	if role == ROLE_BAKER:
		return "Asisten Dapur"
	return "Asisten Kasir"


## Mengambil sistem lain dari Main.systems tanpa mengikat tipe kelasnya.
func _system(key: String) -> Node:
	if _main == null:
		return null
	var raw: Variant = _main.get("systems")
	if typeof(raw) != TYPE_DICTIONARY:
		return null
	var systems: Dictionary = raw
	var node: Variant = systems.get(key, null)
	if node is Node:
		return node
	return null
