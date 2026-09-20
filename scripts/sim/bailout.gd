class_name BailoutSystem
extends Node

## BailoutSystem — jaring pengaman "Tidak Ada Game Over" (GDD Seksi 3.0).
##
## Tiga tanggung jawab:
##   1. GDD 3.0.E — mengevaluasi tabel kondisi pemicu setiap pagi.
##   2. GDD 3.0.A/B — memicu cutscene Pak Lurah lalu memberi 650 KR + set bahan Tier 1.
##   3. GDD 3.0.C — menyalakan / mematikan Mode Solo "Kerja Sendiri Dulu".
##
## GDD 3.0.D dipatuhi ketat: frekuensi bailout TIDAK DIBATASI, tidak ada penalti,
## dan tidak ada penurunan rating sama sekali ("Pemerintah hadir diam-diam —
## pelanggan tidak tahu"). Kelas ini karena itu tidak pernah menyentuh
## GameState.store_rating maupun GameState.rotifood_rating.
##
## Tabel GDD 3.0.E yang diterjemahkan menjadi kode:
##   Saldo 0 DAN tidak bisa beli bahan apa pun         -> bailout aktif
##   Saldo 0 TAPI gudang masih ada stok terpakai       -> belum bailout (masih bisa produksi)
##   Saldo cukup membayar gaji karyawan                -> bailout tidak diperlukan
##   Saldo < total gaji tapi >= harga bahan Tier 1     -> peringatan liburkan karyawan manual

# ---------------------------------------------------------------------------
# Konstanta paket bantuan (GDD 3.0.B)
# ---------------------------------------------------------------------------

## "Bahan Baku Darurat — Set Tier 1 x1: Tepung (1) + Ragi (1) + Gula (1) + Air & Garam (1)".
const EMERGENCY_SET: Dictionary = {
	"tepung_terigu": 1,
	"ragi": 1,
	"gula_pasir": 1,
	"air_garam": 1,
}

## GDD 3.0.D "Cooldown Ringan": bangkrut lagi dalam 3 hari membuat Pak Lurah
## datang dengan dialog berbeda yang membawa satu tip strategi spesifik.
const REPEAT_WINDOW_DAYS: int = 3

## Jeda pemeriksaan Mode Solo dalam detik nyata. Saldo tidak perlu diperiksa tiap
## frame; jeda ini juga mencegah karyawan diliburkan-dipanggil berulang kali.
const SOLO_CHECK_INTERVAL: float = 1.0

# ---------------------------------------------------------------------------
# Keadaan internal
# ---------------------------------------------------------------------------

var _main: Node = null

## Benar bila Pak Lurah datang pada hari yang sedang berjalan.
var _bailout_today: bool = false

## Kunjungan ini termasuk kunjungan ulang dalam 3 hari (menentukan pilihan dialog).
var _repeat_visit: bool = false

## Daftar staff_id yang diliburkan OLEH Mode Solo, supaya pemanggilan kembali tidak
## ikut membangunkan karyawan yang sengaja diliburkan pemain secara manual.
var _benched_by_solo: Array = []

var _solo_timer: float = 0.0

## Penjaga agar peringatan gaji hanya muncul sekali per hari.
var _salary_warned_today: bool = false

## Hari terakhir yang sudah dievaluasi, penjaga on_day_start ganda.
var _evaluated_day: int = -1

# ---------------------------------------------------------------------------
# Antarmuka tick deterministik (ARCHITECTURE 7.0)
# ---------------------------------------------------------------------------

func setup(main: Node) -> void:
	_main = main
	_solo_timer = 0.0
	_bailout_today = GameState.last_bailout_day == GameState.day and GameState.bailout_count > 0
	_sync_solo_from_state()


## Mode Solo dievaluasi sepanjang hari: saldo bisa menembus batas 500 KR kapan saja
## (GDD 3.0.C "Saat saldo berada di kisaran 0-500 KR ... toko memasuki Mode Solo").
func sim_tick(delta: float, hour: float) -> void:
	_solo_timer += delta
	if _solo_timer < SOLO_CHECK_INTERVAL:
		return
	_solo_timer = 0.0
	_update_solo_mode()

	# Pengingat terakhir sebelum toko buka: gaji hari ini masih di luar jangkauan.
	if not _salary_warned_today and hour >= GameConfig.HOUR_OPEN:
		_warn_salary_if_needed()


