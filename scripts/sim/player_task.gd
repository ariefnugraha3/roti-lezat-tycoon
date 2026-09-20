class_name PlayerTaskSystem
extends Node
## Alur produksi manual karakter pemain (GDD 2 "Tahap Persiapan").
##
## Ini lapisan yang menerjemahkan KETUKAN pemain di dunia 3D menjadi perintah ke
## ProductionSystem, dan sebaliknya menerjemahkan keadaan produksi menjadi
## penanda yang mengambang di atas perabot.
##
## Satu putaran penuh satu pesanan:
##   1. ketuk GUDANG      -> karakter ke gudang, pintunya terbuka, daftar resep muncul
##   2. pilih resep       -> daftar & pintu tertutup, tanda "!" muncul di MIXER
##   3. ketuk MIXER       -> karakter ke mixer, adonan mulai diaduk (bar progres)
##   4. aduk selesai      -> tanda "!" pindah ke OVEN
##   5. ketuk OVEN        -> karakter mampir ke mixer mengambil adonan, lalu ke oven
##   6. panggang selesai  -> tanda "!" pindah ke RAK
##   7. ketuk RAK         -> karakter mengambil loyang dari oven lalu ke rak,
##                           layar rak terbuka, pemain memilih petaknya
##
## PENTING: penandanya selalu di stasiun BERIKUTNYA, bukan di stasiun yang baru
## selesai. Pemain membaca "ke mana barang ini harus pergi", bukan "di mana ia
## sekarang" — dan itu yang membuat langkah terakhir (rak) sama bentuknya dengan
## langkah-langkah sebelumnya.
##
## Beberapa pesanan berjalan SEKALIGUS. Yang antre hanyalah kaki karakter: satu
## perjalanan diselesaikan dulu baru perjalanan berikutnya, sementara mixer dan
## oven terus berdetak sendiri. Jadi selagi roti dipanggang, pemain tetap bisa
## memilih resep baru dan mengaduk adonan berikutnya.

# --- Stasiun ---------------------------------------------------------------

const STATION_STORAGE: String = "storage"
const STATION_MIXER: String = "mixer"
const STATION_OVEN: String = "oven"
const STATION_DISPLAY: String = "display"
## Meja kasir. Bukan stasiun produksi: ia tidak pernah menjadi tahap sebuah
## pesanan, hanya tempat karakter berjaga melayani pembeli (GDD 3.0.C).
const STATION_CASHIER: String = "cashier"

## Perjalanan yang tidak membawa pekerjaan apa pun: pemain sekadar menyuruh
## karakternya berdiri di depan satu perabot. Dibedakan dari stasiun kerja agar
## penyelesaiannya tidak memicu langkah produksi apa pun.
const TASK_HAMPIRI: String = "hampiri"

## Jarak yang sudah dianggap "sudah berdiri di sana", meter.
const DEKAT: float = 0.35

# --- Keadaan satu pesanan --------------------------------------------------

## Menunggu diketuk pemain; tanda "!" tampil di stasiun tujuan.
const STATE_MENUNGGU: String = "menunggu"
## Karakter sedang berjalan ke stasiun tujuan.
const STATE_BERJALAN: String = "berjalan"
## Alat sedang bekerja; bar progres tampil di stasiun itu.
const STATE_BEKERJA: String = "bekerja"
## Karakter sudah tiba di rak; menunggu pemain memilih petak.
const STATE_MEMILIH: String = "memilih"
## Belum ada alat kosong untuk tahap berikutnya; tidak ada tanda apa pun.
const STATE_TERTAHAN: String = "tertahan"

# --- Sinyal ----------------------------------------------------------------

## Daftar pesanan berubah — UI penanda menyegarkan diri.
signal orders_changed()
## Karakter sudah sampai di gudang dan pintunya terbuka: tampilkan daftar resep.
signal storage_opened()
## Karakter sudah sampai di rak sambil membawa loyang: tampilkan pemilih petak.
signal rack_requested(order_id: int, rack_index: int)
## Karakter membuka/menutup pintu gudang. Dunia 3D memakai ini untuk animasinya.
signal storage_door(open: bool)

# --- Keadaan internal ------------------------------------------------------

var _main: Node = null
var _orders: Array = []
var _next_id: int = 1
var _hour: float = GameConfig.HOUR_START

