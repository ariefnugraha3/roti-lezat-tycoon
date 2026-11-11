extends Node
## Monetization — iklan berhadiah dan toko (GDD idle 22). Layanan tanpa state
## gameplay: hak beli (No Ads, Golden Oven, Night Manager, paket penawaran),
## langganan Baker's Club, jam penawaran, dan jatah iklan harian milik
## perangkat, disimpan di `user://monetization.json`, bukan di profil. Isi yang
## masuk save (Golden Crumbs, isi paket, Pass premium) diberikan GameRoot
## lewat sinyal `purchased` (PremiumManager.deliver), dan hak beli disalin ke
## simulasi lewat `perks()`.
##
## Satu penyedia per platform (MonetizationProvider): portal CrazyGames/Poki
## lewat fitur ekspor, toko uji (DummyMonetizationProvider) di semua build lain
## selama `monetization.dummy_store` menyala (sebelum plugin Play Billing dan
## AdMob dipasang), dan penyedia palsu di tes. Selama iklan, toko di-pause
## (PauseManager alasan `ad`) dan suara dibisukan; hadiah hanya bila iklan
## selesai ditonton, dan jatah harian hanya berkurang saat hadiah diberikan.

signal changed()
## Produk dibeli atau dipulihkan; isinya perlu masuk save yang sedang dimainkan.
signal purchased(product: StringName)
## Hadiah iklan diberikan (XP Bakery Pass, GDD idle 22.7).
signal ad_watched(placement: StringName)
## Toko uji: tampilkan iklan tiruan atau konfirmasi pembelian tiruan. Tanpa
## pendengar keduanya langsung berhasil.
signal dummy_ad_requested(done: Callable)
signal dummy_purchase_requested(product: StringName, done: Callable)

const VERSION: int = 2
const PAUSE_REASON: StringName = &"ad"
## Jenis produk yang menjadi hak beli tetap perangkat.
const OWNED_KINDS: Array[String] = ["no_ads", "income", "offline", "offer"]

## Berkas perangkat; tes mengarahkannya ke berkas sendiri.
var path: String = "user://monetization.json"
var provider: MonetizationProvider = null
## Iklan sedang tayang.
var busy: bool = false
## Hak beli tetap perangkat ini (id produk).
var owned: Array[String] = []
## Baker's Club aktif sampai jam unix ini.
var club_until: float = 0.0
## Penawaran yang sudah dimulai: id -> jam unix mulai; popup yang sudah tampil.
var offers: Dictionary = {}
var offers_shown: Dictionary = {}
## Tes: jam unix palsu (< 0 = jam sistem).
var now_override: float = -1.0
## Supporter = pemilik No Ads (nama lama Supporter Pack, GDD idle 22.5).
var supporter: bool:
	get:
		return owns(supporter_product())
var _day: String = ""
var _used: Dictionary = {}
var _loading_done: bool = false
var _sent_loading: bool = false
var _gameplay: bool = false
var _sent_gameplay: bool = false
var _club_was: bool = false
var _club_check: float = 0.0


func _ready() -> void:
	load_state()
	use_provider(_platform_provider())


## Penyedia platform ini (GDD idle 22.2).
static func _platform_provider() -> MonetizationProvider:
	if OS.has_feature("web") and OS.has_feature("crazygames"):
		return PortalMonetizationProvider.new(&"crazygames")
	if OS.has_feature("web") and OS.has_feature("poki"):
		return PortalMonetizationProvider.new(&"poki")
	if bool(DataRegistry.idle("monetization.dummy_store")):
		return DummyMonetizationProvider.new()
	return MonetizationProvider.new()


## Ganti penyedia (tes).
func use_provider(p: MonetizationProvider) -> void:
	provider = p
	busy = false
	_sent_loading = false
	_sent_gameplay = false
	provider.setup()
	changed.emit()


func _process(delta: float) -> void:
	if provider == null:
		return
	provider.poll()
	if provider.connected():
		if _loading_done and not _sent_loading:
			_sent_loading = true
			provider.lifecycle(&"loading_finished")
		if _gameplay != _sent_gameplay:
			_sent_gameplay = _gameplay
			provider.lifecycle(&"gameplay_start" if _gameplay else &"gameplay_stop")
	# Langganan berakhir di tengah permainan: hak belinya ikut berubah.
	_club_check -= delta
	if _club_check <= 0.0:
		_club_check = 1.0
		var on: bool = club_active()
		if on != _club_was:
			_club_was = on
			changed.emit()