## GDD 3.0.E dievaluasi tepat pada pergantian hari, sebelum toko buka.
func on_day_start(day: int) -> void:
	if day == _evaluated_day:
		return
	_evaluated_day = day
	_bailout_today = false
	_repeat_visit = false
	_salary_warned_today = false
	_solo_timer = 0.0

	if _should_bailout():
		_grant_bailout(day)

	# Peringatan gaji dinilai setelah bantuan cair, memakai saldo terbaru.
	_warn_salary_if_needed()
	_update_solo_mode()


func on_day_end(ledger: Dictionary) -> void:
	ledger["bailout"] = _bailout_today
	ledger["solo_mode"] = GameState.solo_mode


func reset() -> void:
	_bailout_today = false
	_repeat_visit = false
	_salary_warned_today = false
	_evaluated_day = -1
	_solo_timer = 0.0
	_benched_by_solo.clear()
	_sync_solo_from_state()

# ---------------------------------------------------------------------------
# API publik
# ---------------------------------------------------------------------------

## Benar bila Pak Lurah datang hari ini (dibaca EconomySystem & Daily Summary).
func bailed_out_today() -> bool:
	return _bailout_today


## Jumlah kunjungan Pak Lurah sepanjang permainan.
func bailout_count() -> int:
	return GameState.bailout_count


## Benar bila kunjungan terakhir terjadi dalam 3 hari sejak kunjungan sebelumnya
## (GDD 3.0.D) — dialognya memakai varian bertip strategi.
func is_repeat_visit() -> bool:
	return _repeat_visit


## Kalimat Pak Lurah untuk cutscene. Kunjungan pertama memakai dialog GDD 3.0.A;
## kunjungan ulang dalam 3 hari memakai varian GDD 3.0.D yang membawa satu tip.
## Kunjungan yang berjarak jauh kembali memakai sapaan hangat pertama.
func dialog_line() -> String:
	if _repeat_visit:
		return DialogDB.lurah_bailout(GameState.bailout_count)
	return DialogDB.lurah_bailout(1)


## Ringkasan isi paket bantuan untuk layar cutscene (GDD 3.0.B).
func package_summary() -> Dictionary:
	var items: Array = []
	for k: Variant in EMERGENCY_SET:
		var ing: String = String(k)
		items.append({
			"id": ing,
			"name": IngredientDB.display_name(ing),
			"qty": int(EMERGENCY_SET[k]),
		})
	return {
		"coins": GameConfig.BAILOUT_COINS,
		"items": items,
		"times": GameState.bailout_count,
		"repeat": _repeat_visit,
		"line": dialog_line(),
	}


## Total gaji harian seluruh karyawan yang sedang bekerja (GDD 3.4).
## Bila EconomySystem terpasang, angkanya diambil dari sana agar pembanding
## GDD 3.0.E persis sama dengan yang benar-benar dipotong saat tutup buku.
func active_salary_total() -> float:
	var econ: Node = _system("econ")
	if econ != null and econ.has_method("salary_due"):
		return float(econ.call("salary_due"))
	var total: float = 0.0
	for e: Variant in GameState.active_staff("kasir"):
		total += _salary_of(e)
	for e2: Variant in GameState.active_staff("baker"):
		total += _salary_of(e2)
	return total


## Harga bahan termurah yang masih bisa dibeli di Pasar (GDD 3.0.E baris 1).
func cheapest_ingredient_price() -> float:
	var best: int = -1
	for id: String in IngredientDB.ids():
		var p: int = IngredientDB.price(id)
		if p <= 0:
			continue
		if best < 0 or p < best:
			best = p
	if best < 0:
		return 0.0
	return float(best)


## "Harga bahan Tier 1" (GDD 3.0.E baris 4) = modal bahan satu batch resep Tier 1
## termurah, dihitung dari harga nyata IngredientDB.
func tier1_ingredient_cost() -> float:
	var best: int = -1
	for rid: String in RecipeDB.by_tier(1):
		var cost: int = RecipeDB.modal_computed(rid)
		if cost <= 0:
			continue
		if best < 0 or cost < best:
			best = cost
	if best < 0:
		return float(IngredientDB.total_price(EMERGENCY_SET))
	return float(best)

# ---------------------------------------------------------------------------
# GDD 3.0.E — evaluasi kondisi pemicu
# ---------------------------------------------------------------------------

## Bailout hanya menyala bila saldo benar-benar mentok DAN toko tidak punya cara
## lain untuk berjualan hari ini.
func _should_bailout() -> bool:
	# Baris 3: saldo masih sanggup membiayai operasi -> tidak perlu bantuan.
	if GameState.coins >= cheapest_ingredient_price():
		return false
	# Baris 2: gudang (atau rak display) masih bisa dijadikan uang -> belum bailout.
	if _can_still_operate():
		return false
	# Baris 1: saldo 0 dan tidak bisa membeli bahan apa pun.
	return true