## Perjalanan yang sedang dikerjakan karakter; {} berarti ia menganggur.
var _tugas: Dictionary = {}
## Sisa titik yang harus dilalui pada perjalanan ini.
var _kaki: Array = []
## Perjalanan yang menunggu giliran, urut ketukan pemain.
var _antrean: Array = []

var _actor: PlayerActor = null


# ===========================================================================
# Antarmuka tick (ARCHITECTURE 7.0)
# ===========================================================================

func setup(main: Node) -> void:
	_main = main
	_hour = GameConfig.HOUR_START


func reset() -> void:
	_orders.clear()
	_tugas = {}
	_kaki.clear()
	_antrean.clear()
	_next_id = 1
	_hour = GameConfig.HOUR_START
	var a: PlayerActor = actor()
	if a != null:
		a.set_carry(PlayerActor.CARRY_NONE)
		a.set_working(false)
		a.clear_path()
	orders_changed.emit()


func on_day_start(_day: int) -> void:
	_hour = GameConfig.HOUR_START


func on_day_end(_ledger: Dictionary) -> void:
	# Toko tutup: ProductionSystem.collect_all() sudah menyapu loyang yang matang,
	# jadi pesanan yang masih menggantung tidak punya job lagi untuk diikuti.
	_sapu_pesanan_mati()


func sim_tick(delta: float, hour: float) -> void:
	_hour = hour
	if delta <= 0.0:
		return
	_sapu_pesanan_mati()
	_maju_tahap()


# ===========================================================================
# KETUKAN PEMAIN
# ===========================================================================

## Pemain mengetuk satu perabot. Mengembalikan true bila ketukan itu berarti
## sesuatu — pemanggil memakainya untuk memutuskan perlu berbunyi atau tidak.
##
## Ketukan pada perabot yang TIDAK sedang menunggu pekerjaan tetap dilayani:
## karakter berjalan menghampirinya dan berdiri di situ. Perabot di dunia 3D
## adalah tombolnya sendiri, dan tombol yang kadang menjawab kadang tidak
## membuat pemain mengira ketukannya tidak terbaca.
func tap(kind: String, index: int) -> bool:
	if kind == STATION_STORAGE:
		return _tap_gudang(index)
	var pesanan: Dictionary = _pesanan_menunggu(kind, index)
	if pesanan.is_empty():
		return _hampiri(kind, index)
	pesanan["state"] = STATE_BERJALAN
	_antre(_rencana(pesanan))
	orders_changed.emit()
	return true


## Menyuruh karakter berdiri di depan satu perabot, tanpa pekerjaan apa pun.
##
## Kunjungan yang belum selesai DIGANTI oleh ketukan terbaru, bukan diantrekan
## di belakangnya: pemain yang mengetuk oven lalu rak menginginkan karakternya
## di rak, bukan berkeliling menengok keduanya. Tugas KERJA tidak pernah ikut
## dibatalkan — hanya kunjungan kosong yang boleh dibatalkan begitu saja.
func _hampiri(kind: String, index: int) -> bool:
	if not _stasiun_ada(kind, index):
		return false

	for i: int in range(_antrean.size() - 1, -1, -1):
		if String((_antrean[i] as Dictionary).get("jenis", "")) == TASK_HAMPIRI:
			_antrean.remove_at(i)

	var sedang_berkunjung: bool = String(_tugas.get("jenis", "")) == TASK_HAMPIRI
	if not sedang_berkunjung and _tugas.is_empty() and _sudah_di(kind, index):
		return false
	if sedang_berkunjung:
		_tugas = {}
		_kaki.clear()

	_antre({
		"jenis": TASK_HAMPIRI,
		"order_id": -1,
		"kaki": [{"di": kind, "i": index, "bawa": ""}],
	})
	return true


## Apakah perabot itu memang terpasang di dunia.
func _stasiun_ada(kind: String, index: int) -> bool:
	var w: ShopWorld = world()
	if w == null:
		return index >= 0
	return index >= 0 and index < w.station_points(kind).size()


## Apakah karakter sudah berdiri di depan perabot itu.
func _sudah_di(kind: String, index: int) -> bool:
	var a: PlayerActor = actor()
	if a == null or not a.is_inside_tree():
		return false
	return a.global_position.distance_to(_titik_berdiri(kind, index)) < DEKAT


func _tap_gudang(index: int) -> bool:
	# Dua ketukan gudang berturut-turut tidak menumpuk dua perjalanan.
	if _sedang_ke_gudang():
		return false
	_antre({"jenis": STATION_STORAGE, "order_id": -1, "index": index})
	return true