func now_unix() -> float:
	return now_override if now_override >= 0.0 else Time.get_unix_time_from_system()


# ===========================================================================
# SIKLUS HIDUP PORTAL
# ===========================================================================

## Game selesai dimuat (pemain mengetuk Tap to Start).
func loading_finished() -> void:
	_loading_done = true


## Pemain sedang bermain (toko berjalan, tanpa pause) atau tidak. Dikirim ke
## portal hanya saat berubah.
func set_gameplay(active: bool) -> void:
	_gameplay = active and not busy


# ===========================================================================
# IKLAN BERHADIAH (GDD idle 22.4)
# ===========================================================================

static func placement(id: StringName) -> Dictionary:
	var all: Variant = DataRegistry.idle("monetization.placements")
	if all is Dictionary and (all as Dictionary).has(String(id)):
		return (all as Dictionary)[String(id)]
	return {}


## Sisa jatah hari ini untuk penempatan `id`.
func left_today(id: StringName) -> int:
	var p: Dictionary = placement(id)
	if p.is_empty():
		return 0
	_roll_day()
	return maxi(0, int(p.get("per_day", 0)) - int(_used.get(String(id), 0)))


## Tombol hadiah `id` boleh ditampilkan sekarang: ada jatah, tidak ada iklan
## yang sedang tayang, dan iklan siap (atau hadiahnya gratis tanpa iklan).
func can_offer(id: StringName) -> bool:
	if busy or left_today(id) <= 0:
		return false
	return ads_free() or (provider != null and provider.ads_ready())


## Hadiah iklan diberikan tanpa iklan: No Ads atau Baker's Club (GDD idle 22.5).
func ads_free() -> bool:
	return supporter or club_active()


func is_free(_id: StringName = &"") -> bool:
	return ads_free()


## Tampilkan iklan untuk hadiah `id`, lalu `done(success)`. Tanpa iklan (No
## Ads, Club) langsung berhasil. Hadiahnya sendiri diberikan oleh pemanggil saat
## success.
func show_rewarded(id: StringName, done: Callable) -> void:
	if not can_offer(id):
		done.call(false)
		return
	if ads_free():
		_use(id)
		ad_watched.emit(id)
		done.call(true)
		return
	busy = true
	_gameplay = false
	PauseManager.push(PAUSE_REASON)
	AudioManager.set_ad_muted(true)
	changed.emit()
	provider.show_rewarded(func(ok: bool) -> void:
		busy = false
		PauseManager.pop(PAUSE_REASON)
		AudioManager.set_ad_muted(false)
		if ok:
			_use(id)
		GameLogger.info("UI", "rewarded ad %s: %s" % [id, "watched" if ok else "not completed"])
		changed.emit()
		if ok:
			ad_watched.emit(id)
		done.call(ok))


func _use(id: StringName) -> void:
	_roll_day()
	_used[String(id)] = int(_used.get(String(id), 0)) + 1
	save_state()


func _roll_day() -> void:
	var today: String = BoostManager.today()
	if today != _day:
		_day = today
		_used.clear()


# ===========================================================================
# TOKO (GDD idle 22.5)
# ===========================================================================

static func products(kind: String = "") -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for x: Variant in DataRegistry.idle("monetization.products"):
		if kind == "" or str((x as Dictionary)["kind"]) == kind:
			out.append(x)
	return out


static func product(id: StringName) -> Dictionary:
	return PremiumManager.product(id)


## Id produk satu-satunya dari jenis `kind` (no_ads, income, offline, club, pass).
static func product_id(kind: String) -> StringName:
	var p: Dictionary = PremiumManager.product_of_kind(kind)
	return StringName(str(p.get("id", "")))


static func supporter_product() -> StringName:
	return StringName(str(DataRegistry.idle("monetization.supporter_product")))


