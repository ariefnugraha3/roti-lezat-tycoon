class_name WebPlatform
extends RefCounted
## Satu-satunya tempat yang bicara dengan browser (GDD 12.5, 128.3; keputusan
## maintainer 2026-09-30): deteksi browser HP, posisi layar, serta layar penuh
## plus kunci landscape lewat JavaScriptBridge bawaan Godot (hanya berfungsi di
## build Web; di platform lain semua fungsi di sini tidak berbuat apa-apa).
##
## Browser hanya mengizinkan layar penuh dari gestur pemain yang SELESAI
## (touchend/mouseup, bukan saat jari baru menempel), jadi panggil
## `enter_fullscreen_landscape()` dari ketukan yang dilepas.

## Paksa perilaku browser HP tanpa browser sungguhan (test).
static var force_mobile_web: bool = false
## -1 = baca ukuran jendela; 0 = paksa landscape; 1 = paksa tegak (test).
static var forced_portrait: int = -1

## Chrome Android: layar penuh tersedia dan orientasi bisa dikunci. Safari iPhone
## tidak punya keduanya untuk kanvas, jadi di sana pemain memutar HP sendiri.
const JS_CAN_LOCK: String = "!!((document.fullscreenEnabled || document.webkitFullscreenEnabled) && window.screen && screen.orientation && screen.orientation.lock)"
## Kanvas masuk layar penuh (tanpa bilah navigasi), lalu orientasi dikunci ke
## landscape setelah permintaan layar penuh diterima. Semua kegagalan diabaikan:
## layar "putar HP" tetap menjadi jalan keluarnya.
const JS_FULLSCREEN_LANDSCAPE: String = """(function () {
	var d = document;
	var c = d.getElementById('canvas') || d.querySelector('canvas');
	function lock() {
		try {
			if (window.screen && screen.orientation && screen.orientation.lock) {
				screen.orientation.lock('landscape').catch(function () {});
			}
		} catch (e) {}
	}
	if (d.fullscreenElement || d.webkitFullscreenElement) { lock(); return; }
	if (!c) { return; }
	var req = c.requestFullscreen || c.webkitRequestFullscreen;
	if (!req) { return; }
	try {
		var p = req.call(c, { navigationUI: 'hide' });
		if (p && p.then) { p.then(lock).catch(function () {}); } else { lock(); }
	} catch (e) {}
})();"""


static func is_web() -> bool:
	return OS.has_feature("web")


## Browser di HP atau tablet. iPadOS melapor sebagai Mac, jadi dibedakan dari
## laptop lewat layar sentuh.
static func is_mobile_web() -> bool:
	if force_mobile_web:
		return true
	if not is_web():
		return false
	if OS.has_feature("web_android") or OS.has_feature("web_ios"):
		return true
	return OS.has_feature("web_macos") and DisplayServer.is_touchscreen_available()


## Layar lebih tinggi daripada lebarnya.
static func is_portrait() -> bool:
	if forced_portrait >= 0:
		return forced_portrait == 1
	var s: Vector2i = DisplayServer.window_get_size()
	return s.y > s.x


## Browser ini bisa masuk layar penuh dan mengunci landscape.
static func can_lock_landscape() -> bool:
	if not is_web():
		return false
	return bool(JavaScriptBridge.eval(JS_CAN_LOCK, true))


static func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Masuk layar penuh dan kunci landscape (bila browser mengizinkan). Hanya dari
## ketukan yang dilepas; di luar Web tidak berbuat apa-apa.
static func enter_fullscreen_landscape() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval(JS_FULLSCREEN_LANDSCAPE, true)