## Pemain menutup daftar resep tanpa memilih apa pun.
func cancel_storage() -> void:
	storage_door.emit(false)
	_lepas_karakter()


## Pemain memilih satu resep dari daftar di gudang.
##
## Mengembalikan false bila pesanan tidak bisa diterima (bahan kurang, mixer
## penuh, resep belum memenuhi syarat alat) — daftar tetap terbuka supaya pemain
## bisa memilih yang lain.
func choose_recipe(recipe_id: String, batches: int) -> bool:
	var prod: ProductionSystem = production()
	if prod == null or not prod.can_queue(recipe_id, batches):
		return false

	var slot: int = _slot_mixer_bebas()
	if slot < 0:
		return false

	_orders.append({
		"id": _next_id,
		"recipe_id": recipe_id,
		"batches": batches,
		"job_id": 0,
		"station": STATION_MIXER,
		"index": slot,
		"state": STATE_MENUNGGU,
	})
	_next_id += 1

	storage_door.emit(false)
	_lepas_karakter()
	AudioBus.sfx("paper")
	EventBus.toast.emit("%s: ketuk Mixer untuk mulai mengaduk."
		% _nama_resep(recipe_id), "chef")
	orders_changed.emit()
	return true


## Pemain menaruh roti satu pesanan ke satu petak rak.
## Mengembalikan jumlah roti yang benar-benar masuk (0 = petak itu tidak muat).
func place_bread(order_id: int, global_slot: int) -> int:
	var pesanan: Dictionary = _pesanan(order_id)
	if pesanan.is_empty() or String(pesanan.get("state", "")) != STATE_MEMILIH:
		return 0
	var prod: ProductionSystem = production()
	if prod == null:
		return 0

	var masuk: int = prod.collect_to_slot(int(pesanan.get("job_id", 0)), global_slot)
	if masuk <= 0:
		return 0

	# Loyang bisa berisi lebih banyak roti daripada daya tampung satu petak;
	# selama masih ada sisa, pemain tetap berdiri di rak dan memilih petak lagi.
	if not prod.job(int(pesanan.get("job_id", 0))).is_empty():
		orders_changed.emit()
		return masuk

	_selesaikan(pesanan)
	return masuk


## Pemain menutup layar rak sebelum seluruh loyang tertata.
## Pesanan dikembalikan ke keadaan menunggu supaya rak bisa diketuk lagi nanti.
func cancel_rack(order_id: int) -> void:
	var pesanan: Dictionary = _pesanan(order_id)
	if pesanan.is_empty() or String(pesanan.get("state", "")) != STATE_MEMILIH:
		return
	pesanan["state"] = STATE_MENUNGGU
	_lepas_karakter()
	orders_changed.emit()


# ===========================================================================
# BACAAN UNTUK UI & DUNIA 3D
# ===========================================================================

## Salinan seluruh pesanan yang sedang berjalan.
func orders() -> Array:
	return _orders.duplicate(true)


func order_count() -> int:
	return _orders.size()


## Satu pesanan menurut id; {} bila tidak ada.
func order(order_id: int) -> Dictionary:
	return _pesanan(order_id).duplicate(true)


## Penanda yang harus tampil di dunia 3D, dipetakan "jenis:indeks" ->
## {"mode": "alert" | "progress", "value": float}.
##
## Dunia 3D tidak pernah menghitung sendiri kapan sebuah tanda seru muncul; ia
## hanya menggambar apa yang dilaporkan fungsi ini. Satu sumber kebenaran.
func markers() -> Dictionary:
	var out: Dictionary = {}
	var prod: ProductionSystem = production()
	for e: Variant in _orders:
		var o: Dictionary = e
		var kunci: String = "%s:%d" % [String(o.get("station", "")), int(o.get("index", -1))]
		if int(o.get("index", -1)) < 0:
			continue
		match String(o.get("state", "")):
			STATE_MENUNGGU:
				out[kunci] = {"mode": StationMarker.MODE_ALERT, "value": 0.0}
			STATE_BEKERJA:
				var nilai: float = 0.0
				if prod != null:
					nilai = prod.progress(int(o.get("job_id", 0)))
				# Bar progres tidak pernah menimpa tanda seru di ubin yang sama:
				# tanda seru adalah perintah, bar hanya kabar.
				if not out.has(kunci):
					out[kunci] = {"mode": StationMarker.MODE_PROGRESS, "value": nilai}
	return out


