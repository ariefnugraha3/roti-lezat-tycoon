extends Node
## Monetization — iklan berhadiah dan Supporter Pack (GDD idle 22). Layanan
## tanpa state gameplay: jatah harian dan hak Supporter milik perangkat, disimpan
## di `user://monetization.json`, bukan di profil.
##
## Satu penyedia per platform (MonetizationProvider): tanpa monetisasi di
## desktop dan build Web biasa, portal CrazyGames/Poki lewat fitur ekspor
## `crazygames`/`poki`, dan penyedia palsu di tes. Selama iklan, toko di-pause
## (PauseManager alasan `ad`) dan suara dibisukan; hadiah hanya bila iklan
## selesai ditonton, dan jatah harian hanya berkurang saat hadiah diberikan.

signal changed()

const VERSION: int = 1
const PAUSE_REASON: StringName = &"ad"

## Berkas perangkat; tes mengarahkannya ke berkas sendiri.
var path: String = "user://monetization.json"
var provider: MonetizationProvider = null
## Supporter Pack dimiliki perangkat ini.
var supporter: bool = false
## Iklan sedang tayang.
var busy: bool = false
var _day: String = ""
var _used: Dictionary = {}
var _loading_done: bool = false
var _sent_loading: bool = false
var _gameplay: bool = false
var _sent_gameplay: bool = false


func _ready() -> void:
	load_state()
	use_provider(_platform_provider())


## Penyedia platform ini (GDD idle 22.2).
static func _platform_provider() -> MonetizationProvider:
	if OS.has_feature("web") and OS.has_feature("crazygames"):
		return PortalMonetizationProvider.new(&"crazygames")
	if OS.has_feature("web") and OS.has_feature("poki"):
		return PortalMonetizationProvider.new(&"poki")
	return MonetizationProvider.new()


## Ganti penyedia (tes).
func use_provider(p: MonetizationProvider) -> void:
	provider = p
	busy = false
	_sent_loading = false
	_sent_gameplay = false
	provider.setup()
	changed.emit()


func _process(_delta: float) -> void:
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
# IKLAN BERHADIAH (GDD idle 22.3)
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
## yang sedang tayang, dan iklan siap (atau Supporter, yang tidak perlu iklan).
func can_offer(id: StringName) -> bool:
	if busy or left_today(id) <= 0:
		return false
	return supporter or (provider != null and provider.ads_ready())


## Hadiah `id` diberikan tanpa iklan (Supporter Pack).
func is_free(_id: StringName = &"") -> bool:
	return supporter


## Tampilkan iklan untuk hadiah `id`, lalu `done(success)`. Supporter langsung
## berhasil. Hadiahnya sendiri diberikan oleh pemanggil saat success.
func show_rewarded(id: StringName, done: Callable) -> void:
	if not can_offer(id):
		done.call(false)
		return
	if supporter:
		_use(id)
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
# SUPPORTER PACK (GDD idle 22.4)
# ===========================================================================

static func supporter_product() -> StringName:
	return StringName(str(DataRegistry.idle("monetization.supporter_product")))


func store_available() -> bool:
	return provider != null and provider.store_ready()


func supporter_price() -> String:
	return provider.product_price(supporter_product()) if provider != null else ""


func buy_supporter(done: Callable) -> void:
	if supporter or not store_available():
		done.call(supporter)
		return
	provider.buy(supporter_product(), func(ok: bool) -> void:
		if ok:
			_grant_supporter()
		done.call(ok))


func restore_purchases(done: Callable) -> void:
	if not store_available():
		done.call(supporter)
		return
	provider.restore_purchases(func(owned: Array) -> void:
		if owned.has(supporter_product()):
			_grant_supporter()
		done.call(supporter))


func _grant_supporter() -> void:
	if supporter:
		return
	supporter = true
	save_state()
	GameLogger.important("UI", "Supporter Pack active")
	changed.emit()


# ===========================================================================
# BERKAS PERANGKAT
# ===========================================================================

func load_state() -> void:
	supporter = false
	_day = ""
	_used.clear()
	if not FileAccess.file_exists(path):
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_warning("[SAVE] monetization.json is corrupt; starting fresh")
		return
	var d: Dictionary = data
	supporter = bool(d.get("supporter", false))
	_day = str(d.get("day", ""))
	var used: Variant = d.get("used", {})
	if used is Dictionary:
		for k: Variant in (used as Dictionary).keys():
			_used[str(k)] = maxi(0, int((used as Dictionary)[k]))


func save_state() -> void:
	var payload: Dictionary = {"version": VERSION, "supporter": supporter, "day": _day, "used": _used.duplicate()}
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


## Tes: lupakan semuanya (berkas ikut dihapus).
func reset_for_tests() -> void:
	supporter = false
	busy = false
	_day = ""
	_used.clear()
	_loading_done = false
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
	if PauseManager.has(PAUSE_REASON):
		PauseManager.clear(PAUSE_REASON)
	AudioManager.set_ad_muted(false)