## Toko dianggap masih bisa jalan bila sanggup memproduksi minimal satu batch dari
## stok gudang, atau masih punya dagangan di rak display untuk dijual hari ini.
func _can_still_operate() -> bool:
	for v: Variant in GameState.unlocked_recipes:
		var rid: String = String(v)
		if not GameState.is_recipe_available(rid):
			continue
		if GameState.can_afford_recipe(rid):
			return true
	return GameState.display_total() > 0


## GDD 3.0.E baris 4: saldo tidak cukup menggaji, tetapi masih bisa beli bahan Tier 1.
## Sistem hanya MEMPERINGATKAN; keputusan meliburkan karyawan tetap di tangan pemain.
func _warn_salary_if_needed() -> void:
	if _salary_warned_today:
		return
	var salary: float = active_salary_total()
	if salary <= 0.0:
		return
	if GameState.coins >= salary:
		return
	if GameState.coins < tier1_ingredient_cost():
		return
	_salary_warned_today = true
	AudioBus.sfx("paper")
	EventBus.toast.emit(
		"Saldo %s belum cukup membayar gaji %s hari ini. Liburkan sebagian karyawan dulu, ya." % [
			GameConfig.kr(GameState.coins), GameConfig.kr(salary)
		],
		"warning"
	)

# ---------------------------------------------------------------------------
# GDD 3.0.A & 3.0.B — kunjungan Pak Lurah dan paket bantuan
# ---------------------------------------------------------------------------

func _grant_bailout(day: int) -> void:
	var previous_day: int = GameState.last_bailout_day
	_repeat_visit = GameState.bailout_count > 0 and previous_day > 0 and (day - previous_day) <= REPEAT_WINDOW_DAYS

	GameState.bailout_count += 1
	GameState.last_bailout_day = day
	_bailout_today = true

	# UI memutar cutscene Pak Lurah dari sinyal ini (ARCHITECTURE 5).
	EventBus.bailout_triggered.emit(GameState.bailout_count)

	# Koin Roti Subsidi 650 KR.
	GameState.add_coins(GameConfig.BAILOUT_COINS, "bantuan Pak Lurah")

	# Set bahan Tier 1 langsung masuk gudang.
	var delivered: int = 0
	for k: Variant in EMERGENCY_SET:
		delivered += GameState.pantry_add(String(k), int(EMERGENCY_SET[k]))

	AudioBus.sfx("coin")
	EventBus.toast.emit(
		"Pak Lurah datang membawa %s dan %d bahan darurat." % [GameConfig.kr(GameConfig.BAILOUT_COINS), delivered],
		"heart"
	)
	if delivered <= 0:
		# Gudang penuh: bantuan bahan tidak muat, tetapi koin tetap cair.
		EventBus.toast.emit("Gudang penuh, bahan bantuan tidak muat. Pakai dulu stok yang ada.", "box")

	# GDD 3.0.D: tidak ada stigma. Rating toko maupun RotiFood sengaja tidak disentuh.
	print_verbose("[bailout] kunjungan ke-%d pada hari %d (ulang: %s)" % [GameState.bailout_count, day, str(_repeat_visit)])

# ---------------------------------------------------------------------------
# GDD 3.0.C — Mode Solo "Kerja Sendiri Dulu"
# ---------------------------------------------------------------------------

## Menyalakan Mode Solo saat saldo berada di kisaran 0 - 500 KR, dan mematikannya
## kembali saat pemain "punya cukup dana untuk menggaji lagi" (GDD 3.0.C): saldo
## harus melewati batas 500 KR SEKALIGUS menutupi total gaji harian, sehingga
## karyawan tidak bolak-balik diliburkan di sekitar ambang.
func _update_solo_mode() -> void:
	if GameState.solo_mode:
		var salary: float = active_salary_total() + _benched_salary_total()
		if GameState.coins > GameConfig.SOLO_MODE_MAX_COINS and GameState.coins >= salary:
			_set_solo(false)
		return
	if GameState.coins <= GameConfig.SOLO_MODE_MAX_COINS:
		_set_solo(true)