## Apakah karakter sedang mengerjakan atau menunggu satu perjalanan.
func is_busy() -> bool:
	return not _tugas.is_empty() or not _antrean.is_empty()


## Mesin kasir yang sedang DIJAGA karakter pemain; -1 bila ia tidak berjaga.
##
## Keadaan ini sengaja DITURUNKAN dari posisi karakter, bukan disimpan sebagai
## penanda tersendiri: penanda harus dibersihkan di setiap jalur yang menyuruh
## karakter pergi, dan satu jalur yang terlupa berarti pemain terus "melayani"
## dari seberang dapur. Berdiri di sana berarti melayani; melangkah pergi
## berarti berhenti melayani, tanpa satu baris pun kode pembersih.
func manning_lane() -> int:
	if is_busy():
		return -1
	var a: PlayerActor = actor()
	var w: ShopWorld = world()
	if a == null or w == null or not a.is_inside_tree():
		return -1
	for i in w.cashier_pos.size():
		if a.global_position.distance_to(w.cashier_stand_spot(i)) < DEKAT:
			return i
	return -1


# ===========================================================================
# PERJALANAN KARAKTER
# ===========================================================================

## Menyusun rencana perjalanan untuk satu pesanan yang baru diketuk.
##
## Setiap tahap selain yang pertama punya DUA kaki: mampir ke alat sebelumnya
## untuk mengambil barangnya, lalu mengantarnya ke alat berikutnya. Itulah
## sebabnya karakter terlihat membawa mangkuk adonan atau loyang roti — bawaan
## itu bukan hiasan, ia menandai kaki mana yang sedang ditempuh.
func _rencana(pesanan: Dictionary) -> Dictionary:
	var station: String = String(pesanan.get("station", ""))
	var kaki: Array = []
	var prod: ProductionSystem = production()
	var job: Dictionary = {}
	if prod != null:
		job = prod.job(int(pesanan.get("job_id", 0)))

	match station:
		STATION_MIXER:
			kaki.append({"di": STATION_MIXER, "i": int(pesanan.get("index", 0)), "bawa": ""})
		STATION_OVEN:
			kaki.append({"di": STATION_MIXER, "i": int(job.get("slot_index", 0)),
				"bawa": PlayerActor.CARRY_DOUGH})
			kaki.append({"di": STATION_OVEN, "i": int(pesanan.get("index", 0)), "bawa": ""})
		STATION_DISPLAY:
			kaki.append({"di": STATION_OVEN, "i": int(job.get("slot_index", 0)),
				"bawa": PlayerActor.CARRY_TRAY})
			kaki.append({"di": STATION_DISPLAY, "i": int(pesanan.get("index", 0)), "bawa": ""})
	return {"jenis": station, "order_id": int(pesanan.get("id", -1)), "kaki": kaki}


func _antre(tugas: Dictionary) -> void:
	_antrean.append(tugas)
	if _tugas.is_empty():
		_mulai_tugas_berikutnya()


func _mulai_tugas_berikutnya() -> void:
	_tugas = {}
	_kaki.clear()
	if _antrean.is_empty():
		# Karakter DIBIARKAN berdiri di tempat ia terakhir bekerja, tidak
		# dipulangkan ke lorong. Mesin berjalan sendiri setelah dinyalakan, jadi
		# perjalanan pulang itu murni langkah kosong — dan di dapur sempit Tier 1
		# ia justru terlihat mondar-mandir tanpa sebab.
		var a0: PlayerActor = actor()
		if a0 != null:
			a0.set_working(false)
		return

	_tugas = _antrean.pop_front()
	_kaki = (_tugas.get("kaki", []) as Array).duplicate()
	var a: PlayerActor = actor()
	if a == null:
		# Tanpa aktor (mis. uji headless tanpa dunia), seluruh kaki dianggap
		# langsung ditempuh. Logika tahapnya tetap diuji utuh.
		while not _kaki.is_empty():
			_kaki.pop_front()
		_tugas_selesai()
		return

	a.set_working(false)
	a.clear_path()
	if String(_tugas.get("jenis", "")) == STATION_STORAGE:
		a.goto(_titik_berdiri(STATION_STORAGE, int(_tugas.get("index", 0))), "tugas")
		return
	_langkah_berikutnya()