## Id produk lama (Supporter Pack) diganti id sekarang.
static func canonical(id: StringName) -> StringName:
	var legacy: Variant = DataRegistry.idle("monetization.legacy_products")
	if legacy is Dictionary and (legacy as Dictionary).has(String(id)):
		return StringName(str((legacy as Dictionary)[String(id)]))
	return id


func store_available() -> bool:
	return provider != null and provider.store_ready()


func price(id: StringName) -> String:
	return provider.product_price(id) if provider != null else ""


func owns(id: StringName) -> bool:
	return owned.has(String(canonical(id)))


func club_active() -> bool:
	return now_unix() < club_until


## Detik Baker's Club yang tersisa (0 = tidak aktif).
func club_left() -> float:
	return maxf(0.0, club_until - now_unix())


## Produk `id` boleh dibeli sekarang: hak beli tetap belum dimiliki, dan
## penawaran masih berjalan. Golden Crumbs, Club (diperpanjang), dan Pass
## (dicek di save) selalu boleh.
func can_buy(id: StringName) -> bool:
	var p: Dictionary = product(id)
	if p.is_empty():
		return false
	var kind: String = str(p["kind"])
	if OWNED_KINDS.has(kind) and owns(id):
		return false
	if kind == "offer" and offer_left(id) <= 0.0:
		return false
	return true


## Beli produk `id`; `done(success)` dipanggil tepat sekali.
func buy(id: StringName, done: Callable) -> void:
	if not store_available() or not can_buy(id):
		done.call(false)
		return
	provider.buy(id, func(ok: bool) -> void:
		if ok:
			_on_bought(id)
		done.call(ok))


func _on_bought(id: StringName) -> void:
	var p: Dictionary = product(id)
	var kind: String = str(p.get("kind", ""))
	if OWNED_KINDS.has(kind) and not owned.has(String(id)):
		owned.append(String(id))
	if kind == "club":
		club_until = maxf(now_unix(), club_until) + float(p.get("days", 30)) * 86400.0
	save_state()
	GameLogger.important("UI", "purchased %s" % id)
	_club_was = club_active()
	changed.emit()
	purchased.emit(id)


## Pulihkan hak beli dari toko; `done(any)` dengan true bila ada yang dimiliki.
## Isi paket yang dipulihkan masuk ke save ini bila belum pernah (PremiumManager).
func restore_purchases(done: Callable) -> void:
	if not store_available():
		done.call(not owned.is_empty())
		return
	provider.restore_purchases(func(list: Array) -> void:
		var any: bool = false
		for x: Variant in list:
			var pid: StringName = canonical(StringName(str(x)))
			var p: Dictionary = product(pid)
			if p.is_empty() or not OWNED_KINDS.has(str(p["kind"])):
				continue
			any = true
			if not owned.has(String(pid)):
				owned.append(String(pid))
			purchased.emit(pid)
		save_state()
		changed.emit()
		done.call(any or not owned.is_empty()))


## Hak beli untuk simulasi (PremiumManager.set_perks).
func perks() -> Dictionary:
	var mult: float = 1.0
	var hours: float = 0.0
	var full: bool = false
	var inc: Dictionary = PremiumManager.product_of_kind("income")
	if owns(StringName(str(inc.get("id", "")))):
		mult *= float(inc.get("income_mult", 1.0))
	var off: Dictionary = PremiumManager.product_of_kind("offline")
	if owns(StringName(str(off.get("id", "")))):
		hours += float(off.get("offline_hours", 0.0))
		full = bool(off.get("offline_full", false))
	var club: bool = club_active()
	if club:
		var c: Dictionary = PremiumManager.product_of_kind("club")
		mult *= float(c.get("income_mult", 1.0))
		hours += float(c.get("offline_hours", 0.0))
	return {"income_mult": mult, "offline_hours": hours, "offline_full": full, "club": club}


# ===========================================================================
# PENAWARAN BERBATAS WAKTU (GDD idle 22.9)
# ===========================================================================

static func offer_rule(id: StringName) -> Dictionary:
	var all: Variant = DataRegistry.idle("monetization.offers")
	return (all as Dictionary).get(String(id), {}) if all is Dictionary else {}