## Menyalakan / mematikan Mode Solo. Penanda GameState.solo_mode diubah LEBIH DULU
## agar StaffSim (yang mendengarkan solo_mode_changed) melihat keadaan yang sudah
## benar saat meliburkan atau memanggil kembali karyawan.
func _set_solo(active: bool) -> void:
	if GameState.solo_mode == active:
		return
	GameState.solo_mode = active

	# Hari pertama Mode Solo menyala ditandai untuk Daily Summary (GDD 11.3).
	if active:
		GameState.stats["solo_first_day"] = true

	EventBus.solo_mode_changed.emit(active)

	# StaffSim adalah pemilik otomasi karyawan dan sudah mengurus dirinya sendiri
	# lewat sinyal di atas. Jalur cadangan di bawah hanya dipakai bila sistem itu
	# belum terpasang (mis. uji headless sebagian).
	if _system("staff") == null:
		if active:
			_bench_all_staff()
		else:
			_restore_staff()

	if active:
		AudioBus.sfx("door")
		EventBus.toast.emit(
			"Mode Solo menyala. Semua karyawan diliburkan sementara — kerja sendiri dulu, ya!",
			"chef"
		)
	else:
		AudioBus.sfx("ting")
		EventBus.toast.emit(
			"Kas sudah pulih. Karyawan dipanggil kembali bekerja!",
			"people"
		)


## Meliburkan seluruh karyawan yang masih bekerja dan mencatat siapa saja yang
## diliburkan oleh Mode Solo (bukan oleh pemain).
func _bench_all_staff() -> void:
	_benched_by_solo.clear()
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if bool(s.get("on_leave", false)):
			continue
		var sid: String = String(s.get("staff_id", ""))
		if sid.is_empty():
			continue
		if _set_leave(sid, true):
			_benched_by_solo.append(sid)


## Memanggil kembali karyawan yang tadi diliburkan Mode Solo. Bila catatan kosong
## (misalnya permainan baru dimuat dari berkas simpanan saat Mode Solo menyala),
## seluruh karyawan yang sedang libur dipanggil kembali, sesuai janji GDD 3.0.C
## bahwa "mereka akan kembali saat pemain punya cukup dana untuk menggaji lagi".
func _restore_staff() -> void:
	if _benched_by_solo.is_empty():
		for e: Variant in GameState.staff:
			var s: Dictionary = e
			if not bool(s.get("on_leave", false)):
				continue
			_set_leave(String(s.get("staff_id", "")), false)
		return

	for v: Variant in _benched_by_solo:
		_set_leave(String(v), false)
	_benched_by_solo.clear()


## Mengubah status libur satu karyawan. Bila StaffSim sudah terpasang, pekerjaan
## diserahkan kepadanya (ia pemilik otomasi karyawan); bila belum, status diubah
## langsung di GameState dan sinyalnya tetap di-emit agar UI ikut tersegarkan.
func _set_leave(staff_id: String, on_leave: bool) -> bool:
	if staff_id.is_empty():
		return false

	var staff_sim: Node = _system("staff")
	if staff_sim != null:
		for m: String in ["set_leave", "set_on_leave", "toggle_leave"]:
			if staff_sim.has_method(m):
				staff_sim.call(m, staff_id, on_leave)
				return true

	var changed: bool = false
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if String(s.get("staff_id", "")) != staff_id:
			continue
		if bool(s.get("on_leave", false)) == on_leave:
			return false
		s["on_leave"] = on_leave
		changed = true
		break
	if changed:
		EventBus.staff_leave_toggled.emit(staff_id, on_leave)
	return changed


## Total gaji karyawan yang sedang diliburkan — ikut dihitung saat menilai apakah
## pemain sudah sanggup memanggil semua orang kembali bekerja.
func _benched_salary_total() -> float:
	var total: float = 0.0
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if not bool(s.get("on_leave", false)):
			continue
		total += _salary_of(s)
	return total


## Gaji harian satu karyawan (GDD 3.1 / 3.2, lewat StaffDB).
func _salary_of(entry: Variant) -> float:
	if typeof(entry) != TYPE_DICTIONARY:
		return 0.0
	var s: Dictionary = entry
	var db: Dictionary = StaffDB.entry(String(s.get("staff_id", "")))
	if not db.is_empty():
		return float(db.get("salary", 0))
	return float(StaffDB.salary_for(String(s.get("role", "")), int(s.get("tier", 1))))


## Menyelaraskan penanda Mode Solo internal dengan isi GameState (setelah muat save).
func _sync_solo_from_state() -> void:
	_benched_by_solo.clear()
	if not GameState.solo_mode:
		return
	for e: Variant in GameState.staff:
		var s: Dictionary = e
		if bool(s.get("on_leave", false)):
			_benched_by_solo.append(String(s.get("staff_id", "")))


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