func _langkah_berikutnya() -> void:
	var a: PlayerActor = actor()
	if a == null:
		_tugas_selesai()
		return
	if _kaki.is_empty():
		_tugas_selesai()
		return
	var kaki: Dictionary = _kaki[0]
	a.goto(_titik_berdiri(String(kaki.get("di", "")), int(kaki.get("i", 0))), "tugas")


## Dipanggil ShopWorld saat karakter sampai di satu tujuan.
func on_actor_arrived(tag: String) -> void:
	if tag != "tugas" or _tugas.is_empty():
		return
	if String(_tugas.get("jenis", "")) == STATION_STORAGE:
		_tugas_selesai()
		return
	if _kaki.is_empty():
		_tugas_selesai()
		return

	var kaki: Dictionary = _kaki.pop_front()
	var a: PlayerActor = actor()
	# Menghadap perabot yang baru dihampiri. Tanpa ini karakter berhenti dengan
	# arah hadap sisa perjalanannya dan terlihat membelakangi alat yang sedang
	# ia operasikan -- dan di meja kasir, membelakangi pembelinya.
	if a != null:
		a.face_towards(_titik(String(kaki.get("di", "")), int(kaki.get("i", 0))))
	var bawa: String = String(kaki.get("bawa", ""))
	if a != null and bawa != "":
		a.set_carry(bawa)
	if _kaki.is_empty():
		_tugas_selesai()
		return
	_langkah_berikutnya()


# Perjalanan tuntas: jalankan akibatnya, lalu ambil perjalanan berikutnya.
func _tugas_selesai() -> void:
	var jenis: String = String(_tugas.get("jenis", ""))
	var order_id: int = int(_tugas.get("order_id", -1))
	_tugas = {}
	_kaki.clear()

	match jenis:
		STATION_STORAGE:
			storage_door.emit(true)
			storage_opened.emit()
			# Karakter berdiri menunggu di depan gudang selama daftar terbuka.
			return
		STATION_MIXER:
			_mulai_aduk(order_id)
		STATION_OVEN:
			_mulai_panggang(order_id)
		STATION_DISPLAY:
			# Karakter BERDIRI DI RAK selama pemain memilih petak; antrean baru
			# dilanjutkan setelah layar rak ditutup (place_bread / cancel_rack).
			_buka_rak(order_id)
			return

	_mulai_tugas_berikutnya()


func _mulai_aduk(order_id: int) -> void:
	var pesanan: Dictionary = _pesanan(order_id)
	var prod: ProductionSystem = production()
	if pesanan.is_empty() or prod == null:
		return
	var jid: int = prod.queue_manual(
		String(pesanan.get("recipe_id", "")),
		int(pesanan.get("batches", 1)),
		int(pesanan.get("index", 0)))
	if jid <= 0:
		# Bahan keburu habis atau mixer keburu dipakai: pesanan dibatalkan, bukan
		# dibiarkan menggantung tanpa job yang bisa diikuti.
		EventBus.toast.emit("%s batal: bahan atau mixer tidak tersedia."
			% _nama_resep(String(pesanan.get("recipe_id", ""))), "warning")
		_buang(pesanan)
		orders_changed.emit()
		return
	pesanan["job_id"] = jid
	pesanan["state"] = STATE_BEKERJA
	var a: PlayerActor = actor()
	if a != null:
		a.set_working(true)
	orders_changed.emit()


func _mulai_panggang(order_id: int) -> void:
	var pesanan: Dictionary = _pesanan(order_id)
	var prod: ProductionSystem = production()
	if pesanan.is_empty() or prod == null:
		return
	var slot: int = prod.move_to_oven(
		int(pesanan.get("job_id", 0)), int(pesanan.get("index", -1)))
	var a: PlayerActor = actor()
	if a != null:
		a.set_carry(PlayerActor.CARRY_NONE)
	if slot < 0:
		# Oven keburu dipakai orang lain: kembalikan tanda serunya.
		pesanan["state"] = STATE_MENUNGGU
		orders_changed.emit()
		return
	pesanan["index"] = slot
	pesanan["state"] = STATE_BEKERJA
	if a != null:
		a.set_working(true)
	orders_changed.emit()


func _buka_rak(order_id: int) -> void:
	var pesanan: Dictionary = _pesanan(order_id)
	if pesanan.is_empty():
		return
	pesanan["state"] = STATE_MEMILIH
	orders_changed.emit()
	rack_requested.emit(order_id, int(pesanan.get("index", 0)))