## Detik penawaran `id` yang tersisa (0 = belum mulai, sudah dibeli, atau habis).
func offer_left(id: StringName) -> float:
	if owns(id) or not offers.has(String(id)):
		return 0.0
	var end: float = float(offers[String(id)]) + float(offer_rule(id).get("hours", 0.0)) * 3600.0
	return maxf(0.0, end - now_unix())


## Penawaran yang sedang berjalan, urut katalog.
func live_offers() -> Array[StringName]:
	var out: Array[StringName] = []
	for p: Dictionary in products("offer"):
		var id: StringName = StringName(str(p["id"]))
		if offer_left(id) > 0.0:
			out.append(id)
	return out


## Mulai penawaran yang syaratnya terpenuhi (tier lokasi, cabang dibuka), lalu
## kembalikan penawaran berjalan yang popupnya belum pernah tampil (&"" bila
## tidak ada). Hanya bila toko tersedia.
func update_offers(tier: int, franchises: int) -> StringName:
	if not store_available():
		return &""
	var dirty: bool = false
	for p: Dictionary in products("offer"):
		var id: String = str(p["id"])
		if owned.has(id) or offers.has(id):
			continue
		var rule: Dictionary = offer_rule(StringName(id))
		if tier >= int(rule.get("min_tier", 1)) and franchises >= int(rule.get("min_franchises", 0)):
			offers[id] = now_unix()
			dirty = true
	if dirty:
		save_state()
		changed.emit()
	for id2: StringName in live_offers():
		if not offers_shown.has(String(id2)):
			return id2
	return &""


func mark_offer_shown(id: StringName) -> void:
	offers_shown[String(id)] = true
	save_state()


# ===========================================================================
# BERKAS PERANGKAT
# ===========================================================================

func load_state() -> void:
	_clear()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("[SAVE] monetization.json is corrupt; starting fresh")
		return
	var d: Dictionary = data
	# Versi 1: hanya Supporter Pack.
	if bool(d.get("supporter", false)):
		owned.append(String(supporter_product()))
	for x: Variant in d.get("owned", []):
		var pid: String = String(canonical(StringName(str(x))))
		if not owned.has(pid) and not product(StringName(pid)).is_empty():
			owned.append(pid)
	club_until = maxf(0.0, float(d.get("club_until", 0.0)))
	var of: Variant = d.get("offers", {})
	if of is Dictionary:
		for k: Variant in (of as Dictionary).keys():
			offers[str(k)] = float((of as Dictionary)[k])
	var shown: Variant = d.get("offers_shown", {})
	if shown is Dictionary:
		for k2: Variant in (shown as Dictionary).keys():
			offers_shown[str(k2)] = true
	_day = str(d.get("day", ""))
	var used: Variant = d.get("used", {})
	if used is Dictionary:
		for k3: Variant in (used as Dictionary).keys():
			_used[str(k3)] = maxi(0, int((used as Dictionary)[k3]))
	_club_was = club_active()


func save_state() -> void:
	var payload: Dictionary = {"version": VERSION, "owned": owned.duplicate(), "club_until": club_until,
		"offers": offers.duplicate(), "offers_shown": offers_shown.duplicate(), "day": _day, "used": _used.duplicate()}
	var tmp: String = path + ".tmp"
	var f: FileAccess = FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("[SAVE] could not write monetization state")
		return
	f.store_string(JSON.stringify(payload, "\t"))
	f.close()
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func _clear() -> void:
	owned.clear()
	club_until = 0.0
	offers.clear()
	offers_shown.clear()
	_day = ""
	_used.clear()
	_club_was = false


## Alat ukur yang menjalankan GameRoot (sweep, trailer, probe): berkas perangkat
## sendiri yang dimulai kosong, supaya penawaran dan jatah iklan pemain di mesin
## ini tidak tersentuh.
func use_test_file(tool_name: String) -> void:
	path = "user://%s_monetization.json" % tool_name
	reset_for_tests()


## Tes: lupakan semuanya (berkas ikut dihapus).
func reset_for_tests() -> void:
	_clear()
	busy = false
	now_override = -1.0
	_loading_done = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if PauseManager.has(PAUSE_REASON):
		PauseManager.clear(PAUSE_REASON)
	AudioManager.set_ad_muted(false)
