class_name PortalMonetizationProvider
extends MonetizationProvider
## Iklan berhadiah portal web (GDD idle 22.2): CrazyGames (SDK HTML5 v3) atau
## Poki (SDK v2). SDK-nya dimuat `html/head_include` preset portal; semua panggilan
## JavaScript lewat WebPlatform. Portal tidak menjual Supporter Pack.

var kind: StringName = &""
var _done: Callable = Callable()
## SDK siap (dibaca dari JavaScript setiap ~0,5 detik, bukan setiap frame).
var _ready: bool = false
var _check_in: int = 0


func _init(portal: StringName) -> void:
	kind = portal


func id() -> StringName:
	return kind


func setup() -> void:
	WebPlatform.portal_init(kind)


func connected() -> bool:
	return _ready


func ads_ready() -> bool:
	return _ready and not _done.is_valid()


func show_rewarded(done: Callable) -> void:
	if not WebPlatform.portal_rewarded():
		done.call(false)
		return
	_done = done


func poll() -> void:
	_check_in -= 1
	if _check_in <= 0:
		_check_in = 30
		_ready = WebPlatform.portal_ready()
	if not _done.is_valid():
		return
	var state: String = WebPlatform.portal_ad_state()
	if state == "pending":
		return
	var cb: Callable = _done
	_done = Callable()
	cb.call(state == "done")


func lifecycle(event: StringName) -> void:
	WebPlatform.portal_event(event)