# ===========================================================================
# KEMAJUAN TAHAP
# ===========================================================================

# Memindahkan tanda seru ke stasiun berikutnya begitu satu tahap rampung.
func _maju_tahap() -> void:
	var prod: ProductionSystem = production()
	if prod == null:
		return
	for e: Variant in _orders.duplicate():
		var o: Dictionary = e
		var state: String = String(o.get("state", ""))
		if state != STATE_BEKERJA and state != STATE_TERTAHAN:
			continue
		var jid: int = int(o.get("job_id", 0))
		if jid <= 0:
			continue

		if String(o.get("station", "")) == STATION_MIXER and prod.mixing_done(jid):
			_pindah_ke(o, STATION_OVEN, _slot_oven_bebas())
		elif String(o.get("station", "")) == STATION_OVEN and prod.baking_done(jid):
			_pindah_ke(o, STATION_DISPLAY, _rak_tujuan(o))


# Menetapkan stasiun berikutnya. Indeks -1 berarti belum ada alat kosong:
# pesanan menunggu tanpa tanda seru, dan dicoba lagi tick berikutnya.
func _pindah_ke(o: Dictionary, station: String, index: int) -> void:
	var sebelumnya: String = String(o.get("state", ""))
	o["station"] = station
	o["index"] = index
	o["state"] = STATE_TERTAHAN if index < 0 else STATE_MENUNGGU
	if index < 0 or sebelumnya == STATE_MENUNGGU:
		return

	var a: PlayerActor = actor()
	if a != null and not is_busy():
		a.set_working(false)
	if station == STATION_OVEN:
		EventBus.toast.emit("%s selesai diaduk — ketuk Oven."
			% _nama_resep(String(o.get("recipe_id", ""))), "bread")
	else:
		EventBus.toast.emit("%s matang — ketuk Rak Display."
			% _nama_resep(String(o.get("recipe_id", ""))), "bread")
	orders_changed.emit()


# Membuang pesanan yang job-nya sudah lenyap (gosong, dibatalkan, atau diangkat
# asisten dapur lebih dulu). Tanpa ini tanda seru akan menggantung selamanya.
func _sapu_pesanan_mati() -> void:
	var prod: ProductionSystem = production()
	if prod == null:
		return
	var berubah: bool = false
	for e: Variant in _orders.duplicate():
		var o: Dictionary = e
		var jid: int = int(o.get("job_id", 0))
		if jid <= 0:
			continue
		if not prod.job(jid).is_empty():
			continue
		_buang(o)
		berubah = true
	if berubah:
		orders_changed.emit()


# ===========================================================================
# Pembantu internal
# ===========================================================================

func _pesanan(order_id: int) -> Dictionary:
	for e: Variant in _orders:
		var o: Dictionary = e
		if int(o.get("id", -1)) == order_id:
			return o
	return {}


func _pesanan_menunggu(kind: String, index: int) -> Dictionary:
	for e: Variant in _orders:
		var o: Dictionary = e
		if String(o.get("state", "")) != STATE_MENUNGGU:
			continue
		if String(o.get("station", "")) != kind:
			continue
		if int(o.get("index", -1)) == index:
			return o
	return {}


func _selesaikan(pesanan: Dictionary) -> void:
	_buang(pesanan)
	_lepas_karakter()
	AudioBus.sfx("ting")
	orders_changed.emit()


func _buang(pesanan: Dictionary) -> void:
	var oid: int = int(pesanan.get("id", -1))
	for i: int in range(_orders.size() - 1, -1, -1):
		var cur: Dictionary = _orders[i]
		if int(cur.get("id", -2)) == oid:
			_orders.remove_at(i)
	# Perjalanan yang masih mengantre untuk pesanan ini ikut dibatalkan.
	for i2: int in range(_antrean.size() - 1, -1, -1):
		var t: Dictionary = _antrean[i2]
		if int(t.get("order_id", -2)) == oid:
			_antrean.remove_at(i2)


# Melepaskan karakter dari tempatnya berdiri sekarang dan melanjutkan antrean.
func _lepas_karakter() -> void:
	var a: PlayerActor = actor()
	if a != null:
		a.set_carry(PlayerActor.CARRY_NONE)
		a.set_working(false)
	_mulai_tugas_berikutnya()


func _sedang_ke_gudang() -> bool:
	if String(_tugas.get("jenis", "")) == STATION_STORAGE:
		return true
	for e: Variant in _antrean:
		if String((e as Dictionary).get("jenis", "")) == STATION_STORAGE:
			return true
	return false


