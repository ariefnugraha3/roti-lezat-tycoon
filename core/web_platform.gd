class_name WebPlatform
extends RefCounted
## Satu-satunya tempat yang bicara dengan browser (GDD idle 12.0; v3.1 12.5,
## 128.3): deteksi browser HP, posisi layar, serta layar penuh plus kunci
## potret lewat JavaScriptBridge bawaan Godot (hanya berfungsi di build Web; di
## platform lain semua fungsi di sini tidak berbuat apa-apa).
##
## Browser hanya mengizinkan layar penuh dari gestur pemain yang SELESAI
## (touchend/mouseup, bukan saat jari baru menempel), jadi panggil
## `enter_fullscreen_portrait()` dari ketukan yang dilepas.

## Paksa perilaku browser HP tanpa browser sungguhan (test).
static var force_mobile_web: bool = false
## -1 = baca ukuran jendela; 0 = paksa landscape; 1 = paksa tegak (test).
static var forced_portrait: int = -1

## Chrome Android: layar penuh tersedia dan orientasi bisa dikunci. Safari iPhone
## tidak punya keduanya untuk kanvas, jadi di sana pemain memegang HP sendiri.
const JS_CAN_LOCK: String = "!!((document.fullscreenEnabled || document.webkitFullscreenEnabled) && window.screen && screen.orientation && screen.orientation.lock)"
## Kanvas masuk layar penuh (tanpa bilah navigasi), lalu orientasi dikunci ke
## potret setelah permintaan layar penuh diterima. Semua kegagalan diabaikan:
## bingkai potret tetap bisa dimainkan dalam posisi apa pun (GDD idle 12.0.6).
const JS_FULLSCREEN_PORTRAIT: String = """(function () {
	var d = document;
	var c = d.getElementById('canvas') || d.querySelector('canvas');
	function lock() {
		try {
			if (window.screen && screen.orientation && screen.orientation.lock) {
				screen.orientation.lock('portrait').catch(function () {});
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


## Browser ini bisa masuk layar penuh dan mengunci orientasi.
static func can_lock_orientation() -> bool:
	if not is_web():
		return false
	return bool(JavaScriptBridge.eval(JS_CAN_LOCK, true))


static func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN


## Masuk layar penuh dan kunci potret (bila browser mengizinkan). Hanya dari
## ketukan yang dilepas; di luar Web tidak berbuat apa-apa.
static func enter_fullscreen_portrait() -> void:
	if not is_web():
		return
	JavaScriptBridge.eval(JS_FULLSCREEN_PORTRAIT, true)


## Bagikan gambar PNG lewat lembar bagi browser (Web Share API dengan berkas,
## umumnya di HP), atau unduh bila browser tidak bisa (GDD idle 21.4). Panggil
## dari tombol yang baru dilepas: browser hanya membuka lembar bagi beberapa
## detik setelah gestur. Hasil: "share", "download", atau "error".
const JS_SHARE_PNG: String = """(function (b64, name, text) {
	try {
		var bin = atob(b64);
		var u = new Uint8Array(bin.length);
		for (var i = 0; i < bin.length; i++) { u[i] = bin.charCodeAt(i); }
		var blob = new Blob([u], { type: 'image/png' });
		var file = (typeof File === 'function') ? new File([blob], name, { type: 'image/png' }) : null;
		if (file && navigator.share && navigator.canShare && navigator.canShare({ files: [file] })) {
			navigator.share({ files: [file], text: text }).catch(function () {});
			return 'share';
		}
		var a = document.createElement('a');
		a.href = URL.createObjectURL(blob);
		a.download = name;
		document.body.appendChild(a);
		a.click();
		setTimeout(function () { URL.revokeObjectURL(a.href); a.remove(); }, 4000);
		return 'download';
	} catch (e) { return 'error'; }
})(%s, %s, %s);"""


static func share_or_download_png(png: PackedByteArray, file_name: String, text: String) -> String:
	if not is_web():
		return "error"
	var js: String = JS_SHARE_PNG % [JSON.stringify(Marshalls.raw_to_base64(png)), JSON.stringify(file_name), JSON.stringify(text)]
	var r: Variant = JavaScriptBridge.eval(js, true)
	return str(r) if r != null else "error"