# Slot mixer kosong yang BELUM dijanjikan ke pesanan lain. Tanpa penyaringan
# ini, dua resep yang dipilih berturut-turut akan menaruh tanda serunya di
# mixer yang sama.
func _slot_mixer_bebas() -> int:
	var prod: ProductionSystem = production()
	if prod == null:
		return -1
	var dipesan: Dictionary = _terpesan(STATION_MIXER)
	for i: int in range(prod.mixer_slot_count()):
		if dipesan.has(i):
			continue
		if prod.job_at_slot(ProductionSystem.KIND_MIXER, i).is_empty():
			return i
	return -1


func _slot_oven_bebas() -> int:
	var prod: ProductionSystem = production()
	if prod == null:
		return -1
	var dipesan: Dictionary = _terpesan(STATION_OVEN)
	for i: int in range(prod.oven_slot_count()):
		if dipesan.has(i):
			continue
		if prod.job_at_slot(ProductionSystem.KIND_OVEN, i).is_empty():
			return i
	return -1


# Indeks stasiun yang sudah dijanjikan ke pesanan yang belum berjalan.
func _terpesan(station: String) -> Dictionary:
	var out: Dictionary = {}
	for e: Variant in _orders:
		var o: Dictionary = e
		if String(o.get("station", "")) != station:
			continue
		var st: String = String(o.get("state", ""))
		if st != STATE_MENUNGGU and st != STATE_BERJALAN:
			continue
		out[int(o.get("index", -1))] = true
	return out


# Rak yang masih punya ruang untuk roti pesanan ini; 0 sebagai jalan terakhir
# supaya tanda serunya tetap muncul walau seluruh rak penuh — pemain berhak
# melihat bahwa rotinya sudah matang dan raknya yang bermasalah.
func _rak_tujuan(o: Dictionary) -> int:
	var rak: int = LocationDB.rack_slots(GameState.location_tier)
	if rak <= 0:
		return 0
	var rid: String = String(o.get("recipe_id", ""))
	var prod: ProductionSystem = production()
	var quality: String = ProductionSystem.QUALITY_PRIME
	if prod != null:
		var j: Dictionary = prod.job(int(o.get("job_id", 0)))
		if not j.is_empty():
			quality = String(j.get("quality", quality))
	for r: int in range(rak):
		for s: int in range(GameConfig.SLOTS_PER_RACK):
			var gi: int = r * GameConfig.SLOTS_PER_RACK + s
			if GameState.display_room_at(gi, rid, quality) > 0:
				return r
	return 0


## Titik tempat karakter berdiri untuk mengoperasikan satu perabot.
##
## Ditanyakan ke dunia, bukan dihitung sendiri: hanya dunia yang tahu petak mana
## yang terhalang perabot lain atau meja kasir.
func _titik_berdiri(kind: String, index: int) -> Vector3:
	var w: ShopWorld = world()
	if w == null:
		return _titik(kind, index)
	var a: PlayerActor = actor()
	var dari: Vector3 = Vector3.ZERO
	if a != null and a.is_inside_tree():
		dari = a.global_position
	return w.stand_spot(kind, index, dari)


func _titik(kind: String, index: int) -> Vector3:
	var w: ShopWorld = world()
	if w == null:
		return Vector3.ZERO
	var daftar: Array[Vector3] = w.station_points(kind)
	if daftar.is_empty():
		return Vector3.ZERO
	return daftar[clampi(index, 0, daftar.size() - 1)]


func _nama_resep(recipe_id: String) -> String:
	var rec: Dictionary = RecipeDB.entry(recipe_id)
	return String(rec.get("name", recipe_id)) if not rec.is_empty() else recipe_id


# --- Rujukan ke sistem lain ------------------------------------------------

func production() -> ProductionSystem:
	if _main == null or not is_instance_valid(_main):
		return null
	var sys: Variant = _main.get("systems")
	if not (sys is Dictionary):
		return null
	return (sys as Dictionary).get("prod") as ProductionSystem


func world() -> ShopWorld:
	if _main == null or not is_instance_valid(_main):
		return null
	return _main.get("world") as ShopWorld


func actor() -> PlayerActor:
	if _actor != null and is_instance_valid(_actor):
		return _actor
	var w: ShopWorld = world()
	if w == null:
		return null
	_actor = w.player_actor()
	return _actor
